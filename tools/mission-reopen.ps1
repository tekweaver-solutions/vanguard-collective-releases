#Requires -Version 5.1
<#
.SYNOPSIS
  mission-reopen (A-115 / C1) -- transition a Complete mission Complete -> Reworking per ADR-029:
  APPEND a REOPEN transition block (chained to the prior completion), flip state, PRESERVE
  completed_at (it changes only at reclose).

.DESCRIPTION
  Scaffold-not-author: the operator supplies -Reason; this command scaffolds the structural block
  (header + chain + the reason) -- it does NOT author the routing/rationale prose (the operator
  expands the block if richer prose is wanted). Append-not-rewrite (A-121): prior transition blocks
  are untouched; the new block is inserted immediately before `state:`. No spec bump (reopen changes
  no spec). Invariants inherited from mission-lib.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Reason,        # operator-supplied (scaffold-not-author the prose)
    [string]$Summary = 'reopen',                  # short block-header summary
    [string]$LedgerId,                            # optional; derived if omitted
    [Alias('ReN')][int]$ReopenNumber = 0,         # F-073 (M-56): reopen-matched number (authoritative); HALTS if it collides with sealed history. Required -- no silent maxN+1.
    [switch]$NoCommit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')
$root = Get-MissionRoot
$missionFile = Join-Path $root ".mission\mission.yaml"

if (-not $NoCommit) { Assert-CleanWorkingTree -Root $root }   # A-126
Assert-MissionState -MissionFile $missionFile -Expected 'Complete'   # A-130: reopen requires Complete

$text = [System.IO.File]::ReadAllText($missionFile)
$eol  = if ($text -match "`r`n") { "`r`n" } else { "`n" }

# F-073 (M-56): reopen-matched REOPEN number -- explicit -ReopenNumber is AUTHORITATIVE; the helper HALTS
# LOUD (REOPEN-NUMBER-MISMATCH + exit 1) on a number that collides with sealed history. Replaces the old
# `$reopenN = maxN + 1`, which misnumbers after a re-chartered cycle (REOPEN #19 had NO block on disk, so
# maxN+1 would emit #19 where the reopen-matched number was #20 -- the very misnumbering bug this fixes).
$reopenN = Resolve-ReopenMatchedNumber -MissionText $text -BlockKind 'REOPEN' -ExplicitNumber $ReopenNumber

# the prior completion being re-entered (PRESERVED through Reworking -- A-115)
if ($text -notmatch '(?m)^completed_at:\s*(\S+)\s*$') { Stop-WithError "completed_at not found in mission.yaml" }
$completedAt = $Matches[1]
$date = (Get-UtcStamp).Substring(0,10)
if (-not $LedgerId) { $LedgerId = "ledger-decision-mission-reopen-complete-to-reworking-reopen-$reopenN" }

# scaffold the REOPEN block (structural; the operator's reason embedded)
$blkLines = @(
    "#",
    "# --- REOPEN #$reopenN ($date) -- $Summary, per ADR-029 Complete -> Reworking ---",
    "# Reopened Complete -> Reworking on $date (operator-gated, never automated). REASON",
    "# (operator-supplied): $Reason",
    "# CHAIN (ADR-029): the prior completion being re-entered is $completedAt; per ADR-029 completed_at",
    "# STAYS at $completedAt through Reworking and is UPDATED only at the next Reworking -> Complete",
    "# reclose -- PRESERVED, not overwritten, here. Recorded in the ledger: $LedgerId. The prior",
    "# transition blocks ABOVE are sealed -- preserved unchanged; this block is APPENDED."
)
$block = ($blkLines -join $eol)

# A-121 append-not-rewrite + flip: insert the block immediately before `state: Complete`, flip to Reworking
$pattern = '(?m)^state:\s*Complete\s*$'
if ($text -notmatch $pattern) { Stop-WithError "could not find 'state: Complete' to transition." }
$replacement = "$block$eol" + "state: Reworking"
$newText = [regex]::Replace($text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
[System.IO.File]::WriteAllText($missionFile, $newText)
Write-Pass "REOPEN #$reopenN block appended; state Complete -> Reworking (completed_at preserved at $completedAt)"

# ledger entry (scaffold envelope; content names the reason + chain)
$content = "MISSION REOPEN #$reopenN -- Complete -> Reworking (per ADR-029). REASON: $Reason. " +
           "CHAIN: prior completion $completedAt PRESERVED through Reworking (updated only at reclose). " +
           "Operator-gated, never automated. The REOPEN #$reopenN block is APPENDED to mission.yaml " +
           "(prior transition blocks byte-unchanged). NO spec bump (reopen changes no spec)."
$entry = [ordered]@{
    id = $LedgerId; created_at = (Get-UtcStamp); created_by = 'claude-code:orchestrator-guide'
    ts = (Get-UtcStamp); author = 'claude-code:orchestrator-guide'; type = 'decision'; scope = 'framework'
    scope_ref = '.mission/mission.yaml'; content = $content; source_trace_id = $null; supersedes = $null
    tags = @('lifecycle','reopen',"reopen-$reopenN",'reworking','adr-029','completion-chain','framework')
}
Add-LedgerEntry -Root $root -Entry $entry

if (-not $NoCommit) {
    $body = "reopen: Complete -> Reworking (ADR-029) -- REOPEN #$reopenN`r`n`r`n$Reason`r`n"
    $msg = New-CommitMessageFile -Root $root -Body $body
    Invoke-AtomicCommit -Root $root -Paths @('.mission/mission.yaml','.mission/ledger/entries.jsonl') -MessageFile $msg | Out-Null
}
Write-Host "mission reopen: done (REOPEN #$reopenN)" -ForegroundColor Cyan
