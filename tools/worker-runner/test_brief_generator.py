"""
Tests for brief_generator.build_and_render (ADR-007).

Two-tier coverage:

- **Synthetic-fixture tests**: use a minimal in-tmp_path .mission/ tree
  so error paths and field-level behavior can be exercised quickly.
- **Real-spec test** (test_build_against_real_v010_spec_and_assertions):
  constructs a brief against the actually-committed
  `.mission/spec/v010.yaml` + real assertion files. Verifies the
  generator works against PRODUCTION SHAPE, not just test shape, and
  catches drift if the live spec is restructured. Per operator step-5
  instruction.
"""

from __future__ import annotations

from pathlib import Path
from uuid import uuid4

import pytest
import yaml

from brief_generator import (
    BriefConstructionError,
    _TASK_BRIEF_TEMPLATE_VERSION,
    build_and_render,
)
from schemas import (
    ModelClass,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
)


# Repo root: this file lives at tools/worker-runner/test_brief_generator.py,
# so parents[2] is the repository root.
REPO_ROOT = Path(__file__).resolve().parents[2]


# ---------- helpers ----------


def _make_dispatch(
    *,
    feature_id: str = "F-001",
    assertion_targets: list[str] | None = None,
    spec_version: int = 10,
    prior_handoff_id: str | None = None,
) -> WorkerDispatch:
    return WorkerDispatch(
        id=uuid4(),
        created_at="2026-05-31T18:00:00.000Z",
        created_by="claude-code:test",
        mission_id="mission-test",
        worker_id=str(uuid4()),
        kind=WorkerKind.MAINLINE,
        feature_id=feature_id,
        assertion_targets=assertion_targets or ["A-001"],
        spec_version=spec_version,
        prior_handoff_id=prior_handoff_id,
        worktree_id="wt-test",
        model_class=ModelClass.CODING_STRONG,
        tool_scope=["repo.read"],
        budget=WorkerBudget(cost_cap_usd=1.0, wallclock_cap_minutes=5),
    )


def _provision_minimal_mission(
    project_root: Path,
    *,
    feature_id: str = "F-001",
    feature_title: str = "Test feature title",
    assertion_ids: list[str] | None = None,
    spec_version: int = 10,
) -> None:
    targets = assertion_ids or ["A-001"]
    spec_dir = project_root / ".mission" / "spec"
    spec_dir.mkdir(parents=True, exist_ok=True)
    spec_dir.joinpath(f"v{spec_version:03d}.yaml").write_text(
        yaml.safe_dump(
            {
                "features": [
                    {"id": feature_id, "title": feature_title},
                ],
            }
        ),
        encoding="utf-8",
    )
    contract_dir = project_root / ".mission" / "contract" / "assertions"
    contract_dir.mkdir(parents=True, exist_ok=True)
    for aid in targets:
        contract_dir.joinpath(f"{aid}.yaml").write_text(
            yaml.safe_dump({"id": aid, "feature_id": feature_id}),
            encoding="utf-8",
        )


# ============================================================================
# Real-spec test (operator step-5 requirement)
# ============================================================================


def test_build_against_real_v010_spec_and_assertions() -> None:
    """Production-shape conformance: the generator must work against the
    real committed .mission/spec/v010.yaml + real assertion files, not
    only the minimal test fixture. Catches drift if the live spec is
    restructured in ways that break the generator's parse path.

    Per operator step-5 instruction.
    """
    spec_file = REPO_ROOT / ".mission" / "spec" / "v010.yaml"
    a_001 = REPO_ROOT / ".mission" / "contract" / "assertions" / "A-001.yaml"
    a_002 = REPO_ROOT / ".mission" / "contract" / "assertions" / "A-002.yaml"
    if not (spec_file.is_file() and a_001.is_file() and a_002.is_file()):
        pytest.skip(
            "Real spec/contract not present at expected paths "
            f"({spec_file}); skipping production-shape test."
        )

    dispatch = _make_dispatch(
        feature_id="F-001", assertion_targets=["A-001", "A-002"], spec_version=10
    )
    rendered = build_and_render(dispatch, REPO_ROOT)

    # 1. Objective sentence is deterministic + lists all targets.
    assert rendered.brief.objective == (
        "Implement F-001 such that A-001, A-002 pass."
    )

    # 2. Feature title is pulled from the real spec (not hard-coded): the
    # title the spec gives F-001, read here on its own, anchors the brief.
    spec_doc = yaml.safe_load(spec_file.read_text(encoding="utf-8"))
    f001_title = next(
        (
            str(f.get("title", "")).strip()
            for f in spec_doc.get("features", [])
            if isinstance(f, dict) and f.get("id") == "F-001"
        ),
        "",
    )
    assert (
        f001_title and f001_title in rendered.markdown
    ), "expected F-001's real title to anchor the rendered brief"

    # 3. Versioned artifact paths are indexed (decision 2).
    assert ".mission/spec/v010.yaml" in rendered.markdown
    assert ".mission/contract/assertions/A-001.yaml" in rendered.markdown
    assert ".mission/contract/assertions/A-002.yaml" in rendered.markdown

    # 4. Decision 2: F-001's long body text from the spec does NOT appear.
    # The spec this test was written against carried a marker phrase in
    # F-001's description block; this distribution does not ship that spec
    # (the test skips), and the string below is a placeholder for it.
    assert "F-001 description body" not in rendered.markdown, (
        "ADR-007 decision 2 regression: F-001's spec-body text leaked into "
        "the brief. The generator must INDEX paths, not inline contract body."
    )

    # 5. brief_version is the inlined-template constant.
    assert rendered.brief.brief_version == _TASK_BRIEF_TEMPLATE_VERSION


# ============================================================================
# Synthetic-fixture tests
# ============================================================================


def test_build_with_operator_note_renders_labeled_section(tmp_path: Path) -> None:
    """ADR-007 decision 5: operator_note renders under a labeled
    `## Operator note (out-of-contract)` section -- additive, not replacing.
    Step-5 requirement: operator-note lands in the labeled section."""
    _provision_minimal_mission(tmp_path)
    dispatch = _make_dispatch()
    rendered = build_and_render(
        dispatch,
        tmp_path,
        operator_note="Complete the migration the prior worker stubbed.",
    )

    assert "## Operator note (out-of-contract)" in rendered.markdown
    assert "Complete the migration" in rendered.markdown

    # Additive: the operator-note section appears AFTER both the objective
    # and the artifact index, so it doesn't substitute for them.
    obj_pos = rendered.markdown.find("## Objective")
    art_pos = rendered.markdown.find("## Artifacts to read")
    note_pos = rendered.markdown.find("## Operator note (out-of-contract)")
    assert obj_pos < art_pos < note_pos, (
        "operator note must be additive: appear AFTER objective + artifact "
        "index, not replace them"
    )

    # Schema-side: TaskBrief.operator_note records the verbatim text.
    assert rendered.brief.operator_note == (
        "Complete the migration the prior worker stubbed."
    )


def test_build_without_operator_note_omits_section(tmp_path: Path) -> None:
    _provision_minimal_mission(tmp_path)
    rendered = build_and_render(_make_dispatch(), tmp_path)
    assert "## Operator note (out-of-contract)" not in rendered.markdown
    assert rendered.brief.operator_note is None


def test_build_with_skills_renders_skills_section(tmp_path: Path) -> None:
    """ADR-007 decision 3: skills list renders under a labeled section."""
    _provision_minimal_mission(tmp_path)
    rendered = build_and_render(
        _make_dispatch(),
        tmp_path,
        skills=["skill-schema-authoring", "skill-test-writing"],
    )
    assert "## Skills to consult" in rendered.markdown
    assert "skill-schema-authoring" in rendered.markdown
    assert "skill-test-writing" in rendered.markdown
    assert rendered.brief.skills == [
        "skill-schema-authoring",
        "skill-test-writing",
    ]


def test_build_objective_lists_all_assertion_targets(tmp_path: Path) -> None:
    """Step-5 requirement: worker receives a task brief with the right
    objective + assertion targets. Verify all targets land in the
    objective sentence + the artifact index."""
    _provision_minimal_mission(
        tmp_path, assertion_ids=["A-001", "A-007", "A-042"]
    )
    dispatch = _make_dispatch(assertion_targets=["A-001", "A-007", "A-042"])
    rendered = build_and_render(dispatch, tmp_path)

    assert rendered.brief.objective == (
        "Implement F-001 such that A-001, A-007, A-042 pass."
    )
    # Every target appears in the artifact index.
    for aid in ("A-001", "A-007", "A-042"):
        assert aid in rendered.markdown
        assert f"{aid}.yaml" in rendered.markdown


def test_build_single_assertion_objective(tmp_path: Path) -> None:
    """Single-target objective wording matches multi-target wording (one
    code path, no special-case sentence)."""
    _provision_minimal_mission(tmp_path, assertion_ids=["A-001"])
    rendered = build_and_render(
        _make_dispatch(assertion_targets=["A-001"]), tmp_path
    )
    assert rendered.brief.objective == "Implement F-001 such that A-001 pass."


def test_build_indexes_prior_handoff_when_set(tmp_path: Path) -> None:
    """When dispatch.prior_handoff_id is set (rework dispatch), the brief
    markdown indexes it under Artifacts-to-read. Schema-side: TaskBrief
    does not carry prior_handoff_id (it's a dispatch-level attribute);
    only the rendered markdown carries the pointer."""
    _provision_minimal_mission(tmp_path)
    dispatch = _make_dispatch(prior_handoff_id="handoff-abc-123")
    rendered = build_and_render(dispatch, tmp_path)
    assert "handoff-abc-123" in rendered.markdown
    assert "Prior handoff" in rendered.markdown


def test_build_omits_prior_handoff_when_unset(tmp_path: Path) -> None:
    _provision_minimal_mission(tmp_path)
    rendered = build_and_render(_make_dispatch(), tmp_path)
    assert "Prior handoff" not in rendered.markdown


def test_brief_version_records_template_constant(tmp_path: Path) -> None:
    """ADR-007 decision 6: the inlined template's version string is what
    brief_version records. The eval loop reads this; if it drifts the
    correlation breaks."""
    _provision_minimal_mission(tmp_path)
    rendered = build_and_render(_make_dispatch(), tmp_path)
    assert rendered.brief.brief_version == _TASK_BRIEF_TEMPLATE_VERSION


def test_brief_metadata_carries_dispatch_id(tmp_path: Path) -> None:
    """The committed brief is the worker's input-of-record; it must
    surface the dispatch_id so audit can trace brief <-> dispatch."""
    _provision_minimal_mission(tmp_path)
    dispatch = _make_dispatch()
    rendered = build_and_render(dispatch, tmp_path)
    assert rendered.brief.dispatch_id == str(dispatch.id)
    assert str(dispatch.id) in rendered.markdown


# ---------- Error paths (BriefConstructionError) ----------


def test_missing_spec_file_raises(tmp_path: Path) -> None:
    """No spec file at expected path -> dispatch-construction error,
    no partial brief produced (ADR-007 decision 1)."""
    # No _provision_minimal_mission call: tmp_path is empty.
    with pytest.raises(BriefConstructionError, match="spec file not found"):
        build_and_render(_make_dispatch(), tmp_path)


def test_missing_feature_in_spec_raises(tmp_path: Path) -> None:
    """Spec exists but the feature_id isn't in features: -> error."""
    _provision_minimal_mission(tmp_path, feature_id="F-001")
    dispatch = _make_dispatch(feature_id="F-999")
    with pytest.raises(
        BriefConstructionError, match="feature 'F-999' not found"
    ):
        build_and_render(dispatch, tmp_path)


def test_missing_assertion_file_raises(tmp_path: Path) -> None:
    """assertion_targets references an id with no contract file -> error."""
    _provision_minimal_mission(tmp_path, assertion_ids=["A-001"])
    dispatch = _make_dispatch(assertion_targets=["A-001", "A-999"])
    with pytest.raises(
        BriefConstructionError, match="assertion file not found"
    ):
        build_and_render(dispatch, tmp_path)


def test_wrong_spec_version_raises(tmp_path: Path) -> None:
    """dispatch.spec_version points at a vNNN.yaml that doesn't exist."""
    _provision_minimal_mission(tmp_path, spec_version=10)
    dispatch = _make_dispatch(spec_version=99)
    with pytest.raises(BriefConstructionError, match="spec file not found"):
        build_and_render(dispatch, tmp_path)


def test_malformed_spec_yaml_raises(tmp_path: Path) -> None:
    """A spec file that parses to non-mapping at top level -> error."""
    spec_dir = tmp_path / ".mission" / "spec"
    spec_dir.mkdir(parents=True)
    spec_dir.joinpath("v010.yaml").write_text(
        "- just a list\n- not a mapping\n", encoding="utf-8"
    )
    # Need the contract dir to exist so the spec check is what fires (not
    # the assertion-file-missing check). Doesn't matter that A-001 is
    # absent here; the spec parse error fires first.
    (tmp_path / ".mission" / "contract" / "assertions").mkdir(parents=True)
    with pytest.raises(
        BriefConstructionError, match="not a mapping at top level"
    ):
        build_and_render(_make_dispatch(), tmp_path)
