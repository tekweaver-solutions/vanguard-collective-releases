"""
Tests for hook_config -- per-dispatch settings.json + tool_scope.json writer.

Two architectural properties to verify (operator-named in step-5 C2 prep):
1. Forward-slash POSIX path emission in the hook `command` field
   (bash-on-Windows hook execution requires forward slashes).
2. Per-dispatch namespaced settings at
   <project_root>/.mission-runtime/dispatches/<dispatch_id>/.

Plus input validation, defaults, and shape integrity (the settings JSON
matches what Claude Code's PreToolUse hook config expects, per the
captured fixtures).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path, PureWindowsPath

import pytest

from hook_config import (
    DEFAULT_HOOK_SCRIPT_NAME,
    to_posix,
    write_dispatch_config,
)

# Hook subprocess must spawn the framework venv interpreter (the same one
# generated hook-settings.json points Claude Code at), NOT sys.executable.
# Under bare/ambient pytest sys.executable is system Python; its yaml +
# pydantic live in user-site, which the round-trip test's deliberate env
# scrub ({PATH,SYSTEMROOT,TEMP,TMP}; APPDATA dropped) makes invisible —
# and the scrub is correct per the hook's argv-only contract, so the fix
# is the interpreter, not the env. tools/.venv carries yaml + pydantic
# by lock, so the venv interpreter resolves them without user-site
# anchors. Only the round-trip test (below) spawns the hook; the rest of
# this file exercises hook_config shape and does not need the venv, so
# the skipif is per-test rather than module-level.
_VENV_PYTHON = (
    Path(__file__).resolve().parent.parent / ".venv" / "Scripts" / "python.exe"
)


# ---------- to_posix conversion ----------

def test_to_posix_windows_drive_letter() -> None:
    """`C:\\work\\project\\foo` -> `/c/work/project/foo`."""
    assert to_posix(PureWindowsPath("C:\\work\\project\\foo")) == "/c/work/project/foo"


def test_to_posix_windows_with_forward_slashes() -> None:
    """`C:/work/project/foo` -> `/c/work/project/foo` (also valid input form)."""
    assert to_posix(Path("C:/work/project/foo")) == "/c/work/project/foo"


def test_to_posix_lowercases_drive_letter() -> None:
    """Drive letter must be lowercased (MSYS convention: /c/, not /C/)."""
    assert to_posix(PureWindowsPath("D:\\Projects\\x")) == "/d/Projects/x"


def test_to_posix_posix_path_passthrough() -> None:
    """No drive letter, no backslashes -> returned as-is."""
    assert to_posix(Path("/home/user/file")) == "/home/user/file"


# ---------- write_dispatch_config happy path ----------

def test_writes_both_files(tmp_path: Path) -> None:
    """Creates tool_scope.json and hook-settings.json at the dispatch dir."""
    result = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="dispatch-test-001",
        tool_scope=["repo.read", "worktree.write"],
        worktree_root=tmp_path,
)
    expected_dir = tmp_path / ".mission-runtime" / "dispatches" / "dispatch-test-001"
    assert result == expected_dir / "hook-settings.json"
    assert (expected_dir / "tool_scope.json").is_file()
    assert (expected_dir / "hook-settings.json").is_file()


def test_tool_scope_json_shape(tmp_path: Path) -> None:
    """tool_scope.json round-trips to the same shape gateway_hook reads."""
    write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-shape",
        tool_scope=["repo.read", "postman"],
        worktree_root=tmp_path,
)
    scope_path = tmp_path / ".mission-runtime" / "dispatches" / "d-shape" / "tool_scope.json"
    doc = json.loads(scope_path.read_text(encoding="utf-8"))
    assert doc == {"tool_scope": ["repo.read", "postman"]}


def test_settings_json_shape(tmp_path: Path) -> None:
    """hook-settings.json matches the PreToolUse hook config shape Claude Code expects
    (per fixtures/sample-stream-with-hook-events-allow.jsonl observation)."""
    write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-shape",
        tool_scope=["repo.read"],
        worktree_root=tmp_path,
)
    settings_path = (
        tmp_path / ".mission-runtime" / "dispatches" / "d-shape" / "hook-settings.json"
    )
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    assert "hooks" in doc
    assert "PreToolUse" in doc["hooks"]
    pre = doc["hooks"]["PreToolUse"]
    assert isinstance(pre, list) and len(pre) == 1
    entry = pre[0]
    assert entry["matcher"] == "*"
    assert isinstance(entry["hooks"], list) and len(entry["hooks"]) == 1
    inner = entry["hooks"][0]
    assert inner["type"] == "command"
    assert "command" in inner and isinstance(inner["command"], str)


def test_command_uses_forward_slashes(tmp_path: Path) -> None:
    """Command must use forward-slash POSIX paths,
    not backslash-escaped Windows paths. Bash on Windows strips backslashes."""
    settings_path = write_dispatch_config(
        project_root=tmp_path / "proj",
        dispatch_id="d-slashes",
        tool_scope=["repo.read"],
        python_executable=Path("C:/work/project/.venv/Scripts/python.exe"),
        hook_script=Path("C:/work/project/code/gateway_hook.py"),
        worktree_root=tmp_path,
)
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    command = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    # No backslashes anywhere in the command:
    assert "\\" not in command, f"backslash leaked into command: {command!r}"
    # Drive letter rewritten to MSYS form for ALL paths (python, hook
    # script, project_root, handoff_path):
    assert command.startswith("/c/work/project/.venv/Scripts/python.exe ")
    # Final token is the bounds_path POSIX form (argv[4]); handoff_path
    # (argv[3]) is now penultimate.
    assert command.endswith(
        f" {to_posix(tmp_path / 'proj')}/.mission-runtime/dispatches/d-slashes/handoff.json"
        f" {to_posix(tmp_path / 'proj')}/.mission-runtime/dispatches/d-slashes/bounds.json"
    ), f"expected command to end with the POSIX handoff_path + bounds_path; got {command!r}"


def test_command_threads_dispatch_id_project_root_handoff_path_bounds_path_as_argv(
    tmp_path: Path,
) -> None:
    """argv contract (4 path args after the script):
    argv[1] = dispatch_id (gateway_hook reads sys.argv[1])
    argv[2] = project_root POSIX (sys.argv[2]; was CLAUDE_PROJECT_DIR env)
    argv[3] = handoff_path POSIX (sys.argv[3]; for the exact-path
              handoff-Write exemption per
              `policy.is_handoff_write_exemption`)
    argv[4] = bounds_path POSIX (sys.argv[4]; for the bounds-gate
              predicates' worktree_root + repo_root values)"""
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="my-special-dispatch",
        tool_scope=["repo.read"],
        worktree_root=tmp_path,
)
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    command = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    tokens = command.split()
    # Token positions: 0=python, 1=hook_script, 2=dispatch_id,
    #                  3=project_root, 4=handoff_path, 5=bounds_path
    assert tokens[-4] == "my-special-dispatch", (
        f"expected argv[1] (dispatch_id) at tokens[-4]; got {tokens!r}"
    )
    from hook_config import to_posix
    expected_root_posix = to_posix(tmp_path)
    assert tokens[-3] == expected_root_posix, (
        f"expected argv[2] (project_root POSIX) at tokens[-3]; got {tokens[-3]!r}"
    )
    expected_handoff_posix = to_posix(
        tmp_path / ".mission-runtime" / "dispatches"
        / "my-special-dispatch" / "handoff.json"
    )
    assert tokens[-2] == expected_handoff_posix, (
        f"expected argv[3] (handoff_path POSIX) at tokens[-2]; "
        f"got {tokens[-2]!r}; want {expected_handoff_posix!r}"
    )
    expected_bounds_posix = to_posix(
        tmp_path / ".mission-runtime" / "dispatches"
        / "my-special-dispatch" / "bounds.json"
    )
    assert tokens[-1] == expected_bounds_posix, (
        f"expected argv[4] (bounds_path POSIX) at tokens[-1]; "
        f"got {tokens[-1]!r}; want {expected_bounds_posix!r}"
    )


def test_command_uses_explicit_handoff_path_override(tmp_path: Path) -> None:
    """When `handoff_path` is passed explicitly, the command's argv[3]
    reflects that value (POSIX form). Production callers rely on the
    default; tests use the override to validate the threading. argv[4]
    (bounds_path) is now after handoff_path."""
    custom = tmp_path / "custom" / "elsewhere" / "my-handoff.json"
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-override",
        tool_scope=["repo.read"],
        handoff_path=custom,
        worktree_root=tmp_path,
)
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    command = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    tokens = command.split()
    from hook_config import to_posix
    assert tokens[-2] == to_posix(custom), (
        f"explicit handoff_path override did not reach argv[3] (tokens[-2]): "
        f"got {tokens[-2]!r}; want {to_posix(custom)!r}"
    )


def test_idempotent_on_existing_dir(tmp_path: Path) -> None:
    """Calling twice with the same dispatch_id overwrites; no error on existing dir.
    Verifies both tool_scope.json AND hook-settings.json survive idempotent re-write (found in review)."""
    write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-idem",
        tool_scope=["repo.read"],
        worktree_root=tmp_path,
)
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-idem",
        tool_scope=["worktree.write"],  # different scope,
    worktree_root=tmp_path,
)
    scope_path = tmp_path / ".mission-runtime" / "dispatches" / "d-idem" / "tool_scope.json"
    doc = json.loads(scope_path.read_text(encoding="utf-8"))
    assert doc == {"tool_scope": ["worktree.write"]}
    assert settings_path.is_file()


# ---------- Defaults ----------

def test_default_python_executable_is_sys_executable(tmp_path: Path) -> None:
    """When python_executable is not provided, defaults to sys.executable."""
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-defaults",
        tool_scope=["repo.read"],
        worktree_root=tmp_path,
)
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    command = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    expected_python = to_posix(Path(sys.executable))
    assert command.startswith(expected_python + " ")


def test_default_hook_script_is_gateway_hook_py(tmp_path: Path) -> None:
    """When hook_script is not provided, defaults to gateway_hook.py in the same dir."""
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-defaults2",
        tool_scope=["repo.read"],
        worktree_root=tmp_path,
)
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    command = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    assert DEFAULT_HOOK_SCRIPT_NAME in command


# ---------- Validation ----------

def test_rejects_empty_dispatch_id(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="dispatch_id"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_dispatch_id_with_slash(tmp_path: Path) -> None:
    """Forward-slash fails the positive pattern check."""
    with pytest.raises(ValueError, match=r"\[A-Za-z0-9\._-\]"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="a/b", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_dispatch_id_with_backslash(tmp_path: Path) -> None:
    """Backslash fails the positive pattern check."""
    with pytest.raises(ValueError, match=r"\[A-Za-z0-9\._-\]"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="a\\b", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_dispatch_id_dot(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="all dots"):
        write_dispatch_config(project_root=tmp_path, dispatch_id=".", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_dispatch_id_dotdot(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="all dots"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="..", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_dispatch_id_three_dots(tmp_path: Path) -> None:
    """Three-or-more dots are all-dots; rejected before pattern check (found in review)."""
    with pytest.raises(ValueError, match="all dots"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="...", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_whitespace_only_dispatch_id(tmp_path: Path) -> None:
    """Whitespace-only fails the positive pattern check (found in review)."""
    with pytest.raises(ValueError, match=r"\[A-Za-z0-9\._-\]"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="   ", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_internal_whitespace_in_dispatch_id(tmp_path: Path) -> None:
    """Internal spaces fail the positive pattern check (found in review)."""
    with pytest.raises(ValueError, match=r"\[A-Za-z0-9\._-\]"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="a b", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_tab_in_dispatch_id(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match=r"\[A-Za-z0-9\._-\]"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="a\tb", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_newline_in_dispatch_id(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match=r"\[A-Za-z0-9\._-\]"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="a\nb", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_windows_reserved_name(tmp_path: Path) -> None:
    """Windows reserved device names cause filesystem-level cryptic failures
    on create; reject upfront (found in review). Case-insensitive."""
    with pytest.raises(ValueError, match="reserved"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="NUL", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_rejects_windows_reserved_name_lowercase(tmp_path: Path) -> None:
    """Reserved-name check is case-insensitive ('nul' is also reserved)."""
    with pytest.raises(ValueError, match="reserved"):
        write_dispatch_config(project_root=tmp_path, dispatch_id="con", tool_scope=["repo.read"], worktree_root=tmp_path)


def test_accepts_realistic_dispatch_id_shapes(tmp_path: Path) -> None:
    """Positive-pattern acceptance: natural dispatch_id shapes pass cleanly (found in review)."""
    for did in (
        "dispatch-2026-05-29-c3",
        "d-roundtrip",
        "001",
        "F-001_worker_1",
        "abc.test",
    ):
        # Should not raise.
        write_dispatch_config(
            project_root=tmp_path / did,  # unique parent per id avoids overwrites
            dispatch_id=did,
            tool_scope=["repo.read"],
                worktree_root=tmp_path,
    )


def test_rejects_non_list_tool_scope(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="list"):
        write_dispatch_config(
            project_root=tmp_path,
            dispatch_id="d-bad-scope",
            tool_scope="repo.read",  # type: ignore[arg-type],
        worktree_root=tmp_path,
    )


def test_rejects_non_string_tool_scope_entry(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="strings"):
        write_dispatch_config(
            project_root=tmp_path,
            dispatch_id="d-bad-entry",
            tool_scope=["repo.read", 42],  # type: ignore[list-item],
        worktree_root=tmp_path,
    )


def test_rejects_non_path_project_root(tmp_path: Path) -> None:
    with pytest.raises(TypeError, match="Path"):
        write_dispatch_config(
            project_root=str(tmp_path),  # type: ignore[arg-type]
            dispatch_id="d-bad-root",
            tool_scope=["repo.read"],
                worktree_root=tmp_path,
    )


# ---------- bounds.json channel (per the C1 + test.run build, ruling 4) ----------


def test_bounds_json_is_written(tmp_path: Path) -> None:
    """bounds.json is created under the dispatch dir alongside tool_scope.json."""
    worktree = tmp_path / "_wt"
    write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-bounds-01",
        tool_scope=["repo.read"],
        worktree_root=worktree,
    )
    bounds_path = tmp_path / ".mission-runtime" / "dispatches" / "d-bounds-01" / "bounds.json"
    assert bounds_path.is_file(), "bounds.json must be written under the dispatch dir"


def test_bounds_json_contents_carry_worktree_root_and_repo_root(tmp_path: Path) -> None:
    """bounds.json has worktree_root + repo_root in NATIVE path form
    (the JSON is consumed by python, not by bash; only the FILE PATH
    routed via argv is POSIX-form)."""
    worktree = tmp_path / "_wt"
    write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-bounds-02",
        tool_scope=["repo.read"],
        worktree_root=worktree,
    )
    bounds_path = tmp_path / ".mission-runtime" / "dispatches" / "d-bounds-02" / "bounds.json"
    doc = json.loads(bounds_path.read_text(encoding="utf-8"))
    assert doc["worktree_root"] == str(worktree), (
        f"bounds.json worktree_root should be NATIVE path str; got {doc!r}"
    )
    assert doc["repo_root"] == str(tmp_path), (
        f"bounds.json repo_root should be NATIVE path str; got {doc!r}"
    )


def test_bounds_json_lives_outside_worktree_channel_trust_property(tmp_path: Path) -> None:
    """The bounds.json file path is under the dispatch dir, NOT under the
    worktree. This is the channel-trust property the bounds gate rests on:
    a worktree.write-scoped worker cannot rewrite its own bounds because
    the path-bounds gate (worktree-rooted) rejects writes outside the
    worktree. See policy.is_path_in_bounds + the probe #22 test in
    tool-gateway/test_bounds_predicates.py."""
    worktree = tmp_path / ".mission-runtime" / "worktrees" / "wt-X" / "worktree"
    worktree.mkdir(parents=True)
    write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-bounds-03",
        tool_scope=["worktree.write"],
        worktree_root=worktree,
    )
    bounds_path = tmp_path / ".mission-runtime" / "dispatches" / "d-bounds-03" / "bounds.json"
    # bounds.json is NOT under worktree -- containment check fails by
    # design. The path-bounds gate would reject a write here even with
    # worktree.write scope.
    try:
        bounds_path.resolve().relative_to(worktree.resolve())
        was_under_worktree = True
    except ValueError:
        was_under_worktree = False
    assert not was_under_worktree, (
        f"bounds.json must NOT be under the worktree (channel trust): "
        f"bounds_path={bounds_path}; worktree={worktree}"
    )


def test_worktree_root_is_required_kw(tmp_path: Path) -> None:
    """worktree_root is a required keyword-only argument; calls without
    it must fail at the boundary (not silently default)."""
    with pytest.raises(TypeError, match="worktree_root"):
        write_dispatch_config(
            project_root=tmp_path,
            dispatch_id="d-missing-wt",
            tool_scope=["repo.read"],
        )  # type: ignore[call-arg]


def test_worktree_root_must_be_path(tmp_path: Path) -> None:
    """worktree_root must be a Path; str rejected with TypeError."""
    with pytest.raises(TypeError, match="worktree_root must be a Path"):
        write_dispatch_config(
            project_root=tmp_path,
            dispatch_id="d-str-wt",
            tool_scope=["repo.read"],
            worktree_root=str(tmp_path),  # type: ignore[arg-type]
        )


def test_bounds_path_in_argv_is_posix_form(tmp_path: Path) -> None:
    """argv[4] (the bounds.json file path passed to the hook) must be
    POSIX form because bash on Windows MSYS-translates it back to native
    for python.exe. JSON CONTENTS are native; ARGV is POSIX."""
    from hook_config import to_posix
    worktree = tmp_path / "_wt"
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-bounds-argv",
        tool_scope=["repo.read"],
        worktree_root=worktree,
    )
    doc = json.loads(settings_path.read_text(encoding="utf-8"))
    command = doc["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    tokens = command.split()
    expected_bounds_posix = to_posix(
        tmp_path / ".mission-runtime" / "dispatches" / "d-bounds-argv" / "bounds.json"
    )
    assert tokens[-1] == expected_bounds_posix


# ---------- End-to-end with gateway_hook (round-trip) ----------

@pytest.mark.skipif(
    not _VENV_PYTHON.exists(),
    reason=(
        "framework venv absent at tools/.venv/Scripts/python.exe; run "
        "`uv sync` in tools/ — hook tests target the venv interpreter"
    ),
)
def test_round_trip_with_gateway_hook_allowed(tmp_path: Path) -> None:
    """The hook config produced by hook_config.py is consumable by gateway_hook.py.
    Runs the actual hook subprocess against a config written by hook_config.

    Per the argv contract: project_root is passed at argv[2], NOT via the
    (now-dropped) CLAUDE_PROJECT_DIR env var. Confirms the round-trip
    works end-to-end via the channel Claude Code does not override."""
    import os
    import subprocess

    # Write per-dispatch config
    settings_path = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="d-roundtrip",
        tool_scope=["repo.read"],
        worktree_root=tmp_path,
)
    assert settings_path.is_file()

    # Spawn gateway_hook directly (skipping claude -p) -- proves the
    # tool_scope.json the writer produced is readable by the hook via
    # the argv-passed project_root.
    hook_script = Path(__file__).parent / "gateway_hook.py"
    env = {
        k: v for k, v in os.environ.items()
        if k in ("PATH", "SYSTEMROOT", "TEMP", "TMP")
    }
    # No CLAUDE_PROJECT_DIR -- argv contract is project_root via argv[2].
    # Read tool_input.file_path under tmp_path so the bounds gate ALLOWs
    # (bounds.json declares repo_root=tmp_path; Read tools are repo-rooted).
    stdin = json.dumps({
        "tool_name": "Read",
        "tool_input": {"file_path": str(tmp_path / "fixture.txt")},
        "tool_use_id": "tu_rt",
    })
    handoff_path = (
        tmp_path / ".mission-runtime" / "dispatches" / "d-roundtrip" / "handoff.json"
    )
    bounds_path = (
        tmp_path / ".mission-runtime" / "dispatches" / "d-roundtrip" / "bounds.json"
    )
    result = subprocess.run(
        [
            str(_VENV_PYTHON), str(hook_script),
            "d-roundtrip", str(tmp_path), str(handoff_path), str(bounds_path),
        ],
        input=stdin,
        capture_output=True,
        text=True,
        env=env,
        timeout=20,
    )
    assert result.returncode == 0, f"stderr={result.stderr!r}"
    assert result.stderr == ""
