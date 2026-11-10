#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next SessionEnd hook -- the mission-event feed's session_stop: the session itself ended (UI-2 S2, B-14;
  register row 528).

.DESCRIPTION
  WHY THIS HOOK EXISTS. Claude Code fires Stop at the end of EVERY TURN, and in 1.3.0's first build (UI-2 S1, A-2) the Stop
  hook appended session_stop at each turn's end that had no background task running. An interactive session therefore read
  "stopped" between two turns. Claude Code 2.1.312 also fires SessionEnd, once, when the session itself ends (its payload
  carries session_id, transcript_path, cwd and the reason). So session_stop is said HERE, and the Stop hook keeps its
  turn-end duties only -- the seal and dispatch_finalized, as before (operator ruling 2026-11-08; no new turn-end kind).

  THIS HOOK appends ONE session_stop (expanded-schemas SS14, schema_version 1.2; its payload as the Stop hook wrote it:
  session_id, dispatch_id, manifest_state, entry_count, evidence_state -- the manifest as it is on disk now) and then releases
  the session's once-only start marker in the telemetry folder, so a session RESUMED after it (`claude --resume`) says
  session_start again on its first call instead of writing lines after its own stop. It seals no evidence store and runs no
  finalizer.

  NEVER BLOCKS THE END. Write-MissionEvent's own bounds hold (a bounded wait under the lock, no line and a hook-errors.log
  entry on any failure); everything around it is caught, and the exit code is 0 whatever happens. It prints nothing.
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
        $ok = Write-MissionEvent -Root $root -Kind 'session_stop' -SourcePath $sf.source -Hook 'SessionEnd' -SessionId $sessionId -DispatchId $did `
                  -Payload ([ordered]@{ session_id = $sessionId; dispatch_id = $did; manifest_state = $sf.manifest_state; entry_count = $sf.entry_count; evidence_state = $sf.evidence_state })
        if ($ok) { Remove-MissionTelemetryMarker -Root $root -Name ('session-' + $sessionId) }
    }
} catch {
    try { Write-EvidenceHookError -Hook 'SessionEnd' -Message "the session_stop could not be composed: $($_.Exception.Message)" } catch { }
}
exit 0
