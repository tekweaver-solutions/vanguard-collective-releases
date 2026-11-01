"""
hook_config.py -- write per-dispatch hook configuration files for the
worker-runner to pass to `claude -p --settings`.

Per the step-5 design (operator-approved 2026-05-29):

Outputs (per dispatch, under <project_root>/.mission-runtime/dispatches/<dispatch_id>/):
- `tool_scope.json` -- the scope the gateway_hook reads when checking calls.
- `hook-settings.json` -- the file passed to `claude -p --settings`. Contains
  the PreToolUse hook configuration pointing at gateway_hook.py with the
  dispatch_id as argv.

Invariants enforced here (per the corresponding gotchas):

1. **Forward-slash POSIX-style paths in the `command` field** (per the
   claude-code-hook-bash-windows-forward-slash-paths gotcha).
   Claude Code runs hook commands via bash even on Windows; backslash-escaped
   paths get mangled. _to_posix() converts a Windows Path to MSYS/Git-bash
   form (`C:\\work\\...` -> `/c/work/...`); on Linux this is a no-op.

2. **Per-dispatch namespaced settings.json** at the documented dispatch path.
   Avoids fan-out contention; multiple concurrent dispatches do not share a
   settings file.

3. **dispatch_id + project_root + handoff_path + bounds_path as argv**
   (step-5 operator decision 3c + the hook-runner-contract-escapes-to-argv
   fix + the handoff-write-protocol-exemption fix + the bounds-gate
   channel ruling). The hook command is
   `<python> <hook_script> <dispatch_id> <project_root_posix> <handoff_path_posix> <bounds_path_posix>`.
   - argv[1] = dispatch_id (used to locate tool_scope.json).
   - argv[2] = project_root POSIX path. The project_root rides argv
     (not env) because Claude Code overrides CLAUDE_PROJECT_DIR for
     hook subprocesses.
   - argv[3] = handoff_path POSIX path. The hook applies an exact-path
     exemption for Write to this exact path (the framework-protocol
     handoff). See `policy.is_handoff_write_exemption`.
   - argv[4] = bounds_path POSIX path. Points at a runner-written
     JSON file (`bounds.json`) under the dispatch dir, declaring
     `worktree_root` + `repo_root` for the bounds-gate predicates
     (`policy.is_path_in_bounds`, `policy.is_command_in_allowlist`).
     Channel-trust property: bounds.json lives OUTSIDE the worktree
     (under `.mission-runtime/dispatches/<id>/`), so a `worktree.write`-
     scoped worker cannot rewrite its own bounds even with a write
     capability -- the path-bounds gate rejects the write.
   POSIX form for all path argv slots because the command runs under
   bash on Windows. The argv channel is verbatim
   under runner control -- the hook command string in hook-settings.json
   is what Claude reads to spawn the hook, and Claude doesn't rewrite it.

API:
    write_dispatch_config(project_root, dispatch_id, tool_scope, *, ...)
        Returns the absolute Path to hook-settings.json, which the runner
        passes to claude -p via --settings.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Optional

DEFAULT_HOOK_SCRIPT_NAME = "gateway_hook.py"


def _derive_permissions_allow(tool_scope: list[str]) -> list[str]:
    """Derive the `permissions.allow` patterns for the worker's Claude Code
    settings from its tool_scope, BY CONSTRUCTION from the gateway's
    allowlists.

    Closes the probe finding (`worktree-commit-probe.md`): Claude Code's
    Bash permission engine sits UPSTREAM of the gateway hook. A worker
    granted worktree.commit had `git add` rejected at the Claude Code layer
    ("This command requires approval" in headless dispatch) BEFORE the
    gateway could ALLOW. The fix: inject permissions.allow patterns
    derived from the same allowlists the gateway uses, so the two layers
    are synced by construction.

    Posture (operator-ruled): the GATEWAY is the SOLE authoritative bound.
    This injection is BROAD-within-each-granted-program (e.g. `Bash(git
    add *)` allows any args; the gateway bounds them — path-escape,
    charset, etc.) but NARROW-across-the-vocabulary (only programs/
    subcommands the tool_scope actually grants get a pattern). Avoids
    duplicating the gateway's component-walk path-bounding in Claude's
    glob-pattern language; avoids inviting gateway-denied attempts via a
    blanket `Bash(git *)`.

    For each capability in tool_scope, look up its allowlist via
    `policy._capability_to_allowlist()` (the same source-of-truth the
    gateway uses):
      - If the program has a `program_subcommands` entry: emit
        `Bash(<program> <subcommand> *)` per allowed subcommand
        (more granular than bare program — prevents the worker
        attempting non-allowlisted subcommands that the gateway would
        deny anyway).
      - Else: emit `Bash(<program> *)` (bare-program pattern, the
        gateway's argument-level bounds apply).
    Capabilities not in the gateway's allowlist dispatch map (repo.read,
    worktree.write, task.spawn, MCP server tags) yield no Bash patterns
    — they grant non-Bash tools whose permission is handled by Claude
    Code's own mechanisms.
    """
    # Lazy import: hook_config is also imported by gateway_hook (via the
    # to_posix function), and we want to keep that import path light.
    # Importing policy here means the dispatch map is consulted only when
    # a per-dispatch config is being written, not on every hook
    # invocation.
    import sys as _sys
    from pathlib import Path as _Path
    _here = _Path(__file__).parent
    _gateway_dir = _here.parent / "tool-gateway"
    if str(_gateway_dir) not in _sys.path:
        _sys.path.insert(0, str(_gateway_dir))
    from policy import _capability_to_allowlist  # noqa: E402

    dispatch_map = _capability_to_allowlist()
    patterns: set[str] = set()
    for capability in tool_scope:
        allowlist = dispatch_map.get(capability)
        if allowlist is None:
            # Capability doesn't grant Bash through the dispatch map
            # (repo.read, worktree.write, task.spawn, MCP servers,
            # package.install.allowlisted, shell.exec.* — though the
            # last is rejected at construction). No Bash pattern.
            continue
        for program in allowlist.programs:
            subcommands = allowlist.program_subcommands.get(program)
            if subcommands:
                # Per-subcommand patterns. More granular than
                # `Bash(<program> *)`; prevents the worker attempting
                # non-allowlisted subcommands that the gateway would
                # deny anyway.
                for subcommand in subcommands:
                    patterns.add(f"Bash({program} {subcommand} *)")
            else:
                # Bare-program pattern. The gateway's argument-level
                # bounds (charset, path-position) apply.
                patterns.add(f"Bash({program} *)")
    return sorted(patterns)

# Positive-pattern validation: dispatch_id is a safe filesystem segment.
# Letters, digits, dot, hyphen, underscore. Rejects whitespace, path
# separators, control characters, and most filesystem-cryptic shapes.
_DISPATCH_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")

# Windows reserved device names. Files / directories with these names
# (case-insensitive, with or without extension) are special-cased by the
# OS and cause cryptic failures at create-time.
_WINDOWS_RESERVED_NAMES = frozenset(
    {
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    }
)


def to_posix(path: Path) -> str:
    """Convert a Path to forward-slash POSIX form for bash on Windows.

    Windows: `C:\\work\\project\\...` -> `/c/work/project/...` (MSYS/Git-bash style).
    Linux/macOS: backslash-free path with no drive letter; returned as-is.

    Public helper (no underscore) -- intended for reuse by worktree-manager
    and other modules that produce bash-on-Windows-safe paths.
    """
    s = str(path)
    if len(s) >= 2 and s[1] == ":":
        drive = s[0].lower()
        rest = s[2:].replace("\\", "/")
        if rest.startswith("/"):
            return f"/{drive}{rest}"
        return f"/{drive}/{rest}"
    return s.replace("\\", "/")


def write_dispatch_config(
    project_root: Path,
    dispatch_id: str,
    tool_scope: list[str],
    *,
    worktree_root: Path,
    python_executable: Optional[Path] = None,
    hook_script: Optional[Path] = None,
    handoff_path: Optional[Path] = None,
) -> Path:
    """Write tool_scope.json + bounds.json + hook-settings.json under the dispatch dir.

    Returns the path to hook-settings.json (suitable for `claude -p --settings <path>`).

    Defaults:
    - `python_executable` -> `sys.executable` (the framework venv interpreter).
    - `hook_script` -> `gateway_hook.py` in the same dir as this module.
    - `handoff_path` -> `<project_root>/.mission-runtime/dispatches/<dispatch_id>/handoff.json`
      (the canonical path the runner directs the worker to write). Override
      ONLY in tests; production callers should let it default. The hook
      applies an EXACT-PATH Write exemption against this path -- see
      `policy.is_handoff_write_exemption`.

    Required (no default):
    - `worktree_root` -- the worker's assigned worktree directory. The hook's
      path-bounds gate (`policy.is_path_in_bounds`) bounds writes to this
      directory. Channel-trust property: bounds.json is written under the
      dispatch dir (NOT under the worktree), so a `worktree.write`-scoped
      worker cannot rewrite its own bounds.

    Raises ValueError on invalid inputs (dispatch_id with path separators,
    non-string tool_scope entries, etc.). Raises TypeError if project_root
    or worktree_root is not a Path.
    """
    if not isinstance(project_root, Path):
        raise TypeError(
            f"project_root must be a Path; got {type(project_root).__name__}"
        )
    if not isinstance(worktree_root, Path):
        raise TypeError(
            f"worktree_root must be a Path; got {type(worktree_root).__name__}"
        )
    if not isinstance(dispatch_id, str) or not dispatch_id:
        raise ValueError(f"dispatch_id must be a non-empty string; got {dispatch_id!r}")
    # Reject all-dots ids (., .., ..., etc.) before the pattern check.
    if dispatch_id.strip(".") == "":
        raise ValueError(f"dispatch_id must not be all dots; got {dispatch_id!r}")
    if dispatch_id.upper() in _WINDOWS_RESERVED_NAMES:
        raise ValueError(
            f"dispatch_id must not be a Windows reserved device name; got {dispatch_id!r}"
        )
    if not _DISPATCH_ID_PATTERN.match(dispatch_id):
        raise ValueError(
            f"dispatch_id must match [A-Za-z0-9._-]+; got {dispatch_id!r}"
        )
    if not isinstance(tool_scope, list):
        raise ValueError(
            f"tool_scope must be a list of strings; got {type(tool_scope).__name__}"
        )
    for entry in tool_scope:
        if not isinstance(entry, str):
            raise ValueError(
                f"tool_scope entries must be strings; got {entry!r}"
            )

    if python_executable is None:
        python_executable = Path(sys.executable)
    if hook_script is None:
        hook_script = Path(__file__).parent / DEFAULT_HOOK_SCRIPT_NAME

    dispatch_dir = project_root / ".mission-runtime" / "dispatches" / dispatch_id
    dispatch_dir.mkdir(parents=True, exist_ok=True)
    # Default handoff_path matches the runner's canonical location. The
    # hook applies an exact-path Write exemption against this path.
    if handoff_path is None:
        handoff_path = dispatch_dir / "handoff.json"

    scope_path = dispatch_dir / "tool_scope.json"
    bounds_path = dispatch_dir / "bounds.json"
    settings_path = dispatch_dir / "hook-settings.json"

    with scope_path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump({"tool_scope": tool_scope}, f, indent=2)
        f.write("\n")

    # bounds.json: runner-written, hook-read, worker-unreachable. Values
    # are NATIVE form strings (str(Path)) because the hook reads the JSON
    # via python's open() -- no bash translation applies to file contents,
    # only to argv values that bash itself parses. Contrast: argv[4]
    # (the bounds.json file path) is POSIX-form so bash routes it correctly.
    bounds_doc = {
        "worktree_root": str(worktree_root),
        "repo_root": str(project_root),
    }
    with bounds_path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(bounds_doc, f, indent=2)
        f.write("\n")

    # Build the bash-on-Windows-safe command string. Per the gotcha above,
    # forward-slash POSIX paths are mandatory for argv values that bash
    # parses.
    python_posix = to_posix(python_executable)
    hook_posix = to_posix(hook_script)
    project_root_posix = to_posix(project_root)
    handoff_path_posix = to_posix(handoff_path)
    bounds_path_posix = to_posix(bounds_path)
    # argv[1] = dispatch_id, argv[2] = project_root, argv[3] = handoff_path,
    # argv[4] = bounds_path (all POSIX form; bash on Windows MSYS-translates
    # back to native when invoking python.exe). See ledger entries
    # `hook-runner-contract-escapes-to-argv` (argv[2]),
    # `handoff-write-protocol-exemption` (argv[3]), and the bounds-gate
    # build (argv[4]).
    command = (
        f"{python_posix} {hook_posix} {dispatch_id} "
        f"{project_root_posix} {handoff_path_posix} {bounds_path_posix}"
    )

    # Derive permissions.allow from tool_scope so Claude Code's Bash
    # permission engine doesn't block what the gateway would allow.
    # See `_derive_permissions_allow` for the posture rationale.
    permissions_allow = _derive_permissions_allow(tool_scope)

    settings: dict = {
        "hooks": {
            "PreToolUse": [
                {
                    "matcher": "*",
                    "hooks": [
                        {"type": "command", "command": command},
                    ],
                }
            ]
        }
    }
    if permissions_allow:
        # Only emit the permissions block when there are patterns to add;
        # keeps the settings.json minimal for scopes that don't grant
        # Bash (the F-001 read-only/write-only earlier dispatches).
        settings["permissions"] = {"allow": permissions_allow}

    with settings_path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")

    return settings_path
