# test-a12-verify-origin-arm.ps1 -- A12: mission verify, increment 2 (the ORIGIN-ATTESTATION arm)
# acceptance. Authority: REOPEN #43 (M-113 seam S1) against the
# SEALED bytes of docs/framework/mission-verify-spec.md (A3).
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
# THREE ADDITIONS BEYOND THE FIXTURES, ALL FORCED BY WHERE THIS INSTRUMENT MUST RUN FROM:
#   --library-path  is passed on every invocation. This file's drives run with their working
#                   directory inside a CONSTRUCTED SCRATCH REPOSITORY, because that is where the
#                   url.<base>.insteadOf rewriting lives that splits the two origin channels. The
#                   CLI resolves its sealed detector library from the WORKING DIRECTORY's repository
#                   root first and falls back only to its own script directory -- so a MUTATED COPY
#                   under the scratch mut/ directory resolved NEITHER, and the MANIFEST arm came
#                   back ABSENT on every planted-breakage drive. The flag is the ruled DEV-1
#                   refinement (2026-08-16) being consumed; it changes WHERE THE PATH COMES FROM and
#                   never what is loaded.
#   THE NORMATIVE SCHEMA is placed into each constructed repository, BY BYTE-VERIFIED COPY, before
#                   its seed commit. Get-ManifestSchemaPath joins the schema onto the resolved
#                   repository root and has NO script-relative fallback, so a run from a scratch
#                   repository reported schema_validity ABSENT no matter what --library-path
#                   supplied. THIS IS A THIRD COUPLING, FOUND BY THE INCREMENT-3 BUILDER BATTERY AND
#                   REGISTERED; it is cured here inside the fixture licence rather than by a third
#                   flag. The copy is hashed against its source and a mismatch THROWS -- an
#                   unverified copy would let these drives validate against a drifted document.
#   --plane-root    is NOT used here. No drive in this file needs a write-failing evidence root;
#                   that shape is a11's.
#
# PLACEMENT AND PROVENANCE, STATED FIRST BECAUSE IT DECIDES WHO MAY RUN THIS. IT WAS RULED
# OPEN-C: this instrument lands at tools/framework/tests/ and is OPERATOR-PLACED AND OPERATOR-RUN.
# tools/framework/tests is in the protected set (evidence-common.ps1:1008), so an agent can neither
# write nor run it there, and an instrument an agent placed or drove would be the agent grading
# itself. The builder session authored these bytes in its scratchpad and handed them over with
# their sha256. EVERY FIGURE THIS INSTRUMENT PRINTS IS THE OPERATOR'S -- the A5 discipline, whose
# seal entry states it plainly: "THE SESSION RAN NO SUITE AND CLAIMS NONE."
#
# WHAT THIS INSTRUMENT DECIDES. Per A-564, and per A-562's SIXTH member which a11 could not drive:
#   1  EXCLUSION, DERIVED     -- no derivation verify issues reads the local remote-tracking ref,
#                               established by reading the admitted spec:115-126 command set and
#                               checking issued commands against it. NO FORBIDDEN STRING IS NAMED
#                               ANYWHERE IN THIS FILE (A-564:46-49, :62).
#   2  TWO CHANNELS, MATCHED  -- both answer, agree with each other and with the claim; BOTH raw
#                               ref lines present in the report (spec:377-378, 412-413).
#   3  DISAGREEMENT, channels vs each other -- refuses, escalates, both raw outputs carried, and
#                               NO tiebreak is applied (spec:388-390).
#   4  DISAGREEMENT, channels agree vs claim -- refuses, and refused_by keeps this DISTINGUISHABLE
#                               from case 3 rather than merging them (spec:414-416).
#   5  UNREACHABLE            -- a channel made unable to answer yields UNREACHABLE, never ABSENT,
#                               refuses, and NO RETRY PRODUCES A VERDICT (A-562:52-54).
#   6  API CHANNEL UNAVAILABLE -- reported UNREACHABLE, never SKIPPED: the silence-as-consent shape
#                               spec:406-407 names and A-564:62-63 fails on.
#   7  CREDENTIAL DISCIPLINE  -- no secret bytes in report, evidence or printed command line;
#                               hash prefix only (spec:391-393). ASSERTED, NEVER PLANTED.
#   8  RESIDUAL / CEILING     -- the emitted residual states the MIDDLE-RUNG limit in the arm's own
#                               words and does not claim origin-side independence (spec:507-517).
#
# WHAT THIS INSTRUMENT DOES NOT DECIDE, stated so no reader infers more from a green run:
#   - A-562 is NOT discharged here. This instrument drives its SIXTH member (UNREACHABLE) only.
#     The other five were driven by a11. A discharge resting on two instruments needs both green
#     AT A STATED COMMON BASIS (spec:630-634); that is an operator act, not this file's claim.
#   - A-563 is NOT decided. Its shape rules quantify over EVERY arm entry and every executed row
#     of the command set; that is a separate assertion with its own instrument.
#   - A-565 / A-566 / A-567 / A-568 are untouched.
#   - The MANIFEST (spec 4.2) and PLANE-PARITY (spec 4.3) arms ARE BUILT and DO ENGAGE on every
#     drive here, because these fixtures now carry a lawful plane -- but this file DECIDES NOTHING
#     ABOUT THEM. Their acceptance is a13's. They are made to match so that the gate this file
#     reads reflects the ORIGIN arm and nothing else.
#   - THE TOP RUNG IS NOT DRIVEN AND CANNOT BE. Every channel here runs on the session's own host.
#     ORIGIN-SIDE ATTESTED (spec:497) is the rung at which the asserting party is not the party
#     being asked about; nothing in this file reaches it, and drive 8 exists to make sure the
#     product does not claim otherwise.
#
# ANCHOR BASIS: CONTENT- AND CONSTRUCTION-ANCHORED. It anchors to NO sealed digest. It MUTATES
# ONLY constructed fixtures, constructed scratch git repositories, and mutated CLI copies under a
# scratch root beneath $env:TEMP. The real repository is consulted READ-ONLY, and only by the LIVE
# leg (drive 2L), whose anchors are read at run time rather than baked in so the instrument does
# not go stale when the tree moves. Nothing is written, staged, hashed or run under
# tools/framework/** or .mission/evidence -- every CLI invocation is given an explicit
# --evidence-root inside the scratch root, so the real evidence store is never touched. The sealed
# library and the normative schema are READ (and the schema COPIED, hash-verified) and never
# written, staged, hashed in place or executed.
#
# INSTRUMENT LAWS: (a) pure ASCII source; (b) path variables carry a Path suffix;
# (c) every child process runs through a redirected System.Diagnostics.Process, so a native stderr
# byte can never surface as a PowerShell error record under PS 5.1.
#
# HOW THE TWO CHANNELS ARE CONTROLLED INDEPENDENTLY, AND WHAT THAT COSTS. The git channel is
# pointed at a constructed local repository through git's own `url.<base>.insteadOf` rewriting,
# while the artifact's recorded remote URL still names a host; the API channel is pointed at a
# COMPILED CONSOLE STUB placed first on PATH under the name the CLI resolves. Both channels are
# therefore deterministic, hermetic and offline. RESIDUAL, STATED RATHER THAN GLOSSED: a fixture
# proves the CODE PATH -- that a non-answering channel maps to UNREACHABLE, refuses, and is not
# retried into a verdict. It does NOT prove that every real-world network or authentication
# failure presents in that shape. Drive 2L is the live counterweight and is asserted, not skipped.
#
# PLANTED BREAKAGE IS PER MEMBER AND INDEPENDENT (A-564:59-61). Each mutation is applied to a COPY
# of the CLI in the scratch root; tools/mission-verify.ps1 is never modified. Each mutated run
# asserts BOTH that its own member REDs AND that the neighbouring members stay green.
# DRIVE 7 IS ASSERTED, NEVER PLANTED: planting a credential to prove redaction would create the
# exposure the rule exists to prevent. Where drive 7 needs a URL carrying userinfo it uses an
# obviously synthetic placeholder that is not a credential to anything, and says so on the line.
#
# EXIT CONTRACT (printed at run time): 0 = every check passed. 2 = anchor guard failed (the CLI
# not found at -CliPath, git unavailable, the repository root not derivable, the console stub
# not compilable, or the sealed library or normative schema not present; no check was decided).
# 4 = one or more checks failed. NON-UNIQUENESS DISCLOSED: exit 4 is also A5's, A9's, A10's and
# A11's failing exit; exit 2 is also A10's and A11's anchor-guard exit. Read the printed counts,
# not the code alone.
#
# REACH: this instrument decides whether increment 2 BEHAVES as the sealed spec specifies against
# constructed fixtures plus one live leg. It cannot decide whether the spec is right, it exercises
# no arm but ANCHOR and ORIGIN-ATTESTATION for acceptance purposes, and it does not drive the real
# evidence store.

#requires -Version 5.0
param(
    [string]$CliPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mission-verify.ps1'),
    [string]$ScratchRootPath = (Join-Path $env:TEMP ('a12-scratch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))),
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
    [Console]::Out.WriteLine(("  {0}  {1,-9} {2}" -f $verdict, $Id, $Detail))
}

function Write-Head { param([string]$Text) [Console]::Out.WriteLine(''); [Console]::Out.WriteLine($Text) }

function Invoke-Child {
    <# Redirected, so native stderr is data, never an error record. Honest exit code. #>
    param([string]$FilePath, [string[]]$ArgumentList, [string]$WorkingDirectoryPath)
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

function Get-RefusedBy {
    param([string]$ReportText)
    $out = @()
    $inBlock = $false
    foreach ($l in ($ReportText -split "`r?`n")) {
        if ($l -match '^refused_by:\s*\[\]\s*$') { return , @() }
        if ($l -match '^refused_by:\s*$') { $inBlock = $true; continue }
        if ($inBlock) {
            if ($l -match '^\s+-\s+(.+?)\s*$') { $out += $Matches[1].Trim("'") } else { break }
        }
    }
    return , $out
}

function Get-IssuedCommands {
    param([string]$ReportText)
    $out = @()
    foreach ($m in [regex]::Matches($ReportText, '(?m)^\s*-\s*command:\s*(.+?)\s*$')) {
        $v = $m.Groups[1].Value.Trim()
        if ($v.Length -ge 2 -and $v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1, $v.Length - 2) -replace "''", "'" }
        $out += $v
    }
    return , $out
}

function Get-ResidualsFor {
    <# Every residual belonging to an entry of the named arm. #>
    param([string]$ReportText, [string]$Arm)
    $out = @()
    $lines = $ReportText -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^\s*-?\s*arm:\s*" + [regex]::Escape($Arm) + "\s*$")) {
            for ($j = $i; $j -lt [Math]::Min($i + 12, $lines.Count); $j++) {
                if ($lines[$j] -match '^\s*residual:\s*(.+?)\s*$') { $out += $lines[$j]; break }
            }
        }
    }
    return , $out
}

# =================================================================================================
# ANCHOR GUARD -- exit 2 if any premise is missing; no check is decided on a broken anchor.
# =================================================================================================
Write-Head '=== A12 ANCHOR GUARD ==========================================================='

if (-not (Test-Path -LiteralPath $CliPath -PathType Leaf)) {
    [Console]::Out.WriteLine("  ANCHOR FAIL: no CLI at $CliPath")
    exit 2
}
$repoRootPath = Split-Path -Parent (Split-Path -Parent $CliPath)
if (-not (Test-Path -LiteralPath (Join-Path $repoRootPath '.mission\mission.yaml'))) {
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

# The two documents the plane arms need, composed from the repository root INSIDE this file so that
# no command line this instrument issues names protected territory. Checked by EXISTENCE here; the
# library is never hashed, copied or executed by this file, and the schema is copied only into
# constructed scratch repositories, hash-verified at the point of copy.
$libraryPath = Join-Path $repoRootPath 'tools\framework\hooks\lib\evidence-common.ps1'
$schemaSourcePath = Join-Path $repoRootPath 'docs\framework\evidence-manifest.schema.json'
if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: the sealed detector library is not present under the repository root')
    exit 2
}
if (-not (Test-Path -LiteralPath $schemaSourcePath -PathType Leaf)) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: the normative manifest schema is not present under the repository root')
    exit 2
}

$stubDirPath = Join-Path $ScratchRootPath 'stub'
$fixturePath = Join-Path $ScratchRootPath 'fx'
$outPath     = Join-Path $ScratchRootPath 'out'
$mutPath     = Join-Path $ScratchRootPath 'mut'
$planePath   = Join-Path $ScratchRootPath 'plane'
foreach ($d in @($stubDirPath, $fixturePath, $outPath, $mutPath, $planePath)) { [void][System.IO.Directory]::CreateDirectory($d) }

# The API channel stand-in. A COMPILED CONSOLE APPLICATION, because the CLI starts its children
# with UseShellExecute = $false and .NET resolves a bare tool name through PATH as an executable
# image -- a script file of the same name would simply not be found, and a check that cannot run
# is worse than one that fails.
$stubSource = @'
using System;
using System.IO;
public class Program {
    public static int Main(string[] argv) {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        File.AppendAllText(Path.Combine(dir, "stub-argv.txt"), String.Join(" ", argv) + "\n");
        string so = Path.Combine(dir, "stub-stdout.txt");
        string se = Path.Combine(dir, "stub-stderr.txt");
        string ec = Path.Combine(dir, "stub-exit.txt");
        if (File.Exists(so)) Console.Out.Write(File.ReadAllText(so));
        if (File.Exists(se)) Console.Error.Write(File.ReadAllText(se));
        int code = 0;
        if (File.Exists(ec)) Int32.TryParse(File.ReadAllText(ec).Trim(), out code);
        return code;
    }
}
'@
$stubExePath = Join-Path $stubDirPath 'gh.exe'
try { Add-Type -OutputType ConsoleApplication -OutputAssembly $stubExePath -TypeDefinition $stubSource }
catch {
    [Console]::Out.WriteLine("  ANCHOR FAIL: the API-channel console stub could not be compiled -- $($_.Exception.Message)")
    exit 2
}
if (-not (Test-Path -LiteralPath $stubExePath -PathType Leaf)) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: the API-channel console stub did not materialise')
    exit 2
}

[Console]::Out.WriteLine("  CLI            $CliPath")
[Console]::Out.WriteLine("  repo root      $repoRootPath")
[Console]::Out.WriteLine("  HEAD           $($gitProbe.StdOut.Trim())")
[Console]::Out.WriteLine("  scratch        $ScratchRootPath")
[Console]::Out.WriteLine("  api stub       $stubExePath")

try {

# =================================================================================================
# FIXTURES -- constructed scratch repositories, outside the real repository.
# =================================================================================================

function New-ScratchRepo {
    <#
        A real git repository, so `git ls-remote` has something to answer from.

        IT ALSO CARRIES THE NORMATIVE MANIFEST SCHEMA, placed BEFORE the seed commit so that the
        tree stays clean and the ANCHOR arm's porcelain subject is not perturbed by a fixture file.
        The CLI's Get-ManifestSchemaPath joins that document onto the repository root it RESOLVES
        FROM THE WORKING DIRECTORY, with no script-relative fallback -- so without this a run whose
        working directory is one of these repositories reports schema_validity ABSENT and refuses,
        which would red members that have nothing to do with the ORIGIN arm. THE COPY IS VERIFIED
        AGAINST ITS SOURCE: validating against a document that had drifted from the normative one
        would be worse than not validating at all.
    #>
    param([string]$RepoPath, [string]$SeedText)
    [void][System.IO.Directory]::CreateDirectory($RepoPath)
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('init', '--quiet') -WorkingDirectoryPath $RepoPath
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('symbolic-ref', 'HEAD', 'refs/heads/main') -WorkingDirectoryPath $RepoPath
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('config', 'user.email', 'a12@example.invalid') -WorkingDirectoryPath $RepoPath
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('config', 'user.name', 'a12-fixture') -WorkingDirectoryPath $RepoPath
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('config', 'commit.gpgsign', 'false') -WorkingDirectoryPath $RepoPath
    Write-Utf8NoBom (Join-Path $RepoPath 'seed.txt') $SeedText
    Write-Utf8NoBom (Join-Path $RepoPath '.mission\mission.yaml') "state: Fixture`n"
    $schemaDestPath = Join-Path $RepoPath 'docs\framework\evidence-manifest.schema.json'
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $schemaDestPath))
    Copy-Item -LiteralPath $schemaSourcePath -Destination $schemaDestPath -Force
    if ((Get-FileSha256 $schemaSourcePath) -ne (Get-FileSha256 $schemaDestPath)) {
        throw "FIXTURE: the normative schema copy at $schemaDestPath does not hash to its source. These drives would validate against a drifted document; that is a FAILURE, not a skip."
    }
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('add', '--all') -WorkingDirectoryPath $RepoPath
    $null = Invoke-Child -FilePath 'git' -ArgumentList @('commit', '--quiet', '-m', 'a12 fixture seed') -WorkingDirectoryPath $RepoPath
    $r = Invoke-Child -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD') -WorkingDirectoryPath $RepoPath
    if ($r.ExitCode -ne 0 -or $r.StdOut.Trim() -eq '') {
        throw "FIXTURE: scratch repository at $RepoPath has no resolvable HEAD. This is a FAILURE of the instrument's premises, not a skip."
    }
    return $r.StdOut.Trim()
}

# Two constructed origins with DIFFERENT tips. The git channel is pointed at one of them.
$originAPath = Join-Path $ScratchRootPath 'originA'
$originBPath = Join-Path $ScratchRootPath 'originB'
$shaA = New-ScratchRepo -RepoPath $originAPath -SeedText 'origin A'
$shaB = New-ScratchRepo -RepoPath $originBPath -SeedText 'origin B'
if ($shaA -eq $shaB) { throw 'FIXTURE: the two constructed origins have the same tip; the disagreement drives would be vacuous.' }

$fixtureRemoteUrl = 'https://github.com/fixture-owner/fixture-repo.git'

function New-WorkRepo {
    <#
        The repository the CLI is run in. Its recorded origin URL names a host (so the API channel
        composes an endpoint), while git's own `insteadOf` rewriting sends the git channel to a
        constructed local repository. That is what lets the two channels be driven apart.
        RewriteToPath empty means NO rewriting -- the git channel then fails to reach anything,
        which is the UNREACHABLE fixture.
    #>
    param([string]$WorkPath, [string]$RemoteUrl, [string]$RewriteToPath)
    $head = New-ScratchRepo -RepoPath $WorkPath -SeedText 'work'
    $cfgPath = Join-Path $WorkPath '.git\config'
    $cfg = [System.IO.File]::ReadAllText($cfgPath)
    # FORWARD SLASHES, DELIBERATELY. git reads a backslash in a config VALUE as the start of an
    # escape sequence, so a Windows path pasted in raw makes the whole config unparsable -- and a
    # repository whose config git refuses is one where `git rev-parse HEAD` fails too, which would
    # make this fixture test the ANCHOR arm's basis handling instead of the origin channel it is
    # aimed at. The fixture must break the CHANNEL, not the repository.
    $RemoteUrl = $RemoteUrl -replace '\\', '/'
    $cfg += "[remote `"origin`"]`n`turl = $RemoteUrl`n"
    if ($RewriteToPath) {
        $cfg += "[url `"$($RewriteToPath -replace '\\', '/')`"]`n`tinsteadOf = $RemoteUrl`n"
    }
    [System.IO.File]::WriteAllText($cfgPath, $cfg, (New-Object System.Text.UTF8Encoding($false)))
    return $head
}

$workPath      = Join-Path $ScratchRootPath 'work'        # git channel -> originA
$workNoNetPath = Join-Path $ScratchRootPath 'worknonet'   # git channel -> nothing reachable
$workCredPath  = Join-Path $ScratchRootPath 'workcred'    # remote URL carrying synthetic userinfo

$workHead      = New-WorkRepo -WorkPath $workPath      -RemoteUrl $fixtureRemoteUrl -RewriteToPath $originAPath
$workNoNetHead = New-WorkRepo -WorkPath $workNoNetPath -RemoteUrl (Join-Path $ScratchRootPath 'no-such-repo') -RewriteToPath ''
# DRIVE 7's fixture. The string below is a SYNTHETIC PLACEHOLDER and is not a credential to
# anything: it exists only so the userinfo scanner has something to find. No real secret is ever
# written by this instrument, and none is ever read.
$workCredHead  = New-WorkRepo -WorkPath $workCredPath  -RemoteUrl 'https://fixture-user:SYNTHETIC-NOT-A-REAL-SECRET@github.com/fixture-owner/fixture-repo.git' -RewriteToPath $originAPath

# THE EVIDENCE PLANE THE ARTIFACTS NAME (the increment-3 repair, SS 1.4.1). A plane root mirrors the
# two subpaths the SEALED detectors derive -- <root>/.mission-runtime/evidence/<id> and
# <root>/.mission/evidence/<id> -- because Get-EvidenceRuntimeDir and Get-EvidenceCommittedDir
# compute exactly those from the root they are given. The dispatch id is the manifest's PARENT
# DIRECTORY NAME, because that is how verify derives it. It lives OUTSIDE the repository and outside
# every constructed repository; the real evidence store is neither read nor written.
$planeDispatchId = 'd-a12'
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
$badSha = '0000000000000000000000000000000000000000'

function New-Artifact {
    <#
        A read-only dispatch artifact whose ANCHOR members all agree with the work repository, so
        the gate reflects the ORIGIN arm and nothing else. OriginTip empty means the artifact makes
        NO claim about origin.
    #>
    param([string]$Path, [string]$Head, [string]$OriginTip)
    $originLine = ''
    if ($OriginTip) { $originLine = "  origin_tip: '$OriginTip'`n" }
    Write-Utf8NoBom $Path (
        "id: a12`ndispatch_kind: read-only`nrunner_anchors:`n" +
        "  head_sha: '$Head'`n" +
        "  porcelain: []`n" +
        $originLine +
        "  evidence_manifest: '$manifestYamlPath'`n" +
        "  evidence_manifest_sha256: '$manifestSha'`n" +
        "  testimony_conflict: false`n"
    )
}

New-Artifact -Path (Join-Path $fixturePath 'claim-A.yaml')      -Head $workHead      -OriginTip $shaA
New-Artifact -Path (Join-Path $fixturePath 'claim-bad.yaml')    -Head $workHead      -OriginTip $badSha
New-Artifact -Path (Join-Path $fixturePath 'claim-none.yaml')   -Head $workHead      -OriginTip ''
New-Artifact -Path (Join-Path $fixturePath 'claim-nonet.yaml')  -Head $workNoNetHead -OriginTip $shaA
New-Artifact -Path (Join-Path $fixturePath 'claim-cred.yaml')   -Head $workCredHead  -OriginTip $shaA

function Set-ApiStub {
    <# What the API channel will answer on the next invocation. #>
    param([string]$Sha, [int]$ExitCode, [string]$StdErr)
    $body = ''
    if ($Sha) { $body = "{`"ref`":`"refs/heads/main`",`"object`":{`"sha`":`"$Sha`",`"type`":`"commit`"}}" }
    Write-Utf8NoBom (Join-Path $stubDirPath 'stub-stdout.txt') $body
    Write-Utf8NoBom (Join-Path $stubDirPath 'stub-stderr.txt') $StdErr
    Write-Utf8NoBom (Join-Path $stubDirPath 'stub-exit.txt') ([string]$ExitCode)
    # The argv log is NOT cleared between drives: it accumulates every invocation the CLI made of
    # the API channel across the whole run, which is what drive 1a asserts R3 over.
}

function Get-StubArgv {
    <#
        Comma-wrapped on BOTH returns. PowerShell unrolls a bare empty array on return, and a
        caller under StrictMode asking $result.Count of the resulting $null gets a crash rather
        than a zero -- which would turn "the API channel was never invoked" into a broken probe
        instead of a finding.
    #>
    $argvLogPath = Join-Path $stubDirPath 'stub-argv.txt'
    if (-not (Test-Path -LiteralPath $argvLogPath)) { return , @() }
    return , @([System.IO.File]::ReadAllLines($argvLogPath) | Where-Object { $_ -ne '' })
}

function Invoke-Verify {
    <#
        --library-path IS PASSED ON EVERY INVOCATION (the ruled DEV-1 refinement, 2026-08-16). These
        drives run with their working directory inside a CONSTRUCTED repository, and the CLI resolves
        its sealed detectors from the working directory's repository root first, falling back only to
        its own script directory -- which a mutated copy under mut/ does not satisfy either. Without
        the flag every planted-breakage drive here measured the import-failure path instead of the
        member it was aimed at. The flag names the SAME library the CLI would otherwise find.
    #>
    param([string]$Cli, [string]$Artifact, [string]$WorkingPath, [string[]]$Extra)
    $outFile = Join-Path $outPath ([guid]::NewGuid().ToString('N').Substring(0, 8) + '.yaml')
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Cli,
        '--against', $Artifact, '--evidence-root', $planePath, '--library-path', $libraryPath, '--out', $outFile)
    if ($Extra) { $argumentList += $Extra }
    if (-not $Cli) { throw 'INSTRUMENT: Invoke-Verify called without a CLI path.' }
    return (Invoke-Child -FilePath 'powershell' -ArgumentList $argumentList -WorkingDirectoryPath $WorkingPath)
}

function New-MutatedCli {
    <# A planted breakage, applied to a COPY. A missing anchor is a hard failure, not a skip. #>
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

# THE LIVE LEG RUNS BEFORE THE STUB IS PUT ON PATH, so it reaches the real tool.
Write-Head '=== DRIVE 2L -- THE LIVE LEG, ASSERTED IN BOTH DIRECTIONS ======================'
$liveBranch = (Invoke-Child -FilePath 'git' -ArgumentList @('rev-parse', '--abbrev-ref', 'HEAD') -WorkingDirectoryPath $repoRootPath).StdOut.Trim()
$liveLs = Invoke-Child -FilePath 'git' -ArgumentList @('ls-remote', 'origin', "refs/heads/$liveBranch") -WorkingDirectoryPath $repoRootPath
$liveTip = $null
if ($liveLs.ExitCode -eq 0) {
    $m = [regex]::Match($liveLs.StdOut, '(?m)^([0-9a-f]{40})\s')
    if ($m.Success) { $liveTip = $m.Groups[1].Value }
}
$liveHead = (Invoke-Child -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD') -WorkingDirectoryPath $repoRootPath).StdOut.Trim()
$livePorc = @((Invoke-Child -FilePath 'git' -ArgumentList @('status', '--porcelain=v1') -WorkingDirectoryPath $repoRootPath).StdOut -split "`r?`n" | Where-Object { $_ -ne '' })
$livePorcYaml = ''
if ($livePorc.Count -gt 0) { $livePorcYaml = ($livePorc | ForEach-Object { "    - '" + ($_ -replace "'", "''") + "'" }) -join "`n" }
$liveArtifactPath = Join-Path $fixturePath 'live.yaml'
$liveClaim = $liveTip
if (-not $liveClaim) { $liveClaim = $badSha }
Write-Utf8NoBom $liveArtifactPath (
    "id: a12-live`ndispatch_kind: read-only`nrunner_anchors:`n" +
    "  head_sha: '$liveHead'`n" +
    $(if ($livePorc.Count -gt 0) { "  porcelain:`n$livePorcYaml`n" } else { "  porcelain: []`n" }) +
    "  origin_tip: '$liveClaim'`n" +
    "  evidence_manifest: '$manifestYamlPath'`n" +
    "  evidence_manifest_sha256: '$manifestSha'`n" +
    "  testimony_conflict: false`n"
)
$dLive = Invoke-Verify -Cli $CliPath -Artifact $liveArtifactPath -WorkingPath $repoRootPath
if ($liveTip) {
    Add-Result 'A12-2L' (
        (Get-Outcome $dLive.StdOut 'origin_git') -eq 'MATCHED' -and
        (Get-Outcome $dLive.StdOut 'origin_api') -eq 'MATCHED' -and
        (Get-Outcome $dLive.StdOut 'origin_tip') -eq 'MATCHED'
    ) "LIVE: the real origin answered on BOTH real channels and both agree with a live-derived claim. git=$(Get-Outcome $dLive.StdOut 'origin_git') api=$(Get-Outcome $dLive.StdOut 'origin_api') tip=$(Get-Outcome $dLive.StdOut 'origin_tip')"
}
else {
    Add-Result 'A12-2L' (
        (Get-Outcome $dLive.StdOut 'origin_git') -eq 'UNREACHABLE' -and
        (Get-Outcome $dLive.StdOut 'origin_tip') -eq 'UNREACHABLE'
    ) "LIVE: the real origin could NOT be reached from this host, so the arm must report UNREACHABLE -- never a skip and never a verdict. git=$(Get-Outcome $dLive.StdOut 'origin_git') tip=$(Get-Outcome $dLive.StdOut 'origin_tip')"
}

# From here on the API channel is the stub.
$env:PATH = $stubDirPath + ';' + $env:PATH

# =================================================================================================
Write-Head '=== PER-MEMBER DRIVES, ON THE UNMUTATED BUILD (A-564 acceptance) ==============='

Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$d2 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
$d2Commands = Get-IssuedCommands $d2.StdOut
$d2RawGit = ($d2.StdOut -match [regex]::Escape("$shaA`trefs/heads/main")) -or ($d2.StdOut -match ([regex]::Escape($shaA) + '\s+refs/heads/main'))
$d2RawApi = ($d2.StdOut -match ('"sha":"' + [regex]::Escape($shaA) + '"'))
Add-Result 'A12-2' (
    $d2.ExitCode -eq 0 -and (Get-Gate $d2.StdOut) -eq 'PASS' -and
    (Get-Outcome $d2.StdOut 'origin_git') -eq 'MATCHED' -and
    (Get-Outcome $d2.StdOut 'origin_api') -eq 'MATCHED' -and
    (Get-Outcome $d2.StdOut 'origin_tip') -eq 'MATCHED' -and
    $d2RawGit -and $d2RawApi
) "TWO CHANNELS MATCHED: both answered, agree with each other and with the claim; gate PASS, exit 0; BOTH raw ref lines present in the report (git raw=$d2RawGit api raw=$d2RawApi)"

Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$d3 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
$d3Refused = Get-RefusedBy $d3.StdOut
$d3RawBoth = ($d3.StdOut -match ([regex]::Escape($shaA) + '\s+refs/heads/main')) -and ($d3.StdOut -match ('"sha":"' + [regex]::Escape($shaB) + '"'))
Add-Result 'A12-3' (
    $d3.ExitCode -eq 1 -and (Get-Gate $d3.StdOut) -eq 'REFUSE' -and
    (Get-Outcome $d3.StdOut 'origin_tip.channels') -eq 'DIVERGED' -and
    $d3RawBoth
) "DISAGREEMENT, CHANNELS vs EACH OTHER: refuses and escalates with BOTH raw outputs and picks no winner. tip.channels=$(Get-Outcome $d3.StdOut 'origin_tip.channels') both-raw=$d3RawBoth refused_by=[$($d3Refused -join ', ')]"

# THE HARD PAIR, AND WHY IT HAS TO BE THIS PAIR. The two disagreement cases must stay apart even
# when the SAME channel entries refuse in both of them -- which is exactly what happens when the
# channels disagree and NEITHER of them matches the claim. A pair in which one case leaves a
# channel MATCHED would be told apart by that accident rather than by refused_by, and would let a
# merged implementation pass. Both runs below refuse both channel entries; the ONLY thing that can
# distinguish them is the comparison entry's subject.
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$d4a = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-bad.yaml') -WorkingPath $workPath
$d4aRefused = Get-RefusedBy $d4a.StdOut
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$d4b = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-bad.yaml') -WorkingPath $workPath
$d4bRefused = Get-RefusedBy $d4b.StdOut
$casesDistinct = (($d4aRefused -join '|') -ne ($d4bRefused -join '|'))
Add-Result 'A12-4' (
    $d4a.ExitCode -eq 1 -and $d4b.ExitCode -eq 1 -and
    (Get-Outcome $d4a.StdOut 'origin_tip.channels') -eq 'DIVERGED' -and
    (Get-Outcome $d4b.StdOut 'origin_tip') -eq 'DIVERGED' -and
    $casesDistinct
) "THE TWO DISAGREEMENT CASES STAY APART IN refused_by: channels-disagree-and-neither-matches gives [$($d4aRefused -join ', ')]; channels-agree-and-differ-from-the-claim gives [$($d4bRefused -join ', ')]. Both refuse the SAME two channel entries, so only the comparison subject can tell them apart. distinct=$casesDistinct"

Set-ApiStub -Sha '' -ExitCode 1 -StdErr 'dial tcp: lookup failed'
$d5 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-nonet.yaml') -WorkingPath $workNoNetPath
$d5GitIssued = @((Get-IssuedCommands $d5.StdOut) | Where-Object { $_ -match '\sls-remote\s' }).Count
Add-Result 'A12-5' (
    $d5.ExitCode -eq 1 -and
    (Get-Outcome $d5.StdOut 'origin_git') -eq 'UNREACHABLE' -and
    (Get-Outcome $d5.StdOut 'origin_api') -eq 'UNREACHABLE' -and
    (Get-Outcome $d5.StdOut 'origin_tip') -eq 'UNREACHABLE'
) "UNREACHABLE: a channel made unable to answer yields UNREACHABLE -- NOT ABSENT, NOT DIVERGED -- and refuses. git=$(Get-Outcome $d5.StdOut 'origin_git') api=$(Get-Outcome $d5.StdOut 'origin_api') tip=$(Get-Outcome $d5.StdOut 'origin_tip')"

Add-Result 'A12-5r' (
    $d5GitIssued -eq 1 -and (Get-Outcome $d5.StdOut 'origin_tip') -ne 'MATCHED'
) "NO RETRY PRODUCES A VERDICT: the git channel appears in the derivation record EXACTLY ONCE ($d5GitIssued), and the unreachable run produced no agreement verdict (tip=$(Get-Outcome $d5.StdOut 'origin_tip'))"

Set-ApiStub -Sha '' -ExitCode 1 -StdErr 'gh: connection refused'
$d6 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Add-Result 'A12-6' (
    $d6.ExitCode -eq 1 -and
    (Get-Outcome $d6.StdOut 'origin_api') -eq 'UNREACHABLE' -and
    (Get-Outcome $d6.StdOut 'origin_git') -eq 'MATCHED' -and
    (Get-Outcome $d6.StdOut 'origin_tip') -eq 'UNREACHABLE'
) "API UNAVAILABLE IS REPORTED, NEVER SKIPPED: the git channel answered AND agreed with the claim, and the run still REFUSES because the API channel was silent -- silence is not consent. api=$(Get-Outcome $d6.StdOut 'origin_api') git=$(Get-Outcome $d6.StdOut 'origin_git') tip=$(Get-Outcome $d6.StdOut 'origin_tip')"

Set-ApiStub -Sha '' -ExitCode 1 -StdErr 'gh: Not Found (HTTP 404)'
$d6b = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath -Extra @('--branch', 'nosuchbranch')
Add-Result 'A12-6b' (
    $d6b.ExitCode -eq 1 -and
    (Get-Outcome $d6b.StdOut 'origin_api') -eq 'ABSENT' -and
    (Get-Outcome $d6b.StdOut 'origin_git') -eq 'ABSENT'
) "ABSENT IS KEPT APART FROM UNREACHABLE, IN BOTH CHANNELS: a host answering 404 and an ls-remote exiting 0 with no ref line are ABSENT, not UNREACHABLE. api=$(Get-Outcome $d6b.StdOut 'origin_api') git=$(Get-Outcome $d6b.StdOut 'origin_git')"

Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$d0 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-none.yaml') -WorkingPath $workPath
Add-Result 'A12-0' (
    $d0.ExitCode -eq 0 -and (Get-Gate $d0.StdOut) -eq 'PASS' -and
    $d0.StdOut -match 'ORIGIN-ATTESTATION' -and $d0.StdOut -match 'DID NOT ENGAGE'
) "NO ORIGIN CLAIM: the arm does not engage, and SAYS SO in arms_not_run rather than passing silently or inventing an ABSENT the schema does not declare. exit=$($d0.ExitCode) gate=$(Get-Gate $d0.StdOut)"

Write-Head '=== THE DERIVED EXCLUSION (A-564:46-49) ========================================'

# The admitted set is read from the CLI's OWN TABLE. The process TOOLS are derived from that
# table too, so this probe names no command, no flag and no forbidden string of its own.
$cliText = [System.IO.File]::ReadAllText($CliPath)
$admittedRows = @()
foreach ($m in [regex]::Matches($cliText, "Subject\s*=\s*'(?<s>[a-z_]+)'[^\r\n]*?Kind\s*=\s*'(?<k>[a-z]+)'\s*;\s*Command\s*=\s*'(?<c>[^']*)'")) {
    $admittedRows += [pscustomobject]@{ Subject = $m.Groups['s'].Value; Kind = $m.Groups['k'].Value; Command = $m.Groups['c'].Value }
}
$processRows = @($admittedRows | Where-Object { $_.Kind -eq 'process' })
# A row whose command BEGINS with a placeholder names no tool -- spec:121's suite row is the whole
# command as a token. Including it would put a placeholder in the derived tool list, where it could
# never match anything and would quietly widen what this probe treats as out of scope.
$processTools = @($processRows | ForEach-Object { ($_.Command -split '\s+')[0] } |
    Where-Object { $_ -notmatch '^<' } | Select-Object -Unique)

function Test-IssuedIsAdmitted {
    <# An issued command is admitted iff it is an INSTANCE of some process row's template. #>
    param([string]$Command, $Rows)
    foreach ($r in $Rows) {
        $pattern = '^' + ([regex]::Escape($r.Command) -replace '<[A-Za-z_]+>', '\S+') + '$'
        if ($Command -match $pattern) { return $true }
    }
    return $false
}

function Get-OrphanCommands {
    <# Commands issued with a tool the admitted table names, but matching none of its templates. #>
    param([string[]]$Commands, $Rows, [string[]]$Tools)
    $orphans = @()
    foreach ($c in $Commands) {
        $tool = ($c -split '\s+')[0]
        if ($Tools -notcontains $tool) { continue }
        if (-not (Test-IssuedIsAdmitted -Command $c -Rows $Rows)) { $orphans += $c }
    }
    return , $orphans
}

$allIssued = @()
foreach ($r in @($d2, $d3, $d4a, $d4b, $d5, $d6, $d6b, $d0)) { $allIssued += (Get-IssuedCommands $r.StdOut) }
$orphans = Get-OrphanCommands -Commands $allIssued -Rows $processRows -Tools $processTools
Add-Result 'A12-1' (
    $admittedRows.Count -ge 10 -and $processRows.Count -ge 3 -and $allIssued.Count -gt 0 -and $orphans.Count -eq 0
) "EXCLUSION, DERIVED: $($admittedRows.Count) admitted rows, $($processRows.Count) of them process rows over tool(s) [$($processTools -join ',')]; $($allIssued.Count) command(s) issued across every drive; commands using an admitted tool but matching NO admitted template: $($orphans.Count). The local remote-tracking ref is unreachable from this program because it IS NOT A ROW -- this probe names no forbidden string."

$apiArgv = Get-StubArgv
$apiFlagged = @($apiArgv | Where-Object { $_ -match '(^|\s)(-i|--include)(\s|$)' })
Add-Result 'A12-1a' (
    $apiArgv.Count -gt 0 -and $apiFlagged.Count -eq 0
) "R3, ASSERTED OVER THE ACTUAL INVOCATION: the API channel was invoked $($apiArgv.Count) time(s) as recorded by the stub itself, and carried no response-header flag ($($apiFlagged.Count) offending). Headers can carry auth-adjacent material; this arm takes the ref payload only."

Write-Head '=== CREDENTIAL DISCIPLINE -- ASSERTED, NEVER PLANTED (spec:391-393) ============'

# Every report this run produced, plus every file the CLI wrote under the scratch plane root.
$allEmitted = @()
foreach ($r in @($dLive, $d2, $d3, $d4a, $d4b, $d5, $d6, $d6b, $d0)) { $allEmitted += $r.StdOut; $allEmitted += $r.StdErr }
foreach ($f in @(Get-ChildItem -LiteralPath $planePath -Recurse -File -ErrorAction SilentlyContinue)) {
    $allEmitted += [System.IO.File]::ReadAllText($f.FullName)
}
foreach ($f in @(Get-ChildItem -LiteralPath $outPath -File -ErrorAction SilentlyContinue)) {
    $allEmitted += [System.IO.File]::ReadAllText($f.FullName)
}
$userInfoHits = @($allEmitted | Where-Object { $_ -match 'https?://[^/@\s]*:[^/@\s]*@' })
Add-Result 'A12-7' (
    $userInfoHits.Count -eq 0 -and $allEmitted.Count -gt 0
) "NO SECRET BYTES ANYWHERE: $($allEmitted.Count) emitted stream(s) and written file(s) scanned -- reports, stderr, the --out files and everything the CLI wrote under its evidence root. URLs carrying userinfo found: $($userInfoHits.Count). Nothing was planted to produce this result."

Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$d7 = Invoke-Verify -Cli $CliPath -Artifact (Join-Path $fixturePath 'claim-cred.yaml') -WorkingPath $workCredPath
$d7Leaked = ($d7.StdOut + $d7.StdErr) -match 'SYNTHETIC-NOT-A-REAL-SECRET'
Add-Result 'A12-7b' (
    $d7.ExitCode -eq 2 -and $d7.StdOut -notmatch '(?m)^gate:' -and -not $d7Leaked
) "A REMOTE URL CARRYING USERINFO HALTS: exit $($d7.ExitCode), no gate line emitted, and the halt message reproduces none of the offending bytes (leaked=$d7Leaked). The placeholder in that fixture is synthetic and authenticates nothing."

Write-Head '=== THE CEILING, AS AN EMITTED RESIDUAL (A-564:57-58; spec:507-517) ============'

$originResiduals = Get-ResidualsFor -ReportText $d2.StdOut -Arm 'ORIGIN-ATTESTATION'
$statesMiddleRung = @($originResiduals | Where-Object { $_ -match 'MIDDLE RUNG' }).Count
$disclaimsIndependence = @($originResiduals | Where-Object { $_ -match 'does NOT make the observer independent of the observed' }).Count
$keepsOperatorFinal = @($originResiduals | Where-Object { $_ -match 'remains the final layer' }).Count
Add-Result 'A12-8' (
    $originResiduals.Count -ge 3 -and
    $statesMiddleRung -eq $originResiduals.Count -and
    $disclaimsIndependence -eq $originResiduals.Count -and
    $keepsOperatorFinal -eq $originResiduals.Count
) "RESIDUAL STATES THE MIDDLE-RUNG LIMIT IN THE ARM'S OWN WORDS: $($originResiduals.Count) ORIGIN residual(s); naming the middle rung $statesMiddleRung; explicitly refusing observer-independence $disclaimsIndependence; keeping operator browser confirmation as the final layer $keepsOperatorFinal. An arm claiming origin-side independence FAILS this."

Write-Head '=== PLANTED BREAKAGE -- PER MEMBER AND INDEPENDENT (A-564:59-61) ==============='

# --- 1a: a hand-assembled argument vector reaching for the local remote-tracking ref -------------
$m1a = New-MutatedCli 'm1a-handwritten-cache-read' @(
    @{ From = "            `$inv = Get-AdmittedProcessInvocation -Subject 'origin_git' -Tokens @{ branch = `$branch }"
       To   = "            `$inv = [pscustomobject]@{ FilePath = 'git'; ArgumentList = @('rev-parse', ('origin/' + `$branch)) }" }
)
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m1aRun = Invoke-Verify -Cli $m1a -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Add-Result 'A12-B1a' (
    $m1aRun.ExitCode -eq 2 -and $m1aRun.StdOut -notmatch '(?m)^gate:'
) "HAND-ASSEMBLING THE CACHE READ IS REFUSED STRUCTURALLY: the mutated CLI cannot issue it at all -- exit $($m1aRun.ExitCode), no verdict emitted. The command is unissuable because it is not an instance of any admitted template."

# --- 1b: the derivation replaced by a hand-maintained denylist, and a read it does not name ------
$m1b = New-MutatedCli 'm1b-denylist-instead-of-derivation' @(
    @{ From = "            `$inv = Get-AdmittedProcessInvocation -Subject 'origin_git' -Tokens @{ branch = `$branch }"
       To   = "            `$inv = [pscustomobject]@{ FilePath = 'git'; ArgumentList = @('for-each-ref', ('refs/remotes/origin/' + `$branch)) }" },
    @{ From = "    `$pattern = '^' + ([regex]::Escape(`$row.Command) -replace '<[A-Za-z_]+>', '\S+') + '`$'`n    return (`$CommandText -match `$pattern)"
       To   = "    return (`$CommandText -notmatch 'rev-parse\s+origin/')" }
)
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m1bRun = Invoke-Verify -Cli $m1b -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
$m1bIssued = Get-IssuedCommands $m1bRun.StdOut
$m1bOrphans = Get-OrphanCommands -Commands $m1bIssued -Rows $processRows -Tools $processTools
$m1bDenylistSawNothing = (@($m1bIssued | Where-Object { $_ -match 'rev-parse\s+origin/' }).Count -eq 0)
Add-Result 'A12-B1b' (
    $m1bRun.ExitCode -ne 2 -and $m1bOrphans.Count -gt 0 -and $m1bDenylistSawNothing
) "A HAND-MAINTAINED DENYLIST FAILS THE ASSERTION, DEMONSTRATED RATHER THAN ASSERTED: with the derivation replaced by a forbidden-string list, the CLI happily issued [$($m1bOrphans -join ' | ')] and emitted a report; the denylist matched nothing ($m1bDenylistSawNothing) because it names one spelling of the defect and that read is another. The DERIVED probe caught it ($($m1bOrphans.Count) orphan(s))."

# --- 2: one channel's raw output dropped ---------------------------------------------------------
$m2 = New-MutatedCli 'm2-drop-one-raw-output' @(
    @{ From = '    [void]$script:Derivations.Add($rec)'
       To   = "    if (`$Subject -ne 'origin_api') { [void]`$script:Derivations.Add(`$rec) }" }
)
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m2Run = Invoke-Verify -Cli $m2 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$m2Keep = Invoke-Verify -Cli $m2 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Add-Result 'A12-B2' (
    ($m2Run.StdOut -notmatch ('"sha":"' + [regex]::Escape($shaA) + '"')) -and
    (Get-Outcome $m2Keep.StdOut 'origin_tip.channels') -eq 'DIVERGED'
) "DROPPING ONE CHANNEL'S RAW OUTPUT REDs the two-channel item ONLY: the API channel's raw payload is gone from the report while the verdict still claims two channels; the channel-disagreement member is untouched ($(Get-Outcome $m2Keep.StdOut 'origin_tip.channels'))"

# --- 3: a tiebreak ------------------------------------------------------------------------------
$m3 = New-MutatedCli 'm3-tiebreak' @(
    @{ From = '    elseif ($gitState.Sha -ne $apiState.Sha) {'; To = '    elseif ($false) {' }
)
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$m3Run = Invoke-Verify -Cli $m3 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m3Keep = Invoke-Verify -Cli $m3 -Artifact (Join-Path $fixturePath 'claim-bad.yaml') -WorkingPath $workPath
Add-Result 'A12-B3' (
    (Get-Outcome $m3Run.StdOut 'origin_tip') -eq 'MATCHED' -and
    (Get-Outcome $m3Run.StdOut 'origin_tip.channels') -eq '<no-entry>' -and
    $m3Keep.ExitCode -eq 1
) "IMPLEMENTING A TIEBREAK REDs the disagreement item ONLY: with the channels disagreeing, the mutated CLI PREFERS one and reports the comparison as $(Get-Outcome $m3Run.StdOut 'origin_tip') -- the channel-disagreement finding has vanished from the report entirely ($(Get-Outcome $m3Run.StdOut 'origin_tip.channels')), which is the property the second channel exists for being destroyed. NOTE, so no reader over-reads the exit code: the per-channel entries still refuse on this build, so the GATE happens to hold; the finding is gone even though the gate is not, and it is the finding this member is about. The agree-vs-claim member is untouched (exit $($m3Keep.ExitCode))"

# --- 4: the two disagreement cases merged in refused_by -----------------------------------------
$m4 = New-MutatedCli 'm4-merge-refusal-cases' @(
    @{ From = '        $subject = $script:OriginChannelSubject'; To = '        $subject = $script:OriginClaimSubject' }
)
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$m4Chan = Invoke-Verify -Cli $m4 -Artifact (Join-Path $fixturePath 'claim-bad.yaml') -WorkingPath $workPath
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m4Claim = Invoke-Verify -Cli $m4 -Artifact (Join-Path $fixturePath 'claim-bad.yaml') -WorkingPath $workPath
$m4Merged = ((Get-RefusedBy $m4Chan.StdOut) -join '|') -eq ((Get-RefusedBy $m4Claim.StdOut) -join '|')
Add-Result 'A12-B4' (
    $m4Merged -and $m4Chan.ExitCode -eq 1 -and $m4Claim.ExitCode -eq 1
) "MERGING THE TWO CASES IN refused_by REDs the distinguishability item ONLY: both disagreement shapes now emit the SAME refused_by [$((Get-RefusedBy $m4Chan.StdOut) -join ', ')] (merged=$m4Merged), so a reader cannot tell a channel disagreement from a stale claim; both still refuse, which is exactly why the collapse is invisible from the gate alone"

# --- 5: a silent channel mapped to ABSENT --------------------------------------------------------
$m5 = New-MutatedCli 'm5-silent-into-absent' @(
    @{ From = "        New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject `$Subject -Outcome 'UNREACHABLE' -Recorded `$Claim -Derived `$null ``"
       To   = "        New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject `$Subject -Outcome 'ABSENT' -Recorded `$Claim -Derived `$null ``" },
    @{ From = "        `$outcome = 'UNREACHABLE'"; To = "        `$outcome = 'ABSENT'" }
)
Set-ApiStub -Sha '' -ExitCode 1 -StdErr 'dial tcp: lookup failed'
$m5Run = Invoke-Verify -Cli $m5 -Artifact (Join-Path $fixturePath 'claim-nonet.yaml') -WorkingPath $workNoNetPath
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$m5Keep1 = Invoke-Verify -Cli $m5 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m5Keep2 = Invoke-Verify -Cli $m5 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Add-Result 'A12-B5' (
    (Get-Outcome $m5Run.StdOut 'origin_git') -eq 'ABSENT' -and
    (Get-Outcome $m5Keep1.StdOut 'origin_tip.channels') -eq 'DIVERGED' -and
    $m5Keep2.ExitCode -eq 0
) "MAPPING A SILENT CHANNEL TO ABSENT REDs the UNREACHABLE item ONLY: an unreachable channel now reports $(Get-Outcome $m5Run.StdOut 'origin_git') -- the collapse spec:73-76 names, which reads a channel that could not be contacted as a fact about origin; the disagreement member ($(Get-Outcome $m5Keep1.StdOut 'origin_tip.channels')) and the MATCHED member (exit $($m5Keep2.ExitCode)) are untouched"

# --- 6: the API channel skipped when unavailable -------------------------------------------------
$m6 = New-MutatedCli 'm6-skip-unavailable-api' @(
    @{ From = "    New-OriginChannelEntry -Subject 'origin_api' -State `$apiState -Claim `$claim -Detector `$apiDetector -Ceiling (`$ceiling + `$exitLoad) -BasisMoved `$BasisMoved -MovedNote `$MovedNote"
       To   = "    if (`$apiState.Status -ne 'SILENT') { New-OriginChannelEntry -Subject 'origin_api' -State `$apiState -Claim `$claim -Detector `$apiDetector -Ceiling (`$ceiling + `$exitLoad) -BasisMoved `$BasisMoved -MovedNote `$MovedNote }" },
    @{ From = "    if (`$gitState.Status -eq 'SILENT' -or `$apiState.Status -eq 'SILENT') {"
       To   = "    if (`$gitState.Status -eq 'SILENT') {" },
    # A FAITHFUL "skip" has to remove the channel from the cross-channel comparison too. Without
    # this third edit the silent channel still diverges from the one that answered, and the run
    # refuses for a different reason -- which would let the mutation look harmless and would
    # green this member for the wrong reason.
    @{ From = "    elseif (`$gitState.Sha -ne `$apiState.Sha) {"
       To   = "    elseif (`$apiState.Status -eq 'ANSWERED' -and `$gitState.Sha -ne `$apiState.Sha) {" }
)
Set-ApiStub -Sha '' -ExitCode 1 -StdErr 'gh: connection refused'
$m6Run = Invoke-Verify -Cli $m6 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$m6Keep = Invoke-Verify -Cli $m6 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Add-Result 'A12-B6' (
    $m6Run.ExitCode -eq 0 -and (Get-Gate $m6Run.StdOut) -eq 'PASS' -and
    (Get-Outcome $m6Run.StdOut 'origin_api') -eq '<no-entry>' -and
    (Get-Outcome $m6Keep.StdOut 'origin_tip.channels') -eq 'DIVERGED'
) "SKIPPING THE UNAVAILABLE API CHANNEL REDs the never-skipped item ONLY: the silent channel vanishes from the report entirely ($(Get-Outcome $m6Run.StdOut 'origin_api')) and the run PASSES at exit $($m6Run.ExitCode) on ONE channel's word -- silence read as consent, the false-PASS shape spec:406-407 names; the disagreement member is untouched ($(Get-Outcome $m6Keep.StdOut 'origin_tip.channels'))"

# --- 8: the residual overclaimed ------------------------------------------------------------------
$m8 = New-MutatedCli 'm8-overclaim-residual' @(
    @{ From = 'it does NOT make the observer independent of the observed'
       To   = 'it MAKES the observer independent of the observed and constitutes origin-side attestation' }
)
Set-ApiStub -Sha $shaA -ExitCode 0 -StdErr ''
$m8Run = Invoke-Verify -Cli $m8 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
$m8Residuals = Get-ResidualsFor -ReportText $m8Run.StdOut -Arm 'ORIGIN-ATTESTATION'
$m8Disclaims = @($m8Residuals | Where-Object { $_ -match 'does NOT make the observer independent of the observed' }).Count
Set-ApiStub -Sha $shaB -ExitCode 0 -StdErr ''
$m8Keep = Invoke-Verify -Cli $m8 -Artifact (Join-Path $fixturePath 'claim-A.yaml') -WorkingPath $workPath
Add-Result 'A12-B8' (
    $m8Residuals.Count -ge 3 -and $m8Disclaims -eq 0 -and $m8Run.ExitCode -eq 0 -and
    (Get-Outcome $m8Keep.StdOut 'origin_tip.channels') -eq 'DIVERGED'
) "OVERCLAIMING THE RESIDUAL REDs the ladder item ONLY: $($m8Residuals.Count) ORIGIN residual(s) and NONE now refuses observer-independence ($m8Disclaims) -- a hook-captured ls-remote presented as origin-side proof, which is the overclaim class wearing the clothes of a security control; the gate still says PASS (exit $($m8Run.ExitCode)), which is precisely why no gate can catch this one; the disagreement member is untouched ($(Get-Outcome $m8Keep.StdOut 'origin_tip.channels'))"

Write-Head '=== WHAT THIS RUN DID NOT CHECK ================================================'
[Console]::Out.WriteLine('  (spec:611-612 -- an unrun arm reported as absent from the findings is the false-PASS')
[Console]::Out.WriteLine('   class in prose form. These are declared, not silently omitted.)')
[Console]::Out.WriteLine('  TOP RUNG          NOT DRIVEN AND NOT DRIVABLE HERE. Every channel in this file runs on')
[Console]::Out.WriteLine('                    the session host. ORIGIN-SIDE ATTESTED needs a party that is not the')
[Console]::Out.WriteLine('                    session host; spec 6.3 registers that companion item as NOT BUILT.')
[Console]::Out.WriteLine('  REAL NETWORK      PARTLY DRIVEN. Drive 2L uses the real channels; every other channel')
[Console]::Out.WriteLine('                    outcome is produced by a constructed fixture, which proves the CODE')
[Console]::Out.WriteLine('                    PATH and not that every real failure presents in that shape.')
[Console]::Out.WriteLine('  A-562             FIVE of its six members were driven by a11, NOT here. This file drives')
[Console]::Out.WriteLine('                    the sixth (UNREACHABLE). A discharge spanning two instruments needs')
[Console]::Out.WriteLine('                    both green at a STATED COMMON BASIS (spec:630-634) -- an operator act.')
[Console]::Out.WriteLine('  A-563             NOT DECIDED. Its quantifiers are a separate assertion.')
[Console]::Out.WriteLine('  MANIFEST arm      BUILT AT INCREMENT 3 AND ENGAGED ON EVERY DRIVE HERE, but NOT')
[Console]::Out.WriteLine('  PLANE-PARITY arm  DECIDED BY THIS FILE. These fixtures carry a lawful plane so the arms')
[Console]::Out.WriteLine('                    match and the gate reflects the ORIGIN arm. Their acceptance is a13''s.')
[Console]::Out.WriteLine('  SCHEMA COUPLING   REGISTERED, NOT CURED IN THE PRODUCT. Get-ManifestSchemaPath resolves')
[Console]::Out.WriteLine('                    the normative document from the WORKING DIRECTORY''s repository root')
[Console]::Out.WriteLine('                    with no script-relative fallback, so these constructed repositories')
[Console]::Out.WriteLine('                    each carry a hash-verified copy. That is a FIXTURE accommodating a')
[Console]::Out.WriteLine('                    product coupling, and it is reported rather than absorbed.')
[Console]::Out.WriteLine('  real-store        NOT DRIVEN. Every run here was given an explicit --evidence-root')
[Console]::Out.WriteLine('  self-capture      inside the scratch root; A-563:52-56 forbids greening the self-capture')
[Console]::Out.WriteLine('                    leg by writing the evidence plane from inside a session.')

Write-Head '=== A12 RESULT ================================================================='
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
