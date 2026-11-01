# expanded-schemas.md additions — ADR-032 (Worker Task-Instruction Channel)

> **Renumbered (file + body) from ADR-007.** Companion to the
> "Worker Task-Instruction Channel" ADR, which was renumbered off a colliding
> ADR-007 → ADR-032 (the folded ADR-007 "Bootstrap is a deterministic script"
> retains 007). See `adr-032-worker-task-instruction-channel.md` and
> `adr-007-bootstrap-deterministic-script.md`.
>
> **Status:** Draft. Surfaces the framework-document edits ADR-032 calls for
> (decision 4 + decision 6). Operator owns framework-doc edits per ADR-032's
> "Doc-update targets" section — this file holds the proposed text in
> isolation so it can be folded into the canonical `expanded-schemas.md`
> wherever the operator keeps it (the parent doc was not then committed
> in-repo, which is why this draft stands alone).
>
> **Implementation in code:** `tools/worker-runner/schemas.py` already lands
> the matching Pydantic models (`TaskBrief`; `brief_version` field added to
> `LLMCallTrace`) per ADR-032 decision 4's write-time-enforcement
> requirement. This draft is the doc side of that change; the code side does
> not block on it.

---

## §N — Task Brief *(new artifact section)*

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
| `dispatch_id` | ref<Dispatch> | ✓ | The dispatch this brief belongs to. Operational identity (the file lives at the dispatch-id-keyed path). |
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

---

## §9 LLMCallTrace — `brief_version` field *(addition)*

Add an optional `brief_version` field alongside the existing
`prompt_version`, parallel in shape and intent (ADR-032 decision 6).

| Field | Type | Required | Notes |
|---|---|---|---|
| `brief_version` | optional string | — | Versioned task-brief-template id. Parallel to `prompt_version`. `prompt_version` tracks the role-prompt channel; `brief_version` tracks the per-dispatch task channel (see Task Brief). Optional because not every LLM call is tied to a worker dispatch (e.g., orchestrator-side calls); on worker LLM calls the runner populates it from the constructed `TaskBrief.brief_version`. |

**Closes F5.** The runner-internal F5 gap (`runner.py` notes the
user-message / task fragment is not currently captured) is closed by:
(a) committing the brief as an artifact under
`.mission/dispatches/<dispatch_id>/task-brief.md`, and (b) emitting the
template version on every worker `LLMCallTrace.brief_version`. The eval
loop (§14.5) can now correlate which task-brief template produced which
handoff outcomes.

### Schema (Pydantic, source-of-truth)

`tools/worker-runner/schemas.py :: LLMCallTrace.brief_version`.

---

## Tradeoff acceptances (carried from ADR-032)

- **Two framework-document changes** (this draft): a new Task Brief
  artifact section + a `brief_version` field on §9. Heavier than a
  runtime-only design; paid for the audit position.
- **A new committed artifact kind in `.mission/`.** `.mission/dispatches/`
  becomes a tracked tree. Per-dispatch growth, mitigated by brief size
  (objective + index + optional note).
- **Inlined template debt carried, not closed.** The brief generator
  lives as an inlined constant until `prompts/` registry init (same
  deferred-promotion debt as the handoff instruction). `brief_version`
  records the inlined version meanwhile.

---

## References

- ADR-032 — Worker Task-Instruction Channel (this draft implements).
- ADR-023 — Skills as committed artifacts (role/task channel split).
- ADR-012 / ADR-017 — Prompt registry (eventual home for the brief-generator template).
- `tools/worker-runner/schemas.py :: TaskBrief` and `LLMCallTrace.brief_version` — code side already landed.
- Why this draft is standalone instead of an in-place edit: the parent doc was not then committed in-repo.
