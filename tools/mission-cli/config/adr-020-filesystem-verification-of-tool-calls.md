# ADR-020 — Filesystem verification of tool-call success at the runner seam

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted after** a session reported a `git commit` as successful in its transcript while the file in question was in fact untracked when the next session opened the repo.
>
> **Empirical grounding:** two recorded findings from that recovery: claimed-commit-vs-filesystem-truth, and a stuck-vs-slow diagnostic procedure.

---

## Decision

The runner — the framework component that dispatches tool calls (Bash, Write, Edit, MCP) on behalf of an agent and surfaces results back into the agent's context — **must filesystem-verify any tool call whose success claim implies a durable side effect** before treating the call as successful. Verification happens at the runner seam, not at the agent's discretion, and applies uniformly to:

1. The **bootstrap agent** (Claude Code acting as Local Orchestrator during the design phase).
2. **Workers** (execution-phase coding agents) verifying their own commits, file writes, and handoff-document writes before producing a `Handoff` per `expanded-schemas.md` Section 5.
3. **Validators** (narrow and QA) verifying that the artifact they were asked to inspect actually exists on disk at the path the dispatch named, before emitting a `ValidatorResult`.

Concretely, the runner enforces the following classes of verification:

| Tool-call class | Verification step | Failure handling |
|---|---|---|
| `git commit` (any path) | `git log --format=%H -1` plus `git status --porcelain` on the staged paths; the commit's `tree` must reference each path with the expected blob SHA | Mark the tool call as `failed`; emit a `TraceEvent` with `status: error`, reason `commit_not_landed`. Do **not** report success to the agent. |
| `Write` / `Edit` of any file | `stat` the path; compare size and mtime to the just-completed write; if mtime is more than 5s in the past, treat as failed | Same — `error` status, agent must retry. |
| `Bash` commands declared to mutate state (creates a file, edits a file, runs a migration) | Caller declares the expected side-effect path; runner stats it post-call | Same. |
| Agent emits a `Handoff` per ADR-008 / `expanded-schemas.md` §5 | Runner reads the freshly-written handoff back, validates against the schema, AND checks every path it references (`commits[]`, `commands_run[].cmd` outputs, evidence pointers) | Reject the handoff at the boundary; worker is respawned per the framework's existing handoff-validation rule. |

The verification is **mechanical**, not LLM-mediated. It cannot be skipped, suppressed, or summarized. The cost is a few extra syscalls per durable side effect; the benefit is that no agent ever proceeds on the basis of a non-event.

## Alternatives considered

- **Trust the tool's exit code (status quo before this ADR).** Every dispatcher today reports tool success based on the wrapping tool harness returning a structured result. The recovery incident demonstrated this is not enough: the transcript can carry a "success" record for an operation whose disk-side effect never happened — for reasons that range from process death between syscall and acknowledgment, to shell-level mis-quoting that silently drops the operation, to the agent itself constructing a plausible-looking acknowledgment without having actually issued the call (this last is the most consequential failure mode and the hardest to detect from inside the agent's own context). Rejected because the empirical failure already happened on a real mission.

- **Push verification into the agent's prompt** ("after every write, run `git status` and assert..."). Rejected for two reasons. First, agents under load have been observed to elide self-checks they were prompted to do — silent compliance failure is not catchable from inside. Second, the discipline is too important to depend on prompt adherence; it belongs at the runner seam where it cannot be skipped (per the framework's stance on context cleanliness and structural enforcement in ADR-016).

- **Verify only at handoff boundary, not after every tool call.** Rejected because by the time a worker assembles a handoff, the wrong assumption (e.g., "I committed X earlier") has already shaped the rest of its work. The cost of catching the error at the seam is small; the cost of catching it three hours of derivative work later is large. Both verifications are kept: handoff-level verification is the catch-net, tool-call-level verification is the prevention.

- **Use a periodic background sweep** (every N seconds, run `git status` and compare to the agent's claimed state). Rejected — adds asynchrony to a problem that is naturally synchronous, and produces ambiguous traces (which tool call's claim was wrong?).

## Tradeoff accepted

- **Per-call latency overhead.** Adds 1–4 syscalls per durable tool call (stat / git plumbing). Real cost is on the order of a few milliseconds per call; against the seconds-to-minutes cost of an LLM call it is invisible.
- **The runner must understand which tool calls have durable side effects.** This is a small static table per tool surface (Bash with certain command prefixes; Write; Edit; MCP server methods declared to mutate state). The table lives next to the runner code and is reviewed when new tools are admitted.
- **False-positive risk if the filesystem is slow** (large repos, networked storage, antivirus scanners delaying writes). Mitigated by the 5-second mtime window for write verification; if that window proves too tight on the operator's hardware, it is a per-mission runner config knob, not a per-call retry loop.
- **The bootstrap agent (Claude Code itself) is not under the framework's runner.** The framework cannot install runner-seam verification into Claude Code. For the bootstrap, the verification is therefore a *protocol* the agent runs in its own conversation (see ADR-021 on incremental commits and the bootstrap feedback memo at `tools/mission-cli/config/feedback-bootstrap-improvements.md`). The structural enforcement only applies starting with execution-phase workers spawned via the framework's `worker-runner` (Section 6.2 of `local-orchestrator-mode.md`).

## Why this is forced

- **Section 2.5 — "structure beats cleverness on long horizons."** The original framework principle: the discipline that protects a multi-hour autonomous run must be enforced architecturally, not by reminder. The recovery incident is exactly the failure mode this principle anticipates.
- **Section 2.7 — "alignment-drift defense."** An agent that thinks it committed something but didn't has a corrupt model of the world. Every subsequent decision compounds the error. Catching the disagreement at the seam is the small, atomic defense against compounding drift.
- **ADR-016 — context cleanliness as structural choice, not exhortation.** The same logic generalizes: any property whose failure is silent and compounds must be enforced where it cannot be skipped, not asked-for in a prompt.
- **The handoff schema (`expanded-schemas.md` Section 5).** `Handoff.commits[]` and `Handoff.commands_run[]` are already declared as audit-trail fields. Their value depends on those records corresponding to real disk-side effects. ADR-020 makes that correspondence enforceable.

## Operational integration

- The framework's `tools/worker-runner/` (when built) wraps every tool dispatch in a small verification shim. Specifically:
  - A `verify_write(path, mtime_at_call)` helper.
  - A `verify_commit(staged_paths)` helper using `git plumbing` to confirm the new HEAD tree contains the expected blobs.
  - A `verify_mcp_mutation(server, method, declared_side_effect)` helper for MCP servers whose methods are marked as mutating in `tools/mission-cli/config/mcp-tools.yaml`.
- Failures emit a `TraceEvent` with `type: tool_call`, `status: error`, `error: "filesystem_verification_failed"`, and a structured `expected_vs_actual` diff. The agent sees the error in its next turn and is expected to handle it (typically retry or escalate via an amendment).
- The verification table is reviewed in code review whenever a new tool is admitted to the tool gateway.
- For the bootstrap agent (the operator's Claude Code session), the verification is a *protocol* enforced by the operator's checklist in `bootstrap-instructions-for-claude-code.md` (see ADR-021 and the bootstrap-improvements feedback memo). Specifically: after every `git commit`, run `git status` and confirm the expected file is no longer in the untracked list.

## Relation to other ADRs

- **ADR-016** (context cleanliness) — the structural-enforcement-not-exhortation pattern is identical; this ADR applies it to durability rather than to context shape.
- **ADR-008** (Design Phase as artifact-mediated batch job) — strengthens the artifact-mediated half: artifacts must actually exist on disk to mediate.
- **ADR-021** (incremental commits for multi-artifact generation) — companion ADR. Where ADR-020 is "verify each tool call's effect", ADR-021 is "structure generations so verification is meaningful at frequent boundaries."

## Open follow-ups (deferred to ADR refinement before promotion)

- **What does the runner do on a verification failure that the agent does not handle?** Current proposal: after N consecutive verification-failed-then-retried events on the same logical operation, the circuit breaker opens (per Section 6.3 of the framework) and the operator is notified. N is suggested at 3.
- **Performance budget for the verification syscalls.** A per-mission ceiling could be enforced via the tool-gateway's existing capability accounting. Probably unnecessary; revisit if it becomes a real cost.
- **MCP-server method classification.** Some MCP servers' methods are mutate-or-not depending on arguments (e.g., GitHub's API). The verification table is most useful when methods are statically classified; we accept some loss of coverage on argument-dependent methods, documented per server in `mcp-tools.yaml`.
