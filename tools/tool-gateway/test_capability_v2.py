"""
ADR-026 contract tests (the capability model v2 gate changes).

Per .mission-runtime/preflight/adr-026-027-impl-design.md Parts D.1, D.2, D.3,
D.6 — the OPERATOR-REVIEWED test contract committed BEFORE implementation.
Tests come from the contract, not from "whatever the implementation does."

Covers four decision blocks from ADR-026:
  - D1: shell.read read-tier (12 cases)
  - D2: worktree.commit git-subcommand tier (14 base + operator-ruled
        escape/global-flag cases per the implementation task)
  - D3: capability-dispatch regression (test.run + package.install.allowlisted
        unchanged) (4 cases)
  - D6: harness-internal mapping (TodoWrite/ToolSearch/etc ALLOW;
        WebFetch/WebSearch deliberately excluded — egress) (6 cases)

D.5 (Decision-E deny-attribution) is in Step 3, not here.

Two OPERATOR RULINGS implemented (per the task brief):
  - Ruling 1: for worktree.commit, after the subcommand check, if subcommand
    == "add" then EVERY non-flag operand is path-bounded to the worktree.
    Other allowed subcommands (commit/status/log/etc) take no operand
    bounding (they accept flags/messages/refs).
  - Ruling 2: argv[1] MUST be a bare subcommand name (no leading "-").
    Pre-subcommand global flags like `-C`, `-c`, `--git-dir` → DENY.
    This guarantees argv[1] is the real subcommand so operand positions align.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from policy import (
    BOUNDS_CMD_ARGV_CAPABILITY,
    BOUNDS_CMD_CAPABILITY,
    BOUNDS_CMD_CHARSET_CAPABILITY,
    BOUNDS_CMD_PATH_ARG_CAPABILITY,
    BOUNDS_CMD_PROGRAM_CAPABILITY,
    Bounds,
    Gateway,
    is_command_in_allowlist,
)
from mcp_capability_map import CapabilityMap
from schemas import GatewayDecision


# Constants the implementation declares (Step 2 adds them); tests import by
# name so a typo is caught at collection rather than as a string-equality
# failure deeper in the test body.
from policy import BOUNDS_CMD_SUBCOMMAND_CAPABILITY  # new sentinel (Step 2)


@pytest.fixture
def synthetic_repo(tmp_path: Path) -> tuple[Path, Path]:
    """Synthetic repo with embedded worktree, identical to test_bounds_predicates.py
    fixture (so the new tests share the same path-bounds substrate)."""
    repo = tmp_path / "repo"
    worktree = repo / ".mission-runtime" / "worktrees" / "wt-X" / "worktree"
    (repo / ".mission" / "spec").mkdir(parents=True)
    (repo / ".mission" / "spec" / "v010.yaml").write_text("# fixture\n")
    (worktree / "src").mkdir(parents=True)
    (worktree / "tests").mkdir(parents=True)
    (worktree / "tests" / "test_existing.py").write_text("# fixture\n")
    (worktree / "src" / "file_a.py").write_text("# fixture\n")
    return repo, worktree


def _bounds(repo: Path, worktree: Path) -> Bounds:
    return Bounds(worktree_root=str(worktree), repo_root=str(repo))


# ============================================================================
# D.1 — shell.read (Bash + closed allowlist {cat, head, tail, wc, ls, grep})
# ============================================================================

class TestD1ShellRead:
    """ADR-026 D1: shell.read read-tier. Authorizes Bash with the read-program
    allowlist; find is EXCLUDED under the inclusion criterion (find -delete is
    charset-permitted)."""

    def test_d1a_wc_allowed(self, synthetic_repo) -> None:
        """D.1.a: `wc -l <worktree-file>` ALLOW under shell.read."""
        repo, worktree = synthetic_repo
        file_path = (worktree / "src" / "file_a.py").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"wc -l {file_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"
        assert v.capability_tag == BOUNDS_CMD_CAPABILITY

    def test_d1b_cat_allowed(self, synthetic_repo) -> None:
        """D.1.b: `cat <worktree-file>` ALLOW under shell.read."""
        repo, worktree = synthetic_repo
        file_path = (worktree / "src" / "file_a.py").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"cat {file_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d1c_ls_allowed(self, synthetic_repo) -> None:
        """D.1.c: `ls <worktree-dir>` ALLOW."""
        repo, worktree = synthetic_repo
        dir_path = (worktree / "src").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"ls {dir_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d1d_grep_allowed(self, synthetic_repo) -> None:
        """D.1.d: `grep pattern <file>` ALLOW."""
        repo, worktree = synthetic_repo
        file_path = (worktree / "src" / "file_a.py").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"grep pattern {file_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d1e_head_allowed(self, synthetic_repo) -> None:
        """D.1.e: `head -5 <file>` ALLOW."""
        repo, worktree = synthetic_repo
        file_path = (worktree / "src" / "file_a.py").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"head -5 {file_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d1f_tail_allowed(self, synthetic_repo) -> None:
        """D.1.f: `tail -5 <file>` ALLOW."""
        repo, worktree = synthetic_repo
        file_path = (worktree / "src" / "file_a.py").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"tail -5 {file_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d1g_find_denied_at_program(self, synthetic_repo) -> None:
        """D.1.g: `find . -type d` DENY — find NOT in shell.read programs
        (inclusion-criterion exclusion: find's safety depends on arguments;
        argv[0]-granular allowlist cannot distinguish read traversal from
        side-effecting primaries)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "find . -type d"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_PROGRAM_CAPABILITY
        assert "find" in (v.reason or "")

    def test_d1h_find_delete_denied_at_program(self, synthetic_repo) -> None:
        """D.1.h: `find . -delete` DENY — proves find is denied even for a
        charset-passing destructive form (the exact threat the inclusion
        criterion guards against)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "find . -delete"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_PROGRAM_CAPABILITY

    def test_d1i_pipe_denied_at_charset(self, synthetic_repo) -> None:
        """D.1.i: `cat |tail file` DENY at charset (pipe excluded)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "cat |tail file"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY

    def test_d1j_semicolon_denied_at_charset(self, synthetic_repo) -> None:
        """D.1.j: `cat file;rm x` DENY at charset (semicolon excluded)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "cat file;rm x"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY

    def test_d1k_redirect_denied_at_charset(self, synthetic_repo) -> None:
        """D.1.k: `cat > file` DENY at charset (redirect excluded)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "cat > file"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY

    def test_d1l_python_denied_at_program(self, synthetic_repo) -> None:
        """D.1.l: `python file.py` DENY at program (python not in shell.read
        allowlist; arbitrary-exec stays denied even under read-tier)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "python file.py"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.read",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_PROGRAM_CAPABILITY


# ============================================================================
# D.2 — worktree.commit (Bash + git-subcommand allowlist + operator rulings)
# ============================================================================

class TestD2WorktreeCommit:
    """ADR-026 D2 + operator rulings: worktree.commit authorizes Bash with a
    git-subcommand allowlist {status, log, diff, show, rev-parse, rev-list,
    add, commit}. Ruling 1: `git add` operands are path-bounded to worktree.
    Ruling 2: argv[1] must be a bare subcommand (no leading `-`)."""

    def test_d2a_git_commit_msg_allowed(self, synthetic_repo) -> None:
        """D.2.a: `git commit -m msg` ALLOW. Message is flag-value, not path."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git commit -m msg"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"
        assert v.capability_tag == BOUNDS_CMD_CAPABILITY

    def test_d2a2_git_commit_msg_with_slash_allowed(self, synthetic_repo) -> None:
        """D.2.a': `git commit -m fix-tests/foo` ALLOW — even though message
        contains `/`, it is a flag-value not a path; commit subcommand has NO
        operand bounding so the message isn't routed through is_path_in_bounds."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git commit -m fix-tests/foo"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d2b_git_status_allowed(self, synthetic_repo) -> None:
        """D.2.b: `git status` ALLOW."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git status"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d2c_git_log_oneline_allowed(self, synthetic_repo) -> None:
        """D.2.c: `git log --oneline` ALLOW."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git log --oneline"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d2d_git_add_inside_worktree_allowed(self, synthetic_repo) -> None:
        """D.2.d (operator-ruling 1): `git add <worktree-file>` ALLOW — operand
        is inside worktree, path-bound check passes."""
        repo, worktree = synthetic_repo
        file_path = (worktree / "src" / "file_a.py").as_posix()
        v = is_command_in_allowlist(
            "Bash", {"command": f"git add {file_path}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d2e_git_diff_allowed(self, synthetic_repo) -> None:
        """D.2.e: `git diff` ALLOW."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git diff"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d2f_git_rev_parse_head_allowed(self, synthetic_repo) -> None:
        """D.2.f: `git rev-parse HEAD` ALLOW. Hyphenated subcommand is a
        single subcommand string passing the frozenset check."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git rev-parse HEAD"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"

    def test_d2g_git_push_denied_at_subcommand(self, synthetic_repo) -> None:
        """D.2.g: `git push` DENY at subcommand — push is egress, NOT in
        worktree.commit allowlist."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git push"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY
        assert "push" in (v.reason or "")

    def test_d2h_git_reset_hard_denied_at_subcommand(self, synthetic_repo) -> None:
        """D.2.h: `git reset --hard` DENY at subcommand — reset is destructive."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git reset --hard"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2i_git_checkout_denied_at_subcommand(self, synthetic_repo) -> None:
        """D.2.i: `git checkout main` DENY at subcommand — checkout is
        history-rewriting/branch-switching."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git checkout main"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2j_git_branch_delete_denied_at_subcommand(self, synthetic_repo) -> None:
        """D.2.j: `git branch -d feature` DENY at subcommand — branch excluded
        under inclusion criterion (argv[1]-granularity cannot distinguish
        create from `-d`/`-D`)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git branch -d feature"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2k_git_config_denied_at_subcommand(self, synthetic_repo) -> None:
        """D.2.k: `git config user.email x` DENY at subcommand — config is
        persistent-configuration concern."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git config user.email x"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2l_git_fetch_denied_at_subcommand(self, synthetic_repo) -> None:
        """D.2.l: `git fetch` DENY at subcommand — egress."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git fetch"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2m_bare_git_denied(self, synthetic_repo) -> None:
        """D.2.m: bare `git` (no subcommand) DENY at subcommand."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2n_npm_denied_at_program(self, synthetic_repo) -> None:
        """D.2.n: `npm test` DENY at program — non-git program not in
        WORKTREE_COMMIT_ALLOWLIST."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "npm test"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_PROGRAM_CAPABILITY

    # --- Operator-ruled ESCAPE cases (MANDATORY per the task brief) ---

    def test_d2_escape_last_position_denied(self, synthetic_repo) -> None:
        """OPERATOR-RULING 1 (escape last position): `git add ../outside`
        DENY at framework.bounds.cmd.path_arg — operand resolves outside
        worktree. This is THE ESCAPE CASE; must DENY."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git add ../outside-worktree.txt"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED, (
            f"ESCAPE CASE MUST DENY; got {v.decision} reason={v.reason}"
        )
        assert v.capability_tag == BOUNDS_CMD_PATH_ARG_CAPABILITY

    def test_d2_escape_non_last_position_denied(self, synthetic_repo) -> None:
        """OPERATOR-RULING 1 (escape non-last position): `git add file1
        ../outside file2` DENY at framework.bounds.cmd.path_arg — proves the
        rule bounds ALL add-operands, not just argv[-1]."""
        repo, worktree = synthetic_repo
        file1 = (worktree / "src" / "file_a.py").as_posix()
        file2 = (worktree / "tests" / "test_existing.py").as_posix()
        v = is_command_in_allowlist(
            "Bash",
            {"command": f"git add {file1} ../outside.txt {file2}"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED, (
            f"NON-LAST ESCAPE CASE MUST DENY; got {v.decision} reason={v.reason}"
        )
        assert v.capability_tag == BOUNDS_CMD_PATH_ARG_CAPABILITY

    # --- Operator-ruled GLOBAL-FLAG prohibition (Ruling 2) ---

    def test_d2_global_flag_C_denied(self, synthetic_repo) -> None:
        """OPERATOR-RULING 2: `git -C /other commit` DENY — argv[1]=='-C'
        starts with `-`, prohibited (a global flag, not a bare subcommand)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git -C /other commit"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY

    def test_d2_global_flag_c_config_denied(self, synthetic_repo) -> None:
        """OPERATOR-RULING 2: `git -c core.hooksPath=/x commit` DENY — argv[1]
        is `-c` (config injection vector blocked)."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "git -c core.hooksPath=/x commit"},
            bounds=_bounds(repo, worktree),
            authorized_capability="worktree.commit",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_SUBCOMMAND_CAPABILITY


# ============================================================================
# D.3 — capability-dispatch regression
# ============================================================================

class TestD3CapabilityDispatchRegression:
    """ADR-026: the dispatch generalization preserves test.run + package.install
    behavior unchanged."""

    def test_d3a_test_run_with_populated_allowlist_per_am007(
        self, synthetic_repo
    ) -> None:
        """D.3.a: TEST_RUN_ALLOWLIST is now populated with
        programs={"pytest"}, program_path_positions={"pytest":(-1,)}, and
        program_allowed_flags={"pytest":{"-q","-x","--tb"}}
        (operator-ratified 2026-06-04). The earlier expectation was DENY
        at program (empty allowlist); the current expectation is ALLOW —
        `pytest tests/` resolves to `<worktree>/tests/` (relative path joined
        against the worktree_root via os.path.join), which IS inside the
        synthetic worktree's bounded root (the fixture creates tests/ +
        test_existing.py). The dispatch generalization (ADR-026) still
        preserves the test.run-routes-to-TEST_RUN_ALLOWLIST property; the
        allowlist contents now allow the pytest invocation through the
        terminal ALLOW capability."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "pytest tests/"},
            bounds=_bounds(repo, worktree),
            authorized_capability="test.run",
        )
        assert v.decision == GatewayDecision.ALLOWED
        assert v.capability_tag == BOUNDS_CMD_CAPABILITY

    def test_d3b_package_install_still_bypasses(self, synthetic_repo) -> None:
        """D.3.b: any Bash command under package.install.allowlisted ALLOWS at
        the gate (documented allowlist-bypass; its enforcement is separate).
        Regression check the dispatch fallthrough preserves this."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "anything goes"},
            bounds=_bounds(repo, worktree),
            authorized_capability="package.install.allowlisted",
        )
        assert v.decision == GatewayDecision.ALLOWED
        assert v.capability_tag == BOUNDS_CMD_CAPABILITY

    def test_d3c_shell_exec_sandboxed_still_bypasses_at_gate(
        self, synthetic_repo
    ) -> None:
        """D.3.c: shell.exec.sandboxed-authorized Bash ALLOWs at the gate even
        post-ADR-026. ADR-027 D2 prevents this capability from REACHING the
        gate via construction-time rejection, but if it does, the gateway has
        no second wall — confirming ADR-027 D2's 'sole defense, not a backstop'
        invariant. Regression check."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "anything goes including chains&pipes"},
            bounds=_bounds(repo, worktree),
            authorized_capability="shell.exec.sandboxed",
        )
        assert v.decision == GatewayDecision.ALLOWED

    def test_d3d_test_run_charset_gate_still_fires(self, synthetic_repo) -> None:
        """D.3.d: charset gate runs FIRST under test.run (before program-membership);
        a command with `;` is denied at charset, not program. Regression check
        the dispatch generalization doesn't reorder the pipeline."""
        repo, worktree = synthetic_repo
        v = is_command_in_allowlist(
            "Bash", {"command": "pytest;rm x"},
            bounds=_bounds(repo, worktree),
            authorized_capability="test.run",
        )
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == BOUNDS_CMD_CHARSET_CAPABILITY


# ============================================================================
# D.6 — harness-internal mapping
# ============================================================================

class TestD6HarnessInternal:
    """ADR-026 D4: TodoWrite/ToolSearch/Skill/Task*/Monitor/etc. mapped to a
    framework.* allow so the harness's own machinery is permitted without a
    worker grant. WebFetch + WebSearch deliberately EXCLUDED (they are egress,
    not harness machinery; mapping them would breach ADR-027 D2's
    egress-deferral discipline)."""

    @pytest.fixture
    def gateway(self) -> Gateway:
        return Gateway(CapabilityMap.default())

    def test_d6a_todowrite_allowed_regardless_of_scope(self, gateway: Gateway) -> None:
        """D.6.a: `Gateway.check('TodoWrite', [])` ALLOW with capability_tag
        starting `framework.harness.`. Workers cannot request the tag; the
        tag authorizes the tool."""
        v = gateway.check("TodoWrite", tool_scope=["repo.read"])
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"
        assert v.capability_tag.startswith("framework.harness.")

    def test_d6b_toolsearch_allowed_regardless_of_scope(self, gateway: Gateway) -> None:
        """D.6.b: ToolSearch ALLOW under framework.harness.* mapping."""
        v = gateway.check("ToolSearch", tool_scope=["repo.read"])
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"
        assert v.capability_tag.startswith("framework.harness.")

    def test_d6c_monitor_allowed_regardless_of_scope(self, gateway: Gateway) -> None:
        """D.6.c: Monitor ALLOW under framework.harness.* mapping."""
        v = gateway.check("Monitor", tool_scope=["repo.read"])
        assert v.decision == GatewayDecision.ALLOWED, f"reason: {v.reason}"
        assert v.capability_tag.startswith("framework.harness.")

    def test_d6d_webfetch_denied_egress_excluded(self, gateway: Gateway) -> None:
        """D.6.d: WebFetch DENY at (unmapped) — deliberately NOT in the
        harness mapping because it is egress, not harness machinery. Mapping
        it would breach ADR-027 D2's egress-deferral discipline."""
        v = gateway.check("WebFetch", tool_scope=["repo.read"])
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == "(unmapped)"

    def test_d6e_websearch_denied_egress_excluded(self, gateway: Gateway) -> None:
        """D.6.e: WebSearch DENY — same as WebFetch (egress, not harness)."""
        v = gateway.check("WebSearch", tool_scope=["repo.read"])
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == "(unmapped)"

    def test_d6f_unknown_tool_still_denies(self, gateway: Gateway) -> None:
        """D.6.f: a genuinely unknown tool DENY at (unmapped). The harness
        mapping does NOT change the default-DENY for unmapped tools."""
        v = gateway.check("ToolThatDoesNotExist", tool_scope=["repo.read"])
        assert v.decision == GatewayDecision.DENIED
        assert v.capability_tag == "(unmapped)"
