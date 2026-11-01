"""
policy.py -- the tool gateway. Decides whether a worker's tool call is
permitted given its declared tool_scope.

Per brief §6.2 (Tool Gateway) + the step-4 design (operator-approved 2026-05-29):
- The gateway is PURE DECISION. It does not import trace_store,
  audit_log, or any I/O surface. Caller (the worker-runner) takes the
  Verdict and decides downstream behavior (trace emission, tool-result
  conversion, retry policy).
- Verdict is structured data, not an exception. Denials are first-class
  trace events; raising would force try/except control flow at every
  call site.
- The gateway does NOT inspect tool arguments. Path-inside-worktree
  (worktree.write) and actual sandbox-flag selection (shell.exec.*)
  are pre-tool enforcement in the gateway hook (per brief §6.2,
  "rejected before reaching the tool"); the runner cross-checks
  post-hoc.

Resolution algorithm:
  candidates = capability_map.candidate_tags_for(tool_name)
  if not candidates:
      DENIED with reason="unmapped" -- tool not covered by any
      capability the framework declares.
  matching = candidates & set(tool_scope)
  if matching:
      ALLOWED with capability_tag = deterministically-picked tag
      (sorted alphabetically; auditable + reproducible).
  else:
      DENIED with capability_tag = the first candidate that COULD
      have authorized this call (sorted alphabetically) +
      reason naming what tag(s) the worker would need.
"""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from typing import Any, Optional

from schemas import GatewayDecision

from command_allowlist import ALLOWED_CHARSET, CommandAllowlist
from mcp_capability_map import CapabilityMap

_UNMAPPED_SENTINEL = "(unmapped)"

# Decision-E (ADR-026 §"Note on Decision E"): the multi-candidate DENY
# sentinel. When Gateway.check DENIES a tool that has multiple covering
# capability candidates and none in worker scope, the `capability_tag`
# field is this sentinel rather than `sorted(candidates)[0]`. The
# pre-fix behavior reported the alphabetical-first candidate
# (`package.install.allowlisted` for any denied Bash, since it sorts
# first among Bash's four candidates) — misleading to audit consumers
# who reasonably expected `capability_tag` to name the tag the worker
# meant to request. The reason string still lists all candidates and
# is the audit-rich field.
#
# Single-candidate DENYs are unchanged: they name the single candidate
# (which IS what the worker would have needed). ALLOWED is unchanged:
# `sorted(matching)[0]` is the deterministic pick of WHICH SCOPE TAG
# authorized, not "which of all candidates."
MULTI_CANDIDATE_DENY_SENTINEL = "framework.deny.multi_candidate"

# Capability tag used in the Verdict when the handoff-protocol exemption
# fires. NOT a real capability in the map -- it is an observable marker
# the trace store records so a future audit cannot mistake an exempted
# Write for a normal scope-authorized one. See `is_handoff_write_exemption`.
HANDOFF_EXEMPTION_CAPABILITY = "framework.handoff_exemption"

# Bounds-gate sentinel capability tags (per fork-2 ruling). Namespaced
# under `framework.` to signal "gate verdict" vs. "worker capability"
# to a trace auditor -- same convention as HANDOFF_EXEMPTION_CAPABILITY.
# These are CLOSED additions to the framework-tag namespace; new
# bounds-gate verdict types require operator ruling, not silent expansion.
BOUNDS_PATH_WORKTREE_CAPABILITY = "framework.bounds.path.worktree"
BOUNDS_PATH_REPO_CAPABILITY = "framework.bounds.path.repo"
BOUNDS_CMD_CHARSET_CAPABILITY = "framework.bounds.cmd.charset"
BOUNDS_CMD_ARGV_CAPABILITY = "framework.bounds.cmd.argv"
BOUNDS_CMD_PROGRAM_CAPABILITY = "framework.bounds.cmd.program"
BOUNDS_CMD_PATH_ARG_CAPABILITY = "framework.bounds.cmd.path_arg"
BOUNDS_CMD_SUBCOMMAND_CAPABILITY = "framework.bounds.cmd.subcommand"  # ADR-026 D2
BOUNDS_CMD_FLAG_CAPABILITY = "framework.bounds.cmd.flag"  # Step 3d
BOUNDS_CMD_CAPABILITY = "framework.bounds.cmd"  # terminal ALLOW for Bash


def is_handoff_write_exemption(
    tool_name: str,
    tool_input: Any,
    handoff_path: str,
) -> bool:
    """Framework-protocol exemption: the worker's handoff Write is the
    one channel its dispatch results propagate (§5). Gating it by the
    task `tool_scope` conflates protocol-action with task-action -- a
    `repo.read`-scoped worker still must be able to write its handoff.
    Exempt the EXACT handoff_path Write from scope gating.

    **HARD CONSTRAINT: exact-path match, not prefix/pattern.** The
    worker may Write its one handoff.json and nothing else. The
    read-only guarantee holds for every other path; the exemption does
    NOT leak to `tool_scope.json`, `hook-settings.json`, or anything
    else under the dispatch dir.

    **Tool: Write only.** The handoff protocol is "write a fresh
    handoff.json on exit"; Edit (which presumes a prior file) is not
    part of the protocol and is NOT exempted.

    Normalization: paths are compared by `os.path.normcase(normpath(
    abspath(...)))` -- case-insensitive + slash-neutral on Windows,
    plain on POSIX. NO `resolve()` because the handoff file does not
    exist at hook-check time.

    Both the gateway_hook subprocess and the runner's local-gateway
    cross-check (`_reconstruct_verdict`) call this helper. They MUST
    agree -- otherwise a §6.2 EscalationTrace fires falsely on every
    handoff Write.
    """
    if tool_name != "Write":
        return False
    if not isinstance(tool_input, dict):
        return False
    fp = tool_input.get("file_path")
    if not isinstance(fp, str) or not fp:
        return False
    if not isinstance(handoff_path, str) or not handoff_path:
        return False
    a = os.path.normcase(os.path.normpath(os.path.abspath(fp)))
    b = os.path.normcase(os.path.normpath(os.path.abspath(handoff_path)))
    return a == b


@dataclass(frozen=True)
class Verdict:
    """Gateway's decision on a single tool call.

    Fields per the step-4 design:
    - decision: ALLOWED | DENIED.
    - capability_tag: the tag the call resolved to. On ALLOWED, the
      tag that authorized. On DENIED, the tag the runner would have
      needed (or the sentinel '(unmapped)' if no tag covers the tool
      at all).
    - reason: None on ALLOWED; a structured explanation on DENIED.
    """

    decision: GatewayDecision
    capability_tag: str
    reason: Optional[str] = None


class Gateway:
    """Capability-tagged allowlist enforcer. Stateless beyond the
    capability map; safe to share across worker dispatches."""

    def __init__(self, capability_map: CapabilityMap) -> None:
        self._map = capability_map

    def check(self, tool_name: str, tool_scope: list[str]) -> Verdict:
        """Return ALLOWED if any tag in tool_scope authorizes tool_name;
        DENIED with a reason otherwise.

        Algorithm:
        1. Look up candidate tags that cover tool_name.
        2. If no candidates: DENIED, capability_tag='(unmapped)',
           reason names the tool.
        3. If candidates intersect tool_scope: ALLOWED, capability_tag
           is the alphabetically-first matching tag (deterministic).
        4. If no intersection: DENIED, capability_tag is the
           alphabetically-first candidate (what the worker would have
           needed), reason names the required-vs-held tags.
        """
        candidates = self._map.candidate_tags_for(tool_name)
        if not candidates:
            return Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=_UNMAPPED_SENTINEL,
                reason=(
                    f"Tool {tool_name!r} is not covered by any capability "
                    f"in the framework map; no scope grants access."
                ),
            )

        # ADR-026 D4 — framework.harness.* tags authorize the harness's own
        # tools (TodoWrite, ToolSearch, Skill, Task*, Monitor, etc.)
        # regardless of worker scope. Workers cannot REQUEST these tags
        # (the construction validator filters framework.* out of grantable),
        # but the framework's mapping itself is the authorization.
        # WebFetch/WebSearch are deliberately NOT mapped (egress) and fall
        # to the standard DENY path below.
        framework_candidates = {
            c for c in candidates if c.startswith("framework.harness.")
        }
        if framework_candidates:
            return Verdict(
                decision=GatewayDecision.ALLOWED,
                capability_tag=sorted(framework_candidates)[0],
            )

        scope_set = set(tool_scope)
        matching = candidates & scope_set
        if matching:
            return Verdict(
                decision=GatewayDecision.ALLOWED,
                capability_tag=sorted(matching)[0],
            )

        # Decision-E: on multi-candidate DENY, the capability_tag is the
        # sentinel — not `sorted(candidates)[0]`, which misleads audit
        # consumers by always reporting `package.install.allowlisted` for
        # any denied Bash (alphabetical first of {package.install.allowlisted,
        # shell.exec.sandboxed, shell.exec.unsandboxed, test.run}). The
        # reason string lists all candidates and remains the audit-rich
        # field. Single-candidate DENY keeps the candidate as the tag
        # (the user gets a useful "you would have needed X" hint).
        if len(candidates) == 1:
            capability_tag = next(iter(candidates))
        else:
            capability_tag = MULTI_CANDIDATE_DENY_SENTINEL
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=capability_tag,
            reason=(
                f"Tool {tool_name!r} requires one of {sorted(candidates)}; "
                f"worker tool_scope is {sorted(tool_scope)}."
            ),
        )


# ============================================================================
# Bounds gate -- the second wall the hook runs AFTER Gateway.check() passes.
#
# Per brief §6.2: "Tool calls with out-of-scope arguments (wrong tenant,
# wrong path, wrong cluster) are rejected before reaching the tool."
# Gateway.check decides whether the worker may invoke a tool AT ALL (its
# `tool_scope` covers the tool); the bounds gate decides whether the
# specific ARGUMENTS land inside the worker's permitted reach.
#
# Composition order in the hook:
#   exemption  ->  Gateway.check  ->  is_path_in_bounds  ->  is_command_in_allowlist
#
# The handoff-exemption MUST short-circuit BEFORE the bounds gate -- the
# handoff path is legitimately outside the worktree, and bounding it would
# break the exemption.
# ============================================================================


@dataclass(frozen=True)
class Bounds:
    """Per-dispatch path roots the bounds gate enforces.

    Fork-3 ruling: just worktree_root + repo_root. handoff_path is NOT
    here because the exemption short-circuit fires BEFORE this gate;
    the bounds gate never sees the handoff write.

    Both fields are absolute path strings in the form the runner wrote
    into bounds.json. Normalization (realpath + normcase) happens at use
    time in `_resolve_symlink_safe`, not at construction.
    """

    worktree_root: str
    repo_root: str


# Tool sets the path-bounds gate covers, partitioned by which root applies
# and which tool_input field carries the path.
_PATH_TOOLS_WORKTREE_FILE_PATH = frozenset({"Write", "Edit"})
_PATH_TOOLS_WORKTREE_NOTEBOOK = frozenset({"NotebookEdit"})
_PATH_TOOLS_REPO_FILE_PATH = frozenset({"Read"})
_PATH_TOOLS_REPO_OPTIONAL_PATH = frozenset({"Glob", "Grep"})


def _resolve_symlink_safe(abs_path: str) -> str:
    """Walk `abs_path` component-by-component, resolving symlinks at
    each step. `..` is handled against the REAL (already-symlink-
    resolved) current path, NOT lexically against the pre-resolution
    string.

    **This is the fix for a verification-turn finding: combined
    `..` + symlink containment bypass.** The prior implementation
    called `os.path.abspath` before `realpath`, lexically cancelling
    `link/..` before the filesystem could resolve `link`. A whole-path
    `os.path.realpath` call is also insufficient on Windows: Python's
    Windows `realpath` lexically collapses `..` BEFORE resolving
    preceding symlinks (verified by direct probe -- e.g.
    `os.path.realpath("<wt>/link/..")` returns `<wt>` rather than
    `<external>/..` where `link` -> `<external>`). POSIX `realpath`
    does the right thing natively, but this gate must hold on BOTH
    platforms. The manual walk below forces the correct behavior on
    both:

      Algorithm:
        cur = drive root
        for each component in the input path:
          if `.`        : skip
          elif `..`     : cur = dirname(realpath(cur))   # REAL parent,
                                                         # never lexical
          else          : cur = realpath(join(cur, part))  # resolves
                                                           # symlinks
                                                           # at this hop
        return normcase(normpath(cur))

    Why this works for the combined-vector attack
    `<root>/link/../escape` where `link` -> `<external>`:
        step `link`: cur = realpath(`<root>/link`) = `<external>`
        step `..`  : cur = dirname(realpath(`<external>`))
                        = dirname(`<external>`) = `<external_parent>`
        step `escape`: cur = realpath(`<external_parent>/escape`)
                          = `<external_parent>/escape` (literal append
                            for non-existent leaf -- realpath strict=False)
      Result lands OUTSIDE `<root>`, correctly DENIED.

    Correction A (non-existent write targets) is preserved: realpath
    in non-strict mode (Python 3.10+ default) appends unresolved tail
    components literally without lexical normalization.

    Cost: O(N) realpath calls for an N-component path. For typical
    worker paths (10-15 components) this is sub-millisecond on warm
    inode caches. The hook is per-tool-call cold-start, so we pay this
    once per call; the security correctness is non-negotiable.

    Caller is responsible for passing an absolute path. See
    `is_path_in_bounds` for the absolute-path construction via
    `os.path.join(root, raw_path)`, which leverages os.path.join's
    documented behavior (an absolute right operand discards the left)
    to handle abs-input and rel-input in ONE unconditional expression
    -- no `isabs` branch.
    """
    drive, body = os.path.splitdrive(abs_path)
    # Tokenize against forward slashes; backslashes (Windows) collapse
    # to forward slashes for the split, never feeding `..` to a
    # lexical normalizer.
    parts = [p for p in body.replace("\\", "/").split("/") if p != ""]
    root_anchor = (drive + os.sep) if drive else os.sep
    cur = root_anchor
    for part in parts:
        if part == ".":
            continue
        if part == "..":
            # REAL parent: realpath cur first (resolving any symlinks
            # that built up to here), THEN dirname. Never collapse `..`
            # lexically against the pre-resolution string.
            parent = os.path.dirname(os.path.realpath(cur))
            # Guard against walking above the filesystem root.
            cur = parent if parent else root_anchor
            continue
        # Resolve any symlink at this hop in the same step. realpath of
        # a non-existent leaf in strict=False mode returns the literal
        # path (correction A).
        cur = os.path.realpath(os.path.join(cur, part))
    return os.path.normcase(os.path.normpath(cur))


def _is_path_contained(path: str, root: str) -> bool:
    """True iff `path` (already resolved+normalized) is equal-to or
    strictly beneath `root` (already resolved+normalized).

    Uses os.path.commonpath rather than str.startswith to defeat the
    prefix attack (`/wt-extra/x` is NOT under `/wt`; startswith would
    accept it).
    """
    try:
        common = os.path.commonpath([path, root])
    except ValueError:
        # Different drives on Windows, or empty inputs.
        return False
    return common == root


def is_path_in_bounds(
    tool_name: str,
    tool_input: Any,
    bounds: Bounds,
) -> Verdict:
    """Path-bounds gate. Applies to file-touching tools; ALLOWs others.

    Applicability matrix:
      Write, Edit       -> bounds.worktree_root, tool_input["file_path"]
      NotebookEdit      -> bounds.worktree_root, tool_input["notebook_path"]
      Read              -> bounds.repo_root,     tool_input["file_path"]
      Glob, Grep        -> bounds.repo_root,     tool_input["path"] (optional)
      Other tools       -> ALLOW (gate does not apply; the hook's
                                   dispatcher won't route them here, but
                                   the predicate is defensive)

    Symlink-safety: see `_resolve_symlink_safe` for correction-A detail.
    The leaf may not exist (write target); the algorithm resolves the
    deepest existing ancestor and re-attaches the tail. Symlinked
    ancestors are resolved (escape blocked); non-existent tails are not
    (they cannot be symlinks).

    Verdict tagging:
      ALLOW path-tool: capability_tag = framework.bounds.path.worktree
                       or framework.bounds.path.repo per applicable root.
      DENY path-tool:  same tag (the tag identifies the gate; the
                       decision identifies pass/fail).
      ALLOW non-applicable: capability_tag = framework.bounds.path.worktree
                       (placeholder; the hook dispatcher won't route
                       non-applicable tools here).
    """
    # Pick (root, cap_tag, field, path_optional) per tool.
    if tool_name in _PATH_TOOLS_WORKTREE_FILE_PATH:
        root = bounds.worktree_root
        cap_tag = BOUNDS_PATH_WORKTREE_CAPABILITY
        field = "file_path"
        path_optional = False
    elif tool_name in _PATH_TOOLS_WORKTREE_NOTEBOOK:
        root = bounds.worktree_root
        cap_tag = BOUNDS_PATH_WORKTREE_CAPABILITY
        field = "notebook_path"
        path_optional = False
    elif tool_name in _PATH_TOOLS_REPO_FILE_PATH:
        root = bounds.repo_root
        cap_tag = BOUNDS_PATH_REPO_CAPABILITY
        field = "file_path"
        path_optional = False
    elif tool_name in _PATH_TOOLS_REPO_OPTIONAL_PATH:
        root = bounds.repo_root
        cap_tag = BOUNDS_PATH_REPO_CAPABILITY
        field = "path"
        path_optional = True
    else:
        return Verdict(
            decision=GatewayDecision.ALLOWED,
            capability_tag=BOUNDS_PATH_WORKTREE_CAPABILITY,
        )

    if not isinstance(tool_input, dict):
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=cap_tag,
            reason=f"Tool {tool_name!r} bounds-check: tool_input must be an object",
        )

    raw_path = tool_input.get(field)
    if raw_path is None or raw_path == "":
        if path_optional:
            return Verdict(decision=GatewayDecision.ALLOWED, capability_tag=cap_tag)
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=cap_tag,
            reason=f"Tool {tool_name!r} bounds-check: missing required field {field!r}",
        )
    if not isinstance(raw_path, str):
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=cap_tag,
            reason=f"Tool {tool_name!r} bounds-check: {field!r} must be a string",
        )

    # Construct the absolute path in ONE unconditional expression. Per
    # os.path.join's documented behavior, an absolute right operand
    # discards the left -- so this single line handles both:
    #   - raw_path absolute       -> os.path.join returns raw_path
    #   - raw_path relative       -> joined to the tool-appropriate root
    #                                (NOT cwd; deterministic regardless
    #                                of where the hook subprocess starts)
    # Crucially we do NOT call os.path.abspath here. abspath would collapse
    # `..` LEXICALLY before realpath could resolve symlinks, allowing the
    # combined `..`+symlink containment bypass (a verification-turn finding).
    abs_raw = os.path.join(root, raw_path)
    resolved = _resolve_symlink_safe(abs_raw)
    resolved_root = _resolve_symlink_safe(root)
    if _is_path_contained(resolved, resolved_root):
        return Verdict(decision=GatewayDecision.ALLOWED, capability_tag=cap_tag)
    return Verdict(
        decision=GatewayDecision.DENIED,
        capability_tag=cap_tag,
        reason=(
            f"Tool {tool_name!r} bounds-check: path {raw_path!r} "
            f"resolves to {resolved!r}, which is not under root {resolved_root!r}"
        ),
    )


# ADR-026: capability → allowlist dispatch. Generalizes the prior
# `authorized_capability == "test.run"` short-circuit so the gate runs the
# right allowlist for each sub-Bash capability. Capabilities NOT in this
# map (today: package.install.allowlisted; historically shell.exec.* though
# ADR-027 D2 now blocks the grant at construction so it should never reach
# here) fall through to ALLOW per the documented bypass — they have their
# own enforcement mechanisms (sandbox-flag in the runner per concern C2;
# the package allowlist is its own separate work).
def _capability_to_allowlist() -> dict[str, CommandAllowlist]:
    """Lazy lookup of the production allowlist dispatch. Lazy so test
    modules can monkey-patch the constants if they ever need to."""
    from command_allowlist import (
        SHELL_READ_ALLOWLIST,
        TEST_RUN_ALLOWLIST,
        WORKTREE_COMMIT_ALLOWLIST,
    )
    return {
        "test.run":         TEST_RUN_ALLOWLIST,
        "shell.read":       SHELL_READ_ALLOWLIST,    # ADR-026 D1
        "worktree.commit":  WORKTREE_COMMIT_ALLOWLIST,  # ADR-026 D2
    }


def is_command_in_allowlist(
    tool_name: str,
    tool_input: Any,
    *,
    bounds: Bounds,
    authorized_capability: str,
    allowlist: Optional[CommandAllowlist] = None,
) -> Verdict:
    """Bash command vetting against an authorizing-capability's allowlist.

    Applies ONLY when tool_name == "Bash". Non-Bash tools ALLOW immediately.

    Dispatch (ADR-026 D1+D2 generalization of the prior `test.run`-only check):
      - allowlist explicitly provided  → use it (test seam).
      - allowlist None + capability in `_capability_to_allowlist()` → use
        the looked-up production allowlist for that capability.
      - allowlist None + capability NOT in dispatch map (e.g.
        package.install.allowlisted, or shell.exec.* if it somehow reaches
        here despite ADR-027 D2's construction-time block) → ALLOW immediately.
        These capabilities have their own enforcement (sandbox-flag in the
        runner per concern C2; package allowlist is separate work).

    Composition order (load-bearing — do not reorder):
      1. CHARSET GATE on the WHOLE command string. Runs BEFORE shlex.
         argv[0] being in `allowlist.programs` does NOT bypass this.
         Fail → DENY framework.bounds.cmd.charset.
      2. shlex.split. Empty or parse error → DENY framework.bounds.cmd.argv.
      3. argv[0] basename in `allowlist.programs`. EXACT (case-sensitive).
         Fail → DENY framework.bounds.cmd.program.
      3b. (ADR-026 D2) If program is in `allowlist.program_subcommands`:
          - argv[1] must exist (len(argv) >= 2).
          - argv[1] must NOT start with `-` (operator ruling 2: bare
            subcommand only — pre-subcommand global flags like `git -C` or
            `git -c key=val` are prohibited, since they enable
            config-injection and break operand-position alignment).
          - argv[1] must be in the subcommand frozenset.
          Fail any of these → DENY framework.bounds.cmd.subcommand.
      3c. (ADR-026 D2 + operator ruling 1) If `(program, subcommand)` is
          listed in `allowlist.subcommand_operand_bound`: each argv[i] for
          i >= 2 that does NOT start with `-` is treated as a path operand
          and routed through `is_path_in_bounds(tool_name="Write",
          file_path=argv[i], bounds=bounds)`. Operand outside the worktree
          → DENY framework.bounds.cmd.path_arg. Flag args (starting with
          `-`) are skipped; messages and other flag-values pass through.
      3d. If program has an entry in
          `allowlist.program_allowed_flags`: every argv[i] for i >= 1 that
          starts with `-` is matched against the entry by splitting on the
          first `=` (so `--rootdir=/etc` → `--rootdir`; `-p` → `-p`;
          `--tb=no` → `--tb`). A prefix NOT in the allowed frozenset
          → DENY framework.bounds.cmd.flag. Programs WITHOUT an entry are
          NOT flag-gated by this step (D1 shell.read + D2 worktree.commit
          both omit the field, retain prior behavior). Non-flag tokens are
          skipped here; they remain subject to Step 4 path-position bounding.
      4. Each declared `program_path_positions[program]` index routed
         through `is_path_in_bounds`. Negative indices supported.
         Out-of-range or program-slot indices → DENY
         framework.bounds.cmd.path_arg.
      5. Pass → ALLOW framework.bounds.cmd (terminal).
    """
    if tool_name != "Bash":
        return Verdict(
            decision=GatewayDecision.ALLOWED,
            capability_tag=BOUNDS_CMD_CAPABILITY,
        )

    # Capability → allowlist dispatch.
    if allowlist is None:
        allowlist = _capability_to_allowlist().get(authorized_capability)
        if allowlist is None:
            # Capability is not in the dispatch map (e.g.
            # package.install.allowlisted, or shell.exec.* if construction
            # was bypassed). Documented bypass.
            return Verdict(
                decision=GatewayDecision.ALLOWED,
                capability_tag=BOUNDS_CMD_CAPABILITY,
            )

    if not isinstance(tool_input, dict):
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=BOUNDS_CMD_ARGV_CAPABILITY,
            reason="Bash bounds-check: tool_input must be an object",
        )
    command = tool_input.get("command")
    if not isinstance(command, str) or command == "":
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=BOUNDS_CMD_ARGV_CAPABILITY,
            reason="Bash bounds-check: command must be a non-empty string",
        )

    # Step 1: CHARSET GATE on whole command. Before argv parse.
    if not ALLOWED_CHARSET.match(command):
        offenders = sorted({c for c in command if not ALLOWED_CHARSET.match(c)})
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=BOUNDS_CMD_CHARSET_CAPABILITY,
            reason=(
                f"Bash command failed charset gate; "
                f"disallowed character(s): {offenders!r}"
            ),
        )

    # Step 2: shlex parse.
    try:
        argv = shlex.split(command, posix=True)
    except ValueError as e:
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=BOUNDS_CMD_ARGV_CAPABILITY,
            reason=f"Bash command shlex parse failed: {e}",
        )
    if not argv:
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=BOUNDS_CMD_ARGV_CAPABILITY,
            reason="Bash command parsed to empty argv",
        )

    # Step 3: argv[0] basename in programs. CASE-SENSITIVE.
    program = os.path.basename(argv[0])
    if program not in allowlist.programs:
        return Verdict(
            decision=GatewayDecision.DENIED,
            capability_tag=BOUNDS_CMD_PROGRAM_CAPABILITY,
            reason=(
                f"Bash command program {program!r} not in {authorized_capability} "
                f"allowlist; allowed: {sorted(allowlist.programs)!r}"
            ),
        )

    # Step 3b (ADR-026 D2): subcommand check for programs with a
    # `program_subcommands` entry. Operator ruling 2 enforced: argv[1]
    # MUST be a bare subcommand (no leading `-`). Pre-subcommand global
    # flags (git -C, git -c, git --git-dir) DENIED.
    subcommand_set = allowlist.program_subcommands.get(program)
    subcommand: Optional[str] = None
    if subcommand_set is not None:
        if len(argv) < 2:
            return Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=BOUNDS_CMD_SUBCOMMAND_CAPABILITY,
                reason=(
                    f"Bash command program {program!r} requires a subcommand "
                    f"(one of {sorted(subcommand_set)!r}); got bare {program!r}"
                ),
            )
        if argv[1].startswith("-"):
            # Operator ruling 2: pre-subcommand global flags prohibited.
            # Without this, `git -C /other commit` would let the worker
            # operate outside its worktree, and `git -c key=val commit`
            # would inject persistent configuration.
            return Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=BOUNDS_CMD_SUBCOMMAND_CAPABILITY,
                reason=(
                    f"Bash command program {program!r} requires a bare "
                    f"subcommand at argv[1] (no leading `-`); got {argv[1]!r}. "
                    f"Pre-subcommand global flags (e.g. -C, -c, --git-dir) "
                    f"are prohibited (operator ruling 2: config-injection + "
                    f"operand-position alignment)."
                ),
            )
        subcommand = argv[1]
        if subcommand not in subcommand_set:
            return Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=BOUNDS_CMD_SUBCOMMAND_CAPABILITY,
                reason=(
                    f"Bash command {program!r} subcommand {subcommand!r} "
                    f"not in allowlist; allowed: {sorted(subcommand_set)!r}"
                ),
            )

    # Step 3c (ADR-026 D2 + operator ruling 1): per-(program, subcommand)
    # operand path-bounding. If the pair is listed, every NON-FLAG argv[i]
    # (i >= 2) is treated as a worktree-bound path operand. Flag args
    # (starting with `-`) are skipped — so messages and other flag-values
    # pass through unchecked (e.g. `git commit -m fix-tests/foo` works
    # because `git commit` isn't operand-bound; for `git add`, every
    # non-flag operand IS bounded).
    operand_bound_subcommands = allowlist.subcommand_operand_bound.get(
        program, frozenset()
    )
    if subcommand is not None and subcommand in operand_bound_subcommands:
        for i in range(2, len(argv)):
            arg = argv[i]
            if arg.startswith("-"):
                continue  # flag, skip
            path_verdict = is_path_in_bounds(
                tool_name="Write",
                tool_input={"file_path": arg},
                bounds=bounds,
            )
            if path_verdict.decision == GatewayDecision.DENIED:
                return Verdict(
                    decision=GatewayDecision.DENIED,
                    capability_tag=BOUNDS_CMD_PATH_ARG_CAPABILITY,
                    reason=(
                        f"Bash command {program!r} {subcommand!r} operand at "
                        f"argv[{i}] ({arg!r}) failed worktree containment: "
                        f"{path_verdict.reason}"
                    ),
                )

    # Step 3d: per-program flag allowlist. Programs with an entry
    # in allowlist.program_allowed_flags are flag-gated: every argv[i>=1]
    # token starting with `-` must (after splitting on first `=`) be in the
    # allowed set, else DENY at framework.bounds.cmd.flag. Programs WITHOUT
    # an entry (allowed is None) skip the whole block — preserving prior
    # behavior for D1 shell.read + D2 worktree.commit and any other
    # un-keyed program.
    allowed_flags = allowlist.program_allowed_flags.get(program)
    if allowed_flags is not None:
        for i in range(1, len(argv)):
            tok = argv[i]
            if tok.startswith("-"):
                prefix = tok.split("=", 1)[0]
                if prefix not in allowed_flags:
                    return Verdict(
                        decision=GatewayDecision.DENIED,
                        capability_tag=BOUNDS_CMD_FLAG_CAPABILITY,
                        reason=(
                            f"Bash command {program!r} flag {tok!r} "
                            f"(matched as {prefix!r}) not in allowed set "
                            f"for program {program!r}: "
                            f"{sorted(allowed_flags)!r}"
                        ),
                    )
            # non-flag tokens: skip here; they remain subject to Step 4
            # path-position bounding.

    # Step 4: per-program declared path positions -> C1-bound to worktree.
    positions = allowlist.program_path_positions.get(program, ())
    for pos in positions:
        idx = len(argv) + pos if pos < 0 else pos
        if idx <= 0 or idx >= len(argv):
            # Position resolves to the program slot (idx == 0) or
            # outside argv -- either way, the declared shape and the
            # actual invocation diverge. Closed-by-default: DENY.
            return Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=BOUNDS_CMD_PATH_ARG_CAPABILITY,
                reason=(
                    f"Bash command {program!r} declared path position {pos} "
                    f"resolves to argv index {idx} (argv len={len(argv)})"
                ),
            )
        path_arg = argv[idx]
        # Compose with is_path_in_bounds by synthesizing a Write-shaped
        # tool_input. Routes through bounds.worktree_root since test.run
        # path args are test-target paths inside the worktree.
        path_verdict = is_path_in_bounds(
            tool_name="Write",
            tool_input={"file_path": path_arg},
            bounds=bounds,
        )
        if path_verdict.decision == GatewayDecision.DENIED:
            return Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=BOUNDS_CMD_PATH_ARG_CAPABILITY,
                reason=(
                    f"Bash command path arg at position {pos} ({path_arg!r}) "
                    f"failed worktree containment: {path_verdict.reason}"
                ),
            )

    return Verdict(
        decision=GatewayDecision.ALLOWED,
        capability_tag=BOUNDS_CMD_CAPABILITY,
    )
