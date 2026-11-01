#Requires -Version 5.1
# The acceptance run of a checkout: WP-1..6 serially through the house helper, one run key per reading.
#
#   -RunKey     the reading's key; a key that already names a capture is refused (exit 9), never overwritten.
#   -Root       the checkout whose instruments run and whose .mission-runtime\lam\instrument-runs\ takes the
#               captures; default the checkout this file sits in. It runs as well in a linked worktree as at a
#               primary checkout: run the worktree's own copy, or name the worktree here.
#   -SmokeRoot  the smoke mission the instruments that reach the smoke repository read (WP-2, WP-3 and WP-6). It
#               is handed to them as the environment variable LAM_SMOKE_ROOT, because the helper launches every
#               instrument with no argument; each prints the root it read and where the value came from. Not
#               given, LAM_SMOKE_ROOT is cleared for the run (an inherited value would steer the reading
#               unseen), so each falls back to its own default: lam-smoke beside the primary checkout of -Root.
#               tools\lam\build-smoke-mission.ps1 builds a smoke mission, there by default or at -SmokeRoot.
#
# The output lines are the acceptance's: RUNKEY, ROOT, HEAD, BRANCH, PORCELAIN, PATH-DERIVATION, STARTED, one
# block per instrument, ENDED, HEAD-AFTER, PORCELAIN-AFTER, CAPTURES with each capture's size and sha256, SUMMARY.
param(
    [Parameter(Mandatory = $true)][string]$RunKey,
    [string]$Root,
    [string]$SmokeRoot
)
$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..\..' }
if (-not (Test-Path -LiteralPath (Join-Path $Root 'tools\lam\lam-instrument-run.ps1') -PathType Leaf)) { "REFUSED: $Root is not a checkout of this repository (no tools\lam\lam-instrument-run.ps1)"; exit 9 }
$root = (Resolve-Path -LiteralPath $Root).Path
if ($SmokeRoot) {
    if (-not (Test-Path -LiteralPath $SmokeRoot -PathType Container)) { "REFUSED: -SmokeRoot $SmokeRoot is not a folder"; exit 9 }
    $SmokeRoot = (Resolve-Path -LiteralPath $SmokeRoot).Path
}
Set-Location $root
. (Join-Path $root 'tools\lam\lam-instrument-run.ps1')
$runs = Join-Path $root '.mission-runtime\lam\instrument-runs'
$token = ConvertTo-LamRunToken -Text $RunKey
$existing = @(Get-ChildItem -Path $runs -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.StartsWith($RunKey + '.') -or $_.Name.StartsWith([string]$token + '.') })
if ($existing.Count -gt 0) { "REFUSED: $($existing.Count) capture(s) already carry run key $RunKey -- a reading is never overwritten; use a new key"; exit 9 }
$t0all = [DateTime]::UtcNow
"RUNKEY $RunKey"
"ROOT $root"
"HEAD " + (& git rev-parse HEAD)
"BRANCH " + (& git rev-parse --abbrev-ref HEAD)
"PORCELAIN " + ((& git status --short --branch --untracked-files=no) -join ' | ')
"PATH-DERIVATION (WP-1) " + ((Get-LamInstrumentRunPath -MissionRoot $root -InstrumentPath (Join-Path $root 'tests\lam\instrument-WP-1.ps1') -RunKey $RunKey) | Out-String -Width 300).Trim()
"STARTED " + $t0all.ToString('o')
$summary = @()
$smokeBefore = [Environment]::GetEnvironmentVariable('LAM_SMOKE_ROOT')
try {
    [Environment]::SetEnvironmentVariable('LAM_SMOKE_ROOT', $(if ($SmokeRoot) { $SmokeRoot } else { $null }))
    foreach ($n in 1..6) {
        $inst = Join-Path $root ("tests\lam\instrument-WP-$n.ps1")
        $t0 = [DateTime]::UtcNow
        $r = Save-LamInstrumentRun -InstrumentPath $inst -MissionRoot $root -RunKey $RunKey
        $ec = $LASTEXITCODE
        $t1 = [DateTime]::UtcNow
        "---- WP-$n exit=$ec seconds=" + [int](($t1 - $t0).TotalSeconds)
        ($r | Format-List * | Out-String -Width 300).Trim()
        $summary += "WP-$n exit=$ec"
    }
} finally { [Environment]::SetEnvironmentVariable('LAM_SMOKE_ROOT', $smokeBefore) }
"ENDED " + [DateTime]::UtcNow.ToString('o')
"HEAD-AFTER " + (& git rev-parse HEAD)
"PORCELAIN-AFTER " + ((& git status --short --branch --untracked-files=no) -join ' | ')
"CAPTURES (written since STARTED)"
Get-ChildItem -Path $runs -File | Where-Object { $_.LastWriteTimeUtc -ge $t0all } | Sort-Object Name | ForEach-Object {
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLower()
    "{0}  {1} B  sha256={2}" -f $_.Name, $_.Length, $h
}
"SUMMARY"
$summary
