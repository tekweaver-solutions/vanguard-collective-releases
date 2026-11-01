"""
Tests for port_allocator.allocate_ports.

Coverage per the step-7 design (operator-approved 2026-05-30):
- allocate returns first free port in range
- allocate avoids ports held by other active worktrees
- allocate rejects unknown service
- allocate raises on exhausted range
- allocate persists to record.port_assignments
- ports released on cleanup (via dropping the record from list_active)
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from uuid import uuid4

import pytest

from manager import WorktreeManager
from port_allocator import _DEFAULT_PORT_RANGES, allocate_ports
from schemas import (
    ModelClass,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
    WorktreeKind,
    WorktreeState,
)


def _git_init(repo: Path) -> str:
    subprocess.run(["git", "init"], cwd=repo, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"], cwd=repo, check=True
    )
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
    (repo / "README.md").write_text("initial\n")
    subprocess.run(["git", "add", "."], cwd=repo, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "initial"], cwd=repo, check=True, capture_output=True
    )
    r = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    return r.stdout.strip()


def _make_dispatch(*, worker_id: str) -> WorkerDispatch:
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-05-30T00:00:00Z",
        created_by="claude-code:test",
        mission_id="mission-step7-port",
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
    p = tmp_path / "project"
    p.mkdir()
    head = _git_init(p)
    return p, head


# ----------


def test_allocate_returns_first_free_port_in_range(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    record = mgr.create(
        dispatch=_make_dispatch(worker_id="w-1"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    result = allocate_ports(mgr, record.id, ["web", "db"])
    assert result["web"] == _DEFAULT_PORT_RANGES["web"][0]  # 4100
    assert result["db"] == _DEFAULT_PORT_RANGES["db"][0]  # 5500


def test_allocate_avoids_ports_held_by_other_active_worktrees(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    r1 = mgr.create(
        dispatch=_make_dispatch(worker_id="w-1"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    r2 = mgr.create(
        dispatch=_make_dispatch(worker_id="w-2"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    allocate_ports(mgr, r1.id, ["web"])
    r2_result = allocate_ports(mgr, r2.id, ["web"])
    # r1 got 4100; r2 must get 4101.
    assert r2_result["web"] == _DEFAULT_PORT_RANGES["web"][0] + 1


def test_allocate_rejects_unknown_service(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    record = mgr.create(
        dispatch=_make_dispatch(worker_id="w-1"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    with pytest.raises(ValueError, match="Unknown service"):
        allocate_ports(mgr, record.id, ["definitely-not-a-service"])


def test_allocate_raises_on_exhausted_range(project) -> None:
    """Override with a tiny range so we can exhaust it in one allocation."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    r1 = mgr.create(
        dispatch=_make_dispatch(worker_id="w-1"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    r2 = mgr.create(
        dispatch=_make_dispatch(worker_id="w-2"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    # 1-port range; r1 takes it, r2 has nothing left.
    tiny = {"tiny": (45000, 45000)}
    allocate_ports(mgr, r1.id, ["tiny"], ranges=tiny)
    with pytest.raises(RuntimeError, match="Port range exhausted"):
        allocate_ports(mgr, r2.id, ["tiny"], ranges=tiny)


def test_allocate_persists_to_record(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    record = mgr.create(
        dispatch=_make_dispatch(worker_id="w-1"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    result = allocate_ports(mgr, record.id, ["web", "api"])
    loaded = mgr._load_record(record.id)
    assert loaded.port_assignments == result


def test_allocate_releases_ports_when_worktree_no_longer_active(project) -> None:
    """A worktree that's transitioned out of ACTIVE no longer reserves its
    ports; subsequent allocate calls can reuse those numbers."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    r1 = mgr.create(
        dispatch=_make_dispatch(worker_id="w-1"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    allocate_ports(mgr, r1.id, ["web"])
    # Transition r1 out of ACTIVE.
    mgr.transition_state(r1.id, WorktreeState.DISCARDED)
    r2 = mgr.create(
        dispatch=_make_dispatch(worker_id="w-2"),
        kind=WorktreeKind.FANOUT,
        base_commit=base,
    )
    r2_result = allocate_ports(mgr, r2.id, ["web"])
    # r1's port now free; r2 gets the first port in the range.
    assert r2_result["web"] == _DEFAULT_PORT_RANGES["web"][0]
