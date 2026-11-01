# Vanguard Collective 1.0.0 -- release notes

1.0.0 supersedes 0.3.0. It is the first public release: its tagged tree and the release ZIP carry no name of the project the
framework was extracted from and no file of it (the traces of it that remain are listed in section 1), a project builds its own smoke mission after install instead of receiving
a recorded one, the pinned bases the acceptance instruments read are installed with the framework, and a project can
be installed from the release ZIP or from a clone of the public repository at its release tag. The licence is
unchanged: the evaluation licence in `LICENSE`. New operators start with `docs/QUICKSTART.md` and the operator's
guide, `docs/framework/vanguard-collective-user-guide.md`. What this release does not do comes first.

## 1. Known limits

- **One platform.** Windows with Windows PowerShell 5.1 only, plus git and Python 3, and Claude Code to run a
  mission. macOS and Linux are not supported in 1.0.
- **PowerShell 7 and the Mark of the Web handling are unmeasured for this release.** Nothing in 1.0.0 was run under
  PowerShell 7: run every command with `powershell` (5.1), as written. What INSTALL.md section 3 says about the Mark
  of the Web was measured on earlier release ZIPs, not on this one.
- **The default auth mode's wording, and a credential left in the shell.** With `VANGUARD_AUTH_MODE` unset the
  framework checks nothing: the runner and the wake starter do not even load `tools/lam/lam-auth-mode.ps1` and remove
  nothing from the environment their CLIs inherit, and only the first-generation worker-runner removes a variable,
  `ANTHROPIC_API_KEY`, from its child's (`tools/worker-runner/env_scrub.py`). So the default is the Claude
  subscription Claude Code is signed in with only when no credential is in the environment: an `ANTHROPIC_API_KEY`,
  a bearer token (`ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`) or a cloud-provider selector
  (`CLAUDE_CODE_USE_BEDROCK`, `_VERTEX`, `_FOUNDRY`) left in the shell is picked by Claude Code's own precedence
  instead -- on the worker-runner's path too, the key alone excepted. Set `VANGUARD_AUTH_MODE=subscription` to
  have such a credential refused (`AUTH-MODE-BOTH-CLAIMED`; the subscription's own `CLAUDE_CODE_OAUTH_TOKEN`
  excepted). README.md, INSTALL.md section 9, LAM-INSTALL.md section 7c, the header of `lam-auth-mode.ps1`, the
  docstring of `env_scrub.py`, ADR-014 and `local-orchestrator-mode.md` now say so. Two refusal texts, which tests
  compare, still say to unset the variable "for the Claude subscription": `AUTH-MODE-KEY-ABSENT` and
  `AUTH-MODE-UNKNOWN`, in both `lam-auth-mode.ps1` and `env_scrub.py`; read them as the default above.
- **Key mode has not been run with a valid key.** It was exercised with dummy values and with a key the CLI rejected;
  no worker billed to a real key has been observed by the framework's own tests.
- **The guard library compares the pre-push decider raw.** Before it dispatches, the runner asks the guard library
  (`Test-EvidencePrePushHookInstalled` in `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1`, reached through
  `check-prepush-installed.ps1`) whether the decider is installed. It compares the sha256 of the raw bytes of the
  decider the installed pre-push wrapper names by its `-File` path with the sha256 of the raw bytes of the shipped
  decider in the runner's own checkout, `tools/evidence-hooks-next/hooks/evidence-pre-push.ps1`, with no line-ending
  fold. Where the two files stand in checkouts of different line endings -- a CRLF worktree against an LF checkout,
  say -- the same text reads as different bytes, and the runner refuses the dispatch as though the decider had been
  substituted. The failure is closed (a refusal, never a false pass); the cure is to install the decider from a
  checkout whose line endings match the runner's (LAM-INSTALL.md section 5.4). WP-6 S-4b judges the decider by
  framework.lock's fold rule, and says on its face why when it takes that path.
- **A fresh install reads named skips.** A reading of a fresh install of this release (a
  new git project with a bare origin, the install, `mission init`, the smoke mission built, Docker Desktop running,
  no Python venv) failed nothing and skipped fifteen members: WP-1 H-12; WP-2 R-16, R-B and R-57; WP-3 C-1k, C-1v,
  C-1w, C-2c, C-2d, C-3e, C-1bd and C-1be; and WP-4 T-42, T-53 and T-54. Three members that failed on a fresh
  install of an earlier build are cured in this release: WP-1 H-26 (`mission
  init` now adds the project's ignore rules for `.claude/settings.local.json` and `.claude/worktrees/`), WP-3 C-2e
  (the build read there had changed strings of `mission-goal-check.ps1` that C-2e compares with the base
  evaluator's; those strings are restored) and WP-4 T-42 (a named skip until the project's runner has written a
  spawn ledger). A failure on a fresh install is not
  expected. Once a project's runner has written its own spawn ledger, T-42 fails: its audit holds the ledger's
  first 372 lines to a prefix sha256 pinned in the instrument, the prefix of the spawn ledger of the project the
  framework was extracted from, which no other project's ledger matches. T-42 is not a green member in a working
  project. The skips fall in three kinds:
  - **Bound to the environment, and measurable.** WP-2 R-57 and WP-3 C-1k and C-1be run a fixture's pytest and
    skip while none of `src\.venv` and `tools\.venv` (the primary checkout's too, from a worktree) has a
    `Scripts\python.exe`: create one with pytest installed, `python -m venv tools\.venv` and then
    `tools\.venv\Scripts\python.exe -m pip install pytest`, and they are measured. WP-3 C-1bd measures what a goal
    reads with the container engine really down: it lists the host's named pipes and skips while the engine's
    pipe (`\\.\pipe\dockerDesktopLinuxEngine`) is among them or the pipes cannot be listed, so it is measured only by
    a run of WP-3 with Docker Desktop's Linux engine stopped.
  - **Bound to the project's own state.** WP-3 C-2c reads the goal-check Stop hook's registration at two sites:
    `.claude/settings.local.json` of the checkout (or of the primary checkout, from a worktree) and the smoke
    mission's. It skips while that project file does not exist, provided nothing it could measure failed; once
    the file exists the member is measured, and fails unless it registers a command Stop hook running
    `mission-goal-check.ps1` with a `-Goal` whose goal file is on disk. WP-3 C-3e drives the `HALT-*` files on the
    primary checkout's runtime plane (`.mission-runtime\halts` and `.mission-runtime\lam`): it skips where the plane
    is absent or holds no `HALT-*` file, and where HALTs stand its census row has no member to read while
    `tools\lam\legacy-halt-census.txt` is empty, as the framework ships it -- so C-3e is a named SKIP whenever its
    measured rows hold, and fails only when one of them misses. WP-4 T-42 skips while the primary checkout's
    `.mission-runtime\lam\spawn-ledger.jsonl` does not exist, and fails once it does (above).
  - **Not measurable in this distribution.** WP-1 H-12, WP-2 R-16 and R-B, and WP-3 C-1v, C-1w and C-2d measure
    against a project acceptance record, `docs/framework/LAM-ACCEPT.md`, that no release after 0.2.0 ships (a
    project first installed at 0.2.0 or earlier may still hold the copy those releases installed, which 0.3.0
    retired and left in place); WP-4 T-53 and T-54 are below.
- **WP-4 T-53 and T-54 are named skips in this distribution.** Each re-read a seat brief and runtime records of the
  project the framework was extracted from, which is not part of this distribution, and keeps its id. T-54 reports
  a named SKIP everywhere, never a pass and never a failure. T-53 is a named SKIP while its three skeleton rows (s),
  which read no record of that project, hold, and fails if one of them misses.
- **OneDrive is not detected.** The installer refuses every reparse point below the folder it installs into,
  OneDrive's placeholders among them, but does not judge that folder itself: install from and into folders OneDrive
  does not sync.
- **Traces of the project the framework was extracted from.** They name nothing of that project, but they are
  there: comments in tools, instruments and pinned bases that cite its records by label, some by path and line,
  as though they stood in this repository (dispatch, gate and ledger records under `.mission/` and
  `.mission-runtime/`, which no release ships); WP-4 T-42's pinned ledger prefix (above); a detail line WP-3 C-2c
  prints, quoting a commit subject of that project's history; the ignore entries `.worktreeinclude` lists, read
  from that project's layout (`src/` venvs, `docker/secrets/`, an import-linter cache), which the template
  installs; the four standing residue files two build dispatches name; and configuration, prompts and ADRs
  written for that project with its names replaced by placeholders (`tools/mission-cli/config/mcp-tools.yaml`
  among them).
- **Inherited sample identifiers.** Some sample identifiers in messages, fixtures and tests (assertion, milestone,
  feature and batch numbers) are inherited from the framework's first host project's ceremony. They carry no
  information about that project and are listed in the release record, section 5 of these notes, by kind. Some
  comments, messages and documents, sealed and pinned sources among them, also keep counts measured in that
  project (counts of lines, entries, files and artifacts, for example) and the dates of its operator's rulings; they name nothing of it either.
- **The mission planes are never touched**: the installer refuses every installer-owned path under `.mission/` or
  `.mission-runtime/`.

## 2. What changed since 0.3.0

- **No name or file of the project the framework was extracted from.** Its names, its commit and blob ids and
  the records the repository tracked are gone from the tree and from the release: from the
  documents, ADRs, build dispatches, instruments, tools and tests, from the comments and messages of both evidence
  hook generations, and from `provenance/manifest.jsonl`, which now holds one record per tracked file and no record
  of a file the repository does not track. Identifiers that tests carry as data are fabricated or neutral values,
  or bare inherited labels of the kinds section 5 names, and every outcome they decide is unchanged. Strings a check compares and the pinned framework sources kept their
  bytes where a check reads them. The development records the repository tracked are removed. Some comments
  still cite that project's records, and other traces of it remain; section 1 lists them.
- **The smoke mission is built on install, not shipped.** `tools/lam/build-smoke-mission.ps1`, installed with its
  plain sources under `tools/lam/smoke-mission/`, builds a live git repository, `lam-smoke`, with its bare origin
  `lam-smoke-origin.git`, beside the project (or where `-SmokeRoot` or `LAM_SMOKE_ROOT` names). It spawns no CLI
  worker: git makes the commits, worktrees and push with a fixed identity and fixed dates, the builder keeps git from
  the host's identity, configuration and global ignore and attributes files, and it refuses a root that already
  stands or lands inside a mission plane or a git work tree. The tracked smoke fixture and its materialiser are
  removed. The instruments resolve the smoke root from `-SmokeRoot`, then `LAM_SMOKE_ROOT`, then that default, and
  the members that need one skip by name where none is named and none stands at the default (INSTALL.md section 9,
  LAM-INSTALL.md section 10).
- **The pinned bases the instruments read are installed.** `tests/lam/fixtures/base-700e19e5/` and
  `base-700e19e5-s01/` to `-s13/` replace the base folders 0.3.0 installed: synthetic bases built from the
  framework's own files by a recipe this repository keeps and does not install
  (`tests/lam/fixtures/synthetic-bases.json`). Every reader holds a base to the sha256 of its exact bytes and reads
  no git history, so the members that read an earlier version of a tool can be measured in an installed project.
- **Every date the framework formats is written in the invariant culture**: the stamps of the mission library, both
  evidence libraries, the gate tool, the runner, the goal evaluator, the lifecycle scripts and the smoke builder, so
  a host's regional format can neither change a stamp nor refuse a date git is given.
- **Installs from a clone of the public repository.** `install.ps1` accepts a git checkout as its source only when
  HEAD is exactly the commit the tag `v<VERSION>` names and `git status --porcelain` is empty, and refuses it
  otherwise (exit 1, nothing written). framework.lock records the source: `source_kind` `clone` with the tag and the
  commit, or `release`, with the ZIP's sha256 when `-ReleaseZip` names it. Older locks read, upgrade and verify as before (INSTALL.md section 5).
- **The ZIP is the tagged tree.** `release.ps1` puts every file of the tagged commit in the ZIP, plus the generated
  `RELEASE`, and writes `MEMBERS.sha256` beside it, one `<sha256>  <path>` line per member, which `SHA256SUMS` names
  too: the expanded ZIP can be checked against it file for file (INSTALL.md sections 2 and 4).
- **`docs/QUICKSTART.md` and the operator's guide**, `docs/framework/vanguard-collective-user-guide.md`, are new.
- **The clean-tree patch fixture and the instrument-run helper are re-pinned.** The clean-tree exemption patch's
  preamble cites no record of the earlier project, its pinned pre-image and post-image are re-derived, and it still
  applies forward only; `tools/lam/lam-instrument-run.ps1` changed in comments only, and WP-2 R-57 pins its new
  blob. The tables LAM-INSTALL.md and `mission-verify-spec.md` section 10 keep for the sealed sources are
  re-derived to the files as this release ships them.
- **The default auth mode's wording** is corrected where it is installed (section 1).
- **The earlier release notes stay as history**, `docs/RELEASE-NOTES-v0.1.0.md` to `v0.3.0.md`, each describing its
  own release, with the identifiers of the earlier project they carried replaced by neutral forms.

## 3. Upgrading from 0.3.0

Over a project 0.3.0 installed, in your own Windows PowerShell 5.1 terminal, from the expanded release
(`C:\dl\vanguard-collective-v1.0.0`, after INSTALL.md sections 1 to 4) or from a clone at the tag `v1.0.0`:

1. **Run `install.ps1`** against the project as INSTALL.md sections 5 and 6 write it: `-WhatIf` first if you like,
   which decides everything and writes nothing, then `-ReleaseZip <the ZIP>` (no `-ReleaseZip` from a clone). One
   refusal refuses the whole upgrade and names itself; nothing is then written.
2. **What it installs and retires.** It installs the new pinned bases and the smoke-mission builder with its sources,
   and retires the pinned base copies 0.3.0 installed: each is named on a `retire` line, left in place and dropped
   from the lock; you may delete them once the kept files of step 3 no longer read them.
3. **Kept files stay as they were.** No template or host-configuration file is rewritten. Four of them changed in
   this release: `tools/mission-cli/config/expected-failures.yaml` and `mcp-tools.yaml` (TEMPLATE), and
   `tools/tests/cli/test_close_milestone_lam_roster.py` and `test_prune_worktrees.py` (HOST-CONFIG), the last two
   now reading their bases from the installed fixtures. Each lock row's `upstream_sha256` shows where the project's
   copy differs; the new one is the project's to take from the release by hand.
4. **Sealed files moved.** Files under `tools/framework/` and `docs/framework/LAM-RESIDUALS.md` changed in this
   release (comments, messages and prose), so the upgrade moves sealed bytes: LAM-INSTALL.md section 3 says what to
   record, and a completion-acceptance gate bound to `LAM-RESIDUALS.md` by hash no longer matches it.
5. **Build the smoke mission** with the installed builder before you run the acceptance instruments (INSTALL.md
   section 9).
6. **Verify**: `install.ps1 -Target <the project> -Verify`.

INSTALL.md section 6 shows the upgrade's output, its counts and `-Verify`'s reading; those figures were measured on
a real upgrade of a project 0.3.0 installed.

## 4. The release, counted

- **The members rule.** The ZIP holds every file of the commit the tag `v1.0.0` names and `RELEASE`: 352
  files, the 351 tracked files of that commit and `RELEASE`. `MEMBERS.sha256` lists each with its sha256,
  352 lines, and `SHA256SUMS` names the ZIP and `MEMBERS.sha256`.
- **Installed into an empty folder**, `install.ps1` writes the 318 installer-owned files (MOVE 307,
  TEMPLATE 8, HOST-CONFIG 3) and a framework.lock of 319 lines, and `-Verify` reads
  `318 file(s) listed, 0 difference(s); eol lf=317 crlf=1 mixed=0
  binary=0`.
- **Upgraded from 0.3.0**, the counts, the lock and `-Verify`'s reading are INSTALL.md section 6's.

## 5. Inherited sample identifiers, by kind

Section 1 names these. They are bare labels from the ceremony of the project the framework was first built in: a
number, or a number joined to the framework's own words. None of them names that project, its product, its people
or what it does. The kinds are assertion numbers (`A-nnn`), amendment numbers and file names (`AM-nnn`),
milestone numbers (`M-nn`), feature numbers (`F-nnn`), batch numbers (`BATCH-n`), finding, erratum and deviation
labels (`NEW-n`, `F-n`, `E-n`, `DEV-n`), development-ledger slugs, two session ids in captured hook payloads, and
scratch and record labels (rows, arcs, seats, fixtures). Labels of these kinds stand in messages, string literals,
test data, comments and documents; some of them the design documents define for themselves.

This list is not a census. A review of the shipped values classified the 126 labels below; they stand on 687
distinct lines of the tagged tree, in values, comments and prose alike (18 lines carry labels of more than one kind --
17 of two kinds, one of three -- so the per-kind counts add up to 706), some in the pinned bases under `tests/lam/fixtures/base-700e19e5*/`, which the
instruments compare byte for byte. Other labels of the same kinds stand elsewhere in the tree, unlisted.

- **Assertion numbers** (36, on 347 lines): `A-081`, `A-116`, `A-121`, `A-123`, `A-124`, `A-129`, `A-130`, `A-131`, `A-132`, `A-133`, `A-134`, `A-135`, `A-136`, `A-138`, `A-139`, `A-140`, `A-141`, `A-142`, `A-144`, `A-147`, `A-148`, `A-149`, `A-162`, `A-163`, `A-164`, `A-165`, `A-184`, `A-338`, `A-562`, `A-563`, `A-564`, `A-565`, `A-566`, `A-568`, `A-576`, `A-599`.
- **Milestone numbers** (5, on 15 lines): `contract-m56`, `M-12`, `m-14`, `M-55`, `M-62`.
- **Feature numbers** (4, on 20 lines): `F-034`, `f-034`, `F-037`, `F-079`.
- **Batch numbers** (5, on 143 lines): `BATCH-2`, `BATCH-3`, `BATCH-4`, `batch-4-legacy`, `batch-4-rec-a`.
- **Amendment numbers** (10, on 46 lines): `AM-106`, `AM-113`, `AM-232`, `AM-417`, `AM-418`, `AM-420`, `AM-421`, `AM-422`, `AM-449`, `pre-amendment-20`.
- **Amendment file names** (2, on 3 lines): `AM-417-framework-evidence-plane-artifact-program`, `AM-421-a4-build-dispatches-hook-installation`.
- **Finding, erratum and deviation labels** (5, on 28 lines): `DEV-1`, `E-2`, `F-4`, `NEW-1`, `NEW-3`.
- **Development-ledger slugs** (4, on 6 lines): `ledger-bounds-channel-bounds-json-argv4-landed`, `ledger-handoff-write-protocol-exemption`, `ledger-hook-derives-from-argv-not-ambient`, `ledger-hook-runner-contract-escapes-to-argv`.
- **Session ids in two captured hook payloads** (2, on 2 lines): `c6592081-fbcf-4ec0-abec-7dfe2168e1ea`, `dae28827-a0f0-41f6-8efc-1f6ba74edb8f`.
- **Scratch and record labels (rows, arcs, seats, fixtures)** (53, on 96 lines): `arc-pb-5`, `arc-pb-5-close`, `arc-pb-6-close`, `arc-pb-6-v2`, `arc-pb-7-close`, `b4s2-c4a`, `c3d-r133`, `fx-e-a169`, `post-185`, `pre-row-172`, `prune-listing-arc-pb-7`, `prune-listing-legacy`, `push-row111-nosuchgate`, `push-row111-place`, `r112-subject`, `r112-t22-other`, `r112-t22-subject`, `r112-t23-subject`, `r249-admit`, `r249-admit-report`, `r249-admit-verify`, `r249-fixture`, `r249-nogate`, `r249-nogate-report`, `r249-nogate-verify`, `r249-partial`, `r249-partial-report`, `r249-partial-verify`, `r249-revoked`, `r249-revoked-report`, `r249-revoked-verify`, `r249-triple`, `r249-triple-report`, `r249-triple-verify`, `reclose-44-ledger-content`, `reclose-45-ledger-content`, `row-130`, `row-249`, `row111-accept`, `row111-diverged`, `row111-exists`, `row111-kill`, `row111-nobrowser`, `row111-noref`, `row111-nosuchgate`, `row111-nourl`, `row111-outpath`, `row111-place`, `row111-silent`, `row111-wrongkind`, `test_row116`, `wp3-r249`, `wp3-r249-instrument`.
