#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next SubagentStop hook -- the mission-event feed's session_stop for a subagent's session
  (RELEASE-4 S1, F-P2a; register row 500, W-4).

.DESCRIPTION
  A subagent's tool calls reach PostToolUse under the subagent's own session id, so its first one appends a
  session_start (expanded-schemas SS14) -- but a subagent ending fires SubagentStop, never Stop, so with no
  hook here the feed showed that session open for ever. This hook appends ONE session_stop for the session
  the payload names, with the manifest as it stands on disk (Get-MissionEvidenceStopFacts, the Stop hook's
  own reading), and nothing else: it seals no evidence store and runs no finalizer -- a subagent's stop is
  not the end of the dispatch that owns it, which Stop and the runner's marker decide as before.

  NEVER BLOCKS THE STOP. Write-MissionEvent's own bounds hold (SS14: a bounded wait under the lock, no line
  and a hook-errors.log entry on any failure); everything around it is caught, and the exit code is 0
  whatever happens. It prints nothing, so the harness reads no decision from it.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    $stdin = [Console]::In.ReadToEnd()
    . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
    $parsed = $null
    try { if ($stdin -and $stdin.Trim()) { $parsed = $stdin | ConvertFrom-Json } } catch { $parsed = $null }
    $sessionId = if ($null -ne $parsed) { [string](Get-HookField $parsed 'session_id' '') } else { '' }
    $root = Get-EvidenceRepoRoot
    if ($sessionId -and (Test-MissionTelemetryStream -Root $root)) {
        $did = Get-EvidenceDispatchId -SessionId $sessionId
        $sf = Get-MissionEvidenceStopFacts -Root $root -DispatchId $did
        $null = Write-MissionEvent -Root $root -Kind 'session_stop' -SourcePath $sf.source -Hook 'SubagentStop' -SessionId $sessionId -DispatchId $did `
                    -Payload ([ordered]@{ session_id = $sessionId; dispatch_id = $did; manifest_state = $sf.manifest_state; entry_count = $sf.entry_count; evidence_state = $sf.evidence_state })
    }
} catch {
    try { Write-EvidenceHookError -Hook 'SubagentStop' -Message "the subagent's session_stop could not be composed: $($_.Exception.Message)" } catch { }
}
exit 0
