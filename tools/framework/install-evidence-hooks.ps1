#Requires -Version 5.1
<#
.SYNOPSIS
  Install the A1 evidence-plane hooks into .claude/settings.json.

.DESCRIPTION
  Citation convention: LM2-ADR-0NN / "design SS<n>" denote
  docs/framework/vanguard-collective-local-modes-v2.1.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/.

  Ruling (TOOLS-FRAMEWORK): .claude/ is gitignored (.gitignore:7) and
  mission-spec-accept.ps1:190 depends on that exclusion, so the hook artifacts cannot be
  committed there without a force flag. Therefore tools/framework/hooks/ is the TRACKED
  SOURCE OF TRUTH and .claude/settings.json is a DERIVED, UNCOMMITTED install produced by
  this script -- run ONLY on explicit operator instruction, never as part of an artifact
  commit.

  DEFAULT IS DRY RUN. Without -Apply this script changes nothing and prints the diff it
  would make. Installing hooks changes the behaviour of live sessions; that is an operator
  decision, not a side effect of running a script.

  Refuses to clobber: if .claude/settings.json already carries a hook entry for an event this
  fragment installs, and that entry is not one of ours, the script reports and exits non-zero
  rather than overwriting it.

.EXAMPLE
  powershell -NoProfile -File tools/framework/install-evidence-hooks.ps1
  powershell -NoProfile -File tools/framework/install-evidence-hooks.ps1 -Apply
  powershell -NoProfile -File tools/framework/install-evidence-hooks.ps1 -Remove -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'hooks\lib\evidence-common.ps1')

$root         = Get-EvidenceRepoRoot
$fragmentPath = Join-Path $PSScriptRoot 'hooks\settings.evidence-hooks.json'
$settingsPath = Join-Path $root '.claude\settings.json'

if (-not (Test-Path -LiteralPath $fragmentPath)) { throw "fragment not found: $fragmentPath" }

$fragment = [System.IO.File]::ReadAllText($fragmentPath) | ConvertFrom-Json
$ourMarker = 'tools/framework/hooks/'

Write-Host "source of truth : $fragmentPath"
Write-Host "fragment sha256 : $(Get-Sha256OfFile -Path $fragmentPath)"
Write-Host "install target  : $settingsPath  (gitignored -- derived, uncommitted)"
Write-Host ""

# --- load existing settings -------------------------------------------------------------
$settings = $null
if (Test-Path -LiteralPath $settingsPath) {
    $existingText = [System.IO.File]::ReadAllText($settingsPath)
    Write-Host "existing settings.json sha256 : $(Get-Sha256OfFile -Path $settingsPath)"
    try { $settings = $existingText | ConvertFrom-Json }
    catch { throw "REFUSING: .claude/settings.json exists but is not valid JSON -- $($_.Exception.Message)" }
} else {
    Write-Host "existing settings.json        : (none -- will be created)"
    $settings = [pscustomobject]@{}
}
Write-Host ""

# --- convert to a hashtable tree we can edit ---------------------------------------------
# Type dispatch is explicit and ordered. Under Set-StrictMode -Version Latest a duck-typed
# check (".PSObject.Properties.Count") throws on shapes that do not carry Count -- an empty
# PSCustomObject from ConvertFrom-Json among them. Leading commas preserve array-ness across
# the function return boundary, which PowerShell otherwise unrolls.
function ConvertTo-Hashtable {
    param($Obj)
    if ($null -eq $Obj)        { return $null }
    if ($Obj -is [string])     { return $Obj }
    if ($Obj -is [ValueType])  { return $Obj }
    if ($Obj -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in @($Obj.Keys)) { $h[$k] = ConvertTo-Hashtable $Obj[$k] }
        return $h
    }
    if ($Obj -is [System.Collections.IEnumerable]) {
        return ,@(@($Obj) | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    if ($Obj -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in @($Obj.PSObject.Properties)) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $h
    }
    return $Obj
}

$settingsH = ConvertTo-Hashtable $settings
if ($null -eq $settingsH -or $settingsH -isnot [hashtable]) { $settingsH = @{} }
if (-not $settingsH.ContainsKey('hooks') -or $settingsH['hooks'] -isnot [hashtable]) { $settingsH['hooks'] = @{} }

$fragmentHooks = ConvertTo-Hashtable $fragment.hooks
$events = @($fragmentHooks.Keys)

# --- clobber check -------------------------------------------------------------------------
$conflicts = @()
foreach ($ev in $events) {
    if (-not $settingsH['hooks'].ContainsKey($ev)) { continue }
    foreach ($group in @($settingsH['hooks'][$ev])) {
        foreach ($h in @($group['hooks'])) {
            $cmd = [string]$h['command']
            if ($cmd -and ($cmd -notlike "*$ourMarker*")) {
                $conflicts += "$ev :: $cmd"
            }
        }
    }
}
if ($conflicts.Count -gt 0 -and -not $Remove) {
    Write-Host "REFUSING TO CLOBBER -- foreign hook entries already present on events this fragment installs:" -ForegroundColor Red
    $conflicts | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Merge them by hand, or remove them first. This script will not overwrite hooks it did not write." -ForegroundColor Yellow
    exit 1
}

# --- build the target state ------------------------------------------------------------------
foreach ($ev in $events) {
    # drop any of OUR entries first, so apply is idempotent and remove is exact
    if ($settingsH['hooks'].ContainsKey($ev)) {
        $kept = @()
        foreach ($group in @($settingsH['hooks'][$ev])) {
            $inner = @()
            foreach ($h in @($group['hooks'])) {
                $cmd = [string]$h['command']
                if (-not ($cmd -like "*$ourMarker*")) { $inner += $h }
            }
            if ($inner.Count -gt 0) { $group['hooks'] = $inner; $kept += $group }
        }
        if ($kept.Count -gt 0) { $settingsH['hooks'][$ev] = $kept } else { $settingsH['hooks'].Remove($ev) }
    }
    if (-not $Remove) {
        $existing = @()
        if ($settingsH['hooks'].ContainsKey($ev)) { $existing = @($settingsH['hooks'][$ev]) }
        $settingsH['hooks'][$ev] = @($existing + @($fragmentHooks[$ev]))
    }
}
if ($settingsH['hooks'].Count -eq 0) { $settingsH.Remove('hooks') }

$newText = ($settingsH | ConvertTo-Json -Depth 20)

# --- report ------------------------------------------------------------------------------------
$action = if ($Remove) { 'REMOVE' } else { 'INSTALL' }
Write-Host "--- $action : resulting .claude/settings.json ---"
Write-Host $newText
Write-Host ""

if (-not $Apply) {
    Write-Host "DRY RUN -- nothing written. Re-run with -Apply to write." -ForegroundColor Yellow
    exit 0
}

$dir = Split-Path -Parent $settingsPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if (Test-Path -LiteralPath $settingsPath) {
    $backup = "$settingsPath.bak-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ', [System.Globalization.CultureInfo]::InvariantCulture))"
    Copy-Item -LiteralPath $settingsPath -Destination $backup
    Write-Host "backup written : $backup"
}
[System.IO.File]::WriteAllText($settingsPath, $newText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "written        : $settingsPath"
Write-Host "new sha256     : $(Get-Sha256OfFile -Path $settingsPath)"
Write-Host ""
Write-Host "Hooks are installed for THIS repo. .claude/ is gitignored: this install is not committed" -ForegroundColor Cyan
Write-Host "and does not travel with the repo. tools/framework/hooks/ remains the source of truth." -ForegroundColor Cyan
