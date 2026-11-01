# expanded-schemas.md §8 — Amendment Request (in-repo verbatim copy)

> **Status:** In-repo verbatim copy of `expanded-schemas.md` §8 (Amendment Request)
> plus the shared implicit-fields preamble. Committed so spec-amendment artifacts
> conform to a schema present in the repo (replayability per §14 criterion 3),
> without depending on the not-in-repo canonical authority. Mirrors the §6
> (ValidatorResult) and §7 (Memory Ledger Entry) fragment precedents.
>
> **Canonical authority:** `expanded-schemas.md` (operator project-knowledge). This
> file holds the same text; the canonical document remains the source of truth if
> the two ever diverge. The broader gap: framework documents were not then
> committed in-repo.
>
> **Field-naming note (divergence, not reconciliation).** The §8 schema below
> prescribes the field pair `target_type` + `target_id`. Amendments authored
> before schema-aware authoring may use a different form: they may carry
> `target:` (a path string), and possibly `target_path_within_file:`.
> These are NOT rewritten (amendments are immutable records). The §8 `target_type`/
> `target_id` pair is canonical and is used by all amendments authored going forward
> (older records are left as written). Their enum values are not out-of-schema;
> this is a field-name-shape divergence in the oldest records only.

---

## Shared implicit fields (verbatim preamble)

All artifacts share three implicit fields enforced by the runtime:
- `id: uuid` — unique
- `created_at: timestamp` — set at write
- `created_by: string` — agent or human identifier

---

## 8. Amendment Request (verbatim)

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
| `target_type` | enum | yes | `assertion`, `feature`, `milestone`, `decision`, `scope`, `schema`. |
| `target_id` | string | conditional | Required unless `target_type` is `scope` or `schema`. |
| `change_type` | enum | yes | `relax`, `tighten`, `replace`, `add`, `remove`. |
| `proposed_change` | string | yes | The new content, fully written. |
| `rationale` | string | yes | Why the change is needed. |
| `evidence` | list\<EvidenceItem\> | no | Trace pointers, validator results, or external references supporting the rationale. |
| `material_change` | bool | yes | Triggers human approval if true. |
| `status` | enum | yes | `proposed`, `approved`, `rejected`, `withdrawn`. |
| `decision_rationale` | string | conditional | Required when status is `approved` or `rejected`. |
| `produced_spec_version` | int | conditional | Set on approval ONLY when the amendment changes the **spec surface** — spec-body entities (the `.mission/spec/v*.yaml` chain) OR versioned artifacts under `.mission/spec/` (including `.mission/spec/proposals/`). NULL when the amendment changes governed code/config OUTSIDE the spec surface (gateway policy under `tools/tool-gateway/`, tool-config schema fragments under `tools/mission-cli/config/`, allowlists, etc.). The classification axis is **location**, NOT `target_type`-ness: a `target_type:schema` amendment may bump (e.g., edits to `.mission/spec/proposals/<schema>.yaml`) or NOT bump (e.g., edits to `tools/mission-cli/config/expanded-schemas-section-*.md`). |

### Target-type semantics

- `assertion` — amends a contract assertion (spec-body entity under `.mission/contract/assertions/`).
- `feature` — amends a feature entry in `.mission/spec/v*.yaml`.
- `milestone` — amends a milestone entry in `.mission/spec/v*.yaml`.
- `decision` — amends a `decisions[]` entry in `.mission/spec/v*.yaml`.
- `scope` — amends a `scope_inclusions` / `scope_exclusions` entry in `.mission/spec/v*.yaml`. (`target_id` is null because scope entries are list elements, not named entities.)
- `schema` (a later addition) — amends a schema or structural artifact. May live INSIDE the spec surface (e.g., `.mission/spec/proposals/<schema>.yaml`) or OUTSIDE it (e.g., `tools/mission-cli/config/expanded-schemas-section-*.md`, `tools/tool-gateway/` policy). The **location** determines `produced_spec_version`, not the enum value.

### `produced_spec_version` classification rule

Grounded in three precedent shapes:

| Amendment | Edit location | Spec-surface? | `produced_spec_version` |
|---|---|---|---|
| Precedent 1 | `tools/mission-cli/config/` (§7 fragment) | NO | `null` |
| Precedent 2 | `tools/tool-gateway/` (gateway code + schema field) | NO | `null` |
| Precedent 3 | `.mission/spec/proposals/` (a schema artifact) | YES | next version (bumped) |
| This rule's codification | `tools/mission-cli/config/` (§8 fragment) | NO | `null` (self-applied) |

The codifying amendment's self-classification IS the rule's coherence test: edits to a §8 schema fragment outside `.mission/spec/` MUST NOT bump the version chain (the spec body isn't changing), even though the amendment IS schema-targeted. If `target_type` controlled the bump rather than location, the codifying amendment would self-contradict.

### Constraints
- An amendment cannot target an entity that doesn't exist in the current spec version.
- Workers must pause work on the affected scope while the amendment is pending.
- `material_change: true` cannot be approved without a human approval event in the audit trail.
