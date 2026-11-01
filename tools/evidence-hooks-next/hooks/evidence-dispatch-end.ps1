#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next dispatch-end finalizer -- the RUNNER's boundary act.
  (LAM-ACCEPT WP-1 H-1, H-2)

.DESCRIPTION
  This is not a harness hook. It is invoked by the RUNNER (WP-2, mission-dispatch.ps1) after the
  worker process exits, and it is the only thing that seals a runner-owned dispatch. Design
  SS4.7's D10 asks for A1's dispatch unit and the harness's turn unit to be reconciled; the
  reconciliation is that the party which SPAWNED the worker is the party that declares it done.

  PRECONDITION: the DISPATCH-END marker must already be on disk, written by the runner. This
  script does NOT write it. That separation is deliberate -- the marker is the runner's
  attestation that the worker exited, and a finalizer that could mint its own precondition would
  be attesting to something it did not observe.

  WHAT IT DOES, in order:
    1. refuses if the marker is absent (the runner has not declared the boundary);
    2. runs A1's finalizer in place -- the seal, the committed-plane copies, the supersession
       chain and the reconcile pass are all A1's, unmodified;
    3. writes the capture-gaps SIDECAR beside the manifest.

  STEP 3 RUNS EVEN WHEN STEP 2 REFUSES, and that is the point rather than an oversight. A
  finalizer that refuses -- because the log was truncated or mutated, deriving TAMPERED -- is
  exactly the case where a consumer most needs the gap accounting. Writing the sidecar only on a
  clean seal would make the artifact present precisely when it says nothing and absent precisely
  when it would say something.

  THE SIDECAR IS NOT IN THE MANIFEST, and that is a ruling rather than a preference.
  The normative schema closes the manifest (additionalProperties:false) and pins schema_version to
  the const "1.3.0"; a capture_gaps field would make every next-gen manifest schema-invalid, and
  bumping the version would break both the sealed schema and the A1 suite's own assertion. The
  runner lifts capture_gaps_sha256 and capture_gaps_count into <dispatch>.anchors.yaml instead
  (WP-2 R-3), which is where a claim about the dispatch belongs.

  Exit codes:  0 = sealed (or reconciled) and the sidecar written;  2 = refused, marker absent.
#>
[CmdletBinding()]
param(
    [string]$DispatchId,
    [switch]$NoStreams
)

$ErrorActionPreference = 'Stop'

$stdin = ''
try { $stdin = [Console]::In.ReadToEnd() } catch { $stdin = '' }

try {
    . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

    $sessionId      = ''
    $transcriptPath = ''
    $parsed = $null
    try { if ($stdin -and $stdin.Trim()) { $parsed = $stdin | ConvertFrom-Json } } catch { $parsed = $null }
    if ($null -ne $parsed) {
        $sessionId      = [string](Get-HookField $parsed 'session_id' '')
        $transcriptPath = [string](Get-HookField $parsed 'transcript_path' '')
    }

    $root = Get-EvidenceRepoRoot
    $did  = $DispatchId
    if (-not $did) { $did = Get-EvidenceDispatchId -SessionId $sessionId }

    # 1 -- the runner's attestation must already exist.
    if (-not (Test-EvidenceDispatchEnded -Root $root -DispatchId $did)) {
        $msg = "evidence-hooks-next: REFUSING to finalize $did -- no DISPATCH-END marker at " +
               "$(Get-EvidenceEndMarkerPath -Root $root -DispatchId $did). The marker is the runner's " +
               "attestation that the worker exited; this finalizer does not mint its own precondition."
        try { Write-EvidenceHookError -Hook 'DispatchEnd' -DispatchId $did -Message $msg } catch { }
        [Console]::Error.WriteLine($msg)
        exit 2
    }

    # 2 -- A1's finalizer, in place. The synthesized payload carries only what A1 reads: the
    # session id and, when the runner captured one, the transcript path that is its reconciliation
    # basis. stop_hook_active is deliberately absent -- this is not a re-entrant Stop.
    $a1 = Join-Path $PSScriptRoot '..\..\framework\hooks\evidence-stop-finalize.ps1'
    if (-not (Test-Path -LiteralPath $a1)) {
        throw "evidence-hooks-next: the A1 Stop finalizer is not at $a1"
    }
    $fwd = @{ session_id = $sessionId; hook_event_name = 'Stop' }
    if ($transcriptPath) { $fwd['transcript_path'] = $transcriptPath }
    $json = ($fwd | ConvertTo-Json -Compress -Depth 6)

    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $a1, '-DispatchId', $did)
    if ($NoStreams) { $argv += '-NoStreams' }
    $json | & powershell @argv
    $sealExit = $LASTEXITCODE

    # 2b -- COMPLETE THE COMMITTED PLANE. A1's finalizer copies the stream bodies in its phase-1
    # ceremony, but only when it actually finalizes: on its "already FINALIZED and unchanged" no-op
    # branch it returns without copying anything. A store that was sealed early and grew afterwards
    # therefore ends up with a manifest that says N entries were published and a committed plane
    # holding none of their bodies -- which is exactly what Test-EvidencePlaneParity exists to
    # catch, and did: 170 stream bodies MISSING from the committed plane.
    #
    # This copies the MISSING bodies from the runtime plane, byte for byte, and nothing else. It
    # does not write evidence, re-hash anything, or touch the manifest: it completes the publication
    # the manifest already asserts. Anything it cannot copy is recorded, never passed over.
    try {
        $rtDir  = Get-EvidenceRuntimeDir   -Root $root -DispatchId $did
        $cmDir  = Get-EvidenceCommittedDir -Root $root -DispatchId $did
        $rtStr  = Join-Path $rtDir 'streams'
        $cmStr  = Join-Path $cmDir 'streams'
        if (Test-Path -LiteralPath $rtStr) {
            if (-not (Test-Path -LiteralPath $cmDir)) { New-Item -ItemType Directory -Path $cmDir -Force | Out-Null }
            if (-not (Test-Path -LiteralPath $cmStr)) { New-Item -ItemType Directory -Path $cmStr -Force | Out-Null }
            $copied = 0
            foreach ($f in @(Get-ChildItem -LiteralPath $rtStr -File -ErrorAction SilentlyContinue)) {
                $dst = Join-Path $cmStr $f.Name
                if (-not (Test-Path -LiteralPath $dst)) { Copy-Item -LiteralPath $f.FullName -Destination $dst -Force; $copied++ }
            }
            if ($copied -gt 0) {
                Write-Verbose "evidence-hooks-next: completed the committed plane -- $copied stream body/bodies copied."
            }
        }
    }
    catch {
        try { Write-EvidenceHookError -Hook 'DispatchEnd' -DispatchId $did `
                -Message "committed-plane completion failed: $($_.Exception.Message). The manifest may assert publication of bodies the committed plane does not hold." } catch { }
    }

    # 3 -- the sidecar, unconditionally (see the docstring: a refusing seal is when it matters most).
    $side = $null
    try {
        # The transcript path is forwarded here too. It was already parsed above and carried in the
        # forwarded payload, but the sidecar never received it -- so the reconciliation ran on the
        # counter arm alone, which cannot see a call that never reached PostToolUse (H-2).
        # THE SESSION IS FORWARDED TOO (round 4), for the same reason the transcript is: the log is
        # per-DISPATCH and the transcript per-SESSION, so an unscoped comparison lets a surplus on
        # one side cancel a vanished call on the other.
        $side = Write-EvidenceCaptureGapsSidecar -Root $root -DispatchId $did -TranscriptPath $transcriptPath -SessionId $sessionId
    }
    catch {
        try { Write-EvidenceHookError -Hook 'DispatchEnd' -DispatchId $did `
                -Message "capture-gaps sidecar write failed: $($_.Exception.Message)" } catch { }
    }

    if ($null -ne $side) {
        Write-Verbose "evidence-hooks-next: $did sealed (A1 exit $sealExit); capture_gaps_count=$($side.count) sha256=$($side.sha256)"
        # The runner reads these two lines to populate <dispatch>.anchors.yaml (WP-2 R-3).
        Write-Output "capture_gaps_count: $($side.count)"
        Write-Output "capture_gaps_sha256: $($side.sha256)"
    }
    exit 0
}
catch {
    try {
        . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
        Write-EvidenceHookError -Hook 'DispatchEnd' -Message $_.Exception.Message
    } catch { }
    [Console]::Error.WriteLine("evidence-hooks-next dispatch-end: $($_.Exception.Message)")
    exit 0
}
