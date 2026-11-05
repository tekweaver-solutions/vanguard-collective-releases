#Requires -Version 5.1
<#
.SYNOPSIS
  LAM-ACCEPT WP-7 instrument -- "ui": the mission-event telemetry feed (UI-1 S1, falsifiers U-1..U-16; UI-1 S2-AM1, U-17),
  the service (UI-1 S2, V-1..V-15; S2-AM1, V-16..V-20) and the dashboard (UI-1 S3, L-1..L-16).

.DESCRIPTION
  THE EXIT CODE IS THE CONTRACT: 0 = every member passed, non-zero = the failure count.

  WHAT IT MEASURES. The UI-1 S0 contract's sixteen falsifiers (s1-falsifiers.md, ruled 2026-11-01)
  against expanded-schemas SS14 "Mission Event" and ADR-045: the schema file, the emitter in the
  next-generation hooks' library, the hook and verb emitters, the snapshot writer, host_id and the host
  registry, the ignore rule. E below is a fixture's .mission-runtime/telemetry/events.jsonl, and "one
  line" means exactly one new line that validates against docs/framework/mission-event.schema.json.

  THE FIXTURE (contract ruling (a)). Everything lives under ONE per-run root %TEMP%\w7<8 hex>, kept short
  because a deep fixture has failed on "Filename too long":
    s\   a smoke mission built by tools\lam\build-smoke-mission.ps1, then given the framework files its
         verbs run (copied byte for byte to the paths the installer gives them, and committed), then
         registered by Register-MissionCheckout -- the function mission init calls. VANGUARD_HOME = h\.
    f\   a fresh checkout made by `mission.ps1 init` under its own home h2\, for the members that are
         about minting and registering (U-13, U-14, U-15) and for spec-accept / spec-bump, which a smoke
         mission's spec layout cannot take (its current.txt names spec-v1.yaml, not v001).
    w\   a linked worktree of s\ (U-10).
    x\   a fresh checkout made by `mission init` under h2\ for the verbs whose cores are Python or git -- the LOM
         dispatch entry (tools\mission-dispatch.ps1), the validator result writer (transcribe-validator-results),
         the commit-ledger composer (commit_ledger.py) -- and for the push settle's tip_observed, which is
         driven end to end: a push gate, the real pre-push decider installed as git's hook, a real `git push` to
         a bare origin under the per-run root, then PostToolUse settling it.
  The hooks are driven from THIS checkout's tools\evidence-hooks-next\hooks with CLAUDE_PROJECT_DIR set to
  the fixture, exactly as the smoke builder drives them; the verbs run from the fixture's own copies.

  WHAT THIS INSTRUMENT CANNOT DRIVE, STATED. mission-gate.ps1's mint (approve/reapprove) and settle are
  admitted only through lam-console.ps1 in an operator's own interactive terminal: its NOT-INTERACTIVE and
  HARNESS-SESSION conditions fire in any agent session by design, and this instrument does not defeat a
  human touchpoint to measure a log line. So for gate_minted, gate_consumed and halt_resolved U-4 drives the
  shared emit functions those verbs call (Write-MissionGateEvent / Write-MissionHaltEvent) over fixture
  gate artifacts and READS the verbs' code for the call after each write; gate_expired IS driven end to
  end, through `mission-gate.ps1 list`, which needs no operator. revoke is admitted the same way, so U-5 writes
  revoke's own stamp onto a halt-ruling gate, runs revoke's own Send-LamGateTelemetry -Snapshot -- lifted out of
  mission-gate.ps1 by the PowerShell parser, its text unchanged but for $PSScriptRoot -- and READS revoke's code for
  that call after its write. The LAM runner's close (a handoff landing beside <id>.yaml) is measured the same way:
  its own Send-LamDispatchSnapshot, lifted from tools\lam\mission-dispatch.ps1, and the runner read for its calls.
  The LOM dispatch entry's Python core spawns a real worker, so x\ carries a STUB core (dispatch_entry.py) that
  writes the committed brief the real runner writes before its spawn, then -- standing in for the worker's run --
  waits to SEE its dispatch_opened in the feed while it still runs (validator round 1: a substitute that returned
  at once hid exactly that interval), and prints the DispatchResult the real core prints; the entry under test --
  tools\mission-dispatch.ps1, the emitter -- is the fixture's copy of the real one.

  THE AMENDMENT, U-17 and V-16..V-20 (UI-1 S2-AM1, s2-amendment-1.md, ruled 2026-11-03): U-17 beside U-16 reads the
  snapshot writer's milestones map over this fixture; V-16..V-20 beside V-15 are pytest members like V-2..V-14, over
  the dated fixture feeds l.jsonl and d.jsonl (series.yaml) as well as the S2 ones.

  THE SERVICE, V-1..V-15 (UI-1 S2, s2-falsifiers.md, ruled 2026-11-03): `vanguard ui` in tools\ui, read through
  its pytest suite tools\ui\tests\test_vNN.py -- one file per member, run ONCE for the wanted members by
  tools\.venv's interpreter, each test starting the service on an ephemeral 127.0.0.1 port over its own per-test
  home under %TEMP% and stopping it after. A V-member's verdict is WP-7's own: its file ran at least one test and
  every test passed, the fixture feeds tests\lam\fixtures\ui\*.jsonl validated line by line against the schema here
  (F3; the four V-4 plants in p.jsonl lines 9..12 must each be a rejection), and the member's own reading where it
  has one (V-1 the shim, V-15 the pattern scan). The V-members need none of the fixture below: when -Only names V-
  members alone, the fixture is not built. -HardPatternFile names the HARD-class pattern file (one literal per
  line); this host's computer name, user name, profile path and host-id are read against tools\ui as well. Where
  tools\ui\tests is not in the checkout -- an installed framework: the release ships tools\ui without its tests (UI-1
  S4 P-2) -- every V-member SKIPS BY NAME; the skip is counted, never passed. Likewise, where mission.ps1 or VERSION is
  not in the checkout (the release tree keeps them; an installed framework has neither), F-0's fresh init checkouts f\
  and x\ cannot be made: F-0 and U-4, U-5, U-10, U-13, U-14, U-15 and U-16 SKIP BY NAME, and the members that read only
  the smoke mission are measured.

  THE DASHBOARD, L-1..L-16 (UI-1 S3, s3-falsifiers.md, ruled 2026-11-03): ui\ (Vite + React + TypeScript), read through
  `npm ci --offline` and `npm run build` (twice from clean for L-1), its Playwright smoke ui\tests\lNN.spec.ts -- one
  file per browser member, run ONCE for the wanted members, each file over its own fixture home (the three registries
  of tests\lam\fixtures\ui) and its own `vanguard ui` serving ui\dist -- `npm run screenshots` twice (L-16), and this
  instrument's own readings: tests\lam\wp7-ui-audit.mjs (routes, no-ratio, the one tile, colours; parsed with the
  TypeScript the lockfile pins) and the scans of L-1, L-2, L-10, L-15. An L-member that needs Node or the Playwright
  browser SKIPS BY NAME on a host without them; the skip is counted, never passed. L-15 reads -HardPatternFile too.

  -Only runs the fixture and the named members (planted-breakage passes use it); a member -Only names that this
  instrument does not have reads FAIL on its own line, never "all 0 checks passed". -KeepFixture leaves the
  per-run root on disk.
#>
[CmdletBinding()]
param(
    [string[]]$Only,
    [switch]$KeepFixture,
    [string]$HardPatternFile
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hooksDir = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks'
$schemaPath = Join-Path $repoRoot 'docs\framework\mission-event.schema.json'
$psExe = Join-Path $PSHOME 'powershell.exe'

$failures  = 0
$checksRun = 0
$skips     = 0
$checkedIds = @{}
function Check {
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail, [switch]$Skipped)
    $script:checksRun++
    $script:checkedIds[$Id] = $true
    $tag = if ($Skipped) { 'SKIP' } elseif ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ""
    Write-Host "[$tag] $Id -- $Title"
    if ($Detail) { Write-Host $Detail }
    if ($Skipped) { $script:skips++ }
    elseif (-not $Ok) { $script:failures++ }
}
# `powershell -File ... -Only U-4,U-15` hands the list over as ONE string, so it is split here.
$Only = @(@($Only) | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
function Want { param([string]$Id)
    if ($script:VSkipped -and $Id -match '^V-\d+$') { return $false }
    if ($script:MSkipped -and $script:MSkipIds -contains $Id) { return $false }
    return ($Only.Count -eq 0) -or ($Only -contains $Id)
}
$script:VSkipped = $false
# The members whose subject is made or read by the release tree's mission.ps1 (init, register) or VERSION, which no
# installed framework carries (UI-1 S4 P-6, operator ruling of 2026-11-04): F-0's f\ and x\ checkouts, and the members
# that read them -- U-16 reads U-2..U-5's lines.
$script:MSkipped = $false
$script:MSkipIds = @('U-4', 'U-5', 'U-10', 'U-13', 'U-14', 'U-15', 'U-16')
# A MEMBER THAT THROWS READS RED ON ITS OWN LINE and the reading goes on: one member's broken subject must
# not take the other fifteen readings with it.
function Write-W7Threw { param([string]$Id, $E)
    Check -Id $Id -Title 'the member threw before reaching its own check' -Ok $false `
          -Detail ("    THREW: " + $E.Exception.Message + " (instrument line " + $E.InvocationInfo.ScriptLineNumber + ")")
}
# THE CLOSING LINES: the count is every check that ran. A member -Only named that ran no check -- one this instrument
# does not have -- is a FAIL of its own first, so a reading of absent members is RED, not "all 0 checks passed".
function Write-W7Close {
    foreach ($id in @($Only)) {
        if (-not $script:checkedIds.ContainsKey($id)) {
            Check -Id $id -Title 'named by -Only, but this instrument has no such member' -Ok $false -Detail "    members: F-0, U-1..U-17, V-1..V-20, L-1..L-16"
        }
    }
    Write-Host ""
    Write-Host "------------------------------------------------------------------------------"
    if ($script:failures -eq 0 -and $script:skips -eq 0) { Write-Host " WP-7: all $script:checksRun checks passed." }
    elseif ($script:failures -eq 0) {
        Write-Host " WP-7: $($script:checksRun - $script:skips) of $script:checksRun checks passed, $script:skips SKIPPED -- a skip is not a pass; see the [SKIP] line(s) above."
    }
    else { Write-Host (" WP-7: $script:failures of $script:checksRun checks FAILED." + $(if ($script:skips -gt 0) { '  (' + $script:skips + ' SKIPPED.)' } else { '' })) }
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "EXIT: $script:failures"
}

Write-Host "=============================================================================="
Write-Host " LAM WP-7 INSTRUMENT -- ui (the mission-event telemetry feed, U-1..U-17; the service, V-1..V-20; the dashboard, L-1..L-16)"
Write-Host "=============================================================================="
Write-Host "repo root : $repoRoot"
Write-Host "HEAD      : $((& git -C $repoRoot rev-parse HEAD 2>$null))"
if ($Only.Count) { Write-Host "only      : $($Only -join ', ')" }

# =================================================================================================
# helpers
# =================================================================================================
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Get-W7Sha { param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}
function Write-W7File { param([string]$Path, [string]$Text)
    $d = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

# ONE CHILD-PROCESS DRIVER. Environment is set for the child and restored; stdin is piped when given.
function Invoke-W7 {
    param([string]$File, [string[]]$Argv = @(), [hashtable]$Env = @{}, [string]$Stdin = $null, [string]$Cwd = $null, [string]$Exe = $null)
    if (-not $Exe) { $Exe = $psExe }
    $saved = @{}
    foreach ($k in $Env.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $Env[$k]) }
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ($Cwd) { Push-Location -LiteralPath $Cwd }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $argList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $File) + $Argv
        if ($null -ne $Stdin) { $o = @($Stdin | & $Exe @argList 2>&1) } else { $o = @(& $Exe @argList 2>&1) }
        $code = $LASTEXITCODE
    } finally {
        $sw.Stop()
        if ($Cwd) { Pop-Location }
        $ErrorActionPreference = $prevEap
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    return [pscustomobject]@{ out = @($o | ForEach-Object { "$_" }); code = $code; ms = [int]$sw.ElapsedMilliseconds }
}
# A NATIVE EXECUTABLE (python, git push), driven the same way: environment set and restored, output captured.
function Invoke-W7Native {
    param([string]$Exe, [string[]]$Argv = @(), [hashtable]$Env = @{}, [string]$Cwd = $null)
    $saved = @{}
    foreach ($k in $Env.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $Env[$k]) }
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ($Cwd) { Push-Location -LiteralPath $Cwd }
    try { $o = @(& $Exe @Argv 2>&1); $code = $LASTEXITCODE }
    finally {
        if ($Cwd) { Pop-Location }
        $ErrorActionPreference = $prevEap
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    return [pscustomobject]@{ out = @($o | ForEach-Object { "$_" }); code = $code }
}
function Invoke-W7Git { param([string]$Dir, [string[]]$Argv)
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = @(& git -C $Dir -c core.autocrlf=false -c commit.gpgsign=false -c user.name=w7-fixture -c user.email=w7-fixture@example.invalid @Argv 2>&1 | ForEach-Object { "$_" }); $c = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prevEap }
    return [pscustomobject]@{ out = $o; code = $c }
}

# A HOOK, driven as the harness drives it: one JSON payload on stdin, the project dir in the environment.
function Invoke-W7Hook {
    param([string]$Hook, [hashtable]$Payload, [string]$Root, [string]$Dispatch, [string]$VHome, [string]$Exe = $null, [hashtable]$ExtraEnv = @{})
    $env2 = @{ CLAUDE_PROJECT_DIR = $Root; MISSION_DISPATCH_ID = $Dispatch; VANGUARD_HOME = $VHome; LAM_DISPATCH = $null }
    foreach ($k in $ExtraEnv.Keys) { $env2[$k] = $ExtraEnv[$k] }
    $json = ($Payload | ConvertTo-Json -Compress -Depth 8)
    return (Invoke-W7 -File (Join-Path $hooksDir $Hook) -Env $env2 -Stdin $json -Exe $Exe)
}
function New-W7ToolPayload { param([string]$Session, [string]$Tool = 'Write', [hashtable]$ToolInput = @{}, $ToolResponse = $null)
    $p = @{ session_id = $Session; hook_event_name = 'PostToolUse'; tool_name = $Tool; tool_input = $ToolInput }
    if ($null -ne $ToolResponse) { $p['tool_response'] = $ToolResponse }
    return $p
}

# THE FEED, read as lines. A line that does not parse is kept as {_raw} so a validator can count it.
function Get-W7Feed { param([string]$Root)
    $p = Join-Path $Root '.mission-runtime\telemetry\events.jsonl'
    $res = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return ,$res }
    $text = [System.IO.File]::ReadAllText($p)
    foreach ($ln in ($text -split "`n")) {
        if ($ln -eq '') { continue }
        $o = $null
        try { $o = $ln | ConvertFrom-Json } catch { $o = $null }
        [void]$res.Add([pscustomobject]@{ raw = $ln; obj = $o })
    }
    return ,$res
}
function Get-W7FeedPath { param([string]$Root) Join-Path $Root '.mission-runtime\telemetry\events.jsonl' }
function Get-W7Kind { param($Lines, [string]$Kind) @($Lines | Where-Object { $_.obj -and $_.obj.kind -eq $Kind }) }
function Get-W7LastSeq { param([string]$Root)
    $f = Get-W7Feed -Root $Root
    $m = 0
    foreach ($l in $f) { if ($l.obj -and ($l.obj.PSObject.Properties.Name -contains 'seq')) { if ([int64]$l.obj.seq -gt $m) { $m = [int64]$l.obj.seq } } }
    return $m
}
function Get-W7Has { param($O, [string]$Name)
    if ($null -eq $O -or -not ($O -is [System.Management.Automation.PSCustomObject])) { return $false }
    return (@($O.PSObject.Properties | ForEach-Object { $_.Name }) -contains $Name)
}
function Get-W7Rows { param([string]$VHome)
    $p = Join-Path $VHome 'projects.yaml'
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    $rows = @(); $cur = $null
    foreach ($ln in [System.IO.File]::ReadAllLines($p)) {
        if ($ln -match '^- host_id:\s*(\S+)') { if ($cur) { $rows += [pscustomobject]$cur }; $cur = [ordered]@{ host_id = $Matches[1] }; continue }
        if ($cur -and $ln -match "^  ([a-z_]+):\s*'?(.*?)'?\s*$") { $cur[$Matches[1]] = $Matches[2] }
    }
    if ($cur) { $rows += [pscustomobject]$cur }
    return $rows
}
function Get-W7ErrCount { param([string]$Root, [string]$Dispatch)
    $p = Join-Path $Root (".mission-runtime\evidence\$Dispatch\hook-errors.log")
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    return @([System.IO.File]::ReadAllLines($p) | Where-Object { $_ -match 'events\.jsonl' }).Count
}

# -------------------------------------------------------------------------------------------------
# THE VALIDATOR: a draft-07 SUBSET, the repo's own precedent (tools\mission-verify.ps1 SS8c, hand-written
# because PowerShell 5.1 ships no Test-Json), extended by the two keywords the mission-event schema uses
# and that one lacks -- if/then/else and anyOf -- and made CASE-SENSITIVE for pattern/const/enum (a
# lowercase-hex pattern must refuse upper case). No dependency is added. Returns $null or the first failure.
# -------------------------------------------------------------------------------------------------
function Test-W7Type { param($V, [string]$T)
    switch ($T) {
        'null'    { return ($null -eq $V) }
        'object'  { return ($V -is [System.Management.Automation.PSCustomObject]) }
        'array'   { return ($V -is [System.Array]) }
        'string'  { return ($V -is [string]) }
        'boolean' { return ($V -is [bool]) }
        'integer' { return (($V -is [int]) -or ($V -is [long]) -or ($V -is [int16]) -or ($V -is [byte]) -or ($V -is [decimal] -and [decimal]::Truncate($V) -eq $V)) }
        'number'  { return (($V -is [int]) -or ($V -is [long]) -or ($V -is [double]) -or ($V -is [decimal]) -or ($V -is [single])) }
    }
    return $false
}
function Test-W7Equal { param($A, $B)
    if ($null -eq $A -or $null -eq $B) { return ($null -eq $A -and $null -eq $B) }
    if ($A -is [string] -or $B -is [string]) { return (($A -is [string]) -and ($B -is [string]) -and ($A -ceq $B)) }
    return ($A -eq $B)
}
function Test-W7Schema {
    param([AllowNull()]$I, $S, [string]$P = '')
    if ($S -is [bool]) { if ($S) { return $null } else { return "$P : false schema" } }
    if (-not (Get-W7Has $S '__dummy__') -and -not ($S -is [System.Management.Automation.PSCustomObject])) { return $null }
    if (Get-W7Has $S 'type') {
        $ok = $false
        foreach ($t in @($S.type)) { if (Test-W7Type $I ([string]$t)) { $ok = $true } }
        if (-not $ok) { return "$P : type is not $(@($S.type) -join '|')" }
    }
    if (Get-W7Has $S 'const') { if (-not (Test-W7Equal $I $S.const)) { return "$P : not const $($S.const)" } }
    if (Get-W7Has $S 'enum') {
        $hit = $false; foreach ($e in @($S.enum)) { if (Test-W7Equal $I $e) { $hit = $true } }
        if (-not $hit) { return "$P : not in enum ($(@($S.enum) -join ', '))" }
    }
    if ($I -is [string]) {
        if ((Get-W7Has $S 'pattern') -and -not [regex]::IsMatch($I, [string]$S.pattern)) { return "$P : does not match $($S.pattern)" }
        if ((Get-W7Has $S 'minLength') -and $I.Length -lt [int]$S.minLength) { return "$P : shorter than $($S.minLength)" }
    }
    if ((Test-W7Type $I 'number') -and (Get-W7Has $S 'minimum')) { if ([double]$I -lt [double]$S.minimum) { return "$P : below $($S.minimum)" } }
    if ($I -is [System.Management.Automation.PSCustomObject]) {
        if (Get-W7Has $S 'required') { foreach ($r in @($S.required)) { if (-not (Get-W7Has $I ([string]$r))) { return "$P : required '$r' absent" } } }
        $declared = @()
        if (Get-W7Has $S 'properties') {
            foreach ($pp in @($S.properties.PSObject.Properties)) {
                $declared += $pp.Name
                if (Get-W7Has $I $pp.Name) { $f = Test-W7Schema -I ($I.($pp.Name)) -S $pp.Value -P "$P/$($pp.Name)"; if ($f) { return $f } }
            }
        }
        if ((Get-W7Has $S 'additionalProperties') -and ($S.additionalProperties -is [bool]) -and (-not $S.additionalProperties)) {
            foreach ($n in @($I.PSObject.Properties | ForEach-Object { $_.Name })) { if ($declared -notcontains $n) { return "$P : additional property '$n'" } }
        }
    }
    if (($I -is [System.Array]) -and (Get-W7Has $S 'items')) {
        $k = 0; foreach ($it in $I) { $f = Test-W7Schema -I $it -S $S.items -P "$P/$k"; if ($f) { return $f }; $k++ }
    }
    if (Get-W7Has $S 'allOf') { foreach ($sub in @($S.allOf)) { $f = Test-W7Schema -I $I -S $sub -P $P; if ($f) { return $f } } }
    if (Get-W7Has $S 'anyOf') {
        $any = $false; foreach ($sub in @($S.anyOf)) { if (-not (Test-W7Schema -I $I -S $sub -P $P)) { $any = $true } }
        if (-not $any) { return "$P : matches no anyOf branch" }
    }
    if (Get-W7Has $S 'oneOf') {
        $n1 = 0; foreach ($sub in @($S.oneOf)) { if (-not (Test-W7Schema -I $I -S $sub -P $P)) { $n1++ } }
        if ($n1 -ne 1) { return "$P : matches $n1 oneOf branches" }
    }
    if (Get-W7Has $S 'not') { if (-not (Test-W7Schema -I $I -S $S.not -P $P)) { return "$P : matches a 'not' schema" } }
    if (Get-W7Has $S 'if') {
        if (-not (Test-W7Schema -I $I -S $S.if -P $P)) {
            if (Get-W7Has $S 'then') { $f = Test-W7Schema -I $I -S $S.then -P $P; if ($f) { return $f } }
        } elseif (Get-W7Has $S 'else') { $f = Test-W7Schema -I $I -S $S.else -P $P; if ($f) { return $f } }
    }
    return $null
}
$schemaObj = $null
try { $schemaObj = [System.IO.File]::ReadAllText($schemaPath) | ConvertFrom-Json } catch { $schemaObj = $null }
function Test-W7Line { param($Line)
    if ($null -eq $schemaObj) { return 'the schema file is absent or unparsable' }
    if ($null -eq $Line.obj) { return 'the line is not JSON' }
    return (Test-W7Schema -I $Line.obj -S $schemaObj -P '')
}
# "One line": exactly one new line of the kind, and it validates.
function Test-W7OneLine { param($Before, $After, [string]$Kind)
    $new = @(Get-W7Kind ($After | Select-Object -Skip $Before.Count) $Kind)
    $bad = @($new | ForEach-Object { Test-W7Line $_ } | Where-Object { $_ })
    return [pscustomobject]@{ ok = ($new.Count -eq 1 -and $bad.Count -eq 0); count = $new.Count; bad = $bad; line = $(if ($new.Count -ge 1) { $new[-1].obj } else { $null }) }
}

# =================================================================================================
# THE SERVICE -- V-1..V-15 (UI-1 S2), V-16..V-20 (UI-1 S2-AM1): tools\ui read through tools\ui\tests\test_vNN.py,
# one file per member
# =================================================================================================
$vWant = @(1..20 | ForEach-Object { "V-$_" } | Where-Object { Want $_ })
# An installed framework carries tools\ui without its tests (UI-1 S4 P-2: the release leaves tools/ui/tests in the
# development repository): no suite, no reading -- every wanted V-member SKIPS BY NAME, counted, never passed.
if ($vWant.Count -and -not (Test-Path -LiteralPath (Join-Path $repoRoot 'tools\ui\tests') -PathType Container)) {
    foreach ($id in $vWant) {
        Check -Id $id -Title 'the service, read through its pytest suite tools\ui\tests' -Ok $false -Skipped `
              -Detail "    SKIPPED BY NAME: the service's tests tools\ui\tests are not in this checkout (an installed framework ships tools\ui without them; UI-1 S4 P-2)"
    }
    $script:VSkipped = $true
    $vWant = @()
}
if ($vWant.Count) {
    $vPy = Join-Path $repoRoot 'tools\.venv\Scripts\python.exe'
    $vUi = Join-Path $repoRoot 'tools\ui'
    $vRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('v7' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $vRoot -Force | Out-Null

    # F3: every fixture line validates against the schema, by THIS instrument's validator. The four V-4 plants
    # (p.jsonl lines 9..12) must each be what they plant: no sha256, schema-invalid, not JSON, a repeated seq.
    $vfxLines = 0; $vfxBad = @(); $vfxPlant = @()
    foreach ($ff in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tests\lam\fixtures\ui') -Filter '*.jsonl' -File | Sort-Object Name)) {
        $n = 0; $seqs = @{}
        foreach ($ln in ([System.IO.File]::ReadAllText($ff.FullName) -split "`n")) {
            if ($ln -eq '') { continue }
            $n++; $vfxLines++
            $o = $null; try { $o = $ln | ConvertFrom-Json } catch { $o = $null }
            $why = Test-W7Line ([pscustomobject]@{ raw = $ln; obj = $o })
            $dup = ($null -ne $o) -and (Get-W7Has $o 'seq') -and $seqs.ContainsKey([string]$o.seq)
            if (($null -ne $o) -and (Get-W7Has $o 'seq')) { $seqs[[string]$o.seq] = $true }
            if ($ff.Name -eq 'p.jsonl' -and $n -ge 9 -and $n -le 12) {
                $planted = (@{ 9 = ([string]$why -match "required 'sha256' absent"); 10 = ([bool]$why -and $null -ne $o -and (Get-W7Has $o 'sha256')); 11 = ($null -eq $o); 12 = ((-not $why) -and $dup) })[$n]
                $vfxPlant += "p.jsonl:$n $(if ($planted) { 'planted as meant' } else { 'NOT AS PLANTED' }) ($(if ($why) { $why } elseif ($dup) { 'valid line, repeated seq' } else { 'valid' }))"
                if (-not $planted) { $vfxBad += "p.jsonl:$n is not the rejection it plants" }
                continue
            }
            if ($why) { $vfxBad += "$($ff.Name):$n $why" }
            elseif ($dup) { $vfxBad += "$($ff.Name):$n repeats a seq" }
        }
    }
    $vfxOk = ($vfxLines -gt 0) -and ($vfxBad.Count -eq 0) -and ($vfxPlant.Count -eq 4)
    $vfxDetail = "    fixture feeds (F3): $vfxLines line(s) read against the schema; outside the four plants $($vfxBad.Count) failing$(if ($vfxBad.Count) { ': ' + (($vfxBad | Select-Object -First 3) -join '; ') }); plants: $($vfxPlant -join '; ')`n"

    # ONE pytest run for the wanted members; each member reads its own file's cases from the junit XML.
    $vXml = Join-Path $vRoot 'junit.xml'
    $vFiles = @($vWant | ForEach-Object { 'tools\ui\tests\test_v{0:00}.py' -f [int]$_.Substring(2) })
    $vArgv = @('-m', 'pytest') + $vFiles + @('-q', '-p', 'no:cacheprovider', '--junitxml', $vXml)
    $vPt = Invoke-W7Native -Exe $vPy -Argv $vArgv -Cwd $repoRoot -Env @{ PYTHONDONTWRITEBYTECODE = '1'; VANGUARD_HOME = $null; VANGUARD_UI_DIST = $null; VANGUARD_HARD_PATTERNS = $(if ($HardPatternFile) { $HardPatternFile } else { $null }) }
    Write-Host "v-root    : $vRoot (pytest exit $($vPt.code); $(@($vPt.out | Select-Object -Last 1)))"
    $vCases = @{}
    if (Test-Path -LiteralPath $vXml -PathType Leaf) {
        $jx = New-Object System.Xml.XmlDocument
        $jx.Load($vXml)
        foreach ($tc in @($jx.SelectNodes('//testcase'))) {
            if ([string]$tc.GetAttribute('classname') -notmatch 'test_v(\d\d)') { continue }
            $num = [int]$Matches[1]
            $out = 'passed'; $msg = ''
            foreach ($tag in @('failure', 'error', 'skipped')) {
                $node = $tc.SelectSingleNode($tag)
                if ($node) { $out = $tag; $msg = ([string]$node.GetAttribute('message') -split "`n")[0]; break }
            }
            if (-not $vCases.ContainsKey($num)) { $vCases[$num] = @() }
            $vCases[$num] += [pscustomobject]@{ name = $tc.GetAttribute('name'); outcome = $out; msg = $msg }
        }
    }
}
# A V-member: its file's cases, every one passed, at least one; and the fixture feeds as F3 asks.
function Get-W7VReading { param([string]$Id)
    $num = [int]$Id.Substring(2)
    $cs = @(); if ($vCases.ContainsKey($num)) { $cs = @($vCases[$num]) }
    $pass = @($cs | Where-Object { $_.outcome -eq 'passed' }).Count
    $d = "    pytest tools\ui\tests\test_v{0:00}.py: {1} of {2} test(s) passed`n" -f $num, $pass, $cs.Count
    foreach ($c in $cs) { $d += "      [$($c.outcome)] $($c.name)$(if ($c.msg) { ' -- ' + $c.msg })`n" }
    if (-not $cs.Count) { $d += "      (no case ran: pytest said $(@($vPt.out | Select-Object -Last 3) -join ' | '))`n" }
    return [pscustomobject]@{ ok = ($cs.Count -gt 0 -and $pass -eq $cs.Count -and $vfxOk); detail = ($d + $vfxDetail) }
}

if (Want 'V-1') { try {
    $r = Get-W7VReading 'V-1'
    $sh = Invoke-W7Native -Exe 'cmd.exe' -Argv @('/c', (Join-Path $vUi 'vanguard.cmd'), 'ui', '--help') -Env @{ PYTHONDONTWRITEBYTECODE = '1' }
    $shOk = ($sh.code -eq 0) -and ((@($sh.out) -join "`n") -match 'Usage: vanguard ui')
    $reqText = [System.IO.File]::ReadAllText((Join-Path $vUi 'requirements.txt')) -replace "\\\r?\n", ' '
    $reqs = @($reqText -split "`n" | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') })
    $unhashed = @($reqs | Where-Object { $_ -notmatch '^[A-Za-z0-9._-]+==\S+\s+--hash=sha256:[0-9a-f]{64}' })
    $d = $r.detail + "    tools\ui\vanguard.cmd ui --help: exit $($sh.code), usage line 'Usage: vanguard ui': $shOk`n"
    $d += "    requirements.txt: $($reqs.Count) pinned requirement(s), $($unhashed.Count) without ==version and a sha256 --hash`n"
    Check -Id 'V-1' -Title 'package: tools/ui importable from tools\.venv; requirements.txt hash-pinned; vanguard ui --help exits 0; imports only the pinned set and the stdlib' `
          -Ok ($r.ok -and $shOk -and $reqs.Count -ge 3 -and $unhashed.Count -eq 0) -Detail $d
} catch { Write-W7Threw 'V-1' $_ } }
if (Want 'V-2') { try { $r = Get-W7VReading 'V-2'
    Check -Id 'V-2' -Title 'registry: four rows load; the stale row listed stale, never removed; the malformed row counted, never fatal; a row added while running appears within 2 s' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-2' $_ } }
if (Want 'V-3') { try { $r = Get-W7VReading 'V-3'
    Check -Id 'V-3' -Title 'tailer: an appended line is in /events within 2 s; a restart resumes at the last ingested seq, no re-ingest, no gap' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-3' $_ } }
if (Want 'V-4') { try { $r = Get-W7VReading 'V-4'
    Check -Id 'V-4' -Title 'ingest rejection: the four plants counted per stream with reason and seq or line, none an event; the seq gap reported with its range' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-4' $_ } }
if (Want 'V-5') { try { $r = Get-W7VReading 'V-5'
    Check -Id 'V-5' -Title 'disposable: delete ui.db, vanguard ui --rebuild, the four responses byte-identical (no clock value)' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-5' $_ } }
if (Want 'V-6') { try { $r = Get-W7VReading 'V-6'
    Check -Id 'V-6' -Title '/api/missions: one entry per mission_id, the worktree grouped with both identities, values from the snapshot and the feed, needs-attention order' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-6' $_ } }
if (Want 'V-7') { try { $r = Get-W7VReading 'V-7'
    Check -Id 'V-7' -Title '/api/missions/{id}: five header values, feature -> assertion, spec timeline, errors ranked with source_path@sha256, unknown kinds with counts' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-7' $_ } }
if (Want 'V-8') { try { $r = Get-W7VReading 'V-8'
    Check -Id 'V-8' -Title '/api/missions/{id}/events: paged, seq order, every line its feed line re-serialised canonically' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-8' $_ } }
if (Want 'V-9') { try { $r = Get-W7VReading 'V-9'
    Check -Id 'V-9' -Title '/api/missions/{id}/stats: Green, pass rate of evaluated, dispatches, validator rounds, HALTs and MTTR, exit rate or "not captured", elapsed per milestone; formula and window on every value' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-9' $_ } }
if (Want 'V-10') { try { $r = Get-W7VReading 'V-10'
    # UI-1 S4 C-7, a static reading in V-10's manner: no row of provenance\manifest.jsonl states an eol its blob does not
    # carry. Every row (the manifest's own, sha256 null, aside) is read against git's own reading of the blob in the index
    # (ls-files --eol, its i/ column: lf, crlf, mixed, none), one call for the tree.
    $gEol = @{}
    $gl = Invoke-W7Git -Dir $repoRoot -Argv @('-c', 'core.quotePath=false', 'ls-files', '--eol')
    foreach ($ln in @($gl.out)) { $tab = $ln.IndexOf("`t"); if ($tab -lt 0) { continue }; $gEol[$ln.Substring($tab + 1)] = (($ln.Substring(0, $tab).Trim() -split '\s+')[0]).Substring(2) }
    $eolWord = @{ 'lf' = 'LF'; 'crlf' = 'CRLF'; 'mixed' = 'MIXED'; 'none' = 'NONE'; '' = 'NONE' }
    $eolRows = 0; $eolBad = @()
    foreach ($ml in @([System.IO.File]::ReadAllLines((Join-Path $repoRoot 'provenance\manifest.jsonl')) | Select-Object -Skip 1 | Where-Object { $_ })) {
        $mr = $ml | ConvertFrom-Json
        if ($null -eq $mr.sha256) { continue }
        $eolRows++
        $g = $gEol[[string]$mr.destination]
        $want = if ($null -eq $g) { '(not tracked)' } elseif ($eolWord.ContainsKey($g)) { $eolWord[$g] } else { $g }
        if ([string]$mr.eol -cne $want) { $eolBad += "$($mr.destination): the row says $($mr.eol), the blob carries $want" }
    }
    $d = $r.detail + "    manifest eol (UI-1 S4 C-7): $eolRows row(s) read against git's index reading of their blobs (git ls-files exit $($gl.code)); $($eolBad.Count) disagreeing$(if ($eolBad.Count) { ': ' + (($eolBad | Select-Object -First 5) -join '; ') })`n"
    Check -Id 'V-10' -Title 'query-time stats: no table holds a computed statistic; only tools/ui/metrics.py computes a ratio; every manifest row''s eol is its blob''s' `
          -Ok ($r.ok -and $gl.code -eq 0 -and $eolRows -ge 400 -and $eolBad.Count -eq 0) -Detail $d
} catch { Write-W7Threw 'V-10' $_ } }
if (Want 'V-11') { try { $r = Get-W7VReading 'V-11'
    Check -Id 'V-11' -Title 'staleness: as_of {seq, commit, ts} per stream on every response; an unmoved stream keeps its as_of' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-11' $_ } }
if (Want 'V-12') { try { $r = Get-W7VReading 'V-12'
    Check -Id 'V-12' -Title 'error set closed: seven streams one class each, and nothing else; the eighth reports zero' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-12' $_ } }
if (Want 'V-13') { try { $r = Get-W7VReading 'V-13'
    Check -Id 'V-13' -Title 'SSE: an event within 2 s of the append with mission_id, stream identity and seq; Last-Event-ID receives what was missed' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-13' $_ } }
if (Want 'V-14') { try { $r = Get-W7VReading 'V-14'
    Check -Id 'V-14' -Title 'localhost: 127.0.0.1 by default, another address only by --host; no outbound socket in a full ingest and query pass' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-14' $_ } }
if (Want 'V-15') { try {
    $r = Get-W7VReading 'V-15'
    $pats = @()
    if ($HardPatternFile) { $pats += @([System.IO.File]::ReadAllLines($HardPatternFile) | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }) }
    foreach ($v in @($env:COMPUTERNAME, $env:USERNAME, $env:USERPROFILE)) { if ($v -and $v.Length -ge 4) { $pats += $v } }
    $hidF = Join-Path $env:USERPROFILE '.vanguard\host-id'
    if (Test-Path -LiteralPath $hidF -PathType Leaf) { $pats += ([System.IO.File]::ReadAllText($hidF)).Trim() }
    $pats = @($pats | Sort-Object -Unique)
    $hits = @(); $nf = 0
    foreach ($fi in @(Get-ChildItem -LiteralPath $vUi -Recurse -File | Where-Object { $_.FullName -notmatch '\\__pycache__\\' })) {
        $nf++
        $txt = [System.IO.File]::ReadAllText($fi.FullName)
        foreach ($p in $pats) { if ($txt.IndexOf($p, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += "$($fi.FullName.Substring($repoRoot.Length + 1)): pattern #$([array]::IndexOf($pats, $p))" } }
    }
    $d = $r.detail + "    HARD-class scan of tools\ui ($nf file(s)): $($pats.Count) pattern(s) ($(if ($HardPatternFile) { 'the file ' + $HardPatternFile + ' plus' } else { 'no pattern file given:' }) this host's computer name, user name, profile path, host-id); hits: $(if ($hits.Count) { $hits -join '; ' } else { '(none)' })`n"
    Check -Id 'V-15' -Title 'no host knowledge in tools/ui; dist/ served when present, a plain 404 when absent; the SPA path the only non-/api route' `
          -Ok ($r.ok -and $pats.Count -gt 0 -and $nf -ge 10 -and $hits.Count -eq 0) -Detail $d
} catch { Write-W7Threw 'V-15' $_ } }
# UI-1 S2-AM1 (s2-amendment-1.md): the figures the dashboard shows, each computed in tools\ui\metrics.py
if (Want 'V-16') { try { $r = Get-W7VReading 'V-16'
    Check -Id 'V-16' -Title '/stats series: green and pass rate per day, carried forward; dispatches and HALTs in 7-day buckets ending on the feed''s last ts, the first flagged partial_bucket; formula and window; computed at query time' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-16' $_ } }
if (Want 'V-17') { try { $r = Get-W7VReading 'V-17'
    Check -Id 'V-17' -Title '/api/missions fleet (in flight, open errors, active sessions, assertions green) and fleet_stats (four tiles, four series over every mission); formula and window; byte-identical across --rebuild' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-17' $_ } }
if (Want 'V-18') { try { $r = Get-W7VReading 'V-18'
    Check -Id 'V-18' -Title 'per-mission assertions, top_error, last_verify on /api/missions; the five header tiles on /api/missions/{id} with formula and window; every age against the feed''s last ts' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-18' $_ } }
if (Want 'V-19') { try { $r = Get-W7VReading 'V-19'
    Check -Id 'V-19' -Title 'live sessions (role, tool_calls, failed_calls or "not captured", elapsed) and dispatches (kind, feature, milestone, elapsed), counted in metrics.py' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-19' $_ } }
if (Want 'V-20') { try { $r = Get-W7VReading 'V-20'
    Check -Id 'V-20' -Title 'milestones[] from the latest snapshot''s map, ordered by id, with elapsed; milestone_progress; null with reason for a feed that predates the field' -Ok $r.ok -Detail $r.detail
} catch { Write-W7Threw 'V-20' $_ } }
if ($vWant.Count -and -not $KeepFixture) { Remove-Item -LiteralPath $vRoot -Recurse -Force -ErrorAction SilentlyContinue }

# =================================================================================================
# THE DASHBOARD -- L-1..L-16 (UI-1 S3, s3-falsifiers.md): ui\ read through its own toolchain (npm ci, npm run build),
# its Playwright smoke ui\tests\lNN.spec.ts (one file per browser member, run ONCE for the wanted members, each file
# over its own fixture home and `vanguard ui`), `npm run screenshots`, and this instrument's own readings: the
# TypeScript audit tests\lam\wp7-ui-audit.mjs and the scans below. A member that needs Node (or the Playwright
# browser) SKIPS BY NAME when it is absent from this host -- a skip is counted and is never a pass.
# =================================================================================================
$lWant = @(1..16 | ForEach-Object { "L-$_" } | Where-Object { Want $_ })
if ($lWant.Count) {
    $lUi = Join-Path $repoRoot 'ui'
    $lRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('l7' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $lRoot -Force | Out-Null
    $lNode = Get-Command 'node.exe' -ErrorAction SilentlyContinue
    $lNodeWhy = if ($lNode) { $null } else { 'node is not on PATH on this host (a customer never needs Node; ADR-045)' }
    # an installed framework carries ui\dist only, never the private source (ADR-045 "Distribution"): no source, no reading
    if (-not (Test-Path -LiteralPath (Join-Path $lUi 'package.json') -PathType Leaf)) { $lNode = $null; $lNodeWhy = "the dashboard's source ui\package.json is not in this checkout (an installed framework ships ui\dist only; ADR-045)" }
    $lNodeV = if ($lNode) { ((& $lNode.Source --version) -join '').Trim() } else { '' }
    $lNvmrc = if (Test-Path -LiteralPath (Join-Path $lUi '.nvmrc')) { ([System.IO.File]::ReadAllText((Join-Path $lUi '.nvmrc'))).Trim() } else { '' }
    Write-Host "l-root    : $lRoot (node $(if ($lNode) { $lNodeV } else { 'ABSENT' }); ui\.nvmrc $lNvmrc)"
    $lNpm = { param([string[]]$A) Invoke-W7Native -Exe 'cmd.exe' -Argv (@('/d', '/c', 'npm') + $A) -Cwd $lUi -Env @{ npm_config_update_notifier = 'false'; npm_config_audit = 'false'; npm_config_fund = 'false' } }
    $lTree = { param([string]$Dir)
        $h = [ordered]@{}
        if (Test-Path -LiteralPath $Dir) { foreach ($fi in @(Get-ChildItem -LiteralPath $Dir -Recurse -File | Sort-Object FullName)) { $h[$fi.FullName.Substring($Dir.Length + 1)] = Get-W7Sha $fi.FullName } }
        return $h
    }
    $lDist = Join-Path $lUi 'dist'
    $lBuilt = $false; $l1 = $null; $lBrowser = $null; $lBrowserWhy = $null; $lAudit = $null; $lShot1 = $null; $lShotAt = $null
    if ($lNode) {
        # L-1: npm ci (offline: the lockfile's tarballs from the npm cache, no registry), build, again from clean
        if ((Want 'L-1') -or -not (Test-Path -LiteralPath (Join-Path $lUi 'node_modules'))) {
            $c1 = & $lNpm @('ci', '--offline'); $b1 = & $lNpm @('run', 'build')
            $t1 = & $lTree $lDist
            $c2 = & $lNpm @('ci', '--offline')
            if (Test-Path -LiteralPath $lDist) { Remove-Item -LiteralPath $lDist -Recurse -Force }
            $b2 = & $lNpm @('run', 'build')
            $t2 = & $lTree $lDist
            $diff = @(@($t1.Keys) + @($t2.Keys) | Sort-Object -Unique | Where-Object { $t1[$_] -ne $t2[$_] })
            $l1 = [pscustomobject]@{ c1 = $c1.code; b1 = $b1.code; c2 = $c2.code; b2 = $b2.code; n = $t1.Count; diff = $diff; tail = @($c1.out + $b1.out + $c2.out + $b2.out | Select-Object -Last 4) }
            $lBuilt = ($b2.code -eq 0)
        } else {
            $b = & $lNpm @('run', 'build'); $lBuilt = ($b.code -eq 0)
            if (-not $lBuilt) { Write-Host ("  build failed:`n    " + (($b.out | Select-Object -Last 8) -join "`n    ")) }
        }
        $ex = Invoke-W7Native -Exe $lNode.Source -Argv @('-e', "process.stdout.write(require('@playwright/test').chromium.executablePath())") -Cwd $lUi
        $lBrowser = if ($ex.code -eq 0 -and (Test-Path -LiteralPath ((@($ex.out) -join '').Trim()))) { (@($ex.out) -join '').Trim() } else { $null }
        $lBrowserWhy = if ($lBrowser) { $null } else { "the Playwright chromium build pinned by ui\package-lock.json is not installed on this host ($((@($ex.out) -join ' ').Trim()))" }
        $au = Invoke-W7Native -Exe $lNode.Source -Argv @((Join-Path $repoRoot 'tests\lam\wp7-ui-audit.mjs'), $lUi)
        try { $lAudit = (@($au.out) -join "`n") | ConvertFrom-Json } catch { $lAudit = $null; Write-Host "  audit: $(@($au.out) -join ' ')" }
        if ($lBuilt -and $lBrowser -and (Want 'L-16')) {
            $lShot1 = Join-Path $lRoot 'shots1'
            $s1 = & $lNpm @('run', 'screenshots', '--', $lShot1); $lShotAt = Get-Date
            if ($s1.code -ne 0) { Write-Host ("  screenshots run 1: exit $($s1.code)`n    " + (($s1.out | Select-Object -Last 6) -join "`n    ")) }
        }
    }
    # ONE Playwright run for the wanted browser members; each reads its own spec file's tests from the JSON report.
    $lSpecs = @(3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14 | Where-Object { Want "L-$_" })
    $lCases = @{}
    if ($lNode -and $lBuilt -and $lBrowser -and $lSpecs.Count) {
        $pwJson = Join-Path $lRoot 'pw.json'
        $pwArgv = @((Join-Path $lUi 'node_modules\@playwright\test\cli.js'), 'test') + @($lSpecs | ForEach-Object { 'tests/l{0:00}.spec.ts' -f $_ })
        $pw = Invoke-W7Native -Exe $lNode.Source -Argv $pwArgv -Cwd $lUi -Env @{ PLAYWRIGHT_JSON_OUTPUT_NAME = $pwJson; FORCE_COLOR = '0'; CI = '1' }
        Write-Host "playwright: exit $($pw.code); $(@($pw.out | Where-Object { $_ -match '\d+ (passed|failed|flaky|skipped)' }) -join '; ')"
        if (Test-Path -LiteralPath $pwJson -PathType Leaf) {
            $rep = [System.IO.File]::ReadAllText($pwJson) | ConvertFrom-Json
            $walk = $null
            $walk = { param($s, [string]$File)
                $f = if ($s.file) { [string]$s.file } else { $File }
                foreach ($sp in @($s.specs)) { if (-not $sp) { continue }
                    foreach ($t in @($sp.tests)) {
                        $res = @($t.results | Select-Object -Last 1)
                        $msg = if ($res -and $res[0].error) { ([string]$res[0].error.message -split "`n")[0] } else { '' }
                        if ([string]$f -match 'l(\d\d)\.spec\.ts') { $n = [int]$Matches[1]; if (-not $lCases.ContainsKey($n)) { $lCases[$n] = @() }; $lCases[$n] += [pscustomobject]@{ name = $sp.title; outcome = [string]$t.status; msg = ($msg -replace '\x1b\[[0-9;]*m', '') } }
                    }
                }
                foreach ($c in @($s.suites)) { if ($c) { & $walk $c $f } }
            }
            foreach ($s in @($rep.suites)) { & $walk $s '' }
        }
    }
    if ($lShot1 -and (Want 'L-16')) {
        $gap = ((Get-Date) - $lShotAt).TotalSeconds
        if ($gap -lt 120) { Start-Sleep -Seconds ([int][Math]::Ceiling(120 - $gap)) }
        $lShot2 = Join-Path $lRoot 'shots2'
        $s2 = & $lNpm @('run', 'screenshots', '--', $lShot2)
        $lShotGap = [int]((Get-Date) - $lShotAt).TotalSeconds
    }
}
function Get-W7LSkip { param([string]$Id, [switch]$Browser)
    if (-not $lNode) { return $lNodeWhy }
    if ($Browser -and -not $lBrowser) { return $lBrowserWhy }
    return $null
}
function Get-W7LSpec { param([int]$N)
    $cs = @(); if ($lCases.ContainsKey($N)) { $cs = @($lCases[$N]) }
    $pass = @($cs | Where-Object { $_.outcome -eq 'expected' }).Count
    $d = "    playwright ui\tests\l{0:00}.spec.ts: {1} of {2} test(s) passed$(if (-not $lBuilt) { ' (the build failed)' })`n" -f $N, $pass, $cs.Count
    foreach ($c in $cs) { $d += "      [$(if ($c.outcome -eq 'expected') { 'passed' } else { $c.outcome })] $($c.name)$(if ($c.msg) { ' -- ' + $c.msg })`n" }
    return [pscustomobject]@{ ok = ($cs.Count -gt 0 -and $pass -eq $cs.Count); detail = $d }
}
function Write-W7LSkip { param([string]$Id, [string]$Title, [string]$Why) Check -Id $Id -Title $Title -Ok $false -Skipped -Detail "    SKIPPED BY NAME: $Why" }
function Get-W7UiText { param([string[]]$Sub)
    $out = @()
    foreach ($s in $Sub) {
        $p = Join-Path $lUi $s
        if (Test-Path -LiteralPath $p -PathType Leaf) { $out += Get-Item -LiteralPath $p; continue }
        if (Test-Path -LiteralPath $p) { $out += @(Get-ChildItem -LiteralPath $p -Recurse -File | Where-Object { $_.FullName -notmatch '\\(node_modules|test-results|playwright-report)\\' }) }
    }
    return $out
}

$t = 'toolchain pinned: .nvmrc and engines name one exact Node; package-lock.json tracked; npm ci the only install path; two clean builds byte-equal'
if (Want 'L-1') { try { $why = Get-W7LSkip 'L-1'; if ($why) { Write-W7LSkip 'L-1' $t $why } else {
    $pkg = [System.IO.File]::ReadAllText((Join-Path $lUi 'package.json')) | ConvertFrom-Json
    $inexact = @(@($pkg.dependencies.PSObject.Properties) + @($pkg.devDependencies.PSObject.Properties) | Where-Object { [string]$_.Value -notmatch '^\d+\.\d+\.\d+$' } | ForEach-Object { "$($_.Name)@$($_.Value)" })
    $scripts = @($pkg.scripts.PSObject.Properties | ForEach-Object { $_.Name })
    $installHooks = @($scripts | Where-Object { $_ -match '^(pre|post)?install$|^prepare$' })
    $lockTracked = @(& git -C $repoRoot ls-files -- 'ui/package-lock.json').Count -eq 1
    $npmrc = [System.IO.File]::ReadAllText((Join-Path $lUi '.npmrc'))
    $pinOk = ($lNvmrc -match '^\d+\.\d+\.\d+$') -and ([string]$pkg.engines.node -ceq $lNvmrc) -and ([string]$pkg.engines.npm -match '^\d+\.\d+\.\d+$') -and ("v$lNvmrc" -ceq $lNodeV) -and ($npmrc -match '(?m)^engine-strict=true\s*$')
    $d = "    .nvmrc '$lNvmrc'; engines node '$($pkg.engines.node)', npm '$($pkg.engines.npm)'; this host's node $lNodeV; .npmrc engine-strict=true: $($npmrc -match '(?m)^engine-strict=true\s*$') -> $pinOk`n"
    $d += "    dependencies not pinned to an exact x.y.z: $($inexact.Count)$(if ($inexact.Count) { ' -- ' + ($inexact -join ', ') }); install hooks in scripts: $(if ($installHooks.Count) { $installHooks -join ', ' } else { '(none)' }); package-lock.json tracked: $lockTracked`n"
    $buildOk = $l1 -and $l1.c1 -eq 0 -and $l1.b1 -eq 0 -and $l1.c2 -eq 0 -and $l1.b2 -eq 0 -and $l1.n -gt 0 -and $l1.diff.Count -eq 0
    $d += "    npm ci --offline (exit $($l1.c1)), npm run build (exit $($l1.b1)); npm ci --offline (exit $($l1.c2)), dist removed, npm run build (exit $($l1.b2)): $($l1.n) file(s), differing $($l1.diff.Count)$(if ($l1.diff.Count) { ': ' + (($l1.diff | Select-Object -First 4) -join ', ') }) -> $buildOk`n"
    if (-not $buildOk) { $d += "      tail: $($l1.tail -join ' | ')`n" }
    Check -Id 'L-1' -Title $t -Ok ($pinOk -and $inexact.Count -eq 0 -and $installHooks.Count -eq 0 -and $lockTracked -and $buildOk) -Detail $d
} } catch { Write-W7Threw 'L-1' $_ } }

$t = 'vendored components: every shadcn/ui component under ui/src/components/ui/ with the MIT notice; no registry reference in source or bundle; npm ls shows no shadcn package'
if (Want 'L-2') { try { $why = Get-W7LSkip 'L-2'; if ($why) { Write-W7LSkip 'L-2' $t $why } else {
    $vdir = Join-Path $lUi 'src\components\ui'
    $lic = Join-Path $vdir 'LICENSE.md'
    $licOk = (Test-Path -LiteralPath $lic) -and ([System.IO.File]::ReadAllText($lic) -match 'MIT License') -and ([System.IO.File]::ReadAllText($lic) -match 'Copyright \(c\) 2023 shadcn')
    $comps = @(Get-ChildItem -LiteralPath $vdir -Filter '*.tsx' -File)
    $noHeader = @($comps | Where-Object { -not ([System.IO.File]::ReadAllLines($_.FullName)[0] -match '^// Vendored from shadcn/ui \(MIT; see \./LICENSE\.md\)') } | ForEach-Object { $_.Name })
    $srcFiles = Get-W7UiText @('src')
    $used = @($srcFiles | ForEach-Object { [regex]::Matches([System.IO.File]::ReadAllText($_.FullName), '["'']@/components/ui/([\w-]+)["'']') | ForEach-Object { $_.Groups[1].Value } } | Sort-Object -Unique)
    $missing = @($used | Where-Object { -not (Test-Path -LiteralPath (Join-Path $vdir "$_.tsx")) })
    $regPat = 'shadcn\.com|/r/styles/|components\.json|registry\.json'
    $refs = @(Get-W7UiText @('src', 'dist', 'index.html', 'package.json', 'vite.config.ts', 'tailwind.config.js') | Where-Object { $_.Extension -notin @('.woff2', '.png') } | ForEach-Object { $fi = $_; [regex]::Matches([System.IO.File]::ReadAllText($fi.FullName), $regPat) | ForEach-Object { "$($fi.FullName.Substring($lUi.Length + 1)): $($_.Value)" } })
    $cj = Test-Path -LiteralPath (Join-Path $lUi 'components.json')
    $ls = & $lNpm @('ls', '--all', '--json')
    $lsNames = @([regex]::Matches((@($ls.out) -join "`n"), '"((?:@[\w.-]+/)?[\w.-]+)"\s*:\s*\{') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $shad = @($lsNames | Where-Object { $_ -match '^(shadcn|shadcn-ui|@shadcn/.*)$' })
    $d = "    LICENSE.md (MIT, Copyright (c) 2023 shadcn): $licOk; $($comps.Count) component file(s), without the one-line MIT header: $($noHeader.Count)$(if ($noHeader.Count) { ' -- ' + ($noHeader -join ', ') })`n"
    $d += "    imported from @/components/ui/: $($used -join ', '); not vendored: $($missing.Count)$(if ($missing.Count) { ' -- ' + ($missing -join ', ') })`n"
    $d += "    registry references ($regPat) in src, dist, index.html, package.json, configs: $($refs.Count)$(if ($refs.Count) { ' -- ' + (($refs | Select-Object -First 3) -join '; ') }); components.json present: $cj`n"
    $d += "    npm ls --all --json (exit $($ls.code)): $($lsNames.Count) package name(s), shadcn among them: $($shad.Count)$(if ($shad.Count) { ' -- ' + ($shad -join ', ') })`n"
    Check -Id 'L-2' -Title $t -Ok ($licOk -and $comps.Count -ge 5 -and $noHeader.Count -eq 0 -and $used.Count -ge 5 -and $missing.Count -eq 0 -and $refs.Count -eq 0 -and -not $cj -and $ls.code -eq 0 -and $lsNames.Count -gt 20 -and $shad.Count -eq 0) -Detail $d
} } catch { Write-W7Threw 'L-2' $_ } }

$t = 'routes: exactly four (/, /missions/:id, /missions/:id/stats, /stats); every request same-origin and every data request /api/*; each deep link renders after a reload'
if (Want 'L-3') { try { $why = Get-W7LSkip 'L-3' -Browser; if ($why) { Write-W7LSkip 'L-3' $t $why } else {
    $r = Get-W7LSpec 3
    $rt = @($lAudit.routes)
    $rtOk = (($rt -join ' ') -ceq '/ /missions/:id /missions/:id/stats /stats')
    $net = @(Get-W7UiText @('src') | Where-Object { $_.Extension -in @('.ts', '.tsx') } | ForEach-Object { $fi = $_; $tx = [System.IO.File]::ReadAllText($fi.FullName)
        if ($tx -match '\bfetch\s*\(' -and $fi.Name -notin @('api.ts', 'sse.ts')) { "$($fi.Name): fetch(" }
        if ($tx -match 'https?://|\bEventSource\b|\bWebSocket\b|XMLHttpRequest|\bnavigator\.sendBeacon\b') { "$($fi.Name): $($Matches[0])" } })
    $apiOk = ([System.IO.File]::ReadAllText((Join-Path $lUi 'src\lib\api.ts')) -match 'const API = "/api"')
    $d = $r.detail + "    routes in src/App.tsx (wp7-ui-audit): $($rt -join ', ') -> exactly the four: $rtOk`n"
    $d += "    network outside src/lib/api.ts and sse.ts (fetch, URLs, EventSource, WebSocket, XHR, beacons): $($net.Count)$(if ($net.Count) { ' -- ' + ($net -join '; ') }); the client's base is /api: $apiOk`n"
    Check -Id 'L-3' -Title $t -Ok ($r.ok -and $rtOk -and $net.Count -eq 0 -and $apiOk) -Detail $d
} } catch { Write-W7Threw 'L-3' $_ } }

$t = 'Fleet: header strip, four tiles in order, a card per mission in API order with state, errors, milestone, donut, activity, sessions, dispatches, error strip (source_path@sha256, +N more); severity borders; blocking cards above the fold at 1280x800'
if (Want 'L-4') { try { $why = Get-W7LSkip 'L-4' -Browser; if ($why) { Write-W7LSkip 'L-4' $t $why } else { $r = Get-W7LSpec 4; Check -Id 'L-4' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-4' $_ } }
$t = 'Project overview: breadcrumb, title and badges, five tiles in order; Errors ranked blocking before warning with kind, title, detail, age and a copying source chip; Milestones with All / Needs attention; Live activity; Last verify'
if (Want 'L-5') { try { $why = Get-W7LSkip 'L-5' -Browser; if ($why) { Write-W7LSkip 'L-5' $t $why } else { $r = Get-W7LSpec 5; Check -Id 'L-5' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-5' $_ } }
$t = 'verify shows scope: on the Fleet card strip, the Project tile and the Last verify card the scope (milestone, checks, arms) is visible in the type size of the verdict word'
if (Want 'L-6') { try { $why = Get-W7LSkip 'L-6' -Browser; if ($why) { Write-W7LSkip 'L-6' $t $why } else { $r = Get-W7LSpec 6; Check -Id 'L-6' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-6' $_ } }

$t = 'stats, mission and fleet: four tiles and the charts (green over time with the labelled dashed pass rate, weekly dispatches and HALTs, elapsed per milestone; selector and slowest milestones on the fleet view); ui/src computes no ratio'
if (Want 'L-7') { try { $why = Get-W7LSkip 'L-7' -Browser; if ($why) { Write-W7LSkip 'L-7' $t $why } else {
    $r = Get-W7LSpec 7
    $math = @($lAudit.math)
    $d = $r.detail + "    wp7-ui-audit over $(@($lAudit.files).Count) file(s) of ui/src: division, modulo or *100 outside the vendored src/components/ui/ and the two display formatters (format.ts pct() *100, duration() /): $($math.Count)$(if ($math.Count) { ' -- ' + (($math | Select-Object -First 4) -join '; ') })`n"
    $d += "      the formatters' own, allowed: $(@($lAudit.mathAllowed) -join '; ')`n"
    Check -Id 'L-7' -Title $t -Ok ($r.ok -and $lAudit -and $math.Count -eq 0) -Detail $d
} } catch { Write-W7Threw 'L-7' $_ } }

$t = 'one KPI tile component: one file puts data-kpi-tile on an element, its one export reached by all four screens; every tile shows the API formula and window verbatim on hover and on focus'
if (Want 'L-8') { try { $why = Get-W7LSkip 'L-8' -Browser; if ($why) { Write-W7LSkip 'L-8' $t $why } else {
    $r = Get-W7LSpec 8
    $attr = @($lAudit.kpi.attribute | Sort-Object -Unique)
    $scr = $lAudit.kpi.screens
    $scrOk = $scr -and $scr.FleetPage -and $scr.ProjectPage -and $scr.MissionStatsPage -and $scr.FleetStatsPage
    $ex = @($lAudit.kpi.exports)
    $d = $r.detail + "    data-kpi-tile is set in: $($attr -join ', ') (expect src/components/KpiTile.tsx alone); its exports: $($ex -join ', '); reached by the four screens (Fleet, Project, MissionStats, FleetStats): $($scr.FleetPage), $($scr.ProjectPage), $($scr.MissionStatsPage), $($scr.FleetStatsPage)`n"
    Check -Id 'L-8' -Title $t -Ok ($r.ok -and (($attr -join ',') -ceq 'src/components/KpiTile.tsx') -and (($ex -join ',') -ceq 'KpiTile') -and $scrOk) -Detail $d
} } catch { Write-W7Threw 'L-8' $_ } }

$t = 'staleness everywhere: the header badge is the fleet''s newest as_of; every KPI tile and chart card carries its stream''s as_of; an unmoved feed keeps its badge across a refetch; an older stream is marked stale'
if (Want 'L-9') { try { $why = Get-W7LSkip 'L-9' -Browser; if ($why) { Write-W7LSkip 'L-9' $t $why } else { $r = Get-W7LSpec 9; Check -Id 'L-9' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-9' $_ } }

$t = 'tokens: one accent (brand, indigo) for progress bars, links and the active-tab marker; status tokens ok, bad, warn, neutral; Validating neutral with an accent dot; no hex or rgb() in ui/src outside the token file'
if (Want 'L-10') { try { if (-not (Test-Path -LiteralPath (Join-Path $lUi 'package.json') -PathType Leaf)) { Write-W7LSkip 'L-10' $t $lNodeWhy } else {
    $tok = [System.IO.File]::ReadAllText((Join-Path $lUi 'src\styles\tokens.css'))
    $blocks = @([regex]::Matches($tok, '(:root|\.dark)\s*\{([^}]*)\}') | ForEach-Object { [pscustomobject]@{ sel = $_.Groups[1].Value; names = @([regex]::Matches($_.Groups[2].Value, '--([\w-]+)\s*:') | ForEach-Object { $_.Groups[1].Value }) } })
    $need = @('brand', 'ok', 'bad', 'warn', 'neutral')
    $tokOk = ($blocks.Count -eq 2) -and (@($blocks | Where-Object { $n = $_.names; @($need | Where-Object { $n -notcontains $_ }).Count -gt 0 }).Count -eq 0)
    $accents = @($blocks | ForEach-Object { $_.names } | Where-Object { $_ -match '^(brand|accent-color|indigo)' } | Sort-Object -Unique)
    $lit = @(); $brandAt = @()
    foreach ($fi in @(Get-W7UiText @('src') | Where-Object { $_.FullName -ne (Join-Path $lUi 'src\styles\tokens.css') -and $_.Extension -in @('.ts', '.tsx', '.css', '.js', '.mjs', '.html') })) {
        $ln = 0
        foreach ($l in [System.IO.File]::ReadAllLines($fi.FullName)) { $ln++
            if ($l -match '#[0-9a-fA-F]{3,8}\b' -or $l -match '(?i)\brgba?\s*\(' -or $l -match '(?i)\bhsla?\s*\(\s*\d') { $lit += "$($fi.FullName.Substring($lUi.Length + 1)):$ln" }
            if (($l -replace '//.*$', '') -match '\bbrand\b') { $brandAt += $fi.FullName.Substring($lUi.Length + 1) }
        }
    }
    # the accent's users: the progress bars (Bars), links (App, MissionHeader, Fleet, FleetStats, Project), the tab marker
    # (MissionHeader), the Validating dot (Badges) -- each file's uses read in the detail line
    $allow = @('src\App.tsx', 'src\components\Bars.tsx', 'src\components\MissionHeader.tsx', 'src\components\Badges.tsx', 'src\pages\FleetPage.tsx', 'src\pages\FleetStatsPage.tsx', 'src\pages\ProjectPage.tsx')
    $brandFiles = @($brandAt | Sort-Object -Unique)
    $outside = @($brandFiles | Where-Object { $allow -notcontains $_ })
    $badges = [System.IO.File]::ReadAllText((Join-Path $lUi 'src\components\Badges.tsx'))
    $valOk = $badges -match 'Validating:\s*\{\s*tone:\s*"neutral",\s*dot:\s*"brand"\s*\}'
    $tw = [System.IO.File]::ReadAllText((Join-Path $lUi 'tailwind.config.js'))
    $twOk = ($tw -match '(?m)^\s*theme:\s*\{\s*\r?\n\s*colors:\s*\{') -and ($tw -notmatch '#[0-9a-fA-F]{3,8}\b')
    $d = "    tokens.css: $($blocks.Count) theme block(s) ($(($blocks | ForEach-Object { $_.sel + ' ' + $_.names.Count }) -join ', ')), each defining $($need -join ', '): $tokOk; accent token(s): $($accents -join ', ') (expect brand alone)`n"
    $d += "    hex / rgb() / hsl(<number>) literals in ui/src outside the token file: $($lit.Count)$(if ($lit.Count) { ' -- ' + (($lit | Select-Object -First 5) -join ', ') })`n"
    $named = if ($lNode) { $au2 = Invoke-W7Native -Exe $lNode.Source -Argv @((Join-Path $repoRoot 'tests\lam\wp7-ui-audit.mjs'), $lUi); try { @(((@($au2.out) -join "`n") | ConvertFrom-Json).colours.named) } catch { @('the audit did not run') } } else { @() }
    $d += "    named CSS colours in colour attributes, style keys and Tailwind arbitrary values (wp7-ui-audit; needs Node: $(if ($lNode) { 'read' } else { 'not read on this host' })): $($named.Count)$(if ($named.Count) { ' -- ' + (($named | Select-Object -First 4) -join '; ') })`n"
    $d += "    files using the accent: $($brandFiles -join ', '); outside the allowed roles: $($outside.Count)$(if ($outside.Count) { ' -- ' + ($outside -join ', ') })`n"
    $d += "    Validating = neutral tone with the accent dot (Badges.tsx STATE_TONES): $valOk; tailwind.config.js REPLACES the palette (theme.colors, not extend) and names no hex: $twOk`n"
    Check -Id 'L-10' -Title $t -Ok ($tokOk -and (($accents -join ',') -ceq 'brand') -and $lit.Count -eq 0 -and $named.Count -eq 0 -and $brandFiles.Count -gt 0 -and $outside.Count -eq 0 -and $valOk -and $twOk) -Detail $d
} } catch { Write-W7Threw 'L-10' $_ } }

$t = 'themes: light and dark by a toggle kept per browser and by prefers-color-scheme; dark text, borders and badges in contrast (both themes are read by L-12)'
if (Want 'L-11') { try { $why = Get-W7LSkip 'L-11' -Browser; if ($why) { Write-W7LSkip 'L-11' $t $why } else { $r = Get-W7LSpec 11; Check -Id 'L-11' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-11' $_ } }
$t = 'smoke: four routes at 1280x800, 1440x900, 1920x1080 in both themes -- no console error or warning, no horizontal overflow, Tab reaches the first interactive element; the seven error classes on Fleet'
if (Want 'L-12') { try { $why = Get-W7LSkip 'L-12' -Browser; if ($why) { Write-W7LSkip 'L-12' $t $why } else { $r = Get-W7LSpec 12; Check -Id 'L-12' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-12' $_ } }
$t = 'live: a line appended to a fixture feed reaches the Fleet card and the Project header within 2 s with no reload (SSE); the header as_of advances'
if (Want 'L-13') { try { $why = Get-W7LSkip 'L-13' -Browser; if ($why) { Write-W7LSkip 'L-13' $t $why } else { $r = Get-W7LSpec 13; Check -Id 'L-13' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-13' $_ } }
$t = 'rejections visible: rejected lines (count, reasons, seq or line), seq gaps and unknown kinds on the Project overview, findable at 1440x900 without scrolling past the Errors panel'
if (Want 'L-14') { try { $why = Get-W7LSkip 'L-14' -Browser; if ($why) { Write-W7LSkip 'L-14' $t $why } else { $r = Get-W7LSpec 14; Check -Id 'L-14' -Title $t -Ok $r.ok -Detail $r.detail } } catch { Write-W7Threw 'L-14' $_ } }

$t = 'bundle: the chunk / and /missions/:id load holds no Recharts; no source maps in dist/; no file under ui/ names a host word; the fixture mission names generic'
if (Want 'L-15') { try { $why = Get-W7LSkip 'L-15'; if ($why) { Write-W7LSkip 'L-15' $t $why } else {
    $idx = Join-Path $lDist 'index.html'
    $html = if (Test-Path -LiteralPath $idx) { [System.IO.File]::ReadAllText($idx) } else { '' }
    $entry = @([regex]::Matches($html, '(?:src|href)="/assets/([^"]+\.js)"') | ForEach-Object { $_.Groups[1].Value })
    $stat = @($entry)
    foreach ($e in $entry) { $tx = [System.IO.File]::ReadAllText((Join-Path $lDist "assets\$e")); $stat += @([regex]::Matches($tx, '(?:^|[;}\s])import\s*(?:[\w$*{},\s]+?from\s*)?"\./([^"]+\.js)"') | ForEach-Object { $_.Groups[1].Value }) }
    $stat = @($stat | Sort-Object -Unique)
    $mark = 'recharts-wrapper'
    $inEntry = @($stat | Where-Object { [System.IO.File]::ReadAllText((Join-Path $lDist "assets\$_")).Contains($mark) })
    $js = @(Get-ChildItem -LiteralPath (Join-Path $lDist 'assets') -Filter '*.js' -File -ErrorAction SilentlyContinue)
    $holders = @($js | Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains($mark) } | ForEach-Object { $_.Name })
    $maps = @(Get-ChildItem -LiteralPath $lDist -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.map' -or ($_.Extension -in @('.js', '.css') -and [System.IO.File]::ReadAllText($_.FullName).Contains('sourceMappingURL')) } | ForEach-Object { $_.Name })
    $pats = @()
    if ($HardPatternFile) { $pats += @([System.IO.File]::ReadAllLines($HardPatternFile) | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }) }
    foreach ($v in @($env:COMPUTERNAME, $env:USERNAME, $env:USERPROFILE)) { if ($v -and $v.Length -ge 4) { $pats += $v } }
    $hidF = Join-Path $env:USERPROFILE '.vanguard\host-id'
    if (Test-Path -LiteralPath $hidF -PathType Leaf) { $pats += ([System.IO.File]::ReadAllText($hidF)).Trim() }
    $pats = @($pats | Sort-Object -Unique)
    $hits = @(); $nf = 0
    foreach ($fi in @(Get-W7UiText @('.'))) {
        $nf++
        $tx = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($fi.FullName))
        foreach ($p in $pats) { if ($tx.IndexOf($p, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += "$($fi.FullName.Substring($lUi.Length + 1)): pattern #$([array]::IndexOf($pats, $p))" } }
    }
    $mids = @()
    foreach ($y in @('projects.yaml', 'errors.yaml', 'series.yaml')) { $mids += @([regex]::Matches([System.IO.File]::ReadAllText((Join-Path $repoRoot "tests\lam\fixtures\ui\$y")), "(?m)^\s*mission_id:\s*'?([^'\r\n]+)'?") | ForEach-Object { $_.Groups[1].Value.Trim() }) }
    $notGeneric = @($mids | Where-Object { $_ -notmatch '^m-[a-z0-9]+$' })
    $d = "    dist\index.html loads $($entry -join ', '); with its static imports: $($stat -join ', '); holding '$mark': $($inEntry.Count) (expect 0); the chunk(s) that do: $($holders -join ', ') (expect at least one, loaded lazily)`n"
    $d += "    source maps in dist (*.map, sourceMappingURL): $($maps.Count)$(if ($maps.Count) { ' -- ' + ($maps -join ', ') })`n"
    $d += "    host-word scan of ui\ ($nf file(s), node_modules and the smoke's leftovers excepted): $($pats.Count) pattern(s) ($(if ($HardPatternFile) { 'the file ' + $HardPatternFile + ' plus' } else { 'no pattern file given:' }) this host's computer name, user name, profile path, host-id); hits: $(if ($hits.Count) { $hits -join '; ' } else { '(none)' })`n"
    $d += "    fixture mission ids ($($mids.Count)): $($mids -join ', '); not of the generic form m-<word>: $($notGeneric.Count)`n"
    Check -Id 'L-15' -Title $t -Ok ($lBuilt -and $entry.Count -ge 1 -and $inEntry.Count -eq 0 -and $holders.Count -ge 1 -and $maps.Count -eq 0 -and $pats.Count -gt 0 -and $nf -ge 20 -and $hits.Count -eq 0 -and $mids.Count -ge 8 -and $notGeneric.Count -eq 0) -Detail $d
} } catch { Write-W7Threw 'L-15' $_ } }

$t = 'screenshots, frozen clock: npm run screenshots renders the six counterparts of the look reference at 1440x900; two runs minutes apart are byte-equal'
if (Want 'L-16') { try { $why = Get-W7LSkip 'L-16' -Browser; if ($why) { Write-W7LSkip 'L-16' $t $why } else {
    $names = @('01-fleet.png', '02-project.png', '03-stats.png', '04-fleet-stats.png', '05-project.png', '06-fleet-dark.png')
    $rows = @(); $allOk = $true
    foreach ($n in $names) {
        $a = Join-Path $lShot1 $n; $b = Join-Path $lShot2 $n
        $ha = Get-W7Sha $a; $hb = Get-W7Sha $b
        $dim = ''
        if ($ha) { $by = [System.IO.File]::ReadAllBytes($a); $w = ([int]$by[16] -shl 24) -bor ([int]$by[17] -shl 16) -bor ([int]$by[18] -shl 8) -bor [int]$by[19]; $h = ([int]$by[20] -shl 24) -bor ([int]$by[21] -shl 16) -bor ([int]$by[22] -shl 8) -bor [int]$by[23]; $dim = "${w}x$h" }
        $ok = $ha -and ($ha -ceq $hb) -and ($dim -eq '1440x900')
        if (-not $ok) { $allOk = $false }
        $rows += "      $n $dim run1 $(if ($ha) { $ha.Substring(0, 16) } else { '(absent)' }) run2 $(if ($hb) { $hb.Substring(0, 16) } else { '(absent)' }) -> $(if ($ok) { 'equal' } else { 'NOT EQUAL / absent / wrong size' })"
    }
    $extra = @(@(Get-ChildItem -LiteralPath $lShot1 -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) | Where-Object { $names -notcontains $_ })
    $d = "    npm run screenshots twice, $lShotGap s apart (expect >= 120): run 2 exit $($s2.code)`n" + ($rows -join "`n") + "`n    other files written: $($extra.Count)`n"
    Check -Id 'L-16' -Title $t -Ok ($allOk -and $lShotGap -ge 120 -and $extra.Count -eq 0) -Detail $d
} } catch { Write-W7Threw 'L-16' $_ } }
if ($lWant.Count -and -not $KeepFixture) { Remove-Item -LiteralPath $lRoot -Recurse -Force -ErrorAction SilentlyContinue }

# -Only naming V- and L-members alone: the U fixture below is not needed, and not built.
if ($Only.Count -and -not @($Only | Where-Object { $_ -notlike 'V-*' -and $_ -notlike 'L-*' }).Count) {
    Write-W7Close
    exit $failures
}

# =================================================================================================
# THE FIXTURE
# =================================================================================================
$T  = Join-Path ([System.IO.Path]::GetTempPath()) ('w7' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$H  = Join-Path $T 'h'
$H2 = Join-Path $T 'h2'
$S  = Join-Path $T 's'
$F  = Join-Path $T 'f'
$W  = Join-Path $T 'w'
New-Item -ItemType Directory -Path $T -Force | Out-Null
Write-Host "fixture   : $T"

$fx = [ordered]@{}
# 1. the smoke mission
$b = Invoke-W7 -File (Join-Path $repoRoot 'tools\lam\build-smoke-mission.ps1') -Argv @('-SmokeRoot', $S) -Env @{ VANGUARD_HOME = $H; LAM_SMOKE_ROOT = $null }
$fx['smoke built (build-smoke-mission exit 0)'] = ($b.code -eq 0)
if ($b.code -ne 0) { Write-Host ("  smoke build output (tail):`n    " + (($b.out | Select-Object -Last 12) -join "`n    ")) }
$fx['smoke build seconds'] = [int]($b.ms / 1000)

# 2. the framework files the fixture's verbs run, copied to the paths the installer gives them
$copyRel = @('tools\mission-lib.ps1', 'tools\mission-ledger-append.ps1', 'tools\mission-spec-bump.ps1', 'tools\mission-spec-accept.ps1', 'tools\mission-design-start.ps1',
             'tools\mission-verify.ps1', 'tools\lam\mission-telemetry.ps1', 'tools\lam\mission-gate.ps1', 'tools\lam\lam-gate-class.ps1',
             'tools\lam\lam-verify-admission.ps1', 'docs\framework\evidence-manifest.schema.json',
             'tools\mission-dispatch.ps1', 'tools\lam\transcribe-validator-results.ps1', 'tools\lam\transcribe_validator_results.py',
             'tools\lam\commit_ledger.py', 'tools\lam\emit-mission-event.ps1')
foreach ($sub in @('tools\evidence-hooks-next\hooks', 'tools\framework\hooks')) {
    foreach ($fi in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot $sub) -Recurse -File -ErrorAction SilentlyContinue)) {
        $copyRel += $fi.FullName.Substring($repoRoot.Length).TrimStart('\')
    }
}
function Copy-W7Framework { param([string]$Dest)
    $missing = @()
    foreach ($rel in $copyRel) {
        $src = Join-Path $repoRoot $rel
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { $missing += $rel; continue }
        $dst = Join-Path $Dest $rel
        $dd = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null }
        [System.IO.File]::WriteAllBytes($dst, [System.IO.File]::ReadAllBytes($src))
    }
    return $missing
}
$missingS = @()
if (Test-Path -LiteralPath $S) {
    $missingS = Copy-W7Framework -Dest $S
    $null = Invoke-W7Git $S @('add', '--', 'tools', 'docs')
    $cm = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: the framework files the verbs run')
    $fx['framework files committed into the smoke mission'] = ($cm.code -eq 0)
}
$fx['framework files absent from this checkout'] = $(if ($missingS.Count) { $missingS -join ', ' } else { '(none)' })

# 3. registration -- Register-MissionCheckout, the function mission init calls
$regScript = Join-Path $T 'reg.ps1'
Write-W7File $regScript @'
param([string]$Root, [string]$Lib)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Lib)) { Write-Output "NO-REGISTER-FUNCTION: $Lib"; exit 4 }
. $Lib
$r = Register-MissionCheckout -Root $Root
Write-Output ("REGISTERED " + ($r | ConvertTo-Json -Compress))
exit 0
'@
$rg = Invoke-W7 -File $regScript -Argv @('-Root', $S, '-Lib', (Join-Path $S 'tools\lam\mission-telemetry.ps1')) -Env @{ VANGUARD_HOME = $H }
$fx['smoke registered (Register-MissionCheckout)'] = ($rg.code -eq 0)
$fx['telemetry folder present in the smoke mission'] = (Test-Path -LiteralPath (Join-Path $S '.mission-runtime\telemetry') -PathType Container)
$hostId = ''
if (Test-Path -LiteralPath (Join-Path $H 'host-id')) { $hostId = ([System.IO.File]::ReadAllText((Join-Path $H 'host-id'))).Trim() }
$fx['host-id'] = $(if ($hostId) { $hostId } else { '(absent)' })
$smokeMissionId = ''
if (Test-Path -LiteralPath (Join-Path $S '.mission\mission.yaml')) {
    $mm = [regex]::Match([System.IO.File]::ReadAllText((Join-Path $S '.mission\mission.yaml')), '(?m)^id:\s*(\S+)')
    if ($mm.Success) { $smokeMissionId = $mm.Groups[1].Value }
}

# 4. the fresh init checkout f\, under its own home h2\ (U-13's before/after is taken here)
New-Item -ItemType Directory -Path $F -Force | Out-Null
$h2Before = Test-Path -LiteralPath (Join-Path $H2 'host-id')
$fi1 = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $F) -Env @{ VANGUARD_HOME = $H2 }
$h2After = Test-Path -LiteralPath (Join-Path $H2 'host-id')
$h2Bytes1 = if ($h2After) { [System.IO.File]::ReadAllBytes((Join-Path $H2 'host-id')) } else { [byte[]]@() }
$fx['mission init of f exit 0'] = ($fi1.code -eq 0)
$missingF = Copy-W7Framework -Dest $F
$null = Invoke-W7Git $F @('init', '-q')
$null = Invoke-W7Git $F @('add', '-A')
$fc = Invoke-W7Git $F @('commit', '-q', '-m', 'w7 fixture: the installed framework files and the initialised mission')
$fx['f committed'] = ($fc.code -eq 0)

# 5. the fresh init checkout x\, under h2\: the verbs whose cores are Python or git (see .DESCRIPTION)
$X  = Join-Path $T 'x'
$XO = Join-Path $T 'xo.git'
$basePy = Join-Path $repoRoot 'tools\.venv\Scripts\python.exe'
$xEnv = @{ VANGUARD_HOME = $H2; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
New-Item -ItemType Directory -Path $X -Force | Out-Null
$xi = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $X) -Env @{ VANGUARD_HOME = $H2 }
$fx['mission init of x exit 0'] = ($xi.code -eq 0)
$null = Copy-W7Framework -Dest $X
$xm = Join-Path $X '.mission\mission.yaml'
if (Test-Path -LiteralPath $xm) { Write-W7File $xm (([System.IO.File]::ReadAllText($xm)) -replace '(?m)^state:\s*\S+', 'state: Executing') }
# THE LOM ENTRY RUNS <project>\tools\.venv\Scripts\python.exe: a venv of this checkout's own interpreter, made
# --without-pip (no network), and the STUB core beside it -- what the real core leaves for the entry, nothing more.
$xv = Invoke-W7Native -Exe $basePy -Argv @('-m', 'venv', '--without-pip', (Join-Path $X 'tools\.venv'))
$fx['x: the venv the LOM entry runs (exit 0)'] = ($xv.code -eq 0)
Write-W7File (Join-Path $X 'tools\worker-runner\dispatch_entry.py') @'
import json, os, sys, time, uuid
# THE WP-7 STUB CORE: the committed brief the real runner writes before its spawn -- its target list, then an
# operator note carrying a bullet of the targets' own shape -- then "the worker's run": the stub waits, up to 30 s,
# to SEE its dispatch_opened in the feed WHILE IT RUNS, and says whether it did; then the DispatchResult the real core
# prints on return. W7_CORE_MODE=refused: refused before the brief, exit 2. crash: the brief, then an uncaught raise.
args = json.load(open(sys.argv[1], encoding="utf-8"))
mode = os.environ.get("W7_CORE_MODE", "open")
if args.get("dry_run"):
    print("w7 stub core: a dry run, nothing spawned")
    sys.exit(0)
did = args.get("dispatch_id") or str(uuid.uuid4())
targets = args.get("assertion_targets") or ["A-W7-T1", "A-W7-T2"]
if mode in ("open", "crash"):
    d = os.path.join(args["project_root"], ".mission", "dispatches", did)
    os.makedirs(d)
    with open(os.path.join(d, "task-brief.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("# Task Brief -- " + args["feature_id"] + "\n\n## Artifacts to read\n\n- **Assertion targets** (must pass):\n")
        for t in targets:
            f.write("    - `" + t + "` -> `.mission/contract/assertions/" + t + ".yaml`\n")
        f.write("\n## Operator note (out-of-contract)\n\nThe prior worker:\n    - `the prior worker stubbed the migration` -> do it properly\n")
if mode == "crash":
    raise RuntimeError("w7 stub core: died after its brief")
if mode == "open":
    feed = os.path.join(args["project_root"], ".mission-runtime", "telemetry", "events.jsonl")
    seen = False
    for _ in range(150):
        try:
            with open(feed, "r", encoding="utf-8") as fh:
                seen = any('"kind":"dispatch_opened"' in ln and did in ln for ln in fh)
        except OSError:
            seen = False
        if seen:
            break
        time.sleep(0.2)
    print("w7 stub core: dispatch_opened seen while the core ran: " + str(seen))
code = 0 if mode == "open" else 2
print(json.dumps({"exit_code": code, "dispatch_id": did, "worktree_id": "wt-w7" if mode == "open" else None,
                  "validation_report": None, "error": None if mode == "open" else "w7 stub core: refused before the brief"}, indent=2))
sys.exit(code)
'@
# THE VALIDATOR RESULT WRITER'S INPUTS: two contract assertions of F-W7, two results bound on the spawn ledger by their
# complete lines' result_sha256 (A-W7-T1 PASS at round 1, A-W7-T2 REFUTED at round 2), and an empty store.
$xLedger = New-Object System.Text.StringBuilder
foreach ($a in @(@{ id = 'A-W7-T1'; verdict = 'PASS'; seq = 7001; round = 1 }, @{ id = 'A-W7-T2'; verdict = 'REFUTED'; seq = 7002; round = 2 })) {
    Write-W7File (Join-Path $X ".mission\contract\assertions\$($a.id).yaml") "id: $($a.id)`nfeature_id: F-W7`nmilestone_id: M-W7`n"
    $rp = Join-Path $X "tests\lam\validator-$($a.id).result.yaml"
    Write-W7File $rp "verdict: $($a.verdict)`nchecks: the WP-7 fixture's result for $($a.id)`n"
    [void]$xLedger.Append((([ordered]@{ event = 'spawn'; seq = $a.seq; validates = $a.id; round = $a.round; dispatch_id = "w7-val-$($a.seq)" }) | ConvertTo-Json -Compress) + "`n")
    [void]$xLedger.Append((([ordered]@{ event = 'complete'; seq = $a.seq; validates = $a.id; round = $a.round; tip_judged = '0123456789abcdef0123456789abcdef01234567'
                                        result_sha256 = (Get-W7Sha $rp); verdict = $a.verdict }) | ConvertTo-Json -Compress) + "`n")
}
Write-W7File (Join-Path $X '.mission-runtime\lam\spawn-ledger.jsonl') $xLedger.ToString()
$xStore = Join-Path $X '.mission\validator-results\manifest.json'
if (-not (Test-Path -LiteralPath $xStore)) { Write-W7File $xStore "{`n  `"entries`": []`n}`n" }
# THE COMMIT LEDGER the composer appends to (it creates none)
Write-W7File (Join-Path $X '.mission-runtime\lam\commit-ledger.jsonl') ''
$null = Invoke-W7Git $X @('init', '-q')
$null = Invoke-W7Git $X @('add', '-A')
$xc = Invoke-W7Git $X @('commit', '-q', '-m', 'w7 fixture: the installed framework files, the initialised mission in Executing, the stub core and the results')
$fx['x committed'] = ($xc.code -eq 0)
# THE PRE-PUSH DECIDER, installed as git's hook the way the runner installs it (its wrapper, from the library's own
# definition), and the bare origin it publishes to.
$ppScript = Join-Path $T 'pp.ps1'
Write-W7File $ppScript @'
param([string]$Root, [string]$Lib, [string]$Decider)
$ErrorActionPreference = 'Stop'
. $Lib
$hd = Get-EvidenceEffectiveHooksPath -Root $Root
if (-not (Test-Path -LiteralPath $hd)) { New-Item -ItemType Directory -Path $hd -Force | Out-Null }
[System.IO.File]::WriteAllText((Join-Path $hd 'pre-push'), (Get-EvidencePrePushWrapperText -DeciderPath $Decider), (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("INSTALLED " + (Join-Path $hd 'pre-push'))
exit 0
'@
$ppi = Invoke-W7 -File $ppScript -Argv @('-Root', $X, '-Lib', (Join-Path $hooksDir 'lib\evidence-common.ps1'), '-Decider', (Join-Path $hooksDir 'evidence-pre-push.ps1'))
$fx['x: the pre-push decider installed'] = ($ppi.code -eq 0)
$xob = Invoke-W7Git $T @('init', '--bare', '-q', $XO)
$fx['x: the bare origin'] = ($xob.code -eq 0)

$detail = ''
foreach ($k in $fx.Keys) { $detail += ("    {0,-52} {1}`n" -f $k, $fx[$k]) }
# AN INSTALLED FRAMEWORK carries neither mission.ps1 nor VERSION: they stay in the release tree (INSTALL.md section 4).
# F-0's f\ and x\ checkouts cannot be made here, so F-0 and the members that read them SKIP BY NAME, counted, never
# passed; the smoke mission's part of the fixture stands, and the members that read only it are measured.
$w7NoRelease = @(@('mission.ps1', 'VERSION') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf) })
if ($w7NoRelease.Count) {
    $w7Why = "$($w7NoRelease -join ' and ') not in this checkout (an installed framework: they stay in the release tree), so the fresh init checkouts f\ and x\ cannot be made (UI-1 S4 P-6)"
    Check -Id 'F-0' -Title 'the fixture: a built smoke mission with VANGUARD_HOME inside the per-run root, registered; a fresh init checkout' -Ok $false -Skipped `
          -Detail ($detail + "    SKIPPED BY NAME: $w7Why")
    foreach ($id in @($script:MSkipIds | Where-Object { Want $_ })) {
        Check -Id $id -Title 'a member that reads the fresh init checkouts mission.ps1 makes' -Ok $false -Skipped -Detail "    SKIPPED BY NAME: $w7Why"
    }
    $script:MSkipped = $true
} else {
Check -Id 'F-0' -Title 'the fixture: a built smoke mission with VANGUARD_HOME inside the per-run root, registered; a fresh init checkout' `
      -Ok ([bool]$fx['smoke built (build-smoke-mission exit 0)'] -and [bool]$fx['smoke registered (Register-MissionCheckout)'] -and [bool]$fx['mission init of f exit 0'] -and $hostId -and
           [bool]$fx['mission init of x exit 0'] -and [bool]$fx['x: the venv the LOM entry runs (exit 0)'] -and [bool]$fx['x committed'] -and [bool]$fx['x: the pre-push decider installed'] -and [bool]$fx['x: the bare origin']) `
      -Detail ($detail + "    (members run whatever F-0 says: a member that cannot reach its subject reads RED on its own line)")
}

$EP = Get-W7FeedPath -Root $S

# =================================================================================================
# U-1 -- the schema file
# =================================================================================================
if (Want 'U-1') { try {
    $d = ''
    $ok = $true
    $parsed = $null
    try { $parsed = [System.IO.File]::ReadAllText($schemaPath) | ConvertFrom-Json } catch { $parsed = $null }
    $d += "    $schemaPath parses: $($null -ne $parsed)`n"
    if ($null -eq $parsed) { $ok = $false }
    $em = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'docs\framework\evidence-manifest.schema.json')) | ConvertFrom-Json
    $draftOk = ($null -ne $parsed) -and ((Get-W7Has $parsed '$schema')) -and ([string]$parsed.'$schema' -ceq [string]$em.'$schema')
    $d += "    draft: $(if ($parsed) { $parsed.'$schema' }) vs evidence-manifest $($em.'$schema') -> $draftOk`n"
    if (-not $draftOk) { $ok = $false }
    # THE KIND LIST, BY GREP OF SS14's KINDS TABLE -- never a literal here.
    $es = [System.IO.File]::ReadAllLines((Join-Path $repoRoot 'docs\framework\expanded-schemas.md'))
    $kinds = @(); $inSec = $false; $inTable = $false
    foreach ($ln in $es) {
        if ($ln -match '^## 14\. Mission Event') { $inSec = $true; continue }
        if ($inSec -and $ln -match '^## ') { break }
        if ($inSec -and $ln -match '^\*\*Kinds and payloads') { $inTable = $true; continue }
        if ($inTable -and $ln -match '^\*\*') { break }
        if ($inTable -and $ln -match '^\|\s*(`[a-z_]+`(?:\s*/\s*`[a-z_]+`)*)\s*\|') {
            foreach ($km in [regex]::Matches($Matches[1], '`([a-z_]+)`')) { $kinds += $km.Groups[1].Value }
        }
    }
    $covered = @{}
    if ($parsed -and (Get-W7Has $parsed 'allOf')) {
        foreach ($blk in @($parsed.allOf)) {
            if (-not (Get-W7Has $blk 'if')) { continue }
            $kp = $null
            if ((Get-W7Has $blk.if 'properties') -and (Get-W7Has $blk.if.properties 'kind')) { $kp = $blk.if.properties.kind }
            if ($null -eq $kp) { continue }
            if (Get-W7Has $kp 'const') { $covered[[string]$kp.const] = $true }
            if (Get-W7Has $kp 'enum') { foreach ($e in @($kp.enum)) { $covered[[string]$e] = $true } }
        }
    }
    $unc = @($kinds | Where-Object { -not $covered.ContainsKey($_) })
    $d += "    kinds in SS14's table (by grep): $($kinds.Count) -- $($kinds -join ', ')`n"
    $d += "    kinds with no if/then block: $(if ($unc.Count) { $unc -join ', ' } else { '(none)' })`n"
    if ($kinds.Count -lt 10 -or $unc.Count -gt 0) { $ok = $false }
    Check -Id 'U-1' -Title "the schema file parses, declares the evidence manifest's draft, and covers every kind SS14's table names" -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-1' $_ } }

# =================================================================================================
# U-2 -- PostToolUse emits one tool_call per invocation
# =================================================================================================
if (Want 'U-2') { try {
    $sess = 'w7u2-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $before = Get-W7Feed -Root $S
    $exits = @(); $paths = @()
    foreach ($i in 1..3) {
        $fp = Join-Path $S "src\w7-u2-$i.txt"
        $paths += $fp
        $r = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Write' -ToolInput @{ file_path = $fp; content = 'x' }) -Root $S -Dispatch 'w7-u2' -VHome $H
        $exits += $r.code
    }
    $after = Get-W7Feed -Root $S
    $new = @(Get-W7Kind ($after | Select-Object -Skip $before.Count) 'tool_call' | Where-Object { $_.obj.payload.session_id -eq $sess })
    $d = "    hook exits: $($exits -join ', ')   new tool_call lines for this session: $($new.Count) (expect 3)`n"
    $ok = ($new.Count -eq 3) -and (@($exits | Where-Object { $_ -ne 0 }).Count -eq 0)
    for ($i = 0; $i -lt $new.Count; $i++) {
        $pl = $new[$i].obj.payload
        $pOk = (@($pl.paths).Count -eq 1) -and ([string]@($pl.paths)[0] -ceq $paths[$i])
        $hyg = -not ((Get-W7Has $pl 'stdout') -or (Get-W7Has $pl 'stderr') -or (Get-W7Has $pl 'command'))
        $v = Test-W7Line $new[$i]
        $d += "    [$i] paths=$(@($pl.paths) -join ';')  equal to the captured file_path: $pOk   no stdout/stderr/command key: $hyg   validates: $(-not $v) $v`n"
        if (-not ($pOk -and $hyg -and -not $v)) { $ok = $false }
    }
    Check -Id 'U-2' -Title 'PostToolUse: one tool_call per invocation; paths = the captured arguments; no stdout, stderr or command key' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-2' $_ } }

# =================================================================================================
# U-3 -- session lifecycle: session_start, session_stop + dispatch_finalized, compact
# =================================================================================================
if (Want 'U-3') { try {
    $sess = 'w7u3-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $did = 'w7-u3-' + $sess.Substring(5)
    $b0 = Get-W7Feed -Root $S
    $r1 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Read' -ToolInput @{ file_path = (Join-Path $S 'README.md') }) -Root $S -Dispatch $did -VHome $H
    $a1 = Get-W7Feed -Root $S
    $n1 = @($a1 | Select-Object -Skip $b0.Count | Where-Object { $_.obj -and (Get-W7Has $_.obj.payload 'session_id') -and $_.obj.payload.session_id -eq $sess })
    $startOk = ($n1.Count -eq 2) -and ($n1[0].obj.kind -eq 'session_start') -and ($n1[1].obj.kind -eq 'tool_call') -and ([int64]$n1[0].obj.seq -lt [int64]$n1[1].obj.seq)
    $d = "    first PostToolUse of the session: kinds $(@($n1 | ForEach-Object { $_.obj.kind }) -join ', ') (expect session_start, tool_call)  -> $startOk`n"
    # Stop
    $r2 = Invoke-W7Hook -Hook 'evidence-stop-finalize.ps1' -Payload @{ session_id = $sess; hook_event_name = 'Stop'; stop_hook_active = $false } -Root $S -Dispatch $did -VHome $H
    $a2 = Get-W7Feed -Root $S
    $n2 = @($a2 | Select-Object -Skip $a1.Count | Where-Object { $_.obj -and @('session_stop', 'dispatch_finalized') -contains $_.obj.kind })
    $man = Join-Path $S ".mission-runtime\evidence\$did\manifest.json"
    $manEc = -1
    if (Test-Path -LiteralPath $man) { try { $manEc = [int](([System.IO.File]::ReadAllText($man) | ConvertFrom-Json).entry_count) } catch { $manEc = -2 } }
    $stopOk = ($n2.Count -eq 2) -and ($n2[0].obj.kind -eq 'session_stop') -and ($n2[1].obj.kind -eq 'dispatch_finalized') -and
              ([int]$n2[0].obj.payload.entry_count -eq $manEc) -and ($n2[0].obj.payload.manifest_state -eq 'FINALIZED') -and ($n2[1].obj.payload.dispatch_id -eq $did)
    $d += "    Stop (exit $($r2.code)): kinds $(@($n2 | ForEach-Object { $_.obj.kind }) -join ', ') (expect session_stop, dispatch_finalized)`n"
    if ($n2.Count -ge 1) { $d += "      session_stop manifest_state=$($n2[0].obj.payload.manifest_state) entry_count=$($n2[0].obj.payload.entry_count); manifest on disk entry_count=$manEc -> $stopOk`n" }
    # PreCompact
    $tr = Join-Path $T 'tr.jsonl'
    Write-W7File $tr ('{"type":"user","message":"w7 transcript ' + $sess + '"}' + "`n")
    $trSha = Get-W7Sha $tr
    $r3 = Invoke-W7Hook -Hook 'evidence-pre-compact.ps1' -Payload @{ session_id = $sess; hook_event_name = 'PreCompact'; transcript_path = $tr; trigger = 'manual' } -Root $S -Dispatch $did -VHome $H
    $a3 = Get-W7Feed -Root $S
    $n3 = @(Get-W7Kind ($a3 | Select-Object -Skip $a2.Count) 'compact')
    $cOk = ($n3.Count -eq 1) -and ($n3[0].obj.payload.transcript_sha256 -ceq $trSha) -and ($n3[0].obj.payload.session_id -eq $sess)
    $d += "    PreCompact (exit $($r3.code)): compact lines $($n3.Count) (expect 1); transcript_sha256 = the transcript's sha256 ($trSha): $cOk`n"
    $vbad = @(@($n1) + @($n2) + @($n3) | ForEach-Object { Test-W7Line $_ } | Where-Object { $_ })
    $d += "    lines that do not validate: $($vbad.Count) $($vbad -join '; ')`n"
    # CONCURRENT FIRST CALLS of one new session (validator round 2, A-ANY-9): four PostToolUse processes at once
    # must say session_start ONCE, and each its own tool_call.
    $sessC = 'w7u3c-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $payC = Join-Path $T 'u3c.json'
    Write-W7File $payC ((New-W7ToolPayload -Session $sessC -Tool 'Read' -ToolInput @{ file_path = (Join-Path $S 'README.md') }) | ConvertTo-Json -Compress -Depth 8)
    $savedC = @{ C = $env:CLAUDE_PROJECT_DIR; M = $env:MISSION_DISPATCH_ID; V = $env:VANGUARD_HOME }
    $env:CLAUDE_PROJECT_DIR = $S; $env:MISSION_DISPATCH_ID = 'w7-u3c'; $env:VANGUARD_HOME = $H
    $procsC = @()
    try {
        foreach ($ci in 1..4) {
            $procsC += Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $hooksDir 'evidence-post-tool-use.ps1') + '"')) `
                                     -RedirectStandardInput $payC -RedirectStandardOutput (Join-Path $T "u3c-$ci.out") -PassThru -WindowStyle Hidden
        }
    } finally { $env:CLAUDE_PROJECT_DIR = $savedC.C; $env:MISSION_DISPATCH_ID = $savedC.M; $env:VANGUARD_HOME = $savedC.V }
    foreach ($pc in $procsC) { $null = $pc.WaitForExit(180000) }
    $aC = Get-W7Feed -Root $S
    $ssC = @($aC | Where-Object { $_.obj -and $_.obj.kind -eq 'session_start' -and $_.obj.payload.session_id -eq $sessC }).Count
    $tcC = @($aC | Where-Object { $_.obj -and $_.obj.kind -eq 'tool_call' -and $_.obj.payload.session_id -eq $sessC }).Count
    $concOk = ($ssC -eq 1) -and ($tcC -eq 4)
    $d += "    four concurrent first calls of one session: session_start $ssC (expect 1), tool_call $tcC (expect 4) -> $concOk`n"
    Check -Id 'U-3' -Title 'session lifecycle: session_start before the first tool_call; Stop adds session_stop (manifest state and count as on disk) then dispatch_finalized; PreCompact adds compact with the transcript hash' `
          -Ok ($startOk -and $stopOk -and $cOk -and $concOk -and $vbad.Count -eq 0 -and $r1.code -eq 0 -and $r2.code -eq 0 -and $r3.code -eq 0) -Detail $d
} catch { Write-W7Threw 'U-3' $_ } }

# =================================================================================================
# U-4 -- the stage verbs emit, one line each
# =================================================================================================
$ledgerContent = Join-Path $T 'lc.txt'
Write-W7File $ledgerContent 'w7: a ledger entry written by the WP-7 instrument.'
function Invoke-W7LedgerAppend { param([string]$Tag, [string]$Dispatch = 'w7-verb')
    return (Invoke-W7 -File (Join-Path $S 'tools\mission-ledger-append.ps1') -Argv @('-Id', ("w7-" + $Tag + "-" + [guid]::NewGuid().ToString('N').Substring(0, 8)), '-Type', 'lesson', '-Scope', 'framework', '-ContentFile', $ledgerContent) `
            -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = $Dispatch; CLAUDE_PROJECT_DIR = $null } -Cwd $S)
}
# THE VALIDATOR RESULT WRITER, -Write once over x\'s two bound results. U-4 reads its assertion_result lines and U-5 the
# snapshot it offers; an assertion is recorded once, so whichever member runs first drives it and the other reads it.
$script:w7Tx = $null
function Invoke-W7TranscribeOnce {
    if ($script:w7Tx) { return $script:w7Tx }
    $b = Get-W7Feed -Root $X
    $r = Invoke-W7 -File (Join-Path $X 'tools\lam\transcribe-validator-results.ps1') -Argv @('-Arc', 'w7', '-Assertion', 'A-W7-T1,A-W7-T2', '-Write', '-PythonExe', $basePy) -Env $xEnv -Cwd $X
    $a = Get-W7Feed -Root $X
    $script:w7Tx = [pscustomobject]@{ run = $r; before = $b; after = $a }
    return $script:w7Tx
}
if (Want 'U-4') { try {
    $d = ''; $ok = $true
    # (a) ledger-append -> ledger_row
    $b0 = Get-W7Feed -Root $S
    $la = Invoke-W7LedgerAppend -Tag 'u4'
    $a0 = Get-W7Feed -Root $S
    $o = Test-W7OneLine $b0 $a0 'ledger_row'
    $ledPath = Join-Path $S '.mission\ledger\entries.jsonl'
    $ledN = @([System.IO.File]::ReadAllLines($ledPath) | Where-Object { $_.Trim() }).Count
    $aOk = $o.ok -and ($la.code -eq 0) -and ([int64]$o.line.payload.entry -eq $ledN) -and ($o.line.payload.type -eq 'lesson') -and ($o.line.source_path -ceq '.mission/ledger/entries.jsonl') -and ($o.line.sha256 -ceq (Get-W7Sha $ledPath))
    $d += "    ledger-append (exit $($la.code)) -> ledger_row lines $($o.count) (expect 1); entry=$(if ($o.line) { $o.line.payload.entry }) ledger lines=$ledN; sha256 = the ledger's: $(if ($o.line) { $o.line.sha256 -ceq (Get-W7Sha $ledPath) }) -> $aOk $($o.bad -join '; ')`n"
    if (-not $aOk) { $ok = $false }
    # (b) spec-accept, then spec-bump, in f\ -> spec_bumped
    $bf = Get-W7Feed -Root $F
    $sa = Invoke-W7 -File (Join-Path $F 'tools\mission-spec-accept.ps1') -Argv @('-ProposalVersion', 'v001', '-Confirm') -Env @{ VANGUARD_HOME = $H2; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null } -Cwd $F
    $af = Get-W7Feed -Root $F
    $o = Test-W7OneLine $bf $af 'spec_bumped'
    $sOk = $o.ok -and ($sa.code -eq 0) -and ($null -eq $o.line.payload.from_version) -and ($o.line.payload.to_version -eq 'v001')
    $d += "    spec-accept v001 in f (exit $($sa.code)) -> spec_bumped lines $($o.count) (expect 1); from=$(if ($o.line) { $o.line.payload.from_version }) to=$(if ($o.line) { $o.line.payload.to_version }) -> $sOk $($o.bad -join '; ')`n"
    if (-not $sOk) { $ok = $false }
    # spec-bump needs Reworking and an operator-authored amendment; the fixture supplies both and commits them.
    $mf = Join-Path $F '.mission\mission.yaml'
    Write-W7File $mf (([System.IO.File]::ReadAllText($mf)) -replace '(?m)^state:\s*\S+', 'state: Reworking')
    Write-W7File (Join-Path $F '.mission\amendments\AM-001-w7.yaml') "id: AM-001`ntitle: w7 fixture amendment`n"
    $null = Invoke-W7Git $F @('add', '-A'); $null = Invoke-W7Git $F @('commit', '-q', '-m', 'w7 fixture: Reworking, and the amendment AM-001')
    Write-W7File (Join-Path $T 'rec.txt') "w7_record: the WP-7 fixture's spec-bump record"
    $bf = Get-W7Feed -Root $F
    $sb = Invoke-W7 -File (Join-Path $F 'tools\mission-spec-bump.ps1') -Argv @('-AmendmentId', 'AM-001', '-RecordFile', (Join-Path $T 'rec.txt'), '-LedgerContentFile', $ledgerContent) -Env @{ VANGUARD_HOME = $H2; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null } -Cwd $F
    $af = Get-W7Feed -Root $F
    $o = Test-W7OneLine $bf $af 'spec_bumped'
    $bOk = $o.ok -and ($sb.code -eq 0) -and ($o.line.payload.from_version -eq 'v001') -and ($o.line.payload.to_version -eq 'v002') -and ($o.line.payload.amendment_id -eq 'AM-001')
    $d += "    spec-bump AM-001 in f (exit $($sb.code)) -> spec_bumped lines $($o.count) (expect 1); $(if ($o.line) { "from=$($o.line.payload.from_version) to=$($o.line.payload.to_version) amendment=$($o.line.payload.amendment_id)" }) -> $bOk $($o.bad -join '; ')`n"
    if (-not $sb.code -eq 0) { $d += "      spec-bump output: $(($sb.out | Select-Object -Last 4) -join ' | ')`n" }
    if (-not $bOk) { $ok = $false }
    # (c) gates. gate_expired END TO END through `list`; mint/consume at the shared emit function (see .DESCRIPTION).
    $gd = Join-Path $S '.mission\gates'
    $head = ((Invoke-W7Git $S @('rev-parse', 'HEAD')).out -join '').Trim()
    $gExp = Join-Path $gd 'push-w7exp.yaml'
    Write-W7File $gExp ("kind: push`ngate_class: build-authorization`nid: w7exp`npush_id: push-w7exp`nauthorized_tip_sha: $head`ncreated_at: 2026-01-01T00:00:00.000Z`nexpires_at: 2026-01-01T01:00:00.000Z`nsingle_use: true`nconsumed_at: null`n")
    $b0 = Get-W7Feed -Root $S
    $l1 = Invoke-W7 -File (Join-Path $S 'tools\lam\mission-gate.ps1') -Argv @('list', '-MissionRoot', $S) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $l2 = Invoke-W7 -File (Join-Path $S 'tools\lam\mission-gate.ps1') -Argv @('list', '-MissionRoot', $S) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $a0 = Get-W7Feed -Root $S
    $o = Test-W7OneLine $b0 $a0 'gate_expired'
    $eOk = $o.ok -and ($l1.code -eq 0) -and ($l2.code -eq 0) -and ($o.line.payload.gate_id -eq 'push-w7exp') -and ($o.line.payload.kind -eq 'push') -and ($o.line.payload.tip_sha -ceq $head) -and ($o.line.source_path -ceq '.mission/gates/push-w7exp.yaml')
    $d += "    mission-gate list x2 over an open push gate past expires_at -> gate_expired lines $($o.count) (expect 1: once per gate); tip_sha=$(if ($o.line) { $o.line.payload.tip_sha }) -> $eOk $($o.bad -join '; ')`n"
    if (-not $eOk) { $ok = $false }
    # (c2) A RE-MINTED GATE OF THE SAME ID. reapprove renames the prior aside (revoked) and writes the new gate at the same
    # <kind>-<id>.yaml; past its OWN expires_at it says its own gate_expired, once -- the prior mint's marker never suppresses it.
    $gExpPrior = Join-Path $gd 'push-w7exp.revoked-1.yaml'
    Rename-Item -LiteralPath $gExp -NewName 'push-w7exp.revoked-1.yaml'
    Write-W7File $gExpPrior (([System.IO.File]::ReadAllText($gExpPrior)).TrimEnd() + "`nrevoked_at: 2026-01-02T00:00:00.000Z`nrevoked_by: w7-fixture`nrevoked_reason: `"w7: re-minted by reapprove`"`n")
    Write-W7File $gExp ("kind: push`ngate_class: build-authorization`nid: w7exp`npush_id: push-w7exp`nauthorized_tip_sha: $head`ncreated_at: 2026-01-02T00:00:00.000Z`nexpires_at: 2026-01-02T01:00:00.000Z`nsingle_use: true`nconsumed_at: null`n")
    $b0 = Get-W7Feed -Root $S
    $l3 = Invoke-W7 -File (Join-Path $S 'tools\lam\mission-gate.ps1') -Argv @('list', '-MissionRoot', $S) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $l4 = Invoke-W7 -File (Join-Path $S 'tools\lam\mission-gate.ps1') -Argv @('list', '-MissionRoot', $S) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $a0 = Get-W7Feed -Root $S
    $o = Test-W7OneLine $b0 $a0 'gate_expired'
    $rmOk = $o.ok -and ($l3.code -eq 0) -and ($l4.code -eq 0) -and ($o.line.payload.gate_id -eq 'push-w7exp') -and ($o.line.payload.expires_at -eq '2026-01-02T01:00:00.000Z') -and ($o.line.sha256 -ceq (Get-W7Sha $gExp))
    $d += "    the same id re-minted (the prior renamed aside, revoked; a new push-w7exp.yaml past its own expires_at), list x2 -> gate_expired lines $($o.count) (expect 1: the re-mint's own) -> $rmOk $($o.bad -join '; ')`n"
    if (-not $rmOk) { $ok = $false }
    # (c3) CONCURRENT OBSERVERS OF ONE EXPIRY SAY IT ONCE (validator round 2's observation): four processes, released together,
    # each running the emit function `list` calls over the same expired gate.
    $gExc = Join-Path $gd 'push-w7exc.yaml'
    Write-W7File $gExc ("kind: push`ngate_class: build-authorization`nid: w7exc`npush_id: push-w7exc`nauthorized_tip_sha: $head`ncreated_at: 2026-01-03T00:00:00.000Z`nexpires_at: 2026-01-03T01:00:00.000Z`nsingle_use: true`nconsumed_at: null`n")
    $expApp = Join-Path $T 'expc.ps1'
    Write-W7File $expApp @'
param([string]$Root, [string]$Lib, [string]$Gate, [string]$Go)
. $Lib
while (-not (Test-Path -LiteralPath $Go)) { Start-Sleep -Milliseconds 10 }
$null = Write-MissionGateEvent -Root $Root -Kind 'gate_expired' -GatePath $Gate -Hook 'mission-gate'
'@
    $goE = Join-Path $T 'goe'
    $sLib = Join-Path $S 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1'
    $b0 = Get-W7Feed -Root $S
    $savedE = $env:VANGUARD_HOME; $env:VANGUARD_HOME = $H
    $procsE = @()
    try {
        foreach ($ei in 1..4) {
            $procsE += Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$expApp`"", '-Root', "`"$S`"", '-Lib', "`"$sLib`"", '-Gate', "`"$gExc`"", '-Go', "`"$goE`"") -PassThru -WindowStyle Hidden
        }
    } finally { $env:VANGUARD_HOME = $savedE }
    Start-Sleep -Seconds 5
    Write-W7File $goE 'go'
    foreach ($pe in $procsE) { $null = $pe.WaitForExit(180000) }
    $a0 = Get-W7Feed -Root $S
    $nExc = @(Get-W7Kind ($a0 | Select-Object -Skip $b0.Count) 'gate_expired' | Where-Object { $_.obj.payload.gate_id -eq 'push-w7exc' }).Count
    $excOk = ($nExc -eq 1)
    $d += "    four concurrent observers of one expired gate (push-w7exc), released together -> gate_expired lines $nExc (expect 1: the marker is claimed) -> $excOk`n"
    if (-not $excOk) { $ok = $false }
    # (c4) A CLAIM THE FOLDER REFUSES IS NOT A CLAIM LOST (validator round 3's A-ANY-1): with the telemetry folder not writable,
    # `list` over an expired gate writes no line and leaves ONE hook-errors.log entry naming the append; restored, it says it once.
    $gExr = Join-Path $gd 'push-w7exr.yaml'
    Write-W7File $gExr ("kind: push`ngate_class: build-authorization`nid: w7exr`npush_id: push-w7exr`nauthorized_tip_sha: $head`ncreated_at: 2026-01-04T00:00:00.000Z`nexpires_at: 2026-01-04T01:00:00.000Z`nsingle_use: true`nconsumed_at: null`n")
    $tdirR = Join-Path $S '.mission-runtime\telemetry'
    $errR0 = Get-W7ErrCount -Root $S -Dispatch 'w7-exr'
    $b0 = Get-W7Feed -Root $S
    $aclR = Get-Acl -LiteralPath $tdirR
    $meR = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $ruleR = New-Object System.Security.AccessControl.FileSystemAccessRule($meR, ([System.Security.AccessControl.FileSystemRights]'WriteData, AppendData, CreateDirectories, WriteAttributes, WriteExtendedAttributes, Delete'),
                ([System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'), [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Deny)
    $aclR.AddAccessRule($ruleR); Set-Acl -LiteralPath $tdirR -AclObject $aclR
    try {
        $lR = Invoke-W7 -File (Join-Path $S 'tools\lam\mission-gate.ps1') -Argv @('list', '-MissionRoot', $S) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-exr'; CLAUDE_PROJECT_DIR = $null }
    } finally {
        $aclR = Get-Acl -LiteralPath $tdirR
        foreach ($ru in @($aclR.Access | Where-Object { $_.AccessControlType -eq 'Deny' -and -not $_.IsInherited })) { [void]$aclR.RemoveAccessRule($ru) }
        Set-Acl -LiteralPath $tdirR -AclObject $aclR
    }
    $a0 = Get-W7Feed -Root $S
    $nR = @(Get-W7Kind ($a0 | Select-Object -Skip $b0.Count) 'gate_expired' | Where-Object { $_.obj.payload.gate_id -eq 'push-w7exr' }).Count
    $errR1 = Get-W7ErrCount -Root $S -Dispatch 'w7-exr'
    $lR2 = Invoke-W7 -File (Join-Path $S 'tools\lam\mission-gate.ps1') -Argv @('list', '-MissionRoot', $S) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-exr'; CLAUDE_PROJECT_DIR = $null }
    $a1 = Get-W7Feed -Root $S
    $nR2 = @(Get-W7Kind ($a1 | Select-Object -Skip $a0.Count) 'gate_expired' | Where-Object { $_.obj.payload.gate_id -eq 'push-w7exr' }).Count
    $exrOk = ($lR.code -eq 0) -and ($nR -eq 0) -and (($errR1 - $errR0) -eq 1) -and ($lR2.code -eq 0) -and ($nR2 -eq 1)
    $d += "    list over an expired gate (push-w7exr) with the telemetry folder not writable (exit $($lR.code)): gate_expired lines $nR (expect 0), hook-errors entries naming the append +$($errR1 - $errR0) (expect +1); restored, list (exit $($lR2.code)): $nR2 (expect 1) -> $exrOk`n"
    if (-not $exrOk) { $ok = $false }
    $gMint = Join-Path $gd 'push-w7mint.yaml'
    Write-W7File $gMint ("kind: push`ngate_class: build-authorization`nid: w7mint`npush_id: push-w7mint`nauthorized_tip_sha: $head`ncreated_at: 2026-11-01T00:00:00.000Z`nexpires_at: 2099-01-01T00:00:00.000Z`nsingle_use: true`nconsumed_at: null`n")
    $haltDir = Join-Path $S '.mission-runtime\halts'
    $haltFile = Join-Path $haltDir 'HALT-W7-01.md'
    Write-W7File $haltFile "# HALT-W7-01`n`n**Severity:** high`n`nThe WP-7 instrument's HALT.`n"
    $fnScript = Join-Path $T 'fn.ps1'
    Write-W7File $fnScript @'
param([string]$Root, [string]$Lib, [string]$Kind, [string]$Path, [string]$Resolution)
$ErrorActionPreference = 'Stop'
. $Lib
if ($Kind -like 'gate_*') { $ok = Write-MissionGateEvent -Root $Root -Kind $Kind -GatePath $Path -Hook 'mission-gate' }
else { $ok = Write-MissionHaltEvent -Root $Root -Kind $Kind -HaltPath $Path -Resolution $Resolution -Hook 'mission-gate' }
Write-Output "EMITTED $ok"
exit 0
'@
    $lib = Join-Path $S 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1'
    $b0 = Get-W7Feed -Root $S
    $m1 = Invoke-W7 -File $fnScript -Argv @('-Root', $S, '-Lib', $lib, '-Kind', 'gate_minted', '-Path', $gMint) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $a0 = Get-W7Feed -Root $S
    $o = Test-W7OneLine $b0 $a0 'gate_minted'
    $mOk = $o.ok -and ($o.line.payload.gate_id -eq 'push-w7mint') -and ($o.line.payload.tip_sha -ceq $head) -and ($o.line.payload.expires_at -eq '2099-01-01T00:00:00.000Z')
    # the consumed stamp, as the push hook's Complete-EvidencePushGate and settle write it
    Write-W7File $gMint (([System.IO.File]::ReadAllText($gMint)) -replace 'consumed_at: null', 'consumed_at: 2026-11-02T00:00:00.000Z')
    $b1 = Get-W7Feed -Root $S
    $m2 = Invoke-W7 -File $fnScript -Argv @('-Root', $S, '-Lib', $lib, '-Kind', 'gate_consumed', '-Path', $gMint) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $a1 = Get-W7Feed -Root $S
    $o2 = Test-W7OneLine $b1 $a1 'gate_consumed'
    $cOk = $o2.ok -and ($o2.line.payload.consumed_at -eq '2026-11-02T00:00:00.000Z') -and ($o2.line.payload.tip_sha -ceq $head)
    $d += "    Write-MissionGateEvent gate_minted over a push gate -> lines $($o.count), tip_sha on it: $mOk;  gate_consumed -> lines $($o2.count), consumed_at + tip_sha: $cOk`n"
    if (-not ($mOk -and $cOk)) { $ok = $false }
    # (d) HALT: halt_raised END TO END through PostToolUse (a write of a HALT file); halt_resolved at the function
    $sessH = 'w7u4h-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $b0 = Get-W7Feed -Root $S
    $hr = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sessH -Tool 'Write' -ToolInput @{ file_path = $haltFile; content = 'x' }) -Root $S -Dispatch 'w7-u4h' -VHome $H
    $a0 = Get-W7Feed -Root $S
    $o = Test-W7OneLine $b0 $a0 'halt_raised'
    $hOk = $o.ok -and ($hr.code -eq 0) -and ($o.line.payload.halt_id -eq 'HALT-W7-01') -and ($o.line.payload.severity -eq 'high')
    $b1 = Get-W7Feed -Root $S
    $hv = Invoke-W7 -File $fnScript -Argv @('-Root', $S, '-Lib', $lib, '-Kind', 'halt_resolved', '-Path', $haltFile, '-Resolution', 'ANSWERED') -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null }
    $a1 = Get-W7Feed -Root $S
    $o2 = Test-W7OneLine $b1 $a1 'halt_resolved'
    $rOk = $o2.ok -and ($o2.line.payload.halt_id -eq 'HALT-W7-01') -and ($o2.line.payload.resolution -eq 'ANSWERED')
    $d += "    a Write of HALT-W7-01.md through PostToolUse -> halt_raised lines $($o.count) severity=$(if ($o.line) { $o.line.payload.severity }) -> $hOk;  Write-MissionHaltEvent halt_resolved ANSWERED -> $rOk`n"
    if (-not ($hOk -and $rOk)) { $ok = $false }
    # the verbs' own calls, read from their code (the write paths an agent session cannot reach)
    $mg = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'tools\lam\mission-gate.ps1'))
    $pt = [System.IO.File]::ReadAllText((Join-Path $hooksDir 'evidence-post-tool-use.ps1'))
    $structural = [ordered]@{
        'mission-gate approve/reapprove: gate_minted after WriteAllBytes($p'   = [regex]::IsMatch($mg, '(?s)WriteAllBytes\(\$p, \$newArtifactBytes\).{0,4000}?gate_minted')
        'mission-gate halt-ruling mint: halt_resolved ANSWERED'                  = [regex]::IsMatch($mg, "(?s)gate_minted.{0,1500}?halt_resolved.{0,400}?ANSWERED")
        'mission-gate settle: gate_consumed (push and governance branches)'      = ([regex]::Matches($mg, "Kind 'gate_consumed'").Count -ge 2)
        'mission-gate list: gate_expired'                                         = [regex]::IsMatch($mg, "(?s)'list' \{.{0,4000}?gate_expired")
        'post-tool-use: gate_consumed when Complete-EvidencePushGate consumed'   = [regex]::IsMatch($pt, '(?s)if \(\$r\.consumed\) \{.{0,600}?gate_consumed')
    }
    foreach ($k in $structural.Keys) { $d += ("      read: {0,-70} {1}`n" -f $k, $structural[$k]); if (-not $structural[$k]) { $ok = $false } }
    # (e) mission verify -> verify_result + tip_observed (cached)
    $anch = Join-Path $S '.mission\dispatches\D-1.anchors.yaml'
    $b0 = Get-W7Feed -Root $S
    $vr = Invoke-W7 -File (Join-Path $S 'tools\mission-verify.ps1') -Argv @('--against', $anch) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null } -Cwd $S
    $a0 = Get-W7Feed -Root $S
    $o = Test-W7OneLine $b0 $a0 'verify_result'
    $o2 = Test-W7OneLine $b0 $a0 'tip_observed'
    $vOk = $o.ok -and $o2.ok -and (@(0, 1) -contains $vr.code) -and (@('PASS', 'REFUSE') -contains [string]$o.line.payload.verdict) -and
           ($o2.line.payload.cached -eq $true) -and ($o2.line.payload.local_tip -ceq ((Invoke-W7Git $S @('rev-parse', 'HEAD')).out -join '').Trim())
    $d += "    mission verify --against D-1.anchors.yaml (exit $($vr.code)) -> verify_result $($o.count), tip_observed $($o2.count) (expect 1 each)$(if ($o.line) { "; verdict=$($o.line.payload.verdict) arms=$(@($o.line.payload.arms_run).Count) divergences=$($o.line.payload.divergences)" })$(if ($o2.line) { "; local_tip ok, cached=$($o2.line.payload.cached) ahead=$($o2.line.payload.ahead) behind=$($o2.line.payload.behind)" }) -> $vOk $($o.bad -join '; ') $($o2.bad -join '; ')`n"
    if (-not $vOk) { $ok = $false }
    # (f) THE LOM DISPATCH ENTRY, tools\mission-dispatch.ps1 -> dispatch_opened (x\'s stub core; see .DESCRIPTION). -AssertionTargets
    # omitted, so the targets are the core's and are read off the brief it wrote.
    $bx = Get-W7Feed -Root $X
    $dpo = Invoke-W7 -File (Join-Path $X 'tools\mission-dispatch.ps1') -Argv @('-FeatureId', 'F-W7', '-MilestoneId', 'M-W7') -Env ($xEnv + @{ W7_CORE_MODE = 'open' }) -Cwd $X
    $ax = Get-W7Feed -Root $X
    $o = Test-W7OneLine $bx $ax 'dispatch_opened'
    $dId = ''; $dm = [regex]::Match(($dpo.out -join "`n"), '"dispatch_id":\s*"([0-9a-f-]{36})"'); if ($dm.Success) { $dId = $dm.Groups[1].Value }
    # WHEN: the stub core waits, while it runs, to see its own dispatch_opened -- a line said only when the core returned
    # is never seen by it. WHAT: the targets are the brief's list alone, not the operator note's bullet of the same shape.
    $dSeen = @($dpo.out | Where-Object { $_ -match 'dispatch_opened seen while the core ran: True' }).Count -eq 1
    $dOk = $o.ok -and ($dpo.code -eq 0) -and $dId -and $dSeen -and ($o.line.payload.dispatch_id -eq $dId) -and ($o.line.payload.kind -eq 'fanout') -and ($o.line.payload.feature -eq 'F-W7') -and
           ((@($o.line.payload.assertion_targets) -join ',') -ceq 'A-W7-T1,A-W7-T2') -and ($o.line.source_path -ceq ".mission/dispatches/$dId/task-brief.md")
    $d += "    tools\mission-dispatch.ps1 (exit $($dpo.code); the core's DispatchResult on its stdout: $([bool]$dId)) -> dispatch_opened lines $($o.count) (expect 1); said while the core still ran (the core saw it): $dSeen$(if ($o.line) { "; kind=$($o.line.payload.kind) feature=$($o.line.payload.feature) targets=$(@($o.line.payload.assertion_targets) -join ',') (expect A-W7-T1,A-W7-T2: not the note's bullet) source=$($o.line.source_path)" }) -> $dOk $($o.bad -join '; ')`n"
    $bx = Get-W7Feed -Root $X
    $dpc = Invoke-W7 -File (Join-Path $X 'tools\mission-dispatch.ps1') -Argv @('-FeatureId', 'F-W7', '-MilestoneId', 'M-W7') -Env ($xEnv + @{ W7_CORE_MODE = 'crash' }) -Cwd $X
    $ax = Get-W7Feed -Root $X
    $oCr = Test-W7OneLine $bx $ax 'dispatch_opened'
    $crOk = $oCr.ok -and ($dpc.code -ne 0) -and ($dpc.code -ne $null) -and (Test-Path -LiteralPath (Join-Path $X (($oCr.line.source_path) -replace '/', '\')))
    $d += "    a core that writes its brief and then dies uncaught (exit $($dpc.code), expect non-zero) -> dispatch_opened lines $($oCr.count) (expect 1: it opened) -> $crOk $($oCr.bad -join '; ')`n"
    $bx = Get-W7Feed -Root $X
    $dpd = Invoke-W7 -File (Join-Path $X 'tools\mission-dispatch.ps1') -Argv @('-FeatureId', 'F-W7', '-MilestoneId', 'M-W7', '-DryRun') -Env ($xEnv + @{ W7_CORE_MODE = 'open' }) -Cwd $X
    $dpr = Invoke-W7 -File (Join-Path $X 'tools\mission-dispatch.ps1') -Argv @('-FeatureId', 'F-W7', '-MilestoneId', 'M-W7') -Env ($xEnv + @{ W7_CORE_MODE = 'refused' }) -Cwd $X
    $ax = Get-W7Feed -Root $X
    $dNone = @(Get-W7Kind ($ax | Select-Object -Skip $bx.Count) 'dispatch_opened').Count
    $dnOk = ($dNone -eq 0) -and ($dpd.code -eq 0) -and ($dpr.code -eq 2)
    $d += "    a dry run (exit $($dpd.code)) and a dispatch the core refused before its brief (exit $($dpr.code), expect the core's 2) -> dispatch_opened lines $dNone (expect 0) -> $dnOk`n"
    # THE ENTRY'S OUTPUT STILL REACHES A POWERSHELL CALLER (validator round 2's A-ANY-1): `$o = & <entry>` captures the core's
    # DispatchResult, as it did before the feed -- and the line is still said while the core runs.
    $capApp = Join-Path $T 'capdisp.ps1'
    Write-W7File $capApp @'
param([string]$Entry)
$o = @(& $Entry -FeatureId 'F-W7' -MilestoneId 'M-W7' 2>$null)
$all = (@($o) | ForEach-Object { "$_" }) -join "`n"
Write-Output ("CAPTURED " + @($o).Count + " RESULT " + ($all -match '"dispatch_id"') + " SEEN " + ($all -match 'seen while the core ran: True'))
'@
    $cp = Invoke-W7 -File $capApp -Argv @('-Entry', (Join-Path $X 'tools\mission-dispatch.ps1')) -Env ($xEnv + @{ W7_CORE_MODE = 'open' }) -Cwd $X
    $capLine = [string](@($cp.out | Where-Object { $_ -match '^CAPTURED ' }) | Select-Object -Last 1)
    $capOk = $capLine -match 'RESULT True SEEN True$'
    $d += "    an in-process caller, `$o = & tools\mission-dispatch.ps1 ...: $capLine (expect the DispatchResult captured, and the line seen while the core ran) -> $capOk`n"
    if (-not ($dOk -and $crOk -and $dnOk -and $capOk)) { $ok = $false }
    # (g) THE VALIDATOR RESULT WRITER, transcribe-validator-results -Write -> one assertion_result per recorded assertion, read off the record
    $tx = Invoke-W7TranscribeOnce
    $newA = @(Get-W7Kind ($tx.after | Select-Object -Skip $tx.before.Count) 'assertion_result')
    $badA = @($newA | ForEach-Object { Test-W7Line $_ } | Where-Object { $_ })
    $t1 = @($newA | Where-Object { $_.obj.payload.assertion_id -eq 'A-W7-T1' }); $t2 = @($newA | Where-Object { $_.obj.payload.assertion_id -eq 'A-W7-T2' })
    $rec1 = Join-Path $X '.mission\validator-results\A-W7-T1.validator-result.json'
    $gOk = ($tx.run.code -eq 0) -and ($newA.Count -eq 2) -and ($badA.Count -eq 0) -and ($t1.Count -eq 1) -and ($t2.Count -eq 1) -and
           ($t1[0].obj.payload.result -eq 'green') -and ([int]$t1[0].obj.payload.round -eq 1) -and ($t1[0].obj.payload.feature -eq 'F-W7') -and ($t1[0].obj.payload.validator_kind -eq 'narrow') -and
           ($t1[0].obj.source_path -ceq '.mission/validator-results/A-W7-T1.validator-result.json') -and ($t1[0].obj.sha256 -ceq (Get-W7Sha $rec1)) -and
           ($t2[0].obj.payload.result -eq 'red') -and ([int]$t2[0].obj.payload.round -eq 2) -and ($t2[0].obj.payload.feature -eq 'F-W7')
    $d += "    transcribe-validator-results -Write A-W7-T1,A-W7-T2 (exit $($tx.run.code)) -> assertion_result lines $($newA.Count) (expect 2)$(if ($t1.Count) { "; A-W7-T1 $($t1[0].obj.payload.result) round $($t1[0].obj.payload.round) $($t1[0].obj.payload.validator_kind) feature $($t1[0].obj.payload.feature)" })$(if ($t2.Count) { "; A-W7-T2 $($t2[0].obj.payload.result) round $($t2[0].obj.payload.round)" }) -> $gOk $($badA -join '; ')`n"
    if (-not $gOk) { $ok = $false; $d += "      transcribe output (tail): $(($tx.run.out | Select-Object -Last 4) -join ' | ')`n" }
    # (h) THE COMMIT-LEDGER COMPOSER, tools\lam\commit_ledger.py append -> ledger_row, through emit-mission-event.ps1 (the one writer)
    $clp = Join-Path $X '.mission-runtime\lam\commit-ledger.jsonl'
    $clLine = Join-Path $T 'cl.json'
    Write-W7File $clLine '{"by":"the WP-7 fixture","attested_by":"the WP-7 instrument","note":"a commit line composed by WP-7 U-4"}'
    $xHead = ((Invoke-W7Git $X @('rev-parse', 'HEAD')).out -join '').Trim()
    $bx = Get-W7Feed -Root $X
    $cl = Invoke-W7Native -Exe $basePy -Argv @((Join-Path $X 'tools\lam\commit_ledger.py'), 'append', '--sha', $xHead, '--line-file', $clLine) -Env $xEnv -Cwd $X
    $ax = Get-W7Feed -Root $X
    $o = Test-W7OneLine $bx $ax 'ledger_row'
    $clSaid = @($cl.out | Where-Object { $_ -match '^APPENDED line 1 to ' })
    $cOk = $o.ok -and ($cl.code -eq 0) -and (@($cl.out).Count -eq 1) -and ($clSaid.Count -eq 1) -and ([int64]$o.line.payload.entry -eq 1) -and (Get-W7Has $o.line.payload 'row') -and
           ($null -eq $o.line.payload.row) -and ($o.line.payload.type -eq 'commit') -and ($o.line.source_path -ceq '.mission-runtime/lam/commit-ledger.jsonl') -and ($o.line.sha256 -ceq (Get-W7Sha $clp))
    $d += "    commit_ledger.py append (exit $($cl.code); its output one APPENDED line: $(@($cl.out).Count -eq 1 -and $clSaid.Count -eq 1)) -> ledger_row lines $($o.count) (expect 1)$(if ($o.line) { "; entry=$($o.line.payload.entry) row=$(if ($null -eq $o.line.payload.row) { 'null' } else { $o.line.payload.row }) type=$($o.line.payload.type)" }) -> $cOk $($o.bad -join '; ')`n"
    if (-not $cOk) { $ok = $false; $d += "      composer output: $($cl.out -join ' | ')`n" }
    # (i) THE PUSH HOOK, END TO END -> gate_consumed then tip_observed: a push gate binding (the bare origin, refs/heads/w7tip,
    # HEAD); a real `git push`, which runs the pre-push decider (authorizes, writes the in-flight witness); then PostToolUse,
    # whose settle asks the origin what it holds, consumes the gate, and says both lines.
    $xoU = $XO -replace '\\', '/'
    $gTip = Join-Path $X '.mission\gates\push-w7tip.yaml'
    Write-W7File $gTip ("kind: push`ngate_class: build-authorization`nid: w7tip`npush_id: push-w7tip`nauthorized_tip_sha: $xHead`norigin_url: $xoU`nremote_ref: refs/heads/w7tip`ncreated_at: 2026-11-01T00:00:00.000Z`nexpires_at: 2099-01-01T00:00:00.000Z`nsingle_use: true`nconsumed_at: null`n")
    $pu = Invoke-W7Git $X @('push', $xoU, 'HEAD:refs/heads/w7tip')
    $flight = Test-Path -LiteralPath (Join-Path $X '.mission\gates\.push-inflight.json')
    $sessP = 'w7u4p-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $bx = Get-W7Feed -Root $X
    $pp = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sessP -Tool 'Bash' -ToolInput @{ command = "git push $xoU HEAD:refs/heads/w7tip"; description = 'w7' }) -Root $X -Dispatch 'w7-u4p' -VHome $H2
    $ax = Get-W7Feed -Root $X
    $oc = Test-W7OneLine $bx $ax 'gate_consumed'
    $ot = Test-W7OneLine $bx $ax 'tip_observed'
    $tl = $ot.line
    $pOk = ($pu.code -eq 0) -and $flight -and ($pp.code -eq 0) -and $oc.ok -and $ot.ok -and ($oc.line.payload.gate_id -eq 'push-w7tip') -and ([int64]$oc.line.seq -lt [int64]$tl.seq) -and
           ($tl.payload.origin_tip -ceq $xHead) -and ($tl.payload.local_tip -ceq $xHead) -and ($tl.payload.cached -eq $false) -and ($null -ne $tl.payload.ahead) -and ([int]$tl.payload.ahead -eq 0) -and
           ($null -ne $tl.payload.behind) -and ([int]$tl.payload.behind -eq 0) -and ($tl.payload.ref -ceq 'refs/heads/w7tip') -and ($tl.source_path -ceq '.mission/gates/push-w7tip.yaml')
    $d += "    git push to the bare origin (exit $($pu.code); the decider's in-flight witness written: $flight), then PostToolUse (exit $($pp.code)) -> gate_consumed $($oc.count), tip_observed $($ot.count) (expect 1 each, in that order)$(if ($tl) { "; origin_tip=HEAD $($tl.payload.origin_tip -ceq $xHead) local_tip=HEAD $($tl.payload.local_tip -ceq $xHead) ahead=$($tl.payload.ahead) behind=$($tl.payload.behind) cached=$($tl.payload.cached) ref=$($tl.payload.ref)" }) -> $pOk $($oc.bad -join '; ') $($ot.bad -join '; ')`n"
    if (-not $pOk) { $ok = $false; $d += "      git push output: $(($pu.out | Select-Object -Last 6) -join ' | ')`n" }
    Check -Id 'U-4' -Title 'the stage verbs emit one line each: ledger_row (ledger-append, commit_ledger.py), spec_bumped (accept and bump), gate_expired (re-mint too)/minted/consumed (tip_sha on push gates), halt_raised/resolved, verify_result + tip_observed (verify, push hook), dispatch_opened (LOM entry), assertion_result' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-4' $_ } }

# =================================================================================================
# U-5 -- mission_snapshot on change only, from one writer in tools/lam
# =================================================================================================
if (Want 'U-5') { try {
    $d = ''
    $b0 = Get-W7Feed -Root $S
    $r1 = Invoke-W7LedgerAppend -Tag 'u5a'
    $a1 = Get-W7Feed -Root $S
    $n1 = @(Get-W7Kind ($a1 | Select-Object -Skip $b0.Count) 'mission_snapshot').Count
    $r2 = Invoke-W7LedgerAppend -Tag 'u5b'
    $a2 = Get-W7Feed -Root $S
    $n2 = @(Get-W7Kind ($a2 | Select-Object -Skip $a1.Count) 'mission_snapshot').Count
    # change derived state: the current milestone, committed (the verbs refuse a dirty tree)
    $mf = Join-Path $S '.mission\mission.yaml'
    $mt = [System.IO.File]::ReadAllText($mf)
    $newMs = 'M-W7-' + [guid]::NewGuid().ToString('N').Substring(0, 4)
    Write-W7File $mf ($mt -replace '(?m)^current_milestone:.*$', "current_milestone: $newMs")
    $null = Invoke-W7Git $S @('add', '--', '.mission/mission.yaml'); $null = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: a new current milestone')
    $r3 = Invoke-W7LedgerAppend -Tag 'u5c'
    $a3 = Get-W7Feed -Root $S
    $s3 = @(Get-W7Kind ($a3 | Select-Object -Skip $a2.Count) 'mission_snapshot')
    $r4 = Invoke-W7LedgerAppend -Tag 'u5d'
    $a4 = Get-W7Feed -Root $S
    $n4 = @(Get-W7Kind ($a4 | Select-Object -Skip $a3.Count) 'mission_snapshot').Count
    $allSnap = @(Get-W7Kind $a4 'mission_snapshot')
    $prevSha = if ($allSnap.Count -ge 2) { $allSnap[-2].obj.payload.snapshot_sha256 } else { '' }
    $chgOk = ($s3.Count -eq 1) -and ($s3[0].obj.payload.current_milestone -eq $newMs) -and ($s3[0].obj.payload.snapshot_sha256 -cne $prevSha) -and -not (Test-W7Line $s3[0])
    $d += "    ledger-append #1: $n1 snapshot(s) (0 or 1: the first ever, or a change since the last)`n"
    $d += "    ledger-append #2, nothing changed: $n2 (expect 0)`n"
    $d += "    current_milestone -> $newMs, ledger-append #3: $($s3.Count) (expect 1, carrying $newMs, a new snapshot_sha256) -> $chgOk`n"
    $d += "    ledger-append #4, nothing changed: $n4 (expect 0)`n"
    $d += "    verb exits: $($r1.code) $($r2.code) $($r3.code) $($r4.code)`n"
    # A STAGE VERB THAT ITSELF MOVES THE STATE: design-start, Created -> Planning, over a fresh install of its own.
    $FD = Join-Path $T 'fd'
    New-Item -ItemType Directory -Path $FD -Force | Out-Null
    $iD = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $FD) -Env @{ VANGUARD_HOME = $H2 }
    $null = Copy-W7Framework -Dest $FD
    Write-W7File (Join-Path $FD '.mission\inputs\INDEX.md') "# Inputs`n`n- brief.md`n"
    Write-W7File (Join-Path $FD '.mission\inputs\brief.md') "w7: the fixture's one input.`n"
    $null = Invoke-W7Git $FD @('init', '-q'); $null = Invoke-W7Git $FD @('config', 'user.name', 'w7-fixture'); $null = Invoke-W7Git $FD @('config', 'user.email', 'w7-fixture@example.invalid')
    $null = Invoke-W7Git $FD @('add', '-A'); $null = Invoke-W7Git $FD @('commit', '-q', '-m', 'w7 fixture: a fresh install with one input')
    $bD = Get-W7Feed -Root $FD
    $ds = Invoke-W7 -File (Join-Path $FD 'tools\mission-design-start.ps1') -Env @{ VANGUARD_HOME = $H2; MISSION_DISPATCH_ID = 'w7-verb'; CLAUDE_PROJECT_DIR = $null } -Cwd $FD
    $aD = Get-W7Feed -Root $FD
    $sD = @(Get-W7Kind ($aD | Select-Object -Skip $bD.Count) 'mission_snapshot')
    $dsOk = ($iD.code -eq 0) -and ($ds.code -eq 0) -and ($sD.Count -eq 1) -and ($sD[0].obj.payload.state -eq 'Planning') -and -not (Test-W7Line $sD[0])
    $d += "    design-start over a fresh install (exit $($ds.code)), Created -> Planning: $($sD.Count) snapshot(s) (expect 1, state Planning$(if ($sD.Count) { '; it says ' + $sD[0].obj.payload.state })) -> $dsOk`n"
    # CONCURRENT SNAPSHOT OFFERS after ONE state change (validator round 2, A-ANY-10): three processes at once
    # must write ONE snapshot -- the on-change comparison is made under the emitter's lock.
    $mt2 = [System.IO.File]::ReadAllText($mf)
    $newMs2 = 'M-W7C-' + [guid]::NewGuid().ToString('N').Substring(0, 4)
    Write-W7File $mf ($mt2 -replace '(?m)^current_milestone:.*$', "current_milestone: $newMs2")
    $null = Invoke-W7Git $S @('add', '--', '.mission/mission.yaml'); $null = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: another milestone')
    $snapApp = Join-Path $T 'snap.ps1'
    Write-W7File $snapApp @'
param([string]$Root, [string]$Tm, [string]$Go)
. $Tm
while (-not (Test-Path -LiteralPath $Go)) { Start-Sleep -Milliseconds 20 }
Invoke-MissionTelemetry -Root $Root -Snapshot -Verb 'w7-concurrent'
'@
    $goS = Join-Path $T 'gos'
    $b5 = Get-W7Feed -Root $S
    $savedS = $env:VANGUARD_HOME; $env:VANGUARD_HOME = $H
    $procsS = @()
    try {
        foreach ($si in 1..3) {
            $procsS += Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$snapApp`"", '-Root', "`"$S`"", '-Tm', ('"' + (Join-Path $S 'tools\lam\mission-telemetry.ps1') + '"'), '-Go', "`"$goS`"") -PassThru -WindowStyle Hidden
        }
    } finally { $env:VANGUARD_HOME = $savedS }
    Start-Sleep -Seconds 4
    Write-W7File $goS 'go'
    foreach ($ps5 in $procsS) { $null = $ps5.WaitForExit(180000) }
    $a5 = Get-W7Feed -Root $S
    $s5 = @(Get-W7Kind ($a5 | Select-Object -Skip $b5.Count) 'mission_snapshot')
    $concSnapOk = ($s5.Count -eq 1) -and ($s5[0].obj.payload.current_milestone -eq $newMs2)
    $d += "    three concurrent snapshot offers after one change (current_milestone -> $newMs2): $($s5.Count) snapshot(s) (expect 1) -> $concSnapOk`n"
    # A VERB'S OWN TELEMETRY FUNCTION, RUN AS IT STANDS IN THE VERB. revoke is admitted only through the operator console and
    # the LAM runner's close only at the end of a real dispatch (see .DESCRIPTION), so the function each calls after its
    # write is lifted out of the verb file by the PowerShell parser -- its text unchanged except $PSScriptRoot, which is
    # pointed at the fixture's tools\lam (where the verb's sibling mission-telemetry.ps1 lives) -- and run with the verb's
    # $MissionRoot; and the verb is READ for the call after its write.
    $fnCall = Join-Path $T 'fncall.ps1'
    Write-W7File $fnCall @'
param([string]$Verb, [string]$Function, [string]$ScriptRoot, [string]$Root, [switch]$Snapshot)
$ErrorActionPreference = 'Stop'
$MissionRoot = $Root
$tk = $null; $er = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Verb, [ref]$tk, [ref]$er)
$fd = $ast.Find({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -eq $Function) }, $true)
if (-not $fd) { Write-Output "NO-FUNCTION $Function"; exit 4 }
. ([scriptblock]::Create($fd.Extent.Text.Replace('$PSScriptRoot', ("'" + $ScriptRoot.Replace("'", "''") + "'"))))
if ($Snapshot) { & $Function -Snapshot } else { & $Function }
Write-Output "CALLED $Function"
exit 0
'@
    $sLam = Join-Path $S 'tools\lam'
    $mgVerb = Join-Path $repoRoot 'tools\lam\mission-gate.ps1'
    $rnVerb = Join-Path $repoRoot 'tools\lam\mission-dispatch.ps1'
    $revokeOffer = { Invoke-W7 -File $fnCall -Argv @('-Verb', $mgVerb, '-Function', 'Send-LamGateTelemetry', '-ScriptRoot', $sLam, '-Root', $S, '-Snapshot') -Env @{ VANGUARD_HOME = $H } }
    $closeOffer  = { Invoke-W7 -File $fnCall -Argv @('-Verb', $rnVerb, '-Function', 'Send-LamDispatchSnapshot', '-ScriptRoot', $sLam, '-Root', $S) -Env @{ VANGUARD_HOME = $H } }
    # REVOKE (validator round 4's A-U5): revoking a halt-ruling gate reopens its HALT.
    Write-W7File (Join-Path $S '.mission-runtime\halts\HALT-W7-02.md') "# HALT-W7-02`n`n**Severity:** low`n`nThe WP-7 instrument's second HALT, answered by a halt-ruling gate.`n"
    $hg = Join-Path $S '.mission\gates\halt-ruling-HALT-W7-02.yaml'
    Write-W7File $hg "kind: halt-ruling`nid: HALT-W7-02`nbinds: .mission-runtime/halts/HALT-W7-02.md`ncreated_at: 2026-11-01T00:00:00.000Z`n"
    $null = Invoke-W7Git $S @('add', '--', '.mission/gates/halt-ruling-HALT-W7-02.yaml'); $null = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: a halt-ruling gate answering HALT-W7-02')
    $null = & $revokeOffer   # the feed's snapshot brought up to this state
    $lastSnap = @(Get-W7Kind (Get-W7Feed -Root $S) 'mission_snapshot') | Select-Object -Last 1
    $openBefore = if ($lastSnap) { [int]$lastSnap.obj.payload.counts.open_halts } else { -1 }
    Write-W7File $hg (([System.IO.File]::ReadAllText($hg)).TrimEnd() + "`nrevoked_at: 2026-11-02T00:00:00.000Z`nrevoked_by: w7-fixture`nrevoked_reason: `"w7: revoked by the WP-7 instrument`"`n")
    $bR = Get-W7Feed -Root $S
    $rv1 = & $revokeOffer
    $aR = Get-W7Feed -Root $S
    $sR = @(Get-W7Kind ($aR | Select-Object -Skip $bR.Count) 'mission_snapshot')
    $null = & $revokeOffer
    $aR2 = Get-W7Feed -Root $S
    $nR2 = @(Get-W7Kind ($aR2 | Select-Object -Skip $aR.Count) 'mission_snapshot').Count
    $null = Invoke-W7Git $S @('add', '--', '.mission/gates/halt-ruling-HALT-W7-02.yaml'); $null = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: the halt-ruling gate revoked')
    $mgText = [System.IO.File]::ReadAllText($mgVerb)
    # inside the revoke block (never past where settle's begins), after revoke's one write
    $revokeRead = [regex]::IsMatch($mgText, "(?s)'revoke' \{(?:(?!'settle' \{).)*?WriteAllBytes\(\`$p, \`$resultBytes\)(?:(?!'settle' \{).)*?Send-LamGateTelemetry -Snapshot")
    $rvCalled = @($rv1.out | Where-Object { $_ -eq 'CALLED Send-LamGateTelemetry' }).Count -eq 1
    $rvOk = $rvCalled -and ($openBefore -ge 0) -and ($sR.Count -eq 1) -and ([int]$sR[0].obj.payload.counts.open_halts -eq ($openBefore + 1)) -and -not (Test-W7Line $sR[0]) -and ($nR2 -eq 0) -and $revokeRead
    $d += "    revoke's stamp on a halt-ruling gate, then revoke's own Send-LamGateTelemetry -Snapshot (lifted from mission-gate.ps1: $rvCalled): $($sR.Count) snapshot(s) (expect 1)$(if ($sR.Count) { "; open_halts $openBefore -> $($sR[0].obj.payload.counts.open_halts) (expect +1)" }); the offer again, nothing changed: $nR2 (expect 0)`n"
    $d += "      read: mission-gate revoke offers the snapshot (Send-LamGateTelemetry -Snapshot) after its WriteAllBytes: $revokeRead -> $rvOk`n"
    # THE LAM RUNNER'S CLOSE (validator round 2's U-5): a handoff beside <id>.yaml closes the dispatch -- the snapshot counts
    # it open no longer. The runner's own Send-LamDispatchSnapshot is run after the handoff lands, and the runner is READ for
    # that call once the handoff is settled (worker-written or placed) and again after a rejection record is written.
    $dR = Join-Path $S '.mission\dispatches\D-W7R.yaml'
    Write-W7File $dR "id: D-W7R`nmission_id: $smokeMissionId`nkind: mainline`nfeature_id: F-W7`nassertion_targets: [A-W7]`n"
    $null = Invoke-W7Git $S @('add', '--', '.mission/dispatches/D-W7R.yaml'); $null = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: a dispatch D-W7R, open')
    $null = & $closeOffer   # the feed's snapshot brought up to this state (D-W7R open)
    $lastSnap = @(Get-W7Kind (Get-W7Feed -Root $S) 'mission_snapshot') | Select-Object -Last 1
    $openD0 = if ($lastSnap) { [int]$lastSnap.obj.payload.counts.open_dispatches } else { -1 }
    Write-W7File (Join-Path $S '.mission\dispatches\D-W7R.handoff.yaml') "id: handoff-w7r`ndispatch_id: D-W7R`nterminated_reason: completed`n"
    $bC = Get-W7Feed -Root $S
    $cl1 = & $closeOffer
    $aC = Get-W7Feed -Root $S
    $sC = @(Get-W7Kind ($aC | Select-Object -Skip $bC.Count) 'mission_snapshot')
    $null = & $closeOffer
    $aC2 = Get-W7Feed -Root $S
    $nC2 = @(Get-W7Kind ($aC2 | Select-Object -Skip $aC.Count) 'mission_snapshot').Count
    $null = Invoke-W7Git $S @('add', '--', '.mission/dispatches/D-W7R.handoff.yaml'); $null = Invoke-W7Git $S @('commit', '-q', '-m', 'w7 fixture: D-W7R handed off')
    $rnText = [System.IO.File]::ReadAllText($rnVerb)
    $closeReads = [ordered]@{
        'the function offers the snapshot (Invoke-MissionTelemetry -Snapshot)' = [regex]::IsMatch($rnText, '(?s)function Send-LamDispatchSnapshot \{.{0,700}?Invoke-MissionTelemetry -Root \$MissionRoot -Snapshot')
        'called once the handoff is settled, after the placement'              = [regex]::IsMatch($rnText, '(?s)Copy-Item -LiteralPath \$wtHandoffPath -Destination \$handoffPath.{0,6000}?\n[ \t]*Send-LamDispatchSnapshot[ \t]*\r?\n(?:[ \t]*\r?\n)*[ \t]*\$handoffProblems = @\(\)')
        'called after the rejection record, before exit 3'                     = [regex]::IsMatch($rnText, '(?s)WriteAllText\(\$handoffPath, \$body, [^\r\n]*\r?\n.{0,300}?Send-LamDispatchSnapshot.{0,600}?exit 3')
    }
    $clCalled = @($cl1.out | Where-Object { $_ -eq 'CALLED Send-LamDispatchSnapshot' }).Count -eq 1
    $clOk = $clCalled -and ($openD0 -ge 1) -and ($sC.Count -eq 1) -and ([int]$sC[0].obj.payload.counts.open_dispatches -eq ($openD0 - 1)) -and -not (Test-W7Line $sC[0]) -and ($nC2 -eq 0) -and (@($closeReads.Values | Where-Object { -not $_ }).Count -eq 0)
    $d += "    D-W7R's handoff lands, then the runner's own Send-LamDispatchSnapshot (lifted from lam\mission-dispatch.ps1: $clCalled): $($sC.Count) snapshot(s) (expect 1)$(if ($sC.Count) { "; open_dispatches $openD0 -> $($sC[0].obj.payload.counts.open_dispatches) (expect -1)" }); the offer again, nothing changed: $nC2 (expect 0)`n"
    foreach ($k in $closeReads.Keys) { $d += ("      read: the LAM runner -- {0}: {1}`n" -f $k, $closeReads[$k]) }
    $d += "      -> $clOk`n"
    # THE VALIDATOR RESULT WRITER (validator round 4's A-U5): a -Write that landed moves assertion status, so it offers the
    # snapshot; the same verb with nothing to change -- a check-only run, and a -Write the store refuses -- says nothing.
    $tx = Invoke-W7TranscribeOnce
    $sT = @(Get-W7Kind ($tx.after | Select-Object -Skip $tx.before.Count) 'mission_snapshot')
    $bT = Get-W7Feed -Root $X
    $tc1 = Invoke-W7 -File (Join-Path $X 'tools\lam\transcribe-validator-results.ps1') -Argv @('-Arc', 'w7', '-Assertion', 'A-W7-T1,A-W7-T2', '-PythonExe', $basePy) -Env $xEnv -Cwd $X
    $tc2 = Invoke-W7 -File (Join-Path $X 'tools\lam\transcribe-validator-results.ps1') -Argv @('-Arc', 'w7', '-Assertion', 'A-W7-T1,A-W7-T2', '-Write', '-PythonExe', $basePy) -Env $xEnv -Cwd $X
    $aT = Get-W7Feed -Root $X
    $nT = @($aT | Select-Object -Skip $bT.Count | Where-Object { $_.obj -and @('mission_snapshot', 'assertion_result') -contains $_.obj.kind }).Count
    $txOk = ($tx.run.code -eq 0) -and ($sT.Count -eq 1) -and ($sT[0].obj.payload.assertions.'A-W7-T1' -eq 'green') -and ($sT[0].obj.payload.assertions.'A-W7-T2' -eq 'red') -and -not (Test-W7Line $sT[0]) -and
            ($tc1.code -eq 0) -and ($tc2.code -ne 0) -and ($nT -eq 0)
    $d += "    transcribe-validator-results -Write (exit $($tx.run.code)): $($sT.Count) snapshot(s) (expect 1$(if ($sT.Count) { "; A-W7-T1 $($sT[0].obj.payload.assertions.'A-W7-T1'), A-W7-T2 $($sT[0].obj.payload.assertions.'A-W7-T2')" }))`n"
    $d += "      then check-only (exit $($tc1.code)) and a -Write the store refuses (exit $($tc2.code), expect non-zero): snapshot or assertion_result lines $nT (expect 0) -> $txOk`n"
    # THE ONLY WRITER, BY GREP: 'mission_snapshot' as code appears in exactly one tools file, in tools/lam/.
    # tools\ui\ (UI-1 S2) is the feed's READ-ONLY consumer (ADR-045) and names the kind to read it: its files are
    # read here as readers instead -- none calls the feed's writer or opens any file for writing (its tests\, which
    # write their own per-test homes, aside).
    $writers = @(); $readers = @(); $readerWrites = @()
    foreach ($fi in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tools') -Recurse -File -Include '*.ps1', '*.psm1', '*.py' -ErrorAction SilentlyContinue)) {
        if ($fi.FullName -match '\\(\.venv|__pycache__)\\') { continue }
        $rel = $fi.FullName.Substring($repoRoot.Length).TrimStart('\')
        $txt = [System.IO.File]::ReadAllText($fi.FullName)
        if ($rel -match '^tools\\ui\\' -and $rel -notmatch '^tools\\ui\\tests\\') {
            if ($txt -match 'mission_snapshot') { $readers += $rel }
            if ($txt -match "Write-MissionEvent|Invoke-MissionTelemetry|open\([^)]*,\s*[`"'][wax]b?\+?[`"']|\.write_(text|bytes)\(") { $readerWrites += $rel }
            continue
        }
        if ($rel -match '^tools\\ui\\tests\\') { continue }
        if ($txt -match 'mission_snapshot') { $writers += $rel }
    }
    $fnDefs = @()
    foreach ($wr in $writers) { if ([System.IO.File]::ReadAllText((Join-Path $repoRoot $wr)) -match '(?m)^function Write-MissionSnapshot\b') { $fnDefs += $wr } }
    $grepOk = ($writers.Count -eq 1) -and ($writers[0] -match '^tools\\lam\\') -and ($fnDefs.Count -eq 1) -and ($readerWrites.Count -eq 0)
    $d += "    files under tools\ naming mission_snapshot: $(if ($writers.Count) { $writers -join ', ' } else { '(none)' }) (expect exactly one, in tools\lam\, defining Write-MissionSnapshot)`n"
    $d += "      the read-only consumer tools\ui\ names it in $(if ($readers.Count) { $readers -join ', ' } else { '(none)' }); of its files, writing: $(if ($readerWrites.Count) { $readerWrites -join ', ' } else { '(none)' }) (expect none) -> $grepOk`n"
    Check -Id 'U-5' -Title 'mission_snapshot: emitted by a stage-level verb when the derived state changed (ledger-append, design-start, revoke, transcribe -Write, the LAM runner close), never when it did not; one writer, in tools/lam' `
          -Ok (($n1 -le 1) -and ($n2 -eq 0) -and $chgOk -and ($n4 -eq 0) -and $dsOk -and $concSnapOk -and $rvOk -and $clOk -and $txOk -and $grepOk -and (@($r1.code, $r2.code, $r3.code, $r4.code) -notcontains 1)) -Detail $d
} catch { Write-W7Threw 'U-5' $_ } }

# =================================================================================================
# U-6 / U-7 / U-8 -- never blocks
# =================================================================================================
function Invoke-W7NeverBlocks {
    param([string]$Id, [scriptblock]$Break, [scriptblock]$Restore, [string]$What)
    $sess = ('w7' + $Id.Replace('-', '').ToLower() + '-') + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $did = 'w7-' + $Id.ToLower()
    $pay = { param($n) New-W7ToolPayload -Session $sess -Tool 'Edit' -ToolInput @{ file_path = (Join-Path $S "src\w7-$n.txt") } }
    $p0 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (& $pay 0) -Root $S -Dispatch $did -VHome $H   # starts the session
    $lastSeq = Get-W7LastSeq -Root $S
    $eSha0 = Get-W7Sha $EP
    $err0 = Get-W7ErrCount -Root $S -Dispatch $did
    $verr0 = Get-W7ErrCount -Root $S -Dispatch ($did + 'v')
    $brk = & $Break
    $p1 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (& $pay 1) -Root $S -Dispatch $did -VHome $H
    $vb = Invoke-W7LedgerAppend -Tag ($Id.ToLower()) -Dispatch ($did + 'v')
    $dirExists = Test-Path -LiteralPath (Join-Path $S '.mission-runtime\telemetry')
    $err1 = Get-W7ErrCount -Root $S -Dispatch $did
    $verr1 = Get-W7ErrCount -Root $S -Dispatch ($did + 'v')
    & $Restore $brk
    # E is hashed once it is back where it lives (U-7 takes the folder away), before anything appends again.
    $eSha1 = Get-W7Sha $EP
    $p2 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (& $pay 2) -Root $S -Dispatch $did -VHome $H
    $f2 = Get-W7Feed -Root $S
    $next = @($f2 | Where-Object { $_.obj -and $_.obj.kind -eq 'tool_call' -and $_.obj.payload.session_id -eq $sess }) | Select-Object -Last 1
    $nextSeq = if ($next) { [int64]$next.obj.seq } else { -1 }
    $r = [pscustomobject]@{
        hookExit = $p1.code; verbExit = $vb.code; unchanged = ($eSha0 -eq $eSha1); errDelta = ($err1 - $err0); verbErrDelta = ($verr1 - $verr0)
        nextSeq = $nextSeq; lastSeq = $lastSeq; dirExists = $dirExists; breakNote = $brk
        startOk = ($p0.code -eq 0) -and ($lastSeq -gt 0)
    }
    $r | Add-Member -NotePropertyName ok -NotePropertyValue ($r.startOk -and $r.hookExit -eq 0 -and $r.verbExit -eq 0 -and $r.unchanged -and $r.errDelta -eq 1 -and $r.verbErrDelta -ge 1 -and $r.nextSeq -eq ($r.lastSeq + 1))
    return $r
}
function Format-W7NeverBlocks { param($r)
    return ("    before: the session started and E's last seq is $($r.lastSeq) ($($r.startOk))`n" +
            "    broken ($($r.breakNote)): tool call exit $($r.hookExit) (expect 0); verb exit $($r.verbExit) (expect 0); E unchanged $($r.unchanged) (expect True)`n" +
            "    hook-errors.log entries naming the append: tool call +$($r.errDelta) (expect +1); verb +$($r.verbErrDelta) (expect >= 1)`n" +
            "    restored: the next tool_call's seq $($r.nextSeq) (expect $($r.lastSeq + 1), no gap)`n")
}
if (Want 'U-6') { try {
    $tdir = Join-Path $S '.mission-runtime\telemetry'
    $r = Invoke-W7NeverBlocks -Id 'U-6' -Break {
        $acl = Get-Acl -LiteralPath $tdir
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($me, ([System.Security.AccessControl.FileSystemRights]'WriteData, AppendData, CreateDirectories, WriteAttributes, WriteExtendedAttributes, Delete'),
                    ([System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'), [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Deny)
        $acl.AddAccessRule($rule); Set-Acl -LiteralPath $tdir -AclObject $acl
        return 'a Deny write/append ACE for the current user on the telemetry folder, inherited by E'
    } -Restore {
        param($n)
        $acl = Get-Acl -LiteralPath $tdir
        foreach ($ru in @($acl.Access | Where-Object { $_.AccessControlType -eq 'Deny' -and -not $_.IsInherited })) { [void]$acl.RemoveAccessRule($ru) }
        Set-Acl -LiteralPath $tdir -AclObject $acl
    }
    Check -Id 'U-6' -Title 'never blocks, folder read-only: exit 0 for the call and the verb, no line, one hook-errors entry naming the append, seq continues with no gap' -Ok $r.ok -Detail (Format-W7NeverBlocks $r)
} catch { Write-W7Threw 'U-6' $_ } }
if (Want 'U-7') { try {
    $tdir = Join-Path $S '.mission-runtime\telemetry'
    $away = Join-Path $S '.mission-runtime\telemetry-w7away'
    $r = Invoke-W7NeverBlocks -Id 'U-7' -Break {
        Rename-Item -LiteralPath $tdir -NewName 'telemetry-w7away'
        return 'the telemetry folder taken away between appends (renamed aside, so its E can come back and seq can be read on)'
    } -Restore { param($n) Rename-Item -LiteralPath $away -NewName 'telemetry' }
    $d = (Format-W7NeverBlocks $r) + "    the emitter created no directory while it was missing: $(-not $r.dirExists) (expect True)`n"
    Check -Id 'U-7' -Title 'never blocks, folder missing: the same four outcomes, and the emitter creates no directory' -Ok ($r.ok -and -not $r.dirExists) -Detail $d
} catch { Write-W7Threw 'U-7' $_ } }
if (Want 'U-8') { try {
    $d = ''
    $sess = 'w7u8-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $p0 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Edit' -ToolInput @{ file_path = (Join-Path $S 'src\w7-u8.txt') }) -Root $S -Dispatch 'w7-u8' -VHome $H
    $eSha0 = Get-W7Sha $EP
    $err0 = Get-W7ErrCount -Root $S -Dispatch 'w7-u8'
    $timer = Join-Path $T 'timer.ps1'
    Write-W7File $timer @'
param([string]$Root, [string]$Lib)
. $Lib
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$ok = Write-MissionEvent -Root $Root -Kind 'tool_call' -Payload ([ordered]@{ tool = 'Edit'; exit_code = $null; paths = @(); session_id = 'w7u8-timer'; dispatch_id = 'w7-u8' }) -SourcePath '.mission/mission.yaml' -Hook 'PostToolUse' -DispatchId 'w7-u8'
$sw.Stop()
Write-Output ("ELAPSED_MS " + $sw.ElapsedMilliseconds + " RESULT " + $ok)
exit 0
'@
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($EP, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $p1 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Edit' -ToolInput @{ file_path = (Join-Path $S 'src\w7-u8b.txt') }) -Root $S -Dispatch 'w7-u8' -VHome $H
        $tm = Invoke-W7 -File $timer -Argv @('-Root', $S, '-Lib', (Join-Path $hooksDir 'lib\evidence-common.ps1')) -Env @{ VANGUARD_HOME = $H; MISSION_DISPATCH_ID = 'w7-u8'; CLAUDE_PROJECT_DIR = $S }
    } catch { $p1 = [pscustomobject]@{ code = -1; out = @("could not hold E: $($_.Exception.Message)") }; $tm = [pscustomobject]@{ out = @(); code = -1 } }
    finally { if ($fs) { $fs.Dispose() } }
    $el = -1; $res = ''
    $tl = @($tm.out | Where-Object { $_ -match '^ELAPSED_MS (\d+) RESULT (\S+)' }) | Select-Object -Last 1
    if ($tl -and ($tl -match '^ELAPSED_MS (\d+) RESULT (\S+)')) { $el = [int]$Matches[1]; $res = $Matches[2] }
    $eSha1 = Get-W7Sha $EP
    $err1 = Get-W7ErrCount -Root $S -Dispatch 'w7-u8'
    $bytes = [System.IO.File]::ReadAllBytes($EP)
    $endsLf = ($bytes.Length -gt 0) -and ($bytes[$bytes.Length - 1] -eq 10)
    $ok = ($p0.code -eq 0) -and ($p1.code -eq 0) -and ($el -ge 0) -and ($el -le 1500) -and ($res -eq 'False') -and ($eSha0 -eq $eSha1) -and (($err1 - $err0) -eq 2) -and $endsLf
    $d += "    E held open with FileShare.None by this process:`n"
    $d += "      tool call exit $($p1.code) (expect 0); Write-MissionEvent returned $res in $el ms (expect False, within 500 ms + 1000 ms slack)`n"
    $d += "      E unchanged: $($eSha0 -eq $eSha1); hook-errors.log entries naming the append: +$($err1 - $err0) (expect +2: the call's and the timed one's)`n"
    $d += "    E ends with LF: $endsLf (never a partial line)`n"
    Check -Id 'U-8' -Title 'never blocks, file locked: returns within the 500 ms bound, exit 0, no line, a hook-errors entry, never a partial line' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-8' $_ } }

# =================================================================================================
# U-9 -- concurrency
# =================================================================================================
if (Want 'U-9') { try {
    $N = 25
    $app = Join-Path $T 'app.ps1'
    Write-W7File $app @'
param([string]$Root, [string]$Lib, [int]$N, [string]$Tag, [string]$Go)
. $Lib
while (-not (Test-Path -LiteralPath $Go)) { Start-Sleep -Milliseconds 20 }
$okN = 0
for ($i = 1; $i -le $N; $i++) {
    if (Write-MissionEvent -Root $Root -Kind 'tool_call' -Payload ([ordered]@{ tool = ('w7-' + $Tag); exit_code = $null; paths = @(); session_id = ('w7u9-' + $Tag); dispatch_id = 'w7-u9' }) -SourcePath '.mission/mission.yaml' -Hook 'PostToolUse' -DispatchId 'w7-u9') { $okN++ }
}
Write-Output "APPENDED $okN"
'@
    $go = Join-Path $T 'go'
    $lastSeq = Get-W7LastSeq -Root $S
    $saved = @{ V = $env:VANGUARD_HOME; C = $env:CLAUDE_PROJECT_DIR }
    $env:VANGUARD_HOME = $H; $env:CLAUDE_PROJECT_DIR = $S
    $libP = Join-Path $hooksDir 'lib\evidence-common.ps1'
    $pa = Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$app`"", '-Root', "`"$S`"", '-Lib', "`"$libP`"", '-N', $N, '-Tag', 'A', '-Go', "`"$go`"") -PassThru -WindowStyle Hidden
    $pb = Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$app`"", '-Root', "`"$S`"", '-Lib', "`"$libP`"", '-N', $N, '-Tag', 'B', '-Go', "`"$go`"") -PassThru -WindowStyle Hidden
    $env:VANGUARD_HOME = $saved.V; $env:CLAUDE_PROJECT_DIR = $saved.C
    Start-Sleep -Seconds 4
    Write-W7File $go 'go'
    $null = $pa.WaitForExit(240000); $null = $pb.WaitForExit(240000)
    $feed9 = Get-W7Feed -Root $S
    $mine = @($feed9 | Where-Object { $_.obj -and $_.obj.kind -eq 'tool_call' -and @('w7u9-A', 'w7u9-B') -contains [string]$_.obj.payload.session_id })
    $seqs = @($mine | ForEach-Object { [int64]$_.obj.seq } | Sort-Object)
    $expect = @(($lastSeq + 1)..($lastSeq + 2 * $N))
    $contig = ($seqs.Count -eq 2 * $N) -and ((Compare-Object $seqs $expect -SyncWindow 0).Count -eq 0)
    $allSeq = @($feed9 | Where-Object { $_.obj } | ForEach-Object { [int64]$_.obj.seq })
    $dups = $allSeq.Count - @($allSeq | Sort-Object -Unique).Count
    $bad = @($mine | ForEach-Object { Test-W7Line $_ } | Where-Object { $_ })
    $d = "    two processes x $N appends to one E at once: $($mine.Count) lines (expect $(2 * $N))`n"
    $d += "    their seqs are $($lastSeq + 1)..$($lastSeq + 2 * $N) with no gap: $contig; duplicate seqs anywhere in E: $dups (expect 0); lines that do not validate: $($bad.Count)`n"
    Check -Id 'U-9' -Title 'concurrency: 2N lines, seq 1..2N over the window with no gap and no duplicate, every line validates' -Ok ($contig -and $dups -eq 0 -and $bad.Count -eq 0) -Detail $d
} catch { Write-W7Threw 'U-9' $_ } }

# =================================================================================================
# U-10 -- a worktree writes its own stream
# =================================================================================================
if (Want 'U-10') { try {
    $wt = Invoke-W7Git $S @('worktree', 'add', '--detach', $W, 'HEAD')
    $pSha0 = Get-W7Sha $EP
    # A WORKTREE IS ITS OWN STREAM (ADR-045: the stream identity is the registry entry (host, checkout path)), and
    # git never brings the ignored telemetry folder along. Unregistered it writes NOTHING -- no feed, and no
    # hook-errors line on the feed's account; registered by the product's step (mission.ps1 register; the LAM
    # runner calls the same Register-MissionWorktree for the worktrees it cuts) it writes its own E from seq 1.
    $sess0 = 'w7u10a-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $r0 = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess0 -Tool 'Edit' -ToolInput @{ file_path = (Join-Path $W 'README.md') }) -Root $W -Dispatch 'w7-u10' -VHome $H
    $unregSilent = ($r0.code -eq 0) -and -not (Test-Path -LiteralPath (Join-Path $W '.mission-runtime\telemetry')) -and ((Get-W7ErrCount -Root $W -Dispatch 'w7-u10') -eq 0)
    $rgW = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('register', '-Target', $W) -Env @{ VANGUARD_HOME = $H }
    $wRow = @(Get-W7Rows -VHome $H | Where-Object { $_.checkout_path -eq $W }).Count
    $sess = 'w7u10-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $r = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Edit' -ToolInput @{ file_path = (Join-Path $W 'README.md') }) -Root $W -Dispatch 'w7-u10' -VHome $H
    $wf = Get-W7Feed -Root $W
    $pSha1 = Get-W7Sha $EP
    $first = if ($wf.Count) { $wf[0].obj } else { $null }
    $mineW = @($wf | Where-Object { $_.obj -and $_.obj.kind -eq 'tool_call' -and $_.obj.payload.session_id -eq $sess })
    $ok = ($wt.code -eq 0) -and $unregSilent -and ($rgW.code -eq 0) -and ($wRow -eq 1) -and ($r.code -eq 0) -and ($null -ne $first) -and ([int64]$first.seq -eq 1) -and
          ($mineW.Count -eq 1) -and ($first.mission_id -eq $smokeMissionId) -and ($first.host_id -eq $hostId) -and ($pSha0 -eq $pSha1)
    $d = "    git worktree add (exit $($wt.code)); before registration a hook call (exit $($r0.code)) wrote no feed, made no folder and no hook-errors line: $unregSilent`n"
    $d += "    mission.ps1 register -Target <worktree> (exit $($rgW.code)): its own registry row: $wRow (expect 1); then a hook call (exit $($r.code)) -> its tool_call in the worktree's E: $($mineW.Count) (expect 1)`n"
    $d += "    the worktree's E: $($wf.Count) line(s); first seq $(if ($first) { $first.seq }) (expect 1); mission_id $(if ($first) { $first.mission_id }) (expect $smokeMissionId); host_id equal: $(if ($first) { $first.host_id -eq $hostId })`n"
    $d += "    the primary's E unchanged: $($pSha0 -eq $pSha1)`n"
    Check -Id 'U-10' -Title "a worktree checkout writes its own E from seq 1, with the primary's mission_id and host_id; the primary's E is unchanged" -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-10' $_ } }

# =================================================================================================
# U-11 -- payload hygiene
# =================================================================================================
if (Want 'U-11') { try {
    $sent = 'W7SENTINEL' + [guid]::NewGuid().ToString('N')
    $sess = 'w7u11-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $b0 = Get-W7Feed -Root $S
    $r = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Bash' -ToolInput @{ command = "echo $sent"; description = 'w7' } -ToolResponse @{ stdout = "$sent out"; stderr = "$sent err"; interrupted = $false }) -Root $S -Dispatch 'w7-u11' -VHome $H
    $a0 = Get-W7Feed -Root $S
    $new = @(Get-W7Kind ($a0 | Select-Object -Skip $b0.Count) 'tool_call' | Where-Object { $_.obj.payload.session_id -eq $sess })
    $raw = if (Test-Path -LiteralPath $EP) { [System.IO.File]::ReadAllText($EP) } else { '' }
    $hit = $raw.Contains($sent)
    $ok = ($r.code -eq 0) -and ($new.Count -eq 1) -and (-not $hit)
    $d = "    a Bash call whose command, stdout and stderr carry a sentinel: hook exit $($r.code); tool_call lines $($new.Count) (expect 1); the sentinel appears in E: $hit (expect False)`n"
    Check -Id 'U-11' -Title 'payload hygiene: a sentinel in the command and the output appears nowhere in E' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-11' $_ } }

# =================================================================================================
# U-12 -- commit null when git is absent
# =================================================================================================
if (Want 'U-12') { try {
    $sess = 'w7u12-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $noGitPath = (Join-Path $env:SystemRoot 'System32') + ';' + $PSHOME
    $b0 = Get-W7Feed -Root $S
    $r = Invoke-W7Hook -Hook 'evidence-post-tool-use.ps1' -Payload (New-W7ToolPayload -Session $sess -Tool 'Edit' -ToolInput @{ file_path = (Join-Path $S 'README.md') }) -Root $S -Dispatch 'w7-u12' -VHome $H -ExtraEnv @{ PATH = $noGitPath }
    $a0 = Get-W7Feed -Root $S
    $new = @(Get-W7Kind ($a0 | Select-Object -Skip $b0.Count) 'tool_call' | Where-Object { $_.obj.payload.session_id -eq $sess })
    $gitThere = $false
    $sv = $env:PATH; try { $env:PATH = $noGitPath; $gitThere = [bool](Get-Command git -ErrorAction SilentlyContinue) } finally { $env:PATH = $sv }
    $ok = (-not $gitThere) -and ($r.code -eq 0) -and ($new.Count -eq 1) -and ($null -eq $new[0].obj.commit) -and (Get-W7Has $new[0].obj 'commit') -and -not (Test-W7Line $new[0])
    $d = "    PATH without git (git resolvable there: $gitThere, expect False); hook exit $($r.code); tool_call lines $($new.Count) (expect 1); commit = $(if ($new.Count) { if ($null -eq $new[0].obj.commit) { 'null' } else { $new[0].obj.commit } }) (expect null)`n"
    Check -Id 'U-12' -Title 'commit is null when git is absent from PATH, and the line is still written' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-12' $_ } }

# =================================================================================================
# U-13 / U-14 / U-15 -- host_id, the registry, the ignore rule (the fresh init checkout f\, home h2\)
# =================================================================================================
$h2Id = if ($h2After) { ([System.Text.Encoding]::UTF8.GetString($h2Bytes1)).Trim() } else { '' }
if (Want 'U-13') { try {
    $F2 = Join-Path $T 'f2'
    New-Item -ItemType Directory -Path $F2 -Force | Out-Null
    $i2 = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $F2) -Env @{ VANGUARD_HOME = $H2 }
    $bytes2 = if (Test-Path -LiteralPath (Join-Path $H2 'host-id')) { [System.IO.File]::ReadAllBytes((Join-Path $H2 'host-id')) } else { [byte[]]@() }
    $same = ($h2Bytes1.Length -gt 0) -and ([Convert]::ToBase64String($h2Bytes1) -eq [Convert]::ToBase64String($bytes2))
    $isUuid = $h2Id -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    $notHost = ($h2Id -ne $env:COMPUTERNAME) -and ($h2Id -ne [System.Net.Dns]::GetHostName()) -and ($h2Id -ne $env:USERNAME)
    $ok = (-not $h2Before) -and $h2After -and $isUuid -and $same -and $notHost -and ($i2.code -eq 0)
    $d = "    home h2 had no host-id before the first mission init: $(-not $h2Before); after it: $h2After`n"
    $d += "    host-id '$h2Id' is a lowercase UUID: $isUuid; a second init (of f2, exit $($i2.code)) left it byte-identical: $same; it is neither the hostname nor the user name: $notHost`n"
    Check -Id 'U-13' -Title 'host_id: mission init mints <VANGUARD_HOME>/host-id as a UUID once; a second run leaves it byte-identical; it is not the hostname or user name' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-13' $_ } }
if (Want 'U-14') { try {
    $d = ''
    $rows0 = @(Get-W7Rows -VHome $H2)
    $fId = ''
    if (Test-Path -LiteralPath (Join-Path $F '.mission\mission.yaml')) { $mm = [regex]::Match([System.IO.File]::ReadAllText((Join-Path $F '.mission\mission.yaml')), '(?m)^id:\s*(\S+)'); if ($mm.Success) { $fId = $mm.Groups[1].Value } }
    $fRows = @($rows0 | Where-Object { $_.checkout_path -eq $F })
    $ver = ([System.IO.File]::ReadAllText((Join-Path $repoRoot 'VERSION'))).Trim()
    $shapeOk = ($fRows.Count -eq 1) -and ($fRows[0].host_id -eq $h2Id) -and ($fRows[0].mission_id -eq $fId) -and ($fRows[0].framework_version -eq $ver) -and ([string]$fRows[0].registered_at -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d{3})?Z$')
    $d += "    rows for f after its init: $($fRows.Count) (expect 1); host_id, mission_id ($fId), framework_version ($ver), registered_at as declared: $shapeOk`n"
    # the same checkout again: init refuses before writing, and the function init calls adds no row
    $i3 = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $F) -Env @{ VANGUARD_HOME = $H2 }
    $rg2 = Invoke-W7 -File $regScript -Argv @('-Root', $F, '-Lib', (Join-Path $repoRoot 'tools\lam\mission-telemetry.ps1')) -Env @{ VANGUARD_HOME = $H2 }
    $rows1 = @(Get-W7Rows -VHome $H2)
    $noDup = (@($rows1 | Where-Object { $_.checkout_path -eq $F }).Count -eq 1) -and ($rows1.Count -eq $rows0.Count)
    $d += "    a second init of f (exit $($i3.code)) and Register-MissionCheckout of f again (exit $($rg2.code)): rows for f $(@($rows1 | Where-Object { $_.checkout_path -eq $F }).Count), total $($rows1.Count) (was $($rows0.Count)) -> no row added: $noDup`n"
    # a row whose path is gone is left in place
    $Fg = Join-Path $T 'fg'
    New-Item -ItemType Directory -Path $Fg -Force | Out-Null
    $ig = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $Fg) -Env @{ VANGUARD_HOME = $H2 }
    Remove-Item -LiteralPath $Fg -Recurse -Force
    $Fh = Join-Path $T 'fh'
    New-Item -ItemType Directory -Path $Fh -Force | Out-Null
    $ih = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $Fh) -Env @{ VANGUARD_HOME = $H2 }
    $rows2 = @(Get-W7Rows -VHome $H2)
    $kept = (@($rows2 | Where-Object { $_.checkout_path -eq $Fg }).Count -eq 1) -and (@($rows2 | Where-Object { $_.checkout_path -eq $Fh }).Count -eq 1)
    $d += "    init of fg (exit $($ig.code)), fg deleted, init of fh (exit $($ih.code)): fg's row still present and fh's added: $kept`n"
    Check -Id 'U-14' -Title 'registry: mission init appends one {host_id, checkout_path, mission_id, registered_at, framework_version} row; none for a registered checkout; rows are never pruned' -Ok ($shapeOk -and $noDup -and $kept) -Detail $d
} catch { Write-W7Threw 'U-14' $_ } }
if (Want 'U-15') { try {
    # ITS OWN FRESH INSTALL, untouched by any verb: f\ has run spec-bump by now, and spec-bump leaves its commit
    # message file .mission-runtime/commit-msg-*.txt behind -- a porcelain line that is not the feed's (disclosed).
    $FI = Join-Path $T 'fi'
    New-Item -ItemType Directory -Path $FI -Force | Out-Null
    $iI = Invoke-W7 -File (Join-Path $repoRoot 'mission.ps1') -Argv @('init', '-Target', $FI) -Env @{ VANGUARD_HOME = $H2 }
    $null = Invoke-W7Git $FI @('init', '-q'); $null = Invoke-W7Git $FI @('add', '-A'); $null = Invoke-W7Git $FI @('commit', '-q', '-m', 'w7 fixture: a fresh install')
    $st0 = Invoke-W7Git $FI @('status', '--porcelain')
    $ci = Invoke-W7Git $FI @('check-ignore', '-q', '.mission-runtime/telemetry/events.jsonl')
    $app5 = Join-Path $T 'app5.ps1'
    Write-W7File $app5 @'
param([string]$Root, [string]$Lib, [int]$N)
. $Lib
$okN = 0
for ($i = 1; $i -le $N; $i++) { if (Write-MissionEvent -Root $Root -Kind 'tool_call' -Payload ([ordered]@{ tool = 'w7-u15'; exit_code = $null; paths = @(); session_id = 'w7u15'; dispatch_id = 'w7-u15' }) -SourcePath '.mission/mission.yaml' -Hook 'PostToolUse' -DispatchId 'w7-u15') { $okN++ } }
Write-Output "APPENDED $okN"
'@
    $b0 = Get-W7Feed -Root $FI
    $ap = Invoke-W7 -File $app5 -Argv @('-Root', $FI, '-Lib', (Join-Path $hooksDir 'lib\evidence-common.ps1'), '-N', '5') -Env @{ VANGUARD_HOME = $H2; CLAUDE_PROJECT_DIR = $FI }
    $a0 = Get-W7Feed -Root $FI
    $added = $a0.Count - $b0.Count
    $st = Invoke-W7Git $FI @('status', '--porcelain')
    $clean = ($st.code -eq 0) -and (@($st.out | Where-Object { $_ }).Count -eq 0)
    $clean0 = (@($st0.out | Where-Object { $_ }).Count -eq 0)
    $ok = ($iI.code -eq 0) -and $clean0 -and ($ci.code -eq 0) -and ($added -eq 5) -and $clean
    $d = "    a fresh install: mission init (exit $($iI.code)), git init, everything committed; porcelain before the appends empty: $clean0`n"
    $d += "    git check-ignore .mission-runtime/telemetry/events.jsonl there: exit $($ci.code) (expect 0)`n"
    $d += "    5 appends: E gained $added line(s) (expect 5); git status --porcelain afterwards: $(if ($clean) { '(empty)' } else { ($st.out -join ' | ') })`n"
    Check -Id 'U-15' -Title "ignored, never committed: check-ignore succeeds in a fresh install and the porcelain stays empty after N appends" -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-15' $_ } }

# =================================================================================================
# U-16 -- every line validates
# =================================================================================================
if (Want 'U-16') { try {
    $d = ''
    $tot = 0; $rej = 0; $kindsSeen = @{}
    foreach ($rt in @($S, $F, $W, (Join-Path $T 'fi'), (Join-Path $T 'fd'), $X)) {
        $feed16 = Get-W7Feed -Root $rt
        $bad = @()
        foreach ($l in $feed16) {
            $tot++
            $v = Test-W7Line $l
            if ($v) { $rej++; $bad += $v }
            elseif ($l.obj) { $kindsSeen[[string]$l.obj.kind] = $true }
        }
        $d += "    $rt : $($feed16.Count) line(s), $($bad.Count) rejected$(if ($bad.Count) { ': ' + (($bad | Select-Object -First 3) -join '; ') })`n"
    }
    $need = @('tool_call', 'session_start', 'session_stop', 'dispatch_finalized', 'compact', 'ledger_row', 'spec_bumped', 'gate_expired', 'gate_minted', 'gate_consumed', 'halt_raised', 'halt_resolved', 'verify_result', 'tip_observed', 'mission_snapshot', 'dispatch_opened', 'assertion_result')
    $absentKinds = @($need | Where-Object { -not $kindsSeen.ContainsKey($_) })
    $d += "    lines: $tot; rejected: $rej (expect 0); kinds U-2..U-5 should have left that no stream carries: $(if ($absentKinds.Count) { $absentKinds -join ', ' } else { '(none)' })`n"
    $full = ($Only.Count -eq 0)
    $ok = ($tot -gt 0) -and ($rej -eq 0) -and ((-not $full) -or $absentKinds.Count -eq 0)
    Check -Id 'U-16' -Title 'after U-2..U-5 every line of every stream validates against the schema, zero rejections' -Ok $ok -Detail $d
} catch { Write-W7Threw 'U-16' $_ } }

# =================================================================================================
# U-17 -- snapshot milestones (UI-1 S2-AM1, s2-amendment-1.md)
# =================================================================================================
if (Want 'U-17') { try {
    $d = ''
    $tsRx = '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$'
    $msKeys = @('title', 'status', 'assertions_total', 'assertions_green', 'started_ts', 'done_ts')
    $lastSnap17 = { param($Root) @(Get-W7Kind (Get-W7Feed -Root $Root) 'mission_snapshot') | Select-Object -Last 1 }
    $m1Of = { param($line) if ($line -and (Get-W7Has $line.obj.payload 'milestones') -and (Get-W7Has $line.obj.payload.milestones 'M-1')) { $line.obj.payload.milestones.'M-1' } else { $null } }
    # THE SPEC the smoke mission's current.txt names; a status line is written into (and taken out of) its M-1 block
    $tok17 = ([System.IO.File]::ReadAllText((Join-Path $S '.mission\spec\current.txt'))).Trim()
    $spec17 = Join-Path $S (".mission\spec\" + $tok17)
    $orig17 = [System.IO.File]::ReadAllText($spec17)
    $nameAt = [regex]::Match($orig17, '(?m)^[ \t]+name:[ \t]*"Smoke milestone"[^\n]*\n')
    $setStatus = { param([string]$St, [string]$Why)
        $text17 = if ($St) { $orig17.Insert($nameAt.Index + $nameAt.Length, "    status: $St`n") } else { $orig17 }
        Write-W7File $spec17 $text17
        $null = Invoke-W7Git $S @('add', '--', ('.mission/spec/' + $tok17)); $null = Invoke-W7Git $S @('commit', '-q', '-m', "w7 fixture: $Why")
    }
    # a stamped time: the ts form, and within 120 s of the line's own ts (the writer stamps it just before the append)
    $near = { param($v, $line)
        if (-not ($v -is [string]) -or ($v -notmatch $tsRx) -or -not $line) { return $false }
        $fmt17 = 'yyyy-MM-ddTHH:mm:ss.fffZ'; $ci = [System.Globalization.CultureInfo]::InvariantCulture
        return ([Math]::Abs(([datetime]::ParseExact($line.obj.ts, $fmt17, $ci) - [datetime]::ParseExact($v, $fmt17, $ci)).TotalSeconds) -lt 120)
    }
    $null = Invoke-W7LedgerAppend -Tag 'u17a'   # the feed's snapshot brought up to this state
    $prev = & $lastSnap17 $S
    $d += "    the smoke spec ($tok17): M-1 block found: $($nameAt.Success); the last snapshot before the changes: seq $(if ($prev) { $prev.obj.seq } else { '(none)' })`n"
    # A MILESTONE STATUS CHANGE MOVES snapshot_sha256: four changes, each one new snapshot carrying it; then none.
    $steps = @(); $chgOk = $nameAt.Success -and ($null -ne $prev)
    foreach ($st in @('active', 'passed', 'pending', 'active')) {
        & $setStatus $st "M-1 status $st"
        $before = Get-W7Feed -Root $S
        $rv = Invoke-W7LedgerAppend -Tag ('u17' + $st)
        $after = Get-W7Feed -Root $S
        $new = @(Get-W7Kind ($after | Select-Object -Skip $before.Count) 'mission_snapshot')
        $m = if ($new.Count) { & $m1Of $new[-1] } else { $null }
        $pm = & $m1Of $prev
        $ok1 = ($new.Count -eq 1) -and $m -and ($m.status -ceq $st) -and ($new[0].obj.payload.snapshot_sha256 -cne $prev.obj.payload.snapshot_sha256) -and -not (Test-W7Line $new[0])
        # the times: stamped on the observed transition, carried otherwise, null when pending
        $tsOk = $false
        if ($m) {
            switch ($st) {
                'passed'  { $tsOk = (& $near $m.done_ts $new[0]) -and ($m.started_ts -ceq $pm.started_ts) }
                'pending' { $tsOk = ($null -eq $m.started_ts) -and ($null -eq $m.done_ts) }
                'active'  { $tsOk = ($null -eq $m.done_ts) -and $(if ($pm.status -ceq 'pending') { & $near $m.started_ts $new[0] } else { $m.started_ts -ceq $pm.started_ts }) }
            }
        }
        $steps += "M-1 $($pm.status) -> ${st}: $($new.Count) snapshot(s) (expect 1), status $(if ($m) { $m.status }), started_ts $(if ($m) { $m.started_ts }), done_ts $(if ($m) { $m.done_ts }), times $tsOk, verb exit $($rv.code)"
        $chgOk = $chgOk -and $ok1 -and $tsOk
        if ($new.Count) { $prev = $new[-1] }
    }
    foreach ($stepLine in $steps) { $d += "      $stepLine`n" }
    $bU = Get-W7Feed -Root $S
    $null = Invoke-W7LedgerAppend -Tag 'u17same'
    $nSame = @(Get-W7Kind ((Get-W7Feed -Root $S) | Select-Object -Skip $bU.Count) 'mission_snapshot').Count
    $d += "    nothing changed, ledger-append again: $nSame snapshot(s) (expect 0) -> status changes $chgOk`n"
    # CONCURRENT OFFERS after ONE milestone change that stamps a time (-> passed): the times are kept out of the hash,
    # so three processes at once write ONE snapshot.
    & $setStatus 'passed' 'M-1 status passed, offered three times at once'
    $snap17 = Join-Path $T 'snap17.ps1'
    Write-W7File $snap17 @'
param([string]$Root, [string]$Tm, [string]$Go)
. $Tm
while (-not (Test-Path -LiteralPath $Go)) { Start-Sleep -Milliseconds 20 }
Invoke-MissionTelemetry -Root $Root -Snapshot -Verb 'w7-u17-concurrent'
'@
    $go17 = Join-Path $T 'go17'
    $bC = Get-W7Feed -Root $S
    $saved17 = $env:VANGUARD_HOME; $env:VANGUARD_HOME = $H
    $procs17 = @()
    try {
        foreach ($i in 1..3) {
            $procs17 += Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$snap17`"", '-Root', "`"$S`"", '-Tm', ('"' + (Join-Path $S 'tools\lam\mission-telemetry.ps1') + '"'), '-Go', "`"$go17`"") -PassThru -WindowStyle Hidden
        }
    } finally { $env:VANGUARD_HOME = $saved17 }
    Start-Sleep -Seconds 4
    Write-W7File $go17 'go'
    foreach ($p17 in $procs17) { $null = $p17.WaitForExit(180000) }
    $sC = @(Get-W7Kind ((Get-W7Feed -Root $S) | Select-Object -Skip $bC.Count) 'mission_snapshot')
    $concOk = ($sC.Count -eq 1) -and ((& $m1Of $sC[0]).status -ceq 'passed') -and (& $near (& $m1Of $sC[0]).done_ts $sC[0])
    $d += "    three concurrent offers after M-1 -> passed: $($sC.Count) snapshot(s) (expect 1, done_ts stamped) -> $concOk`n"
    & $setStatus $null 'M-1 status line taken out again'
    $null = Invoke-W7LedgerAppend -Tag 'u17z'
    # THE DERIVATION: the smoke mission's latest map is its spec's milestone list, totals from the spec, green from the
    # snapshot's own assertion map; the fresh install x\ (milestones: []) carries an empty map.
    $ls = & $lastSnap17 $S
    $sec17 = [regex]::Match($orig17, '(?ms)^milestones:[^\r\n]*\r?\n(.*?)(?=^[A-Za-z_]|\z)')
    $specIds = @([regex]::Matches($sec17.Groups[1].Value, '(?m)^\s*-\s+id:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value.Trim('"', "'") })
    $mapIds = if ($ls -and (Get-W7Has $ls.obj.payload 'milestones')) { @($ls.obj.payload.milestones.PSObject.Properties | ForEach-Object { $_.Name }) } else { @() }
    $al = [regex]::Match($sec17.Groups[1].Value, '(?m)^\s+assertions:\s*\[([^\]]*)\]')
    $listed = @($al.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $mL = & $m1Of $ls
    $greenL = @($listed | Where-Object { $ls -and (Get-W7Has $ls.obj.payload.assertions $_) -and ($ls.obj.payload.assertions.$_ -ceq 'green') }).Count
    $statusL = @($listed | Where-Object { $ls -and (Get-W7Has $ls.obj.payload.assertions $_) -and ($ls.obj.payload.assertions.$_ -cne 'pending') }).Count
    $wantSt = if ($listed.Count -and $greenL -eq $listed.Count) { 'passed' } elseif (($ls.obj.payload.current_milestone -ceq 'M-1') -or $statusL) { 'active' } else { 'pending' }
    $derOk = ($specIds.Count -ge 1) -and ((@($mapIds) -join ',') -ceq (@($specIds | Sort-Object) -join ',')) -and $mL -and ($mL.title -ceq 'Smoke milestone') -and
             ($mL.assertions_total -eq $listed.Count) -and ($mL.assertions_green -eq $greenL) -and ($mL.status -ceq $wantSt)
    $d += "    derivation: spec ids $($specIds -join ',') = map ids $($mapIds -join ','); M-1 title '$($mL.title)', total $($mL.assertions_total) (spec lists $($listed.Count)), green $($mL.assertions_green) (snapshot says $greenL), status $($mL.status) -> $derOk`n"
    $xs = & $lastSnap17 $X
    $xOk = ($null -eq $xs) -or ((Get-W7Has $xs.obj.payload 'milestones') -and ($xs.obj.payload.milestones -is [System.Management.Automation.PSCustomObject]) -and (@($xs.obj.payload.milestones.PSObject.Properties).Count -eq 0))
    $d += "    x\ (milestones: [] in its spec): its last snapshot's map $(if ($xs) { 'has ' + @($xs.obj.payload.milestones.PSObject.Properties).Count + ' entr(ies)' } else { '(no snapshot in x)' }) (expect 0) -> $xOk`n"
    # PRESENT ON EVERY SNAPSHOT, every entry exactly the six fields
    $nSnap = 0; $shapeBad = @()
    foreach ($rt in @($S, $F, $W, (Join-Path $T 'fi'), (Join-Path $T 'fd'), $X)) {
        foreach ($l in @(Get-W7Kind (Get-W7Feed -Root $rt) 'mission_snapshot')) {
            $nSnap++
            if (-not (Get-W7Has $l.obj.payload 'milestones') -or -not ($l.obj.payload.milestones -is [System.Management.Automation.PSCustomObject])) { $shapeBad += "$rt seq $($l.obj.seq): no milestones map"; continue }
            foreach ($pp in @($l.obj.payload.milestones.PSObject.Properties)) {
                $e = $pp.Value
                $names = @($e.PSObject.Properties | ForEach-Object { $_.Name })
                $bad = (($names -join ',') -cne ($msKeys -join ',') -and ((@($names | Sort-Object) -join ',') -cne (@($msKeys | Sort-Object) -join ','))) -or
                       -not ($e.status -is [string]) -or -not (Test-W7Type $e.assertions_total 'integer') -or -not (Test-W7Type $e.assertions_green 'integer') -or
                       -not (($null -eq $e.started_ts) -or ([string]$e.started_ts -match $tsRx)) -or -not (($null -eq $e.done_ts) -or ([string]$e.done_ts -match $tsRx))
                if ($bad) { $shapeBad += "$rt seq $($l.obj.seq) $($pp.Name): fields $($names -join ',')" }
            }
        }
    }
    $shapeOk = ($nSnap -gt 0) -and ($shapeBad.Count -eq 0)
    $d += "    every mission_snapshot of every stream: $nSnap, without the map or with an entry not {$($msKeys -join ', ')}: $($shapeBad.Count)$(if ($shapeBad.Count) { ' -- ' + (($shapeBad | Select-Object -First 3) -join '; ') }) -> $shapeOk`n"
    # SS14 NAMES THE FIELD; THE SCHEMA FILE IS BYTE-UNCHANGED (the S0 contract's file, sha256 pinned by s2-amendment-1.md's batch)
    $row14 = @([System.IO.File]::ReadAllLines((Join-Path $repoRoot 'docs\framework\expanded-schemas.md')) | Where-Object { $_.StartsWith('| `mission_snapshot` |') })
    $docOk = ($row14.Count -eq 1) -and ($row14[0].Contains('`milestones`')) -and (@($msKeys | Where-Object { -not $row14[0].Contains('`' + $_ + '`') }).Count -eq 0)
    $schemaSha = Get-W7Sha $schemaPath
    $schemaOk = ($schemaSha -ceq '8488ed475fa49c7a25b0002d2ee1f625b07c279e221c9fe6588308ea2c5fcc4a')
    $d += "    expanded-schemas.md SS14 mission_snapshot row names milestones and its six fields: $docOk; mission-event.schema.json sha256 $schemaSha (expect 8488ed47..., the S0 file) -> $schemaOk`n"
    Check -Id 'U-17' -Title 'every mission_snapshot carries milestones (title, status, assertion totals, observed times) from the one writer; a milestone change moves snapshot_sha256, an unchanged state emits none; SS14 names it, the schema file unchanged' `
          -Ok ($chgOk -and ($nSame -eq 0) -and $concOk -and $derOk -and $xOk -and $shapeOk -and $docOk -and $schemaOk) -Detail $d
} catch { Write-W7Threw 'U-17' $_ } }

if (-not $KeepFixture) {
    try { $null = Invoke-W7Git $S @('worktree', 'remove', '--force', $W) } catch { }
    try { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction Stop } catch { Write-Host "  (the fixture root could not be removed: $($_.Exception.Message))" }
} else { Write-Host ""; Write-Host "fixture kept at $T" }

Write-W7Close
exit $failures
