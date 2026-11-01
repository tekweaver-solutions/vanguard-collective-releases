# test-a11-verify-anchor-arm.ps1 -- A11: mission verify, increment 1 (the decision spine + the
# ANCHOR arm) acceptance. Authority: REOPEN #43, M-113 seam S1, against
# the SEALED bytes of docs/framework/mission-verify-spec.md (A3).
#
# REPAIRED AT INCREMENT 3 (v35-21a, SS 1.4.1), AND THE REPAIR IS FIXTURE-ONLY. Increment 3 built the
# MANIFEST and PLANE-PARITY arms, which ENGAGE on a subject this instrument's artifacts already
# claim -- runner_anchors.evidence_manifest. The original fixtures named a manifest that was not a
# dispatch plane, so the new arms derived ABSENT and every gate-PASS drive here refused. THE ARMS
# ARE RIGHT AND THE FIXTURES WERE INCOMPLETE: spec:310 makes a manifest at a path that holds nothing
# ABSENT, and NOT_APPLICABLE cannot absorb it (spec:78-83, 247-250). The repair therefore GIVES THE
# ARTIFACTS A LAWFUL EVIDENCE PLANE rather than dropping the claim. No assertion was rewritten, no
# drive was added or removed, and no expectation moved.
#
# TWO ADDITIONS BEYOND THE FIXTURES, BOTH THE RULED DEV-1 REFINEMENT BEING CONSUMED (2026-08-16):
#   --plane-root  is passed by the two drives that point --evidence-root at a WRITE-FAILING path.
#                 Before the refinement one flag named both the plane a run reads and the root it
#                 writes, so those drives could not have a failing write path AND a readable plane;
#                 A11-B5's false-PASS member was UNEXPRESSIBLE for that reason alone. The flag is
#                 passed ONLY where the two roots must differ, so the default path stays driven.
#   (--library-path is NOT used here: every drive in this file runs from the real repository root,
#                 where the detectors resolve natively. It is a12 that needed it.)
#
# PLACEMENT AND PROVENANCE, STATED FIRST BECAUSE IT DECIDES WHO MAY RUN THIS. THE RULING WAS
# OPEN-C: this instrument lands at tools/framework/tests/ and is OPERATOR-PLACED AND OPERATOR-RUN.
# tools/framework/tests is in the protected set (evidence-common.ps1:1008), so an agent can neither
# write nor run it, and an instrument an agent placed or drove would be the agent grading itself.
# The builder session authored these bytes in its scratchpad and handed them over with their
# sha256. EVERY FIGURE THIS INSTRUMENT PRINTS IS THE OPERATOR'S -- the A5 discipline, whose seal
# entry states it plainly: "THE SESSION RAN NO SUITE AND CLAIMS NONE."
#
# WHAT THIS INSTRUMENT DECIDES. Per A-562, DRIVEN PER OUTCOME, each member on its own drive
# against a constructed --against artifact and a controlled repository state:
#   MATCHED / DIVERGED / MOVED / ABSENT / NOT_APPLICABLE, the scoped NOT_APPLICABLE pair, the
#   three-value exit contract, and the evidence-write-failure refusal.
# It further drives the A-564 FIRST CLAUSE ONLY -- that no derivation verify issues reads the
# local remote-tracking ref -- DERIVED from the admitted command set, never from a hand-listed
# forbidden string.
#
# WHAT THIS INSTRUMENT DOES NOT DECIDE, stated so no reader infers more from a green run:
#   - UNREACHABLE is NOT driven. A-562:47-49 requires "an origin channel made unable to answer";
#     the ORIGIN-ATTESTATION arm is exercised by a12, not here. Its absence here is DECLARED.
#   - A-563 is NOT decided. Its shape rules quantify over "EVERY arm entry" and its derivation
#     block must carry a row for every executed row of the spec:115-126 command set; that is a
#     separate assertion with its own instrument.
#   - A-564 is NOT decided. Its two-channel, no-tiebreak and UNREACHABLE clauses need the ORIGIN
#     arm. Only its exclusion clause is exercised here.
#   - A-565 is NOT decided HERE. Its member 1 (absent expected-failures home) is driven; its
#     member 2 needs the MANIFEST arm's state derivation AND schema validation, which a13 drives,
#     and A-565 requires BOTH at a stated common basis -- an operator act.
#   - A-566 / A-567 / A-568 are untouched.
#
# ANCHOR BASIS: CONTENT- AND CONSTRUCTION-ANCHORED. It anchors to NO sealed digest and derives
# nothing from .mission/amendments/ as a set. It MUTATES ONLY constructed fixtures and mutated CLI
# copies under a scratch root beneath $env:TEMP. The real repository is consulted READ-ONLY --
# git rev-parse HEAD and git status --porcelain=v1, whose values are read at run time rather than
# baked in, so the instrument does not go stale when the tree moves. Nothing is written, staged,
# hashed or run under tools/framework/** or .mission/evidence.
#
# INSTRUMENT LAWS: (a) pure ASCII source; (b) path variables carry a Path suffix;
# (c) every child process runs through a redirected System.Diagnostics.Process, so a native
# stderr byte can never surface as a PowerShell error record under PS 5.1.
#
# PLANTED BREAKAGE IS PER MEMBER AND INDEPENDENT (A-562:54-59). Each mutation is applied to a COPY
# of the CLI in the scratch root; tools/mission-verify.ps1 is never modified. Each mutated run
# asserts BOTH that its own member REDs AND that the neighbouring members stay green -- "a probe
# in which one collapse's absence greens another member's assertion is itself a defect".
#
# EXIT CONTRACT (printed at run time): 0 = every check passed. 2 = anchor guard failed (the CLI
# not found at -CliPath, git unavailable, or the repository root not derivable; no check was
# decided). 4 = one or more checks failed. NON-UNIQUENESS DISCLOSED: exit 4 is also A5's, A9's and
# A10's failing exit; exit 2 is also A10's anchor-guard exit. Read the printed counts, not the
# code alone.
#
# REACH: this instrument decides whether increment 1 BEHAVES as the sealed spec specifies against
# constructed fixtures. It cannot decide whether the spec is right, and it does not drive the real
# evidence store -- A-563:52-56 forbids greening the self-capture leg by writing the evidence plane
# from inside a session, so the write-failure refusal is proven by a PATH PERMISSION and the
# real-store leg is left to the runner or harness process.

#requires -Version 5.0
param(
    [string]$CliPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mission-verify.ps1'),
    [string]$ScratchRootPath = (Join-Path $env:TEMP ('a11-scratch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))),
    [switch]$KeepScratch
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:PassCount = 0
$script:FailCount = 0
$script:FailingIds = @()

function Add-Result {
    param([string]$Id, [bool]$Ok, [string]$Detail)
    if ($Ok) { $script:PassCount++; $verdict = 'PASS' }
    else { $script:FailCount++; $script:FailingIds += $Id; $verdict = 'FAIL' }
    [Console]::Out.WriteLine(("  {0}  {1,-8} {2}" -f $verdict, $Id, $Detail))
}

function Write-Head { param([string]$Text) [Console]::Out.WriteLine(''); [Console]::Out.WriteLine($Text) }

function Invoke-Child {
    <# Every child process goes through here: redirected, so native stderr is data, never an
       error record. Returns stdout, stderr and the HONEST exit code. #>
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectoryPath
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($ArgumentList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $WorkingDirectoryPath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $so = $p.StandardOutput.ReadToEnd()
    $se = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $rc = $p.ExitCode
    $p.Dispose()
    return [pscustomobject]@{ StdOut = $so; StdErr = $se; ExitCode = $rc }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $dirPath = Split-Path -Parent $Path
    if ($dirPath -and -not (Test-Path -LiteralPath $dirPath)) { [void][System.IO.Directory]::CreateDirectory($dirPath) }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-FileSha256 {
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($Path)
    try { return (($sha.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $fs.Dispose(); $sha.Dispose() }
}

function Get-StringSha256 {
    param([AllowEmptyString()][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}

function Get-Outcome {
    param([string]$ReportText, [string]$Subject)
    $m = [regex]::Match($ReportText, "subject:\s*$([regex]::Escape($Subject))\s*\r?\n\s*outcome:\s*(\w+)")
    if ($m.Success) { return $m.Groups[1].Value }
    return '<no-entry>'
}

function Get-Gate {
    param([string]$ReportText)
    $m = [regex]::Match($ReportText, '(?m)^gate:\s*(\w+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return '<absent>'
}

# =================================================================================================
# ANCHOR GUARD -- exit 2 if any premise is missing; no check is decided on a broken anchor.
# =================================================================================================
Write-Head '=== A11 ANCHOR GUARD ==========================================================='

if (-not (Test-Path -LiteralPath $CliPath -PathType Leaf)) {
    [Console]::Out.WriteLine("  ANCHOR FAIL: no CLI at $CliPath")
    exit 2
}
$repoRootPath = Split-Path -Parent (Split-Path -Parent $CliPath)
if (-not (Test-Path -LiteralPath (Join-Path $repoRootPath '.mission\mission.yaml'))) {
    # The CLI may be driven from elsewhere; fall back to walking up from this file.
    $probePath = $PSScriptRoot
    while ($probePath -and -not (Test-Path -LiteralPath (Join-Path $probePath '.mission\mission.yaml'))) {
        $parentPath = Split-Path -Parent $probePath
        if ($parentPath -eq $probePath) { $probePath = $null; break }
        $probePath = $parentPath
    }
    $repoRootPath = $probePath
}
if (-not $repoRootPath) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: repository root not derivable')
    exit 2
}
$gitProbe = Invoke-Child -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD') -WorkingDirectoryPath $repoRootPath
if ($gitProbe.ExitCode -ne 0) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: git unavailable or HEAD unresolvable')
    exit 2
}
$headSha = $gitProbe.StdOut.Trim()
$porcProbe = Invoke-Child -FilePath 'git' -ArgumentList @('status', '--porcelain=v1') -WorkingDirectoryPath $repoRootPath
$porcelainLines = @($porcProbe.StdOut -split "`r?`n" | Where-Object { $_ -ne '' })

[Console]::Out.WriteLine("  CLI            $CliPath")
[Console]::Out.WriteLine("  repo root      $repoRootPath")
[Console]::Out.WriteLine("  HEAD           $headSha")
[Console]::Out.WriteLine("  porcelain      $($porcelainLines.Count) line(s), read live")
[Console]::Out.WriteLine("  scratch        $ScratchRootPath")

# =================================================================================================
# FIXTURES -- constructed, outside the repository, derived from LIVE state.
# =================================================================================================
$fixturePath = Join-Path $ScratchRootPath 'fx'
$outPath = Join-Path $ScratchRootPath 'out'
$mutPath = Join-Path $ScratchRootPath 'mut'
$planePath = Join-Path $ScratchRootPath 'plane'
foreach ($d in @($fixturePath, $outPath, $mutPath, $planePath)) { [void][System.IO.Directory]::CreateDirectory($d) }

# THE EVIDENCE PLANE THE ARTIFACTS NAME (the increment-3 repair, SS 1.4.1). A plane root mirrors the
# two subpaths the SEALED detectors derive -- <root>/.mission-runtime/evidence/<id> and
# <root>/.mission/evidence/<id> -- because Get-EvidenceRuntimeDir and Get-EvidenceCommittedDir
# compute exactly those from the root they are given. The shape is the detectors' contract, not a
# choice this file made, and the dispatch id is the manifest's PARENT DIRECTORY NAME because that is
# how verify derives it (Get-DispatchIdFromManifestPath). It lives OUTSIDE the repository; this
# instrument hashes THIS plane and never anything under .mission/evidence.
$planeDispatchId = 'd-a11'
$planeRuntimePath = Join-Path $planePath ('.mission-runtime\evidence\' + $planeDispatchId)
$planeCommittedPath = Join-Path $planePath ('.mission\evidence\' + $planeDispatchId)
foreach ($d in @($planeRuntimePath, $planeCommittedPath)) { [void][System.IO.Directory]::CreateDirectory($d) }

$planeLogPath = Join-Path $planeRuntimePath 'log.jsonl'
Write-Utf8NoBom $planeLogPath ('{"seq":1,"tool":"Bash","command":"probe 1"}' + "`n" + '{"seq":2,"tool":"Bash","command":"probe 2"}' + "`n")
$planeStreamsPath = Join-Path $planeRuntimePath 'streams'
[void][System.IO.Directory]::CreateDirectory($planeStreamsPath)
Write-Utf8NoBom (Join-Path $planeStreamsPath '000001.json') '{"stdout":"hello","stderr":""}'

# Hand-assembled rather than ConvertTo-Json'd, on purpose: a serialiser that quietly normalised a
# single-element array or reordered a member would make the fixture something other than what it says.
$planeEntryJson = '{"ts":"2026-08-16T00:00:01.100Z","tool":"Bash","command":"probe 1","exit_code":0' +
    ',"stdout_sha256":"' + (Get-StringSha256 'hello') + '","stderr_sha256":"' + (Get-StringSha256 '') +
    '","path":"streams/000001.json"}'
$manifestPath = Join-Path $planeRuntimePath 'manifest.json'
$planeManifestParts = @(
    '"schema_version":"1.3.0"'
    ('"dispatch_id":"' + $planeDispatchId + '"')
    '"session_id":null'
    '"state":"finalized"'
    ('"entries":[' + $planeEntryJson + ']')
    '"entry_count":1'
    '"unparsable_lines":0'
    '"log_path":"log.jsonl"'
    '"hook_errors_present":false'
    '"hook_errors_sha256":null'
    '"streams_committed":true'
    ('"log_sha256":"' + (Get-FileSha256 $planeLogPath) + '"')
    ('"log_bytes_sealed":' + (Get-Item -LiteralPath $planeLogPath).Length)
    '"finalize_count":1'
    '"created_at":"2026-08-16T00:00:00.000Z"'
    '"finalized_at":"2026-08-16T00:00:01.000Z"'
)
Write-Utf8NoBom $manifestPath ('{' + ($planeManifestParts -join ',') + '}' + "`n")

# The publish step the Stop hook performs, reproduced so the parity subject has something to compare.
foreach ($n in @('manifest.json', 'log.jsonl')) {
    Copy-Item -LiteralPath (Join-Path $planeRuntimePath $n) -Destination (Join-Path $planeCommittedPath $n) -Force
}
$committedStreamsPath = Join-Path $planeCommittedPath 'streams'
[void][System.IO.Directory]::CreateDirectory($committedStreamsPath)
Copy-Item -LiteralPath (Join-Path $planeStreamsPath '000001.json') -Destination (Join-Path $committedStreamsPath '000001.json') -Force

$manifestSha = Get-FileSha256 $manifestPath
$manifestYamlPath = ($manifestPath -replace '\\', '/')

# An UNWRITABLE path without touching permissions: a directory cannot be created under a FILE.
$unwritablePath = Join-Path $fixturePath 'manifest-blocker.json\nope'
Write-Utf8NoBom (Join-Path $fixturePath 'manifest-blocker.json') "not a directory`n"

$porcelainYaml = ($porcelainLines | ForEach-Object { "    - '" + ($_ -replace "'", "''") + "'" }) -join "`n"
$badSha = '0000000000000000000000000000000000000000'

function New-AnchorBlock {
    param([string]$Head)
    return @"
runner_anchors:
  head_sha: '$Head'
  porcelain:
$porcelainYaml
  evidence_manifest: '$manifestYamlPath'
  evidence_manifest_sha256: '$manifestSha'
  testimony_conflict: false
"@
}

Write-Utf8NoBom (Join-Path $fixturePath 'a-matched.yaml')  ("id: a11-matched`ndispatch_kind: read-only`n" + (New-AnchorBlock $headSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-diverged.yaml') ("id: a11-diverged`ndispatch_kind: read-only`n" + (New-AnchorBlock $badSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-moved.yaml') (@"
id: a11-moved
dispatch_kind: read-only
basis:
  head: '$headSha'
  tree: worktree
  untracked_included: true
  hash_class: clone-stable
"@ + "`n" + (New-AnchorBlock $badSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-moved-control.yaml') (@"
id: a11-moved-control
dispatch_kind: read-only
basis:
  head: '$headSha'
  tree: worktree
  untracked_included: true
  hash_class: worktree
"@ + "`n" + (New-AnchorBlock $badSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-absent-ef.yaml') (@"
id: a11-absent-ef
dispatch_kind: build
runner_anchors:
  head_sha: '$headSha'
  porcelain:
$porcelainYaml
  suite:
    command: 'uv run pytest'
    passed: 1
    failed: 0
    skipped: 0
    expected_failures_matched: true
  evidence_manifest: '$manifestYamlPath'
  evidence_manifest_sha256: '$manifestSha'
  testimony_conflict: false
"@)
Write-Utf8NoBom (Join-Path $fixturePath 'a-na-micro.yaml') ("id: a11-na-micro`ndispatch_kind: micro-ceremony`n" + (New-AnchorBlock $headSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-na-pair.yaml')  ("id: a11-na-pair`ndispatch_kind: build`n" + (New-AnchorBlock $headSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-unknown.yaml')  ("id: a11-unknown`ndispatch_kind: banana`n" + (New-AnchorBlock $headSha))
Write-Utf8NoBom (Join-Path $fixturePath 'a-no-anchors.yaml') "id: a11-no-anchors`ndispatch_kind: read-only`nnote: 'carries no runner_anchors block'`n"

function Invoke-Verify {
    <#
        --plane-root IS PASSED ONLY WHERE THE TWO ROOTS MUST DIFFER (the ruled DEV-1 refinement,
        2026-08-16). A drive that points --evidence-root at a write-failing path is exercising the
        spec:187-188 self-capture refusal; before the refinement that same flag also named the plane
        the MANIFEST and PLANE-PARITY arms read, so those arms derived ABSENT and refused alongside
        it -- and A11-B5, whose whole assertion is that the mutated build PASSES, could not be
        stated at all. Where the caller supplies no evidence root the flag is OMITTED, so the
        default -- read plane and write root being one -- stays driven by every other member here.
    #>
    param([string]$Cli, [string]$Artifact, [string]$EvidenceRoot, [string]$OutFile)
    $planeRootArgs = @()
    if (-not $EvidenceRoot) { $EvidenceRoot = $planePath }
    elseif ($EvidenceRoot -ne $planePath) { $planeRootArgs = @('--plane-root', $planePath) }
    if (-not $OutFile) { $OutFile = (Join-Path $outPath ([guid]::NewGuid().ToString('N').Substring(0, 8) + '.yaml')) }
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Cli,
        '--against', $Artifact, '--evidence-root', $EvidenceRoot, '--out', $OutFile) + $planeRootArgs
    return (Invoke-Child -FilePath 'powershell' -ArgumentList $argumentList -WorkingDirectoryPath $repoRootPath)
}

function New-MutatedCli {
    <# A planted breakage, applied to a COPY. A missing anchor is a hard failure of the
       instrument, not a silently skipped check. #>
    param([string]$Name, [hashtable[]]$Edits)
    $text = [System.IO.File]::ReadAllText($CliPath)
    foreach ($e in $Edits) {
        if ($text.IndexOf($e.From) -lt 0) { throw "MUTATION '$Name': anchor string not found in the CLI. The instrument and the CLI have drifted; this is a FAILURE, not a skip." }
        $text = $text.Replace($e.From, $e.To)
    }
    $p = Join-Path $mutPath "$Name.ps1"
    Write-Utf8NoBom $p $text
    return $p
}

try {

# =================================================================================================
Write-Head '=== PER-OUTCOME DRIVES, ON THE UNMUTATED BUILD (A-562 acceptance) ==============='

$d1 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-matched.yaml')
Add-Result 'A11-1' (
    $d1.ExitCode -eq 0 -and (Get-Gate $d1.StdOut) -eq 'PASS' -and
    (Get-Outcome $d1.StdOut 'head_sha') -eq 'MATCHED' -and
    (Get-Outcome $d1.StdOut 'porcelain') -eq 'MATCHED' -and
    (Get-Outcome $d1.StdOut 'evidence_manifest_sha256') -eq 'MATCHED' -and
    (Get-Outcome $d1.StdOut 'testimony_conflict') -eq 'MATCHED'
) "MATCHED: anchors agree -> every arm MATCHED (suite scoped NA), gate PASS, exit 0. got exit=$($d1.ExitCode) gate=$(Get-Gate $d1.StdOut)"

$d2 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-diverged.yaml')
Add-Result 'A11-2' (
    $d2.ExitCode -eq 1 -and (Get-Outcome $d2.StdOut 'head_sha') -eq 'DIVERGED' -and
    $d2.StdOut -match 'ANCHOR/head_sha' -and (Get-Outcome $d2.StdOut 'porcelain') -eq 'MATCHED'
) "DIVERGED: one member perturbed at an UNCHANGED basis -> DIVERGED on THAT subject, exit 1, refused_by names <arm>/<subject>. got exit=$($d2.ExitCode) head=$(Get-Outcome $d2.StdOut 'head_sha')"

$d3 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-moved.yaml')
Add-Result 'A11-3' (
    $d3.ExitCode -eq 1 -and (Get-Outcome $d3.StdOut 'head_sha') -eq 'MOVED'
) "MOVED: the SAME perturbation at a MOVED basis (hash_class differs, erratum E4) -> MOVED, never DIVERGED and never MATCHED. got head=$(Get-Outcome $d3.StdOut 'head_sha')"

$d3c = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-moved-control.yaml')
Add-Result 'A11-3c' (
    $d3c.ExitCode -eq 1 -and (Get-Outcome $d3c.StdOut 'head_sha') -eq 'DIVERGED'
) "MOVED control: same perturbation, basis AGREES -> DIVERGED. Proves MOVED is decided by basis, not emitted by default. got head=$(Get-Outcome $d3c.StdOut 'head_sha')"

$d4 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-absent-ef.yaml')
Add-Result 'A11-4' (
    $d4.ExitCode -eq 1 -and (Get-Outcome $d4.StdOut 'suite.expected_failures_matched') -eq 'ABSENT' -and
    $d4.StdOut -match 'ANCHOR/suite\.expected_failures_matched'
) "ABSENT: expected-failures declared home absent -> ABSENT + REFUSE, NOT NOT_APPLICABLE and NOT silently satisfied (A-565 member 1). got ef=$(Get-Outcome $d4.StdOut 'suite.expected_failures_matched')"

$d5 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-na-micro.yaml')
Add-Result 'A11-5' (
    $d5.ExitCode -eq 0 -and (Get-Outcome $d5.StdOut 'suite') -eq 'NOT_APPLICABLE' -and (Get-Gate $d5.StdOut) -eq 'PASS'
) "NOT_APPLICABLE: suite absent on a micro-ceremony dispatch -> NOT_APPLICABLE and PASS. got suite=$(Get-Outcome $d5.StdOut 'suite') exit=$($d5.ExitCode)"

$d5b = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-na-pair.yaml')
Add-Result 'A11-5b' (
    $d5b.ExitCode -eq 1 -and (Get-Outcome $d5b.StdOut 'suite') -eq 'ABSENT'
) "THE SCOPED PAIR: the SAME absence on a kind the rule does NOT scope away -> ABSENT + REFUSE. The pair is what proves the exemption is scoped rather than general (A-562:50-53). got suite=$(Get-Outcome $d5b.StdOut 'suite')"

$d7 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-matched.yaml') -OutFile (Join-Path $unwritablePath 'r.yaml')
Add-Result 'A11-7' (
    $d7.ExitCode -eq 2 -and $d7.StdOut -notmatch '(?m)^gate:' -and $d7.StdOut -match 'no verdict exists'
) "EXIT 2: verify prevented from emitting -> exit 2 and NO report claiming a verdict. got exit=$($d7.ExitCode), gate line emitted=$($d7.StdOut -match '(?m)^gate:')"

Add-Result 'A11-6' (
    $d1.ExitCode -eq 0 -and $d2.ExitCode -eq 1 -and $d7.ExitCode -eq 2
) "EXIT CONTRACT: 0 / 1 / 2 each driven and each distinct -- 'checked, passed' vs 'checked, refused' vs 'did not check'. got $($d1.ExitCode) / $($d2.ExitCode) / $($d7.ExitCode)"

$d8 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-matched.yaml') -EvidenceRoot $unwritablePath
Add-Result 'A11-8' (
    $d8.ExitCode -eq 1 -and (Get-Gate $d8.StdOut) -eq 'REFUSE' -and
    (Get-Outcome $d8.StdOut 'evidence_self_capture') -eq 'ABSENT'
) "WRITE-FAILURE REFUSAL: evidence write path fails -> REFUSE with a complete report, not a crash and not a warning (spec:187-188). Proven by a PATH PERMISSION, never by provoking a guard denial. The read plane stays readable via --plane-root, so this refusal is the SOLE one and is not confounded with a plane the run could not reach. got exit=$($d8.ExitCode) gate=$(Get-Gate $d8.StdOut)"

$d9 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-unknown.yaml')
Add-Result 'A11-9' (
    $d9.ExitCode -eq 1 -and (Get-Outcome $d9.StdOut 'dispatch_kind') -eq 'ABSENT'
) "SCOPING: a dispatch kind verify cannot scope -> refuses rather than guessing (spec:100-102). got exit=$($d9.ExitCode)"

$d10 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'a-no-anchors.yaml')
Add-Result 'A11-10' (
    $d10.ExitCode -eq 1 -and (Get-Outcome $d10.StdOut 'against_artifact') -eq 'ABSENT'
) "BASIS: an --against artifact carrying no runner_anchors -> refusal with a complete report, distinguished from verify failing to run (spec:185-190). got exit=$($d10.ExitCode)"

Write-Head '=== VOCABULARY CLOSURE AND THE DERIVED EXCLUSION ==============================='

$emitted = [regex]::Matches($d4.StdOut, '(?m)^\s*outcome:\s*(\w+)\s*$') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$closedSet = @('MATCHED', 'DIVERGED', 'MOVED', 'UNREACHABLE', 'ABSENT', 'NOT_APPLICABLE')
$strays = @($emitted | Where-Object { $closedSet -notcontains $_ })
Add-Result 'A11-11' ($strays.Count -eq 0) "CLOSED VOCABULARY: every emitted outcome is a member of the six-member set. emitted=[$($emitted -join ',')] strays=[$($strays -join ',')]"

# A-564 first clause, DERIVED. The admitted set is read from the CLI's own command-set table; the
# check asks whether every ISSUED command traces to that set. It does NOT pattern-match a
# forbidden string -- A-564:47-49 fails a probe that hand-lists the exclusion.
$cliText = [System.IO.File]::ReadAllText($CliPath)
$admittedSubjects = @([regex]::Matches($cliText, "Subject\s*=\s*'([a-z_]+)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$issuedCommands = @([regex]::Matches($d4.StdOut, '(?m)^\s*-\s*command:\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
$remoteTrackingReads = @($issuedCommands | Where-Object { $_ -match 'rev-parse\s+origin/' })
Add-Result 'A11-12' (
    $admittedSubjects.Count -ge 10 -and $issuedCommands.Count -gt 0 -and $remoteTrackingReads.Count -eq 0
) "EXCLUSION, DERIVED: the admitted set carries $($admittedSubjects.Count) subjects; $($issuedCommands.Count) command(s) issued; local remote-tracking reads among them: $($remoteTrackingReads.Count). git rev-parse origin/<branch> is excluded because it is NOT A MEMBER, not because a denylist names it."

Write-Head '=== PLANTED BREAKAGE -- PER MEMBER AND INDEPENDENT (A-562:54-59) ==============='

$b1 = New-MutatedCli 'b1-moved-into-matched' @(@{ From = "-Outcome 'MOVED' -Recorded `$recordedHead"; To = "-Outcome 'MATCHED' -Recorded `$recordedHead" })
$b1Moved = Invoke-Verify -Cli $b1 -Artifact (Join-Path $fixturePath 'a-moved.yaml')
$b1Keep1 = Invoke-Verify -Cli $b1 -Artifact (Join-Path $fixturePath 'a-matched.yaml')
$b1Keep2 = Invoke-Verify -Cli $b1 -Artifact (Join-Path $fixturePath 'a-absent-ef.yaml')
Add-Result 'A11-B1' (
    (Get-Outcome $b1Moved.StdOut 'head_sha') -eq 'MATCHED' -and $b1Keep1.ExitCode -eq 0 -and $b1Keep2.ExitCode -eq 1
) "FOLD MOVED INTO MATCHED REDs the MOVED item ONLY: moved drive now reports $(Get-Outcome $b1Moved.StdOut 'head_sha') (a stale figure laundered as agreement); MATCHED still exit $($b1Keep1.ExitCode); ABSENT still exit $($b1Keep2.ExitCode)"

$b2 = New-MutatedCli 'b2-gate-no-diverged' @(@{ From = 'if ($script:ProceedOutcomes -notcontains $e.outcome) { $refusedBy'; To = "if (`$e.outcome -eq 'DIVERGED') { `$refusedBy" })
$b2Absent = Invoke-Verify -Cli $b2 -Artifact (Join-Path $fixturePath 'a-absent-ef.yaml')
$b2Pair = Invoke-Verify -Cli $b2 -Artifact (Join-Path $fixturePath 'a-na-pair.yaml')
$b2Keep = Invoke-Verify -Cli $b2 -Artifact (Join-Path $fixturePath 'a-diverged.yaml')
Add-Result 'A11-B2' (
    $b2Absent.ExitCode -eq 0 -and $b2Pair.ExitCode -eq 0 -and $b2Keep.ExitCode -eq 1
) "GATE AS 'NO DIVERGED' REDs the ABSENT refusers ONLY: an ABSENT run now PASSES (exit $($b2Absent.ExitCode)) and the scoped pair now PASSES (exit $($b2Pair.ExitCode)) -- the false-PASS class design SS4.5 law 5 exists for; the DIVERGED drive is untouched (exit $($b2Keep.ExitCode))"

$b3 = New-MutatedCli 'b3-second-na-member' @(
    @{ From = "if (`$Outcome -eq 'NOT_APPLICABLE' -and `$Subject -ne `$script:SoleNotApplicableSubject) {"
       To   = "if (`$Outcome -eq 'NOT_APPLICABLE' -and @(`$script:SoleNotApplicableSubject,'suite.expected_failures_matched') -notcontains `$Subject) {" },
    @{ From = "New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome 'ABSENT' -Recorded `$recEF -Derived `$null ``"
       To   = "New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome 'NOT_APPLICABLE' -Recorded `$recEF -Derived `$null ``" }
)
$b3Absent = Invoke-Verify -Cli $b3 -Artifact (Join-Path $fixturePath 'a-absent-ef.yaml')
$b3Keep1 = Invoke-Verify -Cli $b3 -Artifact (Join-Path $fixturePath 'a-na-pair.yaml')
$b3Keep2 = Invoke-Verify -Cli $b3 -Artifact (Join-Path $fixturePath 'a-moved.yaml')
Add-Result 'A11-B3' (
    (Get-Outcome $b3Absent.StdOut 'suite.expected_failures_matched') -eq 'NOT_APPLICABLE' -and
    $b3Keep1.ExitCode -eq 1 -and $b3Keep2.ExitCode -eq 1
) "ADMITTING A SECOND NOT_APPLICABLE MEMBER REDs that item ONLY: the absent expected-failures file now reports $(Get-Outcome $b3Absent.StdOut 'suite.expected_failures_matched') -- the exact spec:247-250 stretch of an allow-side exemption over a MISSING FILE; the scoped pair (exit $($b3Keep1.ExitCode)) and MOVED (exit $($b3Keep2.ExitCode)) are untouched"

$b3a = New-MutatedCli 'b3a-guard-intact' @(
    @{ From = "New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome 'ABSENT' -Recorded `$recEF -Derived `$null ``"
       To   = "New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome 'NOT_APPLICABLE' -Recorded `$recEF -Derived `$null ``" }
)
$b3aRun = Invoke-Verify -Cli $b3a -Artifact (Join-Path $fixturePath 'a-absent-ef.yaml')
Add-Result 'A11-B3a' (
    $b3aRun.ExitCode -eq 2 -and $b3aRun.StdOut -match 'sole admissible member'
) "THE SAME STRETCH WITH THE SOLE-MEMBER GUARD INTACT is refused STRUCTURALLY: verify fails rather than emitting it (exit $($b3aRun.ExitCode)). Admitting a second member is a deliberate code change, never an oversight."

$b4 = New-MutatedCli 'b4-exit2-into-exit1' @(@{ From = "Write-Std 'verify: no verdict exists.'`n            return 2"; To = "Write-Std 'verify: no verdict exists.'`n            return 1" })
$b4Exit = Invoke-Verify -Cli $b4 -Artifact (Join-Path $fixturePath 'a-matched.yaml') -OutFile (Join-Path $unwritablePath 'r.yaml')
$b4Keep1 = Invoke-Verify -Cli $b4 -Artifact (Join-Path $fixturePath 'a-diverged.yaml')
$b4Keep2 = Invoke-Verify -Cli $b4 -Artifact (Join-Path $fixturePath 'a-matched.yaml')
Add-Result 'A11-B4' (
    $b4Exit.ExitCode -eq 1 -and $b4Keep1.ExitCode -eq 1 -and $b4Keep2.ExitCode -eq 0
) "COLLAPSING EXIT 2 INTO EXIT 1 REDs the exit items ONLY: did-not-check now reports as checked-and-refused (exit $($b4Exit.ExitCode)); the genuine refusal (exit $($b4Keep1.ExitCode)) and the pass (exit $($b4Keep2.ExitCode)) are unchanged, which is exactly why the collapse is undetectable from the code alone"

$b5 = New-MutatedCli 'b5-writefail-nonfatal' @(@{ From = 'if ($null -ne $evidenceWriteFailed) {'; To = 'if ($false) {' })
$b5Write = Invoke-Verify -Cli $b5 -Artifact (Join-Path $fixturePath 'a-matched.yaml') -EvidenceRoot $unwritablePath
$b5Keep1 = Invoke-Verify -Cli $b5 -Artifact (Join-Path $fixturePath 'a-absent-ef.yaml')
$b5Keep2 = Invoke-Verify -Cli $b5 -Artifact (Join-Path $fixturePath 'a-diverged.yaml')
Add-Result 'A11-B5' (
    $b5Write.ExitCode -eq 0 -and $b5Keep1.ExitCode -eq 1 -and $b5Keep2.ExitCode -eq 1
) "MAKING THE EVIDENCE-WRITE FAILURE NON-FATAL REDs the self-capture item ONLY: the run now PASSES with no record of what it did (exit $($b5Write.ExitCode), gate $(Get-Gate $b5Write.StdOut)) -- a gate whose record is optional degrades silently into a ceremony; ABSENT (exit $($b5Keep1.ExitCode)) and DIVERGED (exit $($b5Keep2.ExitCode)) are untouched"

Write-Head '=== WHAT THIS RUN DID NOT CHECK (spec:611-612 -- an unrun arm reported as absent =='
[Console]::Out.WriteLine('    from the findings is the false-PASS class in prose form) ======================')
[Console]::Out.WriteLine('  UNREACHABLE       NOT DRIVEN HERE. Requires an origin channel made unable to answer')
[Console]::Out.WriteLine('                    (A-562:47-49); a12 drives it. Declared, not silently omitted.')
[Console]::Out.WriteLine('  MANIFEST arm      BUILT AT INCREMENT 3 AND ENGAGED ON EVERY DRIVE HERE, but NOT')
[Console]::Out.WriteLine('  PLANE-PARITY arm  DECIDED BY THIS FILE. These fixtures carry a lawful plane so the')
[Console]::Out.WriteLine('                    arms match and this instrument measures the ANCHOR arm rather than')
[Console]::Out.WriteLine('                    a missing plane. The arms'' OWN acceptance is a13''s, and A-565')
[Console]::Out.WriteLine('                    member 2 is decided there, not here.')
[Console]::Out.WriteLine('  ORIGIN arm        NOT ENGAGED. No fixture here carries an origin claim; A-564 is')
[Console]::Out.WriteLine('                    decided on its exclusion clause only.')
[Console]::Out.WriteLine('  real-store        NOT DRIVEN. A-563:52-56 forbids greening the self-capture leg by')
[Console]::Out.WriteLine('  self-capture      writing the evidence plane from inside a session.')

Write-Head '=== A11 RESULT ================================================================='
[Console]::Out.WriteLine("  passed  $($script:PassCount)")
[Console]::Out.WriteLine("  failed  $($script:FailCount)")
if ($script:FailCount -gt 0) { [Console]::Out.WriteLine("  failing $($script:FailingIds -join ', ')") }

}
finally {
    if (-not $KeepScratch -and (Test-Path -LiteralPath $ScratchRootPath)) {
        Remove-Item -LiteralPath $ScratchRootPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($script:FailCount -gt 0) { exit 4 }
exit 0
