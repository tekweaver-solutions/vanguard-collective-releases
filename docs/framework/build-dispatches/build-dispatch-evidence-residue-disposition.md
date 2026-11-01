# D9 -- BUILD DISPATCH: evidence-residue disposition and the clean-tree blocker

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>"
> denote `docs/framework/vanguard-collective-local-modes-v2.3.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** Its author built nothing.
>
> **THE TWO GOVERNANCE QUESTIONS ARE ALREADY RULED.** The authorizing amendment carries both operator
> rulings -- Q1 (evidence is NOT committed, gated on a five-condition precondition) and Q2
> (gitignore scoped to `session-*`, exemption rejected on design SS4.5 law 2). **This dispatch
> BUILDS the ruling. It does not re-open it, re-argue it, or improve on it.** A builder who
> arrives at a different answer surfaces the contradiction under law 9 and HALTS; it does not
> quietly implement the better idea.

---

## P0 GROUNDING

Read-only, first reply. Report each with the command and its raw output.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. **The residue population, per member.** Every `.mission/evidence/session-*/` directory
   currently on disk, with its manifest `state` and `entry_count`. Expect at least three by the
   time this runs (one `session-<id>*` per session). The
   number is NOT fixed and MUST NOT be transcribed into anything you build -- that it grows is
   the defect.
3. **The tracked population, and this is the constraint that kills the obvious cure.**
   `.mission/evidence/` is a long-standing TRACKED directory. Derive the count of tracked files
   under it and the dispatch directories that hold them; expect a large population across many
   (`<dispatch>-live`, `<dispatch>-witness`, ...). Read the tracked-directory constraint NEW-3.
4. **The root `.gitignore`** -- read it in full. Derive whether any pattern already reaches
   `.mission/evidence/`.
5. **Both gates, from source, by line.** `tools/mission-spec-accept.ps1` `Assert-CleanGitTree`
   (expect the two untracked exemptions `^\?\? \.claude/` and `^\?\? \.mission-runtime/` at
   lines 193-194) and `tools/mission-lib.ps1` `Assert-CleanWorkingTree` (expect: exempts nothing
   without `-AllowPaths`).
6. **The operator rulings** -- both rulings, in full, including the MIXED DIRECTORY statement and the
   five-condition precondition.
7. **The originating ledger entries** -- the operator ruling that opened the
   residue class, the clean-tree derivation, and the standing "hooks come off first" constraint.

**HALT AND REPORT if:** any `.mission/evidence/session-*/` path is TRACKED (the Q1 ruling has
already been violated and this dispatch's premise has moved); or the root `.gitignore` already
carries a `.mission/evidence` pattern (someone cured this, or shadowed the tracked plane); or
either gate's source no longer matches item 5; or the operator rulings do not read as summarised
above.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; **never**
  `Invoke-AtomicCommit` (a registered defect: its `git clean -fd -- .mission` would delete
  both the RESIDUE-KEEP files and the evidence residue). Ledger appends use `-NoCommit`.
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-10 bind. Law 2 is load-bearing here and law 10 governs the acceptance.
- LEDGER-GOVERNS. AM files are immutable once placed.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **The authorizing amendment's two operator rulings** -- Q1 (evidence is NOT committed, gated
  on a five-condition precondition this dispatch must not weaken) and Q2 (gitignore scoped to
  `session-*`, exemption rejected on design SS4.5 law 2), as summarised at the top of this file.
- **The residue population and the tracked population** -- P0 GROUNDING items 2 and 3 re-derive
  them from disk, and this dispatch transcribes neither. F-4, F-5, NEW-1 and NEW-2 label the dispatch
  set's four incompleteness mechanisms and NEW-3 the tracked-directory constraint; no document of this
  distribution states them, so the builder works from the two populations, not from the labels.
- **design, "### 4.6 Erratum E5 -- four SS4.1 assumptions falsified by the live harness"**
  and **design, "### 4.7 Registered dispatches arising from E5"**
  -- E5's two design findings and D9's registration.
- **design, "### 17.3 The standing operational constraint"** -- the standing operational
  constraint this dispatch is the cure for.
- **design, "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- D9 is the first dispatch of Arc 1, the evidence-plane cure.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: .gitignore, tools/mission-spec-accept.ps1, tools/mission-lib.ps1
MOVES A SEALED HASH: NO

**Why an amendment is required, derived rather than assumed.** The cure writes the root
`.gitignore`, which is outside the dispatch set's standing write surface (`docs/framework/**`,
`tools/framework/**`, `tools/mission-cli/config/**`, and append-only `.mission/ledger/` +
`.mission/amendments/`). Design "## 13. Supersession & Documentation Map", erratum E4, already
registers root `.gitattributes` as needing its own amendment for the same reason; `.gitignore`
is the same class. The two `tools/` paths are covered conditionally -- see WRITE SURFACE, where
they land only if ACCEPTANCE item 4 proves them necessary.

**Why no sealed hash moves.** No sealed A1/A2/A3/A4 artifact is read for edit; the write surface
intersects the sealed anchor set in zero places. If your derivation finds otherwise, that is
a HALT.

## WRITE SURFACE

Exhaustive. Every path here except the ledger is **outside** the standing write surface and is covered by the
amendment this dispatch requires:

- `.gitignore` (repository root) -- the `session-*`-scoped pattern
- `docs/framework/**` -- only if the amendment directs a note; not required by acceptance
- `.mission/ledger/entries.jsonl` -- append only, `-NoCommit`

**CONDITIONALLY, AND ONLY IF ACCEPTANCE ITEM 4 PROVES IT NECESSARY:**

- `tools/mission-spec-accept.ps1` (`Assert-CleanGitTree`)
- `tools/mission-lib.ps1` (`Assert-CleanWorkingTree`)

These two are named here so the amendment can cover them, **not** because they are expected to
change. See ACCEPTANCE item 4: the expectation, derived, is that an ignored path never reaches
porcelain and therefore neither gate ever sees it. If a gate still refuses, **that is an
allow-side exemption arriving by the back door**, it is reported as a finding under law 2 with
its residual stated inline, and it does not land without the amendment naming it.

## FORBIDDEN

- **Committing any `.mission/evidence/session-*/` content.** Q1 is ruled. Four demonstrated
  mechanisms (F-4, F-5, NEW-1, NEW-2) make a finalized-and-consumable manifest silently
  incomplete; committing one makes that permanent in tracked history.
- **A blanket ignore of `.mission/evidence/`.** It would shadow every tracked
  mission-witness file under it. The pattern is `session-*`-scoped and anchored so it cannot widen to the
  directory and cannot match a future dispatch directory whose name merely begins with "session".
- **Deleting, relocating, or staging existing residue**, or the four RESIDUE-KEEP paths
  (`.mission/inputs/samples/sample-OVERSIZED.md`, `sample-RENAMED.md`,
  `sample-capabilities.md`, and `suite-run-operator.txt` **at the repository
  root** -- three under samples, one at root).
- **Adding an exemption to either gate as the primary cure.** Ruled against on law 2.
- **Uninstalling the hooks as the cure.** It works, and it means the window is exactly the window
  with no evidence capture. It remains the interim per design SS17.3; it is not the fix.
- **Touching `.claude/`, the sealed A1/A2/A3/A4 set, or the mission record.**
- **Weakening the five-condition precondition**, or implying evidence becomes committable
  because the clean-tree blocker was cured. Q2 is a gate question; Q1 is unaffected by it.

## ACCEPTANCE

Stated as a goal condition a validator can decide from disk.

1. **The root `.gitignore` carries a `session-*`-scoped pattern that is anchored**, and the
   anchoring is demonstrated in both directions: a path named `.mission/evidence/session-<id>/`
   is ignored, and a path named `.mission/evidence/session-of-record/` (or any non-residue
   sibling) is **not**.
2. **No tracked file changed status.** The count of tracked files under `.mission/evidence/`
   before and after is identical and derived, not asserted. `git ls-files` is the instrument.
   Zero rows found is a FAILURE, not a quiet pass.
3. **Porcelain no longer lists any `session-*` residue**, demonstrated on a residue directory
   that exists at the time of the run -- not on a synthesized one.
4. **BOTH GATES ARE DRIVEN, NOT REASONED ABOUT** (law 10). `Assert-CleanGitTree` and
   `Assert-CleanWorkingTree` are each exercised with residue present on disk, and the verbatim
   result of each is reported. The expected outcome is that neither sees the residue because it
   never reaches porcelain. **If either still refuses, report it as a finding, state what would
   be required, and do NOT add the exemption in the same act.**
5. **The MIXED DIRECTORY is stated on the face of whatever the build leaves behind** -- the
   ledger entry at minimum: `.mission/evidence/` is permanently mixed, tracked mission-witness
   evidence alongside ignored session residue, and that is the design rather than an oversight.
6. **The five-condition precondition is restated unweakened** in the ledger entry, with its
   dependency on D8, D10 and D11 intact.
7. **A ledger entry records the act**, including the pattern verbatim, the before/after tracked
   count, and the driven gate results.
8. **Regression.** The four RESIDUE-KEEP paths present and untracked throughout; porcelain
   compared before and after every act; sealed anchors unmoved -- this dispatch moves none.
   The acceptance suites are **operator-run** (design SS17.3 consequence): a
   suite you could not execute is reported as NOT RUN with the denial cited, never as a result.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- The `.gitignore` diff, verbatim, plus the file's sha256 prefix and byte length after.
- **The both-directions anchoring demonstration** from ACCEPTANCE item 1, verbatim.
- `git ls-files .mission/evidence` counts before and after, with the commands that produced them.
- **The two driven gate runs** from ACCEPTANCE item 4, verbatim, each labelled with which gate
  and whether residue was present on disk at the time.
- The ledger entry id and the line number it landed at.
- An explicit statement of what you did **not** verify -- including, if it applies, which
  acceptance suites were not run and why.
