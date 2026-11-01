"""
Tests for handoff_validator.validate_handoff_against_dispatch.

Coverage per the step-6 design (operator-approved 2026-05-30):

Cross-artifact §5.2 validation (constraint 2 explicit + strict-unfinished):
  - valid handoff with completed_assertions = assertion_targets
  - valid handoff with completed_assertions ⊂ assertion_targets
  - valid handoff with completed_assertions=[] (includes the
    operator-named edge case: minimum-1 assertion_targets per the schema
    means we can't construct assertion_targets=[]; we cover what IS
    constructible)
  - invalid: completed_assertions contains an out-of-scope id
  - invalid: multiple out-of-scope ids each named
  - invalid: unfinished[i].assertion_id out-of-scope (strict rule per a design-review answer)

Denial summary via trace store (option 4 from the step-6 design):
  - denial_count=0 with empty store
  - denial_count aggregates correctly with seeded DENIED events
  - denied_capabilities + denied_tools deduplicated and sorted (found in review)
  - validator without store skips denial summary
  - dispatch filter: events from a different worker_id are excluded

Integration:
  - runner._synthesize_handoff_for_failure() output passes cross-artifact
    validation (structural path).

ValidationReport immutability invariant.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

import pytest

from audit_log import AuditLog
from handoff_validator import ValidationReport, validate_handoff_against_dispatch
from mcp_capability_map import CapabilityMap
from policy import Gateway
from runner import WorkerRunner
from schemas import (
    AgentRole,
    GatewayDecision,
    Handoff,
    ModelClass,
    ProcedureAdherence,
    TerminatedReason,
    ToolCallTrace,
    TraceStatus,
    UnfinishedItem,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
)
from trace_store import TraceStore


# ---------- Helpers ----------


def _make_dispatch(
    *,
    assertion_targets: list[str] | None = None,
    worker_id: str | None = None,
    mission_id: str = "mission-test-step6",
) -> WorkerDispatch:
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-05-30T00:00:00Z",
        created_by="claude-code:test",
        mission_id=mission_id,
        worker_id=worker_id or str(uuid4()),
        kind=WorkerKind.MAINLINE,
        feature_id="F-001",
        assertion_targets=assertion_targets or ["A-001"],
        spec_version=10,
        worktree_id="wt-test",
        model_class=ModelClass.CODING_STRONG,
        tool_scope=["repo.read"],
        budget=WorkerBudget(cost_cap_usd=10.0, wallclock_cap_minutes=10),
    )


def _make_handoff(
    *,
    dispatch_id: str = "dispatch-test",
    completed_assertions: list[str] | None = None,
    unfinished: list[UnfinishedItem] | None = None,
    terminated_reason: TerminatedReason = TerminatedReason.COMPLETED,
) -> Handoff:
    return Handoff(
        id=uuid4(),
        created_at="2026-05-30T00:10:00Z",
        created_by="claude-code:worker",
        from_worker="w-test-001",
        dispatch_id=dispatch_id,
        feature_id="F-001",
        spec_version=10,
        completed_assertions=completed_assertions or [],
        unfinished=unfinished or [],
        commits=[],
        commands_run=[],
        issues_observed=[],
        procedure_adherence=ProcedureAdherence.CONFIRMED,
        terminated_reason=terminated_reason,
    )


def _seed_denied_trace(
    store: TraceStore,
    *,
    mission_id: str,
    agent_id: str,
    tool_name: str,
    capability_tag: str,
    started_at: str,
) -> None:
    store.insert(
        ToolCallTrace(
            id=uuid4(),
            parent_id=None,
            mission_id=mission_id,
            agent_id=agent_id,
            agent_role=AgentRole.WORKER,
            started_at=started_at,
            duration_ms=1,
            status=TraceStatus.ERROR,
            error="gateway_denied: synthetic",
            tool_name=tool_name,
            capability_tag=capability_tag,
            input={},
            output={},
            gateway_decision=GatewayDecision.DENIED,
        )
    )


# ---------- Cross-artifact validation ----------


def test_valid_handoff_with_matching_assertions() -> None:
    dispatch = _make_dispatch(assertion_targets=["A-001", "A-002"])
    handoff = _make_handoff(completed_assertions=["A-001", "A-002"])
    report = validate_handoff_against_dispatch(handoff, dispatch)
    assert report.is_valid
    assert report.cross_artifact_errors == ()


def test_valid_handoff_with_subset_of_assertion_targets() -> None:
    dispatch = _make_dispatch(assertion_targets=["A-001", "A-002", "A-003"])
    handoff = _make_handoff(completed_assertions=["A-001"])
    report = validate_handoff_against_dispatch(handoff, dispatch)
    assert report.is_valid


def test_valid_handoff_with_empty_completed_assertions() -> None:
    """Empty completed_assertions is vacuously valid -- no entries to check.
    (Operator-named edge case: assertion_targets=[] is not constructible
    because WorkerDispatch.assertion_targets has min_length=1.)"""
    dispatch = _make_dispatch(assertion_targets=["A-001"])
    handoff = _make_handoff(completed_assertions=[])
    report = validate_handoff_against_dispatch(handoff, dispatch)
    assert report.is_valid
    assert report.cross_artifact_errors == ()


def test_invalid_handoff_completed_assertion_not_in_targets() -> None:
    dispatch = _make_dispatch(assertion_targets=["A-001"])
    handoff = _make_handoff(completed_assertions=["A-001", "A-999"])
    report = validate_handoff_against_dispatch(handoff, dispatch)
    assert not report.is_valid
    assert len(report.cross_artifact_errors) == 1
    err = report.cross_artifact_errors[0]
    assert "A-999" in err
    assert "completed_assertions" in err


def test_invalid_handoff_multiple_out_of_scope_assertions() -> None:
    """Each out-of-scope assertion is reported with its own error string."""
    dispatch = _make_dispatch(assertion_targets=["A-001"])
    handoff = _make_handoff(completed_assertions=["A-002", "A-003"])
    report = validate_handoff_against_dispatch(handoff, dispatch)
    assert not report.is_valid
    assert len(report.cross_artifact_errors) == 2
    joined = " | ".join(report.cross_artifact_errors)
    assert "A-002" in joined
    assert "A-003" in joined


def test_invalid_handoff_unfinished_assertion_not_in_targets() -> None:
    """Strict unfinished check: assertion_id field on UnfinishedItem must
    be in dispatch.assertion_targets. The rule is 'the assertion this
    worker was supposed to make pass and couldn't,' scope-bounded."""
    dispatch = _make_dispatch(assertion_targets=["A-001"])
    handoff = _make_handoff(
        completed_assertions=[],
        unfinished=[
            UnfinishedItem(
                assertion_id="A-007",  # out-of-scope
                reason="blocked by upstream",
            ),
        ],
        # §5 constraint 1: non-empty unfinished can't pair with COMPLETED.
        terminated_reason=TerminatedReason.AMENDMENT_FILED,
    )
    report = validate_handoff_against_dispatch(handoff, dispatch)
    assert not report.is_valid
    err = report.cross_artifact_errors[0]
    assert "A-007" in err
    assert "unfinished" in err


# ---------- Denial summary ----------


def test_denial_count_zero_when_no_denied_tool_calls(tmp_path: Path) -> None:
    store = TraceStore(tmp_path / "traces.sqlite")
    dispatch = _make_dispatch()
    handoff = _make_handoff()
    report = validate_handoff_against_dispatch(handoff, dispatch, store=store)
    assert report.is_valid
    assert report.denial_count == 0
    assert report.denied_capabilities == ()
    assert report.denied_tools == ()


def test_denial_count_aggregates_correctly(tmp_path: Path) -> None:
    store = TraceStore(tmp_path / "traces.sqlite")
    dispatch = _make_dispatch(worker_id=str(uuid4()))
    for i, (tool, cap) in enumerate(
        [
            ("Bash", "shell.exec.sandboxed"),
            ("Bash", "shell.exec.sandboxed"),  # duplicate cap; same tool
            ("mcp__postman__runCollection", "postman"),
        ]
    ):
        _seed_denied_trace(
            store,
            mission_id=dispatch.mission_id,
            agent_id=dispatch.worker_id,
            tool_name=tool,
            capability_tag=cap,
            started_at=f"2026-05-30T01:0{i}:00Z",
        )
    report = validate_handoff_against_dispatch(
        _make_handoff(), dispatch, store=store
    )
    assert report.denial_count == 3


def test_denied_capabilities_and_tools_deduped_sorted(tmp_path: Path) -> None:
    """The report carries BOTH denied_capabilities and denied_tools, each
    flat tuples deduplicated and sorted. Two Bash denials yield one
    capability entry but two distinct entries get one each."""
    store = TraceStore(tmp_path / "traces.sqlite")
    dispatch = _make_dispatch(worker_id=str(uuid4()))
    _seed_denied_trace(
        store,
        mission_id=dispatch.mission_id,
        agent_id=dispatch.worker_id,
        tool_name="Bash",
        capability_tag="shell.exec.sandboxed",
        started_at="2026-05-30T01:00:00Z",
    )
    _seed_denied_trace(
        store,
        mission_id=dispatch.mission_id,
        agent_id=dispatch.worker_id,
        tool_name="Bash",
        capability_tag="shell.exec.sandboxed",
        started_at="2026-05-30T01:01:00Z",
    )
    _seed_denied_trace(
        store,
        mission_id=dispatch.mission_id,
        agent_id=dispatch.worker_id,
        tool_name="mcp__postman__runCollection",
        capability_tag="postman",
        started_at="2026-05-30T01:02:00Z",
    )
    report = validate_handoff_against_dispatch(
        _make_handoff(), dispatch, store=store
    )
    # Sorted alphabetically; each unique once.
    assert report.denied_capabilities == ("postman", "shell.exec.sandboxed")
    assert report.denied_tools == ("Bash", "mcp__postman__runCollection")


def test_validation_without_store_skips_denial_summary(tmp_path: Path) -> None:
    """store=None -> denial_count=0 + empty tuples, regardless of any
    runtime denials (the caller assumes responsibility for not interpreting
    zero as 'no denials')."""
    dispatch = _make_dispatch()
    handoff = _make_handoff()
    report = validate_handoff_against_dispatch(handoff, dispatch, store=None)
    assert report.denial_count == 0
    assert report.denied_capabilities == ()
    assert report.denied_tools == ()


def test_denial_summary_filters_by_dispatch_worker_id(tmp_path: Path) -> None:
    """Multiple dispatches share mission_id; the validator filters denials
    to this dispatch's worker_id (= agent_id on the trace events)."""
    store = TraceStore(tmp_path / "traces.sqlite")
    this_dispatch = _make_dispatch(worker_id="w-A")
    # Seed a denial from a different worker on the same mission.
    _seed_denied_trace(
        store,
        mission_id=this_dispatch.mission_id,
        agent_id="w-OTHER",
        tool_name="Read",
        capability_tag="repo.read",
        started_at="2026-05-30T02:00:00Z",
    )
    # Plus one from this worker.
    _seed_denied_trace(
        store,
        mission_id=this_dispatch.mission_id,
        agent_id="w-A",
        tool_name="Bash",
        capability_tag="shell.exec.sandboxed",
        started_at="2026-05-30T02:01:00Z",
    )
    report = validate_handoff_against_dispatch(
        _make_handoff(), this_dispatch, store=store
    )
    assert report.denial_count == 1
    assert report.denied_tools == ("Bash",)


# ---------- Integration ----------


def test_synthesized_handoff_from_runner_passes_cross_artifact(tmp_path: Path) -> None:
    """Checks structurally: WorkerRunner._synthesize_handoff_for_failure
    output is consumed by validate_handoff_against_dispatch and reports valid.

    Synthesized Handoff has completed_assertions=[] (always vacuously valid)
    + unfinished entries with assertion_id drawn from dispatch.assertion_targets
    (per runner.py's synthesis logic), so cross-artifact validation passes."""
    dispatch = _make_dispatch(assertion_targets=["A-001", "A-002"])
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()

    store = TraceStore(tmp_path / "traces.sqlite")
    gateway = Gateway(CapabilityMap.default())
    audit = AuditLog(store)
    runner = WorkerRunner(
        dispatch,
        store=store,
        gateway=gateway,
        audit=audit,
        worktree_path=worktree,
        worktree_base_commit="abc1234",
        project_root=project_root,
    )
    # Trigger synthesized path.
    runner._subprocess_exit_code = 1
    synth = runner._synthesize_handoff_for_failure()

    report = validate_handoff_against_dispatch(synth, dispatch, store=store)
    assert report.is_valid
    assert report.cross_artifact_errors == ()
    # Synthesized handoff has unfinished items for every assertion_target;
    # all should validate.
    assert len(synth.unfinished) == 2


# ---------- ValidationReport invariants ----------


def test_validation_report_is_frozen() -> None:
    """ValidationReport is immutable (matches Verdict + frozen schemas convention)."""
    from dataclasses import FrozenInstanceError

    report = ValidationReport(is_valid=True, cross_artifact_errors=())
    with pytest.raises(FrozenInstanceError):
        report.is_valid = False  # type: ignore[misc]
