"""
ADR-027 Decision 1+2 contract tests (the construction-time dispatch validator).

Per .mission-runtime/preflight/adr-026-027-impl-design.md Part D.4 — these are
the OPERATOR-REVIEWED contract committed BEFORE implementation. Tests come from
the contract, not from "whatever the implementation does."

The validator lives in two layers (per design Part B recommendation):
  - schemas.py: Pydantic field_validator on WorkerDispatch.tool_scope (the floor;
    rejects unknown tags + non-string elements + malformed shapes; carries a
    generic vocabulary-mismatch error message).
  - dispatch_entry.build_dispatch: pre-construction check that runs the same
    vocabulary membership BUT carries a human-facing C2-reason text for the
    shell.exec.* prohibition before the WorkerDispatch constructor sees it.

Both layers reject; the field_validator is the floor catching direct constructor
calls; build_dispatch is the gate with the explanatory reason.
"""

from __future__ import annotations

from pathlib import Path
from uuid import uuid4

import pytest
from pydantic import ValidationError

from dispatch_entry import DispatchInputs, build_dispatch
from schemas import (
    ModelClass,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
    WorktreeKind,
)

# Reuse the project fixture helper from test_dispatch_entry.py for the
# build_dispatch tests (it lays out a synthetic .mission/ + spec + contract
# so build_dispatch's spec/contract lookups succeed).
from test_dispatch_entry import _init_mission_like_project


def _make_inputs(tool_scope, **overrides) -> DispatchInputs:
    """Build a DispatchInputs with the given tool_scope; other fields default."""
    defaults = dict(
        feature_id="F-001",
        milestone_id="M-1",
        kind=WorktreeKind.FANOUT,
        model_class=ModelClass.CODING_STRONG,
        tool_scope=tool_scope,
    )
    defaults.update(overrides)
    return DispatchInputs(**defaults)


def _make_worker_dispatch(tool_scope) -> WorkerDispatch:
    """Construct a WorkerDispatch directly (bypassing build_dispatch) to exercise
    the Pydantic field_validator layer in isolation."""
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-06-02T18:00:00.000Z",
        created_by="claude-code:test",
        mission_id="mission-test",
        worker_id=str(uuid4()),
        kind=WorkerKind.FANOUT,
        feature_id="F-001",
        assertion_targets=["A-001"],
        spec_version=10,
        worktree_id="pending",
        model_class=ModelClass.CODING_STRONG,
        tool_scope=tool_scope,
        budget=WorkerBudget(cost_cap_usd=10.0, wallclock_cap_minutes=10),
    )


@pytest.fixture
def project(tmp_path: Path):
    """A synthetic project layout build_dispatch's spec/contract lookups need."""
    root = tmp_path / "project"
    root.mkdir()
    _init_mission_like_project(root)
    return root


# ============================================================================
# D.4 — construction validator contract
# ============================================================================

# ---- D.4.a — valid baseline (existing tags) ----

def test_d4a_valid_scope_existing_tags_accepted(project: Path) -> None:
    """D.4.a: build_dispatch with valid tool_scope [repo.read, worktree.write]
    returns a WorkerDispatch (no exception)."""
    inputs = _make_inputs(tool_scope=["repo.read", "worktree.write"])
    dispatch = build_dispatch(inputs, project)
    assert dispatch.tool_scope == ["repo.read", "worktree.write"]


# ---- D.4.b — valid mixed scope including a new ADR-026 tag ----

def test_d4b_valid_mixed_scope_with_worktree_commit_accepted(project: Path) -> None:
    """D.4.b: valid mixed scope including the new ADR-026 worktree.commit tag."""
    inputs = _make_inputs(
        tool_scope=["repo.read", "worktree.write", "worktree.commit"]
    )
    dispatch = build_dispatch(inputs, project)
    assert "worktree.commit" in dispatch.tool_scope


# ---- D.4.c — new ADR-026 read-tier in scope ----

def test_d4c_valid_scope_with_shell_read_accepted(project: Path) -> None:
    """D.4.c: valid scope including the new ADR-026 shell.read tag."""
    inputs = _make_inputs(tool_scope=["repo.read", "shell.read"])
    dispatch = build_dispatch(inputs, project)
    assert "shell.read" in dispatch.tool_scope


# ---- D.4.d — unknown tag rejected (typo) ----

def test_d4d_unknown_tag_rejected_at_build_dispatch(project: Path) -> None:
    """D.4.d: build_dispatch rejects a typo'd tag with a reason naming the
    offending tag AND listing the valid vocabulary."""
    inputs = _make_inputs(tool_scope=["worktree.wrte"])
    with pytest.raises((RuntimeError, ValueError, ValidationError)) as exc:
        build_dispatch(inputs, project)
    msg = str(exc.value)
    assert "worktree.wrte" in msg, f"reason must name offending tag, got: {msg!r}"


def test_d4d_unknown_tag_rejected_at_field_validator() -> None:
    """D.4.d (floor): direct WorkerDispatch construction rejects an unknown tag
    via the Pydantic field_validator."""
    with pytest.raises(ValidationError) as exc:
        _make_worker_dispatch(tool_scope=["worktree.wrte"])
    assert "worktree.wrte" in str(exc.value)


# ---- D.4.e — shell.exec.sandboxed rejected with C2 reason ----

def test_d4e_shell_exec_sandboxed_rejected_with_c2_reason(project: Path) -> None:
    """D.4.e: build_dispatch rejects shell.exec.sandboxed with a reason that
    cites the unbuilt C2 sandbox/egress layer (ADR-027 D2 + ADR-026 D3)."""
    inputs = _make_inputs(tool_scope=["repo.read", "shell.exec.sandboxed"])
    with pytest.raises((RuntimeError, ValueError, ValidationError)) as exc:
        build_dispatch(inputs, project)
    msg = str(exc.value)
    # The C2-reason text is human-facing and must be specific.
    assert "C2" in msg, f"reason must cite C2, got: {msg!r}"
    assert "shell.exec.sandboxed" in msg, (
        f"reason must name the offending tag, got: {msg!r}"
    )


# ---- D.4.f — shell.exec.unsandboxed also rejected ----

def test_d4f_shell_exec_unsandboxed_rejected_with_c2_reason(project: Path) -> None:
    """D.4.f: ADR-027 D2 covers BOTH shell.exec.{sandboxed,unsandboxed}."""
    inputs = _make_inputs(tool_scope=["shell.exec.unsandboxed"])
    with pytest.raises((RuntimeError, ValueError, ValidationError)) as exc:
        build_dispatch(inputs, project)
    msg = str(exc.value)
    assert "C2" in msg
    assert "shell.exec.unsandboxed" in msg


# ---- D.4.g — both shell.exec.* in same scope: BOTH named ----

def test_d4g_both_shell_exec_tags_rejected_both_named(project: Path) -> None:
    """D.4.g: a scope containing both shell.exec.sandboxed AND shell.exec.unsandboxed
    is rejected with BOTH offending tags named (not first-only)."""
    inputs = _make_inputs(
        tool_scope=["shell.exec.sandboxed", "shell.exec.unsandboxed"]
    )
    with pytest.raises((RuntimeError, ValueError, ValidationError)) as exc:
        build_dispatch(inputs, project)
    msg = str(exc.value)
    assert "shell.exec.sandboxed" in msg
    assert "shell.exec.unsandboxed" in msg


# ---- D.4.h — empty scope rejected at schema (min_length=1 invariant) ----

def test_d4h_empty_scope_rejected_at_schema() -> None:
    """D.4.h: empty tool_scope rejected by the existing min_length=1 Pydantic
    invariant — unchanged by this ADR."""
    with pytest.raises(ValidationError):
        _make_worker_dispatch(tool_scope=[])


# ---- D.4.i — None scope rejected fail-closed ----

def test_d4i_none_scope_rejected_fail_closed() -> None:
    """D.4.i: tool_scope=None rejected fail-closed (ADR-027 D2 fail-closed
    property — malformed input must be rejected, never waved through)."""
    with pytest.raises(ValidationError):
        _make_worker_dispatch(tool_scope=None)


# ---- D.4.j — non-string element rejected fail-closed ----

def test_d4j_non_string_element_rejected_fail_closed() -> None:
    """D.4.j: tool_scope=[123] (non-string element) rejected fail-closed."""
    with pytest.raises(ValidationError):
        _make_worker_dispatch(tool_scope=[123])


# ---- D.4.k — framework.* tags rejected (not worker-grantable) ----

def test_d4k_framework_sentinel_tag_rejected_at_build_dispatch(project: Path) -> None:
    """D.4.k: framework.handoff_exemption is a framework sentinel; workers
    cannot request it. Vocabulary check filters framework.* out of grantable."""
    inputs = _make_inputs(tool_scope=["framework.handoff_exemption"])
    with pytest.raises((RuntimeError, ValueError, ValidationError)) as exc:
        build_dispatch(inputs, project)
    assert "framework.handoff_exemption" in str(exc.value)


def test_d4k_framework_sentinel_tag_rejected_at_field_validator() -> None:
    """D.4.k (floor): same rejection via direct WorkerDispatch construction."""
    with pytest.raises(ValidationError) as exc:
        _make_worker_dispatch(tool_scope=["framework.bounds.path.worktree"])
    assert "framework.bounds.path.worktree" in str(exc.value)


# ---- D.4.l — framework.harness.internal tag rejected (workers can't request) ----

def test_d4l_framework_harness_internal_tag_rejected(project: Path) -> None:
    """D.4.l: framework.harness.internal (added in Step 2 for harness-internal
    tool mapping) — workers also cannot request this tag because the vocabulary
    check filters all framework.* out of grantable. The filter is in place from
    Step 1; the tag itself appears in _NATIVE_MAP only after Step 2, but the
    filter rejects it regardless."""
    inputs = _make_inputs(tool_scope=["framework.harness.internal"])
    with pytest.raises((RuntimeError, ValueError, ValidationError)) as exc:
        build_dispatch(inputs, project)
    assert "framework.harness.internal" in str(exc.value)
