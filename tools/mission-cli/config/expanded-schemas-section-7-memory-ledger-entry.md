# expanded-schemas.md §7 — Memory Ledger Entry (in-repo verbatim copy + reconciliation note)

> **Status:** In-repo verbatim copy of `expanded-schemas.md` §7 (Memory Ledger
> Entry) plus the shared implicit-fields preamble. Committed so the mission
> ledger conforms to a schema present in the repo (replayability per §14
> criterion 3), without depending on the not-in-repo canonical authority.
>
> **Canonical authority:** `expanded-schemas.md` (operator project-knowledge).
> This file holds the same text; the canonical document remains the source of
> truth if the two ever diverge. The broader gap: framework documents
> were not then committed in-repo.
> This copy closes that gap for §7.
>
> **NON-CONFORMANCE NOTICE — read before treating the enums below as binding for
> this repo.** Unlike the §6 fragment (whose repo conformed to the schema as
> written), this repo does NOT currently conform to the §7 `scope` and `type`
> enums copied verbatim below. The live ledger convention diverges; the
> divergence is documented in the "In-repo reconciliation" section AFTER the
> verbatim copy, and is being formalized via a pending amendment. Do not read
> the verbatim enums as the operative in-repo convention until that amendment
> lands. The verbatim copy is preserved unaltered for canonical fidelity.

---

## Shared implicit fields (verbatim preamble)

All artifacts share three implicit fields enforced by the runtime:
- `id: uuid` — unique
- `created_at: timestamp` — set at write
- `created_by: string` — agent or human identifier

---

## 7. Memory Ledger Entry (verbatim)

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
| `type` | enum | yes | `gotcha`, `decision`, `constraint`, `correction`, `runtime_audit`. |
| `scope` | enum | yes | `global`, `milestone`, `feature`. |
| `scope_ref` | string | conditional | Milestone or feature id, required if scope is not global. |
| `content` | string | yes | The actual learning. Should be self-contained. |
| `source_trace_id` | uuid | no | Trace that produced this finding. |
| `supersedes` | uuid | no | Earlier entry this corrects. |
| `tags` | list<string> | no | For retrieval. |

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

## In-repo reconciliation (pending amendment)

> This section is NOT part of canonical §7. It records how the live in-repo
> ledger diverges from the verbatim copy above, and the resolution being
> formalized by amendment. It exists so the in-repo authority does not silently
> assert enums this repo violates.

**Observed divergence (grounding read of a live ledger):**

- `scope` enum. Verbatim §7 defines `{global, milestone, feature}`. The live
  ledger uses `{global, framework, product, mission}`.
  `milestone` and `feature` have zero occurrences; `framework` and `product`
  are the two highest-frequency values. The operative live axis is **subject
  (framework vs product)** — what a learning is *about* (the harness/runtime vs
  the product under construction) — not the **granularity** axis
  (global/milestone/feature) §7 was designed around.
- `type` enum. Verbatim §7 defines `{gotcha, decision, constraint, correction}`.
  The live ledger additionally carries `type: lesson` on some entries.
- Implicit fields. All live entries carry `created_at` and `created_by` (the
  shared implicit-fields preamble), in addition to §7's `ts` and `author`.

**Resolution (formalized by the pending §7 amendment, AM to be filed):**

1. `scope`: extend the enum to add `framework` and `product`, recognizing the
   subject axis the live ledger already runs on. `mission` folds to `global`
   (mission-wide == global; no distinct meaning). `milestone` and `feature` are
   retained in the enum as designed-for-but-currently-unused.
2. `type`: `lesson` is NOT added; it folds to `gotcha` going forward (a "lesson"
   is a gotcha's after-the-fact framing). The existing `lesson` entries are
   addressed by a `correction` entry, not rewritten (immutable ledger).
3. Implicit fields: `created_at`/`created_by` are canonical-by-convention (see
   the Task Brief artifact in `expanded-schemas-adr-032-additions.md`, which
   carries them as explicit "cross-cutting framework convention" fields).
   `ts`/`author` are retained as aliases; the mapping is `ts` ≈ `created_at`,
   `author` ≈ `created_by`. No entries are rewritten.

Until the amendment lands, treat the four-value scope set
`{global, framework, product, mission}` as the descriptive in-repo reality and
the resolution above as the prescriptive target.
