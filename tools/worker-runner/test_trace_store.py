"""
Round-trip + CHECK-constraint tests for trace_store.TraceStore.

Operator-named test plan (step 2 implementation guardrails):
  1. Round-trip: insert one of each TraceEventType subclass, read back
     via mission_events(), assert Pydantic round-trip equivalence.
     Validates discriminator dispatch works through SQLite.
  2. CHECK constraint: attempt raw-SQL inserts that violate it;
     assert the constraint fires.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path
from uuid import uuid4

import pytest

from schemas import (
    AgentRole,
    CheckpointTrace,
    EscalationTrace,
    GatewayDecision,
    LLMCallTrace,
    StateTransitionTrace,
    ToolCallTrace,
    TraceStatus,
)
from trace_store import TraceStore

MISSION_ID = "mission-test-001"


def _make_one_of_each() -> list:
    """One event of each TraceEventType subclass."""
    return [
        LLMCallTrace(
            id=uuid4(),
            mission_id=MISSION_ID,
            agent_id="w-1",
            agent_role=AgentRole.WORKER,
            started_at="2026-05-29T18:00:00Z",
            duration_ms=100,
            status=TraceStatus.SUCCESS,
            model="claude-opus-4-7",
            prompt_version="worker-coding-v17",
            tokens_in=10,
            tokens_out=20,
            cost_usd=0.001,
            input={"system": "hi"},
            output={"content": "hello"},
        ),
        ToolCallTrace(
            id=uuid4(),
            mission_id=MISSION_ID,
            agent_id="w-1",
            agent_role=AgentRole.WORKER,
            started_at="2026-05-29T18:01:00Z",
            duration_ms=50,
            status=TraceStatus.SUCCESS,
            tool_name="Read",
            capability_tag="repo.read",
            input={"file_path": "/x"},
            output={"content": "..."},
            gateway_decision=GatewayDecision.ALLOWED,
        ),
        StateTransitionTrace(
            id=uuid4(),
            mission_id=MISSION_ID,
            agent_id="orch",
            agent_role=AgentRole.ORCHESTRATOR,
            started_at="2026-05-29T18:02:00Z",
            duration_ms=1,
            status=TraceStatus.SUCCESS,
            from_state="dispatched",
            to_state="in_progress",
            trigger="worker.start",
        ),
        CheckpointTrace(
            id=uuid4(),
            mission_id=MISSION_ID,
            agent_id="orch",
            agent_role=AgentRole.ORCHESTRATOR,
            started_at="2026-05-29T18:03:00Z",
            duration_ms=1,
            status=TraceStatus.SUCCESS,
        ),
        EscalationTrace(
            id=uuid4(),
            mission_id=MISSION_ID,
            agent_id="w-1",
            agent_role=AgentRole.WORKER,
            started_at="2026-05-29T18:04:00Z",
            duration_ms=10,
            status=TraceStatus.ERROR,
            error="needs human review",
        ),
    ]


def test_round_trip_discriminator_dispatch(tmp_path: Path) -> None:
    """Insert one of each TraceEventType; read back via mission_events;
    assert each comes back as the right subclass with equivalent fields."""
    db = tmp_path / "traces.sqlite"
    events = _make_one_of_each()

    with TraceStore(db) as store:
        for e in events:
            store.insert(e)
        got = list(store.mission_events(MISSION_ID))

    assert len(got) == len(events)
    by_id = {str(e.id): e for e in events}
    for g in got:
        original = by_id[str(g.id)]
        assert type(g) is type(original), (
            f"discriminator dispatch failed: id={g.id}, "
            f"original={type(original).__name__}, got={type(g).__name__}"
        )
        assert g.model_dump() == original.model_dump(), (
            f"round-trip field mismatch on {g.id}"
        )


def test_count_matches_inserted(tmp_path: Path) -> None:
    """count() returns the number of inserted events for the mission."""
    db = tmp_path / "traces.sqlite"
    events = _make_one_of_each()
    with TraceStore(db) as store:
        for e in events:
            store.insert(e)
        assert store.count(MISSION_ID) == len(events)
        assert store.count("nonexistent-mission") == 0


def test_check_constraint_blocks_success_with_error(tmp_path: Path) -> None:
    """Raw-SQL INSERT with status='success' but non-null error must fail.
    Uses a parallel connection to simulate true API bypass, not private-attribute access."""
    db = tmp_path / "traces.sqlite"
    with TraceStore(db):
        pass  # initialize DDL, then close

    bypass_conn = sqlite3.connect(str(db))
    try:
        with pytest.raises(sqlite3.IntegrityError):
            bypass_conn.execute(
                """
                INSERT INTO trace_events
                    (id, mission_id, agent_id, agent_role, type, started_at,
                     duration_ms, status, error, payload)
                VALUES ('bypass-1', ?, 'w-1', 'worker', 'checkpoint',
                        '2026-05-29T18:00:00Z', 1, 'success',
                        'should not have error', '{}')
                """,
                (MISSION_ID,),
            )
    finally:
        bypass_conn.close()


def test_check_constraint_blocks_error_without_error_text(tmp_path: Path) -> None:
    """Raw-SQL INSERT with status='error' but NULL error must fail.
    Uses a parallel connection to simulate true API bypass, not private-attribute access."""
    db = tmp_path / "traces.sqlite"
    with TraceStore(db):
        pass

    bypass_conn = sqlite3.connect(str(db))
    try:
        with pytest.raises(sqlite3.IntegrityError):
            bypass_conn.execute(
                """
                INSERT INTO trace_events
                    (id, mission_id, agent_id, agent_role, type, started_at,
                     duration_ms, status, error, payload)
                VALUES ('bypass-2', ?, 'w-1', 'worker', 'checkpoint',
                        '2026-05-29T18:00:00Z', 1, 'error', NULL, '{}')
                """,
                (MISSION_ID,),
            )
    finally:
        bypass_conn.close()


def test_errors_in_returns_only_non_success(tmp_path: Path) -> None:
    """errors_in() returns only events with status != success (uses partial idx_te_errors)."""
    db = tmp_path / "traces.sqlite"
    events = _make_one_of_each()  # 4 success + 1 error (escalation)
    with TraceStore(db) as store:
        for e in events:
            store.insert(e)
        errors = list(store.errors_in(MISSION_ID))
    assert len(errors) == 1
    assert errors[0].status == TraceStatus.ERROR


def test_llm_calls_by_prompt_version(tmp_path: Path) -> None:
    """Prompt-version index path returns only matching LLM calls."""
    db = tmp_path / "traces.sqlite"
    events = _make_one_of_each()
    with TraceStore(db) as store:
        for e in events:
            store.insert(e)
        hits = list(store.llm_calls_by_prompt_version("worker-coding-v17"))
        misses = list(store.llm_calls_by_prompt_version("nonexistent-prompt"))
    assert len(hits) == 1
    assert hits[0].prompt_version == "worker-coding-v17"
    assert misses == []


def test_redactor_applied_to_payload(tmp_path: Path) -> None:
    """Caller-supplied redactor mutates the payload before INSERT (base fields untouched)."""
    db = tmp_path / "traces.sqlite"

    def scrub_outputs(payload: dict) -> dict:
        if "output" in payload:
            payload = dict(payload)
            payload["output"] = {"redacted": True}
        return payload

    event = LLMCallTrace(
        id=uuid4(),
        mission_id=MISSION_ID,
        agent_id="w-1",
        agent_role=AgentRole.WORKER,
        started_at="2026-05-29T18:00:00Z",
        duration_ms=100,
        status=TraceStatus.SUCCESS,
        model="claude-opus-4-7",
        prompt_version="worker-coding-v17",
        tokens_in=10,
        tokens_out=20,
        cost_usd=0.001,
        input={"system": "hi"},
        output={"content": "sensitive-text"},
    )

    with TraceStore(db, redactor=scrub_outputs) as store:
        store.insert(event)
        got = store.get(str(event.id))

    assert isinstance(got, LLMCallTrace)
    assert got.output == {"redacted": True}
    assert got.input == {"system": "hi"}  # untouched
    assert got.mission_id == MISSION_ID  # base field untouched
