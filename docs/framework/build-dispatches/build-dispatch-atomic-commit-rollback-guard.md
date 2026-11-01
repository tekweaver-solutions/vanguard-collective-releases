# D3 -- BUILD DISPATCH: the `Invoke-AtomicCommit` destructive-rollback guard

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>" denote
> `docs/framework/vanguard-collective-local-modes-v2.2.md`. Bare `ADR-0NN` and bare `A-NNN`
> denote on-disk mission law under `tools/mission-cli/config/`. `SS` is this file's ASCII
> spelling of the section mark.
>
> **This is a prompt, not a build.** A4 authored it and built nothing.

---

## P0 GROUNDING

Read-only, first reply.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. `tools/mission-lib.ps1`, the `Invoke-AtomicCommit` function IN FULL, including its
   `catch` block. **Re-derive the defect rather than trusting this dispatch:** confirm the
   failure path runs `git reset --hard <preSha>` and then `git clean -fd -- .mission`.
3. `git status --porcelain=v1` -- confirm the four RESIDUE-KEEP untracked paths are present:
   `.mission/inputs/samples/sample-OVERSIZED.md`, `sample-RENAMED.md`,
   `sample-capabilities.md`, and `suite-run-operator.txt`. **These four files
   are what the defect destroys.** They are operator files.
4. **The mission's rollback assertions** -- the rollback law the helper's docstring cites and
   implements. It requires restoring to the pre-operation SHA "leaving NO partial state".
   Read the actual text; the cure must satisfy it, not merely avoid the symptom.
5. Every call site of `Invoke-AtomicCommit` across `tools/**`. Enumerate them; the blast
   radius of a behaviour change is the call-site set, not the function.

**HALT AND REPORT if:** the `git clean -fd -- .mission` line is no longer there (someone
cured this already), or the RESIDUE-KEEP files are absent (the fixture for your negative
case is gone, and you must ask before creating stand-ins under `.mission/`).

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Your own ceremony commit uses `git add <explicit paths>` + `git commit -F` -- **not** the
  function you are curing. Earlier ceremonies have routed around this defect rather
  than trip it, and yours is one more until the cure is proven.
- Strict UTF-8, no BOM, LF-only; `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-9 bind.
- LEDGER-GOVERNS.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **The defect, as this dispatch states it** -- on failure `Invoke-AtomicCommit` runs
  `git reset --hard <preSha>` and then `git clean -fd -- .mission`, which deletes the operator's
  untracked files under `.mission/` (P0 GROUNDING items 2 and 3). Its cure was deferred when it
  was found, and ceremonies since have routed around it rather than trip it.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`),
  "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 12 (D3), and records that its `git clean -fd --
  .mission` now has two victim classes: the RESIDUE-KEEP files and the evidence plane.
- **the design brief (`docs/framework/multi-agent-framework-design-brief.md`), "### 5.5 Amendment"** -- the protocol
  through which the amendment this dispatch needs is proposed and approved.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: tools/mission-lib.ps1, tools/tests/**
MOVES A SEALED HASH: NO

`tools/mission-lib.ps1` is mission-CLI tooling, outside the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`), which is why
this dispatch NEEDS ITS OWN AMENDMENT. The cure touches only what WRITE SURFACE below names -- the
rollback path, its regression test, the ledger append and the amendment. The amendment that admits
the cure should say whether it is framework-scope or mission-scope and why.

## WRITE SURFACE

- `tools/mission-lib.ps1` -- the `Invoke-AtomicCommit` rollback path only
- `tools/tests/**` or the framework test tree -- a regression test for the cure
- `.mission/ledger/entries.jsonl` -- append only
- `.mission/amendments/<the authorizing amendment>.yaml` -- placement only

## FORBIDDEN

- **Deleting the clean step outright.** The rollback law requires no partial state to survive a
  rollback; a rollback that leaves a half-written `vNNN.yaml` or an uncommitted amendment
  behind has traded a destructive bug for a correctness bug, and the next reader inherits a
  tree that lies about what completed.
- **Gitignoring, staging, moving, or deleting the four RESIDUE-KEEP files** to make the
  problem disappear. They are the operator's, they stay untracked, and the defect is that the
  code touches them at all.
- Changing `Invoke-AtomicCommit`'s success path, its signature, or its return value. Every
  call site depends on both.
- Widening the clean beyond `.mission` "while you are in there".
- Curing this by simply telling callers not to use the helper. That is the workaround earlier
  ceremonies already used, and shipping it as the cure would make the workaround permanent.

## ACCEPTANCE

1. **A mid-commit failure no longer deletes pre-existing untracked files under `.mission/`,
   PROVEN BY A DRIVEN CASE** in a scratch repository -- never against the real one. Plant
   untracked files, force a commit failure, and show the files surviving. Show the same
   fixture against the **pre-cure** function with the files destroyed. The pair is the
   acceptance evidence.
2. **The rollback law still holds, PROVEN BY ITS OWN DRIVEN CASE.** In the same scratch repository,
   create a half-written artifact *during* the operation, force the failure, and show the
   artifact removed and HEAD restored to the pre-operation SHA. The cure discriminates
   between "untracked before the operation" and "untracked because the operation half-ran";
   state the mechanism you used to tell them apart, and its residual.
3. **The discrimination mechanism is stated per-member with its reach** (law 4). Whatever you
   use -- a pre-operation untracked snapshot, path-scoped cleaning, an explicit created-paths
   list -- name what it does **not** cover. A file created by a concurrent process during the
   window is the obvious member; there will be others.
4. **The success path is byte-for-byte unchanged in behaviour**, demonstrated by a driven
   successful commit through the helper.
5. **`git reset --hard` still runs** and HEAD still returns to the pre-operation SHA.
6. **A regression test ships on disk**, anchored to `$PSScriptRoot`, pure ASCII, operating
   only on a scratch repository, leaving zero residue in the real one.
7. **Every call site enumerated at grounding still works**, each exercised or each explicitly
   listed as unexercised with the reason.
8. **Regression:** A1 14/14 exit 0; A2 acceptance exit 3; A3 acceptance exit 0; the four
   RESIDUE-KEEP paths present and untracked in the real repository at the end of your work,
   shown by verbatim porcelain.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after -- and the
  **after** must still show the four RESIDUE-KEEP paths. This is the one dispatch where
  porcelain is the primary evidence rather than a formality.
- sha256 prefix and byte length of every file created or modified.
- The **paired driven outputs** from ACCEPTANCE items 1 and 2 -- pre-cure destroying,
  post-cure preserving; and half-written state still removed.
- The call-site enumeration with each site's disposition.
- Full regression suite outputs with exit codes.
- An explicit statement of what you did **not** verify -- including, honestly, whether you
  drove a concurrent-writer case or only reasoned about it.
