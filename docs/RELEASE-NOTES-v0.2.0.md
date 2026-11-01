# Vanguard Collective 0.2.0 -- release notes

0.2.0 supersedes 0.1.1. The installer upgrades a project in place. Outside the smoke fixture, the framework names
the host it was extracted from in one line only, kept by design (group B). And the acceptance instruments read
what they pin -- earlier versions of the tools they hold to their pins -- from fixtures installed with the
framework, before any history. It is still internal (see "Known limits").

The release ZIP holds 284 files: the 275 the framework installs and nine more (INSTALL.md section 4), these notes
among them. Installed into an empty folder, `install.ps1` writes the 275 and a `framework.lock` of 276 lines.

## A. The installer

- **Upgrade, decided whole before anything is written.** Over a `framework.lock` of an older version,
  `install.ps1` upgrades: a file still as the earlier release installed it is replaced by this release's, a file
  identical to this release's is left, a file new in this release is written, and a file this release no longer
  carries is left in place and dropped from the lock (`retired`). One refusal refuses the whole run -- every refused
  path named with its reason, exit code 2, no file and no lock written. A file somebody edited after the install is
  refused `edited-since-install`, a framework path the lock does not list `not-installed-by-framework`, one the lock
  records as the project's own `host-instance`. The table is INSTALL.md section 6.
- **The write is staged.** Every file, then the lock, is written whole into a staging folder inside the target and
  re-hashed there, then moved into place, the lock last and never deleted first. A failure while staging changes
  nothing; a failure while moving leaves whole files and the lock the target had, and the same run again completes it.
- **Lock format 2.** The header gains `previous_version` and `upgraded_at` (`installed_at` is carried over by an
  upgrade); each row gains `kind` (`move`, `template`, `host-config`) and, on a template or host-config row,
  `upstream_sha256`, the release's own file judged by the fold rule, so a project's drift from it can be read. The
  dispositions are `installed`, `already-identical`, `upgraded-from <version>` and `kept`. `-Verify` reads formats 1
  and 2 and says which it read.
- **A downgrade is refused**: a lock newer than the release is judged no further and nothing is written. Versions are
  compared as `major.minor.patch`, part by part, as numbers; a pre-release tag in the lock or in `VERSION` is refused.
- **Templates and host configuration are kept.** An upgrade never rewrites a TEMPLATE or HOST-CONFIG file that is
  present, whatever it holds; an absent one is written. A row an upgrade recorded as `kept` with its `sha256` equal to
  its `upstream_sha256` -- a file left as that release shipped it -- is upgraded when a later release makes the path
  MOVE, and refused `edited-since-install` if it was edited since.
- **The path guard.** Before any file is read or written, every path is judged: no empty, absolute or drive-qualified
  path, no `..` or `.` segment, no backslash, no character or trailing dot or space Windows cannot hold, no device name,
  nothing in `.mission/` or `.mission-runtime/` and nothing at or under `framework.lock`; resolved under the target,
  nothing outside it, no full path of 260 characters or more (no folder of 248 or more), no 8.3 short name standing for
  another name, no reparse point of any kind on the way -- a symbolic link, a junction or a cloud-file placeholder --
  and no file where a folder goes. `-Verify` judges every path the lock lists by the same guard.
- **A 64 MiB read bound.** A file already in the target that is larger than 67108864 bytes is refused,
  `exceeds read bound`, because every target file is read whole; `framework.lock` too.
- **`planned:` and `done:`.** A refused run, and every `-WhatIf` run, prints its counts as
  `planned: written=N already-identical=N kept=N retired=N refused=N`; a run that wrote prints them as `done:`; no other
  line carries `written=`.
- **The release notes are a member of the ZIP.** `release.ps1` adds `docs/RELEASE-NOTES-v<VERSION>.md` as HEAD
  tracks it, and builds nothing without it.
- **A 0.1.0 lock is read exactly.** A file is held to a row 0.1.0 wrote by its raw bytes, by its folded form when the
  fold leaves no CR LF pair, or by its CRLF form -- the bytes 0.1.0 wrote for a CRLF source. So the limit the 0.1.1
  notes state for a 0.1.0 lock ("exact for every file 0.1.0 wrote without CRLF") is closed: the one file 0.1.0 wrote
  with CRLF is held exactly too, and an upgrade rewrites the lock as format 2.

## B. The host made a parameter

- **Host literals are out of the framework's files.** Paths, names and the user's home path that named the original host
  are parameters with generic defaults, or neutral forms in the documents and records. Outside the smoke fixture under
  `tests/lam/fixtures/lam-smoke/`, one line still matches the census pattern, by design: the evidence-manifest
  schema's `$id`, which the smoke fixture carries too and WP-6 holds the two equal.
- **The manifest's vocabulary.** The source token of the files taken from the host is `host`, and the header keys are
  `host_base` and `host_root`. Every reader in this repository reads it so (`install.ps1`, `release.ps1`, the tree law,
  tests/install); a reader outside it that filters `provenance/manifest.jsonl` on the old token must change. A published
  release reads only its own manifest, so 0.1.0 and 0.1.1 are unaffected.
- **`.worktreeinclude` no longer lists `.mission/contract/`.** It is a TEMPLATE: a project keeps its own copy, so the
  change reaches fresh installs only.
- **WP-6 reads the tracked fixture by default**, `tests/lam/fixtures/lam-smoke`, and skips by name what a root of files
  cannot answer (no `.git`, no origin, no runtime plane). A live smoke repository is measured only when handed in, and
  then WP-6's S-1b spawns one real, billed worker.
- **The smoke root.** WP-3 and WP-6 take it from `-SmokeRoot`, else from `LAM_SMOKE_ROOT`, else from the tracked fixture
  in the checkout they run in, and only where that is absent from a sibling `lam-smoke`, a fallback that names itself;
  each prints the root it read and where the value came from.
- **`LAM_WORKTREE_HOME_NAME`**, optional: one folder name the peer-worktree deny rule adds to the homes it derives
  (LAM-INSTALL.md section 5.2). It can only add denials.
- **The acceptance wrapper is installed**: `tools/lam/instrument-acceptance.ps1 -RunKey <key> [-Root <checkout>]
  [-SmokeRoot <root>]` runs WP-1..6 and keeps their captures (LAM-INSTALL.md section 10). In the framework repository,
  `tools/lam/materialise-smoke.ps1` copies the tracked smoke fixture to a root of files, held to the manifest; the
  materialiser and the fixture it copies are not installed.
- **A reading in a worktree equals the root's**, or names the dependence as a skip whose reason says where it stood:
  the instruments derive the primary checkout and the ref they stand on, and resolve the smoke root as above.

## C. Missions, HALTs, and what the instruments read

- **spec-accept accepts the first spec from draft.** `tools/mission-spec-accept.ps1 -ProposalVersion v001 -Confirm`, at
  the root of the project's git repository with a clean tree, accepts the draft `mission.ps1 init` wrote: one commit of
  three files (`state: accepted`, `current_spec_version: 1`, one ledger entry), and nothing written unless `spec/` holds
  `v001.yaml` alone in state `draft` and `current_spec_version` is `null` (INSTALL.md section 8).
- **A tooling seat's HALT is answered by a RESOLVED record** in its own plane,
  `.mission-runtime\seats\<seat>\HALT-<id>.md`: its `**Status:**` reads RESOLVED and one `## RESOLVED` block names the
  HALT, the ruling, who ruled, when and where to resume (LAM-INSTALL.md section 5.6.2). It mints no gate and authorises
  nothing; a mission HALT anywhere else still needs its halt-ruling gate. The verdict artifact gains
  `halts_resolved_by_seat_record:` where one is honoured, so every other artifact is as it was.
- **WP-2 and WP-4 print WP-6's skip forms**: a member that cannot be measured where it runs reads `[SKIP]` with its
  reason, is never counted as a pass, and the summary line names the skips.
- **The pinned-history members read files this release carries.** A member that holds a tool to the tool as it stood at
  an earlier host commit reads that version from `tests/lam/fixtures/base-<sha8>/<path>.base` first, then from the
  host's own history, then from the import commit, held to its pin in every case; a fixture that does not hold fails.
  These fixtures, and the two frozen-census HALTs under `tests/lam/fixtures/legacy-census-halts/`, are now installed
  with the framework, so a project's instruments read the same bytes as this repository's -- with
  `tests/lam/fixtures/.gitattributes` (`* -text`), which keeps git from converting their line endings in a checkout or
  a clone, whatever `core.autocrlf` says. Commit it with them.
- **Two members assert what they only showed.** WP-3 C-3e's census row skips only where no member of the frozen legacy
  census is on the runtime plane by name, and fails where every such member has drifted from its census bytes; WP-4
  T-26 fails when a base it reads does not hold its pin.
- **The prune-worktrees A-B test reads its base from a fixture.** `tools/tests/cli/test_prune_worktrees.py` takes the
  tool as it stood at the host commit it pins from its committed base fixture under `tests/lam/fixtures/` first, as
  the members do, and from git only where no fixture stands; the Python tests read 0 failed (496 passed, 14 skipped
  by name) in this repository.
- **In the framework repository only**: `tools/provenance/tree-law.py` reads the manifest as the law of a commit
  (INSTALL.md section 10), and `tools/provenance/upgrade-diff.py` predicts an upgrade's plan from two releases'
  manifests. Neither is installed.
- **The standalone reading at the release tip**: the six instruments read 274 passed, 0 failed and 13 named skips of
  287 checks, at the last commit before the version -- each skip naming what it depends
  on: four of the original host's runtime records (WP-3 C-3e, WP-4 T-42, T-53 and T-54), its local Claude Code
  settings (WP-3 C-2c), the container engine's state (WP-3 C-1bd), and seven WP-6 members a root of files cannot
  answer.

## D. Upgrading from 0.1.1

- **`install.ps1` over a 0.1.1 lock upgrades in place.** Over a project 0.1.1 installed and nobody edited since,
  `-WhatIf` plans `planned: written=87 already-identical=179 kept=9 retired=0 refused=0` -- 51 files upgraded, 36
  installed, 9 kept, 179 left as they are -- and the upgrade prints the same counts as `done:` and rewrites the lock as
  format 2 (276 lines), keeping `installed_at` (INSTALL.md section 6). Run it with `-WhatIf` first to see that line for
  your project; a file edited since the install refuses the whole upgrade and names itself.
- **Re-issue a completion-acceptance gate bound to `docs/framework/LAM-RESIDUALS.md`.** The file changed (one mention of
  the host). A project whose gate binds its sha256 finds after the upgrade that the gate no longer admits what it
  admitted; the operator re-issues it.
- **Kept files stay as they were.** `.worktreeinclude`, `.claude/settings.json` and the other templates, and the two
  HOST-CONFIG tests `tools/tests/cli/test_close_milestone_lam_roster.py` and `tools/tests/cli/test_prune_worktrees.py`,
  are kept; their `upstream_sha256` shows where they differ from this release's. Three files that were HOST-CONFIG in
  0.1.1 are framework files now and are upgraded: `tests/lam/instrument-WP-1.ps1`,
  `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1` and `tools/lam/mission-goal-check.ps1`.
- **New files arrive**: the acceptance wrapper, the pinned base fixtures under `tests/lam/fixtures/` and the
  `.gitattributes` beside them, written where nothing stands.
- **A kept file is the project's to update by hand.** The new `tools/tests/cli/test_prune_worktrees.py` reads its base
  from the installed fixture; the one 0.1.1 installed reads a host commit from git and fails without it. Take the new
  one from the release if the project wants it.
- **A project checked out with CRLF line endings upgrades exactly as an LF one does**: files are compared after the
  fold, so an unchanged file reads already-identical and is not rewritten.
- **Outside readers of the manifest** that filter on the old source token must change (group B).

## Known limits

- Internal and private. `LICENSE` is a placeholder; the licence terms and the confidentiality pass are not done, and nor
  is the API-key authentication mode the 0.1.0 notes listed as planned.
- One platform: Windows with Windows PowerShell 5.1, plus git and Python 3, and Claude Code Desktop to run a mission.
- The smoke fixture's committed hook settings, `tests/lam/fixtures/lam-smoke/.claude/settings.local.json`, register six
  hooks by absolute path into the original host's checkout: a live smoke repository built from it calls those paths, and
  WP-6's S-1b worker runs them.
- The product-instrument fixtures (the original host's product instrument at four of its versions) and the goal
  fixture (the host's goal of record at the extraction base) are the original host's files; synthetic ones are to
  replace them.
- WP-2 R-36a needs a `\U` segment in its checkout's path: it passes in a checkout under the user profile and fails in
  one at, say, `C:\work\...`.
- Targets OneDrive syncs are refused: its placeholders are reparse points, which the path guard refuses. Install from
  and into folders OneDrive does not sync.
