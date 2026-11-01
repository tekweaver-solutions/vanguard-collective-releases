#Requires -Version 5.1
<#
.SYNOPSIS
  Operator entry: dispatch a worker against the committed v010 contract.

.DESCRIPTION
  Per ADR-007 / kickoff prompt §6.5, this is the operator-facing PS entry
  that triggers a worker dispatch. The PS layer is intentionally thin:
  parameter binding + input validation + JSON args file construction +
  invocation of the Python orchestration core
  (tools/worker-runner/dispatch_entry.py).

  Scope (per step-8 design 2026-05-30, option γ):
    dispatch → runner → validate → report ONLY.

  Promotion + worktree cleanup are deferred to separate operator commands
  (forthcoming mission-promote-handoff.ps1 + mission-cleanup-worktree.ps1).

  Exit code contract (verbatim from dispatch_entry):
    0  success
    1  validation failure (Handoff cross-artifact §5.2 violation)
    2  runtime failure (runner crash, subprocess error)
    3+ operator error (bad args, missing spec, invalid construction)

.PARAMETER FeatureId
  Spec feature id, e.g. "F-001". Required.

.PARAMETER MilestoneId
  Spec milestone id, e.g. "M-1". Required. Used to filter contract assertions.

.PARAMETER Kind
  Worktree kind: 'mainline' or 'fanout'. Default: 'fanout'.

.PARAMETER ModelClass
  Model class per §4: 'coding-strong' | 'coding-fast' | 'narrow-validator' |
  'qa-validator'. Default: 'coding-strong'.

.PARAMETER ToolScope
  Comma-separated capability tags. Default: 'repo.read,worktree.write,test.run'.

.PARAMETER AssertionTargets
  Comma-separated assertion ids. If omitted, auto-derived from contract by
  feature_id + milestone_id (per the design review).

.PARAMETER CostCapUSD
  Per-worker cost ceiling (USD). Default: 100000.0 -- effectively unbounded
  for dev. Max-plan subscription enforces the 5-hour usage window
  separately; the cost cap is left high so it doesn't pre-empt dispatch
  runs that legitimately need many turns. Pass an explicit lower value
  to constrain a specific dispatch.

.PARAMETER WallclockMinutes
  Per-worker wallclock ceiling. Default: 90.

.PARAMETER DryRun
  Build + print the dispatch YAML; do not spawn the worker.

.PARAMETER OperatorNote
  Optional bounded addendum (ADR-007 decision 5). When supplied, the
  runner appends this text to the constructed task brief under a labeled
  `## Operator note (out-of-contract)` section -- additive to, never
  replacing, the artifact-derived objective. Use for rework guidance or
  focus hints; not reproducible from the contract, so it is recorded in
  the committed task-brief.md for audit.

.EXAMPLE
  PS> .\tools\mission-dispatch.ps1 -FeatureId F-001 -MilestoneId M-1 -DryRun

.EXAMPLE
  PS> .\tools\mission-dispatch.ps1 -FeatureId F-001 -MilestoneId M-1 `
        -ModelClass coding-strong -ToolScope 'repo.read,worktree.write,test.run'

.EXAMPLE
  PS> .\tools\mission-dispatch.ps1 -FeatureId F-001 -MilestoneId M-1 `
        -OperatorNote 'Prior worker stubbed the migration; complete it.'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FeatureId,

    [Parameter(Mandatory = $true)]
    [string]$MilestoneId,

    [ValidateSet('mainline', 'fanout')]
    [string]$Kind = 'fanout',

    [ValidateSet('coding-strong', 'coding-fast', 'narrow-validator', 'qa-validator')]
    [string]$ModelClass = 'coding-strong',

    [string]$ToolScope = 'repo.read,worktree.write,test.run',

    [string]$AssertionTargets = '',

    [double]$CostCapUSD = 100000.0,

    [int]$WallclockMinutes = 90,

    [switch]$DryRun,

    [string]$OperatorNote = ''
)

$ErrorActionPreference = 'Stop'

# ----- Resolve project root + verify mission state -----
$projectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$missionFile = Join-Path $projectRoot ".mission\mission.yaml"
if (-not (Test-Path $missionFile)) {
    Write-Error "mission.yaml not found at $missionFile"
    exit 3
}
$missionContent = [System.IO.File]::ReadAllText($missionFile)
if ($missionContent -notmatch '(?m)^state:\s*Executing\s*$') {
    Write-Error "Mission.state is not 'Executing' -- refusing to dispatch."
    exit 3
}

# ----- Resolve Python interpreter + dispatch_entry -----
$venvPython = Join-Path $projectRoot "tools\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Error "Framework venv Python not found at $venvPython. Run 'uv sync' first."
    exit 3
}
$dispatchEntry = Join-Path $projectRoot "tools\worker-runner\dispatch_entry.py"
if (-not (Test-Path $dispatchEntry)) {
    Write-Error "dispatch_entry.py not found at $dispatchEntry"
    exit 3
}

# ----- Build args JSON -----
$toolScopeList = $ToolScope -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$assertionTargetsValue = $null
if (-not [string]::IsNullOrWhiteSpace($AssertionTargets)) {
    $assertionTargetsValue = @($AssertionTargets -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

$operatorNoteValue = $null
if (-not [string]::IsNullOrWhiteSpace($OperatorNote)) {
    $operatorNoteValue = $OperatorNote
}

$argsDoc = [ordered]@{
    feature_id           = $FeatureId
    milestone_id         = $MilestoneId
    kind                 = $Kind
    model_class          = $ModelClass
    tool_scope           = @($toolScopeList)
    assertion_targets    = $assertionTargetsValue
    cost_cap_usd         = $CostCapUSD
    wallclock_cap_minutes = $WallclockMinutes
    dry_run              = [bool]$DryRun
    project_root         = $projectRoot
    operator_note        = $operatorNoteValue
}

# Write to a temp JSON file (avoids shell quoting issues).
$argsJsonPath = [System.IO.Path]::GetTempFileName()
$argsJsonPath = [System.IO.Path]::ChangeExtension($argsJsonPath, '.json')
$argsJson = $argsDoc | ConvertTo-Json -Depth 10 -Compress
[System.IO.File]::WriteAllText($argsJsonPath, $argsJson)

try {
    # ----- Invoke Python orchestration -----
    Write-Host "Dispatching worker against $FeatureId / $MilestoneId..." -ForegroundColor Cyan
    & $venvPython $dispatchEntry $argsJsonPath
    $rc = $LASTEXITCODE

    # Propagate exit code per the step-8 contract.
    switch ($rc) {
        0 { Write-Host "Dispatch complete: handoff valid." -ForegroundColor Green }
        1 { Write-Host "Dispatch complete: handoff INVALID (validation failure)." -ForegroundColor Yellow }
        2 { Write-Host "Dispatch FAILED: runtime error." -ForegroundColor Red }
        default { Write-Host "Dispatch FAILED: operator error (exit $rc)." -ForegroundColor Red }
    }
    exit $rc
}
finally {
    Remove-Item $argsJsonPath -ErrorAction SilentlyContinue
}
