# ADR-024 — Technology stack as an explicit design-stage deliverable

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** an architecture review, after a checkpoint of the Phase 4.5 architecture pass surfaced that a spec's `tech_stack` field had been partial and that several real technology choices had been silently deferred to implementation.
>
> **Empirical grounding:** a spec can carry dozens of features and contract assertions describing the system while the `tech_stack` field carries only single-string entries per technology and silently leaves load-bearing choices (session store, web framework, validation library, build tooling, task orchestration, API-spec generation) unstated. The Phase 4.5 architecture pass — which embeds tech choices into containers and deployment nodes — made the gap visible: drawing the architecture forced concrete-enough choices to render, but those choices were not consolidated, reviewable, or reconcilable against any stated corporate-policy constraints.

---

## Decision

The framework adopts **technology stack as a first-class design-stage deliverable**, with three sub-decisions:

### 1. The technology stack is an explicit, reviewable design-stage deliverable

Each mission's design phase produces a **`tech-stack-NNN.md`** companion artifact in `.mission/spec/proposals/`, mirroring the shape of `design-notes-NNN.md`. The LivingSpec's `tech_stack` field continues to exist (per `expanded-schemas.md` Section 2) and carries the per-item concrete choice; the companion `tech-stack-NNN.md` provides the rationale, the alternatives considered per choice, and explicit visibility into any undecided items.

**Specifically:**

- The `tech_stack` field in `vNNN.yaml` is populated with one entry per technology decision, naming the chosen technology and a one-line rationale-pointer (to a section in `tech-stack-NNN.md`).
- The companion `tech-stack-NNN.md` has a section per technology choice with: the decision, the rationale, the alternatives considered, and the source (operator decision / ADR / framework default).
- **Every previously-undecided item is named explicitly** in `tech-stack-NNN.md` — either decided-with-rationale or flagged **`OPERATOR-DECISION-NEEDED`** if it is genuinely the operator's call. No silent default to a worker.

The tech-stack deliverable belongs **early in the design phase, alongside or before architecture**, because architecture embeds technology choices (a deployment view shows specific containers running specific runtimes; a component view's relationships imply specific library choices). Producing the stack first lets architecture be drawn against an explicit choice set; producing it late forces architecture-by-implication.

### 2. An OPTIONAL input file `.mission/inputs/technology-constraints.md` captures external technology restrictions

The constraints file declares technology constraints and preferences the proposed stack must conform to. It is OPTIONAL — absent means no external restrictions, the designer is free to propose the best technical fit per item.

**File shape (convention, not schema-enforced):**

- **§1 Hard constraints (must conform).** Non-negotiable restrictions. A proposed stack violating any §1 item requires a corrective design decision before acceptance.
- **§2 Stated preferences (strong defaults).** Restrictions with documented exceptions allowed. The designer may propose an alternative only with explicit rationale in `tech-stack-NNN.md`.
- **§3 Explicitly open (no restriction).** Items the constraints author has confirmed are designer/operator's call. The designer proposes a default with rationale; `OPERATOR-DECISION-NEEDED` flagging is appropriate where the operator wants to decide directly.
- **§4 Pending confirmation (corporate policy or stakeholder review).** Items not yet resolved that may impose §1 or §2 entries once resolved. Tracked openly; takes a future iteration to resolve.

**Provisioning timing.** The operator may provide the constraints file at mission start (alongside other typed inputs) OR mid-design-iteration. Provision during refinement triggers a design refinement like any other feedback file — the constraints file is a typed input under `.mission/inputs/` and follows the same commit-before-refine discipline.

**Update protocol.** Updates to the constraints file mid-design trigger a refinement (the existing `mission-design-refine.ps1` pattern: re-author proposals against the updated inputs). Locked once the design accepts at Phase 5.

### 3. The proposed stack is validated against the constraints file at the design checkpoint

At the tech-stack review checkpoint (typically Checkpoint N — the post-tech-stack-draft review):

- **§1 Hard-constraint conflicts** block Phase 5 acceptance until resolved. The agent flags any conflict prominently in `tech-stack-NNN.md` as **`CONFLICT`** with the specific constraint cited.
- **§2 Preference conflicts** require documented rationale in `tech-stack-NNN.md`. The operator decides whether the rationale is sufficient at the checkpoint.
- **§3 Open items** — the designer's proposed default is the working answer unless the operator overrides at the checkpoint.
- **§4 Pending items** are noted in `tech-stack-NNN.md` as awaiting external confirmation. They do not block the checkpoint but should be resolved before Phase 5 if they could affect any §3 choice.

The hard-gate property: Phase 5 acceptance (`mission spec accept`) must verify there are no unresolved §1 `CONFLICT` flags in the accepted `tech-stack-NNN.md`. This parallels the ADR-022 Phase 4.5 hard gate for architecture: `mission-spec-accept.ps1` (Phase 5 deliverable; not yet written) must check the tech-stack acceptance state alongside the architecture acceptance state.

---

## Alternatives considered

- **Defer tech choices to workers (the current implicit behavior before this ADR).** A worker dispatched against a feature would make the technology choice ad-hoc — picking a Python web framework, a database, a build tool — based on its own judgment. Rejected because unreviewed ad-hoc choices are exactly the failure mode the framework's contract-before-code principle prevents. The framework's value depends on technology choices being reviewable BEFORE execution; deferring them to execution moves them past the review.

- **Decide tech stack only at execution-phase planning.** Slightly better than worker-time decisions — at least it surfaces them before code is written. Rejected because the architecture-documentation step (Phase 4.5 per ADR-022) embeds technology choices: a deployment view names container runtimes, a component view's edges imply library choices. Producing the architecture without an explicit tech stack means architecture-by-implication, which the Phase 4.5 work demonstrated produces silent gaps.

- **Make the constraints file mandatory.** Rejected because many missions will have no external restrictions — forcing the operator to author an empty-constraints file adds ceremony without value. The OPTIONAL framing keeps the file out of the way for unconstrained missions while making it a first-class input for constrained ones.

- **Put the tech stack inside design-notes-NNN.md instead of a separate deliverable.** Workable but conflates two concerns. Design-notes captures the designer's reasoning about the spec proposal; tech-stack-NNN.md captures the technology choices and their reconciliation against constraints. Separating them makes each artifact scannable for its specific concern and lets the client (or a corporate-policy reviewer) read the tech-stack deliverable in isolation without wading through the spec-design reasoning.

- **Add an `OPERATOR-DECISION-NEEDED` mechanism inside the LivingSpec itself.** Rejected — the LivingSpec is the accepted record; `OPERATOR-DECISION-NEEDED` is a pre-acceptance status that resolves before the spec promotes. The companion `tech-stack-NNN.md` is the right home: it lives in `proposals/` until accepted, at which point all flags are resolved and the spec's `tech_stack` field carries the final answers.

- **Have the orchestrator/agent propose the stack autonomously from inferred best practices.** This IS what the agent does as the starting point — but the framework's contract-before-code principle demands operator review of choices that could affect millions of dollars of corporate IT policy. The `OPERATOR-DECISION-NEEDED` flag is the mechanism that surfaces "agent's default is X but operator should confirm." Removing the human review step would regress against the principle.

---

## Tradeoff accepted

- **One more design-stage deliverable to maintain.** Each mission now produces `tech-stack-NNN.md` alongside `design-notes-NNN.md` and (for non-trivial missions) the Phase 4.5 architecture artifacts. The maintenance cost is modest — the deliverable is typically ~50-100 lines for a mission with 15-25 technology choices, and the structure (section per choice + rationale) is mechanical.

- **The constraints file adds an input shape.** Operators now have one more place to put information, and the framework has one more file to teach to first-time users. Mitigated by the file being OPTIONAL (default behavior is no constraints) and by the file format being documented in this ADR section by section.

- **Validation against constraints is one more checkpoint dimension.** The Checkpoint-N review must now verify §1 hard-constraint compliance + §2 preference-rationale presence + §3 default-or-decision per item. This adds review surface but exposes failure modes (silent default to a worker, ad-hoc framework choice that violates corporate policy) that previously failed silently in execution.

- **Architecture re-validation when constraints change.** Mid-design constraints updates can force re-doing architecture work if the new constraint changes a container or relationship. The framework absorbs this — constraints updates are real signals that the prior design was wrong against the operator's actual context.

- **The agent's "default" may diverge from corporate policy without the agent knowing.** The agent proposes best-fit defaults from its general knowledge; corporate policy may differ. The `OPERATOR-DECISION-NEEDED` flag mechanism plus §4 (Pending confirmation) in the constraints file are the safety net. The operator, not the agent, owns corporate-policy reconciliation.

---

## Why this is forced by the framework's principles

- **"Contract before code" (brief §2.4).** Technology choices ARE part of the contract — they constrain what workers can build, what dependencies the deliverable carries, what production-deployment paths exist. Making them explicit before code is the consistent extension of the principle.

- **"Two-drift-two-fixes" (brief §2.7).** Tech-stack drift (a worker picking a different library than the spec implies) is a real drift mode this ADR prevents at the design stage rather than catching it as a spec amendment mid-execution.

- **"Replayability" (brief §14.3).** A mission's tech-stack-NNN.md is part of the replay artifact set. A future agent reading the accepted spec sees not only the goal and the contract but the exact technology choices made, with rationale.

- **"Artifact discipline" (this framework's recurring theme).** Tech-stack joins spec, contract, architecture, skills, and ADRs as committed, versioned, reviewable artifacts. No conversation-only tech choices survive a session boundary.

---

## Companion to ADR-022

ADR-022 (Architecture documentation as Phase 4.5 committed artifacts) establishes the architecture-doc step between Phase 4 design refinement and Phase 5 spec acceptance. ADR-024 (this ADR) establishes the tech-stack-as-deliverable pattern that **belongs earlier**: alongside or before the architecture step, since architecture embeds tech choices.

Where the architecture pass is what surfaces the gap, the tech-stack work may run AFTER the architecture once. For future missions, the recommended ordering is:

1. Phase 4: design refinement loop → spec proposal converges.
2. **Phase 4.4 (new, this ADR): tech-stack deliverable** → tech-stack-NNN.md authored, constraints reconciled, operator reviews + resolves OPERATOR-DECISION-NEEDED items.
3. Phase 4.5 (ADR-022): architecture documentation → architecture drawn against the explicit stack, reviewed.
4. Phase 5: spec acceptance hard gate → mission-spec-accept.ps1 verifies (a) no unresolved §1 CONFLICT in tech-stack; (b) all architecture artifacts validated; (c) operator's explicit acceptance.

A mission that ran architecture before tech-stack records that ordering in its `tech-stack-NNN.md` as a one-off; future missions should follow the ADR-024-recommended ordering.

---

## Implementation notes

### For the not-yet-written `mission-spec-accept.ps1`

When the Phase 5 acceptance script is written, in addition to the ADR-022 architecture checks it MUST:

1. **Check `.mission/spec/proposals/tech-stack-vNNN.md` exists** for the accepted spec version. Refuse if missing.
2. **Check `tech-stack-vNNN.md` is git-tracked.** Refuse on any uncommitted state.
3. **Grep `tech-stack-vNNN.md` for unresolved flags.** Refuse on any `OPERATOR-DECISION-NEEDED` or `CONFLICT` token remaining. The acceptance marker is the absence of these tokens.
4. **Optional reconciliation log.** If `.mission/inputs/technology-constraints.md` exists, the script can emit a one-page reconciliation summary (which §1 / §2 / §3 / §4 items were addressed) for the audit trail. Not blocking; advisory.

### For framework tooling

- A future `mission tech-stack draft` command could scaffold a `tech-stack-NNN.md` template from the spec's `tech_stack` field, prompting the agent to fill in rationale per item. Not required for v1; can be added when a mission's tech-stack-authoring becomes a repetitive workflow.
- The `tools/mission-cli/config/proposals/` pattern that ADR-015 established for `mcp-tools.yaml` is a clear analog: `tech-stack-NNN.md` lives in `proposals/` until accepted, then promotes via `mission spec accept`.

---

## References

- `.mission/inputs/technology-constraints.md` — the optional constraints input this ADR defines.
- `.mission/spec/proposals/tech-stack-NNN.md` — the tech-stack deliverable this ADR defines.
- `.mission/spec/proposals/vNNN.yaml` — the spec whose `tech_stack` field the deliverable fully populates.
- `tools/mission-cli/config/adr-022-architecture-documentation.md` — companion ADR for Phase 4.5; tech-stack belongs earlier.
- `tools/mission-cli/config/adr-008-design-phase-as-batch-job.md` (in `local-orchestrator-mode.md`) — the amendment-protocol parent ADR; tech-stack-NNN.md is under this same protocol once accepted.
- `expanded-schemas.md` Section 2 — the LivingSpec schema with the `tech_stack` field (unchanged by this ADR; the field's semantic is reused with stricter completeness expectations).
- `multi-agent-framework-design-brief.md` Sections 2.4, 2.7, 14.3 — the framework principles forcing this ADR.
