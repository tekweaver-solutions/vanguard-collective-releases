# ADR-029 — `Complete → Reworking` mission re-entry transition (post-completion corrective increment)

> **Status:** Accepted — operator-ruled framework doctrine (a framework-level lifecycle change). Canonical as this standalone file per ADR-033 (standalone-canonical; rests at "Accepted" per the S1 rule).
> This ADR follows the **framework-ADR path** (same family as ADR-019..028: a
> standalone `adr-0NN-<slug>.md` under `tools/mission-cli/config/`), **NOT** the
> mid-mission amendment ceremony. A mission amendment edits *this mission's* spec
> version chain; this ADR edits the *framework's* lifecycle state machine, which
> every mission (and both deployment topologies) shares. It is therefore an
> operator-ratified framework decision, not a `mission amend approve`.
>
> **Drafted to give** a defect found after `Complete` a governed corrective
> path. Post-completion
> rework / mission re-entry — the durable answer to 'a defect found after done',
> is the missing piece of the lifecycle. Without a re-entry edge, a
> defect found after `Complete` has no
> governed route, so the
> edge must exist before any corrective commit can land legitimately.

---

**Decision.** Add a **`Reworking`** state to the shared Section-7 mission lifecycle
and two transitions connecting it to `Complete`:

```
Created → Planning → Executing → Validating → AwaitingApproval → Complete
                                                                     │  ▲
                                                  (operator reopen)   │  │  (operator re-closure)
                                                                     ▼  │
                                                                  Reworking
```

- **`Complete → Reworking` (reopen).** The operator re-opens a `Complete` mission
  with a **recorded reason** (written to the ledger as a `type: decision`,
  `scope: framework` entry; in Local Orchestrator Mode the operator action is a
  deliberate edit of `mission.yaml` `state`, the same shape as `mission state set`
  per local-orchestrator-mode.md §6.2/§7). The reopen entry records (a) the reason,
  (b) the SHA / `completed_at` of the completion being re-entered, and (c) the
  scope of the corrective increment about to begin. Reopen is **operator-gated and
  never automated** — it is the symmetric counterpart of the §11.5
  "mission completion is never automated" rule.
- **Rework as a scoped corrective increment.** Work in `Reworking` proceeds by the
  **same machinery already used for in-flight corrections** (a feature's corrective
  increment is the worked precedent): targeted build commits under
  incremental-commit discipline (ADR-021); new contract surface (e.g. a guard
  assertion) enters by the normal mid-mission amendment ceremony on top of the
  reopened mission; re-validation runs against the conformed code.
- **Re-validation supersedes prior attempts IN PLACE.** A re-run validator emits a
  new `ValidatorResult` at a new `attempt_number`; the prior attempt is preserved
  as `<assertion_id>.validator-result.attempt-<N>.json` and the `manifest.json`
  entry's `file` points at the current attempt with `supersedes` referencing the
  predecessor. This is the **existing §6 supersession convention**
  (`validator-results/manifest.json` `supersession_convention`) — Reworking adds
  no new evidence mechanism, it just re-uses it post-`Complete`.
  **Adversarial-validation invariant (§2.4) holds unchanged:** a re-validation
  validator must NOT be derived from the conformed implementation — re-run the
  existing narrow validator, or write expectations from the SPEC.
- **`Reworking → Complete` (re-closure).** On closure the mission returns to
  `Complete` with **`completed_at` updated** to the re-closure timestamp, and a
  ledger entry (`type: decision`, `scope: framework`) **chains the rework to the
  original completion** (referencing the prior `completed_at` and the reopen
  entry's id). The original `completed_at` is preserved in that chaining entry, so
  the audit trail records both the first completion and the re-completion. The
  Section-14.4 completion precondition (all features/milestones `done`, manifest
  all-must-pass) must hold again at re-closure, exactly as for first completion;
  re-closure goes through the same AwaitingApproval human-signoff gate
  (local-orchestrator-mode §11.5).

**Why this is forced by the principles.**

- **§2.7 — two drifts, two fixes / contract-before-code.** Without a re-entry edge,
  a defect found after `Complete` leaves only two bad options: "never re-open"
  (defects fester) or "ad-hoc edits to a `Complete` mission" (commits with no audit
  chain). The latter is the precise failure a re-entry edge exists to prevent. The
  `Reworking` state makes post-completion correction a *contracted, audit-chained*
  act instead of an off-the-books edit.
- **§14.3 — replayability.** Every state of the mission must be reconstructable from
  committed artifacts. A `Complete` mission that silently accrues edits is no longer
  replayable — its git history shows commits with no lifecycle event explaining
  them. The reopen/re-closure ledger pair restores the property: the lifecycle
  transitions are first-class committed events, and the corrective increment replays
  from the reopen entry forward.
- **§2.4 — pre-committed, adversarial validation.** Re-closure re-runs the contract,
  not a bespoke "good enough now" check; the supersession convention keeps the prior
  (failed/weak) attempt visible rather than overwriting it.

**Alternative considered.** A separate `Amending` state, or treating post-completion
work as a brand-new successor mission. Rejected: (a) a new mission orphans the
original mission's contract/ledger/validator-result chain — the corrective work is
*about* the same deliverable and must chain to it, not start a blank audit trail;
(b) `Amending` overloads the word "amendment", which already denotes the
spec-version ceremony (`.mission/amendments/`), and a state named after it would
blur the framework-ADR-vs-amendment distinction this very ADR rests on.
`Reworking` names the activity (corrective increment), not the artifact.

**Invariance check.**
- **Schemas (`expanded-schemas.md`) unchanged except the `Mission.state` enum.** The
  only schema surface touched is the lifecycle enum gaining `Reworking`. No field is
  added to `Mission`, `Amendment`, `ValidatorResult`, or `Ledger`. The reopen reason,
  the rework scope, and the completion-chain all live in **ledger entries**, not new
  mission fields — keeping the artifact set portable across both topologies
  (the artifact-portability invariant, local-orchestrator-mode §9).
- **Reconciles local-orchestrator-mode.md §9's "Local mode adds *no* states" claim.**
  That claim is now amended: `Reworking` is added to the **shared** Section-7
  machine (both topologies), not as a local-mode-only state — so the "local mode
  extends rather than bends the framework" property is preserved (the state exists
  for hosted mode too). **This reconciliation is part of what the operator is
  asked to ratify.**
- **Touchpoint symmetry.** §11.5 (completion never automated) gains a symmetric
  sibling: reopen never automated. Both are deliberate operator actions against a
  committed artifact.

**Reference.** multi-agent-framework-
design-brief.md §2 (principles: §2.4 adversarial validation, §2.7 two-drifts-two-fixes)
and §14.3 (replayability) as the forcing principles; ADR-021 (incremental-commit
discipline) for the corrective-increment commit shape; `validator-results/manifest.json`
`supersession_convention` for in-place re-validation; a feature's corrective increment
(and its closure decision)
as the in-flight-correction precedent this generalizes to post-`Complete`;
local-orchestrator-mode.md §7/§9/§11.5 (lifecycle, invariants, completion touchpoint).
