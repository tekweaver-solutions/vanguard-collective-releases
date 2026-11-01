# ADR-041 — Destructive lifecycle-op gating (operator/CLI layer): bounded + recorded + recoverable; mission-state reclaim is archive-before-prune

> **Status:** **Accepted** — operator-ruled framework doctrine, resting-status rule S1 per ADR-033.
> Rests at **"Accepted"** in the native S1 form — no abolished Framing-C boilerplate; no
> fold-in step. **Standalone-canonical in `tools/mission-cli/config/`** (same family + home as ADR-019..040)
> per ADR-033; the standalone file IS the decision.
>
> **Nature & path.** A **framework capability / lifecycle decision in the ADR-026 family** — it defines the
> *safe gating mechanism* for the **destructive** lifecycle operations that ADR-026 named-but-deferred
> (`adr-026-capability-model-v2-read-tier-vcs-commit-egress-defer.md` — Decision 2's excluded destructive
> subcommand set; Decision 3's egress-deferral). It is the destructive counterpart to the
> *constructive* lifecycle CLI (`reopen / promote-contract / spec-bump / close-milestone / reclose /
> ledger-append`). It discharges the destructive-op-gating increment
> **ADR-026 left deferred**
> (destructive-op gating as a future increment). Follows the **framework-ADR path** (a
> standalone `adr-0NN-<slug>.md`), **NOT** the mid-mission amendment ceremony: it **changes no spec version**,
> adds no schema / field / enum, and **writes no CLI code and no validation contract** — the destructive
> command surface, its contract assertions, and its fixtures are the **next seams, gated by this ADR**. It
> records **gating doctrine only**.

## Context

**The motivating failure class is an unscoped purge.** Consider
an **operator/CLI-layer destructive git operation** — `git reflog expire
--expire=now --expire-unreachable=now --all` + `git gc --prune=now` — run against a live repository. Such an
operation has three properties this ADR exists to prevent:

- it can start inside a seam scoped for verification only
  (working-tree-level verification; history/branch/reflog forensics owed).
- a mid-stream answer that the residue should go
  can be enough to run the purge.
- so the
  operation can **(a) exceed its written dispatch** (a seam's written dispatch may be read-only and
  forbid deletion), **(b) be
  authorized verbally mid-stream without re-scoping** (an interactive answer authorizes it but does
  not re-scope the seam's no-delete instruction in writing), and **(c) be
  irreversible** (purged dangling objects are unrecoverable locally). Whether
  referenced history stayed intact can be
  established **only after the fact**, by an independent `git fsck --full` + `for-each-ref --contains` check that
  proves every purged SHA was unreferenced.

**The gap.** ADR-026 governs the **worker capability layer**: destructive git subcommands (`reset, clean,
checkout, switch, restore, stash, rebase, merge, cherry-pick, gc, prune`) are **excluded from the
`worktree.commit` allowlist** — "destruction stays an operator capability" (ADR-026 Decision 2). That is a
**denylist for workers**. But such a purge is **not** a worker action through the gateway; it is an
**operator/CLI-invoked** op at the repository root, a layer ADR-026's worker denylist never reaches. **No
mechanism gates operator/CLI-invoked destructive lifecycle ops.** This ADR fills that layer. It does **not**
re-decide the worker layer (ADR-026 stands) and it does **not** turn destruction into a worker capability —
the destructive op is **wanted** by the operator (the candidate trigger: "a mission needs to reclaim or prune
mission state"), so this layer grants **gated permission**, where ADR-026 grants **denial**.

## Decision

Two decisions, one mechanism, one motivating failure. The governing principle for both: a destructive op at
the operator/CLI layer is permitted only when it is **BOUNDED** (its target is explicitly scoped, not
ambient), **RECORDED** (authorization and effect are written, never verbal), and **RECOVERABLE** (nothing
referenced or sealed can become unrecoverable). A destructive command **refuses before mutating** if any gate
fails — the lifecycle CLI's enforce-refusal shape (`Assert-CleanWorkingTree`, `Test-RosterClosable`,
`Assert-NoOpenObligations`: mechanical readers that refuse, never trust).

### Decision 1 — Object-store destructive ops (the unscoped-purge class)

**Covered set:** `git gc --prune` / `git prune`; `git reflog expire --expire-unreachable`; operator-level
`git reset --hard` (beyond the bounded rollback `Invoke-AtomicCommit` already performs); `git branch -D`;
`git update-ref -d`; `git reflog delete`. **`git push --force` / `--force-with-lease` stays DENIED** — it is
**egress**, outside this layer's representational scope (ADR-026 Decision 2/3); this ADR does not grant it.

**Gating mechanism — refuse-before-mutate, requiring all of:**

1. **(i) clean working tree** (the `Assert-CleanWorkingTree` precondition — no destructive op runs over stray uncommitted state);
2. **(ii) a WRITTEN scoped authorization naming the target** — the precise object/ref/range the op may touch.
   This is **the unscoped purge's missing piece made structural**: authorization is *written and target-scoped*, never a
   verbal "purge now" that leaves the seam's no-delete instruction un-rescoped;
3. **(iii) a pre-op recorded recoverability anchor** — the pre-operation SHA (and, for reflog-expiring ops,
   an explicit recorded acknowledgement that the recovery net itself is being discarded), so the prior state
   is nameable and, where the op permits, restorable;
4. **(iv) a post-op integrity proof** — `git fsck --full` clean **and** `git for-each-ref --contains` proving
   **nothing REFERENCED was in scope**. This is exactly the after-the-fact audit check, **hoisted to
   run during the op** rather than as a later rescue;
5. **(v) a ledger append recording what was destroyed** — the BOUNDED target, the authorization, and the
   integrity-proof result, as an append-only entry.

If any of (i)–(v) cannot be satisfied, the command **refuses** (non-zero exit, zero mutation).

### Decision 2 — Mission-state reclaim / prune (`.mission/`)

**Covered set:** reclaiming / pruning **superseded spec versions**, **orphaned validator-results**, and
**superseded ledger entries** from `.mission/`. This op is **BOUND to an ARCHIVE-BEFORE-PRUNE invariant**: it
**refuses unless** —

1. **(i) the target is provably superseded / orphaned** (mechanically: superseded by a later entry, or no
   longer referenced by the current spec/manifest chain) — not merely "old";
2. **(ii) an archive copy is written to an archive store FIRST** — the sealed bytes are **RELOCATED**, then
   removed from the live store, so the relocation precedes (and gates) the removal;
3. **(iii) the reclaim is recorded as a ledger entry citing what was archived** (the target + its archive
   location), append-only.

**Reconciliation with ADR-030 (cited verbatim, not paraphrased).** ADR-030 rules: *"A completed mission seals
its **HISTORY**, not its **PRODUCT CODE**,"* and defines the sealed set as *"**Sealed (append-only; never
rewritten):** a completed mission's **history** — its ledger (`.mission/ledger/`), its completed-mission
record and `completed_at`, its lifecycle transitions, its inputs and accepted spec versions and the frozen
contract, and any reopen / re-closure / successor-chain entries. These are immutable records of what
happened."* This ADR holds that invariant by construction: **sealed history is RELOCATED to an archive store,
never destroyed** — ADR-030's **"append-only"** becomes **"append-only + archive-on-reclaim."** No sealed byte
becomes unrecoverable: a reclaim is a *move* (archive then drop-from-live), not a delete. **If
archive-before-prune cannot be guaranteed for a given target, the op refuses** — ADR-030's seal is never
traded for reclamation.

**Consequences.**

1. **A new enforcement surface is named: the operator/CLI layer.** Destructive lifecycle ops are gated where
   they are actually invoked (the CLI), distinct from — and in addition to — ADR-026's worker-capability
   gateway. The unscoped-purge class (an operator-invoked destructive op exceeding an unwritten scope) is
   the surface this layer closes.
2. **Relationship to ADR-026 — sibling tiers, different layers.** ADR-026 = **worker DENY** (destruction is
   not a worker capability); ADR-041 = **operator GATED-PERMIT** (destruction is a *wanted* operator op,
   permitted only bounded + recorded + recoverable). ADR-026 is unchanged; this ADR is its destructive-tier
   counterpart in the same family, self-registered per ADR-033.
3. **ADR-030 holds, restated.** "Append-only + archive-on-reclaim": the sealed-history guarantee is preserved
   as relocation, never destruction.
4. **The constructive/destructive CLI symmetry is completed.** The lifecycle CLI delivered the constructive lifecycle
   commands; this ADR is the doctrinal gate for the destructive counterpart commands (a future build seam).
5. **Deferred — explicitly out of scope (recorded so it is not silent):** `shell.exec.*` / the C2
   sandbox-egress layer (a separate future ADR per ADR-026 Decision 3 — egress is not this layer);
   force-push (egress, stays denied); and workflow history-rewriting subcommands (`rebase / merge /
   cherry-pick / checkout / switch / restore / stash`) — not the unscoped-purge class, deferred unless a concrete
   trigger appears.

## Alternatives considered

- **(a) Extend ADR-026's denylist to the operator layer (deny operator destructive ops too).** Rejected:
  denial blocks a **wanted** op — the candidate trigger is precisely that a mission *sometimes needs* to
  reclaim or prune mission state. The operator/CLI layer needs **gated permission**, not prohibition; a
  denylist here would force the unscoped-purge pattern (do it out-of-band, unscoped) rather than prevent it.
- **(b) Two separate ADRs (object-store gating and mission-state reclaim split apart).** Rejected:
  **one mechanism** (bounded + recorded + recoverable, refuse-before-mutate) and **one
  motivating failure** (the unscoped purge) underpin both; splitting them would duplicate the doctrine and
  fracture a single capability-tier decision (the ADR-026-family one-decision-per-tier shape).
- **(c) Prune-in-place for Decision 2 (delete superseded `.mission/` state without archiving).** Rejected:
  it **violates ADR-030** — a sealed-history byte would become unrecoverable. Archive-before-prune is what
  lets reclamation coexist with the seal; in-place prune trades the seal away.

## Invariance check

- **No schema change.** This ADR rules on a gating layer and a reclaim invariant; it adds no state, field, or
  enum. `Mission`, `Amendment`, `ValidatorResult`, and the §7 Ledger schema are untouched. The doctrine is
  recorded as this ADR plus one `type: decision`, `scope: framework` ledger entry — no new artifact surface.
- **ADR-026 unchanged.** The worker capability map / allowlists / `shell.exec.*` prohibition are not altered;
  this ADR adds a sibling layer, it does not re-decide the worker layer.
- **ADR-030 preserved.** Sealed history stays append-only; archive-on-reclaim is relocation, never deletion.
- **Topology scope.** Local Orchestrator Mode lifecycle doctrine, consistent with ADR-026/030/031; it does
  not change Hosted Autonomous Mode runtime behavior.
- **No code, no contract.** This ADR authors neither CLI code nor validation contract nor fixtures; those are
  the next seams it gates.

## References

- **ADR-026** (`adr-026-capability-model-v2-read-tier-vcs-commit-egress-defer.md`) — the capability family
  this ADR extends; Decision 2's excluded destructive subcommand set ("destruction stays an operator
  capability") and Decision 3's egress-deferral are the named-but-deferred tiers this ADR gates.
- **ADR-030** (`adr-030-mission-completion-seals-history-not-product-code.md`) — the append-only / sealed-
  history invariant Decision 2 reconciles with as "append-only + archive-on-reclaim."
- **ADR-033** — ADRs are standalone-canonical; resting-status rule S1 (this ADR rests at "Accepted").
- **ADR-029 / ADR-040** — the reopen edge + the meta-framework-routes-as-reopen ruling under which
  framework increments run in place under an existing mission UUID, F1 not triggered.
- The lifecycle CLI (`reopen / promote-contract / spec-bump / close-milestone / reclose /
  ledger-append`) — the constructive counterpart whose enforce-refusal shape (the `Assert-*` / `Test-*` readers) this
  ADR's gating mechanism mirrors.
- **The deferred destructive-op tier** — the
  destructive-op gating ADR-026 left as a future increment, which this
  ADR discharges; the unscoped-purge class described in Context
  is the empirical grounding,
  and the lifecycle CLI above is the surface it gates.
