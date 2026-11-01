#Requires -Version 5.1
<#
.SYNOPSIS
  A7 acceptance instrument -- dispatch lifecycle versus turn lifecycle (D10).

.DESCRIPTION
  Citation convention: "design SS<n>" denotes
  docs/framework/vanguard-collective-local-modes-v2.3.md. Sealed dispatch
  docs/framework/build-dispatches/build-dispatch-dispatch-vs-turn-lifecycle.md.

  WHAT THIS PROVES, per member and in BOTH directions (operator constraint 1:
  the TAMPERED direction is the gate):
    A7-1  a dispatch that finalizes, grows by append, and Stops again reaches GREW (never
          TAMPERED), then SUPERSEDES with the prior manifest retained in both planes, and
          ends FINALIZED/consumable; a third turn extends the retention chain.
    A7-2  the detector survives the cure: sealed-byte mutation, truncation below the sealed
          prefix, and mutate-then-extend each derive TAMPERED, and Stop REFUSES with the
          manifest byte-identical.
    A7-3  legacy-form manifests (no log_bytes_sealed / finalize_count -- the pre-cure
          shape) derive by the count-derived prefix in both directions: grown-by-append
          derives GREW and supersedes; mutated derives TAMPERED. Nothing is migrated.
    A7-4  NEW-2 closes: an error recorded AFTER a finalize is reflected --
          without log growth via the no-op trail reconcile, and with growth via
          supersession -- and the trail reaches the committed plane. The pre-cure shape
          (committed manifest denying a live trail) is reproduced first.
    A7-5  single-turn regression: one finalize, no growth, later Stops are no-ops
          (byte-identical manifest, no supersession artifacts) -- the shape of A7-7's first residue member.
    A7-6  a SHORTER log -- even one truncated cleanly at a line boundary -- can never
          supersede: TAMPERED, REFUSED, manifest unchanged (the pre-cure refusal rationale,
          now a property of the append-extension predicate).
    A7-7  HISTORICAL DERIVATION IN PLACE, READ-ONLY, on the four real residue stores named
          by the amendment (content-anchored members, never a globbed population): expected
          FINALIZED / GREW / GREW / GREW, with before/after hashes proving nothing was
          repaired or written. An absent member reports CANNOT-DECIDE, never PASS.
    A7-8  instrument integrity: pure-ASCII BOM-less self-bytes, derived counts, exit
          contract printed.

  REACH, stated on its face: every fixture lives under a temp root; the only real-repository
  reads are A7-7's four named stores, and those are READ-ONLY with hash proof. In-session
  execution of this instrument is guard-denied (any command naming tools/framework/tests is
  refused; NEW-5), so EVERY run of this instrument is operator-run.
  In a copied fixture tree the real residue is absent by construction and A7-7 reports
  CANNOT-DECIDE per member -- the documented builder-side result; the operator run from the
  real tree is the binding one.

  EXIT CONTRACT (printed, derived, and NON-UNIQUE at 3, disclosed): exit 0 = every check
  passed and every A7-7 member decided; exit 3 = zero failures but at least one
  CANNOT-DECIDE; otherwise exit = the failure count, so a THREE-FAILURE run also exits 3.
  Read the printed counts, not the code.

  Instrument laws: (a) pure ASCII asserting its own bytes; (b) path variables
  carry a Path suffix; (c) child hooks write nothing to stderr by construction, and
  unresolvable results land CANNOT-DECIDE, never PASS. No green line appears on a failing
  run: per-check output is buffered and a failing run prints only its failures and
  undecided members.
#>
[CmdletBinding()]
param(
    [switch]$KeepFixtures
)

$ErrorActionPreference = 'Stop'

$hooksDirPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'hooks'
$repoRootPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$fixRootPath  = Join-Path ([System.IO.Path]::GetTempPath()) 'a7-lifecycle-fixture'

. (Join-Path $hooksDirPath 'lib\evidence-common.ps1')

# --- instrument law (a): self-byte assertion, reported as a check result (A7-8) ------------
$selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
$selfNonAscii = 0
foreach ($b in $selfBytes) { if ($b -gt 127) { $selfNonAscii++ } }
$selfBom = ($selfBytes.Length -ge 3 -and $selfBytes[0] -eq 239 -and $selfBytes[1] -eq 187 -and $selfBytes[2] -eq 191)

# --- buffered check bookkeeping: no green line on a failing run ----------------------------
$script:resultsList = New-Object System.Collections.Generic.List[object]
function Add-CheckResult {
    param([string]$Id, [string]$Title, [string]$Result, [string]$Detail)
    [void]$script:resultsList.Add([pscustomobject]@{ id = $Id; title = $Title; result = $Result; detail = $Detail })
}

Write-Host "=============================================================================="
Write-Host " A7 -- DISPATCH LIFECYCLE VERSUS TURN LIFECYCLE (D10)"
Write-Host "=============================================================================="
Write-Host "repo root    : $repoRootPath"
Write-Host "hooks dir    : $hooksDirPath"
Write-Host "fixture root : $fixRootPath   (temp; removed unless -KeepFixtures)"
Write-Host ""
Write-Host "REACH: fixtures under the temp root; the only real-repo touch is A7-7, READ-ONLY"
Write-Host "with before/after hash proof, over four NAMED stores (never a globbed set)."
Write-Host "In-session execution of this file is guard-denied; every run is operator-run."
Write-Host "EXIT: 0 = all passed, all decided; 3 = no failures but >=1 CANNOT-DECIDE"
Write-Host "(NON-UNIQUE -- a three-failure run also exits 3); else exit = failure count."

# --- fixture plumbing ----------------------------------------------------------------------
if (Test-Path -LiteralPath $fixRootPath) { Remove-Item -LiteralPath $fixRootPath -Recurse -Force }
New-Item -ItemType Directory -Path $fixRootPath -Force | Out-Null

function Add-A7Entry {
    param([string]$EvDirPath, [string]$DispatchId, [int]$Seq, [string]$Command, [string]$StdoutText)
    $streamsDirPath = Join-Path $EvDirPath 'streams'
    if (-not (Test-Path -LiteralPath $streamsDirPath)) { New-Item -ItemType Directory -Path $streamsDirPath -Force | Out-Null }
    $name = '{0:d6}.json' -f $Seq
    $body = [ordered]@{ seq = $Seq; tool = 'Bash'; stdout = $StdoutText; stderr = '' } | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText((Join-Path $streamsDirPath $name), $body, (New-Object System.Text.UTF8Encoding($false)))
    $entry = [ordered]@{
        ts = ('2026-08-11T00:00:{0:d2}.000Z' -f ($Seq % 60)); session_id = 'sess-a7'; dispatch_id = $DispatchId
        seq = $Seq; tool = 'Bash'; command = $Command; exit_code = $null
        stdout = $StdoutText; stderr = ''
        stdout_truncated = $false; stderr_truncated = $false
        stdout_sha256 = (Get-Sha256OfString $StdoutText); stderr_sha256 = (Get-Sha256OfString '')
        path = "streams/$name"
    } | ConvertTo-Json -Compress -Depth 8
    [System.IO.File]::AppendAllText((Join-Path $EvDirPath 'log.jsonl'), $entry + "`n")
}

function New-A7Fixture {
    param([string]$DispatchId, [int]$Entries)
    $evDirPath = Join-Path $fixRootPath ".mission-runtime\evidence\$DispatchId"
    New-Item -ItemType Directory -Path $evDirPath -Force | Out-Null
    for ($i = 1; $i -le $Entries; $i++) {
        Add-A7Entry -EvDirPath $evDirPath -DispatchId $DispatchId -Seq $i -Command "echo a7-$i" -StdoutText "a7-output-$i"
    }
    return $evDirPath
}

function Invoke-A7Stop {
    param([string]$DispatchId)
    $payloadJson = (@{ session_id = 'sess-a7'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)
    $env:CLAUDE_PROJECT_DIR  = $fixRootPath
    $env:MISSION_DISPATCH_ID = $DispatchId
    try {
        $out = $payloadJson | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $hooksDirPath 'evidence-stop-finalize.ps1')
        return [pscustomobject]@{ stdout = ($out -join "`n"); exit = $LASTEXITCODE }
    } finally {
        Remove-Item Env:\CLAUDE_PROJECT_DIR  -ErrorAction SilentlyContinue
        Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue
    }
}

# The pre-cure manifest shape, constructed by stripping the two additive fields. Regex over
# whole lines: both fields sit mid-object in the finalizer's 4-space ConvertTo-Json layout, so
# removing their lines leaves valid JSON. The strip is asserted, not assumed.
function ConvertTo-A7LegacyManifest {
    param([string]$ManifestPath)
    $txt = [System.IO.File]::ReadAllText($ManifestPath)
    $txt = $txt -replace '(?m)^\s*"log_bytes_sealed":.*\r?\n', ''
    $txt = $txt -replace '(?m)^\s*"finalize_count":.*\r?\n', ''
    [System.IO.File]::WriteAllText($ManifestPath, $txt, (New-Object System.Text.UTF8Encoding($false)))
    $man = [System.IO.File]::ReadAllText($ManifestPath) | ConvertFrom-Json
    if (($man.PSObject.Properties.Name -contains 'log_bytes_sealed') -or
        ($man.PSObject.Properties.Name -contains 'finalize_count')) {
        throw "A7 fixture defect: legacy strip left an additive field in $ManifestPath"
    }
}

function Get-A7CommittedDirPath { param([string]$DispatchId) Join-Path $fixRootPath ".mission\evidence\$DispatchId" }

# =============================================================================
# A7-1 -- multi-turn lifecycle: finalize, grow, GREW, supersede-with-retention, re-seal
# =============================================================================
$d1 = 'a7-multiturn'
$dir1 = New-A7Fixture -DispatchId $d1 -Entries 3
$logPath1 = Join-Path $dir1 'log.jsonl'
$manPath1 = Join-Path $dir1 'manifest.json'
$null = Invoke-A7Stop -DispatchId $d1
$man1 = [System.IO.File]::ReadAllText($manPath1) | ConvertFrom-Json
$st1  = Get-EvidenceState -Root $fixRootPath -DispatchId $d1
$len1 = ([System.IO.File]::ReadAllBytes($logPath1)).Length
$firstOk = ($st1.state -eq 'FINALIZED' -and $st1.consumable -and
            $man1.entry_count -eq 3 -and $man1.finalize_count -eq 1 -and
            $man1.log_bytes_sealed -eq $len1)

Add-A7Entry -EvDirPath $dir1 -DispatchId $d1 -Seq 4 -Command 'echo a7-4' -StdoutText 'a7-output-4'
Add-A7Entry -EvDirPath $dir1 -DispatchId $d1 -Seq 5 -Command 'echo a7-5' -StdoutText 'a7-output-5'
$stGrew1 = Get-EvidenceState -Root $fixRootPath -DispatchId $d1
$grewOk = ($stGrew1.state -eq 'GREW' -and -not $stGrew1.consumable -and
           $stGrew1.reason -like '*append-extension*')

$manHashBeforeSup = Get-Sha256OfFile -Path $manPath1
$null = Invoke-A7Stop -DispatchId $d1
$sup1RtPath = Join-Path $dir1 'manifest.superseded-001.json'
$sup1CmPath = Join-Path (Get-A7CommittedDirPath -DispatchId $d1) 'manifest.superseded-001.json'
$man2 = [System.IO.File]::ReadAllText($manPath1) | ConvertFrom-Json
$st2  = Get-EvidenceState -Root $fixRootPath -DispatchId $d1
$len2 = ([System.IO.File]::ReadAllBytes($logPath1)).Length
$parity1 = Test-EvidencePlaneParity -Root $fixRootPath -DispatchId $d1
$supOk = ((Test-Path -LiteralPath $sup1RtPath) -and (Test-Path -LiteralPath $sup1CmPath) -and
          (Get-Sha256OfFile -Path $sup1RtPath) -eq $manHashBeforeSup -and
          $man2.entry_count -eq 5 -and $man2.finalize_count -eq 2 -and
          $man2.log_bytes_sealed -eq $len2 -and
          $st2.state -eq 'FINALIZED' -and $st2.consumable -and $parity1.ok)

Add-A7Entry -EvDirPath $dir1 -DispatchId $d1 -Seq 6 -Command 'echo a7-6' -StdoutText 'a7-output-6'
$null = Invoke-A7Stop -DispatchId $d1
$man3 = [System.IO.File]::ReadAllText($manPath1) | ConvertFrom-Json
$sup2RtPath = Join-Path $dir1 'manifest.superseded-002.json'
$sup2CmPath = Join-Path (Get-A7CommittedDirPath -DispatchId $d1) 'manifest.superseded-002.json'
$chainOk = ($man3.finalize_count -eq 3 -and $man3.entry_count -eq 6 -and
            (Test-Path -LiteralPath $sup2RtPath) -and (Test-Path -LiteralPath $sup2CmPath))

$detail = @"
  first finalize   : state=$($st1.state) entry_count=$($man1.entry_count) finalize_count=$($man1.finalize_count) log_bytes_sealed=$($man1.log_bytes_sealed) (log $len1 bytes)
  after growth     : state=$($stGrew1.state) consumable=$($stGrew1.consumable)   (expect GREW, False)
                     reason: $($stGrew1.reason)
  after 2nd Stop   : state=$($st2.state) entry_count=$($man2.entry_count) finalize_count=$($man2.finalize_count)
                     retained runtime  : $(Test-Path -LiteralPath $sup1RtPath)
                     retained committed: $(Test-Path -LiteralPath $sup1CmPath)
                     retained == prior : $((Get-Sha256OfFile -Path $sup1RtPath) -eq $manHashBeforeSup)
                     plane parity ok   : $($parity1.ok)
  after 3rd turn   : finalize_count=$($man3.finalize_count) entry_count=$($man3.entry_count) superseded-002 both planes: $((Test-Path -LiteralPath $sup2RtPath) -and (Test-Path -LiteralPath $sup2CmPath))
"@
Add-CheckResult -Id 'A7-1' -Title 'finalize -> grow -> GREW -> supersede with retention -> FINALIZED; chain extends per turn' `
    -Result $(if ($firstOk -and $grewOk -and $supOk -and $chainOk) { 'PASS' } else { 'FAIL' }) -Detail $detail

# =============================================================================
# A7-2 -- THE GATE: every TAMPERED direction still fires, and Stop refuses
# =============================================================================
$d2 = 'a7-tampered'
$dir2 = New-A7Fixture -DispatchId $d2 -Entries 2
$logPath2 = Join-Path $dir2 'log.jsonl'
$manPath2 = Join-Path $dir2 'manifest.json'
$null = Invoke-A7Stop -DispatchId $d2
$sealedBytes2 = [System.IO.File]::ReadAllBytes($logPath2)

# (i) sealed byte mutated in place
$mutBytes2 = [byte[]]$sealedBytes2.Clone()
$mutBytes2[60] = $(if ($mutBytes2[60] -eq [byte][char]'x') { [byte][char]'y' } else { [byte][char]'x' })
[System.IO.File]::WriteAllBytes($logPath2, $mutBytes2)
$stMut2 = Get-EvidenceState -Root $fixRootPath -DispatchId $d2
$manHashPreRefuse = Get-Sha256OfFile -Path $manPath2
$null = Invoke-A7Stop -DispatchId $d2
$err2Path = Join-Path $dir2 'hook-errors.log'
$mutFired = ($stMut2.state -eq 'TAMPERED' -and
             (Get-Sha256OfFile -Path $manPath2) -eq $manHashPreRefuse -and
             (Test-Path -LiteralPath $err2Path) -and
             ([System.IO.File]::ReadAllText($err2Path) -like '*REFUSED to finalize TAMPERED*'))

# (ii) truncated below the sealed prefix (mid-line)
[System.IO.File]::WriteAllBytes($logPath2, $sealedBytes2)
[System.IO.File]::WriteAllBytes($logPath2, [byte[]]$sealedBytes2[0..($sealedBytes2.Length - 9)])
$stTrunc2 = Get-EvidenceState -Root $fixRootPath -DispatchId $d2
$truncFired = ($stTrunc2.state -eq 'TAMPERED' -and $stTrunc2.reason -like '*SHORTER*')

# (iii) mutate-then-extend: the member a naive length check would miss
[System.IO.File]::WriteAllBytes($logPath2, $sealedBytes2)
$mutGrow2 = [byte[]]$sealedBytes2.Clone()
$mutGrow2[60] = $(if ($mutGrow2[60] -eq [byte][char]'x') { [byte][char]'y' } else { [byte][char]'x' })
[System.IO.File]::WriteAllBytes($logPath2, $mutGrow2)
$extraLine = '{"ts":"2026-08-11T00:00:09.000Z","session_id":"sess-a7","dispatch_id":"' + $d2 + '","seq":99,"tool":"Bash","command":"echo x","exit_code":null,"stdout":"x","stderr":"","stdout_truncated":false,"stderr_truncated":false,"stdout_sha256":"' + (Get-Sha256OfString 'x') + '","stderr_sha256":"' + (Get-Sha256OfString '') + '","path":"streams/000099.json"}'
[System.IO.File]::AppendAllText($logPath2, $extraLine + "`n")
$stMutGrow2 = Get-EvidenceState -Root $fixRootPath -DispatchId $d2
$mutGrowFired = ($stMutGrow2.state -eq 'TAMPERED')

[System.IO.File]::WriteAllBytes($logPath2, $sealedBytes2)

$detail = @"
  (i)  sealed byte mutated : state=$($stMut2.state)   (expect TAMPERED)
       Stop refused        : manifest unchanged=$((Get-Sha256OfFile -Path $manPath2) -eq $manHashPreRefuse), REFUSED on trail=$([System.IO.File]::ReadAllText($err2Path) -like '*REFUSED to finalize TAMPERED*')
       reason: $($stMut2.reason)
  (ii) truncated mid-line  : state=$($stTrunc2.state)   (expect TAMPERED)
       reason: $($stTrunc2.reason)
  (iii) mutate-then-extend : state=$($stMutGrow2.state)   (expect TAMPERED -- growth cannot mask mutation)
"@
Add-CheckResult -Id 'A7-2' -Title 'TAMPERED preserved per member: mutation, truncation, mutate-then-extend; Stop refuses with manifest untouched' `
    -Result $(if ($mutFired -and $truncFired -and $mutGrowFired) { 'PASS' } else { 'FAIL' }) -Detail $detail

# =============================================================================
# A7-3 -- legacy-form manifests, both directions, nothing migrated
# =============================================================================
$d3 = 'a7-legacy'
$dir3 = New-A7Fixture -DispatchId $d3 -Entries 2
$manPath3 = Join-Path $dir3 'manifest.json'
$null = Invoke-A7Stop -DispatchId $d3
ConvertTo-A7LegacyManifest -ManifestPath $manPath3
$cm3ManPath = Join-Path (Get-A7CommittedDirPath -DispatchId $d3) 'manifest.json'
if (Test-Path -LiteralPath $cm3ManPath) { ConvertTo-A7LegacyManifest -ManifestPath $cm3ManPath }

Add-A7Entry -EvDirPath $dir3 -DispatchId $d3 -Seq 3 -Command 'echo a7-legacy-3' -StdoutText 'a7-legacy-output-3'
$stLegacyGrew = Get-EvidenceState -Root $fixRootPath -DispatchId $d3
$null = Invoke-A7Stop -DispatchId $d3
$man3b = [System.IO.File]::ReadAllText($manPath3) | ConvertFrom-Json
$sup3RtPath = Join-Path $dir3 'manifest.superseded-001.json'
$stLegacyAfter = Get-EvidenceState -Root $fixRootPath -DispatchId $d3
$legacyGrowOk = ($stLegacyGrew.state -eq 'GREW' -and
                 (Test-Path -LiteralPath $sup3RtPath) -and
                 $man3b.entry_count -eq 3 -and $man3b.finalize_count -eq 2 -and
                 ($man3b.PSObject.Properties.Name -contains 'log_bytes_sealed') -and
                 $stLegacyAfter.state -eq 'FINALIZED')

$d3b = 'a7-legacy-mut'
$dir3b = New-A7Fixture -DispatchId $d3b -Entries 2
$logPath3b = Join-Path $dir3b 'log.jsonl'
$null = Invoke-A7Stop -DispatchId $d3b
ConvertTo-A7LegacyManifest -ManifestPath (Join-Path $dir3b 'manifest.json')
$bytes3b = [System.IO.File]::ReadAllBytes($logPath3b)
$mut3b = [byte[]]$bytes3b.Clone()
$mut3b[60] = $(if ($mut3b[60] -eq [byte][char]'x') { [byte][char]'y' } else { [byte][char]'x' })
[System.IO.File]::WriteAllBytes($logPath3b, $mut3b)
$stLegacyMut = Get-EvidenceState -Root $fixRootPath -DispatchId $d3b
$legacyMutOk = ($stLegacyMut.state -eq 'TAMPERED')

$detail = @"
  legacy grown  : state=$($stLegacyGrew.state)   (expect GREW -- count-derived prefix, no log_bytes_sealed)
                  reason: $($stLegacyGrew.reason)
  supersession  : retained=$(Test-Path -LiteralPath $sup3RtPath) entry_count=$($man3b.entry_count) finalize_count=$($man3b.finalize_count) upgraded-form=$($man3b.PSObject.Properties.Name -contains 'log_bytes_sealed')
  legacy mutated: state=$($stLegacyMut.state)   (expect TAMPERED)
                  reason: $($stLegacyMut.reason)
"@
Add-CheckResult -Id 'A7-3' -Title 'legacy manifests derive GREW/TAMPERED by count-derived prefix; supersession upgrades in place, migrating nothing' `
    -Result $(if ($legacyGrowOk -and $legacyMutOk) { 'PASS' } else { 'FAIL' }) -Detail $detail

# =============================================================================
# A7-4 -- NEW-2 closes: the error trail is reachable after finalize
# =============================================================================
$d4 = 'a7-errtrail'
$dir4 = New-A7Fixture -DispatchId $d4 -Entries 1
$manPath4 = Join-Path $dir4 'manifest.json'
$err4Path = Join-Path $dir4 'hook-errors.log'
$cm4DirPath = Get-A7CommittedDirPath -DispatchId $d4
$null = Invoke-A7Stop -DispatchId $d4
$man4a = [System.IO.File]::ReadAllText($manPath4) | ConvertFrom-Json
$cleanAtSeal = ($man4a.hook_errors_present -eq $false)

# the error arrives AFTER finalize (written directly -- no lib call, so nothing can resolve
# to the real repository root)
[System.IO.File]::AppendAllText($err4Path, "2026-08-11T00:00:05.000Z PostToolUse: SIMULATED post-finalize failure for A7-4`n")

# THE PRE-CURE SHAPE, REPRODUCED: the committed manifest denies a trail that exists.
$cm4Man = [System.IO.File]::ReadAllText((Join-Path $cm4DirPath 'manifest.json')) | ConvertFrom-Json
$preCureShape = ($cm4Man.hook_errors_present -eq $false -and (Test-Path -LiteralPath $err4Path))

# member 1: NO log growth -- the no-op Stop reconciles the trail flags, log seal untouched.
# Every boolean is CAPTURED AT ASSERTION TIME: member 2 grows the trail below, so a detail
# line that re-evaluated these later would print a verdict contradicting the assertion.
$null = Invoke-A7Stop -DispatchId $d4
$man4b = [System.IO.File]::ReadAllText($manPath4) | ConvertFrom-Json
$cm4ManB = [System.IO.File]::ReadAllText((Join-Path $cm4DirPath 'manifest.json')) | ConvertFrom-Json
$anchor4bOk = ($man4b.hook_errors_sha256 -eq (Get-Sha256OfFile -Path $err4Path))
$noGrowthOk = ($man4b.hook_errors_present -eq $true -and
               $anchor4bOk -and
               ($man4b.PSObject.Properties.Name -contains 'reconciled') -and $man4b.reconciled -eq $true -and
               $man4b.log_sha256 -eq $man4a.log_sha256 -and
               $man4b.finalize_count -eq 1 -and
               $cm4ManB.hook_errors_present -eq $true -and
               (Test-Path -LiteralPath (Join-Path $cm4DirPath 'hook-errors.log')))

# member 2: WITH log growth -- supersession carries the grown trail
[System.IO.File]::AppendAllText($err4Path, "2026-08-11T00:00:06.000Z PostToolUse: SIMULATED second failure for A7-4`n")
Add-A7Entry -EvDirPath $dir4 -DispatchId $d4 -Seq 2 -Command 'echo a7-err-2' -StdoutText 'a7-err-output-2'
$null = Invoke-A7Stop -DispatchId $d4
$man4c = [System.IO.File]::ReadAllText($manPath4) | ConvertFrom-Json
$cm4ErrPath = Join-Path $cm4DirPath 'hook-errors.log'
$anchor4cOk = ($man4c.hook_errors_sha256 -eq (Get-Sha256OfFile -Path $err4Path))
$carryHash4cOk = ((Get-Sha256OfFile -Path $cm4ErrPath) -eq (Get-Sha256OfFile -Path $err4Path))
$growthCarryOk = ($man4c.hook_errors_present -eq $true -and
                  $anchor4cOk -and
                  $man4c.finalize_count -eq 2 -and
                  (Test-Path -LiteralPath $cm4ErrPath) -and
                  $carryHash4cOk)

$detail = @"
  clean at seal                : hook_errors_present=$($man4a.hook_errors_present)   (expect False)
  PRE-CURE SHAPE REPRODUCED    : committed manifest denies a live trail = $preCureShape   (expect True -- this is NEW-2)
  member 1 (no growth, no-op Stop reconciles; booleans captured at assertion time):
    hook_errors_present=$($man4b.hook_errors_present) anchor re-derives=$anchor4bOk reconciled=$($man4b.reconciled)
    log seal untouched=$($man4b.log_sha256 -eq $man4a.log_sha256) finalize_count=$($man4b.finalize_count)   (expect 1 -- no supersession)
    committed reflects trail=$($cm4ManB.hook_errors_present) committed trail present=$(Test-Path -LiteralPath (Join-Path $cm4DirPath 'hook-errors.log'))
  member 2 (growth, supersession carries):
    hook_errors_present=$($man4c.hook_errors_present) anchor re-derives=$anchor4cOk finalize_count=$($man4c.finalize_count)
    committed trail hash == runtime trail hash = $carryHash4cOk
"@
Add-CheckResult -Id 'A7-4' -Title 'NEW-2 closes: post-finalize errors reach the manifest and the committed plane, with and without log growth' `
    -Result $(if ($cleanAtSeal -and $preCureShape -and $noGrowthOk -and $growthCarryOk) { 'PASS' } else { 'FAIL' }) -Detail $detail

# =============================================================================
# A7-5 -- single-turn regression: the shape of A7-7's first residue member
# =============================================================================
$d5 = 'a7-singleturn'
$dir5 = New-A7Fixture -DispatchId $d5 -Entries 2
$manPath5 = Join-Path $dir5 'manifest.json'
$null = Invoke-A7Stop -DispatchId $d5
$h5a = Get-Sha256OfFile -Path $manPath5
$null = Invoke-A7Stop -DispatchId $d5
$h5b = Get-Sha256OfFile -Path $manPath5
$st5 = Get-EvidenceState -Root $fixRootPath -DispatchId $d5
$sup5 = @(Get-ChildItem -LiteralPath $dir5 -File -Filter 'manifest.superseded-*.json' -ErrorAction SilentlyContinue)
$man5 = [System.IO.File]::ReadAllText($manPath5) | ConvertFrom-Json
$detail = @"
  manifest unchanged across a second Stop : $($h5a -eq $h5b)   (expect True -- no-op)
  state          : $($st5.state)   (expect FINALIZED, consumable=$($st5.consumable))
  finalize_count : $($man5.finalize_count)   (expect 1)
  superseded files : $($sup5.Count)   (expect 0)
"@
Add-CheckResult -Id 'A7-5' -Title 'single-turn dispatch: one finalize, later Stops are no-ops, no supersession artifacts' `
    -Result $(if ($h5a -eq $h5b -and $st5.state -eq 'FINALIZED' -and $st5.consumable -and $sup5.Count -eq 0 -and $man5.finalize_count -eq 1) { 'PASS' } else { 'FAIL' }) -Detail $detail

# =============================================================================
# A7-6 -- a shorter log can never supersede, even truncated cleanly at a line boundary
# =============================================================================
$d6 = 'a7-shorter'
$dir6 = New-A7Fixture -DispatchId $d6 -Entries 3
$logPath6 = Join-Path $dir6 'log.jsonl'
$manPath6 = Join-Path $dir6 'manifest.json'
$null = Invoke-A7Stop -DispatchId $d6
$lines6 = [System.IO.File]::ReadAllLines($logPath6)
[System.IO.File]::WriteAllText($logPath6, (($lines6[0..1] -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
$st6 = Get-EvidenceState -Root $fixRootPath -DispatchId $d6
$h6a = Get-Sha256OfFile -Path $manPath6
$null = Invoke-A7Stop -DispatchId $d6
$h6b = Get-Sha256OfFile -Path $manPath6
$err6Path = Join-Path $dir6 'hook-errors.log'
$sup6 = @(Get-ChildItem -LiteralPath $dir6 -File -Filter 'manifest.superseded-*.json' -ErrorAction SilentlyContinue)
$detail = @"
  truncated to 2 of 3 lines (a plausibly-clean shorter log)
  state             : $($st6.state)   (expect TAMPERED)
  reason            : $($st6.reason)
  manifest unchanged: $($h6a -eq $h6b)   (expect True -- REFUSED, no supersession)
  REFUSED on trail  : $((Test-Path -LiteralPath $err6Path) -and ([System.IO.File]::ReadAllText($err6Path) -like '*REFUSED to finalize TAMPERED*'))
  superseded files  : $($sup6.Count)   (expect 0)
"@
Add-CheckResult -Id 'A7-6' -Title 'shorter-log-cannot-supersede: line-boundary truncation derives TAMPERED and is refused' `
    -Result $(if ($st6.state -eq 'TAMPERED' -and $h6a -eq $h6b -and $sup6.Count -eq 0 -and (Test-Path -LiteralPath $err6Path) -and ([System.IO.File]::ReadAllText($err6Path) -like '*REFUSED to finalize TAMPERED*')) { 'PASS' } else { 'FAIL' }) -Detail $detail

# =============================================================================
# A7-7 -- historical derivation IN PLACE on the four real residue stores, READ-ONLY
# =============================================================================
# CONTENT-ANCHORED MEMBERS: the four stores named by the amendment, never a
# globbed population -- a fifth store appearing later must not perturb this check. Expected
# states are the amendment's own forecast. Read-only is PROVEN by before/after hashes of
# every artifact this derivation touches. Nothing is repaired: the orphaned lines stay
# orphaned, the REFUSED entries stay on the record.
$residueMembers = @(
    @{ id = 'session-00004f11-0000-4000-8000-000000004f11'; expect = 'FINALIZED' },
    @{ id = 'session-0000aa33-0000-4000-8000-00000000aa33'; expect = 'GREW' },
    @{ id = 'session-0000659f-0000-4000-8000-00000000659f'; expect = 'GREW' },
    @{ id = 'session-0000a9ee-0000-4000-8000-00000000a9ee'; expect = 'GREW' }
)
$memberLines = @()
$anyAbsent = $false
$anyWrong  = $false
foreach ($m in $residueMembers) {
    $rtDirPath = Join-Path $repoRootPath ".mission-runtime\evidence\$($m.id)"
    if (-not (Test-Path -LiteralPath $rtDirPath)) {
        $anyAbsent = $true
        $memberLines += "    $($m.id) : ABSENT -- CANNOT-DECIDE (expected in a copied fixture tree; the operator run from the real tree decides)"
        continue
    }
    $probePaths = @('log.jsonl', 'manifest.json', 'hook-errors.log') | ForEach-Object { Join-Path $rtDirPath $_ }
    $before = @($probePaths | ForEach-Object { if (Test-Path -LiteralPath $_) { Get-Sha256OfFile -Path $_ } else { '(absent)' } })
    $st = Get-EvidenceState -Root $repoRootPath -DispatchId $m.id
    $after = @($probePaths | ForEach-Object { if (Test-Path -LiteralPath $_) { Get-Sha256OfFile -Path $_ } else { '(absent)' } })
    $untouched = (@(0..2 | Where-Object { $before[$_] -ne $after[$_] }).Count -eq 0)
    $stateOk = ($st.state -eq $m.expect)
    if (-not ($stateOk -and $untouched)) { $anyWrong = $true }
    $memberLines += "    $($m.id) : derived=$($st.state) expected=$($m.expect) match=$stateOk untouched=$untouched"
    $memberLines += "      reason: $($st.reason)"
}
$detail = ($memberLines -join "`n")
$a77Result = if ($anyWrong) { 'FAIL' } elseif ($anyAbsent) { 'CANNOT-DECIDE' } else { 'PASS' }
Add-CheckResult -Id 'A7-7' -Title 'four real residue stores re-derive FINALIZED/GREW/GREW/GREW in place, read-only, nothing repaired' `
    -Result $a77Result -Detail $detail

# =============================================================================
# A7-8 -- instrument integrity
# =============================================================================
$detail = @"
  self bytes      : $($selfBytes.Length)
  BOM present     : $selfBom   (expect False)
  non-ASCII bytes : $selfNonAscii   (expect 0)
  counts          : derived from the buffered result list at the summary, never typed
"@
Add-CheckResult -Id 'A7-8' -Title 'instrument integrity: BOM-less pure-ASCII self-bytes; derived counts; disclosed exit contract' `
    -Result $(if (-not $selfBom -and $selfNonAscii -eq 0) { 'PASS' } else { 'FAIL' }) -Detail $detail

# --- summary (derived; no green line on a failing run) -------------------------------------
$failList  = @($script:resultsList | Where-Object { $_.result -eq 'FAIL' })
$undecList = @($script:resultsList | Where-Object { $_.result -eq 'CANNOT-DECIDE' })
$passList  = @($script:resultsList | Where-Object { $_.result -eq 'PASS' })

if ($failList.Count -gt 0) {
    foreach ($r in @($failList) + @($undecList)) {
        Write-Host ""
        Write-Host "[$($r.result)] $($r.id) -- $($r.title)"
        Write-Host $r.detail
    }
} else {
    foreach ($r in $script:resultsList) {
        Write-Host ""
        Write-Host "[$($r.result)] $($r.id) -- $($r.title)"
        Write-Host $r.detail
    }
}

Write-Host ""
Write-Host "=============================================================================="
Write-Host " A7 SUMMARY: $($passList.Count) passed, $($failList.Count) failed, $($undecList.Count) cannot-decide, $($script:resultsList.Count) checks run"
Write-Host "=============================================================================="

if (-not $KeepFixtures) {
    Remove-Item -LiteralPath $fixRootPath -Recurse -Force
    Write-Host "fixture root removed: $fixRootPath"
} else {
    Write-Host "fixture root kept for inspection: $fixRootPath"
}

if ($failList.Count -gt 0) { exit $failList.Count }
if ($undecList.Count -gt 0) { exit 3 }
exit 0
