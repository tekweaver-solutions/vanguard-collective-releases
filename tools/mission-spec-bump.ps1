#Requires -Version 5.1
<#
.SYNOPSIS
  mission-spec-bump (A-117 / C5) -- the composable spec-version-chain primitive's operator surface.
  Produces the 5-file lockstep: v(NNN+1).yaml = vNNN + the 3 version-metadata lines + an operator-
  authored body record; mission.yaml current_spec_version++; spec/current.txt; the amendment +
  ledger. Atomic, with rollback. Oracle: any AM commit's 5-file bump.

.DESCRIPTION
  This is the operator-facing form of the primitive (the standalone "record-append" bump used by
  ratify/accept). The SAME mechanical core (Invoke-SpecBump in mission-lib.ps1) is CALLED directly,
  in-process, by close-milestone (A-118) + reclose (A-119) in M-11 -- which pass a status-flip /
  completion transform instead of a record-append. Scaffold-not-author: the operator authors the
  amendment file + the body record + the ledger content (the prose); this command does the mechanical
  lockstep + the atomic commit. Append-not-rewrite (A-121): the prior vNNN is never touched.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AmendmentId,        # e.g. AM-NNN -- the amendment file must already exist (operator-authored)
    [Parameter(Mandatory)][string]$RecordFile,         # the spec-body record to insert after the metadata (operator prose)
    [Parameter(Mandatory)][string]$LedgerContentFile,  # operator-authored ledger content
    [string]$LedgerId,
    [string[]]$LedgerTags = @('spec-bump','lockstep','framework'),
    [string]$CommitSubject,
    [switch]$NoCommit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')
$root = Get-MissionRoot
$missionFile = Join-Path $root ".mission\mission.yaml"

# Resolve the operator-authored amendment FIRST -- it is a SANCTIONED bump INPUT (corpus oracle:
# the amendment is a NEW uncommitted file bundled in the bump commit). The CLI never authors
# the amendment prose; it requires the file to exist (operator-authored) and BUNDLES it.
$amFiles = @(Get-ChildItem -Path (Join-Path $root ".mission\amendments") -Filter "$AmendmentId-*.yaml" -ErrorAction SilentlyContinue)
if ($amFiles.Count -ne 1) { Stop-WithError "expected exactly one amendment file '$AmendmentId-*.yaml', found $($amFiles.Count)." }
$amRel = ".mission/amendments/$($amFiles[0].Name)"

# A-126: refuse a dirty tree -- but EXEMPT the sanctioned amendment input (it is uncommitted by design,
# to be committed by THIS bump). Any OTHER uncommitted path is still stray drift -> refused.
if (-not $NoCommit) { Assert-CleanWorkingTree -Root $root -AllowPaths @($amRel) }
Assert-MissionState -MissionFile $missionFile -Expected 'Reworking'  # A-130

if (-not (Test-Path $RecordFile))        { Stop-WithError "record file not found: $RecordFile" }
if (-not (Test-Path $LedgerContentFile)) { Stop-WithError "ledger content file not found: $LedgerContentFile" }

$record = [System.IO.File]::ReadAllText($RecordFile)

# the body change: insert the operator's record immediately after the (already-updated)
# created_from_amendment metadata line, mirroring the accepted-unbound / bound record corpus shape.
$bodyTransform = {
    param($text)
    $eol = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $rec = ($record -replace "`r`n", "`n") -replace "`n", $eol      # normalise the record to the file EOL
    [regex]::Replace(
        $text,
        '(?m)^(created_from_amendment:\s*\S+\s*)$',
        { param($m) "$($m.Groups[1].Value)$eol$eol$rec" },
        1)
}.GetNewClosure()

$result = Invoke-SpecBump -Root $root -AmendmentId $AmendmentId -BodyTransform $bodyTransform   # A-117/A-121/A-122

# ledger entry (operator content; scaffolded envelope)
if (-not $LedgerId) { $LedgerId = "ledger-decision-$($AmendmentId.ToLower())-spec-bump-$($result.OldName)-to-$($result.NewName)" }
$content = [System.IO.File]::ReadAllText($LedgerContentFile)
$entry = [ordered]@{
    id = $LedgerId; created_at = (Get-UtcStamp); created_by = 'claude-code:orchestrator-guide'
    ts = (Get-UtcStamp); author = 'claude-code:orchestrator-guide'; type = 'decision'; scope = 'framework'
    scope_ref = $amRel; content = $content; source_trace_id = $null; supersedes = $null; tags = $LedgerTags
}
Add-LedgerEntry -Root $root -Entry $entry

if (-not $NoCommit) {
    if (-not $CommitSubject) { $CommitSubject = "spec-bump: $($result.OldName) -> $($result.NewName) ($AmendmentId)" }
    $body = "$CommitSubject`r`n`r`nLockstep spec bump via $AmendmentId.`r`n"
    $msg = New-CommitMessageFile -Root $root -Body $body
    # ONE logical unit (A-124), reproducing the corpus 5-file bump: amendment + new vNNN +
    # current.txt + mission.yaml + ledger. On a forced mid-op failure the rollback restores to the pre-op
    # SHA (A-123) -- the uncommitted amendment is correctly wiped with the half-bump (NO partial state).
    # The amendment is exempt only from the clean-tree GATE (A-126, -AllowPaths), NOT from the rollback.
    $paths = @($amRel, ".mission/spec/$($result.NewName).yaml", '.mission/spec/current.txt', '.mission/mission.yaml', '.mission/ledger/entries.jsonl')
    Invoke-AtomicCommit -Root $root -Paths $paths -MessageFile $msg | Out-Null
}
Write-Host "mission spec-bump: done ($($result.OldName) -> $($result.NewName))" -ForegroundColor Cyan
