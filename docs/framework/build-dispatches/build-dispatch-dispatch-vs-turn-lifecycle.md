# D10 -- BUILD DISPATCH: dispatch lifecycle versus turn lifecycle (cures E5-iv)

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>"
> denote `docs/framework/vanguard-collective-local-modes-v2.3.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** Its author built nothing.
>
> **THIS DISPATCH MOVES SEALED A1 HASHES AND IS NOT STAGEABLE BY AN AGENT SESSION.** The guard
> denies `git add tools/framework/hooks/...` and `git add tools/framework/tests/...` by design
> (design SS4.5 law 8). The commit is an operator act. D6 is the pathway and D6
> is itself still a prompt -- see WRITE SURFACE.

---

## P0 GROUNDING

Read-only, first reply. Report each with the command and its raw output.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. **Is the defect still live?** Find a `.mission/evidence/session-*/` dispatch whose manifest
   `entry_count` is lower than its `log.jsonl` line count. Report both numbers and the derived
   state. This is E5-iv in the present tense; if you cannot find one, say so and HALT rather
   than proceeding against a defect you have not observed.
3. **`Get-EvidenceState` from source** (`tools/framework/hooks/lib/evidence-common.ps1`, sealed
   `189f811b`) -- derive exactly how `TAMPERED` is reached, and confirm it is reached by
   `log_sha256` mismatch alone with no distinction between "the log grew by append" and "the
   log's existing bytes changed".
4. **`evidence-stop-finalize.ps1` from source** (sealed `d1f69b6b`) -- derive the finalize path,
   the two-phase finalize and reconcile pass, and the refusal to re-finalize a `TAMPERED`
   dispatch.
5. **The hook-errors trail.** Read a `.mission-runtime/evidence/session-*/hook-errors.log` where
   one exists. Expect entries reading "Stop: REFUSED to finalize TAMPERED dispatch". Correlate
   their timestamps against the committed manifest's `finalized_at` -- see NEW-2:
   the errors post-date the only moment that would have committed them.
6. **Design SS4.6 E5-iv and SS17.2** -- the scoped `wiring_status`, in full, including "A
   consumer reading the manifest FILE sees complete; a consumer deriving STATE sees tampering.
   Neither is true."
7. **The governing amendment's scope** -- the two constraints this dispatch must carry.
8. **`tools/framework/hooks/settings.evidence-hooks.json`** (sealed `a5a8c166`) -- the `Stop`
   registration and its matcher.

**HALT AND REPORT if:** any of the four sealed hashes named in AUTHORITY has moved; or
`Get-EvidenceState` already distinguishes append-growth from byte-mutation (someone cured this);
or `Stop` is no longer registered.

**A NOTE ON GROUNDING ITEM 3 AND 4, BECAUSE IT WILL BITE YOU.** If you are an agent session with
the A1 guard live, `Get-FileHash` over those paths is DENIED and so is any shell command naming
them. Read them with the **file tools** (Read/Grep/Glob), which the guard exempts. Report the
denial verbatim if you hit it; it is the standing condition, not a defect in this dispatch. Your
anchor basis for the sealed set is then porcelain-absence, which is **strictly weaker than a
digest** -- say so.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; **never**
  `Invoke-AtomicCommit` (a registered defect). Ledger appends use `-NoCommit`.
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-10 bind. Laws 4, 5, 6 and 10 govern the acceptance.
- LEDGER-GOVERNS. AM files are immutable once placed.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **The governing amendment's scope, and the two constraints it carries** -- `TAMPERED` keeps
  naming log-hash mismatch, so a log that grew by append stays distinguishable from one whose
  existing bytes changed; and the cure fixes when a dispatch is over without adding capture
  (D8) or re-keying streams (D11). FORBIDDEN and ACCEPTANCE below state both in full.
- **design, "### 4.6 Erratum E5 -- four SS4.1 assumptions falsified by the live harness"**
  -- erratum E5-iv, the falsified assumption, per member with its evidence.
- **design, "### 4.7 Registered dispatches arising from E5"**
  -- the D10 registration.
- **design, "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- places D10 in Arc 1, after D9 and before D8.
- **The measurement P0 GROUNDING item 2 reproduces** -- for example a manifest finalized at
  `entry_count` 3 over a log that then grew to 5 -- and the refusal-to-re-finalize behaviour.
- **The error trail arriving after finalize** (NEW-2, ACCEPTANCE item 5): `hook-errors.log` entries
  written after `finalized_at` post-date the only moment that would have committed them.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: tools/framework/hooks/evidence-stop-finalize.ps1, tools/framework/hooks/lib/evidence-common.ps1, tools/framework/tests/test-a1-negative.ps1
MOVES A SEALED HASH: YES
SEALED FILE: tools/framework/hooks/evidence-stop-finalize.ps1 d1f69b6b
SEALED FILE: tools/framework/hooks/lib/evidence-common.ps1 189f811b
SEALED FILE: tools/framework/tests/test-a1-negative.ps1 a27d008b

**Why an amendment is required.** Not for the write surface -- `tools/framework/**` is inside
the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`) -- but because **a moved sealed hash must be recorded in a ledger
entry**, and because the commit is operator-mediated (below; design, "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)",
law 8). The amendment records which hashes move, with old and new prefix and byte length for each.

**THE ENUMERATION ABOVE IS DERIVED, NOT AUTHORED.** It is the intersection of this dispatch's
WRITE SURFACE with the full, non-abbreviated set of sealed anchors. Report old and new prefix
**and byte length** for each, and record all three in a ledger entry.

The third is not optional and is the one a builder forgets: the A1 negative suite **asserts
today's behaviour**, so a cure that changes the state machine without changing the suite either
breaks the suite or proves the suite never covered it. The dispatch set's adversarial validator
refuted D2 for exactly this omission. Report old and new prefix **and byte length**
for each, and record all three in a ledger entry. If your cure moves a fourth --
`settings.evidence-hooks.json` `a5a8c166`, should the `Stop` registration itself need to change
-- that is a finding, it is reported before it is made, and it is added to the amendment rather
than absorbed.

## WRITE SURFACE

- `tools/framework/hooks/evidence-stop-finalize.ps1`
- `tools/framework/hooks/lib/evidence-common.ps1`
- `tools/framework/tests/test-a1-negative.ps1`
- `.mission/ledger/entries.jsonl` -- append only, `-NoCommit`

All are inside the standing write surface. **NONE IS STAGEABLE BY AN AGENT SESSION** while the hooks are live:
the guard denies `git add` naming `tools/framework/hooks` or `tools/framework/tests`. The commit
is performed by the operator from their own shell. **If D6 has landed by the time you run, follow
its pathway.** If it has not, say so explicitly in your report, hand the operator the exact
`Get-FileHash` and `git add` commands to run, and record that you did so -- that act is D6's
demonstrated need and its dispatch cites instances of it.

## FORBIDDEN

- **Weakening `TAMPERED` into a default.** The state exists to name log-hash mismatch. A cure
  that makes continued work non-`TAMPERED` by making `TAMPERED` harder to reach has removed the
  detector rather than fixed the lifecycle.
- **Curing E5-ii/iii here.** Failed and denied calls are D8. This dispatch does not add capture;
  it fixes when a dispatch is considered over.
- **Curing the stream-name collision here.** That is D11. Do not renumber, rename, or re-key
  stream files as a side effect.
- **Committing evidence, or changing what gets copied into `.mission/evidence/`.** That is D9,
  and D9's Q1 is ruled NOT COMMITTED.
- **Editing `settings.evidence-hooks.json`, the guard, the installer, the schema, or any A2/A3/A4
  artifact** without declaring it first per AUTHORITY.
- **Touching `.claude/`, the mission record, `src/`, or `tests/`.**
- Claiming the cure makes evidence complete. It makes the dispatch's **end** well-defined. The
  failure dimension stays empty until D8.

## ACCEPTANCE

Stated as a goal condition a validator can decide from disk.

1. **A dispatch that continues working across many turns finalizes ONCE, at the end, and derives
   a consumable state** -- demonstrated by driving a real multi-turn session, not by synthesized
   payloads (law 10; law 6).
2. **"Grew by append" and "existing bytes changed" remain DISTINGUISHABLE, per member.** There is
   a named state or flag for each, each has a working detector, and each detector is
   **demonstrated firing** on a case constructed for it. A class claim without a per-member
   demonstration fails law 4.
3. **Byte-mutation of an already-recorded log still derives `TAMPERED`.** Driven, with the
   verbatim before/after. This is the regression that proves item 2 did not remove the detector.
4. **The re-finalize refusal is resolved coherently and the resolution is stated**: either
   finalize supersedes with the prior manifest retained, or it refuses with a state that is
   honest about why. Silence on this is a failure -- it is the behaviour that made the live measurement's
   own dispatch non-consumable.
5. **The error trail is reachable after finalize** (NEW-2), or, if this cure does not
   reach that, the residual is stated per member and registered. Do not report it cured if a
   `hook-errors.log` entry written after `finalized_at` still cannot be surfaced.
6. **`test-a1-negative.ps1` covers the new behaviour and still passes in full**, with its check
   count derived rather than typed, and with the docstring count not left stale.
7. **The manifest schema is honoured.** If `state` gains a member, `docs/framework/
   evidence-manifest.schema.json` (`2a04099d`) is a sealed A2 artifact -- moving it is a
   FOURTH sealed hash and a finding to report **before** making it, not after.
8. **Regression.** RESIDUE-KEEP untouched; porcelain compared before and after; the acceptance
   suites are **operator-run** and any suite you could not execute is reported as
   NOT RUN with the denial cited, never as a result.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- **Old and new sha256 prefix AND byte length for each of the three moved anchors**, plus any
  fourth, with the command that produced each.
- The **driven multi-turn demonstration** from ACCEPTANCE item 1: the manifest before and after,
  the log line count at each point, and the derived state, verbatim.
- The **two per-member detector demonstrations** from ACCEPTANCE item 2 and the byte-mutation
  regression from item 3, verbatim.
- The A1 negative suite run in full with its exit code, **or** the verbatim denial and a plain
  statement that it was operator-run or NOT RUN.
- The ledger entry id and line number.
- The exact commands handed to the operator for staging, if the commit was operator-mediated.
- An explicit statement of what you did **not** verify.
