# test-a14-stream-integrity-variant-branching.ps1 -- A14: NB-2 in its CORRECT FORM. Acceptance for
# assertion A-566 (REOPEN #43, M-113 seam S1, increment 4). Authority: the governing amendments and
# the sealed-hash-move amendment, against the sealed bytes of
# docs/framework/mission-verify-spec.md SS 5.1-5.2 (A3) and A-566's own letter.
#
# PLACEMENT AND PROVENANCE, STATED FIRST BECAUSE IT DECIDES WHO MAY RUN THIS. This instrument lands
# at tools/framework/tests/ and is OPERATOR-PLACED AND OPERATOR-RUN. tools/framework/tests is in the
# protected set (evidence-common.ps1:1008), so an agent can neither write nor run it there, and an
# instrument an agent placed or drove would be the agent grading itself. The builder session authored
# these bytes in its scratchpad and handed them over with their sha256. EVERY FIGURE THIS INSTRUMENT
# PRINTS AT THE OPERATOR'S SITTING IS THE OPERATOR'S -- the A5 discipline, whose seal entry states it
# plainly: "THE SESSION RAN NO SUITE AND CLAIMS NONE."
#
# THE ANCHOR CORRECTION THIS FILE IS BUILT ON, RECORDED BECAUSE IT IS LOAD-BEARING. A-566:64 and
# an earlier spec section 10 both named a 46870 b figure as this library's anchor (spec:673 now pins 3849bd6d / 105431 b). THAT FIGURE IS SUPERSEDED. D11,
# D10 and D8 each moved it, and under the supersession rule the end of the declaration
# chain is
# the 76413 b figure, OPERATOR-VERIFIED in-terminal 2026-08-16.
# This instrument anchors to that figure as PRE-EDIT and to the delta bytes as POST-EDIT, and
# it REFUSES on any third value rather than deciding a check against a library it cannot identify.
#
# WHAT THIS INSTRUMENT DECIDES -- A-566's members, each independently falsifiable:
#   1  TOOL-CALL UNCHANGED    -- a mutated stream body still REDs on stdout_sha256; an unmutated
#                               entry stays green. The delta did not disturb the path it was told
#                               not to disturb.
#   2  GAP IS NEVER A MISMATCH-- a _precompact entry with captured:false produces NO stream-integrity
#                               mismatch and NO existence test, though its file is absent by
#                               construction (spec:445-449). This is the pre-cure FALSE POSITIVE.
#   3  GAP IS NOT DROPPED     -- the same entry appears in capture_gaps, naming its path. A-566:49-51
#                               makes misreporting and dropping DISTINCT failures; members 2 and 3
#                               are separate so one mutation cannot mask the other.
#   4  captured:true EXISTENCE-- a captured:true entry whose snapshot is ABSENT REDs. THIS IS THE
#                               COVERAGE-HOLE MEMBER, and B4 below plants THE BARE HOIST against it.
#   5  transcript_sha256      -- a captured:true entry whose SNAPSHOT BYTES were changed while the
#                               manifest's hash was left stale REDs. The comparison is against the
#                               FILE; A-566:54-56 fails any probe that reads the field back to
#                               itself, so the fixture hashes real bytes and then rewrites them.
#   6  ok IS MISMATCH-ONLY    -- a capture gap does NOT flip ok. A caller reading only
#                               ok must not re-commit the conflation this cure ends.
#   7  D11 IDENTITY RIDES     -- duplicate-path and count-mismatch still ride every integrity run
#                               The delta did not displace them.
#  S1  RETURN SHAPE, BOTH SITES -- SUPPLEMENTARY, DECLARED AS BEYOND THE SEVEN. capture_gaps is
#                               present on the no-manifest early return as well as the terminal one.
#                               It is driven because the delta's rationale (1) claims it, and a claim
#                               with no drive is the thing this program exists to stop. It is NOT
#                               one of A-566's members and is not counted as one.
#
# WHAT THIS INSTRUMENT DOES NOT DECIDE, stated so no reader infers more from a green run:
#   - A-566 IS NOT DISCHARGED HERE. Its ORDERING member -- with the manifest not FINALIZED, no
#     stream mismatch is reported against it at all (spec:440-442) -- is a property of `mission
#     verify`'s ARM ORDERING, not of this function, and a13 drives it. A discharge spans a14 AND a13
#     at a STATED COMMON BASIS (spec:630-634), which is an operator act and not this file's claim.
#   - IT DECIDES NOTHING ABOUT THE HOOKS. This function is not called automatically by anything in
#     A1 (evidence-common.ps1:497-500 says so); driving it proves the detector, not its wiring.
#   - A-562, A-563, A-564, A-565, A-567, A-568 are untouched.
#   - THE REAL EVIDENCE STORE IS NOT DRIVEN. Every plane is CONSTRUCTED under a scratch root beneath
#     $env:TEMP. A-563:52-56 forbids greening the self-capture leg from inside a session.
#
# ANCHOR BASIS: TWO DECLARED DIGESTS, WORKTREE-CLASS (`core.autocrlf` true, no
# `.gitattributes` for `tools/framework/**`, spec:238-244; spec:721 registers that the
# misdeclared-hash class has no detector). Re-derive in a worktree, never from a clone-and-hash.
#
# THIS FILE READS THE SEALED LIBRARY, AND THAT IS A DECLARED DEPARTURE FROM A13. A13 states it "does
# not hash it, does not copy it, and does not read it" -- A13 did not need to. A14 does: A-566:57-60
# makes THE BARE HOIST a required planted breakage, and a variant of the function cannot be produced
# without reading the function. So this file READS the library and WRITES MUTATED COPIES UNDER THE
# SCRATCH ROOT. It never writes, stages, hashes-for-the-record or executes anything under
# tools/framework/**; the tracked library is opened read-only and is byte-unchanged by this run.
#
# INSTRUMENT LAWS: (a) pure ASCII source; (b) path variables carry a Path suffix;
# (c) every child process runs through a redirected System.Diagnostics.Process, so a native stderr
# byte can never surface as a PowerShell error record under PS 5.1.
#
# PLANTED BREAKAGE IS PER MEMBER AND INDEPENDENT (the A-561 form). Each mutation is applied to a COPY
# of the library under the scratch root. Each mutated run asserts BOTH that its own member REDs AND
# that a NAMED NEIGHBOUR member stays green, so a mutation that broke everything would not pass.
#
# EXIT CONTRACT (printed at run time): 0 = every check passed. 2 = anchor guard failed (no library at
# -LibPath, powershell not launchable, or the library carries a digest that is neither the declared
# PRE-EDIT nor the declared POST-EDIT anchor; no check was decided). 4 = one or more checks failed.
# NON-UNIQUENESS DISCLOSED: exit 4 is also A5's, A9's, A10's, A11's, A12's and A13's failing exit;
# exit 2 is also A10's, A11's, A12's and A13's anchor-guard exit. Read the printed counts, not the
# code alone.
#
# RED BASELINE IS A LEGITIMATE RUN, NOT A FAILURE OF THIS FILE. Run against the PRE-EDIT library
# this instrument REDs members 2..6 and exits 4. That is the RED half of RED-then-GREEN
# and is announced in the banner. NO VERDICT IS EVER INVERTED by mode: an instrument that graded
# itself leniently because it recognised its own basis would be worthless.
#
# REACH: this decides whether the delta BEHAVES as spec:468-477 and A-566 specify, against
# constructed manifests. It cannot decide whether the spec is right, and it does not prove that
# every real capture failure presents in the shape these fixtures construct.

#requires -Version 5.0
param(
    [string]$LibPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'framework\hooks\lib\evidence-common.ps1'),
    [string]$ScratchRootPath = (Join-Path $env:TEMP ('a14-scratch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))),
    [switch]$KeepScratch
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# The two declared anchors. PRE-EDIT is the end of the D11/D10/D8 declaration chain
# (operator-verified). POST-EDIT is the delta as handed over by the builder seat.
$script:AnchorPreEdit  = '65865A0F'
$script:AnchorPostEdit = 'EC27AB3A33639B9527062F2CE6B8581636A08204A05D8E355D4EFB552A563609'

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

# =================================================================================================
# ANCHOR GUARD -- exit 2 if any premise is missing; no check is decided on a broken anchor.
# =================================================================================================
Write-Head '=== A14 ANCHOR GUARD ==========================================================='

if (-not (Test-Path -LiteralPath $LibPath -PathType Leaf)) {
    [Console]::Out.WriteLine("  ANCHOR FAIL: no detector library at $LibPath")
    exit 2
}
$libSha = (Get-FileSha256 $LibPath).ToUpperInvariant()
$libLen = (Get-Item -LiteralPath $LibPath).Length
$mode = ''
if ($libSha -eq $script:AnchorPostEdit) { $mode = 'POST-EDIT' }
elseif ($libSha.StartsWith($script:AnchorPreEdit)) { $mode = 'PRE-EDIT' }
else {
    [Console]::Out.WriteLine("  ANCHOR FAIL: the library at -LibPath carries digest $libSha ($libLen b),")
    [Console]::Out.WriteLine("               which is neither the declared PRE-EDIT anchor $($script:AnchorPreEdit)... nor")
    [Console]::Out.WriteLine("               the declared POST-EDIT anchor $($script:AnchorPostEdit).")
    [Console]::Out.WriteLine('               The instrument and the library have drifted. This is a FAILURE of the')
    [Console]::Out.WriteLine('               premise, not of a check, and no check is decided. Re-derive the anchor')
    [Console]::Out.WriteLine('               chain before re-running.')
    exit 2
}

$scratchProbePath = Join-Path $ScratchRootPath 'probe'
[void][System.IO.Directory]::CreateDirectory($scratchProbePath)
$psProbe = Invoke-Child -FilePath 'powershell' -ArgumentList @('-NoProfile', '-Command', 'exit 0') -WorkingDirectoryPath $scratchProbePath
if ($psProbe.ExitCode -ne 0) {
    [Console]::Out.WriteLine('  ANCHOR FAIL: powershell is not launchable as a child process')
    exit 2
}

$evPath  = Join-Path $ScratchRootPath 'ev'
$mutPath = Join-Path $ScratchRootPath 'mut'
$fxPath  = Join-Path $ScratchRootPath 'fx'
foreach ($d in @($evPath, $mutPath, $fxPath)) { [void][System.IO.Directory]::CreateDirectory($d) }

[Console]::Out.WriteLine("  library        $LibPath")
[Console]::Out.WriteLine("  digest         $libSha")
[Console]::Out.WriteLine("  bytes          $libLen")
[Console]::Out.WriteLine("  MODE           $mode")
[Console]::Out.WriteLine("  scratch        $ScratchRootPath")
if ($mode -eq 'PRE-EDIT') {
    [Console]::Out.WriteLine('')
    [Console]::Out.WriteLine('  *** RED BASELINE RUN. This is the library BEFORE the delta. Members 2, 3,')
    [Console]::Out.WriteLine('      4, 5 and 6 are EXPECTED TO RED and the run is EXPECTED to exit 4. That is the')
    [Console]::Out.WriteLine('      RED half of RED-then-GREEN. NO VERDICT IS INVERTED because of this mode. ***')
}

try {

# =================================================================================================
# FIXTURES -- constructed manifests, outside the real repository.
# =================================================================================================
#
# Test-EvidenceStreamIntegrity consumes ONLY the manifest's `entries` array and the files under the
# directory it is given. The manifests below carry the full 1.3.0 member set anyway, so a fixture is
# a manifest rather than a stub -- but NOTHING outside `entries` is read by the function under test,
# and no green here says anything about the other members.
#
# Hand-assembled rather than ConvertTo-Json'd, on purpose: a serialiser that quietly normalises a
# single-element array or reorders a member would make the fixture something other than what the
# drive says it is.

function New-Case {
    param([string]$CaseName)
    $rootPath = Join-Path $evPath $CaseName
    [void][System.IO.Directory]::CreateDirectory((Join-Path $rootPath 'streams'))
    [void][System.IO.Directory]::CreateDirectory((Join-Path $rootPath 'transcripts'))
    return [pscustomobject]@{
        Case = $CaseName
        RootPath = $rootPath
        StreamsPath = (Join-Path $rootPath 'streams')
        TranscriptsPath = (Join-Path $rootPath 'transcripts')
        ManifestPath = (Join-Path $rootPath 'manifest.json')
    }
}

function New-ToolCallEntryJson {
    param([int]$Seq, [string]$OutText, [string]$ErrText)
    $rel = 'streams/{0:d6}.json' -f $Seq
    return ('{"ts":"2026-08-16T00:00:0' + ($Seq % 10) + '.100Z","tool":"Bash","command":"probe ' + $Seq + '"' +
            ',"exit_code":0,"stdout_sha256":"' + (Get-StringSha256 $OutText) + '"' +
            ',"stderr_sha256":"' + (Get-StringSha256 $ErrText) + '","path":"' + $rel + '"}')
}

function New-PrecompactEntryJson {
    <#
        -Sha is passed EXPLICITLY rather than derived here, because member 5 needs a manifest whose
        recorded hash is the hash of bytes that are no longer on disk. Deriving it inside this helper
        would make that fixture impossible to construct honestly.
    #>
    param([int]$Index, [bool]$Captured, [AllowNull()][string]$Sha)
    $rel = 'transcripts/precompact-{0:d3}.jsonl' -f $Index
    $shaText = 'null'
    $code = 1
    if ($Captured) { $code = 0 }
    if ($Sha) { $shaText = '"' + $Sha + '"' }
    return ('{"ts":"2026-08-16T00:00:09.500Z","tool":"_precompact","command":"PreCompact auto"' +
            ',"exit_code":' + $code + ',"transcript_sha256":' + $shaText +
            ',"captured":' + $(if ($Captured) { 'true' } else { 'false' }) + ',"path":"' + $rel + '"}')
}

function Write-ManifestFor {
    param($Case, [string[]]$EntryJson)
    $parts = @()
    $parts += '"schema_version":"1.3.0"'
    $parts += ('"dispatch_id":"d-' + $Case.Case + '"')
    $parts += '"session_id":null'
    $parts += '"state":"finalized"'
    $parts += ('"entries":[' + ($EntryJson -join ',') + ']')
    $parts += ('"entry_count":' + $EntryJson.Count)
    $parts += '"unparsable_lines":0'
    $parts += '"log_path":"log.jsonl"'
    $parts += '"hook_errors_present":false'
    $parts += '"hook_errors_sha256":null'
    $parts += '"streams_committed":true'
    $parts += '"log_sha256":"' + (Get-StringSha256 'log') + '"'
    $parts += '"finalize_count":1'
    $parts += '"created_at":"2026-08-16T00:00:00.000Z"'
    $parts += '"finalized_at":"2026-08-16T00:00:01.000Z"'
    Write-Utf8NoBom $Case.ManifestPath ('{' + ($parts -join ',') + '}' + "`n")
}

function Write-StreamBody {
    <#
        One file per declared streams/ entry, and EXACTLY that many: the sealed
        Get-EvidenceStreamIdentityFindings rides every integrity run and reports a count-mismatch
        when the two disagree, so a fixture off by one would red a member it was not aimed at.
    #>
    param($Case, [int]$Seq, [string]$OutText, [string]$ErrText)
    Write-Utf8NoBom (Join-Path $Case.StreamsPath ('{0:d6}.json' -f $Seq)) ('{"stdout":"' + $OutText + '","stderr":"' + $ErrText + '"}')
}

function Write-Transcript {
    param($Case, [int]$Index, [string]$Text)
    $p = Join-Path $Case.TranscriptsPath ('precompact-{0:d3}.jsonl' -f $Index)
    Write-Utf8NoBom $p $Text
    return $p
}

# ---- the driver ---------------------------------------------------------------------------------
# One child process per (library, case) pair. A child rather than a dot-source in this session for
# two reasons: the library sets Set-StrictMode -Version Latest at import and this instrument runs at
# 2.0, and seven mutated copies would otherwise redefine the same function names in one runspace, so
# a later drive could silently measure an earlier drive's function.

$driverPath = Join-Path $fxPath 'drive.ps1'
Write-Utf8NoBom $driverPath @'
param([string]$Lib, [string]$Dir)
$ErrorActionPreference = 'Stop'
. $Lib
$r = Test-EvidenceStreamIntegrity -Dir $Dir
$names = @($r.PSObject.Properties.Name)
$gapList = @()
if ($names -contains 'capture_gaps') { $gapList = @($r.capture_gaps) }
$o = [ordered]@{
    ok           = [bool]$r.ok
    checked      = [int]$r.checked
    reason       = [string]$r.reason
    has_gaps     = ($names -contains 'capture_gaps')
    mismatches   = @(@($r.mismatches) | ForEach-Object { "$($_.path) :: $($_.problem)" })
    capture_gaps = @($gapList | ForEach-Object { "$($_.path) :: $($_.problem)" })
}
[Console]::Out.WriteLine(($o | ConvertTo-Json -Depth 6 -Compress))
'@

function Invoke-Integrity {
    <# Returns the parsed return object, or throws with the child's stderr if it did not answer. #>
    param([string]$Lib, [string]$Dir)
    $res = Invoke-Child -FilePath 'powershell' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $driverPath, '-Lib', $Lib, '-Dir', $Dir) `
        -WorkingDirectoryPath $fxPath
    if ($res.ExitCode -ne 0 -or -not $res.StdOut.Trim()) {
        throw "DRIVE FAILED (exit $($res.ExitCode)) lib=$Lib dir=$Dir :: $($res.StdErr.Trim())"
    }
    return ($res.StdOut.Trim() | ConvertFrom-Json)
}

function Test-AnyMatch {
    <#
        ORDINAL SUBSTRING, NEVER -like. BUILDER-BATTERY ROUND 1 FIRED HERE, and the defect was in
        this probe, not in the product: the D11 findings are labelled "[duplicate-path]" and
        "[count-mismatch]", and -like reads a bracketed group as a WILDCARD CHARACTER CLASS, so
        '*[count-mismatch]*' is not a valid pattern and PS 5.1 threw rather than returning false.
        A11-B7 and A14-7 were the members that could not be decided. String.Contains has no pattern
        semantics at all, which is what a needle taken from a product string needs.
    #>
    param($Items, [string]$Needle)
    foreach ($i in @($Items)) { if (([string]$i).Contains($Needle)) { return $true } }
    return $false
}

function New-MutatedLib {
    <# A planted breakage, applied to a COPY. A missing anchor is a hard failure, not a skip. #>
    param([string]$Name, [hashtable[]]$Edits)
    $text = [System.IO.File]::ReadAllText($LibPath)
    foreach ($e in $Edits) {
        if ($text.IndexOf($e.From) -lt 0) {
            throw "MUTATION '$Name': anchor string not found in the library. The instrument and the library have drifted; this is a FAILURE, not a skip."
        }
        $text = $text.Replace($e.From, $e.To)
    }
    $p = Join-Path $mutPath "$Name.ps1"
    Write-Utf8NoBom $p $text
    return $p
}

# ---- the cases ----------------------------------------------------------------------------------

# 1. GOOD -- two tool-call entries, two matching stream bodies. The positive control.
$cGood = New-Case 'good'
Write-ManifestFor $cGood @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-ToolCallEntryJson 2 'out-two' 'err-two'))
Write-StreamBody $cGood 1 'out-one' 'err-one'
Write-StreamBody $cGood 2 'out-two' 'err-two'

# 2. BODYMUT -- entry 1's stream body is rewritten AFTER its hash was recorded.
$cBodyMut = New-Case 'bodymut'
Write-ManifestFor $cBodyMut @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-ToolCallEntryJson 2 'out-two' 'err-two'))
Write-StreamBody $cBodyMut 1 'TAMPERED' 'err-one'
Write-StreamBody $cBodyMut 2 'out-two' 'err-two'

# 3. GAP -- one tool-call entry, plus a _precompact entry with captured:false, a null
#    transcript_sha256, and a path whose file DOES NOT EXIST. That absent file is the whole point:
#    pre-cure it reached the existence test and was reported as 'stream file missing'.
$cGap = New-Case 'gap'
Write-ManifestFor $cGap @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-PrecompactEntryJson 1 $false $null))
Write-StreamBody $cGap 1 'out-one' 'err-one'

# 4. CAPMISSING -- captured:true, a real recorded hash, and NO snapshot on disk. The member the bare
#    hoist would stop checking.
$cCapMissing = New-Case 'capmissing'
Write-ManifestFor $cCapMissing @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-PrecompactEntryJson 1 $true (Get-StringSha256 'transcript body')))
Write-StreamBody $cCapMissing 1 'out-one' 'err-one'

# 5. CAPSTALE -- captured:true. The snapshot is written, ITS REAL BYTES ARE HASHED, that hash goes in
#    the manifest, and THEN the snapshot is rewritten. The manifest's field is therefore stale
#    against the file, which is the only construction A-566:54-56 accepts: a probe that read the
#    field back to itself would pass here and would prove nothing.
$cCapStale = New-Case 'capstale'
$stalePath = Write-Transcript $cCapStale 1 "original transcript bytes`n"
$staleSha = Get-FileSha256 $stalePath
Write-ManifestFor $cCapStale @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-PrecompactEntryJson 1 $true $staleSha))
Write-StreamBody $cCapStale 1 'out-one' 'err-one'
[void](Write-Transcript $cCapStale 1 "REWRITTEN transcript bytes`n")

# 6. CAPGOOD -- captured:true and the snapshot matches its recorded hash. The positive control for
#    the transcript comparison: without it, a member that RED on everything would look correct.
$cCapGood = New-Case 'capgood'
$goodPath = Write-Transcript $cCapGood 1 "honest transcript bytes`n"
Write-ManifestFor $cCapGood @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-PrecompactEntryJson 1 $true (Get-FileSha256 $goodPath)))
Write-StreamBody $cCapGood 1 'out-one' 'err-one'

# 7. DUP -- two entries declaring ONE stream path, one file on disk. Drives both D11 members at once.
$cDup = New-Case 'dup'
Write-ManifestFor $cDup @((New-ToolCallEntryJson 1 'out-one' 'err-one'), (New-ToolCallEntryJson 1 'out-one' 'err-one'))
Write-StreamBody $cDup 1 'out-one' 'err-one'

# 8. NOMAN -- no manifest at all. Drives the early return's shape (supplementary member S1).
$cNoMan = New-Case 'noman'

# =================================================================================================
Write-Head '=== A14 MEMBERS -- the delta as spec:468-477 and A-566 specify it ==============='

$rGood       = Invoke-Integrity -Lib $LibPath -Dir $cGood.RootPath
$rBodyMut    = Invoke-Integrity -Lib $LibPath -Dir $cBodyMut.RootPath
$rGap        = Invoke-Integrity -Lib $LibPath -Dir $cGap.RootPath
$rCapMissing = Invoke-Integrity -Lib $LibPath -Dir $cCapMissing.RootPath
$rCapStale   = Invoke-Integrity -Lib $LibPath -Dir $cCapStale.RootPath
$rCapGood    = Invoke-Integrity -Lib $LibPath -Dir $cCapGood.RootPath
$rDup        = Invoke-Integrity -Lib $LibPath -Dir $cDup.RootPath
$rNoMan      = Invoke-Integrity -Lib $LibPath -Dir $cNoMan.RootPath

Add-Result 'A14-1' (
    $rGood.ok -and ($rGood.checked -eq 2) -and (@($rGood.mismatches).Count -eq 0) -and
    (Test-AnyMatch $rBodyMut.mismatches 'stdout_sha256 mismatch') -and (-not $rBodyMut.ok) -and
    ($rBodyMut.checked -eq 2)
) "TOOL-CALL HANDLING UNCHANGED: the clean plane reports ok with checked=$($rGood.checked); the mutated body REDs on stdout_sha256 with checked=$($rBodyMut.checked). The delta was told not to disturb this path and it did not."

Add-Result 'A14-2' (
    (@($rGap.mismatches).Count -eq 0) -and (-not (Test-AnyMatch $rGap.mismatches 'stream file missing'))
) "CAPTURE GAP IS NEVER A STREAM-INTEGRITY MISMATCH: the captured:false entry's file is ABSENT by construction and the mismatch list is still empty ($(@($rGap.mismatches).Count) entries). No existence test was run against a gap the manifest already disclosed (spec:445-449). This is the pre-cure false positive, gone."

Add-Result 'A14-3' (
    $rGap.has_gaps -and (@($rGap.capture_gaps).Count -eq 1) -and (Test-AnyMatch $rGap.capture_gaps 'transcripts/precompact-001.jsonl')
) "THE GAP IS NOT SILENTLY DROPPED: capture_gaps carries $(@($rGap.capture_gaps).Count) entry naming its own path. A-566:49-51 makes dropping and misreporting DISTINCT failures; B2 and B3 below break them apart."

Add-Result 'A14-4' (
    (Test-AnyMatch $rCapMissing.mismatches 'transcript snapshot missing') -and (-not $rCapMissing.ok) -and
    (@($rCapMissing.capture_gaps).Count -eq 0)
) "captured:true GETS THE EXISTENCE TEST: an honest capture whose snapshot is absent REDs, and does NOT land in capture_gaps -- the entry claims it captured, so it is held to that claim. This is the coverage the bare hoist would have removed (spec:461-466)."

Add-Result 'A14-5' (
    (Test-AnyMatch $rCapStale.mismatches 'transcript_sha256 mismatch') -and (-not $rCapStale.ok) -and
    $rCapGood.ok -and (@($rCapGood.mismatches).Count -eq 0)
) "transcript_sha256 IS COMPARED AGAINST THE SNAPSHOT FILE: rewritten bytes under a stale recorded hash RED, and a matching snapshot stays green. The comparison is against the FILE, not the manifest field read back to itself (A-566:54-56). NO CODE IN THE SEALED SET performed this before the delta."

Add-Result 'A14-6' (
    $rGap.ok -and (@($rGap.capture_gaps).Count -eq 1)
) "ok IS GOVERNED BY mismatches ALONE: a plane carrying a capture gap and no mismatch reports ok=$($rGap.ok). A caller reading only ok is not told a gap exists -- which is the SEPARATION, not a merge; the delta's rationale (3) states the consequence."

Add-Result 'A14-7' (
    (Test-AnyMatch $rDup.mismatches '[duplicate-path]') -and (Test-AnyMatch $rDup.mismatches '[count-mismatch]') -and (-not $rDup.ok)
) "D11 IDENTITY MEMBERS STILL RIDE: two entries declaring one stream path yield both duplicate-path and count-mismatch. The delta did not displace them."

Add-Result 'A14-S1' (
    $rNoMan.has_gaps -and (@($rNoMan.capture_gaps).Count -eq 0) -and (-not $rNoMan.ok) -and ($rNoMan.reason -eq 'no manifest')
) "SUPPLEMENTARY, NOT ONE OF A-566'S SEVEN: capture_gaps is present and empty on the NO-MANIFEST early return, so a caller reading it does not throw under Set-StrictMode -Version Latest. Drives the delta's rationale (1); reason is still '$($rNoMan.reason)'."

# =================================================================================================
Write-Head '=== A14 PLANTED BREAKAGE -- each REDs its own member, a named neighbour stays green ==='

# B1 -- alter tool-call handling.
$b1 = New-MutatedLib 'b1-toolcall-blind' @(@{ From = '        if ($actOut -ne $expOut) {'; To = '        if ($false) {' })
$b1Mut = Invoke-Integrity -Lib $b1 -Dir $cBodyMut.RootPath
$b1Gap = Invoke-Integrity -Lib $b1 -Dir $cGap.RootPath
Add-Result 'A14-B1' (
    (-not (Test-AnyMatch $b1Mut.mismatches 'stdout_sha256 mismatch')) -and
    (@($b1Gap.capture_gaps).Count -eq 1) -and (@($b1Gap.mismatches).Count -eq 0)
) "BLINDING THE stdout COMPARISON REDs member 1 ALONE: the mutated body no longer reports a mismatch. NEIGHBOUR GREEN: the capture-gap member is untouched ($(@($b1Gap.capture_gaps).Count) gap, $(@($b1Gap.mismatches).Count) mismatches)."

# B2 -- report the gap as a mismatch: the PRE-CURE FALSE POSITIVE, restored on a copy.
$b2 = New-MutatedLib 'b2-gap-as-mismatch' @(@{
    From = "never as a stream-integrity mismatch' }"
    To   = "never as a stream-integrity mismatch' }" + "`n" + "                `$mismatch += [pscustomobject]@{ path = `$rel; problem = 'stream file missing' }"
})
$b2Gap = Invoke-Integrity -Lib $b2 -Dir $cGap.RootPath
Add-Result 'A14-B2' (
    (Test-AnyMatch $b2Gap.mismatches 'stream file missing') -and
    (@($b2Gap.capture_gaps).Count -eq 1)
) "RESTORING THE FALSE POSITIVE REDs member 2 ALONE: the disclosed gap is reported as 'stream file missing' again. NEIGHBOUR GREEN: member 3 still sees the gap in capture_gaps ($(@($b2Gap.capture_gaps).Count)). Misreporting and dropping are DIFFERENT, and this proves it in one direction."

# B3 -- drop the gap entirely.
$b3 = New-MutatedLib 'b3-gap-dropped' @(@{
    From = "                `$gaps += [pscustomobject]@{ path = `$rel; problem = 'transcript not captured"
    To   = "                `$null    = [pscustomobject]@{ path = `$rel; problem = 'transcript not captured"
})
$b3Gap = Invoke-Integrity -Lib $b3 -Dir $cGap.RootPath
Add-Result 'A14-B3' (
    (@($b3Gap.capture_gaps).Count -eq 0) -and (@($b3Gap.mismatches).Count -eq 0)
) "DROPPING THE GAP REDs member 3 ALONE: capture_gaps is empty. NEIGHBOUR GREEN: member 2's 'never a mismatch' leg still holds ($(@($b3Gap.mismatches).Count) mismatches) -- and that is exactly the danger, because a silent drop looks clean to anyone watching only the mismatch list. This proves the other direction of A-566:49-51."

# B4 -- THE BARE HOIST. The registered "one-line fix", planted so its cost is visible.
#      Effect reproduced exactly: every _precompact entry is skipped BEFORE any existence test,
#      captured:true included, which is what hoisting the stdout_sha256 fetch above the existence
#      test does to a variant that carries no stdout_sha256 at all.
$b4 = New-MutatedLib 'b4-bare-hoist' @(@{
    From = "        if ([string](Get-EntryField `$e 'tool' '') -eq '_precompact') {"
    To   = "        if ([string](Get-EntryField `$e 'tool' '') -eq '_precompact') { continue"
})
$b4CapMissing = Invoke-Integrity -Lib $b4 -Dir $cCapMissing.RootPath
$b4Gap        = Invoke-Integrity -Lib $b4 -Dir $cGap.RootPath
Add-Result 'A14-B4' (
    (-not (Test-AnyMatch $b4CapMissing.mismatches 'transcript snapshot missing')) -and
    $b4CapMissing.ok -and
    (@($b4Gap.mismatches).Count -eq 0) -and (@($b4Gap.capture_gaps).Count -eq 0)
) "THE BARE HOIST REDs member 4 AND LEAVES THE FALSE-POSITIVE CURE LOOKING CORRECT -- which is the whole finding. A captured:true entry with NO snapshot on disk now reports ok=$($b4CapMissing.ok): the coverage hole is open and silent. Meanwhile the gap plane shows $(@($b4Gap.mismatches).Count) mismatches, so anyone grading against the register's own one-line characterization would call this a pass. It also drops the gap entirely ($(@($b4Gap.capture_gaps).Count) in capture_gaps), which member 3 catches and the register never mentioned."

# B5 -- skip the transcript comparison.
$b5 = New-MutatedLib 'b5-transcript-uncompared' @(@{ From = '            if ($actTr -ne $expTr) {'; To = '            if ($false) {' })
$b5Stale   = Invoke-Integrity -Lib $b5 -Dir $cCapStale.RootPath
$b5Missing = Invoke-Integrity -Lib $b5 -Dir $cCapMissing.RootPath
Add-Result 'A14-B5' (
    (-not (Test-AnyMatch $b5Stale.mismatches 'transcript_sha256 mismatch')) -and $b5Stale.ok -and
    (Test-AnyMatch $b5Missing.mismatches 'transcript snapshot missing')
) "SKIPPING THE COMPARISON REDs member 5 ALONE: rewritten snapshot bytes under a stale hash now report ok=$($b5Stale.ok) -- transcript_sha256 back to being compared by nothing (spec:354-360). NEIGHBOUR GREEN: member 4's existence test still fires."

# B6 -- let a capture gap flip ok.
$b6 = New-MutatedLib 'b6-gap-flips-ok' @(@{
    From = '                              ok = ($mismatch.Count -eq 0)'
    To   = '                              ok = (($mismatch.Count -eq 0) -and ($gaps.Count -eq 0))'
})
$b6Gap = Invoke-Integrity -Lib $b6 -Dir $cGap.RootPath
Add-Result 'A14-B6' (
    (-not $b6Gap.ok) -and (@($b6Gap.capture_gaps).Count -eq 1) -and (@($b6Gap.mismatches).Count -eq 0)
) "LETTING A GAP FLIP ok REDs member 6 ALONE: ok=$($b6Gap.ok) on a plane with ZERO mismatches. NEIGHBOUR GREEN: the gap is still reported in its own collection. This is the conflation the delta forbids -- a caller reading ok could no longer tell an integrity violation from a disclosed capture failure."

# B7 -- drop the D11 identity members.
$b7 = New-MutatedLib 'b7-identity-dropped' @(@{
    From = "    foreach (`$f in @(Get-EvidenceStreamIdentityFindings -Entries @(Get-EntryField `$man 'entries' @()) -StreamDir (Join-Path `$rt 'streams'))) {"
    To   = '    foreach ($f in @()) {'
})
$b7Dup     = Invoke-Integrity -Lib $b7 -Dir $cDup.RootPath
$b7BodyMut = Invoke-Integrity -Lib $b7 -Dir $cBodyMut.RootPath
Add-Result 'A14-B7' (
    (-not (Test-AnyMatch $b7Dup.mismatches '[duplicate-path]')) -and
    (-not (Test-AnyMatch $b7Dup.mismatches '[count-mismatch]')) -and
    (Test-AnyMatch $b7BodyMut.mismatches 'stdout_sha256 mismatch')
) "DROPPING THE IDENTITY PASS REDs member 7 ALONE: a destroyed-payload signature goes unreported. NEIGHBOUR GREEN: member 1's stream-body comparison still fires, so the two are genuinely independent detectors sharing one return."

# =================================================================================================
Write-Head '=== WHAT THIS RUN DID NOT CHECK ================================================'
[Console]::Out.WriteLine('  (spec:611-612 -- an unrun member reported as absent from the findings is the false-PASS')
[Console]::Out.WriteLine('   class in prose form. These are declared, not silently omitted.)')
[Console]::Out.WriteLine('  A-566 ORDERING    NOT DRIVEN HERE. "manifest state first; a non-FINALIZED manifest makes the')
[Console]::Out.WriteLine('                    remaining subjects UNREADABLE" (spec:440-442) is a property of mission')
[Console]::Out.WriteLine('                    verify''s ARM ORDERING, not of this function. a13 drives it. A-566''s')
[Console]::Out.WriteLine('                    discharge therefore SPANS a14 AND a13 at one stated common basis.')
[Console]::Out.WriteLine('  reason            SAYS NOTHING ABOUT CAPTURE GAPS, by design (delta rationale 3). It was')
[Console]::Out.WriteLine('                    left byte-unchanged so no regression verdict moved. A caller reading only')
[Console]::Out.WriteLine('                    ok or only reason still learns nothing about gaps, and NO CALLER IN THE')
[Console]::Out.WriteLine('                    SEALED SET READS capture_gaps YET. The separation is built, not consumed.')
[Console]::Out.WriteLine('  checked           NOT INCREMENTED by the transcript comparison (delta rationale 2), so no')
[Console]::Out.WriteLine('                    counter proves it ran. Member 5 proves it by DRIVE instead.')
[Console]::Out.WriteLine('  missing captured  AN OFF-SCHEMA _precompact entry with no `captured` field takes the gap')
[Console]::Out.WriteLine('                    branch (delta rationale 5). NOT DRIVEN here: catching off-schema manifests')
[Console]::Out.WriteLine('                    is the MANIFEST arm''s job (spec:275-279), not this function''s.')
[Console]::Out.WriteLine('  _denied VARIANT   NOT DRIVEN. It carries a null path and is excluded by the pre-existing')
[Console]::Out.WriteLine('                    null-path guard, which the delta did not touch.')
[Console]::Out.WriteLine('  THE HOOKS         NOT DRIVEN. Nothing in A1 calls this function automatically')
[Console]::Out.WriteLine('                    (evidence-common.ps1:497-500). This proves the detector, never its wiring.')
[Console]::Out.WriteLine('  REAL PLANES       NOT DRIVEN. Every manifest here is CONSTRUCTED, which proves the CODE PATH')
[Console]::Out.WriteLine('                    and not that every real capture failure presents in that shape.')
[Console]::Out.WriteLine('  real-store        NOT TOUCHED. Every plane is under the scratch root; A-563:52-56 forbids')
[Console]::Out.WriteLine('  self-capture      greening the self-capture leg from inside a session.')

Write-Head '=== A14 RESULT ================================================================='
[Console]::Out.WriteLine("  mode    $mode  ($libSha, $libLen b)")
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
