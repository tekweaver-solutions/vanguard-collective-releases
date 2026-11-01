"""
audit_log.py -- bridge between the gateway's Verdict and the trace store.

Per the step-4 design (operator-approved 2026-05-29):
- AuditLog takes a TraceStore at construction (direct DI per the design review).
- log_call() takes a Verdict + tool-call meta + tool-result meta;
  builds a ToolCallTrace; inserts via store.insert(). Synchronous
  write path (no batching, no queue) -- volume estimate is tens to
  hundreds of tool calls per dispatch, sub-millisecond inserts.
- Both ALLOWED and DENIED calls are logged. Denied-attempt mining is
  one of the key eval-loop queries (per cross-cutting note 4 +
  ToolCallTrace.capability_tag's sharpened description).
- Caller is responsible for status/error semantics:
    DENIED   -> typically status=ERROR + error=f'gateway_denied: {reason}'
    ALLOWED + tool succeeded -> status=SUCCESS + error=None
    ALLOWED + tool failed    -> status=ERROR + error=<tool error>
  The Pydantic schema's _validate_error_consistency on TraceEventBase
  catches inconsistent caller input at write time.
"""

from __future__ import annotations

from typing import Optional
from uuid import UUID, uuid4

# `worker-runner` is on sys.path via tools/conftest.py.
from schemas import AgentRole, ToolCallTrace, TraceStatus
from trace_store import TraceStore

from policy import Verdict


class AuditLog:
    """Records gateway decisions + tool-call outcomes as ToolCallTrace
    events in the trace store. Stateless beyond the store reference."""

    def __init__(self, store: TraceStore) -> None:
        self._store = store

    def log_call(
        self,
        verdict: Verdict,
        *,
        mission_id: str,
        agent_id: str,
        agent_role: AgentRole,
        started_at: str,
        duration_ms: int,
        tool_name: str,
        input: dict,
        output: dict,
        status: TraceStatus,
        parent_id: Optional[UUID] = None,
        error: Optional[str] = None,
    ) -> None:
        """Build a ToolCallTrace from verdict + meta; insert via the store.

        verdict.decision becomes ToolCallTrace.gateway_decision.
        verdict.capability_tag becomes ToolCallTrace.capability_tag
        (per §9 + the sharpened description: ALLOWED records the tag
        that authorized; DENIED records the tag the runner requested).
        Other fields are caller-provided; the runner has the context.
        """
        trace = ToolCallTrace(
            id=uuid4(),
            parent_id=parent_id,
            mission_id=mission_id,
            agent_id=agent_id,
            agent_role=agent_role,
            started_at=started_at,
            duration_ms=duration_ms,
            status=status,
            error=error,
            tool_name=tool_name,
            capability_tag=verdict.capability_tag,
            input=input,
            output=output,
            gateway_decision=verdict.decision,
        )
        self._store.insert(trace)
