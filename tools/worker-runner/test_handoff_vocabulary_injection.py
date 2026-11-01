"""
Contract tests for the handoff-vocabulary injection (option 4 of the
instance-7 fix from ledger-handoff-recovery-instance-7-brief-doesnt-index-
schemas-enums).

The worker's appended-system-prompt handoff-protocol instruction
(_HANDOFF_INSTRUCTION_TEMPLATE in runner.py) historically listed the
field NAMES the worker must populate but did NOT enumerate the
valid Blocker enum values or describe §5 constraint 1 (terminated_reason:
completed forbidden with non-empty unfinished). The F-001 re-dispatch
recovery showed this gap causes worker schema-invention (worker invented
`manual_observation_pending` as a Blocker value).

Option 4 (this implementation): derive the enum vocabularies from
schemas.py by INTROSPECTION and inject them into the handoff-protocol
instruction by construction. Drift-proof for the enum halves; the §5
constraint is injected as DESCRIBED prose (drift-prone residual that
option 3 — pre-exit handoff validation round-trip — would close, scoped
as a follow-up).

Tests come from the contract, not from "whatever the implementation does."
"""

from __future__ import annotations

import enum

import pytest

import schemas
from runner import _derive_handoff_vocabulary


# ============================================================================
# Enum derivation: positive membership
# ============================================================================

def test_blocker_block_contains_all_current_blocker_members() -> None:
    """The injected vocabulary must list every value the current Blocker
    enum defines. Derived from schemas.Blocker by introspection."""
    block = _derive_handoff_vocabulary()
    for member in schemas.Blocker:
        assert member.value in block, (
            f"Blocker member {member.value!r} missing from injected vocabulary"
        )


def test_terminated_reason_block_contains_all_current_members() -> None:
    """The injected vocabulary must list every value the current
    TerminatedReason enum defines."""
    block = _derive_handoff_vocabulary()
    for member in schemas.TerminatedReason:
        assert member.value in block, (
            f"TerminatedReason member {member.value!r} missing from "
            f"injected vocabulary"
        )


def test_block_labels_each_enum_so_worker_can_locate(
) -> None:
    """The vocabulary block uses identifiable labels (`Blocker:` and
    `TerminatedReason:` headings or equivalent) so a worker reading the
    block knows WHICH enum the values belong to. Operator-named:
    avoid a single undifferentiated list of values."""
    block = _derive_handoff_vocabulary()
    # Case-insensitive presence check for the enum names.
    bl = block.lower()
    assert "blocker" in bl, "vocabulary block must label the Blocker enum"
    assert "terminated_reason" in bl, (
        "vocabulary block must label the TerminatedReason enum"
    )


# ============================================================================
# §5 constraint 1 description (DESCRIBED prose, not derived; residual
# captured for option 3 follow-up)
# ============================================================================

def test_block_describes_section5_constraint1_completed_with_unfinished() -> None:
    """§5 constraint 1: terminated_reason cannot be `completed` when
    unfinished is non-empty. The vocabulary block must DESCRIBE this rule
    so the worker doesn't hit the constraint as a schema-validation
    surprise.

    NOTE (load-bearing): this constraint is DESCRIBED in prose, NOT derived.
    The description can drift from the constraint's actual code
    (schemas.py:535-544 _validate_unfinished_vs_completed). Option 3 of
    the instance-7 fix (pre-exit handoff validation round-trip) would
    catch a drift; option 4 alone cannot. This test asserts the description
    is PRESENT, not that it matches the code byte-for-byte (it can't, by
    nature of being prose).
    """
    block = _derive_handoff_vocabulary()
    bl = block.lower()
    # The rule mentions: "completed" + ("unfinished" must be empty / no
    # unfinished / non-empty unfinished forbidden).
    assert "completed" in bl
    assert "unfinished" in bl
    # And the recommended alternative for the F-002-dependency case:
    # amendment_filed when an amendment was filed (the F-001 re-dispatch
    # recovery's exact path).
    assert "amendment_filed" in bl, (
        "vocabulary block should mention amendment_filed as the alternative "
        "when worker has filed an amendment for the unfinished items"
    )


# ============================================================================
# DERIVATION INTEGRITY — proves the enum halves are derived, not hardcoded
# ============================================================================

def test_derivation_integrity_blocker_monkeypatched(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """If a value is added to the Blocker enum, the derivation reflects
    it. Proves the enum half is introspected from schemas.Blocker, not a
    hardcoded list.

    Approach: synthesize a new Blocker-like Enum class with one extra
    member, monkeypatch schemas.Blocker to that, call the derivation,
    confirm the extra member appears AND the standard members appear.
    """
    SyntheticBlocker = enum.Enum(
        "SyntheticBlocker",
        {
            "SPEC_AMBIGUOUS": "spec_ambiguous",
            "DEPENDENCY_MISSING": "dependency_missing",
            "TOOL_UNAVAILABLE": "tool_unavailable",
            "TIME_EXHAUSTED": "time_exhausted",
            "UNKNOWN": "unknown",
            # NEW (synthetic addition):
            "OBSERVATION_PENDING": "observation_pending",
        },
        type=str,
    )
    monkeypatch.setattr(schemas, "Blocker", SyntheticBlocker)
    block = _derive_handoff_vocabulary()
    # New member appears.
    assert "observation_pending" in block, (
        "derivation must reflect the live schemas.Blocker; "
        "did not include the monkeypatched addition"
    )
    # Standard members ALSO appear (we didn't lose any).
    for v in ("spec_ambiguous", "dependency_missing", "tool_unavailable",
              "time_exhausted", "unknown"):
        assert v in block


def test_derivation_integrity_terminated_reason_monkeypatched(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Same derivation-integrity test for TerminatedReason."""
    SyntheticTR = enum.Enum(
        "SyntheticTR",
        {
            "COMPLETED": "completed",
            "BUDGET_EXHAUSTED": "budget_exhausted",
            "TOOL_BLOCKED": "tool_blocked",
            "AMENDMENT_FILED": "amendment_filed",
            "CRASH_RECOVERED": "crash_recovered",
            # NEW (synthetic addition):
            "CLOSEABLE_SUBSET_DONE": "closeable_subset_done",
        },
        type=str,
    )
    monkeypatch.setattr(schemas, "TerminatedReason", SyntheticTR)
    block = _derive_handoff_vocabulary()
    assert "closeable_subset_done" in block, (
        "derivation must reflect the live schemas.TerminatedReason; "
        "did not include the monkeypatched addition"
    )
    for v in ("completed", "budget_exhausted", "tool_blocked",
              "amendment_filed", "crash_recovered"):
        assert v in block


# ============================================================================
# Integration: the rendered handoff_instruction body contains the block
# ============================================================================

def test_rendered_handoff_instruction_includes_vocabulary_block() -> None:
    """End-to-end: the assembled handoff_instruction string the runner
    writes to system-prompt.txt contains the vocabulary block. Verifies
    the injection at the template-format seam, not just the derivation."""
    from runner import _HANDOFF_INSTRUCTION_TEMPLATE
    block = _derive_handoff_vocabulary()
    rendered = _HANDOFF_INSTRUCTION_TEMPLATE.format(
        handoff_path="/tmp/handoff.json",
        worker_id="worker-test",
        dispatch_id="dispatch-test",
        feature_id="F-001",
        spec_version=10,
        assertion_targets=["A-001"],
        handoff_vocabulary=block,
    )
    # The block must appear verbatim in the rendered output.
    assert block in rendered, (
        "derived vocabulary block must be present in the rendered "
        "handoff_instruction; the {handoff_vocabulary} placeholder is "
        "the injection seam"
    )
    # Spot-check a representative enum value in the rendered output to
    # catch the case where the block is present but the format substitution
    # accidentally elided its contents.
    assert "dependency_missing" in rendered
    assert "amendment_filed" in rendered
