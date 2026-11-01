# D5 -- BUILD DISPATCH: reconcile `expected-failures.yaml` with the mechanism that already exists

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>" denote
> `docs/framework/vanguard-collective-local-modes-v2.2.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. "spec SS<n>" denotes
> `docs/framework/mission-verify-spec.md`. Bare `A-NNN` / `ADR-0NN` denote on-disk mission law
> under `tools/mission-cli/config/`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build. AND IT IS NOT A CREATION DISPATCH.** Read AUTHORITY before
> anything else: the thing this dispatch most obviously appears to ask for is the one act it
> forbids.

---

## P0 GROUNDING

Read-only, first reply.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. Confirm `tools/mission-cli/config/expected-failures.yaml` is **absent**.
3. `.mission/green-gate/product.json` and `.mission/green-gate/framework.json` -- read the
   `expected_failure_test_ids` field in each. Either may carry ids or none.
   **Derive the count; this dispatch carries no figure to trust.**
4. `tools/mission-green-gate-seed.ps1` and `tools/mission-lib.ps1` -- every read and write of
   `expected_failure_test_ids`. This is the live mechanism.
5. **The mission's assertions** -- the mission law governing
   sanctioned red and the baseline-record consistency obligation. Read the actual text.
6. `docs/framework/expanded-schemas.md` SS5, the `SuiteAnchor` sub-schema: the
   `expected_failures_matched` row and the file it names. Expect `db3a8946`.
7. `docs/framework/mission-verify-spec.md` SS4.1 residual and SS12. Expect `46312f76`.
8. **The operator-ratified ruling that scopes this dispatch, IN FULL.**

**HALT AND REPORT if:** `expected-failures.yaml` now exists (someone created it, and the
second-source-of-truth problem is already live), or if the green-gate field has been removed
(the mechanism moved and the reconciliation options below have changed).

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; never
  `Invoke-AtomicCommit` (a registered defect; D3 is its cure).
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-9 bind.
- LEDGER-GOVERNS.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **The scoping ruling** (P0 GROUNDING item 8). Its finding, restated so a
  builder cannot miss it: **the declared home is framework mechanism, the content is mission
  truth, and the content already has a governed home.** Creating
  `tools/mission-cli/config/expected-failures.yaml` would make a **second source of truth for
  one fact across two governance domains** -- the same shape as the A2 `Report` ruling
  (schemas, "## Registered decisions"), where
  v2.2 named a carrier, no artifact answered to the name, and A2 registered the term rather
  than inventing an artifact to satisfy it.
- **spec, "## 12. Registered by this document"** -- registers the declared home and the absent
  file; schemas, "## 5. Handoff Document", *Expected-failure manifest*, states that the
  mechanism is framework and the content is mission truth.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`),
  "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 22 (D5): a mission-reaching amendment; reconcile,
  do not create.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: .mission/green-gate/**, tools/mission-cli/config/expected-failures.yaml, docs/framework/expanded-schemas.md, tools/mission-green-gate-seed.ps1, tools/mission-lib.ps1
MOVES A SEALED HASH: YES
SEALED FILE: docs/framework/expanded-schemas.md db3a8946

The amendment must be **mission-reaching**, not framework-only: `.mission/green-gate/**` is
mission state and no framework amendment touches it. Whether the sealed hash actually moves
depends on which option is chosen -- options (a) and (c) edit the schemas document, option
(b) may not -- so the declaration above is the conservative one and your ceremony records
what actually moved.

## WRITE SURFACE

Determined by the option the amendment selects; do not write anything before it is selected.

- `docs/framework/expanded-schemas.md` -- the `SuiteAnchor` row and SS12 (options a, c)
- `tools/mission-cli/config/expected-failures.yaml` -- **only** under option (b)
- `.mission/green-gate/**` -- **only** under option (b), and only with mission-scope authority
- `tools/mission-green-gate-seed.ps1`, `tools/mission-lib.ps1` -- **only** under option (b)
- `.mission/ledger/entries.jsonl` -- append only
- `.mission/amendments/<the authorizing amendment>.yaml` -- placement only

## FORBIDDEN

- **Creating `tools/mission-cli/config/expected-failures.yaml` on your own judgement.** This
  is the forbidden act named at the top. Under the scoping ruling it is authorized only if the
  amendment selects option (b), and then only together with the migration that removes the
  other carrier.
- **Leaving two populated carriers for the same fact.** Whatever option is chosen, exactly
  one carrier holds the truth at the end, and the other is removed or explicitly demoted to a
  pointer. Two carriers is the defect this dispatch exists to prevent, and shipping both
  would be curing a documentation gap by creating a data-integrity one.
- **Picking the option yourself.** See ACCEPTANCE item 1. A build dispatch that resolves a
  governance question by writing a file has decided it by construction, and the decision then
  lives in a diff instead of an amendment.
- **Authoring or editing the test ids.** They are mission truth under the sanctioned-red law. You reconcile
  where they live; you do not decide which tests are allowed to be red.
- Making `mission verify` read the green-gate file as a silent substitute for the declared
  home. That remains forbidden until the reconciliation lands -- see spec SS4.1's residual and
  D1's ACCEPTANCE item 6.

## ACCEPTANCE

1. **The amendment selects exactly one option and states why the others were rejected.** The
   three are:
   - **(a)** the schema's declared home is **corrected** to name the existing green-gate
     carrier and its field;
   - **(b)** the green-gate field is **migrated** to the declared home and the sanctioned-red machinery
     is repointed;
   - **(c)** the declared home is **retired** and `expected_failures_matched` is redefined
     against the existing carrier.
   The dispatch does not pick. If you find a fourth option, propose it to the amendment
   rather than taking it.
2. **Exactly one carrier holds the truth at the end**, demonstrated by deriving the field
   from disk and showing the other location absent or explicitly a pointer.
3. **The baseline-record consistency obligation and the sanctioned-red rule still hold**,
   demonstrated by a driven green-gate operation -- seed or close -- against a scratch
   mission, not the real one.
4. **`expected_failures_matched` has a resolvable data source**, and spec SS4.1's residual is
   updated to match reality. If the residual no longer describes the world, the document
   moves.
5. **The expected-failure ids (derive the count) survive the reconciliation unchanged in content**, or
   any change is separately ruled as mission truth by someone with the authority to rule it.
6. **Every consumer enumerated at grounding still works**, each exercised or explicitly
   listed as unexercised with the reason.
7. **Regression:** A1 14/14 exit 0; A2 acceptance -- note its exit may change if
   `expanded-schemas.md` moves, and if so the change is explained and the instrument updated
   under its own authority rather than tuned to pass; A3 acceptance exit 0; RESIDUE-KEEP
   untouched.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- sha256 prefix and byte length for every file created or modified, plus the old prefix for
  anything sealed that moved, and the ledger entry recording the move.
- The **derived** `expected_failure_test_ids` population before and after, with the command
  that produces it -- so a reader re-derives instead of trusting a snapshot.
- The driven green-gate operation from ACCEPTANCE item 3, verbatim.
- The consumer enumeration with each site's disposition.
- Full regression outputs with exit codes.
- An explicit statement of what you did **not** verify.
