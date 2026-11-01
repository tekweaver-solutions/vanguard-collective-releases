# Expanded Artifact Schemas
 
This document provides field-level schemas for every artifact that flows through the framework. It complements §5 of the architecture design brief.
 
For each artifact:
- **Purpose** — what it represents and why it exists
- **Authors** — which roles can create/mutate it
- **Readers** — which roles can read it
- **Lifecycle** — when it is created, mutated, sealed
- **Fields** — name, type, required, description, constraints
- **Example** — a fully populated, realistic instance
Schemas are illustrated in YAML with explicit type annotations. The implementing architect should formalize them in the schema language of their choice (JSON Schema, Protobuf, Pydantic, etc.). Field types use a simple notation: `string`, `int`, `float`, `bool`, `timestamp` (ISO 8601 UTC), `uuid`, `enum<...>`, `list<T>`, `map<K,V>`, `ref<Artifact>` (pointer by id).
 
All artifacts share three implicit fields enforced by the runtime:
- `id: uuid` — unique
- `created_at: timestamp` — set at write
- `created_by: string` — agent or human identifier
---
 
## 1. Mission
 
### Purpose
Top-level container. One mission represents one autonomous engagement, from goal capture to completion.
 
### Authors
Orchestrator (creates, transitions states). Human (cancels, approves completion).
 
### Readers
All roles.
 
### Lifecycle
Created on goal capture. Transitions through the lifecycle state machine. Sealed on `Complete` or `Aborted`. Never deleted.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | Mission identifier. |
| `goal` | string | yes | Human's original goal, verbatim. |
| `clarified_scope` | string | yes | Orchestrator's negotiated interpretation, confirmed by human. |
| `state` | enum | yes | One of: `Created`, `Planning`, `Executing`, `Validating`, `Amending`, `Reworking`, `Blocked`, `AwaitingApproval`, `Complete`, `Aborted`. |
| `current_spec_version` | int | yes | Pointer to the active spec version. |
| `current_milestone` | ref\<Milestone\> | no | Active milestone, if any. |
| `budget` | object | yes | See *Budget* sub-schema below. |
| `risk_level` | enum | yes | `low`, `medium`, `high`. Drives default circuit-breaker thresholds and read→write gate behavior. |
| `human_owner` | string | yes | Identifier of the human responsible for approvals. |
| `notification_channel` | string | yes | Where escalations go (Slack channel, email, etc.). |
| `created_at` | timestamp | yes | |
| `completed_at` | timestamp | no | Set on `Complete` or `Aborted`. |
 
### Budget sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `cost_soft_cap_usd` | float | yes | Triggers warning. |
| `cost_hard_cap_usd` | float | yes | Triggers circuit breaker → safe mode. |
| `wallclock_soft_cap_hours` | int | yes | |
| `wallclock_hard_cap_hours` | int | yes | |
| `tokens_used` | int | yes | Updated continuously. |
| `cost_used_usd` | float | yes | Updated continuously. |
 
### Constraints
- `state` transitions must follow the lifecycle state machine; arbitrary transitions are rejected by the runtime.
- `current_spec_version` must reference a spec that exists.
- Hard caps must be ≥ soft caps.
### Example
 
```yaml
id: mission-a3f7
goal: "Build a Slack-clone with channels, DMs, threads, and presence"
clarified_scope: "Web-only MVP. No mobile, no voice/video. Single workspace.
                  Auth via SSO only. ~10 features over 4 milestones."
state: Executing
current_spec_version: 12
current_milestone: M-2
budget:
  cost_soft_cap_usd: 500.00
  cost_hard_cap_usd: 1000.00
  wallclock_soft_cap_hours: 168
  wallclock_hard_cap_hours: 336
  tokens_used: 14_220_000
  cost_used_usd: 287.40
risk_level: medium
human_owner: "alice@example.com"
notification_channel: "slack:#mission-a3f7"
created_at: 2026-04-22T09:00:00Z
completed_at: null
```
 
---
 
## 2. Living Spec
 
### Purpose
The shared source of truth. Encodes goals, features, milestones, and decisions. Versioned: every amendment creates a new immutable revision.
 
### Authors
Orchestrator only.
 
### Readers
All roles.
 
### Lifecycle
Created at planning. Each amendment produces version `n+1`. Old versions are retained immutably so prior handoffs replay against the spec they targeted.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `mission_id` | ref\<Mission\> | yes | |
| `version` | int | yes | Monotonically increasing. |
| `previous_version` | int | no | Null on v1. |
| `created_from_amendment` | ref\<Amendment\> | no | Null on v1. |
| `goal` | string | yes | May restate Mission.goal for self-containment. |
| `scope_inclusions` | list\<string\> | yes | Explicitly in scope. |
| `scope_exclusions` | list\<string\> | yes | Explicitly out of scope. Prevents agents from "helpful" overreach. |
| `features` | list\<Feature\> | yes | See *Feature* sub-schema. |
| `milestones` | list\<Milestone\> | yes | See *Milestone* sub-schema. |
| `decisions` | list\<Decision\> | yes | See *Decision* sub-schema. |
| `constraints` | list\<string\> | no | Non-functional requirements (perf, security, etc.). |
| `tech_stack` | map\<string,string\> | no | E.g. `{language: python, db: postgres}`. |
 
### Feature sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Stable across versions. E.g. `F-003`. |
| `title` | string | yes | |
| `description` | string | yes | |
| `status` | enum | yes | `pending`, `in_progress`, `done`, `blocked`. |
| `assigned_milestone` | string | yes | Milestone id. |
| `dependencies` | list\<string\> | no | Other feature ids this depends on. |
 
### Milestone sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | E.g. `M-2`. |
| `title` | string | yes | |
| `features` | list\<string\> | yes | Feature ids in this milestone. |
| `contract_assertion_ids` | list\<string\> | yes | Assertions checked at this milestone boundary. |
| `status` | enum | yes | `pending`, `active`, `validating`, `passed`, `failed`. |
 
### Decision sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | E.g. `D-009`. |
| `summary` | string | yes | One sentence. |
| `rationale` | string | yes | |
| `superseded_by` | string | no | Decision id, if revised. |
| `made_at` | timestamp | yes | |
 
### Constraints
- Spec versions are immutable once written.
- A feature id, once introduced, cannot be reassigned to a different feature; it can only be marked obsolete via amendment.
- Every `assigned_milestone` must reference an existing milestone.
### Example
 
```yaml
mission_id: mission-a3f7
version: 12
previous_version: 11
created_from_amendment: amend-0033
goal: "Slack-clone web app, MVP scope"
scope_inclusions:
  - "Channels (public, private)"
  - "Direct messages"
  - "Threads"
  - "Presence indicator"
scope_exclusions:
  - "Voice/video calling"
  - "Mobile apps"
  - "Multi-workspace tenancy"
features:
  - id: F-003
    title: "Channel CRUD"
    description: "Create, rename, archive, delete channels..."
    status: in_progress
    assigned_milestone: M-2
    dependencies: [F-001]
milestones:
  - id: M-2
    title: "Channels and DMs"
    features: [F-003, F-004]
    contract_assertion_ids: [A-021, A-022, ..., A-047]
    status: active
decisions:
  - id: D-009
    summary: "Postgres over SQLite for chat history"
    rationale: "Need full-text search and concurrent writes"
    superseded_by: null
    made_at: 2026-04-22T11:30:00Z
constraints:
  - "P95 message-send latency < 200ms"
  - "All endpoints must require authenticated session"
tech_stack:
  language: typescript
  framework: nextjs
  db: postgres
```
 
---
 
## 3. Validation Contract Assertion
 
### Purpose
A single, independently checkable statement of correctness. The contract is the union of all assertions across all milestones.
 
### Authors
Orchestrator (creates), with human approval at planning. Amendments may modify via the amendment protocol.
 
### Readers
All roles, especially validators.
 
### Lifecycle
Created at planning, before any code. Immutable except via amendment. Each assertion is owned by exactly one milestone.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | E.g. `A-021`. |
| `feature_id` | string | yes | Feature this assertion is for. |
| `milestone_id` | string | yes | When this assertion is checked. |
| `type` | enum | yes | `behavioral`, `structural`, `performance`, `security`, `accessibility`. |
| `assertion` | string | yes | Natural-language statement, must be testable. |
| `validator_type` | enum | yes | `narrow` or `qa`. |
| `evidence_required` | list\<enum\> | yes | E.g. `test_output`, `http_trace`, `screenshot`, `metric`, `log`. |
| `acceptance_criteria` | string | yes | What "pass" means, concretely. |
| `priority` | enum | yes | `must`, `should`. `must` blocks milestone completion. |
| `superseded_by` | string | no | Assertion id if revised. |
 
### Constraints
- Every assertion must be checkable independently of other assertions.
- An assertion may not depend on the outcome of another assertion.
- If `validator_type: qa`, the assertion must describe behavior observable from outside the system.
### Example
 
```yaml
id: A-021
feature_id: F-003
milestone_id: M-2
type: behavioral
assertion: "POST /api/channels with a name that already exists in the workspace
            returns HTTP 409 Conflict and does not mutate state"
validator_type: narrow
evidence_required:
  - test_output
  - http_trace
acceptance_criteria: "Test asserts status 409, response body contains
                      error.code == 'channel_name_taken', and a follow-up
                      GET /api/channels returns the same list as before"
priority: must
superseded_by: null
```
 
---
 
## 4. Worker Dispatch
 
### Purpose
The instruction the orchestrator gives a worker when starting it. The worker's full input contract.
 
### Authors
Orchestrator only.
 
### Readers
The dispatched worker. Logged for trace.
 
### Lifecycle
Created on dispatch, immutable thereafter. One per worker invocation.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | |
| `mission_id` | ref\<Mission\> | yes | |
| `worker_id` | string | yes | Stable identifier for this worker instance. |
| `kind` | enum | yes | `mainline`, `fanout`, `rework`. |
| `feature_id` | string | yes | Feature this worker is implementing. |
| `assertion_targets` | list\<string\> | yes | Assertions this worker should make pass. |
| `spec_version` | int | yes | Spec version to read against. |
| `prior_handoff_id` | ref\<Handoff\> | no | The handoff this worker is starting from. |
| `worktree_id` | ref\<Worktree\> | yes | Where this worker writes. |
| `model_class` | enum | yes | E.g. `coding-strong`, `coding-fast`. Resolved to a concrete model by the runtime. |
| `tool_scope` | list\<string\> | yes | Capability-tagged tools this worker may invoke. |
| `budget` | object | yes | Per-worker cost/wallclock cap. |
| `rework_evidence` | object | no | If `kind: rework`, includes failing assertion id and validator evidence. |
 
### Example
 
```yaml
id: dispatch-7b21
mission_id: mission-a3f7
worker_id: w-2026-04-22-c3
kind: mainline
feature_id: F-003
assertion_targets: [A-021, A-022, A-023, A-024, A-025]
spec_version: 12
prior_handoff_id: handoff-7b20
worktree_id: wt-mainline
model_class: coding-strong
tool_scope:
  - repo.read
  - worktree.write
  - shell.exec.sandboxed
  - test.run
  - package.install.allowlisted
budget:
  cost_cap_usd: 25.00
  wallclock_cap_minutes: 90
rework_evidence: null
```
 
---
 
## 5. Handoff Document
 
### Purpose
The structured artifact a worker emits on completion. It is the **only** information that propagates to the next worker. Workers do not inherit context windows.
 
### Authors
Worker that produced it.
 
### Readers
Orchestrator (always). Next worker (if dispatched as continuation). Validators (for context).
 
### Lifecycle
Created on worker completion (or graceful timeout). Immutable. Schema-validated at boundary; rejected handoffs cause worker respawn.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | |
| `from_worker` | string | yes | Worker id that produced this. |
| `dispatch_id` | ref\<Dispatch\> | yes | The dispatch this completes. |
| `feature_id` | string | yes | |
| `spec_version` | int | yes | The version this work targeted. |
| `completed_assertions` | list\<string\> | yes | Assertion ids the worker believes it satisfied. |
| `unfinished` | list\<UnfinishedItem\> | yes | Empty list if none. See sub-schema. |
| `commits` | list\<string\> | yes | Git SHAs created. |
| `commands_run` | list\<CommandLog\> | yes | See sub-schema. |
| `issues_observed` | list\<string\> | yes | Notes on the codebase the worker noticed. Feeds the ledger. |
| `suggested_next` | string | no | Recommendation for the next dispatch. Advisory only. |
| `procedure_adherence` | enum | yes | `confirmed` or `deviated`. |
| `deviation_notes` | string | conditional | Required if `deviated`. |
| `terminated_reason` | enum | yes | `completed`, `budget_exhausted`, `tool_blocked`, `amendment_filed`, `crash_recovered`. |
 
### UnfinishedItem sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `assertion_id` | string | yes | |
| `reason` | string | yes | Why not completed. |
| `partial_progress` | string | no | What was done. |
| `blocker` | enum | no | `spec_ambiguous`, `dependency_missing`, `tool_unavailable`, `time_exhausted`, `unknown`. |
 
### CommandLog sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `cmd` | string | yes | The command executed. |
| `exit_code` | int | yes | |
| `stderr_excerpt` | string | no | Last N lines if non-zero exit. |
 
### Constraints
- A handoff with non-empty `unfinished` and `terminated_reason: completed` is invalid.
- Every `completed_assertions` entry must be in the dispatch's `assertion_targets`.
- `procedure_adherence: deviated` without `deviation_notes` is invalid.
### Example
 
```yaml
id: handoff-7b21
from_worker: w-2026-04-22-c3
dispatch_id: dispatch-7b21
feature_id: F-003
spec_version: 12
completed_assertions: [A-021, A-022, A-024, A-025]
unfinished:
  - assertion_id: A-023
    reason: "Requires a schema migration that the spec doesn't yet describe"
    partial_progress: "Wrote the application code; migration file is stubbed"
    blocker: spec_ambiguous
commits:
  - "<earlier-commit-sha>"
  - "<head-commit-sha>"
commands_run:
  - cmd: "pnpm test channels"
    exit_code: 0
  - cmd: "pnpm lint"
    exit_code: 0
issues_observed:
  - "validate_channel_name() in src/util doesn't handle Unicode normalization"
  - "Test fixtures in tests/fixtures/users.json have stale schema"
suggested_next: "File amendment for migration policy on A-023, then dispatch
                 a worker to complete it"
procedure_adherence: confirmed
deviation_notes: null
terminated_reason: amendment_filed
```
 
---
 
## 6. Validator Result
 
### Purpose
A single validator's verdict on one or more assertions, with evidence.
 
### Authors
The validator that produced it.
 
### Readers
Orchestrator (drives milestone progression). Workers (when dispatched for rework, sees the failing result).
 
### Lifecycle
Created on validator completion. Immutable. Failures may be retried; each retry is a new result.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | |
| `validator_id` | string | yes | |
| `validator_type` | enum | yes | `narrow` or `qa`. |
| `assertion_id` | string | conditional | Required if `narrow`. |
| `assertion_ids` | list\<string\> | conditional | Required if `qa`. May cover many. |
| `verdict` | enum | yes | `pass`, `fail`, `inconclusive`. |
| `evidence` | list\<EvidenceItem\> | yes | See sub-schema. Required even on pass for audit. |
| `failure_summary` | string | conditional | Required on `fail` or `inconclusive`. |
| `attempt_number` | int | yes | 1 for first attempt; increments on rework cycles. |
| `commit_sha` | string | yes | The exact commit validated. |
 
### EvidenceItem sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `type` | enum | yes | `test_output`, `http_trace`, `screenshot`, `log`, `metric`, `manual_observation`. |
| `content` | string | yes | Inline payload or pointer to blob storage. |
| `description` | string | yes | What this evidence shows. |
 
### Example
 
```yaml
id: valresult-9c4f
validator_id: val-narrow-A023
validator_type: narrow
assertion_id: A-023
verdict: fail
evidence:
  - type: test_output
    content: "FAIL test_channel_rename_persists_across_restart"
    description: "Test fails: channel name reverts after server restart"
  - type: http_trace
    content: "blob://traces/run-9c4f-trace.json"
    description: "Full request/response cycle"
failure_summary: "Channel rename is not persisted to the database;
                  appears to only update the in-memory cache"
attempt_number: 1
commit_sha: "<head-commit-sha>"
```
 
---
 
## 7. Memory Ledger Entry
 
### Purpose
Append-only durable record of decisions, gotchas, and constraints discovered during the mission. Fights factual drift.
 
### Authors
Validators (primary, on observed gotchas). Orchestrator (on decisions made during amendments).
 
### Readers
All roles. Workers query the ledger before starting a feature.
 
### Lifecycle
Append-only. Entries are never modified or deleted. An entry can be marked `stale` by a later entry but the original remains.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | |
| `ts` | timestamp | yes | |
| `author` | string | yes | Agent or human id. |
| `type` | enum | yes | `gotcha`, `decision`, `constraint`, `correction`. |
| `scope` | enum | yes | `global`, `milestone`, `feature`. |
| `scope_ref` | string | conditional | Milestone or feature id, required if scope is not global. |
| `content` | string | yes | The actual learning. Should be self-contained. |
| `source_trace_id` | uuid | no | Trace that produced this finding. |
| `supersedes` | uuid | no | Earlier entry this corrects. |
| `tags` | list\<string\> | no | For retrieval. |
 
### Constraints
- Entries are immutable. To correct, write a new `correction` entry referencing the old.
- `scope_ref` must reference a real entity if scope is not `global`.
### Example
 
```yaml
id: ledger-4d12
ts: 2026-04-23T08:14:22Z
author: val-qa-M2
type: gotcha
scope: global
scope_ref: null
content: "Stripe sandbox API rate limit is 25 req/s, not the 100 req/s
          documented. Burst above 25 returns 429 with no retry-after header."
source_trace_id: trace-9871
supersedes: null
tags: [external-api, rate-limit, stripe]
```
 
---
 
## 8. Amendment Request
 
### Purpose
A formal request to modify the spec or contract. Workers, validators, and the orchestrator all create them; only the orchestrator can approve. Material amendments require human approval.
 
### Authors
Any role.
 
### Readers
Orchestrator (decides), Human (on material amendments).
 
### Lifecycle
Created when discovered. Reviewed by orchestrator. Approved → produces new spec version. Rejected → producer is notified, original spec stands. Withdrawn → no effect.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | |
| `mission_id` | ref\<Mission\> | yes | |
| `proposed_by` | string | yes | Agent id. |
| `target_type` | enum | yes | `assertion`, `feature`, `milestone`, `decision`, `scope`. |
| `target_id` | string | conditional | Required unless `target_type: scope`. |
| `change_type` | enum | yes | `relax`, `tighten`, `replace`, `add`, `remove`. |
| `proposed_change` | string | yes | The new content, fully written. |
| `rationale` | string | yes | Why the change is needed. |
| `evidence` | list\<EvidenceItem\> | no | Trace pointers, validator results, or external references supporting the rationale. |
| `material_change` | bool | yes | Triggers human approval if true. |
| `status` | enum | yes | `proposed`, `approved`, `rejected`, `withdrawn`. |
| `decision_rationale` | string | conditional | Required when status is `approved` or `rejected`. |
| `produced_spec_version` | int | conditional | Set on approval. |
 
### Constraints
- An amendment cannot target an entity that doesn't exist in the current spec version.
- Workers must pause work on the affected scope while the amendment is pending.
- `material_change: true` cannot be approved without a human approval event in the audit trail.
### Example
 
```yaml
id: amend-0033
mission_id: mission-a3f7
proposed_by: w-2026-04-22-c3
target_type: assertion
target_id: A-035
change_type: relax
proposed_change: |
  "Login response time P95 must be under 500ms"
  (previously: under 100ms)
rationale: "External SSO provider averages 200-400ms response time;
            100ms is unachievable without local credential caching,
            which the security constraint forbids."
evidence:
  - type: metric
    content: "p50=240ms, p95=380ms, p99=520ms over 1000 sample requests"
    description: "Latency to SSO provider, measured in M-2 worktree"
  - type: log
    content: "blob://logs/sso-latency-survey.txt"
    description: "Raw timing data"
material_change: true
status: approved
decision_rationale: "Confirmed with security team; 500ms acceptable
                    given the constraint. Human approver: alice."
produced_spec_version: 13
```
 
---
 
## 9. Trace Event
 
### Purpose
The fundamental unit of observability. Every LLM call, every tool call, every state transition emits a trace event. Together they form a parent-child tree that reconstructs any past run.
 
### Authors
The runtime, automatically. Not authored by agents directly.
 
### Readers
Orchestrator (for context), humans (for debugging), eval pipeline (for failure clustering).
 
### Lifecycle
Created as actions happen. Immutable. Retained per data-retention policy (typically the life of the mission plus an archive period).
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | uuid | yes | |
| `parent_id` | uuid | no | Null at mission root. |
| `mission_id` | ref\<Mission\> | yes | |
| `agent_id` | string | yes | Which agent (or runtime component) emitted. |
| `agent_role` | enum | yes | `orchestrator`, `worker`, `validator`, `runtime`. |
| `type` | enum | yes | `llm_call`, `tool_call`, `state_transition`, `checkpoint`, `escalation`. |
| `started_at` | timestamp | yes | |
| `duration_ms` | int | yes | |
| `status` | enum | yes | `success`, `error`, `timeout`. |
| `error` | string | conditional | Required on non-success. |
 
### LLM call additional fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `model` | string | yes | |
| `prompt_version` | string | yes | Versioned prompt id, for eval-loop correlation. |
| `tokens_in` | int | yes | |
| `tokens_out` | int | yes | |
| `cost_usd` | float | yes | |
| `input` | object | yes | Full prompt, not summarized. |
| `output` | object | yes | Full response. |
 
### Tool call additional fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `tool_name` | string | yes | |
| `capability_tag` | string | yes | The capability that authorized this call. |
| `input` | object | yes | Full arguments. |
| `output` | object | yes | Full return value. |
| `gateway_decision` | enum | yes | `allowed`, `denied`. |
 
### State transition additional fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `from_state` | string | yes | |
| `to_state` | string | yes | |
| `trigger` | string | yes | What caused the transition. |
 
### Constraints
- Trace events are immutable.
- The full input/output of LLM and tool calls is retained — *not* summarized. This is what makes replay possible.
- Sensitive payloads (credentials, PII) must be redacted at write time, not retrieval time.
### Example (LLM call)
 
```yaml
id: trace-9871
parent_id: trace-9870
mission_id: mission-a3f7
agent_id: w-2026-04-22-c3
agent_role: worker
type: llm_call
started_at: 2026-04-23T08:13:55.220Z
duration_ms: 4180
status: success
error: null
model: "coding-strong-v3"
prompt_version: "worker-coding-v17"
tokens_in: 12_400
tokens_out: 1_820
cost_usd: 0.094
input:
  system: "You are a worker agent. ..."
  messages: [...]
output:
  content: "..."
  tool_calls: [...]
```
 
---
 
## 10. Worktree Record
 
### Purpose
Tracks a git worktree and its lifecycle. Coordinates the conflict scanner.
 
### Authors
Worktree manager (runtime component).
 
### Readers
Workers (to know where they write), conflict scanner, orchestrator.
 
### Lifecycle
Created on worker dispatch. Active during work. Sealed on merge or discard. Garbage collected after retention window.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | E.g. `wt-mainline`, `wt-fanout-c3`. |
| `mission_id` | ref\<Mission\> | yes | |
| `kind` | enum | yes | `mainline` (shared serial worktree) or `fanout` (per-worker). |
| `branch` | string | yes | Git branch backing the worktree. |
| `path` | string | yes | Filesystem path inside sandbox. |
| `current_worker` | string | conditional | Required if `kind: fanout` and active. |
| `base_commit` | string | yes | The commit this worktree was created from. |
| `head_commit` | string | yes | Updated as commits land. |
| `port_assignments` | map\<string,int\> | no | E.g. `{web: 4101, db: 5433}`. |
| `state` | enum | yes | `active`, `merging`, `merged`, `discarded`, `gc_pending`. |
| `conflict_set` | list\<string\> | no | Worktree ids currently in conflict per the scanner. |
 
### Example
 
```yaml
id: wt-fanout-c3
mission_id: mission-a3f7
kind: fanout
branch: "mission-a3f7/F-003-channels"
path: "/sandbox/mission-a3f7/wt-fanout-c3"
current_worker: w-2026-04-22-c3
base_commit: "<base-commit-sha>"
head_commit: "<head-commit-sha>"
port_assignments:
  web: 4101
  db: 5433
state: active
conflict_set: []
```
 
---
 
## Cross-cutting Notes for the Implementing Architect
 
1. **All artifacts are content-addressed where reasonable.** A spec at version 12 has the same content for everyone who reads it, and is referenced by `(mission_id, version)`.
2. **All schemas should be enforced at write time, not read time.** Invalid handoffs should fail to write, not surprise the next reader. The runtime is the gatekeeper.
3. **All sensitive content is redacted at the trace-store write path.** Credentials, PII, and customer data should never sit in trace logs in cleartext, even briefly.
4. **Versioned prompts are first-class artifacts.** Treat them like code: PR-reviewed, tagged, runnable through the eval suite before promotion. The trace event's `prompt_version` field is what closes the loop between production failures and prompt iteration.
5. **The id namespace matters.** Use prefixed ids (`A-`, `F-`, `M-`, `D-`, `mission-`, `wt-`, `trace-`, etc.) to make logs and dashboards readable.
6. **Retention policy is a real decision.** Trace events accumulate fast. A reasonable default: hot store for the life of the mission plus 30 days, archive store for 1 year, then purge. Adjust for compliance requirements.