#Requires -Version 5.1
<#
  UI-3 amendment 3 (1.3.3, seat "U-3 framework 1b"), group V -- THE EVALUATOR'S HALF: UC-34 (after each evaluation, hook or
  hand, exactly one goal_verdict line through the feed's one writer, its source the verdict file, following the verify_result
  line it read, carrying the reading and the identity of that run) and UC-35 (the append cannot change an evaluation: with the
  feed present, absent, and present but not writable, the verdict, the exit code, the printed lines and the verdict file --
  its own timestamps aside -- are identical, to each other and to v1.3.2's evaluator; the verdict file is complete on disk
  before the append begins; the time of an evaluation with and without the append is measured).

  A sandbox under %TEMP%: a mission root registered as a telemetry stream in a Vanguard home of its own (VANGUARD_HOME, host-id,
  projects.yaml), a goal with one verify_pass_or_dib detector pointed (`path`) at a stub verify that writes its report and its
  verify_result line through the real writer (tools/lam/mission-telemetry.ps1 -> Write-MissionEvent) and prints a report the
  evaluator admits as PASS-DIB. The real evaluator (tools/lam/mission-goal-check.ps1) runs in Windows PowerShell 5.1 as the
  Stop hook runs it. "Without the append" is v1.3.2's evaluator, a clean extract of the tag (git archive), over the same sandbox.

  powershell -NoProfile -ExecutionPolicy Bypass -File tests\lam\uc35-goal-verdict.ps1 [-Runs 5] [-KeepSandbox]
  Prints one [PASS]/[FAIL] line per check (UC-34, UC-35) and EXIT: <failures>; exits with the failure count.
#>
param([int]$Runs = 5, [switch]$KeepSandbox)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$evalNew = Join-Path $repo 'tools\lam\mission-goal-check.ps1'
$T = Join-Path ([System.IO.Path]::GetTempPath()) ('uc35-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
$M = Join-Path $T 'mission'
$VH = Join-Path $T 'vhome'
$stub = Join-Path $T 'stub\verify.ps1'
$goal = 'G-UC35'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$failures = 0

function Write-Utf8 { param([string]$Path, [string]$Text)
    $d = Split-Path -Parent $Path; if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}
function Get-Sha { param([string]$Path) (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Check { param([string]$Id, [string]$Title, [bool]$Ok, [string[]]$Detail)
    Write-Host ''
    Write-Host ("[{0}] {1} -- {2}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Id, $Title)
    foreach ($l in @($Detail)) { Write-Host "    $l" }
    if (-not $Ok) { $script:failures++ }
}
function Get-FeedLines {
    $p = Join-Path $M '.mission-runtime\telemetry\events.jsonl'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @() }
    $out = @()
    foreach ($ln in [System.IO.File]::ReadAllLines($p)) { if ($ln.Trim()) { $out += ,([pscustomobject]@{ text = $ln; obj = ($ln | ConvertFrom-Json) }) } }
    return $out
}
function Invoke-Eval { param([string]$Evaluator, [string]$GoalId, [switch]$Hook, [string]$Dispatch = '', [string]$GoalFile = '')
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ps51
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$Evaluator`" -Goal $GoalId -MissionRoot `"$M`""
    if ($GoalFile) { $a += " -GoalFile `"$GoalFile`"" }
    if ($Hook) { $a += ' -AsStopHook' }
    $psi.Arguments = $a
    $psi.WorkingDirectory = $M
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['VANGUARD_HOME'] = $VH
    $psi.EnvironmentVariables['UC35_REPO'] = $repo
    if ($Dispatch) { $psi.EnvironmentVariables['LAM_DISPATCH'] = $Dispatch } elseif ($psi.EnvironmentVariables.ContainsKey('LAM_DISPATCH')) { $psi.EnvironmentVariables.Remove('LAM_DISPATCH') }
    if ($psi.EnvironmentVariables.ContainsKey('MISSION_DISPATCH_ID')) { $psi.EnvironmentVariables.Remove('MISSION_DISPATCH_ID') }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write('{"hook_event_name":"Stop","stop_hook_active":false}'); $p.StandardInput.Close()
    $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
    $p.WaitForExit(); $sw.Stop()
    $vp = Join-Path $M ".mission\goals\$GoalId.verdict.yaml"
    $vb = if (Test-Path -LiteralPath $vp) { [System.IO.File]::ReadAllText($vp) } else { '' }
    return [pscustomobject]@{ code = $p.ExitCode; out = $outTask.Result; err = $errTask.Result; ms = $sw.ElapsedMilliseconds
                              verdictText = $vb; verdictSha = $(if ($vb) { Get-Sha $vp } else { '' }); verdictPath = $vp }
}
# "its own timestamps aside": the verdict file's evaluated_at line; printed text: any ISO-8601 UTC stamp, and the folder the
# evaluator ran from (the extract's or this tree's -- the same file names under both)
function Format-Comparable { param([string]$Text, [string]$EvalDir)
    $t = $Text -replace '(?m)^evaluated_at: .*\r?\n', ''
    $t = $t -replace '\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z', '<ts>'
    if ($EvalDir) { $t = $t.Replace($EvalDir, '<tools-lam>') }
    return $t
}
function Get-Verdict { param([string]$Text) $m = [regex]::Match($Text, '(?m)^verdict: (\S+)'); if ($m.Success) { $m.Groups[1].Value } else { '' } }

try {
    # ---- the sandbox ------------------------------------------------------------------------------------------------------
    $hostId = [guid]::NewGuid().ToString()
    Write-Utf8 (Join-Path $VH 'host-id') $hostId
    Write-Utf8 (Join-Path $VH 'projects.yaml') ("- host_id: $hostId`n  checkout_path: '" + ($M -replace "'", "''") + "'`n  mission_id: 'uc35-mission'`n  registered_at: '2026-11-19T00:00:00.000Z'`n  framework_version: '1.3.2'`n")
    Write-Utf8 (Join-Path $M '.mission\mission.yaml') "id: uc35-mission`nstate: executing`n"
    Write-Utf8 (Join-Path $M '.mission\dispatches\D-UC35.anchors.yaml') "dispatch: D-UC35`n"
    New-Item -ItemType Directory -Force -Path (Join-Path $M '.mission-runtime\telemetry') | Out-Null
    Write-Utf8 (Join-Path $M ".mission\goals\$goal.yaml") ("id: $goal`ndescription: `"uc35 member goal: one detector, the verify`"`ndetectors:`n  - type: verify_pass_or_dib`n    path: $stub`n    against: .mission/dispatches/D-UC35.anchors.yaml`n")
    # the stub verify: its report under .mission/evidence/<verify_id>/, its verify_result line through the real writer, then the
    # report printed (verify_id, write_evidence_root, the three suite subjects ABSENT at the increment boundary), exit 1
    Write-Utf8 $stub @'
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$against = ''; for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '--against') { $against = [string]$args[$i + 1] } }
$id = 'verify-' + ([guid]::NewGuid().ToString('n').Substring(0, 12))
$ev = Join-Path $root '.mission\evidence'
$subj = @('suite.passed', 'suite.failed', 'suite.skipped')
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("verify_version: '1'")
[void]$sb.AppendLine("verify_id: $id")
[void]$sb.AppendLine("against:")
[void]$sb.AppendLine("  path: $against")
[void]$sb.AppendLine("arms:")
foreach ($s in $subj) {
    [void]$sb.AppendLine("  - arm: ANCHOR")
    [void]$sb.AppendLine("    subject: $s")
    [void]$sb.AppendLine("    outcome: ABSENT")
    [void]$sb.AppendLine("    residual: 'Suite EXECUTION is not implemented in this increment (uc35 stub)'")
    [void]$sb.AppendLine("    write_evidence_root: '" + ($ev -replace "'", "''") + "'")
}
[void]$sb.AppendLine("gate: REFUSE")
[void]$sb.AppendLine("refused_by:")
foreach ($s in $subj) { [void]$sb.AppendLine("  - ANCHOR/$s") }
$text = $sb.ToString()
$rp = Join-Path (Join-Path $ev $id) 'verify-report.yaml'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rp) | Out-Null
[System.IO.File]::WriteAllText($rp, $text, (New-Object System.Text.UTF8Encoding($false)))
. (Join-Path $env:UC35_REPO 'tools\lam\mission-telemetry.ps1')
Invoke-MissionTelemetry -Root $root -Verb 'mission-verify' -Events @(
    @{ Kind = 'verify_result'; SourcePath = $rp; Payload = [ordered]@{ verdict = 'REFUSE'; arms_run = @('ANCHOR'); against = $against; divergences = 3
                                                                      refused_by = @($subj | ForEach-Object { "ANCHOR/$_" }) } })
Write-Output $text
exit 1
'@
    # v1.3.2's evaluator: a clean extract of the tag's tools/lam
    $x = Join-Path $T 'v132'
    New-Item -ItemType Directory -Force -Path $x | Out-Null
    $tar = Join-Path $T 'v132.tar'
    & git -C $repo archive --format=tar -o $tar v1.3.2 tools/lam
    if ($LASTEXITCODE -ne 0) { throw 'git archive v1.3.2 failed' }
    & tar -xf $tar -C $x
    if ($LASTEXITCODE -ne 0) { throw 'tar -xf failed' }
    $evalOld = Join-Path $x 'tools\lam\mission-goal-check.ps1'
    $dirNew = Split-Path -Parent $evalNew; $dirOld = Split-Path -Parent $evalOld
    $feedPath = Join-Path $M '.mission-runtime\telemetry\events.jsonl'
    $telDir = Join-Path $M '.mission-runtime\telemetry'

    # ---- UC-34: the line, by hook and by hand ------------------------------------------------------------------------------
    $d34 = @(); $ok34 = $true
    foreach ($mode in @('hook', 'hand')) {
        $before = @(Get-FeedLines)
        $r = Invoke-Eval -Evaluator $evalNew -GoalId $goal -Hook:($mode -eq 'hook')
        $new = @(Get-FeedLines | Select-Object -Skip $before.Count)
        $gv = @($new | Where-Object { $_.obj.kind -eq 'goal_verdict' }); $vr = @($new | Where-Object { $_.obj.kind -eq 'verify_result' })
        $one = ($gv.Count -eq 1) -and ($vr.Count -eq 1)
        $d34 += "$mode : exit $($r.code), verdict $(Get-Verdict $r.verdictText); new lines: $(@($new | ForEach-Object { $_.obj.kind + '#' + $_.obj.seq }) -join ', ') (expect verify_result then exactly one goal_verdict)"
        if (-not $one) { $ok34 = $false; continue }
        $g = $gv[0].obj; $v = $vr[0].obj; $p = $g.payload
        $order = ([int64]$g.seq -gt [int64]$v.seq) -and ([string]$g.ts -ge [string]$v.ts)
        $src = ($g.source_path -ceq ".mission/goals/$goal.verdict.yaml") -and ($g.sha256 -ceq $r.verdictSha)
        $vt = $r.verdictText
        $hdr = ($p.goal -ceq $goal) -and ($p.verdict -ceq (Get-Verdict $vt)) -and
               ($p.evaluated_at -ceq [regex]::Match($vt, '(?m)^evaluated_at: (\S+)').Groups[1].Value) -and ($p.hook_or_hand -ceq $mode) -and
               ($g.schema_version -ceq '1.2')
        $rd = @($p.verify_readings)
        $detAdm = [regex]::Match($vt, "admitted: ((?:\S+, )*\S+)").Groups[1].Value -split ', '
        $read = ($rd.Count -eq 1) -and ($rd[0].word -ceq 'PASS-DIB') -and ($rd[0].ok -eq $true) -and ($rd[0].admits -eq $true) -and
                ($rd[0].exit_code -eq 1) -and ((@($rd[0].admitted) -join '|') -ceq ($detAdm -join '|')) -and
                ($rd[0].against -ceq '.mission/dispatches/D-UC35.anchors.yaml') -and ($rd[0].against_checked -eq $true)
        $ident = ($rd.Count -eq 1) -and ($rd[0].report_path -ceq $v.source_path) -and ($rd[0].report_sha256 -ceq $v.sha256)
        $keys = (@($p.PSObject.Properties.Name) -join ',') -ceq 'goal,verdict,evaluated_at,hook_or_hand,verify_readings'
        $rkeys = ($rd.Count -eq 1) -and ((@($rd[0].PSObject.Properties.Name) -join ',') -ceq 'detector,ok,exit_code,word,admits,admitted,boundary,against,against_checked,report_path,report_sha256')
        $words = @($T, $M, $env:USERPROFILE, $env:COMPUTERNAME) + $(if ($env:USERNAME.Length -gt 3) { @($env:USERNAME) } else { @() })
        $hostWord = @($words | Where-Object { $_ -and $gv[0].text.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
        $d34 += "  order: goal_verdict seq $($g.seq) after verify_result seq $($v.seq), ts $($g.ts) >= $($v.ts) -> $order"
        $d34 += "  source: $($g.source_path) sha256 = the verdict file's bytes after the run -> $src"
        $d34 += "  goal/verdict/evaluated_at/hook_or_hand as the file holds them, schema_version 1.2 as the writer stamps it -> $hdr"
        $d34 += "  reading: word $($rd[0].word), admits $($rd[0].admits), admitted [$(@($rd[0].admitted) -join ', ')] (the verdict detail's: [$($detAdm -join ', ')]) -> $read"
        $d34 += "  identity: report_path $($rd[0].report_path), report_sha256 = the verify_result's source_path and sha256 -> $ident"
        $d34 += "  payload keys exactly the eleven named (no transcript, no credential) -> $($keys -and $rkeys); host words in the line: $($hostWord.Count) -> $($hostWord.Count -eq 0)"
        if ($mode -eq 'hook') { $d34 += "  payload: " + ($gv[0].text -replace '^.*"payload":', '' -replace ',"source_path".*$', '') }
        $ok34 = $ok34 -and $order -and $src -and $hdr -and $read -and $ident -and $keys -and $rkeys -and ($hostWord.Count -eq 0)
    }
    # an absent goal is an evaluation with a verdict file: one line, no reading; the worker guard is no evaluation: none
    $before = @(Get-FeedLines)
    $ra = Invoke-Eval -Evaluator $evalNew -GoalId 'G-NONE' -Hook
    $na = @(Get-FeedLines | Select-Object -Skip $before.Count | Where-Object { $_.obj.kind -eq 'goal_verdict' })
    $absOk = ($na.Count -eq 1) -and ($na[0].obj.payload.verdict -ceq 'GOAL_ABSENT') -and (@($na[0].obj.payload.verify_readings).Count -eq 0) -and ($na[0].obj.sha256 -ceq $ra.verdictSha)
    $d34 += "absent goal (hook): $($na.Count) goal_verdict line(s), verdict '$(if ($na.Count) { $na[0].obj.payload.verdict })', readings $(if ($na.Count) { @($na[0].obj.payload.verify_readings).Count }) -> $absOk"
    $before = @(Get-FeedLines)
    $rw = Invoke-Eval -Evaluator $evalNew -GoalId $goal -Hook -Dispatch 'uc35-worker'
    $nw = @(Get-FeedLines | Select-Object -Skip $before.Count | Where-Object { $_.obj.kind -eq 'goal_verdict' })
    $d34 += "a dispatched worker's stop (the worker guard, no evaluation): $($nw.Count) goal_verdict line(s) (expect 0) -> $($nw.Count -eq 0)"
    $ok34 = $ok34 -and $absOk -and ($nw.Count -eq 0)
    # builder review: a goal file outside the checkout puts its verdict outside it -- no line, and no hook-errors.log line for it
    $outGoal = Join-Path $T 'outside\G-OUT.yaml'
    Write-Utf8 $outGoal ((Get-Content -LiteralPath (Join-Path $M ".mission\goals\$goal.yaml") -Raw) -replace "id: $goal", 'id: G-OUT')
    $errCount = { @(Get-ChildItem -LiteralPath (Join-Path $M '.mission-runtime') -Recurse -File -Filter 'hook-errors.log' -ErrorAction SilentlyContinue | ForEach-Object { [System.IO.File]::ReadAllLines($_.FullName) } | Where-Object { $_ -match 'goal_verdict' }).Count }
    $e0 = & $errCount
    $before = @(Get-FeedLines)
    $ro = Invoke-Eval -Evaluator $evalNew -GoalId 'G-OUT' -Hook -GoalFile $outGoal
    $no = @(Get-FeedLines | Select-Object -Skip $before.Count | Where-Object { $_.obj.kind -eq 'goal_verdict' })
    $outOk = ($no.Count -eq 0) -and ((& $errCount) -eq $e0) -and (Test-Path -LiteralPath (Join-Path $T 'outside\G-OUT.verdict.yaml'))
    $d34 += "a goal file outside the checkout (-GoalFile): verdict beside it, $($no.Count) goal_verdict line(s), $((& $errCount) - $e0) new hook-errors.log line(s) naming goal_verdict (expect 0, 0) -> $outOk"
    # builder review: the boundary never carries the home folder or the user's name (a home folder holding a space included);
    # a goal id the scalar reader reads as null falls back to the file's name
    $unit = & {
        param($Lib, $Tm, $Root)
        . $Tm; . $Lib
        $saved = $env:USERPROFILE
        try {
            $env:USERPROFILE = 'C:\Users\Jane Doe'
            $b = Get-MissionTelemetryNoHostPath -Text (Remove-GoalVerdictUserWords -Text 'refused: C:\Users\Jane Doe\other\x.anchors.yaml is stale' -Root $Root) -Root $Root
        } finally { $env:USERPROFILE = $saved }
        $vp = Join-Path $Root '.mission\goals\null.verdict.yaml'
        [System.IO.File]::WriteAllText($vp, "goal: null`nevaluated_at: 2026-11-19T00:00:00.000Z`nverdict: NOT_MET`nhook_or_hand: hand`ndetectors: []`n")
        $pl = New-GoalVerdictPayload -Root $Root -VerdictPath $vp
        Remove-Item -LiteralPath $vp -Force
        [pscustomobject]@{ boundary = $b; goal = $pl.goal }
    } (Join-Path $repo 'tools\lam\goal-verdict-event.ps1') (Join-Path $repo 'tools\lam\mission-telemetry.ps1') $M
    $unitOk = ($unit.boundary -notmatch 'Jane|Doe') -and ($unit.goal -ceq 'null')
    $d34 += "boundary over a home folder holding a space: '$($unit.boundary)' (no 'Jane', no 'Doe'); a goal named null reads goal '$($unit.goal)' -> $unitOk"
    $ok34 = $ok34 -and $outOk -and $unitOk
    Check -Id 'UC-34' -Title 'after each evaluation, hook or hand, exactly one goal_verdict line follows the verify_result it read, its source the verdict file' -Ok $ok34 -Detail $d34

    # ---- UC-35: the three cases, against v1.3.2's evaluator ---------------------------------------------------------------
    $d35 = @(); $ok35 = $true
    $cases = @('present', 'absent', 'not writable')
    $ref = @{}
    foreach ($mode in @('hook', 'hand')) {
        $old = Invoke-Eval -Evaluator $evalOld -GoalId $goal -Hook:($mode -eq 'hook')
        $ref[$mode] = [pscustomobject]@{ code = $old.code; verdict = Get-Verdict $old.verdictText; out = (Format-Comparable $old.out $dirOld)
                                        err = (Format-Comparable $old.err $dirOld); file = (Format-Comparable $old.verdictText '') }
        $d35 += "v1.3.2 ($mode): exit $($old.code), verdict $($ref[$mode].verdict), $(@($old.out -split "`n" | Where-Object { $_.Trim() }).Count) printed line(s)"
    }
    foreach ($case in $cases) {
        if ($case -eq 'absent') { Remove-Item -LiteralPath $telDir -Recurse -Force }
        if ($case -eq 'not writable') { New-Item -ItemType Directory -Force -Path $telDir | Out-Null; Write-Utf8 $feedPath "{}`n"; (Get-Item -LiteralPath $feedPath).IsReadOnly = $true }
        $feedBefore = if (Test-Path -LiteralPath $feedPath) { Get-Sha $feedPath } else { '(none)' }
        foreach ($mode in @('hook', 'hand')) {
            $r = Invoke-Eval -Evaluator $evalNew -GoalId $goal -Hook:($mode -eq 'hook')
            $same = ($r.code -eq $ref[$mode].code) -and ((Get-Verdict $r.verdictText) -ceq $ref[$mode].verdict) -and
                    ((Format-Comparable $r.out $dirNew) -ceq $ref[$mode].out) -and ((Format-Comparable $r.err $dirNew) -ceq $ref[$mode].err) -and
                    ((Format-Comparable $r.verdictText '') -ceq $ref[$mode].file)
            $d35 += "feed $case ($mode): exit $($r.code), verdict $(Get-Verdict $r.verdictText); exit, verdict, printed lines (stdout and stderr) and verdict file equal to v1.3.2's -> $same"
            $ok35 = $ok35 -and $same
        }
        $feedAfter = if (Test-Path -LiteralPath $feedPath) { Get-Sha $feedPath } else { '(none)' }
        if ($case -ne 'present') { $d35 += "  the feed after: $(if ($feedAfter -eq $feedBefore) { 'unchanged' } else { 'CHANGED' }) ($feedAfter)"; $ok35 = $ok35 -and ($feedAfter -eq $feedBefore) }
        $errLogs = @(Get-ChildItem -LiteralPath (Join-Path $M '.mission-runtime') -Recurse -File -Filter 'hook-errors.log' -ErrorAction SilentlyContinue)
        $d35 += "  hook-errors.log lines so far (the writer's own SS14 trace of a failed append): $(@($errLogs | ForEach-Object { [System.IO.File]::ReadAllLines($_.FullName) }).Count)"
        if ($case -eq 'not writable') { (Get-Item -LiteralPath $feedPath).IsReadOnly = $false; Remove-Item -LiteralPath $feedPath -Force }
    }
    # complete before the append: the line's sha256 is the verdict file's final bytes (checked under UC-34, present case);
    # restated here over a fresh hook run
    $before = @(Get-FeedLines)
    $rc = Invoke-Eval -Evaluator $evalNew -GoalId $goal -Hook
    $gc = @(Get-FeedLines | Select-Object -Skip $before.Count | Where-Object { $_.obj.kind -eq 'goal_verdict' })
    $complete = ($gc.Count -eq 1) -and ($gc[0].obj.sha256 -ceq $rc.verdictSha)
    $d35 += "the verdict file complete on disk before the append: the line binds sha256 $(if ($gc.Count) { $gc[0].obj.sha256.Substring(0, 12) }) = the file's final bytes $($rc.verdictSha.Substring(0, 12)) -> $complete"
    $ok35 = $ok35 -and $complete
    # the time of one evaluation, with (this tree) and without (v1.3.2) the append, alternated, feed present
    foreach ($mode in @('hook', 'hand')) {
        $tn = @(); $to = @()
        for ($i = 0; $i -lt $Runs; $i++) {
            $tn += (Invoke-Eval -Evaluator $evalNew -GoalId $goal -Hook:($mode -eq 'hook')).ms
            $to += (Invoke-Eval -Evaluator $evalOld -GoalId $goal -Hook:($mode -eq 'hook')).ms
        }
        $mn = ($tn | Sort-Object)[[int][Math]::Floor($Runs / 2)]; $mo = ($to | Sort-Object)[[int][Math]::Floor($Runs / 2)]
        $d35 += "time of one evaluation ($mode, $Runs runs each, alternated): with the append median $mn ms [$($tn -join ', ')]; without (v1.3.2) median $mo ms [$($to -join ', ')]; difference $($mn - $mo) ms"
    }
    Check -Id 'UC-35' -Title 'the append cannot change an evaluation: feed present, absent, not writable -- verdict, exit, printed lines, verdict file as v1.3.2' -Ok $ok35 -Detail $d35
}
catch {
    Check -Id 'TOP' -Title 'the member threw' -Ok $false -Detail @($_.Exception.Message, ("line " + $_.InvocationInfo.ScriptLineNumber))
}
finally {
    try { if (Test-Path -LiteralPath (Join-Path $M '.mission-runtime\telemetry\events.jsonl')) { (Get-Item -LiteralPath (Join-Path $M '.mission-runtime\telemetry\events.jsonl')).IsReadOnly = $false } } catch { }
    if (-not $KeepSandbox) { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction SilentlyContinue } else { Write-Host "sandbox kept at $T" }
}
Write-Host ''
Write-Host "EXIT: $failures"
exit $failures
