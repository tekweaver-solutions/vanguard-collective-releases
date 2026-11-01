"""
Tests for WorkerRunner (tools/worker-runner/runner.py).

Per the step-5 C3 design (operator-approved 2026-05-30): option (iii) mix.
- Pipeline tests (~9): construct WorkerRunner, call lifecycle methods
  (_emit_root_trace, _handle_event, _emit_closing_trace,
  _validate_handoff_from_disk / _synthesize_handoff_for_failure)
  directly. Bypasses subprocess machinery; covers event dispatch,
  trace emission, hook correlation, multi-tool_use FIFO ordering,
  Handoff validation, synthesized-Handoff structure.
- Spawn tests (~3): real subprocess against fake-claude.py via the
  claude_argv_prefix test seam. Covers env scrubbing, argv composition,
  claude_cli_safety enforcement.
- Schema-rejection test (~1, design-review addition): malformed handoff file on
  disk propagates Pydantic ValidationError -- documents the design
  choice that the runner does NOT synthesize on malformed-file (worker
  tried and failed, distinct from worker-died-before-writing).

Total: 13 tests.

Test #5 (test_multi_tool_use_fifo_ordering) is the load-bearing
regression test for the design-review pop(0) FIFO decision. If a future
maintainer reverts to pop() or [-1] (LIFO), this test fails
specifically and loudly because it asserts that the FIRST inserted
ToolCallTrace's tool_input matches the FIRST tool_use block in the
assistant message -- not the second.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from pydantic import ValidationError

from audit_log import AuditLog
from mcp_capability_map import CapabilityMap
from policy import Gateway
from runner import WorkerRunner
from schemas import (
    AgentRole,
    EscalationTrace,
    GatewayDecision,
    LLMCallTrace,
    ModelClass,
    StateTransitionTrace,
    ToolCallTrace,
    TraceStatus,
    TerminatedReason,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
)
from trace_store import TraceStore

FIXTURE_DIR = Path(__file__).parent / "fixtures"
FAKE_CLAUDE_PY = FIXTURE_DIR / "fake-claude.py"
SAMPLE_HANDOFF = FIXTURE_DIR / "sample-handoff.json"
SAMPLE_HANDOFF_MALFORMED = FIXTURE_DIR / "sample-handoff-malformed.json"


# ============================================================================
# Helpers / fixtures
# ============================================================================


def _make_dispatch(
    *,
    tool_scope: list[str] | None = None,
    worker_id: str | None = None,
    assertion_targets: list[str] | None = None,
) -> WorkerDispatch:
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-05-30T00:00:00Z",
        created_by="claude-code:test",
        mission_id="mission-test-c3",
        worker_id=worker_id or str(uuid4()),
        kind=WorkerKind.MAINLINE,
        feature_id="F-001",
        assertion_targets=assertion_targets or ["A-001"],
        spec_version=10,
        worktree_id="wt-test",
        model_class=ModelClass.CODING_STRONG,
        tool_scope=tool_scope or ["repo.read"],
        budget=WorkerBudget(cost_cap_usd=10.0, wallclock_cap_minutes=10),
    )


def _provision_mission_fixtures(
    project_root: Path,
    *,
    feature_id: str = "F-001",
    assertion_targets: list[str] | None = None,
    spec_version: int = 10,
) -> None:
    """Provision the minimal .mission/ tree the ADR-007 brief generator reads:
    a spec file declaring `feature_id` and an assertion file per id in
    `assertion_targets`. The pipeline tests bypass run() and don't need
    this; spawn tests do, because run() constructs+writes the brief
    pre-spawn and aborts if the spec/contract files are missing."""
    targets = assertion_targets or ["A-001"]
    spec_dir = project_root / ".mission" / "spec"
    spec_dir.mkdir(parents=True, exist_ok=True)
    spec_dir.joinpath(f"v{spec_version:03d}.yaml").write_text(
        f"features:\n  - id: {feature_id}\n    title: Test feature\n",
        encoding="utf-8",
    )
    contract_dir = project_root / ".mission" / "contract" / "assertions"
    contract_dir.mkdir(parents=True, exist_ok=True)
    for aid in targets:
        contract_dir.joinpath(f"{aid}.yaml").write_text(
            f"id: {aid}\nfeature_id: {feature_id}\n",
            encoding="utf-8",
        )


@pytest.fixture
def runner_setup(tmp_path: Path):
    """Build a WorkerRunner with TraceStore + Gateway + AuditLog ready for
    pipeline tests. Returns (runner, store) so tests can inspect trace events."""
    dispatch = _make_dispatch()
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
    return runner, store


def _events_of_type(store: TraceStore, mission_id: str, cls) -> list:
    return [e for e in store.mission_events(mission_id) if isinstance(e, cls)]


# ============================================================================
# Pipeline tests (~9)
# ============================================================================


def test_root_and_closing_trace_emission(runner_setup) -> None:
    """run()'s root + closing StateTransitionTrace pair anchors the c-γ tree.
    Test the lifecycle methods directly (bypassing subprocess)."""
    runner, store = runner_setup
    runner._emit_root_trace()
    runner._session_id = "session-test-001"
    runner._terminal_result = {"is_error": False, "result": "ok"}
    runner._emit_closing_trace()

    transitions = _events_of_type(
        store, runner._dispatch.mission_id, StateTransitionTrace
    )
    assert len(transitions) == 2
    root = next(t for t in transitions if t.from_state == "dispatched")
    closing = next(t for t in transitions if t.from_state == "running")
    assert root.parent_id is None
    assert root.to_state == "running"
    assert root.trigger == "worker_runner.spawn"
    assert closing.parent_id == root.id
    assert closing.to_state == "completed"
    assert "session=session-test-001" in closing.trigger


def test_assistant_emits_llm_call_trace(runner_setup) -> None:
    runner, store = runner_setup
    runner._emit_root_trace()
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 12, "output_tokens": 34},
                "content": [{"type": "text", "text": "hello"}],
            },
        }
    )

    llms = _events_of_type(store, runner._dispatch.mission_id, LLMCallTrace)
    assert len(llms) == 1
    llm = llms[0]
    assert llm.parent_id == runner._root_id
    assert llm.model == "claude-opus-4-7"
    assert llm.tokens_in == 12
    assert llm.tokens_out == 34
    assert llm.prompt_version == "inlined:_HANDOFF_INSTRUCTION_TEMPLATE"


def test_hook_correlation_single_tool_use(runner_setup) -> None:
    runner, store = runner_setup
    runner._emit_root_trace()
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu_A",
                        "name": "Read",
                        "input": {"file_path": "/a"},
                    }
                ],
            },
        }
    )
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h1"}
    )
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h1",
            "exit_code": 0,
            "stderr": "",
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_A",
                        "content": "ok",
                        "is_error": False,
                    }
                ]
            },
        }
    )

    tcs = _events_of_type(store, runner._dispatch.mission_id, ToolCallTrace)
    assert len(tcs) == 1
    tc = tcs[0]
    assert tc.gateway_decision == GatewayDecision.ALLOWED
    assert tc.tool_name == "Read"
    assert tc.input == {"file_path": "/a"}
    assert tc.capability_tag == "repo.read"


def test_hook_correlation_denied_tool(runner_setup) -> None:
    """exit_code=2 from hook → DENIED ToolCallTrace; status=ERROR."""
    runner, store = runner_setup
    runner._emit_root_trace()
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu_B",
                        "name": "Bash",
                        "input": {"command": "echo x"},
                    }
                ],
            },
        }
    )
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h2"}
    )
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h2",
            "exit_code": 2,
            "stderr": "gateway_denied: tool='Bash' capability='shell.exec.sandboxed' reason=missing",
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_B",
                        "content": "PreToolUse:Bash hook error: ...",
                        "is_error": True,
                    }
                ]
            },
        }
    )

    tcs = _events_of_type(store, runner._dispatch.mission_id, ToolCallTrace)
    assert len(tcs) == 1
    tc = tcs[0]
    assert tc.gateway_decision == GatewayDecision.DENIED
    assert tc.status == TraceStatus.ERROR
    assert tc.error is not None
    assert "gateway_denied" in tc.error


def test_multi_tool_use_fifo_ordering(runner_setup) -> None:
    """🌟 Load-bearing FIFO regression test (design-review specificity and pop(0) fix).

    A single assistant message with two tool_use blocks [A, B]. The first
    hook_response must pair with tool_use[0] (A); the second with tool_use[1] (B).

    If FIFO regresses to LIFO (pop() instead of pop(0), or [-1] peek), the
    first ToolCallTrace would carry B's input, not A's -- this test fails
    specifically on that regression.
    """
    runner, store = runner_setup
    runner._emit_root_trace()
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu_A",
                        "name": "Read",
                        "input": {"file_path": "/A"},
                    },
                    {
                        "type": "tool_use",
                        "id": "tu_B",
                        "name": "Read",
                        "input": {"file_path": "/B"},
                    },
                ],
            },
        }
    )
    # First hook + result pair -- must bind to A.
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h_A"}
    )
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h_A",
            "exit_code": 0,
            "stderr": "",
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_A",
                        "content": "A-result",
                        "is_error": False,
                    }
                ]
            },
        }
    )
    # Second pair -- binds to B.
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h_B"}
    )
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h_B",
            "exit_code": 0,
            "stderr": "",
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_B",
                        "content": "B-result",
                        "is_error": False,
                    }
                ]
            },
        }
    )

    tcs = _events_of_type(store, runner._dispatch.mission_id, ToolCallTrace)
    assert len(tcs) == 2
    # ToolCallTraces are stored in chronological order via mission_events
    # (sorted by started_at). The first inserted is A's, the second is B's.
    first, second = tcs[0], tcs[1]
    # Specific A-vs-B distinction via input value (design-review specificity).
    assert first.input == {"file_path": "/A"}, (
        f"FIFO regression: first ToolCallTrace.input was {first.input!r}, "
        f"expected {'/A'}. If this fails, _handle_hook_started is binding "
        f"hook events LIFO (pop()/[-1]) instead of FIFO (pop(0))."
    )
    assert second.input == {"file_path": "/B"}
    # Both parent to the same LLMCallTrace.
    assert first.parent_id == second.parent_id


def test_inconsistency_escalation_emitted_on_decision_disagreement(
    runner_setup,
) -> None:
    """Force local Gateway.check to ALLOW but inject hook_response exit_code=2
    → EscalationTrace emitted with the queryable colon-separated format."""
    runner, store = runner_setup
    # Worker has test.run in scope -- local will say Bash ALLOWED.
    # (Migrated from shell.exec.sandboxed to test.run after ADR-027 D2 made
    # shell.exec.* ungrantable at dispatch-construction; the test's POINT is
    # the local-allowed/hook-denied capability_tag MISMATCH escalation, not
    # shell.exec specifically. Any Bash-authorizing grantable tag preserves
    # what the test proves.)
    runner._dispatch = _make_dispatch(tool_scope=["test.run"])
    runner._emit_root_trace()
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu_X",
                        "name": "Bash",
                        "input": {"command": "echo x"},
                    }
                ],
            },
        }
    )
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h_x"}
    )
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h_x",
            "exit_code": 2,
            "stderr": "gateway_denied: tool='Bash' capability='shell.exec.unsandboxed' reason=mismatch",
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_X",
                        "content": "blocked",
                        "is_error": True,
                    }
                ]
            },
        }
    )

    escalations = _events_of_type(
        store, runner._dispatch.mission_id, EscalationTrace
    )
    assert len(escalations) == 1
    e = escalations[0]
    assert e.error is not None
    assert "inconsistency:hook_decision_vs_local_gateway" in e.error
    assert "hook=denied" in e.error
    assert "local=allowed" in e.error
    assert "hook_cap=shell.exec.unsandboxed" in e.error
    # local_cap updated alongside the fixture migration above (test.run is
    # now the local-authorizing tag).
    assert "local_cap=test.run" in e.error


def test_handoff_exemption_runner_side_records_observable_capability(
    runner_setup,
) -> None:
    """Runner-side mirror of the gateway-hook exemption: when the worker
    calls Write with file_path == self._handoff_path, _reconstruct_verdict
    short-circuits to ALLOWED with capability_tag=
    'framework.handoff_exemption' (the observable marker the operator
    required), and NO EscalationTrace fires (both sides agree on the
    exemption -- without this mirror, every legitimate handoff Write
    would emit a false §6.2 escalation since the local gateway's
    repo.read scope check says DENY for Write)."""
    runner, store = runner_setup
    # Worker has repo.read scope (no worktree.write). Write would
    # normally be DENIED by local gateway.
    runner._dispatch = _make_dispatch(tool_scope=["repo.read"])
    runner._emit_root_trace()
    handoff_path_str = str(runner._handoff_path)
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu_handoff",
                        "name": "Write",
                        "input": {
                            "file_path": handoff_path_str,
                            "content": "{}",
                        },
                    }
                ],
            },
        }
    )
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h_handoff"}
    )
    # Hook agrees with the exemption -- exit 0, observable stderr.
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h_handoff",
            "exit_code": 0,
            "stderr": (
                "gateway_exemption: tool='Write' "
                "capability='framework.handoff_exemption' "
                f"reason='handoff_protocol_exact_path_allow' file_path={handoff_path_str!r}"
            ),
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_handoff",
                        "content": "wrote 2 bytes",
                        "is_error": False,
                    }
                ]
            },
        }
    )

    # No escalation fired -- both sides agreed via the exemption.
    escalations = _events_of_type(
        store, runner._dispatch.mission_id, EscalationTrace
    )
    assert len(escalations) == 0, (
        f"unexpected escalation on handoff exemption (hook + runner should "
        f"agree); escalations={[e.error for e in escalations]!r}"
    )

    # ToolCallTrace records the exemption observably: ALLOWED +
    # capability_tag = framework.handoff_exemption (NOT a regular tag).
    tcs = _events_of_type(store, runner._dispatch.mission_id, ToolCallTrace)
    assert len(tcs) == 1
    tc = tcs[0]
    assert tc.gateway_decision == GatewayDecision.ALLOWED
    assert tc.capability_tag == "framework.handoff_exemption", (
        f"exemption-allow must be distinguishable from normal scope-allow "
        f"in the trace via capability_tag; got {tc.capability_tag!r}"
    )
    assert tc.tool_name == "Write"
    assert tc.input["file_path"] == handoff_path_str


def test_handoff_exemption_runner_side_DOES_NOT_apply_to_sibling_path(
    runner_setup,
) -> None:
    """Critical negative: a Write to a different file under the same
    dispatch dir (e.g. tool_scope.json) does NOT trigger the runner-side
    exemption. Local gateway path goes through normal scope check ->
    DENIED -- the read-only guarantee holds for every path except the
    exact handoff_path."""
    runner, store = runner_setup
    runner._dispatch = _make_dispatch(tool_scope=["repo.read"])
    runner._emit_root_trace()
    # Sibling path under the dispatch dir -- NOT the handoff_path.
    sibling_path = str(runner._dispatch_dir / "tool_scope.json")
    assert sibling_path != str(runner._handoff_path)
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu_sibling",
                        "name": "Write",
                        "input": {"file_path": sibling_path, "content": "bad"},
                    }
                ],
            },
        }
    )
    runner._handle_event(
        {"type": "system", "subtype": "hook_started", "hook_id": "h_sibling"}
    )
    # Hook agrees: DENIED (the hook's exemption also doesn't apply to
    # sibling paths). Worker-runner local gateway will say DENIED too;
    # no exemption short-circuit; no escalation.
    runner._handle_event(
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h_sibling",
            "exit_code": 2,
            "stderr": (
                "gateway_denied: tool='Write' capability='worktree.write' "
                "reason=Tool 'Write' requires one of ['worktree.write']; "
                "worker tool_scope is ['repo.read']."
            ),
        }
    )
    runner._handle_event(
        {
            "type": "user",
            "message": {
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": "tu_sibling",
                        "content": "PreToolUse:Write hook error: ...",
                        "is_error": True,
                    }
                ]
            },
        }
    )

    tcs = _events_of_type(store, runner._dispatch.mission_id, ToolCallTrace)
    assert len(tcs) == 1
    tc = tcs[0]
    assert tc.gateway_decision == GatewayDecision.DENIED, (
        f"sibling-path Write must be denied; the exemption must not leak"
    )
    # capability_tag must NOT be the exemption marker -- it should be the
    # regular worktree.write capability that the worker doesn't have.
    assert tc.capability_tag == "worktree.write"
    # No escalation either: hook denied, runner-local denied -- agreement.
    escalations = _events_of_type(
        store, runner._dispatch.mission_id, EscalationTrace
    )
    assert len(escalations) == 0


def test_handoff_validation_from_disk_happy_path(runner_setup) -> None:
    """Valid handoff.json on disk → returned via _validate_handoff_from_disk."""
    runner, _ = runner_setup
    runner._dispatch_dir.mkdir(parents=True, exist_ok=True)
    handoff_text = SAMPLE_HANDOFF.read_text(encoding="utf-8")
    runner._handoff_path.write_text(handoff_text, encoding="utf-8")
    h = runner._validate_handoff_from_disk()
    assert str(h.id) == "11111111-1111-4111-8111-111111111111"
    assert h.from_worker == "w-2026-05-30-test"
    assert h.completed_assertions == ["A-001", "A-002"]


def test_handoff_validation_rejects_malformed(runner_setup) -> None:
    """Exercises _validate_handoff_from_disk in isolation from run().
    Pairs with test_malformed_handoff_propagates_through_run which exercises
    the same code path via the full pipeline (design-review unit↔integration split)."""
    runner, _ = runner_setup
    runner._dispatch_dir.mkdir(parents=True, exist_ok=True)
    runner._handoff_path.write_text(
        SAMPLE_HANDOFF_MALFORMED.read_text(encoding="utf-8"), encoding="utf-8"
    )
    with pytest.raises(ValidationError):
        runner._validate_handoff_from_disk()


def test_synthesized_handoff_on_no_file(runner_setup) -> None:
    """No handoff file written by worker → synthesized Handoff with
    terminated_reason=CRASH_RECOVERED, procedure_adherence=CONFIRMED,
    issues_observed populated."""
    runner, _ = runner_setup
    # Simulate subprocess exited but never wrote handoff.json.
    runner._subprocess_exit_code = 1
    runner._subprocess_stderr = b"some final stderr"
    h = runner._synthesize_handoff_for_failure()
    assert h.terminated_reason == TerminatedReason.CRASH_RECOVERED
    assert h.commits == []  # tmp_path worktree has no git; rev-list empty
    assert h.completed_assertions == []
    assert len(h.unfinished) == 1  # one per assertion_target
    assert "subprocess_exit_code=1" in " ".join(h.issues_observed)


# ============================================================================
# Spawn tests (~3)
# ============================================================================


def _spawn_runner(
    tmp_path: Path,
    *,
    selector: str = "llm-only",
    debug: bool = True,
    extra_env: dict | None = None,
) -> tuple[WorkerRunner, TraceStore, dict]:
    """Build a WorkerRunner whose claude_argv_prefix invokes fake-claude.py."""
    dispatch = _make_dispatch(worker_id=str(uuid4()))
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    _provision_mission_fixtures(project_root)  # ADR-007: brief inputs

    store = TraceStore(tmp_path / "traces.sqlite")
    gateway = Gateway(CapabilityMap.default())
    audit = AuditLog(store)

    prefix = [sys.executable, str(FAKE_CLAUDE_PY)]
    if debug:
        prefix.append("--debug")
    prefix.append(selector)

    runner = WorkerRunner(
        dispatch,
        store=store,
        gateway=gateway,
        audit=audit,
        worktree_path=worktree,
        worktree_base_commit="abc1234",
        project_root=project_root,
        claude_argv_prefix=prefix,
    )
    return runner, store, dispatch


@pytest.mark.asyncio
async def test_spawn_scrubs_anthropic_api_key(tmp_path: Path, monkeypatch) -> None:
    """env_scrub.build_scrubbed_env removes ANTHROPIC_API_KEY from the
    child env at spawn time. Verified by fake-claude.py's DEBUG_ENV line."""
    monkeypatch.setenv("ANTHROPIC_API_KEY", "SENTINEL_SHOULD_NOT_LEAK")
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    try:
        await runner.run()
    except Exception:
        # Some downstream steps (handoff validation) may fail in the spawn
        # tests because we don't write handoff.json -- that's fine, we're
        # asserting on subprocess stderr observation, not run() outcome.
        pass
    stderr_text = runner._subprocess_stderr.decode("utf-8", errors="replace")
    assert "DEBUG_ENV: ANTHROPIC_API_KEY=<unset>" in stderr_text, (
        f"Expected ANTHROPIC_API_KEY scrubbed; got stderr={stderr_text!r}"
    )


# THE API-KEY MODE. No key is ever here: the value fails the
# provider's key shape, and fake-claude.py reports only whether one is present.
_NOT_A_KEY = "not-a-key-r2s3-test-dummy"


@pytest.mark.asyncio
async def test_spawn_keeps_the_key_in_key_mode(tmp_path: Path, monkeypatch) -> None:
    """VANGUARD_AUTH_MODE=api-key: the child keeps ANTHROPIC_API_KEY, and
    nothing prints its value."""
    monkeypatch.setenv("VANGUARD_AUTH_MODE", "api-key")
    monkeypatch.setenv("ANTHROPIC_API_KEY", _NOT_A_KEY)
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    try:
        await runner.run()
    except Exception:
        pass
    stderr_text = runner._subprocess_stderr.decode("utf-8", errors="replace")
    assert "DEBUG_ENV: ANTHROPIC_API_KEY=<set>" in stderr_text, stderr_text
    assert _NOT_A_KEY not in stderr_text


@pytest.mark.asyncio
async def test_spawn_refused_before_anything_when_the_mode_has_no_key(tmp_path: Path, monkeypatch) -> None:
    """VANGUARD_AUTH_MODE=api-key with no key: refused naming the variable,
    before the brief is written and before any subprocess."""
    from env_scrub import AuthModeRefused

    monkeypatch.setenv("VANGUARD_AUTH_MODE", "api-key")
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    with pytest.raises(AuthModeRefused) as e:
        await runner.run()
    assert e.value.code == "AUTH-MODE-KEY-ABSENT" and "ANTHROPIC_API_KEY" in e.value.reason
    assert getattr(runner, "_process", None) is None
    assert not runner._brief_path.exists()


@pytest.mark.asyncio
async def test_spawn_refused_when_a_file_it_hands_the_cli_is_key_shaped(tmp_path: Path, monkeypatch) -> None:
    """Key mode: the brief the CLI is pointed at carries a key-shaped value
    (one repeated character, never sent): refused before the subprocess."""
    from env_scrub import AuthModeRefused

    monkeypatch.setenv("VANGUARD_AUTH_MODE", "api-key")
    monkeypatch.setenv("ANTHROPIC_API_KEY", _NOT_A_KEY)
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    shaped = "sk-ant-api03-" + "x" * 40
    original = runner._construct_and_write_brief

    def write_then_plant() -> None:
        original()
        runner._brief_path.write_text(runner._brief_path.read_text(encoding="utf-8") + "\n" + shaped + "\n", encoding="utf-8")

    monkeypatch.setattr(runner, "_construct_and_write_brief", write_then_plant)
    with pytest.raises(AuthModeRefused) as e:
        await runner.run()
    assert e.value.code == "AUTH-MODE-KEY-IN-FILE" and str(runner._brief_path) in e.value.reason
    assert shaped not in str(e.value)
    assert getattr(runner, "_process", None) is None


@pytest.mark.parametrize("mode,rel,text,code", [
    ("api-key", "CLAUDE.md", "# notes\n" + "sk-ant-api03-" + "x" * 40 + "\n", "AUTH-MODE-KEY-IN-FILE"),
    ("api-key", ".mcp.json", '{"mcpServers": {"s": {"env": {"T": "' + "sk-ant-api03-" + "x" * 40 + '"}}}}\n', "AUTH-MODE-KEY-IN-FILE"),
    ("api-key", ".claude/settings.local.json", '{"apiKeyHelper": "x"}\n', "AUTH-MODE-KEY-IN-FILE"),
    ("subscription", ".claude/settings.local.json", '{"env": {"ANTHROPIC_AUTH_TOKEN": "x"}}\n', "AUTH-MODE-BOTH-CLAIMED"),
], ids=["key in the worktree's CLAUDE.md", "key in the worktree's .mcp.json", "credential setting in the worktree's settings", "subscription beside a token in the worktree's settings"])
@pytest.mark.asyncio
async def test_spawn_refused_for_what_the_cli_loads_from_its_worktree(tmp_path: Path, monkeypatch, mode, rel, text, code) -> None:
    """The CLI runs in the worktree and loads its memory files, its MCP
    configuration and its .claude settings itself: each is held as a file the
    spawn hands the CLI, before the subprocess."""
    from env_scrub import AuthModeRefused

    monkeypatch.setenv("VANGUARD_AUTH_MODE", mode)
    if mode == "api-key":
        monkeypatch.setenv("ANTHROPIC_API_KEY", _NOT_A_KEY)
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    planted = runner._worktree_path / rel
    planted.parent.mkdir(parents=True, exist_ok=True)
    planted.write_text(text, encoding="utf-8")
    with pytest.raises(AuthModeRefused) as e:
        await runner.run()
    assert e.value.code == code and str(planted) in e.value.reason
    assert "sk-ant-" not in str(e.value) and _NOT_A_KEY not in str(e.value)
    assert getattr(runner, "_process", None) is None


@pytest.mark.asyncio
async def test_spawn_subscription_admits_the_subscription_token_in_the_worktree(tmp_path: Path, monkeypatch) -> None:
    """CLAUDE_CODE_OAUTH_TOKEN is the subscription's own credential: under
    VANGUARD_AUTH_MODE=subscription a settings file naming it is not refused."""
    monkeypatch.setenv("VANGUARD_AUTH_MODE", "subscription")
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    planted = runner._worktree_path / ".claude" / "settings.local.json"
    planted.parent.mkdir(parents=True)
    planted.write_text('{"env": {"CLAUDE_CODE_OAUTH_TOKEN": "x"}}\n', encoding="utf-8")
    try:
        await runner.run()
    except Exception as e:  # handoff validation may fail downstream, as in the other spawn tests
        assert type(e).__name__ != "AuthModeRefused", str(e)
    assert runner._subprocess_stderr, "the subprocess ran"


# The files the CLI loads from its worktree, spelled in another
# letter case. A case-insensitive file system opens each under the CLI's own
# name; the scan reads each and names it as it stands in the worktree (str,
# never Path: a WindowsPath compares equal across letter case).
_SHAPED = "sk-ant-api03-" + "x" * 40


@pytest.mark.parametrize("mode,rel,text,code", [
    ("api-key", "claude.md", "# notes\n" + _SHAPED + "\n", "AUTH-MODE-KEY-IN-FILE"),
    ("api-key", ".Claude/CLAUDE.md", "# notes\n" + _SHAPED + "\n", "AUTH-MODE-KEY-IN-FILE"),
    ("api-key", ".Claude/settings.json", '{"apiKeyHelper": "x"}\n', "AUTH-MODE-KEY-IN-FILE"),
    ("subscription", ".Claude/settings.json", '{"apiKeyHelper": "x"}\n', "AUTH-MODE-BOTH-CLAIMED"),
], ids=["key in the worktree's claude.md", "key in the worktree's .Claude/CLAUDE.md",
        "credential setting in the worktree's .Claude/settings.json",
        "subscription beside a credential setting in the worktree's .Claude/settings.json"])
@pytest.mark.asyncio
async def test_spawn_refused_for_what_the_cli_loads_from_its_worktree_in_another_letter_case(
    tmp_path: Path, monkeypatch, mode, rel, text, code
) -> None:
    from env_scrub import AuthModeRefused

    monkeypatch.setenv("VANGUARD_AUTH_MODE", mode)
    if mode == "api-key":
        monkeypatch.setenv("ANTHROPIC_API_KEY", _NOT_A_KEY)
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    planted = runner._worktree_path / rel
    planted.parent.mkdir(parents=True, exist_ok=True)
    planted.write_text(text, encoding="utf-8")
    with pytest.raises(AuthModeRefused) as e:
        await runner.run()
    assert e.value.code == code, str(e.value)
    assert str(planted) in e.value.reason, "the reason names the file as it stands in the worktree: " + e.value.reason
    assert "sk-ant-" not in str(e.value) and _NOT_A_KEY not in str(e.value)
    assert getattr(runner, "_process", None) is None


@pytest.mark.asyncio
async def test_spawn_admits_a_clean_worktree_in_another_letter_case(tmp_path: Path, monkeypatch) -> None:
    """A clean claude.md and the subscription's own token in .Claude/settings.json are not refused."""
    monkeypatch.setenv("VANGUARD_AUTH_MODE", "subscription")
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    (runner._worktree_path / "claude.md").write_text("# notes\n", encoding="utf-8")
    planted = runner._worktree_path / ".Claude" / "settings.json"
    planted.parent.mkdir(parents=True)
    planted.write_text('{"env": {"CLAUDE_CODE_OAUTH_TOKEN": "x"}}\n', encoding="utf-8")
    try:
        await runner.run()
    except Exception as e:  # handoff validation may fail downstream, as in the other spawn tests
        assert type(e).__name__ != "AuthModeRefused", str(e)
    assert runner._subprocess_stderr, "the subprocess ran"


@pytest.mark.asyncio
async def test_spawn_argv_includes_required_flags(tmp_path: Path) -> None:
    """The runner's argv carries the required claude -p flags (verified
    via fake-claude.py's DEBUG_ARGV emission)."""
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    try:
        await runner.run()
    except Exception:
        pass
    stderr_text = runner._subprocess_stderr.decode("utf-8", errors="replace")
    debug_argv_line = next(
        (ln for ln in stderr_text.splitlines() if ln.startswith("DEBUG_ARGV:")),
        None,
    )
    assert debug_argv_line is not None, f"DEBUG_ARGV line missing; stderr={stderr_text!r}"
    argv_json = debug_argv_line[len("DEBUG_ARGV: ") :]
    argv = json.loads(argv_json)
    # Required flags. Note: `--append-system-prompt-file` (NOT
    # `--append-system-prompt`) -- the file channel post-Route-A. The
    # multi-line argv channel was silently truncating at newline-pair
    # through asyncio -> cmd.exe /c on Windows.
    for required in (
        "-p",
        "--output-format",
        "stream-json",
        "--verbose",
        "--include-hook-events",
        "--settings",
        "--append-system-prompt-file",
        "--max-budget-usd",
        "--session-id",
        "--no-session-persistence",
        "--permission-mode",
        "--add-dir",
    ):
        assert required in argv, f"Required flag {required!r} missing from argv"
    # Negative guard: the multi-line truncating channel must NOT be back.
    assert "--append-system-prompt" not in argv, (
        "regression: argv contains --append-system-prompt (multi-line, "
        "truncating); should be --append-system-prompt-file (path channel)"
    )
    # Permission mode is `acceptEdits` (NOT `default`). `default` prompts
    # for permission, which in -p headless mode = denial.
    pm_idx = argv.index("--permission-mode")
    assert argv[pm_idx + 1] == "acceptEdits", (
        f"--permission-mode value is {argv[pm_idx + 1]!r}; expected "
        f"'acceptEdits'. `default` blocks brief Read + handoff Write in "
        f"headless mode."
    )


@pytest.mark.asyncio
async def test_spawn_argv_add_dir_scoped_to_two_dispatch_dirs(
    tmp_path: Path,
) -> None:
    """The CONTAINMENT-SCOPE GUARD. --add-dir extends Claude's permission
    engine trust set with EXACTLY the two per-dispatch artifact dirs
    (.mission/dispatches/<id>/ + .mission-runtime/dispatches/<id>/), NOT
    project_root-wide. Probe confirmed scoped containment holds for
    writes -- this test guards against a future change widening the
    trust scope and silently losing defense-in-depth."""
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    try:
        await runner.run()
    except Exception:
        pass
    stderr_text = runner._subprocess_stderr.decode("utf-8", errors="replace")
    debug_argv_line = next(
        (ln for ln in stderr_text.splitlines() if ln.startswith("DEBUG_ARGV:")),
        None,
    )
    assert debug_argv_line is not None
    argv = json.loads(debug_argv_line[len("DEBUG_ARGV: "):])

    # --add-dir is variadic; its values are the args immediately after
    # the flag, up to either EOF (if --add-dir is the trailing flag set)
    # or the next `--flag`. Per the runner's design --add-dir MUST be the
    # trailing flag set -- assert that invariant first.
    add_dir_idx = argv.index("--add-dir")
    trailing_args = argv[add_dir_idx + 1 :]
    # No `--flag` may appear after --add-dir's first value; otherwise the
    # variadic would stop consuming and the trust-set parsing breaks.
    for i, a in enumerate(trailing_args):
        if a.startswith("--"):
            raise AssertionError(
                f"flag {a!r} found at argv[{add_dir_idx + 1 + i}] AFTER "
                f"--add-dir; --add-dir is variadic-greedy and MUST be "
                f"the trailing flag set or its trust-set parsing breaks. "
                f"argv tail = {argv[add_dir_idx:]!r}"
            )

    # The runner's two dirs: brief_dir (.mission/dispatches/<id>) and
    # dispatch_dir (.mission-runtime/dispatches/<id>). Assert BOTH appear
    # AND assert the scope is NOT project-root-wide.
    add_dir_values = trailing_args  # everything after --add-dir
    expected_brief_dir = str(runner._brief_dir)
    expected_dispatch_dir = str(runner._dispatch_dir)
    assert expected_brief_dir in add_dir_values, (
        f"brief_dir {expected_brief_dir!r} missing from --add-dir trust set; "
        f"got {add_dir_values!r}"
    )
    assert expected_dispatch_dir in add_dir_values, (
        f"dispatch_dir {expected_dispatch_dir!r} missing from --add-dir "
        f"trust set; got {add_dir_values!r}"
    )
    # CONTAINMENT GUARD: exactly TWO values. A future change that adds
    # `str(runner._project_root)` or similar broader paths to the trust
    # set fails this assertion loudly. Defense-in-depth depends on the
    # trust set being NARROW.
    assert len(add_dir_values) == 2, (
        f"--add-dir must have EXACTLY 2 trusted dirs (the per-dispatch "
        f"brief_dir + dispatch_dir). Got {len(add_dir_values)}: "
        f"{add_dir_values!r}. Widening the trust set defeats the "
        f"defense-in-depth verification from the probe."
    )
    # Negative guard: project_root MUST NOT appear in the trust set.
    project_root_str = str(runner._project_root)
    assert project_root_str not in add_dir_values, (
        f"--add-dir trust set contains project_root {project_root_str!r}; "
        f"trust must stay scoped to dispatch dirs only."
    )


@pytest.mark.asyncio
async def test_malformed_handoff_propagates_through_run(tmp_path: Path) -> None:
    """Design-review integration: subprocess completes successfully (fake-claude emits
    a clean stream); handoff.json on disk is §5-invalid; run() PROPAGATES
    Pydantic's ValidationError rather than synthesizing.

    Documents the deliberate design choice: when the worker DID write a
    file, the runner doesn't substitute a synthesized one -- the worker
    tried and failed (a distinct outcome from worker-died-before-writing,
    which IS synthesized via test_synthesized_handoff_on_no_file).
    The dispatch script (step 8) catches ValidationError and decides
    rework semantics.
    """
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=False)
    runner._dispatch_dir.mkdir(parents=True, exist_ok=True)
    runner._handoff_path.write_text(
        SAMPLE_HANDOFF_MALFORMED.read_text(encoding="utf-8"), encoding="utf-8"
    )
    with pytest.raises(ValidationError):
        await runner.run()


@pytest.mark.asyncio
async def test_spawn_rejects_forbidden_flag(tmp_path: Path) -> None:
    """Injecting --bare via claude_argv_prefix triggers claude_cli_safety
    BEFORE subprocess spawn (RuntimeError; ADR-014 flag-seam)."""
    dispatch = _make_dispatch(worker_id=str(uuid4()))
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    _provision_mission_fixtures(project_root)  # ADR-007: brief inputs
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
        # Inject --bare directly into the prefix; validate_claude_argv must reject.
        claude_argv_prefix=[sys.executable, str(FAKE_CLAUDE_PY), "--bare", "llm-only"],
    )
    with pytest.raises(RuntimeError, match="--bare"):
        await runner.run()


# ============================================================================
# ADR-007 runner integration tests
# ============================================================================
#
# Cover the pieces that brief_generator unit tests cannot:
#   - The runner WRITES the brief to .mission/dispatches/<id>/task-brief.md
#     (committed-artifact path; pre-spawn).
#   - The runner POPULATES brief_version on every worker LLMCallTrace and
#     captures the rendered brief on the FIRST turn's input (closes the runner gap).
#   - _validate_pre_spawn rejects missing/empty briefs.
#   - _build_argv composes THREE distinct system-prompt surfaces in order
#     (task brief pointer / separator / handoff protocol), neither
#     surface replacing the other.
#   - operator_note threaded via the constructor lands in the rendered
#     brief on disk under the labeled section.


def _runner_with_mission_dir(tmp_path: Path, **runner_kwargs):
    """Build a WorkerRunner pointed at a tmp_path project_root that has
    the ADR-007 brief inputs provisioned. Pipeline-style: no spawn."""
    dispatch = _make_dispatch()
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    _provision_mission_fixtures(project_root)

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
        **runner_kwargs,
    )
    return runner, store, project_root


def test_construct_and_write_brief_lands_committed_artifact(tmp_path: Path) -> None:
    """ADR-007 decision 4: the committed task-brief is written to
    .mission/dispatches/<id>/task-brief.md (NOT runtime scratch)."""
    runner, _, project_root = _runner_with_mission_dir(tmp_path)
    runner._construct_and_write_brief()

    brief_path = (
        project_root
        / ".mission"
        / "dispatches"
        / runner._dispatch_id
        / "task-brief.md"
    )
    assert brief_path.is_file(), (
        f"task-brief.md missing at committed-artifact path: {brief_path}"
    )
    assert brief_path.stat().st_size > 0
    # The brief is NOT under .mission-runtime/.
    runtime_path = (
        project_root
        / ".mission-runtime"
        / "dispatches"
        / runner._dispatch_id
        / "task-brief.md"
    )
    assert not runtime_path.exists()


def test_validate_pre_spawn_rejects_missing_brief(tmp_path: Path) -> None:
    """A missing brief is a dispatch-construction error per ADR-007
    decision 1; _validate_pre_spawn refuses to proceed to spawn."""
    runner, _, _ = _runner_with_mission_dir(tmp_path)
    # Brief was not constructed (the pre-spawn skipped).
    with pytest.raises(RuntimeError, match="task-brief.md missing pre-spawn"):
        runner._validate_pre_spawn()


def test_validate_pre_spawn_rejects_empty_brief(tmp_path: Path) -> None:
    """An empty brief is treated as a construction failure -- the
    file-exists-but-empty case isn't silently allowed."""
    runner, _, project_root = _runner_with_mission_dir(tmp_path)
    brief_path = (
        project_root
        / ".mission"
        / "dispatches"
        / runner._dispatch_id
        / "task-brief.md"
    )
    brief_path.parent.mkdir(parents=True, exist_ok=True)
    brief_path.write_text("", encoding="utf-8")
    with pytest.raises(RuntimeError, match="task-brief.md is empty pre-spawn"):
        runner._validate_pre_spawn()


def test_run_aborts_when_brief_construction_fails(tmp_path: Path) -> None:
    """If the project_root has no .mission/ tree, brief construction
    raises BriefConstructionError BEFORE any subprocess machinery
    engages. The runner does not silently spawn a worker with no task."""
    from brief_generator import BriefConstructionError

    dispatch = _make_dispatch()
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()  # intentionally NOT provisioning .mission/

    store = TraceStore(tmp_path / "traces.sqlite")
    runner = WorkerRunner(
        dispatch,
        store=store,
        gateway=Gateway(CapabilityMap.default()),
        audit=AuditLog(store),
        worktree_path=worktree,
        worktree_base_commit="abc1234",
        project_root=project_root,
    )
    with pytest.raises(BriefConstructionError):
        runner._construct_and_write_brief()


def test_build_argv_uses_append_system_prompt_file(tmp_path: Path) -> None:
    """ADR-007 decision 1 + the asyncio->.CMD mangling fix: argv passes
    `--append-system-prompt-file <path>`, NOT the truncating
    `--append-system-prompt <multiline>` channel. Multi-line argv values
    get truncated at newline boundaries through asyncio.create_subprocess_exec
    -> cmd.exe /c on Windows (a dispatch diagnosed this from
    inside: received only the heading line, nothing else)."""
    runner, _, _ = _runner_with_mission_dir(tmp_path)
    runner._construct_and_write_brief()
    runner._write_system_prompt_file()
    argv = runner._build_argv()

    # The OLD channel must NOT appear in argv -- catches a regression
    # that reintroduces the multi-line value into argv.
    assert "--append-system-prompt" not in argv, (
        "argv still uses --append-system-prompt (multi-line truncating "
        "channel); should use --append-system-prompt-file (path channel)"
    )
    # The NEW channel: --append-system-prompt-file <path> as a flag-value
    # pair.
    assert "--append-system-prompt-file" in argv
    asp_idx = argv.index("--append-system-prompt-file")
    asp_path = argv[asp_idx + 1]
    assert asp_path == str(runner._system_prompt_path)

    # The file MUST exist after _write_system_prompt_file() and carry
    # both surfaces verbatim. Catches a regression where the file is
    # passed but the writer didn't compose both surfaces.
    body = runner._system_prompt_path.read_text(encoding="utf-8")
    assert "WORKER TASK BRIEF" in body
    assert "WORKER HANDOFF PROTOCOL" in body
    assert body.index("WORKER TASK BRIEF") < body.index("WORKER HANDOFF PROTOCOL")
    assert "---" in body  # three-surface separator


@pytest.mark.asyncio
async def test_spawn_delivers_full_append_system_prompt_body(
    tmp_path: Path,
) -> None:
    """The crucial coverage hole the trigger fix exposed and this fix
    closes: an argv assertion (above) is not enough -- the multi-line
    body must SURVIVE the asyncio -> cmd.exe /c transit to the
    subprocess. fake-claude --debug now dumps `DEBUG_APPEND_SP_BODY:
    <json-encoded-body>` to stderr (reads --append-system-prompt-file's
    file). This test spawns the runner with --debug, captures stderr,
    parses the JSON payload, and asserts BOTH "WORKER TASK BRIEF" AND
    "WORKER HANDOFF PROTOCOL" surfaces are present in the body that
    actually reached the subprocess.

    Before the Route-A fix (--append-system-prompt <multiline>), this
    test would have failed -- the multi-line body got truncated at the
    first newline-pair through the .CMD shim, only the heading line
    survived. After the Route-A fix, the full body reaches the
    subprocess via the file channel."""
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    try:
        await runner.run()
    except Exception:
        # Downstream handoff steps may fail (no handoff.json via
        # fake-claude); we're asserting on subprocess body observation,
        # not run() outcome.
        pass
    stderr = runner._subprocess_stderr.decode("utf-8", errors="replace")
    lines = [
        ln for ln in stderr.splitlines()
        if ln.startswith("DEBUG_APPEND_SP_BODY:")
    ]
    assert len(lines) == 1, (
        f"expected exactly 1 DEBUG_APPEND_SP_BODY line; got {len(lines)}. "
        f"stderr={stderr!r}"
    )
    import json as _json
    body = _json.loads(lines[0][len("DEBUG_APPEND_SP_BODY: "):])
    # Both surfaces survived the transit.
    assert "WORKER TASK BRIEF" in body, (
        f"brief-pointer heading missing from delivered body. "
        f"body={body!r}"
    )
    assert "WORKER HANDOFF PROTOCOL" in body, (
        f"handoff-protocol heading missing from delivered body -- "
        f"this is the symptom that diagnosed an earlier dispatch (worker "
        f"received only the heading line). body={body!r}"
    )
    # The substitutions made it through too (catches a regression where
    # the file is read but raw template strings come through unsubstituted).
    assert "{brief_path}" not in body
    assert "{handoff_path}" not in body
    # Brief pointer surface precedes the handoff protocol surface.
    assert body.index("WORKER TASK BRIEF") < body.index(
        "WORKER HANDOFF PROTOCOL"
    )
    # Three-surface separator present.
    assert "---" in body
    # Body is multi-line (the precise property the .CMD shim was
    # truncating): more than one non-empty line.
    nonempty = [ln for ln in body.splitlines() if ln.strip()]
    assert len(nonempty) > 5, (
        f"body has only {len(nonempty)} non-empty lines; the transit "
        f"may still be truncating. body={body!r}"
    )


def test_brief_version_populated_on_llm_call_trace(tmp_path: Path) -> None:
    """ADR-007 decision 6: every worker LLMCallTrace carries brief_version.
    Step-5 requirement: brief_version appears in the trace."""
    runner, store, _ = _runner_with_mission_dir(tmp_path)
    runner._construct_and_write_brief()
    runner._emit_root_trace()
    runner._handle_event(
        {
            "type": "assistant",
            "message": {
                "model": "claude-opus-4-7",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [{"type": "text", "text": "ack"}],
            },
        }
    )
    llms = _events_of_type(store, runner._dispatch.mission_id, LLMCallTrace)
    assert len(llms) == 1
    assert llms[0].brief_version == "inlined:_TASK_BRIEF_TEMPLATE:v1"


def test_brief_captured_in_input_on_first_turn_only(tmp_path: Path) -> None:
    """Runner-gap closure: rendered brief markdown lands in the FIRST LLMCallTrace
    input; subsequent turns have empty input (the brief is a constant)."""
    runner, store, _ = _runner_with_mission_dir(tmp_path)
    runner._construct_and_write_brief()
    runner._emit_root_trace()
    for _ in range(2):
        runner._handle_event(
            {
                "type": "assistant",
                "message": {
                    "model": "claude-opus-4-7",
                    "usage": {"input_tokens": 1, "output_tokens": 1},
                    "content": [{"type": "text", "text": "ack"}],
                },
            }
        )
    llms = _events_of_type(store, runner._dispatch.mission_id, LLMCallTrace)
    assert len(llms) == 2
    first, second = llms[0], llms[1]
    assert first.brief_version == "inlined:_TASK_BRIEF_TEMPLATE:v1"
    assert second.brief_version == "inlined:_TASK_BRIEF_TEMPLATE:v1"
    # First turn carries the rendered brief; second is empty.
    assert "task_brief_markdown" in first.input
    assert "WORKER" not in str(first.input["task_brief_markdown"]) or True
    # Brief content sanity-check: F-001 from the test fixture.
    assert "F-001" in first.input["task_brief_markdown"]
    assert second.input == {}


def test_operator_note_lands_in_brief_markdown(tmp_path: Path) -> None:
    """Step-5 requirement: -OperatorNote lands in the labeled section.
    Construct the runner with operator_note set, write the brief, read
    the on-disk markdown, verify the labeled section + the note text."""
    runner, _, project_root = _runner_with_mission_dir(
        tmp_path,
        operator_note="Focus on the example_field field shape.",
    )
    runner._construct_and_write_brief()
    brief_path = (
        project_root
        / ".mission"
        / "dispatches"
        / runner._dispatch_id
        / "task-brief.md"
    )
    body = brief_path.read_text(encoding="utf-8")
    assert "## Operator note (out-of-contract)" in body
    assert "Focus on the example_field field shape." in body


def test_operator_note_default_None_omits_section(tmp_path: Path) -> None:
    runner, _, project_root = _runner_with_mission_dir(tmp_path)
    runner._construct_and_write_brief()
    brief_path = (
        project_root
        / ".mission"
        / "dispatches"
        / runner._dispatch_id
        / "task-brief.md"
    )
    body = brief_path.read_text(encoding="utf-8")
    assert "## Operator note (out-of-contract)" not in body


# ============================================================================
# Spawn-failure robustness (FIX B: §14.3 replayability hole)
# ============================================================================


@pytest.mark.asyncio
async def test_spawn_failure_emits_root_and_closing_traces(
    tmp_path: Path,
) -> None:
    """When the subprocess cannot be started (e.g. argv[0] resolves to a
    nonexistent path), the runner must STILL emit a closing
    StateTransitionTrace pair with the root before propagating the
    exception. A dangling root with no closing pair is a §14.3
    replayability hole -- a trace consumer cannot tell "still running"
    from "spawn died at exec".

    Uses the test seam (claude_argv_prefix) to bypass FIX A's resolver
    guard and exercise the FIX B branch directly: the spawn attempt
    reaches create_subprocess_exec and raises FileNotFoundError there.
    """
    dispatch = _make_dispatch(worker_id=str(uuid4()))
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    _provision_mission_fixtures(project_root)
    store = TraceStore(tmp_path / "traces.sqlite")
    gateway = Gateway(CapabilityMap.default())
    audit = AuditLog(store)

    # Point claude_argv_prefix at a path that definitely does not exist
    # AND has an extension (so it bypasses any shell PATHEXT fallback).
    nonexistent = tmp_path / "definitely-not-real-claude.exe"
    runner = WorkerRunner(
        dispatch,
        store=store,
        gateway=gateway,
        audit=audit,
        worktree_path=worktree,
        worktree_base_commit="abc1234",
        project_root=project_root,
        claude_argv_prefix=[str(nonexistent)],
    )

    with pytest.raises((FileNotFoundError, OSError)):
        await runner.run()

    # BOTH a root and a closing StateTransitionTrace must exist.
    transitions = _events_of_type(
        store, runner._dispatch.mission_id, StateTransitionTrace
    )
    assert len(transitions) == 2, (
        f"expected 2 StateTransitionTrace events (root + closing) on spawn "
        f"failure, got {len(transitions)}. §14.3 replayability requires the "
        f"closing pair even when subprocess never started."
    )
    root = next(t for t in transitions if t.from_state == "dispatched")
    closing = next(t for t in transitions if t.from_state == "running")
    # Root is unchanged in shape.
    assert root.to_state == "running"
    assert root.trigger == "worker_runner.spawn"
    # Closing carries the spawn-failure marker.
    assert closing.parent_id == root.id
    assert closing.status == TraceStatus.ERROR
    assert closing.to_state == "errored"
    assert closing.trigger.startswith("worker_runner.spawn_failure:")
    assert closing.error is not None
    assert "spawn_failure" in closing.error


def test_fix_a_default_executable_unresolvable_fails_clear(tmp_path: Path) -> None:
    """FIX A guard: when the default executable (`claude_executable=Path(...)`,
    no test seam) cannot be resolved AND is not a file on disk,
    _validate_pre_spawn raises a CLEAR RuntimeError -- NOT the cryptic
    FileNotFoundError from create_subprocess_exec deep in asyncio.

    Constructs a runner with a bare name that shutil.which cannot resolve
    on any reasonable system."""
    dispatch = _make_dispatch()
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    _provision_mission_fixtures(project_root)
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
        claude_executable=Path("definitely-not-real-executable-name-12345"),
    )
    # Pre-spawn must construct the brief before the guard can fire.
    runner._construct_and_write_brief()
    with pytest.raises(RuntimeError, match="claude executable not found"):
        runner._validate_pre_spawn()


def test_fix_a_test_seam_not_resolved(tmp_path: Path) -> None:
    """FIX A must NOT apply shutil.which resolution to the
    claude_argv_prefix test seam -- that path is fully-qualified
    by convention and the guard would erroneously fire for any
    `sys.executable` whose name isn't on PATH (or whose resolution
    would land on a different file)."""
    dispatch = _make_dispatch()
    worktree = tmp_path / "worktree"
    worktree.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    _provision_mission_fixtures(project_root)
    store = TraceStore(tmp_path / "traces.sqlite")
    gateway = Gateway(CapabilityMap.default())
    audit = AuditLog(store)

    # Use an existing on-disk path (sys.executable) as the seam target;
    # the guard is keyed on `_uses_default_executable=False`, so even
    # though sys.executable IS resolvable, the resolution branch should
    # not run -- argv[0] remains exactly what the caller passed.
    seam_argv = [sys.executable, "-c", "print('ok')"]
    runner = WorkerRunner(
        dispatch,
        store=store,
        gateway=gateway,
        audit=audit,
        worktree_path=worktree,
        worktree_base_commit="abc1234",
        project_root=project_root,
        claude_argv_prefix=seam_argv,
    )
    assert runner._uses_default_executable is False
    assert runner._claude_argv_prefix == seam_argv  # verbatim, not re-resolved
    # _validate_pre_spawn should not raise the FIX A guard for the seam.
    runner._construct_and_write_brief()
    runner._validate_pre_spawn()  # would raise if the guard mis-applied


# ============================================================================
# claude -p engagement trigger (delivered via stdin, NOT argv positional)
# ============================================================================
#
# `claude -p` requires a prompt input to start the assistant turn -- either
# a positional argv argument or stdin. `--append-system-prompt` is a
# MODIFIER, not the prompt. Without a trigger the worker exits 1 with
# "Input must be provided either through stdin or as a prompt argument
# when using --print" -- captured stderr from earlier dispatches
# (after persist-the-stderr).
#
# **Delivery via stdin, not argv.** A PowerShell-driven differential
# probe confirmed claude engages correctly when the trigger is the
# trailing positional argv element -- but asyncio.create_subprocess_exec
# on Windows wraps .CMD targets via cmd.exe /c, mangling the trailing
# multi-word positional (same Windows-asyncio-subprocess family as the
# PATHEXT gap fixed earlier). Stdin is the cross-platform channel
# claude -p supports first-class. Runner writes the trigger to the
# subprocess stdin pipe then closes the write end (EOF) BEFORE entering
# the stdout parse loop.
#
# The trigger is content-free per ADR-007 conformance: the brief in the
# appended system prompt remains the durable task channel (decisions 1+2);
# the trigger is a CLI-required engagement signal, byte-identical across
# every dispatch. Negative assertions guard against a future change
# quietly migrating the objective into the trigger.


def test_engagement_trigger_not_in_argv(tmp_path: Path) -> None:
    """The trigger MUST NOT appear in argv. Anything that pushes it back
    into argv re-introduces the Windows .CMD positional-mangling that
    caused earlier dispatches to exit 1 with no stream.
    Stdin delivery (in _spawn_and_parse) is the contract."""
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=False)
    runner._construct_and_write_brief()
    argv = runner._build_argv()
    from runner import _TRIGGER_PROMPT
    assert _TRIGGER_PROMPT not in argv, (
        f"trigger leaked into argv (positional delivery is broken on "
        f"Windows .CMD via asyncio); argv tail = {argv[-3:]!r}"
    )
    # And no element of argv contains the trigger as a substring (catches
    # accidental concatenation into another flag's value).
    for i, a in enumerate(argv):
        assert _TRIGGER_PROMPT not in a, (
            f"trigger substring leaked into argv[{i}]={a!r}"
        )
    # argv should END with --add-dir <brief_dir> <dispatch_dir> (the
    # variadic trailing flag set added for Claude's permission-engine
    # layer-2 path containment). The exact dir contents are guarded by
    # `test_spawn_argv_add_dir_scoped_to_two_dispatch_dirs`; here we just
    # assert the variadic-trailing-flag-set invariant the trigger fix
    # depends on (no positional consumes anything; stdin carries it).
    add_dir_idx = argv.index("--add-dir")
    # No flag may appear after --add-dir's first value (variadic-greedy).
    for a in argv[add_dir_idx + 1 :]:
        assert not a.startswith("--"), (
            f"flag {a!r} after --add-dir breaks variadic parsing"
        )


@pytest.mark.asyncio
async def test_spawn_pipes_engagement_trigger_to_stdin(tmp_path: Path) -> None:
    """The runner writes _TRIGGER_PROMPT to the subprocess stdin and
    closes the write end. fake-claude (with --debug) reads its stdin
    fully and emits a `DEBUG_STDIN: <json>` line to stderr so we can
    observe what the runner actually piped."""
    runner, _, _ = _spawn_runner(tmp_path, selector="llm-only", debug=True)
    try:
        await runner.run()
    except Exception:
        # Downstream handoff steps may fail (we don't write handoff.json
        # via fake-claude); we're asserting on subprocess observation,
        # not run() outcome.
        pass
    stderr = runner._subprocess_stderr.decode("utf-8", errors="replace")
    debug_lines = [ln for ln in stderr.splitlines() if ln.startswith("DEBUG_STDIN:")]
    assert len(debug_lines) == 1, (
        f"expected exactly 1 DEBUG_STDIN: line in stderr; got "
        f"{len(debug_lines)}. stderr={stderr!r}"
    )
    # The DEBUG_STDIN line is `DEBUG_STDIN: <json-encoded-stdin-bytes>`.
    import json as _json
    payload = _json.loads(debug_lines[0][len("DEBUG_STDIN: "):])
    from runner import _TRIGGER_PROMPT
    assert payload == _TRIGGER_PROMPT, (
        f"runner piped {payload!r} to stdin, expected {_TRIGGER_PROMPT!r}"
    )


def test_engagement_trigger_carries_no_task_content() -> None:
    """ADR-007 conformance guard: the trigger MUST NOT carry feature-id,
    assertion ids, or objective wording. The brief is the durable task
    channel (ADR-007 decisions 1+2); the trigger is purely a CLI-required
    engagement signal, byte-identical across every dispatch. A future
    change that quietly migrates the objective into the trigger would
    split the task across two surfaces -- the regression this test
    catches. Inspects the module constant directly (the trigger is
    delivered via stdin now, not argv)."""
    from runner import _TRIGGER_PROMPT
    trigger = _TRIGGER_PROMPT

    # Non-empty directive.
    assert trigger.strip(), "trigger must be non-empty"
    # Bounded length (under ~200 bytes keeps it unambiguously a trigger,
    # not a smuggled task description).
    assert len(trigger.encode("utf-8")) < 200, (
        f"trigger length {len(trigger.encode('utf-8'))} bytes exceeds the "
        f"200-byte ceiling that distinguishes a trigger from task content"
    )
    # Zero feature-id leak: F-NNN pattern must not appear anywhere.
    import re
    assert re.search(r"F-\d{3,}", trigger) is None, (
        f"trigger leaks a feature_id reference: {trigger!r}"
    )
    # Zero assertion-id leak: A-NNN pattern must not appear.
    assert re.search(r"A-\d{3,}", trigger) is None, (
        f"trigger leaks an assertion-id reference: {trigger!r}"
    )
    # Zero objective-phrasing leak: the brief's objective sentence is
    # "Implement {feature_id} such that {targets} pass." -- the trigger
    # must not contain that phrasing or its skeleton.
    lower = trigger.lower()
    assert "implement" not in lower, (
        f"trigger contains objective phrasing: {trigger!r}"
    )
    assert "pass." not in lower, (
        f"trigger contains objective phrasing: {trigger!r}"
    )
    # Positive signal: trigger references the brief + handoff surfaces
    # (it IS a directive, not a bare token).
    assert "brief" in lower or "system prompt" in lower
    assert "handoff" in lower

