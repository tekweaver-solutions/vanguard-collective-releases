# ADR-021 — Incremental commits at artifact boundaries for multi-artifact generation

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted after** an attempt to generate a full spec artifact set (spec + assertions + design notes + operator review) atomically in a single turn stalled silently for hours, producing no disk output.
>
> **Empirical grounding:** two recorded findings, one that multi-artifact atomic generation stalls silently and one on claimed tool-call success vs. filesystem truth. Companion to ADR-020.

---

## Decision

When an agent (designer in batch mode, worker in execution phase, or the bootstrap agent itself) is producing a deliverable that comprises **multiple artifacts** — typically a spec + a set of contract assertions + design notes + operator review, or a feature implementation + tests + documentation + migration — the agent **must commit incrementally at sensible artifact boundaries**, not atomically at the end.

Specifically:

1. The agent **plans** the artifact set up front (a checklist of artifacts to produce).
2. The agent **produces one artifact (or one small batch) at a time**, writing it to disk via the runner.
3. After each artifact (or batch), the agent **runs `git status` and `git add` + `git commit`** for that artifact, with a commit message naming the artifact.
4. The agent **filesystem-verifies the commit** per ADR-020 before proceeding to the next artifact.
5. Only after all artifacts are committed does the agent move to the next phase / report success / produce the handoff.

"Sensible boundary" is per-artifact for small artifact sets (≤ 5 artifacts) and per-batch (e.g., 5–10 contract assertions at a time) for larger sets, where a batch is sized so that a single commit's diff is reviewable without scrolling fatigue. The framework treats per-artifact commits as the default and per-batch commits as the exception, justified inline in the commit message when used.

## Alternatives considered

- **Atomic commit at the end of the generation (status quo before this ADR).** Generate everything in one long turn, write all files, then `git add` + `git commit` once. Rejected after an empirical failure: an atomic generation attempt stalled silently, producing no disk output for hours. The failure mode is silent — there is no error message, no exit code, no progress signal. The runner does not know whether the agent is mid-generation or wedged. The atomic-commit pattern *hides* progress; the incremental pattern *exposes* it as filesystem state.

- **Time-based checkpointing (commit every N minutes regardless of artifact boundaries).** Rejected because mid-artifact commits produce nonsense diffs (half-written assertions, broken YAML), and the runner has no semantic boundary to organize the commit message around. Artifact boundaries are the natural unit; wall-clock is not.

- **Auto-commit at each `Write` tool-call.** Rejected because not every Write is at an artifact boundary — a single artifact may be assembled across multiple Writes (e.g., write the spec skeleton, then fill in features, then fill in decisions). Auto-committing each Write fragments the audit trail and inflates the commit count without adding semantic value.

- **Designer / worker produces a "draft-everything-in-memory then write+commit" pattern.** Rejected — this is the atomic pattern dressed up; the in-memory phase still has no progress signal and still risks the silent stall.

- **Rely on operator polling to detect stalls and restart.** This is a *fallback*, not a designed mechanism. It works (an operator opens the repo, sees nothing new, escalates) but at the cost of multi-hour lost work and a restart. ADR-021 is intended to prevent the situation that requires the fallback.

## Tradeoff accepted

- **More commits per deliverable.** A full spec refinement that previously would have been one commit is now 6+ commits. The git log gets denser. Mitigated by descriptive commit messages: a reviewer can `git log --oneline` and read the artifact-by-artifact story without diving into diffs.
- **The agent must plan upfront.** Atomic generation lets the agent discover structure as it goes; incremental generation requires committing to a checklist first. This is a small cost (the checklist is part of the standard planning step every agent should already be doing) and a real benefit (the checklist itself is a recovery artifact — a future session can read it and resume).
- **Slightly slower wall-clock for the generation.** Each artifact commit adds the cost of a `git add` + `git commit`. Negligible against the LLM-call cost of producing each artifact.
- **Per-artifact commits make rebasing fiddlier than one squashed commit.** Acceptable; for proposals (the primary use case) we do not typically rebase.

## Why this is forced

- **Section 2.5 of `local-orchestrator-mode.md` — "structure beats cleverness on long horizons."** The longer the generation, the more important the structural safeguards. A multi-hour atomic generation is exactly the horizon where structure stops being optional.
- **Section 6.1 — design phase as artifact-mediated batch job (ADR-008).** The design summary is explicit: artifacts mediate the design loop, not conversations. Incremental commits enforce that: every artifact lands on disk and in git before the next one is produced. If the agent dies mid-generation, the artifacts that landed are still there and a fresh designer instance (per ADR-008's "fresh per iteration" rule) can pick up from them.
- **Section 14.3 — replayability.** A multi-artifact generation that committed incrementally is replayable artifact-by-artifact; one that committed atomically is replayable only as a black box.
- **ADR-020 — filesystem verification of tool calls.** Companion ADR. Incremental commits give ADR-020's verification something to verify *frequently*; atomic commits collapse all the verification opportunities into a single end-of-run check.
- **The empirical record.** An incremental generation following this pattern completed where an atomic attempt hung.

## Operational integration

- **In `bootstrap-instructions-for-claude-code.md`** (the bootstrap protocol the operator runs Claude Code against): Phase 4 (design refinement) is updated to require an explicit incremental-commit checklist. The incremental pattern above is the template:

  ```
  Step 1: Draft vNNN.yaml -> git add + git commit
  Step 2: Process surviving assertions (refine in-place) -> git add + git commit
  Step 3: Delete retired assertions -> git add + git commit
  Step 4: Draft new assertions (in batches of ~5-10) -> git add + git commit per batch
  Step 5: Reshape config artifacts (mcp-tools.yaml, etc.) -> git add + git commit
  Step 6: Draft design-notes-NNN.md and operator-review-NNN.md -> git add + git commit
  Step 7: Final git status + git log --oneline review; stop at checkpoint.
  ```

  See `tools/mission-cli/config/feedback-bootstrap-improvements.md` for the full memo.

- **In `tools/worker-runner/`** (when built): the worker harness emits a planning event at the start of each dispatch (the artifact checklist) and a commit event at each artifact boundary. The runner asserts that the number of commit events matches the checklist before allowing the worker to produce its handoff. A worker that produces fewer commits than its checklist has unfinished work and must declare it via the handoff's `unfinished[]` array (per `expanded-schemas.md` Section 5).

- **In the orchestrator-thinking-partner prompt** (when versioned): the standard pattern for any multi-artifact response is the same. The thinking-partner enumerates the artifacts it plans to produce, produces them one at a time, and commits each before moving on.

- **For validators (narrow and QA):** the rule is naturally satisfied because validators produce a single `ValidatorResult` per dispatch. No change.

## Relation to other ADRs

- **ADR-020** (filesystem verification) — companion. ADR-020 is "verify each tool call's effect"; ADR-021 is "structure generations so the verification opportunities are frequent and the verification artifacts are well-defined." Together they make multi-hour generations safe on consumer hardware where silent stalls are a real failure mode.
- **ADR-008** (design phase as batch job, fresh designer per iteration) — strengthens the fresh-designer-from-committed-artifacts property. If artifacts commit incrementally, a fresh designer can resume from the most recent commit rather than from the start of the refinement.
- **ADR-003** (`.mission/` is committed truth) — operationalizes the principle. Committed truth has to actually be committed; atomic-at-the-end leaves a window during which truth is uncommitted.
- **ADR-016** (context cleanliness) — incremental commits also serve context discipline: each batch of artifacts is bounded in size, reducing the chance that a long uncommitted in-context plan gets corrupted.

## Open follow-ups (deferred to ADR refinement before promotion)

- **Batch sizing rule.** "≤ 10 assertions per batch" is an empirical heuristic. A more principled rule (per-commit-diff line count? per-commit token count?) could replace it; for now the heuristic is documented and revisited if it produces noisy commit logs.
- **Recovery protocol.** If a multi-artifact generation is interrupted mid-checklist, what is the correct resume behavior? Current proposal: a fresh designer reads the committed artifacts plus the checklist (which should itself be committed at step 0) and continues from the next unfinished item. Worth a small recipe document under `tools/mission-cli/config/`.
- **Interaction with the prompt registry (ADR-012/ADR-017).** When the bootstrap prompt is versioned and pulled from the registry, the incremental-commit checklist template should live in the prompt, not in the bootstrap instructions. Track for v1 of the registry-hosted bootstrap prompt.
