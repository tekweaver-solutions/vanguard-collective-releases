"""
Permission-injection contract — the per-dispatch settings.json must include a
`permissions.allow` block derived MECHANICALLY from the dispatched tool_scope.

Background: the worktree.commit probe (2026-06-02) found that Claude Code's own
Bash permission engine sits UPSTREAM of the gateway hook. A worker granted
worktree.commit (gateway allows git add/commit) was nonetheless blocked at the
Claude Code layer with "This command requires approval" in headless dispatch
because the per-dispatch settings injected only the hook command, NOT
permissions.allow patterns for the gateway-allowed Bash subcommands.

Posture (operator-ruled): the GATEWAY is the SOLE authoritative bound.
permissions.allow is deliberately BROAD-within-each-granted-program
(`Bash(git add *)` allows any args; the gateway bounds them — path-escape,
charset) but NARROW-across-the-vocabulary (only the programs/subcommands the
tool_scope actually grants get a pattern). Avoids duplicating the gateway's
component-walk path-bounding in Claude's glob-pattern language; avoids inviting
gateway-denied attempts via a blanket `Bash(git *)`.

Tests come from the operator-reviewed contract, NOT from "whatever the
implementation does."
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from hook_config import write_dispatch_config


def _settings(tmp_path: Path, tool_scope: list[str]) -> dict:
    """Helper: write_dispatch_config + parse the settings JSON it emits."""
    result = write_dispatch_config(
        project_root=tmp_path,
        dispatch_id="dispatch-perm-inject-test",
        tool_scope=tool_scope,
        worktree_root=tmp_path,
    )
    return json.loads(result.read_text(encoding="utf-8"))


def _allow_set(settings: dict) -> set[str]:
    """Helper: extract the permissions.allow set (empty set if missing)."""
    return set(settings.get("permissions", {}).get("allow", []))


# ============================================================================
# worktree.commit injection — git subcommand patterns derived from
# WORKTREE_COMMIT_ALLOWLIST.program_subcommands["git"]
# ============================================================================

def test_worktree_commit_scope_injects_each_allowed_git_subcommand(
    tmp_path: Path,
) -> None:
    """A scope including worktree.commit injects exactly one `Bash(git <sub> *)`
    per allowed git subcommand from WORKTREE_COMMIT_ALLOWLIST."""
    settings = _settings(
        tmp_path,
        tool_scope=["repo.read", "worktree.write", "worktree.commit"],
    )
    allow = _allow_set(settings)
    # Every allowed git subcommand must appear as Bash(git <sub> *).
    for subcommand in (
        "status", "log", "diff", "show", "rev-parse", "rev-list", "add", "commit",
    ):
        pattern = f"Bash(git {subcommand} *)"
        assert pattern in allow, (
            f"missing permission pattern for allowed git subcommand "
            f"{subcommand!r}; settings.permissions.allow = {sorted(allow)!r}"
        )


def test_worktree_commit_scope_does_NOT_inject_excluded_git_subcommands(
    tmp_path: Path,
) -> None:
    """Excluded subcommands (egress, destructive, history-rewriting, config,
    branch) MUST NOT appear in permissions.allow. The injection narrows to
    exactly what the gateway permits; broader patterns invite gateway-denied
    attempts."""
    settings = _settings(
        tmp_path,
        tool_scope=["repo.read", "worktree.write", "worktree.commit"],
    )
    allow = _allow_set(settings)
    for excluded in (
        # Egress
        "push", "fetch", "pull", "clone", "remote",
        # Destructive / history-rewriting
        "reset", "clean", "checkout", "switch", "restore", "stash",
        "rebase", "merge", "cherry-pick", "gc", "prune",
        # Persistent configuration
        "config",
        # Argument-granularity excluded (branch -d cannot be distinguished from create)
        "branch",
    ):
        pattern = f"Bash(git {excluded} *)"
        assert pattern not in allow, (
            f"EXCLUDED git subcommand {excluded!r} must NOT appear in "
            f"permissions.allow; got {pattern!r}"
        )


def test_worktree_commit_scope_does_NOT_inject_blanket_git_pattern(
    tmp_path: Path,
) -> None:
    """No blanket `Bash(git *)` — that would let the worker attempt any git
    subcommand (push, reset, branch -d) only to eat a gateway deny. The
    permission layer must narrow to exactly what the gateway permits."""
    settings = _settings(
        tmp_path,
        tool_scope=["repo.read", "worktree.write", "worktree.commit"],
    )
    allow = _allow_set(settings)
    assert "Bash(git *)" not in allow, (
        f"blanket Bash(git *) pattern must NOT be injected; got allow = "
        f"{sorted(allow)!r}"
    )


# ============================================================================
# shell.read injection — program patterns derived from
# SHELL_READ_ALLOWLIST.programs (no subcommands, bare-program pattern)
# ============================================================================

def test_shell_read_scope_injects_each_allowed_program(tmp_path: Path) -> None:
    """A scope including shell.read injects exactly one `Bash(<program> *)`
    per program in SHELL_READ_ALLOWLIST.programs."""
    settings = _settings(tmp_path, tool_scope=["repo.read", "shell.read"])
    allow = _allow_set(settings)
    for program in ("cat", "head", "tail", "wc", "ls", "grep"):
        pattern = f"Bash({program} *)"
        assert pattern in allow, (
            f"missing permission pattern for allowed shell.read program "
            f"{program!r}; allow = {sorted(allow)!r}"
        )


def test_shell_read_scope_does_NOT_inject_find(tmp_path: Path) -> None:
    """`find` is excluded under the inclusion criterion (`-delete` is
    charset-permitted; argv[0]-granular allowlist cannot distinguish read
    traversal from destruction). It must NOT appear in permissions.allow."""
    settings = _settings(tmp_path, tool_scope=["repo.read", "shell.read"])
    allow = _allow_set(settings)
    assert "Bash(find *)" not in allow


# ============================================================================
# Scope-without-bash → NO Bash patterns
# ============================================================================

def test_repo_read_only_scope_injects_no_bash_patterns(tmp_path: Path) -> None:
    """A scope with only repo.read (no shell.read, no test.run, no
    worktree.commit) grants Read/Glob/Grep — NO Bash invocations. The
    injection must add zero Bash permission patterns."""
    settings = _settings(tmp_path, tool_scope=["repo.read"])
    allow = _allow_set(settings)
    bash_patterns = [p for p in allow if p.startswith("Bash(")]
    assert bash_patterns == [], (
        f"repo.read alone must inject no Bash patterns; got {bash_patterns!r}"
    )


def test_repo_read_plus_worktree_write_injects_no_bash_patterns(
    tmp_path: Path,
) -> None:
    """worktree.write grants Write/Edit/NotebookEdit (not Bash). Combined
    with repo.read still produces no Bash permission patterns. (The
    permission for file-writes is governed by Claude Code's own
    write-tool permission model, not by this Bash injection.)"""
    settings = _settings(
        tmp_path,
        tool_scope=["repo.read", "worktree.write"],
    )
    allow = _allow_set(settings)
    bash_patterns = [p for p in allow if p.startswith("Bash(")]
    assert bash_patterns == [], (
        f"repo.read + worktree.write must inject no Bash patterns; got "
        f"{bash_patterns!r}"
    )


# ============================================================================
# test.run injection — populated TEST_RUN_ALLOWLIST (was empty previously)
# ============================================================================

def test_test_run_scope_injects_pytest_pattern_per_am007(
    tmp_path: Path,
) -> None:
    """An operator-ratified change (2026-06-04) populated TEST_RUN_ALLOWLIST.programs
    with {"pytest"}. The injection derivation now mechanically emits a Bash
    pattern for `pytest`. Was emptiness-guard previously — flipped to populated-
    shape guard alongside the test_bounds_predicates module-level tests."""
    settings = _settings(tmp_path, tool_scope=["repo.read", "test.run"])
    allow = _allow_set(settings)
    bash_patterns = [p for p in allow if p.startswith("Bash(")]
    assert bash_patterns, (
        f"test.run with populated allowlist must inject at least one Bash "
        f"pattern; got {bash_patterns!r}"
    )
    assert any("pytest" in p for p in bash_patterns), (
        f"test.run injection must reference pytest (the sole operator-ratified "
        f"program); got {bash_patterns!r}"
    )


# ============================================================================
# DERIVATION INTEGRITY — patterns come from the allowlist constants, not
# hardcoded. A monkeypatched allowlist changes the injection accordingly.
# ============================================================================

def test_injection_is_derived_from_allowlist_not_hardcoded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Replace WORKTREE_COMMIT_ALLOWLIST with a synthetic 2-subcommand
    allowlist {status, commit}. The injection MUST yield exactly those two
    patterns (Bash(git status *), Bash(git commit *)) and no others. Proves
    the derivation reads the live allowlist constant, not a hardcoded list.

    If the implementation hardcodes the 8 subcommands, this test will fail
    — it will inject all 8 even though the monkeypatched allowlist only has
    2."""
    import command_allowlist
    synthetic = command_allowlist.CommandAllowlist(
        programs=frozenset({"git"}),
        program_path_positions={},
        program_subcommands={"git": frozenset({"status", "commit"})},
        subcommand_operand_bound={},
    )
    monkeypatch.setattr(
        command_allowlist, "WORKTREE_COMMIT_ALLOWLIST", synthetic
    )
    settings = _settings(
        tmp_path,
        tool_scope=["repo.read", "worktree.write", "worktree.commit"],
    )
    allow = _allow_set(settings)
    git_patterns = {p for p in allow if p.startswith("Bash(git ")}
    assert git_patterns == {"Bash(git status *)", "Bash(git commit *)"}, (
        f"derivation must read the live allowlist; got git patterns: "
        f"{sorted(git_patterns)!r}"
    )


# ============================================================================
# Hook command preservation — the gateway hook entry must still be written
# unchanged; the new permissions.allow does not displace it.
# ============================================================================

def test_hook_command_preserved_when_permissions_added(tmp_path: Path) -> None:
    """Adding permissions.allow must NOT remove or alter the PreToolUse hook
    entry — the gateway is still the authoritative deny."""
    settings = _settings(
        tmp_path,
        tool_scope=["repo.read", "worktree.write", "worktree.commit"],
    )
    assert "hooks" in settings
    assert "PreToolUse" in settings["hooks"]
    pre_use = settings["hooks"]["PreToolUse"]
    assert len(pre_use) == 1
    assert pre_use[0]["matcher"] == "*"
    assert "command" in pre_use[0]["hooks"][0]
    assert "gateway_hook.py" in pre_use[0]["hooks"][0]["command"]
