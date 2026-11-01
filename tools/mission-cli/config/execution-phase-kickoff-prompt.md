Execution-phase kickoff — <project> mission, post-Phase-5 acceptance.

## Where the mission stands

The <project> mission has transitioned to `Executing` state. v<NNN> is the committed spec; <N> contract assertions are frozen under `.mission/contract/assertions/`; the architecture pass is acceptance-validated; the runbook scaffolding under `.mission/runbook/` is in place. The acceptance commit is durable on `origin/main`. Working tree is clean.

Begin by verifying current state from the filesystem — do NOT take the above on faith (ADR-020 discipline):

```powershell
git log --oneline -5
git status
Get-Content .mission\mission.yaml | Select-String "^state:|^current_spec_version:"
Get-Content .mission\spec\current.txt
Get-ChildItem .mission\spec\v*.yaml
Get-ChildItem .mission\contract\assertions\*.yaml | Measure-Object | Select-Object -ExpandProperty Count
Get-ChildItem .mission\contract\proposals\*.yaml -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count
```

Expected: HEAD at the Phase-5 acceptance commit, plus possibly the `.claude/` gitignore commit below it; tree clean; state `Executing`; current_spec_version `<NNN>`; `current.txt` reads `v<NNN>`; one committed spec at `spec/v<NNN>.yaml`; <N> assertion files under `contract/assertions/`; **zero** files under `contract/proposals/`. If any of this is wrong, STOP and surface to the operator before proceeding.

## What this session is for

Build the worker-runner machinery that turns a `mission dispatch` invocation into a real worker run against the committed contract. This session does NOT dispatch a worker. Building the machinery, reviewing it with the operator, and dispatching the first worker are separate steps — the same pattern as design-phase Checkpoint reviews. Operator review of the runner code happens before any worker runs in anger.

Specifically, this session produces:

1. **`tools/worker-runner/`** — the runner that shells out to `claude -p` (subscription auth per ADR-014), parses the stream-json output, writes trace events to `.mission-runtime/traces.sqlite`, validates worker handoffs against the schema in expanded-schemas.md §5, enforces tool-scope per the dispatch (worker can read repo, write only its assigned worktree, run sandboxed commands, no arbitrary network).
2. **`tools/mission-dispatch.ps1`** — the operator-facing entry point. Takes a dispatch spec (feature id, assertion targets, worktree kind), validates the dispatch is consistent with the committed spec/contract, spawns the worker-runner, monitors via the trace store.
3. **`tools/worktree-manager/`** — git-worktree lifecycle: create mainline-or-fanout worktree, install dependencies in isolation, port-assign for any local services, conflict-scan against other active worktrees, clean up.
4. **`tools/tool-gateway/`** — capability-tagged allowlist enforcer. Every tool call from the worker passes through the gateway; calls outside the dispatch's `tool_scope` are rejected with a structured error and logged.
5. **Updated `model-routing.yaml`** — model-class → provider mapping per ADR-005. coding-strong → claude-code-subscription (primary), ollama qwen2.5-coder:32b (fallback on rate-limit). coding-fast → ollama 7B. narrow-validator → ollama 7B. qa-validator → claude-code-subscription (vision; per ADR-013). Ensure the routing file is committed.
6. **Sandbox container** — per ADR-018, base image at `ghcr.io/anthropic/claude-mission-sandbox:vX.Y.Z` (verify current tag), per-monorepo extension via `docker/sandbox.Dockerfile`. Wire the `compose.yaml` to use it.

This is execution-phase infrastructure, NOT product code. No work begins under `src/` during this session — that happens in the first worker dispatch, which is its own ceremony.

## Operating discipline

The standing rules from design-phase carry forward:

- **ADR-020 filesystem verification.** After every commit, `git status` + `git log -1` confirm the commit landed. The task-tracker reads state from filesystem truth, never from tool-dispatch claims.
- **ADR-021 incremental commits.** One commit per artifact during multi-artifact passes. A stall or disconnect leaves verifiable partial progress. Atomic-by-design commits (like Phase 5 acceptance) are the exception, not the rule.
- **ADR-016 context cleanliness.** Sub-agent isolation for context-heavy work; structured note-taking through `.mission/`; tool-output filtering. Use Task() for browser automation, screenshot batches, multi-file traversal of unfamiliar code.
- **The credential seam is invariant.** The mission's credential assertions are frozen. No script in this session reads, transmits, or executes against product credentials. The worker-runner reads dispatch-context and prompt content; it does NOT read .env or any credential-backing-store. The credential-provider abstraction is product-code, not framework-code.
- **No Phase-5 spec edits.** The spec is frozen at v<NNN>. Discoveries that would change the contract land as amendments per §5.5 of the brief (versioned change, operator approval, possibly client-approval if material) — NOT as silent worker decisions.

## What to read before writing any code

In this order:

1. `.mission/spec/v<NNN>.yaml` — the committed spec. Pay particular attention to M-1's features and assertion targets; M-1 is what the first worker will eventually be dispatched against. (Not in this session — but the runner needs to support what M-1 demands.)
2. `.mission/contract/assertions/` — sample 5-10 assertions across the <N> to understand the shape of what validators will check. The runner's handoff-validation logic enforces the schema in expanded-schemas.md §5; understanding what assertions exist informs what handoffs need to look like.
3. `expanded-schemas.md` §4 (Worker Dispatch), §5 (Handoff Document), §9 (Trace Event), §10 (Worktree Record) — the four schemas the runner machinery serializes against. Read carefully. Schema enforcement at write-time is mandatory (per the cross-cutting note in expanded-schemas.md).
4. The five framework scripts under `tools/` (mission-init.ps1, mission-inputs-import.ps1, mission-design-start.ps1, mission-design-refine.ps1, mission-spec-accept.ps1) — style precedent for the new scripts. Match the comment-block discipline, the `[PASS]/[FAIL]` output format, the preflight pattern, the explicit-confirm-required pattern where mutations occur.
5. The ADRs under `tools/mission-cli/config/adr-0*.md` — particularly ADR-005 (model routing), ADR-013 (QA validator), ADR-014 (subscription auth + ANTHROPIC_API_KEY scrubbing), ADR-018 (sandbox base image), ADR-020 (filesystem verification), ADR-021 (incremental commits). These constrain how the runner machinery is built.
6. The local-orchestrator-mode doc (`local-orchestrator-mode.md`) — §6.2 (tool gateway), §6.3 (circuit breaker), §6.5 (worktree manager), §6.6 (sandbox/execution boundary). These are the framework requirements the runner must satisfy.

## Stopping checkpoint

After the six deliverables above are committed, STOP and surface to the operator:

- A summary of what was built and where it lives.
- A path-list of new files.
- An explicit invitation: "First-dispatch readiness check. Recommend operator review the runner code (tools/worker-runner/) and the dispatch script (tools/mission-dispatch.ps1) before the first worker is dispatched in anger. The first dispatch should target M-1, feature F-001 (or operator's choice), with conservative budget caps and verbose tracing enabled."

DO NOT dispatch a worker in this session. The first dispatch is the next ceremony — its own operator decision, its own checkpoint review, its own commit sequence.

## Failure modes to expect and surface

Predictable issues this session may hit, named so the agent doesn't silently work around them:

- **`claude` CLI availability and auth.** Per ADR-014, the runner shells out to `claude -p` and requires the operator's Pro/Max OAuth keychain entry. Verify `claude --version` and `claude --print "test"` work from the agent's environment BEFORE writing runner code that depends on them. The `ANTHROPIC_API_KEY` scrubbing in the runner is defensive — verify it actually scrubs by writing a test.
- **Ollama availability.** Required for the fallback path on coding-strong and as the primary for coding-fast + narrow-validator. Verify `docker compose up ollama` brings it up and that the configured models (qwen2.5-coder:32b, qwen2.5-coder:7b) are pulled. If models aren't present, surface this — pulling them is operator-initiated, not framework-initiated.
- **Sandbox base image pull.** Per ADR-018, GHCR-hosted. Verify the operator can pull `ghcr.io/anthropic/claude-mission-sandbox:vX.Y.Z` (specific tag from the ADR). On a corporate network, a TLS-intercepting proxy may break the pull, as it can break `npm install`. If the pull fails, surface immediately — the workaround is operator-side, not designer-side.
- **`expanded-schemas.md` schema enforcement.** Use a real schema library (Pydantic, JSON Schema) for handoff validation, NOT regex. The schemas are the contract surface for the runner's input/output validation; ad-hoc parsing risks silent acceptance of malformed handoffs.
- **Trace store schema.** `.mission-runtime/traces.sqlite` per ADR-003 + §6.4 of local-orchestrator-mode.md. Design the schema to support replay (per success criterion 14.3) and failure-cluster mining (per the eval-loop). OpenTelemetry-compatible shape is preferred per §12.7.

## Things that are explicitly out of scope for this session

- Writing any product code (under `src/`).
- Dispatching any worker.
- Modifying any committed spec, assertion, or ADR.
- Modifying the credential-provider abstraction or any module structure adjacent to the mission's credential assertions.
- Updating the framework's project-knowledge docs (the design brief, mode doc, bootstrap-instructions) — that's the parked doc-reconciliation backlog; not this session.
- Multi-mission concerns. This is a single mission; multi-mission resource scheduling is post-v1 per the brief §13.

## On the doc-reconciliation backlog

For context: three framework docs (multi-agent-framework-design-brief.md, local-orchestrator-mode.md, bootstrap-instructions-for-claude-code.md) are stale relative to ADRs 019–025 + the Phase 4.5 architecture-as-deliverable reality + the Phase 5 ceremony reality. The on-disk ADRs (under `tools/mission-cli/config/adr-0NN-*.md`) are canonical for those updates; the project-knowledge copies are stale. Do NOT use the project-knowledge docs as authority where they conflict with the on-disk ADRs. If a question arises that the docs disagree on, ADRs win — and surface the disagreement to the operator so the backlog gets a record of what needs reconciling.

## What "good" looks like at the end of this session

- Six deliverables committed under `tools/` (worker-runner, mission-dispatch, worktree-manager, tool-gateway, model-routing config, sandbox compose wiring).
- Each script readable from its docstring without the agent in the room.
- A clear "ready for first dispatch" message to the operator with: path-list of new files, summary of design choices, any failure-mode surprises encountered.
- Working tree clean. Git log shows incremental commits per ADR-021.
- Mission state still `Executing`; spec still v<NNN>; no contract or architecture mutations.

## Begin

Start by verifying the state per the commands at the top. Surface what you find. Then read the artifacts listed in "What to read before writing any code" — and surface a brief plan back to the operator before writing any new files. The plan-review-before-build pattern is the same one that worked for design phase: don't go heads-down on six deliverables without confirming the operator's mental model matches yours on shape and ordering.

If anything in this prompt reads as ambiguous, file a designer-flag-equivalent (a `.mission/ledger/entries.jsonl` entry of type `gotcha` or a question in your reply) and continue on the items that aren't ambiguous. Do NOT pause for clarification on items the operator did not pre-decide; the operator will resolve at the next checkpoint review.
