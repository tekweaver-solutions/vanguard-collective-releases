# ADR-025 — Production-support documentation as a design-stage deliverable

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** a design phase, after a client-review checkpoint surfaced production-support documentation as a missing design-stage deliverable that should ship to L1 support alongside the architecture.
>
> **Empirical grounding:** a mission's design phase can produce spec, contract, architecture, skills and tech-stack and still ship no production-support documentation, leaving L1 support with nothing to work from. Every software-engineering mission ships into production support, so the framework sets the production-support-docs-as-design-stage-deliverable convention once and every mission inherits it.

---

## Decision

The framework adopts **production-support documentation as a first-class design-stage deliverable**, with three sub-decisions:

### 1. The runbook is an explicit, reviewable design-stage deliverable

Each mission's design phase produces a **runbook** committed to `.mission/runbook/`, drafted by the designer from spec + architecture + tech-stack. The runbook is reviewed at the same gate as the architecture (per ADR-022) and the tech-stack (per ADR-024) — drafted at design time, refined in execution as workers encounter real failure modes, frozen at Phase 5 acceptance for the version under acceptance.

**Specifically:**

- One **runbook entry per container** in the architecture (per `containers.c4`). Container is the operational unit. Components are too fine-grained for L1; services aren't named architecturally.
- Each entry conforms to a **versioned schema** at `.mission/runbook/_schema.md`. Sections (operator-locked at MVP, designer's exact section names): **Purpose** (one paragraph), **Normal-state signals** (what `/health` returns when fine; key log signatures), **Common failure modes** (3-5 entries: symptom + likely cause + first-line response), **Restart procedure** (exact commands), **Escalation path** (who to contact, with role tag tying back to the notification routing taxonomy where one exists).
- A top-level **`INDEX.md`** lists every entry; orphan entries (no INDEX link) and missing entries (containers without an entry) both fail validation.
- A **`quickstart-L1.md`** page covers: how to check overall system health, where logs and traces live, the 3 most common situations and their first-line responses. This is the L1-first-five-minutes document.
- Format: **markdown**, committed under `.mission/runbook/` (new directory, parallel to `.mission/architecture/`).

### 2. Runbook entries are drafted by the designer and extended by execution-phase workers

At design time, the designer drafts every runbook entry from the spec + architecture + tech-stack. **Initial set of "common failure modes" is 3 per container as a starting point** — the designer reasons from architectural knowledge (this container depends on Postgres; if Postgres is down, the symptom is X; the response is Y) rather than from observed runtime failures. The designer cannot enumerate every failure mode at design time; the execution phase fills in real-world failures as workers encounter them.

**During execution:** workers add failure-mode entries when they encounter operational issues, following the same versioned schema. The runbook is "alive" during execution — failure-mode additions are normal commits, not amendments. **The runbook entry structure (the section names + the schema-as-versioned-artifact) is the contract; the failure-mode entries within it are mutable.** This parallels the architecture's "the views are the contract; the rendering is external" framing per ADR-022.

### 3. The runbook is a Phase 4.5 expansion (or new Phase 4.6)

ADR-022 established Phase 4.5 as the architecture-documentation pass. ADR-025 expands Phase 4.5 to include production-support documentation, at the designer's election: either as a single Phase 4.5 (architecture + runbook drafted in one pass) or as Phase 4.5 (architecture) + Phase 4.6 (runbook). **The framework precedent is one phase** — same gate, same artifact-discipline, same parser-validation pattern (the runbook's schema validation is the analog of the C4 parser-validation). The designer picks the organizational shape per mission; the deliverable contract is identical either way.

Phase 5 acceptance gate (per ADR-008, ADR-022, ADR-024, and now ADR-025) requires:
- All architecture artifacts validated.
- All tech-stack deliverables reconciled.
- **All runbook entries conform to the versioned schema; INDEX.md is complete; quickstart-L1.md exists.**

The `mission-spec-accept.ps1` script verifies all four gates (spec, architecture, tech-stack, runbook) before transitioning Mission.state to Executing.

---

## Alternatives considered

- **Skip production-support documentation entirely.** Status quo before this ADR; rejected for the same reasons ADR-022 rejected skipping architecture: a mission that ships into production without operator-support documentation hands every operational incident to the developer-who-built-it. The framework's value depends on operator-handoff being a clean artifact-mediated event, not a tribal-knowledge transfer. Drafting at design time costs ~1-2 commits per mission; the savings at every future production incident dwarf this.

- **Make runbook drafting an execution-phase responsibility.** Considered: a worker dispatched against the final integration milestone drafts the runbook based on the implemented system. Rejected because (a) the worker is feature-focused and runbook drafting is cross-cutting; (b) the worker doesn't know the L1 use cases the operator-handoff is designed for; (c) the design-time draft establishes the schema + INDEX structure, which executing workers extend — separating the structure-creation from the content-extension produces a cleaner artifact than a single late draft.

- **Hand-author the runbook outside the framework's deliverable discipline.** Workable but loses the artifact-portability, versioning, and reviewability properties. The runbook would become a side-document not pegged to a spec version, drifting from the system over time. Folding it into `.mission/` brings it under the same git-history + version-pin + accepted-snapshot regime as the spec.

- **Use a third-party runbook tool** (PagerDuty runbooks, Notion ops pages, Confluence). Rejected because (a) external tools introduce a dependency the framework doesn't otherwise have; (b) the runbook ages at the same cadence as the spec, so co-locating it with the spec is operationally honest; (c) markdown-in-git is the simplest viable shape, requires no integration, and is readable by any L1 with a text editor.

- **Make the runbook entry schema unversioned (just informal markdown conventions).** Rejected because the same drift-defense argument that motivated ADR-022's versioned views applies: a runbook with informal conventions drifts entry-to-entry, becomes harder to scan, and surprises L1 readers who expect consistency. The versioned schema artifact (`.mission/runbook/_schema.md`) is the analog of ADR-022's c4-syntax-as-source-of-truth pattern.

- **Bury the runbook inside `.mission/architecture/`.** Rejected because the runbook serves a distinct reader (L1 support during operational incidents) and has a distinct cadence (extended during execution as failures appear). Co-locating with architecture conflates these. A sibling directory is the cleaner shape.

---

## Tradeoff accepted

- **Mission scope grows by N runbook entries** where N is the container count. For a mission with ~14 containers, this is ~14 entries. Mitigated by the per-entry section structure being short: an entry at MVP is ~50-100 lines (one paragraph per section + 3 failure-mode entries).

- **The designer must reason about operational concerns** (what failures might occur; what restart procedures look like) at design time. Architecturally this is fine — the designer already reasons about the architecture's failure modes when drawing the deployment view. The runbook formalizes that reasoning as a separate, reviewable artifact. Designer effort: ~1-2 hours per mission for the scaffolding + first-pass entries.

- **Execution-phase workers gain a new artifact to maintain.** Adding a failure-mode entry when a real operational issue surfaces is a small commit; the discipline is identical to adding a ledger entry. Mitigated by the schema being committed (workers follow the existing structure, not invent one).

- **One more framework-acceptance-gate check.** The `mission-spec-accept.ps1` script now verifies four gates (spec, architecture, tech-stack, runbook) instead of three. Implementation cost: the new gate is a structural check (every container in `containers.c4` has an entry in `.mission/runbook/`; every entry conforms to the schema; INDEX.md is complete). Cheaper than the parser-validation already in ADR-022.

---

## Why this is forced by the framework's principles

- **"Two-drift-two-fixes" (brief §2.7).** Production-support drift (operator-handoff fails because L1 can't troubleshoot a component) is a real drift mode this ADR prevents at the design stage rather than catching it as a customer-incident escalation.

- **"Replayability" (brief §14.3).** A mission's runbook is part of the replay artifact set. A future operator (or a future Claude) reading the accepted spec sees not only the goal and the contract and the architecture but the exact failure-mode reasoning that informed the operational handover.

- **"Artifact discipline" (this framework's recurring theme).** Runbook entries join spec, contract, architecture, skills, tech-stack, and ADRs as committed, versioned, reviewable artifacts. No conversation-only operational knowledge survives a session boundary.

- **"Section 14.5 success criteria — operator-handoff is real, not theatrical."** Without production-support documentation, "operator handoff" is theater — the developer-who-built-it remains the only person who can run the system. The runbook is the artifact that makes the handoff substantive.

---

## Invariants preserved

**This is the test that ADR-025 extends rather than bends the framework.** Each of these is unchanged by this ADR:

- **All schemas in `expanded-schemas.md`.** The runbook is a committed-artifact convention (markdown under `.mission/runbook/` + a versioned schema at `_schema.md`), NOT a schema field on any existing artifact. `Mission`, `LivingSpec`, `Assertion`, etc. — every field, every constraint — unchanged.

- **The Section 4 role separation.** Drafting the runbook is the orchestrator role in batch-job mode (same role that drafts architecture per ADR-022), not a new role. Execution-phase extensions happen via worker dispatches as normal.

- **The Section 5 schema portability.** Runbook entries are markdown files; markdown is universal. The runbook moves between local-mode and hosted-mode deployments without re-encoding.

- **Section 14.6 model-class swappability.** Unaffected — runbook drafting is the designer role (orchestrator-thinking-partner model class), not a new class.

- **Section 9 drift defenses.** Runbook entries are versioned (git-tracked) and have a schema, so factual drift in operational docs is fought the same way as elsewhere — through the artifact store, not through longer in-agent contexts.

- **Section 11 touchpoint mapping.** No new touchpoints. The Phase 4.5 review (per ADR-022) absorbs the runbook review; no new operator-attention surface.

---

## Companion to ADR-022 and ADR-024

The framework's "design-stage deliverable" pattern is now established as a triad:

- **ADR-022:** Architecture is a design-stage deliverable (committed under `.mission/architecture/`).
- **ADR-024:** Tech-stack is a design-stage deliverable (committed under `.mission/spec/proposals/tech-stack-NNN.md`).
- **ADR-025 (this ADR):** Production-support documentation is a design-stage deliverable (committed under `.mission/runbook/`).

All three share the same shape:
1. Drafted at design time by the designer (orchestrator-thinking-partner).
2. Reviewed at a single design checkpoint (Phase 4.5 + tech-stack + runbook = one operator-attention pass).
3. Frozen at Phase 5 acceptance for the version under acceptance.
4. Refined via amendment post-acceptance (architecture via Docker viewer re-validation; tech-stack via constraints-file evolution per ADR-024 exception; runbook via failure-mode addition as workers encounter real issues).

For future missions, the recommended ordering is:

1. Phase 4: design refinement loop → spec proposal converges.
2. Phase 4.4: tech-stack deliverable (per ADR-024).
3. Phase 4.5: architecture documentation + runbook scaffolding (per ADR-022 + ADR-025).
4. Phase 5: spec acceptance hard gate → `mission-spec-accept.ps1` verifies all four (spec, architecture, tech-stack, runbook).

A mission whose runbook request arrives after Phase 4.5 has already run may invert this order once — runbook AFTER the architecture's touch-ups. Future missions follow the recommended ordering.

---

## Implementation notes

### For the existing `mission-spec-accept.ps1`

The script's gate set extends to four:

1. **Spec acceptance (ADR-008):** spec at `vNNN.yaml` is reviewable; operator approves explicitly.
2. **Architecture acceptance (ADR-022):** parser-validation evidence available; operator approves.
3. **Tech-stack acceptance (ADR-024):** no unresolved `OPERATOR-DECISION-NEEDED` tokens; no `CONFLICT` flags; constraints file reconciled.
4. **Runbook acceptance (ADR-025, NEW):**
   - `.mission/runbook/_schema.md` exists.
   - `.mission/runbook/INDEX.md` exists and links every entry.
   - `.mission/runbook/quickstart-L1.md` exists.
   - For every container in `containers.c4`: a corresponding entry in `.mission/runbook/<container_id>.md` exists.
   - Each entry's section structure conforms to the versioned schema at `_schema.md`.

The script can implement the runbook check as a structural pass (list containers; list runbook files; verify pairing). The deeper "does the failure-mode entry actually reflect a plausible failure" check is the operator's review at Phase 4.5; the script's check is mechanical.

### For Phase 4.5 (per ADR-022)

The Phase 4.5 work expands to include the runbook scaffolding. The designer's deliverables in Phase 4.5 are now:

- C4 architecture artifacts (per ADR-022).
- Mermaid state-machine and data-model diagrams (per ADR-022).
- UI README placeholder (per ADR-022).
- Runbook scaffolding + per-container entries (per this ADR).

A single Phase 4.5 commit sequence can cover both; the designer's call on organizational shape.

### For the framework's skill set (per ADR-023)

A future skill `skills/runbook-authoring/SKILL.md` (TBD; not part of this ADR) would capture the per-section content patterns + L1-readability conventions + the schema-as-versioned-artifact discipline. Until that skill exists, the operator-lean section names (Purpose / Normal-state signals / Common failure modes / Restart / Escalation) and the schema at `.mission/runbook/_schema.md` serve as the reference.

---

## References

- `.mission/inputs/` — where a mission records the client's request + operator decisions establishing the operator-locked properties.
- `.mission/runbook/` — where a mission's runbook lives under this ADR.
- `tools/mission-cli/config/adr-022-architecture-documentation.md` — companion ADR; the architecture-deliverable pattern.
- `tools/mission-cli/config/adr-024-tech-stack-as-deliverable.md` — companion ADR; the tech-stack-deliverable pattern.
- `tools/mission-cli/config/adr-008-design-phase-as-batch-job.md` (in `local-orchestrator-mode.md`) — the amendment-protocol parent ADR; runbook entries are under this same protocol after acceptance.
- `expanded-schemas.md` — unchanged by this ADR (runbook is a committed-artifact convention, not a schema field).
- `multi-agent-framework-design-brief.md` Sections 2.7, 14.3, 14.5 — the framework principles forcing this ADR.
