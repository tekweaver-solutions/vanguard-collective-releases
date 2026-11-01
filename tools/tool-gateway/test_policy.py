"""
Tests for policy.Gateway.

Coverage matches the operator-named test architectural properties:
- (c) denial path with reason (three flavors: unmapped tool, scope-doesn't-match,
      and the allowed positive case as a control)
- Deterministic capability_tag selection on ALLOWED (alphabetical pick).
- Multi-tag tool (Bash) resolves to whichever matching tag the scope has.
"""

from __future__ import annotations

from dataclasses import FrozenInstanceError

import pytest

from schemas import GatewayDecision

from mcp_capability_map import CapabilityMap
from policy import (
    HANDOFF_EXEMPTION_CAPABILITY,
    Gateway,
    Verdict,
    is_handoff_write_exemption,
)


@pytest.fixture
def gateway() -> Gateway:
    return Gateway(CapabilityMap.default())


def test_allowed_native_call(gateway: Gateway) -> None:
    """Worker has repo.read in scope; Read is permitted."""
    v = gateway.check("Read", tool_scope=["repo.read"])
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == "repo.read"
    assert v.reason is None


def test_allowed_mcp_call(gateway: Gateway) -> None:
    """Worker has postman in scope; mcp__postman__runCollection is permitted."""
    v = gateway.check(
        "mcp__postman__runCollection",
        tool_scope=["postman", "repo.read"],
    )
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == "postman"


def test_denied_unmapped_tool(gateway: Gateway) -> None:
    """(c) Tool not in any capability → DENIED with sentinel capability_tag
    and reason explaining the absence."""
    v = gateway.check("TotallyUnknownTool", tool_scope=["repo.read"])
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == "(unmapped)"
    assert v.reason is not None
    assert "TotallyUnknownTool" in v.reason
    assert "not covered" in v.reason


def test_denied_scope_lacks_capability(gateway: Gateway) -> None:
    """(c) Tool exists in map; worker scope doesn't include any covering tag.
    Verdict's capability_tag is the multi-candidate sentinel (post-Decision-E,
    per ADR-026 §"Note on Decision E"); the reason field is the audit-rich
    source naming all candidates.

    Pre-Decision-E this asserted `package.install.allowlisted` as the deny
    tag — the alphabetical-first of Bash's four candidates. That was
    misleading: it implied the worker meant to request package-install
    when in practice the worker likely meant test.run or shell.exec.*.
    Post-Decision-E the deny tag is the unambiguous sentinel; the reason
    string carries the full candidate list."""
    from policy import MULTI_CANDIDATE_DENY_SENTINEL
    v = gateway.check("Bash", tool_scope=["repo.read"])
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == MULTI_CANDIDATE_DENY_SENTINEL
    assert v.reason is not None
    assert "Bash" in v.reason
    assert "tool_scope" in v.reason
    # All four candidates surface in the reason for operator inspection.
    for candidate in (
        "shell.exec.sandboxed",
        "shell.exec.unsandboxed",
        "test.run",
        "package.install.allowlisted",
    ):
        assert candidate in v.reason


def test_bash_with_sandboxed_capability_resolves_to_sandboxed_tag(
    gateway: Gateway,
) -> None:
    """Worker has shell.exec.sandboxed; Bash call is allowed; the recorded
    capability_tag is shell.exec.sandboxed (the tag actually in scope, not
    the alphabetical first across all candidates)."""
    v = gateway.check("Bash", tool_scope=["shell.exec.sandboxed"])
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == "shell.exec.sandboxed"


def test_bash_with_multiple_scope_tags_picks_alphabetical_first(
    gateway: Gateway,
) -> None:
    """If multiple tags in scope match, the gateway picks deterministically
    (alphabetical). Auditability + reproducibility."""
    v = gateway.check(
        "Bash",
        tool_scope=[
            "shell.exec.unsandboxed",
            "test.run",
            "package.install.allowlisted",
        ],
    )
    assert v.decision == GatewayDecision.ALLOWED
    # All three are in scope and cover Bash; alphabetical-first is
    # package.install.allowlisted.
    assert v.capability_tag == "package.install.allowlisted"


def test_verdict_is_frozen() -> None:
    """Verdict is immutable evidence. Catching the precise FrozenInstanceError
    will detect if a future refactor changes the immutability mechanism
    (e.g., to Pydantic which raises ValidationError)."""
    v = Verdict(
        decision=GatewayDecision.ALLOWED,
        capability_tag="repo.read",
        reason=None,
    )
    with pytest.raises(FrozenInstanceError):
        v.decision = GatewayDecision.DENIED  # type: ignore[misc]


# ============================================================================
# Handoff-protocol exact-path exemption
# ============================================================================
#
# `is_handoff_write_exemption` is the shared predicate the gateway_hook
# subprocess AND the runner's local-gateway cross-check both call. They
# MUST agree; otherwise a §6.2 EscalationTrace fires falsely on every
# legitimate handoff Write.


def test_exemption_fires_on_exact_path_write(tmp_path) -> None:
    handoff = str(tmp_path / "dispatch-X" / "handoff.json")
    assert is_handoff_write_exemption(
        "Write", {"file_path": handoff}, handoff
    )


def test_exemption_does_not_fire_on_sibling_path(tmp_path) -> None:
    """CRITICAL NEGATIVE: a Write to ANOTHER file under the same dispatch
    dir is NOT exempt. The exemption is exact-path; the read-only
    guarantee for sibling paths must hold."""
    dispatch_dir = tmp_path / "dispatch-X"
    handoff = str(dispatch_dir / "handoff.json")
    sibling = str(dispatch_dir / "tool_scope.json")
    assert not is_handoff_write_exemption(
        "Write", {"file_path": sibling}, handoff
    )


def test_exemption_does_not_fire_on_edit_of_handoff_path(tmp_path) -> None:
    """The exemption is Write-tool-only. Edit (which assumes a prior file)
    is not part of the framework handoff protocol."""
    handoff = str(tmp_path / "dispatch-X" / "handoff.json")
    assert not is_handoff_write_exemption(
        "Edit",
        {"file_path": handoff, "old_string": "x", "new_string": "y"},
        handoff,
    )


def test_exemption_does_not_fire_on_other_tools(tmp_path) -> None:
    """Read, Glob, Bash etc. -- exemption is Write-only."""
    handoff = str(tmp_path / "dispatch-X" / "handoff.json")
    for tool in ("Read", "Glob", "Bash", "PowerShell", "NotebookEdit"):
        assert not is_handoff_write_exemption(
            tool, {"file_path": handoff}, handoff
        ), f"exemption wrongly fired for tool={tool}"


def test_exemption_normalizes_slash_directions(tmp_path) -> None:
    """tool_input.file_path may arrive forward-slash or backslash. The
    exemption uses os.path.normcase(normpath(abspath(...))) so equivalent
    representations of the same handoff file are equally exempt."""
    handoff = str(tmp_path / "dispatch-X" / "handoff.json")
    forward = handoff.replace("\\", "/")
    backward = handoff.replace("/", "\\")
    assert is_handoff_write_exemption(
        "Write", {"file_path": forward}, handoff
    )
    assert is_handoff_write_exemption(
        "Write", {"file_path": backward}, handoff
    )


def test_exemption_rejects_malformed_input(tmp_path) -> None:
    """Defensive: non-string file_path, missing file_path, non-dict
    tool_input, empty strings -- all return False (no exemption)."""
    handoff = str(tmp_path / "dispatch-X" / "handoff.json")
    assert not is_handoff_write_exemption("Write", None, handoff)
    assert not is_handoff_write_exemption("Write", {}, handoff)
    assert not is_handoff_write_exemption("Write", {"file_path": ""}, handoff)
    assert not is_handoff_write_exemption("Write", {"file_path": 42}, handoff)
    assert not is_handoff_write_exemption(
        "Write", {"file_path": handoff}, ""
    )


def test_exemption_capability_tag_constant() -> None:
    """The observable marker constant: framework.handoff_exemption.
    Locked here so runner / gateway_hook / trace consumers all agree on
    the exact string. A future change that breaks this token breaks
    audit-trail-grep against the trace store."""
    assert HANDOFF_EXEMPTION_CAPABILITY == "framework.handoff_exemption"
