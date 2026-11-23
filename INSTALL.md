# Installing Vanguard Collective 1.3.3

From the release ZIP -- or a clone of the public repository at the release tag (section 5) -- to a
project folder that holds the framework and an empty mission whose goal reads MET. Every command runs
in **your own Windows PowerShell 5.1 terminal**, not inside a Claude Code session -- the same rule `docs/framework/LAM-INSTALL.md` opens with ("Who runs this: the
operator, at their own terminal"). The examples use `C:\dl` for the download and `C:\work\my-project`
for the project; any folders will do, but keep the project path short (the longest installed path
is 103 characters below it, and `install.ps1` refuses a target that would reach 260).

The dashboard, `vanguard ui`, runs on Python: the install puts its pinned packages into
`tools\ui\.venv` with `pip --require-hashes`, and those hashes are the wheels for **CPython 3.14 on 64-bit
Windows (win_amd64)** -- have it installed (the python.org installer, with the `py` launcher) and the
network to PyPI during the install (section 5). Node is not needed: Node 24.16.0 builds the dashboard when
the release is made, and the release carries the built files.

What you install is free to use under the release's `LICENSE`, for commercial and client work too; the
Framework itself may not be redistributed or resold. Support is by subscription, for paying customers:
support@tekweaver.ca.

## 1. Download

The releases are published on the Releases page of the public repository,
https://github.com/tekweaver-solutions/vanguard-collective-releases/releases. Each release carries four assets: the
archive under its versioned name, `vanguard-collective-v<VERSION>.zip` (`<VERSION>` is the release's version, the text
of its `VERSION` file); the same archive under the fixed name `vanguard-collective.zip`, so
https://github.com/tekweaver-solutions/vanguard-collective-releases/releases/latest/download/vanguard-collective.zip
always fetches the latest release's; `SHA256SUMS`; and `MEMBERS.sha256`. Put `vanguard-collective-v1.3.3.zip`,
`SHA256SUMS` and `MEMBERS.sha256` in `C:\dl` -- from the Releases page, or with the GitHub CLI, which fetches every
asset of the release its tag names:

```powershell
gh release download v<VERSION> --repo tekweaver-solutions/vanguard-collective-releases --dir C:\dl
```

## 2. Check the hash

```powershell
(Get-FileHash -Algorithm SHA256 C:\dl\vanguard-collective-v1.3.3.zip).Hash.ToLower()
```

```powershell
Get-Content C:\dl\SHA256SUMS
```

The first prints 64 hex characters; they must equal the first field of the second's first line, the
one naming the ZIP. If they differ, stop: the archive is not the one that was released.
`SHA256SUMS`'s second line names `MEMBERS.sha256`; check it the same way:

```powershell
(Get-FileHash -Algorithm SHA256 C:\dl\MEMBERS.sha256).Hash.ToLower()
```

`MEMBERS.sha256` has one line per file in the archive, `<sha256>  <path>` (two spaces, forward
slashes), in path order: the files of the commit the release tag names that the release carries, the
dashboard's build output under `ui/dist/`, `THIRD-PARTY-NOTICES` and `RELEASE` (section 4). Once the archive is expanded (section 4),
check the folder against it file for file -- the first command prints nothing when every file
matches, and the second prints the same number twice, so no file is missing and none was added:

```powershell
Get-Content C:\dl\MEMBERS.sha256 | ForEach-Object { $h, $p = $_ -split '  ', 2; if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path C:\dl\vanguard-collective-v1.3.3 $p)).Hash.ToLower() -ne $h) { "DIFFERS $p" } }
```

```powershell
(Get-Content C:\dl\MEMBERS.sha256).Count; (Get-ChildItem -LiteralPath C:\dl\vanguard-collective-v1.3.3 -Recurse -File -Force).Count
```

## 3. Unblock the ZIP -- your step

```powershell
Unblock-File C:\dl\vanguard-collective-v1.3.3.zip
```

A file downloaded by a browser carries the Mark of the Web (a `Zone.Identifier` stream); one
downloaded with `gh release download`, or with Windows PowerShell 5.1's `Invoke-WebRequest -OutFile`,
carries none (measured: the first on the 0.2.0 ZIP, the second on another download), and after
either this step has nothing to unblock and is not needed. What was measured, on a release ZIP given
that stream (Internet zone):

- Expanded by **Explorer** (or the Explorer shell's zip engine), **every** file carries the mark,
  and a host policy of `RemoteSigned` -- the policy on the measuring host -- then refuses
  `install.ps1` before its first line runs: *"... is not digitally signed. You cannot run this
  script on the current system."* `mission.ps1` is refused the same way.
- Expanded by **`Expand-Archive`**, **no** file carries it -- under Windows PowerShell 5.1
  (Microsoft.PowerShell.Archive 1.0.1) and under PowerShell 7 (7.6.9, Archive 1.2.6) alike (measured
  2026-11-08 on the 1.2.0 ZIP given the stream: 0 of 417 members marked under either shell).
- With **`Unblock-File` on the ZIP first**, no file carries it, whichever way it is expanded.
- **Installed files never carry it.** `install.ps1` writes every file fresh, so even an install from
  a marked tree (run with `-ExecutionPolicy Bypass`) leaves a project whose scripts run under
  `RemoteSigned`. A tree Explorer expanded is refused by `RemoteSigned` under PowerShell 7 (7.6.9, the
  same measurement) exactly as under 5.1.

`install.ps1` cannot unblock itself -- a refused script never runs -- and stripping streams from your
download is your act, so this step is yours. If you skip it, the installer still runs under
`-ExecutionPolicy Bypass` (the form every command on this page uses), under Windows PowerShell 5.1 or
PowerShell 7 (installer falsifier case h7, read for 1.3.3 on 7.7.0), and prints two lines: before the plan, `MARK OF THE WEB: this tree carries a
Zone.Identifier stream on N file(s) (...)` with the fix, counting `install.ps1`, `mission.ps1` and
every installer-owned file it reads; after the write, `MARK OF THE WEB: N file(s) written; carrying a
Zone.Identifier stream after the write: 0` -- every written file is read for the stream, and one
found is removed from it.

**PowerShell 7.** `install.ps1`, `mission.ps1` and `tools\lam\build-smoke-mission.ps1` run under
`pwsh` to the same dispositions, counts and exit codes as under Windows PowerShell 5.1 (installer falsifier
case p7, read for 1.3.3 on 7.7.0) -- but for an upgrade over a project whose `tools\ui\.venv` 1.3.2
made: from `pwsh` (7.7.0) it writes the same files and exits 4, leaving that set as it stood (the 1.3.3 release notes, section 1), so
run an upgrade from Windows PowerShell 5.1. The framework's hooks are run by Windows PowerShell 5.1 by name
(`powershell`), whichever shell you type in, and the smoke builder and WP-7 start their children with
5.1's own path; Windows ships it.
The acceptance wrapper (`tools\lam\instrument-acceptance.ps1`) runs under either shell, and its runner
(`tools\lam\lam-instrument-run.ps1`) starts each instrument with `& powershell`: `tests\lam\instrument-WP-1.ps1`
.. `-WP-7.ps1` run under Windows PowerShell 5.1 whichever shell starts the wrapper. A reading of WP-1 .. WP-4
under a PowerShell 7 host was not taken (register row 538).

**A Windows PowerShell child below another program.** A process inherits the environment of the program
that starts it, so a Windows PowerShell 5.1 process started by a program that is not PowerShell itself
gets the `PSModulePath` that program was given. Under a PowerShell 7 prompt that path names 7's module
folders first. Measured with pwsh 7.7 -> Python (pytest) -> Windows PowerShell 5.1, `Get-FileHash` is not
recognized there; with pwsh 7.7 -> cmd -> Windows PowerShell 5.1, each probed alone, 5.1 cannot load the
six script functions of its `Microsoft.PowerShell.Utility` (`Get-FileHash`,
`New-TemporaryFile`, `New-Guid`, `Format-Hex`, `Import-PowerShellDataFile`, `ConvertFrom-SddlString`) nor
the three commands of `Microsoft.PowerShell.Security` probed (`Get-Acl`, `Get-ExecutionPolicy`,
`ConvertTo-SecureString`). PowerShell 7 corrects the path for a `powershell` it starts with `&` and not for
one it starts with `Start-Process` (read for 1.3.3 on 7.7.0). The suite launcher (`Invoke-SuiteDefaultRun` in
`tools\mission-lib.ps1`), `tools\tests\cli\conftest.py`, `tools\lam\commit_ledger.py` and
`tests\lam\wp7-group-b.py` give such a child no `PSModulePath`, so each edition builds its own (installer
falsifier case ra9 runs the launcher and the conftest under both shells, PowerShell 7 read for 1.3.3 on 7.7.0; ra10 reads the other two in their
code and lists every other installer-owned file that starts one, with its reason). Two chains stay outside
the framework's reach and were not measured for 1.3.3: Claude Code's hooks are Claude Code's children, and
the git pre-push hook the evidence library installs runs `powershell` below git, so a Claude Code started,
or a `git push` typed, at a PowerShell 7 prompt would hand that 5.1 child 7's path; the evidence library
both load hashes files with `Get-FileHash`. Over a host uv
project whose run writes to stderr (uv's first-run lines and one of the project's own), the suite launcher
under Windows PowerShell 5.1 returned the exit code and the tally it returned under PowerShell 7 (7.7.0, read
for 1.3.3), for a passing suite and a failing one (case ra15).

## 4. Expand

```powershell
Expand-Archive -LiteralPath C:\dl\vanguard-collective-v1.3.3.zip -DestinationPath C:\dl\vanguard-collective-v1.3.3
```

The archive holds 434 files: the 414 files of the commit the release tag names that the release
carries -- every one but the dashboard's private source (`ui/`, but for its build output) and the
service's tests (`tools/ui/tests/`) --, the 18 files of the dashboard's build output under `ui/dist/`,
built from that source when the release was made, `THIRD-PARTY-NOTICES` (the licences of the
third-party software the release carries, generated with it), and `RELEASE` (the version, the commit
the release was built from, and the sha256 of the archive's `provenance/manifest.jsonl`) -- the one
file no commit can hold, since it names the commit. `MEMBERS.sha256` lists them all (section 2). The
archive's `provenance/manifest.jsonl` is the commit's, less the lines of the files the release leaves
out and with a line for each file of `ui/dist/` and for `THIRD-PARTY-NOTICES`, so it names every file
the installer takes from the archive. The 387 files the framework installs are among them, `ui/dist/`
and `THIRD-PARTY-NOTICES` included, with `install.ps1`, `mission.ps1`, `VERSION`, `LICENSE`,
`README.md`, this file, `provenance/manifest.jsonl`, the release notes
`docs/RELEASE-NOTES-v<version>.md`, and every file the framework repository keeps for itself and does
not install.

## 5. Install

Optionally, first see what it would do (`-WhatIf` decides everything and writes nothing):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.3.3\install.ps1 -Target C:\work\my-project -WhatIf
```

Then install, naming the ZIP so the lock records its sha256:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.3.3\install.ps1 -Target C:\work\my-project -ReleaseZip C:\dl\vanguard-collective-v1.3.3.zip
```

Into an empty folder, expect one `install` line per file between the first lines and the last:

```text
install.ps1: source C:\dl\vanguard-collective-v1.3.3 (release at <commit>, version 1.3.3)
install.ps1: target C:\work\my-project
install.ps1: manifest sha256 <64 hex>; installer-owned 387 (MOVE 376, TEMPLATE 8, HOST-CONFIG 3); framework.lock absent
install.ps1: fresh install: no framework.lock in the target
install.ps1:   install            .claude/settings.json
...
install.ps1: host registration: host-id <id> in C:\Users\<you>\.vanguard; no registry row (the target carries no mission yet: mission init adds it)
install.ps1: python set: tools\ui\.venv made by py -3.14: <its python.exe> (CPython 3.14.<n>, win-amd64)
install.ps1:   pip | Successfully installed annotated-doc-0.0.5 ... uvicorn-0.54.0
install.ps1: python set: 22 pinned package(s) in tools\ui\.venv, installed with --require-hashes
install.ps1: done: written=387 already-identical=0 kept=0 retired=0 refused=0
install.ps1: framework.lock written: 388 line(s) for 387 file(s), sha256 <64 hex>
install.ps1: installed 1.3.3 into C:\work\my-project.
```

and exit code 0. Check the folder against its lock at any time:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.3.3\install.ps1 -Target C:\work\my-project -Verify
```

which ends `verify: 387 file(s) listed, 0 difference(s); eol lf=374 crlf=1 mixed=0 binary=12.` (one
framework file has CRLF line endings of its own, and twelve of the dashboard's font files hold a 0x00
byte, so they are judged binary) and exits 0, or 3 when a file differs. It writes nothing under the installed set or
the lock. From 1.3.0, where the project is registered (its `.mission-runtime\telemetry` feed and a host registry row:
`mission init` or `mission register`), it appends one `verify_result` line to that feed listing each difference it
printed, and says so (`verify: one verify_result line appended to the project's feed ...`); `vanguard ui` shows them on
the verify card. Elsewhere it says no feed line was written and writes nothing at all.

### The Python set and the `vanguard` command

After the files and `framework.lock` are in place, a run that writes -- a fresh install or an upgrade --
installs the dashboard service's pinned Python packages into `tools\ui\.venv`, a folder of the framework's own
beside the `vanguard` command:

```text
<project>\tools\ui\.venv\Scripts\python.exe -m pip install --require-hashes --only-binary :all: -r <project>\tools\ui\requirements.txt
```

from PyPI, every wheel held to the sha256 `tools\ui\requirements.txt` pins (ruling F4 of UI-1) -- the
service's packages and PyYAML, which the framework's own Python tools import and which they find there, since
they take `tools\ui\.venv`'s interpreter first. Those
hashes are the CPython 3.14 win_amd64 wheels, so `tools\ui\.venv` must be that interpreter: one that stands
is used when its `Scripts\python.exe` is CPython 3.14 for win-amd64, and left untouched when
it is anything else; with none the installer makes one, with `-Python <python.exe>` when you
name it, else the `py` launcher's 3.14 (`py -3.14`), else `python` on `PATH`. `-WhatIf` says which it
would use. When the step cannot complete -- no such interpreter, no network, a hash pip refuses -- every
file and the lock still stand: the installer says why and prints the two commands that build the set once the
cause is gone, and exits **4**. `-SkipPythonSet` installs the files and the lock only and leaves `tools\ui\.venv`
as it is. A run that writes nothing (`-WhatIf`, `-Verify`, a same-version run) installs nothing.
`tools\ui\.gitignore`, installed with the files, keeps the folder out of `git status`; it is the one rule
that does, since the installer makes the folder with `venv`'s `--without-scm-ignore-files`.

**When `tools\ui\.venv` is missing.** Once a project is at this release's version, running `install.ps1` again --
with `-Python` or without -- does not build it: that run writes nothing. Build it with the two commands the
installer's own step runs, from PowerShell, with the project's folder in `<project>`'s place -- a single quote in its
name (`'`, or a curly one) written twice, as the installer's own printed commands write it -- and another CPython 3.14
win-amd64 `python.exe` in `py -3.14`'s place, if you name one:

```powershell
py -3.14 -m venv --without-scm-ignore-files '<project>\tools\ui\.venv'
& '<project>\tools\ui\.venv\Scripts\python.exe' -m pip install --require-hashes --only-binary :all: --disable-pip-version-check --no-input -r '<project>\tools\ui\requirements.txt'
```

**`tools\.venv` is the host's.** Releases before 1.3.1 put this set there, in the folder uv (and other Python
tools) use for a project living under `tools\`; from 1.3.1 the installer never reads, writes, moves or deletes it,
and no framework tool, hook test or command runs its interpreter (the acceptance instruments WP-2 and WP-3 take it,
as one of the project's own environments, to run a fixture's pytest under it when it holds an interpreter). An upgrade from 1.3.0 builds `tools\ui\.venv` and leaves `tools\.venv`
exactly as it stood, the 1.3.0 set still in it: yours to keep, to rebuild from your own project's lock, or to delete.

The `vanguard` command is `tools\ui\vanguard.cmd`, installed with the other files; it runs the service
with `tools\ui\.venv`'s interpreter. From the project:

```powershell
C:\work\my-project\tools\ui\vanguard.cmd ui --help
C:\work\my-project\tools\ui\vanguard.cmd ui
```

The first prints the command's usage and exits 0; the second starts the dashboard on
`http://127.0.0.1:8765/` until Ctrl+C. To type `vanguard ui` instead, put `C:\work\my-project\tools\ui` on
your `PATH`. The dashboard is local-only in this version: it binds 127.0.0.1, and a request that does not
name a loopback host (`127.0.0.1`, `localhost` or `[::1]`) is answered 421 with no body, so binding
another address with `--host` serves nothing -- the flag is kept for the v2 hub. The operator's guide
has the Dashboard section, with the service's one stated limit on reading a feed: the tail window
(`--tail-window-bytes`, 4096 by default), shown on the Fleet stats screen.

### Install from a clone of the public repository

The public repository holds one commit per release: the expanded release ZIP (section 4), `RELEASE`,
`ui/dist/` and `THIRD-PARTY-NOTICES` among its files. So a clone of it checked out at the release tag is
the same source, and its `install.ps1` installs from it with no ZIP at all. Clone it outside the project folder, and check out the tag -- git leaves HEAD
detached at it:

```powershell
git clone https://github.com/tekweaver-solutions/vanguard-collective-releases.git C:\src\vanguard-collective
cd C:\src\vanguard-collective
git checkout v1.3.3
```

The release tags are annotated: each names a tag object, which points to the release's commit. So
`git ls-remote` lists the tag object's id for `refs/tags/v<VERSION>`, not the commit's -- the commit is on
the line after it, the one ending `^{}` -- and `git clone --branch v<VERSION>` prints
`warning: refs/tags/v<VERSION> <id> is not a commit!` before it checks the commit out: the id it names is the
tag object's, and the warning is harmless. In the clone, the commit is

```powershell
git rev-parse v<VERSION>^{commit}
```

-- `<VERSION>` the text of the release's `VERSION` file -- and that commit is the one the installer holds HEAD
to and records in the lock as `source_commit` (below).

Then install as above, from the clone and without `-ReleaseZip` (there is no archive to name, and the
installer refuses one with a clone):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\src\vanguard-collective\install.ps1 -Target C:\work\my-project
```

Its first line names the tag and the commit, and the rest is the output above:

```text
install.ps1: source C:\src\vanguard-collective (clone at tag v1.3.3, commit <commit>, version 1.3.3)
```

A clone is accepted only as the release it stands for. A source folder holding `.git` is a clone, never an
expanded release: before the installer reads its manifest or any file, git (reading `VERSION` from HEAD) must
confirm it, or the installer REFUSES, exit 1, on one line beginning `install.ps1: REFUSED:`, a clone that is
- **off the tag** -- HEAD is not the commit the tag `v<version>` names, or no tag has that exact name (`V1.3.3`
  is not `v1.3.3`): `install.ps1: REFUSED: the source checkout is not at tag v1.3.3 (HEAD <commit>; tag v1.3.3
  absent) -- install from a clone at the release tag, or from the release ZIP. Nothing was written.` (`at <commit>` in place of
  `absent` when the tag names another commit). A branch elsewhere, or the tag with commits on top of it, is not
  the release; a branch whose tip is the tagged commit is accepted (HEAD is then that commit).
- **changed** -- `git status --porcelain` prints anything: a tracked file changed or deleted, an installed one
  too, or a file git does not track (one `.gitignore` ignores does not count): `install.ps1: REFUSED: the source
  checkout has local changes (git status --porcelain is not empty) -- install from a clean clone at the release
  tag. Nothing was written.`, after a `LOCAL CHANGE` line for each of the first ten. A `RELEASE` HEAD does not track is refused, ignored or not.
- **unconfirmed** -- git is not on PATH, cannot open the `.git`, distrusts the folder (`safe.directory`), or answers
  for a repository above it: `install.ps1: REFUSED: the source holds .git but git cannot confirm it is a clean checkout at the release tag (<reason>) -- ...`

In every case, clone again, or put the clone back at the tag with nothing changed, and run it again.

The lock records where the framework came from: `source_kind` `clone`, `source_tag` the tag
(`v1.3.3`) and `source_commit` the commit (40 hex), which is `framework_repo_tip` too unless HEAD tracks a
`RELEASE`, whose tip is recorded there; `zip_sha256` is null. An install from the ZIP records `source_kind` `release`, `source_tag` and `source_commit` null,
and the ZIP's sha256 when `-ReleaseZip` names it (null without it). Every file line, and every other header field but the times, is what the ZIP's
install of the same release writes. `-Verify` works the same for both: it reads the project and its
lock, never the source, so the clone's `install.ps1` runs it as the expanded ZIP's does:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\src\vanguard-collective\install.ps1 -Target C:\work\my-project -Verify
```

To upgrade later (section 6), check out the newer release's tag in the clone and run its `install.ps1`
the same way.

### The contract

**Text and binary.** A file that holds no 0x00 byte is text; any other file is binary.

**The fold.** To fold a text file is to replace every CR LF pair with LF, in one pass from the first
byte; a lone CR and a lone LF stay as they are. A binary file is never folded.

**Identical.** A file in the folder is identical to the framework's when the two have the same sha256
after folding; a binary file, when the two have the same raw sha256. So a text file whose only
difference is its CRLF line endings -- as a git checkout with `core.autocrlf=true` leaves them -- is
identical, and is left as it is: no file is ever rewritten for its line endings. What the installer
writes is always the framework's own bytes, and the release's files are held to
`provenance/manifest.jsonl` byte for byte before anything is judged.

**The lock.** `framework.lock` is JSON lines, LF, UTF-8 without a byte-order mark: a header, then one
line per file in path order, 388 lines for the 387. Each file line records `sha256`, the file's sha256
as it stands after folding (raw, for a binary file); `eol`, what the file showed when it was judged --
`lf` (no CR LF pair, a file with no line end included), `crlf` (CR LF pairs and no lone LF), `mixed`
(both) or `binary`; `disposition`; `kind` -- `move`, `template` or `host-config`; and, on the eight
TEMPLATE and three HOST-CONFIG lines, `upstream_sha256`, the framework's own file judged the same way,
so a project's drift from it can be read. The header names the version, the commit, the source --
`source_kind` `release` or `clone`, and a clone's `source_tag` and `source_commit` -- the manifest's
and the ZIP's sha256, when it was installed and, after an upgrade (section 6), the version it was
upgraded from and when. This is `lock_format` 2. `-Verify` judges by the same fold, reads this format
and the one 0.1.0 and 0.1.1 wrote, and says which it read; its `eol` counts are the lock's. One line
can name a file the installer did not write: the root `.gitattributes` it left out (below) reads
`disposition` `not-written`, its `sha256` and `eol` null, and `-Verify` passes over it, saying
`1 not written`.

**A folder that is not empty.** Each file is judged before anything is written: absent, it is written
(`install`) -- but the root `.gitattributes`, below; identical, it is left (`already-identical`);
different and a TEMPLATE file -- one the project owns, such as `.claude/settings.json`, `.gitattributes`
or `model-routing.yaml` -- the project's copy is kept (`keep`). A different copy of any other framework
file is REFUSED, `not-installed-by-framework`.

**The root `.gitattributes`** -- the framework's line-ending rules, `* -text` and two family lines -- is
written by a fresh install only, and only into a folder that holds no file a git repository tracks: no
`.git` there or in any folder above it, or `git ls-files` there listing nothing. Into a repository with
files of its own (the folder, or a repository it lies in, tracking files there -- or git unable to say)
an absent one is not written, since a framework install does not change a project's line-ending policy
for the project's own files: the installer prints one line, `not-written        .gitattributes  -- not
written: the target holds files its git repository tracks, and ...`, and the counts carry
`not-written=1` after `kept=`. A project that wants the rules copies `.gitattributes` from the release
tree itself (LAM-INSTALL.md section 10 says what they do to an existing repository).

**The path guard.** Before anything is read or written, every path is checked: it must stay inside
the folder (no `..`, no absolute or drive-qualified path, and no symlink, junction or other reparse
point on the way), name nothing Windows cannot hold and nothing by another name (an 8.3 short name such
as `MISSIO~1`), lie outside `.mission/` and `.mission-runtime/` -- which are never touched -- and stay
short: a full path of 260 characters or more is refused. The project folder itself is yours to choose
and is not checked; but the placeholders OneDrive keeps for its files are reparse points, so install
from and into folders OneDrive does not sync. A file already in the folder that is larger than 64 MiB
(67108864 bytes) is refused for the reason `exceeds read bound`, because the installer reads each file
whole.

**One refusal refuses the run.** Every refused path is named with its reason; the counts are printed
as `planned: written=N already-identical=N kept=N retired=N refused=N` (with `not-written=N` after
`kept=` when the root `.gitattributes` is left out) -- what would have happened,
since nothing did; the exit code is 2; and no file and no lock is written. A run that writes prints
the same counts as `done:`, as above.

**Run again at the same version**, and the installer checks the folder against its lock as `-Verify`
does, says `already installed`, and writes nothing, not even the lock (exit 0, or 3 when a file
differs).

## 6. Upgrade a project an earlier release installed

Run the newer release's `install.ps1` against the project exactly as in section 5, `-WhatIf` first if
you like. What it does is decided by the version in the project's `framework.lock` against the
release's own, each read as `major.minor.patch` and compared part by part, as numbers; a version that
does not read that way (a pre-release tag, say) is refused.

| `framework.lock` | the run |
|---|---|
| absent | a fresh install (section 5) |
| an older version | an upgrade |
| this version | already installed: verified, nothing written |
| a newer version | REFUSED: a release never downgrades a project; nothing is judged or written |

An upgrade decides every file before it writes any, by the fold rule of section 5:

| the file in the project | the upgrade |
|---|---|
| a TEMPLATE or HOST-CONFIG file, present | kept, never rewritten, whatever it holds (`keep`; the lock says `kept`, and its `upstream_sha256` is the new release's file) |
| absent | written (`install`; the lock says `installed`) -- but the root `.gitattributes`, which an upgrade does not write (`not-written`, below) |
| any other file, identical to the new release's | left (`already-identical`) |
| any other file, identical to what the lock recorded as the framework's (`installed`, `already-identical` or `upgraded-from`; or `kept` with its `sha256` equal to its `upstream_sha256` -- a TEMPLATE or HOST-CONFIG file the project left as that release shipped it, a framework file in this release), the release carrying other bytes | rewritten with the release's bytes (`upgrade`; the lock says `upgraded-from <the old version>`) |
| any other file the lock recorded as the framework's, matching neither the lock nor the release | REFUSED `edited-since-install`: a local edit the upgrade would overwrite |
| any other file, present and different, that the lock does not list | REFUSED `not-installed-by-framework` |
| any other file, present and different, that the lock records as the project's own (`kept` with a `sha256` other than its `upstream_sha256`, or `host-instance-kept` in a format-1 lock) | REFUSED `host-instance` -- also a TEMPLATE or HOST-CONFIG file a later release changed while the project kept the earlier bytes: the lock cannot tell those from the project's own, so the refusal names it and the project decides |
| listed in the old lock, absent from the new release | retired: left in place, and dropped from the lock |

The decision is atomic: one refusal refuses the whole upgrade -- every refused path named, the
`planned:` counts printed, exit code 2 -- and nothing is written, no file and no lock. When the
upgrade succeeds the lock is rewritten whole, as `lock_format` 2, naming the version it was upgraded
from; `installed_at` stays the first install's. A project checked out with CRLF line endings upgrades
exactly as an LF one does. A lock written by 0.1.0 (raw sha256s and no `eol`) is read as it was
written, and each file is held to it exactly, whatever its line endings now; the upgrade rewrites it as
`lock_format` 2. A path whose letter case changes between releases is the same file, and upgrades.

**The 11 kept files, and the notice.** These are the manifest's 8 TEMPLATE and 3 HOST-CONFIG files, the
files an upgrade keeps (and a fresh install keeps a TEMPLATE the project already has). The installer never
edits one: a kept file is the project's, and the release offers its version, it does not merge it. For
every kept file whose bytes differ, on the lock's basis (`fold-crlf-text`), from the release's version,
`-WhatIf` and the run print one line, `install.ps1: NOTICE kept <path> -- kept: ...`, naming where the
release's version stands (the release folder you expanded, or the clone); for `.claude/settings.json` the
next lines name each hook registration the release's file carries that yours lacks -- at 1.2.0,
`SubagentStop`; at 1.3.0, `SessionEnd`, which writes the session's one `session_stop` (and `SubagentStop`
too for a project 1.1.0 installed) -- and print that registration's block, read from the release's file, each line after
`install.ps1: NOTICE   | `. A kept file the release's version equals prints no notice.

| kept file | disposition | after an upgrade that names it |
|---|---|---|
| `.claude/settings.json` | template | add each registration the notice names, as its block reads, to your file's `"hooks"`; then run LAM-INSTALL.md section 2's READY probe |
| `.worktreeinclude` | template | compare with the release's version and take the entries you want |
| `model-routing.yaml` | template | compare with the release's version and take what you want |
| `tools/lam/settings/orchestrator.json` | template | compare with the release's version and take what you want |
| `tools/mission-cli/config/expected-failures.yaml` | template | compare with the release's version and take what you want |
| `tools/mission-cli/config/mcp-tools.yaml` | template | compare with the release's version and take what you want |
| `tools/mission-cli/config/model-routing.yaml` | template | compare with the release's version and take what you want |
| `.gitattributes` | template, written on a fresh install only (below) | none required; to take the framework's rules, copy it from the release |
| `tools/tests/cli/test_close_milestone_lam_roster.py` | host-configuration | none required: the project's own; compare if you want the release's checks |
| `tools/tests/cli/test_prune_worktrees.py` | host-configuration | none required: the project's own; compare if you want the release's checks |
| `tools/lam/legacy-halt-census.txt` | host-configuration | none: the project's own census (below) |

**After the NOTICE block is added.** Once `.claude/settings.json` carries every registration the notice named, as
its block reads -- the file now byte-equal to this release's version -- run `install.ps1 -Target <project> -Verify`.
From 1.3.0 it reads the file `kept, now equal to upstream` and counts no difference for it (exit 0):

```text
install.ps1:   KEPT     .claude/settings.json  -- kept, now equal to upstream: the project's copy is this release's file (the lock's row records the bytes the run kept; -Verify writes nothing under the installed set or the lock)
```

`-Verify` writes nothing under the installed set or the lock, the lock's row included. A kept file that differs from both the bytes the upgrade kept
and this release's version reads `CHANGED <path> ... -- kept, differs from upstream`, and exit 3. Before 1.3.0
`-Verify` reported a kept file made equal to its upstream as `CHANGED`, exit 3.

**The root `.gitattributes`.** An upgrade keeps a project's own, and where the project has none it
writes none (a framework install does not change a project's line-ending policy for the project's own
files): it prints one `not-written` line naming the file and why, counts `not-written=1`, and records a
`not-written` line in the lock, which a later upgrade reads and writes none again. To take the
framework's rules, copy `.gitattributes` from the release tree. In a git repository on a
`core.autocrlf=true` host whose own files git stored LF and checked out CRLF, `* -text` stops that
conversion for the project's own files too: before you commit, narrow its first line to the framework's
paths, or check the tree out again so every file stands as stored. LAM-INSTALL.md section 10 says more.

**The legacy HALT census, from 0.2.0 or earlier.** A project whose goals answer legacy HALTs by a
`legacy_answered_allowlist` runs `tools\lam\export-legacy-census.ps1` from the new release, naming the
project's own `tools\lam\mission-goal-check.ps1`, BEFORE it runs `install.ps1`: the census that bounds
those allowlists was a literal inside that evaluator, and is now `tools\lam\legacy-halt-census.txt`, a
HOST-CONFIG file the framework ships empty, which the upgrade installs where none stands and keeps where
one does. Skip the step and those HALTs are honoured no longer. LAM-INSTALL.md section 10 gives the
command and what it refuses. A project with no legacy HALTs needs nothing.

**A smoke mission a 0.x release built.** The acceptance instruments read the smoke mission beside the project,
`lam-smoke` with its bare origin `lam-smoke-origin.git` (section 9, §10). One that 0.x built is not the smoke
mission this release's instruments read, and the installed builder refuses either folder already standing. After
the upgrade, rename both aside -- `lam-smoke` to `lam-smoke.old`, `lam-smoke-origin.git` to
`lam-smoke-origin.git.old` -- and build a current one beside the project with the installed builder,
`tools\lam\build-smoke-mission.ps1`, in a `powershell -File` process of its own:

```powershell
Rename-Item C:\work\lam-smoke lam-smoke.old
Rename-Item C:\work\lam-smoke-origin.git lam-smoke-origin.git.old
cd C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\build-smoke-mission.ps1
```

The acceptance wrapper, `tools\lam\instrument-acceptance.ps1`, then reads the new one. Remove the two `.old`
folders once nothing needs them.

**From 1.3.2.** Over a project the 1.3.2 release ZIP installed and nobody has edited since, the upgrade prints, between
the first lines and the last:

```text
install.ps1: upgrade: framework.lock says 1.3.2, and this release is 1.3.3
...
install.ps1: python set: the target's tools\ui\.venv (CPython 3.14.<n>, win-amd64)
install.ps1:   pip | 22 requirement(s) already satisfied
install.ps1: python set: 22 pinned package(s) in tools\ui\.venv, installed with --require-hashes
install.ps1: done: written=23 already-identical=353 kept=11 retired=5 refused=0
install.ps1: framework.lock written: 388 line(s) for 387 file(s), sha256 <64 hex>
install.ps1: upgraded 1.3.2 to 1.3.3 in C:\work\my-project.
```

-- 17 files upgraded and 6 installed, the 11 templates and host-configuration files kept, and 5 retired. Upgraded:
`THIRD-PARTY-NOTICES` and `ui/dist/index.html`; 4 framework documents under `docs/framework/` (the schema text
`expanded-schemas.md`, the feed's schema `mission-event.schema.json`, the verify spec `mission-verify-spec.md` and
`vanguard-collective-local-modes-v2.3.md`);
3 acceptance files under `tests/lam/` (the instruments `instrument-WP-2.ps1` and `instrument-WP-7.ps1`, and
`wp7-group-b.py`); 3 tools under `tools/lam/` (the dispatch runner `mission-dispatch.ps1`, the stop evaluator
`mission-goal-check.ps1` and the snapshot writer `mission-telemetry.ps1`); and 5 files of the service under `tools/ui/`
(`cli.py`, `derive.py`, `errors.py`, `metrics.py` and `views.py`). Installed: `tools/lam/goal-verdict-event.ps1`, which
appends the stop evaluator's `goal_verdict` line to the feed, and 5 of the dashboard's built files under
`ui/dist/assets/`, under the new names of the 5 retired ones, which are left in place and dropped from the lock. In a
project left as 1.3.2 installed it no kept file differs from this release's version, so no NOTICE is printed. The kept set is `.claude/settings.json` and any other file the installer reports kept: a template or
host-config file the project edited differs, and gets its own NOTICE line. The Python set is the one 1.3.2 put in
`tools\ui\.venv` (`tools\ui\requirements.txt` is unchanged), so pip finds every pinned package already there.
`release.ps1` derives its own line for the release notes from this release's installer-owned set and that of the latest
earlier release tag its history holds, `v1.3.2`, and refuses a build whose notes do not carry it --
`install.ps1: done: written=35 already-identical=341 kept=11 retired=0 refused=0` (upgraded 15, installed 20): it
reads 1.3.2's set from the tag's tree, whose manifest names none of the files a release generates, so its line counts
`ui/dist/` and `THIRD-PARTY-NOTICES` installed and none retired. `-Verify` then says `387 file(s) listed, 0 difference(s)`, and `-WhatIf` first prints the
same counts as `planned:`, followed by what it would do outside the files: the Python set (`planned python set:`), the
`vanguard` command, the host registration and the mission-event feed's ignore rule. A project whose mission is not yet registered for the feed -- one made before the feed existed -- is named by the upgrade, with `mission.ps1 register -Target <project>`, which adds the project's row to the host registry, makes `.mission-runtime/telemetry/` and the ignore rule `/.mission-runtime/` in its `.gitignore`. Once the project is upgraded, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 register -Target '<the project folder>'` once more from the release folder: it writes the first snapshot with this release's readings (section 7, "A fresh snapshot for the dashboard"). The first stop evaluation after the upgrade -- the Stop hook at a session's end, or the evaluator run by hand -- writes the project's first `goal_verdict` line. The release notes, "Upgrading from 1.3.2", give the
steps in order.

**From 1.3.0.** A project still on 1.3.0 upgrades the same way, from this release; the counts it prints are not the
ones above. What 1.3.1 and 1.3.2 changed on that path is in the 1.3.2 release notes, section 3 -- the dashboard's Python
set moving to `tools\ui\.venv` among it: after the files the upgrade makes `tools\ui\.venv` and installs the Python set
there; the folder 1.3.0 put the set in is the host's, and is left as it stood (section 5).

**The host registry row.** From 1.3.0 an upgrade (and any run that writes) brings the project's row in the host registry,
`C:\Users\<you>\.vanguard\projects.yaml`, to the version it installs: the row's `framework_version` is rewritten to the
release's, and nothing else in the file changes -- the row's other fields and every other checkout's row stay as they were.
`-WhatIf` names it first, `planned host registration: ...; the target's row in <registry> would be rewritten:
framework_version '<old>' -> '<new>' (its other fields kept)`, and the run says `framework_version '<old>' rewritten to
'<new>', its other fields kept`. A project with no row is registered by the upgrade only where it already carries a mission
and the feed's folder `.mission-runtime\telemetry\`; for one made before the feed, registration stays `mission init`'s and
`mission.ps1 register`'s. Where the registry cannot be written (read-only, say), every file and the lock are still
installed, the run says `REGISTRY NOT UPDATED`, naming the registry, and exits 5; make the file writable and run the same
release again. Before 1.3.0 an upgrade left the row at the version first registered, so the dashboard showed the old
version; the first 1.3.0 upgrade corrects such a row.

**An upgrade made in a work tree, then merged.** You may upgrade in a git work tree of the project (`git worktree add`,
`install.ps1 -Target <work tree>`, the result committed and merged into the registered checkout). The registered root
then holds every file and `framework.lock` of the new release already, and the installer run there next reads
`already installed` and writes nothing under the project. From 1.3.1 that run still brings the root's row to the lock's
version: `-WhatIf` prints the same planned line as above, its host-id named as that run reads it (`no host-id` where
the file is absent: that run mints none), the run says `host registration: ...; the target's row in
<registry>: framework_version '<old>' rewritten to '<new>', its other fields kept`, and a registry it cannot write exits
5 as above. In 1.3.0 that run ended before the registration and the row kept the old version; run the installer once at
the root after such a merge. What each run does to the row, in short: a run that writes (a fresh install, an upgrade)
appends the target's row where the target carries a mission and the feed's folder and has none, and rewrites its
`framework_version` to the release's where it has one that differs; a run over a target already at this version rewrites
that value the same way and appends nothing; `-WhatIf` writes nothing and names each change; no run changes any other
field or any other checkout's row. A work tree a dispatch cuts is registered at spawn as a checkout of its own, its row's
`framework_version` the version its `framework.lock` records, or its primary checkout's where it has none (1.3.0 wrote
`''` there); rows are appended and never pruned.

**The write is staged**, for an install and an upgrade alike. Every file to write, and then the lock,
is first written whole into a staging folder inside the project, `.framework-staging-<random>`, and
checked there; only then is each moved into place, and the lock last, replacing the old one without
ever deleting it first. An upgraded file's old copy is deleted first, so a hard link to it elsewhere
keeps its bytes. If staging fails (a full disk, say), nothing in the project has changed. If a move
fails, the lock's included, the project holds whole files only and the lock it had before the run;
run the same release again and it completes the run, judging each file already in place
`already-identical`. The staging folder is removed either way -- unless the old lock is in it and could
not be put back, which the installer then says, naming where it is.

## 7. `mission init`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.3.3\mission.ps1 init -Target C:\work\my-project
```

Expect:

```text
mission.ps1:   written  .mission/mission.yaml (<n> bytes)
mission.ps1:   written  .mission/spec/current.txt (4 bytes)
mission.ps1:   written  .mission/spec/v001.yaml (<n> bytes)
mission.ps1:   written  .mission/ledger/entries.jsonl (0 bytes)
mission.ps1:   written  .mission/goals/SMOKE-MISSION.yaml (<n> bytes)
mission.ps1:   folder   .mission/amendments/
...
mission.ps1:   folder   .mission/validator-results/
mission.ps1:   .gitignore created: it ignores /.claude/settings.local.json and /.claude/worktrees/ and /.mission-runtime/ (per-checkout files, never committed)
mission.ps1:   registered on this host: the checkout C:\work\my-project -- host_id <id> (host-id read from C:\Users\<you>\.vanguard\host-id), a row added to C:\Users\<you>\.vanguard\projects.yaml (the mission-event feed folder .mission-runtime/telemetry/ made)
mission.ps1: initialised an empty mission at C:\work\my-project (id <guid>). Next: mission.ps1 smoke -Target C:\work\my-project
```

and exit code 0. Every value in the new `mission.yaml` and `v001.yaml` is a placeholder for you
to fill in. `spec/current.txt` holds the token `v001` and nothing else, and names `spec/v001.yaml`:
the form the framework's spec tools read and write (`tools/mission-spec-bump.ps1`,
`tools/mission-close-milestone.ps1`, `tools/mission-spec-accept.ps1`). `init`
refuses (exit 2, nothing written) if any of its files is already there.

`init` also registers the project on this host for the dashboard: the host's id in
`%USERPROFILE%\.vanguard\host-id` (made once; `VANGUARD_HOME` names another folder), the project's row in
`projects.yaml` beside it, and the folder of its mission-event feed, `.mission-runtime\telemetry\`, which
the hooks and lifecycle commands append to and `vanguard ui` reads. For a mission made before the feed
existed, `mission.ps1 register -Target <project>` does the same, and says so in the line `init` prints for its own
registration -- which checkout it registered, and what it wrote: `host-id made at` where the host had none yet
(`read from` otherwise), `a row added to` (`already a row in ..., kept as it is` where the project has one), the
feed folder `made` (`already there` where it stood) -- then the `.gitignore` line and whether
a snapshot was written:

```text
mission.ps1: registered on this host: the checkout C:\work\my-project -- host_id <id> (host-id read from C:\Users\<you>\.vanguard\host-id), a row added to C:\Users\<you>\.vanguard\projects.yaml (the mission-event feed folder .mission-runtime/telemetry/ made)
mission.ps1:   .gitignore appended 1 rule: /.mission-runtime/ (the runtime plane, never committed)
mission.ps1:   snapshot: a mission_snapshot line appended to the mission-event feed, .mission-runtime/telemetry/events.jsonl
```

and, run again over the same project:

```text
mission.ps1: registered on this host: the checkout C:\work\my-project -- host_id <id> (host-id read from C:\Users\<you>\.vanguard\host-id), already a row in C:\Users\<you>\.vanguard\projects.yaml, kept as it is (the mission-event feed folder .mission-runtime/telemetry/ already there)
mission.ps1:   .gitignore unchanged: it already ignores /.mission-runtime/
mission.ps1:   snapshot: no mission_snapshot line appended -- the newest one in the feed already holds the mission's derived state, or the state could not be derived (the cause is then logged to .mission-runtime\evidence\<dispatch>\hook-errors.log, session-unknown from a plain terminal)
```

**A fresh snapshot for the dashboard.** `mission.ps1 register -Target <project>` is also the one command that
writes a fresh snapshot of the mission into its feed (a `mission_snapshot` line), from which the dashboard
reads assertions, milestones, the spec version, HALTs and dispatches. On a project already registered it
keeps the registry row as it is; its `.gitignore` step appends `/.mission-runtime/` to a root `.gitignore` that
has no line `/.mission-runtime/` or `.mission-runtime/` (or creates the file with that line), as `register`
always has, and prints which. It appends a snapshot to the target checkout's own feed whenever the mission's
derived state differs from the newest snapshot in that feed -- so target the checkout the screens' snapshot line
names (`seq <n> of <checkout>` where a mission has several); always, the first time after an upgrade to 1.3.2, whose
snapshot carries readings a 1.3.1 or 1.3.0 snapshot lacks. From 1.3.3 it says whether it appended one (its
`snapshot:` line above); it cannot tell a state that did not change from one that could not be derived: where the
mission's state cannot be derived (a file it reads that does not parse, say), no line is written, `register` still
exits 0, and the cause is in `.mission-runtime\evidence\<dispatch>\hook-errors.log` (`session-unknown` when no dispatch
or session names the run, as from a plain terminal); the screens then still name the
older snapshot they read. The Project and Stats screens name the snapshot they read,
how many feed lines came after it, and this command -- from 1.3.3 in the form in which this page runs the release's
scripts,
`powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 register -Target '<the project folder>'`, run from
the release folder, so it runs as pasted where the execution policy refuses a bare script; a reading an older
snapshot lacks is shown as not in this snapshot, never as an error.

`init` makes the project's root `.gitignore` ignore Claude Code's two per-checkout paths,
`/.claude/settings.local.json` and `/.claude/worktrees/` -- its local settings and its worktrees,
never committed; `.claude/settings.json` is named by neither and stays tracked -- and the runtime plane,
`/.mission-runtime/`: the mission-event feed and the evidence, LAM and HALT folders the hooks and commands write
beside it, none of them ever committed (a `.mission-runtime/` line already there counts). The acceptance
instrument (WP-1 H-26) reads the first two as ignored once `.claude/settings.json` is tracked. It prints one
line saying what it did:

- no `.gitignore`: `.gitignore created: ...` -- a one-line comment and the three rules, LF;
- one that lacks a rule: `.gitignore appended <n> rule(s): ...` -- the same comment and only the
  missing rules, added at the end in the file's own line ending (its first line break's; LF if it has
  none). No line already there is changed, removed or reordered;
- one that already holds all three: `.gitignore unchanged: ...`, and the file is left byte for byte. A
  rule counts as held when a line equals it, with or without its leading slash.

A refused `init` does not touch `.gitignore`. A `.gitignore` that is a folder, that cannot be read, or that
lacks a rule and cannot be appended to (read-only, or access denied) stops `init` (exit 1) before it writes
anything, its reason on one line ending `Nothing was written.`

## 8. `mission smoke` -- the first thing to run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.3.3\mission.ps1 smoke -Target C:\work\my-project
```

It runs the **installed** evaluator, `C:\work\my-project\tools\lam\mission-goal-check.ps1`, over the
goal `init` wrote. Expect:

```text
mission-goal-check: SMOKE-MISSION -> MET
  goal file : C:\work\my-project\.mission\goals\SMOKE-MISSION.yaml
  verdict   : C:\work\my-project\.mission\goals\SMOKE-MISSION.verdict.yaml
  [ok  ] ungated_placement_absent -- 0 AWAITING line(s) for .mission/amendments [] -- ...
  [ok  ] ungated_manifest_absent -- 0 AWAITING line(s) for .mission/dispatches [] -- ...
  [ok  ] handoff_brief_present -- no HANDOFF head -- ...
  [ok  ] halt_absent -- 0 unanswered HALT artifact(s) []
  [ok  ] file_exists -- .mission/mission.yaml exists=True (...)
  ...
mission.ps1: smoke: MET
```

-- seventeen `[ok  ]` lines in all -- and exit code 0. Anything else is not MET, and the exit code
is the evaluator's: 1 NOT_MET, 3 HALT, 4, 5 or 6 a stop the evaluator admits (a placed amendment or
dispatch manifest awaiting its gate, or a handoff).

**Accepting the first spec.** `init` writes `spec/v001.yaml` as a draft (`state: draft`) and leaves
`current_spec_version: null` in `mission.yaml`. Once the draft is filled in, and the project is a git
repository with it committed and a clean tree, accept it from the project root:

```powershell
cd C:\work\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\mission-spec-accept.ps1 -ProposalVersion v001 -Confirm
```

It makes one commit of three files: the draft's `state: draft` becomes `state: accepted`,
`current_spec_version` becomes `1`, and one ledger entry records the acceptance. The mission's `state`
and every other byte stay as they were, and no amendment is written. It refuses, writing nothing,
unless `spec/` holds `v001.yaml` alone, `current.txt` names it, its one `state:` line reads `draft`
and `current_spec_version` is `null` -- so a mission's first spec is accepted once. Later versions take
the amendment path (`tools/mission-spec-bump.ps1`); a proposal under `spec/proposals/` takes the
script's Phase 5 path.

## 9. What LAM-INSTALL.md adds

`docs/framework/LAM-INSTALL.md` (installed with the framework) is the operator's procedure for the
toolchain itself, and nothing above replaces any step of it. Read it whole before its own step 1, as
it asks. In outline, by its own sections:

- **§2, the hook registrations.** `install.ps1` placed the framework's `.claude/settings.json`,
  whose six registrations are the ones §2's tables show -- the state §2's four path edits and its
  two next-generation-only events (`SubagentStop`, `SessionEnd`) produce. §2 reaches that state on a fresh mission
  through `tools/framework/install-evidence-hooks.ps1`, the four edits and those two additions; here
  the file is already in it, so none is needed. If your project
  already had a `.claude/settings.json`, it was kept (`keep`) and §2 is yours to
  perform. Either way, confirm it from evidence with §2's READY probe, and run every
  diagnostic you do not want recorded from outside the project (§2).
- **§3, the sealed-hash re-seal.** The files under `tools/framework/` are installed byte-identical
  to the manifest, so this install moves no sealed byte; §3 says what to record when that is so.
- **§5.4, the pre-push decider.** Until it is installed at the hooks path git reports, the runner
  refuses to dispatch -- §5 says that refusal is the machinery working. §5.4 assumes the project is
  a git repository.
- **§5's remaining additions and probes, §5.5's post-install probe, and the complete operator
  install sequence** that orders all of them.
- **§6, the install-validation step** -- one real ceremony-class operation, and the first-generation
  negative suite, each with the next-generation hooks live.
- **§7, §7b and §8** -- the memory-off residual, what the validator role's permission layer does not
  give you, and rollback.
- **§7c, authentication** -- how every CLI the toolchain starts is authenticated, below.
- **§11, a seat that commits in your project** -- the line its prompt carries, and the line the merge
  block carries: every commit is appended to the project's commit ledger through
  `tools/lam/commit_ledger.py`, a commit in the primary checkout as it is made, a worktree commit in the merge
  block that brings it into main.
- **§10, the smoke mission and the acceptance run** -- a step after install, yours, before the acceptance
  instruments are run. The smoke mission they read is not installed: it is a git repository of its own,
  `lam-smoke`, with its bare origin `lam-smoke-origin.git`, built beside the project by the installed
  builder, which spawns no worker:

  ```powershell
  cd C:\work\my-project
  powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\build-smoke-mission.ps1
  ```

  It builds `C:\work\lam-smoke` and `C:\work\lam-smoke-origin.git` (`-SmokeRoot <folder>\lam-smoke`,
  or the environment variable `LAM_SMOKE_ROOT`, builds elsewhere), refuses either folder already
  standing, and ends `EXIT: 0`. Run it as shown, in a `powershell -File` process of its own: it sets git
  variables for itself and its children. The instruments read it there by default; the acceptance wrapper,
  `tools/lam/instrument-acceptance.ps1`, is installed and hands them any other root you name with
  `-SmokeRoot`. The installed pinned bases its instruments read
  are under `tests/lam/fixtures/base-700e19e5/`, `base-700e19e5-sNN/` (built by a recipe the framework
  repository keeps, which is not installed) and `tests/lam/fixtures/legacy-census-halts/`, with the
  `tests/lam/fixtures/.gitattributes` that keeps git from converting their line endings.

Run every probe as LAM-INSTALL.md writes it, with its control.

**Authenticating with an API key.** By default -- `VANGUARD_AUTH_MODE` unset -- the runner and the wake starter set
and check nothing, and each Claude Code CLI they start authenticates as Claude Code's own precedence decides: with the
subscription it is signed in with only when no credential is in the environment -- an `ANTHROPIC_API_KEY`, a bearer
token (`ANTHROPIC_AUTH_TOKEN` or `CLAUDE_CODE_OAUTH_TOKEN`) or a cloud-provider selector (`CLAUDE_CODE_USE_BEDROCK`,
`_VERTEX` or `_FOUNDRY`) left in the shell is used, and billed, in its place by every print-mode CLI the runner starts
(the first-generation worker-runner removes `ANTHROPIC_API_KEY`, and only it, from its child's environment in every
mode but `api-key`). Set `VANGUARD_AUTH_MODE=subscription` to have such a credential refused instead (the
subscription's own `CLAUDE_CODE_OAUTH_TOKEN` excepted). To bill an Anthropic API key on purpose, set the key and the mode in your own
PowerShell terminal -- the one you run the toolchain from, never inside a
Claude Code session, whose hooks record every command -- before you run it, and never type the key itself on a
command line, which PowerShell's line editor (PSReadLine) saves to its history file:

```powershell
$env:ANTHROPIC_API_KEY = [System.Net.NetworkCredential]::new('', (Read-Host -AsSecureString 'Anthropic API key')).Password
$env:VANGUARD_AUTH_MODE = 'api-key'
```

`Read-Host -AsSecureString` asks for the key without echoing it. The key then travels in the environment only:
the toolchain puts it in no file, dispatch or argument of its own, and the runner, the wake starter and the
worker-runner refuse (`AUTH-MODE-<CODE>`), before any CLI that calls a model starts, when the mode is set and the
key is not, when another credential is set beside it, or when a key-shaped value stands in an argument or in a file
the CLI would read -- one they hand it, or the `CLAUDE.md`, `CLAUDE.local.md`, `.claude\CLAUDE.md` or `.mcp.json` at
the root of the tree it runs in, as that tree will stand when the CLI starts (for the runner's worker, as the commit
the tree is cut at holds them), each in any letter case -- a case-insensitive file system gives the CLI a committed
`claude.md` as its `CLAUDE.md`. None of them prints the key, and with the mode admitted they print nothing they
would not print without it. Every program they start inherits it with the rest of the shell's environment -- a
product test suite that calls the API whenever the variable is present will call it under the verify gate. The
interactive seat the wake starter opens asks once whether to use the key; answer yes, and that CLI records the key's
last 20 characters in its own configuration. To go back to the subscription, remove both `VANGUARD_AUTH_MODE` and
`ANTHROPIC_API_KEY` from the shell -- a key, bearer token or cloud-provider selector left there is still used by print
mode -- or set the mode to `subscription` to have a stray one refused; run the acceptance instruments with the mode removed. LAM-INSTALL.md §7c
has the mechanism.

## 10. In a checkout of the framework repository: the tree law

Nothing in this section is installed. It concerns a git checkout of the Vanguard Collective repository
itself, not a project the framework was installed into.

`provenance/manifest.jsonl` is the law of the tree: every file tracked at a commit has exactly one
manifest line whose destination is its path and whose sha256 and byte count are the file's, and every
manifest line with a destination names a tracked file. Read it at a commit with

```
python -I tools\provenance\tree-law.py [<checkout>] [<commit>]
```

(by default the checkout the script sits in, and HEAD). It reads the commit's blobs through git and
writes nothing. It prints the commit; the tracked blob count, the manifest's record count and the
manifest's own sha256; the records counted by source, class and whether they carry a destination; the
installer-owned set by kind -- the set `install.ps1` derives: source `host`, class MOVE, TEMPLATE or
HOST-CONFIG, a destination; every AUTHORED line; and last `TREE-LAW: OK`, or the faults followed by
`TREE-LAW: FAIL` and exit code 1. A commit that adds or changes a tracked file re-measures that file's
manifest line in the same commit.
