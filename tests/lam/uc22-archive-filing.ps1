#Requires -Version 5.1
<#
  UI-3 (1.3.3, seat "U-3 framework 1c"), contract section 7 -- THE RUNNER FILES EACH RESULT IN THE VALIDATORS ARCHIVE
  (register row 568): UC-22 (when the runner places a validator's result at tests/lam/<name>.result.yaml it also files a
  byte-equal copy under the mission root's validators archive, where the 1.3.2 reader finds it), UC-23 (a copy of the same
  name and the same bytes already there: nothing is written; the same name with other bytes: the existing file is never
  overwritten, the new bytes are kept beside it so the reader still finds, by name and hash, the one the ledger binds) and
  UC-24 (the archive copy cannot be written: the placement stands, the runner says so in one line naming the reason, and no
  dispatch fails for it).

  THE REAL RUNNER (tools/lam/mission-dispatch.ps1) in Windows PowerShell 5.1, in a child process, over mission roots of
  this script's own under %TEMP% -- each a git repository with the pre-push decider installed, a prior anchors file so the
  verify stub is the gate, and an empty spawn ledger -- as WP-2's R-54 drives it: the validator is stubbed in its real shape
  (it writes its result file in its own tree at the declared result_path and no handoff, so the runner rejects the missing
  handoff and exits 3, the designed validator completion), the verify command and the login probe are stubs. No real
  `claude` runs; nothing outside the sandbox is written. -Runner names another runner (a clean extract's, for the RED).
  The 1.3.2 reader is the archive lister of tools/lam/mission-telemetry.ps1 (Get-MissionValidatorsArchive), lifted from this
  tree's file by the parser.

  powershell -NoProfile -ExecutionPolicy Bypass -File tests\lam\uc22-archive-filing.ps1 [-Runner <mission-dispatch.ps1>] [-KeepSandbox]
  Prints one [PASS]/[FAIL] line per check (UC-22, UC-23, UC-24) and EXIT: <failures>; exits with the failure count.
#>
param([string]$Runner, [switch]$KeepSandbox)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Runner) { $Runner = Join-Path $repo 'tools\lam\mission-dispatch.ps1' }
$ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$T = Join-Path ([System.IO.Path]::GetTempPath()) ('uc22-' + [guid]::NewGuid().ToString('n').Substring(0, 8))
$utf8 = New-Object System.Text.UTF8Encoding($false)
$failures = 0
$ArchiveRel = '.mission-runtime\lam\validators'

function Write-Utf8 { param([string]$Path, [string]$Text)
    $d = Split-Path -Parent $Path; if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}
function Get-Sha { param([string]$Path) if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '(absent)' }; (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Check { param([string]$Id, [string]$Title, [bool]$Ok, [string[]]$Detail)
    Write-Host ''
    Write-Host ("[{0}] {1} -- {2}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Id, $Title)
    foreach ($d in @($Detail)) { if ($d) { Write-Host ('    ' + $d) } }
    if (-not $Ok) { $script:failures++ }
}
function Invoke-Git { param([string]$Dir, [string[]]$Argv)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = & git -C $Dir @Argv 2>&1; $c = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ code = $c; out = ((@($o) | ForEach-Object { "$_" }) -join "`n") }
}

# THE 1.3.2 READER'S LISTING, lifted from this tree's writer: the archive's files by lowercased name
$tAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'tools\lam\mission-telemetry.ps1'), [ref]$null, [ref]$null)
$lister = @($tAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -ceq 'Get-MissionValidatorsArchive') }, $true))
if ($lister.Count -ne 1) { throw "tools/lam/mission-telemetry.ps1 defines $($lister.Count) function(s) named Get-MissionValidatorsArchive" }
. ([scriptblock]::Create($lister[0].Extent.Text))

# THE PRE-PUSH DECIDER, as WP-2 installs it: the sealed library's own wrapper text (its one function lifted by the parser;
# the library is read, never changed, and not dot-sourced whole)
$hAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1'), [ref]$null, [ref]$null)
$wrap = @($hAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -ceq 'Get-EvidencePrePushWrapperText') }, $true))
if ($wrap.Count -ne 1) { throw "the sealed library defines $($wrap.Count) function(s) named Get-EvidencePrePushWrapperText" }
. ([scriptblock]::Create($wrap[0].Extent.Text))
$decider = Join-Path $repo 'tools\evidence-hooks-next\hooks\evidence-pre-push.ps1'

$stubs = Join-Path $T 'stubs'
$verifyPass = Join-Path $stubs 'verify-pass.ps1'
$probeOk = Join-Path $stubs 'probe-ok.ps1'
Write-Utf8 $verifyPass "Write-Output 'gate: PASS'`nexit 0`n"
Write-Utf8 $probeOk "Write-Output 'OK'`nexit 0`n"
$probeSeam = $false
try { $probeSeam = [bool]((Get-Command -Name $Runner -ErrorAction Stop).Parameters.ContainsKey('LoginProbeCommand')) } catch { $probeSeam = $false }

function New-MissionRoot { param([string]$Name)
    $root = Join-Path (Join-Path $T $Name) 'm'
    Write-Utf8 (Join-Path $root '.mission\mission.yaml') "id: mission-uc22-$Name`nstate: executing`n"
    Write-Utf8 (Join-Path $root 'src\seed.txt') "seed`n"
    Write-Utf8 (Join-Path $root '.gitignore') ".mission-runtime/`n"
    $i = Invoke-Git $root @('init', '-q')
    if ($i.code -ne 0) { throw "git init failed at ${root}: $($i.out)" }
    # the fixture's git dir is its own before any config write (WP-2's Assert-FixtureGitDir rule)
    $gd = (Invoke-Git $root @('rev-parse', '--absolute-git-dir')).out.Trim()
    if (-not ([System.IO.Path]::GetFullPath($gd)).StartsWith(([System.IO.Path]::GetFullPath($root).TrimEnd('\') + '\'), [System.StringComparison]::OrdinalIgnoreCase)) { throw "the fixture's git dir $gd is not inside $root; refusing before any git config write" }
    foreach ($kv in @(@('user.email', 'uc22@instrument.local'), @('user.name', 'UC-22 Instrument'), @('core.longpaths', 'true'))) { $null = Invoke-Git $root @('config', '--local', $kv[0], $kv[1]) }
    $null = Invoke-Git $root @('add', '-A'); $null = Invoke-Git $root @('commit', '-q', '-m', 'fixture seed')
    $head = (Invoke-Git $root @('rev-parse', 'HEAD')).out.Trim()
    $hooks = Join-Path $root '.git\hooks'; if (-not (Test-Path -LiteralPath $hooks)) { New-Item -ItemType Directory -Force -Path $hooks | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $hooks 'pre-push'), (Get-EvidencePrePushWrapperText -DeciderPath $decider), $utf8)
    Write-Utf8 (Join-Path $root '.mission\dispatches\D-PRIOR.anchors.yaml') "dispatch_id: D-PRIOR`nworktree_tip_sha: $head`ncapture_gaps_count: 0`n"
    Write-Utf8 (Join-Path $root '.mission-runtime\lam\spawn-ledger.jsonl') ''
    return $root
}

function Invoke-Validator { param([string]$Root, [string]$Id, [string]$Body, [string]$Rel = 'tests/lam/validator-A-1.result.yaml', [string]$Validates = 'A-1', [int]$Round = 1)
    $bodyFile = Join-Path $stubs "body-$Id.yaml"
    Write-Utf8 $bodyFile $Body
    $stub = Join-Path $stubs "validator-$Id.ps1"
    Write-Utf8 $stub ("`$root = `$env:LAM_WORKTREE`n`$dst = Join-Path `$root '$Rel'`n" +
        "New-Item -ItemType Directory -Path (Split-Path -Parent `$dst) -Force | Out-Null`n" +
        "Copy-Item -LiteralPath '$bodyFile' -Destination `$dst -Force`nWrite-Output 'UC22-VALIDATOR-STUB'`nexit 0`n")
    Write-Utf8 (Join-Path $Root ".mission\dispatches\$Id.yaml") ("id: $Id`nmission_id: mission-uc22`nworker_id: w-$($Id.ToLower())`nkind: read-only`nfeature_id: F-001`n" +
        "assertion_targets: [$Validates]`nspec_version: 1`nworktree_id: wt-$($Id.ToLower())`nmodel_class: qa-validator`nvalidates: $Validates`nround: $Round`nresult_path: $Rel`n" +
        "goal_condition: `"the $Id fixture validator`"`n")
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Runner, '-MissionRoot', $Root, '-Dispatch', $Id, '-VerifyCommand', $verifyPass, '-WorkerCommand', $stub)
    if ($probeSeam) { $argv += @('-LoginProbeCommand', $probeOk) }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = & $ps51 @argv 2>&1; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
    $lines = @($out | ForEach-Object { "$_" })
    $anchors = Join-Path $Root ".mission\dispatches\$Id.anchors.yaml"
    $at = if (Test-Path -LiteralPath $anchors) { [System.IO.File]::ReadAllText($anchors) } else { '' }
    $field = { param($k) if ($at -match ("(?m)^" + [regex]::Escape($k) + ":[ \t]*(.*?)\r?$")) { $Matches[1].Trim().Trim("'") } else { '(absent)' } }
    $rej = Join-Path $Root ".mission\dispatches\$Id.handoff.yaml"
    $problems = if (Test-Path -LiteralPath $rej) { @(([System.IO.File]::ReadAllText($rej) -split "`n") | Where-Object { $_ -match '^\s+- ' } | ForEach-Object { $_.Trim() }) } else { @() }
    return [pscustomobject]@{ code = $code; lines = $lines; placement = (& $field 'validator_result_placement'); placedSha = (& $field 'validator_result_placement_sha256'); problems = $problems
                              dest = (Join-Path $Root ($Rel -replace '/', '\')) }
}
function Get-ArchiveFiles { param([string]$Root)
    $a = Join-Path $Root $ArchiveRel
    if (-not (Test-Path -LiteralPath $a -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $a -Recurse -File -Force | ForEach-Object { [pscustomobject]@{ rel = $_.FullName.Substring($Root.Length + 1); sha = (Get-Sha $_.FullName); mtime = $_.LastWriteTimeUtc.Ticks } } | Sort-Object rel)
}
function Get-Said { param($Run, [string]$Like) @($Run.lines | Where-Object { $_ -like $Like }) }
function Get-ReaderFinds { param([string]$Root, [string]$Sha, [string]$Leaf = 'validator-a-1.result.yaml')
    # the 1.3.2 reader's listing, then the bytes of each file of that name re-hashed: the copies it would try, and whether one
    # of them is the bound one
    $l = Get-MissionValidatorsArchive -Root $Root
    $copies = @(if ($l.by_name.ContainsKey($Leaf)) { $l.by_name[$Leaf] })
    $hit = @($copies | Where-Object { (Get-Sha (Join-Path $Root ($_ -replace '/', '\'))) -ceq $Sha })
    return [pscustomobject]@{ listed = $l.listed; copies = $copies; hit = $hit }
}

$pass1 = "# written by the UC-22 fixture validator`nverdict: PASS`nid: D-V-A-1`nvalidates: A-1`nchecks:`n  - one`n"
$pass2 = "# written by the UC-22 fixture validator, round 2`nverdict: REFUTED`nid: D-V-A-1-R2`nvalidates: A-1`nchecks:`n  - one`n"
Write-Host "runner    : $Runner"
Write-Host "sandbox   : $T"
try {
    # ---------------------------------------------------------------- UC-22: a placement files a byte-equal copy the reader finds
    $r = New-MissionRoot 'a'
    $a1 = Invoke-Validator -Root $r -Id 'D-UC22-A' -Body $pass1
    $files = @(Get-ArchiveFiles $r)
    $want = '.mission-runtime\lam\validators\D-UC22-A\validator-A-1.result.yaml'
    $copy = @($files | Where-Object { $_.rel -ceq $want })
    $placedSha = Get-Sha $a1.dest
    $finds = Get-ReaderFinds -Root $r -Sha $placedSha
    $said = @(Get-Said $a1 'mission-dispatch: validator result FILED in the validators archive at *')
    $ok22 = ($a1.placement -ceq 'placed') -and ($placedSha -ceq $a1.placedSha) -and ($files.Count -eq 1) -and ($copy.Count -eq 1) -and ($copy[0].sha -ceq $placedSha) -and
            $finds.listed -and ($finds.hit.Count -eq 1) -and ($said.Count -eq 1) -and ($said[0] -like "*$placedSha*")
    Check 'UC-22' 'a placement at tests/lam also files a byte-equal copy under the validators archive, where the 1.3.2 reader finds it' $ok22 @(
        "runner exit $($a1.code); anchors validator_result_placement=$($a1.placement) sha256=$($a1.placedSha); tests/lam copy sha256 $placedSha",
        "archive files: $(if ($files.Count) { ($files | ForEach-Object { "$($_.rel) ($($_.sha))" }) -join '; ' } else { 'none' }) (expect exactly $want, byte-equal)",
        "the 1.3.2 reader lists $($finds.copies.Count) file(s) named validator-A-1.result.yaml: $($finds.copies -join ', '); with the placed bytes: $($finds.hit.Count)",
        "said: $(if ($said.Count) { $said -join ' | ' } else { '(no FILED line)' })")

    # ---------------------------------------------------------------- UC-23: same name, same bytes -> nothing written; other bytes -> beside
    # the next round's preparation removes the working copy; a second dispatch places the SAME bytes at the same name
    Remove-Item -LiteralPath $a1.dest -Force
    $before = @(Get-ArchiveFiles $r)
    $a2 = Invoke-Validator -Root $r -Id 'D-UC22-B' -Body $pass1
    $after = @(Get-ArchiveFiles $r)
    $same = (($before | ForEach-Object { "$($_.rel)|$($_.sha)|$($_.mtime)" }) -join "`n") -ceq (($after | ForEach-Object { "$($_.rel)|$($_.sha)|$($_.mtime)" }) -join "`n")
    $saidSame = @(Get-Said $a2 'mission-dispatch: validator result ALREADY FILED in the validators archive at *')
    $okSame = ($a2.placement -ceq 'placed') -and $same -and ($after.Count -eq 1) -and ($saidSame.Count -eq 1) -and ($saidSame[0] -like "*D-UC22-A*") -and -not (Test-Path -LiteralPath (Join-Path $r "$ArchiveRel\D-UC22-B"))
    # other bytes at the same name: round 2's result (REFUTED) -- and, at the runner's own place for this dispatch, a file of the
    # same name with other bytes already standing (a planted one)
    Remove-Item -LiteralPath $a2.dest -Force
    $plant = Join-Path $r "$ArchiveRel\D-UC22-C\validator-A-1.result.yaml"
    Write-Utf8 $plant "# a file of the same name with other bytes, standing where the runner files this dispatch's copy`nverdict: PASS`n"
    $plantSha = Get-Sha $plant; $plantTicks = (Get-Item -LiteralPath $plant).LastWriteTimeUtc.Ticks
    $round1Sha = Get-Sha (Join-Path $r $want)
    $a3 = Invoke-Validator -Root $r -Id 'D-UC22-C' -Body $pass2 -Round 2
    $newSha = Get-Sha $a3.dest
    $files3 = @(Get-ArchiveFiles $r)
    $beside = @($files3 | Where-Object { ($_.rel -like '.mission-runtime\lam\validators\D-UC22-C\*\validator-A-1.result.yaml') -and ($_.sha -ceq $newSha) })
    $finds3 = Get-ReaderFinds -Root $r -Sha $newSha
    $saidOther = @(Get-Said $a3 'mission-dispatch: validator result FILED in the validators archive at *')
    $okOther = ($a3.placement -ceq 'placed') -and ($beside.Count -eq 1) -and ($beside[0].rel -ceq (".mission-runtime\lam\validators\D-UC22-C\" + $newSha.Substring(0, 16) + "\validator-A-1.result.yaml")) -and
               ((Get-Sha $plant) -ceq $plantSha) -and ((Get-Item -LiteralPath $plant).LastWriteTimeUtc.Ticks -eq $plantTicks) -and ((Get-Sha (Join-Path $r $want)) -ceq $round1Sha) -and
               ($finds3.copies.Count -eq 3) -and ($finds3.hit.Count -eq 1) -and ($saidOther.Count -eq 1)
    Check 'UC-23' 'the same name and bytes already in the archive: nothing written; the same name with other bytes: never overwritten, the new bytes kept beside it, the reader finding each by name and hash' ($okSame -and $okOther) @(
        "same bytes (D-UC22-B, the working copy removed first): placement=$($a2.placement); the archive before and after, path, sha256 and write time: $(if ($same) { 'IDENTICAL' } else { 'CHANGED' }) ($($after.Count) file(s)); said: $(if ($saidSame.Count) { $saidSame -join ' | ' } else { '(no ALREADY FILED line)' }) -> $okSame",
        "other bytes (D-UC22-C, round 2, a planted same-named file of other bytes at its own place): placement=$($a3.placement), new sha256 $newSha",
        "  the planted file $(if ((Get-Sha $plant) -ceq $plantSha) { 'unchanged' } else { 'CHANGED' }); round 1's copy $(if ((Get-Sha (Join-Path $r $want)) -ceq $round1Sha) { 'unchanged' } else { 'CHANGED' }); the new bytes at: $(if ($beside.Count) { $beside[0].rel } else { '(not filed beside)' })",
        "  the 1.3.2 reader lists $($finds3.copies.Count) file(s) of the name (expect 3): $($finds3.copies -join ', '); with round 2's bytes: $($finds3.hit.Count)",
        "  said: $(if ($saidOther.Count) { $saidOther -join ' | ' } else { '(no FILED line)' }) -> $okOther")

    # ---------------------------------------------------------------- UC-24: the archive cannot be written
    $r4 = New-MissionRoot 'd'
    $blocker = Join-Path $r4 $ArchiveRel
    Write-Utf8 $blocker "a file standing where the validators archive folder goes`n"
    $blockSha = Get-Sha $blocker
    $a4 = Invoke-Validator -Root $r4 -Id 'D-UC22-D' -Body $pass1
    $notFiled = @(Get-Said $a4 'mission-dispatch: validator result NOT FILED in the validators archive -- *')
    $anyArchive = @($a4.lines | Where-Object { $_ -match 'validators archive' })
    $probOf = { param($run) @($run.problems | ForEach-Object { $_ -replace 'D-UC22-[A-D]', 'D' -replace [regex]::Escape($r4), 'R' -replace [regex]::Escape($r), 'R' }) }
    $sameProblems = ((& $probOf $a4) -join "`n") -ceq ((& $probOf $a1) -join "`n")
    $ok24 = ($a4.placement -ceq 'placed') -and ((Get-Sha $a4.dest) -ceq $a4.placedSha) -and ($a4.code -eq $a1.code) -and $sameProblems -and
            ($notFiled.Count -eq 1) -and ($anyArchive.Count -eq 1) -and ($notFiled[0] -match 'the placement stands') -and ((Get-Sha $blocker) -ceq $blockSha) -and
            -not @($a4.problems | Where-Object { $_ -match 'archive' }).Count
    Check 'UC-24' 'the archive copy cannot be written: the placement stands, one line names the reason, and the dispatch does not fail for it' $ok24 @(
        "a file stands at $ArchiveRel; runner exit $($a4.code) (UC-22's run, the same dispatch with a writable archive: $($a1.code)); placement=$($a4.placement), the tests/lam copy $(if ((Get-Sha $a4.dest) -ceq $a4.placedSha) { 'present, byte-equal to the anchors' } else { 'NOT as placed' })",
        "the rejection record's problems equal UC-22's run's: $sameProblems ($($a4.problems.Count) problem(s), none naming the archive: $(-not @($a4.problems | Where-Object { $_ -match 'archive' }).Count))",
        "lines naming the archive: $($anyArchive.Count) (expect 1): $(if ($anyArchive.Count) { $anyArchive -join ' | ' } else { '(none)' })",
        "the file standing in the archive's place $(if ((Get-Sha $blocker) -ceq $blockSha) { 'unchanged' } else { 'CHANGED' })")
} catch {
    Check 'TOP' 'the script ran to its end' $false @("threw: $($_.Exception.Message)", "at: $($_.InvocationInfo.PositionMessage)")
} finally {
    if (-not $KeepSandbox) { try { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction Stop } catch { Write-Host "  (the sandbox could not be removed: $($_.Exception.Message))" } }
    else { Write-Host "sandbox kept at $T" }
}
Write-Host ''
Write-Host "EXIT: $failures"
exit $failures
