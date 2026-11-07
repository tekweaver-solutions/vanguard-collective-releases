#Requires -Version 5.1
<#
.SYNOPSIS
  The clean-environment install proof (RELEASE-4 S2 F-H6; row 495 (11)): a fresh install from a built ZIP and nothing else,
  then the acceptance run, in a scratch root.

.DESCRIPTION
  From -Zip and nothing else, in -ScratchRoot (absent or empty; made here):
    1 release   the ZIP's SHA256SUMS line checked where a SHA256SUMS stands beside it; the ZIP expanded to <scratch>\release
    2 project   a bare origin <scratch>\origin.git and a fresh git project <scratch>\project (branch main) cloned from it
    3 install   <release>\install.ps1 -Target <project> -ReleaseZip <zip>, with -Python when given, else -SkipPythonSet
    4 init      <release>\mission.ps1 init -Target <project>; the project committed whole and pushed to its origin
    5 smoke     <release>\mission.ps1 smoke -Target <project> (MET, exit 0)
    6 register  <release>\mission.ps1 register -Target <project>
                (mission.ps1 is the release's, run from the expanded folder: install.ps1 does not install it, row 505 (a))
    7 build     <project>\tools\lam\build-smoke-mission.ps1 -SmokeRoot <scratch>\lam-smoke (the instruments' default: the
                sibling of the project), in a child process
    8 accept    <project>\tools\lam\instrument-acceptance.ps1 -RunKey <RunKey> -Root <project> -SmokeRoot <scratch>\lam-smoke;
                then every capture of the run key is read and its tally line (" WP-n: ...") printed
  -Through <step> stops after that step (a member that needs no acceptance run uses it); the default is accept.

  THE ENVIRONMENT. Every child runs with VANGUARD_HOME = <scratch>\vanguard-home and TEMP = TMP = <scratch>\tmp -- never
  the caller's -- set for the run and put back as they were in a finally; every git call this script makes passes its
  identity and line-ending rule with -c, so nothing is read from or written to the caller's git configuration. At the end
  the script compares the caller's whole environment (Env:) and the caller's VANGUARD_HOME folder (its file names, sizes
  and write times, where one stands) with what they were at the start: both must be unchanged. It writes nothing outside
  -ScratchRoot; the run key's captures are the project's own, under <project>\.mission-runtime\lam\instrument-runs.

  THE ENGINE. -EngineDown asserts, before anything is read, that the container engine is down -- the read the evaluator
  makes (tools\lam\mission-goal-check.ps1, engine_read docker_pipe_then_version): no \\.\pipe\dockerDesktopLinuxEngine,
  or `docker version --format {{.Server.Version}}` failing. The engine's state is the operator's; this script only reads
  it, and it prints the reading either way. An engine that is up under -EngineDown refuses the run (exit 3).

  OUTPUT: one "PROOF <step> PASS|FAIL -- <what>" line per step, the tally lines, "PROOF ENV PASS|FAIL", then
  "PROOF RESULT: <n> step(s), <f> failed". EXIT 0 iff every step passed (and, at accept, every instrument exited 0);
  1 a step failed; 2 a parameter refused (nothing made); 3 -EngineDown and the engine is up.
#>
param(
    [Parameter(Mandatory = $true)][string]$Zip,
    [Parameter(Mandatory = $true)][string]$ScratchRoot,
    [Parameter(Mandatory = $true)][string]$RunKey,
    [string]$Python,
    [switch]$EngineDown,
    [ValidateSet('release', 'project', 'install', 'init', 'smoke', 'register', 'build', 'accept')][string]$Through = 'accept'
)
$ErrorActionPreference = 'Stop'
$steps = @('release', 'project', 'install', 'init', 'smoke', 'register', 'build', 'accept')
$last = [Array]::IndexOf($steps, $Through)
$results = New-Object System.Collections.Generic.List[string]
function Say { param([string]$T) [Console]::Out.WriteLine($T) }
function Step { param([string]$Name, [bool]$Ok, [string]$What)
    $s = if ($Ok) { 'PASS' } else { 'FAIL' }
    $results.Add("$s $Name"); Say "PROOF $Name $s -- $What"
    if (-not $Ok) { throw "step $Name failed" }
}
function Run-Child { param([string]$File, [string[]]$A)
    $ErrorActionPreference = 'Continue'
    $o = @(& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $File @A 2>&1 | ForEach-Object { "$_" })
    $c = $LASTEXITCODE
    foreach ($l in $o) { Say "  | $l" }
    return [pscustomobject]@{ code = $c; out = $o }
}
function Invoke-ProofGit { param([string]$Dir, [string[]]$A)
    $ErrorActionPreference = 'Continue'
    $o = @(& git -C $Dir -c core.autocrlf=false -c user.name=clean-install-proof -c user.email=clean-install-proof@example.invalid -c init.defaultBranch=main @A 2>&1 | ForEach-Object { "$_" })
    return [pscustomobject]@{ code = $LASTEXITCODE; out = $o }
}
function Snap-Dir { param([string]$P)
    if (-not $P -or -not (Test-Path -LiteralPath $P -PathType Container)) { return '(absent)' }
    return (@(Get-ChildItem -LiteralPath $P -Recurse -Force -File -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object { '{0}|{1}|{2}' -f $_.FullName, $_.Length, $_.LastWriteTimeUtc.Ticks }) -join "`n")
}
function Snap-Env { return (@(Get-ChildItem Env: | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Value }) -join "`n") }

# ---- parameters (exit 2, nothing made)
$zipFull = [System.IO.Path]::GetFullPath($Zip)
if (-not (Test-Path -LiteralPath $zipFull -PathType Leaf)) { Say "PROOF REFUSED: -Zip $zipFull is not a file"; exit 2 }
$scratch = [System.IO.Path]::GetFullPath($ScratchRoot).TrimEnd('\')
if ((Test-Path -LiteralPath $scratch) -and @(Get-ChildItem -LiteralPath $scratch -Force).Count -gt 0) { Say "PROOF REFUSED: -ScratchRoot $scratch is not empty"; exit 2 }
if ($RunKey -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Say "PROOF REFUSED: -RunKey '$RunKey' is not a plain key"; exit 2 }
if ($Python -and -not (Test-Path -LiteralPath $Python -PathType Leaf)) { Say "PROOF REFUSED: -Python $Python is not a file"; exit 2 }

# ---- the engine, read only
$pipeUp = @([System.IO.Directory]::GetFiles('\\.\pipe\') | Where-Object { $_ -match '\\dockerDesktopLinuxEngine$' }).Count -gt 0
$verText = ''; $verOk = $false
if ($pipeUp) { try { $verText = (@(& docker version --format '{{.Server.Version}}' 2>$null) -join ' ').Trim(); $verOk = ($LASTEXITCODE -eq 0) -and [bool]$verText } catch { $verOk = $false } }
$engineUp = $pipeUp -and $verOk
Say ("PROOF ENGINE read: pipe dockerDesktopLinuxEngine {0}; docker version server {1} -> engine {2}" -f $(if ($pipeUp) { 'present' } else { 'absent' }), $(if ($verOk) { $verText } else { '(no answer)' }), $(if ($engineUp) { 'UP' } else { 'DOWN' }))
if ($EngineDown -and $engineUp) { Say 'PROOF REFUSED: -EngineDown, and the engine is UP (the engine is the operator''s; this script only reads it)'; exit 3 }

# ---- the caller, as it stands
$callerHome = [Environment]::GetEnvironmentVariable('VANGUARD_HOME')
$callerHomeDir = if ($callerHome) { $callerHome } else { Join-Path $env:LOCALAPPDATA 'vanguard' }
$envBefore = Snap-Env
$homeBefore = Snap-Dir $callerHomeDir
$saved = @{}; foreach ($n in 'VANGUARD_HOME', 'TEMP', 'TMP', 'LAM_SMOKE_ROOT') { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }

$release = Join-Path $scratch 'release'; $origin = Join-Path $scratch 'origin.git'; $project = Join-Path $scratch 'project'
$vh = Join-Path $scratch 'vanguard-home'; $tmp = Join-Path $scratch 'tmp'; $smoke = Join-Path $scratch 'lam-smoke'
$failed = $false
try {
    foreach ($d in @($scratch, $vh, $tmp)) { $null = [System.IO.Directory]::CreateDirectory($d) }
    [Environment]::SetEnvironmentVariable('VANGUARD_HOME', $vh); [Environment]::SetEnvironmentVariable('TEMP', $tmp); [Environment]::SetEnvironmentVariable('TMP', $tmp)
    [Environment]::SetEnvironmentVariable('LAM_SMOKE_ROOT', $null)
    Say "PROOF SCRATCH $scratch; VANGUARD_HOME $vh; TEMP $tmp; zip $zipFull"

    # 1 release
    $zsha = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipFull).Hash.ToLowerInvariant()
    $sums = Join-Path (Split-Path -Parent $zipFull) 'SHA256SUMS'
    $sumOk = $true; $sumWhat = 'no SHA256SUMS beside it'
    if (Test-Path -LiteralPath $sums -PathType Leaf) {
        $line = @([System.IO.File]::ReadAllLines($sums) | Where-Object { $_ -match ('  ' + [regex]::Escape((Split-Path -Leaf $zipFull)) + '$') })
        $sumOk = ($line.Count -eq 1) -and $line[0].StartsWith($zsha + '  '); $sumWhat = "SHA256SUMS line $(if ($sumOk) { 'matches' } else { 'DOES NOT match' })"
    }
    Expand-Archive -LiteralPath $zipFull -DestinationPath $release
    Step 'release' ($sumOk -and (Test-Path -LiteralPath (Join-Path $release 'install.ps1') -PathType Leaf)) "zip sha256 $zsha; $sumWhat; expanded to $release"
    if ($last -lt 1) { throw 'PROOF-THROUGH' }

    # 2 project
    $g1 = Invoke-ProofGit $scratch @('init', '-q', '--bare', $origin)
    $g2 = Invoke-ProofGit $scratch @('clone', '-q', $origin, $project)
    Step 'project' (($g1.code -eq 0) -and ($g2.code -eq 0) -and (Test-Path -LiteralPath (Join-Path $project '.git'))) "bare origin $origin; project $project cloned from it"
    if ($last -lt 2) { throw 'PROOF-THROUGH' }

    # 3 install
    $ia = @('-Target', $project, '-ReleaseZip', $zipFull); if ($Python) { $ia += @('-Python', $Python) } else { $ia += '-SkipPythonSet' }
    $r = Run-Child (Join-Path $release 'install.ps1') $ia
    Step 'install' ($r.code -eq 0) ("install.ps1 exit $($r.code); " + (@($r.out | Where-Object { $_ -match '^install\.ps1: done: ' }) -join ' '))
    if ($last -lt 3) { throw 'PROOF-THROUGH' }

    # 4 init, committed and pushed
    $r = Run-Child (Join-Path $release 'mission.ps1') @('init', '-Target', $project)
    $ga = Invoke-ProofGit $project @('add', '-A'); $gc = Invoke-ProofGit $project @('commit', '-q', '-m', 'the installed framework and the initialised mission'); $gp = Invoke-ProofGit $project @('push', '-q', '-u', 'origin', 'HEAD:main')
    Step 'init' (($r.code -eq 0) -and ($ga.code -eq 0) -and ($gc.code -eq 0) -and ($gp.code -eq 0)) "mission init exit $($r.code); commit exit $($gc.code); push to origin exit $($gp.code)"
    if ($last -lt 4) { throw 'PROOF-THROUGH' }

    # 5 smoke
    $r = Run-Child (Join-Path $release 'mission.ps1') @('smoke', '-Target', $project)
    Step 'smoke' (($r.code -eq 0) -and (@($r.out | Where-Object { $_ -ceq 'mission.ps1: smoke: MET' }).Count -eq 1)) "mission smoke exit $($r.code)"
    if ($last -lt 5) { throw 'PROOF-THROUGH' }

    # 6 register, under the scratch VANGUARD_HOME
    $r = Run-Child (Join-Path $release 'mission.ps1') @('register', '-Target', $project)
    $vhFiles = @(Get-ChildItem -LiteralPath $vh -Recurse -File -ErrorAction SilentlyContinue)
    Step 'register' (($r.code -eq 0) -and ($vhFiles.Count -gt 0)) "mission register exit $($r.code); files under the scratch VANGUARD_HOME: $($vhFiles.Count)"
    if ($last -lt 6) { throw 'PROOF-THROUGH' }

    # 7 the smoke mission, built by the installed builder in a child (its environment dies with it)
    $r = Run-Child (Join-Path $project 'tools\lam\build-smoke-mission.ps1') @('-SmokeRoot', $smoke)
    Step 'build' (($r.code -eq 0) -and (Test-Path -LiteralPath (Join-Path $smoke '.git'))) "build-smoke-mission exit $($r.code); smoke mission $smoke"
    if ($last -lt 7) { throw 'PROOF-THROUGH' }

    # 8 the acceptance run, then the tally line of every capture of the run key
    $r = Run-Child (Join-Path $project 'tools\lam\instrument-acceptance.ps1') @('-RunKey', $RunKey, '-Root', $project, '-SmokeRoot', $smoke)
    $exits = @($r.out | Where-Object { $_ -match '^WP-\d exit=' })
    $runs = Join-Path $project '.mission-runtime\lam\instrument-runs'
    $caps = @(Get-ChildItem -LiteralPath $runs -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.StartsWith($RunKey + '.') } | Sort-Object Name)
    Say "PROOF TALLY ($($caps.Count) capture(s) of run key $RunKey under $runs)"
    foreach ($cap in $caps) { foreach ($tl in @([System.IO.File]::ReadAllLines($cap.FullName) | Where-Object { $_ -match '^ WP-\d: ' })) { Say ("  {0}: {1}" -f $cap.Name, $tl) } }
    foreach ($e in $exits) { Say "  $e" }
    $allZero = ($exits.Count -eq 7) -and (@($exits | Where-Object { $_ -notmatch ' exit=0$' }).Count -eq 0)
    Step 'accept' (($r.code -eq 0) -and $allZero) "acceptance exit $($r.code); instruments exiting 0: $(@($exits | Where-Object { $_ -match ' exit=0$' }).Count) of $($exits.Count)"
} catch {
    $failed = $true
    if ($_.Exception.Message -ceq 'PROOF-THROUGH') { $failed = $false; Say "PROOF THROUGH $Through -- stopped after it, as asked" }
    elseif (-not ($_.Exception.Message -like 'step * failed')) { $results.Add('FAIL exception'); Say "PROOF EXCEPTION -- $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
} finally {
    foreach ($n in $saved.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n]) }
}
$envOk = ((Snap-Env) -ceq $envBefore); $homeOk = ((Snap-Dir $callerHomeDir) -ceq $homeBefore)
$results.Add($(if ($envOk -and $homeOk) { 'PASS env' } else { 'FAIL env' }))
Say ("PROOF ENV {0} -- the caller's environment unchanged: {1}; the caller's VANGUARD_HOME ({2}) unchanged: {3}" -f $(if ($envOk -and $homeOk) { 'PASS' } else { 'FAIL' }), $envOk, $callerHomeDir, $homeOk)
$nf = @($results | Where-Object { $_ -like 'FAIL*' }).Count
Say "PROOF RESULT: $($results.Count) step(s), $nf failed (through $Through)"
if ($nf -gt 0) { exit 1 }
exit 0
