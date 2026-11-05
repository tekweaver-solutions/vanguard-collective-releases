#Requires -Version 5.1
<#
.SYNOPSIS
  Phase 3 (Design) bootstrap. Verifies preconditions, assembles a
  design-context blob from .mission/inputs/, transitions Mission.state
  from Created to Planning, and commits the transition.

.DESCRIPTION
  Per Section 6.1 of local-orchestrator-mode.md, the Design Phase is a
  batch job, not a chat. This script's job is the deterministic setup:
  it produces the single context blob the designer reads, and it does
  the gated state transition. Drafting itself is then done by an LLM
  (Claude Code in thinking-partner mode for this mission).

  Hard gates enforced:
    - .mission/mission.yaml must exist and Mission.state must be 'Created'.
    - .mission/inputs/INDEX.md must exist and inputs/ must contain at
      least one non-.gitkeep file.

  After successful run:
    - .mission-runtime/design-context.md exists (gitignored cache).
    - Mission.state == Planning, committed.

.PARAMETER (none)
  The script takes no parameters. Mission root is resolved from
  $PSScriptRoot.Parent.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ----- Resolve paths -----
$root        = (Get-Item $PSScriptRoot).Parent.FullName
$missionFile = Join-Path $root ".mission\mission.yaml"
$inputsDir   = Join-Path $root ".mission\inputs"
$indexFile   = Join-Path $inputsDir "INDEX.md"
$runtimeDir  = Join-Path $root ".mission-runtime"
$contextFile = Join-Path $runtimeDir "design-context.md"

# ----- Pre-flight gates -----
if (-not (Test-Path $missionFile)) {
    Write-Error "Mission file not found: $missionFile"
    exit 1
}
if (-not (Test-Path $indexFile)) {
    Write-Error "INDEX.md not found at $indexFile. Run Phase 2 (mission-inputs-import.ps1) first."
    exit 1
}

$missionContent = [System.IO.File]::ReadAllText($missionFile)
if ($missionContent -notmatch '(?m)^state:\s*Created\s*$') {
    Write-Error "Mission.state is not 'Created' -- refusing to start the design phase. State transitions are deliberate; see local-orchestrator-mode.md Section 6.1."
    exit 1
}

$inputFiles = @(Get-ChildItem -Path $inputsDir -Recurse -File |
    Where-Object { $_.Name -ne '.gitkeep' -and $_.Name -ne 'INDEX.md' })
if ($inputFiles.Count -eq 0) {
    Write-Error "No input files found under .mission/inputs/. Run Phase 2 first."
    exit 1
}

Write-Host "Found $($inputFiles.Count) input file(s) to assemble." -ForegroundColor Green

# ----- Build design context blob -----
if (-not (Test-Path $runtimeDir)) {
    New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
}

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
$binExts = @('.docx','.pdf','.xlsx','.pptx','.png','.jpg','.jpeg','.tiff','.bmp')

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Design context")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Assembled by tools/mission-design-start.ps1 at $now.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Source files concatenated below with H2 headers, sourced from .mission/inputs/. INDEX.md (the manifest) is first; the designer should read it before the other files.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Binary files are omitted from this blob; their extracted .md siblings (per ADR-019) are included instead.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# INDEX.md first
[void]$sb.AppendLine("## .mission/inputs/INDEX.md")
[void]$sb.AppendLine("")
[void]$sb.AppendLine([System.IO.File]::ReadAllText($indexFile))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Other files, sorted for determinism
foreach ($f in ($inputFiles | Sort-Object FullName)) {
    $rel = $f.FullName.Substring($root.Length + 1).Replace('\','/')
    if ($binExts -contains $f.Extension.ToLower()) {
        [void]$sb.AppendLine("## $rel (BINARY -- omitted; see sibling .md if present)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("---")
        [void]$sb.AppendLine("")
        continue
    }
    [void]$sb.AppendLine("## $rel")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine([System.IO.File]::ReadAllText($f.FullName))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
}

[System.IO.File]::WriteAllText($contextFile, $sb.ToString())
Write-Host "Wrote design context: $contextFile ($((Get-Item $contextFile).Length) bytes)" -ForegroundColor Green

# ----- Transition Mission.state: Created -> Planning -----
$newMissionContent = $missionContent -replace '(?m)^state:\s*Created\s*$', 'state: Planning'
[System.IO.File]::WriteAllText($missionFile, $newMissionContent)
Write-Host "Mission.state -> Planning" -ForegroundColor Yellow

# ----- Commit the state transition (do not redirect git stderr in PS 5.1) -----
Push-Location $root
try {
    & git add .mission/mission.yaml | Out-Null
    & git commit -m "Mission state: Created -> Planning (Phase 3 begin)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git commit returned exit code $LASTEXITCODE; inspect repo state manually."
    }
} finally {
    Pop-Location
}

# ----- UI-1 S1 (ADR-045): the stage transition offers the mission-event feed its snapshot -----
# Created -> Planning moves the derived state, so a snapshot line is written (on change only). Through
# tools\lam\mission-telemetry.ps1; it prints nothing and can fail nothing.
try {
    $tmS = Join-Path $PSScriptRoot 'lam\mission-telemetry.ps1'
    if (Test-Path -LiteralPath $tmS -PathType Leaf) { . $tmS; Invoke-MissionTelemetry -Root $root -Snapshot -Verb 'design-start' }
} catch { }

# ----- Designer instructions -----
Write-Host ""
Write-Host "=== DESIGNER INSTRUCTIONS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "The designer (Claude Code in thinking-partner mode for this mission)"
Write-Host "should now read $contextFile and produce, into .mission/spec/proposals/,"
Write-Host ".mission/contract/proposals/, and tools/mission-cli/config/proposals/:"
Write-Host ""
Write-Host "  - v001.yaml             (LivingSpec; expanded-schemas.md Section 2)"
Write-Host "  - A-NNN.yaml            (20-40 assertions; Section 3)"
Write-Host "  - mcp-tools.yaml        (recommended MCP tools per ADR-015)"
Write-Host "  - design-notes-001.md   (designer reasoning + open questions)"
Write-Host ""
Write-Host "Then switch to operator hat and write:"
Write-Host "  - operator-review-001.md"
Write-Host ""
