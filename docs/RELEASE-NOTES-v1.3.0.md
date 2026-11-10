# Vanguard Collective 1.3.0 -- release notes

1.3.0 supersedes 1.2.0. Free to use under LICENSE; support by subscription: support@tekweaver.ca. It is the release of
batch UI-2: the subagent's stop no longer read as its parent's, the session's end moved to a SessionEnd hook, the host
registry row brought along by an upgrade, PowerShell 7 and the Mark of the Web measured, and the dashboard reading, from
the feed alone, what a mission proved round by round and how long it took. What this release does not do comes first.

## 1. Known limits

- **A 1.2.0 project upgraded without the SessionEnd block writes no `session_stop`.** From 1.3.0 the Stop hook never
  writes `session_stop`; the session's one `session_stop` is SessionEnd's (section 2.2). An upgrade keeps a project's own
  `.claude/settings.json` and prints the SessionEnd block to add (section 3); until it is added, the project's sessions
  read running.
- **A session that ends without SessionEnd reads running.** A session that ends without Claude Code firing `SessionEnd`
  (the process killed, a crash), or whose `SessionEnd` line cannot be appended (named in the project's hook-errors.log,
  except when Claude Code stops the hook at its timeout), has no `session_stop`, and `vanguard ui` reads it running: no
  Stop says `session_stop` any more, and the dashboard applies no idle limit.
- **WP-1 H-26's parsed comparison, 1.3.x limits** (section 2.3; recorded by UI-2 S2's last validator round, R7-1..R7-4,
  not cured): under Windows PowerShell 5.1 a timeout one unit in the last place of a double away from the composition
  reads equal (5.1 parses a plain fraction as decimal and misrounds by one ulp; PowerShell 7 reads it unequal); a
  proposal re-encoded as UTF-16 or with a byte-order mark reads equal; a bare number or literal as a key passes the lexer
  (it adds a key, so the comparison reads unequal); some reader checks remain case-insensitive or culture-aware, with no
  verdict effect (the comparisons themselves are ordinal).
- **The zero-host-data gate's SOFT residual.** `tools/lam/gate-host-data.ps1` over the release tree reads SOFT 6735 --
  B3-FIXTURE-BASE 2512, B3-OTHER 385, B3-TESTS 1104, FIXTURE-ID 481, HEX-UNRESOLVED 226, UUID 2027; over the expanded
  ZIP SOFT 6927 -- B3-FIXTURE-BASE 2512, B3-OTHER 362, B3-TESTS 1104, FIXTURE-ID 481, HEX-UNRESOLVED 450, UUID 2018. SOFT
  hits are listed for review and never block: bare row, ledger and gate numbers, hex tokens neither repository resolves,
  and UUIDs, most of them inside the instruments' pinned bases and their data. The HARD reading at the tag, over the
  operator's own pattern file, is the operator's gate.
- **A fresh install reads named skips.** A reading of a fresh install of this release -- a new git project with a bare
  origin, the install from the ZIP (`-SkipPythonSet`), `mission init`, `mission smoke` (MET), `mission register`, the
  smoke mission built, `install.ps1 -Verify` (0 differences, one `verify_result` line on the feed), then WP-5, WP-6 and
  WP-7's F-0 and U-1 to U-52 -- failed nothing. WP-5 passed 10 of 10 and WP-6 13 of 13. Of WP-7's 53 members read, 14
  passed and 39 skipped by name: without the Python set, U-19, U-22, U-30, U-31, U-33, U-34, U-35, U-39 to U-49 and U-50's
  API and browser halves, 19 members (no `tools\.venv` interpreter to run the service on); F-0, U-4, U-5, U-10, U-13 to
  U-16 and U-25, 9 members (their fixtures are made by `mission.ps1` and read `VERSION`, which stay in the release tree);
  U-20, U-24 and U-26, 3 members (the dashboard's source is not in the release); U-28, U-29 and U-52, 3 members
  (`mission.ps1` is not installed); U-21 and U-51, 2 members (`provenance/` is not installed); U-27, 1 member (an installed
  project's `.gitignore` is its own); U-32, 1 member (no `-HardPatternFile`: the operator's HARD pattern file is never
  tracked); and U-38, 1 member (an installed project holds `framework.lock` and not the user guide, S2-AM1). WP-7's V and
  L members read the service's tests and the dashboard's source, which are not in the release.
- **1.3.x candidates, recorded, not built.** One figure per question on the per-mission Stats face: the UI-1 rounds and
  elapsed charts, read from the feed's `assertion_result` lines and `current_milestone` runs, stand beside this release's
  panels, read from the snapshot, and over a feed with no `assertion_result` line the two disagree (UI-2 S2 open decision
  8). `tests/lam/wp7-real-feed.py`'s rule R2 ("dispatch_finalized with no session_stop of its session before it") is
  worded for the order before SessionEnd; under 1.3.0 `dispatch_finalized` (Stop) precedes `session_stop` (SessionEnd),
  and no member applies the rule to a feed of that shape (open decision 3). WP-7 U-52 drives `CHANGED` and `MISSING`
  only; `kept-differs`, `REFUSED` and a kept file now equal to upstream were confirmed by reading `install.ps1`, and a
  member over a kept row and a refused path is a later row's (open decision 9).
- **1.2.0's known limits stand** as its notes, section 1, give them, but where section 2 below says this release changed
  them: PowerShell 7 and the Mark of the Web are now measured (row 522), the line-ending pin for `docs/framework/**` is
  held by installer falsifier case h11 (row 520), and the ADR citation items and the base document's whitespace-only
  lines are cured (row 523).

## 2. What changed since 1.2.0

### 2.1 Correctness (group A)

**The subagent's stop is no longer read as its parent's stop (register row 500).** In 1.2.0 the `SubagentStop` hook
appended a `session_stop` for the session its payload named. On the live harness that is the PARENT's session (a
subagent's hooks carry the parent's `session_id`), so N subagents wrote N parent stops before the parent stopped, and the
dashboard showed the orchestrator stopped while it worked. And because the harness runs an Agent call in the background,
the parent's turn could end while its subagent still worked: that Stop wrote `session_stop` and `dispatch_finalized` for
a session that went on.

From 1.3.0:
- `SubagentStop` appends a `subagent_stop` line: the subagent's `agent_id` (and `agent_type`), its `parent_session_id`
  and the parent's `dispatch_id`. Where a harness gives no agent id, it carries `subagent_ordinal` instead. It never
  appends `session_stop` or `dispatch_finalized`.
- `Stop` never appends `session_stop` (the session's end is `SessionEnd`'s, section 2.2). A Stop whose payload lists a
  background task still running is the end of the parent's turn: it appends nothing, and a seal it made is announced by
  `dispatch_finalized` at a later Stop.
- The mission-event schema is 1.2 (expanded-schemas §14): the kind `subagent_stop` is added; 1.0 and 1.1 lines are read
  as they were written.
- `vanguard ui` shows a running session's finished subagents, and marks a session whose `session_stop` is followed by
  later lines of the same session (the 1.2.0 shape) as "Stopped early" instead of showing it stopped.

The evidence store is sealed as before; only the mission-event feed's lines change. The cure was read live on Claude
Code 2.1.312 with one headless session making one Agent call, against the 1.2.0 hooks and the cured ones. The real-feed
fixture carries a 1.2.0 slice of that defect's shape, `tests/lam/fixtures/real-feed/rec-q-1.2.0.events.jsonl` (WP-7
U-31 to U-33), and its two 1.1.0 feeds are re-keyed under the slice's secret key (row 529).

**The host registry row follows an upgrade (register row 526).** In 1.2.0 an upgrade kept the project's row in
`~/.vanguard/projects.yaml` as it stood, so its `framework_version` named the version first registered (a 1.1.0 row after
the 1.2.0 upgrade), and the dashboard showed it. From 1.3.0 a run that writes rewrites that row's `framework_version` to
the release's, every other byte of the registry kept; `-WhatIf` names the rewrite as a planned act. A project with no row
is not registered by the upgrade. A registry the installer cannot write leaves the row as it was: the run names the
registry and exits 5, every file and the lock installed. WP-7 U-36 compares the row with the project's lock.

**WP-3 C-3e counts HALTs one way on both sides (register row 517).** C-3e's legacy-allowlist row compared the
evaluator's list of HALTs OPEN under the allowlist -- one entry per file -- with the OPEN HALTs counted by name, so an
exact byte copy of a HALT under a scratch subfolder of the runtime plane made the member fail. Every C-3e count is now of
distinct HALT ids (a HALT's id is its file name, read without regard to case; an exact byte copy under another path is
the same HALT), and the member states that rule on its face. Its verdict over the plane it read before is unchanged.

**`-Verify` reads a kept file made equal to its upstream as no difference (register row 518).** A kept file -- the
project's own `.claude/settings.json`, say -- that the project later made byte-equal to the release's version (by adding
the block the upgrade's NOTICE printed) was reported `CHANGED`, exit 3. `-Verify` now reports it `kept, now equal to
upstream` and counts no difference; a kept file that differs from both reads `CHANGED ... -- kept, differs from
upstream` as before, exit 3. `-Verify` writes nothing under the installed set or the lock (from 1.3.0 it appends one
line to a registered project's feed: section 2.2).

**The gate console says which clock is which (register row 512).** The console composes a gate's `created_at` once, at
preview; the feed's `gate_minted` line carries the time the artifact is written, after the confirm act, and so may trail
it. The preview now says so on its face, in one line. WP-7 U-37 reads it.

**PowerShell 7 and the Mark of the Web, measured (register row 522).** Under PowerShell 7.6.9 the 1.2.0 installer wrote
the root `.gitattributes` as not-written into an empty project, and refused a clone source outright: a `$null` handed to
`SetEnvironmentVariable` leaves the variable set and empty under 7, so the git variables it meant to clear made git exit
128. The smoke builder and WP-7 looked for `powershell.exe` beside `pwsh.exe`, and WP-6 read timestamps and a stream as
5.1 parses them. Each is cured; installer falsifier case p7 runs the install path under both shells to the same counts.
`Expand-Archive` carries no `Zone.Identifier` stream to the members under either shell (measured on the 1.2.0 ZIP);
the installer now names every marked source file it reads before the plan, and after the write says how many written
files carry the stream (0), removing any it finds (case h7, under both shells). `tools/lam/commit_ledger.py`'s Windows
PowerShell child no longer inherits PowerShell 7's module path. The acceptance instruments WP-1 to WP-4, with the
acceptance wrapper, were measured by the operator under both shells at b472b8e, whose code this release carries
(INSTALL.md section 3).

**The dashboard states its tail window (register row 525).** On resume the service compares a feed's first line and
the last 4096 bytes before where it stopped; a feed truncated and regrown with both unchanged is not seen as replaced.
That limit is now stated in the user guide's section 12, is the service setting `--tail-window-bytes`, and is shown on
the Fleet stats screen. WP-7 U-38 reads all three in the framework repository, and skips by name in an installed
project (one with `framework.lock`), which does not carry the user guide. Where there is no `framework.lock`, a missing
user guide fails U-38 instead of skipping it.

**The release tree's line-ending pin, the kept set and the citations (register rows 520, 524, 523).** Installer
falsifier case h11 reads every `framework.lock` row recorded `lf` or `crlf` against the release file and the installed
file (row 520). INSTALL.md section 6 and the 1.2.0 notes' item 3.2 name the kept set whole -- `.claude/settings.json`
and any other file the installer reports kept (row 524, case d524). The five ambiguous bare ADR citations, the v2.4
DELTA's PASS-DIB number, the schema's ADR-045 and the base document's whitespace-only lines are cured (row 523, cases l8
and enc).

### 2.2 The dashboard (group B)

**What a mission proved, round by round, and how long it took.** `vanguard ui` now reads, from the feed alone, what the
mission's own record holds. The snapshot writer adds four optional `mission_snapshot` fields (schema 1.2, expanded-schemas
§14) -- `assertion_detail`, `dispatch_detail`, `halts` and `framework_lock_version`: each contract assertion's feature,
milestone and validator rounds; each dispatch's feature and assertion targets; each HALT's raised and answered times and
where each was read; and the project's lock version. From them:
- The Project screen shows each feature's verdict chip (confirmed, refuted, partial, unjudged) and, expanded, its
  assertions with each one's latest verdict and round, and the latest validator round beside them (register row 501).
- Stats shows a mission's validator rounds, confirmed and refuted per round with the refuted ids, per mission and per
  dispatch; a HALT card (open, answered, mean and median time to resolve, the oldest open HALT's age, an unknown time
  marked, never a zero); elapsed time and the dispatch count per milestone; and the per-mission face of 8 cards --
  sessions, dispatches, rounds, HALTs, milestones, verify, tail window and framework version -- where a figure the feed
  cannot give reads "no data", never 0.
- The verify card lists each divergence -- path, kind, the two digests' first 8 characters -- not only their count
  (register row 498). `install.ps1 -Verify` now writes it: where the project is registered it appends one
  `verify_result` line with `divergence_list` to the feed, each difference it prints (`CHANGED`, `MISSING`, `REFUSED`,
  and `kept-differs` for a kept file it prints as `CHANGED ... -- kept, differs from upstream`; a kept file now equal to
  upstream is not listed), and still writes nothing under the installed set or the lock.
- A subagent's own tool calls carry its `agent_id` and `agent_type` on the feed, where Claude Code gives them, and the
  Live panel lists each subagent under its parent's session with its number of calls.

**An interactive session reads running between its turns (register row 528).** Claude Code fires `Stop` at the end of
every turn. In 1.3.0's first build the Stop hook wrote `session_stop` there, so a session read stopped between two
turns. From 1.3.0 a new `SessionEnd` hook, `tools/evidence-hooks-next/hooks/evidence-session-end.ps1`, writes the one
`session_stop` when the session itself ends, and a session resumed after it (`claude --resume`) says `session_start`
again; `Stop` keeps the seal and `dispatch_finalized` and writes no `session_stop`. The settings template registers
`SessionEnd`, so a project upgraded from 1.2.0 is told by the `.claude/settings.json` notice to add that registration.
Read live on Claude Code 2.1.312 with headless turns of one session (`claude -p`, then `claude -p --resume`) against the
1.2.0 hooks and the cured ones.

WP-7 carries 14 new members for this section (U-39..U-52), each with its RED at the 1.2.0-based tree, its GREEN and a
planted RED; 89 members in all (F-0, U-1 to U-52, V-1 to V-20, L-1 to L-16).

### 2.3 The instruments, the amendments and the validation

- **WP-1 H-26 compares the settings registration parsed (S2-AM3).** H-26 (P) compares the registration it composes
  with the proposal as parsed JSON -- the same events, keys compared exactly; each event's groups, matchers and hooks in
  order; each hook's type, command and timeout, numbers by value; `autoMemoryEnabled` the boolean false -- with object
  key order not compared, the proposal held to plain JSON (RFC 8259's grammar), and every equality ordinal. The line
  comparison it replaces could never hold under PowerShell 7, whose hash order differs per process.
- **The contract's amendments, each ruled by the operator.** S1-AM1 (A-8): `-Verify` writes nothing under the installed
  set or the lock, and where the project is registered appends exactly one `verify_result` line to its feed. S2-AM1
  (B-13): WP-7 U-38 skips by name only where `framework.lock` is present and the user guide absent; with no lock it
  always reads, and a missing guide fails it. S2-AM2 (L-5): the Project view's milestone table has seven heads, B-9's
  Dispatches among them. S2-AM3 (H-26): the parsed comparison above.
- **Validation.** UI-2 S2 was judged by a fresh-identity validator over 7 rounds under three caps -- 4, then 2, then 1
  -- each refutation cured or, at the last cap, recorded here as a 1.3.x limit (section 1).

## 3. Upgrading from 1.2.0

Over a project 1.2.0 installed, in your own Windows PowerShell 5.1 terminal, from the expanded release
(`C:\dl\vanguard-collective-v1.3.0`, after INSTALL.md sections 1 to 4) or from a clone at the tag `v1.3.0`:

1. **Run `install.ps1`** against the project as INSTALL.md sections 5 and 6 write it: `-WhatIf` first if you like,
   then `-ReleaseZip <the ZIP>` (no `-ReleaseZip` from a clone). One refusal refuses the whole upgrade and names itself;
   nothing is then written. Over a project the 1.2.0 ZIP installed and nobody edited since, the upgrade ends:

   ```text
   install.ps1: done: written=45 already-identical=329 kept=11 retired=5 refused=0
   ```

   -- 33 files upgraded and 12 installed, the 11 templates and host-configuration files kept,
   5 of the dashboard's old built files retired (left in place, dropped from the lock). `release.ps1`'s own
   line, which it derives from the two releases' installer-owned sets and requires here, is

   ```text
   install.ps1: done: written=57 already-identical=317 kept=11 retired=0 refused=0
   ```

   (upgraded 31, installed 26): it reads 1.2.0's set from the tag's tree,
   whose manifest names none of the files a release generates, so it counts `ui/dist/` and `THIRD-PARTY-NOTICES`
   installed and none retired.
2. **Kept files stay as they were.** Of the 11, `.claude/settings.json` differs from this release's version in a
   project left as 1.2.0 installed it, by the SessionEnd registration. The kept set is `.claude/settings.json` and
   any other file the installer reports kept: a template or host-config file the project edited differs too, and gets
   its own NOTICE line. For `.claude/settings.json` the run prints:

   ```text
   install.ps1: NOTICE kept .claude/settings.json -- kept: the project's own copy is not changed, and it differs from this release's version (fold-crlf-text basis), which is at C:\dl\vanguard-collective-v1.3.0\.claude\settings.json
   install.ps1: NOTICE kept .claude/settings.json -- this release registers SessionEnd (powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-session-end.ps1"); the project registers no SessionEnd: add this block to the project's "hooks" object:
   install.ps1: NOTICE   | "SessionEnd":  [
   install.ps1: NOTICE   |                                      {
   install.ps1: NOTICE   |                                          "hooks":  [
   install.ps1: NOTICE   |                                                        {
   install.ps1: NOTICE   |                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File \"$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-session-end.ps1\"",
   install.ps1: NOTICE   |                                                            "timeout":  30,
   install.ps1: NOTICE   |                                                            "type":  "command"
   install.ps1: NOTICE   |                                                        }
   install.ps1: NOTICE   |                                                    ],
   install.ps1: NOTICE   |                                          "matcher":  "*"
   install.ps1: NOTICE   |                                      }
   install.ps1: NOTICE   |                                  ]
   ```

   Add that block to your file's `"hooks"` object, then run LAM-INSTALL.md section 2's READY probe. Until it is added,
   the project's sessions write no `session_stop` (section 1).
3. **After the NOTICE block is added**, run `install.ps1 -Target <project> -Verify` and expect
   `kept, now equal to upstream` for the file, with 0 differences (INSTALL.md section 6, "After the NOTICE block is
   added").
4. **No sealed file moved.** Nothing under `tools/framework/` and nothing in `docs/framework/LAM-RESIDUALS.md` changed
   since 1.2.0 (`git diff --stat v1.2.0` reads empty for both).
5. **The Python set is unchanged.** `tools/ui/requirements.txt` pins the same 22 packages; the upgrade installs
   them into `tools\.venv` as 1.2.0's did (INSTALL.md section 5).
6. **Verify**: `install.ps1 -Target <the project> -Verify` reads `385 file(s) listed, 0 difference(s)`.

## 4. The release, counted

- **The members rule.** The ZIP holds 425 files: the 405 files of the commit the tag `v1.3.0` names that the release
  carries -- every one but the dashboard's private source under `ui/` and the service's tests under `tools/ui/tests/`
  -- the 18 files of `ui/dist/`, `THIRD-PARTY-NOTICES` and `RELEASE`. `MEMBERS.sha256` lists each with its sha256,
  425 lines, and `SHA256SUMS` names the ZIP and `MEMBERS.sha256`.
- **Installed into an empty folder**, `install.ps1` writes the 385 installer-owned files (MOVE 374, TEMPLATE 8,
  HOST-CONFIG 3) and a framework.lock of 386 lines, and `-Verify` reads
  `verify: 385 file(s) listed, 0 difference(s); eol lf=372 crlf=1 mixed=0 binary=12.`
- **Upgraded from 1.2.0**, section 3's lines; `release.ps1` derives its own from the two releases' installer-owned
  sets and refuses a build whose notes do not carry it.
- **`THIRD-PARTY-NOTICES`** names 128 packages: 106 in `ui/dist/` (103 production packages and 3 build-time ones) and
  the 22 of the Python set; their licences are MIT (100), ISC (13), BSD-3-Clause (7), Apache-2.0 (2), OFL-1.1 (2),
  0BSD (1), BSD-2-Clause (1), MIT AND ISC (1) and PSF-2.0 (1).
