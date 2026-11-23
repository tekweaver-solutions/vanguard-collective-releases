<#
  UI-3 amendment 3 (1.3.3), group V, UC-34: THE GOAL EVALUATOR'S READING IN THE FEED. One goal_verdict line per goal
  evaluation, appended through the feed's one writer (Write-MissionEvent, in the sealed library, used exactly as it is, by way
  of tools/lam/mission-telemetry.ps1's Invoke-MissionTelemetry), its source the goal's verdict file -- so the line's sha256
  binds the verdict's bytes -- and written only once that file is complete on disk.

  Dot-sourced ONLY inside a child script block of tools/lam/mission-goal-check.ps1, after the verdict file is written, with
  every stream of that block sent to $null and the call inside try/catch: nothing here can reach the evaluator's verdict, its
  exit code, its printed lines, its verdict file or its trap (UC-35). Nothing here throws to its caller.

  THE PAYLOAD (docs/framework/mission-event.schema.json, kind goal_verdict; expanded-schemas SS14):
    goal, verdict, evaluated_at, hook_or_hand -- as the verdict file holds them;
    verify_readings -- one entry per verify_pass_or_dib detector of the verdict file whose detail is a verify reading
      ("mission verify exited <n> -> <PASS|PASS-DIB|REFUSE>.[ admitted: ...] <boundary>"), in the goal's order:
        detector         its position among the goal's verify_pass_or_dib detectors (1-based)
        ok               the detector's ok
        exit_code, word  verify's exit and the evaluator's word for it
        admits           ok and the word is PASS or PASS-DIB
        admitted         the subjects the evaluator admitted (PASS-DIB), else []
        boundary         the rest of the detail (the evaluator's reason), no host path, else null
        against          the artifact the detector declared it runs verify against (made relative where it lies under the
                         mission root, as verify writes it), else null
        against_checked  against is not null
        report_path      the report the verify run wrote, relative to the mission root -- the verify_result line's source_path
        report_sha256    that file's sha256 -- the verify_result line's sha256; both null where the evaluator does not hold
                         them (the run printed no verify_id, its report is not on disk, or lies outside the mission root)
  The detector lines are read from the verdict file with the snapshot writer's own pattern (mission-telemetry.ps1,
  Get-MissionSnapshotState's goal_verdicts) and the detail with the dashboard's (tools/ui/derive.py _VERIFY_DETAIL), so a
  snapshot and a line read from one verdict give the dashboard the same reading.
#>

# The detector entry, as the snapshot writer reads it (mission-telemetry.ps1, goal_verdicts).
$script:GoalVerdictDetectorPattern = "(?m)^  - type:[ \t]*verify_pass_or_dib[ \t]*\r?\n    ok:[ \t]*(true|false)[ \t]*\r?\n    detail:[ \t]*'((?:[^']|'')*)'[ \t]*\r?$"
# The detail, as the dashboard reads it (tools/ui/derive.py _VERIFY_DETAIL; .NET's Singleline is Python's re.S).
$script:GoalVerdictDetailPattern = '^mission verify exited (-?\d+) -> (PASS-DIB|PASS|REFUSE)\.(?: admitted: ((?:\S+, )*\S+))?\s*(.*)$'

function Get-GoalVerdictRelPath {
    # A path under the mission root as the writer spells a source_path (forward slashes); $null when it is not under it.
    param([string]$Root, [string]$Path)
    if (-not $Path) { return $null }
    try {
        $full = if ([System.IO.Path]::IsPathRooted($Path)) { [System.IO.Path]::GetFullPath($Path) } else { [System.IO.Path]::GetFullPath((Join-Path $Root $Path)) }
        $base = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + '\'
        if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) { return ($full.Substring($base.Length) -replace '\\', '/') }
    } catch { }
    return $null
}

function Remove-GoalVerdictUserWords {
    # Before the path scrubber (which reads a path up to a space): the user's home folder and name, whatever follows them, so a
    # home folder holding a space never leaves its owner's name in the text (builder review).
    param([string]$Text, [string]$Root)
    $t = $Text
    # the mission root first (a path under it is written relative, as the scrubber writes it), then the home folder
    if ($Root) { $t = [regex]::Replace($t, [regex]::Escape($Root.TrimEnd('\', '/')) + '[\\/]?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) }
    foreach ($h in @($env:USERPROFILE, $env:HOME) | Where-Object { $_ -and $_.Length -gt 3 } | Sort-Object Length -Descending) {
        $t = [regex]::Replace($t, [regex]::Escape($h.TrimEnd('\', '/')), '~', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    if ($env:USERNAME -and $env:USERNAME.Length -gt 2) {
        $t = [regex]::Replace($t, [regex]::Escape($env:USERNAME), '<user>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $t
}

function Get-GoalVerdictRunIdentity {
    # The report a verify run wrote, from the report it printed: <write_evidence_root>/<verify_id>/verify-report.yaml (else the
    # default home, <root>/.mission/evidence). @{ report_path; report_sha256 } -- both $null where it is not held.
    param([string]$Root, [string]$VerifyText)
    $none = [ordered]@{ report_path = $null; report_sha256 = $null }
    if (-not $VerifyText) { return $none }
    $idm = [regex]::Match($VerifyText, "(?m)^verify_id:[ \t]*['""]?(verify-[0-9a-f]+)['""]?[ \t]*\r?$")
    if (-not $idm.Success) { return $none }
    $id = $idm.Groups[1].Value
    $roots = New-Object System.Collections.Generic.List[string]
    $em = [regex]::Match($VerifyText, "(?m)^[ \t]*write_evidence_root:[ \t]*(?:'((?:[^']|'')*)'|""([^""]*)""|(\S[^\r\n]*?))[ \t]*\r?$")
    if ($em.Success) {
        $v = if ($em.Groups[1].Success) { $em.Groups[1].Value -replace "''", "'" } elseif ($em.Groups[2].Success) { $em.Groups[2].Value } else { $em.Groups[3].Value }
        if ($v -and $v -ne '<unresolved>') { $roots.Add($v) }
    }
    $roots.Add((Join-Path $Root '.mission\evidence'))
    foreach ($er in $roots) {
        try {
            $p = Join-Path (Join-Path $er $id) 'verify-report.yaml'
            if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $Root $p }
            if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
            $rel = Get-GoalVerdictRelPath -Root $Root -Path $p
            if (-not $rel) { continue }
            $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant()
            return [ordered]@{ report_path = $rel; report_sha256 = $sha }
        } catch { }
    }
    return $none
}

function New-GoalVerdictPayload {
    # The goal_verdict payload, from the verdict file on disk and the verify runs the detectors stashed (in order: @{ detail;
    # against; text }). Requires tools/lam/mission-telemetry.ps1 dot-sourced (its YAML scalar reader and path scrubber).
    param([string]$Root, [string]$VerdictPath, [object[]]$Runs = @())
    $vt = [System.IO.File]::ReadAllText($VerdictPath)
    $goal = Get-MissionTelemetryYamlScalar -Text $vt -Key 'goal'
    # builder review: a goal id the scalar reader reads as null (`null`, `Null`) falls back to the file's name, as the snapshot
    # writer's does
    if (-not $goal) { $goal = ([System.IO.Path]::GetFileName($VerdictPath)) -replace '\.verdict\.yaml$', '' }
    $readings = New-Object System.Collections.ArrayList
    $runQueue = New-Object System.Collections.Generic.Queue[object]
    foreach ($r in @($Runs)) { if ($null -ne $r) { $runQueue.Enqueue($r) } }
    $dms = [regex]::Matches($vt, $script:GoalVerdictDetectorPattern)
    for ($i = 0; $i -lt $dms.Count; $i++) {
        $detail = $dms[$i].Groups[2].Value.Replace("''", "'")
        $m = [regex]::Match($detail, $script:GoalVerdictDetailPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $m.Success) { continue }
        # the run this detector made: the next stashed run whose detail is this entry's (the verdict file folds newlines)
        $run = $null
        while ($runQueue.Count -gt 0) {
            $c = $runQueue.Dequeue()
            if (((([string]$c.detail) -replace "`r?`n", ' ')) -ceq $detail) { $run = $c; break }
        }
        $against = $null
        if ($null -ne $run -and $run.against) {
            $against = [string]$run.against
            $relA = Get-GoalVerdictRelPath -Root $Root -Path $against
            if ($relA -and [System.IO.Path]::IsPathRooted($against)) { $against = $relA }
        }
        $ident = if ($null -ne $run) { Get-GoalVerdictRunIdentity -Root $Root -VerifyText ([string]$run.text) } else { [ordered]@{ report_path = $null; report_sha256 = $null } }
        $word = $m.Groups[2].Value
        $ok = ($dms[$i].Groups[1].Value -ceq 'true')
        $boundary = $m.Groups[4].Value.Trim()
        if ($boundary) { $boundary = Get-MissionTelemetryNoHostPath -Text (Remove-GoalVerdictUserWords -Text $boundary -Root $Root) -Root $Root } else { $boundary = $null }
        [void]$readings.Add([ordered]@{
            detector        = $i + 1
            ok              = $ok
            exit_code       = [int]$m.Groups[1].Value
            word            = $word
            admits          = ($ok -and ($word -ceq 'PASS' -or $word -ceq 'PASS-DIB'))
            admitted        = @($(if ($m.Groups[3].Success) { @($m.Groups[3].Value -split ',' | ForEach-Object { $_.Trim() }) } else { @() }))
            boundary        = $boundary
            against         = $against
            against_checked = ($null -ne $against)
            report_path     = $ident.report_path
            report_sha256   = $ident.report_sha256
        })
    }
    return [ordered]@{
        goal            = $goal
        verdict         = (Get-MissionTelemetryYamlScalar -Text $vt -Key 'verdict')
        evaluated_at    = (Get-MissionTelemetryYamlScalar -Text $vt -Key 'evaluated_at')
        hook_or_hand    = (Get-MissionTelemetryYamlScalar -Text $vt -Key 'hook_or_hand')
        verify_readings = @($readings.ToArray())
    }
}

function Send-GoalVerdictEvent {
    # THE APPEND. One goal_verdict line for the verdict at $VerdictPath, through Invoke-MissionTelemetry (-> Write-MissionEvent,
    # unchanged). A checkout that is not a telemetry stream, a feed absent or not writable: the writer writes nothing and
    # returns (recording its own SS14 trace where the checkout is a stream). Never throws; returns nothing.
    param([string]$MissionRoot, [string]$VerdictPath, [object[]]$Runs = @())
    try {
        if (-not $VerdictPath -or -not (Test-Path -LiteralPath $VerdictPath -PathType Leaf)) { return }
        . (Join-Path $PSScriptRoot 'mission-telemetry.ps1')
        $root = [System.IO.Path]::GetFullPath($MissionRoot).TrimEnd('\', '/')
        if (-not (Test-MissionTelemetryStreamLite -Root $root)) { return }
        # a verdict beside a goal file outside the checkout (-GoalFile elsewhere) cannot be a line's source: no line, and no
        # hook-errors.log line on every stop for it (builder review)
        if (-not (Get-GoalVerdictRelPath -Root $root -Path $VerdictPath)) { return }
        $payload = New-GoalVerdictPayload -Root $root -VerdictPath $VerdictPath -Runs $Runs
        Invoke-MissionTelemetry -Root $root -Verb 'goal-check' -Events @(@{ Kind = 'goal_verdict'; Payload = $payload; SourcePath = $VerdictPath })
    } catch { }
}

function Test-MissionTelemetryStreamLite {
    # The cheap half of "is this checkout a stream" (the writer asks the whole question again under its own rules): a mission
    # record and a registry to look in. A checkout with neither pays nothing for the append.
    param([string]$Root)
    if (-not (Test-Path -LiteralPath (Join-Path $Root '.mission\mission.yaml') -PathType Leaf)) { return $false }
    $vh = if ($env:VANGUARD_HOME) { $env:VANGUARD_HOME } elseif ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.vanguard' } elseif ($env:HOME) { Join-Path $env:HOME '.vanguard' } else { '' }
    return ($vh -and (Test-Path -LiteralPath (Join-Path $vh 'projects.yaml') -PathType Leaf))
}
