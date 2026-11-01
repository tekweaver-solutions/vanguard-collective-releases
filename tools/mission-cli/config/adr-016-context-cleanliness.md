# ADR-016 — Context cleanliness at every level of the agent hierarchy

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-016-context-cleanliness.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Context cleanliness is treated as a system-wide design discipline, not a per-tool tactic. At every level of the agent hierarchy — orchestrator, worker, validator, and any sub-tasks they spawn — the framework actively curates what enters the context window. Four techniques apply, in roughly this order of preference:

1. **Compaction at task boundaries.** When a worker or validator finishes a discrete unit of work (a feature, an assertion check, a research pass), its output to the next agent is a structured summary, not the raw context that produced it. The structured handoff doc (Section 5.3 of the brief, expanded in `expanded-schemas.md`) is the canonical compaction artifact: it captures decisions, completed work, unfinished items, and observations in a high-signal, low-volume form.
2. **Sub-agent isolation for context-heavy work.** Tools or sub-tasks whose intermediate state is voluminous (browser DOM, screenshot batches, large-file traversal, network logs, multi-file refactors of unfamiliar codebases) are invoked through Claude Code's `Task()` mechanism. The sub-agent runs in its own context window; the parent receives a structured summary. Mandatory for: Playwright (per the shape of its output), bulk file traversal, screenshot batch capture, network log capture.
3. **Structured note-taking via the artifact store.** Information that needs to persist across agent invocations does not live in any single agent's context. It lives in the memory ledger (Section 5.4), the spec, or the trace store. Agents query these on demand. This is *Section 9 of the brief operationalized* — factual drift is fought with the ledger, not with longer contexts.
4. **Tool-output filtering.** When a tool produces output that's mostly noise relative to the agent's task (full HTTP response bodies when only the status code matters; full file contents when only specific symbols matter), the tool harness filters before returning. Full output is captured to disk for traceability; the agent sees the filtered slice.

**Where the techniques apply.**

| Level | Default practice |
|---|---|
| Orchestrator (interactive thinking-partner) | Reads artifacts on demand; never loads the full repo. Keeps a slim working context anchored in the current spec version and active milestone. |
| Orchestrator (batch designer) | Reads `.mission/inputs/` once, produces a single output, terminates. Fresh context per design iteration (ADR-008). |
| Worker | Fresh context per dispatch. Reads only the spec snapshot, assertion targets, and prior handoff. Spawns sub-agents for context-heavy exploration. Compacts to a structured handoff at the end. |
| Validator (narrow) | Fresh context per assertion. Sees the assertion text, the built artifact, and nothing else — no implementation history, no prior worker reasoning. |
| Validator (QA) | Fresh context. Sub-agent for Playwright work; main agent evaluates the screenshot summary. |
| Sub-agents (Task) | Whatever context-heavy work the parent needed. Returns only a summary. |

**Why this is a principle, not a checklist.** Context pollution is an emergent failure mode that compounds over hours-long runs. Per-prompt discipline is insufficient because the failure is silent — there's no error message saying "your context is rotted." The framework enforces context cleanliness through structural choices: fresh contexts at boundaries, mandatory sub-agents for known-voluminous tools, artifact-store queries instead of in-context memory, and filtered tool harnesses. These structural choices remove the opportunity to violate the principle by accident.

**Relation to the brief.** This ADR operationalizes Section 9's "Context rot" defense ("Fresh context per worker, structured handoffs (high-signal, low-volume)") by naming the four concrete techniques and where each applies. It does not introduce new principles — it makes the existing principle enforceable.

**Alternatives considered.**

- *Trust per-prompt discipline.* Tried in earlier iterations of similar systems; failure mode is silent, hard to detect, and degrades over hours-long runs. Rejected.
- *Hard size cap on tool outputs.* Caps cause information loss. Sub-agents preserve full information *in their own context* and return summaries — strictly better.
- *Run all tools in sub-agents.* Overkill for simple GitHub queries or low-volume reads. The `isolation` declaration in `mcp-tools.yaml` makes this an explicit choice per tool.

**Tradeoff accepted.** Sub-agent calls add latency relative to direct calls (extra context bootstrap). Compaction at task boundaries means the next agent has less raw material to draw on. Both costs are worth paying because the alternative is invisible degradation. The discipline is enforced architecturally, not by exhortation.

**Reference.** Anthropic has published a guide on context engineering for AI agents that covers compaction, structured note-taking, and multi-agent architectures as the core techniques. ADR-016 adopts that vocabulary and applies it consistently at every level of the framework's agent hierarchy.
