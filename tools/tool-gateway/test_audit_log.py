"""
Tests for audit_log.AuditLog.

Four tests targeting the four call outcomes + the contract boundary:
  1. ALLOWED + tool succeeded -> ToolCallTrace stored with gateway_decision=allowed,
     status=success, capability_tag from the verdict.
  2. DENIED -> ToolCallTrace stored with gateway_decision=denied, status=error
     embedding the verdict's reason.
  3. ALLOWED + tool execution failed -> caller-supplied error preserved in the
     trace (status=error from caller, not from verdict).
  4. Inconsistent caller input (status=SUCCESS + non-null error, or
     status=ERROR + null error) -> Pydantic ValidationError. Documents the
     §9 contract at the audit_log seam where misuse would occur; a future
     refactor that relaxes the boundary fails this test.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from schemas import (
    AgentRole,
    GatewayDecision,
    ToolCallTrace,
    TraceStatus,
)
from trace_store import TraceStore

from audit_log import AuditLog
from policy import Verdict

MISSION_ID = "mission-audit-001"
AGENT_ID = "w-audit-1"
STARTED_AT = "2026-05-29T18:45:00Z"


def test_log_allowed_call_round_trip(tmp_path: Path) -> None:
    """Allowed verdict + successful tool exec; round-trip via mission_events."""
    db = tmp_path / "traces.sqlite"
    verdict = Verdict(
        decision=GatewayDecision.ALLOWED,
        capability_tag="repo.read",
        reason=None,
    )
    with TraceStore(db) as store:
        audit = AuditLog(store)
        audit.log_call(
            verdict,
            mission_id=MISSION_ID,
            agent_id=AGENT_ID,
            agent_role=AgentRole.WORKER,
            started_at=STARTED_AT,
            duration_ms=12,
            tool_name="Read",
            input={"file_path": "/x"},
            output={"content": "..."},
            status=TraceStatus.SUCCESS,
        )
        got = list(store.mission_events(MISSION_ID))

    assert len(got) == 1
    evt = got[0]
    assert isinstance(evt, ToolCallTrace)
    assert evt.gateway_decision == GatewayDecision.ALLOWED
    assert evt.capability_tag == "repo.read"
    assert evt.tool_name == "Read"
    assert evt.status == TraceStatus.SUCCESS
    assert evt.error is None


def test_log_denied_call(tmp_path: Path) -> None:
    """Denied verdict; caller supplies status=ERROR + error embedding the reason."""
    db = tmp_path / "traces.sqlite"
    verdict = Verdict(
        decision=GatewayDecision.DENIED,
        capability_tag="shell.exec.sandboxed",
        reason="Tool 'Bash' requires one of [...]; worker tool_scope is ['repo.read'].",
    )
    with TraceStore(db) as store:
        audit = AuditLog(store)
        audit.log_call(
            verdict,
            mission_id=MISSION_ID,
            agent_id=AGENT_ID,
            agent_role=AgentRole.WORKER,
            started_at=STARTED_AT,
            duration_ms=1,
            tool_name="Bash",
            input={"command": "echo x"},
            output={},
            status=TraceStatus.ERROR,
            error=f"gateway_denied: {verdict.reason}",
        )
        got = list(store.errors_in(MISSION_ID))

    assert len(got) == 1
    evt = got[0]
    assert isinstance(evt, ToolCallTrace)
    assert evt.gateway_decision == GatewayDecision.DENIED
    assert evt.capability_tag == "shell.exec.sandboxed"
    assert evt.status == TraceStatus.ERROR
    assert evt.error is not None
    assert "gateway_denied" in evt.error
    assert "Bash" in evt.error  # verdict.reason content preserved


def test_log_allowed_call_tool_execution_failure(tmp_path: Path) -> None:
    """Allowed verdict but tool execution failed; caller-supplied error
    is preserved (gateway succeeded; the underlying tool didn't)."""
    db = tmp_path / "traces.sqlite"
    verdict = Verdict(
        decision=GatewayDecision.ALLOWED,
        capability_tag="repo.read",
        reason=None,
    )
    with TraceStore(db) as store:
        audit = AuditLog(store)
        audit.log_call(
            verdict,
            mission_id=MISSION_ID,
            agent_id=AGENT_ID,
            agent_role=AgentRole.WORKER,
            started_at=STARTED_AT,
            duration_ms=5,
            tool_name="Read",
            input={"file_path": "/nonexistent"},
            output={},
            status=TraceStatus.ERROR,
            error="FileNotFoundError: /nonexistent",
        )
        denied = list(store.denied_tool_attempts(MISSION_ID))
        errors = list(store.errors_in(MISSION_ID))

    # Denied-attempt mining must NOT surface this (it was allowed):
    assert denied == []
    # But errors_in must include it:
    assert len(errors) == 1
    evt = errors[0]
    assert evt.gateway_decision == GatewayDecision.ALLOWED
    assert evt.status == TraceStatus.ERROR
    assert evt.error == "FileNotFoundError: /nonexistent"


def test_pydantic_catches_inconsistent_status_and_error(tmp_path: Path) -> None:
    """Document the §9 status/error consistency contract at the audit_log
    seam itself. A future refactor of log_call() that relaxes the boundary
    (e.g., silently coercing status, swallowing inconsistent error) fails
    this test before any production write happens.

    Both directions of the bidirectional invariant are checked:
    - status=SUCCESS with non-null error -> ValidationError
    - status=ERROR with null error       -> ValidationError
    """
    db = tmp_path / "traces.sqlite"
    verdict = Verdict(
        decision=GatewayDecision.ALLOWED,
        capability_tag="repo.read",
        reason=None,
    )
    common_kwargs = dict(
        mission_id=MISSION_ID,
        agent_id=AGENT_ID,
        agent_role=AgentRole.WORKER,
        started_at=STARTED_AT,
        duration_ms=10,
        tool_name="Read",
        input={"file_path": "/x"},
        output={"content": "ok"},
    )
    with TraceStore(db) as store:
        audit = AuditLog(store)
        with pytest.raises(ValidationError):
            audit.log_call(
                verdict,
                status=TraceStatus.SUCCESS,
                error="should-not-be-here",
                **common_kwargs,
            )
        with pytest.raises(ValidationError):
            audit.log_call(
                verdict,
                status=TraceStatus.ERROR,
                error=None,
                **common_kwargs,
            )
