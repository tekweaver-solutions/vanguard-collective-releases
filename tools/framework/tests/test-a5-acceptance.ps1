# test-a5-acceptance.ps1 -- acceptance instrument for Arc 1.
#
# Decides the Arc 1 amendment's SS G criteria G1-G10 from disk. Content-anchored: it derives its populations
# from named files whose content is immutable once placed, and never from a directory population
# that a ceremony perturbs. A2's instrument derived a figure from the population of
# .mission/amendments/ -- a population its own ceremony moved -- so it reads exit 3 forever after
# its seal. This one takes A3's and A4's route.
#
# WHAT DERIVES AND WHAT TRANSCRIBES, PER CHECK. There is no universal claim here that every
# population is derived, because that claim was false in A4's instrument and its validator
# refuted it (finding B1). Stated per check instead:
#   G1  DERIVES the dispatch inventory from the A4 amendment SS B and the Arc 1 amendment SS H.
#   G2  DERIVES the block list from the A4 amendment SS C.
#   G3  DERIVES cited amendment ids from each dispatch; TRANSCRIBES the four AUTHORITY field
#       names (NEEDS ITS OWN AMENDMENT, AMENDMENT COVERS, MOVES A SEALED HASH, SEALED FILE) from
#       A4's instrument, which is where that form is defined. They are line-anchored there and
#       are line-anchored here, deliberately: an earlier revision of the Arc 1 dispatches carried
#       the same verdicts bolded and embedded in prose, A4's matcher missed them, and the
#       enumeration behind them turned out to be short by one sealed anchor. A form that only a
#       human can read is a form a checker cannot enforce.
#   G4-G7 TRANSCRIBE their claim tokens from the Arc 1 amendment SS C/SS E. These can go stale if that amendment's
#       wording is ever superseded; AM files are immutable once placed, so they cannot go stale
#       against THIS amendment.
#   G8  DERIVES the permitted set from the program amendment SS C and the declared paths from each dispatch.
#   G9  DERIVES the anchor set from the A4 amendment SS A, a ledger line, and the Arc 1 amendment SS A.
#   G10 DERIVES nothing; it measures bytes, including its own.
#
# PRE-PLACEMENT CONTRACT. The arc's amendment is placed at the Arc 1 ceremony commit, which happens AFTER the
# build it authorizes. Every check that depends on it -- G1's inventory union and G3's citation
# resolution -- therefore SKIPS while it is absent, on A4's own precedent (A4 skips G1 and G2 when
# the A4 amendment is not on disk). The documented pre-placement result is EXIT 3 WITH TWO SKIPS. An earlier
# revision FAILED instead, which made this instrument unusable before its own ceremony.
#
# KNOWN LIMITATION, REGISTERED AS D12 AND NOT CURED HERE. G1 derives its declaring authority from
# a NAMED PAIR of amendments (A4's and Arc 1's). A later arc that authorizes further dispatches will
# break it exactly as Arc 1 broke A4's G1, whose second direction enumerates a directory and
# requires every member be named by a document that can never name them. The durable cure is to
# derive the union from ALL amendments that name dispatch files -- amendments are append-only and
# immutable, so scanning them only ever ADDS. That cure moves this file's hash and A4's
# (94b536cc); it needs its own amendment and belongs to a later arc, because a session that
# repairs the instrument judging it has put the pen on its own evidence.
#
# EXIT CONTRACT. 0 = clean (no failures, no skips). 3 = passed with skips. n = n failures.
# EXIT 3 IS NON-UNIQUE: it is also what three failures produce. This is disclosed rather than
# papered over with an offset nobody remembers at the moment it matters. Read the summary lines,
# which are derived from the result list, not typed.
#
# Nothing invokes this file -- no hook, no gate, no ceremony step. It decides only when a person
# runs it, and the dispatch set can drift between runs of it. It checks that dispatches are
# WELL-FORMED and that their claims resolve. It cannot decide whether a dispatch would produce a
# good build.

[CmdletBinding()]
param(
    [switch]$SelfTest,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------------------------
# Tree anchoring. $PSScriptRoot, never cwd (instrument law 5). This file lives at
# tools/framework/tests/, so the repository root is three levels up.
# ---------------------------------------------------------------------------------------------

$ScriptDirPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDirPath)) {
    Write-Host "FATAL: PSScriptRoot is empty. This instrument must be run as a file."
    exit 1
}
$SelfPath = Join-Path $ScriptDirPath 'test-a5-acceptance.ps1'
$DerivedRootPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDirPath))

if ($PSBoundParameters.ContainsKey('RepoRoot') -and -not $SelfTest) {
    Write-Host "FATAL: -RepoRoot may only be supplied together with -SelfTest."
    Write-Host "Pointing this instrument at a tree it did not come from is how a test validates a"
    Write-Host "foreign tree and prints green (instrument law 5). Refusing."
    exit 1
}

$RootPath = $DerivedRootPath
$IsForeignTree = $false
if ($SelfTest -and $PSBoundParameters.ContainsKey('RepoRoot')) {
    $RootPath = (Resolve-Path -LiteralPath $RepoRoot).Path
    $IsForeignTree = $true
}

# ---------------------------------------------------------------------------------------------
# Result plumbing. Counts are derived from this list, never typed.
# ---------------------------------------------------------------------------------------------

$Script:Results = New-Object System.Collections.ArrayList

function Add-Result {
    param([string]$Check, [string]$Status, [string]$Detail)
    $null = $Script:Results.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
    Write-Host ("[{0}] {1} -- {2}" -f $Status, $Check, $Detail)
}

function Write-Reach {
    param([string]$Text)
    Write-Host ("       reach: {0}" -f $Text)
}

function Read-TextOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Get-SectionText {
    param([string]$Text, [string]$StartPattern, [string]$EndPattern)
    $lines = $Text -split "`n"
    $out = New-Object System.Collections.ArrayList
    $inSection = $false
    foreach ($line in $lines) {
        if (-not $inSection) {
            if ($line -match $StartPattern) { $inSection = $true }
            continue
        }
        if ($line -match $EndPattern) { break }
        $null = $out.Add($line)
    }
    return ($out -join "`n")
}

function Test-FileBytes {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $cr = 0; $nonAscii = 0
    foreach ($b in $bytes) {
        if ($b -eq 13) { $cr++ }
        if ($b -gt 127) { $nonAscii++ }
    }
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)
    $strict = $true
    $mojibake = 0
    try {
        $enc = [System.Text.Encoding]::GetEncoding('utf-8', [System.Text.EncoderFallback]::ExceptionFallback, [System.Text.DecoderFallback]::ExceptionFallback)
        $s = $enc.GetString($bytes)
        foreach ($ch in $s.ToCharArray()) {
            $code = [int]$ch
            if ($code -eq 0x00C3 -or $code -eq 0x00E2 -or $code -eq 0x00C2) { $mojibake++ }
        }
    } catch {
        $strict = $false
    }
    return [pscustomobject]@{
        Bytes = $bytes.Length; Cr = $cr; NonAscii = $nonAscii; Bom = $bom
        StrictUtf8 = $strict; Mojibake = $mojibake
    }
}

# ---------------------------------------------------------------------------------------------
# Source artifacts.
# ---------------------------------------------------------------------------------------------

$AmendDirPath    = Join-Path $RootPath '.mission/amendments'
$LedgerPath      = Join-Path $RootPath '.mission/ledger/entries.jsonl'
$DispatchDirPath = Join-Path $RootPath 'docs/framework/build-dispatches'
$Am417Path       = Join-Path $AmendDirPath 'AM-417-framework-evidence-plane-artifact-program.yaml'
$Am421Path       = Join-Path $AmendDirPath 'AM-421-a4-build-dispatches-hook-installation.yaml'

$Am422Path = $null
if (Test-Path -LiteralPath $AmendDirPath -PathType Container) {
    $cand = @(Get-ChildItem -LiteralPath $AmendDirPath -Filter 'AM-422-*.yaml' -File -ErrorAction SilentlyContinue)
    if ($cand.Count -eq 1) { $Am422Path = $cand[0].FullName }
    elseif ($cand.Count -gt 1) { $Am422Path = 'AMBIGUOUS' }
}

$Am417Text = Read-TextOrNull $Am417Path
$Am421Text = Read-TextOrNull $Am421Path
$Am422Text = $null
if ($Am422Path -and $Am422Path -ne 'AMBIGUOUS') { $Am422Text = Read-TextOrNull $Am422Path }

Write-Host "=============================================================================="
Write-Host "A5 ACCEPTANCE -- Arc 1: v2.3 admission, D9/D10/D8/D11 dispatch set"
Write-Host "=============================================================================="
if ($IsForeignTree) {
    Write-Host ""
    Write-Host "  ****  SELF-TEST MODE -- FOREIGN TREE  ****"
    Write-Host "  NO ACCEPTANCE VERDICT IS EMITTED IN THIS MODE. Results below describe a"
    Write-Host "  fixture, not the repository this instrument ships in."
    Write-Host ""
}
Write-Host "Root: $RootPath"
Write-Host ""

# ---------------------------------------------------------------------------------------------
# G1 -- dispatch-set completeness, both directions. DERIVED.
# ---------------------------------------------------------------------------------------------

$DeclaredDispatches = New-Object System.Collections.ArrayList
$g1Skip = $false
$g1SkipReason = ''

if ($null -eq $Am421Text) {
    $g1Skip = $true; $g1SkipReason = 'A4 amendment not readable at ' + $Am421Path
} else {
    foreach ($line in ($Am421Text -split "`n")) {
        if ($line -match '^\s*D\d+\s+(build-dispatch-[a-z0-9\-]+\.md)\s*$') {
            if (-not $DeclaredDispatches.Contains($Matches[1])) { $null = $DeclaredDispatches.Add($Matches[1]) }
        }
    }
}
$fromAm421 = $DeclaredDispatches.Count

if ($Am422Path -eq 'AMBIGUOUS') {
    $g1Skip = $true; $g1SkipReason = 'more than one AM-422-*.yaml present'
} elseif ($null -eq $Am422Text) {
    $g1Skip = $true
    $g1SkipReason = 'the Arc 1 amendment is not placed yet (the documented pre-placement result)'
} else {
    foreach ($m in [regex]::Matches($Am422Text, 'build-dispatches/(build-dispatch-[a-z0-9\-]+\.md)')) {
        $n = $m.Groups[1].Value
        if (-not $DeclaredDispatches.Contains($n)) { $null = $DeclaredDispatches.Add($n) }
    }
}
$fromAm422 = $DeclaredDispatches.Count - $fromAm421

if ($g1Skip) {
    Add-Result 'G1 dispatch-set completeness' 'SKIP' $g1SkipReason
} elseif ($DeclaredDispatches.Count -eq 0) {
    Add-Result 'G1 dispatch-set completeness' 'FAIL' 'ZERO dispatches derived from the amendments -- the extractor found nothing, which is a failure and not a quiet pass'
} else {
    $actual = @()
    if (Test-Path -LiteralPath $DispatchDirPath -PathType Container) {
        $actual = @(Get-ChildItem -LiteralPath $DispatchDirPath -Filter 'build-dispatch-*.md' -File | ForEach-Object { $_.Name })
    }
    $missing = @($DeclaredDispatches | Where-Object { $actual -notcontains $_ })
    $extra   = @($actual | Where-Object { -not $DeclaredDispatches.Contains($_) })
    if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
        Add-Result 'G1 dispatch-set completeness' 'PASS' ("{0} declared, {0} on disk, both directions" -f $DeclaredDispatches.Count)
    } else {
        foreach ($m in $missing) { Add-Result 'G1 dispatch-set completeness' 'FAIL' ("DECLARED BUT ABSENT: {0}" -f $m) }
        foreach ($e in $extra)   { Add-Result 'G1 dispatch-set completeness' 'FAIL' ("PRESENT BUT UNDECLARED: {0}" -f $e) }
    }
    Write-Reach ("{0} names derived from the A4 amendment SS B, {1} from the Arc 1 amendment SS H; compared against {2} files on disk" -f $fromAm421, $fromAm422, $actual.Count)
}

$NewDispatchMap = @{
    'D9'  = 'build-dispatch-evidence-residue-disposition.md'
    'D10' = 'build-dispatch-dispatch-vs-turn-lifecycle.md'
    'D8'  = 'build-dispatch-failure-and-denial-capture.md'
    'D11' = 'build-dispatch-stream-payload-identity.md'
}

# ---------------------------------------------------------------------------------------------
# G2 -- every new dispatch carries every block the A4 amendment SS C lists. Block list DERIVED.
# ---------------------------------------------------------------------------------------------

$Blocks = New-Object System.Collections.ArrayList
if ($null -ne $Am421Text) {
    $ssC = Get-SectionText -Text $Am421Text -StartPattern 'SS C\. DISPATCH FORM' -EndPattern 'SS D\.'
    foreach ($line in ($ssC -split "`n")) {
        if ($line -match '^\s{4}([A-Z0-9][A-Z0-9 \-]*[A-Z0-9])\s+--\s') {
            $b = $Matches[1].Trim()
            if (-not $Blocks.Contains($b)) { $null = $Blocks.Add($b) }
        }
    }
}

if ($Blocks.Count -eq 0) {
    Add-Result 'G2 dispatch blocks' 'FAIL' 'ZERO blocks derived from the A4 amendment SS C -- extractor found nothing'
} else {
    $g2Fail = 0
    foreach ($key in ($NewDispatchMap.Keys | Sort-Object)) {
        $p = Join-Path $DispatchDirPath $NewDispatchMap[$key]
        $t = Read-TextOrNull $p
        if ($null -eq $t) {
            Add-Result 'G2 dispatch blocks' 'FAIL' ("{0}: file absent at {1}" -f $key, $NewDispatchMap[$key]); $g2Fail++
            continue
        }
        foreach ($b in $Blocks) {
            if ($t -notmatch ('(?m)^##\s+' + [regex]::Escape($b) + '\s*$')) {
                Add-Result 'G2 dispatch blocks' 'FAIL' ("{0} ({1}) is MISSING block: {2}" -f $key, $NewDispatchMap[$key], $b); $g2Fail++
            }
        }
    }
    if ($g2Fail -eq 0) {
        Add-Result 'G2 dispatch blocks' 'PASS' ("{0} blocks derived from the A4 amendment SS C, present in all {1} new dispatches" -f $Blocks.Count, $NewDispatchMap.Count)
    }
    Write-Reach ("checks the {0} dispatches THIS arc authored, not the D1-D7 set (A4's G2 decided those); blocks derived: {1}" -f $NewDispatchMap.Count, ($Blocks -join ', '))
}

# ---------------------------------------------------------------------------------------------
# G3 -- per member: authority resolves, and both verdicts are present.
# ---------------------------------------------------------------------------------------------

if ($null -eq $Am422Text) {
    Add-Result 'G3 authority resolution' 'SKIP' 'the Arc 1 amendment is not placed yet, so every dispatch citation of it is unresolvable by construction (A4 precedent: a check whose authorizing amendment is absent SKIPS rather than fails)'
} else {
    $knownAmendments = @()
    if (Test-Path -LiteralPath $AmendDirPath -PathType Container) {
        $knownAmendments = @(Get-ChildItem -LiteralPath $AmendDirPath -Filter 'AM-*.yaml' -File | ForEach-Object {
            if ($_.Name -match '^(AM-\d{3})') { $Matches[1] } })
    }

    $g3Fail = 0
    $g3Cited = 0
    foreach ($key in ($NewDispatchMap.Keys | Sort-Object)) {
        $p = Join-Path $DispatchDirPath $NewDispatchMap[$key]
        $t = Read-TextOrNull $p
        if ($null -eq $t) { Add-Result 'G3 authority resolution' 'FAIL' ("{0}: file absent" -f $key); $g3Fail++; continue }
        $auth = Get-SectionText -Text $t -StartPattern '^##\s+AUTHORITY\s*$' -EndPattern '^##\s'
        if ($auth -notmatch '(?m)^NEEDS ITS OWN AMENDMENT:\s*(YES|NO)\s*$') {
            Add-Result 'G3 authority resolution' 'FAIL' ("{0}: no bare 'NEEDS ITS OWN AMENDMENT: YES|NO' line in AUTHORITY" -f $key); $g3Fail++
        } elseif ($Matches[1] -eq 'YES' -and $auth -notmatch '(?m)^AMENDMENT COVERS:\s*\S') {
            Add-Result 'G3 authority resolution' 'FAIL' ("{0}: declares NEEDS ITS OWN AMENDMENT: YES but carries no AMENDMENT COVERS line" -f $key); $g3Fail++
        }
        if ($auth -notmatch '(?m)^MOVES A SEALED HASH:\s*(YES|NO)\s*$') {
            Add-Result 'G3 authority resolution' 'FAIL' ("{0}: no bare 'MOVES A SEALED HASH: YES|NO' line in AUTHORITY" -f $key); $g3Fail++
        } elseif ($Matches[1] -eq 'YES' -and $auth -notmatch '(?m)^SEALED FILE:\s*\S+\s+[0-9a-f]{8}\s*$') {
            Add-Result 'G3 authority resolution' 'FAIL' ("{0}: declares MOVES A SEALED HASH: YES but carries no 'SEALED FILE: <path> <8-hex>' line" -f $key); $g3Fail++
        }
        $ids = @([regex]::Matches($t, 'AM-\d{3}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
        $g3Cited += $ids.Count
        foreach ($id in $ids) {
            if ($knownAmendments -notcontains $id) {
                Add-Result 'G3 authority resolution' 'FAIL' ("{0}: cites {1}, which has no file in .mission/amendments/" -f $key, $id); $g3Fail++
            }
        }
    }
    if ($g3Fail -eq 0) {
        Add-Result 'G3 authority resolution' 'PASS' ("{0} dispatches, all four AUTHORITY fields well-formed, {1} cited amendment ids all resolve on disk" -f $NewDispatchMap.Count, $g3Cited)
    }
    Write-Reach ("amendment ids extracted by pattern AM-nnn and range-checked against {0} files on disk; the four AUTHORITY field names are TRANSCRIBED from A4's instrument, which is where the form is defined" -f $knownAmendments.Count)
}

# ---------------------------------------------------------------------------------------------
# G4-G7 -- per-dispatch claim content. Tokens TRANSCRIBED from the Arc 1 amendment SS C / SS E.
# ---------------------------------------------------------------------------------------------

$ClaimChecks = @(
    @{ Id = 'G4'; Key = 'D9';  Name = 'D9 four-mechanism count and NEW-3 constraint';
       Tokens = @('F-4', 'F-5', 'NEW-1', 'NEW-2', 'NEW-3', 'blanket ignore') },
    @{ Id = 'G5'; Key = 'D8';  Name = 'D8 candidate narrowing and driven transcript question';
       Tokens = @('cannot count the calls', 'raw-stdin probe', 'D10 MUST LAND FIRST', 'law 10') },
    @{ Id = 'G6'; Key = 'D10'; Name = 'D10 TAMPERED-preservation constraint';
       Tokens = @('grew by append', 'bytes changed', 'TAMPERED') },
    @{ Id = 'G7'; Key = 'D11'; Name = 'D11 collision per member and N-e falsification';
       Tokens = @('key collision', 'E6', 'streams/000013.json', 'N-e') }
)

foreach ($c in $ClaimChecks) {
    $p = Join-Path $DispatchDirPath $NewDispatchMap[$c.Key]
    $t = Read-TextOrNull $p
    if ($null -eq $t) {
        Add-Result ("{0} {1}" -f $c.Id, $c.Name) 'FAIL' ("{0} file absent" -f $c.Key)
        continue
    }
    $missingTokens = @($c.Tokens | Where-Object { $t -notmatch [regex]::Escape($_) })
    if ($missingTokens.Count -eq 0) {
        Add-Result ("{0} {1}" -f $c.Id, $c.Name) 'PASS' ("all {0} claim tokens present" -f $c.Tokens.Count)
    } else {
        foreach ($mt in $missingTokens) {
            Add-Result ("{0} {1}" -f $c.Id, $c.Name) 'FAIL' ("MISSING claim token: '{0}'" -f $mt)
        }
    }
    Write-Reach ("{0} tokens, TRANSCRIBED from the Arc 1 amendment; a reworded dispatch that still says the right thing would fail here, which is the cost of transcription and is why it is declared" -f $c.Tokens.Count)
}

$d11Text = Read-TextOrNull (Join-Path $DispatchDirPath $NewDispatchMap['D11'])
if ($null -ne $d11Text) {
    if ($d11Text -imatch 'falsif') {
        Add-Result 'G7 N-e falsification stated' 'PASS' "D11 states the falsification"
    } else {
        Add-Result 'G7 N-e falsification stated' 'FAIL' "D11 does not state that A2's N-e resolution is falsified"
    }
}

# ---------------------------------------------------------------------------------------------
# G8 -- no dispatch claims a write surface wider than its authority grants.
# ---------------------------------------------------------------------------------------------

$Permitted = New-Object System.Collections.ArrayList
if ($null -ne $Am417Text) {
    foreach ($line in ($Am417Text -split "`n")) {
        if ($line -match 'PERMITTED:' -or $line -match 'append-only \.mission/ledger/') {
            foreach ($m in [regex]::Matches($line, '[A-Za-z0-9._\-]+(?:/[A-Za-z0-9._\-]+)*/\*\*')) {
                if (-not $Permitted.Contains($m.Value)) { $null = $Permitted.Add($m.Value) }
            }
            foreach ($m in [regex]::Matches($line, '\.mission/(?:ledger|amendments)/')) {
                if (-not $Permitted.Contains($m.Value)) { $null = $Permitted.Add($m.Value) }
            }
        }
    }
}

if ($Permitted.Count -eq 0) {
    Add-Result 'G8 write surface range' 'FAIL' 'ZERO permitted prefixes derived from the program amendment SS C -- extractor found nothing'
} else {
    $g8Fail = 0; $g8Tokens = 0; $g8InRange = 0; $g8Covered = 0
    foreach ($key in ($NewDispatchMap.Keys | Sort-Object)) {
        $p = Join-Path $DispatchDirPath $NewDispatchMap[$key]
        $t = Read-TextOrNull $p
        if ($null -eq $t) { continue }
        $ws   = Get-SectionText -Text $t -StartPattern '^##\s+WRITE SURFACE\s*$' -EndPattern '^##\s'
        $auth = Get-SectionText -Text $t -StartPattern '^##\s+AUTHORITY\s*$'     -EndPattern '^##\s'
        $needsOwn = ($auth -match '(?m)^NEEDS ITS OWN AMENDMENT:\s*YES\s*$')
        $covers = ''
        if ($auth -match '(?m)^AMENDMENT COVERS:\s*(.+?)\s*$') { $covers = $Matches[1] }
        foreach ($m in [regex]::Matches($ws, '`([^`]+)`')) {
            $tok = $m.Groups[1].Value.Trim()
            if ($tok -notmatch '[/.]') { continue }
            $g8Tokens++
            $inRange = $false
            foreach ($pref in $Permitted) {
                $base = $pref -replace '\*\*$', ''
                if ($base.Length -gt 0 -and $tok.StartsWith($base)) { $inRange = $true; break }
            }
            if ($inRange) { $g8InRange++; continue }
            # A blanket NEEDS ITS OWN AMENDMENT: YES does NOT cover a path. The COVERS line must
            # NAME it. Accepting the blanket was this check's reach-narrower-than-its-name defect:
            # it would have passed a dispatch declaring any out-of-range path at all.
            $okCover = $false
            if ($needsOwn -and $covers) {
                foreach ($c in ($covers -split ',')) {
                    $cb = ($c.Trim() -replace '\*\*$', '')
                    if ($cb.Length -gt 0 -and $tok.StartsWith($cb)) { $okCover = $true; break }
                }
            }
            if ($okCover) { $g8Covered++; continue }
            Add-Result 'G8 write surface range' 'FAIL' ("{0}: declares '{1}', outside the program amendment SS C permitted set, and AMENDMENT COVERS does not NAME it" -f $key, $tok)
            $g8Fail++
        }
    }
    if ($g8Fail -eq 0) {
        Add-Result 'G8 write surface range' 'PASS' ("{0} path tokens checked; {1} inside the program amendment SS C, {2} covered by a needs-its-own-amendment declaration" -f $g8Tokens, $g8InRange, $g8Covered)
    }
    Write-Reach ("permitted prefixes derived from the program amendment: {0}" -f ($Permitted -join ', '))
    Write-Reach "tokens are extracted from EVERY backticked span on EVERY line of WRITE SURFACE, not just the first per line (the A4 B2 defect); spans with no '/' or '.' are treated as non-paths and are NOT counted"
    Write-Reach "an out-of-range token is covered only when AMENDMENT COVERS NAMES IT (prefix match against a comma-separated entry). A blanket 'NEEDS ITS OWN AMENDMENT: YES' covers NOTHING -- accepting it was this check's own reach defect, cured by exception to the termination rule because a check whose reach is narrower than its name is the law-4 class this program blocks on everywhere else."
}

# ---------------------------------------------------------------------------------------------
# G9 -- anchors. Set DERIVED from the A4 amendment SS A, the ledger, and the Arc 1 amendment SS A.
# ---------------------------------------------------------------------------------------------

$Script:AnchorSeen = New-Object System.Collections.ArrayList
$Script:AnchorList = New-Object System.Collections.ArrayList

function Add-Anchor {
    param([string]$Prefix, [string]$Path, [string]$Source)
    if ($Script:AnchorSeen.Contains($Path)) { return }
    $null = $Script:AnchorSeen.Add($Path)
    $null = $Script:AnchorList.Add([pscustomobject]@{ Prefix = $Prefix; Path = $Path; Source = $Source })
}

if ($null -ne $Am421Text) {
    foreach ($line in ($Am421Text -split "`n")) {
        if ($line -match '^\s{4}([0-9a-f]{8})\s+(\d+)\s+(tools/framework/\S+)\s*$') {
            Add-Anchor $Matches[1] $Matches[3] 'A4 amendment SS A'
        }
    }
}
$ledgerText = Read-TextOrNull $LedgerPath
if ($null -ne $ledgerText) {
    foreach ($m in [regex]::Matches($ledgerText, '([0-9a-f]{8})\s+(\d+)\s+(tools/framework/tests/test-a4-acceptance\.ps1)')) {
        Add-Anchor $m.Groups[1].Value $m.Groups[3].Value 'ledger'
    }
}
$anchorsBeforeAm422 = $Script:AnchorList.Count
if ($null -ne $Am422Text) {
    $ssA = Get-SectionText -Text $Am422Text -StartPattern 'SS A\. GROUNDING' -EndPattern 'SS B\.'
    foreach ($line in ($ssA -split "`n")) {
        if ($line -match '^\s{4}([0-9a-f]{8})\s+(\S+)\s*$') {
            Add-Anchor $Matches[1] $Matches[2] 'Arc 1 amendment SS A'
        }
    }
}

if ($Script:AnchorList.Count -eq 0) {
    Add-Result 'G9 sealed anchors' 'FAIL' 'ZERO anchors derived -- extractor found nothing'
} else {
    $match = 0; $mismatch = 0; $unverifiable = 0
    foreach ($a in $Script:AnchorList) {
        $full = Join-Path $RootPath $a.Path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Add-Result 'G9 sealed anchors' 'FAIL' ("{0}: file absent" -f $a.Path); $unverifiable++
            continue
        }
        $h = $null
        try { $h = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLower() } catch { $h = $null }
        if ($null -eq $h) {
            Add-Result 'G9 sealed anchors' 'FAIL' ("{0}: UNVERIFIABLE -- hash could not be computed" -f $a.Path); $unverifiable++
        } elseif ($h.StartsWith($a.Prefix)) {
            $match++
        } else {
            Add-Result 'G9 sealed anchors' 'FAIL' ("{0}: MOVED -- recorded {1}, derived {2}" -f $a.Path, $a.Prefix, $h.Substring(0,8)); $mismatch++
        }
    }
    if ($mismatch -eq 0 -and $unverifiable -eq 0) {
        Add-Result 'G9 sealed anchors' 'PASS' ("{0} anchors derived, {0} re-derive at their recorded prefixes" -f $match)
    }
    Write-Reach ("{0} anchors from the A4 amendment SS A + the ledger, {1} added from the Arc 1 amendment SS A; {2} matched, {3} moved, {4} unverifiable" -f $anchorsBeforeAm422, ($Script:AnchorList.Count - $anchorsBeforeAm422), $match, $mismatch, $unverifiable)
    Write-Reach "run by an AGENT session the guard denies hashing tools/framework/**, so this instrument cannot run there at all; run from an OPERATOR terminal there is no guard and every row is a digest. Where a row is UNVERIFIABLE the basis degrades to porcelain-absence, which is STRICTLY WEAKER than a digest."
}

# ---------------------------------------------------------------------------------------------
# G10 -- encoding, and this instrument's own bytes.
# ---------------------------------------------------------------------------------------------

$encTargets = New-Object System.Collections.ArrayList
foreach ($key in ($NewDispatchMap.Keys | Sort-Object)) {
    $null = $encTargets.Add([pscustomobject]@{ Path = (Join-Path $DispatchDirPath $NewDispatchMap[$key]); Ascii = $true; Label = $NewDispatchMap[$key] })
}
$v23Path = Join-Path $RootPath 'docs/framework/vanguard-collective-local-modes-v2.3.md'
$null = $encTargets.Add([pscustomobject]@{ Path = $v23Path; Ascii = $false; Label = 'vanguard-collective-local-modes-v2.3.md' })
$null = $encTargets.Add([pscustomobject]@{ Path = $SelfPath; Ascii = $true; Label = 'test-a5-acceptance.ps1 (SELF)' })

$g10Fail = 0; $g10Checked = 0
foreach ($t in $encTargets) {
    if (-not (Test-Path -LiteralPath $t.Path -PathType Leaf)) {
        Add-Result 'G10 encoding' 'FAIL' ("{0}: absent" -f $t.Label); $g10Fail++; continue
    }
    $g10Checked++
    $r = Test-FileBytes -Path $t.Path
    $problems = New-Object System.Collections.ArrayList
    if (-not $r.StrictUtf8) { $null = $problems.Add('not strict UTF-8') }
    if ($r.Bom)             { $null = $problems.Add('has a BOM') }
    if ($r.Cr -gt 0)        { $null = $problems.Add(("{0} CR bytes (not LF-only)" -f $r.Cr)) }
    if ($r.Mojibake -gt 0)  { $null = $problems.Add(("{0} double-encoding sentinel codepoints" -f $r.Mojibake)) }
    if ($t.Ascii -and $r.NonAscii -gt 0) { $null = $problems.Add(("{0} non-ASCII bytes but ASCII is required" -f $r.NonAscii)) }
    if ($problems.Count -gt 0) {
        Add-Result 'G10 encoding' 'FAIL' ("{0}: {1}" -f $t.Label, ($problems -join '; ')); $g10Fail++
    }
}
if ($g10Fail -eq 0) {
    Add-Result 'G10 encoding' 'PASS' ("{0} files: strict UTF-8, no BOM, LF-only, no mojibake; ASCII enforced where required including this file's own bytes" -f $g10Checked)
}

$selfHash = 'UNAVAILABLE'
try { $selfHash = (Get-FileHash -LiteralPath $SelfPath -Algorithm SHA256).Hash.ToLower().Substring(0,8) } catch { }
Write-Reach ("self: {0} sha256 {1}" -f $SelfPath, $selfHash)

# ---------------------------------------------------------------------------------------------
# Summary. Counts DERIVED from the result list.
# ---------------------------------------------------------------------------------------------

$fail  = @($Script:Results | Where-Object { $_.Status -eq 'FAIL' }).Count
$skip  = @($Script:Results | Where-Object { $_.Status -eq 'SKIP' }).Count
$pass  = @($Script:Results | Where-Object { $_.Status -eq 'PASS' }).Count
$total = $Script:Results.Count

Write-Host ""
Write-Host "------------------------------------------------------------------------------"
Write-Host ("RESULTS: {0} emitted -- {1} passed, {2} failed, {3} skipped" -f $total, $pass, $fail, $skip)

if ($IsForeignTree) {
    Write-Host "SELF-TEST MODE: no acceptance verdict. Exit code reflects the fixture only."
    Write-Host "------------------------------------------------------------------------------"
    if ($fail -gt 0) { exit $fail }
    exit 0
}

if ($fail -gt 0) {
    Write-Host ("VERDICT: FAILED -- {0} failing check(s) above." -f $fail)
    Write-Host "------------------------------------------------------------------------------"
    exit $fail
}
if ($skip -gt 0) {
    Write-Host "VERDICT: PASSED WITH SKIPS. Exit 3."
    Write-Host "NOTE: exit 3 is NON-UNIQUE -- three failures also exit 3. Read the counts above."
    Write-Host "------------------------------------------------------------------------------"
    exit 3
}
Write-Host "VERDICT: ALL CHECKS PASSED."
Write-Host "------------------------------------------------------------------------------"
exit 0
