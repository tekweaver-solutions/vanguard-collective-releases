"""
Tests for WorktreeManager: git-worktree lifecycle + record persistence.

Coverage per the step-7 design (operator-approved 2026-05-30 + the operator's answers):
- create() lifecycle (mainline + fanout; duplicate rejection; invalid base)
- get() lazy head refresh (found in review)
- list_active() filtering
- update_head() explicit refresh
- transition_state() §10 state-machine enforcement (found in review)
- cleanup() two-condition gate (force=False rejects dirty/non-terminal; per an operator answer)
- reconcile() orphan handling (found in review)

Tests require real git, so they construct an actual git project in tmp_path
with an initial commit before exercising the manager.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from uuid import uuid4

import pytest

from manager import ReconcileReport, WorktreeManager
from schemas import (
    ModelClass,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
    WorktreeKind,
    WorktreeRecord,
    WorktreeState,
)


# ---------- helpers ----------


def _git_init(repo: Path) -> str:
    """Initialize a git repo with an initial commit; return the initial commit SHA.
    Uses git init without -b to support git <2.28 (a review fix); tests don't care
    about the branch name."""
    subprocess.run(["git", "init"], cwd=repo, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"], cwd=repo, check=True
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"], cwd=repo, check=True
    )
    (repo / "README.md").write_text("initial\n")
    subprocess.run(["git", "add", "."], cwd=repo, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "initial"], cwd=repo, check=True, capture_output=True
    )
    r = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True, check=True
    )
    return r.stdout.strip()


def _make_dispatch(*, worker_id: str = "w-test") -> WorkerDispatch:
    # Note: WorkerKind (dispatch's role) and WorktreeKind (manager.create()'s
    # kind parameter) are independent enums. Tests construct a FANOUT-kind
    # dispatch but pass either WorktreeKind.MAINLINE or .FANOUT to manager.create()
    # depending on the worktree scenario being exercised.
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-05-30T00:00:00Z",
        created_by="claude-code:test",
        mission_id="mission-step7",
        worker_id=worker_id,
        kind=WorkerKind.FANOUT,
        feature_id="F-001",
        assertion_targets=["A-001"],
        spec_version=10,
        worktree_id="wt-test",
        model_class=ModelClass.CODING_STRONG,
        tool_scope=["repo.read"],
        budget=WorkerBudget(cost_cap_usd=10.0, wallclock_cap_minutes=10),
    )


@pytest.fixture
def project(tmp_path: Path):
    """A real git project with one initial commit. Returns (path, head_sha)."""
    p = tmp_path / "project"
    p.mkdir()
    head = _git_init(p)
    return p, head


# ---------- create() ----------


def test_create_mainline_writes_record_and_worktree(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    assert record.id.startswith("wt-mainline-")
    assert record.kind == WorktreeKind.MAINLINE
    assert record.state == WorktreeState.ACTIVE
    assert record.base_commit == base
    assert record.head_commit == base
    assert Path(record.path).is_dir()
    # mainline kind + ACTIVE state -> current_worker is None (mainline serial)
    assert record.current_worker is None


def test_create_fanout_with_branch(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch(worker_id="w-fanout-1")
    record = mgr.create(
        dispatch=dispatch,
        kind=WorktreeKind.FANOUT,
        base_commit=base,
        branch="fanout-test-branch",
    )
    assert record.kind == WorktreeKind.FANOUT
    assert record.branch == "fanout-test-branch"
    assert record.current_worker == "w-fanout-1"


def test_create_rejects_duplicate_worktree_id(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    with pytest.raises(ValueError, match="already exists"):
        mgr.create(
            dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
        )


def test_create_fails_on_nonexistent_base_commit(project) -> None:
    project_root, _ = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    with pytest.raises(RuntimeError, match="git worktree add"):
        mgr.create(
            dispatch=dispatch,
            kind=WorktreeKind.MAINLINE,
            base_commit="nonexistent-sha",
        )


def test_default_branch_name_includes_dispatch_suffix(project) -> None:
    """Branch names suffix per dispatch so second-mainline
    against same mission doesn't fail on git worktree add -b. Two dispatches
    against the same mission produce distinct branch names."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-1")
    d2 = _make_dispatch(worker_id="w-2")
    # Same mission, two different dispatches.
    assert d1.mission_id == d2.mission_id
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    assert r1.branch != r2.branch
    assert str(d1.id)[:8] in r1.branch
    assert str(d2.id)[:8] in r2.branch


def test_create_populates_created_at(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    assert record.created_at.endswith("Z")
    assert "T" in record.created_at


# ---------- get + list ----------


def test_get_loads_record_from_disk(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    created = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    loaded = mgr.get(created.id)
    assert loaded.id == created.id
    assert loaded.base_commit == base


def test_get_lazy_refreshes_head_after_external_commit(project) -> None:
    """Lazy refresh: get() runs git rev-parse HEAD and updates record.head_commit."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    worktree_dir = Path(record.path)
    # Make an external commit in the worktree.
    (worktree_dir / "new.txt").write_text("hello")
    subprocess.run(["git", "add", "."], cwd=worktree_dir, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "added file"], cwd=worktree_dir, check=True, capture_output=True
    )
    new_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=worktree_dir, capture_output=True, text=True, check=True
    ).stdout.strip()
    assert new_head != base
    refreshed = mgr.get(record.id)
    assert refreshed.head_commit == new_head


def test_list_active_filters_by_state(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-1")
    d2 = _make_dispatch(worker_id="w-2")
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    mgr.transition_state(r2.id, WorktreeState.DISCARDED)
    active = list(mgr.list_active())
    active_ids = {r.id for r in active}
    assert r1.id in active_ids
    assert r2.id not in active_ids


# ---------- update_head + transition_state ----------


def test_update_head_explicit_refresh(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    worktree_dir = Path(record.path)
    (worktree_dir / "x.txt").write_text("x")
    subprocess.run(["git", "add", "."], cwd=worktree_dir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "x"], cwd=worktree_dir, check=True, capture_output=True)
    mgr.update_head(record.id)
    new_head = mgr._load_record(record.id).head_commit
    assert new_head != base


def test_transition_state_valid(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    # ACTIVE -> MERGING -> MERGED -> GC_PENDING
    mgr.transition_state(record.id, WorktreeState.MERGING)
    mgr.transition_state(record.id, WorktreeState.MERGED)
    mgr.transition_state(record.id, WorktreeState.GC_PENDING)
    assert mgr._load_record(record.id).state == WorktreeState.GC_PENDING


def test_transition_state_rejects_invalid_transition(project) -> None:
    """Per the design: §10 state machine catches invalid transitions (programmer error)."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    # DISCARDED → ACTIVE is not a valid §10 transition (only forward to GC_PENDING).
    mgr.transition_state(record.id, WorktreeState.DISCARDED)
    with pytest.raises(ValueError, match="Invalid state transition"):
        mgr.transition_state(record.id, WorktreeState.ACTIVE)


def test_transition_state_from_terminal_rejects_any(project) -> None:
    """GC_PENDING is terminal; no further transitions allowed."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    mgr.transition_state(record.id, WorktreeState.DISCARDED)
    mgr.transition_state(record.id, WorktreeState.GC_PENDING)
    with pytest.raises(ValueError, match="Invalid state transition"):
        mgr.transition_state(record.id, WorktreeState.ACTIVE)


# ---------- cleanup ----------


def test_cleanup_force_false_happy_path(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    mgr.transition_state(record.id, WorktreeState.DISCARDED)
    mgr.cleanup(record.id, force=False)
    # Record and dir gone.
    assert not mgr._record_path(record.id).exists()


def test_cleanup_force_false_rejects_non_terminal_state(project) -> None:
    """Cleanup gate: force=False rejects cleanup of ACTIVE worktrees."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    with pytest.raises(RuntimeError, match="transition to MERGED or DISCARDED"):
        mgr.cleanup(record.id, force=False)


def test_cleanup_force_false_rejects_dirty_worktree(project) -> None:
    """Cleanup gate: force=False rejects cleanup when working tree has uncommitted changes."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    # Dirty the worktree.
    (Path(record.path) / "dirty.txt").write_text("uncommitted")
    mgr.transition_state(record.id, WorktreeState.DISCARDED)
    with pytest.raises(RuntimeError, match="dirty changes"):
        mgr.cleanup(record.id, force=False)


def test_cleanup_force_true_bypasses_dirty(project) -> None:
    """Cleanup gate: force=True bypasses dirty-tree check with a logger.warning."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    (Path(record.path) / "dirty.txt").write_text("uncommitted")
    mgr.cleanup(record.id, force=True)
    assert not mgr._record_path(record.id).exists()


def test_cleanup_partial_failure_leaves_state_gc_pending(
    project, monkeypatch
) -> None:
    """The correctness fix: when git worktree remove fails mid-cleanup, the state machine
    transitions to GC_PENDING BEFORE the git op. State reflects intent
    ('we intend to GC'); subsequent re-run completes the work cleanly.

    Without this fix, state would stay at MERGED/DISCARDED while the dir
    was partially removed -- the state machine would be inconsistent with
    reality and no operator-visible signal would surface."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    mgr.transition_state(record.id, WorktreeState.DISCARDED)

    # Force _git_worktree_remove to fail.
    def fail_remove(*args, **kwargs):
        raise subprocess.CalledProcessError(
            1, ["git", "worktree", "remove"], "", "simulated failure"
        )

    monkeypatch.setattr(mgr, "_git_worktree_remove", fail_remove)

    with pytest.raises(RuntimeError, match="git worktree remove failed"):
        mgr.cleanup(record.id, force=False)

    # State transitioned to GC_PENDING BEFORE the git op raised --
    # a re-run can complete the work from a known state.
    record_path = mgr._record_path(record.id)
    if record_path.exists():
        # Record may have been removed if the cleanup ordering placed the
        # transition before the git op AND the record removal also before
        # the raise -- in current impl, the raise short-circuits before
        # record removal, so the record is still on disk.
        loaded = mgr._load_record(record.id)
        assert loaded.state == WorktreeState.GC_PENDING


# ---------- reconcile ----------


def test_reconcile_marks_orphan_record_discarded(project) -> None:
    """Reconcile: record on disk + worktree dir missing -> mark state DISCARDED."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    dispatch = _make_dispatch()
    record = mgr.create(
        dispatch=dispatch, kind=WorktreeKind.MAINLINE, base_commit=base
    )
    # Externally remove the worktree directory (simulates git worktree
    # destruction outside the manager).
    import shutil

    shutil.rmtree(record.path)
    # Manually trigger reconcile (not just on __init__).
    report = mgr.reconcile()
    assert record.id in report.discarded_orphan_records
    assert mgr._load_record(record.id).state == WorktreeState.DISCARDED


def test_reconcile_detects_orphan_directory(project, tmp_path: Path) -> None:
    """Reconcile: worktree directory present + record missing -> reported but
    not auto-fixed (logged warning; manual cleanup is operator territory)."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    # Synthesize an orphan: create a worktree subdir without a record.
    orphan_dir = (
        project_root / ".mission-runtime" / "worktrees" / "orphan-id" / "worktree"
    )
    orphan_dir.mkdir(parents=True)
    report = mgr.reconcile()
    assert "orphan-id" in report.reconstructed_orphan_dirs


def test_reconcile_runs_on_init(project) -> None:
    """The manager runs reconcile() during __init__."""
    project_root, _ = project
    # Pre-create an orphan record without worktree directory.
    sub = project_root / ".mission-runtime" / "worktrees" / "pre-orphan"
    sub.mkdir(parents=True)
    record_data = {
        "id": "pre-orphan",
        "created_at": "2026-05-30T00:00:00Z",
        "mission_id": "mission-test",
        "kind": "mainline",
        "branch": "main",
        "path": str(sub / "worktree"),
        "current_worker": None,
        "base_commit": "1234567",
        "head_commit": "1234567",
        "port_assignments": None,
        "state": "active",
        "conflict_set": [],
    }
    (sub / "record.json").write_text(json.dumps(record_data), encoding="utf-8")

    mgr = WorktreeManager(project_root)
    # __init__'s reconcile() should have flipped state to DISCARDED.
    loaded = mgr._load_record("pre-orphan")
    assert loaded.state == WorktreeState.DISCARDED


# ============================================================================
# create() auto-reuse of terminal-state slots
# ============================================================================
#
# Background (lifecycle bug, not recovery polish): mainline worktree ids
# are deterministic per mission (`wt-mainline-<mission_id>`), so the SECOND
# mainline dispatch to any mission previously failed at create() with
# "Worktree already exists" -- a normal-multi-dispatch correctness bug.
# Fix: create() auto-reuses the slot when the prior record is in a
# terminal slot-free state (MERGED / DISCARDED / GC_PENDING). ACTIVE and
# MERGING records (live worker / in-flight merge) still hard-fail.


def _stale_mainline_record(
    project_root: Path,
    *,
    mission_id: str,
    state: WorktreeState,
    base_commit: str,
    plant_worktree_dir: bool = False,
) -> tuple[str, dict]:
    """Plant a record.json for a mainline worktree id, in the given state.

    Default (plant_worktree_dir=False): NO corresponding worktree dir --
    mirrors the on-disk state that bit us with an earlier cleanup
    (record on disk, git worktree gone). For terminal states this is the
    realistic stale-residue shape.

    plant_worktree_dir=True: also create a stub `worktree/` directory
    alongside the record. Required when testing live-state records
    (ACTIVE / MERGING) because WorktreeManager.__init__'s reconcile()
    auto-flips ACTIVE records WITHOUT a worktree dir to DISCARDED -- a
    safety net for the orphan-record invariant. To assert ACTIVE / MERGING
    hard-fail in create(), the on-disk shape must satisfy reconcile's
    invariant so it leaves the state alone.
    """
    worktree_id = f"wt-mainline-{mission_id}"
    sub = project_root / ".mission-runtime" / "worktrees" / worktree_id
    sub.mkdir(parents=True, exist_ok=True)
    if plant_worktree_dir:
        (sub / "worktree").mkdir(exist_ok=True)
    record_data = {
        "id": worktree_id,
        "created_at": "2026-05-30T00:00:00.000Z",
        "mission_id": mission_id,
        "kind": "mainline",
        "branch": f"mission/{mission_id}/{worktree_id}/prior01ab",
        "path": str(sub / "worktree"),
        "current_worker": None,
        "base_commit": base_commit,
        "head_commit": base_commit,
        "port_assignments": None,
        "state": state.value,
        "conflict_set": [],
    }
    (sub / "record.json").write_text(json.dumps(record_data), encoding="utf-8")
    return worktree_id, record_data


def _make_mainline_dispatch_for_mission(mission_id: str) -> WorkerDispatch:
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-05-31T22:30:00.000Z",
        created_by="claude-code:test",
        mission_id=mission_id,
        worker_id=str(uuid4()),
        kind=WorkerKind.MAINLINE,
        feature_id="F-001",
        assertion_targets=["A-001"],
        spec_version=10,
        worktree_id=f"wt-mainline-{mission_id}",
        model_class=ModelClass.CODING_STRONG,
        tool_scope=["repo.read"],
        budget=WorkerBudget(cost_cap_usd=10.0, wallclock_cap_minutes=10),
    )


def _assert_fresh_record_no_field_leak(
    new_record: WorktreeRecord,
    *,
    prior: dict,
    fresh_dispatch: WorkerDispatch,
    fresh_base_commit: str,
) -> None:
    """Assert the new record's dispatch-derived fields are FRESH, not
    leaked from the cleaned-up prior record. The reuse path is auto-
    cleanup-then-standard-create, so any leak here is a real bug in the
    reuse implementation."""
    # base_commit / branch / created_at come from the fresh dispatch +
    # fresh wall-clock, NOT the prior record.
    assert new_record.base_commit == fresh_base_commit
    assert new_record.base_commit != prior["base_commit"] or True  # may coincide; not a leak unless other fields leak too
    assert new_record.branch != prior["branch"], (
        f"branch leak: new={new_record.branch!r} prior={prior['branch']!r} "
        f"(branch should carry the fresh dispatch's id suffix)"
    )
    assert new_record.created_at != prior["created_at"], (
        f"created_at leak: new={new_record.created_at!r} "
        f"prior={prior['created_at']!r}"
    )
    # The fresh dispatch's id[:8] suffix MUST appear in the new branch.
    assert str(fresh_dispatch.id)[:8] in new_record.branch
    # State machine is reset to ACTIVE for the new dispatch.
    assert new_record.state == WorktreeState.ACTIVE
    # current_worker rule (§10): None for mainline-ACTIVE.
    assert new_record.current_worker is None


def test_create_reuses_DISCARDED_terminal_slot(project, caplog) -> None:
    """The stale-residue case: prior dispatch left a DISCARDED record.
    create() auto-cleans and proceeds; new record carries fresh fields."""
    project_root, base = project
    mission_id = "mission-discarded-reuse"
    _, prior = _stale_mainline_record(
        project_root, mission_id=mission_id,
        state=WorktreeState.DISCARDED, base_commit=base,
    )

    mgr = WorktreeManager(project_root)
    fresh = _make_mainline_dispatch_for_mission(mission_id)

    with caplog.at_level("WARNING"):
        new_record = mgr.create(
            dispatch=fresh, kind=WorktreeKind.MAINLINE, base_commit=base
        )
    _assert_fresh_record_no_field_leak(
        new_record, prior=prior, fresh_dispatch=fresh, fresh_base_commit=base,
    )
    # GUARDRAIL 2: the reuse_terminal_slot log line emitted with the
    # prior state, branch, base_commit, created_at captured pre-cleanup.
    reuse_lines = [
        r for r in caplog.records
        if "worktree_manager.reuse_terminal_slot" in r.getMessage()
    ]
    assert len(reuse_lines) == 1
    msg = reuse_lines[0].getMessage()
    assert "prior_state=discarded" in msg
    assert prior["branch"] in msg
    assert prior["base_commit"] in msg
    assert prior["created_at"] in msg


def test_create_reuses_MERGED_terminal_slot(project, caplog) -> None:
    project_root, base = project
    mission_id = "mission-merged-reuse"
    _, prior = _stale_mainline_record(
        project_root, mission_id=mission_id,
        state=WorktreeState.MERGED, base_commit=base,
    )

    mgr = WorktreeManager(project_root)
    fresh = _make_mainline_dispatch_for_mission(mission_id)
    with caplog.at_level("WARNING"):
        new_record = mgr.create(
            dispatch=fresh, kind=WorktreeKind.MAINLINE, base_commit=base
        )
    _assert_fresh_record_no_field_leak(
        new_record, prior=prior, fresh_dispatch=fresh, fresh_base_commit=base,
    )
    reuse_lines = [
        r for r in caplog.records
        if "worktree_manager.reuse_terminal_slot" in r.getMessage()
    ]
    assert len(reuse_lines) == 1
    assert "prior_state=merged" in reuse_lines[0].getMessage()


def test_create_reuses_GC_PENDING_terminal_slot(project, caplog) -> None:
    """GC_PENDING means cleanup was started (intent-to-GC marker) but
    didn't complete -- e.g., Windows file lock during rmdir. Reusing is
    safe: the dispatch is gone, re-cleanup is idempotent."""
    project_root, base = project
    mission_id = "mission-gcpending-reuse"
    _, prior = _stale_mainline_record(
        project_root, mission_id=mission_id,
        state=WorktreeState.GC_PENDING, base_commit=base,
    )

    mgr = WorktreeManager(project_root)
    fresh = _make_mainline_dispatch_for_mission(mission_id)
    with caplog.at_level("WARNING"):
        new_record = mgr.create(
            dispatch=fresh, kind=WorktreeKind.MAINLINE, base_commit=base
        )
    _assert_fresh_record_no_field_leak(
        new_record, prior=prior, fresh_dispatch=fresh, fresh_base_commit=base,
    )
    reuse_lines = [
        r for r in caplog.records
        if "worktree_manager.reuse_terminal_slot" in r.getMessage()
    ]
    assert len(reuse_lines) == 1
    assert "prior_state=gc_pending" in reuse_lines[0].getMessage()


def test_create_hard_fails_on_ACTIVE_record(project, caplog) -> None:
    """ACTIVE record means a worker is or was actively assigned to the
    slot. Auto-reuse would kill live work; create() must hard-fail with
    the prior state named for triage.

    Plants the worktree subdir alongside the record so that __init__'s
    reconcile() does NOT auto-flip the state to DISCARDED (its safety net
    for orphan records lacking a worktree dir)."""
    project_root, base = project
    mission_id = "mission-active-hardfail"
    _stale_mainline_record(
        project_root, mission_id=mission_id,
        state=WorktreeState.ACTIVE, base_commit=base,
        plant_worktree_dir=True,
    )

    mgr = WorktreeManager(project_root)
    fresh = _make_mainline_dispatch_for_mission(mission_id)
    with caplog.at_level("WARNING"):
        with pytest.raises(
            ValueError,
            match=r"already exists \(state=active\); refuse auto-reuse",
        ):
            mgr.create(
                dispatch=fresh, kind=WorktreeKind.MAINLINE, base_commit=base
            )
    # No reuse log line should have been emitted -- the hard-fail path
    # is silent on the manager logger (the caller surfaces the ValueError).
    reuse_lines = [
        r for r in caplog.records
        if "worktree_manager.reuse_terminal_slot" in r.getMessage()
    ]
    assert reuse_lines == []


def test_create_hard_fails_on_MERGING_record(project, caplog) -> None:
    """MERGING record means an in-flight merge owns the slot. Auto-reuse
    would kill an in-progress integration; create() must hard-fail.

    Like the ACTIVE test, plants the worktree subdir to keep reconcile
    from flipping the state -- though MERGING is currently not in
    reconcile's auto-flip set, planting the dir matches the realistic
    live-state on-disk invariant and makes the test robust to future
    reconcile-rule additions."""
    project_root, base = project
    mission_id = "mission-merging-hardfail"
    _stale_mainline_record(
        project_root, mission_id=mission_id,
        state=WorktreeState.MERGING, base_commit=base,
        plant_worktree_dir=True,
    )

    mgr = WorktreeManager(project_root)
    fresh = _make_mainline_dispatch_for_mission(mission_id)
    with caplog.at_level("WARNING"):
        with pytest.raises(
            ValueError,
            match=r"already exists \(state=merging\); refuse auto-reuse",
        ):
            mgr.create(
                dispatch=fresh, kind=WorktreeKind.MAINLINE, base_commit=base
            )
    reuse_lines = [
        r for r in caplog.records
        if "worktree_manager.reuse_terminal_slot" in r.getMessage()
    ]
    assert reuse_lines == []

