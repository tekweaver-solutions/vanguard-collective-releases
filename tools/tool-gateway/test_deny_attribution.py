"""
Decision-E (deny-attribution fix) contract tests.

Per .mission-runtime/preflight/adr-026-027-impl-design.md Part D.5 and
ADR-026 §"Note on Decision E (deny-attribution) — handled separately."

The pre-Decision-E behavior: a multi-candidate DENY (a tool covered by
multiple capabilities but none in worker scope) had
`capability_tag = sorted(candidates)[0]` — alphabetically-first. For Bash
(4 candidates), this was always `package.install.allowlisted`, regardless
of which tag the worker likely meant to request. Audit consumers reading
the `capability_tag` field alone got a misleading signal; the
audit-rich field was `reason` (which listed all candidates).

The Decision-E fix: on a multi-candidate DENY, `capability_tag` is the
sentinel `framework.deny.multi_candidate` (NOT the alphabetical-first).
The reason string still lists all candidates (audit-rich field unchanged).

  - Single-candidate DENY: unchanged (capability_tag is the single
    candidate; that IS what the worker would have needed; no
    misattribution risk).
  - ALLOWED: unchanged (sorted(matching)[0] is deterministic + correct;
    it's "which scope tag authorized this" not "which of all candidates").
"""

from __future__ import annotations

import pytest

from mcp_capability_map import CapabilityMap
from policy import Gateway, Verdict
from schemas import GatewayDecision


# Sentinel under test (Step 3 adds it to policy.py).
from policy import MULTI_CANDIDATE_DENY_SENTINEL


@pytest.fixture
def gateway() -> Gateway:
    return Gateway(CapabilityMap.default())


# ============================================================================
# D.5 — Decision-E (deny-attribution)
# ============================================================================

def test_d5a_multi_candidate_deny_returns_sentinel(gateway: Gateway) -> None:
    """D.5.a: Gateway.check('Bash', ['repo.read']) — Bash has 4 candidate
    capabilities, none in worker scope. Pre-Decision-E: capability_tag was
    `package.install.allowlisted` (alphabetical-first, misleading).
    Post-Decision-E: capability_tag is `framework.deny.multi_candidate`."""
    v = gateway.check("Bash", tool_scope=["repo.read"])
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == MULTI_CANDIDATE_DENY_SENTINEL, (
        f"multi-candidate DENY must use the sentinel; got {v.capability_tag!r}"
    )


def test_d5b_multi_candidate_deny_reason_lists_all_candidates(
    gateway: Gateway,
) -> None:
    """D.5.b: the reason string still lists ALL Bash-covering candidates
    (audit-rich field unchanged by Decision-E). Operator audit can read
    the reason to see what scope the worker would have needed."""
    v = gateway.check("Bash", tool_scope=["repo.read"])
    assert v.reason is not None
    # All four current Bash-covering capabilities must appear in reason.
    for candidate in (
        "shell.exec.sandboxed",
        "shell.exec.unsandboxed",
        "test.run",
        "package.install.allowlisted",
    ):
        assert candidate in v.reason, (
            f"reason must list candidate {candidate!r}; got {v.reason!r}"
        )


def test_d5c_allowed_case_unchanged(gateway: Gateway) -> None:
    """D.5.c: Gateway.check('Write', ['worktree.write']) — single matching
    candidate in scope. ALLOWED path unchanged by Decision-E. The
    capability_tag is the matching scope tag (the tag that authorized),
    NOT the multi-candidate sentinel."""
    v = gateway.check("Write", tool_scope=["worktree.write"])
    assert v.decision == GatewayDecision.ALLOWED
    assert v.capability_tag == "worktree.write"


def test_d5d_unmapped_tool_unchanged(gateway: Gateway) -> None:
    """D.5.d: Gateway.check('UnknownTool', ['repo.read']) — tool has no
    candidates at all. DENIED with capability_tag `(unmapped)` unchanged
    by Decision-E. The unmapped sentinel and the multi-candidate sentinel
    are DIFFERENT verdict-shape signals; both must be distinguishable to
    audit consumers."""
    v = gateway.check("UnknownToolThatDoesNotExist", tool_scope=["repo.read"])
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == "(unmapped)"
    assert v.capability_tag != MULTI_CANDIDATE_DENY_SENTINEL


def test_d5e_single_candidate_deny_returns_the_candidate(
    gateway: Gateway,
) -> None:
    """D.5.e: Gateway.check('Read', []) — Read has a single covering
    capability (repo.read), worker scope is empty. Single-candidate DENY:
    capability_tag IS the single candidate (`repo.read`), NOT the
    multi-candidate sentinel. The user gets a useful 'you would have
    needed X' hint when there's only one option.

    (Note: empty tool_scope normally fails WorkerDispatch min_length=1
    schema invariant — this test calls Gateway.check directly, which has
    no such constraint, exercising the gate-level behavior in isolation.)"""
    v = gateway.check("Read", tool_scope=[])
    assert v.decision == GatewayDecision.DENIED
    assert v.capability_tag == "repo.read", (
        f"single-candidate DENY uses the candidate, not the sentinel; "
        f"got {v.capability_tag!r}"
    )
    assert v.capability_tag != MULTI_CANDIDATE_DENY_SENTINEL
