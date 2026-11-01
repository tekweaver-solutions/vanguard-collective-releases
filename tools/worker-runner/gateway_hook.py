"""
gateway_hook.py -- the PreToolUse hook executable Claude Code spawns
before each tool call.

Per the step-5 design (operator-approved 2026-05-29):

Invocation contract (caller is Claude Code's hook runtime):
- Spawned in a fresh Python interpreter per tool call.
- argv[1] is the dispatch_id (passed by hook_config.py at settings-write time).
- argv[2] is the project_root absolute path (mission monorepo root).
- argv[3] is the handoff_path absolute path. The hook applies a framework-
  protocol exemption for an EXACT-PATH Write to this file (regardless
  of the worker's task tool_scope), because the handoff is the one
  channel results propagate (§5). The exemption is exact-path: any other
  path -- including other files under the dispatch dir -- still routes
  through normal scope gating. See `policy.is_handoff_write_exemption`
  and ledger `ledger-handoff-write-protocol-exemption`.
- argv[4] is the bounds_path absolute path. Points at a runner-written
  bounds.json declaring `worktree_root` + `repo_root` for the bounds-gate
  predicates (`policy.is_path_in_bounds`, `policy.is_command_in_allowlist`).
  The gate runs AFTER Gateway.check() ALLOWED in the composition
  (exemption -> capability check -> bounds gate). bounds.json lives
  OUTSIDE the worktree, so a worktree.write-scoped worker cannot rewrite
  its own bounds. See ledger `ledger-bounds-channel-bounds-json-argv4-landed`.
  **All hook inputs derive from argv + runner-written files. The hook
  does NOT read Claude-controlled ambient state (env, cwd) -- Claude
  overrides those for hook subprocesses, breaking the runner->hook
  contract. The argv channel is the only runner-controlled channel
  Claude does not rewrite (the hook command string in hook-settings.json
  is verbatim).** See ledger entries
  `ledger-hook-runner-contract-escapes-to-argv` and
  `ledger-hook-derives-from-argv-not-ambient` for context.
- stdin is the canonical PreToolUse JSON payload (see
  tools/worker-runner/fixtures/hook-stdin-allow.jsonl for the shape).
- stdout is consumed by Claude Code; print to stderr for human-visible reasons.
- exit 0 = allow; exit 2 = block (Claude Code blocks the tool call).
- Any other non-zero exit = treated as block + error by Claude Code (the
  hook itself failed). Defensive policy: this script never returns any
  exit code other than 0 (allow) or 2 (deny / hook-internal failure).

Performance constraints:
- Cold-start matters. Imports are kept minimal -- json (stdlib),
  pathlib (stdlib), os/sys (stdlib), and only the two framework modules
  the gateway needs (mcp_capability_map + policy). No trace_store, no
  audit_log, no extra pydantic surface beyond what comes transitively
  through policy.
- sys.path manipulation happens AFTER all argument and stdin validation
  so the cheapest fail-closed paths return without paying framework
  import cost.

Fail-closed policy (operator C2-prep refinement):
- Missing argv, missing env, missing files, malformed JSON, malformed
  tool_scope, framework import failure, capability-map drift -- all
  result in exit 2 with the reason printed to stderr. Claude Code's
  hook_response event will carry the stderr; the runner sees it and
  emits a ToolCallTrace with gateway_decision=DENIED and the reason.
- Never fail-open: a hook that exits 0 on internal error would silently
  bypass the gateway, which is the precise failure mode ADR-014's
  framework discipline forbids.

Architectural invariant (record per step-5 C2-prep operator observation):
- The runner consumes `system/hook_response` events as the canonical
  denial signal -- closest to source, before any Claude Code internal
  re-encoding. The downstream `user/tool_result` and terminal
  `result.permission_denials` are secondary cross-checks; if they
  disagree with `hook_response`, that is a Claude Code internal bug
  to surface, NOT a framework decision point.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def _die(reason: str) -> None:
    """Print reason to stderr; exit 2 (deny). Fail-closed terminal step."""
    print(f"gateway_denied: {reason}", file=sys.stderr, flush=True)
    sys.exit(2)


def main() -> None:
    # --- argv ---
    # argv[1] = dispatch_id; argv[2] = project_root absolute path. Both
    # required. Per the hook-runner contract (see module docstring),
    # the hook derives all its inputs from argv + runner-written files
    # only, NEVER from Claude-controlled ambient state.
    if len(sys.argv) < 2:
        _die("missing dispatch_id argv[1]")
    dispatch_id = sys.argv[1]
    if not dispatch_id:
        _die("empty dispatch_id argv[1]")

    if len(sys.argv) < 3:
        _die("missing project_root argv[2]")
    project_dir = sys.argv[2]
    if not project_dir:
        _die("empty project_root argv[2]")

    if len(sys.argv) < 4:
        _die("missing handoff_path argv[3]")
    handoff_path = sys.argv[3]
    if not handoff_path:
        _die("empty handoff_path argv[3]")

    if len(sys.argv) < 5:
        _die("missing bounds_path argv[4]")
    bounds_path_str = sys.argv[4]
    if not bounds_path_str:
        _die("empty bounds_path argv[4]")

    # --- stdin payload ---
    try:
        stdin_raw = sys.stdin.read()
    except Exception as e:  # I/O failure
        _die(f"stdin read failed: {e!r}")
    if not stdin_raw.strip():
        _die("empty stdin")
    try:
        payload = json.loads(stdin_raw)
    except json.JSONDecodeError as e:
        _die(f"stdin JSON decode failed: {e}")
    if not isinstance(payload, dict):
        _die(f"stdin payload not an object; got {type(payload).__name__}")

    tool_name = payload.get("tool_name")
    if not isinstance(tool_name, str) or not tool_name:
        _die("payload missing or empty tool_name")

    # --- tool_scope ---
    scope_path = (
        Path(project_dir)
        / ".mission-runtime"
        / "dispatches"
        / dispatch_id
        / "tool_scope.json"
    )
    if not scope_path.is_file():
        _die(f"tool_scope.json not found at {scope_path}")
    try:
        with scope_path.open("r", encoding="utf-8") as f:
            scope_doc = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        _die(f"tool_scope.json read failed: {e}")
    if not isinstance(scope_doc, dict):
        _die("tool_scope.json root must be an object")
    tool_scope = scope_doc.get("tool_scope")
    if not isinstance(tool_scope, list):
        _die("tool_scope.json missing or non-list 'tool_scope' field")
    for tag in tool_scope:
        if not isinstance(tag, str):
            _die(f"tool_scope contains non-string entry: {tag!r}")

    # --- bounds.json (per-dispatch worktree_root + repo_root) ---
    # Mirrors the tool_scope.json load block: argv[4]-pointed file, read
    # with fail-closed on every malformed shape.
    bounds_file = Path(bounds_path_str)
    if not bounds_file.is_file():
        _die(f"bounds.json not found at {bounds_file}")
    try:
        with bounds_file.open("r", encoding="utf-8") as f:
            bounds_doc = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        _die(f"bounds.json read failed: {e}")
    if not isinstance(bounds_doc, dict):
        _die("bounds.json root must be an object")
    worktree_root_raw = bounds_doc.get("worktree_root")
    repo_root_raw = bounds_doc.get("repo_root")
    if not isinstance(worktree_root_raw, str) or not worktree_root_raw:
        _die("bounds.json missing or empty 'worktree_root'")
    if not isinstance(repo_root_raw, str) or not repo_root_raw:
        _die("bounds.json missing or empty 'repo_root'")

    # --- framework imports (deferred until after all cheap validation) ---
    _HERE = Path(__file__).parent
    sys.path.insert(0, str(_HERE.parent / "tool-gateway"))
    sys.path.insert(0, str(_HERE))  # explicit: schemas.py lives in this dir (worker-runner)
    try:
        from command_allowlist import TEST_RUN_ALLOWLIST
        from mcp_capability_map import CapabilityMap, CapabilityMapDriftError
        from policy import (
            HANDOFF_EXEMPTION_CAPABILITY,
            Bounds,
            Gateway,
            is_command_in_allowlist,
            is_handoff_write_exemption,
            is_path_in_bounds,
        )
        from schemas import GatewayDecision
    except ImportError as e:
        _die(f"framework import failed: {e!r}")
    except Exception as e:  # any other import-time failure (module syntax error, import-time side effect, etc.)
        _die(f"framework import unexpected error: {e!r}")

    bounds = Bounds(
        worktree_root=worktree_root_raw,
        repo_root=repo_root_raw,
    )

    # --- handoff-protocol exemption (checked BEFORE the normal gateway,
    # because the handoff Write must succeed regardless of task scope).
    # EXACT-PATH match only (see policy.is_handoff_write_exemption). The
    # exemption is OBSERVABLE: stderr carries a distinctive marker so a
    # future trace audit cannot mistake an exempted Write for a normal
    # scope-authorized one.
    tool_input = payload.get("tool_input")
    if is_handoff_write_exemption(tool_name, tool_input, handoff_path):
        fp = tool_input.get("file_path") if isinstance(tool_input, dict) else None
        print(
            f"gateway_exemption: tool={tool_name!r} "
            f"capability={HANDOFF_EXEMPTION_CAPABILITY!r} "
            f"reason='handoff_protocol_exact_path_allow' "
            f"file_path={fp!r}",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(0)

    try:
        cap_map = CapabilityMap.default()
    except CapabilityMapDriftError as e:
        _die(f"capability map drift: {e}")
    except Exception as e:
        _die(f"capability map build failed: {e!r}")

    gateway = Gateway(cap_map)
    verdict = gateway.check(tool_name, tool_scope)

    # Explicit enum comparison eliminates silent-string-coupling drift
    # if GatewayDecision.ALLOWED.value ever changes value.
    if verdict.decision != GatewayDecision.ALLOWED:
        # Capability gate denied. Print structured reason; the runner
        # observes via hook_response.stderr. Bounds gate is NOT run when
        # the capability gate denied -- the worker isn't authorized for
        # the tool at all, so argument-bounding would be misleading audit.
        reason = verdict.reason or "(no reason)"
        print(
            f"gateway_denied: tool={tool_name!r} capability={verdict.capability_tag!r} "
            f"reason={reason}",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(2)

    # --- bounds gate (runs AFTER Gateway.check ALLOWED) ---
    # Composition order (load-bearing -- do not reorder):
    #   exemption  ->  Gateway.check  ->  is_path_in_bounds  ->  is_command_in_allowlist
    # Exemption short-circuits at line ~176 BEFORE we get here, so a
    # legitimate handoff write never reaches the bounds gate (its path is
    # outside the worktree by design). Path-bounds runs before command-
    # allowlist purely for ordering symmetry; the two predicates apply
    # to disjoint tool sets (path tools vs. Bash), so order between them
    # is observationally invariant -- but we run path-bounds first to
    # keep the audit log's "which gate caught it" identifier stable.
    path_verdict = is_path_in_bounds(tool_name, tool_input, bounds)
    if path_verdict.decision != GatewayDecision.ALLOWED:
        reason = path_verdict.reason or "(no reason)"
        print(
            f"gateway_denied: tool={tool_name!r} "
            f"capability={path_verdict.capability_tag!r} reason={reason}",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(2)

    # ADR-026 D1+D2: is_command_in_allowlist now dispatches the allowlist
    # internally based on authorized_capability (test.run, shell.read,
    # worktree.commit). The hook lets the function pick the right
    # allowlist; TEST_RUN_ALLOWLIST is no longer threaded explicitly.
    cmd_verdict = is_command_in_allowlist(
        tool_name,
        tool_input,
        bounds=bounds,
        authorized_capability=verdict.capability_tag,
    )
    if cmd_verdict.decision != GatewayDecision.ALLOWED:
        reason = cmd_verdict.reason or "(no reason)"
        print(
            f"gateway_denied: tool={tool_name!r} "
            f"capability={cmd_verdict.capability_tag!r} reason={reason}",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
