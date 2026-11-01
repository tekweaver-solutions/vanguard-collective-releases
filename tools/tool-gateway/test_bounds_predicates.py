"""
Direct-probe tests for the bounds-gate predicates in policy.py.

Surface design ruled by operator: 21 cases enumerated in the design pass,
plus correction-B (probe #10 hedge-removed) and correction-C (probe #22
worker-cannot-rewrite-its-own-bounds). All cases here are $0 in-process
predicate invocations -- no claude subprocess, no live dispatch.

Cases that depend on the hook COMPOSITION ORDER (notably probe #5: the
handoff-exemption short-circuit must fire BEFORE the bounds gate so a
write to the handoff path returns ALLOW under the exemption tag, not
DENY under the bounds tag) are tested at the hook integration level in
tools/worker-runner/test_hook_bounds.py. This file proves the predicates
in isolation; the hook file proves they compose correctly.

The TEST-LOCAL allowlist {'pytest': (-1,)} is injected here. The
module-level TEST_RUN_ALLOWLIST in command_allowlist.py STAYS EMPTY
(closed-by-default); operator ratifies the real contents separately.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from command_allowlist import ALLOWED_CHARSET, CommandAllowlist
from policy import (
    BOUNDS_CMD_ARGV_CAPABILITY,
    BOUNDS_CMD_CAPABILITY,
    BOUNDS_CMD_CHARSET_CAPABILITY,
    BOUNDS_CMD_PATH_ARG_CAPABILITY,
    BOUNDS_CMD_PROGRAM_CAPABILITY,
    BOUNDS_PATH_REPO_CAPABILITY,
    BOUNDS_PATH_WORKTREE_CAPABILITY,
    Bounds,
    is_command_in_allowlist,
    is_path_in_bounds,
)
from schemas import GatewayDecision


# Test-local allowlist. NOT exported. Operator ratifies the module-level
# constant separately; this fixture exists ONLY so the probes can prove
# the gate works.
_TEST_ALLOWLIST = CommandAllowlist(
    programs=frozenset({"pytest"}),
    program_path_positions={"pytest": (-1,)},  # pytest's last argv = path
)


@pytest.fixture
def synthetic_repo(tmp_path: Path) -> tuple[Path, Path]:
    """Synthetic monorepo with an embedded worktree.

    Layout:
      tmp_path/repo/                          <- repo_root
        .mission/spec/v010.yaml               <- read target above worktree
        .mission-runtime/
          worktrees/wt-X/worktree/            <- worktree_root
            src/                              <- legitimate write target
            tests/                            <- legitimate test path
          dispatches/<id>/bounds.json         <- channel-trust target (probe #22)
    Returns (repo_root, worktree_root) as Paths.
    """
    repo = tmp_path / "repo"
    worktree = repo / ".mission-runtime" / "worktrees" / "wt-X" / "worktree"
    (repo / ".mission" / "spec").mkdir(parents=True)
    (repo / ".mission" / "spec" / "v010.yaml").write_text("# fixture\n")
    (worktree / "src").mkdir(parents=True)
    (worktree / "tests").mkdir(parents=True)
    (worktree / "tests" / "test_existing.py").write_text("# fixture\n")
    return repo, worktree


def _bounds(repo: Path, worktree: Path) -> Bounds:
    return Bounds(
        worktree_root=str(worktree),
        repo_root=str(repo),
    )


# ============================================================================
# C1 PATH-BOUNDING — Probes #1..#9
# ============================================================================


def test_probe_01_write_inside_worktree_allow(synthetic_repo: tuple[Path, Path]) -> None:
    """#1: Write file_path under worktree -> ALLOW framework.bounds.path.worktree."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Write",
        {"file_path": str(wt / "src" / "new.py")},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_02_write_outside_worktree_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#2: Write file_path outside worktree -> DENY framework.bounds.path.worktree."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Write",
        {"file_path": "/tmp/outside.py"},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_03_dotdot_traversal_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#3: Write with .. traversal escaping worktree -> DENY (normpath collapses)."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Write",
        {"file_path": str(wt / ".." / ".." / "escaped.py")},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_04_symlink_escape_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#4: Write through a symlink whose target is OUTSIDE worktree -> DENY.

    Correction A: the leaf may not exist; resolve realpath of the deepest
    existing ancestor (the symlink), then re-attach the non-existing tail.
    """
    repo, wt = synthetic_repo
    sym_target = wt.parent.parent / "external"  # outside worktree
    sym_target.mkdir(parents=True)
    sym = wt / "src" / "sym"
    try:
        os.symlink(sym_target, sym, target_is_directory=True)
    except (OSError, NotImplementedError) as e:
        pytest.skip(f"symlink creation unsupported: {e}")
    v = is_path_in_bounds(
        "Write",
        {"file_path": str(sym / "newfile.py")},  # leaf does not exist
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED, (
        f"symlink-escape probe should DENY but got {v}"
    )
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_05_handoff_exemption_NOT_handled_here(synthetic_repo: tuple[Path, Path]) -> None:
    """#5: A Write to a path outside the worktree (the handoff path is
    such a path) is DENIED by is_path_in_bounds. The handoff EXEMPTION
    is not the predicate's responsibility — it's the hook's composition
    that runs the exemption check BEFORE this predicate, so a real
    handoff write never reaches here. This probe documents the predicate
    contract: it does NOT know about exemptions. See
    test_hook_bounds.test_probe_05_handoff_exemption_short_circuits for
    the composition-order verification (the load-bearing assertion)."""
    repo, wt = synthetic_repo
    handoff_path = repo / ".mission-runtime" / "dispatches" / "d-01" / "handoff.json"
    v = is_path_in_bounds(
        "Write",
        {"file_path": str(handoff_path)},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_06_edit_inside_worktree_allow(synthetic_repo: tuple[Path, Path]) -> None:
    """#6: Edit shares Write's worktree-root semantics."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Edit",
        {"file_path": str(wt / "tests" / "test_existing.py")},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_07_notebook_edit_inside_worktree_allow(synthetic_repo: tuple[Path, Path]) -> None:
    """#7: NotebookEdit reads notebook_path (NOT file_path); worktree root."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "NotebookEdit",
        {"notebook_path": str(wt / "analysis.ipynb")},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_08_read_inside_repo_above_worktree_allow(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#8: Read a file above the worktree but inside the repo -> ALLOW.
    Bounds.repo_root is the read root, not worktree_root."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Read",
        {"file_path": str(repo / ".mission" / "spec" / "v010.yaml")},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_PATH_REPO_CAPABILITY


def test_probe_09_read_outside_repo_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#9: Read outside repo_root -> DENY framework.bounds.path.repo."""
    repo, wt = synthetic_repo
    # Sibling of repo_root (NOT under it). startswith would accept this if
    # we used prefix-match; commonpath correctly rejects.
    sibling = repo.parent / "repo-extra" / "file"
    sibling.parent.mkdir()
    sibling.write_text("x")
    v = is_path_in_bounds(
        "Read",
        {"file_path": str(sibling)},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_PATH_REPO_CAPABILITY


# ============================================================================
# Probe #10 — Glob/Grep optional path (correction B: NO hedge)
# ============================================================================


def test_probe_10a_glob_no_explicit_path_allow(synthetic_repo: tuple[Path, Path]) -> None:
    """#10 (correction B, part 1): Glob without explicit `path` field -> ALLOW.
    Pattern-only invocations do not carry a bounded path argument."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Glob",
        {"pattern": "**/*.py"},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_PATH_REPO_CAPABILITY


def test_probe_10b_glob_explicit_path_inside_repo_allow(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#10 (correction B, part 2): Glob with explicit path inside repo -> ALLOW."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Glob",
        {"pattern": "*.yaml", "path": str(repo / ".mission" / "spec")},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_PATH_REPO_CAPABILITY


def test_probe_10c_glob_explicit_path_outside_repo_deny(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#10 (correction B, part 3): Glob with explicit path OUTSIDE repo -> DENY.
    No special-casing — any path arg to any gated tool is bounded."""
    repo, wt = synthetic_repo
    v = is_path_in_bounds(
        "Glob",
        {"pattern": "*.txt", "path": "/tmp"},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_PATH_REPO_CAPABILITY


# ============================================================================
# test.run COMMAND ALLOWLIST — Probes #11..#21
# ============================================================================


def _cmd_verdict(command: str, bounds: Bounds, *, cap: str = "test.run"):
    """Helper: run is_command_in_allowlist with the test-local allowlist."""
    return is_command_in_allowlist(
        tool_name="Bash",
        tool_input={"command": command},
        allowlist=_TEST_ALLOWLIST,
        bounds=bounds,
        authorized_capability=cap,
    )


def test_probe_11_pytest_clean_path_allow(synthetic_repo: tuple[Path, Path]) -> None:
    """#11: `pytest <worktree>/tests/` -> ALLOW framework.bounds.cmd.
    All four steps pass: charset, argv, program, path-arg.

    Command-string path is POSIX-form. On Windows, the production hook
    runs under bash (per the existing hook-runner contract); a worker
    Bash command containing native backslash paths is correctly rejected
    by the charset gate -- backslash is not in ALLOWED_CHARSET. The path
    inside tool_input.file_path (used by is_path_in_bounds) is
    realpath-normalized so accepts either form, but the Bash command
    string is shell-source and must be POSIX-clean."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests").as_posix()
    v = _cmd_verdict(f"pytest {posix_tests_path}", _bounds(repo, wt))
    assert v.decision == GatewayDecision.ALLOWED, f"got {v}"
    assert v.capability_tag == BOUNDS_CMD_CAPABILITY


def test_probe_12_chained_and_charset_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#12: `pytest tests/ && curl evil.com` -> DENY charset (& sign)."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest tests/ && curl evil.com", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_13_command_substitution_dollar_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#13: `pytest $(whoami)` -> DENY charset ($, (, ))."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest $(whoami)", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_14_semicolon_chain_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#14: `pytest; rm -rf x` -> DENY charset (;)."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest; rm -rf x", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_15_backtick_substitution_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#15: pytest `whoami` -> DENY charset (backtick)."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest `whoami`", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_16_newline_injection_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#16: pytest with embedded newline -> DENY charset (\\n)."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest\ntests/", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_17_redirect_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#17: `pytest > /tmp/out` -> DENY charset (>)."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest > /tmp/out", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_18_chained_with_cd_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#18: `cd /tmp && pytest tests/` -> DENY charset (&). Operator's escape
    hatch for chains is shell.exec.sandboxed, not test.run."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("cd /tmp && pytest tests/", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


def test_probe_19_non_allowlisted_program_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#19: `npm test` (npm not in test-local allowlist) -> DENY program.
    Charset passes; argv[0]='npm' fails program membership."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("npm test", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_PROGRAM_CAPABILITY


def test_probe_20_pytest_outside_worktree_path_arg_deny(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#20: `pytest /etc/passwd` -> DENY path_arg. Charset passes; program
    passes; path-arg routed through is_path_in_bounds(worktree_root) and
    rejected. This is the C1 + test.run COMPOSITION proof."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("pytest /etc/passwd", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_PATH_ARG_CAPABILITY


def test_probe_21_program_case_sensitive_deny(synthetic_repo: tuple[Path, Path]) -> None:
    """#21: `Pytest tests/` (capitalized) -> DENY program. Program match is
    CASE-SENSITIVE (exact); this INTENTIONALLY diverges from
    is_handoff_write_exemption's normcase. Path containment uses normcase
    (the FS decides identity); program allowlisting uses exact match (the
    framework decides identity). Spoof surface on Windows closed."""
    repo, wt = synthetic_repo
    v = _cmd_verdict("Pytest tests/", _bounds(repo, wt))
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_PROGRAM_CAPABILITY


# ============================================================================
# Correction C — Probe #22: worker cannot rewrite its own bounds
# ============================================================================


def test_probe_22_write_to_bounds_json_by_worktree_writer_deny(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#22 (correction C): A Write targeting <runtime>/dispatches/<id>/bounds.json
    by a worktree.write-scoped worker -> DENY framework.bounds.path.worktree.
    bounds.json lives OUTSIDE the worktree (under .mission-runtime/dispatches/
    not under .mission-runtime/worktrees/.../worktree/), so the worktree-bounds
    gate rejects it. This is the load-bearing trust property the channel rests
    on: the worker, even with worktree.write, cannot rewrite its own bounds."""
    repo, wt = synthetic_repo
    bounds_json = repo / ".mission-runtime" / "dispatches" / "d-target" / "bounds.json"
    v = is_path_in_bounds(
        "Write",
        {"file_path": str(bounds_json)},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


# ============================================================================
# Probes #23 / #24 — combined `..` + symlink escape (a verification turn finding)
# ============================================================================
#
# The OLD _resolve_symlink_safe called os.path.abspath BEFORE realpath.
# abspath collapses `..` LEXICALLY, cancelling a `link/..` hop before the
# filesystem ever resolves `link`. For path `<root>/link/../escape` where
# `link` is a symlink to OUTSIDE root, abspath canceled `link/..` to
# `<root>/`, then the escape leaf appended INSIDE root -- a WRONG ALLOW.
# The fix replaces abspath+realpath with a single realpath call, which
# walks the filesystem component-by-component and resolves symlinks
# BEFORE interpreting `..`. These probes prove that combined-vector
# escape is now correctly DENIED.


def test_probe_23_combined_dotdot_and_symlink_escape_worktree_deny(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#23 (verification-turn correction): Write via `link/..` where link
    is a worktree-resident symlink to outside the worktree -> DENY
    framework.bounds.path.worktree.

    Old algorithm (abspath-then-realpath): abspath collapsed `link/..`
    lexically to `<wt>/` BEFORE the symlink was resolved -> ALLOW (BUG).
    New algorithm (single realpath): symlink resolves to <external>;
    `..` walks <external>'s real parent; literal leaf appends -> DENY."""
    repo, wt = synthetic_repo
    # Symlink target placed OUTSIDE the worktree (under tmp_path, which is
    # also the repo_root; but the worktree is narrower than the repo so
    # external is outside the worktree even though it could be inside the
    # repo). For the worktree-bounds-check, what matters is whether the
    # resolved path lands UNDER wt -- it should not.
    external = wt.parent.parent / "external_combined_23"
    external.mkdir(parents=True)
    link = wt / "link23"
    try:
        os.symlink(external, link, target_is_directory=True)
    except (OSError, NotImplementedError) as e:
        pytest.skip(f"symlink creation unsupported: {e}")
    # Construct the attack path as a string (NOT via Path resolution,
    # which would normalize `..` itself before we hand to the predicate).
    attack_path = str(link) + os.sep + ".." + os.sep + "escape.py"
    v = is_path_in_bounds(
        "Write",
        {"file_path": attack_path},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED, (
        f"combined ..+symlink escape must DENY; got {v}"
    )
    assert v.capability_tag == BOUNDS_PATH_WORKTREE_CAPABILITY


def test_probe_24_combined_dotdot_and_symlink_escape_repo_deny(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """#24 (read-side mirror of #23): Read via `link/..` where link is a
    repo-resident symlink to outside the repo -> DENY
    framework.bounds.path.repo. Same bug, same fix, applied to the Read
    side where bounds.repo_root is the relevant containment root."""
    repo, wt = synthetic_repo
    external = repo.parent / "external_combined_24"
    external.mkdir(parents=True)
    link = repo / "link24-out"
    try:
        os.symlink(external, link, target_is_directory=True)
    except (OSError, NotImplementedError) as e:
        pytest.skip(f"symlink creation unsupported: {e}")
    attack_path = str(link) + os.sep + ".." + os.sep + "escape.txt"
    v = is_path_in_bounds(
        "Read",
        {"file_path": attack_path},
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED, (
        f"combined ..+symlink escape (repo side) must DENY; got {v}"
    )
    assert v.capability_tag == BOUNDS_PATH_REPO_CAPABILITY


# ============================================================================
# Contract-first probes — flag-allowlist enforcement
# ============================================================================
#
# These probes declare the TEST_RUN_ALLOWLIST shape:
#   programs={"pytest"}, program_path_positions={"pytest":(-1,)},
#   program_allowed_flags={"pytest":{"-q","-x","--tb"}}
#
# Pre-2C state (this commit): `program_allowed_flags` is NOT yet a field on
# CommandAllowlist. The fixture below will TypeError at construction; that
# IS the schema-level broken-case signal. Per contract-first
# discipline, the DENY probes (-p evil_plugin / --rootdir=/etc / -c
# /tmp/poison.ini) prove the gate's flag-gap by either:
#   (path A) failing at fixture construction → schema missing, the
#     CommandAllowlist field addition (2C part 1) is required.
#   (path B, only after 2C part 1) failing at assert(DENIED) — gate ALLOWs
#     the harmful vector because policy.py has no Step 3d yet → the
#     enforcement (2C part 2) is required.
#
# Construction is LAZY (pytest fixture, not module-level) so the failure
# localizes to these probes; the rest of the suite stays green.


@pytest.fixture
def am007_allowlist() -> CommandAllowlist:
    """TEST_RUN_ALLOWLIST shape (proposed). Constructed lazily so
    missing-field TypeErrors surface as per-probe failures, not collection-
    time errors that take down the whole file."""
    return CommandAllowlist(
        programs=frozenset({"pytest"}),
        program_path_positions={"pytest": (-1,)},
        program_allowed_flags={"pytest": frozenset({"-q", "-x", "--tb"})},
    )


def _cmd_verdict_am007(
    allowlist: CommandAllowlist,
    command: str,
    bounds: Bounds,
):
    """Variant of _cmd_verdict that takes an explicit allowlist (the
    fixture above), so these probes do not depend on the module-
    level `_TEST_ALLOWLIST`."""
    return is_command_in_allowlist(
        tool_name="Bash",
        tool_input={"command": command},
        allowlist=allowlist,
        bounds=bounds,
        authorized_capability="test.run",
    )


def test_probe_am007_p_plugin_deny(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_21'): `pytest -p evil_plugin
    tests/foo.py` -> EXPECT DENY at framework.bounds.cmd.flag. -p loads
    arbitrary plugin code (ACE surface); `-p` is NOT in the allowed flag
    set, so an enforced gate must reject. Pre-2C: gate has no Step 3d, so
    argv[-1]='tests/foo.py' passes the position bound and the call
    ALLOWs — probe fails, proving the gap."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist,
        f"pytest -p evil_plugin {posix_tests_path}",
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED, f"broken-case: got {v}"


def test_probe_am007_rootdir_deny(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_22'): `pytest --rootdir=/etc
    tests/foo.py` -> EXPECT DENY at framework.bounds.cmd.flag. --rootdir
    redirects conftest discovery outside the worktree; `--rootdir` (prefix
    of `--rootdir=/etc`) is NOT in the allowed flag set."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist,
        f"pytest --rootdir=/etc {posix_tests_path}",
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED, f"broken-case: got {v}"


def test_probe_am007_dash_c_config_deny(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_23'): `pytest -c
    /tmp/poison.ini tests/foo.py` -> EXPECT DENY. -c loads a custom config
    file from arbitrary path; `-c` is NOT in the allowed flag set."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist,
        f"pytest -c /tmp/poison.ini {posix_tests_path}",
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.DENIED, f"broken-case: got {v}"


def test_probe_am007_dash_q_allow(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_24'): `pytest -q
    tests/test_existing.py` -> EXPECT ALLOW. -q is in the allowed flag
    set; operand is inside the synthetic worktree."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist, f"pytest -q {posix_tests_path}", _bounds(repo, wt)
    )
    assert v.decision == GatewayDecision.ALLOWED, f"happy-path: got {v}"


def test_probe_am007_tb_no_allow(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_25'): `pytest --tb=no
    tests/test_existing.py` -> EXPECT ALLOW. --tb is matched by prefix
    (split on first '='); --tb is in the allowed flag set; any --tb=<val>
    form is admitted per the operator-ratified --tb Note."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist, f"pytest --tb=no {posix_tests_path}", _bounds(repo, wt)
    )
    assert v.decision == GatewayDecision.ALLOWED, f"happy-path: got {v}"


def test_probe_am007_tb_long_allow(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_25b'): `pytest --tb=long
    tests/test_existing.py` -> EXPECT ALLOW. Documents the operator-
    ratified ruling that --tb-prefix admits ALL --tb=<value> forms (no,
    short, long, line, native, auto); --tb is traceback-verbosity only,
    no code-loading / config-redirect / import-semantics surface."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist,
        f"pytest --tb=long {posix_tests_path}",
        _bounds(repo, wt),
    )
    assert v.decision == GatewayDecision.ALLOWED, f"happy-path: got {v}"


def test_probe_am007_bare_allow(
    synthetic_repo: tuple[Path, Path], am007_allowlist: CommandAllowlist
) -> None:
    """Probe (was operator's 'probe_26'): `pytest
    tests/test_existing.py` -> EXPECT ALLOW. Bare invocation, no flags;
    operand inside worktree."""
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = _cmd_verdict_am007(
        am007_allowlist, f"pytest {posix_tests_path}", _bounds(repo, wt)
    )
    assert v.decision == GatewayDecision.ALLOWED, f"happy-path: got {v}"


# ============================================================================
# Module-level contract sanity (operator-ratified 2026-06-04):
# TEST_RUN_ALLOWLIST is populated, NOT empty. These tests were emptiness
# guards originally; they now pin the populated shape so future drift
# (a worker silently widening the allowlist, an editor mass-edit, an
# automated re-formatter eating a kwarg) surfaces as a contract failure
# rather than a silent permission grant.
# ============================================================================


def test_module_level_allowlist_is_populated_per_am007() -> None:
    """Contract: TEST_RUN_ALLOWLIST is populated with the
    operator-ratified shape. Growing the set is an operator amendment
    (same authorization shape as ADR-015 + ADR-026 D1/D2). This is the
    populated-shape regression guard — was emptiness-guard originally."""
    from command_allowlist import TEST_RUN_ALLOWLIST
    assert TEST_RUN_ALLOWLIST.programs == frozenset({"pytest"})
    assert TEST_RUN_ALLOWLIST.program_path_positions == {"pytest": (-1,)}
    assert TEST_RUN_ALLOWLIST.program_subcommands == {}
    assert TEST_RUN_ALLOWLIST.subcommand_operand_bound == {}
    assert TEST_RUN_ALLOWLIST.program_allowed_flags == {
        "pytest": frozenset({"-q", "-x", "--tb"})
    }


def test_module_level_populated_allowlist_denies_disallowed_flag(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """Contract: the production TEST_RUN_ALLOWLIST denies a real
    pytest invocation carrying a disallowed flag (`-p` plugin-load is
    NOT in the allowed set) at framework.bounds.cmd.flag (Step 3d). Was
    the deny-real-pytest emptiness proof originally; flipped to assert
    the Step 3d denial."""
    from command_allowlist import TEST_RUN_ALLOWLIST
    from policy import BOUNDS_CMD_FLAG_CAPABILITY
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = is_command_in_allowlist(
        tool_name="Bash",
        tool_input={"command": f"pytest -p evil_plugin {posix_tests_path}"},
        allowlist=TEST_RUN_ALLOWLIST,
        bounds=_bounds(repo, wt),
        authorized_capability="test.run",
    )
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == BOUNDS_CMD_FLAG_CAPABILITY


def test_module_level_populated_allowlist_allows_real_pytest(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """Contract: the production TEST_RUN_ALLOWLIST allows a real
    pytest invocation with an allowed flag (`-q`) + worktree-interior
    operand at argv[-1] — the closure path the entire M-1 test_output
    surface depends on."""
    from command_allowlist import TEST_RUN_ALLOWLIST
    repo, wt = synthetic_repo
    posix_tests_path = (wt / "tests" / "test_existing.py").as_posix()
    v = is_command_in_allowlist(
        tool_name="Bash",
        tool_input={"command": f"pytest -q {posix_tests_path}"},
        allowlist=TEST_RUN_ALLOWLIST,
        bounds=_bounds(repo, wt),
        authorized_capability="test.run",
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_CMD_CAPABILITY


def test_non_test_run_capability_bypasses_allowlist(
    synthetic_repo: tuple[Path, Path]
) -> None:
    """Bash authorized by shell.exec.sandboxed (NOT in the capability →
    allowlist dispatch map) bypasses the allowlist gate — it has its own
    enforcement layer (sandbox flag in the runner per concern C2; in
    practice ADR-027 D2 also blocks this capability from reaching here via
    construction-time rejection, but the gate-level documented bypass is
    preserved as ADR-027 D2's 'sole defense, not a backstop' invariant).

    Fixture migrated for ADR-026: under the new API the dispatch map is
    consulted internally (test.run/shell.read/worktree.commit have
    allowlists; everything else is bypass). The explicit allowlist arg
    was a no-op under the old API too (the capability check ran first);
    here we drop it to exercise the production code path the hook uses."""
    repo, wt = synthetic_repo
    v = is_command_in_allowlist(
        tool_name="Bash",
        tool_input={"command": "any command including; bad chars"},
        bounds=_bounds(repo, wt),
        authorized_capability="shell.exec.sandboxed",
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == BOUNDS_CMD_CAPABILITY


def test_charset_regex_is_anchored() -> None:
    """Sanity: ALLOWED_CHARSET is whole-string anchored (^...$). A prefix
    of allowed chars + a disallowed suffix must fail (not partial-match)."""
    assert ALLOWED_CHARSET.match("pytest")
    assert not ALLOWED_CHARSET.match("pytest;")
    assert not ALLOWED_CHARSET.match(";pytest")
    assert not ALLOWED_CHARSET.match("pytest tests/ && curl")
