# Vanguard Collective 0.3.0 -- release notes

0.3.0 supersedes 0.2.0. It is the release that makes the framework usable by a developer who is not its author: its
agents authenticate with an Anthropic API key as well as with a Claude subscription, it carries an evaluation licence,
the first host's own fixtures and the names of its organisation, project and people are out of what a project receives
(what remains of its identifiers is listed under "Known limits"), and a reading taken in a worktree equals the root's.
Its acceptance instruments are not yet a reading a project passes: run in a freshly installed project, 45 of their 287
checks fail for inputs a project is not given (section 4). It is still internal and private: 1.0.0 is kept for the
first public release, after a confidentiality pass this release does not make.

## 1. What 0.3.0 is

### A. Authentication with an Anthropic API key

- **One variable decides.** `VANGUARD_AUTH_MODE` unset is the default, and with it the runner and the wake starter set,
  load and refuse nothing: each Claude Code CLI they start authenticates as Claude Code decides -- with the subscription
  it is signed in with, unless a credential is in the environment: an `ANTHROPIC_API_KEY` left in the shell is used,
  and billed, by every print-mode CLI the runner starts (the first-generation worker-runner removes the key from its
  child's environment, as in every mode but `api-key`). To go back to the subscription, remove the key as well as the
  mode. `api-key` bills `ANTHROPIC_API_KEY`, the provider's own variable,
  on purpose; `subscription` claims the subscription out loud and refuses a stray key, bearer token or cloud-provider
  selector. The mode is never sniffed: a key in the environment with the variable unset changes nothing the toolchain
  does. Set the key and the mode in your own PowerShell terminal, reading the key with `Read-Host -AsSecureString` and
  never typing it on a command line, which PowerShell's line editor saves to its history file (INSTALL.md section 9;
  the mechanism is LAM-INSTALL.md section 7c).
- **Where it is read.** The four places that start the CLI to call a model read the one variable alike: the runner's
  login probe and its worker and validator spawn (`tools/lam/mission-dispatch.ps1`), the wake starter's interactive
  seat (`tools/lam/lam-wake.ps1`) and the first-generation worker-runner (`tools/worker-runner/runner.py`, which in
  every other mode removes the key from its child's environment). The decision is a new installed library,
  `tools/lam/lam-auth-mode.ps1`, and the same rule in Python in `tools/worker-runner/env_scrub.py`.
- **The refusals**, each before any CLI that calls a model starts, each naming a variable, an argument by its index or
  a file by its path, never a value: `AUTH-MODE-UNKNOWN` (a value other than the two); `AUTH-MODE-KEY-ABSENT`
  (`api-key` with no key); `AUTH-MODE-BOTH-CLAIMED` (`api-key` beside another credential or a cloud-provider selector,
  or `subscription` beside a key, a bearer token, such a selector or a settings file naming a credential);
  `AUTH-MODE-KEY-IN-ARGUMENT` and `AUTH-MODE-KEY-IN-FILE` (in key mode, a key-shaped value -- `sk-ant-` and 20 or more
  of `[A-Za-z0-9_-]` -- in an argument of the spawn, in a file it hands the CLI, or in the `CLAUDE.md`,
  `CLAUDE.local.md`, `.claude\CLAUDE.md`, `.mcp.json` or `.claude` settings at the root of the tree the CLI runs in,
  each read in any letter case; or a settings file that names a credential setting -- `apiKeyHelper`, or a credential
  variable in its `env` block); and `AUTH-MODE-UNREADABLE` (the library not loaded where the mode is set, in the runner
  or the wake starter; or a file the commit the runner's worker is cut at names, which git cannot read). The runner
  reads the worker's tree as that commit holds it, since the tree does not exist yet when it decides.
- **Where the key goes.** The key travels in the environment only: the toolchain puts it in no file, dispatch,
  argument or record of its own, and prints, logs, captures or hashes no value. But **every program the runner starts
  inherits it** with the rest of your shell's environment -- the verify gate and the product test suite it runs, the
  login probe, the worker, and the tools and hooks the CLI starts. A product test suite that calls the API whenever
  `ANTHROPIC_API_KEY` is present will call it, and bill it, under the verify gate. Key mode sets nothing in a child but
  what it inherits; the provider's `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, set in the same shell, keeps the key out of
  the tools and hooks the CLI starts. What the toolchain cannot keep out of a record is what a child prints: a worker
  that printed its environment would put the key into the stream the runner captures, and into the evidence plane,
  which captures every tool's output and seals it into the session's manifest. And **the interactive CLI records an
  approved key's last 20 characters in its own configuration**: the seat the wake starter opens asks once whether to
  use the key, and once you answer yes the CLI keeps that answer in its `.claude.json` (or the folder
  `CLAUDE_CONFIG_DIR` names) under the key's last 20 characters. That is read from the CLI's own code (2.1.284), not
  measured with a real key; the toolchain writes none of it.
- Run the acceptance instruments and the Python tests with `VANGUARD_AUTH_MODE` unset: they were measured under the
  default (the Python tests clear it for themselves, in `tools/conftest.py`).

### B. The evaluation licence

- **`LICENSE` is the evaluation licence**, in place of 0.2.0's placeholder: a non-exclusive, non-transferable,
  revocable licence to install and use the framework solely to evaluate it and for your own internal development work;
  no redistribution, sublicensing or publication; what you produce with it in your own repositories is yours; no
  warranty. README.md's licence line points at it.

### C. The first host out of what a project receives

- **Synthetic fixtures replace the first host's.** The members that run a product instrument, read a goal of record and
  copy legacy HALTs now read files the framework owns outright, in place of the first host's: the product instrument
  WP-2 R-57 and WP-3 C-1k and C-1be run is
  `tests/lam/fixtures/base-<sha8>/tests/lam/instrument-sample-suite.ps1.base`, one version each in four such folders
  -- the host's instrument at that version with every host
  identifier in its comments, its banner and its mirror line replaced and its code otherwise unchanged, so the versions
  differ by exactly what the host's did; the goal of record WP-3 C-1ah reads is
  `base-<sha8>/.mission/goals/SAMPLE-GOAL.yaml`, in one of those folders; and the legacy HALTs WP-3 C-3d copies are
  `legacy-census-halts/HALT-SAMPLE-01.md` and `HALT-SAMPLE-02.md`, honoured only by a sandbox double of the evaluator,
  with a control row in which the real evaluator honours neither. The seven files they replace are retired by an
  upgrade (section 2).
- **The first host's names.** A census of its names -- its organisation, project, a partner's name, user name and home paths
  -- read over every file this repository tracks finds 166 lines in 16 files, every one in the smoke fixture's recorded
  acts under `tests/lam/fixtures/lam-smoke/.mission/` (its evidence manifests, anchors, gate and validator results,
  several bound to one another by sha256), which is not installed. With wider classes -- its product, partners'
  products and slugs, services, a person's first name, product source paths, a machine name -- it finds 388 lines in 21
  files: those 166, the extraction's provenance records (220 lines in four files), one earlier seat's handoff (1) and
  one more line of the smoke fixture's. No installed file holds a line of either census; of the release ZIP's members,
  `provenance/manifest.jsonl` does (Known limits). The evidence-manifest schema's `$id`, which 0.2.0 kept by design,
  names the framework now, in the installed copy and the smoke fixture's. The engagement's review and validation
  finding ids are gone from the tools, instruments and documents, but where a file cannot move: the sealed
  first-generation hooks and tests, files bound by sha256 to a gate or a sealed record, a patch's pinned pre-image and
  the post-image it derives, five member titles the first host's acceptance record quotes, a review's findings
  register, and the pinned base copies.
- **The acceptance record is not shipped.** `docs/framework/LAM-ACCEPT.md`, the first host's acceptance record, is not
  a framework document, and this release does not carry it. The six members that measure the framework
  against sentences of it -- WP-1 H-12, WP-2 R-16 and R-B, WP-3 C-1v, C-1w and C-2d -- read it as 0.2.0 carried it,
  held to its sha256 after the fold: at its path where an upgrade from 0.2.0 left it, else from this repository's
  history; where neither holds it they SKIP by name (WP-1 gained a skip outcome for H-12).
- **The legacy HALT census is a file of the project's.** The census that bounds a goal's `legacy_answered_allowlist`
  was a literal inside the evaluator, `tools/lam/mission-goal-check.ps1`, listing legacy HALTs by name and
  sha256. It is now `tools/lam/legacy-halt-census.txt`, HOST-CONFIG, which the framework ships empty (`count : 0`),
  and the evaluator carries no literal. A census line of no form makes the goal that consults it read NOT_MET, its
  `evaluator_error` naming the file and the line. `tools/lam/export-legacy-census.ps1`, installed, writes the census
  from an older evaluator's literal, which it parses and never runs (section 2, step 1).
- **The smoke fixture's hooks are relative to its root.** The six hook commands of
  `tests/lam/fixtures/lam-smoke/.claude/settings.local.json` name their scripts under `$CLAUDE_PROJECT_DIR`, not by
  absolute path into the first host's checkout, which was a known limit of 0.2.0. A copy of the fixture runs none of
  them until the framework's hook files stand at those paths, as they do in an installed project.

### D. Worktrees, line endings, and the tools around the installer

- **A reading taken in a worktree equals the root's.** WP-6 S-4b judges the pre-push decider a smoke repository's
  wrapper names by framework.lock's fold rule, so a CRLF worktree's decider and an LF checkout's read as the same text
  (and still differ where the text differs); and ZP resolves its exclusion row's disclosure on the primary checkout's
  runtime plane, which a linked worktree does not carry. The readings: section 4.
- **WP-2 R-36a measures a Windows path wherever the checkout stands**: 0.2.0's need for a `\U` segment in the
  checkout's path is gone.
- **The root `.gitattributes`.** The framework's own -- `* -text` and the two family lines `.mission/** -text` and
  `docs/framework/** -text` -- is installed as a TEMPLATE, by a fresh install only, and only into a folder that holds no
  file a git repository tracks: no `.git` there or above it, or `git ls-files` there listing nothing. An upgrade never
  writes it, nor does a first install into a repository with files of its own, because a framework install does not
  change a project's line-ending policy for the project's own files: the installer prints one `not-written` line,
  counts `not-written=1` after `kept=`, and records a `not-written` row in framework.lock (`sha256` and `eol` null),
  which `-Verify` passes over, saying `1 not written`. Where it is written, git stores and checks out every file as it
  is, whatever `core.autocrlf` says -- the project's own files too (LAM-INSTALL.md section 10).
- **A seat's commit in a worktree** has its ledger line written in the merge block that brings it into main, not where
  it is made: the primary checkout's composer refuses a commit outside its HEAD's history (LAM-INSTALL.md section 11).
- **In the framework repository only**: `tools/provenance/upgrade-diff.py` names each manifest by the digest of its
  installer-owned records (destination, class, sha256, bytes and eol), which a commit that changes only authored
  records leaves as it is, so a prediction made before the tag names the tag's manifest; `--digest` prints it, and a
  working tree whose manifest is not HEAD's is refused.
- **The Mark of the Web**: a ZIP fetched with `gh release download`, or with Windows PowerShell 5.1's
  `Invoke-WebRequest`, carries none (measured), so `Unblock-File` is for a browser download (INSTALL.md section 3).

## 2. Upgrading from 0.2.0

Over a project 0.2.0 installed, in your own Windows PowerShell 5.1 terminal, from the expanded release
(`C:\dl\vanguard-collective-v0.3.0` below, after INSTALL.md sections 1 to 4):

1. **If the project's goals answer legacy HALTs** -- a goal with a `legacy_answered_allowlist` -- **export the census
   first, before `install.ps1`**, from the release tree, naming the project's own 0.2.0 evaluator:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v0.3.0\tools\lam\export-legacy-census.ps1 -From C:\work\my-project\tools\lam\mission-goal-check.ps1
   ```

   It writes `tools\lam\legacy-halt-census.txt` beside that evaluator, one line per legacy HALT its literal names.
   Skip this step and, once the upgrade
   replaces the evaluator, those legacy HALTs are honoured no longer: each reads OPEN, and its goal HALT, until the
   census is written back (LAM-INSTALL.md section 10 says how, after the fact) or a `halt-ruling` gate answers it. A
   project with no legacy HALTs skips this step.
2. **Run `install.ps1`** against the project as INSTALL.md section 5 writes it: `-WhatIf` first if you like, which
   decides everything and writes nothing, then `-ReleaseZip <the ZIP>`. One refusal refuses the whole upgrade and names
   itself; nothing is then written.
3. **What it retires.** Eight paths 0.2.0 installed and this release does not carry: the seven files the synthetic
   fixtures replace -- the product instrument's four versions `tests/lam/fixtures/base-<sha8>/tests/lam/instrument-<host arc>.ps1.base`,
   the goal of record `base-<sha8>/.mission/goals/<host arc>.yaml`, and two legacy HALTs under `legacy-census-halts/`
   -- and `docs/framework/LAM-ACCEPT.md`. Each is named on a `retire` line, left in place and dropped from
   the lock; you may delete them. While `LAM-ACCEPT.md` stands at its 0.2.0 bytes, the six members of section 1C keep
   measuring against it.
4. **The root `.gitattributes` is not written** where the project has none: the installer prints its `not-written`
   line and the lock records a `not-written` row. To take the framework's rules, copy `.gitattributes` from the release
   tree and commit it -- first reading what `* -text` does to an existing `core.autocrlf=true` repository
   (LAM-INSTALL.md section 10).
5. **Verify**: `install.ps1 -Target <the project> -Verify` reads lock formats 1 and 2 and the `not-written` row. After
   the upgrade, where the root `.gitattributes` was not written, it reads `verify: 278 file(s) listed, 1 not written, 0
   difference(s); eol lf=276 crlf=1 mixed=0 binary=0.` in an LF checkout (a CRLF one counts its own line endings) and
   exits 0; where the project keeps its own, `278 file(s) listed, 0 difference(s)`.
6. **The planned counts**, as `tools/provenance/upgrade-diff.py` predicts them from 0.2.0's manifest and this
   release's, and as `-WhatIf` prints them (`planned:`) and the upgrade (`done:`), over a project 0.2.0 installed and
   nobody has edited since: `written=82 already-identical=186 kept=9 not-written=1 retired=8 refused=0` -- 72 files
   upgraded and 10 installed, 9 templates and host-configuration files kept, the root `.gitattributes` not written, 8
   retired, 186 left as they are -- and framework.lock rewritten, 279 lines for 278 files. Where step 1 wrote the
   census, the upgrade keeps it, byte for byte: `written=81` and `kept=10`. Where the project has a root
   `.gitattributes` of its own, the upgrade keeps it: `kept=` one more and no `not-written=`.
7. **Kept files stay as they were**: this upgrade rewrites no template or host-configuration file (no file changes
   kind between 0.2.0 and 0.3.0). Two of them changed in this release: `tools/mission-cli/config/mcp-tools.yaml`
   (TEMPLATE), whose 0.2.0 copy carries a first-host name this release removed from it, and
   `tools/tests/cli/test_prune_worktrees.py` (HOST-CONFIG); each lock row's `upstream_sha256` shows where the project's
   copy differs, and the new one is the project's to take from the release by hand. `docs/framework/LAM-RESIDUALS.md`
   did not change, so a completion-acceptance gate bound to it stands; no file under `tools/framework/` changed, so
   there is no sealed hash to re-seal.
8. **A live smoke repository made from an earlier release's fixture** carries the evidence-manifest schema as that
   release shipped it -- its `$id` and three of its descriptions differ from this release's -- and hook commands by
   absolute path into the first host's checkout: copy the installed `docs\framework\evidence-manifest.schema.json` into
   it and commit it, or WP-6 F-0 fails there; this release's fixture names its hooks under `$CLAUDE_PROJECT_DIR`.

## 3. Known limits

- **Internal and private, under the evaluation licence**: no redistribution or publication. The confidentiality pass
  that would make the repository public is not done.
- **The acceptance instruments do not yet read green in a project.** Run in a freshly installed project, 45 of the 287
  checks fail rather than skip (section 4), each for an input a project is not given: earlier versions of the tools
  that 31 WP-3 members read from this repository's history, which a project's history does not hold; the smoke mission
  that 11 members read (WP-2 R-35a and R-49, WP-3 C-2c and eight of WP-6's); the first host's live spawn ledger (WP-4
  T-42); this repository's own ignore rules (WP-1 H-26); and a gate WP-3 C-1e mints with the real gate tool, which
  exits 2 there. The instruments are meant to be read in this repository, where they read 274 passed, 0 failed and 13
  named skips; making every member pass or skip by name in a project is for a later release.
- **The acceptance instruments need the project to be a git repository.** In a folder that is not one, members that
  ask git about the checkout they stand in fail as well: 62 of the 287 fail there (section 4).
- **One platform**: Windows with Windows PowerShell 5.1, plus git and Python 3, and Claude Code Desktop to run a
  mission.
- **Key mode has not been run with a valid key.** It was exercised with dummy values and with a key the CLI rejected
  (`Invalid API key`, the runner refusing at its login probe): no worker billed to a real key has been observed by the
  framework's own tests.
- **Installed texts state the default without its condition**: LAM-INSTALL.md section 7c's first bullet; in
  `tools/lam/lam-auth-mode.ps1` its header comment, the reason text of its unset decision, and its `AUTH-MODE-UNKNOWN`
  refusal, which tells you to unset the variable "for the Claude subscription"; and a comment in
  `tools/lam/mission-dispatch.ps1`. Each calls the unset mode the subscription; a key left in the shell is used by the
  runner's print-mode CLIs (section 1A, INSTALL.md section 9). They are corrected in a later release.
- **The guard library's pre-push decider comparison is raw bytes.** WP-6 S-4b judges the decider by the fold rule,
  but the runner asks the guard library, which compares the raw sha256 of the decider across checkouts: dispatched from
  a checkout whose line endings differ from the ones the mission's wrapper names (a CRLF worktree against an LF
  checkout, say), a dispatch may be refused as a substituted decider. S-4b's face says why when it takes the fold path.
- **Six members SKIP in a project.** WP-1 H-12, WP-2 R-16 and R-B, and WP-3 C-1v, C-1w and C-2d skip by name in every
  project installed afresh or carried from 0.1.x, where the acceptance record they measure against is not to be found;
  only a project upgraded from 0.2.0 that keeps the retired file keeps them measuring.
- **The first host's arc ids are still in files the ZIP carries.** 845 lines in 49 of its files hold an id of the arc
  pattern -- 751 of them one of the first host's arc ids, 94 only ids of that shape the tests make up: the pinned base
  copies under `tests/lam/fixtures/base-*/` (513), the six instruments (221), the tools (77), the documents (25) and the
  manifest (9). Seven of the nine pinned base copies of the evaluator still carry its legacy census literal, the first
  host's HALT names. And `tools/tests/cli/test_prune_worktrees.py`, HOST-CONFIG, carries the first host's dispatch and
  session data: six of its items compare it with that host's own records on a runtime plane, and skip by name where
  those are absent (LAM-INSTALL.md section 10). Their clean-up is for 1.0.
- **`provenance/manifest.jsonl` is a member of the ZIP** and, by its records of the files the framework was extracted
  from, names the first host's product and its source paths (71 lines of the wider census classes).
- **The committed-tree key scan folds letter case as ASCII does**, the case a case-insensitive file system folds onto
  the names it reads, and does not read a symbolic link's target where git checks committed links out as links.
- **OneDrive is not detected.** The installer refuses every reparse point it meets below the folder it installs into,
  OneDrive's cloud-file placeholders among them -- so an upgrade, a same-version run or `-Verify` in a synced folder is
  refused once a placeholder stands below it -- but it does not judge the folder itself: a first install into an empty
  synced folder is not refused. Install from and into folders OneDrive does not sync.
- **The smoke materialiser is not installed**, nor the smoke fixture it copies: a project runs the acceptance
  instruments against a smoke repository it is handed (`-SmokeRoot`), or with none.
- **The mission planes are never touched**: the installer refuses every installer-owned path under `.mission/` or
  `.mission-runtime/`, so nothing the framework ships can stand there (the legacy census is under `tools/lam/` for that
  reason).

## 4. The release, counted

- **The ZIP holds 287 files**: the 278 the framework installs and nine more -- `install.ps1`, `mission.ps1`,
  `VERSION`, `LICENSE`, `README.md`, `INSTALL.md`, `provenance/manifest.jsonl`, these notes and `RELEASE` (INSTALL.md
  section 4). Installed into an empty folder, `install.ps1` writes the 278 -- the root `.gitattributes` among them --
  and a framework.lock of 279 lines, and `-Verify` reads `278 file(s) listed, 0 difference(s); eol lf=277 crlf=1`.
- **A fresh install's acceptance reading** -- this release's ZIP installed into an empty folder and its
  `tools\lam\instrument-acceptance.ps1` run there with no smoke repository -- reads, with the folder made a git
  repository holding the install in one commit and no mission initialised, **228 passed, 45 failed and 14 skipped of
  287** (on a ZIP built from this release's installed files before these notes were final).
  The 14 skips each name what they need: the six acceptance-record members of section 1C, three that need a Python
  venv to run a fixture's pytest (WP-2 R-57, WP-3 C-1k and C-1be), four the first host's runtime records or the
  container engine answer (WP-3 C-3e and C-1bd, WP-4 T-53 and T-54), and WP-6 S-1b, the smoke mission. The 45 failures
  are those Known limits names, each for an input a project is not given. In the empty folder alone, which is no git
  repository, 62 fail (211 passed, the same 14 skipped): the same 45 and 17 more, each
  asking git about the checkout it stands in -- WP-1 H-4, H-18 and H-24, WP-2 R-E and R-53 to R-56, and WP-4 T-30,
  T-36, T-41, T-43, T-44, T-46 to T-48 and T-58.
- **In this repository**, the six instruments read 274 passed, 0 failed and 13 named skips of 287 checks at the first
  commit of this release's build, whose installed files are this release's -- equal, face
  for face, to the readings at 2973521, whose installed files are this release's too: the root's and a linked
  worktree's, the worktree's equal to the root's.
  The skips are the first host's runtime records (WP-3 C-3e, WP-4 T-42, T-53 and T-54), its local Claude Code settings
  (WP-3 C-2c), the container engine's state (WP-3 C-1bd), and seven WP-6 members a root of the smoke fixture's files
  cannot answer. The Python tests read 606 passed, 0 failed and 14 skipped by name.
