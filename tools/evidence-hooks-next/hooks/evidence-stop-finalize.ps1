#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next Stop hook -- an OWNERSHIP GATE in front of A1's finalizer.
  (LAM-ACCEPT WP-1 H-1)

.DESCRIPTION
  THE FINALIZE LOGIC IS NOT REIMPLEMENTED HERE. Everything A1's finalizer does -- the two-phase
  order, the append-verified supersession and its retention chain, the stream-identity divergence
  check, the call-completeness block, the reconcile pass -- is 23 KB of sealed, adversarially
  tested code. Reproducing it to add one branch in front would put a second copy in the tree and
  make H-4's regression a coincidence rather than a consequence. So this hook decides ONE thing
  and then runs A1's finalizer in place.

  THE ONE DECISION:

    runner-owned AND no DISPATCH-END  ->  NO-OP. Stop finalizes nothing. The state machine
                                          derives OPEN, and the runner's marker will finalize
                                          later via evidence-dispatch-end.ps1.
    anything else                     ->  A1, unchanged. Stop finalizes; post-finalize growth
                                          derives GREW; mutation derives TAMPERED.

  WHY THE UNOWNED PATH IS LEFT ENTIRELY ALONE. It is the path with fourteen adversarial checks
  against it (the A1 negative suite, H-4). An unowned dispatch is one nothing has claimed, and for
  it the harness's turn IS the only lifecycle unit there is -- which is what A1 already assumed
  and, for that case, correctly.

  STDIN IS FORWARDED BYTE-FOR-BYTE. The gate parses a copy to read session_id; the ORIGINAL
  string is what A1 receives, so no field is lost or reshaped by a round-trip through
  ConvertTo-Json. A1's own re-entry guard (stop_hook_active) and its fail-closed branches are
  therefore reached exactly as they would be if it were registered directly.

  FAILURE DIRECTION. If the gate cannot decide -- unreadable payload, unresolvable root -- it
  FORWARDS rather than swallowing. A1 then applies its own fail-closed handling. The gate fails
  toward A1's behaviour, never toward silently finalizing nothing.
#>
[CmdletBinding()]
param(
    [string]$DispatchId,
    [switch]$NoStreams
)

$ErrorActionPreference = 'Stop'

$stdin = [Console]::In.ReadToEnd()

function Invoke-A1Finalizer {
    param([string]$Payload, [string]$Dispatch, [bool]$NoStream)
    $a1 = Join-Path $PSScriptRoot '..\..\framework\hooks\evidence-stop-finalize.ps1'
    if (-not (Test-Path -LiteralPath $a1)) {
        throw "evidence-hooks-next: the A1 Stop finalizer is not at $a1"
    }
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $a1)
    if ($Dispatch)  { $argv += @('-DispatchId', $Dispatch) }
    if ($NoStream)  { $argv += '-NoStreams' }
    $Payload | & powershell @argv
    return $LASTEXITCODE
}

try {
    . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

    $sessionId = ''
    $parsed    = $null
    try { if ($stdin -and $stdin.Trim()) { $parsed = $stdin | ConvertFrom-Json } } catch { $parsed = $null }
    if ($null -ne $parsed) { $sessionId = [string](Get-HookField $parsed 'session_id' '') }

    $root = Get-EvidenceRepoRoot
    $did  = $DispatchId
    if (-not $did) { $did = Get-EvidenceDispatchId -SessionId $sessionId }

    $owned = Test-EvidenceRunnerOwned   -Root $root -DispatchId $did
    $ended = Test-EvidenceDispatchEnded -Root $root -DispatchId $did

    # THE MISSION-EVENT FEED (UI-1 S1): session_stop on every Stop, with the manifest as it is on disk after
    # this hook's own work; dispatch_finalized after it when this Stop is the one that sealed the store (the
    # manifest's bytes changed across the A1 run). Never fails the hook: Write-MissionEvent does not throw,
    # and the composition around it is caught.
    function Send-StopTelemetry {
        param([string]$ManifestShaBefore, $Sidecar, [bool]$MaySeal)
        try {
            if (-not (Test-MissionTelemetryStream -Root $root)) { return }
            $sf = Get-MissionEvidenceStopFacts -Root $root -DispatchId $did
            $null = Write-MissionEvent -Root $root -Kind 'session_stop' -SourcePath $sf.source -Hook 'Stop' -SessionId $sessionId -DispatchId $did `
                        -Payload ([ordered]@{ session_id = $sessionId; dispatch_id = $did; manifest_state = $sf.manifest_state; entry_count = $sf.entry_count; evidence_state = $sf.evidence_state })
            if ($MaySeal -and $sf.manifest_sha -and ($sf.manifest_sha -ne $ManifestShaBefore)) {
                $gaps = 0
                if ($null -ne $Sidecar) { try { $gaps = [int]$Sidecar.count } catch { $gaps = 0 } }
                $null = Write-MissionEvent -Root $root -Kind 'dispatch_finalized' -SourcePath $sf.source -Hook 'Stop' -SessionId $sessionId -DispatchId $did `
                            -Payload ([ordered]@{ dispatch_id = $did; manifest_state = $sf.manifest_state; partial = (($sf.manifest_state -ne 'FINALIZED') -or ($gaps -gt 0)); capture_gaps_count = $gaps })
            }
        } catch { }
    }

    if ($owned -and -not $ended) {
        # THE GATE. The runner owns this dispatch and has not declared it finished, so this Stop
        # is the end of a TURN, not the end of a DISPATCH -- the exact conflation E5-iv recorded.
        # Nothing is sealed, nothing is copied, and the store is left byte-untouched.
        Write-Verbose "evidence-hooks-next: dispatch $did is runner-owned and unfinished -- Stop is a no-op (state OPEN)."
        Send-StopTelemetry -ManifestShaBefore '' -Sidecar $null -MaySeal $false
        exit 0
    }

    # Read for the feed only, so it may not fail the hook: a manifest held without read share would throw here
    # under EAP Stop and take A1's run with it. Unreadable, it reads as no prior hash.
    $manShaBefore = $null
    try { $manShaBefore = Get-Sha256OfFile -Path (Join-Path (Get-EvidenceRuntimeDir -Root $root -DispatchId $did) 'manifest.json') } catch { $manShaBefore = $null }
    $side = $null
    $a1Exit = Invoke-A1Finalizer -Payload $stdin -Dispatch $DispatchId -NoStream ([bool]$NoStreams)

    # THE SIDECAR IS WRITTEN HERE TOO, AND IT WAS NOT BEFORE. H-2 requires Stop-time reconciliation
    # to write capture-gaps.yaml beside the manifest. The only caller of the writer was
    # evidence-dispatch-end.ps1, which refuses without a DISPATCH-END marker -- so an UNOWNED
    # session, the lifecycle H-1 deliberately preserves, finalized with a manifest and NO GAP
    # ACCOUNTING AT ALL. Found by V-1 round 2 (WP-1). A session that produced a manifest has been
    # sealed, and a sealed store with no statement about what went missing is the E5-ii silence the
    # sidecar exists to break.
    #
    # THE TRANSCRIPT PATH IS FORWARDED, because the counter arm alone cannot see a call that never
    # reached PostToolUse. It comes from this Stop payload, which is the only place it exists.
    #
    # FAILURE DIRECTION: a sidecar write that throws is recorded as a hook error and does NOT change
    # the finalizer's exit code. A1 has already sealed the store by this point; turning its success
    # into a failure because an accounting file could not be written would misreport what happened.
    try {
        $tp = ''
        if ($null -ne $parsed) { $tp = [string](Get-HookField $parsed 'transcript_path' '') }
        # THE SESSION IS FORWARDED TOO (round 4). The log is per-DISPATCH and the transcript is
        # per-SESSION; without a session to scope the log side, the two arms describe different
        # populations and their difference is arithmetic rather than evidence.
        $side = Write-EvidenceCaptureGapsSidecar -Root $root -DispatchId $did -TranscriptPath $tp -SessionId $sessionId
    }
    catch {
        try { Write-EvidenceHookError -Hook 'Stop' -SessionId $sessionId `
                -Message "capture-gaps sidecar could not be written after finalize: $($_.Exception.Message)" } catch { }
    }

    Send-StopTelemetry -ManifestShaBefore ([string]$manShaBefore) -Sidecar $side -MaySeal $true

    exit $a1Exit
}
catch {
    # The gate could not decide. Forward rather than swallow, then record why the gate failed.
    try { $null = Invoke-A1Finalizer -Payload $stdin -Dispatch $DispatchId -NoStream ([bool]$NoStreams) } catch { }
    try {
        . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
        Write-EvidenceHookError -Hook 'Stop' -Message "next-gen ownership gate failed, forwarded to the A1 finalizer: $($_.Exception.Message)"
    } catch { }
    exit 0
}
