# ADR-031 — One active mission per monorepo; successor missions run in place (supersedes two ADR-011 clauses)

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy per
> ADR-033 (standalone-canonical; an ADR rests at "Accepted" once operator-ruled — the S1 rule; there is no
> fold-into-`local-orchestrator-mode.md` step). This ADR follows the **framework-ADR path** (a standalone
> `adr-0NN-<slug>.md` under `tools/mission-cli/config/`), **NOT** the mid-mission amendment ceremony. A
> mission amendment edits *this mission's* spec version chain; this ADR edits the *framework's*
> mission↔monorepo binding and supersedes two clauses of ADR-011 (now standalone
> `adr-011-single-mission-single-user-scope.md`), which every mission (and the local topology) shares. It is
> therefore an operator-ratified framework decision, not a `mission amend approve`.
>
> **Drafted to resolve** a live contradiction between **ADR-011** (`local-orchestrator-mode.md` §3,
> "one monorepo per mission … a user finishing mission A and starting mission B does so by opening a
> **new** monorepo") and **ADR-030** ("a **successor mission** … extends the product by modifying the
> product source directly", in place). The two cannot both stand. The operator rules in favor of
> ADR-030's in-place model and reverses the offending ADR-011 clause. A grounding read further found
> ADR-011's asserted single-instance lock to be **counterfactual** — no `.mission-runtime/mission.lock`
> exists and `mission-init.ps1` carries no lock logic — so this ADR records the one-active invariant as
> the **rule** while marking its enforcement **unimplemented**, rather than inheriting a claim the code
> does not honor.

---

**Decision (operator-ruled doctrine).**

1. **One-active invariant.** A monorepo has **at most one ACTIVE mission at any time.** "Active" is any
   mission whose `state` is not a terminal `Complete` (i.e. `Created`/`Planning`/`Executing`/`Validating`/
   `AwaitingApproval`/`Reworking` per the Section-7 lifecycle as extended by ADR-029). Concurrency of two
   non-terminal missions in one monorepo is prohibited.
2. **Binding invariant.** While active, a mission is intrinsically **1:1 with a monorepo.** The mission's
   artifact store (`.mission/`) and the monorepo working tree are the same checkout; there is no
   second-mission namespace alongside an active mission.
3. **Successor-in-place.** A **new** mission does **NOT** require a **new** monorepo. When the monorepo
   already exists, a subsequent mission runs **in it** after the prior mission has closed (`Complete`).
   This makes **ADR-030's "successor mission modifies product in place, same repo" the governing model**:
   the product is the living codebase the organization continues to evolve; the next mission extends it
   in place, under the standard discipline (contract-before-code §2.7, adversarial validation §2.4,
   incremental-commit ADR-021), not by standing up a fresh monorepo per unit of work.
4. **Supersession of ADR-011.** This ADR **supersedes exactly two clauses** of ADR-011
   (now standalone `adr-011-single-mission-single-user-scope.md`; formerly inline at `local-orchestrator-mode.md` §3):
   - **(a) REVERSED — the new-monorepo-per-successor clause.** ADR-011's *"A user finishing mission A and
     starting mission B does so by opening a new monorepo"* is reversed: a successor mission **reuses the
     existing monorepo** and runs in place after the prior mission closes (per Decision 3).
   - **(b) DOWNGRADED to rule-without-enforcement — the lock claim.** ADR-011's *"The `mission` CLI
     enforces a single-instance lock against the monorepo; attempts to start a second mission process for
     the same repo are rejected"* and *"One CLI process at a time, enforced via a PID lockfile in
     `.mission-runtime/mission.lock`"* **describe enforcement that does not exist in code** (grounded at
     HEAD: no `.mission-runtime/mission.lock`; `mission-init.ps1` has no lock/single-instance/PID logic —
     its only guard is a folder-collision check). ADR-031 keeps the **one-active invariant as the RULE**
     (Decision 1) but records its enforcement as **UNIMPLEMENTED / required follow-on (F2)**. This ADR
     makes **no claim that a lock exists.**
   - **RETAINED (NOT superseded):** ADR-011's remaining content stands unchanged — *one user per laptop*,
     *no multi-mission scheduling*, *no per-user namespacing*, *no cross-mission resource pooling*, the
     fixed sandbox/Ollama port range, the single `.mission-runtime/` directory, and the
     "does-not-bleed-into-hosted-mode" boundary (hosted mode remains multi-tenant/multi-mission). Only
     clauses (a) and (b) fall; everything else in ADR-011 is in force.

**Required follow-on (named here, NOT designed or executed by this ADR).**

- **F1 — `.mission/` is structurally single-mission; the successor-in-place model requires a restructure.**
  At HEAD `.mission/` holds exactly **one** `mission.yaml`, **one** linear `spec/vNNN.yaml` chain, **one**
  `ledger/entries.jsonl`, and a single mission UUID — there is no per-mission namespacing or index. A
  second mission run in place under Decision 3 would **overwrite/co-mingle** the first mission's spec
  chain, contract, and ledger. Reconciling this (per-mission namespacing, or archive-on-close so the
  sealed history of all missions co-exists) is **BLOCKING for multi-mission** and is **deferred to a
  separate ADR / design seam.** ADR-031 only **names** it; it does not design or perform the restructure.
- **F2 — implement the one-active-mission enforcement** (the lock ADR-011 claimed but that does not exist).
  Deferred. Until built, the one-active invariant (Decision 1) is a **rule honored by operator
  discipline**, not a mechanism.
- **F3 — lifecycle tooling past `Executing`.** `Complete`/`Reworking` (and `Validating`/`AwaitingApproval`)
  transitions are performed today by **manual `mission.yaml` edits** (no `mission state set` / `mission
  complete` tool exists); ADR-029's reopen/re-closure is likewise a deliberate `mission.yaml` edit. Noted
  as known current state. Deferred.

**Alternatives considered.**

- **(a) Keep ADR-011 as written.** Rejected: its successor-by-new-monorepo clause **contradicts ADR-030**
  and the operator doctrine, and its single-instance-lock clause is **counterfactual** at HEAD (no lock
  exists). Leaving it standing would keep a live contradiction in the corpus and assert enforcement the
  code does not provide.
- **(b) One-monorepo-per-mission with mission history archived elsewhere** (outside `.mission/`). Rejected:
  it **defeats the intended ".mission/ holds the holistic record of all missions" model**, orphans
  successor work from the deliverable's contract/ledger/validation chain it extends (the same orphaning
  ADR-030 rejected for shadow trees), and forfeits the in-place evolution ADR-030 mandates.

**Tradeoff accepted.** The successor-in-place model gives up what new-monorepo-per-mission bought ADR-011:
**clean filesystem isolation between missions** (a fresh monorepo guaranteed no spec/ledger collision and
no runtime-state bleed). In exchange, **`.mission/` must carry cross-mission history and grows unboundedly**
across a long-lived product's life, and the project takes on **restructure debt now** (F1) — the
single-mission store must be re-shaped before a second mission can safely run. This is the cost of treating
the repo as a **long-lived product** (ADR-030) rather than a per-mission scratch
checkout: history accretes in one place, and isolation becomes a discipline + future mechanism (F1/F2)
rather than a free property of separate directories.

**Supersession marker (placed — the fold gate is void under ADR-033).** Per ADR-033 (standalone-canonical),
ADR-011 was extracted to its own standalone file (`adr-011-single-mission-single-user-scope.md`); both ADRs
now live as standalone files in the one canonical store. ADR-031 declares the supersession in **its own
body** (Decision 4); the back-reference marker (*"clauses (a)/(b) partially superseded by ADR-031"*) is
placed directly on the standalone ADR-011. The earlier deferral ("when ADR-031 is folded into the doc") no
longer applies — there is no fold step.

**Invariance check.**

- **No schema change.** This ADR rules on the mission↔monorepo binding and supersedes two prose clauses;
  it adds no state, field, or enum. `Mission` (and its `state` enum, `expanded-schemas.md`) is untouched —
  the one-active invariant constrains *how many* missions are non-terminal in a repo, not the mission
  schema. F1/F2/F3 are named as deferred, so no artifact surface changes here.
- **Topology scope.** Like ADR-011, this is **Local Orchestrator Mode** doctrine; it does not constrain
  Hosted Autonomous Mode, which remains multi-tenant/multi-mission (ADR-011's retained boundary).
- **Consistent with ADR-029/030.** ADR-030 supplies the in-place successor model this ADR makes the
  governing rule; ADR-029 supplies the `Reworking` re-entry path for same-mission corrective work; ADR-028
  `scope: framework` is the correct subject axis for the companion ledger entry. None is changed.

**Reference.** ADR-011 (`local-orchestrator-mode.md` §3, L213–223 — the two superseded clauses (a)/(b) and
the retained remainder); ADR-029 (`Complete → Reworking` re-entry — the same-mission corrective path);
ADR-030 (mission completion seals history not product code — the in-place successor model this ADR makes
governing); `local-orchestrator-mode.md` §3 (ADR-011 home) and §7 (Section-7 lifecycle / touchpoint
mapping); `expanded-schemas.md` Section 1 (`Mission.state` — unchanged); ADR-033
(standalone-canonical; an ADR rests at "Accepted" once operator-ruled), the canonical-home
direction this ADR's Status and
supersession-marker seam follow; ADR-030 ("long-lived product") as the forcing framing.
