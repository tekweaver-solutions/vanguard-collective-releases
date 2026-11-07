# Vanguard Collective 1.2.0 -- release notes

1.2.0 supersedes 1.1.0. Free to use under LICENSE; support by subscription: support@tekweaver.ca. It is the
release of the licence change and of the fixes that 1.1.0's first installs and upgrades asked for: the dashboard
patch, a SubagentStop hook, the kept-file notice an upgrade prints, a clean-install proof made a script, and the public
repository named in the documents. What this release does not do comes first.

## 1. Known limits

- **The licence model changed.** `LICENSE` Version 2.0 -- free use, including commercial and client work; the
  Framework itself is not redistributed; support for paying customers -- supersedes the Evaluation Licence of 1.0.0
  and 1.1.0. The licence text was approved by tekWeaver Solutions Inc. and has not been reviewed by legal counsel.
- **PowerShell 7 and the Mark of the Web are not measured.** What PowerShell 7's `Invoke-WebRequest` leaves on a
  downloaded ZIP, and whether `Expand-Archive` there carries a Mark of the Web onto the files, was measured on no
  PowerShell 7 host: the installer falsifier's case h7 skips by name where no `pwsh` stands, and did on the machine
  this release was read on. INSTALL.md section 3 states Windows PowerShell 5.1's behaviour only.
- **The zero-host-data gate's SOFT residual at the tag.** `tools/lam/gate-host-data.ps1` over the release tree reads
  `HARD 0 (H1 0, H2 0, H3 0, H4 0, H5 0); H3 not evaluated (no -HostRepo)`, SOFT 5416 -- B3-FIXTURE-BASE 2512, B3-OTHER 244, B3-TESTS 1044, FIXTURE-ID 379, HEX-UNRESOLVED 222, UUID 1015; over the expanded ZIP
  `HARD 0 (H1 0, H2 0, H3 0, H4 0, H5 0); H3 not evaluated (no -HostRepo)`, SOFT 5626 -- B3-FIXTURE-BASE 2512, B3-OTHER 236, B3-TESTS 1044, FIXTURE-ID 379, HEX-UNRESOLVED 446, UUID 1009. SOFT hits are listed for review and never block:
  bare row, ledger and gate numbers, hex tokens neither repository resolves, and UUIDs, most of them inside the
  instruments' pinned bases and their data.
- **Carried, by name.** The line-ending pin for `docs/framework/**` (F-H11: whether those files may be pinned
  `eol=lf`, given that the root `.gitattributes` is a TEMPLATE and the sealed tests may read it); the guard's reading
  of a script run with `-File` (F-H9b: writes made through a script the guard does not read); and the ADR citation
  items -- the local-modes family documents' own bare ADR-0NN citations and the other ambiguous bare ones,
  `docs/framework/mission-event.schema.json`'s bare ADR-045 (WP-7 U-17 pins that file's sha256), the v2.4 DELTA's
  "PASS-DIB (ADR-036 below)", qualified as written, and the whitespace-only lines kept in
  `docs/framework/expanded-schemas-base.md`, whose bytes 2 documents cite by sha256 prefix -- carried to the next
  dashboard release.
- **A fresh install reads named skips.** A reading of a fresh install of this release -- a new git project with a bare
  origin, the install from the ZIP, `mission init`, `mission smoke`, `mission register`, the smoke mission built, the
  acceptance run, the container engine up -- failed nothing. With the Python set installed (`-Python`) it skipped
  67 members by name, without it (`-SkipPythonSet`) 70. Of each, 15 are the
  other instruments': WP-1 H-12; WP-2 R-16, R-B and R-57; WP-3 C-2c, C-3e, C-1k, C-1v, C-1w, C-2d, C-1bd and C-1be; WP-4 T-42, T-53 and T-54 -- 1.1.0's, measured as 1.0.0's notes, section 1, say; with the engine up,
  WP-3 C-1bd skips where C-1aw skips with the engine down. The WP-7 members: V-1 to V-20, 20 members (the service's tests are
  not in the release); L-1 to L-16, U-20, U-24 and U-26, 19 members (the dashboard's source is not in the release); U-28 and U-29, 2 members (`mission.ps1`
  is not installed); F-0, U-4, U-5, U-10, U-13 to U-16 and U-25, 9 members (their fixtures are made by `mission.ps1` and read `VERSION`, which stay in the
  release tree); U-27, 1 member (an installed project's `.gitignore` is its own; the release tree's is not
  installed); U-21, 1 member (`provenance/` is not installed); and, without the Python set only, U-19, U-22 and U-30, 3 members
  (no `tools\.venv` interpreter to run the service on).
- **1.1.0's known limits stand.** Its notes, section 1, list them -- one platform, the dashboard local and
  read-only, the Windows stop keys, a mission made before the feed, the dashboard's source and the service's tests not
  in the release, `tools\.venv` as the framework tools' interpreter too, the OFL-1.1 fonts, and 1.0.0's -- but its
  licence sentence, which this release's licence replaces.

## 2. What changed since 1.1.0

- **The licence and the model (L).** `LICENSE` is the Commercial Use & Support Licence, Version 2.0, byte for byte as
  tekWeaver Solutions Inc. approved it (F-L1); README's first paragraph, QUICKSTART's head and INSTALL.md's head say
  the model where a reader starts -- free to use, commercial and client work included, not redistributed or resold,
  support by subscription (F-L6); README's Licence section and its "Ownership and contributions" (F-L4).
- **The public repository named (L).** INSTALL.md section 1 and QUICKSTART section 2 name
  https://github.com/tekweaver-solutions/vanguard-collective-releases, its Releases page, the versioned and fixed-name
  archives, `SHA256SUMS`, `MEMBERS.sha256` and the `gh release download` form (F-L2); INSTALL.md's clone section says
  the release tags are annotated and how to read the commit, `git rev-parse v<VERSION>^{commit}` (F-L3); section 6
  says what to do with a smoke mission a 0.x release built (F-L5).
- **The SubagentStop hook and the kept-file notice (P, H).** A SubagentStop hook in the next-generation set,
  `tools/evidence-hooks-next/hooks/evidence-subagent-stop.ps1`, registered by the settings template, appends one
  `session_stop` for the subagent's session and never blocks the stop (F-P2a, F-H15; WP-7 U-21). An upgraded
  project's own `.claude/settings.json` is kept, never merged: `install.ps1` prints a kept-file notice for each kept
  file that differs from the release's version, naming where that version stands, and for `.claude/settings.json`
  the registration it lacks and that registration's block to add (F-H5; section 3 gives it).
- **The dashboard patch (P).** Milestone statuses closed to passed/active/pending/withdrawn -- the snapshot writer maps
  the spec's words at emit, the mission-event schema 1.1 closes the field, the service reads a 1.0 `done` as passed
  and leaves the withdrawn out of progress and of both charts' runs (F-P1a, F-P1b, F-P1c); the open-session count read
  over a real feed (F-P2b); the schema read on the lock's fold basis (F-P3); the PARTIAL caption names what fired
  (F-P4); the mission's name from its record, on the API, the Fleet card and the breadcrumb (F-P5a, F-P5b); the
  release tree's `.gitignore` re-includes `ui/dist/` (F-P6); `mission init` and `register` ignore `/.mission-runtime/`
  whole, `register` prints init's line, and `vanguard ui --help` says what `--host` is (F-P7a, F-P7b, F-P7c); WP-7
  reads to its tally line in an installed project (F-P1-fix). WP-7 gains U-18 to U-30.
- **The real-feed fixture (P).** `tests/lam/fixtures/real-feed/`, 2 feeds of a real 1.1.0 upgrade, neutralised
  (the zero-host-data gate's HARD classes read zero over it), with its reader `tests/lam/wp7-real-feed.py` (F-P0).
- **The clean-install proof is a script (H).** `tests/install/clean-install-proof.ps1`: from a built ZIP and nothing
  else, in a scratch root -- a bare origin, a fresh project, the install, `mission init`, `smoke`, `register`, the
  smoke mission built, the acceptance run -- with `VANGUARD_HOME` and `TEMP` inside the scratch root and the caller's
  environment held unchanged; `-EngineDown` reads the engine and refuses to run while it is up (F-H6).
- **The builder's environment isolation (H).** The smoke builder runs its build as a child process, so its git
  identity, `GIT_CONFIG_*` and the `GIT_*` removal die with it and the caller's environment is left as it was (F-H18).
- **The guard and the evidence plane (H, X).** The pre-push decider compares on the lock's fold basis (F-H1); the seat
  tripwire exempts tracked fixtures under a session root's `tests/` and `tools/lam/smoke-mission/` (F-H2), and never a
  path holding a `..` component (F-X1); H-26's reader scans every event for the sealed path (F-H17); WP-6 F-0's H-3
  row is decided by code, never by comment text (F-H9).
- **The installer and its tools (H, X).** `-WhatIf` and the run warn once per installed member a project's git ignore
  rules hide (F-H8, F-X3); the planned-ignore message names `/.mission-runtime/` (F-H12); the legacy census header
  names the evaluator by its fold digest (F-H10); a `#` inside a quoted YAML scalar is kept (F-H13); `prune-worktrees
  -Remove` over an empty worktree folder prunes its registration (F-H3); the session-id scan,
  `tools/lam/scan-session-ids.ps1`, reads its ids at run time and refuses a folder that does not stand (F-H4, F-X4);
  the verify spec's section 10 anchor table equals disk, held by the framework repository's own tool (F-H16).
- **The installer falsifier (H, L).** Cases h4, h5, h6, h7, h8, h10, h14, h16 and h18 for this release's group H -- among them h7, PowerShell 7 and the
  Mark of the Web, skipped by name without `pwsh` (F-H7), and h14, no permission-rule form the CLI rejects, with the
  CLI's exit code held to 0 (F-H14, F-X6) -- and l1, l6, l2, l3, l4, l5, l8 and enc for group L: the licence, the model sentence, the
  public repository, the annotated tags, ownership, the 0.x smoke mission, the ADR citation convention of the v2.4
  DELTA (F-L8), and every tracked Markdown file and `LICENSE` UTF-8 without a byte-order mark and without a
  whitespace-only line, but the base document listed (F-ENC).
- **The documents (R).** `VERSION` 1.2.0; INSTALL.md's and README.md's counts written by a script from the
  build, and INSTALL.md section 6's example the upgrade from 1.1.0.

## 3. Upgrading from 1.1.0

Over a project 1.1.0 installed, in your own Windows PowerShell 5.1 terminal, from the expanded release
(`C:\dl\vanguard-collective-v1.2.0`, after INSTALL.md sections 1 to 4) or from a clone at the tag `v1.2.0`:

1. **Run `install.ps1`** against the project as INSTALL.md sections 5 and 6 write it: `-WhatIf` first if you like,
   then `-ReleaseZip <the ZIP>` (no `-ReleaseZip` from a clone). One refusal refuses the whole upgrade and names itself;
   nothing is then written. Over a project the 1.1.0 ZIP installed and nobody edited since, the upgrade ends:

   ```text
   install.ps1: done: written=33 already-identical=334 kept=11 retired=4 refused=0
   ```

   -- 24 files upgraded and 9 installed, the 11 templates and host-configuration files kept,
   4 of the dashboard's old built files retired (left in place, dropped from the lock). `release.ps1`'s own
   line, which it derives from the two releases' installer-owned sets and requires here, is

   ```text
   install.ps1: done: written=46 already-identical=321 kept=11 retired=0 refused=0
   ```

   (upgraded 22, installed 24): it reads 1.1.0's set from the tag's tree,
   whose manifest names none of the files a release generates, so it counts `ui/dist/` and `THIRD-PARTY-NOTICES`
   installed and none retired.
2. **Kept files stay as they were.** Of the 11, only `.claude/settings.json` differs from this release's
   version, by the SubagentStop registration; the run prints:

   ```text
   install.ps1: NOTICE kept .claude/settings.json -- kept: the project's own copy is not changed, and it differs from this release's version (fold-crlf-text basis), which is at C:\dl\vanguard-collective-v1.2.0\.claude\settings.json
   install.ps1: NOTICE kept .claude/settings.json -- this release registers SubagentStop (powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-subagent-stop.ps1"); the project registers no SubagentStop: add this block to the project's "hooks" object:
   install.ps1: NOTICE   | "SubagentStop":  [
   install.ps1: NOTICE   |                                        {
   install.ps1: NOTICE   |                                            "hooks":  [
   install.ps1: NOTICE   |                                                          {
   install.ps1: NOTICE   |                                                              "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File \"$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-subagent-stop.ps1\"",
   install.ps1: NOTICE   |                                                              "timeout":  30,
   install.ps1: NOTICE   |                                                              "type":  "command"
   install.ps1: NOTICE   |                                                          }
   install.ps1: NOTICE   |                                                      ],
   install.ps1: NOTICE   |                                            "matcher":  "*"
   install.ps1: NOTICE   |                                        }
   install.ps1: NOTICE   |                                    ]
   ```

   Add that block to your file's `"hooks"` object, then run LAM-INSTALL.md section 2's READY probe.
3. **No sealed file moved.** Nothing under `tools/framework/` and nothing in `docs/framework/LAM-RESIDUALS.md` changed since 1.1.0 (`git diff --stat v1.1.0` reads empty for both).
4. **The Python set is unchanged.** `tools/ui/requirements.txt` pins the same 22 packages; the upgrade installs
   them into `tools\.venv` as 1.1.0's did (INSTALL.md section 5).
5. **Verify**: `install.ps1 -Target <the project> -Verify` reads `378 file(s) listed, 0 difference(s)`.

## 4. The release, counted

- **The members rule.** The ZIP holds 417 files: the 397 files of the commit the tag
  `v1.2.0` names that the release carries -- every one but the dashboard's private source under `ui/` and the
  service's tests under `tools/ui/tests/` -- the 18 files of `ui/dist/`, `THIRD-PARTY-NOTICES` and `RELEASE`.
  `MEMBERS.sha256` lists each with its sha256, 417 lines, and `SHA256SUMS` names the ZIP and
  `MEMBERS.sha256`.
- **Installed into an empty folder**, `install.ps1` writes the 378 installer-owned files (MOVE 367,
  TEMPLATE 8, HOST-CONFIG 3) and a framework.lock of 379 lines, and `-Verify` reads
  `verify: 378 file(s) listed, 0 difference(s); eol lf=365 crlf=1 mixed=0 binary=12.`
- **Upgraded from 1.1.0**, section 3's lines; `release.ps1` derives its own from the two releases' installer-owned
  sets and refuses a build whose notes do not carry it.
- **`THIRD-PARTY-NOTICES`** names 128 packages: 106 in `ui/dist/` (103 production packages and
  3 build-time ones) and the 22 of the Python set; their licences are MIT (100), ISC (13), BSD-3-Clause (7), Apache-2.0 (2), OFL-1.1 (2), 0BSD (1), BSD-2-Clause (1), MIT AND ISC (1) and PSF-2.0 (1).
