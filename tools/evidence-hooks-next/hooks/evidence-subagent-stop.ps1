#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next SubagentStop hook -- the mission-event feed's subagent_stop: a subagent finished, its parent runs on
  (RELEASE-4 S1, F-P2a; cured by UI-2 S1, A-2; register row 500, W-4).

.DESCRIPTION
  WHAT THE HARNESS GIVES (read live, UI-2 S1 A-3, Claude Code 2.1.312): a subagent's hooks carry the PARENT's session_id --
  its tool calls reach PostToolUse stamped with the parent -- and its SubagentStop payload carries agent_id, agent_type and
  agent_transcript_path besides (the subagent's own transcript, distinct from the parent's transcript_path). So a subagent's
  stop is NEVER a stop of the session the payload names: RELEASE-4's hook appended session_stop for that id, and the feed
  read the orchestrator stopped while it worked (N subagents, N parent stops before the parent's own).

  THIS HOOK appends ONE subagent_stop (expanded-schemas SS14, schema_version 1.2) and nothing else:
    (i)  the payload names the subagent (agent_id, or an agent_transcript_path apart from the parent's): agent_id (the
         transcript's agent-<id> name where the payload has no agent_id), agent_type when given, parent_session_id = the
         payload's session_id, dispatch_id = the parent's dispatch;
    (ii) it names none: parent_session_id, dispatch_id and subagent_ordinal -- the count of subagent_stop lines of that
         parent on the feed, this one included.
  Never session_stop, never dispatch_finalized: a subagent's end is not the end of the dispatch that owns it, which the
  parent's own Stop (evidence-stop-finalize.ps1) and the runner's marker decide. It seals no evidence store and runs no
  finalizer.

  NEVER BLOCKS THE STOP. Write-MissionEvent's own bounds hold (SS14: a bounded wait under the lock, no line and a
  hook-errors.log entry on any failure); everything around it is caught, and the exit code is 0 whatever happens. It prints
  nothing, so the harness reads no decision from it.
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
        $agent = Get-MissionSubagentIdentity -Payload $parsed
        $p = [ordered]@{}
        if ($agent.agent_id) {
            $p['agent_id'] = $agent.agent_id
            if ($agent.agent_type) { $p['agent_type'] = $agent.agent_type }
            $p['parent_session_id'] = $sessionId
            $p['dispatch_id'] = $did
        } else {
            $p['parent_session_id'] = $sessionId
            $p['dispatch_id'] = $did
            $p['subagent_ordinal'] = (Get-MissionSubagentStopCount -Root $root -ParentSessionId $sessionId) + 1
        }
        $null = Write-MissionEvent -Root $root -Kind 'subagent_stop' -SourcePath $sf.source -Hook 'SubagentStop' -SessionId $sessionId -DispatchId $did -Payload $p
    }
} catch {
    try { Write-EvidenceHookError -Hook 'SubagentStop' -Message "the subagent_stop could not be composed: $($_.Exception.Message)" } catch { }
}
exit 0
