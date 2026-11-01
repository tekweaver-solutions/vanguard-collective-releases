# ADR-040 — Meta-framework rework of the mission's OWN machinery routes as a reopen (same mission); ADR-034's chaining test extends to non-deliverable infrastructure work

> **Status:** **Accepted** — operator-ratified framework doctrine; resting-status rule S1 per ADR-033.
> Rests at **"Accepted"** in the native S1 form — no abolished Framing-C boilerplate; no
> fold-in step. **Standalone-canonical in `tools/mission-cli/config/`** (same family + home as ADR-019..039)
> per ADR-033; the standalone file IS the decision.
>
> **Nature & path.** A **framework lifecycle-routing decision** — *which post-completion path (reopen vs
> successor mission) delivers work that reworks the mission's OWN machinery, rather than the product the
> mission produced*. Authored when a reopen of the mission to build its own lifecycle CLI
> (a Reworking episode) recorded this
> routing as operator-ruled **pending doctrinal ratification** — this ADR is that ratification. **Extends**
> ADR-034 (the reopen-vs-successor chaining test). Authored as a standalone framework-family ADR with a
> `type: decision`, `scope: framework` ledger entry per the operator's ruling — **NOT** a mission-spec
> amendment: **changes no spec version**, adds no schema/field/enum, and **writes no product/framework code
> and no validation contract** (the lifecycle CLI's contract + code are the NEXT seams, gated by this ADR).

## Context

**ADR-034** settled reopen-vs-successor routing with a **chaining test**: *"is the new work about the same
deliverable?"* — YES (it extends the product the mission produced and chains to that deliverable's
contract / ledger / validator-result history) → **REOPEN** under the same UUID; NO (a genuinely separate /
orphaned deliverable) → **successor mission**, which "remains **blocked pending the ADR-031 F1 restructure**"
(`adr-034…md:32-40`). ADR-034 was written with the **product deliverable** in mind (its worked example is
an agent layer added to a product component the mission delivered).

**The mission lifecycle CLI (ADR-031 F3)** is a different class of work: it reworks the mission's
**own machinery** (`tools/mission-cli/` + the `.mission/` lifecycle ceremony), **not** the product the
mission delivers. Under a *strict* reading of ADR-034 ("about the **product** deliverable?"),
meta-framework work answers NO → it would route to a successor mission → blocked behind the **unbuilt**
ADR-031 F1 multi-mission restructure. That outcome is wrong on the merits: meta-framework work is **not an
orphaned deliverable** — it is *this* mission reworking the very framework it runs under, and its artifacts
land in *this* mission's `.mission/` chain.

The reopen charter recorded the operator's reopen ruling and **flagged it as an extension of ADR-034
needing doctrinal ratification** rather than letting an unratified routing decision sit load-bearing.

## Decision

**Meta-framework / infrastructure work that reworks the mission's OWN machinery — `tools/mission-cli/` (the
framework tooling) and the `.mission/` lifecycle ceremony — routes as a REOPEN (same-mission rework, same
mission UUID), NOT a successor mission.**

The routing is grounded in **ADR-034's own chaining criterion**, applied at the **artifact level**: the
increment's **feature + contract assertions + ValidatorResults chain to THIS mission's `.mission/`
ledger / contract / validator-result history** (e.g. a lifecycle-CLI increment mints its `F-NNN` feature, its `A-NNN` assertions, and its
ValidatorResults into the same single `.mission/` chain). "Same deliverable → chain to its ledger" is
**satisfied at the artifact level** even though the *subject* of the work is the framework, not the product.
This **extends** ADR-034's chaining test — written for the product deliverable — to **non-deliverable
meta-framework work**, by reading "chains to this mission's history" as the operative test (which it already
was) rather than "is literally about the product."

**Consequences:**

1. **Lifecycle-tooling rework proceeds as a reopen** under the same UUID — as the reopen charter enacted;
   this ADR ratifies its routing basis.
2. **ADR-031 F1 (the single-mission `.mission/` restructure) is NOT triggered** by meta-framework rework,
   because such work does not charter a successor mission — it chains into the existing single `.mission/`.
3. **Future meta-framework increments route the same way** (a reopen of the mission whose machinery they
   rework), without re-litigation — the same role ADR-034's "ROUTING INHERITED" plays for product work.
4. **The successor-mission path (and its ADR-031 F1 prerequisite) remains reserved** for genuinely separate /
   orphaned deliverables that do **not** chain to an existing mission — unchanged by this ADR.

**Boundary (what this ADR does NOT do):** it does **not** alter ADR-034's product-deliverable routing; it
does **not** build the multi-mission restructure (F1 stays deferred); and it does **not** author the lifecycle CLI's
command surface, contract, or code — those are the next seams, gated by this ADR. It records **routing
doctrine only**.

## Alternatives considered

- **Route the lifecycle CLI as a successor mission (strict ADR-034).** Rejected: it forces the unbuilt ADR-031 F1
  restructure as a prerequisite for *every* framework-tooling improvement, and mischaracterizes
  rework-of-own-machinery as an orphaned deliverable. The artifacts chain to this mission; that is what the
  chaining test actually measures.
- **Leave the routing as a bare per-seam operator ruling (no ADR).** Rejected: the reopen charter
  explicitly flagged it for ratification so an extension of a load-bearing routing ADR is recorded
  doctrinally, not left implicit — the same discipline ADR-034 itself applied to the reopen-vs-successor
  reconciliation.
- **Amend ADR-034 in place.** Rejected per ADR-033 (standalone-canonical ADRs; the new decision is its own
  standalone file that extends, and cross-references, the prior one) — consistent with how ADR-035..039
  extended earlier chains without rewriting them.

## References

- **ADR-034** — net-new in-place work about the same deliverable is delivered by reopen; the chaining test
  (the rule extended here).
- **ADR-029** — the `Complete → Reworking → Complete` reopen edge (the mechanism this routing selects).
- **ADR-031 F1 / F3** — F1 (the deferred multi-mission restructure, not triggered here); F3 (the lifecycle-
  tooling finding the lifecycle CLI closes).
- **ADR-030** — mission completion seals history, not product/framework code (in-place evolution).
- **ADR-033** — ADRs are standalone-canonical; resting-status rule S1.
- **Ledger:** the reopen charter entry (the reopen
  charter that recorded this routing pending ratification);
  and the ADR-034 chaining-test decision entry (the chaining test extended).
