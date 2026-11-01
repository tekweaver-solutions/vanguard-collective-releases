# test-a13-verify-manifest-plane-arms.ps1 -- A13: mission verify, increment 3 (the MANIFEST and
# PLANE-PARITY arms) acceptance. Authority: the arm amendments and the
# DP-09 amendment (M-113 seam S1), against the SEALED bytes of
# docs/framework/mission-verify-spec.md (A3).
#
# PLACEMENT AND PROVENANCE, STATED FIRST BECAUSE IT DECIDES WHO MAY RUN THIS. It was ruled
# OPEN-C: this instrument lands at tools/framework/tests/ and is OPERATOR-PLACED AND OPERATOR-RUN.
# tools/framework/tests is in the protected set (evidence-common.ps1:1008), so an agent can neither
# write nor run it there, and an instrument an agent placed or drove would be the agent grading
# itself. The builder session authored these bytes in its scratchpad and handed them over with
# their sha256. EVERY FIGURE THIS INSTRUMENT PRINTS AT THE OPERATOR'S SITTING IS THE OPERATOR'S --
# the A5 discipline, whose seal entry states it plainly: "THE SESSION RAN NO SUITE AND CLAIMS NONE."
#
# WHAT THIS INSTRUMENT DECIDES. Per A-565's SECOND member, and per the arm properties spec 4.2 and
# 4.3 declare:
#   1  THE STATE LADDER          -- every state Get-EvidenceState derives is mapped and reported
#                                  with its VERBATIM reason string (spec:307).
#   2  GREW -> MOVED             -- the DP-09 amendment's clause. The ordinary between-turns state of a live
#                                  multi-turn dispatch REFUSES as MOVED, never as DIVERGED, and the
#                                  report shows GREW so the distinction survives the mapping.
#   3  NB-1, THE REQUIRED DRIVE  -- a manifest that FAILS SCHEMA VALIDATION WHILE STILL DERIVING
#                                  FINALIZED is caught. Neither check subsumes the other
#                                  (spec:275-279). This is the member A-565 cannot green without.
#   4  hook_errors_present       -- reported on EVERY entry of the arm, not only when it refuses
#                                  (spec:286-289).
#   5  seq                       -- an ordering hint and never a key; no gap becomes a finding
#                                  (spec:294-300).
#   6  TWO SUBJECTS, SEPARATELY  -- committed-plane parity and stream-body integrity are reported
#                                  apart, because parity alone presented as "the plane is intact"
#                                  is the class claim law 4 forbids (spec:341-342).
#   7  THE PARITY ASYMMETRY      -- inherited and STATED: stream bodies are compared by existence
#                                  only inside the parity check, so a present-but-corrupt committed
#                                  body passes it (spec:329-340).
#   8  SECTION 5's ORDER         -- manifest state first; a non-FINALIZED manifest makes the
#                                  remaining subjects UNREADABLE rather than failing (spec:440-442).
#   9  NB-2, AT BOTH ENDS NOW    -- a _precompact entry with captured:false is a CAPTURE GAP on its
#                                  own subject and NEVER a stream-integrity mismatch (spec:445-449).
#                                  THIS FILE decides the rule on VERIFY's side of the call and edits
#                                  no sealed byte; the sealed function itself has since been cured,
#                                  which a14 decides. Both ends, two instruments, one rule.
#  10  DP-11's TWO NULLS         -- a library detector's exit_code is null WITH ITS OWN REASON, and
#                                  a child process's exit code is the real one, in the same report.
#
# WHAT THIS INSTRUMENT DOES NOT DECIDE, stated so no reader infers more from a green run:
#   - A-565 is NOT discharged here. This drives its SECOND member; its FIRST rides the ANCHOR arm
#     from increment 1. A discharge spanning increments needs both green at a STATED COMMON BASIS
#     (spec:630-634), which is an operator act and not this file's claim.
#   - A-563 is NOT decided. Its quantifiers are a separate assertion with its own instrument.
#   - A-566 is ADVANCED, NOT DISCHARGED HERE. Its CODE DELTA IS NOW APPLIED: the delta
#     RETIRED anchor 65865a0f / 76413 b and recorded EC27AB3A / 80479 b, both WORKTREE-CLASS.
#     The 189f811b / 46870 b figure these lines once carried
#     was a SUPERSEDED figure off an earlier spec section 10 (spec:673 now pins 3849bd6d / 105431 b) and was never this library's live anchor. This file
#     drives the ORDERING RULE verify obeys, which is a different thing from the sealed function's
#     own branching; a14 drives that. A-566's discharge SPANS BOTH at one stated common basis.
#   - A-562, A-564, A-567, A-568 are untouched.
#   - THE REAL EVIDENCE STORE IS NOT DRIVEN. Every CLI invocation is given an explicit
#     --evidence-root inside the scratch root; A-563:52-56 forbids greening the self-capture leg
#     by writing the evidence plane from inside a session.
#
# ANCHOR BASIS: CONTENT- AND CONSTRUCTION-ANCHORED. It anchors to NO sealed digest and moves none.
# It MUTATES ONLY constructed evidence-plane fixtures and mutated CLI copies under a scratch root
# beneath $env:TEMP. The real repository is consulted READ-ONLY, and its live HEAD and porcelain are
# read AT RUN TIME rather than baked in, so the instrument does not go stale when the tree moves.
# NOTHING under tools/framework/** or under the repository's own .mission/evidence or
# .mission-runtime/evidence is written, staged, hashed or run by this file.
#
# WHY THE CLI IS RUN FROM THE REAL REPOSITORY ROOT, AND WHY THAT IS NOT A LEAK. The CLI resolves its
# sealed detector library relative to the repository root it resolves from the working directory,
# so a run whose working directory is a constructed scratch repository would find no detectors and
# every drive would measure the import-failure path instead of the arms. The working directory is
# therefore the REAL repository -- which supplies the ANCHOR arm's live anchors and the sealed
# library, and NOTHING ELSE. The evidence plane every drive reads and writes is the scratch one
# named by --evidence-root, so the real store is neither read nor written at any point.
#
# INSTRUMENT LAWS: (a) pure ASCII source; (b) path variables carry a Path suffix;
# (c) every child process runs through a redirected System.Diagnostics.Process, so a native stderr
# byte can never surface as a PowerShell error record under PS 5.1.
#
# PLANTED BREAKAGE IS PER MEMBER AND INDEPENDENT (the A-561 form). Each mutation is applied to a
# COPY of the CLI in the scratch root; tools/mission-verify.ps1 is never modified. Each mutated run
# asserts BOTH that its own member REDs AND that a neighbouring member stays green.
#
# EXIT CONTRACT (printed at run time): 0 = every check passed. 2 = anchor guard failed (the CLI not
# found at -CliPath, git unavailable, the repository root not derivable, or the sealed detector
# library not present; no check was decided). 4 = one or more checks failed. NON-UNIQUENESS
# DISCLOSED: exit 4 is also A5's, A9's, A10's, A11's and A12's failing exit; exit 2 is also A10's,
# A11's and A12's anchor-guard exit. Read the printed counts, not the code alone.
#
# REACH: this instrument decides whether increment 3 BEHAVES as the sealed spec plus the DP-09 amendment specify,
# against constructed evidence-plane fixtures. It cannot decide whether the spec is right, it
# exercises no arm beyond the four now built, and it does not drive the real evidence store.

#requires -Version 5.0
param(
    [string]$CliPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'mission-verify.ps1'),
    [string]$ScratchRootPath = (Join-Path $env:TEMP ('a13-scratch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))),
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

# --- report readers ------------------------------------------------------------------------------

function Get-EntryBlock {
    <#
        The lines of the arm entry whose subject is $Subject, from its `- arm:` line to the next
        one. Comma-wrapped on both returns: a bare empty array unrolls to $null on return, and a
        caller under StrictMode asking .Count of that gets a crash instead of a zero -- which would
        turn "the entry is missing" into a broken probe rather than a finding.
    #>
    param([string]$ReportText, [string]$Subject)
    $lines = $ReportText -split "`r?`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^\s*subject:\s*' + [regex]::Escape($Subject) + '\s*$')) {
            for ($j = $i; $j -ge 0; $j--) {
                if ($lines[$j] -match '^\s*-\s*arm:\s*\S+\s*$') { $start = $j; break }
            }
            break
        }
    }
    if ($start -lt 0) { return , @() }
    $out = @($lines[$start])
    for ($k = $start + 1; $k -lt $lines.Count; $k++) {
        if ($lines[$k] -match '^\s*-\s*arm:\s*\S+\s*$') { break }
        if ($lines[$k] -match '^[a-z_]+:') { break }
        $out += $lines[$k]
    }
    return , $out
}

function Get-Outcome {
    param([string]$ReportText, [string]$Subject)
    $m = [regex]::Match($ReportText, "subject:\s*$([regex]::Escape($Subject))\s*\r?\n\s*outcome:\s*(\w+)")
    if ($m.Success) { return $m.Groups[1].Value }
    return '<no-entry>'
}

function Get-Field {
    <# One named field of one subject's entry, as text. '<none>' when the entry is absent. #>
    param([string]$ReportText, [string]$Subject, [string]$Field)
    foreach ($l in (Get-EntryBlock -ReportText $ReportText -Subject $Subject)) {
        if ($l -match ('^\s*' + [regex]::Escape($Field) + ':\s*(.*)$')) { return $Matches[1] }
    }
    return '<none>'
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

function Get-ArmSubjects {
    param([string]$ReportText, [string]$Arm)
    $out = @()
    $lines = $ReportText -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^\s*-\s*arm:\s*' + [regex]::Escape($Arm) + '\s*$')) {
            if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*subject:\s*(\S+)\s*$') { $out += $Matches[1] }
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

# =================================================================================================
# ANCHOR GUARD -- exit 2 if any premise is missing; no check is decided on a broken anchor.
# =================================================================================================
Write-Head '=== A13 ANCHOR GUARD ==========================================================='

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
# The detector library is a PREMISE of arms 4.2 and 4.3. Its absence would make every drive measure
# the CLI's import-failure path, which is a real path but not the one this instrument is aimed at.
# Checked by EXISTENCE ONLY: this file does not hash it, does not copy it, and does not read it.
$libRelPath = 'tools\framework\hooks\lib\evidence-common.ps1'
if (-not (Test-Path -LiteralPath (Join-Path $repoRootPath $libRelPath) -PathType Leaf)) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: the sealed detector library is not present under the repository root')
    exit 2
}

$planesPath   = Join-Path $ScratchRootPath 'planes'
$outPath      = Join-Path $ScratchRootPath 'out'
$mutPath      = Join-Path $ScratchRootPath 'mut'
$artifactPath = Join-Path $ScratchRootPath 'fx'
foreach ($d in @($planesPath, $outPath, $mutPath, $artifactPath)) { [void][System.IO.Directory]::CreateDirectory($d) }

$liveHead = $gitProbe.StdOut.Trim()
$livePorc = @((Invoke-Child -FilePath 'git' -ArgumentList @('status', '--porcelain=v1') -WorkingDirectoryPath $repoRootPath).StdOut -split "`r?`n" | Where-Object { $_ -ne '' })

[Console]::Out.WriteLine("  CLI            $CliPath")
[Console]::Out.WriteLine("  repo root      $repoRootPath")
[Console]::Out.WriteLine("  HEAD           $liveHead")
[Console]::Out.WriteLine("  porcelain      $($livePorc.Count) line(s), read live")
[Console]::Out.WriteLine("  scratch        $ScratchRootPath")

try {

# =================================================================================================
# FIXTURES -- constructed evidence planes, outside the real repository.
# =================================================================================================
#
# A plane root mirrors the two subpaths the SEALED detectors derive -- <root>/.mission-runtime/
# evidence/<id> and <root>/.mission/evidence/<id> -- because Get-EvidenceRuntimeDir and
# Get-EvidenceCommittedDir compute exactly those from the root they are given. The shape is the
# detectors' contract, not a choice this file made.

function New-Plane {
    param([string]$CaseName)
    $rootPath = Join-Path $planesPath $CaseName
    $id = 'd-' + $CaseName
    $runtimePath = Join-Path $rootPath (".mission-runtime\evidence\" + $id)
    $committedPath = Join-Path $rootPath (".mission\evidence\" + $id)
    [void][System.IO.Directory]::CreateDirectory($runtimePath)
    [void][System.IO.Directory]::CreateDirectory($committedPath)
    return [pscustomobject]@{
        Case = $CaseName; RootPath = $rootPath; Id = $id
        RuntimePath = $runtimePath; CommittedPath = $committedPath
        ManifestPath = (Join-Path $runtimePath 'manifest.json')
        LogPath = (Join-Path $runtimePath 'log.jsonl')
    }
}

function Get-LogText {
    param([int]$Count, [int]$Start = 1)
    $sb = New-Object System.Text.StringBuilder
    for ($i = $Start; $i -lt ($Start + $Count); $i++) {
        [void]$sb.Append('{"seq":' + $i + ',"tool":"Bash","command":"probe ' + $i + '"}')
        [void]$sb.Append("`n")
    }
    return $sb.ToString()
}

function New-ToolCallEntryJson {
    param([int]$Seq, [string]$OutText, [string]$ErrText)
    $rel = 'streams/{0:d6}.json' -f $Seq
    return ('{"ts":"2026-08-16T00:00:0' + ($Seq % 10) + '.100Z","tool":"Bash","command":"probe ' + $Seq + '"' +
            ',"exit_code":0,"stdout_sha256":"' + (Get-StringSha256 $OutText) + '"' +
            ',"stderr_sha256":"' + (Get-StringSha256 $ErrText) + '","path":"' + $rel + '"}')
}

function New-PrecompactEntryJson {
    param([int]$Index, [bool]$Captured)
    $rel = 'transcripts/precompact-{0:d3}.jsonl' -f $Index
    $sha = 'null'
    $code = 1
    if ($Captured) { $sha = '"' + (Get-StringSha256 ('transcript ' + $Index)) + '"'; $code = 0 }
    return ('{"ts":"2026-08-16T00:00:09.500Z","tool":"_precompact","command":"PreCompact auto"' +
            ',"exit_code":' + $code + ',"transcript_sha256":' + $sha +
            ',"captured":' + $(if ($Captured) { 'true' } else { 'false' }) + ',"path":"' + $rel + '"}')
}

function New-ManifestText {
    param(
        [string]$Id, [string]$LogSha, [long]$LogBytes, [int]$EntryCount, [string[]]$EntryJson,
        [bool]$Finalized, [bool]$StreamsCommitted, [bool]$HookErrors, [AllowNull()][string]$HookErrSha,
        [AllowNull()][string]$ExtraMember
    )
    # Hand-assembled rather than ConvertTo-Json'd, on purpose: this text is the SUBJECT of a schema
    # validation drive, and a serialiser that quietly normalises a single-element array or reorders
    # a member would make the fixture something other than what the drive says it is.
    $parts = @()
    $parts += '"schema_version":"1.3.0"'
    $parts += ('"dispatch_id":"' + $Id + '"')
    $parts += '"session_id":null'
    $parts += '"state":"finalized"'
    $parts += ('"entries":[' + ($EntryJson -join ',') + ']')
    $parts += ('"entry_count":' + $EntryCount)
    $parts += '"unparsable_lines":0'
    $parts += '"log_path":"log.jsonl"'
    $parts += ('"hook_errors_present":' + $(if ($HookErrors) { 'true' } else { 'false' }))
    $parts += ('"hook_errors_sha256":' + $(if ($HookErrSha) { '"' + $HookErrSha + '"' } else { 'null' }))
    $parts += ('"streams_committed":' + $(if ($StreamsCommitted) { 'true' } else { 'false' }))
    $parts += ('"log_sha256":"' + $LogSha + '"')
    $parts += ('"log_bytes_sealed":' + $LogBytes)
    $parts += '"finalize_count":1'
    $parts += '"created_at":"2026-08-16T00:00:00.000Z"'
    if ($Finalized) { $parts += '"finalized_at":"2026-08-16T00:00:01.000Z"' }
    if ($ExtraMember) { $parts += $ExtraMember }
    return ('{' + ($parts -join ',') + '}' + "`n")
}

function Write-StreamBodies {
    <#
        One file per declared streams/ entry, and EXACTLY that many: the sealed
        Get-EvidenceStreamIdentityFindings rides every integrity run and reports a count-mismatch
        when the two disagree, so a fixture off by one would red a member it was not aimed at.
    #>
    param([string]$RuntimePath, [int[]]$Seqs, [string]$OutText, [string]$ErrText)
    $streamsPath = Join-Path $RuntimePath 'streams'
    [void][System.IO.Directory]::CreateDirectory($streamsPath)
    foreach ($s in $Seqs) {
        Write-Utf8NoBom (Join-Path $streamsPath ('{0:d6}.json' -f $s)) ('{"stdout":"' + $OutText + '","stderr":"' + $ErrText + '"}')
    }
}

function Copy-ToCommittedPlane {
    <# The publish step the Stop hook performs, reproduced so parity has something to compare. #>
    param($Plane, [switch]$IncludeStreams, [switch]$IncludeHookErrors, [string[]]$SkipRelative)
    $skip = @($SkipRelative)
    foreach ($name in @('manifest.json', 'log.jsonl')) {
        $src = Join-Path $Plane.RuntimePath $name
        if ((Test-Path -LiteralPath $src -PathType Leaf) -and ($skip -notcontains $name)) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $Plane.CommittedPath $name) -Force
        }
    }
    if ($IncludeHookErrors) {
        $src = Join-Path $Plane.RuntimePath 'hook-errors.log'
        if ((Test-Path -LiteralPath $src -PathType Leaf) -and ($skip -notcontains 'hook-errors.log')) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $Plane.CommittedPath 'hook-errors.log') -Force
        }
    }
    if ($IncludeStreams) {
        $srcDir = Join-Path $Plane.RuntimePath 'streams'
        if (Test-Path -LiteralPath $srcDir) {
            $dstDir = Join-Path $Plane.CommittedPath 'streams'
            [void][System.IO.Directory]::CreateDirectory($dstDir)
            foreach ($f in @(Get-ChildItem -LiteralPath $srcDir -File)) {
                if ($skip -contains ('streams/' + $f.Name)) { continue }
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dstDir $f.Name) -Force
            }
        }
    }
}

function New-Artifact {
    <#
        A read-only dispatch artifact whose ANCHOR members all agree with the LIVE repository, so
        the gate reflects the MANIFEST and PLANE-PARITY arms and nothing else. It carries NO
        origin_tip, so the ORIGIN arm does not engage and no channel is contacted.
    #>
    param([string]$Name, [string]$ManifestPath)
    $porcYaml = "  porcelain: []`n"
    if ($livePorc.Count -gt 0) {
        $porcYaml = "  porcelain:`n" + (($livePorc | ForEach-Object { "    - '" + ($_ -replace "'", "''") + "'" }) -join "`n") + "`n"
    }
    $sha = ''
    if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) { $sha = Get-FileSha256 $ManifestPath }
    $p = Join-Path $artifactPath ($Name + '.yaml')
    Write-Utf8NoBom $p (
        "id: a13-$Name`ndispatch_kind: read-only`nrunner_anchors:`n" +
        "  head_sha: '$liveHead'`n" +
        $porcYaml +
        "  evidence_manifest: '$($ManifestPath -replace '\\', '/')'`n" +
        "  evidence_manifest_sha256: '$sha'`n" +
        "  testimony_conflict: false`n"
    )
    return $p
}

function Invoke-Verify {
    param([string]$Cli, [string]$Artifact, [string]$PlaneRootPath)
    $outFile = Join-Path $outPath ([guid]::NewGuid().ToString('N').Substring(0, 8) + '.yaml')
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Cli,
        '--against', $Artifact, '--evidence-root', $PlaneRootPath, '--out', $outFile)
    return (Invoke-Child -FilePath 'powershell' -ArgumentList $argumentList -WorkingDirectoryPath $repoRootPath)
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

# ---- the planes -----------------------------------------------------------------------------

# 1. ABSENT -- no log and no manifest, with the hook-errors.log hint beside them.
$pAbsent = New-Plane 'absent'
Write-Utf8NoBom (Join-Path $pAbsent.RuntimePath 'hook-errors.log') "2026-08-16T00:00:00Z first hook errored`n"

# 2. PARTIAL -- log present, manifest absent.
$pNoMan = New-Plane 'nomanifest'
Write-Utf8NoBom $pNoMan.LogPath (Get-LogText -Count 3)

# 3. PARTIAL -- manifest present but unparsable.
$pBadJson = New-Plane 'unparsable'
Write-Utf8NoBom $pBadJson.LogPath (Get-LogText -Count 3)
Write-Utf8NoBom $pBadJson.ManifestPath "{ this is not json`n"

# 4. PARTIAL -- manifest present without finalized_at. Its COMMITTED PLANE IS DELIBERATELY EMPTY,
#    so that a build which ran parity out of order would report DIVERGED and be caught (drive B6).
$pNoFinal = New-Plane 'nofinal'
Write-Utf8NoBom $pNoFinal.LogPath (Get-LogText -Count 3)
Write-Utf8NoBom $pNoFinal.ManifestPath (New-ManifestText -Id $pNoFinal.Id -LogSha (Get-FileSha256 $pNoFinal.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pNoFinal.LogPath).Length -EntryCount 3 -EntryJson @() `
    -Finalized $false -StreamsCommitted $false -HookErrors $false -HookErrSha $null -ExtraMember $null)

# 5. FINALIZED, schema-valid, committed plane complete -- THE POSITIVE CONTROL.
$pGood = New-Plane 'good'
Write-Utf8NoBom $pGood.LogPath (Get-LogText -Count 2)
Write-StreamBodies -RuntimePath $pGood.RuntimePath -Seqs @(1) -OutText 'hello' -ErrText ''
Write-Utf8NoBom $pGood.ManifestPath (New-ManifestText -Id $pGood.Id -LogSha (Get-FileSha256 $pGood.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pGood.LogPath).Length -EntryCount 1 `
    -EntryJson @((New-ToolCallEntryJson -Seq 1 -OutText 'hello' -ErrText '')) `
    -Finalized $true -StreamsCommitted $true -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pGood -IncludeStreams

# 6. GREW -- sealed over two lines, then the session kept working. THE E5-iv ARTIFACT.
$pGrew = New-Plane 'grew'
Write-Utf8NoBom $pGrew.LogPath (Get-LogText -Count 2)
$grewSha = Get-FileSha256 $pGrew.LogPath
$grewSealed = (Get-Item -LiteralPath $pGrew.LogPath).Length
Write-StreamBodies -RuntimePath $pGrew.RuntimePath -Seqs @(1) -OutText 'hello' -ErrText ''
Write-Utf8NoBom $pGrew.ManifestPath (New-ManifestText -Id $pGrew.Id -LogSha $grewSha -LogBytes $grewSealed `
    -EntryCount 1 -EntryJson @((New-ToolCallEntryJson -Seq 1 -OutText 'hello' -ErrText '')) `
    -Finalized $true -StreamsCommitted $true -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pGrew -IncludeStreams
# THE APPEND HAPPENS AFTER THE SEAL, which is what makes this GREW and not a differently-built log.
[System.IO.File]::AppendAllText($pGrew.LogPath, (Get-LogText -Count 3 -Start 3), (New-Object System.Text.UTF8Encoding($false)))

# 7. TAMPERED -- the log truncated below the sealed prefix.
$pTrunc = New-Plane 'truncated'
Write-Utf8NoBom $pTrunc.LogPath (Get-LogText -Count 4)
$truncSha = Get-FileSha256 $pTrunc.LogPath
$truncSealed = (Get-Item -LiteralPath $pTrunc.LogPath).Length
Write-Utf8NoBom $pTrunc.ManifestPath (New-ManifestText -Id $pTrunc.Id -LogSha $truncSha -LogBytes $truncSealed `
    -EntryCount 4 -EntryJson @() -Finalized $true -StreamsCommitted $false -HookErrors $false -HookErrSha $null -ExtraMember $null)
Write-Utf8NoBom $pTrunc.LogPath (Get-LogText -Count 1)

# 8. TAMPERED -- the sealed prefix mutated, at the SAME length, so nothing but re-derivation can
#    tell. This is the case that proves the discriminator is PREFIX RE-DERIVATION AND NOT LENGTH.
$pMut = New-Plane 'mutated'
Write-Utf8NoBom $pMut.LogPath (Get-LogText -Count 3)
$mutSha = Get-FileSha256 $pMut.LogPath
$mutSealed = (Get-Item -LiteralPath $pMut.LogPath).Length
Write-Utf8NoBom $pMut.ManifestPath (New-ManifestText -Id $pMut.Id -LogSha $mutSha -LogBytes $mutSealed `
    -EntryCount 3 -EntryJson @() -Finalized $true -StreamsCommitted $false -HookErrors $false -HookErrSha $null -ExtraMember $null)
Write-Utf8NoBom $pMut.LogPath ((Get-LogText -Count 3).Replace('probe 2', 'PROBE_2'))
if ((Get-Item -LiteralPath $pMut.LogPath).Length -ne $mutSealed) {
    throw 'FIXTURE: the mutated log changed length, so the truncation branch could decide it and the prefix-re-derivation member would be vacuous.'
}

# 9. NB-1 -- SCHEMA-INVALID WHILE STILL DERIVING FINALIZED. The entry is valid JSON carrying NONE of
#    the declared fields, which is spec:276-278's own example. log_sha256 matches the log on disk,
#    so state derivation says FINALIZED and only the schema axis can catch it.
$pNb1 = New-Plane 'nb1'
Write-Utf8NoBom $pNb1.LogPath (Get-LogText -Count 1)
Write-Utf8NoBom $pNb1.ManifestPath (New-ManifestText -Id $pNb1.Id -LogSha (Get-FileSha256 $pNb1.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pNb1.LogPath).Length -EntryCount 1 `
    -EntryJson @('{"note":"valid JSON, none of the declared fields"}') `
    -Finalized $true -StreamsCommitted $false -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pNb1

# 10. hook_errors_present TRUE on a FINALIZED manifest.
$pErr = New-Plane 'hookerr'
Write-Utf8NoBom $pErr.LogPath (Get-LogText -Count 2)
Write-Utf8NoBom (Join-Path $pErr.RuntimePath 'hook-errors.log') "2026-08-16T00:00:00Z a hook errored`n"
Write-Utf8NoBom $pErr.ManifestPath (New-ManifestText -Id $pErr.Id -LogSha (Get-FileSha256 $pErr.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pErr.LogPath).Length -EntryCount 0 -EntryJson @() `
    -Finalized $true -StreamsCommitted $false -HookErrors $true `
    -HookErrSha (Get-FileSha256 (Join-Path $pErr.RuntimePath 'hook-errors.log')) -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pErr -IncludeHookErrors

# 11. PARITY DIVERGED -- the manifest says a stream body was published; the canonical committed path
#     does not hold it. spec:323-327's demonstrated class, exactly.
$pGap = New-Plane 'parityhole'
Write-Utf8NoBom $pGap.LogPath (Get-LogText -Count 1)
Write-StreamBodies -RuntimePath $pGap.RuntimePath -Seqs @(1) -OutText 'hello' -ErrText ''
Write-Utf8NoBom $pGap.ManifestPath (New-ManifestText -Id $pGap.Id -LogSha (Get-FileSha256 $pGap.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pGap.LogPath).Length -EntryCount 1 `
    -EntryJson @((New-ToolCallEntryJson -Seq 1 -OutText 'hello' -ErrText '')) `
    -Finalized $true -StreamsCommitted $true -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pGap -IncludeStreams -SkipRelative @('streams/000001.json')

# 12. PARITY CLEAN, STREAM BODY CORRUPT -- the committed plane holds everything the manifest names,
#     so parity passes (its stream arm compares EXISTENCE ONLY); the runtime body no longer hashes
#     to its recorded stdout_sha256, so stream integrity catches it. The two subjects are separate
#     or this fixture is invisible.
$pCorrupt = New-Plane 'corruptbody'
Write-Utf8NoBom $pCorrupt.LogPath (Get-LogText -Count 1)
Write-StreamBodies -RuntimePath $pCorrupt.RuntimePath -Seqs @(1) -OutText 'hello' -ErrText ''
Write-Utf8NoBom $pCorrupt.ManifestPath (New-ManifestText -Id $pCorrupt.Id -LogSha (Get-FileSha256 $pCorrupt.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pCorrupt.LogPath).Length -EntryCount 1 `
    -EntryJson @((New-ToolCallEntryJson -Seq 1 -OutText 'hello' -ErrText '')) `
    -Finalized $true -StreamsCommitted $true -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pCorrupt -IncludeStreams
Write-Utf8NoBom (Join-Path $pCorrupt.RuntimePath 'streams\000001.json') '{"stdout":"TAMPERED","stderr":""}'

# 13. CAPTURE GAP -- a _precompact entry the manifest itself records as NOT captured, whose snapshot
#     file is absent. streams_committed is FALSE so the parity arm does not reach the entry, which
#     isolates the member: the ONLY thing that can report here is the stream/capture-gap boundary.
$pCapGap = New-Plane 'capturegap'
Write-Utf8NoBom $pCapGap.LogPath (Get-LogText -Count 1)
Write-Utf8NoBom $pCapGap.ManifestPath (New-ManifestText -Id $pCapGap.Id -LogSha (Get-FileSha256 $pCapGap.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pCapGap.LogPath).Length -EntryCount 1 `
    -EntryJson @((New-PrecompactEntryJson -Index 1 -Captured $false)) `
    -Finalized $true -StreamsCommitted $false -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pCapGap

# 14. SEQ GAP on an otherwise clean plane. The log's seq values jump; nothing may become a finding.
$pSeq = New-Plane 'seqgap'
Write-Utf8NoBom $pSeq.LogPath ('{"seq":1,"tool":"Bash","command":"probe 1"}' + "`n" + '{"seq":7,"tool":"Bash","command":"probe 7"}' + "`n")
Write-Utf8NoBom $pSeq.ManifestPath (New-ManifestText -Id $pSeq.Id -LogSha (Get-FileSha256 $pSeq.LogPath) `
    -LogBytes (Get-Item -LiteralPath $pSeq.LogPath).Length -EntryCount 0 -EntryJson @() `
    -Finalized $true -StreamsCommitted $false -HookErrors $false -HookErrSha $null -ExtraMember $null)
Copy-ToCommittedPlane -Plane $pSeq

$aAbsent  = New-Artifact 'absent'      $pAbsent.ManifestPath
$aNoMan   = New-Artifact 'nomanifest'  $pNoMan.ManifestPath
$aBadJson = New-Artifact 'unparsable'  $pBadJson.ManifestPath
$aNoFinal = New-Artifact 'nofinal'     $pNoFinal.ManifestPath
$aGood    = New-Artifact 'good'        $pGood.ManifestPath
$aGrew    = New-Artifact 'grew'        $pGrew.ManifestPath
$aTrunc   = New-Artifact 'truncated'   $pTrunc.ManifestPath
$aMut     = New-Artifact 'mutated'     $pMut.ManifestPath
$aNb1     = New-Artifact 'nb1'         $pNb1.ManifestPath
$aErr     = New-Artifact 'hookerr'     $pErr.ManifestPath
$aGap     = New-Artifact 'parityhole'  $pGap.ManifestPath
$aCorrupt = New-Artifact 'corruptbody' $pCorrupt.ManifestPath
$aCapGap  = New-Artifact 'capturegap'  $pCapGap.ManifestPath
$aSeq     = New-Artifact 'seqgap'      $pSeq.ManifestPath

# =================================================================================================
Write-Head '=== THE STATE LADDER, ON THE UNMUTATED BUILD (spec:307-310 + DP-09) ==========='

$rGood = Invoke-Verify -Cli $CliPath -Artifact $aGood -PlaneRootPath $pGood.RootPath
Add-Result 'A13-5' (
    $rGood.ExitCode -eq 0 -and (Get-Gate $rGood.StdOut) -eq 'PASS' -and
    (Get-Outcome $rGood.StdOut 'evidence_state') -eq 'MATCHED' -and
    (Get-Outcome $rGood.StdOut 'schema_validity') -eq 'MATCHED' -and
    (Get-Outcome $rGood.StdOut 'plane_parity') -eq 'MATCHED' -and
    (Get-Outcome $rGood.StdOut 'stream_integrity') -eq 'MATCHED' -and
    (Get-Outcome $rGood.StdOut 'capture_gap') -eq 'MATCHED'
) "POSITIVE CONTROL, UNMUTATED BUILD: a FINALIZED, schema-valid, parity-clean plane passes on every one of the five new subjects and the gate says PASS at exit $($rGood.ExitCode). state=$(Get-Outcome $rGood.StdOut 'evidence_state') schema=$(Get-Outcome $rGood.StdOut 'schema_validity') parity=$(Get-Outcome $rGood.StdOut 'plane_parity') stream=$(Get-Outcome $rGood.StdOut 'stream_integrity') gap=$(Get-Outcome $rGood.StdOut 'capture_gap')"

$rAbsent = Invoke-Verify -Cli $CliPath -Artifact $aAbsent -PlaneRootPath $pAbsent.RootPath
$absentDerived = Get-Field $rAbsent.StdOut 'evidence_state' 'derived'
Add-Result 'A13-1' (
    $rAbsent.ExitCode -eq 1 -and (Get-Outcome $rAbsent.StdOut 'evidence_state') -eq 'ABSENT' -and
    $absentDerived -match 'state=ABSENT' -and $absentDerived -match 'hook-errors\.log EXISTS'
) "ABSENT (spec:310), AND THE HINT RIDES THE VERBATIM REASON: no log and no manifest on disk maps to ABSENT and refuses; the detector's own hook-errors.log hint survives into the report rather than being summarised away. outcome=$(Get-Outcome $rAbsent.StdOut 'evidence_state')"

$rNoMan = Invoke-Verify -Cli $CliPath -Artifact $aNoMan -PlaneRootPath $pNoMan.RootPath
Add-Result 'A13-2' (
    (Get-Outcome $rNoMan.StdOut 'evidence_state') -eq 'DIVERGED' -and
    (Get-Field $rNoMan.StdOut 'evidence_state' 'derived') -match 'state=PARTIAL'
) "PARTIAL -> DIVERGED (spec:309), log present and manifest absent: outcome=$(Get-Outcome $rNoMan.StdOut 'evidence_state'), derived state carried verbatim"

$rBadJson = Invoke-Verify -Cli $CliPath -Artifact $aBadJson -PlaneRootPath $pBadJson.RootPath
Add-Result 'A13-3' (
    (Get-Outcome $rBadJson.StdOut 'evidence_state') -eq 'DIVERGED' -and
    (Get-Field $rBadJson.StdOut 'evidence_state' 'derived') -match 'unparsable'
) "PARTIAL -> DIVERGED, manifest present but unparsable: outcome=$(Get-Outcome $rBadJson.StdOut 'evidence_state')"

$rNoFinal = Invoke-Verify -Cli $CliPath -Artifact $aNoFinal -PlaneRootPath $pNoFinal.RootPath
Add-Result 'A13-4' (
    (Get-Outcome $rNoFinal.StdOut 'evidence_state') -eq 'DIVERGED' -and
    (Get-Field $rNoFinal.StdOut 'evidence_state' 'derived') -match 'without finalized_at'
) "PARTIAL -> DIVERGED, manifest without finalized_at: outcome=$(Get-Outcome $rNoFinal.StdOut 'evidence_state')"

$rGrew = Invoke-Verify -Cli $CliPath -Artifact $aGrew -PlaneRootPath $pGrew.RootPath
$grewDerived = Get-Field $rGrew.StdOut 'evidence_state' 'derived'
$grewResidual = Get-Field $rGrew.StdOut 'evidence_state' 'residual'
Add-Result 'A13-6' (
    $rGrew.ExitCode -eq 1 -and (Get-Gate $rGrew.StdOut) -eq 'REFUSE' -and
    (Get-Outcome $rGrew.StdOut 'evidence_state') -eq 'MOVED' -and
    $grewDerived -match 'state=GREW' -and
    $grewDerived -match 'VERIFIED append-extension' -and
    $grewResidual -match 'AM-449'
) "THE DP-09 CLAUSE, DRIVEN: a log grown by VERIFIED APPEND after its seal maps to MOVED, not DIVERGED and not MATCHED, and the report SHOWS GREW with its verbatim reason so the distinction survives the mapping (clause D). outcome=$(Get-Outcome $rGrew.StdOut 'evidence_state') gate=$(Get-Gate $rGrew.StdOut) exit=$($rGrew.ExitCode); residual names the amendment"

$rTrunc = Invoke-Verify -Cli $CliPath -Artifact $aTrunc -PlaneRootPath $pTrunc.RootPath
Add-Result 'A13-7' (
    (Get-Outcome $rTrunc.StdOut 'evidence_state') -eq 'DIVERGED' -and
    (Get-Field $rTrunc.StdOut 'evidence_state' 'derived') -match 'state=TAMPERED'
) "TAMPERED -> DIVERGED, log SHORTER than the sealed prefix. spec:309's clause is untouched by the DP-09 amendment and still fires: outcome=$(Get-Outcome $rTrunc.StdOut 'evidence_state')"

$rMut = Invoke-Verify -Cli $CliPath -Artifact $aMut -PlaneRootPath $pMut.RootPath
$mutDerived = Get-Field $rMut.StdOut 'evidence_state' 'derived'
Add-Result 'A13-8' (
    (Get-Outcome $rMut.StdOut 'evidence_state') -eq 'DIVERGED' -and
    $mutDerived -match 'state=TAMPERED' -and $mutDerived -match 'sealed prefix does not re-derive'
) "TAMPERED -> DIVERGED, SEALED PREFIX MUTATED AT UNCHANGED LENGTH: the discriminator is PREFIX RE-DERIVATION AND NOT LENGTH, so a same-length mutation cannot pass as growth. outcome=$(Get-Outcome $rMut.StdOut 'evidence_state')"

# =================================================================================================
Write-Head '=== NB-1 -- NEITHER CHECK SUBSUMES THE OTHER (spec:275-279; A-565 member 2) ===='

$rNb1 = Invoke-Verify -Cli $CliPath -Artifact $aNb1 -PlaneRootPath $pNb1.RootPath
$nb1Schema = Get-Field $rNb1.StdOut 'schema_validity' 'derived'
$nb1Refused = Get-RefusedBy $rNb1.StdOut
Add-Result 'A13-9' (
    $rNb1.ExitCode -eq 1 -and (Get-Gate $rNb1.StdOut) -eq 'REFUSE' -and
    (Get-Outcome $rNb1.StdOut 'evidence_state') -eq 'MATCHED' -and
    (Get-Outcome $rNb1.StdOut 'schema_validity') -eq 'DIVERGED' -and
    $nb1Schema -match 'first_failing_pointer=/entries/0' -and
    ($nb1Refused -contains 'MANIFEST/schema_validity')
) "THE REQUIRED DRIVE: a manifest that FAILS SCHEMA VALIDATION WHILE STILL DERIVING FINALIZED. State says MATCHED ($(Get-Outcome $rNb1.StdOut 'evidence_state')) and the schema axis alone refuses ($(Get-Outcome $rNb1.StdOut 'schema_validity')) at first_failing_pointer /entries/0 -- so a build running only the state derivation would have reported this artifact GOOD. refused_by=[$($nb1Refused -join ', ')]"

Add-Result 'A13-9p' (
    $nb1Schema -match 'matches NONE of the 3 declared variants'
) "AND THE POINTER IS USEFUL, NOT DECORATIVE: the oneOf failure names all three declared entry variants and why each rejected the instance, rather than naming one arbitrary branch. derived=$($nb1Schema.Substring(0, [Math]::Min(180, $nb1Schema.Length)))"

# =================================================================================================
Write-Head '=== hook_errors_present, seq, AND THE FOUR EMISSIONS (spec:286-308) ==========='

$rErr = Invoke-Verify -Cli $CliPath -Artifact $aErr -PlaneRootPath $pErr.RootPath
$errState = Get-Field $rErr.StdOut 'evidence_state' 'derived'
$errSchema = Get-Field $rErr.StdOut 'schema_validity' 'derived'
Add-Result 'A13-10' (
    $errState -match 'hook_errors_present=true' -and $errSchema -match 'hook_errors_present=true' -and
    $errState -match 'entry_count=0' -and $errSchema -match 'entry_count=0'
) "THE FLAG RIDES EVERY ENTRY OF THE ARM, NOT ONLY THE REFUSING ONES (spec:286-289): hook_errors_present=true and entry_count appear on the evidence_state entry AND on the schema_validity entry -- a consumer that never sees the flag cannot weigh it, and this manifest is FINALIZED, so without the flag it would read as complete"

Add-Result 'A13-10r' (
    (Get-Field $rErr.StdOut 'evidence_state' 'residual') -match 'MAY UNDERCOUNT REALITY'
) "AND THE FLAG IS EXPLAINED WHERE IT FIRES: the residual states that entry_count may undercount reality and that a finalized manifest must not be consumed as complete on the strength of being finalized"

$rSeq = Invoke-Verify -Cli $CliPath -Artifact $aSeq -PlaneRootPath $pSeq.RootPath
Add-Result 'A13-15' (
    (Get-Outcome $rSeq.StdOut 'evidence_state') -eq 'MATCHED' -and
    (Get-Field $rSeq.StdOut 'evidence_state' 'residual') -match 'ORDERING HINT AND NEVER A KEY' -and
    $rSeq.ExitCode -eq 0
) "A seq GAP IS NOT A FINDING (spec:294-300): a log whose seq values jump from 1 to 7 produces NO refusal -- exit $($rSeq.ExitCode) -- and the arm states in its own residual that seq is an ordering hint and never a key. The counter counts all log lines while only tool-call lines carry seq, so a gap and an interleaved snapshot are indistinguishable"

$goodStateDerived = Get-Field $rGood.StdOut 'evidence_state' 'derived'
Add-Result 'A13-E' (
    $goodStateDerived -match 'state=' -and $goodStateDerived -match 'reason=' -and
    $goodStateDerived -match 'hook_errors_present=' -and $goodStateDerived -match 'entry_count=' -and
    (Get-Field $rGood.StdOut 'schema_validity' 'derived') -match 'first_failing_pointer='
) "ALL FOUR EMISSIONS ARE PRESENT (spec:307-308): the derived state WITH ITS VERBATIM reason STRING, the schema verdict WITH ITS FIRST FAILING POINTER, hook_errors_present, and the declared entry_count"

# =================================================================================================
Write-Head '=== TWO SUBJECTS, REPORTED SEPARATELY (spec:341-342, 364-366) =================='

$rGap = Invoke-Verify -Cli $CliPath -Artifact $aGap -PlaneRootPath $pGap.RootPath
$gapParity = Get-Field $rGap.StdOut 'plane_parity' 'derived'
Add-Result 'A13-11' (
    $rGap.ExitCode -eq 1 -and (Get-Outcome $rGap.StdOut 'plane_parity') -eq 'DIVERGED' -and
    $gapParity -match 'MISSING from the committed plane'
) "THE NARROW DEMONSTRATED CLASS (spec:323-327): a committed artifact the runtime manifest SAYS WAS PUBLISHED and which is absent from its canonical path is DIVERGED, with the parity function's VERBATIM problems list carried in the report. parity=$(Get-Outcome $rGap.StdOut 'plane_parity')"

$rCorrupt = Invoke-Verify -Cli $CliPath -Artifact $aCorrupt -PlaneRootPath $pCorrupt.RootPath
$corruptStream = Get-Field $rCorrupt.StdOut 'stream_integrity' 'derived'
Add-Result 'A13-12' (
    (Get-Outcome $rCorrupt.StdOut 'plane_parity') -eq 'MATCHED' -and
    (Get-Outcome $rCorrupt.StdOut 'stream_integrity') -eq 'DIVERGED' -and
    $corruptStream -match 'stdout_sha256 mismatch'
) "THE ASYMMETRY, INHERITED AND PROVED (spec:329-342): a committed stream body that is PRESENT BUT CORRUPT PASSES THE PARITY CHECK ($(Get-Outcome $rCorrupt.StdOut 'plane_parity')) because parity compares stream bodies BY EXISTENCE ONLY, and the hash-bearing subject beside it catches it ($(Get-Outcome $rCorrupt.StdOut 'stream_integrity')). Reported as ONE subject, this fixture would be invisible -- which is the class claim law 4 forbids"

Add-Result 'A13-12a' (
    (Get-Field $rCorrupt.StdOut 'plane_parity' 'residual') -match 'EXISTENCE ONLY'
) "AND THE ASYMMETRY IS STATED RATHER THAN GLOSSED: the parity entry's own residual says its stream arm compares existence only and that a present-but-corrupt body passes it"

# =================================================================================================
Write-Head '=== SECTION 5 -- ORDER, AND THE CAPTURE GAP (spec:435-449) ====================='

$noFinalParity = Get-Outcome $rNoFinal.StdOut 'plane_parity'
$noFinalStream = Get-Outcome $rNoFinal.StdOut 'stream_integrity'
$noFinalGap    = Get-Outcome $rNoFinal.StdOut 'capture_gap'
Add-Result 'A13-13' (
    $noFinalParity -eq 'ABSENT' -and $noFinalStream -eq 'ABSENT' -and $noFinalGap -eq 'ABSENT' -and
    (Get-Field $rNoFinal.StdOut 'plane_parity' 'residual') -match 'UNREADABLE RATHER THAN FAILING'
) "SECTION 5, STEP 1 (spec:440-442): a manifest that is not FINALIZED makes the remaining subjects UNREADABLE RATHER THAN FAILING. All three PLANE-PARITY subjects report ABSENT and refuse; NONE reports DIVERGED, even though this plane's committed side is EMPTY and a parity run would have found problems. parity=$noFinalParity stream=$noFinalStream gap=$noFinalGap"

$rCapGap = Invoke-Verify -Cli $CliPath -Artifact $aCapGap -PlaneRootPath $pCapGap.RootPath
$capGapDerived = Get-Field $rCapGap.StdOut 'capture_gap' 'derived'
$capStreamDerived = Get-Field $rCapGap.StdOut 'stream_integrity' 'derived'
Add-Result 'A13-14' (
    (Get-Outcome $rCapGap.StdOut 'capture_gap') -eq 'ABSENT' -and
    (Get-Outcome $rCapGap.StdOut 'stream_integrity') -eq 'MATCHED' -and
    $capGapDerived -match 'capture_gap_entries=1' -and
    $capGapDerived -match 'transcripts/precompact-001\.jsonl' -and
    $capStreamDerived -match 'mismatches_verbatim=<none>' -and
    $rCapGap.StdOut -match 'transcript not captured \(captured is not true\)'
) "NB-2 IS NOW CURED AT SOURCE AND THE CONSUMER RULE STILL HOLDS (spec:437, 445-449): a _precompact entry with captured:false is a CAPTURE GAP on its OWN subject ($(Get-Outcome $rCapGap.StdOut 'capture_gap')) and NEVER a stream-integrity mismatch ($(Get-Outcome $rCapGap.StdOut 'stream_integrity')). WHAT THE CURE CHANGED, AND WHY THIS MEMBER MOVED: the sealed function NO LONGER MANUFACTURES 'stream file missing' for it, so the mismatch list is EMPTY AT SOURCE rather than emptied by verify -- mismatches_verbatim reads <none>. The gap now rides the library's own capture_gaps field, whose VERBATIM problem text reaches this report through the library row's raw derivation (spec:109-113). The capture_gap SUBJECT is derived from the MANIFEST by Get-CaptureGapPaths, which is now the ONLY route by which a gap reaches the report"

Add-Result 'A13-14n' (
    $capStreamDerived -match 'reclassified_as_capture_gap=<none>' -and
    $capGapDerived -match 'reclassified_from_stream_integrity=<none>' -and
    $capGapDerived -match 'capture_gap_entries=1'
) "AND THE RECLASSIFICATION IS NOW EMPTY WHILE THE GAP IS STILL REPORTED -- the visible consumer-side signature of the cure, and the reason this member had to be re-authored. Both reclassification fields read <none> because there is no longer a mismatch to reclassify, and capture_gap_entries is nevertheless still 1. The partition at mission-verify.ps1:2211-2233 is CORRECT, STILL RUNNING, AND NO LONGER REACHABLE for the captured:false class. THE TRAP THIS MEMBER EXISTS TO HOLD: mission verify NEVER READS capture_gaps, so anyone who later deletes that partition on the grounds that 'the library handles gaps now' would be deleting the wrong thing while the manifest-derived discrimination is what is actually load-bearing. REGISTERED as the capture_gaps-has-no-consumer follow-on; B5 below REDs if the load-bearing half goes"

# =================================================================================================
Write-Head '=== DP-11 -- THE TWO NULLS, IN ONE REPORT ======================================='

$hasProcExit = $rGood.StdOut -match '(?m)^\s+exit_code:\s*0\s*$'
$hasNullExit = $rGood.StdOut -match '(?m)^\s+exit_code:\s*~\s*$'
$hasReason   = $rGood.StdOut -match 'null BY CATEGORY, NOT BY CAPTURE GAP'
$hasE5Note   = $rGood.StdOut -match 'THIS IS NOT THE E5-i NULL'
Add-Result 'A13-16' (
    $hasProcExit -and $hasNullExit -and $hasReason -and $hasE5Note
) "TWO NULLS, NEVER CONFLATED, IN ONE REPORT: the git rows carry a REAL child-process exit code (present=$hasProcExit) and the library rows carry a NULL WITH ITS OWN REASON FIELD (present=$hasNullExit, reason=$hasReason) which says in terms that it is a CATEGORY FACT and not the E5-i capture gap (present=$hasE5Note). A fabricated 0 on a detector that never was a process would be an invented field"

# ASSIGN FIRST, NORMALISE SECOND. These readers comma-wrap their return so that an empty result
# survives as an empty array; @() around the CALL would collect that wrap as one item and yield a
# one-element list holding the whole array. The first drive battery caught this in three places.
$goodIssuedRaw = Get-IssuedCommands $rGood.StdOut
$goodIssued = @($goodIssuedRaw)
$libIssued = @($goodIssued | Where-Object { $_ -match '^(Get-EvidenceState|Test-EvidencePlaneParity|Test-EvidenceStreamIntegrity) -Root ' })
Add-Result 'A13-17' (
    $libIssued.Count -eq 3 -and $rGood.StdOut -match '"state":\s*"FINALIZED"' -and
    @($goodIssued | Where-Object { $_ -match 'evidence-manifest\.schema\.json' }).Count -eq 1
) "EVERY EXECUTED ROW OF THE spec:115-126 SET HAS ITS COMMAND AND ITS RAW OUTPUT BESIDE IT (spec:109-113): $($libIssued.Count) library invocations printed WITH THE PLANE ROOT THEY READ, the schema row printed with the manifest it validated, and the detectors' returned verdict objects serialised verbatim as the raw derivation"

$manifestSubjectsRaw = Get-ArmSubjects -ReportText $rGood.StdOut -Arm 'MANIFEST'
$paritySubjectsRaw = Get-ArmSubjects -ReportText $rGood.StdOut -Arm 'PLANE-PARITY'
$manifestSubjects = @($manifestSubjectsRaw)
$paritySubjects = @($paritySubjectsRaw)
$missingBits = 0
foreach ($s in ($manifestSubjects + $paritySubjects)) {
    if ((Get-Field $rGood.StdOut $s 'detector') -eq '<none>') { $missingBits++ }
    if ((Get-Field $rGood.StdOut $s 'residual') -eq '<none>') { $missingBits++ }
}
$dp10Count = 0
foreach ($s in $manifestSubjects) {
    if ((Get-Field $rGood.StdOut $s 'residual') -match 'MANIFEST COMPLETENESS IS NOT CALL COMPLETENESS') { $dp10Count++ }
}
Add-Result 'A13-18' (
    $manifestSubjects.Count -eq 2 -and $paritySubjects.Count -eq 3 -and
    $missingBits -eq 0 -and $dp10Count -eq $manifestSubjects.Count
) "EVERY NEW ARM ENTRY CARRIES BOTH DETECTOR AND RESIDUAL (spec:173-174): $($manifestSubjects.Count) MANIFEST subject(s) and $($paritySubjects.Count) PLANE-PARITY subject(s), $missingBits missing detector-or-residual fields; and the DP-10 manifest-completeness residual rides $dp10Count of $($manifestSubjects.Count) MANIFEST entries"

Add-Result 'A13-18d' (
    $rGood.StdOut -match 'DOES NOT REPORT WHAT THE PLANE NEVER SAW' -and
    $rGood.StdOut -match 'NO ENTRY, NO HOOK ERROR, AND NO' -and
    $rGood.StdOut -match 'recorded since cure D8'
) "THE DP-10 RESIDUAL SAYS THE TRUE THING ABOUT BOTH MEMBERS: E5-ii is NOT cured and a failed call leaves no entry, no hook error and no seq gap; E5-iii's guard denials ARE recorded since cure D8, complete by construction for calls the matcher reaches. A residual repeating 'until D8 lands' would be stale"

# =================================================================================================
Write-Head '=== PLANTED BREAKAGE -- PER MEMBER AND INDEPENDENT ============================='

# --- B1: the pre-DP-09 world -- GREW folded into DIVERGED --------------------------------------
$b1 = New-MutatedCli 'b1-grew-into-diverged' @(
    @{ From = "    'GREW'      = 'MOVED'"; To = "    'GREW'      = 'DIVERGED'" }
)
$b1Run = Invoke-Verify -Cli $b1 -Artifact $aGrew -PlaneRootPath $pGrew.RootPath
$b1Keep = Invoke-Verify -Cli $b1 -Artifact $aGood -PlaneRootPath $pGood.RootPath
Add-Result 'A13-B1' (
    (Get-Outcome $b1Run.StdOut 'evidence_state') -eq 'DIVERGED' -and
    $b1Keep.ExitCode -eq 0
) "FOLDING GREW INTO DIVERGED REDs the DP-09 member ONLY: the ordinary between-turns state of a live multi-turn dispatch now reports $(Get-Outcome $b1Run.StdOut 'evidence_state') -- an INTEGRITY EVENT for a session that merely continued working, which is the E5-iv misdiagnosis spec:68-71 says gets the gate switched off within a week. The positive control is untouched (exit $($b1Keep.ExitCode))"

# --- B2: the subsumption defect -- only the state derivation runs -------------------------------
$b2 = New-MutatedCli 'b2-state-subsumes-schema' @(
    @{ From = "    `$schemaPath = Get-ManifestSchemaPath -RepoRoot `$RepoRoot"
       To   = "    if (`$state -eq 'FINALIZED') { return [pscustomobject]@{ Engaged = `$true; State = `$st; DispatchId = `$dispatchId; Reason = `$null } }`n    `$schemaPath = Get-ManifestSchemaPath -RepoRoot `$RepoRoot" }
)
$b2Run = Invoke-Verify -Cli $b2 -Artifact $aNb1 -PlaneRootPath $pNb1.RootPath
$b2Keep = Invoke-Verify -Cli $b2 -Artifact $aTrunc -PlaneRootPath $pTrunc.RootPath
Add-Result 'A13-B2' (
    $b2Run.ExitCode -eq 0 -and (Get-Gate $b2Run.StdOut) -eq 'PASS' -and
    (Get-Outcome $b2Run.StdOut 'schema_validity') -eq '<no-entry>' -and
    $b2Keep.ExitCode -eq 1
) "LETTING THE STATE DERIVATION SUBSUME THE SCHEMA CHECK REDs the NB-1 member ONLY: with the schema axis skipped on a FINALIZED manifest, the NB-1 artifact PASSES at exit $($b2Run.ExitCode) with gate $(Get-Gate $b2Run.StdOut) and the schema subject has vanished from the report ($(Get-Outcome $b2Run.StdOut 'schema_validity')). That is spec:278-279 exactly -- 'an implementation that runs only the state derivation and reports the artifact good has reintroduced the defect the resolution recorded'. The TAMPERED member is untouched (exit $($b2Keep.ExitCode))"

# --- B3: the flag reported only when the arm refuses ---------------------------------------------
$b3 = New-MutatedCli 'b3-flag-only-when-refusing' @(
    @{ From = "    `$pathNote = ''"
       To   = "    if (`$stateOutcome -eq 'MATCHED') { `$flags = '' }`n    `$pathNote = ''" }
)
$b3Run = Invoke-Verify -Cli $b3 -Artifact $aErr -PlaneRootPath $pErr.RootPath
$b3Keep = Invoke-Verify -Cli $b3 -Artifact $aNb1 -PlaneRootPath $pNb1.RootPath
Add-Result 'A13-B3' (
    (Get-Field $b3Run.StdOut 'evidence_state' 'derived') -notmatch 'hook_errors_present=true' -and
    $b3Run.ExitCode -eq 0 -and
    (Get-Outcome $b3Keep.StdOut 'schema_validity') -eq 'DIVERGED'
) "REPORTING THE FLAG ONLY WHEN THE ARM REFUSES REDs the every-entry member ONLY: a FINALIZED manifest carrying hook_errors_present=true now PASSES at exit $($b3Run.ExitCode) with NO flag anywhere on its entry, so a consumer reads it as complete evidence -- and spec:288-289 exists precisely because 'a consumer that never sees the flag cannot weigh it'. THE GATE CANNOT CATCH THIS ONE, which is the point. NB-1 is untouched ($(Get-Outcome $b3Keep.StdOut 'schema_validity'))"

# --- B4: parity alone reported as "the plane is intact" -------------------------------------------
$b4 = New-MutatedCli 'b4-parity-alone-is-the-plane' @(
    @{ From = "    `$runtimeManifestPath = [string]`$ManifestResult.State.manifest_path"
       To   = "    return [pscustomobject]@{ Engaged = `$true; Reason = `$null }`n    `$runtimeManifestPath = [string]`$ManifestResult.State.manifest_path" }
)
$b4Run = Invoke-Verify -Cli $b4 -Artifact $aCorrupt -PlaneRootPath $pCorrupt.RootPath
$b4Keep = Invoke-Verify -Cli $b4 -Artifact $aGap -PlaneRootPath $pGap.RootPath
Add-Result 'A13-B4' (
    $b4Run.ExitCode -eq 0 -and (Get-Gate $b4Run.StdOut) -eq 'PASS' -and
    (Get-Outcome $b4Run.StdOut 'plane_parity') -eq 'MATCHED' -and
    (Get-Outcome $b4Run.StdOut 'stream_integrity') -eq '<no-entry>' -and
    $b4Keep.ExitCode -eq 1
) "REPORTING PARITY ALONE AS 'THE PLANE IS INTACT' REDs the two-subjects member ONLY: with the stream-body subject gone ($(Get-Outcome $b4Run.StdOut 'stream_integrity')), a plane whose committed stream body is CORRUPT passes at exit $($b4Run.ExitCode) on the parity arm's word -- and parity compares stream bodies by existence only, so it was never able to see it. That is the class claim spec:341-342 forbids. The parity-hole member is untouched (exit $($b4Keep.ExitCode))"

# --- B5: verify stops discriminating the capture-gap variant on its own side ----------------------
#     THE REPLACEMENT FOR THE RETIRED B5, UNDER THE KILL-SIGNAL-PROVENANCE LAW. The
#     predecessor disabled verify's RECLASSIFICATION (mission-verify.ps1:2231) and was killed by a
#     mismatch THE SEALED FUNCTION MANUFACTURED. The cure removed that mismatch at source, so the old
#     mutation now has nothing to act on: an UNKILLABLE mutant, which is the class the law was
#     minted over. The replacement is derived CONSUMER-SIDE and its kill signal is PROVED BEFORE
#     ADOPTION, from source rather than from expectation: Get-CaptureGapPaths (:2102-2126) feeds
#     $gapPaths (:2211-2212), and the $gapPaths.Count -gt 0 branch (:2267) is the ONLY producer of
#     the ABSENT capture_gap outcome and of a non-zero capture_gap_entries. Empty that input and the
#     subject flips to MATCHED, the plane stops refusing, and the disclosed gap VANISHES from the
#     report -- a live signal, post-cure, on verify's own side of the call.
#     NOT a duplicate of a14's library-side B2. That mutation RESTORES the false positive inside the
#     sealed function; this one DELETES verify's manifest-derived discrimination. Different code,
#     different failure direction, different instrument. A mutation that kills in a neighbour's
#     instrument is not evidence about this one.
$b5 = New-MutatedCli 'b5-verify-stops-discriminating-the-gap' @(
    @{ From = "        if (`$cap -is [bool] -and `$cap) { continue }"
       To   = "        if (`$true) { continue }" }
)
$b5Run = Invoke-Verify -Cli $b5 -Artifact $aCapGap -PlaneRootPath $pCapGap.RootPath
$b5Keep = Invoke-Verify -Cli $b5 -Artifact $aCorrupt -PlaneRootPath $pCorrupt.RootPath
Add-Result 'A13-B5' (
    (Get-Outcome $b5Run.StdOut 'capture_gap') -eq 'MATCHED' -and
    (Get-Field $b5Run.StdOut 'capture_gap' 'derived') -match 'capture_gap_entries=0' -and
    $b5Run.ExitCode -eq 0 -and (Get-Gate $b5Run.StdOut) -eq 'PASS' -and
    (Get-Outcome $b5Keep.StdOut 'stream_integrity') -eq 'DIVERGED'
) "REMOVING VERIFY'S OWN VARIANT DISCRIMINATION REDs the NB-2 CONSUMER member ONLY: an HONESTLY DISCLOSED capture failure now reports $(Get-Outcome $b5Run.StdOut 'capture_gap') with capture_gap_entries=0, and the plane PASSES at exit $($b5Run.ExitCode) with gate $(Get-Gate $b5Run.StdOut) where it refused before. THE GAP IS NOT MISREPORTED AS TAMPERING -- IT SILENTLY DISAPPEARS, which spec:445-449 forbids in the same breath as the false positive: 'It is NOT SILENTLY DROPPED EITHER'. Post-cure this is the ONLY route by which a gap reaches the report, because verify never reads the library's capture_gaps -- so this member is what stands between the registered follow-on and a real hole. The real corrupt-body member is untouched ($(Get-Outcome $b5Keep.StdOut 'stream_integrity'))"

# --- B6: section 5's ordering inverted ------------------------------------------------------------
$b6 = New-MutatedCli 'b6-ordering-inverted' @(
    @{ From = "    if (`$state -ne 'FINALIZED') {"; To = "    if (`$false) {" }
)
$b6Run = Invoke-Verify -Cli $b6 -Artifact $aNoFinal -PlaneRootPath $pNoFinal.RootPath
$b6Keep = Invoke-Verify -Cli $b6 -Artifact $aGood -PlaneRootPath $pGood.RootPath
Add-Result 'A13-B6' (
    (Get-Outcome $b6Run.StdOut 'plane_parity') -eq 'DIVERGED' -and
    $b6Keep.ExitCode -eq 0
) "RUNNING THE PLANE DETECTORS AGAINST A MANIFEST VERIFY HAS ALREADY REFUSED REDs the ordering member ONLY: an interrupted finalizer -- an honest, already-disclosed capture failure -- is now reported as $(Get-Outcome $b6Run.StdOut 'plane_parity'), an INTEGRITY VIOLATION, which is spec:351-353's stated consequence of the wrong order. The positive control is untouched (exit $($b6Keep.ExitCode))"

# --- B7: a fabricated exit code for an in-process detector ----------------------------------------
$b7 = New-MutatedCli 'b7-fabricated-exit-code' @(
    @{ From = "        `$exit = `$null`n        `$exitReason = `$script:ExitNullInProc"
       To   = "        `$exit = 0`n        `$exitReason = `$script:ExitNullInProc" }
)
$b7Run = Invoke-Verify -Cli $b7 -Artifact $aGood -PlaneRootPath $pGood.RootPath
$b7Keep = Invoke-Verify -Cli $b7 -Artifact $aNb1 -PlaneRootPath $pNb1.RootPath
Add-Result 'A13-B7' (
    ($b7Run.StdOut -notmatch '(?m)^\s+exit_code:\s*~\s*$') -and
    ($b7Run.StdOut -notmatch 'null BY CATEGORY, NOT BY CAPTURE GAP') -and
    (Get-Outcome $b7Keep.StdOut 'schema_validity') -eq 'DIVERGED'
) "FABRICATING exit_code 0 FOR A DETECTOR THAT NEVER WAS A PROCESS REDs the DP-11 member ONLY: every in-process derivation now reports a 0 nobody observed and the reason field is gone, so a reader cannot tell a real child-process success from a function call that has no exit code at all -- and the E5-i capture-gap null becomes indistinguishable from a non-applicability. The gate is silent about it, which is why it needs its own member. NB-1 is untouched ($(Get-Outcome $b7Keep.StdOut 'schema_validity'))"

# =================================================================================================
Write-Head '=== WHAT THIS RUN DID NOT CHECK ================================================'
[Console]::Out.WriteLine('  (spec:611-612 -- an unrun arm reported as absent from the findings is the false-PASS')
[Console]::Out.WriteLine('   class in prose form. These are declared, not silently omitted.)')
[Console]::Out.WriteLine('  A11 AND A12 DO NOT GREEN AGAINST THIS BUILD, AND THAT IS THIS INCREMENT''S DOING.')
[Console]::Out.WriteLine('                    Their fixtures name an evidence_manifest whose plane holds no')
[Console]::Out.WriteLine('                    finalized manifest, so the now-built MANIFEST arm refuses and their')
[Console]::Out.WriteLine('                    gate-PASS drives fail. The refusal is CORRECT under spec:309-310 --')
[Console]::Out.WriteLine('                    every increment that adds a refusing arm can turn a previously')
[Console]::Out.WriteLine('                    passing fixture red. Curing it means editing two OPERATOR-PLACED')
[Console]::Out.WriteLine('                    instruments, which is not this file''s to do and is registered.')
[Console]::Out.WriteLine('  spec:367-369      PARTLY DRIVEN. An absent or unparsable RUNTIME manifest yields ABSENT')
[Console]::Out.WriteLine('                    and not a parity failure, which drive A13-13 shows -- but by section')
[Console]::Out.WriteLine('                    5''s ordering rule rather than by the parity function''s own branch,')
[Console]::Out.WriteLine('                    which the ordering makes UNREACHABLE from inside the arm. The branch')
[Console]::Out.WriteLine('                    is implemented and is not driven. Disclosed, not cured.')
[Console]::Out.WriteLine('  SCHEMA VALIDATOR  SUBSET REACH. It implements the keywords this schema uses and no')
[Console]::Out.WriteLine('                    others; an unimplemented keyword in a future revision would be')
[Console]::Out.WriteLine('                    SILENTLY IGNORED, which fails OPEN. Stated on every entry it decides.')
[Console]::Out.WriteLine('  transcript_sha256 NO LONGER COMPARED BY NOTHING AT THE LIBRARY (the library now compares a')
[Console]::Out.WriteLine('                    captured:true snapshot against its recorded hash), but NO ARM IN THIS')
[Console]::Out.WriteLine('                    DOCUMENT re-derives a COMMITTED transcript''s contents. a14 member 5')
[Console]::Out.WriteLine('                    drives the library side; the committed side stays registered.')
[Console]::Out.WriteLine('  NB-2 CODE DELTA   APPLIED, retiring anchor 65865a0f / 76413 b and recording')
[Console]::Out.WriteLine('                    EC27AB3A / 80479 b, both WORKTREE-CLASS. The 189f811b /')
[Console]::Out.WriteLine('                    46870 b figure these lines once carried was SUPERSEDED off an earlier spec section 10 and')
[Console]::Out.WriteLine('                    was never the live anchor. This file drives the ORDERING RULE verify')
[Console]::Out.WriteLine('                    obeys; a14 drives the sealed function''s own branching. A-566 SPANS BOTH.')
[Console]::Out.WriteLine('  capture_gaps      HAS NO CONSUMER, AND THAT IS A REGISTERED FOLLOW-ON, NOT A CURE HERE.')
[Console]::Out.WriteLine('                    mission verify never reads the library''s new field; it re-derives the')
[Console]::Out.WriteLine('                    gap from the manifest (Get-CaptureGapPaths). The reclassification')
[Console]::Out.WriteLine('                    partition at :2211-2233 is now DEAD for the captured:false class --')
[Console]::Out.WriteLine('                    correct, still running, unreachable by that input. A13-14n states the')
[Console]::Out.WriteLine('                    trap and A13-B5 holds the load-bearing half.')
[Console]::Out.WriteLine('  A-565             ITS SECOND MEMBER IS DRIVEN HERE; its FIRST rides the ANCHOR arm from')
[Console]::Out.WriteLine('                    increment 1 and is a11''s. A discharge spanning both needs them green')
[Console]::Out.WriteLine('                    at a STATED COMMON BASIS (spec:630-634) -- an operator act.')
[Console]::Out.WriteLine('  A-563             NOT DECIDED. Its quantifiers are a separate assertion.')
[Console]::Out.WriteLine('  real-store        NOT DRIVEN. Every run here was given an explicit --evidence-root')
[Console]::Out.WriteLine('  self-capture      inside the scratch root; A-563:52-56 forbids greening the self-capture')
[Console]::Out.WriteLine('                    leg by writing the evidence plane from inside a session.')
[Console]::Out.WriteLine('  REAL PLANES       NOT DRIVEN. Every plane here is CONSTRUCTED, which proves the CODE PATH')
[Console]::Out.WriteLine('                    and not that every real capture failure presents in that shape.')

Write-Head '=== A13 RESULT ================================================================='
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
