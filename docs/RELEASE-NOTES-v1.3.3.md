# Vanguard Collective 1.3.3 -- release notes

1.3.3 supersedes 1.3.2. These notes say what changed since 1.3.2; a reader coming from 1.3.0 reads the 1.3.2 notes
first, which this release carries unedited. Free to use under LICENSE; support by subscription: support@tekweaver.ca. It
is the release of batch UI-3: the dashboard's pages brought to what the feed records -- milestone times observed at
snapshots, and the verify cards led by the stop evaluator's reading, which now reaches the feed as a line of its own --
the dispatch runner keeping the validators archive, and a register command that runs as pasted and says what it wrote.
What this release does not do comes first.

## 1. Known limits

- **Two chains the shell cure does not reach.** The framework's hooks under a Claude Code session started from a
  PowerShell 7 terminal, and its pre-push hook under a `git push` typed at a PowerShell 7 prompt, are not cured in 1.3.3
  either -- the sealed hooks are byte for byte 1.3.2's -- and were not measured; until 1.4, start Claude Code and
  `git push` from Windows PowerShell 5.1.
- **An install or upgrade whose Python set step cannot complete.** With no CPython 3.14 on the machine, or no network to
  PyPI, an install or an upgrade still leaves every file and `framework.lock` in place, exits 4 and prints the two
  commands that build `tools\ui\.venv`, and `vanguard ui` does not start until they have been run (the 1.3.2 notes,
  section 2.1; `install.ps1` is unchanged since 1.3.2).
- **An upgrade from 1.3.2 started from PowerShell 7 exits 4.** Run from a PowerShell 7 parent over a project 1.3.2
  installed, the installer reads the project's `tools\ui\.venv` as an interpreter that does not run and leaves it
  untouched: `-WhatIf` says so, and the run writes every file and `framework.lock` -- the counts of section 3 -- prints
  `PYTHON SET NOT INSTALLED` and exits 4. The set 1.3.2 installed stays as it stood, `-Verify` reads 0 differences and
  the project's dashboard starts. `install.ps1` is unchanged since 1.3.2. Remedy: run the upgrade from Windows
  PowerShell 5.1, where it ends with exit 0.
- **A missing dashboard environment on a project already at this version.** Running `install.ps1` again over such a
  project -- with `-Python` or without -- builds nothing: a run over a target already at this version writes nothing.
  The two commands of the 1.3.2 notes, section 2.1, build it. Where the project folder's name holds a character outside
  the console's code page (a curly quote among them) and the Python set step fails, the installer's printed commands
  show that name wrongly and do not paste; use INSTALL.md section 5's commands instead, the folder written in, any
  single quote in it written twice.
- **The snapshot writer's cost.** The snapshot writer reads the close tool's and the stop evaluator's own rules, and, for
  closed work whose result file is gone, the validators archive, which from 1.3.3 grows by one file for each result the
  runner files (section 2.4). It takes about as long as 1.3.2's. Measured on a fresh project of each release (the release's ZIP installed into a new git project -- for 1.3.3, a build whose installed files are the released ZIP's --, the empty mission `mission init` writes, `mission register`), with one verb that runs the snapshot writer, `tools\mission-ledger-append.ps1` (a lesson row): 11 runs each, interleaved, each its own Windows PowerShell 5.1 process timed from its start to its exit, start-up included, the derived state unchanged so no snapshot line was appended -- 1.3.3 a median of 1174 ms (1156 to 1207 ms), 1.3.2 a median of 1178 ms (1145 to 2103 ms, one run of 2103 ms and the other ten 1145 to 1208 ms); a bare `powershell -NoProfile` start-up took a median of 134 ms on the same machine. It derives the whole state on every lifecycle command, also where
  nothing changed and no snapshot is written. The dispatch reading grows faster than the number of dispatches: each
  dispatch scans every file name in the dispatch folder, so a mission with many dispatches pays more per dispatch. This
  is accepted for 1.3.3 and recorded for 1.4.
- **The stop evaluation's added cost.** Each evaluation now appends its `goal_verdict` line (section 2.3) after its
  verdict file is written and before the Stop hook prints its decision: it loads the feed's writer in a child scope and
  adds one line to the feed. Measured on fresh projects made as for the snapshot writer's cost above, in the same interleaved runs: one evaluation of the goal `mission init` writes (`SMOKE-MISSION`), as the Stop hook runs it (`tools\lam\mission-goal-check.ps1 -Goal SMOKE-MISSION -MissionRoot <project> -AsStopHook`, the Stop event on its input), 11 runs each, each its own Windows PowerShell 5.1 process timed from its start to its exit, start-up included -- 1.3.3 a median of 922 ms (901 to 939 ms), each run adding its one `goal_verdict` line, 1.3.2 a median of 660 ms (646 to 721 ms), 262 ms more. Where a checkout is registered but its feed folder is missing or its feed
  cannot be written, each evaluation also adds one line to the hooks' `hook-errors.log`. This is accepted for 1.3.3.
- **What the dashboard does not read (group B).** A snapshot is written only by a lifecycle command, and only when the
  mission's derived state has changed; until a project's first snapshot written by 1.3.2 or later, its pages show each
  reading such a snapshot adds as not in this snapshot. The remedy is the command the pages print,
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 register -Target` with the project's folder, run
  once from the release folder after the project is upgraded (section 3). A validator round numbered 0 is not shown. A
  Stop hook goal given by position rather than by `-Goal`, or registered only in the user's own settings, is not read:
  the HALT card then uses the evaluator's default scan and says that no goal was read. The snapshot's agreement flag
  (`halt_reading.agrees`, which no page shows) reads false where an open HALT lies in a goal's declared folder that
  overlaps a folder the scan already reads: the evaluator lists that file once for each folder that holds it, the
  snapshot writer once.
- **The verify cards after an upgrade, until the first evaluation.** The verify cards read the stop evaluator's reading
  from its `goal_verdict` lines and from the newest snapshot. Until the first evaluation after the upgrade -- the Stop
  hook at a session's end, or the evaluator run by hand -- writes a line, they read it from the snapshot alone, as 1.3.2
  did: a verify run newer than the newest snapshot then shows its own verdict, a refusal blocking and listed among the
  errors, until a line or a snapshot holds the evaluator's reading of it. Remedy: one evaluation after the upgrade
  (section 3).
- **A goal file outside the checkout.** An evaluation whose goal file lies outside the checkout (`-GoalFile` naming
  another folder) writes no `goal_verdict` line: the verdict file beside that goal cannot be a feed line's source, so the
  verify cards have no line of that goal to read. Remedy: keep the goal file in the project's `.mission\goals\`.
- **A second `goal_verdict` line for one evaluation.** Where the evaluator's error handler fires after an evaluation's
  line was written and rewrites the verdict file (`NOT_MET`, with an `evaluator_error` detector), a second line follows
  for that evaluation, so the feed's newest line of the goal is the verdict on disk; the dashboard reads a goal's newest
  line. A reader that expects one line per evaluation finds two there.
- **A goal path with a space.** Where a goal file or the stop evaluator lies outside the project and cannot be read,
  and its path holds a space, part of that path can appear in the snapshot's goal reason and on the page.
- **A work tree with no snapshot of its own.** Its HALTs are placed by a rule restated from the stop evaluator's, which
  does not match the evaluator's in every shape, and its reading can turn on another checkout's snapshot. The main
  checkout is not affected once it has a snapshot of its own, which `mission init` and `mission.ps1 register` write.
  Remedy: run `mission.ps1 register -Target <work tree>`, which writes the work tree's own snapshot.
- **Milestone times where more than one live checkout writes snapshots.** A checkout that never showed a milestone
  closed changes nothing about that milestone (section 2.2), but where a mission's snapshots come from more than one live
  checkout, a lagging checkout's snapshot can still move another milestone's clock, give a Milestones row its title and
  assertion counts, and name the milestone-progress tile's current milestone, whose formula text still says each status
  is read from the latest snapshot's map; this is recorded for a later release.
- **Milestone times rest on snapshots alone.** The feed carries no signal of work started other than a snapshot: a
  milestone is taken as started when a snapshot shows it the mission's next milestone or active, so its window opens at
  that snapshot, whenever work on it began; where the snapshot's current milestone names a planned milestone while an
  earlier one is active, both run at once; and a milestone that goes from planned to passed without ever being the next
  or seen active has no time (`not recorded: passed without being seen started`). A signal of work started is recorded
  for a later release.
- **The folder tail of a checkout directly under the user's folder.** The Framework version card shows each checkout by
  the last two parts of its folder (section 2.1); for a checkout directly under the user's own folder those are the
  user's folder and the project's, `<user folder>\<project>`, as the tails of the other cards already show them. This is
  recorded for a later release.
- **Closed work read from kept evidence.** From 1.3.3 the dispatch runner files each result it places in the validators
  archive (section 2.4). Results placed before 1.3.3 are not filed retroactively: for those, a host still copies each
  placed result file, under its own name, into any folder under `.mission-runtime\lam\validators` before the next
  round's preparation removes the working copy. An assertion held on the record alone shows the verdict the spawn
  ledger's `complete` line states; its bytes were not verified, and the page marks it so. An archive copy that cannot be
  opened, or a folder under the archive that cannot be listed, leaves the assertion not judged where no other copy holds
  the bound bytes, and its reason says so. Links (junctions, symbolic links) under the archive are not followed.
  `mission close-milestone` still demands the working copy: the archive is the dashboard's reading only.
- **A result file named another way, and a dispatch id ending in a dot.** The archive's reader finds a copy by the name
  `validator-<assertion id>.result.yaml`. A result file declared under another name of that shape -- one with a round
  suffix, `validator-A-1-r2.result.yaml` -- is filed with no note, but the reader does not find it by that name; a name
  outside the shape is filed with a note that says the reader will not look for it. A dispatch id ending in a dot
  (`D-1.`) is printed with the dot in the filed path, while Windows makes the folder without it (`D-1`). Remedy: declare
  each validator's result as `validator-<assertion id>.result.yaml`, and end no dispatch id with a dot.
- **Evidence paths beyond 260 characters where Windows long paths are off.** The Project page shows a long evidence path
  whole once it is read (section 2.5), but 1.3.3 adds no long-path handling to the reader or to the close tool: where
  Windows long paths are off, a working or archive copy whose path is longer than 260 characters may read as absent --
  record alone, or not judged -- as it could in 1.3.2.
- **The kept-evidence panel's length.** The Project page prints each judged assertion's evidence, its reason and its
  path whole; a mission with many closed assertions makes that list long, and 1.3.3 does not shorten it.
- **The smoke mission's replayed feed holds no `dispatch_opened` line.** The feed `tests\lam\wp7-smoke-feed.ps1` replays
  from the smoke mission's history, a snapshot per commit, carries snapshot lines alone, so over it the dashboard counts
  no dispatch in the smoke milestone's window; the dispatch count of section 2.2 is shown over that replay only with
  `dispatch_opened` lines added to it. A replay that carries the dispatch runner's own lines is recorded for a later
  release.
- **The operator wait (the 1.3.2 notes, section 2.5) covers one act at a time.** A host act and a ruling that is not a
  gate still need a HALT; a HALT outranks a wait; `settled` is for a push only; a second wait while one is unreleased is
  refused.
- **The sealed hooks, recorded for 1.4 and not changed here.** The hooks capture no tool exit codes, because the harness
  gives the post-tool hook none: every `tool_call` line carries `exit_code: null`. From 1.3.3 no page shows a tool-call
  failure rate (section 2.1); the API keeps its figure, `not captured` while no exit code is. A `dispatch_finalized`
  line names the session (`session-D-x`), not the dispatch, because the runner gives its worker the session id as the
  dispatch id; the dashboard joins the two and the feed lines stay as they are written. A session with a failed tool
  call always leaves a capture-gap record: the post-tool hook is not called for a failed call, so its manifest is sealed
  FINALIZED with `partial: true`.
- **The zero-host-data gate's SOFT residual.** `tools/lam/gate-host-data.ps1` lists SOFT hits over the release tree and
  over the expanded ZIP for review, and they never block: bare row, ledger and gate numbers, hex tokens neither repository
  resolves, and UUIDs, most of them inside the pinned bases under `tests/` and their data. The HARD reading at the tag,
  over the operator's own pattern file, is the operator's gate, and its SOFT counts are read in the same run.
- **The limits the 1.3.2 notes state in their section 2 stand** where section 2.6 below does not correct them: the
  suite launcher's green gate needs the host's own uv project under `tools\`; registry rows already written `''` are not
  rewritten; where a page cannot know which folder (a mission with no snapshot and more than one checkout) it says so in
  words; the operator wait's bounds (their section 2.5); and a close still needs the working copy.
- **1.3.0's known limits stand** as its notes, section 1, give them, but where the 1.3.2 notes, section 2, or section 2
  below say a release changed them.

**The acceptance instruments under PowerShell 7 (row 538).** The acceptance runner (`tools\lam\lam-instrument-run.ps1`) starts each instrument with `& powershell`, so WP-1, WP-2, WP-3 and WP-4 run under Windows PowerShell 5.1 whatever shell starts the runner. Their reading under a PowerShell 7 host was not taken for 1.3.3, and these notes claim none. The 1.3.0 notes said WP-1 to WP-4 were measured under both shells, and no capture of them under a PowerShell 7 host is held.

## 2. What changed since 1.3.2

1.3.3 adds sections 2.1 to 2.5 and corrects the places of the 1.3.2 notes it makes false (section 2.6). Every figure in
sections 2 to 4 was taken for 1.3.3; section 1 states the Python set step's exit and printed commands as the 1.3.2
notes do, `install.ps1` being unchanged since 1.3.2.

### 2.1 The pages (rows 587, 589, 590, 594, 595, 596, 601 and 602)

**The tool-call failure tile is gone.** The hooks still capture no tool exit code (section 1, "The sealed hooks"), so
the Stats screens' tile could only ever say so; it is removed, and the words "exit code not captured" appear on no page.
The API keeps `tool_call_failure_rate`, reading `not captured` while no exit code is. A session's row under Live
activity on the Project page says a failed count only where an exit code was captured, beside the calls that carry none
(`<n> failed` and `<m> calls without an exit code`); where none is captured it shows no failure figure at all. Capturing
exit codes needs the change to the sealed hooks recorded for 1.4.

**The page is headed by the mission's name.** The Project screens' head is the mission's name, its id small beside it,
and the browser tab reads `<name> · Mission Control` while a mission is shown.

**Removed checkouts are one line.** The streams under the head list each live checkout on its own line and the removed
ones on one line with their count (`<n> removed checkouts`), opened to list them.

**The validator chart.** "Validator confirmed vs refuted" reads the rounds the snapshot's validator results hold as well
as the feed's `assertion_result` lines; in 1.3.2 it read the feed's lines alone and was empty on a feed whose rounds the
snapshot holds. Each round it draws is labelled by its number.

**One mean time to resolve.** The Stats tile and the HALT card show one figure, the HALT card's: the mean over the
answered HALTs whose raising and answering times are both known, and the tile says how many HALTs it is over
(`over <n> measured`).

**"Last verify" and "Verify detail".** The Project page's tile is "Last verify" and the full card "Verify detail"; both
read the newest mission verify. An installer check -- the `verify_result` `install.ps1 -Verify` writes, the installer's
check of the framework files against `framework.lock` -- never takes either: in 1.3.2 a newer installer check took the
tile. The installer's newest check is its own line on the Framework version card.

**The evaluator's word leads.** Where the stop evaluator read the shown verify run against the artifact its detector
declares, both verify faces lead with the evaluator's word -- `PASS-DIB` where it admitted a refused run -- and the
verify's own verdict, its checks and its divergences stand beneath, with whether the goal admitted that run. A run the
evaluator admitted is no error: it is in no list and no count, and raises no "need attention". In 1.3.2 such a run was
not shown as blocking, but the errors still listed it. A run with no admitting reading stays an error as in 1.3.2.

**The errors read the mission's verify.** The errors list reads the same newest mission verify the cards show; an
installer check, older or newer, never stands in for it. An installer check with differences is its own critical line
(a testimony conflict, the class's fixed severity), in the installer's words: `the installer's check of the framework
files against framework.lock (verdict <verdict>) found <n> divergence(s) from the lock`; an installer check that did
not pass with none is a failed verify; an installer `PASS` lists nothing. A framework file that drifts from the lock
therefore raises "need attention" and ranks first. Remedy for such a line: `install.ps1 -Target <project> -Verify`
names each differing file.

**The divergences card says whose run it lists.** "Verify divergences" keeps its reading, the newest verify of either
kind, and says which and when: `Lists the installer's check of the framework files against framework.lock, <time>` or
`Lists the mission's verify against <artifact>, <time>`.

**The framework version card shows folder tails.** Each checkout's row shows the last two parts of its folder, whole,
with no elision mark and no home folder on screen; opening the row (a click, or focus and Enter) shows the whole path.
Nothing needs a hover. Section 1 names the one case where a tail holds the user's folder.

**Smaller faces.** A milestone's `<n> on the record alone` is said only where the count is above zero (row 587); tiles,
as-of lines and the framework card wrap rather than clip (row 589); session ids are shown whole (row 590).

### 2.2 Milestone times, observed at snapshots (row 588)

**What 1.3.2 did.** The times came from the snapshot writer's `started_ts` and `done_ts`: a milestone could show no time
or `0s`, a later writer's close could stand for an earlier one, and the Dispatches column showed no value.

**What 1.3.3 does.** One derivation serves the Milestones table, the Stats page's milestone strip, "Elapsed time per
milestone" and "Slowest milestones across the fleet". Each figure's formula text states its rule, and these are its
words:

- *Times observed at snapshots, in feed order.* A writer's `started_ts` is never read.
- *Which milestone runs.* "The mission's next milestone is the snapshot's current milestone when that milestone is
  listed and not closed; only otherwise the earliest milestone not closed, in the milestones' natural order (passed and
  withdrawn are closed; a withdrawn one is never the next)." A milestone "is taken as started when it became the
  mission's next milestone or was seen active, whichever a snapshot shows first: its window opens at that snapshot's ts."
- *A window closes* "at the first snapshot showing the milestone closed: at its done_ts when that lies at or after the
  window's opening, else at that snapshot's ts." A window that ended because the milestone stopped being the next, with
  no close, is not counted.
- *Not recorded.* "A milestone whose first appearance in the feed is already closed has no time (not recorded: closed
  before the feed began) until it is reopened."
- *Not started.* "A planned milestone that is not the next has no running window (not started when it has no other)."
- *Reopening.* "A closed milestone is reopened -- seen active, or again the next -- only by a snapshot of a checkout that
  itself showed it closed; a checkout that never showed it closed changes nothing about it. Reopened, it runs again and
  closed_at is its latest close."
- *Elapsed* is "the sum of its windows: those that ended in a close, and the open one to the clock while it runs" -- the
  clock being the mission feed's last ts -- marked running while one is open; "a planned milestone keeps the sum and
  count of its windows that ended in a close."
- *Dispatches* are "the dispatch_opened lines whose ts lies within one of its windows, null where no window is
  measured."

The charts draw the measured milestones only and say how many are not recorded and how many not started.

**What an upgrade shows.** The rule reads the whole feed, so after an upgrade every milestone the feed first shows closed
reads `not recorded: closed before the feed began` where 1.3.2 showed a dash or a writer's time, and the elapsed time of
each measured milestone changes to the sum of its windows. Section 1 states the limits.

### 2.3 The stop evaluator's reading in the feed: `goal_verdict`

**The line.** At every evaluation -- the Stop hook's, or by hand -- the stop evaluator (`tools\lam\mission-goal-check.ps1`)
appends one line of the new kind `goal_verdict` once its verdict file is complete on disk, through the feed's one
writer, unchanged; its source is the goal's verdict file (`.mission\goals\<goal>.verdict.yaml`), so its sha256 binds the
verdict's bytes. A new installer-owned file, `tools\lam\goal-verdict-event.ps1`, carries the append; the evaluation's
verdict, exit code, printed lines and verdict file are those 1.3.2's evaluator gives. A dispatched worker's stop is no
evaluation and writes none. Section 1 states the one case with a second line, the case with none, and the cost. An
evaluation started from a PowerShell 7 parent other than by `&` -- by a program that parent started -- writes none either,
its verdict and exit code unchanged: its Windows PowerShell 5.1 process, given that parent's environment, cannot load
`Get-FileHash`, and the hooks' `hook-errors.log` gains one line saying the append failed; started with `&` from
PowerShell 7, or from Windows PowerShell 5.1, it writes its line -- the class of section 1's first limit.

**The payload, as the schema names it** (`docs/framework/mission-event.schema.json`; expanded-schemas §14): `goal`,
`verdict`, `evaluated_at` and `hook_or_hand`, as the verdict file holds them, and `verify_readings`, one entry per
`verify_pass_or_dib` detector whose detail is a verify reading, in the goal's order: `detector` (its position, 1-based),
`ok`, `exit_code`, `word` (`PASS`, `PASS-DIB` or `REFUSE`), `admits` (ok, and the word `PASS` or `PASS-DIB`), `admitted`
(the subjects admitted, else `[]`), `boundary` (the evaluator's reason, with no host path, or null), `against` (the
artifact the detector declared, relative where it lies under the mission root, or null), `against_checked`, and
`report_path` and `report_sha256` -- the report the verify run wrote, which is its `verify_result` line's `source_path`
and `sha256`, both null where the evaluator does not hold them. No transcript text and no credential.

**The schema version does not move.** The lines carry the feed writer's `schema_version` as it is, `1.2`; the kind is
additive since framework 1.3.3, and a reader tells lines apart by kind. A dashboard of 1.3.2 or earlier counts these
lines among its unknown kinds and fails nothing; a 1.3.3 dashboard no longer lists them among a stream's unknown kinds.

**What the dashboard reads from it.** The verify cards read each goal's newest line from the verify run's own stream,
beside the newest snapshot's goal verdicts. Where a line names the report and sha256 of the run, it read that run
exactly, and a line naming another run's report never reads it; where it names none, it is joined to a run on the terms
1.3.2 used for the snapshot's verdicts. Of every reading of a run, the newest evaluation's is shown. So an admitted
verify shows admitted right after the stop that admitted it, with no snapshot written. A goal's newest line is its
reading: a later evaluation of the same goal that read no verify run removes the earlier run's reading, as a fresh
snapshot always did. A line and a snapshot can word one verdict's `against` and `boundary` differently: the line writes
a declared artifact under the mission root relative and replaces a host path in the boundary, where the snapshot keeps
the goal file's and the verdict's own text.

### 2.4 The runner keeps the validators archive (rows 568 and 569)

**Where.** Each time the dispatch runner places a validator's result in the project (its `PLACED` line), it also files a
byte-equal copy, its creation and last-write times kept, at
`.mission-runtime\lam\validators\<dispatch id>\<name>.result.yaml` -- the archive the dashboard has read since 1.3.2 for
closed work whose working copy is gone. A dispatch id that does not begin with a letter or a digit, or holds a
character other than letters, digits, `.`, `_` and `-`, is filed under `dispatch-<the first 16 hex of its sha256>`. The
copy is made in the runner's own process, never by an agent's tool call: written under a temporary name beside its
place, hashed, renamed without overwrite, and hashed again.

**It never overwrites.** Where a file of that name with those bytes already lies anywhere under the archive, nothing is
written. A file of that name with other bytes at the dispatch's own place is never overwritten: the new bytes are kept
beside it, at `<dispatch id>\<first 16 hex of their sha256>\<name>.result.yaml`, and the dashboard, which tries every
file of the name and selects by the hash the spawn ledger's `complete` line binds, still finds the one bound.

**One printed line, never a failed dispatch.** Right after its `PLACED` line the runner prints one of:

```text
mission-dispatch: validator result FILED in the validators archive at <path> -- sha256 <sha256>, byte-equal to the placed copy, its times kept
mission-dispatch: validator result ALREADY FILED in the validators archive at <path> -- the same name and the same bytes (sha256 <sha256>); nothing written
mission-dispatch: validator result NOT FILED in the validators archive -- <reason>; the placement stands and this dispatch does not fail for it
```

A failure to file -- a file or a link where a folder of the archive's path goes, a folder that cannot be written -- is
that one `NOT FILED` line with its reason: the placement and the dispatch's outcome stand, and its exit code and anchors
do not change. A placement the runner refuses files nothing.

**What it replaces.** The 1.3.2 notes' how-to, "How a host keeps an archive" (their section 2.6), is replaced: a host
no longer copies each placed result by hand. Results placed before 1.3.3 are not archived retroactively; for those the
hand copy stands (section 1). A hand copy made before the runner files equal bytes makes it write nothing; one made after
leaves a second equal copy, which the reader accepts. The archive grows by one file for each result filed, and nothing
prunes it.

**What the page shows.** An assertion of a closed milestone whose working copy is removed after a 1.3.3 placement reads
*archive copy*, with its path, where 1.3.2 read *record alone*. `mission close-milestone` still demands the working copy.

### 2.5 The command and the text (rows 577, 579, 581 and 582)

**`vanguard ui` with its output piped or redirected (row 577).** Under code page 1252, with a home folder whose name
holds a character outside it, `vanguard ui` with its output piped or redirected no longer exits at start-up with
`UnicodeEncodeError`: such a character is printed as an escape (`\u03a9`), and the dashboard serves. A console is not
affected.

**The register command the pages print runs as pasted (row 579).** The Project and Stats screens print, to be run from
the release folder, the form in which INSTALL.md runs the release's scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 register -Target '<project>'
```

with the checkout's own folder in `<project>`'s place, quoted as before -- every character PowerShell reads as a single
quote written twice, every space kept. Under a Restricted execution policy it runs as pasted.

**What `mission.ps1 register` says (row 582).** Its line names the checkout it registered and says what it wrote:
`host-id made at` or `read from`, `a row added to` or `already a row in ..., kept as it is`, and the feed folder `made`
or `already there` -- never `made` of a folder that stood, as 1.3.2 printed. A new `snapshot:` line says whether a
`mission_snapshot` line was appended:

```text
mission.ps1: registered on this host: the checkout C:\work\my-project -- host_id <id> (host-id read from <Vanguard home>\host-id), already a row in <Vanguard home>\projects.yaml, kept as it is (the mission-event feed folder .mission-runtime/telemetry/ already there)
mission.ps1:   .gitignore unchanged: it already ignores /.mission-runtime/
mission.ps1:   snapshot: a mission_snapshot line appended to the mission-event feed, .mission-runtime/telemetry/events.jsonl
```

`snapshot: no mission_snapshot line appended` covers both a state that did not change and one that could not be derived:
the command cannot tell them apart, and the cause of the second is still in `hook-errors.log`. The line still begins
`mission.ps1: registered on this host:`, so anything that parsed 1.3.2's line must follow the rest; `mission init`'s
registration line changes the same way, indented, without a `snapshot:` line. INSTALL.md section 7 gives both forms.

**Long evidence paths are shown whole (row 581).** An assertion's evidence path and reason of 250 characters or more
wrap inside their panel on the Project page instead of running past it. Section 1 states where such a path may not be
read.

### 2.6 Places of the 1.3.2 notes that 1.3.3 corrects

`docs/RELEASE-NOTES-v1.3.2.md` ships unedited, as 1.3.2 released it. These places no longer hold:

- Section 1, "What the dashboard does not read (group B)", and section 2.4, "Freshness", give the command the pages
  print as `.\mission.ps1 register -Target '<project>'`. From 1.3.3 the pages print
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 register -Target '<project>'`, the folder quoted as
  before (section 2.5).
- Section 2.4, "Freshness", says "The command prints nothing about the snapshot" and that the pages' snapshot line is
  where to see whether a fresh one was written. From 1.3.3 the command's `snapshot:` line says whether it appended one;
  the pages' snapshot line names the snapshot they read (section 2.5).
- Section 1, "The sealed hooks", says the failure rate reads "exit code not captured", and section 2.4, "Dispatches",
  ends "Where the feed holds no exit code the page says "exit code not captured", never a blank or a zero." From 1.3.3
  no page shows a tool-call failure rate or those words; a session's row says a failed count only where an exit code was
  captured (section 2.1).
- Section 2.4, "Cards", says the verify card shows the verify run's own verdict "and, beside it, how the goal evaluator
  read that same run". From 1.3.3 the card is "Verify detail", beside the tile "Last verify", both read the newest
  mission verify, and where the evaluator read that run against its declared artifact its word leads, the run's own
  verdict beneath (section 2.1).
- Section 1, "Closed work read from kept evidence", says "No framework tool writes the validators archive in 1.3.2: a
  host keeps it, by copying each placed result file there", and section 2.6, "How a host keeps an archive", gives that
  how-to. From 1.3.3 the dispatch runner files each placed result; a hand copy is for results placed before 1.3.3 only
  (section 2.4).
- Section 2.6, "The record alone is marked", says each milestone's tally line counts such assertions apart
  (`<n> on the record alone`). From 1.3.3 that count is said only where it is above zero (section 2.1).

## 3. Upgrading from 1.3.2

Over a project 1.3.2 installed, in your own Windows PowerShell 5.1 terminal (from PowerShell 7 this upgrade exits 4:
section 1), from the expanded release (`C:\dl\vanguard-collective-v1.3.3`, after
INSTALL.md sections 1 to 4) or from a clone at the tag `v1.3.3`:

1. **Run `install.ps1`** against the project as INSTALL.md sections 5 and 6 write it: `-WhatIf` first if you like, then
   `-ReleaseZip <the ZIP>` (no `-ReleaseZip` from a clone). One refusal refuses the whole upgrade and names itself;
   nothing is then written. Over a project the 1.3.2 ZIP installed and nobody edited since, the upgrade ends:

   ```text
   install.ps1: done: written=23 already-identical=353 kept=11 retired=5 refused=0
   ```

   -- 17 files upgraded and 6 installed (`tools\lam\goal-verdict-event.ps1`, and 5 of the dashboard's built files under new names), the 11 templates and host-configuration files kept, and 5 of the dashboard's old built files retired (left in place, dropped from the lock); in a project left as 1.3.2 installed it, no kept file differs, so no NOTICE is printed. `-WhatIf` prints the same counts as `planned:`. The dashboard's pinned Python set is the
   one 1.3.2 installed (`tools\ui\requirements.txt` is unchanged). `release.ps1`'s own line, which it derives from the
   installer-owned sets of this release and of the latest earlier release tag its history holds -- `v1.3.2` -- and
   requires here, is

   ```text
   install.ps1: done: written=35 already-identical=341 kept=11 retired=0 refused=0
   ```

   (upgraded 15, installed 20): it reads 1.3.2's set from the tag's tree, whose manifest names none of the files a release
   generates, so it counts `ui/dist/` and `THIRD-PARTY-NOTICES` installed and none retired.
2. **Restart the dashboard** if `vanguard ui` was running: the service's own files are among those upgraded.
3. **Write a fresh snapshot.** Run, from the release folder, once in each upgraded project:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 register -Target '<project>'
   ```

   It reads the mission with the upgraded tools, and its `snapshot:` line says whether it appended a snapshot; a project
   whose state has not changed since its newest snapshot gets none and needs none. Upgrade the project before you run
   it: the command writes its snapshot with the release folder's tools, but every later snapshot is written by the
   project's own verbs.
4. **Let one evaluation run.** The first stop after the upgrade -- a Claude Code session ending under the project's Stop
   hook, or the evaluator run by hand -- writes the project's first `goal_verdict` line; until then the verify cards
   read the evaluator's reading from the snapshot alone (section 1).
5. **Verify**: `install.ps1 -Target <the project> -Verify` reads `387 file(s) listed, 0 difference(s)`.

A project still on 1.3.0 upgrades the same way, from this release. What 1.3.1 and 1.3.2 changed on that path -- the
dashboard's Python set moving to `tools\ui\.venv` among it -- is in section 3 of the 1.3.2 notes; the counts that
upgrade prints are not the ones above.

## 4. The release, counted

- **The members rule.** The ZIP holds 434 files: the 414 files of the commit the tag `v1.3.3` names that the release carries -- every one but the dashboard's private source under `ui/` and the service's tests under `tools/ui/tests/` -- the 18 files of `ui/dist/`, `THIRD-PARTY-NOTICES` and `RELEASE`. `MEMBERS.sha256` lists each with its sha256, 434 lines, and `SHA256SUMS` names the ZIP and `MEMBERS.sha256`. The 1.3.2 notes are among the members, as 1.3.2 released them.
- **Installed into an empty folder**, `install.ps1` writes the 387 installer-owned files (MOVE 376, TEMPLATE 8, HOST-CONFIG 3) and a framework.lock of 388 lines; `tools\lam\goal-verdict-event.ps1` is new to
  the installer-owned set. `-Verify` reads `verify: 387 file(s) listed, 0 difference(s); eol lf=374 crlf=1 mixed=0 binary=12.`
- **Upgraded from 1.3.2**, section 3's lines; `release.ps1` derives its own from the installer-owned sets of this release
  and of `v1.3.2`, and refuses a build whose notes do not carry it.
- **`THIRD-PARTY-NOTICES`** names 128 packages: 106 in `ui/dist/` (103 production packages and 3 build-time ones) and the 22 of the Python set;
  their licences are MIT (100), ISC (13), BSD-3-Clause (7), Apache-2.0 (2), OFL-1.1 (2), 0BSD (1), BSD-2-Clause (1),
  MIT AND ISC (1) and PSF-2.0 (1).
