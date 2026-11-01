#Requires -Version 5.1
<#
.SYNOPSIS
  Phase 4 (Design refinement) script. Assembles a fresh design-context
  blob from the previous proposal, the operator's feedback, and the
  prior design-notes. Does NOT change Mission.state -- still Planning.

.DESCRIPTION
  Per Section 6.1 of local-orchestrator-mode.md and Phase 4 of the
  bootstrap, each refinement iteration is a fresh designer instance
  reading committed artifacts. There is no conversation thread that
  lives across iterations.

  This script's job is the deterministic setup:
    - Verify the feedback file exists AND is committed to git.
    - Locate the most recent proposal version vNNN and its design-notes.
    - Concatenate (feedback + prior proposal + prior design-notes +
      inputs INDEX) into a single context blob at
      .mission-runtime/design-context-NNN.md (NNN = next version).
    - Print instructions for what the designer should produce next.

  The designer (an LLM) then drafts v(NNN) into proposals/.

  Hard gates:
    - Mission.state must be 'Planning' (refinement happens between
      Phase 3 and Phase 5; pre-Phase-3 or post-acceptance is rejected).
    - .mission/spec/proposals/vNNN.yaml must exist (we need something
      to refine FROM).
    - FeedbackFile must be tracked by git (committed) -- raw uncommitted
      feedback is not a typed input.

.PARAMETER FeedbackFile
  Path to the feedback artifact, typically
  .mission/inputs/feedback-NNN.md. May be absolute or relative to the
  mission root.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FeedbackFile
)

$ErrorActionPreference = 'Stop'

# ----- Resolve mission root -----
$root        = (Get-Item $PSScriptRoot).Parent.FullName
$missionFile = Join-Path $root ".mission\mission.yaml"
$specDir     = Join-Path $root ".mission\spec\proposals"
$inputsDir   = Join-Path $root ".mission\inputs"
$runtimeDir  = Join-Path $root ".mission-runtime"

if (-not (Test-Path $missionFile)) {
    Write-Error "Mission file not found: $missionFile"
    exit 1
}

# ----- Resolve FeedbackFile (absolute or mission-root-relative) -----
$fbFull = if ([System.IO.Path]::IsPathRooted($FeedbackFile)) {
    $FeedbackFile
} else {
    Join-Path $root $FeedbackFile
}
if (-not (Test-Path $fbFull)) {
    Write-Error "FeedbackFile not found: $fbFull"
    exit 1
}

# ----- State gate: must be Planning -----
$missionContent = [System.IO.File]::ReadAllText($missionFile)
if ($missionContent -notmatch '(?m)^state:\s*Planning\s*$') {
    Write-Error "Mission.state is not 'Planning' -- refinement only runs between Phase 3 start and Phase 5 acceptance."
    exit 1
}

# ----- Verify feedback file is committed to git -----
Push-Location $root
try {
    $relFb = Resolve-Path -Relative -Path $fbFull
    & git ls-files --error-unmatch $relFb > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Error "FeedbackFile is not tracked by git: $relFb. Feedback is a typed input -- commit it before running refine."
        exit 1
    }
} finally {
    Pop-Location
}

# ----- Find the highest existing proposal version -----
$proposalRegex = '^v(\d{3})\.yaml$'
$existing = Get-ChildItem -Path $specDir -Filter "v*.yaml" -File |
    Where-Object { $_.Name -match $proposalRegex } |
    ForEach-Object { [int]$Matches[1] } |
    Sort-Object -Descending

if ($existing.Count -eq 0) {
    Write-Error "No prior proposal vNNN.yaml found in $specDir. Refinement requires something to refine from."
    exit 1
}

$priorN = $existing[0]
$nextN = $priorN + 1
$priorTag = "v{0:000}" -f $priorN
$nextTag  = "v{0:000}" -f $nextN

Write-Host "Prior proposal: $priorTag. Drafting $nextTag." -ForegroundColor Green

# ----- Locate prior artifacts -----
$priorSpec       = Join-Path $specDir "$priorTag.yaml"
$priorDesignNote = Join-Path $specDir ("design-notes-{0:000}.md" -f $priorN)
$priorOpReview   = Join-Path $specDir ("operator-review-{0:000}.md" -f $priorN)
$indexFile       = Join-Path $inputsDir "INDEX.md"

# ----- Assemble context blob -----
if (-not (Test-Path $runtimeDir)) {
    New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
}
$contextFile = Join-Path $runtimeDir ("design-context-{0:000}.md" -f $nextN)

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Design refinement context -- target $nextTag (refining from $priorTag)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Assembled by tools/mission-design-refine.ps1 at $now.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Refinement reads (in this order): feedback, prior proposal, prior design notes, prior operator review, inputs INDEX. Each iteration is a fresh designer instance -- no conversation thread spans iterations.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Block 1: feedback (most important)
[void]$sb.AppendLine("## Feedback (typed input)")
[void]$sb.AppendLine("Source: $relFb")
[void]$sb.AppendLine("")
[void]$sb.AppendLine([System.IO.File]::ReadAllText($fbFull))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Block 2: prior proposal
[void]$sb.AppendLine("## Prior proposal: $priorTag")
[void]$sb.AppendLine("")
[void]$sb.AppendLine('```yaml')
[void]$sb.AppendLine([System.IO.File]::ReadAllText($priorSpec))
[void]$sb.AppendLine('```')
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Block 3: prior design notes (if present)
if (Test-Path $priorDesignNote) {
    [void]$sb.AppendLine(("## Prior design notes: design-notes-{0:000}.md" -f $priorN))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine([System.IO.File]::ReadAllText($priorDesignNote))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
}

# Block 4: prior operator review (if present)
if (Test-Path $priorOpReview) {
    [void]$sb.AppendLine(("## Prior operator review: operator-review-{0:000}.md" -f $priorN))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine([System.IO.File]::ReadAllText($priorOpReview))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
}

# Block 5: inputs INDEX
if (Test-Path $indexFile) {
    [void]$sb.AppendLine("## Current inputs INDEX.md (for context; full input files at .mission/inputs/)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine([System.IO.File]::ReadAllText($indexFile))
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
}

[System.IO.File]::WriteAllText($contextFile, $sb.ToString())
$sz = (Get-Item $contextFile).Length
Write-Host "Wrote refinement context: $contextFile ($sz bytes)" -ForegroundColor Green

# ----- Designer instructions -----
Write-Host ""
Write-Host "=== DESIGNER INSTRUCTIONS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "The designer (Claude Code in thinking-partner mode) should now read"
Write-Host "  $contextFile"
Write-Host "and produce, into .mission/spec/proposals/ + .mission/contract/proposals/:"
Write-Host ""
Write-Host "  - $nextTag.yaml                  (refined LivingSpec; do NOT minimize the diff)"
Write-Host "  - A-NNN.yaml                    (refined assertions; add/drop/rewrite as needed)"
Write-Host ("  - design-notes-{0:000}.md           (designer reasoning + open questions for $nextTag)" -f $nextN)
Write-Host ""
Write-Host "Then switch to operator hat and write:"
Write-Host ("  - operator-review-{0:000}.md" -f $nextN)
Write-Host ""
Write-Host "Mission.state remains 'Planning'; refinement does NOT auto-promote."
Write-Host "Acceptance happens at Phase 5 via mission-spec-accept.ps1 against $nextTag."
Write-Host ""
