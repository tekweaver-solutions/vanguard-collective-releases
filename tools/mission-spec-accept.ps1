<#
.SYNOPSIS
    Phase 5 ceremony: promote accepted proposals to committed spec + contract,
    enforce three hard gates (ADR-008, ADR-022, ADR-024), transition mission
    state to Executing.

.DESCRIPTION
    This is the hard gate from ADR-008. It is irreversible by design:
    promoted spec and contract are moved (not copied) from proposals/ into
    the committed spec/ and contract/assertions/ directories, and the
    mission state machine transitions Planning -> Executing.

    The four hard gates verified at the script level:

      Gate 1 (ADR-008 spec-acceptance):
        Spec proposal exists; contract proposals exist; mission state is
        Planning; current_spec_version is null; operator has typed -Confirm.

      Gate 2 (ADR-022 architecture-validated):
        Architecture artifacts exist (.mission/architecture/c4/model.c4 +
        view files; .mission/architecture/mermaid/; .mission/architecture/ui/);
        operator has typed -ArchitectureValidated to attest a Docker-viewer
        pass was performed. Per the ADR-022 amendment, the LikeC4 Docker
        viewer is the parser-validation oracle; this script does NOT run the
        viewer itself (rendering is external) -- the operator attestation IS
        the gate.

      Gate 3 (ADR-024 tech-stack-reconciled):
        tech-stack-NNN.md exists for the proposal version; tech-stack
        designer-flag footer is RESOLVED (empty); §4 pending-client items
        all marked CLOSED or RESOLVED; tech_stack field in v009.yaml is
        populated.

      Gate 4 (ADR-025 runbook-validated):
        Runbook scaffolding exists (.mission/runbook/_schema.md,
        .mission/runbook/INDEX.md, .mission/runbook/quickstart-L1.md);
        operator has typed -RunbookValidated to attest a spot-check of
        sample entries was performed. Parallel in shape to Gate 2: the
        script checks artifacts exist; the operator attests to content
        quality. Per A-081's mandate this gate runs at acceptance time,
        not at CI time alone -- it makes ADR-025 a hard gate, same family
        as ADR-022's architecture-artifact gate.

    All four gates must pass before any filesystem mutation occurs.
    The script performs preflight checks (§Preflight), runs the four gates
    in order (§Gate 1 / §Gate 2 / §Gate 3 / §Gate 4), then performs the
    atomic acceptance sequence (§Acceptance):

      1. Move spec proposal to .mission/spec/<version>.yaml
      2. Update .mission/spec/current.txt with the version number
      3. Move every contract proposal A-NNN.yaml to .mission/contract/assertions/
      4. Update Mission.current_spec_version and transition state
         Planning -> Executing in .mission/mission.yaml
      5. git add + git commit (single atomic commit)

    On any failure during the acceptance sequence, the script attempts
    rollback via `git reset --hard <pre-acceptance-sha>` and reports the
    state. The operator can re-run after correction.

    Per ADR-015: MCP tools (.mission/.../config/mcp-tools.yaml) are
    accepted separately by the operator committing the file from
    proposals/ to config/ and installing servers manually. This script
    does NOT touch mcp-tools.yaml -- that ceremony already happened or
    has not happened, but is orthogonal to spec acceptance.

.PARAMETER ProposalVersion
    The proposal version to accept (e.g. "v009", "v010"). Must match an
    existing .mission/spec/proposals/<version>.yaml file. Required.

.PARAMETER Confirm
    Mandatory flag confirming the operator intends to promote this version
    to the committed spec. Without -Confirm the script refuses to proceed.
    This is the deliberate-ceremony requirement from the original bootstrap
    doc (Phase 5 step 1).

.PARAMETER ArchitectureValidated
    Mandatory flag confirming the operator has run the LikeC4 Docker viewer
    pass and that all views render parser-clean (no Invalid / Could not
    resolve / empty-actors-array errors at startup). The ADR-022 amendment
    requires parser validation as a precondition; this flag is the operator
    attestation.

.PARAMETER RunbookValidated
    Mandatory flag confirming the operator has spot-checked sample runbook
    entries (.mission/runbook/<container_id>.md) for content quality, per
    ADR-025. Parallel in shape to -ArchitectureValidated: the script checks
    that artifacts exist; the operator attests they're substantive. Without
    -RunbookValidated the script refuses to proceed.

.PARAMETER DryRun
    Optional. Run all preflight checks and three gates, report verdicts,
    but do NOT mutate the filesystem or commit. Useful for verifying gate
    state before the real run.

.EXAMPLE
    .\tools\mission-spec-accept.ps1 -ProposalVersion v010 -Confirm -ArchitectureValidated -RunbookValidated

    Accepts v010 as the committed spec and transitions mission state to
    Executing. All three attestation flags required.

.EXAMPLE
    .\tools\mission-spec-accept.ps1 -ProposalVersion v010 -Confirm -ArchitectureValidated -RunbookValidated -DryRun

    Runs all four gates against v010 and reports verdicts without
    mutating anything. Recommended dry-run before the real acceptance.

.NOTES
    Per ADR-020: this script does NOT trust agent tool-dispatch claims for
    its filesystem state -- it uses native Get-ChildItem / Test-Path / git
    commands and reads file contents directly.

    Per ADR-021: the acceptance is a single atomic commit, not multiple
    incremental commits. The rationale is that Phase 5 acceptance is by
    definition a "promote everything together or nothing" operation; partial
    promotion would leave the mission in an inconsistent state. Disconnect-
    recovery is supported via the pre-acceptance SHA captured at the start.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^v\d{3}$')]
    [string]$ProposalVersion,

    [Parameter(Mandatory=$true)]
    [switch]$Confirm,

    [Parameter(Mandatory=$false)]
    [switch]$ArchitectureValidated,

    [Parameter(Mandatory=$false)]
    [switch]$RunbookValidated,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ====================================================================
# §Helpers
# ====================================================================

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ====" -ForegroundColor Cyan
}

function Write-Pass {
    param([string]$Msg)
    Write-Host "  [PASS] $Msg" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Msg)
    Write-Host "  [FAIL] $Msg" -ForegroundColor Red
}

function Write-Info {
    param([string]$Msg)
    Write-Host "  [INFO] $Msg" -ForegroundColor Gray
}

function Stop-WithError {
    param([string]$Msg)
    Write-Host ""
    Write-Host "ACCEPTANCE ABORTED: $Msg" -ForegroundColor Red
    Write-Host "Filesystem is unchanged. Mission state is unchanged." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

function Assert-RepoRoot {
    # Per ADR-020: verify filesystem state, do not trust caller's CWD.
    if (-not (Test-Path '.git' -PathType Container)) {
        Stop-WithError "Not in a git repository root. cd to the mission repository root and re-run."
    }
    if (-not (Test-Path '.mission' -PathType Container)) {
        Stop-WithError "No .mission/ directory found. This script must run from the mission monorepo root."
    }
}

function Assert-CleanGitTree {
    # =============================================================================================
    # THIS GATE CALLS THE A-126 PREDICATE. IT NO LONGER CARRIES ONE OF ITS OWN.
    # =============================================================================================
    # WHAT STOOD HERE. A code-constant exemption list over `git status --porcelain`: '?? .claude/',
    # '?? .mission-runtime/', and the forms '?? .mission/evidence/session-',
    # '?? .mission/evidence/' and '?? .mission/gates/'. Status-aware but PREFIX-BLIND -- it tolerated
    # the whole untracked evidence plane and the whole untracked gates plane, and no mission could
    # narrow it -- the sibling of the defect removed from
    # Assert-CleanWorkingTree in tools/mission-lib.ps1. After that cure the two clean-tree gates
    # DIVERGED; this is the other half.
    #
    # WHAT GOVERNS NOW. The SAME predicate, CALLED rather than restated: mission-lib.ps1 is
    # dot-sourced and Assert-CleanWorkingTree judges every porcelain line, status code included,
    # against `admitted_porcelain` in the mission's own mission.yaml, read through
    # tools/lam/lam-verify-admission.ps1. One reader of one declaration. Its fail-closed branches are
    # this gate's too: a failing git status REFUSES, an unreadable or malformed declaration REFUSES,
    # and a mission that declares nothing has an admitted set that admits nothing. No -AllowPaths is
    # passed: spec-accept has no sanctioned uncommitted input, so the gate is strict. The root is the
    # current location, which Assert-RepoRoot has already required to be the repository root.
    #
    # WHY THE DOT-SOURCE IS INSIDE THIS FUNCTION. For the reason mission-lib.ps1 dot-sources its own
    # reader inside its gate: nothing is added to this script's scope, and a missing library fails
    # THIS GATE, closed, before any mutation. mission-lib.ps1 also defines Write-Pass, Write-Fail,
    # Write-Info and Stop-WithError. Dot-sourced here they SHADOW this script's definitions for the
    # duration of this call only (the nearer scope wins) and are gone when it returns, so every
    # later message in this script is still this script's own. The consequence, stated rather than
    # hidden: a dirty-tree refusal prints mission-lib's "ERROR: Working tree must be clean before a
    # lifecycle command ..." -- naming every offending porcelain line and the file the admitted set
    # is declared in -- and exits 1, instead of this script's ACCEPTANCE ABORTED banner. It is still
    # Preflight and still precedes every mutation.
    #
    # WHAT DROPPING '?? .claude/' AND '?? .mission-runtime/' COSTS. Those two lines are now judged by
    # the declaration like any other. In <project> (where this was measured) both directories are
    # gitignored and nothing under either is tracked, so git never emits either line and the change
    # is inert there. A mission repository that does NOT ignore them will see this gate refuse until
    # it ignores them or declares the prefix in admitted_porcelain.
    $missionLib = Join-Path $PSScriptRoot 'mission-lib.ps1'
    if (-not (Test-Path -LiteralPath $missionLib)) {
        Stop-WithError "the shared A-126 working-tree predicate is absent at $missionLib, so the mission's declared admitted set cannot be judged. A gate that cannot read its own rule does not pass the tree."
    }
    . $missionLib
    Assert-CleanWorkingTree -Root (Get-Location).ProviderPath
}

# ====================================================================
# §Preflight
# ====================================================================

Write-Section "Preflight"

Assert-RepoRoot
Write-Pass "In mission monorepo root."

Assert-CleanGitTree
Write-Pass "Working tree clean apart from the mission's declared admitted_porcelain (the A-126 predicate, shared with Assert-CleanWorkingTree)."

$preAcceptanceSha = (git rev-parse HEAD).Trim()
Write-Info "Pre-acceptance HEAD: $preAcceptanceSha"

if ($DryRun) {
    Write-Info "DRY-RUN mode: no filesystem mutations will occur."
}

# ====================================================================
# Draft-first: the first spec version, accepted from draft
# ====================================================================
# mission.ps1 init writes the first spec IN PLACE -- .mission/spec/v001.yaml with state: draft, and
# spec/current.txt naming v001 -- and no proposals/. The Phase 5 path below promotes a PROPOSAL and
# moves the mission to Executing; that is not this. This branch is taken only for -ProposalVersion
# v001 when spec/proposals/v001.yaml does not exist and spec/v001.yaml does, and once taken it never
# falls through to Phase 5: it accepts the draft, or refuses with nothing written. It accepts only
# when spec/ holds exactly one .yaml file, v001.yaml; current.txt names v001; v001.yaml has exactly
# one column-0 state: line and it reads draft; mission.yaml has exactly one current_spec_version
# line and it reads null; the ledger holds no entry of this acceptance's id; -Confirm is given.
#
# It then writes, and nothing else: the value of v001.yaml's state: line, draft -> accepted (every
# other byte of the file kept); the value of mission.yaml's current_spec_version, null -> 1
# (Mission.state is NOT touched: accepting the first draft is not the Phase 5 transition); one
# ledger entry through mission-lib's own writer; and it commits those three paths as one commit
# (mission-lib's Invoke-AtomicCommit, the message file under %TEMP%, never in the project). The
# amendment chain is untouched: no amendment is written, and no previous_version or
# created_from_amendment line is added or changed. -ArchitectureValidated and -RunbookValidated are
# not asked for here; the Phase 5 path below still refuses without them. -DryRun reports and writes
# nothing. On a failure after the first write, the tree is reset to the pre-acceptance HEAD, as the
# Phase 5 path does (the clean-tree gate above has already required a clean tree).
function Invoke-DraftFirstAccept {
    param([string]$Root, [string]$PreSha)
    $specDir     = Join-Path $Root '.mission\spec'
    $draftPath   = Join-Path $specDir 'v001.yaml'
    $currentPath = Join-Path $specDir 'current.txt'
    $missionPath = Join-Path $Root '.mission\mission.yaml'
    $ledgerPath  = Join-Path $Root '.mission\ledger\entries.jsonl'
    $ledgerId    = 'ledger-decision-spec-accept-v001-from-draft'

    $refusals = New-Object System.Collections.Generic.List[string]
    $yamls = @(Get-ChildItem -LiteralPath $specDir -File -Filter '*.yaml' | ForEach-Object { $_.Name })
    if (($yamls.Count -ne 1) -or ($yamls[0] -cne 'v001.yaml')) {
        $refusals.Add("spec/ must hold exactly one version file, v001.yaml; it holds $($yamls.Count): $($yamls -join ', ')")
    }
    $current = if (Test-Path -LiteralPath $currentPath -PathType Leaf) { ([System.IO.File]::ReadAllText($currentPath)).Trim() } else { '<absent>' }
    if ($current -cne 'v001') { $refusals.Add("spec/current.txt must name v001; it reads '$current'") }
    $draftBytes = [System.IO.File]::ReadAllBytes($draftPath)
    $draftBom   = ($draftBytes.Length -ge 3) -and ($draftBytes[0] -eq 0xEF) -and ($draftBytes[1] -eq 0xBB) -and ($draftBytes[2] -eq 0xBF)
    $draftText  = [System.IO.File]::ReadAllText($draftPath)
    $states = @([regex]::Matches($draftText, '(?m)^state:[ \t]*([^\s#]*)'))
    if ($states.Count -ne 1) { $refusals.Add("spec/v001.yaml must have exactly one column-0 state: line; it has $($states.Count)") }
    elseif ($states[0].Groups[1].Value -cne 'draft') { $refusals.Add("spec/v001.yaml is not a draft: its state: line reads '$($states[0].Groups[1].Value)' -- only a draft is accepted here") }
    if (-not (Test-Path -LiteralPath $missionPath -PathType Leaf)) { $refusals.Add("the mission record $missionPath is missing") }
    else {
        $missionText = [System.IO.File]::ReadAllText($missionPath)
        $versions = @([regex]::Matches($missionText, '(?m)^current_spec_version:[ \t]*([^\s#]*)'))
        if ($versions.Count -ne 1) { $refusals.Add("mission.yaml must have exactly one current_spec_version line; it has $($versions.Count)") }
        elseif ($versions[0].Groups[1].Value -cne 'null') { $refusals.Add("mission.yaml's current_spec_version reads '$($versions[0].Groups[1].Value)', not null -- a spec has already been accepted") }
    }
    if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) { $refusals.Add("the ledger $ledgerPath is missing") }
    elseif ([System.IO.File]::ReadAllText($ledgerPath).Contains('"id":"' + $ledgerId + '"')) { $refusals.Add("the ledger already holds an entry $ledgerId") }
    if (-not $Confirm) { $refusals.Add('-Confirm is required: accepting the first spec is a ceremony') }

    if ($refusals.Count -gt 0) {
        foreach ($r in $refusals) { Write-Fail $r }
        Stop-WithError "spec v001 is not accepted from draft ($($refusals.Count) refusal(s) above)."
    }
    Write-Pass "spec/ holds v001.yaml alone; current.txt names v001; its one state: line reads draft; current_spec_version is null; -Confirm given."
    if ($DryRun) {
        Write-Host ""
        Write-Host "DRY-RUN: spec v001 would be accepted from draft. No filesystem mutations performed." -ForegroundColor Green
        exit 0
    }

    try {
        . (Join-Path $PSScriptRoot 'mission-lib.ps1')
        $stamp = Get-UtcStamp
        [System.IO.File]::WriteAllText($draftPath, (Set-MissionFieldValue -Text $draftText -Key 'state' -Value 'accepted'), (New-Object System.Text.UTF8Encoding($draftBom)))
        Write-Pass "spec/v001.yaml state: draft -> accepted"
        $missionBytes = [System.IO.File]::ReadAllBytes($missionPath)
        $missionBom = ($missionBytes.Length -ge 3) -and ($missionBytes[0] -eq 0xEF) -and ($missionBytes[1] -eq 0xBB) -and ($missionBytes[2] -eq 0xBF)
        [System.IO.File]::WriteAllText($missionPath, (Set-MissionFieldValue -Text $missionText -Key 'current_spec_version' -Value '1'), (New-Object System.Text.UTF8Encoding($missionBom)))
        Write-Pass "mission.yaml current_spec_version: null -> 1 (Mission.state unchanged)"
        $entry = [ordered]@{
            id = $ledgerId; created_at = $stamp; created_by = 'mission-spec-accept.ps1'
            ts = $stamp; author = 'operator'; type = 'decision'; scope = 'mission'
            scope_ref = '.mission/spec/v001.yaml'
            content = 'spec v001 accepted from draft: its state from draft to accepted, current_spec_version from null to 1; the first version, so no amendment, and Mission.state unchanged'
            source_trace_id = $null; supersedes = $null; tags = @('spec-accept', 'draft-first')
        }
        Add-LedgerEntry -Root $Root -Entry $entry
        $msgFile = Join-Path $env:TEMP ('spec-accept-msg-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
        [System.IO.File]::WriteAllText($msgFile, "Spec v001 accepted from draft: state draft -> accepted; current_spec_version null -> 1; mission state unchanged`n")
        try { $newSha = Invoke-AtomicCommit -Root $Root -Paths @('.mission/spec/v001.yaml', '.mission/mission.yaml', '.mission/ledger/entries.jsonl') -MessageFile $msgFile }
        finally { Remove-Item -LiteralPath $msgFile -Force -ErrorAction SilentlyContinue }
    }
    catch {
        Write-Host ""
        Write-Host "ACCEPTANCE FAILED mid-sequence: $($_.Exception.Message)" -ForegroundColor Red
        & git -C $Root reset --hard $PreSha 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "Rolled back to the pre-acceptance HEAD $PreSha." -ForegroundColor Yellow }
        else { Write-Host "ROLLBACK FAILED. Manual recovery required; the pre-acceptance HEAD was $PreSha." -ForegroundColor Red }
        exit 1
    }
    # UI-1 S1 (ADR-045): one spec_bumped line -- no version before the draft, so from_version is null, and no
    # amendment drives a first acceptance. (Invoke-AtomicCommit above has already offered the snapshot.)
    Invoke-MissionLibTelemetry -Root $Root -Verb 'spec-accept' -Events @(@{ Kind = 'spec_bumped'; SourcePath = '.mission/spec/v001.yaml'
        Payload = [ordered]@{ from_version = $null; to_version = 'v001'; amendment_id = $null } })
    Write-Section "Spec v001 accepted from draft"
    Write-Host "  Committed spec:     .mission/spec/v001.yaml (state: accepted)" -ForegroundColor Green
    Write-Host "  Acceptance commit:  $newSha" -ForegroundColor Green
    exit 0
}
if (($ProposalVersion -ceq 'v001') -and (-not (Test-Path -LiteralPath '.mission\spec\proposals\v001.yaml')) -and (Test-Path -LiteralPath '.mission\spec\v001.yaml' -PathType Leaf)) {
    Write-Section "Draft-first: spec v001, accepted from draft"
    Invoke-DraftFirstAccept -Root (Get-Location).ProviderPath -PreSha $preAcceptanceSha
}

# Confirmation flags. Both are mandatory parameters so CmdletBinding catches
# absence at parse time, but defensive checks here for explicitness.
if (-not $Confirm) {
    Stop-WithError "-Confirm flag required. This is the Phase 5 ceremony; promotion is irreversible."
}
if (-not $ArchitectureValidated) {
    Stop-WithError "-ArchitectureValidated flag required per ADR-022 amendment. Run the LikeC4 Docker viewer pass and confirm all views render parser-clean before re-running with this flag."
}
if (-not $RunbookValidated) {
    Stop-WithError "-RunbookValidated flag required per ADR-025. Spot-check sample runbook entries (e.g., two existing containers' entries under .mission/runbook/ and one new container's entry) for substantive L1-actionable content before re-running with this flag."
}
Write-Pass "All three operator-attestation flags present (-Confirm, -ArchitectureValidated, -RunbookValidated)."

# ====================================================================
# §Gate 1: ADR-008 spec-acceptance
# ====================================================================

Write-Section "Gate 1: ADR-008 spec-acceptance"

# 1.1 Spec proposal file exists.
$specProposalPath = ".mission\spec\proposals\$ProposalVersion.yaml"
if (-not (Test-Path $specProposalPath -PathType Leaf)) {
    Write-Fail "Spec proposal not found: $specProposalPath"
    Stop-WithError "Spec proposal for $ProposalVersion does not exist. Available proposals: $(Get-ChildItem .mission\spec\proposals\v*.yaml -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)"
}
Write-Pass "Spec proposal exists: $specProposalPath"

# 1.2 Contract proposals directory exists and is non-empty.
$contractProposalsDir = ".mission\contract\proposals"
if (-not (Test-Path $contractProposalsDir -PathType Container)) {
    Stop-WithError "Contract proposals directory missing: $contractProposalsDir"
}
$contractProposals = Get-ChildItem "$contractProposalsDir\A-*.yaml" -ErrorAction SilentlyContinue
if (-not $contractProposals -or $contractProposals.Count -eq 0) {
    Stop-WithError "No contract proposal files (A-*.yaml) found in $contractProposalsDir"
}
Write-Pass "Contract proposals present: $($contractProposals.Count) assertion file(s)."

# 1.3 Verify mission.yaml state is Planning.
$missionYamlPath = ".mission\mission.yaml"
if (-not (Test-Path $missionYamlPath -PathType Leaf)) {
    Stop-WithError "Mission record missing: $missionYamlPath"
}
$missionContent = Get-Content $missionYamlPath -Raw

# Simple regex-based field reads. We deliberately do not pull in a YAML
# parser dependency for this single check; the mission.yaml shape is
# stable per expanded-schemas.md §1.
if ($missionContent -notmatch '(?m)^state:\s*Planning\s*$') {
    $currentStateMatch = [regex]::Match($missionContent, '(?m)^state:\s*(\S+)\s*$')
    $currentState = if ($currentStateMatch.Success) { $currentStateMatch.Groups[1].Value } else { "<unknown>" }
    Write-Fail "Mission.state is '$currentState', expected 'Planning'."
    Stop-WithError "Phase 5 acceptance requires Mission.state = Planning. Current state: $currentState"
}
Write-Pass "Mission.state = Planning (per .mission/mission.yaml)."

# 1.4 Verify current_spec_version is null (first acceptance) OR consistent.
# Per the schema, current_spec_version is null before first acceptance and an
# int after. For mission #1 first acceptance we expect null; for re-acceptance
# scenarios (not currently supported but reserved) we'd allow the prior version
# to be set. v1 of this script supports only the first-acceptance case.
if ($missionContent -match '(?m)^current_spec_version:\s*null\s*$') {
    Write-Pass "Mission.current_spec_version is null (first acceptance)."
} elseif ($missionContent -match '(?m)^current_spec_version:\s*(\d+)\s*$') {
    $existingVersion = $matches[1]
    Write-Fail "Mission.current_spec_version is already set to $existingVersion."
    Stop-WithError "This script accepts a first promotion (current_spec_version: null). Re-acceptance of a later version into an already-Executing mission is an amendment path, not a Phase 5 ceremony."
} else {
    Stop-WithError "Could not parse Mission.current_spec_version from $missionYamlPath."
}

Write-Pass "Gate 1 PASSED: ADR-008 spec-acceptance preconditions met."

# ====================================================================
# §Gate 2: ADR-022 architecture-validated
# ====================================================================

Write-Section "Gate 2: ADR-022 architecture-validated"

# 2.1 .mission/architecture/c4/ contains model.c4 + at least one view file.
$c4Dir = ".mission\architecture\c4"
if (-not (Test-Path $c4Dir -PathType Container)) {
    Stop-WithError "Architecture C4 directory missing: $c4Dir"
}
$modelFile = Join-Path $c4Dir "model.c4"
if (-not (Test-Path $modelFile -PathType Leaf)) {
    Stop-WithError "model.c4 missing from $c4Dir. Per the shared-model + view-only-files pattern (ADR-022 amendment), model.c4 is mandatory."
}
$viewFiles = Get-ChildItem "$c4Dir\*.c4" | Where-Object { $_.Name -ne 'model.c4' }
if ($viewFiles.Count -eq 0) {
    Stop-WithError "No view files (.c4 other than model.c4) found in $c4Dir."
}
Write-Pass "Architecture C4 layout valid: model.c4 + $($viewFiles.Count) view file(s)."

# 2.2 .mission/architecture/mermaid/ exists with at least one .md file.
$mermaidDir = ".mission\architecture\mermaid"
if (-not (Test-Path $mermaidDir -PathType Container)) {
    Stop-WithError "Architecture Mermaid directory missing: $mermaidDir"
}
$mermaidFiles = Get-ChildItem "$mermaidDir\*.md" -ErrorAction SilentlyContinue
if (-not $mermaidFiles -or $mermaidFiles.Count -eq 0) {
    Stop-WithError "No Mermaid files (.md) found in $mermaidDir."
}
Write-Pass "Architecture Mermaid layout valid: $($mermaidFiles.Count) file(s)."

# 2.3 .mission/architecture/ui/ exists with README.md.
$uiDir = ".mission\architecture\ui"
if (-not (Test-Path "$uiDir\README.md" -PathType Leaf)) {
    Stop-WithError "Architecture UI README missing: $uiDir\README.md (Figma-placeholder per the architecture-documentation skill)"
}
Write-Pass "Architecture UI placeholder present."

# 2.4 Operator attestation already verified at preflight via -ArchitectureValidated.
# Per ADR-022 amendment, the LikeC4 Docker viewer is the parser-validation
# oracle; this script does not run it. The operator's -ArchitectureValidated
# flag is the trusted attestation.
Write-Pass "Operator attestation of Docker-viewer pass recorded (-ArchitectureValidated)."

Write-Pass "Gate 2 PASSED: ADR-022 architecture artifacts present + operator attestation."

# ====================================================================
# §Gate 3: ADR-024 tech-stack-reconciled
# ====================================================================

Write-Section "Gate 3: ADR-024 tech-stack-reconciled"

# 3.1 tech-stack-<NNN>.md exists for this proposal version.
# Strip leading 'v' to match the doc naming convention (tech-stack-009.md, not tech-stack-v009.md).
$versionNumber = $ProposalVersion -replace '^v', ''
$techStackPath = ".mission\spec\proposals\tech-stack-$versionNumber.md"
if (-not (Test-Path $techStackPath -PathType Leaf)) {
    Stop-WithError "Tech-stack proposal not found: $techStackPath"
}
Write-Pass "Tech-stack proposal exists: $techStackPath"
$techStackContent = Get-Content $techStackPath -Raw

# 3.2 Designer-flag footer marked RESOLVED (empty residuals) or absent.
# The pattern across v007/v008/v009 is a "Designer flag for operator at
# Checkpoint NN" footer; resolved state is marked "RESOLVED" with no
# unresolved items beneath it. We accept either "RESOLVED" line or
# absence of the footer entirely (some early versions omitted it).
if ($techStackContent -match '(?im)^.*Designer flag.*:\s*$') {
    # Footer present -- check it's marked RESOLVED.
    if ($techStackContent -match '(?im)Designer flag.*\n.*RESOLVED') {
        Write-Pass "Tech-stack designer-flag footer marked RESOLVED."
    } else {
        Stop-WithError "Tech-stack designer-flag footer is present but not marked RESOLVED. Unresolved operator decisions block acceptance."
    }
} else {
    Write-Info "No designer-flag footer found in tech-stack -- treating as no outstanding designer flags."
}

# 3.3 §4 pending-client items all CLOSED or RESOLVED.
# Pattern: lines under §4 may say "PENDING", "CLOSED", "RESOLVED", or "OPEN".
# Any line containing PENDING or OPEN under §4 is a blocker.
$section4Match = [regex]::Match(
    $techStackContent,
    '(?ims)^##\s*4\.[^\n]*\n(.*?)(?=^##\s*\d+\.|^\-\-\-\s*$)'
)
if ($section4Match.Success) {
    $section4Body = $section4Match.Groups[1].Value
    $pendingLines = $section4Body -split "`n" | Where-Object {
        $_ -match '\b(PENDING|OPEN)\b' -and
        $_ -notmatch '\b(NOT PENDING|RESOLVED|CLOSED)\b'
    }
    if ($pendingLines) {
        Write-Fail "§4 of tech-stack contains unresolved PENDING / OPEN items:"
        $pendingLines | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
        Stop-WithError "All §4 items must be CLOSED or RESOLVED before Phase 5 acceptance."
    }
    Write-Pass "§4 pending-client items all CLOSED or RESOLVED."
} else {
    Write-Info "No §4 section found in tech-stack -- treating as no pending items."
}

# 3.4 Spec's tech_stack field is populated.
$specContent = Get-Content $specProposalPath -Raw
if ($specContent -notmatch '(?m)^tech_stack:\s*$') {
    Stop-WithError "Spec proposal $specProposalPath does not contain a 'tech_stack:' field. Per ADR-024, populated tech_stack is mandatory."
}
# Cheap non-emptiness check: at least one indented key under tech_stack.
$techStackBlockMatch = [regex]::Match(
    $specContent,
    '(?ms)^tech_stack:\s*\n((?:[ \t]+\S[^\n]*\n)+)'
)
if (-not $techStackBlockMatch.Success -or $techStackBlockMatch.Groups[1].Value.Trim() -eq '') {
    Stop-WithError "tech_stack field in $specProposalPath is empty. Populated tech_stack is mandatory per ADR-024."
}
Write-Pass "Spec proposal tech_stack field is populated."

Write-Pass "Gate 3 PASSED: ADR-024 tech-stack-reconciled."

# ====================================================================
# §Gate 4: ADR-025 runbook-validated
# ====================================================================

Write-Section "Gate 4: ADR-025 runbook-validated"

# 4.1 .mission/runbook/ directory exists.
$runbookDir = ".mission\runbook"
if (-not (Test-Path $runbookDir -PathType Container)) {
    Stop-WithError "Runbook directory missing: $runbookDir (required per ADR-025)."
}
Write-Pass "Runbook directory exists: $runbookDir"

# 4.2 Required scaffolding artifacts present: _schema.md, INDEX.md, quickstart-L1.md.
$requiredScaffolding = @('_schema.md', 'INDEX.md', 'quickstart-L1.md')
foreach ($scaffold in $requiredScaffolding) {
    $scaffoldPath = Join-Path $runbookDir $scaffold
    if (-not (Test-Path $scaffoldPath -PathType Leaf)) {
        Stop-WithError "Runbook scaffolding artifact missing: $scaffoldPath (required per ADR-025 + A-081)."
    }
}
Write-Pass "Runbook scaffolding present: _schema.md + INDEX.md + quickstart-L1.md."

# 4.3 At least one per-container entry exists (a runbook with only scaffolding is structurally
# empty -- the whole point of ADR-025 is per-container content). Excluding the scaffolding files,
# any other .md is a per-container entry.
$entryFiles = Get-ChildItem "$runbookDir\*.md" | Where-Object {
    $_.Name -notin $requiredScaffolding
}
if ($entryFiles.Count -eq 0) {
    Stop-WithError "No per-container runbook entries found in $runbookDir. ADR-025 requires one entry per container in containers.c4."
}
Write-Pass "Per-container runbook entries present: $($entryFiles.Count) entry file(s)."

# 4.4 INDEX.md links every entry file. A-081's orphan-detection property.
$indexContent = Get-Content (Join-Path $runbookDir "INDEX.md") -Raw
$missingFromIndex = @()
foreach ($entryFile in $entryFiles) {
    # Match a markdown link or bare reference to the entry filename.
    if ($indexContent -notmatch [regex]::Escape($entryFile.Name)) {
        $missingFromIndex += $entryFile.Name
    }
}
if ($missingFromIndex.Count -gt 0) {
    Write-Fail "Runbook entries not linked from INDEX.md:"
    $missingFromIndex | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    Stop-WithError "Every per-container runbook entry must be linked from INDEX.md (A-081 orphan-detection property)."
}
Write-Pass "INDEX.md links all $($entryFiles.Count) per-container entry file(s)."

# 4.5 Operator attestation already verified at preflight via -RunbookValidated.
# Per ADR-025, runbook content quality is operator-attested -- the script checks
# structure + presence; the operator attests substance.
Write-Pass "Operator attestation of runbook spot-check recorded (-RunbookValidated)."

Write-Pass "Gate 4 PASSED: ADR-025 runbook-validated."

# ====================================================================
# §Summary before acceptance
# ====================================================================

Write-Section "Summary"
Write-Host "  Proposal version:           $ProposalVersion"
Write-Host "  Spec proposal:              $specProposalPath"
Write-Host "  Contract proposals:         $($contractProposals.Count) assertion file(s)"
Write-Host "  Tech-stack:                 $techStackPath"
Write-Host "  Architecture C4 views:      $($viewFiles.Count) (+ model.c4)"
Write-Host "  Architecture Mermaid files: $($mermaidFiles.Count)"
Write-Host "  Runbook entries:            $($entryFiles.Count) per-container entry file(s)"
Write-Host "  Pre-acceptance SHA:         $preAcceptanceSha"

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY-RUN: all four gates passed. No filesystem mutations performed." -ForegroundColor Green
    Write-Host "Re-run without -DryRun to perform actual acceptance." -ForegroundColor Cyan
    exit 0
}

# ====================================================================
# §Acceptance
# ====================================================================

Write-Section "Acceptance (atomic)"
Write-Host "  Promoting $ProposalVersion to committed spec + contract..." -ForegroundColor Cyan

try {
    # Acceptance step 1: Move spec proposal to .mission/spec/<version>.yaml.
    $committedSpecPath = ".mission\spec\$ProposalVersion.yaml"
    if (Test-Path $committedSpecPath) {
        Stop-WithError "Committed spec already exists at $committedSpecPath. This script assumes a first-acceptance scenario."
    }
    Move-Item -Path $specProposalPath -Destination $committedSpecPath -Force
    Write-Pass "Spec moved: proposals/$ProposalVersion.yaml -> spec/$ProposalVersion.yaml"

    # Acceptance step 2: Update .mission/spec/current.txt.
    # Per the original bootstrap doc Phase 5 step 1 (symlink-alternative for Windows).
    $currentTxtPath = ".mission\spec\current.txt"
    Set-Content -Path $currentTxtPath -Value $ProposalVersion -NoNewline
    Write-Pass "Active spec version pointer updated: spec/current.txt = $ProposalVersion"

    # Acceptance step 3: Move contract proposals to .mission/contract/assertions/.
    $committedAssertionsDir = ".mission\contract\assertions"
    if (-not (Test-Path $committedAssertionsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $committedAssertionsDir -Force | Out-Null
        Write-Info "Created $committedAssertionsDir."
    }
    foreach ($proposalFile in $contractProposals) {
        $destPath = Join-Path $committedAssertionsDir $proposalFile.Name
        if (Test-Path $destPath) {
            Stop-WithError "Assertion already committed at $destPath. Aborting mid-acceptance; rollback follows."
        }
        Move-Item -Path $proposalFile.FullName -Destination $destPath -Force
    }
    Write-Pass "Contract moved: $($contractProposals.Count) assertion file(s) -> contract/assertions/"

    # Acceptance step 4: Update mission.yaml fields.
    # Two field updates: current_spec_version (null -> int) and state (Planning -> Executing).
    $newSpecVersionInt = [int]$versionNumber  # "009" -> 9
    $missionContent = Get-Content $missionYamlPath -Raw
    $missionContent = $missionContent -replace '(?m)^(current_spec_version:\s*)null\s*$', "`${1}$newSpecVersionInt"
    $missionContent = $missionContent -replace '(?m)^(state:\s*)Planning\s*$', '${1}Executing'
    Set-Content -Path $missionYamlPath -Value $missionContent -NoNewline
    Write-Pass "Mission state transitioned: Planning -> Executing (current_spec_version = $newSpecVersionInt)"

    # Acceptance step 5: git add + git commit (single atomic commit per ADR-021).
    git add .mission\ 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed."
    }
    $commitMessage = "Design accepted: spec $ProposalVersion promoted; mission state Planning -> Executing (ADR-008 + ADR-022 + ADR-024 + ADR-025 gates passed)"
    git commit -m $commitMessage 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed."
    }
    $newSha = (git rev-parse HEAD).Trim()
    Write-Pass "Atomic acceptance commit: $newSha"

    # Per ADR-020: verify filesystem truth after the commit.
    if ($newSha -eq $preAcceptanceSha) {
        throw "git commit did not advance HEAD (still at $preAcceptanceSha). Phantom-commit risk -- aborting."
    }

    # UI-1 S1 (ADR-045): one spec_bumped line (the first version, so from_version and amendment_id are null)
    # and the snapshot -- this path commits with git directly, not through Invoke-AtomicCommit.
    try {
        $tmA = Join-Path $PSScriptRoot 'lam\mission-telemetry.ps1'
        if (Test-Path -LiteralPath $tmA -PathType Leaf) {
            . $tmA
            Invoke-MissionTelemetry -Root (Get-Location).Path -Verb 'spec-accept' -Snapshot -Events @(@{ Kind = 'spec_bumped'; SourcePath = ($committedSpecPath -replace '\\', '/')
                Payload = [ordered]@{ from_version = $null; to_version = $ProposalVersion; amendment_id = $null } })
        }
    } catch { }

    Write-Section "Phase 5 acceptance COMPLETE"
    Write-Host "  Mission state:      Executing" -ForegroundColor Green
    Write-Host "  Committed spec:     $committedSpecPath" -ForegroundColor Green
    Write-Host "  Acceptance commit:  $newSha" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: the mission is now ready for execution-phase worker dispatch." -ForegroundColor Cyan
    Write-Host "Verify with:" -ForegroundColor Cyan
    Write-Host "  git log --oneline -5" -ForegroundColor Gray
    Write-Host "  git show --stat HEAD" -ForegroundColor Gray
}
catch {
    # Rollback. Per ADR-021 the acceptance is atomic; if any step failed,
    # roll the working tree back to the pre-acceptance SHA so the operator
    # can correct and re-run.
    Write-Host ""
    Write-Host "ACCEPTANCE FAILED mid-sequence: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Attempting rollback to pre-acceptance SHA: $preAcceptanceSha" -ForegroundColor Yellow

    git reset --hard $preAcceptanceSha 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        # Also reset any untracked moves (Move-Item is not git-tracked until add).
        git clean -fd .mission\ 2>&1 | Out-Null
        Write-Host "Rollback complete. Working tree restored to $preAcceptanceSha." -ForegroundColor Yellow
        Write-Host "Spec and contract proposals must be manually restored from git history if Move-Item left them in committed directories. Run:" -ForegroundColor Yellow
        Write-Host "  git status" -ForegroundColor Gray
        Write-Host "  git stash list" -ForegroundColor Gray
    } else {
        Write-Host "ROLLBACK FAILED. Manual recovery required." -ForegroundColor Red
        Write-Host "Pre-acceptance SHA was: $preAcceptanceSha" -ForegroundColor Red
        Write-Host "Inspect: git status; git log --oneline -10" -ForegroundColor Red
    }
    exit 1
}
