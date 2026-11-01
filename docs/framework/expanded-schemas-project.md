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
 
## Citation convention
 
**`LM2-ADR-0NN`** denotes a decision in the local-modes design document (`docs/framework/vanguard-collective-local-modes-v2.2.md`). A bare **`ADR-0NN`** denotes the on-disk file under `tools/mission-cli/config/`. The two namespaces collide numerically and are not related — v2.1 claimed they bore "no relation" as a matter of design; erratum E2 in v2.2 records that on disk they collide with every ID the design document mints. Standing convention, carried in v2.2's own front matter.
 
Likewise **`v2.2 §12`** denotes a section of the design document; a bare **`§12`** denotes a section of *this* document. They are different numbering spaces and this document's §12 is not v2.2's §12.
 
---
 
## Consolidation record
 
This document is the consolidation called for by v2.2 §13.3. It is assembled from five admitted inputs, each cited at the sha256 prefix of the file as this tree carries it, re-derived whenever an input is edited:
 
| Input | sha256 prefix | Role |
|---|---|---|
| `docs/framework/expanded-schemas-base.md` | `57ed463c` | Base document; §1–§10 and the cross-cutting notes |
| `tools/mission-cli/config/expanded-schemas-section-6-validator-result.md` | `474e04c1` | §6 reconciliation |
| `tools/mission-cli/config/expanded-schemas-section-7-memory-ledger-entry.md` | `317afce7` | §7 reconciliation |
| `tools/mission-cli/config/expanded-schemas-section-8-amendment-request.md` | `f240bc1f` | §8 reconciliation |
| `tools/mission-cli/config/expanded-schemas-adr-032-additions.md` | `74b046a5` | §11 Task Brief; §9 `brief_version` |
 
Per erratum E4 these are **worktree anchors**: each prefix is the sha256 of the file's bytes as checked out (`Get-FileHash -Algorithm SHA256`). The framework's root `.gitattributes` (`* -text`) checks every file out exactly as stored, whatever `core.autocrlf` says, so in this repository a clone presents the same bytes as the worktree; in a project without that rule, re-derive in a worktree, not from a clone-and-hash.
 
The v2.2 §12 schema deltas are applied additively: §12.1 `goal_condition` (this document's §4), §12.2 `runner_anchors` (§5 and §6), §12.3 the Evidence Manifest as sealed at schema 1.2.0 (§12), §12.4 Push Authorization (§13).
 
### Reconciliation outcome
 
The §6/§7/§8 fragments self-describe as in-repo verbatim copies of the corresponding base sections. They are not verbatim. A mechanical sweep compared each fragment against its base section block by block; every divergence is resolved by an individual ruling, under a rule that forbids the builder from picking a winner. The rulings, and where each is visible in this document:
 
- **`type`, `scope`, `target_type` are open vocabularies, not closed enums.** The closed-enum claims were falsified by live usage and are retired. See *Open-vocabulary fields* below, and §7 and §8.
- **§8 `target_type`, `target_id`, `produced_spec_version` take the fragment's text**, which is the later and more precise statement of the rule. The base rows are the stale copy. Each superseded row is marked inline.
- **§7's designed core is the base's four values.** `runtime_audit`, declared by the §7 fragment's table, is contradicted by that same fragment's own reconciliation prose; it is recorded in the disclosure and is not part of the designed core.
- **The `(verbatim)` heading suffixes are dropped.** They described the fragments' role, which ends here.
- **The base's escaped angle-bracket form wins** (`list\<string\>`), being the form the base uses consistently.
- **Coverage is the union**: the base-only examples in §6 and §8 and the fragment-only subsections in §8 are all carried.
Two mechanical properties of this document, stated so a diff against the inputs is exact:
 
1. **Trailing whitespace is not reproduced.** The base carries trailing spaces on **125 of its 732 lines** — an artifact of the download path that produced it — while every fragment carries none. This document carries none. A whitespace-insensitive diff (`git diff -w`, `diff -b`) against the base is therefore the exact comparison; a byte diff will additionally show the stripped trailing spaces on those 125 lines. (The base carries 731 line terminators against 732 lines because it ends without a final newline. 732 is the line count used here; a figure of 125-of-731 is the terminator count and is the same measurement stated against the wrong denominator.)
2. **Line endings are LF and the encoding is UTF-8 without BOM**, matching the A1 documents. The inputs are CRLF; this is a normalization, not an edit.
---
 
## Open-vocabulary fields
 
Three fields in this document were declared as closed enums and are not. The claims are retired here on evidence.
 
**Derivation anchor.** All populations below are derived from **the working tree at the anchor HEAD** — the tree as it stands, untracked files included, not the content of the commit. The figures below are placeholders: a population belongs to the mission repository the commands run in, and this repository records none. Stating the basis matters: an amendment file under `.mission/amendments/` that is not yet tracked at the anchor HEAD is still inside the file count below. Run from the repository root:
 
```powershell
git rev-parse HEAD
(Get-Content .mission/ledger/entries.jsonl).Count
(Get-ChildItem .mission/amendments -Filter *.yaml -File).Count
```
 
```
<anchor HEAD>
<ledger entry count>
<amendment file count>
```
 
**Disclosed: a population taken over a directory that a ceremony writes into includes any amendment that ceremony places.** An amendment that authorizes a change to this document is itself inside the file count, and its own `target_type` moves the §8 tally under its own ceremony — a figure taken before that amendment is placed on disk is stale after it. A derivation over a directory the ceremony writes into is not stable across that ceremony. The consequence is stated rather than left implied: the acceptance check that re-derives these blocks decides only at the stated anchor, and at any other HEAD it skips rather than deciding on ground that has legitimately moved.
 
**Standing law.** Acceptance evidence over these populations is taken at anchor HEAD **before** any mutation of `.mission/amendments/`. Authoring a new amendment file moves the population while HEAD still equals the anchor, and that is the one window in which the re-derivation check fails rather than skips — the failure would be the instrument correctly reporting a stale figure, not a defect in the ceremony.
 
**What "open vocabulary" means here.** The field is typed `string`. A **designed core** is recorded — the values the original schema declared, kept because they carry design intent. An **observed set** is recorded beside it as a derived population: what the live data actually contains, with the command that produces it, so a reader re-derives instead of trusting. The observed set is a **dated derivation, not a new closed enum**. This document invents no values and canonizes no snapshot; a reader at a later HEAD should re-run the command rather than cite these figures.
 
**What is not claimed.** Exactly three fields were measured: §7 `type`, §7 `scope`, §8 `target_type`. Every other `enum`-typed field in this document is carried as declared and was **not** measured against live data. Their enum claims are unverified, not verified — the absence of a disclosure below is absence of evidence, not evidence of conformance.
 
**Registered, not resolved:** whether and how a vocabulary re-closes — for instance, requiring an amendment to introduce a new value — is a framework governance question, not a schema question. It is recorded in *Registered decisions* and belongs to v2.2+ / the A3 era.
 
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
| `goal_condition` | string | no | *(v2.2 §12.1 addition.)* Completion condition the runner translates to `/goal`. Must be expressible as: all `assertion_targets` pass locally AND a schema-valid handoff exists at the expected path. Scoped to this dispatch only. |
 
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
goal_condition: "A-021..A-025 pass under `pnpm test channels` AND
                 .mission-runtime/dispatches/dispatch-7b21/handoff.json validates"
```
 
---
 
## 5. Handoff Document
 
### Purpose
The structured artifact a worker emits on completion. It is the **only** information that propagates to the next worker. Workers do not inherit context windows.
 
### Authors
Worker that produced it. **Except `runner_anchors`, which the runner writes from evidence and the model can neither write nor influence** (v2.2 §12.2; Principle 11).
 
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
| `runner_anchors` | object | yes | *(v2.2 §12.2 addition.)* Written by the runner from evidence, never by the model. See *RunnerAnchors* sub-schema. |
 
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
 
### RunnerAnchors sub-schema
 
*(v2.2 §12.2. Shared with §6 Validator Result — one shape, two carriers.)*
 
| Field | Type | Required | Description |
|---|---|---|---|
| `head_sha` | string | yes | `git rev-parse HEAD` at session end. Always present. |
| `porcelain` | list\<string\> | yes | `git status --porcelain=v1`, verbatim. Always present. Empty list means a clean tree — it does not mean the field was skipped. |
| `suite` | object | conditional | See *SuiteAnchor*. Required for build-, rework- and close-class dispatches; **absent** for read-only and micro-ceremony dispatches. |
| `evidence_manifest` | string | yes | Path of the manifest: `.mission/evidence/<dispatch_id>/manifest.json`. |
| `evidence_manifest_sha256` | string | yes | sha256 of that manifest. |
| `testimony_conflict` | bool | yes | See *decidability* below. |
 
### SuiteAnchor sub-schema
 
| Field | Type | Required | Description |
|---|---|---|---|
| `command` | string | yes | The canonical suite command from mission config. |
| `passed` | int | yes | |
| `failed` | int | yes | |
| `skipped` | int | yes | |
| `expected_failures_matched` | bool | yes | Checked against `tools/mission-cli/config/expected-failures.yaml`. |
 
### Constraints
- A handoff with non-empty `unfinished` and `terminated_reason: completed` is invalid.
- Every `completed_assertions` entry must be in the dispatch's `assertion_targets`.
- `procedure_adherence: deviated` without `deviation_notes` is invalid.
- **`runner_anchors` is not model-writable.** The schema gives the model no such fields, and a handoff in which the model supplied them is invalid rather than merely suspect.
- **`testimony_conflict` is decidable, not fuzzy.** It fires only when a model-populated *structured* field — a claimed test tally in a summary field, say — contradicts a runner anchor. Contradictions in free prose are surfaced as lint warnings for the human and never as automated verdicts: prose is testimony and is treated as such in both directions.
- **Anchor scoping is by dispatch kind, and absence is meaningful.** `head_sha`, `porcelain` and the manifest fields are universal. The `suite` block's absence on a read-only or micro-ceremony dispatch is correct and must not be read as a missing anchor — running a full suite per micro-dispatch would contradict the micro-dispatch doctrine.
**Expected-failure manifest.** `tools/mission-cli/config/expected-failures.yaml` — committed, amendment-gated. The mechanism is framework; the content is mission truth, and each mission populates its own.
 
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
  - "<commit-1>..."
  - "<commit-2>..."
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
runner_anchors:
  head_sha: "<commit-2>..."
  porcelain: []
  suite:
    command: "pnpm test"
    passed: 214
    failed: 1
    skipped: 3
    expected_failures_matched: true
  evidence_manifest: ".mission/evidence/dispatch-7b21/manifest.json"
  evidence_manifest_sha256: "b9c1..."
  testimony_conflict: false
```
 
---
 
## 6. Validator Result
 
### Purpose
A single validator's verdict on one or more assertions, with evidence.
 
### Authors
The validator that produced it. **Except `runner_anchors`** — see §5.
 
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
| `runner_anchors` | object | yes | *(v2.2 §12.2 addition.)* Written by the runner from evidence, never by the model. Shape and constraints per §5 *RunnerAnchors*. |
 
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
commit_sha: "<commit-sha>..."
runner_anchors:
  head_sha: "<commit-sha>..."
  porcelain: []
  suite:
    command: "pnpm test"
    passed: 213
    failed: 2
    skipped: 3
    expected_failures_matched: false
  evidence_manifest: ".mission/evidence/valrun-9c4f/manifest.json"
  evidence_manifest_sha256: "4e77..."
  testimony_conflict: false
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
| `type` | string (open vocabulary) | yes | Kind of learning. Designed core and observed set below. |
| `scope` | string (open vocabulary) | yes | What the learning is filed under. Designed core and observed set below. |
| `scope_ref` | string | conditional | Milestone or feature id, required if scope is not global. |
| `content` | string | yes | The actual learning. Should be self-contained. |
| `source_trace_id` | uuid | no | Trace that produced this finding. |
| `supersedes` | uuid | no | Earlier entry this corrects. |
| `tags` | list\<string\> | no | For retrieval. |
 
### `type` — open vocabulary
 
**Designed core:** `gotcha`, `decision`, `constraint`, `correction`.
 
**Enum claim retired.** `type` was declared a closed enum of the four values above. Live data contains values outside that set, so the claim is retired and the field is typed `string`.
 
**Observed set**, derived at the anchor in *Open-vocabulary fields*; the block below shows the shape the command prints, with counts as placeholders. From the repository root:
 
```powershell
[System.IO.File]::ReadAllLines((Resolve-Path '.mission/ledger/entries.jsonl').Path) |
  Where-Object { $_.Trim() } | ForEach-Object { ($_ | ConvertFrom-Json).type } |
  Group-Object | Sort-Object Count -Descending |
  ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
```
 
```
  <n>  gotcha
  <n>  decision
  <n>  constraint
  <n>  correction
  <n>  <other observed value>
```
 
**Disclosure.** The §7 fragment (`317afce7`) declares a fifth core value, `runtime_audit`. It is not carried into the designed core, for the reason stated so a reader can weigh it: that fragment's own reconciliation prose states the designed set as the four values above, contradicting its own table.
 
### `scope` — open vocabulary
 
**Designed core:** `global`, `milestone`, `feature` — a *granularity* axis.
 
**Enum claim retired.** Live data can run on a different axis. Undeclared values such as `framework` and `product` record what a learning is *about* (the harness versus the product under construction) rather than how broadly it applies. The claim is retired and the field is typed `string`.
 
**Observed set**, derived at the same anchor:
 
```powershell
[System.IO.File]::ReadAllLines((Resolve-Path '.mission/ledger/entries.jsonl').Path) |
  Where-Object { $_.Trim() } | ForEach-Object { ($_ | ConvertFrom-Json).scope } |
  Group-Object | Sort-Object Count -Descending |
  ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
```
 
```
  <n>  global
  <n>  milestone
  <n>  feature
  <n>  <other observed value>
```
 
### Constraints
- Entries are immutable. To correct, write a new `correction` entry referencing the old.
- `scope_ref` must reference a real entity if scope is not `global`.
- **`scope_ref`'s conditional requirement is stated against the designed core** and is not re-derived from the observed set. This document does not rule on whether a `framework`- or `product`-scoped entry owes a `scope_ref`; that is part of the registered vocabulary-governance question.
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
| `target_type` | string (open vocabulary) | yes | What the amendment amends. Designed core and observed set below. *Row updated; earlier text superseded.* |
| `target_id` | string | conditional | Required unless `target_type` is `scope` or `schema`. *Row updated; earlier text superseded.* |
| `change_type` | enum | yes | `relax`, `tighten`, `replace`, `add`, `remove`. |
| `proposed_change` | string | yes | The new content, fully written. |
| `rationale` | string | yes | Why the change is needed. |
| `evidence` | list\<EvidenceItem\> | no | Trace pointers, validator results, or external references supporting the rationale. |
| `material_change` | bool | yes | Triggers human approval if true. |
| `status` | enum | yes | `proposed`, `approved`, `rejected`, `withdrawn`. |
| `decision_rationale` | string | conditional | Required when status is `approved` or `rejected`. |
| `produced_spec_version` | int | conditional | Set on approval ONLY when the amendment changes the **spec surface** — spec-body entities (the `.mission/spec/v*.yaml` chain) OR versioned artifacts under `.mission/spec/` (including `.mission/spec/proposals/`). NULL when the amendment changes governed code/config OUTSIDE the spec surface (gateway policy under `tools/tool-gateway/`, tool-config schema fragments under `tools/mission-cli/config/`, allowlists, etc.). The classification axis is **location**, NOT `target_type`-ness: a `target_type:schema` amendment may bump (e.g., edits to `.mission/spec/proposals/<schema>.yaml`) or NOT bump (e.g., edits to `tools/mission-cli/config/expanded-schemas-section-*.md`). *Row updated; earlier text superseded.* |
 
### `target_type` — open vocabulary
 
**Designed core:** `assertion`, `feature`, `milestone`, `decision`, `scope`, plus `schema` (a later addition, carried per the ruling on this row).
 
**Enum claim retired.** Amendments in live use can carry values outside that set. The claim is retired and the field is typed `string`.
 
**Observed set**, derived at the same anchor. From the repository root:
 
```powershell
Get-ChildItem .mission/amendments -Filter *.yaml -File | ForEach-Object {
  $m = [regex]::Match([System.IO.File]::ReadAllText($_.FullName), '(?m)^target_type:\s*(\S+)')
  if ($m.Success) { $m.Groups[1].Value } else { '(none)' }
} | Group-Object | Sort-Object Count -Descending |
  ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
```
 
```
  <n>  assertion
  <n>  feature
  <n>  milestone
  <n>  decision
  <n>  scope
  <n>  schema
  <n>  (none)
  <n>  <other observed value>
```
 
`(none)` is not a value: it is the tally of amendment files carrying no `target_type` line at all, reported rather than dropped so the population sums to the anchor's file count.
 
### Target-type semantics
 
- `assertion` — amends a contract assertion (spec-body entity under `.mission/contract/assertions/`).
- `feature` — amends a feature entry in `.mission/spec/v*.yaml`.
- `milestone` — amends a milestone entry in `.mission/spec/v*.yaml`.
- `decision` — amends a `decisions[]` entry in `.mission/spec/v*.yaml`.
- `scope` — amends a `scope_inclusions` / `scope_exclusions` entry in `.mission/spec/v*.yaml`. (`target_id` is null because scope entries are list elements, not named entities.)
- `schema` (later addition) — amends a schema or structural artifact. May live INSIDE the spec surface (e.g., `.mission/spec/proposals/<schema>.yaml`) or OUTSIDE it (e.g., `tools/mission-cli/config/expanded-schemas-section-*.md`, `tools/tool-gateway/` policy). The **location** determines `produced_spec_version`, not the enum value.
Values appearing in the observed set but not above are undocumented: they are in use and their semantics are not recorded here. Documenting or retiring them is part of the registered vocabulary-governance question.
 
### `produced_spec_version` classification rule
 
Illustrated by four cases:
 
| Amendment | Edit location | Spec-surface? | `produced_spec_version` |
|---|---|---|---|
| A §7-fragment amendment | `tools/mission-cli/config/` (§7 fragment) | NO | `null` |
| A gateway amendment | `tools/tool-gateway/` (gateway code + schema field) | NO | `null` |
| A schema amendment | `.mission/spec/proposals/` (a schema artifact) | YES | `n+1` (bumped) |
| The amendment codifying this rule | `tools/mission-cli/config/` (§8 fragment) | NO | `null` (self-applied) |
 
The codifying amendment's self-classification IS the rule's coherence test: edits to a §8 schema fragment outside `.mission/spec/` MUST NOT bump the version chain (the spec body isn't changing), even though the amendment IS schema-targeted. If `target_type` controlled the bump rather than location, the codifying amendment would self-contradict.
 
### Field-naming divergence — three shapes on disk
 
The `target_type` + `target_id` pair is the **schema-aware form**: what this schema declares, and what an author writing against it produces. That is a statement of designed intent. It is *not* a property the record set exhibits, and this document does not claim it is. Amendment records on disk can carry three distinct field-name shapes, two of which are what the `(none)` row of the tally above counts.
 
| Shape | Records | Dated | Count |
|---|---|---|---|
| `target_type:` + `target_id:` — the schema-aware form | amendments authored against this schema | — | `<n>` |
| `target:` (a path string) + `target_path_within_file:` | amendments in an earlier, pre-schema form | — | `<n>` |
| no `target*` key of any kind | amendments authored with no target key | — | `<n>` |
 
Derived at the same anchor, and the three counts sum to its amendment file count; the counts are placeholders here. From the repository root:
 
```powershell
Get-ChildItem .mission/amendments -Filter *.yaml -File | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName)
  $k = ([regex]::Matches($t, '(?m)^(target[a-z_]*):') | ForEach-Object { $_.Groups[1].Value }) -join ','
  if (-not $k) { $k = '(no target* key)' }
  $k
} | Group-Object | Sort-Object Count -Descending |
  ForEach-Object { '{0,5}  {1}' -f $_.Count, $_.Name }
```
 
**Two claims are not made here, because that derivation can falsify both.** The first is that the canonical pair is used by *all* amendments authored going forward: records carrying no `target*` key can appear among the **newest** records on disk, not only the oldest — a third shape such a claim has no room for. The second is that the divergence sits in the **oldest** records *only*: it can span unrelated shapes, and age does not explain them all. Nor is it assumed which `target:` records also carry `target_path_within_file:` — the derivation shows it.
 
None of these records is rewritten; amendments are immutable. The divergence is disclosed, not reconciled, and no reading of it is offered: whether a record carrying no `target*` key is a schema violation, a distinct document class, or an authoring gap is a governance question. It is registered alongside the vocabulary question and is not settled by this document.
 
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
| `brief_version` | string | no | *(ADR-032 decision 6 addition.)* Versioned task-brief-template id. Parallel to `prompt_version`: `prompt_version` tracks the role-prompt channel, `brief_version` tracks the per-dispatch task channel (see §11 Task Brief). Optional because not every LLM call is tied to a worker dispatch (orchestrator-side calls, for instance); on worker LLM calls the runner populates it from the constructed `TaskBrief.brief_version`. |
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
brief_version: "brief-gen-v1"
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
base_commit: "<base-commit>..."
head_commit: "<head-commit>..."
port_assignments:
  web: 4101
  db: 5433
state: active
conflict_set: []
```
 
---
 
## 11. Task Brief
 
*(New artifact section, from ADR-032 decision 4. The source fragment used `§N` as a placeholder for the next available number; this document assigns 11. The fragment's Authors/Readers/Lifecycle table form is preserved rather than rewritten into the base's prose subsections — see the consolidation record.)*
 
### Purpose
 
The per-dispatch task surface: the sentence "produce THIS artifact, for
THIS feature, against THESE assertions." Distinct from the role-prompt
(ADR-023, runtime-loaded by the worker's agent construction) and from
the handoff-reporting instruction (the worker's exit protocol). The
runner constructs a Task Brief deterministically from `WorkerDispatch`
metadata + the versioned spec + assertion files, writes it as a
committed artifact, and instructs the worker to read it via the
existing `--append-system-prompt` channel.
 
### Path
 
`.mission/dispatches/<dispatch_id>/task-brief.md`
 
A new committed artifact kind under `.mission/`. The dispatch's runtime
scratch (`tool_scope.json`, `hook-settings.json`, `handoff.json`) stays
gitignored under `.mission-runtime/`; the task brief is promoted to
`.mission/` because it is part of the dispatch's durable, replayable
contract — the worker's input of record (ADR-032 decision 4).
 
### Authors / Readers / Lifecycle
 
| Aspect | Value |
|---|---|
| Authors | Runner (framework, automatically). Operator only via the bounded `operator_note` addendum (ADR-032 decision 5). |
| Readers | Dispatched worker (via the `--append-system-prompt` pointer); orchestrator / operator (for audit); eval pipeline (correlated via `brief_version` on §9 LLMCallTrace). |
| Lifecycle | Constructed pre-spawn; written; immutable. Pre-spawn the runner verifies the file exists and is non-empty (`_validate_pre_spawn` extension) — a missing brief is a dispatch-construction error, not a silent empty-task spawn. |
 
### Fields
 
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | ✓ | Cross-cutting framework convention. Wire form prefixed `brief-...`. |
| `created_at` | ISO-8601 UTC string | ✓ | Cross-cutting framework convention. |
| `created_by` | string | ✓ | Cross-cutting framework convention. Agent id of the constructor (e.g. `claude-code:worker-runner`). |
| `dispatch_id` | ref\<Dispatch\> | ✓ | The dispatch this brief belongs to. Operational identity (the file lives at the dispatch-id-keyed path). |
| `feature_id` | string `^F-\d{3,}$` | ✓ | The feature the worker is implementing. |
| `spec_version` | PositiveInt | ✓ | Pins the brief to a frozen spec. The brief indexes `.mission/spec/v{spec_version:03d}.yaml`; it does NOT inline the spec (ADR-032 decision 2). |
| `assertion_targets` | list[string], min 1 | ✓ | Assertions the worker is to make pass. The brief indexes `.mission/contract/assertions/<A-NNN>.yaml`; it does NOT inline assertion text (ADR-032 decision 2). |
| `objective` | string, non-empty | ✓ | The task statement — derived deterministically from `feature_id` + `assertion_targets`. The sentence the framework previously failed to construct. |
| `skills` | optional list[string] | — | Skill ids the worker should consult (ADR-023). Hand-specified by the operator in v1; auto-selection deferred (ADR-032 decision 3). |
| `operator_note` | optional string | — | Bounded addendum per ADR-032 decision 5. Threaded from `mission-dispatch.ps1 -OperatorNote`. Rendered under a labeled `## Operator note (out-of-contract)` section — additive to, never replacing, the artifact-derived objective. |
| `brief_version` | string, non-empty | ✓ | Versioned brief-generator-template id. Until the prompts/ registry initializes (post-MVP per ADR-012/017), this is the inlined template's version string (mirrors the existing `_HANDOFF_INSTRUCTION_TEMPLATE` debt). Correlates with `LLMCallTrace.brief_version` (§9). |
 
### Constraints
 
1. **Write-time schema validation is REQUIRED** (cross-cutting note 2 +
   ADR-032 decision 4). The Pydantic `TaskBrief` model in
   `tools/worker-runner/schemas.py` is the source of truth; the rendered
   markdown is a presentation surface produced by the brief-generator
   after validation succeeds.
2. **The brief indexes; it does not inline** (ADR-032 decision 2). The
   worker reads the frozen contract artifacts (spec + assertions)
   directly; the brief carries pointers and the objective, not copies of
   the contract text.
3. **`operator_note` is the one un-reproducible surface** (ADR-032
   decision 5 tradeoff). Bounded, additive, labeled, recorded, traced.
### Schema (Pydantic, source-of-truth)
 
`tools/worker-runner/schemas.py :: TaskBrief`. See class docstring for
the canonical field-by-field description.
 
### Tradeoff acceptances (carried from ADR-032)
 
- **Two framework-document changes**: a new Task Brief artifact section
  + a `brief_version` field on §9. Heavier than a runtime-only design;
  paid for the audit position.
- **A new committed artifact kind in `.mission/`.** `.mission/dispatches/`
  becomes a tracked tree. Per-dispatch growth, mitigated by brief size
  (objective + index + optional note).
- **Inlined template debt carried, not closed.** The brief generator
  lives as an inlined constant until `prompts/` registry init (same
  deferred-promotion debt as the handoff instruction). `brief_version`
  records the inlined version meanwhile.
---
 
## 12. Evidence Manifest
 
*(New artifact section, per v2.2 §12.3. This document assigns 12; v2.2 §12.3 is the design section, not this section number — see the citation convention.)*
 
### Purpose
 
Per-dispatch manifest of hook-captured evidence: the artifact a report is checked *against*. It exists so that a claim about what a session did has an anchor the session did not author.
 
### Authors
 
The Stop hook (`tools/framework/hooks/evidence-stop-finalize.ps1`), never a model. Principle 11: evidence is captured by the harness, and the model never holds the pen.
 
### Readers
 
Orchestrator (consumption gate), operator (audit), A3 `mission verify` (when wired).
 
### Lifecycle
 
The append-only log accumulates during the session; the manifest is written once, at Stop. Writing the manifest **is** finalization. Immutable after finalization, and the finalizer refuses to finalize twice — a second finalization would let a shorter later log overwrite the record of a longer earlier one.
 
### Normative source
 
**`docs/framework/evidence-manifest.schema.json`, sealed at sha256 prefix `2a04099d`, is normative for this artifact.** This section describes it. Where the two could differ, the JSON schema wins and this section is wrong. Field spellings below are taken from that file.
 
**DECISION — the A1 deviations from design §12.3 are RATIFIED.** The sealed schema labels every way it departs from v2.2 §12.3's stated shape and hands the ratify-or-overrule choice to this document. They are ratified as written, not overruled: each addition exists because §12.3's shape could not carry a property the design elsewhere requires. `log_sha256` is the clearest case — §12.3 asserts "immutable after finalization", and without a hash anchor that sentence has no detector, which is exactly the assertion-without-enforcement pattern Principle 11 exists to stop.
 
**DECISION — the derived-state vocabulary is ADOPTED.** `ABSENT`, `PARTIAL`, `FINALIZED`, `TAMPERED` are this document's declared vocabulary for evidence state. The sealed schema flagged `TAMPERED` as A1-local pending alignment here; it is no longer A1-local.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `schema_version` | string | yes | Const `1.2.0`. An older manifest does not validate against the sealed schema, which is the point of the field. |
| `dispatch_id` | string | yes | The dispatch this evidence belongs to. Resolved by the hook; the model has no input into this value. |
| `session_id` | string \| null | no | Harness session id. Not required: the harness may not supply one, and `dispatch_id` is the identity that governs consumption. |
| `state` | enum | yes | `finalized` only. `PARTIAL` and `TAMPERED` are **derived**, never stored — a stored `PARTIAL` would be a claim by the very machinery whose failure defines it, and a crashed session writes nothing at all. |
| `entries` | list\<Entry\> | yes | One per captured event, in log order. Two declared variants, disjoint by construction — see below. |
| `entry_count` | int | yes | Redundant with `entries` length by construction, deliberately: a consumer reading only the header can still detect truncation. |
| `unparsable_lines` | int | no | Log lines that would not parse as JSON and were excluded. Recorded rather than dropped silently; nonzero is a capture defect an operator must see. |
| `log_path` | string | no | Path of the append-only log, relative to the dispatch evidence directory. Always `log.jsonl`. |
| `log_sha256` | string | yes | sha256 of the log at finalization. The immutability anchor. |
| `hook_errors_present` | bool | yes | Whether any hook recorded an error. **A consumer must not treat a manifest with `hook_errors_present: true` as complete evidence merely because it is FINALIZED** — `entry_count` may undercount reality. |
| `hook_errors_sha256` | string \| null | no | sha256 of `hook-errors.log` at finalization, or null when none were recorded. |
| `reconciled` | bool | no | Present and true only when the finalizer's reconcile pass corrected `hook_errors_present` after the publish phase itself raised an error. Its presence means the first manifest write was wrong and was fixed within the same finalization. |
| `streams_committed` | bool | yes | Whether stream bodies and transcript snapshots reached the committed plane. False means the untruncated output survives only in `.mission-runtime/`, which is ephemeral — so for any entry over the inline byte cap the committed evidence holds a hash whose subject is gone. |
| `created_at` | string | yes | UTC ISO-8601. When the manifest was computed. |
| `finalized_at` | string | no | UTC ISO-8601. Its **presence** is what makes the manifest finalized; its absence in a manifest found on disk means the finalizer was interrupted, which derives to PARTIAL. Deliberately not required, so an interrupted finalizer's output reads as the state it is instead of failing validation. |
 
### Entry — tool-call variant
 
| Field | Type | Required | Description |
|---|---|---|---|
| `ts` | string | yes | UTC ISO-8601 with milliseconds. |
| `tool` | string | yes | Tool name as reported by the harness. Never `_precompact` — synthetic events use the other variant. |
| `command` | string \| null | yes | The anchor-bearing field: the command for shell tools, the target path for file tools, otherwise the serialised tool input. Never elided — an entry with no command cannot be checked against a report. |
| `exit_code` | int \| null | yes | Null where the tool has none. **Null is not success.** |
| `stdout_sha256` | string | yes | sha256 over the FULL stdout bytes, never over the inline excerpt. Hashing a truncated excerpt would make the anchor unverifiable while looking authoritative. |
| `stderr_sha256` | string | yes | sha256 over the FULL stderr bytes. Same rule. |
| `path` | string | yes | Path, relative to the dispatch evidence directory, of the file holding the full streams: `streams/<seq>.json`. |
 
### Entry — `_precompact` variant
 
A PreCompact event captures a transcript, not a command's streams, so it has no stdout or stderr to hash. Forcing it into the tool-call shape would make `stdout_sha256` mean two different things, which is the opposite of an anchor.
 
| Field | Type | Required | Description |
|---|---|---|---|
| `ts` | string | yes | UTC ISO-8601 with milliseconds. |
| `tool` | string | yes | Const `_precompact`. Underscore-prefixed so it can never collide with a harness tool name. |
| `command` | string \| null | yes | PreCompact trigger and source transcript path, for audit. |
| `exit_code` | int \| null | yes | 0 when the transcript was copied, 1 when it could not be. |
| `transcript_sha256` | string \| null | yes | sha256 of the snapshot file. Null when capture failed. |
| `captured` | bool | yes | Whether the transcript was actually copied. **A false here is a real evidence gap and must not be read as an absent event** — which is why it exists as a separate boolean rather than being inferred from a null hash. |
| `path` | string | yes | `transcripts/precompact-NNN.jsonl`. Snapshots are numbered and never overwritten: the Nth is not a replacement for the (N-1)th. |
 
### Derived states
 
State is derived by a consumer from what is on disk. It is not a field a writer asserts.
 
| State | When | Consumable | Forensics |
|---|---|---|---|
| `ABSENT` | no log and no manifest | no | no |
| `PARTIAL` | log present AND (manifest absent OR unparsable OR `finalized_at` missing) | no | yes |
| `FINALIZED` | manifest present AND `finalized_at` present AND `sha256(log.jsonl)` == `log_sha256` | yes | yes |
| `TAMPERED` | manifest finalized BUT `sha256(log.jsonl)` != `log_sha256` | no | yes |
 
`ABSENT` on a mutation-bearing dispatch is itself the finding: evidence-blind mutation is the fabrication precondition. `PARTIAL` blocks report consumption but fully supports forensic re-ground — the log is written per tool call, not at exit, so every mutation that hit disk before the crash is in it. `FINALIZED` is the only state that permits consumption.
 
### Constraints
- **State and schema-validity are independent checks, and a consumer owes both.** `FINALIZED` is derived from the header and the log hash; it does not imply that `entries` validates against the sealed schema. A log line that is valid JSON but carries none of the declared fields yields a manifest that fails schema validation while still deriving `FINALIZED`. Neither check subsumes the other.
- **Stream-body integrity is not checked by state derivation.** Verifying a stream body means reading the file at `entries[].path`, hashing its `stdout` and `stderr` members over their full UTF-8 bytes, and comparing to the recorded hashes. Nothing in A1 runs this automatically. Until A3's `mission verify` wires it into the dispatch gate, **a mutated stream body with an untouched `log.jsonl` still reads FINALIZED from state alone.**
- **Committed-plane parity is a separate detector with a stated scope.** `Test-EvidencePlaneParity` checks that the committed plane holds what the runtime manifest asserts was published. It detects the demonstrated scenario class — a silent publish failure — not "plane integrity" in general.
### The append-only log (`log.jsonl`)
 
**DECISION — resolved: `log.jsonl` gets a declared schema here.** It is the primary append-only evidence and had none, which meant the manifest was schematized while its source was not. One JSON object per line, UTF-8, LF-terminated, never rewritten. Two variants, matching the two manifest entry variants. The field lists below are the shapes the sealed hooks write.
 
**Tool-call line** — written by `evidence-post-tool-use.ps1`:
 
| Field | Type | Description |
|---|---|---|
| `ts` | string | UTC ISO-8601 with milliseconds. |
| `session_id` | string | As supplied by the harness; may be empty. |
| `dispatch_id` | string | Resolved by the hook. |
| `seq` | int | Allocation and its limits described below. |
| `tool` | string | Tool name as reported by the harness. |
| `command` | string \| null | The anchor-bearing field. |
| `exit_code` | int \| null | |
| `stdout` | string | Inline excerpt, capped at the inline byte budget. |
| `stderr` | string | Inline excerpt, capped at the inline byte budget. |
| `stdout_truncated` | bool | Whether the inline excerpt is short of the full bytes. |
| `stderr_truncated` | bool | Same. |
| `stdout_sha256` | string | Over the FULL bytes, never the excerpt. |
| `stderr_sha256` | string | Over the FULL bytes, never the excerpt. |
| `path` | string | `streams/<seq>.json`. |
 
**`_precompact` line** — written by `evidence-pre-compact.ps1`: `ts`, `session_id`, `dispatch_id`, `tool` (const `_precompact`), `command`, `exit_code`, `transcript_sha256`, `captured`, `path`. **It carries no `seq`.**
 
**Stream file** (`streams/<seq>.json`): `seq`, `tool`, `stdout`, `stderr` — the full, untruncated bytes.
 
**The manifest projects the log, it does not mirror it.** The manifest's entry variants carry a subset of the log line's fields and forbid additional properties — but the projection is not a flat subtraction, and an earlier revision of this paragraph got it wrong by listing `session_id` and `dispatch_id` as log-only. They are not. Both are **manifest fields at the top level, once per manifest** — `dispatch_id` required, `session_id` optional and nullable — as the Fields table above states and the normative schema requires. What the log does that the manifest does not is repeat them on *every line*.
 
The fields that appear **nowhere in the manifest, at any level**, are `seq`, the inline `stdout` and `stderr` excerpts, and the truncation flags `stdout_truncated` and `stderr_truncated`. A consumer wanting any of those must read the log. So must a consumer wanting `session_id` or `dispatch_id` attributed *per entry* rather than per dispatch: the manifest asserts each once for the whole dispatch and cannot distinguish its entries by them.
 
**DECISION — resolved: the manifest deliberately carries no `seq`.** Gap detection lives in the log. The consequence is stated rather than left implied: a consumer reading only the manifest cannot detect a dropped entry by sequence gap, and `entry_count` does not help, being derived from the same entries. Detecting a gap requires the log.
 
**DECISION — resolved: `seq` is not unique under concurrency, and is documented as such rather than made safe.** The hook allocates `seq` by counting existing non-blank log lines and adding one. Two PostToolUse hooks running concurrently read the same count, take the same `seq`, and write the same `streams/<seq>.json` path — so one stream body overwrites the other and two log lines share a sequence number.
 
**The append is locked; the allocation is not.** An earlier revision said flatly that no lock is taken, which understated what the capture path does. `Add-EvidenceLogLine` opens the log with `FileShare::Read` — an exclusive-write open that denies a second writer — and retries up to twenty times with increasing backoff before throwing, so two concurrent appends do not interleave bytes. What no lock spans is the *allocation*: the count that produces `seq` and the append that consumes it are separate operations, with the stream-body write between them. Serializing the write does not serialize the numbering, and it is the numbering that collides. The mitigation is not built here; the property is declared so that a consumer treats `seq` as an ordering hint rather than a key, and so a runner that later needs uniqueness knows it must add allocation discipline rather than assume it.
 
**Disclosed consequence — a `seq` gap is not proof of a dropped capture.** The counter counts *all* log lines, but only tool-call lines carry `seq`. A `_precompact` line therefore consumes a number without recording one, and the tool-call sequence shows a legitimate gap. A capture gap and an interleaved transcript snapshot are indistinguishable by inspecting tool-call `seq` values alone; distinguishing them requires counting all lines. Stated here because the A1 capture hook's own documentation offers "the runner sees missing seq numbers" as the gap detector, and that detector false-positives on any session that compacted **and then ran at least one more tool call**. The scope matters: a session that compacted as its last act leaves no gap at all. The number a `_precompact` line consumes becomes visible as a gap only when a later tool-call line takes the next one.
 
### Example
 
```yaml
schema_version: "1.2.0"
dispatch_id: dispatch-7b21
session_id: "sess-4419ab"
state: finalized
entries:
  - ts: "2026-08-09T17:36:22.481Z"
    tool: Bash
    command: "pnpm test channels"
    exit_code: 0
    stdout_sha256: "9f2c...64hex"
    stderr_sha256: "e3b0...64hex"
    path: "streams/000001.json"
  - ts: "2026-08-09T18:02:11.907Z"
    tool: _precompact
    command: "PreCompact trigger=auto source=/transcripts/sess-4419ab.jsonl"
    exit_code: 0
    transcript_sha256: "71ad...64hex"
    captured: true
    path: "transcripts/precompact-001.jsonl"
entry_count: 2
unparsable_lines: 0
log_path: "log.jsonl"
log_sha256: "c41d...64hex"
hook_errors_present: false
hook_errors_sha256: null
streams_committed: true
created_at: "2026-08-09T18:44:03.115Z"
finalized_at: "2026-08-09T18:44:03.402Z"
```
 
---
 
## 13. Push Authorization
 
*(New artifact section, per v2.2 §12.4. Local Autonomous Mode only.)*
 
### Purpose
 
Makes a push an authorized, single-use act against one specific tip, rather than a capability a session holds. The human creates it; the hook-gated push consumes it once.
 
### Authors
 
The human. Never an agent, and never the runner.
 
### Readers
 
The push hook (consumes), operator and audit (retained after consumption).
 
### Lifecycle
 
Created by the human against a specific tip. Consumed once by the hook-gated push, which tombstones it in place. Retained for audit after consumption. A consumed or expired authorization is refused.
 
### Fields
 
| Field | Type | Required | Description |
|---|---|---|---|
| `push_id` | uuid | yes | |
| `authorized_tip_sha` | string | yes | The exact commit authorized to become origin's tip. |
| `authorized_by` | string | yes | The human who authorized. |
| `created_at` | timestamp | yes | |
| `expires_at` | timestamp | yes | |
| `consumed_at` | timestamp | no | Written by the hook on successful push, alongside the origin tip it verified. Presence tombstones the authorization. |
 
### Constraints
- **TOCTOU is closed by re-derivation.** The hook re-derives `git rev-parse HEAD` at push time and refuses unless it equals `authorized_tip_sha` exactly. An authorization is for one specific tip; any commit landing after authorization voids it.
- **Single use.** On successful push the hook rewrites the artifact with `consumed_at` plus the origin tip it verified. A consumed or expired authorization is refused.
- **Operator browser confirmation of the origin tip remains the final layer**, regardless of what this artifact says. The artifact narrows the window; it does not replace the human looking at origin.
### Example
 
```yaml
push_id: push-0f31
authorized_tip_sha: "<authorized-tip-sha>"
authorized_by: "operator"
created_at: 2026-08-10T09:12:00Z
expires_at: 2026-08-10T10:12:00Z
consumed_at: null
```
 
---
 
## Cross-cutting Notes for the Implementing Architect
 
1. **All artifacts are content-addressed where reasonable.** A spec at version 12 has the same content for everyone who reads it, and is referenced by `(mission_id, version)`.
2. **All schemas should be enforced at write time, not read time.** Invalid handoffs should fail to write, not surprise the next reader. The runtime is the gatekeeper.
3. **All sensitive content is redacted at the trace-store write path.** Credentials, PII, and customer data should never sit in trace logs in cleartext, even briefly.
4. **Versioned prompts are first-class artifacts.** Treat them like code: PR-reviewed, tagged, runnable through the eval suite before promotion. The trace event's `prompt_version` field is what closes the loop between production failures and prompt iteration.
5. **The id namespace matters.** Use prefixed ids (`A-`, `F-`, `M-`, `D-`, `mission-`, `wt-`, `trace-`, etc.) to make logs and dashboards readable.
6. **Retention policy is a real decision.** Trace events accumulate fast. A reasonable default: hot store for the life of the mission plus 30 days, archive store for 1 year, then purge. Adjust for compliance requirements.
7. **A field the model can write is testimony; a field the runner writes from evidence is an anchor.** `runner_anchors` (§5, §6) and the whole of §12 are the second kind. Do not let a schema make them look alike — an implementation that lets a model populate an anchor field has removed the property the field exists for, while leaving every name in place.
8. **Declaring a closed enum is a claim, and claims decay.** Three fields in this document were declared closed and are retyped as open, since live data can carry values outside a declared set. Where a vocabulary is genuinely open, type it `string` and record the observed population with the command that derives it, so the next reader re-derives instead of trusting a snapshot. See *Open-vocabulary fields*.
---
 
## Registered decisions
 
The A1 program accumulated questions that could not be settled without these schemas in front of us. Each is resolved here with an explicit decision, or explicitly deferred — a decision recorded as "deferred" resolves the question of status; a decision left unmentioned resolves nothing.
 
| Item | Status | Where |
|---|---|---|
| **A review finding:** `seq` allocation race under concurrent hooks | RESOLVED — declared non-unique, not made safe | §12, *The append-only log* |
| **A review finding:** the manifest carries no `seq` | RESOLVED — deliberate; gap detection lives in the log, with the consequence stated | §12, *The append-only log* |
| **A review finding:** no declared schema for `log.jsonl` | RESOLVED — schema declared, both variants, from the sealed hooks | §12, *The append-only log* |
| **A review finding:** a fieldless valid-JSON log line yields a schema-invalid manifest that still derives consumable | RESOLVED — state and schema-validity declared independent; a consumer owes both checks | §12, *Constraints* |
| **A review finding:** stream-integrity check ordering false-positives on an honest capture failure | **DEFERRED TO A3** at wiring time. Not resolved here, and not left looking resolved. | — |
| **Operator-maintenance pathway** (v2.2 §4.5 law 8) | RESOLVED AS PROCESS — see below | this section |
| **Ceremony-commit `-m` metacharacter narrowing** | REGISTERED DESIGN CANDIDATE — not built | this section |
| **Vocabulary governance** — whether and how an open vocabulary re-closes | REGISTERED — framework design item, v2.2+ / A3 era | *Open-vocabulary fields* |
| **`Report` as a `runner_anchors` carrier** | REGISTERED — term recorded, no artifact invented | below |
| **Unmeasured enum fields** | REGISTERED — three fields measured; every other enum unverified | *Open-vocabulary fields* |
| **Retype coverage** — nothing pairs a changed field *type* with the ruling that changed it | REGISTERED — the shipped acceptance test derives and checks field *names*, never declared types, so a silent retype and an operator-ruled one are indistinguishable to it; the rulings are recorded in the consolidation record and no check enforces the pairing | *Consolidation record*; §7, §8 |
| **A1 deviations from design §12.3** | RATIFIED | §12, *Normative source* |
| **`TAMPERED` vocabulary alignment** | RESOLVED — adopted; no longer A1-local | §12, *Normative source* |
 
**Operator-maintenance pathway.** Modifying the capture machinery is an operator-mediated act, not an agent act. The PreToolUse guard denies an agent staging changes to `tools/framework/hooks/**`, the installer, the test tree and `.claude/settings.json` by design: a session that could edit the capture machinery and seal that change into history would hold the pen on its own evidence one level up. Post-install maintenance commits are therefore made by the operator. **Schema impact: none.** No artifact schema changes; the constraint is on authorship, and it is recorded here so that a future runner design does not quietly grant an agent the staging capability the guard exists to withhold. **Disclosed limit:** bulk staging (`git add .`, `git add -A`, `git commit -a`) reaches the machinery anyway. The property is not enforced — the guard is an accident tripwire, not a boundary.
 
**Ceremony-commit `-m` metacharacter narrowing.** Parentheses or other shell metacharacters inside a quoted `git commit -m` argument, combined with a protected path, currently deny. The cost is real and the failure is safe. A message-aware carve-out — so shell-inactive metacharacters inside a quoted `-m` argument do not trip the gate — is a candidate, not a commitment. **Not built:** no message parser exists in the capture machinery, and this document does not add one.
 
**`Report` as a `runner_anchors` carrier.** v2.2 §12.2 names three carriers: Handoff, ValidatorResult and Report. The first two are §5 and §6. **No artifact in this schema set is named Report, and none is invented for it here.** The term denotes any session-level report artifact a topology adds; when such an artifact is schematized it inherits `runner_anchors` with the shape and constraints in §5. Registered rather than resolved, because inventing an artifact to satisfy a term would be exactly the rediscovery v2.2 §12.3 forbids.
 
---
 
## What this document does not claim
 
It is a specification. It builds no runner, installs no hooks, and does not verify harness wiring — which remains unverified and operator-gated per v2.2 §14.2. Every statement here about what the A1 machinery does is derived from reading the sealed sources, not from observing a live harness invoke them.
 
The evidence-plane enforcement claims are inherited from A1 and are not re-argued here: mount exclusion (design §4.1 layer (a)) is unavailable for natively-run sessions per erratum E1; harness-side capture (layer (b)) carries the integrity claim and is unverified under a real harness; the PreToolUse guard (layer (c)) is an accident tripwire and is not a write boundary: string inspection of shell commands cannot be a boundary, because matching shell semantics correctly is implementing a shell.
 
**No *standing* enforcement is claimed for this document's own shape**, and an earlier form of this paragraph understated what does exist. An acceptance test ships beside this document at `tools/framework/tests/test-a2-acceptance.ps1`. It checks that every field named by v2.2 §12, by the sealed `evidence-manifest.schema.json`, and by the capture hook's own log-line construction appears here with exact spelling; that every row of *Registered decisions* carries a status; that the observed populations re-derive verbatim; and that the encoding holds. Each of those field sets is read from its source rather than transcribed, so none of them is a list this document maintains.
 
What the test is not is standing. **Nothing invokes it** — no hook, no gate, no ceremony step — so it decides only when a person runs it, and its population check skips at any HEAD other than the derivation anchor rather than deciding on moved ground. It is an instrument, not a boundary, and this document can drift between runs of it.
 