"""
mcp_capability_map.py -- canonical mapping between capability tags and the
underlying tool names workers may invoke.

Taxonomy: hybrid per the step-4 design (operator-approved 2026-05-29).
- Native Claude Code tools get dot-namespaced fine-grained capability tags
  (`repo.read`, `worktree.write`, `shell.exec.sandboxed`, ...). Multiple
  tags may map to the same underlying tool (Bash is the canonical case);
  the gateway treats any matching tag in tool_scope as authorization.
- MCP server tools get coarse server-name tags (`postman`, `playwright`,
  `github`, `docling`) per ADR-015 ("server name = capability tag").

Cross-check at load time: CapabilityMap.default() reads
tools/mission-cli/config/mcp-tools.yaml and verifies every server named in
this map's _MCP_MAP appears in the YAML's framework_mcp_tools (and vice
versa). Drift fires a CapabilityMapDriftError with a named-direction
message, not an AssertionError.

Architectural-concern documentation (operator-named C1/C2):
- `worktree.write` covers Write/Edit/NotebookEdit but is ONLY the
  capability declaration -- "is the worker permitted to write at all?"
  The gateway hook enforces "is the path argument inside the worker's
  assigned worktree?" pre-tool (per brief §6.2, "rejected before
  reaching the tool"); the runner cross-checks the verdict post-hoc.
  Two checks; both must pass. Do not bake path-scoping into
  Gateway.check().
- `shell.exec.sandboxed` vs `shell.exec.unsandboxed` are different
  capability declarations even though both cover Bash. The gateway
  records which capability authorized; the runner enforces the actual
  sandbox flag at subprocess construction. Do not have the gateway
  inspect Bash arguments for sandbox semantics.

Postman --minimal source-of-truth: per the source-enumerated
v2.8.9 tool list,
the 41 tools below are the canonical --minimal
surface from v2.8.9. Upgrade ceremony re-enumerates and supersedes.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Final

import yaml

# ----- Static data -----

# Native Claude Code tool tags.
# Multiple tags may map to the same tool (Bash); the gateway treats any
# matching tag in tool_scope as authorization.
_NATIVE_MAP: Final[dict[str, frozenset[str]]] = {
    "repo.read": frozenset({"Read", "Glob", "Grep"}),
    # worktree.write: capability-level declaration only. Path-inside-worktree
    # enforcement is the hook's job (pre-tool, per brief §6.2),
    # cross-checked by the runner (see module docstring, concern C1).
    "worktree.write": frozenset({"Write", "Edit", "NotebookEdit"}),
    # shell.exec.* tags are capability-level distinctions for the gateway;
    # the runner enforces the actual sandbox flag at subprocess construction
    # (see module docstring, concern C2).
    "shell.exec.sandboxed": frozenset({"Bash"}),
    "shell.exec.unsandboxed": frozenset({"Bash"}),
    # Subordinate shell capabilities; the runner pattern-matches the
    # command to enforce the narrower intent.
    "test.run": frozenset({"Bash"}),
    "package.install.allowlisted": frozenset({"Bash"}),
    # task.spawn -- sub-agent dispatch via the Agent/Task tool. Sub-agent
    # scope inheritance (does the child get the parent's tool_scope?
    # narrower? amendment-controlled?) is DEFERRED to step 5 (worker-runner
    # main loop) where the actual subprocess management lives. The
    # capability tag alone is recorded here.
    "task.spawn": frozenset({"Task", "Agent"}),
    # ADR-026 D1 — shell.read read-tier covering Bash. Authorization is
    # gated by the SHELL_READ_ALLOWLIST in command_allowlist.py via the
    # capability→allowlist dispatch in policy.is_command_in_allowlist;
    # the program allowlist {cat, head, tail, wc, ls, grep} encodes the
    # inclusion criterion (each program safe under every argument the
    # charset gate permits).
    "shell.read": frozenset({"Bash"}),
    # ADR-026 D2 — worktree.commit git-subcommand tier covering Bash.
    # Gated by WORKTREE_COMMIT_ALLOWLIST: programs={"git"},
    # program_subcommands={git: {status, log, diff, show, rev-parse,
    # rev-list, add, commit}}, with operator-ruled operand bounding for
    # `git add` (every non-flag operand path-bounded to worktree) and
    # operator-ruled prohibition on pre-subcommand global flags.
    "worktree.commit": frozenset({"Bash"}),
    # ADR-026 D4 — harness-internal tools. The framework's own machinery
    # (todo-list state, deferred-tool loading, skill invocation, subtask
    # management, monitor/schedule/notification surfaces, plan-mode +
    # worktree-isolation toggles, interactive prompts, MCP resource
    # access). Workers cannot REQUEST this tag (the construction
    # validator filters framework.* out of grantable per ADR-027 D1);
    # Gateway.check special-cases framework.harness.* candidates to ALLOW
    # regardless of worker scope so the harness's own operation is not
    # blocked by worker-scope mismatch.
    #
    # NOT INCLUDED HERE (deliberately): WebFetch, WebSearch. Both are
    # network EGRESS; mapping them to framework.harness.internal would
    # breach ADR-027 D2's egress-deferral discipline (workers would have
    # implicit network access via Claude Code's tool surface, with no
    # C2-style egress containment). They remain in the (unmapped)
    # DENY-default branch until C2 lands or a network-capability tag is
    # added by a separate ADR.
    "framework.harness.internal": frozenset({
        "TodoWrite",
        "ToolSearch",
        "Skill",
        "TaskCreate", "TaskGet", "TaskList",
        "TaskOutput", "TaskStop", "TaskUpdate",
        "Monitor",
        "ScheduleWakeup",
        "PushNotification",
        "RemoteTrigger",
        "CronCreate", "CronList", "CronDelete",
        "EnterPlanMode", "ExitPlanMode",
        "EnterWorktree", "ExitWorktree",
        "AskUserQuestion",
        "ListMcpResourcesTool",
        "ReadMcpResourceTool",
    }),
}

# MCP server tags (coarse, server-name = tag per ADR-015).
# Each frozenset is the tool surface that server exposes; tool names are
# Claude Code's `mcp__<server>__<method>` form (matching what the runner
# sees as tool_name in stream-json events).
#
# postman: --minimal mode per operator decision
# 2026-05-29. The 41 method names below are verbatim from v2.8.9 source
# (dist/src/enabledResources.js lines 131-173), which is the
# source-of-truth; an upgrade re-enumerates them under the
# drift-detection ceremony.
_POSTMAN_MINIMAL_METHODS: Final[tuple[str, ...]] = (
    "createCollection",
    "createEnvironment",
    "createMock",
    "createSpec",
    "createSpecFile",
    "createWorkspace",
    "generateCollection",
    "generateSpecFromCollection",
    "getAllSpecs",
    "getAuthenticatedUser",
    "getCollection",
    "getCollections",
    "getEnvironment",
    "getEnvironments",
    "getGeneratedCollectionSpecs",
    "getMock",
    "getMocks",
    "getSpec",
    "getSpecCollections",
    "getSpecDefinition",
    "getSpecFile",
    "getSpecFiles",
    "getTaggedEntities",
    "getWorkspace",
    "getWorkspaces",
    "publishMock",
    "putCollection",
    "putEnvironment",
    "syncCollectionWithSpec",
    "syncSpecWithCollection",
    "updateMock",
    "updateSpecFile",
    "updateSpecProperties",
    "updateWorkspace",
    "createCollectionRequest",
    "createCollectionResponse",
    "duplicateCollection",
    "getDuplicateCollectionTaskStatus",
    "runCollection",
    "getEnabledTools",
    "updateCollectionRequest",
)

# Playwright / github / docling tool surfaces are deferred until each
# server's dispatched use is concrete. Per the operator's same-pattern
# discipline (enumerate per-server when a worker actually needs it),
# placeholder empty surfaces here surface as DENIED for any specific
# tool invocation -- the worker dispatch can grow the inventory via
# amendment when needed.
_MCP_MAP: Final[dict[str, frozenset[str]]] = {
    "postman": frozenset(
        f"mcp__postman__{m}" for m in _POSTMAN_MINIMAL_METHODS
    ),
    # playwright: enumeration deferred. The first QA-validator dispatch that
    # needs playwright (ADR-013: a QA validator with Playwright-captured
    # screenshots) triggers an amendment to enumerate the actual surface.
    "playwright": frozenset(),
    # github: enumeration deferred. The first worker that needs github MCP
    # tools (a project's repository integration, or its handoff push) triggers
    # an amendment to enumerate.
    "github": frozenset(),
    # docling: enumeration deferred. The first worker that needs the docling
    # MCP runtime (a project's document conversion) triggers an amendment to
    # enumerate.
    "docling": frozenset(),
}

_MCP_TOOLS_YAML_PATH: Final[Path] = (
    Path(__file__).parent.parent / "mission-cli" / "config" / "mcp-tools.yaml"
)


class CapabilityMapDriftError(RuntimeError):
    """Raised when CapabilityMap.default() detects drift between this module's
    _MCP_MAP and the framework_mcp_tools declaration in mcp-tools.yaml."""


@dataclass(frozen=True)
class CapabilityMap:
    """Immutable static map of capability_tag -> covered tool names.

    Built via CapabilityMap.default() for production use (cross-checks
    against mcp-tools.yaml). The internal `_build` constructor accepts a
    custom yaml path for testability.
    """

    _tag_to_tools: dict[str, frozenset[str]]

    @classmethod
    def default(cls) -> "CapabilityMap":
        """Build from canonical sources: hardcoded internal native + MCP maps,
        cross-checked against tools/mission-cli/config/mcp-tools.yaml."""
        return cls._build(_MCP_TOOLS_YAML_PATH)

    @classmethod
    def _build(cls, yaml_path: Path) -> "CapabilityMap":
        """Internal builder; takes yaml path for testability. Verifies that
        every MCP server in _MCP_MAP appears in mcp-tools.yaml's
        framework_mcp_tools (and vice versa). On drift, raises
        CapabilityMapDriftError with a directional message naming the
        offending server(s)."""
        with yaml_path.open("r", encoding="utf-8") as f:
            yaml_doc = yaml.safe_load(f)

        yaml_servers = {
            entry["name"] for entry in yaml_doc.get("framework_mcp_tools", [])
        }
        map_servers = set(_MCP_MAP.keys())

        in_map_not_in_yaml = map_servers - yaml_servers
        in_yaml_not_in_map = yaml_servers - map_servers

        if in_map_not_in_yaml:
            raise CapabilityMapDriftError(
                f"MCP server(s) {sorted(in_map_not_in_yaml)} declared in "
                f"mcp_capability_map._MCP_MAP but NOT in "
                f"{yaml_path.name} framework_mcp_tools. "
                f"Either add the server to mcp-tools.yaml (via amendment "
                f"per ADR-015), or remove from _MCP_MAP."
            )
        if in_yaml_not_in_map:
            raise CapabilityMapDriftError(
                f"MCP server(s) {sorted(in_yaml_not_in_map)} declared in "
                f"{yaml_path.name} framework_mcp_tools but NOT in "
                f"mcp_capability_map._MCP_MAP. "
                f"Either add the server's tool surface to _MCP_MAP, or "
                f"remove from mcp-tools.yaml (via amendment per ADR-015)."
            )

        # Merge native + MCP tags into a single canonical dict.
        merged: dict[str, frozenset[str]] = {}
        merged.update(_NATIVE_MAP)
        merged.update(_MCP_MAP)
        return cls(_tag_to_tools=merged)

    def candidate_tags_for(self, tool_name: str) -> frozenset[str]:
        """Tags that could authorize a call to tool_name.

        Returns multiple tags when a tool is covered by multiple capabilities
        (Bash is covered by shell.exec.sandboxed, shell.exec.unsandboxed,
        test.run, package.install.allowlisted). The gateway treats any
        intersection with tool_scope as authorization.

        Returns an empty frozenset if no tag covers the tool -- the gateway
        will surface this as a DENIED verdict with reason 'unmapped'.
        """
        return frozenset(
            tag for tag, tools in self._tag_to_tools.items() if tool_name in tools
        )

    def tools_for(self, capability_tag: str) -> frozenset[str]:
        """Forward lookup: which tools does this tag cover?
        Returns an empty frozenset for unknown tags."""
        return self._tag_to_tools.get(capability_tag, frozenset())

    def tags(self) -> frozenset[str]:
        """All capability tags declared by the framework."""
        return frozenset(self._tag_to_tools.keys())
