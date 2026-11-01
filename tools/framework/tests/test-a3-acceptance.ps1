#Requires -Version 5.1
<#
.SYNOPSIS
  A3 acceptance test -- the mission verify specification.

.DESCRIPTION
  Citation convention (v2.2's standing convention): LM2-ADR-0NN / "design SS<n>"
  denote docs/framework/vanguard-collective-local-modes-v2.2.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/. "SS" is this file's ASCII spelling of the section mark.

  WHAT THIS IS FOR. It exists so the authorizing amendment's acceptance criteria K(1)-K(7) can be RE-DERIVED -- by a
  validator, by a future ceremony, by anyone -- instead of taken on a build session's word. Placed
  on disk on the A1 R1 and A2 R-A2-1 precedent: an acceptance check that exists only in a build
  transcript is testimony. It is NOT a substitute for a validator deriving the criteria
  independently.

  NO INVENTORY IS WRITTEN HERE. A hand-maintained list drifts exactly the way a hand-maintained
  count does (the A2 B2 defect: a seven-item inventory against a twelve-row table silently
  exempted the five rows it did not name). Every population this file checks is derived from the
  artifact, from the sealed sources, or from the authorizing amendment. Where a check's reach is
  narrower than its name suggests, THE CHECK PRINTS ITS OWN REACH on every run.

  READ-ONLY BY CONSTRUCTION. This test opens files. It writes nothing, anywhere, so there is no
  sandbox to build and no residue to clean.

  IT INVOKES NO NATIVE EXECUTABLE, AND THAT IS DELIBERATE. Instrument law (c) below was earned by
  the A2 suite, where `git rev-parse` under $ErrorActionPreference = 'Stop' killed the run instead
  of taking the skip branch three lines below it. This suite has no native call to be killed by.

  THIS SUITE DECIDES AT ANY HEAD, AND THAT IS A DELIBERATE DIFFERENCE FROM THE A2 SUITE. The A2
  instrument gates its population check on the artifact's derivation anchor and SKIPS away from it,
  because its figures are live-data populations that legitimately move. The A3 artifact derives NO
  population from repository state that a ceremony moves -- its anchor block carries file-content
  hashes, which re-derive as long as the files are unchanged, and it derives nothing at all from
  the contents of .mission/amendments/. So there is no ground here that moves under a commit, and
  no skip branch is owed to one.

  THE ONE GATED CHECK IS K1c, and it gates on FILE PRESENCE rather than on HEAD: the second
  enforcement direction reads the arm set out of the authorizing amendment, which is placed at the
  A3 ceremony commit. Before placement K1c SKIPS and the suite exits 3; after placement it decides
  and the suite exits 0. Exit 3 from this suite therefore means "the authorizing amendment is not on disk yet", which
  is a fact worth surfacing rather than noise to be tuned out.

  THREE INSTRUMENT LAWS THIS FILE OBEYS, inherited from the A1 and A2 instruments.

  (a) PURE ASCII SOURCE, PATTERNS INCLUDED. A BOM-less .ps1 is parsed by PowerShell 5.1 in the
      ANSI codepage. A non-ASCII character inside a regex here decodes to mojibake and the match
      SILENTLY NEVER FIRES -- the check reports nothing and reads as passing. That is how an
      earlier A2 mirror "passed" while finding zero sections. Check K6c asserts this file's own
      bytes. The artifact under test is pure ASCII too, which is why no pattern here needs to
      wildcard a character it cannot spell.

  (b) PATH VARIABLES ARE NOT CASE-VARIANTS OF DATA VARIABLES. PowerShell variable names are
      CASE-INSENSITIVE: $A3 and $a3 are one variable, so `$a3 = ReadText $A3` destroys the path it
      just read. Path variables here carry a Path suffix.

  (c) NATIVE STDERR IS NOT A TERMINATING ERROR, BUT POWERSHELL 5.1 MAKES IT ONE. Satisfied here by
      construction -- see above, nothing native is invoked.

  EXIT CONTRACT -- true as written, and ceremony-safe.
      0  every check ran and passed; nothing skipped.
      3  every check that ran passed, but at least one SKIPPED. The suite is incomplete, not
         green. A documented value, because a ceremony reading only the exit code must be able to
         tell "incomplete" from "clean" without parsing stdout.
      n  n failures. Failures take precedence over skips.
  EXIT 3 IS NOT UNIQUE, and that is disclosed rather than papered over: a run with exactly three
  failures also exits 3. The summary line disambiguates and is printed on every run -- "SUITE
  FAILED" carries a failure count, "SUITE INCOMPLETE, NOT GREEN" carries a skip count. An offset
  that made the codes disjoint would be a rule nobody remembers at the moment it matters.

  WHAT THIS FILE DOES NOT DO. It is an instrument, not a boundary. NOTHING INVOKES IT -- no hook,
  no gate, no ceremony step -- so it decides only when a person runs it, and the artifact can drift
  between runs of it. It checks the artifact's SHAPE and the resolvability of what the artifact
  cites. It does not adjudicate whether the specification is a good specification, and it cannot:
  no check here would notice a well-formed arm that specifies the wrong comparison.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# tools/framework/tests/<this file>  ->  up three  ->  repo root.
# Anchored to THIS SCRIPT, never to the caller's cwd: a test whose subject
# depends on where it was invoked from is not a test.
$repoRoot        = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$artifactPath    = Join-Path $repoRoot 'docs\framework\mission-verify-spec.md'
$selfPath        = $PSCommandPath
$commonPath      = Join-Path $repoRoot 'tools\framework\hooks\lib\evidence-common.ps1'
$amendmentsDir   = Join-Path $repoRoot '.mission\amendments'

# The sealed corpus a prose field token may be inherited from. Derived as a directory of sources,
# not as a list of tokens: adding a token to any of these files makes it citable, and no token is
# exempted individually.
$corpusPaths = @(
    $commonPath
    (Join-Path $repoRoot 'docs\framework\evidence-manifest.schema.json')
    (Join-Path $repoRoot 'docs\framework\expanded-schemas.md')
    (Join-Path $repoRoot 'docs\framework\vanguard-collective-local-modes-v2.2.md')
    (Join-Path $repoRoot 'docs\framework\evidence-write-path-threat-notes.md')
)

# --- harness -----------------------------------------------------------------------------------
# Summary counts are DERIVED from checks actually run (instrument integrity, design SS4.5 law 5).
# Nothing here maintains a total by hand.
$script:passed   = 0
$script:failed   = 0
$script:skipped  = 0

function Check {
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail = '')
    if ($Ok) {
        $script:passed++
        Write-Host ("PASS  {0}  {1}" -f $Id, $Title)
    } else {
        $script:failed++
        Write-Host ("FAIL  {0}  {1}" -f $Id, $Title)
        if ($Detail) { foreach ($line in ($Detail -split "`n")) { Write-Host ("        " + $line) } }
    }
}

function Skip {
    param([string]$Id, [string]$Title, [string]$Why)
    $script:skipped++
    Write-Host ("SKIP  {0}  {1}" -f $Id, $Title)
    foreach ($line in ($Why -split "`n")) { Write-Host ("        " + $line) }
}

function Note { param([string]$Text) Write-Host ("      . " + $Text) }

# Joins detail lines, dropping the empty results of conditional expressions. Written as a helper
# because the inline form of this is where a precedence bug hides and takes a check's detail with
# it -- a check that fails with an empty explanation is a check nobody can act on.
function JoinDetail {
    param([object[]]$Parts)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Parts) {
        if ($null -eq $p) { continue }
        foreach ($item in @($p)) {
            if ($null -ne $item -and ([string]$item).Trim() -ne '') { [void]$out.Add([string]$item) }
        }
    }
    return ($out -join "`n")
}

function ReadText { param([string]$Path) return [System.IO.File]::ReadAllText($Path) }
function ReadBytes { param([string]$Path) return [System.IO.File]::ReadAllBytes($Path) }

function Get-AsciiVerdict {
    # Returns a report object for the encoding properties every framework artifact owes.
    param([string]$Path)
    $bytes = ReadBytes $Path
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $cr = 0; $nonAscii = 0; $tab = 0
    foreach ($b in $bytes) {
        if ($b -eq 13) { $cr++ }
        elseif ($b -gt 127) { $nonAscii++ }
        elseif ($b -eq 9) { $tab++ }
    }
    return [pscustomobject]@{ bom = $bom; cr = $cr; non_ascii = $nonAscii; tab = $tab; bytes = $bytes.Length }
}

Write-Host ""
Write-Host "A3 acceptance -- mission verify specification (amendment SS K)"
Write-Host ("repo root : " + $repoRoot)
Write-Host ("artifact  : " + $artifactPath)
Write-Host ""

if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
    Check 'K0' 'the artifact exists' $false ("not found: " + $artifactPath)
    Write-Host ""
    Write-Host "SUITE FAILED: 1 failure(s). The artifact is absent; no other check can decide."
    exit 1
}
Check 'K0' 'the artifact exists' $true

$artifactText  = ReadText $artifactPath
$artifactLines = $artifactText -split "`n"

# Fenced-block map. Needed twice: prose-only scans must exclude fenced content, and the
# inherited-or-defined token check treats this document's own fenced definitions as a corpus.
$inFence = $false
$proseLines = New-Object System.Collections.Generic.List[string]
$fenceLines = New-Object System.Collections.Generic.List[string]
foreach ($line in $artifactLines) {
    if ($line.TrimStart().StartsWith('```')) { $inFence = -not $inFence; continue }
    if ($inFence) { [void]$fenceLines.Add($line) } else { [void]$proseLines.Add($line) }
}
$proseText = ($proseLines -join "`n")
$fenceText = ($fenceLines -join "`n")
Check 'K0b' 'fenced blocks are balanced' (-not $inFence) '       an unclosed code fence makes every prose-scoped scan below unsound'

# --- K1a: the arm summary table and the arm sections are the same set, both directions ----------
# The F5-mirror technique. A table row with no section is an arm that was promised and not
# specified; a section with no row is an arm the summary hides. Zero arms found is a FAILURE, not
# a quiet pass -- that is how a broken pattern reads as green.
$tableArms = New-Object System.Collections.Generic.List[string]
$headerIdx = -1
for ($i = 0; $i -lt $artifactLines.Count; $i++) {
    if ($artifactLines[$i] -match '^\|\s*Arm\s*\|\s*Subject\s*\|\s*Detector\s*\|\s*Section\s*\|') { $headerIdx = $i; break }
}
if ($headerIdx -ge 0) {
    for ($i = $headerIdx + 1; $i -lt $artifactLines.Count; $i++) {
        $row = $artifactLines[$i]
        if (-not $row.TrimStart().StartsWith('|')) { break }
        if ($row -match '^\|[\s\-:|]+\|$') { continue }
        $cells = $row.Trim().Trim('|') -split '\|'
        $name = $cells[0].Trim()
        if ($name) { [void]$tableArms.Add($name) }
    }
}

$sectionArms = New-Object System.Collections.Generic.List[string]
foreach ($line in $artifactLines) {
    $m = [regex]::Match($line, '^###\s+\d+\.\d+\s+Arm:\s+(\S.*?)\s*$')
    if ($m.Success) { [void]$sectionArms.Add($m.Groups[1].Value) }
}

$onlyTable   = @($tableArms   | Where-Object { $sectionArms -notcontains $_ })
$onlySection = @($sectionArms | Where-Object { $tableArms   -notcontains $_ })
$armMirrorOk = ($tableArms.Count -gt 0 -and $sectionArms.Count -gt 0 -and
                $onlyTable.Count -eq 0 -and $onlySection.Count -eq 0)
$armDetail = @()
if ($headerIdx -lt 0)          { $armDetail += 'no arm summary table found (header row "| Arm | Subject | Detector | Section |")' }
if ($tableArms.Count -eq 0)    { $armDetail += 'the arm summary table yielded no rows' }
if ($sectionArms.Count -eq 0)  { $armDetail += 'no "### <n>.<n> Arm: <NAME>" sections found' }
foreach ($a in $onlyTable)   { $armDetail += ("in the table, no section: " + $a) }
foreach ($a in $onlySection) { $armDetail += ("a section, not in the table: " + $a) }
Check 'K1a' 'arm table and arm sections are the same set (both directions)' $armMirrorOk ($armDetail -join "`n")
Note ("arms derived from the artifact: " + ($sectionArms -join ', '))

# --- K1b: every arm carries its detector and its residual, per design SS4.5 law 4 ---------------
# Stated per-member and demonstrated per-member. The labels are the artifact's own structure; the
# check reads them out of it rather than knowing them.
$requiredLabels = @('**Compares.**', '**Detector.**', '**Residual.**', '**Emits.**')
$armGaps = @()
foreach ($arm in $sectionArms) {
    $startIdx = -1
    for ($i = 0; $i -lt $artifactLines.Count; $i++) {
        if ($artifactLines[$i] -match ('^###\s+\d+\.\d+\s+Arm:\s+' + [regex]::Escape($arm) + '\s*$')) { $startIdx = $i; break }
    }
    if ($startIdx -lt 0) { $armGaps += ("could not locate the section body for " + $arm); continue }
    $endIdx = $artifactLines.Count
    for ($i = $startIdx + 1; $i -lt $artifactLines.Count; $i++) {
        if ($artifactLines[$i] -match '^#{2,3}\s') { $endIdx = $i; break }
    }
    $body = ($artifactLines[$startIdx..($endIdx - 1)] -join "`n")
    foreach ($label in $requiredLabels) {
        if ($body -notmatch [regex]::Escape($label)) { $armGaps += ($arm + " is missing " + $label) }
    }
}
Check 'K1b' 'every arm carries Compares / Detector / Residual / Emits' `
      ($sectionArms.Count -gt 0 -and $armGaps.Count -eq 0) ($armGaps -join "`n")

# --- K1c: second enforcement direction, derived from the authorizing amendment ------------------
# REACH, STATED IN THE LABEL: this derives the arm names the authorizing amendment's SS D itself names, and requires
# each to be specified. It makes NO claim about arms from any other source. A coverage check
# claiming more than its derivation reaches is the A2 B2 defect reborn.
$am420Path = $null
if (Test-Path -LiteralPath $amendmentsDir) {
    $cand = @(Get-ChildItem -LiteralPath $amendmentsDir -Filter 'AM-420-*.yaml' -File)
    if ($cand.Count -ge 1) { $am420Path = $cand[0].FullName }
}
if (-not $am420Path) {
    Skip 'K1c' 'the amendment-named arm set is specified (amendment-derived direction)' `
        ("The authorizing amendment is not placed under .mission/amendments/ yet, so the amendment-derived direction`n" +
         "has no source to read. It is placed at the A3 ceremony commit; re-run after placement.`n" +
         "This is the suite's only gated check, and it gates on file presence, not on HEAD.")
} else {
    $amText = ReadText $am420Path
    $amArms = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($amText -split "`n")) {
        $m = [regex]::Match($line, '^\s*D\.\d+\s+([A-Z][A-Z-]*)\s+ARM')
        if ($m.Success) { [void]$amArms.Add($m.Groups[1].Value) }
    }
    $missing = @($amArms | Where-Object { $sectionArms -notcontains $_ })
    Check 'K1c' 'the amendment-named arm set is specified (amendment-derived direction)' `
          ($amArms.Count -gt 0 -and $missing.Count -eq 0) `
          (JoinDetail @(
            $(if ($amArms.Count -eq 0) { 'derived no arm names from amendment SS D -- the pattern found nothing, which is a failure, not a pass' })
            ,@($missing | ForEach-Object { "the amendment names it, the artifact does not specify it: " + $_ })
          ))
    Note ("arms derived from amendment SS D: " + ($amArms -join ', '))
    Note "reach: the amendment-named set only. Arms registered elsewhere are outside this check."
}

# --- K2: no authored counts (design SS4.5 law 3) ------------------------------------------------
# REACH, PRINTED ON EVERY RUN. This fires on a spelled cardinal followed by an enumerable noun from
# the set below, optionally across one hyphenated compound adjective. That last allowance was added
# after a run: the first form matched adjacent pairs only, and "two same-host channels" sat in the
# artifact unflagged -- an authored count wearing an adjective. Found by executing the check, not by
# reading it.
# What it does NOT reach, stated because a check whose gaps are invisible is a check that lies by
# omission: bare digits (in this corpus they are section references, hashes and byte lengths); more
# than one intervening word; a noun outside the set; and the DISTRIBUTIVE form
# "<cardinal> <noun> per ...", which states a rule about each member rather than counting a
# population.
$cardinalSet = 'one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|dozen'
$nounSet     = 'arms?|outcomes?|checks?|members?|channels?|rungs?|residuals?|detectors?|items?|states?|fields?|commands?|entries|subjects?|layers?|sections?|rules?'
$countPat    = "(?i)\b($cardinalSet)\s+(?:[a-z]+-[a-z]+\s+)?($nounSet)\b(?!\s+per\b)"
$countHits   = @([regex]::Matches($proseText, $countPat))
$countDetail = @()
foreach ($h in $countHits) {
    $s = [Math]::Max(0, $h.Index - 60)
    $e = [Math]::Min($proseText.Length, $h.Index + $h.Length + 30)
    $countDetail += ('...' + (($proseText.Substring($s, $e - $s)) -replace "`n", ' ') + '...')
}
Check 'K2' 'no authored counts in prose' ($countHits.Count -eq 0) ($countDetail -join "`n")
Note ("cardinals: " + $cardinalSet)
Note ("nouns    : " + $nounSet)
Note "spans    : an optional single hyphenated compound adjective between cardinal and noun"
Note "excluded : bare digits; more than one intervening word; the distributive form '<cardinal> <noun> per ...'"

# --- K3a: every sealed-source anchor line re-derives from disk ----------------------------------
# The artifact prints "<sha8>  <bytes>  <path>" lines. Each must re-derive. Both the hash prefix
# and the byte length are checked, because a length alone is not an anchor and a prefix alone
# hides a truncation.
$anchorHits = @([regex]::Matches($artifactText, '(?m)^([0-9a-f]{8})\s+(\d+)\s+(\S+)\s*$'))
$anchorProblems = @()
foreach ($h in $anchorHits) {
    $sha8     = $h.Groups[1].Value
    $declared = [int]$h.Groups[2].Value
    $rel      = $h.Groups[3].Value
    $full     = Join-Path $repoRoot ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $anchorProblems += ($rel + ": no such file")
        continue
    }
    $actualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant().Substring(0, 8)
    $actualLen = (Get-Item -LiteralPath $full).Length
    if ($actualSha -ne $sha8)     { $anchorProblems += ($rel + ": sha8 " + $sha8 + " declared, " + $actualSha + " on disk") }
    if ($actualLen -ne $declared) { $anchorProblems += ($rel + ": " + $declared + " bytes declared, " + $actualLen + " on disk") }
}
Check 'K3a' 'every declared sealed-source anchor re-derives from disk' `
      ($anchorHits.Count -gt 0 -and $anchorProblems.Count -eq 0) `
      (JoinDetail @(
        $(if ($anchorHits.Count -eq 0) { 'no "<sha8>  <bytes>  <path>" anchor lines found -- the artifact declares no anchors, which is a failure' })
        ,@($anchorProblems)
      ))
Note ("anchor lines derived from the artifact: " + $anchorHits.Count)

# --- K3b: every sealed symbol the artifact names resolves in the sealed library ------------------
# REACH: one direction only. The library defines functions the artifact need not cite, so the
# reverse direction would be a false claim. What is enforced: the artifact cannot name a detector
# that does not exist.
$commonText = ReadText $commonPath
$symbols = @([regex]::Matches($artifactText, '\b((?:Get|Test)-Evidence[A-Za-z]*)\b') |
             ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$symbolProblems = @()
foreach ($sym in $symbols) {
    if ($commonText -notmatch ('(?m)^function\s+' + [regex]::Escape($sym) + '\b')) {
        $symbolProblems += ($sym + ": named by the artifact, not defined in evidence-common.ps1")
    }
}
Check 'K3b' 'every sealed detector the artifact names is defined in the sealed library' `
      ($symbols.Count -gt 0 -and $symbolProblems.Count -eq 0) `
      (JoinDetail @(
        $(if ($symbols.Count -eq 0) { 'the artifact names no Get-Evidence*/Test-Evidence* symbol -- the pattern found nothing, which is a failure' })
        ,@($symbolProblems)
      ))
Note ("detectors derived from the artifact: " + ($symbols -join ', '))
Note "reach: artifact -> library only. The library holds functions no artifact need cite."

# --- K3c: every snake_case field token in prose is inherited or defined here ---------------------
# A token the prose backticks must exist EITHER in a sealed source OR in this document's own fenced
# definitions. That is a structural rule, not an allowlist: no token is exempted individually, and
# a misspelled inherited field resolves in neither corpus. Dotted paths are out of scope -- the
# identifier is extracted from inside the backticks, so `basis.hash_class` contributes hash_class.
$corpusText = $fenceText
foreach ($cp in $corpusPaths) {
    if (Test-Path -LiteralPath $cp -PathType Leaf) { $corpusText += "`n" + (ReadText $cp) }
}
$tokenSet = New-Object System.Collections.Generic.List[string]
foreach ($span in [regex]::Matches($proseText, '`([^`]+)`')) {
    foreach ($idm in [regex]::Matches($span.Groups[1].Value, '[_A-Za-z][_A-Za-z0-9]*')) {
        $tok = $idm.Value
        if ($tok -cmatch '^_?[a-z][a-z0-9]*(_[a-z0-9]+)+$') {
            if ($tokenSet -notcontains $tok) { [void]$tokenSet.Add($tok) }
        }
    }
}
$tokenProblems = @()
foreach ($tok in $tokenSet) {
    if ($corpusText -notmatch [regex]::Escape($tok)) {
        $tokenProblems += ($tok + ": in prose, but in no sealed source and in no fenced definition here")
    }
}
Check 'K3c' 'every snake_case field token in prose is inherited or defined here' `
      ($tokenSet.Count -gt 0 -and $tokenProblems.Count -eq 0) `
      (JoinDetail @(
        $(if ($tokenSet.Count -eq 0) { 'no snake_case tokens found in prose -- the pattern found nothing, which is a failure' })
        ,@($tokenProblems)
      ))
Note ("prose field tokens derived: " + $tokenSet.Count)
Note "corpus: the sealed sources listed at the top of this file, plus this document's fenced blocks."

# --- K4: NB-2 is resolved on its face -----------------------------------------------------------
# The deferral came due here, so the artifact must show the ordering rule, must show that sealed
# code was NOT edited, and must carry the correction to the register's own "one-line" wording.
# The markers are load-bearing sentences, not decoration: each one is a claim a reader checks.
$nb2Markers = @(
    'discriminates entry variant before it tests existence',
    'A3 does not touch',
    'transcript_sha256'
)
$nb2Missing = @($nb2Markers | Where-Object { $artifactText -notmatch [regex]::Escape($_) })
Check 'K4' 'NB-2 is resolved on its face (ordering rule, sealed code untouched, register corrected)' `
      ($artifactText -match 'NB-2' -and $nb2Missing.Count -eq 0) `
      (($nb2Missing | ForEach-Object { "missing marker: " + $_ }) -join "`n")

# --- K5: the independence ladder is stated in full, and the companion item is NOT BUILT ----------
# The rung labels are derived from the ladder table rather than typed here. What the check enforces
# beyond that: no rung is a table-only entry, the ceiling is admitted in prose, and the companion
# item carries its status. REACH: it verifies the ladder is present, complete against its own
# table, and honestly capped. It does not adjudicate whether the ladder has the right rungs.
$ladderRungs = New-Object System.Collections.Generic.List[string]
foreach ($line in $artifactLines) {
    $m = [regex]::Match($line, '^\|\s*\*\*([A-Z][A-Z\- ]*)\*\*\s*\|')
    if ($m.Success) { [void]$ladderRungs.Add($m.Groups[1].Value.Trim()) }
}
$rungProblems = @()
foreach ($rung in $ladderRungs) {
    $occurrences = @([regex]::Matches($artifactText, [regex]::Escape($rung))).Count
    if ($occurrences -lt 2) { $rungProblems += ($rung + ": appears only in the ladder table, nowhere in prose") }
}
if (-not ($artifactText -match 'specifies the top rung\. It does not possess it')) {
    $rungProblems += 'the ceiling admission is absent: the artifact does not say it specifies the top rung without possessing it'
}
if (-not ($artifactText -match 'REGISTERED, NOT BUILT')) {
    $rungProblems += 'the companion item does not carry REGISTERED, NOT BUILT'
}
Check 'K5' 'the independence ladder is stated in full and honestly capped; companion item NOT BUILT' `
      ($ladderRungs.Count -gt 0 -and $rungProblems.Count -eq 0) `
      (@(
        $(if ($ladderRungs.Count -eq 0) { 'no ladder table rows found -- the pattern found nothing, which is a failure' })
        $rungProblems
      ) -ne $null -join "`n")
Note ("ladder rungs derived from the artifact: " + ($ladderRungs -join ' < '))

# --- K6a: the citation convention note is present -----------------------------------------------
Check 'K6a' 'the LM2 citation convention note is present' ($artifactText -match 'LM2-ADR-0NN')

# --- K6b: the artifact's encoding ---------------------------------------------------------------
# Strict UTF-8 with no BOM and LF-only is the standing regression from the A1 corruption. Pure
# ASCII is this artifact's own stricter choice; it is checked because the artifact claims it.
$artEnc = Get-AsciiVerdict $artifactPath
$encProblems = @()
if ($artEnc.bom)          { $encProblems += 'the artifact carries a UTF-8 BOM' }
if ($artEnc.cr -gt 0)     { $encProblems += ("the artifact carries " + $artEnc.cr + " CR byte(s); LF-only is required") }
if ($artEnc.non_ascii -gt 0) { $encProblems += ("the artifact carries " + $artEnc.non_ascii + " non-ASCII byte(s); it claims pure ASCII") }
if ($artEnc.tab -gt 0)    { $encProblems += ("the artifact carries " + $artEnc.tab + " tab(s)") }
try { [void][System.Text.Encoding]::UTF8.GetString((ReadBytes $artifactPath)) }
catch { $encProblems += 'the artifact does not decode as UTF-8' }
Check 'K6b' 'the artifact is BOM-less, LF-only, tab-free, pure ASCII' ($encProblems.Count -eq 0) ($encProblems -join "`n")

# --- K6c: this instrument's own encoding (law (a), self-asserted) -------------------------------
$selfEnc = Get-AsciiVerdict $selfPath
$selfProblems = @()
if ($selfEnc.bom)             { $selfProblems += 'this file carries a BOM' }
if ($selfEnc.cr -gt 0)        { $selfProblems += ("this file carries " + $selfEnc.cr + " CR byte(s)") }
if ($selfEnc.non_ascii -gt 0) { $selfProblems += ("this file carries " + $selfEnc.non_ascii + " non-ASCII byte(s); a regex here would decode to mojibake under PS 5.1") }
Check 'K6c' 'this instrument is BOM-less, LF-only, pure ASCII (instrument law (a))' ($selfProblems.Count -eq 0) ($selfProblems -join "`n")

# --- K7: instrument integrity, the mechanically checkable part ----------------------------------
# REACH: this checks the two properties that are decidable from the file's own bytes -- tree
# anchoring, and the absence of cwd dependence. The remaining law-5 properties (no green line on a
# failing run, derived summary counts, well-formed fixtures) are properties of construction: this
# file prints its summary from $script:passed/$script:failed/$script:skipped, and it has no
# fixtures at all, being read-only over real files. They are demonstrated by the code, and this
# check does not pretend to decide them.
$selfText = ReadText $selfPath
$selfIntegrity = @()
if ($selfText -notmatch '\$PSScriptRoot') { $selfIntegrity += 'this file does not anchor to $PSScriptRoot' }
# The cwd-dependence probe is BUILT, not spelled. Written as a literal, the pattern occurs in this
# very line, and the check fails on its own source -- the false-positive twin of the mojibake class
# in instrument law (a): a pattern that matches the file that carries it decides nothing about the
# file's behaviour.
$cwdCall = 'Get' + '-Location'
if ($selfText -match ('(?m)^\s*[^#\r\n]*' + $cwdCall)) { $selfIntegrity += ('this file calls ' + $cwdCall + ' -- cwd dependence') }
Check 'K7' 'this instrument anchors to its own tree and does not depend on cwd' ($selfIntegrity.Count -eq 0) ($selfIntegrity -join "`n")
Note "reach: tree anchoring and cwd independence only. The other law-5 properties are construction, not checks."

# --- summary ------------------------------------------------------------------------------------
# Derived from what ran. Printed on EVERY run, so the non-unique exit 3 is always disambiguated.
$ran = $script:passed + $script:failed + $script:skipped
Write-Host ""
Write-Host ("checks run: {0}   passed: {1}   failed: {2}   skipped: {3}" -f $ran, $script:passed, $script:failed, $script:skipped)
if ($script:failed -gt 0) {
    Write-Host ("SUITE FAILED: {0} failure(s)." -f $script:failed)
    exit $script:failed
}
if ($script:skipped -gt 0) {
    Write-Host ("SUITE INCOMPLETE, NOT GREEN: {0} skip(s). Exit 3 is documented and is not unique -- read this line, not the code." -f $script:skipped)
    exit 3
}
Write-Host "SUITE PASSED."
exit 0
