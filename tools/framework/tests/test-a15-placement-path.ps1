# test-a15-placement-path.ps1 -- A15: the PLACEMENT PATH acceptance instrument. Authority: the
# RATIFIED docs/framework/evidence-placement-input-contract-spec.md,
# assertion A-568, and the operator's ruling with OPEN-A ruled (A-i).
#
# PLACEMENT AND PROVENANCE, STATED FIRST BECAUSE IT DECIDES WHO MAY RUN THIS. This instrument lands
# at tools/framework/tests/ and is OPERATOR-PLACED AND OPERATOR-RUN. tools/framework/tests is in the
# protected set (evidence-common.ps1:1062), so an agent can neither write nor run it there, and an
# instrument an agent placed or drove would be the agent grading itself. The builder session
# authored these bytes in its scratchpad and handed them over with their sha256. EVERY FIGURE THIS
# INSTRUMENT PRINTS AT THE OPERATOR'S SITTING IS THE OPERATOR'S -- the A5 discipline, whose seal
# entry states it plainly: "THE SESSION RAN NO SUITE AND CLAIMS NONE."
#
# WHAT THIS INSTRUMENT DECIDES. Every MUST the ratified contract places on the placement path, each
# with a PLANTED BREAKAGE that must kill it alone:
#   D01  SS 5.1  the staging path is an explicit parameter, NOT defaulted and NOT discovered.
#   D02  SS 5.5  the destination name is explicit and is NOT derived from a payload session_id.
#   D02R SS 5.4 AS REVISED (operator, 2026-08-17)  the destination-name predicate is the anchored
#                       ^[A-Za-z0-9][A-Za-z0-9_.-]*$, it is a SEPARATE variable from the unrevised
#                       SS 5.3 item 4 predicate, and it REFUSES `.`, `..`, a leading `-` and a
#                       leading `.`.
#   D03a-g SS 5.3 all SEVEN substrate requirements enforced -- seven independent drives.
#   D04  SS 5.3 item 4  declared-terminal-activity.txt REQUIRED; no default terminal activity
#                       is assigned anywhere in the placement code (explicit or refuse).
#   D05  SS 6.5/7.3.2  every source digest re-derived against the substrate's own manifest.
#   D06  SS 7.3.2  the file set is EXACTLY the manifest's -- no missing member, no extra file.
#   D07  SS 6.5  every destination digest re-derived after the copy.
#   D08  SS 6.5  a placement record is written.
#   D09  SS 7.1  ABSENT -> refuse, place nothing, exit non-zero, DO NOT create the destination.
#   D10  SS 7.2  MALFORMED -> report EVERY violation, not the first.
#   D11  SS 7.2  MALFORMED -> MUST NOT place the well-formed subset.
#   D12  SS 7.3.4  PARTIAL -> refuse per file, NO retry and NO wait-and-re-read.
#   D13  SS 7.4  INDETERMINATE -> name placed and not-placed, report no success, ATTEMPT NO ROLLBACK.
#   D14  A-568:58-61  both guard arrays unchanged -- must RED "EVEN IF every placement leg passes".
#   D15  SS 6.2  THE COMPOSITE-LAUNDERING SHAPE. The contract calls SS 6.2 its most important
#                sentence: a laundering path "does so WITHOUT touching either protected array -- so
#                A-568's array-diff criterion would pass while the property was gone." D15 asserts
#                what the diff cannot: no settings surface names the placement script (D15a), no
#                agent-writable marker or gate file decides whether placement happens (D15b), the
#                script sits inside the live protected set (D15c), and D14 STAYS GREEN under each
#                D15 mutation (D15P1, D15P2) -- THE PAIR THAT PROVES THE CRITERION IS NECESSARY BUT
#                NOT SUFFICIENT, and the single most important drive in this battery.
#   S01-S03  the UNWIRED verify leg: it matches a good destination, it catches destination drift,
#            and it is wired to nothing. Supplementary to the contract's MUSTs, not a substitute for
#            any drive above.
#
# NON-VACUITY IS MECHANICAL HERE. Every planted breakage is applied by literal string replacement to
# a COPY in the scratch root, and A MUTATION WHOSE ANCHOR IS NOT FOUND IS A FAILED CHECK, not a
# silent no-op. That is the kill-signal discipline in enforceable form: each drive proves
# its signal EXISTS by observing it on the unmutated build, then proves the drive is not vacuous by
# observing that the mutant no longer produces it.
#
# WHAT THIS INSTRUMENT DOES NOT DECIDE, stated so no reader infers more from a green run:
#   - A-568 IS NOT DISCHARGED HERE. Contract SS 9.2 lists FIVE conjunctive retirement conditions for
#     the interim. Condition 3 (an operator-registered payload capture for the wired leg)
#     is OPEN because the verify leg is BUILT AND NOT WIRED, and the "if any" in its wording is NOT
#     read as vacuous satisfaction -- OPEN-A was ruled (A-i), which rules a verify leg IS wired
#     eventually. Condition 4 (a REAL substrate placed, destination digests re-derived and recorded)
#     is not satisfiable by any fixture and is the binding gap. THE INTERIM DOES NOT RETIRE.
#   - IT DOES NOT PROMOTE THE GUARD. Contract SS 2.7 / evidence-guard-pretooluse.ps1:8-15: the guard
#     "is NOT a boundary... an agent that wants in gets in." D15c asserts that the placement script's
#     directory is a MEMBER of the live $script:EvidenceProtectedPaths, parsed from the library at
#     run time. It does not re-prove what the guard does with that set; that is A1's attested
#     property and this file rests no new claim on it.
#   - IT DOES NOT DECIDE BYTE-IDENTITY OF THE GUARD ARRAYS, ONLY THEIR CONTENT. D14 parses each
#     array's members and compares the ordered list to the expected list, and PRINTS the sha256 of
#     each array's region text so a reader has the figure. A pure reformatting that preserves every
#     member would pass D14. Byte-identity is decided by the commit's own path set, which is a
#     ceremony record and not this file's claim. STATED, not glossed.
#   - IT NEVER TOUCHES THE REAL EVIDENCE STORE. Every placement drive is given an explicit
#     -RepositoryRootPath inside the scratch root, so every destination this file creates is a
#     scratch destination. Nothing is written under the repository's own .mission/evidence or
#     .mission-runtime/evidence, and nothing under tools/framework/** is written, staged or mutated
#     in place -- mutants are COPIES in the scratch root.
#   - IT DOES NOT PROVOKE AN INTERACTIVE PROMPT. D01 and D02 decide mandatory-ness by inspecting the
#     parameter DECLARATION rather than by omitting a mandatory argument in a redirected child
#     process, which would block on a console prompt that never arrives. Disclosed as a choice.
#   - A source-text predicate decides the SHAPES ENUMERATED IN D15b, not arbitrary obfuscated gates.
#     Registered as a residual, in the SS 11.3 form.
#
# ANCHOR BASIS: CONTENT- AND CONSTRUCTION-ANCHORED. It anchors to NO sealed digest and moves none.
# It mutates only COPIES under a scratch root beneath $env:TEMP and constructed substrate fixtures.
#
# INSTRUMENT LAWS: (a) pure ASCII source; (b) path variables carry a Path suffix;
# (c) every child process runs through a redirected System.Diagnostics.Process, so a native stderr
# byte can never surface as a PowerShell error record under PS 5.1.
#
# EXIT CONTRACT (printed at run time): 0 = every check passed. 2 = anchor guard failed (a subject
# file was not found; no check was decided). 4 = one or more checks failed. NON-UNIQUENESS
# DISCLOSED: exit 4 is also A5's, A9's, A10's, A11's, A12's and A13's failing exit; exit 2 is also
# A10's, A11's, A12's and A13's anchor-guard exit. Read the printed counts, not the code alone.
#
# REACH: this instrument decides whether the placement path BEHAVES as the ratified contract
# specifies, against constructed substrate fixtures. It cannot decide whether the contract is right,
# it does not place a real witness substrate, and a green run is not a discharge.

#requires -Version 5.0
param(
    [string]$RepositoryRootPath = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
    [string]$PlacementScriptPath = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks') 'evidence-place-substrate.ps1'),
    [string]$VerifyLegPath = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks') 'evidence-verify-placement.ps1'),
    [string]$LibraryPath = (Join-Path (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks') 'lib') 'evidence-common.ps1'),
    [string]$SettingsFragmentPath = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks') 'settings.evidence-hooks.json'),
    [string]$ScratchRootPath = (Join-Path $env:TEMP ('a15-scratch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))),
    [switch]$KeepScratch
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:PassCount = 0
$script:FailCount = 0
$script:FailingIds = @()
$script:DriveSerial = 0

function Add-Result {
    param([string]$Id, [bool]$Ok, [string]$Detail)
    if ($Ok) { $script:PassCount++; $verdict = 'PASS' }
    else { $script:FailCount++; $script:FailingIds += $Id; $verdict = 'FAIL' }
    [Console]::Out.WriteLine(("  {0}  {1,-9} {2}" -f $verdict, $Id, $Detail))
}

function Write-Head { param([string]$Text) [Console]::Out.WriteLine(''); [Console]::Out.WriteLine($Text) }
function Write-Line { param([AllowEmptyString()][string]$Text) [Console]::Out.WriteLine($Text) }

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
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $so = $p.StandardOutput.ReadToEnd()
    $se = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $rc = $p.ExitCode
    $p.Dispose()
    $sw.Stop()
    return [pscustomobject]@{ StdOut = $so; StdErr = $se; ExitCode = $rc; ElapsedMs = $sw.ElapsedMilliseconds }
}

function Write-Utf8NoBom {
    <# Erratum #12: Set-Content -Encoding UTF8 emits a BOM under PS 5.1. Never used in this file. #>
    param([string]$Path, [string]$Text)
    $dirPath = Split-Path -Parent $Path
    if ($dirPath -and -not (Test-Path -LiteralPath $dirPath)) { [void][System.IO.Directory]::CreateDirectory($dirPath) }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-Utf8WithBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($true)))
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

function Get-FirstThreeBytesHex {
    param([string]$Path)
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $buf = New-Object byte[] 3
        $n = $fs.Read($buf, 0, 3)
        $out = ''
        for ($i = 0; $i -lt $n; $i++) { $out += $buf[$i].ToString('x2') }
        return $out
    }
    finally { $fs.Dispose() }
}

function Get-CodeText {
    <#
        The subject's source with COMMENTS REMOVED: block comments first, then whole-line hash
        comments. Every source predicate below runs on this, never on the raw file. Without it a
        script that DOCUMENTS "MUST NOT be derived from session_id" would fail a scan for
        `session_id`, and the predicate would be deciding prose instead of code.
    #>
    param([string]$Text)
    $t = [regex]::Replace($Text, '(?s)<\#.*?\#>', '')
    $keep = @()
    foreach ($line in ($t -split "`r?`n")) {
        if ($line -match '^\s*#') { continue }
        $keep += $line
    }
    return ($keep -join "`n")
}

# =================================================================================================
# ANCHOR GUARD
# =================================================================================================

Write-Line '=== A15 -- THE PLACEMENT PATH ================================================='
Write-Line ("repository root  : {0}" -f $RepositoryRootPath)
Write-Line ("placement script : {0}" -f $PlacementScriptPath)
Write-Line ("verify leg       : {0}" -f $VerifyLegPath)
Write-Line ("library          : {0}" -f $LibraryPath)
Write-Line ("settings fragment: {0}" -f $SettingsFragmentPath)
Write-Line ("scratch root     : {0}" -f $ScratchRootPath)

$missing = @()
foreach ($pair in @(
        @{ Label = 'placement script'; Path = $PlacementScriptPath },
        @{ Label = 'verify leg'; Path = $VerifyLegPath },
        @{ Label = 'library'; Path = $LibraryPath },
        @{ Label = 'settings fragment'; Path = $SettingsFragmentPath })) {
    if (-not (Test-Path -LiteralPath $pair.Path -PathType Leaf)) { $missing += ("{0} not found at {1}" -f $pair.Label, $pair.Path) }
}
if ($missing.Count -gt 0) {
    Write-Line ''
    Write-Line 'ANCHOR GUARD FAILED. No check was decided.'
    foreach ($m in $missing) { Write-Line ("  - {0}" -f $m) }
    Write-Line 'EXIT: 2'
    exit 2
}

$powershellPath = (Get-Command powershell.exe -ErrorAction SilentlyContinue)
if (-not $powershellPath) {
    Write-Line ''
    Write-Line 'ANCHOR GUARD FAILED: powershell.exe not on PATH. No check was decided.'
    Write-Line 'EXIT: 2'
    exit 2
}
$powershellPath = $powershellPath.Source

[void][System.IO.Directory]::CreateDirectory($ScratchRootPath)
$mutantRootPath = Join-Path $ScratchRootPath 'mutants'
[void][System.IO.Directory]::CreateDirectory($mutantRootPath)

$placementSourceText = [System.IO.File]::ReadAllText($PlacementScriptPath)
$placementCodeText = Get-CodeText -Text $placementSourceText
$verifySourceText = [System.IO.File]::ReadAllText($VerifyLegPath)
$verifyCodeText = Get-CodeText -Text $verifySourceText

# =================================================================================================
# FIXTURES
# =================================================================================================

$script:GoodFiles = @{
    '02-compose-ps.txt'              = "NAME             STATUS`nproject-api      Up 3 minutes (healthy)`nproject-db       Up 3 minutes (healthy)`n"
    '03-pytest.txt'                  = "==================== 412 passed, 0 failed in 41.20s ====================`n"
    '04-event-history.json'          = "{`"events`":[{`"id`":1,`"name`":`"WorkflowExecutionStarted`"},{`"id`":2,`"name`":`"ACTIVITY_TASK_SCHEDULED`"},{`"id`":3,`"name`":`"live_walk_terminal`"}]}`n"
    'declared-terminal-activity.txt' = "live_walk_terminal`n"
}

function Write-SubstrateManifest {
    <#
        SS 7.3.3: "The manifest MUST be written last by the assembling party". It therefore cannot
        describe itself, and every set predicate downstream is evaluated over (files present MINUS
        the manifest). This helper is the assembling party in every drive.
    #>
    param([string]$DirectoryPath, [string]$ManifestFileName = '00-substrate-manifest.json')
    $entries = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $DirectoryPath -File | Sort-Object Name)) {
        if ($f.Name -eq $ManifestFileName) { continue }
        $entries += [pscustomobject]@{
            name              = $f.Name
            bytes             = $f.Length
            sha256            = (Get-FileSha256 -Path $f.FullName)
            first_three_bytes = (Get-FirstThreeBytesHex -Path $f.FullName)
        }
    }
    $json = ConvertTo-Json -InputObject ([pscustomobject]@{ substrate_manifest_version = 1; files = $entries }) -Depth 6
    Write-Utf8NoBom -Path (Join-Path $DirectoryPath $ManifestFileName) -Text ((($json -replace "`r`n", "`n")) + "`n")
}

function New-SubstrateFixture {
    <# Builds one staging directory. Returns its path. Post-manifest tampering is applied AFTER the
       manifest is written, which is exactly how a real partial write presents. #>
    param([string]$Path, [string]$Variant)
    [void][System.IO.Directory]::CreateDirectory($Path)
    if ($Variant -eq 'empty') { return $Path }

    $skip = @()
    switch ($Variant) {
        'no-compose' { $skip = @('02-compose-ps.txt') }
        'no-pytest' { $skip = @('03-pytest.txt') }
        'no-eventhistory' { $skip = @('04-event-history.json') }
        'no-declared' { $skip = @('declared-terminal-activity.txt') }
        'multi-violation' { $skip = @('02-compose-ps.txt', '03-pytest.txt', 'declared-terminal-activity.txt') }
    }
    foreach ($name in $script:GoodFiles.Keys) {
        if ($skip -contains $name) { continue }
        $target = Join-Path $Path $name
        if ($Variant -eq 'has-bom' -and $name -eq '03-pytest.txt') { Write-Utf8WithBom -Path $target -Text $script:GoodFiles[$name] }
        else { Write-Utf8NoBom -Path $target -Text $script:GoodFiles[$name] }
    }
    if ($Variant -eq 'bad-declared-line') {
        Write-Utf8NoBom -Path (Join-Path $Path 'declared-terminal-activity.txt') -Text "not a valid name`n"
    }
    if ($Variant -eq 'has-subdir') {
        $subPath = Join-Path $Path 'nested'
        [void][System.IO.Directory]::CreateDirectory($subPath)
        Write-Utf8NoBom -Path (Join-Path $subPath 'stray.txt') -Text "stray`n"
    }

    Write-SubstrateManifest -DirectoryPath $Path

    switch ($Variant) {
        'no-manifest' { Remove-Item -LiteralPath (Join-Path $Path '00-substrate-manifest.json') -Force }
        'extra-file' { Write-Utf8NoBom -Path (Join-Path $Path '99-unnamed-extra.txt') -Text "extra`n" }
        'missing-file' { Remove-Item -LiteralPath (Join-Path $Path '03-pytest.txt') -Force }
        'digest-drift' {
            # Same byte length, different content, first three bytes untouched -- so ONLY the sha256
            # predicate can catch it. That makes D05's kill signal unambiguous.
            $p = Join-Path $Path '03-pytest.txt'
            $original = [System.IO.File]::ReadAllText($p)
            $drifted = $original.Substring(0, $original.Length - 12) + 'XXXXXXXXXXX' + "`n"
            Write-Utf8NoBom -Path $p -Text $drifted
        }
    }
    return $Path
}

function New-DriveContext {
    <# A fresh faux repository root plus a staging directory that is its SIBLING, never its child --
       contract SS 5.2 forbids a staging directory inside the working tree. #>
    param([string]$Variant)
    $script:DriveSerial++
    $tag = ('d{0:d3}' -f $script:DriveSerial)
    $repoPath = Join-Path $ScratchRootPath ('repo-' + $tag)
    [void][System.IO.Directory]::CreateDirectory($repoPath)
    $stagingPath = Join-Path $ScratchRootPath ('staging-' + $tag)
    if ($Variant -ne 'absent') { [void](New-SubstrateFixture -Path $stagingPath -Variant $Variant) }
    return [pscustomobject]@{
        RepoPath        = $repoPath
        StagingPath     = $stagingPath
        SubstrateName   = 'a15-scratch-substrate'
        DestinationPath = (Join-Path (Join-Path (Join-Path $repoPath '.mission') 'evidence') 'a15-scratch-substrate')
    }
}

function Invoke-Placement {
    param([string]$ScriptPath, $Context, [string[]]$ExtraArguments = @())
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath,
        '-StagingPath', $Context.StagingPath,
        '-SubstrateName', $Context.SubstrateName,
        '-RepositoryRootPath', $Context.RepoPath) + $ExtraArguments
    return (Invoke-Child -FilePath $powershellPath -ArgumentList $argv -WorkingDirectoryPath $ScratchRootPath)
}

function New-Mutant {
    <#
        A COPY of the subject with literal replacements applied. AN ANCHOR THAT IS NOT FOUND THROWS:
        a mutation that silently no-ops would make its drive vacuous while still printing PASS, which
        is the exact failure an earlier erratum was banked for.
    #>
    param([string]$SourcePath, [string]$Id, $Replacements)
    # LF-normalised before matching, so a multi-line anchor cannot miss on line-ending class alone.
    $text = ([System.IO.File]::ReadAllText($SourcePath)) -replace "`r`n", "`n"
    foreach ($r in $Replacements) {
        if (-not $text.Contains($r.From)) {
            throw ("mutation '{0}': anchor not found in {1} -- the planted breakage would not have applied: <{2}>" -f $Id, $SourcePath, $r.From)
        }
        $text = $text.Replace($r.From, $r.To)
    }
    $outPath = Join-Path $mutantRootPath ($Id + '-' + (Split-Path $SourcePath -Leaf))
    [System.IO.File]::WriteAllText($outPath, $text, (New-Object System.Text.UTF8Encoding($false)))
    return $outPath
}

function Test-Mutant {
    <# Builds the mutant, or records the anchor failure as a FAILED check and returns $null. #>
    param([string]$Id, $Replacements, [string]$SourcePath = $PlacementScriptPath)
    try { return (New-Mutant -SourcePath $SourcePath -Id $Id -Replacements $Replacements) }
    catch { Add-Result -Id ($Id + '-anchor') -Ok $false -Detail $_.Exception.Message; return $null }
}

# =================================================================================================
# POSITIVE CONTROL -- the unmutated build against a well-formed substrate.
# =================================================================================================

Write-Head 'PC -- POSITIVE CONTROL (unmutated build, well-formed substrate, scratch destination)'

$pcContext = New-DriveContext -Variant 'wellformed'
$pc = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $pcContext
Add-Result -Id 'PC-exit' -Ok ($pc.ExitCode -eq 0) -Detail ("exit {0} (expected 0); OUTCOME line present: {1}" -f $pc.ExitCode, $pc.StdOut.Contains('OUTCOME: PLACED.'))
$pcPlaced = @()
if (Test-Path -LiteralPath $pcContext.DestinationPath) { $pcPlaced = @(Get-ChildItem -LiteralPath $pcContext.DestinationPath -File | ForEach-Object { $_.Name }) }
Add-Result -Id 'PC-files' -Ok ($pcPlaced.Count -eq 6) -Detail ("destination holds {0} file(s): {1}" -f $pcPlaced.Count, ($pcPlaced -join ', '))
$pcDigestsOk = $true
foreach ($n in @($script:GoodFiles.Keys)) {
    $srcPath = Join-Path $pcContext.StagingPath $n
    $dstPath = Join-Path $pcContext.DestinationPath $n
    if (-not (Test-Path -LiteralPath $dstPath)) { $pcDigestsOk = $false; continue }
    if ((Get-FileSha256 -Path $srcPath) -ne (Get-FileSha256 -Path $dstPath)) { $pcDigestsOk = $false }
}
Add-Result -Id 'PC-digest' -Ok $pcDigestsOk -Detail 'every source file re-derives equal at the destination'
Add-Result -Id 'PC-noclaim' -Ok ($pc.StdOut.Contains('the operator was NOT removed from the loop')) `
    -Detail 'the report does NOT claim operator elimination (contract SS 6.6: such a discharge is false)'
Add-Result -Id 'PC-stderr' -Ok ([string]::IsNullOrWhiteSpace($pc.StdErr)) -Detail ("stderr empty: <{0}>" -f $pc.StdErr.Trim())

# =================================================================================================
# D01 / D02 -- explicit parameters (SS 5.1, SS 5.5)
# =================================================================================================

Write-Head 'D01 -- SS 5.1: the staging path is EXPLICIT, not defaulted, not discovered'

$paramBlockMatch = [regex]::Match($placementCodeText, '(?s)param\s*\((.*?)\n\)')
$paramBlockText = ''
if ($paramBlockMatch.Success) { $paramBlockText = $paramBlockMatch.Groups[1].Value }

$stagingDeclOk = ($paramBlockText -match '(?s)\[Parameter\(Mandatory\s*=\s*\$true\)\]\s*\[ValidateNotNullOrEmpty\(\)\]\s*\[string\]\$StagingPath\s*,') -and
                 ($paramBlockText -notmatch '\$StagingPath\s*=')
Add-Result -Id 'D01-green' -Ok $stagingDeclOk -Detail 'StagingPath is declared Mandatory with NO default value'
$discoveryOk = ($placementCodeText -notmatch 'Get-ChildItem[^\n]*-Recurse') -and ($placementCodeText -notmatch 'Resolve-Path[^\n]*\*')
Add-Result -Id 'D01-nosearch' -Ok $discoveryOk -Detail 'no recursive search and no wildcard resolution: the input location is never discovered'

$m01 = Test-Mutant -Id 'M01' -Replacements @(
    @{ From = "    [Parameter(Mandatory = `$true)]`n    [ValidateNotNullOrEmpty()]`n    [string]`$StagingPath,"
       To   = "    [string]`$StagingPath = 'C:\a15-planted-default-staging'," })
if ($m01) {
    $m01Text = Get-CodeText -Text ([System.IO.File]::ReadAllText($m01))
    $m01Block = [regex]::Match($m01Text, '(?s)param\s*\((.*?)\n\)')
    $m01Defaulted = $m01Block.Success -and ($m01Block.Groups[1].Value -match '\$StagingPath\s*=')
    Add-Result -Id 'D01-kill' -Ok $m01Defaulted -Detail 'PLANTED: a default on StagingPath. The D01-green predicate no longer holds, so the drive is not vacuous'
}

Write-Head 'D02 -- SS 5.5: the destination name is EXPLICIT and never derived from a payload'

$nameDeclOk = ($paramBlockText -match '(?s)\[Parameter\(Mandatory\s*=\s*\$true\)\]\s*\[ValidateNotNullOrEmpty\(\)\]\s*\[string\]\$SubstrateName\s*,') -and
              ($paramBlockText -notmatch '\$SubstrateName\s*=')
Add-Result -Id 'D02-green' -Ok $nameDeclOk -Detail 'SubstrateName is declared Mandatory with NO default value'
$payloadTokens = @('session_id', 'hook_event_name', 'transcript_path', 'stop_hook_active', '[Console]::In', 'Read-Host', '$input')
$foundTokens = @($payloadTokens | Where-Object { $placementCodeText.Contains($_) })
Add-Result -Id 'D02-nopayload' -Ok ($foundTokens.Count -eq 0) `
    -Detail ("no payload/stdin token appears in CODE (comments stripped); found: {0}" -f (@($foundTokens) -join ', '))
Add-Result -Id 'D02-regex' -Ok ($placementCodeText.Contains("'^[A-Za-z0-9][A-Za-z0-9_.-]*`$'")) -Detail 'the SS 5.4 name predicate AS REVISED is implemented verbatim'

$m02 = Test-Mutant -Id 'M02' -Replacements @(
    @{ From = "    [Parameter(Mandatory = `$true)]`n    [ValidateNotNullOrEmpty()]`n    [string]`$SubstrateName,"
       To   = "    [string]`$SubstrateName = ([string](((([Console]::In.ReadToEnd()) | ConvertFrom-Json)).session_id))," })
if ($m02) {
    $m02Text = Get-CodeText -Text ([System.IO.File]::ReadAllText($m02))
    $m02Derived = $m02Text.Contains('session_id') -and $m02Text.Contains('[Console]::In')
    Add-Result -Id 'D02-kill' -Ok $m02Derived -Detail 'PLANTED: the name derived from a payload session_id read off stdin. Both D02 predicates now fail, so the drive is not vacuous'
}

# =================================================================================================
# D02R -- SS 5.4 AS REVISED (operator ruling, 2026-08-17; re-ratified contract sha256 2D817195).
#
# THE CURE. As originally ratified SS 5.4 required ^[A-Za-z0-9_.-]+$, which ACCEPTS `.` and `..` --
# either of which resolves .mission/evidence/<name>/ to the evidence plane's own root or to
# .mission/. The revised predicate anchors the first character to an alphanumeric. It is WIDER than
# the finding by ruling, and the widening is stated rather than absorbed: a leading `.` would create
# a hidden directory under the evidence root, and a leading `-` is parsed by PowerShell as a
# parameter rather than an argument at the SS 6.5 operator command.
#
# THE SPLIT IS PART OF THE CURE AND D02-split LOCKS IT IN. The revised predicate governs the
# DESTINATION NAME only. SS 5.3 item 4 -- declared-terminal-activity.txt's first non-empty line --
# was NOT revised, and it must keep ^[A-Za-z0-9_.-]+$ because that is the expression the real close
# gate applies at mission-lib.ps1:731. One shared variable serving both clauses would make the
# placement path refuse a substrate Test-WitnessedSubstrate accepts. D02-split asserts the two
# predicates are two separately named variables and that each site uses its own.
#
# KILL-SIGNAL PROVENANCE. The signal every D02R drive observes is the refusal line the
# CURED code emits at the SS 5.4 site. M02R reverts ONLY the predicate literal to the pre-cure
# expression; under it all four names match, the predicate does not trip, the signal is not produced
# AND THE SUBSTRATE IS PLACED. Both halves are asserted, so no drive here is vacuous. The mutant's
# anchor is the cured literal, and Test-Mutant records a missing anchor as a FAILED check.
# =================================================================================================

Write-Head 'D02R -- SS 5.4 AS REVISED: the anchored predicate, its split, and four refusals'

$splitOk = $placementCodeText.Contains("`$script:DestinationNamePattern = '^[A-Za-z0-9][A-Za-z0-9_.-]*`$'") -and
           $placementCodeText.Contains("`$script:DeclaredActivityPattern = '^[A-Za-z0-9_.-]+`$'") -and
           $placementCodeText.Contains('if ($SubstrateName -notmatch $script:DestinationNamePattern) {') -and
           $placementCodeText.Contains('elseif ($declaredActivity -notmatch $script:DeclaredActivityPattern) {')
Add-Result -Id 'D02-split' -Ok $splitOk `
    -Detail 'the SS 5.4 and SS 5.3-item-4 predicates are SEPARATE named variables and each site uses its own: the cure did not widen the unrevised clause away from mission-lib.ps1:731'

$script:PredicateSignal = 'does not match the contract SS 5.4 predicate'

$refusedNames = @(
    @{ Id = 'dot'; Name = '.'; Why = 'resolves the destination to the evidence root itself -- the finding' },
    @{ Id = 'dotdot'; Name = '..'; Why = 'resolves the destination to .mission/ -- the finding' },
    @{ Id = 'leadhyphen'; Name = '-a15-planted'; Why = 'PowerShell parses a leading hyphen as a parameter at the SS 6.5 command -- the widening' },
    @{ Id = 'leaddot'; Name = '.a15-planted'; Why = 'a hidden directory under the evidence root -- the widening' }
)

function Invoke-PlacementNamed {
    <# A well-formed substrate with ONLY the destination name varied, so nothing but the SS 5.4
       predicate can decide the outcome. #>
    param([string]$ScriptPath, $Context, [string]$Name)
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath,
        '-StagingPath', $Context.StagingPath,
        '-SubstrateName', $Name,
        '-RepositoryRootPath', $Context.RepoPath)
    return (Invoke-Child -FilePath $powershellPath -ArgumentList $argv -WorkingDirectoryPath $ScratchRootPath)
}

$m02r = Test-Mutant -Id 'M02R' -Replacements @(
    @{ From = "`$script:DestinationNamePattern = '^[A-Za-z0-9][A-Za-z0-9_.-]*`$'"
       To   = "`$script:DestinationNamePattern = '^[A-Za-z0-9_.-]+`$'" })

foreach ($r in $refusedNames) {
    $ctx = New-DriveContext -Variant 'wellformed'
    $evidenceRootPath = Join-Path (Join-Path $ctx.RepoPath '.mission') 'evidence'
    $green = Invoke-PlacementNamed -ScriptPath $PlacementScriptPath -Context $ctx -Name $r.Name
    $signalPresent = $green.StdOut.Contains($script:PredicateSignal)
    $rootCreated = Test-Path -LiteralPath $evidenceRootPath
    Add-Result -Id ('D02R-' + $r.Id) -Ok (($green.ExitCode -eq 6) -and $signalPresent -and (-not $rootCreated)) `
        -Detail ("name '{0}' REFUSED ({1}): exit {2}, predicate signal present: {3}, evidence root created: {4}" -f $r.Name, $r.Why, $green.ExitCode, $signalPresent, $rootCreated)

    if ($m02r) {
        $ctx2 = New-DriveContext -Variant 'wellformed'
        $red = Invoke-PlacementNamed -ScriptPath $m02r -Context $ctx2 -Name $r.Name
        Add-Result -Id ('D02R-' + $r.Id + '-kill') -Ok ((-not $red.StdOut.Contains($script:PredicateSignal)) -and ($red.ExitCode -eq 0)) `
            -Detail ("PLANTED: the pre-cure predicate restored -> '{0}' no longer trips it, the refusal signal is NOT produced and the substrate is PLACED (mutant exit {1}, scratch faux-repo only); the drive is not vacuous" -f $r.Name, $red.ExitCode)
    }
}

# =================================================================================================
# D03a-g -- SS 5.3 all seven substrate requirements, seven independent drives
# =================================================================================================

Write-Head 'D03a-g -- SS 5.3: all SEVEN substrate requirements, one independent drive each'

$sevenDrives = @(
    @{ Id = 'D03a'; Item = 1; Variant = 'no-compose'; Signal = 'SS 5.3 item 1:'
       Replacements = @(@{ From = "if (-not (Test-AnyMatch -Names `$substrateNames -Wildcard '02-compose-ps*' -Pattern 'Up\b.*healthy' -StagingDirectoryPath `$StagingPath)) {"; To = 'if ($false) {' }) },
    @{ Id = 'D03b'; Item = 2; Variant = 'no-pytest'; Signal = 'SS 5.3 item 2:'
       Replacements = @(@{ From = "if (-not (Test-AnyMatch -Names `$substrateNames -Wildcard '03-pytest*' -Pattern '(?m)\b\d+\s+passed\b' -StagingDirectoryPath `$StagingPath)) {"; To = 'if ($false) {' }) },
    @{ Id = 'D03c'; Item = 3; Variant = 'no-eventhistory'; Signal = 'SS 5.3 item 3:'
       # Requirement 3 has two halves -- real event structure AND the declared terminal activity --
       # and dropping "the requirement" means dropping both. A one-half mutation would leave the
       # other half still emitting the signal and the drive would be vacuous while printing PASS.
       Replacements = @(
           @{ From = 'if (-not $eventStructureOk) {'; To = 'if ($false) {' },
           @{ From = '    if (-not $activityPresent) {'; To = '    if ($false) {' }) },
    @{ Id = 'D03d'; Item = 4; Variant = 'no-declared'; Signal = 'SS 5.3 item 4:'
       Replacements = @(@{ From = "    `$malformed += `"SS 5.3 item 4: 'declared-terminal-activity.txt' is absent. This contract REQUIRES it, as the gate does -- explicit or refuse; no default terminal activity exists to inherit`""; To = '    $null = $substrateNames' }) },
    @{ Id = 'D03e'; Item = 5; Variant = 'has-subdir'; Signal = 'SS 5.3 item 5 (flat):'
       Replacements = @(@{ From = "    `$malformed += (`"SS 5.3 item 5 (flat): '{0}' is a subdirectory of the staging directory`" -f `$d)"; To = '    $null = $d' }) },
    @{ Id = 'D03f'; Item = 6; Variant = 'no-manifest'; Signal = 'SS 5.3 item 6 (manifest):'
       Replacements = @(
           @{ From = 'if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {'; To = 'if ($false) {' },
           @{ From = "try { `$manifest = (Get-Content -LiteralPath `$manifestPath -Raw) | ConvertFrom-Json }"
              To   = "try { if (Test-Path -LiteralPath `$manifestPath -PathType Leaf) { `$manifest = (Get-Content -LiteralPath `$manifestPath -Raw) | ConvertFrom-Json } else { `$synth = @(); foreach (`$sf in @(Get-ChildItem -LiteralPath `$StagingPath -File)) { `$synth += [pscustomobject]@{ name = `$sf.Name; bytes = `$sf.Length; sha256 = (Get-FileSha256 -Path `$sf.FullName); first_three_bytes = (Get-FirstThreeBytesHex -Path `$sf.FullName) } }; `$manifest = [pscustomobject]@{ files = `$synth } } }" }) },
    @{ Id = 'D03g'; Item = 7; Variant = 'has-bom'; Signal = 'SS 5.3 item 7:'
       Replacements = @(@{ From = "        `$malformed += (`"SS 5.3 item 7: '{0}' carries a UTF-8 BOM (first three bytes efbbbf)`" -f `$n)"; To = '        $null = $n' }) }
)

foreach ($drive in $sevenDrives) {
    $ctx = New-DriveContext -Variant $drive.Variant
    $green = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $ctx
    $refused = ($green.ExitCode -ne 0) -and $green.StdOut.Contains($drive.Signal) -and (-not (Test-Path -LiteralPath $ctx.DestinationPath))
    Add-Result -Id ($drive.Id + '-green') -Ok $refused `
        -Detail ("SS 5.3 item {0} violated -> exit {1}, signal '{2}' present: {3}, destination created: {4}" -f $drive.Item, $green.ExitCode, $drive.Signal, $green.StdOut.Contains($drive.Signal), (Test-Path -LiteralPath $ctx.DestinationPath))

    $mutantPath = Test-Mutant -Id ('M' + $drive.Id) -Replacements $drive.Replacements
    if ($mutantPath) {
        $ctx2 = New-DriveContext -Variant $drive.Variant
        $red = Invoke-Placement -ScriptPath $mutantPath -Context $ctx2
        $killed = -not $red.StdOut.Contains($drive.Signal)
        Add-Result -Id ($drive.Id + '-kill') -Ok $killed `
            -Detail ("PLANTED: requirement {0} dropped -> the signal '{1}' is no longer produced (mutant exit {2}); the drive is not vacuous" -f $drive.Item, $drive.Signal, $red.ExitCode)
    }
}

# =================================================================================================
# D04 -- SS 5.3 item 4: no default terminal activity is inherited
#
# UNCHANGED BY THE SS 5.4 CURE, AND DELIBERATELY SO. This drive decides the SS 5.3 item 4 predicate,
# which the operator did not revise. Both its fixtures behave identically under the pre-cure and
# post-cure expressions -- 'live_walk_terminal' passes both, 'not a valid name' fails both on the
# space -- so the cure moves nothing here and the drive's kill signal is untouched.
# =================================================================================================

Write-Head 'D04 -- SS 5.3 item 4: declared-terminal-activity.txt REQUIRED; no default terminal activity is inherited'

Add-Result -Id 'D04-nofallback' -Ok (-not ($placementCodeText -match '\$declaredActivity\s*=\s*[''"]')) `
    -Detail 'no string literal is ever assigned to $declaredActivity in CODE: it comes from the declaration file or not at all (M04 plants exactly such an assignment)'

$d04Context = New-DriveContext -Variant 'bad-declared-line'
$d04 = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d04Context
Add-Result -Id 'D04-predicate' -Ok (($d04.ExitCode -eq 3) -and $d04.StdOut.Contains('does not match')) `
    -Detail ("a first non-empty line failing ^[A-Za-z0-9_.-]+$ is refused: exit {0}" -f $d04.ExitCode)

$m04 = Test-Mutant -Id 'M04' -Replacements @(
    @{ From = "    `$malformed += `"SS 5.3 item 4: 'declared-terminal-activity.txt' is absent. This contract REQUIRES it, as the gate does -- explicit or refuse; no default terminal activity exists to inherit`""
       To   = "    `$declaredActivity = 'sample_terminal_activity'" })
if ($m04) {
    $ctx = New-DriveContext -Variant 'no-declared'
    $red = Invoke-Placement -ScriptPath $m04 -Context $ctx
    Add-Result -Id 'D04-kill' -Ok ($red.ExitCode -eq 0) `
        -Detail ("PLANTED: a default terminal activity assigned -> a substrate with NO declaration is PLACED (exit {0}); the drive is not vacuous" -f $red.ExitCode)
}

# =================================================================================================
# D05 / D06 -- SS 7.3.2 the partial-write predicate
# =================================================================================================

Write-Head 'D05 -- SS 6.5 / SS 7.3.2: every source digest re-derived against the substrate manifest'

$d05Context = New-DriveContext -Variant 'digest-drift'
$d05 = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d05Context
Add-Result -Id 'D05-green' -Ok (($d05.ExitCode -eq 4) -and $d05.StdOut.Contains('SS 7.3.2 (digest)') -and (-not (Test-Path -LiteralPath $d05Context.DestinationPath))) `
    -Detail ("a same-length content drift is caught by sha256 alone: exit {0}, nothing placed" -f $d05.ExitCode)

$m05 = Test-Mutant -Id 'M05' -Replacements @(
    @{ From = '    if ($actualSha -ne ([string]$e.sha256).ToLowerInvariant()) {'; To = '    if ($false) {' })
if ($m05) {
    $ctx = New-DriveContext -Variant 'digest-drift'
    $red = Invoke-Placement -ScriptPath $m05 -Context $ctx
    Add-Result -Id 'D05-kill' -Ok ($red.ExitCode -eq 0) `
        -Detail ("PLANTED: the source-digest comparison skipped -> the drifted substrate is PLACED (exit {0}); the drive is not vacuous" -f $red.ExitCode)
}

Write-Head 'D06 -- SS 7.3.2: the file set is EXACTLY the manifest set -- no extra, no missing'

$d06aContext = New-DriveContext -Variant 'extra-file'
$d06a = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d06aContext
Add-Result -Id 'D06-extra' -Ok (($d06a.ExitCode -eq 4) -and $d06a.StdOut.Contains('the manifest does not name it') -and (-not (Test-Path -LiteralPath $d06aContext.DestinationPath))) `
    -Detail ("an EXTRA file is as disqualifying as a missing one: exit {0}" -f $d06a.ExitCode)

$d06bContext = New-DriveContext -Variant 'missing-file'
$d06b = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d06bContext
Add-Result -Id 'D06-missing' -Ok (($d06b.ExitCode -eq 4) -and $d06b.StdOut.Contains('but it is not present in the staging directory') -and (-not (Test-Path -LiteralPath $d06bContext.DestinationPath))) `
    -Detail ("a manifest member absent from disk is refused per file: exit {0}" -f $d06b.ExitCode)

$m06 = Test-Mutant -Id 'M06' -Replacements @(
    @{ From = "        `$partial += (`"SS 7.3.2 (set equality): '{0}' is present but the manifest does not name it`" -f `$n)"; To = '        $null = $n' })
if ($m06) {
    $ctx = New-DriveContext -Variant 'extra-file'
    $red = Invoke-Placement -ScriptPath $m06 -Context $ctx
    Add-Result -Id 'D06-kill' -Ok ($red.ExitCode -eq 0) `
        -Detail ("PLANTED: an extra file tolerated -> the substrate is PLACED (exit {0}); the drive is not vacuous" -f $red.ExitCode)
}

# =================================================================================================
# D07 -- SS 6.5: destination digests re-derived. The leg the interim could not perform.
#
# Destination re-derivation is unobservable unless the destination DIFFERS from its source, so this
# drive plants a corrupting copy to make it observable. That is a statement about what can be
# measured, not a weakening: the corrupting-copy mutant proves the check is LIVE (exit 5), and the
# corrupting-copy-PLUS-skipped-re-derivation mutant proves it is LOAD-BEARING (exit 0).
# =================================================================================================

Write-Head 'D07 -- SS 6.5: every destination digest re-derived after the copy'

Add-Result -Id 'D07-source' -Ok ($placementCodeText.Contains('$dstSha = Get-FileSha256 -Path $dstPath')) `
    -Detail 'the destination path is hashed, not the source hash reused'

$corruptReplacement = @{ From = '        [System.IO.File]::Copy($srcPath, $dstPath, $false)'
                         To   = "        [System.IO.File]::Copy(`$srcPath, `$dstPath, `$false); [System.IO.File]::AppendAllText(`$dstPath, 'a15-planted-corruption')" }
$m07a = Test-Mutant -Id 'M07a' -Replacements @($corruptReplacement)
if ($m07a) {
    $ctx = New-DriveContext -Variant 'wellformed'
    $red = Invoke-Placement -ScriptPath $m07a -Context $ctx
    Add-Result -Id 'D07-green' -Ok (($red.ExitCode -eq 5) -and $red.StdOut.Contains('destination digest disagrees for')) `
        -Detail ("PLANTED: a corrupting copy -> the destination re-derivation CATCHES it, exit {0} INDETERMINATE. The kill signal exists" -f $red.ExitCode)
}
$m07b = Test-Mutant -Id 'M07b' -Replacements @($corruptReplacement,
    @{ From = '    $agree = ($srcSha -eq $dstSha) -and ([int64]$srcBytes -eq [int64]$dstBytes)'; To = '    $agree = $true' })
if ($m07b) {
    $ctx = New-DriveContext -Variant 'wellformed'
    $red = Invoke-Placement -ScriptPath $m07b -Context $ctx
    Add-Result -Id 'D07-kill' -Ok ($red.ExitCode -eq 0) `
        -Detail ("PLANTED: the same corrupting copy WITH destination re-derivation skipped -> corruption sails through as success (exit {0}); the drive is not vacuous" -f $red.ExitCode)
}

# =================================================================================================
# D08 -- SS 6.5: a placement record is written
# =================================================================================================

Write-Head 'D08 -- SS 6.5: a placement record is written'

$recordPath = Join-Path $pcContext.DestinationPath '00-placement-record.json'
$recordOk = Test-Path -LiteralPath $recordPath -PathType Leaf
$recordJson = $null
if ($recordOk) { $recordJson = (Get-Content -LiteralPath $recordPath -Raw) | ConvertFrom-Json }
Add-Result -Id 'D08-green' -Ok $recordOk -Detail ("the positive control's destination carries 00-placement-record.json: {0}" -f $recordOk)
if ($recordOk) {
    $hasFields = @('outcome', 'substrate_name', 'destination_path', 'files', 'destination_digests_rederived') |
        Where-Object { $recordJson.PSObject.Properties.Name -notcontains $_ }
    Add-Result -Id 'D08-fields' -Ok (@($hasFields).Count -eq 0) -Detail ("record carries every required field; missing: {0}" -f (@($hasFields) -join ', '))
    $perFile = @($recordJson.files | Where-Object { $_.destination_sha256 -and ($_.destination_sha256 -eq $_.source_sha256) })
    Add-Result -Id 'D08-digests' -Ok ($perFile.Count -eq 5) -Detail ("record carries a re-derived destination sha256 per file: {0} entries agree" -f $perFile.Count)
    Add-Result -Id 'D08-noclaim' -Ok (([string]$recordJson.trust_model_note).Contains('NOT operator elimination')) `
        -Detail 'the record does NOT claim the operator was removed from the loop (contract SS 6.6)'
    $recordHead = Get-FirstThreeBytesHex -Path $recordPath
    Add-Result -Id 'D08-nobom' -Ok ($recordHead -ne 'efbbbf') -Detail ("the record it writes is itself BOM-free: first three bytes {0}" -f $recordHead)
}

$m08 = Test-Mutant -Id 'M08' -Replacements @(
    @{ From = 'try { Write-Utf8NoBom -Path $recordPath -Text (ConvertTo-JsonLf -InputObject $record -Depth 6) }'; To = 'try { $null = $record }' })
if ($m08) {
    $ctx = New-DriveContext -Variant 'wellformed'
    $red = Invoke-Placement -ScriptPath $m08 -Context $ctx
    $noRecord = -not (Test-Path -LiteralPath (Join-Path $ctx.DestinationPath '00-placement-record.json'))
    Add-Result -Id 'D08-kill' -Ok $noRecord -Detail 'PLANTED: the record suppressed -> the destination carries no record; the drive is not vacuous'
}

# =================================================================================================
# D09 -- SS 7.1 ABSENT
# =================================================================================================

Write-Head 'D09 -- SS 7.1: ABSENT input -> refuse, place nothing, non-zero, DO NOT create the destination'

$d09Context = New-DriveContext -Variant 'absent'
$d09 = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d09Context
Add-Result -Id 'D09-green' -Ok (($d09.ExitCode -eq 2) -and (-not (Test-Path -LiteralPath $d09Context.DestinationPath))) `
    -Detail ("exit {0}, destination created: {1}" -f $d09.ExitCode, (Test-Path -LiteralPath $d09Context.DestinationPath))
Add-Result -Id 'D09-names' -Ok ($d09.StdOut.Contains($d09Context.StagingPath)) -Detail 'the refusal names the path AS GIVEN'

$d09eContext = New-DriveContext -Variant 'empty'
$d09e = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d09eContext
Add-Result -Id 'D09-empty' -Ok (($d09e.ExitCode -eq 2) -and (-not (Test-Path -LiteralPath $d09eContext.DestinationPath))) `
    -Detail ("an EMPTY staging directory is ABSENT input too: exit {0}" -f $d09e.ExitCode)

$m09 = Test-Mutant -Id 'M09' -Replacements @(
    @{ From = 'if (-not (Test-Path -LiteralPath $StagingPath)) {'
       To   = 'if (-not (Test-Path -LiteralPath $StagingPath)) { [void][System.IO.Directory]::CreateDirectory($destinationPath);' })
if ($m09) {
    $ctx = New-DriveContext -Variant 'absent'
    $red = Invoke-Placement -ScriptPath $m09 -Context $ctx
    Add-Result -Id 'D09-kill' -Ok (Test-Path -LiteralPath $ctx.DestinationPath) `
        -Detail 'PLANTED: the destination created on an ABSENT input -> it now exists; the drive is not vacuous'
}

# =================================================================================================
# D10 / D11 -- SS 7.2 MALFORMED
# =================================================================================================

Write-Head 'D10 -- SS 7.2: report EVERY violation, not the first'

$d10Context = New-DriveContext -Variant 'multi-violation'
$d10 = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $d10Context
$expectedSignals = @('SS 5.3 item 1:', 'SS 5.3 item 2:', 'SS 5.3 item 4:')
$presentSignals = @($expectedSignals | Where-Object { $d10.StdOut.Contains($_) })
Add-Result -Id 'D10-green' -Ok ($presentSignals.Count -eq 3) `
    -Detail ("three independent violations -> {0}/3 reported in one refusal (exit {1})" -f $presentSignals.Count, $d10.ExitCode)
Add-Result -Id 'D10-predicate' -Ok ($d10.StdOut.Contains('declared-terminal-activity.txt') -and $d10.StdOut.Contains("'02-compose-ps*'")) `
    -Detail 'each violation names the failing file and the specific predicate it failed'

$m10 = Test-Mutant -Id 'M10' -Replacements @(
    @{ From = '    foreach ($v in $list) { Write-Line ("  - {0}" -f $v) }'; To = '    Write-Line ("  - {0}" -f $list[0])' })
if ($m10) {
    $ctx = New-DriveContext -Variant 'multi-violation'
    $red = Invoke-Placement -ScriptPath $m10 -Context $ctx
    $redSignals = @($expectedSignals | Where-Object { $red.StdOut.Contains($_) })
    Add-Result -Id 'D10-kill' -Ok ($redSignals.Count -lt 3) `
        -Detail ("PLANTED: only the first violation printed -> {0}/3 reported; the drive is not vacuous" -f $redSignals.Count)
}

Write-Head 'D11 -- SS 7.2: MUST NOT place the well-formed subset'

Add-Result -Id 'D11-green' -Ok (-not (Test-Path -LiteralPath $d10Context.DestinationPath)) `
    -Detail 'a substrate with three violations placed NOTHING -- not even its well-formed members'

$m11 = Test-Mutant -Id 'M11' -Replacements @(
    @{ From = 'if ($malformed.Count -gt 0) {'; To = 'if ($false) {' })
if ($m11) {
    $ctx = New-DriveContext -Variant 'no-declared'
    $red = Invoke-Placement -ScriptPath $m11 -Context $ctx
    $subsetPlaced = (Test-Path -LiteralPath $ctx.DestinationPath) -and (@(Get-ChildItem -LiteralPath $ctx.DestinationPath -File).Count -gt 0)
    Add-Result -Id 'D11-kill' -Ok $subsetPlaced `
        -Detail 'PLANTED: the MALFORMED gate bypassed -> the well-formed subset IS placed; the drive is not vacuous'
}

# =================================================================================================
# D12 -- SS 7.3.4 no retry, no wait-and-re-read
# =================================================================================================

Write-Head 'D12 -- SS 7.3.4: PARTIAL refuses per file with NO retry and NO wait-and-re-read'

Add-Result -Id 'D12-source' -Ok (-not $placementCodeText.Contains('Start-Sleep')) -Detail 'no Start-Sleep exists in CODE: nothing waits and re-reads'
Add-Result -Id 'D12-green' -Ok (($d06b.ExitCode -eq 4) -and ($d06b.ElapsedMs -lt 5000)) `
    -Detail ("the missing-member drive refused in {0} ms -- a retry loop cannot be hiding in that window" -f $d06b.ElapsedMs)

$m12 = Test-Mutant -Id 'M12' -Replacements @(
    @{ From = 'if ($partial.Count -gt 0) {'; To = 'if ($partial.Count -gt 0) { Start-Sleep -Seconds 6;' })
if ($m12) {
    $ctx = New-DriveContext -Variant 'missing-file'
    $red = Invoke-Placement -ScriptPath $m12 -Context $ctx
    $mutantCode = Get-CodeText -Text ([System.IO.File]::ReadAllText($m12))
    Add-Result -Id 'D12-kill' -Ok ($mutantCode.Contains('Start-Sleep') -and ($red.ElapsedMs -gt $d06b.ElapsedMs + 4000)) `
        -Detail ("PLANTED: a wait-and-re-read -> Start-Sleep now in CODE and the run took {0} ms vs {1} ms; both signals fire, the drive is not vacuous" -f $red.ElapsedMs, $d06b.ElapsedMs)
}

# =================================================================================================
# D13 -- SS 7.4 INDETERMINATE, and NO ROLLBACK
# =================================================================================================

Write-Head 'D13 -- SS 7.4: INDETERMINATE names placed and not-placed, reports no success, rolls nothing back'

Add-Result -Id 'D13-source' -Ok ((-not $placementCodeText.Contains('Remove-Item')) -and (-not $placementCodeText.Contains('::Delete'))) `
    -Detail 'no Remove-Item and no ::Delete exist in CODE: the destructive-rollback class is absent by construction'

if ($m07a) {
    $ctx = New-DriveContext -Variant 'wellformed'
    $red = Invoke-Placement -ScriptPath $m07a -Context $ctx
    $survivors = @()
    if (Test-Path -LiteralPath $ctx.DestinationPath) { $survivors = @(Get-ChildItem -LiteralPath $ctx.DestinationPath -File | ForEach-Object { $_.Name }) }
    Add-Result -Id 'D13-green' -Ok (($red.ExitCode -eq 5) -and $red.StdOut.Contains('PLACED (') -and $red.StdOut.Contains('NOT PLACED (') -and (-not $red.StdOut.Contains('OUTCOME: PLACED.')) -and ($survivors.Count -gt 0)) `
        -Detail ("exit {0}; names PLACED and NOT PLACED; reports no success; {1} file(s) LEFT IN PLACE for the operator to resolve" -f $red.ExitCode, $survivors.Count)
    Add-Result -Id 'D13-norollback' -Ok ($red.StdOut.Contains('NO ROLLBACK WAS ATTEMPTED')) -Detail 'the report says so in those words'

    $m13 = Test-Mutant -Id 'M13' -Replacements @($corruptReplacement,
        @{ From = 'if ($indeterminate.Count -gt 0) {'
           To   = 'if ($indeterminate.Count -gt 0) { foreach ($rn in @($placedNames)) { Remove-Item -LiteralPath (Join-Path $destinationPath $rn) -Force }; Remove-Item -LiteralPath $destinationPath -Force -Recurse;' })
    if ($m13) {
        $ctx2 = New-DriveContext -Variant 'wellformed'
        $red2 = Invoke-Placement -ScriptPath $m13 -Context $ctx2
        Add-Result -Id 'D13-kill' -Ok (-not (Test-Path -LiteralPath $ctx2.DestinationPath)) `
            -Detail ("PLANTED: a rollback on INDETERMINATE -> the destination is DELETED (exit {0}), destroying what the operator must resolve; the drive is not vacuous" -f $red2.ExitCode)
    }
}

# =================================================================================================
# D14 -- THE ARRAY DIFF (A-568:58-61). Must RED even if every placement leg passes.
# =================================================================================================

Write-Head 'D14 -- A-568:58-61: both guard arrays unchanged, at the ranges re-derived at run time'

$script:ExpectedProtected = @(
    '.mission-runtime/evidence',
    '.mission/evidence',
    'tools/framework/hooks',
    'tools/framework/install-evidence-hooks.ps1',
    'tools/framework/tests',
    '.claude/settings.json')
$script:ExpectedCeremony = @('.mission/evidence')

function Get-ArrayRegion {
    <#
        The array's region and members, LOCATED BY NAME AT RUN TIME rather than by baked line
        numbers. Contract SS 2.11 is the reason: A-568 and the ruling both cite :1003-1010 and :1021,
        which a later delta moved by +54 lines, and "a discharge that diffs :1003-1010 at
        today's bytes would be diffing an unrelated region of the file and reporting EMPTY for the
        wrong reason." An instrument that re-locates by name cannot make that mistake.
    #>
    param([string]$Text, [string]$VariableName)
    $lines = $Text -split "`r?`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^\$script:' + [regex]::Escape($VariableName) + '\s*=\s*@\(')) { $start = $i; break }
    }
    if ($start -lt 0) { return $null }
    $end = $start
    if ($lines[$start] -notmatch '\)\s*$') {
        for ($j = $start + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j].Trim() -eq ')') { $end = $j; break }
        }
    }
    $regionLines = @()
    for ($k = $start; $k -le $end; $k++) { $regionLines += $lines[$k] }
    $regionText = ($regionLines -join "`n")
    $members = @([regex]::Matches($regionText, "'([^']*)'") | ForEach-Object { $_.Groups[1].Value })
    return [pscustomobject]@{
        StartLine  = $start + 1
        EndLine    = $end + 1
        RegionText = $regionText
        Members    = $members
        Sha256     = (Get-StringSha256 -Text $regionText)
    }
}

function Test-Arrays {
    param([string]$Text, [string]$Label)
    $protected = Get-ArrayRegion -Text $Text -VariableName 'EvidenceProtectedPaths'
    $ceremony = Get-ArrayRegion -Text $Text -VariableName 'EvidenceCeremonyPaths'
    if (-not $protected -or -not $ceremony) { return [pscustomobject]@{ Ok = $false; Detail = ("{0}: one or both arrays not found by name" -f $Label); Protected = $protected; Ceremony = $ceremony } }
    $pOk = ((@($protected.Members) -join '|') -eq (($script:ExpectedProtected) -join '|'))
    $cOk = ((@($ceremony.Members) -join '|') -eq (($script:ExpectedCeremony) -join '|'))
    $detail = ("{0}: EvidenceProtectedPaths :{1}-{2} sha256 {3} [{4} member(s)]; EvidenceCeremonyPaths :{5} sha256 {6} [{7} member(s)]" -f `
            $Label, $protected.StartLine, $protected.EndLine, $protected.Sha256.Substring(0, 8), @($protected.Members).Count,
        $ceremony.StartLine, $ceremony.Sha256.Substring(0, 8), @($ceremony.Members).Count)
    return [pscustomobject]@{ Ok = ($pOk -and $cOk); Detail = $detail; Protected = $protected; Ceremony = $ceremony }
}

$libraryText = [System.IO.File]::ReadAllText($LibraryPath)
$liveArrays = Test-Arrays -Text $libraryText -Label 'live library'
Add-Result -Id 'D14-green' -Ok $liveArrays.Ok -Detail $liveArrays.Detail
if ($liveArrays.Protected) {
    Write-Line ('    EvidenceProtectedPaths members: ' + (@($liveArrays.Protected.Members) -join ', '))
    Write-Line ('    EvidenceCeremonyPaths  members: ' + (@($liveArrays.Ceremony.Members) -join ', '))
    Write-Line ('    region sha256 (protected): ' + $liveArrays.Protected.Sha256)
    Write-Line ('    region sha256 (ceremony) : ' + $liveArrays.Ceremony.Sha256)
}

function New-ArrayMutation {
    <#
        Widen or narrow the located region STRUCTURALLY -- by line index off the region this run
        found -- rather than by a literal text anchor. A literal anchor would carry an assumption
        about indentation and trailing whitespace that this seat cannot verify without hashing a
        protected file, and an anchor that silently missed would print a vacuous PASS.
    #>
    param([string]$Text, $Region, [string]$Mode)
    $lines = $Text -split "`r?`n"
    $out = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNumber = $i + 1
        if ($Mode -eq 'widen' -and $lineNumber -eq $Region.EndLine) { $out += "    'tools/a15-planted-widening'," }
        if ($Mode -eq 'narrow' -and $lineNumber -eq ($Region.StartLine + 1)) { continue }
        $out += $lines[$i]
    }
    return ($out -join "`n")
}

if (-not $liveArrays.Protected) {
    Add-Result -Id 'D14-kill' -Ok $false -Detail 'the protected array was not located, so no planted breakage could be applied'
}
else {
    $widenedText = New-ArrayMutation -Text $libraryText -Region $liveArrays.Protected -Mode 'widen'
    $widened = Test-Arrays -Text $widenedText -Label 'widened'
    $widenedGrew = $widened.Protected -and (@($widened.Protected.Members).Count -eq (@($liveArrays.Protected.Members).Count + 1))
    Add-Result -Id 'D14-kill' -Ok ((-not $widened.Ok) -and $widenedGrew) -Detail ("PLANTED: EvidenceProtectedPaths WIDENED by one member -> " + $widened.Detail)

    $narrowedText = New-ArrayMutation -Text $libraryText -Region $liveArrays.Protected -Mode 'narrow'
    $narrowed = Test-Arrays -Text $narrowedText -Label 'narrowed'
    $narrowedShrank = $narrowed.Protected -and (@($narrowed.Protected.Members).Count -eq (@($liveArrays.Protected.Members).Count - 1))
    Add-Result -Id 'D14-kill2' -Ok ((-not $narrowed.Ok) -and $narrowedShrank) -Detail ("PLANTED: EvidenceProtectedPaths NARROWED by one member -> " + $narrowed.Detail)
}

# =================================================================================================
# D15 -- SS 6.2 THE COMPOSITE-LAUNDERING SHAPE. The single most important drive here.
# =================================================================================================

Write-Head 'D15 -- SS 6.2: the composite-laundering shape, which the array diff CANNOT see'

function Test-SettingsNamesScript {
    <#
        Does a settings surface's `hooks` key name the given script? The signal is PROVEN to exist:
        each of the four wired hooks is named by its own `command` string in this same key
        (settings.evidence-hooks.json :18, :30, :42, :54), so a basename search over the serialized
        `hooks` key finds a wired script when one is there. This is an observed signal, not an
        inference about intent.
    #>
    param([string]$Path, [string]$BaseName)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [pscustomobject]@{ Present = $false; Named = $false } }
    $obj = (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json
    if ($obj.PSObject.Properties.Name -notcontains 'hooks') { return [pscustomobject]@{ Present = $true; Named = $false } }
    $hooksText = ConvertTo-Json -InputObject $obj.hooks -Depth 12
    return [pscustomobject]@{ Present = $true; Named = $hooksText.Contains($BaseName) }
}

$placementBaseName = Split-Path $PlacementScriptPath -Leaf
$verifyBaseName = Split-Path $VerifyLegPath -Leaf
$derivedSettingsPath = Join-Path (Join-Path $RepositoryRootPath '.claude') 'settings.json'

$fragmentNames = Test-SettingsNamesScript -Path $SettingsFragmentPath -BaseName $placementBaseName
$derivedNames = Test-SettingsNamesScript -Path $derivedSettingsPath -BaseName $placementBaseName
Add-Result -Id 'D15a-fragment' -Ok (-not $fragmentNames.Named) `
    -Detail ("the TRACKED SOURCE OF TRUTH does not name {0} in its hooks key" -f $placementBaseName)
Add-Result -Id 'D15a-derived' -Ok (-not $derivedNames.Named) `
    -Detail ("the derived install does not name {0} (present on disk: {1})" -f $placementBaseName, $derivedNames.Present)

# The counterfactual: the SAME predicate over a fragment that DOES wire it. The signal is observed,
# not assumed -- (A-ii) was rejected and recorded "so it cannot return quietly", and this is the
# check that would see it return.
$fragmentText = [System.IO.File]::ReadAllText($SettingsFragmentPath)
$wiredFragmentPath = Join-Path $mutantRootPath 'M15a-settings.evidence-hooks.json'
$wiredFragmentText = $fragmentText.Replace('"Stop": [', ('"SessionEnd": [ { "matcher": "*", "hooks": [ { "type": "command", "command": "powershell -NoProfile -File \"$CLAUDE_PROJECT_DIR/tools/framework/hooks/' + $placementBaseName + '\"", "timeout": 60 } ] } ], "Stop": ['))
if ($wiredFragmentText -eq $fragmentText) { Add-Result -Id 'D15a-anchor' -Ok $false -Detail 'the wiring anchor was not found in the fragment: the planted breakage would not have applied' }
else {
    [System.IO.File]::WriteAllText($wiredFragmentPath, $wiredFragmentText, (New-Object System.Text.UTF8Encoding($false)))
    $wiredCheck = Test-SettingsNamesScript -Path $wiredFragmentPath -BaseName $placementBaseName
    Add-Result -Id 'D15a-kill' -Ok $wiredCheck.Named `
        -Detail 'PLANTED: the placement script wired to a hook event, BOTH ARRAYS UNTOUCHED -> the settings predicate FIRES. This is (A-ii) returning, and it is seen'
}

# D15b -- no agent-writable marker, trigger or gate file decides whether placement happens.
# The observable signal is a path-taking cmdlet whose target is a STRING LITERAL rather than a value
# derived from the two operator-supplied parameters. RESIDUAL, REGISTERED: this predicate decides
# the shapes enumerated here, not arbitrary obfuscated gates (the SS 11.3 form).
$literalPathPattern = "(Test-Path|Get-Content|Get-ChildItem|::Exists)\s*(\(\s*)?(-LiteralPath\s+|-Path\s+)?'"
$literalGates = @([regex]::Matches($placementCodeText, $literalPathPattern) | ForEach-Object { $_.Value })
Add-Result -Id 'D15b-green' -Ok ($literalGates.Count -eq 0) `
    -Detail ("no path-taking cmdlet targets a string literal: every path read derives from -StagingPath, -SubstrateName or -RepositoryRootPath; found {0}" -f $literalGates.Count)
Add-Result -Id 'D15b-nostdin' -Ok ((-not $placementCodeText.Contains('[Console]::In')) -and (-not $placementCodeText.Contains('Read-Host'))) `
    -Detail 'the script reads no stdin: nothing an agent writes can reach it through a payload'

$m15b = Test-Mutant -Id 'M15b' -Replacements @(
    @{ From = 'foreach ($n in $copyPlan) {'
       To   = "if (-not (Test-Path -LiteralPath 'C:\a15-planted-substrate-ready.marker')) { Write-Line 'gate closed'; exit 7 }`nforeach (`$n in `$copyPlan) {" })
if ($m15b) {
    $m15bCode = Get-CodeText -Text ([System.IO.File]::ReadAllText($m15b))
    $m15bGates = @([regex]::Matches($m15bCode, $literalPathPattern) | ForEach-Object { $_.Value })
    Add-Result -Id 'D15b-kill' -Ok ($m15bGates.Count -gt 0) `
        -Detail ("PLANTED: an agent-writable marker gates the copy, BOTH ARRAYS UNTOUCHED -> the literal-path predicate FIRES ({0} match). SS 6.3: what an agent cannot do is cause the operator to execute a command -- a marker gate hands that back" -f $m15bGates.Count)
    $ctx = New-DriveContext -Variant 'wellformed'
    $red = Invoke-Placement -ScriptPath $m15b -Context $ctx
    Add-Result -Id 'D15b-behaviour' -Ok (($red.ExitCode -eq 7) -and (-not (Test-Path -LiteralPath (Join-Path $ctx.DestinationPath '00-placement-record.json')))) `
        -Detail ("and the gate really does decide placement: a well-formed substrate is NOT placed while the marker is absent (exit {0})" -f $red.ExitCode)
}

# D15c -- the script sits inside the LIVE protected set. Parsed from the library at run time, not
# assumed. This asserts MEMBERSHIP; what the guard does with that set is A1's attested property and
# is not re-proven here (contract SS 2.7: the guard is a tripwire, not a boundary).
$placementFullPath = [System.IO.Path]::GetFullPath($PlacementScriptPath)
$repoFullPath = [System.IO.Path]::GetFullPath($RepositoryRootPath).TrimEnd('\', '/')
$relativePath = $placementFullPath
if ($placementFullPath.StartsWith($repoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    $relativePath = $placementFullPath.Substring($repoFullPath.Length).TrimStart('\', '/').Replace('\', '/')
}
$coveringMembers = @()
if ($liveArrays.Protected) {
    $coveringMembers = @($liveArrays.Protected.Members | Where-Object { $relativePath.StartsWith($_ + '/', [System.StringComparison]::OrdinalIgnoreCase) })
}
Add-Result -Id 'D15c-protected' -Ok ($coveringMembers.Count -gt 0) `
    -Detail ("'{0}' lies under live protected member(s): {1} -- contract SS 6.7's mechanism, with no array widened" -f $relativePath, (@($coveringMembers) -join ', '))

# D15P -- THE PAIR. D14 stays GREEN under each D15 mutation. This is what proves the array-diff
# criterion is NECESSARY BUT NOT SUFFICIENT, and it is the reason SS 6.2 calls itself the most
# important sentence in the contract.
$pairA = Test-Arrays -Text $libraryText -Label 'under the D15a mutation'
Add-Result -Id 'D15P1' -Ok ($pairA.Ok -and $wiredFragmentText -ne $fragmentText) `
    -Detail 'PAIR: with the placement script WIRED TO A HOOK EVENT, D14 is still GREEN -- the array diff passes while the property is gone'
$pairB = Test-Arrays -Text $libraryText -Label 'under the D15b mutation'
Add-Result -Id 'D15P2' -Ok ($pairB.Ok -and ($null -ne $m15b)) `
    -Detail 'PAIR: with an AGENT-WRITABLE MARKER GATE in the script, D14 is still GREEN -- the array diff passes while the property is gone'

# =================================================================================================
# S01-S03 -- THE UNWIRED VERIFY LEG. Supplementary; no contract MUST rides on these.
# =================================================================================================

Write-Head 'S01-S03 -- the verify leg: BUILT AND NOT WIRED'

$verifyGood = Invoke-Child -FilePath $powershellPath -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $VerifyLegPath,
    '-RepositoryRootPath', $pcContext.RepoPath, '-SubstrateName', $pcContext.SubstrateName) -WorkingDirectoryPath $ScratchRootPath
Add-Result -Id 'S01' -Ok (($verifyGood.ExitCode -eq 0) -and $verifyGood.StdOut.Contains('verdict: VERIFIED')) `
    -Detail ("a correctly placed destination re-derives clean: exit {0}" -f $verifyGood.ExitCode)

$driftContext = New-DriveContext -Variant 'wellformed'
$driftRun = Invoke-Placement -ScriptPath $PlacementScriptPath -Context $driftContext
if ($driftRun.ExitCode -eq 0) {
    [System.IO.File]::AppendAllText((Join-Path $driftContext.DestinationPath '03-pytest.txt'), 'post-placement drift')
    $verifyDrift = Invoke-Child -FilePath $powershellPath -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $VerifyLegPath,
        '-RepositoryRootPath', $driftContext.RepoPath, '-SubstrateName', $driftContext.SubstrateName) -WorkingDirectoryPath $ScratchRootPath
    Add-Result -Id 'S02' -Ok (($verifyDrift.ExitCode -eq 3) -and $verifyDrift.StdOut.Contains('drift AFTER placement')) `
        -Detail ("a destination byte changed after placement is caught against BOTH the manifest and the record: exit {0}" -f $verifyDrift.ExitCode)
}
else { Add-Result -Id 'S02' -Ok $false -Detail ("could not stage the drift drive: placement exited {0}" -f $driftRun.ExitCode) }

$verifyFragment = Test-SettingsNamesScript -Path $SettingsFragmentPath -BaseName $verifyBaseName
$verifyDerived = Test-SettingsNamesScript -Path $derivedSettingsPath -BaseName $verifyBaseName
$verifyUnwired = (-not $verifyFragment.Named) -and (-not $verifyDerived.Named) -and
                 (-not $verifyCodeText.Contains('[Console]::In')) -and (-not $verifyCodeText.Contains('hook_event_name')) -and
                 (-not $verifyCodeText.Contains('session_id'))
Add-Result -Id 'S03' -Ok $verifyUnwired `
    -Detail 'BUILT AND NOT WIRED: named by neither settings surface, reads no stdin and no payload field'
Write-Line '    Contract SS 9.2 retirement condition 3 is therefore OPEN, NOT SATISFIED. The "if any"'
Write-Line '    in its wording is NOT read as vacuous satisfaction: OPEN-A was ruled (A-i), which rules'
Write-Line '    that a verify leg IS wired eventually. Wiring is its own operator-gated act (SS 8.2-8.4).'

# =================================================================================================
# SUMMARY
# =================================================================================================

Write-Head '--- what a green run does NOT establish ----------------------------------------'
Write-Line '  The interim DOES NOT RETIRE. Contract SS 9.2 lists five conjunctive'
Write-Line '  conditions. Condition 3 is OPEN (the verify leg is unwired, no payload capture is'
Write-Line '  recorded). Condition 4 -- a REAL substrate placed with destination digests re-derived'
Write-Line '  and recorded -- IS NOT SATISFIABLE BY ANY FIXTURE and is the binding gap. A-568 is'
Write-Line '  ADVANCED at most; nothing here discharges it, and no ValidatorResult exists.'
Write-Line '  D14 decides array CONTENT, not byte-identity; the commit path set decides the bytes.'

Write-Head '=== SUMMARY ==================================================================='
Write-Line ("  passed : {0}" -f $script:PassCount)
Write-Line ("  failed : {0}" -f $script:FailCount)
if ($script:FailCount -gt 0) { Write-Line ("  failing: {0}" -f ((@($script:FailingIds)) -join ', ')) }

if (-not $KeepScratch) {
    try { Remove-Item -LiteralPath $ScratchRootPath -Recurse -Force -ErrorAction Stop }
    catch { Write-Line ("  note: scratch root not removed: {0}" -f $_.Exception.Message) }
}
else { Write-Line ("  scratch kept at: {0}" -f $ScratchRootPath) }

if ($script:FailCount -gt 0) { Write-Line 'EXIT: 4'; exit 4 }
Write-Line 'EXIT: 0'
exit 0
