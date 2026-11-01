# ADR-030 — Mission completion seals HISTORY, not PRODUCT CODE

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy per
> ADR-033 (standalone-canonical; an ADR rests at "Accepted" once operator-ruled — the S1 rule; there is no
> fold-into-`local-orchestrator-mode.md` step). This ADR follows the **framework-ADR path** (a standalone
> `adr-0NN-<slug>.md` under `tools/mission-cli/config/`), **NOT** the mid-mission amendment ceremony. A
> mission amendment edits *this mission's* spec version chain; this ADR states a **framework doctrine** about
> what "Complete" means, which every mission (and both deployment topologies) shares. It is therefore an
> operator-ratified framework decision, not a `mission amend approve`.
>
> **Drafted to make explicit** the mission/product boundary that **ADR-029** (the
> `Complete → Reworking` re-entry edge, the durable
> answer to 'a defect found after done') and the premise that a mission's output is a
> **long-lived product** both *rely on* but neither states as doctrine. The forward
> purpose is to **foreclose an erroneous inference** — "a mission is Complete, therefore
> the product code it produced is now immutable" — which does **not** follow, and which,
> left unstated, invites a successor effort to build a parallel shadow tree beside the
> product source rather than extend the product in place.

---

**Decision.** A completed mission seals its **HISTORY**, not its **PRODUCT CODE**.

> **SEALED = mission history. LIVING = product code.**

Concretely:

- **Sealed (append-only; never rewritten):** a completed mission's **history** — its
  ledger (`.mission/ledger/`), its completed-mission record and `completed_at`, its
  lifecycle transitions, its inputs and accepted spec versions and the frozen contract,
  and any reopen / re-closure / successor-chain entries. These are immutable *records of
  what happened*. (This is what the framework already means by "inputs are immutable once
  design starts", "spec versions are immutable", and "the contract is frozen before
  execution" — see *Clarification* below.)
- **Living (modifiable; the normal codebase):** the **product code** the mission produced
  (`src/`, `docker/`, `compose.yaml`, and every other deliverable
  artifact). "Mission Complete" records that **a unit of WORK is done**; it does **not**
  make the **product** immutable. The product is the living codebase the organization
  continues to operate and evolve.
- **Successor work modifies the product IN PLACE, under the normal discipline.** Whether
  the next increment is a **reopen of the same mission** (corrective work on the same
  deliverable — ADR-029's `Reworking`) or a **successor mission** (genuinely new
  extension work building on the product), it **extends the product by modifying the
  product source directly**, governed by the framework's standard discipline:
  contract-before-code (§2.7), pre-committed adversarial / role-separated validation
  (§2.4), incremental-commit discipline (ADR-021), and the per-milestone review. It does
  **NOT** proceed by building a parallel shadow tree alongside the product source to avoid
  touching it. Avoiding the product source is not a way to "respect" a completed mission;
  the completed mission's history is untouched no matter how much the product evolves,
  because history is a separate, sealed record.

**Why this is forced by the principles.**

- **The ADR-029 precedent (in-place post-completion modification is the established
  pattern).** ADR-029 added the `Complete → Reworking → Complete` edge precisely so a
  defect found *after* `Complete` is fixed **in the product, in place**, with the
  correction audit-chained in the one coherent `.mission/` ledger. A reopen pass under that edge
  modifies a completed product's source directly and re-closes — so
  completion never freezes the code. This ADR names the general doctrine ADR-029 enacted in
  the specific (corrective) case.
- **§14.3 — replayability.** Replayability requires that every state be reconstructable
  from committed artifacts. That is a property of **history** being append-only (sealed),
  **not** of the product code being frozen — git records every product change, so an
  evolving product remains fully replayable. Freezing the product code would buy
  replayability nothing the sealed history doesn't already provide, while making the
  living system un-maintainable.
- **§11.5 — completion is never automated (a recorded event about WORK).** "Complete" is
  a deliberate, operator-gated *event* recording that a unit of work met its bar. An event
  about work cannot, and does not, impose a permanent constraint on the code's future
  mutability — exactly as a "shipped v1" tag does not forbid v2 touching the same files.
- **§2.7 — contract-before-code governs HOW the product changes, not WHETHER it may.** The
  discipline that protects the product is "no edit without a contract first", applied to
  the next increment — not "no edit at all." Treating the product as frozen replaces a
  *discipline* (contract-before-code) with a *prohibition* (don't touch it), which the
  framework never imposed.

**Clarification (this ADR refines a reading; it supersedes no written rule).** No framework
document states that product *code* becomes immutable on completion. The framework's
existing immutability statements all concern **mission artifacts / history** —
`.mission/inputs/` "immutable once design starts", `.mission/spec/v*.yaml` "immutable spec
versions" (local-orchestrator-mode §5.1), and "the contract is frozen before execution"
(§2.7). Those are correct and remain in force; they are precisely the *sealed history* half
of this ADR. This ADR makes the boundary **explicit** so the (erroneous) inference
"completion ⇒ product immutable" cannot be drawn from them, and affirms that
the "**long-lived product**" framing is the framework's actual stance.

**Alternative considered.** Treat the product as frozen at completion and require successor
work to build alongside it (a parallel tree) rather than modify it. **Rejected:** (a) it
contradicts the ADR-029 precedent and this ADR's explicit long-lived-product
framing; (b) it **orphans** the new work from the product's history, contract surface, and
test/validation harness — the successor code cannot chain to the deliverable it extends; (c)
it forces **duplication** of the product's structure and invites drift between the shadow
tree and the real product; (d) it confuses *not rewriting history* (correct) with *not
touching code* (an over-reach the framework never required). The sealed history already
guarantees the completed unit of work is faithfully recorded; nothing about evolving the
product violates that guarantee.

**Invariance check.**

- **No schema change.** This is doctrine about the *meaning* of the `Complete` state, not a
  new state, field, or enum. `Mission`, `Amendment`, `ValidatorResult`, and the §7 Ledger
  schema are untouched. The doctrine is recorded as this ADR plus one `type: decision`,
  `scope: framework` ledger entry — no new artifact surface.
- **Consistent with ADR-029 and ADR-028.** ADR-029 supplies the in-place-modification
  mechanism for the reopen path; ADR-028's `scope: framework` is the correct subject axis
  for recording this cross-mission doctrine. Neither is changed.
- **Topology-neutral.** The doctrine holds for both the hosted and local orchestration
  topologies; it concerns what "Complete" means, which the shared Section-7 lifecycle owns.

**Reference.** ADR-029 (`Complete → Reworking` re-entry — the in-place post-completion
modification precedent this generalizes); ADR-021 (incremental-commit discipline for the
corrective/extension increment); ADR-028 (ledger `scope` subject axis — `framework`);
local-orchestrator-mode.md §5.1 (immutable inputs/spec — the
sealed-history half), §11.5 (completion never automated),
§14.3 (replayability);
multi-agent-framework-design-brief.md §2.4 (adversarial validation), §2.7 (contract-before-
code / two-drifts-two-fixes), §14.3 (replayability) as the forcing principles.
