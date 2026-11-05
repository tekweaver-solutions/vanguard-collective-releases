#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next -- the next-generation evidence library. (LAM-ACCEPT WP-1)

.DESCRIPTION
  THIS FILE IS A DELTA, NOT A FORK. It dot-sources the sealed A1 library and then redefines
  exactly the functions WP-1 changes. Everything else -- Get-EvidenceRepoRoot, the atomic stream
  allocator, Read-EvidenceLog, Test-EvidenceLogExtension, Test-EvidencePlaneParity,
  Test-EvidenceStreamIntegrity, the guard's path canonicalisation and its protected/parent sets --
  is A1's, unmodified, executed in place.

  WHY A DELTA. LAM-ACCEPT H-4 requires the 14-check A1 negative suite to pass UNCHANGED against
  these hooks. A fork of an 80 KB library would make that a claim to be tested; a delta makes it
  true by construction for every function the delta does not name, and leaves the change surface
  small enough to review. Design SS4.5 law 6 (execution-beats-inspection) still governs: the
  instrument drives all of it.

  THE A1 LIBRARY IS NEVER MODIFIED BY THIS BUILD. It is a sealed source and protected territory;
  this file reads it the way A1's own hooks do -- by dot-sourcing it in place. No byte of
  tools/framework/** is written, moved, or re-hashed here.

  THE DELTA, per member:

  1. OWNERSHIP (H-1, amendment 2). A dispatch is RUNNER-OWNED when the runner has written an
     OWNER file into the evidence directory before spawning the worker. While an owned dispatch
     has no DISPATCH-END marker, its state derives OPEN and Stop finalizes nothing. When the
     runner writes DISPATCH-END after worker exit, the marker finalizes. An UNOWNED dispatch is
     A1 exactly: Stop finalizes, and post-finalize growth derives GREW.

     This is the reconciliation design SS4.7 D10 asks for, stated as ownership: whoever owns the
     dispatch declares its end. Where nothing owns it, the turn is the only unit there is, and
     A1's semantics are already correct -- which is why they are preserved rather than replaced.

  2. CALL-COUNTER seq (H-2). A1 derived the stream-allocation floor from log LENGTH, so a
     _precompact or _denied line shifted every later number (the sibling of an earlier defect). The floor
     now comes from a per-session counter file that counts CALLS. The atomic CreateNew allocator
     (A1, cure D11) is untouched and still decides the winning number, so seq remains unique by
     construction; the counter is a floor, never a key.

  3. outcome ON EVERY ENTRY (H-2). Log entries carry outcome: succeeded | failed | denied.
     THE FIELD LIVES IN log.jsonl AND NOWHERE ELSE. Manifest entries are schema-closed
     (evidence-manifest.schema.json:40/:55/:70, additionalProperties:false with fixed required
     lists) and log.jsonl has no declared schema (a finding registered for A2). Projecting outcome into the manifest
     would invalidate every next-gen manifest against the normative schema, so the finalizer does
     not project it. This is what keeps the manifest at 1.3.0 per ruling.

  4. capture-gaps SIDECAR (H-2). Reconciliation writes capture-gaps.yaml BESIDE the manifest --
     never into it, for the reason in (3). The runner lifts capture_gaps_sha256 and
     capture_gaps_count into the dispatch anchors (WP-2 R-3).

  5. THE WORKER'S MISSION PLANE (K-3). A dispatched worker's
     write to a `.mission/**` path outside its two closed exceptions is denied, by file tool and by
     shell. This lives here because it CANNOT LIVE IN THE PERMISSION FILE: deny is evaluated before
     allow and a deny rule cannot carry allowlist exceptions, so worker.json's blanket
     `Edit(.mission/**)` shadowed both exceptions and the number that obtained was ZERO -- with the
     WP-5 member reporting PASS throughout, because it counted rules instead of evaluating them.

     Scoped by the runner's LAM_DISPATCH marker. A role-blind rule here would refuse `git add` of
     the mission ledger and amendment placement -- ordinary ceremony, which A1's own protected/parent
     doctrine warns must not be denied. T-3 stays role-blind and is untouched.

  RESIDUAL, stated rather than argued away (design SS4.5 law 4). Ownership is declared by a FILE,
  and a file is only as trustworthy as the thing that may write it. The marker paths sit inside
  .mission-runtime/evidence, which the A1 guard already denies to every agent-side write, and
  Test-EvidenceOwnershipMarkerPath below adds an explicit second rule over the two basenames. Both
  are layer (c) -- a tripwire, not a boundary. A worker that gets past the guard can
  forge a boundary; what it cannot do is forge one silently, because the denial is recorded and
  the manifest's own hashes still have to re-derive.
#>

# The sealed A1 library, executed in place. tools/evidence-hooks-next/hooks/lib -> up three -> tools.
. (Join-Path $PSScriptRoot '..\..\..\framework\hooks\lib\evidence-common.ps1')

# Capture the A1 implementations BEFORE redefining them, so the delta can delegate rather than
# reimplement. A redefinition that cannot reach the original is a fork wearing a delta's clothes.
$script:A1_GetEvidenceState        = ${function:Get-EvidenceState}
$script:A1_GetEvidenceGuardDecision = ${function:Get-EvidenceGuardDecision}

$script:EvidenceOwnerFileName   = 'OWNER'
$script:EvidenceEndMarkerName   = 'DISPATCH-END'
$script:EvidenceSeqCounterName  = 'seq.counter'
$script:EvidenceGapsSidecarName = 'capture-gaps.yaml'
$script:EvidenceNextGeneration  = 'evidence-hooks-next/1'
# WHERE THE PROCESS IS STANDING, for the duration of one hook invocation. Initialised HERE and not
# only assigned inside Get-EvidenceGuardDecision: an uninitialised $script: variable read as a
# parameter default THROWS, so any caller reaching a path predicate by another route -- another
# hook, a test, a future entry point -- died instead of judging. Empty means "unknown", which
# reproduces the previous behaviour exactly: command-text forms only, nothing widened, nothing hidden.
$script:EvidenceCwd = ''

# --- THE CASE CURE (V-1 round 3, WP-4) --------------------------------------------------------
function Test-PathHit {
    <#
      THE MOST SERIOUS DEFECT THIS BUILD HAS FOUND, and it is one character of intent.

      A1's form is `[regex]::IsMatch($Text, $rx)` -- CASE-SENSITIVE. Every sibling predicate in the
      guard is case-insensitive (PowerShell's `-match` is by default); this one is not, and it is
      the one the whole protected-path tier runs through. On Windows the filesystem is
      case-INSENSITIVE, so an upper-cased spelling names the SAME REAL FILE and was ALLOWED:

          .MISSION/EVIDENCE/x/log.jsonl            the evidence plane
          .MISSION-RUNTIME/EVIDENCE/x/log.jsonl    the runtime plane
          TOOLS/FRAMEWORK/HOOKS/lib/...            the sealed guard library ITSELF
          .CLAUDE/SETTINGS.JSON                    the settings file
          .MISSION/GATES/push-forged.yaml          -- an agent mints its own push authorization

      An independent validator drove the last one end to end: write a gate face, copy it in with an
      upper-cased path, `mission-gate.ps1 list` reads it back as a valid open build-authorization
      gate, and `git push` answers "push authorized". THAT VOIDS THE AGENT-UNMINTABILITY that T-3,
      R-1, amendment 6 and amendment 15 all cite BY NAME as their compensating control -- including
      a sentence I wrote and committed earlier in this same session.

      WHY THE FIX LIVES HERE AND IS ONE FUNCTION. A1's `Get-EvidencePathHits` calls `Test-PathHit`
      BY NAME, so redefining it in this delta cures the delegated A1 decision path too. One
      predicate, one place -- the law this build keeps restating. Redefining the caller instead
      would have put the boundary regex in two places, which is the defect one layer over.

      DIRECTION: this can only ADD denials, never remove one. Widening a guard is safe only in the
      fail-closed direction, and this is that direction. H-4 (the 14-check A1 negative suite) is
      re-run against it, because "can only add denials" is a claim about the suite too.

      THE SEALED LIBRARY STILL HAS THE DEFECT. This build may not write
      tools/framework/hooks/**; the same change there is an OPERATOR step, carried in
      LAM-INSTALL SS5.3.
    #>
    param([AllowNull()][string]$Text, [string]$Pattern)
    if (-not $Text) { return $false }
    $rx = [regex]::Escape($Pattern) + '(?=$|[/\s;,:|&)\]}"''`]|\\)'
    return [regex]::IsMatch($Text, $rx, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

# --- ownership -------------------------------------------------------------------------------

function Get-EvidenceOwnerPath {
    param([string]$Root, [string]$DispatchId)
    Join-Path (Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId) $script:EvidenceOwnerFileName
}

function Get-EvidenceEndMarkerPath {
    param([string]$Root, [string]$DispatchId)
    Join-Path (Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId) $script:EvidenceEndMarkerName
}

# A dispatch is runner-owned iff the OWNER file exists. Presence is the whole test: the file's
# CONTENT (runner id, dispatch id, spawn timestamp) is for the human and the audit trail, and
# parsing it here would make a malformed line silently un-own a dispatch -- failing toward A1
# semantics, which is the direction that finalizes early. Presence cannot fail that way.
function Test-EvidenceRunnerOwned {
    param([string]$Root, [string]$DispatchId)
    return (Test-Path -LiteralPath (Get-EvidenceOwnerPath -Root $Root -DispatchId $DispatchId))
}

function Test-EvidenceDispatchEnded {
    param([string]$Root, [string]$DispatchId)
    return (Test-Path -LiteralPath (Get-EvidenceEndMarkerPath -Root $Root -DispatchId $DispatchId))
}

# Is this path one of the two ownership markers? Used by the guard delta. The test is deliberately
# NARROW -- basename match AND an evidence-directory segment -- because a bare 'OWNER' pattern in
# the protected list would deny ordinary paths like docs/OWNERS.md, and a guard that denies
# ordinary work is a guard that gets switched off (a cure's own rationale).
function Test-EvidenceOwnershipMarkerPath {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    $canon = ConvertTo-CanonicalPathText -Text $Path
    $leaf  = $canon.TrimEnd('/').Split('/')[-1]
    if (($leaf -ne $script:EvidenceOwnerFileName) -and ($leaf -ne $script:EvidenceEndMarkerName)) { return $false }
    return ($canon -match '(^|/)\.mission(-runtime)?/evidence/')
}

# --- the state machine, with OPEN ------------------------------------------------------------
# OPEN is DERIVED, never stored. The manifest's `state` field is enum ["finalized"] in the
# normative schema (evidence-manifest.schema.json:28) and this delta does not touch it -- OPEN
# joins PARTIAL and GREW as a state the machine derives from disk, exactly as A1 derives those.
#
# ORDERING MATTERS. Ownership is consulted BEFORE delegating, but ONLY to answer "is this
# dispatch still running?". Everything a finalized store can be -- FINALIZED, TAMPERED, GREW --
# is A1's verdict, unmodified. An owned dispatch that HAS ended is not special-cased at all.
function Get-EvidenceState {
    param([string]$Root, [string]$DispatchId)

    $rt      = Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId
    $logPath = Join-Path $rt 'log.jsonl'
    $manPath = Join-Path $rt 'manifest.json'

    $owned = Test-EvidenceRunnerOwned    -Root $Root -DispatchId $DispatchId
    $ended = Test-EvidenceDispatchEnded  -Root $Root -DispatchId $DispatchId

    if ($owned -and -not $ended -and (Test-Path -LiteralPath $logPath)) {
        $errPath = Join-Path $rt 'hook-errors.log'
        $errHint = if (Test-Path -LiteralPath $errPath) { " hook-errors.log EXISTS -- read it before concluding anything about cause." } else { "" }
        return [pscustomobject]@{
            state    = 'OPEN'
            reason   = "runner-owned dispatch with no DISPATCH-END marker: the runner has not declared the boundary, so the log is still being appended to and nothing has been sealed. This is a LIFECYCLE fact, not an integrity finding -- a session that keeps working derives OPEN, never TAMPERED.$errHint"
            log_path = $logPath; manifest_path = $manPath
            consumable = $false          # nothing is sealed yet; consumption is blocked
            forensics  = $true           # the log is fully readable for forensic re-ground
        }
    }

    return (& $script:A1_GetEvidenceState -Root $Root -DispatchId $DispatchId)
}

# --- call-counter seq (H-2) -------------------------------------------------------------------
# A1 took the allocation floor from log length. That is wrong for two independent reasons: a
# _precompact line and a _denied line each consume a log line without being a tool call, so the
# floor jumped past numbers no call had used, and the gap was indistinguishable from a dropped
# capture. The counter counts CALLS, so a gap in the call sequence means a call was lost.
#
# The counter is a FLOOR, not a key: New-EvidenceStreamFile's atomic CreateNew probe still picks
# the winning number (A1 cure D11), so concurrent hooks cannot collide even if both read the same
# counter value. The seq-race finding is therefore still resolved the way it was resolved before.
function Get-EvidenceNextSeq {
    param([string]$Root, [string]$DispatchId)
    $rt = Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId
    if (-not (Test-Path -LiteralPath $rt)) { New-Item -ItemType Directory -Path $rt -Force | Out-Null }
    $counterPath = Join-Path $rt $script:EvidenceSeqCounterName

    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try {
            $fs = [System.IO.File]::Open($counterPath, [System.IO.FileMode]::OpenOrCreate,
                                         [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            try {
                $buf = New-Object byte[] $fs.Length
                if ($fs.Length -gt 0) { [void]$fs.Read($buf, 0, $buf.Length) }
                $cur = 0
                $txt = ([System.Text.Encoding]::UTF8.GetString($buf)).Trim()
                if ($txt -and [int]::TryParse($txt, [ref]$cur)) { } else { $cur = 0 }
                $next  = $cur + 1
                $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$next)
                $fs.SetLength(0)
                $fs.Position = 0
                $fs.Write($bytes, 0, $bytes.Length)
                return $next
            } finally { $fs.Dispose() }
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds (10 * $attempt)
        }
    }
    throw "evidence-next: could not allocate a seq from $counterPath after 20 attempts."
}

function Get-EvidenceAllocatedSeqCount {
    param([string]$Root, [string]$DispatchId)
    $counterPath = Join-Path (Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId) $script:EvidenceSeqCounterName
    if (-not (Test-Path -LiteralPath $counterPath)) { return 0 }
    $cur = 0
    $txt = ([System.IO.File]::ReadAllText($counterPath)).Trim()
    if ($txt -and [int]::TryParse($txt, [ref]$cur)) { return $cur }
    return 0
}

# --- capture gaps (H-2), as a SIDECAR ---------------------------------------------------------
# THE DERIVATION, stated so a reader can check it rather than trust it: the counter records how
# many call slots were ALLOCATED; the log records which slots actually landed an entry. A slot
# with no entry is a capture gap. This is the accounting E5-ii/iii left empty -- pre-cure, a call
# that failed or was refused left no entry, no hook error and no seq gap, so an agent that never
# ran the suite left the same evidence as one whose run failed: none.
#
# THE COUNTER ARM ALONE IS STRUCTURALLY BLIND, and this comment used to say the opposite -- that
# the gap list "needs no transcript". It does. H-2's clause says Stop-time reconciliation compares
# THE TRANSCRIPT'S tool-call count with the log, and the substitution is load-bearing rather than
# cosmetic: THE COUNTER INCREMENTS INSIDE PostToolUse. A call that never reaches PostToolUse
# increments nothing and logs nothing, so it is invisible to BOTH sides of a counter-vs-log
# comparison, and the sidecar reports capture_gaps: [] over a call that vanished.
#
# Demonstrated, not theorised (V-1 round 2, WP-1): two probes run back to back, the successful one
# logged and the failing one leaving no entry, no hook error and no seq gap -- and the sidecar
# calling that a clean capture. Which is exactly the E5-ii condition this sidecar exists to end.
#
# BOTH ARMS NOW RUN, and each says what it can and cannot see. The counter arm finds allocated slots
# with no entry -- a gap WITH a seq. The transcript arm finds calls the harness resolved that the
# store never recorded -- a gap with NO seq, because there is no slot to name. Neither subsumes the
# other, and reporting only the first was the defect.
function Get-EvidenceCaptureGaps {
    param([string]$Root, [string]$DispatchId, [AllowNull()][string]$TranscriptPath = '',
          [AllowNull()][string]$SessionId = '')

    $rt      = Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId
    $logPath = Join-Path $rt 'log.jsonl'
    $allocated = Get-EvidenceAllocatedSeqCount -Root $Root -DispatchId $DispatchId

    # DECIDED BEFORE THE LOG IS READ, from the same facts the arm choice below uses: a transcript
    # path was supplied (per-SESSION, so filter) or it was not (the worker stream will be used, which
    # is per-DISPATCH, so do not). Computing it here rather than beside the arm keeps one statement
    # of the rule instead of two that can drift -- which is the defect class this file has now
    # recorded nine times.
    $logFilterSession = if ($TranscriptPath) { $SessionId } else { '' }

    $seen = @{}
    $entries = 0
    # DENIED CALLS ARE COUNTED SEPARATELY, NOT DISCARDED (amendment 16). They are excluded from
    # $entries because they allocate no seq slot, but they ARE tool calls and they DO appear in the
    # transcript -- so if the transcript arm did not know about them, every denial would read as a
    # missing record and the sidecar would fill with false gaps. A gap detector that cries wolf is
    # switched off as surely as one that stays silent.
    $deniedEntries = 0
    # =============================================================================================
    # THE TWO SIDES MUST DESCRIBE THE SAME POPULATION (V-1 round 4, WP-1).
    # =============================================================================================
    # The log is per-DISPATCH; the transcript is per-SESSION. Subtracting one from the other was not
    # a reconciliation but a NET DIFFERENCE, so a SURPLUS on one side cancelled a DEFICIT on the
    # other, one for one, and `capture_gaps: []` was reported over a call that had vanished. Two
    # driven instances, each against a control differing by a single record: a subagent
    # (`isSidechain`) call the summariser deliberately excludes from the transcript count but whose
    # PostToolUse entry lands in this same store; and two sessions sharing one dispatch id.
    #
    # So the log side is FILTERED TO THE SESSION the transcript describes, and the transcript side
    # is asked for that same session. Where no session is known the arms are not comparable, and
    # that is reported rather than papered over -- an unscoped comparison is the defect, not a
    # weaker version of the check.
    foreach ($e in @(Read-EvidenceLog -LogPath $logPath)) {
        if ((Get-EntryField $e '_unparsable' $false)) { continue }
        $tool = [string](Get-EntryField $e 'tool' '')
        if ($tool -eq '_precompact') { continue }
        # THE FILTER BELONGS TO THE ARM, NOT TO THE CALLER'S STRING (V-1 round 7, WP-1).
        #
        # This discarded every entry on the delivered path. The runner passes a SYNTHETIC
        # `session-<Dispatch>` -- an id it composes to locate the store -- while PostToolUse stamps
        # entries with the WORKER'S REAL HARNESS session id. One string doing two jobs: addressing a
        # store and filtering its contents, in namespaces that never match. A store with nothing
        # missing reported 36, 35 and 13 phantom gaps on three live mirrors.
        #
        # Session filtering exists for the per-SESSION transcript arm, where the log (per-DISPATCH)
        # and the transcript (per-SESSION) genuinely describe different populations. When the second
        # arm is the worker STREAM, both sides are already per-dispatch and there is nothing to
        # reconcile away -- so filtering there subtracts the entire population instead.
        #
        # `$logFilterSession` is set below, from the ARM, and is empty whenever the arm is
        # per-dispatch. Scope both the same way, or neither.
        if ($logFilterSession) {
            $esid = [string](Get-EntryField $e 'session_id' '')
            if ($esid -and ($esid -ne $logFilterSession)) { continue }
        }
        if ($tool -eq '_denied') { $deniedEntries++; continue }
        $entries++
        $s = Get-EntryField $e 'seq' $null
        if ($null -ne $s) { $seen[[int]$s] = $true }
    }

    $gaps = New-Object System.Collections.Generic.List[object]
    for ($i = 1; $i -le $allocated; $i++) {
        if (-not $seen.ContainsKey($i)) {
            $gaps.Add([pscustomobject]@{
                seq    = $i
                reason = 'seq allocated by the call counter; no log entry carries it -- the entry was never written, or was removed after the fact'
            })
        }
    }
    # --- THE TRANSCRIPT ARM (H-2 as rewritten by amendment 16) ----------------------------------
    # A1 already knows how to read a transcript; this reuses its summariser rather than parsing the
    # format a second time.
    #
    # IT COUNTS ALL TOOL CALLS, REGARDLESS OF OUTCOME, AND THAT IS THE WHOLE CURE.
    # It used to compare `succeeded`, which made this arm blind to exactly the population it exists
    # to find: a FAILED call never reaches PostToolUse, so it writes no log entry AND is not
    # `succeeded` -- invisible to the counter arm and to the transcript arm alike (erratum E45).
    # Both arms shared one failure mode, which is not a reconciliation at all: it is one measurement
    # taken twice.
    #
    # `tool_use_total` is written by the harness, OUTSIDE the capture path, which is the property
    # that makes it a real second opinion. Every tool call must be accounted for as either a normal
    # log entry or a `_denied` record; anything left over never reached the store.
    $trStatus  = 'not-attempted'
    $trCalls   = $null
    $trSucceed = $null
    $trSha     = $null

    # ==============================================================================================
    # WHICH SECOND ARM, AND THE DELIVERED LIFECYCLE HAD NONE (V-1 round 6, WP-1).
    # ==============================================================================================
    # H-2's asserted property is that a vanished call can never coexist with an empty sidecar. For a
    # RUNNER-OWNED dispatch it could: the Stop hook is a no-op there, so `evidence-dispatch-end.ps1`
    # is the only writer, and it can learn a transcript path from nothing but its stdin payload --
    # which the runner filled with `{"session_id": ...}` and nothing else. So `$TranscriptPath` was
    # empty, this whole block was skipped, and the sidecar reported on the COUNTER ARM ALONE: the arm
    # that increments INSIDE PostToolUse, which E45 established cannot see a call that never got
    # there. Every owned dispatch in the live smoke plane shows exactly that.
    #
    # The library was internally inconsistent about it, which is the part that should have been
    # caught here rather than by a reader: a transcript NAMED BUT UNREADABLE raised a gap, a MISSING
    # SESSION ID raised a gap, and NO TRANSCRIPT AT ALL raised none -- and that third branch is the
    # one the canonical lifecycle always takes. I enumerated the failure modes I was thinking about
    # and left the default.
    #
    # THE WORKER'S OWN STREAM IS A REAL SECOND ARM, and it was already on disk. The runner tees
    # `claude -p --output-format stream-json` into runner-stream.jsonl, which carries the worker's
    # tool_use and tool_result records in the SAME record shape the sealed summariser parses.
    # Measured against the five live owned dispatches: on four of them the stream's succeeded count
    # equals the store's logged count and the stream's denied count equals the store's denial
    # records, EXACTLY; the fifth is a dispatch that was retried while its store accumulated, and the
    # surplus branch reports it. Each also shows 2-3 FAILED calls -- precisely the population H-2
    # exists to name, and precisely what the counter arm cannot see.
    #
    # PROVENANCE, STATED PLAINLY BECAUSE IT IS WEAKER. A transcript is written by the harness. This
    # stream is harness-PRODUCED content written by the RUNNER, so it is one remove further from the
    # source. What matters for E45 is preserved and is the whole reason it qualifies: it does not
    # increment inside PostToolUse, so it can see a call that never reached it. The basis line says
    # which arm ran, so no reader has to infer it.
    #
    # NO SESSION FILTER FOR THE STREAM. It is per-DISPATCH by construction -- one file, one worker --
    # so both arms already describe one population. Filtering it by the runner's synthetic
    # `session-<id>` would match nothing: the stream carries the worker's REAL harness session id.
    $armPath   = $TranscriptPath
    $armKind   = 'transcript'
    $armSession = $SessionId
    if (-not $armPath) {
        $streamCandidate = Join-Path $rt 'runner-stream.jsonl'
        if (Test-Path -LiteralPath $streamCandidate) {
            $armPath    = $streamCandidate
            $armKind    = 'worker-stream'
            $armSession = ''
        }
    }
    if (-not $armPath) {
        # NEITHER ARM. This is the branch that used to be silent, and silence here is the exact
        # claim the artifact must never make: the counter arm alone cannot see a vanished call, so a
        # reconciliation that ran only that arm has not reconciled anything.
        $trStatus = 'no-second-arm'
        $gaps.Add([pscustomobject]@{
            seq    = 'null'
            reason = "NO SECOND ARM WAS AVAILABLE: no transcript path was supplied and no runner-stream.jsonl was found for this dispatch, so the only arm that ran is the call counter -- which increments INSIDE PostToolUse and therefore cannot see a call that never reached it. This is not a clean capture; it is an unreconciled one"
        })
    }
    if ($armPath) {
        $summary = Get-EvidenceTranscriptCallSummary -TranscriptPath $armPath -SessionId $armSession
        if ($null -ne $summary -and $summary.readable) {
            $trStatus  = 'read'
            $trCalls   = [int]$summary.tool_use_total
            $trSucceed = [int]$summary.succeeded
            $trSha     = $summary.transcript_sha256
            $trFailed  = [int]$summary.failed
            $trDenied  = [int]$summary.denied
            # THE TWO STATES MY OWN CURE STOPPED READING (V-1 round 5, self-audit). The summariser
            # classifies calls into FIVE states plus a line counter; the per-category rewrite read
            # three. The arithmetic it replaced was `tool_use_total - accounted`, and tool_use_total
            # INCLUDES unresolved calls -- so the old net difference reported them and the new,
            # stronger form did not. A cure that widens one axis while narrowing another is not
            # finished, and this one narrowed the axis that matters most.
            $trUnres   = [int]$summary.unresolved
            $trUndec   = [int]$summary.undecidable
            $trUnparse = [int]$summary.unparsable_lines
            if (-not $logFilterSession -and $armKind -eq 'transcript') {
                # UNSCOPED IS UNCOMPARABLE. Without a session the log side may hold entries from
                # sessions the transcript never described, and any arithmetic over the two is a
                # coincidence. Reported as a gap, because "we could not compare" must never read as
                # "nothing was lost".
                $gaps.Add([pscustomobject]@{
                    seq    = 'null'
                    reason = "the reconciliation ran WITHOUT a session id, so the per-dispatch log and the per-session transcript may describe different populations and their difference means nothing. Not a clean capture -- an uncomparable one"
                })
            }
            else {
                # =================================================================================
                # RECONCILED PER OUTCOME CATEGORY, IN BOTH DIRECTIONS -- NEVER AS ONE SUBTRACTION.
                # =================================================================================
                # A single `transcript_total - accounted` was still a NET DIFFERENCE, and a net
                # difference of the right size is indistinguishable from nothing happening. It was
                # driven: a subagent call, hook-captured into this store but excluded from the
                # transcript count by design, cancelled a vanished failing call EXACTLY, and the
                # sidecar read `capture_gaps: []` over a call that was gone. Reporting a surplus
                # separately does not help when the two are the same subtraction; the categories
                # have to be kept apart so a surplus in one cannot pay for a deficit in another.
                #
                # THE CATEGORIES, and why each is the pairing it is:
                #   failed    -- PostToolUse does not fire on a failed call, so EVERY failed call in
                #                the transcript is by construction a call with no log entry. It is
                #                not a discrepancy to be netted; it IS the population H-2 names.
                #   succeeded -- pairs one-to-one with an ordinary log entry.
                #   denied    -- pairs one-to-one with a `_denied` record.
                # A1's own call_completeness block reconciles the last two by ABSOLUTE difference
                # per category, and in the driven case above it correctly read "incomplete" in the
                # same finalize in which this sidecar read clean. The capture point H-2 nominates
                # was strictly weaker than the block beside it; it no longer is.
                if ($trFailed -gt 0) {
                    # NO seq, AND THAT IS THE POINT. These calls never allocated a slot, which is
                    # why the counter cannot see them and why a seq cannot be named for them.
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "post-hook-not-fired: the transcript records $trFailed FAILED tool call(s) for this session, and PostToolUse does not fire on a failed call -- so each left no log entry at all. The call counter cannot see them either, because it increments INSIDE PostToolUse. Reported on its own rather than folded into a total: a vanished call can never coexist with an empty sidecar"
                    })
                }
                $dSucc = $trSucceed - $entries
                if ($dSucc -gt 0) {
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "post-hook-not-fired: $trSucceed call(s) SUCCEEDED in this session's transcript against $entries ordinary log entr(y/ies) -- $dSucc succeeded call(s) reached no record. A successful call that leaves no entry is the capture path failing on its own terms"
                    })
                }
                elseif ($dSucc -lt 0) {
                    # A SURPLUS IS AN ANOMALY IN ITS OWN RIGHT. The store holds entries this
                    # session's transcript does not explain -- a foreign writer, a shared dispatch
                    # id, or a subagent call the summariser excludes by design. Any of those means
                    # the arms describe different populations, and a misaligned reconciliation that
                    # returns zero is the exact failure this cure exists to end.
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "store SURPLUS: $entries ordinary log entr(y/ies) against $trSucceed succeeded call(s) in this session's transcript -- $([Math]::Abs($dSucc)) entr(y/ies) the transcript does not explain. Reported rather than netted off: a surplus that cancels a shortfall is how a vanished call once came to sit beside an empty sidecar"
                    })
                }
                $dDenied = $trDenied - $deniedEntries
                if ($dDenied -gt 0) {
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "denial NOT RECORDED: the transcript carries $trDenied guard-denied call(s) for this session against $deniedEntries '_denied' record(s) in the store -- $dDenied denial(s) the guard did not write down. A denial that leaves no record is a refusal nobody can audit"
                    })
                }
                elseif ($dDenied -lt 0) {
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "denial-record SURPLUS: $deniedEntries '_denied' record(s) against $trDenied denied call(s) in this session's transcript -- $([Math]::Abs($dDenied)) record(s) the transcript does not explain"
                    })
                }
                # THE STATES THAT ARE NOT AN OUTCOME AT ALL, AND THEY MAY NOT NET EITHER.
                #
                # `unresolved` is a tool_use the transcript never resolves: no outcome record, so no
                # PostToolUse, so no log entry. That is PRECISELY the population H-2 names, and the
                # three-category comparison above cannot see it, because it belongs to none of them.
                # A session that stops while a call is in flight leaves exactly this shape, and Stop
                # time is when that is likeliest -- so the artifact whose whole claim is "a vanished
                # call can never coexist with an empty sidecar" was returning clean for the most
                # reachable case there is.
                #
                # Found by auditing my own cure against the rule I had just written for other
                # people's code (E56), not by a reader. A1's `call_completeness` has always reported
                # these as `unreconciled`, and I read that function while designing this one: I took
                # its per-category arithmetic and left the branch directly beneath it. Round 4's
                # finding was that this sidecar was weaker than the block beside it. It is the
                # capture point H-2 nominates; it may not be the weaker of the two.
                if ($trUnres -gt 0) {
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "post-hook-not-fired: $trUnres tool call(s) in this session's transcript were never resolved -- a tool_use with no result record, so no outcome, no PostToolUse and no log entry. Reported in its own right rather than folded into a total: an unresolved call is not a smaller version of a completed one"
                    })
                }
                if ($trUndec -gt 0) {
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "$trUndec transcript record(s) fall outside the derived record shape, so this session's calls cannot be fully classified and the two arms cannot be aligned. Undecidable is reported, never rounded toward clean"
                    })
                }
                if ($trUnparse -gt 0) {
                    $gaps.Add([pscustomobject]@{
                        seq    = 'null'
                        reason = "$trUnparse transcript line(s) did not parse, so the transcript arm is PARTLY unreadable. A partial read is a partial reconciliation, and the difference between the arms means correspondingly less"
                    })
                }
            }
        }
        else {
            # FAIL LOUD, NOT SILENT. A transcript named and unreadable is a gap in the gap
            # accounting, which is the one thing this artifact must never report as clean.
            $trStatus = 'unreadable'
            $gaps.Add([pscustomobject]@{
                seq    = 'null'
                reason = "the $armKind arm was named ($armPath) but could not be read, so the second arm of this reconciliation did not run. The counter arm's result below stands alone and CANNOT see a call that never reached PostToolUse"
            })
        }
    }

    return [pscustomobject]@{
        gaps              = $gaps.ToArray()
        allocated         = $allocated
        logged_calls      = $entries
        denied_calls      = $deniedEntries
        transcript_status = $trStatus
        transcript_calls  = $trCalls
        transcript_succeeded = $trSucceed
        transcript_sha256 = $trSha
        basis             = $(if ($trStatus -eq 'read') { "call-counter vs log.jsonl AND $armKind vs log.jsonl" }
                              elseif ($trStatus -eq 'unreadable') { 'call-counter vs log.jsonl ONLY -- the named transcript was unreadable' }
                              else { 'call-counter vs log.jsonl ONLY -- NO SECOND ARM was available, so nothing here can see a call that never reached PostToolUse' })
    }
}

# YAML is hand-emitted rather than piped through a converter: PS 5.1 ships no YAML writer, the
# document is four fields deep, and the sidecar is schema-free by ruling. Values
# that reach the file are integers and a fixed reason string -- nothing here interpolates
# attacker-controlled text into a YAML scalar.
function Write-EvidenceCaptureGapsSidecar {
    param([string]$Root, [string]$DispatchId, [AllowNull()][string]$TranscriptPath = '',
          [AllowNull()][string]$SessionId = '')

    $rt   = Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId
    $path = Join-Path $rt $script:EvidenceGapsSidecarName
    $d    = Get-EvidenceCaptureGaps -Root $Root -DispatchId $DispatchId -TranscriptPath $TranscriptPath -SessionId $SessionId

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# capture-gaps sidecar -- LAM-ACCEPT WP-1 H-2. Schema-free by ruling.")
    [void]$sb.AppendLine("# The manifest beside this file stays at schema_version 1.3.0 and carries no capture_gaps field.")
    [void]$sb.AppendLine("generator: $($script:EvidenceNextGeneration)")
    [void]$sb.AppendLine("dispatch_id: $DispatchId")
    [void]$sb.AppendLine("derived_at: $(Get-UtcStampZ)")
    [void]$sb.AppendLine("basis: $($d.basis)")
    [void]$sb.AppendLine("seq_allocated: $($d.allocated)")
    [void]$sb.AppendLine("logged_calls: $($d.logged_calls)")
    # Emitted so a reader can re-derive the shortfall arithmetic from the sidecar's own face rather
    # than trusting the reason string: transcript_calls - (logged_calls + denied_calls).
    [void]$sb.AppendLine("denied_calls: $($d.denied_calls)")
    # THE TRANSCRIPT ARM IS REPORTED WHETHER OR NOT IT RAN. A reader must be able to tell a clean
    # reconciliation from one that only had half its evidence, and the difference is invisible if
    # the field is simply omitted when the transcript was absent.
    [void]$sb.AppendLine("transcript_status: $($d.transcript_status)")
    [void]$sb.AppendLine("transcript_calls: $(if ($null -ne $d.transcript_calls) { $d.transcript_calls } else { 'null' })")
    [void]$sb.AppendLine("transcript_succeeded: $(if ($null -ne $d.transcript_succeeded) { $d.transcript_succeeded } else { 'null' })")
    [void]$sb.AppendLine("transcript_sha256: $(if ($d.transcript_sha256) { $d.transcript_sha256 } else { 'null' })")
    [void]$sb.AppendLine("capture_gaps_count: $(@($d.gaps).Count)")
    if (@($d.gaps).Count -eq 0) {
        [void]$sb.AppendLine("capture_gaps: []")
    } else {
        [void]$sb.AppendLine("capture_gaps:")
        foreach ($g in @($d.gaps)) {
            [void]$sb.AppendLine("  - seq: $($g.seq)")
            [void]$sb.AppendLine("    reason: `"$($g.reason)`"")
        }
    }
    [System.IO.File]::WriteAllText($path, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    return [pscustomobject]@{
        path   = $path
        count  = @($d.gaps).Count
        sha256 = (Get-Sha256OfFile -Path $path)
    }
}

# --- denial recording, with outcome (H-2) -----------------------------------------------------
# A1's Write-EvidenceDeniedRecord already writes the '_denied' variant with the verbatim reason
# (cure D8). The delta adds `outcome: denied` so that every log entry -- succeeded, failed
# and denied alike -- answers the same question in the same field, instead of the reader having to
# infer outcome from which variant a line happens to be.
function Write-EvidenceDeniedRecord {
    param([AllowNull()][string]$SessionId, [AllowNull()][string]$ToolName, $ToolInput,
          [AllowNull()][string]$Reason)
    $command = $null
    if ($null -ne $ToolInput) {
        if ($ToolInput -is [string]) { $command = $ToolInput }
        elseif ($ToolInput.PSObject.Properties.Name -contains 'command')   { $command = [string]$ToolInput.command }
        elseif ($ToolInput.PSObject.Properties.Name -contains 'file_path') { $command = "$ToolName $($ToolInput.file_path)" }
        elseif ($ToolInput.PSObject.Properties.Name -contains 'pattern')   { $command = "$ToolName $($ToolInput.pattern)" }
        else { $command = ($ToolInput | ConvertTo-Json -Compress -Depth 8) }
    }
    $root       = Get-EvidenceRepoRoot
    $dispatchId = Get-EvidenceDispatchId -SessionId $SessionId
    $rt         = Get-EvidenceRuntimeDir -Root $root -DispatchId $dispatchId
    Add-EvidenceLogLine -LogPath (Join-Path $rt 'log.jsonl') -Entry ([ordered]@{
        ts          = Get-UtcStampZ
        session_id  = $SessionId
        dispatch_id = $dispatchId
        tool        = '_denied'
        denied_tool = $ToolName
        command     = $command
        reason      = $Reason
        outcome     = 'denied'
        path        = $null
    })
}

# --- guard decision, with the ownership-marker rule (H-1) --------------------------------------
# The two marker paths already sit under .mission-runtime/evidence and are therefore ALREADY
# denied by A1's protected set -- this rule is a second, explicit statement of the same refusal,
# added because amendment 2 requires the markers to be named rather than merely covered. It is
# checked BEFORE delegating so the denial reason names the boundary rather than the directory,
# which is what a reader of the log needs to see.
#
# It can only ever deny MORE than A1, never less, and it is scoped by
# Test-EvidenceOwnershipMarkerPath to paths that carry an evidence-directory segment -- so no
# ordinary write acquires a new refusal, and the A1 negative suite's allow population is unmoved.
# --- push authorization (LAM-ACCEPT WP-4 T-2, ADR-033) -----------------------------------------
# Design SS10.5: publishing to origin is an operator-gated irreversible. In Local Autonomous Mode
# there is no paste to serve as the authorization act, so the gate takes physical form -- an
# artifact the human created, hash-bound to one exact tip.
#
# THE TWO HOLES, CLOSED HERE RATHER THAN DESCRIBED (schemas SS13):
#   TOCTOU     -- the tip is RE-DERIVED AT PUSH TIME, inside this function, and compared exactly.
#                 An authorization is for one commit; anything landing after it voids it.
#   SINGLE USE -- a consumed or revoked or expired gate is refused. Consumption is stamped by the
#                 PostToolUse hook, which on this harness fires ONLY on successful, permitted
#                 calls (E5-ii) -- so its firing IS the evidence that the push happened. That
#                 quirk, which cost the program an erratum, is exactly the right instrument here.
# ONE DEFINITION OF THE QUOTE SET (V-1 round 7, WP-4). It was written out separately in the
# classifier and in the resolver, and the two then normalised WITH IT DIFFERENTLY -- the
# classifier tried a quote-DELETED variant as well, the resolver only ever spaced them. That is
# the whole of the second defect this round cured: a quoted --git-dir split for one and not the
# other, so a command was classified as a push and resolved to the WRONG REPOSITORY.
$script:EvidenceQuoteChars = '["' + "'" + '`]'

# POSITIONAL SUBCOMMAND (3), WITH GIT'S VALUE-TAKING MAIN OPTIONS SKIPPED (round 4).
#
# THE NARROWING IN (3) OPENED A NEW HOLE, and this is the repair. Only `-C` was treated
# as taking a separated value, so for every OTHER value-taking main option the scan
# broke on the option's VALUE and never reached `push`:
#     git --git-dir .git push      git --work-tree . push     git --namespace ns push
#     git --super-prefix p push    git --attr-source r push   git --config-env k=v push
# All allowed, no gate, no denial record -- while the attached forms (`--git-dir=.git`)
# correctly denied, which is what localised it. Driven by an independent reader against
# real git (V-1 round 4, WP-4).
#
# THE LESSON, recorded because it is the same one twice: I special-cased ONE member of a
# family. `-C` was the option I happened to think of; git has a closed set of them, and a
# closed set is enumerable. It is listed here in full rather than sampled.
#
# ANYTHING UNRECOGNISED THAT LOOKS LIKE AN OPTION IS SKIPPED, NOT BROKEN ON: a future
# git option this list does not know must not silently become "the subcommand", because
# that reads as "not a push" -- the fail-OPEN direction. An unknown option defers; only a
# NON-option token decides.

$script:EvidenceGitValueOpts = @('-C', '-c', '--git-dir', '--work-tree', '--namespace',
    '--super-prefix', '--exec-path', '--attr-source', '--config-env', '--object-directory')

# =================================================================================================
# THE FOURTH PUSH OVER-REFUSAL -- A GIT SEGMENT WITH NO POSITIONAL TOKEN AT ALL.
# =================================================================================================
# WHAT THE ROW RECORDS, and it is the sequel LAM-ACCEPT H-5/H-6 left open by name: a segment naming
# git with NO POSITIONAL TOKEN AT ALL -- `git --version`, `git --list-cmds=main`, `git --exec-path`
# -- was classified a PUBLICATION by the fail-closed "no shape at all is the most unrecognised
# shape" rule at the foot of Get-EvidenceCommandGitScan. It refused this build's own census
# command. Driven at the base of this edit: eleven such shapes, every one class=push, Test=True.
#
# THE RULE IS NOT RELAXED; ONE CORNER OF IT IS NARROWED. "No positional token" still refuses. What
# is admitted is the single case where the absence of a positional token is not an unrecognised
# shape but a KNOWN one: git invoked purely to report on ITSELF. Every member below prints and
# exits, none of them can reach a remote, and -- this is the load-bearing half -- none of them
# takes a SEPARATED value, so none can swallow the token that follows it.
#
# THE FALSE-ALLOW HAZARD THIS LIST IS SHAPED AROUND, which is why the row demanded its own
# analysis. The scan does `$j++` on a member of $script:EvidenceGitValueOpts above -- it SWALLOWS
# THE NEXT TOKEN. So `git --exec-path push origin main` reaches the end of the loop with
# $sawPositional = $false, and a naive "no positional means not-a-push" cure would ADMIT A REAL
# PUSH. The admission is therefore INVALIDATED by any token the scan consumed as a separated
# value; see $inertBroken at the branch below. `--exec-path` is admitted BARE ONLY for exactly
# that reason: it is the one option that appears in both roles, and only its bare form reports.
#
# MUST STAY ABSENT, named here so a later tidier cannot re-add them by symmetry -- the device H-5
# uses at LAM-ACCEPT.md:138-141: `-c`, `-C`, `--git-dir`, `--work-tree`, `--namespace`,
# `--super-prefix`, `--attr-source`, `--config-env`, `--object-directory`. EACH TAKES A VALUE, and
# `git -c alias.zz=push zz origin` is precisely the alias route H-5 documents as the fail-OPEN
# class. Also absent on purpose: the BARE `--list-cmds` (a usage error, not a query) and any
# `--exec-path=<path>` attached form, which SETS the exec path rather than reporting it.
#
# THE LIST MUST STAY LITERAL. Deriving it at runtime -- from `git --list-cmds`, from parsing
# `git --help`, from anything git itself says -- would let a future git version silently widen
# what the gate admits, which is the fail-OPEN direction. That is the same argument LAM-ACCEPT H-5
# makes for the non-push subcommand list, and it governs here for the same reason.
$script:EvidenceGitInertBareOpts = @('--version', '--help', '-h', '--html-path', '--man-path',
    '--info-path', '--build-options', '--exec-path')

# THE ATTACHED-ONLY MEMBERS, matched by PREFIX because the value rides inside the token and there
# is nothing for the scan to swallow. `--list-cmds=main` and `--list-cmds=builtins,main` are the
# census forms this cure was opened by. The bare `--list-cmds` is deliberately NOT here.
$script:EvidenceGitInertAttachedOpts = @('--list-cmds=')

# =================================================================================================
# THE PUSH LAYER'S REFUSAL TEXT ON A NON-PUSH COMMAND.
# =================================================================================================
# WHAT THE ROW RECORDS: in the S4 worktree a `git commit -F -` with a heredoc was refused with
# "push is BLOCKED: no unconsumed push gate is bound to <sha>...". No push was attempted. The
# commit was re-issued from a message file.
#
# WHAT IT ACTUALLY WAS, driven rather than assumed: NOT a classifier defect. The commit message body
# carried BACKTICKS -- markdown code quoting of an identifier -- and the unreadable-command rule
# below fired on them. The refusal was LAWFUL under that rule. Its text misnamed the class, which is
# exactly what the row says in its own words: "The refusal was lawful under [that rule]; its text
# misnames the class."
#
# SO NO VERDICT MOVES HERE. The FINDING is split from the DECISION: this function answers WHAT the
# guard saw, and the deny site chooses the sentence. Both refusals still deny.
#
# THE ORDER OF THE TWO TESTS IS REVERSED AND THAT IS THE ONE BEHAVIOURAL CHANGE. Until now the
# unreadable test ran FIRST, so a command that was BOTH unreadable AND carried a real push segment
# -- `git ${x}push origin main` -- would have been named 'unreadable' and would have stopped being
# named a push. Testing push_segment first keeps a real publication named as a publication and can
# only strengthen the sentence, never the verdict: both branches return non-'none'.
#
# CONFIRMED BEFORE EDITING, NOT ASSUMED: no gate consumption, tombstoning or revocation is keyed off
# this deny path or off its reason text. Consumption is driven by the in-flight record `pre-push`
# writes (evidence-post-tool-use.ps1, whose own comment records that the
# block once gated on Test-EvidencePushCommand was REMOVED for being wrong in both directions), and
# `Complete-EvidencePushGate` requires the declared origin to be observed holding the authorized sha
# before spending anything. Grepped: the only reader of the string "push is BLOCKED" anywhere in the
# tree is tests/lam/instrument-WP-6.ps1:238, which COUNTS durable denial records already on disk. It
# is not a consumption path, and the real-push sentence is left byte-identical so its count is
# unaffected.
function Get-EvidenceGitRefusalClass {
    <#
      WHY IS THIS GIT COMMAND REFUSED? 'push' | 'unreadable' | 'none'.

      'push'       -- a segment naming a git executable whose positional subcommand is not a
                      recognised non-push word (or which has no positional token at all). This is
                      the inverted test; see Get-EvidenceCommandGitScan.
      'unreadable' -- the command names a git executable AND carries a shell expansion the guard
                      cannot evaluate, so it cannot be classified at all. Refused without a claim.
      'none'       -- nothing here for the publication gate to answer.

      The two refusing classes reach the SAME decision. This is a better sentence, not a softer rule.
    #>
    param([AllowNull()][string]$Command)
    if (-not $Command) { return 'none' }
    $scan = Get-EvidenceCommandGitScan -Command $Command
    # PUSH IS TESTED FIRST. See the block above: a command that is both a push and unreadable is a
    # push, and calling it unreadable would be the fail-open direction wearing a truthful word.
    if ($scan.push_segment) { return 'push' }
    # UNREADABLE COMMAND NAMING GIT -> refuse. Kept HERE and not in the scanner, because it is a
    # judgement about whether the guard can read the command at all -- not a finding about which
    # segment is a push. The resolver must not be handed a target derived from text nobody can read.
    # FIVE EXPANSION SHAPES, NOT THREE (V-1 round 9, WP-4). The test recognised `$(`, `${` and a
    # backtick, and a shell has two more ways to spell a word the guard never sees:
    #
    #   p=push; git $p origin main     -- a bare VARIABLE reference
    #   git pu"$Q"sh origin main       -- the same, spliced into the middle of the subcommand
    #   git $'\x70ush' origin main     -- ANSI-C quoting, where the shell decodes the escape
    #
    # All three were ALLOWED and each really advanced a bare origin in a repository holding NO
    # gates directory at all -- publication with no authorization artifact in existence -- while
    # plain `git push origin main` in the same repository in the same run DENIED.
    #
    # THE TEST IS APPLIED TO THE RAW COMMAND, NOT TO THE HEREDOC-STRIPPED TEXT THE SCAN READS. That
    # is deliberate and it is what keeps the recorded commit's own command refused: its backticks live in the
    # heredoc BODY, and a body is data to a shell but it is still text the guard cannot vouch for
    # when it is handed to `git commit -F -`. Verdict unchanged, sentence corrected.
    #
    # THE COST IS STATED, NOT HIDDEN: any command naming git and carrying `$VAR` or `$'` refuses,
    # so `git commit -m "$MSG"` refuses too, and so do the process queries that merely name git.exe
    # (`tasklist`, `ps`, `Get-Process`). Those are NOT cured -- they are the documented cost of the
    # inversion and of this rule. After this split they at least refuse under a sentence that says
    # what actually happened instead of naming a gate nobody asked for.
    if ($scan.names_git -and ($Command -match '\$\(|\$\{|`|\$''|\$[A-Za-z_]')) { return 'unreadable' }
    return 'none'
}

function Test-EvidencePushCommand {
    <#
      DOES THIS COMMAND PUSH? Answered by tokenising, not by one regex over the raw string.

      THE PREVIOUS FORM, `(^|[\s;&|])git\s+(-C\s+\S+\s+)?push(\s|$)`, FAILED OPEN on four shapes an
      independent validator drove (WP-4, V-1 round 2):
        git.exe push                 -- `git\s+` cannot match `git.exe`
        git --git-dir=.git push      -- the optional group admits only `-C <path>`
        (git push origin main)       -- `(` is not in the leading character class
        "git" push                   -- quotes break the same class
      Every one of them pushes. A publication gate that can be stepped around by spelling the
      executable differently is not a gate, and this is the ADR-033 irreversible.

      IT NOW FAILS CLOSED, AND THAT COSTS SOMETHING I AM STATING RATHER THAN HIDING. Quotes are
      stripped and each operator-separated segment is tokenised; a segment pushes if it names a git
      executable (`git`, `git.exe`, or any path ending in either) and carries a later bare `push`
      token. So `git log --grep push` and `echo "git push"` are ALSO treated as pushes and will be
      refused. That is the deliberate direction: a false refusal costs one re-issued command, a
      false allow costs an unauthorised publication that cannot be taken back. `--grep=push` and
      other attached forms are single tokens and do not trip it.

      THE SIGNATURE IS LOAD-BEARING AND DOES NOT MOVE. It stays a [bool] of exactly the
      same verdicts, now DEFINED in terms of Get-EvidenceGitRefusalClass rather than restating the
      rule: tests/lam/instrument-WP-4.ps1's two Test-EvidencePushCommand -Command $Cmd calls use it as a bool, and WP-4 is outside the
      declared file set of this edit. Defining it by delegation makes "the verdicts did not move"
      true by construction rather than by luck.

      WHY THE SUBCOMMAND SCAN COULD NOT CATCH THE EXPANSION SHAPES, and why the unreadable rule
      lives beside the scanner rather than inside it. The scanner strips ONE leading `$` from the
      subcommand token, so `git $'push'` rejoins to `push` and IS caught. `$'\x70ush'` is not a
      spelling of the word at all until the shell decodes it: there is no string operation on the
      command text that yields `push`, because the word does not exist yet. That is the definition
      of unreadable, so it is answered by the unreadable test rather than by teaching the scanner
      one more escape -- the enumeration of escapes is unbounded and the enumeration of "we cannot
      read this" is one rule.
    #>
    param([AllowNull()][string]$Command)
    return ((Get-EvidenceGitRefusalClass -Command $Command) -ne 'none')
}

# ONE SCAN OF A COMMAND, ANSWERING EVERY QUESTION ASKED OF IT (V-1 round 7, WP-4).
#
# TWO DEFECTS, ONE ROOT: the push CLASSIFIER and the push TARGET RESOLVER each walked the same
# command under their own normalisation, so they agreed only on the spellings that had been tested.
#
#   * A NEWLINE WAS NOT A SEPARATOR. The classifier split on [;&|()] and not on a newline, so the
#     ordinary three-line block -- `git add -A` / `git commit -m ...` / `git push origin main`,
#     which is exactly the shape the Bash tool executes -- ran forward from the FIRST `git`, saw
#     `add`, and concluded "not a push". ALLOWED: no gate, no denial record, no consumption, and
#     driven to a real publication against a bare remote. The `;` spelling of the identical act denied.
#     A1's Split-CommandSegments already splits on && || ; | AND a newline, and it lives in the file
#     this one dot-sources. The scan had been reinvented a few lines away from the splitter.
#
#   * QUOTING DEFEATED THE RESOLVER BUT NOT THE CLASSIFIER. With a quoted --git-dir the resolver
#     turned quotes into SPACES, so the option separated from its path and matched no pattern, while
#     the classifier also tried a quote-DELETED variant and still saw a push. Classified as a push,
#     resolved to the WRONG repository, authorised by the session's gate: it published a repository
#     holding no gate at all, then tombstoned the session's gate for it. Unquoted, whole-token-quoted,
#     separated-and-quoted and -C all denied, which localised it to the quoting alone.
#
# So there is now ONE scan. It reports both things the callers need -- whether the command names git
# at all, and WHICH SEGMENT is the push -- because the resolver must answer from that segment alone:
# a -C in an earlier command must not answer for a push in a later one.
# THE VERBS THAT MOVE THE PROCESS, in both shells the registered matcher covers (round 10, WP-4).
# `popd`/`Pop-Location` are excluded on purpose: they move to a location this scan cannot compute.
$script:EvidenceChdirVerbs = @('cd', 'chdir', 'pushd', 'set-location', 'sl', 'push-location')

# THE CLOSED SET OF SUBCOMMANDS THIS BUILD RECOGNISES AS NOT-A-PUSH (V-1 round 10, WP-4).
#
# Read by the inverted test in Get-EvidenceCommandGitScan: anything outside it is treated as a push
# and therefore needs a gate. It is deliberately GENEROUS -- every porcelain command this toolchain
# or an ordinary ceremony actually runs is here -- because the cost of an omission is a refused
# command, and the cost of a wrong ADDITION is an unauthorised publication. Nothing that pushes may
# be added: `push` obviously, and note that `send-email` and `request-pull` are absent by choice
# rather than by oversight, since neither is used here and both move work outward.
$script:EvidenceNonPushSubcommands = @(
    'add','am','annotate','apply','archive','bisect','blame','branch','bundle','cat-file',
    'check-attr','check-ignore','check-mailmap','checkout','cherry','cherry-pick','citool','clean',
    'clone','column','commit','commit-tree','config','count-objects','credential','describe','diff',
    'diff-files','diff-index','diff-tree','difftool','fetch','for-each-ref','format-patch','fsck',
    'gc','get-tar-commit-id','grep','gui','hash-object','help','init','instaweb','interpret-trailers',
    'log','ls-files','ls-remote','ls-tree','maintenance','merge','merge-base','merge-file','merge-tree',
    'mergetool','mv','name-rev','notes','pack-objects','pack-refs','patch-id','pull','range-diff',
    'read-tree','rebase','reflog','remote','repack','replace','rerere','reset','restore','rev-list',
    'rev-parse','revert','rm','shortlog','show','show-branch','show-ref','sparse-checkout','stash',
    'status','stripspace','submodule','switch','symbolic-ref','tag','update-index','update-ref',
    'var','verify-commit','verify-pack','verify-tag','version','whatchanged','worktree','write-tree',
    # RESTORED (V-1 round 11, WP-4): ordinary non-publishing commands were being refused, and A1's
    # own doctrine says *a guard that blocks the workflow it protects gets switched off*. Over-
    # refusal is not a T-2 violation, but it is the cost side of the inversion and it is paid down
    # here rather than left to accumulate.
    #
    # FOUR OF THE ORIGINAL NINETEEN WERE WRONG, AND THE COMMENT CLAIMING OTHERWISE WAS WORSE.
    # It read: "None of these publishes: each was checked against what it does, not against whether
    # it looked harmless." The list was written from what each subcommand is USUALLY FOR, and then
    # the sentence asserted it had been checked. `subtree` (`git subtree push`), `for-each-repo`
    # (`--config=... push`), `svn` (`dcommit`) and `lfs` (`push`) all publish. They are removed, so
    # the tripwire recognises them again.
    #
    # WHY IT MATTERS UNEVENLY, stated because the layers differ: `subtree` and `for-each-repo`
    # delegate to `git push`, so the pre-push tripwire sees them anyway -- WP-1 drove `git subtree
    # push` to a refusal with origin unmoved. `svn dcommit` and `lfs push` do NOT take git's ref-push
    # path, run no pre-push hook, and are invisible to S-4, which reads git refs. For those two,
    # THIS list is the only local layer that ever sees them. (Not driven: `svn` is not installed on
    # the build host; recorded as a reading, per amendment 20's sentence discipline.)
    'bugreport','checkout-index','commit-graph','diagnose','filter-branch','hook',
    'index-pack','merge-index','multi-pack-index','prune','prune-packed','refs','stage',
    'unpack-objects','update-server-info',
    # =============================================================================================
    # A READ-ONLY PLUMBING COMMAND WAS REFUSED AS A PUBLICATION.
    # =============================================================================================
    # THE DEFECT, reproduced before it was cured: `git unpack-file <blob>` -- which writes a
    # temporary file holding a blob's contents and touches no remote at all -- was classified as a
    # push and denied with "push is BLOCKED: no unconsumed push gate ...". Driven at the base of
    # this edit: unpack-file push=True, while its neighbour `unpack-objects` (present in the block
    # above) push=False. One word of a pair was on the list and the other was not, and nothing
    # about the two commands justifies the difference.
    #
    # THE SHAPE OF THE CURE IS THE LIST, NOT THE TEST. The order that opened this row asked for the
    # classifier to "match push VERBS, not the string git". It must not be built that way and it is
    # not: the classifier already does not match the string `git` (`git status`, `git log` and
    # `git cat-file -p HEAD` were all driven with names_git=True and ADMITTED), and a positive
    # push-verb allowlist would permanently reopen the alias hole the comment below records as
    # having been driven to a real publication -- `git -c alias.zz=push zz origin` cannot be decided
    # from the command text, because the answer lives in the repository's config. THE INVERSION
    # STAYS. The cost of the inversion is paid where it is cheap: here, in data.
    #
    # HOW THESE WORDS WERE CHOSEN, and what was NOT measured. The universe was taken from this
    # host's own git installation (2.54.0.windows.1), not from memory: the distinct subcommand names
    # under share/doc/git-doc/git-<name>.html and libexec/git-core/git-<name>, unioned -- 211 names,
    # of which 100 were absent from the list above. Each of the 29 added here was then DRIVEN
    # through Test-EvidencePushCommand as `git <word>` and measured refused: 29 of 29 push=True
    # before this edit. That count is the wrong-refusal debt this block pays down.
    #
    # NOT MEASURED, AND SAID SO: the census command the brief named, `git --list-cmds=main`, was
    # REFUSED by this very guard -- it carries no positional token at all, so the round-11 rule at
    # the foot of Get-EvidenceCommandGitScan calls it a push. It was not respelled or routed around.
    # The doc/libexec listing is a lawful substitute and it is NARROWER, so words git ships but
    # neither documents nor hardlinks -- `submodule--helper`, `checkout--worker` and their kind --
    # are simply still refused. An omission costs one re-issued command; that is the cheap
    # direction, and it is the direction this list errs in on purpose.
    #
    # THIS LIST IS LITERAL AND MUST STAY LITERAL. Deriving it at runtime from git itself would let a
    # future git version silently widen what the publication gate admits, which is the fail-OPEN
    # direction. An edit here is reviewable; a derivation is not.
    #
    # MUST STAY ABSENT. Named here so a later tidier cannot re-add them by symmetry, because every
    # one of them moves work OUTWARD, and for some of them this list is the only local layer that
    # ever sees them:
    #   push, send-pack, receive-pack   -- the ref-push path itself, in all three spellings
    #   upload-pack, upload-archive, upload-archive--writer
    #                                   -- the serving half; a push is the peer's upload
    #   for-each-repo                   -- `--config=... push` publishes N repositories at once
    #   remote-ext, remote-fd           -- transport helpers that carry a push over an arbitrary
    #                                      external command
    #   subtree, lfs, svn               -- not builtins; `subtree push`, `lfs push` and
    #                                      `svn dcommit` all publish, and the last two do not take
    #                                      git's ref-push path at all, so no pre-push hook and no
    #                                      S-4 ref read ever sees them
    #   daemon, http-backend, shell     -- servers: each can accept an inbound publication
    #   http-push, imap-send, send-email, request-pull, p4
    #                                   -- outward by definition
    #
    # THE PER-VERB HARMLESSNESS BELOW IS A READING, NOT A MEASUREMENT (amendment 20 sentence
    # discipline): each was judged against what git documents it to do, and no end-to-end run was
    # attempted for any of them. What WAS measured is that every one is refused before this edit
    # and admitted after it.
    'backfill',                 # fetches missing objects into a partial clone -- inbound only
    'check-ref-format',         # validates a refname string; touches nothing
    'credential-cache',         # local credential helpers: they hold secrets, they publish nothing
    'credential-cache--daemon',
    'credential-store',
    'diff-pairs',               # compares provided blob pairs; read-only
    'fast-export',              # writes a stream to stdout -- a local export, not a remote write
    'fast-import',              # reads a stream, writes local objects
    'fetch-pack',               # the plumbing under `fetch`, which is already on this list: the
                                # peer sends and this side receives. It cannot write to the remote
    'fmt-merge-msg',            # composes a merge message from local refs
    'fsck-objects',             # the historical alias of `fsck`, already on this list
    'fsmonitor--daemon',        # a local filesystem-watching daemon
    'history',                  # EXPERIMENTAL; rewrites LOCAL history
    'init-db',                  # the historical alias of `init`, already on this list
    'last-modified',            # EXPERIMENTAL; read-only query
    'mailinfo','mailsplit',     # split and parse mailboxes on disk
    'merge-octopus',            # the merge STRATEGY helpers, invoked by `merge`; local index work
    'merge-one-file',
    'merge-resolve',
    'mktag','mktree',           # build a local tag or tree object
    'pack-redundant',           # reports redundant packs; read-only
    'quiltimport',              # applies a quilt patchset onto the current branch, locally
    'replay',                   # EXPERIMENTAL; replays commits onto a new local base
    'repo',                     # retrieves information about the repository; read-only
    'show-index',               # prints a pack index; read-only
    'survey',                   # EXPERIMENTAL; measures repository dimensions
    'unpack-file'               # THE REFUSED COMMAND ITSELF: writes a temp file holding a blob's contents
)

# =================================================================================================
# A HEREDOC BODY IS TEXT, NOT A COMMAND (the plumbing-refusal cure's third mechanism, found while building it).
# =================================================================================================
# THE DEFECT, driven before it was cured: `Get-EvidenceCommandGitScan` splits on a newline -- which
# is correct and was itself a cure (the three-line add/commit/push block) -- and a heredoc BODY line
# is a newline-separated line like any other. So the ordinary shape
#
#     git commit -F - <<'EOF'
#     the git push guard was fixed
#     EOF
#
# split the middle line into its own segment, found the tokens `git` and `push` in it, and refused
# the COMMIT as a publication. Measured at the base of this edit: push=True. It is the same class as
# the plumbing refusal -- a wrong refusal of something that publishes nothing -- and it is more common than the
# missing subcommand, because it fires on any commit message that mentions git.
#
# THE FENCE IS THE WHOLE SAFETY OF THIS, and it is stated first because this is the ONLY part of the
# over-refusal work that can create a false ALLOW. If no terminator line is found, the heredoc is
# UNTERMINATED and NOTHING is dropped -- current behaviour stands verbatim. Without that fence,
#
#     git commit -F - <<EOF
#     msg
#     git push origin main          (and no EOF anywhere)
#
# would be laundered into a body and ADMITTED: a real publication hidden behind a bogus opener. That
# shape is pinned as its own kill row in tests/lam/instrument-WP-1.ps1 H-5.
#
# TWO FURTHER NARROWINGS, both deliberately tighter than a real shell, because every line this
# function declines to drop is a line that still gets scanned -- the fail-CLOSED direction:
#
#   (a) THE OPENER MUST BE THE LAST THING ON ITS LINE. A shell accepts `cmd <<EOF > out.txt`; this
#       does not, and so it will not strip it. The reason is `echo '<<EOF'`, where the shell opens
#       no heredoc at all: if a later line happened to read EOF, a `git push` between them would be
#       swallowed. Requiring the opener to end the line means a trailing quote or redirection
#       disqualifies it, and the push stays visible.
#   (b) THE TERMINATOR IS MATCHED CASE-SENSITIVELY on the trimmed line. Trim() is MORE permissive
#       than a shell (which allows leading whitespace only for the `<<-` form, and only tabs), and
#       being more permissive here means finding the terminator EARLIER, which drops FEWER lines.
#       Every line not dropped is still scanned, so the permissiveness runs fail-closed too.
#
# The OPENER LINE ITSELF IS KEPT and scanned normally -- it is a real command, and `git push origin
# main <<EOF` must still be a push.
$script:EvidenceHeredocOpener = [regex]'(?:^|\s)<<-?\s*(["''`]?)([A-Za-z_][A-Za-z0-9_]*)\1\s*$'

function Remove-EvidenceHeredocBodies {
    param([AllowNull()][string]$Text)
    if (-not $Text) { return $Text }
    if ($Text -notmatch '<<') { return $Text }          # the ordinary case, untouched
    $lines = @($Text -split '\r?\n')
    $keep = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        [void]$keep.Add($line)
        $i++
        $m = $script:EvidenceHeredocOpener.Match($line)
        if (-not $m.Success) { continue }
        $delim = $m.Groups[2].Value
        $end = -1
        for ($j = $i; $j -lt $lines.Count; $j++) {
            if ($lines[$j].Trim() -ceq $delim) { $end = $j; break }
        }
        if ($end -lt 0) { continue }                    # THE FENCE: unterminated, drop nothing
        $i = $end + 1                                   # body AND terminator line are dropped
    }
    return ($keep -join ([string][char]10))
}

function Get-EvidenceCommandGitScan {
    param([AllowNull()][string]$Command)
    # `segments_before` exists because `-C` and `cd` are NOT the same kind of thing, and treating
    # them as one cost a fail-open: see the resolver.
    $result = @{ names_git = $false; push_segment = $null; segments_before = @() }
    if (-not $Command) { return $result }
    # A1'S SPLITTER DOES NOT SPLIT ON PARENTHESES, AND THE SCAN IT REPLACED DID (round 7, found by
    # driving the cure). `(git push origin main)` -- a shape an independent reader drove in ROUND 2,
    # and which this file's own doc comment lists as one of the four fail-open spellings it exists to
    # close -- went back to ALLOWED: the token is `(git`, and `(` is neither a start-anchor nor a
    # slash. Adopting a better splitter silently dropped a separator the worse one had.
    #
    # This is E70 exactly, in the batch that recorded E70: a cure that narrows what a rule RECOGNISES
    # widens what it ACCEPTS. Measured, not reasoned -- the control row was already written down.
    # =========================================================================================
    # ROUND-3 CURES (V-1 round 3, WP-4). THREE DEFECTS, and two of them pull in OPPOSITE
    # directions -- which is why this is one rewrite and not three patches.
    # =========================================================================================
    #
    # (1) THE SUBCOMMAND WAS STILL A LITERAL TOKEN. The previous round hardened the `git` half and
    #     left `push` matched as a bare word, so the shell could assemble it out of reach:
    #         git pu""sh          git pus''h        -- quotes were replaced by a SPACE, splitting
    #                                                  the token into `pu` + `sh`, matching neither
    #         git $(echo push)    git ${x}push      -- substitution: the word does not exist yet
    #     All four were ALLOWED with no gate and no recorded denial. Quotes are now DELETED rather
    #     than spaced, which rejoins `pu""sh` into `push`; both variants are tested, because
    #     deleting alone would let `git"push"` read as the word `gitpush`.
    #
    # (2) A SUBSTITUTION MEANS THE GUARD CANNOT READ THE COMMAND, so it must not pretend to. Any
    #     command naming a git executable AND carrying `$(`, `${` or a backtick is treated as a
    #     push. This is the metacharacter doctrine the rest of the guard already runs on: claim
    #     nothing, refuse. A false refusal costs one re-issued command; a false allow costs an
    #     unauthorised publication that cannot be taken back.
    #
    # (3) BUT A COMMIT IS NOT A PUSH, and the old fail-closed reading made that WORSE rather than
    #     safer. `git commit -m "document the push guard"` carried a bare `push` token, so it was
    #     classified as a push -- and on a repo with a live gate it would have been permitted AND
    #     CONSUMED THE OPERATOR'S GATE in PostToolUse, leaving a tombstone that says a push happened
    #     when none did. A gate spent by a commit is worse than a gate spelled around: it corrupts
    #     the record instead of merely failing to stop something.
    #     So the SUBCOMMAND is now identified positionally -- the first token after the executable
    #     that is not a flag, skipping `-C <path>` and its attached forms -- rather than by scanning
    #     for the word anywhere in the line. `git log --grep push` and `git commit -m "...push..."`
    #     are therefore NOT pushes, and that is a deliberate narrowing paid for by (2): the shapes
    #     that remain unreadable still refuse.
    # HEREDOC BODIES ARE REMOVED BEFORE THE VARIANT LOOP, not inside it: the quote-stripping
    # variants below would destroy the very quoting that identifies a `<<'EOF'` delimiter, so the
    # strip has to see the command as it was written. Unterminated heredocs are left whole by
    # Remove-EvidenceHeredocBodies, so this line can only ever REMOVE text a shell would have
    # treated as data. See the fence comment on that function -- it is the false-allow boundary.
    $scanText = Remove-EvidenceHeredocBodies -Text $Command
    foreach ($variant in @(($scanText -replace $script:EvidenceQuoteChars, ' '),
                           ($scanText -replace $script:EvidenceQuoteChars, ''))) {
        # A SINGLE `&` IS A SEPARATOR TOO (V-1 round 8, WP-4). A1 splits on `&&`, `||`, `;`, `|` and a
        # newline; the hand-rolled scan it replaced split on the class `[;&|()]`, which included the
        # SINGLE `&`. Round 7 restored the parentheses it had dropped and did not notice this one.
        # Driven: `git status & git push origin main` was ALLOWED and really published, while the
        # `;` spelling of the same act denied and was recorded.
        $segsAll = @()
        foreach ($outer in @(Split-CommandSegments -Command $variant)) {
            foreach ($mid in ($outer -split '&')) {
                foreach ($inner in ($mid -split '[()]+')) {
                    if ($inner.Trim()) { $segsAll += $inner }
                }
            }
        }
        for ($k = 0; $k -lt $segsAll.Count; $k++) {
            $seg = $segsAll[$k]
            # THE SEGMENT IS NOT SLASH-NORMALISED, only the token being MATCHED is. The whole variant
            # used to be rewritten \ -> / before scanning; that is harmless for recognising the
            # executable and wrong to hand onward, because the segment is now a RETURN VALUE that the
            # resolver reads paths out of.
            $tokens = @(($seg -split '\s+') | Where-Object { $_ })
            # EVERY git TOKEN IN THE SEGMENT, NOT THE FIRST (V-1 round 8, WP-4). The scan stopped at
            # the first git executable it found, so `git status & git push` broke on `status` and
            # never reached the push. Four spellings were ALLOWED and really published.
            #
            # MY OWN PROBE MISSED THIS AND THE REASON IS THE LESSON. I drove the separator change and
            # reported "nothing else was lost" using `foo & git push` -- where the FIRST git token IS
            # the pushing one. The shape I chose passed for a reason that does not generalise, and I
            # reported it as coverage. E69 inside the probe written to check E70.
            for ($gitAt = 0; $gitAt -lt $tokens.Count; $gitAt++) {
                if (-not (($tokens[$gitAt].Replace('\', '/')) -match '(^|/)git(\.exe)?$')) { continue }
                $result.names_git = $true
            $sawPositional = $false
            # NO-POSITIONAL ACCUMULATORS, read only by the no-positional branch at the foot of this loop.
            # $inertFlags counts tokens admitted by the closed literal allowlist; $inertBroken is
            # set by ANY flag off that list AND by any token the scan consumed as a SEPARATED
            # VALUE, which is the false-allow route `git --exec-path push origin main` takes.
            $inertFlags  = 0
            $inertBroken = $false
            for ($j = $gitAt + 1; $j -lt $tokens.Count; $j++) {
                $tok = $tokens[$j]
                if ($script:EvidenceGitValueOpts -contains $tok) {                   # option and its SEPARATED value
                    if ($j + 1 -lt $tokens.Count) { $inertBroken = $true }           # a token really was swallowed
                    elseif ($script:EvidenceGitInertBareOpts -contains $tok) { $inertFlags++ }  # bare, nothing to swallow
                    else { $inertBroken = $true }
                    $j++; continue
                }
                if ($tok.StartsWith('-')) {                                          # attached (--git-dir=...) and bare flags
                    if (($script:EvidenceGitInertBareOpts -contains $tok) -or
                        (@($script:EvidenceGitInertAttachedOpts | Where-Object { $tok.StartsWith($_) }).Count -gt 0)) {
                        $inertFlags++
                    }
                    else { $inertBroken = $true }
                    continue
                }
                $sawPositional = $true
                # THE SUBCOMMAND IS NOT A LITERAL. A shell removes backslash escapes and ANSI-C
                # quoting before git sees the word, so `git \push`, `git p\ush` and `git $'push'`
                # all reach git as `push` while a literal comparison sees three other words. All
                # three were ALLOWED and really published.
                $bare = ($tok -replace '\\', '') -replace '^\$', ''
                # ============================================================================
                # THE TEST IS INVERTED (V-1 round 10, WP-4), AND THE INVERSION IS THE POINT.
                # ============================================================================
                # Every previous cure here answered "does this look like a push?" and refused on a
                # BLACKLIST of shapes that had already embarrassed it -- quote variants, then
                # `$(`/`${`/backtick, then `$VAR` and `$'...'`. A blacklist over shell spellings
                # cannot close, and round 10 walked straight past the newest one with three more:
                #
                #   git {push,--quiet} origin main    brace expansion -- no `$` anywhere
                #   git pu\<newline>sh origin main    line continuation -- no `$`, and it INVERTS
                #                                    this scanner's own newline-splitting cure,
                #                                    because there a newline is NOT a separator
                #   git -c alias.zz=push zz origin    an ALIAS: `zz` is a perfectly ordinary word
                #   git config alias.zz push; git zz  the same, set up in an earlier call
                #
                # Each was ALLOWED and each really published a repository holding no gate at all.
                # The alias pair is the one that settles the design question: no amount of reading
                # the command TEXT can tell you that `zz` means `push`, because the answer lives in
                # the repository's config and not in the string.
                #
                # SO THE QUESTION IS TURNED AROUND. A segment naming a git executable is treated as
                # a PUSH unless its positional subcommand is BOTH a plain literal AND a word this
                # build recognises as something other than a push. That is closed by construction:
                # a spelling nobody has thought of is not a known non-push word, so it refuses.
                # `zz` refuses. `{push,--quiet}` refuses. `pu\` refuses.
                #
                # THE COST, STATED PLAINLY: a legitimate git subcommand missing from the list below
                # is REFUSED. That is a false refusal -- one re-issued command, and a loud one --
                # against a false allow, which is an unauthorised publication that cannot be taken
                # back. It is the same trade this function has documented since round 3, applied to
                # the whole space instead of to the shapes that had been caught so far. When a new
                # subcommand needs to be used, it goes in the list, and that edit is reviewable in a
                # way "we did not think of that expansion" never was.
                if ($bare -eq 'push') {
                    $result.push_segment = $seg
                    if ($k -gt 0) { $result.segments_before = @($segsAll[0..($k - 1)]) }
                    return $result
                }
                # A PLAIN LITERAL is a word the shell will hand to git unchanged: letters, digits and
                # hyphens, nothing else. `{push,--quiet}`, `pu\` and `$p` are not plain literals.
                $isPlainLiteral = ($tok -cmatch '^[A-Za-z][A-Za-z0-9-]*$')
                if ((-not $isPlainLiteral) -or (-not ($script:EvidenceNonPushSubcommands -contains $bare.ToLowerInvariant()))) {
                    $result.push_segment = $seg
                    if ($k -gt 0) { $result.segments_before = @($segsAll[0..($k - 1)]) }
                    return $result
                }
                break                                                                # a recognised non-push subcommand
            }
            # A SEGMENT THAT NAMES GIT AND CARRIES NO POSITIONAL TOKEN AT ALL FELL OPEN (V-1 round
            # 11, WP-4). The inner loop simply ended -- every remaining token was a flag, or there
            # were none -- and nothing assigned `push_segment`, so the inverted test never ran. The
            # inversion's whole point is that an unrecognised shape refuses; "no shape at all" is
            # the most unrecognised of them. `$sawPositional` records whether the loop ever reached
            # a decision, and the absence of one is now itself the decision.
            #
            # THE INERT-OPTION ALLOWLIST NARROWS THIS BY EXACTLY ONE CORNER AND ONLY THAT CORNER. The rule above kept
            # its word too well: `git --version`, `git --exec-path` and `git --list-cmds=main` --
            # git reporting on ITSELF -- were refused as publications, and the build's own census
            # command was one of them. A segment is admitted here only when EVERY token after the
            # git executable was on the closed literal allowlist beside
            # $script:EvidenceGitValueOpts (so at least one was, and none was off it), AND nothing
            # was consumed as a SEPARATED VALUE. That second half is not belt-and-braces: without
            # it `git --exec-path push origin main` arrives here with $sawPositional = $false,
            # because the scan swallowed `push` as --exec-path's value, and this branch would ADMIT
            # A REAL PUSH. Driven before and after this edit, it classes push at both ends.
            #
            # AN UNKNOWN BARE FLAG STILL REFUSES. `git --frobnicate` is not on the list, so
            # $inertBroken is set and the fail-closed rule stands -- the corner that is admitted is
            # enumerated, not inferred, for the same reason the list itself is literal.
            if (-not $sawPositional) {
                $inertOnly = (($inertFlags -gt 0) -and (-not $inertBroken))
                if (-not $inertOnly) {
                    $result.push_segment = $seg
                    if ($k -gt 0) { $result.segments_before = @($segsAll[0..($k - 1)]) }
                    return $result
                }
            }
            }
        }
    }
    return $result
}

# WHICH command in a sequence is the push. $null when none is.
# A DRY-RUN PREDICATE LIVED HERE FROM ROUND 8 TO ROUND 15, AND IT IS GONE ON PURPOSE.
#
# `Test-EvidencePushIsDryRun` (with its only helper, `Get-EvidencePushSegment`) answered "does this
# command's push segment carry --dry-run or -n". It was written correctly, warned in its own docblock
# that wrongly calling a REAL push a dry run "leaves the gate open for a second publication, which is
# the single-use property gone" -- and was then called from nowhere for eleven rounds. V-1 round 14
# wired it into PostToolUse; V-1 round 15 (WP-1 findings) drove exactly the failure its docblock named,
# because `push_segment` is a SCALAR and one segment was judging a whole multi-push tool call.
#
# IT IS DELETED RATHER THAN REPAIRED BECAUSE IT IS SUPERSEDED. Amendment 20 settles every witness
# against what the DECLARED ORIGIN actually holds, so a dry run -- which publishes nothing -- settles
# as "not published, not spent" with no classifier involved. Keeping a second, weaker answer to a
# question the origin already answers is how the two halves of this lifecycle drifted apart four
# times. See V-2 E99: dead code is wired or dropped, and this is the dropped branch.

function Get-EvidencePushTargetRoot {
    <#
      WHICH REPOSITORY IS BEING PUSHED? (V-1 round 3, WP-4.)

      `Get-EvidencePushGateVerdict` re-derived the tip from `CLAUDE_PROJECT_DIR` -- the session's
      project -- rather than from the repository the command actually names. So
      `git -C <other repo> push` was checked against, and AUTHORIZED BY, a gate bound to a
      DIFFERENT repository's sha.

      That is reachable in this build's own live topology rather than in theory: the smoke mission
      is a separate repository, `-MissionRoot` is arbitrary, and every worker runs in a worktree.
      A gate authorises one tip of one repository; answering for a different one is the same class
      of error as the stale-tip TOCTOU this function already closes.

      Returns the `-C` target when the command names one, else $null (caller keeps its own root).
    #>
    param([AllowNull()][string]$Command, [AllowNull()][string]$Cwd = $script:EvidenceCwd)
    if (-not $Command) { return $null }
    # FROM THE PUSH SEGMENT, NOT FROM THE WHOLE STRING (V-1 round 7, WP-4). Reading the entire
    # command let a -C in an EARLIER segment answer for a push in a LATER one: `git -C <other> log`
    # followed by `git push` would have resolved to <other> and checked ITS gate for a publication
    # of the session repository. The classifier and this function also normalised quotes
    # differently; both now read the single scan, so a spelling that reaches one reaches both.
    $scan = Get-EvidenceCommandGitScan -Command $Command
    $segment = $scan.push_segment
    # A command classified a push only because it is UNREADABLE has no segment. Falling back to
    # the whole string keeps the old behaviour there: the classification already refuses, and the
    # gate lookup refuses again on its own terms.
    if (-not $segment) { $segment = $Command }
    $tokens = @((($segment -replace $script:EvidenceQuoteChars, ' ') -split '\s+') | Where-Object { $_ })

    # A REPOSITORY CAN BE NAMED FIVE WAYS AND THIS ANSWERED FOR ONE (V-1 round 5, WP-4).
    #
    # Driven by an independent reader, not argued: with one operator push gate in the session
    # repository, `git --git-dir=<other>\.git --work-tree=<other> push origin main` was ALLOWED and
    # PUBLISHED that other repository -- one with no gate at all, at a commit no gate ever named --
    # while PostToolUse tombstoned the SESSION repository's gate for it. Single-use unmarked where
    # it mattered, false audit record where it did not. Controls bracketed it: no gate -> deny,
    # revoked -> deny, and the `-C` spelling of the identical act -> deny.
    #
    # THE LIST WAS ALREADY IN THIS FILE. `Test-EvidencePushCommand` three functions up was taught
    # git's whole closed family of value-taking main options in the PREVIOUS batch, for the
    # subcommand scan, while this resolver kept its `-C` special case -- so the same command was
    # correctly identified as a push and then checked against the wrong repository. I special-cased
    # one member of a family, in a file that records that exact lesson, one function away from the
    # enumeration that fixes it.
    #
    # ORDER MATTERS. `--work-tree` names the working tree, which IS the repository root a gate lives
    # under; `--git-dir` names the `.git` directory, so it resolves to its PARENT. Preferring the
    # work tree avoids looking for `.git/.mission/gates`.
    # ==============================================================================================
    # RESOLVED FROM WHAT A PUSH DOES, NOT FROM THE SPELLINGS THAT HAVE EMBARRASSED IT (round 6, WP-4)
    # ==============================================================================================
    # The previous form answered for every way a command NAMES a repository, and a process can also
    # simply be STANDING in one. Driven by an independent reader, with one operator gate in the
    # session project and a second repository holding NO gate: `git push`, `git -C <other>
    # --work-tree <session> push`, and `git --work-tree <session> push` from inside the other repo
    # were all ALLOWED and each really published the ungated repository -- after which PostToolUse
    # tombstoned the SESSION repository's gate for a publication it never had.
    #
    # TWO ERRORS, and the second is the instructive one.
    #
    # 1. The `cwd` that settles it was already in hand. It is plumbed into the path predicates in
    #    THIS SAME FILE, added in the same commit, with three paragraphs about the guard throwing
    #    that evidence away -- and it was never handed to this function. New evidence is not a patch
    #    to one call site; it is a question asked again of everything that had to guess before.
    #
    # 2. `--work-tree` was given PRIORITY, and that is wrong on the merits. A PUSH PUBLISHES THE
    #    REPOSITORY -- the object store, the git dir -- NOT the working tree. `--work-tree` selects
    #    which files are staged; it does not change where objects go. So `git -C <other>
    #    --work-tree <session> push` publishes OTHER, and the resolver answered SESSION. Built from
    #    a list of spellings, it was guaranteed to miss the next one; built from the semantics, the
    #    list stops mattering.
    #
    # PRECEDENCE, in the order git itself resolves the object store:
    #   1. an explicit --git-dir / GIT_DIR      -- names the store outright
    #   2. -C <path>                            -- moves the process, then discovery runs there
    #   3. cd <path> in the same command        -- same effect, one layer out
    #   4. the payload's cwd                    -- where the process actually stands
    # `--work-tree` and GIT_WORK_TREE deliberately do NOT participate.
    $gitDir = $null; $dashC = $null; $cdTarget = $null
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $t = $tokens[$i]
        $nxt = if ($i + 1 -lt $tokens.Count) { $tokens[$i + 1] } else { $null }
        # CASE-SENSITIVE, and that is not pedantry (V-1 round 8, WP-4). `-c` is git's CONFIG option
        # and `-C` its CHDIR option. `switch -regex` is case-INSENSITIVE in PowerShell, so
        # `git -c user.name=x push` resolved its repository root to `user.name=x`. Fail-closed --
        # the gate lookup finds no gates directory there and denies -- but it refuses legitimate
        # work and misreports the target in the record.
        # THE QUOTED FORM DETACHES THE VALUE, AND THE VALUE IS THE WHOLE ANSWER (V-1 round 9, WP-4).
        #
        # `Get-EvidenceCommandGitScan` returns on the FIRST of its two quote variants that finds a
        # push, and variant 1 replaces each quote character with a SPACE. So
        #     GIT_DIR="<other>/.git" git push origin main
        # reaches this loop as the two tokens `GIT_DIR=` and `<other>/.git`, and `^GIT_DIR=(.+)$`
        # -- which requires at least one character after the `=` -- matched neither. The resolver
        # fell through to the payload cwd and the SESSION repository's gate authorised publication
        # of an ungated one, with PostToolUse then tombstoning that gate. Driven to the real
        # publication for both the inline and the `export` spellings.
        #
        # The UNQUOTED spellings of the identical commands resolved correctly and denied, which is
        # what localises this to the quoting alone rather than to the option handling.
        #
        # THE SEPARATED FORM ALREADY HAD A PATTERN HERE -- `-C` and the bare `--git-dir` both read
        # their value from the NEXT token. A quote-split assignment is that same shape, so it is
        # handled the same way instead of being special-cased: the trailing-`=` token takes the
        # token after it as its value.
        switch -regex -casesensitive ($t) {
            '^-C$'                 { if ($nxt) { $dashC  = $nxt }; break }
            '^--git-dir$'          { if ($nxt) { $gitDir = $nxt }; break }
            '^--git-dir=(.+)$'     { $gitDir = $Matches[1]; break }
            '^--git-dir=$'         { if ($nxt) { $gitDir = $nxt }; break }
            '^GIT_DIR=(.+)$'       { $gitDir = $Matches[1]; break }
            '^GIT_DIR=$'           { if ($nxt) { $gitDir = $nxt }; break }
        }
    }
    # `cd` IS NOT A PER-INVOCATION OPTION, AND READING IT FROM THE PUSH SEGMENT LOSES IT (round 7).
    #
    # `--git-dir` and `-C` belong to the git invocation that carries them, so they must be read from
    # the push segment alone -- that is the fix in part 2, and it stands. `cd` is the opposite: it
    # moves the PROCESS, and every command after it inherits that. Narrowing the whole resolver to
    # one segment therefore dropped `cd <other>; git push` back to "wherever the payload says we
    # stand" -- the session repository -- so the session's gate would have authorised, and
    # PostToolUse tombstoned for, a publication of a DIFFERENT repository. That is round 6's defect
    # returning through round 7's cure.
    #
    # Only the segments BEFORE the push are read: a `cd` after it cannot have moved it. The LAST one
    # wins, as the shell would have it.
    #
    # WHEN THERE IS NO PUSH SEGMENT the command was classified unreadable, and `$segment` fell back
    # to the whole string above; the `cd` scan falls back with it, or this narrowing would lose for
    # the unreadable case the one thing the fallback exists to preserve.
    $cdSources = @()
    if ($scan.push_segment) { $cdSources = @($scan.segments_before) } else { $cdSources = @($Command) }
    if (-not $gitDir -and -not $dashC) {
        foreach ($before in $cdSources) {
            $bt = @((($before -replace $script:EvidenceQuoteChars, ' ') -split '\s+') | Where-Object { $_ })
            for ($i = 0; $i -lt $bt.Count; $i++) {
                # `export GIT_DIR=...` MOVES THE OBJECT STORE, which is what a push publishes -- for
                # exactly the reason this loop reads `cd` at all (V-1 round 8, WP-4). It was read
                # from the push segment and not from what precedes it, so
                # `export GIT_DIR=<other>/.git; git push` published <other> while the SESSION's gate
                # authorised it and PostToolUse stamped the SESSION's gate consumed. Both halves
                # agreed, on the wrong repository.
                #
                # It outranks a later `cd` for the same reason `--git-dir` outranks `-C`: it names
                # the store outright, where `cd` only moves discovery.
                if ($bt[$i] -cmatch '^GIT_DIR=(.+)$') { $gitDir = $Matches[1]; continue }
                # THE QUOTE-SPLIT FORM, in the preceding-segment scan as well as in the push segment
                # (V-1 round 9, WP-4). `export GIT_DIR="<other>/.git"; git push` arrives here as
                # `GIT_DIR=` followed by the path, for the same variant-1 reason recorded above. Curing
                # only the push-segment copy would have left this one live -- the two-sites-one-cured
                # shape this file has recorded repeatedly -- so both are done in one edit.
                if ($bt[$i] -ceq 'GIT_DIR=' -and ($i + 1) -lt $bt.Count) { $gitDir = $bt[$i + 1]; continue }
                # `pushd` MOVES THE PROCESS EXACTLY AS `cd` DOES (V-1 round 9, WP-4). The scan read the
                # literal token `cd` and nothing else, so `pushd <other> && git push` fell through to
                # the payload cwd -- the SESSION repository -- and the session's gate authorised
                # publication of a different, ungated repository, after which PostToolUse stamped the
                # session's gate consumed for a push it never had. Driven to the real publication.
                #
                # `pushd -n` IS NOT MODELLED, and the residual is recorded rather than papered over:
                # `-n` pushes onto the directory stack WITHOUT moving the process, so treating it as a
                # move resolves to the named directory and refuses a push that was legitimately the
                # session's. That is a false refusal, which is the direction this guard chooses
                # everywhere else, and the alternative -- modelling a directory stack from command
                # text -- is exactly the kind of guessing that produced the defects above it.
                # ONE SHELL OVER, AGAIN (V-1 round 10, WP-4). Round 9 added `pushd` beside `cd`, and
                # the registered PreToolUse matcher covers `PowerShell` as well as `Bash` -- so
                # `Set-Location`, its alias `sl`, and `Push-Location` are the SAME MOVE in the other
                # shell, and all three were ALLOWED while `cd` denied. Each really published a
                # different, ungated repository on the session's gate.
                #
                # The set is bounded and it is written out rather than pattern-matched, because a
                # pattern over verb names would catch words nobody meant. `chdir` is cmd's and
                # PowerShell's alias for the same act; `popd`/`Pop-Location` are deliberately ABSENT
                # -- they move somewhere this scan cannot know, so treating them as a move to their
                # next token would be inventing a target.
                if (($script:EvidenceChdirVerbs -contains $bt[$i].ToLowerInvariant()) -and ($i + 1) -lt $bt.Count) {
                    $cdArg = $bt[$i + 1]
                    if ($cdArg -eq '-n' -and ($i + 2) -lt $bt.Count) { $cdArg = $bt[$i + 2] }
                    $cdTarget = $cdArg
                }
            }
        }
    }
    # THE SEGMENT IS VERBATIM NOW, SO THE RETURN VALUE MUST BE NORMALISED HERE. The whole command
    # used to be rewritten `\` -> `/` before any of this ran, so every path this returned came back
    # slash-normalised; part 2 stopped doing that to keep the segment faithful, and
    # `GetDirectoryName` then handed back `C:\other` where callers had always seen `C:/other`.
    # Functionally equivalent to git, and NOT equivalent to any caller that compares the string --
    # so the form is restored rather than left to be discovered later.
    if ($gitDir) {
        # `<path>/.git` names the repository at `<path>`: the gate lives beside the working copy,
        # not inside the object store.
        $leaf = [System.IO.Path]::GetFileName($gitDir.TrimEnd('/', '\'))
        if ($leaf -eq '.git') {
            $parent = [System.IO.Path]::GetDirectoryName($gitDir.TrimEnd('/', '\'))
            if ($parent) { return ($parent.Replace('\', '/')) }
        }
        return ($gitDir.Replace('\', '/'))
    }
    if ($dashC)    { return ($dashC.Replace('\', '/')) }
    if ($cdTarget) { return ($cdTarget.Replace('\', '/')) }
    # WHERE THE PROCESS STANDS, which is the commonest spelling of all: a bare `git push`. Returned
    # only when nothing in the command names a repository, so this widens what the resolver answers
    # for without overriding an explicit target.
    if ($Cwd) { return $Cwd }
    return $null
}

# ONE DEFINITION OF "THIS FIELD CARRIES A REAL VALUE", because the sentinel `null` is itself \S and
# every hand-written form of these artifacts uses it. FOUR separate defects in this build were a call
# site restating this test and getting it slightly wrong, and a fifth was the same test written
# correctly TWICE.
#
# IT LIVES HERE RATHER THAN IN tools/lam/lam-gate-class.ps1 ON PURPOSE. This tree is installed on its
# own (LAM-INSTALL sec 2) into a repository that may not contain tools/lam at all, so a dependency
# there would make the guard fail to load in exactly the deployment the install document describes --
# and a guard that does not load denies nothing. Two copies across the tree boundary is a DISCLOSED
# duplication with a reason, which is not the same as an accident.
#
# `null\b` rather than `null$`: the reaching shape was a trailing YAML comment, so what follows the
# sentinel must not decide whether it is one.
# ROOTED MEANS ALREADY ABSOLUTE: drive-qualified or slash-leading, after canonicalisation has turned
# every backslash into a slash. Written out TWICE when the cwd cure landed -- eleven hundred lines
# apart, both correct -- in the batch whose own commit message names restated predicates as the root
# cause behind nine defects here. Neither copy was wrong; that is exactly the state the other nine
# were in before one of them drifted.
function Test-EvidenceRootedPath {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    return [bool]($Path -match '^([A-Za-z]:)?/')
}

function Test-EvidencePathIsFullyQualified {
    <#
      IS THIS PATH ANCHORED SOMEWHERE ABSOLUTE, OR ONLY SOMEWHERE RELATIVE TO SOMETHING?

      `[IO.Path]::IsPathRooted` IS NOT THIS TEST and using it as though it were is a live defect in
      this build (V-1 round 15, a WP-4 finding, driven against mission-gate.ps1's `-Binds`). It returns
      True for `C:e.txt` -- the current directory OF DRIVE C, which is per-process state -- and for
      `\dir\file.txt`, the current DRIVE's root. Both are relative to something the caller does not
      control, and both sailed through a check built on IsPathRooted.

      Fully qualified means: a drive letter followed by a separator, or a UNC root. .NET Framework
      4.x has no `IsPathFullyQualified` (it arrived in .NET Core 2.1), so it is spelled out.
    #>
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    return [bool]([regex]::IsMatch($Path, '^[A-Za-z]:[\\/]') -or [regex]::IsMatch($Path, '^[\\/][\\/]'))
}

function Test-EvidenceGateFieldSet {
    param([AllowNull()][string]$Text, [string]$Field)
    if (-not $Text) { return $false }
    return [bool]([regex]::IsMatch($Text, '(?m)^' + [regex]::Escape($Field) + ':[ \t]*(?!null\b)\S'))
}

# THE CONSUME BLOCK -- FIVE FIELDS, AND THIS TREE'S MIRROR OF tools/lam/lam-gate-class.ps1's LIST.
#
# WHAT WAS WRONG HERE (round 3, a review finding, driven). Complete-EvidencePushGate's write loop guarded
# itself with `Test-EvidenceGateFieldSet -Text $t -Field 'consumed_at'` -- ONE of the five fields a
# settle appends -- under a comment asserting that "refusing the gate whole makes it true by
# construction". It did not: a gate carrying the four appended fields while `consumed_at` still read
# the literal sentinel `null` answered that predicate FALSE, so this loop would have PROCEEDED and
# appended a second consume block. The console's settle carried the identical gap at the same moment,
# so the disclosure that named this the "OLD guard's" weakness was wrong about which guard.
#
# THE DUPLICATION IS DISCLOSED AND PRICED. This tree installs ALONE (LAM-INSTALL section 2) into a
# repository that need not contain tools/lam, so it may not load that library -- a guard that does
# not load denies nothing. E113 prices a disclosed duplication at a drift-detecting TEST; WP-4's T-35
# drives Get-LamGateConsumeBlock and Get-EvidenceGateConsumeBlock over the same texts and fails on
# any disagreement, exactly as T-14 does for the three state fields and H-21 for the kind.
$script:EvidenceConsumeBlockFields = @(
    'consumed_at',
    'consumed_origin_tip',
    'consumed_ref',
    'consumed_origin_before',
    'consumed_basis'
)

function Get-EvidenceGateConsumeBlock {
    # WHICH of the five consume-block fields are SET on this gate text. Returns an OBJECT, never a
    # bare array: a one-element array is unrolled by assignment and double-wrapped by `@(...)`, and a
    # guard's arity must not depend on how its caller spelled the call.
    param([AllowNull()][string]$Text)
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($f in $script:EvidenceConsumeBlockFields) {
        if (Test-EvidenceGateFieldSet -Text $Text -Field ([string]$f)) { [void]$found.Add([string]$f) }
    }
    $arr = $found.ToArray()
    return [pscustomobject]@{ any = ($found.Count -gt 0); count = $found.Count
                              fields = @($arr); joined = ($arr -join ', ') }
}

function Get-EvidenceGateScalarField {
    # ONE column-0 scalar field off a gate artifact, AND IT COUNTS THE KEYS BEFORE IT ANSWERS
    # (round 3, a review finding). The decider's `authorized_tip_sha` read was a first-match `-match` with
    # no count -- one of four copies of one regex literal -- so an artifact carrying TWO column-0
    # keys authorized on the first and the second was never seen. Fail-closed: two keys authorize
    # nothing, because an artifact that says which authorization it grants by KEY ORDER grants none.
    #
    # COLUMN 0 ONLY, AND THE PATTERN IS THE FOUR SITES' OWN CHARACTER FOR CHARACTER, so a single-key
    # artifact reads exactly as it read before. This is a MIRROR of tools/lam/lam-gate-class.ps1's
    # Get-LamGateScalarField, reason text included, for the reason stated above the field list.
    param([AllowNull()][string]$Text, [string]$Field)
    $none = [pscustomobject]@{ ok = $true; value = ''; count = 0; field = $Field; values = @(); reason = '' }
    if (-not $Text) { return $none }
    $ms = @([regex]::Matches($Text, '(?m)^' + [regex]::Escape($Field) + ':[ \t]*(\S+)'))
    if ($ms.Count -eq 0) { return $none }
    $vals = New-Object System.Collections.Generic.List[string]
    foreach ($m in $ms) { [void]$vals.Add([string]$m.Groups[1].Value) }
    $varr = $vals.ToArray()
    if ($ms.Count -eq 1) {
        return [pscustomobject]@{ ok = $true; value = ([string]$varr[0]); count = 1; field = $Field
                                  values = @($varr); reason = '' }
    }
    return [pscustomobject]@{ ok = $false; value = ''; count = $ms.Count; field = $Field; values = @($varr)
        reason = ("the artifact carries " + $ms.Count + " column-0 '" + $Field + "' keys (values: " +
                  ($varr -join ', ') + "), so which one it declares is AMBIGUOUS and this reader does not pick one") }
}

# A GATE LIVES AT THE REPOSITORY ROOT, AND A PATH IS USUALLY NOT ONE (round 6, WP-4).
#
# Once the resolver started answering "where the process stands", most answers became SUBDIRECTORIES:
# a bare `git push` from three levels down is the ordinary case. Handing that path to the gate lookup
# would find no `.mission/gates` there and DENY -- fail-closed, so not a hole, but it would refuse
# legitimate publication from anywhere but a repository root, which is a cure nobody would keep
# switched on.
#
# So the path is normalised to the repository top level the way git itself would. If that cannot be
# derived -- not a repository, git absent -- the path is returned unchanged and the gate lookup
# refuses on its own terms, which keeps the failure visible instead of silently widening.
function Get-EvidenceRepoTopLevel {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $Path }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Path rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -eq 0) {
            $top = ("$out").Trim()
            if ($top) { return $top }
        }
    } catch { } finally { $ErrorActionPreference = $prev }
    return $Path
}

# THE AUTHORIZATION RULE, WRITTEN ONCE AND ASKED TWO DIFFERENT QUESTIONS.
#
# The TRIPWIRE asks "is HEAD authorized?" before a command runs. The DECIDER (`pre-push`) asks "is
# THIS SHA, the one git is about to publish, authorized?" -- and those differ whenever a push names
# a ref that is not HEAD. Two questions, ONE rule: this function is the rule, and both callers pass
# their own sha in. Restating it per caller is the defect this file has recorded nine times.
function Get-EvidencePushGateForSha {
    param([string]$Root, [string]$Sha, [AllowNull()][string]$OriginUrl, [AllowNull()][string]$RemoteRef)
    $gatesDir = Get-EvidenceGatesDir -Root $Root
    if (-not (Test-Path -LiteralPath $gatesDir)) {
        return @{ ok = $false; reason = "no gate directory at $gatesDir -- push is authorized by an artifact a human creates, and none exists"; path = $null }
    }
    if (-not $Sha) {
        return @{ ok = $false; reason = "no sha was supplied to check against, so no authorization can be checked. Refusing rather than guessing"; path = $null }
    }
    $tip = $Sha
    $seen = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $gatesDir -File -Filter 'push-*.yaml' -ErrorAction SilentlyContinue)) {
        # THE CANDIDATE READ IS GUARDED, AND THE GUARD REFUSES BY NAME (V-3 round 3, a review finding,
        # driven through the real hook). This was a bare [System.IO.File]::ReadAllText under this
        # file's top-level $ErrorActionPreference = 'Stop'. It is the ADMISSION'S round-3 cure
        # (round-2 review finding, lam-verify-admission.ps1) left undone in the DECIDER -- the
        # component that actually gates a publication, and the one that round's residual list did
        # not mention. Driven: with one push-*.yaml held FileShare.None and a valid gate also
        # present, the installed pre-push hook died with an unhandled MethodInvocationException --
        #
        #     evidence-pre-push.ps1 : Exception calling "ReadAllText" with "1" argument(s): "The
        #     process cannot access the file '...\.mission\gates\push-aaa-locked.yaml' because it
        #     is being used by another process."
        #
        # -- EXIT 1, and no "PUSH REFUSED by the LAM pre-push decider" banner: a raw PowerShell
        # stack trace where a refusal belongs. The control with the handle released exited 0 and
        # wrote the in-flight witness, so the fixture was authorizing all along.
        #
        # THE WIDTH, AND NO WIDER. The direction is FAIL-CLOSED -- git aborts on the non-zero exit,
        # so nothing unsafe was ever admitted -- which makes this DIAGNOSABILITY and defence in
        # depth, NOT an authorization hole. What was lost is the sentence naming the file an
        # operator must release, and a decider that dies is not a decider that denied.
        #
        # ONE READ, NOT TWO. The admission reads each candidate twice -- its own ReadAllText and a
        # second one inside Get-LamGateClassForArtifact -- and had to guard both. This scan holds
        # the shared reader's regex inline (see the kind block below, and its reason), so the
        # candidate is read exactly once and this is the whole of the exposure.
        #
        # IT RETURNS; IT DOES NOT `continue` -- AND NOT FOR THE REASON THE ADMISSION'S TWIN USED TO
        # GIVE. That comment said an unreadable candidate "may be the revoked gate that would have
        # blocked a match further down this sorted scan". NO SUCH MECHANISM EXISTS, in either scan
        # (V-3 round 3, a review finding, measured): every in-loop refusal here and there is a
        # `continue`, and the only returns are the pre-scan guards, this one, the success and the
        # fall-through -- so no candidate of any content blocks a match further down. Driven at
        # this tip, in this function and in the admission: a gate carrying a revoked_at at
        # push-aaa.yaml does not stop a byte-identical unrevoked gate at push-zzz.yaml from
        # authorizing the same triple, with the revoked one recorded in `seen`. That behaviour is
        # left standing on purpose -- revocation withdraws ONE artifact, and whether it should bind
        # a TRIPLE is a ruling nobody has made -- and it is reported as a finding, not patched here.
        # THIS SCAN IS NOT SORTED EITHER: there is no Sort-Object above, so the order is whatever
        # Get-ChildItem hands back, which is one more reason no claim here may rest on position.
        #
        # THE TWO REASONS THAT ARE TRUE:
        #   (1) THIS SCAN'S VERDICT IS A NEGATIVE EXISTENCE CLAIM. Its fall-through says "no
        #       unconsumed push gate is bound to <tip>" and lists the candidates it examined -- a
        #       claim about EVERY artifact in this directory. A candidate nobody could read makes
        #       that claim unprovable, so continuing would have this function assert what it cannot
        #       establish, with the one file that made it unestablishable missing from the list.
        #   (2) CONTINUING WOULD MANUFACTURE A DECIDER-VERSUS-ADMISSION DIVERGENCE, IN THE
        #       PERMISSIVE DIRECTION. The admission RETURNS on this shape, so a decider that
        #       skipped an unreadable candidate and authorized on a later one would AUTHORIZE what
        #       the admission REFUSES over one directory -- verbatim the three review findings' and
        #       tip-comparison shape this pair of readers has now recorded four times.
        #
        # DIRECTION CHECK, and it is the cleanest one in this function: the guarded path previously
        # THREW, so this can only turn a crash into a refusal. No artifact that authorized before
        # answers differently, and none that was refused is now admitted. The refusal carries THIS
        # function's own {ok; reason; path} shape -- a refusal in a foreign shape is how a round-1
        # finding turned a refusal into a StrictMode throw at a caller -- and `path` stays $null
        # because in this function it means THE GATE THAT AUTHORIZED, and nothing authorized. The
        # file is NAMED so an operator can act on it instead of re-deriving which candidate was
        # unreadable. tests/lam/instrument-WP-1.ps1's H-23 drives it with the lock held and
        # released, and voids its own run if the lock is ever not a lock.
        $t = $null
        try { $t = [System.IO.File]::ReadAllText($f.FullName) }
        catch {
            return @{ ok = $false; reason = "candidate gate '$($f.Name)' could not be READ at $($f.FullName) -- $($_.Exception.Message). REFUSING rather than skipping it: this scan's verdict is a NEGATIVE EXISTENCE claim over every artifact in that directory -- 'no unconsumed push gate is bound to $tip' -- and a candidate nobody can read makes that claim unprovable. Release whatever holds that file, or move it out of the gates directory, and push again"
                      path = $null }
        }
        # THE KIND IS READ FROM THE ARTIFACT, NOT INFERRED FROM ITS FILENAME (round 5 self-audit).
        # The scan is `-Filter 'push-*.yaml'`, so a gate of ANY kind merely NAMED that way
        # authorised a publication -- a `kind: dispatch` artifact, whose entire purpose is
        # authorising a SPAWN, could authorise and be consumed by a push. Filenames are chosen by
        # whoever writes the file; the kind is what the classifier and the zero-paste attestation
        # both read.
        #
        # Same defect the runner's supersession lookup carried, fixed there one batch ago and left
        # in the other three sites -- the class was named and not enumerated, which is E56 exactly.
        # Checked against the live artifact before applying: lam-smoke's push gate declares
        # `kind: push` on its face, so no existing authorization is refused by this.
        #
        # AND "SOMEWHERE IN THE FILE" IS NOT "THIS ARTIFACT'S KIND" (V-2 round 2, a review finding, driven).
        # The round-5 cure recorded above read the kind as `-notmatch '(?m)^kind:[ \t]*push[ \t]*\r?$'`,
        # which asks whether such a line exists ANYWHERE in the file, and asks it CASE-INSENSITIVELY,
        # because `-match`/`-notmatch` fold case. The shared reader in tools/lam/lam-gate-class.ps1
        # takes the FIRST top-level kind and stops, and the admission compares that ordinally with
        # `-cne 'push'`. Three shapes therefore had the two readers disagreeing, and all three
        # disagreed in the PERMISSIVE direction: a two-kind artifact whose FIRST top-level kind is
        # `dispatch` and which carries a LATER `kind: push`; `kind: PUSH`; and `kind: Push`. Each one
        # authorised a publication HERE while every other consumer in this build read the same file
        # as something other than a push gate. That is the round-5 defect one layer in: the kind was
        # read from the artifact rather than from the filename, and then read by a rule of its own.
        #
        # THIS IS A DISCLOSED DUPLICATION OF tools/lam/lam-gate-class.ps1's READER, and it is
        # deliberate for the reason stated a hundred lines above this function: THIS TREE IS
        # INSTALLED ON ITS OWN (LAM-INSTALL sec 2) into a repository that may not contain tools/lam
        # at all, so a dependency there would make the guard fail to load in exactly the deployment
        # the install document describes -- and a guard that does not load denies nothing.
        # check-prepush-installed.ps1's .DESCRIPTION fixes the same dependency direction. E113
        # prices a disclosed duplication at a DRIFT-DETECTING TEST, and that test now exists and is
        # named: tests/lam/instrument-WP-1.ps1's H-21 drives BOTH readers over one corpus of real
        # gate files -- including the three shapes above -- and reds if they ever answer differently.
        # WP-4's T-14 pays the same price for the three state FIELDS; `kind` was not in its list.
        # So the regex below is the shared reader's own, character for character, and the
        # comparison is ORDINAL exactly as the admission's is.
        #
        # CAPTURE $Matches[1] IMMEDIATELY. $Matches is global and the next -match overwrites it;
        # reading it later is how this build lost a runner to an index-into-null.
        #
        # DIRECTION CHECK, because this NARROWS a guard rather than widening it: it can only stop
        # AUTHORIZING artifacts that were never `kind: push` on their face, and it can never begin
        # authorizing one that the old test refused. Driven against every gate on disk in the
        # repository of record before applying: all 81 artifacts carry exactly one top-level `kind:`
        # line at column 0, all 10 `push-*.yaml` files read `kind: push` exactly, and the old test
        # and this one agree on all 81. No existing authorization is refused by this.
        $gateKind = if ($t -match '(?m)^kind:[ \t]*(\S+)[ \t]*\r?$') { $Matches[1] } else { '' }
        if ($gateKind -cne 'push') {
            $seen += "$($f.BaseName): its FIRST top-level kind is '$gateKind', not push, as the shared class reader sees it -- a file NAMED for a kind is not a gate of that kind"
            continue
        }
        # ONE SCALAR READER, AND IT COUNTS (round 3, a review finding). This was a first-match `-match`
        # with no count, so a gate carrying TWO column-0 `authorized_tip_sha` keys authorized a
        # publication on the first and the second was never seen. Fail-closed here for the reason
        # every refusal in this scan is fail-closed: this function decides a real publication, and an
        # artifact that says which authorization it grants by KEY ORDER grants none.
        $authRead = Get-EvidenceGateScalarField -Text $t -Field 'authorized_tip_sha'
        if (-not $authRead.ok) { $seen += "$($f.BaseName): $($authRead.reason)"; continue }
        $auth = [string]$authRead.value
        if (Test-EvidenceGateFieldSet -Text $t -Field 'consumed_at') { $seen += "$($f.BaseName): already consumed"; continue }
        # `(?!null)` ON BOTH LINES, WHICH IS THE WHOLE OF THIS FIX. These two statements sat
        # adjacent, about two fields of one artifact, and only the first had it -- so a gate
        # carrying the literal `revoked_at: null` read as REVOKED and authorised nothing.
        #
        # Every hand-written gate carries that line: LAM-INSTALL's snippets do, the runner's own
        # supersession lookup treats it as the normal unrevoked state, and `Get-LamGateState` reads
        # it that way too. It went unnoticed because `mission-gate approve` writes no `revoked_at`
        # at all, so the ONE path anybody exercises never produces the shape.
        #
        # DIRECTION CHECK, because this WIDENS a guard: it can only stop refusing gates that were
        # never revoked. A gate with a real timestamp still matches `(?!null)\S` and is still
        # refused -- asserted as its own row in T-2e rather than reasoned about here.
        #
        # FOURTH INSTANCE of one defect. `consumed_at` had it in `gate_present`; `revoked_at` had
        # it in `mission-gate revoke`; and here. Each was found separately, and each time the fix
        # was to stop restating a predicate that already exists.
        if (Test-EvidenceGateFieldSet -Text $t -Field 'revoked_at') { $seen += "$($f.BaseName): revoked"; continue }
        # A GATE WHOSE WITNESS EXPIRED IS NOT USABLE AGAIN. It is not consumed -- nobody confirmed a
        # publication -- and it is not revoked, because no operator withdrew it. It is disqualified,
        # which is a third state and the only honest one for "a push was witnessed and its outcome
        # cannot be established".
        if (Test-EvidenceGateFieldSet -Text $t -Field 'witness_expired_at') { $seen += "$($f.BaseName): its witness expired before the declared origin could confirm the publication -- disqualified, re-mint to authorize again"; continue }
        if ($t -match '(?m)^expires_at:[ \t]*(\S+)') {
            # [ref] to an UNTYPED variable has no matching TryParse overload in PS 5.1 -- the
            # target must already be a [datetime]. Getting this wrong threw inside the guard,
            # which then failed CLOSED and denied an authorized push: the safe direction, but a
            # defect all the same, and one only driving the guard would have found.
            [datetime]$exp = [datetime]::MinValue
            if ([datetime]::TryParse($Matches[1], [ref]$exp)) {
                if ((Get-Date).ToUniversalTime() -gt $exp.ToUniversalTime()) {
                    # AND THIS BRANCH HIDES THE ANNOTATE REMEDY FROM EVERY GATE THAT NEEDS IT
                    # (V-1 round 17, a WP-4 finding, driven). The origin-declaration branch fifty
                    # lines below prints the annotation instruction; a gate that genuinely
                    # predates amendment 20 is by construction OLD, so it is refused HERE and never
                    # reaches it -- and annotation would not help if it did, because `expires_at` is
                    # immutable by ruling and the gate stays expired.
                    #
                    # THE REORDER IS NOT THE FIX. Showing ANNOTATE first to a gate that is expired
                    # points the operator at work that changes nothing, which is the round-14 defect
                    # this refusal family was rewritten to cure, inverted. So the message SAYS the
                    # two conditions together have no remedy inside the current rulings, and stops:
                    # whether a fresh authorization is the falsification the ruling forbids or a new
                    # act it never addressed is a READING of a ruling, and that is the operator's.
                    $preA20 = -not ([regex]::IsMatch($t, '(?m)^origin_url:[ \t]*\S') -and [regex]::IsMatch($t, '(?m)^remote_ref:[ \t]*\S'))
                    # PROPORTIONS (V-1 round 18, a WP-4 finding): the ORDINARY expired gate is the
                    # common case and was getting one word and no remedy, while the exotic pre-a20
                    # case got four sentences. An operator meeting the common case deserves to be
                    # told what to do about it.
                    #
                    # AND THE FREEZE IS A NORM, NOT A MECHANISM (a WP-4 finding, driven -- the field
                    # was moved ten years forward by hand and the decider authorized, untraced).
                    # Saying "cannot" would read as a technical impossibility. Naming it as a rule
                    # nothing enforces IS the compensating control: an operator who knows the
                    # machinery will not stop them is the only thing standing there.
                    $seen += "$($f.BaseName): expired at $($Matches[1]) -- an expired authorization does not authorize, and expires_at is frozen by ruling (a RULE, not a mechanism: nothing here detects an edit to it). The remedy for ordinary expiry is a NEW authorization for the work you are doing now, which is not the record-falsification the ruling forbids." + $(if ($preA20) { " AND this gate declares no origin_url/remote_ref, so it also predates amendment 20. What has no remedy is the ANNOTATION ROUTE for THIS artifact: an operator annotation adds the declaration and cannot move the expiry, so annotating it will not make it authorize. That is not the same as having no remedy, which is what this sentence used to say (V-1 round 19, a WP-4 finding, driven -- an expired pre-amendment-20 gate returns ok=False alone, and minting a fresh gate carrying origin_url and remote_ref for the same sha returns ok=True). The remedy is the one named above: a NEW authorization for the work you are doing now, which carries both a current expiry and the declaration. Take it to the operator only if a new authorization is not something you may ask for." } else { "" })
                    continue
                }
            }
        }
        # ONE CANONICAL FORM FOR A SHA, AND THE SAME ONE THE ADMISSION USES (round 3, the THIRD
        # decider-vs-admission divergence). This test was `-ne`, which FOLDS CASE, and the
        # admission's twin in lam-verify-admission.ps1 was `-cne`, which does not: an UPPERCASE
        # gate sha against a lowercase origin tip read False HERE -- the gate MATCHED and this
        # function AUTHORIZED THE PUSH -- and True there, so the admission refused the same
        # artifact. Permissive at the component that gates publication, which is verbatim the
        # shape of two review findings on a third predicate.
        #
        # THE DIRECTION IS NORMALISE, NOT REFUSE, and it is the opposite of a ruling's answer
        # for a gate KIND on purpose. A kind is drawn from a CLOSED VOCABULARY, where `PUSH` and
        # `push` are two tokens and the difference is an operator's next action; a sha is not --
        # git emits lowercase, hex case carries no meaning, and two spellings name ONE commit.
        # mission-gate.ps1's settle and record-origin-attestation.ps1 ALREADY compared tips
        # lower-cased, so leaving a raw ordinal test here would have made a two-way split a
        # three-way one. mission-gate.ps1 now lower-cases AT THE MINT, so the divergent shape is
        # unmintable and reachable only by hand-annotation.
        #
        # DIRECTION CHECK, because this WIDENS a guard: it can only begin authorizing a gate whose
        # sha names THE SAME COMMIT in another case, never one bound to a different commit.
        # Measured before applying: all 10 push-*.yaml at the repository of record carry lowercase
        # 40-hex, so no artifact on disk changes answer.
        #
        # THE DUPLICATE COMPARISON'S PRICE IS PAID BY A DRIFT-DETECTING TEST, as it is for the kind predicate. This
        # tree installs ALONE (LAM-INSTALL sec 2) into a repository that need not contain
        # tools/lam, so the comparison necessarily exists twice; tests/lam/instrument-WP-1.ps1's
        # H-22 drives BOTH readers AND the mint over one corpus of sha spellings and reds if they
        # ever answer differently. H-21 is its sibling for `kind`.
        if (($auth.ToLowerInvariant()) -cne ($tip.ToLowerInvariant())) { $seen += "$($f.BaseName): bound to $auth, sha under test is $tip"; continue }

        # AMENDMENT 20: A PUSH GATE AUTHORIZES ONE (origin url, ref, sha), NOT A SHA.
        # The declared values live on the artifact a human wrote. They are compared here and read
        # from nowhere else -- in particular never from `.git/config`, which is ruled unprotectable.
        $gateUrl = if ($t -match '(?m)^origin_url:[ \t]*(\S+)') { $Matches[1] } else { '' }
        # A RELATIVE DECLARATION IS MISSION-RELATIVE, AND IT IS RESOLVED HERE -- WHERE THE GATE
        # IS READ -- SO IT NAMES ONE REPOSITORY FROM EVERY ROOT (V-1 round 16, WP-1, HIGH,
        # driven both ways).
        #
        # The round-15 cure deliberately shares one gates directory between a main tree and its
        # linked worktrees, so one witness is reachable from SEVERAL roots -- and the settle
        # pass used to hand its own root to the origin read, which resolved `../o.git` against
        # it. Those roots disagree about what that names. Driven: settled at the worktree the
        # url could not be resolved and a REAL publication was stamped `witness_expired_at`
        # claiming the origin 'WAS ASKED and could not answer'; and with bare repos at both
        # `<root>/o.git` and `<root>/sub/o.git`, a push that published to the second was
        # tombstoned against the first. Not uniformly fail-closed.
        #
        # The gate lives at `<missionRoot>/.mission/gates/`, so its OWN location is the one
        # root that does not depend on who is settling. Resolving here means the decider's
        # witness, the settle pass and any later reader all receive an ABSOLUTE url and nobody
        # re-resolves it. Same rule round 15 gave `-Binds`: a relative path in a mission
        # artifact is mission-relative, and having ONE answer to 'relative to what' per
        # artifact class is the property that was missing.
        if ($gateUrl -and $gateUrl -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://' -and $gateUrl -notmatch '^[^/]+@' -and
            -not (Test-EvidencePathIsFullyQualified -Path $gateUrl)) {
            $missionRoot = Split-Path -Parent (Split-Path -Parent $gatesDir)
            if ($missionRoot) {
                try { $gateUrl = (([IO.Path]::GetFullPath((Join-Path $missionRoot $gateUrl))) -replace '\\', '/') } catch { }
            }
        }
        $gateRef = if ($t -match '(?m)^remote_ref:[ \t]*(\S+)') { $Matches[1] } else { '' }
        if (-not $gateUrl -or -not $gateRef) {
            # A GATE THAT PREDATES AMENDMENT 20 CANNOT SUPPORT ITS GUARANTEE, and saying so is the
            # honest outcome. Falling back to the current config would reintroduce exactly the
            # surface the amendment removed, on the artifacts least able to defend themselves.
            # ANNOTATE, DO NOT RE-MINT (V-1 round 14, WP-4). This used to say "Re-mint it" --
            # which is the act T-2 and the ruling call FALSIFICATION: re-minting stamps the
            # current date on an authorization a human gave earlier, on the one artifact class
            # whose purpose is recording when a human said yes. The sanctioned remedy is a dated
            # operator ANNOTATION that adds the missing declaration and alters nothing above it,
            # and it is already implemented downstream: instrument-WP-6 reads annotated_at /
            # annotated_by and discloses the pre-annotation gap on the member's face. The live
            # smoke gate carries one. The machinery was pointing the operator away from the
            # remedy the contract sanctions, toward the act it forbids -- and a refusal is the
            # only thing the operator sees, so a wrong sentence there is not cosmetic.
            $seen += "$($f.BaseName): declares no origin_url/remote_ref -- it predates amendment 20 and cannot bind a publication. ANNOTATE it (by ruling: a dated operator annotation naming the amendment, adding origin_url and remote_ref, altering no existing field). WRITE THE ADDED FIELDS AT COLUMN 0: every reader of them is anchored there, so an indented annotation is read as absent and changes nothing -- silently, since the gate then fails this same check again with the same message (V-1 round 17, a WP-4 finding). Do NOT re-mint: that stamps today's date on an authorization given earlier, which T-2 calls falsifying the record. Either act is an operator act -- T-3 denies agents write access to the gates directory."
            continue
        }
        # `-cne`, NOT `-ne`. PowerShell's `-ne` and `-eq` FOLD CASE for strings, so this comparison
        # treated https://example.com/o.git and https://example.com/O.git as one origin -- different
        # repositories on every case-sensitive host, which is every non-Windows git server. Since
        # `.git/config` is ruled unprotectable, setting `remote.origin.url` is precisely the move this
        # binding exists to defeat, so the compensating control was handing itself back.
        #
        # The canonicaliser has already folded everything that SHOULD fold: it lowercases
        # genuinely-local paths, because NTFS is case-insensitive and two spellings there are one
        # repository, and it leaves remote URLs alone because their path is case-significant. A
        # case-SENSITIVE comparison here is therefore correct for both kinds, not merely stricter.
        # BOTH SIDES ARE RESOLVED AGAINST AN EXPLICIT ROOT, AND THEY ARE DIFFERENT ROOTS ON PURPOSE
        # (V-1 round 16, WP-1). The gate's declaration is MISSION-relative and was resolved where the
        # gate was read, above. Git's url is REPOSITORY-relative -- it is whatever `remote.origin.url`
        # says in the repo being pushed -- so it is resolved against $Root here.
        #
        # These used to be compared as two unresolved strings, and the canonicaliser's full-path
        # resolution then anchored both against the PROCESS CWD. They matched because they were
        # resolved against the same accidental directory, not because they named the same repository.
        # That is WP-1's finding wearing a friendly face.
        #
        # When the two roots are the same directory this changes nothing. When they differ -- a linked
        # worktree, a separate mission repo -- the two now name DIFFERENT repositories and the push is
        # refused, which is correct: the publication is going somewhere the gate did not authorize.
        # WP-1 drove exactly that case into a false consumption tombstoned against the wrong repo.
        $originForCompare = $OriginUrl
        if ($originForCompare -and $originForCompare -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://' -and
            $originForCompare -notmatch '^[^/]+@' -and -not (Test-EvidencePathIsFullyQualified -Path $originForCompare)) {
            try { $originForCompare = (([IO.Path]::GetFullPath((Join-Path $Root $originForCompare))) -replace '\\', '/') } catch { }
        }
        if ($OriginUrl -and ((ConvertTo-EvidenceCanonicalRemoteUrl -Url $gateUrl) -cne (ConvertTo-EvidenceCanonicalRemoteUrl -Url $originForCompare))) {
            $seen += "$($f.BaseName): declares origin '$gateUrl' (resolved against the mission root), publication is to '$OriginUrl' (resolved against '$Root' as '$originForCompare')"; continue
        }
        # THE SECOND CALL SITE, AND MY OWN REVIEW MISSED IT. I found the origin comparison above and
        # stopped -- naming the instance and not the class, which is E56 committed inside a review
        # rather than inside a cure. An independent reader (V-1 round 13, WP-1) drove BOTH through the
        # real decider: a gate binding ssh://host/srv/a/b.git + refs/heads/main ALLOWED
        # ssh://host/srv/A/B.git, ssh://host/SRV/a/b.git, refs/heads/Main AND refs/heads/MAIN, with
        # correct controls denying. Git refs are case-sensitive; refs/heads/Main is a different ref.
        if ($RemoteRef -and ($gateRef -cne $RemoteRef)) {
            $seen += "$($f.BaseName): authorizes ref '$gateRef', publication is to '$RemoteRef'"; continue
        }
        return @{ ok = $true; reason = "gate $($f.BaseName) is unconsumed and binds ($gateUrl, $gateRef, $tip)"
                  path = $f.FullName; authorized_sha = $tip; origin_url = $gateUrl; remote_ref = $gateRef }
    }
    $detail = if ($seen.Count -gt 0) { " Gates examined -- $($seen -join ' ; ')." } else { " No push gate artifacts exist." }
    return @{ ok = $false; reason = "no unconsumed push gate is bound to $tip.$detail"; path = $null }
}

# THE TRIPWIRE'S QUESTION: is the repository's CURRENT HEAD authorized? Unchanged in behaviour --
# it re-derives the tip at call time (the D6/D7 TOCTOU rule) and hands it to the shared predicate.
function Get-EvidencePushGateVerdict {
    param([string]$Root)
    $tip = $null
    try {
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $s = & git -C $Root rev-parse HEAD 2>&1
            if ($LASTEXITCODE -eq 0) { $tip = ("$s").Trim() }
        } finally { $ErrorActionPreference = $prev }
    } catch { $tip = $null }
    if (-not $tip) {
        return @{ ok = $false; reason = "the local tip could not be re-derived, so no authorization can be checked against it. Refusing rather than guessing"; path = $null }
    }
    return (Get-EvidencePushGateForSha -Root $Root -Sha $tip)
}

# THE IN-FLIGHT RECORD: WHAT THE DECIDER SAW, WRITTEN WHERE AN AGENT CANNOT FORGE IT.
#
# `pre-push` runs inside git, after every expansion, and is handed the real remote, refspec and sha
# on its stdin. It writes this record ONLY after a gate has been found to bind that sha -- so the
# record cannot manufacture an authorization, it can only witness one. It lives under
# `.mission/gates/`, which T-3 hard-denies to every agent role by both routes (measured closed in
# V-1 round 11), and it is a dotfile rather than a `push-*.yaml` so no gate scan can mistake it for
# an authorization.
function Get-EvidenceGatesDir {
    <#
      WHERE DO THIS REPOSITORY'S GATES LIVE? ONE ANSWER, FOR EVERY CONSUMER.

      Two callers joined `.mission\gates` onto whatever root they were handed, and a LINKED WORKTREE
      does not carry that directory -- it lives in the main working tree. So a push from a worktree
      was refused for want of gates that were present all along, WHILE the sibling function that
      resolves the hooks path asked git precisely so that worktrees and core.hooksPath are accounted
      for. The runner CREATES worktrees, so this is the ordinary path, not a corner (V-1 round 14,
      a WP-4 finding).

      S7 -- A PATH RESOLVED AGAINST THE WRONG CONTEXT -- for the sixth and seventh time in this
      build. THE INSTANCE FIX IS DELIBERATELY NOT WHAT IS DONE HERE. Every previous S7 was cured
      correctly at its own call site and the shape came back, because a PowerShell path is a string
      and a string carries no record of what it is relative to. One resolver is the smallest thing
      that makes the next caller inherit the answer instead of re-deriving it wrongly.

      NOTE THE RECURSION HAZARD, WHICH IS S7 ITSELF: `--git-common-dir` may answer RELATIVELY, and
      resolving that answer against the wrong directory would be instance eight inside the cure for
      instances six and seven. It is resolved against $Root, which is the directory git was asked
      from, and that is why `-C $Root` and the Join-Path below name the same root.
    #>
    param([string]$Root)
    $direct = Join-Path $Root '.mission\gates'
    if (Test-Path -LiteralPath $direct) { return $direct }
    # ASK GIT WHICH WORKING TREE, DO NOT INFER IT FROM THE GIT DIRECTORY (V-1 round 15, a WP-1 finding --
    # HIGH, driven). This used to take the PARENT of `--git-common-dir` and call it the main working
    # tree. That is a guess, and `git init --separate-git-dir <gated-tree>/dir <rogue>` -- plain,
    # documented git -- is the layout where the guess is wrong: an unrelated repository's git
    # directory sits inside the gated tree, so its parent IS the gated tree, and this resolver handed
    # a rogue repo the gated repo's gates and its in-flight witness. WP-1 chained it: one PostToolUse
    # naming only the rogue destroyed the gated repo's witness for a real publication.
    #
    # `worktree list --porcelain` names the working trees of the repository $Root ACTUALLY BELONGS
    # TO, first entry being the main one. Driven both ways before this was written: for the rogue it
    # answers the rogue's own git directory, which holds no gates, so this falls through and refuses;
    # for a linked worktree it answers the main tree, which is the case this function exists to
    # serve. One question replaces one inference.
    try {
        $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $wt = & git -C $Root worktree list --porcelain 2>&1
        $ErrorActionPreference = $prevEap
        if ($LASTEXITCODE -eq 0) {
            $first = @(@($wt | ForEach-Object { "$_" }) | Where-Object { $_ -match '^worktree ' }) | Select-Object -First 1
            if ($first) {
                $main = ($first -replace '^worktree\s+', '').Trim()
                if ($main) {
                    $alt = Join-Path $main '.mission\gates'
                    if (Test-Path -LiteralPath $alt) { return $alt }
                }
            }
        }
    } catch { }
    # FALLING BACK TO THE DIRECT FORM KEEPS THE REFUSAL HONEST: a repository with genuinely no gates
    # must still be refused, and refused NAMING the path it looked in.
    return $direct
}

function Get-EvidencePushInFlightPath {
    param([string]$Root)
    return (Join-Path (Get-EvidenceGatesDir -Root $Root) '.push-inflight.json')
}

function Write-EvidencePushInFlight {
    # EVERY AUTHORIZED REF IS WITNESSED, NOT THE FIRST.
    #
    # The previous version wrote a record for `$authorized[0]` alone, directly beneath a comment
    # explaining that authorizing one ref and publishing the rest is a one-of-a-class defect. Round
    # 12 drove the consequence: `git push origin main b1` with two gates published BOTH, consumed
    # only the `main` gate, and left the `b1` gate open -- which then authorized a second real
    # publication. E56 in code written while quoting E56.
    #
    # AND EVERY PUSH IS WITNESSED, NOT THE LAST (V-1 round 14, a WP-1 finding). This function used to
    # WriteAllText a single record, so a second push in the same tool call erased the first witness
    # and its gate was never settled. The record is now APPENDED. The comment above describes the
    # ref-level version of this same defect, cured in round 12 -- and the push-level version
    # survived it, in the function whose own comment ends "E56 in code written while quoting E56".
    param([string]$Root, [string]$Remote, [AllowNull()][string]$RemoteUrl, [array]$Entries)
    $rec = [pscustomobject][ordered]@{
        remote      = $Remote
        remote_url  = $RemoteUrl
        entries     = @($Entries)
        written_at  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
        written_by  = 'pre-push (git decision point, after shell expansion)'
        note        = 'Amendment 20: one entry per ref git said it was publishing. remote_url is the DECLARED origin from the gate, not remote.origin.url.'
    }
    $existing = @(Get-EvidencePushInFlightRecords -Root $Root)
    return (Set-EvidencePushInFlightRecords -Root $Root -Records (@($existing) + @($rec)))
}

function Test-EvidencePushInFlightFresh {
    # AN IN-FLIGHT RECORD HAS A SHELF LIFE.
    #
    # `written_at` was recorded and never read, and on one documented path -- a remote that cannot be
    # asked what it holds -- the record is deliberately LEFT IN PLACE for the next attempt. With no
    # age bound, "left for the next attempt" and "left forever" are the same code: a record could
    # outlive the push it describes indefinitely and then consume a gate on the strength of a
    # publication somebody else made later.
    param($Flight, [int]$MaxAgeMinutes = 120)
    if (-not $Flight -or -not $Flight.written_at) { return $false }
    [datetime]$w = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$Flight.written_at, [ref]$w)) { return $false }
    return (((Get-Date).ToUniversalTime() - $w.ToUniversalTime()).TotalMinutes -le $MaxAgeMinutes)
}

function Read-EvidencePushInFlight {
    # KEPT FOR ITS ONE HONEST USE: "is there anything in flight at all?" Callers that need the
    # records themselves must use Get-EvidencePushInFlightRecords, because after the append cure there may be
    # MORE THAN ONE and a caller reading only the first would be the very defect being cured.
    param([string]$Root)
    $p = Get-EvidencePushInFlightPath -Root $Root
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try { return ([System.IO.File]::ReadAllText($p) | ConvertFrom-Json) } catch { return $null }
}

function Get-EvidencePushInFlightRecords {
    <#
      EVERY WITNESS, NOT THE LAST ONE (V-1 round 14, a WP-1 finding).

      Two pushes in one tool call both published; the second `WriteAllText` erased the first
      witness; the single PostToolUse that followed consumed only the second gate; the first stayed
      OPEN and later authorized a second real publication. Round 12 cured "several refs in ONE
      push" and this is "several PUSHES before one consumption pass" -- the same guarantee, the same
      function, the third time.

      THE LEGACY SHAPE IS STILL READ. A record written by the previous version sits at the top level
      rather than under `records`. Dropping it silently would spend nothing and consume nothing for
      a push already in flight across the upgrade -- so it is normalised, not ignored.
    #>
    param([string]$Root)
    $p = Get-EvidencePushInFlightPath -Root $Root
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    $doc = $null
    try { $doc = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json } catch { return @() }
    if (-not $doc) { return @() }
    if ($doc.PSObject.Properties.Name -contains 'records') { return @($doc.records | Where-Object { $_ }) }
    return @($doc)
}

function Set-EvidencePushInFlightRecords {
    # WRITING BACK IS HOW A RECORD LEAVES. There is no other exit: a witness that was not settled,
    # disqualified, or found to have published nothing is written back unchanged, so nothing can be
    # lost by omission -- which is precisely how the single-record write lost one.
    param([string]$Root, [array]$Records)
    $p = Get-EvidencePushInFlightPath -Root $Root
    $keep = @($Records | Where-Object { $_ })
    if ($keep.Count -eq 0) {
        # ONE DEFINITION OF "REMOVE THE WITNESS FILE". This branch was a verbatim copy of
        # `Clear-EvidencePushInFlight`'s body, and after the dry-run cure removed that function's only other caller
        # the copy would have been the sole survivor -- a second implementation quietly becoming the
        # only one. Calling it keeps the pair from drifting, which is the failure mode this file has
        # recorded for the gate-state predicate (four copies) and the origin read (two).
        [void](Clear-EvidencePushInFlight -Root $Root)
        return $null
    }
    $doc = [ordered]@{
        records = @($keep)
        note    = 'Amendment 20 + V-1 round 14 (a WP-1 finding): one record PER PUSH, accumulated. A later push must never erase an earlier witness; each is settled against the DECLARED origin on its own terms.'
    }
    [System.IO.File]::WriteAllText($p, ($doc | ConvertTo-Json -Depth 8),
                                   (New-Object System.Text.UTF8Encoding($false)))
    return $p
}

function Clear-EvidencePushInFlight {
    param([string]$Root)
    $p = Get-EvidencePushInFlightPath -Root $Root
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
}

# WHAT DOES ORIGIN ACTUALLY HOLD? The detector's question, asked of the remote rather than of this
# session. Returns $null when it cannot be answered, and $null must never be read as "it advanced".
function ConvertTo-EvidenceCanonicalRemoteUrl {
    # TWO SPELLINGS OF ONE ORIGIN MUST COMPARE EQUAL, or the binding refuses the thing it authorized.
    #
    # Amendment 20 compares the origin a gate DECLARES against the origin git says it is publishing
    # to. Those two strings reach the comparison by different routes: the operator (or a fixture)
    # writes one into the artifact, and git hands the other to the pre-push hook as argv[1]. On
    # Windows they routinely differ by separator alone -- `C:\x\o.git` versus `C:/x/o.git` -- and a
    # naive `-ne` then denies a correctly authorized push. Measured while building this: every
    # consumption member went red with `usable=True stamped=False`, because the decider refused, no
    # in-flight record was written, and nothing could be consumed.
    #
    # WHAT IS NORMALISED, and nothing beyond it: separators, a trailing slash, and -- for paths that
    # are genuinely local -- full-path resolution and case, because NTFS is case-insensitive and
    # `..` segments are common in these fixtures. A REMOTE url (ssh/https) is left alone apart from
    # separators and the trailing slash: host and path case can be significant there, and quietly
    # folding it would make two different remotes compare equal, which is the failure that matters.
    # `.git` is NEVER stripped: `o` and `o.git` are different repositories.
    param([AllowNull()][string]$Url)
    if (-not $Url) { return '' }
    $u = ("$Url").Trim() -replace '\\', '/'
    $u = $u -replace '/+$', ''
    if ($u -match '^[A-Za-z]:/' -or $u -match '^//' -or $u -match '^file:///') {
        $p = $u -replace '^file:///', ''
        try { $p = [System.IO.Path]::GetFullPath(($p -replace '/', '\')) -replace '\\', '/' } catch { }
        return $p.ToLowerInvariant() -replace '/+$', ''
    }
    return $u
}

function Get-EvidenceRemoteRefs {
    # EVERY REF THE DECLARED ORIGIN HOLDS, PARSED CANONICALLY.
    #
    # TWO defects are cured here and they are independent:
    #
    #  1. IT TOOK A REMOTE *NAME*. `git ls-remote origin` resolves `origin` through `.git/config`,
    #     which amendment 20 rules an unprotectable control surface. Round 12 drove it: repointing
    #     `remote.origin.url` at a decoy bare repo made the detector report PASS while the real
    #     origin held an unauthorized commit. A detector that reads the attacker's configuration is
    #     not a detector. It now takes a URL, and callers get that URL from the GATE ARTIFACT.
    #
    #  2. IT TOOK THE FIRST 40-HEX IT SAW. `ls-remote` matches its pattern at slash boundaries and
    #     sorts by refname, so `refs/heads/aaa/main` is returned BEFORE `refs/heads/main`. Round 12
    #     drove that too: the authorized sha parked on a decoy ref, an unauthorized commit on the
    #     real one, and S-4 reported PASS. Parsing is now exact -- refname compared whole, never a
    #     prefix and never a first-match.
    #
    # Returns a hashtable of refname -> sha for the WHOLE remote, or $null when the remote could not
    # be asked. `$null` and "no refs" are different answers and callers must not conflate them: one
    # is ignorance, the other is knowledge.
    # `-Root` IS BACK, AND ITS ABSENCE WAS A REAL PUBLICATION THAT SPENT NOTHING (V-1 round 13,
    # WP-4). `mission-gate approve` copies `git remote get-url origin` verbatim onto the artifact, so
    # a repository whose remote was added relatively -- `git remote add origin ../o.git`, which is
    # ordinary -- declares `origin_url: ../o.git`. Running `git ls-remote ../o.git` with NO `-C`
    # resolves that against the HOOK PROCESS's working directory, which is not the repository: exit
    # 128, `$null` returned, and consumption takes the "unconfirmed, spend nothing" branch. Driven:
    # origin went from absent to a real sha, the gate stayed OPEN, and the same gate then authorized
    # a SECOND real publication -- falsifying "spent exactly once, iff the publication happened".
    #
    # I INTRODUCED THIS WHILE FIXING SOMETHING ELSE. The rewrite that moved this function from a
    # remote NAME to a gate-declared URL -- the amendment-20 cure for `.git/config` being
    # untrustworthy -- dropped `-Root` in the same edit. A relative declaration is not a lesser
    # declaration; it is one that has to be resolved somewhere, and the repository is that somewhere.
    param([string]$Root, [string]$Url)
    if (-not $Url) { return $null }
    # THE DECLARED ORIGIN, NOT WHATEVER CONFIG REWRITES IT TO (V-1 round 14, WP-6).
    #
    # `git config url.<decoy>.insteadOf <declared>` -- one line, repo-local OR global -- redirects
    # this read to a decoy while the member prints "DECLARED origin (from the gate, never
    # .git/config)". The URL came from the gate; the ANSWER came from config. That is verbatim the
    # defect amendment 20 lists as cured, narrowed to one key rather than closed, and it matters
    # because the detector is the top layer while D4 is unbuilt.
    #
    # ISOLATION WAS DRIVEN BEFORE BEING WRITTEN, since whether it is possible decides between a
    # repair and a contract question. `-c url.<x>.insteadOf=` does NOT neutralise it. What does:
    # resolve the url to ABSOLUTE (using $Root, which is why $Root exists at all -- a relative
    # declaration must still be resolvable), then read from OUTSIDE the repository with global and
    # system config suppressed. Both routes close.
    #
    # THE TENSION THIS RESOLVES: `-Root` was added so a relative declared url could resolve; being
    # inside the repo is also what exposes repo-local config. Resolving with the root and READING
    # outside it satisfies both.
    $askUrl = $Url
    if ($Root -and $Url -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://' -and $Url -notmatch '^[^/]+@') {
        try { $askUrl = [IO.Path]::GetFullPath((Join-Path $Root $Url)) } catch { $askUrl = $Url }
    }
    # NAME THE CONFIG FILES; DO NOT GUESS WHERE GIT LOOKS FOR THEM (V-1 round 16, a WP-6 finding --
    # CRITICAL, driven). This used to point HOME / USERPROFILE / XDG_CONFIG_HOME at the TEMP ROOT and
    # call that neutral. Those variables ARE git's global-config search paths, so `%TEMP%\.gitconfig`
    # became live global config IN A WORLD-WRITABLE DIRECTORY: the isolation relocated the surface
    # instead of removing it, and the relocated one is easier to reach than the original -- a temp
    # file, with no repository, no mission and no guard involved.
    #
    # GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM (git 2.32+) point those two layers at explicit files.
    # Aimed at paths that cannot exist, both layers are absent -- an instruction git obeys rather than
    # a guess about where it looks. GIT_CONFIG_NOSYSTEM stays for older git.
    #
    # The THIRD layer is repo-local, and it is closed by WHERE this runs: a private directory is
    # created for the read, outside any repository.
    # AND THAT CURE WAS ONE-THIRD INERT (V-1 round 17, WP-1 and WP-6 findings -- CRITICAL,
    # driven INDEPENDENTLY by two validators, each with the same strict-ancestor control, which is
    # what makes it a measurement rather than a reading of the manual).
    #
    #   * GIT_CEILING_DIRECTORIES was set to the directory being read FROM. A ceiling names
    #     directories git will not chdir UP INTO, and the starting directory never is one -- so it
    #     was no ceiling at all. Discovery climbed straight out into the temp root, and a bare
    #     `%TEMP%\.git\config` -- no repository, no mission, no guarded path, creatable by an
    #     ordinary tool call -- redirected this read to a decoy. Driven end to end: a real
    #     publication landed, the settle pass asked the DECOY, the gate stayed OPEN, and that SAME
    #     gate then authorized a SECOND real publication. Control: gate consumed, second push
    #     refused, origin left empty.
    #   * Round 15 closed `.git/config`. Round 16 closed `%TEMP%\.gitconfig`. Round 17 found
    #     `%TEMP%\.git\config`. Three cures, three named routes, each a ONE-DIRECTORY MOVE.
    #
    # SO THE LIST IS ABANDONED FOR A DEFAULT-DENY. Every `GIT_*` variable is removed for the duration
    # of the read and only the four this function actually needs are set back. That closes
    # GIT_CONFIG_COUNT/GIT_CONFIG_KEY_n/GIT_CONFIG_VALUE_n, GIT_CONFIG_PARAMETERS, GIT_DIR,
    # GIT_WORK_TREE and every route git adds in future BY CONSTRUCTION rather than by enumeration.
    # WP-1 and WP-6 findings each named four more live routes; the point of this shape is that
    # naming them was never going to terminate.
    #
    # AND THE CEILING IS NOW A STRICT ANCESTOR. Both directories are created here, microseconds
    # before use, so neither can be pre-planted: discovery starts in `<neutral>\read` and is
    # forbidden to climb into `<neutral>`.
    #
    # WHAT IS NOT DEFENDED, SAID PLAINLY RATHER THAN IMPLIED: `PATH`, and `TMP`/`TEMP`, and
    # anything else that requires control of this process's environment. Whoever can set those can
    # replace `git` itself, and no GIT_* hygiene survives that. The boundary drawn here is CONFIG
    # INJECTION AND REPOSITORY DISCOVERY -- which is what the file-plant route actually needed, and
    # it is the route both validators drove.
    #
    # `TMP`/`TEMP` ARE NAMED BECAUSE THEY WERE NOT (V-1 round 18, a WP-1 finding, driven). They sit
    # outside the cleared namespace and SITE the private read directory below: sane -> refs,
    # hijacked -> NULL, restored -> refs. Listing `PATH` alone read as an exhaustive account of what
    # is conceded, and a disclosure that names one member of a class implies the others are covered.
    # After the transport finding, NULL is the PERMISSIVE answer, so this is the direction that matters.
    #
    # TRANSPORT VARIABLES ARE KEPT, AND THE ROUND-17 COMMIT ARGUED THE OPPOSITE (V-1 round 18,
    # a WP-1 finding, HIGH, driven). That commit said an origin reachable only through ambient
    # `GIT_SSH_COMMAND` / `GIT_PROXY_COMMAND` "is reported UNCONFIRMABLE instead of being confirmed
    # through a channel somebody else configured. For a detector that is the correct direction."
    #
    # UNCONFIRMABLE IS THE PERMISSIVE DIRECTION. Driven: the same gate, the same REAL publication,
    # settled twice through `Complete-EvidencePushGate` with only reachability differing --
    #   reachable      -> consumed, no longer authorizes;
    #   unconfirmable  -> NOT consumed, witness kept, STILL AUTHORIZES.
    # That is round 17's own CRITICAL end-state, reached by denial rather than by an attacker.
    #
    # THE REASONING FAILED BY ANSWERING THE WRONG QUESTION. "Better to say I could not confirm than
    # to confirm through somebody else's channel" is right for a READER and wrong for a CONSUMER
    # THAT SPENDS A GATE ON THE ANSWER. One function serves both, and only one was considered.
    #
    # AND THE DEFENCE WAS ALREADY CONCEDED TWO PARAGRAPHS UP. These variables can be abused only by
    # someone who can set this process's environment -- who can equally set `PATH` and replace `git`.
    # Clearing them protects against nobody while making a whole class of origin permanently
    # unconfirmable. The sweep never covered transport in any case: it matches on the `GIT_` name
    # prefix, and `http_proxy` / `ALL_PROXY` do not carry one (V-1 round 18, a WP-6 finding, driven with
    # two controls -- git routed through the host they named).
    #
    # WHAT THIS ISOLATION DEFENDS AGAINST IS CONFIGURATION ON DISK, NOT THE PROCESS ENVIRONMENT.
    # An earlier wording here claimed the default-deny was "scoped to the variables that decide WHICH
    # REPOSITORY IS READ AND WHOSE CONFIG IS CONSULTED" -- with `GIT_SSH_COMMAND` four lines below it
    # on the allow-list, deciding exactly that (V-1 round 19, a WP-1 finding). The sentence described
    # a narrower list than the one it introduced, and a reader checking the scope by reading would
    # have been told the opposite of what the code does.
    #
    # Stated correctly: global and system config, `insteadOf`, conditional includes and `hooksPath`
    # are suppressed and stay suppressed. Everything `GIT_*` is still cleared by default, so a
    # variable git adds next year is closed by construction (E116), and twelve transport names are
    # then restored BY NAME. Two of them -- `GIT_SSH_COMMAND` and `GIT_PROXY_COMMAND` -- can point a
    # read at another repository entirely. That is a real hole and it is deliberate.
    #
    # BOTH HALVES OF THE TRADE, DRIVEN, because round 18 recorded only the permissive one. Two cells,
    # identical but for the allow-list, attacker setting GIT_SSH_COMMAND in both, declared origin
    # holding ONLY the earlier commit:
    #
    #   shipped (transport restored) : read STEERED to the attacker's repository -> the gate is
    #       CONSUMED, and the artifact asserts `consumed_basis: ... the DECLARED origin observed
    #       holding the authorized sha, having ADVANCED from '<sha>...'` -- about an origin that
    #       received nothing and still holds that sha.
    #   round 17 (transport cleared) : read NULL -> nothing consumed -> "REMAINS OPEN AND STILL
    #       AUTHORIZES", reachable with no attacker at all by making the origin unreachable.
    #
    # THE TWO FAILURES ARE NOT THE SAME KIND. Clearing transport leaves an authorization alive past
    # its use and writes a TRUE record saying the origin could not be asked. Restoring it lets a
    # steered read spend the gate and write a FALSE one -- a positive claim, in an audit artifact,
    # about a publication that did not occur. The decision stands, and it is not costless; anyone
    # revisiting it is choosing which of those two they prefer, not whether to have a defect.
    #
    # AND THE HONEST BOUND: against an adversary who can set this process's environment, this
    # function is not a defence and never was -- the same adversary sets `PATH` and replaces `git`,
    # which the concession two paragraphs up already grants. Clearing `GIT_*` did not close that;
    # it only made the failure quieter. What survives such an adversary is not this read but the
    # gate's own single-use binding to (origin url, ref, sha), and the fact that a consumed gate is
    # a durable artifact somebody can later compare against the origin.
    #
    # A default-deny with a short, justified allow-list is still a default-deny; a blacklist is not.
    $keepTransport = @(
        'GIT_SSH', 'GIT_SSH_COMMAND', 'GIT_SSH_VARIANT', 'GIT_PROXY_COMMAND',
        'GIT_SSL_CAINFO', 'GIT_SSL_CAPATH', 'GIT_SSL_CERT', 'GIT_SSL_KEY',
        'GIT_ASKPASS', 'GIT_TERMINAL_PROMPT', 'GIT_CURL_VERBOSE', 'GIT_TRACE'
    )
    # THE CREDENTIAL HELPER IS READ NOW, WHILE THE OPERATOR'S CONFIG IS STILL VISIBLE, and carried
    # into the isolated read by name (V-1 round 19, a WP-1 finding, driven). Suppressing global and
    # system config removes `credential.helper`, and a credential-gated origin then returns NULL with
    # the isolation flag EMPTY -- the read ran and authentication failed. Measured: this repository's
    # https origin answers a bare `ls-remote` with 5 refs and returns NULL here; the SAME isolation
    # reads a public repository at 5,310 refs, so https, TLS and the network all survive it.
    #
    # Every settle for such an origin then lands on "REMAINS OPEN AND STILL AUTHORIZES". Amendment 20
    # says detection asks the declared origin what it holds; an origin that cannot be asked makes that
    # property UNATTAINABLE rather than merely undefended.
    #
    # THIS IS NOT A WIDENING. The isolation exists to stop configuration deciding WHICH REPOSITORY IS
    # READ -- `insteadOf` and the rest, all still suppressed. A credential helper cannot redirect a
    # read. And planting a hostile one needs write access to global config, which is the same access
    # that sets `core.hooksPath` and which this function's own disclosure already concedes.
    #
    # THE WHOLE `credential.*` FAMILY, NOT JUST THE PLAIN KEY. The first version of this carried
    # `credential.helper` and was INERT, because that key does not exist on the host it was written
    # for: system, global and local all answer exit 1. What exists is
    # `credential.https://github.com.helper` -- URL-SCOPED -- which the first version's own comment
    # named as the limitation and then did not act on.
    #
    # Isolated by measurement rather than by reasoning, one ingredient at a time against the real
    # origin: GIT_CONFIG_SYSTEM harmless, GIT_CONFIG_NOSYSTEM harmless, GIT_CONFIG_GLOBAL=nowhere
    # ALONE breaking the read. Two earlier guesses -- the plain key, then the HOME redirect -- each
    # looked sufficient and each changed nothing.
    #
    # VALUES ARE NEVER LOGGED. A helper value is a command line belonging to the operator; it is
    # passed to git and nowhere else. This build's standing rule for secret-adjacent bytes is
    # hash-or-shape, never content.
    $credHelpers = @()
    $prevCred = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        # NUL-SEPARATED, AND EVERY KEY RE-CHECKED (V-1 round 20, a WP-1 finding, CRITICAL, driven).
        #
        # This parsed `--get-regexp` output LINE BY LINE and split at the first space. A
        # `credential.*` VALUE containing a NEWLINE therefore became two records, and the second was
        # appended as its own `-c` and never re-checked -- so one ordinary `git config --local --add`
        # (exit 0; git writes the escape itself) injected `-c url.<decoy>.insteadOf=<origin>` into
        # the isolated read. Driven to a CONSUMED gate whose `consumed_basis` asserts the declared
        # origin ADVANCED to a sha it never held. That is STRICTLY LESS ACCESS than the transport
        # route this file already discusses, and unlike that one it is live for the smoke topology.
        #
        # It falsified four sentences I had written, including "A credential helper cannot redirect
        # a read." It can, if the reader lets it smuggle a non-credential option alongside itself.
        #
        # `-z` makes each record `key<LF>value<NUL>`, so a newline in a value is DATA and the only
        # structural separator is the NUL. PowerShell splits native output on newlines, so the lines
        # are rejoined before splitting on NUL -- measured on this host rather than assumed: 5
        # records, every key `credential.*`, the planted value carrying its newline internally.
        $ch = & git -C $Root config --get-regexp -z '^credential\.' 2>&1
        if ($LASTEXITCODE -eq 0) {
            foreach ($rec in @((@($ch) -join "`n") -split "`0")) {
                if (-not $rec) { continue }
                $nl = $rec.IndexOf("`n")
                if ($nl -lt 1) { continue }
                $k = $rec.Substring(0, $nl)
                $v = $rec.Substring($nl + 1)
                # ASKING IS NOT VERIFYING. The old code checked the pattern it handed git and then
                # trusted the shape of what came back. The key is re-checked here against the same
                # pattern, on the parsed record.
                if ($k -notmatch '^credential\.') { continue }
                # AND A VALUE THAT STILL CARRIES A NEWLINE IS DROPPED. There is no legitimate use for
                # one here, it is the injection vector itself, and dropping it does not depend on my
                # being right about how git re-parses `-c`. Belt and braces, in the safe direction.
                if ($v -match "[`r`n]") { continue }
                $credHelpers += ($k + '=' + $v)
            }
        }
    } catch { } finally { $ErrorActionPreference = $prevCred }

    $neutral = Join-Path ([IO.Path]::GetTempPath()) ('lam-neutral-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    $readDir = Join-Path $neutral 'read'
    $nowhere = Join-Path $neutral 'no-such-config'
    $out = $null
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $svHome = $env:HOME; $svUp = $env:USERPROFILE; $svXdg = $env:XDG_CONFIG_HOME
    # Snapshot BEFORE removing, and restore from the snapshot -- not from four named saves, which is
    # the shape that let a fifth variable through.
    $svGit = @{}
    foreach ($e in (Get-ChildItem Env: -ErrorAction SilentlyContinue)) {
        if ($e.Name -like 'GIT_*') { $svGit[$e.Name] = $e.Value }
    }
    try {
        $null = New-Item -ItemType Directory -Force -Path $readDir -ErrorAction SilentlyContinue
        # A FAILURE TO ESTABLISH ISOLATION IS NOT AN UNREACHABLE ORIGIN, and until round 18 both
        # arrived at the caller as the same `$null` -- reported as "the declared origin could not be
        # asked", which is false, and which is the branch that leaves the gate open. If the private
        # directory is not there, this read never happened and saying so is the honest outcome.
        if (-not (Test-Path -LiteralPath $readDir)) {
            $script:EvidenceOriginReadFailure = 'isolation'
            return $null
        }
        $script:EvidenceOriginReadFailure = $null
        foreach ($n in @($svGit.Keys)) { [Environment]::SetEnvironmentVariable($n, $null) }
        # Cleared first, restored by name -- so the DEFAULT is deny and the exception is explicit.
        # Doing it in the other order would make the list a blacklist again.
        foreach ($n in $keepTransport) {
            if ($svGit.ContainsKey($n)) { [Environment]::SetEnvironmentVariable($n, $svGit[$n]) }
        }
        # HOME IS REDIRECTED ONLY WHERE GIT_CONFIG_GLOBAL IS NOT HONOURED (V-1 round 19, WP-1
        # finding; the deciding measurement is in this commit's message). Both mechanisms close
        # the global-config route independently -- driven, with a hostile `$HOME/.gitconfig` and a
        # working positive control on either side of the run -- so below git 2.32 the redirect is
        # the fallback, and at or above it the redirect buys nothing and costs the CREDENTIAL STORE,
        # which lives under the real HOME.
        #
        # That cost is not hypothetical: with HOME redirected, a credential-gated origin returns
        # NULL, every settle against it lands on "REMAINS OPEN AND STILL AUTHORIZES", and amendment
        # 20's requirement to ask the declared origin becomes unattainable for that whole origin
        # class. Carrying `credential.helper` forward alone did NOT fix it -- the helper is named in
        # config and its store is not.
        $gitMajorMinor = 0.0
        try {
            $gv = & git --version 2>&1
            $gm = [regex]::Match("$gv", '(\d+)\.(\d+)')
            if ($gm.Success) { $gitMajorMinor = [double]("{0}.{1:D2}" -f [int]$gm.Groups[1].Value, [int]$gm.Groups[2].Value) }
        } catch { }
        if ($gitMajorMinor -lt 2.32) {
            # Old git: GIT_CONFIG_GLOBAL is ignored, so the redirect is the only thing standing
            # between this read and `$HOME/.gitconfig`. Credentials lose; isolation wins.
            $env:HOME = $neutral; $env:USERPROFILE = $neutral; $env:XDG_CONFIG_HOME = $neutral
        }
        $env:GIT_CONFIG_NOSYSTEM = '1'; $env:GIT_CONFIG_GLOBAL = $nowhere; $env:GIT_CONFIG_SYSTEM = $nowhere
        $env:GIT_CEILING_DIRECTORIES = $neutral
        # `-c` is a GLOBAL option and must precede the subcommand. An empty first value would reset
        # the helper list, so blanks were filtered at capture.
        $credArgv = @()
        foreach ($h in $credHelpers) { $credArgv += @('-c', $h) }
        $out = & git -C $readDir @credArgv ls-remote $askUrl 2>&1
        if ($LASTEXITCODE -ne 0) {
            # THREE OUTCOMES, NOT ONE (V-1 round 19, WP-1 findings). "Never asked",
            # "asked and refused authentication" and "asked and got no answer" were all arriving at
            # the caller as the same $null, and the caller reports the third. Only the third is
            # evidence about the ORIGIN; the first two are facts about this machinery and its
            # credentials, and the settle path stamps them into gate artifacts.
            $errText = ("$out")
            if ($errText -match 'could not read (Username|Password)' -or
                $errText -match 'Authentication failed' -or
                $errText -match 'terminal prompts disabled' -or
                $errText -match 'HTTP Basic: Access denied' -or
                $errText -match 'fatal: Authentication') {
                $script:EvidenceOriginReadFailure = 'auth'
            }
            return $null
        }
    } catch { return $null } finally {
        $env:HOME = $svHome; $env:USERPROFILE = $svUp; $env:XDG_CONFIG_HOME = $svXdg
        foreach ($n in @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GIT_CEILING_DIRECTORIES')) {
            [Environment]::SetEnvironmentVariable($n, $null)
        }
        foreach ($n in @($svGit.Keys)) { [Environment]::SetEnvironmentVariable($n, $svGit[$n]) }
        $ErrorActionPreference = $prev
        try { Remove-Item -LiteralPath $neutral -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
    # AN ORDINAL DICTIONARY, NOT `@{}`. PowerShell hashtable keys FOLD CASE and git refs do not, so
    # refs/heads/main and refs/heads/Main -- two different refs that can point at different commits --
    # shared one slot and the last one read won. That loses a ref in the direction that HIDES a stray
    # one, which is the single thing this enumeration exists to catch. Same family as the
    # first-40-hex defect round 12 drove: there the decoy won by sort order, here by insertion order.
    #
    # MEASUREMENT STATUS (T-2s): the language behaviour is DRIVEN -- `@{}` collapses the two keys, an
    # ordinal Dictionary keeps both. The end-to-end consequence is a READING and was NOT drivable on
    # the build host: git refused to create the colliding ref against a Windows bare origin with
    # `cannot lock ref 'refs/heads/Main': reference already exists`, because loose refs are files and
    # this filesystem is case-insensitive. On a case-sensitive server both refs exist.
    $refs = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($line in @($out)) {
        $m = [regex]::Match("$line", '^([0-9a-f]{40})\s+(\S+)$')
        if ($m.Success) { $refs[$m.Groups[2].Value] = $m.Groups[1].Value }
    }
    return $refs
}

function Get-EvidenceRemoteRefSha {
    # One ref of the DECLARED origin, by exact refname. Never a prefix, never a first match.
    param([string]$Root, [string]$Url, [string]$Ref)
    if (-not $Url -or -not $Ref) { return $null }
    $refs = Get-EvidenceRemoteRefs -Root $Root -Url $Url
    if ($null -eq $refs) { return $null }
    if ($refs.ContainsKey($Ref)) { return $refs[$Ref] }
    return ''      # asked and answered: the remote holds NO such ref. Distinct from $null.
}

# CONSUMPTION IS BOUND TO A REAL REF ADVANCE.
#
# THE CLAIM THIS BLOCK USED TO REST ON WAS THAT CLASSIFICATION IMPLIES PUBLICATION, and it was
# measured false: with a live gate, `git lfs env` -- which publishes nothing -- was allowed, this
# function stamped `consumed_at`, `mission-gate.ps1 list` then read the gate CONSUMED, and the
# operator's real push was DENIED. A tombstone is testimony that an authorized act occurred, so a
# tombstone for an act that did not occur is the worse half of the pair: it corrupts the record AND
# it costs the operator the authorization they were holding.
#
# TWO INDEPENDENT FACTS ARE NOW REQUIRED, AND NEITHER IS THIS SESSION'S OPINION:
#   (a) the DECIDER recorded a publication of the authorized sha in flight -- git's own fact, taken
#       after expansion. THIS USED TO READ "and impossible for a non-publishing command to produce",
#       WHICH IS FALSE AND WAS DRIVEN FALSE (V-1 round 14, WP-4): `git push --dry-run` runs the
#       pre-push hook and writes exactly this witness, and git hands a pre-push hook no way to tell
#       a dry run from a publication -- so at THAT layer the property is not merely unmet, it is
#       unattainable. It is (b) that carries the weight, which is the whole point: the local
#       layers are tripwires and origin is the only thing that cannot be spelled around; and
#   (b) the REMOTE is observed to hold that sha -- origin's own answer, the A3 ladder's top rung.
# Absent either, NOTHING is consumed and the reason is returned so the caller can record it. A gate
# left unspent after a real push would be the single-use property gone, which is why (b) exists and
# why an unanswerable remote returns a reason rather than a shrug.
function Complete-EvidencePushGate {
    # THE `-OriginTip` PARAMETER IS GONE, AND IT WAS THE THIRD DEAD FIELD IN THIS ONE LIFECYCLE.
    # It was declared here and passed `$null` by its only caller, and read by nothing -- after
    # `written_at` (cured in amendment 20) and `remote_sha_before` (declared cured, actually inert
    # until round 14). E85 says a field a record carries but nothing reads is a claim about a check
    # that does not happen; a PARAMETER nobody reads makes the same claim to anyone reading the
    # signature, which is where a reader looks first.
    param([string]$Root)
    $records = @(Get-EvidencePushInFlightRecords -Root $Root)
    if ($records.Count -eq 0) {
        return @{ consumed = $null
                  reason = "no in-flight record: the pre-push decider did not witness a publication from this repository, so nothing is consumed. A command that publishes nothing may not spend an authorization (amendment 19)." }
    }

    $consumedPaths = @(); $disqualifiedPaths = @(); $notes = @(); $keep = @()
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)

    # EVERY WITNESS IS SETTLED ON ITS OWN TERMS. One unreachable origin must not strand a second
    # push to a reachable one, and one settled push must not clear a witness that is still waiting.
    foreach ($rec in $records) {
        $url = [string]$rec.remote_url
        if (-not $url) {
            $notes += "a witness carries no DECLARED origin url, so there is no trustworthy remote to ask; amendment 20 forbids falling back to remote.origin.url, and it is dropped rather than guessed at"
            continue
        }

        $refs = Get-EvidenceRemoteRefs -Root $Root -Url $url
        if ($null -eq $refs) {
            # UNKNOWN IS THE ONLY STATE THE AGE BOUND GOVERNS (V-1 round 14, a WP-1 finding and a WP-4 finding).
            #
            # This test used to run FIRST, above the origin read, for every record. So a witness
            # that merely aged out was disqualified even when the origin was sitting there ready to
            # answer -- and the artifact was stamped with a note reading "the declared origin could
            # not be asked to confirm it", which the branch had no way to know and which was driven
            # FALSE: origin answered ls-remote immediately before and after the decision, the push
            # had really landed, and the gate was stamped `witness_expired_at` with `consumed_at:
            # null`. A real publication ended with no tombstone and a false explanation on the
            # audit record.
            #
            # It also cost the operator authorizations they were holding: `git push --dry-run`
            # writes a witness, an out-of-session operator push fires no PostToolUse at all (S-4 /
            # E22 -- the contract's OWN canonical publication path), and past the bound the next
            # hook-visible command disqualified a gate for a publication nobody had made.
            #
            # Moved here, the bound finally means what it always claimed: a limit on how long an
            # UNCONFIRMABLE witness stays actionable. Round 13's driving case is not lost but
            # improved -- a stale witness for a push that DID land now reaches the settle loop and
            # CONSUMES its gate on origin's own answer, instead of disqualifying it on a guess.
            if (-not (Test-EvidencePushInFlightFresh -Flight $rec)) {
                foreach ($e in @($rec.entries)) {
                    $gp = [string]$e.gate_path
                    if (-not $gp -or -not (Test-Path -LiteralPath $gp)) { continue }
                    $gt = [System.IO.File]::ReadAllText($gp)
                    if (Test-EvidenceGateFieldSet -Text $gt -Field 'witness_expired_at') { continue }
                    $gt = $gt.TrimEnd() + "`nwitness_expired_at: $stamp`n"
                    # THIS BRANCH WRITES THE RECORD, AND IT WAS THE ONE NOT CONSULTING THE FLAG
                    # (V-1 round 19, a WP-1 finding, driven). It stamped "WAS ASKED and could not
                    # answer" into the gate artifact when no `ls-remote` had run -- byte-identical to
                    # the note for a genuinely unreachable origin. Round 18 cured the branch that
                    # RETURNS a string and left the branch that WRITES the record, which is the one
                    # an auditor reads years later.
                    $askedClause = switch ($script:EvidenceOriginReadFailure) {
                        'isolation' { "the declared origin '$url' WAS NEVER ASKED -- the isolated read could not be set up (its private directory could not be created), so no query reached any origin. This sentence is a fact about this machinery, NOT about the origin" }
                        'auth'      { "the declared origin '$url' WAS ASKED AND REFUSED THE CREDENTIALS AVAILABLE HERE -- it answered, and what it answered was that this reader may not look. That is a configuration failure of the reader, NOT evidence that the publication did or did not land" }
                        default     { "the declared origin '$url' WAS ASKED and could not answer" }
                    }
                    $gt = $gt.TrimEnd() + "`nwitness_expired_note: `"The pre-push decider witnessed a publication of $([string]$e.authorized_sha) to $([string]$e.remote_ref), and $askedClause before the witness aged out. Whether it landed is UNKNOWN, so this authorization is disqualified rather than consumed -- consuming it would assert a publication nobody observed. Re-mint to authorize again.`"`n"
                    [System.IO.File]::WriteAllText($gp, $gt, (New-Object System.Text.UTF8Encoding($false)))
                    $disqualifiedPaths += $gp
                }
                $notes += "the declared origin '$url' could not be asked AND this witness is STALE (written $([string]$rec.written_at)): unconfirmable and out of time is the one state the bound governs, so its gate(s) are DISQUALIFIED rather than consumed"
                continue
            }
            $keep += $rec
            # AND SAY WHAT THAT COSTS, because the half that is not said is the permissive half
            # (V-1 round 18, a WP-1 finding, driven). Leaving the witness in place is the right
            # call for a transient failure -- disqualifying a real publication because a network
            # blinked would be worse -- but until the bound expires the gate REMAINS OPEN AND
            # STILL AUTHORIZES, and a reader who is told only "nothing is consumed" hears the
            # safe half of that. The validator reached round 17's own CRITICAL end-state through
            # this branch with no attacker present, purely by making the origin unreachable.
            $notes += "the declared origin '$url' " + $(switch ($script:EvidenceOriginReadFailure) { 'isolation' { "COULD NOT BE ASKED SAFELY -- the private read directory could not be created, so the isolated read never ran. This is NOT evidence about the origin: it is a failure of this machinery, most likely TMP/TEMP pointing somewhere unusable, and it should be fixed rather than waited out. " } 'auth' { "REFUSED THE CREDENTIALS AVAILABLE HERE -- it answered, and the answer was that this reader may not look. The isolated read carries the whole credential.* family forward from the repository's own configuration; if this origin's credentials come from somewhere else entirely, it can never be confirmed and every gate against it will sit in exactly this state until that is fixed. " } default { "" } }) + "could not be asked what it holds, so this publication is unconfirmed and nothing is consumed; the witness is LEFT IN PLACE for the next attempt and expires by its own age bound. UNTIL THEN THIS GATE REMAINS OPEN AND STILL AUTHORIZES -- an unconfirmable settlement is the permissive outcome, not a refusal, and repeated unreachability is indistinguishable here from a publication that never happened. If the origin is unreachable BY CONSTRUCTION rather than transiently, revoke the gate rather than waiting out the bound."
            continue
        }

        # EACH SETTLED REF CARRIES ITS OWN OBSERVED SHA. A first draft of this loop stamped every
        # gate with the observed value of the FIRST entry -- reintroducing, inside the cure, exactly
        # the first-of-a-class defect the cure exists to remove.
        $settle = @()
        foreach ($e in @($rec.entries)) {
            $sha = [string]$e.authorized_sha
            $ref = [string]$e.remote_ref
            $observed = if ($refs.ContainsKey($ref)) { $refs[$ref] } else { '' }
            if ($observed -cne $sha) {
                $notes += "$ref -> declared origin holds '$observed', authorized '$sha': not published, not spent"
                continue
            }
            $v = Get-EvidencePushGateForSha -Root $Root -Sha $sha -OriginUrl $url -RemoteRef $ref
            if (-not $v.ok -or -not $v.path) { $notes += "$ref -> published, but no unconsumed gate now binds it ($($v.reason))"; continue }

            # THE CONDITION THE RULING ASKED FOR, ACTUALLY WIRED (V-1 round 14, a WP-4 finding).
            # `$advanced` was computed here, written into `consumed_basis` as prose, and READ BY NO
            # BRANCH -- under a comment insisting the field was "CONSULTED, not merely stored" and
            # citing an erratum while committing it. The ruling said CONDITIONAL. The code said RECORDED.
            # The comment said the ruling had been honoured, which is why three readings missed it.
            #
            # The ref already held the authorized sha when this push began, so THIS push published
            # nothing, and a push that published nothing may not spend an authorization -- the false
            # tombstone amendment 19 abolished, arriving by a quieter route.
            #
            # LEAVING IT OPEN IS THE MORE PERMISSIVE DIRECTION AND THAT IS SAID PLAINLY, NOT BURIED:
            # what bounds it is that the gate stays single-use and bound to (origin url, ref, sha),
            # so the only act it can ever authorize is the exact publication it already names -- one
            # origin is at this moment observed to hold.
            $before = [string]$e.remote_sha_before
            if ($before -ceq $observed) {
                $notes += "$ref -> origin already held '$observed' before this push, so this push published nothing and its gate is NOT spent"
                continue
            }
            $settle += [pscustomobject]@{ Path = $v.path; Ref = $ref; Observed = $observed; Before = $before }
        }

        foreach ($sv in $settle) {
            $t = [System.IO.File]::ReadAllText($sv.Path)
            # FIRST STAMP WINS, AND IT IS ENFORCED HERE RATHER THAN FIELD BY FIELD (operator
            # ruling (i): "the in-session PostToolUse settle stays; first stamp wins,
            # the second refuses").
            #
            # WHY A REFUSAL AT THE TOP AND NOT A WIDER GUARD BELOW. Get-EvidencePushGateForSha
            # filters consumed gates out of the SELECTION, so it looked as though this loop could
            # never meet one. It can: selection runs to completion for the WHOLE record before any
            # write, so two entries naming the same ref both resolve to the same still-unconsumed
            # gate, and this loop then visits it twice. DRIVEN -- one record, two identical
            # entries, and the second visit appended consumed_origin_tip, consumed_ref,
            # consumed_origin_before and consumed_basis a SECOND time while the consumed_at guard
            # below correctly left that one field alone.
            #
            # So the artifact carried TWO consume blocks under ONE consumed_at: "a missing record
            # traded for an ambiguous one", which is verbatim the harm the guard below names and
            # was written to prevent -- reappearing one field further on, because the guard was
            # attached to a FIELD when the property belongs to the GATE. Widening it to cover four
            # more fields would leave the fifth addition to remember for itself; refusing the gate
            # whole makes it true by construction.
            # AND IT IS NOW ACTUALLY THE GATE (round 3, a review finding, driven). The paragraph above
            # says "refusing the gate whole makes it true by construction" and then tested ONE field
            # of the five, so the claim was false of this SHIPPED guard exactly as it was false of the
            # one it replaced: driven over a gate carrying the four appended fields with consumed_at
            # still reading the literal `null`, this predicate answered False and the loop would have
            # appended a second consume block. The console's settle carried the identical gap.
            #
            # NO INNER `foreach` HERE, AND THAT IS NOT A STYLE CHOICE. This test sits inside
            # `foreach ($sv in $settle)`; a `foreach` over the five field names would make the
            # `continue` below continue the INNER loop and FALL THROUGH TO THE WRITE -- the cure
            # writing the defect. Get-EvidenceGateConsumeBlock resolves the whole question in one
            # call, so the `continue` stays at the depth it has always been at.
            $cb = Get-EvidenceGateConsumeBlock -Text $t
            if ($cb.any) {
                $notes += "$($sv.Ref) -> its gate ALREADY CARRIES part of a consume block ($($cb.joined)) and is left untouched: a gate records ONE use, and a second stamp would append a second consume block to an audit artifact (first stamp wins, operator ruling (i))"
                continue
            }
            # THE SENTINEL IS REPLACED WHEREVER IT IS AND WHATEVER TRAILS IT (round 6 sweep). The
            # anchored form required `null` to end the line, so `consumed_at: null   # not yet` was
            # not replaced -- and the guard below, testing the sentinel-blind `\S`, then read `null`
            # as a value and appended nothing. The gate was never stamped, the push had already
            # happened, and the same gate authorised the next one.
            #
            # The REPLACE is what widens; the append stays strictly the no-line case. Appending
            # beside a surviving sentinel would put two `consumed_at` keys in an AUDIT artifact,
            # which trades a missing record for an ambiguous one.
            if (-not (Test-EvidenceGateFieldSet -Text $t -Field 'consumed_at')) {
                if ($t -match '(?m)^consumed_at:') { $t = $t -replace '(?m)^consumed_at:.*$', "consumed_at: $stamp" }
                else { $t = $t.TrimEnd() + "`nconsumed_at: $stamp`n" }
            }
            # THE ORIGIN TIP IS NOT TAKEN ON TRUST FROM THE CALLER. It is what the remote was
            # OBSERVED to hold at consumption time, which is the same fact the decision turned on.
            $t = $t.TrimEnd() + "`nconsumed_origin_tip: $($sv.Observed)`n"
            $t = $t.TrimEnd() + "`nconsumed_ref: $($sv.Ref)`n"
            $t = $t.TrimEnd() + "`nconsumed_origin_before: $(if ($sv.Before) { $sv.Before } else { '(none)' })`n"
            $t = $t.TrimEnd() + "`nconsumed_basis: pre-push in-flight witness for this ref + the DECLARED origin observed holding the authorized sha, having ADVANCED from '$(if ($sv.Before) { $sv.Before } else { '(none)' })' (amendment 20)`n"
            [System.IO.File]::WriteAllText($sv.Path, $t, (New-Object System.Text.UTF8Encoding($false)))
            $consumedPaths += $sv.Path
            $notes += "$($sv.Ref) -> published at $($sv.Observed) (was '$($sv.Before)') and its gate consumed"
        }
    }

    # THE WITNESSES THAT SURVIVE ARE WRITTEN BACK, and only those. A record leaves this file by
    # being settled, disqualified, or found to have published nothing -- never by being overwritten.
    [void](Set-EvidencePushInFlightRecords -Root $Root -Records $keep)

    if ($consumedPaths.Count -eq 0) {
        return @{ consumed = $null; disqualified = $disqualifiedPaths
                  reason = ("nothing consumed. " + ($notes -join ' ; ')) }
    }
    return @{ consumed = $consumedPaths[0]; consumed_all = $consumedPaths; disqualified = $disqualifiedPaths
              reason = ("gate(s) consumed against the DECLARED origin -- " + ($notes -join ' ; ')) }
}

# IS THE DECIDER INSTALLED, AND IS IT THE ONE WE SHIPPED? (amendment 19 item 3.)
#
# A hook that can be deleted is answered by DETECTION, not by pretending it cannot be. The expected
# wrapper text is defined HERE, once, and both the runner's refusal and the instrument's member
# compare against this same definition -- so the two cannot drift, which is the defect this file
# keeps recording. The wrapper is deliberately tiny and fixed: all the logic lives in the vendored
# `evidence-pre-push.ps1`, which is a tracked file and therefore covered by the tree sha.
function Get-EvidencePrePushWrapperText {
    param([string]$DeciderPath)
    $p = ($DeciderPath -replace '\\', '/')
    return "#!/bin/sh`n# LAM amendment 19 / ruling HALT-24 -- the DECIDER.`n# git runs this AFTER all shell expansion and hands it the real remote, refspec and sha on stdin,`n# which is why spelling is irrelevant here. Do not edit: the runner and WP-4 both verify its sha256.`n#`n# AMENDMENT 20: this wrapper is a TRIPWIRE, not a boundary. `git push --no-verify` skips it, and so`n# does core.hooksPath pointed elsewhere. Both are documented git behaviour, neither is a defect here,`n# and the contract now says so (LAM-ACCEPT T-2). What cannot be skipped is what ORIGIN accepts.`nexec powershell -NoProfile -ExecutionPolicy Bypass -File `"$p`" `"`$@`"`n"
}

function Get-EvidencePrePushWrapperFingerprint {
    # WHAT "THE SHIPPED WRAPPER" MEANS, WITH THE PATH TAKEN OUT OF IT (amendment 20).
    #
    # The expected sha256 used to be taken over the wrapper's whole text, which embeds the decider's
    # ABSOLUTE path. Two byte-identical installations therefore disagreed whenever the decider lived
    # somewhere else -- and LAM-INSTALL sec 2 explicitly contemplates VENDORING the next-gen tree
    # INSIDE a mission repository, so the supported layout was the one that failed. Driven by an
    # independent reader in round 12: a correct vendored decider reported `installed:false` and the
    # runner refused the dispatch.
    #
    # The fingerprint is the wrapper with the -File argument replaced by a placeholder. It answers
    # "is this our wrapper, unedited" without answering "does it live where I expect", which was
    # never the question. The path is still REPORTED, so a human can see where it points.
    param([string]$Text)
    if ($null -eq $Text) { return $null }
    $norm = [regex]::Replace($Text, '-File\s+"[^"]*"', '-File "<DECIDER>"')
    return [BitConverter]::ToString(
        ([Security.Cryptography.SHA256]::Create()).ComputeHash([Text.Encoding]::UTF8.GetBytes($norm))
    ).Replace('-', '').ToLowerInvariant()
}

function Get-EvidenceEffectiveHooksPath {
    # WHICH HOOK WOULD GIT ACTUALLY RUN? (amendment 20.)
    #
    # The old check tested for a FILE at <root>\.git\hooks\pre-push. Driven by two independent
    # readers in round 12: with the correct wrapper in place AND `core.hooksPath` redirected, the
    # checker reported installed:true, the runner proceeded, and a real gateless push PUBLISHED --
    # into an empty bare origin. The file existed; git was running something else entirely.
    #
    # `git rev-parse --git-path hooks` is git's OWN answer to "where are my hooks", and it accounts
    # for core.hooksPath AS THAT APPLIES TO THE TREE IT IS ASKED ABOUT.
    #
    # IT DOES NOT ACCOUNT FOR WORKTREES, AND THIS COMMENT SAID IT DID FOR FIVE ROUNDS (V-1 round 17,
    # WP-2 and WP-1 findings, driven). git answers about the repository named by `-C`; the runner
    # names the mission root, and the push is issued from a worktree that does not exist when the
    # question is asked. Asking git cannot be out-argued by configuration IN THE TREE ASKED ABOUT --
    # which is a smaller claim than the one this paragraph used to make, and it is the true one.
    # The cross-tree question is refused separately, by Test-EvidenceHooksPathTreeVariance.
    #
    # This does NOT make the decider a boundary. core.hooksPath can still be pointed elsewhere; what
    # changes is that the check now SEES it rather than reporting green over it.
    # AND GIT IS ASKED TO ANSWER IN ABSOLUTE TERMS, SO NOBODY HAS TO RESOLVE ITS ANSWER
    # (V-1 round 16, a CRITICAL and a HIGH WP-2 finding, both driven).
    #
    # This used to take git's RELATIVE answer and join it onto `$Root`. Two defects rode on that one
    # line, and both were the mistake round 15 cured forty lines below while leaving this one:
    #
    #   * `core.hooksPath = relhooks` -> git answers `relhooks`; joining it onto `$Root` -- the
    #     mission root, fixed before any worktree exists -- resolves against a DIFFERENT TREE than
    #     git will, which resolves against the tree the push is ISSUED FROM. Driven to a real
    #     ungated publication from a worktree.
    #   * `core.hooksPath = C:relhooks` is DRIVE-RELATIVE; `IsPathRooted` calls it rooted, so the
    #     anchor was skipped entirely and GetFullPath resolved it against the process's per-drive
    #     current directory -- landing the hooks path inside an unrelated repository.
    #
    # `--path-format=absolute` (git 2.31+) makes GIT do the resolution, against the tree it is
    # actually operating on. The question that could be answered wrongly is not asked. The old join
    # survives only as a fallback for a git too old to know the flag, and is marked as the weaker
    # answer it is.
    #
    # E107 -- written this round, and this is what failing it looks like: I searched for siblings of
    # the `-File` RESOLUTION and found none, when the class is "a path git hands us that we resolve
    # ourselves". The sibling was one function away.
    param([string]$Root)
    $out = $null
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Root rev-parse --path-format=absolute --git-path hooks 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Older git: fall back to the relative answer and anchor it. This is the WEAKER answer --
            # it re-opens the wrong-tree ambiguity above -- and it is kept only so an old git degrades
            # rather than reporting "no hooks path" and refusing every dispatch.
            $out = & git -C $Root rev-parse --git-path hooks 2>&1
            if ($LASTEXITCODE -ne 0) { return $null }
            $p = ("$out").Trim()
            if (-not $p) { return $null }
            if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $Root $p }
            try { return [System.IO.Path]::GetFullPath($p) } catch { return $p }
        }
    } catch { return $null } finally { $ErrorActionPreference = $prev }
    $p = ("$out").Trim()
    if (-not $p) { return $null }
    try { return [System.IO.Path]::GetFullPath($p) } catch { return $p }
}

function Test-EvidenceHooksPathTreeVariance {
    # WILL GIT'S ANSWER TO "WHERE ARE MY HOOKS" BE THE SAME IN A TREE THAT DOES NOT EXIST YET?
    #
    # V-1 round 17, a WP-2 finding (CRITICAL) and a WP-1 finding (HIGH) -- one defect, found independently
    # by two validators on two packages, each driving it to a REAL gateless publication with the
    # checker reporting installed:true and the runner exiting 0.
    #
    # Round 16 replaced a hand-rolled join with `--path-format=absolute` under a comment that had
    # ALREADY diagnosed the real problem: "the mission root, fixed before any worktree exists,
    # resolves against a DIFFERENT TREE than git will". The flag decides what a relative answer is
    # anchored TO. It does not decide WHICH REPOSITORY IS ASKED, and `git -C $Root` still asks about
    # $Root -- which `mission-dispatch.ps1` sets to the mission root, before the worktree exists.
    # The sentence was true and about a different variable. WP-2: "the variable was never the path
    # format; it was the anchor." WP-1: "the predicate is right, the root it is handed is wrong."
    #
    # RE-ASKING AFTER THE WORKTREE EXISTS IS NOT AVAILABLE. ADR-026 gives the worktree to the CLI,
    # which creates it DURING the spawn and runs the worker inside it; there is no moment at which
    # the runner holds control between "the worktree exists" and "the worker may push". So the
    # question cannot be answered late, and answering it early for one tree is the guess that
    # published twice.
    #
    # SO THE VARIANCE IS REFUSED RATHER THAN RESOLVED -- which is what this file already does three
    # lines away for a relative `-File`, and WP-1 said so unprompted: "the build cured this exact
    # ambiguity correctly by REFUSING it; here it is resolved by picking a tree."
    #
    # TWO WAYS THE ANSWER CAN DIFFER BETWEEN TREES, AND BOTH WERE DRIVEN TO A PUBLICATION:
    #   * a RELATIVE core.hooksPath resolves against the tree the hook runs in (WP-2 shape A, which
    #     is round 16's CRITICAL finding verbatim -- relocated by the cure, not closed);
    #   * `extensions.worktreeConfig` lets a worktree carry its OWN core.hooksPath, fully absolute
    #     and invisible from the main tree (WP-2 shape B -- which `--path-format=absolute` cannot
    #     reach BY CONSTRUCTION, since the value is already absolute and simply belongs to another
    #     tree).
    #
    # Unset is INVARIANT: hooks live in the common git directory, which every linked worktree shares.
    param([string]$Root)
    $raw = $null; $wtCfg = $null; $cond = @(); $wtSeen = @(); $localHooks = $null; $localCond = @()
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $raw = & git -C $Root config --get core.hooksPath 2>&1
        if ($LASTEXITCODE -ne 0) { $raw = $null }
        $wtCfg = & git -C $Root config --get extensions.worktreeConfig 2>&1
        if ($LASTEXITCODE -ne 0) { $wtCfg = $null }
        # CONDITIONALITY ITSELF, NOT THE KINDS OF CONDITION (V-1 round 18, a WP-2 finding, CRITICAL,
        # driven to an ungated publication). Every `includeIf` section is an ordinary config key --
        # measured: `includeif.gitdir/i:**/worktrees/**.path` and `includeif.onbranch:feature.path`
        # both list -- so asking whether ANY exists covers gitdir, gitdir/i, onbranch, hasconfig and
        # whatever git adds next, without this function knowing what any of them mean.
        $cond = @(& git -C $Root config --get-regexp '^includeif\.' 2>&1 | Where-Object { "$_" -match '\S' })
        if ($LASTEXITCODE -ne 0) { $cond = @() }
        # THE LOCAL SCOPE ON ITS OWN, for the narrow exemption below (V-1 round 19, a WP-2 finding).
        $localHooks = & git -C $Root config --local --get core.hooksPath 2>&1
        if ($LASTEXITCODE -ne 0) { $localHooks = $null }
        # REACHABILITY, NOT SCOPE (V-1 round 20, a WP-2 finding, CRITICAL, driven to an ungated
        # publication). This read was `--local --get-regexp`, which answers "does the local FILE
        # carry a conditional" -- not "can the local scope REACH one". A local file reaches a
        # conditional through an ordinary `[include] path = ...`, and that read is blind to it while
        # the all-scopes read is not. So `$localBinds` was true, the refusal below was skipped, and
        # the conditional won because `include.path` appends AFTER `[core]` and the later value wins
        # within a scope. Measured: --local saw 0 entries, --show-scope labelled it `local`, the
        # narrowing answered invariant=TRUE, and the worktree then resolved a different hooks path.
        # WP-2 drove that to `git push` rc 0 with a hostile hook running and the decider never
        # invoked.
        #
        # WHICH SCOPES BLOCK THE EXEMPTION, by precedence rather than by list:
        #   global/system  lose to a local value -- this is the case the exemption exists for;
        #   local          wins, by the append-after-[core] route above;
        #   worktree/command outrank local outright.
        $localCond = @()
        $scopedCond = & git -C $Root config --show-scope --get-regexp '^includeif\.' 2>&1
        if ($LASTEXITCODE -eq 0) {
            foreach ($sline in @($scopedCond)) {
                $st = "$sline"
                if (-not $st.Trim()) { continue }
                # `--show-scope` prefixes each entry with its scope and a TAB.
                if ($st -match '^(local|worktree|command)[\s]') { $localCond += $st.Trim() }
            }
        }
        # WHAT EVERY EXISTING WORKTREE ACTUALLY RESOLVES, not what the extension flag suggests
        # (V-1 round 19, a review finding, driven). A linked worktree's `config.worktree` is not in this tree's
        # view: with the extension on and the shared value unset, the main tree answers '' while a
        # worktree answers its own absolute path, and this function returned invariant=TRUE.
        $wtPaths = @()
        foreach ($ln in @(& git -C $Root worktree list --porcelain 2>&1)) {
            $m = [regex]::Match("$ln", '^worktree\s+(.+)$')
            if ($m.Success) { $wtPaths += $m.Groups[1].Value.Trim() }
        }
        if ($LASTEXITCODE -ne 0) { $wtPaths = @() }
        foreach ($wp in $wtPaths) {
            if (-not (Test-Path -LiteralPath $wp)) { continue }
            $wv = & git -C $wp config --get core.hooksPath 2>&1
            if ($LASTEXITCODE -ne 0) { $wv = '' }
            $wtSeen += [pscustomobject]@{ path = $wp; value = ("$wv").Trim() }
        }
    } catch { } finally { $ErrorActionPreference = $prev }
    $rawVal = if ($raw) { ("$raw").Trim() } else { '' }
    $wtVal = if ($wtCfg) { ("$wtCfg").Trim() } else { '' }
    # Git's boolean spellings, not PowerShell's. `[bool]'false'` is TRUE, and reading a git config
    # boolean through PowerShell's cast is its own small family of defect.
    # FIRST, because a conditional include can produce either of the shapes below and neither test
    # would see it. The condition is evaluated against the TREE, and the tree that will push does
    # not exist yet -- so this is not "a route we have not closed", it is the same defect one level
    # up: a question about the worker's tree, answered from the mission root.
    $localVal = if ($localHooks) { ("$localHooks").Trim() } else { '' }
    # ONE NARROW EXEMPTION, DRIVEN (V-1 round 19, a WP-2 finding). A conditional include cannot change what
    # core.hooksPath resolves to when the LOCAL scope already sets it: measured, the include wins in
    # both trees on its own and loses in both trees to a local absolute value.
    #
    # This refusal is round 18's CRITICAL finding, which was reached through an ungated publication, so the
    # exemption is deliberately tight. All three conditions are required:
    #   * local sets core.hooksPath, fully qualified;
    #   * the EFFECTIVE value equals the local one -- if something beats local it is already winning,
    #     and GIT_CONFIG_COUNT / GIT_CONFIG_PARAMETERS carry command-line precedence and do;
    #   * the local file carries no includeIf of its own, because a conditional inside the winning
    #     scope varies per tree, which is the defect itself.
    # It FALLS THROUGH rather than returning, so the worktreeConfig and not-fully-qualified branches
    # below still apply. One refusal is removed and no other.
    $localBinds = ($localVal -and $localVal -eq $rawVal -and @($localCond).Count -eq 0 -and
                   ($localVal -match '^[A-Za-z]:[/\\]' -or $localVal -match '^[/\\][/\\]' -or $localVal -match '^[/\\]'))
    if (@($cond).Count -gt 0 -and -not $localBinds) {
        $condNames = (@($cond) | ForEach-Object { (("$_" -split '\s+')[0]) }) -join ', '
        return @{ invariant = $false; hooks_path_config = $rawVal; worktree_config = $wtVal
                  conditional_includes = $condNames
                  reason = "this repository's git configuration is CONDITIONAL -- $(@($cond).Count) includeIf section(s): $condNames. A conditional include is evaluated against the tree git is running in, and the worktree this dispatch will push from does not exist yet, so what core.hooksPath resolves to here is not what it will resolve to there. Driven in V-1 round 18 to an ungated publication with the main tree reporting no core.hooksPath at all. Set core.hooksPath in THIS repository's LOCAL config to an absolute path -- WHICH WORKS ONLY IF THE CONDITIONAL IS IN GLOBAL OR SYSTEM SCOPE. Driven both ways (V-1 round 20, a WP-2 finding): against a GLOBAL include a local value wins in the main tree and in a linked worktree, and this check then accepts the repository with the include still in place; against a conditional the LOCAL scope reaches through an ordinary `[include]`, both halves are false -- the local value LOSES in the worktree, and this check still refuses. This sentence used to state the global result as a universal, which is round 19's own unperformable-remedy defect recurring one scope over, inside the cure written for it. For a locally-reachable conditional the remedy is to remove the include, or move it to global scope. Removing the include also works. What is NOT available is scoping an include so it cannot reach a key -- git has no such mechanism, and this sentence used to offer it as the first remedy (V-1 round 19, a WP-2 finding)." }
    }
    if ($wtVal -and $wtVal -notmatch '^(?i)(false|no|off|0)$') {
        # ...AND ONLY WHEN A HOOKS PATH IS ACTUALLY SET SOMEWHERE (V-1 round 18, a WP-2 finding).
        # With `core.hooksPath` unset in every scope, both trees demonstrably resolve to the shared
        # `.git/hooks`, and refusing that turned away ordinary repositories: `git sparse-checkout
        # set` enables this extension, so the refusal fired on a workflow nobody chose.
        if ($rawVal) {
            return @{ invariant = $false; hooks_path_config = $rawVal; worktree_config = $wtVal
                      reason = "extensions.worktreeConfig is enabled ('$wtVal') AND core.hooksPath is set ('$rawVal'), so that value can be overridden PER WORKTREE -- including in the worktree this dispatch has not created yet. What git answers for this tree does not bind the tree the push will be issued from." }
        }
        # AND THE CASE THE NARROWING ABOVE LET THROUGH: the shared value is unset, so `if ($rawVal)`
        # is false, while a worktree that ALREADY EXISTS carries its own (V-1 round 19, a review finding, driven --
        # main tree '', worktree 'C:\v19w\hostile-hooks', this function returning invariant=TRUE).
        #
        # MEASURED, NOT INFERRED FROM THE FLAG. Refusing whenever the extension is on would undo
        # round 18's finding -- `git sparse-checkout set` enables it, and the blanket refusal fired on
        # a workflow nobody chose. Asking each worktree what it resolves keeps that case passing,
        # because with nobody setting a hooks path no worktree disagrees.
        $divergent = @($wtSeen | Where-Object { $_.value -ne $rawVal })
        if ($divergent.Count -gt 0) {
            $names = (($divergent | ForEach-Object { "$($_.path) -> '$($_.value)'" }) -join '; ')
            return @{ invariant = $false; hooks_path_config = $rawVal; worktree_config = $wtVal
                      reason = "extensions.worktreeConfig is enabled ('$wtVal') and $($divergent.Count) existing worktree(s) already resolve core.hooksPath differently from this tree (which answers '$rawVal'): $names. A per-worktree value lives in that worktree's own config.worktree and is not visible from here, so this tree's answer does not describe the repository." }
        }
    }
    # `~` IS TREE-INVARIANT AND WAS REFUSED UNDER A SENTENCE THAT IS FALSE OF IT (V-1 round 18,
    # a WP-2 finding, driven -- both trees measured resolving to the same absolute path). Git expands a
    # leading `~` against the USER'S HOME, which does not vary by worktree, so the refusal's stated
    # mechanism -- "git resolves it against the working tree the hook runs in" -- is simply not what
    # happens for this value. A refusal that fires for a reason that is not true of the thing it
    # refuses teaches the operator to fix the wrong property.
    if ($rawVal -and $rawVal -notmatch '^~[/\\]' -and $rawVal -ne '~' -and
        -not (Test-EvidencePathIsFullyQualified -Path $rawVal)) {
        return @{ invariant = $false; hooks_path_config = $rawVal; worktree_config = $wtVal
                  reason = "core.hooksPath is set to '$rawVal', which is not fully qualified. Git resolves it against the working tree the hook runs in, and this build's runner pushes from a linked worktree created during the dispatch -- so this repository's answer is not the answer that will apply. Set core.hooksPath to an absolute path, or unset it." }
    }
    # THIS SENTENCE USED TO SAY "per-worktree config is off" UNCONDITIONALLY -- in the same hashtable
    # that returned `worktree_config = 'true'` (V-1 round 19, a review finding). A record contradicting its own
    # field in one breath. It now states what was measured, including how many trees were compared,
    # so a reader can tell an unset repository from one whose worktrees were checked and agreed.
    return @{ invariant = $true; hooks_path_config = $rawVal; worktree_config = $wtVal
              reason = "core.hooksPath is $(if ($rawVal) { "absolute ('$rawVal')" } else { 'unset, so hooks resolve to the shared common git directory' }); per-worktree config is $(if ($wtVal) { "enabled ('$wtVal') and all $(@($wtSeen).Count) existing worktree(s) resolve it identically" } else { 'not enabled' }), so every worktree of this repository gets the same answer." }
}

function Test-EvidencePrePushHookInstalled {
    # AMENDMENT 20: ASK GIT WHERE ITS HOOKS ARE, AND COMPARE A PATH-INDEPENDENT FINGERPRINT.
    # Two round-12 refutations land here, and neither was an exotic spelling:
    #   * core.hooksPath redirected -- file present, git running something else, checker said
    #     installed:true, and a gateless push really published;
    #   * a vendored decider -- byte-identical, refused, because the hash embedded an absolute path.
    param([string]$Root, [string]$DeciderPath)
    $expectedText = Get-EvidencePrePushWrapperText -DeciderPath $DeciderPath
    $expected = Get-EvidencePrePushWrapperFingerprint -Text $expectedText
    # THE DECIDER'S OWN BYTES. Without this the check hashes a CONSTANT: the wrapper's only variable
    # content is the -File path, and amendment 20 placeholders exactly that path so a VENDORED
    # decider is recognised. The fingerprint therefore verified nothing about what would run.
    # AN UNCOMPUTABLE EXPECTATION IS A REFUSAL, NOT A SKIP. The first version of this check guarded
    # the comparison with `$expectedDecider -and (...)`, so when the SHIPPED decider was absent the
    # whole content check was skipped rather than failed -- and a repository whose wrapper pointed at
    # an allow-everything script reported installed:true, on the strength of a fingerprint that by
    # construction hashes a constant. Driven, with a control: shipped decider present -> correctly
    # refused; shipped decider absent -> installed:true.
    #
    # That is a guard clause disabling the check it guards, committed inside the cure for a defect of
    # exactly that shape. If we cannot say what the decider SHOULD be, we cannot say the installed one
    # is right, and the honest answer is to refuse.
    if (-not (Test-Path -LiteralPath $DeciderPath)) {
        # `hooks_dir` IS NOT IN THIS RETURN, AND ITS ABSENCE IS THE FIX (V-1 round 15, a WP-2 finding).
        # It was, and `$hooksDir` is not assigned until five lines below -- so under the
        # Set-StrictMode this library inherits, the refusal THREW instead of speaking and the
        # operator was told "the checker output was not parsable: The variable '$hooksDir'".
        # A true refusal delivered as a parse error is the wrong-reason defect this function was
        # reordered to cure, reintroduced by the edit that cured it.
        #
        # The honest shape is to omit the field: at this point git has not been asked where its
        # hooks live, so this function does not know, and a record must not carry a value nobody
        # computed.
        return @{ installed = $false; path = $null; sha256 = $null; expected = $expected
                  reason = "the SHIPPED decider is not on disk at '$DeciderPath', so there is nothing to compare an installed one against. Refusing rather than reporting installed on a fingerprint that cannot see which script would run." }
    }
    $expectedDecider = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash([IO.File]::ReadAllBytes($DeciderPath))).Replace('-','').ToLowerInvariant()

    $hooksDir = Get-EvidenceEffectiveHooksPath -Root $Root
    if (-not $hooksDir) {
        return @{ installed = $false; path = $null; sha256 = $null; expected = $expected
                  reason = "git could not be asked where its hooks directory is for '$Root', so which hook would run is unknown. Refusing rather than guessing." }
    }
    $hookPath = Join-Path $hooksDir 'pre-push'
    if (-not (Test-Path -LiteralPath $hookPath)) {
        return @{ installed = $false; path = $hookPath; sha256 = $null; expected = $expected; hooks_dir = $hooksDir
                  reason = "the pre-push decider is NOT INSTALLED at $hookPath -- which is the hooks directory GIT ITSELF reports for THIS repository (core.hooksPath as it applies here). Whether every worktree agrees is a separate question and IS NOT ASKED ON THIS PATH: there is no hook to be consistent about, so the check returns here. T-2's tripwire at the publication point is absent." }
    }
    # THE BYTES ARE CHECKED FOR WHAT IS A PROPERTY OF BYTES (V-1 round 16, a WP-2 finding, driven).
    # `ReadAllText` strips a UTF-8 BOM before the fingerprint is taken, so a BOM'd wrapper -- which
    # git CANNOT SPAWN, failing with "cannot spawn" -- matched byte-for-byte as far as this check
    # was concerned and reported installed:true. Fail-closed at push time, because git refuses; but
    # a FALSE-GREEN PRECONDITION, telling the runner the tripwire is in force when it cannot run.
    # CRLF was already caught here and the BOM was not, and they are one class: the bytes on disk
    # are not what the fingerprint saw.
    $hookBytes = [System.IO.File]::ReadAllBytes($hookPath)
    if ($hookBytes.Length -ge 3 -and $hookBytes[0] -eq 0xEF -and $hookBytes[1] -eq 0xBB -and $hookBytes[2] -eq 0xBF) {
        return @{ installed = $false; path = $hookPath; sha256 = $null; expected = $expected; hooks_dir = $hooksDir
                  reason = "the pre-push hook at $hookPath begins with a UTF-8 BOM. git executes it through the shell, which cannot spawn a script whose first bytes are EF BB BF -- so this hook would fail to run at all, and a fingerprint taken over decoded TEXT cannot see it. Rewrite it without a BOM (the shipped wrapper is BOM-free)." }
    }
    $actualText = [System.IO.File]::ReadAllText($hookPath)
    $actual = Get-EvidencePrePushWrapperFingerprint -Text $actualText
    # WHICH decider does the INSTALLED wrapper point at, and is that file ours? The name is read from
    # the wrapper rather than assumed to be $DeciderPath -- assuming it is what let a substitution
    # through, since a vendored install legitimately points somewhere else.
    #
    # DRIVEN (V-1 round 13, WP-2): a wrapper with an IDENTICAL fingerprint pointing at an
    # allow-everything script reported installed:true, the runner exited 0, and a gateless push
    # PUBLISHED. In the vendored layout amendment 20 was written FOR, swapping only the vendored
    # decider's CONTENTS -- hook byte-untouched -- published into a repo with no gates directory.
    # E70: the cure that widened what "installed" RECOGNISES widened what it ACCEPTS, in one edit.
    #
    # VENDORING STILL WORKS: a vendored copy is byte-identical to the shipped decider, so it matches.
    # What no longer matches is a SUBSTITUTED one.
    # A RELATIVE `-File` IS REFUSED, BECAUSE THIS FUNCTION CANNOT HONESTLY RESOLVE ONE.
    #
    # Round 14 resolved it against `$Root` under a comment claiming it was "resolved the way git will
    # resolve it". It was not, and V-1 round 15 (a WP-2 finding) drove the difference: the runner sets
    # `$Root` to the mission root ONCE, before any worktree exists, while git resolves a hook's
    # relative path against the top level of the working tree the push is ISSUED FROM -- the worker's
    # linked worktree, which this build's runner CREATES. Checker against MAIN reported
    # installed:true and the runner exited 0; a real push from the worktree, with an allow-everything
    # script at that relative path, PUBLISHED.
    #
    # THERE IS NO BETTER RESOLUTION TO REACH FOR. Which tree will run the hook is not knowable from
    # the wrapper text, and a checker that picks one and answers `installed:true` is guessing and
    # calling it a verdict. So the ambiguity is refused instead of resolved -- fail-closed, and it
    # removes the whole class rather than one of its members. LAM-INSTALL 5.4 installs an ABSOLUTE
    # path and every in-tree caller passes one, so nothing supported is affected.
    #
    # `IsPathRooted` IS NOT THE TEST (a WP-4 finding): `C:e.txt` and `\dir\file.txt` are drive-relative and
    # it calls both rooted, which is exactly the ambiguity being refused.
    $pointsAt = $null
    $pm = [regex]::Match($actualText, '-File\s+"([^"]*)"')
    if ($pm.Success) { $pointsAt = $pm.Groups[1].Value }
    # AN EMPTY -File IS NOT "NO -File" (V-1 round 16, a WP-2 finding). `-File ""` extracts as an empty
    # string, and every guard below of the form `if ($pointsAt -and ...)` is false for it -- so an
    # empty decider path slipped past the qualification check and reached the contents comparison
    # with nothing to compare. It is a wrapper naming a decider it does not name.
    $deciderNamed = $pm.Success
    $actualDecider = $null
    $deciderMissing = $false
    if ($deciderNamed -and $pointsAt -and (Test-Path -LiteralPath $pointsAt)) {
        $actualDecider = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash([IO.File]::ReadAllBytes($pointsAt))).Replace('-','').ToLowerInvariant()
    } elseif ($deciderNamed) {
        # ABSENT IS NOT DIFFERENT, AND SAYING SO IS THE FIX. This used to leave $actualDecider null
        # and fall into the contents comparison, which rendered "whose contents do NOT match the
        # shipped decider (sha256 , expected abc...)" -- an EMPTY hash where a real one belongs,
        # telling the operator the file's contents are wrong when the file is not there. Two
        # different repairs, one sentence.
        $deciderMissing = $true
    }
    # ORDER MATTERS, AND THIS BRANCH USED TO COME FIRST (V-1 round 14, WP-2). A hook that is not our
    # wrapper at all has no -File to extract, so `$pointsAt` was empty and this branch fired with
    # "the pre-push hook IS our wrapper, but it points at ''" -- an empty path, an empty hash, and a
    # sentence that is false about the very hook it is refusing. A true refusal for a false reason
    # teaches an operator to fix the wrong thing, and it made the fingerprint branch unreachable for
    # exactly the shape R-25's own instrument drives.
    #
    # So the fingerprint question -- "is this our wrapper at all?" -- is answered FIRST, below, and
    # only a hook that IS our wrapper reaches the question of which decider it names.
    if ($actual -cne $expected) {
        return @{ installed = $false; path = $hookPath; sha256 = $actual; expected = $expected; hooks_dir = $hooksDir
                  reason = "the pre-push hook at $hookPath is not the shipped wrapper (fingerprint $actual, expected $expected). An edited hook is refused for the same reason an absent one is: neither can be trusted to carry the tripwire." }
    }
    # ONLY A HOOK THAT IS OUR WRAPPER REACHES ANY QUESTION ABOUT ITS DECIDER, and this check was
    # ABOVE the fingerprint compare for one round (V-1 round 16, a WP-2 finding, driven). A third-party
    # hook -- `exec powershell -File "hooks/mine.ps1"` -- was refused with "the pre-push hook at X
    # names ITS DECIDER with a path that is not fully qualified ... Install the decider with an
    # absolute path": a true refusal for a false reason, telling the operator to fix a file that is
    # not ours.
    #
    # That is verbatim the defect the reorder above was written to cure in round 14, reintroduced one
    # round later by the fix for a WP-2 finding -- and the sentence six lines up already said the fingerprint
    # question is answered FIRST. R-25's instrument misses it because its EDITED shape is a bare
    # `exit 0`, which carries no `-File` at all.
    if ($pointsAt -and -not (Test-EvidencePathIsFullyQualified -Path $pointsAt)) {
        return @{ installed = $false; path = $hookPath; sha256 = $actual; expected = $expected; hooks_dir = $hooksDir
                  decider_path = $pointsAt
                  reason = "the pre-push hook at $hookPath IS the shipped wrapper, but it names its decider with a path that is not fully qualified ('$pointsAt'). Git resolves a hook's relative path against the working tree the push is issued from -- and this build's runner creates worktrees -- so which script would actually run cannot be determined from the wrapper. Refusing rather than guessing which tree. Install the decider with an absolute path (LAM-INSTALL 5.4 does)." }
    }
    if ($deciderMissing) {
        return @{ installed = $false; path = $hookPath; sha256 = $actual; expected = $expected; hooks_dir = $hooksDir
                  decider_path = $pointsAt
                  reason = "the pre-push hook at $hookPath IS the shipped wrapper, but the decider it names is NOT ON DISK$(if ($pointsAt) { " ('$pointsAt')" } else { " -- its -File argument is empty" }). That is a different repair from a substituted decider and is reported as one: there is nothing to compare, so no hash is shown." }
    }
    if ($actualDecider -cne $expectedDecider) {
        return @{ installed = $false; path = $hookPath; sha256 = $actual; expected = $expected; hooks_dir = $hooksDir
                  decider_path = $pointsAt; decider_sha256 = $actualDecider; decider_expected = $expectedDecider
                  reason = "the pre-push hook IS our wrapper, but it points at '$pointsAt', whose contents do NOT match the shipped decider (sha256 $actualDecider, expected $expectedDecider). A wrapper is only as good as the script it runs, and substituting that script leaves the wrapper byte-identical." }
    }
    # A THIRD COMPARISON STOOD HERE AND COULD NEVER FIRE (V-1 round 15, a WP-2 finding). It re-asked the
    # fingerprint question with `-ne` after the `-cne` above had already returned, and case-sensitive
    # equality IMPLIES case-insensitive equality -- so reaching this line meant the comparison was
    # necessarily false. Its distinct refusal message was text no operator could ever be shown. My
    # leftover from the round-14 reorder: the check was moved up and its twin was not removed.
    # AND WOULD THIS ANSWER STILL HOLD IN THE TREE THE PUSH IS ACTUALLY ISSUED FROM?
    #
    # PLACED LAST ON PURPOSE. Round 14 and round 16 were each spent on the ORDER of the branches
    # above -- a true refusal delivered for a false reason teaches an operator to fix the wrong
    # thing -- so this asks a question about the REPOSITORY only once every question about the
    # HOOK has been answered. A repository with no wrapper still hears about its missing wrapper.
    $variance = Test-EvidenceHooksPathTreeVariance -Root $Root
    if (-not $variance.invariant) {
        return @{ installed = $false; path = $hookPath; sha256 = $actual; expected = $expected; hooks_dir = $hooksDir
                  hooks_path_config = $variance.hooks_path_config; worktree_config = $variance.worktree_config
                  reason = "the pre-push wrapper at $hookPath is correct, but WHICH hooks directory git uses is not the same in every worktree of this repository -- and the push will be issued from a worktree that does not exist yet. $($variance.reason)" }
    }
    return @{ installed = $true; path = $hookPath; sha256 = $actual; expected = $expected; hooks_dir = $hooksDir
              hooks_path_config = $variance.hooks_path_config; worktree_config = $variance.worktree_config
              reason = "pre-push decider installed at the effective hooks path and matching ($actual)" }
}

# T-3: agents cannot write under .mission/gates/**. A gate an agent could mint authorizes nothing.
# WIN32 STRIPS TRAILING DOTS AND SPACES FROM EVERY PATH COMPONENT (V-1 round 8, WP-4).
#
# `.mission/gates./push-forged.yaml` OPENS `.mission/gates/push-forged.yaml` on disk -- Win32
# discards a component's trailing dots and spaces when it resolves the path -- while a string
# comparison sees `gates.` and `gates` as different. Driven by an independent reader through the
# whole chain: the write was ALLOWED by file tool AND by shell, landed in the real gates directory,
# was read back by `mission-gate.ps1 list` as a valid open build-authorization gate, and `git push`
# then answered "push authorized" and really published.
#
# THAT VOIDS T-3's AGENT-UNMINTABILITY -- the compensating control that the zero-paste attestation
# and Ruling A2 both cite BY NAME -- and it is one character away from the case-sensitivity cure
# that exists to stop the identical chain. Nine sibling spellings (upper-case, dot-segment,
# parent-hop, \\?\, cwd-chain) all denied correctly, which is what localises it to this one.
#
# ENUMERATED, NOT PATCHED: the same normalisation applies to EVERY component, not just the one the
# reader happened to decorate. `.mission./gates/x.yaml` -- the dot on the FIRST component -- was
# found by enumerating the class and appears in no report.
#
# THE FORM IS ADDED, NEVER SUBSTITUTED. Every form the guard produced before is still produced, so
# this can only ADD denials; nothing that was allowed becomes denied by this change alone.
function ConvertTo-EvidenceWin32ComponentForm {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($part in ($Path -split '/')) {
        # `.` and `..` are DOT SEGMENTS, not decorated names. Stripping their trailing dots would
        # empty them and destroy the path, so they pass through untouched.
        if ($part -eq '.' -or $part -eq '..') { [void]$out.Add($part); continue }
        $t = $part
        while ($t.Length -gt 0 -and ($t.EndsWith('.') -or $t.EndsWith(' '))) { $t = $t.Substring(0, $t.Length - 1) }
        [void]$out.Add($t)
    }
    $joined = ($out -join '/')
    if ($joined -eq $Path) { return $null }          # nothing was decorated; add nothing
    if (-not $joined.Trim('/')) { return $null }     # never emit an empty or all-slash form
    return $joined
}

# WIN32 EXPOSES AN 8.3 SHORT-NAME ALIAS FOR EVERY NON-8.3 COMPONENT (V-1 round 9, WP-4).
#
# `.mission` is not an 8.3-legal name -- a leading dot alone disqualifies it -- so the volume also
# addresses it as `MISSIO~1`. An independent reader drove the whole chain: six short-name spellings
# were ALLOWED by BOTH routes, `cp seed.yaml MISSIO~2/gates/push-forged.yaml` landed a file in the
# REAL gates directory, and the real `mission-gate.ps1 list` then read it back as
# `push-forged  open  build-authorization`. AN AGENT MINTED ITS OWN OPEN BUILD-AUTHORIZATION GATE --
# precisely the act T-3 exists to forbid, and the compensating control that R-1, amendment 12 / the
# zero-paste attestation and amendment 15 each cite BY NAME.
#
# REACHABLE IN THE DEPLOYMENT, NOT ONLY IN A FIXTURE: a read-only metadata query reports
# `.mission` -> `MISSIO~1` in BOTH live planes, and the alias is discoverable with an ordinary
# `dir /x`. No guessing is required.
#
# THIS IS THE THIRD MEMBER OF ONE CLASS, and the class is worth more than the instance: the guard
# compares path STRINGS while the filesystem resolves SEVERAL spellings onto the same file.
#   round 3 -- case:            `.MISSION/GATES` opens `.mission/gates`
#   round 8 -- trailing dot:    `.mission/gates./x` opens `.mission/gates/x`
#   round 9 -- 8.3 alias:       `MISSIO~1/gates/x`  opens `.mission/gates/x`
# Each was cured on its own; none of the first two prompted the question "what ELSE resolves?".
#
# AND THIS MEMBER DIFFERS FROM ITS SIBLINGS IN A WAY THAT MUST BE STATED. Case and trailing dots
# are pure STRING transforms -- the guard can compute them from the text alone. An 8.3 alias is a
# FILESYSTEM FACT: nothing in `MISSIO~1` tells you what it stands for, and only the volume can say.
# So this form is available ONLY where the parent prefix exists and is rooted, and it is therefore
# strictly weaker than the other two. Where it cannot resolve, it adds nothing and denies nothing
# -- stated here so no later reader mistakes it for a total defence.
#
# THE FORM IS ADDED, NEVER SUBSTITUTED, exactly as the Win32 form above: every form the guard
# produced before is still produced, so this can only ADD denials.
# THE EXTENDED-LENGTH PREFIX HIDES EVERY OTHER NORMALISATION BEHIND IT (V-1 round 10, WP-4).
#
# `\\?\C:\<root>\MISSIO~1\gates\push-forged.yaml` was ALLOWED by both routes, LANDED in the real
# gates directory, was read back by the real `mission-gate.ps1 list` as
# `push-forged open build-authorization`, and then authorized a `git push` that really advanced the
# origin. The control one component away -- the same path with `.mission` spelled out, same run,
# same cwd -- DENIED, which is what proves the prefix alone is not the bypass: it is the 8.3 alias
# INSIDE it.
#
# WHY IT DEFEATS THE ALIAS CURE. A1's `ConvertTo-CanonicalPathText` collapses repeated slashes, so
# `\\?\C:/...` becomes `/?/C:/...`. `ConvertTo-EvidenceLongNameForm` can only invert an alias when
# the prefix built so far is rooted AND exists as a directory -- and `/?/C:` exists on no volume.
# The alias is therefore never inverted and `.mission/gates` never appears in any offered form.
#
# THE STRIP HAPPENS ON RAW TEXT, BEFORE CANONICALISATION, because canonicalisation is what destroys
# the prefix's shape. And it is done HERE rather than in the canonicaliser, which is A1's and
# SEALED -- redefining a primitive that A1's own matcher depends on to fix one caller's problem is
# a far wider change than this build should make.
function Remove-EvidenceExtendedLengthPrefix {
    param([AllowNull()][string]$Text)
    if (-not $Text) { return $null }
    # `\\?\UNC\server\share` names `\\server\share`; `\\?\C:\x` names `C:\x`. Both spellings of the
    # prefix are matched, and so is the already-canonicalised `/?/` shape, because this is offered
    # at more than one point in the pipeline and a form that only works on one of them is the
    # two-routes-one-cured defect this file has recorded five times.
    $t = $Text
    $t = [regex]::Replace($t, '(?i)(\\\\|//)\?(\\|/)UNC(\\|/)', '\\\\')
    $t = [regex]::Replace($t, '(?i)(\\\\|//)\?(\\|/)', '')
    $t = [regex]::Replace($t, '(?i)(^|[\s;|&,=<>()"''`])/\?/', '$1')
    if ($t -eq $Text) { return $null }     # nothing was prefixed; add nothing
    if (-not $t.Trim()) { return $null }
    return $t
}

function ConvertTo-EvidenceLongNameForm {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    # CHEAP GATE FIRST. An alias always carries `~<digit>` in the aliased component, so a path
    # without one cannot be a short form and costs no filesystem call at all. This keeps the
    # ordinary case -- every path that is not an alias -- string-only.
    if ($Path -notmatch '~[0-9]') { return $null }
    $parts = @($Path -split '/')
    $out = New-Object System.Collections.Generic.List[string]
    $changed = $false
    foreach ($p in $parts) {
        $long = $p
        $prefix = ($out -join '/')
        if ($p -match '~[0-9]' -and $prefix -and (Test-EvidenceRootedPath -Path $prefix)) {
            try {
                $di = New-Object System.IO.DirectoryInfo $prefix
                if ($di.Exists) {
                    # A LITERAL PATTERN, NOT A WILDCARD: `~` has no special meaning to the matcher,
                    # and Win32 matches a search pattern against BOTH the long and the short name --
                    # which is the whole mechanism this uses to invert the alias.
                    $hits = @($di.GetFileSystemInfos($p))
                    if ($hits.Count -eq 1 -and $hits[0].Name -ne $p) { $long = $hits[0].Name; $changed = $true }
                }
            } catch { }
        }
        [void]$out.Add($long)
    }
    if (-not $changed) { return $null }
    $joined = ($out -join '/')
    if ($joined -eq $Path) { return $null }
    return $joined
}

function Resolve-EvidenceGlobForms {
    <#
      A GLOB DENOTES A PATH WITHOUT SPELLING IT (operator ruling A, V-1 round 20).

      `New-Item -ItemType Junction -Path l -Target .mis*\evidence` was ALLOWED by the guard, the
      junction was created, and writes through it landed inside `.mission`. Both tiers were defeated
      by ONE input: the glob is what stops the protected path being detected, and the metacharacter
      tier fires only when one IS detected. The guard's own denial text says it refuses when it
      "cannot determine what ... globbing ... will actually do" -- globbing was the one case where it
      claimed something instead.

      SO THE GLOB IS EXPANDED AGAINST THE FILESYSTEM AND EVERY EXPANSION IS OFFERED AS A FORM. This
      is the 8.3-alias mechanism exactly: resolve against the volume, ADD the resolved spelling, never
      substitute. It adds denials only. A bare `*` is never refused on its own -- it expands to
      whatever is there, and if nothing there is protected, nothing is added.

      BOUNDED, and the bounds are stated: a relative glob resolves only against a KNOWN cwd, a rooted
      glob only when drive-qualified, and at most 64 expansions are offered. Where it cannot resolve
      it adds nothing -- strictly weaker than a string transform, which is the same honest note the
      alias form carries.
    #>
    param([AllowNull()][string]$Token, [AllowNull()][string]$CwdCanon)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Token -or $Token -notmatch '[*?]') { return $out.ToArray() }
    $probe = $Token
    if ($CwdCanon -and -not (Test-EvidenceRootedPath -Path $Token)) { $probe = "$CwdCanon/$Token" }
    if ($probe -notmatch '^[A-Za-z]:/') { return $out.ToArray() }
    $native = $probe -replace '/', '\'
    # THE LONGEST EXISTING PREFIX, WITH THE TAIL RE-APPENDED. The first version resolved the whole
    # token and so offered nothing for a NEW leaf under a glob-denoted directory -- which is exactly
    # the minting route: `cp x .mis*/dispatches/D-FORGED.superseded.yaml` was ALLOWED because the
    # marker did not exist yet. WP-2's R-12b caught it on its first run. So trailing components are
    # peeled off until something resolves, and each hit is offered with the peeled tail restored.
    $head = $native; $tail = ''; $hits = @()
    for ($i = 0; $i -lt 8; $i++) {
        try { $hits = @(Resolve-Path -Path $head -ErrorAction Stop | Select-Object -First 64) } catch { $hits = @() }
        if ($hits.Count -gt 0) { break }
        $cut = $head.LastIndexOf('\')
        if ($cut -lt 3) { break }
        $tail = $head.Substring($cut) + $tail
        $head = $head.Substring(0, $cut)
        # Once no glob remains in the head, the glob was in the tail and matched nothing: a NEW
        # name with a wildcard in it denotes no existing protected path, so there is nothing to add.
        if ($head -notmatch '[*?]') { $hits = @(); break }
    }
    foreach ($h in $hits) {
        $c = ConvertTo-CanonicalPathText -Text (([string]$h.Path) + $tail)
        if ($c) { [void]$out.Add($c) }
    }
    return $out.ToArray()
}

function Test-EvidenceLinkCreationCommand {
    <#
      DOES THIS COMMAND CREATE A FILESYSTEM LINK? mklink (any flag), New-Item with a link ItemType,
      or `ln -s`/`--symbolic`. Case-insensitive; a command that merely mentions the word inside a
      quoted string will also match, which errs toward asking rather than toward missing.
    #>
    param([AllowNull()][string]$Command)
    if (-not $Command) { return $false }
    return [bool]([regex]::IsMatch($Command,
        '(\bmklink\b)|(New-Item\b[^\r\n]*-ItemType\s+(Junction|SymbolicLink|HardLink)\b)|(\bln\s+(-[A-Za-z]*s[A-Za-z]*\b|--symbolic\b))',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}

# --- THE '..' FORM-BUILDER CURE (amendment 37) -----------------------------
#
# A LEADING `..` NAMED SOMEWHERE ELSE AND THE GUARD BUILT A FORM THAT SAID OTHERWISE.
#
# A1's `Resolve-DotSegments` pops `..` off a stack and, when the stack is EMPTY, DISCARDS it.
# That is correct for a rooted path -- `/..` is `/` -- and wrong for a relative one, where a
# leading `..` is the whole meaning of the token. `Get-EvidencePathForms` resolves the token
# BEFORE the cwd join, so from a worker worktree `<repo>/.claude/worktrees/wt-X`:
#
#     ../../settings.json  ->  settings.json  ->  <repo>/.claude/worktrees/wt-X/settings.json
#
# -- a form that is ALWAYS under the worktree root and NAMES THE WRONG FILE, while no form
# naming the real `<repo>/.claude/settings.json` was produced at all. Driven before this cure,
# from that cwd, through the real hook: `cat ../../settings.json` ALLOWED, and the form list for
# the token carried only `../../settings.json`, `settings.json` and the wrong join. Amendment 37
# registered the mechanism and recorded that it is PRE-EXISTING -- it is not what WP-1 reverted.
#
# THE CURE IS IN THE FORM BUILDER, not in a tier downstream of it: a token whose real target lies
# outside the cwd now PRODUCES a form that says so. A leading `..` that cannot be popped is KEPT.
#
# WHY REDEFINING THE SEALED NAME IS THE SEAM, AND WHAT IT REACHES. A1's own
# `Get-EvidencePathHits` calls `Resolve-DotSegments` BY NAME, so this redefinition reaches A1's
# decision path while the sealed library stays unmodified -- the seam amendment 37 documented for
# `Test-PathHit`. That is a FEATURE (A1's matcher is cured too) and a RISK (it can move verdicts
# nobody aimed at), so the direction is PROVED rather than asserted:
#
#   Run both algorithms in lockstep over the same token. On an ordinary segment both push. On
#   `..` with a non-empty legacy stack, the new stack's top is that same real segment and both
#   pop. On `..` with an EMPTY legacy stack, legacy discards and the new one pushes `..`. So at
#   every step  new = ('..' * k) + legacy  for some k >= 0, and the legacy output is always a
#   SUFFIX of the new one. `Test-PathHit` is a substring match with a RIGHT boundary and no left
#   anchor, so every pattern that matched the legacy form still matches the new form at the same
#   boundary. NO HIT CAN BE LOST. Where legacy resolved to the empty string (`..`, `../..`) it
#   produced no form at all and the new one produces a real token -- strictly more.
#
# ROOTED PATHS ARE UNTOUCHED. `/..` stays `/`, which is what the filesystem does, and every
# rooted form the guard produced before is byte-identical after.
#
# AND THE LEGACY FORM IS STILL OFFERED. The proof above covers the RESOLUTION; it does not cover
# the helpers `Get-EvidencePathForms` runs ON the resolution (the Win32 component form, the 8.3
# alias, and above all the glob expansion, which probes the FILESYSTEM and can resolve under one
# spelling and not the other). So the builder below runs its whole pipeline over BOTH resolutions.
# ADD, NEVER SUBSTITUTE -- the same rule this file already states for the Win32, alias and glob
# forms. Nothing the guard saw before this cure stops being offered.
function Resolve-DotSegmentsLegacy {
    <#
      A1's dot resolver, reproduced here so the delta can still offer the form A1 used to build
      without depending on the sealed name it redefines. Byte-for-byte the sealed algorithm
      (tools/framework/hooks/lib/evidence-common.ps1, `Resolve-DotSegments`): a `..` on an empty
      stack is discarded. Kept ONLY as an additive form source; nothing decides anything on it.
    #>
    param([AllowNull()][string]$Token)
    if (-not $Token) { return '' }
    $t = $Token.Replace('\', '/')
    $rooted = $t.StartsWith('/')
    $stack = New-Object System.Collections.Generic.List[string]
    foreach ($p in $t.Split('/')) {
        if ($p -eq '' -or $p -eq '.') { continue }
        if ($p -eq '..') { if ($stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }; continue }
        [void]$stack.Add($p)
    }
    $joined = ($stack -join '/')
    if ($rooted) { return "/$joined" }
    return $joined
}

function Resolve-DotSegments {
    <#
      THE CURED RESOLVER. Identical to A1's except in the one branch that was the defect: a `..`
      that cannot be popped is PRESERVED on a relative token instead of being discarded.

      The stack never holds a real segment ABOVE a `..`, so "the top is `..`" means "there is
      nothing left to pop" and another `..` is pushed. `../..` therefore survives as `../..`
      rather than collapsing to `..` or to nothing.
    #>
    param([AllowNull()][string]$Token)
    if (-not $Token) { return '' }
    $t = $Token.Replace('\', '/')
    $rooted = $t.StartsWith('/')
    $stack = New-Object System.Collections.Generic.List[string]
    foreach ($p in $t.Split('/')) {
        if ($p -eq '' -or $p -eq '.') { continue }
        if ($p -eq '..') {
            if ($stack.Count -gt 0 -and $stack[$stack.Count - 1] -ne '..') {
                $stack.RemoveAt($stack.Count - 1)
            } elseif (-not $rooted) {
                # NOTHING LEFT TO POP AND THE PATH IS RELATIVE: the `..` IS the meaning. Keeping
                # it is what lets the cwd join below name the real target.
                [void]$stack.Add('..')
            }
            continue
        }
        [void]$stack.Add($p)
    }
    $joined = ($stack -join '/')
    if ($rooted) { return "/$joined" }
    return $joined
}

function Get-EvidencePathForms {
    <#
      THE PATH-SHAPED FORMS OF A STRING: the canonicalised whole text, plus every whitespace- or
      operator-separated TOKEN with its dot segments resolved.

      WHY THIS EXISTS, and it is a defect repaired rather than a convenience. The two predicates
      below used to run a `(^|/)`-anchored regex over the WHOLE COMMAND STRING. A path preceded by a
      SPACE has neither start-of-string nor a `/` before it, so

          cp seed.yaml .mission/gates/push-forged.yaml

      matched NOTHING and the guard returned ALLOW. An independent validator drove the whole chain
      from there: write a gate face, copy it in, `mission-gate.ps1 list` reads it back as a valid
      open build-authorization gate, and `git push` then answers "push authorized". AN AGENT MINTED
      ITS OWN AUTHORIZATION AND PUBLISHED ON IT -- the exact act T-3 exists to forbid, and the
      compensating control that BOTH the zero-paste attestation and Ruling A2 cite by name.

      A `(^|/)` anchor is correct WITHIN A TOKEN and wrong across a command. A1's own protected-path
      matcher never had this bug because it tokenises first (Get-EvidencePathHits) -- which is why
      `.mission/evidence` in a command has always denied correctly. These predicates bypassed that
      machinery and reinvented the matching. The cure is to stop reinventing it.

      DISCLOSED DUPLICATION, REGISTERED RATHER THAN HIDDEN: the token split and dot resolution below
      mirror the form construction inside A1's `Get-EvidencePathHits`, because A1 does not export a
      token function and its bytes are sealed against this build. That is one predicate living in
      two places, which is the law this build keeps restating -- so it is named here, and the fix
      (export the form builder from A1 so both callers share it) belongs to whoever next opens the
      sealed set.
    #>
    param([AllowNull()][string]$Text, [AllowNull()][string]$Cwd = $script:EvidenceCwd)
    $forms = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $forms.ToArray() }
    $canon = ConvertTo-CanonicalPathText -Text $Text
    [void]$forms.Add($canon)
    $cwdCanon = if ($Cwd) { (ConvertTo-CanonicalPathText -Text $Cwd).TrimEnd('/') } else { '' }
    foreach ($tok in ($canon -split '[\s;|&,=<>()"''`]+')) {
        if (-not $tok) { continue }
        # THE TOKEN RESOLVES TWO WAYS AND BOTH ARE OFFERED (amendment 37). The
        # cured resolver KEEPS a leading `..`, so the cwd join below names the real target; the
        # legacy resolver reproduces what A1 built, so no form this guard produced before stops
        # being produced. Deduped, so a token with no `..` costs exactly one pass as it always did.
        # AN EMPTY RESOLUTION IS A RESOLUTION AND IS CARRIED, NOT FILTERED OUT. This is the first
        # thing this cure got wrong and its own member caught: the legacy rule resolves `..` and
        # `../..` to the EMPTY STRING, and the empty string joined to the cwd names THE CWD ITSELF
        # -- a form the guard really did produce for those tokens. Dropping the empty candidate
        # because it is falsy REMOVED that form, which is a deny-to-allow direction wherever the
        # cwd is itself protected territory. So the two candidates are deduped as STRINGS, empty
        # included, and the `if ($r)` below is what declines to add an empty form.
        $resolutions = New-Object System.Collections.Generic.List[string]
        foreach ($cand in @((Resolve-DotSegments -Token $tok), (Resolve-DotSegmentsLegacy -Token $tok))) {
            $candText = if ($null -eq $cand) { '' } else { [string]$cand }
            if (-not $resolutions.Contains($candText)) { [void]$resolutions.Add($candText) }
        }
        foreach ($r in $resolutions) {
        if ($r) {
            [void]$forms.Add($r)
            # THE SHAPE THE FILESYSTEM WILL ACTUALLY OPEN, offered alongside the literal token.
            $w32 = ConvertTo-EvidenceWin32ComponentForm -Path $r
            if ($w32) { [void]$forms.Add($w32) }
            # AND THE 8.3 ALIAS RESOLVED (V-1 round 9, WP-4), by the same add-never-substitute rule.
            $lng = ConvertTo-EvidenceLongNameForm -Path $r
            if ($lng) { [void]$forms.Add($lng) }
            # AND EVERY GLOB EXPANSION (operator ruling A), by the same rule again. This is
            # the form that turns `.mis*/evidence` into `.mission/evidence` for BOTH routes, because
            # both build their candidates here.
            foreach ($g in @(Resolve-EvidenceGlobForms -Token $r -CwdCanon $cwdCanon)) { [void]$forms.Add($g) }
        }
        # A RELATIVE PATH MEANS SOMETHING ONLY RELATIVE TO SOMEWHERE (V-1 round 5, WP-4 residual).
        #
        # The guard read the COMMAND TEXT and nothing else, so it never knew where the process was
        # standing. Driven by an independent reader: `cd .mission`, then `cd gates`, then
        # `echo x > y.yaml` -- three calls, ALLOWED at every step, no protected path in any single
        # command, and no denial recorded. The Bash tool's working directory persists between calls,
        # so the sequence lands a file in the gates directory that T-3 exists to make unreachable.
        # That qualifies the agent-unmintability claim which the zero-paste attestation and Ruling
        # A2 both cite BY NAME as their compensating control.
        #
        # So each relative token is ALSO offered in its cwd-joined form. This can only ADD denials:
        # every form the guard saw before is still produced, and the extra one is what the command
        # actually names. It is still a tripwire, not a boundary; a shell can still
        # compute a path the guard cannot see, and this closes the spelling that needed no
        # computation at all.
        if ($cwdCanon -and -not (Test-EvidenceRootedPath -Path $r)) {
            # RESOLVED AFTER THE JOIN, NOT BEFORE IT. This is the line the cure exists for: with a
            # leading `..` preserved in $r, `<cwd>/../../settings.json` pops REAL segments off the
            # cwd and lands on the file the token actually names.
            $joined = Resolve-DotSegments -Token "$cwdCanon/$r"
            if ($joined) {
                [void]$forms.Add($joined)
                $jw32 = ConvertTo-EvidenceWin32ComponentForm -Path $joined
                if ($jw32) { [void]$forms.Add($jw32) }
                # THE CWD-JOINED FORM IS WHERE THE ALIAS USUALLY RESOLVES, because a bare
                # `MISSIO~2/gates/x.yaml` has no rooted prefix of its own to enumerate. Joining it to
                # the cwd first is what makes the expansion possible at all for a relative spelling.
                $jlng = ConvertTo-EvidenceLongNameForm -Path $joined
                if ($jlng) { [void]$forms.Add($jlng) }
            }
        }
        }
    }
    return $forms.ToArray()
}

function Test-EvidenceGatePath {
    <#
      Delegates to A1's own protected-path matcher, which tokenises and resolves dot segments before
      testing -- so a relative destination inside a command is caught exactly as an absolute one is.
      Zero bespoke matching here: the previous bespoke regex is what let a plain `cp` through.
    #>
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    return (@(Get-EvidencePathHits -Text $Path -Patterns @('.mission/gates')).Count -gt 0)
}

# =================================================================================================
# T-3 IS ABOUT AN ACT, AND THE RULE WAS ABOUT A SPELLING.
# =================================================================================================
# WHAT THE ROW RECORDS, and what was DRIVEN rather than reasoned:
#
#   `Test-EvidenceGatePath` directly above matches the literal text `.mission/gates`. The ratified
#   mint convention -- the one the docs themselves publish, LAM-ACCEPT.md:526 and :895 -- is
#
#       powershell -File tools/lam/mission-gate.ps1 approve -Kind push -MissionRoot .
#
#   and that command contains the string `.mission/gates` NOWHERE. mission-gate.ps1 computes its
#   gates directory from `-MissionRoot` INSIDE THE CHILD PROCESS (mission-gate.ps1:96-101), so the
#   guard-visible command line never names the territory the rule protects.
#
#   MEASURED, both tool names, before this function existed: the payload
#   {tool_name: Bash|PowerShell, tool_input.command: <the line above>} returned exit 0 and
#   permissionDecision "allow" -- and so did the full realistic self-mint with -Id/-Binds/-TipSha/
#   -OriginUrl/-RemoteRef, and so did `revoke`, and so did a verb spelled through a shell variable.
#   The tool was then run against a SCRATCH mission root and really wrote
#   a push gate carrying `single_use: true`, `consumed_at: null`, a declared
#   origin_url and a declared remote_ref -- the exact shape `Get-EvidencePushGateVerdict` consumes
#   -- and the real `mission-gate.ps1 list` read it back as `open build-authorization`.
#
# THE OTHER HALF OF THE ROW, ALSO CONFIRMED: the `Write(.mission/gates/**)` deny is a FILE-TOOL
# rule, and a child process does not pass through it. Shell tools are excluded from the
# candidate-path branch of Get-EvidenceGuardDecision by construction, which is correct -- a file
# tool cannot spawn a process, and denying a READ of a gate is not what T-3 says.
#
# THIS IS A HOLE, NOT DEFENCE IN DEPTH, AND THE DIFFERENCE IS THE WHOLE POINT.
# mission-gate.ps1:12 states that agents cannot mint "and the guard enforces that from the other
# side". Read against the tool: there is NO TTY test, no [Environment]::UserInteractive test, no
# environment check, no LAM_DISPATCH check and no confirmation prompt anywhere in its 501 lines.
# `$env:USERNAME` is written onto the artifact at :462 and printed at :497 as a RECORD of who ran
# it; it is never compared against anything. So the tool points at the guard, the guard matched a
# string the tool never emits, and NEITHER LAYER HELD. Until this predicate, T-3 -- the law that
# R-1, amendment 12, amendment 15, Ruling A2 and the WP-6 zero-paste attestation each cite BY NAME
# as their compensating control -- was enforced by nothing at all for the published convention.
# THIS PREDICATE IS THEREFORE THE LOAD-BEARING CONTROL, not a second one. No reader should file it
# alongside the path rules as one more layer: it is the only layer the mint convention meets.
#
# ALLOWLIST, NEVER BLACKLIST. `list` is the only read-only verb mission-gate.ps1 has. Everything
# else -- `approve`, `revoke`, any verb a later ValidateSet grows, a verb that is absent, and a verb
# the guard cannot read -- mutates the operator's authorization set and is refused FOR EVERY ROLE.
# A blacklist of {approve, revoke} would be the same defect one verb over, and the ValidateSet at
# mission-gate.ps1:34 is exactly the kind of list that grows.
#
# THE NARROWING, AND WHY IT IS NOT A WEAKENING. The naive form of this predicate -- "the text names
# mission-gate.ps1" -- also refuses `cat tools/lam/mission-gate.ps1`, `grep approve
# tools/lam/mission-gate.ps1` and `Select-String -Path tools/lam/mission-gate.ps1`. That cost is
# too high: T-3 makes a gate unwritable, NOT unreadable, and the same sentence has to hold for the
# tool that writes one -- reading a tool is how anyone learns what it does, including this comment's
# reader. So the token must stand in EXECUTABLE POSITION: first token of its segment, or the token
# after -File / -Command / -c / /c, or after a shell name (powershell, pwsh, sh, bash) or the
# dot-source operator. Both shapes are DRIVEN by instrument-WP-1 H-7 in the same table, because a
# narrowing that is only argued is a narrowing nobody measured.
#
# AND THE UNREADABLE BRANCH REFUSES. A segment naming the tool in executable position while the
# command carries an expansion this guard cannot decode -- $( ), ${ }, a backtick, $'...' or a bare
# $VAR -- is treated as a MUTATION. Same direction as Get-EvidenceGitRefusalClass above: a guard
# that allows when it cannot see is not a guard. The expansion test reads the RAW command rather
# than the quote-stripped scan variants, for the reason that function already records -- the
# variants destroy the very characters being looked for.
#
# THE HONEST BOUND, CARRIED RATHER THAN ARGUED AWAY (design SS4.5 law 4). This is a
# TRIPWIRE ON THE RATIFIED SPELLING, not a boundary. A shell can still compute an invocation whose
# text never names the tool -- `& $gateTool approve` is one line of PowerShell -- and no amount of
# reading the command TEXT can recover that, exactly as the alias case settles the same question
# for the push classifier. What the unreadable branch buys is that the guard does not ALLOW the
# shapes it cannot read; what it does not buy is a boundary. The durable fix lives on the other
# side, in an operator/TTY assertion INSIDE mission-gate.ps1, which has none today and which this
# build's declared file set does not permit it to add. This predicate does not pretend to
# substitute for one, and the register should keep that residual open.
#
# DIRECTION CHECK, in this file's own idiom: unchanged for every command that does not name
# mission-gate.ps1 in executable position; unchanged for every file tool and every read-only tool;
# unchanged for `list`. It can only ADD denials (b1s5 item 3's shell-decided guard included). AMENDED
# BY THE AMENDMENT BELOW, the ONE clause here that REMOVES a denial; its bound is stated there.
#
# THE COST, CENSUSED RATHER THAN ESTIMATED. A 32-command census was driven through the real hook at
# the tip of this edit. THREE shapes refuse that did not before, and they are all of them:
#
#   powershell -File tools/lam/mission-gate.ps1                 named with NO verb
#   powershell -File tools/lam/mission-gate.ps1 -?              asking for help -- NO LONGER REFUSED; see the amendment below
#   powershell -File tools/lam/mission-gate.ps1 list -MissionRoot $root
#                                                               a READ whose argument is a variable
#
# AS MEASURED AT THAT CENSUS the first two were the "absent verb" rule doing exactly what it was
# written to do, and `Get-Help tools/lam/mission-gate.ps1` was offered as answering the same
# question. The amendment below records that it does NOT, and lifts the second row. The third is the
# unreadable branch refusing a command that is in fact harmless, which is the price of not
# deciding what a variable expands to -- one re-issued command with the root spelled out; it is
# UNCHANGED, and `mission-gate.ps1 -? $root` is still refused by it.
#
# EVERYTHING ELSE IN THE CENSUS STILL ALLOWS, and these are the rows that matter most: `cat`,
# `head`, `sed`, `Get-Content`, `Get-Content -Path`, `grep`, `Select-String -Path`, `Get-Help`,
# `Get-FileHash`, `wc`, `ls`, `git add`, `git diff`, `git log` and `cp` over the tool's own file;
# `list` in every spelling tried, including `-M .` abbreviated, `-Kind push` before the verb, a
# bare `-Verbose`, `./tools/lam/mission-gate.ps1 list`, the backslash spelling, and
# `powershell -Command`; and running instrument-WP-3, WP-4 and WP-6, each of which MINTS a real
# gate inside its own child process where the guard cannot and should not see it.
#
# ---------------------------------------------------------------------------------------------
# AMENDMENT: `-?` AND `-Help` ARE ADMITTED AS READ-ONLY.
# ---------------------------------------------------------------------------------------------
# The finding: "`tools/lam/mission-gate.ps1 -?` IS REFUSED INSIDE A SESSION: T-3 rule (c) allowlists
# the single verb `list`, and `-?` is neither `list` nor a verb the guard can read, so it is
# refused with the mutating ones. The per-verb help surface amendment 33 BUILT -- and
# which WP-4 T-24 asserts against real output -- cannot be reached by the seat it was written for.
# FAIL-CLOSED AND THEREFORE CORRECT IN DIRECTION; the cost is that a cure shipped for operators is
# invisible to every in-session reader."
#
# The census paragraph above offered `Get-Help tools/lam/mission-gate.ps1` as answering the same
# question. IT DOES NOT: Get-Help prints the comment-based help block, while amendment 33's cure is a
# per-verb surface the tool prints for ITSELF -- which is exactly the text WP-4 T-24 measures. So
# the only way to see the shipped cure from a session was a shape the guard refused.
#
# THE ADMITTED LIST IS CLOSED, LITERAL AND EXACT-MATCHED: $script:EvidenceGateToolHelpFlags below.
# It is NOT prefix-matched, and that is a decision, not an oversight. `-H` and `-He` are NOT
# admitted and STILL REFUSE. A prefix rule here would be the only place in this predicate where an
# abbreviated token could REMOVE a denial, and it would sit next to
# $script:EvidenceGateToolValueParams, which IS prefix-matched -- one list growing a member could
# then silently change what the other one means. Exact match keeps the two lists independent.
#
# AND NEITHER LIST CAN EAT THE OTHER'S TOKEN, which is the collision worth stating:
#   - a value-taking parameter CONSUMES the token after it, so in `mission-gate.ps1 -MissionRoot -?`
#     the `-?` is that parameter's value, is never examined as a flag, and the command still
#     REFUSES. That is the fail-closed answer for a shape where the help flag is somebody's
#     argument, and it is driven as a case;
#   - the help test runs BEFORE the value-param prefix scan, so an admitted help flag can never be
#     mistaken for an abbreviation of a value-taking parameter and have the next token eaten.
#
# DIRECTION WARNING -- THIS CLAUSE IS THE OPPOSITE OF EVERY OTHER RULE IN THIS PREDICATE. It can
# only REMOVE denials, which is the fail-OPEN direction. It is bounded to fire ONLY when, in the
# same segment and after the tool token, ALL THREE of these hold:
#   (1) ZERO positional tokens were collected -- so there is no verb at all, and therefore no
#       `approve`, no `revoke` and no future ValidateSet member present to act on;
#   (2) at least one token is an EXACT member of the closed help list; and
#   (3) the unreadable-command test has already been passed -- it runs FIRST and is untouched, so
#       `mission-gate.ps1 -? $root` is still refused as unreadable.
# CONDITION (1) IS WHAT DOES THE WORK: mission-gate.ps1 mutates nothing without a verb, and a verb
# is exactly what a positional token is. `approve -?`, `-? revoke`, `list approve` and
# `-Unknown approve -?` each collect a positional and are refused by the unchanged rules below,
# and the BARE no-verb shape -- no positional AND no help flag -- refuses unchanged as well.
#
# WHAT IT COSTS, SAID PLAINLY RATHER THAN ARGUED AWAY (design SS4.5 law 4). If mission-gate.ps1
# ever grows a MUTATING action that needs no positional verb -- a bare switch such as a
# hypothetical `-RevokeAll` -- then a command carrying that switch together with a help flag would
# be admitted by this clause. That residual is real and the register should keep it open. What
# bounds it today is that the tool's entire mutating surface is a ValidateSet of POSITIONAL verbs
# (mission-gate.ps1:34), and the same honest bound this block already carries: a tripwire on a
# ratified spelling is not a boundary.
# ---------------------------------------------------------------------------------------------

# THE PARAMETERS OF mission-gate.ps1 THAT TAKE A SEPARATED VALUE, so the verb scan does not mistake
# a switch's value for the verb. Matched by PREFIX, because PowerShell itself accepts `-M .` for
# `-MissionRoot .` and a rule that did not would refuse an ordinary `list`. An UNRECOGNISED switch
# is skipped alone and its next token is still allowed to decide, as Get-EvidenceCommandGitScan does
# for unknown git options. `reason` added b1s5 item 3 (amendment 37 note 3); the shell-decided guard below bounds it.
$script:EvidenceGateToolValueParams = @('command', 'kind', 'id', 'binds', 'missionroot',
    'tipsha', 'originurl', 'remoteref', 'expiresminutes', 'reason')

# WHAT PUTS A TOKEN IN EXECUTABLE POSITION when it is not the first of its segment. Both spellings
# of each lead are listed: the raw flag as written, and the leaf of a path, because an interpreter
# may be named as `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
$script:EvidenceGateToolExecLeads = @('-file', '-command', '-c', '/c', '/k', 'powershell',
    'powershell.exe', 'pwsh', 'pwsh.exe', 'sh', 'bash', 'cmd', 'cmd.exe', '.')

# THE ONLY READ-ONLY VERB. Kept as a list of one so that adding a second is a reviewable edit
# rather than a regex nobody re-reads.
$script:EvidenceGateToolReadVerbs = @('list')

# THE HELP FLAGS ADMITTED AS READ-ONLY. LITERAL, CLOSED and EXACT-matched --
# never a prefix and never a regex -- for the reason the amendment block above gives in full: this
# is the ONE clause in this predicate that can REMOVE a denial, so the set of tokens able to
# trigger it has to be readable at a glance and must not grow by abbreviation. `-H` and `-He` are
# therefore NOT members and still refuse. Adding a member here WIDENS A FAIL-OPEN CLAUSE and is a
# reviewable edit that should be treated as one.
$script:EvidenceGateToolHelpFlags = @('?', 'help')

function Test-EvidenceGateToolMutation {
    <#
      DOES THIS COMMAND INVOKE mission-gate.ps1 WITH A GATE-MUTATING VERB?

      Answered on the ACT (tool + verb), never on the territory the act happens to name -- see the
      block above for what was driven and what it costs. Allowlists the one read-only verb; an
      absent verb, an unreadable verb, an ambiguous verb and any future verb all refuse.

      Segmented and tokenised with the SAME primitives the push classifier uses, deliberately:
      Remove-EvidenceHeredocBodies, the one quote-set, Split-CommandSegments, and the single-&
      and parenthesis splits. A second segmenter for the same job is how two copies of one
      predicate drift apart, which this file has already recorded happening twice.
    #>
    param([AllowNull()][string]$Command)
    if (-not $Command) { return $false }
    $scanText = Remove-EvidenceHeredocBodies -Text $Command
    foreach ($variant in @(($scanText -replace $script:EvidenceQuoteChars, ' '),
                           ($scanText -replace $script:EvidenceQuoteChars, ''))) {
        $segsAll = @()
        foreach ($outer in @(Split-CommandSegments -Command $variant)) {
            foreach ($mid in ($outer -split '&')) {
                foreach ($inner in ($mid -split '[()]+')) {
                    if ($inner.Trim()) { $segsAll += $inner }
                }
            }
        }
        foreach ($seg in $segsAll) {
            $tokens = @(($seg -split '\s+') | Where-Object { $_ })
            for ($i = 0; $i -lt $tokens.Count; $i++) {
                $tok = $tokens[$i]
                # A TOKEN CARRYING `=` IS AN OPTION'S ATTACHED VALUE, never an executable. Without
                # this, `git -c hooks.path=tools/lam/mission-gate.ps1 status` would be read as an
                # invocation of the tool, which is a false refusal with no act behind it.
                if ($tok.Contains('=')) { continue }
                $leaf = (($tok.Replace('\', '/')) -split '/')[-1]
                if ($leaf -inotmatch '^mission-gate(\.ps1)?$') { continue }
                # EXECUTABLE POSITION, or this is a READ of the tool and T-3 does not speak to it.
                $execPos = ($i -eq 0)
                if (-not $execPos) {
                    $prevRaw  = $tokens[$i - 1].ToLowerInvariant()
                    $prevLeaf = ((($tokens[$i - 1].Replace('\', '/')) -split '/')[-1]).ToLowerInvariant()
                    $execPos  = ($script:EvidenceGateToolExecLeads -contains $prevRaw) -or
                                ($script:EvidenceGateToolExecLeads -contains $prevLeaf)
                }
                if (-not $execPos) { continue }
                # AN INVOCATION THE GUARD CANNOT READ IS A MUTATION BY DEFAULT. Tested on the RAW
                # command: the quote-stripped variants above have already destroyed the backtick.
                if ($Command -match '\$\(|\$\{|`|\$''|\$[A-Za-z_]') { return $true }
                if (Test-EvidenceGateToolValueParamShellDecided -Command $Command) { return $true }  # b1s5 item 3: a value the shell sizes; helper after Test-EvidenceWorkerPlanePath
                # THE VERB IS EVERY POSITIONAL TOKEN AFTER THE TOOL, COLLECTED RATHER THAN TAKEN
                # FIRST. Taking the first would let `-Unknown approve list` read as `list`; requiring
                # EXACTLY ONE positional and requiring it to be the read-only verb refuses the
                # ambiguous shape instead of guessing at it.
                $positional = New-Object System.Collections.Generic.List[string]
                $sawHelpFlag = $false
                for ($j = $i + 1; $j -lt $tokens.Count; $j++) {
                    $n = $tokens[$j]
                    if ($n.StartsWith('-') -or $n.StartsWith('/')) {
                        $name = ($n -replace '^[-/]+', '')
                        $sep = $name.IndexOfAny(@([char]58, [char]61)); if ($sep -ge 0) { $atName = $name.Substring(0, $sep).ToLowerInvariant(); $atValue = $name.Substring($sep + 1); if ($atName -and $atValue -and $script:EvidenceGateToolReadVerbs -notcontains $atValue.ToLowerInvariant()) { foreach ($p in $script:EvidenceGateToolValueParams) { if ($p.StartsWith($atName)) { if ($p -eq 'command') { [void]$positional.Add($atValue) }; break } } }; continue }   # an ATTACHED token, split at its FIRST ':'/'=' as the helper below does, is ONE token; a non-list attached -Command value IS the verb (deny-side only)
                        if ($name) {
                            $nl = $name.ToLowerInvariant()
                            # HELP IS TESTED BEFORE THE VALUE-PARAM PREFIX SCAN, so an
                            # admitted help flag can never be read as an abbreviation of a
                            # value-taking parameter and eat the token after it. EXACT match,
                            # never a prefix: `-H` and `-He` fall through and still refuse.
                            if ($script:EvidenceGateToolHelpFlags -contains $nl) {
                                $sawHelpFlag = $true
                                continue
                            }
                            foreach ($p in $script:EvidenceGateToolValueParams) {
                                # `-Command <verb>`: a non-`list` value IS the verb, collected so a mint is not hidden (b1s5 item 3 fork; helper below).
                                if ($p.StartsWith($nl)) { if ($p -eq 'command' -and ($j + 1) -lt $tokens.Count -and $script:EvidenceGateToolReadVerbs -notcontains $tokens[$j + 1].ToLowerInvariant()) { [void]$positional.Add($tokens[$j + 1]) }; $j++; break }
                            }
                        }
                        continue
                    }
                    [void]$positional.Add($n)
                }
                # READ-ONLY HELP: NO verb at all AND an admitted help flag. This is the
                # only clause here that REMOVES a denial -- its full bound is in the amendment
                # block above. A value-taking parameter has already consumed the token after it,
                # so `-MissionRoot -?` never sets this flag and still refuses. `continue` and not
                # `return $false`, so a LATER segment naming the tool with a real verb still
                # refuses on its own.
                if ($positional.Count -eq 0 -and $sawHelpFlag) { continue }
                if ($positional.Count -ne 1) { return $true }   # no verb, or more than one
                if (-not ($script:EvidenceGateToolReadVerbs -contains $positional[0].ToLowerInvariant())) {
                    return $true
                }
            }
        }
    }
    return $false
}

function Test-EvidenceSupersessionMarkerPath {
    <#
      LAM-ACCEPT R-1. A `*.superseded.yaml` marker retires a prior dispatch, and an
      agent placed one here with a plain `cp` before anything stopped it. The pattern is therefore
      protected territory for agent WRITES.

      SCOPED TO THE MARKER SUFFIX, NOT TO THE DIRECTORY, and the narrowness is required rather than
      cautious: `.mission/dispatches/` also holds `<id>.handoff.yaml`, which is the worker's ENTIRE
      output obligation and which K-3 names as one of exactly two closed exceptions. A rule written
      against the directory would deny the handoff and no dispatch could ever complete.

      THIS IS DEFENCE IN DEPTH, NOT THE LOAD-BEARING CONTROL, and saying so matters. Under Ruling
      A2-revised a marker is honoured only against an unrevoked `supersession` GATE binding its
      re-derived sha256, and gates are agent-unmintable (T-3). So a marker an agent wrote already
      achieves nothing. This deny stops the artifact from being created at all, which is cheaper to
      reason about than an artifact that exists and is inert -- but nobody should read it as the
      thing that makes supersession safe. It is still a tripwire, not a boundary.
    #>
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    # TOKENISE FIRST, THEN ANCHOR WITHIN THE TOKEN. The previous form ran the anchored regex over
    # the whole command string and dropped `$` to compensate; that was treating the symptom. A
    # relative destination still slipped past, because `(^|/)` cannot match after a space -- and my
    # own R-12 member passed anyway, because its fixture used an ABSOLUTE path. I tested the one
    # shape that happened to work and generalised from it, which is a recorded fixture lesson committed
    # by the author who recorded it. Anchored at BOTH ends now, per token, so a marker is recognised and a
    # sibling handoff in the same directory is not.
    foreach ($f in @(Get-EvidencePathForms -Text $Path)) {
        # THE SAME SCOPE THE RUNNER SCANS, and they drifted because each was written separately
        # (found by driving, round 7 wait). R-22 made the runner's scan RECURSIVE over `.mission`
        # and `.mission-runtime`; this rule stayed on `.mission/dispatches/` alone, so FOUR
        # locations the runner honours as a refusal were agent-writable -- and `.mission-runtime/`
        # was reachable even by a dispatched worker, whose plane rule covers `.mission/` only.
        #
        # No privilege is gained: a planted marker cannot ratify itself. But it halts every
        # subsequent dispatch, and R-1's whole point is that markers are OPERATOR-placed. This rule
        # exists because an agent placed one with a plain `cp`.
        #
        # Widening can only ADD denials. The operator hand-places markers outside the session, where
        # the guard does not apply, and the runner never writes one.
        if ($f -match '(^|/)\.mission(-runtime)?/.*\.superseded\.yaml$') { return $true }
    }
    return $false
}

# =================================================================================================
# THE PARTY ASKED TO VERIFY A BINDING
# WAS THE ONE FORBIDDEN TO COMPUTE IT.
# =================================================================================================
# WHAT THE ROW RECORDS. A validator is asked to confirm that a gate binds the sha256 of a dispatch
# face or a contract artifact. Under K-3's shell reach, a dispatched worker naming ANY `.mission/`
# path in ANY command is refused -- so the validator could not compute the figure it was asked to
# check. A-579 round 2's disclosure is the record: the validator said plainly that the figures
# were carried UNVERIFIED, and it STOPPED when its scoped `git archive` workaround was denied too,
# rather than route around the guard. The refusal was correct under the rule as written and the
# rule was wrong: K-3's own text scopes the worker restriction to a WRITE, and the code applied it
# to any MENTION of the path.
#
# THERE ARE THREE LINES HERE, NOT ONE, and the register says so in as many words. Whoever reads
# this later should not repeat the mistake of curing one and believing the class closed:
#
#   LINE 1  THE WORKER-PLANE RULE (Test-EvidenceWorkerPlanePath, immediately below, reached from
#           this file's file route and shell route and from the SEALED A1 copies at
#           framework:1660 and :1716). Scoped to a dispatched worker by LAM_DISPATCH, and scoped
#           to `.mission/`. THIS IS THE ONLY LINE THIS CURE TOUCHES.
#   LINE 2  A1'S PROTECTED TIER (framework:1057-1064, enforced at :1758 and by the file route).
#           `.mission/evidence` and `.mission-runtime/evidence` are refused to EVERY identity by
#           BOTH routes, with or without a metacharacter. Measured at this close: a `sha256sum` of
#           `.mission/evidence/...` is refused for the ORCHESTRATOR SEAT, which is not a worker at
#           all. Untouched here, and the predicate below cannot reach that plane.
#   LINE 3  THE METACHARACTER TIER (framework:1122 / :1702). Any metacharacter plus any protected
#           OR PARENT path -- and `.mission` is a parent -- refuses for every identity. Measured at
#           this close on a `.mission/dispatches` path with a redirect, from the seat. Untouched,
#           and clause C1 below makes the new exception structurally unable to coexist with it.
#
# THE NARROWING THE OPERATOR ORDERED: "narrow the rule so a READ-ONLY hash of files under
# .mission/dispatches and .mission/contract is permitted to workers and validators while every
# write, move and delete stays refused."
#
# WHY THIS IS NOT THE MISTAKE AN EARLIER ERRATUM MADE, stated head-on because that erratum DELETED a
# read-only verb list and this brings a verb set back. The deleted list asserted "this verb cannot
# modify the filesystem" -- a claim over every flag of every tool on the host. That surface is not
# enumerable, which is why the list was audited clean twice and was wrong twice (`sort -o`,
# `file -C -m`, `git blame --output=`). THIS PREDICATE ASSERTS SOMETHING CHECKABLE INSTEAD: that
# THIS EXACT COMMAND is one segment, carries no metacharacter and no newline, begins with a verb
# from a closed set, carries only dash-flags from a closed per-verb set that contains no
# output-taking flag, carries no token with an equals sign, and names at least one mission-plane
# path -- every one of which resolves, in EVERY form the form builder can produce, inside
# `.mission/dispatches/` or `.mission/contract/`. The blast radius is bounded by the PATH clause
# INDEPENDENTLY OF THE VERB: a verb I have mis-classified still cannot name a target outside those
# two directories, cannot reach the evidence plane, the gates, the markers, the runtime plane,
# tools/framework or .claude, because a command carrying any such token fails the path clause and
# the deny fires unchanged. The deleted list had no such bound; a mis-classified verb there
# reached the whole protected tier.
#
# DIRECTION. The predicate is consulted in ONE place -- the first clause of the function below --
# and it can only ever SUPPRESS A DENY. It never produces an allow: lines 2 and 3, the gate rule,
# the marker rules and A1's segment classifier all run afterwards regardless. False is the default
# and every unrecognised input returns false: an unknown verb, an unknown flag, a token carrying
# an equals sign, a path outside the two roots, a path that resolves differently than it reads, an
# unresolvable token, an empty text, or any thrown exception.
#
# THE VERB SET, EACH INCLUSION ARGUED -- and the exclusions matter more than the inclusions:
#   sha256sum / sha512sum / sha384sum / sha224sum / sha1sum / md5sum -- the coreutils hash family.
#       One binary shape, no output option in any of them: the checksum goes to stdout and there is
#       no `-o`. `-c/--check` READS a checksum file and is deliberately NOT admitted, because it
#       takes a second file argument whose role is not "the thing being hashed".
#   shasum -- the perl-packaged equivalent shipped with git-for-windows and macOS; same absence of
#       an output option. It is not admitted as an INTERPRETER: the guard sees `shasum` in verb
#       position and perl's own flags are unreachable from there.
#   Get-FileHash -- the only in-box hasher on Windows PowerShell. Its parameters are -Algorithm,
#       -Path, -LiteralPath and -InputStream; none of them writes. Its output is a pipeline object,
#       and putting that anywhere needs a redirect or a pipe, which clause C1 refuses.
#   certutil -- admitted with the narrowest flag set of the four, and named here as the riskiest
#       inclusion because it is a general-purpose tool with a well-known download verb
#       (`-urlcache -split -f <url> <file>`). It is bounded twice: `-urlcache`, `-split` and `-f`
#       are NOT in its closed flag set, and a URL token resolves to no mission-plane path, so such
#       a command carries no permitted path token and fails C6.
# DELIBERATELY EXCLUDED, with the reason: `openssl dgst` (it has `-out`, which writes);
# `git hash-object` (`-w` writes into the object store, and git already has its own route through
# the segment classifier); python, node, perl, pwsh, powershell, bash, sh and every other
# interpreter (AN INTERPRETER IS NEVER A READ-ONLY VERB -- `-c` is arbitrary code); xxd, od, cat,
# head (not hashes at all -- admitting readers is a larger question than this cure asks, and it
# should be asked on its own rather than smuggled in under a hashing cure).
#
# THE RESIDUAL, NAMED RATHER THAN ARGUED AWAY (design SS4.5 law 4). If one of these verbs has an
# output option I have not found, a dispatched worker could clobber a file under
# `.mission/dispatches/` or `.mission/contract/` with no metacharacter. That is the honest failure
# mode, and it is bounded three ways: to those two directories, by C5 and C6; to a RECORDED call,
# because the hook writes a log entry either way; and to no durable effect, because dispatch faces
# and contract artifacts are committed and hash-chained, so a clobbered face does not re-derive.
# A second residual, smaller and disclosed: a DIRECTORY under the two roots -- for example
# `.mission/contract/assertions` -- satisfies the path clause. A hashing verb handed a directory
# reads nothing and writes nothing; it errors. The exception therefore admits a call that cannot
# succeed rather than one that can do harm. It is still a tripwire, not a boundary.
#
# THE CLOSED VERB -> CLOSED DASH-FLAG TABLE. Every key is a lowercased path LEAF, and no value
# contains a flag that takes an output destination. A verb absent from this table is unrecognised
# and the predicate returns false.
$script:EvidenceMissionHashVerbs = @{
    'sha256sum'    = @('-b', '--binary', '-t', '--text', '--tag')
    'sha512sum'    = @('-b', '--binary', '-t', '--text', '--tag')
    'sha384sum'    = @('-b', '--binary', '-t', '--text', '--tag')
    'sha224sum'    = @('-b', '--binary', '-t', '--text', '--tag')
    'sha1sum'      = @('-b', '--binary', '-t', '--text', '--tag')
    'md5sum'       = @('-b', '--binary', '-t', '--text', '--tag')
    'shasum'       = @('-b', '--binary', '-t', '--text', '-a', '--algorithm', '-p', '--portable')
    'get-filehash' = @('-algorithm', '-literalpath', '-path')
    'certutil'     = @('-hashfile')
}

function Test-EvidenceReadOnlyMissionHashCommand {
    <#
      TRUE only for a command that is unmistakably a READ-ONLY HASH of a file under
      `.mission/dispatches/` or `.mission/contract/`. Consulted as the first clause of
      Test-EvidenceWorkerPlanePath, where it suppresses that rule's deny and nothing else.

      WHERE IT IS PLACED, AND WHY THE OBVIOUS PLACE IS A TRAP. The worker-plane rule has FOUR call
      sites: this file's file route and shell route, and the SEALED A1 copies at framework:1660 and
      framework:1716. A1's bytes may not be edited by this build, but A1's copy calls
      Test-EvidenceWorkerPlanePath BY NAME, and PowerShell resolves a command name at call time in
      the current session state -- where this file's redefinition is what stands. So the exception
      belongs INSIDE the function, which reaches all four sites. Writing it at this file's shell
      call site instead leaves framework:1716 to re-deny at the delegation, and the cure then reads
      correct and measures NOTHING. That is not a reading: it was DRIVEN. A variant carrying the
      suppression at the shell call site only returned exit 2 for the very command this cure exists
      to admit, while the in-function placement returns exit 0 for it -- and the difference between
      those two runs IS A1's copy, consulted and governed. WP-1 H-8 carries the measurement.

      THE TEXT IT IS GIVEN. On the file-tool route the argument is a bare path with no verb, so C3
      fails by construction and a Write, Edit or MultiEdit is never exempted: the exception cannot
      leak across routes. On the shell route the argument is the COMMAND TEXT, and at this file's
      shell call site it is the command PLUS every resolved path form appended by the augmentation
      above. Clause C5 is written for that: a token naming no mission-plane path is passed over,
      because the rule this predicate suppresses is about `.mission/` paths and nothing else, and
      every other layer still judges those tokens. A token that DOES name the plane must resolve,
      in every form, inside the two permitted roots.

      TWO SPELLINGS THAT FAIL CLOSED, disclosed here rather than discovered later.
      (1) A QUOTED path token, with the quote characters still attached, does not match the
          anchored root test, so the exception does not apply and the deny stands.
      (2) WHERE THE PROCESS STANDS CAN KILL THE EXCEPTION. Every non-flag token is offered in its
          cwd-joined form as well, so when the working directory is itself inside a `.mission` or
          `.mission-runtime` subtree, an ordinary token such as `README.md` resolves to a plane
          path that is not under the two permitted roots, and C5(b) refuses. That is deliberate:
          the cwd-joined form is the path the command will actually open (V-1 round 5), and
          dropping it here would reopen `cd .mission/dispatches` followed by a relative token
          reaching the evidence plane. The cost is a refused legitimate hash for a worker standing
          inside the plane; the worker spells the path from the repository root and it is admitted.
      Both are refusals of a legitimate command, which is the safe direction.
    #>
    param([AllowNull()][string]$Text, [AllowNull()][string]$Cwd = $script:EvidenceCwd)
    if (-not $Text) { return $false }
    try {
        # C1 -- NO SHELL METACHARACTER AND NO NEWLINE. This exception can never coexist with the
        # metacharacter tier (line 3 above): where one fires, the other is structurally absent.
        if ($Text -match $script:ShellMetaPattern) { return $false }
        if ($Text -match "`n") { return $false }
        if ($Text -match "`r") { return $false }
        # C2 -- EXACTLY ONE COMMAND SEGMENT. Belt over the brace: A1's splitter also breaks on a
        # newline, so a smuggled second command fails here even if C1 somehow did not see it.
        if (@(Split-CommandSegments -Command $Text).Count -ne 1) { return $false }
        $tokens = @($Text -split '\s+' | Where-Object { $_ })
        if ($tokens.Count -lt 2) { return $false }
        # C3 -- THE VERB, TAKEN BY ITS PATH LEAF so that /usr/bin/sha256sum is the same verb, AND
        # REFUSED IF THE VERB ITSELF LIVES IN THE MISSION PLANE. Without that second test the
        # exception would admit EXECUTING a file inside the territory it exists to let a worker
        # only read.
        $verbTok = $tokens[0]
        $leaf = (($verbTok -split '[\\/]') | Where-Object { $_ } | Select-Object -Last 1)
        if (-not $leaf) { return $false }
        $leaf = ($leaf -replace '\.exe$', '').ToLowerInvariant()
        if (-not $script:EvidenceMissionHashVerbs.ContainsKey($leaf)) { return $false }
        # THE VERB IS JUDGED ON WHAT WAS WRITTEN, NOT ON WHERE THE PROCESS STANDS -- so the two
        # textual forms, and deliberately NOT the cwd-joined ones. Driven, and it was a real defect
        # before it was a comment: with the cwd-joined forms in this test, a process standing
        # anywhere inside a .mission or .mission-runtime subtree made EVERY verb token resolve into
        # the plane, so the exception died for every command. That direction is safe -- it denies --
        # but it is noise, and a rule about the verb must answer about the verb.
        foreach ($vf in @((ConvertTo-CanonicalPathText -Text $verbTok), (Resolve-DotSegments -Token $verbTok))) {
            if ($vf -and ($vf -match '(^|/)\.mission(-runtime)?(/|$)')) { return $false }
        }
        $flags = @($script:EvidenceMissionHashVerbs[$leaf])
        $sawPermittedPath = $false
        foreach ($tok in $tokens[1..($tokens.Count - 1)]) {
            # C4 -- NO TOKEN CARRIES AN EQUALS SIGN. This kills the whole --output=<path> family
            # generically, including an option nobody has enumerated yet, and it costs nothing:
            # none of the admitted flags is written with one.
            if ($tok.Contains('=')) { return $false }
            # C5(a) -- A DASH TOKEN MUST BE IN THE CLOSED PER-VERB SET. Unknown flag, deny.
            if ($tok.StartsWith('-')) {
                if ($flags -notcontains $tok.ToLowerInvariant()) { return $false }
                continue
            }
            $forms = @(Get-EvidencePathForms -Text $tok -Cwd $Cwd)
            if ($forms.Count -eq 0) { return $false }
            $namesPlane = $false
            foreach ($f in $forms) {
                if ($f -match '(^|/)\.mission(-runtime)?(/|$)') { $namesPlane = $true; break }
            }
            # A token that names no mission-plane path in ANY of its forms is not this rule's
            # business. It is still judged by the metacharacter tier, A1's protected tier, the gate
            # rule, the marker rules and A1's segment classifier -- none of which this predicate
            # touches. Passing over it is also what makes the exception survive the shell call
            # site's path augmentation, which appends resolved forms of EVERY token including the
            # verb's own: requiring every token to be a permitted plane path would make the
            # exception unreachable at the site that matters, which is exactly the shape of a cure
            # that measures nothing.
            if (-not $namesPlane) { continue }
            # C5(b) -- EVERY RESOLVED FORM, not one of them. `.mission/dispatches/../evidence/x`
            # READS as permitted and RESOLVES as the evidence plane; the dot-segment resolution
            # inside the form builder produces both, and the permitted test must hold for both.
            foreach ($f in $forms) {
                if ($f -notmatch '(^|/)\.mission/(dispatches|contract)/[^/]') { return $false }
                if ($f -match '(^|/)\.mission(-runtime)?/evidence(/|$)') { return $false }
            }
            # AND THE THREE ARTIFACT RULES, asked BY NAME rather than restated as a regex here. A
            # gate, a supersession marker and an ownership marker are refused even if some future
            # layout were to put one under the two permitted roots.
            if (Test-EvidenceGatePath -Path $tok) { return $false }
            if (Test-EvidenceSupersessionMarkerPath -Path $tok) { return $false }
            if (Test-EvidenceOwnershipMarkerPath -Path $tok) { return $false }
            $sawPermittedPath = $true
        }
        # C6 -- AT LEAST ONE PERMITTED PATH TOKEN. A hashing verb with no plane path has nothing to
        # be excepted FOR, and the rule it would suppress was not going to fire anyway.
        return $sawPermittedPath
    }
    catch {
        # FAIL CLOSED. A predicate that throws under Set-StrictMode must not decide anything; the
        # worker-plane rule then evaluates exactly as it does today.
        return $false
    }
}

function Test-EvidenceWorkerPlanePath {
    <#
      LAM-ACCEPT K-3 as amended (amendment 15). THE WORKER'S MISSION-PLANE
      RESTRICTION, expressed here because it CANNOT BE EXPRESSED IN THE PERMISSION GRAMMAR.

      K-3 asks for "no `.mission/**` writes except exactly two closed members". Claude Code
      evaluates deny before allow, specificity does not change the order, and a deny rule cannot
      carry allowlist exceptions -- so `Edit(.mission/**)` in deny shadowed both allow entries and
      the number of exceptions that obtained was ZERO. Confirmed by driving the real CLI against a
      byte-identical copy of worker.json with a passing control (V-1 round 2, WP-5), and it was not
      a paper defect: the runner passes that file as --settings for every dispatched worker, so
      R-3's required handoff was unwritable by the role obliged to produce it.

      TRUE IFF the text names a `.mission/` path that is NOT one of the two closed members.

      TOKENISE FIRST, ANCHOR WITHIN THE TOKEN -- the T-3 cure, reused rather than reinvented. A
      `(^|/)`-anchored regex over a whole command string cannot match after a space, which is how
      `cp seed.yaml .mission/gates/x.yaml` once returned ALLOW. Every predicate in this file that
      reinvented the matching had that bug; the one that delegated never did.

      `.mission-runtime/` DOES NOT MATCH, by construction: `\.mission/` requires a slash
      immediately after `mission`, and `.mission-runtime` carries a hyphen there.
    #>
    param([AllowNull()][string]$Path, [AllowNull()][string]$DispatchId)
    if (-not $Path) { return $false }
    # CLOSED MEMBER 3, AND IT IS THE FIRST CLAUSE ON PURPOSE. A read-only hash of a file
    # under .mission/dispatches/ or .mission/contract/ is not a WRITE, and K-3's own text scopes
    # this rule to writes. Placed INSIDE the function rather than at a call site so that all four
    # call sites -- this file's two and the SEALED A1 copies at framework:1660 and :1716, which
    # call this function by name -- see the same answer. It can only SUPPRESS this rule's deny:
    # lines 2 and 3 (A1's protected tier and the metacharacter tier), the gate rule and the two
    # marker rules run afterwards regardless, and the predicate returns false for everything it
    # does not recognise. See the block above this function for the closed sets and the residual.
    if (Test-EvidenceReadOnlyMissionHashCommand -Text $Path -Cwd $script:EvidenceCwd) { return $false }
    # THE EXCEPTION IS "ITS OWN HANDOFF", AND THE FIRST IMPLEMENTATION MADE IT "ANY HANDOFF"
    # (V-1 round 3, WP-5). K-3 names `.mission/dispatches/<dispatch_id>.handoff.yaml`; the pattern
    # below shipped as `[^/]*\.handoff\.yaml`, a wildcard over EVERY dispatch id -- so a dispatched
    # worker could overwrite a PEER dispatch's handoff, by file tool and by shell, allowed and
    # unlogged. The dispatching id was in scope the whole time, in the very predicate that gates
    # this rule. Worse, the deny message quoted the narrow `<id>.handoff.yaml` form while the code
    # enforced the wide one: the artifact's own face claimed a closure the code did not have, which
    # is the overclaim this build's laws exist to forbid, committed by the fix for the last one.
    # Falling back to the wildcard when no id is known would re-open it, so an unknown id closes
    # the exception entirely -- fail closed.
    $ownHandoff = if ($DispatchId) {
        '(^|/)\.mission/dispatches/' + [regex]::Escape($DispatchId) + '\.handoff\.yaml$'
    } else { $null }
    foreach ($f in @(Get-EvidencePathForms -Text $Path)) {
        # JUDGE TOKENS, NOT THE WHOLE COMMAND TEXT (V-1 round 8, found by reordering the offered
        # tokens). Form #1 is the entire canonicalised text. Once the cwd augmentation appends an
        # ABSOLUTE plane path, that whole-text form matches the plane pattern -- and the two
        # exceptions below are `$`-anchored, so they can only be satisfied when the command happens
        # to END with the excepted path. Measured: `cp h.yaml <own handoff>` was allowed and
        # `cp <own handoff> backup.yaml` was DENIED, for the same act written the other way round.
        #
        # A worker's own handoff is one of K-3's two closed exceptions; denying it means no dispatch
        # can complete. The exception must not depend on where in the line the path appears.
        #
        # Nothing is lost by skipping it: every path in the command is also offered as its own
        # token form, with its cwd-joined absolute alongside. The whole-text form can only ever
        # restate what the tokens already say -- and it restates it in a shape the anchors misread.
        if ($f -match '\s') { continue }
        if ($f -notmatch '(^|/)\.mission/') { continue }
        # CLOSED MEMBER 1 -- the worker's own evidence session.
        # DISCLOSED: this exception is unreachable in practice and that is CORRECT, not a defect.
        # A1's sealed protected set denies `.mission/evidence` to every role by both routes, and
        # this build may not modify it. The exception is therefore a PERMISSION-LAYER one that the
        # guard layer overrides -- which costs nothing, because a worker's evidence session is
        # written by the HOOKS, harness-side, never by the worker's tool calls. It is named here so
        # the closed set reads the same in both places rather than silently differing.
        if ($f -match '(^|/)\.mission/evidence/session-[^/]+/') { continue }
        # CLOSED MEMBER 2 -- the worker's OWN handoff, scoped to the dispatching id.
        if ($ownHandoff -and ($f -match $ownHandoff)) { continue }
        return $true
    }
    return $false
}

function Test-EvidenceDispatchedWorker {
    <#
      Is THIS session a dispatched worker? The runner sets LAM_DISPATCH before spawning
      `claude -p` (mission-dispatch.ps1), so the hook child inherits it and an agent cannot set it
      for its own hook process from inside a tool call.

      WHY THE WORKER RULE IS SCOPED AND T-3 IS NOT. There is no role for which minting one's own
      authorization is legitimate, so T-3 is role-blind by design and stays that way. Writing the
      mission plane is different: `git add .mission/ledger/entries.jsonl` and amendment placement
      are ORDINARY CEREMONY, and A1's own doctrine warns in as many words that a blanket ban on
      `.mission` "would deny ... ordinary mission ceremony that is not evidence at all -- and a
      guard that blocks the workflow it protects gets switched off". So the rule fires only where
      K-3 scopes it.

      LAM_DISPATCH is already the contract-named compensating control for telling machinery from a
      human (the S-5 dispatch route); this is the same marker doing the same job one layer
      down, not a new trust assumption.
    #>
    return [bool]$env:LAM_DISPATCH
}

# =================================================================================================
# THE GATE TOOL'S VALUE-PARAMETER MODEL, AND THE SHELL-DECIDED VALUE THAT WOULD WIDEN IT
# (b1s5 item 3; docs/framework/LAM-ACCEPT.md amendment 37 "what is not claimed" (3)).
# EXTENDED b1s6 item 3 (the brace/glob refutation of amendment 46, the lead's addendum, and the ruling's
# covered spellings) -- see THE b1s6 EXTENSION below; nothing earlier in this block was narrowed.
# =================================================================================================
# WHAT AMENDMENT 37 REGISTERED. mission-gate.ps1 declares `[string]$Reason` at script level (used by
# revoke/reapprove), and $script:EvidenceGateToolValueParams above did NOT carry `reason`. So for a
# bare `mission-gate.ps1 list -Reason x` the verb scan skipped `-Reason` as an unknown switch and read
# its VALUE `x` as a second positional -- two positionals, refused. Fail-CLOSED (a false refusal), but
# a false refusal of the ratified `revoke ... -Reason` convention, which is what the note asked to fix.
# `reason` is now in the model, so PowerShell's script-level binding of -Reason is mirrored by the
# guard whatever the verb.
#
# WHY THAT ADDITION NEEDED A GUARD BESIDE IT, MEASURED NOT REASONED. Adding a value-taking parameter
# lets it CONSUME the next token, and the predicate tokenises the QUOTE-STRIPPED command -- so an
# empty quoted string vanishes before tokenisation and the token AFTER it slides into the parameter's
# value slot. Driven at the base of this edit through the real hook:
#   mission-gate.ps1 -Reason '' approve -Ruling list -Kind push -Id x -Binds y
# binds Command=approve in PowerShell (a MINT), yet with `reason` naively added the guard would let
# -Reason swallow `approve`, leave -Ruling's `list` as the lone positional, and ALLOW. That is the
# EXACT pre-existing hole the register's two `!!` rows record for -MissionRoot '' -- literally adding
# `reason` would have minted a new spelling of it. So the model gains `reason` AND this guard, and the
# guard is written to only ever ADD denials.
#
# THE RULE. A token consumed as a value-taking parameter's value whose ARGUMENT COUNT THE SHELL
# decides rather than the text is unreadable, and an unreadable invocation of this tool is a mutation
# by default (the same direction as the backtick/`$(` branch in the predicate above). The closed set
# of shell-decided shapes, each measured through the real hook (b1s5 = amendment 46's four, unchanged):
#   ''  ""            an empty quoted string      (b1s5; bash and cmd both collapse it; the guard sees nothing)
#   '  "  (lone)      a quoted run of whitespace  (b1s5; `-Reason ' '` splits to a lone quote token; the
#                                                  shell joins across the space, the text cannot)
#   %NAME%            a cmd environment expansion (b1s5; value set by the environment, not the line)
#   !NAME!            a cmd delayed expansion under /v:on (b1s5; same)
#   {  anywhere       BRACE EXPANSION (b1s6). bash turns {x,approve} into TWO words before
#                     PowerShell binds: -Reason takes x and approve binds as Command, a MINT the guard
#                     read as ONE value beside a -Ruling list decoy. A one-word {a} is refused too (the
#                     rule is the character, so a comma inside braces needs no clause of its own).
#   * ? [ ]           A GLOB (b1s6). a[ap]* in a cwd holding `aa` and `approve` is two words and
#                     binds Command=approve; in an empty cwd bash leaves it literal. The guard cannot
#                     know a directory listing, so the character decides, not the listing.
#   quotes only       A TOKEN MADE OF QUOTE CHARACTERS ONLY (b1s6): ''"" and "''" are one word to
#                     bash (empty, or two literal quotes) and NOTHING to the quote-stripped scan -- the
#                     b1s5 empty-quote hole in spellings its two exact literals did not name.
#   ...\              A TRAILING BACKSLASH, a lone \ included (b1s6, the addendum's item 2). It
#                     escapes what follows: a space (`-Reason x\ -Kind approve` makes `x -Kind` ONE
#                     word, so the -Kind the guard saw consuming approve does not exist) or a line break.
#   $                 A SHELL PARAMETER EXPANSION THE UNREADABLE BRANCH DOES NOT MATCH (b1s6): $1,
#                     $@, $*, $#. Unquoted it is word-split -- under IFS=, a positional ,approve turns
#                     x$1 into x and approve. The unreadable regex matches $NAME, never $<digit> or $@.
#   @...              A POWERSHELL SPLAT (b1s6): in the PowerShell tool `-Reason @Error` hands the
#                     native tool one argument PER ELEMENT of an automatic variable no $ names -- after
#                     two Write-Error calls in the same command it binds Reason=x and Command=approve.
# AND THREE TESTS THE VALUE TOKEN ALONE CANNOT MAKE, in Test-EvidenceGateToolValueParamShellDecided:
#   QUOTE-GLUED NAME  -MissionRoot"" / '-MissionRoot' / -Id'' / ""-Id (b1s6, the addendum's item 1). The
#                     NAME was matched on the RAW token, so a quote glued to it hid the value from
#                     every test above while the quote-stripped verb scan still consumed it. The name is
#                     now matched with the quote characters DELETED; the value token stays raw.
#   ODD QUOTES ON A NAME  -Kind' (b1s6, R3): a name that CLOSES a quoted run is not a switch to the
#                     shell -- `-Reason 'x -Kind' approve` is -Reason=<x -Kind> and approve binds as
#                     Command, while the guard saw -Kind consume approve. Tested on the name part only.
#   \ + LINE BREAK    ANYWHERE in the heredoc-stripped text (b1s6, the addendum's item 2 generalised
#                     under R3): bash joins the next line into the invocation, the segmenter has cut
#                     at the newline, and `-Ruling list -Verbose\<LF> approve` binds Command=approve
#                     with NO value slot involved at all -- which is why this one is not a token test.
# The b1s5 shapes CLOSED THE PRE-EXISTING -MissionRoot '' / "" / ' ' FAIL-OPEN for the SEPARATED
# spelling only. THAT IS AMENDED (b1s6): -MissionRoot"" '' approve ... and '-MissionRoot' '' approve
# ... bind Command=approve and were ALLOW before; the quote-glued-name test closes
# them now.
#
# THE b1s6 EXTENSION -- RULINGS, FORKS AND FAILURE DIRECTION (operator: treat `{`, `,` in braces, and
# `*?[]` in a value slot as shell-decided, refusing the command; adds refusals only).
#   R1  every value-taking parameter in the model, separated and attached (`-Reason:{x,approve}`,
#       `-Id={a,b}`), through the one token predicate below. The -Command fork, the help clause and
#       the verb scan are untouched: this helper runs BEFORE them, so `-MissionRoot {x,approve} -?`
#       -- admitted by the help clause before -- is refused here first.
#   R2  FORK, FAIL-CLOSED: QUOTING IS IGNORED. The tokeniser splits raw text on whitespace and has no
#       quote state, and `bash -c "... -Reason "'{x,approve}'" ..."` closes the outer quote, so the
#       braces are unquoted to the inner shell (measured: Command=approve). COST, measured: a quoted
#       value carrying one of the characters is refused -- `list -Reason 'why?'`, `list -Reason "{x}"`,
#       `list -Reason 'a[1]'`, `list -MissionRoot "C:/a*b"`, `list -Reason 'cost$5'`, `list -MissionRoot
#       C:\temp\` -- each ALLOW before, DENY now.
#   R3  `}` or `,` without `{` is NOT shell-decided: `list -Reason a,b` and `list -Reason x}` are one
#       word in bash and one argument in PowerShell (measured) and stay ALLOW. The R3 spellings found
#       and COVERED because each is one line and adds refusals only: quotes-only, trailing backslash,
#       $-expansion, odd quotes on a name, \+line break -- each one measured ALLOW before with a
#       bash word list that binds Command=approve, and DENY now.
#   SCOPE FORK (the addendum's item 6): NOT NARROWED. Every new test runs over every segment and every
#       position, exactly as the b1s5 tests do, because narrowing to "after the tool token" needs the
#       tool located on RAW tokens whose quoting the predicate's variants resolve differently -- a
#       second locator is a second place to miss it. COST, measured ALLOW -> DENY: `ls -t *.ps1;
#       mission-gate.ps1 list` (-t prefixes tipsha), `echo a \<LF>b<LF>mission-gate.ps1 list`,
#       `powershell -Command { tools/lam/mission-gate.ps1 list }`. Value-token quote PARITY was NOT
#       added for the same reason: it would refuse `bash -c "powershell -File ...mission-gate.ps1 list"`
#       (the -c value opens a quote), which stays ALLOW.
#
# THE -Command FORK (b1s5 item 3, recorded per the common brief's fail-closed rule). Modelling
# `reason` had a collateral edge NOT covered by the shell-decided guard above: for the SEPARATED form
#   -Command approve -Reason x -Ruling list -Kind push -Id x -Binds y
# `x` was a stray positional at base (reason unmodelled), so base refused it on a 2-positional count;
# once `x` is consumed the command collapses to the pre-existing `-Command approve -Ruling list` decoy
# (ALLOW at base), a DENY->ALLOW that REACHES A MINT (`approve`). Point 2's guard does not cover it --
# `approve` is a literal, not a shell-decided value. Two instructions then conflict for this one row:
# "add reason" (point 1) versus "must not widen the fail-open" / the transition invariant (no
# deny->allow may reach a mutating verb). The common brief directs the CONSERVATIVE reading, so the
# value-param loop now collects a NON-`list` value of an EXPLICIT, SEPARATED `-Command` as the
# positional verb it is: the mint is seen and refused. This can ONLY add denials (it only ever ADDS a
# positional), it is scoped to `-Command` tokens AFTER the tool token (so `powershell -Command "..."`,
# where -Command is the shell's own exec lead BEFORE the tool token, is untouched), and it also closes
# the separated `-Command approve -Ruling list` fail-open as a measured side effect (ALLOW->DENY).
#
# WHAT THIS DOES NOT CLAIM (findings, not cures):
#   * A LITERAL attached `-Command:<verb>` / `-Command=<verb>` (quoted or not, any case, `-Comm:` too) is
#     REFUSED (WP-1 H-20): split at its FIRST `:`/`=` and collected as the verb WITHIN
#     THE TOOL'S SEGMENT (`=` cannot bind under PS 5.1: refused fail-closed). NOT REACHED -- pre-existing, ALLOW
#     before and now, register candidates, not built -- are three CLASSES, the
#     spellings only examples (measured list: WP-1 H-20's header). (1) SEVERING: the predicate's
#     three splits (Split-CommandSegments, `&`, `[()]+`) are QUOTE-BLIND: any argument before the verb carrying
#     `;` `|` `&` `(` `)` severs the tool's segment -- attached, separated or positional verb alike (`-Ruling
#     list -Id 'a;b' -Command:approve`). (2) A PARAMETER NAME THE SHELL TRANSFORMS: only a name part reaching
#     the guard LITERALLY as a prefix of `command` is recognised; one with `\` `^` (escapes), `{` `}` (brace),
#     `$1` `$@` (positionals), `%` `!` (cmd) binds `-Command:approve` but the token drops WHOLE (bash
#     `-Comm\and:approve`, `-{Command:approve,Verbose}`); a `$NAME`, `${`, `$(`, `$'` or backtick anywhere is
#     not in it, :3628 refusing the command first. (3) THE TOOL NOT IN EXECUTABLE POSITION as this predicate
#     defines it (first of a segment, or after an ExecLeads member, :3566): a backslash IN the tool name, a
#     string handed to `iex`, a script block opened with a space, the three below -- no verb is judged.
#     DECOY: an UNMODELLED parameter's value donates a fake `list`; `-Ruling`, `-ComposedAt`, `-ConsoleToken`,
#     `-ConsoleCredential`, `-OutVariable` stay OUT of the model (adding one REMOVES denials; a recorded finding). With NO
#     decoy `-Command list`, `:list`, `=list` stay REFUSED (`-Command list -MissionRoot .`; a recorded finding, R2); with one
#     they bind a read (or cannot bind) and pass, unchanged.
#   * A shell that computes an invocation whose text never names the tool is unreachable here
#     -- a tripwire on the ratified spelling, not a boundary. CORRECTED b1s6:
#     PowerShell/bash value-slot expansions were credited to the unreadable branch; FALSE: it matches $NAME,
#     $( ), ${ }, $' and a backtick only, and brace expansion, globs, $1/$@ word splitting and a backslash
#     continuation passed it, changing the word count (a MINT each, measured); THIS helper refuses them.
#   * STILL NOT REACHED (class 3), ALLOW before and now: the tool NAME split by a continuation, glued to an
#     expansion (`...mission-gate.ps1$1`), fed to a heredoc interpreter -- the three. `-?` is a bash GLOB
#     IN THE HELP FLAG, matching only two-character `-` names, never a verb: admitted (H-9). A multi-word quoted
#     -Reason (`-Reason "a b" list`) splits and refuses (safe); a zero-word `$@` fails closed (MORE tokens).
function Test-EvidenceShellDecidedToken {
    <#
      Is this ONE raw token (as whitespace-splitting the un-quote-stripped command yields it) a value
      whose argument count the SHELL fixes rather than the command text? Closed set, exact where it can
      be and anchored substring for the cmd expansions; the b1s6 clauses are single characters or
      anchored shapes, listed in the block above. Quoting is ignored on purpose (R2). Returns only
      $true/$false; never throws under Set-StrictMode.
    #>
    param([AllowNull()][string]$Token)
    if ($null -eq $Token -or $Token -eq '') { return $false }
    if ($Token -eq "''" -or $Token -eq '""') { return $true }       # empty quoted string
    if ($Token -eq "'"  -or $Token -eq '"')  { return $true }       # lone quote: value was quoted whitespace
    if ($Token -match '%[^%\s]*%') { return $true }                 # cmd %NAME% (and %%) expansion
    if ($Token -match '![^!\s]*!') { return $true }                 # cmd delayed !NAME! expansion
    if ($Token.Contains('{')) { return $true }                      # b1s6 R1: brace expansion ({x,approve}, and a one-word {a})
    if ($Token.IndexOfAny([char[]]@([char]42, [char]63, [char]91, [char]93)) -ge 0) { return $true }   # b1s6 R1: glob * ? [ ]
    if ($Token -match '^[''"]+$') { return $true }                  # b1s6 R3: quote characters only (''"", "''")
    if ($Token.EndsWith('\')) { return $true }                      # b1s6 addendum 2 / R3: a trailing backslash, a lone \ included
    if ($Token.Contains('$')) { return $true }                      # b1s6 R3: $1 $@ $* $# -- expansions the unreadable regex does not match
    if ($Token.StartsWith('@')) { return $true }                    # b1s6 R3: a PowerShell splat (@Error, @args) -- one token, many arguments
    return $false
}
function Test-EvidenceGateToolValueParamShellDecided {
    <#
      Does $Command hand a value-taking parameter of mission-gate.ps1 a shell-decided value (see the
      block above)? Segments and tokenises with the SAME primitives the gate predicate uses, but on the
      RAW text -- the quote-stripped variants the predicate scans have already destroyed the quotes this
      has to see. Both the separated form (`-Reason ''`) and the attached forms (`-Reason:''`,
      `-Reason=''`) are examined. b1s6: the NAME is matched with its quote characters deleted (the value
      token stays raw), a name carrying an odd number of either quote character is refused, and a
      backslash that ends a line anywhere in the text is refused. Only ever returns $true to ADD a
      denial; the caller has already confirmed the tool is named in executable position.
    #>
    param([AllowNull()][string]$Command)
    if (-not $Command) { return $false }
    $scan = Remove-EvidenceHeredocBodies -Text $Command
    # b1s6: A LINE CONTINUATION. Judged on the text, not a token: the segmenter has already cut there.
    if ($scan -match '\\\r?\n') { return $true }
    foreach ($outer in @(Split-CommandSegments -Command $scan)) {
        foreach ($mid in ($outer -split '&')) {
            foreach ($seg in ($mid -split '[()]+')) {
                $toks = @(($seg -split '\s+') | Where-Object { $_ })
                for ($i = 0; $i -lt $toks.Count; $i++) {
                    $tok = $toks[$i]
                    $namePart = $tok
                    $attached = $null
                    $sep = $tok.IndexOfAny(@([char]58, [char]61))   # ':' or '='
                    if ($sep -ge 0) { $attached = $tok.Substring($sep + 1); $namePart = $tok.Substring(0, $sep) }
                    # b1s6 (addendum item 1): the NAME with its quote characters deleted, so a quote glued
                    # to or wrapping it cannot hide the value; the value token below is still RAW.
                    $bare = ($namePart -replace $script:EvidenceQuoteChars, '')
                    if (-not ($bare.StartsWith('-') -or $bare.StartsWith('/'))) { continue }
                    $name = ($bare -replace '^[-/]+', '')
                    if (-not $name) { continue }
                    $nl = $name.ToLowerInvariant()
                    $isValueParam = $false
                    foreach ($p in $script:EvidenceGateToolValueParams) { if ($p.StartsWith($nl)) { $isValueParam = $true; break } }
                    if (-not $isValueParam) { continue }
                    # b1s6 (R3): a name carrying an ODD count of either quote character opens or closes a
                    # quoted run, so to the shell it is part of a word and not a switch at all.
                    $sq = $namePart.Length - $namePart.Replace([string][char]39, '').Length
                    $dq = $namePart.Length - $namePart.Replace([string][char]34, '').Length
                    if ((($sq % 2) -eq 1) -or (($dq % 2) -eq 1)) { return $true }
                    if ($null -ne $attached) {
                        if (Test-EvidenceShellDecidedToken -Token $attached) { return $true }
                        continue
                    }
                    if (($i + 1) -lt $toks.Count -and (Test-EvidenceShellDecidedToken -Token $toks[$i + 1])) { return $true }
                }
            }
        }
    }
    return $false
}

# --- THE PATH-FRAGMENT EVASION CURE (batch 1 session 4, ITEM 2) --------------------------------
# A protected/parent path spelled IN PIECES across a command evades A1's matcher AND the
# metacharacter gate, because Get-EvidencePathHits matches literal protected substrings and
# $script:ShellMetaPattern -- '[><|&;$`(){}*?]' -- contains NONE of '+', a quote, or the letters of
# `chr`. So `'.mis' + 'sion'`, `chr(46) + 'mission-runtime'`, `Join-Path '.mission' 'evidence'`, and
# a variable literal-assigned earlier and then joined all NAME protected territory the guard cannot
# see, and each was measured ALLOWED against the unedited library. The functions below reconstruct
# ONLY what the guard can STATICALLY READ -- string literals, chr(<int>)/[char]<int> constants,
# Join-Path/[IO.Path]::Combine over literal components, and variables assigned such an expression
# EARLIER IN THE SAME TEXT. RUNTIME expansions ($env, ${VAR}, $(...), backticks, %VAR%, a bare $var
# never literal-assigned here) are deliberately NOT evaluated: the guard cannot read them, and the
# git 'unreadable' refusal class already refuses expansions (per the brief's scope).
#
# FALSE-POSITIVE DISCIPLINE, load-bearing. Two rules keep this from reddening ordinary work:
#   (a) QUOTE-AWARE. The scan runs over a masked form in which every TOP-LEVEL string literal is one
#       opaque marker, so a '+' or fragment INSIDE a quoted argument -- a commit message quoting the
#       words -- is never read as structure, while a '+' BETWEEN two quoted literals still is.
#   (b) NEW-HIT ONLY. A reconstruction fires only when it yields a protected/parent hit the RAW
#       command text does not already contain. If the literal is already present, A1's tiers judge
#       it with their own (metacharacter / destructive / ceremony) semantics and this adds nothing --
#       so `Join-Path '.mission' 'ledger'` (parent already in raw) is left exactly as A1 leaves it.
# It can only ADD denials, never remove one, and never scans `content`/`file_path` -- only command
# TEXT, so a document that quotes an evidence path is not judged here (a validator finding's cure preserved).

function ConvertFrom-EvidenceCharCode {
    # A chr(<int>) / [char]<int> code point -> its one-character string. Never throws.
    param([AllowNull()][string]$N)
    if (-not $N) { return @{ ok = $false; value = '' } }
    $code = -1
    try {
        if ($N -match '^0[xX]') { $code = [Convert]::ToInt32($N.Substring(2), 16) }
        else { $code = [int]$N }
    } catch { return @{ ok = $false; value = '' } }
    if ($code -ge 0 -and $code -le 65535) { return @{ ok = $true; value = ([string][char]$code) } }
    return @{ ok = $false; value = '' }
}

function ConvertTo-EvidenceAsmMasked {
    # Quote-aware masking: replace every TOP-LEVEL string literal with a marker <SOH>index<SOH> and
    # record its value + whether it carries interpolation ($ or a backtick escape). A single quote
    # inside a double-quoted string is a literal character, not a delimiter, so this is what keeps
    #   git commit -m "note '.mis'+'sion'"     (concat INSIDE one message -> never read)
    # apart from
    #   "tools/fram" + "ework/hooks"           (concat BETWEEN two literals -> read).
    param([string]$Command)
    $values = New-Object System.Collections.Generic.List[hashtable]
    $sb = New-Object System.Text.StringBuilder
    $mk = [char]2
    $i = 0; $n = $Command.Length
    while ($i -lt $n) {
        $ch = $Command[$i]
        if ($ch -eq "'") {
            $j = $i + 1; $closed = $false
            $val = New-Object System.Text.StringBuilder
            while ($j -lt $n) {
                if ($Command[$j] -eq "'") {
                    if (($j + 1) -lt $n -and $Command[$j + 1] -eq "'") { [void]$val.Append("'"); $j += 2; continue }
                    $closed = $true; $j++; break
                }
                [void]$val.Append($Command[$j]); $j++
            }
            if (-not $closed) { [void]$sb.Append($Command.Substring($i)); break }
            [void]$sb.Append($mk); [void]$sb.Append([string]$values.Count); [void]$sb.Append($mk)
            [void]$values.Add(@{ value = $val.ToString(); interp = $false })
            $i = $j; continue
        }
        if ($ch -eq '"') {
            $j = $i + 1; $closed = $false; $interp = $false
            $val = New-Object System.Text.StringBuilder
            while ($j -lt $n) {
                $cj = $Command[$j]
                if ($cj -eq '`') { $interp = $true; if (($j + 1) -lt $n) { [void]$val.Append($Command[$j + 1]); $j += 2; continue }; $j++; continue }
                if ($cj -eq '"') { $closed = $true; $j++; break }
                if ($cj -eq '$') { $interp = $true }
                [void]$val.Append($cj); $j++
            }
            if (-not $closed) { [void]$sb.Append($Command.Substring($i)); break }
            [void]$sb.Append($mk); [void]$sb.Append([string]$values.Count); [void]$sb.Append($mk)
            [void]$values.Add(@{ value = $val.ToString(); interp = $interp })
            $i = $j; continue
        }
        [void]$sb.Append($ch); $i++
    }
    return @{ text = $sb.ToString(); values = $values }
}

function Resolve-EvidenceAsmTerm {
    # One term of an assembly -> its literal value. A masked string marker resolves to its recorded
    # value (an interpolated one is UNREADABLE); chr()/[char] to a character; a variable to its map
    # entry if one exists. ok=$false means "not statically readable" and abandons the chain.
    param([string]$Term, [hashtable]$Vars, $Values)
    $mk = [regex]::Escape([string][char]2)
    if ($Term -match ('^' + $mk + '(\d+)' + $mk + '$')) {
        $idx = [int]$matches[1]
        if ($idx -ge 0 -and $idx -lt $Values.Count) {
            $entry = $Values[$idx]
            if ($entry['interp']) { return @{ ok = $false; value = '' } }
            return @{ ok = $true; value = [string]$entry['value'] }
        }
        return @{ ok = $false; value = '' }
    }
    if ($Term -match '(?i)^chr\(\s*(0x[0-9a-fA-F]+|\d+)\s*\)$') { return (ConvertFrom-EvidenceCharCode -N $matches[1]) }
    if ($Term -match '(?i)^\[char\]\s*(0x[0-9a-fA-F]+|\d+)$')   { return (ConvertFrom-EvidenceCharCode -N $matches[1]) }
    if ($Term -match '^\$([A-Za-z_][A-Za-z0-9_]*)$') {
        $nm = $matches[1]
        if ($Vars.ContainsKey($nm)) { return @{ ok = $true; value = [string]$Vars[$nm] } }
        return @{ ok = $false; value = '' }
    }
    return @{ ok = $false; value = '' }
}

function Resolve-EvidenceAsmConcat {
    # Resolve a '+'-joined chain to its concatenated literal value, but ONLY if the expression is
    # EXACTLY terms joined by '+' (a sentinel-skeleton check), so a partial parse is never trusted.
    param([string]$Expr, [hashtable]$Vars, $Values, [string]$TermRx)
    if (-not $Expr) { return @{ ok = $false; value = '' } }
    $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $sentinel = [string][char]1
    $skeleton = [regex]::Replace($Expr, $TermRx, $sentinel, $ic)
    if ($skeleton -notmatch ('^\s*' + $sentinel + '(?:\s*\+\s*' + $sentinel + ')*\s*$')) {
        return @{ ok = $false; value = '' }
    }
    $terms = [regex]::Matches($Expr, $TermRx, $ic)
    if ($terms.Count -lt 1) { return @{ ok = $false; value = '' } }
    $sb = New-Object System.Text.StringBuilder
    foreach ($m in $terms) {
        $r = Resolve-EvidenceAsmTerm -Term $m.Value -Vars $Vars -Values $Values
        if (-not $r.ok) { return @{ ok = $false; value = '' } }
        [void]$sb.Append($r.value)
    }
    return @{ ok = $true; value = $sb.ToString() }
}

function Resolve-EvidenceAsmJoin {
    # Join-Path / [IO.Path]::Combine over literal-only components -> the path they build (with '/').
    # Bails (returns $null) if any component is not statically readable, so an unknown component
    # cannot manufacture a hit -- `Join-Path $root 'notes.txt'` yields nothing.
    param([string]$ArgText, [hashtable]$Vars, $Values, [string]$TermRx)
    if (-not $ArgText) { return $null }
    $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $a = [regex]::Replace($ArgText, '(?i)-(Path|ChildPath|AdditionalChildPath|Resolve)\b', ' ')
    $terms = [regex]::Matches($a, $TermRx, $ic)
    if ($terms.Count -lt 2) { return $null }
    $vals = New-Object System.Collections.Generic.List[string]
    foreach ($m in $terms) {
        $r = Resolve-EvidenceAsmTerm -Term $m.Value -Vars $Vars -Values $Values
        if (-not $r.ok) { return $null }
        [void]$vals.Add($r.value)
    }
    return ($vals -join '/')
}

function Get-EvidenceAssemblyReadablePaths {
    # Every path the command TEXT statically assembles from literal fragments. Distinct strings; the
    # caller tests each and denies only a hit the RAW text lacks (Test-EvidenceAssembledPathHit).
    param([AllowNull()][string]$Command)
    $paths = New-Object System.Collections.Generic.List[string]
    if (-not $Command) { return $paths.ToArray() }
    $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase

    $masked = ConvertTo-EvidenceAsmMasked -Command $Command
    $mtext  = $masked.text
    $values = $masked.values

    $mk      = [regex]::Escape([string][char]2)
    $markerT = $mk + '\d+' + $mk
    $chrT    = '\bchr\(\s*(?:0x[0-9a-fA-F]+|\d+)\s*\)'
    $charT   = '\[char\]\s*(?:0x[0-9a-fA-F]+|\d+)'
    $varT    = '\$[A-Za-z_][A-Za-z0-9_]*'
    $termRx  = '(?:' + $markerT + '|' + $chrT + '|' + $charT + '|' + $varT + ')'
    $chainRx = $termRx + '(?:\s*\+\s*' + $termRx + ')+'

    # (1) VARIABLE MAP: names assigned a statically-readable expression earlier in the SAME text.
    $vars = @{}
    foreach ($stmt in ($mtext -split '[;\r\n]+')) {
        $m = [regex]::Match($stmt, '^\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*(\+?=)\s*(\S.*)$')
        if (-not $m.Success) { continue }
        $nm = $m.Groups[1].Value; $op = $m.Groups[2].Value; $rhs = $m.Groups[3].Value.Trim()
        $r = Resolve-EvidenceAsmConcat -Expr $rhs -Vars $vars -Values $values -TermRx $termRx
        if (-not $r.ok) { continue }
        if ($op -eq '+=' -and $vars.ContainsKey($nm)) { $vars[$nm] = [string]$vars[$nm] + $r.value }
        else { $vars[$nm] = $r.value }
    }

    # (2) CONCATENATION CHAINS (2+ terms) anywhere in the masked text.
    foreach ($m in [regex]::Matches($mtext, $chainRx, $ic)) {
        $r = Resolve-EvidenceAsmConcat -Expr $m.Value -Vars $vars -Values $values -TermRx $termRx
        if ($r.ok -and $r.value) { [void]$paths.Add($r.value) }
    }

    # (3) Join-Path / [IO.Path]::Combine over literal-only components.
    foreach ($m in [regex]::Matches($mtext, '(?i)\bJoin-Path\b([^;|&\r\n]*)', $ic)) {
        $j = Resolve-EvidenceAsmJoin -ArgText $m.Groups[1].Value -Vars $vars -Values $values -TermRx $termRx
        if ($j) { [void]$paths.Add($j) }
    }
    foreach ($m in [regex]::Matches($mtext, '(?i)\[(?:System\.)?IO\.Path\]::Combine\s*\(([^;\r\n]*)\)', $ic)) {
        $j = Resolve-EvidenceAsmJoin -ArgText $m.Groups[1].Value -Vars $vars -Values $values -TermRx $termRx
        if ($j) { [void]$paths.Add($j) }
    }

    # (4) A LITERAL-ASSIGNED VARIABLE USED DIRECTLY IN A PATH TOKEN ($p/evidence, "$p/evidence").
    #     Substitution is over the RAW text and only for names the map holds, so a message that
    #     merely mentions '+' is untouched (no assignment -> empty map -> no substitution).
    if ($vars.Count -gt 0) {
        $expanded = $Command
        foreach ($nm in @($vars.Keys)) {
            $safe = ([string]$vars[$nm]) -replace '\$', '$$$$'
            $expanded = [regex]::Replace($expanded, ('\$' + [regex]::Escape($nm) + '\b'), $safe)
        }
        if ($expanded -ne $Command) { [void]$paths.Add($expanded) }
    }

    return $paths.ToArray()
}

function Test-EvidenceAssembledPathHit {
    # The protected/parent path the command STATICALLY ASSEMBLES that its RAW text does not already
    # contain, or $null. NEW-HIT ONLY: if the literal is already present, A1's tiers own the verdict.
    param([AllowNull()][string]$Command)
    if (-not $Command) { return $null }
    $prot = if ($script:EvidenceProtectedPaths) { @($script:EvidenceProtectedPaths) } else {
        @('.mission-runtime/evidence', '.mission/evidence', 'tools/framework/hooks',
          'tools/framework/install-evidence-hooks.ps1', 'tools/framework/tests', '.claude/settings.json') }
    $parent = if ($script:EvidenceParentPaths) { @($script:EvidenceParentPaths) } else {
        @('.mission-runtime', '.mission', 'tools/framework', '.claude') }
    $all = @($prot + $parent)

    $rawSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($h in @(Get-EvidencePathHits -Text $Command -Patterns $all)) { [void]$rawSet.Add($h) }

    foreach ($cand in @(Get-EvidenceAssemblyReadablePaths -Command $Command)) {
        if (-not $cand) { continue }
        foreach ($h in @(Get-EvidencePathHits -Text $cand -Patterns $all)) {
            if (-not $rawSet.Contains($h)) { return $h }
        }
    }
    return $null
}

# =================================================================================================
# THE PEER-WORKTREE RULE: A SIBLING WORKTREE HOME IS REFUSED TO A WORKER EXCEPT ITS OWN TREE
# (batch 1 session 5, ITEM 4 -- added by the operator mid-session so batch 2's `git merge main` has it)
# =================================================================================================
# THE ORDER. Batch 2 session 4 is measuring relocating worker worktrees OUT of the repository, to
# <parent-of-repo>/<project>-worktrees/wt-<LAM_DISPATCH>/. Inside the repository every worktree sat
# under `.claude/worktrees/` and the `.claude` PARENT tier covered a peer's tree as a side effect; in a
# sibling home nothing names it, so a worker's OWN tree allows and a PEER's tree is unprotected. The
# rule: a dispatched worker (LAM_DISPATCH set) is refused ANY path resolving under
# <parent-of-repo>/<project>-worktrees/<seg>/ whose <seg> is not its own `wt-<LAM_DISPATCH>`.
#
# THIS IS NOT AN OWN-TREE EXEMPTION AND IS BUILT SO IT CANNOT BECOME IT. An earlier member (a worker's own-worktree
# EXEMPTION) was refuted four times and is OPEN; H-11 stays reserved for it. This rule ADDS DENIALS
# ONLY. It is evaluated AFTER every other rule in Get-EvidenceGuardDecision, so it can only turn an
# allow into a deny: every earlier refusal has already returned, with its own sentence, before this is
# reached -- no hit is suppressed and no later rule is short-circuited. It grants NOTHING to the
# worker's own tree: "own tree allows" means only that THIS rule does not fire there.
#
# THE LEAD'S RULINGS, AS BUILT.
#   1 WHICH REPOSITORY. <parent-of-repo> is the parent of the MAIN repository root, derived WITHOUT
#     running git (a native exe's stderr is fatal in the hook). From an anchor, walk up to the FIRST
#     `.git` entry: a `.git` DIRECTORY -> the directory holding it is the main root; a `.git` FILE
#     reading `gitdir: <X>/.git/worktrees/<name>` -> the main root is <X> (a relative gitdir resolves
#     against the worktree that holds the file); anything else -- a submodule's gitdir, a bare
#     repository's worktree, an unreadable file -- derives NOTHING from that anchor. The anchors are
#     $env:CLAUDE_PROJECT_DIR, the payload cwd and this library's own location, and the containers are
#     their UNION, so a worker that cd's out of every repository is still judged through the others.
#   2 WHICH NAME. The union of the optional operator-supplied name $env:LAM_WORKTREE_HOME_NAME (unset by
#     default; anything but ONE folder name -- a letter or digit, then letters, digits, . _ - -- is ignored)
#     and the derived `<basename of main root>-worktrees`. Denials only, so the union can only refuse more.
#   3 WHICH TREE IS OWN. A segment directly under a container is own iff it EQUALS `wt-<LAM_DISPATCH>`,
#     ordinal-ignore-case, after Win32 normalisation (trailing dots and spaces stripped). EXACT, never a
#     prefix (`wt-D-OWN2` is a peer of `wt-D-OWN`), and nothing else is own: a bare `<LAM_DISPATCH>`
#     folder is not. FORK, fail-closed and beyond the order's text: an entry that is not `wt-`-shaped
#     at all is refused too -- the runner composes only `wt-` names, so it is no worker's tree.
#   4 THE CONTAINER ITSELF is refused (FORK, fail-closed): `rm -rf ..` from a worktree root reaches
#     every peer through it. Its ANCESTORS are NOT covered -- see WHAT IS NOT REACHED.
#   5 TWO MATCHERS, BOTH DENY-ONLY, EACH WITH ITS OWN DOMAIN.
#     RESOLVED -- every ROOTED form the form builder produces WITH the cwd join (dot segments resolved
#       keeping the drive, trailing dots/spaces stripped, an 8.3 alias inverted where the volume can
#       say) that EQUALS a derived container or lies under a non-own segment of one.
#     TEXTUAL -- every form the builder produces WITHOUT the cwd join (the tokens as written, their
#       dot resolutions, Win32 and alias forms) whose text carries `<name>/<seg>` with <seg> not own,
#       WHATEVER ITS PREFIX, so `~/.../<project>-worktrees/wt-Y`, `$HOME/...` and `%USERPROFILE%\...`
#       are refused although the shell computes the prefix. FORK, fail-closed: it also refuses
#       `<prefix>/<name>` at the END of a path token -- the container behind a computed prefix, which
#       is ruling 4's case in ruling 5's clothes. It deliberately does NOT read the cwd-joined forms:
#       those are rooted and belong to the resolved matcher, so each matcher can be shown red alone.
#   6 WIRING. Three deny-only branches at the END of Get-EvidenceGuardDecision: the FILE-TOOL route
#     (every path value at any depth, for the tool names that route already judges), the SHELL route
#     (the command text, raw and with any extended-length prefix stripped), and the PATH-FRAGMENT route
#     (every string Get-EvidenceAssemblyReadablePaths reconstructs). The seat never evaluates any of it.
#
# THE SECOND ORDER (batch 1 session 6, ITEM 1 -- the validator's findings). "Derive
# the worktree home through the guard's existing form builder so an 8.3-spelled mission root (MISSIO~1,
# or an 8.3 alias of <project>) and a mission root that is itself a linked worktree compose the same home H-18 protects;
# cases from the validator's own rows; the $WT/wt-Y bound stays stated." MEASURED before
# this cure, with real `git worktree add` trees: the runner composes <parent as given>\<leaf as
# given>-worktrees\wt-<id> from a Resolve-Path'd root, which KEEPS an 8.3 spelling (MISSIO~1 ->
# MISSIO~1-worktrees) and takes a linked worktree's own leaf (side -> side-worktrees), while git writes
# the LONG main root into every tree's `.git` file -- so rulings 1 and 2 derived only
# <parent>/missionroot-worktrees and <parent>/main-worktrees, and a worker in the composed home was
# ALLOWED `rm -rf ../wt-Y`, a redirect and a Write into a peer, a read of one, and `rm -rf ..`.
# Rulings 7 and 8 add the two homes. They ADD DENIALS ONLY and are consulted strictly AFTER rulings 1-6
# have found nothing (Get-EvidencePeerWorktreeHit), so every hit rulings 1-6 produce is produced first
# and unchanged; they can only turn a miss into a refusal.
#   7 THE HOME THROUGH THE FORM BUILDER (the order). In the RESOLVED matcher, every rooted form the
#     builder already offers (cwd join, dot resolution, Win32 form, 8.3 alias inverted) is read
#     component by component. A component <L>-worktrees (Win32-normalised, the suffix ordinal-ignore-
#     case, <L> non-empty and not a dot segment) is a CANDIDATE home, and <prefix>/<L> is the mission
#     root it would have been composed from. That root goes through the SAME builder functions
#     (ConvertTo-EvidencePeerComparablePath, ConvertTo-EvidenceLongNameForm), and the candidate is a
#     REAL home iff the root, in any of its spellings,
#       (a) EQUALS a derived main root in any of that root's spellings -- the short-name finding: MISSIO~1 inverts to
#           missionroot, an 8.3 alias of <project> to <project>; or
#       (b) is a directory holding a `.git` FILE whose gitdir resolves, by ruling 1's own parse
#           (Get-EvidencePeerWorktreeGitFileMainRoot, which never walks up from the candidate), to a
#           derived main root -- the linked-worktree finding: `side` reads gitdir <main>/.git/worktrees/side.
#     A real home is judged exactly as a ruling-2 container: the home itself refused (ruling 4), a
#     non-own segment under it refused, the own segment not refused by this rule (ruling 3). Never runs
#     git. FILESYSTEM COST, bounded and stated: the rooted form's own 8.3 inversion, exactly the one the
#     resolved matcher already performs (a listing only where the form carries `~<digit>` -- which is also
#     how a home spelled by ITS alias, MISSIO~2, is seen); and, only for a component ending in -worktrees,
#     one listing where the candidate root carries `~<digit>`, one File.Exists and at most one read of a
#     `.git` file, once per candidate per decision (a cache carried in the decision's context).
#   8 THE WORKER'S OWN HOME (FORK, fail-closed, beyond the order's text). The worker's OWN TREE ROOT(S)
#     come from the two anchors the runner and the CLI set -- $env:LAM_WORKTREE and
#     $env:CLAUDE_PROJECT_DIR -- and NEVER from the payload cwd, which the worker chooses: for each, the
#     nearest ancestor-or-self directory whose leaf is exactly wt-<LAM_DISPATCH> (ruling 3's test) and
#     which exists, walked as spelled and 8.3-inverted (Get-EvidenceOwnWorktreeRoots -- the one place
#     any worker-scoped rule reads "the worker's own tree" from). Each own root's PARENT is offered to
#     the resolved matcher as a container, in every spelling, and the parent's LEAF to the textual
#     matcher as a name: whatever the runner spelled -- MISSIO~1-worktrees, side-worktrees -- the home it
#     composed is a home, and its literal name is refused behind a computed prefix too. COST, stated:
#     the parent is taken as a home WHATEVER its leaf, so an own tree placed outside a runner-composed
#     home (the retired `.claude/worktrees` layout) makes that parent, and its generic leaf `worktrees`
#     as a textual name, refused to that worker. A parent with no leaf (a drive root) offers nothing: no
#     home can be composed there, and the runner refuses such a mission root before it composes one.
#
# FAILURE DIRECTION, BOTH HALVES STATED. An exception in the resolved/textual core returns DENY for the
# worker (FORK: a guard that cannot see refuses). The path-fragment branch keeps that detector's own
# doctrine -- a reconstruction error FAILS TO ADD a denial -- because the reconstruction it re-reads is
# already wrapped that way above and an unrelated command must not start refusing on its account.
# Rulings 7 and 8 keep both halves: neither catches, so an exception in either reaches the core's catch
# and refuses; a `.git` file at a candidate that cannot be read derives NOTHING, as ruling 1 treats one.
#
# WHAT IS NOT REACHED (a tripwire, not a boundary).
#   * ANCESTORS OF THE CONTAINER. `rm -rf ../..` from a worktree root names <parent-of-repo> itself,
#     which holds every peer AND the main repository; no rule here names it. (b1s6 item 2: a worker's RECURSIVE
#     DELETE of it is refused by the recursive-delete rule below Get-EvidencePeerWorktreeDenyReason; every other
#     verb on the ancestor is still not reached.)
#   * SPELLINGS THE SHELL OR A TOOL COMPUTES WITHOUT A CONTAINER NAME BEFORE THE PEER: a `..` walk behind
#     a computed prefix (`$PWD/../wt-Y`), a variable holding the container (`$WT/wt-Y`), a container
#     name spelled as an 8.3 alias behind a computed prefix, and a git command that resolves a worktree
#     from its bare name (`git worktree remove wt-Y`).
#   * THE $WT/wt-Y BOUND STAYS, restated because the second order says so: a shell variable holding the
#     home names neither the home nor any component ending in -worktrees, so no ruling -- 7 and 8
#     included -- sees it. H-18 keeps it as a NOT-REACHED row that allows, with a non-destructive verb.
#   * RULING 7 NEEDS THE CANDIDATE ROOT ON THE VOLUME. An 8.3 alias is a filesystem fact: where
#     <prefix>/<L> does not exist (the mission root renamed or removed, or a prefix that exists only once
#     a shell computes it) the alias cannot be inverted and 7(b) finds no `.git` file, so the candidate
#     is no home unless ruling 8 names it.
#   * A TEXTUAL 8.3 OR LINKED-WORKTREE HOME NAME BEHIND A COMPUTED PREFIX (`~/.../MISSIO~1-worktrees/wt-Y`,
#     `$HOME/.../side-worktrees/wt-Y`) is refused ONLY through ruling 8's name, i.e. when LAM_WORKTREE or
#     CLAUDE_PROJECT_DIR places the worker's own tree in that home. Ruling 7 reads ROOTED forms only; a
#     worker whose two anchors place no own tree is judged by rulings 1, 2 and 7 (H-18 measures it).
#   * 7(b) COUNTS ONLY gitdir <main>/.git/worktrees/<name> RESOLVING TO A DERIVED MAIN ROOT: a linked
#     worktree of ANOTHER repository, a submodule-shaped gitdir or a bare repository's worktree makes no
#     home, exactly as ruling 1 derives nothing from them.
#   * LINKS. A junction, symlink or hardlink INSIDE the worker's own tree that points at a peer is
#     judged by its NAME. Creating one whose target names a peer is refused by this rule, because the
#     command names the peer; a link that already exists is not seen through.
#   * A WORKER NO ANCHOR PLACES UNDER A MAIN REPOSITORY: the resolved matcher then has no container to
#     compare against (ruling 7 has no main root either), and only the textual matcher's spellings of
#     LAM_WORKTREE_HOME_NAME, when it is set -- plus ruling 8's own home, where LAM_WORKTREE or
#     CLAUDE_PROJECT_DIR places one -- are refused.
#   * An 8.3 alias of the worker's OWN segment is REFUSED (the alias is not `wt-<LAM_DISPATCH>`), a
#     fail-closed cost; a peer literally named `wt-<LAM_DISPATCH>` plus trailing spaces would be read as
#     own under ruling 3's normalisation (creating one needs a `\\?\` path naming the container).
$script:EvidencePeerWorktreeLibDir      = $PSScriptRoot
$script:EvidencePeerWorktreeConfiguredName = $(if (([string]$env:LAM_WORKTREE_HOME_NAME).Trim() -cmatch '\A[A-Za-z0-9][A-Za-z0-9._-]*\z') { ([string]$env:LAM_WORKTREE_HOME_NAME).Trim() } else { '' })
# RULING 7: the suffix the runner appends to a mission root's leaf (mission-dispatch.ps1's composition).
$script:EvidencePeerWorktreeHomeSuffix  = '-worktrees'

function ConvertTo-EvidencePeerComparablePath {
    <#
      A path as the peer rule compares it: A1's canonical separators, every component's trailing dots
      and spaces stripped (the Win32 form), dot segments resolved with a DRIVE kept as the root
      (`C:/a/../..` stays `C:`), no trailing slash. String-only; never touches the filesystem.
    #>
    param([AllowNull()][string]$Path)
    if (-not $Path) { return '' }
    $t = ConvertTo-CanonicalPathText -Text $Path
    $w = ConvertTo-EvidenceWin32ComponentForm -Path $t
    if ($w) { $t = $w }
    $drive = ''
    $dm = [regex]::Match($t, '^([A-Za-z]:)(/.*)?$')
    if ($dm.Success) {
        $drive = $dm.Groups[1].Value
        $t = if ($dm.Groups[2].Success) { $dm.Groups[2].Value } else { '/' }
    }
    $r = [string](Resolve-DotSegments -Token $t)
    return ($drive + $r.TrimEnd('/'))
}

function Get-EvidencePeerWorktreeGitFileMainRoot {
    <#
      RULING 1's `.git` FILE PARSE, FOR ONE DIRECTORY AND NO OTHER (b1s6 item 1: lifted out of
      Get-EvidencePeerWorktreeMainRoot unchanged so ruling 7(b) reads a candidate root by the SAME parse
      instead of a restated one). -Dir is a comparable path (ConvertTo-EvidencePeerComparablePath). If
      <Dir>/.git is a FILE reading `gitdir: <X>/.git/worktrees/<name>` -- a relative gitdir resolved
      against <Dir> -- the answer is the main root <X>; for anything else (no `.git` file, no gitdir line,
      a submodule's or a bare repository's gitdir, an unreadable file) it is $null. NEVER WALKS UP, never
      runs git, never throws.
    #>
    param([AllowNull()][string]$Dir)
    if (-not $Dir) { return $null }
    try {
        $git = $Dir.Replace('/', '\').TrimEnd('\') + '\.git'
        if (-not [System.IO.File]::Exists($git)) { return $null }
        $gm = [regex]::Match([System.IO.File]::ReadAllText($git), '(?im)^\s*gitdir:\s*(\S.*?)\s*$')
        if (-not $gm.Success) { return $null }
        $gd = ConvertTo-CanonicalPathText -Text $gm.Groups[1].Value
        if (-not (Test-EvidenceRootedPath -Path $gd)) { $gd = $Dir + '/' + $gd }
        $gd = ConvertTo-EvidencePeerComparablePath -Path $gd
        $wm = [regex]::Match($gd, '^(.+)/\.git/worktrees/[^/]+$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($wm.Success) { return $wm.Groups[1].Value }
        return $null
    } catch { return $null }
}

function Get-EvidencePeerWorktreeMainRoot {
    <#
      RULING 1: the MAIN repository root an anchor belongs to, or $null. Walks up to the FIRST `.git`
      entry and stops there. Never runs git, never throws. A `.git` FILE is read by
      Get-EvidencePeerWorktreeGitFileMainRoot, and whatever it answers ends the walk.
    #>
    param([AllowNull()][string]$Anchor)
    if (-not $Anchor) { return $null }
    try {
        $cur = ConvertTo-EvidencePeerComparablePath -Path $Anchor
        if (-not (Test-EvidenceRootedPath -Path ($cur + '/'))) { return $null }
        for ($i = 0; $i -lt 512; $i++) {
            $native = $cur.Replace('/', '\')
            $git = $native.TrimEnd('\') + '\.git'
            if ([System.IO.Directory]::Exists($git)) { return $cur }
            if ([System.IO.File]::Exists($git)) {
                return (Get-EvidencePeerWorktreeGitFileMainRoot -Dir $cur)
            }
            $cut = $cur.LastIndexOf('/')
            if ($cut -lt 0) { return $null }
            $cur = $cur.Substring(0, $cut)
        }
        return $null
    } catch { return $null }
}

function Get-EvidenceOwnWorktreeRoots {
    <#
      RULING 8 (b1s6 item 1): THE WORKER'S OWN TREE ROOT(S). The one place a worker-scoped rule reads
      "this worker's own tree" from.

      THE ANCHORS ARE THE TWO THE WORKER DOES NOT CHOOSE: $env:LAM_WORKTREE (set by the runner,
      mission-dispatch.ps1, to the tree it composed and created) and $env:CLAUDE_PROJECT_DIR (set by the
      CLI to the project it was launched in). NEVER the payload cwd: a worker moves its cwd with one `cd`.

      THE ORDER. For each anchor, in that order: the anchor through ConvertTo-EvidencePeerComparablePath,
      then walked as spelled AND as ConvertTo-EvidenceLongNameForm inverts it; on each walk the NEAREST
      ancestor-or-self directory whose leaf is exactly wt-<LAM_DISPATCH> (Test-EvidencePeerWorktreeSegmentIsOwn:
      Win32-normalised, ordinal-ignore-case, never a prefix) and which EXISTS is an own root.

      RETURNS a flat [string[]] of distinct spellings (ordinal-ignore-case), each comparable: a root as its
      walk spelled it, then that root's long form where the volume inverts an alias. Empty when there is
      no dispatch id or no anchor places a tree -- call it inside @(). A caller compares its own forms
      after the same two builder functions, on both sides.

      COST: the filesystem is read only at a component whose leaf already equals the own segment.
      FAILURE DIRECTION: it does not catch; an exception propagates to the caller, and the peer rule's
      caller turns it into DENY.
    #>
    param([AllowNull()][string]$DispatchId)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $DispatchId) { return $out.ToArray() }
    $own = Get-EvidencePeerWorktreeOwnSegment -DispatchId $DispatchId
    if (-not $own) { return $out.ToArray() }
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    foreach ($anchor in @($env:LAM_WORKTREE, $env:CLAUDE_PROJECT_DIR)) {
        if (-not $anchor) { continue }
        $start = ConvertTo-EvidencePeerComparablePath -Path $anchor
        if (-not (Test-EvidenceRootedPath -Path ($start + '/'))) { continue }
        $walks = New-Object System.Collections.Generic.List[string]
        [void]$walks.Add($start)
        $startLong = ConvertTo-EvidenceLongNameForm -Path $start
        if ($startLong) { [void]$walks.Add((ConvertTo-EvidencePeerComparablePath -Path $startLong)) }
        foreach ($walkFrom in $walks) {
            $cur = $walkFrom
            for ($i = 0; ($i -lt 512) -and $cur; $i++) {
                $cut = $cur.LastIndexOf('/')
                if ($cut -lt 0) { break }
                $leaf = $cur.Substring($cut + 1)
                if ((Test-EvidencePeerWorktreeSegmentIsOwn -Segment $leaf -OwnSegment $own) -and
                    [System.IO.Directory]::Exists($cur.Replace('/', '\'))) {
                    $found = New-Object System.Collections.Generic.List[string]
                    [void]$found.Add($cur)
                    $rootLong = ConvertTo-EvidenceLongNameForm -Path $cur
                    if ($rootLong) { [void]$found.Add((ConvertTo-EvidencePeerComparablePath -Path $rootLong)) }
                    foreach ($spelling in $found) {
                        $dup = $false
                        foreach ($seen in $out) { if ([string]::Equals($seen, $spelling, $ic)) { $dup = $true; break } }
                        if (-not $dup) { [void]$out.Add($spelling) }
                    }
                    break
                }
                $cur = $cur.Substring(0, $cut)
            }
        }
    }
    return $out.ToArray()
}

function Get-EvidencePeerWorktreeContainers {
    <#
      RULINGS 1 AND 2: the union, over the three anchors, of the container PATHS <parent-of-main-root>/
      <LAM_WORKTREE_HOME_NAME, when set> and <parent-of-main-root>/<basename>-worktrees (each also
      from the main root's 8.3-inverted form), and the container NAMES the textual matcher reads -- the
      configured name when set, the derived ones when an anchor derives a root. `paths` and `names`
      are exactly rulings 1 and 2, whatever -DispatchId says.
      RULINGS 7 AND 8 (b1s6 item 1) ride in the same answer under their own keys, so the matchers can
      consult them strictly after rulings 1-6: `roots` (every derived main root, in every spelling, for
      ruling 7), `ownRoots` (Get-EvidenceOwnWorktreeRoots for -DispatchId), `ownHomes` (each own root's
      parent, in every spelling, not already in `paths`), `ownHomeNames` (those parents' leaves, not
      already in `names`), and `cache` (ruling 7's per-decision answers).
      Returns @{ paths; names; roots; ownRoots; ownHomes; ownHomeNames; cache }.
    #>
    param([AllowNull()][string]$Cwd, [AllowNull()][string]$DispatchId)
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    $paths = New-Object System.Collections.Generic.List[string]
    $names = New-Object System.Collections.Generic.List[string]
    $mainRoots = New-Object System.Collections.Generic.List[string]
    if ($script:EvidencePeerWorktreeConfiguredName) { [void]$names.Add($script:EvidencePeerWorktreeConfiguredName) }
    foreach ($anchor in @($env:CLAUDE_PROJECT_DIR, $Cwd, $script:EvidencePeerWorktreeLibDir)) {
        if (-not $anchor) { continue }
        $root = Get-EvidencePeerWorktreeMainRoot -Anchor $anchor
        if (-not $root) { continue }
        $roots = New-Object System.Collections.Generic.List[string]
        [void]$roots.Add($root)
        $long = ConvertTo-EvidenceLongNameForm -Path $root
        if ($long) { [void]$roots.Add((ConvertTo-EvidencePeerComparablePath -Path $long)) }
        foreach ($r in $roots) {
            $knownRoot = $false
            foreach ($m in $mainRoots) { if ([string]::Equals($m, $r, $ic)) { $knownRoot = $true; break } }
            if (-not $knownRoot) { [void]$mainRoots.Add($r) }
            $cut = $r.LastIndexOf('/')
            if ($cut -lt 0) { continue }
            $base = $r.Substring($cut + 1)
            if (-not $base) { continue }
            $derived = $base + '-worktrees'
            $known = $false
            foreach ($n in $names) { if ([string]::Equals($n, $derived, $ic)) { $known = $true; break } }
            if (-not $known) { [void]$names.Add($derived) }
            foreach ($n in @(@($script:EvidencePeerWorktreeConfiguredName, $derived) | Where-Object { $_ })) {
                $c = ConvertTo-EvidencePeerComparablePath -Path ($r.Substring(0, $cut) + '/' + $n)
                $dup = $false
                foreach ($p in $paths) { if ([string]::Equals($p, $c, $ic)) { $dup = $true; break } }
                if (-not $dup) { [void]$paths.Add($c) }
            }
        }
    }
    # RULING 8: the directory holding each own root is a home, in every spelling, and its leaf a name.
    $ownRoots = @(Get-EvidenceOwnWorktreeRoots -DispatchId $DispatchId)
    $ownHomes = New-Object System.Collections.Generic.List[string]
    $ownHomeNames = New-Object System.Collections.Generic.List[string]
    foreach ($ownRoot in $ownRoots) {
        $cut = $ownRoot.LastIndexOf('/')
        if ($cut -le 0) { continue }
        $parent = $ownRoot.Substring(0, $cut)
        $parentCut = $parent.LastIndexOf('/')
        if ($parentCut -lt 0) { continue }
        $parentLeaf = $parent.Substring($parentCut + 1)
        if (-not $parentLeaf) { continue }
        $dup = $false
        foreach ($p in @($paths.ToArray() + $ownHomes.ToArray())) { if ([string]::Equals($p, $parent, $ic)) { $dup = $true; break } }
        if (-not $dup) { [void]$ownHomes.Add($parent) }
        $known = $false
        foreach ($n in @($names.ToArray() + $ownHomeNames.ToArray())) { if ([string]::Equals($n, $parentLeaf, $ic)) { $known = $true; break } }
        if (-not $known) { [void]$ownHomeNames.Add($parentLeaf) }
    }
    return @{ paths = $paths.ToArray(); names = $names.ToArray(); roots = $mainRoots.ToArray(); ownRoots = $ownRoots
              ownHomes = $ownHomes.ToArray(); ownHomeNames = $ownHomeNames.ToArray(); cache = @{} }
}

function Get-EvidencePeerWorktreeOwnSegment {
    # RULING 3: the one segment that is this worker's own -- `wt-<LAM_DISPATCH>`, Win32-normalised.
    param([AllowNull()][string]$DispatchId)
    $s = 'wt-' + [string]$DispatchId
    while ($s.Length -gt 0 -and ($s.EndsWith('.') -or $s.EndsWith(' '))) { $s = $s.Substring(0, $s.Length - 1) }
    return $s
}

function Test-EvidencePeerWorktreeSegmentIsOwn {
    # RULING 3: EXACT equality after Win32 normalisation, ordinal-ignore-case. Never a prefix test.
    param([AllowNull()][string]$Segment, [AllowNull()][string]$OwnSegment)
    if (-not $Segment -or -not $OwnSegment) { return $false }
    $s = $Segment
    while ($s.Length -gt 0 -and ($s.EndsWith('.') -or $s.EndsWith(' '))) { $s = $s.Substring(0, $s.Length - 1) }
    if (-not $s) { return $false }
    return [string]::Equals($s, $OwnSegment, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-EvidencePeerWorktreeForms {
    <#
      The two form lists the matchers read, built ONLY by the library's own form builder: `resolved` WITH
      the cwd join, `textual` WITHOUT it, each over the text and its extended-length-stripped shape.
      -WholePath (the file-tool route) also offers the untokenised path and its cwd join, because a
      file_path containing a space would otherwise be judged only in fragments.
    #>
    param([AllowNull()][string]$Text, [AllowNull()][string]$Cwd, [switch]$WholePath)
    $resolved = New-Object System.Collections.Generic.List[string]
    $textual  = New-Object System.Collections.Generic.List[string]
    if ($Text) {
        $texts = New-Object System.Collections.Generic.List[string]
        [void]$texts.Add($Text)
        $unpref = Remove-EvidenceExtendedLengthPrefix -Text $Text
        if ($unpref) { [void]$texts.Add($unpref) }
        foreach ($t in $texts) {
            foreach ($f in @(Get-EvidencePathForms -Text $t -Cwd $Cwd)) { if ($f) { [void]$resolved.Add($f) } }
            foreach ($f in @(Get-EvidencePathForms -Text $t -Cwd '')) { if ($f) { [void]$textual.Add($f) } }
            if ($WholePath) {
                $canon = ConvertTo-CanonicalPathText -Text $t
                if ($canon) {
                    [void]$resolved.Add($canon)
                    [void]$textual.Add($canon)
                    if ($Cwd -and -not (Test-EvidenceRootedPath -Path $canon)) {
                        [void]$resolved.Add(((ConvertTo-CanonicalPathText -Text $Cwd).TrimEnd('/')) + '/' + $canon)
                    }
                }
            }
        }
    }
    return @{ resolved = $resolved.ToArray(); textual = $textual.ToArray() }
}

function Get-EvidencePeerWorktreeResolvedHit {
    # RULING 5, THE RESOLVED MATCHER: a rooted form equal to a container, or under a non-own segment.
    param([AllowNull()][string[]]$Forms, [AllowNull()][string[]]$Containers, [AllowNull()][string]$OwnSegment)
    if ($null -eq $Containers -or $Containers.Count -eq 0) { return $null }
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    foreach ($f in @($Forms)) {
        if (-not $f) { continue }
        $c0 = ConvertTo-CanonicalPathText -Text $f
        if (-not (Test-EvidenceRootedPath -Path $c0)) { continue }
        $variants = New-Object System.Collections.Generic.List[string]
        $n0 = ConvertTo-EvidencePeerComparablePath -Path $c0
        [void]$variants.Add($n0)
        $long = ConvertTo-EvidenceLongNameForm -Path $n0
        if ($long) { [void]$variants.Add((ConvertTo-EvidencePeerComparablePath -Path $long)) }
        foreach ($n in $variants) {
            foreach ($c in $Containers) {
                if ([string]::Equals($n, $c, $ic)) {
                    return @{ kind = 'container'; form = $f; container = $c; segment = ''; matcher = 'resolved' }
                }
                if ($n.Length -gt ($c.Length + 1) -and $n.StartsWith($c + '/', $ic)) {
                    $seg = $n.Substring($c.Length + 1).Split('/')[0]
                    if (-not (Test-EvidencePeerWorktreeSegmentIsOwn -Segment $seg -OwnSegment $OwnSegment)) {
                        return @{ kind = 'peer'; form = $f; container = $c; segment = $seg; matcher = 'resolved' }
                    }
                }
            }
        }
    }
    return $null
}

function Get-EvidencePeerWorktreeTextualHit {
    # RULING 5, THE TEXTUAL MATCHER: `<name>/<seg>` with <seg> not own, whatever the prefix; and
    # `<prefix>/<name>` ending a path token (the container behind a computed prefix -- the fork).
    param([AllowNull()][string[]]$Forms, [AllowNull()][string[]]$Names, [AllowNull()][string]$OwnSegment)
    if ($null -eq $Names -or $Names.Count -eq 0) { return $null }
    $alt = (@($Names | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $stop = '\s;|&,=<>()"' + [string][char]39 + [string][char]96
    $pairRx = '(?i)(^|[/' + $stop + '])(' + $alt + ')[. ]*/([^/' + $stop + ']*)'
    $bareRx = '(?i)/(' + $alt + ')[. ]*/*(?=$|[' + $stop + '])'
    # TOKEN FORMS FIRST, whole-text forms (which carry whitespace) after: the verdict is the same either
    # way -- any hit refuses -- but the sentence then quotes the path, not the whole command around it.
    $ordered = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($Forms)) { if ($f -and $f -notmatch '\s') { [void]$ordered.Add($f) } }
    foreach ($f in @($Forms)) { if ($f -and $f -match '\s') { [void]$ordered.Add($f) } }
    foreach ($f in $ordered) {
        if (-not $f) { continue }
        $texts = New-Object System.Collections.Generic.List[string]
        $c0 = ConvertTo-CanonicalPathText -Text $f
        [void]$texts.Add($c0)
        $w = ConvertTo-EvidenceWin32ComponentForm -Path $c0
        if ($w) { [void]$texts.Add($w) }
        foreach ($t in $texts) {
            foreach ($m in [regex]::Matches($t, $pairRx)) {
                $seg = $m.Groups[3].Value
                # `.`/`..` right after the name is a walk back OUT; the builder also offers this token
                # dot-resolved, and that form carries the real meaning. An empty segment is the bare
                # container, judged by the rule below.
                if ($seg -eq '' -or $seg -eq '.' -or $seg -eq '..') { continue }
                if (-not (Test-EvidencePeerWorktreeSegmentIsOwn -Segment $seg -OwnSegment $OwnSegment)) {
                    return @{ kind = 'peer'; form = $f; container = $m.Groups[2].Value; segment = $seg; matcher = 'textual' }
                }
            }
            $bm = [regex]::Match($t, $bareRx)
            if ($bm.Success) {
                return @{ kind = 'container'; form = $f; container = $bm.Groups[1].Value; segment = ''; matcher = 'textual' }
            }
        }
    }
    return $null
}

function Get-EvidencePeerWorktreeCandidateRootDerivation {
    <#
      RULING 7's TEST FOR ONE CANDIDATE MISSION ROOT <prefix>/<L> (the root a `<L>-worktrees` home would
      have been composed from). Answers 'main-root-spelling' when the root, in any of its spellings,
      EQUALS a derived main root in any of that root's spellings (7a); 'linked-worktree-root' when it is
      a directory holding a `.git` FILE whose gitdir resolves, by Get-EvidencePeerWorktreeGitFileMainRoot
      and without walking up, to one (7b); '' otherwise. Both sides go through the form builder's own
      ConvertTo-EvidencePeerComparablePath and ConvertTo-EvidenceLongNameForm. Never runs git. -Cache (a
      hashtable, the decision context's) holds each answer so a candidate costs the filesystem once.
    #>
    param([AllowNull()][string]$CandidateRoot, [AllowNull()][string[]]$MainRoots, $Cache = $null)
    if (-not $CandidateRoot -or $null -eq $MainRoots -or $MainRoots.Count -eq 0) { return '' }
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    $cand = ConvertTo-EvidencePeerComparablePath -Path $CandidateRoot
    if (-not $cand) { return '' }
    $cacheKey = $cand.ToUpperInvariant()
    if ($null -ne $Cache -and $Cache.ContainsKey($cacheKey)) { return [string]$Cache[$cacheKey] }
    $answer = ''
    $spellings = New-Object System.Collections.Generic.List[string]
    [void]$spellings.Add($cand)
    $candLong = ConvertTo-EvidenceLongNameForm -Path $cand
    if ($candLong) { [void]$spellings.Add((ConvertTo-EvidencePeerComparablePath -Path $candLong)) }
    foreach ($s in $spellings) {
        foreach ($mr in $MainRoots) { if ($mr -and [string]::Equals($s, $mr, $ic)) { $answer = 'main-root-spelling'; break } }
        if ($answer) { break }
    }
    if (-not $answer) {
        $linkedMain = Get-EvidencePeerWorktreeGitFileMainRoot -Dir $cand
        if ($linkedMain) {
            $linkedSpellings = New-Object System.Collections.Generic.List[string]
            [void]$linkedSpellings.Add($linkedMain)
            $linkedLong = ConvertTo-EvidenceLongNameForm -Path $linkedMain
            if ($linkedLong) { [void]$linkedSpellings.Add((ConvertTo-EvidencePeerComparablePath -Path $linkedLong)) }
            foreach ($s in $linkedSpellings) {
                foreach ($mr in $MainRoots) { if ($mr -and [string]::Equals($s, $mr, $ic)) { $answer = 'linked-worktree-root'; break } }
                if ($answer) { break }
            }
        }
    }
    if ($null -ne $Cache) { $Cache[$cacheKey] = $answer }
    return $answer
}

function Get-EvidencePeerWorktreeCandidateHomeHit {
    <#
      RULING 7, THE HOME THROUGH THE FORM BUILDER: over every ROOTED form the resolved matcher reads (the
      same forms, the same comparable and long variants), each component <L>-worktrees is a candidate
      home; where Get-EvidencePeerWorktreeCandidateRootDerivation calls <prefix>/<L> a mission root, the
      home is judged as a container is -- the form EQUALS the home (it ends there), or the segment after
      the home is not own. Every component is read, so an own segment under one home does not hide a
      peer under a later one. Returns the first hit, carrying `derivation`, or $null.
    #>
    param([AllowNull()][string[]]$Forms, [AllowNull()][string[]]$MainRoots, [AllowNull()][string]$OwnSegment, $Cache = $null)
    if ($null -eq $MainRoots -or $MainRoots.Count -eq 0) { return $null }
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    $suffix = $script:EvidencePeerWorktreeHomeSuffix
    foreach ($f in @($Forms)) {
        if (-not $f) { continue }
        $c0 = ConvertTo-CanonicalPathText -Text $f
        if (-not (Test-EvidenceRootedPath -Path $c0)) { continue }
        $variants = New-Object System.Collections.Generic.List[string]
        $n0 = ConvertTo-EvidencePeerComparablePath -Path $c0
        [void]$variants.Add($n0)
        $long = ConvertTo-EvidenceLongNameForm -Path $n0
        if ($long) { [void]$variants.Add((ConvertTo-EvidencePeerComparablePath -Path $long)) }
        foreach ($n in $variants) {
            $parts = $n.Split('/')
            for ($k = 1; $k -lt $parts.Length; $k++) {
                $comp = $parts[$k]
                if ($comp.Length -le $suffix.Length -or -not $comp.EndsWith($suffix, $ic)) { continue }
                $leaf = $comp.Substring(0, $comp.Length - $suffix.Length)
                if ($leaf -eq '.' -or $leaf -eq '..') { continue }
                $prefix = [string]::Join('/', $parts, 0, $k)
                $derivation = Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot ($prefix + '/' + $leaf) -MainRoots $MainRoots -Cache $Cache
                if (-not $derivation) { continue }
                $homePath = $prefix + '/' + $comp
                if ($k -eq ($parts.Length - 1)) {
                    return @{ kind = 'container'; form = $f; container = $homePath; segment = ''; matcher = 'resolved'; derivation = $derivation }
                }
                $seg = $parts[$k + 1]
                if (-not (Test-EvidencePeerWorktreeSegmentIsOwn -Segment $seg -OwnSegment $OwnSegment)) {
                    return @{ kind = 'peer'; form = $f; container = $homePath; segment = $seg; matcher = 'resolved'; derivation = $derivation }
                }
            }
        }
    }
    return $null
}

function Get-EvidencePeerWorktreeHit {
    <#
      THE PEER-WORKTREE PREDICATE: the first hit of the resolved matcher, then the textual one, over the
      forms of ONE text, or $null. -Context is Get-EvidencePeerWorktreeContainers' answer, passed in so
      one decision derives the containers once. Deny-only by construction: a hit can only refuse.
      THE ORDER (b1s6 item 1): rulings 1-6 first and exactly as before -- the resolved matcher over
      `paths`, the textual matcher over `names`; only when both miss, ruling 7 (candidate homes over the
      same resolved forms), then ruling 8 (the resolved matcher over `ownHomes`, the textual matcher over
      `ownHomeNames`). A hit from 7 or 8 carries `derivation`; a hit from 1-6 is unchanged.
    #>
    param([AllowNull()][string]$Text, [AllowNull()][string]$Cwd, [AllowNull()][string]$DispatchId,
          $Context = $null, [switch]$WholePath)
    if (-not $Text) { return $null }
    if ($null -eq $Context) { $Context = Get-EvidencePeerWorktreeContainers -Cwd $Cwd -DispatchId $DispatchId }
    $own = Get-EvidencePeerWorktreeOwnSegment -DispatchId $DispatchId
    $forms = Get-EvidencePeerWorktreeForms -Text $Text -Cwd $Cwd -WholePath:$WholePath
    $hit = Get-EvidencePeerWorktreeResolvedHit -Forms $forms.resolved -Containers $Context.paths -OwnSegment $own
    if ($hit) { return $hit }
    $hit = Get-EvidencePeerWorktreeTextualHit -Forms $forms.textual -Names $Context.names -OwnSegment $own
    if ($hit) { return $hit }
    # BY KEY: a context built without rulings 7 and 8 (a caller's own) carries none of these keys, and
    # under strict mode reading a missing one as a property throws.
    $isDict = ($Context -is [System.Collections.IDictionary])
    $ctxRoots        = if ($isDict -and $Context.Contains('roots'))        { [string[]]$Context['roots'] }        else { $null }
    $ctxCache        = if ($isDict -and $Context.Contains('cache'))        { $Context['cache'] }                  else { $null }
    $ctxOwnHomes     = if ($isDict -and $Context.Contains('ownHomes'))     { [string[]]$Context['ownHomes'] }     else { $null }
    $ctxOwnHomeNames = if ($isDict -and $Context.Contains('ownHomeNames')) { [string[]]$Context['ownHomeNames'] } else { $null }
    $hit = Get-EvidencePeerWorktreeCandidateHomeHit -Forms $forms.resolved -MainRoots $ctxRoots -OwnSegment $own -Cache $ctxCache
    if ($hit) { return $hit }
    $hit = Get-EvidencePeerWorktreeResolvedHit -Forms $forms.resolved -Containers $ctxOwnHomes -OwnSegment $own
    if ($hit) { $hit['derivation'] = 'own-tree-home'; return $hit }
    $hit = Get-EvidencePeerWorktreeTextualHit -Forms $forms.textual -Names $ctxOwnHomeNames -OwnSegment $own
    if ($hit) { $hit['derivation'] = 'own-tree-home-name'; return $hit }
    return $null
}

function Test-EvidencePeerWorktreePath {
    # [bool] form of the predicate for a caller that is not the decision function. No dispatch id is
    # no worker, and the rule does not apply -- exactly as the decision function gates it.
    param([AllowNull()][string]$Text, [AllowNull()][string]$Cwd, [AllowNull()][string]$DispatchId, [switch]$WholePath)
    if (-not $DispatchId) { return $false }
    return ($null -ne (Get-EvidencePeerWorktreeHit -Text $Text -Cwd $Cwd -DispatchId $DispatchId -WholePath:$WholePath))
}

function Get-EvidencePeerWorktreeDenyReason {
    # The sentence names the peer path, the worker id, the rule, the matcher and the route -- and, for a
    # home rulings 7 and 8 found (b1s6 item 1), how that home was derived. It no longer says a home is
    # only a configured name or <repo>-worktrees: it names every derivation the rule now reads.
    param($Hit, [AllowNull()][string]$DispatchId, [AllowNull()][string]$Route)
    $own = Get-EvidencePeerWorktreeOwnSegment -DispatchId $DispatchId
    $what = if ($Hit.kind -eq 'container') {
        "IS the sibling worktree home '$($Hit.container)' itself -- every peer's tree lies under it, so an act on it (rm -rf .. from a worktree root) reaches all of them at once"
    } elseif ($Hit.matcher -eq 'resolved') {
        "resolves inside '$($Hit.container)/$($Hit.segment)', a sibling worktree that is not this worker's own '$($Hit.container)/$own'"
    } else {
        "carries '$($Hit.container)/$($Hit.segment)', a sibling worktree segment that is not this worker's own '$own', whatever the prefix before it resolves to"
    }
    # READ BY KEY, NOT BY PROPERTY: under the strict mode this library runs in, `$Hit.derivation` on a hit
    # from rulings 1-6 (which carries no such key) THROWS -- measured while building this, where it turned
    # every rulings-1-6 refusal into an exception outside the core's catch.
    $derivationKey = if (($Hit -is [System.Collections.IDictionary]) -and $Hit.Contains('derivation')) { [string]$Hit['derivation'] } else { '' }
    $derivationText = switch ($derivationKey) {
        'main-root-spelling'   { 'a <name>-worktrees whose <name> is the main repository root under another spelling (an 8.3 alias)' }
        'linked-worktree-root' { 'a <name>-worktrees whose <name> is a linked worktree of the main repository' }
        'own-tree-home'        { "the directory holding this worker's own wt-<LAM_DISPATCH> tree, from LAM_WORKTREE or CLAUDE_PROJECT_DIR" }
        'own-tree-home-name'   { "the NAME of the directory holding this worker's own wt-<LAM_DISPATCH> tree, from LAM_WORKTREE or CLAUDE_PROJECT_DIR" }
        default                { '' }
    }
    $provenance = if ($derivationText) { "b1s6 item 1, $($Hit.matcher) matcher, home derived as $derivationText" } else { "b1s5 item 4, $($Hit.matcher) matcher" }
    return ("PEER WORKTREE: the $Route path '$($Hit.form)' $what, and this session is dispatched worker '$DispatchId'. " +
            "A dispatched worker is refused every path under a sibling worktree home except its own wt-<LAM_DISPATCH> tree, and an entry there that is not wt-shaped is no worker's tree and is refused too. " +
            "A home is <parent-of-repo>/<repo>-worktrees/$(if ($script:EvidencePeerWorktreeConfiguredName) { " or <parent-of-repo>/$($script:EvidencePeerWorktreeConfiguredName)/ (from LAM_WORKTREE_HOME_NAME)" } else { ' (no LAM_WORKTREE_HOME_NAME in effect)' }) for a main repository an anchor derives, a <name>-worktrees/ whose <name> is that repository under another spelling or a linked worktree of it, or the directory holding this worker's own tree " +
            "($provenance). The rule only ADDS denials -- it runs after every other rule and grants nothing to the worker's own tree. A tripwire, not a boundary: a link, or a path the shell computes without naming the peer, is not seen")
}

# =================================================================================================
# THE WORKER RECURSIVE-DELETE RULE: A DISPATCHED WORKER'S RECURSIVE DELETE MUST NAME STATIC TARGETS
# STRICTLY INSIDE ITS OWN TREE (batch 1 session 6, ITEM 2 -- the own-tree destructive verbs)
# =================================================================================================
# THE EXPOSURE. Worker worktrees moved from <repo>/.claude/worktrees/
# wt-<id> to <parent>/<leaf>-worktrees/wt-<id>. Inside `.claude` the guard's PARENT tier fired on the
# cwd-joined form of every token, so a worker's `rm -rf $HOME`, `rm -rf ~`, `rm -rf $(echo ../..)`,
# `rm -rf .` at its tree root and `rm -rf <own tree>` were refused AS A SIDE EFFECT. At the sibling home
# nothing refused them; worker.json's `Bash(*rm -rf*)` permission rule is not this guard, and neither
# `rm -r -f` nor `Remove-Item -Recurse` matches it. `rm -rf ../..` from a tree root (the home's
# ancestors: every peer and the main repository) was the peer rule's stated bound.
#
# THE ORDER (operator, verbatim in substance). "Add a worker-scoped rule refusing a recursive delete
# (rm -r/-rf/-fr in any spelling, Remove-Item -Recurse, rmdir /s) whose target is uncomputable (shell
# expansion, ~, %VAR%), outside the worker's own tree, or the tree root itself; ordinary deletes inside
# the tree allow; the seat unaffected; cases both ways including `rm -r -f`." It ADDS REFUSALS ONLY.
#
# THIS IS NOT AN OWN-TREE EXEMPTION AND IT GRANTS THE OWN TREE NOTHING. An ordinary delete inside the own tree
# was allowed before this rule existed; "allowed" here means only that THIS rule does not fire. H-11
# stays reserved for the earlier own-worktree exemption.
#
# THE LEAD'S RULINGS, AS BUILT.
#   D1 SCOPE. Worker only (Test-EvidenceDispatchedWorker): the seat never evaluates any of it, so every
#      seat verdict AND reason is the base library's by construction. One deny-only branch at the END of
#      Get-EvidenceGuardDecision, after the peer-worktree branches, for every tool whose input carries a
#      command ($cmdText). It can only turn an allow into a deny: every earlier refusal has returned with
#      its own sentence before this is reached, so a peer-rule refusal keeps the peer sentence.
#   D2 WHAT A RECURSIVE DELETE IS (Get-EvidenceRecursiveDeleteInvocation). The command goes through the
#      library's own segmenter -- Remove-EvidenceHeredocBodies, Split-CommandSegments, then the single-`&`
#      and parenthesis splits exactly as Test-EvidenceGateToolMutation cuts them -- in THREE token variants:
#      quotes spaced and quotes deleted (the two that predicate reads) and quotes spaced with backticks
#      KEPT (FORK F2); each also with bash line continuations joined. ANY variant that refuses, refuses.
#      A token is in COMMAND POSITION when it is the first of its segment; when a LEAD in command position
#      precedes it (FORK F1); when a token starting with `{` or an assignment `=` precedes it anywhere; or
#      after a NAME=value prefix. Its NAMES (Get-EvidenceRecursiveDeleteVerbNames) are its leaf after the
#      last / or \ and the leaf of the token with the \ and ^ escapes removed, braces trimmed, the text
#      after a last `=` too, lowercased, without .exe -- so /usr/bin/rm, \rm, r\m, rm.exe, C:\x\rm.exe,
#      {rm and Microsoft.PowerShell.Management\Remove-Item are the verbs they run as. SPELLINGS COVERED:
#        (a) rm with ANY single-dash option token (before `--`; after the operands too, as GNU permutes
#            them) whose letters carry r or R -- -r -R -rf -fr -Rf -rfv -vfR, and -r -f / -f -r as
#            separate tokens -- or a long option that is a prefix of --recursive (--r .. --recursive);
#        (b) Remove-Item (any case, module-qualified) and its aliases rm, ri, del, erase, rd, rmdir with a
#            parameter that is a prefix of -Recurse (-r .. -Recurse), attached forms (-Recurse:$true,
#            -r:1) included;
#        (c) rmdir, rd, del, erase with a cmd switch cluster carrying /s (/s /S /s/q /q/S, any order, and
#            attached to the verb: rd/s/q);
#        and, as POSSIBLY recursive because the shell decides the flags: an rm or Remove-Item-family verb
#        given an option token carrying $ or a backtick (rm -$f x), or a PowerShell splat (Remove-Item @p).
#      LEADS whose tail is command position: sudo doas command builtin exec env nice nohup time timeout
#      xargs busybox stdbuf ionice setsid find (so find -exec/-execdir/-ok) bash sh zsh dash ksh cmd
#      powershell pwsh wsl call start Start-Process Start-Job Invoke-Expression iex Invoke-Command icm
#      ForEach-Object % Where-Object `.` eval watch flock strace chroot script su runuser unshare, and the
#      keywords if then else elif elseif do while until try finally !. An interpreter's quoted payload is
#      inlined by the quote variants.
#   D3 THE TARGETS (Get-EvidenceRecursiveDeleteTargetFinding). The OPERANDS are every token after the verb
#      to the end of its segment that is not an option, a redirection (with its separated target), a lone
#      `}` or -- for the cmd names -- a single-letter switch cluster; an attached PowerShell value
#      (-Path:..) is an operand unless it is a boolean on a name only a switch parameter abbreviates; a
#      trailing `}` closing a block is trimmed (its parent is the same, so the verdict can only tighten);
#      after `--` every token is one. The invocation is REFUSED when, in variant, segment and operand order:
#      UNCOMPUTABLE -- an operand carries $, a backtick, a brace, * ? [ or ], %, !, < or >, a leading @, a ~
#        at its start or after = : or ,, or a colon other than a leading drive letter's before a separator
#        (a provider or drive qualifier, a drive-relative C:x); an option carries $ or a backtick; there is
#        NO static target (a pipeline, xargs, find -exec -- whose `{}` is itself uncomputable -- or a $( )
#        the segmenter split away); the argument list CONTINUES INTO A SUB-EXPRESSION (the segment is cut
#        by an opening parenthesis: Remove-Item -Recurse (Get-Item ..)); or an operand is RELATIVE while a
#        base it may be relative to is unknown -- no payload cwd, a directory change earlier in the same
#        command the guard cannot compute (FORK F3), or a lead option that moves the directory (env -C,
#        sudo -D, --chdir, --directory, --cwd, --workdir, -WorkingDirectory, -wd, /d).
#      OUTSIDE -- no own tree root derives (Get-EvidenceOwnWorktreeRoots, the peer rule's ruling 8: from
#        LAM_WORKTREE and CLAUDE_PROJECT_DIR ONLY, never from the payload cwd, which the worker controls --
#        a stale same-id tree elsewhere would otherwise be deletable), or ANY rooted form the library's
#        form builder produces for the operand (Get-EvidencePathForms: cwd-joined from every possible base,
#        dot segments resolved the cured AND legacy ways, Win32-normalised, 8.3 alias inverted) is, in
#        every one of its spellings (ConvertTo-EvidencePeerComparablePath and its
#        ConvertTo-EvidenceLongNameForm), not STRICTLY under an own-root spelling -- ordinal-ignore-case,
#        only at a `/` boundary, never a bare string prefix. Fail-closed: EVERY form must be inside.
#      ROOT -- a form equals an own root: rm -rf . at the root, rm -rf <own tree>, rm -rf ../wt-<own id>.
#      The first failing form in the builder's own order names the condition, so a cured `..` resolution
#      speaks before its legacy twin. A static operand strictly inside the own tree from every possible
#      base is not judged here at all.
#   D4 THE SENTENCE (Get-EvidenceRecursiveDeleteDenyReason) names the verb as spelled, the target, which
#      condition fired and why, the worker id and the own root(s) derived, and says it is a tripwire,
#      worker-scoped and deny-only.
#   D5 FAILURE DIRECTION, BOTH HALVES (FORK F4). An exception while RECOGNISING or EVALUATING, once the
#      pre-screen has matched, returns DENY for the worker: a guard that cannot see refuses. An exception
#      in the PRE-SCREEN, or a command the pre-screen does not match, adds nothing -- so no command that
#      names no delete verb can be refused on this rule's account.
#
# THE FORKS, EACH FAIL-CLOSED, EACH WITH ITS COST.
#   F1 A LEAD MAKES ITS WHOLE TAIL COMMAND POSITION, instead of parsing each lead's own options (nice -n 10,
#      timeout 5, sudo -u root, xargs -I {} all put the verb past a value). Cost: a verb word a lead merely
#      passes as data -- bash -c "echo rm -rf .", xargs echo rm -rf x, a `{` in an echoed string -- is
#      judged as a delete.
#   F2 A THIRD, BACKTICK-KEEPING VARIANT instead of the raw-command backtick test the gate predicate uses.
#      Quote-stripping deletes backticks, so a command substitution in backticks reads as a static word.
#      A substitution's opening backtick always lies in the argument list it feeds, so the kept variant sees
#      it in the invocation's own segment. Cost: none beyond the uncomputable rule -- and unlike the raw
#      test, a PowerShell escape in ANOTHER segment does not refuse this delete.
#   F3 A LITERAL DIRECTORY CHANGE IS RESOLVED, AS A SET OF POSSIBLE BASES (Add-EvidenceRecursiveDeleteBase).
#      `cd src && rm -rf build` is ordinary work, so cd/chdir/pushd/Set-Location/sl/Push-Location with ONE
#      static argument (flags -L -P -Path -LiteralPath only) resolves -- but a change can fail and `;` or a
#      newline still runs the delete, so each change ADDS its destination to the bases instead of replacing
#      the base, and every operand must be inside from EVERY base. A change the guard cannot compute (an
#      uncomputable or missing argument, `cd -`, a bare cd, popd, Pop-Location, another flag, two arguments)
#      adds an UNKNOWN base, and every later relative operand is uncomputable. Beyond 32 bases the set gains
#      an unknown. A lead option that moves the directory adds an unknown for the delete it leads. Cost:
#      `cd .. && rm -rf x` is judged from the directory before the change as well as after it.
#   F4 THE PRE-SCREEN (Test-EvidenceRecursiveDeleteMentioned) CANNOT MISS WHAT RECOGNITION HITS: a delete
#      verb word bounded by non-alphanumerics, in the command with quotes deleted or spaced, then with \ and
#      ^ removed or \ and / spaced, continuations joined or not. Cost: when recognition throws, a command
#      that merely names a delete verb word is refused.
#   F5 NO VALUE-TAKING PARAMETER IS SKIPPED. Every non-option token is an operand, so -Filter *.tmp and
#      -ErrorAction SilentlyContinue are judged as targets (a wildcard refuses; a word is a relative path,
#      inside from a cwd inside the tree). Skipping a value slot after a misread switch would hide a target.
#   F6 THE ORDER'S "ANY SPELLING" IS READ WIDE: any single-dash token carrying r or R makes rm recursive, so
#      PowerShell's rm -Force <target> is judged too; and in the unjoined variant a bash continuation's lone
#      `\` is an operand naming the drive root, so a line-continued recursive delete refuses.
#
# WHAT IS NOT REACHED (a tripwire, not a boundary).
#   * LINKS inside the own tree are judged by NAME: a junction or symlink to a peer or an ancestor is a static
#     inside target, and Windows PowerShell 5.1's Remove-Item -Recurse on a junction deletes through it.
#   * A TARGET OR FLAG SET THE SHELL COMPUTES FROM TEXT CARRYING NONE OF THE LISTED CHARACTERS: an alias or
#     function defined in an earlier call (alias x='rm -rf ..'), a script file run by path, and an unquoted
#     `rm $X` whose value supplies -rf -- a delete whose recursion flag is not visible is not recognised,
#     and only a recognised delete has its $ operands judged uncomputable.
#   * DELETES WITHOUT THESE VERBS: find -delete, git clean, git rm -r, shutil.rmtree,
#     [IO.Directory]::Delete(p, $true), robocopy /MIR or /PURGE, rsync --delete, rimraf, Get-ChildItem |
#     Remove-Item without -Recurse, and any interpreter that deletes without spelling one of them.
#   * A VERB SPELLED BEYOND THE NORMALISATION: an escape inside a backslash-qualified leaf (C:\x\r^m.exe), a
#     verb held in a variable (& $v -rf ..), a verb whose name a continuation splits across a backslash path.
#   * A HEREDOC BODY FED TO AN INTERPRETER (bash <<EOF ... EOF): the segmenter drops heredoc bodies as data,
#     exactly as the gate predicate does, so a delete spelled only inside one is not read.
#   * A LEAD NOT LISTED (parallel, ssh, nsenter ...), and a lead that moves the directory through an
#     option not listed above.
#   * The seat: never evaluated (D1).
$script:EvidenceRecursiveDeleteVerbWords    = @('rm', 'rmdir', 'rd', 'del', 'erase', 'ri', 'remove-item')
$script:EvidenceRecursiveDeletePsNames      = @('remove-item', 'rm', 'ri', 'del', 'erase', 'rd', 'rmdir')
$script:EvidenceRecursiveDeleteCmdNames     = @('rmdir', 'rd', 'del', 'erase')
$script:EvidenceRecursiveDeleteLeads        = @('sudo', 'doas', 'command', 'builtin', 'exec', 'env', 'nice', 'nohup',
    'time', 'timeout', 'xargs', 'busybox', 'stdbuf', 'ionice', 'setsid', 'find', 'bash', 'sh', 'zsh', 'dash', 'ksh',
    'cmd', 'powershell', 'pwsh', 'wsl', 'call', 'start', 'start-process', 'start-job', 'invoke-expression', 'iex',
    'invoke-command', 'icm', 'foreach-object', '%', 'where-object', '.', 'eval', 'watch', 'flock', 'strace', 'chroot', 'script',
    'su', 'runuser', 'unshare',
    'if', 'then', 'else', 'elif', 'elseif', 'do', 'while', 'until', 'try', 'finally', '!')
$script:EvidenceRecursiveDeletePopVerbs     = @('popd', 'pop-location')
$script:EvidenceRecursiveDeleteChdirFlags   = @('-l', '-p', '-path', '-literalpath')
$script:EvidenceRecursiveDeleteSwitchParams = @('recurse', 'force', 'whatif', 'confirm', 'verbose', 'debug')
$script:EvidenceRecursiveDeleteValueParams  = @('path', 'literalpath', 'pspath', 'lp', 'filter', 'include', 'exclude',
    'credential', 'stream', 'erroraction', 'warningaction', 'informationaction', 'errorvariable', 'warningvariable',
    'informationvariable', 'outvariable', 'outbuffer', 'pipelinevariable', 'progressaction')
$script:EvidenceRecursiveDeleteMaxBases     = 32
# A REDIRECTION TOKEN: an optional descriptor, the operator, and an attached target (empty when separated).
$script:EvidenceRecursiveDeleteRedirection  = '^(?:\d+|\*)?(?:>>|>\||>|<<<|<<|<)(.*)$'
# A CMD SWITCH CLUSTER: single-letter switches, each with an optional :value (/s /q /S/Q /A:H).
$script:EvidenceRecursiveDeleteCmdSwitches  = '^(?:/[A-Za-z?](?::[^/\s]*)?)+$'

function Test-EvidenceRecursiveDeleteMentioned {
    <#
      FORK F4, THE PRE-SCREEN: does the command name a delete verb word ANYWHERE, in any of the spellings
      recognition can read? A superset of recognition by construction -- a recognised verb is a token leaf
      bounded by whitespace, a segment separator, a quote position, / or \, a brace or `=`, and every one of
      those is a non-alphanumeric boundary in one of the eight texts read here. $false means this rule has
      nothing to judge; its caller treats an exception here as $false (adds no denial).
    #>
    param([AllowNull()][string]$Command)
    if (-not $Command) { return $false }
    $words = '(?:' + ((@($script:EvidenceRecursiveDeleteVerbWords) | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
    $rx = New-Object System.Text.RegularExpressions.Regex(('(?<![A-Za-z0-9])' + $words + '(?![A-Za-z0-9])'),
                                                         [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($text in @($Command, ($Command -replace '\\\r?\n', ''))) {
        foreach ($quoted in @(($text -replace $script:EvidenceQuoteChars, ''), ($text -replace $script:EvidenceQuoteChars, ' '))) {
            if ($rx.IsMatch(($quoted -replace '[\\^]', ''))) { return $true }
            if ($rx.IsMatch(($quoted -replace '[\\/]', ' '))) { return $true }
        }
    }
    return $false
}

function Get-EvidenceRecursiveDeleteVerbNames {
    <#
      D2: the names one token can run as, lowercased, without a trailing .exe -- its leaf after the last /
      or \, and the same for the token with the shell escapes \ and ^ removed; each with braces trimmed and
      also as the text after a last `=` (a PowerShell `$x=Remove-Item`). A cmd verb carrying its switches
      (rd/s/q) is also its head before the first /. Never throws on a string.
    #>
    param([AllowNull()][string]$Token)
    $names = New-Object System.Collections.Generic.List[string]
    if (-not $Token) { return $names.ToArray() }
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($spelled in @($Token, ($Token -replace '[\\^]', ''))) {
        $trimmed = $spelled.Trim([char[]]@([char]123, [char]125))
        if (-not $trimmed) { continue }
        $cut = $trimmed.LastIndexOfAny([char[]]@([char]47, [char]92))
        $leaf = if ($cut -ge 0) { $trimmed.Substring($cut + 1) } else { $trimmed }
        [void]$candidates.Add($leaf)
        $eq = $leaf.LastIndexOf('=')
        if ($eq -ge 0) { [void]$candidates.Add($leaf.Substring($eq + 1)) }
        $head = [regex]::Match($trimmed, '^([A-Za-z]+)(?:/[A-Za-z?](?::[^/\s]*)?)+$')
        if ($head.Success) { [void]$candidates.Add($head.Groups[1].Value) }
    }
    foreach ($c in $candidates) {
        $n = $c.ToLowerInvariant()
        if ($n.EndsWith('.exe')) { $n = $n.Substring(0, $n.Length - 4) }
        if ($n -and -not $names.Contains($n)) { [void]$names.Add($n) }
    }
    return $names.ToArray()
}

function Get-EvidenceRecursiveDeleteSegments {
    <#
      D2's SEGMENTATION, in every variant this rule judges. Returns one entry per variant:
      @{ variant = <name>; segments = @( @{ tokens = [string[]]; openAfter = [bool] } ... ) }, segments in
      command order. `openAfter` is true when the parenthesis split cut the segment at an OPENING
      parenthesis -- the pieces are the ones `-split '[()]+'` yields; the split is written with a capture
      only so the separator that ended each piece can be read.
    #>
    param([AllowNull()][string]$Command)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not $Command) { return $out.ToArray() }
    $stripped = Remove-EvidenceHeredocBodies -Text $Command
    $texts = New-Object System.Collections.Generic.List[object]
    [void]$texts.Add(@{ name = ''; text = $stripped })
    $joined = $stripped -replace '\\\r?\n', ''
    if ($joined -ne $stripped) { [void]$texts.Add(@{ name = ', continuations joined'; text = $joined }) }
    foreach ($t in $texts) {
        $variants = @(
            @{ name = ('quotes spaced' + $t['name']);  text = ($t['text'] -replace $script:EvidenceQuoteChars, ' ') },
            @{ name = ('quotes deleted' + $t['name']); text = ($t['text'] -replace $script:EvidenceQuoteChars, '') },
            @{ name = ('backticks kept' + $t['name']); text = ($t['text'] -replace '["'']', ' ') }
        )
        foreach ($v in $variants) {
            $segs = New-Object System.Collections.Generic.List[object]
            foreach ($outer in @(Split-CommandSegments -Command $v['text'])) {
                foreach ($mid in ($outer -split '&')) {
                    $parts = [regex]::Split($mid, '([()]+)')
                    for ($p = 0; $p -lt $parts.Count; $p += 2) {
                        $inner = $parts[$p]
                        if (-not $inner.Trim()) { continue }
                        $openAfter = (($p + 1) -lt $parts.Count) -and $parts[$p + 1].Contains('(')
                        $toks = [string[]]@(($inner -split '\s+') | Where-Object { $_ })
                        [void]$segs.Add(@{ tokens = $toks; openAfter = [bool]$openAfter })
                    }
                }
            }
            [void]$out.Add(@{ variant = $v['name']; segments = $segs.ToArray() })
        }
    }
    return $out.ToArray()
}

function Get-EvidenceRecursiveDeleteUncomputableReason {
    <#
      D3's UNCOMPUTABLE CHARACTERS for one operand (or one directory-change argument): '' when the text is
      static, else a phrase naming what the shell decides. Closed list, string-only, never throws.
    #>
    param([AllowNull()][string]$Token)
    if (-not $Token) { return 'no text at all' }
    if ($Token.Contains('$')) { return 'a dollar sign (a variable, a $( ) or ${ } expansion, or an ANSI-C quote)' }
    if ($Token.Contains([string][char]96)) { return 'a backtick (a command substitution or an escape)' }
    if ($Token.IndexOfAny([char[]]@([char]123, [char]125)) -ge 0) { return 'a brace (brace expansion or a script block)' }
    if ($Token.IndexOfAny([char[]]@([char]42, [char]63, [char]91, [char]93)) -ge 0) { return 'a glob character' }
    if ($Token.Contains('%')) { return 'a percent sign (a cmd %NAME% expansion)' }
    if ($Token.Contains('!')) { return 'an exclamation mark (a cmd !NAME! delayed expansion or a history expansion)' }
    if ($Token.IndexOfAny([char[]]@([char]60, [char]62)) -ge 0) { return 'a redirection or process-substitution character' }
    if ($Token.StartsWith('@')) { return 'a leading @ (a PowerShell splat)' }
    if ($Token -match '(^|[=:,])~') { return 'a tilde the shell expands to a home directory' }
    if (($Token -replace '^[A-Za-z]:(?=[\\/])', '').Contains(':')) { return 'a colon that is not a drive letter before a separator (a provider or drive qualifier, or a drive-relative path)' }
    return ''
}

function Test-EvidenceRecursiveDeleteDirOption {
    <#
      FORK F3: does this token, standing between a lead in command position and the delete it leads, move
      the directory the delete runs in? Closed list. The one-letter forms are case-SENSITIVE, because their
      other case means something else (bash -c, sudo -d does not exist).
    #>
    param([AllowNull()][string]$Token)
    if (-not $Token) { return $false }
    if ($Token -ceq '-C' -or $Token -ceq '-D') { return $true }
    $t = $Token.ToLowerInvariant()
    foreach ($p in @('--chdir', '--directory', '--cwd', '--workdir', '--work-dir', '--working-directory')) {
        if ($t.StartsWith($p)) { return $true }
    }
    if ($t -eq '/d' -or $t -eq '-wd') { return $true }
    $name = ($t -split ':', 2)[0]
    return (($name.Length -ge 3) -and '-workingdirectory'.StartsWith($name))
}

function Get-EvidenceRecursiveDeleteInvocation {
    <#
      D2 AND D3's OPERANDS FOR ONE TOKEN IN COMMAND POSITION. $null when $Tokens[$VerbAt] is not a recursive
      delete; otherwise @{ spelling; family; operands = [string[]]; expansion } where `family` names every
      route that recognised it and `expansion` is the option or splat whose value the shell decides ('' when
      none). Reads only to the end of the segment it was given.
    #>
    param([string[]]$Tokens, [int]$VerbAt)
    $verbTok = [string]$Tokens[$VerbAt]
    $names = @(Get-EvidenceRecursiveDeleteVerbNames -Token $verbTok)
    $isRm  = ($names -contains 'rm')
    $isPs  = (@($names | Where-Object { $script:EvidenceRecursiveDeletePsNames -contains $_ }).Count -gt 0)
    $isCmd = (@($names | Where-Object { $script:EvidenceRecursiveDeleteCmdNames -contains $_ }).Count -gt 0)
    if (-not ($isRm -or $isPs -or $isCmd)) { return $null }
    $family = New-Object System.Collections.Generic.List[string]
    $operands = New-Object System.Collections.Generic.List[string]
    $expansion = ''
    # (c) ATTACHED TO THE VERB: cmd reads rd/s/q as rd /s /q.
    $attached = [regex]::Match($verbTok.Trim([char[]]@([char]123, [char]125)), '^[A-Za-z]+((?:/[A-Za-z?](?::[^/\s]*)?)+)$')
    if ($isCmd -and $attached.Success -and ($attached.Groups[1].Value -match '(?i)(?:^|/)s(?=[:/]|$)')) { [void]$family.Add('cmd /s') }
    $endOfOptions = $false
    $skipNext = $false
    for ($i = $VerbAt + 1; $i -lt $Tokens.Count; $i++) {
        $tok = [string]$Tokens[$i]
        if ($skipNext) { $skipNext = $false; continue }
        $redir = [regex]::Match($tok, $script:EvidenceRecursiveDeleteRedirection)
        if ($redir.Success) { if (-not $redir.Groups[1].Value) { $skipNext = $true }; continue }
        if ($tok -eq '}') { continue }
        if (-not $endOfOptions) {
            if ($tok -eq '--') { $endOfOptions = $true; continue }
            if ($tok.Length -gt 1 -and $tok.StartsWith('-')) {
                if ($tok.StartsWith('--')) {
                    $lname = ($tok.Substring(2) -split '=', 2)[0].ToLowerInvariant()
                    if ($isRm -and $lname -and 'recursive'.StartsWith($lname)) { [void]$family.Add('rm --recursive') }
                    if ($tok -match '[$`]') { $expansion = $tok }
                    continue
                }
                $body = $tok.Substring(1)
                $colon = $body.IndexOf(':')
                $pname = if ($colon -ge 0) { $body.Substring(0, $colon) } else { $body }
                $pl = $pname.ToLowerInvariant()
                if ($isRm -and ($pname -match '[rR]')) { [void]$family.Add('rm -r') }
                if ($isPs -and $pl -and 'recurse'.StartsWith($pl)) { [void]$family.Add('Remove-Item -Recurse') }
                if ($colon -ge 0) {
                    $pvalue = $body.Substring($colon + 1)
                    $switchOnly = [bool]$pl -and
                                  (@($script:EvidenceRecursiveDeleteSwitchParams | Where-Object { $_.StartsWith($pl) }).Count -gt 0) -and
                                  (@($script:EvidenceRecursiveDeleteValueParams | Where-Object { $_.StartsWith($pl) }).Count -eq 0)
                    if ($switchOnly -and ($pvalue -match '^(?i)(\$true|\$false|true|false|1|0)$')) { continue }
                    if ($pvalue) { [void]$operands.Add($pvalue) }
                    continue
                }
                if ($tok -match '[$`]') { $expansion = $tok }
                continue
            }
            if ($isCmd -and ($tok -match $script:EvidenceRecursiveDeleteCmdSwitches)) {
                if ($tok -match '(?i)(?:^|/)s(?=[:/]|$)') { [void]$family.Add('cmd /s') }
                continue
            }
        }
        if (($isRm -or $isPs) -and $tok.Length -gt 1 -and $tok.StartsWith('@')) { $expansion = $tok }
        # A TRAILING `}` CLOSES A BLOCK: the operand is judged without it (same parent, so never looser).
        if ($tok.EndsWith('}') -and -not $tok.Contains('{')) {
            $tok = $tok.TrimEnd([char]125)
            if (-not $tok) { continue }
        }
        [void]$operands.Add($tok)
    }
    if ($expansion -and $family.Count -eq 0 -and ($isRm -or $isPs)) { [void]$family.Add('flags supplied by an expansion') }
    if ($family.Count -eq 0) { return $null }
    $spelling = ($Tokens[$VerbAt..($Tokens.Count - 1)] -join ' ')
    if ($spelling.Length -gt 160) { $spelling = $spelling.Substring(0, 157) + '...' }
    $familyText = ((@($family) | Select-Object -Unique) -join ', ')
    return @{ spelling = $spelling; family = $familyText; operands = $operands.ToArray(); expansion = $expansion; moved = '' }
}

function Get-EvidenceRecursiveDeleteChdir {
    <#
      FORK F3 FOR ONE TOKEN IN COMMAND POSITION: $null when it is not a directory change; otherwise
      @{ known = $true; dest; why = '' } for exactly one static argument under the flags -L -P -Path
      -LiteralPath, and @{ known = $false; dest = ''; why } for anything else -- popd and Pop-Location
      included, which return to a directory this text does not name.
    #>
    param([string[]]$Tokens, [int]$VerbAt)
    $names = @(Get-EvidenceRecursiveDeleteVerbNames -Token ([string]$Tokens[$VerbAt]))
    $spelled = ($Tokens[$VerbAt..($Tokens.Count - 1)] -join ' ')
    if (@($names | Where-Object { $script:EvidenceRecursiveDeletePopVerbs -contains $_ }).Count -gt 0) {
        return @{ known = $false; dest = ''; why = "an earlier '$spelled' returns to a directory the command text does not name" }
    }
    if (@($names | Where-Object { $script:EvidenceChdirVerbs -contains $_ }).Count -eq 0) { return $null }
    $dirArgs = New-Object System.Collections.Generic.List[string]
    $unmodelled = ''
    $skipNext = $false
    for ($i = $VerbAt + 1; $i -lt $Tokens.Count; $i++) {
        $tok = [string]$Tokens[$i]
        if ($skipNext) { $skipNext = $false; continue }
        $redir = [regex]::Match($tok, $script:EvidenceRecursiveDeleteRedirection)
        if ($redir.Success) { if (-not $redir.Groups[1].Value) { $skipNext = $true }; continue }
        if ($tok -eq '}') { continue }
        if ($tok.StartsWith('-')) {
            if ($script:EvidenceRecursiveDeleteChdirFlags -contains $tok.ToLowerInvariant()) { continue }
            $unmodelled = $tok
            continue
        }
        [void]$dirArgs.Add($tok)
    }
    if ($unmodelled) { return @{ known = $false; dest = ''; why = "an earlier directory change '$spelled' carries '$unmodelled', which the guard does not model" } }
    if ($dirArgs.Count -ne 1) { return @{ known = $false; dest = ''; why = "an earlier directory change '$spelled' names $($dirArgs.Count) directories, not one static one" } }
    $uncomputable = Get-EvidenceRecursiveDeleteUncomputableReason -Token $dirArgs[0]
    if ($uncomputable) { return @{ known = $false; dest = ''; why = "an earlier directory change '$spelled' carries $uncomputable" } }
    return @{ known = $true; dest = $dirArgs[0]; why = '' }
}

function Add-EvidenceRecursiveDeleteBase {
    <#
      FORK F3: a directory change ADDS the bases it may produce -- its destination from every known base, or
      one unknown base -- and never removes one, because the change may fail and the delete still run.
      -Bases is a List of @{ path; known; why }, modified in place; paths are comparable.
    #>
    param($Bases, $Change)
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    $added = New-Object System.Collections.Generic.List[object]
    if (-not $Change['known']) {
        [void]$added.Add(@{ path = ''; known = $false; why = [string]$Change['why'] })
    } else {
        $destCanon = ConvertTo-CanonicalPathText -Text ([string]$Change['dest'])
        if (Test-EvidenceRootedPath -Path $destCanon) {
            [void]$added.Add(@{ path = (ConvertTo-EvidencePeerComparablePath -Path $destCanon); known = $true; why = '' })
        } else {
            foreach ($b in @($Bases.ToArray())) {
                if (-not $b['known']) { continue }
                [void]$added.Add(@{ path = (ConvertTo-EvidencePeerComparablePath -Path (([string]$b['path']).TrimEnd('/') + '/' + $destCanon)); known = $true; why = '' })
            }
        }
    }
    foreach ($n in $added) {
        $dup = $false
        foreach ($b in $Bases) {
            if (($b['known'] -eq $n['known']) -and [string]::Equals([string]$b['path'], [string]$n['path'], $ic)) { $dup = $true; break }
        }
        if (-not $dup) { [void]$Bases.Add($n) }
    }
    if ($Bases.Count -gt $script:EvidenceRecursiveDeleteMaxBases) {
        if (@($Bases | Where-Object { -not $_['known'] }).Count -eq 0) {
            [void]$Bases.Add(@{ path = ''; known = $false; why = "more than $($script:EvidenceRecursiveDeleteMaxBases) possible directories precede it" })
        }
    }
}

function Get-EvidenceRecursiveDeleteTargetFinding {
    <#
      D3 FOR ONE OPERAND. -Bases: the possible bases (FORK F3), each @{ path; known; why }. -OwnRoots:
      Get-EvidenceOwnWorktreeRoots' spellings. $null when the operand is static and every rooted form of it,
      from every base, lies STRICTLY under an own root; otherwise @{ condition = 'uncomputable' | 'outside'
      | 'root'; form; detail }. Relativity is the form builder's own answer: a form it builds WITHOUT a cwd
      that is not rooted.
    #>
    param([AllowNull()][string]$Target, [object[]]$Bases, [AllowNull()][string[]]$OwnRoots)
    $why = Get-EvidenceRecursiveDeleteUncomputableReason -Token $Target
    if ($why) { return @{ condition = 'uncomputable'; form = ''; detail = "it carries $why, so its value is the shell's to decide" } }
    $bareForms = @(Get-EvidencePathForms -Text $Target -Cwd '')
    $isRelative = (@($bareForms | Where-Object { $_ -and -not (Test-EvidenceRootedPath -Path $_) }).Count -gt 0)
    $unknown = @(@($Bases) | Where-Object { -not $_['known'] })
    if ($isRelative -and $unknown.Count -gt 0) {
        return @{ condition = 'uncomputable'; form = ''; detail = "it is relative and $($unknown[0]['why'])" }
    }
    $roots = @(@($OwnRoots) | Where-Object { $_ })
    if ($roots.Count -eq 0) {
        return @{ condition = 'outside'; form = ''; detail = 'no own tree root could be derived, so no target can be shown to lie inside it' }
    }
    $forms = New-Object System.Collections.Generic.List[string]
    if ($isRelative) {
        foreach ($b in @($Bases)) {
            foreach ($f in @(Get-EvidencePathForms -Text $Target -Cwd ([string]$b['path']))) {
                if ($f -and (Test-EvidenceRootedPath -Path $f)) { [void]$forms.Add($f) }
            }
        }
    } else {
        foreach ($f in $bareForms) { if ($f -and (Test-EvidenceRootedPath -Path $f)) { [void]$forms.Add($f) } }
    }
    if ($forms.Count -eq 0) { return @{ condition = 'uncomputable'; form = ''; detail = 'the form builder produced no rooted form for it' } }
    $ic = [System.StringComparison]::OrdinalIgnoreCase
    foreach ($f in $forms) {
        $spellings = New-Object System.Collections.Generic.List[string]
        $comparable = ConvertTo-EvidencePeerComparablePath -Path $f
        [void]$spellings.Add($comparable)
        $long = ConvertTo-EvidenceLongNameForm -Path $comparable
        if ($long) { [void]$spellings.Add((ConvertTo-EvidencePeerComparablePath -Path $long)) }
        $rootHit = ''
        $inside = $false
        foreach ($s in $spellings) {
            foreach ($r in $roots) {
                if ([string]::Equals($s, $r, $ic)) { $rootHit = $r }
                elseif (($s.Length -gt ($r.Length + 1)) -and $s.StartsWith($r + '/', $ic)) { $inside = $true }
            }
        }
        if ($rootHit) { return @{ condition = 'root'; form = $f; detail = "its form '$f' is the own tree root '$rootHit' itself" } }
        if (-not $inside) { return @{ condition = 'outside'; form = $f; detail = "its form '$f' is not strictly under any own tree root" } }
    }
    return $null
}

function Get-EvidenceRecursiveDeleteInvocationFinding {
    <#
      D3 FOR ONE RECOGNISED INVOCATION: an expansion-supplied flag set, a cut argument list and a missing
      static target are uncomputable before any operand is read; then each operand in order. $null when
      every operand is inside; otherwise the operand's finding with the invocation's spelling, family and
      target attached.
    #>
    param($Invocation, [object[]]$Bases, [AllowNull()][string[]]$OwnRoots, [bool]$OpenAfter)
    $shared = @{ spelling = [string]$Invocation['spelling']; family = [string]$Invocation['family'] }
    $result = $null
    if ($Invocation['expansion']) {
        $result = @{ condition = 'uncomputable'; form = ''; target = [string]$Invocation['expansion']
                     detail = "the option or parameter set '$($Invocation['expansion'])' is supplied by an expansion the shell decides" }
    } elseif ($OpenAfter) {
        $result = @{ condition = 'uncomputable'; form = ''; target = '(a sub-expression)'
                     detail = 'its argument list continues into a parenthesised sub-expression -- $( ), ( ) or @( ) -- whose value the guard does not read' }
    } elseif (@($Invocation['operands']).Count -eq 0) {
        $result = @{ condition = 'uncomputable'; form = ''; target = '(none)'
                     detail = 'it names no static target: its targets arrive from a pipeline, xargs, find -exec or a substitution' }
    } else {
        $judgeBases = @($Bases)
        if ($Invocation['moved']) {
            $judgeBases = @($Bases) + @(@{ path = ''; known = $false; why = "the lead option '$($Invocation['moved'])' moves the directory it runs in" })
        }
        foreach ($op in @($Invocation['operands'])) {
            $f = Get-EvidenceRecursiveDeleteTargetFinding -Target $op -Bases $judgeBases -OwnRoots $OwnRoots
            if ($f) { $f['target'] = $op; $result = $f; break }
        }
    }
    if ($null -eq $result) { return $null }
    foreach ($k in $shared.Keys) { $result[$k] = $shared[$k] }
    return $result
}

function Get-EvidenceRecursiveDeleteFinding {
    <#
      THE RULE'S PREDICATE (D1-D5): the first refusing finding over every variant, segment, invocation and
      operand of -Command for worker -DispatchId standing in -Cwd, or $null. Deny-only by construction: a
      finding can only refuse. FAILURE DIRECTION (FORK F4): the pre-screen's exception adds nothing; past it,
      any exception is returned as condition 'error', which the caller refuses.
    #>
    param([AllowNull()][string]$Command, [AllowNull()][string]$Cwd, [AllowNull()][string]$DispatchId)
    if (-not $Command) { return $null }
    $mentioned = $false
    try { $mentioned = [bool](Test-EvidenceRecursiveDeleteMentioned -Command $Command) } catch { $mentioned = $false }
    if (-not $mentioned) { return $null }
    $ownRoots = @()
    try {
        $ownRoots = @(Get-EvidenceOwnWorktreeRoots -DispatchId $DispatchId)
        $initial = if ($Cwd) { @{ path = (ConvertTo-EvidencePeerComparablePath -Path $Cwd); known = $true; why = '' } }
                   else { @{ path = ''; known = $false; why = 'the payload carries no cwd to resolve it against' } }
        foreach ($variant in @(Get-EvidenceRecursiveDeleteSegments -Command $Command)) {
            $bases = New-Object System.Collections.Generic.List[object]
            [void]$bases.Add($initial)
            foreach ($seg in @($variant['segments'])) {
                $toks = [string[]]@($seg['tokens'])
                $found = New-Object System.Collections.Generic.List[object]
                $led = $false
                for ($i = 0; $i -lt $toks.Count; $i++) {
                    $tok = $toks[$i]
                    # ANYWHERE-LEADS: a `{` opens a block and an assignment `=` hands its right side to a command.
                    if ($tok.StartsWith('{') -or ($tok -match '^[-+*/%]?=$')) { $led = $true }
                    $inPosition = ($i -eq 0) -or $led
                    if (-not $inPosition) { continue }
                    $change = Get-EvidenceRecursiveDeleteChdir -Tokens $toks -VerbAt $i
                    if ($null -ne $change) { Add-EvidenceRecursiveDeleteBase -Bases $bases -Change $change }
                    $inv = Get-EvidenceRecursiveDeleteInvocation -Tokens $toks -VerbAt $i
                    if ($null -ne $inv) {
                        for ($j = 1; $j -lt $i; $j++) {
                            if (Test-EvidenceRecursiveDeleteDirOption -Token $toks[$j]) { $inv['moved'] = $toks[$j]; break }
                        }
                        [void]$found.Add($inv)
                    }
                    $names = @(Get-EvidenceRecursiveDeleteVerbNames -Token $tok)
                    if ((@($names | Where-Object { $script:EvidenceRecursiveDeleteLeads -contains $_ }).Count -gt 0) -or
                        ($tok -match '^[A-Za-z_][A-Za-z0-9_]*=')) { $led = $true }
                }
                foreach ($inv in $found) {
                    $finding = Get-EvidenceRecursiveDeleteInvocationFinding -Invocation $inv -Bases $bases.ToArray() -OwnRoots $ownRoots -OpenAfter ([bool]$seg['openAfter'])
                    if ($null -ne $finding) {
                        $finding['variant'] = [string]$variant['variant']
                        $finding['ownRoots'] = @($ownRoots)
                        return $finding
                    }
                }
            }
        }
    } catch {
        return @{ condition = 'error'; spelling = ''; family = ''; target = ''; form = ''; variant = ''
                  detail = [string]$_.Exception.Message; ownRoots = @($ownRoots) }
    }
    return $null
}

function Get-EvidenceRecursiveDeleteDenyReason {
    # D4: the verb as spelled, the target, the condition and why, the worker, the own roots derived, and the
    # rule's standing. Never names the peer rule's sentence, so the two refusals stay distinguishable.
    param($Finding, [AllowNull()][string]$DispatchId)
    $roots = @(@($Finding['ownRoots']) | Where-Object { $_ })
    $rootText = if ($roots.Count -gt 0) { "'" + ($roots -join "', '") + "'" } else { 'NONE (neither LAM_WORKTREE nor CLAUDE_PROJECT_DIR places an existing wt-<LAM_DISPATCH> tree)' }
    $standing = "A dispatched worker's recursive delete -- rm -r/-R/--recursive in any spelling, Remove-Item -Recurse and its aliases, rmdir/rd/del/erase /s -- is refused when a target is uncomputable, outside its own tree, or the tree root itself; a static target strictly inside the own tree is not judged here. " +
                "Worker-scoped and deny-only (b1s6 item 2): it runs after every other rule, the seat never evaluates it, and it grants the own tree nothing. " +
                "A tripwire, not a boundary: a delete the shell computes from text carrying none of these characters, a link inside the tree, or a delete spelled without these verbs is not seen"
    if ($Finding['condition'] -eq 'error') {
        return ("RECURSIVE DELETE: the recursive-delete rule could not evaluate this command ($($Finding['detail'])), and this session is dispatched worker '$DispatchId'. A guard that cannot see refuses; the own tree root(s) derived were $rootText. " + $standing)
    }
    $cond = switch ([string]$Finding['condition']) {
        'uncomputable' { "is UNCOMPUTABLE: $($Finding['detail'])" }
        'root'         { "IS the worker's own tree ROOT: $($Finding['detail'])" }
        default        { "lies OUTSIDE the worker's own tree: $($Finding['detail'])" }
    }
    return ("RECURSIVE DELETE: the invocation '$($Finding['spelling'])' ($($Finding['family']); read with $($Finding['variant'])) names the target '$($Finding['target'])', which $cond. " +
            "This session is dispatched worker '$DispatchId', whose own tree root(s) derived from LAM_WORKTREE and CLAUDE_PROJECT_DIR (never the payload cwd) are $rootText. " + $standing)
}

# =================================================================================================
# THE SEAT TRIPWIRE: A MISSION-PLANE WRITE FROM A SESSION WHOSE PROJECT IS A LINKED WORKTREE IS REFUSED
# (toolchain batch WP-E, member E-2;
# WP-1 H-25 measures it)
# =================================================================================================
# THE RULING, VERBATIM: "Mission-plane ceremony runs only from a root seat bearing the
# orchestrator hooks; a guard tripwire refuses writes under .mission/** and .mission-runtime/lam/** from a
# linked worktree (deny-side, fails safe; WP fixtures' git-dir assertion is the distinguishing fact)."
#
# WHY. A close ceremony ran from the tooling seat in the linked
# worktree wt-close-fix and left NO evidence sidecar in either plane. And a linked worktree
# carries no .claude/ directory, so a tooling seat there registers no project hook at all. Ceremony belongs
# to the root seat, and a seat in a linked worktree that reaches for the mission plane is refused.
#
# THE CONDITION, IN FOUR PARTS.
#   1 WHOSE GIT DIR. The SESSION's. Its project directory is $env:CLAUDE_PROJECT_DIR, which the CLI hands
#     every hook process as the directory the session was started in -- NEVER the payload cwd, which the
#     agent moves with one `cd`. The rule reads the `.git` entry AT that directory and does NOT walk up.
#     THIS IS A FORK, STATED: git's own discovery walks up. It does not have to here, because the harness
#     registers a tree's project hooks only for a session started where that tree's .claude/ sits, which is
#     the tree's root, where its `.git` entry is (measured by WP-E's probes P5b, P6 and P6m on CLI 2.1.258
#     and 2.1.281: a session started in a subdirectory, of a main checkout or of a linked worktree, loaded
#     no project settings and ran no hook). And it must not, because a directory inside a tree that has no
#     git dir of its own -- an instrument's sandbox -- would then read as the tree it sits in, and the same
#     instrument would pass at the root and fail in a linked worktree (review round 1's blocker: H-4's A1
#     negative suite and H-14, whose sandboxes are exactly that). Answers, never running git (a native
#     exe's stderr is fatal in the hook):
#       a `.git` DIRECTORY -> a main checkout, and this rule does not fire;
#       a `.git` FILE whose gitdir (a relative one resolved against the directory holding the file) is an
#         existing directory holding HEAD, and is a submodule's (a modules/<name> path, no worktrees/
#         segment) -> 'other', and this rule does not fire;
#       a `.git` FILE whose gitdir is any other existing directory holding HEAD -> LINKED. That is a linked
#         worktree's (<common dir>/worktrees/<name>), and deny-side it is also a separate-git-dir checkout
#         or a .git file a seat rewrote to name another repository's git dir;
#       a `.git` FILE that cannot be read, carries no gitdir line, or names a gitdir that is not an
#         existing directory holding HEAD -> UNREADABLE, judged as linked (law 1: a guard that cannot see
#         refuses; a review finding drove a gitdir naming nothing failing OPEN);
#       no anchor, an anchor that is not an existing rooted directory, or no `.git` entry AT it -> nothing
#         is known about a session root, and nothing is refused.
#   2 THE DISTINGUISHING FACT IS THE GIT DIR, as the ruling says. A WP fixture that `git init`s its own
#     repository and asserts its git dir inside itself (the 2026-09-13 rule) holds a `.git` DIRECTORY and is
#     a main checkout here, wherever it sits -- inside a linked worktree included. A sandbox with no git dir
#     of its own is no session root and does not trip: the 2026-09-13 class does not trip.
#   3 WHICH ACTS. The mutating forms this guard ALREADY classifies:
#       FILE-TOOL ROUTE -- every tool name the file-tool branch of Get-EvidenceGuardDecision judges (not in
#         $readOnlyTools and not a shell tool, unknown names included), every path value at any depth;
#       SHELL ROUTE -- every command segment whose verb is in A1's two classes (framework:1123-1128):
#         'destructive' (rm, rmdir, del, erase, rd, unlink, shred, truncate, mv, move, ren, rename,
#         Remove-Item, Move-Item, Rename-Item, Clear-Content, Clear-Item; git clean, rm, checkout, restore,
#         reset) and 'staging' (git add, git commit). The segment is read QUOTE-AWARE, and through what
#         precedes or dresses the verb -- the wrappers sudo, env (with its NAME=VALUE words), command and
#         exec, PowerShell's call operator, an .exe suffix, git's global options (-c, -C, --git-dir,
#         --work-tree, --namespace, --config-env, and every other option before the subcommand), and the
#         PowerShell aliases of A1's cmdlets (ri, del, erase, rd, rmdir, rm, mi, move, mv, rni, ren, clc,
#         cli) -- because A1's own reader takes the first word only and misses each (a review
#         finding). The classes are A1's; no verb joins them.
#     A READ BY A TOOL THIS HOOK IS REGISTERED FOR IS NEVER REFUSED BY THIS RULE. The read-only tools are
#     skipped; a segment whose verb is in neither class is not judged; and inside a classified segment
#     only the words that NAME WHAT IS WRITTEN are judged: never the verb or the subcommand, never an
#     option, never the value of a git option that takes a message, a file of messages, a commit, an
#     author, a date or a trailer (-m, --message, -F, --file, -C, -c, --reuse-message, --reedit-message,
#     --fixup, --squash, --author, --date, --cleanup, -t, --template, --trailer), and not at all when a git
#     staging segment is a dry run (add -n/--dry-run, commit --dry-run, clean -n/--dry-run). A message is
#     not a path (review findings). A tool name the file-tool branch does not know is
#     judged as a write, as that branch judges it; the registration's matcher routes none to this hook.
#   4 WHICH TERRITORY. A path, dot segments resolved with its drive kept, Win32 trailing dots and spaces
#     stripped, an 8.3 alias inverted where the volume can say, an extended-length prefix removed and a
#     relative path joined to the payload cwd (to the session's project directory when the payload has
#     none), that carries:
#       `.mission` as a whole component -- the directory itself or anything under it;
#       `.mission-runtime/lam` as a whole pair of components; or
#       the session's own `.git` entry, <CLAUDE_PROJECT_DIR>/.git or anything under it -- so that a linked
#         seat cannot rewrite the fact this rule reads (a review finding).
#     A component boundary is a slash OR A COLON, so the NTFS stream spelling `.mission::$INDEX_ALLOCATION`,
#     git's `:.mission/...` pathspec and a drive-relative `C:.mission` are the plane too (review
#     findings). Case-insensitive. Judged on the RESOLVED form, so `.mission/../src/x` is not under
#     the plane and `.mission./ledger/x` is.
#
# THE DISPATCHED WORKER (FORK, beyond the ruling's text, stated). A worker runs in a linked worktree too,
# and K-3 gives it exactly two closed members under .mission/ -- its own evidence session and
# its own handoff. Refusing the handoff would leave every dispatch unable to complete, the defect K-3's
# amendment cured. So for a dispatched worker this rule leaves .mission/** to K-3, which above has already refused
# every path outside those two members, and refuses .mission-runtime/lam/** and its own `.git` entry.
#
# PLACED LAST AND DENY-ONLY, for the peer rule's reason: every rule above has returned its own refusal, so
# this block can only turn an allow into a deny and never re-words a refusal. The territory test runs only
# for a LINKED or UNREADABLE session. A root seat's session reads 'main' from one Directory.Exists; an
# error inside the session test answers UNREADABLE and could then refuse a root seat's plane write -- no
# input found raises one (review round 1 forced one only by redefining a helper).
#
# FAILURE DIRECTION, BOTH HALVES. The session test never throws. An exception in the territory test for a
# linked or unreadable session REFUSES the call.
#
# WHAT IS NOT REACHED (a tripwire, not a boundary).
#   * A shell verb in neither class -- cp, Copy-Item, Set-Content, Add-Content, Out-File, tee, New-Item,
#     mkdir, git mv, git stash, git apply and the rest. A1's parent tier refuses one that also carries a
#     metacharacter, for every role; without one it is not seen here.
#   * A classified verb that NAMES nothing in the plane and reaches it anyway: `git add -A`, `git add .`,
#     `git add -u`, `git commit -a`, `git reset --hard`, `git clean -fdx` (A1's repo-wide rule refuses the
#     last for every role), and a pathspec read from a file (--pathspec-from-file).
#   * A script invoked by path whose command names no plane path, such as tools/lam/mission-*.ps1 with
#     -MissionRoot: it computes its targets inside the child process.
#   * A link that already exists inside the tree and resolves into the plane: judged by its name. Creating
#     one whose target is the plane is refused by the link rule above, for every role.
#   * A session with no CLAUDE_PROJECT_DIR, or with one the CLI never writes (the MSYS spelling /c/...),
#     and a session started in a SUBDIRECTORY of a tree: P6 and P6m measured such a session loading no
#     project settings at all, so no hook runs there and no rule of this guard runs either. A subdirectory
#     that carries a .claude/ registration of its own is judged by its own `.git` entry, which it lacks.
#   * A tree that registers no hook. Until a linked worktree carries the registration (the operator's
#     step), nothing here runs in it -- which is the WHY's second finding.
$script:EvidenceSeatTripwireWrappers = @('sudo', 'env', 'command', 'exec', '&')
$script:EvidenceSeatTripwirePsAliases = @('ri', 'del', 'erase', 'rd', 'rmdir', 'rm', 'mi', 'move', 'mv', 'rni', 'ren', 'clc', 'cli')
$script:EvidenceSeatTripwireGitGlobalValueOpts = @('-c', '-C', '--git-dir', '--work-tree', '--namespace', '--config-env', '--exec-path', '--super-prefix')
$script:EvidenceSeatTripwireGitValueOpts = @('-m', '--message', '-F', '--file', '-C', '-c', '--reuse-message', '--reedit-message',
    '--fixup', '--squash', '--author', '--date', '--cleanup', '-t', '--template', '--trailer', '--pathspec-from-file',
    '--chmod', '-e', '--exclude', '-s', '--source', '-b', '-B', '--orphan', '--conflict')

function Get-EvidenceSeatSessionLink {
    <#
      PART 1: is THIS session's project a linked worktree? The anchor is $env:CLAUDE_PROJECT_DIR and nothing
      else, and the `.git` entry read is the one AT the anchor (no walk). Returns
      @{ state; anchor; root; roots; dotGit; gitdir; detail }, state one of 'linked', 'unreadable', 'main',
      'other', 'none'; `root` is the anchor in the form builder's comparable spelling and `roots` adds its 8.3
      long form where the volume inverts one. Never runs git, never throws.
    #>
    $out = @{ state = 'none'; anchor = [string]$env:CLAUDE_PROJECT_DIR; root = ''; roots = @(); dotGit = ''; gitdir = ''; detail = 'no CLAUDE_PROJECT_DIR' }
    try {
        $anchor = [string]$env:CLAUDE_PROJECT_DIR
        if (-not $anchor) { return $out }
        $unpref = Remove-EvidenceExtendedLengthPrefix -Text $anchor
        if ($unpref) { $anchor = $unpref }
        $root = ConvertTo-EvidencePeerComparablePath -Path $anchor
        $out.root = $root
        $rootLong = ConvertTo-EvidenceLongNameForm -Path $root
        $out.roots = @(@($root) + @(if ($rootLong) { ConvertTo-EvidencePeerComparablePath -Path $rootLong }) | Where-Object { $_ })
        if (-not $root -or -not (Test-EvidenceRootedPath -Path ($root + '/'))) { $out.detail = 'CLAUDE_PROJECT_DIR is not a rooted path'; return $out }
        $native = $root.Replace('/', '\').TrimEnd('\')
        if (-not [System.IO.Directory]::Exists($native + '\')) { $out.detail = 'CLAUDE_PROJECT_DIR is not an existing directory'; return $out }
        $dotGit = $native + '\.git'
        if ([System.IO.Directory]::Exists($dotGit)) {
            $out.state = 'main'; $out.dotGit = $dotGit; $out.detail = 'the .git entry at the session root is a directory'
            return $out
        }
        if (-not [System.IO.File]::Exists($dotGit)) { $out.detail = 'no .git entry at the session root'; return $out }
        $out.dotGit = $dotGit
        $text = $null
        try { $text = [System.IO.File]::ReadAllText($dotGit) }
        catch { $out.state = 'unreadable'; $out.detail = 'the .git file could not be read (' + $_.Exception.Message + ')'; return $out }
        $gm = [regex]::Match([string]$text, '(?im)^\s*gitdir:\s*(\S.*?)\s*$')
        if (-not $gm.Success) { $out.state = 'unreadable'; $out.detail = 'the .git file carries no gitdir line'; return $out }
        $gd = ConvertTo-CanonicalPathText -Text $gm.Groups[1].Value
        if (-not (Test-EvidenceRootedPath -Path $gd)) { $gd = $root + '/' + $gd }
        $gd = ConvertTo-EvidencePeerComparablePath -Path $gd
        $out.gitdir = $gd
        $gdNative = $gd.Replace('/', '\').TrimEnd('\')
        if (-not ([System.IO.Directory]::Exists($gdNative) -and [System.IO.File]::Exists($gdNative + '\HEAD'))) {
            $out.state = 'unreadable'; $out.detail = 'the .git file names a gitdir that is not an existing directory holding HEAD'
            return $out
        }
        $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        if ([regex]::IsMatch($gd, '/modules/[^/]', $ic) -and -not [regex]::IsMatch($gd, '/worktrees/[^/]+$', $ic)) {
            $out.state = 'other'; $out.detail = 'the .git file names a submodule''s git dir'
            return $out
        }
        $out.state = 'linked'
        $out.detail = 'the .git file names ' + $(if ([regex]::IsMatch($gd, '/worktrees/[^/]+$', $ic)) { 'a linked worktree''s git dir' } else { 'a git dir that is not the session root''s own (judged linked)' })
        return $out
    } catch {
        $out.state = 'unreadable'; $out.detail = 'the session test failed (' + $_.Exception.Message + ')'
        return $out
    }
}

function Get-EvidenceMissionPlanePathClass {
    <#
      PART 4, for ONE resolved path form: 'lam' (`.mission-runtime/lam` as a whole pair of components),
      'mission' (`.mission` as a whole component), 'dotgit' (the session root's own `.git` entry, when -Roots
      are given), or ''. A component boundary is a slash or a colon. Case-insensitive, string-only.
    #>
    param([AllowNull()][string]$Path, [AllowNull()][string[]]$Roots = @())
    if (-not $Path) { return '' }
    $t = ConvertTo-CanonicalPathText -Text $Path
    $ic = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    if ([regex]::IsMatch($t, '(^|[/:])\.mission-runtime(:[^/]*)?/lam(?=[/:]|$)', $ic)) { return 'lam' }
    if ([regex]::IsMatch($t, '(^|[/:])\.mission(?=[/:]|$)', $ic)) { return 'mission' }
    foreach ($r in @($Roots)) {
        if (-not $r) { continue }
        if ([regex]::IsMatch($t, '^' + [regex]::Escape($r.TrimEnd('/')) + '/\.git(?=[/:]|$)', $ic)) { return 'dotgit' }
    }
    return ''
}

function Get-EvidenceSeatTripwireForms {
    <#
      PART 4's forms for ONE path value, WHOLE (a file-tool value, or one word of a shell segment): the
      value and its extended-length-stripped shape, each as written and joined to -Base when relative, each
      through ConvertTo-EvidencePeerComparablePath (dot segments resolved with the drive kept, Win32
      trailing dots and spaces stripped), and each of those with its 8.3 alias inverted where the volume can
      say. Returns a flat string[].
    #>
    param([AllowNull()][string]$Value, [AllowNull()][string]$Base)
    $forms = New-Object System.Collections.Generic.List[string]
    if (-not $Value) { return $forms.ToArray() }
    $bases = New-Object System.Collections.Generic.List[string]
    [void]$bases.Add($Value)
    $unpref = Remove-EvidenceExtendedLengthPrefix -Text $Value
    if ($unpref) { [void]$bases.Add($unpref) }
    foreach ($b in $bases) {
        $canon = ConvertTo-CanonicalPathText -Text $b
        if (-not $canon) { continue }
        $spellings = New-Object System.Collections.Generic.List[string]
        [void]$spellings.Add($canon)
        if ($Base -and -not (Test-EvidenceRootedPath -Path $canon)) {
            [void]$spellings.Add(((ConvertTo-CanonicalPathText -Text $Base).TrimEnd('/')) + '/' + $canon)
        }
        foreach ($s in $spellings) {
            $r = ConvertTo-EvidencePeerComparablePath -Path $s
            if (-not $r) { continue }
            [void]$forms.Add($r)
            $l = ConvertTo-EvidenceLongNameForm -Path $r
            if ($l) { [void]$forms.Add((ConvertTo-EvidencePeerComparablePath -Path $l)) }
            # THE STREAM-STRIPPED SHAPE, AND ITS 8.3 LONG NAME (WP-E2 round 2; validator round 1). A
            # stream suffix on an 8.3 short-name component (`MISSIO~1::$INDEX_ALLOCATION/ledger`)
            # defeats the alias resolver above, because the stream breaks the component-name lookup, so
            # neither the colon-boundary class test nor a resolved `.mission` form was produced and a
            # linked seat's mission-plane write leaked. Strip the stream, then resolve. Add-never-
            # substitute; a non-plane path adds forms that match no class.
            $st = Remove-EvidenceStreamSuffix -Path $r
            if ($st) {
                $stc = ConvertTo-EvidencePeerComparablePath -Path $st
                if ($stc) {
                    [void]$forms.Add($stc)
                    $stl = ConvertTo-EvidenceLongNameForm -Path $stc
                    if ($stl) { [void]$forms.Add((ConvertTo-EvidencePeerComparablePath -Path $stl)) }
                }
            }
        }
    }
    return $forms.ToArray()
}

function Split-EvidenceSeatShellSegments {
    <#
      PART 3's QUOTE-AWARE reading of a command: a list of segments, each a string[] of words with their
      quotes removed. A segment ends at ; | & or a line break OUTSIDE quotes; a word ends at whitespace outside
      quotes. Inside double quotes a backslash or a backtick before a double quote keeps the quote literal.
      An unbalanced quote runs to the end of the command, so nothing after it can escape into a new segment.
    #>
    param([AllowNull()][string]$Command)
    $segments = New-Object System.Collections.ArrayList
    if (-not $Command) { return @() }
    $words = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $inWord = $false
    $quote = [char]0
    $i = 0
    while ($i -lt $Command.Length) {
        $ch = $Command[$i]
        if ($quote -ne [char]0) {
            if ($quote -eq [char]34 -and ($ch -eq [char]92 -or $ch -eq [char]96) -and ($i + 1) -lt $Command.Length -and $Command[$i + 1] -eq [char]34) {
                [void]$sb.Append([char]34); $i += 2; continue
            }
            if ($ch -eq $quote) { $quote = [char]0; $i++; continue }
            [void]$sb.Append($ch); $i++; continue
        }
        if ($ch -eq [char]34 -or $ch -eq [char]39) { $quote = $ch; $inWord = $true; $i++; continue }
        if ($ch -eq ';' -or $ch -eq '|' -or $ch -eq '&' -or $ch -eq "`n" -or $ch -eq "`r") {
            if ($inWord) { [void]$words.Add($sb.ToString()); [void]$sb.Clear(); $inWord = $false }
            if ($words.Count -gt 0) { [void]$segments.Add($words.ToArray()); $words = New-Object System.Collections.Generic.List[string] }
            $i++; continue
        }
        if ([char]::IsWhiteSpace($ch)) {
            if ($inWord) { [void]$words.Add($sb.ToString()); [void]$sb.Clear(); $inWord = $false }
            $i++; continue
        }
        [void]$sb.Append($ch); $inWord = $true; $i++
    }
    if ($inWord) { [void]$words.Add($sb.ToString()) }
    if ($words.Count -gt 0) { [void]$segments.Add($words.ToArray()) }
    # NO leading comma: each segment leaves as one string[] object, and the caller's @() collects them.
    return $segments.ToArray()
}

function Get-EvidenceSeatSegmentTargets {
    <#
      PART 3 for ONE segment's words: @{ class; targets } -- A1's class for the segment's verb, read through
      the wrappers, an .exe suffix, git's global options and the PowerShell aliases of A1's cmdlets, and the
      words that NAME WHAT IS WRITTEN. class is 'destructive', 'staging' or 'other'; targets is empty for
      'other' and for a git staging or clean dry run.
    #>
    param([string[]]$Words)
    $none = @{ class = 'other'; targets = @() }
    $w = @($Words | Where-Object { $_ -ne $null -and $_ -ne '' })
    $i = 0
    while ($i -lt $w.Count) {
        # A LEADING NAME=VALUE WORD (bash's per-command environment, or env's) and a wrapper are skipped.
        if ($w[$i] -match '^[A-Za-z_][A-Za-z0-9_]*=') { $i++; continue }
        if ($script:EvidenceSeatTripwireWrappers -contains $w[$i].ToLowerInvariant()) { $i++; continue }
        break
    }
    if ($i -ge $w.Count) { return $none }
    $verb = ($w[$i].Trim('(', '&')) -replace '(?i)\.exe$', ''
    $verbLeaf = ($verb -split '[\\/]')[-1]
    $rest = @(if (($i + 1) -lt $w.Count) { $w[($i + 1)..($w.Count - 1)] } else { @() })
    if ($verbLeaf -ieq 'git') {
        $j = 0
        while ($j -lt $rest.Count -and $rest[$j].StartsWith('-')) {
            $o = $rest[$j]
            if (($script:EvidenceSeatTripwireGitGlobalValueOpts -ccontains $o) -and -not $o.Contains('=')) { $j += 2 } else { $j++ }
        }
        if ($j -ge $rest.Count) { return $none }
        $sub = $rest[$j].ToLowerInvariant()
        $args2 = @(if (($j + 1) -lt $rest.Count) { $rest[($j + 1)..($rest.Count - 1)] } else { @() })
        $class = if ($script:StagingGitSubs -contains $sub) { 'staging' } elseif ($script:DestructiveGitSubs -contains $sub) { 'destructive' } else { 'other' }
        if ($class -eq 'other') { return $none }
        $targets = New-Object System.Collections.Generic.List[string]
        $afterDashDash = $false
        $dry = $false
        for ($k = 0; $k -lt $args2.Count; $k++) {
            $a = $args2[$k]
            if ($afterDashDash) { [void]$targets.Add($a); continue }
            if ($a -eq '--') { $afterDashDash = $true; continue }
            if ($a.StartsWith('-')) {
                if ($a -eq '--dry-run' -or (($sub -eq 'add' -or $sub -eq 'clean' -or $sub -eq 'rm') -and $a -ceq '-n')) { $dry = $true }
                if (($script:EvidenceSeatTripwireGitValueOpts -ccontains $a) -and -not $a.Contains('=')) { $k++ }
                continue
            }
            [void]$targets.Add($a)
        }
        if ($dry) { return @{ class = $class; targets = @() } }
        return @{ class = $class; targets = $targets.ToArray() }
    }
    $isDestructive = ($script:DestructiveVerbs -contains $verbLeaf) -or ($script:EvidenceSeatTripwirePsAliases -contains $verbLeaf.ToLowerInvariant())
    if (-not $isDestructive) { return $none }
    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($a in $rest) {
        if ($a.StartsWith('-')) {
            # A PowerShell parameter written with its value attached (-Path:x, -LiteralPath:x) names a path.
            $cut = $a.IndexOf(':')
            if ($cut -gt 1 -and ($cut + 1) -lt $a.Length) { [void]$targets.Add($a.Substring($cut + 1)) }
            continue
        }
        [void]$targets.Add($a)
    }
    return @{ class = 'destructive'; targets = $targets.ToArray() }
}

function Get-EvidenceSeatTripwireHit {
    <#
      PARTS 3 AND 4: the first mission-plane WRITE this call makes, as @{ route; form; plane; verb }, or
      $null. -RawPaths are the path values the decision function collected at any depth, before any
      augmentation; -ReadOnlyTools and -ShellTools are the decision function's own two lists, passed in so the
      two routes here are exactly the routes it judges; -Roots are the session root's spellings, for the
      'dotgit' territory and as the base of a relative path when the payload carries no cwd. For a dispatched
      worker (-Worker) a 'mission' hit is left to K-3 (the FORK above). Throws on an internal error; the
      caller refuses on it.
    #>
    param([string]$ToolName, [string[]]$RawPaths, [AllowNull()][string]$CmdText, [AllowNull()][string]$Cwd,
          [string[]]$ReadOnlyTools, [string[]]$ShellTools, [bool]$Worker, [AllowNull()][string[]]$Roots = @())
    $base = if ($Cwd) { $Cwd } else { @($Roots)[0] }
    # FILE-TOOL ROUTE.
    if (-not ($ReadOnlyTools -contains $ToolName) -and -not ($ShellTools -contains $ToolName)) {
        foreach ($rp in @($RawPaths)) {
            if (-not $rp) { continue }
            foreach ($f in @(Get-EvidenceSeatTripwireForms -Value $rp -Base $base)) {
                $plane = Get-EvidenceMissionPlanePathClass -Path $f -Roots $Roots
                if (-not $plane) { continue }
                if ($Worker -and $plane -eq 'mission') { continue }
                return @{ route = 'file-tool'; form = $f; plane = $plane; verb = $ToolName }
            }
        }
    }
    # SHELL ROUTE: only the words of a classified segment that name what it writes.
    if ($CmdText) {
        foreach ($seg in @(Split-EvidenceSeatShellSegments -Command $CmdText)) {
            $st = Get-EvidenceSeatSegmentTargets -Words @($seg)
            if ($st.class -eq 'other') { continue }
            foreach ($tw in @($st.targets)) {
                foreach ($f in @(Get-EvidenceSeatTripwireForms -Value $tw -Base $base)) {
                    $plane = Get-EvidenceMissionPlanePathClass -Path $f -Roots $Roots
                    if (-not $plane) { continue }
                    if ($Worker -and $plane -eq 'mission') { continue }
                    return @{ route = 'shell'; form = $f; plane = $plane; verb = $st.class }
                }
            }
        }
    }
    return $null
}

function Get-EvidenceSeatTripwireDenyReason {
    # The sentence names the write, the territory, the session's project directory and what its `.git` entry
    # says, the ruling, and the rule's standing. It never borrows the peer rule's or K-3's wording, so the
    # three refusals stay distinguishable by their first two words.
    param($Hit, $Link)
    $planeText = switch ([string]$Hit.plane) { 'lam' { 'the mission plane .mission-runtime/lam/' } 'dotgit' { "this session root's own .git entry" } default { 'the mission plane .mission/' } }
    $why = if ($Link.state -eq 'linked') {
        "this session's project directory '" + $Link.anchor + "' is a LINKED worktree: its .git file '" + $Link.dotGit + "' names the git dir '" + $Link.gitdir + "'"
    } else {
        "this session's project directory '" + $Link.anchor + "' could not be established as a main checkout (" + $Link.detail + "), and a guard that cannot see refuses (law 1)"
    }
    return ('SEAT TRIPWIRE: the {0} write ({1}) to ''{2}'' reaches {3}, and {4}. Mission-plane ceremony runs only from a root seat bearing the orchestrator hooks: run it from the root checkout. A read by a registered tool is never refused by this rule, and the same write from a root seat is unaffected. A tripwire, not a boundary: a shell verb in neither of A1''s write classes (cp, Copy-Item, Set-Content, tee), a write that names no plane path (git add -A, git reset --hard), a script invoked by path, and a session with no CLAUDE_PROJECT_DIR are not seen' -f
            $Hit.route, $Hit.verb, $Hit.form, $planeText, $why)
}

function Remove-EvidenceStreamSuffix {
    <#
      THE NTFS ALTERNATE-DATA-STREAM SPELLING, STRIPPED (WP-E2, E2-1).

      A component boundary in the guard's literal patterns is a slash. The filesystem gives every
      file object a second boundary the patterns do not read: a COLON opens a named or default NTFS
      alternate data stream of the SAME object. `.mission::$INDEX_ALLOCATION/gates/x.yaml` writes the
      index stream of the `.mission` directory and then a path continues, and every string comparison
      sees a first component `.mission::$INDEX_ALLOCATION` that the two-component literals
      `.mission/gates`, `.mission/evidence`, `.mission-runtime/evidence`, `.claude/settings.json` and
      `tools/framework/hooks` no longer match. This is the case/trailing-dot/8.3/extended-length class
      one spelling further: the guard compares path STRINGS while the filesystem resolves several
      spellings onto one object.

      THE STRIP. Per component, cut at the FIRST colon that is not the drive separator (a leading
      `[A-Za-z]:` on component 0 is kept). Win32 forbids a colon in a filename otherwise, so any
      other colon in a component IS a stream separator and the text before it names the real object.
      A component that STARTS with a colon (git's `:.mission` colon pathspec) is NOT a stream and is
      left untouched -- that spelling is the seat tripwire's, which reads a leading colon as a
      boundary of its own. Returns the stripped path, or $null when nothing was a stream (add
      nothing). String-only; never touches the filesystem.
    #>
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    $t = $Path.Replace('\', '/')
    $parts = $t -split '/'
    $out = New-Object System.Collections.Generic.List[string]
    $changed = $false
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        $from = 0
        if ($i -eq 0 -and $p -match '^[A-Za-z]:') { $from = 2 }   # keep a drive letter's own colon
        $cut = $p.IndexOf(':', $from)
        if ($cut -gt $from) { [void]$out.Add($p.Substring(0, $cut)); $changed = $true }
        else { [void]$out.Add($p) }
    }
    if (-not $changed) { return $null }                # no stream on any component: add nothing
    $joined = ($out -join '/')
    if (-not $joined.Trim('/')) { return $null }       # never emit an empty or all-slash form
    return $joined
}

function Get-EvidenceA1OfferForms {
    <#
      THE FORMS OF ONE WHOLE PATH VALUE offered to A1's SEALED protected tier. Each SEED -- the canonical
      value, its extended-length-stripped shape, and (when relative and a cwd is known) the cwd-joined
      shape -- is CLOSED under the three string normalisations the filesystem can apply to one spelling:
      the Win32 trailing-dot/space strip, the 8.3 short-name alias inversion, and the NTFS stream strip.
      The closure runs to a FIXPOINT, so ANY COMPOSITION of them -- an 8.3 alias AND a trailing dot AND a
      stream on one path -- yields the fully-normalised form the sealed matcher can see. Validator rounds
      1, 2 and 3 each found ONE composition or route the earlier code applied singly rather than composed
      (a stream not re-resolved through the alias; a nested offer with its own weaker set; an 8.3 alias
      and a trailing dot never composed); the fixpoint closes the class rather than adding a fourth
      one-off. NOT tokenised: a file value is one path, and a space in it must not be split into fragments
      (WP-4 round 9's note). One builder, used by the top-level file-tool offer AND the nested (deep)
      offer, so the two cannot drift (WP-E2 rounds 3 and 4).
    #>
    param([AllowNull()][string]$Value, [AllowNull()][string]$Cwd = $script:EvidenceCwd)
    $forms = New-Object System.Collections.Generic.List[string]
    if (-not $Value) { return $forms.ToArray() }
    $seeds = New-Object System.Collections.Generic.List[string]
    $canon = ConvertTo-CanonicalPathText -Text $Value
    if ($canon) { [void]$seeds.Add($canon) }
    $unpref = Remove-EvidenceExtendedLengthPrefix -Text $Value
    if ($unpref) { $uc = ConvertTo-CanonicalPathText -Text $unpref; if ($uc) { [void]$seeds.Add($uc) } }
    if ($Cwd -and $canon -and -not (Test-EvidenceRootedPath -Path $canon)) {
        $j = Resolve-DotSegments -Token (((ConvertTo-CanonicalPathText -Text $Cwd).TrimEnd('/')) + '/' + $canon)
        if ($j) { [void]$seeds.Add($j) }
    }
    # CLOSE the seeds under {Win32 trailing-dot, 8.3 alias, stream strip} to a fixpoint. Each transform
    # returns $null when it changes nothing, and every reachable form is a normalisation (a strict
    # simplification), so the reachable set is finite; the counter is a backstop, not the terminator.
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $work = New-Object System.Collections.Generic.Queue[string]
    foreach ($sd in $seeds) { if ($sd -and $seen.Add([string]$sd)) { [void]$work.Enqueue([string]$sd) } }
    $guard = 0
    while (($work.Count -gt 0) -and ($guard -lt 64)) {
        $guard++
        $cur = $work.Dequeue()
        [void]$forms.Add($cur)
        foreach ($t in @((ConvertTo-EvidenceWin32ComponentForm -Path $cur),
                         (ConvertTo-EvidenceLongNameForm -Path $cur),
                         (Remove-EvidenceStreamSuffix -Path $cur))) {
            if ($t -and $seen.Add([string]$t)) { [void]$work.Enqueue([string]$t) }
        }
    }
    return $forms.ToArray()
}

function Remove-EvidenceStreamSuffixTokens {
    <#
      A COMMAND's path tokens with any NTFS stream suffix stripped, rejoined by spaces, or $null when no
      token carried a stream. Fed to Get-EvidencePathForms so the SHELL route's 8.3 alias inverts on the
      stream-free token: `cp MISSIO~1::$INDEX_ALLOCATION/gates/x` -> `MISSIO~1/gates/x` -> `.mission/gates`
      (validator round 2's out-of-scope observation; WP-E2 round 3). Add-never-substitute.
    #>
    param([AllowNull()][string]$Text)
    if (-not $Text) { return $null }
    $canon = ConvertTo-CanonicalPathText -Text $Text
    if (-not $canon) { return $null }
    $out = New-Object System.Collections.Generic.List[string]
    $changed = $false
    foreach ($tok in ($canon -split '[\s;|&,=<>()"''`]+')) {
        if (-not $tok) { continue }
        $st = Remove-EvidenceStreamSuffix -Path $tok
        if ($st) { [void]$out.Add($st); $changed = $true } else { [void]$out.Add($tok) }
    }
    if (-not $changed) { return $null }
    return ($out -join ' ')
}

function Get-EvidenceGuardDecision {
    param([string]$ToolName, $ToolInput, [AllowNull()][string]$Cwd = '')

    # WHERE THE PROCESS IS STANDING, set ONCE per hook invocation and consumed by every path
    # predicate below through Get-EvidencePathForms. Script scope rather than a parameter threaded
    # through nine predicates: the alternative is nine signatures changed and eight call sites that
    # could each forget it, which is how a class ends up cured in one member and not the others --
    # the defect this file has recorded four times. One assignment, one reader.
    #
    # Set to '' when the payload carries no cwd, which restores the previous behaviour exactly:
    # command-text forms only. Absent knowledge widens nothing and hides nothing.
    $script:EvidenceCwd = $Cwd

    $candidates = @()
    if ($null -ne $ToolInput -and $ToolInput -isnot [string]) {
        # AT ANY DEPTH, NOT ONLY AT THE TOP (V-1 round 19, a WP-5 finding, driven). These four names were
        # read off the tool input itself, so a payload carrying the path anywhere else produced no
        # candidate and every predicate below was asked about nothing -- `file_path` nested under
        # `edits[]` reached BOTH `.mission/gates` and `.mission/evidence` with ALLOW.
        #
        # BY KEY NAME, NEVER BY VALUE. Collecting every string in the graph would sweep up `content`,
        # and then writing any file whose TEXT quotes `.mission/gates/x.yaml` would be refused --
        # which this build does constantly, in documents and commit messages. A guard that refuses
        # those is worse than the hole it closes. Only values whose KEY is one of the four are taken.
        $pathKeys = @('file_path', 'path', 'notebook_path', 'filePath')
        # Kept separately so the ones A1 could not have seen can be OFFERED to it below. A top-level
        # value needs no offering: A1 reads those itself.
        $deepPaths = New-Object System.Collections.Generic.List[string]
        $pending = New-Object System.Collections.ArrayList
        [void]$pending.Add(@{ node = $ToolInput; depth = 0 })
        while ($pending.Count -gt 0) {
            $cur = $pending[0]; $pending.RemoveAt(0)
            $node = $cur.node
            if ($null -eq $node -or $cur.depth -gt 8) { continue }
            if ($node -is [string] -or $node -is [ValueType]) { continue }
            if ($node -is [System.Collections.IDictionary]) {
                foreach ($k in @($node.Keys)) {
                    $v = $node[$k]
                    if ($pathKeys -contains [string]$k) {
                        if ($v -is [string] -and $v) { $candidates += $v; if ($cur.depth -gt 0) { [void]$deepPaths.Add($v) } }
                    }
                    else { [void]$pending.Add(@{ node = $v; depth = $cur.depth + 1 }) }
                }
                continue
            }
            if ($node -is [System.Collections.IEnumerable]) {
                foreach ($item in $node) { [void]$pending.Add(@{ node = $item; depth = $cur.depth + 1 }) }
                continue
            }
            if ($node.PSObject -and $node.PSObject.Properties) {
                foreach ($prop in $node.PSObject.Properties) {
                    if ($pathKeys -contains [string]$prop.Name) {
                        if ($prop.Value -is [string] -and $prop.Value) {
                            $candidates += $prop.Value
                            if ($cur.depth -gt 0) { [void]$deepPaths.Add($prop.Value) }
                        }
                    } else {
                        [void]$pending.Add(@{ node = $prop.Value; depth = $cur.depth + 1 })
                    }
                }
            }
        }
    } elseif ($ToolInput -is [string]) { $candidates += $ToolInput }
    # THE PATH VALUES AS THE TOOL INPUT CARRIES THEM, before any augmentation below: the peer-worktree
    # rule at the foot of this function builds its own two form lists from these (b1s5 item 4).
    $peerRawPaths = @($candidates)

    # THE EXTENDED-LENGTH PREFIX STRIPPED, FIRST, because every augmentation below it runs through
    # the sealed canonicaliser and that is what destroys the prefix (V-1 round 10, WP-4). Offered as
    # an extra candidate so each later transform -- Win32 component form, 8.3 alias inversion, the
    # cwd join -- gets a chance at the shape underneath it.
    $candidates = @($candidates + @(
        $candidates | ForEach-Object { Remove-EvidenceExtendedLengthPrefix -Text $_ } |
                      Where-Object { $_ }
    ))

    # THE SHAPE THE FILESYSTEM WILL OPEN, offered beside the one that was typed (V-1 round 8, WP-4).
    # Win32 discards a component's trailing dots and spaces, so `.mission/gates./x.yaml` WRITES to
    # `.mission/gates/x.yaml` while every string comparison sees a different path. Driven end to end
    # by an independent reader: the gate was minted, listed by the real tool as a valid open
    # build-authorization gate, and a push then answered "authorized" and really published.
    #
    # Measured scope, which is wider than the report: the same dot defeats A1's ENTIRE protected
    # tier -- `.mission/evidence` and `.claude/settings.json` included -- not only the gate rule.
    # Additive: every candidate that was tested before is still tested.
    $candidates = @($candidates + @(
        $candidates | ForEach-Object { ConvertTo-EvidenceWin32ComponentForm -Path (ConvertTo-CanonicalPathText -Text $_) } |
                      Where-Object { $_ }
    ))

    # THE CWD-JOINED FORM REACHED THE SHELL ROUTE AND NOT THIS ONE (V-1 round 9, WP-4, T-3-b).
    #
    # `$cmdTextForPaths` below augments the shell route with cwd-joined forms; the file-tool
    # candidate list was augmented with the Win32 component form ONLY, so a RELATIVE `file_path` was
    # never offered in the form that says where it actually lands. The reader who found it recorded
    # its reachability as UNESTABLISHED -- the Write tool documents `file_path` as absolute, so the
    # harness may reject a relative one before the guard ever sees it -- and declined to inflate it
    # into a refutation on that basis.
    #
    # IT IS CURED ANYWAY, FOR TWO REASONS THAT DO NOT DEPEND ON THAT QUESTION. It is the same
    # two-routes-one-cured asymmetry this file has now recorded three times, and leaving a known
    # asymmetry in place because today's harness happens not to reach it is how the trailing-dot and
    # short-name spellings survived. And it is load-bearing for the 8.3 cure directly: a relative
    # `MISSIO~2/gates/x.yaml` has no rooted prefix to enumerate, so WITHOUT the cwd join there is
    # nothing for the alias expansion to resolve against.
    #
    # Additive in both directions: every candidate tested before is still tested.
    # ONE PASS, NOT TWO. `Get-EvidencePathForms` already emits the Win32 form AND the resolved 8.3
    # alias for every token it produces, so applying the alias expansion again here would be the
    # same call written twice -- the restated-predicate shape this file exists to stop repeating.
    $candidates = @($candidates + @(
        $candidates | ForEach-Object { Get-EvidencePathForms -Text $_ -Cwd $Cwd } |
                      Where-Object { $_ }
    ))

    # THE NTFS ALTERNATE-DATA-STREAM SPELLING, STRIPPED (WP-E2, E2-1). Offered here
    # BEFORE the gate rule and the marker rules below, and to A1's protected tier through the
    # file-tool offers further down, so a colon-stream on an interior component cannot read a gate or
    # a protected path past the two-component literals. Add-never-substitute, exactly as the Win32,
    # 8.3 and extended-length forms above: this can only ADD denials, and a stream on a component that
    # is not itself under a protected path yields a form that matches nothing (H-27's ALLOW controls).
    #
    # THE STRIPPED FORM IS RE-RESOLVED, NOT JUST STRIPPED (WP-E2 round 2; validator round 1's
    # refutation). A stream suffix on an 8.3 short-name component -- `MISSIO~1::$INDEX_ALLOCATION/gates`
    # -- defeats the alias resolver, because the stream breaks the component-name lookup, so the strip
    # alone yielded `MISSIO~1/gates` and never the gate literal `.mission/gates`. The T-3 gate rule
    # lives ONLY in the candidate loop below (A1 has no gate rule), so the resolved form has to reach
    # THIS list. Running the stripped form back through Get-EvidencePathForms gives its Win32, 8.3 and
    # cwd-joined shapes, so `.mission/gates` is judged here. Still add-never-substitute.
    $candidates = @($candidates + @(
        $candidates | ForEach-Object {
            $stripped = Remove-EvidenceStreamSuffix -Path (ConvertTo-CanonicalPathText -Text $_)
            if ($stripped) { $stripped; Get-EvidencePathForms -Text $stripped -Cwd $Cwd }
        } | Where-Object { $_ }
    ))

    # AN ALLOW-LIST OF FOUR NAMES GATED FOUR RULES, ONE OF WHICH CALLS ITSELF A HARD DENY FOR EVERY
    # ROLE WITH NO EXEMPTION (V-1 round 19, a WP-5 finding, driven). Measured on this library:
    # `.mission/evidence` denied for every tool name tried, because that tier judges the PATH; and
    # `.mission/gates` denied for Write/Edit/MultiEdit/NotebookEdit and ALLOWED for `FileWrite`,
    # `mcp__fs__write_file` and `CreateFile`. Same territory, same intent, one tier name-independent
    # and the other a blacklist by omission -- which is E116 in the shape E116 was written about.
    #
    # INVERTED RATHER THAN DELETED. Dropping the test entirely would apply these rules to `Read` and
    # `Grep` too, and denying a READ of a gate is not what T-3 says: a gate is meant to be readable
    # and unwritable. Shell tools keep their own command-text tier above and are not judged here on
    # the mere presence of a path token, which would refuse `cat` on an artifact anyone may read.
    #
    # DIRECTION CHECK, because this widens a guard: unchanged for the four names previously listed,
    # unchanged for read-only and shell tools, and applied for every unknown name. It can only ADD
    # denials.
    #
    # THE HONEST BOUND: `.claude/settings.json` routes PreToolUse for
    # `Write|Edit|MultiEdit|NotebookEdit|Bash|PowerShell` only, so a tool named anything else does
    # not reach this hook today. This is defence in depth rather than a door standing open -- and it
    # is worth having, because the matcher is one line in a file this build cannot edit while this
    # library is the thing being built.
    $readOnlyTools = @('Read', 'Glob', 'Grep', 'NotebookRead', 'LS', 'WebFetch', 'WebSearch',
                       'TodoWrite', 'Task', 'ExitPlanMode')
    $shellTools = @('Bash', 'PowerShell')
    if (-not ($readOnlyTools -contains $ToolName) -and -not ($shellTools -contains $ToolName)) {
        foreach ($c in $candidates) {
            if (Test-EvidenceOwnershipMarkerPath -Path $c) {
                return @{ decision = 'deny'
                          reason = "tool '$ToolName' targets the dispatch-boundary marker '$c'. OWNER and DISPATCH-END are written by the RUNNER, before spawn and after worker exit; a worker that could write them could declare its own dispatch finished and seal a manifest over a log it was still appending to" }
            }
            # T-3: hard-deny for EVERY role, no exemption and no role check -- there is no role for
            # which minting one's own authorization is legitimate.
            if (Test-EvidenceGatePath -Path $c) {
                return @{ decision = 'deny'
                          reason = "tool '$ToolName' targets '$c' under .mission/gates. Gate artifacts are created by a HUMAN and consumed once; an agent that could write one could authorize its own irreversible act, so this is denied for every role" }
            }
            # R-1: the supersession marker pattern.
            if (Test-EvidenceSupersessionMarkerPath -Path $c) {
                return @{ decision = 'deny'
                          reason = "tool '$ToolName' targets the supersession marker '$c'. A *.superseded.yaml marker retires a prior dispatch, and an agent placed one here with a plain copy before anything stopped it. Markers are operator-placed and operator-ratified: the runner honours one only against an unrevoked supersession gate binding its re-derived sha256. The worker's own handoff in this same directory is unaffected -- the rule is scoped to the marker suffix, not to the directory" }
            }
            # K-3 as amended: the worker's mission-plane restriction, enforced here
            # because the permission grammar cannot express deny-a-subtree-except-two-members.
            if ((Test-EvidenceDispatchedWorker) -and (Test-EvidenceWorkerPlanePath -Path $c -DispatchId $env:LAM_DISPATCH)) {
                return @{ decision = 'deny'
                          reason = "tool '$ToolName' targets '$c' under the mission plane, and this session is dispatched worker '$env:LAM_DISPATCH'. K-3 gives a worker exactly TWO closed exceptions under .mission/ -- its own evidence session (.mission/evidence/session-*/) and its own handoff (.mission/dispatches/<id>.handoff.yaml) -- and this is neither. The permission layer cannot express this rule: deny is evaluated before allow and a deny rule cannot carry allowlist exceptions, so a blanket deny there made BOTH exceptions inert instead. This is a tripwire, not a boundary: the denial is recorded, which is what a worker cannot get past silently" }
            }
        }
    }

    # T-2: the push guard. Evaluated before delegating, because A1's decision function knows
    # nothing about authorization -- it is an evidence guard, and this is a publication gate.
    $cmdText = $null
    if ($null -ne $ToolInput) {
        if ($ToolInput -is [string]) { $cmdText = $ToolInput }
        else { $cmdText = [string](Get-EntryField $ToolInput 'command' $null) }
    }

    # THE SAME COMMAND, PLUS WHAT ITS RELATIVE TOKENS ACTUALLY NAME FROM WHERE THE PROCESS STANDS.
    #
    # `Test-EvidenceGatePath` and the protected-tier matcher are A1's, SEALED, and they tokenise
    # with A1's own `Get-EvidencePathHits` -- so widening this file's `Get-EvidencePathForms` to
    # understand a cwd reached the delta's predicates and none of A1's. That is the disclosed
    # duplication this file already records: one predicate living in two places, and a cure applied
    # to one copy is not applied at all. I could not edit A1, so the cwd-joined forms are OFFERED to
    # every predicate as extra tokens instead -- appended text, which both tokenisers split the
    # same way.
    #
    # A SEPARATE VARIABLE, deliberately. `Test-EvidencePushCommand` scans for a positional
    # subcommand and must keep seeing the command the user actually typed; only the PATH predicates
    # get the augmented form. Mixing the two would make a push detector answer about tokens nobody
    # wrote.
    $cmdTextForPaths = $cmdText
    if ($cmdText) {
        $offer = New-Object System.Collections.Generic.List[string]
        # THE SAME COMMAND WITH ANY EXTENDED-LENGTH PREFIX REMOVED (V-1 round 10, WP-4), offered
        # before the form builders run so that they see the path underneath it. Additive: the
        # original text is still scanned exactly as before.
        $stripped = Remove-EvidenceExtendedLengthPrefix -Text $cmdText
        if ($stripped) {
            foreach ($f in @(Get-EvidencePathForms -Text $stripped -Cwd $Cwd)) { [void]$offer.Add($f) }
        }
        # AND THE STREAM-STRIPPED COMMAND (WP-E2 round 3; validator round 2's shell observation). Every
        # ADS name carries a `$`, so A1's metacharacter+parent tier refuses a PLAIN `.mission` stream --
        # but an 8.3 alias (`cp MISSIO~1::$INDEX_ALLOCATION/gates/x`) names no `.mission` literal and slips
        # it. Stripping each token's stream, then re-resolving through Get-EvidencePathForms, offers the
        # `.mission/gates` form to T-3 and A1. Additive.
        $streamStrippedCmd = Remove-EvidenceStreamSuffixTokens -Text $cmdText
        if ($streamStrippedCmd) {
            foreach ($f in @(Get-EvidencePathForms -Text $streamStrippedCmd -Cwd $Cwd)) { [void]$offer.Add($f) }
        }
        if ($Cwd) {
            foreach ($f in @(Get-EvidencePathForms -Text $cmdText -Cwd $Cwd | Where-Object { Test-EvidenceRootedPath -Path $_ })) {
                [void]$offer.Add($f)
            }
        }
        # AND THE WIN32 FORMS, by the same route and for the same reason (V-1 round 8, WP-4). A1's
        # matcher is sealed and cannot learn about trailing dots, so the resolved shape is OFFERED to
        # it as an extra token. This is the mechanism the cwd cure already established; a second
        # mechanism for the same job is how the two copies drifted in the first place.
        foreach ($f in @(Get-EvidencePathForms -Text $cmdText -Cwd $Cwd)) {
            $w = ConvertTo-EvidenceWin32ComponentForm -Path $f
            if ($w) { [void]$offer.Add($w) }
            # AND THE 8.3 ALIAS RESOLVED, offered to A1's sealed matcher by the same route (V-1
            # round 9, WP-4). A1 cannot learn about short names any more than it could learn about
            # trailing dots, so the resolved shape is handed to it as an extra token -- the mechanism
            # the cwd cure established and the trailing-dot cure reused.
            $l = ConvertTo-EvidenceLongNameForm -Path $f
            if ($l) { [void]$offer.Add($l) }
        }
        # ORDER-PRESERVING DEDUPE. `Sort-Object -Unique` reorders, and reordering these tokens
        # changed a guard verdict -- which is how the position dependence above was found. A
        # predicate whose answer depends on token order is a defect, and it has been fixed; keeping
        # the order stable as well means a denial record reads in the order the command was written.
        $seen = New-Object System.Collections.Generic.HashSet[string]
        $ordered = New-Object System.Collections.Generic.List[string]
        foreach ($o in $offer) { if ($seen.Add($o)) { [void]$ordered.Add($o) } }
        $offer = @($ordered)
        if ($offer.Count -gt 0) { $cmdTextForPaths = $cmdText + ' ' + ($offer -join ' ') }
    }
    # A LINK WHOSE RESOLVED TARGET LIES IN PROTECTED TERRITORY IS NOT CREATED (operator
    # ruling A). The glob expansion above closes the driven spelling, but a link to a protected
    # directory spelled IN FULL and carrying NO metacharacter reaches no tier at all: `.mission` is a
    # PARENT entry, and the parent tier fires only with a metacharacter. Driven: `New-Item -ItemType
    # Junction -Path l -Target .mission` ALLOWED before this rule and DENIED after. A link lets the
    # same bytes be addressed by a name containing no protected component, so the link itself is
    # the act to refuse, for every role. Both A1 arrays are consulted; if the sealed library did not
    # export them the six-plus-four literals below are what it holds, restated rather than guessed.
    if ($cmdText -and (Test-EvidenceLinkCreationCommand -Command $cmdText)) {
        $protPatterns = if ($script:EvidenceProtectedPaths) { @($script:EvidenceProtectedPaths) } else {
            @('.mission-runtime/evidence', '.mission/evidence', 'tools/framework/hooks',
              'tools/framework/install-evidence-hooks.ps1', 'tools/framework/tests', '.claude/settings.json') }
        $parentPatterns = if ($script:EvidenceParentPaths) { @($script:EvidenceParentPaths) } else {
            @('.mission-runtime', '.mission', 'tools/framework', '.claude') }
        foreach ($lf in @(Get-EvidencePathForms -Text $cmdText -Cwd $Cwd)) {
            if (-not $lf) { continue }
            $inProtected = (@(Get-EvidencePathHits -Text $lf -Patterns $protPatterns).Count -gt 0) -or
                           (@(Get-EvidencePathHits -Text $lf -Patterns $parentPatterns).Count -gt 0) -or
                           (Test-EvidenceGatePath -Path $lf)
            if ($inProtected) {
                return @{ decision = 'deny'
                          reason = "the command creates a filesystem LINK (junction, symbolic or hard) and one of its resolved path forms, '$lf', lies in protected territory. A link lets the same bytes be addressed by a name that contains no protected component -- which is how a glob-denoted junction wrote into .mission (operator ruling A). A link whose resolved target is protected is refused for every role; a link to unprotected territory is not judged here" }
            }
        }
    }

    # AN AUTHORISED PUSH IS NOT A BLANKET ALLOW FOR THE COMMAND THAT CARRIES IT. This branch used to
    # `return allow` outright, which short-circuited every rule below it: with a valid gate in place,
    # `git push origin main; rm -rf .mission/evidence` was PERMITTED, while the `rm` on its own
    # denied. Found by an independent validator (WP-4, V-1 round 2). A gate authorises the ACT it
    # names and nothing else that happens to share a command line, so the push verdict is now
    # recorded and evaluation CONTINUES through every remaining check.
    $pushAuthorizedReason = $null
    # THE FINDING IS TAKEN ONCE, AND IT CHOOSES THE SENTENCE -- NEVER THE DECISION.
    #
    # `$gitClass` is exactly what `Test-EvidencePushCommand` answers, un-collapsed: 'push' when a
    # segment really carries a publication, 'unreadable' when the command names a git executable and
    # carries an expansion the guard cannot evaluate, 'none' otherwise. The branch condition below is
    # `-ne 'none'`, which is the same predicate this site used before, so EVERY VERDICT IS
    # UNCHANGED -- including the one nobody asks about: an unreadable command under an OPEN gate
    # bound to this tip still falls through and evaluation continues, exactly as it did. That is
    # disclosed rather than quietly hardened, because "do not move a verdict" has to mean the whole
    # truth table and not only the interesting row.
    #
    # WHAT CHANGES IS THE SENTENCE. The earlier refusal named a gate and quoted a tip sha at a command
    # that attempted no push, and the operator had to reconstruct from the ledger what had actually
    # happened. The unreadable branch now says what the guard saw and how to re-issue the command.
    $gitClass = Get-EvidenceGitRefusalClass -Command $cmdText
    if ($gitClass -ne 'none') {
        $root = $null
        try { $root = Get-EvidenceRepoRoot } catch { $root = $null }
        if (-not $root) {
            if ($gitClass -eq 'unreadable') {
                return @{ decision = 'deny'
                          reason = "the guard could not READ this command: it names a git executable AND carries a shell expansion -- a dollar-paren, a dollar-brace, a backtick, an ANSI-C quote or a bare dollar-variable -- whose value does not exist yet. NO PUSH WAS DETECTED and none is claimed. The repository root could not be resolved either, so nothing further was checked. Re-issue the command with the expansion removed: take a commit message from a file with -F <path> rather than from a heredoc or a variable, and keep backticks out of the message body" }
            }
            return @{ decision = 'deny'
                      reason = "a push was attempted but the repository root could not be resolved, so no authorization could be checked. A publication gate that cannot read its own artifacts refuses" }
        }
        # THE GATE MUST ANSWER FOR THE REPOSITORY BEING PUSHED, not for the session's project
        # (V-1 round 3, WP-4). `git -C <other repo> push` was authorized by a gate bound to a
        # different repository's sha until this line existed.
        $targetRoot = Get-EvidencePushTargetRoot -Command $cmdText
        if ($targetRoot) {
            # RESOLVE AGAINST THE PAYLOAD'S cwd, NOT THE HOOK PROCESS'S (V-1 round 8, WP-4).
            # `Resolve-Path` resolves a relative path against wherever THIS process happens to
            # stand. With the hook standing in the session project and the payload cwd in another
            # repository, `git -C . push origin main` was allowed on the SESSION's gate and really
            # published the OTHER repo, tombstoning the session's gate. Control: a bare `git push`
            # from the same cwd correctly denied -- so the defect is the relative token alone.
            #
            # This is round 6's lesson at the one site that still resolves a relative path: the cwd
            # was plumbed into this file and then not used where it decides which repository an act
            # publishes.
            $probeRoot = $targetRoot
            if ($script:EvidenceCwd -and -not (Test-EvidenceRootedPath -Path (ConvertTo-CanonicalPathText -Text $targetRoot))) {
                $probeRoot = Join-Path $script:EvidenceCwd $targetRoot
            }
            $resolved = $null
            try { $resolved = Get-EvidenceRepoTopLevel -Path ((Resolve-Path -LiteralPath $probeRoot -ErrorAction Stop).Path) } catch { $resolved = $null }
            if (-not $resolved) {
                if ($gitClass -eq 'unreadable') {
                    return @{ decision = 'deny'
                              reason = "the guard could not READ this command: it names a git executable AND carries a shell expansion -- a dollar-paren, a dollar-brace, a backtick, an ANSI-C quote or a bare dollar-variable -- whose value does not exist yet. NO PUSH WAS DETECTED and none is claimed. The repository the command names could not be resolved either, so nothing further was checked. Re-issue the command with the expansion removed: take a commit message from a file with -F <path> rather than from a heredoc or a variable, and keep backticks out of the message body" }
                }
                return @{ decision = 'deny'
                          reason = "a push names repository '$targetRoot', which could not be resolved, so no authorization could be checked against it. A publication gate that cannot identify the repository it is answering for refuses" }
            }
            $root = $resolved
        }
        $v = Get-EvidencePushGateVerdict -Root $root
        if (-not $v.ok) {
            # THE UNREADABLE SENTENCE NAMES NO GATE AND QUOTES NO TIP SHA. `$v.reason` is deliberately
            # NOT interpolated here: it is the answer to a question this command never asked, and
            # printing it is what made an operator hunt for a publication that never happened.
            # Same decision, same gate state, different sentence.
            if ($gitClass -eq 'unreadable') {
                return @{ decision = 'deny'
                          reason = "the guard could not READ this command: it names a git executable AND carries a shell expansion -- a dollar-paren, a dollar-brace, a backtick, an ANSI-C quote or a bare dollar-variable -- whose value does not exist yet, so the command cannot be classified at all. NO PUSH WAS DETECTED, and no publication gate was named, consumed or revoked on its account. Re-issue the command with the expansion removed: take a commit message from a file with -F <path> rather than from a heredoc or a variable, and keep backticks out of the message body" }
            }
            return @{ decision = 'deny'
                      reason = "push is BLOCKED: $($v.reason). Publishing to origin is an operator-gated irreversible (design SS10.5, ADR-033) -- a human creates the gate with tools/lam/mission-gate.ps1 approve -Kind push, bound to the exact tip" }
        }
        $pushAuthorizedReason = $v.reason
    }
    # THE ACT, PLACED ABOVE THE SPELLING. The test below still
    # catches a command that NAMES the gates directory; this one catches the mint that never has to.
    #
    # JUDGED ON $cmdText, NOT ON $cmdTextForPaths, AND DELIBERATELY. This is a tool+verb scan, and
    # the path-augmented text carries tokens nobody wrote -- resolved forms, cwd joins, 8.3 aliases.
    # The reason this file already gives for keeping Test-EvidencePushCommand on the raw text
    # applies unchanged here: a predicate about what the agent INVOKED must not answer about text
    # the guard synthesised.
    #
    # ABOVE the path test so the denial names the act. A mint that happened to spell the gates
    # directory as well would otherwise be refused with a sentence about territory, and the unreadable sentence above is
    # this build's record of what a refusal under the wrong sentence costs an operator.
    #
    # NOT IN THE FILE-TOOL BRANCH ABOVE: that branch iterates extracted FILE PATHS and is skipped
    # for shell tools by construction. A file tool cannot spawn a process, so there is no act there
    # for this predicate to see, and the Write-deny it already carries is unchanged.
    if ($cmdText -and (Test-EvidenceGateToolMutation -Command $cmdText)) {
        return @{ decision = 'deny'
                  reason = "the command invokes mission-gate.ps1 with a gate-MUTATING verb. THE GATES DIRECTORY NEED NEVER APPEAR IN THE COMMAND: mission-gate.ps1 computes it from -MissionRoot inside the child process, so the rule that matched only the literal text '.mission/gates' allowed an agent to mint its own open single-use push gate -- driven, allow, exit 0, artifact on disk, read back by the real tool as an open build-authorization. A gate is created by a HUMAN (T-3, design SS10.5 / ADR-033) and this is denied for every role, because there is no role for which minting one's own authorization is legitimate. Only 'list' is admitted -- an absent, unreadable or ambiguous verb is refused, because a guard that allows when it cannot see is not a guard. READING the tool is not refused: 'cat', 'grep' and 'Get-Content' over tools/lam/mission-gate.ps1 are allowed, since T-3 makes a gate unwritable, not unreadable. If this is legitimate operator work, run mission-gate.ps1 outside the session" }
    }
    if (Test-EvidenceGatePath -Path $cmdTextForPaths) {
        return @{ decision = 'deny'
                  reason = "the command references .mission/gates, which is human-authored territory: an agent that could write a gate could authorize its own irreversible act" }
    }
    # The SHELL path for the marker rule, and it is the one that actually mattered: the marker this
    # build had to retro-ratify was placed by a plain `cp`, not by a file tool. A rule that guarded
    # only the write tools would have missed the exact way it happened.
    if (Test-EvidenceSupersessionMarkerPath -Path $cmdTextForPaths) {
        return @{ decision = 'deny'
                  reason = "the command names a *.superseded.yaml supersession marker. Markers retire a prior dispatch and are operator-placed; the one this build had to retro-ratify was created by a plain copy, which is why the rule covers commands and not only the write tools" }
    }
    # THE SHELL ROUTE FOR THE WORKER-PLANE RULE, and it is not the lesser half. Every plane write
    # this build actually had to chase -- the minted gate, the placed marker, the copied handoff --
    # arrived by a plain shell copy rather than by a file tool. A rule that guarded only the write
    # tools would have missed each one.
    if ((Test-EvidenceDispatchedWorker) -and (Test-EvidenceWorkerPlanePath -Path $cmdTextForPaths -DispatchId $env:LAM_DISPATCH)) {
        return @{ decision = 'deny'
                  reason = "the command names a mission-plane path outside the worker's two closed exceptions, and this session is dispatched worker '$env:LAM_DISPATCH'. A worker writes its own evidence session and its own handoff; the rest of .mission/ belongs to the orchestrator and to ceremony. Scoped to a dispatched worker on purpose -- a role-blind rule here would refuse git add of the mission ledger and amendment placement, which is ordinary ceremony this guard exists to protect" }
    }

    # THE PATH-FRAGMENT EVASION (batch 1 session 4, ITEM 2). A protected/parent path assembled from
    # fragments -- '.mis'+'sion', chr(46)+'mission-runtime', Join-Path '.mission' 'evidence', or a
    # variable literal-assigned earlier and then joined -- carries no literal protected substring, so
    # A1's matcher below and the $ShellMetaPattern gate (which holds none of '+', a quote, or `chr`)
    # both miss it. Reconstruct only what the guard can STATICALLY READ, from the RAW command text
    # (not $cmdTextForPaths, whose cwd/Win32 augmentation is a different concern), and deny a hit the
    # raw text does not already carry. Wrapped so a reconstruction bug can only FAIL TO ADD a denial,
    # never fail an ordinary command closed -- an additive layer must preserve existing verdicts when
    # it errors. Runtime expansions are NOT judged here; they refuse via the git 'unreadable' class.
    if ($cmdText) {
        $asmHit = $null
        try { $asmHit = Test-EvidenceAssembledPathHit -Command $cmdText } catch { $asmHit = $null }
        if ($asmHit) {
            return @{ decision = 'deny'
                      reason = "the command STATICALLY ASSEMBLES the protected path '$asmHit' from fragments (string-literal concatenation, a chr()/[char] constant, Join-Path/[IO.Path]::Combine over literal components, or a variable literal-assigned earlier in the same command). No single literal token spells '$asmHit', which is how a fragmented spelling slips past both the protected-path matcher and the metacharacter gate; a readable assembly of protected territory is refused for every role. Runtime expansions (`$env, `${VAR}, `$(...), backticks, %VAR%, a bare variable never literal-assigned here) are NOT judged here -- the guard cannot read them, and they refuse via the unreadable class instead" }
        }
    }

    # A1 STILL GETS THE LAST WORD, EVEN ON AN AUTHORISED PUSH. Its metacharacter tier and protected
    # paths are what catch the rest of a compound command, and skipping them was the hole above.
    # A1 GETS THE RESOLVED FORMS TOO, AND THIS IS THE HALF THAT MATTERS MOST. The protected tier
    # -- .mission-runtime/evidence, .mission/evidence, tools/framework/hooks, .claude/settings.json
    # -- is A1's, and it is a far wider surface than the three predicates above. Handing the
    # augmented text only to this file's own checks would have cured the gates directory and left
    # `cd .mission-runtime` + `cd evidence` + a relative write untouched: the same defect, one
    # directory over, which is exactly the shape this build keeps re-finding.
    #
    # The input is COPIED rather than mutated: the caller's object is not ours to edit, and a
    # predicate that silently rewrites what it was asked about is a poor witness.
    $a1Input = $ToolInput
    if ($cmdTextForPaths -ne $cmdText -and $null -ne $ToolInput -and $ToolInput -isnot [string]) {
        $a1Input = @{}
        foreach ($prop in $ToolInput.PSObject.Properties) { $a1Input[$prop.Name] = $prop.Value }
        $a1Input['command'] = $cmdTextForPaths
        $a1Input = [pscustomobject]$a1Input
    }
    elseif ($cmdTextForPaths -ne $cmdText -and $ToolInput -is [string]) { $a1Input = $cmdTextForPaths }
    $a1 = & $script:A1_GetEvidenceGuardDecision -ToolName $ToolName -ToolInput $a1Input
    if ($a1.decision -eq 'deny') { return $a1 }

    # AND THE PATHS A1 CANNOT SEE, OFFERED TO IT ONE AT A TIME (V-1 round 19, a WP-5 finding).
    # A1 extracts `file_path`/`path`/`notebook_path`/`filePath` from the TOP LEVEL of the tool input,
    # so a payload nesting the path -- `edits[].file_path` -- reached this file's gate predicate after
    # the depth-walk above and still reached A1's protected tier as nothing at all. Curing one and
    # not the other is the asymmetry the comment above this delegation warns about in as many words.
    #
    # The same mechanism, not a second one: the value is placed where A1 looks and A1 is asked again.
    # Only paths found BELOW the top level are re-offered, since a top-level one has already been
    # judged. Additive -- this can turn an allow into a deny and never the reverse.
    if ($deepPaths -and $deepPaths.Count -gt 0) {
        foreach ($dp in $deepPaths) {
            $offerInput = @{}
            if ($null -ne $ToolInput -and $ToolInput -isnot [string]) {
                foreach ($prop in $ToolInput.PSObject.Properties) { $offerInput[$prop.Name] = $prop.Value }
            }
            # THE NESTED PATH GETS THE FULL A1-OFFER FORM SET (WP-E2 round 3; validator round 2). The
            # round-2 deep offer stripped the stream but did NOT re-resolve the 8.3 alias, so a nested
            # `MISSIO~1::$INDEX_ALLOCATION/evidence/p.txt` reached A1's protected tier un-inverted and was
            # ALLOWED for the root-seat role. It now uses the same Get-EvidenceA1OfferForms builder the
            # top-level offer uses, so the two cannot diverge.
            foreach ($dpForm in @(@($dp) + @(Get-EvidenceA1OfferForms -Value $dp -Cwd $Cwd) | Where-Object { $_ })) {
                $offerInput['file_path'] = $dpForm
                $deep = & $script:A1_GetEvidenceGuardDecision -ToolName $ToolName -ToolInput ([pscustomobject]$offerInput)
                if ($deep.decision -eq 'deny') { return $deep }
            }
        }
    }

    # AND THE FILE-TOOL ROUTE GETS THE SAME OFFER (V-1 round 8, WP-4). The augmentation above
    # rewrites `command`, which is the SHELL route; a file tool carries its path in `file_path` and
    # reached A1 undecorated. Measured: `cp x .claude./settings.json` DENIED while a `Write` to
    # `.claude./settings.json` was ALLOWED -- the same path, the same rule, two routes, one cured.
    #
    # A1 is sealed and cannot learn what Win32 does to a trailing dot, so it is asked again about
    # the shape the filesystem will actually open. Asking twice is the established route in this
    # file for exactly this reason; re-implementing A1's protected tier here would be the
    # duplication that produced this class in the first place.
    if ($null -ne $ToolInput -and $ToolInput -isnot [string]) {
        foreach ($fieldName in @('file_path', 'path', 'notebook_path', 'filePath')) {
            $v = Get-EntryField $ToolInput $fieldName $null
            if ($v -isnot [string] -or -not $v) { continue }
            # EVERY RESOLVED SPELLING, NOT ONE OF THEM (V-1 round 9, WP-4). This loop offered A1 the
            # Win32 trailing-dot form and nothing else, so the 8.3 short-name alias reached A1's OWN
            # protected tier undecorated. MEASURED, with controls: a `Write` to
            # `<root>/MISSIO~1/evidence/p.txt` was ALLOWED while the same path spelled
            # `.mission/evidence/p.txt` DENIED, and the SHELL spelling of the identical act denied --
            # because the shell route hands A1 its augmented text and this one did not. One route
            # cured and one not, which is the shape this file has now recorded four times.
            #
            # THE PATH IS NOT TOKENISED HERE, deliberately. `Get-EvidencePathForms` splits its input
            # on whitespace and operators, which is right for a COMMAND and wrong for a `file_path`:
            # a path containing a space would be offered to A1 as two fragments, and a fragment that
            # happened to match a protected pattern would deny a write nobody made. So the transforms
            # are applied to the whole path.
            # THE FULL A1-OFFER FORM SET, from the shared builder (WP-E2 round 3): canon, de-prefixed,
            # Win32, 8.3, stream-stripped + Win32/8.3, and the cwd-joined shapes. The nested (deep) offer
            # above uses the SAME builder, so the two routes cannot drift (validator round 2's refutation).
            $forms = @(Get-EvidenceA1OfferForms -Value $v -Cwd $Cwd)
            if ($forms.Count -eq 0) { continue }
            foreach ($form in $forms) {
                $alt = @{}
                foreach ($prop in $ToolInput.PSObject.Properties) { $alt[$prop.Name] = $prop.Value }
                $alt[$fieldName] = $form
                $altDecision = & $script:A1_GetEvidenceGuardDecision -ToolName $ToolName -ToolInput ([pscustomobject]$alt)
                if ($altDecision.decision -eq 'deny') { return $altDecision }
            }
        }
    }

    # THE PEER-WORKTREE RULE (b1s5 item 4), AND IT IS LAST ON PURPOSE. Every rule above has already run
    # and returned its own refusal, so this block can only turn an allow into a deny: it cannot suppress
    # a hit, cannot re-word one, and cannot short-circuit anything but the two allow exits below it.
    # Worker only -- the seat never evaluates it. The three branches are the file-tool route, the shell
    # route and the path-fragment route; see the block above Get-EvidencePeerWorktreeHit for the rulings.
    if (Test-EvidenceDispatchedWorker) {
        $peerId = [string]$env:LAM_DISPATCH
        $peerHit = $null
        $peerRoute = ''
        $peerCtx = $null
        try {
            $peerCtx = Get-EvidencePeerWorktreeContainers -Cwd $Cwd -DispatchId $peerId
            # FILE-TOOL ROUTE: the same tool names the file-tool branch above judges.
            if (-not ($readOnlyTools -contains $ToolName) -and -not ($shellTools -contains $ToolName)) {
                foreach ($pv in @($peerRawPaths)) {
                    $peerHit = Get-EvidencePeerWorktreeHit -Text $pv -Cwd $Cwd -DispatchId $peerId -Context $peerCtx -WholePath
                    if ($peerHit) { $peerRoute = 'file-tool'; break }
                }
            }
            # SHELL ROUTE: the command as typed, for every tool that carries one.
            if (-not $peerHit -and $cmdText) {
                $peerHit = Get-EvidencePeerWorktreeHit -Text $cmdText -Cwd $Cwd -DispatchId $peerId -Context $peerCtx
                if ($peerHit) { $peerRoute = 'shell' }
            }
        } catch {
            return @{ decision = 'deny'
                      reason = "PEER WORKTREE: the peer-worktree rule could not evaluate this call ($($_.Exception.Message)) and this session is dispatched worker '$peerId'. A guard that cannot see refuses; the seat is unaffected (b1s5 item 4)" }
        }
        # PATH-FRAGMENT ROUTE: every statically-readable assembly, judged by the same predicate. Wrapped
        # the way the fragment detector above is: a reconstruction error fails to ADD a denial.
        if (-not $peerHit -and $cmdText) {
            try {
                foreach ($asm in @(Get-EvidenceAssemblyReadablePaths -Command $cmdText)) {
                    if (-not $asm) { continue }
                    $peerHit = Get-EvidencePeerWorktreeHit -Text $asm -Cwd $Cwd -DispatchId $peerId -Context $peerCtx
                    if ($peerHit) { $peerRoute = 'path-fragment'; break }
                }
            } catch { $peerHit = $null }
        }
        if ($peerHit) {
            return @{ decision = 'deny'
                      reason = (Get-EvidencePeerWorktreeDenyReason -Hit $peerHit -DispatchId $peerId -Route $peerRoute) }
        }
    }
    # THE WORKER RECURSIVE-DELETE RULE (b1s6 item 2), AFTER THE PEER RULE AND LAST ON PURPOSE. Every rule
    # above -- the peer rule included -- has already returned its own refusal, so this branch can only turn
    # an allow into a deny and never re-words a refusal. Worker only: the seat never evaluates it. The block
    # above Test-EvidenceRecursiveDeleteMentioned carries the order, the rulings, the forks and the bounds.
    # An exception past the pre-screen arrives as condition 'error' and is refused (FORK F4).
    if ((Test-EvidenceDispatchedWorker) -and $cmdText) {
        $rdId = [string]$env:LAM_DISPATCH
        $rdFinding = Get-EvidenceRecursiveDeleteFinding -Command $cmdText -Cwd $Cwd -DispatchId $rdId
        if ($null -ne $rdFinding) {
            return @{ decision = 'deny'
                      reason = (Get-EvidenceRecursiveDeleteDenyReason -Finding $rdFinding -DispatchId $rdId) }
        }
    }
    # THE SEAT TRIPWIRE (WP-E, E-2), LAST AND DENY-ONLY.
    # The block above Get-EvidenceSeatSessionLink carries the condition, the worker fork and the bounds.
    # Every role reaches it; only a session whose project directory is a LINKED worktree (or cannot be read
    # as a main checkout) reaches the territory test, so a root seat's call is decided exactly as before.
    $seatLink = Get-EvidenceSeatSessionLink
    if ($seatLink.state -eq 'linked' -or $seatLink.state -eq 'unreadable') {
        $seatHit = $null
        try {
            $seatHit = Get-EvidenceSeatTripwireHit -ToolName $ToolName -RawPaths @($peerRawPaths) -CmdText $cmdText -Cwd $Cwd `
                                                   -ReadOnlyTools $readOnlyTools -ShellTools $shellTools -Worker ([bool](Test-EvidenceDispatchedWorker)) `
                                                   -Roots @($seatLink.roots)
        } catch {
            return @{ decision = 'deny'
                      reason = ("SEAT TRIPWIRE: the tripwire could not evaluate this call (" + $_.Exception.Message + ") and this session's project directory '" + $seatLink.anchor + "' is a linked worktree or could not be read as a main checkout. A guard that cannot see refuses (law 1); a root seat is unaffected (WP-E, E-2)") }
        }
        if ($null -ne $seatHit) {
            return @{ decision = 'deny'; reason = (Get-EvidenceSeatTripwireDenyReason -Hit $seatHit -Link $seatLink) }
        }
    }
    if ($pushAuthorizedReason) {
        return @{ decision = 'allow'; reason = "push authorized: $pushAuthorizedReason (and every other rule was still evaluated for this command)" }
    }
    return $a1
}

# =================================================================================================
# THE MISSION-EVENT FEED (UI-1 S1; LM2-ADR-045; expanded-schemas SS14 "Mission Event")
# =================================================================================================
# One append-only, never-committed file per checkout, .mission-runtime/telemetry/events.jsonl, read only by
# `vanguard ui`. It is a PROJECTION SOURCE, NOT EVIDENCE: nothing in it is consumed as proof, and a report
# cites the artifact a line points at (source_path@sha256), never the line.
#
# APPENDED HERE, AT THE END OF THE FILE, AND NOTHING ABOVE IS TOUCHED. LAM-INSTALL SS5.2 cites this file by
# line range (4188-4264) and WP-5 K-4 compares five of its functions token for token; a function added above
# them would move every one of those citations.
#
# THE RULES THIS SECTION KEEPS (SS14 "Rules"):
#   * the append never blocks and never fails the call or verb that caused it: one buffered write under a
#     named mutex per file path, a 500 ms bounded wait, and on ANY failure no line, no gap, and one line in
#     the hook's own hook-errors.log naming the failed append;
#   * the emitter never creates the telemetry folder -- the installer's step (Register-MissionCheckout, which
#     mission init runs) does; a folder that is missing is a failure, recorded;
#   * no payload carries stdout, stderr, command text, file contents or model output.
#
# WHO IS A STREAM. A checkout is a telemetry stream when it carries .mission/mission.yaml with an id AND the
# host registry (<home>/projects.yaml, home = $env:VANGUARD_HOME or ~/.vanguard) holds a row for THAT
# checkout -- a worktree is registered as itself. Anything else -- a test sandbox, this framework checkout, a
# project never initialised on this host -- is not a stream, and the emitter returns at once and writes
# NOTHING, not even an error line: the registry entry IS the stream identity (SS14 "File"), so a checkout
# without one has no feed to have failed to append to. Without this rule every sandbox the A1 negative
# suite drives would grow a hook-errors.log it asserts is absent.

$script:MissionEventSchemaVersion = '1.0'
$script:MissionEventLockWaitMs    = 500
$script:MissionEventUuidPattern   = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

function Get-MissionVanguardHome {
    # $VANGUARD_HOME (environment) overrides ~/.vanguard.
    if ($env:VANGUARD_HOME) { return $env:VANGUARD_HOME }
    $prof = $env:USERPROFILE
    if (-not $prof) { $prof = $env:HOME }
    if (-not $prof) { return '' }
    return (Join-Path $prof '.vanguard')
}

function Get-MissionTelemetryScalar {
    # A column-0 YAML scalar, ONE key or none: two keys of one name answer $null rather than a guess.
    param([AllowNull()][string]$Text, [string]$Key)
    if (-not $Text) { return $null }
    $ms = [regex]::Matches($Text, '(?m)^' + [regex]::Escape($Key) + ':[ \t]*([^\s#][^\r\n#]*?)[ \t]*(?:#.*)?\r?$')
    if ($ms.Count -ne 1) { return $null }
    $v = $ms[0].Groups[1].Value.Trim().Trim('"', "'")
    if ($v -eq '' -or $v -eq 'null' -or $v -eq '~') { return $null }
    return $v
}

function ConvertTo-MissionEventRelPath {
    # The repo-relative, forward-slash form of a path under $Root, or $null for a path outside it.
    param([string]$Root, [AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    $p = $Path
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $Root ($p -replace '/', '\') }
    $full = [System.IO.Path]::GetFullPath($p)
    $base = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + '\'
    if (-not $full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
    return ($full.Substring($base.Length) -replace '\\', '/')
}

function Get-MissionTelemetryGitFacts {
    # ONE git call for HEAD and the common directory. git absent (or no commit yet): commit is $null, which
    # SS14 shows as "no commit".
    param([string]$Root)
    $res = @{ commit = $null; common = $null }
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue)
    if ($git.Count -eq 0) { return $res }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $o = @(& $git[0].Source -C $Root rev-parse --path-format=absolute HEAD --git-common-dir 2>$null | ForEach-Object { "$_".Trim() })
        if ($LASTEXITCODE -eq 0 -and $o.Count -ge 2) {
            if ($o[0] -cmatch '^[0-9a-f]{40}$') { $res.commit = $o[0] }
            $res.common = $o[1]
        }
    } catch { } finally { $ErrorActionPreference = $prev }
    return $res
}

function Get-MissionTelemetryContext {
    # $null = this checkout is not a telemetry stream (see WHO IS A STREAM above); otherwise what a line needs.
    param([string]$Root)
    $mf = Join-Path $Root '.mission\mission.yaml'
    if (-not (Test-Path -LiteralPath $mf -PathType Leaf)) { return $null }
    $missionId = Get-MissionTelemetryScalar -Text ([System.IO.File]::ReadAllText($mf)) -Key 'id'
    if (-not $missionId) { return $null }
    $vh = Get-MissionVanguardHome
    if (-not $vh) { return $null }
    $reg = Join-Path $vh 'projects.yaml'
    if (-not (Test-Path -LiteralPath $reg -PathType Leaf)) { return $null }
    $rows = @()
    foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($reg), "(?m)^\s*(?:-\s+)?checkout_path:\s*'((?:[^']|'')*)'\s*\r?$")) {
        $rows += ($m.Groups[1].Value -replace "''", "'").TrimEnd('\', '/')
    }
    # THE ROW MUST BE THIS CHECKOUT'S OWN -- a worktree included (ADR-045: the stream identity is the registry
    # entry (host, checkout path)). A worktree is registered as itself (Register-MissionWorktree, the runner;
    # mission.ps1 register by hand), which also makes its folder; one nobody registered is not a stream and
    # writes nothing, rather than failing one append per call into a folder no one will make.
    $here = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $registered = $false
    foreach ($r in $rows) { if ([string]::Equals($here, $r, [System.StringComparison]::OrdinalIgnoreCase)) { $registered = $true } }
    if (-not $registered) { return $null }
    $git = Get-MissionTelemetryGitFacts -Root $Root
    $hostId = ''
    $hp = Join-Path $vh 'host-id'
    if (Test-Path -LiteralPath $hp -PathType Leaf) { $hostId = ([System.IO.File]::ReadAllText($hp)).Trim() }
    $dir = Join-Path $Root '.mission-runtime\telemetry'
    return @{ mission_id = $missionId; host_id = $hostId; host_id_path = $hp; commit = $git.commit
              dir = $dir; path = (Join-Path $dir 'events.jsonl') }
}

function Test-MissionTelemetryStream {
    # Is $Root a telemetry stream? Every error path OUTSIDE Write-MissionEvent asks this first, so a checkout
    # that is not a stream never gains a hook-errors.log line on the feed's account.
    param([string]$Root)
    try { return ($null -ne (Get-MissionTelemetryContext -Root $Root)) } catch { return $false }
}

function Write-MissionTelemetryError {
    # THE ONE TRACE OF A FAILED APPEND (SS14): a line in the hook's own hook-errors.log, the per-dispatch file
    # Get-EvidenceState already points a reader at. A verb has no session; it writes to the dispatch the
    # environment or CURRENT_DISPATCH names, else session-unknown -- the same order A1's resolver uses, taken
    # from $Root and not from the library's own location. This function itself never throws.
    param([string]$Root, [string]$Hook, [string]$Message, [string]$SessionId = '', [string]$DispatchId = '')
    try {
        $did = $DispatchId
        if (-not $did) { $did = $env:MISSION_DISPATCH_ID }
        if (-not $did) {
            $ptr = Join-Path $Root '.mission-runtime\evidence\CURRENT_DISPATCH'
            if (Test-Path -LiteralPath $ptr -PathType Leaf) { $did = ([System.IO.File]::ReadAllText($ptr)).Trim() }
        }
        if (-not $did) { $did = $(if ($SessionId) { "session-$SessionId" } else { 'session-unknown' }) }
        $p = Get-EvidenceHookErrorPath -Root $Root -DispatchId $did
        $d = Split-Path -Parent $p
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        Add-Content -LiteralPath $p -Value "$(Get-UtcStampZ) ${Hook}: $Message"
    } catch { }
}

function Write-MissionEvent {
    <#
      THE EMITTER. Appends ONE mission-event line to <Root>\.mission-runtime\telemetry\events.jsonl and
      returns $true, or writes nothing to the feed, records the failure in hook-errors.log and returns $false.
      It never throws and never writes to the pipeline anything but its one boolean.

      seq is allocated UNDER THE LOCK from the file's own last line: a named mutex per file path, waited on
      for at most 500 ms, then the file opened (FileShare.Read, so a reader can tail it) within the same
      500 ms. The line is ONE buffered write ending in LF; if the file does not end in LF (a torn write by
      something else) an LF goes first, so a line is never glued onto a partial one.

      $SourcePath is the artifact the event derives from, repo-relative (an absolute path under $Root is
      converted); sha256 is that file's raw bytes now, after the write that caused the event. A source that
      is not on disk is a failure: SS14 rejects a line without its sha256 at ingest, so none is written.
    #>
    # -ChangeField names a payload field whose value must DIFFER from the one on the feed's last line of the
    # same kind for the line to be written; the comparison is made UNDER THE LOCK, so two concurrent writers of
    # one unchanged value write it once. A suppressed line is not a failure: $false, and nothing is recorded.
    param([string]$Root, [string]$Kind, $Payload, [string]$SourcePath, [string]$Hook = 'telemetry',
          [string]$SessionId = '', [string]$DispatchId = '', [string]$ChangeField = '')
    $mutex = $null; $owned = $false; $fs = $null
    try {
        $ctx = Get-MissionTelemetryContext -Root $Root
        if ($null -eq $ctx) { return $false }
        if ($ctx.host_id -cnotmatch $script:MissionEventUuidPattern) { throw "the host has no usable host-id at $($ctx.host_id_path)" }
        if (-not (Test-Path -LiteralPath $ctx.dir -PathType Container)) {
            throw "the telemetry folder .mission-runtime/telemetry is missing (the installer makes it; the emitter makes no directory)"
        }
        $rel = ConvertTo-MissionEventRelPath -Root $Root -Path $SourcePath
        if (-not $rel) { throw "the source path '$SourcePath' is not under the checkout" }
        $sha = Get-Sha256OfFile -Path (Join-Path $Root ($rel -replace '/', '\'))
        if (-not $sha) { throw "the source '$rel' is not on disk, so the line would carry no sha256" }
        if ($null -eq $Payload) { $Payload = [ordered]@{} }

        $full = [System.IO.Path]::GetFullPath($ctx.path)
        $name = 'Local\vanguard-mission-event-' + (Get-Sha256OfString -Text $full.ToLowerInvariant()).Substring(0, 40)
        $mutex = New-Object System.Threading.Mutex($false, $name)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { $owned = $mutex.WaitOne($script:MissionEventLockWaitMs) }
        catch [System.Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { throw "the lock on events.jsonl was not obtained within $($script:MissionEventLockWaitMs) ms" }
        while ($null -eq $fs) {
            try {
                $fs = [System.IO.File]::Open($full, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
            } catch [System.IO.IOException] {
                if ($sw.ElapsedMilliseconds -ge $script:MissionEventLockWaitMs) { throw "events.jsonl could not be opened within $($script:MissionEventLockWaitMs) ms: $($_.Exception.Message)" }
                Start-Sleep -Milliseconds 25
            }
        }

        # THE LAST seq, read from the file's tail (the whole file only when the tail holds no line).
        $len = $fs.Length
        $last = [int64]0
        $needLf = $false
        if ($len -gt 0) {
            $take = [int][Math]::Min($len, [int64]65536)
            foreach ($pass in 1..2) {
                $buf = New-Object byte[] $take
                $fs.Position = $len - $take
                $got = 0
                while ($got -lt $take) { $n = $fs.Read($buf, $got, $take - $got); if ($n -le 0) { break }; $got += $n }
                if ($pass -eq 1) { $needLf = ($buf[$take - 1] -ne 10) }
                $text = [System.Text.Encoding]::UTF8.GetString($buf, 0, $got)
                foreach ($m in [regex]::Matches($text, '"host_id":"[^"]*","seq":(\d+),')) { $v = [int64]$m.Groups[1].Value; if ($v -gt $last) { $last = $v } }
                if ($last -gt 0 -or $take -ge $len) { break }
                $take = [int]$len
            }
        }

        if ($ChangeField -and $len -gt 0) {
            $want = [string]$Payload[$ChangeField]
            $all = New-Object byte[] ([int]$len)
            $fs.Position = 0
            $got = 0
            while ($got -lt $len) { $n = $fs.Read($all, $got, [int]$len - $got); if ($n -le 0) { break }; $got += $n }
            $prior = $null
            $kindTok = '"kind":"' + $Kind + '"'
            $fieldRx = '"' + [regex]::Escape($ChangeField) + '":"([^"]*)"'
            foreach ($ln in ([System.Text.Encoding]::UTF8.GetString($all, 0, $got) -split "`n")) {
                if (-not $ln.Contains($kindTok)) { continue }
                $fm = [regex]::Match($ln, $fieldRx)
                if ($fm.Success) { $prior = $fm.Groups[1].Value }
            }
            if (($null -ne $prior) -and ($prior -ceq $want)) { return $false }
        }

        $line = [ordered]@{
            schema_version = $script:MissionEventSchemaVersion
            mission_id     = $ctx.mission_id
            host_id        = $ctx.host_id
            seq            = $last + 1
            ts             = Get-UtcStampZ
            kind           = $Kind
            payload        = $Payload
            source_path    = $rel
            sha256         = $sha
            commit         = $ctx.commit
        }
        $json = ($line | ConvertTo-Json -Compress -Depth 12)
        $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($(if ($needLf) { "`n" } else { '' }) + $json + "`n")
        $fs.Position = $len
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Flush()
        return $true
    }
    catch {
        Write-MissionTelemetryError -Root $Root -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId `
            -Message ("telemetry: the append of a '$Kind' line to .mission-runtime/telemetry/events.jsonl failed and nothing was written to it: " + $_.Exception.Message)
        return $false
    }
    finally {
        if ($null -ne $fs) { try { $fs.Dispose() } catch { } }
        if ($null -ne $mutex) {
            if ($owned) { try { $mutex.ReleaseMutex() } catch { } }
            try { $mutex.Dispose() } catch { }
        }
    }
}

# --- once-only markers, files in the telemetry folder (never a directory: a missing folder stays missing) ---
function Get-MissionTelemetryMarkerPath {
    param([string]$Root, [string]$Name)
    Join-Path $Root ('.mission-runtime\telemetry\' + ($Name -replace '[^A-Za-z0-9._-]', '-') + '.marker')
}
function Test-MissionTelemetryMarker {
    param([string]$Root, [string]$Name)
    try { return (Test-Path -LiteralPath (Get-MissionTelemetryMarkerPath -Root $Root -Name $Name) -PathType Leaf) } catch { return $false }
}
function Set-MissionTelemetryMarker {
    param([string]$Root, [string]$Name)
    try {
        $p = Get-MissionTelemetryMarkerPath -Root $Root -Name $Name
        if (Test-Path -LiteralPath (Split-Path -Parent $p) -PathType Container) { [System.IO.File]::WriteAllText($p, (Get-UtcStampZ)) }
    } catch { }
}

function New-MissionTelemetryMarker {
    # CLAIM a once-only marker: $true only for the ONE caller whose CreateNew wins, so concurrent first calls
    # of one session say session_start once. $false when it exists already or cannot be made.
    param([string]$Root, [string]$Name)
    try {
        $p = Get-MissionTelemetryMarkerPath -Root $Root -Name $Name
        if (-not (Test-Path -LiteralPath (Split-Path -Parent $p) -PathType Container)) { return $false }
        $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $b = [System.Text.Encoding]::UTF8.GetBytes((Get-UtcStampZ)); $fs.Write($b, 0, $b.Length) } finally { $fs.Dispose() }
        return $true
    } catch { return $false }
}
function Remove-MissionTelemetryMarker {
    # Release a claim whose line could not be written, so the next call may claim it again.
    param([string]$Root, [string]$Name)
    try { $p = Get-MissionTelemetryMarkerPath -Root $Root -Name $Name; if (Test-Path -LiteralPath $p -PathType Leaf) { Remove-Item -LiteralPath $p -Force } } catch { }
}

function Get-MissionEventToolPaths {
    # tool_call.paths: the path-valued arguments the hook captured, verbatim -- the keys the guard's own
    # tool-input walk reads. Never the command text and never any other argument.
    param($ToolInput)
    $out = New-Object System.Collections.Generic.List[string]
    if ($ToolInput -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in @($ToolInput.PSObject.Properties)) {
            if ((@('file_path', 'path', 'notebook_path', 'filePath') -contains $p.Name) -and ($p.Value -is [string]) -and $p.Value) { [void]$out.Add([string]$p.Value) }
        }
    }
    return $out.ToArray()
}

function Write-MissionGateEvent {
    # gate_minted / gate_consumed / gate_expired, read off the gate artifact itself after the write that
    # caused the event. gate_id is the artifact's push_id (<kind>-<id>), else its file name; tip_sha rides on
    # push gates. gate_expired is once per gate (a marker), so a verb that observes expiry twice says it once.
    # ONE GATE IS ITS ID AND ITS MINT: reapprove re-mints a gate under the same <kind>-<id> at the same path, so the
    # marker is keyed by gate_id AND the mint stamp (created_at; the artifact's sha256 where it states none), and a
    # re-minted gate reports its own expiry once -- a prior mint's marker never suppresses it.
    param([string]$Root, [string]$Kind, [string]$GatePath, [string]$Hook = 'mission-gate', [string]$SessionId = '', [string]$DispatchId = '')
    try {
        $t = [System.IO.File]::ReadAllText($GatePath)
        $gk = Get-MissionTelemetryScalar -Text $t -Key 'kind'
        $pushId = Get-MissionTelemetryScalar -Text $t -Key 'push_id'
        $gateId = $(if ($pushId) { $pushId } else { [System.IO.Path]::GetFileNameWithoutExtension($GatePath) })
        $expMarker = ''
        $expClaimed = $false
        if ($Kind -eq 'gate_expired') {
            $mint = Get-MissionTelemetryScalar -Text $t -Key 'created_at'
            if (-not $mint) { $mint = Get-Sha256OfFile -Path $GatePath }
            $expMarker = 'gate-expired-' + $gateId + '-' + (Get-Sha256OfString -Text ([string]$mint)).Substring(0, 16)
            if (Test-MissionTelemetryMarker -Root $Root -Name $expMarker) { return $false }
            # CLAIMED, as session_start's is: of two concurrent observers of one expiry only the CreateNew winner says
            # it. A claim that fails with no marker standing was not lost to another observer -- the folder is missing
            # or cannot be written -- so the append below is still attempted, and its failure recorded (SS14's trace).
            if (Test-Path -LiteralPath (Join-Path $Root '.mission-runtime\telemetry') -PathType Container) {
                if (New-MissionTelemetryMarker -Root $Root -Name $expMarker) { $expClaimed = $true }
                elseif (Test-MissionTelemetryMarker -Root $Root -Name $expMarker) { return $false }
            }
        }
        $p = [ordered]@{
            gate_id    = $gateId
            kind       = $gk
            expires_at = Get-MissionTelemetryScalar -Text $t -Key 'expires_at'
        }
        if ($Kind -eq 'gate_consumed') { $p['consumed_at'] = Get-MissionTelemetryScalar -Text $t -Key 'consumed_at' }
        if ($gk -eq 'push') { $p['tip_sha'] = Get-MissionTelemetryScalar -Text $t -Key 'authorized_tip_sha' }
        $ok = Write-MissionEvent -Root $Root -Kind $Kind -Payload $p -SourcePath $GatePath -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId
        if ($expClaimed -and -not $ok) { Remove-MissionTelemetryMarker -Root $Root -Name $expMarker }   # released: the next observer may say it
        elseif ($ok -and $expMarker -and -not $expClaimed) { Set-MissionTelemetryMarker -Root $Root -Name $expMarker }
        return $ok
    } catch {
        if (Test-MissionTelemetryStream -Root $Root) {
            Write-MissionTelemetryError -Root $Root -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId -Message ("telemetry: a '$Kind' line could not be composed from $GatePath and nothing was written to .mission-runtime/telemetry/events.jsonl: " + $_.Exception.Message)
        }
        return $false
    }
}

function Write-MissionHaltEvent {
    # halt_raised / halt_resolved. halt_id is the HALT file's base name (the id a halt-ruling gate binds);
    # severity is the file's own `severity:` / `**Severity:**` line, or null where it states none.
    # halt_raised is once per HALT (a marker): editing a HALT does not raise it again.
    param([string]$Root, [string]$Kind, [string]$HaltPath, [AllowNull()][string]$Resolution = $null, [string]$Hook = 'mission-gate', [string]$SessionId = '', [string]$DispatchId = '')
    try {
        $hid = [System.IO.Path]::GetFileNameWithoutExtension($HaltPath)
        if ($Kind -eq 'halt_raised' -and (Test-MissionTelemetryMarker -Root $Root -Name ('halt-raised-' + $hid))) { return $false }
        $sev = $null
        if (Test-Path -LiteralPath $HaltPath -PathType Leaf) {
            $m = [regex]::Match([System.IO.File]::ReadAllText($HaltPath), '(?im)^\s*[*_]*severity[*_]*\s*:\s*[*_]*\s*([A-Za-z0-9_-]+)')
            if ($m.Success) { $sev = $m.Groups[1].Value }
        }
        $p = [ordered]@{ halt_id = $hid; severity = $sev }
        if ($Kind -eq 'halt_resolved') { $p['resolution'] = $Resolution }
        $ok = Write-MissionEvent -Root $Root -Kind $Kind -Payload $p -SourcePath $HaltPath -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId
        if ($ok -and $Kind -eq 'halt_raised') { Set-MissionTelemetryMarker -Root $Root -Name ('halt-raised-' + $hid) }
        return $ok
    } catch {
        if (Test-MissionTelemetryStream -Root $Root) {
            Write-MissionTelemetryError -Root $Root -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId -Message ("telemetry: a '$Kind' line could not be composed from $HaltPath and nothing was written to .mission-runtime/telemetry/events.jsonl: " + $_.Exception.Message)
        }
        return $false
    }
}

function Get-MissionEvidenceStopFacts {
    # session_stop / dispatch_finalized: the manifest as it is on disk now. SS14's manifest_state enum has
    # four values and the state machine derives six; OPEN (runner-owned, not yet ended) and GREW (sealed,
    # then appended to) both mean "not sealed as it stands", which is PARTIAL, and the derived state rides
    # beside it, additively, as evidence_state.
    param([string]$Root, [string]$DispatchId)
    $st = Get-EvidenceState -Root $Root -DispatchId $DispatchId
    $native = [string]$st.state
    $mapped = if (@('ABSENT', 'PARTIAL', 'FINALIZED', 'TAMPERED') -contains $native) { $native } else { 'PARTIAL' }
    $rt = Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId
    $man = Join-Path $rt 'manifest.json'
    $log = Join-Path $rt 'log.jsonl'
    $ec = 0
    if (Test-Path -LiteralPath $man -PathType Leaf) {
        try { $mo = [System.IO.File]::ReadAllText($man) | ConvertFrom-Json; $ec = [int](Get-EntryField $mo 'entry_count' 0) } catch { $ec = 0 }
    }
    $src = if (Test-Path -LiteralPath $man -PathType Leaf) { $man } elseif (Test-Path -LiteralPath $log -PathType Leaf) { $log } else { Join-Path $Root '.mission\mission.yaml' }
    return @{ manifest_state = $mapped; evidence_state = $native; entry_count = $ec; source = $src; manifest_sha = (Get-Sha256OfFile -Path $man) }
}

function Write-MissionPushTipEvent {
    # tip_observed from the push hook (SS14: "push hook / verify"), beside the gate_consumed it says for the same gate.
    # origin_tip is what the push settle OBSERVED the declared origin to hold -- an ls-remote read, live, so cached is
    # false -- as Complete-EvidencePushGate stamped it on the consumed gate (consumed_origin_tip, beside consumed_ref,
    # which rides additively as ref). local_tip is this checkout's HEAD; ahead/behind count HEAD against that observed
    # tip from local objects, null where they cannot be counted (git absent, or the tip not held here). source_path is
    # the gate.
    param([string]$Root, [string]$GatePath, [string]$Hook = 'PostToolUse', [string]$SessionId = '', [string]$DispatchId = '')
    try {
        $t = [System.IO.File]::ReadAllText($GatePath)
        $p = [ordered]@{ local_tip = $null; origin_tip = (Get-MissionTelemetryScalar -Text $t -Key 'consumed_origin_tip'); ahead = $null; behind = $null
                         cached = $false; ref = (Get-MissionTelemetryScalar -Text $t -Key 'consumed_ref') }
        $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue)
        if ($git.Count -gt 0) {
            $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try {
                $h = @(& $git[0].Source -C $Root rev-parse HEAD 2>$null | ForEach-Object { "$_".Trim() })
                if ($LASTEXITCODE -eq 0 -and $h.Count -ge 1 -and $h[0] -cmatch '^[0-9a-f]{40}$') { $p['local_tip'] = $h[0] }
                if ($p['local_tip'] -and ([string]$p['origin_tip'] -cmatch '^[0-9a-f]{40}$')) {
                    $c = @(& $git[0].Source -C $Root rev-list --left-right --count ('HEAD...' + $p['origin_tip']) 2>$null | ForEach-Object { "$_" })
                    if ($LASTEXITCODE -eq 0 -and $c.Count -ge 1 -and ($c[0] -match '^\s*(\d+)\s+(\d+)\s*$')) { $p['ahead'] = [int]$Matches[1]; $p['behind'] = [int]$Matches[2] }
                }
            } catch { } finally { $ErrorActionPreference = $prev }
        }
        return (Write-MissionEvent -Root $Root -Kind 'tip_observed' -Payload $p -SourcePath $GatePath -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId)
    } catch {
        if (Test-MissionTelemetryStream -Root $Root) {
            Write-MissionTelemetryError -Root $Root -Hook $Hook -SessionId $SessionId -DispatchId $DispatchId -Message ("telemetry: a 'tip_observed' line could not be composed from $GatePath and nothing was written to .mission-runtime/telemetry/events.jsonl: " + $_.Exception.Message)
        }
        return $false
    }
}
