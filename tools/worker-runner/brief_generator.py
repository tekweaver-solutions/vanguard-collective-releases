"""
brief_generator.py -- ADR-007 task-brief constructor.

Builds a per-dispatch TaskBrief (the input-of-record the framework
previously failed to construct) from a WorkerDispatch + the committed
spec + assertion files, and renders it to markdown for the worker.

Per ADR-007:
- Decision 1: the brief is a `task-brief.md` file the worker is
  instructed to read via the existing `--append-system-prompt` channel.
  This module produces the file body; runner.py writes the file and
  appends the read-the-brief pointer to the system prompt.
- Decision 2: the brief INDEXES versioned artifacts (spec feature +
  assertion files) by path; it does NOT inline their full text. This
  keeps drift impossible: the worker reads the frozen contract directly.
  The objective is derived deterministically from feature_id +
  assertion_targets.
- Decision 4: the brief is schema-validated at write time via the
  TaskBrief Pydantic model in schemas.py. Construction failures
  (missing spec, missing assertion file, unknown feature) raise
  BriefConstructionError BEFORE any partial brief lands on disk.
- Decision 5: `operator_note`, when supplied, is rendered under a
  labeled `## Operator note (out-of-contract)` section — additive to
  the artifact-derived objective, never replacing it.
- Decision 6: the inlined template's version string is what
  TaskBrief.brief_version (and LLMCallTrace.brief_version) records.
  Same registry-promotion debt as `_HANDOFF_INSTRUCTION_TEMPLATE`
  (the prompts-registry promotion is deferred);
  this module's `_TASK_BRIEF_TEMPLATE_VERSION` is the
  v0 home.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import uuid4

import yaml

from schemas import TaskBrief, WorkerDispatch


# --- Inlined template (decision 6 v0 home) ---

_TASK_BRIEF_TEMPLATE_VERSION = "inlined:_TASK_BRIEF_TEMPLATE:v1"
"""The version string TaskBrief.brief_version and LLMCallTrace.brief_version
record. Bumped when the template structure or wording materially changes.
Same debt pattern as `_HANDOFF_INSTRUCTION_TEMPLATE` -- promoted to the
prompts/ registry post-MVP per ADR-012/017."""

_BRIEF_CONSTRUCTOR_AGENT_ID = "claude-code:worker-runner"


class BriefConstructionError(RuntimeError):
    """Raised when the brief cannot be assembled deterministically from the
    committed artifacts (missing spec, unknown feature, missing assertion
    file). Surfaces at dispatch-construction time, BEFORE the worker is
    spawned -- a missing brief is a hard error, not a silent empty-task
    spawn (ADR-007 decision 1)."""


# --- Public entry ---


@dataclass(frozen=True)
class RenderedBrief:
    """The TaskBrief model + its rendered markdown body. Both are produced
    together so the renderer has the resolved feature/assertion paths
    without re-reading. The runner writes `markdown` to
    `.mission/dispatches/<dispatch_id>/task-brief.md`; the `brief` is
    available for trace embedding and audit."""

    brief: TaskBrief
    markdown: str


def build_and_render(
    dispatch: WorkerDispatch,
    project_root: Path,
    *,
    operator_note: Optional[str] = None,
    skills: Optional[list[str]] = None,
) -> RenderedBrief:
    """Construct the TaskBrief from `dispatch` + committed artifacts,
    validate it (Pydantic write-time), and render the markdown body.

    Raises BriefConstructionError if the spec or any assertion file is
    missing or the feature_id is not present in the spec.
    """
    feature_title = _load_feature_title(
        project_root, dispatch.spec_version, dispatch.feature_id
    )
    assertion_paths = _resolve_assertion_paths(
        project_root, dispatch.assertion_targets
    )

    spec_path = _spec_path(project_root, dispatch.spec_version)
    objective = _objective(dispatch.feature_id, list(dispatch.assertion_targets))

    brief = TaskBrief(
        id=uuid4(),
        created_at=_now_iso(),
        created_by=_BRIEF_CONSTRUCTOR_AGENT_ID,
        dispatch_id=str(dispatch.id),
        feature_id=dispatch.feature_id,
        spec_version=dispatch.spec_version,
        assertion_targets=list(dispatch.assertion_targets),
        objective=objective,
        skills=list(skills) if skills else None,
        operator_note=operator_note,
        brief_version=_TASK_BRIEF_TEMPLATE_VERSION,
    )

    markdown = _render_markdown(
        brief=brief,
        dispatch=dispatch,
        spec_path=spec_path,
        feature_title=feature_title,
        assertion_paths=assertion_paths,
    )
    return RenderedBrief(brief=brief, markdown=markdown)


# --- Internal: artifact lookups ---


def _spec_path(project_root: Path, spec_version: int) -> Path:
    # v010.yaml is the live shape (zero-padded width 3 with `v` prefix).
    return project_root / ".mission" / "spec" / f"v{spec_version:03d}.yaml"


def _load_feature_title(
    project_root: Path, spec_version: int, feature_id: str
) -> str:
    """Look up the feature's title from the frozen spec. Title is a small,
    spec-level metadata field (not feature body text) -- included in the
    rendered brief to anchor what the feature_id refers to without
    inlining the feature description (ADR-007 decision 2)."""
    spec_path = _spec_path(project_root, spec_version)
    if not spec_path.is_file():
        raise BriefConstructionError(
            f"spec file not found: {spec_path} "
            f"(dispatch.spec_version={spec_version})"
        )
    try:
        doc = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        raise BriefConstructionError(
            f"spec file {spec_path} failed to parse: {e}"
        ) from e
    if not isinstance(doc, dict):
        raise BriefConstructionError(
            f"spec file {spec_path} is not a mapping at top level"
        )
    features = doc.get("features")
    if not isinstance(features, list):
        raise BriefConstructionError(
            f"spec file {spec_path} has no `features:` list"
        )
    for feat in features:
        if isinstance(feat, dict) and feat.get("id") == feature_id:
            title = feat.get("title")
            if isinstance(title, str) and title.strip():
                return title.strip()
            return ""  # feature exists but has no title; brief renders without one
    raise BriefConstructionError(
        f"feature {feature_id!r} not found in {spec_path}"
    )


def _resolve_assertion_paths(
    project_root: Path, assertion_targets: list[str]
) -> list[Path]:
    """For each assertion id, verify the contract file exists and return
    its path. The brief indexes paths only -- not contents (decision 2)."""
    contract_dir = project_root / ".mission" / "contract" / "assertions"
    paths: list[Path] = []
    for aid in assertion_targets:
        p = contract_dir / f"{aid}.yaml"
        if not p.is_file():
            raise BriefConstructionError(
                f"assertion file not found: {p} (assertion id {aid!r})"
            )
        paths.append(p)
    return paths


# --- Internal: objective construction ---


def _objective(feature_id: str, assertion_targets: list[str]) -> str:
    """ADR-007 decision 2: 'implement {feature_id}; make {assertion_targets}
    pass'. Deterministic from the dispatch metadata; no spec text inlined."""
    if len(assertion_targets) == 1:
        joined = assertion_targets[0]
        suffix = "pass"
    else:
        joined = ", ".join(assertion_targets)
        suffix = "pass"
    return f"Implement {feature_id} such that {joined} {suffix}."


# --- Internal: markdown rendering ---


def _render_markdown(
    *,
    brief: TaskBrief,
    dispatch: WorkerDispatch,
    spec_path: Path,
    feature_title: str,
    assertion_paths: list[Path],
) -> str:
    """Render the brief to markdown. Indexes versioned artifact paths
    relative to the project root (ADR-007 decision 2: pointer-only)."""
    project_root = spec_path.parent.parent.parent
    spec_rel = _posix_rel(spec_path, project_root)

    lines: list[str] = []
    lines.append(f"# Task Brief -- {brief.feature_id}")
    lines.append("")
    lines.append(f"> Generator: `{brief.brief_version}` (ADR-007).")
    lines.append(
        f"> Brief id: `{brief.id}`. Dispatch id: `{brief.dispatch_id}`. "
        f"Constructed at {brief.created_at} by `{brief.created_by}`."
    )
    lines.append("")

    lines.append("## Objective")
    lines.append("")
    lines.append(brief.objective)
    if feature_title:
        lines.append("")
        lines.append(f"Feature title (from spec): _{feature_title}_")
    lines.append("")

    lines.append("## Artifacts to read")
    lines.append("")
    lines.append("Read these directly from the worktree -- the brief")
    lines.append("indexes versioned paths and does **not** inline their")
    lines.append("text (ADR-007 decision 2). The frozen contract is the")
    lines.append("source of truth.")
    lines.append("")
    lines.append(
        f"- **Spec (v{brief.spec_version:03d})**: `{spec_rel}` "
        f"-- locate the `features:` entry where `id: {brief.feature_id}`."
    )
    lines.append("- **Assertion targets** (must pass):")
    for aid, path in zip(brief.assertion_targets, assertion_paths):
        rel = _posix_rel(path, project_root)
        lines.append(f"    - `{aid}` -> `{rel}`")
    if dispatch.prior_handoff_id:
        lines.append(
            f"- **Prior handoff** (rework context): "
            f"`{dispatch.prior_handoff_id}` -- see "
            f"`.mission/handoffs/{dispatch.prior_handoff_id}.json` "
            f"(or `.mission-runtime/dispatches/` if not yet promoted)."
        )
    lines.append("")

    if brief.skills:
        lines.append("## Skills to consult (per ADR-023)")
        lines.append("")
        for skill_id in brief.skills:
            lines.append(f"- `{skill_id}`")
        lines.append("")
        lines.append(
            "Skill resolution is hand-specified by the operator in v1 "
            "(ADR-007 decision 3); auto-selection is deferred."
        )
        lines.append("")

    lines.append("## Reporting")
    lines.append("")
    lines.append(
        "Follow the framework-injected WORKER HANDOFF PROTOCOL in your "
        "system prompt to write the structured Handoff JSON on exit. The "
        "task brief and the handoff protocol are distinct surfaces -- "
        "this document tells you **what** to build; the handoff protocol "
        "tells you **how to report** when finished."
    )
    lines.append("")

    if brief.operator_note:
        lines.append("## Operator note (out-of-contract)")
        lines.append("")
        lines.append(
            "_Operator-supplied context. Not reproducible from the "
            "contract (ADR-007 decision 5). Additive to the objective "
            "above; does not override it._"
        )
        lines.append("")
        lines.append(brief.operator_note)
        lines.append("")

    return "\n".join(lines).rstrip("\n") + "\n"


def _posix_rel(p: Path, root: Path) -> str:
    try:
        rel = p.resolve().relative_to(root.resolve())
    except ValueError:
        rel = p
    return rel.as_posix()


def _now_iso() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )
