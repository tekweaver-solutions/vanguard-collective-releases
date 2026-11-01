#Requires -Version 5.1
<#
.SYNOPSIS
  Stop hook -- finalize the evidence log into a manifest. (A1)

.DESCRIPTION
  Citation convention: LM2-ADR-0NN / "design SS<n>" denote
  docs/framework/vanguard-collective-local-modes-v2.1.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/.

  Design SS4.1: "Stop finalizes the log, computes a manifest (per-entry sha256, count), and
  copies the manifest + selected evidence files into .mission/evidence/<dispatch_id>/ for
  commit at the next ceremony boundary."
  Design SS12.3: entries are {ts, tool, command, exit_code, stdout_sha256, stderr_sha256,
  path}; "immutable after finalization."

  CURE B1. Every field is read through Get-EntryField. The pre-cure version read
  $e.stdout_sha256 directly under Set-StrictMode -Version Latest; a _precompact entry has no
  such field, so the finalizer threw, the outer catch swallowed it, and EVERY session that
  compacted was permanently stuck PARTIAL with a manifest that never appeared. Long sessions
  are the ones that compact, and the ones whose evidence matters most.

  CURE B2. _precompact entries are emitted as a DECLARED VARIANT
  {ts, tool, command, exit_code, transcript_sha256, captured, path} rather than being forced
  into a shape they do not have. Overloading stdout_sha256 to mean "transcript hash" would
  make one field name mean two things -- the opposite of an anchor.

  CURE N-b. streams/ is copied to the committed plane by DEFAULT. The per-entry
  stdout_sha256/stderr_sha256 are computed over the full streams, so a committed stream body
  can be re-derived and compared (Test-EvidenceStreamIntegrity). Without the bodies, entries
  over the inline cap had their untruncated output only in .mission-runtime/, which is
  ephemeral by ADR-003. -NoStreams restores the old behaviour for size-sensitive dispatches
  and is a deliberate, logged reduction in what can later be re-derived.

  CURE D11. A stream-identity divergence check runs inside the fallible phase,
  BEFORE the flags are computed: a manifest can no longer read hook_errors_present:false over
  a store whose stream identities diverge from its entries. The pre-cure instances finalized
  entry_count 15 over 14 files, clean.

  CURE D10. Stop is per-turn on this harness, so finalize is
  per-Stop, and a later Stop SUPERSEDES the prior manifest IF AND ONLY IF the log is a
  VERIFIED APPEND-EXTENSION of the sealed prefix -- the bytes the prior log_sha256 was
  computed over must still hash to it (Get-EvidenceState derives GREW). The prior manifest
  is retained as manifest.superseded-<k>.json in BOTH planes before the successor is
  written; retention failure aborts the supersession. A log whose sealed bytes changed, or
  which is shorter than the sealed prefix, derives TAMPERED and is REFUSED exactly as
  before: the pre-cure rationale -- a later, shorter log must never overwrite the record of
  a longer one -- is now enforced by the append-extension predicate itself rather than by
  refusing every re-finalization. Because every finalize recomputes the error-trail flags,
  the trail is committable AFTER the errors exist, which closes an earlier finding (the
  pre-cure plane froze hook_errors_present:false at first finalize and then refused the
  only mechanism that could update it).

  CURE D8. THE STOP PAYLOAD SENT BY THIS HARNESS CARRIES ELEVEN FIELDS
  -- session_id, transcript_path, cwd, prompt_id, permission_mode, effort, hook_event_name,
  stop_hook_active, last_assistant_message, background_tasks, session_crons -- derived by an
  operator-registered raw-stdin probe (capture sha256 prefix b0eb6687, 2026-08-11). That is
  the SENDS register; the READS register is documented separately, and the two are different
  statements (conflating them is how this cure's space was nearly mis-derived). This hook
  now reads THREE of the eleven:
    session_id       -- dispatch identity, as before;
    stop_hook_active -- RE-ENTRY GUARD (operator ruling): when true, this hook is a NO-OP in
                        its entirety -- no finalize, no supersession, no reconcile, store
                        byte-untouched. A reconcile that runs on a re-entrant Stop risks a
                        supersession chain nobody can read; the next non-re-entrant Stop
                        carries the work.
    transcript_path  -- THE RECONCILIATION BASIS: the payload's own path, never a derived
                        one (the session_id-derived fallback is RETIRED; a transcript absent
                        or unreadable at this path degrades the call_completeness block to
                        'unreconciled', never to a fabricated verdict).
  last_assistant_message IS NEVER READ AND NEVER RECORDED (operator ruling): the reconciler
  reads the TRANSCRIPT by path and never quotes the payload's session content into the
  evidence plane. The call_completeness block it writes is CONTENT-FREE -- counts, status,
  basis, and the transcript's sha256. An evidence store that embeds assistant prose is a
  different artifact than the one this program is building. A failed call and a denied call
  are now either recorded ('_denied' entries, written by the guard) or their absence is
  DETECTABLE from the committed manifest alone (the block's counts); 'complete' is asserted
  ONLY when reconciliation ran with zero unmatched calls.
#>
[CmdletBinding()]
param(
    [string]$DispatchId,
    [switch]$NoStreams
)

. (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

try {
    $payload   = Read-HookStdin
    $sessionId = [string](Get-HookField $payload 'session_id' '')

    # CURE D8 -- the re-entry guard runs BEFORE ANYTHING, the FINALIZED no-op branch included.
    if ([bool](Get-HookField $payload 'stop_hook_active' $false)) {
        exit 0
    }
    $transcriptPath = [string](Get-HookField $payload 'transcript_path' '')

    $root      = Get-EvidenceRepoRoot
    if (-not $DispatchId) { $DispatchId = Get-EvidenceDispatchId -SessionId $sessionId }

    $rt      = Get-EvidenceRuntimeDir -Root $root -DispatchId $DispatchId
    $logPath = Join-Path $rt 'log.jsonl'
    $manPath = Join-Path $rt 'manifest.json'

    if (-not (Test-Path -LiteralPath $logPath)) {
        Write-Verbose "evidence-stop-finalize: no log for dispatch $DispatchId -- nothing to finalize."
        exit 0
    }

    $state = Get-EvidenceState -Root $root -DispatchId $DispatchId
    if ($state.state -eq 'FINALIZED') {
        # The log is unchanged since the seal, so there is nothing to re-seal and this Stop is
        # a no-op -- with ONE exception (CURE D10): the ERROR TRAIL may have grown
        # since the seal (an error recorded after the last finalize, with no further log
        # growth). Reconcile the trail flags by hash comparison, exactly as the phase-3
        # reconcile below does. The log seal is untouched -- log_sha256 and log_bytes_sealed
        # are not recomputed -- so nothing about the evidence record is laundered; only the
        # manifest's statement about its own error trail is kept true, disclosed via
        # `reconciled`. (JSON round-trip note: this branch re-serialises the parsed manifest,
        # which is content-preserving but not byte-preserving; the superseded-manifest chain
        # is untouched by it.) CURE D8 NOTE: call_completeness is NOT refreshed here -- the
        # block is as-of its finalize, and an unchanged log means no new calls to reconcile.
        try {
            $man0 = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json
            $errPath0 = Get-EvidenceHookErrorPath -Root $root -DispatchId $DispatchId
            $errSha0  = $(if (Test-Path -LiteralPath $errPath0) { Get-Sha256OfFile -Path $errPath0 } else { $null })
            $recorded0 = Get-EntryField $man0 'hook_errors_sha256' $null
            if ($errSha0 -ne $recorded0) {
                $man0.hook_errors_present = ($null -ne $errSha0)
                $man0.hook_errors_sha256  = $errSha0
                if ($man0.PSObject.Properties.Name -contains 'reconciled') { $man0.reconciled = $true }
                else { $man0 | Add-Member -NotePropertyName 'reconciled' -NotePropertyValue $true }
                [System.IO.File]::WriteAllText($manPath, ($man0 | ConvertTo-Json -Depth 12),
                                               (New-Object System.Text.UTF8Encoding($false)))
                $committed0 = Get-EvidenceCommittedDir -Root $root -DispatchId $DispatchId
                if (-not (Test-Path -LiteralPath $committed0)) { New-Item -ItemType Directory -Path $committed0 -Force | Out-Null }
                Copy-Item -LiteralPath $manPath -Destination (Join-Path $committed0 'manifest.json') -Force
                if ($errSha0) { Copy-Item -LiteralPath $errPath0 -Destination (Join-Path $committed0 'hook-errors.log') -Force }
            }
        }
        catch {
            try { Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId -Message "no-op trail reconcile failed: $($_.Exception.Message)" } catch { }
        }
        Write-Verbose "evidence-stop-finalize: dispatch $DispatchId already FINALIZED and unchanged -- no-op."
        exit 0
    }
    if ($state.state -eq 'TAMPERED') {
        # Do not overwrite: the existing manifest is the record of what the log was when it was
        # sealed. Re-finalizing here would launder the tamper into a clean manifest. Since CURE D10
        # this branch is reached ONLY when the sealed bytes cannot be re-derived (mutation or
        # truncation) -- growth by append derives GREW and supersedes below.
        try {
            Add-Content -LiteralPath (Join-Path $rt 'hook-errors.log') `
                -Value "$(Get-Date -Format o) Stop: REFUSED to finalize TAMPERED dispatch -- $($state.reason)"
        } catch { }
        exit 0
    }
    if ($state.state -eq 'GREW') {
        # CURE D10: APPEND-VERIFIED SUPERSESSION. Get-EvidenceState has already
        # verified that the sealed prefix re-derives and the log is strictly longer. Retain the
        # prior manifest FIRST, in the runtime plane; if retention fails, REFUSE to supersede --
        # superseding without the retained prior would rewrite the record, and the next Stop can
        # retry. The retained file is never edited and never deleted.
        $priorSup = @(Get-ChildItem -LiteralPath $rt -File -Filter 'manifest.superseded-*.json' -ErrorAction SilentlyContinue)
        $supName  = 'manifest.superseded-{0:d3}.json' -f ($priorSup.Count + 1)
        try {
            Copy-Item -LiteralPath $manPath -Destination (Join-Path $rt $supName) -ErrorAction Stop
        }
        catch {
            try { Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
                -Message "supersession retention failed ($supName): $($_.Exception.Message) -- REFUSING to supersede without the retained prior." } catch { }
            exit 0
        }
        Write-Verbose "evidence-stop-finalize: dispatch $DispatchId GREW -- prior manifest retained as $supName; superseding."
    }

    # finalize_count is DERIVED from the retained chain, never carried forward from a field a
    # damaged manifest might not have: first finalize = 1, k-th supersession = k+1.
    $finalizeCount = @(Get-ChildItem -LiteralPath $rt -File -Filter 'manifest.superseded-*.json' -ErrorAction SilentlyContinue).Count + 1

    # The log is read as BYTES exactly once; the seal (log_sha256) and the sealed length
    # (log_bytes_sealed) are computed from that one buffer, and the committed copy is written
    # from it, so the three can never disagree about which bytes were sealed (CURE D10).
    $logBytes = [System.IO.File]::ReadAllBytes($logPath)

    $log = Read-EvidenceLog -LogPath $logPath
    $entries = @()
    foreach ($e in @($log)) {
        if ((Get-EntryField $e '_unparsable' $false)) { continue }
        $tool = [string](Get-EntryField $e 'tool' '')

        if ($tool -eq '_precompact') {
            # declared variant -- design SS12.3 does not name this shape; see the schema's
            # x-deviations-from-design-12-3 block.
            $entries += [ordered]@{
                ts                = Get-EntryField $e 'ts' $null
                tool              = $tool
                command           = Get-EntryField $e 'command' $null
                exit_code         = Get-EntryField $e 'exit_code' $null
                transcript_sha256 = Get-EntryField $e 'transcript_sha256' $null
                captured          = [bool](Get-EntryField $e 'captured' $false)
                path              = Get-EntryField $e 'path' $null
            }
        } elseif ($tool -eq '_denied') {
            # declared variant (cure D8): a call the guard refused, recorded by the
            # guard at deny time. No stream, no seq, and NO exit_code -- nothing executed, and
            # an exit_code here would resurrect the constant-null confusion.
            $entries += [ordered]@{
                ts          = Get-EntryField $e 'ts' $null
                tool        = $tool
                denied_tool = Get-EntryField $e 'denied_tool' $null
                command     = Get-EntryField $e 'command' $null
                reason      = Get-EntryField $e 'reason' $null
                path        = Get-EntryField $e 'path' $null
            }
        } else {
            $entries += [ordered]@{
                ts            = Get-EntryField $e 'ts' $null
                tool          = $tool
                command       = Get-EntryField $e 'command' $null
                exit_code     = Get-EntryField $e 'exit_code' $null
                stdout_sha256 = Get-EntryField $e 'stdout_sha256' (Get-Sha256OfString '')
                stderr_sha256 = Get-EntryField $e 'stderr_sha256' (Get-Sha256OfString '')
                path          = Get-EntryField $e 'path' $null
            }
        }
    }
    $unparsable = @(@($log) | Where-Object { (Get-EntryField $_ '_unparsable' $false) }).Count

    # B3 -- TWO-PHASE FINALIZE. The fallible work (copying to the committed plane) runs
    # FIRST, so hook_errors_present reflects errors raised BY that work. The previous order
    # computed the flag before the copies, and a validator measured hook_errors_present=false on
    # a dispatch that had errored: the copy threw, the error was logged, and the already-written
    # manifest denied it.
    $errPath   = Get-EvidenceHookErrorPath -Root $root -DispatchId $DispatchId
    $committed = Get-EvidenceCommittedDir -Root $root -DispatchId $DispatchId

    # PHASE 1 -- fallible copies. Failures are recorded and do NOT abort finalization: a
    # committed-plane problem must not cost the runtime manifest, but it must be visible.
    # CURE D10: the committed log is written from the SAME byte buffer the seal was computed
    # over, and every retained superseded manifest rides to the committed plane, so the
    # retention chain exists identically in both planes.
    try {
        if (-not (Test-Path -LiteralPath $committed)) { New-Item -ItemType Directory -Path $committed -Force | Out-Null }
        [System.IO.File]::WriteAllBytes((Join-Path $committed 'log.jsonl'), $logBytes)
        foreach ($sup in @(Get-ChildItem -LiteralPath $rt -File -Filter 'manifest.superseded-*.json' -ErrorAction SilentlyContinue)) {
            Copy-Item -LiteralPath $sup.FullName -Destination (Join-Path $committed $sup.Name) -Force
        }
        if (-not $NoStreams) {
            foreach ($sub in @('streams', 'transcripts')) {
                $src = Join-Path $rt $sub
                if (Test-Path -LiteralPath $src) {
                    $dst = Join-Path $committed $sub
                    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
                    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
                }
            }
        } else {
            Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
                -Message "-NoStreams set -- stream/transcript bodies NOT committed; untruncated output survives only in .mission-runtime (ephemeral per ADR-003)."
        }
    }
    catch {
        Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
            -Message "committed-plane copy failed: $($_.Exception.Message)"
    }

    # CURE D11: stream-identity divergence is recorded INSIDE the fallible phase,
    # BEFORE the flags are computed (the B3 two-phase order is preserved), so a manifest
    # can no longer read hook_errors_present:false over a store whose stream identities diverge
    # from its entries. Findings are per member (design SS4.5 law 4); the check is identity-only
    # (no re-hashing), so finalize stays cheap.
    try {
        foreach ($f in @(Get-EvidenceStreamIdentityFindings -Entries $entries -StreamDir (Join-Path $rt 'streams'))) {
            Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
                -Message "stream identity divergence [$($f.kind)]: $($f.problem)"
        }
    }
    catch {
        Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
            -Message "stream identity check failed: $($_.Exception.Message)"
    }

    # CURE D8: CALL-COMPLETENESS RECONCILIATION, inside the fallible phase so a
    # reconciler error is reflected by the flags computed below. The block is CONTENT-FREE --
    # counts, status, basis, and the transcript's sha256; the reconciler reads the TRANSCRIPT
    # by the payload's path and NEVER quotes the payload's session content
    # (last_assistant_message) into the evidence plane (operator ruling). Every failure lands
    # 'unreconciled': never a fabricated 'complete', never a fabricated gap.
    $ccBlock = $null
    try {
        $summary = $null
        if ($transcriptPath) {
            $summary = Get-EvidenceTranscriptCallSummary -TranscriptPath $transcriptPath -SessionId $sessionId
        }
        $ccBlock = Get-EvidenceCallCompleteness -Summary $summary -LogEntries @($log) `
                                                -TranscriptPathPresent ([bool]$transcriptPath)
    }
    catch {
        Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
            -Message "call-completeness reconciliation failed: $($_.Exception.Message)"
        $ccBlock = [pscustomobject][ordered]@{
            status            = 'unreconciled'
            basis             = $(if ($transcriptPath) { 'payload-transcript-path' } else { 'none' })
            transcript_sha256 = $null
            transcript_calls  = $null
            logged_entries    = $null
            failed_seen       = $null
            denied_seen       = $null
            denied_records    = $null
            unmatched         = $null
            unresolved_calls  = $null
            reason            = 'reconciler error -- see hook-errors.log'
        }
    }

    # PHASE 2 -- flags computed AFTER the fallible work.
    $errPresent = Test-Path -LiteralPath $errPath

    $manifest = [ordered]@{
        schema_version     = $script:EvidenceSchemaVersion
        dispatch_id        = $DispatchId
        session_id         = $sessionId
        state              = 'finalized'
        entries            = $entries
        entry_count        = $entries.Count
        unparsable_lines   = $unparsable
        log_path           = 'log.jsonl'
        log_sha256         = (Get-Sha256OfBytes -Bytes $logBytes)
        log_bytes_sealed   = $logBytes.Length
        streams_committed  = (-not $NoStreams)
        hook_errors_present = $errPresent
        hook_errors_sha256 = $(if ($errPresent) { Get-Sha256OfFile -Path $errPath } else { $null })
        call_completeness  = $ccBlock
        finalize_count     = $finalizeCount
        created_at         = Get-UtcStampZ
        finalized_at       = Get-UtcStampZ
    }

    $json = ($manifest | ConvertTo-Json -Depth 12)
    [System.IO.File]::WriteAllText($manPath, $json, (New-Object System.Text.UTF8Encoding($false)))

    # PHASE 3 -- publish the manifest and the error trail, then RECONCILE ONCE. If anything in
    # this phase errors, the error log gains an entry the manifest we just wrote denies; the
    # reconcile pass rewrites the manifest a single time so the flag matches reality.
    # Finalization is not complete until this hook returns, so this is not a post-seal rewrite.
    try {
        if (-not (Test-Path -LiteralPath $committed)) { New-Item -ItemType Directory -Path $committed -Force | Out-Null }
        Copy-Item -LiteralPath $manPath -Destination (Join-Path $committed 'manifest.json') -Force
        if ($errPresent) { Copy-Item -LiteralPath $errPath -Destination (Join-Path $committed 'hook-errors.log') -Force }
    }
    catch {
        Write-EvidenceHookError -Hook 'Stop' -DispatchId $DispatchId `
            -Message "manifest publish failed: $($_.Exception.Message)"
    }

    # F4 -- the gate is a HASH COMPARISON, which is strictly simpler than the
    # presence-plus-absence condition it replaces. The old gate (`$errNow -and -not $errPresent`)
    # could not fire when an error already existed at phase 2 and the publish phase errored
    # again: the flag was already true, so the recorded hash stayed stale while the schema called
    # it an anchor. Comparing hashes covers every case -- appeared, grew, unchanged -- with one
    # condition and no new logic.
    $errNowSha = $(if (Test-Path -LiteralPath $errPath) { Get-Sha256OfFile -Path $errPath } else { $null })
    if ($errNowSha -ne $manifest.hook_errors_sha256) {
        $manifest.hook_errors_present = ($null -ne $errNowSha)
        $manifest.hook_errors_sha256  = $errNowSha
        $manifest.reconciled          = $true
        [System.IO.File]::WriteAllText($manPath, ($manifest | ConvertTo-Json -Depth 12),
                                       (New-Object System.Text.UTF8Encoding($false)))
        try {
            Copy-Item -LiteralPath $manPath -Destination (Join-Path $committed 'manifest.json') -Force
            if ($errNowSha) { Copy-Item -LiteralPath $errPath -Destination (Join-Path $committed 'hook-errors.log') -Force }
        } catch { }
    }

    Write-Verbose "evidence-stop-finalize: finalized $DispatchId ($($entries.Count) entries, finalize_count $finalizeCount)."
    exit 0
}
catch {
    # CURE B5 (trail visibility): per-dispatch log -- the path Get-EvidenceState reads.
    try { Write-EvidenceHookError -Hook 'Stop' -Message $_.Exception.Message -SessionId $sessionId -DispatchId $DispatchId } catch { }
    # Exit 0 deliberately: a thrown Stop hook must not wedge session shutdown. The absent
    # manifest is itself the signal -- the dispatch reads PARTIAL, which blocks consumption.
    # B1 is the reminder that this swallow can hide a live defect: hook-errors.log is the only
    # place the cause survives, which is why Get-EvidenceState now points readers at it.
    exit 0
}
