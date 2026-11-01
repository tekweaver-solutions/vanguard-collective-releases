# ADR-034 — Net-new in-place work about the SAME deliverable is delivered by reopen; the chaining test decides reopen-vs-successor

> **Status:** **Accepted** — operator-ruled framework doctrine (resting-status rule: S1 per ADR-033).
> This ADR rests at **"Accepted"** in the native S1 form (ADR-033) — it does **NOT** carry the
> abolished Framing-C *"Draft until folded into `local-orchestrator-mode.md`"* boilerplate; there is no
> fold-in step. This ADR follows the **framework-ADR path** (a standalone `adr-0NN-<slug>.md` under
> `tools/mission-cli/config/`, same family as ADR-019..033), **NOT** the mid-mission amendment ceremony. A
> mission amendment edits *this mission's* spec version chain; this ADR states a **framework doctrine** about
> which post-completion path (reopen vs successor mission) delivers a given unit of work, which every mission
> and both deployment topologies share — an operator-ratified framework decision, not a `mission amend
> approve`.
>
> **Drafted to resolve** a framework contradiction found in net-new extension work and
> traced through the ADR corpus's own history: the corpus simultaneously
> pointed net-new successor work (e.g. an agent layer added to a completed product) at **two** post-completion
> paths. **ADR-029** built the `Complete → Reworking` *reopen* edge (titled "corrective increment");
> **ADR-030** introduced a *successor-mission* label for "genuinely new extension work"; an earlier
> advisory note named *reopen* before the successor category existed; and **ADR-031 F1** left the
> `.mission/` restructure that any successor mission would need **deferred to an unwritten ADR** — so the
> successor path was simultaneously *labeled* for net-new work and *structurally unbuilt*. The operator rules
> in favor of **reopen for net-new in-place work about the same deliverable**, decided by ADR-029's
> **chaining test**, and records the reconciliation here so the corpus is coherent and later
> extension work proceeds on resolved doctrine.

---

**Decision (operator-ruled doctrine).**

1. **The chaining test decides reopen-vs-successor — NOT corrective-vs-net-new scope.** The question "does
   post-completion work re-enter the existing mission (reopen) or charter a new one (successor mission)?" is
   answered by ADR-029's own rationale: **is the new work *about the same deliverable*?**
   - **YES — about the same deliverable** (it extends the product the mission produced, and must chain to that
     deliverable's contract / ledger / validator-result history): it is delivered by **REOPEN** (ADR-029
     `Complete → Reworking → Complete`), under the **same mission UUID**, audit-chained to the prior
     completion. This holds **whether the increment is corrective OR genuinely net-new extension.** Net-new
     scope does **not** force a successor mission.
   - **NO — a genuinely separate / orphaned deliverable** (it does not chain to, and is not *about*, the
     existing deliverable): it is a **successor mission** — which remains **blocked pending the ADR-031 F1
     restructure** (see Decision 5).
   - The corrective-vs-net-new distinction is a **scope descriptor**, not the routing criterion. The routing
     criterion is **chaining** ("same deliverable → chain to its ledger").

2. **Net-new extension about the same deliverable is delivered by reopen.** Building a new capability *onto*
   an existing completed deliverable — extending the same product the organization continues to operate — is
   **same-deliverable work** and is delivered by reopening the mission that produced it. This is the
   conformant path; it is not a stretch, an exception, or a degenerate reading of ADR-029. It is the direct
   consequence of the chaining test (Decision 1) applied to net-new-but-same-deliverable scope.

3. **Reconciliation of ADR-030 (clarifies its taxonomy's meaning; does NOT rewrite its body).** ADR-030's
   *"successor mission"* term — *"Whether the next increment is a reopen of the same mission (corrective work
   on the same deliverable …) or a successor mission (genuinely new extension work building on the product),
   it extends the product by modifying the product source directly"* — is a **SCOPE descriptor, not an
   identity mandate.** ADR-030 **never required** net-new work to take a separate `.mission/` identity (a new
   UUID / spec chain / ledger); it discusses no such identity for the successor case. ADR-030's **core
   doctrine is unchanged and reaffirmed**: a completed mission seals HISTORY, not PRODUCT CODE — successor
   work modifies the product **in place**, never by a parallel shadow tree, and that holds for **both** the
   reopen and successor-mission paths. ADR-034 clarifies that the "successor mission = net-new" wording must
   **not** be read as "net-new MUST be a separate mission" — that misreading (which treated a scope label as
   a structural requirement) is what triggered this contradiction. **ADR-030's body is not edited; ADR-034
   states the authoritative reading of its taxonomy.**

4. **Reconciliation of ADR-029 (clarifies its scope reading; does NOT rewrite its body).** ADR-029's reopen
   edge — though titled and exemplified as a *"corrective increment"* — **covers net-new extension work about
   the same deliverable**, grounded in ADR-029's **own** stated rationale for rejecting the successor-mission
   alternative: *"a new mission orphans the original mission's contract/ledger/validator-result chain — the
   corrective work is about the same deliverable and must chain to it."* That rationale is a **chaining**
   argument, not a corrective-only restriction: any work *about the same deliverable* — corrective or net-new
   — has the same must-chain property and the same orphaning risk if split off. ADR-034 reads ADR-029's scope
   accordingly: `Complete → Reworking` is the home for **all** same-deliverable post-completion increments.
   **ADR-029's body is not edited; ADR-034 states the authoritative scope reading.**

5. **Successor-mission stays cleanly deferred (ADR-031 F1 unchanged).** The successor-mission path — for
   work on a **genuinely separate deliverable** that should *not* chain to the existing mission — **still
   requires the multi-mission `.mission/` restructure ADR-031 F1 deferred** (per-mission namespacing, or
   archive-on-close so the sealed history of all missions co-exists). That restructure remains **UNBUILT and
   out of scope here.** ADR-034 does **not** design it, does **not** lift the deferral, and records that
   successor-mission remains **blocked pending that separate ADR.** Direction R (reopen) is chosen for the
   present need precisely because it is **both conformant (Decision 1–2) and unblocked**, whereas the
   successor path is doctrinally available only after F1 is resolved.

6. **Reopen was the earlier advisory instinct; ADR-034 formalizes it (supersedes the informal framing).**
   An advisory note that predates the successor-mission category named a `Complete → Reworking (or Amending)`
   re-entry as the durable answer to post-completion work, and called follow-on extension work
   the work such a re-entry would deliver — written **before** the
   successor-mission category existed (ADR-030). ADR-034 **confirms that the reopen instinct was
   correct for same-deliverable work** and **formalizes WHY**: the chaining test (Decision 1). The note used
   "successor work" descriptively (follow-on work) and reopen as the mechanism because reopen was then the
   only mechanism; ADR-034 is the **ratified doctrine** that formalizes that informal framing.
   An advisory note is not an ADR; ADR-034 supersedes its
   informal framing by stating the formal rule.

**Application example (states doctrine; does NOT perform a reopen or charter).** An agent layer added to an
already-completed product — an extension of that same deliverable — is, per the
chaining test, **about the same deliverable** (the agent layer of the same product, not an
orphaned separate product). It is therefore delivered by **reopening the mission that produced the deliverable
via ADR-029 `Complete → Reworking`**, chaining to that mission's existing ledger under the same UUID — **not**
by chartering a successor mission. ADR-034 states this doctrine; any such reopen and its charter are a
**later seam** (on this resolved doctrine) and are **not performed here.**

**Reopen execution mechanics for the later charter seam (informational; NOT performed here).** Per ADR-031 F3,
lifecycle transitions past `Executing` have **no CLI tooling**; the `Complete → Reworking` reopen is a
**manual `mission.yaml` `state` edit** plus a **hand-authored ledger entry** (`type: decision`, `scope:
framework`) recording (a) the reopen reason, (b) the SHA / `completed_at` of the completion being re-entered,
and (c) the scope of the corrective/extension increment (per ADR-029). Re-closure updates `completed_at` and
chains to the original completion. A full `Complete → Reworking →
Complete` cycle is therefore a reopen entry
plus a re-closure entry, each a `type: decision` ledger entry,
whether the increment is corrective or net-new.
ADR-034 records this so the charter seam knows the mechanics; it performs none of them.

**Why this is forced by the principles / the grounded history.**

- **The chaining test is ADR-029's own logic.** ADR-029 rejected the successor-mission alternative because a
  new mission *orphans the deliverable's contract/ledger/validation chain*. That is a property of **same-vs-
  separate deliverable**, not of corrective-vs-net-new. Reading ADR-029 by its own rationale yields the
  chaining test, and the chaining test routes same-deliverable net-new work to reopen.
- **§2.7 — contract-before-code governs HOW the product changes, not WHETHER it may, nor by which ledger.**
  ADR-030 already established that the discipline (not a prohibition) protects the product. Extending that:
  *which* mission identity the work chains to is decided by what the work is *about*, so that the audit chain
  stays coherent — same deliverable, same chain.
- **§14.3 — replayability.** Replayability is a property of **history being append-only and coherent.**
  Same-deliverable work chained into one mission's ledger keeps a single coherent replayable history;
  splitting same-deliverable work into a fresh, orphaned mission would fragment the very chain replayability
  depends on. The chaining test protects replayability.
- **Grounded history (the ADR corpus).** The advisory framing is the oldest and pointed at reopen; ADR-029
  was built to satisfy it; ADR-030's successor label was newest and never mandated a separate
  identity; ADR-031 F1's "block" is a soft undefined convention, not a hard schema lock. The history shows
  reopen was always the intended path for this work; ADR-034 formalizes why (the chaining test) rather than
  inventing a new rule.

**Alternative considered.** Route a same-deliverable extension (and net-new work generally) through a **successor mission** per
ADR-030's label. **Rejected:** (a) it would require building the ADR-031 F1 multi-mission restructure first
(unbuilt, deferred, out of scope) — blocking work that has a conformant unblocked path; (b) it would
**orphan** the extension from the deliverable's contract/ledger/validation chain it extends —
the exact orphaning ADR-029 and ADR-030 both reject; (c) it rests on reading ADR-030's "successor mission"
**scope label** as an **identity mandate**, which ADR-030's text does not support. The successor-mission path
remains correct **only** for a genuinely separate deliverable, and **only** after F1 is resolved.

**Invariance check.**

- **No schema change.** This ADR states doctrine about *which path delivers a unit of work*; it adds no
  state, field, or enum. `Mission` (and its `state` enum, `expanded-schemas.md`), `Amendment`,
  `ValidatorResult`, and the §7 Ledger schema are untouched. The reopen path it points to (ADR-029) already
  exists; the deferred successor path (ADR-031 F1) is unchanged. The doctrine is recorded as this ADR plus
  one `type: decision`, `scope: framework` ledger entry — no new artifact surface.
- **No body rewrite of cited ADRs / advisory.** ADR-029, ADR-030, ADR-031, and the advisory note are
  **cited and reconciled by stated reading**, not edited. ADR-034 is the authoritative statement of how the
  taxonomy is read; the cited bodies remain byte-unchanged.
- **Consistent with ADR-029 / 030 / 031 / 033.** ADR-029 supplies the reopen mechanism; ADR-030 supplies the
  in-place, no-shadow-tree doctrine (reaffirmed for both paths); ADR-031 supplies the successor-in-place
  governing model and the F1 deferral (unchanged); ADR-033 supplies the S1 resting-status form this ADR uses.
  None is changed.
- **Topology scope.** Like ADR-029/030/031, this concerns the shared Section-7 lifecycle and the Local
  Orchestrator Mode mission↔monorepo binding; the chaining-test doctrine holds for both topologies (it
  concerns which mission identity work chains to, which both topologies share).

**Reference.**
ADR-029 (`Complete → Reworking` reopen edge + the chaining rationale this ADR generalizes);
ADR-030 (completion seals history not product code; the "successor mission" scope label clarified here);
ADR-031 (one-active / successor-in-place governing model; F1 successor restructure deferral — unchanged);
ADR-033 (standalone-canonical + S1 resting-status form);
`mission.yaml` (`id`
`<mission-id>`, the identity a `Complete → Reworking → Complete` cycle chains to under these
mechanics); multi-agent-framework-design-brief.md §2.4 (adversarial validation), §2.7 (contract-before-code /
two-drifts-two-fixes), §14.3 (replayability) as the forcing principles.
