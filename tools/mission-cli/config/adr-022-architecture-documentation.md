# ADR-022 — Architecture documentation as committed artifacts; Phase 4.5 hard gate

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** an architecture-documentation phase, after a spec version was accepted at a refinement checkpoint and the architecture-documentation pass was authorized by the operator.
>
> **Empirical grounding:** a spec can carry dozens of features and contract assertions describing an architecture while the framework had no step that required the architecture to be DRAWN before execution started. Drawing the architecture surfaces internal inconsistencies, missing components, and wrong boundaries that are much cheaper to fix BEFORE Phase 5 acceptance than after dispatch begins. This ADR establishes architecture-documentation as a first-class framework step (Phase 4.5) and as a hard gate against Phase 5.

---

## Decision

The framework adopts a new phase, **Phase 4.5: architecture documentation**, between Phase 4 (design refinement) and Phase 5 (spec acceptance / `mission spec accept`). Phase 4.5 produces a committed, validated set of architecture artifacts that visualize the spec the operator has accepted. Specifically:

1. **Phase 4.5 runs after the operator accepts a spec version at a Phase 4 refinement checkpoint** and BEFORE `mission spec accept` is invoked.
2. **The artifact set is fixed per the operator's stated requirements**, consisting of:
   - **C4 model views in likeC4 DSL** under `.mission/architecture/c4/`: System Context, Container, Component, Deployment, plus dynamic views for each load-bearing workflow (one per load-bearing user workflow).
   - **State machines and data-model diagrams in Mermaid** under `.mission/architecture/mermaid/`: state machines via `stateDiagram-v2`; data models via `erDiagram` or `classDiagram` per the designer's judgment of which more naturally represents the structure.
   - **UI wireframes / mockups in Figma**, indexed by a `README.md` under `.mission/architecture/ui/`. The agent writes only the README; the operator produces the Figma file using Figma MCP as a design-time tool. Exported PNG snapshots are committed by the operator.
3. **likeC4 DSL specifically**, not PlantUML or hand-rolled XML. Consult `likec4.dev` and `likec4.dev/tutorial` for canonical syntax. The framework's responsibility ends at producing valid DSL; **rendering (to SVG / PNG / browser views) is an EXTERNAL concern**, handled by whatever viewer the reader prefers (likeC4 Docker, structurizr, VS Code extensions, online viewers). The framework does NOT install renderers.
4. **Mermaid sources are committed in markdown files** with fenced ` ```mermaid ` blocks (NOT in `.mmd` files), so GitHub renders them natively without any tooling installation.
5. **Each architecture artifact is validated before commit** per ADR-020 + ADR-021:
   - likeC4 files: `likec4 validate <file>` if the CLI is installed. **If install fails (a likely path on Windows), fall back to LLM-based self-validation against the likec4.dev syntax reference.**
   - Mermaid files: LLM-based self-validation against `mermaid.js.org` syntax references.
   - **First non-obvious syntax issue → ledger gotcha entry as its own commit**.
6. **Architecture artifacts are themselves under the amendment protocol per ADR-008.** Once accepted at the Phase 4.5 review checkpoint (Checkpoint N.5), changes go through `mission amend`. Workers in execution phase cannot silently deviate from the architecture; deviations require an amendment in the same way as spec / contract deviations do.
7. **Phase 4.5 is a HARD GATE against Phase 5.** `mission spec accept vNNN` MUST refuse to run if `.mission/architecture/` contains uncommitted or unvalidated artifacts. The Phase 5 acceptance script (`mission-spec-accept.ps1` — not yet written at the time this ADR is drafted) inherits this requirement; it must be extended to enforce the gate when it is implemented.
8. **If the architecture-documentation pass exposes a spec gap**, Phase 4.5 STOPS at the artifact that surfaced the gap. The operator triggers a v(N) → v(N+1) refinement (the standard Phase 4 loop) to close the gap; Phase 4.5 re-runs against v(N+1). This is the explicit reason for placing Phase 4.5 BEFORE Phase 5: drawing the spec is a meaningful check on the spec.

The detail-level production know-how for each artifact kind lives in **committed skill files** under the new `skills/` directory (per ADR-023, drafted concurrently):

- `skills/likec4-authoring/SKILL.md` — likeC4 DSL authoring conventions.
- `skills/mermaid-authoring/SKILL.md` — Mermaid syntax conventions.
- `skills/architecture-documentation/SKILL.md` — meta-skill orchestrating the artifact set, validation discipline, and Checkpoint N.5 review shape.

## Alternatives considered

- **Skip architecture documentation entirely.** Status quo before this ADR; rejected because drawing makes the gap visible — a spec with dozens of features and assertions describes an architecture but does not visualize it. The act of drawing reveals internal inconsistencies, missing components, and wrong boundaries that are easy to miss when reading text. The cost of catching such issues mid-execution (worker dispatched against a wrong boundary, validator fires on an assertion the architecture doesn't support, amendment storm) is much higher than the cost of producing the architecture artifacts.

- **Defer architecture to the execution phase (workers produce architecture as part of their work).** Rejected for two reasons:
  - **Architecture as a check on the spec is lost.** If the architecture is produced as part of execution, the spec is already frozen at Phase 5; architecture-revealed gaps would need amendment rather than spec refinement. The cheaper-to-fix moment is BEFORE Phase 5.
  - **The architecture would become per-worker and inconsistent.** Workers building different milestones might produce different (and conflicting) architecture views. A pre-execution architecture pass produces a single, internally-consistent architecture that all workers consume.

- **Single-tool architecture (e.g., PlantUML only, or hand-rolled markdown only).** Rejected because C4 views, state machines, and UI mockups have fundamentally different natural representations. Forcing all three through one tool produces poor results in at least two of the three. likeC4 + Mermaid + Figma is three tools chosen for fitness; the cost is three skills to maintain (mitigated by committing them per ADR-023).

- **Framework auto-renders architecture artifacts.** Rejected because rendering is a different concern from authoring. Different readers prefer different viewers (the likeC4 Docker image, VS Code extensions, online viewers, structurizr, …); the framework would be choosing for them. Committing only the DSL source preserves reader choice, avoids a tooling dependency in the framework, and is consistent with the broader "framework distributes specifications, not implementations" pattern.

- **Make Phase 4.5 advisory (recommended but not gated).** Rejected because the value of catching architecture-revealed spec gaps depends on the architecture being produced BEFORE the operator commits to Phase 5. An advisory step would be skipped under deadline pressure exactly when the architecture-as-check property is most valuable.

- **Include Figma DSL / source files instead of only the README placeholder.** Rejected because Figma's source format is proprietary and not human-readable in git diffs. The PNG snapshots committed alongside the README are the human-readable archive; the operator's Figma file URL is the canonical authoring source.

## Tradeoff accepted

- **More framework surface.** Phase 4.5 is a new lifecycle phase with its own artifact set, validation discipline, and review checkpoint. The framework grows by one phase, two skills (likeC4, Mermaid), one meta-skill, and one ADR (this one). Mitigated by the empirical justification: drawing a text-only spec makes the gap visible, and the failure cost of dispatching against an unvisualized architecture is high.
- **Tool dependency on likeC4 + Mermaid + Figma.** Three tools the framework now depends on. Mitigated by:
  - likeC4 and Mermaid have committed skills (`skills/likec4-authoring/`, `skills/mermaid-authoring/`); the framework's authoring know-how is durable across tool-version drift.
  - Rendering is EXTERNAL; the framework's dependency is only on the DSL / markdown syntax, which is far more stable than the rendering ecosystem.
  - Figma is the operator's tool; the framework's only Figma dependency is the README placeholder format.
- **Phase 4.5 takes wallclock.** A typical architecture pass produces on the order of a dozen artifacts (C4 views, Mermaid diagrams, a UI README, ADRs), roughly a day of agent work. This is a real cost on the critical path. Mitigated by the fact that the cost is paid ONCE per mission (and per amended-architecture, when amendments are material), not per worker dispatch.
- **The architecture can stale.** If the operator amends the spec mid-execution but does not update the architecture artifacts, the architecture diverges from truth. Mitigated by the ADR-008 amendment protocol: architecture artifacts are under the same protocol as spec artifacts; the amendment workflow includes the architecture refresh step.
- **The hard gate stops execution if architecture is invalid.** A `mission spec accept` invocation against an unvalidated architecture refuses cleanly with a structured error. The operator must fix the architecture first. This is the intended behavior; cost is one extra step in the happy path, prevention of a class of "dispatched against the wrong architecture" failures in the unhappy path.

## Why this is forced by the framework's principles

- **"Contract before code" (brief §2.4).** The contract IS the architecture in textual form. Drawing the architecture is the visual companion to the textual contract; producing both before code starts is the consistent extension of the principle.
- **"Replayability" (Section 14.3 of the brief).** The architecture artifacts are committed and versioned; future sessions can reconstruct what the architecture was at any point. Without this ADR, the architecture would live only in the spec text, harder to navigate.
- **"Two-drift-two-fixes" (brief §2.7).** Architecture-revealed spec gaps surface BEFORE workers are dispatched; the gap is fixed in the spec (Phase 4 refinement), not in the architecture artifact alone. This is consistent with "fix the source of the drift, not the symptom."
- **"Artifact discipline" (this framework's recurring theme).** The architecture pass produces committed, versioned, reviewable artifacts. No conversation-only architecture survives a session boundary; this ADR makes that property explicit.

## Companion to ADR-023

ADR-023 (Skills as committed artifacts) is drafted concurrently with this ADR. The empirical need for ADR-023 is THIS architecture-documentation work: likeC4 and Mermaid have non-trivial syntax that benefits from committed reference material so that future architecture-doc passes (in this mission's amendments, and in future missions) start from a working knowledge base rather than re-deriving syntax from the canonical sources each time.

The two ADRs together establish:
- ADR-022: WHAT the framework produces during Phase 4.5 (the architecture-artifact set) and WHEN (between Phase 4 and Phase 5; as a hard gate).
- ADR-023: HOW the agent knows to produce it (via committed skills under `skills/`).

## Amendment: Parser validation is mandatory for DSL-based architecture artifacts

For DSL-based architecture artifacts (likeC4 and similar), parser validation via the official viewer or CLI is considered **mandatory**. LLM-self-validation against syntax references is insufficient — DSL files can pass self-validation yet fail parser validation with structural errors that would have been undetectable without a real parser (three error classes recur: duplicate elements across files, cascading reference-resolution failures, and dynamic views with empty actors arrays).

Where local parser-CLI installation is blocked (e.g., corporate SSL interception, npm registry issues such as an npm-install TLS failure), the **Docker-based viewer is the alternative** — the "rendering is external" framing applies equally to validation. Validation that produces structurally correct .c4 files can be conducted entirely via the official likeC4 Docker image at `likec4/likec4`, with parser errors inspected via `docker logs <container>`.

The implementation notes below carry through unchanged. Parser validation should run during authoring — not only as a final-check step before commit.

## Implementation notes for the not-yet-written `mission-spec-accept.ps1`

When the Phase 5 acceptance script is written, it MUST:

1. **Check `.mission/architecture/` exists.** Refuse if missing.
2. **Check all expected artifact files are present.** Mission-specific; e.g. the `.c4` view files + the `.md` files in `mermaid/` + 1 `README.md` in `ui/`. Future missions declare their expected architecture-artifact set in a yet-to-be-defined manifest (this ADR does NOT prescribe the manifest format; the script's check can start with a hardcoded list per mission and be generalized later).
3. **Check each artifact is git-tracked.** Refuse on any uncommitted architecture file.
4. **Check each artifact has been validated.** A separate `.mission-runtime/architecture-validation.json` (NOT committed; per ADR-003 ephemeral cache) records the validation result per file. The script reads this and refuses on any "invalid" or "missing" entry. Validation is the responsibility of the agent during Phase 4.5; the script's job is only to verify the validation outcome.
5. **Check an architecture-review acceptance commit exists.** The convention: the operator explicitly accepts the architecture by committing a small marker file (e.g., `.mission/architecture/ACCEPTED-vNNN.txt`) naming the version of the spec the architecture was reviewed against. The script refuses if this marker is missing for the spec version being accepted.

The hard-gate check is BEFORE the script does anything else (before moving files from `proposals/` to authoritative locations, before transitioning state). A refusal on Phase 4.5 absence is the cheapest possible halt.

## References

- `.mission/architecture/` — where a mission's Phase 4.5 artifacts live.
- `skills/architecture-documentation/SKILL.md` — meta-skill for the architecture-doc pass.
- `skills/likec4-authoring/SKILL.md` and `skills/mermaid-authoring/SKILL.md` — detail-level skills.
- `tools/mission-cli/config/adr-008-design-phase-as-batch-job.md` (in `local-orchestrator-mode.md`) — the amendment-protocol parent ADR.
- `tools/mission-cli/config/adr-020-filesystem-verification-of-tool-calls.md` — filesystem-verify discipline applied during Phase 4.5.
- `tools/mission-cli/config/adr-021-incremental-commits-for-multi-artifact-generation.md` — incremental-commit discipline applied during Phase 4.5.
- `tools/mission-cli/config/adr-023-skills-as-committed-artifacts.md` — companion ADR establishing the `skills/` directory.
- The mission ledger's gotcha entries — operational failure modes that informed the validation-discipline part of this ADR.
- `likec4.dev` and `likec4.dev/tutorial` — canonical syntax reference for likeC4 DSL.
- `mermaid.js.org` — canonical syntax reference for Mermaid.
- Simon Brown's C4 model (`c4model.com`) — conceptual framework underlying likeC4.
