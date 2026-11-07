#Requires -Version 5.1
<#
.SYNOPSIS
  mission-telemetry -- the verb side of the mission-event feed (UI-1 S1; LM2-ADR-045; expanded-schemas SS14):
  the host registration mission init runs, the ONE mission_snapshot writer, and the bridge every lifecycle
  verb calls to append its line.

.DESCRIPTION
  DOT-SOURCED, NEVER RUN. It defines functions and performs no I/O on import.

  Register-MissionCheckout -Root   the installer's step for one checkout (mission init calls it): mints
                                   <home>/host-id once (a UUID, byte-stable afterwards), appends one row
                                   {host_id, checkout_path, mission_id, registered_at, framework_version} to
                                   <home>/projects.yaml unless the checkout already has one (rows are never
                                   pruned), and makes .mission-runtime/telemetry/ -- the folder the emitter
                                   itself never makes. home = $env:VANGUARD_HOME, else ~/.vanguard.
  Get-MissionSnapshotState -Root   the derived state a mission_snapshot carries.
  Write-MissionSnapshot -Root      THE ONLY SNAPSHOT WRITER: derives, hashes, compares with the feed's last
                                   mission_snapshot line, and appends only when the hash moved.
  Invoke-MissionTelemetry          THE BRIDGE: loads the next-generation hooks' library in a child scope
                                   (so its strict mode and its functions stay there), appends the verb's
                                   events through Write-MissionEvent, then the snapshot when asked.

  NEVER FAILS A VERB. Every entry point catches everything: SS14's append "never blocks and never fails the
  tool call or verb that triggered it". A verb that cannot find this file (a copy vendored without it) skips
  the feed silently -- the caller tests for the file before it dot-sources it.
#>

function Get-MissionTelemetryHome {
    if ($env:VANGUARD_HOME) { return $env:VANGUARD_HOME }
    $prof = $env:USERPROFILE
    if (-not $prof) { $prof = $env:HOME }
    return (Join-Path $prof '.vanguard')
}

function Get-MissionTelemetryYamlScalar {
    # A column-0 scalar, one key or none ($null for absent, duplicated, null or ~). RELEASE-4 S2 F-H13 (S1 F5): a '#' is a
    # comment only where YAML makes it one -- outside quotes, at the value's start or after a space or tab -- so a name
    # such as 'Project #2' (mission init writes the name single-quoted, '' for a quote) or Project#2 is kept whole, and a
    # trailing " # comment" is still stripped. Single-quoted: '' is one '. Double-quoted: \" and \\ are unescaped.
    param([AllowNull()][string]$Text, [string]$Key)
    if (-not $Text) { return $null }
    $ms = [regex]::Matches($Text, '(?m)^' + [regex]::Escape($Key) + ':[ \t]*(.*?)[ \t]*\r?$')
    if ($ms.Count -ne 1) { return $null }
    $raw = $ms[0].Groups[1].Value
    if ($raw.StartsWith("'")) {
        $q = [regex]::Match($raw, "^'((?:[^']|'')*)'(?:[ \t]+#.*)?$")
        if (-not $q.Success) { return $null }
        $v = $q.Groups[1].Value.Replace("''", "'")
    } elseif ($raw.StartsWith('"')) {
        $q = [regex]::Match($raw, '^"((?:[^"\\]|\\.)*)"(?:[ \t]+#.*)?$')
        if (-not $q.Success) { return $null }
        $v = $q.Groups[1].Value.Replace('\"', '"').Replace('\\', '\')
    } else {
        $v = ([regex]::Replace($raw, '(^|[ \t])#.*$', '')).Trim()
    }
    if ($v -eq '' -or $v -eq 'null' -or $v -eq '~') { return $null }
    return $v
}

function Register-MissionCheckout {
    param([Parameter(Mandatory = $true)][string]$Root, [string]$FrameworkVersion)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $vh = Get-MissionTelemetryHome
    if (-not (Test-Path -LiteralPath $vh -PathType Container)) { New-Item -ItemType Directory -Path $vh -Force | Out-Null }
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    # host-id: minted ONCE. CreateNew is the race guard -- of two first runs one creates and the other reads.
    $hp = Join-Path $vh 'host-id'
    if (-not (Test-Path -LiteralPath $hp -PathType Leaf)) {
        try {
            $fs = [System.IO.File]::Open($hp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $b = $utf8.GetBytes([guid]::NewGuid().ToString('D').ToLowerInvariant() + "`n"); $fs.Write($b, 0, $b.Length) } finally { $fs.Dispose() }
        } catch [System.IO.IOException] { if (-not (Test-Path -LiteralPath $hp -PathType Leaf)) { throw } }
    }
    $hostId = ([System.IO.File]::ReadAllText($hp)).Trim()

    $missionId = $null
    $mf = Join-Path $rootFull '.mission\mission.yaml'
    if (Test-Path -LiteralPath $mf -PathType Leaf) { $missionId = Get-MissionTelemetryYamlScalar -Text ([System.IO.File]::ReadAllText($mf)) -Key 'id' }
    if (-not $FrameworkVersion) {
        $vf = Join-Path $PSScriptRoot '..\..\VERSION'
        $FrameworkVersion = if (Test-Path -LiteralPath $vf -PathType Leaf) { ([System.IO.File]::ReadAllText($vf)).Trim() } else { $null }
    }

    # the registry: one row per checkout, appended, never pruned and never rewritten
    $reg = Join-Path $vh 'projects.yaml'
    $known = $false
    if (Test-Path -LiteralPath $reg -PathType Leaf) {
        foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($reg), "(?m)^\s*(?:-\s+)?checkout_path:\s*'((?:[^']|'')*)'\s*\r?$")) {
            if ([string]::Equals((($m.Groups[1].Value -replace "''", "'").TrimEnd('\', '/')), $rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { $known = $true }
        }
    }
    $added = $false
    if (-not $known) {
        $sb = New-Object System.Text.StringBuilder
        if (-not (Test-Path -LiteralPath $reg -PathType Leaf)) {
            [void]$sb.Append("# Vanguard host registry -- one row per registered checkout, appended by install.ps1 and mission init`n")
            [void]$sb.Append("# (ADR-045). Read by ``vanguard ui``. Rows are never pruned: a row whose path is gone is shown as stale.`n")
        }
        $q = { param($s) if ($null -eq $s) { 'null' } else { "'" + ([string]$s -replace "'", "''") + "'" } }
        [void]$sb.Append("- host_id: $hostId`n")
        [void]$sb.Append("  checkout_path: $(& $q $rootFull)`n")
        [void]$sb.Append("  mission_id: $(& $q $missionId)`n")
        [void]$sb.Append("  registered_at: $(& $q ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)))`n")
        [void]$sb.Append("  framework_version: $(& $q $FrameworkVersion)`n")
        $bytes = $utf8.GetBytes($sb.ToString())
        $fs = [System.IO.File]::Open($reg, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
        $added = $true
    }

    $tdir = Join-Path $rootFull '.mission-runtime\telemetry'
    if (-not (Test-Path -LiteralPath $tdir -PathType Container)) { New-Item -ItemType Directory -Path $tdir -Force | Out-Null }
    return [pscustomobject]@{ host_id = $hostId; checkout_path = $rootFull; mission_id = $missionId; row_added = $added; registry = $reg; telemetry_dir = $tdir }
}

function Register-MissionWorktree {
    # A WORKTREE IS ITS OWN STREAM (ADR-045: "each has its own file and seq; the stream identity is the
    # registry entry (host, checkout path)"), so it is registered as itself -- its own row, its own telemetry
    # folder, which git never brings along because the folder is ignored. Only when the checkout it was cut
    # from is a stream: a worktree of a checkout that is not one gets nothing. $null when nothing was done.
    param([Parameter(Mandatory = $true)][string]$PrimaryRoot, [Parameter(Mandatory = $true)][string]$WorktreeRoot)
    try {
        $lib = Join-Path $PSScriptRoot '..\evidence-hooks-next\hooks\lib\evidence-common.ps1'
        if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) { return $null }
        $isStream = & { param($L, $R) . $L; Test-MissionTelemetryStream -Root $R } $lib ([System.IO.Path]::GetFullPath($PrimaryRoot))
        if (-not $isStream) { return $null }
        return (Register-MissionCheckout -Root $WorktreeRoot)
    } catch { return $null }
}

# --------------------------------------------------------------------------------------------------
# THE SNAPSHOT. Derived from .mission/mission.yaml (state, current_milestone), the spec current.txt names
# (feature ids, and a feature's own status: where the spec writes one; milestone ids, titles and status),
# the contract (assertion ids, their features and milestones), and the registers beside them:
# validator-results (assertion status), dispatches (open ones) and the HALT folders (open ones). Nothing is
# read from the feed except the last snapshot: its hash, and -- only when the hash moved -- its milestones'
# started_ts / done_ts, which are carried forward (see Set-MissionMilestoneTimes).
# --------------------------------------------------------------------------------------------------
function Get-MissionCheckoutName {
    # The folder name mission init gives a mission (F-P5a): the checkout's own; for a linked worktree, whose .git is a file
    # naming <primary>\.git\worktrees\<n>, the primary checkout's -- one mission, one name, whichever stream writes.
    param([Parameter(Mandatory = $true)][string]$Root)
    $full = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $dotGit = Join-Path $full '.git'
    if (Test-Path -LiteralPath $dotGit -PathType Leaf) {
        $m = [regex]::Match([System.IO.File]::ReadAllText($dotGit), '(?m)^gitdir:\s*(.+?)\s*$')
        if ($m.Success) {
            $wm = [regex]::Match($m.Groups[1].Value, '^(.*)[\\/]\.git[\\/]worktrees[\\/][^\\/]+$')
            if ($wm.Success) { return (Split-Path -Leaf ($wm.Groups[1].Value.TrimEnd('\', '/'))) }
        }
    }
    return (Split-Path -Leaf $full)
}

function ConvertTo-MissionMilestoneStatus {
    # A milestone's spec status word as the snapshot carries it: the closed set of expanded-schemas SS14 (passed, active,
    # pending, withdrawn), done read as passed; $null for any other word (the caller refuses it). Case-sensitive.
    param([AllowNull()][string]$Word)
    switch -CaseSensitive ($Word) {
        'passed'    { return 'passed' }
        'done'      { return 'passed' }
        'active'    { return 'active' }
        'pending'   { return 'pending' }
        'withdrawn' { return 'withdrawn' }
    }
    return $null
}

function Get-MissionSnapshotState {
    param([Parameter(Mandatory = $true)][string]$Root)
    $mt = [System.IO.File]::ReadAllText((Join-Path $Root '.mission\mission.yaml'))
    $state = Get-MissionTelemetryYamlScalar -Text $mt -Key 'state'
    $milestone = Get-MissionTelemetryYamlScalar -Text $mt -Key 'current_milestone'
    # the mission's name (RELEASE-4 S1, F-P5a): the record's own `name`, which mission init writes; where the record carries
    # none (a mission made before init wrote it), the value init would have written -- the checkout's own folder name, the
    # primary checkout's for a linked worktree. Never the host registry's row, which is stale by design after a prune.
    $missionName = Get-MissionTelemetryYamlScalar -Text $mt -Key 'name'
    if (-not $missionName) { $missionName = Get-MissionCheckoutName -Root $Root }

    # assertions: ids from the contract, status from the validator results (latest attempt wins)
    $assertions = @{}
    $assertFeature = @{}
    $assertMilestone = @{}
    $cdir = Join-Path $Root '.mission\contract\assertions'
    foreach ($af in @(Get-ChildItem -LiteralPath $cdir -File -Filter '*.yaml' -ErrorAction SilentlyContinue)) {
        $at = [System.IO.File]::ReadAllText($af.FullName)
        $aid = Get-MissionTelemetryYamlScalar -Text $at -Key 'id'
        if (-not $aid) { $aid = $af.BaseName }
        $assertions[$aid] = 'pending'
        $assertFeature[$aid] = Get-MissionTelemetryYamlScalar -Text $at -Key 'feature_id'
        $assertMilestone[$aid] = Get-MissionTelemetryYamlScalar -Text $at -Key 'milestone_id'
    }
    $vdir = Join-Path $Root '.mission\validator-results'
    $verdictOf = { param($v) if ($null -eq $v) { return $null }; switch -regex ([string]$v) { '^(?i:pass|passed|green|confirmed)$' { 'green' } '^(?i:fail|failed|red|refuted)$' { 'red' } '^(?i:skip|skipped)$' { 'skipped' } default { $null } } }
    $results = @()
    $vman = Join-Path $vdir 'manifest.json'
    if (Test-Path -LiteralPath $vman -PathType Leaf) {
        $vm = [System.IO.File]::ReadAllText($vman) | ConvertFrom-Json
        foreach ($e in @($vm.entries)) { $results += [pscustomobject]@{ ids = @([string]$e.assertion_id); only = $null; attempt = [int]$e.attempt_number; verdict = (& $verdictOf $e.verdict) } }
    } else {
        foreach ($vf in @(Get-ChildItem -LiteralPath $vdir -File -Filter '*.yaml' -ErrorAction SilentlyContinue)) {
            $vt = [System.IO.File]::ReadAllText($vf.FullName)
            $lm = [regex]::Match($vt, '(?m)^assertion_ids:\s*\[([^\]]*)\]')
            if (-not $lm.Success) { continue }
            $ids = @($lm.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
            $att = 0; [void][int]::TryParse([string](Get-MissionTelemetryYamlScalar -Text $vt -Key 'attempt_number'), [ref]$att)
            $results += [pscustomobject]@{ ids = $ids; only = (Get-MissionTelemetryYamlScalar -Text $vt -Key 'assertion_id'); attempt = $att
                                           verdict = (& $verdictOf (Get-MissionTelemetryYamlScalar -Text $vt -Key 'verdict')) }
        }
    }
    foreach ($r in @($results | Sort-Object attempt)) {
        if (-not $r.verdict) { continue }
        foreach ($id in @($r.ids)) {
            # a failing result that names ONE assertion fails that one; the others it lists keep their status
            if ($r.verdict -eq 'red' -and $r.only -and ($r.only -ne $id)) { continue }
            $assertions[$id] = $r.verdict
        }
    }

    # features: ids from the spec current.txt names; the spec's status where it writes one, else derived
    $features = @{}
    $st = $null
    $curF = Join-Path $Root '.mission\spec\current.txt'
    if (Test-Path -LiteralPath $curF -PathType Leaf) {
        $tok = ([System.IO.File]::ReadAllText($curF)).Trim()
        if ($tok -and $tok -notmatch '\.ya?ml$') { $tok = $tok + '.yaml' }
        $specF = Join-Path $Root (".mission\spec\" + $tok)
        if ($tok -and (Test-Path -LiteralPath $specF -PathType Leaf)) {
            $st = [System.IO.File]::ReadAllText($specF)
            $sec = [regex]::Match($st, '(?ms)^features:[^\r\n]*\r?\n(.*?)(?=^[A-Za-z_]|\z)')
            if ($sec.Success) {
                $blocks = [regex]::Matches($sec.Groups[1].Value, '(?ms)^\s*-\s+id:\s*(\S+)[^\r\n]*\r?\n?(.*?)(?=^\s*-\s+id:|\z)')
                foreach ($bk in $blocks) {
                    $fid = $bk.Groups[1].Value.Trim('"', "'")
                    $sm = [regex]::Match($bk.Groups[2].Value, '(?m)^\s+status:\s*([^\s#]+)')
                    if ($sm.Success) { $features[$fid] = $sm.Groups[1].Value.Trim('"', "'"); continue }
                    $mine = @($assertFeature.Keys | Where-Object { $assertFeature[$_] -eq $fid })
                    $fs = 'pending'
                    if ($mine.Count -gt 0) {
                        $vals = @($mine | ForEach-Object { $assertions[$_] })
                        if (@($vals | Where-Object { $_ -ne 'green' }).Count -eq 0) { $fs = 'done' }
                        elseif (@($vals | Where-Object { $_ -ne 'pending' }).Count -gt 0) { $fs = 'in_progress' }
                    }
                    $features[$fid] = $fs
                }
            }
        }
    }

    # milestones (UI-1 S2-AM1, U-17): ids, titles and status from the same spec's milestones list (SS2's Milestone
    # writes title / contract_assertion_ids; a spec writing name / assertions is read alike), each milestone's
    # assertions = the ids it lists plus the contract assertions whose milestone_id names it; its status the spec's
    # where it writes one, else derived: passed when every one of its assertions is green, active when it is the
    # current milestone or any of its assertions has a status, else pending. started_ts / done_ts are null here --
    # they are observation times, not derived state, and Write-MissionSnapshot fills them outside the hash.
    $milestones = [ordered]@{}
    if ($st) {
        $msec = [regex]::Match($st, '(?ms)^milestones:[^\r\n]*\r?\n(.*?)(?=^[A-Za-z_]|\z)')
        if ($msec.Success) {
            $found = @{}
            foreach ($bk in [regex]::Matches($msec.Groups[1].Value, '(?ms)^\s*-\s+id:\s*(\S+)[^\r\n]*\r?\n?(.*?)(?=^\s*-\s+id:|\z)')) {
                $mid = $bk.Groups[1].Value.Trim('"', "'")
                $title = $null; $mstatus = $null; $ids = @(); $key = $null
                foreach ($ln in ($bk.Groups[2].Value -split '\r?\n')) {
                    if ($ln -match '^\s+([A-Za-z_]+):\s*(.*?)\s*$') {
                        $key = $Matches[1]; $val = $Matches[2]
                        if (($key -eq 'title') -or ($key -eq 'name' -and $null -eq $title)) { if ($val -and $val -notmatch '^[>|]') { $title = $val.Trim('"', "'") } }
                        elseif ($key -eq 'status' -and $val) { $mstatus = ($val -replace '\s+#.*$', '').Trim('"', "'") }
                        elseif ($key -eq 'contract_assertion_ids' -or $key -eq 'assertions') {
                            # an elision ("...", as SS2's own example writes the list) is not an id
                            if ($val -match '^\[([^\]]*)\]') { $ids += @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ -and $_ -notmatch '^(\.{2,}|…)$' }) }
                        }
                    } elseif (($key -eq 'contract_assertion_ids' -or $key -eq 'assertions') -and $ln -match '^\s+-\s+([^\s#]+)') {
                        $one = $Matches[1].Trim('"', "'")
                        if ($one -notmatch '^(\.{2,}|…)$') { $ids += $one }
                    }
                }
                $ids += @($assertMilestone.Keys | Where-Object { $assertMilestone[$_] -eq $mid })
                $ids = @($ids | Sort-Object -Unique)
                $green = @($ids | Where-Object { $assertions[$_] -eq 'green' }).Count
                if ($mstatus) {
                    # THE STATUS MAP (RELEASE-4 S1, F-P1a): a spec word becomes one of the closed set at emit -- done -> passed,
                    # withdrawn -> withdrawn, passed / active / pending as they are. A word outside the map is refused, the
                    # snapshot with it: never a silent fifth value.
                    $word = $mstatus
                    $mstatus = ConvertTo-MissionMilestoneStatus -Word $word
                    if (-not $mstatus) { throw ("REFUSED: milestone $mid carries the spec status '$word', a word outside the milestone status map (passed, active, pending, withdrawn; done -> passed)") }
                }
                if (-not $mstatus) {
                    if ($ids.Count -gt 0 -and $green -eq $ids.Count) { $mstatus = 'passed' }
                    elseif ($mid -eq $milestone -or @($ids | Where-Object { $assertions.ContainsKey($_) -and $assertions[$_] -ne 'pending' }).Count -gt 0) { $mstatus = 'active' }
                    else { $mstatus = 'pending' }
                }
                $found[$mid] = [ordered]@{ title = $title; status = $mstatus; assertions_total = $ids.Count; assertions_green = $green; started_ts = $null; done_ts = $null }
            }
            foreach ($k in @($found.Keys | Sort-Object)) { $milestones[$k] = $found[$k] }
        }
    }

    # open dispatches: <id>.yaml with neither <id>.handoff.yaml nor <id>.superseded.yaml beside it
    $openD = 0
    $ddir = Join-Path $Root '.mission\dispatches'
    foreach ($df in @(Get-ChildItem -LiteralPath $ddir -File -Filter '*.yaml' -ErrorAction SilentlyContinue)) {
        if ($df.Name -notmatch '^[^.]+\.yaml$') { continue }
        $b = $df.BaseName
        if ((Test-Path -LiteralPath (Join-Path $ddir "$b.handoff.yaml")) -or (Test-Path -LiteralPath (Join-Path $ddir "$b.superseded.yaml"))) { continue }
        $openD++
    }
    # open HALTs: HALT-* under the two HALT homes, with no unrevoked halt-ruling gate naming the file
    $openH = 0
    foreach ($hd in @('.mission-runtime\halts', '.mission-runtime\lam')) {
        $hdir = Join-Path $Root $hd
        foreach ($hf in @(Get-ChildItem -LiteralPath $hdir -Recurse -File -Filter 'HALT-*' -ErrorAction SilentlyContinue)) {
            if ($hf.Name -match '\.ruling-citation\.yaml$') { continue }
            $g = Join-Path $Root (".mission\gates\halt-ruling-" + [System.IO.Path]::GetFileNameWithoutExtension($hf.Name) + '.yaml')
            if ((Test-Path -LiteralPath $g -PathType Leaf) -and -not (Get-MissionTelemetryYamlScalar -Text ([System.IO.File]::ReadAllText($g)) -Key 'revoked_at')) { continue }
            $openH++
        }
    }

    $fo = [ordered]@{}; foreach ($k in @($features.Keys | Sort-Object)) { $fo[$k] = $features[$k] }
    $ao = [ordered]@{}; foreach ($k in @($assertions.Keys | Sort-Object)) { $ao[$k] = $assertions[$k] }
    return [ordered]@{
        state             = $state
        mission_name      = $missionName
        current_milestone = $milestone
        features          = $fo
        assertions        = $ao
        counts            = [ordered]@{ features = $fo.Count; assertions = $ao.Count; open_halts = $openH; open_dispatches = $openD }
        milestones        = $milestones
    }
}

function Get-MissionLastSnapshotMilestones {
    # The milestones map on the feed's LAST mission_snapshot line (a PSCustomObject), or $null when there is no
    # snapshot, its line does not parse, or it predates the field.
    param([string]$Root)
    $p = Join-Path $Root '.mission-runtime\telemetry\events.jsonl'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
    $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false))); $text = $sr.ReadToEnd() } finally { $fs.Dispose() }
    # the last line whose own kind is mission_snapshot: the text is only a cheap filter, the parsed kind decides (a payload
    # may hold the same text in a nested object)
    $lines = $text -split "`n"
    $o = $null
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -notmatch '"kind":"mission_snapshot"') { continue }
        try { $c = $lines[$i] | ConvertFrom-Json } catch { continue }
        if ((Get-MissionTelemetryMember $c 'kind') -ceq 'mission_snapshot') { $o = $c; break }
    }
    if ($null -eq $o) { return $null }
    $pl = Get-MissionTelemetryMember $o 'payload'
    $ms = Get-MissionTelemetryMember $pl 'milestones'
    if (-not ($ms -is [System.Management.Automation.PSCustomObject])) { return $null }
    return $ms
}

function Get-MissionTelemetryMember {
    # A parsed JSON object's member, or $null when the object is not one or has no such member (strict-mode safe).
    param($O, [string]$Name)
    if (-not ($O -is [System.Management.Automation.PSCustomObject])) { return $null }
    $pp = $O.PSObject.Properties[$Name]
    if ($null -eq $pp) { return $null }
    return $pp.Value
}

function Set-MissionMilestoneTimes {
    # started_ts / done_ts: WHEN a milestone was seen to start (leave pending) and to pass, carried from the last
    # snapshot's map. A status the last map also shows keeps its times; a transition the writer observes -- the
    # milestone pending (or not listed) in a map that exists, and not pending now; not passed then, passed now --
    # is stamped with this derivation's UTC time, the clock the line's own ts comes from. With no earlier map (the
    # first snapshot, or one that predates the field) nothing was observed, so the times stay null: null until known.
    # They are not part of the hashed state, so concurrent writers after one change still write one snapshot.
    param([System.Collections.IDictionary]$Milestones, $Previous)
    $fmt = 'yyyy-MM-ddTHH:mm:ss.fffZ'
    $now = [DateTime]::UtcNow.ToString($fmt, [System.Globalization.CultureInfo]::InvariantCulture)
    $asTs = { param($v) if ($null -eq $v) { $null } elseif ($v -is [datetime]) { $v.ToUniversalTime().ToString($fmt, [System.Globalization.CultureInfo]::InvariantCulture) } else { [string]$v } }
    foreach ($id in @($Milestones.Keys)) {
        $m = $Milestones[$id]
        $p = Get-MissionTelemetryMember $Previous ([string]$id)
        $pStatus = Get-MissionTelemetryMember $p 'status'
        if ($null -ne $pStatus) { $pStatus = [string]$pStatus }
        if ($m['status'] -ne 'pending') {
            $pStart = & $asTs (Get-MissionTelemetryMember $p 'started_ts')
            if ($pStart) { $m['started_ts'] = $pStart }
            elseif ($null -ne $Previous -and ($null -eq $p -or $pStatus -eq 'pending')) { $m['started_ts'] = $now }
        }
        if ($m['status'] -eq 'passed') {
            $pDone = & $asTs (Get-MissionTelemetryMember $p 'done_ts')
            if ($pStatus -eq 'passed' -and $pDone) { $m['done_ts'] = $pDone }
            elseif ($null -ne $Previous -and $pStatus -ne 'passed') { $m['done_ts'] = $now }
        }
    }
}

function ConvertTo-MissionCanonicalJson {
    # Compact JSON, object keys sorted ordinally at every level, so the same derived state is the same bytes
    # (and the same snapshot_sha256) whoever derives it.
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [int] -or $Value -is [long]) { return ([string]$Value) }
    if ($Value -is [string]) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('"')
        foreach ($ch in $Value.ToCharArray()) {
            $c = [int]$ch
            if ($ch -eq '"') { [void]$sb.Append('\"') } elseif ($ch -eq '\') { [void]$sb.Append('\\') }
            elseif ($c -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $c)) } else { [void]$sb.Append($ch) }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = @(); foreach ($k in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) { $parts += ((ConvertTo-MissionCanonicalJson $k) + ':' + (ConvertTo-MissionCanonicalJson $Value[$k])) }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = @(); foreach ($i in $Value) { $parts += (ConvertTo-MissionCanonicalJson $i) }
        return '[' + ($parts -join ',') + ']'
    }
    return (ConvertTo-MissionCanonicalJson ([string]$Value))
}

function Get-MissionLastSnapshotSha {
    # The snapshot_sha256 on the feed's LAST mission_snapshot line, or '' when there is none.
    param([string]$Root)
    $p = Join-Path $Root '.mission-runtime\telemetry\events.jsonl'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return '' }
    $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false))); $text = $sr.ReadToEnd() } finally { $fs.Dispose() }
    $last = ''
    foreach ($ln in ($text -split "`n")) {
        if ($ln -notmatch '"kind":"mission_snapshot"') { continue }
        $m = [regex]::Match($ln, '"snapshot_sha256":"([0-9a-f]{64})"')
        if ($m.Success) { $last = $m.Groups[1].Value }
    }
    return $last
}

function Write-MissionSnapshot {
    # THE ONLY SNAPSHOT WRITER. Called by Invoke-MissionTelemetry -Snapshot, after Write-MissionEvent is in
    # scope. Appends a mission_snapshot only when snapshot_sha256 differs from the feed's last one.
    param([Parameter(Mandatory = $true)][string]$Root, [string]$Hook = 'verb')
    try {
        if (-not (Test-MissionTelemetryStream -Root $Root)) { return $false }
        $s = Get-MissionSnapshotState -Root $Root
        # the hash is of the derived state: the milestones map with its started_ts / done_ts still null
        $sha = Get-Sha256OfString -Text (ConvertTo-MissionCanonicalJson $s)
        if ($sha -ceq (Get-MissionLastSnapshotSha -Root $Root)) { return $false }
        Set-MissionMilestoneTimes -Milestones $s['milestones'] -Previous (Get-MissionLastSnapshotMilestones -Root $Root)
        $s['snapshot_sha256'] = $sha
        # The comparison above is a cheap early exit; -ChangeField makes it again UNDER THE EMITTER'S LOCK, so
        # concurrent verbs after one state change write one snapshot, not one each.
        return (Write-MissionEvent -Root $Root -Kind 'mission_snapshot' -Payload $s -SourcePath '.mission/mission.yaml' -Hook $Hook -ChangeField 'snapshot_sha256')
    } catch {
        $why = $_.Exception.Message
        $what = if ($why.StartsWith('REFUSED: ')) { 'was refused' } else { 'could not be derived' }
        try { Write-MissionTelemetryError -Root $Root -Hook $Hook -Message ("telemetry: the mission_snapshot $what and nothing was written to .mission-runtime/telemetry/events.jsonl: " + $why) } catch { }
        return $false
    }
}

function Invoke-MissionTelemetry {
    <#
      THE BRIDGE. -Events is a list of hashtables, each one of:
        @{ Kind; Payload; SourcePath }        a line composed by the verb
        @{ Kind; GatePath }                   gate_minted / gate_consumed / gate_expired, read off the gate
        @{ Kind; HaltPath; Resolution }       halt_raised / halt_resolved, read off the HALT
      -Snapshot then runs Write-MissionSnapshot. Returns nothing and never throws.
    #>
    param([Parameter(Mandatory = $true)][string]$Root, [object[]]$Events = @(), [switch]$Snapshot, [string]$Verb = 'verb')
    try {
        $lib = Join-Path $PSScriptRoot '..\evidence-hooks-next\hooks\lib\evidence-common.ps1'
        if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) { return }
        $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
        $null = & {
            param($LibPath, $R, $Evs, $Snap, $V)
            . $LibPath
            foreach ($e in @($Evs)) {
                if ($null -eq $e) { continue }
                if ($e.ContainsKey('GatePath')) { $null = Write-MissionGateEvent -Root $R -Kind $e.Kind -GatePath $e.GatePath -Hook $V }
                elseif ($e.ContainsKey('HaltPath')) { $null = Write-MissionHaltEvent -Root $R -Kind $e.Kind -HaltPath $e.HaltPath -Resolution $e.Resolution -Hook $V }
                else { $null = Write-MissionEvent -Root $R -Kind $e.Kind -Payload $e.Payload -SourcePath $e.SourcePath -Hook $V }
            }
            if ($Snap) { $null = Write-MissionSnapshot -Root $R -Hook $V }
        } $lib $rootFull $Events ([bool]$Snapshot) $Verb
    } catch { }
}
