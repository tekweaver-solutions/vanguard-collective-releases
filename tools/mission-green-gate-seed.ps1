#Requires -Version 5.1
<#
.SYNOPSIS
  mission-green-gate-seed (F-034 / M-14, A-148) -- seed a per-suite green-gate manifest from a FRESH
  default run. REFUSES to seed over a real red (no seeding over a failure). On a clean run writes the
  manifest with expected_failure_test_ids EMPTY + stored_floor = the collected-and-runnable count
  (deselection-aware), records last_green_close=seed, and appends a ledger baseline-record (the audit
  twin; A-147 consistency anchor). Atomic commit. Per ADR-042.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('product','framework')][string]$SuiteId,
    [string]$Cwd,                  # suite cwd relative to repo root: product=src, framework=tools (defaulted)
    [switch]$NoCommit
)
. (Join-Path $PSScriptRoot 'mission-lib.ps1')
$root = Get-MissionRoot
if (-not $Cwd) { $Cwd = if ($SuiteId -eq 'product') { 'src' } else { 'tools' } }

if (-not $NoCommit) { Assert-CleanWorkingTree -Root $root }   # A-126

Write-Info "green-gate seed ($SuiteId): running the default unnamed suite in '$Cwd' (this runs the full suite)..."
$run = Invoke-SuiteDefaultRun -Root $root -Cwd $Cwd

# A-148: REFUSE to seed over a real red (no seeding over a failure / collection error).
if ($run.Failed -gt 0 -or $run.FailedIds.Count -gt 0 -or $run.CollectionError) {
    Stop-WithError ("REFUSED (green-gate seed, $SuiteId): the fresh run is NOT clean -- failed=$($run.Failed), failed_ids=[$($run.FailedIds -join ', ')], collection_error=$($run.CollectionError). A manifest MUST NOT seed over a real red (A-148). Fix the suite, then re-seed.")
}
$floor = $run.Runnable
$now = Get-UtcStamp
$manDir = Join-Path $root ".mission\green-gate"
if (-not (Test-Path $manDir)) { New-Item -ItemType Directory -Path $manDir -Force | Out-Null }
$manPath = Get-GreenGateManifestPath -Root $root -SuiteId $SuiteId

$manifest = [ordered]@{
    suite_id = $SuiteId
    cwd = $Cwd
    stored_floor = $floor
    expected_failure_test_ids = @()    # SEED EMPTY (no sanctioned red)
    last_green_close = [ordered]@{ transition='seed'; ref="green-gate-seed-$SuiteId"; collected=$floor; at=$now }
    schema_version = '1.0'
}
($manifest | ConvertTo-Json -Depth 8) | Set-Content -Path $manPath -Encoding ascii
Write-Pass "green-gate manifest written: $manPath (stored_floor=$floor, expected_failure_test_ids=EMPTY, runnable=$floor; passed=$($run.Passed), skipped=$($run.Skipped), deselected=$($run.Deselected))"

# ledger baseline-record (the A-147 audit twin; content carries 'stored_floor=N' for the consistency check).
# M-70 (A-338): DELEGATED to the single writer Add-GreenGateBaselineRecord (transition='seed') -- every
# seed event mints a UNIQUE timestamped id (the mission-lib close-record style) carrying the structured
# suite_id field (A-164). The old inline mint reused the FIXED id ledger-decision-green-gate-baseline-
# seed-$SuiteId, which the A-166 backfill supersedes for BOTH suites -- making every post-backfill seed
# twin selector-invisible at birth (an M-67 finding). Unique ids cannot join that superseded set.
$content = "GREEN-GATE BASELINE-RECORD ($SuiteId, seed) -- manifest seeded from a clean fresh default run. stored_floor=$floor (collected-and-runnable, deselection-aware: passed=$($run.Passed) + failed=$($run.Failed) + skipped=$($run.Skipped); deselected=$($run.Deselected) EXCLUDED). expected_failure_test_ids=EMPTY (no sanctioned red; A-148). cwd=$Cwd. This is the audit twin of $manPath; the A-147 consistency obligation is manifest.stored_floor == this latest baseline-record floor. transition=seed."
$null = Add-GreenGateBaselineRecord -Root $root -SuiteId $SuiteId -StoredFloor $floor -Transition 'seed' -Ref "green-gate-seed-$SuiteId" -Content $content -ExtraTags @('seed','f-034','m-14')

if (-not $NoCommit) {
    $body = "green-gate seed($SuiteId): stored_floor=$floor, expected-failures EMPTY (A-148)`r`n`r`nSeed the $SuiteId green-gate manifest from a clean fresh run.`r`n"
    $msg = New-CommitMessageFile -Root $root -Body $body
    Invoke-AtomicCommit -Root $root -Paths @(".mission/green-gate/$SuiteId.json", '.mission/ledger/entries.jsonl') -MessageFile $msg | Out-Null
}
Write-Host "mission green-gate-seed: done ($SuiteId, stored_floor=$floor)" -ForegroundColor Cyan
