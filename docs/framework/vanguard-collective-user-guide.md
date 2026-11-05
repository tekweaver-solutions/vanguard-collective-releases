# Vanguard Collective 1.1.0 -- the operator's guide

This guide says what the parts of the framework are, what each one records, who may write it, and
how to read what the acceptance instruments say about it. It does not repeat the procedures: the
install is in `INSTALL.md`, the shortest route is `docs/QUICKSTART.md`, and the operator's full
procedure for the toolchain -- hook registrations, the pre-push decider, the console, HALT rulings,
authentication, rollback -- is `docs/framework/LAM-INSTALL.md`. A reference below written
"LAM-INSTALL section N" is a section of that document; this guide's own parts are referred to by
their titles.

The examples use the project folder `C:\work\my-project` and the framework's own smoke mission.

## 1. The idea in one paragraph

A mission is a committed record on disk. Workers are Claude Code sessions dispatched into worktrees
of their own; independent validators judge what they hand back; a human operator holds the gates
that admit a dispatch or a publication. What the framework says about a session is meant to be
checkable on disk rather than taken from a transcript: the goal evaluator reads exit codes, files
and hashes, never prose, and the evidence of what each session did is kept by hooks the agents
cannot write.

## 2. Local Autonomous Mode

Local Autonomous Mode (LAM) is the toolchain that runs this on a single Windows workstation. Its
parts, all under `tools\lam\` in an installed project:

### The runner -- `mission-dispatch.ps1`

The runner executes one worker dispatch as a pure function. Given `-MissionRoot` and `-Dispatch`,
it runs the verify gate, asks the CLI a one-line login probe, places a fresh worktree at the commit
the dispatch declares, spawns a headless `claude -p` worker there with the role's settings file,
and when the worker exits it declares the dispatch boundary, validates the handoff, writes the
anchors from evidence and emits a completion signal. `-PlanOnly` prints the worker command line it
would use without spawning anything.

The runner owns the dispatch boundary: it writes an `OWNER` record before the spawn and a
`DISPATCH-END` record after the worker exits, both under the evidence root where the worker cannot
write. Its exit codes are the contract: `0` the dispatch ran, the handoff is valid and the anchors
are written; `2` refused before spawning (the verify gate did not pass, an input is unusable, a
dispatch gate or the authentication mode refused); `3` the worker ran but the dispatch is rejected
(an invalid handoff, among other named reasons); `4` the worker exited non-zero; `7` the login probe
did not answer OK, so nothing was spawned.

The runner refuses to dispatch until the pre-push decider is installed at the hooks path git reports
(LAM-INSTALL section 5.4). That refusal is the machinery working.

### The goal evaluator and Stop hook -- `mission-goal-check.ps1`

The goal evaluator reads a goal file, `.mission\goals\<id>.yaml`, runs each of its detectors
against disk, and writes `<id>.verdict.yaml` beside it. The verdict is one of `MET`, `NOT_MET`,
`HALT`, `AWAITING_AMENDMENT_GATE`, `AWAITING_DISPATCH_GATE`, `HANDOFF_ADMITTED` or `GOAL_ABSENT`,
and the evaluator exits 0 if and only if the verdict is `MET`. A detector this file does not
implement is refused, never skipped: a skipped detector would be a goal reporting MET over a check
nobody ran.

Run with `-AsStopHook`, the same file is the Stop hook. `NOT_MET` blocks the session from stopping
and names the failing detectors, so the session continues on evidence. `MET`, `HALT` and the
admitted stops do not block. A HALT outranks a fully satisfied goal: control returns to the human.

`mission.ps1 smoke` is the first use of it: it runs the project's installed evaluator over the
`SMOKE-MISSION` goal that `mission.ps1 init` wrote.

### The gate tool -- `mission-gate.ps1`

A gate is the physical form of a human touchpoint: a file under `.mission\gates\` that authorizes
one act. `mission-gate.ps1` composes and writes gate artifacts and lists them. Its gate-mutating
verbs -- `approve`, `reapprove`, `revoke` and `settle` -- refuse (exit 3, nothing written) when run
directly, and when any of four session conditions fires: the runner's dispatched-worker marker is
set, the Claude Code session environment is present, the session is not interactive, or the call
looks like a hook's. `list` reads and mutates nothing. "Gates", below, says what they authorize.

### The operator console -- `lam-console.ps1`

The console is how the operator mints, re-mints, revokes and settles a gate, in their own
interactive terminal:

```text
tools\lam\lam-console.ps1 approve   -Kind <kind> -Id <id> -Binds <path> -MissionRoot .
tools\lam\lam-console.ps1 reapprove -Kind <kind> -Id <id> -Binds <path> -Reason "..." -MissionRoot .
tools\lam\lam-console.ps1 revoke    -Kind <kind> -Id <id> -Reason "..." -MissionRoot .
tools\lam\lam-console.ps1 settle    -Kind push  -Id <id> -MissionRoot .
```

It composes the act without writing anything, then previews where the act lands and every byte it
would write, with its length and sha256. **Read the preview**: it is the only thing between you and
authorizing bytes you did not mean to. Then one keystroke, a secure-desktop Windows credential
prompt, and only on success the mint, through the gate tool, in the same process. It appends one
content-free line per act to `.mission-runtime\operator-acts.log`. That log records console acts,
not mints: ask the gates folder, not the log, which gates exist. LAM-INSTALL section 5.6 is the
whole of it, including the residuals it leaves open and the stage-2 ownership setup you do yourself
(section 5.6.1). Before your first real act, run the credential probe (LAM-INSTALL section 5.6.3).

### The wake starter -- `lam-wake.ps1`

A seat is an interactive Claude Code session the operator wakes in a worktree the operator
prepared. The wake starter reads the newest wake artifact under
`.mission-runtime\lam\wake\`, checks every field that reaches the command line, writes the seat's
brief into the worktree as `.wake-brief.md`, and launches `claude -n <seat> --model <model>
--effort <effort>` with one fixed opening line. It launches only a native `claude.exe`: a `.ps1`,
`.cmd` or `.bat` shim, a function or an alias is refused `CLAUDE-NOT-EXE` (exit 2, nothing written),
because a shim re-parses the command line and delivers something other than the documented one.
Put the directory holding `claude.exe` first on `PATH`. LAM-INSTALL section 5.7 describes the
starter.

## 3. The mission record

The mission lives in two planes in the project root.

**`.mission\` -- the committed record.** `mission.ps1 init` creates:

- `mission.yaml` -- the mission's identity, goal, state and declarations, every value a
  placeholder for you to fill in.
- `spec\current.txt` and `spec\v001.yaml` -- the spec. `current.txt` holds the token naming the
  current version. The first spec is accepted once with `tools\mission-spec-accept.ps1`; later
  versions take the amendment path (`tools\mission-spec-bump.ps1`). INSTALL.md section 8 says how.
- `contract\` -- the assertions the work is judged against, one file each. In the smoke mission
  they are `contract\assertions\A-1.yaml` to `A-5.yaml`, each a one-line `statement`.
- `dispatches\` -- one immutable artifact per worker dispatch: the work's entire input (its
  assertion targets, base commit, suite command, model class, tool scope, budget and goal
  condition). The worker's handoff is written beside it as `<id>.handoff.yaml`, and a superseded
  dispatch carries a supersession marker beside it.
- `handoffs\`, `inputs\`, `amendments\` -- further mission records.
- `validator-results\` -- one result per validator attempt: the validator, the assertions it
  judged, its verdict, the commit it judged and the evidence for each assertion.
- `ledger\entries.jsonl` -- the ledger (see "The ledger").
- `gates\` -- the gate artifacts (see "Gates").
- `goals\` -- goal files and their verdicts.
- `evidence\` -- the committed evidence plane (see "The evidence plane").

`init` leaves the folders empty on purpose: a stray file in `amendments\` or `dispatches\` that git
does not track reads as a placement awaiting its gate.

**`.mission-runtime\` -- the runtime plane.** Runtime state, not part of the committed record: the
framework repository and the smoke mission both keep it out of git. It holds the runtime evidence
plane, HALT files (`halts\` and `lam\`), wake artifacts, the instrument captures
(`lam\instrument-runs\`), the console's `operator-acts.log`, and each tooling seat's own folder
under `seats\`. Nothing here is durable evidence: it does not survive a fresh clone.

`install.ps1` never touches either plane.

## 4. The seats and their settings

Each role a dispatched session can take has a settings template under `tools\lam\settings\`, handed
to the CLI with `--settings` by the runner. Each carries its `permissions`, its intent under
`_authority`, and its known limits under `lam_residuals`.

**Worker** (`worker.json`). A worker implements one feature in one worktree and is visible only
through artifacts and evidence. Mode `auto`. Denied: `git push` in either shell, writes to
`.mission\gates\`, `tools\framework\` and `.claude\settings.json`, and destructive deletes. Allowed
inside the mission plane: its own evidence session and its own `.mission\dispatches\*.handoff.yaml`.
The rest of `.mission\` is closed to it by the evidence guard rather than by the permission layer,
because a permission deny cannot carry exceptions.

**Validator** (`validator.json`). A validator judges built artifacts against an assertion set and
writes one thing, its result file. Mode `dontAsk`, which auto-denies any tool not allowed: `Read`,
`Glob`, `Grep`, the two shells, and `Edit` on `tests/lam/validator-*.result.yaml` only. Denied in the
shells: `git push`, `commit`, `add`, `reset` and `checkout`, and destructive deletes (`rm -rf` in
Bash, `Remove-Item` in PowerShell). Denied to `Edit`: the two protected paths,
`.claude/settings.json` and `tools/framework/**`. The shell is allowed because a validator judges by
execution; its write surface in the shells is then bounded by the deny list alone. LAM-INSTALL section 7b says what that does not give you and names the
enforcing control: before spawning a validator the orchestrator captures the hashes of every subject
with `tools\lam\lam-validator-subjects.ps1`, and verifies them afterwards; a moved subject voids the
verdict.

**Orchestrator** (`orchestrator.json`). The orchestrator authors dispatches, schedules validators,
consumes verdicts and adjudicates immaterial amendments. Mode `auto`. It is read-only on `src\`,
denied `git push`, the gates folder, `tools\framework\` and `.claude\settings.json`. Kickoff,
material amendments, push, live witness and completion are never delegable to it: an orchestrator
that could mint a push gate would be authorizing its own irreversible act.

**Model classes.** Which model a role runs is not in these files: `model-routing.yaml` maps each
class (`coding-strong`, `qa-validator`, `coding-fast`, `small-fast`) to a model, and refuses an
unknown or not-live class. The runner's `-Role` defaults to `coding-strong`.

**Memory.** No settings key turns Claude Code's auto memory off for a dispatched role; each template
says so in `_memory_off` rather than claiming a disable it does not have. LAM-INSTALL section 7 is
the operator's check at install time.

## 5. The evidence plane

**What it is.** Four hooks registered in `.claude\settings.json` keep a record of every session
that agents cannot write:

- **PreToolUse guard** (`evidence-guard-pretooluse.ps1`), on `Write`, `Edit`, `MultiEdit`,
  `NotebookEdit`, `Bash` and `PowerShell`: refuses an agent write to a protected path and records
  every refusal. The protected set is the two evidence planes (`.mission-runtime/evidence`,
  `.mission/evidence`), the first-generation hooks and their installer and tests under
  `tools/framework/`, and `.claude/settings.json`. It also denies a command that invokes the gate
  tool with any verb but `list`.
- **PostToolUse capture** (`evidence-post-tool-use.ps1`), on every tool: one log entry per tool
  call, numbered by a call counter so that a hole in the sequence means a lost capture, with an
  explicit outcome. It never fails a tool call.
- **Stop finalizer** (`evidence-stop-finalize.ps1`): seals the session's manifest. For a session the
  runner owns it does nothing until the runner's `DISPATCH-END`, so a worker's repeated stops seal
  nothing early; the dispatch-end writer then finalizes it. Growth after finalizing reads `GREW`,
  and mutation reads `TAMPERED`.
- **PreCompact** (`evidence-pre-compact.ps1`): marks a compaction in the session log (a
  `_precompact` line, which the call counter does not count as a tool call).

The manifest's shape is `docs/framework/evidence-manifest.schema.json`.

**Why agents cannot write it.** An evidence store an agent could write would launder testimony as
evidence: a session could record that it did what it only said it did. So the evidence is written by
the hooks, harness-side, and never by an agent's tool calls -- even the worker's allow rule for its
own session is overridden by the guard. Two limits are stated, not hidden: a hook is a tripwire
inside a harness session, not a boundary outside one, and string inspection of a command raises the
cost of a bad write rather than making it impossible. Only a worktree or a sandbox makes a path
unreachable.

**The pre-push decider** is the last local layer for publication; "Gates", below, covers it.

## 6. Gates

**What a gate authorizes.** One act, bound by hash to exactly what was authorized. The kinds are
`push`, `dispatch`, `amendment-material`, `supersession`, `witness-attested`,
`completion-acceptance`, `reclose` and `halt-ruling`. A gate binds a file (`-Binds`) by its sha256,
or, for a push, one exact commit. A dispatch gate (`.mission\gates\dispatch-<id>.yaml`) admits the
runner's spawns under it, and the runner stamps it at the first spawn. A supersession gate ratifies a
supersession marker, so prior-artifact selection skips the dispatch it names. A `halt-ruling` gate
answers one HALT (see "HALTs").

**Who mints it.** The operator, through the console, in their own terminal (see "The operator
console"). Agents can compose a gate, which authorizes nothing; they cannot mint one through the
tool. Until you do the stage-2 setup of LAM-INSTALL section 5.6.1, the gates folder itself is still
writable to your own user, and a hand-written file there is the residual that setup closes.

**Push gates.** Publishing to an origin is operator-gated in every topology. A push gate names the
commit it authorizes (`authorized_tip_sha`), the origin it declares and the remote ref, carries an
expiry, and is consumed once. `settle` records its use after the push: it asks the gate's own
declared origin what it holds, and stamps the consumption.

**The pre-push decider.** `tools\evidence-hooks-next\hooks\evidence-pre-push.ps1`, installed as
`.git\hooks\pre-push` through a fixed wrapper (LAM-INSTALL section 5.4 generates and places it; do
not compose it by hand, because its sha256 is checked). By the time git runs a pre-push hook every expansion of the
command has happened, so the decider reads the real local ref, the sha about to be published, the
remote ref and what the remote holds -- spelling no longer matters. It refuses the whole push if any
ref lacks an authorization, if a ref is being deleted, or if it cannot resolve the repository; it
writes an in-flight record when it allows, so a command that published nothing can never spend a
gate. It is the strongest local layer, not a boundary: `git push --no-verify` and `core.hooksPath`
skip it.

## 7. HALTs

**What a HALT is.** A HALT file, named `HALT-<id>.md`, is a stop for the operator's word: an agent
that cannot go on without a ruling writes one and stops. The goal evaluator scans
`.mission-runtime\halts` and `.mission-runtime\lam` by default; an open HALT there makes the verdict
`HALT`, and the Stop hook lets the session end so control returns to you. The orchestrator also
raises one when a validator's subjects moved during its run (LAM-INSTALL section 7b).

**How it is resolved.** A HALT is answered if and only if a live, unrevoked `halt-ruling` gate binds
the HALT file's current bytes. Its own `**Status:**` line answers nothing. You rule through the
console:

```text
tools\lam\lam-console.ps1 approve -Kind halt-ruling -Id HALT-EX-01 -Binds .mission-runtime\halts\HALT-EX-01.md -Ruling "<your ruling>" -MissionRoot .
```

The gate is `.mission\gates\halt-ruling-HALT-EX-01.yaml`; it does not expire and is not spent by
being read. After you rule, nobody edits that HALT: any change to its bytes reopens it until you
re-rule with `reapprove`. The seat records what it did on the strength of the ruling in a
non-authoritative sidecar beside the HALT, `HALT-EX-01.ruling-citation.yaml`, which the evaluator
sets aside and never lets answer anything. `revoke` withdraws a ruling and the HALT reads open at
once.

Two further routes exist, both narrow. A goal may name HALTs answered under the old marker rule in a
`legacy_answered_allowlist`, honoured only for members of `tools\lam\legacy-halt-census.txt`, which
the framework ships empty; a project started on this framework leaves it empty. And a tooling seat's
own HALT, under `.mission-runtime\seats\<seat>\`, is closed for the evaluator by a `## RESOLVED`
block written into it, where a goal chose to scan that plane; it mints no gate and authorizes
nothing. LAM-INSTALL section 5.6.2 states both.

## 8. The ledger

`.mission\ledger\entries.jsonl` is the mission's append-only record of events: one JSON object per
line, one entry per event. An entry records its `id`, when it was created and by what
(`created_at`, `created_by`, `ts`), its `author`, its `type`, its `scope` and `scope_ref`, its
`content` and its `tags`. Ids are one per event: an append whose id already stands is refused.
Entries are appended by the mission's ceremonies -- the first-spec acceptance writes one, and the
smoke mission's close ceremony writes a `ceremony` entry -- each committed in the same atomic commit
as the change it records, with the tree held clean before it.

Two other ledgers are separate from it: the spawn ledger the runner keeps under the runtime plane,
and the project's commit ledger, to which a seat that commits appends through
`tools\lam\commit_ledger.py` (LAM-INSTALL section 11).

## 9. The smoke mission -- the worked example

**What it is.** A small, complete mission, built so the acceptance instruments have a live one to
read: a git repository `lam-smoke` with its bare origin `lam-smoke-origin.git` beside it, carrying
the residue of one dispatch run. It is not installed; the builder makes it after install, from the
plain files under `tools\lam\smoke-mission\`.

**What it contains.** A product of three files -- `src\greeting.txt`, `src\counter.ps1` and its test
`tests\test-smoke.ps1` -- judged by five assertions:

- A-1: `src/greeting.txt` exists and its first line is exactly `hello from the smoke worker`.
- A-2: `src/counter.ps1` prints exactly `3` with no arguments.
- A-3: `tests/test-smoke.ps1` exists and exits 0.
- A-4: `src/greeting.txt` has a second line reading exactly `REWORKED`.
- A-5: the dispatch anchors file records the worktree's tip and zero capture gaps.

And five dispatches, each with its handoff, anchors and evidence session:

- D-1, D-1b, D-1c -- the build, dispatched three times so the mission carries the supersession path:
  D-1 superseded by D-1b, D-1b by D-1c, each by a marker that a supersession gate ratifies. A
  superseded dispatch's record stays on disk, unedited.
- Validation: an isolation probe recorded before the validators ran; validator A passes A-1 to
  A-3; validator B fails A-4 on its first attempt, with the evidence of what it observed. (In the
  built mission each validation is the builder's own check of one assertion, and each result file
  says so.)
- D-2 -- a rework dispatch authored from validator B's failure evidence; B's second attempt passes
  A-4 and A-5.
- D-3 -- the close: the ceremony runs both clean-tree gates, appends a ledger entry and commits
  atomically.

Then the push to the origin, and a push gate composed after it, bound to the tip the origin then
holds, and revoked.

**How it is built.**

```powershell
cd C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\build-smoke-mission.ps1
```

The builder spawns no CLI worker. It performs every act the record shows, for real, with the
framework's own tools: git for the commits, worktrees, merges and push; its own check of every
assertion before it writes a validator result; the evidence hooks driven with the payloads a session
sends, including a push attempt the guard denies before any push gate exists; the gate tool's
compose-only mode for the gates; the pre-push decider; and the close ceremony. Commits up to the
pushed tip carry fixed content, identity and dates, so two builds from the same framework files give
the same commit ids. Every gate says on its first line that no operator confirmed it
(`operator_credential: injected-seam`). The builder refuses, before writing anything, a root or
origin that already exists, a root inside a `.mission` or `.mission-runtime` folder or inside a git
work tree, a path segment ending in a dot or a space, and a git older than 2.48.

**What it demonstrates.** The whole lifecycle a mission goes through, on disk, in the shape the
tools leave it: dispatch, handoff, validation, a failure answered by rework, supersession under a
gate, a ledgered close, a gated publication and its revocation -- and the evidence plane's record of
each session. The project's own `.mission\` from `init` has the same shape, empty.

## 10. The seven instruments

The acceptance instruments are `tests\lam\instrument-WP-1.ps1` to `instrument-WP-7.ps1`. Each
exercises the machinery by running it, and each obeys the same law: its exit code is its failure
count, it derives its counts from its own check recorder, and it prints no green summary on a
failing run. Except where stated, every fixture lives in a sandbox under `.mission-runtime\`, so a
run leaves nothing in the repository.

**WP-1 -- the evidence hooks.** Drives the next-generation hooks with `CLAUDE_PROJECT_DIR` pointed at
a sandbox: the Stop finalizer's ownership gate (a runner-owned session is not finalized until
`DISPATCH-END`), the PostToolUse capture's call-counter numbering and outcomes, capture-gap
accounting, and the first-generation negative suite run against the next-generation hooks.

**WP-2 -- the runner.** Drives `mission-dispatch.ps1` with stub verify and worker commands, so it
needs no network and no live agent. It proves the runner's own mechanics: the verify gate's refusal
path, the composed worker command line (from `-PlanOnly`), stream capture, `DISPATCH-END`, handoff
schema validation, anchor population, the wake emission and the exit-code discipline. That a real
worker honours that command line is WP-6's to prove.

**WP-3 -- the goal evaluator and Stop hook.** Its central check: a fabricated "all tests pass" line
with no evidence entry reads `NOT_MET`; a real instrument exit-0 entry reads `MET`; a HALT file
reads `HALT`. The evaluator must be indifferent to prose. It also drives HALT rulings, the Stop
hook's decisions, and reads the smoke mission's settings registration.

**WP-4 -- gates and the push guard.** That a gate-mutating verb refuses in every non-operator
session condition; that a push authorized for one tip is refused once a commit lands over it; that a
consumed authorization is refused. It performs real pushes, but only into throwaway bare origins it
creates under the sandbox; no push here can reach a real remote.

**WP-5 -- configuration.** Read-only: it parses and starts nothing. It checks `model-routing.yaml`,
`.worktreeinclude` and the role settings templates against closed field sets in both directions --
every role the contract names is present and no unnamed role appears -- and that LAM-INSTALL.md's
code excerpts and hash tables still match the code they describe.

**WP-6 -- the smoke mission.** Reads what the smoke mission's run left on disk and judges it: the
fixture's own integrity, the dispatch run, validator isolation, the push gate and the zero-paste
property. It is read-only on the smoke repository. One member, S-1b, performs what it grades: it
clones the smoke repository into a temporary folder, drives the real runner and one real small
worker there, and deletes the clone. **That costs one billed worker spawn per reading**, and leaves
the CLI's own per-project state for that temporary path in your user profile. With no smoke mission
found and none named, WP-6's members fail, its fixture check first.

**WP-7 -- the dashboard.** The mission-event feed (U-members: each hook and lifecycle command appends
its one line, valid against `docs\framework\mission-event.schema.json`, to a fixture's
`.mission-runtime\telemetry\events.jsonl`; host-id and the registry), the service (V-members, through its
pytest suite `tools\ui\tests`) and the dashboard (L-members, through its own build and Playwright smoke
under `ui\`). The service's tests and the dashboard's source stay in the framework's development
repository, and `mission.ps1` and `VERSION` stay in the release tree: in an installed project the V-members, the
L-members and the members whose fixtures `mission.ps1` makes skip by name.

## 11. Readings

**What a reading is.** One run of all seven instruments under one run key:

```powershell
cd C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\instrument-acceptance.ps1 -RunKey reading-1 -SmokeRoot C:\work\lam-smoke
```

The wrapper runs WP-1 to WP-7 in order through the shared instrument-run helper,
`tools\lam\lam-instrument-run.ps1`, which records a capture of each: under
`.mission-runtime\lam\instrument-runs\`, `<key>.instrument-WP-<n>.stdout.txt` -- a provenance header
(the run key, the commit, whether the tree was clean, the instrument's sha256, the exit code, the
body's size and sha256) and then the instrument's output verbatim -- and `<key>.instrument-WP-<n>.tally.txt`.
`-Root` names the checkout to run (default: the one the script sits in); `-SmokeRoot` is handed to
the instruments as `LAM_SMOKE_ROOT`, and without it that variable is cleared for the run, so an
inherited value cannot steer a reading unseen. A key that already names a capture is refused
(exit 9): a reading is never overwritten. A whole reading takes about an hour. Take it with
`VANGUARD_AUTH_MODE` unset: the instruments were measured under the default.

The wrapper prints the reading's context (`RUNKEY`, `ROOT`, `HEAD`, `BRANCH`, `PORCELAIN`,
`PATH-DERIVATION`, `STARTED`), one block per instrument beginning `---- WP-<n> exit=<code>
seconds=<s>`, then `ENDED`, `HEAD-AFTER`, `PORCELAIN-AFTER`, `CAPTURES` -- every capture written
since `STARTED`, with its size and sha256 -- and `SUMMARY`, one `WP-<n> exit=<code>` line each.

**How to read a CHECKS line.** Each instrument ends on its own count line, in one of three forms:

```text
 WP-<n>: all <n> checks passed.
 WP-<n>: <f> of <n> checks FAILED.
 WP-<n>: <p> of <n> checks passed, <s> SKIPPED -- a skip is not a pass; see the [SKIP] line(s) above.
```

(the FAILED form may add `  (<s> SKIPPED.)`). The helper reads the last such line and records it as
one line of the tally file -- its first line, since the instruments print no TALLY line -- before
the closing `EXIT` line:

```text
CHECKS instrument=WP-3 result=passed_with_skips checks=<n> passed=<p> failed=0 skipped=<s> lines=1 exit_code_agrees=True
EXIT exit_code=0 ran=True tally_count=0 captured_at=<UTC time>
```

`lines` counts how many count lines the output carried; `exit_code_agrees` says whether the
instrument's exit code is the one its count line implies (0 for a pass, the failure count for a
failure). A count line whose numbers no instrument could print is not read at all.

**What the results mean.**

- `passed` -- every member was measured and passed.
- `FAILED` -- `failed` members failed, and the exit code is that number. Each failure is a `[FAIL]
  <member> -- <title>` line in the stdout capture, with its detail; read those.
- `passed_with_skips` -- nothing failed, and `skipped` members could not be measured in this
  checkout. The exit code is 0, but **a skip is not a pass**: the summary withholds the word "all".
- **A named SKIP** -- a member whose clause could not be measured here. Its face reads `[SKIP]
  <member> -- <title>`, and its detail leads with `SKIPPED:` and the reason: what was missing and
  where it was looked for. Where a member could measure some of its rows, it still shows them, and a
  row that was measured and missed fails the member: a measured miss outranks an unmeasurable row.

**Why skips are expected on a fresh project.** A skip names an environment, not a defect. A
reading of a fresh install of this release -- a new git project with a bare origin, the install with
its Python set, `mission init`, the smoke mission built, the container engine down -- failed nothing
and showed fifty-nine named skips, each with its reason on its face:

- **No project acceptance record: WP-1 H-12, WP-2 R-16 and R-B, WP-3 C-1v, C-1w and C-2d.** Each
  measures against a project's own acceptance record, `docs/framework/LAM-ACCEPT.md`, which no
  release after 0.2.0 ships: the record is neither in the checkout nor in its history.
- **No venv with pytest: WP-2 R-57, WP-3 C-1k and C-1be.** Each runs a fixture's pytest in the first
  of `src\.venv` and `tools\.venv` (the primary checkout's too, from a worktree) that has a
  `Scripts\python.exe`; the install's `tools\.venv` holds the dashboard's packages and no pytest, so
  each skips, naming it. With pytest installed there, or a `src\.venv` that has it, they are measured.
- **The dashboard's tests and source not installed: WP-7 V-1 to V-20 and L-1 to L-16.** The service's
  pytest suite and the dashboard's source stay in the framework's development repository.
- **The release tree's `mission.ps1` and `VERSION` not installed: WP-7 F-0, U-4, U-5, U-10, U-13, U-14,
  U-15 and U-16.** Their fixtures are fresh checkouts `mission.ps1 init` makes, and one reads `VERSION`;
  the members that read only the smoke mission are measured.
- **No goal-check registration file: WP-3 C-2c.** There is no `.claude\settings.local.json` in the
  checkout, nor in the primary checkout when the reading runs in a worktree. Once that file exists
  the member is measured: it must register a command Stop hook that runs `mission-goal-check.ps1`
  with `-Goal <id>`, that goal on disk, or the member fails.
- **No HALT on the runtime plane: WP-3 C-3e.** The live drive reads the `HALT-*` files under the
  primary checkout's `.mission-runtime\halts` and `.mission-runtime\lam`; with none there, or no
  plane at all, there is nothing live to drive. Where HALTs stand, its census row still has nothing
  to read while `tools\lam\legacy-halt-census.txt` is empty, as the framework ships it, so the member
  stays a named SKIP unless one of the rows it measured missed.
- **The container engine down: WP-3 C-1aw.** It measures what a goal reads with the engine up, so it
  skips while the engine cannot be reached. With the engine up, **WP-3 C-1bd** skips in its place: it
  measures what a goal reads with the engine really down, so it skips while the engine's named pipe
  (`\\.\pipe\dockerDesktopLinuxEngine`) is among the host's pipes, or while the pipes cannot be listed.
- **No spawn ledger yet: WP-4 T-42.** Its live row reads the primary checkout's
  `.mission-runtime\lam\spawn-ledger.jsonl`, which a project's runner writes when it first
  dispatches; with none there it skips. Once one stands, T-42 fails: its audit holds the ledger's
  first 372 lines to a prefix pinned from the ledger of the project the framework was extracted
  from, which no other project's ledger matches (the release notes' known limits).
- **Records of the project the framework was extracted from: WP-4 T-53 and T-54.** Each re-read a
  seat brief and runtime records of that project, which are not part of this distribution.

Three members that failed on a fresh install of a build before 1.0.0 were cured in 1.0.0: WP-1
H-26, now that
`mission init` adds the project's ignore rules for `.claude/settings.local.json` and
`.claude/worktrees/`; WP-3 C-2e, whose comparison with the base evaluator's strings read changed
`mission-goal-check.ps1` strings in that build, now restored; and WP-4 T-42, which reads the project's live spawn ledger and is now a named
skip until the project's runner has written one.

Other environments add their own named skips: members that need the engine answering skip when no
`docker` is on `PATH` or its pipe is not there (the rows that need no engine are measured anyway); a
project with no `origin` remote skips the member that mints a push gate; and with no smoke mission
built and none named, WP-2's and WP-3's smoke members skip while WP-6 fails, so build it first. A
smoke root named with `-SmokeRoot` is always measured.

**A failure on a fresh install is not expected.** A `FAILED` result names its members; read their
`[FAIL]` detail before anything else.

**Comparing readings.** A reading taken in a linked worktree equals the primary checkout's, or names
its dependence as a skip whose reason says where it stood. To compare two, run the wrapper in each
with the same smoke mission and compare their `CHECKS` lines field by field (LAM-INSTALL
section 10).

## 12. The dashboard -- `vanguard ui`

The dashboard is a read-only, local view of every mission registered on this machine -- ADR-045 in the
local-modes design document (section 11.6), which supersedes ADR-029 for the human-facing Mission Control
surface. It owns no truth: `.mission\` and the evidence plane stay the record, and the dashboard is a
projection of the projects' event feeds that can be deleted and rebuilt from them at any time. It sends
nothing to an agent, writes nothing into a project, and holds no cost figure.

**What it shows.** Three screens.

- **Fleet**: tiles for the fleet (missions in flight, open errors, active sessions, assertions green), then
  one card per mission, those that need attention first: its state, current milestone, last activity,
  assertions and the error that ranks highest, naming the artifact.
- **Project**: the mission's header tiles; milestone progress; features and their assertions; the open
  sessions and dispatches; the spec timeline; the last verify, its scope shown beside its verdict; and the
  open errors ranked by severity, each with the `source_path@sha256` of the line it came from.
- **Stats**: Green -- green assertions over all of them, the headline; the pass rate of those evaluated,
  green over green and red, always labelled so; dispatches finalized against PARTIAL; validator rounds
  confirmed against refuted; HALTs raised and resolved and the mean time to resolve; the tool-call non-zero
  exit rate, or "not captured" where no exit code was captured; and the time spent on each milestone.

Every figure carries its formula and the window it was read over, and is computed when it is asked for,
never stored. Every tile carries a badge naming what it was read as of -- the stream, its last `seq` and
commit -- and a stream that has fallen behind is marked stale, never shown as current. The errors are a
closed set: an open HALT (a blocking error only when its own severity is critical, high or blocking), a
PARTIAL manifest, a testimony conflict, a failed verify, an expired gate, a refuted assertion, and main
ahead of origin beyond N days (`--ahead-days`, 7 by default).

**Where it reads from.** Each checkout's mission-event feed, `.mission-runtime\telemetry\events.jsonl`:
append-only, never committed, one line per event, appended by the hooks and the lifecycle commands, each
line valid against `docs\framework\mission-event.schema.json` (expanded-schemas section 14) and naming the
`source_path@sha256` it reports; a line without it is rejected and counted. The service tails every
registered feed into a disposable projection, `ui.db`, in the Vanguard home; `vanguard ui --rebuild`
deletes it and regenerates it from the feeds.

**The registry.** The Vanguard home is `%USERPROFILE%\.vanguard\` (or the folder `VANGUARD_HOME` names, or
`--home`). It holds `host-id`, this machine's id, made once, and `projects.yaml`, one row per registered
checkout -- `host_id`, `checkout_path`, `mission_id`, `registered_at`, `framework_version` -- appended by
`mission init`, by `mission.ps1 register -Target <checkout>` (a mission made before the feed existed, or a
worktree made by hand, which is a stream of its own), and by `install.ps1` over a project whose mission
already has its feed folder. Rows are never pruned: a row whose checkout is gone is shown stale. Two
checkouts of one mission are grouped by `mission_id` on the Fleet screen.

**Starting it.** From the project, after the install put its Python set in `tools\.venv` (INSTALL.md
section 5):

```powershell
C:\work\my-project\tools\ui\vanguard.cmd ui
```

-- or `vanguard ui` with `C:\work\my-project\tools\ui` on `PATH`. It prints
`vanguard ui: http://127.0.0.1:8765/  (home <the Vanguard home>)` and serves the dashboard there, with
live updates, until it is stopped; `--port` names another port. Version 1 serves loopback only: a request
whose Host is not loopback (`127.0.0.1`, `localhost` or `[::1]`) is answered 421 with no body by design, so
binding another address with `--host` serves nothing -- the flag is reserved for the v2 hub.

**Stopping it.** On Windows the service's catchable stops are Ctrl+C and Ctrl+Break: either closes every
open live stream, releases `ui.db` and the port, prints `vanguard ui: stopped (SIGINT)` (or `SIGBREAK`)
and exits 0. SIGTERM is the POSIX signal; an external TerminateProcess -- `Stop-Process`, Task Manager's
End task -- cannot be handled, so the service ends with no line of its own and may leave `ui.db`'s
write-ahead files beside it.

## 13. Authentication, briefly

`VANGUARD_AUTH_MODE` in the shell that starts the toolchain decides how every CLI it starts
authenticates: unset, nothing is checked, and the subscription Claude Code is signed in with is used
only when no credential is in the environment (an `ANTHROPIC_API_KEY`, a bearer token or a
cloud-provider selector left in the shell is used by print mode instead, by Claude Code's own
precedence); `subscription`, the same with any other credential refused; `api-key`, the key in
`ANTHROPIC_API_KEY`, in the environment only. A refusal is `AUTH-MODE-<CODE>`, exit 2, before any
CLI that calls a model starts. `docs/QUICKSTART.md` step 5 and LAM-INSTALL section 7c have the
details.

## 14. Where to go next

- `INSTALL.md` -- install, verify, upgrade, `mission init`, `mission smoke` and the dashboard's Python set.
- `docs/QUICKSTART.md` -- the shortest route through all of it.
- `docs/framework/LAM-INSTALL.md` -- the operator's procedure, including the complete operator
  install sequence. Read it whole before its step 1.
