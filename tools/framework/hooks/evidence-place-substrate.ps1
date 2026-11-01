# evidence-place-substrate.ps1 -- THE PLACEMENT PATH. Authority: the RATIFIED
# docs/framework/evidence-placement-input-contract-spec.md,
# assertion A-568, and the ruling with OPEN-A ruled (A-i).
#
# THIS IS NOT A HOOK. It carries no event name in its filename for that reason. It is wired to
# nothing, it is named by neither settings surface, and it reads no hook payload and no stdin. The
# contract's SS 4.4 is explicit: "The placement MUST be operator-initiated, and MUST NOT be
# initiated by a harness event." SS 4's OPEN-A was ruled (A-i) and (A-ii) -- a wired hook gated on a
# marker file -- was REJECTED and recorded "so it cannot return quietly." A future edit that wires
# this file to an event, or that gates it on a file an agent can write, reinstates (A-ii).
#
# WHY IT LIVES UNDER tools/framework/hooks/ WHEN IT IS NOT A HOOK. Contract SS 6.7: this directory
# is in $script:EvidenceProtectedPaths (evidence-common.ps1:1060), so an agent naming this script's
# path in a shell command is denied by the EXISTING matcher. That is the mechanism by which "not
# agent-invocable in effect" is achieved without adding a refusal and without widening any array --
# A-568:27-30's "by construction, not by exemption". THE HOME IS LOAD-BEARING, NOT A FILING
# CONVENTION. Moving this file to tools/ -- the unprotected CLI tier -- would satisfy every other
# clause here and destroy the property.
#
# WHAT IS ACTUALLY GAINED, AND WHAT IS NOT (contract SS 6.6, quoted because a discharge that
# overclaims is a FAIL): "The win is destination verification and a placement record, not operator
# elimination. A discharge claiming the operator was removed from the loop is false." SS 6.3 derives
# why: an agent can write the staging directory, compute any digest and compose any command; what it
# cannot do is cause the operator to execute one. THE OPERATOR STAYS IN THE LOOP. This script
# removes the UNVERIFIABLE part of the interim -- under the interim the destination "could
# NOT be re-derived ... no independent destination re-derivation was performed and none is claimed."
# Here it is re-derived, by a harness-side actor to which the guard's refusal does not apply.
#
# THE FAILURE DIRECTION IS INHERITED AND FIXED (contract SS 7.0, from
# evidence-guard-pretooluse.ps1:27-29): this path FAILS TOWARD NOT-PLACED, never toward
# partially-placed and never toward placed-without-record. A substrate half-present under
# .mission/evidence/ is worse than one absent, because Test-WitnessedSubstrate reads presence and
# shape and a partial substrate can satisfy a shape check it should have failed.
#
# IT NEVER ROLLS BACK (contract SS 7.4). Deleting under .mission/evidence is a destructive operation
# in the guard's parent tier (evidence-common.ps1:1065-1069) and the destructive-rollback class is
# where this program has been burned. "The operator resolves an INDETERMINATE destination; the
# script never does."
#
# EXIT CONTRACT:
#   0  PLACED. Every source digest agreed with the substrate's own manifest, every destination
#      digest was re-derived and agreed with its source, and the placement record was written.
#   2  REFUSED -- ABSENT input (contract SS 7.1). Nothing was placed; the destination was not created.
#   3  REFUSED -- MALFORMED input (contract SS 7.2). Nothing was placed; every violation is reported.
#   4  REFUSED -- PARTIALLY WRITTEN input (contract SS 7.3). Nothing was placed; the disagreement is
#      reported per file. No retry was attempted and no re-read was waited for.
#   5  INDETERMINATE destination (contract SS 7.4). The copy began. Every file placed and every file
#      not placed is named. NO SUCCESS IS REPORTED AND NO ROLLBACK WAS ATTEMPTED.
#   6  REFUSED -- precondition. The destination name, the staging path's location, or an already
#      occupied destination. Nothing was placed.
#   NON-UNIQUENESS DISCLOSED: these codes are this script's own; they are not a house-wide registry.
#   Read the printed OUTCOME line, not the code alone.
#
# DERIVED CHOICES, DISCLOSED AS CHOICES (contract SS 10.8: the contract "does not specify the
# placement script's implementation -- only the contract it must satisfy"):
#   - The substrate's own manifest is the file `00-substrate-manifest.json` in the staging
#     directory. The contract requires a manifest (SS 5.3 item 6) and names its four per-file fields
#     but not the file. The manifest does NOT describe itself: SS 7.3.3 requires it be "written last
#     by the assembling party", which makes self-description impossible. The set predicate of
#     SS 7.3.2 is therefore evaluated over (files present MINUS the manifest).
#   - The placement record is `00-placement-record.json`, written INSIDE the destination, so the
#     record travels with what it describes and is committed with it at the ceremony boundary. `00-`
#     is house convention for a leading record and matches no Test-WitnessedSubstrate glob, so the
#     record can neither satisfy nor break that gate.
#   - The manifest is COPIED to the destination alongside the substrate, so the completeness
#     declaration survives at the destination and the verify leg has something to re-derive against.
#   - The exit-code table above.
#   - Refusals write NOTHING anywhere under .mission/evidence, including no record file.
#   - An already-occupied destination is refused rather than merged into. The contract is silent;
#     refusing is the SS 7.0 direction.
#   - -RepositoryRootPath exists so the acceptance instrument can drive every leg against a scratch
#     destination. It defaults to this file's own three-parents-up location and the operator's
#     command does not pass it.
#
# CURED -- THE DESTINATION-NAME PREDICATE. As originally ratified, contract SS 5.4 required <name>
# to match ^[A-Za-z0-9_.-]+$, and that expression ACCEPTS `.` and `..`, either of which resolves
# .mission/evidence/<name>/ to the evidence plane's own root or to `.mission/`. The defect was found
# at cycle 12, REGISTERED and IMPLEMENTED-AS-RATIFIED by the increment that built this file --
# implementing the contract as written rather than its intention is the correct behavior -- and the
# operator CURED it by amendment on 2026-08-17. SS 5.4 AS REVISED requires <name> to match
# ^[A-Za-z0-9][A-Za-z0-9_.-]*$: a name MUST BEGIN WITH AN ALPHANUMERIC. This script implements the
# REVISED predicate at the SS 5.4 site and nowhere else.
#
# THE CURE IS SCOPED TO SS 5.4, AND THE SCOPING IS LOAD-BEARING. The revised predicate governs the
# DESTINATION NAME only. SS 5.3 item 4 -- the first non-empty line of declared-terminal-activity.txt
# -- was NOT revised and is NOT widened here: it keeps ^[A-Za-z0-9_.-]+$, which is the same
# expression the real close gate applies at mission-lib.ps1:731. Retargeting a single shared variable
# to both clauses would have made this script refuse a substrate that Test-WitnessedSubstrate
# accepts, from an unratified predicate change to a clause the operator did not rule on. The two
# predicates are therefore two separately named variables, and each names the clause it serves.
#
# INSTRUMENT LAWS: (a) pure ASCII source; (b) path variables carry a Path suffix;
# (c) no child process is started by this file at all, so no native stderr byte can surface as a
# PowerShell error record under PS 5.1.
#
# REACH: this script places one staging directory into one substrate destination and records what it
# did. It does not assemble substrates, does not decide whether a substrate's CONTENT is true, does
# not run Test-WitnessedSubstrate, and does not retire the interim -- the contract's
# SS 9.2 lists five conjunctive retirement conditions and this file is one of them, not all five.

#requires -Version 5.0
[CmdletBinding()]
param(
    # Contract SS 5.1: an explicit absolute path. MUST NOT be defaulted, MUST NOT be discovered by
    # search. There is deliberately no default value on this parameter and no discovery anywhere in
    # this file.
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StagingPath,

    # Contract SS 5.4/5.5: supplied explicitly by the operator. MUST NOT be derived from a hook
    # payload's session_id or from any inferred dispatch id. This file reads no payload and no stdin.
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubstrateName,

    [string]$RepositoryRootPath = (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ManifestFileName = '00-substrate-manifest.json'
$script:RecordFileName = '00-placement-record.json'
# SS 5.4 AS REVISED (operator, 2026-08-17). The first character is anchored: a destination name MUST
# begin with an alphanumeric. This excludes `.` and `..` -- the finding -- and, disclosed as a
# deliberate WIDENING rather than absorbed, any name beginning `.` (a hidden directory under the
# evidence root) or `-` (parsed by PowerShell as a parameter at the SS 6.5 operator command).
$script:DestinationNamePattern = '^[A-Za-z0-9][A-Za-z0-9_.-]*$'
# SS 5.3 item 4, UNREVISED BY THE CURE. Kept byte-identical to the expression the real close gate
# applies at mission-lib.ps1:731. Widening this one would make this script refuse a declared terminal
# activity that Test-WitnessedSubstrate accepts, diverging the placement path from the gate it feeds.
$script:DeclaredActivityPattern = '^[A-Za-z0-9_.-]+$'

function Write-Line { param([AllowEmptyString()][string]$Text) [Console]::Out.WriteLine($Text) }

function Write-Outcome {
    <#
        Every exit from this script goes through here, so no path can end without saying which of
        the contract's states holds. A-568:61-68 requires a discharge to say which of two states
        holds; the same discipline is applied to the script's own report.
    #>
    param([string]$Outcome, [string[]]$Violations, [int]$Code)
    Write-Line ''
    Write-Line ("OUTCOME: {0}" -f $Outcome)
    $list = @($Violations)
    if ($list.Count -gt 0) {
        Write-Line ("VIOLATIONS: {0}" -f $list.Count)
        foreach ($v in $list) { Write-Line ("  - {0}" -f $v) }
    }
    Write-Line ("EXIT: {0}" -f $Code)
    exit $Code
}

function Get-FileSha256 {
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($Path)
    try { return (($sha.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $fs.Dispose(); $sha.Dispose() }
}

function Get-FirstThreeBytesHex {
    <#
        Lowercase hex of the first min(3, length) bytes. Files shorter than three bytes yield a
        shorter string rather than a padded one, so a two-byte file is described honestly instead of
        being described as something it is not.
    #>
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

function Write-Utf8NoBom {
    <#
        Erratum #12: Set-Content -Encoding UTF8 emits a BOM under PS 5.1. This path never uses it.
        The placement record this writes is itself BOM-free, which matters because the record lands
        in the evidence plane beside files this same script refuses for carrying a BOM.
    #>
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-JsonLf {
    param($InputObject, [int]$Depth = 6)
    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth
    return (($json -replace "`r`n", "`n") + "`n")
}

# =================================================================================================
# SS 5.4 / SS 5.2 / precondition -- exit 6
# =================================================================================================

$pre = @()

if ($SubstrateName -notmatch $script:DestinationNamePattern) {
    $pre += ("destination name '{0}' does not match the contract SS 5.4 predicate {1}" -f $SubstrateName, $script:DestinationNamePattern)
}

if (-not [System.IO.Path]::IsPathRooted($StagingPath)) {
    $pre += ("staging path '{0}' is not an absolute path (contract SS 5.1 requires an explicit absolute path)" -f $StagingPath)
}

# Normalised, comparable forms. GetFullPath does not require the path to exist, so an absent staging
# directory still reaches SS 7.1's ABSENT case rather than dying here.
$stagingFullPath = $null
$repoFullPath = $null
try {
    $stagingFullPath = [System.IO.Path]::GetFullPath($StagingPath).TrimEnd('\', '/')
    $repoFullPath = [System.IO.Path]::GetFullPath($RepositoryRootPath).TrimEnd('\', '/')
}
catch {
    $pre += ("staging path '{0}' or repository root '{1}' could not be normalised: {2}" -f $StagingPath, $RepositoryRootPath, $_.Exception.Message)
}

if ($stagingFullPath -and $repoFullPath) {
    # Contract SS 5.2: "IT MUST NOT LIE INSIDE THE REPOSITORY." A staging directory inside the
    # working tree would be git-visible in `git status --porcelain`, which several ceremony gates
    # read as a cleanliness precondition, and it would sit inside the guard's parent tier
    # (evidence-common.ps1:1065-1069).
    $repoPrefix = $repoFullPath + [System.IO.Path]::DirectorySeparatorChar
    if ($stagingFullPath -eq $repoFullPath -or $stagingFullPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $pre += ("staging path '{0}' lies inside the repository working tree '{1}' (contract SS 5.2 forbids it)" -f $stagingFullPath, $repoFullPath)
    }
}

Write-Line '=== evidence-place-substrate ==================================================='
Write-Line ("staging     : {0}" -f $StagingPath)
Write-Line ("substrate   : {0}" -f $SubstrateName)
Write-Line ("repo root   : {0}" -f $RepositoryRootPath)

$destinationPath = $null
if ($repoFullPath) {
    $destinationPath = Join-Path (Join-Path (Join-Path $repoFullPath '.mission') 'evidence') $SubstrateName
    Write-Line ("destination : {0}" -f $destinationPath)
}

if ($destinationPath -and (Test-Path -LiteralPath $destinationPath)) {
    # The contract is silent on an occupied destination. Refusing is SS 7.0's direction: merging a
    # new substrate into an existing one produces exactly the half-present tree SS 7.0 calls worse
    # than an absent one.
    $pre += ("destination '{0}' already exists; this script refuses rather than merging into or overwriting an existing substrate" -f $destinationPath)
}

if ($pre.Count -gt 0) { Write-Outcome -Outcome 'REFUSED -- PRECONDITION. Nothing was placed.' -Violations $pre -Code 6 }

# =================================================================================================
# SS 7.1 ABSENT -- exit 2. Refuse, place nothing, name the path AS GIVEN. No substitute is searched
# for, the destination is not created, and no partial record is emitted.
# =================================================================================================

if (-not (Test-Path -LiteralPath $StagingPath)) {
    Write-Outcome -Outcome 'REFUSED -- ABSENT INPUT. Nothing was placed; the destination was not created.' `
        -Violations @(("staging directory does not exist: {0}" -f $StagingPath)) -Code 2
}

$stagingItem = Get-Item -LiteralPath $StagingPath
if (-not $stagingItem.PSIsContainer) {
    Write-Outcome -Outcome 'REFUSED -- ABSENT INPUT. Nothing was placed; the destination was not created.' `
        -Violations @(("staging path is not a directory: {0}" -f $StagingPath)) -Code 2
}

$stagingEntries = @(Get-ChildItem -LiteralPath $StagingPath -Force)
if ($stagingEntries.Count -eq 0) {
    Write-Outcome -Outcome 'REFUSED -- ABSENT INPUT. Nothing was placed; the destination was not created.' `
        -Violations @(("staging directory is empty: {0}" -f $StagingPath)) -Code 2
}

# =================================================================================================
# SS 7.3.3 -- THE MANIFEST IS RE-DERIVED FIRST. Everything below depends on it, so a substrate
# without a readable manifest is decided before any other predicate runs.
# =================================================================================================

$malformed = @()

$subdirectoryNames = @($stagingEntries | Where-Object { $_.PSIsContainer } | ForEach-Object { $_.Name })
foreach ($d in $subdirectoryNames) {
    # SS 5.3 item 5: MUST be flat.
    $malformed += ("SS 5.3 item 5 (flat): '{0}' is a subdirectory of the staging directory" -f $d)
}

$presentFiles = @($stagingEntries | Where-Object { -not $_.PSIsContainer })
$presentNames = @($presentFiles | ForEach-Object { $_.Name })

$manifestPath = Join-Path $StagingPath $script:ManifestFileName
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    # SS 7.3.1: "a substrate without one is not partially written, it is malformed."
    $malformed += ("SS 5.3 item 6 (manifest): '{0}' is absent; a substrate without its own manifest is MALFORMED, not partially written (SS 7.3.1)" -f $script:ManifestFileName)
    Write-Outcome -Outcome 'REFUSED -- MALFORMED INPUT. Nothing was placed.' -Violations $malformed -Code 3
}

$manifest = $null
try { $manifest = (Get-Content -LiteralPath $manifestPath -Raw) | ConvertFrom-Json }
catch {
    $malformed += ("SS 5.3 item 6 (manifest): '{0}' is not parseable JSON: {1}" -f $script:ManifestFileName, $_.Exception.Message)
    Write-Outcome -Outcome 'REFUSED -- MALFORMED INPUT. Nothing was placed.' -Violations $malformed -Code 3
}

$manifestEntries = @()
$manifestShapeOk = $true
if (-not ($manifest.PSObject.Properties.Name -contains 'files')) {
    $malformed += ("SS 5.3 item 6 (manifest): '{0}' has no 'files' member" -f $script:ManifestFileName)
    $manifestShapeOk = $false
}
else {
    $manifestEntries = @($manifest.files)
    if ($manifestEntries.Count -eq 0) {
        $malformed += ("SS 5.3 item 6 (manifest): '{0}' declares an empty file set" -f $script:ManifestFileName)
        $manifestShapeOk = $false
    }
    foreach ($e in $manifestEntries) {
        foreach ($field in @('name', 'bytes', 'sha256', 'first_three_bytes')) {
            if (-not ($e.PSObject.Properties.Name -contains $field)) {
                $label = '<unnamed entry>'
                if ($e.PSObject.Properties.Name -contains 'name') { $label = [string]$e.name }
                $malformed += ("SS 5.3 item 6 (manifest): entry '{0}' is missing the required field '{1}'" -f $label, $field)
                $manifestShapeOk = $false
            }
        }
    }
}
if (-not $manifestShapeOk) { Write-Outcome -Outcome 'REFUSED -- MALFORMED INPUT. Nothing was placed.' -Violations $malformed -Code 3 }

# =================================================================================================
# SS 7.3.2 -- THE PARTIAL-WRITE PREDICATE. Exact set equality, then exact per-file agreement. No
# retry and no wait-and-re-read: SS 7.3.4 says "a retry loop converts a partial write into a race
# the record cannot describe." There is no Start-Sleep anywhere in this file.
#
# CONTRACT-INTERNAL OVERLAP, RESOLVED AND DISCLOSED: SS 7.2 lists "any file whose re-derived sha256
# or byte length disagrees with the manifest" under MALFORMED, while SS 7.3.3 says of the same
# disagreement "Any disagreement is a partial write." The two clauses claim the same predicate. The
# OPERATIVE behaviour is identical under both readings -- refuse, place nothing, report per file --
# so nothing this script does turns on it. The LABEL is resolved toward SS 7.3 as the more specific
# clause, and the overlap is reported as a finding rather than absorbed silently.
# =================================================================================================

$manifestNames = @($manifestEntries | ForEach-Object { [string]$_.name })
$substrateNames = @($presentNames | Where-Object { $_ -ne $script:ManifestFileName })

$partial = @()

foreach ($n in $manifestNames) {
    if ($substrateNames -notcontains $n) {
        $partial += ("SS 7.3.2 (set equality): manifest names '{0}' but it is not present in the staging directory" -f $n)
    }
}
foreach ($n in $substrateNames) {
    if ($manifestNames -notcontains $n) {
        # SS 7.3.2: "An extra file is as disqualifying as a missing one: it means the manifest does
        # not describe what is on disk."
        $partial += ("SS 7.3.2 (set equality): '{0}' is present but the manifest does not name it" -f $n)
    }
}

$derived = @{}
foreach ($e in $manifestEntries) {
    $n = [string]$e.name
    $p = Join-Path $StagingPath $n
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
    $actualSha = Get-FileSha256 -Path $p
    $actualBytes = (Get-Item -LiteralPath $p).Length
    $actualHead = Get-FirstThreeBytesHex -Path $p
    $derived[$n] = [pscustomobject]@{ Sha256 = $actualSha; Bytes = $actualBytes; Head = $actualHead }

    if ($actualSha -ne ([string]$e.sha256).ToLowerInvariant()) {
        $partial += ("SS 7.3.2 (digest): '{0}' manifest sha256 {1}, re-derived {2}" -f $n, ([string]$e.sha256).ToLowerInvariant(), $actualSha)
    }
    if ([int64]$actualBytes -ne [int64]$e.bytes) {
        $partial += ("SS 7.3.2 (byte length): '{0}' manifest {1} bytes, re-derived {2} bytes" -f $n, [int64]$e.bytes, [int64]$actualBytes)
    }
    if ($actualHead -ne ([string]$e.first_three_bytes).ToLowerInvariant()) {
        $partial += ("SS 7.3.2 (first three bytes): '{0}' manifest {1}, re-derived {2}" -f $n, ([string]$e.first_three_bytes).ToLowerInvariant(), $actualHead)
    }
}

if ($partial.Count -gt 0) {
    Write-Outcome -Outcome 'REFUSED -- PARTIALLY WRITTEN INPUT. Nothing was placed; no retry was attempted and no re-read was waited for.' `
        -Violations $partial -Code 4
}

# =================================================================================================
# SS 5.3 items 1-5 and 7 -- THE MALFORMED PREDICATE. EVERY violation is reported, not the first
# (SS 7.2), and each names the failing file and the specific predicate it failed, because "a refusal
# that says only 'malformed' makes the operator re-derive the contract by trial."
# =================================================================================================

function Test-AnyMatch {
    param([string[]]$Names, [string]$Wildcard, [string]$Pattern, [string]$StagingDirectoryPath)
    foreach ($n in $Names) {
        if ($n -notlike $Wildcard) { continue }
        $text = Get-Content -LiteralPath (Join-Path $StagingDirectoryPath $n) -Raw -ErrorAction SilentlyContinue
        if ($null -eq $text) { continue }
        if ($text -match $Pattern) { return $true }
    }
    return $false
}

# SS 5.3 item 1 -- a 02-compose-ps* file matching `Up\b.*healthy`.
# INHERITED HOLE, REGISTERED NOT CURED (contract SS 11.3): this predicate
# also matches the literal `Up 2 days (unhealthy)`. The contract inherits it knowingly and rests no
# claim on the clause; so does this script.
if (-not (Test-AnyMatch -Names $substrateNames -Wildcard '02-compose-ps*' -Pattern 'Up\b.*healthy' -StagingDirectoryPath $StagingPath)) {
    $malformed += "SS 5.3 item 1: no '02-compose-ps*' file whose text matches 'Up\b.*healthy'"
}

# SS 5.3 item 2 -- a 03-pytest* file showing a pass.
if (-not (Test-AnyMatch -Names $substrateNames -Wildcard '03-pytest*' -Pattern '(?m)\b\d+\s+passed\b' -StagingDirectoryPath $StagingPath)) {
    $malformed += "SS 5.3 item 2: no '03-pytest*' file whose text shows a pass (no '<n> passed')"
}

# SS 5.3 item 3 -- a 04-event-history* file carrying real event structure AND the terminal activity.
$declaredPath = Join-Path $StagingPath 'declared-terminal-activity.txt'
$declaredActivity = $null
if ($substrateNames -contains 'declared-terminal-activity.txt') {
    $declaredRaw = Get-Content -LiteralPath $declaredPath -Raw
    foreach ($line in ($declaredRaw -split "`r?`n")) {
        if ($line.Trim().Length -gt 0) { $declaredActivity = $line.Trim(); break }
    }
}

$eventStructureOk = Test-AnyMatch -Names $substrateNames -Wildcard '04-event-history*' -Pattern '("name"\s*:|ACTIVITY_TASK_SCHEDULED)' -StagingDirectoryPath $StagingPath
if (-not $eventStructureOk) {
    $malformed += "SS 5.3 item 3: no '04-event-history*' file carrying real event structure (a JSON `"name`" field or an ACTIVITY_TASK_SCHEDULED line)"
}
if ($declaredActivity) {
    $activityPresent = Test-AnyMatch -Names $substrateNames -Wildcard '04-event-history*' -Pattern ([regex]::Escape($declaredActivity)) -StagingDirectoryPath $StagingPath
    if (-not $activityPresent) {
        $malformed += ("SS 5.3 item 3: no '04-event-history*' file carries the declared terminal activity '{0}'" -f $declaredActivity)
    }
}

# SS 5.3 item 4 -- declared-terminal-activity.txt is REQUIRED HERE, EXPLICIT OR REFUSE.
# Test-WitnessedSubstrate (tools/mission-lib.ps1) requires it too and has no built-in default terminal
# activity: a substrate placed without its declaration could never close. There is deliberately no
# fallback in this file: $declaredActivity is assigned from the declaration file and from nothing else.
if ($substrateNames -notcontains 'declared-terminal-activity.txt') {
    $malformed += "SS 5.3 item 4: 'declared-terminal-activity.txt' is absent. This contract REQUIRES it, as the gate does -- explicit or refuse; no default terminal activity exists to inherit"
}
elseif (-not $declaredActivity) {
    $malformed += "SS 5.3 item 4: 'declared-terminal-activity.txt' has no non-empty line"
}
elseif ($declaredActivity -notmatch $script:DeclaredActivityPattern) {
    $malformed += ("SS 5.3 item 4: 'declared-terminal-activity.txt' first non-empty line '{0}' does not match {1}" -f $declaredActivity, $script:DeclaredActivityPattern)
}

# SS 5.3 item 7 -- every file BOM-free.
foreach ($n in $substrateNames) {
    if (-not $derived.ContainsKey($n)) { continue }
    if ($derived[$n].Head -eq 'efbbbf') {
        $malformed += ("SS 5.3 item 7: '{0}' carries a UTF-8 BOM (first three bytes efbbbf)" -f $n)
    }
}
$manifestHead = Get-FirstThreeBytesHex -Path $manifestPath
if ($manifestHead -eq 'efbbbf') {
    $malformed += ("SS 5.3 item 7: '{0}' carries a UTF-8 BOM (first three bytes efbbbf)" -f $script:ManifestFileName)
}

if ($malformed.Count -gt 0) {
    Write-Outcome -Outcome 'REFUSED -- MALFORMED INPUT. Nothing was placed; the well-formed subset was NOT placed.' `
        -Violations $malformed -Code 3
}

# =================================================================================================
# PLACEMENT. Nothing above this line created the destination. SS 6.5: the copy, then EVERY
# destination digest re-derived and compared to its source.
# =================================================================================================

$copyPlan = @($manifestNames) + @($script:ManifestFileName)
$placedNames = @()
$notPlacedNames = @($copyPlan)
$indeterminate = @()

try { [void][System.IO.Directory]::CreateDirectory($destinationPath) }
catch {
    Write-Outcome -Outcome 'REFUSED -- PRECONDITION. The destination could not be created; nothing was placed.' `
        -Violations @(("destination '{0}' could not be created: {1}" -f $destinationPath, $_.Exception.Message)) -Code 6
}

Write-Line ''
Write-Line '--- placement -----------------------------------------------------------------'

foreach ($n in $copyPlan) {
    $srcPath = Join-Path $StagingPath $n
    $dstPath = Join-Path $destinationPath $n
    try {
        [System.IO.File]::Copy($srcPath, $dstPath, $false)
        $placedNames += $n
        $notPlacedNames = @($notPlacedNames | Where-Object { $_ -ne $n })
    }
    catch {
        $indeterminate += ("copy failed for '{0}': {1}" -f $n, $_.Exception.Message)
    }
}

# SS 6.5 -- "re-deriving every digest at the destination, comparing source to destination". This is
# the leg the interim could not perform and the reason SS 6.6 says anything at all is gained.
$verified = @()
foreach ($n in $placedNames) {
    $srcPath = Join-Path $StagingPath $n
    $dstPath = Join-Path $destinationPath $n
    $srcSha = Get-FileSha256 -Path $srcPath
    $dstSha = Get-FileSha256 -Path $dstPath
    $srcBytes = (Get-Item -LiteralPath $srcPath).Length
    $dstBytes = (Get-Item -LiteralPath $dstPath).Length
    $agree = ($srcSha -eq $dstSha) -and ([int64]$srcBytes -eq [int64]$dstBytes)
    if (-not $agree) {
        $indeterminate += ("destination digest disagrees for '{0}': source {1} ({2} b), destination {3} ({4} b)" -f $n, $srcSha, $srcBytes, $dstSha, $dstBytes)
    }
    $verified += [pscustomobject]@{
        name              = $n
        source_sha256     = $srcSha
        source_bytes      = $srcBytes
        destination_sha256 = $dstSha
        destination_bytes = $dstBytes
        agrees            = $agree
    }
    Write-Line ("  {0}  {1}  {2} b  {3}" -f $(if ($agree) { 'OK  ' } else { 'DIFF' }), $n, $dstBytes, $dstSha)
}

if ($indeterminate.Count -gt 0) {
    # SS 7.4. NO ROLLBACK. Nothing below deletes anything; there is no Remove-Item in this file.
    Write-Line ''
    Write-Line ("PLACED ({0}): {1}" -f $placedNames.Count, (@($placedNames) -join ', '))
    Write-Line ("NOT PLACED ({0}): {1}" -f @($notPlacedNames).Count, (@($notPlacedNames) -join ', '))
    Write-Line 'NO ROLLBACK WAS ATTEMPTED. The operator resolves an INDETERMINATE destination; the script never does.'
    Write-Outcome -Outcome 'INDETERMINATE DESTINATION. Success is NOT reported.' -Violations $indeterminate -Code 5
}

# =================================================================================================
# THE PLACEMENT RECORD (SS 6.5). Written last, after every destination digest agreed.
# =================================================================================================

$record = [pscustomobject]@{
    placement_record_version = 1
    outcome                  = 'PLACED'
    substrate_name           = $SubstrateName
    staging_path             = $stagingFullPath
    destination_path         = $destinationPath
    manifest_file            = $script:ManifestFileName
    placed_utc               = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
    placed_by                = 'evidence-place-substrate.ps1 (operator-invoked; not hook-wired)'
    contract                 = 'docs/framework/evidence-placement-input-contract-spec.md (ratified)'
    source_digests_rederived = $true
    destination_digests_rederived = $true
    trust_model_note         = 'The operator executed this script. Contract SS 6.6: the win is destination verification and a placement record, NOT operator elimination. The operator was not removed from the loop and this record does not claim otherwise.'
    files                    = $verified
}

$recordPath = Join-Path $destinationPath $script:RecordFileName
try { Write-Utf8NoBom -Path $recordPath -Text (ConvertTo-JsonLf -InputObject $record -Depth 6) }
catch {
    # SS 7.0 forbids placed-without-record. The bytes are already at the destination and SS 7.4
    # forbids removing them, so the honest report is INDETERMINATE, not success.
    Write-Line ''
    Write-Line ("PLACED ({0}): {1}" -f $placedNames.Count, (@($placedNames) -join ', '))
    Write-Line 'NO ROLLBACK WAS ATTEMPTED.'
    Write-Outcome -Outcome 'INDETERMINATE DESTINATION -- the files were placed but the placement record could not be written. Success is NOT reported.' `
        -Violations @(("placement record '{0}' could not be written: {1}" -f $recordPath, $_.Exception.Message)) -Code 5
}

Write-Line ''
Write-Line ("record      : {0}" -f $recordPath)
Write-Line ("placed      : {0} file(s), every destination digest re-derived and agreed" -f $placedNames.Count)
Write-Line 'NOTE: the operator ran this command. Destination verification and a placement record are'
Write-Line 'what this path gains (contract SS 6.6); the operator was NOT removed from the loop.'
Write-Outcome -Outcome 'PLACED.' -Violations @() -Code 0
