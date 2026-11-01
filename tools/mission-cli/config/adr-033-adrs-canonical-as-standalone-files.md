# ADR-033 — ADRs are canonical as standalone files; `local-orchestrator-mode.md` is a reference overview (resolves the ADR source-of-truth contradiction)

> **Status:** **Accepted** — operator-ruled framework doctrine (direction: standalone-canonical; resting-status
> rule: S1). This ADR is the **first to use the S1 resting form natively**: it rests at
> **"Accepted"**, *not* the ADR-019..032 family's prior Status boilerplate (*"Draft until folded into
> `local-orchestrator-mode.md`, the family's only promotion"*) — that boilerplate asserts the very Framing-C
> convention this ADR abolishes, so ADR-033 could not have rested in it without self-contradiction. The
> family-wide Draft→Accepted relabel of the other standalone ADRs is **b3** work, not done here.
>
> This ADR follows the **framework-ADR path** (a standalone `adr-0NN-<slug>.md` under
> `tools/mission-cli/config/`, same family as ADR-019..032), **NOT** the mid-mission amendment ceremony. It
> states a **framework doctrine** about where ADRs canonically live, which every mission and both deployment
> topologies share — an operator-ratified framework decision, not a `mission amend approve`.
>
> **Drafted to resolve** the ADR source-of-truth contradiction the two-store audits surfaced: the framework
> simultaneously asserted three mutually-inconsistent framings about where ADRs canonically live (see
> "Supersedes" below). The operator rules in favor of **standalone-canonical**. This ADR records the
> corrected lifecycle in **one canonical place** so future readers find the rule here instead of
> re-inferring it from headers — re-inference being how the drift started.

---

**Decision (operator-ruled doctrine).**

1. **Standalone is canonical.** A standalone `adr-0NN-<slug>.md` file under the ADR home
   (`tools/mission-cli/config/`, where ADR-019..032 already live) is the **single, authoritative, canonical
   copy** of each ADR decision. There is exactly **one** canonical copy of any ADR — the standalone file.

2. **The doc references, it does not own.** `local-orchestrator-mode.md` is a **topology / design-overview**
   document that **references** the standalone ADRs by number. It does **not** own, host, or duplicate ADR
   content. Its §3 ("Architecture Decisions") becomes a **reference list** pointing to the standalone files,
   not an inline ADR store.

3. **There is NO fold-in promotion step.** The prior **Framing-C** convention — *"a standalone ADR is a
   Draft that is promoted by folding it into `local-orchestrator-mode.md`; folding is the family's only
   promotion"* — is **superseded and abolished.** A standalone ADR is canonical **where it lives**, from the
   moment it is recorded. No ADR is ever "folded into the doc"; the doc never becomes a second store.

4. **The standalone family is the home for ALL ADRs, including ADR-001..018.** The 18 ADRs currently inline
   in `local-orchestrator-mode.md` §3 are **not** an exception — they are folded-only by historical accident
   (the doc predated the standalone convention). They are to be **extracted out** to standalone files so that
   every ADR-001..033 obeys one rule. (This ratifies, as executed doctrine, what the corpus already pointed
   to — see "Basis" below.)

**Basis (this ADR ratifies existing, convergent signals — it is not a new direction).**

- **§12 of `local-orchestrator-mode.md`** ("Documentation Updates Required", item 2) already recommends
  *"a `docs/adr/` directory in the repo"* for ADR-001..018 — the doc's own author anticipated extraction.
- **ADR-027** (dispatch write-time validation) names *"the ADR-extraction mission that resolves the
  canonical-home split"* as the fix for its "phantom promotion target" defect — extraction, not folding.
- **ADR-028's relocation precedent**: when an ADR was placed
  inline in the doc, it was **relocated back out to a standalone file** with the rationale *"Convention
  wins … ADR-019+ = standalone."* The only under-pressure ruling already went to standalone.
- **Zero fold-ins** have occurred across ADR-019..032; the de-facto home has
  always been standalone. This ADR makes the rule match the reality.

**Supersedes / corrects (the three contradictory framings).**

- **Framing A** — `local-orchestrator-mode.md` §1 status *"Design captured from conversation. Awaiting
  promotion into ADRs."* Superseded: the design is not "awaiting promotion into ADRs"; the §3 entries **are**
  ADRs and become standalone files. The §1 status is to be reworded to "this doc references the standalone
  ADRs."
- **Framing B** — the STOPGAP banner's *"planned Option-1 ADR-extraction mission: ADR-001..018 become
  standalone … this file is reduced to a pure topology-overview doc."* This ADR makes B's mechanism the
  **ratified end-state**, so the banner's "planned/pending" framing is retired (the plan is now doctrine, to
  be executed by b1).
- **Framing C** — the Framing-C language in every standalone header (ADR-019..032) **including ADR-030 and
  ADR-031** (*"Draft until folded into `local-orchestrator-mode.md`, the family's only promotion"*).
  Superseded by Decision 3. These headers are to be reworded (b2) and ADR-030/031's status basis re-stated
  (b3) once the resting-status rule is ruled.

**Conforming edits this ADR authorizes (named here; NOT executed by this ADR — they are seams b1/b2/b3).**

- **b1 (mechanical extraction).** Extract ADR-001..018 from `local-orchestrator-mode.md` §3 into standalone
  `adr-0NN-<slug>.md` files (ADR-007 "Bootstrap" keeps id 007 — the slot is free post-Fix-1; ADR-009 extracts
  as a superseded-stub → ADR-012); author a Status header on each; fix the two positional references (the
  banner's *"(inline, §3)"* and §12's *"as captured in Section 3 above"*); convert §3 to a reference list.
- **b2 (convention reword).** Reword the ~13 standalone headers carrying Framing-C language (and ADR-019's
  *"## Promotion path"* section) to state standalone-canonical / no-fold-in.
- **b3 (doctrine + framing, ruling-sensitive).** Re-state ADR-030/031's Status basis under the new lifecycle
  and retire/reconcile the banner + §1 status. **b3 depends on the resting-status ruling below** and does not
  run until it is made.

ADR-033 is authored and operator-approved **first**; b1/b2/b3 are the mechanical work that **conforms** to it.

**Resting status (rule S1 — "Accepted").**

Under the prior convention, an ADR rested at "Draft because folding hadn't happened yet"
(per the ADR-030 status reconciliation). This ADR abolishes folding, so
that rationale no longer holds. **The operator rules S1:**

> **An ADR rests at status "Accepted" once operator-ruled.** Under standalone-canonical, the recorded
> standalone file **IS** the decision; there is no fold-in step for a "Draft" status to be pending on. This
> **supersedes the prior "Draft-until-folded" resting state** (the ADR-030 status-reconciliation ledger
> entry, now itself superseded by this rule). The status vocabulary is **Accepted** (operator-ruled and
> recorded) and **Superseded** (when a later ADR replaces it; e.g. ADR-009 → ADR-012). A pre-ruling proposal
> may carry "Draft/Proposed", but the **resting** state of a ruled ADR is **Accepted**.

ADR-033 itself is the first to rest in this form (see Status, top). The family-wide Draft→Accepted relabel
of the other standalone ADRs (019..032) and the ADR-030/031 doctrinal-header re-statement are **b3**.

**Alternatives considered (the rejected source-of-truth directions).**

- **(a) Doc-canonical** — make `local-orchestrator-mode.md` §3 the home and **fold the 14 standalones
  (019..032) in.** Rejected by the operator ruling: it reverses the de-facto standalone practice and
  the ADR-028 "convention wins" precedent, requires performing the fold that has **never once** happened in
  the corpus, and re-creates the dual-role (design-summary + ADR store) wart. (It would, however, keep
  ADR-030/031's wording valid — see Tradeoff.)
- **(c) One-way promotion** — standalone drafts fold in, then the standalone is **deleted** after folding.
  Rejected: same fold direction as (a) against the same practice/precedent, and it still requires never-done
  folds plus tooling against half-folded states. (b) standalone-canonical is the lowest rule/reality gap.

**Tradeoff accepted.** Standalone-canonical is the **most text-editing** of the three directions: it extracts
18 inline ADRs out, rewords ~13 headers, and — uniquely — **rewrites recent doctrine (ADR-030/031) and
reopens the ADR-030 status-reconciliation** (the resting-status question above). (a)/(c) would touch ~half as
many files and keep ADR-030/031 verbatim. The operator accepts the ~2× edit cost and the doctrine reopen in
exchange for the **lowest gap between the rule and what the framework actually does** — and because the
corpus already pointed here (§12, ADR-027, ADR-028). The edits are largely mechanical (b1/b2) with one
ruling-sensitive seam (b3).

**Invariance check.**

- **No schema change.** This ADR rules on where ADRs canonically live; it adds no state, field, or enum.
  `expanded-schemas.md` and the `Mission` schema are untouched.
- **No content change to any ADR decision.** Extraction (b1) moves ADR text verbatim; it does not alter what
  any ADR decides. The Fix-1 ADR-007→032 renumber and the ADR-009→012 supersession are unaffected.
- **Sealed history untouched.** Per ADR-030, the ledger/amendments/spec are append-only; b1/b2/b3 touch
  living framework docs only, never sealed mission history.
- **Topology scope.** Framework-wide documentation doctrine; it does not change either deployment topology's
  runtime behavior.

**References.** The two-store audits that surfaced the
contradiction (see Status);
the option-(b) impact analysis (see Tradeoff);
`local-orchestrator-mode.md` §1 (Framing A), STOPGAP banner (Framing B), §3 (the 18 inline ADRs), §12 item 2
(the `docs/adr/` recommendation); ADR-027 ("the ADR-extraction mission"); the ADR-028 relocation precedent
("convention wins"); ADR-030 & ADR-031 (the doctrine whose Status basis b3
re-states); the ADR-030 status reconciliation (the prior "Draft = resting
state" ruling this ADR reopens); the Fix-1 collision-renumber
(of the standalone ADR-007 to ADR-032).
