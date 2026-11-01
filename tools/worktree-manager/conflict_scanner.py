"""
conflict_scanner.py -- file-level path overlap detection across active
worktrees.

Per the step-7 design (operator-approved 2026-05-30, question a answer):
file-level path overlap is sufficient at MVP fan-out (1-3 concurrent
workers per ADR-006 GPU gate). AST-level (symbol overlap) and
behavioral (test-impact analysis) scanners are deferred items; their
value emerges with higher concurrency post-MVP.

**Algorithm.** For each worktree:
  touched = {files modified-or-added since base_commit, committed OR uncommitted}

Two worktrees conflict iff the intersection of their touched-sets is
non-empty. Uncommitted scope includes:
  - staged-but-not-committed (`git status --porcelain` index column)
  - unstaged modifications (working-tree column)
  - untracked files (?? prefix)
  - renames: target side recorded; source side dropped (the new path
    is what could collide with another worktree's writes)

**Side effect.** scan_conflicts updates the target worktree's
record.conflict_set with the sorted list of conflicting worktree_ids,
matching §10's conflict_set semantics ("worktree ids currently in
conflict per the scanner").

**Deferred items** (flagged for future amendments when concurrency
grows):
- AST-level symbol-overlap detection (Python imports, class/function
  definitions touched in both worktrees).
- Behavioral test-impact analysis (which tests would each worktree's
  changes break; intersection of impact sets).
- Symlink / submodule handling (current scanner treats them as file
  paths; complex cases out of scope at MVP).
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from manager import WorktreeManager


def _files_touched_by_worktree(worktree_dir: Path, base_commit: str) -> set[str]:
    """All file paths modified or added since base_commit, including
    uncommitted changes (staged, unstaged, untracked)."""
    files: set[str] = set()

    # Committed changes since base_commit.
    r = subprocess.run(
        ["git", "diff", "--name-only", f"{base_commit}..HEAD"],
        cwd=str(worktree_dir),
        capture_output=True,
        text=True,
    )
    if r.returncode == 0:
        for line in r.stdout.splitlines():
            line = line.strip()
            if line:
                files.add(line)

    # Uncommitted changes via git status porcelain.
    r = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=str(worktree_dir),
        capture_output=True,
        text=True,
    )
    if r.returncode == 0:
        for line in r.stdout.splitlines():
            if len(line) < 4:
                continue
            # Porcelain format: XY <path> where X = index, Y = worktree.
            # Renames format as "R  old -> new"; we keep the new path.
            payload = line[3:].strip()
            if " -> " in payload:
                payload = payload.split(" -> ")[-1].strip()
            if payload:
                files.add(payload)

    return files


def scan_conflicts(manager: WorktreeManager, worktree_id: str) -> list[str]:
    """Detect file-level conflicts between this worktree and other active
    worktrees. Updates record.conflict_set as a side effect; returns the
    same sorted list.

    See module docstring for algorithm + uncommitted-scope semantics.
    """
    target = manager.get(worktree_id)
    target_files = _files_touched_by_worktree(
        Path(target.path), target.base_commit
    )

    conflicting: list[str] = []
    for other in manager.list_active():
        if other.id == worktree_id:
            continue
        other_files = _files_touched_by_worktree(
            Path(other.path), other.base_commit
        )
        if target_files & other_files:
            conflicting.append(other.id)

    conflicting.sort()
    record = manager._load_record(worktree_id)
    record.conflict_set = conflicting
    manager._save_record(record)
    return conflicting
