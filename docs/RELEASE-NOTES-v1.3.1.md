# Vanguard Collective 1.3.1 -- release notes

1.3.1 supersedes 1.3.0. Free to use under LICENSE; support by subscription: support@tekweaver.ca. It is the release of
batch RELEASE-5: the dashboard's Python set in a folder of its own, Windows PowerShell children under PowerShell 7, the
host registry row after a work-tree upgrade and at spawn, the dashboard reading what the record holds, and a seat that
can wait on one act of the operator's. What this release does not do comes first.

## 1. Known limits

- **Two chains the shell cure does not reach.** The framework's hooks under a Claude Code session started from a
  PowerShell 7 terminal, and its pre-push hook under a `git push` typed at a PowerShell 7 prompt, are not cured in 1.3.1
  and were not measured; until 1.4, start Claude Code and `git push` from Windows PowerShell 5.1, Git Bash or the desktop
  app.
- **An install or upgrade whose Python set step cannot complete.** With no CPython 3.14 on the machine, or no network to
  PyPI, an install or an upgrade still leaves every file and `framework.lock` in place, exits 4 and prints the `pip`
  command that builds `tools\ui\.venv`, and `vanguard ui` does not start until that command has been run (section 2.1).
- **The snapshot writer's cost.** The snapshot writer now reads the close tool's and the stop evaluator's own rules, and
  takes longer. Measured on a fresh project of each release (the release ZIP installed into a new git project, the empty mission `mission init` writes, `mission register`), with one verb that runs the snapshot writer, `tools\mission-ledger-append.ps1` (a lesson row): 11 runs each, interleaved, each its own Windows PowerShell 5.1 process timed from its start to its exit, start-up included, the derived state unchanged so no snapshot line was appended -- 1.3.1 a median of 1036 ms (1026 to 1095 ms), 1.3.0 a median of 788 ms (771 to 829 ms); a bare `powershell -NoProfile` start-up took a median of 132 ms on the same machine. It derives the whole
  state on every lifecycle command, also where nothing changed and no snapshot is written. The dispatch reading grows
  faster than the number of dispatches: each dispatch scans every file name in the dispatch folder, so a mission with
  many dispatches pays more per dispatch. This is accepted for 1.3.1 and recorded for 1.4.
- **What the dashboard does not read (group B).** A snapshot is written only by a lifecycle command, and only when the
  mission's derived state has changed; until a project's first 1.3.1 snapshot, its pages show each new reading as not
  in this snapshot. The remedy is `mission.ps1 register -Target <project>` from the release folder, once per project,
  after the project is upgraded (section 2.4, "Freshness"). A validator round numbered 0 is not shown. A Stop hook
  goal given by position rather than by `-Goal`, or registered only in the user's own settings, is not read: the HALT
  card then uses the evaluator's default scan and says that no goal was read. The snapshot's agreement flag (`halt_reading.agrees`,
  which no page shows) reads false where an open HALT lies in a goal's declared folder that overlaps a folder the scan
  already reads: the evaluator lists that file once for each folder that holds it, the snapshot writer once.
- **A goal path with a space.** Where a goal file or the stop evaluator lies outside the project and cannot be read,
  and its path holds a space, part of that path can appear in the snapshot's goal reason and on the page.
- **A work tree with no snapshot of its own.** Its HALTs are placed by a rule restated from the stop evaluator's, which
  differs from the evaluator's in two shapes, and its reading can turn on another checkout's snapshot. The main
  checkout is not affected once it has a snapshot of its own, which `mission init` and `mission.ps1 register` write.
  Remedy: run `mission.ps1 register -Target <work tree>`, which writes the work tree's own
  snapshot.
- **The operator wait (section 2.5) covers one act at a time.** A host act and a ruling that is not a gate still need a
  HALT; a HALT outranks a wait; `settled` is for a push only; a second wait while one is unreleased is refused.
- **The sealed hooks, recorded for 1.4 and not changed here.** The hooks capture no tool exit codes, because the harness
  gives the post-tool hook none: every `tool_call` line carries `exit_code: null`, and the failure rate reads "exit code
  not captured". A `dispatch_finalized` line names the session (`session-D-x`), not the dispatch, because the runner
  gives its worker the session id as the dispatch id; the dashboard joins the two and the feed lines stay as they are
  written. A session with a failed tool call always leaves a capture-gap record: the post-tool hook is not called for a
  failed call, so its manifest is sealed FINALIZED with `partial: true`.
- **The zero-host-data gate's SOFT residual.** `tools/lam/gate-host-data.ps1` over the release tree reads SOFT 6783 -- B3-FIXTURE-BASE 2512, B3-OTHER 409, B3-TESTS 1116, FIXTURE-ID 481, HEX-UNRESOLVED 231, UUID 2034; over the expanded ZIP SOFT 6961 -- B3-FIXTURE-BASE 2512, B3-OTHER 378, B3-TESTS 1116, FIXTURE-ID 481, HEX-UNRESOLVED 450, UUID 2024.
  SOFT hits are listed for review and never block: bare row, ledger and gate numbers, hex tokens neither repository
  resolves, and UUIDs, most of them inside the pinned bases under `tests/` and their data. The HARD reading at the tag,
  over the operator's own pattern file, is the operator's gate.
- **1.3.0's known limits stand** as its notes, section 1, give them, but where section 2 below says this release changed
  them.

**The acceptance instruments under PowerShell 7 (row 538).** The acceptance runner (`tools\lam\lam-instrument-run.ps1`) starts each instrument with `& powershell`, so WP-1, WP-2, WP-3 and WP-4 run under Windows PowerShell 5.1 whatever shell starts the runner. Their reading under a PowerShell 7 host was not taken for 1.3.1, and these notes claim none. The 1.3.0 notes said WP-1 to WP-4 were measured under both shells, and no capture of them under a PowerShell 7 host is held.

## 2. What changed since 1.3.0

### 2.1 The dashboard's Python set has its own folder: tools\ui\.venv (rows 561 and 563)

**What moved.** 1.1.0 to 1.3.0 installed the dashboard's 22 pinned packages into `tools\.venv`. That folder is
also where uv (and other Python tools) keep the environment of a project living under `tools\`, so a host project there
and the framework shared one environment: the suite launcher's `uv run` re-synced it to the host's lock and the
dashboard stopped starting, and the host's suite ran on the dashboard's CPython 3.14. From 1.3.1 the installer installs
the set into `tools\ui\.venv`, beside the `vanguard` command, with the same contract: CPython 3.14 on 64-bit Windows, the
pinned set, `pip --require-hashes --only-binary :all:`. `vanguard.cmd`, the validator-result transcriber and the LOM
dispatch entry run that folder's interpreter; `release.ps1` reads the third-party notices from it. A new
installer-owned file, `tools\ui\.gitignore`, keeps the folder out of `git status`; it is the one rule that does, since
the installer makes the folder without the `.gitignore` CPython's `venv` would otherwise write into it.

**What an upgrade from 1.3.0 does.** The files are upgraded as usual (section 3), `tools\ui\.gitignore` among the
installed. Then the Python set step finds no `tools\ui\.venv`, makes it with `-Python`, `py -3.14` or `python` on `PATH`
(each held to CPython 3.14 win-amd64), and installs the set from PyPI. `-WhatIf` names the new folder and writes nothing;
`-Verify` afterwards reads 0 differences. If the step cannot complete (no 3.14, no network) the files and the lock
stand, the run exits 4 and prints the `pip` command for `tools\ui\.venv` -- and `vanguard ui` does not start until it is
run, since the upgraded command names the new folder.

**Repairing the dashboard's environment.** Where `tools\ui\.venv` is missing or incomplete, run the command the
installer printed, from the project (INSTALL.md section 5):

```powershell
<project>\tools\ui\.venv\Scripts\python.exe -m pip install --require-hashes --only-binary :all: -r <project>\tools\ui\requirements.txt
```

after making the folder with CPython 3.14 (`py -3.14 -m venv --without-scm-ignore-files <project>\tools\ui\.venv`), or
run `install.ps1` again with `-Python <a CPython 3.14 python.exe>`.

**What tools\.venv now is.** The host's. The installer never reads, writes, moves or deletes it, and no framework tool,
hook test or command runs its interpreter (the acceptance instruments WP-2 and WP-3 take it, as one of the project's own
environments, to run a fixture's pytest under it when it holds an interpreter). An upgrade leaves it exactly as it
stood, the 1.3.0 set still in it (measured over an upgrade of the 1.3.0 ZIP's install: its `pyvenv.cfg` and every
dist-info name and `METADATA` sha256 equal before and after). It is yours to keep, to rebuild from your own project's lock on the interpreter your
project wants, or to delete.

**The suite launcher with no uv project under tools\ (RA-6).** On a fresh 1.3.1 install with no `pyproject.toml` or
`uv.lock` under `tools\`, `Invoke-SuiteDefaultRun` (its `uv run python -m pytest -q -rfE -p no:cacheprovider`
unchanged, cwd `tools\`) exits 1 with `<interpreter>: No module named pytest`, reading 0 runnable tests and no
collection error, and creates, removes and changes no file under the project; `uv run` outside a project takes the first
interpreter uv finds on the machine, not the dashboard's. The dashboard's environment is unchanged after it. On the
1.3.0 layout the same run took `tools\.venv` -- the dashboard's own environment -- and failed the same way. The green
gate needs the host's own uv project under `tools\`. Under Windows PowerShell 5.1 the 1.3.1 launcher
returns there, and its reading is PowerShell 7's: exit 1, 0 runnable, no collection error, the same `No module
named pytest` line, no file created, removed or changed, the dashboard's environment unchanged (installer falsifier
case ra6, under both shells).

### 2.2 Windows PowerShell children under PowerShell 7 (rows 562 and 538)

**What failed.** A Windows PowerShell 5.1 process started below a program that is not PowerShell inherits the
`PSModulePath` of whatever started that program. When that was PowerShell 7, the path names 7's module folders first.
Measured below pwsh 7.7.0, with Windows PowerShell 5.1.26100 as the child, each command probed alone in its own child,
through Python and through cmd alike: the six script functions of 5.1's own `Microsoft.PowerShell.Utility` probed
(`Get-FileHash`, `New-TemporaryFile`, `New-Guid`, `Format-Hex`, `Import-PowerShellDataFile`, `ConvertFrom-SddlString`)
are not recognized, and the three `Microsoft.PowerShell.Security` commands probed (`Get-Acl`, `Get-ExecutionPolicy`,
`ConvertTo-SecureString`) are found in a module that could not be loaded; with no `PSModulePath` in the child's
environment each of the nine runs. The framework's own tests in `tools\tests\cli` start such children: at 1.3.0, from a
PowerShell 7 parent, `test_close_milestone_lam_roster.py` read 19 failed, 9 passed, 1 skipped; from Git Bash, 28 passed,
1 skipped. PowerShell 7 corrects the path for a `powershell` it starts with `&` (installer falsifier case ra10 probes
it), and not for one it starts with `Start-Process`: below pwsh 7.7.0, a 5.1 child started with `Start-Process`
inherited 7's module path, and the same nine commands, each probed alone, read as through Python and cmd -- the six
not recognized, the three found in a module that could not be loaded; with no `PSModulePath` each of the nine ran.

**What 1.3.1 does.** The suite launcher (`Invoke-SuiteDefaultRun` in `tools\mission-lib.ps1`) runs its uv line with no
`PSModulePath` in the child's environment and puts it back after; `tools\tests\cli\conftest.py` takes it out of
pytest's own environment; `tests\lam\wp7-group-b.py` hands its Windows PowerShell child an environment without it, as
`tools\lam\commit_ledger.py` already did. Given none, Windows PowerShell 5.1 builds its own module path.
At 1.3.1 the same roster file reads 28 passed, 1 skipped from a PowerShell 7 parent, as from Git Bash. Every other installer-owned file that starts a `powershell` or `pwsh` child is listed with its
reason in the installer falsifier's case ra10.

**The suite launcher under Windows PowerShell 5.1.** In 1.3.1, `Invoke-SuiteDefaultRun` takes each line of uv's output
as text, with `ErrorActionPreference` Continue for that call alone, so a line uv or the interpreter writes to stderr does
not end the call; the arguments given to uv, its working directory and how the tally is read are unchanged. Over one host
uv project whose run writes to stderr, a passing suite and a failing one, the launcher under 5.1 returns the exit code
and every tally field PowerShell 7 returns (installer falsifier cases ra9 and ra15).

### 2.3 The host registry row after a work-tree upgrade, and a work tree's own row (rows 530 and 567)

**An upgrade made in a work tree, then merged (row 530).** A registered project upgraded in a git work tree and merged
into its registered checkout arrives there with every file and `framework.lock` already the new release's, so the next
installer run at the root reads `already installed` and writes nothing under the project. In 1.3.0 that run ended
before the host registration, and the root's row in `projects.yaml` kept the version it was first registered at. From
1.3.1 the same run rewrites that row's `framework_version` to the lock's version, by the same one-value edit an upgrade
makes and under the same conditions (a mission, the feed's folder, a row for the root); every other field and every
other checkout's row stay byte for byte. `-WhatIf` prints the planned line first, `the target's row in <registry> would
be rewritten: framework_version '<old>' -> '<new>' (its other fields kept)`; a registry the run cannot write leaves the
row and exits 5, naming it, as an upgrade does. Nothing is appended by that run. Measured over a synthetic project
upgraded from 1.2.1 to 1.2.2 in a work tree and merged (installer falsifier case ra12); the 1.3.0 installer left
`'1.2.1'` there. Run the installer once at the root after such a merge to correct a row 1.3.0 left behind.

**A work tree's row at spawn (row 567).** A dispatch that cuts a work tree registers it as a checkout of its own. In
1.3.0 that row's `framework_version` came from a `VERSION` file no installed checkout has, and was written `''`. From
1.3.1 it is the version the work tree's `framework.lock` records, or its primary checkout's where the work tree has
none (a project that does not track the lock); `null`, never `''`, where neither stands. Measured from the installed
`tools\lam\mission-telemetry.ps1` (installer falsifier case ra13). `mission init` and `mission.ps1 register` share that
writer, so their rows also carry the target's lock version where it has one, else the release's `VERSION` (case
ra20). Rows already written `''` are not rewritten by this writer; how the dashboard shows them is not part of this
release.

### 2.4 The dashboard shows what the record holds (rows 541 and 564)

**Verdicts.** In 1.3.0 the dashboard took an assertion's status only from `.mission\validator-results`, a folder the
LAM runner no longer writes to, so assertions a validator had judged on the spawn ledger read as not judged. From 1.3.1
the snapshot reads each assertion from the record the close tool trusts: the spawn ledger's `complete` line that binds
the validator's result file by its hash, resolved by the close tool's own reader (`Resolve-LamRosterRecord`), so the
dashboard and `mission close-milestone` agree on what passed. An assertion the ledger does not bind keeps the old
folder's verdict. Every round the ledger records is shown, in the order the close tool gives it (a round written as a
label or a numeral included), with its verdict, and an assertion not judged says why, naming both places it looked. A
round is shown without a verdict only where the close tool itself names it as the round it refuses; where it refuses an
assertion without naming a round, every round it orders stays shown -- as "no verdict" where its ledger line states
none. Each milestone's row also counts its judged assertions.

**Cards.** The spec card reads the mission's current spec version from `.mission\spec\current.txt`, so a close that
bumps the spec without a `spec_bumped` line is read all the same. The verify card shows the verify run's own verdict
and, beside it, how the goal evaluator read that same run -- in the same checkout, by the detector that ran verify
against that run's artifact -- with the boundary it disclosed; a refusal the evaluator admitted is no longer shown as a
blocking error. The HALT card counts as open exactly what the stop evaluator counts as unanswered when it runs for the
mission's governing goal -- the one goal the project's Stop hook is registered for, read from the Stop hook's command
line in the project's `.claude\settings.json` or `.claude\settings.local.json` -- that goal's own HALT folders and its
legacy allowlist included. A legacy HALT that goal's allowlist answers is shown as answered by the goal's legacy
allowlist, counted apart from the HALTs a ruling gate answers; one edited after its allowlist entry was written reads
open, as the evaluator reads it; an allowlist in another goal file, which no Stop hook runs, answers nothing. Where no
single governing goal can be read -- none registered, more than one, or a goal file at neither place the evaluator
looks -- the card uses the evaluator's default scan and says that no goal was read. HALT files the evaluator does not
count (under a copied mission, under scratch copies, or a tool file) are counted apart as set aside, never as open,
including one raised after the newest snapshot. Each HALT is decided by the newest snapshot of the checkout that holds
it, so a work tree's own snapshot never moves a HALT of the main checkout; a work tree no snapshot has read yet (the LAM
runner registers each work tree it cuts without writing one) has each HALT decided by its place, by a rule restated from
the evaluator's default rule (section 1), and the card says that checkout has no snapshot of its own. The card, the open-HALTs figure and the error
list count one set. The card reads `Open`, `Answered`, `Answered by the goal's legacy allowlist`, `Set aside, not
counted by the stop rule`, `Mean TTR`, `Median TTR`, `Oldest open`, and beneath them `HALT rule read for goal <G>, the
goal the mission's Stop hook runs (named in .claude/settings.local.json; goal file .mission/goals/<G>.yaml) -- its
declared folders and its legacy allowlist included` (or `No governing goal was read -- <why>; the stop evaluator's
default scan of .mission-runtime/halts and .mission-runtime/lam is shown`); the HALTs tile adds `<n> HALTs answered by
the legacy allowlist of goal <G>`. The framework-version card compares only registry rows whose folder still exists: a
row of a removed work tree is listed as removed and takes no part, a row whose version was never recorded says so, and
no row is ever deleted. A removed checkout is no longer counted as a stale stream.

**Dispatches.** A dispatch is open only when a worker it spawned is running: spawned and not finished, with nothing
beside it. A refusal before spawn creates nothing, so a dispatch is read by its latest attempt that was not refused
before its spawn -- a second spawn of the same id refused for id reuse never hides the worker that ran before it -- and
it reads refused before spawn only where every attempt was. Every other dispatch says what its files hold: handed off,
superseded, handoff rejected, complete with its handoff rejected, aborted, refused before spawn, complete with a
refusal, refused by the runner after its run, complete without a handoff, or not spawned. The feed's `dispatch_opened`
and `dispatch_finalized` lines of one dispatch carry different ids (`D-x` and `session-D-x`); the dashboard now joins
them on the session, so a finished dispatch reads finished. "Partial" is the evidence manifest's word. It is shown on
the session the manifest belongs to, with its count of capture gaps, and the Stats page counts dispatches finalized
whatever their manifest; it is never a state of the dispatch. A capture gap is a record the hooks write when a session's
evidence store and the session's own record of its calls disagree. That can be a tool-call slot allocated with no log
entry, the session's failed tool calls (the post-tool hook is never called for a failed call, and one record covers
them all), more or fewer calls than the transcript shows, or a transcript the hooks could not compare at all. Where the
feed holds no exit code the page says "exit code not captured", never a blank or a zero.

**Freshness.** The Project and Stats pages say which snapshot their readings come from -- its sequence number and when
it was written -- and how many feed lines came after it. A snapshot is written only by a lifecycle command, and only
when the mission's derived state has changed. To write a fresh one, run from the release folder:

```powershell
.\mission.ps1 register -Target <project>
```

After an upgrade to 1.3.1, run it once in each project: until then the pages show each new reading as not in this
snapshot, with that command, and nothing fails. Upgrade the project to 1.3.1 before you run the command in it: the
command writes its snapshot with the release folder's 1.3.1 tools, but every later snapshot is written by the project's
own verbs, so a project still on 1.3.0's tools would go back to 1.3.0 snapshots at its next verb. The command prints
nothing about the snapshot; where the mission's state cannot be derived it writes none and logs the cause to the hooks'
`hook-errors.log`, and the pages' snapshot line is where to see whether a fresh one was written.

**The snapshot's new keys.** The snapshot writer adds five optional `mission_snapshot` fields (schema 1.2, additive;
expanded-schemas §14): `assertion_reading`, `goal_verdicts`, `halt_reading`, `milestone_tally` and `spec_version`. A
reader without them reads the snapshot as before.

### 2.5 Waiting on the operator (ADR-046)

A seat that has done its part and needs one act of yours can now stop on a single line instead of placing a holding
file or raising a HALT.

**How a goal opts in.** It declares `- type: operator_wait_present`. Without that line nothing changes; the smoke goal
does not declare it.

**The line.** The seat writes the first line of `.mission-runtime\lam\STATUS.md` as
`OPERATOR WAIT gate <kind> <id> <minted|settled>`. The stop is then admitted as `AWAITING_OPERATOR` (exit 7 by hand)
for as long as that one gate condition is unmet. The verdict file names the wait, the gate, and what was read.

**What releases each wait.**

| condition | released by |
|---|---|
| `minted` | your mint of that gate |
| `settled` (push only) | your console settle after your push |

**A settle of an amendment-material or reclose gate is not a wait.** A line naming `settled` on those kinds is refused,
and that case stays a HALT: the settle observes a commit the seat makes, so the seat could withhold it. A seat may
still wait `minted` on such a gate. To decide a wait, the evaluator only reads files in the mission; it starts no
process and writes no temporary file.

**Once released, a wait never admits again.** The evaluator records each release, and each admission, in
`.mission-runtime\lam\operator-wait-releases.jsonl`. That file needs no cleanup and is never read as a HALT.

**What it does not cover.**

- A host act and a ruling that is not a gate still need a HALT.
- A HALT outranks a wait.
- Anything the evaluator cannot read for certain is refused and leaves the goal to decide, including:
  - free text, or a log line or a file in place of a gate;
  - a second wait while one is unreleased;
  - a wait no act of yours could release, such as a push gate the seat consumed itself.

**The one misuse it knowingly admits.** A seat can name a gate you never mean to mint and stop with its work undone.
That is bounded by:

- your goal's opt-in;
- the claim, printed word for word in the verdict and the hook's reason;
- the record;
- one wait at a time, which holds until you mint that gate.

The user guide's section on the operator wait says how a goal declares it and how a wait is released.

## 3. Upgrading from 1.3.0

Over a project 1.3.0 installed, in your own Windows PowerShell 5.1 terminal, from the expanded release
(`C:\dl\vanguard-collective-v1.3.1`, after INSTALL.md sections 1 to 4) or from a clone at the tag `v1.3.1`:

1. **Run `install.ps1`** against the project as INSTALL.md sections 5 and 6 write it: `-WhatIf` first if you like, then
   `-ReleaseZip <the ZIP>` (no `-ReleaseZip` from a clone). One refusal refuses the whole upgrade and names itself;
   nothing is then written. Over a project the 1.3.0 ZIP installed and nobody edited since, the upgrade ends:

   ```text
   install.ps1: done: written=31 already-identical=344 kept=11 retired=5 refused=0
   ```

   -- 25 files upgraded and 6 installed (`tools\ui\.gitignore`, and 5 of the dashboard's built files under new names), the 11 templates and host-configuration files kept, and 5 of the dashboard's old built files retired (left in place, dropped from the lock); in a project left as 1.3.0 installed it, no kept file differs, so no NOTICE is printed. `-WhatIf` prints the same counts as `planned:`. `release.ps1`'s own line, which it derives from the two releases' installer-owned sets and
   requires here, is

   ```text
   install.ps1: done: written=43 already-identical=332 kept=11 retired=0 refused=0
   ```

   (upgraded 23, installed 20): it reads 1.3.0's set from the tag's tree, whose manifest names none of the files a
   release generates, so it counts `ui/dist/` and `THIRD-PARTY-NOTICES` installed and none retired.
2. **The Python set moves.** The upgrade makes `tools\ui\.venv` and installs the pinned set there (section 2.1);
   `tools\.venv`, the host's, is left as it stood. Without CPython 3.14 or the network the run exits 4 after the files and the lock,
   and prints the command that completes the set.
3. **Write a fresh snapshot.** Run `.\mission.ps1 register -Target <project>` from the release folder once in each
   upgraded project (section 2.4, "Freshness").
4. **Verify**: `install.ps1 -Target <the project> -Verify` reads `386 file(s) listed, 0 difference(s)`.

## 4. The release, counted

- **The members rule.** The ZIP holds 429 files: the 409 files of the commit the tag `v1.3.1` names that the release carries -- every one but the dashboard's private source under `ui/` and the service's tests under `tools/ui/tests/` -- the 18 files of `ui/dist/`, `THIRD-PARTY-NOTICES` and `RELEASE`. `MEMBERS.sha256` lists each with its sha256, 429 lines, and `SHA256SUMS` names the ZIP and `MEMBERS.sha256`.
- **Installed into an empty folder**, `install.ps1` writes the 386 installer-owned files (MOVE 375, TEMPLATE 8, HOST-CONFIG 3) and a framework.lock of
  387 lines, and `-Verify` reads `verify: 386 file(s) listed, 0 difference(s); eol lf=373 crlf=1 mixed=0 binary=12.`
- **Upgraded from 1.3.0**, section 3's lines; `release.ps1` derives its own from the two releases' installer-owned
  sets and refuses a build whose notes do not carry it.
- **`THIRD-PARTY-NOTICES`** names 128 packages: 106 in `ui/dist/` (103 production packages and 3 build-time ones) and the 22 of the Python set;
  their licences are MIT (100), ISC (13), BSD-3-Clause (7), Apache-2.0 (2), OFL-1.1 (2), 0BSD (1), BSD-2-Clause (1),
  MIT AND ISC (1) and PSF-2.0 (1).
