"""
Tests for conflict_scanner.scan_conflicts.

Coverage per the step-7 design (operator-approved 2026-05-30):
- Empty result when no overlap.
- Committed-file overlap detected.
- Uncommitted (modified) file overlap detected.
- Untracked file overlap detected.
- record.conflict_set updated as side effect (sorted).
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from uuid import uuid4

import pytest

from conflict_scanner import _files_touched_by_worktree, scan_conflicts
from manager import WorktreeManager
from schemas import (
    ModelClass,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
    WorktreeKind,
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
        ["git", "commit", "-m", "initial"],
        cwd=repo,
        check=True,
        capture_output=True,
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
        mission_id="mission-step7-conflict",
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


def _commit_in_worktree(worktree_dir: Path, file_name: str, content: str) -> None:
    (worktree_dir / file_name).write_text(content)
    subprocess.run(["git", "add", "."], cwd=worktree_dir, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", f"add {file_name}"],
        cwd=worktree_dir,
        check=True,
        capture_output=True,
    )


# ---------- ----------


def test_scan_returns_empty_when_no_overlap(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-A")
    d2 = _make_dispatch(worker_id="w-B")
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    _commit_in_worktree(Path(r1.path), "fileA.txt", "A")
    _commit_in_worktree(Path(r2.path), "fileB.txt", "B")
    assert scan_conflicts(mgr, r1.id) == []
    assert scan_conflicts(mgr, r2.id) == []


def test_scan_detects_committed_file_overlap(project) -> None:
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-A")
    d2 = _make_dispatch(worker_id="w-B")
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    _commit_in_worktree(Path(r1.path), "shared.txt", "from A")
    _commit_in_worktree(Path(r2.path), "shared.txt", "from B")
    conflicts_for_r1 = scan_conflicts(mgr, r1.id)
    assert conflicts_for_r1 == [r2.id]


def test_scan_detects_uncommitted_modified_file_overlap(project) -> None:
    """One worktree commits the file; another has an uncommitted change to it."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-A")
    d2 = _make_dispatch(worker_id="w-B")
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    _commit_in_worktree(Path(r1.path), "shared.txt", "from A")
    # r2 has an uncommitted modification to README.md; r1 also touches README.md.
    _commit_in_worktree(Path(r1.path), "README.md", "modified by A")
    (Path(r2.path) / "README.md").write_text("modified by B (uncommitted)")
    conflicts_for_r2 = scan_conflicts(mgr, r2.id)
    assert conflicts_for_r2 == [r1.id]


def test_scan_detects_untracked_file_overlap(project) -> None:
    """Both worktrees have untracked files with the same path."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-A")
    d2 = _make_dispatch(worker_id="w-B")
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    (Path(r1.path) / "untracked.txt").write_text("from A")
    (Path(r2.path) / "untracked.txt").write_text("from B")
    conflicts_for_r1 = scan_conflicts(mgr, r1.id)
    assert conflicts_for_r1 == [r2.id]


def test_scan_updates_record_conflict_set(project) -> None:
    """scan_conflicts updates the record.conflict_set field as a side
    effect (matches §10 conflict_set semantics)."""
    project_root, base = project
    mgr = WorktreeManager(project_root)
    d1 = _make_dispatch(worker_id="w-A")
    d2 = _make_dispatch(worker_id="w-B")
    d3 = _make_dispatch(worker_id="w-C")
    r1 = mgr.create(dispatch=d1, kind=WorktreeKind.FANOUT, base_commit=base)
    r2 = mgr.create(dispatch=d2, kind=WorktreeKind.FANOUT, base_commit=base)
    r3 = mgr.create(dispatch=d3, kind=WorktreeKind.FANOUT, base_commit=base)
    # r1 and r2 both touch shared.txt; r3 stays clean.
    _commit_in_worktree(Path(r1.path), "shared.txt", "A")
    _commit_in_worktree(Path(r2.path), "shared.txt", "B")

    scan_conflicts(mgr, r1.id)
    loaded = mgr._load_record(r1.id)
    assert loaded.conflict_set == [r2.id]
    assert r3.id not in loaded.conflict_set
