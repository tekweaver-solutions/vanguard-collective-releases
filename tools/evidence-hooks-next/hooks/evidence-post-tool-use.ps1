#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next PostToolUse hook -- one entry per tool call, with a call-counter seq and an
  explicit outcome. (LAM-ACCEPT WP-1 H-2)

.DESCRIPTION
  A1's capture logic, with two changes and no others.

  1. THE ALLOCATION FLOOR IS A CALL COUNTER, NOT LOG LENGTH.
     A1 computed `$startSeq = (non-blank log lines) + 1`. A _precompact line and a _denied line
     each consume a log line without being a tool call, so every such line pushed the floor past
     a number no call had used -- and the resulting hole was indistinguishable from a dropped
     capture. Get-EvidenceNextSeq counts CALLS, so a hole in the call sequence means a call was
     lost, which is the whole point of H-2's capture_gaps accounting.

     The atomic allocator is UNTOUCHED. New-EvidenceStreamFile still probes upward with
     FileMode::CreateNew and the winning number is still the entry's seq, its filename and its
     log-line seq (A1 cure D11). The counter is a FLOOR, not a key: two hooks that read the same
     counter value still cannot collide, so the resolution of the seq-race finding stands unchanged.

  2. EVERY ENTRY CARRIES `outcome`.
     succeeded | failed here; denied is written by the guard. A reader no longer infers the
     outcome from which variant a line happens to be.

     `outcome` LIVES IN log.jsonl AND IS NEVER PROJECTED INTO THE MANIFEST. Manifest entries are
     schema-closed (evidence-manifest.schema.json:39-40) and the finalizer projects a fixed field
     set, so the manifest stays valid at schema_version 1.3.0. This is not
     a convention this hook has to maintain: A1's finalizer builds the projection explicitly and
     simply never reads this field.

  E5-i REMAINS TRUE AND IS NOT PAPERED OVER. On the live harness `exit_code` is absent from every
  captured payload, so `outcome` degrades to 'succeeded' where no exit code is present. That is a
  statement about what the harness reports, not a claim that the call succeeded -- and it is why
  the capture_gaps accounting is derived from the counter rather than from outcomes.

  Exit behaviour, unchanged: this hook never fails a tool call. Capture errors are recorded to
  hook-errors.log and the hook exits 0.
#>
[CmdletBinding()]
param(
    [int]$InlineCap = 8192
)

. (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

try {
    $payload   = Read-HookStdin
    $sessionId = [string](Get-HookField $payload 'session_id' '')
    $toolName  = [string](Get-HookField $payload 'tool_name' 'unknown')
    $toolInput = Get-HookField $payload 'tool_input' $null
    $toolResp  = Get-HookField $payload 'tool_response' $null

    $root       = Get-EvidenceRepoRoot
    $dispatchId = Get-EvidenceDispatchId -SessionId $sessionId
    $rt         = Get-EvidenceRuntimeDir -Root $root -DispatchId $dispatchId
    $logPath    = Join-Path $rt 'log.jsonl'
    $streamDir  = Join-Path $rt 'streams'
    if (-not (Test-Path -LiteralPath $streamDir)) { New-Item -ItemType Directory -Path $streamDir -Force | Out-Null }

    $command = $null
    if ($null -ne $toolInput) {
        if ($toolInput.PSObject.Properties.Name -contains 'command')        { $command = [string]$toolInput.command }
        elseif ($toolInput.PSObject.Properties.Name -contains 'file_path')  { $command = "$toolName $($toolInput.file_path)" }
        elseif ($toolInput.PSObject.Properties.Name -contains 'pattern')    { $command = "$toolName $($toolInput.pattern)" }
        else { $command = ($toolInput | ConvertTo-Json -Compress -Depth 8) }
    }

    $stdout = ''; $stderr = ''; $exitCode = $null
    if ($null -ne $toolResp) {
        # AN EMPTY tool_response USED TO KILL THIS HOOK OUTRIGHT (V-1 round 14, orchestrator).
        # `.PSObject.Properties.Name` on a PSCustomObject with ZERO properties throws "The property
        # 'Name' cannot be found on this object" -- and the outer catch then logged one line and
        # exited 0, so the in-flight witness was never settled, no gate was consumed, and the run
        # reported success. Driven by varying this one field: absent, null and "" all worked; `{}`
        # alone was fatal, which is exactly what a tool producing no output would emit.
        #
        # Enumerating the collection cannot throw on empty. The FAILURE MODE is what mattered here,
        # not the shape: a tripwire that fails silent is worse than one that fails loud, and this
        # one failed silent on the single-use property itself.
        $names = @($toolResp.PSObject.Properties | ForEach-Object { $_.Name })
        if ($names -contains 'stdout')    { $stdout   = [string]$toolResp.stdout }
        if ($names -contains 'stderr')    { $stderr   = [string]$toolResp.stderr }
        if ($names -contains 'exit_code') { $exitCode = $toolResp.exit_code }
        if ($names -contains 'exitCode')  { $exitCode = $toolResp.exitCode }
        if (-not $stdout -and -not $stderr) { $stdout = ($toolResp | ConvertTo-Json -Compress -Depth 8) }
    }

    # DELTA 2 -- outcome. Derived only from what the payload actually carries. A null exit_code is
    # 'succeeded' because PostToolUse fires only on permitted calls (E5-ii) and the harness reports
    # nothing finer; it is NOT evidence that the command's own exit status was zero, and the
    # capture_gaps accounting deliberately does not rely on this field.
    $outcome = 'succeeded'
    if ($null -ne $exitCode) {
        $ec = 0
        if ([int]::TryParse([string]$exitCode, [ref]$ec)) { if ($ec -ne 0) { $outcome = 'failed' } }
    }

    # DELTA 1 -- the floor comes from the call counter.
    $startSeq = Get-EvidenceNextSeq -Root $root -DispatchId $dispatchId

    # Full bytes first, then the log line that points at them -- so a crash between the two loses
    # the pointer, never the evidence.
    $alloc = New-EvidenceStreamFile -StreamDir $streamDir -StartSeq $startSeq -Tool $toolName `
                                    -Stdout $stdout -Stderr $stderr
    $seq       = $alloc.seq
    $streamRel = $alloc.rel

    $stdoutTrunc = (Get-Utf8ByteCount $stdout) -gt $InlineCap
    $stderrTrunc = (Get-Utf8ByteCount $stderr) -gt $InlineCap

    $entry = [ordered]@{
        ts                = Get-UtcStampZ
        session_id        = $sessionId
        dispatch_id       = $dispatchId
        seq               = $seq
        tool              = $toolName
        command           = $command
        exit_code         = $exitCode
        outcome           = $outcome
        stdout            = $(if ($stdoutTrunc) { Get-Utf8TruncatedString -Text $stdout -MaxBytes $InlineCap } else { $stdout })
        stderr            = $(if ($stderrTrunc) { Get-Utf8TruncatedString -Text $stderr -MaxBytes $InlineCap } else { $stderr })
        stdout_truncated  = $stdoutTrunc
        stderr_truncated  = $stderrTrunc
        stdout_sha256     = (Get-Sha256OfString $stdout)   # over FULL bytes, never the excerpt
        stderr_sha256     = (Get-Sha256OfString $stderr)   # over FULL bytes, never the excerpt
        path              = $streamRel
    }
    Add-EvidenceLogLine -LogPath $logPath -Entry $entry

    # T-2, single use. THE CLAIM THIS BLOCK WAS BUILT ON IS FALSE, AND IT WAS MEASURED FALSE
    # (V-1 round 8, WP-4). It read: "this hook firing IS the evidence that the push succeeded --
    # PostToolUse fires only on successful permitted calls". Driven: a payload carrying
    # `exit_code: 1` and "failed to push some refs" fires this hook and stamped the gate CONSUMED.
    # So did `git push --dry-run`.
    #
    # A TOMBSTONE IS TESTIMONY THAT AN AUTHORIZED ACT OCCURRED. Spending a gate for a push that
    # never happened is a false audit record -- the worse half of the pair, by this file's own
    # reckoning -- and it forces the operator to mint a new gate to retry an act that did not occur.
    #
    # THE ANSWER WAS ALREADY IN HAND. `$outcome` is derived from this same payload twenty lines
    # above and was never consulted. That is E66 exactly: the evidence just derived is the evidence
    # the decision forgets to read.
    #
    # DISCLOSED, NOT PAPERED OVER: on this harness `exit_code` is absent from every captured payload
    # (E5-i), so `$outcome` degrades to 'succeeded' and an unknown outcome still consumes. That is
    # unchanged deliberately -- only an EXPLICIT failure now withholds the tombstone. Widening it to
    # "consume only on a proven success" would stop consuming altogether here, and an unspent gate
    # after a real push is the single-use property gone.
    # ============================================================================================
    # CONSUMPTION IS DRIVEN BY THE DECIDER'S RECORD, NOT BY THE CLASSIFIER.
    # ============================================================================================
    # The block that stood here was gated on `Test-EvidencePushCommand`, and that was wrong in BOTH
    # directions -- each measured, neither argued:
    #
    #   OVER-classification: `git lfs env` publishes nothing, was called a push, and STAMPED THE
    #     GATE CONSUMED. `mission-gate.ps1 list` then read CONSUMED and the operator's real push was
    #     DENIED. A tombstone is testimony that an authorized act occurred; that one testified to an
    #     act that never happened, and cost the operator the authorization they were holding.
    #
    #   UNDER-classification: the spellings the tripwire cannot read (`$G push`, `xargs git`, a
    #     wrapper, an alias) now reach the DECIDER, which authorizes and witnesses them correctly.
    #     Had consumption stayed behind the classifier, its blindness would have left those gates
    #     UNSPENT after a real publication -- the single-use property gone. Keeping the old trigger
    #     would have converted the tripwire's known and accepted limit into a second live defect.
    #
    # THE OLD PATH IS REMOVED RATHER THAN LEFT BESIDE THE NEW ONE. Two mechanisms for one decision
    # is precisely how the halves of this lifecycle drifted apart four times.
    #
    # The trigger is now the in-flight record `pre-push` writes: git's own fact, taken after every
    # expansion. It is NOT "impossible for a non-publishing command to produce", which is what this
    # comment used to claim -- `git push --dry-run` produces it, and no pre-push hook can tell the
    # difference (V-1 round 14, WP-4). `Complete-EvidencePushGate` requires the remote to be OBSERVED
    # holding the authorized sha before spending anything, so classification never decides whether an
    # authorization is spent, and a dry run's witness settles as "not published, not spent".
    #
    # HERE, unlike at the pre-push layer, the command text IS available -- so the dry run is caught
    # outright rather than merely surviving. That asymmetry is the point of having both layers.
    #
    # BOTH CANDIDATE ROOTS ARE ASKED. The record lives in the repository that was actually pushed;
    # the session's root and any root the command names are both checked, because a resolver
    # answering for the wrong repository is the defect rounds 4 through 11 kept re-finding.
    # NORMALISED BEFORE DE-DUPLICATION (V-1 round 15, a WP-1 finding, driven). `Select-Object -Unique`
    # compares strings, and `C:\x\work` and `C:/x/work` are two different strings naming one
    # directory -- so the settle pass ran TWICE per tool call, visible as duplicate hook-error lines.
    # It was harmless only because the consume path deletes the record before the second pass sees
    # it, which is luck rather than design: at any moment when the first pass had not finished, the
    # second would have been answering about a record still in flight.
    $flightRoots = New-Object System.Collections.Generic.List[string]
    function Add-FlightRoot { param([string]$P)
        if (-not $P) { return }
        try { $P = [IO.Path]::GetFullPath($P) } catch { }
        [void]$flightRoots.Add($P.TrimEnd('\','/'))
    }
    if ($root) { Add-FlightRoot -P $root }
    try {
        $t = Get-EvidencePushTargetRoot -Command $command -Cwd ([string](Get-HookField $payload 'cwd' ''))
        if ($t) { Add-FlightRoot -P (Get-EvidenceRepoTopLevel -Path ((Resolve-Path -LiteralPath $t -ErrorAction Stop).Path)) }
    } catch { }
    # A DRY RUN IS SETTLED BY ORIGIN, NOT BY A CLASSIFIER -- AND THE CLASSIFIER THAT USED TO BE HERE
    # AUTHORIZED A SECOND REAL PUBLICATION (V-1 round 15, WP-1 findings -- CRITICAL, driven).
    #
    # Round 14 put a dry-run test here that cleared the in-flight witness. Two faults compounded:
    # `push_segment` is a SCALAR, so the predicate answers about ONE push segment while this code
    # treated it as a verdict on the whole tool call; and `Clear-EvidencePushInFlight` removes the
    # WHOLE FILE, which is round 14's own finding -- a whole-file write -- coming back as a whole-file
    # delete. Driven: identical publications, only the dry run's position changed; dry-run-first left
    # the real push's gate unspent, the hook-errors log empty, and the stranded gate then authorized
    # a second real publication.
    #
    # NOTHING REPLACES IT, and that is the fix. `Complete-EvidencePushGate` asks the DECLARED origin
    # what it holds: a dry run published nothing, so origin does not hold the sha, so the witness
    # settles as "not published, not spent" and the gate stays open. Amendment 20's mechanism already
    # provides what the round-8 predicate was written to provide, which made the predicate dead code
    # -- and E99 says dead code is wired or DROPPED. Round 14 wired it. That was the wrong branch.
    #
    # The residual cost is named rather than hidden: a dry run whose declared origin is UNREACHABLE
    # for the whole age bound still ages out and disqualifies its gate. That is bounded and LOUD --
    # the artifact records why and re-minting is an operator act -- and it is traded against two
    # silent critical defects.
    foreach ($fr in (@($flightRoots) | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Read-EvidencePushInFlight -Root $fr)) { continue }
        try {
            $r = Complete-EvidencePushGate -Root $fr
            if ($r.consumed) {
                Write-Verbose "evidence-hooks-next: push gate consumed -- $($r.consumed)"
            } else {
                # Fires ONLY when the decider actually witnessed a publication, so an ordinary
                # non-publishing command reaches none of this. An unspent gate after a real push can
                # authorize a second one, which is why this is loud rather than swallowed.
                try { Write-EvidenceHookError -Hook 'PostToolUse' -SessionId $sessionId `
                        -Message "the pre-push decider witnessed a publication from '$fr' but the gate was NOT consumed: $($r.reason)" } catch { }
            }
        }
        catch {
            try { Write-EvidenceHookError -Hook 'PostToolUse' -SessionId $sessionId `
                    -Message "consumption failed for a witnessed publication from '$fr': $($_.Exception.Message). Treat the authorization as spent and revoke it." } catch { }
        }
    }
    exit 0
}
catch {
    try { Write-EvidenceHookError -Hook 'PostToolUse' -Message $_.Exception.Message -SessionId $sessionId } catch { }
    exit 0
}
