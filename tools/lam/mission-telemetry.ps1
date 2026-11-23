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

function Get-MissionFrameworkVersion {
    # RELEASE-5 (register row 567): THE FRAMEWORK VERSION A CHECKOUT CARRIES, for its registry row. The version its own
    # framework.lock records (line 1, the header's "version": the installer writes it, and a work tree checks it out with
    # the project's files); else, for a work tree whose project does not track the lock, its primary checkout's; else the
    # VERSION file beside this script (the framework's own repository, which has no lock). $null when none is found --
    # written as null, never as ''. An installed checkout has no VERSION file: before 1.3.1 this read only that, and a
    # work tree registered at spawn got framework_version ''.
    param([Parameter(Mandatory = $true)][string]$Root, [string]$PrimaryRoot)
    foreach ($r in @($Root, $PrimaryRoot)) {
        if (-not $r) { continue }
        $lk = Join-Path $r 'framework.lock'
        if (-not (Test-Path -LiteralPath $lk -PathType Leaf)) { continue }
        try {
            $sr = New-Object System.IO.StreamReader($lk, (New-Object System.Text.UTF8Encoding($false)), $true)
            try { $first = $sr.ReadLine() } finally { $sr.Dispose() }
            $h = $first | ConvertFrom-Json
            if ($h -and $h.PSObject.Properties['version'] -and ([string]$h.version).Trim()) { return ([string]$h.version).Trim() }
        } catch { }
    }
    $vf = Join-Path $PSScriptRoot '..\..\VERSION'
    if (Test-Path -LiteralPath $vf -PathType Leaf) { $v = ([System.IO.File]::ReadAllText($vf)).Trim(); if ($v) { return $v } }
    return $null
}

function Register-MissionCheckout {
    param([Parameter(Mandatory = $true)][string]$Root, [string]$FrameworkVersion, [string]$PrimaryRoot)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $vh = Get-MissionTelemetryHome
    if (-not (Test-Path -LiteralPath $vh -PathType Container)) { New-Item -ItemType Directory -Path $vh -Force | Out-Null }
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    # host-id: minted ONCE. CreateNew is the race guard -- of two first runs one creates and the other reads.
    $hp = Join-Path $vh 'host-id'
    # UI-3 (1.3.3) UC-21: what this call wrote is returned, so the caller says it -- host_id_made, telemetry_made
    $hostMade = $false
    if (-not (Test-Path -LiteralPath $hp -PathType Leaf)) {
        try {
            $fs = [System.IO.File]::Open($hp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $b = $utf8.GetBytes([guid]::NewGuid().ToString('D').ToLowerInvariant() + "`n"); $fs.Write($b, 0, $b.Length) } finally { $fs.Dispose() }
            $hostMade = $true
        } catch [System.IO.IOException] { if (-not (Test-Path -LiteralPath $hp -PathType Leaf)) { throw } }
    }
    $hostId = ([System.IO.File]::ReadAllText($hp)).Trim()

    $missionId = $null
    $mf = Join-Path $rootFull '.mission\mission.yaml'
    if (Test-Path -LiteralPath $mf -PathType Leaf) { $missionId = Get-MissionTelemetryYamlScalar -Text ([System.IO.File]::ReadAllText($mf)) -Key 'id' }
    # A [string] parameter turns $null into '', so the version written is held apart (row 567).
    $fwVersion = if ($FrameworkVersion) { $FrameworkVersion } else { Get-MissionFrameworkVersion -Root $rootFull -PrimaryRoot $PrimaryRoot }

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
        [void]$sb.Append("  framework_version: $(& $q $fwVersion)`n")
        $bytes = $utf8.GetBytes($sb.ToString())
        $fs = [System.IO.File]::Open($reg, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
        $added = $true
    }

    $tdir = Join-Path $rootFull '.mission-runtime\telemetry'
    $tdirMade = $false
    if (-not (Test-Path -LiteralPath $tdir -PathType Container)) { New-Item -ItemType Directory -Path $tdir -Force | Out-Null; $tdirMade = $true }
    return [pscustomobject]@{ host_id = $hostId; checkout_path = $rootFull; mission_id = $missionId; row_added = $added; registry = $reg; telemetry_dir = $tdir
                              host_id_path = $hp; host_id_made = $hostMade; telemetry_made = $tdirMade }
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
        return (Register-MissionCheckout -Root $WorktreeRoot -PrimaryRoot ([System.IO.Path]::GetFullPath($PrimaryRoot)))
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

function Get-MissionTelemetryPlainWhy {
    # RELEASE-5 group B (validator round 1): a reason carried into the feed names no absolute path -- the mission root is
    # written <mission root>, the framework's tools folder <tools>.
    param([AllowNull()][string]$Text, [string]$Root)
    if (-not $Text) { return $Text }
    $t = $Text
    foreach ($p in @(@(
        @($(try { [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') } catch { $null }), '<mission root>'),
        @($(try { [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/') } catch { $null }), '<tools>')))) {
        if ($p[0]) { $t = [regex]::Replace($t, [regex]::Escape($p[0]), $p[1], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) }
    }
    return $t
}

function Get-MissionTelemetryNoHostPath {
    # RELEASE-5 group B, amendment 1 (validator round 1): a reason carried into the feed names NO host path at all. The mission
    # root and the tools folder are written as Get-MissionTelemetryPlainWhy writes them; any other drive-rooted or UNC path the
    # text still holds -- a goal file or an evaluator beside the checkout, named in another tool's own message -- is written
    # '<outside the mission root>/<its last name>'. A path is read up to a space, a quote or a bracket, so a folder name
    # holding a space keeps the words after that space (no drive, no folder above them).
    param([AllowNull()][string]$Text, [string]$Root)
    $t = Get-MissionTelemetryPlainWhy -Text $Text -Root $Root
    if (-not $t) { return $t }
    return [regex]::Replace($t, '(?:[A-Za-z]:[\\/]|\\\\)[^\s''"()<>\[\]]*', {
        param($m)
        $leaf = ($m.Value.TrimEnd('\', '/') -split '[\\/]')[-1]
        '<outside the mission root>/' + $leaf.TrimEnd('.', ',', ';', ':') })
}

function Get-MissionLiftedModule {
    # RELEASE-5 group B: A RULE ANOTHER TOOL OWNS, CALLED -- NEVER RESTATED. The close tool (tools/mission-close-milestone.ps1)
    # and the stop evaluator (tools/lam/mission-goal-check.ps1) are scripts that act when run, so neither can be dot-sourced.
    # Their rule functions are lifted here with the PowerShell parser, THEIR TEXT EXACTLY AS THE FILE HOLDS IT: the -Roots
    # and every function of the same file they call, transitively (a function the file defines twice is taken as it stands
    # last, as a run of the file would leave it), with the file's own top-level statements that assign -ScriptVars, the
    # -DotSource files dot-sourced first, at -Preference -- all inside a dynamic module of their own that exports nothing,
    # so nothing they define or set reaches the verb that asked. Throws when the file is absent, does not parse, or lacks
    # a root or one of the variables.
    # -Append (amendment 1, RB-17): text added inside the module after the lifted functions -- a wrapper the caller composes
    # from Get-MissionLiftedStatements, so the file's own top-level statements run beside its functions.
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string[]]$Roots, [string[]]$ScriptVars = @(),
          [string[]]$DotSource = @(), [string]$Preference = 'Stop', [string]$Append = '')
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "not on disk: $Path" }
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tok, [ref]$err)
    if ($err -and $err.Count) { throw "does not parse: $Path ($($err[0].Message))" }
    $defs = @{}
    foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) { $defs[$f.Name] = $f }
    $seen = @{}; $order = New-Object System.Collections.Generic.List[string]
    $queue = New-Object System.Collections.Queue
    foreach ($r in $Roots) { if (-not $defs.ContainsKey($r)) { throw "$Path defines no function $r" }; $queue.Enqueue($r) }
    while ($queue.Count -gt 0) {
        $n = [string]$queue.Dequeue()
        if ($seen.ContainsKey($n)) { continue }
        $seen[$n] = $true; $order.Add($defs[$n].Name)
        foreach ($c in $defs[$n].Body.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $cn = $c.GetCommandName()
            if ($cn -and $defs.ContainsKey($cn) -and -not $seen.ContainsKey($cn)) { $queue.Enqueue($cn) }
        }
    }
    $assigns = @($ast.FindAll({ param($x) ($x -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
                    ($x.Left -is [System.Management.Automation.Language.VariableExpressionAst]) -and
                    ($ScriptVars -contains $x.Left.VariablePath.UserPath) }, $false))
    foreach ($v in $ScriptVars) { if (@($assigns | Where-Object { $_.Left.VariablePath.UserPath -eq $v }).Count -eq 0) { throw "$Path assigns no `$$v at top level" } }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("`$ErrorActionPreference = '$Preference'")
    foreach ($d in $DotSource) {
        if (-not (Test-Path -LiteralPath $d -PathType Leaf)) { throw "not on disk: $d" }
        [void]$sb.AppendLine(". '" + ($d -replace "'", "''") + "'")
    }
    foreach ($a in $assigns) { [void]$sb.AppendLine($a.Extent.Text) }
    foreach ($n in $order) { [void]$sb.AppendLine($defs[$n].Extent.Text) }
    if ($Append) { [void]$sb.AppendLine($Append) }
    [void]$sb.AppendLine('Export-ModuleMember -Function @() -Variable @() -Alias @()')
    return (New-Module -ScriptBlock ([scriptblock]::Create($sb.ToString())))
}

function Get-MissionLiftedStatements {
    # RELEASE-5 group B, amendment 1 (RB-17): A FILE'S OWN TOP-LEVEL STATEMENTS, LIFTED -- NEVER RESTATED. Where a rule another
    # tool owns is not a function but a run of its script's top-level statements (the stop evaluator composes a goal's HALT
    # scope that way), the run is taken with the PowerShell parser, THE TEXT EXACTLY AS THE FILE HOLDS IT: for each range
    # @(<first>, <last>), the top-level statement whose text begins with <first>, through the first statement at or after it
    # whose text begins with <last>. Returns one text per range. Throws when the file is absent or does not parse, or a
    # range's first statement is not exactly one, or its last is not found -- so an evaluator that moved its rule refuses
    # the lift, and the caller says so, rather than running something else.
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object[]]$Ranges)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "not on disk: $Path" }
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tok, [ref]$err)
    if ($err -and $err.Count) { throw "does not parse: $Path ($($err[0].Message))" }
    $sts = @($ast.EndBlock.Statements)
    $texts = New-Object System.Collections.Generic.List[string]
    foreach ($rg in $Ranges) {
        $first = [string]$rg[0]; $last = [string]$rg[1]
        $at = @(for ($i = 0; $i -lt $sts.Count; $i++) { if ($sts[$i].Extent.Text.StartsWith($first, [System.StringComparison]::Ordinal)) { $i } })
        if ($at.Count -ne 1) { throw "$Path holds $($at.Count) top-level statement(s) beginning '$first'" }
        $to = -1
        for ($i = $at[0]; $i -lt $sts.Count; $i++) { if ($sts[$i].Extent.Text.StartsWith($last, [System.StringComparison]::Ordinal)) { $to = $i; break } }
        if ($to -lt 0) { throw "$Path holds no top-level statement beginning '$last' at or after '$first'" }
        $sb = New-Object System.Text.StringBuilder
        for ($i = $at[0]; $i -le $to; $i++) { [void]$sb.AppendLine($sts[$i].Extent.Text) }
        $texts.Add($sb.ToString())
    }
    return , $texts.ToArray()
}

function Get-MissionStopHookGoal {
    # RELEASE-5 group B, amendment 1 (RB-17, ruling (r)): THE GOAL THE MISSION'S STOP HOOK IS REGISTERED FOR, read from where
    # the mission records it: the checkout's own .claude/settings.json and .claude/settings.local.json (the harness's project
    # settings -- READ, never written), each Stop hook command that runs tools/lam/mission-goal-check.ps1, and the -Goal (and
    # -GoalFile) it passes; the evaluator reads no settings file -- it is run with that command line. Returns {read, goal,
    # goal_file_arg, named_in, why}: read only where every such command names ONE goal; with none, several, or a settings file
    # that does not parse, no goal is read and why says so. A Stop hook registered only in the user's own settings is not read.
    param([Parameter(Mandatory = $true)][string]$Root)
    $named = New-Object System.Collections.Generic.List[object]
    $why = $null
    foreach ($rel in @('.claude/settings.json', '.claude/settings.local.json')) {
        $p = Join-Path $Root ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        $j = $null
        try { $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json } catch { $why = "$rel does not parse as JSON, so the goal its Stop hook runs for cannot be read"; continue }
        $stop = Get-MissionTelemetryMember (Get-MissionTelemetryMember $j 'hooks') 'Stop'
        foreach ($grp in @($stop)) {
            foreach ($h in @(Get-MissionTelemetryMember $grp 'hooks')) {
                $cmd = [string](Get-MissionTelemetryMember $h 'command')
                if ($cmd -notmatch '(?i)mission-goal-check\.ps1') { continue }
                # (validator round 1: a PowerShell parameter may also be written -Goal:<value>)
                $gm = [regex]::Match($cmd, '(?i)(?:^|\s)-Goal(?::|\s+)(?:"([^"]*)"|''([^'']*)''|([^\s"'']+))')
                $fm = [regex]::Match($cmd, '(?i)(?:^|\s)-GoalFile(?::|\s+)(?:"([^"]*)"|''([^'']*)''|([^\s"'']+))')
                $gv = @(if ($gm.Success) { @($gm.Groups[1].Value, $gm.Groups[2].Value, $gm.Groups[3].Value) | Where-Object { $_ } })
                $fv = @(if ($fm.Success) { @($fm.Groups[1].Value, $fm.Groups[2].Value, $fm.Groups[3].Value) | Where-Object { $_ } })
                $g = if ($gv.Count) { [string]$gv[0] } else { $null }
                $f = if ($fv.Count) { [string]$fv[0] } else { $null }
                # the evaluator file the hook runs (builder-side review: its census is the one beside IT, which may not be
                # the one beside this writer -- mission.ps1 register runs the release folder's writer)
                $em = [regex]::Match($cmd, '(?i)"([^"]*mission-goal-check\.ps1)"|''([^'']*mission-goal-check\.ps1)''|([^\s"'']*mission-goal-check\.ps1)')
                $ev = @($em.Groups[1].Value, $em.Groups[2].Value, $em.Groups[3].Value) | Where-Object { $_ } | Select-Object -First 1
                $named.Add([pscustomobject]@{ file = $rel; goal = $g; goal_file = $f; evaluator = [string]$ev })
            }
        }
    }
    $distinct = @($named | ForEach-Object { [string]$_.goal + '|' + [string]$_.goal_file + '|' + [string]$_.evaluator } | Select-Object -Unique)
    $files = @($named | ForEach-Object { $_.file } | Select-Object -Unique)
    $none = [ordered]@{ read = $false; goal = $null; goal_file_arg = $null; evaluator_arg = $null; named_in = $files; why = $null }
    if ($why) { $none.why = $why; return $none }
    if ($named.Count -eq 0) { $none.why = 'no Stop hook in .claude/settings.json or .claude/settings.local.json runs tools/lam/mission-goal-check.ps1'; return $none }
    if (@($named | Where-Object { -not $_.goal }).Count) { $none.why = 'a Stop hook runs tools/lam/mission-goal-check.ps1 with no -Goal'; return $none }
    if ($distinct.Count -gt 1) {
        $none.why = "the Stop hooks name $($distinct.Count) goals or evaluators ($((@($named | ForEach-Object { $_.goal } | Select-Object -Unique)) -join ', ')) -- the HALT card honours the exceptions of one goal, and none is chosen"
        return $none
    }
    return [ordered]@{ read = $true; goal = [string]$named[0].goal; goal_file_arg = $named[0].goal_file; evaluator_arg = [string]$named[0].evaluator; named_in = $files; why = $null }
}

function Get-MissionSpecMilestoneBlocks {
    # The spec's milestones list as the snapshot reads it (UI-1 S2-AM1, U-17): every block in the order the spec writes it, as
    # {id, title, word, ids} -- word the status as the spec writes it ($null for none), ids the assertion ids the block lists.
    # SS2's Milestone writes title / contract_assertion_ids; a spec writing name / assertions is read alike. RELEASE-5 group B,
    # amendment 3: the parse the milestones map always made, moved here unchanged and made once, before the assertions are
    # read, so the assertion reading knows which milestones are closed; the milestones map below reads the same blocks.
    param([AllowNull()][string]$SpecText)
    # (returned inside one object, .blocks: an empty array returned bare reads back as $null, which strict mode will not count)
    $out = New-Object System.Collections.ArrayList
    $box = [pscustomobject]@{ blocks = $out }
    if (-not $SpecText) { return $box }
    $msec = [regex]::Match($SpecText, '(?ms)^milestones:[^\r\n]*\r?\n(.*?)(?=^[A-Za-z_]|\z)')
    if (-not $msec.Success) { return $box }
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
        [void]$out.Add([pscustomobject]@{ id = $mid; title = $title; word = $mstatus; ids = @($ids) })
    }
    return $box
}

function Get-MissionValidatorsArchive {
    # RELEASE-5 group B, amendment 3 (rulings (bk), (bl); RB-18, RB-19): THE VALIDATORS ARCHIVE -- the folder
    # .mission-runtime/lam/validators and every folder under it, where a host keeps each placed validator result under its own
    # name before the next round's preparation removes the working copy. LISTED, NEVER WRITTEN, and listed at most once per
    # snapshot (the caller lists it the first time an assertion needs it). A folder or a file that is a link (a reparse point:
    # a junction, a symbolic link) is not followed and not read, only counted -- and so is a link anywhere on the archive's own
    # path, which leaves the archive unread; nothing outside the archive is listed or opened. Returns {folder, present, listed,
    # why, files, links_not_followed, folders_unreadable, by_name}: by_name maps a result file's lowercased name to the
    # mission-root-relative paths (/-separated, in ordinal order) of every file of that name under the archive.
    param([Parameter(Mandatory = $true)][string]$Root)
    $rel = '.mission-runtime/lam/validators'
    $out = [ordered]@{ folder = $rel; present = $false; listed = $false; why = $null; files = 0; links_not_followed = 0; folders_unreadable = 0; by_name = @{} }
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $walk = $rootFull
    foreach ($seg in @('.mission-runtime', 'lam', 'validators')) {
        $walk = Join-Path $walk $seg
        $di = New-Object System.IO.DirectoryInfo $walk
        if (-not $di.Exists) {
            $here = (($walk.Substring($rootFull.Length + 1)) -replace '\\', '/')
            $out.why = if ([System.IO.File]::Exists($walk)) { "$here is a file, not a folder, so $rel is not read" } else { "$rel is not on disk" }
            return $out
        }
        if ($di.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $out.links_not_followed++
            $out.why = (($walk.Substring($rootFull.Length + 1)) -replace '\\', '/') + " is a link, which is not followed, so $rel is not read"
            return $out
        }
    }
    $out.present = $true
    $byName = @{}
    $stack = New-Object System.Collections.Stack
    $stack.Push((New-Object System.IO.DirectoryInfo $walk))
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        $ents = $null
        try { $ents = @($d.GetFileSystemInfos()) } catch { $out.folders_unreadable++; continue }
        foreach ($e in $ents) {
            if ($e.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { $out.links_not_followed++; continue }
            if ($e -is [System.IO.DirectoryInfo]) { $stack.Push($e); continue }
            if ($e.Name -notmatch '^(?i:validator-.+\.result\.yaml)$') { continue }
            $out.files++
            $k = $e.Name.ToLowerInvariant()
            if (-not $byName.ContainsKey($k)) { $byName[$k] = New-Object System.Collections.Generic.List[string] }
            $byName[$k].Add((($e.FullName.Substring($rootFull.Length + 1)) -replace '\\', '/'))
        }
    }
    foreach ($k in @($byName.Keys)) {
        $l = $byName[$k]
        $l.Sort([System.StringComparer]::Ordinal)
        $out.by_name[$k] = $l.ToArray()
    }
    $out.listed = $true
    return $out
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
    # UI-2 S2 (B-1, B-4; register row 501): each assertion's verdict in each validator round -- the round is the result's
    # attempt_number. A result's verdict reaches every assertion it lists, but a failing result that names ONE assertion
    # (assertion_id) refutes that one and CONFIRMS the others it lists: in that round they were judged and passed (the
    # result's evidence records them), where the status above lets them keep their earlier one. A later result for the same
    # assertion and round wins. Read with the contract's own binding (feature_id, milestone_id) into assertion_detail.
    $rounds = @{}
    foreach ($r in @($results | Sort-Object attempt)) {
        if (-not $r.verdict -or $r.attempt -lt 1) { continue }
        foreach ($id in @($r.ids)) {
            $v = $r.verdict
            if ($v -eq 'red' -and $r.only -and ($r.only -ne $id)) { $v = 'green' }
            if (-not $rounds.ContainsKey($id)) { $rounds[$id] = @{} }
            $rounds[$id][[int]$r.attempt] = $v
        }
    }

    # RELEASE-5 GROUP B, VERDICTS (register row 541, ruling (l)): THE RECORD THE CLOSE TOOL TRUSTS. A validator's result is
    # bound on the spawn ledger (.mission-runtime/lam/spawn-ledger.jsonl): a 'complete' line naming the assertion in its own
    # `validates`, its round, and the sha256 of the result file it binds. The close tool reads that record with
    # Resolve-LamRosterRecord (tools/mission-close-milestone.ps1), and so does this writer -- the same function, lifted
    # unchanged (Get-MissionLiftedModule), never a restatement: the highest round wins; a line with no `validates` key is not
    # read; a result file that is absent or does not re-hash to its bound sha256, or whose document does not read one verdict,
    # is not accepted; PASS is a pass, REFUTED and FAIL a refutation. An assertion that record binds takes its status from
    # it alone, as the close tool does (no fall back to the old folder); one it does not bind keeps the old folder's
    # (.mission/validator-results, read above) -- the older assertions. Rounds: each complete line's own round and verdict,
    # the current round's verdict from the document it binds. Every assertion not judged carries the reason, naming both
    # sources. One ledger line that is not JSON makes the close tool read none of it, and this writer likewise.
    # The ledger is read once; each assertion is resolved over ITS OWN RECORDS: every record (each once, in ledger order)
    # that Resolve-LamRosterRecord's candidate filter or Get-LamRosterAttempt's spawn filter can select for it -- chosen by
    # the very expressions those filters use ([string]$_.event, [string]$_.validates -eq <id>, [string]$_.seq), so a
    # record PowerShell reads through member enumeration (a line that is a JSON array) is chosen as they choose it. Over that
    # subset both filters return exactly what they return over the whole ledger, in the same order (validator round 1: the
    # first cut added a shared spawn line once per candidate, and read an array line not at all).
    # the current spec (.mission/spec/current.txt names it), read once here: its features and milestones are read below
    $st = $null
    $curF = Join-Path $Root '.mission\spec\current.txt'
    if (Test-Path -LiteralPath $curF -PathType Leaf) {
        $tok = ([System.IO.File]::ReadAllText($curF)).Trim()
        if ($tok -and $tok -notmatch '\.ya?ml$') { $tok = $tok + '.yaml' }
        $specF = Join-Path $Root (".mission\spec\" + $tok)
        if ($tok -and (Test-Path -LiteralPath $specF -PathType Leaf)) { $st = [System.IO.File]::ReadAllText($specF) }
    }
    $msBlocks = (Get-MissionSpecMilestoneBlocks -SpecText $st).blocks
    # RELEASE-5 group B, amendment 3 (ruling (bi)): CLOSED WORK. An assertion is of closed work when every milestone that holds
    # it -- the ids a milestone of the current spec lists, and the contract assertions whose milestone_id names it, as the
    # milestones map below counts them -- carries, in the spec, the status the milestones map shows as passed (done, passed);
    # an assertion no milestone holds is not closed. A milestone with no status of its own, whose passed would be derived
    # from its assertions' greens, is not closed: the mission's own state carries no status for it.
    $closedMs = @{}; $holders = @{}
    foreach ($blk in $msBlocks) {
        $closedMs[$blk.id] = ($blk.word -and ((ConvertTo-MissionMilestoneStatus -Word $blk.word) -eq 'passed'))
    }
    $msHeld = @{}
    foreach ($blk in $msBlocks) {
        $hids = @(@($blk.ids) + @($assertMilestone.Keys | Where-Object { $assertMilestone[$_] -eq $blk.id }) | Sort-Object -Unique)
        foreach ($h in $hids) { if (-not $msHeld.ContainsKey($h)) { $msHeld[$h] = New-Object System.Collections.Generic.List[string] }; if (-not $msHeld[$h].Contains($blk.id)) { $msHeld[$h].Add($blk.id) } }
    }
    $closedOf = @{}
    foreach ($h in @($msHeld.Keys)) {
        $mine = @($msHeld[$h])
        if ($mine.Count -gt 0 -and @($mine | Where-Object { -not $closedMs[$_] }).Count -eq 0) { $closedOf[$h] = $mine }
    }

    $ledgerRel = '.mission-runtime/lam/spawn-ledger.jsonl'
    $oldRel = '.mission/validator-results'
    $assertSource = @{}; $assertReason = @{}; $boundBy = @{}
    # amendment 3 (RB-24, RB-25): the evidence each judged assertion stands on, in one of four words -- working copy (the
    # result file the complete line binds, re-hashed equal where it lies), archive copy (a file of the result's own name under
    # the validators archive, re-hashed equal), record alone (the complete line, its bytes found nowhere it is read), old
    # results folder (.mission/validator-results) -- and, for the first two, the file's path from the mission root
    $assertEvidence = @{}; $assertEvidencePath = @{}; $archive = $null
    foreach ($k in @($assertions.Keys)) { if ($assertions[$k] -ne 'pending') { $assertSource[$k] = 'validator_results' } }
    $assertionReading = [ordered]@{
        rule = 'an assertion the spawn ledger binds: the close tool''s own reader, Resolve-LamRosterRecord of tools/mission-close-milestone.ps1, over ' + $ledgerRel + '; any other: ' + $oldRel
        spawn_ledger = $ledgerRel; present = $false; lines_not_json = 0; complete_without_validates = 0; reader = $null }
    $ledgerWhy = $null; $byAid = @{}; $spawnBySeq = @{}; $closeMod = $null; $ledger = $null
    try {
        $closeMod = Get-MissionLiftedModule -Path (Join-Path $PSScriptRoot '..\mission-close-milestone.ps1') -Roots @('Read-LamSpawnLedger', 'Resolve-LamRosterRecord')
        $ledger = & $closeMod { param($MissionLiftRoot) Read-LamSpawnLedger -Root $MissionLiftRoot } $Root
        $assertionReading.reader = 'called'
    } catch { $why0 = Get-MissionTelemetryPlainWhy -Text $_.Exception.Message -Root $Root
              $ledgerWhy = 'could not be read with the close tool''s reader (' + $why0 + ')'; $assertionReading.reader = 'not called: ' + $why0 }
    $recs = @()
    if ($null -ne $ledger) {
        $assertionReading.present = [bool]$ledger.Present
        $assertionReading.lines_not_json = @($ledger.Bad).Count
        if (-not $ledger.Present) { $ledgerWhy = 'is not on disk' }
        elseif (@($ledger.Bad).Count -gt 0) { $ledgerWhy = "holds $(@($ledger.Bad).Count) line(s) that are not JSON, so the close tool reads none of it" }
        else {
            $recs = @($ledger.Records)
            # THE READER'S OWN EXPRESSIONS, EVALUATED IN THE READER'S OWN SCOPE: the lifted module, as the close tool runs
            # them -- not under the strict mode the verb's telemetry scope inherits from the hooks' library, where reading a
            # key a record lacks throws (found by RB-15's member running mission.ps1 register)
            $meta = & $closeMod { param($L)
                $o = New-Object System.Collections.ArrayList
                foreach ($r in $L) { [void]$o.Add(@([string]$r.event, [string]$r.validates, [string]$r.seq, $r.round, [string]$r.verdict)) }
                , $o.ToArray() } $recs
            for ($ri = 0; $ri -lt $recs.Count; $ri++) {
                $ev = [string]$meta[$ri][0]
                if ($ev -eq 'spawn') {
                    $sk = [string]$meta[$ri][2]
                    if (-not $spawnBySeq.ContainsKey($sk)) { $spawnBySeq[$sk] = New-Object System.Collections.ArrayList }
                    [void]$spawnBySeq[$sk].Add($ri)
                } elseif ($ev -eq 'complete') {
                    $va = [string]$meta[$ri][1]
                    if (-not $va) { $assertionReading.complete_without_validates++; continue }
                    $vk = $va.ToLowerInvariant()
                    if (-not $byAid.ContainsKey($vk)) { $byAid[$vk] = New-Object System.Collections.ArrayList }
                    [void]$byAid[$vk].Add($ri)
                }
            }
        }
    }
    $noValidates = if ($assertionReading.complete_without_validates -gt 0) { " (the ledger also holds $($assertionReading.complete_without_validates) complete line(s) with no validates key, which the close tool reads for no assertion)" } else { '' }
    foreach ($aid in @($assertions.Keys | Sort-Object)) {
        $oldWord = $assertions[$aid]
        $vk = ([string]$aid).ToLowerInvariant()
        $ledgerPart = $null; $keptPart = $null
        $candIdx = @()
        if ((-not $ledgerWhy) -and $byAid.ContainsKey($vk)) { $candIdx = @($byAid[$vk] | Where-Object { [string]$meta[$_][1] -eq $aid }) }
        if ($ledgerWhy) { $ledgerPart = $ledgerWhy }
        elseif ($candIdx.Count -eq 0) { $ledgerPart = 'has no complete line whose validates names it' + $noValidates }
        else {
            $pick = New-Object 'System.Collections.Generic.SortedSet[int]'
            foreach ($ci in $candIdx) {
                [void]$pick.Add($ci)
                $sk = [string]$meta[$ci][2]
                if ($spawnBySeq.ContainsKey($sk)) { foreach ($si in $spawnBySeq[$sk]) { [void]$pick.Add($si) } }
            }
            # collected with Add, never through the pipeline, which would unroll an array record into its elements
            $candList = New-Object System.Collections.ArrayList; foreach ($ci in $candIdx) { [void]$candList.Add($recs[$ci]) }
            $ownList = New-Object System.Collections.ArrayList; foreach ($pi in $pick) { [void]$ownList.Add($recs[$pi]) }
            $cands = $candList.ToArray()
            $own = [pscustomobject]@{ Path = $ledger.Path; Present = $true; Records = $ownList.ToArray(); Bad = @() }
            $res = & $closeMod { param($MissionLiftRoot, $MissionLiftId, $MissionLiftLedger) Resolve-LamRosterRecord -Root $MissionLiftRoot -AssertionId $MissionLiftId -Ledger $MissionLiftLedger } $Root $aid $own
            $boundBy[$aid] = $res
            # the record's rounds alone: the old folder's are not read once the ledger binds the assertion (validator round 1)
            # -- each candidate at the attempt the close tool's own Get-LamRosterAttempt orders it at: `round` where the tool's
            # [int] cast reads it (a string numeral included), else the round_number on it and its one paired spawn line (a
            # LABEL round); a candidate the tool cannot order, or with no round at all, is shown at none (validator round 2)
            $rounds[$aid] = @{}
            foreach ($ci in $candIdx) {
                if ($null -eq $meta[$ci][3]) { continue }
                $att = & $closeMod { param($C, $L, $A) Get-LamRosterAttempt -Cand $C -Ledger $L -AssertionId $A } $recs[$ci] $own $aid
                if ((-not $att.Ok) -or ($null -eq $att.Attempt)) { continue }
                # rounds are shown from 1, as the ledger's composer admits them (spawn_ledger.py rule (6))
                if ([int]$att.Attempt -lt 1) { continue }
                $w = & $verdictOf ([string]$meta[$ci][4])
                # validator round 1 (amendment 1): a round the reader orders is shown though its line states no verdict (the
                # reader allows the key absent) -- without one; a line that states one at the same round is not overwritten
                if (-not $w) { if (-not $rounds[$aid].ContainsKey([int]$att.Attempt)) { $rounds[$aid][[int]$att.Attempt] = $null }; continue }
                $rounds[$aid][[int]$att.Attempt] = $w
            }
            $assertSource[$aid] = 'spawn_ledger'
            # RELEASE-5 group B, amendment 3 (rulings (bi), (bk), (bl)): KEPT EVIDENCE FOR CLOSED WORK. The close tool's reader
            # refuses a binding whose result file is ABSENT, and for a close in progress that refusal stands. For an assertion of
            # closed work, and for that refusal alone -- never a file present that fails its comparison (ruling (bl)) -- the
            # writer reads what stands in for the removed working copy, from THE COMPLETE LINE THE READER ITSELF SELECTED (its
            # seq, at the round it ordered): first a file of the result's own name under the validators archive whose bytes
            # satisfy the reader's own comparison -- the reader is called again over a copy of that one line pointing at the
            # file, so the hash comparison and the verdict read are its own -- else the record alone, the verdict that line
            # states. What a close accepts is not changed: the close tool reads none of this.
            $kept = $null
            if ((-not $res.Ok) -and ([string]$res.Cause -eq 'RESULT FILE ABSENT') -and $closedOf.ContainsKey($aid)) {
                if ($null -eq $archive) { $archive = Get-MissionValidatorsArchive -Root $Root }
                $leaf = ('validator-' + [string]$aid + '.result.yaml').ToLowerInvariant()
                $copies = @(if ($archive.by_name.ContainsKey($leaf)) { $archive.by_name[$leaf] })
                $kept = & $closeMod { param($KRoot, $KId, $KCands, $KOwn, $KRes, $KCopies)
                    $o = @{ selected = $false; why = $null; bound = $null; prose = $null; verified = $null; refused = $null; differing = 0; unreadable = 0; unread = $null }
                    $hit = New-Object System.Collections.ArrayList
                    foreach ($c in $KCands) {
                        $one = $c
                        if ($one -is [array]) { if (@($one).Count -eq 1 -and ($one[0] -is [System.Management.Automation.PSCustomObject])) { $one = $one[0] } else { continue } }
                        if (-not ($one -is [System.Management.Automation.PSCustomObject])) { continue }
                        if (([string]$one.seq -ne [string]$KRes.Seq) -or ($null -eq $one.result_sha256)) { continue }
                        $att = Get-LamRosterAttempt -Cand $c -Ledger $KOwn -AssertionId $KId
                        if ((-not $att.Ok) -or ([int]$att.Attempt -ne [int]$KRes.Round)) { continue }
                        [void]$hit.Add(@($c, $one))
                    }
                    if ($hit.Count -ne 1) { $o.why = "$($hit.Count) complete line(s) answer to the one it selected (seq $($KRes.Seq), round $($KRes.Round))"; return $o }
                    $orig = $hit[0][0]; $sel = $hit[0][1]
                    $o.selected = $true
                    $o.bound = ([string]$sel.result_sha256).ToLower()
                    if ($null -ne $sel.verdict) { $o.prose = [string]$sel.verdict }
                    foreach ($kc in $KCopies) {
                        $clone = $sel.PSObject.Copy()
                        if ($clone.PSObject.Properties['result_path']) { $clone.result_path = $kc } else { $clone | Add-Member -NotePropertyName result_path -NotePropertyValue $kc }
                        $kr = New-Object System.Collections.ArrayList
                        foreach ($r in $KOwn.Records) { if ([object]::ReferenceEquals($r, $orig)) { [void]$kr.Add($clone) } else { [void]$kr.Add($r) } }
                        $kl = [pscustomobject]@{ Path = $KOwn.Path; Present = $true; Records = $kr.ToArray(); Bad = @() }
                        # validator round 1: a copy the reader cannot open (held by another process, say) throws inside its
                        # Get-FileHash; it is counted and named, and the snapshot is still derived -- never the record alone over
                        # it, since its bytes may be the bound ones
                        $r2 = $null
                        try { $r2 = Resolve-LamRosterRecord -Root $KRoot -AssertionId $KId -Ledger $kl }
                        catch { $o.unreadable++; if ($null -eq $o.unread) { $o.unread = @{ rel = $kc; why = [string]$_.Exception.Message } }; continue }
                        if ($r2.Ok) { $o.verified = @{ rel = $kc; verdict = [string]$r2.Verdict; raw = [string]$r2.RawVerdict }; break }
                        if ([string]$r2.Cause -eq 'SHA256 MISMATCH') { $o.differing++; continue }
                        if ([string]$r2.Cause -eq 'RESULT FILE ABSENT') { continue }
                        if ($null -eq $o.refused) { $o.refused = @{ rel = $kc; cause = [string]$r2.Cause; reason = [string]$r2.Reason } }
                    }
                    return $o
                } $Root $aid $cands $own $res $copies
            }
            if ($null -ne $kept) {
                $msNames = (@($closedOf[$aid]) -join ', ')
                $kLine = "the spawn ledger's complete line seq $($res.Seq) (round $($res.Round), dispatch $($res.DispatchId))"
                # (validator round 2: "looked for", not "read" -- the archive may be absent, a link or a file)
                $gone = "that working copy is gone, and the milestone holding the assertion ($msNames) is closed, so its kept evidence was looked for"
                $arcNote = if (-not $archive.listed) { "$($archive.folder): not read -- $($archive.why)" }
                           else { "$($archive.folder): $($copies.Count) file(s) named validator-$aid.result.yaml$(if ($kept.differing -gt 0) { ", $($kept.differing) holding other bytes" })$(if ($archive.links_not_followed -gt 0) { "; $($archive.links_not_followed) link(s) under it not followed" })" }
                $kw = $null; $kWord = $null; $kPath = $null; $kWhy = $null
                if (-not $kept.selected) {
                    $kWhy = "and the kept evidence could not be read for it: $($kept.why)"
                } elseif ($null -ne $kept.verified) {
                    $kw = switch ($kept.verified.verdict) { 'pass' { 'green' } 'fail' { 'red' } default { $null } }
                    $kWord = 'archive copy'; $kPath = $kept.verified.rel
                    $kWhy = "judged on an archive copy -- $kLine binds $($res.ResultRel) by sha256 $($kept.bound); ${gone}: the bound bytes were verified at $($kept.verified.rel) under the validators archive, which re-hashes equal to the bound figure and reads verdict '$($kept.verified.raw)' ($arcNote)"
                    if (-not $kw) { $kWhy = "and its kept evidence holds no verdict: the archive copy $($kept.verified.rel) re-hashes equal to the bound figure and reads '$($kept.verified.raw)', which is neither a pass nor a refutation" }
                } elseif ($null -ne $kept.refused) {
                    $kWhy = "and its kept evidence is refused: the archive copy $($kept.refused.rel) is not accepted by the close tool's reader -- $($kept.refused.cause): $(Get-MissionTelemetryPlainWhy -Text ([string]$kept.refused.reason) -Root $Root)"
                } elseif ($archive.folders_unreadable -gt 0) {
                    # validator round 2: a folder under the archive that could not be listed may hold the bound bytes, as an
                    # unreadable file may -- so neither stands as the record alone
                    $kWhy = "and its kept evidence could not be read whole: $($archive.folders_unreadable) folder(s) under the validators archive could not be listed, and no copy found holds the bound bytes -- so neither an archive copy nor the record alone is read"
                } elseif ($kept.unreadable -gt 0) {
                    $kWhy = "and its kept evidence could not be read: $($kept.unreadable) file(s) named validator-$aid.result.yaml under the validators archive could not be opened by the close tool's reader (the first, $($kept.unread.rel): $(Get-MissionTelemetryNoHostPath -Text ([string]$kept.unread.why) -Root $Root)), and no other copy holds the bound bytes -- so neither an archive copy nor the record alone is read"
                } else {
                    # THE RECORD ALONE: the verdict the selected complete line states, read in the reader's own vocabulary (its
                    # Get-LamResultVerdict: PASS a pass; REFUTED and FAIL a refutation; any other word neither)
                    $raw = if ($null -ne $kept.prose) { $kept.prose.Trim().Trim('"').Trim("'").Trim() } else { $null }
                    $kw = if ($null -eq $raw) { $null } else { switch ($raw.ToUpper()) { 'PASS' { 'green' } 'REFUTED' { 'red' } 'FAIL' { 'red' } default { $null } } }
                    $placesRead = "the working copy's place ($($res.ResultRel)) and the validators archive ($arcNote)"
                    if ($kw) {
                        $kWord = 'record alone'
                        $kWhy = "judged on the record alone -- $kLine binds $($res.ResultRel) by sha256 $($kept.bound) and states verdict '$raw'; ${gone}: no copy with the bound bytes was found in either place looked in, $placesRead, so the bytes are not verified and the complete line alone stands for them"
                    } elseif ($null -eq $raw) {
                        $kWhy = "and the record alone holds no verdict: no copy with the bound bytes was found in either place looked in, $placesRead, and the complete line states no verdict"
                    } else {
                        $kWhy = "and the record alone holds no verdict: no copy with the bound bytes was found in either place looked in, $placesRead, and the complete line states '$raw', which is neither a pass nor a refutation"
                    }
                }
                if ($kw) {
                    if (-not $rounds.ContainsKey($aid)) { $rounds[$aid] = @{} }
                    $rounds[$aid][[int]$res.Round] = $kw
                    $assertions[$aid] = $kw
                    $assertEvidence[$aid] = $kWord; $assertEvidencePath[$aid] = $kPath
                    $assertReason[$aid] = $kWhy
                    continue
                }
                $keptPart = $kWhy
            }
            if ($res.Ok) {
                $w = switch ([string]$res.Verdict) { 'pass' { 'green' } 'fail' { 'red' } default { $null } }
                if ($null -ne $res.Round) {
                    if (-not $rounds.ContainsKey($aid)) { $rounds[$aid] = @{} }
                    if ($w) { $rounds[$aid][[int]$res.Round] = $w } else { $rounds[$aid].Remove([int]$res.Round) }
                }
                # amendment 3: the evidence word -- the working copy, re-hashed equal where the complete line binds it
                if ($w) { $assertions[$aid] = $w; $assertEvidence[$aid] = 'working copy'; $assertEvidencePath[$aid] = $res.ResultRel; continue }
                $assertions[$aid] = 'pending'
                $ledgerPart = "binds a result (round $($res.Round), seq $($res.Seq)) whose document reads '$($res.RawVerdict)', which is neither a pass nor a refutation"
            } else {
                # the current round has no verdict the close tool accepts: none is shown for it -- ONLY THE ROUND THE READER ITSELF
                # NAMES as the one it refuses (amendment 1, RB-2): its .Round, set once it has taken the current round (an unbound,
                # absent, mismatched or unreadable current result); else the round its own reason names in the words "the highest
                # round (N) for <id>" (the highest round held only by lines that bind no result, or claimed by several). Where it
                # refuses naming none -- a candidate with no round, an attempt Get-LamRosterAttempt cannot order, or, beside a line
                # that binds no result, a candidate whose round is no JSON integer ("this gate will not assume where it stands")
                # -- it took no round as current, and every round it orders is shown (validator rounds 2, 3 and 4)
                # (the round named is one the tool's [int] holds: any value [int]::TryParse reads, ten digits included)
                $named = [regex]::Match([string]$res.Reason, '^the highest round \((-?\d+)\) for ')
                $namedN = 0
                $cur = if ($null -ne $res.Round) { [int]$res.Round }
                       elseif ($named.Success -and [int]::TryParse($named.Groups[1].Value, [System.Globalization.NumberStyles]::AllowLeadingSign, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$namedN)) { $namedN }
                       else { $null }
                if ($null -ne $cur -and $rounds.ContainsKey($aid)) { $rounds[$aid].Remove([int]$cur) }
                $assertions[$aid] = 'pending'
                $ledgerPart = "binds a result the close tool does not accept -- $($res.Cause): $(Get-MissionTelemetryPlainWhy -Text ([string]$res.Reason) -Root $Root)"
                if ($keptPart) { $ledgerPart += "; $keptPart" }
            }
        }
        if ($assertions[$aid] -eq 'green' -or $assertions[$aid] -eq 'red') {
            # amendment 3: an assertion the spawn ledger does not bind keeps the old results folder's verdict -- its evidence word
            if (-not $assertEvidence.ContainsKey($aid)) { $assertEvidence[$aid] = 'old results folder'; $assertEvidencePath[$aid] = $null }
            continue
        }
        $oldPart = if ($assertSource[$aid] -eq 'spawn_ledger' -and $oldWord -ne 'pending') { "records '$oldWord', which the close tool does not read once the spawn ledger binds the assertion" }
                   elseif ($oldWord -eq 'skipped') { 'records it skipped, which is no verdict' }
                   else { 'holds no verdict for it' }
        $assertReason[$aid] = "not judged -- neither source holds a verdict the close tool would accept: the spawn ledger ($ledgerRel) $ledgerPart; the old results folder ($oldRel) $oldPart"
    }

    # features: ids from the spec current.txt names; the spec's status where it writes one, else derived
    # (the spec read once, above the assertions -- amendment 3)
    $features = @{}
    if ($true) {
        if ($st) {
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
    $milestoneTally = @{}
    if ($st) {
        if ($msBlocks.Count -gt 0) {
            $found = @{}
            foreach ($blk in $msBlocks) {
                $mid = $blk.id; $title = $blk.title; $mstatus = $blk.word; $ids = @($blk.ids)
                $ids += @($assertMilestone.Keys | Where-Object { $assertMilestone[$_] -eq $mid })
                $ids = @($ids | Sort-Object -Unique)
                $green = @($ids | Where-Object { $assertions[$_] -eq 'green' }).Count
                # RELEASE-5 group B (RB-4): the milestone's tally of its JUDGED assertions (green or red), from this same map
                $judged = @($ids | Where-Object { $assertions[$_] -eq 'green' -or $assertions[$_] -eq 'red' }).Count
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
                # RELEASE-5 group B (RB-4): the tally rides its own payload key -- a milestones entry keeps its six fields (WP-7 U-17)
                # amendment 3 (RB-25): and its assertions judged on the record alone, counted apart
                $recordAlone = @($ids | Where-Object { $assertEvidence[$_] -eq 'record alone' }).Count
                $milestoneTally[$mid] = [ordered]@{ assertions_total = $ids.Count; assertions_green = $green; assertions_judged = $judged; assertions_record_alone = $recordAlone }
            }
            foreach ($k in @($found.Keys | Sort-Object)) { $milestones[$k] = $found[$k] }
        }
    }

    # UI-2 S2 (B-4, B-8): each dispatch as its record states it -- feature_id, assertion_targets -- and its state. The dashboard
    # reads a dispatch's validator rounds over its assertion_targets, and a dispatch first seen in a snapshot as opened then.
    # RELEASE-5 GROUP B, DISPATCHES (RB-11, register row 564): WHAT OPEN MEANS. 1.3.0 held open every dispatch with no plain
    # <id>.handoff.yaml beside it. A dispatch is OPEN only when the spawn ledger holds a spawn line for it and no complete
    # line, and no handoff, rejection or aborted record stands beside it: a worker running. Every other shape has a word of
    # its own saying what disk holds, in this order (the first that holds):
    #   superseded                 <id>.superseded.yaml beside it
    #   handed_off                 a plain <id>.handoff.yaml that is no rejection record
    #   complete_handoff_rejected  a rejection record -- the plain handoff reading `status: rejected`, or an archived
    #                              <id>.handoff.rejected-stub* -- and a complete line on the spawn ledger
    #   handoff_rejected           a rejection record and no complete line (other than one naming a refusal), or the
    #                              spawn ledger cannot be read
    #   aborted                    archived <id>.handoff.aborted-seq* / <id>.anchors.aborted-seq* files only
    # Below the records beside it, a dispatch is read as ONE ATTEMPT: each spawn line in ledger order is an attempt -- the
    # complete line(s) paired with it (the same seq) and the runner's refusal notes written after it -- and the one read is the
    # LATEST ATTEMPT NOT REFUSED BEFORE ITS SPAWN (amendment 1): the runner runs an id again after a refusal before its spawn
    # ("this dispatch id runs again unchanged", tools/lam/mission-dispatch.ps1), its id-reuse guard refuses an id that already
    # ran, and a seat's spawn line is written before the runner runs (spawn_ledger.py rule (15): the complete line of a spawn
    # the runner refused before spawning names REFUSED-BEFORE-SPAWN-<CODE>) -- a refusal before spawn creates nothing, so it
    # never hides an earlier attempt, and an earlier attempt's refusal never decides a later one (validator round 2). Where
    # every attempt was refused before its spawn, the latest is read. With no spawn line, every complete line and note is
    # read. Of that attempt:
    #   complete_no_handoff        a complete line naming no refusal, and no handoff, rejection or aborted record
    #   refused_before_spawn       a refusal BEFORE the spawn: a complete line or a runner note whose refusal token is
    #                              REFUSED-BEFORE-SPAWN-*, or whose outcome is REFUSED-BEFORE-SPAWN (the runner's own note:
    #                              outcome REFUSED-BEFORE-SPAWN, refusal LOGIN-PROBE-<CODE>), or that reads "before spawn"
    #   complete_refused           a complete line naming any other refusal: the spawn ran and left no result
    #   runner_refused             a spawn and, after it, the runner's own refusal note of a run that ended -- NO-RESULT-AT-
    #                              SESSION-END-*, RESULT-PLACEMENT-* -- and no complete line yet: nothing is running
    #   open                       a spawn line and none of the above: a worker running
    #   not_spawned                the dispatch file alone, no spawn-ledger line
    #   ledger_unreadable          nothing beside it, and the spawn ledger cannot be read (a line that is not JSON)
    # basis states what was read, in words. counts.open_dispatches counts open. A complete line that names no dispatch_id is
    # read through its spawn line's (the same seq), as the ledger's own pairing rule reads it (validator round 1).
    $ddir = Join-Path $Root '.mission\dispatches'
    $spawnSeqDid = @{}; $ledgerBy = @{}
    $ledgerOk = ($null -ne $ledger) -and $ledger.Present -and (@($ledger.Bad).Count -eq 0)
    if ($ledgerOk) {
        $lrecs = @($ledger.Records)
        foreach ($rec in $lrecs) {
            $sdk = [string](Get-MissionTelemetryMember $rec 'dispatch_id')
            if ([string](Get-MissionTelemetryMember $rec 'event') -eq 'spawn' -and $sdk) { $spawnSeqDid[[string](Get-MissionTelemetryMember $rec 'seq')] = $sdk }
        }
        # each dispatch's spawn, complete and refusal-note lines, in ledger order: [index, event, seq, record]
        for ($li = 0; $li -lt $lrecs.Count; $li++) {
            $rec = $lrecs[$li]
            $ev = [string](Get-MissionTelemetryMember $rec 'event')
            $dk = [string](Get-MissionTelemetryMember $rec 'dispatch_id')
            if (-not $dk -and $ev -eq 'complete') { $dk = [string]$spawnSeqDid[[string](Get-MissionTelemetryMember $rec 'seq')] }
            if (-not $dk) { continue }
            if (-not (($ev -eq 'spawn') -or ($ev -eq 'complete') -or (($ev -eq 'note') -and (Get-MissionTelemetryMember $rec 'refusal')))) { continue }
            if (-not $ledgerBy.ContainsKey($dk)) { $ledgerBy[$dk] = New-Object System.Collections.ArrayList }
            [void]$ledgerBy[$dk].Add(@($li, $ev, [string](Get-MissionTelemetryMember $rec 'seq'), $rec))
        }
    }
    $dnames = @(Get-ChildItem -LiteralPath $ddir -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $openD = 0
    $dispatchDetail = [ordered]@{}
    foreach ($df in @(Get-ChildItem -LiteralPath $ddir -File -Filter '*.yaml' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ($df.Name -notmatch '^[^.]+\.yaml$') { continue }
        $b = $df.BaseName
        $dt = [System.IO.File]::ReadAllText($df.FullName)
        $did = Get-MissionTelemetryYamlScalar -Text $dt -Key 'id'
        if (-not $did) { $did = $b }
        $tg = @()
        $tm = [regex]::Match($dt, '(?m)^assertion_targets:\s*\[([^\]]*)\]')
        if ($tm.Success) { $tg = @($tm.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ }) }
        $plain = Join-Path $ddir "$b.handoff.yaml"
        $plainRejected = $false
        if (Test-Path -LiteralPath $plain -PathType Leaf) { $plainRejected = [regex]::IsMatch([System.IO.File]::ReadAllText($plain), '(?m)^status:[ \t]*[''"]?rejected[''"]?[ \t]*\r?$') }
        $stubs = @($dnames | Where-Object { $_.StartsWith("$b.handoff.rejected-stub", [System.StringComparison]::OrdinalIgnoreCase) })
        $aborts = @($dnames | Where-Object { $_.StartsWith("$b.handoff.aborted-seq", [System.StringComparison]::OrdinalIgnoreCase) -or $_.StartsWith("$b.anchors.aborted-seq", [System.StringComparison]::OrdinalIgnoreCase) })
        # this dispatch's ledger lines (under its id and its file's base name), each once, in ledger order
        # (kept in a SortedDictionary by ledger index, never sorted through the pipeline, which unrolls an entry that is an array)
        $byIdx = New-Object 'System.Collections.Generic.SortedDictionary[int,object]'
        foreach ($k in @($did, $b) | Select-Object -Unique) {
            if (-not $ledgerBy.ContainsKey($k)) { continue }
            foreach ($x in $ledgerBy[$k]) { $byIdx[[int]$x[0]] = $x }
        }
        $mineSorted = New-Object System.Collections.ArrayList; foreach ($kv in $byIdx.GetEnumerator()) { [void]$mineSorted.Add($kv.Value) }
        $spawnX = New-Object System.Collections.ArrayList; foreach ($x in $mineSorted) { if ($x[1] -eq 'spawn') { [void]$spawnX.Add($x) } }
        $spawned = $spawnX.Count
        $completes = New-Object System.Collections.ArrayList; foreach ($x in $mineSorted) { if ($x[1] -eq 'complete') { [void]$completes.Add($x[3]) } }
        $notes = New-Object System.Collections.ArrayList; foreach ($x in $mineSorted) { if ($x[1] -eq 'note') { [void]$notes.Add($x[3]) } }
        $refusalOf = { param($R) $rw = Get-MissionTelemetryMember $R 'refusal'; if ($rw) { [string]$rw } elseif ([string](Get-MissionTelemetryMember $R 'outcome') -match '(?i)refus') { [string](Get-MissionTelemetryMember $R 'outcome') } else { $null } }
        # a refusal before the spawn: its token, or its outcome (the runner's note carries outcome REFUSED-BEFORE-SPAWN beside
        # refusal LOGIN-PROBE-<CODE>)
        $preSpawn = { param($R)
            foreach ($w in @([string](Get-MissionTelemetryMember $R 'refusal'), [string](Get-MissionTelemetryMember $R 'outcome'))) {
                if (($w -match '^(?i)REFUSED-BEFORE-SPAWN') -or ($w -match '(?i)before[-_ ]?spawn')) { return $true } }
            return $false }
        # THE ATTEMPTS (amendment 1, RB-11): each spawn line, in ledger order, is one attempt -- the complete line(s) paired
        # with it by seq, a complete line whose seq pairs with none of this dispatch's spawn lines (or that carries none)
        # placed by its position after it and before the next spawn line (validator round 3), and the runner's refusal notes
        # after it and before the next. A REFUSAL BEFORE SPAWN CREATES NOTHING: an attempt with a refusal before its spawn
        # and no complete line naming no refusal ran nothing. The dispatch is read as its latest attempt NOT refused before
        # its spawn -- a worker an id-reuse refusal followed is still running, or ran and left no result, or was refused by
        # the runner after it ran -- and as refused before spawn only where every attempt was.
        $curC = New-Object System.Collections.ArrayList; $curN = New-Object System.Collections.ArrayList
        $attemptNote = ''
        if ($spawned -gt 0) {
            $spawnSeqs = @{}; foreach ($x in $spawnX) { if ($x[2] -ne '') { $spawnSeqs[$x[2]] = $true } }
            $attempts = New-Object System.Collections.Generic.List[object]
            for ($ai = 0; $ai -lt $spawnX.Count; $ai++) {
                $sx = $spawnX[$ai]; $lo = [int]$sx[0]
                $hi = if ($ai + 1 -lt $spawnX.Count) { [int]$spawnX[$ai + 1][0] } else { [int]::MaxValue }
                $aC = New-Object System.Collections.ArrayList; $aN = New-Object System.Collections.ArrayList
                foreach ($x in $mineSorted) {
                    $at = [int]$x[0]
                    if ($x[1] -eq 'complete' -and ((($x[2] -ne '') -and ($x[2] -eq $sx[2])) -or ((-not $spawnSeqs.ContainsKey($x[2])) -and ($at -gt $lo) -and ($at -lt $hi)))) { [void]$aC.Add($x[3]) }
                    elseif ($x[1] -eq 'note' -and ($at -gt $lo) -and ($at -lt $hi)) { [void]$aN.Add($x[3]) }
                }
                $ran = @($aC | Where-Object { -not (& $refusalOf $_) }).Count -gt 0
                $pre = @(@($aC) + @($aN) | Where-Object { & $preSpawn $_ }).Count -gt 0
                $attempts.Add([pscustomobject]@{ Seq = [string]$sx[2]; C = $aC; N = $aN; RefusedBefore = ($pre -and -not $ran) })
            }
            # the runner's notes carry no seq, so a note is placed by its position -- but an attempt refused before its spawn ran
            # nothing, so a note that is no refusal before spawn (NO-RESULT-AT-SESSION-END-*, RESULT-PLACEMENT-*) written after
            # it is the earlier run's: the id-reuse guard refuses while that run is still going, and its end note follows
            # (builder-side review)
            for ($ai = 1; $ai -lt $attempts.Count; $ai++) {
                if (-not $attempts[$ai].RefusedBefore) { continue }
                $target = -1
                for ($bi = $ai - 1; $bi -ge 0; $bi--) { if (-not $attempts[$bi].RefusedBefore) { $target = $bi; break } }
                if ($target -lt 0) { continue }
                $keepN = New-Object System.Collections.ArrayList
                foreach ($x in $attempts[$ai].N) { if (& $preSpawn $x) { [void]$keepN.Add($x) } else { [void]$attempts[$target].N.Add($x) } }
                $attempts[$ai].N = $keepN
            }
            $pickAt = $attempts.Count - 1
            for ($ai = $attempts.Count - 1; $ai -ge 0; $ai--) { if (-not $attempts[$ai].RefusedBefore) { $pickAt = $ai; break } }
            foreach ($x in $attempts[$pickAt].C) { [void]$curC.Add($x) }
            foreach ($x in $attempts[$pickAt].N) { [void]$curN.Add($x) }
            $later = @(for ($ai = $pickAt + 1; $ai -lt $attempts.Count; $ai++) { $attempts[$ai].Seq })
            if ($later.Count) { $attemptNote = " -- the attempt at seq $($attempts[$pickAt].Seq) decides; the later attempt(s) at seq $($later -join ', ') were refused before their spawn, which creates nothing" }
            elseif ($spawned -gt 1 -and $attempts[$pickAt].RefusedBefore) { $attemptNote = " -- each of its $spawned spawn lines was refused before its spawn (the latest at seq $($attempts[$pickAt].Seq))" }
            elseif ($spawned -gt 1) { $attemptNote = " -- the latest of $spawned spawn lines decides (seq $($attempts[$pickAt].Seq))" }
        } else { foreach ($x in $completes) { [void]$curC.Add($x) }; foreach ($x in $notes) { [void]$curN.Add($x) } }
        $refusalWords = @(@($completes) + @($notes) | ForEach-Object { & $refusalOf $_ } | Where-Object { $_ })
        $refusedComplete = @($completes | Where-Object { & $refusalOf $_ })
        $curRefC = @($curC | Where-Object { & $refusalOf $_ })
        $curOkC = @($curC | Where-Object { -not (& $refusalOf $_) })
        $curPre = @(@($curC) + @($curN) | Where-Object { & $preSpawn $_ })
        # validator round 3: a complete line that binds no result (result_sha256 written null) says so
        $noResult = @($curOkC | Where-Object { ($_ -is [System.Management.Automation.PSCustomObject]) -and (@($_.PSObject.Properties.Name) -contains 'result_sha256') -and ($null -eq $_.result_sha256) })
        $noResultNote = if ($noResult.Count) { ' -- its complete line binds no result (result_sha256 null) and names no refusal' } else { '' }
        # what stands beside it, said whatever the word (validator round 1: "the dispatch file alone" was said beside an anchors file)
        $beside = @($dnames | Where-Object { $_ -ne "$b.yaml" -and $_.StartsWith("$b.", [System.StringComparison]::OrdinalIgnoreCase) })
        $besideNote = if ($beside.Count) { 'beside it: ' + ($beside -join ', ') } else { 'the dispatch file alone' }
        $ledgerNote = if (-not $ledgerOk) { 'the spawn ledger ' + $(if ($null -ne $ledger -and $ledger.Present) { 'cannot be read' } else { 'is not on disk' }) }
                      else { 'the spawn ledger: ' + $spawned + ' spawn line(s), ' + @($completes).Count + ' complete line(s)' + $(if ($notes.Count) { ', ' + $notes.Count + ' refusal note(s) of the runner' } else { '' }) + $(if ($refusalWords.Count) { ', naming a refusal (' + ($refusalWords -join ', ') + ')' } else { '' }) }
        if (Test-Path -LiteralPath (Join-Path $ddir "$b.superseded.yaml")) { $dstate = 'superseded'; $basis = "$besideNote" }
        elseif ((Test-Path -LiteralPath $plain -PathType Leaf) -and -not $plainRejected) { $dstate = 'handed_off'; $basis = "$besideNote" }
        elseif ($plainRejected -or $stubs.Count) {
            $what = (@($(if ($plainRejected) { "the plain $b.handoff.yaml reads status: rejected" })) + @($stubs | ForEach-Object { "archived $_" })) -join '; '
            if (@($completes).Count -gt $refusedComplete.Count) { $dstate = 'complete_handoff_rejected' } else { $dstate = 'handoff_rejected' }
            $basis = "a rejection record ($what); $besideNote; $ledgerNote"
        }
        elseif ($aborts.Count) { $dstate = 'aborted'; $basis = "archived aborted-seq files only ($($aborts -join ', ')); $ledgerNote" }
        elseif ($curOkC.Count) { $dstate = 'complete_no_handoff'; $basis = "$besideNote; $ledgerNote$attemptNote$noResultNote" }
        elseif ($curPre.Count) { $dstate = 'refused_before_spawn'; $basis = "$besideNote; $ledgerNote$attemptNote -- refused before its spawn" }
        elseif ($curRefC.Count) { $dstate = 'complete_refused'; $basis = "$besideNote; $ledgerNote$attemptNote -- the spawn left no result" }
        elseif ($curN.Count -and $spawned -gt 0) { $dstate = 'runner_refused'; $basis = "$besideNote; $ledgerNote$attemptNote -- the runner's refusal note after the spawn, and no complete line yet: the run ended" }
        elseif ($spawned -gt 0) { $dstate = 'open'; $basis = "$besideNote; $($ledgerNote)$attemptNote -- a worker spawned and not complete" }
        elseif (-not $ledgerOk -and $null -ne $ledger -and $ledger.Present) { $dstate = 'ledger_unreadable'; $basis = "$besideNote; $ledgerNote" }
        else { $dstate = 'not_spawned'; $basis = "$besideNote; $ledgerNote" }
        if ($dstate -eq 'open') { $openD++ }
        $dispatchDetail[$did] = [ordered]@{ feature_id = (Get-MissionTelemetryYamlScalar -Text $dt -Key 'feature_id'); assertion_targets = $tg; state = $dstate; basis = $basis }
    }
    # open HALTs: HALT-* under the two HALT homes, with no unrevoked halt-ruling gate naming the file
    # UI-2 S2 (B-6): and each HALT's times, as the artifacts state them. raised_at: the HALT's own Raised stamp (a
    # `**Raised:**` / `raised_at:` line naming a date and a time, ~ allowed), basis stamp; else the file's last write time,
    # basis mtime (a HALT under .mission-runtime is never committed, so no first commit exists to read). answered_at: the
    # HALT's own Answered / Resolved stamp, basis stamp; else the ruling-citation's cited_at beside it, basis citation; else
    # null. state: answered when an unrevoked halt-ruling gate names it (the count's own predicate), else open.
    $openH = 0
    $haltDetail = [ordered]@{}
    $stampOf = {
        param([string]$Text, [string]$KeyRx)
        $m = [regex]::Match($Text, '(?im)^\s*[*_]*(?:' + $KeyRx + ')(?:_at)?[*_]*\s*:\s*[*_]*\s*~?\s*(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?')
        if (-not $m.Success) { return $null }
        $sec = if ($m.Groups[6].Success) { $m.Groups[6].Value } else { '00' }
        $ms = if ($m.Groups[7].Success) { $m.Groups[7].Value.PadRight(3, '0') } else { '000' }
        return ('{0}-{1}-{2}T{3}:{4}:{5}.{6}Z' -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value, $m.Groups[5].Value, $sec, $ms)
    }
    # RELEASE-5 GROUP B, CARDS (register row 564, ruling (m)): OPEN IS WHAT THE STOP EVALUATOR COUNTS UNANSWERED. The rule is
    # tools/lam/mission-goal-check.ps1's own detector, Get-OpenHalts, with its Test-HaltRuled -- lifted unchanged
    # (Get-MissionLiftedModule) and called with no goal: the evaluator's default scan of the two homes below. A HALT it
    # reports is 'open'; one its ruling test answers is 'answered'; every other HALT-* file found here is 'set_aside', with
    # the evaluator's own reason where it gives one (under a nested mission root, a tool file): the evaluator does not count
    # it and no ruling record answers it, so it is never open (ruling (m): shown apart, no ruling file written). A goal's own
    # declared dirs and legacy allowlist are a goal's, not the mission's: they are read for THE GOVERNING GOAL alone (below).
    # Where the evaluator's file cannot be read the 1.3.0 predicate stands (an unrevoked halt-ruling gate) and halt_reading
    # says why.
    # AMENDMENT 1 (RB-17, ruling (r)): THE GOVERNING GOAL. The HALT card honours the exceptions of ONE goal -- the goal the
    # mission's Stop hook is registered for, read from the Stop hook's own command line in the checkout's .claude settings
    # (Get-MissionStopHookGoal; read only). Where one is read, the evaluator's HALT scope for it is run as the evaluator runs
    # it: its own top-level statements, lifted by the parser (Get-MissionLiftedStatements) -- the goal file located as it
    # locates it, its detectors read as it reads them (Read-GoalDetectors, kept before any fault empties them), every
    # halt_absent detector's declared `dir` and the union of their legacy_answered_allowlist entries, and Get-OpenHalts over
    # the two homes and the declared dirs with that allowlist. The census an entry is tested against is the evaluator's:
    # legacy-halt-census.txt beside it (the evaluator names it from $PSScriptRoot, which a lifted module does not have, so
    # the same file is named here from the evaluator's folder). With no governing goal read -- none registered, several,
    # a settings file that does not parse, a goal file at neither search place, or a lift the evaluator's text refuses -- the
    # default scan stands, and halt_reading.goal says why.
    $haltMod = $null; $evOpen = $null; $haltWhy = $null; $haltTools = @(); $hxCache = $null; $hxRoots = $null
    $gcPath = Join-Path $PSScriptRoot 'mission-goal-check.ps1'
    $rootFullH = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    # a path as the feed may carry it: relative to the mission root, or -- outside it -- '<outside the mission root>/<its
    # last name>': never a host path (builder-side review)
    $relOfH = { param($P) $s = [string]$P; try { if ($s) { $s = [System.IO.Path]::GetFullPath($s).TrimEnd('\') } } catch { }
                if ($s.StartsWith($rootFullH + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $s.Substring($rootFullH.Length + 1) -replace '\\', '/' }
                elseif ([string]::Equals($s, $rootFullH, [System.StringComparison]::OrdinalIgnoreCase)) { '.' }
                elseif ($s) { '<outside the mission root>/' + [System.IO.Path]::GetFileName($s) } else { '' } }
    $stopGoal = $null; $goalScan = $null; $goalWhy = $null
    try { $stopGoal = Get-MissionStopHookGoal -Root $rootFullH }
    catch { $stopGoal = [ordered]@{ read = $false; goal = $null; goal_file_arg = $null; named_in = @(); why = 'the Stop hook registration could not be read (' + (Get-MissionTelemetryNoHostPath -Text $_.Exception.Message -Root $Root) + ')' } }
    $haltRoots = @((Join-Path $Root '.mission-runtime\halts'), (Join-Path $Root '.mission-runtime\lam'))
    $haltRunRoots = $haltRoots
    $haltLiftRoots = @('Get-OpenHalts', 'Test-HaltRuled', 'Get-HaltScanExclusion', 'ConvertTo-HaltScanPath')
    $haltLiftVars = @('script:HaltToolExtensions', 'script:HaltCitationSidecarSuffix')
    # the evaluator the Stop hook itself runs (its -File, the project dir put in), with the gate library and the legacy census
    # beside IT (builder-side review: mission.ps1 register runs the release folder's writer, whose own census is not the
    # project's); where the hook names none on disk, no goal is read
    $projTokens = @('${CLAUDE_PROJECT_DIR}', '$CLAUDE_PROJECT_DIR', '%CLAUDE_PROJECT_DIR%')
    $gcGoal = $null
    if ($stopGoal.read) {
        $gcGoal = [string]$stopGoal.evaluator_arg
        foreach ($tokn in $projTokens) { $gcGoal = $gcGoal.Replace($tokn, $rootFullH) }
        if ($gcGoal -and -not [System.IO.Path]::IsPathRooted($gcGoal)) { $gcGoal = Join-Path $rootFullH $gcGoal }
        if ($gcGoal) { try { $gcGoal = [System.IO.Path]::GetFullPath($gcGoal) } catch { } }
        if ((-not $gcGoal) -or -not (Test-Path -LiteralPath $gcGoal -PathType Leaf)) {
            $goalWhy = "the Stop hook runs goal $($stopGoal.goal) with an evaluator that is not on disk (" + (& $relOfH $gcGoal) + ')'
            $stopGoal = [ordered]@{ read = $false; goal = $stopGoal.goal; goal_file_arg = $null; evaluator_arg = $null; named_in = @($stopGoal.named_in); why = $goalWhy }
        }
    }
    if ($stopGoal.read) {
        try {
            $st5 = Get-MissionLiftedStatements -Path $gcGoal -Ranges @(
                @('$searched = @()', 'if ($GoalFile) {'),
                # (validator round 1: through the evaluator's grammar and line-fault rules, so its goal parse error is the
                # snapshot's; $detectorsAsRead is kept before any of them empties the detectors)
                @('$goalParseError = ''''', '$detectorsAsRead = @($detectors)'),
                @('$script:HaltDeclaredDirs = @()', '$script:HaltRunScanDirs = '),
                @('$declaredHaltDirs = @($script:HaltDeclaredDirs)', '$openHalts = @(Get-OpenHalts'))
            $wrap = "function Invoke-MissionGoalHaltScan {`n    param([string]`$MissionRoot, [string]`$Goal, [string]`$GoalFile)`n" + $st5[0] +
                    "`n    if (-not `$goalPath) { return [pscustomobject]@{ GoalPath = `$null; Searched = @(`$searched) } }`n" + $st5[1] + "`n" + $st5[2] + "`n" + $st5[3] +
                    "`n    return [pscustomobject]@{ GoalPath = [string]`$goalPath; Searched = @(`$searched); ParseError = `$goalParseError; Open = @(`$openHalts); HaltDirs = @(`$haltDirs | Where-Object { `$_ })" +
                    "; RunScanDirs = @(`$script:HaltRunScanDirs); DeclaredDirs = @(`$script:HaltDeclaredDirs); Allowlist = @(`$script:HaltEffectiveAllowlist | ForEach-Object { [string]`$_.raw })" +
                    "; ByLegacy = @(`$script:HaltsAnsweredByLegacy); AllowReport = @(`$script:HaltLegacyAllowlistReport) }`n}"
            $haltMod = Get-MissionLiftedModule -Path $gcGoal -Roots ($haltLiftRoots + @('Read-GoalDetectors', 'Resolve-DetectorPath', 'ConvertFrom-HaltLegacyAllowlist', 'Get-HaltSeatResolution', 'Get-HaltBytesSha256', 'ConvertFrom-HaltBytes',
                                                                      'Get-GoalGrammarFaults', 'Get-GoalLineFaults', 'ConvertTo-ManifestDisplayText', 'ConvertTo-GoalWholeNumber')) `
                -ScriptVars ($haltLiftVars + @('script:HaltLegacyCensus', 'script:HaltLegacyCensusReason')) -DotSource @((Join-Path (Split-Path -Parent $gcGoal) 'lam-gate-class.ps1')) -Append $wrap
            & $haltMod { param($P) $script:HaltLegacyCensusPath = $P } (Join-Path (Split-Path -Parent $gcGoal) 'legacy-halt-census.txt')
            $gfArg = ''
            if ($stopGoal.goal_file_arg) {
                $gfArg = [string]$stopGoal.goal_file_arg
                foreach ($tokn in $projTokens) { $gfArg = $gfArg.Replace($tokn, $rootFullH) }
                if (-not [System.IO.Path]::IsPathRooted($gfArg)) { $gfArg = Join-Path $rootFullH $gfArg }
                try { $gfArg = [System.IO.Path]::GetFullPath($gfArg) } catch { }
            }
            $goalScan = & $haltMod { param($R, $G, $F) Invoke-MissionGoalHaltScan -MissionRoot $R -Goal $G -GoalFile $F } $rootFullH ([string]$stopGoal.goal) $gfArg
            if (-not $goalScan.GoalPath) {
                $goalWhy = "the Stop hook runs goal $($stopGoal.goal), whose goal file is at none of the places the evaluator searches (" +
                           ((@($goalScan.Searched) | ForEach-Object { & $relOfH $_ }) -join ', ') + ')'
                $goalScan = $null
            } else { $evOpen = @($goalScan.Open) }
        } catch { $goalWhy = "the stop evaluator's HALT scope for goal $($stopGoal.goal) could not be run (" + (Get-MissionTelemetryNoHostPath -Text $_.Exception.Message -Root $Root) + ')'; $goalScan = $null; $evOpen = $null }
    }
    try {
        if ($null -eq $haltMod) {
            $haltMod = Get-MissionLiftedModule -Path $gcPath -Roots $haltLiftRoots -ScriptVars $haltLiftVars -DotSource @((Join-Path $PSScriptRoot 'lam-gate-class.ps1'))
        }
        if ($null -eq $goalScan) { $evOpen = @(& $haltMod { param($MissionLiftRoot) @(Get-OpenHalts -MissionRoot $MissionLiftRoot) } $Root) }
        else {
            if (@($goalScan.HaltDirs).Count) { $haltRoots = @($goalScan.HaltDirs) }
            $haltRunRoots = @(@($haltRoots) + @($goalScan.RunScanDirs))
        }
        $haltTools = @(& $haltMod { $script:HaltToolExtensions })
        $hxCache = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)
        $hxRoots = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($hd0 in $haltRunRoots) { [void]$hxRoots.Add((& $haltMod { param($P) ConvertTo-HaltScanPath -Path $P } $hd0)) }
    } catch { $haltWhy = $_.Exception.Message; $evOpen = $null }
    # EACH FILE, BY ITS PATH (validator round 1: matching the evaluator's open entries by file NAME counted a nested copy or a
    # tool file of the same name as the open HALT, and one file's state overwrote another's under a shared base name). Each
    # HALT-* file of the scanned roots -- the two homes, and a governing goal's declared dirs -- is decided by the evaluator's
    # own steps, in Get-OpenHalts' order, with its own functions: set aside when Get-HaltScanExclusion excludes it under
    # every root that reached it or its extension is one of $script:HaltToolExtensions; answered when Test-HaltRuled holds;
    # answered_allowlist where the governing goal's legacy allowlist answers it -- its name and the sha256 of its bytes
    # (Get-HaltBytesSha256) among the entries Get-OpenHalts itself honoured ($script:HaltsAnsweredByLegacy), counted apart
    # from the HALTs a gate answers; answered where its seat folder's RESOLVED record is honoured (Get-HaltSeatResolution,
    # which honours one only inside .mission-runtime/seats, a place only a goal's declared dir scans); else open (an
    # unreadable file too, as the evaluator counts it). The open files' names are then compared with Get-OpenHalts' own
    # report: halt_reading.agrees. A HALT id (the base name) shared by several files takes the strongest state among them --
    # open, then answered, then answered by the allowlist, then set aside -- and lists each file under `files`; the counts
    # count files, as the evaluator does.
    $haltCount = @{ open = 0; answered = 0; answered_allowlist = 0; set_aside = 0 }
    $haltRank = @{ open = 4; answered = 3; answered_allowlist = 2; set_aside = 1 }
    $openNames = New-Object System.Collections.Generic.List[string]
    $goalRel = if ($null -ne $goalScan) { & $relOfH ([string]$goalScan.GoalPath) } else { $null }
    $byLegacy = @(if ($null -ne $goalScan) { @($goalScan.ByLegacy) })
    # validator round 2: the places the evaluator's rule set aside in this scan -- its scratch-copies tree (named by the rule
    # itself) and each nested mission root Get-HaltScanExclusion named -- for the dashboard to decide a HALT line written
    # after this snapshot by the same place
    $hxExcluded = New-Object 'System.Collections.Generic.SortedSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    [void]$hxExcluded.Add('.mission-runtime/scratch-copies')
    # every HALT-* file under the scanned roots, once by its full path; counted where ANY root that reached it counts it (the
    # evaluator's own reading: a file is excluded only where no root of the run counted it)
    $hfAll = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($hdir in $haltRoots) {
        foreach ($hf in @(Get-ChildItem -LiteralPath $hdir -Recurse -File -Filter 'HALT-*' -ErrorAction SilentlyContinue)) {
            # a ruling citation is no HALT -- the suffix matched as the evaluator matches it (case-sensitively)
            if ($hf.Name.EndsWith('.ruling-citation.yaml', [System.StringComparison]::Ordinal)) { continue }
            $hx = ''
            if ($null -ne $evOpen) {
                try { $hx = [string](& $haltMod { param($R, $S, $F, $C, $RR) Get-HaltScanExclusion -MissionRoot $R -ScanRoot $S -FilePath $F -Cache $C -RunRoots $RR } $Root $hdir $hf.FullName $hxCache $hxRoots) } catch { $hx = '' }
            }
            if (-not $hfAll.ContainsKey($hf.FullName)) { $hfAll[$hf.FullName] = [pscustomobject]@{ File = $hf; Hx = $hx } }
            elseif (-not $hx) { $hfAll[$hf.FullName].Hx = '' }
        }
    }
    foreach ($hfe in $hfAll.Values) {
            $hf = $hfe.File
            $hid = [System.IO.Path]::GetFileNameWithoutExtension($hf.Name)
            $hrel = $hf.FullName
            if ($hrel.StartsWith($rootFullH + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $hrel = $hrel.Substring($rootFullH.Length + 1) -replace '\\', '/' }
            else { $hrel = '<outside the mission root>/' + $hf.Name }
            $hstate = $null; $hreason = $null
            if ($null -ne $evOpen) {
                $hx = [string]$hfe.Hx
                $hwhy = $null
                if ($hx) {
                    $cut = $hx.IndexOf('|'); $xr = $hx.Substring($cut + 1)
                    if ($xr.StartsWith($rootFullH + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $xr = $xr.Substring($rootFullH.Length + 1) }
                    $hwhy = 'it lies under ' + $hx.Substring(0, $cut) + ' at ' + ($xr -replace '\\', '/')
                    [void]$hxExcluded.Add(($xr -replace '\\', '/'))
                } elseif ($haltTools -contains $hf.Extension.ToLowerInvariant()) { $hwhy = "it is a tool file ($($hf.Extension)), not a HALT" }
                if ($hwhy) {
                    $hstate = 'set_aside'
                    $hreason = "set aside: the stop evaluator does not count it -- $hwhy -- and no ruling record answers it; never shown as open"
                } elseif ([bool](& $haltMod { param($F, $R) Test-HaltRuled -HaltFile $F -MissionRoot $R } $hf $Root)) { $hstate = 'answered' }
                else {
                    $hb = $null
                    if ($null -ne $goalScan) { try { $hb = [System.IO.File]::ReadAllBytes($hf.FullName) } catch { $hb = $null } }
                    $legacyKey = $null
                    if (($null -ne $hb) -and $byLegacy.Count) { $legacyKey = $hf.Name + '@' + [string](& $haltMod { param($B) Get-HaltBytesSha256 -Bytes $B } $hb) }
                    if ($legacyKey -and ($byLegacy -ccontains $legacyKey)) {
                        $hstate = 'answered_allowlist'
                        $hreason = "answered by the legacy allowlist of goal $($stopGoal.goal) ($goalRel), the goal the mission's Stop hook runs: its entry $legacyKey is a member of the legacy HALT census, the file still hashes to it and its own marker reads ANSWERED, so the stop evaluator does not count it"
                    } elseif (($null -ne $hb) -and [bool](& $haltMod { param($B, $F, $R) (Get-HaltSeatResolution -Text (ConvertFrom-HaltBytes -Bytes $B) -HaltFile $F -MissionRoot $R).honoured } $hb $hf $Root)) {
                        $hstate = 'answered'
                        $hreason = "answered by its seat folder's RESOLVED record, which the stop evaluator honours (Get-HaltSeatResolution)"
                    } else { $hstate = 'open'; $openNames.Add($hf.Name) }
                }
            } else {
                $g = Join-Path $Root (".mission\gates\halt-ruling-" + $hid + '.yaml')
                $ruled0 = (Test-Path -LiteralPath $g -PathType Leaf) -and -not (Get-MissionTelemetryYamlScalar -Text ([System.IO.File]::ReadAllText($g)) -Key 'revoked_at')
                $hstate = if ($ruled0) { 'answered' } else { 'open' }
            }
            $haltCount[$hstate]++
            if ($hstate -eq 'open') { $openH++ }
            # validator round 2: a HALT that cannot be read is still a HALT (the evaluator counts it open); its times are its
            # file's, and the snapshot is written all the same
            $ht = ''
            try { $ht = [System.IO.File]::ReadAllText($hf.FullName) } catch { $ht = '' }
            $ra = & $stampOf $ht 'raised'; $rb = 'stamp'
            if (-not $ra) { $ra = $hf.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture); $rb = 'mtime' }
            $aa = & $stampOf $ht 'answered|resolved'; $ab = $(if ($aa) { 'stamp' } else { $null })
            if (-not $aa) {
                $cit = Join-Path $hf.DirectoryName ($hid + '.ruling-citation.yaml')
                if (Test-Path -LiteralPath $cit -PathType Leaf) { $aa = & $stampOf ([System.IO.File]::ReadAllText($cit)) 'cited'; if ($aa) { $ab = 'citation' } }
            }
            $one = [ordered]@{ state = $hstate; raised_at = $ra; raised_basis = $rb; answered_at = $aa; answered_basis = $ab; reason = $hreason }
            $fileNote = [ordered]@{ file = $hrel; state = $hstate; reason = $hreason }
            if ($haltDetail.Contains($hid)) {
                $prev = $haltDetail[$hid]
                $files = @($prev['files']) + @($fileNote)
                if ($haltRank[$hstate] -gt $haltRank[[string]$prev['state']]) { $one['files'] = $files; $haltDetail[$hid] = $one }
                else { $prev['files'] = $files }
            } else {
                $one['files'] = @($fileNote)
                $haltDetail[$hid] = $one
            }
    }
    # the evaluator's own report, compared: the names of the files it counts unanswered (an entry may carry a bracketed note)
    $evNames = @(); $haltAgrees = $null
    if ($null -ne $evOpen) {
        $evNames = @($evOpen | ForEach-Object { $s = [string]$_; $i = $s.IndexOf(' ['); if ($i -gt 0 -and $s.EndsWith(']')) { $s.Substring(0, $i) } else { $s } } | Sort-Object)
        $haltAgrees = (($evNames -join "`n") -ceq ((@($openNames | Sort-Object)) -join "`n"))
    }
    # amendment 1 (RB-17): the goal read -- which, where its name was read, why none was read otherwise -- and what its
    # allowlist did; paths relative to the mission root, never a host path
    $relOf = $relOfH
    $goalReading = [ordered]@{ read = ($null -ne $goalScan); goal = $(if ($stopGoal.read) { [string]$stopGoal.goal } else { $null }); goal_file = $goalRel
                               named_in = @($stopGoal.named_in); source = 'the Stop hook command running tools/lam/mission-goal-check.ps1 in .claude/settings.json or .claude/settings.local.json'
                               why = $(if ($null -ne $goalScan) { $null } elseif ($goalWhy) { $goalWhy } else { [string]$stopGoal.why })
                               parse_error = $(if (($null -ne $goalScan) -and $goalScan.ParseError) { Get-MissionTelemetryNoHostPath -Text ([string]$goalScan.ParseError) -Root $Root } else { $null })
                               declared_dirs = @(if ($null -ne $goalScan) { @($goalScan.DeclaredDirs) | ForEach-Object { & $relOf $_ } })
                               allowlist_entries = @(if ($null -ne $goalScan) { @($goalScan.Allowlist) })
                               honoured = @($byLegacy)
                               not_honoured = @(if ($null -ne $goalScan) { @($goalScan.AllowReport) | ForEach-Object { Get-MissionTelemetryNoHostPath -Text ([string]$_) -Root $Root } }) }
    $haltReading = [ordered]@{
        agrees = $haltAgrees
        evaluator_open = @($evNames)
        rule = 'open = what the stop evaluator''s own detector (Get-OpenHalts of tools/lam/mission-goal-check.ps1) reports unanswered when run for the governing goal -- the one goal the mission''s Stop hook runs (goal): its declared dirs and its legacy allowlist included; with no governing goal read, its default scan of .mission-runtime/halts and .mission-runtime/lam; answered = its Test-HaltRuled (or a seat folder''s RESOLVED record it honours); answered_allowlist = answered by the governing goal''s legacy allowlist, counted apart from the HALTs a gate answers; set_aside = any other HALT-* file found there, which it does not count and no ruling record answers'
        evaluator = $(if ($null -ne $evOpen) { 'called' } else { 'not called: ' + (Get-MissionTelemetryNoHostPath -Text $haltWhy -Root $Root) + ' -- the 1.3.0 predicate stands (an unrevoked halt-ruling gate)' })
        open = $haltCount['open']; answered = $haltCount['answered']; answered_allowlist = $haltCount['answered_allowlist']; set_aside = $haltCount['set_aside']
        scan_homes = @(@($haltRunRoots) | ForEach-Object { & $relOf $_ } | Select-Object -Unique); excluded_roots = @($hxExcluded)
        goal = $goalReading }

    # RELEASE-5 GROUP B, CARDS (RB-6): THE MISSION'S CURRENT SPEC VERSION, READ FROM ITS OWN STATE -- .mission/spec/current.txt
    # (the token the spec tools write, "vNNN"; a file name has its .yaml taken off) and mission.yaml's current_spec_version.
    # Every installer-owned tool that writes it: mission-spec-bump.ps1 and mission-spec-accept.ps1 (both emit spec_bumped);
    # mission-close-milestone.ps1 (Invoke-SpecBump at a close, no spec_bumped); mission.ps1 init and tools/mission-init.ps1
    # (the initial v001 / null, no bump); tools/lam/build-smoke-mission.ps1 (a fixture mission). The card reads this, so a
    # bump with no spec_bumped line is read all the same.
    $specVersion = $null
    if (Test-Path -LiteralPath $curF -PathType Leaf) {
        $rawTok = ([System.IO.File]::ReadAllText($curF)).Trim()
        if ($rawTok) {
            $specVersion = [ordered]@{ current = ($rawTok -replace '\.ya?ml$', ''); current_txt = $rawTok
                                       current_spec_version = (Get-MissionTelemetryYamlScalar -Text $mt -Key 'current_spec_version'); source = '.mission/spec/current.txt' }
        }
    }

    # RELEASE-5 GROUP B, CARDS (RB-7): WHAT THE STOP EVALUATOR READ OF A VERIFY RUN. Each goal verdict on disk
    # (.mission/goals/<goal>.verdict.yaml, written by tools/lam/mission-goal-check.ps1) -- its verdict, evaluated_at, and
    # its verify_pass_or_dib detector's ok and detail (the evaluator's own words: "mission verify exited <n> -> <PASS |
    # PASS-DIB | REFUSE>. admitted: ... <the boundary disclosed>"), as the file holds them. The dashboard decides whether a
    # reading read the run its card shows.
    $goalVerdicts = [ordered]@{}
    foreach ($gf in @(Get-ChildItem -LiteralPath (Join-Path $Root '.mission\goals') -File -Filter '*.verdict.yaml' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        try {
            $gt = [System.IO.File]::ReadAllText($gf.FullName)
            $gname = Get-MissionTelemetryYamlScalar -Text $gt -Key 'goal'
            if (-not $gname) { $gname = $gf.Name -replace '\.verdict\.yaml$', '' }
            $gver = $null
            # validator round 2: EVERY verify_pass_or_dib detector, in order -- the evaluator writes one result per detector the
            # goal declares, in the goal's order (a short-circuited one included: "NOT EVALUATED ..."), so the i-th such entry
            # of the verdict is the i-th such declaration of the goal file, whose own `against` it ran verify with (validator
            # round 1 added `against`; round 2: read inside that declaration's own entry, never across into the next)
            $dms = [regex]::Matches($gt, "(?m)^  - type:[ \t]*verify_pass_or_dib[ \t]*\r?\n    ok:[ \t]*(true|false)[ \t]*\r?\n    detail:[ \t]*'((?:[^']|'')*)'[ \t]*\r?$")
            $declAgainst = New-Object System.Collections.ArrayList
            $gFile = Get-MissionTelemetryYamlScalar -Text $gt -Key 'goal_file'
            if ($dms.Count -and $gFile) {
                $gPath = if ([System.IO.Path]::IsPathRooted($gFile)) { $gFile } else { Join-Path $Root $gFile }
                if (Test-Path -LiteralPath $gPath -PathType Leaf) {
                    foreach ($en in [regex]::Split([System.IO.File]::ReadAllText($gPath), '(?m)^(?=[ \t]*-[ \t]+type:)')) {
                        if (-not [regex]::IsMatch($en, '^[ \t]*-[ \t]+type:[ \t]*verify_pass_or_dib[ \t]*(?:#.*)?\r?(?:\n|$)')) { continue }
                        $am = [regex]::Match($en, "(?m)^[ \t]+against:[ \t]*['""]?([^'""\r\n#]+?)['""]?[ \t]*(?:#.*)?\r?$")
                        [void]$declAgainst.Add($(if ($am.Success) { $am.Groups[1].Value.Trim() } else { $null }))
                    }
                }
            }
            $verifyAll = New-Object System.Collections.ArrayList
            for ($di = 0; $di -lt $dms.Count; $di++) {
                $dAgainst = if ($di -lt $declAgainst.Count) { $declAgainst[$di] } else { $null }
                [void]$verifyAll.Add([ordered]@{ ok = ($dms[$di].Groups[1].Value -ceq 'true'); detail = $dms[$di].Groups[2].Value.Replace("''", "'"); against = $dAgainst })
            }
            if ($verifyAll.Count) { $gver = $verifyAll[0] }
            $goalVerdicts[$gname] = [ordered]@{ file = '.mission/goals/' + $gf.Name; verdict = (Get-MissionTelemetryYamlScalar -Text $gt -Key 'verdict')
                                               evaluated_at = (Get-MissionTelemetryYamlScalar -Text $gt -Key 'evaluated_at')
                                               hook_or_hand = (Get-MissionTelemetryYamlScalar -Text $gt -Key 'hook_or_hand'); verify = $gver
                                               verify_detectors = @($verifyAll.ToArray()) }
        } catch { }
    }

    $fo = [ordered]@{}; foreach ($k in @($features.Keys | Sort-Object)) { $fo[$k] = $features[$k] }
    $ao = [ordered]@{}; foreach ($k in @($assertions.Keys | Sort-Object)) { $ao[$k] = $assertions[$k] }
    $adet = [ordered]@{}
    foreach ($k in @($assertions.Keys | Sort-Object)) {
        $rs = @()
        if ($rounds.ContainsKey($k)) { foreach ($n in @($rounds[$k].Keys | Sort-Object)) { $rs += ,([ordered]@{ round = [int]$n; verdict = $rounds[$k][$n] }) } }
        # RELEASE-5 group B (RB-1..RB-4), additively: where the status came from, and why an assertion is not judged
        $adet[$k] = [ordered]@{ feature_id = $assertFeature[$k]; milestone_id = $assertMilestone[$k]; rounds = $rs
                                source = $assertSource[$k]; reason = $(if ($assertReason.ContainsKey($k)) { $assertReason[$k] } else { $null })
                                # RELEASE-5 group B, amendment 3 (RB-24, RB-25), additively: the evidence a judged assertion stands on, in
                                # one of four words, and the path of the file read for it (working copy, archive copy) -- null where
                                # it is not judged, or where no file was read
                                evidence = $(if ($assertEvidence.ContainsKey($k)) { $assertEvidence[$k] } else { $null })
                                evidence_path = $(if ($assertEvidencePath.ContainsKey($k)) { $assertEvidencePath[$k] } else { $null }) }
    }
    # amendment 3 (RB-18, RB-19), additively: how the kept evidence was read -- the rule, and the archive as it was listed (or
    # why it was not); it is listed only where an assertion of closed work has its working copy absent
    $assertionReading['kept_evidence'] = [ordered]@{
        rule = 'for an assertion of closed work (every milestone holding it carries the spec status done or passed) whose bound working copy is absent, and for that refusal alone: a file named validator-<assertion id>.result.yaml under ' + '.mission-runtime/lam/validators' + ' (any folder, no link followed) whose bytes the close tool''s reader accepts against the complete line it selected -- evidence archive copy; else that line''s own verdict -- evidence record alone. Open work, and a working copy present that fails its comparison, are read as the close tool reads them.'
        archive = '.mission-runtime/lam/validators'
        listed = $(if ($null -ne $archive) { [bool]$archive.listed } else { $false })
        why = $(if ($null -eq $archive) { 'not needed: no assertion of closed work has its working copy absent' } else { $archive.why })
        files = $(if ($null -ne $archive) { [int]$archive.files } else { 0 })
        links_not_followed = $(if ($null -ne $archive) { [int]$archive.links_not_followed } else { 0 })
        folders_unreadable = $(if ($null -ne $archive) { [int]$archive.folders_unreadable } else { 0 })
        closed_milestones = @($msBlocks | Where-Object { $closedMs[$_.id] } | ForEach-Object { $_.id } | Sort-Object -Unique) }
    # UI-2 S2 (B-11; register row 526): the version the project's framework.lock records, beside the registry row's
    $lockV = $null
    $lockF = Join-Path $Root 'framework.lock'
    if (Test-Path -LiteralPath $lockF -PathType Leaf) { try { $lockV = [string](([System.IO.File]::ReadAllLines($lockF)[0]) | ConvertFrom-Json).version } catch { $lockV = $null }; if (-not $lockV) { $lockV = $null } }
    return [ordered]@{
        state             = $state
        mission_name      = $missionName
        current_milestone = $milestone
        features          = $fo
        assertions        = $ao
        counts            = [ordered]@{ features = $fo.Count; assertions = $ao.Count; open_halts = $openH; open_dispatches = $openD }
        milestones        = $milestones
        # UI-2 S2 (group B), additively: what the artifacts hold and the feed did not carry
        assertion_detail  = $adet
        dispatch_detail   = $dispatchDetail
        halts             = $haltDetail
        framework_lock_version = $lockV
        # RELEASE-5 group B, additively: how the assertions were read (RB-1..RB-4), the HALTs (RB-8), the spec version
        # (RB-6) and the goal verdicts' verify readings (RB-7)
        assertion_reading = $assertionReading
        halt_reading      = $haltReading
        spec_version      = $specVersion
        goal_verdicts     = $goalVerdicts
        milestone_tally   = $(& { $mo = [ordered]@{}; foreach ($k in @($milestoneTally.Keys | Sort-Object)) { $mo[$k] = $milestoneTally[$k] }; $mo })
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
