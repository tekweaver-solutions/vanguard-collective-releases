# ADR-023 — Skills as committed artifacts under a registry-pull pattern

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** an architecture-documentation phase (Phase 4.5), concurrent with ADR-022. Drafted after authoring three Phase 4.5 skill files (`skills/likec4-authoring/`, `skills/mermaid-authoring/`, `skills/architecture-documentation/`) revealed the empirical need.
>
> **Empirical grounding:** the Phase 4.5 architecture-documentation work required non-trivial authoring know-how for likeC4 DSL and Mermaid. Without committed skill artifacts, the agent would need to re-derive syntax from `likec4.dev` and `mermaid.js.org` each time architecture work runs (within a mission's amendments and in future missions). Committing the know-how once and pinning it (like the prompts registry per ADR-012 / ADR-017) makes the architecture-doc pass replayable and reproducible.

---

## Decision

The framework adopts a new top-level directory **`skills/`** at the monorepo root, paralleling `prompts/`. `skills/` holds committed Skill artifacts that teach agents how to produce specific deliverables. Each skill is a folder named for the skill ID, containing a `SKILL.md` file (and optionally supplementary files, examples, fixtures).

Specifically:

1. **Skills are committed artifacts**, not ephemeral instructions in conversation. They live on disk, are git-tracked, are part of every clone of the monorepo, and survive session boundaries.
2. **Skills are produced under a registry-pull pattern**, the same pattern ADR-012 + ADR-017 established for prompts. Specifically:
   - The framework maintains a public skill registry (a GitHub repo, framework-maintainer-owned). Initial location TBD; in MVP the skills committed in this monorepo serve as the seed corpus for the registry.
   - `mission init` pulls a tagged version of the skill registry into the monorepo's `skills/` directory, writes a `skills/manifest.yaml` recording the registry source, the pulled version, and per-file SHAs.
   - `mission skills update [--to vX.Y.Z]` advances the pin. Same MAJOR-version-bump confirmation behavior as `mission prompts update` per ADR-017.
   - `mission skills fork <skill-id>` removes the manifest entry for a skill and leaves the file editable. Forking is opt-in and visible (a manifest gap is inspectable in code review).
3. **Each skill is structured for in-context reading by agents.** A SKILL.md has:
   - **YAML frontmatter** at the top with `skill_id`, `version`, `introduced_in`, `purpose`, `canonical_sources` (URLs the agent should consult for authoritative information beyond this file), `applies_to` (glob patterns for files the skill applies to), and optional `depends_on` / `related_adrs`.
   - **Section structure** typically: When to use this skill; Minimum you need to know; Framework conventions; Validation step; Common pitfalls; Worked example; References. The exact sectioning is per-skill; the framework convention is "structured for the agent to scan and find the relevant subsection in seconds."
4. **Skills are version-pinned for reproducibility**, in the same way prompts are per ADR-012. A trace event during execution may record the `skill_version` used by an agent, just as it records `prompt_version`. This closes the eval loop on skill-driven failures the same way it does on prompt-driven failures.
5. **The framework distributes a standard set of skills**; missions may add mission-specific skills as needed. Mission-specific skills go in the same `skills/` directory but are NOT listed in `manifest.yaml`'s `pinned` block; they live in a `forked` or `local` block per the same forking semantics as prompts.
6. **Skills vs prompts: different semantic.** Prompts are ROLE-level instructions (how a worker / validator / orchestrator behaves overall). Skills are TASK-level know-how (how to produce a specific artifact kind: a likeC4 view, a Mermaid diagram, a PR review). An agent reads a prompt at agent-construction time and a skill at task-execution time. The two are orthogonal and BOTH can be version-pinned independently.

The initial seed skills for the framework, produced during a Phase 4.5 pass:

| Skill ID | Purpose |
|---|---|
| `likec4-authoring` | Author valid likeC4 DSL files for C4-model architecture views. |
| `mermaid-authoring` | Author valid Mermaid diagrams in markdown files (stateDiagram-v2, erDiagram, classDiagram). |
| `architecture-documentation` | Meta-skill orchestrating the Phase 4.5 architecture-documentation pass per ADR-022. |

Future skills the framework is likely to add (out of scope for this ADR; listed as the trajectory):

- `assertion-authoring` — produce valid `A-NNN.yaml` contract assertions per `expanded-schemas.md` Section 3.
- `spec-refinement` — produce valid LivingSpec proposals per `expanded-schemas.md` Section 2.
- `ledger-entry-authoring` — write valid memory-ledger entries.
- `commit-message-authoring` — produce framework-conformant commit messages (incremental, descriptive, referencing IDs).
- `figma-design-authoring` — operator-side skill for producing the UI Figma file consistent with the framework's UI conventions.

## Alternatives considered

- **Skills inside `prompts/` (no new directory).** Rejected because skills and prompts have different semantics (task-level know-how vs role-level instructions). Conflating them produces a directory where two unrelated artifact kinds live; future readers struggle to distinguish "what does this agent do" from "how does this agent do task X." The cost of one new directory is small; the clarity benefit is large.

- **Skills as ephemeral instructions in conversation (the status quo before this ADR).** Rejected because not durable across agent invocations. Every new agent would have to receive the same know-how from the orchestrator, inflating prompt size and risking drift (different orchestrator runs producing different in-context skill versions). Committing skills once and pinning them eliminates the drift.

- **Per-mission skill authoring (no registry; every mission writes its own skills).** Rejected because of duplication. Five missions producing the same likeC4-authoring know-how independently is a recipe for inconsistency. A central registry produces one canonical version; missions pin against it; updates flow through MAJOR-version-confirmation per the prompts pattern.

- **Skills as a sub-property of prompts (e.g., `prompts/skills/`).** Rejected for the same reason as "skills inside prompts/" — the conflation cost outweighs the directory-count savings.

- **Skills distributed as an npm / pip package.** Rejected for the same reasons ADR-017 rejected packaging prompts: markdown files don't fit package manifests well, and semver via git tags is the same primitive with less ceremony.

- **Skills embedded in source code (e.g., docstrings).** Rejected because skills are produced and reviewed independently of code; coupling them to source files binds two cadences that should evolve separately. Skills are READ by agents; source code is EXECUTED. Different consumers, different cadences.

- **Skills written by the LLM at task-execution time (LLM derives skill from canonical-source URLs on each invocation).** Rejected on two grounds:
  - **Non-determinism.** Two invocations against the same task could produce different in-context skill versions, depending on the LLM's reasoning that turn. The framework's reproducibility property (replay-from-artifacts) is weakened.
  - **Cost.** Re-deriving skill content from URL contents at every invocation inflates token cost and adds an external-fetch dependency. Committed skills are read from disk once and consumed by many invocations.

## Tradeoff accepted

- **New directory to maintain.** `skills/` joins `prompts/`, `tools/`, `docker/`, `src/`, etc. as a top-level concern. Mitigated by parallel structure with `prompts/`: the maintenance protocol is the same (registry-pull, manifest-pinning, fork-on-edit). No new operational ceremony.

- **Skill content goes stale.** likeC4 and Mermaid syntax evolve; committed skills can lag the canonical references. Mitigated by:
  - **Canonical-source URLs in frontmatter.** Every SKILL.md declares the authoritative source; agents are instructed to consult the source when the skill is ambiguous.
  - **Versioned pinning.** A mission pinned to skill registry v1.4 sees v1.4's content; updates via `mission skills update` are explicit.
  - **MAJOR-version-confirmation.** Breaking changes in a skill (e.g., likeC4 v2.0 syntax that is incompatible with v1.x) bump the MAJOR; `mission skills update` refuses without `--confirm-breaking`.

- **Skills can drift from prompts.** A prompt that references a skill that has changed could produce inconsistent agent behavior. Mitigated by recording `skill_version` alongside `prompt_version` in trace events; mismatches are detectable in the eval loop. The framework does NOT enforce skill-prompt compatibility at runtime; the eval loop is the surfacing mechanism.

- **Mission-specific skills can fragment the corpus.** A mission that produces a one-off skill that another mission could use is missed by future missions. Mitigated by the natural promotion path: a mission's locally-developed skill can be contributed back to the registry (the same way the first Phase 4.5 skills seed the registry at v0.1.0). This is operationally similar to a PR upstream.

## Why this is forced by the framework's principles

- **"Replayability" (Section 14.3 of the brief).** Trace events that record `skill_version` (alongside `prompt_version`) enable replay of past work against the exact skills the original agent used. Without committed skills, replay loses fidelity on skill-driven failures.
- **"Eval-loop integrity" (Section 14.5 of the brief).** The eval loop correlates failures back to (prompt_version, skill_version) tuples; committing skills makes the second component first-class.
- **"Artifact discipline" (this framework's recurring theme).** Skills join prompts, specs, contracts, and architecture artifacts as committed, versioned, reviewable artifacts. No conversation-only know-how survives a session boundary.
- **"Structure beats cleverness on long horizons" (brief §2.5).** A library of curated, versioned skills is a structural investment; the cleverness alternative ("the agent will figure out the syntax in context") is the brittle path.

## Companion to ADR-022

ADR-022 (Architecture documentation as Phase 4.5 committed artifacts) is drafted concurrently. ADR-022 establishes WHAT the framework produces in Phase 4.5 and WHEN; ADR-023 establishes HOW the agent knows to produce it (via committed skills under `skills/`).

The Phase 4.5 work was the EMPIRICAL NEED that surfaced this ADR. Authoring three skill files (likec4-authoring, mermaid-authoring, architecture-documentation) at the start of Phase 4.5 made the architecture work tractable. Without such skills, an agent re-derives likeC4 syntax from likec4.dev on each architecture pass; with them, it refers to the skill file as needed and produces views consistently.

## Implementation notes

- **`skills/manifest.yaml` shape** (mirroring `prompts/manifest.yaml` per ADR-012):
  ```yaml
  registry: https://github.com/<framework-org>/mission-skills    # TBD; not yet established
  version: v0.1.0                                                # placeholder for the seed corpus
  pinned:
    likec4-authoring/SKILL.md:           sha256:...
    mermaid-authoring/SKILL.md:          sha256:...
    architecture-documentation/SKILL.md: sha256:...
  forked: []
  local: []     # mission-specific skills not in the registry
  ```
- **The `manifest.yaml` is NOT committed at the time this ADR is drafted.** The first mission to author them seeds the registry with its three Phase 4.5 skills; the registry itself does not yet exist as a separate GitHub repo. When the registry is established, a follow-up mission emits the manifest. This is a deliberate sequencing: ADR-023 declares the pattern; the registry follows.
- **CLI commands NOT yet implemented** at this ADR's draft time: `mission skills update`, `mission skills fork`. They follow the same shape as `mission prompts update` / `mission prompts fork` per ADR-017.
- **Trace-event field** `skill_version` to be added to the trace schema in a future schema-amendment. Cross-cutting with ADR-017's `prompt_version`.

## References

- `skills/likec4-authoring/SKILL.md`, `skills/mermaid-authoring/SKILL.md`, `skills/architecture-documentation/SKILL.md` — the empirical instance of this ADR; the seed skills for the registry.
- `tools/mission-cli/config/adr-022-architecture-documentation.md` — companion ADR; the work that surfaced this ADR's need.
- `tools/mission-cli/config/adr-012-pinned-pull-prompt-registry.md` (in `local-orchestrator-mode.md`) — the analogous pattern for prompts, which this ADR mirrors.
- `tools/mission-cli/config/adr-017-prompt-registry-on-github-with-semver.md` (in `local-orchestrator-mode.md`) — the analogous registry-distribution decision for prompts.
- `prompts/manifest.yaml` (when present in a mission) — the parallel manifest structure.
- `expanded-schemas.md` Section 9 — the TraceEvent schema; a future amendment adds `skill_version`.
- `multi-agent-framework-design-brief.md` Sections 14.3 (replayability) and 14.5 (eval loop) — the principles forcing this ADR.
