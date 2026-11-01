"""
Tests for mcp_capability_map.CapabilityMap.

Coverage matches the operator-named test architectural properties:
- (a) native tag → tool resolution
- (b) MCP tag → tool resolution
- (d) yaml ↔ map cross-check (positive: matching yaml passes;
      negative: yaml-vs-map drift fails with the right error)
Property (c) (denial path with reason) lives in test_policy.py.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from mcp_capability_map import (
    CapabilityMap,
    CapabilityMapDriftError,
    _MCP_MAP,
)


def test_default_loads_against_real_mcp_tools_yaml() -> None:
    """The committed mcp-tools.yaml matches the hardcoded _MCP_MAP.
    Catches drift between the amendment YAML and the gateway map at
    commit-time; if this test fails the framework is in inconsistent state.

    Tightened assertions verify meaningful structure (not just None-check):
    canonical tags present + postman surface size matches the v2.8.9 enumeration.
    A silently-corrupt map (e.g., missing tags from a refactor regression)
    would fail here."""
    cap_map = CapabilityMap.default()
    assert cap_map is not None
    assert "postman" in cap_map.tags()
    assert "repo.read" in cap_map.tags()
    assert "worktree.write" in cap_map.tags()
    assert len(cap_map.tools_for("postman")) == 41


def test_native_tag_resolves_to_tool_set() -> None:
    """(a) Native tag → tool resolution. Forward lookup returns the
    documented tool surface for each native capability."""
    cap_map = CapabilityMap.default()
    assert cap_map.tools_for("repo.read") == frozenset({"Read", "Glob", "Grep"})
    assert cap_map.tools_for("worktree.write") == frozenset(
        {"Write", "Edit", "NotebookEdit"}
    )
    assert cap_map.tools_for("task.spawn") == frozenset({"Task", "Agent"})


def test_shell_exec_variants_are_distinct_tags_covering_same_tool() -> None:
    """Both shell.exec.sandboxed and shell.exec.unsandboxed cover Bash.
    Reverse lookup returns both candidates -- the runner-layer concern C2."""
    cap_map = CapabilityMap.default()
    bash_candidates = cap_map.candidate_tags_for("Bash")
    # All four Bash-covering tags should appear.
    assert "shell.exec.sandboxed" in bash_candidates
    assert "shell.exec.unsandboxed" in bash_candidates
    assert "test.run" in bash_candidates
    assert "package.install.allowlisted" in bash_candidates


def test_mcp_tag_resolves_to_postman_minimal_surface() -> None:
    """(b) MCP tag → tool resolution. postman covers exactly the 41
    method names from v2.8.9 source (with mcp__postman__ prefix)."""
    cap_map = CapabilityMap.default()
    tools = cap_map.tools_for("postman")
    assert len(tools) == 41
    # Spot-check a representative subset.
    assert "mcp__postman__getAuthenticatedUser" in tools
    assert "mcp__postman__runCollection" in tools
    assert "mcp__postman__createCollection" in tools
    assert "mcp__postman__updateCollectionRequest" in tools


def test_postman_tool_resolves_back_to_postman_tag() -> None:
    """Reverse lookup: an mcp__postman__* tool name resolves to {postman}."""
    cap_map = CapabilityMap.default()
    candidates = cap_map.candidate_tags_for("mcp__postman__runCollection")
    assert candidates == frozenset({"postman"})


def test_unmapped_tool_returns_empty_candidates() -> None:
    """An unknown tool name has zero candidate tags. The gateway uses
    this to surface a DENIED verdict with reason='unmapped'."""
    cap_map = CapabilityMap.default()
    assert cap_map.candidate_tags_for("DefinitelyNotARealTool") == frozenset()


def test_drift_yaml_has_extra_server_not_in_map(tmp_path: Path) -> None:
    """(d-negative) yaml declares 'random-mcp' but _MCP_MAP doesn't.
    CapabilityMap.default() must raise CapabilityMapDriftError naming the
    offending server name and the direction of drift."""
    fake_yaml = tmp_path / "mcp-tools.yaml"
    fake_yaml.write_text(
        """\
framework_mcp_tools:
  - name: postman
  - name: playwright
  - name: github
  - name: docling
  - name: random-mcp
""",
        encoding="utf-8",
    )
    with pytest.raises(CapabilityMapDriftError) as excinfo:
        CapabilityMap._build(fake_yaml)
    msg = str(excinfo.value)
    assert "random-mcp" in msg
    assert "NOT in" in msg  # directional message
    assert "_MCP_MAP" in msg
    # Negative assertions: non-drifting servers must NOT appear in the
    # error message; if they do, a set-difference bug is conflating clean
    # and drifting servers (found in review).
    for clean_server in ("postman", "playwright", "github", "docling"):
        assert clean_server not in msg


def test_drift_map_has_extra_server_not_in_yaml(tmp_path: Path) -> None:
    """(d-negative) yaml omits 'postman' but _MCP_MAP includes it.
    CapabilityMap.default() must raise CapabilityMapDriftError naming the
    offending server name and the direction of drift."""
    fake_yaml = tmp_path / "mcp-tools.yaml"
    fake_yaml.write_text(
        """\
framework_mcp_tools:
  - name: playwright
  - name: github
  - name: docling
""",
        encoding="utf-8",
    )
    with pytest.raises(CapabilityMapDriftError) as excinfo:
        CapabilityMap._build(fake_yaml)
    msg = str(excinfo.value)
    assert "postman" in msg
    assert "NOT in" in msg
    assert "framework_mcp_tools" in msg or "mcp-tools.yaml" in msg
    # Negative assertions: the three servers that DO appear in the fake
    # yaml must NOT appear as drift in the error message (found in review, same
    # rationale as the reverse-direction test).
    for clean_server in ("playwright", "github", "docling"):
        assert clean_server not in msg


def test_drift_matching_yaml_passes(tmp_path: Path) -> None:
    """(d-positive) yaml matches _MCP_MAP exactly → no drift, builds cleanly."""
    fake_yaml = tmp_path / "mcp-tools.yaml"
    fake_yaml.write_text(
        """\
framework_mcp_tools:
"""
        + "\n".join(f"  - name: {name}" for name in _MCP_MAP.keys()),
        encoding="utf-8",
    )
    cap_map = CapabilityMap._build(fake_yaml)
    assert cap_map is not None


def test_tags_returns_all_declared_capabilities() -> None:
    """tags() enumerates the full canonical capability surface."""
    cap_map = CapabilityMap.default()
    tags = cap_map.tags()
    # All native tags present.
    for t in (
        "repo.read",
        "worktree.write",
        "shell.exec.sandboxed",
        "shell.exec.unsandboxed",
        "test.run",
        "package.install.allowlisted",
        "task.spawn",
    ):
        assert t in tags
    # All MCP tags present.
    for t in ("postman", "playwright", "github", "docling"):
        assert t in tags
