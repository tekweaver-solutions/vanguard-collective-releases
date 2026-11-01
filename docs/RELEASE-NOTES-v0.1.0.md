# Vanguard Collective 0.1.0 -- release notes

## What 0.1.0 is

Version 0.1.0 is the framework extracted byte for byte from the host repository's BASE commit
into a repository of its own. Every framework file is the host's blob, unchanged. What
this repository adds is its own: the installer, two commands, the documentation and the
provenance. Every tracked file has one line in `provenance/manifest.jsonl` naming its class, its
sha256 and size, and why it is here, so the manifest is the law of the tree.

It is internal and private. It is not licensed for distribution (`LICENSE` is a placeholder), the
confidentiality pass has not been run, and it targets one platform: Windows with Windows
PowerShell 5.1, plus git and Python 3, and Claude Code Desktop to run a mission.

## What it contains

- **`install.ps1`** installs the 239 installer-owned files the manifest defines (MOVE 227,
  TEMPLATE 7, HOST-CONFIG 5) into a project folder, byte for byte, and writes `framework.lock`.
  If a framework file in the target has been changed, it refuses and writes nothing. It keeps a
  project's own copy of a template file, never touches `.mission/` or `.mission-runtime/`, and
  `-Verify` re-checks an installed folder against its lock.
- **`mission.ps1 init`** writes an empty mission: `.mission/` with its record, a draft spec
  `spec/v001.yaml` named by `spec/current.txt`, an empty ledger and the goal SMOKE-MISSION.
  **`mission.ps1 smoke`** runs the installed goal evaluator over it and exits 0 on MET.
- **The framework itself**: the LAM toolchain (`tools/lam/`), the evidence hooks
  (`tools/evidence-hooks-next/`, delegating to the first-generation hooks in `tools/framework/`),
  the mission lifecycle commands (`tools/mission-*.ps1`), the design documents and schemas
  (`docs/framework/`), and the acceptance instruments `tests/lam/instrument-WP-1.ps1` to
  `instrument-WP-6.ps1`.
- **In this repository only, not installed**: the smoke fixture under `tests/lam/fixtures/`,
  `provenance/`, and `release.ps1`, which builds the release ZIP from HEAD.

The release ZIP holds 247 files: the 239, `install.ps1`, `mission.ps1`, `VERSION`, `LICENSE`,
`README.md`, `INSTALL.md`, `provenance/manifest.jsonl`, and a generated `RELEASE` that names the
version, the commit and the manifest's sha256. It is built deterministically, with entries sorted
and every timestamp fixed, so two builds at one commit are the same bytes. `SHA256SUMS` carries its
sha256. INSTALL.md goes step by step from the downloaded ZIP to a smoke that reads MET.

## The standalone reading

The six instruments were run in this repository with the host absent. **287 checks = 233 passed +
54 named skips; 0 unexplained.** A named skip is a check that fails, or skips itself, only because a
named part of the host is not here; each was read in its capture and its dependence named. The
classes follow. A check may carry two, so the counts overlap; there are 54 distinct checks.

- **Pinned host-history objects (42).** These checks read older commits or blobs of the host's
  history by id, and this repository, which starts at one import commit, does not carry them.
- **Host mission, runtime and local-configuration files (12).** These checks read the host's
  sealed mission record, its untracked runtime plane, or its local Claude Code settings beside a
  sibling checkout. None of these is framework, and none ships.
- **The product's source tree and virtual environment (5).** These checks need the host product's
  tracked source corpus (at least 400 source files; this tree has 138 to 151 by each check's own
  count), or its Python virtual environment, which only the product's own instrument builds.
- **The host's product instrument (2).** These checks run the host's own acceptance instrument for
  its product, which stays in the host repository.
- **The container engine's state (1).** One check measures the container engine while it is stopped,
  as it was at the host. Here the engine is running.

By instrument, passed + named skips: WP-1 41 + 0; WP-2 72 + 5; WP-3 39 + 38; WP-4 60 + 10;
WP-5 10 + 0; WP-6 11 + 1.

## Three host crossings in WP-6, as recorded

WP-6 drives the smoke fixture through its sibling checkouts, a working copy and its origin. They
were copied from the host, and three things in them still reached it:

1. **Worktree pointers.** The copies' git worktree pointers named the host's paths. The
   materialisation step repaired them, re-pointing each worktree at the copy.
2. **The pre-push decider.** The copied pre-push wrapper named the host's decider. The same step
   re-pointed it at this repository's `tools/evidence-hooks-next/hooks/evidence-pre-push.ps1`.
3. **S-1b's committed hooks.** S-1b runs one real, billed worker in a clone of the fixture, and that
   clone carries the fixture's committed `.claude/settings.local.json`. Its six hook commands name
   the host's hook scripts by absolute path. This crossing is accepted for 0.1.0: S-1b passed
   against the host's hook scripts.

## What the next release adds

- An API-key authentication mode.
- Parameterised host literals: the host paths and names that the instruments and the fixture
  still carry become parameters.
- The installer-owned-path guard.
- Upgrade semantics. 0.1.0 installs once, and `install.ps1` refuses a file installed from another
  version.
- The fixture materialisation recipe: the step above, written down and repeatable.
- The rebased members: checks that pin host-history objects, rebased onto objects this repository
  carries.
- The licence terms and the confidentiality pass.
