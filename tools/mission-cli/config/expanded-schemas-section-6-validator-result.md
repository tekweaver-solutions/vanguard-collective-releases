# expanded-schemas.md §6 — Validator Result (in-repo verbatim copy)

> **Status:** In-repo verbatim copy of `expanded-schemas.md` §6 (Validator
> Result + EvidenceItem sub-schema). Committed to the repo so a mission's
> closure ValidatorResults conform to a schema present in the repo
> (replayability per §14 criterion 3), without depending on the
> not-in-repo canonical authority.
>
> **Canonical authority:** `expanded-schemas.md` (operator
> project-knowledge). This file holds the same text; the canonical
> document remains the source of truth if the two ever diverge. The
> broader gap: framework documents were not then committed in-repo.
> This slice is committed because closure evidence needs a schema
> present in the repository to replay against; that is the
> rationale specific to this slice.
>
> **Implementation in code:** a validator's internal `ValidatorResult` /
> `Finding` accumulators, where it has them, are the
> validator's own pipeline accumulator (Layer 1 / 2 / 3 finding
> aggregation); the §6 envelope below is the framework-level wrapper
> a closure-evidence harness emits to close the mission's
> assertions.

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
| `assertion_ids` | list<string> | conditional | Required if `qa`. May cover many. |
| `verdict` | enum | yes | `pass`, `fail`, `inconclusive`. |
| `evidence` | list<EvidenceItem> | yes | See sub-schema. Required even on pass for audit. |
| `failure_summary` | string | conditional | Required on `fail` or `inconclusive`. |
| `attempt_number` | int | yes | 1 for first attempt; increments on rework cycles. |
| `commit_sha` | string | yes | The exact commit validated. |

### EvidenceItem sub-schema

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | enum | yes | `test_output`, `http_trace`, `screenshot`, `log`, `metric`, `manual_observation`. |
| `content` | string | yes | Inline payload or pointer to blob storage. |
| `description` | string | yes | What this evidence shows. |
