"""
Pydantic schemas for the worker-runner -- the runtime types the runner
serializes against.

Source-of-truth: expanded-schemas.md §4 (Worker Dispatch), §5 (Handoff),
§9 (Trace Event), §10 (Worktree Record), plus ADR-007 (Task Brief --
the per-dispatch task channel; `brief_version` on §9 LLMCallTrace; new
Task Brief artifact section, draft additions in
`tools/mission-cli/config/expanded-schemas-adr-007-additions.md` pending
operator fold-in). All four §-numbered schemas + the ADR-007 additions
are covered.

Cross-cutting discipline (expanded-schemas.md §"Cross-cutting Notes"):
- Schema enforcement is at WRITE time, not read time (note 2).
- Sensitive content redaction happens at the trace-store write path,
  not here (note 3). This schema does NOT model credentials of any kind:
  a product's credentials live in the product's own code, and the
  dispatch never names one.
- Id namespace: prefixed ids (`wt-`, `mission-`, `dispatch-`, ...) per
  note 5. Validators in this module accept prefixed strings; the
  prefix-shape is not regex-enforced at MVP (designer-flag for later).
- Mutability: all schemas in this module are immutable (frozen=True)
  EXCEPT WorktreeRecord, which is mutated in-place by the worktree-
  manager as commits land and state transitions occur. The
  WorktreeRecord class docstring documents the divergence.

Inferred-vs-confirmed (WorkerDispatch §4):
- CONFIRMED from §4 table: id, mission_id, worker_id, kind,
  feature_id, assertion_targets, spec_version, prior_handoff_id,
  worktree_id, model_class, tool_scope, budget, rework_evidence.
- CONFIRMED via the cross-cutting framework convention (three implicit
  runtime-enforced fields per expanded-schemas.md): id, created_at,
  created_by.
- INFERRED (called out inline below): ModelClass enum values (§4
  example only shows two; the four-value enum from the kickoff prompt
  §5 is canonical); WorkerBudget sub-fields (cost_cap_usd,
  wallclock_cap_minutes per §4 example); ReworkEvidence sub-fields
  (failing_assertion_id, validator_result_ref); tool_scope string
  format (capability-tagged strings per §4 example + kickoff prompt
  §"6.2 tool gateway").

Inferred-vs-confirmed (Handoff §5):
- CONFIRMED from §5 table: id, from_worker, dispatch_id, feature_id,
  spec_version, completed_assertions, unfinished, commits,
  commands_run, issues_observed, suggested_next, procedure_adherence,
  deviation_notes, terminated_reason.
- CONFIRMED from §5 sub-schemas: UnfinishedItem.{assertion_id, reason,
  partial_progress, blocker}, CommandLog.{cmd, exit_code,
  stderr_excerpt}.
- CONFIRMED from §5 Constraints (all three): non-empty `unfinished`
  vs. `terminated_reason: completed`; `procedure_adherence: deviated`
  requires `deviation_notes`; every `completed_assertions` entry must
  be in dispatch's `assertion_targets` (CROSS-ARTIFACT -- not
  schema-enforceable; flagged in Handoff docstring for runner-level
  enforcement).
- INFERRED: git-SHA regex (`^[A-Fa-f0-9]{7,40}$`) on `commits[i]` --
  §5 says "Git SHAs created" but doesn't pin shape; standard hex
  abbreviated-or-full is the safe pattern.

Inferred-vs-confirmed (TraceEvent §9):
- CONFIRMED from §9 base table: id, parent_id, mission_id, agent_id,
  agent_role, type, started_at, duration_ms, status, error
  (conditional).
- CONFIRMED from §9 type-specific tables: LLMCall (model,
  prompt_version, tokens_in, tokens_out, cost_usd, input, output);
  ToolCall (tool_name, capability_tag, input, output,
  gateway_decision); StateTransition (from_state, to_state, trigger).
- CONFIRMED from §9 Constraints: immutable (frozen=True), full
  input/output retained (no summarization), redaction at write time
  (runner-level concern; documented in TraceEventBase docstring, not
  schema-enforced).
- INFERRED: Checkpoint and Escalation event types have NO §9-named
  additional fields; modeled as base-only subclasses with just the
  `type` discriminator. If they grow, extend in place.
- INFERRED: cross-cutting `created_at` and `created_by` convention is
  satisfied by `started_at` and `agent_id` respectively (semantic
  equivalents at this layer); no separate fields added.
- INFERRED: `input` / `output` typed as `dict[str, Any]` -- §9 says
  "object" generically; arbitrary-JSON shape is correct for both LLM
  and tool payloads.
- INFERRED: `started_at` modeled as `str` (ISO-8601) to match
  WorkerDispatch.created_at / Handoff.created_at; the §9 doc types it
  as "timestamp." Flagged for follow-up: if the framework moves to
  `datetime` for typed timestamps, all three sites convert together.

Inferred-vs-confirmed (WorktreeRecord §10):
- CONFIRMED from §10 table: id, mission_id, kind, branch, path,
  current_worker (conditional), base_commit, head_commit,
  port_assignments (optional), state, conflict_set (optional).
- CONFIRMED divergence: WorktreeRecord is NOT immutable. §10 names
  head_commit as "Updated as commits land" and the lifecycle covers
  state transitions (active -> merging -> merged | discarded ->
  gc_pending). `frozen=True` is omitted here -- the only schema in
  the module without it. The worktree-manager updates the record over
  its lifecycle; downstream readers see snapshots.
- CONFIRMED conditional: current_worker required iff kind == FANOUT
  AND state == ACTIVE. Enforced by the model_validator below.
- INFERRED: `base_commit` / `head_commit` get the same git-SHA regex
  (`^[A-Fa-f0-9]{7,40}$`) as Handoff.commits[i].
- INFERRED: `port_assignments` value type is `int` per §10 ("map<string,
  int>"). Bounded to TCP port range 1-65535 via Field constraints.
- INFERRED: `created_at` added per cross-cutting framework convention
  (timestamps on mutable records help debugging). `created_by` NOT
  added -- §10's Authors line names "worktree manager" unambiguously,
  and there's no semantic stand-in field; redundant. Flagged for
  operator decision.
- INFERRED: `conflict_set` defaults to empty list (matching §10
  example), not None. An explicit `None` would model "not yet
  scanned"; empty list models "scanned, no conflicts." The latter is
  the operationally common case and avoids None-vs-empty branching
  in callers.
"""

from __future__ import annotations

import re
from enum import Enum
from typing import Annotated, Any, Literal, Optional, Union
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    NonNegativeFloat,
    NonNegativeInt,
    PositiveInt,
    TypeAdapter,
    field_validator,
    model_validator,
)


# ----- Capability-vocabulary validation (ADR-027 D1 + D2) -----
# Tags a worker cannot be granted under any circumstance until the C2
# sandbox/egress containment layer is built (per ADR-026 D3 + ADR-027 D2).
# The Pydantic field_validator on WorkerDispatch.tool_scope below is the
# FLOOR — it rejects these tags at any direct constructor call.
# dispatch_entry.build_dispatch carries the human-facing C2-reason text.
_C2_PROHIBITED_TAGS: frozenset[str] = frozenset({
    "shell.exec.sandboxed",
    "shell.exec.unsandboxed",
})


def _grantable_vocabulary() -> frozenset[str]:
    """The worker-grantable capability vocabulary, computed lazily from
    CapabilityMap.default() so ADR-015's amendment-by-data discipline holds
    (no hardcoded Literal enum coupling the schema to the capability map).

    Filters:
      - framework.* sentinels — not requestable by workers.
      - shell.exec.* — prohibited until C2 lands (ADR-027 D2 enforcement
        ALSO catches these at build_dispatch with a friendlier C2-specific
        reason; the floor here rejects them generically).
    """
    # Lazy import: schemas.py is imported by many modules; CapabilityMap.default()
    # reads mcp-tools.yaml at construction. Importing at module level would
    # change the import topology and could surprise minimal-environment users.
    from mcp_capability_map import CapabilityMap  # noqa: E402

    all_tags = CapabilityMap.default().tags()
    return frozenset(
        tag for tag in all_tags
        if not tag.startswith("framework.")
        and tag not in _C2_PROHIBITED_TAGS
    )


# ----- Enums -----

class WorkerKind(str, Enum):
    """Why the worker is being dispatched. Per §4 table `kind` enum."""
    MAINLINE = "mainline"
    FANOUT = "fanout"
    REWORK = "rework"


class ModelClass(str, Enum):
    """
    Logical model class the dispatch requests. Resolved to a concrete
    provider+model at runtime via `tools/mission-cli/config/model-routing.yaml`
    (per ADR-005 + kickoff prompt §5).

    §4 example shows `coding-strong` and `coding-fast` only; the kickoff
    prompt §5 names the canonical four. INFERRED that the enum is closed
    at these four for MVP -- if the routing config gains a fifth class
    later, the enum extends here.
    """
    CODING_STRONG = "coding-strong"
    CODING_FAST = "coding-fast"
    NARROW_VALIDATOR = "narrow-validator"
    QA_VALIDATOR = "qa-validator"


# ----- Sub-models -----

class WorkerBudget(BaseModel):
    """
    Per-worker resource caps. §4 example shape (cost_cap_usd +
    wallclock_cap_minutes); the runner enforces these as hard ceilings,
    not soft warnings (kickoff prompt §6.3 circuit breaker territory --
    INFERRED until §6.3 read).
    """
    model_config = ConfigDict(extra="forbid")

    cost_cap_usd: NonNegativeFloat = Field(
        description="Hard ceiling on cumulative LLM-call cost. Runner halts the worker at this cap.",
    )
    wallclock_cap_minutes: PositiveInt = Field(
        description="Hard ceiling on wall-clock runtime. Runner halts the worker at this cap.",
    )


class ReworkEvidence(BaseModel):
    """
    Populated only when WorkerDispatch.kind == REWORK.
    §4 description: "includes failing assertion id and validator evidence."
    Sub-fields INFERRED -- the schema doc names the shape only descriptively.
    The validator_result_ref points to a ValidatorResult artifact per §6
    (also INFERRED until §6 read).
    """
    model_config = ConfigDict(extra="forbid")

    failing_assertion_id: str = Field(
        description="Assertion id (e.g. 'A-024') that the prior worker's handoff failed against.",
        pattern=r"^A-\d{3,}$",
    )
    validator_result_ref: str = Field(
        description="Reference to the ValidatorResult artifact carrying the failure evidence.",
    )


# ----- Main model -----

class WorkerDispatch(BaseModel):
    """
    The instruction the orchestrator gives a worker when starting it --
    the worker's full input contract.

    Authors: orchestrator only (the mission-dispatch.ps1 entry script).
    Readers: the dispatched worker; logged for trace.
    Lifecycle: created on dispatch, immutable thereafter; one per worker invocation.

    Per §4 table, all `required` fields are populated; optional fields
    (`prior_handoff_id`, `rework_evidence`) default to None.

    Serialization: `model_dump(mode="json")` for trace-event embedding;
    `model_dump_json(indent=2)` for the on-disk dispatch artifact.
    """
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID = Field(
        description=(
            "Stable dispatch id. Per the cross-cutting note on id namespacing, "
            "the wire form in logs is prefixed (`dispatch-...`); this field is "
            "the underlying uuid."
        ),
    )
    created_at: str = Field(
        description="ISO-8601 UTC timestamp of dispatch creation.",
    )
    created_by: str = Field(
        description="Agent id of the dispatcher (e.g. 'claude-code:orchestrator').",
    )

    mission_id: str = Field(
        description="ref<Mission> -- string id of the mission record this dispatch belongs to.",
    )
    worker_id: str = Field(
        description="Stable identifier for this worker instance. Per §4 free-form string.",
    )
    kind: WorkerKind = Field(
        description="Why this worker is being dispatched.",
    )
    feature_id: str = Field(
        description="Feature this worker is implementing (e.g. 'F-001').",
        pattern=r"^F-\d{3,}$",
    )
    assertion_targets: list[str] = Field(
        description="Assertions this worker should make pass (e.g. ['A-001','A-002']).",
        min_length=1,
    )
    spec_version: PositiveInt = Field(
        description="Spec version the worker reads against. Pins the dispatch to a frozen spec.",
    )
    prior_handoff_id: Optional[str] = Field(
        default=None,
        description="ref<Handoff> -- handoff this worker is starting from. None for first dispatch on a feature.",
    )
    worktree_id: str = Field(
        description="ref<Worktree> -- where this worker writes. Resolved by worktree-manager.",
    )
    model_class: ModelClass = Field(
        description="Logical model class; routing config resolves to a concrete model.",
    )
    tool_scope: list[str] = Field(
        description=(
            "Capability-tagged tools this worker may invoke. Tags must be members "
            "of the worker-grantable vocabulary (CapabilityMap.tags() minus the "
            "framework.* sentinels minus shell.exec.* which is C2-prohibited per "
            "ADR-026 D3 + ADR-027 D2). The field_validator below is the floor "
            "that catches direct constructor calls; dispatch_entry.build_dispatch "
            "is the gate with C2-specific human-facing reasons."
        ),
        min_length=1,
    )

    @field_validator("tool_scope", mode="after")
    @classmethod
    def _validate_tool_scope_vocabulary(cls, v: list[str]) -> list[str]:
        """ADR-027 D1+D2 (floor layer): every element must be a member of the
        worker-grantable capability vocabulary. Non-string elements (and other
        malformed shapes) are rejected by Pydantic before this validator runs;
        this validator handles the vocabulary check.

        Fail-closed: any element not in the grantable set raises ValueError,
        which Pydantic converts to a ValidationError surfaced to the caller.
        Generic message — `build_dispatch` provides the C2-specific text for
        the shell.exec.* subset.
        """
        grantable = _grantable_vocabulary()
        offending = [tag for tag in v if tag not in grantable]
        if offending:
            raise ValueError(
                f"tool_scope contains tag(s) not in worker-grantable "
                f"vocabulary: {sorted(offending)!r}. "
                f"Grantable vocabulary: {sorted(grantable)!r}. "
                f"(framework.* sentinels and shell.exec.* are filtered out; "
                f"shell.exec.* requires C2 sandbox/egress layer per ADR-026 D3.)"
            )
        return v

    budget: WorkerBudget = Field(
        description="Per-worker resource caps. Required.",
    )
    rework_evidence: Optional[ReworkEvidence] = Field(
        default=None,
        description="Required iff kind == REWORK; None otherwise. Enforced by the model_validator below.",
    )

    @model_validator(mode="after")
    def _validate_rework_evidence_consistency(self) -> "WorkerDispatch":
        """Cross-field constraint: rework_evidence required iff kind == REWORK."""
        if self.kind == WorkerKind.REWORK and self.rework_evidence is None:
            raise ValueError(
                "WorkerDispatch.rework_evidence is required when kind == 'rework' "
                "(per §4 'If kind: rework, includes failing assertion id and "
                "validator evidence')."
            )
        if self.kind != WorkerKind.REWORK and self.rework_evidence is not None:
            raise ValueError(
                "WorkerDispatch.rework_evidence must be None when kind != 'rework'."
            )
        return self


# ============================================================================
# Handoff Document -- expanded-schemas.md §5
# ============================================================================


# ----- Enums -----

class ProcedureAdherence(str, Enum):
    """Per §5 table `procedure_adherence` enum."""
    CONFIRMED = "confirmed"
    DEVIATED = "deviated"


class TerminatedReason(str, Enum):
    """Per §5 table `terminated_reason` enum (five values)."""
    COMPLETED = "completed"
    BUDGET_EXHAUSTED = "budget_exhausted"
    TOOL_BLOCKED = "tool_blocked"
    AMENDMENT_FILED = "amendment_filed"
    CRASH_RECOVERED = "crash_recovered"


class Blocker(str, Enum):
    """Per §5 UnfinishedItem `blocker` enum. Optional field; this enum is closed."""
    SPEC_AMBIGUOUS = "spec_ambiguous"
    DEPENDENCY_MISSING = "dependency_missing"
    TOOL_UNAVAILABLE = "tool_unavailable"
    TIME_EXHAUSTED = "time_exhausted"
    UNKNOWN = "unknown"


# ----- Sub-models -----

class UnfinishedItem(BaseModel):
    """Per §5 UnfinishedItem sub-schema."""
    model_config = ConfigDict(extra="forbid")

    assertion_id: str = Field(
        description="Assertion the worker did not finish (e.g. 'A-023').",
    )
    reason: str = Field(
        description="Why it was not completed.",
        min_length=1,
    )
    partial_progress: Optional[str] = Field(
        default=None,
        description="What was done. Helps the next worker pick up.",
    )
    blocker: Optional[Blocker] = Field(
        default=None,
        description="Coarse-grained blocker category, if known.",
    )


class CommandLog(BaseModel):
    """Per §5 CommandLog sub-schema."""
    model_config = ConfigDict(extra="forbid")

    cmd: str = Field(
        description="The command executed.",
        min_length=1,
    )
    exit_code: int = Field(
        description="Process exit code.",
    )
    stderr_excerpt: Optional[str] = Field(
        default=None,
        description="Last N lines of stderr if non-zero exit. Redaction applied per cross-cutting note 3.",
    )


# ----- Main model -----

class Handoff(BaseModel):
    """
    The structured artifact a worker emits on completion -- the ONLY
    information that propagates to the next worker. Workers do not
    inherit context windows (§5 Purpose).

    Authors: the worker that produced it.
    Readers: orchestrator (always); next worker (if dispatched as
    continuation); validators (for context).
    Lifecycle: created on worker completion (or graceful timeout);
    immutable; schema-validated at the boundary; rejected handoffs
    cause worker respawn (§5 Lifecycle).

    Cross-artifact constraint NOT enforced here (§5 constraint 2):
    "Every `completed_assertions` entry must be in the dispatch's
    `assertion_targets`." This requires the corresponding WorkerDispatch
    to validate; the runner enforces it at handoff-acceptance time in
    `tools/worker-runner/handoff_validator.py` (forthcoming). The schema
    enforces what it can locally (constraints 1 and 3).
    """
    model_config = ConfigDict(extra="forbid", frozen=True)

    # Three cross-cutting framework-required fields (per the convention
    # confirmed in WorkerDispatch above).
    id: UUID = Field(
        description=(
            "Stable handoff id. The wire form in logs is prefixed "
            "(`handoff-...`); this field is the underlying uuid."
        ),
    )
    created_at: str = Field(
        description="ISO-8601 UTC timestamp of handoff creation.",
    )
    created_by: str = Field(
        description="Agent id of the worker that produced this handoff.",
    )

    from_worker: str = Field(
        description="Worker id that produced this handoff. Often equals created_by.",
    )
    dispatch_id: str = Field(
        description="ref<Dispatch> -- the dispatch this completes.",
    )
    feature_id: str = Field(
        description="Feature the work was against (e.g. 'F-003').",
        pattern=r"^F-\d{3,}$",
    )
    spec_version: PositiveInt = Field(
        description="The spec version this work targeted.",
    )

    completed_assertions: list[str] = Field(
        description=(
            "Assertion ids the worker believes it satisfied. Cross-checked "
            "against the dispatch's assertion_targets at handoff-acceptance "
            "time by the runner (not at schema-validation time)."
        ),
    )
    unfinished: list[UnfinishedItem] = Field(
        description="Empty list if none. Required to be present (an empty list IS the explicit declaration of completeness).",
    )
    commits: list[str] = Field(
        description=(
            "Git SHAs created by the worker. Empty list legitimate if the "
            "worker filed an amendment or was budget-exhausted before commit."
        ),
    )
    commands_run: list[CommandLog] = Field(
        description="Command-log entries. Required field; empty list legitimate.",
    )
    issues_observed: list[str] = Field(
        description="Notes on the codebase the worker noticed. Feeds the ledger.",
    )
    suggested_next: Optional[str] = Field(
        default=None,
        description="Advisory recommendation for the next dispatch.",
    )

    procedure_adherence: ProcedureAdherence = Field(
        description="Did the worker follow the dispatched procedure or deviate?",
    )
    deviation_notes: Optional[str] = Field(
        default=None,
        description=(
            "Conditional: required iff procedure_adherence == DEVIATED. "
            "Enforced by the model_validator below (§5 constraint 3)."
        ),
    )
    terminated_reason: TerminatedReason = Field(
        description="Why the worker stopped. AMENDMENT_FILED is a terminal state.",
    )

    @model_validator(mode="after")
    def _validate_commit_sha_shape(self) -> "Handoff":
        """Tighten commits[i] to git SHA hex (abbreviated or full)."""
        pattern = re.compile(r"^[A-Fa-f0-9]{7,40}$")
        for i, sha in enumerate(self.commits):
            if not pattern.match(sha):
                raise ValueError(
                    f"Handoff.commits[{i}] = {sha!r} is not a git SHA "
                    f"(expected hex, 7-40 chars)."
                )
        return self

    @model_validator(mode="after")
    def _validate_unfinished_vs_completed(self) -> "Handoff":
        """§5 constraint 1: non-empty unfinished cannot pair with COMPLETED."""
        if self.unfinished and self.terminated_reason == TerminatedReason.COMPLETED:
            raise ValueError(
                "Handoff with non-empty `unfinished` and "
                "`terminated_reason: completed` is invalid (§5 constraint 1). "
                "Use a different terminated_reason or finish the unfinished items."
            )
        return self

    @model_validator(mode="after")
    def _validate_deviation_notes(self) -> "Handoff":
        """§5 constraint 3: DEVIATED procedure_adherence requires deviation_notes."""
        if self.procedure_adherence == ProcedureAdherence.DEVIATED and not self.deviation_notes:
            raise ValueError(
                "Handoff.deviation_notes is required when "
                "procedure_adherence == 'deviated' (§5 constraint 3)."
            )
        if self.procedure_adherence == ProcedureAdherence.CONFIRMED and self.deviation_notes:
            raise ValueError(
                "Handoff.deviation_notes must be None when "
                "procedure_adherence == 'confirmed'."
            )
        return self


# ============================================================================
# Trace Event -- expanded-schemas.md §9
# ============================================================================
#
# Polymorphic: the `type` field discriminates among five subclasses. Use the
# `TraceEventAdapter` TypeAdapter (defined at module bottom) for round-trip
# validation: TraceEventAdapter.validate_python(d) returns the right subclass
# instance based on the `type` field.


# ----- Enums -----

class AgentRole(str, Enum):
    """Per §9 base table `agent_role` enum."""
    ORCHESTRATOR = "orchestrator"
    WORKER = "worker"
    VALIDATOR = "validator"
    RUNTIME = "runtime"


class TraceEventType(str, Enum):
    """Per §9 base table `type` enum. Used as the discriminator."""
    LLM_CALL = "llm_call"
    TOOL_CALL = "tool_call"
    STATE_TRANSITION = "state_transition"
    CHECKPOINT = "checkpoint"
    ESCALATION = "escalation"


class TraceStatus(str, Enum):
    """Per §9 base table `status` enum."""
    SUCCESS = "success"
    ERROR = "error"
    TIMEOUT = "timeout"


class GatewayDecision(str, Enum):
    """Per §9 Tool call additional fields, `gateway_decision` enum."""
    ALLOWED = "allowed"
    DENIED = "denied"


# ----- Base -----

class TraceEventBase(BaseModel):
    """
    Universal trace-event fields. Authors: the runtime, automatically (NOT
    agents directly). Readers: orchestrator (context), humans (debugging),
    eval pipeline (failure clustering).

    Cross-cutting framework convention (per WorkerDispatch/Handoff): the
    implicit `created_at` + `created_by` fields are satisfied here by
    `started_at` and `agent_id` respectively -- semantic equivalents at
    this layer.

    Per §9 Constraints:
      - Immutable (`frozen=True`).
      - The full input/output of LLM and tool calls is retained, NOT
        summarized. This is what makes replay possible (cross-cutting
        note 2 + §9 constraint 2).
      - Sensitive payloads (credentials, PII) must be REDACTED AT WRITE
        TIME, not retrieval time (§9 constraint 3 + cross-cutting note 3).
        Redaction happens in `tools/worker-runner/trace_store.py` -- NOT
        in this schema. The schema does not see or filter payload bytes;
        it accepts what the trace-store writer hands it.

    Subclasses add type-specific fields and constrain `type` to a Literal
    so Pydantic v2 discriminated-union dispatch works. Use
    `TraceEventAdapter` (defined below) for round-trip validation.
    """
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID = Field(
        description=(
            "Stable trace-event id. Wire form in logs is prefixed "
            "(`trace-...`); this field is the underlying uuid."
        ),
    )
    parent_id: Optional[UUID] = Field(
        default=None,
        description="Parent event id; None at the mission root of the trace tree.",
    )
    mission_id: str = Field(
        description="ref<Mission> -- mission this event belongs to.",
    )
    agent_id: str = Field(
        description="Which agent (or runtime component) emitted this event.",
    )
    agent_role: AgentRole = Field(
        description="Role of the emitting agent.",
    )
    started_at: str = Field(
        description="ISO-8601 UTC timestamp when the underlying action began.",
    )
    duration_ms: NonNegativeInt = Field(
        description="Elapsed milliseconds for the underlying action.",
    )
    status: TraceStatus = Field(
        description="Outcome of the action.",
    )
    error: Optional[str] = Field(
        default=None,
        description=(
            "Conditional: required when status != SUCCESS, forbidden when "
            "status == SUCCESS. Enforced by the model_validator below."
        ),
    )

    @model_validator(mode="after")
    def _validate_error_consistency(self) -> "TraceEventBase":
        """§9: `error` required on non-success; forbidden on success."""
        if self.status != TraceStatus.SUCCESS and not self.error:
            raise ValueError(
                f"TraceEvent.error is required when status == {self.status.value!r} "
                "(§9: 'Required on non-success')."
            )
        if self.status == TraceStatus.SUCCESS and self.error:
            raise ValueError(
                "TraceEvent.error must be None when status == 'success'."
            )
        return self


# ----- Per-type subclasses -----

class LLMCallTrace(TraceEventBase):
    """Per §9 LLM-call additional fields. Full input/output retained (§9 c.2)."""
    type: Literal[TraceEventType.LLM_CALL] = TraceEventType.LLM_CALL

    model: str = Field(
        description="Concrete model identifier (e.g. 'claude-opus-4-7').",
    )
    prompt_version: str = Field(
        description=(
            "Versioned prompt id (per cross-cutting note 4: 'closes the loop "
            "between production failures and prompt iteration'). Tracks the "
            "role-prompt (system-prompt) channel."
        ),
    )
    brief_version: Optional[str] = Field(
        default=None,
        description=(
            "Versioned task-brief-template id, parallel to prompt_version "
            "(ADR-007 decision 6). Tracks the per-dispatch task channel "
            "(see TaskBrief). Optional because not every LLM call is tied "
            "to a worker dispatch (e.g., orchestrator-side calls); on "
            "worker LLM calls the runner populates it from the constructed "
            "TaskBrief.brief_version."
        ),
    )
    tokens_in: NonNegativeInt = Field(description="Input token count.")
    tokens_out: NonNegativeInt = Field(description="Output token count.")
    cost_usd: NonNegativeFloat = Field(description="LLM-call cost in USD.")
    input: dict[str, Any] = Field(
        description="Full prompt -- not summarized. Redaction applied at write time.",
    )
    output: dict[str, Any] = Field(
        description="Full response -- not summarized. Redaction applied at write time.",
    )


class ToolCallTrace(TraceEventBase):
    """Per §9 Tool-call additional fields. `gateway_decision` is mandatory."""
    type: Literal[TraceEventType.TOOL_CALL] = TraceEventType.TOOL_CALL

    tool_name: str = Field(
        description="Name of the invoked tool (e.g. 'Read', 'mcp__postman__getCollection').",
    )
    capability_tag: str = Field(
        description=(
            "The capability tag the call resolves to in the gateway's policy. "
            "On ALLOWED, this is the capability that authorized the call. On "
            "DENIED, this is the capability the runner requested -- useful for "
            "mining denied-attempt patterns (which capabilities workers are "
            "reaching for that they don't have)."
        ),
    )
    input: dict[str, Any] = Field(
        description="Full arguments. Redaction applied at write time.",
    )
    output: dict[str, Any] = Field(
        description="Full return value. Redaction applied at write time.",
    )
    gateway_decision: GatewayDecision = Field(
        description=(
            "Whether the tool-gateway allowed or denied this call. Denied "
            "calls are still logged so the eval pipeline can mine denied-"
            "tool-attempt patterns."
        ),
    )


class StateTransitionTrace(TraceEventBase):
    """Per §9 State-transition additional fields. `from_state`/`to_state` are free-form."""
    type: Literal[TraceEventType.STATE_TRANSITION] = TraceEventType.STATE_TRANSITION

    from_state: str = Field(description="Prior state.")
    to_state: str = Field(description="New state.")
    trigger: str = Field(
        description="What caused the transition (free-form designer-flexible).",
    )


class CheckpointTrace(TraceEventBase):
    """
    Checkpoint event. §9 lists `checkpoint` as a valid `type` but does NOT
    name additional fields; modeled as base-only. Extend in place if a
    future event-shape grows.
    """
    type: Literal[TraceEventType.CHECKPOINT] = TraceEventType.CHECKPOINT


class EscalationTrace(TraceEventBase):
    """
    Escalation event. §9 lists `escalation` as a valid `type` but does NOT
    name additional fields; modeled as base-only. Extend in place if a
    future event-shape grows.
    """
    type: Literal[TraceEventType.ESCALATION] = TraceEventType.ESCALATION


# ----- Discriminated union + adapter -----

TraceEvent = Annotated[
    Union[
        LLMCallTrace,
        ToolCallTrace,
        StateTransitionTrace,
        CheckpointTrace,
        EscalationTrace,
    ],
    Field(discriminator="type"),
]
"""
Discriminated-union type alias. Use `TraceEventAdapter.validate_python(d)`
to parse an arbitrary dict into the right subclass; Pydantic dispatches
on the `type` field.
"""

TraceEventAdapter: TypeAdapter[TraceEvent] = TypeAdapter(TraceEvent)
"""TypeAdapter for the discriminated union. Round-trip validation entry point."""


# ============================================================================
# Worktree Record -- expanded-schemas.md §10
# ============================================================================


# ----- Enums -----

class WorktreeKind(str, Enum):
    """Per §10 `kind` enum. Operator-confirmed granularity: one worker per worktree per feature."""
    MAINLINE = "mainline"
    FANOUT = "fanout"


class WorktreeState(str, Enum):
    """Per §10 `state` enum. Lifecycle: active -> merging -> merged | discarded -> gc_pending."""
    ACTIVE = "active"
    MERGING = "merging"
    MERGED = "merged"
    DISCARDED = "discarded"
    GC_PENDING = "gc_pending"


# ----- Main model -----

# Constrained int alias for TCP port values (1-65535).
Port = Annotated[int, Field(ge=1, le=65535)]


class WorktreeRecord(BaseModel):
    """
    Tracks a git worktree and its lifecycle. Coordinates the conflict scanner.

    Authors: the worktree-manager (runtime component).
    Readers: workers (to know where they write), conflict scanner, orchestrator.
    Lifecycle: created on worker dispatch; active during work; sealed on
    merge or discard; garbage-collected after retention window.

    Mutability: this schema is NOT frozen. Per §10, head_commit is
    "Updated as commits land" and `state` transitions through the
    lifecycle values. Downstream readers see snapshots; the worktree-
    manager is the canonical writer that updates the record over its
    lifetime. The only invariant is `id` (immutable handle).
    """
    model_config = ConfigDict(extra="forbid")  # NOT frozen; see class docstring.

    id: str = Field(
        description="Worktree id, e.g. 'wt-mainline', 'wt-fanout-c3'.",
        min_length=1,
    )
    created_at: str = Field(
        description="ISO-8601 UTC timestamp of worktree record creation.",
    )

    mission_id: str = Field(
        description="ref<Mission> -- the mission this worktree serves.",
    )
    kind: WorktreeKind = Field(
        description="Mainline (shared serial) or fanout (per-worker).",
    )
    branch: str = Field(
        description="Git branch backing the worktree.",
        min_length=1,
    )
    path: str = Field(
        description="Filesystem path inside the sandbox (or the local equivalent).",
        min_length=1,
    )
    current_worker: Optional[str] = Field(
        default=None,
        description=(
            "Worker currently using this worktree. Required iff "
            "kind == FANOUT AND state == ACTIVE (per §10). Cleared when the "
            "worker hands off or the worktree transitions out of ACTIVE."
        ),
    )
    base_commit: str = Field(
        description="The commit this worktree was created from (git SHA hex).",
        pattern=r"^[A-Fa-f0-9]{7,40}$",
    )
    head_commit: str = Field(
        description="Latest commit SHA on the worktree's branch. Updated as commits land.",
        pattern=r"^[A-Fa-f0-9]{7,40}$",
    )
    port_assignments: Optional[dict[str, Port]] = Field(
        default=None,
        description=(
            "Optional service-name -> TCP-port map (e.g. {'web': 4101, 'db': 5433}). "
            "None when the worker needs no local network services."
        ),
    )
    state: WorktreeState = Field(
        description="Current lifecycle state.",
    )
    conflict_set: list[str] = Field(
        default_factory=list,
        description=(
            "Worktree ids currently in conflict per the scanner. Empty list "
            "is the operationally common case (scanned, no conflicts) and the "
            "default; populated only when the conflict scanner finds overlap."
        ),
    )

    @model_validator(mode="after")
    def _validate_current_worker_conditional(self) -> "WorktreeRecord":
        """§10: current_worker required iff kind == FANOUT AND state == ACTIVE."""
        is_active_fanout = (
            self.kind == WorktreeKind.FANOUT
            and self.state == WorktreeState.ACTIVE
        )
        if is_active_fanout and not self.current_worker:
            raise ValueError(
                "WorktreeRecord.current_worker is required when kind == 'fanout' "
                "AND state == 'active' (§10)."
            )
        return self


# ============================================================================
# Task Brief -- ADR-007 (worker task-instruction channel)
# ============================================================================
#
# Per-dispatch task brief: the third worker-input surface (alongside role
# per ADR-023 and reporting per the handoff protocol). The framework
# constructs this artifact deterministically from WorkerDispatch metadata
# + the versioned spec + assertion files, writes it under
# `.mission/dispatches/<dispatch_id>/task-brief.md`, and instructs the
# worker (via the existing `--append-system-prompt` channel) to read it.
#
# Schema enforcement is at WRITE time (cross-cutting note 2 + ADR-007
# decision 4: "the committed artifact is schema-validated at write time").
# The Pydantic model is the source of truth; the rendered markdown is a
# presentation surface produced by the brief-generator (forthcoming
# module), not the parse target. Operator-supplied content is bounded to
# `operator_note` (ADR-007 decision 5).


class TaskBrief(BaseModel):
    """
    Per-dispatch task brief (ADR-007). The committed input-of-record that
    answers "produce THIS artifact, for THIS feature, against THESE
    assertions" -- the channel the framework previously lacked.

    Authors: the runner (framework, automatically); operator only via the
    bounded `operator_note` addendum.
    Readers: the dispatched worker (instructed to read it via the
    `--append-system-prompt` pointer); orchestrator/operator (for audit);
    eval pipeline (correlated via `brief_version` on LLMCallTrace).
    Lifecycle: constructed pre-spawn by the runner; written to
    `.mission/dispatches/<dispatch_id>/task-brief.md` (committed artifact
    per ADR-007 decision 4); immutable thereafter. Pre-spawn the runner
    verifies the file exists and is non-empty (extends `_validate_pre_spawn`).

    Cross-cutting framework convention (per WorkerDispatch / Handoff):
    `id` / `created_at` / `created_by` modeled here (same shape as
    WorkerDispatch). Note that the dispatch_id-keyed artifact path
    (`.mission/dispatches/<dispatch_id>/task-brief.md`) is the operational
    identity; the `id` field is the schema identity per the cross-cutting
    convention.

    Serialization: the brief-generator (forthcoming) produces the rendered
    markdown text from a `TaskBrief` instance after Pydantic validates the
    fields. The rendered markdown is what the worker reads; the JSON dump
    of this model is for trace embedding and inspection.
    """
    model_config = ConfigDict(extra="forbid", frozen=True)

    # Three cross-cutting framework-required fields (per WorkerDispatch/Handoff).
    id: UUID = Field(
        description=(
            "Stable task-brief id. The wire form in logs is prefixed "
            "(`brief-...`); this field is the underlying uuid."
        ),
    )
    created_at: str = Field(
        description="ISO-8601 UTC timestamp of brief construction.",
    )
    created_by: str = Field(
        description="Agent id of the brief constructor (e.g. 'claude-code:worker-runner').",
    )

    dispatch_id: str = Field(
        description=(
            "ref<Dispatch> -- the dispatch this brief belongs to. The "
            "operational identity (the brief lives at "
            "`.mission/dispatches/<dispatch_id>/task-brief.md`)."
        ),
    )
    feature_id: str = Field(
        description="Feature the worker is implementing (e.g. 'F-001').",
        pattern=r"^F-\d{3,}$",
    )
    spec_version: PositiveInt = Field(
        description=(
            "Spec version pinned by the dispatch. The brief indexes "
            "`.mission/spec/v{spec_version:03d}.yaml` for the worker to read; "
            "the brief does not inline the spec (ADR-007 decision 2)."
        ),
    )
    assertion_targets: list[str] = Field(
        description=(
            "Assertion ids the worker is to make pass (drawn from the "
            "dispatch). The brief indexes "
            "`.mission/contract/assertions/<A-NNN>.yaml` for each; the "
            "brief does not inline assertion text (ADR-007 decision 2)."
        ),
        min_length=1,
    )
    objective: str = Field(
        description=(
            "The brief's task statement -- the sentence the framework "
            "previously failed to construct. Derived deterministically "
            "from feature_id + assertion_targets (ADR-007 decision 2). "
            "Required and non-empty."
        ),
        min_length=1,
    )
    skills: Optional[list[str]] = Field(
        default=None,
        description=(
            "Optional skill ids the worker should consult per ADR-023. "
            "Hand-specified by the dispatching operator in v1; "
            "auto-selection is deferred (ADR-007 decision 3). None means "
            "the operator named no skills for this dispatch."
        ),
    )
    operator_note: Optional[str] = Field(
        default=None,
        description=(
            "Optional bounded addendum per ADR-007 decision 5. Threaded "
            "from `mission-dispatch.ps1 -OperatorNote`. The generator "
            "renders it under a labeled `## Operator note (out-of-contract)` "
            "section; additive to, never replacing, the artifact-derived "
            "objective. Recorded here so the audit trail is complete even "
            "where reproducibility-from-contract does not apply."
        ),
    )
    brief_version: str = Field(
        description=(
            "Versioned brief-generator-template id (ADR-007 decision 6). "
            "Until the prompts/ registry initializes (post-MVP per ADR-012/017), "
            "this is the inlined template's version string (mirrors the "
            "`_HANDOFF_INSTRUCTION_TEMPLATE` debt). Required and non-empty -- "
            "the field exists so the eval loop can correlate brief-template "
            "iterations with handoff outcomes."
        ),
        min_length=1,
    )

