"""
command_allowlist.py -- structural definitions for the test.run command
allowlist gate. SHAPE only at this commit; CONTENTS are operator-ratified
separately before being filled in.

Where it lives: sibling of policy.py + mcp_capability_map.py. Imported by
`policy.is_command_in_allowlist`. Framework-CONSTANT, not per-dispatch:
every dispatch with `test.run` in scope sees the same allowlist. Growing
the list is an operator amendment (same authorization shape as ADR-015
amendments for MCP tools).

What's here:
  - ALLOWED_CHARSET: the whole-command character whitelist (runs BEFORE
    argv parsing in the policy gate).
  - CommandAllowlist: the frozen dataclass declaring programs +
    per-program path positions.
  - TEST_RUN_ALLOWLIST: the module-level constant the gate consults.
    Populated (operator-ratified 2026-06-04):
    `programs={pytest}`, `program_path_positions={pytest:(-1,)}` (last-arg
    path-bounded to the worktree), `program_allowed_flags={pytest:{-q,-x,
    --tb}}` (closed-by-default flag set; --tb-prefix admits all --tb=<val>
    forms — traceback-verbosity-only, no ACE surface).
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Final


# ---------------------------------------------------------------------------
# Whole-command charset gate.
#
# Matches the ENTIRE Bash command string and runs BEFORE argv parsing.
# argv[0] being in the program allowlist does NOT bypass this gate.
# WHITELIST-only: every permitted character is here because some legitimate
# test invocation needs it; nothing else.
#
# Per-character justification (positive list):
#   A-Za-z0-9   identifiers, flag tokens, version strings
#   _           identifiers (test_foo, --no-cov)
#   -           flag prefixes (--maxfail=1)
#   /           POSIX path separators (tests/unit/)
#   .           dotted paths + extensions (tests/test_foo.py)
#   :           pytest node ids (file.py::Class::method)
#   space       argument separator
#   =           --key=value flag form
#   [ ]         pytest parametrize ids (test_foo[case1])
#   ,           --addopts comma-list
#
# EXPLICITLY EXCLUDED (each blocks a known attack family):
#   $       command substitution / variable expansion
#   `       command substitution (backticks)
#   ( )     subshell grouping
#   < >     IO redirection
#   ;       statement separator
#   & |     pipe / background / chain
#   \n \r   newline injection
#   "  '    quoting (shlex parsing is strict; quoting adds ambiguity)
#   \       escape sequences
#   #       comment injection (silent truncation)
#   *  ?    glob expansion
#   ~       home expansion
ALLOWED_CHARSET: Final[re.Pattern[str]] = re.compile(
    r"^[A-Za-z0-9_\-./:= \[\],]+$"
)


@dataclass(frozen=True)
class CommandAllowlist:
    """Framework-constant test.run command allowlist.

    SHAPE only at this commit. Contents (the `programs` set and the
    `program_path_positions` map) are operator-ratified separately
    BEFORE being filled in. With both empty, every test.run-scoped Bash
    command that passes the charset gate is denied at the
    program-membership check -- this is the closed-by-default property.

    Fields:
      programs: argv[0] basename allowlist. CASE-SENSITIVE exact match.
        Intentionally diverges from is_handoff_write_exemption's
        normcase: path containment uses normcase (the filesystem decides
        identity); program allowlisting uses exact match (the framework
        decides identity, and case-spoof on Windows would otherwise open
        a hole). Do not "fix" to consistency.

      program_path_positions: per-program declared argv positions that
        must be path-bounded to the worktree. 0-indexed (program slot
        is 0); negative indices supported (-1 = last). A declared
        position resolving to <= 0 or out of range is DENIED at
        framework.bounds.cmd.path_arg (the allowlist declared a shape
        the invocation didn't supply).

      program_subcommands: per-program allowlist of bare subcommands
        (argv[1]) — ADR-026 D2 addition. Programs without an entry are
        not subcommand-gated. Programs WITH an entry require argv[1] to
        be a bare subcommand (no leading `-` per operator ruling 2) AND
        a member of the listed frozenset; otherwise DENIED at
        framework.bounds.cmd.subcommand.

      subcommand_operand_bound: per (program, subcommand) operand
        path-bounding rule — ADR-026 D2 + operator ruling 1. Keyed by
        program, value is the frozenset of subcommands whose every
        NON-FLAG operand (argv element after the subcommand not starting
        with `-`) must be inside `bounds.worktree_root`. Operands that
        resolve outside DENY at framework.bounds.cmd.path_arg. Flag args
        (starting with `-`) are skipped; this means messages and other
        flag-values pass through unchecked.

      program_allowed_flags: per-program flag allowlist — schema
        addition. Keyed by program; value is the frozenset of allowed
        flag prefixes. FIELD-ONLY at this commit (no-op default;
        enforcement deferred to the Phase 2C policy.py edit). When
        the enforcement step lands, semantics will be: for any program
        listed as a key, every argv[i>=1] token starting with `-` is
        matched against the frozenset by splitting on the first `=`
        (so `--rootdir=/etc` is matched as `--rootdir`); flag tokens
        NOT in the set DENY at framework.bounds.cmd.flag. Programs
        WITHOUT an entry are not flag-gated.
    """

    programs: frozenset[str]
    program_path_positions: dict[str, tuple[int, ...]]
    program_subcommands: dict[str, frozenset[str]] = field(default_factory=dict)
    subcommand_operand_bound: dict[str, frozenset[str]] = field(
        default_factory=dict
    )
    # Schema addition — field-only at this commit; enforcement in
    # policy.py is deferred to the same amendment's Phase 2C edit. With
    # an empty default and no enforcement step, gate behavior is
    # unchanged for D1 (shell.read) and D2 (worktree.commit) which both
    # omit this field at construction and therefore receive the empty
    # default.
    program_allowed_flags: dict[str, frozenset[str]] = field(
        default_factory=dict
    )


# Operator-ratified 2026-06-04 — module-level constant the gate
# consults. Populated:
#   - programs={"pytest"}: the framework's test harness (real test.run
#     invocation surface at HEAD per the Phase-1 audit; bare `pytest` from
#     tools/ cwd is what actually runs the suite — `uv run pytest` is
#     broken by the `jsonschema` deps gap, separately deferred).
#   - program_path_positions={"pytest": (-1,)}: argv[-1] must be inside
#     the worktree (Step 4 path-bound). Brittle to flag ordering, by
#     design — workers must keep the test target at the trailing slot.
#   - program_allowed_flags={"pytest": frozenset({"-q","-x","--tb"})}:
#     Step 3d closed-by-default flag set. -q quiet output, -x stop-on-
#     first-failure, --tb traceback verbosity (prefix-match admits ALL
#     --tb=<value> forms — no, short, long, line, native, auto — per
#     operator-ratified note). Excluded by intent (ACE surface):
#     -p (arbitrary plugin load), -c (custom config from arbitrary path),
#     --rootdir (conftest redirect outside worktree), -o (ini-option
#     override), --import-mode (module-load-semantics swap). Growing the
#     set is an operator amendment (same authorization shape as ADR-015 +
#     ADR-026 D1/D2).
TEST_RUN_ALLOWLIST: Final[CommandAllowlist] = CommandAllowlist(
    programs=frozenset({"pytest"}),
    program_path_positions={"pytest": (-1,)},
    program_subcommands={},
    subcommand_operand_bound={},
    program_allowed_flags={"pytest": frozenset({"-q", "-x", "--tb"})},
)


# ADR-026 D1 — shell.read read-tier allowlist.
# Programs ratified by the ADR; contents match ADR-026 §Decision 1 verbatim.
# Each program is safe under every argument the charset gate permits (per
# the inclusion criterion); `find` is EXCLUDED because its `-delete` primary
# is charset-permitted and `argv[0]`-granular allowlist cannot distinguish
# read traversal from destruction.
SHELL_READ_ALLOWLIST: Final[CommandAllowlist] = CommandAllowlist(
    programs=frozenset({"cat", "head", "tail", "wc", "ls", "grep"}),
    program_path_positions={},   # no per-program path-position bounding;
    # read tools accept paths but the charset gate already prevents
    # shell-injection and the operations don't mutate state, so bounding
    # path arguments to the worktree would be over-restrictive (a
    # shell.read-scoped worker can `cat .mission/spec/v010.yaml` from
    # anywhere in repo_root).
    program_subcommands={},
    subcommand_operand_bound={},
)


# ADR-026 D2 — worktree.commit git-subcommand allowlist.
# Subcommands ratified by the ADR verbatim. Egress subcommands (push, fetch,
# pull, clone, remote) and destructive/history-rewriting subcommands (reset,
# clean, checkout, switch, restore, stash, rebase, merge, cherry-pick, gc,
# prune) are explicitly EXCLUDED. `config` excluded (persistent
# configuration). `branch` excluded under the inclusion criterion (argv[1]-
# granularity cannot distinguish create from `-d`/`-D`).
#
# Operator ruling 1: every NON-FLAG operand of `git add` is path-bounded to
# the worktree (subcommand_operand_bound entry below). Other allowed
# subcommands take flags/messages/refs, not worktree write-paths, so are
# NOT operand-bound.
#
# Operator ruling 2: argv[1] must be a bare subcommand (no leading `-`).
# Enforced by the gate's subcommand check; pre-subcommand global flags
# like `-C`, `-c`, `--git-dir` are rejected (config-injection vectors).
WORKTREE_COMMIT_ALLOWLIST: Final[CommandAllowlist] = CommandAllowlist(
    programs=frozenset({"git"}),
    program_path_positions={},   # operand bounding is per-subcommand below
    program_subcommands={
        "git": frozenset({
            "status", "log", "diff", "show",
            "rev-parse", "rev-list",
            "add", "commit",
        }),
    },
    subcommand_operand_bound={
        # `git add <pathspec>...` — every non-flag operand must be inside
        # the worktree. Prevents `git add ../outside` (escape) in any
        # operand position, not just the last.
        "git": frozenset({"add"}),
    },
)
