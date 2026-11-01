#Requires -Version 5.1
<#
.SYNOPSIS
  A2 acceptance test -- the consolidated schemas document.

.DESCRIPTION
  Citation convention (v2.2's standing convention): LM2-ADR-0NN / "design SS<n>"
  denote docs/framework/vanguard-collective-local-modes-v2.2.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/. "SS" is this file's ASCII spelling of the section mark.

  WHAT THIS IS FOR. It exists so the A2 acceptance criteria F(1)-F(6) can be RE-DERIVED -- by a
  validator, by a future ceremony, by anyone -- instead of taken on a build session's word. Placed
  on disk as plan-divergence addition R-A2-1, on the A1 R1 precedent: an acceptance test that
  exists only in a build transcript is testimony. It is NOT a substitute for a validator deriving
  the criteria independently.

  Checks: no inventory is written here. A hand-maintained list drifts exactly the way a
  hand-maintained count does. Each check states its own purpose at its own definition, and the
  suite prints its own total, derived from checks actually run.

  READ-ONLY BY CONSTRUCTION. This test opens files and runs `git rev-parse HEAD`. It writes
  nothing, anywhere, so there is no sandbox to build and no residue to clean.

  THREE INSTRUMENT LAWS THIS FILE OBEYS, each earned by a defect in its own earlier drafts.
  Law (c) is stated at its site, above the F5-derive gate, because that is where it bites:
  native stderr is not a terminating error, but PowerShell 5.1 makes it one, and that turned
  this suite's skip branch into a crash.

  (a) PURE ASCII SOURCE, PATTERNS INCLUDED. A BOM-less .ps1 is parsed by PowerShell 5.1 in the
      ANSI codepage. An em-dash inside a regex here decodes to mojibake and the match SILENTLY
      NEVER FIRES -- the check reports nothing and reads as passing. That is exactly how the
      open-vocabulary mirror below first "passed" while finding zero sections. Patterns that must
      span a non-ASCII character wildcard it instead of spelling it.

  (b) PATH VARIABLES ARE NOT CASE-VARIANTS OF DATA VARIABLES. PowerShell variable names are
      CASE-INSENSITIVE: $A2 and $a2 are one variable, so `$a2 = ReadLines $A2` destroys the path
      it just read. Path variables here carry a Path suffix.

  EXIT CONTRACT -- true as written, and ceremony-safe.
      0  every check ran and passed; nothing skipped.
      3  every check that ran passed, but at least one SKIPPED. The suite is incomplete, not
         green. A documented value, because a ceremony reading only the exit code must be able
         to tell "incomplete" from "clean" without parsing stdout.
      n  n failures. Failures take precedence over skips.
  The earlier docstring claimed 0 meant "passed and none skipped" while the code exited 0 on a
  skipped run. The claim and the instrument disagreed, and the instrument was the honest one.

  EXIT 3 IS NOT UNIQUE, and that is disclosed rather than papered over: a run with exactly three
  failures also exits 3. The summary line disambiguates and is printed on every run -- "SUITE
  FAILED" carries a failure count, "SUITE INCOMPLETE, NOT GREEN" carries a skip count. An offset
  that made the codes disjoint would be a rule nobody remembers at the moment it matters.

  CONSEQUENCE FOR CEREMONIES, from the F5-derive gate below. F5-derive re-derives the artifact's
  observed populations from live data, and can decide only at the artifact's derivation anchor
  HEAD. At ANY other HEAD it SKIPS by design rather than failing on ground that has
  legitimately moved -- so a post-seal ceremony run, whose commit has already moved HEAD, reads
  EXIT 3, and that is the expected clean result rather than a regression.

  STANDING LAW (operator ruling, carried at this cure): acceptance evidence over those
  populations is taken at anchor HEAD BEFORE any mutation of .mission/amendments/. Authoring a
  new amendment file moves a population while HEAD still equals the anchor -- the one window in
  which F5-derive FAILS rather than skips, and it would be correctly reporting a stale figure.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# tools/framework/tests/<this file>  ->  up three  ->  repo root.
# Anchored to THIS SCRIPT, never to the caller's cwd: a test whose subject
# depends on where it was invoked from is not a test.
$repoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$artifactPath = Join-Path $repoRoot 'docs\framework\expanded-schemas.md'
$basePath     = Join-Path $repoRoot 'docs\framework\expanded-schemas-base.md'
$schemaPath   = Join-Path $repoRoot 'docs\framework\evidence-manifest.schema.json'
$designPath   = Join-Path $repoRoot 'docs\framework\vanguard-collective-local-modes-v2.2.md'
$ledgerPath   = Join-Path $repoRoot '.mission\ledger\entries.jsonl'
$amendDir     = Join-Path $repoRoot '.mission\amendments'
$fragPaths    = @{
    '6' = Join-Path $repoRoot 'tools\mission-cli\config\expanded-schemas-section-6-validator-result.md'
    '7' = Join-Path $repoRoot 'tools\mission-cli\config\expanded-schemas-section-7-memory-ledger-entry.md'
    '8' = Join-Path $repoRoot 'tools\mission-cli\config\expanded-schemas-section-8-amendment-request.md'
}
$adrPath      = Join-Path $repoRoot 'tools\mission-cli\config\expanded-schemas-adr-032-additions.md'
$hookPath     = Join-Path $repoRoot 'tools\framework\hooks\evidence-post-tool-use.ps1'
$am419Path    = Join-Path $repoRoot '.mission\amendments\AM-419-design-authority-v2-2-schemas-base-a2.yaml'

$failures  = 0
$checksRun = 0
$skips     = 0

function Check {
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail)
    $script:checksRun++
    $tag = if ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ""
    Write-Host "[$tag] $Id -- $Title"
    if ($Detail) { Write-Host $Detail }
    if (-not $Ok) { $script:failures++ }
}

# A skip is NOT a pass. It is counted separately and suppresses the green line, because a suite
# that prints ALL PASSED while a check never ran is making the claim the check was meant to test.
function Skip {
    param([string]$Id, [string]$Title, [string]$Reason)
    $script:skips++
    Write-Host ""
    Write-Host "[SKIP] $Id -- $Title"
    Write-Host "       $Reason"
}

function Read-Lines([string]$p) {
    return ,([string[]]([System.IO.File]::ReadAllText($p) -split "`r`n|`n"))
}

# A field name is the leading backticked cell of a markdown table row.
function Get-FieldNames($lines) {
    $acc = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) {
        $m = [regex]::Match($l, '^\|\s*`([^`]+)`\s*\|')
        if ($m.Success) { $acc.Add($m.Groups[1].Value) }
    }
    return ,([string[]]$acc.ToArray())
}

function Get-SectionLines($lines, [string]$headingPattern) {
    $s = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $headingPattern) { $s = $i; break } }
    if ($s -lt 0) { return ,([string[]]@()) }
    $e = $lines.Count - 1
    for ($i = $s + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## ') { $e = $i - 1; break } }
    return ,([string[]]($lines[$s..$e]))
}

Write-Host "=============================================================================="
Write-Host " A2 ACCEPTANCE TEST"
Write-Host "=============================================================================="
Write-Host "repo root : $repoRoot"
Write-Host "artifact  : $artifactPath"

foreach ($p in @($artifactPath, $basePath, $schemaPath, $designPath, $adrPath, $hookPath, $fragPaths['6'], $fragPaths['7'], $fragPaths['8'])) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host ""
        Write-Host "[FAIL] PRE -- required input missing: $p"
        Write-Host ""
        Write-Host "=============================================================================="
        Write-Host " 1 FAILURE(S) -- SUITE FAILED (inputs absent; no checks could run)"
        Write-Host "=============================================================================="
        exit 1
    }
}

$artifact     = Read-Lines $artifactPath
$artifactText = [System.IO.File]::ReadAllText($artifactPath)
$base         = Read-Lines $basePath

# --- F(1) additive-only ----------------------------------------------------------------------
# Every field the base declares, and every field each fragment declares, must still be present in
# the artifact's corresponding section. The operator-ruled supersessions changed row CONTENT
# and row TYPE; they removed no field NAME, so this check is valid across
# them. A field that vanished without a ruling fails here.
$dropped = New-Object System.Collections.Generic.List[string]
$detail  = New-Object System.Collections.Generic.List[string]
foreach ($n in 1..10) {
    $pat = '^## ' + $n + '\. '
    $b = Get-FieldNames (Get-SectionLines $base $pat)
    $a = Get-FieldNames (Get-SectionLines $artifact $pat)
    $miss = @($b | Where-Object { $a -notcontains $_ })
    foreach ($m in $miss) { $dropped.Add("SS${n}:$m") }
    $detail.Add(('       SS{0,-3} base={1,-3} artifact={2,-3} {3}' -f $n, $b.Count, $a.Count, $(if ($miss.Count -eq 0) { 'all present' } else { 'DROPPED: ' + ($miss -join ', ') })))
}
foreach ($k in @('6','7','8')) {
    $f  = Get-FieldNames (Get-SectionLines (Read-Lines $fragPaths[$k]) ('^## ' + $k + '\. '))
    $a  = Get-FieldNames (Get-SectionLines $artifact ('^## ' + $k + '\. '))
    $miss = @($f | Where-Object { $a -notcontains $_ })
    foreach ($m in $miss) { $dropped.Add("frag${k}:$m") }
    $detail.Add(('       frag SS{0} fields={1,-3} {2}' -f $k, $f.Count, $(if ($miss.Count -eq 0) { 'all present' } else { 'DROPPED: ' + ($miss -join ', ') })))
}
$adrFields = Get-FieldNames (Read-Lines $adrPath)
$allFields = Get-FieldNames $artifact
$missAdr = @($adrFields | Where-Object { $allFields -notcontains $_ })
foreach ($m in $missAdr) { $dropped.Add("adr032:$m") }
$detail.Add(('       frag adr-032 fields={0,-3} {1}' -f $adrFields.Count, $(if ($missAdr.Count -eq 0) { 'all present' } else { 'DROPPED: ' + ($missAdr -join ', ') })))
Check 'F1' 'additive-only: every base and fragment field survives' ($dropped.Count -eq 0) (($detail -join "`n"))

# --- F(2a) sealed schema field spellings -----------------------------------------------------
# The field list is READ FROM the sealed JSON schema, never transcribed. A transcribed list is a
# hand-maintained inventory and drifts; this one cannot disagree with its source.
$schema = [System.IO.File]::ReadAllText($schemaPath) | ConvertFrom-Json
$schemaFields = New-Object System.Collections.Generic.List[string]
foreach ($p in $schema.properties.PSObject.Properties.Name) { $schemaFields.Add($p) }
foreach ($variant in $schema.properties.entries.items.oneOf) {
    foreach ($p in $variant.properties.PSObject.Properties.Name) {
        if (-not $schemaFields.Contains($p)) { $schemaFields.Add($p) }
    }
}
$missSchema = @($schemaFields | Where-Object { $artifactText -cnotmatch ('`' + [regex]::Escape($_) + '`') })
Check 'F2a' 'every sealed evidence-manifest.schema.json field appears with exact spelling' `
    ($missSchema.Count -eq 0) `
    ("       schema declares $($schemaFields.Count) field names; absent from artifact: " + $(if ($missSchema.Count -eq 0) { 'none' } else { $missSchema -join ', ' }))

$states = @('ABSENT','PARTIAL','FINALIZED','TAMPERED')
$missStates = @($states | Where-Object { $artifactText -cnotmatch ('`' + $_ + '`') })
Check 'F2a-states' 'all four derived evidence states are named' ($missStates.Count -eq 0) `
    ("       absent: " + $(if ($missStates.Count -eq 0) { 'none' } else { $missStates -join ', ' }))

# --- F(2b) design SS12 field spellings -------------------------------------------------------
# Identifiers are extracted from ANY inline code span in design SS12, not only from spans that are
# exactly one identifier: SS12.4 states the Push Authorization fields as a single brace-list inside
# one span, which a whole-span match cannot see.
$design = Read-Lines $designPath
$s12 = -1; $e12 = -1
for ($i = 0; $i -lt $design.Count; $i++) {
    if ($design[$i] -match '^## 12\. ') { $s12 = $i }
    elseif ($s12 -ge 0 -and $design[$i] -match '^## 13\. ') { $e12 = $i - 1; break }
}
$designFields = New-Object System.Collections.Generic.List[string]
if ($s12 -ge 0 -and $e12 -gt $s12) {
    foreach ($l in $design[$s12..$e12]) {
        foreach ($span in [regex]::Matches($l, '`([^`]+)`')) {
            foreach ($id in [regex]::Matches($span.Groups[1].Value, '\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b')) {
                if (-not $designFields.Contains($id.Value)) { $designFields.Add($id.Value) }
            }
        }
        $m2 = [regex]::Match($l, '^\s{2,}([a-z][a-z0-9_]*):')
        if ($m2.Success -and -not $designFields.Contains($m2.Groups[1].Value)) { $designFields.Add($m2.Groups[1].Value) }
    }
}
$missDesign = @($designFields | Where-Object { $artifactText -cnotmatch ('`' + [regex]::Escape($_) + '`') })
Check 'F2b' 'every snake_case field named by design SS12 appears with exact spelling' `
    ($designFields.Count -gt 0 -and $missDesign.Count -eq 0) `
    ("       design SS12 names $($designFields.Count) identifiers; absent from artifact: " + $(if ($missDesign.Count -eq 0) { 'none' } else { $missDesign -join ', ' }))

# --- F(2c) log-line field spellings, mirrored from the hook that writes them ------------------
# The manifest's field names are read from the sealed JSON schema (F2a). The LOG's field names
# are in no schema file at all: the artifact's SS12 declares them, and the only other statement
# of them is the capture hook's own entry construction. So they are read from there. Typing
# 'seq' into a list here would be exactly the hand-maintained inventory this file forbids;
# deriving the whole set from the writer is not, and it cannot drift away from the writer.
$hookLines = Read-Lines $hookPath
$logFields = New-Object System.Collections.Generic.List[string]
$inEntry   = $false
foreach ($l in $hookLines) {
    if (-not $inEntry) {
        if ($l -match '^\s*\$entry\s*=\s*\[ordered\]@\{') { $inEntry = $true }
        continue
    }
    if ($l -match '^\s*\}\s*$') { break }
    $m = [regex]::Match($l, '^\s*([a-z][a-z0-9_]*)\s*=')
    if ($m.Success -and -not $logFields.Contains($m.Groups[1].Value)) { $logFields.Add($m.Groups[1].Value) }
}
$missLog = @($logFields | Where-Object { $artifactText -cnotmatch ('`' + [regex]::Escape($_) + '`') })
Check 'F2c' 'every log-line field the capture hook writes appears with exact spelling' `
    ($logFields.Count -gt 0 -and $missLog.Count -eq 0) `
    ("       hook constructs $($logFields.Count) log-line field names: " + ($logFields -join ', ') + "`n" +
     "       absent from artifact: " + $(if ($missLog.Count -eq 0) { 'none' } else { $missLog -join ', ' }))

# --- F(3) registered decisions ---------------------------------------------------------------
# NO INVENTORY. The earlier form of this check carried a hardcoded seven-item list against a
# twelve-row table: a hand-maintained inventory inside the file whose own docstring forbids one,
# and it silently exempted every row it did not name. The set is now DERIVED from the document's
# own Registered-decisions table -- the F5-mirror technique -- so every row that table declares
# must carry an explicit status, and a row added later is covered the day it is added.
# ZERO ROWS IS A FAILURE, never a quiet pass: a matcher that finds nothing and reports success
# is instrument law (a)'s defect wearing different clothes.
$regRows = New-Object System.Collections.Generic.List[psobject]
foreach ($l in (Get-SectionLines $artifact '^## Registered decisions')) {
    if ($l -notmatch '^\|') { continue }
    $cells = @($l -split '\|')
    if ($cells.Count -lt 4) { continue }
    $item   = $cells[1].Trim()
    $status = $cells[2].Trim()
    if ($item -eq 'Item')       { continue }   # header row
    if ($item -match '^-{2,}$') { continue }   # separator row
    $regRows.Add([pscustomobject]@{ Item = $item; Status = $status })
}
# WORD-BOUNDARIED: a status keyword is a WORD in the status cell, not a substring of one.
$noStatus = @($regRows | Where-Object { $_.Status -cnotmatch '\b(RESOLVED|DEFERRED|REGISTERED|RATIFIED)\b' })
Check 'F3' 'every row of the Registered-decisions table carries an explicit status' `
    ($regRows.Count -gt 0 -and $noStatus.Count -eq 0) `
    ("       rows derived from the table: $($regRows.Count)`n" +
     "       without a status: " + $(if ($noStatus.Count -eq 0) { 'none' } else { ($noStatus | ForEach-Object { $_.Item }) -join ' / ' }))

# --- F(3-coverage) the AMENDMENT-NAMED set, and only that set -------------------------------
# F3 derives from the table and therefore cannot see a row that was DELETED. This is the other
# direction (law 3, the N10 pattern), and ITS REACH IS STATED EXACTLY, per operator ruling:
# it derives the ID-SHAPED items the amendment's SS C names -- N-e, N-g, N-k, NB-1, NB-2 -- from the
# amendment itself, and requires each to appear in the table's Item column. That is FIVE of the
# table's rows. The remaining rows are registered from v2.2 and ledger sources this test does
# not read, and this check makes NO claim about them. A coverage check labelled "all registered
# decisions" while deriving five of them would be the defect F3 was just cured of (law 4:
# per-member statement, per-member demonstration).
if (-not (Test-Path -LiteralPath $am419Path)) {
    Skip 'F3-coverage' 'the amendment-named registered items each appear in the table' `
        "The amendment is not on disk at $am419Path, so the named set cannot be derived. This check reads the amendment rather than transcribing its list, and declines to decide without it."
} else {
    $am419Text = [System.IO.File]::ReadAllText($am419Path)
    $namedIds  = @([regex]::Matches($am419Text, '\bN-[a-z]\b|\bNB-[0-9]+\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $regItems  = (($regRows | ForEach-Object { $_.Item }) -join "`n")
    $missingId = @($namedIds | Where-Object { $regItems -cnotmatch ('\b' + [regex]::Escape($_) + '\b') })
    Check 'F3-coverage' 'the amendment-named registered items each appear in the table' `
        ($namedIds.Count -gt 0 -and $missingId.Count -eq 0) `
        ("       the amendment names $($namedIds.Count) ID-shaped items: " + ($namedIds -join ', ') + "`n" +
         "       reach: those $($namedIds.Count) of the table's $($regRows.Count) rows; the rest are outside this check`n" +
         "       absent from the table: " + $(if ($missingId.Count -eq 0) { 'none' } else { $missingId -join ', ' }))
}

# NB-2 is REQUIRED to read as a deferral. A deferral dressed as a resolution is the failure mode
# this check exists for -- it is the one item the amendment's SS C forbids A2 from resolving.
$nb2 = @($artifact | Where-Object { $_ -match '\bNB-2\b' })
$nb2Deferred = @($nb2 | Where-Object { $_ -cmatch 'DEFERRED' }).Count -gt 0
Check 'F3-NB2' 'NB-2 is recorded as an explicit deferral, not as resolved' $nb2Deferred `
    ("       NB-2 mentions: $($nb2.Count); carrying DEFERRED: " + $(@($nb2 | Where-Object { $_ -cmatch 'DEFERRED' }).Count))

# --- F(4) citation note ----------------------------------------------------------------------
$citeIdx = -1
for ($i = 0; $i -lt $artifact.Count; $i++) { if ($artifact[$i] -match '^## Citation convention') { $citeIdx = $i; break } }
Check 'F4' 'LM2 citation note present near the top' `
    ($citeIdx -ge 0 -and $citeIdx -lt 40 -and $artifactText -cmatch 'LM2-ADR-0NN') `
    ("       citation heading at line " + $(if ($citeIdx -ge 0) { $citeIdx + 1 } else { 'ABSENT' }) + "; LM2-ADR-0NN present: " + ($artifactText -cmatch 'LM2-ADR-0NN'))

# --- F(5) open-vocabulary mirror, enforced BOTH directions -----------------------------------
# The prose says N fields are open vocabularies. Derive N from the document's own structure and
# require the word to match. Enumerating members beside a count is only safe while something
# enforces that the enumeration and the count agree.
# ASCII-ONLY PATTERN: the heading contains an em-dash, wildcarded rather than spelled -- see
# instrument law (a) in the docstring.
$ovHeads = @($artifact | Where-Object { $_ -cmatch '^### `[a-z_]+` .+ open vocabulary$' })
$numberWord = @{ 1 = 'one'; 2 = 'two'; 3 = 'three'; 4 = 'four'; 5 = 'five'; 6 = 'six' }
$expectedWord = if ($numberWord.ContainsKey($ovHeads.Count)) { $numberWord[$ovHeads.Count] } else { '<out-of-range>' }
$proseWords = New-Object System.Collections.Generic.List[string]
foreach ($l in $artifact) {
    foreach ($m in [regex]::Matches($l, '(?i)\b(one|two|three|four|five|six)\s+fields?\b')) {
        $proseWords.Add($m.Groups[1].Value.ToLower())
    }
}
$wrongWords = @($proseWords | Where-Object { $_ -ne $expectedWord })
Check 'F5-mirror' 'the open-vocabulary count in prose matches the sections that exist' `
    ($ovHeads.Count -gt 0 -and $proseWords.Count -gt 0 -and $wrongWords.Count -eq 0) `
    ("       sections found: $($ovHeads.Count) -> expected word '$expectedWord'`n" +
     "       prose counts found: $($proseWords.Count); disagreeing: " + $(if ($wrongWords.Count -eq 0) { 'none' } else { ($wrongWords | Select-Object -Unique) -join ', ' }) + "`n" +
     (($ovHeads | ForEach-Object { '       ' + $_ }) -join "`n"))

# --- F(5) derived populations actually re-derive ---------------------------------------------
# The artifact prints three observed-set blocks and the HEAD they were derived at. Re-derive them
# and require the printed blocks to appear verbatim. Gated on the anchor: at a different HEAD the
# live data legitimately differs, so this SKIPS with a reason rather than failing on the operator.
#
# (c) A THIRD INSTRUMENT LAW, earned right here: NATIVE STDERR IS NOT A TERMINATING ERROR, BUT
#     PowerShell 5.1 MAKES IT ONE. Under $ErrorActionPreference = 'Stop', a native executable
#     writing to stderr raises NativeCommandError and KILLS THE SCRIPT -- even with `2>$null`,
#     which suppresses the text and not the record. The previous line was
#         $currentHead = (& git -C $repoRoot rev-parse HEAD 2>$null)
#     and it meant that whenever `git rev-parse` failed -- a tree that is not a repository, git
#     not on PATH -- the suite DIED at exit 1 instead of taking the skip branch three lines
#     below. The skip path the docstring promises was unreachable in exactly the case it was
#     written for, and no run at the anchor could reveal that, because there git succeeds.
#     Found by driving the skip path rather than reading it (law 6, execution-beats-inspection).
#     Failure to resolve HEAD is NOT a test failure here: it means "cannot decide", which is
#     what Skip is for.
$anchorMatch = [regex]::Match($artifactText, 'HEAD = ([0-9a-f]{40})')
$currentHead = $null
$prevEap     = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $gitOut = & git -C $repoRoot rev-parse HEAD 2>&1
    if ($LASTEXITCODE -eq 0 -and $gitOut) {
        $currentHead = ($gitOut | Select-Object -First 1).ToString().Trim()
    }
} catch {
    $currentHead = $null
} finally {
    $ErrorActionPreference = $prevEap
}
if (-not $currentHead) { $currentHead = '<unresolved>' }
if (-not $anchorMatch.Success) {
    Check 'F5-derive' 'observed sets re-derive at the stated anchor' $false '       no derivation anchor (HEAD = <40 hex>) found in the artifact'
} elseif ($currentHead -ne $anchorMatch.Groups[1].Value) {
    Skip 'F5-derive' 'observed sets re-derive at the stated anchor' `
        ("artifact anchor is $($anchorMatch.Groups[1].Value); repository HEAD is $currentHead. The live populations legitimately differ at a different commit, so this check cannot decide. Re-run at the anchor, or re-derive the artifact's observed sets against the new HEAD.")
} else {
    function Format-Population($values) {
        return @($values | Group-Object | Sort-Object Count -Descending | ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name })
    }
    $ledgerLines = @([System.IO.File]::ReadAllLines($ledgerPath) | Where-Object { $_.Trim() })
    $typeBlock  = Format-Population (@($ledgerLines | ForEach-Object { ($_ | ConvertFrom-Json).type }))
    $scopeBlock = Format-Population (@($ledgerLines | ForEach-Object { ($_ | ConvertFrom-Json).scope }))
    $ttBlock    = Format-Population (@(Get-ChildItem -LiteralPath $amendDir -Filter *.yaml -File | ForEach-Object {
        $m = [regex]::Match([System.IO.File]::ReadAllText($_.FullName), '(?m)^target_type:\s*(\S+)')
        if ($m.Success) { $m.Groups[1].Value } else { '(none)' }
    }))
    $blocks = @{ 'ledger type' = $typeBlock; 'ledger scope' = $scopeBlock; 'amendment target_type' = $ttBlock }
    $mismatched = New-Object System.Collections.Generic.List[string]
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($name in @('ledger type','ledger scope','amendment target_type')) {
        $blk = $blocks[$name]
        $joined = ($blk -join "`n")
        $present = $artifactText.Replace("`r`n", "`n").Contains($joined)
        if (-not $present) { $mismatched.Add($name) }
        $lines.Add(('       {0,-24} {1,2} distinct values  {2}' -f $name, $blk.Count, $(if ($present) { 'block reproduces verbatim' } else { 'DOES NOT MATCH the artifact' })))
    }
    Check 'F5-derive' 'observed sets re-derive verbatim at the stated anchor' ($mismatched.Count -eq 0) (($lines -join "`n"))
}

# --- F(6) encoding ---------------------------------------------------------------------------
$bytes  = [System.IO.File]::ReadAllBytes($artifactPath)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$strictOk = $true
$strictErr = ''
try {
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    $null = $strict.GetString($bytes)
} catch { $strictOk = $false; $strictErr = $_.Exception.Message }
$cr = @($bytes | Where-Object { $_ -eq 13 }).Count
# Double-encoding leaves U+00C3 / U+00C2 lead bytes in the decoded text -- the signature of UTF-8
# bytes decoded as ANSI and re-encoded. Spelled by code point, never as a literal, per law (a).
$mojiPattern = "$([char]0x00C3)|$([char]0x00C2)"
$mojiLines = @($artifact | Where-Object { $_ -cmatch $mojiPattern }).Count
Check 'F6' 'strict UTF-8, no BOM, LF only, no double-encoding artefacts' `
    ((-not $hasBom) -and $strictOk -and ($cr -eq 0) -and ($mojiLines -eq 0)) `
    ("       BOM: $hasBom (expect False)`n" +
     "       strict UTF-8 decode: $strictOk $strictErr`n" +
     "       CR bytes: $cr (expect 0)`n" +
     "       lines with double-encoding artefacts: $mojiLines (expect 0)")

$trailing = @($artifact | Where-Object { $_ -ne $_.TrimEnd() }).Count
Check 'F6-trailing' 'no trailing whitespace (the artifact states it carries none)' ($trailing -eq 0) `
    ("       lines with trailing whitespace: $trailing (expect 0)")

# --- summary ---------------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================================="
Write-Host " artifact sha256 : $((Get-FileHash $artifactPath -Algorithm SHA256).Hash)"
Write-Host " artifact bytes  : $($bytes.Length)"
Write-Host "=============================================================================="
# The count is derived from checks actually run, never hardcoded. A skipped check is not a passed
# check: any skip suppresses the green line, because the alternative is a suite reporting success
# for a property it did not examine.
if ($failures -eq 0 -and $skips -eq 0) {
    Write-Host " ALL $checksRun CHECKS PASSED"
} elseif ($failures -eq 0) {
    Write-Host " $checksRun CHECK(S) PASSED, $skips SKIPPED -- SUITE INCOMPLETE, NOT GREEN"
} else {
    Write-Host " $failures FAILURE(S) across $checksRun CHECK(S), $skips SKIPPED -- SUITE FAILED"
}
Write-Host "=============================================================================="

# EXIT CONTRACT, per the docstring. Failures outrank skips; a skip-only run is 3, never 0.
# `exit $failures` alone returned 0 on a skipped run, which is the claim the docstring made and
# the code did not keep.
if ($failures -gt 0) { exit $failures }
if ($skips    -gt 0) { exit 3 }
exit 0
