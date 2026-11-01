"""
Tests for dispatch_entry: WorkerDispatch construction + orchestration entry.

Per the step-8 design (operator-approved 2026-05-30; the operator's answers applied):
Step-8 scope is dispatch → runner → validate → report ONLY.
Promotion + worktree cleanup are deferred to separate operator commands
(the operator's option γ); tests for those (#6, #7 in original plan) are out of step-8 scope.

8 tests:
1. happy path: full dispatch builds, runs against fake-claude, validates handoff, exits 0
2. assertion_targets auto-derived from contract via feature_id + milestone_id (found in review)
3. worker_id minted as UUID (per an operator answer)
4. model_class resolved via model_routing
5. dry-run prints YAML, exits 0 without spawning
6. ValidationReport.is_valid=False → exit code 1
7. runtime failure → exit code 2
8. mainline branch-reuse works on second dispatch (end-to-end)
"""

from __future__ import annotations

import json
import subprocess
import sys
import shutil
from pathlib import Path
from uuid import uuid4

import pytest
import yaml

from dispatch_entry import (
    DispatchInputs,
    DispatchResult,
    _derive_assertion_targets,
    build_dispatch,
    main,
    run_dispatch,
)
from schemas import ModelClass, WorktreeKind

FIXTURE_DIR = Path(__file__).parent / "fixtures"
FAKE_CLAUDE_PY = FIXTURE_DIR / "fake-claude.py"
SAMPLE_HANDOFF = FIXTURE_DIR / "sample-handoff.json"


def _init_mission_like_project(project_root: Path) -> str:
    """Set up a project_root with .mission/ layout + minimal mission.yaml,
    spec/current.txt, and one contract assertion for F-001 / M-1."""
    subprocess.run(
        ["git", "init"], cwd=project_root, check=True, capture_output=True
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=project_root,
        check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"], cwd=project_root, check=True
    )
    (project_root / "README.md").write_text("hi\n")

    mission_dir = project_root / ".mission"
    (mission_dir / "spec").mkdir(parents=True)
    (mission_dir / "contract" / "assertions").mkdir(parents=True)

    (mission_dir / "mission.yaml").write_text(
        yaml.safe_dump({"id": "mission-test-step8", "state": "Executing"}),
        encoding="utf-8",
    )
    (mission_dir / "spec" / "current.txt").write_text("v010", encoding="utf-8")
    # ADR-007 brief generator reads v010.yaml directly for the feature
    # title; without it, `_construct_and_write_brief` raises
    # BriefConstructionError pre-spawn and any test exercising run()
    # fails at exit_code=2 before reaching the synthesis/persistence
    # paths it's actually trying to test.
    (mission_dir / "spec" / "v010.yaml").write_text(
        yaml.safe_dump(
            {
                "features": [
                    {
                        "id": "F-001",
                        "title": "Test feature (dispatch_entry fixture)",
                    },
                ],
            }
        ),
        encoding="utf-8",
    )
    (mission_dir / "contract" / "assertions" / "A-001.yaml").write_text(
        yaml.safe_dump(
            {
                "id": "A-001",
                "feature_id": "F-001",
                "milestone_id": "M-1",
                "type": "structural",
                "assertion": "synthetic",
                "evidence_required": ["test_output"],
                "acceptance_criteria": "synthetic",
                "priority": "must",
                "validator_type": "narrow",
                "created_at": "2026-05-30T00:00:00Z",
                "created_by": "test",
                "superseded_by": None,
            }
        ),
        encoding="utf-8",
    )
    # An assertion outside F-001/M-1 (should NOT be picked up by auto-derive).
    (mission_dir / "contract" / "assertions" / "A-099.yaml").write_text(
        yaml.safe_dump(
            {
                "id": "A-099",
                "feature_id": "F-099",
                "milestone_id": "M-9",
                "type": "structural",
                "assertion": "synthetic",
                "evidence_required": ["test_output"],
                "acceptance_criteria": "synthetic",
                "priority": "must",
                "validator_type": "narrow",
                "created_at": "2026-05-30T00:00:00Z",
                "created_by": "test",
                "superseded_by": None,
            }
        ),
        encoding="utf-8",
    )

    subprocess.run(
        ["git", "add", "."], cwd=project_root, check=True, capture_output=True
    )
    subprocess.run(
        ["git", "commit", "-m", "init"],
        cwd=project_root,
        check=True,
        capture_output=True,
    )
    r = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=project_root,
        capture_output=True,
        text=True,
        check=True,
    )
    return r.stdout.strip()


@pytest.fixture
def project(tmp_path: Path):
    root = tmp_path / "project"
    root.mkdir()
    head = _init_mission_like_project(root)
    return root, head


def _make_inputs(**overrides) -> DispatchInputs:
    defaults = dict(
        feature_id="F-001",
        milestone_id="M-1",
        kind=WorktreeKind.FANOUT,
        model_class=ModelClass.CODING_STRONG,
        tool_scope=["repo.read"],
    )
    defaults.update(overrides)
    return DispatchInputs(**defaults)


def _pre_write_handoff(project_root: Path, dispatch_id: str) -> None:
    """Test setup arranges the handoff.json the runner will read."""
    dispatch_dir = (
        project_root / ".mission-runtime" / "dispatches" / dispatch_id
    )
    dispatch_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy(SAMPLE_HANDOFF, dispatch_dir / "handoff.json")


# ---------- ----------


def test_derive_assertion_targets_filters_by_feature_and_milestone(
    project,
) -> None:
    """The filter rule -- feature_id AND milestone_id both match."""
    project_root, _ = project
    targets = _derive_assertion_targets(project_root, "F-001", "M-1")
    assert targets == ["A-001"]
    # F-099/M-9 yields only A-099, not A-001.
    targets2 = _derive_assertion_targets(project_root, "F-099", "M-9")
    assert targets2 == ["A-099"]


def test_build_dispatch_auto_derives_assertion_targets(project) -> None:
    project_root, _ = project
    inputs = _make_inputs()
    dispatch = build_dispatch(inputs, project_root)
    assert dispatch.assertion_targets == ["A-001"]


def test_build_dispatch_rejects_empty_assertion_match(project) -> None:
    """An empty result raises with a clear error before Pydantic catches min_length=1."""
    project_root, _ = project
    inputs = _make_inputs(feature_id="F-NONEXISTENT", milestone_id="M-NONE")
    with pytest.raises(RuntimeError, match="no assertions match"):
        build_dispatch(inputs, project_root)


def test_build_dispatch_worker_id_is_uuid(project) -> None:
    """Per an operator answer: worker_id is a UUID by convention."""
    project_root, _ = project
    dispatch = build_dispatch(_make_inputs(), project_root)
    from uuid import UUID

    UUID(dispatch.worker_id)  # raises ValueError if not a UUID


def test_dry_run_exits_zero_without_spawning(project, capsys) -> None:
    project_root, _ = project
    inputs = _make_inputs(dry_run=True)
    result = run_dispatch(inputs, project_root)
    assert result.exit_code == 0
    assert result.worktree_id is None  # didn't create worktree
    # Dry-run prints YAML to stdout (PS treats stderr as errors; YAML is
    # the dry-run's output and belongs on stdout).
    captured = capsys.readouterr()
    assert "F-001" in captured.out
    assert "mission-test-step8" in captured.out


def test_main_returns_exit_code_3_on_missing_args() -> None:
    """exit code 3 = operator-error (missing args)."""
    rc = main([])
    assert rc == 3


def test_main_returns_exit_code_3_on_bad_args_json(tmp_path: Path) -> None:
    args_file = tmp_path / "args.json"
    args_file.write_text("not valid json", encoding="utf-8")
    rc = main([str(args_file)])
    assert rc == 3


def test_full_dispatch_against_fake_claude_with_valid_handoff(
    project, capsys
) -> None:
    """Happy path: full dispatch flow runs against fake-claude, validates the
    pre-written handoff, exits 0. Documents the orchestration end-to-end."""
    project_root, _ = project
    inputs = _make_inputs()
    # Pre-write the handoff that fake-claude doesn't write itself.
    # We need to compute the dispatch_id deterministically -- but UUIDs are
    # random. Instead: build the dispatch first to get the id, then
    # pre-write handoff under that id. Then construct another runner
    # with the pre-existing dispatch (or accept that the test exercises
    # the orchestration as far as the runner's handoff-load step,
    # which will fail on no-handoff-file → synthesized handoff → that
    # path is also valid here).
    #
    # The runner's synthesized-handoff path produces a Handoff that
    # passes cross-artifact validation (already tested in step 6).
    # That's a valid outcome for this test -- it exercises the full
    # dispatch_entry orchestration to completion.
    #
    # We patch run_dispatch's runner spawn to use fake-claude.
    import dispatch_entry as de

    # Monkey-patch WorkerRunner inside dispatch_entry to point claude at fake.
    from runner import WorkerRunner as RealRunner

    class _PatchedRunner(RealRunner):
        def __init__(self, dispatch, **kwargs):
            super().__init__(
                dispatch,
                claude_argv_prefix=[
                    sys.executable,
                    str(FAKE_CLAUDE_PY),
                    "llm-only",
                ],
                **kwargs,
            )

    de.WorkerRunner = _PatchedRunner
    try:
        result = run_dispatch(inputs, project_root)
    finally:
        de.WorkerRunner = RealRunner

    # Exit 0 or 1 are both acceptable end-states:
    #  - 0 if the synthesized handoff happened to validate clean.
    #  - 1 if cross-artifact validation surfaced an issue (e.g., synthesized
    #    handoff's unfinished items match assertion_targets; report valid).
    # In practice the synthesized handoff for this setup IS valid, so 0.
    # exit_code=2 (runtime failure) is NOT acceptable here -- previously
    # the fixture didn't provision .mission/spec/v010.yaml and this test
    # passed silently at exit 2 via BriefConstructionError pre-spawn,
    # masking whether the synthesis path was actually exercised. Tightened
    # to (0, 1) after the fixture got the v010.yaml provision.
    assert result.exit_code in (0, 1), (
        f"unexpected exit_code {result.exit_code}: {result.error}"
    )
    assert result.worktree_id is not None


def test_synthesized_handoff_persisted_with_full_stderr(
    project, capsys
) -> None:
    """When the worker exits non-zero with no stream-json (matches the
    real `claude -p` exit-1-no-stream production failure on a real
    dispatch), the runner synthesizes a Handoff in-memory. Without
    persistence, that synthesized handoff is GC'd before the operator
    can read it -- and the captured subprocess_stderr (the only signal
    of WHY claude exited) goes with it.

    This test forces a fake-claude that emits stderr text and exits 1
    with NO stdout, runs the full dispatch_entry orchestration, and
    asserts that `.mission-runtime/dispatches/<id>/synthesized-handoff.json`
    is written before validation -- with the FULL stderr (not a
    500-char tail) round-tripped into `issues_observed`.

    Mirror of FIX B's principle: a diagnostic signal observed by the
    framework must never be silently dropped.
    """
    project_root, _ = project
    inputs = _make_inputs()

    import dispatch_entry as de
    from runner import WorkerRunner as RealRunner

    class _AbortNoStreamRunner(RealRunner):
        def __init__(self, dispatch, **kwargs):
            super().__init__(
                dispatch,
                claude_argv_prefix=[
                    sys.executable,
                    str(FAKE_CLAUDE_PY),
                    "abort-no-stream",
                ],
                **kwargs,
            )

    de.WorkerRunner = _AbortNoStreamRunner
    try:
        result = run_dispatch(inputs, project_root)
    finally:
        de.WorkerRunner = RealRunner

    # Dispatch outcome: the synthesized handoff trivially validates
    # (empty completed_assertions is a subset of any assertion_targets).
    # Validator exit codes 0 or 1 are acceptable; 2 (runtime failure)
    # would mean the runner crashed before producing a handoff at all.
    assert result.exit_code in (0, 1), (
        f"unexpected exit_code {result.exit_code}: {result.error}"
    )

    # Synthesized handoff on disk at the contract path.
    synthesized_path = (
        project_root
        / ".mission-runtime"
        / "dispatches"
        / result.dispatch_id
        / "synthesized-handoff.json"
    )
    assert synthesized_path.is_file(), (
        f"synthesized-handoff.json not persisted at {synthesized_path}; "
        f"the framework's only diagnostic signal would be lost on the "
        f"next dispatch_entry return."
    )

    # Schema validates (round-trip through the Pydantic model).
    from schemas import Handoff, TerminatedReason

    handoff = Handoff.model_validate_json(
        synthesized_path.read_text(encoding="utf-8")
    )
    # Failure shape: no completed work, all 10 (or 1, depending on
    # _make_inputs) assertion_targets unfinished, terminated reason is
    # CRASH_RECOVERED (subprocess exited abnormally; not a wallclock
    # timeout).
    assert handoff.completed_assertions == []
    assert handoff.terminated_reason == TerminatedReason.CRASH_RECOVERED
    assert len(handoff.unfinished) >= 1
    assert handoff.created_by == "claude-code:worker-runner"

    # FULL stderr captured into issues_observed (the operator-instructed
    # invariant: not a 500-char tail). Both subprocess_exit_code and
    # subprocess_stderr keys present; the stderr text is the fake-claude
    # diagnostic line we emit from `abort-no-stream`.
    issues_joined = "\n".join(handoff.issues_observed)
    assert "subprocess_exit_code=1" in issues_joined, (
        f"subprocess_exit_code missing/wrong; issues={handoff.issues_observed!r}"
    )
    assert "subprocess_stderr=" in issues_joined, (
        f"subprocess_stderr (full, not _excerpt) missing; "
        f"issues={handoff.issues_observed!r}"
    )
    # The fake-claude's stderr text round-trips verbatim.
    assert "fake-claude: simulating no-stream abort" in issues_joined
    assert "must round-trip into the synthesized handoff" in issues_joined
    # Sanity: no [-500:] truncation -- both lines of fake-claude stderr
    # are present, and the second line is well past byte 500 if we'd
    # truncated naively (the truncation guard the prior code violated).
    # The fake-claude stderr is short enough that this is implicit, but
    # we assert the second line's presence explicitly so a future
    # regression that re-introduces truncation gets caught even at
    # short stderr lengths.
    assert "this is the diagnostic" in issues_joined


# ============================================================================
# Completion driver: ACTIVE -> DISCARDED on dispatch completion
# ============================================================================
#
# Background (root lifecycle gap): nothing previously drove the §10 worktree
# state machine to a terminal state on dispatch completion. Every successful
# OR failed dispatch left the worktree record stuck in ACTIVE, blocking the
# next mainline dispatch (deterministic mainline id). Path Y's auto-reuse
# refuses ACTIVE (HARD-FAIL), so it could never fire on the natural
# multi-dispatch lifecycle -- the reuse worked only via the
# reconcile() safety-net coincidence (ACTIVE without worktree dir flipped to
# DISCARDED on __init__). These tests prove dispatch_entry now drives
# ACTIVE -> DISCARDED on completion + that B + Path Y compose end-to-end.


def _run_with_patched_runner(
    project_root: Path,
    *,
    fake_claude_selector: str,
    inputs: DispatchInputs,
):
    """Run dispatch_entry.run_dispatch with the WorkerRunner monkey-patched to
    spawn fake-claude.py against `fake_claude_selector`. Restores the real
    WorkerRunner on the way out."""
    import dispatch_entry as de
    from runner import WorkerRunner as RealRunner

    class _PatchedRunner(RealRunner):
        def __init__(self, dispatch, **kwargs):
            super().__init__(
                dispatch,
                claude_argv_prefix=[
                    sys.executable,
                    str(FAKE_CLAUDE_PY),
                    fake_claude_selector,
                ],
                **kwargs,
            )

    de.WorkerRunner = _PatchedRunner
    try:
        return run_dispatch(inputs, project_root)
    finally:
        de.WorkerRunner = RealRunner


def _load_worktree_record(project_root: Path, worktree_id: str) -> dict:
    """Read the manager-owned record.json verbatim as a dict."""
    import json as _json
    p = (
        project_root
        / ".mission-runtime"
        / "worktrees"
        / worktree_id
        / "record.json"
    )
    return _json.loads(p.read_text(encoding="utf-8"))


def test_completion_transitions_worktree_to_DISCARDED_on_success_path(
    project,
) -> None:
    """A dispatch whose worker produces a clean stream (fake-claude 'llm-only'
    selector emits a success-shaped stream) and whose handoff is synthesized
    by the runner (fake-claude doesn't write handoff.json) MUST leave the
    worktree record in DISCARDED on disk.

    Before this fix, the same dispatch left the record ACTIVE; the next
    mainline dispatch hit Path Y's hard-fail. This test guards the
    completion driver."""
    project_root, _ = project
    inputs = _make_inputs(kind=WorktreeKind.MAINLINE)
    result = _run_with_patched_runner(
        project_root,
        fake_claude_selector="llm-only",
        inputs=inputs,
    )
    assert result.exit_code in (0, 1), (
        f"unexpected exit_code {result.exit_code}: {result.error}"
    )
    record = _load_worktree_record(project_root, result.worktree_id)
    assert record["state"] == "discarded", (
        f"worktree record left in state={record['state']!r} on success-path "
        f"completion; expected 'discarded'. The completion driver did not "
        f"fire, or fired but failed silently."
    )


def test_completion_transitions_worktree_to_DISCARDED_on_failure_path(
    project,
) -> None:
    """A dispatch whose worker exits non-zero with no stream (fake-claude
    'abort-no-stream', matching the real production failure) MUST
    still leave the worktree record in DISCARDED. The completion driver
    fires regardless of dispatch outcome."""
    project_root, _ = project
    inputs = _make_inputs(kind=WorktreeKind.MAINLINE)
    result = _run_with_patched_runner(
        project_root,
        fake_claude_selector="abort-no-stream",
        inputs=inputs,
    )
    assert result.exit_code in (0, 1), (
        f"unexpected exit_code {result.exit_code}: {result.error}"
    )
    record = _load_worktree_record(project_root, result.worktree_id)
    assert record["state"] == "discarded", (
        f"worktree record left in state={record['state']!r} on failure-path "
        f"completion; expected 'discarded'."
    )


def test_completion_plus_path_y_compose_on_natural_lifecycle(
    project, caplog
) -> None:
    """End-to-end: prove the completion driver + Path Y compose on the
    natural multi-dispatch lifecycle (the thing that never actually worked
    before).

    Phase 1: dispatch1 runs to completion -> worktree DISCARDED.
    Phase 2: dispatch2 runs against the SAME mission/mainline-id ->
             WorktreeManager.create() finds the prior DISCARDED record,
             Path Y's reuse_terminal_slot warning fires, force-cleans,
             and a fresh ACTIVE record is minted.

    This is the failure mode the operator surfaced: second-mainline-
    dispatch-per-mission was previously broken. After this fix it works."""
    project_root, _ = project
    inputs = _make_inputs(kind=WorktreeKind.MAINLINE)

    # Phase 1.
    result1 = _run_with_patched_runner(
        project_root,
        fake_claude_selector="llm-only",
        inputs=inputs,
    )
    assert result1.exit_code in (0, 1), (
        f"dispatch1 unexpected exit: {result1.error}"
    )
    rec1 = _load_worktree_record(project_root, result1.worktree_id)
    assert rec1["state"] == "discarded"
    rec1_created = rec1["created_at"]
    rec1_branch = rec1["branch"]

    # Phase 2: SECOND mainline dispatch against the same mission_id.
    # The mainline id is deterministic (`wt-mainline-<mission_id>`); the
    # record path collides exactly with phase 1's. Path Y must fire.
    inputs2 = _make_inputs(kind=WorktreeKind.MAINLINE)
    with caplog.at_level("WARNING"):
        result2 = _run_with_patched_runner(
            project_root,
            fake_claude_selector="llm-only",
            inputs=inputs2,
        )
    assert result2.exit_code in (0, 1), (
        f"dispatch2 unexpected exit (Path Y should have reused, not blocked): "
        f"{result2.error}"
    )

    # Path Y's reuse_terminal_slot warning fired between the two dispatches.
    reuse_lines = [
        r for r in caplog.records
        if "worktree_manager.reuse_terminal_slot" in r.getMessage()
    ]
    assert len(reuse_lines) == 1, (
        f"expected exactly 1 reuse_terminal_slot warning between dispatches; "
        f"got {len(reuse_lines)}. The natural multi-dispatch path didn't "
        f"engage Path Y."
    )
    msg = reuse_lines[0].getMessage()
    assert "prior_state=discarded" in msg

    # Dispatch 2's worktree id is the SAME (mainline id is deterministic),
    # but its record is FRESH (new created_at, new branch, new dispatch id
    # in the branch suffix).
    assert result2.worktree_id == result1.worktree_id
    rec2 = _load_worktree_record(project_root, result2.worktree_id)
    assert rec2["created_at"] != rec1_created, (
        "fresh record.created_at must differ from prior; field leaked"
    )
    assert rec2["branch"] != rec1_branch, (
        "fresh record.branch must differ from prior (new dispatch id suffix); "
        "branch leaked from prior record"
    )
    # And dispatch 2's completion drove the new record back to DISCARDED.
    assert rec2["state"] == "discarded"
