"""
Tests for gateway_hook.py -- the PreToolUse hook executable.

Subprocess-based: each test spawns a fresh Python process running
gateway_hook.py with controlled stdin + argv. Exit codes are read;
stderr is captured.

Per the hook-runner argv contract (gateway_hook.py docstring): the hook
derives ALL inputs from argv + runner-written files only. No env-
dependency. argv[1]=dispatch_id, argv[2]=project_root (replaces the
prior CLAUDE_PROJECT_DIR env dependency that Claude Code overrode for
hook subprocesses).

Coverage per the step-5 design + operator test priorities:
- Positive ALLOWED path: full valid setup, exit 0, no stderr noise.
  Catches the regression where someone reverts the explicit
  GatewayDecision.ALLOWED comparison to a string compare and the
  underlying value drifts -- silent fail-closed becomes a test failure.
- DENIED path: tool not in scope, exit 2, reason in stderr.
- DENIED path (unmapped tool): tool not in any capability tag.
- Fail-closed paths (each must exit 2 with a descriptive reason):
  * Missing argv[1] (dispatch_id)
  * Missing argv[2] (project_root) -- NEW per the argv contract fix
  * Empty argv[2] -- NEW per the argv contract fix
  * Empty stdin
  * Malformed JSON stdin
  * Payload not an object
  * Missing tool_name
  * Missing tool_scope.json
  * Malformed tool_scope.json
  * tool_scope.json root not an object
  * Missing 'tool_scope' key or non-list
  * Non-string entry in tool_scope
"""

from __future__ import annotations

import json
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


_DEFAULT_STDIN_SENTINEL = "<<USE_DEFAULT>>"


def _run_hook(
    *,
    tmp_path: Path,
    dispatch_id: str = "dispatch-test-001",
    stdin: str | None = _DEFAULT_STDIN_SENTINEL,
    tool_scope: list | dict | None = None,
    omit_dispatch_id: bool = False,
    omit_project_root: bool = False,
    project_root_override: str | None = None,
    omit_handoff_path: bool = False,
    handoff_path_override: str | None = None,
    omit_bounds_path: bool = False,
    bounds_path_override: str | None = None,
    omit_bounds_file: bool = False,
    bounds_file_content: str | None = None,
    worktree_root: Path | None = None,
    omit_scope_file: bool = False,
    scope_file_content: str | None = None,
) -> subprocess.CompletedProcess:
    """Spawn gateway_hook.py with controlled setup.

    Default setup is the happy ALLOWED path: dispatch_id at argv[1],
    project_root=tmp_path at argv[2], handoff_path at argv[3], bounds_path
    at argv[4], valid stdin, tool_scope=['repo.read'] on disk, bounds.json
    declaring worktree_root=tmp_path + repo_root=tmp_path. Override flags
    to construct each fail-closed scenario.

    Per the hook-runner argv contract (see gateway_hook.py docstring),
    the hook derives all inputs from argv + runner-written files only --
    NEVER from Claude-controlled ambient state. This helper reflects that:
    no env injection of CLAUDE_PROJECT_DIR.
    """
    if stdin is _DEFAULT_STDIN_SENTINEL:
        # Default Read call must include a file_path under tmp_path so
        # the bounds gate ALLOWs. Bounds repo_root defaults to tmp_path.
        stdin = json.dumps({
            "tool_name": "Read",
            "tool_input": {"file_path": str(tmp_path / "dummy.txt")},
            "tool_use_id": "tu_x",
        })
    if not omit_scope_file:
        scope_dir = tmp_path / ".mission-runtime" / "dispatches" / dispatch_id
        scope_dir.mkdir(parents=True, exist_ok=True)
        if scope_file_content is not None:
            (scope_dir / "tool_scope.json").write_text(
                scope_file_content, encoding="utf-8"
            )
        else:
            payload = (
                {"tool_scope": tool_scope}
                if tool_scope is not None
                else {"tool_scope": ["repo.read"]}
            )
            (scope_dir / "tool_scope.json").write_text(
                json.dumps(payload), encoding="utf-8"
            )

    # bounds.json (per argv[4] contract). Default values use tmp_path for
    # both worktree_root and repo_root, which means most existing tests
    # see an effectively-permissive bounds gate (writes under tmp_path
    # pass containment). Tests that need to probe bounds DENY paths
    # pass an explicit worktree_root narrower than tmp_path.
    if not omit_bounds_file:
        bounds_dir = tmp_path / ".mission-runtime" / "dispatches" / dispatch_id
        bounds_dir.mkdir(parents=True, exist_ok=True)
        if bounds_file_content is not None:
            (bounds_dir / "bounds.json").write_text(
                bounds_file_content, encoding="utf-8"
            )
        else:
            wt = worktree_root if worktree_root is not None else tmp_path
            (bounds_dir / "bounds.json").write_text(
                json.dumps({
                    "worktree_root": str(wt),
                    "repo_root": str(tmp_path),
                }),
                encoding="utf-8",
            )

    argv = [str(_VENV_PYTHON), str(HOOK_SCRIPT)]
    # Positional ordering matters: argv[1]=dispatch_id THEN argv[2]=project_root
    # THEN argv[3]=handoff_path THEN argv[4]=bounds_path. Skipping a position
    # means everything after also skips (the hook checks positions in order
    # and dies on the first missing slot).
    if not omit_dispatch_id:
        argv.append(dispatch_id)
        if not omit_project_root:
            argv.append(
                project_root_override
                if project_root_override is not None
                else str(tmp_path)
            )
            if not omit_handoff_path:
                # Default handoff_path matches the runner's canonical location.
                default_handoff = (
                    tmp_path / ".mission-runtime" / "dispatches"
                    / dispatch_id / "handoff.json"
                )
                argv.append(
                    handoff_path_override
                    if handoff_path_override is not None
                    else str(default_handoff)
                )
                if not omit_bounds_path:
                    default_bounds = (
                        tmp_path / ".mission-runtime" / "dispatches"
                        / dispatch_id / "bounds.json"
                    )
                    argv.append(
                        bounds_path_override
                        if bounds_path_override is not None
                        else str(default_bounds)
                    )

    # Minimal env -- no CLAUDE_PROJECT_DIR (the hook no longer reads it).
    # PATH/SYSTEMROOT/TEMP/TMP retained so the Python interpreter runs.
    import os

    env = {
        k: v for k, v in os.environ.items()
        if k in ("PATH", "SYSTEMROOT", "TEMP", "TMP")
    }

    return subprocess.run(
        argv,
        input=stdin if stdin is not None else "",
        capture_output=True,
        text=True,
        env=env,
        timeout=20,
    )


# ---------- ALLOWED path ----------

def test_allowed_path_exit_zero(tmp_path: Path) -> None:
    """Valid setup with Read+repo.read -> exit 0, no stderr noise.
    Operator-flagged priority test: catches enum-comparison regressions."""
    result = _run_hook(tmp_path=tmp_path, tool_scope=["repo.read"])
    assert result.returncode == 0, f"expected exit 0; got {result.returncode}; stderr={result.stderr!r}"
    assert result.stderr == "", f"expected silent allow; got stderr={result.stderr!r}"


def test_allowed_path_mcp_tool(tmp_path: Path) -> None:
    """MCP tool covered by a server-scope tag -> exit 0, silent stderr.
    Silent-allow invariant holds on both halves of the hybrid taxonomy (a design-review note)."""
    stdin = json.dumps(
        {"tool_name": "mcp__postman__runCollection", "tool_input": {}, "tool_use_id": "tu_y"}
    )
    result = _run_hook(tmp_path=tmp_path, stdin=stdin, tool_scope=["postman"])
    assert result.returncode == 0, f"stderr={result.stderr!r}"
    assert result.stderr == "", f"expected silent allow on MCP path; got stderr={result.stderr!r}"


# ---------- DENIED paths ----------

def test_denied_scope_lacks_capability(tmp_path: Path) -> None:
    """Tool exists but scope doesn't cover it -> exit 2 with reason."""
    stdin = json.dumps({"tool_name": "Bash", "tool_input": {}, "tool_use_id": "tu_z"})
    result = _run_hook(tmp_path=tmp_path, stdin=stdin, tool_scope=["repo.read"])
    assert result.returncode == 2
    assert "gateway_denied" in result.stderr
    assert "Bash" in result.stderr


def test_denied_unmapped_tool(tmp_path: Path) -> None:
    """Tool not in any capability tag -> exit 2 with unmapped reason."""
    stdin = json.dumps({"tool_name": "TotallyMadeUp", "tool_input": {}, "tool_use_id": "tu_n"})
    result = _run_hook(tmp_path=tmp_path, stdin=stdin, tool_scope=["repo.read"])
    assert result.returncode == 2
    assert "gateway_denied" in result.stderr


# ---------- Fail-closed paths ----------

def test_fail_closed_missing_dispatch_id_argv(tmp_path: Path) -> None:
    """argv[1] missing -> fail-closed deny with dispatch_id-named error."""
    result = _run_hook(tmp_path=tmp_path, omit_dispatch_id=True)
    assert result.returncode == 2
    assert "dispatch_id" in result.stderr


def test_fail_closed_missing_project_root_argv(tmp_path: Path) -> None:
    """argv[2] missing -> fail-closed deny with project_root-named error.

    The hook derives project_root from argv[2] (not env). This guard ensures
    a malformed hook command (missing the second argv element written by
    hook_config.py) fails closed -- not silently allowing or defaulting
    to an ambient value Claude could control."""
    result = _run_hook(tmp_path=tmp_path, omit_project_root=True)
    assert result.returncode == 2
    assert "project_root" in result.stderr


def test_fail_closed_empty_project_root_argv(tmp_path: Path) -> None:
    """argv[2] = '' -> fail-closed (catches accidental whitespace-stripping
    or build-time bugs that would otherwise pass an empty string through)."""
    result = _run_hook(tmp_path=tmp_path, project_root_override="")
    assert result.returncode == 2
    assert "project_root" in result.stderr


def test_fail_closed_missing_handoff_path_argv(tmp_path: Path) -> None:
    """argv[3] (handoff_path) missing -> fail-closed deny with
    handoff_path-named error. The hook applies an exact-path Write
    exemption against argv[3]; without it, the exemption code path
    would silently fall through to the normal gateway check, denying
    the legitimate handoff Write. Better to fail-closed loudly than
    silently degrade."""
    result = _run_hook(tmp_path=tmp_path, omit_handoff_path=True)
    assert result.returncode == 2
    assert "handoff_path" in result.stderr


def test_fail_closed_empty_handoff_path_argv(tmp_path: Path) -> None:
    """argv[3] = '' -> fail-closed."""
    result = _run_hook(tmp_path=tmp_path, handoff_path_override="")
    assert result.returncode == 2
    assert "handoff_path" in result.stderr


# ---------- Handoff-protocol exemption ----------

def test_exemption_write_to_handoff_path_allowed(tmp_path: Path) -> None:
    """The CORE exemption: with tool_scope=['repo.read'], a Write to the
    EXACT handoff_path is ALLOWED (exit 0) with observable stderr
    naming the exemption + the capability tag `framework.handoff_exemption`.
    This is the framework-protocol carve-out -- writing the handoff is
    NOT task work; the worker must be able to produce its handoff
    regardless of task scope (§5)."""
    dispatch_id = "exempt-001"
    handoff_path = (
        tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "handoff.json"
    )
    stdin = json.dumps({
        "tool_name": "Write",
        "tool_input": {"file_path": str(handoff_path), "content": "{}"},
        "tool_use_id": "tu_exempt",
    })
    result = _run_hook(
        tmp_path=tmp_path, dispatch_id=dispatch_id,
        stdin=stdin, tool_scope=["repo.read"],
    )
    assert result.returncode == 0, f"expected ALLOW; got exit {result.returncode}; stderr={result.stderr!r}"
    # Observable marker: stderr names the exemption + the special capability tag.
    assert "gateway_exemption" in result.stderr, (
        f"exemption ALLOW must be observable in stderr; got {result.stderr!r}"
    )
    assert "framework.handoff_exemption" in result.stderr
    assert "handoff_protocol_exact_path_allow" in result.stderr


def test_exemption_does_NOT_apply_to_different_path_under_dispatch_dir(
    tmp_path: Path,
) -> None:
    """THE CRITICAL NEGATIVE TEST. The exemption is exact-path: a Write
    to a DIFFERENT file under the same dispatch dir (e.g. tool_scope.json,
    hook-settings.json, or any sibling file) must still go through normal
    scope gating and be DENIED for a `repo.read`-scoped worker. If this
    test fails, the read-only guarantee is broken -- the exemption
    leaked beyond the one file it should cover."""
    dispatch_id = "exempt-negative-001"
    sibling_path = (
        tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "tool_scope.json"
    )
    # The hook's argv[3] is the handoff_path (default ...handoff.json),
    # but the tool_input.file_path is the SIBLING tool_scope.json under
    # the same dispatch dir. The exemption MUST NOT fire.
    stdin = json.dumps({
        "tool_name": "Write",
        "tool_input": {"file_path": str(sibling_path), "content": '{"tool_scope": ["worktree.write"]}'},
        "tool_use_id": "tu_negative_sibling",
    })
    result = _run_hook(
        tmp_path=tmp_path, dispatch_id=dispatch_id,
        stdin=stdin, tool_scope=["repo.read"],
    )
    assert result.returncode == 2, (
        f"exemption leaked to a sibling path under the dispatch dir -- "
        f"read-only guarantee broken. expected exit 2, got {result.returncode}; "
        f"stderr={result.stderr!r}"
    )
    assert "gateway_denied" in result.stderr
    assert "Write" in result.stderr
    assert "worktree.write" in result.stderr
    # And the exemption marker MUST NOT appear.
    assert "gateway_exemption" not in result.stderr


def test_exemption_does_NOT_apply_to_arbitrary_worktree_path(tmp_path: Path) -> None:
    """A Write anywhere else under the worktree (a normal worker task
    write target, e.g. source code) must still be DENIED under
    repo.read scope. The exemption is dispatch-handoff-specific, not a
    blanket Write allow."""
    dispatch_id = "exempt-negative-002"
    arbitrary_path = tmp_path / "src" / "feature.py"
    stdin = json.dumps({
        "tool_name": "Write",
        "tool_input": {"file_path": str(arbitrary_path), "content": "code"},
        "tool_use_id": "tu_negative_worktree",
    })
    result = _run_hook(
        tmp_path=tmp_path, dispatch_id=dispatch_id,
        stdin=stdin, tool_scope=["repo.read"],
    )
    assert result.returncode == 2
    assert "gateway_denied" in result.stderr
    assert "gateway_exemption" not in result.stderr


def test_exemption_does_NOT_apply_to_edit_of_handoff_path(tmp_path: Path) -> None:
    """The exemption is for Write tool ONLY, not Edit. The handoff
    protocol is 'Write a fresh handoff.json on exit' -- Edit presumes a
    prior file and is not part of the protocol. Edit to the handoff_path
    is still denied under repo.read scope (worktree.write required)."""
    dispatch_id = "exempt-negative-003"
    handoff_path = (
        tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "handoff.json"
    )
    stdin = json.dumps({
        "tool_name": "Edit",
        "tool_input": {
            "file_path": str(handoff_path),
            "old_string": "x",
            "new_string": "y",
        },
        "tool_use_id": "tu_negative_edit",
    })
    result = _run_hook(
        tmp_path=tmp_path, dispatch_id=dispatch_id,
        stdin=stdin, tool_scope=["repo.read"],
    )
    assert result.returncode == 2
    assert "gateway_denied" in result.stderr
    assert "gateway_exemption" not in result.stderr


def test_exemption_handles_slash_normalization(tmp_path: Path) -> None:
    """tool_input.file_path may arrive as forward-slash or backslash form
    (Claude might normalize either way). The exemption's path comparison
    uses os.path.normcase(normpath(abspath(...))), so equivalent path
    representations of the same handoff file MUST be exempted equally."""
    dispatch_id = "exempt-norm-001"
    handoff_path = (
        tmp_path / ".mission-runtime" / "dispatches" / dispatch_id / "handoff.json"
    )
    # Use forward slashes for the tool_input.file_path while argv[3] uses
    # the native (potentially backslash) form via str(Path).
    handoff_path_fwd = str(handoff_path).replace("\\", "/")
    stdin = json.dumps({
        "tool_name": "Write",
        "tool_input": {"file_path": handoff_path_fwd, "content": "{}"},
        "tool_use_id": "tu_normalize",
    })
    result = _run_hook(
        tmp_path=tmp_path, dispatch_id=dispatch_id,
        stdin=stdin, tool_scope=["repo.read"],
    )
    assert result.returncode == 0, (
        f"normalized-equivalent path should still exempt. "
        f"stderr={result.stderr!r}"
    )
    assert "gateway_exemption" in result.stderr


def test_fail_closed_empty_stdin(tmp_path: Path) -> None:
    result = _run_hook(tmp_path=tmp_path, stdin="")
    assert result.returncode == 2
    assert "empty stdin" in result.stderr


def test_fail_closed_malformed_json_stdin(tmp_path: Path) -> None:
    result = _run_hook(tmp_path=tmp_path, stdin="{not valid json")
    assert result.returncode == 2
    assert "JSON decode" in result.stderr


def test_fail_closed_payload_not_object(tmp_path: Path) -> None:
    """stdin is a JSON array, not object."""
    result = _run_hook(tmp_path=tmp_path, stdin="[1, 2, 3]")
    assert result.returncode == 2
    assert "not an object" in result.stderr


def test_fail_closed_missing_tool_name(tmp_path: Path) -> None:
    result = _run_hook(
        tmp_path=tmp_path,
        stdin=json.dumps({"tool_input": {}, "tool_use_id": "tu_x"}),
    )
    assert result.returncode == 2
    assert "tool_name" in result.stderr


def test_fail_closed_missing_scope_file(tmp_path: Path) -> None:
    """project_root argv set, but the dispatch dir/file doesn't exist."""
    result = _run_hook(tmp_path=tmp_path, omit_scope_file=True)
    assert result.returncode == 2
    assert "tool_scope.json not found" in result.stderr


def test_fail_closed_malformed_scope_json(tmp_path: Path) -> None:
    result = _run_hook(tmp_path=tmp_path, scope_file_content="{not json")
    assert result.returncode == 2
    assert "tool_scope.json read failed" in result.stderr


def test_fail_closed_scope_root_not_object(tmp_path: Path) -> None:
    result = _run_hook(tmp_path=tmp_path, scope_file_content="[\"repo.read\"]")
    assert result.returncode == 2
    assert "root must be an object" in result.stderr


def test_fail_closed_scope_missing_tool_scope_field(tmp_path: Path) -> None:
    """Missing 'tool_scope' key triggers the same code path as a non-list
    value (the hook's `not isinstance(tool_scope, list)` covers None +
    any non-list type). Asserts the specific 'missing or non-list' phrase
    rather than just 'tool_scope' so the assertion documents the shared
    error path (a design-review note)."""
    result = _run_hook(tmp_path=tmp_path, scope_file_content="{}")
    assert result.returncode == 2
    assert "missing or non-list" in result.stderr


def test_fail_closed_scope_non_list_tool_scope(tmp_path: Path) -> None:
    """Non-list 'tool_scope' value (string here) triggers the same code
    path as a missing field (a design-review note)."""
    result = _run_hook(
        tmp_path=tmp_path,
        scope_file_content=json.dumps({"tool_scope": "repo.read"}),
    )
    assert result.returncode == 2
    assert "missing or non-list" in result.stderr


def test_fail_closed_scope_non_string_entry(tmp_path: Path) -> None:
    result = _run_hook(
        tmp_path=tmp_path,
        scope_file_content=json.dumps({"tool_scope": ["repo.read", 42]}),
    )
    assert result.returncode == 2
    assert "non-string entry" in result.stderr
