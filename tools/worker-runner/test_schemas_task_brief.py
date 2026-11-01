"""
Tests for the TaskBrief Pydantic model (ADR-007 decision 4) and the
brief_version field added to LLMCallTrace (ADR-007 decision 6).

The TaskBrief is the schema-validated representation of the per-dispatch
task surface. Write-time enforcement is REQUIRED by ADR-007 decision 4
("the committed artifact is schema-validated at write time") -- so these
tests focus on rejection at construction time, not deferred catches.
"""

from __future__ import annotations

from uuid import UUID, uuid4

import pytest
from pydantic import ValidationError

from schemas import (
    AgentRole,
    LLMCallTrace,
    TaskBrief,
    TraceEventType,
    TraceStatus,
)


def _base_brief_kwargs() -> dict:
    """A valid TaskBrief kwargs dict; tests override one field to probe rejection."""
    return dict(
        id=uuid4(),
        created_at="2026-05-31T18:00:00.000Z",
        created_by="claude-code:worker-runner",
        dispatch_id="dispatch-test",
        feature_id="F-001",
        spec_version=10,
        assertion_targets=["A-001", "A-002"],
        objective="Implement F-001 such that A-001, A-002 pass.",
        brief_version="inlined:_TASK_BRIEF_TEMPLATE:v1",
    )


# ---------- Happy-path construction ----------


def test_valid_construction() -> None:
    b = TaskBrief(**_base_brief_kwargs())
    assert b.feature_id == "F-001"
    assert b.assertion_targets == ["A-001", "A-002"]
    assert b.brief_version == "inlined:_TASK_BRIEF_TEMPLATE:v1"
    assert b.skills is None
    assert b.operator_note is None


def test_optional_fields_default_None() -> None:
    """skills and operator_note default None; no incidental value leaks in."""
    b = TaskBrief(**_base_brief_kwargs())
    assert b.skills is None
    assert b.operator_note is None


def test_skills_and_operator_note_round_trip() -> None:
    kwargs = _base_brief_kwargs()
    kwargs["skills"] = ["skill-schema-authoring"]
    kwargs["operator_note"] = "Focus on the example_field field shape."
    b = TaskBrief(**kwargs)
    assert b.skills == ["skill-schema-authoring"]
    assert "example_field" in b.operator_note


# ---------- Write-time rejection (ADR-007 decision 4) ----------


def test_rejects_bad_feature_id_pattern() -> None:
    kwargs = _base_brief_kwargs()
    kwargs["feature_id"] = "X-001"
    with pytest.raises(ValidationError, match="feature_id"):
        TaskBrief(**kwargs)


def test_rejects_short_feature_id() -> None:
    """Pattern ^F-\\d{3,}$ enforces minimum 3 digits."""
    kwargs = _base_brief_kwargs()
    kwargs["feature_id"] = "F-1"
    with pytest.raises(ValidationError):
        TaskBrief(**kwargs)


def test_rejects_empty_assertion_targets() -> None:
    kwargs = _base_brief_kwargs()
    kwargs["assertion_targets"] = []
    with pytest.raises(ValidationError, match="assertion_targets"):
        TaskBrief(**kwargs)


def test_rejects_empty_objective() -> None:
    kwargs = _base_brief_kwargs()
    kwargs["objective"] = ""
    with pytest.raises(ValidationError, match="objective"):
        TaskBrief(**kwargs)


def test_rejects_empty_brief_version() -> None:
    """brief_version is required and non-empty -- the eval loop relies on it."""
    kwargs = _base_brief_kwargs()
    kwargs["brief_version"] = ""
    with pytest.raises(ValidationError, match="brief_version"):
        TaskBrief(**kwargs)


def test_rejects_non_positive_spec_version() -> None:
    kwargs = _base_brief_kwargs()
    kwargs["spec_version"] = 0
    with pytest.raises(ValidationError, match="spec_version"):
        TaskBrief(**kwargs)


def test_rejects_extra_field() -> None:
    """extra='forbid': unknown keys are a write-time error so typos surface."""
    kwargs = _base_brief_kwargs()
    kwargs["bogus_field"] = "should-be-rejected"
    with pytest.raises(ValidationError, match="bogus_field"):
        TaskBrief(**kwargs)


def test_rejects_missing_required_field() -> None:
    """Missing brief_version trips Pydantic's required-field check."""
    kwargs = _base_brief_kwargs()
    del kwargs["brief_version"]
    with pytest.raises(ValidationError, match="brief_version"):
        TaskBrief(**kwargs)


def test_frozen_immutable() -> None:
    """frozen=True: post-construction mutation is a write-time error.
    The committed artifact must not drift from its validated form."""
    b = TaskBrief(**_base_brief_kwargs())
    with pytest.raises(ValidationError):
        b.objective = "tampered"  # type: ignore[misc]


# ---------- LLMCallTrace.brief_version (ADR-007 decision 6) ----------


def _llm_trace_kwargs(**overrides) -> dict:
    base = dict(
        id=uuid4(),
        parent_id=None,
        mission_id="mission-test",
        agent_id="worker-test",
        agent_role=AgentRole.WORKER,
        started_at="2026-05-31T18:00:00.000Z",
        duration_ms=10,
        status=TraceStatus.SUCCESS,
        error=None,
        model="claude-opus-4-7",
        prompt_version="inlined:_HANDOFF_INSTRUCTION_TEMPLATE",
        tokens_in=1,
        tokens_out=1,
        cost_usd=0.001,
        input={},
        output={},
    )
    base.update(overrides)
    return base


def test_llm_call_trace_brief_version_optional_default_None() -> None:
    """brief_version is optional -- not every LLM call is a worker dispatch."""
    t = LLMCallTrace(**_llm_trace_kwargs())
    assert t.brief_version is None
    assert t.type == TraceEventType.LLM_CALL


def test_llm_call_trace_brief_version_round_trip() -> None:
    t = LLMCallTrace(
        **_llm_trace_kwargs(brief_version="inlined:_TASK_BRIEF_TEMPLATE:v1")
    )
    assert t.brief_version == "inlined:_TASK_BRIEF_TEMPLATE:v1"


def test_llm_call_trace_prompt_version_and_brief_version_independent() -> None:
    """prompt_version (role surface) and brief_version (task surface) are
    distinct fields -- ADR-007's whole point. Verify they don't alias."""
    t = LLMCallTrace(
        **_llm_trace_kwargs(
            prompt_version="role-prompt-v3",
            brief_version="brief-template-v7",
        )
    )
    assert t.prompt_version == "role-prompt-v3"
    assert t.brief_version == "brief-template-v7"
    assert t.prompt_version != t.brief_version
