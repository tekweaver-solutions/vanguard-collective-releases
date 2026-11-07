# Multi-Agent Framework for Long-Running Software Engineering
## Architecture Design Brief

---

## 1. Purpose & Scope

Design a framework that lets a small number of humans direct AI agents through software engineering work that runs autonomously for **hours to weeks**, with minimal supervision and shippable output at the end.

The bottleneck this framework targets is **human attention**, not model intelligence. A modern model can plausibly attempt dozens of features in parallel; a human cannot review every commit. The framework's job is to make autonomous runs *trustworthy enough that humans only intervene at the seams*.

This document is a design brief. It specifies the architecture's **roles, artifacts, contracts, and failure semantics**. Implementation choices (specific frameworks, storage backends, model providers, UI) are deliberately left open and listed in §12.

---

## 2. Core Principles

These are non-negotiable design bets. Architecture choices must preserve them.

1. **The system is a state machine over a shared contract, not a conversation among agents.** Agents do not DM each other. All inter-agent communication goes through versioned artifacts (spec, handoffs, ledger, traces). This makes runs reproducible and resumable.
2. **Agents are pure functions on artifacts.** They read inputs, produce outputs, terminate. No persistent agent state outside the artifact store.
3. **The spec is the source of truth and it lives.** It is written before code, evolves through an explicit amendment protocol, and is versioned so old handoffs replay against the spec they targeted.
4. **Validation is adversarial and pre-committed.** The "definition of done" — a set of independent assertions — is written before any code. Validators never saw the implementation.
5. **Structure beats cleverness on long horizons.** Most day-10 failures are context rot, silent drift, and merge chaos — not intelligence failures. Fix them at the seams.
6. **Serial on shared mutable state. Parallel only when isolated.** Fan-out is reserved for work that cannot collide (research, isolated features in separate worktrees, read-only checks).
7. **Two kinds of drift, two different fixes.** *Factual drift* (forgetting what was decided) is fought with the memory ledger. *Alignment drift* (forgetting why) is fought with the validation contract. They are not interchangeable.
8. **Model-agnostic and role-typed.** Each role declares the model class it needs (strong reasoner, coding-strong, fast/cheap precise, vision-capable). The framework swaps models without changing logic, so it improves as models improve.
9. **Durable execution underneath everything.** Every LLM call and tool call is checkpointed. Any run is replayable from any point. Without this, nondeterministic failures at hour 200 are unfixable.
10. **Human attention is precious.** Default is autonomy. Escalation is cheap, well-defined, and rare.
---

## 3. System Diagram

```
                  human: high-level goal
                            │
                            ▼
                   ┌────────────────┐
       ┌──────────►│  ORCHESTRATOR  │◄─── eval feedback
       │           │ living spec +  │     (from prod traces)
       │ amend     │ contract +     │
       │ requests  │ milestones     │
       │           └───┬────────┬───┘
       │               │        │
       │               ▼        ▼
       │       ┌──────────┐  ┌────────────────┐
       │       │ MAINLINE │  │ FAN-OUT        │
       │       │ serial   │  │ parallel       │
       │       │ on code  │  │ in worktrees   │
       │       │ (1 wt)   │  │ + conflict scan│
       │       └────┬─────┘  └──────┬─────────┘
       │            │               │
       │            └─── typed ─────┘
       │                handoff
       │                  │
       │                  ▼
       │         ┌───────────────────┐
       │         │  VALIDATORS       │
       │         │ many narrow +     │
       │         │ end-to-end QA     │
       │         │ (read-only tools) │
       │         └─────┬─────────┬───┘
       │   pass        │         │ fail
       └───────────────┘         └──► amend / rework

  ───────── cross-cutting layers ─────────

  TOOL GATEWAY        capability-tagged, role-scoped allowlists
  CIRCUIT BREAKER     budget caps · loop detect · read→write gate
  MEMORY LEDGER       decisions, gotchas (fights factual drift)
  TRACE STORE         every call checkpointed, replayable
  EVAL LOOP           prod failures → clusters → new evals
  WORKTREE MANAGER    isolated filesystems + conflict scanner
  DURABLE RUNTIME     Postgres/SQLite checkpoints under everything
  MISSION CONTROL UI  async human monitoring + escalation inbox
```

---

## 4. Agent Roles

Each role has a defined input contract, output contract, model class, and tool scope. Agents within a role are interchangeable; the role is what's stable.

### 4.1 Orchestrator
- **Purpose:** Convert a human goal into a plan, contract, and milestone schedule. Own the spec. Adjudicate amendments.
- **Input:** Human goal + (optional) constraints, repo state, existing spec.
- **Output:** Living spec, validation contract (set of independent assertions), milestone schedule, dispatch decisions.
- **Model class:** Strong reasoner. Long context. Used sparingly; orchestrator runs are short and infrequent.
- **Tool scope:** Read-only against repo. Write access to spec/contract/milestone artifacts only. Cannot touch code.
- **Sole authority:** Spec amendments. No other role may modify the contract.
### 4.2 Worker
- **Purpose:** Implement one feature against the spec. Produce a structured handoff.
- **Input:** Spec snapshot (versioned), assigned feature, current handoff doc, repo at HEAD (or worktree HEAD for fan-out).
- **Output:** Code commits + structured handoff document.
- **Model class:** Coding-strong. Fresh context per worker — no inherited baggage.
- **Tool scope:** Read repo. Write only inside assigned worktree. Run tests/build inside sandbox. No network beyond approved registries.
- **Lifespan:** One feature, then terminates. The next worker spawns clean from the handoff, not from the previous worker's context.
### 4.3 Validator
- **Purpose:** Adversarial verification against the contract.
- **Two sub-types:**
  - **Narrow validator** — owns one contract assertion. Cheap, parallel, hard to rationalize away. A 200-assertion contract spawns up to 200 narrow validators.
  - **QA validator** — runs the application end-to-end (computer-use, integration tests, behavioral flows). Slower, fewer in number, catches behavior not visible in unit assertions.
- **Input:** Built artifact + assertion(s) to check. Validators do **not** see implementation history or prior worker reasoning.
- **Output:** Pass/fail per assertion + evidence (logs, screenshots, failing inputs).
- **Model class:** Precise, cost-efficient for narrow validators; coding-strong + computer-use for QA.
- **Tool scope:** Read-only against the running app. May execute tests. Cannot modify code, spec, or ledger.
### 4.4 Human
First-class participant, not a fallback. Has defined touchpoints (§11), not arbitrary interruption.

---

## 5. Artifacts

Everything that flows through the system is a typed, versioned artifact. Schemas below are illustrative, not prescriptive.

### 5.1 Living Spec
The shared source of truth. Versioned. Each amendment produces a new version.

```yaml
version: 17
goal: "..."
features:
  - id: F-003
    title: "..."
    status: in_progress | done | blocked
    assigned_milestone: M-2
milestones:
  - id: M-2
    features: [F-003, F-004]
    contract_assertions: [A-021..A-047]
decisions:
  - id: D-009
    summary: "Chose Postgres over SQLite for X"
    rationale: "..."
    superseded_by: null
```

### 5.2 Validation Contract
Independent, assertion-level. Each assertion is checkable in isolation by a narrow validator. Written **before** implementation.

```yaml
- id: A-021
  feature: F-003
  type: behavioral | structural | performance | security
  assertion: "POST /users with duplicate email returns 409"
  evidence_required: [test_output, http_trace]
  owner_validator: narrow
- id: A-088
  feature: F-007
  type: behavioral
  assertion: "Login flow completes in under 3s on fresh session"
  owner_validator: qa
```

### 5.3 Handoff Document
Structured (JSON or YAML), not prose. Schema-validated at boundaries.

```yaml
from_worker: w-2025-04-12-a3
feature: F-003
spec_version: 17
completed_assertions: [A-021, A-022]
unfinished: 
  - assertion: A-023
    reason: "Requires schema migration not yet specified"
suggested_next: "Run amendment cycle for migration policy"
commits: [sha1, sha2]
commands_run:
  - cmd: "pytest tests/users/"
    exit_code: 0
issues_observed:
  - "Existing helper validate_email() does not handle Unicode"
procedure_adherence: confirmed | deviated
deviation_notes: null
```

### 5.4 Memory Ledger
Append-only. Written by validators (and orchestrator on amendments). Readable by all roles. Fights *factual* drift only.

```yaml
- ts: 2025-04-12T14:22Z
  type: gotcha | decision | constraint
  scope: feature | global
  content: "API rate limit on Stripe sandbox is 25 req/s, not 100"
  source_trace: trace-9871
```

### 5.5 Amendment
Versioned spec change. Proposed by any role, approved only by orchestrator (and human, if material).

```yaml
proposed_by: w-2025-04-12-a3
target_assertion: A-035
change: "Relax response time from 100ms to 500ms"
rationale: "Vendor API latency unavoidable"
material_change: true   # → human approval required
```

### 5.6 Trace Event
Every LLM call and every tool call. Parent-child structured. Replayable.

```yaml
trace_id: trace-9871
parent: trace-9870
agent: w-2025-04-12-a3
type: llm_call | tool_call
model: <if llm_call>
prompt_version: <if llm_call>
tokens_in: ...
tokens_out: ...
cost_usd: ...
duration_ms: ...
input: { ... }   # full, not summarized
output: { ... }
```

---

## 6. Cross-Cutting Infrastructure Layers

### 6.1 Durable Runtime
The substrate. Every artifact write and every trace event is checkpointed to durable storage (Postgres or equivalent). Runs survive process crashes, deploys, and OS restarts. Any run is **replayable from any checkpoint**, which is what makes nondeterministic failures debuggable.

### 6.2 Tool Gateway
Single point of tool invocation. Enforces:
- **Capability-based allowlists per role.** Orchestrator: read repo, write spec. Worker: write its worktree, run sandboxed tests. Validator: read-only + test execution.
- **Parameter validation.** Tool calls with out-of-scope arguments (wrong tenant, wrong path, wrong cluster) are rejected before reaching the tool.
- **Audit trail.** Every call logs to the trace store.
### 6.3 Circuit Breaker
Three-state machine: `closed` (normal), `open` (halt), `half-open` (cautious retry).

Triggers:
- **Budget breach.** Per-worker, per-mission, per-day token/cost caps. Soft cap → warning. Hard cap → degrade to read-only safe mode.
- **Loop detection.** Poll-no-progress: same tool, same args, no state change after N iterations → escalate.
- **Read→write transition.** When an agent's plan shifts from read-only to mutating actions, pause and require approval (configurable per mission risk level).
- **Repeated validator failure.** Same assertion failing N times in a row → escalate, do not keep retrying.
### 6.4 Trace Store + Eval Loop
The trace store is more than logging. It is the substrate for continuous improvement:
1. Production traces accumulate.
2. Failure-pattern clustering identifies recurring breakdowns.
3. Failure clusters become regression evals.
4. Evals run against new prompt versions before deployment.
5. Prompt versions are first-class versioned artifacts (treated like code).
### 6.5 Worktree Manager + Conflict Scanner
- Each fan-out worker gets a git worktree (separate working directory, shared object store, own branch).
- Worktree manager handles creation, port assignment, isolated dependency installs, and cleanup.
- Conflict scanner runs continuously across active worktrees, surfacing collisions *during* work rather than at PR time. Workers approaching conflicting regions get warned (or paused, configurable).
- Mainline workers all share one worktree and run serially. This is intentional: most code work touches shared state, and serial-with-handoffs is dramatically more reliable than parallel-with-merges.
### 6.6 Sandbox / Execution Boundary
Worktrees give *file* isolation. The framework also requires *process and network* isolation:
- Workers run inside containers (or equivalent) with restricted filesystem mounts.
- Network policy: only approved registries (npm, pypi, internal) reachable. No outbound to arbitrary domains.
- Test execution and computer-use happen inside the same sandbox, never on the orchestrator's host.
### 6.7 Mission Control UI
Async human interface. Not for real-time micromanagement.
- Live mission status (current milestone, active workers, budget burn).
- Escalation inbox (amendments, approvals, blocked items).
- Trace explorer (drill into any past decision).
- Mission audit trail (full reproducibility on demand).

v1 is specified by LM2-ADR-045 (read-only local dashboard, `vanguard ui`); §12.9 carries the status.

---

## 7. Mission Lifecycle

```
  CREATED
     │
     ▼
  PLANNING ─────┐
     │          │ amendment
     ▼          │
  EXECUTING ◄───┘
     │  (worker → handoff → worker → ...)
     │
     ▼
  VALIDATING (per milestone)
     │
     ├── all assertions pass ──► next milestone (back to EXECUTING)
     ├── failures              ──► REWORK (back to EXECUTING)
     └── contract impossible   ──► AMENDMENT (back to PLANNING)
     │
     ▼  (final milestone passes)
  HUMAN_APPROVAL
     │
     ▼
  COMPLETE
```

**Termination ("done") requires all of:**
- Every contract assertion passes its validator.
- QA validator approves end-to-end behavior.
- No open amendment requests.
- Human signoff (always required for mission completion, regardless of automation).
---

## 8. Failure Handling

| Failure | Detection | Response |
|---|---|---|
| Worker crash mid-task | Durable runtime checkpoint | Replay from last checkpoint, or respawn fresh worker from prior handoff |
| Worker produces invalid handoff | Schema validation at boundary | Reject; respawn worker with the validation error in context |
| Validator finds contract violation | Validator output | Scope corrective work; spawn worker with failure evidence |
| Same assertion fails repeatedly | Circuit breaker (loop detect) | Escalate to human; do not retry blindly |
| Worker exceeds budget | Tool gateway accounting | Degrade to read-only; require approval to continue |
| Spec is impossible as written | Worker filed amendment | Orchestrator decides; human approves if material |
| Worker tries out-of-scope tool/param | Tool gateway rejection | Logged, fed back as constraint; worker retries |
| Trace store unreachable | Health check | Halt new runs; existing runs survive on local checkpoint |
| Cross-worktree conflict detected | Conflict scanner | Pause one worker; orchestrator decides ordering |

---

## 9. Drift Defenses

| Drift Type | What It Is | Defense |
|---|---|---|
| **Factual** | Agents forget what was decided/built | Memory ledger (append-only, queryable) + spec versioning |
| **Alignment** | Agents remember decisions but optimize for the wrong thing | Validation contract written before code, narrow validators that re-check intent at every milestone |
| **Context rot** | Long context degrades model attention to mid-context info | Fresh context per worker, structured handoffs (high-signal, low-volume) |
| **Specification** | Spec ambiguity → agents fill gaps with wrong assumptions | Living spec with explicit amendment protocol; gaps surface as amendment requests, not silent assumptions |

---

## 10. Concurrency Model

| Pattern | When to use | Mechanism |
|---|---|---|
| **Serial mainline** | Default for any work touching shared mutable state | Single worktree, one worker at a time, handoff between |
| **Fan-out parallel** | Independent features, research, isolated subsystems, read-only analysis | Separate worktrees per worker, conflict scanner active, merge sequenced by orchestrator |
| **Validator parallel** | Always | Narrow validators are stateless and read-only; fan out as wide as cost allows |
| **Forbidden** | Two workers modifying overlapping mutable state | Conflict scanner prevents; orchestrator must serialize them |

The default bias is **serial**. Parallel is justified only when the work is provably non-conflicting.

---

## 11. Human-in-the-Loop Touchpoints

Defined, not arbitrary. The human is consulted at:

1. **Mission kickoff** — goal capture, scope negotiation with orchestrator.
2. **Material amendments** — spec changes that alter scope, cost, or external commitments.
3. **Read→write escalation** — first time a mission shifts from analysis to mutating actions (configurable; can be auto-approved for low-risk missions).
4. **Repeated failure** — same assertion failing N times, or budget hard-cap breached.
5. **Mission completion** — final signoff. Never automated.
Between these touchpoints, the human monitors via Mission Control UI but is not expected to act. Notifications are batched. Default escalation channel: async (email/Slack), not synchronous.

---

## 12. Architectural Decisions — status (back-filled 2026-11-01)

This section was written as a list of open choices for the receiving architect. It is now a status
register. Legend: CLOSED — ruled and recorded (ADR cited); PROPOSED — a design exists and the fork
is named, no ruling; OPEN — deliberately unresolved, with the condition that reopens it; DEFERRED — out of v1 by ruling, with what keeps it from being foreclosed; CLOUD-GATED —
not designed until a hosted customer exists. "Local" is Local Orchestrator / Local Autonomous Mode on
one workstation (local-modes v2.3 §3); "Cloud" is Hosted Autonomous Mode, designed-not-built.

1. **Durable runtime platform.** Local CLOSED: git holds `.mission/` (LM2-ADR-003) and the evidence
   plane holds per-dispatch manifests (LM2-ADR-021); the runner spawns workers as pure functions
   (LM2-ADR-023). Replay is re-execution from recorded inputs (spec version, brief bytes by sha256, base
   commit) against the captured transcript — LLM nondeterminism means re-execute, never reproduce.
   What this gives up: Principle 9 holds at dispatch granularity, not per call; a crash mid-dispatch
   resumes from the handoff or the PARTIAL manifest, not from the last tool call. Cloud PROPOSED:
   CR-3 — Postgres mirror of artifacts + WORM evidence store + `replay <dispatch_id>`. Watchlist,
   no decision: Claude Managed Agents as hosted substrate (agent loop and session state would live
   outside the framework's checkpoint ownership).
2. **Storage backend.** Local CLOSED: `.mission/` tracked in git is canonical; `.mission-runtime/`
   untracked holds evidence, gates' runtime state and telemetry. There is no query engine locally:
   instruments and grep are the query layer, and the dashboard's SQLite projection (LM2-ADR-045) is a
   disposable cache, never storage. Cloud PROPOSED: the CR-3 Postgres mirror, which depends on
   published JSON Schemas (item 4).
3. **Sandboxing technology.** Local CLOSED: layered (LM2-ADR-027) — Docker as the outer, user-owned
   boundary; the sandboxed Bash tool as the near-zero-startup inner layer for validator swarms.
   Named limit: a native Windows session has no mount namespace, so evidence-machinery exclusion
   (v2.3 §4.1 layer (a)) does not exist locally; the PreToolUse guard is an accident tripwire, not a
   boundary (v2.3 §4.5 law 1). Cloud PROPOSED: CR-2 — a seat container image (Linux, pwsh 7,
   Python, Claude Code / Agent SDK) with mount exclusion and an egress allowlist; doubles as the
   devcontainer for non-Windows Local.
4. **Schema enforcement.** CLOSED: Pydantic at the runner boundary for Handoff, ValidatorResult,
   Report, Amendment (LM2-ADR-024); invalid → reject + respawn (§8). Refinement PROPOSED, not ruled
   (P5 / LH-6): JSON Schema as the canonical form with Pydantic generated from it, so a Cloud
   mirror and the dashboard validate against the same files. Precedent already on disk: the
   Evidence Manifest ships as JSON Schema 1.2.0; the `mission-event` artifact (LM2-ADR-045) follows that
   precedent without pre-empting P5.
5. **Worktree management.** CLOSED: Claude Code native worktrees with `.worktreeinclude`
   (LM2-ADR-026); custom orchestration deleted. Merge sequencing stays framework-owned and the
   operator's `--no-ff` merge at the root is the trust boundary for tooling branches.
6. **Conflict scanner.** OPEN on purpose. Nothing native detects cross-worktree conflict. PROPOSED
   for v1 (LH-7): file-level — each dispatch declares `writes:` globs, the guard refuses writes
   outside them, a check reports overlap across active worktrees (mechanizes today's hand-written
   pair-proof table). AST-level or behavioral only after file-level has measured how often it is too
   coarse.
7. **Trace store backend.** PROPOSED, not ruled (LH-3): Claude Code's native OpenTelemetry metrics
   and events into a collector, with resource attributes `mission_id, dispatch_id, role,
   prompt_version` set by the runner; usage and cost anchors read from transcript snapshots in the
   evidence plane, never from telemetry (telemetry's cost metric is an estimate for trends). The
   backend fork — OTel-compatible, LLM-native, self-hosted — is open. The dashboard's
   `events.jsonl` (LM2-ADR-045) is not the trace store and carries no LLM-call content.
8. **Eval framework.** Half CLOSED: cadence work (archive scans, prompt-regression checks,
   pre-witness deploy-currency checks) runs as scheduled routines whose output counts only once it
   lands in `.mission/` (LM2-ADR-030). PROPOSED (LH-5): prompt versions as artifacts — brief templates
   under `prompts/`, `prompt_version` = template id + sha256 on every spawn line (validator prompts'
   sha256 already recorded). Failure clustering → regression evals DEFERRED until traces from ≥ 2
   missions exist; today the loop is retrospective → batch, by hand.
9. **Mission Control UI.** CLOSED for v1 by LM2-ADR-045, which supersedes LM2-ADR-029: a read-only,
   local-machine dashboard (`vanguard ui`) projecting each project's `mission-event` feed; no
   commands, no messages to agents. LM2-ADR-029's native surfaces (agent view, channels, Artifacts)
   remain the operator's surfaces at the seat; what LM2-ADR-045 replaces is the deferral of a custom UI
   and the claim that native surfaces are the product's face. Web app only; no terminal UI or IDE
   plugin.
10. **Multi-mission resource management.** DEFERRED on purpose (out of v1, §13). Two rulings keep
    it from being foreclosed: hosted mode, if built, is bring-your-own-cloud so each customer's
    missions run on their own compute and model quota (productization F2, deferred with Cloud);
    and every `mission-event` carries `mission_id + host_id + seq` and the dashboard speaks only to
    `/api/*`, so a fleet view over many hosts is an endpoint re-implementation, not a schema change.
11. **Identity and permissions.** OPEN; CLOUD-GATED. Local today: the operator's console
    credential mints gates, the push gate is a hash-bound single-use artifact (LM2-ADR-033), and the only
    credential the framework handles is the model key, read from the environment in API-key mode
    (release 0.3.0) and never stored. PROPOSED for Cloud (CR-1): per-role scoped Git-provider tokens
    (worker: branch push; validator: read; main only after a verified signed gate) and secrets in
    the data plane's manager. Also gates the dashboard's v2 control path (human-authored
    touchpoint artifacts through the UI) — not designed until this item is.
12. **Cost attribution.** PROPOSED, not ruled: per-dispatch and per-arc caps and showback derive
    from transcript-derived anchors (LH-4, a `budget_within` detector reading the evidence plane);
    billing-grade figures come from the provider (usage reporting per workspace or key, or the
    customer's cloud bill). Attribution keys per mission / feature / role follow the Role Manifest
    (LH-1), not built. The dashboard shows no cost figure until an anchor exists (LM2-ADR-045).

Sources of record: local-modes v2.3 §5 (LM2-ADR-023–035) and §11; the productization recommendation of
2026-10-19 (§5 triage LH-1…7, CR-1…5; §9; §11 rulings); release 0.3.0 (API-key mode); LM2-ADR-045.
These are framework decisions; the operator's host ledger carries the rulings that made them.

---

## 13. Non-Goals

To keep the design honest, the framework does **not** aim to:

- Replace human architectural judgment on novel systems.
- Operate without any human touchpoints.
- Eliminate code review (it shifts review from per-commit to per-milestone).
- Be useful for ad-hoc one-shot prompts (use a single agent for that).
- Guarantee correctness — only make failures observable, recoverable, and bounded.
---

## 14. Success Criteria for the Architecture

A successful design will:

1. Run a non-trivial project (10+ features, 5+ milestones) for **multiple days** without human intervention except at defined touchpoints.
2. Survive process crashes, model API outages, and deploy-mid-run without losing work.
3. Make any past decision **inspectable and replayable** from the trace store.
4. Catch contract violations *before* they reach the human for review.
5. Improve over time via the eval loop, not degrade from prompt rot.
6. Swap to a new model class for any role with a config change, not a rewrite.