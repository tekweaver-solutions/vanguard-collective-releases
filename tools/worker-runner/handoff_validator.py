"""
handoff_validator.py -- cross-artifact §5 validation of a worker Handoff
against its originating WorkerDispatch.

The runner (runner.py) performs schema-level Handoff validation via
`Handoff.model_validate_json`. Schema enforcement catches every §5
constraint EXCEPT **cross-artifact constraint 2**: "Every
completed_assertions entry must be in the dispatch's assertion_targets."
That constraint requires both Handoff AND WorkerDispatch in scope
simultaneously; this module is the place where they meet.

**Integration boundary** (per step-6 design 2026-05-30, operator option (i)
external validator): runner.py stays subprocess-focused; this module is
its sibling. The orchestration call site is `mission-dispatch.ps1` (step 8):

    dispatch -> runner.run() -> handoff_validator -> promote-or-rework

The validator does NOT live inside runner.run(); cross-artifact failures
do not raise from the runner. The runner produces a schema-valid Handoff;
this module produces a structured ValidationReport that the orchestration
script enumerates to decide rework / acceptance / escalation.

**permission_denials surface via option 4** (per step-6 design, the new
fourth option vs the three originally named): denials are
NOT carried in the Handoff itself; the ValidationReport derives the
summary from the trace store's `gateway_decision=DENIED` ToolCallTraces
filtered by `agent_id == dispatch.worker_id`. This matches the c-γ
result-metadata pattern: derive summary metadata from
the trace store, do not duplicate in the Handoff. The Handoff stays
unmodified; a future amendment can add a `permission_denials` field
to §5 if a concrete need surfaces — until then, the trace store IS the
canonical record and the validator surfaces it via the report.

**Strict unfinished[i].assertion_id check** (per step-6 design review's
clarification): §5 does not explicitly enforce that unfinished items'
assertion_id values are drawn from dispatch.assertion_targets, but it
follows from the dispatch's scope being the contract. **The rule is
"the assertion this worker was supposed to make pass and couldn't"
(scope-bounded), NOT "the assertion that blocked progress" (unbounded;
could reference any assertion in the system).** Blockers may reference
out-of-scope assertions in the human-readable `reason` text, but the
`assertion_id` field is bounded to the dispatched scope. This validator
enforces the rule as a hard error; future maintainers should preserve
the semantic above.

**Report-based, not exception-based**: orchestration callers need to
enumerate failures and counts to decide rework semantics. Exceptions
collapse the structured information into a stack trace.

**`store: Optional[TraceStore] = None`**: production orchestration always
provides a store; schema-only consumers (CI checks, eval-loop offline
analysis) may omit. When store is None, `denial_count=0` and
`denied_capabilities=()` regardless of actual runtime denials -- the
caller assumes responsibility for not interpreting the zero as evidence
of no denials.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from schemas import GatewayDecision, Handoff, ToolCallTrace, WorkerDispatch
from trace_store import TraceStore


@dataclass(frozen=True)
class ValidationReport:
    """Result of validate_handoff_against_dispatch.

    Immutable per the framework convention (Verdict + frozen schemas).
    Orchestration callers (step-8 dispatch script) inspect `is_valid` and
    enumerate `cross_artifact_errors` to decide rework / acceptance /
    escalation. Denial summary fields are populated only when the validator
    was given a TraceStore.
    """

    is_valid: bool
    cross_artifact_errors: tuple[str, ...]
    denial_count: int = 0
    denied_capabilities: tuple[str, ...] = ()
    denied_tools: tuple[str, ...] = ()


def validate_handoff_against_dispatch(
    handoff: Handoff,
    dispatch: WorkerDispatch,
    *,
    store: Optional[TraceStore] = None,
) -> ValidationReport:
    """Validate the Handoff against §5 cross-artifact constraints + summarize
    denials from the trace store.

    Returns a ValidationReport. Does NOT raise on validation failure --
    enumeration of structured errors is the report's purpose.

    Constraint 2 (mandatory, §5 explicit): every
    `handoff.completed_assertions[i]` must be in `dispatch.assertion_targets`.

    Strict unfinished check (per step-6 design review): every
    `handoff.unfinished[i].assertion_id` must also be in
    `dispatch.assertion_targets`. The rule is scope-bounded: an unfinished
    item names the assertion this worker was supposed to make pass and
    couldn't, not the assertion that blocked progress.

    When `store` is provided, the report's `denial_count`,
    `denied_capabilities`, and `denied_tools` are populated by querying
    `gateway_decision=DENIED` ToolCallTraces filtered to this dispatch's
    `agent_id` (= `worker_id`).
    """
    allowed = set(dispatch.assertion_targets)
    errors: list[str] = []

    for aid in handoff.completed_assertions:
        if aid not in allowed:
            errors.append(
                f"completed_assertions entry {aid!r} is not in "
                f"dispatch.assertion_targets ({sorted(allowed)})"
            )

    for u in handoff.unfinished:
        if u.assertion_id not in allowed:
            errors.append(
                f"unfinished entry assertion_id {u.assertion_id!r} is not "
                f"in dispatch.assertion_targets ({sorted(allowed)})"
            )

    denial_count = 0
    denied_capabilities: tuple[str, ...] = ()
    denied_tools: tuple[str, ...] = ()
    if store is not None:
        caps: set[str] = set()
        tools: set[str] = set()
        for evt in store.denied_tool_attempts(dispatch.mission_id):
            # Filter to this dispatch via agent_id (= worker_id).
            if evt.agent_id != dispatch.worker_id:
                continue
            denial_count += 1
            caps.add(evt.capability_tag)
            tools.add(evt.tool_name)
        denied_capabilities = tuple(sorted(caps))
        denied_tools = tuple(sorted(tools))

    return ValidationReport(
        is_valid=not errors,
        cross_artifact_errors=tuple(errors),
        denial_count=denial_count,
        denied_capabilities=denied_capabilities,
        denied_tools=denied_tools,
    )
