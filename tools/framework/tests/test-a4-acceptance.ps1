#Requires -Version 5.1
<#
.SYNOPSIS
  A4 acceptance test -- the bootstrap build-dispatch set.

.DESCRIPTION
  Citation convention (v2.2's standing convention): LM2-ADR-0NN / "design SS<n>"
  denote docs/framework/vanguard-collective-local-modes-v2.2.md. "schemas SS<n>" denotes
  docs/framework/expanded-schemas.md. "spec SS<n>" denotes docs/framework/mission-verify-spec.md.
  Bare ADR-0NN denotes the on-disk file under tools/mission-cli/config/. "SS" is this file's
  ASCII spelling of the section mark.

  WHAT THIS IS FOR. It exists so the dispatch-set amendment's SS F acceptance criteria G(1)-G(8) can be
  RE-DERIVED -- by a validator, by a future ceremony, by anyone -- instead of taken on a build
  session's word. Placed on disk on the A1 / A2 / A3 precedent: an acceptance check
  that exists only in a build transcript is testimony. It is NOT a substitute for a validator
  deriving the criteria independently.

  WHAT IS DERIVED AND WHAT IS TRANSCRIBED -- STATED PER-CHECK, BECAUSE THE UNIVERSAL DIED.
  An earlier revision of this docstring claimed "NO INVENTORY IS WRITTEN HERE / Every
  population this file checks is derived from an artifact on disk". A validator falsified it:
  G4 carried its three NB-2 claims as literal regexes, in the one check the dispatch-set amendment's SS F explicitly
  ordered DERIVED. The universal is deleted rather than defended -- the choice this program
  has made every time -- and replaced by this statement.

    DERIVED FROM AN ARTIFACT ON DISK, and re-derived on every run:
      G1  the dispatch inventory, from the dispatch-set amendment's SS B
      G2  the required block headings, from the dispatch-set amendment's SS C
      G3  the amendment id namespace, from .mission/amendments/
      G4  the NB-2 claim token set, the CAPTURE GAP token, the "coverage hole" phrase and the
          "no code" negation -- ALL extracted from spec SS5.2's own Correct-form bullets, plus
          the forbidden "one line" phrase from SS5.2's closing sentence
      G5  the permitted write-surface prefixes, from the evidence-plane program amendment's SS C
      G6  the sealed anchor set, from the dispatch-set amendment's SS A
      G9  the sealed anchor set (as G6) intersected with each dispatch's declared write surface

    TRANSCRIBED INTO THIS FILE, and therefore able to drift:
      G3  the four AUTHORITY field names (NEEDS ITS OWN AMENDMENT, AMENDMENT COVERS,
          MOVES A SEALED HASH, SEALED FILE). The dispatch-set amendment's SS C names the BLOCKS, not these fields.
      G4  the negation vocabulary used to decide whether an occurrence of "one line" is
          affirmative or refusing
      G7  the three double-encoding sentinel sequences
      G8  the self-probe tokens ($PSScriptRoot, the cwd call, the native-invocation shape)
    Each of those is a small vocabulary rather than a population, and each is named here so a
    reader knows exactly where this instrument can go stale.

  REACH LINES STATE REACH, NEVER RESULT. A validator found this file printing
  "All OTHER cited amendment ids must resolve on disk, and do." two lines below the [FAIL] that
  refuted it -- a green claim on a failing run, instrument law 5. Every Reach text in this file
  was swept for that shape. Reach now describes what a check COVERS; it never asserts how the
  check came out. Where a Reach must report a run-specific tally it reports counts, which are
  facts about the run rather than verdicts about it.

  READ-ONLY BY CONSTRUCTION. This test opens files. It writes nothing, anywhere, so there is
  no sandbox to build and no residue to clean.

  IT INVOKES NO NATIVE EXECUTABLE, AND THAT IS DELIBERATE (instrument law (c) below).

  WHAT IS GATED, AND ON WHAT. The dispatch-set amendment is placed at the Phase 1 ceremony commit, so before
  placement the four checks that read it -- G1, G2, G6, G9 -- SKIP and the suite exits 3.
  After placement they decide, AT ANY HEAD, forever: they read a NAMED FILE whose bytes are
  immutable once placed, never a POPULATION a ceremony moves. That is the deliberate
  difference from the A2 instrument, which derived a figure from the count of
  .mission/amendments/ -- ground its own ceremony moved -- and therefore reads exit 3 forever
  after its seal. Nothing here counts files in a directory.

  THREE INSTRUMENT LAWS THIS FILE OBEYS, inherited from the A1, A2 and A3 instruments.

  (a) PURE ASCII SOURCE, PATTERNS INCLUDED. A BOM-less .ps1 is parsed by PowerShell 5.1 in the
      ANSI codepage. A non-ASCII character inside a regex here decodes to mojibake and the
      match SILENTLY NEVER FIRES -- the check reports nothing and reads as passing. Check G7b
      asserts this file's own bytes.

  (b) PATH VARIABLES ARE NOT CASE-VARIANTS OF DATA VARIABLES. PowerShell variable names are
      CASE-INSENSITIVE: $a4 and $A4 are one variable, so `$a4 = ReadText $A4` destroys the
      path it just read. Path variables here carry a Path suffix.

  (c) NATIVE STDERR IS NOT A TERMINATING ERROR, BUT POWERSHELL 5.1 MAKES IT ONE. Under
      $ErrorActionPreference = 'Stop' a native executable writing to stderr raises
      NativeCommandError and kills the script -- even with 2>$null, which suppresses the text
      and not the record. That turned the A2 suite's skip branch into a crash. Satisfied here
      by construction: nothing native is invoked.

  EXIT CONTRACT -- true as written, and ceremony-safe.
      0  every check ran and passed; nothing skipped.
      3  every check that ran passed, but at least one SKIPPED. Incomplete, not green.
      n  n failures. Failures take precedence over skips.
  EXIT 3 IS NOT UNIQUE, and that is disclosed rather than papered over: a run with exactly
  three failures also exits 3. The summary line disambiguates and is printed on every run --
  "SUITE FAILED" carries a failure count, "SUITE INCOMPLETE, NOT GREEN" carries a skip count.
  An offset that made the codes disjoint would be a rule nobody remembers when it matters.

  THE SUMMARY COUNTS EMITTED CHECKS, NOT G-CRITERIA. The dispatch-set amendment's SS F states eight criteria; this
  file emits more check lines than that because G7 splits into G7a/G7b and because G9 was
  added by the B4 cure. The summary line says so rather than letting a reader infer that
  "checks emitted : 10" means ten criteria.

  WHAT THIS FILE DOES NOT DO. It is an instrument, not a boundary. NOTHING INVOKES IT -- no
  hook, no gate, no ceremony step -- so it decides only when a person runs it, and the
  dispatch set can drift between runs of it. It checks that the dispatches are WELL-FORMED and
  that their declarations are internally consistent with the amendments that authorize them.
  It cannot decide whether a dispatch would produce a good build, and no check here would
  notice a well-formed dispatch that specifies the wrong thing.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# tools/framework/tests/<this file> -> up three -> repo root.
# Anchored to THIS SCRIPT, never to the caller's cwd: a test whose
# subject depends on where it was invoked from is not a test.
$repoRootPath    = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$dispatchDirPath = Join-Path $repoRootPath 'docs\framework\build-dispatches'
$amendDirPath    = Join-Path $repoRootPath '.mission\amendments'
$am417Path       = Join-Path $amendDirPath 'AM-417-framework-evidence-plane-artifact-program.yaml'
$specPath        = Join-Path $repoRootPath 'docs\framework\mission-verify-spec.md'
$selfPath        = $PSCommandPath

$script:Failures = 0
$script:Skips    = 0
$script:Ran      = 0

function ReadText { param([string]$Path) return [System.IO.File]::ReadAllText($Path) }

function Check {
    param([string]$Id, [string]$Desc, [bool]$Ok, [string]$Detail = '')
    $script:Ran++
    if ($Ok) {
        Write-Host ("[PASS] {0}  {1}" -f $Id, $Desc)
    } else {
        $script:Failures++
        Write-Host ("[FAIL] {0}  {1}" -f $Id, $Desc)
        if ($Detail) { foreach ($l in ($Detail -split "`n")) { if ($l.Trim()) { Write-Host ("       " + $l.TrimEnd()) } } }
    }
    return $Ok
}

function Skip {
    param([string]$Id, [string]$Desc, [string]$Reason)
    $script:Skips++
    Write-Host ("[SKIP] {0}  {1}" -f $Id, $Desc)
    Write-Host ("       reason: " + $Reason)
}

# Reach describes COVERAGE. It must never assert an outcome -- see the docstring's B3 note.
function Reach { param([string]$Text) Write-Host ("       REACH: " + $Text) }

function Get-MdSection {
    param([string[]]$Lines, [string]$Heading)
    $out = New-Object System.Collections.Generic.List[string]
    $inSec = $false
    foreach ($l in $Lines) {
        if ($l -match '^##\s+(.+?)\s*$') {
            if ($inSec) { break }
            if ($Matches[1] -eq $Heading) { $inSec = $true; continue }
        }
        if ($inSec) { $out.Add($l) }
    }
    return $out.ToArray()
}

function Get-AmSection {
    param([string[]]$Lines, [string]$Marker)
    $out = New-Object System.Collections.Generic.List[string]
    $inSec = $false
    foreach ($l in $Lines) {
        if ($l -match '^\s*SS ([A-Z])\.\s') {
            if ($inSec) { break }
            if ($l -match ('^\s*SS ' + $Marker + '\.\s')) { $inSec = $true; continue }
        }
        if ($inSec) { $out.Add($l) }
    }
    return $out.ToArray()
}

# Every backticked path-like token on a line, placeholders included. An earlier revision took
# only the FIRST token on BULLET lines and required the token to be whitespace-free -- three
# silent exemptions in one extractor, which is the A2 B2 defect in the check whose own comment
# cites B2 as its motivation.
function Get-PathTokens {
    param([string]$Line)
    $out = @()
    foreach ($m in ([regex]::Matches($Line, '`([^`]+)`'))) {
        $tok = $m.Groups[1].Value.Trim()
        if (-not $tok) { continue }
        if ($tok -notmatch '/' -and $tok -notmatch '\.(ps1|yaml|yml|json|md)$') { continue }
        if ($out -notcontains $tok) { $out += $tok }
    }
    return $out
}

Write-Host ''
Write-Host '=== A4 ACCEPTANCE -- build-dispatch set + instrument (dispatch-set amendment SS F) ==='
Write-Host ("repo root     : " + $repoRootPath)
Write-Host ("dispatch dir  : " + $dispatchDirPath)

$am421Path = $null
if (Test-Path -LiteralPath $amendDirPath) {
    $cand = @(Get-ChildItem -LiteralPath $amendDirPath -Filter 'AM-421-*.yaml' -File -ErrorAction SilentlyContinue)
    if ($cand.Count -eq 1) { $am421Path = $cand[0].FullName }
    elseif ($cand.Count -gt 1) { $am421Path = 'AMBIGUOUS' }
}
Write-Host ("amendment     : " + $(if ($null -eq $am421Path) { '(absent -- G1/G2/G6/G9 will SKIP)' } else { $am421Path }))
Write-Host ''

$dispatchFiles = @()
if (Test-Path -LiteralPath $dispatchDirPath) {
    $dispatchFiles = @(Get-ChildItem -LiteralPath $dispatchDirPath -Filter '*.md' -File | Sort-Object Name)
}

$am421Lines = @()
$am421Ok    = ($null -ne $am421Path -and $am421Path -ne 'AMBIGUOUS')
if ($am421Ok) { $am421Lines = (ReadText $am421Path) -split "`n" }

# --- sealed anchor set, derived once from the dispatch-set amendment's SS A (used by G6 and G9) ---
$anchors = New-Object System.Collections.Generic.List[psobject]
$anchorAbbrev = 0
if ($am421Ok) {
    foreach ($l in (Get-AmSection $am421Lines 'A')) {
        if ($l -match '^\s+([0-9a-f]{8})\s+(\d+)\s+(\S+)\s*$') {
            if ($Matches[3] -match '\.\.\.') { $anchorAbbrev++; continue }
            $anchors.Add([pscustomobject]@{ Prefix = $Matches[1]; Length = [int]$Matches[2]; Rel = $Matches[3] })
        }
    }
}

# =========================================================================================
# G1 -- dispatch-set completeness, BOTH directions.
# =========================================================================================
if (-not $am421Ok) {
    Skip 'G1' 'dispatch set matches SS B of the dispatch-set amendment in both directions' 'the dispatch-set amendment is not on disk (placed at the Phase 1 ceremony commit)'
} else {
    $declared = New-Object System.Collections.Generic.List[string]
    foreach ($l in (Get-AmSection $am421Lines 'B')) {
        if ($l -match '^\s*D\d\s+(build-dispatch-[a-z0-9\-]+\.md)\s*$') { $declared.Add($Matches[1]) }
    }
    $onDisk = @($dispatchFiles | ForEach-Object { $_.Name })
    $problems = @()
    if ($declared.Count -eq 0) { $problems += 'ZERO dispatches derived from SS B of the dispatch-set amendment -- a derivation that finds nothing is a failure, not a pass' }
    foreach ($d in $declared) { if ($onDisk -notcontains $d) { $problems += ("declared in SS B, ABSENT on disk: " + $d) } }
    foreach ($f in $onDisk)   { if ($declared -notcontains $f) { $problems += ("on disk, NOT declared in SS B: " + $f) } }
    [void](Check 'G1' ("dispatch set matches SS B of the dispatch-set amendment in both directions (" + $declared.Count + " declared, " + $onDisk.Count + " on disk)") ($problems.Count -eq 0) ($problems -join "`n"))
}

# =========================================================================================
# G2 -- every dispatch carries every block the dispatch-set amendment's SS C lists.
# =========================================================================================
if (-not $am421Ok) {
    Skip 'G2' 'every dispatch carries every SS C block' 'the dispatch-set amendment is not on disk'
} else {
    $blocks = New-Object System.Collections.Generic.List[string]
    foreach ($l in (Get-AmSection $am421Lines 'C')) {
        if ($l -match '^\s+([A-Z][A-Z0-9\-]*(?: [A-Z0-9\-]+)*)\s+--\s') { $blocks.Add($Matches[1]) }
    }
    $problems = @()
    if ($blocks.Count -eq 0) { $problems += 'ZERO block headings derived from SS C of the dispatch-set amendment -- derivation found nothing' }
    if ($dispatchFiles.Count -eq 0) { $problems += 'ZERO dispatch files found' }
    foreach ($f in $dispatchFiles) {
        $txt = ReadText $f.FullName
        foreach ($b in $blocks) {
            if ($txt -notmatch ('(?m)^##\s+' + [regex]::Escape($b) + '\s*$')) { $problems += ($f.Name + ' :: missing block "' + $b + '"') }
        }
    }
    [void](Check 'G2' ("every dispatch carries every SS C block (" + $blocks.Count + " blocks x " + $dispatchFiles.Count + " dispatches)") ($problems.Count -eq 0) ($problems -join "`n"))
    if ($blocks.Count -gt 0) { Reach ("block headings are derived from SS C of the dispatch-set amendment, not listed here: " + ($blocks -join ', ')) }
}

# =========================================================================================
# G3 -- authority and amendment status, PER MEMBER.
# =========================================================================================
$knownAmendments = @()
if (Test-Path -LiteralPath $amendDirPath) {
    $knownAmendments = @(Get-ChildItem -LiteralPath $amendDirPath -Filter 'AM-*.yaml' -File | ForEach-Object {
        if ($_.Name -match '^(AM-\d+)') { $Matches[1] } })
}
$problems = @()
$selfRefs = 0
foreach ($f in $dispatchFiles) {
    $lines  = (ReadText $f.FullName) -split "`n"
    $joined = (Get-MdSection $lines 'AUTHORITY') -join "`n"
    if ($joined -notmatch '(?m)^NEEDS ITS OWN AMENDMENT:\s*(YES|NO)\s*$') {
        $problems += ($f.Name + ' :: no "NEEDS ITS OWN AMENDMENT: YES|NO" line in AUTHORITY')
    } elseif ($Matches[1] -eq 'YES' -and $joined -notmatch '(?m)^AMENDMENT COVERS:\s*\S') {
        $problems += ($f.Name + ' :: declares NEEDS ITS OWN AMENDMENT: YES but carries no "AMENDMENT COVERS:" line')
    }
    if ($joined -notmatch '(?m)^MOVES A SEALED HASH:\s*(YES|NO)\s*$') {
        $problems += ($f.Name + ' :: no "MOVES A SEALED HASH: YES|NO" line in AUTHORITY')
    } elseif ($Matches[1] -eq 'YES' -and $joined -notmatch '(?m)^SEALED FILE:\s*\S+\s+[0-9a-f]{8}\s*$') {
        $problems += ($f.Name + ' :: declares MOVES A SEALED HASH: YES but carries no "SEALED FILE: <path> <8-hex>" line')
    }
    foreach ($m in ([regex]::Matches($joined, 'AM-\d+'))) {
        if ($m.Value -eq 'AM-421') { $selfRefs++; continue }
        if ($knownAmendments -notcontains $m.Value) {
            $problems += ($f.Name + ' :: AUTHORITY cites ' + $m.Value + ' which does not resolve in .mission/amendments/')
        }
    }
}
if ($dispatchFiles.Count -eq 0) { $problems += 'ZERO dispatch files found' }
[void](Check 'G3' ("every dispatch resolves its authority and amendment status, per member (" + $dispatchFiles.Count + " dispatches)") ($problems.Count -eq 0) ($problems -join "`n"))
Reach ("covers four AUTHORITY fields whose NAMES are transcribed into this file, and CHECKS every cited amendment id except the dispatch-set amendment's own against .mission/amendments/. Its self-references are excluded by design (" + $selfRefs + " seen) because it is placed at the ceremony commit this set is sealed by. Findings, if any, are listed above this line.")

# =========================================================================================
# G4 -- the NB-2 dispatch carries the CORRECTED characterization. Claims DERIVED from spec SS5.2.
# =========================================================================================
$d2 = @($dispatchFiles | Where-Object { $_.Name -like '*nb2*' })
if (-not (Test-Path -LiteralPath $specPath)) {
    [void](Check 'G4' 'the NB-2 dispatch carries the corrected characterization' $false 'mission-verify-spec.md is absent; the claim set cannot be derived')
} elseif ($d2.Count -ne 1) {
    [void](Check 'G4' 'the NB-2 dispatch carries the corrected characterization' $false ("expected exactly one dispatch matching *nb2*; found " + $d2.Count))
} else {
    $specLines = (ReadText $specPath) -split "`n"
    # SS5.2 body
    $sec = New-Object System.Collections.Generic.List[string]
    $inSec = $false
    foreach ($l in $specLines) {
        if ($l -match '^###\s+5\.2\s') { $inSec = $true; continue }
        if ($inSec -and $l -match '^#{2,3}\s') { break }
        if ($inSec) { $sec.Add($l) }
    }
    # the Correct-form bullet block
    $cfIdx = -1
    for ($i = 0; $i -lt $sec.Count; $i++) { if ($sec[$i] -match 'Correct form') { $cfIdx = $i; break } }
    $bullets = New-Object System.Collections.Generic.List[string]
    if ($cfIdx -ge 0) {
        $cur = $null
        for ($i = $cfIdx + 1; $i -lt $sec.Count; $i++) {
            $l = $sec[$i]
            if ($l -match '^-\s+(.*)$') { if ($cur) { $bullets.Add($cur) }; $cur = $Matches[1] }
            elseif ($cur -and $l -match '^\s+\S') { $cur += ' ' + $l.Trim() }
            elseif ($cur -and $l.Trim() -eq '') { $bullets.Add($cur); $cur = $null; if ($bullets.Count -ge 3) { break } }
        }
        if ($cur) { $bullets.Add($cur) }
    }
    # derive the required token set from those bullets
    $required = New-Object System.Collections.Generic.List[string]
    foreach ($b in $bullets) {
        foreach ($m in ([regex]::Matches($b, '`([^`]+)`'))) { if (-not $required.Contains($m.Groups[1].Value)) { $required.Add($m.Groups[1].Value) } }
        foreach ($m in ([regex]::Matches($b, '\b([A-Z]{2,}(?: [A-Z]{2,})+)\b'))) { if (-not $required.Contains($m.Groups[1].Value)) { $required.Add($m.Groups[1].Value) } }
        if ($b -notmatch '^`') { $lead = ($b -split ':')[0].Trim(); if ($lead -and $lead.Length -lt 40 -and -not $required.Contains($lead)) { $required.Add($lead) } }
    }
    # derive the two predicate phrases from SS5.2 itself
    $secText = ($sec -join ' ')
    $coveragePhrase = $null
    if ($secText -match '(coverage hole)') { $coveragePhrase = $Matches[1] }
    $negPhrase = $null
    foreach ($b in $bullets) { if ($b -match '\*\*(no code)[^*]*\*\*') { $negPhrase = $Matches[1] } }
    $forbidPhrase = $null
    if ($secText -match 'calling it (one line)') { $forbidPhrase = $Matches[1] }

    $d2Text  = ReadText $d2[0].FullName
    $d2Lines = $d2Text -split "`n"
    $problems = @()
    if ($bullets.Count -lt 3) { $problems += ('spec SS5.2 Correct-form derivation yielded ' + $bullets.Count + ' bullet(s), expected 3 -- the spec moved or the parser is stale') }
    if ($required.Count -eq 0) { $problems += 'ZERO claim tokens derived from spec SS5.2' }
    foreach ($t in $required) {
        $probe = [regex]::Escape($t) -replace '\\ ', '\s*'
        if ($d2Text -notmatch $probe) { $problems += ('claim token derived from spec SS5.2 is ABSENT from the dispatch: "' + $t + '"') }
    }
    if (-not $coveragePhrase) { $problems += 'could not derive the coverage-hole phrase from spec SS5.2' }
    elseif ($d2Text -notmatch [regex]::Escape($coveragePhrase)) { $problems += ('the "' + $coveragePhrase + '" claim is ABSENT from the dispatch') }
    if (-not $negPhrase) { $problems += 'could not derive the negation phrase from spec SS5.2' }
    elseif ($d2Text -notmatch [regex]::Escape($negPhrase)) { $problems += ('the "' + $negPhrase + '" negation about transcript_sha256 is ABSENT from the dispatch') }
    if (-not $forbidPhrase) { $problems += 'could not derive the forbidden phrase from spec SS5.2' }
    else {
        $fs = -1; $fe = $d2Lines.Length
        for ($i = 0; $i -lt $d2Lines.Length; $i++) {
            if ($d2Lines[$i] -match '^##\s+FORBIDDEN\s*$') { $fs = $i }
            elseif ($fs -ge 0 -and $i -gt $fs -and $d2Lines[$i] -match '^##\s') { $fe = $i; break }
        }
        $probe = [regex]::Escape($forbidPhrase) -replace '\\ ', '[\s\-]'
        for ($i = 0; $i -lt $d2Lines.Length; $i++) {
            if ($d2Lines[$i] -match $probe) {
                $inForbidden = ($fs -ge 0 -and $i -gt $fs -and $i -lt $fe)
                $negated = ($d2Lines[$i] -match '(?i)\bNOT\b|\bnever\b|forbidden|refuted|must not')
                if (-not ($inForbidden -or $negated)) { $problems += ('the refuted "' + $forbidPhrase + '" characterization is used affirmatively at line ' + ($i + 1) + ': ' + $d2Lines[$i].Trim()) }
            }
        }
    }
    [void](Check 'G4' ("the NB-2 dispatch carries the corrected characterization, derived from spec SS5.2 (" + $required.Count + " tokens from " + $bullets.Count + " bullets)") ($problems.Count -eq 0) ($problems -join "`n"))
    Reach ("claim tokens, the coverage-hole phrase, the negation phrase and the refuted phrase are all EXTRACTED from spec SS5.2 at run time. Only the negation vocabulary that decides affirmative-vs-refusing use is transcribed. Presence of a token is not proof the dispatch uses it correctly -- no check here would notice a well-formed but wrong branch specification.")
}

# =========================================================================================
# G5 -- no dispatch claims a write surface wider than its authority grants.
# =========================================================================================
if (-not (Test-Path -LiteralPath $am417Path)) {
    [void](Check 'G5' 'no dispatch claims a write surface wider than its authority grants' $false 'the evidence-plane program amendment is not found; the permitted set cannot be derived')
} else {
    $a417 = ReadText $am417Path
    $permitted = @()
    $appendOnly = @()
    if ($a417 -match '(?s)PERMITTED:(.*?)FORBIDDEN') {
        $seg = $Matches[1]
        foreach ($m in ([regex]::Matches($seg, '[A-Za-z0-9_.\-]+(?:/[A-Za-z0-9_.\-]+)*/(?:\*\*)?'))) {
            $p = $m.Value -replace '\*\*$', ''
            if ($permitted -notcontains $p) { $permitted += $p }
        }
        if ($seg -match '(?s)append-only(.*)$') {
            foreach ($m in ([regex]::Matches($Matches[1], '\.mission/[A-Za-z0-9_.\-]+/'))) {
                if ($appendOnly -notcontains $m.Value) { $appendOnly += $m.Value }
            }
        }
    }
    $problems = @()
    $tokTotal = 0; $tokChecked = 0; $tokPlaceholder = 0
    if ($permitted.Count -eq 0) { $problems += 'ZERO permitted prefixes derived from SS C of the evidence-plane program amendment -- derivation found nothing' }
    foreach ($f in $dispatchFiles) {
        $lines = (ReadText $f.FullName) -split "`n"
        $ws    = Get-MdSection $lines 'WRITE SURFACE'
        $auth  = (Get-MdSection $lines 'AUTHORITY') -join "`n"
        $needsOwn = ($auth -match '(?m)^NEEDS ITS OWN AMENDMENT:\s*YES\s*$')
        $covers = ''
        if ($auth -match '(?m)^AMENDMENT COVERS:\s*(.+?)\s*$') { $covers = $Matches[1] }
        # EVERY line in the section, not only bullets: a path named in prose is still a claim.
        $declaredPaths = @()
        foreach ($l in $ws) { foreach ($t in (Get-PathTokens $l)) { if ($declaredPaths -notcontains $t) { $declaredPaths += $t } } }
        foreach ($p in $declaredPaths) {
            $tokTotal++
            # PLACEHOLDER RULE, NAMED: a token containing an angle-bracketed segment stands for a
            # file the dispatch cannot name yet. It is NOT skipped -- it is range-checked on the
            # literal prefix before the '<', and counted as placeholder-classified.
            $isPlaceholder = ($p -match '<')
            $subject = $p
            if ($isPlaceholder) { $tokPlaceholder++; $subject = ($p -split '<')[0] }
            if ($isPlaceholder -and -not $subject) {
                $problems += ($f.Name + ' :: placeholder token "' + $p + '" has no literal prefix and cannot be range-checked')
                continue
            }
            $tokChecked++
            $bare = ($subject -replace '\*\*$', '')
            $okPerm = $false
            foreach ($pre in $permitted) { if ($bare.StartsWith($pre)) { $okPerm = $true; break } }
            if ($okPerm) { continue }
            $okCover = $false
            if ($needsOwn -and $covers) {
                foreach ($c in ($covers -split ',')) {
                    $cb = ($c.Trim() -replace '\*\*$', '')
                    if ($cb -and $bare.StartsWith($cb)) { $okCover = $true; break }
                }
            }
            if (-not $okCover) { $problems += ($f.Name + ' :: WRITE SURFACE path "' + $p + '" is outside SS C of the evidence-plane program amendment and is not covered by AMENDMENT COVERS') }
        }
    }
    [void](Check 'G5' 'no dispatch claims a write surface wider than its authority grants' ($problems.Count -eq 0) ($problems -join "`n"))
    Reach ("tokens found " + $tokTotal + " / range-checked " + $tokChecked + " / placeholder-classified " + $tokPlaceholder + " (checked on their literal prefix). Permitted prefixes derived from SS C of the evidence-plane program amendment: " + ($permitted -join ', ') + ". The APPEND-ONLY qualifier that amendment attaches to " + $(if ($appendOnly.Count) { ($appendOnly -join ' and ') } else { 'its .mission/ entries' }) + " is NOT enforced by this check -- prefix membership is all it decides.")
}

# =========================================================================================
# G6 -- sealed anchors unmoved.
# =========================================================================================
if (-not $am421Ok) {
    Skip 'G6' 'sealed anchors re-derive at their recorded prefixes' 'the dispatch-set amendment is not on disk'
} else {
    $problems = @()
    if ($anchors.Count -eq 0) { $problems += 'ZERO resolvable anchors derived from SS A of the dispatch-set amendment' }
    foreach ($a in $anchors) {
        $p = Join-Path $repoRootPath ($a.Rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $p)) { $problems += ('ABSENT: ' + $a.Rel); continue }
        $actualLen = (Get-Item -LiteralPath $p).Length
        $actualPfx = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower().Substring(0, 8)
        if ($actualPfx -ne $a.Prefix) { $problems += ('HASH MOVED: ' + $a.Rel + ' recorded ' + $a.Prefix + ', derived ' + $actualPfx) }
        if ($actualLen -ne $a.Length) { $problems += ('LENGTH MOVED: ' + $a.Rel + ' recorded ' + $a.Length + ', derived ' + $actualLen) }
    }
    [void](Check 'G6' ("sealed anchors re-derive at their recorded prefixes (" + $anchors.Count + " checked)") ($problems.Count -eq 0) ($problems -join "`n"))
    Reach ($anchors.Count.ToString() + " anchor row(s) checked; " + $anchorAbbrev + " row(s) in SS A of the dispatch-set amendment carry an abbreviated path containing '...' and are NOT checked. An abbreviated anchor is unresolvable by construction; it is counted and named here rather than counted as covered.")
}

# =========================================================================================
# G9 -- a dispatch that writes a sealed anchor must ENUMERATE it in AUTHORITY.
#       Generic by construction: the sealed set is derived, not a list of known offenders.
# =========================================================================================
if (-not $am421Ok) {
    Skip 'G9' 'every sealed anchor in a write surface is enumerated in that dispatch AUTHORITY' 'the dispatch-set amendment is not on disk'
} else {
    $anchorByRel = @{}
    foreach ($a in $anchors) { $anchorByRel[$a.Rel] = $a }
    $problems = @()
    $globs = 0
    if ($anchors.Count -eq 0) { $problems += 'ZERO sealed anchors derived from SS A of the dispatch-set amendment' }
    foreach ($f in $dispatchFiles) {
        $lines = (ReadText $f.FullName) -split "`n"
        $ws    = Get-MdSection $lines 'WRITE SURFACE'
        $auth  = (Get-MdSection $lines 'AUTHORITY') -join "`n"
        $sealedDeclared = @()
        foreach ($m in ([regex]::Matches($auth, '(?m)^SEALED FILE:\s*(\S+)\s+([0-9a-f]{8})\s*$'))) { $sealedDeclared += $m.Groups[1].Value }
        $movesYes = ($auth -match '(?m)^MOVES A SEALED HASH:\s*YES\s*$')
        $hits = @()
        foreach ($l in $ws) {
            foreach ($t in (Get-PathTokens $l)) {
                if ($t -match '\*\*$') { $globs++; continue }
                if ($anchorByRel.ContainsKey($t) -and $hits -notcontains $t) { $hits += $t }
            }
        }
        foreach ($h in $hits) {
            if ($sealedDeclared -notcontains $h) {
                $problems += ($f.Name + ' :: WRITE SURFACE declares sealed anchor "' + $h + '" (' + $anchorByRel[$h].Prefix + ') but AUTHORITY does not enumerate it as a SEALED FILE')
            }
        }
        if ($hits.Count -gt 0 -and -not $movesYes) {
            $problems += ($f.Name + ' :: writes ' + $hits.Count + ' sealed anchor(s) but declares MOVES A SEALED HASH: NO')
        }
    }
    [void](Check 'G9' 'every sealed anchor in a write surface is enumerated in that dispatch AUTHORITY' ($problems.Count -eq 0) ($problems -join "`n"))
    Reach ("compares EXACT declared paths against the " + $anchors.Count + " sealed anchors derived from SS A of the dispatch-set amendment. " + $globs + " glob token(s) ending in '**' were not expanded: a glob may cover a sealed anchor without the dispatch intending to modify it, and expanding it would manufacture findings this check cannot substantiate.")
}

# =========================================================================================
# G7 -- encoding.
# =========================================================================================
$problems = @()
foreach ($f in $dispatchFiles) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $problems += ($f.Name + ' :: has a UTF-8 BOM') }
    if (@($b | Where-Object { $_ -eq 13 }).Count -gt 0) { $problems += ($f.Name + ' :: contains CR (not LF-only)') }
    try { $enc = New-Object System.Text.UTF8Encoding($false, $true); [void]$enc.GetString($b) }
    catch { $problems += ($f.Name + ' :: does not decode as strict UTF-8') }
    $txt = ReadText $f.FullName
    foreach ($moj in @([char]0x00E2 + [char]0x20AC, [char]0x00C2 + [char]0x00A7, [char]0x00C3 + [char]0x00A9)) {
        if ($txt.Contains($moj)) { $problems += ($f.Name + ' :: carries a double-encoding artefact') }
    }
}
if ($dispatchFiles.Count -eq 0) { $problems += 'ZERO dispatch files found' }
[void](Check 'G7a' ("every dispatch is strict UTF-8, BOM-less, LF-only, no double-encoding (" + $dispatchFiles.Count + " files)") ($problems.Count -eq 0) ($problems -join "`n"))
Reach 'the double-encoding probe is three TRANSCRIBED sentinel sequences, not a derived population; a fourth mojibake shape would pass unnoticed.'

$selfBytes = [System.IO.File]::ReadAllBytes($selfPath)
$selfProblems = @()
if ($selfBytes.Length -ge 3 -and $selfBytes[0] -eq 0xEF -and $selfBytes[1] -eq 0xBB -and $selfBytes[2] -eq 0xBF) { $selfProblems += 'this instrument has a UTF-8 BOM' }
if (@($selfBytes | Where-Object { $_ -eq 13 }).Count -gt 0) { $selfProblems += 'this instrument contains CR (not LF-only)' }
$nonAscii = @($selfBytes | Where-Object { $_ -gt 127 }).Count
if ($nonAscii -gt 0) { $selfProblems += ('this instrument carries ' + $nonAscii + ' non-ASCII byte(s) -- instrument law (a)') }
[void](Check 'G7b' 'this instrument is BOM-less, LF-only, pure ASCII (instrument law (a))' ($selfProblems.Count -eq 0) ($selfProblems -join "`n"))

# =========================================================================================
# G8 -- instrument integrity, the mechanically checkable part.
# =========================================================================================
$selfText = ReadText $selfPath
$integrity = @()
if ($selfText -notmatch '\$PSScriptRoot') { $integrity += 'this file does not anchor to $PSScriptRoot' }
$cwdCall = 'Get' + '-Location'
if ($selfText -match ('(?m)^\s*[^#\r\n]*' + $cwdCall)) { $integrity += ('this file calls ' + $cwdCall + ' -- cwd dependence') }
$nativeProbe = 'git' + ' rev-parse'
if ($selfText -match ('(?m)^\s*[^#\r\n]*&\s*' + $nativeProbe)) { $integrity += 'this file invokes a native executable -- instrument law (c)' }
[void](Check 'G8' 'this instrument anchors to its own tree, has no cwd dependence, invokes nothing native' ($integrity.Count -eq 0) ($integrity -join "`n"))
Reach 'covers the properties decidable from this file bytes: tree anchoring, absence of a cwd call, absence of a native invocation. The probe tokens are transcribed. The remaining law-5 properties (no green line on a failing run, derived summary counts) are structural and are not self-checked.'

# --- summary ------------------------------------------------------------------------------
Write-Host ''
Write-Host ("checks emitted : " + $script:Ran + "   (emitted check lines, NOT the 8 SS F criteria of the dispatch-set amendment -- G7 splits into G7a/G7b and G9 was added by the B4 cure)")
Write-Host ("failures       : " + $script:Failures)
Write-Host ("skipped        : " + $script:Skips)
if ($script:Failures -gt 0) {
    Write-Host ("SUITE FAILED -- " + $script:Failures + " failure(s)")
    exit $script:Failures
}
if ($script:Skips -gt 0) {
    Write-Host ("SUITE INCOMPLETE, NOT GREEN -- " + $script:Skips + " check(s) skipped")
    exit 3
}
Write-Host 'ALL CHECKS PASSED'
exit 0
