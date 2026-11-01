"""
manager.py -- WorktreeManager: git-worktree lifecycle + record persistence.

Per the step-7 design (operator-approved 2026-05-30):

Storage layout (one directory per worktree):
  <project_root>/.mission-runtime/worktrees/<worktree_id>/
    record.json    -- WorktreeRecord serialized per §10 schema
    worktree/      -- the actual git worktree directory

The record-lives-with-the-worktree layout means cleanup removes both
atomically -- no orphaned-record problem (operator's unsaid benefit
noted at plan review).

**Concurrency model (MVP).** The manager assumes operator-foreground-
serial invocation: mission-dispatch.ps1 (step 8) invokes the manager
once per operator command. There is no parallel dispatcher at MVP per
ADR-006's GPU gate (1-3 concurrent workers). File-locked registry for
true-parallel dispatcher invocation is a documented deferred item.

**§10 state machine.** transitions enforced via _VALID_TRANSITIONS
(an operator answer): active -> merging -> merged | active -> discarded |
merging -> active (rollback) | merged|discarded -> gc_pending |
gc_pending = terminal. Invalid transitions raise ValueError.

**Lazy head refresh.** get(worktree_id) runs `git rev-parse HEAD` in
the worktree and updates record.head_commit before returning (operator
lazy-refresh decision). update_head() remains as an explicit-refresh
API for edge cases (force-push, worktree-external manipulation).

**cleanup two-condition gate** (an operator answer):
- force=False rejects on: state not in {MERGED, DISCARDED} OR working
  tree dirty (git status --porcelain non-empty).
- force=True bypasses both with a logger.warning.

**reconcile() startup pass** (an operator answer): on __init__, walks the
worktrees directory and handles two orphan cases:
- Record on disk + worktree directory missing -> mark state DISCARDED.
- Worktree directory present + record missing -> log warning; manual
  cleanup is the operator's responsibility.
Also exposed as a standalone manager method for the future
`mission worktrees reconcile` CLI (step 8 territory).

**Deferred items flagged for the ledger when implementation lands:**
- Operator-config for port ranges (port_allocator.py).
- File-locked registry for true-parallel dispatcher invocation.
- update_head() explicit-refresh use cases beyond the lazy default.
- AST/behavioral conflict scanners (conflict_scanner.py).
"""

from __future__ import annotations

import json
import logging
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator, Optional

# Cross-dir framework imports (schemas live in worker-runner).
_WORKER_RUNNER = str(Path(__file__).parent.parent / "worker-runner")
if _WORKER_RUNNER not in sys.path:
    sys.path.insert(0, _WORKER_RUNNER)
from schemas import (  # noqa: E402
    WorkerDispatch,
    WorktreeKind,
    WorktreeRecord,
    WorktreeState,
)

logger = logging.getLogger(__name__)


# §10 state machine. Empty frozenset = terminal state.
_VALID_TRANSITIONS: dict[WorktreeState, frozenset[WorktreeState]] = {
    WorktreeState.ACTIVE: frozenset(
        {WorktreeState.MERGING, WorktreeState.DISCARDED}
    ),
    WorktreeState.MERGING: frozenset(
        {WorktreeState.MERGED, WorktreeState.ACTIVE}  # ACTIVE = rollback
    ),
    WorktreeState.MERGED: frozenset({WorktreeState.GC_PENDING}),
    WorktreeState.DISCARDED: frozenset({WorktreeState.GC_PENDING}),
    WorktreeState.GC_PENDING: frozenset(),
}

# Implicit-recovery set for `create()`: when a record already exists in one
# of these states, the slot is functionally free (no worker, no in-flight
# state-machine operation) and create() force-cleans the residue then
# proceeds. Deliberately narrower than `cleanup(force=True)`'s operator-
# explicit acceptance (which accepts any state). The auto-reuse must NEVER
# clean an ACTIVE slot (a live worker may be writing) or a MERGING slot (a
# merge is in flight). See `create()` for the reuse logging signature.
_TERMINAL_REUSABLE_STATES: frozenset[WorktreeState] = frozenset(
    {
        WorktreeState.MERGED,
        WorktreeState.DISCARDED,
        WorktreeState.GC_PENDING,
    }
)


@dataclass(frozen=True)
class ReconcileReport:
    """Summary of reconcile() pass. Immutable per framework convention."""

    discarded_orphan_records: tuple[str, ...]
    reconstructed_orphan_dirs: tuple[str, ...]


def _now_iso() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


class WorktreeManager:
    """Git-worktree lifecycle + record persistence. See module docstring."""

    def __init__(self, project_root: Path, *, run_reconcile: bool = True) -> None:
        if not project_root.is_dir():
            raise RuntimeError(f"project_root is not a directory: {project_root}")
        self._project_root = project_root.resolve()
        self._worktrees_root = (
            self._project_root / ".mission-runtime" / "worktrees"
        )
        self._worktrees_root.mkdir(parents=True, exist_ok=True)
        if run_reconcile:
            self.reconcile()

    # --- Path helpers ---

    def _worktree_subdir(self, worktree_id: str) -> Path:
        return self._worktrees_root / worktree_id

    def _record_path(self, worktree_id: str) -> Path:
        return self._worktree_subdir(worktree_id) / "record.json"

    def _worktree_dir(self, worktree_id: str) -> Path:
        return self._worktree_subdir(worktree_id) / "worktree"

    # --- Lifecycle ---

    def create(
        self,
        *,
        dispatch: WorkerDispatch,
        kind: WorktreeKind,
        base_commit: str,
        branch: Optional[str] = None,
    ) -> WorktreeRecord:
        worktree_id = self._mint_worktree_id(dispatch, kind)
        if self._record_path(worktree_id).exists():
            # Mainline ids are deterministic (`wt-mainline-<mission_id>`),
            # so EVERY second-and-subsequent mainline dispatch per mission
            # hits this branch on the normal multi-dispatch path -- it's a
            # correctness bug, not just a recovery edge case. When the
            # prior record is in a terminal slot-free state (no worker, no
            # in-flight op), force-clean the residue and proceed. When the
            # prior record is ACTIVE or MERGING, hard-fail naming the
            # state so the operator can triage instead of stepping on a
            # live slot.
            try:
                existing = self._load_record(worktree_id)
            except (json.JSONDecodeError, ValueError) as parse_err:
                raise ValueError(
                    f"Worktree {worktree_id!r} record exists but cannot "
                    f"be parsed: {parse_err}. Manual cleanup required."
                ) from parse_err
            if existing.state in _TERMINAL_REUSABLE_STATES:
                # GUARDRAIL 2: capture prior-record fields BEFORE cleanup
                # so they survive into the log even though cleanup unlinks
                # the record file. Two grep-able marks land in logs for
                # any reused slot: this "reuse_terminal_slot" decision +
                # the cleanup's own "force=True bypassing checks"
                # execution-side line.
                logger.warning(
                    "worktree_manager.reuse_terminal_slot: "
                    "worktree_id=%s prior_state=%s prior_branch=%s "
                    "prior_base_commit=%s prior_created_at=%s",
                    worktree_id,
                    existing.state.value,
                    existing.branch,
                    existing.base_commit,
                    existing.created_at,
                )
                self.cleanup(worktree_id, force=True)
                # After cleanup the record file is gone; fall through to
                # the standard create path below. The new record will
                # carry fresh dispatch-derived fields -- no leak from the
                # old record (covered by test assertions).
            else:
                raise ValueError(
                    f"Worktree {worktree_id!r} already exists "
                    f"(state={existing.state.value}); refuse auto-reuse "
                    f"on live/in-flight slot."
                )

        worktree_dir = self._worktree_dir(worktree_id)
        worktree_dir.parent.mkdir(parents=True, exist_ok=True)

        branch_name = branch or self._default_branch_name(dispatch, worktree_id)
        self._git_worktree_add(worktree_dir, branch_name, base_commit)

        head_commit = self._git_rev_parse_head(worktree_dir)
        record = WorktreeRecord(
            id=worktree_id,
            created_at=_now_iso(),
            mission_id=dispatch.mission_id,
            kind=kind,
            branch=branch_name,
            path=str(worktree_dir),
            current_worker=(
                dispatch.worker_id if kind == WorktreeKind.FANOUT else None
            ),
            base_commit=base_commit,
            head_commit=head_commit,
            port_assignments=None,
            state=WorktreeState.ACTIVE,
            conflict_set=[],
        )
        self._save_record(record)
        return record

    def get(self, worktree_id: str) -> WorktreeRecord:
        record = self._load_record(worktree_id)
        # Lazy head refresh (found in review).
        worktree_dir = self._worktree_dir(worktree_id)
        if worktree_dir.is_dir():
            try:
                current_head = self._git_rev_parse_head(worktree_dir)
                if current_head and current_head != record.head_commit:
                    record.head_commit = current_head
                    self._save_record(record)
            except (subprocess.CalledProcessError, FileNotFoundError):
                pass  # worktree git failed; return record without refresh
        return record

    def list_active(self) -> Iterator[WorktreeRecord]:
        for record_path in sorted(self._worktrees_root.glob("*/record.json")):
            try:
                record = WorktreeRecord.model_validate_json(
                    record_path.read_text(encoding="utf-8")
                )
            except (json.JSONDecodeError, ValueError):
                continue
            if record.state == WorktreeState.ACTIVE:
                yield record

    def update_head(self, worktree_id: str) -> None:
        record = self._load_record(worktree_id)
        record.head_commit = self._git_rev_parse_head(
            self._worktree_dir(worktree_id)
        )
        self._save_record(record)

    def transition_state(
        self, worktree_id: str, new_state: WorktreeState
    ) -> None:
        record = self._load_record(worktree_id)
        allowed = _VALID_TRANSITIONS.get(record.state, frozenset())
        if new_state not in allowed:
            raise ValueError(
                f"Invalid state transition for worktree {worktree_id!r}: "
                f"{record.state.value} -> {new_state.value}. "
                f"Valid transitions from {record.state.value}: "
                f"{sorted(s.value for s in allowed)}"
            )
        record.state = new_state
        self._save_record(record)

    def cleanup(self, worktree_id: str, *, force: bool = False) -> None:
        record = self._load_record(worktree_id)
        worktree_dir = self._worktree_dir(worktree_id)

        if not force:
            if record.state not in (
                WorktreeState.MERGED,
                WorktreeState.DISCARDED,
            ):
                raise RuntimeError(
                    f"Cannot cleanup worktree {worktree_id!r} in state "
                    f"{record.state.value}; transition to MERGED or DISCARDED "
                    f"first, or pass force=True."
                )
            if worktree_dir.is_dir():
                dirty = self._git_status_porcelain(worktree_dir)
                if dirty:
                    raise RuntimeError(
                        f"Cannot cleanup worktree {worktree_id!r} with dirty "
                        f"changes: {dirty[:200]!r}; commit or stash first, or "
                        f"pass force=True."
                    )
        else:
            logger.warning(
                "cleanup force=True bypassing checks for worktree %s (state=%s)",
                worktree_id,
                record.state.value,
            )

        # Review fix (correctness): transition to GC_PENDING BEFORE git operations.
        # State reflects intent; if the subsequent git remove fails (locked
        # file on Windows, etc.), the state machine remains consistent with
        # reality ("we intend to GC"). A re-run of cleanup completes the work
        # cleanly from a known state.
        try:
            self.transition_state(worktree_id, WorktreeState.GC_PENDING)
        except ValueError:
            # Already GC_PENDING from a prior partial-failure run, or the
            # current state doesn't permit (force=True path) -- write directly.
            r = self._load_record(worktree_id)
            r.state = WorktreeState.GC_PENDING
            self._save_record(r)

        # Remove the git worktree.
        if worktree_dir.is_dir():
            try:
                self._git_worktree_remove(worktree_dir, force=force)
            except subprocess.CalledProcessError as e:
                if not force:
                    raise RuntimeError(
                        f"git worktree remove failed: {e.stderr or e.stdout}"
                    )
                logger.warning(
                    "git worktree remove failed (force=True; continuing): %s", e
                )

        # Remove record + dir.
        record_path = self._record_path(worktree_id)
        if record_path.exists():
            record_path.unlink()
        for p in (worktree_dir, self._worktree_subdir(worktree_id)):
            try:
                p.rmdir()
            except OSError:
                pass  # non-empty or missing; manual cleanup may be needed

    def reconcile(self) -> ReconcileReport:
        """Walk the worktrees directory; reconcile orphan records and dirs."""
        discarded: list[str] = []
        reconstructed: list[str] = []
        if not self._worktrees_root.is_dir():
            return ReconcileReport(tuple(), tuple())
        for sub in sorted(self._worktrees_root.iterdir()):
            if not sub.is_dir():
                continue
            worktree_id = sub.name
            record_path = sub / "record.json"
            worktree_dir = sub / "worktree"

            record_exists = record_path.is_file()
            dir_exists = worktree_dir.is_dir()

            if record_exists and not dir_exists:
                try:
                    record = WorktreeRecord.model_validate_json(
                        record_path.read_text(encoding="utf-8")
                    )
                except (json.JSONDecodeError, ValueError):
                    continue
                if record.state == WorktreeState.ACTIVE:
                    record.state = WorktreeState.DISCARDED
                    self._save_record(record)
                    discarded.append(worktree_id)
            elif dir_exists and not record_exists:
                logger.warning(
                    "Orphaned worktree directory at %s (no record.json); "
                    "manual cleanup may be required.",
                    worktree_dir,
                )
                reconstructed.append(worktree_id)

        return ReconcileReport(
            discarded_orphan_records=tuple(discarded),
            reconstructed_orphan_dirs=tuple(reconstructed),
        )

    # --- Internal helpers ---

    def _mint_worktree_id(
        self, dispatch: WorkerDispatch, kind: WorktreeKind
    ) -> str:
        if kind == WorktreeKind.MAINLINE:
            return f"wt-mainline-{dispatch.mission_id}"
        short = str(dispatch.id)[:8]
        return f"wt-fanout-{short}"

    def _default_branch_name(
        self, dispatch: WorkerDispatch, worktree_id: str
    ) -> str:
        """Per-dispatch branch naming.

        Branch names include a dispatch-id suffix so second-mainline-dispatch
        against the same mission doesn't fail on `git worktree add -b` with
        an already-existing branch. Suffix is the first 8 chars of the
        dispatch's UUID -- short enough to read in `git branch -l` output,
        long enough to disambiguate across a mission's dispatch lifetime.
        """
        short = str(dispatch.id)[:8]
        return f"mission/{dispatch.mission_id}/{worktree_id}/{short}"

    def _load_record(self, worktree_id: str) -> WorktreeRecord:
        path = self._record_path(worktree_id)
        if not path.exists():
            raise FileNotFoundError(
                f"No record for worktree {worktree_id!r} at {path}"
            )
        return WorktreeRecord.model_validate_json(
            path.read_text(encoding="utf-8")
        )

    def _save_record(self, record: WorktreeRecord) -> None:
        path = self._record_path(record.id)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            record.model_dump_json(indent=2), encoding="utf-8", newline="\n"
        )

    # --- git subprocess helpers ---

    def _git_worktree_add(
        self, worktree_dir: Path, branch: str, base_commit: str
    ) -> None:
        cmd = [
            "git",
            "worktree",
            "add",
            "-b",
            branch,
            str(worktree_dir),
            base_commit,
        ]
        r = subprocess.run(
            cmd, cwd=str(self._project_root), capture_output=True, text=True
        )
        if r.returncode != 0:
            raise RuntimeError(
                f"git worktree add failed: {r.stderr.strip() or r.stdout.strip()}"
            )

    def _git_worktree_remove(self, worktree_dir: Path, *, force: bool) -> None:
        cmd = ["git", "worktree", "remove"]
        if force:
            cmd.append("--force")
        cmd.append(str(worktree_dir))
        r = subprocess.run(
            cmd, cwd=str(self._project_root), capture_output=True, text=True
        )
        if r.returncode != 0:
            raise subprocess.CalledProcessError(
                r.returncode, cmd, r.stdout, r.stderr
            )

    def _git_rev_parse_head(self, worktree_dir: Path) -> str:
        cmd = ["git", "rev-parse", "HEAD"]
        r = subprocess.run(
            cmd,
            cwd=str(worktree_dir),
            capture_output=True,
            text=True,
            check=True,
        )
        return r.stdout.strip()

    def _git_status_porcelain(self, worktree_dir: Path) -> str:
        cmd = ["git", "status", "--porcelain"]
        r = subprocess.run(
            cmd,
            cwd=str(worktree_dir),
            capture_output=True,
            text=True,
            check=True,
        )
        return r.stdout.strip()
