#Requires -Version 5.1
<#
.SYNOPSIS
  Deterministic goal evaluator, and the Stop hook that runs it. (LAM-ACCEPT WP-3, C-1..C-3)

.DESCRIPTION
  WHAT THIS FILE IS FOR, stated once and plainly. A session that says it is finished is not
  evidence that it is finished. Design SS4.4 says a verify result existing only in agent prose does
  not exist; WP-3 generalises that from verify to the GOAL. Every detector below reads DISK -- an
  exit code, a file, a hash, a count -- and no detector reads a transcript, a summary, or any
  claim. The evaluator is indifferent to prose by construction, not by discipline.

  C-1  Reads <mission-root>/.mission/goals/<id>.yaml and writes <id>.verdict.yaml beside it, with
       `verdict: MET|NOT_MET|HALT|AWAITING_AMENDMENT_GATE`
       `|AWAITING_DISPATCH_GATE|HANDOFF_ADMITTED` `|GOAL_ABSENT`
       and one entry per detector. EXIT 0 IF AND ONLY IF MET.

  C-2  With -AsStopHook it emits a Stop-hook decision. NOT_MET blocks and names the failing
       detectors as the reason, so the session continues on evidence rather than on a transcript
       evaluator's opinion. MET, HALT and AWAITING_AMENDMENT_GATE, AWAITING_DISPATCH_GATE
       and HANDOFF_ADMITTED and GOAL_ABSENT do not block.

  C-3  A HALT artifact makes the verdict HALT, and on HALT the hook DOES NOT BLOCK -- control
       returns to the human. A HALT outranks a fully satisfied goal: if the harness has falsified
       something, "every detector passed" is not a reason to keep going.
       ONE THING OUTRANKS THE HALT LABEL:
       a goal file in which a HALT-SCOPE key of a halt_absent item -- `dir`, `legacy_answered_allowlist`
       -- does not touch its colon. THE ITEM IS TAKEN AS THE GOAL WROTE IT: it is a halt_absent where any
       `type` line of it says so, whether or not that line touches its own colon -- AND, for a key
       line under an item, ALSO AS THE READER READ IT: either reading is enough. The scope a HALT
       would then be derived over is not the scope the goal wrote, so the verdict is NOT_MET with the
       HALT open and the hook BLOCKS. Every other goal that does not parse is still outranked by an
       open HALT -- one whose only mis-spaced key is the item's `type` among them.
       A HALT STOPS COUNTING ONLY WHEN THE OPERATOR HAS ANSWERED IT: a live,
       unrevoked `halt-ruling` gate binding the HALT file's current bytes (Test-HaltRuled). The
       HALT's own `**Status:**` line answers nothing, except for a HALT a goal names in its
       legacy_answered_allowlist -- empty unless written, reported entry by entry, and honoured
       only for a member of the LEGACY HALT CENSUS, tools/lam/legacy-halt-census.txt (below).

  WHERE THE GOAL FILE LIVES. C-1's canonical path is <mission-root>/.mission/goals/<id>.yaml and
  that is searched first. Two more locations are accepted, in order, and both are disclosed rather
  than implied:
    2. <mission-root>/.mission-runtime/lam/goals/<id>.yaml
    3. an explicit -GoalFile <path>
  Location 2 exists because .mission/ is outside this build's write surface (LAM-ACCEPT line 6),
  so the agent building the toolchain cannot author its own goal in the canonical place. The
  canonical path always wins where it exists; this is a fallback, never an override.

  A MISSING GOAL FILE IS AN ADMITTED STOP, AND A RECORDED ONE (the operator's
  ruling). As a Stop hook, refusing to let a session end because nobody
  authored a goal would wedge every session in the repository, and S0's pre-goal window depends on
  the stop. So it does not block -- but it is never silent: it writes verdict
  GOAL_ABSENT to <mission-root>/.mission/goals/<id>.verdict.yaml naming the goal id and every path
  it looked in, and prints that as the stop's reason. WHERE THAT VERDICT CANNOT BE WRITTEN THE STOP IS
  REFUSED: an absent goal is admitted as a recorded stop or not at all. A goal file
  that EXISTS but cannot be read, declares no detectors, declares a number that is not one,
  or holds inside its detectors list a key that does not touch its colon
  is the other case, and it REFUSES the stop: verdict NOT_MET, a `goal_parse`
  entry carrying the parse error. THE TRAP FAILS CLOSED: an error this file does
  not catch -- a goal file it cannot even stat, a verdict artifact it cannot write -- ends in the trap,
  which REFUSES the stop with the error as its reason and writes a NOT_MET verdict when it can, for an
  unparseable goal as for every other. It once reported and did not block.

  UNKNOWN DETECTOR TYPES REFUSE. A detector this file does not implement is NOT skipped: a
  skipped detector is a goal that reports MET over a check nobody ran, which is design SS4.5
  law 2's allow-side failure in miniature.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Goal,
    # THE EMPTY STRING BINDS. A hook
    # whose registration takes its root from an environment variable hands over '' where that variable is
    # unset, and a mandatory [string] refuses '' at binding -- PowerShell's own exit 1, no decision printed,
    # the stop not refused. Admitted here, '' reaches the block that answers a mission root that is no
    # directory (above the goal search). The worker guard below stands ahead of that block, as it did.
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$MissionRoot,
    [string]$GoalFile,
    [switch]$AsStopHook,
    [int]$TurnsElapsed = -1
)

$ErrorActionPreference = 'Stop'

# THE WORKER-TRAP GUARD, and it was found by driving rather than by reasoning.
#
# A Stop hook registered in a project's settings is inherited by EVERY session whose working
# directory sits inside that project -- including a headless worker the runner spawns. A worker
# cannot satisfy the ORCHESTRATOR's goal (it is not building the toolchain, it is building one
# feature), so a blocking decision traps it: it is told to continue, forever, until something
# external kills it.
#
# MEASURED, not inferred. A trivial `claude -p` prompt run with cwd inside this project produced
# no output and was killed at 200 seconds; the identical prompt run from a directory outside the
# project returned in 4 SECONDS. The difference was this hook.
#
# The runner marks every worker it spawns with LAM_DISPATCH. Seeing it here means "this session is
# a dispatched worker, and this goal is not its goal" -- so the hook reports and does not block.
# It fails toward NOT BLOCKING, which is the only safe direction: a continuation gate that wedges
# the workers it was meant to supervise defeats the mode it exists to enable.
#
# IT STANDS ABOVE ALL THAT CAN RAISE AN ERROR (only the error preference is set before it). It stood below the turn count and
# the three dot-sourced libraries, and the trap beneath it now REFUSES a stop on any error: left
# there, an error in one of those -- a transcript that cannot be read, a library that does not load
# -- would have BLOCKED a worker, which is the trap this guard exists to keep it out of. Nothing a
# worker's stop depends on runs before it now. Its decision, its reason and its exit are unchanged;
# the hook's stdin is drained first, as it was, because a worker's stop used to pass that read.
if ($AsStopHook -and $env:LAM_DISPATCH) {
    try { $null = [Console]::In.ReadToEnd() } catch { }
    Write-Output (@{
        decision = 'approve'
        reason   = "goal-check: this session is dispatched worker '$env:LAM_DISPATCH', not the orchestrator. Goal '$Goal' is the orchestrator's and is not evaluated here -- a worker held to its dispatcher's goal can never stop."
    } | ConvertTo-Json -Compress)
    exit 0
}

# THE THREE NAMES THE TRAP READS, ASSIGNED HERE so that it reads THIS run's and nothing else's:
# unassigned, a name is looked up through the caller's scopes, and a caller that ran this file
# in-process holding a $verdictPath of its own would have handed the trap its write target.
$goalPath = $null
$verdictPath = $null
$verdict = $null

# =================================================================================================
# TURN COUNTING -- THE WIRING turn_cap NEVER HAD (V-1 round 3, WP-3 residual).
# =================================================================================================
# `turn_cap` could not fail as wired. Neither registration passed -TurnsElapsed, so the detector
# always took its "not enforced" branch and returned ok, and stdin was discarded so nothing else
# could supply a count either. A cap that cannot be exceeded is not a cap -- it is a comment.
#
# THE COUNT COMES FROM THE TRANSCRIPT, WHICH THE HARNESS WRITES. A Stop hook's stdin payload names
# `transcript_path`; each user turn is a line whose `type` is `user`. That source sits OUTSIDE the
# agent's reach, which is the same property that makes the transcript the right second arm for
# H-2's reconciliation -- a session cannot lower its own turn count by behaving differently.
#
# IT STILL REPORTS RATHER THAN ASSUMES. If stdin carries nothing, or the transcript is absent or
# unreadable, the count stays -1 and the detector says so on its face instead of quietly passing.
# The explicit -TurnsElapsed parameter still wins where a caller supplies one.
function Get-TurnsFromStdinTranscript {
    $raw = $null
    try {
        if (-not [Console]::IsInputRedirected) { return -1 }
        $raw = [Console]::In.ReadToEnd()
    } catch { return -1 }
    if (-not $raw -or -not $raw.Trim()) { return -1 }
    $payload = $null
    try { $payload = $raw | ConvertFrom-Json } catch { return -1 }
    if ($null -eq $payload) { return -1 }
    $tp = [string]$payload.transcript_path
    # UNREADABLE IS -1, AS THE BLOCK ABOVE SAYS -- AND ONCE IT WAS NOT. The read below
    # stood outside any try and opened the transcript sharing Read alone, so a transcript the harness
    # was appending to at that instant, or a transcript_path that is a directory, THREW. The old trap
    # then approved the stop with nothing evaluated; the trap that fails closed would BLOCK a met goal
    # over a count only turn_cap reads. So the read is guarded and shares ReadWrite: what cannot be read
    # is -1, and a goal that DECLARES a turn_cap then fails its own entry, as it always has for -1.
    $turns = 0
    try {
        if (-not $tp -or -not (Test-Path -LiteralPath $tp -PathType Leaf)) { return -1 }
        $tpStream = New-Object System.IO.FileStream($tp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
                                                    ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        try {
            $tpReader = New-Object System.IO.StreamReader($tpStream, [System.Text.Encoding]::UTF8, $true)
            try {
                while ($null -ne ($line = $tpReader.ReadLine())) {
                    if (-not $line.Trim()) { continue }
                    $o = $null
                    try { $o = $line | ConvertFrom-Json } catch { continue }
                    if ($null -eq $o) { continue }
                    if ([string]$o.type -eq 'user') { $turns++ }
                }
            } finally { $tpReader.Dispose() }
        } finally { $tpStream.Dispose() }
    } catch { return -1 }
    return $turns
}
if ($AsStopHook -and ($TurnsElapsed -lt 0)) { $TurnsElapsed = Get-TurnsFromStdinTranscript }

# =================================================================================================
# THE TRAP FAILS CLOSED (the BATCH-3 charter).
# =================================================================================================
# WHAT IT WAS. An error this file does not catch ends here, and once this block printed
# `{"decision":"approve","reason":"goal-check errored: ..."}` and exited 9, with no verdict artifact:
# "It reports, and it does not block". So an error BEFORE THE VERDICT WAS WRITTEN admitted the stop.
# FOUR ROUTES were measured: a goal that does not parse
# with a DIRECTORY at its verdict artifact's path; a goal file the search cannot even stat; an eligible
# HANDOFF head with the artifact unwritable, at every later stop; and two Stop hooks at once, the one
# that loses the artifact's write. A fifth was on the page since an earlier revision: a halt_absent `dir` that
# Resolve-DetectorPath throws on, outside the per-detector catch.
#
# THE RULING. "Any error before the verdict is written BLOCKS the stop with a printed reason and writes
# the verdict when it can; no route ends in approve without a written verdict."
#
# AS BUILT.
#   THE VERDICT IS NOT_MET, the one verdict C-2 blocks on, so the verdict set and the blocked set stand
#     as they were: an evaluation that errored has not established that the goal is met.
#   IT IS WRITTEN WHEN IT CAN BE, by this block, at the path the run would have written -- the path it
#     had composed, else beside the goal file it had found, else the canonical
#     <MissionRoot>\.mission\goals\<Goal>.verdict.yaml under the absent goal's own two conditions (the id
#     one token, .mission a directory). One failing entry, type evaluator_error, carries the error; a
#     key evaluator_error carries it at column 0. Where it cannot be written the reason says so and why.
#     This block may overwrite an artifact another hook wrote a moment ago: the artifact is the last
#     writer's, as it always was.
#   THE HOOK BLOCKS in the form NOT_MET blocks in (C-2): `{"decision":"block","reason":...}` on stdout and
#     EXIT 0 -- the decision JSON is honoured on exit 0. If that JSON cannot be composed, EXIT 2, the
#     harness's own blocking code, with one line on stderr: the stop is refused either way.
#   BY HAND the two lines and EXIT 9 are what they were; a third line names the verdict file.
#   IT USES NOTHING THIS FILE DEFINES BELOW IT, because the error may be that a library did not load.
#   A DISPATCHED WORKER NEVER REACHES IT: the worker-trap guard stands above every statement that can raise one.
#
# WHAT IT GIVES UP, said plainly: the trap's old sentence was "it also must not wedge it". A cause that
# does not clear -- a directory where the artifact goes, a denied goal directory -- now refuses EVERY stop
# of that session until someone clears it, an open HALT included: a HALT hands control back through its
# verdict, and here there is none. That is the ruling's direction, and the reason names the cause.
# NOT ERRORS, AND NOT THIS BLOCK'S: an absent goal whose verdict IS written (GOAL_ABSENT)
# and the worker guard each approve by their own rule, above or below, unchanged. A MISSION ROOT THAT IS NOT
# A DIRECTORY IS NOT THIS BLOCK'S EITHER, AND IT NO LONGER APPROVES: the block
# above the goal search answers it, and as a Stop hook that block now REFUSES the stop, in the absent goal's form.
# WHAT THIS BLOCK DOES NOT REACH, each stated because "no route" would otherwise be read wider than it is:
#   (1) AN ABSENT GOAL WHOSE OWN ARTIFACT CANNOT BE WRITTEN does not reach this block either -- the write
#       is caught where it is made -- and once it was still an admitted stop with no
#       file. NOW THAT BRANCH BLOCKS IT ITSELF, in this block's form and under its sentence.
#   (2) AN ERROR BEFORE THIS FILE'S BODY RUNS -- a parameter that does not bind, a file that does not
#       parse -- is PowerShell's own exit 1 with no decision printed. A trap cannot see it. (Now
#       an EMPTY -MissionRoot binds and is answered as a root that is no directory; a
#       -MissionRoot that is not on the command line at all still does not bind.)
#   (3) WHERE THE VERDICT GOES ON AN EARLY ERROR: one that comes before the goal file is found is
#       recorded at the CANONICAL path, also when the goal lives at the second location or at -GoalFile,
#       where a later, clean run writes beside the goal and leaves that record standing.
trap {
    $trapMessage = 'the error could not be rendered'
    try { $trapMessage = (([string]$_.Exception.Message) -replace '[\r\n]+', ' ').Trim() } catch { }
    $trapStack = ''
    try { $trapStack = (([string]$_.ScriptStackTrace) -split "`r?`n") -join ' | ' } catch { }
    $trapDerived = ''
    try { if ($verdict) { $trapDerived = " The verdict this run had derived before the error: $verdict." } } catch { }
    $trapSentence = "THE EVALUATOR ERRORED BEFORE ITS VERDICT WAS WRITTEN -- $trapMessage -- and an error is not an admitted stop: the stop is REFUSED (register row 358).$trapDerived"
    $trapTarget = ''
    $trapWritten = ''
    $trapNotWritten = ''
    try {
        if ($verdictPath) { $trapTarget = [string]$verdictPath }
        elseif ($goalPath) { $trapTarget = Join-Path (Split-Path -Parent ([string]$goalPath)) "$Goal.verdict.yaml" }
        elseif (-not [regex]::IsMatch([string]$Goal, '\A[A-Za-z0-9][A-Za-z0-9._-]*\z')) {
            $trapNotWritten = "the goal id '$Goal' is not one token [A-Za-z0-9][A-Za-z0-9._-]*, so no file is named for it"
        } elseif (-not [System.IO.Directory]::Exists((Join-Path ([string]$MissionRoot) '.mission'))) {
            $trapNotWritten = "$(Join-Path ([string]$MissionRoot) '.mission') is not a directory, so there is no mission plane to write it into"
        } else {
            $trapGoalsDir = Join-Path (Join-Path ([string]$MissionRoot) '.mission') 'goals'
            if (-not [System.IO.Directory]::Exists($trapGoalsDir)) { [void][System.IO.Directory]::CreateDirectory($trapGoalsDir) }
            $trapTarget = Join-Path $trapGoalsDir "$Goal.verdict.yaml"
        }
    } catch { $trapTarget = ''; $trapNotWritten = 'its path could not be composed (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + ')' }
    if ($trapTarget) {
        try {
            $trapSb = New-Object System.Text.StringBuilder
            [void]$trapSb.AppendLine("# Written by tools/lam/mission-goal-check.ps1's trap. THE EVALUATION ERRORED BEFORE ITS VERDICT WAS WRITTEN.")
            [void]$trapSb.AppendLine("# An error is not an admitted stop: the stop is REFUSED and the error is recorded here (register row 358).")
            [void]$trapSb.AppendLine("goal: $Goal")
            [void]$trapSb.AppendLine("goal_file: $(if ($goalPath) { [string]$goalPath } else { 'not established -- the error came before a goal file was found' })")
            [void]$trapSb.AppendLine("mission_root: $MissionRoot")
            [void]$trapSb.AppendLine("evaluated_at: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture))")
            [void]$trapSb.AppendLine("verdict: NOT_MET")
            [void]$trapSb.AppendLine("detector_count: 1")
            [void]$trapSb.AppendLine("failing_count: 1")
            [void]$trapSb.AppendLine("short_circuited: 0   # detectors NOT evaluated (hook mode); never counted as passing")
            # WHO WROTE THIS VERDICT (the BATCH-7 charter's item (c)): hook as the Stop hook, hand by
            # hand, rendered from the switch ITSELF -- a parameter is bound before any line of this file runs, so the
            # trap reads no name assigned below it (the hazard the three names above it are assigned for).
            [void]$trapSb.AppendLine("hook_or_hand: $(if ($AsStopHook) { 'hook' } else { 'hand' })")
            [void]$trapSb.AppendLine("evaluator_error: '$(($trapMessage) -replace "'", "''")'")
            [void]$trapSb.AppendLine("halt_scan_roots: []   # no HALT scan is reported by a run that errored (register row 363)")
            [void]$trapSb.AppendLine("halt_scan_excluded: []")
            [void]$trapSb.AppendLine("detectors:")
            [void]$trapSb.AppendLine("  - type: evaluator_error")
            [void]$trapSb.AppendLine("    ok: false")
            [void]$trapSb.AppendLine("    detail: '$((($trapSentence) -replace "`r?`n", ' ') -replace "'", "''")'")
            [System.IO.File]::WriteAllText($trapTarget, $trapSb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
            $trapWritten = $trapTarget
        } catch {
            $trapNotWritten = "writing $trapTarget failed (" + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + ')'
        }
    }
    $trapTail = if ($trapWritten) { " Verdict: $trapWritten." } else { " No verdict file was written: $trapNotWritten." }
    if ($AsStopHook) {
        $trapJson = ''
        try {
            $trapJson = (@{ decision = 'block'; reason = "Goal '$Goal' is NOT_MET: $trapSentence$trapTail Clear the cause and stop again: this decision is derived from the evaluator's own failure, not from the transcript." } | ConvertTo-Json -Compress)
        } catch { $trapJson = '' }
        if ($trapJson) { Write-Output $trapJson; exit 0 }
        try { [Console]::Error.WriteLine('goal-check errored and could not compose its decision; the stop is REFUSED (register row 358)') } catch { }
        exit 2
    }
    Write-Output "mission-goal-check: UNHANDLED ERROR -- $trapMessage"
    Write-Output "  stack: $trapStack"
    Write-Output "  verdict   : $(if ($trapWritten) { $trapWritten + ' (NOT_MET, evaluator_error)' } else { 'none -- ' + $trapNotWritten })"
    exit 9
}

# The ONE shared definition of PASS-DIB and of ledger provenance binding. Never restated here.
. (Join-Path $PSScriptRoot 'lam-verify-admission.ps1')
# The ONE shared definition of gate classification and gate state. `gate_present` restated the
# consumed-gate predicate here once, without the (?!null) the other copy carried, and was dead on
# arrival for it. Never restated here either.
. (Join-Path $PSScriptRoot 'lam-gate-class.ps1')
# The ONE shared definition of "run an instrument and persist what it said" --
# landed in an earlier revision and dot-sourced by the runner
# (tools/lam/mission-dispatch.ps1:2547) as well. The private Save-InstrumentCapture that used to
# live beside the instrument_exit0 detector is GONE: this file no longer runs an instrument and no
# longer writes a transcript of its own. Never restated here either. (It now writes
# ONE file beside the helper's captures: the content-addressed copy of a capture it reuses, byte for byte.)
. (Join-Path $PSScriptRoot 'lam-instrument-run.ps1')

if ($AsStopHook) { try { $null = [Console]::In.ReadToEnd() } catch { } }

# (THE WORKER-TRAP GUARD once stood here. It stands directly under the error preference
# now, above everything that can raise an error: see the head of the file.)

function Out-Line { param([string]$m) if (-not $AsStopHook) { Write-Output $m } }

# --- "is this HALT answered?" -- ONE definition, TWO consumers ----------------------------------
# The predicate was written out twice, in the halt_absent DETECTOR and again in the C-3 VERDICT
# path, and the two drifted the moment one was fixed: the detector reported 2 open halts while the
# verdict line beneath it reported 3, disagreeing about one HALT in the same run. Bold is admitted on
# BOTH sides of the colon -- `**Status:** **ANSWERED**` is answered, and reading it as open is a
# ruling reported as outstanding because of markdown emphasis. Same lesson as the PASS-DIB constant:
# a predicate two consumers share lives in one place or it drifts.
#
# ROUND-3 CURE (V-1 round 3, WP-3). THE PREDICATE ASKED THE WRONG QUESTION, and the answer it gave
# was a FALSE PASS in the goal evaluator -- the worst class in this build's vocabulary, and the
# third instance of it.
#
# It asked "does this DOCUMENT CONTAIN a line beginning `Status: ANSWERED`", not "is this ARTIFACT
# answered". So an OPEN halt whose body merely MENTIONS another halt's marker -- a "Related halts"
# line, or a fenced example showing the marker's own shape -- read as ANSWERED. Driven: that
# mission root returns verdict MET, exit 0, records `open_halts: []`, and the Stop hook emits
# `decision: approve`. THE SESSION IS ALLOWED TO END WITH AN UNANSWERED HALT ON DISK, which is the
# one outcome the whole HALT mechanism exists to prevent.
#
# It is a live trap for this build in particular: these artifacts quote one another constantly, and
# every writeback shows the marker's shape. Re-derived before fixing -- across all 20 live halts the
# old and new readings agree, so no artifact tripped it yet; the certification made with the old
# predicate stands, but it was made with a predicate that could not have said otherwise.
#
# AN ARTIFACT'S STATUS IS ITS FIRST `Status:` LINE. That is what a human reads, and it is what
# these files are written to. Bold on BOTH sides is preserved -- that was an earlier HALT's cure, where a
# correctly-answered halt read as open because of markdown emphasis, and it must not regress.
#
# FAIL CLOSED WHEN THERE IS NO STATUS AT ALL: not answered. The safe direction is the one that
# hands control back to the human.
# --- "where does a relative detector path point?" -- ONE definition, EVERY consumer --------------
# A GOAL IS A STATEMENT ABOUT A MISSION, NOT ABOUT A SHELL. Relative paths in detectors resolved
# against the PROCESS CWD, so one goal file with one -MissionRoot answered MET from one directory
# and NOT_MET from another -- and the Stop hook and a hand-run do not share a working directory.
#
# I CURED `file_exists` AND LEFT ITS THREE SIBLINGS (V-1 round 4, WP-3): `instrument_exit0`,
# `validator_pass_count`'s `dir` and `time_cap`'s `since_file` all still resolved against the cwd,
# and that was LIVE in the registered goal, which names relative paths for seven detectors. Curing
# one member of a class and calling the class fixed is the same mistake as special-casing `-C`
# among git's value-taking options, in a different file on the same day.
#
# AND THEN I DID IT AGAIN. The sentence that used to end this comment -- "the resolution lives in
# one function that every path-taking detector calls" -- was FALSE WHEN WRITTEN. Two inputs never
# called it: `halt_absent`'s `dir` (fail-OPEN, the worst direction) and `verify_pass_or_dib`'s
# `path`. V-1 round 5 (WP-3) drove both. There are SIX path-taking inputs, not four, and the count
# is stated here because a claim of completeness with no number attached is what let this recur.
#
# So: SEVEN inputs -- file_exists.path, instrument_exit0.path, validator_pass_count.dir,
# time_cap.since_file, halt_absent.dir, verify_pass_or_dib.path, and gate_present.path -- and every
# one of them calls Resolve-DetectorPath.
#
# IT SAID SIX, AND SIX WAS WRONG (V-1 round 6, WP-3). `gate_present`'s `path:` override was never
# counted, and a reader drove a goal satisfying one mission's gate detector with another
# repository's gate. Twice now this comment has claimed a completeness it did not have: first the
# unqualified "every path-taking detector calls it", then a NUMBER -- which reads as though somebody
# had counted. A count is only worth more than a claim if it was DERIVED rather than asserted. So if
# an eighth is added: it calls this too, this list gains a name, and C-1h's assertion of the
# call-site count moves with it.
function Resolve-DetectorPath {
    param([string]$MissionRoot, [AllowNull()][string]$Path)
    if (-not $Path) { return $Path }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $MissionRoot $Path)
}

function Test-HaltAnswered {
    # ============================================================================================
    # DEMOTED (batch 4 item 3). THIS IS NOW A CITATION READER, NOT THE DECISION.
    # ============================================================================================
    # This function reads what the HALT FILE SAYS about itself -- a `**Status:**` line anybody who
    # can write the file can write. Its answer NO LONGER DECIDES whether a HALT is OPEN or ANSWERED.
    # That decision is Test-HaltRuled's (below): a HALT is ANSWERED if and only if a live, unrevoked
    # `halt-ruling` gate binds its current bytes. This reader keeps exactly two jobs:
    #   (1) INSIDE THE LEGACY ALLOWLIST ONLY. A halt_absent detector's legacy_answered_allowlist entry
    #       (<HALT file name>@<sha256>) is honoured only when the named file's current bytes hash to
    #       that sha AND this function reads its marker ANSWERED. Outside an allowlist entry its answer
    #       answers nothing.
    #   (2) THE DETAIL. Where this function says ANSWERED and no gate binds the bytes, the open HALT is
    #       reported as "[seat marker ANSWERED; no live halt-ruling gate binds these bytes]", so an
    #       operator reading the verdict sees why a HALT the seat marked answered is still open.
    # The rule below is unchanged, and every WP-3 C-3c row that measured it still measures it -- now
    # through a per-row allowlist entry, which is the one place its answer still has authority.
    # ============================================================================================
    # C-3 AS AMENDED. ONE CANONICAL FORM, AND NOTHING ELSE.
    # ============================================================================================
    # A HALT artifact is OPEN unless the FIRST line matching `^\*\*Status:\*\*` at column 0 carries
    # the value ANSWERED. The label is fixed: no decoration, no alternatives, no blockquote, no
    # bullet, no heading, no table cell, no ordered-list item. Everything else is OPEN.
    #
    # WHAT THIS REPLACES, AND WHY IT IS SHORTER RATHER THAN CLEVERER. The previous implementation was
    # ~150 lines of accumulated widening: five consecutive V-1 rounds (5, 6, 7, 8, 12) each refuted
    # it on a form the previous cure had not imagined, and round 13 found 13 of 26 spellings STILL
    # invisible. Each cure was written against the spellings that round had found, because there was
    # nothing else to write it against -- C-3 contained no answered-exception at all. `grep -i
    # answered` over the contract returned two hits, neither about HALT artifacts. Every round was
    # inventing a little more of a specification nobody had written.
    #
    # A RULE WITH NO SPECIFICATION CANNOT BE COMPLETED BY PATCHING, BECAUSE NOTHING SAYS WHEN IT IS
    # DONE. The amended C-3 writes the specification; this function implements it and stops.
    #
    # TWO CASES THE DRAFT GOT WRONG AND THE REGRESSION CAUGHT, both now handled explicitly:
    #   One HALT writes `**Status:** **ANSWERED**` -- the VALUE is emphasised. A naive capture takes
    #           `**ANSWERED**`, reads it as not-answered, and pins the goal on a permanently open
    #           HALT. This same artifact broke round 7's widening.
    #   Another HALT's first STATUS-SHAPED line is a `git status` mention three lines above its real
    #           marker -- which is why the rule is "first line matching the CANONICAL form", never
    #           "first status-shaped line".
    #
    # FAIL-CLOSED BY CONSTRUCTION: no canonical line at all means OPEN, so a writer using any other
    # spelling produces an open HALT that is visible immediately rather than a silent false MET.
    #
    # THE REGRESSION IS PART OF THE RULE (C-3): any change here ships only after being run over every
    # live HALT artifact, each of which must read as it should.
    # ============================================================================================
    # ONE ADDITION TO THE RULED RULE, AND IT IS DISCLOSED RATHER THAN SLIPPED IN: FENCED CODE BLOCKS
    # ARE REMOVED BEFORE SCANNING.
    # ============================================================================================
    # The amended C-3 says "the first line matching `^\*\*Status:\*\*` at column 0". A line inside a
    # fenced code block IS at column 0 in the raw text, and these documents routinely show a writeback
    # EXAMPLE -- "a writeback looks like: ```markdown **Status:** ANSWERED ```" -- ABOVE the
    # artifact's own marker. Driven before deviating: such a document reports **MET** while its own
    # marker reads OPEN, with controls (same two lines in the other order; a plain canonical ANSWERED)
    # both correct. That is a FALSE MET -- a genuinely open HALT reported answered, the Stop hook
    # approving, the session ending. The silent direction, which is the worst outcome this evaluator
    # has, reachable by an ordinary documentation habit.
    #
    # AND THE CORRECT FENCE HANDLING INVERTS WITH THE RESOLUTION RULE, which is why the previous
    # implementation did the opposite here. Under "collect every marker and require agreement", an
    # UNCLOSED fence was left unstripped because over-collection could only produce more disagreement
    # -- fail-closed. Under "the first canonical line wins", over-collection can hand the verdict to
    # an example -- fail-OPEN. So an unclosed fence now runs to EOF and takes the rest of the document
    # with it: that loses markers, which under this rule means OPEN, which is loud.
    # RATIFIED BY THE OPERATOR, AND THE SINGLE TOGGLE IT REPLACES WAS WRONG THREE
    # WAYS. `if ($line -match '^[ \t]*```') { $inFence = -not $inFence }` did not recognise a TILDE
    # fence at all, so an example inside one was SCANNED (false MET); a four-backtick block containing
    # three-backtick lines toggled state OFF on the inner line, inverting everything after it (false
    # MET); and a fence indented four or more spaces was treated as a fence when CommonMark says it is
    # an indented code block (false HALT). Driven over nine cases, then over WP-3's mirror case, before
    # the text was offered for ruling.
    #
    # THE RULE AS RATIFIED: a fence OPENS on a line whose first non-whitespace run is three or more
    # backticks OR tildes, indented at most three spaces; it CLOSES only on a line of the SAME
    # character, at least as long as the opener, carrying nothing else; an unclosed fence runs to EOF.
    # Fails closed by construction -- a marker the rule hides reads OPEN, never ANSWERED.
    param([string]$Text)
    $scan = New-Object System.Collections.Generic.List[string]
    $fenceChar = ''; $fenceLen = 0
    foreach ($line in (($Text -replace "`r", '') -split "`n")) {
        if ($fenceChar) {
            $c = [regex]::Match($line, '^ {0,3}(' + [regex]::Escape($fenceChar) + '{3,})[ \t]*$')
            if ($c.Success -and $c.Groups[1].Value.Length -ge $fenceLen) { $fenceChar = ''; $fenceLen = 0 }
            continue
        }
        $o = [regex]::Match($line, '^ {0,3}(`{3,}|~{3,})')
        if ($o.Success) { $fenceChar = $o.Groups[1].Value.Substring(0, 1); $fenceLen = $o.Groups[1].Value.Length; continue }
        [void]$scan.Add($line)
    }
    foreach ($line in $scan) {
        $m = [regex]::Match($line, '^\*\*Status:\*\*[ \t]*(.*)$')
        if (-not $m.Success) { continue }
        # EMPHASIS IS STRIPPED FROM THE VALUE, not from the label. `**ANSWERED**` -> ANSWERED.
        $v = ($m.Groups[1].Value -replace '[*_`]', '').Trim()
        # The value is the first word: a marker legitimately carries trailing prose
        # ("ANSWERED -- ruled by the operator 2026-09-01. ...").
        $w = [regex]::Match($v, '^(\w+)')
        return ($w.Success -and $w.Groups[1].Value.ToUpperInvariant() -eq 'ANSWERED')
    }
    return $false
}

# =================================================================================================
# BATCH 4 ITEM 3 (operator ruling): A HALT IS ANSWERED BY THE OPERATOR, NOT BY ITS
# OWN TEXT.
# =================================================================================================
# THE HOLE. Test-HaltAnswered reads a `**Status:**` line out of the HALT file, and the HALT file is
# agent-writable on every layer: neither guard's protected set names the HALT directories, and the
# permission layer allows Write/Edit under .mission-runtime. The design note (batch-4-proposals.md,
# item 3) measured it: a scratch HALT reading OPEN gave Get-OpenHalts Count=1, and after the SAME agent
# rewrote only that line to ANSWERED, Count=0. One agent edit flipped the goal verdict -- a seat could
# answer its own HALT and let the session end.
#
# THE RULING. A HALT is ANSWERED if and only if a live, unrevoked `halt-ruling` gate binds its CURRENT
# bytes by sha256. The operator mints that gate through tools\lam\lam-console.ps1 (the console's
# verified path); it carries `halt_id: <HALT BaseName>` and sits at ONE canonical
# path, .mission\gates\halt-ruling-<HALT BaseName>.yaml. The binding strictness is the design note's
# fork (B): byte equality, so ANY edit to a ruled HALT re-opens it until the operator reapproves. The
# seat's write-back moves to a <HALT BaseName>.ruling-citation.yaml sidecar, which is never a HALT and
# never an answer.
#
# EVERY OTHER CASE IS OPEN, and each is named because each is driven (WP-3 C-3d): no file at the
# canonical path; a file there whose column-0 kind is not exactly `halt-ruling` (a hand-written
# `kind: dispatch` included) or whose kind and written gate_class conflict; a gate the shared predicate
# reports revoked, consumed or disqualified; a binds_sha256 that is not the sha256 of the HALT's bytes
# NOW; a halt_id naming a different HALT (a real gate copied to another HALT's name); a kind, halt_id or
# binds_sha256 key written more than once at column 0 (the first-of-a-class shape: which of two
# answers would count?); a HALT whose bytes cannot be hashed. Fail closed -- the direction that hands
# control back to the human.
#
# WHAT THIS DOES NOT CLOSE, CARRIED RATHER THAN CLAIMED. The derive side is only as strong as the gates
# directory. Until STAGE 2 (LAM-INSTALL 5.6.1) a direct file write into .mission\gates needs no tool,
# and a hand-written file declaring `kind: halt-ruling` over the right bytes reads ANSWERED -- C-3d's
# control row drives exactly that. On THE GATE ROUTE the cost moved from one Edit into an agent-writable
# HALT to forging a gate artifact, which the guard's gate-path predicate and the permission layer's
# Edit(.mission/gates/**) deny inside a harness session, and which STAGE 2 makes unwritable.
#
# AND THAT SENTENCE WAS ONCE WRITTEN AS IF IT WERE THE WHOLE STORY, WHICH IT WAS NOT (its review,
# a finding, driven). The legacy allowlist below is a SECOND route, and as first built it cost two file
# edits and no gate: a seat rewrote its own HALT to `**Status:** ANSWERED`, hashed it, and named it
# `HALT-SELF.md@<sha>` in the goal's halt_absent detector -- verdict MET, exit 0. The goal file is
# agent-writable (the permission layer allows Write/Edit(.mission/**), and the fallback location
# .mission-runtime/lam/goals is agent-writable by design), so "the goal file is the operator's" is true
# BY CONVENTION ONLY. The cure bounds that route by DATA IN A TRACKED FILE BESIDE THIS TOOL, not by the
# goal file: an entry is honoured only for a member of the LEGACY HALT CENSUS, so no HALT raised or edited
# after the census can be allowlisted by editing a goal. WHAT REMAINS, stated plainly: (a) a goal-file edit can
# still honour a census member at its captured bytes -- one of the HALTs that already read ANSWERED under
# the marker rule on the day that rule was retired, which is the bridge the operator's migration fork
# admits and nothing more; (b) extending the census is a MODIFICATION OF A TRACKED FILE
# (tools/lam/legacy-halt-census.txt), the same residual as editing any tracked tool until STAGE 2 and
# review close it.
function Get-HaltFileSha256 {
    # THE SAME READ mission-gate.ps1 USES FOR binds_sha256: a FileStream opened for Read with
    # FileShare ReadWrite|Delete, lower-case hex -- so the digest compared here is computed exactly the
    # way the gate recorded it. '' when the bytes cannot be read, which every caller treats as OPEN.
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $haltStream = New-Object System.IO.FileStream(
            $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
            ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        try {
            $haltHasher = [System.Security.Cryptography.SHA256]::Create()
            try { return ([BitConverter]::ToString($haltHasher.ComputeHash($haltStream))).Replace('-', '').ToLowerInvariant() }
            finally { $haltHasher.Dispose() }
        } finally { $haltStream.Dispose() }
    } catch { return '' }
}

function Get-HaltBytesSha256 {
    # sha256 of bytes ALREADY READ, lower-case hex. The legacy allowlist compares the sha of the SAME
    # bytes its marker was read from, so a file rewritten between two reads cannot pair one version's
    # marker with the other version's digest.
    param([AllowNull()][byte[]]$Bytes)
    if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
    $bytesHasher = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($bytesHasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $bytesHasher.Dispose() }
}

function ConvertFrom-HaltBytes {
    # DECODES EXACTLY AS [System.IO.File]::ReadAllText DID: a StreamReader over UTF-8 that detects a
    # byte-order mark. The marker reader's input is therefore unchanged by reading bytes first.
    param([AllowNull()][byte[]]$Bytes)
    if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
    $decodeStream = [System.IO.MemoryStream]::new($Bytes)
    $decodeReader = [System.IO.StreamReader]::new($decodeStream, [System.Text.Encoding]::UTF8, $true)
    try { return $decodeReader.ReadToEnd() } finally { $decodeReader.Dispose() }
}

function Test-HaltRuled {
    <#
      IS THIS HALT ANSWERED? TRUE IF AND ONLY IF, ALL AT ONCE:
        * <MissionRoot>\.mission\gates\halt-ruling-<HALT BaseName>.yaml exists as a file;
        * its column-0 `kind:`, read by the shared Get-LamGateClassForArtifact, is exactly
          `halt-ruling` (-ceq), and the classification is ok (no kind / gate_class conflict);
        * the shared Get-LamGateState reports it neither revoked, consumed nor disqualified;
        * its one column-0 `binds_sha256:` (64 hex) equals the sha256 of the HALT file's CURRENT bytes;
        * its one column-0 `halt_id:` -- the whole value to end of line, trimmed -- equals the HALT
          BaseName (-ceq).
      Every other case is $false. -HaltFile takes a FileInfo (what the scan holds) or a path.
    #>
    param([Parameter(Mandatory = $true)]$HaltFile, [Parameter(Mandatory = $true)][string]$MissionRoot)
    $haltFull = ''
    $haltLeaf = ''
    try {
        if ($HaltFile -is [System.IO.FileInfo]) { $haltFull = $HaltFile.FullName; $haltLeaf = $HaltFile.Name }
        else { $haltFull = [string]$HaltFile; $haltLeaf = [System.IO.Path]::GetFileName($haltFull) }
    } catch { return $false }
    if ((-not $haltFull) -or (-not $haltLeaf)) { return $false }
    if (-not (Test-Path -LiteralPath $haltFull -PathType Leaf)) { return $false }
    $haltBase = ''
    try { $haltBase = [System.IO.Path]::GetFileNameWithoutExtension($haltLeaf) } catch { return $false }
    if (-not $haltBase) { return $false }
    $rulingGate = Join-Path $MissionRoot ('.mission\gates\halt-ruling-' + $haltBase + '.yaml')
    if (-not (Test-Path -LiteralPath $rulingGate -PathType Leaf)) { return $false }
    $rulingText = $null
    try { $rulingText = [System.IO.File]::ReadAllText($rulingGate) } catch { return $false }
    # ONE ANSWER PER KEY. Two column-0 lines for a key the decision reads would leave "which one
    # counts?" to regex order -- the first-of-a-class shape this build has shipped three times.
    foreach ($rulingKey in @('kind', 'binds_sha256', 'halt_id')) {
        if ([regex]::Matches($rulingText, '(?m)^' + $rulingKey + ':').Count -ne 1) { return $false }
    }
    # THE TWO SHARED READS ARE GUARDED LIKE THE ONE ABOVE THEM (its review). Each re-reads the gate
    # file with an unguarded ReadAllText, and this function is reached from the C-3 VERDICT path, which
    # sits outside the per-detector try/catch: a gate that became unreadable between the read above and
    # these two would have thrown out of the verdict path -- no verdict artifact, and a Stop hook that
    # does not block. Caught, it is what every other failure here is: NOT ruled, so the HALT reads OPEN
    # and is reported in open_halts. Fail closed.
    $rulingClass = $null
    try { $rulingClass = Get-LamGateClassForArtifact -Path $rulingGate } catch { return $false }
    if ($null -eq $rulingClass) { return $false }
    if (-not $rulingClass.ok) { return $false }
    # LEFT ORDINAL, NOT ROUTED THROUGH Resolve-LamGateKind (an operator ruling), and said rather
    # than assumed: 'halt-ruling' here is a CANONICAL LITERAL, `-cne` against a canonical literal IS
    # the rule, and `-not $rulingClass.ok` two lines above already refuses every kind the shared
    # reader cannot resolve. Routing it would add a call and change nothing.
    if ($rulingClass.kind -cne 'halt-ruling') { return $false }
    $rulingState = $null
    try { $rulingState = Get-LamGateState -Path $rulingGate } catch { return $false }
    if ($null -eq $rulingState) { return $false }
    if ((-not $rulingState.exists) -or $rulingState.revoked -or $rulingState.consumed -or $rulingState.disqualified) { return $false }
    $boundMatch = [regex]::Match($rulingText, '(?m)^binds_sha256:[ \t]*([0-9a-fA-F]{64})[ \t]*\r?$')
    if (-not $boundMatch.Success) { return $false }
    # THE WHOLE halt_id VALUE, TO END OF LINE, TRIMMED (a review finding, driven). This read was
    # `(\S+)`, so a gate recording `halt_id: HALT-A B` -- which mission-gate.ps1 then wrote for any HALT
    # whose BaseName held a space -- matched nothing, and the operator's ruling silently answered
    # nothing. The writer now refuses such an id (-Id must match ^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$), and
    # the reader reads what the writer writes, so the two round-trip whichever side a gate came from.
    $idMatch = [regex]::Match($rulingText, '(?m)^halt_id:(.*)$')
    if (-not $idMatch.Success) { return $false }
    $rulingHaltId = $idMatch.Groups[1].Value.Trim()
    if ((-not $rulingHaltId) -or ($rulingHaltId -cne $haltBase)) { return $false }
    $currentSha = Get-HaltFileSha256 -Path $haltFull
    if (-not $currentSha) { return $false }
    return ($boundMatch.Groups[1].Value.ToLowerInvariant() -ceq $currentSha)
}

# =================================================================================================
# THE SEAT PLANE'S RESOLVED RECORD: A TOOLING SEAT'S HALT, ANSWERED IN ITS OWN FILE.
# =================================================================================================
# A tooling or recording seat -- one that builds or records the framework rather than executing a
# mission -- raises its HALT in its own runtime plane, <MissionRoot>\.mission-runtime\seats\<seat>\HALT-<id>.md,
# a sibling of the mission planes that no goal scans unless it declares a halt_absent `dir` there. The
# operator answers it by having a RESOLVED record written into the HALT file itself: its first canonical
# `**Status:**` line reads RESOLVED, and ONE column-0 `## RESOLVED` heading opens a block carrying, each
# exactly once at column 0 and before the next `## ` heading, `**HALT:**` (the file's own BaseName),
# `**Ruling:**` (the ruling as given), `**Ruled by:**`, `**Ruled at:**` (a date first, YYYY-MM-DD) and
# `**Resume at:**` (the resumption point), every value non-empty. Fenced blocks are set aside first, by
# Test-HaltAnswered's ratified fence rule, so a record shown as an EXAMPLE answers nothing.
#
# NO GATE IS MINTED, AND THAT IS THE ONE DIFFERENCE FROM A MISSION HALT: a mission HALT reads closed
# only when an operator-minted halt-ruling gate binds its current bytes, and that gate is what a push
# and every other operator-gated act can rest on; a RESOLVED record is text in the seat's own plane,
# so it closes that HALT for the evaluator and authorises nothing.
#
# HONOURED ONLY THERE. The test is on the PATH: the file must sit directly inside one seat folder under
# <MissionRoot>\.mission-runtime\seats\ (ConvertTo-HaltScanPath's one spelling, case folded). The same
# record on a HALT anywhere else -- .mission-runtime\halts, \lam, a seat's subfolder, any declared dir --
# answers nothing: that HALT is OPEN until its halt-ruling gate binds it, and the open entry says why.
# Returns claimed (the Status line reads RESOLVED), honoured, and why not.
function Get-HaltSeatResolution {
    param([string]$Text, [Parameter(Mandatory = $true)]$HaltFile, [Parameter(Mandatory = $true)][string]$MissionRoot)
    $srFull = ''
    $srBase = ''
    try {
        $srFull = if ($HaltFile -is [System.IO.FileInfo]) { $HaltFile.FullName } else { [string]$HaltFile }
        $srBase = [System.IO.Path]::GetFileNameWithoutExtension($srFull)
    } catch { return [pscustomobject]@{ claimed = $false; honoured = $false; why = '' } }
    # THE SAME FENCE RULE AS Test-HaltAnswered, applied here to a copy of the lines.
    $srLines = New-Object System.Collections.Generic.List[string]
    $srFenceChar = ''; $srFenceLen = 0
    foreach ($srLine in (($Text -replace "`r", '') -split "`n")) {
        if ($srFenceChar) {
            $srC = [regex]::Match($srLine, '^ {0,3}(' + [regex]::Escape($srFenceChar) + '{3,})[ \t]*$')
            if ($srC.Success -and $srC.Groups[1].Value.Length -ge $srFenceLen) { $srFenceChar = ''; $srFenceLen = 0 }
            continue
        }
        $srO = [regex]::Match($srLine, '^ {0,3}(`{3,}|~{3,})')
        if ($srO.Success) { $srFenceChar = $srO.Groups[1].Value.Substring(0, 1); $srFenceLen = $srO.Groups[1].Value.Length; continue }
        [void]$srLines.Add($srLine)
    }
    $srStatus = ''
    foreach ($srLine in $srLines) {
        $srM = [regex]::Match($srLine, '^\*\*Status:\*\*[ \t]*(.*)$')
        if (-not $srM.Success) { continue }
        $srW = [regex]::Match((($srM.Groups[1].Value -replace '[*_`]', '').Trim()), '^(\w+)')
        if ($srW.Success) { $srStatus = $srW.Groups[1].Value.ToUpperInvariant() }
        break
    }
    if ($srStatus -cne 'RESOLVED') { return [pscustomobject]@{ claimed = $false; honoured = $false; why = '' } }
    $srWhy = ''
    $srPlace = $false
    try {
        $srRoot = (ConvertTo-HaltScanPath -Path $MissionRoot) + '\.mission-runtime\seats\'
        $srAt = ConvertTo-HaltScanPath -Path $srFull
        if ($srAt.StartsWith($srRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $srPlace = (@($srAt.Substring($srRoot.Length) -split '\\').Count -eq 2)
        }
    } catch { $srPlace = $false }
    if (-not $srPlace) {
        $srWhy = 'not directly inside a seat folder under .mission-runtime\seats - a RESOLVED record answers a seat-plane HALT only, and this HALT is answered by its halt-ruling gate alone'
        return [pscustomobject]@{ claimed = $true; honoured = $false; why = $srWhy }
    }
    $srHeads = @(for ($srI = 0; $srI -lt $srLines.Count; $srI++) { if ($srLines[$srI] -match '^## RESOLVED[ \t]*$') { $srI } })
    if ($srHeads.Count -ne 1) {
        return [pscustomobject]@{ claimed = $true; honoured = $false; why = "$($srHeads.Count) column-0 '## RESOLVED' heading(s), not exactly one" }
    }
    $srEnd = $srLines.Count
    for ($srI = $srHeads[0] + 1; $srI -lt $srLines.Count; $srI++) { if ($srLines[$srI] -match '^## ') { $srEnd = $srI; break } }
    $srValues = @{}
    foreach ($srLabel in @('HALT', 'Ruling', 'Ruled by', 'Ruled at', 'Resume at')) {
        $srHits = @(for ($srI = 0; $srI -lt $srLines.Count; $srI++) {
            $srM = [regex]::Match($srLines[$srI], '^\*\*' + [regex]::Escape($srLabel) + ':\*\*[ \t]*(.*)$')
            if ($srM.Success) { [pscustomobject]@{ at = $srI; value = $srM.Groups[1].Value.Trim() } }
        })
        if ($srHits.Count -ne 1) { return [pscustomobject]@{ claimed = $true; honoured = $false; why = "the field **$($srLabel):** is written $($srHits.Count) time(s) at column 0, not exactly once" } }
        if (($srHits[0].at -le $srHeads[0]) -or ($srHits[0].at -ge $srEnd)) { return [pscustomobject]@{ claimed = $true; honoured = $false; why = "the field **$($srLabel):** stands outside the RESOLVED block" } }
        if (-not $srHits[0].value) { return [pscustomobject]@{ claimed = $true; honoured = $false; why = "the field **$($srLabel):** is empty" } }
        $srValues[$srLabel] = $srHits[0].value
    }
    $srNamed = (([string]$srValues['HALT']) -replace '[*_`]', '').Trim()
    if ($srNamed -cne $srBase) { return [pscustomobject]@{ claimed = $true; honoured = $false; why = "the field **HALT:** names $srNamed, not this file's $srBase" } }
    if (([string]$srValues['Ruled at']) -notmatch '^\d{4}-\d{2}-\d{2}') { return [pscustomobject]@{ claimed = $true; honoured = $false; why = 'the field **Ruled at:** does not begin with a date YYYY-MM-DD' } }
    return [pscustomobject]@{ claimed = $true; honoured = $true; why = '' }
}

# --- THE LEGACY ALLOWLIST, DEFAULT EMPTY (the operator's migration fork) -------
# THE PROBLEM IT EXISTS FOR, STATED PLAINLY. Every HALT on the live plane was answered, where it was
# answered at all, by a seat-written marker. Under the rule above ALL of them read OPEN -- including
# the eleven HALTs the repository of record's goal scans -- so that goal reads HALT the moment
# this lands. The operator has two ways out: mint a halt-ruling gate per HALT through the console, or
# name legacy HALTs on the goal itself. This is the second, and it is EMPTY UNLESS WRITTEN.
#
# THE SHAPE. A halt_absent detector may carry ONE line (the goal reader reads single-line key: value):
#     legacy_answered_allowlist: "HALT-A.md@<sha256>, HALT-B.md@<sha256>"
# An entry is HONOURED iff ALL of: its <name>@<sha256> is a member of the LEGACY HALT CENSUS below,
# exactly (-ceq on the name, the sha lower-cased); a HALT file of EXACTLY that name is being scanned and
# its current bytes hash to that sha256; AND Test-HaltAnswered reads its legacy marker ANSWERED. A live
# halt-ruling gate outranks it. Every honoured HALT is NAMED as LEGACY-ALLOWLISTED on the detector's face
# and in the verdict artifact; every entry NOT honoured -- malformed, not-in-legacy-census, absent, sha
# moved, marker not ANSWERED -- is REPORTED, with its reason. Absent key = empty allowlist = no legacy
# HALT honoured.
#
# ONE EFFECTIVE ALLOWLIST PER RUN (a review finding, driven). The entries of EVERY halt_absent
# detector in the goal are unioned ONCE, and every halt_absent detector and the C-3 verdict path use that
# same union, with every entry's disposition decided over the same run-wide scan (Get-OpenHalts
# -ReportDirs). As first built the detector used only its own entries and the verdict path the union, so
# a goal with two detectors -- one allowlisting HALT-X, one not -- had the second detector report HALT-X
# OPEN while the verdict called it answered: NOT_MET, a Stop hook BLOCKING on a HALT only the operator can
# settle, and a verdict report that disagreed with the detector's. That is the C-3 law this file already
# states for the scan -- the detector and the verdict must not disagree inside one run -- one level out.
#
# WHY THE SHA IS REQUIRED AND NOT JUST THE NAME: the allowlist is written into a goal file by a human
# who has read that HALT at those bytes. A later edit to the HALT -- by a seat, by anybody -- moves the
# sha and un-honours the entry without anyone touching the goal, exactly as an edit voids a gate.
#
# =================================================================================================
# THE LEGACY HALT CENSUS (a review finding). DATA, NOT CONFIGURATION -- A FILE BESIDE THIS TOOL.
# =================================================================================================
# WHY IT EXISTS. The operator's migration fork admits legacy HALTs DATED BEFORE THIS AMENDMENT. As first
# built the allowlist admitted ANY HALT, and the goal file that carries it is agent-writable, so a seat
# could answer a HALT it raised itself with two edits and no gate (driven by the reviewer: MET, exit 0).
# The bound therefore cannot live in the goal file. It lives in a reviewed, tracked file beside this tool:
# every HALT a project had answered by its own marker when that rule was retired, by file name and the
# sha256 of its bytes. A goal-file entry naming anything else is reported not-in-legacy-census and
# honoured never.
#
# WHERE. tools/lam/legacy-halt-census.txt, beside this file, found through $PSScriptRoot.
# Until this release the census was a literal in this file, so an installed tool carried the first host's
# own HALTs into every project; it is now a HOST-CONFIG file the framework ships EMPTY -- a header and no
# member -- which an install writes once and an upgrade never rewrites. A project with no legacy HALTs
# leaves it empty; one upgrading from a release that carried the literal writes it, BEFORE it upgrades,
# with tools/lam/export-legacy-census.ps1 from that older evaluator (docs/framework/LAM-INSTALL.md
# section 10). Absent, or holding no member line, it is an EMPTY census: no legacy HALT is honoured.
#
# NOTHING ELSE EXTENDS IT. No parameter or environment variable is read into it; it is that file and
# nothing else. Extending it is an edit of a tracked file -- the same residual as editing any tracked tool,
# closed only by STAGE 2 and review, and stated rather than hidden.
#
# ITS FORM. LF lines (a CR before an LF is dropped), UTF-8, a byte-order mark read past as the HALT reads
# read one. A line whose first non-blank character is '#' is a comment and a blank line is nothing; every
# other line is ONE member, <HALT file name>@<64 lower-case hex sha256>, the members in ordinal order. Its
# header carries one '#   count : N' line and one '#   census_sha256 : <hex>' line, the digest over the
# CANONICAL CENSUS TEXT: each member line, sorted ordinal, each followed by exactly one LF, ASCII, no BOM
# (the digest the literal recorded, so an export of it carries the same). WP-3 C-3d recomputes the count
# and the digest from the file. Every member's BaseName matches ^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$, so
# every census HALT is rulable by a halt-ruling gate (mission-gate.ps1's -Id rule).
#
# READ ONCE, AND ONLY WHEN CONSULTED: by the first allowlist entry well-formed enough to look up, so a
# goal that names none never reads it. A line of no form above, or a path that holds something other
# than a file, THROWS: the trap writes NOT_MET with evaluator_error naming the file and the line, and a
# census that does not parse admits nothing.
$script:HaltLegacyCensusPath = Join-Path $PSScriptRoot 'legacy-halt-census.txt'
$script:HaltLegacyCensus = $null
$script:HaltLegacyCensusReason = 'not-in-legacy-census -- this <name>@<sha256> is not a member of the legacy HALT census (tools/lam/legacy-halt-census.txt beside this evaluator: the HALTs a project answered by their own marker when that rule was retired, by name and the sha256 of their bytes; absent or empty, it admits none); a HALT raised or edited after the census is answered only by a halt-ruling gate'

function Get-HaltLegacyCensus {
    # The census as a set of '<name>@<sha256>' (ordinal), read from $script:HaltLegacyCensusPath once per
    # run: absent, or holding no member line, an empty set. Throws as the block above says.
    if ($null -ne $script:HaltLegacyCensus) { return , $script:HaltLegacyCensus }
    $censusSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $censusPath = $script:HaltLegacyCensusPath
    if (Test-Path -LiteralPath $censusPath) {
        if (-not (Test-Path -LiteralPath $censusPath -PathType Leaf)) {
            throw "THE LEGACY HALT CENSUS CANNOT BE READ -- $censusPath is not a file"
        }
        $censusLines = (ConvertFrom-HaltBytes -Bytes ([System.IO.File]::ReadAllBytes($censusPath))) -split "`n"
        for ($censusAt = 0; $censusAt -lt $censusLines.Count; $censusAt++) {
            $censusMember = $censusLines[$censusAt].TrimEnd("`r").Trim()
            if ((-not $censusMember) -or $censusMember.StartsWith('#')) { continue }
            $censusMatch = [regex]::Match($censusMember, '\A([^@\\/:*?"<>|]+)@([0-9a-f]{64})\z')
            if (-not ($censusMatch.Success -and ($censusMatch.Groups[1].Value -ceq $censusMatch.Groups[1].Value.Trim()))) {
                throw ("THE LEGACY HALT CENSUS DOES NOT PARSE -- $censusPath line $($censusAt + 1) is neither " +
                       '<HALT file name>@<64 lower-case hex sha256>, a # comment nor blank: a census that does not parse admits nothing')
            }
            [void]$censusSet.Add($censusMember)
        }
    }
    $script:HaltLegacyCensus = $censusSet
    return , $censusSet
}

function ConvertFrom-HaltLegacyAllowlist {
    # Returns one pscustomobject per comma-separated entry: raw, name, sha, valid, reason. NO
    # COMMA-WRAP on the return (the Get-OpenHalts NO COMMA-WRAP note): callers wrap with @().
    # A well-formed entry that is NOT a census member is returned valid = $false with its name and sha
    # kept and the not-in-legacy-census reason, so it is reported as name@sha and never honoured.
    param([AllowNull()][AllowEmptyString()][string]$Raw)
    $parsedEntries = @()
    if ((-not $Raw) -or (-not $Raw.Trim())) { return $parsedEntries }
    foreach ($piece in ($Raw -split ',')) {
        $entryText = $piece.Trim()
        $entryMatch = [regex]::Match($entryText, '\A([^@\\/:*?"<>|]+)@([0-9a-fA-F]{64})\z')
        if ($entryMatch.Success -and ($entryMatch.Groups[1].Value -ceq $entryMatch.Groups[1].Value.Trim())) {
            $entryName = $entryMatch.Groups[1].Value
            $entrySha = $entryMatch.Groups[2].Value.ToLowerInvariant()
            $inCensus = (Get-HaltLegacyCensus).Contains($entryName + '@' + $entrySha)
            $parsedEntries += [pscustomobject]@{
                raw = $entryText; name = $entryName; sha = $entrySha; valid = $inCensus
                reason = $(if ($inCensus) { '' } else { $script:HaltLegacyCensusReason })
            }
        } else {
            $whyMalformed = if (-not $entryText) { 'MALFORMED -- an empty entry (a stray comma)' }
                            else { 'MALFORMED -- an entry must be <HALT file name>@<64-hex sha256>, one file name, no path' }
            $parsedEntries += [pscustomobject]@{ raw = $entryText; name = ''; sha = ''; valid = $false; reason = $whyMalformed }
        }
    }
    return $parsedEntries
}

# --- "which halts are open?" -- ONE definition, TWO consumers -----------------------------------
# THE PREDICATE WAS UNIFIED AND THE SCAN WAS NOT, and that is the same defect one level out. The
# `halt_absent` DETECTOR and the C-3 VERDICT path each ran their own `Get-ChildItem`, so fixing
# one made them DISAGREE INSIDE A SINGLE RUN: the detector reported the open halt and the verdict
# beneath it said none, which is exactly the failure the shared predicate was written to end.
# Caught here by a member whose scan-shape rows returned NOT_MET instead of HALT.
#
# So the ENUMERATION is shared too, not just the test it applies. A rule about which files count
# is as much a predicate as the rule about what they say.
#
# RECURSIVE AND NOT LIMITED TO .md (V-1 round 3, WP-3): the scan was `-Filter 'HALT-*.md'` with no
# `-Recurse`, so `HALT-xx.txt` or `halts/archive/HALT-xx.md` produced no HALT verdict at all.
# Widening a HALT scan can only find MORE halts, so it can only make the verdict MORE likely to be
# HALT and hand control back to the human -- the fail-closed direction, and the only direction in
# which widening a detector is safe.
#
# AND THE ONE NARROWING THAT IS SAFE, BECAUSE IT IS ABOUT SHAPE AND NOT ABOUT STATUS.
# `-Filter 'HALT-*'` is a NAME glob: case-insensitive on Windows, extension-blind, and it recurses.
# The directory it recurses into holds this arc's own TOOLS about halts -- `helpers/halt-append.py`,
# the helper that appends sections to HALT files and sets their Status lines. A Python file carries
# no canonical `**Status:**` marker, "no canonical line at all means OPEN" is fail-closed BY
# CONSTRUCTION, and so THE GOAL COULD NOT READ MET WHILE THAT FILE EXISTED UNDER THAT NAME. No
# ruling can answer a Python file. DRIVEN before this was written: with `helpers/halt-append.py`
# and `HALT-tool.ps1` the only files on disk and every detector passing, the evaluator returned
# verdict HALT and `open_halts: [HALT-tool.ps1, halt-append.py]`.
#
# THE CURE IS AN EXTENSION DENYLIST, NOT AN ALLOWLIST, and the difference is the whole argument.
# An allowlist -- or a return to `'HALT-*.md'` -- makes every artifact shape nobody enumerated
# INVISIBLE, and V-1 round 3 already measured what that costs: `HALT-xx.txt` and
# `halts/archive/HALT-xx.md` produced no HALT verdict at all. Under a denylist the exclusion set is
# closed and executable, and EVERYTHING ELSE -- .md, .txt, .markdown, .yaml, no extension at all --
# is still a halt, so widening the artifact set stays the default and the fail-closed direction is
# preserved. The residual risk is stated rather than hidden: a genuine HALT artifact named
# `HALT-xx.py` would go invisible. Nothing in this build writes one, and the instrument rows pin
# that assumption where a reader can refute it.
#
# TWO OTHER OPTIONS WERE CONSIDERED AND ARE REFUSED ON THE RECORD. BY LOCATION -- exclude
# `lam/helpers/`, or stop recursing -- re-creates the round-3 hole exactly: `halts/archive/HALT-xx.md`
# is a real halt one directory down, and no location rule separates that subdirectory from a
# helpers one without a hand list that rots. BY REQUIRED CANONICAL HEADER inverts the fail
# direction: a genuine HALT whose header was mistyped becomes INVISIBLE -- a false MET, the silent
# direction, strictly worse than the false HALT this row is about. GIVING THE HELPER AN ANSWERED
# MARKER is refused too: putting a HALT marker in a Python file to satisfy a HALT detector is "never
# fix the state to satisfy a checker" inverted, and it would establish that any future genuinely-open
# HALT can be silenced the same way.
#
# AND THE SKIP IS NOT SILENT. A narrowing that hides a file without saying so is the same class of
# defect one level down, so every skipped name is collected in $script:HaltScanSkipped and surfaced
# twice: in the `halt_absent` detail, and as `halt_scan_skipped:` in the verdict artifact. That
# leaves a record on disk a reader can refute. The list is emitted SINGLE-QUOTED with embedded
# quotes doubled, for the reason the UNREADABLE entry below records: a bare YAML scalar carrying
# `: ` silently stops being a string and becomes a single-key MAP, and the narrowing's own report
# must not become the unparsable artifact.
$script:HaltToolExtensions = @('.py','.pyc','.pyo','.pyw','.ps1','.psm1','.psd1','.sh','.bash','.zsh',
                               '.bat','.cmd','.js','.mjs','.cjs','.ts','.rb','.pl','.exe','.dll')
$script:HaltScanSkipped = @()
# FOUR MORE REPORTS, reset and filled by every Get-OpenHalts call exactly as HaltScanSkipped is:
#   HaltCitationSidecarsSkipped  <HALT>.ruling-citation.yaml files set aside BEFORE the read
#   HaltsAnsweredByGate          HALT names a live halt-ruling gate answers (Test-HaltRuled)
#   HaltsAnsweredByLegacy        name@sha of HALTs a legacy allowlist entry answers (LEGACY-ALLOWLISTED)
#   HaltLegacyAllowlistReport    every allowlist entry NOT honoured, with its reason
$script:HaltCitationSidecarsSkipped = @()
$script:HaltsAnsweredByGate = @()
$script:HaltsAnsweredByLegacy = @()
$script:HaltLegacyAllowlistReport = @()
$script:HaltCitationSidecarSuffix = '.ruling-citation.yaml'
# Reset and filled the same way: HALTs of the seat plane a RESOLVED record answers
# (Get-HaltSeatResolution). Reported only when one is, so every artifact without one reads as before.
$script:HaltsResolvedBySeatRecord = @()

# =================================================================================================
# A RULING AND THE BATCH-3 CHARTER: THE SCAN
# STATES ITS ROOTS, AND TWO KINDS OF PLACE ARE NOT COUNTED BY RULE.
# =================================================================================================
# THE FACT. On 2026-10-01 the live goal read HALT over two files that were validator FIXTURES: HALT-R-1.md
# and HALT-R.md, each in the .mission-runtime\halts of a FIXTURE mission root that a scratch tree had left
# under the live root's .mission-runtime\lam\close\. The recursive HALT-* scan read them as live HALTs, an
# open HALT outranks every arm and every verdict, and so every stop at the root was admitted under any
# goal until the operator moved the tree away by hand.
#
# THE RULE, two clauses, each decided on the PATH and on nothing a file says:
#   A NESTED MISSION ROOT  a file is not counted when some directory on its path STRICTLY BELOW the scan
#       root it was found under -- that scan root itself at or below the live mission root -- carries its
#       own .mission\ directory. The topmost such directory is the nested root, and it is named.
#   THE SCRATCH-COPIES TREE  a file under <MissionRoot>\.mission-runtime\scratch-copies\ is not counted,
#       whichever root reached it and whether or not a goal declared a dir there (standing G.12: scratch
#       copies live there, and nothing there is a live HALT).
# WHAT THE RULE DOES NOT REACH, each driven by WP-3 C-3h: a plain subdirectory (halts\archive\HALT-xx.md is
# counted, as V-1 round 3 made it); a directory carrying only .mission-runtime\ and no .mission\ (the
# charter's words are "carrying its own .mission/"; the ruling's candidate named either, and the
# narrower one is built, because an exclusion can only hide files); a FILE named .mission; A SCAN ROOT
# ITSELF, which is never a nested root whatever it carries -- so a .mission directory planted in
# .mission-runtime\halts hides nothing; and a scan root outside the live mission root.
#
# "BY LOCATION" WAS REFUSED ON THE RECORD ABOVE and this is a location rule, so the difference
# is stated: that refusal was of a HAND LIST of directory names, which rots. This rule names no
# directory but one the standing fixes, and otherwise reads a STRUCTURE -- a mission root inside a
# mission root -- which a fixture has and a HALT plane does not.
#
# AND IT IS NEVER SILENT. Every root this run's C-3 scan read is written to the verdict artifact as
# halt_scan_roots, on every evaluation, and every excluded root with the number of HALT-* files not
# counted under it as halt_scan_excluded; the halt_absent detail names them too.
#
# WHAT IT GIVES UP: a real HALT moved under a directory that carries .mission\ is not counted -- as one
# moved out of the scanned planes, renamed or deleted is not counted today; those leave no trace, and
# this one is named in the verdict on every evaluation.
$script:HaltScanRootsReport = @()
$script:HaltScanExcludedReport = @()
function ConvertTo-HaltScanPath {
    # ONE SPELLING for every path the rule compares, keys on and reports: the full path, a leading \\?\
    # taken off, no trailing separator. Two spellings of one place must not read as two places -- nor a
    # root be reported in one spelling and what was set aside under it in another. Throws where the path
    # has no full form; each caller says what it does then.
    param([string]$Path)
    $hsFull = [System.IO.Path]::GetFullPath($Path)
    if ($hsFull.StartsWith('\\?\UNC\', [System.StringComparison]::OrdinalIgnoreCase)) { $hsFull = '\\' + $hsFull.Substring(8) }
    elseif ($hsFull.StartsWith('\\?\', [System.StringComparison]::Ordinal)) { $hsFull = $hsFull.Substring(4) }
    return $hsFull.TrimEnd('\')
}
function Get-HaltScanExclusion {
    # '' when the file is counted; otherwise '<kind>|<excluded root>'. -Cache holds one answer per
    # directory asked, for the run of one Get-OpenHalts call, and it is keyed ORDINALLY, case folded: a
    # culture-aware table reads `strasse` and its sharp-s spelling as one key, and would hand a plain
    # directory the answer cached for a nested root beside it. -RunRoots is every scan root of this RUN,
    # in ConvertTo-HaltScanPath's spelling: none of them is ever a nested root, under whichever root a
    # file was reached, so a halt_absent detector and the verdict beneath it apply one exemption.
    # What cannot be spelled is COUNTED: an exclusion can only hide files.
    param([string]$MissionRoot, [string]$ScanRoot, [string]$FilePath, [System.Collections.Hashtable]$Cache,
          [AllowNull()][System.Collections.Generic.HashSet[string]]$RunRoots)
    $hxOic = [System.StringComparison]::OrdinalIgnoreCase
    $hxRoot = ''
    $hxScan = ''
    $hxFile = ''
    try {
        $hxRoot = ConvertTo-HaltScanPath -Path $MissionRoot
        $hxScan = ConvertTo-HaltScanPath -Path $ScanRoot
        $hxFile = ConvertTo-HaltScanPath -Path $FilePath
    } catch { return '' }
    $hxScratch = $hxRoot + '\.mission-runtime\scratch-copies'
    if ($hxFile.StartsWith($hxScratch + '\', $hxOic)) { return ('the scratch-copies tree|' + $hxScratch) }
    if (-not ([string]::Equals($hxScan, $hxRoot, $hxOic) -or $hxScan.StartsWith($hxRoot + '\', $hxOic))) { return '' }
    if (-not $hxFile.StartsWith($hxScan + '\', $hxOic)) { return '' }
    $hxParts = @($hxFile.Substring($hxScan.Length + 1) -split '\\')
    $hxDir = $hxScan
    for ($hxAt = 0; $hxAt -lt ($hxParts.Count - 1); $hxAt++) {
        $hxDir = $hxDir + '\' + $hxParts[$hxAt]
        if (($null -ne $RunRoots) -and $RunRoots.Contains($hxDir)) { continue }
        if (-not $Cache.ContainsKey($hxDir)) { $Cache[$hxDir] = [System.IO.Directory]::Exists($hxDir + '\.mission') }
        if ($Cache[$hxDir]) { return ('a nested mission root (it carries its own .mission\)|' + $hxDir) }
    }
    return ''
}
function Get-OpenHalts {
    # -ReportDirs (a review finding): the RUN-WIDE scan the allowlist's per-entry dispositions
    # are decided over -- every directory any halt_absent consumer of this run scans. A HALT found there
    # but outside -Dirs never enters this call's open list or its skip and answer lists; it is read only
    # so that an entry's disposition ("honoured", "sha256 MISMATCH", ...) is the same statement in every
    # detector and in the verdict, whichever subset of the plane each one scans.
    param([string]$MissionRoot, [AllowNull()][string[]]$Dirs, [AllowNull()][object[]]$LegacyAllowlist,
          [AllowNull()][string[]]$ReportDirs)
    $dirs = if ($Dirs) { $Dirs } else {
        @((Join-Path $MissionRoot '.mission-runtime\halts'), (Join-Path $MissionRoot '.mission-runtime\lam'))
    }
    # RESET PER CALL, and both consumers read it IMMEDIATELY after their own call. The report rides
    # a script-scoped variable rather than the return value because `return $open` is comma-free and
    # both call sites wrap it in @() -- changing the arity here is what broke `halt_absent` on every
    # mission the last time this return was touched (the NO COMMA-WRAP note below).
    $script:HaltScanSkipped = @()
    $script:HaltCitationSidecarsSkipped = @()
    $script:HaltsAnsweredByGate = @()
    $script:HaltsAnsweredByLegacy = @()
    $script:HaltLegacyAllowlistReport = @()
    $script:HaltsResolvedBySeatRecord = @()
    # One tracker per allowlist entry, so every entry that ends up NOT honoured can say WHY.
    $allowTrack = @()
    foreach ($allowEntry in @($LegacyAllowlist | Where-Object { $null -ne $_ })) {
        $allowTrack += @{ entry = $allowEntry; seen = 0; shaHit = 0; markerHit = 0; unreadable = 0; ruledHit = 0; honoured = $false; shas = @() }
    }
    $open = @()
    # THE SCAN LIST: this call's own directories first, exactly as before (in scope); then, only when an
    # allowlist is in play, any file of an allowlisted name under -ReportDirs that the own scan did not
    # already reach (out of scope: it informs dispositions and nothing else).
    $scanItems = New-Object System.Collections.Generic.List[object]
    $scanSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    # THE ROOTS THIS CALL READS, AND WHAT THE RULE SETS ASIDE UNDER THEM. Both reports are reset
    # per call and read by each consumer immediately after its own call, as HaltScanSkipped is. A file is
    # reported excluded only if NO root of this call counted it: under one root it may sit below a nested
    # mission root while another root IS that directory, and then it is counted.
    $script:HaltScanRootsReport = @()
    $script:HaltScanExcludedReport = @()
    # EVERY TABLE HERE IS KEYED ORDINALLY, CASE FOLDED (a PowerShell @{} compares by CULTURE), and every key
    # and every reported root is in ConvertTo-HaltScanPath's one spelling; a path that has none is kept as
    # written.
    $hxCache = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)
    $hxSetAside = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)
    $hxCounted = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $hxRunRoots = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($hxRunRoot in (@($dirs) + @($ReportDirs | Where-Object { $_ }))) {
        try { [void]$hxRunRoots.Add((ConvertTo-HaltScanPath -Path ([string]$hxRunRoot))) } catch { }
    }
    foreach ($dd in $dirs) {
        $hxShown = [string]$dd
        try { $hxShown = ConvertTo-HaltScanPath -Path ([string]$dd) } catch { $hxShown = [string]$dd }
        if (-not (Test-Path -LiteralPath $dd)) { $script:HaltScanRootsReport += ($hxShown + ' -- NOT ON DISK'); continue }
        $script:HaltScanRootsReport += $hxShown
        foreach ($sf in @(Get-ChildItem -LiteralPath $dd -File -Recurse -Filter 'HALT-*' -ErrorAction SilentlyContinue)) {
            $hxName = [string]$sf.FullName
            try { $hxName = ConvertTo-HaltScanPath -Path ([string]$sf.FullName) } catch { $hxName = [string]$sf.FullName }
            $hxWhy = Get-HaltScanExclusion -MissionRoot $MissionRoot -ScanRoot $dd -FilePath $sf.FullName -Cache $hxCache -RunRoots $hxRunRoots
            if ($hxWhy) { if (-not $hxSetAside.ContainsKey($hxName)) { $hxSetAside[$hxName] = $hxWhy }; continue }
            [void]$hxCounted.Add($hxName)
            [void]$scanSeen.Add($sf.FullName)
            $scanItems.Add([pscustomobject]@{ file = $sf; inScope = $true })
        }
    }
    $hxTotals = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
    foreach ($hxFileName in @($hxSetAside.Keys)) {
        if ($hxCounted.Contains([string]$hxFileName)) { continue }
        $hxKey = [string]$hxSetAside[$hxFileName]
        if ($hxTotals.ContainsKey($hxKey)) { $hxTotals[$hxKey] = [int]$hxTotals[$hxKey] + 1 } else { $hxTotals[$hxKey] = 1 }
    }
    $hxLines = New-Object System.Collections.Generic.List[string]
    foreach ($hxKey in @($hxTotals.Keys)) {
        $hxCut = ([string]$hxKey).IndexOf('|')
        $hxLines.Add(([string]$hxKey).Substring($hxCut + 1) + ' -- ' + ([string]$hxKey).Substring(0, $hxCut) + ': ' + [string]$hxTotals[$hxKey] + ' file(s) matching HALT-* under it NOT COUNTED by rule (register row 363)')
    }
    $hxSorted = [string[]]@($hxLines.ToArray())
    [System.Array]::Sort($hxSorted, [System.StringComparer]::Ordinal)
    $script:HaltScanExcludedReport = @($hxSorted)
    if ($allowTrack.Count -gt 0) {
        foreach ($rd in @($ReportDirs | Where-Object { $_ })) {
            if (-not (Test-Path -LiteralPath $rd)) { continue }
            foreach ($sf in @(Get-ChildItem -LiteralPath $rd -File -Recurse -Filter 'HALT-*' -ErrorAction SilentlyContinue)) {
                # What the rule sets aside informs no disposition either: it is not a HALT of this mission.
                if (Get-HaltScanExclusion -MissionRoot $MissionRoot -ScanRoot $rd -FilePath $sf.FullName -Cache $hxCache -RunRoots $hxRunRoots) { continue }
                if (-not $scanSeen.Add($sf.FullName)) { continue }
                $sfName = $sf.Name
                if (@($allowTrack | Where-Object { $_.entry.valid -and ($_.entry.name -ceq $sfName) }).Count -eq 0) { continue }
                $scanItems.Add([pscustomobject]@{ file = $sf; inScope = $false })
            }
        }
    }
    foreach ($scanItem in $scanItems) {
            $f = $scanItem.file
            $inScope = [bool]$scanItem.inScope
            # A TOOL ABOUT HALTS IS NOT A HALT. The test is on the extension and nothing
            # else: not on case, not on contents, not on which subdirectory the file sits in. It
            # sits BEFORE the read, so a skipped file never reaches the catch below and never
            # appears in `open_halts` -- it appears in the skipped list instead, which is a
            # different statement and is reported as one.
            if ($script:HaltToolExtensions -contains $f.Extension.ToLowerInvariant()) {
                if ($inScope) { $script:HaltScanSkipped += $f.Name }
                continue
            }
            # A RULING CITATION IS NOT A HALT EITHER. The seat's write-back now lands in
            # <HALT BaseName>.ruling-citation.yaml beside the ruled HALT, so the ruled bytes stay
            # frozen. That name matches `HALT-*`, carries no canonical marker, and would read OPEN
            # forever -- so it is set aside HERE, BEFORE the read, and reported in its OWN list,
            # distinct from the tool-extension skips, because it is a different statement. It is
            # NON-AUTHORITATIVE: nothing in it is read, so it can never answer a HALT.
            # THE SUFFIX IS MATCHED CASE-SENSITIVELY, and that is the fail-closed choice: an
            # exclusion can only hide files, so it is kept as narrow as the documented name. A
            # differently-cased sidecar is scanned, reads OPEN, and is visible at once.
            if ($f.Name.EndsWith($script:HaltCitationSidecarSuffix, [System.StringComparison]::Ordinal)) {
                if ($inScope) { $script:HaltCitationSidecarsSkipped += $f.Name }
                continue
            }
            # An ANSWERED halt is not an open one, and "answered" is a fact on disk rather than a
            # memory. NOW THAT FACT IS THE OPERATOR'S halt-ruling GATE OVER THE
            # HALT'S BYTES (Test-HaltRuled, below), not the artifact's own marker, which any writer
            # of the file could set.
            #
            # AN UNREADABLE HALT IS AN OPEN ONE (V-1 round 6, WP-3). This read had no guard, and it
            # is reached from the C-3 VERDICT path as well as from the detector -- which sits
            # OUTSIDE the per-detector try/catch added last round. Driven by an independent reader:
            # a HALT artifact that cannot be read threw out of the verdict path entirely, so the
            # evaluator exited 9, wrote NO verdict artifact at all, and the Stop hook approved.
            #
            # Same class as the throwing detector, cured in the detector loop and not here -- the
            # enumeration stopped at the loop because that was where the reader had pointed.
            #
            # It counts as OPEN rather than being skipped: a halt nobody can read is the case most
            # in need of a human, and the safe direction for this artifact is always "stop".
            #
            # READ ONCE, AS BYTES. The legacy allowlist needs the marker and the sha256 of the
            # SAME bytes, so the text is decoded from the bytes read here -- exactly as ReadAllText
            # decoded it, with the same share mode and so the same UNREADABLE cases -- rather than
            # read twice.
            $t = $null
            $haltBytes = $null
            try {
                $haltBytes = [System.IO.File]::ReadAllBytes($f.FullName)
                $t = ConvertFrom-HaltBytes -Bytes $haltBytes
            }
            catch {
                # NO COLON-SPACE IN A BARE YAML SCALAR (V-1 round 7, WP-3), AND THE REASON IS NOT
                # THE ONE FIRST WRITTEN HERE. This comment used to say `[UNREADABLE: ` made the
                # artifact "unparsable -- PyYAML refused the document". MEASURED, when a
                # falsification run reported the member blind: PyYAML ACCEPTS it. `- name [UNREADABLE:
                # msg]` is a well-formed block MAPPING, so the list item silently stops being a
                # string and becomes a single-key dict.
                #
                # That is worse than the refusal I claimed, not better. A refusal is loud and stops
                # the reader. This passes every parse, and then `"HALT-xx.md" -in $open_halts` is
                # FALSE, the halt's name comes back with `[UNREADABLE` glued onto it, and anything
                # iterating the list gets a dict where it expects a filename -- in the one artifact
                # that exists to report that a halt could not be read.
                #
                # BOTH HALVES ARE LOAD-BEARING: the literal below, and the colon strip on $msg. An
                # exception message carrying its own `: ` ("Could not find file: C:\...") produces
                # the same mapping through the other half. The detector-detail field was
                # single-quoted for exactly this reason; these two were not.
                $msg = ($_.Exception.Message -replace '[\r\n]+', ' ') -replace ':', ' -'
                if ($inScope) { $open += "$($f.Name) [UNREADABLE - $msg -- counted OPEN, because a halt that cannot be read is the one most needing a human]" }
                foreach ($tr in $allowTrack) { if ($tr.entry.valid -and ($tr.entry.name -ceq $f.Name)) { $tr.seen++; $tr.unreadable++ } }
                continue
            }
            # THE DECISION. Only an operator-minted halt-ruling gate over these exact bytes
            # answers a HALT. This line used to be `if (Test-HaltAnswered -Text $t) { continue }` --
            # the seat's own marker -- and that is the hole this closes.
            $ruled = Test-HaltRuled -HaltFile $f -MissionRoot $MissionRoot
            # THE CITATION READER, demoted: consulted for the legacy allowlist and for the detail only.
            $seatAnswered = Test-HaltAnswered -Text $t
            $legacyHit = $null
            if ($allowTrack.Count -gt 0) {
                $haltSha = Get-HaltBytesSha256 -Bytes $haltBytes
                foreach ($tr in $allowTrack) {
                    if (-not $tr.entry.valid) { continue }
                    if ($tr.entry.name -cne $f.Name) { continue }
                    $tr.seen++
                    $tr.shas += $haltSha
                    if ($ruled) { $tr.ruledHit++ }
                    if ($tr.entry.sha -cne $haltSha) { continue }
                    $tr.shaHit++
                    if (-not $seatAnswered) { continue }
                    $tr.markerHit++
                    # A GATE OUTRANKS THE ALLOWLIST: an entry is honoured only where it DECIDES.
                    if ($ruled) { continue }
                    $tr.honoured = $true
                    if ($null -eq $legacyHit) { $legacyHit = ($f.Name + '@' + $haltSha) }
                }
            }
            # OUT OF SCOPE: read for the dispositions above, and for nothing else.
            if (-not $inScope) { continue }
            if ($ruled) { $script:HaltsAnsweredByGate += $f.Name; continue }
            if ($null -ne $legacyHit) { $script:HaltsAnsweredByLegacy += $legacyHit; continue }
            # THE SEAT PLANE'S RESOLVED RECORD, read only where neither a gate nor the
            # allowlist answered: honoured directly inside a seat folder of .mission-runtime\seats and
            # nowhere else. A record that claims RESOLVED and is not honoured says why on the open entry.
            $seatResolution = Get-HaltSeatResolution -Text $t -HaltFile $f -MissionRoot $MissionRoot
            if ($seatResolution.honoured) { $script:HaltsResolvedBySeatRecord += $f.Name; continue }
            if ($seatResolution.claimed) {
                $open += "$($f.Name) [seat RESOLVED record NOT honoured - $($seatResolution.why)]"
            } elseif ($seatAnswered) {
                # NO COLON-SPACE in the annotation (the UNREADABLE note above records why), and the
                # writer single-quotes any open_halts entry that is not a bare file name regardless.
                $open += "$($f.Name) [seat marker ANSWERED; no live halt-ruling gate binds these bytes]"
            } else {
                $open += $f.Name
            }
    }
    # EVERY ENTRY NOT HONOURED IS REPORTED, WITH ITS REASON -- never silently dropped. A malformed entry
    # is reported by its raw text in brackets; a well-formed one outside the census by its name@sha.
    foreach ($tr in $allowTrack) {
        $e = $tr.entry
        if (-not $e.valid) {
            $invalidLabel = if ($e.name) { $e.name + '@' + $e.sha } else { '[' + $e.raw + ']' }
            $script:HaltLegacyAllowlistReport += ($invalidLabel + ' -- NOT HONOURED -- ' + $e.reason)
            continue
        }
        if ($tr.honoured) { continue }
        $why = ''
        if ($tr.seen -eq 0) {
            $why = "no HALT file named exactly '$($e.name)' is being scanned (absent, renamed, a different case, or skipped as tooling or as a citation sidecar)"
        } elseif (($tr.unreadable -gt 0) -and ($tr.unreadable -eq $tr.seen)) {
            $why = 'the HALT file could not be read, so it is counted OPEN'
        } elseif ($tr.shaHit -eq 0) {
            $why = "sha256 MISMATCH -- the file's current bytes hash to $((@($tr.shas | Select-Object -Unique)) -join ' / '), not the allowlisted $($e.sha); it was edited after the entry was written"
        } elseif ($tr.markerHit -eq 0) {
            $why = 'its legacy seat marker does NOT read ANSWERED at the allowlisted bytes (Test-HaltAnswered), and the allowlist honours only a legacy ANSWERED marker'
        } elseif ($tr.ruledHit -gt 0) {
            $why = 'not needed -- a live halt-ruling gate already answers this HALT, and a gate outranks the allowlist'
        } else {
            # Unreachable by construction (sha and marker matched, no gate, yet not honoured); stated
            # rather than silently folded into another reason.
            $why = 'not honoured for a reason this reader cannot name -- counted OPEN'
        }
        $script:HaltLegacyAllowlistReport += ($e.name + '@' + $e.sha + ' -- NOT HONOURED -- ' + $why)
    }
    # NO COMMA-WRAP. `return , $open` survives a bare assignment but is DOUBLE-WRAPPED by an
    # `@(Get-OpenHalts ...)` call site, so an empty result reads Count=1 and `halt_absent` failed
    # on every mission -- measured, not reasoned: five checks went red at once. Both consumers wrap
    # with @() because that is the idiom that is correct for a plain return in every arity.
    return $open
}

# =================================================================================================
# THE PLACEMENT-WINDOW ARM: detector type `ungated_placement_absent` (an amended LAM-ACCEPT;
# the operator's ruling on it, and the operator's four later rulings)
# =================================================================================================
# THE RULING, in its own words: "A placed amendment under .mission/amendments/ that is untracked and
# has no amendment-material gate is an admitted stop for the goal evaluator (a new halt_absent sibling
# arm ...); the amendment-material mint is the release; no placement-window HALT." Ruled with it for
# this package: the arm is a DETECTOR TYPE the goal file declares, in halt_absent's shape, evaluated
# first and outranking instrument_exit0; "no live gate" means no UNREVOKED amendment-material gate
# whose binds_sha256 equals the file's LF/blob sha256 -- a gate over other bytes does not release.
# AND FOUR LATER RULINGS, made on this package's pre-commit review:
#   (1) EITHER DIGEST RELEASES. mission-gate.ps1 records binds_sha256 over the file's WORKING COPY,
#       so for a placement carrying CR LF the mint's digest is not the LF/blob digest. A gate
#       releases when its binds_sha256 equals EITHER one; both are the placement's current bytes,
#       and a gate over other bytes matches neither.
#   (2) WHAT THE ARM CANNOT ESTABLISH ADMITS THE STOP -- halt_absent's doctrine (an unreadable HALT
#       counts OPEN) and this file's trap's (an evaluator error does not block). The cause rides the
#       line, in its digest slot.
#   (3) ONLY THE CANONICAL GATE COUNTS: .mission\gates\amendment-material-<id>.yaml whose own one
#       column-0 id: is <id> -- the one path mission-gate's approve, reapprove and revoke address. A
#       copy renamed aside (a .revoked-N name, a "- Copy") never releases.
#   (4) THE STATUS LINE IS THIS FILE'S OWN OUTPUT: the verdict artifact's list, the hand-run status
#       lines directly under the verdict, and the hook's reason. This file writes no STATUS.md.
#
# WHAT IT RETIRES. A seat that placed an amendment for the operator to ratify could not stop on it:
# the goal read NOT_MET and the hook blocked, so the seat raised a placement-window HALT to hand
# control back.
#
# THE DEFINITIONS THIS ARM DECIDES ON. Nothing else decides; what else it reads feeds the detail.
#   PLACEMENT  a FILE anywhere under <MissionRoot>\.mission\amendments\ (recursive, hidden files
#              included, every entry enumerated BY THE NAME AS WRITTEN -- Get-PlacementWalk) that
#              `git ls-files -z -- :(icase)<prefix>.mission/amendments`, run at the
#              top of the repository that holds the mission root (<prefix> is the mission root's
#              place in it), does not list. A file git IGNORES is such a file. Its name, extension
#              and contents are not read to decide that. Its path under .mission/amendments/ is
#              compared with git's EXACTLY where the walk found two names that fold to one (a
#              directory made case-sensitive, which needs no administrator: am-x... beside a
#              tracked AM-X... is another file), and otherwise folded as git folds under
#              core.ignorecase -- ASCII letters only, so E-acute is not its capital.
#   LF/BLOB    sha256 of the bytes git would store for it under core.autocrlf=true: CR LF pairs
#              collapsed to LF when git's own text test calls the bytes text (no NUL, no lone CR,
#              printable >> 7 not below non-printable), the raw bytes otherwise. .gitattributes is
#              not read. The bytes are read BY THE NAME AS WRITTEN (the \\?\ form): Win32 path
#              handling trims a trailing dot or space and turns NUL into a device, so without it
#              AM-X.yaml. would be hashed as AM-X.yaml, a gate over THOSE bytes would release it,
#              and the verdict would be a false MET (a validator round's finding).
#   A NAME WIN32 REWRITES -- one whose full path GetFullPath changes, or that Test-Path does not
#              find as a file by the path -Binds resolves to (a device name such as CON) -- is a
#              placement like any other, its digest its own bytes'; but mission-gate resolves -Binds
#              through that same normalization and test before it hashes, so a mint would bind ANOTHER
#              file or none: no mint is printed for it. A DIRECTORY whose name Win32 rewrites is
#              walked as itself, and each file in it is such a placement. Nor is a mint printed for a
#              placement whose name the verdict artifact's YAML does not carry as it is
#              (Get-PlacementYamlUnfaithful), or whose path or mission root carries U+FEFF, which no
#              gate in the line shape carries (Get-PlacementGateShapeFault).
#   LIVE GATE  <MissionRoot>\.mission\gates\amendment-material-<id>.yaml carrying exactly one
#              column-0 id: equal to <id> (ordinally), exactly one column-0 kind that the shared
#              classifier also reads as `amendment-material` (ordinally), exactly one column-0
#              binds_sha256 of 64 hex equal to the placement's LF/blob OR working-copy sha256 -- "exactly
#              one" of all the keys that fold to it in ASCII, and spelled exactly so
#              (Get-PlacementGateField) -- and no revoked_at (the shared Test-LamGateFieldSet), its bytes
#              UTF-8, its text decoded as ReadAllText decodes it and in the line shape the console
#              writes, so that YAML reads it as these line readers do (Get-PlacementGateShapeFault).
#              expires_at, consumed_at and binds: are not read to decide.
#   RELEASE    BY BYTES ALONE: a live gate releases EVERY placement whose bytes it binds, whatever
#              that placement's own path or the <id> on its line. The <id> is a label for the mint.
#
# WHAT CANNOT BE ESTABLISHED ADMITS, NAMED IN THE LINE'S DIGEST SLOT (ruling (2)):
#   git cannot list the tracked files  -> ONE line: id and digest UNDETERMINABLE, path .mission/amendments/
#   a directory link (a reparse point) under .mission\amendments, whose contents the walk does not
#   enter, or a directory the walk cannot list -> a line with id and digest UNDETERMINABLE, its path
#   a placement cannot be read         -> its line carries UNREADABLE in the digest slot
#   a canonical gate cannot be read    -> every placement no READABLE live gate releases carries
#                                         UNDETERMINABLE in the digest slot, the gate named beside it
$script:PlacementArmType = 'ungated_placement_absent'
$script:PlacementAwaitingPrefix = 'AWAITING AMENDMENT GATE'

function Get-PlacementLfBlobSha256 {
    # The LF/BLOB digest defined above, lower-case hex. The text test is git's own (gather_stats and
    # convert_is_binary in git's convert.c): a lone CR or a NUL makes the bytes binary, as does
    # (printable >> 7) < non-printable; BS, HT, ESC and FF count printable, DEL and every other
    # control byte non-printable, and a final 0x1A is not counted. Binary bytes, or text with no CR LF
    # pair, hash as they are.
    param([AllowNull()][byte[]]$Bytes)
    if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
    $lfNul = 0; $lfLoneCr = 0; $lfCrlf = 0; $lfPrintable = 0; $lfNonPrintable = 0
    for ($bi = 0; $bi -lt $Bytes.Length; $bi++) {
        $bc = $Bytes[$bi]
        if ($bc -eq 13) {
            if ((($bi + 1) -lt $Bytes.Length) -and ($Bytes[$bi + 1] -eq 10)) { $lfCrlf++; $bi++ } else { $lfLoneCr++ }
            continue
        }
        if ($bc -eq 10) { continue }
        if ($bc -eq 127) { $lfNonPrintable++; continue }
        if ($bc -lt 32) {
            if (($bc -eq 8) -or ($bc -eq 9) -or ($bc -eq 27) -or ($bc -eq 12)) { $lfPrintable++ }
            else {
                if ($bc -eq 0) { $lfNul++ }
                $lfNonPrintable++
            }
            continue
        }
        $lfPrintable++
    }
    if (($Bytes.Length -ge 1) -and ($Bytes[$Bytes.Length - 1] -eq 26)) { $lfNonPrintable-- }
    $lfBinary = ($lfLoneCr -gt 0) -or ($lfNul -gt 0) -or (($lfPrintable -shr 7) -lt $lfNonPrintable)
    if ($lfBinary -or ($lfCrlf -eq 0)) { return (Get-HaltBytesSha256 -Bytes $Bytes) }
    $lfStream = New-Object System.IO.MemoryStream
    try {
        for ($bi = 0; $bi -lt $Bytes.Length; $bi++) {
            if (($Bytes[$bi] -eq 13) -and (($bi + 1) -lt $Bytes.Length) -and ($Bytes[$bi + 1] -eq 10)) { continue }
            $lfStream.WriteByte($Bytes[$bi])
        }
        return (Get-HaltBytesSha256 -Bytes $lfStream.ToArray())
    } finally { $lfStream.Dispose() }
}

function Invoke-PlacementGit {
    # ONE git call through the process API (under this file's 'Stop' preference a native command's
    # stderr is fatal), read as UTF-8, with the variables that would redirect it to another repository
    # or index, or change how it reads a pathspec, removed from the CHILD's environment only. Returns
    # exit, out and err; exit -1 when git could not be run or did not finish within 60 s. Never throws.
    param([Parameter(Mandatory = $true)][string]$WorkDir, [Parameter(Mandatory = $true)][string]$GitArgs)
    $gitProc = $null
    try {
        $gitPsi = New-Object System.Diagnostics.ProcessStartInfo
        $gitPsi.FileName = 'git'
        $gitPsi.Arguments = $GitArgs
        $gitPsi.WorkingDirectory = $WorkDir
        $gitPsi.UseShellExecute = $false
        $gitPsi.CreateNoWindow = $true
        $gitPsi.RedirectStandardOutput = $true
        $gitPsi.RedirectStandardError = $true
        $gitPsi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
        $gitPsi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
        foreach ($gitVar in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR',
                              'GIT_LITERAL_PATHSPECS', 'GIT_GLOB_PATHSPECS', 'GIT_NOGLOB_PATHSPECS', 'GIT_ICASE_PATHSPECS')) {
            if ($gitPsi.EnvironmentVariables.ContainsKey($gitVar)) { $gitPsi.EnvironmentVariables.Remove($gitVar) }
        }
        $gitProc = [System.Diagnostics.Process]::Start($gitPsi)
        $gitOutTask = $gitProc.StandardOutput.ReadToEndAsync()
        $gitErrTask = $gitProc.StandardError.ReadToEndAsync()
        if (-not $gitProc.WaitForExit(60000)) {
            try { $gitProc.Kill() } catch { }
            return [pscustomobject]@{ exit = -1; out = ''; err = 'git did not finish within 60 s' }
        }
        return [pscustomobject]@{ exit = $gitProc.ExitCode; out = [string]$gitOutTask.Result; err = [string]$gitErrTask.Result }
    } catch {
        return [pscustomobject]@{ exit = -1; out = ''; err = ('git could not be run -- ' + ($_.Exception.Message -replace '[\r\n]+', ' ')) }
    } finally {
        if ($null -ne $gitProc) { $gitProc.Dispose() }
    }
}

function Get-PlacementTrackedSet {
    # "What does the repository that holds this mission root track under its .mission/amendments?"
    # TWO git calls: `rev-parse --show-toplevel --show-prefix` at the mission root, then
    # `ls-files -z -- :(icase)<prefix>.mission/amendments` at the top of the repository. :(icase)
    # because the disk walk is case-insensitive, and it reaches the <prefix> only when the pathspec
    # carries it -- a mission root in a subdirectory the index spells in another case still lists its
    # files. Paths come back relative to the mission root, '/'-separated, the .mission/amendments/ the
    # index spells in any case written as that literal, so what lies under it compares as git holds it:
    # `exact` as spelled, `folded` as ConvertTo-PlacementAsciiFold keys it -- git's own folding, ASCII
    # letters only (the caller decides which applies).
    # -Dir names ANOTHER mission directory to list the same way, relative to the mission root and
    # '/'-separated (the dispatch-manifest arm's .mission/dispatches); its default is
    # the placement arm's own, so that arm's two calls are the calls they were.
    param([Parameter(Mandatory = $true)][string]$MissionRoot, [string]$Dir = '.mission/amendments')
    $exactSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $foldedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $gitWhere = Invoke-PlacementGit -WorkDir $MissionRoot -GitArgs 'rev-parse --show-toplevel --show-prefix'
    if ($gitWhere.exit -ne 0) {
        return [pscustomobject]@{ ok = $false; exact = $exactSet; folded = $foldedSet; why = ('git rev-parse exited ' + $gitWhere.exit + ' -- ' + (($gitWhere.err -replace '[\r\n]+', ' ').Trim())) }
    }
    $gitWhereLines = @(($gitWhere.out -replace "`r", '') -split "`n")
    $gitTop = $gitWhereLines[0].Trim()
    $gitPrefix = if ($gitWhereLines.Count -gt 1) { $gitWhereLines[1].Trim() } else { '' }
    if (-not $gitTop) { return [pscustomobject]@{ ok = $false; exact = $exactSet; folded = $foldedSet; why = 'git rev-parse named no top-level directory' } }
    $gitList = Invoke-PlacementGit -WorkDir $gitTop -GitArgs ('ls-files -z -- "' + ':(icase)' + $gitPrefix + $Dir + '"')
    if ($gitList.exit -ne 0) {
        return [pscustomobject]@{ ok = $false; exact = $exactSet; folded = $foldedSet; why = ('git ls-files exited ' + $gitList.exit + ' -- ' + (($gitList.err -replace '[\r\n]+', ' ').Trim())) }
    }
    $amendPrefix = $Dir + '/'
    foreach ($trackedPath in ($gitList.out -split "`0")) {
        if (-not $trackedPath) { continue }
        $trackedRel = $trackedPath.Replace('\', '/')
        if ($gitPrefix) {
            if (-not $trackedRel.StartsWith($gitPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $trackedRel = $trackedRel.Substring($gitPrefix.Length)
        }
        if ($trackedRel.StartsWith($amendPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { $trackedRel = $amendPrefix + $trackedRel.Substring($amendPrefix.Length) }
        [void]$exactSet.Add($trackedRel)
        [void]$foldedSet.Add((ConvertTo-PlacementAsciiFold -Text $trackedRel))
    }
    return [pscustomobject]@{ ok = $true; exact = $exactSet; folded = $foldedSet; why = '' }
}

function Test-PlacementIdToken {
    # $true when YAML reads $Id as a string: it starts with a letter and is none of the words YAML 1.1
    # reads as a bool or a null (y, n, yes, no, true, false, on, off, null), in any case. Of the tokens
    # [A-Za-z0-9][A-Za-z0-9._-]*, every other one PyYAML reads as a number or a date starts with a digit.
    # PyYAML read the ids null, true, Yes, on, 2026-09-25, 010, 1.5, 0x1f and 1_000 as None, True, a
    # date or a number (the third package's pre-commit review F, driven).
    param([AllowNull()][AllowEmptyString()][string]$Id)
    $tiId = [string]$Id
    return ([regex]::IsMatch($tiId, '\A[A-Za-z]') -and (-not [regex]::IsMatch($tiId, '\A(?i:y|n|yes|no|true|false|on|off|null)\z')))
}

function ConvertTo-PlacementIdToken {
    # $Text lower-cased and reduced to [a-z0-9._-] with no leading or trailing '-' or '.', so the line's
    # <id> is one token ('placement' when nothing is left), cut to $Max characters (Limit-PlacementId),
    # and prefixed p- when what is left is not an id YAML reads as a string (Test-PlacementIdToken). The
    # test is made AFTER the cut: made before it, `on`, 198 dashes and `x` were cut to the id on (the
    # third package's pre-commit review G, driven).
    param([AllowNull()][AllowEmptyString()][string]$Text, [int]$Max = $script:PlacementIdMax)
    $itSafe = ([regex]::Replace(([string]$Text).ToLowerInvariant(), '[^a-z0-9._-]+', '-')).Trim([char[]]@('-', '.'))
    if (-not $itSafe) { return 'placement' }
    $itCut = Limit-PlacementId -Id $itSafe -Max $Max
    if (Test-PlacementIdToken -Id $itCut) { return $itCut }
    return ('p-' + (Limit-PlacementId -Id $itSafe -Max ($Max - 2)))
}

function Get-PlacementGateId {
    # The -Id an operator would mint under: am-<n> for a file named AM-<n>..., the way every live
    # amendment-material gate is named (amendment-material-am-x binds AM-X-...); otherwise the
    # file's base name reduced to an id token (ConvertTo-PlacementIdToken). A LABEL for the operator:
    # release is decided by bytes alone.
    param([Parameter(Mandatory = $true)][string]$Leaf)
    # [0-9], NOT \d: .NET's \d is every Unicode decimal digit, and the id must stay [a-z0-9._-].
    # Either way the id is cut to $script:PlacementIdMax characters (Limit-PlacementId).
    $idMatch = [regex]::Match($Leaf, '\A(?i:am)-([0-9]+)(?=[-.]|\z)')
    if ($idMatch.Success) { return (Limit-PlacementId -Id ('am-' + $idMatch.Groups[1].Value)) }
    $idBase = [System.IO.Path]::GetFileNameWithoutExtension($Leaf)
    if (-not $idBase) { $idBase = $Leaf }
    return (ConvertTo-PlacementIdToken -Text $idBase)
}

function ConvertTo-PlacementQuoted {
    # A PowerShell DOUBLE-quoted literal in which every character that could end it or expand inside it
    # is escaped with a backtick: the backtick itself, '$', and each character PowerShell reads as a
    # double quote (U+0022, U+201C, U+201D, U+201E). A placement name is chosen by the seat, so nothing
    # in it may reach the operator's terminal as code -- and the literal is not single-quoted, because
    # the verdict artifact is YAML that doubles every single quote in its raw text: a single-quoted
    # literal copied from that raw text ended early and ran the rest as code (pre-commit review of the
    # second package). Copied from the raw text, this one is still one command; but an apostrophe INSIDE
    # a value is doubled there too, so that copy names the path with the apostrophe doubled. A backtick
    # is never placed before a letter, so no escape sequence (`n, `u{...}) forms.
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $qtBuild = New-Object System.Text.StringBuilder
    foreach ($qtChar in ([string]$Text).ToCharArray()) {
        $qtCode = [int]$qtChar
        if (($qtCode -eq 0x60) -or ($qtCode -eq 0x24) -or ($qtCode -eq 0x22) -or ($qtCode -eq 0x201C) -or ($qtCode -eq 0x201D) -or ($qtCode -eq 0x201E)) { [void]$qtBuild.Append([char]0x60) }
        [void]$qtBuild.Append($qtChar)
    }
    return ([string][char]0x22 + $qtBuild.ToString() + [string][char]0x22)
}

function ConvertTo-PlacementAsciiFold {
    # git's case folding under core.ignorecase: ASCII A-Z to a-z, and NOTHING else. .NET's
    # OrdinalIgnoreCase also folds letters git keeps apart (E-acute and its capital), so a file git
    # reports untracked was counted tracked -- a false MET (pre-commit review of the second package).
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $afBuild = New-Object System.Text.StringBuilder
    foreach ($afChar in ([string]$Text).ToCharArray()) {
        $afCode = [int]$afChar
        if (($afCode -ge 65) -and ($afCode -le 90)) { [void]$afBuild.Append([char]($afCode + 32)) } else { [void]$afBuild.Append($afChar) }
    }
    return $afBuild.ToString()
}

function ConvertTo-PlacementExtendedPath {
    # THE NAME AS WRITTEN, past Win32's normalization: a \\?\ path reaches the file system unaltered, so
    # a trailing dot or space is not trimmed and NUL is not turned into a device. A \\server\share path
    # takes the \\?\UNC\ form; a path already in either extended form is returned as it is.
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.StartsWith('\\?\', [System.StringComparison]::Ordinal) -or $Path.StartsWith('\\.\', [System.StringComparison]::Ordinal)) { return $Path }
    if ($Path.StartsWith('\\', [System.StringComparison]::Ordinal)) { return ('\\?\UNC\' + $Path.Substring(2)) }
    return ('\\?\' + $Path)
}

function Get-PlacementWin32Rewrite {
    # WHAT WIN32 MAKES OF THIS FULL PATH: '' when GetFullPath -- the normalization mission-gate applies
    # to -Binds before it hashes -- returns it unchanged; otherwise what it returns, or why it threw.
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $w32Full = [System.IO.Path]::GetFullPath($Path)
        if ([string]::Equals($w32Full, $Path, [System.StringComparison]::Ordinal)) { return '' }
        return $w32Full
    } catch { return ('GetFullPath threw: ' + ($_.Exception.Message -replace '[\r\n]+', ' ')) }
}

function Read-PlacementBytes {
    # The bytes, opened the way mission-gate.ps1 opens what it hashes (Read, sharing ReadWrite and
    # Delete), so a file another process is writing can still be read -- but BY THE NAME AS WRITTEN
    # (ConvertTo-PlacementExtendedPath), never by what Win32 would make of it. Throws when it cannot.
    # COMMA-WRAPPED: a bare `return` of an EMPTY array hands the caller $null -- an empty placement
    # would read as unreadable -- and of a non-empty one unrolls it into object[]. Its callers assign
    # it, or pass it parenthesized as ONE argument; none wraps it in @(), which would double-wrap it.
    param([Parameter(Mandatory = $true)][string]$Path)
    $rbStream = New-Object System.IO.FileStream((ConvertTo-PlacementExtendedPath -Path $Path), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
                                                 ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
    try {
        $rbMem = New-Object System.IO.MemoryStream
        try { $rbStream.CopyTo($rbMem); return , ($rbMem.ToArray()) } finally { $rbMem.Dispose() }
    } finally { $rbStream.Dispose() }
}

function ConvertFrom-PlacementExtendedPath {
    # The plain path of a \\?\ (or \\?\UNC\) path; any other path as it is.
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.StartsWith('\\?\UNC\', [System.StringComparison]::Ordinal)) { return ('\\' + $Path.Substring(8)) }
    if ($Path.StartsWith('\\?\', [System.StringComparison]::Ordinal)) { return $Path.Substring(4) }
    return $Path
}

function Get-PlacementWalk {
    # EVERY ENTRY UNDER $Root, ENUMERATED BY THE NAME AS WRITTEN (\\?\), depth first. Get-ChildItem
    # entered a directory whose name Win32 rewrites BY THE REWRITTEN NAME: beside an existing sub\, a
    # sub.\ or SUB.\ was walked as sub\ or SUB\ -- its own files never seen, and sub\'s listed again
    # under another spelling, which a tracked file then did not match (pre-commit review of the second
    # package; a round-2 validator finding). Here every entry is read as it is on disk. Returns ONE object:
    #   files   one pscustomobject per file: FullName (the plain path) and Name
    #   opaque  the plain paths of the directories not entered, each once: a directory link (a reparse
    #           point), which is not followed, and a directory that could not be listed -- the root too
    param([Parameter(Mandatory = $true)][string]$Root)
    $pwFiles = New-Object System.Collections.Generic.List[object]
    $pwOpaque = New-Object System.Collections.Generic.List[string]
    $pwOpaqueSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $pwStack = New-Object 'System.Collections.Generic.Stack[string]'
    $pwStack.Push($Root)
    while ($pwStack.Count -gt 0) {
        $pwDir = $pwStack.Pop()
        $pwEntries = $null
        try { $pwEntries = (New-Object System.IO.DirectoryInfo((ConvertTo-PlacementExtendedPath -Path $pwDir))).GetFileSystemInfos() }
        catch { if ($pwOpaqueSeen.Add($pwDir)) { $pwOpaque.Add($pwDir) }; continue }
        foreach ($pwEntry in $pwEntries) {
            $pwPlain = ConvertFrom-PlacementExtendedPath -Path ([string]$pwEntry.FullName)
            if (($pwEntry.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                if (($pwEntry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    if ($pwOpaqueSeen.Add($pwPlain)) { $pwOpaque.Add($pwPlain) }
                } else { $pwStack.Push($pwPlain) }
            } else {
                $pwFiles.Add([pscustomobject]@{ FullName = $pwPlain; Name = [string]$pwEntry.Name })
            }
        }
    }
    return [pscustomobject]@{ files = $pwFiles; opaque = $pwOpaque }
}

$script:PlacementIdMax = 200
function Limit-PlacementId {
    # An <id> cut to $Max characters (the canonical gate's file name, amendment-material-<id>.yaml, is
    # then at most 224, under the 255 NTFS allows one name: an id of 232 made the console refuse the mint
    # at PREVIEW -- a round-2 validator finding), without a trailing '-' or '.'.
    param([Parameter(Mandatory = $true)][string]$Id, [int]$Max = $script:PlacementIdMax)
    if ($Id.Length -le $Max) { return $Id }
    $ltCut = $Id.Substring(0, $Max).TrimEnd([char[]]@('-', '.'))
    if (-not $ltCut) { $ltCut = 'placement' }
    return $ltCut
}

function Get-PlacementGateField {
    # ONE column-0 field of a gate's text, as the arm decides on it. Every column-0 key that FOLDS to
    # $Field -- ASCII letters folded, trailing blanks trimmed -- is counted, an empty value included, and
    # the field is taken only when exactly ONE such key exists AND it is spelled exactly $Field; its
    # value must not be empty. Counted in one case and read in another, a gate whose only kind: line said
    # push, below a `KIND: amendment-material` line, released a placement (a round-2 validator finding). Taken
    # in any case, a gate with `ID: am-x` and no id: counted as carrying its own id: (pre-commit review
    # of the third package). .NET's (?i) is not used: it folds letters outside ASCII too (the Kelvin sign
    # as K). Returns ok, count, and value ('' unless ok).
    param([AllowNull()][string]$Text, [Parameter(Mandatory = $true)][string]$Field)
    $gfCount = 0
    $gfExact = $false
    $gfValue = ''
    foreach ($gfMatch in [regex]::Matches([string]$Text, '(?m)^([^:\r\n]+):[ \t]*(\S*)')) {
        $gfKey = [string]$gfMatch.Groups[1].Value
        if (-not [string]::Equals((ConvertTo-PlacementAsciiFold -Text ($gfKey.TrimEnd([char[]]@(' ', "`t")))), $Field, [System.StringComparison]::Ordinal)) { continue }
        $gfCount++
        if ([string]::Equals($gfKey, $Field, [System.StringComparison]::Ordinal)) { $gfExact = $true; $gfValue = [string]$gfMatch.Groups[2].Value }
    }
    $gfOk = ($gfCount -eq 1) -and $gfExact -and [bool]$gfValue
    return [pscustomobject]@{ ok = $gfOk; count = $gfCount; value = $(if ($gfOk) { $gfValue } else { '' }) }
}

function Get-PlacementPlainFault {
    # '' when PyYAML builds the plain scalar $Text (its comment and trailing blanks already cut off) and
    # it holds no run of more than 4300 digits; otherwise why not. PyYAML's resolvers read = and << as
    # tags it has no constructor for, 0x or 0b followed only by underscores as an int with no digits, and
    # a date or a date and time as a timestamp, which it cannot build out of range: 2026-02-30,
    # 0000-01-01, an hour of 25, a minute or a second of 60, an offset of 24 hours or more. Nor does it
    # build a decimal int of more than 4300 digits, which Python refuses. Each of these, appended to a
    # gate in the line shape, left the gate one the arm released and PyYAML refused to load (the third
    # package's pre-commit reviews G and H, and the builder's probe of PyYAML 6.0.3, driven). A run of
    # more than 4300 digits is refused wherever it stands, in values PyYAML loads as well (review I).
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $pfText = [string]$Text
    if ([string]::Equals($pfText, '=', [System.StringComparison]::Ordinal) -or [string]::Equals($pfText, '<<', [System.StringComparison]::Ordinal)) { return ('the plain value ' + $pfText + ', which PyYAML has no constructor for') }
    foreach ($pfRun in [regex]::Matches($pfText.Replace('_', ''), '[0-9]+')) {
        if ($pfRun.Length -gt 4300) { return 'a plain value holding a run of more than 4300 digits (PyYAML cannot build a decimal int of that many; the run is refused wherever it stands)' }
    }
    if ([regex]::IsMatch($pfText, '\A[-+]?0[xb]_+\z')) { return ('the plain value ' + $pfText + ', an int with no digits') }
    $pfTs = [regex]::Match($pfText, '\A(?<y>[0-9]{4})-(?<mo>[0-9]{2})-(?<d>[0-9]{2})\z')
    if (-not $pfTs.Success) {
        $pfTs = [regex]::Match($pfText, '\A(?<y>[0-9]{4})-(?<mo>[0-9][0-9]?)-(?<d>[0-9][0-9]?)(?:[Tt]| +)(?<h>[0-9][0-9]?):(?<mi>[0-9]{2}):(?<s>[0-9]{2})(?:\.[0-9]*)?(?: *(?:Z|(?<sg>[-+])(?<th>[0-9][0-9]?)(?::(?<tm>[0-9]{2}))?))?\z')
    }
    if (-not $pfTs.Success) { return '' }
    $pfH = 0; $pfMi = 0; $pfS = 0
    if ($pfTs.Groups['h'].Success) { $pfH = [int]$pfTs.Groups['h'].Value; $pfMi = [int]$pfTs.Groups['mi'].Value; $pfS = [int]$pfTs.Groups['s'].Value }
    try { [void][System.DateTime]::new([int]$pfTs.Groups['y'].Value, [int]$pfTs.Groups['mo'].Value, [int]$pfTs.Groups['d'].Value, $pfH, $pfMi, $pfS) }
    catch { return ('the plain value ' + $pfText + ', a timestamp PyYAML cannot build') }
    if ($pfTs.Groups['sg'].Success) {
        $pfTz = ([int]$pfTs.Groups['th'].Value * 60) + $(if ($pfTs.Groups['tm'].Success) { [int]$pfTs.Groups['tm'].Value } else { 0 })
        if ($pfTz -ge 1440) { return ('the plain value ' + $pfText + ', a timestamp whose offset PyYAML cannot build') }
    }
    return ''
}

function Get-PlacementGateShapeFault {
    # '' when a gate's text is in THE LINE SHAPE THE CONSOLE WRITES -- so that what this arm reads off
    # it line by line is what YAML reads -- otherwise the first fault, named. The gate readers here and
    # in the shared library read column-0 `key: value` lines; YAML also honours quoted and tagged keys, a
    # lone CR, NEL, LS and PS as line breaks, values that continue onto later lines, and typed scalars.
    # A gate over the exact bytes that YAML reads with another kind or id, or as revoked -- `"kind": push`,
    # `note: x<CR>kind: push`, `revoked_at : <ts>`, `note:  "open` on the line above kind:,
    # `revoked_at: null-x`, `revoked_at: <U+00A0><ts>`, `id: 2026-09-25` -- released a placement (the
    # third package's pre-commit reviews E, F and G, driven); so did gates PyYAML refused to load at all
    # (reviews F and G). The shape -- every amendment-material gate on the live plane has it; one
    # composed where USERNAME or COMPUTERNAME starts with an indicator named below does not, and releases
    # nothing (review F, driven):
    #   * no lone CR; no NEL, LS or PS; no U+FEFF; and no character outside PyYAML's printable set (a C0
    #     control but TAB, LF and CR; DEL; a C1 control; U+FFFE; U+FFFF; an unpaired surrogate);
    #   * each line empty, a comment starting at column 0 with #, or `key:` at column 0 (the key
    #     [a-z0-9_]+, at most 64 characters: PyYAML refused a key of 1100, and one PyYAML builds) followed
    #     by nothing or by ONE space and a value that does not start with a character .NET's \s matches:
    #     the shared field test read `revoked_at: <U+00A0><ts>` as unset, and YAML reads it as set;
    #   * a value starting with " or ' is a quoted scalar closed on its own line, followed by nothing but
    #     blanks and a comment; a double-quoted one escapes only as PyYAML does (\0 \a \b \t \n \v \f \r
    #     \e, a backslash before a blank, a TAB, " / or itself, \N \_ \L \P, \xHH, \uHHHH, \UHHHHHHHH to
    #     U+10FFFF, neither naming a surrogate: PyYAML refused "a\qb", and libyaml "\ud800", review H);
    #     no value starts with { [ ] } & * ! | > % @ ` ? , or a lone
    #     -; a plain value holds no TAB and no ': ', does not end with ':', and is one PyYAML builds
    #     (Get-PlacementPlainFault);
    #   * the value of kind:, id: and binds_sha256: is ONE token, [A-Za-z0-9][A-Za-z0-9._-]*; id:'s is one
    #     YAML reads as a string (Test-PlacementIdToken), and binds_sha256:'s is neither all digits nor
    #     0b and binary digits: every run of 64 hex digits YAML reads as an int is one of these (review H);
    #   * a revoked_at: value that the shared field test (Test-LamGateFieldSet) reads as unset because
    #     it starts with the word null is null alone, or null before blanks and a comment: that test read
    #     `null-x` as unset, and YAML reads it as set.
    param([AllowNull()][string]$Text)
    $gsText = [string]$Text
    $gsBad = [regex]::Match($gsText, '\r(?!\n)|[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u2028\u2029\uFEFF\uFFFE\uFFFF]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]')
    if ($gsBad.Success) {
        $gsCode = [int]$gsBad.Value[0]
        if ($gsCode -eq 13) { return 'it carries a CR that is not followed by LF' }
        if ($gsCode -eq 0xFEFF) { return 'it carries U+FEFF' }
        if (($gsCode -eq 0x85) -or ($gsCode -eq 0x2028) -or ($gsCode -eq 0x2029)) { return ('it carries U+{0:X4}, which YAML reads as a line break' -f $gsCode) }
        return ('it carries U+{0:X4}, which PyYAML refuses' -f $gsCode)
    }
    $gsLines = [regex]::Split($gsText, '\r?\n')
    for ($gsI = 0; $gsI -lt $gsLines.Length; $gsI++) {
        $gsLine = $gsLines[$gsI]
        $gsAt = 'line ' + ($gsI + 1)
        if (($gsLine.Length -eq 0) -or $gsLine.StartsWith('#', [System.StringComparison]::Ordinal)) { continue }
        $gsM = [regex]::Match($gsLine, '\A([a-z0-9_]{1,64}):(?: (.*))?\z')
        if (-not $gsM.Success) { return ($gsAt + ' is neither a comment nor a column-0 "key: value" whose key is at most 64 characters') }
        $gsKey = $gsM.Groups[1].Value
        $gsKeyFault = Get-PlacementPlainFault -Text $gsKey
        if ($gsKeyFault) { return ($gsAt + ': a key PyYAML cannot build (' + $gsKeyFault + ')') }
        $gsVal = if ($gsM.Groups[2].Success) { $gsM.Groups[2].Value } else { '' }
        if ([regex]::IsMatch($gsVal, '\A\s')) { return ($gsAt + ': a value that starts with a blank or another space character') }
        if (([string]::Equals($gsKey, 'kind', [System.StringComparison]::Ordinal)) -or ([string]::Equals($gsKey, 'id', [System.StringComparison]::Ordinal)) -or ([string]::Equals($gsKey, 'binds_sha256', [System.StringComparison]::Ordinal))) {
            if (-not [regex]::IsMatch($gsVal, '\A[A-Za-z0-9][A-Za-z0-9._-]*\z')) { return ($gsAt + ': the ' + $gsKey + ': value is not one plain token') }
            if (([string]::Equals($gsKey, 'id', [System.StringComparison]::Ordinal)) -and (-not (Test-PlacementIdToken -Id $gsVal))) { return ($gsAt + ': an id: value YAML may read as other than a string') }
            if (([string]::Equals($gsKey, 'binds_sha256', [System.StringComparison]::Ordinal)) -and [regex]::IsMatch($gsVal, '\A(?:[0-9]+|0b[01]+)\z')) { return ($gsAt + ': a binds_sha256: value of all digits, or 0b and binary digits, which YAML may read as an int') }
            continue
        }
        if (([string]::Equals($gsKey, 'revoked_at', [System.StringComparison]::Ordinal)) -and [regex]::IsMatch($gsVal, '\Anull\b') -and (-not [regex]::IsMatch($gsVal, '\Anull(?: +(?:#.*)?)?\z'))) { return ($gsAt + ': a revoked_at: value the shared field test reads as unset and YAML as set') }
        if ($gsVal.Length -eq 0) { continue }
        $gsFirst = $gsVal[0]
        if ($gsFirst -eq [char]'"') {
            if (-not [regex]::IsMatch($gsVal, '\A"(?:[^"\\]|\\(?:[0abtnvfre "/\\N_LP]|\t|x[0-9A-Fa-f]{2}|u(?![dD][89A-Fa-f])[0-9A-Fa-f]{4}|U(?!0000[dD][89A-Fa-f])00(?:0[0-9A-Fa-f]|10)[0-9A-Fa-f]{4}))*"(?: +#.*)? *\z')) { return ($gsAt + ': a double-quoted value not closed on its line, or with an escape PyYAML or libyaml does not read') }
            continue
        }
        if ($gsFirst -eq [char]"'") {
            if (-not [regex]::IsMatch($gsVal, "\A'(?:[^']|'')*'(?: +#.*)? *\z")) { return ($gsAt + ': a single-quoted value not closed on its line') }
            continue
        }
        if ('{[]}&*!|>%@`?,'.IndexOf($gsFirst) -ge 0) { return ($gsAt + ': a value starting with ' + $gsFirst) }
        if (([string]::Equals($gsVal, '-', [System.StringComparison]::Ordinal)) -or $gsVal.StartsWith('- ', [System.StringComparison]::Ordinal) -or $gsVal.StartsWith('-' + [char]9, [System.StringComparison]::Ordinal)) { return ($gsAt + ': a value starting with a sequence entry') }
        if ($gsVal.Contains([string][char]9)) { return ($gsAt + ': a TAB outside quotes') }
        if ($gsVal.Contains(': ') -or $gsVal.EndsWith(':', [System.StringComparison]::Ordinal)) { return ($gsAt + ': a plain value holding ": ", or ending with ":"') }
        # The comment, cut at the first ' #' by IndexOf: an unanchored regex took 16.8 s over 60,000
        # blanks (review H, driven).
        $gsPlain = $gsVal
        $gsHash = $gsVal.IndexOf(' #', [System.StringComparison]::Ordinal)
        if ($gsHash -ge 0) { $gsPlain = $gsVal.Substring(0, $gsHash) }
        $gsPlainFault = Get-PlacementPlainFault -Text $gsPlain.TrimEnd(' ')
        if ($gsPlainFault) { return ($gsAt + ': ' + $gsPlainFault) }
    }
    return ''
}

function Get-PlacementYamlUnfaithful {
    # '' when every character of $Text comes back unchanged from the verdict artifact's YAML
    # single-quoted scalar; otherwise the first that does not, as U+XXXX. PyYAML folds LF, CR and NEL
    # (U+0085) to a space there, and refuses every character outside its printable set (TAB,
    # U+0020-U+007E, NEL, U+00A0-U+D7FF, U+E000-U+FFFD, a surrogate pair). LS (U+2028) and PS (U+2029)
    # it keeps only with no blank beside them -- a blank next to one is dropped, and one before --- or
    # ... breaks the document -- so they count as unfaithful too (the third package's pre-commit reviews,
    # driven). A mint read from the decoded artifact for a name carrying NEL named ANOTHER path:
    # AM-X<NEL>x.md became AM-X x.md, a sibling (a round-2 validator finding).
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $yfText = [string]$Text
    for ($yfI = 0; $yfI -lt $yfText.Length; $yfI++) {
        $yfCode = [int]$yfText[$yfI]
        if ($yfCode -eq 9) { continue }
        if (($yfCode -ge 0x20) -and ($yfCode -le 0x7E)) { continue }
        if (($yfCode -ge 0xA0) -and ($yfCode -le 0xD7FF) -and ($yfCode -ne 0x2028) -and ($yfCode -ne 0x2029)) { continue }
        if (($yfCode -ge 0xE000) -and ($yfCode -le 0xFFFD)) { continue }
        if (($yfCode -ge 0xD800) -and ($yfCode -le 0xDBFF) -and (($yfI + 1) -lt $yfText.Length) -and ([int]$yfText[$yfI + 1] -ge 0xDC00) -and ([int]$yfText[$yfI + 1] -le 0xDFFF)) { $yfI++; continue }
        return ('U+{0:X4}' -f $yfCode)
    }
    return ''
}

function Get-UngatedPlacements {
    # Returns ONE object (no comma-wrap; callers read its properties):
    #   fileCount       files the walk found under .mission/amendments
    #   trackedCount    of those, files git lists
    #   unwalked        directories the walk did not enter (links, and directories it could not list)
    #   undeterminable  git's reason when it could not list tracked files ('' otherwise)
    #   awaiting        one pscustomobject per ADMITTED line: rel, id, digest, line, notes, prescription
    #   released        one line per placement a live gate releases, naming the gate
    #   gateUnreadable  canonical gates that could not be read, each named with the reason
    param([Parameter(Mandatory = $true)][string]$MissionRoot)
    $awaitingList = New-Object System.Collections.Generic.List[object]
    $releasedList = New-Object System.Collections.Generic.List[string]
    $gateUnreadableList = New-Object System.Collections.Generic.List[string]
    $plResult = [pscustomobject]@{ fileCount = 0; trackedCount = 0; unwalked = 0; undeterminable = ''; awaiting = @(); released = @(); gateUnreadable = @() }
    $amendDir = Join-Path $MissionRoot '.mission\amendments'
    if (-not (Test-Path -LiteralPath $amendDir -PathType Container)) { return $plResult }
    $amendFull = (Get-Item -LiteralPath $amendDir -Force).FullName.TrimEnd('\')
    # THE WALK, BY THE NAME AS WRITTEN (Get-PlacementWalk), AND WHAT IT CANNOT SEE (ruling (2)): a
    # directory link, which it does not enter, and a directory it cannot list each become an
    # UNDETERMINABLE line naming its path, never a silent gap. A directory whose name Win32 rewrites is
    # walked like any other, as itself. A WALK THAT THROWS establishes nothing about the directory, so
    # it too is ONE UNDETERMINABLE line, the exception beside it -- never a detector that fails and
    # blocks.
    $plWalk = $null
    try { $plWalk = Get-PlacementWalk -Root $amendFull }
    catch {
        $awaitingList.Add([pscustomobject]@{ rel = '.mission/amendments/'; id = 'UNDETERMINABLE'; digest = 'UNDETERMINABLE'
            line = ($script:PlacementAwaitingPrefix + ' UNDETERMINABLE UNDETERMINABLE .mission/amendments/')
            notes = @('the walk of .mission/amendments threw (' + ($_.Exception.Message -replace '[\r\n]+', ' ') + '), so what it holds is not established')
            prescription = '' })
        $plResult.undeterminable = 'the walk of .mission/amendments threw'
        $plResult.awaiting = @($awaitingList.ToArray())
        return $plResult
    }
    $amendFiles = @($plWalk.files.ToArray())
    $plResult.fileCount = $amendFiles.Count
    $plResult.unwalked = $plWalk.opaque.Count
    foreach ($opaqueFull in $plWalk.opaque) {
        $opaqueRel = if ($opaqueFull.StartsWith($amendFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $opaqueFull.Substring($amendFull.Length + 1) } else { '' }
        $opaqueRel = '.mission/amendments/' + $opaqueRel.Replace('\', '/').TrimEnd('/') + $(if ($opaqueRel) { '/' } else { '' })
        $awaitingList.Add([pscustomobject]@{ rel = $opaqueRel; id = 'UNDETERMINABLE'; digest = 'UNDETERMINABLE'
            line = ($script:PlacementAwaitingPrefix + ' UNDETERMINABLE UNDETERMINABLE ' + $opaqueRel)
            notes = @('a directory link or a directory the walk could not list: what it holds is not established')
            prescription = '' })
    }
    if (($amendFiles.Count -eq 0) -and ($awaitingList.Count -eq 0)) { return $plResult }
    $tracked = Get-PlacementTrackedSet -MissionRoot $MissionRoot
    if (-not $tracked.ok) {
        # RULING (2): which of these files are placements is not established, and that ADMITS the stop --
        # ONE line for the directory rather than one per file, git's reason beside it.
        $plResult.undeterminable = $tracked.why
        $awaitingList.Clear()
        $awaitingList.Add([pscustomobject]@{ rel = '.mission/amendments/'; id = 'UNDETERMINABLE'; digest = 'UNDETERMINABLE'
            line = ($script:PlacementAwaitingPrefix + ' UNDETERMINABLE UNDETERMINABLE .mission/amendments/')
            notes = @('git could not list the tracked files (' + $tracked.why + '), so none of the ' + $amendFiles.Count + ' file(s) under .mission/amendments could be classified')
            prescription = '' })
        $plResult.awaiting = @($awaitingList.ToArray())
        return $plResult
    }
    # TRACKED, AS git LISTS IT: exactly where the walk found two names that fold to one (so a
    # case-sensitive directory's am-x... is not taken for the AM-X... git tracks beside it), and
    # folded otherwise (an index spelling a name in another case than the disk does) -- folded as git
    # folds, ASCII letters only (ConvertTo-PlacementAsciiFold).
    $amendEntries = New-Object System.Collections.Generic.List[object]
    $foldCounts = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([System.StringComparer]::Ordinal)
    foreach ($af in $amendFiles) {
        $afFull = [string]$af.FullName
        $afRel = if ($afFull.StartsWith($amendFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $afFull.Substring($amendFull.Length + 1) } else { [string]$af.Name }
        $afRel = '.mission/amendments/' + $afRel.Replace('\', '/')
        $afFold = ConvertTo-PlacementAsciiFold -Text $afRel
        $amendEntries.Add([pscustomobject]@{ item = $af; full = $afFull; rel = $afRel; fold = $afFold })
        if ($foldCounts.ContainsKey($afFold)) { $foldCounts[$afFold] = $foldCounts[$afFold] + 1 } else { $foldCounts[$afFold] = 1 }
    }
    $candidates = New-Object System.Collections.Generic.List[object]
    $rootYaml = Get-PlacementYamlUnfaithful -Text $MissionRoot
    foreach ($ae in $amendEntries) {
        $afFull = $ae.full
        $afRel = $ae.rel
        $afTracked = $tracked.exact.Contains($afRel) -or (($foldCounts[$ae.fold] -eq 1) -and $tracked.folded.Contains($ae.fold))
        if ($afTracked) { $plResult.trackedCount++; continue }
        # THE PRINTED -Binds, AND WHAT mission-gate WOULD RESOLVE IT TO, trimmed and '\'-separated as its
        # reapprove compares them ($sameBindsAs compares them exactly).
        $afBindsArg = $afRel.Replace('/', '\')
        $afResolved = ''
        try { $afResolved = [System.IO.Path]::GetFullPath((Join-Path $MissionRoot $afBindsArg)) } catch { $afResolved = '' }
        $afResolvedSep = ($afResolved -replace '/', '\').Trim().TrimEnd('\')
        # CAN mission-gate ADDRESS IT BY NAME? Not when Win32 rewrites its full path, and not when
        # mission-gate's own test -- Test-Path on the path it resolves -Binds to -- does not find it as a
        # file: a device name Win32 leaves unrewritten (CON, AUX, COM1.txt on this host) is such a name,
        # and mission-gate refuses it as "not on disk" (pre-commit review of the second package).
        $afWin32 = Get-PlacementWin32Rewrite -Path $afFull
        if ((-not $afWin32) -and ((-not $afResolved) -or (-not (Test-Path -LiteralPath $afResolved -PathType Leaf)))) {
            $afWin32 = 'Test-Path does not find ' + $(if ($afResolved) { $afResolved } else { 'its resolved path' }) + ' as a file by that name'
        }
        $afBytes = $null
        $afWhy = ''
        try { $afBytes = Read-PlacementBytes -Path $afFull } catch { $afWhy = ($_.Exception.Message -replace '[\r\n]+', ' ') }
        # CAN THE VERDICT ARTIFACT CARRY ITS NAME? A mint for a name whose YAML scalar does not decode to
        # the same text would name another path when read from the artifact (Get-PlacementYamlUnfaithful).
        $afYaml = Get-PlacementYamlUnfaithful -Text $afRel
        $afCand = [pscustomobject]@{ rel = $afRel; leaf = [string]$ae.item.Name; full = $afFull; bindsSep = $afBindsArg.Trim().TrimEnd('\'); resolvedSep = $afResolvedSep
                                     win32 = $afWin32; yaml = $afYaml; lfSha = ''; rawSha = ''; unreadable = $afWhy }
        if ($null -ne $afBytes) {
            $afCand.lfSha = Get-PlacementLfBlobSha256 -Bytes $afBytes
            $afCand.rawSha = Get-HaltBytesSha256 -Bytes $afBytes
        }
        $candidates.Add($afCand)
    }
    # THE GATES ARE READ ONLY WHEN THERE IS A PLACEMENT TO DECIDE, and each is read ONCE: its id, kind,
    # binds_sha256 and revoked_at answers all come from the same text. Every *.yaml in the directory is
    # read so the detail can name a NON-canonical file that binds a placement's bytes; only a canonical
    # one is ever live (ruling (3)).
    $gateRecords = New-Object System.Collections.Generic.List[object]
    $gatesDir = Join-Path $MissionRoot '.mission\gates'
    if (($candidates.Count -gt 0) -and (Test-Path -LiteralPath $gatesDir -PathType Container)) {
        foreach ($gf in @(Get-ChildItem -LiteralPath $gatesDir -File -Filter '*.yaml' -Force -ErrorAction SilentlyContinue)) {
            if ($gf.Extension -ine '.yaml') { continue }
            $gName = [string]$gf.Name
            $gNameMatch = [regex]::Match($gName, '\Aamendment-material-(.+)\.yaml\z')
            $gNameId = if ($gNameMatch.Success) { $gNameMatch.Groups[1].Value } else { '' }
            # THE TEXT, DECODED AS ReadAllText DECODES IT (mission-gate's reader, and the shared ones): UTF-8
            # unless a byte-order mark names another encoding. Decoded as UTF-8 regardless, a gate whose
            # bytes began FF FE read here as text after two replacement characters, while mission-gate read
            # it as UTF-16 and found no kind (a round-2 validator finding).
            $gText = $null
            try {
                $gBytes = Read-PlacementBytes -Path $gf.FullName
                $gReader = New-Object System.IO.StreamReader -ArgumentList @((New-Object System.IO.MemoryStream -ArgumentList (, $gBytes)), (New-Object System.Text.UTF8Encoding($false)), $true)
                try { $gText = $gReader.ReadToEnd() } finally { $gReader.Dispose() }
            }
            catch {
                if ($gNameId) { $gateUnreadableList.Add($gName + ' could not be read (' + ($_.Exception.Message -replace '[\r\n]+', ' ') + ')') }
                continue
            }
            $gKind = Get-PlacementGateField -Text $gText -Field 'kind'
            $gClass = Get-LamGateClassForText -Text $gText -Path $gf.FullName
            # THE KIND AND THE ID ARE COMPARED ORDINALLY ([string]::Equals, Ordinal), never by -ceq:
            # PowerShell's -ceq is a culture comparison that ignores a soft hyphen or a zero-width joiner,
            # so `kind: amendment-material<U+00AD>` and `id: am-x<U+2060>` passed it (pre-commit review
            # of the second package, driven). Each of kind:, id: and binds_sha256: must occur exactly ONCE
            # among the keys that fold to it, spelled exactly so (Get-PlacementGateField), and the kind must
            # also be what the shared classifier reads, its class consistent; Resolve-LamGateKind compares
            # with -ceq (lam-gate-class.ps1:148), so it is not relied on for the spelling here.
            $isAm = $gKind.ok -and [string]::Equals($gKind.value, 'amendment-material', [System.StringComparison]::Ordinal) -and $gClass.ok -and [string]::Equals([string]$gClass.kind, 'amendment-material', [System.StringComparison]::Ordinal)
            if ((-not $isAm) -and (-not $gNameId)) { continue }
            $gIdField = Get-PlacementGateField -Text $gText -Field 'id'
            $gCanonical = [bool]$gNameId -and $gIdField.ok -and [string]::Equals($gIdField.value, $gNameId, [System.StringComparison]::Ordinal)
            $gBinds = Get-PlacementGateField -Text $gText -Field 'binds_sha256'
            $gSha = ''
            if ($gBinds.ok -and ($gBinds.value -match '\A[0-9a-fA-F]{64}\z')) { $gSha = $gBinds.value.ToLowerInvariant() }
            # THE FILE A GATE NAMES, AND WHETHER IT IS SPENT, read as mission-gate's reapprove reads them:
            # the FIRST binds: and binds_resolved: lines matched case-insensitively (its -match), each
            # trimmed and '\'-separated, and consumed_at through the shared field test (its
            # Get-LamGateState). For choosing the printed id and verb, and for the diagnostic -- never for
            # release, which is by bytes alone.
            $gBindsSep = ''
            $gBindsLine = [regex]::Match($gText, '(?m)^binds:[ \t]*(.+?)[ \t]*\r?$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($gBindsLine.Success) { $gBindsSep = ($gBindsLine.Groups[1].Value -replace '/', '\').Trim().TrimEnd('\') }
            $gResolvedSep = ''
            $gResolvedLine = [regex]::Match($gText, '(?m)^binds_resolved:[ \t]*(.+?)[ \t]*\r?$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($gResolvedLine.Success) { $gResolvedSep = ($gResolvedLine.Groups[1].Value -replace '/', '\').Trim().TrimEnd('\') }
            $gRevoked = Test-LamGateFieldSet -Text $gText -Field 'revoked_at'
            $gConsumed = Test-LamGateFieldSet -Text $gText -Field 'consumed_at'
            # STRICT UTF-8, FOR THE SHAPE: the console writes UTF-8, and a gate whose bytes are not -- one
            # carrying 0xFF, or re-encoded as UTF-32 -- read here as a live gate while PyYAML refused to read
            # it at all (the third package's pre-commit review F, driven).
            $gShape = ''
            try { [void](New-Object System.Text.UTF8Encoding -ArgumentList @($false, $true)).GetString($gBytes) } catch { $gShape = 'its bytes are not UTF-8' }
            if (-not $gShape) { $gShape = Get-PlacementGateShapeFault -Text $gText }
            $gateRecords.Add([pscustomobject]@{ name = $gName; nameId = $gNameId; canonical = $gCanonical; isAm = $isAm; sha = $gSha
                                                bindsSep = $gBindsSep; resolvedSep = $gResolvedSep; revoked = $gRevoked; consumed = $gConsumed; shape = $gShape
                                                live = ($gCanonical -and $isAm -and [bool]$gSha -and (-not $gRevoked) -and (-not $gShape)) })
        }
    }
    # WHICH PLACEMENTS STILL AWAIT, released by bytes alone (ruling (1): EITHER DIGEST -- both are the
    # placement's current bytes; a gate over other bytes matches neither).
    $pending = New-Object System.Collections.Generic.List[object]
    foreach ($cand in $candidates) {
        if (-not $cand.unreadable) {
            $liveNames = @($gateRecords | Where-Object { $_.live -and (($_.sha -ceq $cand.lfSha) -or ($_.sha -ceq $cand.rawSha)) } | ForEach-Object { $_.name })
            if ($liveNames.Count -gt 0) {
                $releasedList.Add($cand.rel + ' ' + $cand.lfSha + ' -- RELEASED by ' + ($liveNames -join ', '))
                continue
            }
        }
        $pending.Add($cand)
    }
    # THE <id> ON EACH LINE, a label for the mint, chosen so every printed command CAN succeed where the
    # arm can see why it would not. mission-gate refuses an approve where a file already sits at the id's
    # canonical path, and a reapprove over a CONSUMED gate, over one of another kind, or over one whose
    # binds: -- or, failing that, binds_resolved: -- is not the -Binds it is given, compared as it
    # compares them (a validator round's finding: a consumed gate was prescribed a reapprove it refuses). So:
    # am-<n> (or the reduced base name) unless two awaiting placements derive the same one, or something
    # sits at that id's canonical path that is not a canonical, unconsumed amendment-material gate naming
    # THIS file -- then the reduced path under .mission/amendments; and while THAT is still taken, -2,
    # -3, ... In rel order, so the same disk prints the same ids. $idTakenBy answers WHY an id is taken,
    # '' when it is free.
    # "NAMES THIS FILE" is its binds: -- else its binds_resolved: -- spelled EXACTLY as the printed -Binds
    # (else as what that resolves to), '\' for '/' and trimmed, compared ORDINALLY. mission-gate's
    # reapprove accepts every such pair, since it compares the same two values case-folded. Anything
    # looser would be wrong: folding case, in a directory made case-sensitive, takes a gate over a
    # case-SIBLING (am-x... placed beside a tracked AM-X...) for this file's, and the printed
    # reapprove would retire the sibling's gate; and -ceq, a culture comparison, takes AM-Y.yaml for
    # AM-Y<U+00AD>.yaml, K for the Kelvin sign and ss for sharp s (pre-commit review of the second
    # package, driven). A gate naming the file in another spelling is passed over, and the approve
    # printed under a fresh id succeeds. A placement mission-gate cannot address by name
    # ($Cand.win32) is named by no gate: a binds: that matches its trimmed spelling names the NEIGHBOUR
    # Win32 resolves it to (pre-commit review of the second package: a name ending in a space).
    $sameBindsAs = {
        param($Gr, $Cand)
        if ($Cand.win32) { return $false }
        if (($Gr.bindsSep -ne '') -and [string]::Equals($Gr.bindsSep, $Cand.bindsSep, [System.StringComparison]::Ordinal)) { return $true }
        if ($Gr.resolvedSep -and $Cand.resolvedSep -and [string]::Equals($Gr.resolvedSep, $Cand.resolvedSep, [System.StringComparison]::Ordinal)) { return $true }
        return $false
    }
    $derivedCounts = @{}
    foreach ($pc in $pending) {
        $pcId = Get-PlacementGateId -Leaf $pc.leaf
        if ($derivedCounts.ContainsKey($pcId)) { $derivedCounts[$pcId]++ } else { $derivedCounts[$pcId] = 1 }
    }
    $usedIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $idTakenBy = {
        param($TryId, $TryCand)
        if ($usedIds.Contains($TryId)) { return 'another placement on this disk is printed under it' }
        $tryName = 'amendment-material-' + $TryId + '.yaml'
        if (-not (Test-Path -LiteralPath (Join-Path $gatesDir $tryName))) { return '' }
        # A gate there that could not be READ is not known to bind another file; no mint is printed while
        # any gate is unreadable, so the short id stands as the label.
        if (@($gateUnreadableList | Where-Object { $_.StartsWith($tryName + ' ', [System.StringComparison]::Ordinal) }).Count -gt 0) { return '' }
        $tryRec = @($gateRecords | Where-Object { [string]::Equals([string]$_.name, $tryName, [System.StringComparison]::Ordinal) })
        if ($tryRec.Count -eq 0) { return ($tryName + ' exists and is not a gate this arm reads') }
        if (-not ($tryRec[0].canonical -and $tryRec[0].isAm)) { return ($tryName + ' is not a canonical amendment-material gate') }
        if ($tryRec[0].shape) { return ($tryName + ' is not in the line shape the console writes (' + $tryRec[0].shape + ')') }
        if ($tryRec[0].consumed) { return ($tryName + ' is CONSUMED, and mission-gate refuses to reapprove a consumed gate') }
        if ($TryCand.win32) { return ($tryName + ' names another file: no gate can name this one by the path mission-gate would resolve') }
        if (-not (& $sameBindsAs $tryRec[0] $TryCand)) { return ($tryName + ' does not name this file as the printed -Binds spells it, and a reapprove must bind the file its prior binds') }
        return ''
    }
    # ORDINAL order by path: Sort-Object compares by culture, where a hyphen and a space do not order as
    # their code points, and which placement takes the plain id and which the -2 must not depend on that.
    $pendArr = $pending.ToArray()
    $pendKeys = [string[]]@($pendArr | ForEach-Object { [string]$_.rel })
    [System.Array]::Sort($pendKeys, $pendArr, [System.StringComparer]::Ordinal)
    foreach ($cand in $pendArr) {
        $candShortId = Get-PlacementGateId -Leaf $cand.leaf
        $candId = $candShortId
        $candPassedOver = if ($derivedCounts[$candId] -gt 1) { 'another awaiting placement derives the same short id' } else { [string](& $idTakenBy $candId $cand) }
        $collides = [bool]$candPassedOver
        if ($collides) {
            $candPathBase = $cand.rel.Substring('.mission/amendments/'.Length)
            $candPathExt = [System.IO.Path]::GetExtension($candPathBase)
            if ($candPathExt -and ($candPathExt.Length -lt $candPathBase.Length)) { $candPathBase = $candPathBase.Substring(0, $candPathBase.Length - $candPathExt.Length) }
            $candId = ConvertTo-PlacementIdToken -Text $candPathBase
            $candIdStem = $candId
            $candIdN = 2
            # A reduced path that, cut to the cap, equals the short id just passed over is taken as well
            # (pre-commit review of the third package: the note said the id was passed over, and the mint
            # used it).
            while (([string](& $idTakenBy $candId $cand)) -or [string]::Equals($candId, $candShortId, [System.StringComparison]::Ordinal)) {
                $candIdSuffix = '-' + $candIdN
                $candId = (Limit-PlacementId -Id $candIdStem -Max ($script:PlacementIdMax - $candIdSuffix.Length)) + $candIdSuffix
                $candIdN++
            }
        }
        [void]$usedIds.Add($candId)
        # WHY NOTHING RELEASES IT, for the operator. A DIAGNOSTIC ONLY -- none of it decides anything.
        $candNotes = New-Object System.Collections.Generic.List[string]
        if ($cand.unreadable) {
            $candNotes.Add('UNREADABLE (' + $cand.unreadable + '): no gate can be shown to bind it, so the stop is admitted on that account')
        } elseif ($cand.rawSha -cne $cand.lfSha) {
            $candNotes.Add('LF/blob ' + $cand.lfSha + ', working copy ' + $cand.rawSha + ' -- a canonical gate binding either releases it')
        }
        if ($cand.win32) {
            $candW32 = if ($cand.win32.StartsWith('GetFullPath threw', [System.StringComparison]::Ordinal) -or $cand.win32.StartsWith('Test-Path does not find', [System.StringComparison]::Ordinal)) { $cand.win32 } else { 'GetFullPath gives ' + $cand.win32 }
            $candNotes.Add('its name does not survive Win32 path handling (' + $candW32 + '): its bytes were read by the name as written, and mission-gate resolves -Binds through that normalization before it hashes, so a mint would bind another file or none')
        }
        if ($collides) { $candNotes.Add('its <id> is its reduced path (suffixed while taken): the short id ' + $candShortId + ' was passed over -- ' + $candPassedOver) }
        foreach ($gr in $gateRecords) {
            $grOver = (-not $cand.unreadable) -and [bool]$gr.sha -and (($gr.sha -ceq $cand.lfSha) -or ($gr.sha -ceq $cand.rawSha))
            if ($grOver) {
                if ($gr.shape) { $candNotes.Add($gr.name + ' binds these bytes but is not in the line shape the console writes (' + $gr.shape + '), so it never releases') }
                elseif (-not $gr.canonical) { $candNotes.Add($gr.name + ' binds these bytes but is NOT a canonical gate (its name is not amendment-material-<its one id:>.yaml), so it never releases') }
                elseif (-not $gr.isAm) { $candNotes.Add($gr.name + ' binds these bytes but its kind is not amendment-material') }
                elseif ($gr.revoked) { $candNotes.Add($gr.name + ' binds these bytes and is REVOKED') }
                continue
            }
            if ($gr.canonical -and (& $sameBindsAs $gr $cand)) {
                $grState = $(if ($gr.revoked) { ', and is revoked' } else { '' }) + $(if ($gr.consumed) { ', and is CONSUMED' } else { '' })
                if (-not $gr.sha) { $candNotes.Add($gr.name + ' names this file but carries no single 64-hex binds_sha256' + $grState) }
                else { $candNotes.Add($gr.name + ' names this file but binds OTHER bytes (' + $gr.sha + ')' + $grState) }
            }
        }
        $gateBlind = ($gateUnreadableList.Count -gt 0) -and (-not $cand.unreadable)
        foreach ($gu in $gateUnreadableList) { $candNotes.Add($gu + ' -- if it binds these bytes it was not seen, so whether this placement is gated is UNDETERMINABLE') }
        $candDigest = if ($cand.unreadable) { 'UNREADABLE' } elseif ($gateBlind) { 'UNDETERMINABLE' } else { $cand.lfSha }
        # THE MINT TO RUN, printed as ONE pasteable command that ENDS IN ' #': PowerShell reads the rest
        # of any line carrying it as a comment. The detector detail puts every placement's notes and
        # mint on one line, and a placement's name is the seat's choice, so without the mark a paste
        # running past the command to the end of that line could carry the seat's text in as code
        # (a validator round's finding). What the operator should know first rides BEFORE the command, never
        # inside it.
        $candPrescription = ''
        if ($cand.unreadable) {
            $candPrescription = 'no mint is printed for ' + $cand.rel + ': it cannot be read; re-run once it can'
        } elseif ($gateBlind) {
            $candPrescription = 'no mint is printed for ' + $cand.rel + ': a canonical gate could not be read, and it may already release this placement; re-run once it can be read'
        } elseif ($cand.win32) {
            $candPrescription = 'no mint is printed for ' + $cand.rel + ': its path does not survive Win32 path handling as written (a trailing dot or space, a device name; the note says which), so a mint would bind another file or none; renamed, it is a placement like any other'
        } elseif ($cand.yaml -or $rootYaml) {
            $candPrescription = 'no mint is printed for ' + $cand.rel + ': ' + $(if ($cand.yaml) { 'its path under .mission/amendments carries ' + $cand.yaml } else { 'the mission root''s path carries ' + $rootYaml }) + ', which the verdict artifact''s YAML does not carry as it is, so a mint read from the artifact would name another path or none; ' + $(if ($cand.yaml) { 'renamed, it is a placement like any other' } else { 'a mint can be printed under a mission root whose path does not carry it' })
        } elseif ($cand.rel.Contains([string][char]0xFEFF) -or $MissionRoot.Contains([string][char]0xFEFF)) {
            # A gate carrying U+FEFF is out of the line shape (Get-PlacementGateShapeFault), and mission-gate
            # writes the -Binds path and the mission root into the gate: such a mint could never release
            # (the third package's pre-commit review F, driven).
            $candPrescription = 'no mint is printed for ' + $cand.rel + ': ' + $(if ($cand.rel.Contains([string][char]0xFEFF)) { 'its path under .mission/amendments carries' } else { 'the mission root''s path carries' }) + ' U+FEFF, and a gate carrying it is not in the line shape the console writes, so a mint could never release it; ' + $(if ($cand.rel.Contains([string][char]0xFEFF)) { 'renamed, it is a placement like any other' } else { 'a mint can be printed under a mission root whose path does not carry it' })
        } else {
            # By the id choice above, a gate at this id's canonical path is a canonical, unconsumed
            # amendment-material gate naming THIS file, or there is none.
            $candGateExists = Test-Path -LiteralPath (Join-Path $gatesDir ('amendment-material-' + $candId + '.yaml'))
            $candVerb = if ($candGateExists) { 'reapprove' } else { 'approve' }
            $candPrescription = 'mint for ' + $cand.rel +
                $(if ($candGateExists) { ' (amendment-material-' + $candId + '.yaml already exists and binds this file, so reapprove retires it)' } else { '' }) +
                ': tools\lam\lam-console.ps1 ' + $candVerb + ' -Kind amendment-material -Id ' + (ConvertTo-PlacementQuoted $candId) +
                ' -Binds ' + (ConvertTo-PlacementQuoted $cand.rel.Replace('/', '\')) +
                $(if ($candGateExists) { ' -Reason ' + (ConvertTo-PlacementQuoted 'the placement as it stands now') } else { '' }) +
                ' -MissionRoot ' + (ConvertTo-PlacementQuoted $MissionRoot) + ' #'
        }
        $awaitingList.Add([pscustomobject]@{ rel = $cand.rel; id = $candId; digest = $candDigest
                                             line = ($script:PlacementAwaitingPrefix + ' ' + $candId + ' ' + $candDigest + ' ' + $cand.rel)
                                             notes = @($candNotes.ToArray()); prescription = $candPrescription })
    }
    $awaitArr = $awaitingList.ToArray()
    $awaitKeys = [string[]]@($awaitArr | ForEach-Object { [string]$_.rel })
    [System.Array]::Sort($awaitKeys, $awaitArr, [System.StringComparer]::Ordinal)
    $plResult.awaiting = @($awaitArr)
    $plResult.released = @($releasedList.ToArray())
    $plResult.gateUnreadable = @($gateUnreadableList.ToArray())
    return $plResult
}

# =================================================================================================
# THE DISPATCH-MANIFEST ARM: detector type `ungated_manifest_absent` (the BATCH-2
# charter, WP-H (a))
# =================================================================================================
# THE CHARTER, in its own words: "an untracked dispatch manifest under .mission/dispatches/ with no
# `dispatch-<id>` gate on disk is an admitted stop (the placement-window arm's pattern); STATUS.md head `AWAITING
# DISPATCH GATE <bare id> <sha256 LF/blob>; <working>`; the dispatch gate is the release; a tracked or
# gated manifest does not admit. The round's operator framing lives in the manifest's operator_note; a
# HALT is raised only when the round needs a ruling beyond authorization."
#
# IT IS THE PLACEMENT-WINDOW ARM'S SIBLING AND TAKES ITS SHAPE (that arm and its four rulings of
# 2026-09-24): a DETECTOR TYPE the goal file declares, evaluated first and instantly beside it and
# outranking instrument_exit0; (1) either digest releases; (2) what it cannot establish ADMITS the stop,
# the cause in the line; (3) only a canonical gate counts; (4) the line is this file's own output -- the
# verdict artifact's `awaiting_dispatch_gate` list, the hand-run status lines and the hook's reason --
# and this file writes no STATUS.md.
#
# WHAT IT RETIRES. A seat that authored a round manifest could not stop on it: the goal read NOT_MET and
# the hook blocked, so each validator round cost a HALT and a dispatch gate (standing 7;
# .mission-runtime/operator-acts.log lines 36-37, 40-41 and 43-44).
#
# THE DEFINITIONS THIS ARM DECIDES ON. Nothing else decides; what else it reads feeds the detail.
#   MANIFEST   a FILE anywhere under <MissionRoot>\.mission\dispatches\ (recursive, hidden files included,
#              walked by the name as written -- Get-PlacementWalk) whose name ends in `.manifest.yaml`,
#              ASCII case folded, that `git ls-files -z -- :(icase)<prefix>.mission/dispatches` does not
#              list (Get-PlacementTrackedSet -Dir), compared exactly where the walk found two names that
#              fold to one and folded otherwise, as the placement arm compares. A file git IGNORES is
#              such a file. Its contents are not read to decide that.
#   ITS ID     its ONE column-0 key folding to `id:`, spelled exactly so, its value the rest of its line,
#              trimmed and unquoted as Read-GoalDetectors unquotes (Get-ManifestFlatField), one token
#              [A-Za-z0-9][A-Za-z0-9._-]* -- the runner's gate-id rule -- else UNDETERMINABLE. A LABEL: the
#              bare id the operator mints under (`-Kind dispatch -Id <id>`, the gate file
#              dispatch-<id>.yaml). Release never reads it.
#   ITS NOTE   its ONE column-0 `operator_note:`, read the same way -- one line; a block scalar prints its
#              indicator -- printed beside its line (ConvertTo-ManifestDisplayText): every character the
#              verdict artifact's YAML would not keep as it is shown as '?', and more than
#              $script:ManifestNoteMax characters cut there, the cut said.
#   LIVE GATE  <MissionRoot>\.mission\gates\dispatch-<gid>.yaml carrying exactly one column-0 id: equal to
#              <gid> (ordinally), exactly one column-0 kind that the shared classifier also reads as
#              `dispatch` (ordinally), exactly one column-0 binds_sha256 of 64 hex equal to the manifest's
#              LF/blob OR working-copy sha256 -- each counted as Get-PlacementGateField counts -- and no
#              revoked_at (the shared Test-LamGateFieldSet), its bytes UTF-8 and its text in the line shape
#              the console writes (Get-PlacementGateShapeFault) once the runner's own consume list is set
#              aside (Remove-ManifestGateSpawnLines). consumed_at, expires_at and binds: are not read to
#              decide: a gate the runner has stamped at spawn still gates its manifest.
#   RELEASE    BY BYTES ALONE, as the placement arm's: a live gate releases EVERY manifest whose bytes it binds,
#              whatever its <gid> and whatever the manifest's id. The runner itself finds a gate's
#              manifest through the gate's binds: path and compares that file's working-copy sha256 with
#              binds_sha256; it never reads the manifest's id: (lam-dispatch-gate.ps1's
#              Get-LamDispatchGateDecision). THIS ARM READS NO binds: PATH: the bytes decide. One arc's
#              gates are named v-*-rN over manifests whose id: is D-V-* (dispatch-v-a-593-r1.yaml binds
#              D-V-A-593.manifest.yaml).
#
# THE LINE, `AWAITING DISPATCH GATE <id> <sha256 LF/blob>; <sha256 working>`, AND WHAT CANNOT BE
# ESTABLISHED (ruling (2)), the cause in the slot it belongs to:
#   git cannot list the tracked files, the walk throws, a directory link or an unlistable directory
#                                      -> AWAITING DISPATCH GATE UNDETERMINABLE UNDETERMINABLE; UNDETERMINABLE
#   a manifest cannot be read          -> AWAITING DISPATCH GATE UNDETERMINABLE UNREADABLE; UNREADABLE
#   its id is absent, doubled or not one token
#                                      -> AWAITING DISPATCH GATE UNDETERMINABLE <lf>; <working>
#   a dispatch-*.yaml cannot be read   -> AWAITING DISPATCH GATE <id> UNDETERMINABLE; UNDETERMINABLE
# The line carries NO PATH, as the charter writes it: the detail names each manifest's path and why, and
# two manifests of one id and the same bytes are one line (one gate releases both). NO MINT COMMAND IS
# PRINTED (the placement arm prints one): the operator composes `-Kind dispatch -Id <id> -Binds <path>`
# from the line and the detail.
$script:ManifestArmType = 'ungated_manifest_absent'
$script:ManifestAwaitingPrefix = 'AWAITING DISPATCH GATE'
$script:ManifestNoteMax = 400
$script:ManifestIdPattern = '\A[A-Za-z0-9][A-Za-z0-9._-]*\z'

function Get-ManifestFlatField {
    # ONE column-0 field of a manifest, by the flat reader this file already uses -- no YAML library. Every
    # column-0 key that FOLDS to $Field (ASCII letters; trailing blanks trimmed) is counted, and the field is
    # taken only when exactly ONE such key exists and it is spelled exactly $Field (Get-PlacementGateField's
    # discipline: which of two answers would count?); its value is the rest of its line, trimmed and
    # stripped of quotes as Read-GoalDetectors strips them. Returns ok, count, value ('' unless ok), why.
    param([AllowNull()][string]$Text, [Parameter(Mandatory = $true)][string]$Field)
    $mfCount = 0
    $mfExact = $false
    $mfValue = ''
    foreach ($mfMatch in [regex]::Matches([string]$Text, '(?m)^([^:\r\n]+):[ \t]*([^\r\n]*)')) {
        $mfKey = [string]$mfMatch.Groups[1].Value
        if (-not [string]::Equals((ConvertTo-PlacementAsciiFold -Text ($mfKey.TrimEnd([char[]]@(' ', "`t")))), $Field, [System.StringComparison]::Ordinal)) { continue }
        $mfCount++
        if ([string]::Equals($mfKey, $Field, [System.StringComparison]::Ordinal)) { $mfExact = $true; $mfValue = $mfMatch.Groups[2].Value.Trim().Trim('"').Trim("'") }
    }
    $mfWhy = ''
    if ($mfCount -eq 0) { $mfWhy = 'no column-0 ' + $Field + ': line' }
    elseif ($mfCount -gt 1) { $mfWhy = [string]$mfCount + ' column-0 keys fold to ' + $Field + ':, not one' }
    elseif (-not $mfExact) { $mfWhy = 'the column-0 key folding to ' + $Field + ': is not spelled exactly ' + $Field }
    elseif (-not $mfValue) { $mfWhy = 'its ' + $Field + ': value is empty' }
    return [pscustomobject]@{ ok = (-not $mfWhy); count = $mfCount; value = $(if (-not $mfWhy) { $mfValue } else { '' }); why = $mfWhy }
}

function ConvertTo-ManifestDisplayText {
    # SEAT-CHOSEN TEXT AS THIS FILE PRINTS IT (an operator_note, an id that is not a token, a path, a
    # HANDOFF head): TAB as one space, and every character the verdict artifact's single-quoted YAML scalar
    # would not return unchanged (Get-PlacementYamlUnfaithful's set: a control character, NEL, LS, PS, an
    # unpaired surrogate, U+FFFE, U+FFFF) as '?', so what is printed never leaves the artifact unparsable.
    # With -Max above 0, more than -Max characters are cut there -- never inside a surrogate pair -- and
    # the cut is said.
    param([AllowNull()][AllowEmptyString()][string]$Text, [int]$Max = 0)
    $dtText = [string]$Text
    $dtBuild = New-Object System.Text.StringBuilder
    for ($dtI = 0; $dtI -lt $dtText.Length; $dtI++) {
        $dtCode = [int]$dtText[$dtI]
        if ($dtCode -eq 9) { [void]$dtBuild.Append(' '); continue }
        if ((($dtCode -ge 0x20) -and ($dtCode -le 0x7E)) -or (($dtCode -ge 0xA0) -and ($dtCode -le 0xD7FF) -and ($dtCode -ne 0x2028) -and ($dtCode -ne 0x2029)) -or (($dtCode -ge 0xE000) -and ($dtCode -le 0xFFFD))) {
            [void]$dtBuild.Append($dtText[$dtI]); continue
        }
        if (($dtCode -ge 0xD800) -and ($dtCode -le 0xDBFF) -and (($dtI + 1) -lt $dtText.Length) -and ([int]$dtText[$dtI + 1] -ge 0xDC00) -and ([int]$dtText[$dtI + 1] -le 0xDFFF)) {
            [void]$dtBuild.Append($dtText[$dtI]); [void]$dtBuild.Append($dtText[$dtI + 1]); $dtI++; continue
        }
        [void]$dtBuild.Append('?')
    }
    $dtOut = $dtBuild.ToString()
    if (($Max -gt 0) -and ($dtOut.Length -gt $Max)) {
        $dtCut = $Max
        if (([int]$dtOut[$dtCut - 1] -ge 0xD800) -and ([int]$dtOut[$dtCut - 1] -le 0xDBFF)) { $dtCut-- }
        $dtOut = $dtOut.Substring(0, $dtCut) + ' [cut at ' + $Max + ' characters]'
    }
    return $dtOut
}

function Remove-ManifestGateSpawnLines {
    # A dispatch gate's text with the runner's own consume list set aside, FOR THE LINE-SHAPE TEST ALONE.
    # When exactly one column-0 `consumed_spawns:` line carrying nothing after it is followed, to the END
    # of the text, only by lines `  - {seq: <n>, dispatch_id: <id>}` -- at least one -- and the one empty
    # string a final line ending leaves, those lines are dropped: the form Read-LamDispatchConsumeBlock
    # reads and the only indented lines a gate lawfully carries (lam-dispatch-gate.ps1, "after
    # consumed_spawns, ONLY lines `  - {seq: <n>, dispatch_id: <id>}`"). Any other text is returned as it
    # is, so an indented line anywhere else, or a key after the list, is still out of the line shape.
    param([AllowNull()][string]$Text)
    $rsText = [string]$Text
    $rsLines = [regex]::Split($rsText, '\r?\n')
    $rsKeyAt = @()
    for ($rsI = 0; $rsI -lt $rsLines.Length; $rsI++) { if ($rsLines[$rsI] -cmatch '\Aconsumed_spawns:[ \t]*\z') { $rsKeyAt += $rsI } }
    if ($rsKeyAt.Count -ne 1) { return $rsText }
    $rsLast = $rsLines.Length - 1
    $rsSpawns = 0
    for ($rsJ = $rsKeyAt[0] + 1; $rsJ -le $rsLast; $rsJ++) {
        if ($rsLines[$rsJ].Length -eq 0) {
            if ($rsJ -eq $rsLast) { break }
            return $rsText
        }
        if ($rsLines[$rsJ] -cnotmatch '\A  - \{seq: [1-9][0-9]{0,8}, dispatch_id: [A-Za-z0-9][A-Za-z0-9._-]*\}\z') { return $rsText }
        $rsSpawns++
    }
    if ($rsSpawns -eq 0) { return $rsText }
    return ((@($rsLines[0..$rsKeyAt[0]]) -join "`n") + "`n")
}

function Get-UngatedManifests {
    # Returns ONE object (no comma-wrap; callers read its properties):
    #   fileCount       manifests the walk found under .mission/dispatches
    #   trackedCount    of those, manifests git lists
    #   unwalked        directories the walk did not enter (links, and directories it could not list)
    #   undeterminable  git's reason when it could not list tracked files ('' otherwise)
    #   awaiting        one pscustomobject per ADMITTED line: rel, id, line, note, notes
    #   released        one line per manifest a live gate releases, naming the gate
    #   gateUnreadable  dispatch-*.yaml gates that could not be read, each named with the reason
    param([Parameter(Mandatory = $true)][string]$MissionRoot)
    $maPrefix = $script:ManifestAwaitingPrefix
    $maUnd = $maPrefix + ' UNDETERMINABLE UNDETERMINABLE; UNDETERMINABLE'
    $awaitingList = New-Object System.Collections.Generic.List[object]
    $releasedList = New-Object System.Collections.Generic.List[string]
    $gateUnreadableList = New-Object System.Collections.Generic.List[string]
    $maResult = [pscustomobject]@{ fileCount = 0; trackedCount = 0; unwalked = 0; undeterminable = ''; awaiting = @(); released = @(); gateUnreadable = @() }
    $dispDir = Join-Path $MissionRoot '.mission\dispatches'
    if (-not (Test-Path -LiteralPath $dispDir -PathType Container)) { return $maResult }
    $dispFull = (Get-Item -LiteralPath $dispDir -Force).FullName.TrimEnd('\')
    # THE WALK, BY THE NAME AS WRITTEN, and what it cannot see (ruling (2)): a walk that throws, a
    # directory link and a directory it cannot list each become ONE UNDETERMINABLE line, never a silent gap.
    $maWalk = $null
    try { $maWalk = Get-PlacementWalk -Root $dispFull }
    catch {
        $awaitingList.Add([pscustomobject]@{ rel = '.mission/dispatches/'; id = 'UNDETERMINABLE'; line = $maUnd; note = ''
            notes = @('the walk of .mission/dispatches threw (' + ($_.Exception.Message -replace '[\r\n]+', ' ') + '), so what it holds is not established') })
        $maResult.undeterminable = 'the walk of .mission/dispatches threw'
        $maResult.awaiting = @($awaitingList.ToArray())
        return $maResult
    }
    $maFiles = @($maWalk.files.ToArray() | Where-Object { (ConvertTo-PlacementAsciiFold -Text ([string]$_.Name)).EndsWith('.manifest.yaml', [System.StringComparison]::Ordinal) })
    $maResult.fileCount = $maFiles.Count
    $maResult.unwalked = $maWalk.opaque.Count
    foreach ($opaqueFull in $maWalk.opaque) {
        $opaqueRel = if ($opaqueFull.StartsWith($dispFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $opaqueFull.Substring($dispFull.Length + 1) } else { '' }
        $opaqueRel = '.mission/dispatches/' + $opaqueRel.Replace('\', '/').TrimEnd('/') + $(if ($opaqueRel) { '/' } else { '' })
        $awaitingList.Add([pscustomobject]@{ rel = (ConvertTo-ManifestDisplayText -Text $opaqueRel); id = 'UNDETERMINABLE'; line = $maUnd; note = ''
            notes = @('a directory link or a directory the walk could not list: whether it holds a manifest is not established') })
    }
    if (($maFiles.Count -eq 0) -and ($awaitingList.Count -eq 0)) { return $maResult }
    $tracked = Get-PlacementTrackedSet -MissionRoot $MissionRoot -Dir '.mission/dispatches'
    if (-not $tracked.ok) {
        # RULING (2): which of these manifests are untracked is not established, and that ADMITS the stop --
        # ONE line for the directory, git's reason beside it.
        $maResult.undeterminable = $tracked.why
        $awaitingList.Clear()
        $awaitingList.Add([pscustomobject]@{ rel = '.mission/dispatches/'; id = 'UNDETERMINABLE'; line = $maUnd; note = ''
            notes = @('git could not list the tracked files (' + $tracked.why + '), so none of the ' + $maFiles.Count + ' manifest(s) under .mission/dispatches could be classified') })
        $maResult.awaiting = @($awaitingList.ToArray())
        return $maResult
    }
    # TRACKED, AS git LISTS IT -- exactly where the walk found two names that fold to one, folded as git
    # folds otherwise (the placement arm's rule; ASCII letters only).
    $maEntries = New-Object System.Collections.Generic.List[object]
    $maFoldCounts = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([System.StringComparer]::Ordinal)
    foreach ($mf in $maFiles) {
        $mfFull = [string]$mf.FullName
        $mfRel = if ($mfFull.StartsWith($dispFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $mfFull.Substring($dispFull.Length + 1) } else { [string]$mf.Name }
        $mfRel = '.mission/dispatches/' + $mfRel.Replace('\', '/')
        $mfFold = ConvertTo-PlacementAsciiFold -Text $mfRel
        $maEntries.Add([pscustomobject]@{ full = $mfFull; rel = $mfRel; fold = $mfFold })
        if ($maFoldCounts.ContainsKey($mfFold)) { $maFoldCounts[$mfFold] = $maFoldCounts[$mfFold] + 1 } else { $maFoldCounts[$mfFold] = 1 }
    }
    $maCands = New-Object System.Collections.Generic.List[object]
    foreach ($me in $maEntries) {
        $meTracked = $tracked.exact.Contains($me.rel) -or (($maFoldCounts[$me.fold] -eq 1) -and $tracked.folded.Contains($me.fold))
        if ($meTracked) { $maResult.trackedCount++; continue }
        $meBytes = $null
        $meWhy = ''
        try { $meBytes = Read-PlacementBytes -Path $me.full } catch { $meWhy = ($_.Exception.Message -replace '[\r\n]+', ' ') }
        $meCand = [pscustomobject]@{ rel = $me.rel; lfSha = ''; rawSha = ''; unreadable = $meWhy; id = ''; idWhy = ''; note = '' }
        if ($null -ne $meBytes) {
            $meCand.lfSha = Get-PlacementLfBlobSha256 -Bytes $meBytes
            $meCand.rawSha = Get-HaltBytesSha256 -Bytes $meBytes
            # THE TEXT, DECODED AS ReadAllText DECODES IT: UTF-8 unless a byte-order mark names another encoding.
            $meText = ''
            try {
                $meReader = New-Object System.IO.StreamReader -ArgumentList @((New-Object System.IO.MemoryStream -ArgumentList (, $meBytes)), (New-Object System.Text.UTF8Encoding($false)), $true)
                try { $meText = $meReader.ReadToEnd() } finally { $meReader.Dispose() }
            } catch { $meText = '' }
            $meId = Get-ManifestFlatField -Text $meText -Field 'id'
            if ($meId.ok -and [regex]::IsMatch($meId.value, $script:ManifestIdPattern)) { $meCand.id = $meId.value }
            elseif ($meId.ok) { $meCand.idWhy = 'its id: value ' + (ConvertTo-ManifestDisplayText -Text $meId.value -Max $script:ManifestNoteMax) + ' is not one token [A-Za-z0-9][A-Za-z0-9._-]*' }
            else { $meCand.idWhy = $meId.why }
            $meNote = Get-ManifestFlatField -Text $meText -Field 'operator_note'
            if ($meNote.ok) { $meCand.note = ConvertTo-ManifestDisplayText -Text $meNote.value -Max $script:ManifestNoteMax }
            elseif ($meNote.count -gt 0) { $meCand.note = '(not read: ' + $meNote.why + ')' }
        }
        $maCands.Add($meCand)
    }
    # THE GATES ARE READ ONLY WHEN THERE IS A MANIFEST TO DECIDE, and each is read ONCE: its id, kind,
    # binds_sha256 and revoked_at answers all come from the same text. Every *.yaml in the directory is read
    # so the detail can name a NON-canonical file that binds a manifest's bytes; only a canonical one is
    # ever live (ruling (3)).
    $maGates = New-Object System.Collections.Generic.List[object]
    $gatesDir = Join-Path $MissionRoot '.mission\gates'
    if (($maCands.Count -gt 0) -and (Test-Path -LiteralPath $gatesDir -PathType Container)) {
        foreach ($gf in @(Get-ChildItem -LiteralPath $gatesDir -File -Filter '*.yaml' -Force -ErrorAction SilentlyContinue)) {
            if ($gf.Extension -ine '.yaml') { continue }
            $gName = [string]$gf.Name
            $gNameMatch = [regex]::Match($gName, '\Adispatch-(.+)\.yaml\z')
            $gNameId = if ($gNameMatch.Success) { $gNameMatch.Groups[1].Value } else { '' }
            $gText = $null
            $gBytes = $null
            try {
                $gBytes = Read-PlacementBytes -Path $gf.FullName
                $gReader = New-Object System.IO.StreamReader -ArgumentList @((New-Object System.IO.MemoryStream -ArgumentList (, $gBytes)), (New-Object System.Text.UTF8Encoding($false)), $true)
                try { $gText = $gReader.ReadToEnd() } finally { $gReader.Dispose() }
            }
            catch {
                if ($gNameId) { $gateUnreadableList.Add($gName + ' could not be read (' + ($_.Exception.Message -replace '[\r\n]+', ' ') + ')') }
                continue
            }
            # THE KIND AND THE ID ARE COMPARED ORDINALLY, each key counted among the keys that fold to it, as
            # the placement arm reads its gates; the kind must also be what the shared classifier reads.
            $gKind = Get-PlacementGateField -Text $gText -Field 'kind'
            $gClass = Get-LamGateClassForText -Text $gText -Path $gf.FullName
            $isDispatch = $gKind.ok -and [string]::Equals($gKind.value, 'dispatch', [System.StringComparison]::Ordinal) -and $gClass.ok -and [string]::Equals([string]$gClass.kind, 'dispatch', [System.StringComparison]::Ordinal)
            if ((-not $isDispatch) -and (-not $gNameId)) { continue }
            $gIdField = Get-PlacementGateField -Text $gText -Field 'id'
            $gCanonical = [bool]$gNameId -and $gIdField.ok -and [string]::Equals($gIdField.value, $gNameId, [System.StringComparison]::Ordinal)
            $gBinds = Get-PlacementGateField -Text $gText -Field 'binds_sha256'
            $gSha = ''
            if ($gBinds.ok -and ($gBinds.value -match '\A[0-9a-fA-F]{64}\z')) { $gSha = $gBinds.value.ToLowerInvariant() }
            $gRevoked = Test-LamGateFieldSet -Text $gText -Field 'revoked_at'
            $gConsumed = Test-LamGateFieldSet -Text $gText -Field 'consumed_at'
            $gShape = ''
            try { [void](New-Object System.Text.UTF8Encoding -ArgumentList @($false, $true)).GetString($gBytes) } catch { $gShape = 'its bytes are not UTF-8' }
            if (-not $gShape) { $gShape = Get-PlacementGateShapeFault -Text (Remove-ManifestGateSpawnLines -Text $gText) }
            $maGates.Add([pscustomobject]@{ name = $gName; nameId = $gNameId; canonical = $gCanonical; isDispatch = $isDispatch; sha = $gSha; revoked = $gRevoked; consumed = $gConsumed; shape = $gShape
                                            live = ($gCanonical -and $isDispatch -and [bool]$gSha -and (-not $gRevoked) -and (-not $gShape)) })
        }
    }
    # WHICH MANIFESTS STILL AWAIT, released by bytes alone (ruling (1): EITHER DIGEST).
    $maPending = New-Object System.Collections.Generic.List[object]
    foreach ($mc in $maCands) {
        if (-not $mc.unreadable) {
            $mcLive = @($maGates | Where-Object { $_.live -and (($_.sha -ceq $mc.lfSha) -or ($_.sha -ceq $mc.rawSha)) } | ForEach-Object { $_.name })
            if ($mcLive.Count -gt 0) {
                $releasedList.Add((ConvertTo-ManifestDisplayText -Text $mc.rel) + ' ' + $mc.lfSha + ' -- RELEASED by ' + ($mcLive -join ', '))
                continue
            }
        }
        $maPending.Add($mc)
    }
    foreach ($mc in $maPending) {
        # WHY NOTHING RELEASES IT, for the operator. A DIAGNOSTIC ONLY -- none of it decides anything.
        $mcNotes = New-Object System.Collections.Generic.List[string]
        if ($mc.unreadable) { $mcNotes.Add('UNREADABLE (' + $mc.unreadable + '): its id and digests are not established, and no gate can be shown to bind it, so the stop is admitted on that account') }
        elseif ($mc.idWhy) { $mcNotes.Add('its id is UNDETERMINABLE (' + $mc.idWhy + ')') }
        foreach ($gr in $maGates) {
            $grOver = (-not $mc.unreadable) -and [bool]$gr.sha -and (($gr.sha -ceq $mc.lfSha) -or ($gr.sha -ceq $mc.rawSha))
            if ($grOver) {
                if ($gr.shape) { $mcNotes.Add($gr.name + ' binds these bytes but is not in the line shape the console and the runner write (' + $gr.shape + '), so it never releases') }
                elseif (-not $gr.canonical) { $mcNotes.Add($gr.name + ' binds these bytes but is NOT a canonical gate (its name is not dispatch-<its one id:>.yaml), so it never releases') }
                elseif (-not $gr.isDispatch) { $mcNotes.Add($gr.name + ' binds these bytes but its kind is not dispatch') }
                elseif ($gr.revoked) { $mcNotes.Add($gr.name + ' binds these bytes and is REVOKED') }
                continue
            }
            if ($mc.id -and [string]::Equals([string]$gr.nameId, $mc.id, [System.StringComparison]::Ordinal)) {
                $grState = $(if ($gr.revoked) { ', and is revoked' } else { '' }) + $(if ($gr.consumed) { ', and is CONSUMED' } else { '' })
                if (-not $gr.sha) { $mcNotes.Add($gr.name + ', the gate this manifest''s id names, carries no single 64-hex binds_sha256' + $grState) }
                else { $mcNotes.Add($gr.name + ', the gate this manifest''s id names, binds OTHER bytes (' + $gr.sha + ')' + $grState) }
            }
        }
        $mcBlind = ($gateUnreadableList.Count -gt 0) -and (-not $mc.unreadable)
        foreach ($gu in $gateUnreadableList) { $mcNotes.Add($gu + ' -- if it binds these bytes it was not seen, so whether this manifest is gated is UNDETERMINABLE') }
        $mcId = if ($mc.id) { $mc.id } else { 'UNDETERMINABLE' }
        $mcDigest = if ($mc.unreadable) { 'UNREADABLE; UNREADABLE' } elseif ($mcBlind) { 'UNDETERMINABLE; UNDETERMINABLE' } else { $mc.lfSha + '; ' + $mc.rawSha }
        $awaitingList.Add([pscustomobject]@{ rel = (ConvertTo-ManifestDisplayText -Text $mc.rel); id = $mcId; line = ($maPrefix + ' ' + $mcId + ' ' + $mcDigest); note = [string]$mc.note; notes = @($mcNotes.ToArray()) })
    }
    # ORDINAL order by path, as the placement arm orders its lines: the same disk prints the same lines.
    $maArr = $awaitingList.ToArray()
    $maKeys = [string[]]@($maArr | ForEach-Object { [string]$_.rel })
    [System.Array]::Sort($maKeys, $maArr, [System.StringComparer]::Ordinal)
    $maResult.awaiting = @($maArr)
    $maResult.released = @($releasedList.ToArray())
    $maResult.gateUnreadable = @($gateUnreadableList.ToArray())
    return $maResult
}

# =================================================================================================
# THE HANDOFF ARM: detector type `handoff_brief_present` (the BATCH-2 charter,
# WP-H (b))
# =================================================================================================
# THE CHARTER, in its own words: "STATUS.md's head reading `HANDOFF AT <ctx%> <sha256 of the brief>` with
# the brief's sha re-derived by the evaluator admits ONE stop; the successor's first stop is not admitted
# by it (the arm records the admitted head's sha in its verdict and refuses a second admission on the
# same sha). The residual is the placement window's and is stated in the amendment."
#
# WHAT IT RETIRES. A seat at a handoff seam could not stop on its brief: the goal read NOT_MET, so it
# authored a HALT to obtain the stop (standing 8).
#
# AS BUILT -- each choice the package's, stated here and in the amendment with what it gives up:
#   THE HEAD    the FIRST line of <MissionRoot>\.mission-runtime\lam\STATUS.md (the file's head: one line
#               per edition, the newest first, editions separated by ---), decoded as ReadAllText decodes
#               it -- a byte-order mark is not the head's text -- its CR and trailing blanks dropped. A
#               first line beginning `HANDOFF` (ordinally) is a HANDOFF head, and it must read, whole:
#                 HANDOFF AT <ctx%> <sha256 LF/blob>; <sha256 working> <path of the brief>
#               <ctx%> an integer 0-100 and '%' -- RECORDED TESTIMONY, never verified; the two digests the
#               placement line's two bases; the path the rest of the line, relative to the mission root or
#               absolute. The charter's minimum form carries one digest and no path: the path is what lets
#               the evaluator find the brief to re-derive it, and the two digests mirror the placement arm's two
#               bases. THE ALTERNATIVE, a brief located by convention at one fixed path, is not built: a
#               fixed path is rewritten at every handoff, so it would not say WHICH brief a stop was
#               admitted on, and the record would name a path whose bytes have since moved.
#               Any other first line is NO HANDOFF head, and the arm is inert.
#   RE-DERIVED  the brief's bytes are read by this file from that path; the head admits when its LF/blob
#               slot equals the brief's LF/blob sha256 OR its working slot equals the brief's working-copy
#               sha256 (either basis, as the placement arm's ruling (1)).
#   ONE STOP    an admission is APPENDED to THE ADMISSIONS RECORD, <MissionRoot>\.mission-runtime\lam\
#               handoff-admissions.jsonl -- JSON lines, this arm its only writer, in the runtime plane
#               .gitignore excludes whole -- and a brief whose LF/blob OR working-copy sha256 the record
#               already holds is REFUSED: under any goal, at any path, in either line ending. The append
#               re-reads the record under one exclusive handle before it writes (Add-HandoffAdmission),
#               so a second hook at the same mission root cannot admit the same brief in between. The
#               verdict file cannot be the record, because every evaluation overwrites it (D-V-A-593
#               finding).
#   HOOK ONLY   only a Stop hook's admission is recorded. A hand-run reads HANDOFF_ADMITTED and records
#               nothing, so a seat that tees its own evaluation before it stops does not spend its brief.
#   SPENT LAST  the arm is evaluated after the placement and manifest arms, and the record is written
#               only when the stop would not be admitted without it: under an open HALT or another arm's
#               admission the brief is ELIGIBLE, NOT SPENT.
#   FAIL CLOSED everything the arm cannot establish REFUSES the head -- the opposite direction from the
#               two AWAITING arms, because here the seat writes the claim itself: a head out of the form,
#               no file at its path, a brief that cannot be read, digests that match neither basis, and a
#               record that cannot be read. A REFUSED head fails no detector: it blocks nothing a met
#               goal would not. AN APPEND THAT FAILS IS NOT A REFUSED HEAD AND IS STRICTER: the head was
#               eligible, so in hook mode every other detector is already NOT EVALUATED; the arm's own
#               entry fails, the verdict is NOT_MET and the hook BLOCKS -- also a goal that would have
#               read MET -- until the record can be written or STATUS.md's first line is another.
$script:HandoffArmType = 'handoff_brief_present'
$script:HandoffAdmittedPrefix = 'HANDOFF ADMITTED'
$script:HandoffHeadPattern = '\AHANDOFF AT (?<ctx>0|[1-9][0-9]?|100)% (?<lf>[0-9A-Fa-f]{64}); (?<raw>[0-9A-Fa-f]{64}) (?<path>\S.*)\z'

function Find-HandoffRecordedLine {
    # THE RECORD'S ONE QUESTION, asked where the arm reads and again where it writes: does this text already
    # hold either digest of this brief? Each line is read as JSON and its brief_lf_sha256 and
    # brief_working_sha256 compared with both; a line that does not parse as such a record still refuses
    # whatever digest it spells (fail closed). Returns hit (the digest found, '' when none) and line (its
    # number, counting every line-feed-separated line from 1).
    param([AllowNull()][AllowEmptyString()][string]$Text, [Parameter(Mandatory = $true)][string]$Lf, [Parameter(Mandatory = $true)][string]$Raw)
    $frLine = 0
    foreach ($frRl in @(([string]$Text) -split "`n")) {
        $frLine++
        if (-not $frRl.Trim()) { continue }
        $frHit = ''
        $frObj = $null
        try { $frObj = $frRl | ConvertFrom-Json } catch { $frObj = $null }
        if (($null -ne $frObj) -and ($frObj -is [psobject]) -and (@($frObj.PSObject.Properties.Name) -contains 'brief_lf_sha256') -and (@($frObj.PSObject.Properties.Name) -contains 'brief_working_sha256')) {
            foreach ($frSha in @(([string]$frObj.brief_lf_sha256).ToLowerInvariant(), ([string]$frObj.brief_working_sha256).ToLowerInvariant())) {
                if ($frSha -and (($frSha -ceq $Lf) -or ($frSha -ceq $Raw))) { $frHit = $frSha; break }
            }
        } else {
            foreach ($frSha in @($Lf, $Raw)) { if ($frSha -and ($frRl.IndexOf($frSha, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) { $frHit = $frSha; break } }
        }
        if ($frHit) { return [pscustomobject]@{ hit = $frHit; line = $frLine } }
    }
    return [pscustomobject]@{ hit = ''; line = 0 }
}

function Test-HandoffBriefIsRecord {
    # A FINDING OF AN EARLIER REVIEW: THE ADMISSIONS RECORD IS
    # NEVER A BRIEF. "ANY file is a brief" included the arm's own record. Every admission APPENDS to it,
    # so its bytes after a stop are never the bytes the head named, the record never holds its own digest,
    # and a seat that rewrote the head's two digests to the record's new bytes after each stop was admitted
    # again and again with no brief written. (It is not the only file whose bytes move at every stop --
    # the goal's own verdict artifact is rewritten by every evaluation, and named as the brief it admitted
    # the same way. This member is the record. THE ARTIFACT IS ANOTHER'S (the
    # BATCH-4 charter): Get-HandoffDecision asks this same function, both tests, about
    # the artifact's path -- -Noun and -LongNoun say which file its sentences are about, and default to the
    # record's words, so the record's refusals read as they did.)
    # TWO TESTS, the second because a file has more names than one:
    #   BY NAME      the brief's full path is the record's (GetFullPath, ordinal, case folded) -- this is
    #                what a relative, an absolute, an upper-case, a dot-segment or a short (8.3) spelling
    #                falls to, GetFullPath giving each the one long form;
    #   BY IDENTITY  the record is held open with NO sharing and the brief is then opened. A sharing
    #                violation has two causes, and they are told apart: the hold is released and the brief
    #                opened ONCE MORE -- if it opens now the hold was the only obstacle and the brief IS the
    #                record, by a hard link or a link in its path; if it still does not, another process
    #                holds the brief, that is the brief's own trouble, and the read below reports it.
    # A spelling with no full form at all (a bare `::$DATA` suffix) names no file and is refused as that.
    # undetermined = the record could not be held (another process has it open): the question is open, and
    # the caller refuses. A COPY of the record at another path is another file -- its bytes do not move
    # when the record is appended to -- and is a brief like any other.
    param([Parameter(Mandatory = $true)][string]$BriefPath, [Parameter(Mandatory = $true)][string]$RecordPath,
          [string]$Noun = 'record', [string]$LongNoun = 'admissions record')
    $brOut = [pscustomobject]@{ same = $false; undetermined = $false; how = '' }
    try {
        if ([string]::Equals([System.IO.Path]::GetFullPath($BriefPath), [System.IO.Path]::GetFullPath($RecordPath), [System.StringComparison]::OrdinalIgnoreCase)) {
            $brOut.same = $true
            $brOut.how = 'its path is the ' + $Noun + '''s own'
            return $brOut
        }
    } catch { }
    if (-not (Test-Path -LiteralPath $RecordPath -PathType Leaf)) { return $brOut }
    $brHold = $null
    try { $brHold = New-Object System.IO.FileStream($RecordPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None) }
    catch {
        $brOut.undetermined = $true
        $brOut.how = 'the ' + $LongNoun + ' could not be held with no sharing: ' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' '))
        return $brOut
    }
    $brBlocked = $false
    try {
        $brProbe = $null
        try {
            $brProbe = New-Object System.IO.FileStream((ConvertTo-PlacementExtendedPath -Path $BriefPath), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
                                                        ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        } catch {
            # ERROR_SHARING_VIOLATION (0x80070020) or ERROR_LOCK_VIOLATION (0x80070021), on the exception or
            # the one it wraps. Any other failure is the brief's own, and the read below reports it.
            $brCodes = @()
            $brEx = $_.Exception
            while ($null -ne $brEx) { $brCodes += [int]$brEx.HResult; $brEx = $brEx.InnerException }
            if (($brCodes -contains -2147024864) -or ($brCodes -contains -2147024863)) { $brBlocked = $true }
        } finally { if ($null -ne $brProbe) { $brProbe.Dispose() } }
    } finally { $brHold.Dispose() }
    if ($brBlocked) {
        # THE HOLD RELEASED, THE BRIEF OPENED ONCE MORE. It opens: this arm's own hold was the obstacle,
        # so the brief is the record. It still does not: someone else holds it, and it is not called the
        # record on that account.
        $brAgain = $null
        try {
            $brAgain = New-Object System.IO.FileStream((ConvertTo-PlacementExtendedPath -Path $BriefPath), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
                                                        ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            $brOut.same = $true
            $brOut.how = 'it could not be opened while the ' + $Noun + ' was held with no sharing and opens once the ' + $Noun + ' is released, so it is the ' + $Noun + ' under another name'
        } catch { $brOut.same = $false }
        finally { if ($null -ne $brAgain) { $brAgain.Dispose() } }
    }
    return $brOut
}

function Get-HandoffDecision {
    # THE ARM'S READING OF THE HEAD, READ-ONLY. Returns ONE object:
    #   state       'inert' (no HANDOFF head), 'refused' (a HANDOFF head that does not admit) or 'eligible'
    #   why         the inert or refused reason, printable
    #   head        the first line as read, whole (what the record keeps); headShown: as the detail prints it
    #   ctx, path   the head's testimony and the brief's path as the head writes it
    #   lf, raw     the brief's LF/blob and working-copy sha256, RE-DERIVED here ('' until the brief is read)
    #   resolved    the brief's full path; line: the ADMITTED line when eligible
    #   statusPath, statusSha, recordPath
    # -VerdictPath is the goal's own verdict artifact, where the arm composes it: a head
    # naming THAT file as its brief is refused, as one naming the record is. Not given, nothing is asked.
    # (Its DIRECTORY is read too: it is the goal file's own directory, one of the
    # three in which a file named `*.verdict.yaml` is never a brief. Not given, the other two still are.)
    param([Parameter(Mandatory = $true)][string]$MissionRoot, [string]$VerdictPath = '')
    $hdStatus = Join-Path $MissionRoot '.mission-runtime\lam\STATUS.md'
    $hdRecord = Join-Path $MissionRoot '.mission-runtime\lam\handoff-admissions.jsonl'
    $hd = [pscustomobject]@{ state = 'inert'; why = ''; head = ''; headShown = ''; ctx = -1; lf = ''; raw = ''; path = ''; resolved = ''; line = ''; statusPath = $hdStatus; statusSha = ''; recordPath = $hdRecord }
    if (-not (Test-Path -LiteralPath $hdStatus -PathType Leaf)) { $hd.why = 'no HANDOFF head -- ' + $hdStatus + ' does not exist'; return $hd }
    $hdBytes = $null
    try { $hdBytes = Read-PlacementBytes -Path $hdStatus }
    catch { $hd.state = 'refused'; $hd.why = $hdStatus + ' could not be read (' + ($_.Exception.Message -replace '[\r\n]+', ' ') + '), so no head is established'; return $hd }
    $hd.statusSha = Get-HaltBytesSha256 -Bytes $hdBytes
    $hdText = ''
    $hdReader = New-Object System.IO.StreamReader -ArgumentList @((New-Object System.IO.MemoryStream -ArgumentList (, $hdBytes)), (New-Object System.Text.UTF8Encoding($false)), $true)
    try { $hdText = $hdReader.ReadToEnd() } finally { $hdReader.Dispose() }
    $hdNl = $hdText.IndexOf("`n")
    $hdHead = if ($hdNl -ge 0) { $hdText.Substring(0, $hdNl) } else { $hdText }
    $hdHead = $hdHead.TrimEnd([char[]]@("`r", ' ', "`t"))
    # The head as the record keeps it (whole), and as the detail prints it (cut at 600 characters, so a
    # first line of any length cannot swell the verdict artifact).
    $hd.head = $hdHead
    $hd.headShown = ConvertTo-ManifestDisplayText -Text $hdHead -Max 600
    if (-not $hdHead) { $hd.why = 'no HANDOFF head -- the first line of ' + $hdStatus + ' is empty'; return $hd }
    if (-not $hdHead.StartsWith('HANDOFF', [System.StringComparison]::Ordinal)) { $hd.why = 'no HANDOFF head -- the first line of ' + $hdStatus + ' does not begin HANDOFF'; return $hd }
    $hd.state = 'refused'
    $hdM = [regex]::Match($hdHead, $script:HandoffHeadPattern)
    if (-not $hdM.Success) { $hd.why = 'the head is not in the form "HANDOFF AT <0-100>% <sha256 LF/blob>; <sha256 working> <path of the brief>"'; return $hd }
    $hd.ctx = [int]$hdM.Groups['ctx'].Value
    $hdHeadLf = $hdM.Groups['lf'].Value.ToLowerInvariant()
    $hdHeadRaw = $hdM.Groups['raw'].Value.ToLowerInvariant()
    $hdPath = $hdM.Groups['path'].Value
    $hd.path = $hdPath
    $hdShown = ConvertTo-ManifestDisplayText -Text $hdPath
    $hdResolved = ''
    try {
        $hdPathOs = $hdPath.Replace('/', '\')
        if ([System.IO.Path]::IsPathRooted($hdPathOs)) { $hdResolved = [System.IO.Path]::GetFullPath($hdPathOs) }
        else { $hdResolved = [System.IO.Path]::GetFullPath((Join-Path $MissionRoot $hdPathOs)) }
    } catch { $hdResolved = '' }
    $hd.resolved = $hdResolved
    $hdResolvedShown = if ($hdResolved) { ConvertTo-ManifestDisplayText -Text $hdResolved } else { 'the path it names' }
    if ((-not $hdResolved) -or (-not (Test-Path -LiteralPath $hdResolved -PathType Leaf))) { $hd.why = 'no file at ' + $hdResolvedShown + ' (the head names ' + $hdShown + ')'; return $hd }
    # The admissions record itself, under any of its names, is never a brief.
    $hdSelf = Test-HandoffBriefIsRecord -BriefPath $hdResolved -RecordPath $hdRecord
    if ($hdSelf.same) {
        $hd.why = 'the head names the admissions record itself as the brief (' + $hdResolvedShown + ': ' + $hdSelf.how + '); the record is this arm''s own account of the briefs already spent, every admission rewrites it, and it is never a brief (register row 360 member (1))'
        return $hd
    }
    # (Where the record could not be held, the question stays open: the readings below go on, so that a
    # record nobody can READ still refuses in its own words, and the head is refused at the end otherwise.)
    # THE GOAL'S OWN VERDICT ARTIFACT IS NEVER A BRIEF EITHER, under any of its names. Every
    # evaluation rewrites it -- this one will -- so its bytes after a stop are never the bytes the head
    # named, the record never holds its digest, and a seat that rewrote the head's two digests to the
    # artifact's new bytes after each stop was admitted at every stop with no brief written: the record's loop
    # through another file. The same two tests, by name and by identity (the artifact held with no sharing
    # for the length of one open, as the record is); what cannot be established refuses, at the end, as for
    # the record. It is the artifact BESIDE THE GOAL FILE that is asked about, the one this run writes.
    # WHAT IT DOES NOT REACH: every OTHER file a run rewrites. Once that was another
    # goal's artifact, an instrument capture this evaluation tees, and a copy -- each a brief like any
    # other, admitted once per distinct bytes. NOW THE FIRST TWO ARE REFUSED BY THEIR NAMES (the
    # block under this one); a copy is still a brief, and so is any other file a run rewrites.
    $hdArtifact = [pscustomobject]@{ same = $false; undetermined = $false; how = '' }
    if ($VerdictPath) {
        $hdArtifact = Test-HandoffBriefIsRecord -BriefPath $hdResolved -RecordPath $VerdictPath -Noun 'verdict artifact' -LongNoun 'verdict artifact'
        if ($hdArtifact.same) {
            $hd.why = 'the head names the goal''s own verdict artifact as the brief (' + $hdResolvedShown + ': ' + $hdArtifact.how + '); the artifact is this evaluator''s own verdict, every evaluation rewrites it, and it is never a brief (register row 377)'
            return $hd
        }
    }
    # THE BATCH-5 CHARTER'S WP-N (e): TWO PATH CLASSES THAT ARE NEVER A
    # BRIEF. The two rules above each refused ONE file whose bytes move at every stop, and left the loop open
    # through the others a run rewrites: a head naming ANOTHER goal's verdict artifact, or the live capture
    # an evaluation tees, with that file's own digests, was admitted and recorded -- and admitted again once
    # the next evaluation had rewritten the file and the seat the head. THE RULE, BY NAME, after the goal's
    # own artifact has had its own answer (so that one keeps its own sentence) and BEFORE the brief or the
    # record is read:
    #   (1) a file whose name ends `.verdict.yaml` and whose directory is <MissionRoot>\.mission\goals,
    #       <MissionRoot>\.mission-runtime\lam\goals, or the directory of the goal file this run evaluates
    #       (the parent of -VerdictPath: under -GoalFile the artifact is written beside that file);
    #   (2) any file under <MissionRoot>\.mission-runtime\lam\instrument-runs\ -- the separator is part of
    #       the name, so a sibling directory whose name only begins `instrument-runs` is not it.
    # ONE SPELLING ON BOTH SIDES OF BOTH TESTS, TAKEN IN TWO PASSES: ConvertTo-HaltScanPath (the full path, a
    # leading \\?\ taken off, no trailing separator), and then THE SAME FUNCTION ONCE MORE over its own
    # answer (the builder-side review's finding). The second pass does what the first cannot: behind a
    # \\?\ prefix the full-path call normalises nothing, so with the prefix off a name could still stand in
    # an 8.3 (short) spelling -- which the second pass, the prefix gone, gives its long form -- or end on a
    # stream suffix (`::$DATA`), which has no full form at all: on that the second pass THROWS, out of this
    # function, and the arm's own backstop then REFUSES the head ("the arm threw ..., so nothing about the
    # head is established") -- a refusal in the arm's sentence, never an admission. That throw reaches past
    # the two classes, on the deny side: ANY brief named by \\?\ and a stream suffix is refused there, as
    # the same spelling without the prefix always was (it has no full form and names no file). Every
    # comparison is ordinal, case folded. So an upper-case, an extended-length, a dot-segment, a
    # forward-slash or a short spelling of the path does not walk past the rule.
    # The refusal has the shape of the two above it: state `refused`, one sentence, the record neither read
    # nor appended. Where a file is of both classes it is refused as the first.
    # WHAT IT GIVES UP, AND DOES NOT CLAIM: the rule reads a NAME, the whole of it, and never a file's
    # identity (rows 360 and 377 do; this has no such half). Each of these is still a brief like any other,
    # and the row stays open for them: a path under a \\.\ (device) spelling, a UNC spelling of the same disk
    # or a \\?\UNC\ one -- the three directories are not written that way, and neither pass turns one into
    # the other; a SECOND NAME of such a file -- a hard link under another directory, a path through a
    # junction or another link; a COPY of it; a file of that name in a directory that is none of the three;
    # and any other file a run rewrites.
    # AND ONE THING THE FIRST SENTENCE SAYS LOOSELY: under -GoalFile the goal's own artifact stands beside
    # that file, so a head naming <MissionRoot>\.mission\goals\<this goal>.verdict.yaml -- THIS goal's
    # canonical-path artifact, which is not the one this run writes -- is refused here in the words
    # "another goal's verdict artifact".
    $hdOic = [System.StringComparison]::OrdinalIgnoreCase
    $hdName = ConvertTo-HaltScanPath -Path (ConvertTo-HaltScanPath -Path $hdResolved)
    $hdRootName = ConvertTo-HaltScanPath -Path (ConvertTo-HaltScanPath -Path $MissionRoot)
    $hdNameCut = $hdName.LastIndexOf('\')
    $hdNameDir = if ($hdNameCut -ge 0) { $hdName.Substring(0, $hdNameCut) } else { '' }
    if ($hdName.EndsWith('.verdict.yaml', $hdOic)) {
        $hdGoalDirs = @(($hdRootName + '\.mission\goals'), ($hdRootName + '\.mission-runtime\lam\goals'))
        if ($VerdictPath) {
            $hdOwnName = ConvertTo-HaltScanPath -Path (ConvertTo-HaltScanPath -Path $VerdictPath)
            $hdOwnCut = $hdOwnName.LastIndexOf('\')
            if ($hdOwnCut -ge 0) { $hdGoalDirs += $hdOwnName.Substring(0, $hdOwnCut) }
        }
        foreach ($hdGoalDir in $hdGoalDirs) {
            if ([string]::Equals($hdNameDir, [string]$hdGoalDir, $hdOic)) {
                $hd.why = 'the head names another goal''s verdict artifact as the brief (' + $hdResolvedShown + '): a file a goal''s evaluation rewrites is never a brief (register row 399)'
                return $hd
            }
        }
    }
    if ($hdName.StartsWith(($hdRootName + '\.mission-runtime\lam\instrument-runs\'), $hdOic)) {
        $hd.why = 'the head names a file under instrument-runs as the brief (' + $hdResolvedShown + '): a capture a run rewrites is never a brief (register row 399)'
        return $hd
    }
    $hdBrief = $null
    try { $hdBrief = Read-PlacementBytes -Path $hdResolved }
    catch { $hd.why = 'the brief at ' + $hdResolvedShown + ' could not be read (' + ($_.Exception.Message -replace '[\r\n]+', ' ') + ')'; return $hd }
    $hd.lf = Get-PlacementLfBlobSha256 -Bytes $hdBrief
    $hd.raw = Get-HaltBytesSha256 -Bytes $hdBrief
    if (-not (($hdHeadLf -ceq $hd.lf) -or ($hdHeadRaw -ceq $hd.raw))) {
        $hd.why = 'the brief at ' + $hdResolvedShown + ' hashes to LF/blob ' + $hd.lf + ', working copy ' + $hd.raw + ', and the head reads ' + $hdHeadLf + '; ' + $hdHeadRaw + ': neither digest matches its basis'
        return $hd
    }
    # THE RECORD: a brief whose LF/blob OR working-copy sha256 it already holds is refused. Each line is read
    # as JSON and its two brief digests compared; a line that does not parse still refuses whatever digest
    # it spells, and a record that cannot be read refuses every head -- a prior admission cannot be ruled out.
    if (Test-Path -LiteralPath $hdRecord) {
        $hdRecText = $null
        try {
            if (-not (Test-Path -LiteralPath $hdRecord -PathType Leaf)) { throw 'it is not a file' }
            $hdRecBytes = Read-PlacementBytes -Path $hdRecord
            $hdRecText = (New-Object System.Text.UTF8Encoding($false)).GetString($hdRecBytes)
        } catch {
            $hd.why = 'the admissions record ' + $hdRecord + ' could not be read, so a prior admission of this brief cannot be ruled out (' + (([string]$_.Exception.Message) -replace '[\r\n]+', ' ') + ')'
            return $hd
        }
        $hdFound = Find-HandoffRecordedLine -Text $hdRecText -Lf $hd.lf -Raw $hd.raw
        if ($hdFound.hit) {
            $hd.why = 'already admitted: the brief''s sha256 ' + $hdFound.hit + ' is recorded in ' + $hdRecord + ' (line ' + $hdFound.line + '); a brief admits ONE stop, and the successor''s first stop is not admitted by it'
            return $hd
        }
    }
    if ($hdSelf.undetermined) {
        $hd.why = 'whether the brief at ' + $hdResolvedShown + ' is the admissions record itself could not be established (' + $hdSelf.how + '), and the record is never a brief (register row 360 member (1))'
        return $hd
    }
    if ($hdArtifact.undetermined) {
        $hd.why = 'whether the brief at ' + $hdResolvedShown + ' is the goal''s own verdict artifact could not be established (' + $hdArtifact.how + '), and the artifact is never a brief (register row 377)'
        return $hd
    }
    $hd.state = 'eligible'
    $hd.line = $script:HandoffAdmittedPrefix + ' ' + $hd.ctx + '% ' + $hd.lf + '; ' + $hd.raw + ' ' + $hdShown
    return $hd
}

function Add-HandoffAdmission {
    # APPEND ONE LINE to the admissions record for an ELIGIBLE decision, UNDER ONE EXCLUSIVE HANDLE: the
    # record's directory made when it is absent; the file opened (or created) for read and write with NO
    # sharing; the record RE-READ through that handle and the brief looked for again, so two hooks at one
    # mission root cannot both admit one brief between a reading and a write -- the second either cannot
    # open the record or finds the first's line; a missing final line ending supplied first, so the new
    # line never joins the last. Returns ok, line (the new line's number, as Find-HandoffRecordedLine
    # counts lines) and why. Every failure is returned as ok = $false: an admission that is not recorded is
    # not made.
    param([Parameter(Mandatory = $true)]$Decision, [Parameter(Mandatory = $true)][string]$Goal, [Parameter(Mandatory = $true)][string]$MissionRoot)
    $haOut = [pscustomobject]@{ ok = $false; line = 0; why = '' }
    $haStream = $null
    try {
        $haDir = Split-Path -Parent $Decision.recordPath
        if (-not (Test-Path -LiteralPath $haDir -PathType Container)) { New-Item -ItemType Directory -Path $haDir -Force -ErrorAction Stop | Out-Null }
        $haStream = New-Object System.IO.FileStream($Decision.recordPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $haPriorMem = New-Object System.IO.MemoryStream
        try { $haStream.CopyTo($haPriorMem); $haPriorBytes = $haPriorMem.ToArray() } finally { $haPriorMem.Dispose() }
        $haAgain = Find-HandoffRecordedLine -Text ((New-Object System.Text.UTF8Encoding($false)).GetString($haPriorBytes)) -Lf ([string]$Decision.lf) -Raw ([string]$Decision.raw)
        if ($haAgain.hit) {
            $haOut.why = 'the record took this brief between the arm''s reading and its write: sha256 ' + $haAgain.hit + ' at line ' + $haAgain.line
            return $haOut
        }
        $haLead = if (($haPriorBytes.Length -gt 0) -and ($haPriorBytes[$haPriorBytes.Length - 1] -ne 10)) { "`n" } else { '' }
        $haPriorLines = 0
        foreach ($haByte in $haPriorBytes) { if ($haByte -eq 10) { $haPriorLines++ } }
        if ($haLead) { $haPriorLines++ }
        $haRec = [ordered]@{
            event = 'handoff_admitted'
            admitted_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
            goal = $Goal
            mission_root = $MissionRoot
            ctx_percent = [int]$Decision.ctx
            head = [string]$Decision.head
            brief_path = [string]$Decision.path
            brief_resolved = [string]$Decision.resolved
            brief_lf_sha256 = [string]$Decision.lf
            brief_working_sha256 = [string]$Decision.raw
            status_path = [string]$Decision.statusPath
            status_sha256 = [string]$Decision.statusSha
            rule = 'register row 353: a brief admits ONE stop; a brief whose sha256 this record holds is refused'
        }
        $haJson = ($haRec | ConvertTo-Json -Compress)
        $haBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($haLead + $haJson + "`n")
        [void]$haStream.Seek(0, [System.IO.SeekOrigin]::End)
        $haStream.Write($haBytes, 0, $haBytes.Length)
        $haStream.Flush()
        $haOut.ok = $true
        $haOut.line = $haPriorLines + 1
    } catch { $haOut.why = (([string]$_.Exception.Message) -replace '[\r\n]+', ' ') }
    finally { if ($null -ne $haStream) { $haStream.Dispose() } }
    return $haOut
}

# EXIT 2 IS CLAUDE CODE'S BLOCKING SIGNAL FOR A STOP HOOK, so these two error paths were doing the
# exact opposite of what they announce: they emit `decision: approve` -- "not blocking" -- and then
# exit with the code that blocks. The decision JSON is honoured on exit 0; on exit 2 the exit code
# wins and the session is held. Found by V-1 round 2 (WP-3), which noted that both cases are ones
# this script's own docstring says must NOT block.
#
# THE CLI PATH IS UNCHANGED AND STILL EXITS 2. A human running this by hand wants a non-zero code
# for "I could not evaluate anything", and 2 is that code everywhere else in this toolchain. Only
# the hook path moves, because only the hook path has a caller that reads 2 as a command.
#
# THE BATCH-5 CHARTER, AND TWO RULINGS OF THE OPERATOR (one of 2026-10-11):
# A MISSION ROOT THAT IS NO DIRECTORY BLOCKS.
# OF THE "TWO ERROR PATHS" THE NOTE ABOVE SPEAKS OF, THIS ONE NO LONGER APPROVES. Once the hook
# answered a -MissionRoot that named no directory with `approve` -- "mission root not found ... not
# blocking" -- and exit 0: a hook whose root was misspelt, moved or deleted read no goal, wrote no verdict
# and admitted EVERY stop of the session, an approve with nothing written (an earlier review recorded
# it as a case the absent goal's rule did not reach). THE RULING: it BLOCKS, in the absent goal's form --
#   AS A STOP HOOK  the reason on stderr, one line behind `goal-check: `, and beside it
#                   `{"decision":"block","reason":...}` ALONE on stdout and EXIT 0, the same string both
#                   times. If that JSON cannot be composed, EXIT 2, the harness's own blocking code.
#   BY HAND         what it was, byte for byte: the one line and exit 2.
# THE EMPTY ROOT IS ONE OF THEM (the operator's ruling): -MissionRoot admits '' (the param block says why), and
# emptiness is asked FIRST, because Test-Path refuses an empty -LiteralPath by throwing -- which would land
# in the trap under another sentence. By hand '' takes the same branch: the line, with nothing after its
# colon, and exit 2, where PowerShell's binder used to end it with exit 1.
# TWO ROOTS THIS BLOCK DOES NOT ANSWER, each as it was: one that holds a character illegal in a path makes
# Test-Path itself throw, and ends in the trap, which refuses the stop under its own sentence;
# and one that is ONLY BLANKS passes the test and is then taken for `<the current directory>\<the
# blanks>`, a path at which nothing stands -- it is NEVER evaluated as the current directory: no goal is
# found under it, no mission plane is there to record that, and the absent goal's branch refuses the stop
# under the absent goal's sentence (as a hook: block; by hand: exit 2). Measured so by the builder-side review.
# THE WORKER GUARD IS ABOVE THIS BLOCK, at the head of the file, and no test of the root stands above it:
# a dispatched worker is approved whatever its root, the empty one included.
# WHAT IT GIVES UP, said plainly: a hook registered with a root that is no directory now refuses EVERY
# stop of that session until the registration is corrected -- no verdict artifact can say so, because
# there is no mission plane to write one into; the reason on both streams is the whole of the record.
# WHAT IT DOES NOT CURE, stated: A -MissionRoot ARGUMENT THAT IS NOT THERE AT ALL. Launched -NonInteractive,
# or with nothing to read on stdin, the mandatory parameter fails to bind -- PowerShell's exit 1, no
# decision -- and no line of this file runs. Launched as a Stop hook is launched, WITHOUT -NonInteractive
# and with the Stop payload on stdin, PowerShell PROMPTS for the parameter and the prompt reads STDIN: the
# payload itself becomes the mission root (and is echoed to stdout by the prompt). That root is no
# directory, so this block answers it too -- the block printed AFTER the echoed payload, on a stdout that
# is then not one JSON object.
if ((-not $MissionRoot) -or (-not (Test-Path -LiteralPath $MissionRoot -PathType Container))) {
    if ($AsStopHook) {
        $rootSaid = if (-not $MissionRoot) { 'the mission root is the empty string' }
                    else { "the mission root '" + (ConvertTo-ManifestDisplayText -Text ([string]$MissionRoot) -Max 600) + "' is not a directory" }
        # ONE LINE, AND THE SAME STRING ON BOTH STREAMS: folded once, here, and written twice from this.
        $rootReason = ("Goal '$Goal' is NOT_MET: $rootSaid, so no goal can be read and no verdict written (register row 401). Correct the hook's -MissionRoot; nothing was evaluated.") -replace '[\r\n]+', ' '
        try { [Console]::Error.WriteLine('goal-check: ' + $rootReason) } catch { }
        $rootJson = ''
        try { $rootJson = (@{ decision = 'block'; reason = $rootReason } | ConvertTo-Json -Compress) } catch { $rootJson = '' }
        if ($rootJson) { Write-Output $rootJson; exit 0 }
        exit 2
    }
    Write-Output "mission-goal-check: mission root not found: $MissionRoot"
    exit 2
}
$MissionRoot = (Resolve-Path -LiteralPath $MissionRoot).Path

# --- locate the goal ---------------------------------------------------------------------------
$searched = @()
$goalPath = $null
foreach ($cand in @(
        (Join-Path $MissionRoot ".mission\goals\$Goal.yaml"),
        (Join-Path $MissionRoot ".mission-runtime\lam\goals\$Goal.yaml"))) {
    $searched += $cand
    if ((-not $goalPath) -and (Test-Path -LiteralPath $cand)) { $goalPath = $cand }
}
if ($GoalFile) {
    $searched += $GoalFile
    if (Test-Path -LiteralPath $GoalFile) { $goalPath = $GoalFile }
}
if (-not $goalPath) {
    # =============================================================================================
    # RULED BY THE OPERATOR ON 2026-09-30 (lean A): AN ABSENT GOAL IS AN ADMITTED STOP,
    # AND A RECORDED ONE.
    # =============================================================================================
    # THE FINDING: "a Stop hook that names a goal whose file is at neither search location --
    # not yet placed, misspelled, moved or deleted -- governs nothing, and says so only in the hook's
    # reason." THE RULING: the absent goal STAYS an admitted stop -- S0's pre-goal window depends on it
    # -- but never silently: a verdict GOAL_ABSENT naming the goal id and every path searched,
    # printed as the stop's reason line. A goal file that EXISTS and cannot be read is the other case, and
    # it refuses the stop (below, before the detector loop).
    #
    # WHERE THE VERDICT GOES. There is no goal to write it beside, so it goes where C-1's canonical path
    # would put it: <MissionRoot>\.mission\goals\<Goal>.verdict.yaml, which .gitignore already excludes
    # (`/.mission/goals/*.verdict.yaml`), the goals directory made when .mission exists without it. It is
    # NOT written -- and the reason says so, and why -- when the goal id is not one token
    # [A-Za-z0-9][A-Za-z0-9._-]* (a name is never composed from an id that could leave the directory), when
    # <MissionRoot>\.mission is not a directory (this is no mission plane to write into), or when the
    # write fails. Until the refusal below the stop was admitted in every one of those cases as well; SINCE
    # IT, AN ABSENT GOAL IS ADMITTED ONLY WHERE ITS VERDICT WAS WRITTEN, and each of the three BLOCKS (the
    # block under the write, below). No HALT scan runs: with no goal, nothing here governs the stop.
    # BY HAND the exit is still 2, "I could not evaluate anything", as it was.
    $absentLine = "GOAL_ABSENT: no goal file for '$Goal'. Looked in: $($searched -join ' ; ') -- an ADMITTED STOP (register row 341; the operator's ruling of 2026-09-30, lean A): no detector governs this stop, and it is recorded, never silent."
    $absentVerdictPath = ''
    $absentNotWritten = ''
    $absentPlane = Join-Path $MissionRoot '.mission'
    if (-not [regex]::IsMatch([string]$Goal, '\A[A-Za-z0-9][A-Za-z0-9._-]*\z')) {
        $absentNotWritten = "the goal id '$Goal' is not one token [A-Za-z0-9][A-Za-z0-9._-]*, so no file is named for it"
    } elseif (-not (Test-Path -LiteralPath $absentPlane -PathType Container)) {
        $absentNotWritten = "$absentPlane is not a directory, so there is no mission plane to write it into"
    } else {
        $absentGoalsDir = Join-Path $absentPlane 'goals'
        $absentTry = Join-Path $absentGoalsDir "$Goal.verdict.yaml"
        try {
            if (-not (Test-Path -LiteralPath $absentGoalsDir -PathType Container)) { New-Item -ItemType Directory -Path $absentGoalsDir -ErrorAction Stop | Out-Null }
            $absentSb = New-Object System.Text.StringBuilder
            [void]$absentSb.AppendLine("# Written by tools/lam/mission-goal-check.ps1. NO GOAL FILE WAS FOUND, SO NO DETECTOR RAN.")
            [void]$absentSb.AppendLine("# An absent goal is an admitted stop that is recorded, never a silent one (register row 341).")
            [void]$absentSb.AppendLine("goal: $Goal")
            [void]$absentSb.AppendLine("goal_file: none -- absent at every location searched")
            [void]$absentSb.AppendLine("mission_root: $MissionRoot")
            [void]$absentSb.AppendLine("evaluated_at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture))")
            [void]$absentSb.AppendLine("verdict: GOAL_ABSENT")
            [void]$absentSb.AppendLine("detector_count: 0")
            [void]$absentSb.AppendLine("failing_count: 0")
            [void]$absentSb.AppendLine("short_circuited: 0   # detectors NOT evaluated (hook mode); never counted as passing")
            # WHO WROTE THIS VERDICT (the BATCH-7 charter's item (c)): hook as the Stop hook, hand by hand, from the switch.
            [void]$absentSb.AppendLine("hook_or_hand: $(if ($AsStopHook) { 'hook' } else { 'hand' })")
            [void]$absentSb.AppendLine("goal_searched:")
            foreach ($absentPath in $searched) { [void]$absentSb.AppendLine("  - '$((([string]$absentPath) -replace "`r?`n", ' ') -replace "'", "''")'") }
            [void]$absentSb.AppendLine("reason: '$((($absentLine) -replace "`r?`n", ' ') -replace "'", "''")'")
            [void]$absentSb.AppendLine("halt_scan_roots: []   # no HALT scan runs on an absent goal (register row 363)")
            [void]$absentSb.AppendLine("halt_scan_excluded: []")
            [void]$absentSb.AppendLine("detectors: []")
            [System.IO.File]::WriteAllText($absentTry, $absentSb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
            $absentVerdictPath = $absentTry
        } catch {
            $absentNotWritten = "writing $absentTry failed ($(($_.Exception.Message -replace '[\r\n]+', ' ')))"
        }
    }
    $absentTail = if ($absentVerdictPath) { " Verdict: $absentVerdictPath." } else { " No verdict file was written: $absentNotWritten." }
    # =============================================================================================
    # (the BATCH-4 charter; the operator's rulings
    # B3 and B4 of 2026-10-06): AN ABSENT GOAL WHOSE VERDICT CANNOT BE WRITTEN IS NOT AN ADMITTED STOP.
    # =============================================================================================
    # The 2026-09-30 ruling admits the absent goal as a RECORDED stop, and where the record could not be written this
    # block approved all the same: "an approve with no written verdict", the one route an earlier rule's sentence
    # -- "no route ends in approve without a written verdict" -- had left through this branch. THE RULING:
    # it BLOCKS, in all three cases the block above names -- an id that is not one token, no .mission
    # directory, a write that throws. Where the verdict IS written nothing here is entered and the stop is
    # admitted exactly as it was, byte for byte.
    #   AS A STOP HOOK  the reason on stderr, one line, and beside it the decision in the form NOT_MET blocks
    #                   in (C-2): `{"decision":"block","reason":...}` on stdout and EXIT 0. If that JSON cannot
    #                   be composed, EXIT 2, the harness's own blocking code: the stop is refused either way.
    #   BY HAND         exit 2, as an absent goal always was; the status line reads NOT_MET, the word the hook
    #                   blocks on -- there is no artifact to carry any other.
    # (The "No verdict file was written" half of $absentTail above, and of the hand-run's verdict line at the
    # foot of this branch, is no longer reached: this block answers that case first. Both are left as they
    # stood, so the admitted path below is byte for byte what it was.)
    # WHAT IT GIVES UP, said plainly: a Stop hook registered where there is no mission plane at all -- a
    # mission root with no .mission directory -- now refuses EVERY stop of that session until the plane or
    # the goal exists. That is a misconfigured hook failing closed; the reason names the cause.
    # WHAT IT DOES NOT REACH, so that "no route" is not read wider than this branch: a -MissionRoot that is
    # no directory at all is answered by the block ABOVE the goal search, and a dispatched worker by the
    # guard at the head of the file. Neither is this block's. The worker
    # still approves with nothing written, a stated exception; THE ROOT THAT IS NO DIRECTORY NO LONGER
    # DOES -- its own block now refuses the stop, in this block's form.
    if (-not $absentVerdictPath) {
        $absentRefusal = "GOAL_ABSENT, AND ITS VERDICT COULD NOT BE WRITTEN -- no goal file for '$Goal'. Looked in: $($searched -join ' ; ') -- an absent goal is an admitted stop only as a RECORDED one (register row 341), and this one is not recorded: the stop is REFUSED (register row 376: an absent goal is not approved without a written verdict). No verdict file was written: $absentNotWritten."
        if ($AsStopHook) {
            $absentReason = "Goal '$Goal' is NOT_MET: $absentRefusal Place the goal file, or clear what keeps its verdict from being written, and stop again: this decision is derived from the evaluator's own inability to record the stop, not from the transcript."
            try { [Console]::Error.WriteLine('goal-check: ' + (($absentReason) -replace '[\r\n]+', ' ')) } catch { }
            $absentJson = ''
            try { $absentJson = (@{ decision = 'block'; reason = $absentReason } | ConvertTo-Json -Compress) } catch { $absentJson = '' }
            if ($absentJson) { Write-Output $absentJson; exit 0 }
            exit 2
        }
        Write-Output "mission-goal-check: $Goal -> NOT_MET"
        Write-Output "  $absentRefusal"
        Write-Output "  verdict   : none -- $absentNotWritten"
        exit 2
    }
    # THE HOOK STILL EXITS 0 WITH `approve` (exit 2 is the harness's blocking code, the note above).
    if ($AsStopHook) {
        Write-Output (@{ decision = 'approve'; reason = "goal-check: $absentLine$absentTail Not blocking." } | ConvertTo-Json -Compress)
        exit 0
    }
    Write-Output "mission-goal-check: $Goal -> GOAL_ABSENT"
    Write-Output "  $absentLine"
    Write-Output "  verdict   : $(if ($absentVerdictPath) { $absentVerdictPath } else { 'none -- ' + $absentNotWritten })"
    exit 2
}

# --- a very small YAML reader for the detector list ---------------------------------------------
# REACH, STATED: `detectors:` followed by `- type: <t>` items whose subsequent indented
# `key: value` lines belong to that item. Nothing else. A shape it cannot read becomes a detector
# with no type, which REFUSES below rather than being skipped.
#
# -LineLog (the BATCH-4 charter). The reader keeps
# no line number in what it RETURNS, and a refusal that cannot name the goal line is half a refusal. Given a
# list, it adds one record per key it stored -- item (the detector's index in the returned array), key (as
# the goal file spells it) and line (its number in the file, counted from 1) -- in the order the keys were
# read, so the LAST record of an item's key is the line whose value the item holds. Without -LineLog nothing
# is logged and the function is what it was: what it RETURNS is the same either way, item for item and
# key for key, and nothing is added to an item (the three admitted-stop arms print every key they do not
# read). It is still ONE function that calls nothing outside itself.
function Read-GoalDetectors {
    param([string]$Path, [System.Collections.IList]$LineLog = $null)
    $items = New-Object System.Collections.Generic.List[object]
    $cur = $null
    $inDetectors = $false
    $lineNo = 0
    foreach ($raw in [System.IO.File]::ReadAllLines($Path)) {
        $lineNo++
        $line = $raw -replace "`t", '    '
        if ($line -match '^\s*#') { continue }
        if ($line -match '^detectors:\s*$') { $inDetectors = $true; continue }
        if (-not $inDetectors) { continue }
        if ($line -match '^\S') { $inDetectors = $false; continue }
        if ($line -match '^\s*-\s*([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            if ($null -ne $cur) { [void]$items.Add($cur) }
            $cur = @{}
            $cur[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
            if ($null -ne $LineLog) { [void]$LineLog.Add([pscustomobject]@{ item = $items.Count; key = $Matches[1]; line = $lineNo }) }
            continue
        }
        if ($line -match '^\s+([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            if ($null -ne $cur) {
                $cur[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
                if ($null -ne $LineLog) { [void]$LineLog.Add([pscustomobject]@{ item = $items.Count; key = $Matches[1]; line = $lineNo }) }
            }
            continue
        }
    }
    if ($null -ne $cur) { [void]$items.Add($cur) }
    return $items.ToArray()
}

# --- THE 2026-09-30 RULING's OTHER HALF: A GOAL FILE THAT EXISTS AND DOES NOT PARSE REFUSES THE STOP ---
# (the operator's ruling: "a goal file that EXISTS but does not parse or declares no
# detectors REFUSES the stop (blocked; the parse error printed)".) UNTIL IT, a goal file the reader could
# not read -- held open by another process, or a DIRECTORY at the goal's path, which the search above
# finds -- threw out of Read-GoalDetectors to this file's trap, and the trap APPROVES: the stop was
# admitted on a goal nobody had read, with no verdict artifact. And a goal file declaring no detectors
# read NOT_MET with nothing named as failing. Both now REFUSE the stop and say why: a `goal_parse` entry
# that FAILS carries the parse error into the verdict artifact, the hand-run and the hook's reason, and
# the verdict is NOT_MET -- unless a HALT is open, which still outranks everything (C-3). (ONE PARSE ERROR
# IS NOT OUTRANKED, since the operator's HALT-scope ruling: a key that does not touch its colon, where it is
# a HALT-scope key of a halt_absent item -- the block under this one says why.)
# WHAT "DOES NOT PARSE" IS, for a reader this small: the file's bytes cannot be read; the reader throws;
# or it yields no detector at all -- no column-0 `detectors:` line, or one with no `- <key>:` item under
# it. A line the reader skips inside the list is not a parse error -- WITH ONE EXCEPTION,
# the key-shaped line of the block under this one -- and an item with no type refuses as
# an UNKNOWN detector, as before. THERE IS A FOURTH: the goal declares, under a type
# that reads it as one, a number that is not a whole number in its range (the block under the reader).
# AND A FIFTH: inside the list, a key that does not touch its colon (Get-GoalGrammarFaults).
# Read-GoalDetectors must stay self-contained: WP-2's R-E and WP-3's C-1ah row (m) each lift it from this
# file by its AST and run it alone. (This half left it unchanged. It has since gained -LineLog, which
# those two never pass; what it returns did not move. The colon rule did not touch it: that rule is a function of
# its own, beside the reader.)
#
# =================================================================================================
# THE CHARTER, WP-N (c) (the operator's rulings of
# 2026-10-11): INSIDE THE detectors: LIST A KEY TOUCHES ITS COLON, OR THE GOAL DOES NOT PARSE.
# =================================================================================================
# WHAT IT WAS. The reader stores a key only where the key touches its colon -- its two patterns, the item
# opener's and the key's under it, ask for `<key>:`. `count : 4` is a line it SKIPS: the key is then
# absent and the type's DEFAULT is read, in silence, and for the keys that exist the default is weaker
# than what was declared. `reuse_within_minutes : 30` read no window; `count : 4` asked for ONE result and
# passed on one; an opener written `- type : <t>` opened no item and handed the keys under it to the item
# BEFORE it; and a halt_absent's `legacy_answered_allowlist : <HALT>@<sha256>` answered nothing -- the HALT
# read OPEN, the verdict was HALT, and the Stop hook APPROVED. The number rule recorded this as a residual.
# RULE 1. In the reader's own list scope -- a tab is four spaces, a `#` line is skipped, a column-0
# `detectors:` line opens the list and a column-0 non-blank line closes it -- a line the reader does NOT
# store (it matches neither of its two patterns) and that reads `<key> :`, a key, blanks and then a colon,
# with or without the item's dash ahead of it, is a FAULT, and the goal does not parse: NOT_MET, ONE
# failing goal_parse entry naming the line's number, the line as written and the key, and NO detector run.
# It is by SHAPE, so it holds for every key a type reads and for any key added later. It is asked right
# after the reader returns and AHEAD of the no-detector test, so a goal whose only opener is `- type : x`
# names its line instead of reading "it declares no detectors".
# THE OLD RULE STANDS FOR EVERY OTHER SHAPE: a free-text line, a hyphenated key, a bare list item, a
# quoted key inside the list is skipped and is no parse error, exactly as before.
# THE HALT SCOPE IS THE SCOPE AS READ, AND ONE FAULT OUTRANKS THE HALT LABEL (the operator's ruling). A goal that
# does not parse runs no detector, and its halt_absent `dir`s and legacy_answered_allowlist are still
# read from the items as the reader returned them ($detectorsAsRead, below): $detectors is emptied only
# AFTER that copy is taken, so a HALT in a directory the goal declares is still seen, and on any fault an
# open HALT still reads HALT -- the refusal on the artifact beside it. THE ONE EXCEPTION: where the fault
# is ON a HALT-scope key -- the key is `dir` or `legacy_answered_allowlist` -- OF A halt_absent ITEM, the
# scope as read is NOT the scope the goal wrote, a HALT label derived from it is not to be trusted, and
# the verdict is NOT_MET with the HALT open: the hook blocks. WHICH ITEM THAT IS, exactly -- TWO
# CONDITIONS, AND EITHER ONE IS ENOUGH:
#   (1) THE ITEM AS THE GOAL WROTE IT IS A halt_absent. Asked of every faulted line, the item's own
#     opener (`  - dir : x`) and a key line (`    dir : x`) alike. AN ITEM AS WRITTEN runs from an opener
#     line -- one the reader stores, or one that is itself mis-spaced and so opens nothing for the reader
#     -- to the next opener of either kind, or to the list's end. IT IS A halt_absent ITEM where ANY
#     `type` line in it -- its opener or a key line under it, stored (`type: halt_absent`) or itself
#     mis-spaced (`type : halt_absent`) -- has a value that reads halt_absent.
#   (2) FOR A FAULTED KEY LINE ONLY: THE ITEM AS THE READER READ IT IS A halt_absent -- the last opener
#     the reader took above the line, and the type the reader returned for that item. A faulted OPENER is
#     judged by (1) alone: the reader takes no opener from it, and an opener with no `type` line under it
#     does not fire by falling into a halt_absent item above it (the builder-side review's finding:
#     one goal read HALT as its first item and NOT_MET behind another).
# WHY BOTH. (2) was the whole test for a key line until the independent validator's round 1 (a finding),
# and it failed open wherever the item's `type` line was mis-spaced too: the reader then takes no
# halt_absent from the item, its HALT-scope line falls in no item, in the unrelated item above, or in an
# item with no type, and the goal read HALT and the hook approved -- the fault standing on a HALT-scope
# key of an item the goal wrote as halt_absent. (1) closes that. AND (2) IS KEPT, UNCHANGED IN WHAT IT
# CATCHES, because (1) alone lets go of one shape (2) holds: a mis-spaced HALT-scope key line that stands,
# as written, under a mis-spaced opener of its own -- in an item with no `type` line -- and falls, AS READ,
# in a halt_absent item above it (`- type: halt_absent` / `- path : x` / `dir : y`). That goal was
# refused before the finding was cured, and the cure of a finding opens no stop that was refused: an
# exemption on the allow side fails open. So against the rule as it stood NOTHING moves from NOT_MET to
# HALT; every goal that moves, moves the other way.
# WHAT IT DOES NOT REACH, ALLOW-SIDE, each recorded and not built: a MISSPELLED or
# unknown key is still stored and read by nobody (`cuont: 4` reads the default 1); a key-shaped line at
# COLUMN 0 still ends the list, every detector after it dropped in silence -- the rule's scope is inside
# the list and never sees it; and an opener of another skipped shape (`- "type": x`) still hands its keys
# to the item before it.
# AND THE HALT-SCOPE RULING's OTHER HALF, recorded and not built (the ruling speaks of a fault ON `dir` or
# `legacy_answered_allowlist`): WHERE THE FAULT IS ON THE KEY `type` of a halt_absent item whose HALT-scope
# key touches its colon -- the opener `- type : halt_absent` with `legacy_answered_allowlist: <e>` (or
# `dir: <d>`) under it, or `type : halt_absent` under a well-spelled `- legacy_answered_allowlist: <e>` --
# the fault is named and the goal does not parse, but it is not a fault on a HALT-scope key: the item is
# no halt_absent item to the reader, its allowlist answers nothing and its dir is not scanned, the HALT
# reads OPEN and the hook APPROVES. (Where a HALT-scope key of that item is mis-spaced AS WELL, condition
# (1) above reaches it: the fault is then on `dir` or the allowlist, inside an item written as halt_absent.)
function Get-GoalGrammarFaults {
    # RULE 1's FINDER, AND NOTHING ELSE. It reads the goal file's lines under Read-GoalDetectors' own scope
    # and its two patterns, restated here so that the reader stays the one function others lift alone, and
    # returns faults: one record for each line inside the list that the reader does not store and that
    # reads `<key> :` -- line (its number in the file, from 1), key (as written), raw (the line as the file
    # holds it), item (the index, in what the reader returns, of the last opener the READER took above the
    # line; -1 where there is none), opener ($true where the faulted line is in dash form: it opens an item
    # of its own as written, and the reader takes no opener from it) and haltAsWritten: $true where THE
    # ITEM AS WRITTEN that the line stands in is a halt_absent.
    # THE ITEM AS WRITTEN is opened by every opener line, one the reader stores and one that is itself
    # mis-spaced alike, and runs to the next of either kind or to the list's end; a line ahead of the
    # list's first opener stands in none. IT IS A halt_absent where ANY `type` line in it -- the opener or
    # a key line, stored or mis-spaced, ABOVE the faulted line or BELOW it -- has a value that reads
    # halt_absent as the reader would read one: trimmed, quote marks trimmed, case folded. So the answer
    # for a fault is known only once its item has ended, and it is written into the records after the
    # last line is read. `item` says where the line falls AS READ and no more: what type the reader gave
    # that item is the step's to read, off the items the reader returned.
    # It calls nothing outside itself; the sentence a fault is printed in, and what a fault on a HALT-scope
    # key does, are the step's below.
    param([Parameter(Mandatory = $true)][string]$Path)
    $ggFaults = New-Object System.Collections.Generic.List[object]
    $ggInList = $false
    $ggLineNo = 0
    $ggItem = -1
    # The item as written that the line being read stands in ($null ahead of the first opener), and beside
    # each fault the item it was found in: `halt` may still turn true on a `type` line further down.
    $ggWritten = $null
    $ggWrittenOf = New-Object System.Collections.Generic.List[object]
    foreach ($ggRaw in [System.IO.File]::ReadAllLines($Path)) {
        $ggLineNo++
        $ggLine = $ggRaw -replace "`t", '    '
        if ($ggLine -match '^\s*#') { continue }
        if ($ggLine -match '^detectors:\s*$') { $ggInList = $true; continue }
        if (-not $ggInList) { continue }
        if ($ggLine -match '^\S') { $ggInList = $false; $ggWritten = $null; continue }
        if ($ggLine -match '^\s*-\s*([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            # AN OPENER THE READER STORES: the next item as read, and a new item as written; and where its own
            # key is `type`, a `type` line.
            $ggWritten = [pscustomobject]@{ halt = (([string]$Matches[1] -eq 'type') -and (([string]$Matches[2]).Trim().Trim('"').Trim("'") -eq 'halt_absent')) }
            $ggItem++
            continue
        }
        if ($ggLine -match '^\s+([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            # A KEY LINE THE READER STORES: a `type` line of the item as written it stands in.
            if (($null -ne $ggWritten) -and ([string]$Matches[1] -eq 'type') -and (([string]$Matches[2]).Trim().Trim('"').Trim("'") -eq 'halt_absent')) { $ggWritten.halt = $true }
            continue
        }
        if ($ggLine -match '^\s*(-\s*)?([A-Za-z_][A-Za-z0-9_]*)\s+:\s*(.*)$') {
            # THE FAULT. In dash form it opens an item as written of its own -- and none as read: $ggItem stays
            # where the reader's last opener left it --; in either form it is a `type` line where its key is
            # `type`.
            $ggDash = [bool]$Matches[1]
            $ggKey = [string]$Matches[2]
            $ggValue = ([string]$Matches[3]).Trim().Trim('"').Trim("'")
            if ($ggDash) { $ggWritten = [pscustomobject]@{ halt = $false } }
            if (($null -ne $ggWritten) -and ($ggKey -eq 'type') -and ($ggValue -eq 'halt_absent')) { $ggWritten.halt = $true }
            $ggFaults.Add([pscustomobject]@{ line = $ggLineNo; key = $ggKey; raw = [string]$ggRaw; item = $ggItem; opener = $ggDash; haltAsWritten = $false })
            $ggWrittenOf.Add($ggWritten)
        }
    }
    for ($ggAt = 0; $ggAt -lt $ggFaults.Count; $ggAt++) {
        $ggFaults[$ggAt].haltAsWritten = (($null -ne $ggWrittenOf[$ggAt]) -and [bool]$ggWrittenOf[$ggAt].halt)
    }
    return [pscustomobject]@{ faults = @($ggFaults.ToArray()) }
}
# =================================================================================================
# BATCH-6 WP-Q (d) (ruled 2026-10-16 07:2x local, lean accepted, with
# Q12): A LINE OF A GOAL's DETECTORS LIST THAT IS NO KEY, NO LIST OPENER, NO BLANK AND NO COMMENT IS A GOAL THAT DOES
# NOT PARSE.
# =================================================================================================
# WHAT IT WAS. The old rule (the block above Read-GoalDetectors): a free-text line, a hyphenated key, a bare list
# item, a quoted key inside the list were skipped in silence and were no parse error -- so `engine-read: x` read no
# engine, `"count": 4` asked for the default, and a quoted opener `- "type": x` handed its keys to the item before it
# (D1 (ii)'s third shape). THE RULE: in Read-GoalDetectors' own list scope, a line that is not blank (nothing but
# blanks), not an opener the reader stores, not a key line it stores, not rule 1's fault (named there, first), and not
# an item of a BLOCK LIST under a key whose value is empty -- an indented `- <value>` line at that key's indent or
# deeper, and each such line after it (such items are list openers for this rule, so the operator's earlier ruling stands: a block list
# under instrument_inputs_except or patterns still FAILS ITS DETECTOR by name, not the goal) -- is a FAULT. Asked
# after rule 1 and only where no earlier parse error stands; the goal does not parse, one goal_parse entry naming the
# first three such lines as written and counting the rest, no detector run. The HALT ladder is what it is for every
# parse error but D15's: a fault of this rule never outranks the HALT label.
# WHAT IT DOES NOT REACH: a misspelled key (`cuont: 4` is a key the reader stores); a key-shaped line at column 0
# (it ends the list, as the reader reads it). Read-GoalDetectors is not edited: WP-2's R-E and WP-3's C-1ah row (m),
# C-1al (k) and C-1as (d) lift it alone.
function Get-GoalLineFaults {
    # THE FINDER OF THE BLOCK ABOVE, AND NOTHING ELSE. It reads the goal file's lines under Read-GoalDetectors' own scope and its two
    # patterns, and rule 1's, restated here so that it can be lifted and run alone; returns faults: one record for each
    # line inside the list that the rule refuses -- line (its number in the file, from 1) and raw (the line as the file
    # holds it). It calls nothing outside itself; the sentence a fault is printed in is the step's below.
    param([Parameter(Mandatory = $true)][string]$Path)
    $glFaults = New-Object System.Collections.Generic.List[object]
    $glInList = $false
    $glLineNo = 0
    # The indent of the key whose value is empty that a block list may stand under; -1 where none does.
    $glBlockAt = -1
    foreach ($glRaw in [System.IO.File]::ReadAllLines($Path)) {
        $glLineNo++
        $glLine = $glRaw -replace "`t", '    '
        if ($glLine -match '^\s*#') { continue }
        if ($glLine -match '^detectors:\s*$') { $glInList = $true; $glBlockAt = -1; continue }
        if (-not $glInList) { continue }
        if ($glLine -match '^\S') { $glInList = $false; $glBlockAt = -1; continue }
        if ($glLine.Trim().Length -eq 0) { continue }
        $glIndent = $glLine.Length - $glLine.TrimStart().Length
        if ($glLine -match '^\s*-\s*([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') { $glBlockAt = $(if (([string]$Matches[2]).Trim().Length -eq 0) { $glIndent } else { -1 }); continue }
        if ($glLine -match '^\s+([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') { $glBlockAt = $(if (([string]$Matches[2]).Trim().Length -eq 0) { $glIndent } else { -1 }); continue }
        if ($glLine -match '^\s*(-\s*)?([A-Za-z_][A-Za-z0-9_]*)\s+:\s*(.*)$') { $glBlockAt = -1; continue }
        if (($glBlockAt -ge 0) -and ($glIndent -ge $glBlockAt) -and ($glLine -match '^\s*-(\s|$)')) { continue }
        $glBlockAt = -1
        $glFaults.Add([pscustomobject]@{ line = $glLineNo; raw = [string]$glRaw })
    }
    return [pscustomobject]@{ faults = @($glFaults.ToArray()) }
}
$goalParseError = ''
$detectors = @()
$goalLineLog = New-Object System.Collections.Generic.List[object]
try { $null = [System.IO.File]::ReadAllBytes($goalPath) }
catch { $goalParseError = 'it could not be read (' + (([string]$_.Exception.Message) -replace '[\r\n]+', ' ') + ')' }
if (-not $goalParseError) {
    try { $detectors = @(Read-GoalDetectors -Path $goalPath -LineLog $goalLineLog) }
    catch { $goalParseError = 'the detector reader threw (' + (([string]$_.Exception.Message) -replace '[\r\n]+', ' ') + ')' }
}
# RULE 1, ASKED HERE: after the reader returned and AHEAD of the no-detector test. A fault sets the
# parse error and NOTHING ELSE at this point -- $detectors is emptied under the number step, after the
# items as read have been kept for the HALT scope. The line is printed as this file prints every
# seat-chosen text (ConvertTo-ManifestDisplayText), at most 160 characters of it, here and not in the
# function; the first three faults are named and the rest counted. A finder that throws has established
# nothing about the goal's grammar, and that refuses too.
$goalGrammarFaults = @()
if (-not $goalParseError) {
    try { $goalGrammarFaults = @((Get-GoalGrammarFaults -Path $goalPath).faults) }
    catch { $goalGrammarFaults = @(); $goalParseError = 'its key grammar could not be read (' + (([string]$_.Exception.Message) -replace '[\r\n]+', ' ') + ')' }
    if ($goalGrammarFaults.Count -gt 0) {
        $goalGrammarSaid = @($goalGrammarFaults | ForEach-Object {
            'line ' + [string]$_.line + ': `' + (ConvertTo-ManifestDisplayText -Text ([string]$_.raw) -Max 160) + '` -- the key ' + [string]$_.key + ' does not touch its colon (register row 397)'
        })
        $goalParseError = 'a key it declares does not touch its colon -- ' + (@($goalGrammarSaid | Select-Object -First 3) -join '; ') +
                          $(if ($goalGrammarSaid.Count -gt 3) { '; and ' + [string]($goalGrammarSaid.Count - 3) + ' more' } else { '' }) +
                          ' -- the reader stores a key only where the key touches its colon, and a line it would skip is never read as the type''s default'
    }
}
# THE NO-KEY LINE RULE (Get-GoalLineFaults), ASKED HERE: after rule 1, and only where no earlier parse error stands, so a goal names one cause. The lines
# are printed as rule 1 prints its own; a finder that throws has established nothing about the goal's lines, and
# that refuses too.
if (-not $goalParseError) {
    $goalLineFaults = @()
    try { $goalLineFaults = @((Get-GoalLineFaults -Path $goalPath).faults) }
    catch { $goalLineFaults = @(); $goalParseError = 'its lines could not be read for register row 424 (' + (([string]$_.Exception.Message) -replace '[\r\n]+', ' ') + ')' }
    if ($goalLineFaults.Count -gt 0) {
        $goalLineSaid = @($goalLineFaults | ForEach-Object { 'line ' + [string]$_.line + ': `' + (ConvertTo-ManifestDisplayText -Text ([string]$_.raw) -Max 160) + '`' })
        $goalParseError = 'a line inside its detectors list is no key, no list opener, no blank and no comment -- ' + (@($goalLineSaid | Select-Object -First 3) -join '; ') +
                          $(if ($goalLineSaid.Count -gt 3) { '; and ' + [string]($goalLineSaid.Count - 3) + ' more' } else { '' }) +
                          ' -- the reader skips such a line in silence, and nothing it holds is ever read (register row 424)'
    }
}
if ((-not $goalParseError) -and ($detectors.Count -eq 0)) {
    $goalHasDetectorsLine = $false
    try {
        foreach ($goalLine in [System.IO.File]::ReadAllLines($goalPath)) {
            if (($goalLine -replace "`t", '    ') -match '^detectors:\s*$') { $goalHasDetectorsLine = $true; break }
        }
    } catch { $goalHasDetectorsLine = $false }
    $goalParseError = if ($goalHasDetectorsLine) { "it declares no detectors (a column-0 detectors: line with no '- <key>:' item under it)" }
                      else { 'it declares no detectors (no column-0 detectors: line)' }
}

# =================================================================================================
# THE BATCH-4 CHARTER (the operator's rulings B1
# and B2 of 2026-10-06): A NUMBER IN A GOAL FILE IS A WHOLE NUMBER IN ITS RANGE, OR THE GOAL DOES NOT PARSE.
# =================================================================================================
# WHAT IT WAS. The reader keeps everything after a key's colon, a trailing comment included, and each of
# the four keys this file reads as a number met that text in its own way. reuse_within_minutes written
# `30  # thirty` was read as 0: the instrument ran at every stop, and the only word of it stood in the
# detail of an entry that passed. validator_pass_count's count went to TryParse with the answer thrown
# away, so `4  # four` asked for no result at all and the detector passed -- the allow-side one. turn_cap's
# cap and time_cap's minutes failed their detector in a sentence that named neither the value nor the cause.
#
# THE RULE. For the four keys, at every site that reads one: the value, whole, is 1 to 6 digits and not
# below the key's floor -- reuse_within_minutes 0 to 999999 (0 is "never reuse"); count, cap and minutes
# 1 to 999999 -- or THE GOAL FILE DOES NOT PARSE and the stop is REFUSED by the 2026-09-30 ruling's other half, the route
# just above: one failing goal_parse entry naming the key, its line in the goal file and the value as
# written, and NO detector run, the instrument included. No comment is stripped and no number is guessed:
# `30  # x` is refused, `30` is thirty, and so is `"30"`, which the reader has always unquoted. (The
# reader's unquoting is what it was -- it trims quote marks from either end, so `30"` is thirty too -- and
# so is its key grammar: a key that does not touch its colon, `count : 4`, is a line it skips. Neither is
# this rule's, and both were recorded as its residuals. THE SECOND IS CLOSED NOW: the
# reader still skips that line, but the goal then DOES NOT PARSE (the block above, under the reader), so
# the key is no longer absent with the type's default read. The unquoting is a residual still.) A number
# is tested only under the type that reads it; the same key under another type is not this rule's.
# THE HALT SCOPE IS KEPT: the goal's halt_absent `dir`s and legacy_answered_allowlist are read from the
# goal as written, so the C-3 scan is what it is for a goal that parses and a HALT still outranks the
# refusal -- an open one, and not one the goal answers.
#
# A FIFTH KEY SINCE BATCH-6 WP-Q (a) (ruled 2026-10-16 07:2x local, lean accepted):
# reuse_tree_within_minutes, under instrument_exit0, 0 to 999999 -- one row more in the table below, and every
# word of this block holds of it as of the four.
#
# ONE DEFINITION, EVERY READER. ConvertTo-GoalWholeNumber is the rule, and each place that reads one of the
# four keys reads it through that function, so no two can answer differently: the step below, before any
# detector runs; Get-InstrumentReuseDecision; the test that decides whether the verdict carries the reuse
# keys; and the validator_pass_count, turn_cap and time_cap arms. The arms and the reuse decision keep a
# refusal of their own for a caller that reaches them some other way; from a goal file none is reached.
#
# WHAT IT DOES NOT REACH: a key that is not a number. A trailing comment on `path:`, `dir:`, `session:` or
# any other text key is still part of the value, as it was (the finding: "The same reader rule holds for
# every key of every detector"); the charter cures the numbers.
function ConvertTo-GoalWholeNumber {
    # ok and value: -Text, trimmed, is 1 to 6 digits -- so never above 999999 -- and not below -Min.
    param([AllowNull()][AllowEmptyString()][string]$Text, [int]$Min = 0)
    $gnOut = [pscustomobject]@{ ok = $false; value = 0 }
    $gnText = ([string]$Text).Trim()
    if (-not [regex]::IsMatch($gnText, '\A[0-9]{1,6}\z')) { return $gnOut }
    $gnValue = [int]$gnText
    if ($gnValue -lt $Min) { return $gnOut }
    $gnOut.ok = $true
    $gnOut.value = $gnValue
    return $gnOut
}
function Get-GoalNumericFaults {
    # EVERY NUMBER THE DETECTORS DECLARE, TESTED ONCE. -Detectors is Read-GoalDetectors' array and -LineLog
    # the list it filled. Returns tested (how many numbers were read) and faults: one record for each that
    # is not a number in its range -- line, key, value (as the item holds it), min (the key's floor) and
    # type (the detector type that reads it). The line is the LAST one that set the key in its item, which
    # is the value the item holds. It reads nothing but its two arguments and calls nothing but
    # ConvertTo-GoalWholeNumber; the sentence each fault is printed in is composed by the step below.
    param([AllowNull()][object[]]$Detectors, [AllowNull()][System.Collections.IList]$LineLog)
    $gfKeys = @(
        [pscustomobject]@{ type = 'instrument_exit0'; key = 'reuse_within_minutes'; min = 0 },
        [pscustomobject]@{ type = 'instrument_exit0'; key = 'reuse_tree_within_minutes'; min = 0 },
        [pscustomobject]@{ type = 'validator_pass_count'; key = 'count'; min = 1 },
        [pscustomobject]@{ type = 'turn_cap'; key = 'cap'; min = 1 },
        [pscustomobject]@{ type = 'time_cap'; key = 'minutes'; min = 1 })
    $gfOut = [pscustomobject]@{ tested = 0; faults = @() }
    $gfFaults = New-Object System.Collections.Generic.List[object]
    $gfList = @($Detectors)
    for ($gfI = 0; $gfI -lt $gfList.Count; $gfI++) {
        $gfD = $gfList[$gfI]
        if ($null -eq $gfD) { continue }
        foreach ($gfK in $gfKeys) {
            if (([string]$gfD['type']) -ne $gfK.type) { continue }
            if (-not $gfD.ContainsKey($gfK.key)) { continue }
            $gfOut.tested++
            $gfRaw = [string]$gfD[$gfK.key]
            if ((ConvertTo-GoalWholeNumber -Text $gfRaw -Min $gfK.min).ok) { continue }
            $gfLine = 0
            foreach ($gfL in @($LineLog)) {
                if (($null -ne $gfL) -and ([int]$gfL.item -eq $gfI) -and ([string]$gfL.key -eq $gfK.key)) { $gfLine = [int]$gfL.line }
            }
            $gfFaults.Add([pscustomobject]@{ line = $gfLine; key = $gfK.key; value = $gfRaw; min = $gfK.min; type = $gfK.type })
        }
    }
    $gfOut.faults = @($gfFaults.ToArray())
    return $gfOut
}
# THE DETECTORS AS READ, KEPT FOR THE HALT SCOPE ALONE (the builder-side review's finding). A goal that
# declares a number that is not one runs NO detector -- but its halt_absent detectors still say WHERE halts
# live (`dir`) and WHICH legacy halts the goal answers (legacy_answered_allowlist), and the C-3 scan must
# read both from the goal as written. Without them every HALT the goal answers by its allowlist read OPEN,
# the verdict was HALT, and the hook APPROVED a stop this rule exists to refuse; and an open HALT in a
# declared dir was not seen at all. For a goal that could not be read there is nothing to keep, as before.
$detectorsAsRead = @($detectors)
if (-not $goalParseError) {
    $goalNumeric = Get-GoalNumericFaults -Detectors $detectors -LineLog $goalLineLog
    # The value is printed as this file prints every seat-chosen text (ConvertTo-ManifestDisplayText), here
    # and not in the function, which must stay liftable on its own.
    $goalNumericFaults = @(@($goalNumeric.faults) | ForEach-Object {
        'line ' + [string]$_.line + ': ' + [string]$_.key + ": '" + (ConvertTo-ManifestDisplayText -Text ([string]$_.value) -Max 60) + "' is not a whole number from " + [string]$_.min + ' to 999999 (' + [string]$_.type + ' reads it as a number)'
    })
    if ($goalNumericFaults.Count -gt 0) {
        $goalParseError = 'a number it declares is not one -- ' + (@($goalNumericFaults | Select-Object -First 3) -join '; ') +
                          $(if ($goalNumericFaults.Count -gt 3) { '; and ' + [string]($goalNumericFaults.Count - 3) + ' more' } else { '' }) +
                          ' -- the value is everything after the colon, a trailing comment included, and nothing is read in its place (register row 385)'
        # A goal that does not parse has no detector to evaluate: none runs, the instrument included.
        $detectors = @()
    }
}
# THE COLON RULE: ... AND SO FOR EVERY GOAL THAT DOES NOT PARSE, EMPTIED HERE -- under the line that kept the items
# as read, never above it. For the three older classes $detectors is already empty when this is reached, and
# for a number that is not one the step above has just emptied it; what this line adds is the goal RULE 1
# faulted, whose items the reader DID return: kept above for the HALT scope, they must not be evaluated.
if ($goalParseError) { $detectors = @() }
# THE HALT-SCOPE RULING: DOES A RULE-1 FAULT STAND ON A HALT-SCOPE KEY OF A halt_absent ITEM? The key is `dir` or
# legacy_answered_allowlist (compared as the items' own tables compare a key: case folded), and the item
# is a halt_absent under EITHER of two conditions (the block above the finder states both, and why the
# second is kept beside the first):
#   (1) THE ITEM AS THE GOAL WROTE IT is a halt_absent -- the finder's haltAsWritten, asked of every faulted
#     line, the item's own opener and a key line alike (the independent validator's round 1, a finding).
#   (2) THE LINE IS A KEY LINE, and the item it falls in AS READ -- the last opener the reader took above
#     it -- has the type halt_absent as the reader returned it. The test as it stood before that finding,
#     unchanged in what it catches. A faulted OPENER is not asked it: what the reader made of the lines
#     under a skipped opener -- nothing, or keys of the item above -- is not that opener's item.
# Where it does, the verdict below is NOT_MET even with a HALT open: a mis-spaced `dir` leaves a declared
# directory unscanned and a mis-spaced allowlist leaves every HALT it answers reading OPEN, so the HALT
# label would be derived from a scope the goal did not write. A fault on any other key -- the key `type`
# of a halt_absent item among them, ALONE, the ruling's other half -- leaves the ladder as it was.
$goalGrammarHaltScope = $false
foreach ($goalGrammarFault in $goalGrammarFaults) {
    if (@('dir', 'legacy_answered_allowlist') -notcontains ([string]$goalGrammarFault.key)) { continue }
    if ($goalGrammarFault.haltAsWritten) { $goalGrammarHaltScope = $true; continue }
    if ($goalGrammarFault.opener) { continue }
    $goalGrammarAt = [int]$goalGrammarFault.item
    if (($goalGrammarAt -ge 0) -and ($goalGrammarAt -lt $detectorsAsRead.Count) -and (([string]$detectorsAsRead[$goalGrammarAt]['type']) -eq 'halt_absent')) { $goalGrammarHaltScope = $true }
}

# =================================================================================================
# THE BATCH-4 CHARTER (the operator's ruling B10 of
# 2026-10-06): validator_pass_count MAY NAME ITS ROSTER BY A LIST OF PATTERNS.
# =================================================================================================
# THE COST IT ANSWERS. The detector finds its files with ONE -Filter pattern, and a filter has `*` and `?`
# and no character class: a roster spanning A-598..A-601 took two detectors (validator-A-5??,
# validator-A-6??), each with its own count, and a .gitignore line per pattern.
# THE KEY. `patterns: [<pattern>, <pattern>, ...]` -- an INLINE list on the key's own line, each item a
# -Filter pattern exactly as `pattern:` takes one. The detector reads the UNION: every pattern is asked in
# the order written, a file two patterns match is read ONCE (by its full path, case folded), and `count` is
# over the union. `pattern:` keeps its meaning and its default, and a detector that carries no `patterns`
# is read exactly as it was. The inline form is one scalar to the reader, so Read-GoalDetectors is not
# changed for it; ConvertFrom-GoalInlineList is the whole of the list's grammar.
# WHAT REFUSES, each as a FAILED entry of this detector with its reason, and NEVER a fall back to the
# default pattern, which would read a roster nobody declared: `pattern` and `patterns` both declared; and a
# `patterns` that is not `[` ... `]` holding at least one item, none of them empty -- a trailing comment
# after the `]` included, and a block list under the key, which the reader reads as an empty value.
# AND, SINCE RULE 2: a `patterns` ITEM that holds a bracket or a path
# separator -- any one of [ ] / \ -- because an item is ONE file-name pattern of the roster's own directory
# (the arm says what each did before). The single `pattern:` key is not reached by that rule.
# WHAT IT GIVES UP: a pattern that itself holds a comma cannot be listed, and the union's count does not say
# how many each pattern must give -- 4 over two patterns is met by 3 and 1.
function ConvertFrom-GoalInlineList {
    # ok, items and why for the value of a key written `[a, b, c]`: the text, trimmed, opens `[` and closes
    # `]`; what is between is split at commas; each item is trimmed, and one quoted on BOTH sides in one
    # kind of quote is unquoted; an item quoted on one side only is refused (the comma inside a quoted
    # item is not read as part of it); no item may be empty.
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $ilOut = [pscustomobject]@{ ok = $false; items = @(); why = '' }
    $ilText = ([string]$Text).Trim()
    if (-not $ilText) { $ilOut.why = 'its value is empty (an inline list `[a, b]` on the key''s own line is the form; a block list under the key is not read)'; return $ilOut }
    if ((-not $ilText.StartsWith('[')) -or (-not $ilText.EndsWith(']')) -or ($ilText.Length -lt 2)) {
        $ilOut.why = 'its value does not open with [ and close with ] (everything after the colon is the value, a trailing comment included)'
        return $ilOut
    }
    $ilInner = $ilText.Substring(1, $ilText.Length - 2)
    if (-not $ilInner.Trim()) { $ilOut.why = 'it is an empty list'; return $ilOut }
    $ilItems = New-Object System.Collections.Generic.List[string]
    foreach ($ilPart in @($ilInner -split ',')) {
        $ilRaw = ([string]$ilPart).Trim()
        # A QUOTED ITEM IS QUOTED ON BOTH SIDES, in one kind of quote. An item quoted on one side only is what
        # a quoted item holding a comma splits into: it is refused, never read as two patterns.
        $ilFirst = if ($ilRaw.Length -gt 0) { $ilRaw.Substring(0, 1) } else { '' }
        $ilLast = if ($ilRaw.Length -gt 0) { $ilRaw.Substring($ilRaw.Length - 1, 1) } else { '' }
        $ilOpens = (($ilFirst -ceq '"') -or ($ilFirst -ceq "'"))
        $ilCloses = (($ilLast -ceq '"') -or ($ilLast -ceq "'"))
        if (($ilOpens -or $ilCloses) -and (($ilRaw.Length -lt 2) -or ($ilFirst -cne $ilLast))) {
            $ilOut.why = 'an item is quoted on one side only (a quoted item cannot hold a comma)'
            return $ilOut
        }
        $ilItem = if ($ilOpens) { $ilRaw.Substring(1, $ilRaw.Length - 2).Trim() } else { $ilRaw }
        if (-not $ilItem) { $ilOut.why = 'it holds an empty item'; return $ilOut }
        $ilItems.Add($ilItem)
    }
    $ilOut.items = @($ilItems.ToArray())
    $ilOut.ok = $true
    return $ilOut
}

# --- detector implementations -------------------------------------------------------------------
# Each returns @{ ok = <bool>; detail = <string> }. Every one of them reads DISK.

# --- THE DETECTOR HALF: A RED RUN LEAVES ITS REASON ON DISK -------------------------------
# `instrument_exit0` ran the instrument as `$null = & powershell ... 2>&1` and threw away everything
# it said, keeping only $LASTEXITCODE. So the entire record of a failing suite was one sentence --
# "<leaf> exited 1 (require 0)" -- and the instrument's TALLY line, its failing member names and
# every diagnostic it printed existed NOWHERE afterwards. Reproduced 2026-09-11 against this
# evaluator: a goal whose instrument printed
#   FAILED src/x/test_a.py::test_one
#   TALLY passed=11 failed=1 skipped=2 deselected=0 runnable=14 stored_floor=14 collection_error=False pytest_exit=1 elapsed_seconds=7
# and exited 1 produced a verdict artifact carrying `detail: 'red-instrument.ps1 exited 1 (require
# 0)'` and nothing else, and a full recursive scan of the mission root found that TALLY text in no
# file but the instrument's own source. The exit code survived; the reason did not.
#
# =================================================================================================
# THE PRIVATE CAPTURE IS GONE. THE SHARED HELPER OWNS THE CAPTURE NOW.
# =================================================================================================
# Save-InstrumentCapture used to live here and wrote its sidecar into (Split-Path -Parent
# $goalPath) -- i.e. .mission/goals/, BESIDE the verdict artifact. THAT WAS THE DEFECT, and it is
# the one this block records. .gitignore:79 ignores `/.mission/goals/*.verdict.yaml` and NOTHING
# ELSE in that directory, so `<goal>.instrument.txt` was an UNTRACKED, PORCELAIN-VISIBLE file
# written on EVERY Stop hook. Measured at the base of this item in the repository of record's
# worktree: a clean tree (0 porcelain lines) gained exactly one line,
#   ?? .mission/goals/<goal>.instrument.txt
# and Assert-CleanWorkingTree (tools/mission-lib.ps1:90) as it stands
# admits NOTHING that the mission has not DECLARED in .mission/mission.yaml `admitted_porcelain`.
# This mission declares exactly two prefixes -- "?? .mission/evidence/verify-" and
# "?? .mission/gates/" -- so that line is $offending and A-126 REFUSES. Every lifecycle command
# (reopen, promote-contract, ledger-append, close, reclose) would have refused, after any Stop hook
# had run the goal once. The capture cured one hole by opening a worse one.
#
# THE CURE IS THE ONE SHARED DEFINITION, tools/lam/lam-instrument-run.ps1 (
# landed in an earlier revision), dot-sourced at the head of this file and called below. It runs the
# instrument, persists its stdout and its tally under
# <MissionRoot>/.mission-runtime/lam/instrument-runs/ -- the plane .gitignore:3 excludes WHOLE --
# and hands back the exit code. Nothing is written under .mission/goals/ but the verdict artifact.
#
# WHAT THE PRIVATE FUNCTION GUARANTEED, AND WHERE EACH GUARANTEE WENT. Stated in full because a
# finding that is merely deleted is a finding that gets re-learned.
#   CAPTURE ON EVERY OUTCOME, not only on red. HONOURED, unconditionally: the helper's persistence
#     block (its `(b) AGAIN` try block in lam-instrument-run.ps1) is not guarded
#     by the exit code, so a green run writes its transcript too. Let go.
#   THE TALLY SURFACED IN BOTH DIRECTIONS. HONOURED, in a SECOND FILE rather than as a key: the
#     helper writes `<base>.tally.txt` carrying the TALLY line verbatim when one was printed, and
#     the explicit sentinel `NO-TALLY exit_code=<n>` when none was. Absence is still STATED. Let go.
#   KEYED, BECAUSE ONE GOAL MAY DECLARE MORE THAN ONE instrument_exit0. HONOURED BY THE CALLER, not
#     by the helper: the helper keys on RunKey/Goal + the instrument's leaf name, which separates
#     two detectors over DIFFERENT instruments but NOT two over the SAME one. The ordinal counter
#     below therefore survives the move and is folded into the RunKey, which is exactly what that
#     parameter is for. MEASURED at the base of this item: with `-Goal` alone, two detectors naming
#     one instrument write one file and the second overwrites the first; with the RunKey below they
#     do not. Driven by WP-3 member C-1j's TWO row.
#   NEVER AN EMPTY FILE. HONOURED BY THE HELPER (contract
#     (h) 3). It WAS NOT HONOURED at first: the helper wrote $flat verbatim; a silent instrument
#     left a ZERO-BYTE `<base>.stdout.txt` where the private function wrote a sentence saying so,
#     and this walk recorded that as a finding against the helper. Now the stdout header's
#     `body_bytes:` counts the instrument's own output; when it is 0 the body is one of the helper's
#     own sentences ("THE INSTRUMENT PRINTED NOTHING ..."). Read `body_bytes: 0`, not the sentence.
#   THE EXIT CODE ON THE CAPTURE'S FACE. HONOURED BY THE HELPER
#     (contract (h) 4, with (h) 2's header). It WAS NOT HONOURED at first: the private file
#     carried `exit_code: <n>` on every capture, the helper's files only in the NO-TALLY sentinel,
#     and this walk recorded that as a finding against the helper too. Now every stdout header
#     carries `exit_code: <n>`, and every tally file ENDS with an `EXIT exit_code=<n> ...` line.
#     C-1j's exit-code rows still read the verdict artifact and the tally file; none was dropped.
#   THIS FUNCTION MAY THROW; ITS CALLER WRAPS IT. SUPERSEDED BY A STRONGER RULE: the helper's
#     contract (b) is that it MUST NOT THROW -- persistence is a side effect and an unwritable
#     directory degrades to `persisted = false`, never to a verdict. The caller below still wraps
#     the one thing it does for itself (deriving the capture path for the detail line), for the
#     same reason the old wrapper existed.
#
# THE HELPER'S OWN REASONING FOR ITS LOCATION IS STALE, AND ITS CONCLUSION IS STRENGTHENED, NOT
# WEAKENED. lam-instrument-run.ps1's docblock justifies .mission-runtime/ by citing
# "Assert-CleanWorkingTree (tools/mission-lib.ps1:110-117) exempts only ^\.mission/evidence/ and
# ^\.mission/gates/". That describes an older gate: a later change deleted those
# two code exemptions outright and made the admitted set the mission's own declaration, admitting
# nothing undeclared. The function is now at :90 and there is no code exemption to cite. So the
# premise is wrong and the conclusion is more true than when it was written -- under the old code
# a `.mission/goals/` file was offending, and under the new gate it is offending for a reason no
# mission can quietly widen. lam-instrument-run.ps1 is batch 2's file: REPORTED, NOT EDITED HERE.

# =================================================================================================
# THE BATCH-3 CHARTER: instrument_exit0 MAY REUSE
# A FRESH READING, AND ONLY WHERE THE GOAL FILE SAYS SO.
# =================================================================================================
# THE COST IT ANSWERS. An arc instrument takes minutes, a seat runs it by hand before it stops, and the
# Stop hook then ran it again at the same HEAD over the same tree -- four goal readings inside forty
# minutes at one HEAD is on this file's own record.
#
# THE KEY. An instrument_exit0 detector may carry `reuse_within_minutes: <N>`. ABSENT, OR 0, MEANS NEVER
# REUSE: the detector runs the instrument exactly as it did, and its detail is byte for byte what it
# was, so no existing goal file is affected. A value that is not a whole number from 0 to 999999 was
# read as 0, the detail saying so; SINCE THE NUMBER RULE such a goal file DOES NOT PARSE and the stop is
# refused before any detector runs (the block under Read-GoalDetectors), so no such value arrives here.
#
# WITH N ABOVE 0, a capture of the shared helper is REUSED -- the instrument is not run -- only when
# ALL of these hold, and each is read here, now:
#   HEAD EQUAL -- OR, WHERE THE DETECTOR DECLARES instrument_inputs_except, THE INPUT TREE EQUAL
#                         the capture's own `head:` is the 40-hex `git rev-parse HEAD` reads now. Without
#                         the key that is the whole of the condition, and its words are what they were.
#                         With it (the input-tree block, below) a capture whose head is NOT HEAD still
#                         passes THIS condition where its own `input_tree:` is the figure HEAD has under
#                         the goal's list. The condition is WIDENED, never branched: every condition
#                         under this one still applies to a capture admitted that way
#   THE TREE CLEAN, NOW   apart from the mission's declared set: VERIFY'S OWN PREDICATE, called and not
#                         restated -- Test-LamAdvanceAdmission asked whether HEAD is an admitted advance
#                         from itself (clean apart from admitted_porcelain, or the shared default)
#   AND WHEN IT WAS TAKEN the capture's own `tree_clean: True`, written by the helper from the same
#                         predicate before it launched the instrument -- so a reading taken over an
#                         edit that was later reverted is not a reading of this tree
#   THE INSTRUMENT'S BLOB the capture's `instrument_sha256:` is the sha256 of the instrument file's
#                         bytes now
#   THE SAME INSTRUMENT   the capture's `instrument_resolved:` -- the file the helper LAUNCHED, a full
#                         path -- is this detector's own resolved instrument. A leaf name and equal
#                         bytes are not enough: the runner captures a suite it ran in a WORKER's
#                         worktree under this mission root's instrument-runs, and that is a reading of
#                         another tree
#   A TREE OF ITS OWN     the mission root is itself the top level of a git repository; at a plain
#                         directory inside another repository git answers for the enclosing one, and
#                         nothing is reused there
#   INSIDE THE WINDOW     the capture's own `captured_at:` is not in the future and not more than N
#                         minutes old
#   AND IT IS A WHOLE CAPTURE: the helper's writer line, capture_format 1, `ran: True`, an integer
#                         exit_code, and a body that hashes to its own body_sha256 and is closed by the
#                         closing line at the end of the file.
#   AND IT IS GREEN, AND NO RED FOLLOWS IT (the input-tree block's (ii), below): the capture chosen exited 0,
#                         and no whole capture of this instrument taken after it exited anything else.
# WHERE THE CAPTURE'S OWN HEAD COMES FROM: the helper's stdout header -- since this block, five keys after its
# thirteen: head, tree_clean, tree_reason, instrument_sha256, instrument_resolved (lam-instrument-run.ps1,
# contract (i)); tree_reason is not read here. A capture written before that carries none and is never reused.
# Since the input-tree block a nineteenth, input_tree, where the capture was taken under a list (its contract (j)).
# THE CANDIDATES are every <key>.<instrument leaf>.stdout.txt under
# <MissionRoot>\.mission-runtime\lam\instrument-runs\ -- the evaluator's own capture of an earlier
# evaluation and a hand-run under any run key alike -- the 32 most recently written; the one with the
# latest captured_at that passes is the one CHOSEN, and it is reused only if it is GREEN and no RED follows.
# WHAT THE VERDICT SAYS. The detail names the capture by path and by the sha256 of the file's bytes as
# read, with its captured_at, its age, the HEAD and the instrument's sha256, and says the instrument
# was NOT run; a goal that declares a window above 0 also gets the key instrument_captures_reused.
# ok is still (exit code = 0) -- the capture's exit code, which since rule (ii) below is 0 on every reuse.
# Where nothing passes, or the capture chosen is not reused, the instrument is run as before and the
# detail says why nothing was reused.
# AND THE CAPTURE CITED IS KEPT (Save-InstrumentReusedCapture): before it is named, the capture that passed is copied
# beside itself as <key>.<instrument leaf>.<first eight hex of its sha256>.stdout.txt, from the bytes that
# were hashed; the detail names that copy too, and the key instrument_captures_kept lists it. The live
# file is rewritten by the next fresh run under its run key; the kept copy is never rewritten, and is never
# a candidate (Save-InstrumentReusedCapture). A copy that cannot be made is a reading that is not reused.
#
# WHAT IT GIVES UP, stated because it is the whole of the risk: the captures live in the agent-writable
# runtime plane, so a reused reading is as trustworthy as that plane and no more. A hand-written file in
# the helper's shape, at this HEAD, passes -- and, since the input-tree block, where the detector declares
# instrument_inputs_except, so does one that names any 40-hex head and carries HEAD's own figure, which
# the verdict prints. The key is therefore the operator's to write per detector,
# the default is never, and the verdict names what was reused by sha256 so a reader can refute it. What
# no condition sees: a change to a file git ignores, the clock, the network, another process.
#
# =================================================================================================
# THE BATCH-5 CHARTER, WP-N (a) (the operator's ruling 5
# and his later rulings): THE INPUT TREE A CAPTURE STOOD ON, AND A
# RED THAT IS NEVER REUSED AND NEVER STEPPED OVER.
# =================================================================================================
# (i) THE COST IT ANSWERS. HEAD EQUAL declined every capture across every commit, a ledger line among them:
# the charter counts five fresh runs of the arc instrument in one arc, four of them after ledger-only commits.
# THE KEY. An instrument_exit0 detector may carry `instrument_inputs_except: [p1, p2]` -- an INLINE list on
# the key's own line (ConvertFrom-GoalInlineList), each item a repository-relative path that is NOT an input
# of the instrument. (The charter's inclusion list, `instrument_inputs:`, is not built, by the operator's ruling -- a list
# of what IS an input decays with every entry HEAD gains.) ABSENT, nothing here is entered and the detector
# is what it was. DECLARED: the instrument is launched through the helper's -InstrumentInputsExcept, so its
# capture carries `input_tree:` -- Get-LamInputTree's figure over that head's tree less the list, in the
# helper, one function for both sides -- and the HEAD condition above is widened by it. HEAD's own figure
# is derived ONCE, inside the reuse decision, from the head it has just read, before any capture is.
# WHAT THE FIGURE IS (the helper's function states it whole): the sha256 of the head's tree entries less
# the listed paths, sorted, AND THEN OF THE LIST ITSELF -- one `except<TAB><path>` line for each exclusion.
# THE LIST IS IN IT BECAUSE THE KEPT ENTRIES DO NOT SAY WHICH LIST THEY WERE KEPT UNDER (the builder-side
# review's finding): without it, a capture taken under a WIDER list is admitted under a narrower one
# once a commit removes the path the narrower list did not exclude. So a figure binds its list: a capture
# is admitted by its input tree only where it was taken under THIS detector's list, item for item, and the
# decline for any other says the two figures differ. (A capture AT HEAD ITSELF is still reused whatever
# list it was taken under, or none: head equality is the fast path, and it was always enough.)
# WHAT REFUSES, each as a FAILED entry of this detector, the instrument NOT run and nothing reused (ruling
# D1 (i)): a list the list reader refuses; and an ITEM that is not a repository-relative path this file
# reads -- it holds one of [ ] \ : * ?, begins or ends with /, holds an empty, `.` or `..` segment, or
# repeats an earlier item (Get-GoalInputsExceptFault).
# WHAT DECLINES, in the capture's own words after today's "its head is X, and HEAD is Y": its head is no
# 40-hex commit id; HEAD's figure is not derivable (and why); it carries no input_tree; its input_tree is
# no figure; its figure is not HEAD's -- asked in that order, the first that holds said once.
# WHAT THE VERDICT SAYS. A reuse the figure admitted names the capture's own head and ADMITTED BY ITS INPUT
# TREE in its detail; a goal that declares the key gets two keys more -- instrument_inputs_except (the list
# and the figure at HEAD, one item for each declaring detector that was invoked with a list that reads) and
# instrument_input_tree_matched (one item for each reuse the figure admitted; `[]` when none).
# WHAT IT GIVES UP -- ENDPOINTS, NOT HISTORY (the operator's ruling: no history condition). HEAD equality proved that
# no commit lay between a capture and this evaluation; two equal figures prove only that the two heads
# store the same objects outside the list, under the same list. A change to an input and its revert, both
# committed between them, is reused over. AND THE FIGURE IS BLIND WHERE VERIFY'S PREDICATE IS BLIND -- a
# file under skip-worktree or assume-unchanged, an ignored file, an untracked file under an admitted
# prefix -- which is why "the tree is clean, now and when it was taken" is still asked, of that predicate,
# for every capture. AND A LIST THAT CHANGES COSTS ONE RUN: a capture taken under the list as it was is
# declined under the list as it is, at every head but its own. What narrows the first: rule (ii).
# (ii) A RED IS NEVER REUSED, AND NEVER STEPPED OVER (ruling 5). Until this row the capture with the latest
# captured_at that passed was reused RED OR GREEN: one RED reading was handed back as RED, the instrument
# not run, for as long as the window lasted, and a copy of it kept. THE RULE, applied after the newest
# passing capture is chosen and BEFORE anything is kept: (1) the capture chosen did not exit 0 -- nothing
# is reused, nothing kept, the instrument RUNS; no older capture is fallen back on. (2) some WHOLE capture
# of this detector's instrument (it reads; it names this instrument's own path; `ran: True`; a numeric
# exit_code; a UTC captured_at that is not in the future), taken strictly AFTER the one chosen, did not
# exit 0 -- WHATEVER it was declined for: its head, its input tree, its tree_clean, its instrument_sha256
# -- the same. (2) is over every candidate read, not over the passing ones, because (i) would otherwise
# open the hole it closes: a later RED that carries no input_tree is declined for its head as soon as a
# commit lands, and the older GREEN that carries one would be the only capture left to choose. A RED taken
# BEFORE the capture chosen stops nothing. WHAT IT COSTS: any RED capture of this instrument, under any run
# key, forces one fresh run; that reading is then the newest.
# WHAT (2) DOES NOT READ, stated: "every candidate" is the 32 captures of this instrument most recently
# WRITTEN -- the same 32 the choice is made among. A later RED that is not one of them is not read, and
# does not stop the reuse.
# (iii) (BATCH-6 WP-Q (d)): AN UNDATABLE CAPTURE REFUSES REUSE. (2) reads
# a RED only where its captured_at can be read, so a capture whose date cannot be -- absent, not parsing, not UTC,
# in the future -- was stepped over, RED or GREEN, and the older capture behind it reused. Now a capture of this
# detector's instrument that reads whole and is undatable, among the same 32, refuses the reuse: the instrument
# RUNS, and the note names it. WHAT IT COSTS: one such file -- the runner's capture of the same leaf, a hand run,
# a clock stepped back -- forces a fresh run at every evaluation until it is moved or the clock passes it.
function Read-InstrumentCapture {
    # ONE CAPTURE, read under the helper's own splitting rule (its contract (h) 2): the header is every
    # line before the FIRST line that is exactly the opening delimiter; the body is exactly body_bytes
    # bytes after it, then the closing line, which ends the file. Returns ok, why, keys (first occurrence
    # of each header key), the sha256 and length of the file's bytes as read, and raw: those bytes
    # themselves (the copy kept on reuse is written from the bytes that were hashed,
    # never from a second read of a file the next evaluation may have rewritten).
    param([Parameter(Mandatory = $true)][string]$Path)
    $rc = [pscustomobject]@{ ok = $false; why = ''; keys = @{}; sha256 = ''; bytes = 0; raw = $null }
    $rcBytes = $null
    try { $rcBytes = [System.IO.File]::ReadAllBytes($Path) } catch { $rc.why = 'it could not be read'; return $rc }
    $rc.bytes = $rcBytes.Length
    $rc.sha256 = Get-LamCaptureSha256 -Bytes $rcBytes
    $rc.raw = $rcBytes
    # One byte, one character: offsets in this text are offsets in the file. The keys read are ASCII.
    $rcLatin = [System.Text.Encoding]::GetEncoding(28591)
    $rcHeadLen = [Math]::Min($rcBytes.Length, 65536)
    $rcHeadText = $rcLatin.GetString($rcBytes, 0, $rcHeadLen)
    $rcOpen = "`n--- instrument stdout and stderr, verbatim ---`n"
    $rcAt = $rcHeadText.IndexOf($rcOpen, [System.StringComparison]::Ordinal)
    if ($rcAt -lt 0) { $rc.why = 'it has no opening delimiter line in its first 65536 bytes'; return $rc }
    # The header's bytes are the first $rcAt of the file; they are decoded as the UTF-8 they were written
    # in, so a path among the values reads as it was written.
    $rcHeader = (New-Object System.Text.UTF8Encoding($false)).GetString($rcBytes, 0, $rcAt)
    foreach ($rcLine in @($rcHeader -split "`n")) {
        $rcM = [regex]::Match($rcLine, '\A([a-z_0-9]+): (.*)\z')
        if ($rcM.Success -and (-not $rc.keys.ContainsKey($rcM.Groups[1].Value))) { $rc.keys[$rcM.Groups[1].Value] = $rcM.Groups[2].Value }
    }
    if ([string]$rc.keys['writer'] -cne 'tools/lam/lam-instrument-run.ps1 Save-LamInstrumentRun') { $rc.why = 'its writer line is not the shared helper''s'; return $rc }
    if ([string]$rc.keys['capture_format'] -cne '1') { $rc.why = 'its capture_format is not 1'; return $rc }
    if ([string]$rc.keys['body_bytes'] -cnotmatch '\A[0-9]{1,10}\z') { $rc.why = 'its body_bytes is not a number'; return $rc }
    $rcBodyLen = [long]$rc.keys['body_bytes']
    $rcBodyAt = $rcAt + $rcOpen.Length
    $rcClose = $rcLatin.GetBytes("`n--- end of instrument output ---`n")
    $rcTailAt = $rcBytes.Length - $rcClose.Length
    if ($rcTailAt -lt $rcBodyAt) { $rc.why = 'it is cut short: no closing line ends the file'; return $rc }
    for ($rcI = 0; $rcI -lt $rcClose.Length; $rcI++) {
        if ($rcBytes[$rcTailAt + $rcI] -ne $rcClose[$rcI]) { $rc.why = 'the closing line does not end the file'; return $rc }
    }
    $rcHasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        if ($rcBodyLen -gt 0) {
            if (($rcBodyAt + $rcBodyLen) -ne $rcTailAt) { $rc.why = 'its body is not the body_bytes its header states'; return $rc }
            $rcBodySha = ([BitConverter]::ToString($rcHasher.ComputeHash($rcBytes, [int]$rcBodyAt, [int]$rcBodyLen))).Replace('-', '').ToLowerInvariant()
        } else {
            $rcBodySha = ([BitConverter]::ToString($rcHasher.ComputeHash([byte[]]@()))).Replace('-', '').ToLowerInvariant()
        }
    } finally { $rcHasher.Dispose() }
    if ([string]$rc.keys['body_sha256'] -cne $rcBodySha) { $rc.why = 'its body does not hash to its own body_sha256'; return $rc }
    $rc.ok = $true
    return $rc
}

function Test-InstrumentSamePath {
    # Is the file a capture says it ran (-A, its instrument_resolved) this detector's instrument (-B, a full
    # path)? Full paths compared ordinally, case folded. -A that has no full form is not the same file.
    param([string]$A, [string]$B)
    try { return [string]::Equals([System.IO.Path]::GetFullPath($A), [System.IO.Path]::GetFullPath($B), [System.StringComparison]::OrdinalIgnoreCase) }
    catch { return $false }
}

function Get-GoalInputsExceptFault {
    # THE OPERATOR'S RULING: IS EVERY ITEM OF AN instrument_inputs_except LIST A REPOSITORY-RELATIVE
    # PATH THIS FILE READS? -Items is what ConvertFrom-GoalInlineList handed over (each trimmed and unquoted;
    # none empty -- an empty item is that reader's refusal). Returns $null where every item is one, else the
    # FIRST that is not: item (as handed over) and reason. An item is refused when it holds one of
    # [ ] \ : * ? (a path is written as git writes it: forward slashes, no drive, no pattern); begins with /
    # (it is relative to the repository's root); ends with / (a directory is named without one); holds an
    # empty, `.` or `..` segment; or repeats an earlier item, compared as git compares paths: ordinally.
    # It reads nothing but its argument. What it does NOT ask is whether the head holds the path: that is
    # Get-LamInputTree's, asked of a head, and its answer is "not derivable", never a refusal.
    param([AllowNull()][string[]]$Items)
    $ieSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($ieItem in @($Items)) {
        $ieText = [string]$ieItem
        $ieWhy = ''
        if ($ieText.IndexOfAny([char[]]@('[', ']', '\', ':', '*', '?')) -ge 0) { $ieWhy = 'it holds one of the characters [ ] \ : * ?' }
        elseif ($ieText.StartsWith('/', [System.StringComparison]::Ordinal)) { $ieWhy = 'it begins with /' }
        elseif ($ieText.EndsWith('/', [System.StringComparison]::Ordinal)) { $ieWhy = 'it ends with /' }
        elseif (@($ieText.Split('/') | Where-Object { ($_ -ceq '') -or ($_ -ceq '.') -or ($_ -ceq '..') }).Count -gt 0) { $ieWhy = 'it holds an empty, . or .. segment' }
        elseif (-not $ieSeen.Add($ieText)) { $ieWhy = 'it repeats an earlier item' }
        if ($ieWhy) { return [pscustomobject]@{ item = $ieText; reason = $ieWhy } }
    }
    return $null
}

# =================================================================================================
# THE BATCH-5 CHARTER, WP-N (b) (the operator's ruling 10
# and two later rulings of his): THE ENGINE READ. AN INSTRUMENT THAT NEEDS THE DOCKER ENGINE
# IS NOT LAUNCHED INTO ONE THAT IS DOWN.
# =================================================================================================
# WHAT IT WAS. The evaluator launched the instrument whatever the engine's state; with the engine stopped
# the product instrument's suite did not finish inside its 900 s wall -- a wall and a
# runnable-0 tally where the finding was two words long.
# THE KEY. An instrument_exit0 detector may carry `engine_read: docker_pipe` or
# `engine_read: docker_pipe_then_version`. ABSENT, no read is made and the detector is what it was.
#   docker_pipe               the NAMES of this host's named pipes are listed
#                             ([System.IO.Directory]::GetFiles('\\.\pipe\')) and dockerDesktopLinuxEngine
#                             looked for among their leaf names, case folded. Names only: no pipe is
#                             opened and no process is started (the listing form is chosen because a
#                             test for one pipe's existence may open it -- not driven here)
#   docker_pipe_then_version  that, and where the pipe is there, `docker version --format
#                             {{.Server.Version}}` through the process API, bounded to 10 s: exit 0 with a
#                             first line that is not empty is an engine that answers; any other exit, no
#                             output, a launch that fails, or the bound -- the child's process tree then
#                             killed -- is an engine that is down. (A present pipe over a backend that does
#                             not answer is the shape the first read cannot see.)
# WHEN. At EVERY INVOKED EVALUATION of the detector, after the arm's refusals and BEFORE ANY REUSE DECISION
# (BATCH-6 WP-Q (a); the operator's ruling (b) of 21:49 local), and the outcome follows the
# read: UP, the reuse question as before; DOWN, NOT RUN and nothing reused. In hook mode a detector that is not
# invoked makes none. (Until then the read was made only where the instrument was ABOUT TO BE LAUNCHED,
# after the reuse question, and a reuse made none: a goal that declared engine_read read MET by reuse with the
# engine down -- said then, not hidden, and closed by that row.)
# DOWN: the detector FAILS, "<leaf> NOT RUN: engine down -- <the read's own words> (engine_read <value>;
# <a record id>)." -- no capture is written, the helper is not called, the verdict is NOT_MET through
# this entry. THE DETAIL's WHOLE FORM: those words and no more where no window above 0 is declared; and where
# one is, after them " reuse_within_minutes <N>: no reuse question was asked -- the engine read answered down
# before any reuse decision (<a record id>)." -- never the words a launched detector's detail carries ("NOT
# reused, the instrument was run"), which would say NOT RUN and "was run" of one instrument in one detail (the
# independent validator's round 1, a finding). (Until then the reuse question came first, and where it was
# answered no the tail was " reuse_within_minutes <N>: NOT reused, and the instrument was not launched
# (<a record id>) -- <the reason nothing was reused>".)
# UP: the instrument is launched and its detail is what it is without the key. Either way every
# read MADE is one item of the verdict's instrument_engine_reads, written (`[]` when no read was made)
# wherever some instrument_exit0 declares engine_read.
# A LISTING THAT THROWS IS NOT CAUGHT TO PROCEED: it leaves these functions, lands in the per-detector
# catch and FAILS the detector -- never a launch on a read that was not made.
# THE FIXTURE'S SEAM: `engine_read_fault: pipe_absent | version_exit | version_silent`, one more
# key on the detector. A DETECTOR CARRYING IT ASKS NO REUSE QUESTION AT ALL, and its read can only answer
# DOWN, so it ends NOT RUN on every path: a goal carrying the key never reads MET through that detector.
# pipe_absent: the real listing is taken and timed, and the engine's pipe is then REPORTED absent.
# version_exit / version_silent: the real listing is taken and reported as it is, and whatever it says the
# real bounded-launch routine is run -- over a STAND-IN child (one that exits 1; one that sleeps 30 s) in
# place of docker. So the DOWN branch, the bound, the kill and the NOT RUN return are the real code; only
# docker's own failure is stood in for. The detail and the item say FAULT INJECTED BY THE GOAL's
# engine_read_fault KEY. It is no exemption: it cannot make a declared read pass, or be skipped.
# WHAT REFUSES, at the head of the arm, before the reuse question, each a FAILED entry by name, in this
# order: an engine_read value that is neither of the two (the empty one among them); a fault with no
# engine_read beside it; a fault that is none of the three; a version_* fault under docker_pipe, which
# makes no docker version read.
# WHAT IT GIVES UP: the UP branch is driven only against a host whose engine is up (the fixture cannot
# stand an engine up; a goal-named pipe would let a live goal name a pipe that always exists, and is not
# built). And the read is of ONE engine, Docker Desktop's Linux engine by its pipe's name.
function Invoke-InstrumentEngineChild {
    # THE BOUNDED LAUNCH OF ONE CHILD THAT IS ASKED WHETHER THE ENGINE ANSWERS -- `docker version`, or the
    # seam's stand-in for it: through the process API (no shell, no window, stdout and stderr redirected),
    # waited for -BoundMs and no longer. Returns answered (exit 0 and a first stdout line that is not
    # empty), text (that line), why (when not answered: `exit <n>`, `it printed nothing`, `no answer
    # inside <s> s, its process tree killed`, or `it could not be started: <message>`) and seconds.
    # THE CHILD's STREAMS ARE READ ASYNCHRONOUSLY, never to their end ahead of the wait: a child that says
    # nothing would hold that read for as long as it lives. AND A CHILD PAST THE BOUND IS DEAD BEFORE THIS
    # RETURNS, its tree with it (taskkill /T /F, then the process's own Kill where that left it standing):
    # the child inherits this evaluator's own stdout and stderr, and left alive it holds a hook's caller
    # waiting on them for as long as it lives. It runs nothing through the call operator, so $LASTEXITCODE
    # is not touched. IT NEVER THROWS: a child that cannot be started has not answered.
    param([Parameter(Mandatory = $true)][string]$FileName, [string]$Arguments = '', [int]$BoundMs = 10000)
    $ecOut = [pscustomobject]@{ answered = $false; text = ''; why = ''; seconds = 0.0 }
    $ecProc = $null
    $ecClock = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $ecPsi = New-Object System.Diagnostics.ProcessStartInfo
        $ecPsi.FileName = $FileName
        $ecPsi.Arguments = $Arguments
        $ecPsi.UseShellExecute = $false
        $ecPsi.CreateNoWindow = $true
        $ecPsi.RedirectStandardOutput = $true
        $ecPsi.RedirectStandardError = $true
        $ecProc = [System.Diagnostics.Process]::Start($ecPsi)
        $ecStdout = $ecProc.StandardOutput.ReadToEndAsync()
        $ecStderr = $ecProc.StandardError.ReadToEndAsync()
        if (-not $ecProc.WaitForExit($BoundMs)) {
            try {
                $ecKill = New-Object System.Diagnostics.ProcessStartInfo
                $ecKill.FileName = Join-Path ([Environment]::SystemDirectory) 'taskkill.exe'
                $ecKill.Arguments = '/PID ' + [string]$ecProc.Id + ' /T /F'
                $ecKill.UseShellExecute = $false
                $ecKill.CreateNoWindow = $true
                $ecKill.RedirectStandardOutput = $true
                $ecKill.RedirectStandardError = $true
                $ecKiller = [System.Diagnostics.Process]::Start($ecKill)
                try {
                    $null = $ecKiller.StandardOutput.ReadToEndAsync()
                    $null = $ecKiller.StandardError.ReadToEndAsync()
                    $null = $ecKiller.WaitForExit(5000)
                } finally { $ecKiller.Dispose() }
            } catch { }
            try { if (-not $ecProc.WaitForExit(3000)) { $ecProc.Kill(); $null = $ecProc.WaitForExit(3000) } } catch { }
            $ecOut.why = 'no answer inside ' + [string][int][Math]::Round($BoundMs / 1000.0) + ' s, its process tree killed'
        } else {
            $ecCode = $ecProc.ExitCode
            $ecText = ''
            try { if ($ecStdout.Wait(3000)) { $ecText = [string]$ecStdout.Result } } catch { $ecText = '' }
            $ecFirst = ([string](@(($ecText -replace "`r", '') -split "`n")[0])).Trim()
            if ($ecCode -ne 0) { $ecOut.why = 'exit ' + [string]$ecCode }
            elseif (-not $ecFirst) { $ecOut.why = 'it printed nothing' }
            else { $ecOut.answered = $true; $ecOut.text = $ecFirst }
        }
    } catch {
        $ecOut.answered = $false
        $ecOut.text = ''
        $ecOut.why = 'it could not be started: ' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' '))
    } finally {
        $ecClock.Stop()
        if ($null -ne $ecProc) { try { $ecProc.Dispose() } catch { } }
    }
    $ecOut.seconds = $ecClock.Elapsed.TotalSeconds
    return $ecOut
}

function Get-InstrumentEngineRead {
    # THE ENGINE READ OF ONE instrument_exit0 DETECTOR, MADE BEFORE ANY REUSE DECISION (the
    # block above states the rule). -Leaf is the instrument's leaf name, -Read the detector's engine_read (one of the two values:
    # the arm has refused every other) and -Fault its engine_read_fault ('' or one of the three, which the
    # arm has held to the read). Returns up, words (when not up: what the detail says after "engine down --
    # ") and items (one line per read MADE, in the order made, for instrument_engine_reads).
    # THE LISTING IS NOT IN A TRY: a host whose pipe names cannot be listed throws out of here, by design.
    # A pipe's leaf name is what follows its last backslash -- never [System.IO.Path]::GetFileName, which
    # throws in Windows PowerShell 5.1 on a name holding a character illegal in a path, and pipes have such
    # names. Seconds are printed fixed-point under the invariant culture: digits and a point, never a comma
    # or an exponent.
    param([Parameter(Mandatory = $true)][string]$Leaf, [Parameter(Mandatory = $true)][string]$Read, [string]$Fault = '')
    $erOut = [pscustomobject]@{ up = $false; words = ''; items = @() }
    $erItems = New-Object System.Collections.Generic.List[string]
    $erPipe = '\\.\pipe\dockerDesktopLinuxEngine'
    $erInvariant = [System.Globalization.CultureInfo]::InvariantCulture
    $erFaultSaid = if ($Fault) { 'FAULT INJECTED BY THE GOAL''s engine_read_fault KEY (' + $Fault + '): ' } else { '' }
    # THE FIRST READ, under either value of the key and under every fault: the names, and nothing opened.
    $erClock = [System.Diagnostics.Stopwatch]::StartNew()
    $erNames = @([System.IO.Directory]::GetFiles('\\.\pipe\'))
    $erClock.Stop()
    $erThere = $false
    foreach ($erName in $erNames) {
        if ([string]::Equals(([string]$erName).Substring(([string]$erName).LastIndexOf('\') + 1), 'dockerDesktopLinuxEngine', [System.StringComparison]::OrdinalIgnoreCase)) { $erThere = $true; break }
    }
    $erCounted = '(' + [string]$erNames.Count + ' named pipes, ' + $erClock.Elapsed.TotalSeconds.ToString('0.0000', $erInvariant) + ' s)'
    if ($Fault -ceq 'pipe_absent') {
        # THE SEAM, FIRST FAULT: the listing above was really taken; the engine's pipe is REPORTED absent.
        $erItems.Add($Leaf + ': ' + $erFaultSaid + 'docker_pipe ' + $erPipe + ' ABSENT ' + $erCounted)
        $erOut.words = $erFaultSaid + 'the named pipe ' + $erPipe + ' is reported absent'
        $erOut.items = @($erItems.ToArray())
        return $erOut
    }
    $erItems.Add($Leaf + ': docker_pipe ' + $erPipe + ' ' + $(if ($erThere) { 'present' } else { 'ABSENT' }) + ' ' + $erCounted)
    if ((-not $erThere) -and (-not $Fault)) {
        $erOut.words = 'the named pipe ' + $erPipe + ' is not among the ' + [string]$erNames.Count + ' named pipe(s) of this host'
        $erOut.items = @($erItems.ToArray())
        return $erOut
    }
    if ($Read -cne 'docker_pipe_then_version') {
        # docker_pipe ALONE, the pipe there (no fault reaches this line: pipe_absent returned above, and the
        # arm refuses a version_* fault under this value): the engine is taken to be up.
        $erOut.up = $true
        $erOut.items = @($erItems.ToArray())
        return $erOut
    }
    # THE SECOND READ: docker itself, bounded -- or, under a version_* fault and WHATEVER THE LISTING SAID, the
    # same bounded launch over a stand-in child, so the faulted step always runs and can only fail.
    $erChild = $null
    if ($Fault -ceq 'version_exit') { $erChild = Invoke-InstrumentEngineChild -FileName 'powershell' -Arguments '-NoProfile -NonInteractive -Command "exit 1"' }
    elseif ($Fault -ceq 'version_silent') { $erChild = Invoke-InstrumentEngineChild -FileName 'powershell' -Arguments '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 30"' }
    else { $erChild = Invoke-InstrumentEngineChild -FileName 'docker' -Arguments 'version --format {{.Server.Version}}' }
    $erSeconds = ([double]$erChild.seconds).ToString('0.000', $erInvariant)
    if ($erChild.answered -and (-not $Fault)) {
        $erItems.Add($Leaf + ': docker version answered ' + (ConvertTo-ManifestDisplayText -Text ([string]$erChild.text) -Max 80) + ' (' + $erSeconds + ' s)')
        $erOut.up = $true
    } else {
        # (A stand-in cannot answer -- one exits 1, one outlives the bound -- so under a fault `why` is always
        # the routine's own; the `exit 0` below is what would be said of one that somehow did.)
        $erWhy = if ($erChild.why) { ConvertTo-ManifestDisplayText -Text ([string]$erChild.why) -Max 300 } else { 'exit 0' }
        $erItems.Add($Leaf + ': ' + $erFaultSaid + 'docker version did not answer: ' + $erWhy + ' (' + $erSeconds + ' s)')
        if ($Fault) { $erOut.words = $erFaultSaid + 'a stand-in child ran in place of docker version and did not answer (' + $erWhy + ')' }
        else { $erOut.words = 'the named pipe ' + $erPipe + ' is present and docker version did not answer (' + $erWhy + ')' }
    }
    $erOut.items = @($erItems.ToArray())
    return $erOut
}

function Save-InstrumentReusedCapture {
    # THE BATCH-4 CHARTER (the operator's rulings B7
    # and B8 of 2026-10-06): THE CAPTURE A REUSE CITES IS KEPT, CONTENT-ADDRESSED, BESIDE THE LIVE FILE,
    # BEFORE THE VERDICT NAMES IT. A reused capture is cited by path and sha256, and the next fresh
    # evaluation under the same run key rewrites that path: the digest the verdict named was then on disk
    # nowhere but in a seat's hand copy, and one was missed.
    # THE NAME is the live file's own, whole, with the first eight hex of the cited sha256 before its tail:
    #   <key>.<instrument leaf>.stdout.txt  ->  <key>.<instrument leaf>.<sha8>.stdout.txt
    # in the same directory. It does not end `.<instrument leaf>.stdout.txt`, so the reuse scan's filter
    # never offers a kept copy as a candidate, and it is not a name the shared helper or the runner writes.
    # THE BYTES are -Bytes, the array the cited sha256 was computed over; they are hashed again here and must
    # read -Sha256, so what is written is what is cited: header, delimiters, body and closing line.
    # A KEPT COPY IS NEVER OVERWRITTEN. The name free: it is created with CreateNew and no sharing, read back
    # and hashed. The name taken by a FILE of the same bytes THAT IS NOT THE LIVE FILE ITSELF: it is kept as
    # found and nothing is written. The name taken by anything else -- other bytes, a directory, a second name
    # of the live capture (a hard link: the next fresh run would rewrite it), a file that cannot be read --
    # or a write that fails: ok is false, what stood at the name stands unchanged, and the caller then
    # reuses nothing. A file THIS call created and could not finish or verify is removed again, so a failed
    # keep leaves no partial file under a content-addressed name.
    # Returns ok, path (the kept name), how ('written now' or 'already kept, the same bytes') and why.
    # IT NEVER THROWS. Only the stdout capture is kept: it is the file the verdict cites.
    # WHAT IT GIVES UP: the kept copies only grow -- one file per distinct capture reused, and nothing here
    # or in the shared helper removes one.
    param([Parameter(Mandatory = $true)][string]$Path, [AllowNull()][byte[]]$Bytes, [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Sha256)
    $kc = [pscustomobject]@{ ok = $false; path = ''; how = ''; why = '' }
    $kcStream = $null
    $kcCreated = $false
    try {
        $kcTail = '.stdout.txt'
        $kcName = [System.IO.Path]::GetFileName($Path)
        if (($null -eq $Bytes) -or ($Sha256 -cnotmatch '\A[0-9a-f]{64}\z') -or (-not $kcName.EndsWith($kcTail, [System.StringComparison]::Ordinal)) -or ($kcName.Length -le $kcTail.Length)) {
            $kc.why = 'the capture to keep is not a <key>.<leaf>.stdout.txt file with its bytes and a sha256'
            return $kc
        }
        if ((Get-LamCaptureSha256 -Bytes $Bytes) -cne $Sha256) { $kc.why = 'the bytes in hand do not hash to the sha256 cited'; return $kc }
        $kc.path = Join-Path ([System.IO.Path]::GetDirectoryName($Path)) ($kcName.Substring(0, $kcName.Length - $kcTail.Length) + '.' + $Sha256.Substring(0, 8) + $kcTail)
        if ([System.IO.Directory]::Exists($kc.path)) { $kc.why = 'a directory stands at ' + $kc.path + ', and a kept copy is never written over anything'; return $kc }
        if ([System.IO.File]::Exists($kc.path)) {
            $kcThereBytes = $null
            try { $kcThereBytes = [System.IO.File]::ReadAllBytes($kc.path) }
            catch { $kc.why = 'a file already stands at ' + $kc.path + ' and could not be read (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + '), and a kept copy is never overwritten'; return $kc }
            $kcThere = Get-LamCaptureSha256 -Bytes $kcThereBytes
            if ($kcThere -cne $Sha256) {
                $kc.why = 'a file already stands at ' + $kc.path + ' with other bytes (sha256 ' + $kcThere + '), and a kept copy is never overwritten'
                return $kc
            }
            # THE SAME BYTES -- BUT IS IT ANOTHER FILE? A hard link to the live capture at the kept name has
            # the live capture's bytes because it IS the live capture, and the next fresh run rewrites both
            # names. The file's own identity test (the one the handoff arm applies to its record): the live
            # capture held with no sharing, the kept name opened -- one file, or a question that could not be
            # settled, is not a kept copy.
            $kcSelf = Test-HandoffBriefIsRecord -BriefPath $kc.path -RecordPath $Path -Noun 'live capture' -LongNoun 'live capture'
            if ($kcSelf.same -or $kcSelf.undetermined) {
                $kc.why = 'the file at ' + $kc.path + ' has the capture''s bytes but ' + $(if ($kcSelf.same) { 'is the live capture itself under another name (' } else { 'could not be told apart from the live capture (' }) + [string]$kcSelf.how + '), and the next run would rewrite it'
                return $kc
            }
            $kc.ok = $true
            $kc.how = 'already kept, the same bytes'
            return $kc
        }
        $kcStream = New-Object System.IO.FileStream($kc.path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $kcCreated = $true
        $kcStream.Write($Bytes, 0, $Bytes.Length)
        $kcStream.Flush()
        $kcStream.Dispose()
        $kcStream = $null
        $kcBack = Get-LamCaptureSha256 -Bytes ([System.IO.File]::ReadAllBytes($kc.path))
        if ($kcBack -cne $Sha256) { throw ('it reads back as sha256 ' + $kcBack + ', not the sha256 cited') }
        $kc.ok = $true
        $kc.how = 'written now'
        return $kc
    } catch {
        $kc.ok = $false
        $kc.why = 'it could not be written' + $(if ($kc.path) { ' at ' + $kc.path } else { '' }) + ' (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + ')'
        if ($null -ne $kcStream) { try { $kcStream.Dispose() } catch { }; $kcStream = $null }
        # What THIS call created and could not finish is removed: no partial file stays under the name.
        if ($kcCreated) { try { [System.IO.File]::Delete($kc.path); $kc.why += '; the unfinished file was removed' } catch { $kc.why += '; AND THE UNFINISHED FILE COULD NOT BE REMOVED' } }
        return $kc
    } finally { if ($null -ne $kcStream) { try { $kcStream.Dispose() } catch { } } }
}

function Get-InstrumentKeptOnDisk {
    # A LATER CHARTER, WP-N (d) (the operator's ruling of
    # 2026-10-11): THE KEPT COPIES, LISTED BY THE TOOL. A verdict that reuses a capture names the ONE copy it
    # kept (Save-InstrumentReusedCapture) and said nothing of what else stands at a kept name -- the copies only grow,
    # and which of them still hash to their names was a seat's hand list at every close. THE RULE: where the
    # verdict is MET and a window above 0 is declared (the caller asks only then), this is the artifact's
    # instrument_captures_kept_on_disk: for each instrument_exit0 detector's instrument EVERY name under
    # instrument-runs of the kept copy's form, <key>.<instrument leaf>.<eight hex>.stdout.txt -- BY LEAF,
    # UNDER EVERY RUN KEY, a file or a directory -- one item each, the names in ordinal order:
    #   <full path> sha256 <64 hex>                                      its bytes hash to its name
    #   <full path> sha256 <64 hex> -- MISMATCH: the name says <8 hex>   they do not; the digest is of the
    #                                                                    bytes that stand there now
    #   <full path> -- UNREADABLE: <why>                                 it could not be read
    #   <full path> -- NOT A FILE                                        a directory stands at the name
    # WHY BY LEAF AND NOT UNDER THE GOAL'S RUN KEY (the charter's words): a kept copy is named from the
    # capture that was REUSED (Save-InstrumentReusedCapture), and the candidates are captures under ANY run
    # key -- a listing scoped to the goal's key would omit the very copy the same verdict cites when the
    # capture reused was a hand run's.
    # AND WHY THE WHOLE NAME IS MATCHED IN ANY CASE (the independent validator's round 3, a finding): THE
    # LISTER SEES A NAME AS THE FILE SYSTEM SEES IT. The evaluator finds its candidates by a filter that
    # folds case (Get-ChildItem -Filter) and asks whether a kept name is taken with File.Exists, which
    # folds case too: it can reuse, find "already kept" and CITE a file whose name on disk is the kept
    # name in another case -- and a lister that held the form to the case of its letters left the very
    # copy a verdict cites out of this list. It happens two ways. THE LEAF: the token here is the one
    # derivation's (Get-LamInstrumentRunPath) over the goal's `path` AS THE GOAL SPELLS IT, while a
    # capture is named by the helper from the instrument's path AS THE PATH WAS GIVEN TO IT -- a hand run
    # over <root>\scratch\INST.ps1 under the run key HAND is HAND.INST.stdout.txt, and the goal whose path
    # is scratch/inst.ps1 reuses it and keeps HAND.INST.<eight hex>.stdout.txt. THE HEX AND THE TAIL: no
    # tool writes them in another case, but a file a hand left at <key>.<leaf>.<EIGHT HEX>.stdout.txt
    # holding the capture's bytes IS the kept name to File.Exists: Save-InstrumentReusedCapture finds it
    # already kept, writes nothing beside it, and the verdict cites the name as derived, lower-case hex.
    # The lister must not see less than the evaluator can cite, so every part of the form is matched
    # without regard to case -- under the INVARIANT culture: a fold that followed the session's culture
    # does not take INST for inst under a Turkish one. (For the ASCII letters -- all that the token, the
    # hex and the tail hold -- that fold and the volume's own agree; a name carrying some other letter
    # that one of the two folds onto an ASCII one is not claimed.)
    # NOTHING ELSE MOVES. The names are sorted ordinally, as they stand on disk. The item's path is
    # Join-Path over that derivation's directory and THE NAME AS THE DIRECTORY HOLDS IT. And the test
    # below still holds the sha8 to the name's eight hex AS WRITTEN: a name that says its hex in another
    # case is LISTED and reads MISMATCH, never clean -- no tool writes such a name, and the list says so
    # aloud instead of dropping it --, while a name whose tail alone is in another case, its hex
    # lower-case and true, lists clean under the name the directory holds. So a copy the evaluator
    # wrote -- under the reused capture's own name, its eight hex before the tail -- reads here character
    # for character as it reads in instrument_captures_kept; and a file it found already kept under a
    # name in another case has its item under THAT name, which is not the spelling the verdict cites.
    # IT NEVER THROWS AND IT NEVER MOVES THE VERDICT: the artifact is composed by top-level code, and a
    # throw there would end in the trap and BLOCK a met goal over a listing. Each name is examined in its
    # own try, and what that try holds is one cmdlet (Join-Path), .NET calls (Directory.Exists,
    # File.ReadAllBytes, string work) and the helper's Get-LamCaptureSha256 -- none of which writes to
    # stdout or stderr where it succeeds, and a failure of any of them is caught there and becomes the
    # item. So a copy another process holds is an item that says so and the names after it are still
    # listed; a directory that cannot be listed is the one item.
    # WHAT IT COSTS, stated: EVERY kept copy is read and hashed again at EVERY MET verdict of a goal that
    # declares a window above 0 -- in the Stop hook's path too, where time is the budget -- and the kept
    # copies only grow (Save-InstrumentReusedCapture removes none; nothing here does either).
    # WHAT IT DOES NOT SAY, stated: it reads a name and a digest, never a capture. A file of other bytes
    # renamed to THEIR OWN first eight hex lists clean; a copy deleted leaves no item; and no earlier
    # verdict's citation is read back against what stands here.
    param([Parameter(Mandatory = $true)][string]$MissionRoot, [AllowNull()][object[]]$Detectors)
    $kdItems = New-Object System.Collections.Generic.List[string]
    $kdDir = ''
    try {
        $kdTokens = New-Object System.Collections.Generic.List[string]
        foreach ($kdDetector in @($Detectors)) {
            if (($null -eq $kdDetector) -or (([string]$kdDetector['type']) -ne 'instrument_exit0')) { continue }
            $kdDeclared = [string]$kdDetector['path']
            if (-not $kdDeclared) { continue }
            $kdPaths = Get-LamInstrumentRunPath -MissionRoot $MissionRoot -InstrumentPath $kdDeclared -RunKey 'k'
            $kdDir = [string]$kdPaths.dir
            $kdToken = ([string]$kdPaths.base).Substring(2)
            if (-not $kdTokens.Contains($kdToken)) { $kdTokens.Add($kdToken) }
        }
        if ((-not $kdDir) -or ($kdTokens.Count -eq 0) -or (-not [System.IO.Directory]::Exists($kdDir))) { return @($kdItems.ToArray()) }
        # ONE LIST, files and directories together, each kept name once though two detectors name one leaf.
        $kdNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        foreach ($kdEntry in [System.IO.Directory]::GetFileSystemEntries($kdDir)) {
            $kdName = ([string]$kdEntry).Substring(([string]$kdEntry).LastIndexOf('\') + 1)
            foreach ($kdToken in $kdTokens) {
                if ([regex]::IsMatch($kdName, ('\A.+\.' + [regex]::Escape($kdToken) + '\.[0-9a-f]{8}\.stdout\.txt\z'), ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant))) { [void]$kdNames.Add($kdName); break }
            }
        }
        $kdSorted = [string[]]@($kdNames)
        [Array]::Sort($kdSorted, [System.StringComparer]::Ordinal)
        foreach ($kdName in $kdSorted) {
            $kdPath = $kdDir + '\' + $kdName
            try {
                $kdPath = Join-Path $kdDir $kdName
                if ([System.IO.Directory]::Exists($kdPath)) { $kdItems.Add($kdPath + ' -- NOT A FILE'); continue }
                $kdSha = Get-LamCaptureSha256 -Bytes ([System.IO.File]::ReadAllBytes($kdPath))
                $kdSaid = $kdName.Substring($kdName.Length - '.stdout.txt'.Length - 8, 8)
                if ($kdSha.Substring(0, 8) -ceq $kdSaid) { $kdItems.Add($kdPath + ' sha256 ' + $kdSha) }
                else { $kdItems.Add($kdPath + ' sha256 ' + $kdSha + ' -- MISMATCH: the name says ' + $kdSaid) }
            } catch {
                $kdItems.Add($kdPath + ' -- UNREADABLE: ' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')))
            }
        }
    } catch {
        # The directory itself could not be listed (or a name not derived): said as ONE item, never thrown.
        $kdItems.Add($(if ($kdDir) { $kdDir } else { 'the instrument-runs directory' }) + ' -- UNREADABLE: the kept copies could not be listed (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + ')')
    }
    return @($kdItems.ToArray())
}

# =================================================================================================
# BATCH-6 WP-Q (a) (ruled 2026-10-16 07:2x local, leans accepted,
# Q5 and Q6 among them): A CAPTURE ADMITTED BY ITS INPUT TREE MAY BE HELD TO A TREE WINDOW OF ITS OWN.
# =================================================================================================
# WHAT IT WAS. One window, reuse_within_minutes, held every capture alike -- one at HEAD, and one its input tree
# admitted (the input-tree block). A goal whose list leaves most commits outside the instrument's inputs could keep a reading
# no longer than it would keep one taken at HEAD.
# THE KEY. `reuse_tree_within_minutes: <M>` on instrument_exit0, a whole number 0 to 999999 (the number rule's table).
# At the head of the arm, after the list, it is held to two refusals, each FAILING the detector by name with
# nothing read, reused or launched: declared without instrument_inputs_except (a tree window has no input tree
# to admit by), or without a reuse_within_minutes above 0 (it has no reuse to widen).
# THE TWO WINDOWS. Where the key is declared the arm binds -TreeRaw, and only there: NOT BOUND, every byte the
# decision writes is what it was. BOUND: the HEAD window (reuse_within_minutes, N) admits a capture whose head is
# HEAD and whose age is N minutes or less; the TREE window (M) admits a capture whose input_tree is HEAD's figure
# under the goal's list and whose age is M minutes or less -- a capture admitted by its input tree, which the
# HEAD window then no longer holds, and a capture at HEAD that carries the figure. The HEAD window is asked
# first and is the one named where both hold. A tree window shorter than the HEAD window is allowed: it narrows
# a capture admitted by its input tree.
# THE WORDS. A capture neither window admits is declined at the window test, in words that name the window or
# the windows: `it is <n> minute(s) old, outside the tree window (reuse_tree_within_minutes <M>)` (admitted by
# its input tree); `... outside the HEAD window (reuse_within_minutes <N>) and the tree window
# (reuse_tree_within_minutes <M>)` (at HEAD, carrying the figure); `... outside the HEAD window
# (reuse_within_minutes <N>); its input tree does not admit it to the tree window (<why>)` (at HEAD, its figure
# absent, not a figure or not HEAD's, or HEAD's not derivable). The REUSED detail gains `; ADMITTED BY THE HEAD
# WINDOW (reuse_within_minutes <N>)` or `; ADMITTED BY THE TREE WINDOW (reuse_tree_within_minutes <M>)` after the
# by-tree words and BEFORE `, the tree clean apart` -- so its opening, `<leaf> exited <n> (require 0). REUSED A
# FRESH READING, `, and its closing, ` THE CAPTURE CITED IS KEPT at ...`, stand byte for byte (seat.py reads
# both). The verdict carries instrument_reuse_window_admitted (Q6): one item per reuse, `<capture path> sha256
# <sha256> window head|tree minutes <the window's own minutes>`.
# WHAT IT DOES NOT MOVE. instrument_input_tree_matched is what it was -- a reuse at HEAD itself, the tree
# window's among them, names no match -- and a goal that declares no tree key reads byte for byte as it did.
function Get-InstrumentReuseDecision {
    # THE REUSE QUESTION FOR ONE instrument_exit0 DETECTOR (the block above states every condition).
    # Returns reused, minutes, note (what a fresh run's detail appends; '' for 0), and on reuse: exit,
    # path, sha256, kept (the content-addressed copy) and detail. IT NEVER THROWS:
    # anything it cannot establish is a fresh run -- a capture it cannot KEEP included.
    # -InputsExcept (the input-tree block) is the detector's instrument_inputs_except list, as the arm read and
    # held it to the item rule. BOUND, the key is declared: HEAD's input tree is derived and the head
    # condition is widened by it. FIVE MEMBERS WERE ADDED TO WHAT IS RETURNED, on every return and whether
    # or not the parameter is bound: head (HEAD, '' until it was read and held to 40 hex), inputTree (HEAD's
    # figure, '' where none was derived), inputTreeWhy (why there is none, in words the verdict's
    # instrument_inputs_except item prints), byInputTree ($true on a reuse the figure admitted) and
    # captureHead (that capture's own head, '' otherwise). NOT BOUND, no figure is derived and the head
    # condition is what it was: inputTree stays '', byInputTree $false and captureHead ''; head and
    # inputTreeWhy are still set as the reads go, and nobody reads them.
    # AND TWO MORE, FOR THE DETECTOR THAT ASKS THIS QUESTION AND IS THEN NOT LAUNCHED (the engine read's DOWN;
    # the independent validator's round 1, a finding). EVERY NOTE SAYS THE INSTRUMENT WAS RUN, because where
    # this function answers "not reused" the arm goes on to launch it -- unless the engine read then answers
    # DOWN, and a detail must not say NOT RUN and "was run" at once. So, set wherever a note may follow and
    # read only beside a `note` that is not '': noteLead, the words `note` OPENS with and says the launch
    # in -- everything ahead of the reason nothing was reused (for the one note that gives no reason after
    # them, the whole of it) -- and noteLeadNotLaunched, the words that stand in their place where there
    # was no launch. `note` itself is what it was, to the byte; the arm swaps the one lead for the other
    # and keeps the reason as it is. (Now the arm reads the engine BEFORE it asks, so no
    # detector that asks is then left unlaunched by a DOWN; both leads stay in the return, as ruled -- Q4.)
    # -TreeRaw (the block above) is the detector's reuse_tree_within_minutes as written, BOUND
    # only where the key is declared -- and the arm then binds -InputsExcept beside it. Two members more, on every
    # return: window ('head' or 'tree' on a reuse where -TreeRaw is bound, '' otherwise) and windowMinutes (that
    # window's own minutes, 0 otherwise).
    param([Parameter(Mandatory = $true)][string]$MissionRoot, [Parameter(Mandatory = $true)][string]$InstrumentPath, [AllowNull()][AllowEmptyString()][string]$Raw, [AllowNull()][string[]]$InputsExcept = $null,
          [AllowNull()][AllowEmptyString()][string]$TreeRaw = $null)
    $ru = [pscustomobject]@{ reused = $false; minutes = 0; note = ''; noteLead = ''; noteLeadNotLaunched = ''; exit = 1; path = ''; sha256 = ''; kept = ''; detail = ''
                             head = ''; inputTree = ''; inputTreeWhy = ''; byInputTree = $false; captureHead = ''; window = ''; windowMinutes = 0 }
    $ruTreeDeclared = $PSBoundParameters.ContainsKey('InputsExcept')
    $ruTreeWindow = $PSBoundParameters.ContainsKey('TreeRaw')
    $ruText = ([string]$Raw).Trim()
    # The one whole-number rule. From a goal file a value that fails it never arrives -- the goal
    # does not parse, and no detector runs; this refusal is for a caller that reaches the function otherwise.
    $ruParsed = ConvertTo-GoalWholeNumber -Text $ruText -Min 0
    if (-not $ruParsed.ok) {
        $ruNotANumber = " reuse_within_minutes '" + (ConvertTo-ManifestDisplayText -Text $ruText -Max 40) + "' is not a whole number of minutes from 0 to 999999: nothing is reused, and the instrument "
        $ru.note = $ruNotANumber + 'was run (register rows 368 and 385).'
        $ru.noteLead = $ru.note
        $ru.noteLeadNotLaunched = $ruNotANumber + 'was not launched (register rows 368 and 385).'
        $ru.inputTreeWhy = 'HEAD was not read: reuse_within_minutes is not a whole number of minutes'
        return $ru
    }
    $ru.minutes = $ruParsed.value
    # (inputTreeWhy, read only where the key is declared: until HEAD has been read and held to 40 hex there is
    # no figure to print, and it says which return that was -- this one, the window 0; then, until the reads
    # below are through, a check that ended before them.)
    $ru.inputTreeWhy = 'HEAD was not read: reuse_within_minutes is 0, and nothing is ever reused'
    if ($ru.minutes -eq 0) { return $ru }
    $ruLead = " reuse_within_minutes $($ru.minutes): NOT reused, the instrument was run (register row 368) -- "
    # Every note below is $ruLead and then its reason. The pair of leads is handed back from here, once.
    $ru.noteLead = $ruLead
    $ru.noteLeadNotLaunched = " reuse_within_minutes $($ru.minutes): NOT reused, and the instrument was not launched (register row 368) -- "
    $ru.inputTreeWhy = 'HEAD was not read: the reuse check ended before it'
    # THE TREE WINDOW's MINUTES, by the one whole-number rule. From a goal file a value that fails it never
    # arrives (the goal does not parse); this refusal is for a caller that reaches the function otherwise.
    $ruTreeMinutes = 0
    if ($ruTreeWindow) {
        $ruTreeParsed = ConvertTo-GoalWholeNumber -Text ([string]$TreeRaw) -Min 0
        if (-not $ruTreeParsed.ok) {
            $ru.note = $ruLead + 'reuse_tree_within_minutes ''' + (ConvertTo-ManifestDisplayText -Text (([string]$TreeRaw).Trim()) -Max 40) + ''' is not a whole number of minutes from 0 to 999999, so no window is read (register rows 385 and 438).'
            $ru.inputTreeWhy = 'HEAD was not read: reuse_tree_within_minutes is not a whole number of minutes'
            return $ru
        }
        $ruTreeMinutes = $ruTreeParsed.value
    }
    try {
        $ruMine = [System.IO.Path]::GetFullPath($InstrumentPath)
        $ruNowSha = Get-LamCaptureSha256 -Bytes ([System.IO.File]::ReadAllBytes($ruMine))
        $ruHead = ''
        $ruHeadExit = 1
        $ruTop = ''
        $ruTopExit = 1
        $ruPrev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try {
            $ruTop = ("$(& git -C $MissionRoot rev-parse --show-toplevel 2>&1)").Trim()
            $ruTopExit = $LASTEXITCODE
            $ruHead = ("$(& git -C $MissionRoot rev-parse HEAD 2>&1)").Trim()
            $ruHeadExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $ruPrev }
        # THE MISSION ROOT MUST BE THE REPOSITORY'S OWN TOP LEVEL: at a plain directory inside another
        # repository git answers for the ENCLOSING one, and its HEAD and its tree are not this mission's.
        $ruTopIsRoot = $false
        if (($ruTopExit -eq 0) -and $ruTop) {
            $ruTopIsRoot = [string]::Equals([System.IO.Path]::GetFullPath($ruTop.Replace('/', '\')).TrimEnd('\'), [System.IO.Path]::GetFullPath($MissionRoot).TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)
        }
        if (-not $ruTopIsRoot) {
            $ru.note = $ruLead + 'the mission root is not the top level of a git repository, so there is no HEAD and no tree of its own to hold a capture to.'
            $ru.inputTreeWhy = 'HEAD was not read: the mission root is not the top level of a git repository'
            return $ru
        }
        if (($ruHeadExit -ne 0) -or ($ruHead -cnotmatch '\A[0-9a-f]{40}\z')) {
            $ru.note = $ruLead + 'HEAD could not be derived at the mission root.'
            $ru.inputTreeWhy = 'HEAD was not read: HEAD could not be derived at the mission root'
            return $ru
        }
        # RULE (i): HEAD's INPUT TREE, DERIVED HERE AND NOWHERE ELSE -- from the head just read and held to
        # 40 hex (it is never read a second time), by the helper's one function, the one a capture's own
        # figure was taken with -- and BEFORE the returns below, so that a fresh run with a tree that is not
        # clean, or with no capture on disk, still hands the figure back for the verdict's key. Where it is
        # not derivable NOTHING IS REUSED BY INPUTS: a capture at HEAD itself still passes, as it always did.
        # Get-LamInputTree does not throw; were it to, the catch below would end in a fresh run, said.
        $ru.head = $ruHead
        $ru.inputTreeWhy = ''
        $ruTreeFigure = ''
        if ($ruTreeDeclared) {
            $ruTree = Get-LamInputTree -MissionRoot $MissionRoot -Head $ruHead -Except $InputsExcept
            if ($ruTree.ok -and ([string]$ruTree.figure -cmatch '\A[0-9a-f]{64}\z')) { $ruTreeFigure = [string]$ruTree.figure }
            else { $ru.inputTreeWhy = [string]$ruTree.why; if (-not $ru.inputTreeWhy) { $ru.inputTreeWhy = 'the helper gave no figure and no reason' } }
            $ru.inputTree = $ruTreeFigure
        }
        $ruAdm = Test-LamAdvanceAdmission -MissionRoot $MissionRoot -RecordedHeadSha $ruHead
        if ((-not $ruAdm.admitted) -or ([string]$ruAdm.current -cne $ruHead)) {
            $ru.note = $ruLead + 'the tree is not clean apart from the mission''s declared set, by verify''s own predicate (' + ((([string]$ruAdm.reason) -replace '[\r\n]+', ' ')) + ').'
            return $ru
        }
        $ruPaths = Get-LamInstrumentRunPath -MissionRoot $MissionRoot -InstrumentPath $InstrumentPath -RunKey 'k'
        $ruLeaf = ([string]$ruPaths.base).Substring(2)
        $ruFiles = @()
        if (Test-Path -LiteralPath $ruPaths.dir -PathType Container) {
            $ruFiles = @(Get-ChildItem -LiteralPath $ruPaths.dir -File -Filter ('*.' + $ruLeaf + '.stdout.txt') -ErrorAction SilentlyContinue |
                         Sort-Object -Property LastWriteTimeUtc -Descending | Select-Object -First 32)
        }
        if ($ruFiles.Count -eq 0) { $ru.note = $ruLead + 'no capture of this instrument is on disk under ' + $ruPaths.dir + '.'; return $ru }
        $ruNow = [DateTime]::UtcNow
        $ruBest = $null
        $ruWhy = New-Object System.Collections.Generic.List[string]
        # RULE (ii): every RED reading of this instrument among the candidates, kept as it is read.
        $ruReds = New-Object System.Collections.Generic.List[object]
        # RULE (iii): every UNDATABLE capture of this instrument among the candidates, kept as it is read.
        $ruUndatable = New-Object System.Collections.Generic.List[object]
        foreach ($ruFile in $ruFiles) {
            $ruCap = Read-InstrumentCapture -Path $ruFile.FullName
            $ruNo = ''
            # THE TREE WINDOW: the window that admits this capture, where -TreeRaw is bound ('head' or 'tree'); '' elsewhere.
            $ruWin = ''
            $ruAt = [DateTime]::MinValue
            $ruAge = [TimeSpan]::Zero
            # RULE (ii), ITS SECOND HALF's READING, made of EVERY candidate and apart from the chain below:
            # a WHOLE capture of THIS instrument that did not exit 0 is remembered WHATEVER the chain then
            # declines it for -- its head, its input tree, its tree_clean, its instrument_sha256, its age.
            # Whole, here: it reads; it says which file it ran, and that file is this detector's; ran: True;
            # a numeric exit_code; a captured_at that parses, is UTC and is not in the future.
            $ruRedAt = [DateTime]::MinValue
            if ($ruCap.ok -and $ruCap.keys.ContainsKey('instrument_resolved') -and (Test-InstrumentSamePath -A ([string]$ruCap.keys['instrument_resolved']) -B $ruMine) -and
                ([string]$ruCap.keys['ran'] -ceq 'True') -and ([string]$ruCap.keys['exit_code'] -cmatch '\A-?[0-9]{1,9}\z') -and ([int]$ruCap.keys['exit_code'] -ne 0) -and
                [DateTime]::TryParse([string]$ruCap.keys['captured_at'], [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$ruRedAt) -and
                ($ruRedAt.Kind -eq [System.DateTimeKind]::Utc) -and (($ruNow - $ruRedAt).TotalSeconds -ge 0)) {
                $ruReds.Add([pscustomobject]@{ name = [string]$ruFile.Name; sha256 = [string]$ruCap.sha256; at = $ruRedAt; said = [string]$ruCap.keys['captured_at']; exit = [int]$ruCap.keys['exit_code'] })
            }
            # RULE (iii) (BATCH-6 WP-Q (d); ruled 2026-10-16 07:2x local, lean accepted): AN
            # UNDATABLE CAPTURE OF THIS INSTRUMENT, read of EVERY candidate and apart from the chain below, as the RED
            # reading above is. Undatable: it reads whole, it says it ran this detector's own file, and its
            # captured_at is absent, does not parse, is not UTC, or is in the future -- so it cannot be placed before
            # or after the capture the chain chooses, and the RED rule's (2) cannot ask whether it came later. The
            # chain still declines it in its own words; what it decides is asked after the choice, below.
            if ($ruCap.ok -and $ruCap.keys.ContainsKey('instrument_resolved') -and (Test-InstrumentSamePath -A ([string]$ruCap.keys['instrument_resolved']) -B $ruMine)) {
                $ruDateAt = [DateTime]::MinValue
                $ruDateWhy = ''
                if (-not $ruCap.keys.ContainsKey('captured_at')) { $ruDateWhy = 'it carries no captured_at' }
                elseif (-not [DateTime]::TryParse([string]$ruCap.keys['captured_at'], [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$ruDateAt)) { $ruDateWhy = 'its captured_at does not parse' }
                elseif ($ruDateAt.Kind -ne [System.DateTimeKind]::Utc) { $ruDateWhy = 'its captured_at is not a UTC time' }
                elseif (($ruNow - $ruDateAt).TotalSeconds -lt 0) { $ruDateWhy = 'its captured_at is in the future' }
                if ($ruDateWhy) { $ruUndatable.Add([pscustomobject]@{ name = [string]$ruFile.Name; sha256 = [string]$ruCap.sha256; why = $ruDateWhy; said = $(if ($ruCap.keys.ContainsKey('captured_at')) { [string]$ruCap.keys['captured_at'] } else { '' }) }) }
            }
            # RULE (i): THE HEAD CONDITION, WIDENED. $ruHeadNo is why this capture is declined FOR ITS HEAD,
            # '' where it is not: its head is HEAD (the fast path, and the only path without the key), or --
            # the key declared -- its head is another 40-hex commit id and its own input_tree is the figure
            # HEAD has under the goal's list ($ruByTree then says the figure admitted it). Without the key the
            # words are what they were, byte for byte. With it they are followed by `; ` and the FIRST of five
            # reasons that holds, asked in this order. The capture's head is held to 40 hex because it is
            # printed in the verdict and captures live in a plane an agent can write.
            $ruHeadNo = ''
            $ruByTree = $false
            if ($ruCap.ok -and $ruCap.keys.ContainsKey('head') -and ([string]$ruCap.keys['head'] -cne $ruHead)) {
                $ruHeadNo = 'its head is ' + (ConvertTo-ManifestDisplayText -Text ([string]$ruCap.keys['head']) -Max 48) + ', and HEAD is ' + $ruHead
                if ($ruTreeDeclared) {
                    if ([string]$ruCap.keys['head'] -cnotmatch '\A[0-9a-f]{40}\z') { $ruHeadNo += '; and its head is not a 40-hex commit id, so its input tree cannot admit it (register row 412)' }
                    elseif (-not $ruTreeFigure) { $ruHeadNo += '; and HEAD''s input tree is not derivable (' + (ConvertTo-ManifestDisplayText -Text ([string]$ru.inputTreeWhy) -Max 300) + '), so nothing is reused by inputs (register row 412)' }
                    elseif (-not $ruCap.keys.ContainsKey('input_tree')) { $ruHeadNo += '; and it carries no input_tree: (it was not taken under the goal''s instrument_inputs_except) (register row 412)' }
                    elseif ([string]$ruCap.keys['input_tree'] -cnotmatch '\A[0-9a-f]{64}\z') { $ruHeadNo += '; and its input_tree is not a figure (register row 412)' }
                    elseif ([string]$ruCap.keys['input_tree'] -cne $ruTreeFigure) { $ruHeadNo += '; and its input_tree ' + [string]$ruCap.keys['input_tree'] + ' is not HEAD''s ' + $ruTreeFigure + ' (register row 412)' }
                    else { $ruHeadNo = ''; $ruByTree = $true }
                }
            }
            if (-not $ruCap.ok) { $ruNo = [string]$ruCap.why }
            elseif (-not $ruCap.keys.ContainsKey('head')) { $ruNo = 'it carries no head: (it was written before register row 368)' }
            elseif ($ruHeadNo) { $ruNo = $ruHeadNo }
            elseif (-not $ruCap.keys.ContainsKey('instrument_resolved')) { $ruNo = 'it does not say which file it ran (no instrument_resolved)' }
            elseif (-not (Test-InstrumentSamePath -A ([string]$ruCap.keys['instrument_resolved']) -B $ruMine)) { $ruNo = 'it is a capture of ' + (ConvertTo-ManifestDisplayText -Text ([string]$ruCap.keys['instrument_resolved']) -Max 200) + ', not of this detector''s instrument' }
            elseif ([string]$ruCap.keys['tree_clean'] -cne 'True') { $ruNo = 'the tree was not clean, or not read, when it was taken (tree_clean: ' + (ConvertTo-ManifestDisplayText -Text ([string]$ruCap.keys['tree_clean']) -Max 48) + ')' }
            elseif ([string]$ruCap.keys['instrument_sha256'] -cne $ruNowSha) { $ruNo = 'the instrument''s bytes are not the bytes it ran (instrument_sha256 differs)' }
            elseif ([string]$ruCap.keys['ran'] -cne 'True') { $ruNo = 'the instrument did not run to completion (ran is not True)' }
            elseif ([string]$ruCap.keys['exit_code'] -cnotmatch '\A-?[0-9]{1,9}\z') { $ruNo = 'its exit_code is not a number' }
            elseif (-not [DateTime]::TryParse([string]$ruCap.keys['captured_at'], [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$ruAt)) { $ruNo = 'its captured_at does not parse' }
            elseif ($ruAt.Kind -ne [System.DateTimeKind]::Utc) { $ruNo = 'its captured_at is not a UTC time' }
            else {
                $ruAge = $ruNow - $ruAt
                if ($ruAge.TotalSeconds -lt 0) { $ruNo = 'its captured_at is in the future' }
                elseif ($ruTreeWindow) {
                    # THE TWO WINDOWS (the block above this function). A capture its input tree admitted is
                    # held to the tree window alone; one at HEAD to the HEAD window first, and then -- where it carries
                    # HEAD's figure -- to the tree window. The fast path is asked first, so it is the one named.
                    $ruOutside = 'it is ' + [string][int][Math]::Floor($ruAge.TotalMinutes) + ' minute(s) old, outside the '
                    if ($ruByTree) {
                        if ($ruAge.TotalMinutes -le $ruTreeMinutes) { $ruWin = 'tree' }
                        else { $ruNo = $ruOutside + 'tree window (reuse_tree_within_minutes ' + [string]$ruTreeMinutes + ')' }
                    } elseif ($ruAge.TotalMinutes -le $ru.minutes) { $ruWin = 'head' }
                    else {
                        $ruTreeNo = ''
                        if (-not $ruTreeDeclared) { $ruTreeNo = 'no instrument_inputs_except list was handed to the decision' }
                        elseif (-not $ruTreeFigure) { $ruTreeNo = 'HEAD''s input tree is not derivable (' + (ConvertTo-ManifestDisplayText -Text ([string]$ru.inputTreeWhy) -Max 300) + ')' }
                        elseif (-not $ruCap.keys.ContainsKey('input_tree')) { $ruTreeNo = 'it carries no input_tree: (it was not taken under the goal''s instrument_inputs_except)' }
                        elseif ([string]$ruCap.keys['input_tree'] -cnotmatch '\A[0-9a-f]{64}\z') { $ruTreeNo = 'its input_tree is not a figure' }
                        elseif ([string]$ruCap.keys['input_tree'] -cne $ruTreeFigure) { $ruTreeNo = 'its input_tree ' + [string]$ruCap.keys['input_tree'] + ' is not HEAD''s ' + $ruTreeFigure }
                        $ruHeadOutside = $ruOutside + 'HEAD window (reuse_within_minutes ' + [string]$ru.minutes + ')'
                        if ($ruTreeNo) { $ruNo = $ruHeadOutside + '; its input tree does not admit it to the tree window (' + $ruTreeNo + ')' }
                        elseif ($ruAge.TotalMinutes -le $ruTreeMinutes) { $ruWin = 'tree' }
                        else { $ruNo = $ruHeadOutside + ' and the tree window (reuse_tree_within_minutes ' + [string]$ruTreeMinutes + ')' }
                    }
                }
                elseif ($ruAge.TotalMinutes -gt $ru.minutes) { $ruNo = 'it is ' + [string][int][Math]::Floor($ruAge.TotalMinutes) + ' minute(s) old, outside the window' }
            }
            if ($ruNo) { $ruWhy.Add($ruFile.Name + ': ' + $ruNo); continue }
            if (($null -eq $ruBest) -or ($ruAt -gt $ruBest.at)) {
                $ruBest = [pscustomobject]@{ path = $ruFile.FullName; cap = $ruCap; at = $ruAt; age = $ruAge; exit = [int]$ruCap.keys['exit_code']; byTree = $ruByTree; head = [string]$ruCap.keys['head']; window = $ruWin }
            }
        }
        if ($null -eq $ruBest) {
            $ruShown = @($ruWhy.ToArray() | Select-Object -First 3)
            $ru.note = $ruLead + [string]$ruFiles.Count + ' capture(s) of this instrument considered, none passes: ' + ($ruShown -join '; ') + $(if ($ruWhy.Count -gt 3) { '; and ' + [string]($ruWhy.Count - 3) + ' more' } else { '' }) + '.'
            return $ru
        }
        # RULE (ii): A RED IS NEVER REUSED, AND NEVER STEPPED OVER -- asked HERE, of the capture chosen, after
        # the choice and BEFORE the keep below, so a RED capture is never copied and never named as reused. In
        # the per-capture chain a RED newest capture would merely be skipped, and the OLDER GREEN behind it
        # chosen and reused: a stale GREEN past a newer RED, which is the thing ruled out.
        # (1) THE CAPTURE CHOSEN DID NOT EXIT 0: it is re-measured. No older capture is fallen back on.
        if ([int]$ruBest.exit -ne 0) {
            $ru.note = $ruLead + 'the newest capture that passes, ' + [System.IO.Path]::GetFileName([string]$ruBest.path) + ' sha256 ' + [string]$ruBest.cap.sha256 + ', exited ' + [string]$ruBest.exit + ': a reading that is not exit 0 is never reused, it is re-measured (register row 412).'
            return $ru
        }
        # (2) A RED READING OF THIS INSTRUMENT WAS TAKEN AFTER IT -- strictly after: an equal captured_at is not
        # "after", and a RED before the capture chosen stops nothing. Of several, the latest is the one named.
        $ruLater = $null
        foreach ($ruRed in $ruReds) {
            if (($ruRed.at -gt $ruBest.at) -and (($null -eq $ruLater) -or ($ruRed.at -gt $ruLater.at))) { $ruLater = $ruRed }
        }
        if ($null -ne $ruLater) {
            $ru.note = $ruLead + 'a later reading of this instrument, ' + [string]$ruLater.name + ' sha256 ' + [string]$ruLater.sha256 + ' captured_at ' + (ConvertTo-ManifestDisplayText -Text ([string]$ruLater.said) -Max 48) + ', exited ' + [string]$ruLater.exit +
                       ' after the capture that passes (' + [System.IO.Path]::GetFileName([string]$ruBest.path) + '): a RED is never stepped over, it is re-measured (register row 412).'
            return $ru
        }
        # (3) RULE (iii): AN UNDATABLE CAPTURE OF THIS INSTRUMENT STANDS AMONG THE CANDIDATES -- asked after the RED rule's
        # two refusals and BEFORE the keep, so nothing is copied or named as reused. The first is named (its file,
        # its sha256, why, the line as written) and the rest counted; the capture that would have been reused too.
        if ($ruUndatable.Count -gt 0) {
            $ruUndated = $ruUndatable[0]
            $ruUndatedSaid = if ($ruUndated.said) { ConvertTo-ManifestDisplayText -Text ([string]$ruUndated.said) -Max 48 } else { 'absent' }
            $ru.note = $ruLead + 'an undatable capture of this instrument stands among the candidates, ' + [string]$ruUndated.name + ' sha256 ' + [string]$ruUndated.sha256 + ': ' + [string]$ruUndated.why + ' (' + $ruUndatedSaid + ')' +
                       $(if ($ruUndatable.Count -gt 1) { '; and ' + [string]($ruUndatable.Count - 1) + ' more' } else { '' }) +
                       ' -- it cannot be placed before or after the capture that passes, ' + [System.IO.Path]::GetFileName([string]$ruBest.path) + ', so it is never stepped over; the instrument is re-measured (register row 423).'
            return $ru
        }
        # KEPT BEFORE IT IS NAMED. The capture that passed is copied content-addressed beside itself,
        # from the bytes its sha256 was computed over, before anything says "reused" -- the detail below, the
        # two verdict keys and the artifact are all written after this line. Where the copy cannot be made,
        # or its name is taken by other bytes, NOTHING IS REUSED and the instrument runs: a reading is cited
        # only once the bytes cited are on disk under a name the next evaluation does not rewrite.
        $ruKeep = Save-InstrumentReusedCapture -Path ([string]$ruBest.path) -Bytes $ruBest.cap.raw -Sha256 ([string]$ruBest.cap.sha256)
        if (-not $ruKeep.ok) {
            $ru.note = $ruLead + 'the capture that passes, ' + [System.IO.Path]::GetFileName([string]$ruBest.path) + ' sha256 ' + [string]$ruBest.cap.sha256 + ', could not be kept beside it -- ' + [string]$ruKeep.why + ' -- and a reading is cited only once its bytes are kept (register row 391).'
            return $ru
        }
        $ru.reused = $true
        $ru.exit = [int]$ruBest.exit
        $ru.path = [string]$ruBest.path
        $ru.sha256 = [string]$ruBest.cap.sha256
        $ru.kept = [string]$ruKeep.path
        # WHERE THE FIGURE ADMITTED IT -- the capture's head is not HEAD -- the detail says so
        # between "HEAD <sha>" and the tree-clean clause: the capture's OWN head, the figure, and how many
        # paths the goal's list holds. A capture at HEAD itself adds nothing: the detail is what it was.
        $ruByTreeSaid = ''
        if ($ruBest.byTree) {
            $ru.byInputTree = $true
            $ru.captureHead = [string]$ruBest.head
            $ruByTreeSaid = ' (the capture''s head is ' + $ru.captureHead + '; ADMITTED BY ITS INPUT TREE: input_tree ' + $ruTreeFigure + ' over the head''s tree less the goal''s ' + [string]@($InputsExcept).Count + ' instrument_inputs_except path(s) equals HEAD''s -- register row 412)'
        }
        # WHERE THE TREE WINDOW IS DECLARED, THE WINDOW THAT ADMITTED IT -- named after the by-tree words and
        # before the tree-clean clause, and handed back for the verdict's instrument_reuse_window_admitted. Not
        # bound, nothing is added and the detail is what it was.
        $ruWindowSaid = ''
        if ($ruTreeWindow) {
            $ru.window = [string]$ruBest.window
            if ($ru.window -ceq 'tree') { $ru.windowMinutes = $ruTreeMinutes; $ruWindowSaid = '; ADMITTED BY THE TREE WINDOW (reuse_tree_within_minutes ' + [string]$ruTreeMinutes + ')' }
            else { $ru.windowMinutes = $ru.minutes; $ruWindowSaid = '; ADMITTED BY THE HEAD WINDOW (reuse_within_minutes ' + [string]$ru.minutes + ')' }
        }
        $ru.detail = 'REUSED A FRESH READING, the instrument was NOT run in this evaluation (register row 368; reuse_within_minutes ' + [string]$ru.minutes + '): capture ' + $ru.path + ' sha256 ' + $ru.sha256 +
                     ', captured_at ' + [string]$ruBest.cap.keys['captured_at'] + ' (' + [string][int][Math]::Floor($ruBest.age.TotalMinutes) + ' min ' + [string]$ruBest.age.Seconds + ' s old), HEAD ' + $ruHead + $ruByTreeSaid + $ruWindowSaid +
                     ', the tree clean apart from the mission''s declared set when it was taken and now (verify''s own predicate), instrument sha256 ' + $ruNowSha + '.' +
                     ' THE CAPTURE CITED IS KEPT at ' + $ru.kept + ' (' + [string]$ruKeep.how + '; register row 391).'
        return $ru
    } catch {
        $ru.reused = $false
        $ru.byInputTree = $false
        $ru.note = $ruLead + 'the reuse check threw (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + ').'
        # (HEAD's figure, where it was derived before the throw, is still handed back; where it was not, say so.)
        if ((-not $ru.inputTree) -and (-not $ru.inputTreeWhy)) { $ru.inputTreeWhy = 'the reuse check threw before the figure was derived' }
        return $ru
    }
}

function Invoke-Detector {
    param($D)
    $type = [string]$D['type']
    switch ($type) {

        'instrument_exit0' {
            $pRaw = [string]$D['path']
            if (-not $pRaw) { return @{ ok = $false; detail = "instrument_exit0 has no 'path'" } }
            $p = Resolve-DetectorPath -MissionRoot $MissionRoot -Path $pRaw
            if (-not (Test-Path -LiteralPath $p)) { return @{ ok = $false; detail = "instrument not on disk: $p" } }
            # THE ORDINAL SURVIVES THE MOVE. One goal may declare MORE THAN ONE instrument_exit0,
            # and the shared helper keys its files on RunKey/Goal + the instrument's LEAF NAME --
            # which separates two detectors over different instruments and does NOT separate two
            # over the SAME instrument. Folding this counter into the RunKey restores the guarantee
            # the private capture had, using the parameter the helper provides for it, and without
            # touching the helper. The first detector keeps the plain key (so the common
            # single-detector goal gets the plainest filename); the second and later carry their
            # ordinal, exactly as the private capture's ".2.txt" did.
            if ($null -eq $script:InstrumentCaptureSeq) { $script:InstrumentCaptureSeq = 0 }
            $script:InstrumentCaptureSeq++
            # Built by CONCATENATION, never by "$Goal.$n": in a double-quoted string a `.` after a
            # variable is the property-access operator, and a key that silently became something
            # else would put the second detector's transcript back on top of the first's.
            $runKey = [string]$Goal
            if ($script:InstrumentCaptureSeq -gt 1) {
                $runKey = ([string]$Goal + '.' + [string]$script:InstrumentCaptureSeq)
            }
            # THE THREE KEYS OF BATCH-5 ARE HELD TO THEIR RULES HERE, at the head of the
            # arm -- after the ordinal has advanced, so a later detector keeps its own key whatever this one
            # does, and BEFORE the reuse question, so a key this file cannot read is never passed over by a
            # reuse. PRESENCE IS ContainsKey, as the window's is -- never the truthiness this arm asks of
            # `path`, under which `engine_read:` with nothing after its colon would read as absent. Each
            # refusal FAILS the detector by name: nothing is reused, nothing is read, nothing is launched and
            # nothing is written. A goal that declares none of the three enters nothing here.
            # THE ENGINE's TWO KEYS FIRST, in the order the row lists its four refusals.
            $engineRead = ''
            $engineFault = ''
            if ($D.ContainsKey('engine_read')) {
                $engineRead = [string]$D['engine_read']
                if (@('docker_pipe', 'docker_pipe_then_version') -cnotcontains $engineRead) {
                    return @{ ok = $false; detail = "instrument_exit0's engine_read '" + (ConvertTo-ManifestDisplayText -Text $engineRead -Max 60) + "' is not a read this evaluator makes (docker_pipe, docker_pipe_then_version): the instrument was NOT run (register row 264)." }
                }
            }
            if ($D.ContainsKey('engine_read_fault')) {
                if (-not $D.ContainsKey('engine_read')) {
                    return @{ ok = $false; detail = 'instrument_exit0 declares engine_read_fault without engine_read: the instrument was NOT run (register row 264).' }
                }
                $engineFault = [string]$D['engine_read_fault']
                if (@('pipe_absent', 'version_exit', 'version_silent') -cnotcontains $engineFault) {
                    return @{ ok = $false; detail = "instrument_exit0's engine_read_fault '" + (ConvertTo-ManifestDisplayText -Text $engineFault -Max 60) + "' is not a fault this evaluator injects (pipe_absent, version_exit, version_silent): the instrument was NOT run (register row 264)." }
                }
                if (($engineRead -ceq 'docker_pipe') -and ($engineFault -cne 'pipe_absent')) {
                    return @{ ok = $false; detail = "instrument_exit0's engine_read_fault '" + $engineFault + "' does not apply to engine_read docker_pipe, which makes no docker version read: the instrument was NOT run (register row 264)." }
                }
            }
            # ... THEN THE LIST OF WHAT IS NOT AN INPUT: one the list reader refuses,
            # or an item that is not a repository-relative path, fails this detector -- it is never a goal
            # that does not parse, and never a fall back to "no list", which would reuse by head alone and
            # launch without the figure.
            $inputsDeclared = $D.ContainsKey('instrument_inputs_except')
            $inputsExcept = [string[]]@()
            $inputsSaid = ''
            if ($inputsDeclared) {
                $inputsList = ConvertFrom-GoalInlineList -Text ([string]$D['instrument_inputs_except'])
                if (-not $inputsList.ok) {
                    return @{ ok = $false; detail = "instrument_exit0's instrument_inputs_except is not an inline list ($($inputsList.why)): the instrument was NOT run (register row 397)." }
                }
                $inputsFault = Get-GoalInputsExceptFault -Items ([string[]]@($inputsList.items))
                if ($null -ne $inputsFault) {
                    return @{ ok = $false; detail = "instrument_exit0's instrument_inputs_except item '" + (ConvertTo-ManifestDisplayText -Text ([string]$inputsFault.item) -Max 200) + "' is not a repository-relative path this evaluator reads (" + [string]$inputsFault.reason + '): the instrument was NOT run (register row 397).' }
                }
                $inputsExcept = [string[]]@($inputsList.items)
                # What the verdict's instrument_inputs_except item opens with: the leaf, and the list as it was read.
                $inputsSaid = (Split-Path -Leaf $p) + ': except [' + (@($inputsExcept | ForEach-Object { ConvertTo-ManifestDisplayText -Text ([string]$_) -Max 200 }) -join ', ') + ']; input_tree at HEAD '
            }
            # ... AND THE TREE WINDOW's KEY (ruled 2026-10-16 07:2x local, lean accepted, Q5 (i)), held to
            # its two refusals here, after the list's and in the same form: each FAILS this detector by name -- nothing
            # is read, reused or launched. Its value is a number by the one whole-number rule, taken before any detector runs; the
            # decision reads it, bound only where the key is declared.
            $treeWindowDeclared = $D.ContainsKey('reuse_tree_within_minutes')
            if ($treeWindowDeclared) {
                if (-not $inputsDeclared) {
                    return @{ ok = $false; detail = 'instrument_exit0 declares reuse_tree_within_minutes without instrument_inputs_except -- a tree window has no input tree to admit by: the instrument was NOT run (register row 438).' }
                }
                if (-not (ConvertTo-GoalWholeNumber -Text ([string]$D['reuse_within_minutes']) -Min 1).ok) {
                    return @{ ok = $false; detail = 'instrument_exit0 declares reuse_tree_within_minutes without reuse_within_minutes above 0 -- a tree window has no reuse to widen: the instrument was NOT run (register row 438).' }
                }
            }
            # THE ENGINE READ -- MOVED HERE (BATCH-6 WP-Q (a); the operator's ruling (b) of
            # 21:49 local; ruled 2026-10-16 07:2x local, lean accepted, Q4 among them): after every refusal above and
            # BEFORE ANY REUSE DECISION, so a declared engine_read is made at every INVOKED evaluation of this detector,
            # reuse or launch, and the outcome follows it. (Until this move it was made only where the instrument was
            # about to be launched, after the reuse question: a goal that declared engine_read read MET by reuse with
            # the engine down.) Every read made is an item of the verdict's key, up or down. DOWN, the detector
            # answers here: nothing is reused, no capture is written and the helper is not called. A listing that
            # throws is not caught here: it fails this detector in the loop's own catch. UP: the reuse question below,
            # as before, and on a reuse the read stands beside it.
            # THE DOWN DETAIL: "<leaf> NOT RUN: engine down -- <words> (engine_read <v>; <a record id>)." and,
            # where a window above 0 is declared, " reuse_within_minutes <N>: no reuse question was asked -- the engine
            # read answered down before any reuse decision (<a record id>)."; no reuse question precedes a DOWN, so
            # no reuse note follows it. The list's item, where the list is declared, says why HEAD was not read: that
            # same answer where such a window is declared; elsewhere the words it had, byte for byte --
            # "reuse_within_minutes is 0, and nothing is ever reused" where a window of 0 would have been asked, "no
            # reuse question was asked" where none would.
            if ($engineRead) {
                $engine = Get-InstrumentEngineRead -Leaf (Split-Path -Leaf $p) -Read $engineRead -Fault $engineFault
                foreach ($engineItem in @($engine.items)) { $script:InstrumentEngineReads += [string]$engineItem }
                if (-not $engine.up) {
                    $engineWindow = ConvertTo-GoalWholeNumber -Text ([string]$D['reuse_within_minutes']) -Min 1
                    if ($inputsDeclared) {
                        $engineHeadWhy = 'no reuse question was asked'
                        if ($engineWindow.ok) { $engineHeadWhy = 'the engine read answered down before the reuse question' }
                        elseif ($D.ContainsKey('reuse_within_minutes') -and (-not $D.ContainsKey('engine_read_fault'))) { $engineHeadWhy = 'reuse_within_minutes is 0, and nothing is ever reused' }
                        $script:InstrumentInputsExceptSaid += ($inputsSaid + 'not derivable (HEAD was not read: ' + $engineHeadWhy + ')')
                    }
                    $engineTail = ''
                    if ($engineWindow.ok) { $engineTail = ' reuse_within_minutes ' + [string]$engineWindow.value + ': no reuse question was asked -- the engine read answered down before any reuse decision (register row 438).' }
                    return @{ ok = $false; detail = "$(Split-Path -Leaf $p) NOT RUN: engine down -- $($engine.words) (engine_read $engineRead; register row 264).$engineTail" }
                }
            }
            # A FRESH READING MAY BE REUSED, AND ONLY WHERE THIS DETECTOR SAYS SO. The key
            # absent, this block is not entered and everything below is what it was; the key 0, the
            # question is asked and answered "never" with no note, so the detail is byte for byte the
            # same. It sits AFTER the ordinal has advanced, so a later detector keeps its own key
            # whether or not this one ran its instrument. On reuse the detector answers here: the
            # helper is not called and no NEW capture is written, because no instrument was run -- the
            # capture cited is copied beside itself first, and that copy is named too.
            # A DETECTOR CARRYING engine_read_fault ASKS NO REUSE QUESTION AT ALL, window or not --
            # the seam's read can only answer DOWN, and a goal carrying it never reads MET through this entry.
            # Where the list is declared the decision is handed it, derives HEAD's figure and hands
            # that back on every return; the verdict's item is written from it HERE, reuse or not. Where no
            # question is asked, or the decision read no HEAD, there is no figure and the item says which.
            $reuseNote = ''
            $reuseNoteNotLaunched = ''
            if ($D.ContainsKey('reuse_within_minutes') -and (-not $D.ContainsKey('engine_read_fault'))) {
                # A third shape of the one call, binding -TreeRaw where the tree window is declared (and the
                # list with it: the refusals above stand between); the other two are the calls they were.
                if ($treeWindowDeclared) { $reuse = Get-InstrumentReuseDecision -TreeRaw ([string]$D['reuse_tree_within_minutes']) -InputsExcept $inputsExcept -MissionRoot $MissionRoot -InstrumentPath $p -Raw ([string]$D['reuse_within_minutes']) }
                elseif ($inputsDeclared) { $reuse = Get-InstrumentReuseDecision -InputsExcept $inputsExcept -MissionRoot $MissionRoot -InstrumentPath $p -Raw ([string]$D['reuse_within_minutes']) }
                else { $reuse = Get-InstrumentReuseDecision -MissionRoot $MissionRoot -InstrumentPath $p -Raw ([string]$D['reuse_within_minutes']) }
                if ($inputsDeclared) {
                    $script:InstrumentInputsExceptSaid += ($inputsSaid + $(if ($reuse.inputTree) { [string]$reuse.inputTree } else { 'not derivable (' + (ConvertTo-ManifestDisplayText -Text ([string]$reuse.inputTreeWhy) -Max 300) + ')' }))
                }
                if ($reuse.reused) {
                    $script:InstrumentCapturesReused += ([string]$reuse.path + ' sha256 ' + [string]$reuse.sha256)
                    # The kept copy named beside it, under its own key -- the entry above is unchanged.
                    $script:InstrumentCapturesKept += ([string]$reuse.kept + ' sha256 ' + [string]$reuse.sha256)
                    # And, where the figure admitted it, the match -- the capture, the figure, both heads.
                    if ($reuse.byInputTree) {
                        $script:InstrumentInputTreeMatched += ([string]$reuse.path + ' input_tree ' + [string]$reuse.inputTree + ' capture_head ' + [string]$reuse.captureHead + ' head ' + [string]$reuse.head)
                    }
                    # And, where the tree window is declared, the window that admitted it and its own minutes.
                    if ($treeWindowDeclared) {
                        $script:InstrumentReuseWindowAdmitted += ([string]$reuse.path + ' sha256 ' + [string]$reuse.sha256 + ' window ' + [string]$reuse.window + ' minutes ' + [string]$reuse.windowMinutes)
                    }
                    return @{ ok = ($reuse.exit -eq 0); detail = "$(Split-Path -Leaf $p) exited $($reuse.exit) (require 0). $($reuse.detail)" }
                }
                $reuseNote = [string]$reuse.note
                # BESIDE THE ENGINE READ (the independent validator's round 1, a finding): THE SAME NOTE IN THE
                # WORDS THAT ARE TRUE WHERE THIS DETECTOR IS THEN NOT LAUNCHED. Every note says the instrument
                # was run, and it is -- unless the engine read below answers DOWN. The decision hands back the
                # words its note opens with and the words that take their place where there was no launch;
                # what follows them, the REASON nothing was reused, is kept as it is. (A note that did not
                # open with its own lead would not be quoted: the tail would then say that nothing was
                # reused and nothing launched, and no more. No note the decision writes is one.)
                # THE ENGINE READ NOW STANDS ABOVE THIS QUESTION, so a detector here read UP or
                # declares none, and is launched: $reuseNoteNotLaunched is composed and then read by nothing on
                # this path. Kept: no code is removed here, and the decision's two leads stay.
                if ($reuseNote) {
                    $reuseLead = [string]$reuse.noteLead
                    if ($reuseLead -and $reuseNote.StartsWith($reuseLead, [System.StringComparison]::Ordinal)) { $reuseNoteNotLaunched = [string]$reuse.noteLeadNotLaunched + $reuseNote.Substring($reuseLead.Length) }
                    else { $reuseNoteNotLaunched = ' reuse_within_minutes: nothing was reused, and the instrument was not launched (register row 368).' }
                }
            } elseif ($inputsDeclared) {
                $script:InstrumentInputsExceptSaid += ($inputsSaid + 'not derivable (HEAD was not read: no reuse question was asked)')
            }
            # THE ENGINE READ STOOD HERE, where the instrument is about to be launched, until it was
            # moved above the reuse question (BATCH-6 WP-Q (a); the operator's ruling (b) of 21:49 local): a
            # detector that reaches this line read UP, or declares no engine_read.
            # SAVED AS $prev, NEVER AS $p: PowerShell variable names FOLD CASE, so a saved
            # ErrorActionPreference called $p IS the instrument path resolved two lines up. The one
            # NATIVE call moved into the helper, which saves and restores its own preference around
            # it (and names its saved value $prevEap, for this same reason). This guard stays: the
            # planted-revert kill in tests/lam/instrument-WP-3.ps1 puts a native call back on the
            # line below, and it must run under the same preference it ran under before.
            $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try {
                # THE `$null =` IS LOAD-BEARING AND IT IS NOT COSMETIC. Invoke-Detector answers by
                # RETURNING @{ ok = ...; detail = ... }, and in PowerShell every unassigned,
                # unsuppressed expression in a function lands on that same output stream. Without
                # the suppression this call's [pscustomobject] is emitted too and the detector
                # answers with an ARRAY whose [0] is the helper's result -- $r['ok'] then reads
                # $null, every detector reports FAILED, and a MET goal reads NOT_MET. Measured at
                # the base of this item by dropping it.
                # TWO SHAPES OF THE ONE CALL, AND THE SECOND IS THE LINE IT ALWAYS WAS. Where the
                # detector declares instrument_inputs_except the helper is handed the list -- the new
                # parameter FIRST on its line, so the old line's text is no part of it -- and the capture
                # then carries input_tree. Where it does not, the call is the old one, to the letter: other
                # instruments find that line by its text and plant a revert on it. `$null =` stands on
                # both, for the reason above, and NOTHING native stands between either and the line that
                # reads the exit code (contract (a)). The first shape's contract (a) is measured by one
                # row (a stub exiting 3 through it); it carries no planted-revert kill of its own.
                if ($inputsDeclared) {
                    $null = Save-LamInstrumentRun -InstrumentInputsExcept $inputsExcept -InstrumentPath $p -MissionRoot $MissionRoot -RunKey $runKey -Goal $Goal
                } else {
                    $null = Save-LamInstrumentRun -InstrumentPath $p -MissionRoot $MissionRoot -RunKey $runKey -Goal $Goal
                }
                # CONTRACT (a): the helper's LAST act is `$global:LASTEXITCODE = <instrument exit>`
                # and it runs NOTHING NATIVE after it, so this line reads the instrument's own code.
                # Anything native inserted between these two lines destroys the verdict input.
                $code = $LASTEXITCODE
            } finally { $ErrorActionPreference = $prev }
            if ($null -eq $code) { $code = 1 }
            # THE CAPTURE PATH IS DERIVED, NOT READ BACK. The call above is suppressed, so the
            # helper's returned object is unreachable here by construction -- which is exactly what
            # contract (g) exists for: Get-LamInstrumentRunPath is the ONE derivation of the
            # filename and both callers compute it from what they already hold.
            #
            # DEGRADES TO A NOTE, NEVER TO AN EXCEPTION. The helper itself cannot throw (contract
            # (b)), but these two cmdlets run under this file's 'Stop' preference and a malformed
            # path would take a GREEN instrument's whole evaluation down. The old wrapper existed
            # for this reason and it is kept for it.
            $capNote = ''
            try {
                $capPath = (Get-LamInstrumentRunPath -MissionRoot $MissionRoot -InstrumentPath $p `
                                                     -RunKey $runKey -Goal $Goal).stdout
                if (Test-Path -LiteralPath $capPath) {
                    $capNote = " Instrument output kept at $capPath."
                } else {
                    $capNote = " Instrument output was NOT PERSISTED -- nothing is on disk at $capPath."
                }
            } catch {
                $capNote = " Instrument output CAPTURE PATH UNRESOLVABLE and is recorded here rather than thrown -- $(($_.Exception.Message -replace '[\r\n]+', ' '))"
            }
            # THE VERDICT IS UNMOVED. ok is ($code -eq 0) for every input, exactly as before and
            # exactly as it was before the capture existed at all; this row moves an artifact, it
            # does not change a decision.
            return @{ ok = ($code -eq 0); detail = "$(Split-Path -Leaf $p) exited $code (require 0).$capNote$reuseNote" }
        }

        'verify_pass_or_dib' {
            # LAM-ACCEPT C-1 as amended. The PASS-DIB definition is NOT restated here -- it comes
            # from the one shared file, so a future verify that implements suite execution starts
            # binding all three members in the runner and in this evaluator at the same instant.
            # The existence check below ran at the PROCESS cwd while the execution further down runs
            # after `Push-Location $MissionRoot` -- two statements about one file that meant two
            # different directories (V-1 round 5, WP-3). Resolving once makes them agree.
            # Resolve-DetectorPath returns its argument unchanged when falsy, so the default below
            # is reached exactly as before when no path is declared.
            $p = Resolve-DetectorPath -MissionRoot $MissionRoot -Path ([string]$D['path'])
            if (-not $p) { $p = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\mission-verify.ps1' }
            if (-not (Test-Path -LiteralPath $p)) { return @{ ok = $false; detail = "verify not on disk: $p" } }
            $against = [string]$D['against']
            $kind    = [string]$D['dispatch_kind']
            # THE EVALUATOR ADMITS THE ADVANCE THE RUNNER
            # ADMITS. Get-LamVerifyVerdict tests the advance admission -- ancestry, cleanliness, provenance,
            # R-1's companion admission -- only when it is given the mission root and the RECORDED head_sha of
            # the anchors verify ran against ("Without a mission root and a recorded sha to test against, they
            # are simply not admitted"). This detector passed neither, so every advance read REFUSE and a goal
            # could never read MET once HEAD had moved past the anchors it names -- which every close does.
            # Measured live against a dispatch's .anchors.yaml file
            # while the runner had admitted the same advance at spawn seq 134 with the same library. The
            # recorded head is read from the SAME file verify is pointed at, never from a second source; a
            # basis that carries no head_sha (or no basis named) leaves the call as it was, and the refusal
            # stands. Driven by WP-3 member C-1i: the cure, the planted-revert kill, the drift control.
            $recordedHead = $null
            if ($against) {
                $againstPath = Resolve-DetectorPath -MissionRoot $MissionRoot -Path $against
                if ($againstPath -and (Test-Path -LiteralPath $againstPath -PathType Leaf)) {
                    $againstText = [System.IO.File]::ReadAllText($againstPath)
                    if ($againstText -match '(?m)^\s+head_sha:[ \t]*([0-9a-fA-F]{40})[ \t]*\r?$') { $recordedHead = $Matches[1] }
                }
            }
            $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try {
                Push-Location $MissionRoot     # verify resolves its repo root from cwd first
                try {
                    if ($against -and $kind) { $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $p --against $against --dispatch-kind $kind 2>&1 }
                    elseif ($against)        { $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $p --against $against 2>&1 }
                    else                     { $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $p 2>&1 }
                    $code = $LASTEXITCODE
                } finally { Pop-Location }
            } finally { $ErrorActionPreference = $prev }
            $verifyText = ((@($out) | ForEach-Object { "$_" }) -join "`n")
            if ($recordedHead) { $v = Get-LamVerifyVerdict -VerifyOutput $verifyText -ExitCode $code -MissionRoot $MissionRoot -RecordedHeadSha $recordedHead }
            else               { $v = Get-LamVerifyVerdict -VerifyOutput $verifyText -ExitCode $code }
            $ok = ($v.verdict -eq 'PASS') -or ($v.verdict -eq 'PASS-DIB')
            $adm = if ($v.admitted.Count -gt 0) { " admitted: $($v.admitted -join ', ')" } else { '' }
            return @{ ok = $ok; detail = "mission verify exited $code -> $($v.verdict).$adm $($v.reason)" }
        }

        'validator_pass_count' {
            $dir = Resolve-DetectorPath -MissionRoot $MissionRoot -Path ([string]$D['dir'])
            if (-not $dir) { $dir = Join-Path $MissionRoot 'tests\lam' }
            $need = 1
            # `count` through the one whole-number rule. It went to TryParse with the answer thrown
            # away, so a value that was no number asked for NO result and the detector passed. From a goal
            # file such a value never arrives now (the goal does not parse); reached otherwise, it FAILS.
            if ($D.ContainsKey('count')) {
                $needParsed = ConvertTo-GoalWholeNumber -Text ([string]$D['count']) -Min 1
                if (-not $needParsed.ok) { return @{ ok = $false; detail = "validator_pass_count 'count' is not a whole number from 1 to 999999 (register row 385)" } }
                $need = $needParsed.value
            }
            $pat = [string]$D['pattern']; if (-not $pat) { $pat = 'validator-*.result.yaml' }
            # THE ROSTER, BY ONE PATTERN OR BY A LIST OF THEM (the block above ConvertFrom-GoalInlineList).
            # With no `patterns` key this is the one pattern it always was, asked once, in the order
            # Get-ChildItem answers.
            $pats = @($pat)
            if ($D.ContainsKey('patterns')) {
                if ($D.ContainsKey('pattern')) {
                    return @{ ok = $false; detail = "validator_pass_count declares both 'pattern' and 'patterns': a roster is read through one of them, and which one is not guessed (register row 392)" }
                }
                $patList = ConvertFrom-GoalInlineList -Text ([string]$D['patterns'])
                if (-not $patList.ok) {
                    return @{ ok = $false; detail = "validator_pass_count 'patterns' is not an inline list of patterns -- $($patList.why) -- and the default pattern is never read in its place (register row 392)" }
                }
                # RULE 2: AN ITEM IS ONE FILE-NAME PATTERN. The list reader splits at commas and
                # reads nothing else of an item's text, and -Filter then took whatever it was handed: an item
                # holding a bracket matched nothing and nothing said so, and one holding a separator was
                # FOLLOWED OUT OF THE ROSTER'S DIRECTORY -- `sub/x.yaml` counted a result one level down.
                # The first item holding any one of [ ] / \ FAILS this detector by name, as a malformed list
                # does; nothing is counted. The item is printed as the list reader hands it.
                foreach ($patItem in @($patList.items)) {
                    if (([string]$patItem).IndexOfAny([char[]]@('[', ']', '/', '\')) -ge 0) {
                        return @{ ok = $false; detail = "validator_pass_count's patterns item '" + (ConvertTo-ManifestDisplayText -Text ([string]$patItem) -Max 200) + "' holds a bracket or a path separator: an item is one file-name pattern (register row 397)." }
                    }
                }
                $pats = @($patList.items)
            }
            # SESSION-LAW AMENDMENT 3a. A PASS is counted only if the file's sha256 matches a
            # COMPLETED spawn-ledger line -- that is, only if this session spawned the thing that
            # produced it. Presence was the whole of the old test, and presence is precisely what a
            # concurrent writer forged: ten unattributed artifacts appeared at exactly these paths,
            # five asserting PASS, none of them malformed. An unledgered file here is FOREIGN and
            # FAILS the detector; it is never silently ignored and never counted.
            # THE STOPPING RULE: A REFUTED RESULT COUNTS AS COMPLETE
            # WHEN AN OPERATOR HAS ACCEPTED ITS REGISTERED RESIDUALS -- and it is admitted LOUDLY.
            # Three conditions, all three or none: (1) the result is ledger-bound exactly as a PASS
            # must be; (2) an unrevoked, unconsumed `completion-acceptance-*.yaml` gate exists under
            # the mission's gates directory whose binds_sha256 is the sha256 of
            # docs/framework/LAM-RESIDUALS.md ON DISK NOW -- so an edited manifest un-accepts every
            # package without anyone revoking anything; (3) that manifest carries at least one
            # `### RES-nn [WP-x]` heading for the package. The detail then names every package as
            # PASS or ACCEPTED-WITH-RESIDUALS with its residual count and gate file, because an
            # acceptance a reader cannot see on the verdict's face is the same hole one layer down.
            $manifestPath = Join-Path $MissionRoot 'docs\framework\LAM-RESIDUALS.md'
            $manifestSha = $null; $manifestText = ''
            if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
                $manifestSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()
                $manifestText = [System.IO.File]::ReadAllText($manifestPath)
            }
            $acceptGate = $null
            $gatesDirD = Join-Path $MissionRoot '.mission\gates'
            if ($manifestSha -and (Test-Path -LiteralPath $gatesDirD)) {
                foreach ($gf in @(Get-ChildItem -LiteralPath $gatesDirD -File -Filter 'completion-acceptance-*.yaml' -ErrorAction SilentlyContinue)) {
                    $gt = [System.IO.File]::ReadAllText($gf.FullName)
                    # THE SHARED READER, NOT A LOCAL REGEX. This test carried
                    # BOTH of the defects this repository has already cured three times: `-notmatch`
                    # is case-INSENSITIVE, so a gate declaring `kind: COMPLETION-ACCEPTANCE`
                    # satisfied it; and it asked whether such a line existed ANYWHERE, so an
                    # artifact whose FIRST top-level kind was something else still matched on a
                    # later line. Get-LamGateClassForArtifact captures the FIRST top-level kind --
                    # which is what settle, revoke, list and gate_present each see -- and
                    # Resolve-LamGateKind applies the one case rule to it.
                    if ((Resolve-LamGateKind -Kind (Get-LamGateClassForArtifact -Path $gf.FullName).kind) -cne 'completion-acceptance') { continue }
                    $gs = Get-LamGateState -Path $gf.FullName
                    if ($gs.consumed -or $gs.revoked) { continue }
                    $bound = if ($gt -match '(?m)^binds_sha256:[ \t]*([0-9a-fA-F]{64})[ \t]*\r?$') { $Matches[1].ToLowerInvariant() } else { '' }
                    if ($bound -eq $manifestSha) { $acceptGate = $gf.Name; break }
                }
            }
            $found = 0; $names = @(); $foreign = @(); $accepted = @()
            if (Test-Path -LiteralPath $dir) {
                # The UNION of the patterns, each asked in the order written; a file a second
                # pattern matches again is read once, by its full path, case folded.
                $rosterFiles = New-Object System.Collections.Generic.List[object]
                $rosterSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($onePat in $pats) {
                    foreach ($rosterFile in @(Get-ChildItem -LiteralPath $dir -File -Filter $onePat -ErrorAction SilentlyContinue)) {
                        if ($rosterSeen.Add([string]$rosterFile.FullName)) { $rosterFiles.Add($rosterFile) }
                    }
                }
                foreach ($f in $rosterFiles) {
                    $t = [System.IO.File]::ReadAllText($f.FullName)
                    if ($t -match '(?m)^verdict:[ \t]*REFUTED[ \t]*\r?$') {
                        $pkg = if ($f.Name -match 'WP-(\d+)') { $Matches[1] } else { '' }
                        $resCount = if ($pkg -and $manifestText) { ([regex]::Matches($manifestText, '(?m)^### RES-\d+ \[WP-' + $pkg + '\]')).Count } else { 0 }
                        if ($acceptGate -and $resCount -gt 0) {
                            $bR = Test-LamLedgerBound -MissionRoot $MissionRoot -FilePath $f.FullName
                            if ($bR.bound) {
                                $found++
                                $accepted += "$($f.Name)=ACCEPTED-WITH-RESIDUALS($resCount residuals, gate $acceptGate)"
                            } else { $foreign += "$($f.Name) [$($bR.reason)]" }
                        }
                        continue
                    }
                    # TOP-LEVEL verdict only -- anchored at COLUMN 0, no leading whitespace.
                    # `^\s*verdict:` also matched the INDENTED per-member `verdict: PASS` lines
                    # inside a `members:` block, so a REFUTED result whose individual members mostly
                    # passed was counted as a PASS. Driven: with five REFUTED results on disk the
                    # detector reported "6 of 6 ... carry verdict PASS". A false PASS in the goal
                    # evaluator is the one failure this detector exists to make impossible, and it
                    # was masked until the ledger binding was fixed -- the FOREIGN failure was
                    # hiding it. YAML top-level keys sit at column 0; member keys are indented.
                    if ($t -notmatch '(?m)^verdict:[ \t]*PASS[ \t]*\r?$') { continue }
                    $b = Test-LamLedgerBound -MissionRoot $MissionRoot -FilePath $f.FullName
                    if ($b.bound) { $found++; $names += "$($f.Name)=PASS" }
                    else { $foreign += "$($f.Name) [$($b.reason)]" }
                }
            }
            $ok = ($found -ge $need) -and ($foreign.Count -eq 0)
            $detail = "$found of $need required validator result(s) are COMPLETE (PASS, or REFUTED accepted with registered residuals under amendment 23) AND provenance-bound to the spawn ledger in $dir [$(@($names + $accepted) -join ', ')]"
            if ($foreign.Count -gt 0) { $detail += ". FOREIGN (unledgered, NOT counted, detector FAILS): $($foreign -join ' ; ')" }
            return @{ ok = $ok; detail = $detail }
        }

        'gate_present' {
            $kind = [string]$D['kind']; $id = [string]$D['id']
            $p = Join-Path $MissionRoot ".mission\gates\$kind-$id.yaml"
            # THE SEVENTH PATH-TAKING INPUT, and the comment above Resolve-DetectorPath said there
            # were six (V-1 round 6, WP-3). This override was passed through raw, so a goal could
            # name a relative `path:` that resolved against the CWD -- and an independent reader
            # drove exactly that, satisfying one mission's gate detector with ANOTHER REPOSITORY'S
            # gate. Writing "six inputs, enumerated" in a comment did not make it six; it made the
            # miscount look authoritative.
            if ($D['path']) { $p = Resolve-DetectorPath -MissionRoot $MissionRoot -Path ([string]$D['path']) }
            # THE PREDICATE COMES FROM THE ONE SHARED DEFINITION (tools/lam/lam-gate-class.ps1).
            # It used to be restated here as `-notmatch '^\s*consumed_at:\s*\S'`, WITHOUT the
            # `(?!null)` that mission-gate.ps1's copy carried and explained. Every gate that tool
            # writes carries the literal `consumed_at: null`, and `null` is `\S` -- so this detector
            # reported a FRESH gate as consumed and could never pass on a real artifact. Dead on
            # arrival, and hidden because a hand-rolled fixture that omits the field takes the other
            # branch. Same class as the porcelain parameter no caller supplied.
            $gs = Get-LamGateState -Path $p
            $exists = $gs.exists
            $unconsumed = $exists -and (-not $gs.consumed)
            # A REVOKED GATE IS NOT A PRESENT ONE (V-1 round 3, WP-3 residual). This returned `ok`
            # for a gate whose own state the SAME LINE printed as REVOKED -- a detector contradicting
            # itself on its own face, which is the exact shape that makes a reader stop believing the
            # detail column. Revocation is the withdrawal mechanism for every gate kind and the ONLY
            # one for `supersession`, so a detector that ignores it can pass on a capability its
            # author has explicitly taken back.
            $revoked = $exists -and ($gs.state -eq 'REVOKED')
            # AND A DISQUALIFIED GATE IS NOT A PRESENT ONE EITHER (V-1 round 14, orchestrator
            # self-review while curing a WP-1 finding and a WP-4 finding). The gate's `witness_expired_at`
            # makes a gate unusable WITHOUT consuming or revoking it: the decider refuses it, and
            # this detector -- reading only `consumed` and `REVOKED` -- would have reported
            # exists=True, unconsumed=True, ok=True for a gate no push can spend.
            #
            # That is precisely the divergence being cured one layer up in this same batch, and it
            # would have been INTRODUCED HERE BY THAT CURE: adding a state to the shared predicate
            # silently widened what every consumer of it accepts (E70). The comment above already
            # said a self-contradicting detector is what makes readers stop believing the detail
            # column; it simply could not enumerate a state that did not exist when it was written.
            $disqualified = $exists -and ($gs.state -eq 'DISQUALIFIED')
            # THE KIND IS READ FROM THE ARTIFACT, NOT INFERRED FROM THE FILENAME THIS DETECTOR BUILT
            # (V-1 round 5 self-audit). The path above is composed as `<kind>-<id>.yaml`, and nothing
            # then asked whether the file found there DECLARES that kind -- so `gate_present kind:
            # dispatch id: X` was satisfied by a `dispatch-X.yaml` whose artifact said `kind: push`,
            # or said nothing at all. Filenames are chosen by whoever writes the file; the kind is
            # what the classifier and the zero-paste attestation both read.
            #
            # Same defect the supersession lookup carried in the runner, fixed there in the previous
            # batch and left here -- the class was named and not enumerated, which is E56 exactly.
            # Get-LamGateClassForArtifact was already dot-sourced in this file and already reads the
            # kind; the cross-check is one call.
            #
            # REPORTED, NOT SILENTLY FAILED. Saying only "not present" about a file that plainly
            # exists sends a reader to the wrong place; the mismatch is named on the detector's face.
            $declaredKind = ''
            $kindMismatch = $false
            if ($exists -and $kind) {
                $declaredKind = (Get-LamGateClassForArtifact -Path $p).kind
                # -cne: A GATE KIND IS CASE-SIGNIFICANT (V-1 round 15, a WP-3 finding, driven). With `-ne`
                # a gate declaring `kind: DISPATCH` satisfied a detector asking for `dispatch`, so
                # the cross-check this line exists to perform passed on a kind it had not been shown.
                #
                # THE RULE NOW LIVES IN lam-gate-class.ps1's Resolve-LamGateKind (operator ruling
                # R3-2), AND THIS LINE IS DELIBERATELY NOT ROUTED THROUGH IT. $kind here is a
                # DETECTOR'S REQUEST read out of a goal file, not a value this repository controls.
                # Resolving both sides would make two DIFFERENT unresolvable kinds compare EQUAL --
                # a regression in the permissive direction, which is the one that matters -- and
                # would turn a goal legitimately asking about a kind outside the map into a
                # permanent mismatch. An ordinal comparison of two texts neither side canonicalises
                # already IS the rule; what the rule adds elsewhere is a canonical key to compare
                # against, and there is none to be had here.
                $kindMismatch = ($declaredKind -cne $kind)
            }
            $ok = $exists -and $unconsumed -and (-not $revoked) -and (-not $disqualified) -and (-not $kindMismatch)
            # THE OTHER SIDE (the operator's ruling; ruled again
            # 2026-10-16 07:2x local, lean accepted): FOR kind amendment-material ALONE -- the kind this detector
            # asks for AND the kind the artifact declares -- CONSUMPTION DECIDES NOTHING. Revocation alone
            # disqualifies such a gate, and witness expiry with it; the placement arm
            # releases on the same rule. Both are read here from the gate's OWN FIELDS, never from its state: the
            # shared state ranks CONSUMED above REVOKED and DISQUALIFIED (lam-gate-class.ps1, Get-LamGateState), so a
            # gate both consumed and revoked reports state CONSUMED and the state-read $revoked above is $false --
            # read that way, this rule would release a revoked gate. A gate that is NOT consumed is not entered here:
            # its state and its fields agree, and its detail is what it was. Every other kind is what it was; a
            # detector with no kind: (a path: override alone) is what it was.
            $amConsumedNotRead = ($exists -and $gs.consumed -and ($kind -ceq 'amendment-material') -and ($declaredKind -ceq 'amendment-material'))
            if ($amConsumedNotRead) {
                $revoked = [bool]$gs.revoked
                $disqualified = [bool]$gs.disqualified
                $ok = $exists -and (-not $revoked) -and (-not $disqualified) -and (-not $kindMismatch)
            }
            $detail = "gate $p exists=$exists unconsumed=$unconsumed revoked=$revoked disqualified=$disqualified state=$($gs.state)"
            if ($kindMismatch) {
                $detail += ". KIND MISMATCH: this detector asked for '$kind' and the artifact declares " +
                           $(if ($declaredKind) { "'$declaredKind'" } else { 'no kind at all' }) +
                           " -- a file NAMED for a kind is not a gate of that kind"
            }
            if ($amConsumedNotRead) { $detail += '. CONSUMED, AND NOT READ: for kind amendment-material consumption decides nothing; revocation and disqualification alone disqualify the gate (register rows 285 and 440)' }
            return @{ ok = $ok; detail = $detail }
        }

        'file_exists' {
            $p = [string]$D['path']
            if (-not $p) { return @{ ok = $false; detail = "file_exists has no 'path'" } }
            # RELATIVE PATHS RESOLVE AGAINST -MissionRoot, NOT THE CWD (V-1 round 3, WP-3 residual).
            # Every other detector is mission-scoped; this one silently answered about whatever
            # directory the evaluator happened to be launched from, so the same goal file could
            # return MET or NOT_MET depending on the caller's cwd -- and the Stop hook and a hand
            # run do not share one. A goal is a statement about a mission, not about a shell.
            $resolved = Resolve-DetectorPath -MissionRoot $MissionRoot -Path $p
            $e = Test-Path -LiteralPath $resolved
            return @{ ok = $e; detail = "$p exists=$e (resolved against the mission root: $resolved)" }
        }

        'halt_absent' {
            # RESOLVED AT THE MISSION ROOT LIKE EVERY OTHER PATH-TAKING INPUT (V-1 round 5, WP-3).
            # Passed through raw, this was the FAIL-OPEN member of the cwd class, and the only one:
            # driven by an independent reader, one goal file with one -MissionRoot returned MET and
            # exit 0 from one working directory and NOT_MET from another over the SAME open HALT.
            # Every other member of this class fails closed; this one hands the session permission
            # to end. I cured file_exists, then its three siblings, and called the class closed
            # twice while this input and verify_pass_or_dib's were still raw.
            $dirs = if ($D['dir']) { @(Resolve-DetectorPath -MissionRoot $MissionRoot -Path ([string]$D['dir'])) } else { $null }
            # THE RUN'S ONE EFFECTIVE legacy_answered_allowlist (a review's finding): the union across
            # every halt_absent detector in the goal, with dispositions decided over the run-wide scan --
            # the SAME allowlist and the SAME scope the C-3 verdict path uses below, never this detector's
            # own entries alone. Both are computed once, before the detector loop.
            $halts = @(Get-OpenHalts -MissionRoot $MissionRoot -Dirs $dirs -LegacyAllowlist @($script:HaltEffectiveAllowlist) -ReportDirs @($script:HaltRunScanDirs))
            # THE SKIP IS REPORTED WHERE THE COUNT IS REPORTED. Read immediately after the
            # call, because the next call resets it. A file that matched `HALT-*` and was set aside
            # as tooling is named here, so "0 unanswered HALT artifact(s)" is never a count that
            # quietly swallowed something.
            $skipped = @($script:HaltScanSkipped)
            $sidecars = @($script:HaltCitationSidecarsSkipped)
            $byGate = @($script:HaltsAnsweredByGate)
            $byLegacy = @($script:HaltsAnsweredByLegacy)
            $allowReport = @($script:HaltLegacyAllowlistReport)
            $bySeatRecord = @($script:HaltsResolvedBySeatRecord)
            $skipNote = if ($skipped.Count -gt 0) { " -- $($skipped.Count) file(s) matched HALT-* and were SKIPPED as tooling by extension [$($skipped -join ', ')]" } else { '' }
            # AND EVERY WAY A HALT LEFT THE OPEN COUNT IS NAMED BESIDE IT, never silently.
            if ($sidecars.Count -gt 0) { $skipNote += " -- $($sidecars.Count) file(s) matched HALT-* and were SKIPPED as ruling-citation sidecars (a seat's citation beside a ruled HALT; never a HALT and never an answer) [$($sidecars -join ', ')]" }
            if ($byGate.Count -gt 0) { $skipNote += " -- $($byGate.Count) HALT(s) ANSWERED by a live halt-ruling gate binding their current bytes [$($byGate -join ', ')]" }
            if ($byLegacy.Count -gt 0) { $skipNote += " -- $($byLegacy.Count) HALT(s) LEGACY-ALLOWLISTED (answered by the goal's legacy_answered_allowlist -- one union for every halt_absent detector and the verdict -- over a legacy seat marker of a census member, NOT by a gate) [$($byLegacy -join ', ')]" }
            if ($allowReport.Count -gt 0) { $skipNote += " -- $($allowReport.Count) legacy_answered_allowlist entr(ies) NOT HONOURED [$($allowReport -join ' ; ')]" }
            if ($bySeatRecord.Count -gt 0) { $skipNote += " -- $($bySeatRecord.Count) seat-plane HALT(s) RESOLVED by their own RESOLVED record (a tooling seat's plane, .mission-runtime\seats; no gate is minted and nothing is authorised) [$($bySeatRecord -join ', ')]" }
            # WHAT THE RULE SET ASIDE IS NAMED WHERE THE COUNT IS, and only when it set something
            # aside, so a detail with nothing excluded reads as it did. Read immediately after the call.
            $ruleExcluded = @($script:HaltScanExcludedReport)
            if ($ruleExcluded.Count -gt 0) { $skipNote += " -- $($ruleExcluded.Count) place(s) under the scanned roots NOT COUNTED by rule [$($ruleExcluded -join ' ; ')]" }
            return @{ ok = ($halts.Count -eq 0); detail = "$($halts.Count) unanswered HALT artifact(s) [$($halts -join ', ')]$skipNote" }
        }

        'ungated_placement_absent' {
            # THE PLACEMENT-WINDOW ARM (the block above Get-UngatedPlacements says what it
            # decides on). ok when nothing is admitted; `admitted` is what the verdict path reads. What
            # the arm cannot establish admits too, its cause in the line (ruling (2) of 2026-09-24). The
            # directory is FIXED by the ruling: no key a goal writes moves it.
            # THE BACKSTOP (ruling (2)): an arm that throws has established nothing, and that ADMITS the
            # stop -- one UNDETERMINABLE line with the exception beside it -- rather than failing the
            # detector, which would block.
            $pl = $null
            try { $pl = Get-UngatedPlacements -MissionRoot $MissionRoot }
            catch {
                $plThrew = ($_.Exception.Message -replace '[\r\n]+', ' ')
                $pl = [pscustomobject]@{ fileCount = 0; trackedCount = 0; unwalked = 0; undeterminable = ('the arm threw: ' + $plThrew); released = @(); gateUnreadable = @()
                    awaiting = @([pscustomobject]@{ rel = '.mission/amendments/'; id = 'UNDETERMINABLE'; digest = 'UNDETERMINABLE'
                        line = ($script:PlacementAwaitingPrefix + ' UNDETERMINABLE UNDETERMINABLE .mission/amendments/')
                        notes = @('the arm threw (' + $plThrew + '), so nothing about .mission/amendments is established'); prescription = '' }) }
            }
            $plAwait = @($pl.awaiting)
            $plLines = @($plAwait | ForEach-Object { [string]$_.line })
            $plIgnored = @(@($D.Keys) | Where-Object { ([string]$_) -ne 'type' } | Sort-Object)
            $plDetail = "$($plAwait.Count) AWAITING line(s) for .mission/amendments"
            if ($plAwait.Count -gt 0) {
                $plDetail += " -- an ADMITTED STOP (LAM-ACCEPT amendment 54, operator ruling (ii), ledger 1404) [$($plLines -join ' ; ')]"
                # Each placement's notes BEFORE its mint, and every printed mint ends in ' #', so whatever
                # follows a command on this one line is a PowerShell comment when pasted.
                foreach ($pa in $plAwait) {
                    if (@($pa.notes).Count -gt 0) { $plDetail += " -- about $($pa.rel): $(@($pa.notes) -join '; ')" }
                    if ($pa.prescription) { $plDetail += " -- $($pa.prescription)" }
                }
            } else { $plDetail += ' []' }
            $plReleased = @($pl.released)
            if ($plReleased.Count -gt 0) { $plDetail += " -- $($plReleased.Count) placement(s) RELEASED by a canonical amendment-material gate over their bytes [$($plReleased -join ' ; ')]" }
            if ($pl.undeterminable) { $plDetail += " -- what git tracks under .mission/amendments is UNDETERMINABLE ($($pl.undeterminable)); $($pl.fileCount) file(s) walked" }
            else { $plDetail += " -- $($pl.trackedCount) tracked file(s) under .mission/amendments (a tracked file never admits)" + $(if ($pl.unwalked -gt 0) { "; $($pl.unwalked) director(ies) not walked, so that count is of what was walked" } else { '' }) }
            if ($plIgnored.Count -gt 0) { $plDetail += " -- key(s) not read by this type: $($plIgnored -join ', ')" }
            return @{ ok = ($plAwait.Count -eq 0); detail = $plDetail; admitted = ($plAwait.Count -gt 0); awaiting = $plLines }
        }

        'ungated_manifest_absent' {
            # THE DISPATCH-MANIFEST ARM (the block above Get-UngatedManifests says what it
            # decides on). ok when nothing is admitted; `admitted` and `entries` are what the verdict path
            # reads. What the arm cannot establish admits too, its cause in the line. The directory is FIXED
            # by the charter: no key a goal writes moves it.
            # THE BACKSTOP, the placement arm's: an arm that throws has established nothing, and that ADMITS
            # the stop -- one UNDETERMINABLE line, the exception beside it -- rather than failing the
            # detector, which would block.
            $ma = $null
            try { $ma = Get-UngatedManifests -MissionRoot $MissionRoot }
            catch {
                $maThrew = (([string]$_.Exception.Message) -replace '[\r\n]+', ' ')
                $ma = [pscustomobject]@{ fileCount = 0; trackedCount = 0; unwalked = 0; undeterminable = ('the arm threw: ' + $maThrew); released = @(); gateUnreadable = @()
                    awaiting = @([pscustomobject]@{ rel = '.mission/dispatches/'; id = 'UNDETERMINABLE'; note = ''
                        line = ($script:ManifestAwaitingPrefix + ' UNDETERMINABLE UNDETERMINABLE; UNDETERMINABLE')
                        notes = @('the arm threw (' + $maThrew + '), so nothing about .mission/dispatches is established') }) }
            }
            $maAwait = @($ma.awaiting)
            $maLines = @($maAwait | ForEach-Object { [string]$_.line })
            $maIgnored = @(@($D.Keys) | Where-Object { ([string]$_) -ne 'type' } | Sort-Object)
            $maDetail = "$($maAwait.Count) AWAITING line(s) for .mission/dispatches"
            if ($maAwait.Count -gt 0) {
                $maDetail += " -- an ADMITTED STOP (register row 352; ledger 1474 SS F, BATCH-2 WP-H (a)) [$($maLines -join ' ; ')]"
                foreach ($maOne in $maAwait) {
                    $maAbout = @(@($maOne.notes) | Where-Object { $_ })
                    if ($maOne.note) { $maAbout += ('operator_note: ' + [string]$maOne.note) }
                    $maDetail += " -- about $($maOne.rel): $(if ($maAbout.Count -gt 0) { $maAbout -join '; ' } else { 'no canonical, unrevoked dispatch gate binds its bytes' })"
                }
            } else { $maDetail += ' []' }
            $maReleased = @($ma.released)
            if ($maReleased.Count -gt 0) { $maDetail += " -- $($maReleased.Count) manifest(s) RELEASED by a canonical dispatch gate over their bytes [$($maReleased -join ' ; ')]" }
            if ($ma.undeterminable) { $maDetail += " -- what git tracks under .mission/dispatches is UNDETERMINABLE ($($ma.undeterminable)); $($ma.fileCount) manifest(s) walked" }
            else { $maDetail += " -- $($ma.trackedCount) tracked manifest(s) under .mission/dispatches (a tracked manifest never admits)" + $(if ($ma.unwalked -gt 0) { "; $($ma.unwalked) director(ies) not walked, so that count is of what was walked" } else { '' }) }
            if ($maIgnored.Count -gt 0) { $maDetail += " -- key(s) not read by this type: $($maIgnored -join ', ')" }
            $maEntries = @($maAwait | ForEach-Object { [pscustomobject]@{ line = [string]$_.line; note = [string]$_.note } })
            return @{ ok = ($maAwait.Count -eq 0); detail = $maDetail; admitted = ($maAwait.Count -gt 0); awaiting = $maLines; entries = $maEntries }
        }

        'handoff_brief_present' {
            # THE HANDOFF ARM (the block above Get-HandoffDecision says what it decides on).
            # READ-ONLY HERE: the verdict path appends the admission, and only when the stop needs it. ok
            # unless a HANDOFF head is ELIGIBLE -- an inert arm and a refused head both pass, so a refused
            # head blocks nothing a met goal would not; `admitted` marks an eligible head, and `handoff` is
            # what the verdict path reads.
            # THE BACKSTOP RUNS THE OTHER WAY from the two AWAITING arms: an arm that throws has established
            # nothing, and that REFUSES the head -- a stop is never admitted on a claim nobody could check.
            $hoIgnored = @(@($D.Keys) | Where-Object { ([string]$_) -ne 'type' } | Sort-Object)
            $ho = $null
            # The verdict artifact's path is composed HERE as the writer below composes it -- beside
            # the goal file -- because the head is read before that writer runs. Inside the try: a path that
            # cannot be composed is an arm that established nothing, and that refuses.
            try { $ho = Get-HandoffDecision -MissionRoot $MissionRoot -VerdictPath (Join-Path (Split-Path -Parent $goalPath) "$Goal.verdict.yaml") }
            catch {
                $ho = [pscustomobject]@{ state = 'refused'; why = ('the arm threw (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + '), so nothing about the head is established')
                                         head = ''; headShown = ''; ctx = -1; lf = ''; raw = ''; path = ''; resolved = ''; line = ''; statusPath = ''; statusSha = ''; recordPath = '' }
            }
            $hoDetail = ''
            if ($ho.state -eq 'eligible') { $hoDetail = 'HANDOFF head ELIGIBLE -- ' + $ho.line }
            elseif ($ho.state -eq 'refused') { $hoDetail = 'HANDOFF head NOT admitted -- ' + $ho.why + $(if ($ho.headShown) { ' -- head: ' + $ho.headShown } else { '' }) }
            else { $hoDetail = [string]$ho.why }
            if ($hoIgnored.Count -gt 0) { $hoDetail += " -- key(s) not read by this type: $($hoIgnored -join ', ')" }
            return @{ ok = ($ho.state -ne 'eligible'); detail = $hoDetail; admitted = ($ho.state -eq 'eligible'); handoff = $ho }
        }

        'turn_cap' {
            # `cap` through the one whole-number rule (1 to 999999). A value that fails it leaves 0
            # here and the sentence below; from a goal file such a value never arrives (the goal does not parse).
            $cap = 0
            if ($D.ContainsKey('cap')) { $capParsed = ConvertTo-GoalWholeNumber -Text ([string]$D['cap']) -Min 1; if ($capParsed.ok) { $cap = $capParsed.value } }
            if ($cap -le 0) { return @{ ok = $false; detail = "turn_cap has no positive 'cap'" } }
            # UNENFORCEABLE IS NOT SATISFIED. This returned ok when no count was available, and
            # since nothing ever supplied one it returned ok ALWAYS -- a detector that cannot fail,
            # reporting its own inertness in a detail column nobody reads on a passing check. It now
            # refuses: a goal that DECLARES a turn cap and cannot measure turns has an unchecked
            # condition, and the honest verdict for an unchecked condition is not "met".
            if ($TurnsElapsed -lt 0) { return @{ ok = $false; detail = "turn_cap $cap CANNOT BE EVALUATED: no turn count is available (no -TurnsElapsed, and no readable transcript_path on stdin). A declared cap that cannot be measured is an unchecked condition, not a satisfied one." } }
            return @{ ok = ($TurnsElapsed -lt $cap); detail = "$TurnsElapsed turns elapsed against a cap of $cap" }
        }

        'time_cap' {
            # `minutes` through the one whole-number rule (1 to 999999), as turn_cap's cap.
            $cap = 0
            if ($D.ContainsKey('minutes')) { $capParsed = ConvertTo-GoalWholeNumber -Text ([string]$D['minutes']) -Min 1; if ($capParsed.ok) { $cap = $capParsed.value } }
            $since = Resolve-DetectorPath -MissionRoot $MissionRoot -Path ([string]$D['since_file'])
            if ($cap -le 0 -or -not $since) { return @{ ok = $false; detail = "time_cap needs 'minutes' and 'since_file'" } }
            if (-not (Test-Path -LiteralPath $since)) { return @{ ok = $false; detail = "time_cap since_file not on disk: $since" } }
            $mins = [int]((New-TimeSpan -Start (Get-Item -LiteralPath $since).CreationTimeUtc -End (Get-Date).ToUniversalTime()).TotalMinutes)
            return @{ ok = ($mins -lt $cap); detail = "$mins minute(s) since $([System.IO.Path]::GetFileName($since)) against a cap of $cap" }
        }

        'sidecar_present' {
            # A runner-owned session with no capture-gaps sidecar FAILS CLOSED. The
            # sidecar is the only artifact that says whether calls went missing, so its absence is
            # a gap in the gap accounting -- not an absence of gaps.
            $sid = [string]$D['session']
            if (-not $sid) { return @{ ok = $false; detail = "sidecar_present has no 'session'" } }
            $evDir = Join-Path $MissionRoot ".mission-runtime\evidence\$sid"
            $owned = Test-Path -LiteralPath (Join-Path $evDir 'OWNER')
            $side  = Join-Path $evDir 'capture-gaps.yaml'
            # BATCH-7 WP-R (a) (the charter): `require_owned: true`, the opt-in the
            # close-prep step declares, turns the vacuous ok below into a FAIL by name -- a session no runner owns is
            # "not yet spawned" or "spawned under another name", and the goal cannot tell which. Under require_owned:
            # true a session is owned by an OWNER FILE alone (a folder of that name owns nothing), and that one reading
            # is the arm's from here on: an OWNER the runner writes between two reads cannot leave a stale one to pass
            # vacuously below. `false` reads as today. Any other value FAILS by name, the stricter reading, as
            # allow_gaps falls toward it, printed as this file prints goal text. The value is read by its leading
            # token: the reader keeps a trailing `# comment` as part of it. Without the key nothing here runs, and the
            # arm is what it was, byte for byte.
            if ($D.ContainsKey('require_owned')) {
                $ownerFile = Join-Path $evDir 'OWNER'
                $reqOwned = [regex]::Match(([string]$D['require_owned']).Trim(), '\A[^\s#]*').Value
                if ($reqOwned -eq 'true') {
                    $owned = Test-Path -LiteralPath $ownerFile -PathType Leaf
                    if (-not $owned) { return @{ ok = $false; detail = "$sid is NOT runner-owned: no OWNER file at " + (ConvertTo-ManifestDisplayText -Text $ownerFile -Max 600) + " -- the goal declares require_owned: true, and a session no runner owns FAILS here (register row 455)" } }
                } elseif ($reqOwned -ne 'false') {
                    return @{ ok = $false; detail = "$sid -- sidecar_present's require_owned '" + (ConvertTo-ManifestDisplayText -Text ([string]$D['require_owned']) -Max 60) + "' is neither true nor false: it FAILS by name, read as neither (register row 455)" }
                }
            }
            if (-not $owned) { return @{ ok = $true; detail = "$sid is not runner-owned; the sidecar is not required of it" } }
            if (-not (Test-Path -LiteralPath $side)) { return @{ ok = $false; detail = "$sid is runner-owned and has NO capture-gaps sidecar -- fail closed" } }
            $t = [System.IO.File]::ReadAllText($side)
            $count = -1
            # ANCHORED AT COLUMN 0 (V-1 round 6, WP-3). Unanchored, this matched the FIRST
            # textual occurrence anywhere in the file -- including inside a `reason:` string, where
            # these sidecars quote their own field names while explaining a gap. Driven: a sidecar
            # recording THREE lost calls read as an empty capture and the detector PASSED. Third
            # instance in this file of one class -- `validator_pass_count` counted indented
            # per-member `verdict:` lines, `Test-HaltAnswered` read a quoted marker, and now this.
            # A key at the top level of a YAML document sits at column 0; anything else is content.
            if ($t -match '(?m)^capture_gaps_count:[ \t]*(\d+)[ \t]*\r?$') { $count = [int]$Matches[1] }
            $requireEmpty = $true
            if ($D.ContainsKey('allow_gaps')) { $requireEmpty = -not ([string]$D['allow_gaps'] -eq 'true') }
            $ok = if ($requireEmpty) { $count -eq 0 } else { $count -ge 0 }
            return @{ ok = $ok; detail = "$sid sidecar present, capture_gaps_count=$count (require empty: $requireEmpty)" }
        }

        default {
            return @{ ok = $false; unknown = $true
                      detail = "UNKNOWN detector type '$type'. It is REFUSED, not skipped: a skipped detector is a goal reporting MET over a check nobody ran." }
        }
    }
}

# --- ONE HALT SCOPE AND ONE EFFECTIVE ALLOWLIST FOR THE WHOLE RUN (a review's finding) -------
# Computed ONCE, here, before any detector runs, from the goal file alone -- so every halt_absent
# detector and the C-3 verdict path below read the same two values and cannot disagree about an entry.
#   HaltDeclaredDirs       every halt_absent detector's declared `dir`, resolved at the mission root
#   HaltRunScanDirs        the run-wide scan: the two default planes plus every declared dir (the verdict
#                          path's own scan, and the scope every entry's disposition is decided over)
#   HaltEffectiveAllowlist the UNION of every halt_absent detector's legacy_answered_allowlist entries,
#                          deduplicated by exact entry text, so two detectors naming one entry report it once
$script:HaltDeclaredDirs = @()
$script:HaltEffectiveAllowlist = @()
$haltAllowSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
# FROM THE GOAL AS READ, not from the detectors that will run: a goal refused for a number that is not one
# or for a key that does not touch its colon, runs none, and still
# declares its halt dirs and its allowlist ($detectorsAsRead) -- those of them the reader stored.
foreach ($d in $detectorsAsRead) {
    if (([string]$d['type']) -ne 'halt_absent') { continue }
    $dd = [string]$d['dir']
    if ($dd) { $script:HaltDeclaredDirs += (Resolve-DetectorPath -MissionRoot $MissionRoot -Path $dd) }
    foreach ($ua in @(ConvertFrom-HaltLegacyAllowlist -Raw ([string]$d['legacy_answered_allowlist']))) {
        if ($haltAllowSeen.Add([string]$ua.raw)) { $script:HaltEffectiveAllowlist += $ua }
    }
}
$script:HaltRunScanDirs = @((Join-Path $MissionRoot '.mission-runtime\halts'), (Join-Path $MissionRoot '.mission-runtime\lam')) + @($script:HaltDeclaredDirs)

# --- IS A REUSE WINDOW DECLARED AT ALL? ---------------------------------------------------
# Read from the goal file alone, before any detector runs: true when some instrument_exit0 detector
# carries a reuse_within_minutes above 0. It decides ONE thing -- whether the verdict artifact carries
# the key instrument_captures_reused and the key instrument_captures_kept beside
# it (and, where the verdict is MET, instrument_captures_kept_on_disk under
# that) -- so a goal that declares no window writes the artifact it wrote.
$script:InstrumentCapturesReused = @()
# The kept copy of each capture reused, `<kept path> sha256 <sha256>`, in the same order.
$script:InstrumentCapturesKept = @()
$instrumentReuseDeclared = $false
# AND ARE THE TWO KEYS OF BATCH-5 DECLARED AT ALL? Read the same way, from the detectors
# that will run (a goal that does not parse has none, and writes none of these keys), by ContainsKey:
#   some instrument_exit0 declares instrument_inputs_except -> the artifact carries instrument_inputs_except
#     (one item per declaring detector that was invoked with a list that reads: the list, and HEAD's figure
#     or why there is none) and instrument_input_tree_matched (one item per reuse the figure admitted);
#   some instrument_exit0 declares engine_read -> the artifact carries instrument_engine_reads (one item per
#     read made; none on a short-circuit or a refused key -- and the read a reuse
#     follows stands beside it).
# Each is `[]` when it has no item, and a goal that declares neither key writes neither -- the artifact it wrote.
# (NAMED ...Said, NOT AFTER ITS KEY: PowerShell variable names fold case, and $InstrumentInputsExcept is the
# shared helper's own parameter -- the helper's rule about $p, which this file keeps for its $prev, applies.)
$script:InstrumentInputsExceptSaid = @()
$script:InstrumentInputTreeMatched = @()
$script:InstrumentEngineReads = @()
# AND IS THE TREE WINDOW DECLARED? Read the same way: some instrument_exit0 declares
# reuse_tree_within_minutes -> the artifact carries instrument_reuse_window_admitted (one item per reuse, the window
# that admitted it), `[]` when nothing was reused; a goal that declares no such key writes no such key.
$script:InstrumentReuseWindowAdmitted = @()
$instrumentInputsDeclared = $false
$instrumentEngineDeclared = $false
$instrumentTreeWindowDeclared = $false
foreach ($d in $detectors) {
    if (([string]$d['type']) -ne 'instrument_exit0') { continue }
    if ($d.ContainsKey('instrument_inputs_except')) { $instrumentInputsDeclared = $true }
    if ($d.ContainsKey('engine_read')) { $instrumentEngineDeclared = $true }
    if ($d.ContainsKey('reuse_tree_within_minutes')) { $instrumentTreeWindowDeclared = $true }
    if (-not $d.ContainsKey('reuse_within_minutes')) { continue }
    # The SAME parse the reuse decision makes -- one rule, so the two cannot read a value two ways.
    $reuseDeclaredParsed = ConvertTo-GoalWholeNumber -Text ([string]$d['reuse_within_minutes']) -Min 0
    if ($reuseDeclaredParsed.ok -and ($reuseDeclaredParsed.value -gt 0)) { $instrumentReuseDeclared = $true }
}

# --- evaluate -----------------------------------------------------------------------------------
$results = New-Object System.Collections.Generic.List[object]
$unknownSeen = $false
$shortCircuited = 0

# SHORT-CIRCUIT, IN HOOK MODE ONLY, AND DISCLOSED ON THE ARTIFACT.
# A Stop hook needs a DECISION, not a report: once one detector has failed, the decision is
# `block` and no later detector can change it. A full run evaluates everything.
#
# This is not an optimisation for its own sake. Detectors of type instrument_exit0 RUN the
# instrument, and the full set is tens of seconds; a hook that outran its own timeout would be
# silently skipped by the harness, and a continuation gate that silently stops firing is worse
# than no gate at all. Order your goal file cheapest-detector-first and this stays fast until the
# goal is genuinely close to met.
#
# The detectors not reached are RECORDED AS NOT EVALUATED, never as passing. A verdict file that
# implied a check had run would be the exact overclaim design SS4.5 law 4 forbids.
#
# THE PLACEMENT-WINDOW ARM IS EVALUATED FIRST, WHEREVER THE GOAL DECLARES IT. Every
# `ungated_placement_absent` detector is hoisted ahead of every other detector, in declaration order,
# and the artifact lists it first. In HOOK MODE, once an arm has ADMITTED a stop the decision is
# already `approve` -- only a HALT could change its label, and the C-3 scan below runs regardless --
# so every other detector is recorded NOT EVALUATED, the instrument included. A FULL RUN still
# evaluates everything, as it always has; its verdict is the same.
#
# THE THREE ADMITTED-STOP ARMS, IN ONE FIXED ORDER, WHATEVER THE GOAL'S OWN:
# every `ungated_placement_absent`, then every `ungated_manifest_absent`, then every
# `handoff_brief_present`, each group in declaration order, all ahead of every other detector. The
# placement arm keeps its place, so a goal that declares it alone is evaluated as it was. The two
# AWAITING arms come before the handoff arm because the handoff arm is the only one that SPENDS
# something: an admission is recorded only when the stop would not be admitted without it, and that is
# known only once the two arms that spend nothing have answered. Every declared arm is evaluated, also
# after one has admitted -- each is instant, and the operator is owed every line -- while in HOOK MODE
# every other detector is then recorded NOT EVALUATED, the arm that admitted first named. The absent
# goal is decided before any of this, where the goal is searched for: with no goal there is no arm.
$placementArmDeclared = @($detectors | Where-Object { ([string]$_['type']) -eq $script:PlacementArmType })
$manifestArmDeclared = @($detectors | Where-Object { ([string]$_['type']) -eq $script:ManifestArmType })
$handoffArmDeclared = @($detectors | Where-Object { ([string]$_['type']) -eq $script:HandoffArmType })
$armTypes = @($script:PlacementArmType, $script:ManifestArmType, $script:HandoffArmType)
$orderedDetectors = @($placementArmDeclared) + @($manifestArmDeclared) + @($handoffArmDeclared) + @($detectors | Where-Object { $armTypes -notcontains ([string]$_['type']) })
$armAdmittedBy = ''
$placementAwaiting = New-Object System.Collections.Generic.List[string]
$manifestAwaiting = New-Object System.Collections.Generic.List[string]
$manifestNotes = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]' ([System.StringComparer]::Ordinal)
$handoffDecision = $null
$handoffResults = New-Object System.Collections.Generic.List[object]
# THE OTHER HALF: a goal file that exists and does not parse has no detector to evaluate, and its
# one entry FAILS. The C-3 scan below still runs, over the default planes.
if ($goalParseError) {
    [void]$results.Add([pscustomobject]@{
        type   = 'goal_parse'
        ok     = $false
        detail = "THE GOAL FILE DOES NOT PARSE -- $goalParseError -- the stop is REFUSED (register row 341; the operator's ruling of 2026-09-30: a goal file that exists and cannot be read fails closed; only an ABSENT goal is admitted)"
    })
}
foreach ($d in $orderedDetectors) {
    $dType = [string]$d['type']
    $isPlacementArm = ($dType -eq $script:PlacementArmType)
    $isArm = ($armTypes -contains $dType)
    if ($AsStopHook -and $armAdmittedBy -and (-not $isArm)) {
        [void]$results.Add([pscustomobject]@{
            type   = [string]$d['type']
            ok     = $false
            detail = "NOT EVALUATED -- hook-mode short-circuit: $armAdmittedBy. This is not a pass."
        })
        $shortCircuited++
        continue
    }
    if ($AsStopHook -and (-not $isArm) -and ($results | Where-Object { -not $_.ok } | Select-Object -First 1)) {
        [void]$results.Add([pscustomobject]@{
            type   = [string]$d['type']
            ok     = $false
            detail = 'NOT EVALUATED -- hook-mode short-circuit after an earlier detector failed. This is not a pass.'
        })
        $shortCircuited++
        continue
    }
    # A DETECTOR THAT THROWS IS A DETECTOR THAT FAILED -- NOT ONE THAT WAS NEVER ASKED
    # (V-1 round 4, WP-3). An exception here used to escape to the script trap, which abandoned the
    # whole evaluation: NO verdict artifact was written at all, and in hook mode it emitted a
    # NON-BLOCKING decision on the way out. So a detector crashing let a session end, and left
    # nothing on disk saying why -- the fail-OPEN direction, in the file whose own law is that an
    # unknown detector refuses rather than being skipped.
    #
    # Caught per detector, recorded as a FAILURE with the exception text, and evaluation continues
    # so the remaining detectors are still reported and the artifact still gets written.
    $r = $null
    try { $r = Invoke-Detector -D $d }
    catch {
        $r = @{ ok = $false
                detail = "detector '$([string]$d['type'])' THREW and is recorded as FAILED, not skipped: $($_.Exception.Message). A detector that cannot answer has not answered yes." }
    }
    if ($r['unknown']) { $unknownSeen = $true }
    if ($isPlacementArm -and $r['admitted']) {
        if (-not $armAdmittedBy) { $armAdmittedBy = "the placement-window arm admitted a stop ($($script:PlacementAwaitingPrefix))" }
        foreach ($awaitLine in @($r['awaiting'])) {
            if ($awaitLine -and (-not $placementAwaiting.Contains([string]$awaitLine))) { $placementAwaiting.Add([string]$awaitLine) }
        }
    }
    if (($dType -eq $script:ManifestArmType) -and $r['admitted']) {
        if (-not $armAdmittedBy) { $armAdmittedBy = "the dispatch-manifest arm admitted a stop ($($script:ManifestAwaitingPrefix))" }
        # One line per DISTINCT text -- two manifests of one id and the same bytes are one line, which one
        # gate releases -- and its operator_note(s) kept beside it.
        foreach ($manifestEntry in @($r['entries'])) {
            $manifestLine = [string]$manifestEntry.line
            if (-not $manifestLine) { continue }
            if (-not $manifestAwaiting.Contains($manifestLine)) {
                $manifestAwaiting.Add($manifestLine)
                $manifestNotes[$manifestLine] = New-Object System.Collections.Generic.List[string]
            }
            $manifestNote = [string]$manifestEntry.note
            if ($manifestNote -and (-not $manifestNotes[$manifestLine].Contains($manifestNote))) { $manifestNotes[$manifestLine].Add($manifestNote) }
        }
    }
    if ($dType -eq $script:HandoffArmType) {
        # The FIRST handoff arm's reading is the run's; a second one declared reads the same disk.
        if (($null -eq $handoffDecision) -and ($null -ne $r['handoff'])) { $handoffDecision = $r['handoff'] }
        if ($r['admitted'] -and (-not $armAdmittedBy)) { $armAdmittedBy = "the handoff arm found an eligible HANDOFF head ($($script:HandoffAdmittedPrefix))" }
    }
    $resultEntry = [pscustomobject]@{
        type   = [string]$d['type']
        ok     = [bool]$r['ok']
        detail = [string]$r['detail']
    }
    [void]$results.Add($resultEntry)
    if ($dType -eq $script:HandoffArmType) { $handoffResults.Add($resultEntry) }
}

# --- C-3: a HALT outranks everything ------------------------------------------------------------
# THE SAME ENUMERATOR THE DETECTOR USES. This path had its own copy of the scan, and the two
# disagreed the moment one was corrected -- the detector naming an open halt while the verdict
# beneath it read none. One function, two consumers.
#
# AND THE SAME DIRECTORIES, WHICH IS THE HALF THAT WAS STILL MISSING (V-1 round 5). Sharing the
# FUNCTION was not sharing the SCAN: the detector passed its declared `dir` and this path passed
# $null, so a goal declaring `halt_absent` with a `dir` produced a FAILING DETECTOR and a verdict of
# NOT_MET -- while an unanswered HALT sat in the directory the goal had named. Caught by a member I
# wrote for a different fix, which is the only reason it is not still there.
#
# The difference is not cosmetic and it runs the wrong way. NOT_MET means "the agent has work left"
# and BLOCKS; HALT means "a human must rule" and hands control back. Reporting NOT_MET over an open
# halt tells the session to keep working on something only the operator can settle -- C-3's whole
# point is that a HALT outranks every other verdict, and it cannot outrank what it cannot see.
# THE DECLARED DIRS AND THE EFFECTIVE ALLOWLIST were computed ONCE before the detector loop (a
# review's finding) and are read here, so this path and every halt_absent detector use the same union
# of legacy_answered_allowlist entries over the same run-wide scan.
$declaredHaltDirs = @($script:HaltDeclaredDirs)
# UNION, NEVER REPLACEMENT. A declared dir ADDS somewhere to look; it must not stop this path
# looking where halts normally live, or a goal could hide the default planes by naming another one.
$haltDirs = if ($declaredHaltDirs.Count -gt 0) {
    @((Join-Path $MissionRoot '.mission-runtime\halts'), (Join-Path $MissionRoot '.mission-runtime\lam')) + $declaredHaltDirs
} else { $null }
$openHalts = @(Get-OpenHalts -MissionRoot $MissionRoot -Dirs $haltDirs -LegacyAllowlist @($script:HaltEffectiveAllowlist) -ReportDirs @($script:HaltRunScanDirs))
# Captured IMMEDIATELY after the call that produced it -- this is the LAST scan of the
# run, so this list is the one the verdict artifact reports.
$haltScanSkipped = @($script:HaltScanSkipped)
$haltCitationSidecars = @($script:HaltCitationSidecarsSkipped)
$haltsByGate = @($script:HaltsAnsweredByGate)
$haltsByLegacy = @($script:HaltsAnsweredByLegacy)
$haltAllowReport = @($script:HaltLegacyAllowlistReport)
$haltsBySeatRecord = @($script:HaltsResolvedBySeatRecord)
# The roots THIS scan read and what the rule set aside under them, captured with the rest.
$haltScanRoots = @($script:HaltScanRootsReport)
$haltScanExcluded = @($script:HaltScanExcludedReport)

$failing = @($results | Where-Object { -not $_.ok })
# THE FOURTH VERDICT: an admitted placement reads AWAITING_AMENDMENT_GATE. A HALT still
# outranks it -- C-3 is unamended -- and the awaiting lines are written beside the HALT all the same.
#
# THE FIFTH AND SIXTH, IN THAT ORDER BENEATH IT: an admitted manifest reads
# AWAITING_DISPATCH_GATE, and an eligible HANDOFF head reads HANDOFF_ADMITTED. The order is the order
# the arms are evaluated in, and for the same reason: the placement arm's verdict is the one a goal
# already declares and keeps its reading, its sibling follows it, and the handoff arm comes last because
# it alone SPENDS something -- the brief is recorded, and so spent, ONLY when no HALT and no AWAITING
# line already admits the stop, and only as a Stop hook. A hand-run records nothing and reads the same
# verdict. An append that fails admits nothing: the head was eligible, the record could not take it, and
# the verdict falls to NOT_MET -- the hook blocks, the write failure named.
$handoffEligible = ($null -ne $handoffDecision) -and ([string]$handoffDecision.state -eq 'eligible')
$handoffRecorded = $null
# ONE BRANCH AHEAD OF THE HALT (the operator's ruling): a key that does
# not touch its colon ON A HALT-SCOPE KEY of a halt_absent item -- one the goal WROTE as halt_absent, or,
# for a key line, one the reader READ as halt_absent ($goalGrammarHaltScope, set under the parse steps) --
# outranks the HALT label: NOT_MET, the hook blocks, by hand exit 1. C-3 is otherwise unamended:
# every other verdict a HALT outranks it still outranks, a goal that does not parse for any other reason
# among them. open_halts is written as the scan read it, whichever branch answers.
if ($goalGrammarHaltScope) { $verdict = 'NOT_MET' }
elseif ($openHalts.Count -gt 0) { $verdict = 'HALT' }
elseif ($placementAwaiting.Count -gt 0) { $verdict = 'AWAITING_AMENDMENT_GATE' }
elseif ($manifestAwaiting.Count -gt 0) { $verdict = 'AWAITING_DISPATCH_GATE' }
elseif ($handoffEligible) {
    if ($AsStopHook) {
        $handoffRecorded = Add-HandoffAdmission -Decision $handoffDecision -Goal $Goal -MissionRoot $MissionRoot
        $verdict = if ($handoffRecorded.ok) { 'HANDOFF_ADMITTED' } else { 'NOT_MET' }
    } else { $verdict = 'HANDOFF_ADMITTED' }
}
elseif ($unknownSeen)       { $verdict = 'NOT_MET' }
elseif ($failing.Count -eq 0 -and $results.Count -gt 0) { $verdict = 'MET' }
else { $verdict = 'NOT_MET' }
# WHAT THE VERDICT DID WITH AN ELIGIBLE HEAD, written back onto the arm's own entries so the artifact and
# the hook's reason say it; and a REFUSED head's one sentence, which every surface below carries.
if ($handoffEligible) {
    $handoffOutcome = ''
    if (($verdict -eq 'HANDOFF_ADMITTED') -and $AsStopHook) {
        $handoffOutcome = "ADMITTED ONE STOP (register row 353; ledger 1474 SS F, BATCH-2 WP-H (b)) -- $($handoffDecision.line) -- recorded at $($handoffDecision.recordPath) line $($handoffRecorded.line); the same brief never admits again"
    } elseif ($verdict -eq 'HANDOFF_ADMITTED') {
        $handoffOutcome = "ADMITTED BY HAND, NOT RECORDED -- a hand-run records nothing; only a Stop hook's admission is recorded and spends the brief -- $($handoffDecision.line)"
    } elseif (($null -ne $handoffRecorded) -and (-not $handoffRecorded.ok)) {
        $handoffOutcome = "NOT ADMITTED -- the admissions record $($handoffDecision.recordPath) could not be written ($($handoffRecorded.why)); a stop is admitted on a brief only once it is recorded -- $($handoffDecision.line)"
    } else {
        $handoffOutcome = "ELIGIBLE, NOT SPENT -- the verdict is $verdict, which admits the stop without it; nothing is recorded -- $($handoffDecision.line)"
    }
    foreach ($handoffEntry in $handoffResults) { $handoffEntry.detail = $handoffOutcome }
}
$handoffRefusal = ''
if (($null -ne $handoffDecision) -and ([string]$handoffDecision.state -eq 'refused')) { $handoffRefusal = 'HANDOFF head NOT admitted -- ' + [string]$handoffDecision.why }
$handoffTail = if ($handoffRefusal) { ' ' + $handoffRefusal + '.' } else { '' }

# --- write the verdict beside the goal ----------------------------------------------------------
$verdictPath = Join-Path (Split-Path -Parent $goalPath) "$Goal.verdict.yaml"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Written by tools/lam/mission-goal-check.ps1. Every detector below read DISK.")
[void]$sb.AppendLine("# No detector reads a transcript, a summary, or any claim (LAM-ACCEPT WP-3).")
[void]$sb.AppendLine("goal: $Goal")
[void]$sb.AppendLine("goal_file: $goalPath")
[void]$sb.AppendLine("mission_root: $MissionRoot")
[void]$sb.AppendLine("evaluated_at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture))")
[void]$sb.AppendLine("verdict: $verdict")
[void]$sb.AppendLine("detector_count: $($results.Count)")
[void]$sb.AppendLine("failing_count: $($failing.Count)")
[void]$sb.AppendLine("short_circuited: $shortCircuited   # detectors NOT evaluated (hook mode); never counted as passing")
# WHO WROTE THIS VERDICT (the BATCH-7 charter's item (c)): `hook` where this
# run is the Stop hook (-AsStopHook), `hand` where it is not -- written by EVERY writer of the artifact (this one, the
# absent goal's and the trap's), directly after short_circuited:, the one trace it supersedes: short_circuited above 0
# says a hook only where the hook short-circuited something, and a MET hook stop that evaluates every detector read as a
# hand run does. ONE LINE ADDED; no key is renamed or moved, and nothing on stdout says it. seat.py reads it.
[void]$sb.AppendLine("hook_or_hand: $(if ($AsStopHook) { 'hook' } else { 'hand' })")
# THE OTHER HALF, ON DISK: written only for a goal file that exists and does not parse, so a goal
# that parses writes exactly the artifact it wrote before.
if ($goalParseError) { [void]$sb.AppendLine("goal_parse_error: '$((($goalParseError) -replace "`r?`n", ' ') -replace "'", "''")'") }
if ($openHalts.Count -gt 0) {
    [void]$sb.AppendLine("open_halts:")
    # A BARE FILE NAME STAYS BARE; ANYTHING ELSE IS SINGLE-QUOTED WITH QUOTES DOUBLED. The
    # annotation "[seat marker ANSWERED; ...]" and the UNREADABLE entry both ride this list,
    # and the round-7 finding stands: a bare scalar that ever carries `: ` stops being a string.
    foreach ($h in $openHalts) {
        if ([regex]::IsMatch([string]$h, '\A[A-Za-z0-9._-]+\z')) { [void]$sb.AppendLine("  - $h") }
        else { [void]$sb.AppendLine("  - '$(([string]$h) -replace "'", "''")'") }
    }
} else {
    [void]$sb.AppendLine("open_halts: []")
}
# WHAT THE SCAN SET ASIDE, ON DISK, EVERY RUN. Emitted unconditionally -- `[]` when
# nothing was skipped -- because a key that appears only when something was hidden is a key no
# reader learns to look for. SINGLE-QUOTED WITH QUOTES DOUBLED, the discipline the UNREADABLE entry
# had to be taught: a bare scalar carrying `: ` becomes a single-key MAP and the entry silently
# stops being a string. These are file names rather than exception text, so the hazard is smaller --
# but the report of a narrowing is the last artifact that should be allowed to go unparsable.
if ($haltScanSkipped.Count -gt 0) {
    [void]$sb.AppendLine("halt_scan_skipped:")
    foreach ($s in $haltScanSkipped) { [void]$sb.AppendLine("  - '$(([string]$s) -replace "'", "''")'") }
} else {
    [void]$sb.AppendLine("halt_scan_skipped: []")
}
# FOUR MORE KEYS, EACH EMITTED UNCONDITIONALLY (`[]` when empty) FOR THE SAME REASON AS THE
# ONE ABOVE, AND EACH ENTRY SINGLE-QUOTED WITH QUOTES DOUBLED:
#   halt_scan_skipped_citation_sidecars  ruling-citation sidecars set aside before the read, with why
#   halts_answered_by_ruling_gate        HALTs a live halt-ruling gate answers, naming the gate
#   halts_answered_by_legacy_allowlist   name@sha of every LEGACY-ALLOWLISTED HALT (never silent)
#   legacy_allowlist_report              every legacy_answered_allowlist entry NOT honoured, with why
function Add-VerdictQuotedList {
    param($Builder, [string]$Key, [AllowNull()][object[]]$Items)
    $listItems = @($Items | Where-Object { $null -ne $_ })
    if ($listItems.Count -eq 0) { [void]$Builder.AppendLine("${Key}: []"); return }
    [void]$Builder.AppendLine("${Key}:")
    foreach ($listItem in $listItems) { [void]$Builder.AppendLine("  - '$(((([string]$listItem) -replace "`r?`n", ' ')) -replace "'", "''")'") }
}
Add-VerdictQuotedList -Builder $sb -Key 'halt_scan_skipped_citation_sidecars' -Items @($haltCitationSidecars | ForEach-Object { "$_ -- a ruling-citation sidecar, not a HALT and never an answer" })
Add-VerdictQuotedList -Builder $sb -Key 'halts_answered_by_ruling_gate' -Items @($haltsByGate | ForEach-Object { "$_ -- ANSWERED by .mission/gates/halt-ruling-$([System.IO.Path]::GetFileNameWithoutExtension([string]$_)).yaml, which binds its current bytes" })
Add-VerdictQuotedList -Builder $sb -Key 'halts_answered_by_legacy_allowlist' -Items @($haltsByLegacy | ForEach-Object { "$_ -- LEGACY-ALLOWLISTED (a legacy seat marker at the allowlisted bytes; no halt-ruling gate)" })
Add-VerdictQuotedList -Builder $sb -Key 'legacy_allowlist_report' -Items $haltAllowReport
# THE SEAT-RECORD ANSWERS -- written ONLY when a seat-plane HALT was answered by its RESOLVED record, so every artifact
# without one is byte for byte the artifact it was before:
#   halts_resolved_by_seat_record   each such HALT, said to authorise nothing (no gate was minted)
if ($haltsBySeatRecord.Count -gt 0) {
    Add-VerdictQuotedList -Builder $sb -Key 'halts_resolved_by_seat_record' -Items @($haltsBySeatRecord | ForEach-Object { "$_ -- RESOLVED by its own RESOLVED record in a tooling seat's plane (.mission-runtime\seats); no halt-ruling gate, and it authorises nothing" })
}
# THE SCANNED SET, IN THE VERDICT'S OWN WORDS, ON EVERY EVALUATION:
#   halt_scan_roots     every root the C-3 scan read, recursively, for HALT-*; one that is not on disk says so
#   halt_scan_excluded  every place the rule did not count -- a nested mission root, the scratch-copies
#                       tree -- with how many HALT-* files sit under it; `[]` when the rule set nothing aside
# Both are written whatever the goal declares, for the reason halt_scan_skipped is: a key that appears
# only when something was hidden is a key no reader learns to look for.
Add-VerdictQuotedList -Builder $sb -Key 'halt_scan_roots' -Items $haltScanRoots
Add-VerdictQuotedList -Builder $sb -Key 'halt_scan_excluded' -Items $haltScanExcluded
# THE ADMISSION, NAMED ON DISK -- written only when the goal DECLARES the arm, `[]` when
# it admitted nothing, so a goal without the type writes exactly the artifact it wrote before.
if ($placementArmDeclared.Count -gt 0) {
    Add-VerdictQuotedList -Builder $sb -Key 'awaiting_amendment_gate' -Items @($placementAwaiting.ToArray())
}
# THE TWO SIBLING ADMISSIONS, NAMED ON DISK, each key written only when the
# goal DECLARES its arm and `[]` when it admitted nothing, by the same rule: a goal without the types
# writes exactly the artifact it wrote before.
#   awaiting_dispatch_gate        one AWAITING DISPATCH GATE line per distinct admitted manifest
#   awaiting_dispatch_gate_notes  `<that line> -- operator_note: <note>` for each manifest that carries one
#   handoff_admitted              the HANDOFF ADMITTED line, when the verdict is HANDOFF_ADMITTED
#   handoff_refused               why a HANDOFF head was not admitted, when one was read and refused
# This artifact is NEVER the handoff arm's record -- the next evaluation overwrites it; the record is
# .mission-runtime/lam/handoff-admissions.jsonl.
$dispatchEntries = @()
foreach ($dispatchLine in $manifestAwaiting) {
    $dispatchLineNotes = @($manifestNotes[$dispatchLine].ToArray())
    if ($dispatchLineNotes.Count -eq 0) { $dispatchEntries += $dispatchLine }
    else { foreach ($dispatchLineNote in $dispatchLineNotes) { $dispatchEntries += ($dispatchLine + ' -- operator_note: ' + $dispatchLineNote) } }
}
if ($manifestArmDeclared.Count -gt 0) {
    Add-VerdictQuotedList -Builder $sb -Key 'awaiting_dispatch_gate' -Items @($manifestAwaiting.ToArray())
    Add-VerdictQuotedList -Builder $sb -Key 'awaiting_dispatch_gate_notes' -Items @($dispatchEntries | Where-Object { $_ -match ' -- operator_note: ' })
}
if ($handoffArmDeclared.Count -gt 0) {
    Add-VerdictQuotedList -Builder $sb -Key 'handoff_admitted' -Items @($(if ($verdict -eq 'HANDOFF_ADMITTED') { [string]$handoffDecision.line }))
    Add-VerdictQuotedList -Builder $sb -Key 'handoff_refused' -Items @($(if ($handoffRefusal) { $handoffRefusal }))
}
# EVERY CAPTURE REUSED IN PLACE OF A RUN, NAMED BY PATH AND SHA256, written only when the goal
# declares a reuse window above 0 and `[]` when nothing was reused, by the same rule as the arms' keys.
if ($instrumentReuseDeclared) {
    Add-VerdictQuotedList -Builder $sb -Key 'instrument_captures_reused' -Items @($script:InstrumentCapturesReused)
    # AND THE CONTENT-ADDRESSED COPY OF EACH, `<kept path> sha256 <sha256>`, under its own key and
    # by the same rule: a capture is named as reused only after its bytes were kept beside it, so the two
    # lists are the same length, entry for entry; `[]` when nothing was reused.
    Add-VerdictQuotedList -Builder $sb -Key 'instrument_captures_kept' -Items @($script:InstrumentCapturesKept)
    # AND, WHERE THE VERDICT IS MET, EVERY KEPT COPY THAT STANDS ON DISK, directly under the key
    # above: by leaf, under every run key, each said to hash to its name or not (Get-InstrumentKeptOnDisk);
    # `[]` when none stands. Listed HERE, after every detector ran, so the copy this evaluation kept is in
    # it. A verdict that is not MET does not carry the key, and a goal with no window above 0 writes none of
    # the three. The listing cannot throw and decides nothing.
    if ($verdict -eq 'MET') {
        Add-VerdictQuotedList -Builder $sb -Key 'instrument_captures_kept_on_disk' -Items @(Get-InstrumentKeptOnDisk -MissionRoot $MissionRoot -Detectors $detectors)
    }
}
# THE LIST OF WHAT IS NOT AN INPUT, WITH HEAD's FIGURE UNDER IT, AND EVERY REUSE THAT FIGURE ADMITTED,
# each key written only where some instrument_exit0 declares instrument_inputs_except, by the arms' rule:
#   instrument_inputs_except       `<leaf>: except [<p1>, <p2>]; input_tree at HEAD <64 hex>`, or
#                                  `...; input_tree at HEAD not derivable (<why>)`
#   instrument_input_tree_matched  `<capture path> input_tree <64 hex> capture_head <40 hex> head <40 hex>`;
#                                  `[]` for a fresh run, a decline, and a reuse at HEAD itself
if ($instrumentInputsDeclared) {
    Add-VerdictQuotedList -Builder $sb -Key 'instrument_inputs_except' -Items @($script:InstrumentInputsExceptSaid)
    Add-VerdictQuotedList -Builder $sb -Key 'instrument_input_tree_matched' -Items @($script:InstrumentInputTreeMatched)
}
# EVERY ENGINE READ MADE, IN THE ORDER MADE, written only where some instrument_exit0 declares
# engine_read and `[]` where none was made (the read comes before any reuse, so a reuse
# carries the read it followed):
#   `<leaf>: docker_pipe \\.\pipe\dockerDesktopLinuxEngine <present|ABSENT> (<n> named pipes, <s> s)`
#   `<leaf>: docker version <answered <text>|did not answer: <why>> (<s> s)`
# an injected fault's item opening `<leaf>: FAULT INJECTED BY THE GOAL's engine_read_fault KEY (<fault>): `.
if ($instrumentEngineDeclared) {
    Add-VerdictQuotedList -Builder $sb -Key 'instrument_engine_reads' -Items @($script:InstrumentEngineReads)
}
# THE WINDOW THAT ADMITTED EACH REUSE, written only where some instrument_exit0 declares
# reuse_tree_within_minutes, AFTER every key written before it and BEFORE `detectors:` -- never between
# instrument_captures_kept and instrument_captures_kept_on_disk -- and `[]` where nothing was reused:
#   `<capture path> sha256 <sha256> window head|tree minutes <the window's own minutes>`
if ($instrumentTreeWindowDeclared) {
    Add-VerdictQuotedList -Builder $sb -Key 'instrument_reuse_window_admitted' -Items @($script:InstrumentReuseWindowAdmitted)
}
[void]$sb.AppendLine("detectors:")
foreach ($r in $results) {
    [void]$sb.AppendLine("  - type: $($r.type)")
    [void]$sb.AppendLine("    ok: $(if ($r.ok) { 'true' } else { 'false' })")
    # SINGLE-QUOTED, NOT DOUBLE-QUOTED, and this is a correctness fix rather than a style one.
    # A YAML DOUBLE-quoted scalar processes backslash escapes, and these details are full of Windows
    # paths -- so an expanded `%USERPROFILE%\...` path contains `\U`, and `\l`, `\d` and friends appear wherever a path
    # segment starts with those letters. None is a legal YAML escape, so EVERY verdict artifact this
    # tool has ever written is unparsable, and the error is fatal to the whole document: a reader
    # cannot recover even the `verdict:` line. Found by V-1 round 2 (WP-3) against both live
    # artifacts. A YAML SINGLE-quoted scalar has no escapes at all; the only thing needing care is
    # an embedded quote, which is doubled.
    # Newlines are folded to spaces first: a raw newline inside a single-line quoted scalar would
    # break the document in a different way, which would be trading one unparsable artifact for
    # another.
    $detailFlat = (([string]$r.detail) -replace "`r?`n", ' ') -replace "'", "''"
    [void]$sb.AppendLine("    detail: '$detailFlat'")
}
[System.IO.File]::WriteAllText($verdictPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

# --- report --------------------------------------------------------------------------------------
if ($AsStopHook) {
    # C-2 / C-3. NOT_MET blocks and names what is missing. MET and HALT do not block -- MET because
    # there is nothing left to do, HALT because control belongs to the human.
    if ($verdict -eq 'NOT_MET') {
        # Name only the detectors that ACTUALLY failed. The short-circuited ones are recorded in
        # the verdict file as not-evaluated; repeating them here would bury the one fact the
        # session needs -- what to go and fix -- under boilerplate.
        $real = @($failing | Where-Object { $_.detail -notlike 'NOT EVALUATED*' })
        $why  = ($real | ForEach-Object { "$($_.type): $($_.detail)" }) -join ' ; '
        $skipped = $failing.Count - $real.Count
        $tail = if ($skipped -gt 0) { " ($skipped further detector(s) not evaluated -- the decision was already determined.)" } else { '' }
        # A HANDOFF head that was read and REFUSED is named beside them ($handoffTail; '' when there is
        # none, so a goal without the type reads as before): the seat is told why its head did not admit.
        # BATCH-6 WP-Q (b) (the BLOCK-text half; ruled 2026-10-16 07:2x local, lean accepted,
        # Q3): AND THEN ONE SENTENCE, THE STOPS THIS GOAL ADMITS AND THE NEAREST. The arms the goal declares, in the
        # fixed order the evaluator evaluates them (placement, manifest, handoff), and then a HALT, which every goal
        # admits; the nearest by a fixed order over what this evaluation read: a handoff line read and refused (its
        # words stand in $handoffTail); else the manifest arm declared and a validator_pass_count among the failing --
        # the round is what is owed; else a HALT. Every other text this hook prints, and the hand run, is unchanged.
        # The words never spell "HANDOFF head" (WP-3 C-1ag (g)) nor "the instrument was run" (C-1ar (j3)), and hold no
        # character the hook's JSON escapes. The harness's block cap, which ends a turn the evaluator refused, is the
        # outer limit this evaluator cannot change (the harness half, recorded).
        $admitList = New-Object System.Collections.Generic.List[string]
        if ($placementArmDeclared.Count -gt 0) { $admitList.Add('a placed amendment awaiting its gate (ungated_placement_absent)') }
        if ($manifestArmDeclared.Count -gt 0) { $admitList.Add('a placed round manifest awaiting its gate (ungated_manifest_absent)') }
        if ($handoffArmDeclared.Count -gt 0) { $admitList.Add('a handoff line first on STATUS.md whose brief re-derives (handoff_brief_present)') }
        $admitList.Add('a HALT under .mission-runtime/halts/')
        $admitNearest = if ($handoffRefusal) { 'the handoff line -- mend it as said above' }
                        elseif (($manifestArmDeclared.Count -gt 0) -and (@($real | Where-Object { ([string]$_.type) -eq 'validator_pass_count' }).Count -gt 0)) { 'a placed round manifest -- place the manifest of the round under .mission/dispatches/' }
                        else { 'a HALT -- write a HALT that names what blocks' }
        $admitted = ' The stops this goal admits: ' + ($admitList -join '; ') + '. Nearest for this state: ' + $admitNearest + '.'
        $reason = "Goal '$Goal' is NOT_MET on disk. Failing -- $why.$tail$handoffTail Verdict: $verdictPath. Continue working: this decision is derived from the evidence plane, not from the transcript.$admitted"
        Write-Output (@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress)
        exit 0
    }
    if ($verdict -eq 'HALT') {
        # Every AWAITING line is still named beside the HALT -- the placement arm's, then the manifest
        # arm's, each manifest line with its operator_note.
        $alsoAdmitted = @($placementAwaiting.ToArray()) + @($dispatchEntries)
        $haltAwaitTail = if ($alsoAdmitted.Count -gt 0) { " Also admitted: $($alsoAdmitted -join ' ; ')." } else { '' }
        Write-Output (@{ decision = 'approve'; reason = "Goal '$Goal' derives HALT: unanswered $($openHalts -join ', '). Not blocking -- control returns to the human.$haltAwaitTail$handoffTail" } | ConvertTo-Json -Compress)
        exit 0
    }
    # THE PLACEMENT-WINDOW ARM ADMITTED A STOP. Its own branch, because the fall-through
    # below says "MET on disk" and a fourth verdict reaching it would be reported as a met goal.
    if ($verdict -eq 'AWAITING_AMENDMENT_GATE') {
        # THE RELEASE SENTENCE BY CAUSE: a line with a digest is released by a mint over those bytes; an
        # UNREADABLE or UNDETERMINABLE line consults no gate, so only its cause clearing releases it.
        $awaitCaused = @($placementAwaiting.ToArray() | Where-Object { $_ -match ' (UNREADABLE|UNDETERMINABLE) ' }).Count -gt 0
        $awaitRelease = "the operator's mint of a canonical amendment-material gate over each placement's bytes is the release"
        if ($awaitCaused) { $awaitRelease += '; an UNREADABLE or UNDETERMINABLE line consults no gate and is released only once its cause clears' }
        # A manifest admitted beside it is named after the sentence: the older arm's verdict stands, and
        # the operator is owed both lines ('' when there is none, so this reason reads as it did).
        $awaitAlso = if ($dispatchEntries.Count -gt 0) { " Also admitted: $($dispatchEntries -join ' ; ')." } else { '' }
        $awaitReason = "$(@($placementAwaiting.ToArray()) -join ' ; ') -- Goal '$Goal': an untracked file under .mission/amendments/ has no live amendment-material gate over its bytes, or that could not be established -- an ADMITTED STOP (LAM-ACCEPT amendment 54, operator ruling (ii), ledger 1404). Not blocking -- $awaitRelease. Verdict: $verdictPath.$awaitAlso$handoffTail"
        Write-Output (@{ decision = 'approve'; reason = $awaitReason } | ConvertTo-Json -Compress)
        exit 0
    }
    # THE DISPATCH-MANIFEST ARM ADMITTED A STOP. Its own branch, for the placement
    # arm's reason: the fall-through below says "MET on disk".
    if ($verdict -eq 'AWAITING_DISPATCH_GATE') {
        # THE RELEASE SENTENCE BY CAUSE: a line carrying its two digests is released by a mint over those
        # bytes; one whose digest slots read UNREADABLE or UNDETERMINABLE is released only once its cause
        # clears. (A line whose ID alone is UNDETERMINABLE carries its digests, and a gate releases it.)
        $dispCaused = @($manifestAwaiting.ToArray() | Where-Object { $_ -match ' (UNREADABLE|UNDETERMINABLE); (UNREADABLE|UNDETERMINABLE)\z' }).Count -gt 0
        $dispRelease = "the operator's mint of a canonical dispatch gate over each manifest's bytes is the release"
        if ($dispCaused) { $dispRelease += '; an UNREADABLE or UNDETERMINABLE line consults no gate and is released only once its cause clears' }
        $dispReason = "$($dispatchEntries -join ' ; ') -- Goal '$Goal': an untracked round manifest under .mission/dispatches/ has no live dispatch gate over its bytes, or that could not be established -- an ADMITTED STOP (register row 352; ledger 1474 SS F, BATCH-2 WP-H (a)). Not blocking -- $dispRelease. Verdict: $verdictPath.$handoffTail"
        Write-Output (@{ decision = 'approve'; reason = $dispReason } | ConvertTo-Json -Compress)
        exit 0
    }
    # THE HANDOFF ARM ADMITTED ONE STOP, and the admission is on the record.
    if ($verdict -eq 'HANDOFF_ADMITTED') {
        $handoffReason = "$($handoffDecision.line) -- Goal '$Goal': the first line of STATUS.md is a HANDOFF head whose brief the evaluator re-derived -- ONE ADMITTED STOP (register row 353; ledger 1474 SS F, BATCH-2 WP-H (b)), recorded at $($handoffDecision.recordPath) line $($handoffRecorded.line); the same brief never admits again, and the successor's first stop is not admitted by it. Not blocking. Verdict: $verdictPath."
        Write-Output (@{ decision = 'approve'; reason = $handoffReason } | ConvertTo-Json -Compress)
        exit 0
    }
    Write-Output (@{ decision = 'approve'; reason = "Goal '$Goal' is MET on disk ($($results.Count) detector(s), 0 failing).$handoffTail" } | ConvertTo-Json -Compress)
    exit 0
}

Out-Line "mission-goal-check: $Goal -> $verdict"
# THE STATUS LINES OF AN ADMITTED PLACEMENT, one per placement, directly under the verdict.
foreach ($awaitOut in $placementAwaiting) { Out-Line "  $awaitOut" }
# ... THEN EACH ADMITTED MANIFEST's, its operator_note beneath it; THEN the handoff
# arm's one line: the ADMITTED line, or why a HANDOFF head was refused.
foreach ($dispatchOut in $manifestAwaiting) {
    Out-Line "  $dispatchOut"
    foreach ($dispatchOutNote in @($manifestNotes[$dispatchOut].ToArray())) { Out-Line "    operator_note: $dispatchOutNote" }
}
if ($verdict -eq 'HANDOFF_ADMITTED') { Out-Line "  $($handoffDecision.line)" }
elseif ($handoffRefusal) { Out-Line "  $handoffRefusal" }
Out-Line "  goal file : $goalPath"
Out-Line "  verdict   : $verdictPath"
foreach ($r in $results) {
    Out-Line "  [$(if ($r.ok) { 'ok  ' } else { 'FAIL' })] $($r.type) -- $($r.detail)"
}
if ($openHalts.Count -gt 0) { Out-Line "  OPEN HALTS: $($openHalts -join ', ')" }
if ($haltsByLegacy.Count -gt 0) { Out-Line "  LEGACY-ALLOWLISTED HALTS (answered by the goal's allowlist, not by a gate): $($haltsByLegacy -join ', ')" }
if ($haltAllowReport.Count -gt 0) { Out-Line "  LEGACY ALLOWLIST ENTRIES NOT HONOURED: $($haltAllowReport -join ' ; ')" }

# EXIT 0 IF AND ONLY IF MET. 4 is the placement-window arm's admitted stop; 5 the
# dispatch-manifest arm's and 6 the handoff arm's. An absent goal exits 2
# where the goal is searched for, as it did; NOT_MET is 1, HALT 3, and the trap 9 by hand (as a Stop
# hook the trap blocks and exits 0).
if ($verdict -eq 'MET') { exit 0 }
if ($verdict -eq 'HALT') { exit 3 }
if ($verdict -eq 'AWAITING_AMENDMENT_GATE') { exit 4 }
if ($verdict -eq 'AWAITING_DISPATCH_GATE') { exit 5 }
if ($verdict -eq 'HANDOFF_ADMITTED') { exit 6 }
exit 1
