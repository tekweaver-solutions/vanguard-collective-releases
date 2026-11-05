# Vanguard Collective 1.1.0 -- release notes

1.1.0 supersedes 1.0.0. It adds the dashboard, `vanguard ui`: a read-only view, local to one machine, of every
mission registered on it, fed by a mission-event feed that the framework's hooks and lifecycle commands now append in
each project (ADR-045 in the local-modes design document, section 11.6). The release carries the dashboard's built files
and its Python service; the install puts the service's pinned Python set into the project's `tools\.venv`. The licence
is unchanged: the evaluation licence in `LICENSE`. What this release does not do comes first.

## 1. Known limits

- **One platform.** Windows with Windows PowerShell 5.1, plus git and Python 3, and Claude Code to run a mission. The
  dashboard's Python set is pinned by sha256 to the wheels for CPython 3.14 on 64-bit Windows (win_amd64): the install
  needs that interpreter and the network to PyPI. With another interpreter in the project's `tools\.venv`, or none to
  make one with, every file and the lock are installed and `install.ps1` exits 4, naming the `pip` command to run
  (INSTALL.md section 5). macOS and Linux are not supported.
- **The dashboard is local and read-only.** Version 1 serves loopback only: a request whose Host is not loopback is
  answered 421 with no body by design, so binding another address with `--host` serves nothing -- the flag is reserved
  for the v2 hub. It sends nothing to an agent and writes nothing into a project. It shows no cost figure, and the
  tool-call exit rate reads "not captured" where no exit code was captured.
- **Stopping the service.** On Windows the service's catchable stops are Ctrl+C and Ctrl+Break; SIGTERM is the POSIX
  signal, and an external TerminateProcess (`Stop-Process`, Task Manager's End task) cannot be handled: the service then
  ends with no line of its own and may leave `ui.db`'s write-ahead files beside it.
- **A mission made before the feed is not on the dashboard until it is registered.** The upgrade does not register it
  (the installer never touches `.mission-runtime\`); it says so and names `mission.ps1 register -Target <project>`, which
  makes the feed folder, the project's registry row and the ignore rule `/.mission-runtime/telemetry/`.
- **The dashboard's source and the service's tests are not in the release.** They stay in the framework's development
  repository: in an installed project the WP-7 members that read them -- the service's V-members and the dashboard's
  L-members -- skip by name, as do F-0 and the U-members whose fixtures the release tree's `mission.ps1` makes.
- **A fresh install reads named skips.** A reading of a fresh install of this release -- a new git project with a bare
  origin, the install with its Python set (so `tools\.venv` holds the dashboard's packages and no pytest), `mission
  init`, the smoke mission built, the container engine down -- failed nothing and skipped fifty-nine members by name.
  Fifteen are the ones a fresh install of 1.0.0 skipped, with WP-3 C-1aw in place of C-1bd while the engine is down:
  WP-1 H-12; WP-2 R-16, R-B and R-57; WP-3 C-1k, C-1v, C-1w, C-2c, C-2d, C-3e, C-1aw and C-1be; WP-4 T-42, T-53 and
  T-54 -- WP-2 R-57 and WP-3 C-1k and C-1be now because `tools\.venv` holds no pytest, where 1.0.0's had no venv. The
  other forty-four are WP-7's: its twenty V-members and sixteen L-members, because the service's tests and the
  dashboard's source are not in the release; and F-0 with U-4, U-5, U-10, U-13, U-14, U-15 and U-16, because their
  fixtures are made by `mission.ps1` and read `VERSION`, which stay in the release tree and are not installed (the
  members that read only the smoke mission are measured). 1.0.0's notes, section 1, say how the first fifteen are measured; with the engine up, WP-3
  C-1bd skips in C-1aw's place.
- **`tools\.venv` is the framework tools' interpreter too.** The framework's own Python tools (the validator-result
  transcriber among them) take `tools\.venv`'s interpreter before `python` on `PATH`, and the install now makes that
  venv where there was none. So the pinned set carries PyYAML 6.0.3, which those tools import, beside the service's
  packages (operator ruling of 2026-11-04); a package your own tooling installed into `tools\.venv` stays there.
- **The dashboard's fonts are OFL-1.1.** Inter and JetBrains Mono, from the `@fontsource-variable` packages, are under
  the SIL Open Font License 1.1, which the release's licence allow-list admits for font packages only (operator ruling
  of 2026-11-04); `THIRD-PARTY-NOTICES` carries their licence text with every other package's.
- **1.0.0's known limits stand.** Its notes, section 1, list them: the default auth mode's wording, key mode unmeasured
  with a valid key, the guard library's raw comparison of the pre-push decider, WP-4 T-42, T-53 and T-54, OneDrive, and
  the traces of the project the framework was extracted from. This release changes none of them.

## 2. What changed since 1.0.0

- **The dashboard, `vanguard ui`.** The service, `tools/ui/` -- a Typer command starting FastAPI under uvicorn, its
  pinned set in `tools/ui/requirements.txt`, the command `tools/ui/vanguard.cmd` -- reads the host registry, tails every
  registered feed into a disposable SQLite projection, `ui.db` (`--rebuild` regenerates it), serves four read endpoints
  and live updates, and serves the dashboard's built files, `ui/dist/`, from the same process. Three screens: Fleet,
  Project and Stats, every figure with its formula, window and an as-of badge. The operator's guide has the Dashboard
  section.
- **The mission-event feed.** One append-only, never-committed file per checkout,
  `.mission-runtime/telemetry/events.jsonl`, each line valid against `docs/framework/mission-event.schema.json`
  (expanded-schemas section 14) and naming the `source_path@sha256` it reports. The next-generation evidence hooks, the
  lifecycle commands, the runners, the gate tool, the validator-result transcriber and the commit-ledger writer append
  it, through `tools/lam/emit-mission-event.ps1` and `tools/lam/mission-telemetry.ps1`; an append never blocks or fails
  the call that made it.
- **The host registry.** `host-id` and `projects.yaml` in the Vanguard home (`%USERPROFILE%\.vanguard`, or
  `VANGUARD_HOME`): `mission init` registers a new mission, `mission.ps1 register` an existing checkout, and
  `install.ps1` a target whose mission already has its feed folder.
- **The install puts the Python set in place.** After the files and the lock, a fresh install or an upgrade runs
  `pip install --require-hashes --only-binary :all: -r tools\ui\requirements.txt` in the project's `tools\.venv`, made
  with CPython 3.14 where there is none (`-Python` names the interpreter); `-SkipPythonSet` leaves it out; a step that
  cannot complete exits 4 with every file and the lock in place. `-WhatIf` now also says what the run would do outside
  the files: the Python set, the `vanguard` command, the host registration and the feed's ignore rule.
- **The release carries the dashboard built, and its licences.** `release.ps1` builds `ui/dist/` from the commit's
  `ui/` with `npm ci` and `npm run build` under the pinned Node and npm, and generates `THIRD-PARTY-NOTICES`: the
  production packages of `ui/package-lock.json` and the build-time packages whose output the bundle carries, read by the
  pinned licence checker, and the pinned Python set, read by pip-licenses -- each with its licence and licence text --
  refusing any licence outside the allow-list. The ZIP leaves out the dashboard's source and the service's tests, and
  its `provenance/manifest.jsonl` names the generated files, so the installer holds every file it installs to it.
- **WP-7**, `tests/lam/instrument-WP-7.ps1`, the seventh acceptance instrument: the feed (U-members), the service
  (V-members) and the dashboard (L-members); the acceptance wrapper, `tools/lam/instrument-acceptance.ps1`, now runs it
  after WP-6.
- **The zero-host-data gate**, `tools/lam/gate-host-data.ps1`: HARD classes that must read zero over a release tree and
  its expanded ZIP -- names from an operator's pattern file, given by parameter and never tracked, and from a host
  repository; host paths; ids only the host's history resolves; pinned host copies; provenance citing the host -- and
  SOFT classes listed, never blocking, with a report naming every hit by path and line.
- **The documents.** INSTALL.md (the Python set, the `vanguard` command, the new counts), `docs/QUICKSTART.md`, the
  operator's guide (the Dashboard section, the seventh instrument) and README.md.

## 3. Upgrading from 1.0.0

Over a project 1.0.0 installed, in your own Windows PowerShell 5.1 terminal, from the expanded release
(`C:\dl\vanguard-collective-v1.1.0`, after INSTALL.md sections 1 to 4) or from a clone at the tag `v1.1.0`:

1. **Run `install.ps1`** against the project as INSTALL.md sections 5 and 6 write it: `-WhatIf` first if you like,
   then `-ReleaseZip <the ZIP>` (no `-ReleaseZip` from a clone). One refusal refuses the whole upgrade and names itself;
   nothing is then written. Over a project nobody edited since 1.0.0 installed it, the upgrade ends:

   ```text
   install.ps1: done: written=75 already-identical=287 kept=11 retired=0 refused=0
   ```

   -- 20 files upgraded and 55 installed, the 11 templates and host-configuration files kept, none retired
   (INSTALL.md section 6 names them).
2. **Kept files stay as they were.** No template or host-configuration file changed in this release.
3. **No sealed file moved.** Nothing under `tools/framework/` and nothing in `docs/framework/LAM-RESIDUALS.md` changed.
4. **The Python set.** After the files the upgrade installs the dashboard's set into `tools\.venv` (INSTALL.md section
   5). A project whose `tools\.venv` is not CPython 3.14 win_amd64 keeps it untouched, and the run exits 4.
5. **Register the mission for the feed**: `mission.ps1 register -Target <the project>`, from the release.
6. **Verify**: `install.ps1 -Target <the project> -Verify` reads `373 file(s) listed, 0 difference(s)`.

## 4. The release, counted

- **The members rule.** The ZIP holds 408 files: the 388 files of the commit the tag `v1.1.0` names that the release
  carries -- every one but the dashboard's private source under `ui/` and the service's tests under `tools/ui/tests/`
  -- the 18 files of `ui/dist/`, `THIRD-PARTY-NOTICES` and `RELEASE`. `MEMBERS.sha256` lists each with its sha256, 408
  lines, and `SHA256SUMS` names the ZIP and `MEMBERS.sha256`.
- **Installed into an empty folder**, `install.ps1` writes the 373 installer-owned files (MOVE 362, TEMPLATE 8,
  HOST-CONFIG 3) and a framework.lock of 374 lines, and `-Verify` reads
  `373 file(s) listed, 0 difference(s); eol lf=360 crlf=1 mixed=0 binary=12`.
- **Upgraded from 1.0.0**, section 3's line; `release.ps1` derives it from the two releases' installer-owned sets and
  refuses a build whose notes do not carry it.
- **`THIRD-PARTY-NOTICES`** names 128 packages: 106 in `ui/dist/` (103 production packages and 3 build-time ones) and
  the 22 of the Python set; their licences are MIT (100), ISC (13), BSD-3-Clause (7), Apache-2.0 (2), OFL-1.1 (2),
  0BSD (1), BSD-2-Clause (1), PSF-2.0 (1) and MIT AND ISC (1).
