# test-a10-atomic-rollback.ps1 -- A10: Invoke-AtomicCommit destructive-rollback guard acceptance
# (D3 build). Authority: the operator-ratified disposition-B revision (sha256 prefix 999a272f;
# the earlier ratified bytes are the preserved diff basis) to the sealed dispatch
# docs/framework/build-dispatches/build-dispatch-atomic-commit-rollback-guard.md.
#
# WHAT THIS INSTRUMENT DECIDES. The paired case IS the gate (operator constraint 1): the
# PRE-CURE replica must DESTROY the decoy bystanders and the CURED helper must PRESERVE them,
# in the same run against same-shaped fixtures. It further drives: both retry halves
# (constraint 2 -- commit-failure branch cleared by reset --hard's staged-file deletion,
# add-failure branch cleared by the paths-scoped delta clean, then a REAL Invoke-SpecBump
# retry passing the A-121 guard); the site-annotated concurrent-writer members (constraint 3
# -- helper: structural survival; A-169 site: deletion, the demonstrated residual); the R2f
# directory-grain member (outcome MEASURED, not asserted); the success path byte-for-byte in
# behaviour; and the phantom-commit guard via a disclosed stub-drive.
#
# ANCHOR BASIS: CONTENT- AND CONSTRUCTION-ANCHORED. It anchors to NO sealed digest, derives
# nothing from .mission/amendments/ as a set, and MUTATES ONLY constructed scratch
# repositories under the temp root. The real repository is consulted READ-ONLY (porcelain
# before/after, asserted identical).
#
# SELF-DRIVE ADMISSIBILITY (differs from A9, stated so a ceremony does not misread it):
# every git invocation here targets a CONSTRUCTED SCRATCH repository; no command composes
# guard-protected territory. An in-session build-time drive of the scratchpad-authored copy
# (via -LibPath) is therefore admissible and was performed; the PLACED instrument remains
# operator-run for the record. -LibPath exists exactly for that pre-placement drive; when
# placed under tools/framework/tests/ the default resolves to the real mission-lib.ps1.
#
# INSTRUMENT LAWS: (a) pure ASCII source asserting its own bytes (A10-8);
# (b) path variables carry a Path suffix; (c) the instrument's OWN git calls run through a
# redirected System.Diagnostics.Process (native stderr can never surface as a PowerShell
# error record). The DRIVEN mission-lib functions keep their own bare `& git` idiom -- that
# idiom is part of what is under test; fixture repos set core.autocrlf=false so no benign
# CRLF chatter reaches the driven code's stderr.
#
# STUB DISCLOSURE (the A9 stubbed-terminator precedent): after dot-sourcing mission-lib,
# Stop-WithError is REDEFINED to record its message and THROW a marked exception instead of
# exiting the process (the real terminator never returns; the stub preserves that invariant
# while keeping the suite alive). The phantom drive additionally shadows `git` with a
# passthrough whose `commit` is a no-op exit 0 -- the only way to produce commit-succeeded-
# HEAD-unmoved without racing; disclosed in that check's detail and removed in finally.
#
# EXIT CONTRACT (printed at run time): 0 = every check passed. 2 = anchor guard failed
# (mission-lib.ps1 not found at -LibPath, git unavailable, or the real repository root not
# derivable; no check was decided). 4 = one or more checks failed. NON-UNIQUENESS DISCLOSED:
# exit 4 is also A5's and A9's failing exit; exit 2 is also A4's current documented result.
# Read the printed counts, not the code alone.
#
# REACH: this instrument decides whether the D3 cure BEHAVES as ruled (its split
# semantics) against constructed fixtures. It cannot decide whether the ruling is right, and
# it does not drive the nine ceremony commands end-to-end (they mutate the real mission
# record; they are listed unexercised with that reason).

#requires -Version 5.0
param(
    [string]$LibPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mission-lib.ps1'),
    [string]$ScratchRootPath = (Join-Path $env:TEMP ('a10-scratch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))),
    [switch]$KeepScratch
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:PassCount = 0
$script:FailCount = 0
$script:FailingIds = @()
$script:StopMsg = $null
$script:ShadowCommitCalls = 0

function Add-Result {
    param([string]$Id, [bool]$Ok, [string]$Detail)
    if ($Ok) {
        $script:PassCount = $script:PassCount + 1
        Write-Output ("[PASS] {0}: {1}" -f $Id, $Detail)
    } else {
        $script:FailCount = $script:FailCount + 1
        $script:FailingIds = $script:FailingIds + $Id
        Write-Output ("[FAIL] {0}: {1}" -f $Id, $Detail)
    }
}

function Invoke-NativeGit {
    # Law (c): the instrument's own git calls -- redirected Process API, stderr contained.
    param([string[]]$ArgList, [string]$WorkDirPath)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $quoted = @()
    foreach ($a in $ArgList) { $quoted = $quoted + ('"' + $a + '"') }
    $psi.Arguments = ($quoted -join ' ')
    $psi.WorkingDirectory = $WorkDirPath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ Out = $out; Err = $err; Code = $proc.ExitCode }
}

function Write-FixtureFile {
    param([string]$FilePath, [string]$Content)
    $dir = Split-Path $FilePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($FilePath, $Content)
}

function New-A10Fixture {
    # A fresh scratch repository per scenario: tracked .mission base (spec v001 + current.txt +
    # mission.yaml + ledger + a committed D9-style ignore rule), then the untracked cast --
    # two decoy bystanders (sample-shaped), a pre-placed amendment-analog, an ignored store.
    param([string]$Name)
    $repoPath = Join-Path $ScratchRootPath $Name
    New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
    $r = Invoke-NativeGit -ArgList @('-c', 'init.defaultBranch=main', 'init', '--quiet', $repoPath) -WorkDirPath $ScratchRootPath
    if ($r.Code -ne 0) { throw "fixture git init failed: $($r.Err)" }
    [void](Invoke-NativeGit -ArgList @('config', 'user.email', 'a10@fixture') -WorkDirPath $repoPath)
    [void](Invoke-NativeGit -ArgList @('config', 'user.name', 'a10') -WorkDirPath $repoPath)
    [void](Invoke-NativeGit -ArgList @('config', 'core.autocrlf', 'false') -WorkDirPath $repoPath)
    Write-FixtureFile (Join-Path $repoPath '.gitignore') "/.mission/evidence/session-fixture/`n"
    Write-FixtureFile (Join-Path $repoPath '.mission\spec\v001.yaml') "version: 1`nprevious_version: 0`ncreated_from_amendment: AM-000`nbody: fixture`n"
    [System.IO.File]::WriteAllText((Join-Path $repoPath '.mission\spec\current.txt'), 'v001')
    Write-FixtureFile (Join-Path $repoPath '.mission\mission.yaml') "state: Executing`ncurrent_spec_version: 1`n"
    Write-FixtureFile (Join-Path $repoPath '.mission\ledger\entries.jsonl') "{`"id`":`"fixture-base`"}`r`n"
    [void](Invoke-NativeGit -ArgList @('add', '--', '.gitignore', '.mission/spec/v001.yaml', '.mission/spec/current.txt', '.mission/mission.yaml', '.mission/ledger/entries.jsonl') -WorkDirPath $repoPath)
    $c = Invoke-NativeGit -ArgList @('commit', '--quiet', '-m', 'fixture base') -WorkDirPath $repoPath
    if ($c.Code -ne 0) { throw "fixture commit failed: $($c.Err)" }
    $pre = (Invoke-NativeGit -ArgList @('rev-parse', 'HEAD') -WorkDirPath $repoPath).Out.Trim()
    # the untracked cast (created AFTER the base commit -- pre-operation untracked state)
    Write-FixtureFile (Join-Path $repoPath '.mission\inputs\samples\decoy-a.md') "operator bystander a`n"
    Write-FixtureFile (Join-Path $repoPath '.mission\inputs\samples\decoy-b.md') "operator bystander b`n"
    Write-FixtureFile (Join-Path $repoPath '.mission\AM-999-fixture-amendment.yaml') "id: AM-999`n"
    Write-FixtureFile (Join-Path $repoPath '.mission\evidence\session-fixture\log.jsonl') "{`"residue`":true}`n"
    return [pscustomobject]@{
        RepoPath = $repoPath; PreSha = $pre
        DecoyAPath = Join-Path $repoPath '.mission\inputs\samples\decoy-a.md'
        DecoyBPath = Join-Path $repoPath '.mission\inputs\samples\decoy-b.md'
        AmendmentPath = Join-Path $repoPath '.mission\AM-999-fixture-amendment.yaml'
        StorePath = Join-Path $repoPath '.mission\evidence\session-fixture\log.jsonl'
        V002Path = Join-Path $repoPath '.mission\spec\v002.yaml'
        MissionYamlPath = Join-Path $repoPath '.mission\mission.yaml'
    }
}

function Get-FixtureHead {
    param([string]$RepoPath)
    return (Invoke-NativeGit -ArgList @('rev-parse', 'HEAD') -WorkDirPath $RepoPath).Out.Trim()
}

# ==================================================================================
# Anchor guard (exit 2): the lib, git, and the real repository root must resolve.
# ==================================================================================
$gitProbe = $null
try { $gitProbe = Invoke-NativeGit -ArgList @('--version') -WorkDirPath $env:TEMP } catch {}
if (-not $gitProbe -or $gitProbe.Code -ne 0) {
    Write-Output 'ANCHOR GUARD: git is not invocable. No check was decided. EXIT 2.'
    exit 2
}
if (-not (Test-Path $LibPath)) {
    Write-Output ("ANCHOR GUARD: mission-lib.ps1 not found at -LibPath '{0}'. No check was decided. EXIT 2." -f $LibPath)
    exit 2
}
$RealRootPath = Split-Path (Split-Path (Resolve-Path $LibPath).Path -Parent) -Parent
$rp0 = Invoke-NativeGit -ArgList @('status', '--porcelain=v1') -WorkDirPath $RealRootPath
if ($rp0.Code -ne 0) {
    Write-Output ("ANCHOR GUARD: real repository porcelain not derivable at '{0}'. No check was decided. EXIT 2." -f $RealRootPath)
    exit 2
}
$RealPorcelainBefore = $rp0.Out
New-Item -ItemType Directory -Force -Path $ScratchRootPath | Out-Null

# Dot-source the REAL lib under test, then stub its terminator (disclosed above).
. $LibPath
function Stop-WithError { param([string]$m) $script:StopMsg = $m; throw ('A10-STOPPED: ' + $m) }

Write-Output ("A10: driving mission-lib at {0}" -f (Resolve-Path $LibPath).Path)
Write-Output ("A10: scratch root {0}" -f $ScratchRootPath)
Write-Output ''

# ==================================================================================
# A10-1a -- PRE-CURE REPLICA (negative control): the B1 catch logic, labelled, DESTROYS.
# ==================================================================================
$fxA = New-A10Fixture -Name 'fx-a-precure'
Write-FixtureFile $fxA.V002Path "half-bump unstaged`n"
# THE REPLICA, verbatim semantics of the pre-cure catch (reset --hard + bare .mission clean):
[void](Invoke-NativeGit -ArgList @('reset', '--hard', '-q', $fxA.PreSha) -WorkDirPath $fxA.RepoPath)
[void](Invoke-NativeGit -ArgList @('clean', '-fd', '--', '.mission') -WorkDirPath $fxA.RepoPath)
Add-Result 'A10-1a-i' ((-not (Test-Path $fxA.DecoyAPath)) -and (-not (Test-Path $fxA.DecoyBPath))) 'pre-cure replica DESTROYED both decoy bystanders (the R2 defect, demonstrated -- the pair''s destructive half)'
Add-Result 'A10-1a-ii' (-not (Test-Path $fxA.AmendmentPath)) 'pre-cure replica destroyed the pre-placed amendment-analog too'
Add-Result 'A10-1a-iii' (Test-Path $fxA.StorePath) 'ignored store survived the pre-cure replica (clean without -x skips ignored; D9-class unchanged)'

# ==================================================================================
# A10-1b -- CURED HELPER (paired positive): commit-failure branch preserves bystanders.
# ==================================================================================
$fxB = New-A10Fixture -Name 'fx-b-cured'
Write-FixtureFile $fxB.V002Path "half-bump op-created`n"
$missionOriginal = [System.IO.File]::ReadAllText($fxB.MissionYamlPath)
Write-FixtureFile $fxB.MissionYamlPath "state: Executing`ncurrent_spec_version: 2`n"
$script:StopMsg = $null
try {
    Invoke-AtomicCommit -Root $fxB.RepoPath -Paths @('.mission/AM-999-fixture-amendment.yaml', '.mission/spec/v002.yaml', '.mission/mission.yaml') -MessageFile (Join-Path $fxB.RepoPath 'no-such-message-file.txt') | Out-Null
} catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
Add-Result 'A10-1b-i' ($null -ne $script:StopMsg) ("cured helper took the rollback path on commit failure (refusal captured: '{0}')" -f $script:StopMsg)
Add-Result 'A10-1b-ii' ((Test-Path $fxB.DecoyAPath) -and (Test-Path $fxB.DecoyBPath)) 'cured helper PRESERVED both decoy bystanders -- the pair''s preserving half, same fixture shape, same run (the gate)'
Add-Result 'A10-1b-iii' (-not (Test-Path $fxB.AmendmentPath)) 'staged amendment-analog deleted BY RESET --HARD itself (the joint-erratum semantic, driven)'
Add-Result 'A10-1b-iv' (-not (Test-Path $fxB.V002Path)) 'staged v002 deleted by reset --hard (commit-failure retry half: no v(N+1) survives)'
Add-Result 'A10-1b-v' ([System.IO.File]::ReadAllText($fxB.MissionYamlPath) -eq $missionOriginal) 'mid-operation tracked modification reverted (reset --hard demonstrably ran)'
Add-Result 'A10-1b-vi' ((Get-FixtureHead $fxB.RepoPath) -eq $fxB.PreSha) 'HEAD restored to the pre-operation SHA (A-123)'
Add-Result 'A10-1b-vii' (Test-Path $fxB.StorePath) 'ignored store survived the cured rollback'

# ==================================================================================
# A10-2a -- RETRY, commit-failure half: a REAL Invoke-SpecBump passes the A-121 guard.
# ==================================================================================
Write-FixtureFile $fxB.AmendmentPath "id: AM-999`n"   # operator re-places the amendment
$retryOk = $false
try { $null = Invoke-SpecBump -Root $fxB.RepoPath -AmendmentId 'AM-999' -BodyTransform $null; $retryOk = $true }
catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
$curNow = [System.IO.File]::ReadAllText((Join-Path $fxB.RepoPath '.mission\spec\current.txt')).Trim()
Add-Result 'A10-2a-i' ($retryOk -and (Test-Path $fxB.V002Path) -and ($curNow -eq 'v002')) ("REAL Invoke-SpecBump retry PERMITTED by A-121 after the rollback (current.txt={0}); the cure did not break the retry" -f $curNow)

# ==================================================================================
# A10-2b -- ADD-failure branch: unstaged intent-set members cleaned by the scoped delta.
# ==================================================================================
$fxC = New-A10Fixture -Name 'fx-c-addfail'
Write-FixtureFile $fxC.V002Path "half-bump unstaged`n"
$script:StopMsg = $null
try {
    Invoke-AtomicCommit -Root $fxC.RepoPath -Paths @('definitely-missing-path.txt', '.mission/AM-999-fixture-amendment.yaml', '.mission/spec/v002.yaml') -MessageFile (Join-Path $fxC.RepoPath 'unused.txt') | Out-Null
} catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
Add-Result 'A10-2b-i' ($null -ne $script:StopMsg) 'rollback path taken on add failure (first pathspec unmatchable; the throw may arrive via the PS5.1 stderr class rather than the exit-code check -- both land in the same catch, disclosed)'
Add-Result 'A10-2b-ii' (-not (Test-Path $fxC.V002Path)) 'UNSTAGED v002 removed by the paths-scoped delta clean (add-failure retry half)'
Add-Result 'A10-2b-iii' (-not (Test-Path $fxC.AmendmentPath)) 'unstaged amendment-analog (a $Paths member) removed by the scoped clean -- today''s helper-site semantics preserved (wiped when it is itself the unstaged member)'
Add-Result 'A10-2b-iv' ((Test-Path $fxC.DecoyAPath) -and (Test-Path $fxC.DecoyBPath)) 'decoy bystanders (outside $Paths) preserved on the add-failure branch'
$retry2Ok = $false
try { $null = Invoke-SpecBump -Root $fxC.RepoPath -AmendmentId 'AM-999' -BodyTransform $null; $retry2Ok = $true }
catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
Add-Result 'A10-2b-v' ($retry2Ok -and (Test-Path $fxC.V002Path)) 'REAL Invoke-SpecBump retry permitted after the add-failure rollback (both retry halves proven)'

# ==================================================================================
# A10-3 -- concurrent-writer at the HELPER (structural survival) + the overwrite member.
# ==================================================================================
$fxD = New-A10Fixture -Name 'fx-d-concurrent'
Write-FixtureFile (Join-Path $fxD.RepoPath '.mission\preexisting-note.md') "ORIGINAL`n"
Write-FixtureFile $fxD.V002Path "half-bump`n"
Write-FixtureFile (Join-Path $fxD.RepoPath '.mission\intruder-concurrent.md') "concurrent writer analog`n"
Write-FixtureFile (Join-Path $fxD.RepoPath '.mission\preexisting-note.md') "MID-OP OVERWRITE`n"
$script:StopMsg = $null
try {
    Invoke-AtomicCommit -Root $fxD.RepoPath -Paths @('.mission/spec/v002.yaml') -MessageFile (Join-Path $fxD.RepoPath 'no-such-message-file.txt') | Out-Null
} catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
Add-Result 'A10-3a-i' (Test-Path (Join-Path $fxD.RepoPath '.mission\intruder-concurrent.md')) 'concurrent-writer analog OUTSIDE $Paths SURVIVED the helper rollback -- the STRUCTURAL guarantee demonstrated, not just the hazard (timing disclosure: same-process plant; the helper takes no snapshot, so plant timing is immaterial to the mechanism)'
$noteNow = [System.IO.File]::ReadAllText((Join-Path $fxD.RepoPath '.mission\preexisting-note.md'))
Add-Result 'A10-3b-i' ((Test-Path (Join-Path $fxD.RepoPath '.mission\preexisting-note.md')) -and ($noteNow -like 'MID-OP*')) 'overwrite member: pre-op untracked file overwritten mid-op survives WITH the overwritten bytes -- existence preserved, content NOT restored (a stated residual, demonstrated)'

# ==================================================================================
# A10-4 -- the A-169 SITE (snapshot semantics): amendment survives; post-snapshot dies.
# ==================================================================================
$fxE = New-A10Fixture -Name 'fx-e-a169'
$missionOriginalE = [System.IO.File]::ReadAllText($fxE.MissionYamlPath)
$snap = Get-MissionUntrackedPaths -Root $fxE.RepoPath
Write-FixtureFile $fxE.V002Path "spec-bump creation`n"
Write-FixtureFile (Join-Path $fxE.RepoPath '.mission\intruder-post-snapshot.md') "arrived inside the window`n"
Write-FixtureFile $fxE.MissionYamlPath "state: Executing`ncurrent_spec_version: 2`n"
$delta = @(Get-MissionUntrackedPaths -Root $fxE.RepoPath | Where-Object { $snap -notcontains $_ })
Invoke-GuardedRollback -Root $fxE.RepoPath -PreSha $fxE.PreSha -RemovePaths $delta
Add-Result 'A10-4-i' (-not (Test-Path $fxE.V002Path)) 'A-169 site: the operation''s own vNNN removed by the snapshot delta'
Add-Result 'A10-4-ii' (-not (Test-Path (Join-Path $fxE.RepoPath '.mission\intruder-post-snapshot.md'))) 'A-169 site: post-snapshot arrival DELETED -- the concurrent-writer residual at this site, demonstrated and stated as what actually happens'
Add-Result 'A10-4-iii' (Test-Path $fxE.AmendmentPath) 'A-169 site: pre-placed amendment-analog SURVIVED the refusal rollback (the ratified promise, holding at the one site where it is implementable)'
Add-Result 'A10-4-iv' ((Test-Path $fxE.DecoyAPath) -and (Test-Path $fxE.DecoyBPath)) 'A-169 site: decoy bystanders survived'
Add-Result 'A10-4-v' (([System.IO.File]::ReadAllText($fxE.MissionYamlPath) -eq $missionOriginalE) -and ((Get-FixtureHead $fxE.RepoPath) -eq $fxE.PreSha)) 'A-169 site: tracked state reverted and HEAD at the pre-operation SHA'

# ==================================================================================
# A10-5 -- R2f: directory-grain $Paths (the reclaim shape), outcome MEASURED.
# ==================================================================================
$fxF = New-A10Fixture -Name 'fx-f-r2f'
Write-FixtureFile (Join-Path $fxF.RepoPath '.mission\audits\archive-copy.txt') "op artifact`n"
$script:StopMsg = $null
try {
    Invoke-AtomicCommit -Root $fxF.RepoPath -Paths @('.mission') -MessageFile (Join-Path $fxF.RepoPath 'no-such-message-file.txt') | Out-Null
} catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
$decoysGone = ((-not (Test-Path $fxF.DecoyAPath)) -and (-not (Test-Path $fxF.DecoyBPath)))
Add-Result 'A10-5-i' $decoysGone 'R2f MEASURED: directory-grain $Paths @(''.mission'') destroyed the bystanders -- mechanism: the wholesale `git add -- .mission` STAGED them, and reset --hard deleted the staged set; the blast radius is reconstituted at this grain exactly as registered (and would be reconstituted via the scoped clean on the add-failure branch)'
Add-Result 'A10-5-ii' (-not (Test-Path (Join-Path $fxF.RepoPath '.mission\audits\archive-copy.txt'))) 'R2f: the op artifact was removed (rollback itself remains coherent at this caller)'
Add-Result 'A10-5-iii' (-not (Test-Path $fxF.AmendmentPath)) 'R2f: the amendment-analog under .mission was destroyed at directory grain (swept with everything else)'
Add-Result 'A10-5-iv' (Test-Path $fxF.StorePath) 'R2f: the ignored store STILL survived even at directory grain (ignore-protection is grain-independent)'

# ==================================================================================
# A10-6 -- SUCCESS PATH: byte-for-byte behaviour, exactly the named paths, HEAD advances.
# ==================================================================================
$fxG = New-A10Fixture -Name 'fx-g-success'
Write-FixtureFile $fxG.V002Path "committed bump`n"
Write-FixtureFile $fxG.MissionYamlPath "state: Executing`ncurrent_spec_version: 2`n"
[System.IO.File]::WriteAllText((Join-Path $fxG.RepoPath '.mission\spec\current.txt'), 'v002')
$fs = [System.IO.File]::Open((Join-Path $fxG.RepoPath '.mission\ledger\entries.jsonl'), [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
try { $b = [System.Text.Encoding]::UTF8.GetBytes("{`"id`":`"fixture-close`"}`r`n"); $fs.Write($b, 0, $b.Length) } finally { $fs.Dispose() }
$msgPath = Join-Path $ScratchRootPath 'fx-g-message.txt'
[System.IO.File]::WriteAllText($msgPath, "fixture close commit`n")
$expectedPaths = @('.mission/AM-999-fixture-amendment.yaml', '.mission/spec/v002.yaml', '.mission/spec/current.txt', '.mission/mission.yaml', '.mission/ledger/entries.jsonl')
$newSha = $null
try { $newSha = Invoke-AtomicCommit -Root $fxG.RepoPath -Paths $expectedPaths -MessageFile $msgPath }
catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
$headNow = Get-FixtureHead $fxG.RepoPath
Add-Result 'A10-6-i' (($null -ne $newSha) -and ($newSha -eq $headNow) -and ($newSha -ne $fxG.PreSha)) 'success path: helper committed, returned the new SHA, HEAD advanced (signature and return value unchanged in behaviour)'
$nameOnly = (Invoke-NativeGit -ArgList @('show', '--name-only', '--format=') -WorkDirPath $fxG.RepoPath).Out
$committed = @($nameOnly -split "`r?`n" | Where-Object { $_ }) | Sort-Object
$expectedSorted = @($expectedPaths) | Sort-Object
Add-Result 'A10-6-ii' ((@($committed) -join '|') -eq (@($expectedSorted) -join '|')) ("success path: the commit contains EXACTLY the named paths (A-124): {0}" -f (@($committed) -join ', '))
Add-Result 'A10-6-iii' ((Test-Path $fxG.DecoyAPath) -and (Test-Path $fxG.DecoyBPath) -and (Test-Path $fxG.StorePath)) 'success path: bystanders and ignored store untouched'

# ==================================================================================
# A10-7 -- PHANTOM GUARD: commit-succeeded-HEAD-unmoved, via the disclosed git shadow.
# ==================================================================================
$fxH = New-A10Fixture -Name 'fx-h-phantom'
Write-FixtureFile $fxH.V002Path "phantom drive`n"
$script:RealGitPath = (Get-Command git -CommandType Application | Select-Object -First 1).Source
function git {
    if (@($args) -contains 'commit') { $script:ShadowCommitCalls = $script:ShadowCommitCalls + 1; $global:LASTEXITCODE = 0; return }
    & $script:RealGitPath @args
}
$script:StopMsg = $null
try {
    try {
        Invoke-AtomicCommit -Root $fxH.RepoPath -Paths @('.mission/spec/v002.yaml') -MessageFile (Join-Path $ScratchRootPath 'fx-g-message.txt') | Out-Null
    } catch { if ($_.Exception.Message -notlike 'A10-STOPPED:*') { throw } }
} finally {
    Remove-Item function:git -ErrorAction SilentlyContinue
}
Add-Result 'A10-7-i' (($script:ShadowCommitCalls -ge 1) -and ($null -ne $script:StopMsg) -and ((Get-FixtureHead $fxH.RepoPath) -eq $fxH.PreSha)) ("phantom guard: commit was shadowed to a no-op exit 0 ({0} call(s)), the adds succeeded, and the helper still REFUSED and rolled back with HEAD unmoved -- the only throw site left on that path is the no-advance guard (stub-drive, disclosed)" -f $script:ShadowCommitCalls)

# ==================================================================================
# A10-8 -- self-bytes (law a): pure ASCII, BOM-less, LF-only.
# ==================================================================================
$selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
$selfCr = 0; $selfHigh = 0
foreach ($sb in $selfBytes) { if ($sb -eq 13) { $selfCr++ }; if ($sb -gt 127) { $selfHigh++ } }
$selfBom = ($selfBytes.Length -ge 3 -and $selfBytes[0] -eq 0xEF -and $selfBytes[1] -eq 0xBB -and $selfBytes[2] -eq 0xBF)
Add-Result 'A10-8-i' (($selfCr -eq 0) -and ($selfHigh -eq 0) -and (-not $selfBom)) ("self-bytes: {0} bytes, CR={1}, non-ASCII={2}, BOM={3}" -f $selfBytes.Length, $selfCr, $selfHigh, $selfBom)

# ==================================================================================
# A10-9 -- zero real-repository residue: porcelain identical before and after.
# ==================================================================================
if (-not $KeepScratch) { try { Remove-Item -Recurse -Force $ScratchRootPath -ErrorAction Stop } catch {} }
$RealPorcelainAfter = (Invoke-NativeGit -ArgList @('status', '--porcelain=v1') -WorkDirPath $RealRootPath).Out
Add-Result 'A10-9-i' ($RealPorcelainBefore -eq $RealPorcelainAfter) ("real repository porcelain byte-identical before and after the suite (scratch root removed: {0})" -f (-not (Test-Path $ScratchRootPath)))

# ==================================================================================
# Summary + exit contract.
# ==================================================================================
Write-Output ''
$total = $script:PassCount + $script:FailCount
Write-Output ("A10 SUMMARY: {0} checks decided (derived count -- no hand inventory): {1} passed, {2} failed." -f $total, $script:PassCount, $script:FailCount)
if ($script:FailCount -gt 0) {
    Write-Output ("FAILING: {0}" -f (@($script:FailingIds) -join ', '))
    Write-Output 'EXIT 4 (one or more checks failed; non-unique -- read the counts above).'
    exit 4
}
Write-Output 'A10 SUITE PASSED. EXIT 0.'
exit 0
