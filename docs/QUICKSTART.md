# Vanguard Collective 1.1.0 -- Quickstart

The shortest correct path from nothing to an installed project, an initialised mission, a built
smoke mission and a first acceptance reading. Every step is a command you run in **your own
Windows PowerShell 5.1 terminal**, never inside a Claude Code session. INSTALL.md is the full
procedure with the output to expect; this page is the route through it.

The examples use `C:\dl` for the download, `C:\src\vanguard-collective` for a clone, and
`C:\work\my-project` for the project. Any folders will do, but keep the project path short
(`install.ps1` refuses a path of 260 characters or more below it) and keep both the source and the
project out of folders OneDrive syncs (its placeholders are reparse points, which the installer
refuses).

## 1. Prerequisites

- Windows, with **Windows PowerShell 5.1**.
- Python 3.
- git. The smoke-mission builder needs git 2.48 or later.
- Claude Code, signed in. The wake starter (`tools\lam\lam-wake.ps1`) launches only a native
  `claude.exe` (section 6).
- Docker Desktop, only if your product's test suite needs it.

**Not supported in 1.0:** macOS and Linux.

**Unmeasured in 1.0:** PowerShell 7, and the Mark of the Web handling. Unmeasured means nothing in
this release was tested under them here: run every command with `powershell` (5.1), as written. A
ZIP your browser downloaded carries the Mark of the Web; INSTALL.md step 3 says how to unblock it
(`Unblock-File` on the ZIP before you expand it) and what earlier measurement found.

## 2. Get the release

Either way below gives you the same source: the release ZIP is the tagged commit's files plus one
generated file, `RELEASE`.

**A. The release assets.** Download `vanguard-collective-v1.1.0.zip`, `SHA256SUMS` and
`MEMBERS.sha256` from the release into `C:\dl`. Check the ZIP against `SHA256SUMS`, whose first line
names the ZIP and whose second names `MEMBERS.sha256`:

```powershell
$want = ((Get-Content C:\dl\SHA256SUMS)[0] -split '  ')[0]
(Get-FileHash -Algorithm SHA256 C:\dl\vanguard-collective-v1.1.0.zip).Hash.ToLower() -eq $want
```

It must print `True`; if not, stop -- the archive is not the one that was released. Check
`MEMBERS.sha256` the same way against the second line. Then unblock (browser downloads only) and
expand:

```powershell
Unblock-File C:\dl\vanguard-collective-v1.1.0.zip
Expand-Archive -LiteralPath C:\dl\vanguard-collective-v1.1.0.zip -DestinationPath C:\dl\vanguard-collective-v1.1.0
```

Optionally check every expanded file against `MEMBERS.sha256` (one line per member,
`<sha256>  <path>`). The first command prints nothing when every file matches; the second prints the
same number twice:

```powershell
Get-Content C:\dl\MEMBERS.sha256 | ForEach-Object { $h, $p = $_ -split '  ', 2; if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path C:\dl\vanguard-collective-v1.1.0 $p)).Hash.ToLower() -ne $h) { "DIFFERS $p" } }
(Get-Content C:\dl\MEMBERS.sha256).Count; (Get-ChildItem -LiteralPath C:\dl\vanguard-collective-v1.1.0 -Recurse -File -Force).Count
```

**B. A clone at the tag.** Clone outside the project folder and check out the release tag:

```powershell
git clone <public repository URL> C:\src\vanguard-collective
cd C:\src\vanguard-collective
git checkout v1.1.0
```

The installer accepts a clone only when HEAD is exactly the commit tag `v1.1.0` names and
`git status --porcelain` prints nothing. Anything else -- a branch whose tip is not the tagged commit, commits on top of the tag, a
local change, an untracked file -- is refused before anything is written, with exit 1 and a last
line beginning `install.ps1: REFUSED:`. A local change or an untracked file is listed first: up to
ten lines `install.ps1:   LOCAL CHANGE  <git status line>` (then `install.ps1:   ... and <n> more`
when there are more), and the refusal then reads `install.ps1: REFUSED: the source checkout has
local changes (git status --porcelain is not empty) -- install from a clean clone at the release
tag. Nothing was written.` Every other refusal of the source is that one `REFUSED:` line alone.
Clone again, or put the clone back at the tag with nothing changed.

Below, `<release>` is `C:\dl\vanguard-collective-v1.1.0` (A) or `C:\src\vanguard-collective` (B).

## 3. Install

See what it would do first; `-WhatIf` decides every file and writes nothing (its exit code is the
real run's):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <release>\install.ps1 -Target C:\work\my-project -WhatIf
```

Then install. From the ZIP, name it so `framework.lock` records its sha256; from a clone, leave
`-ReleaseZip` out (the installer refuses it with a clone):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.1.0\install.ps1 -Target C:\work\my-project -ReleaseZip C:\dl\vanguard-collective-v1.1.0.zip
powershell -NoProfile -ExecutionPolicy Bypass -File C:\src\vanguard-collective\install.ps1 -Target C:\work\my-project
```

Then check the project against its lock (it never writes):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <release>\install.ps1 -Target C:\work\my-project -Verify
```

Exit codes: **0** done (or already installed and verified); **2** refused, nothing written -- every
refused path is named with its reason; **3** `-Verify` found a difference; **1** the source or target
could not be used; **4** every file and the lock are installed, but the dashboard's Python set is not
(the reason and the `pip` command to run are printed). The installer never touches `.mission\` or
`.mission-runtime\`, and never overwrites a file it did not put there.

The install ends by putting the dashboard's pinned Python packages into the project's `tools\.venv`
with `pip --require-hashes`, from PyPI: it needs CPython 3.14 for 64-bit Windows (`py -3.14`) and the
network. Then `C:\work\my-project\tools\ui\vanguard.cmd ui` starts the dashboard on
`http://127.0.0.1:8765/` (INSTALL.md section 5; the user guide's Dashboard section).

## 4. Initialise the mission

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <release>\mission.ps1 init -Target C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File <release>\mission.ps1 smoke -Target C:\work\my-project
```

`init` writes an empty mission under `.mission\` -- every value a placeholder for you to fill in --
and refuses (exit 2, nothing written) if any of its files is already there. `smoke` runs the
project's installed goal evaluator over the goal `init` wrote and exits 0 only when the verdict is
`MET`. INSTALL.md section 8 shows the expected output and how to accept the first spec.

`init` also adds two ignore rules to the project, for `.claude/settings.local.json` and
`.claude/worktrees/`: both are local to one machine and never belong in the project's history (WP-1
H-26 checks that they stay ignored).

The toolchain assumes the project is a git repository (LAM-INSTALL.md section 5.4 installs the
pre-push decider into it, and the runner refuses to dispatch until it is there). Make it one before
you go further.

## 5. Authentication

One environment variable, `VANGUARD_AUTH_MODE`, read from the shell you run the toolchain from,
decides how every Claude Code CLI the toolchain starts is authenticated:

- **Unset (the default).** Nothing is set or checked: the CLI uses the Claude subscription Claude
  Code is signed in with -- provided no credential is in the environment. An `ANTHROPIC_API_KEY`,
  a bearer token (`ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`) or a cloud-provider selector
  (`CLAUDE_CODE_USE_BEDROCK` / `_VERTEX` / `_FOUNDRY`) left in the shell is used, and billed, by
  every print-mode CLI the runner starts, by Claude Code's own precedence (only the first-generation
  worker-runner removes `ANTHROPIC_API_KEY`).
- **`subscription`.** The subscription, claimed out loud: an `ANTHROPIC_API_KEY`,
  `ANTHROPIC_AUTH_TOKEN` or a `CLAUDE_CODE_USE_BEDROCK` / `_VERTEX` / `_FOUNDRY` selector in the
  environment, or a credential setting in a settings file the session loads, is refused
  (`AUTH-MODE-BOTH-CLAIMED`).
- **`api-key`.** Bill an Anthropic API key. Set it in your own terminal, without typing the key on
  a command line (PowerShell's line editor saves typed lines to its history file):

  ```powershell
  $env:ANTHROPIC_API_KEY = [System.Net.NetworkCredential]::new('', (Read-Host -AsSecureString 'Anthropic API key')).Password
  $env:VANGUARD_AUTH_MODE = 'api-key'
  ```

  The key travels in the environment only. The runner and the wake starter refuse, exit 2, before
  any CLI that calls a model starts: `AUTH-MODE-KEY-ABSENT` (no key), `AUTH-MODE-BOTH-CLAIMED`
  (another credential beside it), `AUTH-MODE-KEY-IN-ARGUMENT` or `AUTH-MODE-KEY-IN-FILE` (a
  key-shaped value where the CLI would read it).

Any other value is refused `AUTH-MODE-UNKNOWN`; the values are matched exactly, in lower case. To go
back to the subscription, remove both variables from the shell. **Run the acceptance readings with
`VANGUARD_AUTH_MODE` unset.** LAM-INSTALL.md section 7c has the mechanism.

## 6. If `claude` is a .ps1 shim: CLAUDE-NOT-EXE

The wake starter, `tools\lam\lam-wake.ps1`, launches a seat only through a native `claude.exe`. It
asks PowerShell which command a bare `claude` would run, invoking nothing; if that is a `.ps1`,
`.cmd` or `.bat` shim, a function or an alias, it refuses `CLAUDE-NOT-EXE` (exit 2, nothing written,
no session), because a shim re-parses the arguments and delivers something other than the documented
command line. An npm global install of Claude Code leaves exactly such shims (`claude.cmd` and
`claude.ps1`). Check what yours resolves to:

```powershell
Get-Command claude | Format-List CommandType, Source
```

`CommandType` must be `Application` and `Source` must end `.exe`. If not, put the directory holding
the native `claude.exe` first on `PATH` (and remove any `claude` alias or function from your profile),
then check again. LAM-INSTALL.md section 5.7 describes the starter.

## 7. Build the smoke mission

The smoke mission is the worked example the acceptance instruments read. It is not installed; the
installed builder makes it, as a git repository `lam-smoke` with a bare origin
`lam-smoke-origin.git` beside it. Run it from the project, in a `powershell -File` process of its own:

```powershell
cd C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\build-smoke-mission.ps1
```

It builds `C:\work\lam-smoke` and `C:\work\lam-smoke-origin.git` (`-SmokeRoot <folder>\lam-smoke`,
or the variable `LAM_SMOKE_ROOT`, builds elsewhere), spawns no CLI worker, prints each step and ends
`EXIT: 0`. Exit 2 is a refusal before anything was written -- among them a root or origin that
already exists (it never overwrites: delete both folders to rebuild), a root inside a git work tree,
and a git older than 2.48. Exit 1 is a failure part way; the folders are left for inspection.

## 8. Take a reading

```powershell
cd C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\instrument-acceptance.ps1 -RunKey reading-1 -SmokeRoot C:\work\lam-smoke
```

A reading runs the seven instruments, WP-1 to WP-7, in order and writes two captures per instrument
under `C:\work\my-project\.mission-runtime\lam\instrument-runs\`:
`reading-1.instrument-WP-<n>.stdout.txt` and `.tally.txt`. **A whole reading takes about an hour.**
Each run key is used once: a key that already names a capture is refused (exit 9), never
overwritten. `-SmokeRoot` must be an existing folder; without it each instrument reads its default,
`lam-smoke` beside the project. **WP-6's S-1b spawns one real worker against the smoke mission, and
that worker is billed** to whatever the CLI authenticates with.

The wrapper prints `RUNKEY`, `ROOT`, `HEAD`, `BRANCH`, `PORCELAIN`, `PATH-DERIVATION`, `STARTED`,
one `---- WP-<n> exit=<code> seconds=<s>` block per instrument, `ENDED`, `HEAD-AFTER`,
`PORCELAIN-AFTER`, `CAPTURES` (each capture with its size and sha256) and `SUMMARY`. Each
instrument's exit code is its failure count.

The verdict of each instrument is the `CHECKS` line in its `.tally.txt`, read from the instrument's
own closing count line:

```text
CHECKS instrument=WP-5 result=passed checks=<n> passed=<n> failed=0 skipped=0 lines=1 exit_code_agrees=True
```

- `result=passed` -- every member was measured and passed.
- `result=FAILED` -- `failed=` members failed; the exit code is that count. Read the `[FAIL]` lines
  in the `.stdout.txt` capture.
- `result=passed_with_skips` -- nothing failed, and `skipped=` members could not be measured here.
  **A skip is not a pass.** Each one prints a `[SKIP] <member> -- <title>` line and a detail
  beginning `SKIPPED:` with its reason; read it.
- `exit_code_agrees=True` -- the exit code is the one the count line implies.

On a freshly installed project some named skips are expected, because what they need does not
exist there. A reading of a fresh install of this release (a new git project with a bare origin,
the install with its Python set, `mission init`, the smoke mission built, the container engine down)
failed nothing and showed fifty-nine:

- **WP-1 H-12; WP-2 R-16, R-B; WP-3 C-1v, C-1w, C-2d** -- the project acceptance record they
  measure against (`docs/framework/LAM-ACCEPT.md`) is not in the checkout; no release after 0.2.0
  ships it.
- **WP-2 R-57; WP-3 C-1k, C-1be** -- no venv with pytest to run the fixture's tests under: the
  install's `tools\.venv` holds the dashboard's packages and no pytest (install pytest into it, or make
  `src\.venv`, and they are measured).
- **WP-3 C-2c** -- no `.claude\settings.local.json` in the checkout (nor in the primary checkout).
- **WP-3 C-3e** -- the runtime plane holds no `HALT-*` file, so there is nothing live to drive.
- **WP-3 C-1aw** -- the container engine is down, so what a goal reads with it up cannot be measured;
  with Docker Desktop running, **C-1bd** skips in its place (its DOWN case cannot be measured).
- **WP-4 T-42** -- the project's runner has written no spawn ledger yet. Once it has, T-42 fails;
  the release notes' known limits say why.
- **WP-4 T-53, T-54** -- each re-read records of the project the framework was extracted from,
  which are not part of this distribution.
- **WP-7 V-1 to V-20 and L-1 to L-16** -- the dashboard service's tests and the dashboard's source
  stay in the framework's development repository; the release carries the service and the built
  dashboard only.
- **WP-7 F-0, U-4, U-5, U-10, U-13, U-14, U-15, U-16** -- their fixtures are fresh checkouts made by
  `mission.ps1 init` and read `VERSION`, which stay in the release tree and are not installed.

Three members that failed on a fresh install of a build before 1.0.0 were cured in 1.0.0: WP-1
H-26 (`mission init`
now adds the ignore rules for `.claude/settings.local.json` and `.claude/worktrees/`), WP-3 C-2e (the
build read there had changed `mission-goal-check.ps1` strings that C-2e compares with the base
evaluator's; they are restored), and WP-4 T-42, now a named skip until the project's runner has
written a spawn ledger. **A failure on a
fresh install is not expected**: a `FAILED` result names its members; read their `[FAIL]` detail
first. The user guide explains each kind of skip, and the release notes' known limits say how to
measure the ones your environment decides.

## 9. Where to go next

- `INSTALL.md` -- every step above with its expected output; upgrades; the install contract.
- `docs/framework/vanguard-collective-user-guide.md` -- what the parts are and how to read a reading.
- `docs/framework/LAM-INSTALL.md` -- the operator's full procedure for the toolchain: hook
  registrations, the pre-push decider, the operator console, HALT rulings, authentication, and the
  complete operator install sequence. Read it whole before its step 1.
