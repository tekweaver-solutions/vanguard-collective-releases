#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrap a new mission monorepo in Local Orchestrator Mode.

.DESCRIPTION
  Creates a deterministic monorepo layout per Section 5 of
  local-orchestrator-mode.md (the design summary). Writes a starter
  Mission record (state = Created), initializes git, and makes the
  first commit.

  This script is the reusable extraction of the manual steps performed
  during the <project> bootstrap. It is invoked from the *parent*
  directory: a new folder named $ProjectName is created underneath.

  DELIBERATELY OUT OF SCOPE for this script:
    - Docker compose up / image pulls (ADR-004 / ADR-018)
    - MCP server installs (ADR-015 -- manual, post-design-acceptance)
    - Prompt registry pull (ADR-017 -- separate ceremony, not yet wired)
    - Inputs import (Phase 2 -- separate script)

.PARAMETER ProjectName
  Lowercase letters, digits, and hyphens. Must start with a letter or digit.
  A folder of this name must not already exist in the current directory.

.EXAMPLE
  PS> cd C:\work
  PS> .\some-monorepo\tools\mission-init.ps1 -ProjectName "new-mission"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectName
)

$ErrorActionPreference = 'Stop'

# ----- Validate ProjectName -----
if ($ProjectName -notmatch '^[a-z0-9][a-z0-9-]*$') {
    Write-Error "ProjectName must be lowercase letters, digits, and hyphens, starting with a letter or digit. Got: '$ProjectName'"
    exit 1
}

$cwd = (Get-Location).Path
$root = Join-Path $cwd $ProjectName
if (Test-Path $root) {
    Write-Error "Folder already exists: $root"
    exit 1
}

# ----- Directory layout (Section 5 of local-orchestrator-mode.md) -----
$dirs = @(
    ".mission/inputs",
    ".mission/spec/proposals",
    ".mission/contract/proposals",
    ".mission/contract/assertions",
    ".mission/handoffs",
    ".mission/dispatches",
    ".mission/validator-results",
    ".mission/amendments/inbox",
    ".mission/ledger",
    ".mission-runtime/worktrees",
    "prompts",
    "tools/mission-cli/config/proposals",
    "tools/worker-runner",
    "tools/validator-runner",
    "tools/tool-gateway",
    "docker",
    "src",
    "tests"
)

New-Item -ItemType Directory -Path $root -Force | Out-Null
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null
}

# ----- Leaf .gitkeep markers (so empty dirs survive git) -----
$leafDirs = @(
    ".mission/amendments/inbox",
    ".mission/contract/assertions",
    ".mission/contract/proposals",
    ".mission/dispatches",
    ".mission/handoffs",
    ".mission/inputs",
    ".mission/spec/proposals",
    ".mission/validator-results",
    "docker",
    "prompts",
    "src",
    "tests",
    "tools/mission-cli/config/proposals",
    "tools/tool-gateway",
    "tools/validator-runner",
    "tools/worker-runner"
)
foreach ($d in $leafDirs) {
    New-Item -ItemType File -Path (Join-Path $root (Join-Path $d ".gitkeep")) -Force | Out-Null
}

# Empty ledger -- append-only JSONL per Section 5.4 of the brief
New-Item -ItemType File -Path (Join-Path $root ".mission/ledger/entries.jsonl") -Force | Out-Null

# ----- File contents (BOM-less UTF-8 via System.IO.File) -----

$gitignoreContent = @'
# Ephemeral runtime cache -- losing this is recoverable from .mission/
# Per ADR-003, this directory has a different durability contract than .mission/
.mission-runtime/

# OS / editor noise
.DS_Store
Thumbs.db
*.swp
.vscode/
.idea/

# Node / language toolchains
node_modules/
__pycache__/
*.pyc
.venv/
dist/
build/
'@

$readmeTemplate = @'
# {{PROJECT_NAME}}

(Mission goal -- fill in during inputs import / design phase.)

This monorepo is a mission run under the multi-agent framework in **Local Orchestrator Mode**.

## Layout

| Path | Purpose |
|---|---|
| `.mission/` | Committed mission truth: spec, contract, handoffs, ledger, validator results, amendments. |
| `.mission-runtime/` | Gitignored. Ephemeral cache: trace store, durable-runtime checkpoints, worker worktrees. |
| `prompts/` | Pulled from the prompt registry at a pinned semver tag (ADR-012/ADR-017). |
| `tools/` | Mission CLI, worker/validator runners, tool gateway. |
| `docker/` | Compose file + sandbox Dockerfile extension (ADR-004/ADR-018). |
| `src/` | The product code being built. |
| `tests/` | Product tests (distinct from the framework's contract assertions). |

## Current state

`Mission.state = Created`. See `git log` for the audit trail.
'@

$missionTemplate = @'
# Mission record -- top-level state for this mission.
# Schema: expanded-schemas.md Section 1 (Mission).
# Local Orchestrator Mode -- see local-orchestrator-mode.md (ADRs 001-018).
#
# Two fields are intentionally `null` here even though the canonical
# schema marks them `required`:
#   - clarified_scope: filled in during the Design Phase.
#   - current_spec_version: set to 1 on `mission spec accept` (Phase 5).
#
# Per ADR-014, budget fields are NOT enforced in Local Orchestrator Mode;
# they are kept for portability to Hosted Autonomous Mode.

id: {{UUID}}
created_at: {{TIMESTAMP}}
created_by: "TODO - operator email or identifier"

goal: "TODO - fill in during design phase"
clarified_scope: null

state: Created
current_spec_version: null
current_milestone: null

budget:
  cost_soft_cap_usd: 200.00
  cost_hard_cap_usd: 500.00
  wallclock_soft_cap_hours: 40
  wallclock_hard_cap_hours: 168
  tokens_used: 0
  cost_used_usd: 0.00

risk_level: medium

human_owner: "TODO - operator email or identifier"
notification_channel: local-tui

completed_at: null
'@

$uuid = [guid]::NewGuid().ToString()
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)

$readme = $readmeTemplate.Replace('{{PROJECT_NAME}}', $ProjectName)
$mission = $missionTemplate.Replace('{{UUID}}', $uuid).Replace('{{TIMESTAMP}}', $ts)

[System.IO.File]::WriteAllText((Join-Path $root ".gitignore"), $gitignoreContent)
[System.IO.File]::WriteAllText((Join-Path $root "README.md"), $readme)
[System.IO.File]::WriteAllText((Join-Path $root ".mission/mission.yaml"), $mission)

# ----- git init + first commit -----
Push-Location $root
try {
    & git init -b main 2>&1 | Out-Null
    & git add . 2>&1 | Out-Null
    & git commit -m "Mission init: $ProjectName monorepo created" 2>&1 | Out-Null
    $commitOk = ($LASTEXITCODE -eq 0)
} finally {
    Pop-Location
}

if (-not $commitOk) {
    Write-Error "git commit failed in $root. Inspect the repo and resolve manually."
    exit 1
}

# ----- Next-step guidance -----
Write-Host ""
Write-Host "Created mission monorepo at: $root" -ForegroundColor Green
Write-Host ""
Write-Host "Mission.state = Created. Next steps:"
Write-Host "  1. Edit .mission/mission.yaml: fill in 'goal' and 'human_owner'."
Write-Host "  2. Drop requirements/samples/brand/context into .mission/inputs/"
Write-Host "     (or use tools/mission-inputs-import.ps1 once it exists)."
Write-Host "  3. Run 'mission design start' when inputs are ready."
Write-Host ""
Write-Host "Deliberately NOT done by this script:"
Write-Host "  - Docker compose up / image pulls (ADR-004 / ADR-018)"
Write-Host "  - MCP server installs (ADR-015 - post-design)"
Write-Host "  - Prompt registry pull (ADR-017 - separate ceremony)"
Write-Host ""
