# Installing Vanguard Collective 1.0.0

From the release ZIP -- or a clone of the public repository at the release tag (section 5) -- to a
project folder that holds the framework and an empty mission whose goal reads MET. Every command runs
in **your own Windows PowerShell 5.1 terminal**, not inside a Claude Code session -- the same rule `docs/framework/LAM-INSTALL.md` opens with ("Who runs this: the
operator, at their own terminal"). The examples use `C:\dl` for the download and `C:\work\my-project`
for the project; any folders will do, but keep the project path short (the longest installed path
is 103 characters below it, and `install.ps1` refuses a target that would reach 260).

## 1. Download

Put `vanguard-collective-v1.0.0.zip`, `SHA256SUMS` and `MEMBERS.sha256` in `C:\dl`.

## 2. Check the hash

```powershell
(Get-FileHash -Algorithm SHA256 C:\dl\vanguard-collective-v1.0.0.zip).Hash.ToLower()
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
slashes), in path order. Every line but `RELEASE`'s names a file of the commit the release tag names,
so the list is that commit's files and `RELEASE` (section 4). Once the archive is expanded (section 4),
check the folder against it file for file -- the first command prints nothing when every file
matches, and the second prints the same number twice, so no file is missing and none was added:

```powershell
Get-Content C:\dl\MEMBERS.sha256 | ForEach-Object { $h, $p = $_ -split '  ', 2; if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path C:\dl\vanguard-collective-v1.0.0 $p)).Hash.ToLower() -ne $h) { "DIFFERS $p" } }
```

```powershell
(Get-Content C:\dl\MEMBERS.sha256).Count; (Get-ChildItem -LiteralPath C:\dl\vanguard-collective-v1.0.0 -Recurse -File -Force).Count
```

## 3. Unblock the ZIP -- your step

```powershell
Unblock-File C:\dl\vanguard-collective-v1.0.0.zip
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
- Expanded by **`Expand-Archive`**, **no** file carries it.
- With **`Unblock-File` on the ZIP first**, no file carries it, whichever way it is expanded.
- **Installed files never carry it.** `install.ps1` writes every file fresh, so even an install from
  a marked tree (run with `-ExecutionPolicy Bypass`) leaves a project whose scripts run under
  `RemoteSigned`.

`install.ps1` cannot unblock itself -- a refused script never runs -- and stripping streams from your
download is your act, so this step is yours. If you skip it, the installer still runs under
`-ExecutionPolicy Bypass` (the form every command on this page uses) and prints a `NOTE:` naming
the marked files.

## 4. Expand

```powershell
Expand-Archive -LiteralPath C:\dl\vanguard-collective-v1.0.0.zip -DestinationPath C:\dl\vanguard-collective-v1.0.0
```

The archive holds 352 files: the 351 files of the commit the release tag names, and `RELEASE` (the
version, the commit the release was built from, and the manifest's sha256) -- the one file no commit
can hold, since it names the commit. Expanded, the folder is that commit's tree file for file, and
`RELEASE` beside it; `MEMBERS.sha256` lists them all (section 2). The 318 files the framework installs
are among them, with `install.ps1`, `mission.ps1`, `VERSION`, `LICENSE`, `README.md`, this file,
`provenance/manifest.jsonl`, the release notes `docs/RELEASE-NOTES-v<version>.md`, and every file the
framework repository keeps for itself and does not install. At any version it is the tagged commit's
files and `RELEASE`, so every file a release commit adds -- its release notes among them -- adds one
to the count.

## 5. Install

Optionally, first see what it would do (`-WhatIf` decides everything and writes nothing):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.0.0\install.ps1 -Target C:\work\my-project -WhatIf
```

Then install, naming the ZIP so the lock records its sha256:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.0.0\install.ps1 -Target C:\work\my-project -ReleaseZip C:\dl\vanguard-collective-v1.0.0.zip
```

Into an empty folder, expect one `install` line per file between the first lines and the last:

```text
install.ps1: source C:\dl\vanguard-collective-v1.0.0 (release at <commit>, version 1.0.0)
install.ps1: target C:\work\my-project
install.ps1: manifest sha256 <64 hex>; installer-owned 318 (MOVE 307, TEMPLATE 8, HOST-CONFIG 3); framework.lock absent
install.ps1: fresh install: no framework.lock in the target
install.ps1:   install            .claude/settings.json
...
install.ps1: done: written=318 already-identical=0 kept=0 retired=0 refused=0
install.ps1: framework.lock written: 319 line(s) for 318 file(s), sha256 <64 hex>
install.ps1: installed 1.0.0 into C:\work\my-project.
```

and exit code 0. Check the folder against its lock at any time:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.0.0\install.ps1 -Target C:\work\my-project -Verify
```

which ends `verify: 318 file(s) listed, 0 difference(s); eol lf=317 crlf=1 mixed=0 binary=0.` (one
framework file has CRLF line endings of its own) and exits 0, or 3 when a file differs. It never
writes.

### Install from a clone of the public repository

The release ZIP is the tagged commit's files and `RELEASE` (section 4), so a clone of the public
repository checked out at the release tag is the same source, and its `install.ps1` installs from it
with no ZIP at all. Clone it outside the project folder, and check out the tag -- git leaves HEAD
detached at it:

```powershell
git clone <the public repository's URL> C:\src\vanguard-collective
cd C:\src\vanguard-collective
git checkout v1.0.0
```

Then install as above, from the clone and without `-ReleaseZip` (there is no archive to name, and the
installer refuses one with a clone):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\src\vanguard-collective\install.ps1 -Target C:\work\my-project
```

Its first line names the tag and the commit, and the rest is the output above:

```text
install.ps1: source C:\src\vanguard-collective (clone at tag v1.0.0, commit <commit>, version 1.0.0)
```

A clone is accepted only as the release it stands for. A source folder holding `.git` is a clone, never an
expanded release: before the installer reads its manifest or any file, git (reading `VERSION` from HEAD) must
confirm it, or the installer REFUSES, exit 1, on one line beginning `install.ps1: REFUSED:`, a clone that is
- **off the tag** -- HEAD is not the commit the tag `v<version>` names, or no tag has that exact name (`V1.0.0`
  is not `v1.0.0`): `install.ps1: REFUSED: the source checkout is not at tag v1.0.0 (HEAD <commit>; tag v1.0.0
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
(`v1.0.0`) and `source_commit` the commit (40 hex), which is `framework_repo_tip` too unless HEAD tracks a
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
line per file in path order, 319 lines for the 318. Each file line records `sha256`, the file's sha256
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

**From 0.3.0.** Over a project 0.3.0 installed into an empty git repository and nobody has edited since, the
upgrade prints, between the first lines and the last:

```text
install.ps1: upgrade: framework.lock says 0.3.0, and this release is 1.0.0
...
install.ps1: done: written=243 already-identical=64 kept=11 retired=32 refused=0
install.ps1: framework.lock written: 319 line(s) for 318 file(s), sha256 <64 hex>
install.ps1: upgraded 0.3.0 to 1.0.0 in C:\work\my-project.
```

-- 171 files upgraded and 72 installed (the pinned bases under `tests/lam/fixtures/base-700e19e5/`
and `base-700e19e5-sNN/`, and the smoke-mission builder `tools/lam/build-smoke-mission.ps1` with its sources under
`tools/lam/smoke-mission/`), the 11 templates and host-configuration files kept, and 32 files
retired, each named on a `retire` line: the pinned base copies 0.3.0 installed, which the bases above replace -- left
in place and dropped from the lock; the project may delete them. `-Verify` then says `318 file(s) listed,
0 difference(s)`, and `-WhatIf` first prints the same counts as `planned:`. A project whose 0.3.0 lock carries a
`not-written` row for the root `.gitattributes` (0.3.0 installed into a repository that already tracked files) reads
`kept=10 not-written=1` instead, with one `not-written` line, and `-Verify` adds `1 not written`. The release notes,
"Upgrading from 0.3.0", give the steps in order.

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
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.0.0\mission.ps1 init -Target C:\work\my-project
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
mission.ps1:   .gitignore created: it ignores /.claude/settings.local.json and /.claude/worktrees/ (Claude Code's per-checkout files, never committed)
mission.ps1: initialised an empty mission at C:\work\my-project (id <guid>). Next: mission.ps1 smoke -Target C:\work\my-project
```

and exit code 0. Every value in the new `mission.yaml` and `v001.yaml` is a placeholder for you
to fill in. `spec/current.txt` holds the token `v001` and nothing else, and names `spec/v001.yaml`:
the form the framework's spec tools read and write (`tools/mission-spec-bump.ps1`,
`tools/mission-close-milestone.ps1`, `tools/mission-spec-accept.ps1`). `init`
refuses (exit 2, nothing written) if any of its files is already there.

`init` also makes the project's root `.gitignore` ignore Claude Code's two per-checkout paths,
`/.claude/settings.local.json` and `/.claude/worktrees/` -- its local settings and its worktrees,
never committed; `.claude/settings.json` is named by neither and stays tracked. The acceptance
instrument (WP-1 H-26) reads both as ignored once `.claude/settings.json` is tracked. It prints one
line saying what it did:

- no `.gitignore`: `.gitignore created: ...` -- a one-line comment and the two rules, LF;
- one that lacks a rule: `.gitignore appended <n> rule(s): ...` -- the same comment and only the
  missing rules, added at the end in the file's own line ending (its first line break's; LF if it has
  none). No line already there is changed, removed or reordered;
- one that already holds both: `.gitignore unchanged: ...`, and the file is left byte for byte. A
  rule counts as held when a line equals it, with or without its leading slash.

A refused `init` does not touch `.gitignore`. A `.gitignore` that is a folder, that cannot be read, or that
lacks a rule and cannot be appended to (read-only, or access denied) stops `init` (exit 1) before it writes
anything, its reason on one line ending `Nothing was written.`

## 8. `mission smoke` -- the first thing to run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dl\vanguard-collective-v1.0.0\mission.ps1 smoke -Target C:\work\my-project
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
  whose four registrations are the ones §2's table shows -- the state §2's four path edits produce.
  §2 reaches that state on a fresh mission through `tools/framework/install-evidence-hooks.ps1`
  and then the four edits; here the file is already in it, so neither is needed. If your project
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
