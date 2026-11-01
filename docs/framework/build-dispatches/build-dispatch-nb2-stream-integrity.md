# D2 -- BUILD DISPATCH: NB-2, the stream-integrity ordering fix, in its CORRECT form

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>" denote
> `docs/framework/vanguard-collective-local-modes-v2.2.md`. "spec SS<n>" denotes
> `docs/framework/mission-verify-spec.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** A4 authored it and built nothing.

---

## P0 GROUNDING

Read-only, first reply, before writing anything.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. `tools/framework/hooks/lib/evidence-common.ps1`, the `Test-EvidenceStreamIntegrity`
   function IN FULL. Expect sha256 prefix `189f811b`, 46870 bytes.
3. `tools/framework/hooks/evidence-stop-finalize.ps1`, the manifest-entry projection loop --
   the `_precompact` branch specifically. Expect `d1f69b6b`.
4. `tools/framework/hooks/evidence-pre-compact.ps1` -- where `transcript_sha256` is written.
   Expect `5428c5a0`.
5. `docs/framework/mission-verify-spec.md` SS5 IN FULL -- the resolution you implement.
   Expect `46312f76`.
6. `docs/framework/evidence-manifest.schema.json` -- the two entry variants. Expect `2a04099d`.
7. `tools/framework/tests/test-a1-negative.ps1` -- the suite you EXTEND. Expect `a27d008b`,
   54272 bytes, and **14** checks today. Your cure adds cases, so both its count and its hash
   move; it is the second sealed file under AUTHORITY.

**RE-DERIVE, DO NOT TRUST, THESE THREE CLAIMS.** They are this dispatch's whole basis and
each was verified against sealed source at A3 and again at A4. If any no longer holds, HALT
and report -- a cure built on a stale reading of the defect is a new defect.

- **(i)** In `Test-EvidenceStreamIntegrity`'s per-entry loop, the stream-file existence test
  PRECEDES the `if (-not $expOut) { continue }` line.
- **(ii)** `evidence-stop-finalize.ps1` projects `_precompact` entries with
  `transcript_sha256`, `captured` and `path` ONLY -- **there is no `stdout_sha256` on that
  variant at all.**
- **(iii)** `transcript_sha256` is written by the PreCompact hook, projected by the Stop
  hook, presence-asserted by the A1 negative suite, and **compared against the transcript
  file by no code path anywhere in `tools/framework/**`.**

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`. Never
  `Invoke-AtomicCommit` (registered defect R2; D3 is its cure).
- Strict UTF-8, no BOM, LF-only; `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-9 bind, law 3 and law 4 especially: every claim you make about this
  cure is stated per-member and demonstrated per-member.
- LEDGER-GOVERNS: amendment files are immutable; status lives in the ledger.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **spec, "## 5. NB-2, resolved"** and **spec, "### 5.2 The code delta, stated and not applied"**
  -- resolve NB-2 as an ordering rule; **spec, "## 12. Registered by this document"** registers
  this delta as an A4-dispatch build item, explicitly SPECIFY-ONLY at A3.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 10 (D2).
- **schemas, "## Registered decisions"** -- the NB-2 row: first registered at A1, carried at A2
  as DEFERRED TO A3, and corrected on the record at A3 by the spec.

NEEDS ITS OWN AMENDMENT: NO
MOVES A SEALED HASH: YES
SEALED FILE: tools/framework/hooks/lib/evidence-common.ps1 189f811b
SEALED FILE: tools/framework/tests/test-a1-negative.ps1 a27d008b

**Read the seal lines together with the write surface, and note that there are TWO.** The
write surface is fine -- `tools/framework/**` is inside the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`). What is **not** free is
the seal, and this dispatch moves **two** sealed A1 anchors, not one: `evidence-common.ps1`
carries the delta, and `test-a1-negative.ps1` carries the new negative cases ACCEPTANCE item 6
requires. Both are sealed A1 anchors. An earlier revision of this dispatch enumerated only the
first while its own WRITE SURFACE declared both -- a builder following it literally would have
moved two sealed hashes and recorded one, producing precisely the drift the sentence below
names. A moved sealed hash must be recorded: your ceremony appends a ledger entry recording, FOR
EACH of the two, the old and new prefixes, the byte length, and what moved them. A sealed hash
that changes without a ledger entry is exactly the drift the seal exists to prevent.

**AND ONE OPERATIONAL FACT THAT MAY ALREADY BIND YOU.** If the A1 hooks have been installed
(local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "### 17.1 What was done"), the PreToolUse guard **denies**
`git add tools/framework/hooks/...` by design -- design, "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)",
law 8, Principle 11 expressed in the guard. Your commit is then an
**operator-mediated act**, per D6's pathway. Check whether `.claude/settings.json` exists
before you plan your ceremony. Do not attempt to work around the guard; that it denies you
is the design working.

## WRITE SURFACE

- `tools/framework/hooks/lib/evidence-common.ps1` -- the `Test-EvidenceStreamIntegrity` function only
- `tools/framework/tests/test-a1-negative.ps1` -- new negative cases for the new branches
- `.mission/ledger/entries.jsonl` -- append only (the seal-move record)

## FORBIDDEN

- **The bare one-line hoist.** Moving `if (-not $expOut) { continue }` above the existence
  test is NOT the fix and must not be shipped as one. See ACCEPTANCE item 2.
- Editing `evidence-stop-finalize.ps1` or `evidence-pre-compact.ps1` to add `stdout_sha256`
  to the `_precompact` variant so the existing code path "just works". That changes the
  manifest shape, contradicts the sealed schema's two-variant declaration, and cures a
  coverage problem by deleting the distinction that makes coverage checkable.
- Touching any other function in `evidence-common.ps1`.
- Any sealed A2/A3 artifact.
- Weakening or removing an existing A1 negative case to make the suite pass.
- Describing this delta as a one-line fix, in code comments, in the ledger, or in your
  report. The characterization was falsified by source and corrected on the record; repeating
  it re-introduces a refuted claim.

## ACCEPTANCE

1. **The variant is discriminated by branching, not by falling through.** Three branches,
   each doing something different:
   - **tool-call entry** -- unchanged. Existence, then `stdout_sha256` and `stderr_sha256`
     re-derived from the body and compared.
   - **`_precompact` with `captured: false`** -- emitted as a **CAPTURE GAP** in its own
     category. No existence test. No mismatch. Not silently dropped either: the manifest's
     `captured` boolean exists as a separate field precisely so a false there is not read as
     an absent event.
   - **`_precompact` with `captured: true`** -- existence test **AND** `transcript_sha256`
     compared against the sha256 of the snapshot file. **This comparison exists nowhere in
     the sealed set today.** It is the coverage the bare hoist would have removed, plus the
     coverage that was never there.
2. **The coverage hole is closed and PROVEN closed by a driven case.** Because `_precompact`
   entries carry no `stdout_sha256` at all, a hoisted `continue` fires for **every**
   `_precompact` entry -- `captured: true` included -- and those reach the existence test
   today. Drive a `captured: true` `_precompact` entry whose snapshot file is missing:
   the bare hoist SKIPS it (silent), the correct form REPORTS it. Show both outputs side by
   side. That pair is the acceptance evidence for this item.
3. **The false positive is gone**, proven by its own driven case: a `_precompact` entry with
   `captured: false`, null `transcript_sha256`, and a `path` the schema requires, produces a
   CAPTURE GAP -- not `stream file missing`, and `ok` does not go false on it.
4. **A tampered transcript is now detected**, proven by mutating a snapshot body and showing
   the `transcript_sha256` comparison fire. Before this delta, nothing anywhere detects it.
5. **The function's return shape stays consumable by spec SS4.3's arm** -- `checked`,
   `mismatches`, `ok`, `reason` -- with capture gaps distinguishable from mismatches rather
   than merged into the same list. A consumer must be able to tell a disclosed gap from an
   integrity violation without parsing prose.
6. **The A1 negative suite passes at its new count**, with new cases for all three branches,
   and the count DERIVED rather than typed. The suite's N10 mirror enforces the documented
   catch list in both directions; a new case with no documented catch fails, and a documented
   catch with no case fails.
7. **The threat notes' claim set still matches the suite** -- if a claim there is now
   narrower or wider than what the code does, the document moves, not the claim.
8. **Regression:** the A1 suite green at its DERIVED NEW COUNT, with the old count (14)
   recorded beside it so the move is visible, and with zero repository residue; A2 acceptance
   exit 3; A3 acceptance exit 0; A4 acceptance exit 0; the four RESIDUE-KEEP paths untouched.
   **"Stays at 14/14" is not the standard and an earlier revision of this dispatch said so in
   three places at once** -- item 6 requires new cases, which moves the count by construction.
   Green at a derived count is the standard; an unchanged count would mean item 6 was skipped.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- The old and new sha256 prefix and byte length of **each** of the two sealed files this
  dispatch moves -- `evidence-common.ps1` (from `189f811b`) and `test-a1-negative.ps1` (from
  `a27d008b`) -- and the ledger entry recording **both** seal moves. One entry may record both;
  neither may go unrecorded.
- The **side-by-side outputs** required by ACCEPTANCE items 2, 3 and 4 -- bare hoist versus
  correct form on the same fixture. This is the core evidence of the dispatch and a report
  without it has not demonstrated the thing it claims.
- Full A1 suite output with exit code; A2 and A3 suite exit codes.
- If the guard denied any staging attempt: the verbatim denial, and how the commit was made
  instead.
- An explicit statement of what you did **not** verify.
