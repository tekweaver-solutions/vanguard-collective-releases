"""
dispatch_entry.py -- Python orchestration core for step 8.

The PowerShell entry script (tools/mission-dispatch.ps1) parses operator
arguments, validates the mission state, and invokes this module via:

    python -m worker_runner.dispatch_entry <args-json>

or equivalent. This module:
1. Builds a WorkerDispatch from operator inputs + spec/contract lookup
   (the hybrid construction approach per a step-8 design answer).
2. Creates a worktree via WorktreeManager (per-dispatch suffix branch
   per a resolution).
3. Configures the per-dispatch hook (hook_config.write_dispatch_config).
4. Instantiates WorkerRunner with all wiring (TraceStore, Gateway,
   AuditLog) + runs the dispatch.
5. Cross-artifact-validates the produced Handoff via
   handoff_validator.validate_handoff_against_dispatch.
6. Returns a structured DispatchResult to the PS caller via stdout JSON.

**Step-8 scope per an operator answer (option γ):** dispatch → runner →
validate → report ONLY. Promotion of the handoff to .mission/handoffs/
and worktree cleanup are separate operator-driven follow-on commands
(future `mission promote-handoff` and `mission cleanup-worktree`).

**Exit code contract** (per an operator answer's refinement):
  0 success (Handoff valid + dispatch complete)
  1 validation failure (ValidationReport.is_valid=False; recoverable)
  2 runtime failure (runner crash, subprocess error, handoff-parse error)
  3 operator error (bad args, missing spec, invalid dispatch construction)

mission-dispatch.ps1 propagates these verbatim.

**Worker_id convention** (per an operator answer): worker_ids are
UUIDs. The runner's _looks_like_uuid fallback never fires. This entry
mints worker_id as uuid4() always.

**milestone_id is a construction-time arg, NOT a WorkerDispatch field**
(per an operator answer). The -MilestoneId arg filters assertion_targets via the
auto-derive rule (found in review): every assertion where
assertion.feature_id == dispatch.feature_id AND
assertion.milestone_id == matching-milestone.
"""

from __future__ import annotations

import json
import logging
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from uuid import uuid4

# Set up sys.path for cross-directory framework imports BEFORE the imports.
# Standalone invocation (python dispatch_entry.py ...) doesn't go through
# pytest's conftest sys.path bridge; this block makes the module
# self-contained for direct execution.
_HERE = Path(__file__).parent
_TOOLS_ROOT = _HERE.parent
for _subdir in ("worker-runner", "tool-gateway", "worktree-manager"):
    _candidate = str(_TOOLS_ROOT / _subdir)
    if _candidate not in sys.path:
        sys.path.insert(0, _candidate)

import yaml  # noqa: E402

from audit_log import AuditLog  # noqa: E402
from handoff_validator import (  # noqa: E402
    ValidationReport,
    validate_handoff_against_dispatch,
)
from mcp_capability_map import CapabilityMap  # noqa: E402
from model_routing import resolve_model_class, ModelRoutingError  # noqa: E402
from policy import Gateway  # noqa: E402
from runner import WorkerRunner  # noqa: E402
from schemas import (  # noqa: E402
    Handoff,
    ModelClass,
    WorkerBudget,
    WorkerDispatch,
    WorkerKind,
    WorktreeKind,
    WorktreeState,
)
from trace_store import TraceStore  # noqa: E402

logger = logging.getLogger(__name__)

# Default budget when operator doesn't supply.
# Cost cap effectively unbounded for dev (Max-plan subscription enforces
# the 5-hour usage window separately; we don't want the cost cap to
# pre-empt dispatch runs). PS-side default in mission-dispatch.ps1 must
# match this number so PS-omits-arg dispatches and Python-omits-arg
# dispatches share the same behavior. Operator can still pass an
# explicit lower value to constrain a specific dispatch.
_DEFAULT_COST_CAP_USD = 100000.0
_DEFAULT_WALLCLOCK_MINUTES = 90


@dataclass(frozen=True)
class DispatchInputs:
    """Operator-supplied dispatch construction inputs (the hybrid γ split)."""

    feature_id: str
    milestone_id: str
    kind: WorktreeKind
    model_class: ModelClass
    tool_scope: list[str]
    assertion_targets: Optional[list[str]] = None
    cost_cap_usd: float = _DEFAULT_COST_CAP_USD
    wallclock_cap_minutes: int = _DEFAULT_WALLCLOCK_MINUTES
    dry_run: bool = False
    project_root: Optional[Path] = None
    # ADR-007 decision 5: optional bounded addendum threaded from
    # mission-dispatch.ps1 -OperatorNote into the constructed task brief.
    # Additive to, never replacing, the artifact-derived objective.
    operator_note: Optional[str] = None


@dataclass(frozen=True)
class DispatchResult:
    """Structured outcome the PS caller reads as JSON on stdout."""

    exit_code: int
    dispatch_id: str
    worktree_id: Optional[str]
    validation_report: Optional[dict]
    error: Optional[str]


# ---------- spec + contract lookup ----------


def _read_spec_version(project_root: Path) -> int:
    current_txt = project_root / ".mission" / "spec" / "current.txt"
    if not current_txt.is_file():
        raise RuntimeError(
            f"spec current.txt not found at {current_txt}; mission not in Executing?"
        )
    raw = current_txt.read_text(encoding="utf-8").strip()
    # current.txt has values like 'v010'; strip the v.
    if raw.startswith("v") or raw.startswith("V"):
        raw = raw[1:]
    return int(raw)


def _read_mission_id(project_root: Path) -> str:
    mission_yaml = project_root / ".mission" / "mission.yaml"
    if not mission_yaml.is_file():
        raise RuntimeError(f"mission.yaml not found at {mission_yaml}")
    doc = yaml.safe_load(mission_yaml.read_text(encoding="utf-8"))
    mid = doc.get("id")
    if not isinstance(mid, str):
        raise RuntimeError(
            f"mission.yaml missing or non-string `id` field: {mid!r}"
        )
    return mid


def _derive_assertion_targets(
    project_root: Path, feature_id: str, milestone_id: str
) -> list[str]:
    """The auto-derive rule: every assertion where feature_id matches AND milestone_id matches.
    Returns empty list if no match (caller should reject before Pydantic)."""
    assertions_dir = project_root / ".mission" / "contract" / "assertions"
    if not assertions_dir.is_dir():
        raise RuntimeError(
            f"contract assertions dir not found at {assertions_dir}"
        )
    targets: list[str] = []
    for path in sorted(assertions_dir.glob("A-*.yaml")):
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError:
            continue
        if not isinstance(doc, dict):
            continue
        if (
            doc.get("feature_id") == feature_id
            and doc.get("milestone_id") == milestone_id
        ):
            aid = doc.get("id")
            if isinstance(aid, str):
                targets.append(aid)
    return sorted(targets)


# ---------- dispatch construction ----------


_C2_PROHIBITED_TAGS: frozenset[str] = frozenset({
    "shell.exec.sandboxed",
    "shell.exec.unsandboxed",
})


def _validate_tool_scope_at_construction(tool_scope: list[str]) -> None:
    """ADR-027 D1+D2 (gate layer): pre-construction check that runs the same
    vocabulary membership as the WorkerDispatch field_validator BUT carries
    a human-facing C2-reason text for the shell.exec.* subset.

    Fail-closed: this is the SOLE defense (ADR-027 D2: 'sole defense, not a
    backstop') — the gateway still ALLOWs shell.exec.*-authorized Bash calls;
    no second wall until C2 lands. Therefore any input shape malformity
    (non-list, non-string elements) is also rejected here, not just delegated
    to the Pydantic floor.

    Layered design rationale (per impl-design Part B):
      - This gate fires FIRST so the C2-specific human-readable reason wins
        over the generic Pydantic message.
      - WorkerDispatch's field_validator is the floor that catches direct
        constructor calls that bypass build_dispatch.
    """
    if not isinstance(tool_scope, list):
        raise RuntimeError(
            f"tool_scope must be a list of capability tags; got "
            f"{type(tool_scope).__name__}. ADR-027 D2 fail-closed: malformed "
            f"tool_scope is rejected at construction, never waved through."
        )
    for entry in tool_scope:
        if not isinstance(entry, str):
            raise RuntimeError(
                f"tool_scope contains non-string element {entry!r} "
                f"(type {type(entry).__name__}). ADR-027 D2 fail-closed."
            )
    # ADR-027 D2 / ADR-026 D3 — shell.exec.* prohibition with C2 reason.
    egress_offenders = sorted(set(tool_scope) & _C2_PROHIBITED_TAGS)
    if egress_offenders:
        raise RuntimeError(
            f"tool_scope contains C2-prohibited tag(s): {egress_offenders!r}. "
            f"These are not grantable until the C2 sandbox/egress containment "
            f"layer is built (per ADR-026 Decision 3 + ADR-027 Decision 2). "
            f"The gateway still ALLOWs shell.exec.*-authorized Bash calls "
            f"(is_command_in_allowlist returns ALLOW immediately for "
            f"authorized_capability != 'test.run'); this construction-time "
            f"check is the SOLE defense, not a backstop. Workers needing "
            f"shell-level operations: use shell.read (read-only program "
            f"allowlist), test.run (test allowlist), or worktree.commit "
            f"(git-subcommand allowlist) per ADR-026 D1/D2 instead."
        )


def build_dispatch(
    inputs: DispatchInputs, project_root: Path
) -> WorkerDispatch:
    """Hybrid construction per the operator's answer: operator supplies variable parts;
    this module fills the rest from spec + contract."""
    # ADR-027 D1+D2 — construction-time validation gate. Runs BEFORE the
    # Pydantic constructor so the C2-specific reason wins over the generic
    # field_validator message. The field_validator on WorkerDispatch is the
    # floor that catches direct constructor calls bypassing this gate.
    _validate_tool_scope_at_construction(inputs.tool_scope)

    mission_id = _read_mission_id(project_root)
    spec_version = _read_spec_version(project_root)

    targets = inputs.assertion_targets
    if targets is None:
        targets = _derive_assertion_targets(
            project_root, inputs.feature_id, inputs.milestone_id
        )
        if not targets:
            raise RuntimeError(
                f"no assertions match feature {inputs.feature_id!r} "
                f"in milestone {inputs.milestone_id!r}; "
                f"check feature_id + milestone_id args or contract"
            )

    return WorkerDispatch(
        id=uuid4(),
        created_at=_iso_now(),
        created_by="claude-code:operator",
        mission_id=mission_id,
        worker_id=str(uuid4()),  # per an operator answer: UUIDs by convention
        kind=WorkerKind.FANOUT,  # WorkerKind from §4; orthogonal to WorktreeKind
        feature_id=inputs.feature_id,
        assertion_targets=targets,
        spec_version=spec_version,
        worktree_id="pending",  # rewritten after worktree creation
        model_class=inputs.model_class,
        tool_scope=inputs.tool_scope,
        budget=WorkerBudget(
            cost_cap_usd=inputs.cost_cap_usd,
            wallclock_cap_minutes=inputs.wallclock_cap_minutes,
        ),
    )


def _iso_now() -> str:
    from datetime import datetime, timezone

    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


# ---------- orchestration ----------


def run_dispatch(
    inputs: DispatchInputs,
    project_root: Path,
) -> DispatchResult:
    """The main orchestration entry. Returns a DispatchResult; the PS caller
    reads it as JSON on stdout."""
    try:
        dispatch = build_dispatch(inputs, project_root)
    except (RuntimeError, ValueError) as e:
        return DispatchResult(
            exit_code=3,  # operator-error
            dispatch_id="<not-constructed>",
            worktree_id=None,
            validation_report=None,
            error=f"dispatch construction failed: {e}",
        )

    if inputs.dry_run:
        # Print the constructed dispatch for inspection; don't spawn.
        # YAML goes to stdout (it IS the dry-run's output).
        print(
            yaml.safe_dump(
                json.loads(dispatch.model_dump_json()),
                default_flow_style=False,
                sort_keys=False,
            )
        )
        return DispatchResult(
            exit_code=0,
            dispatch_id=str(dispatch.id),
            worktree_id=None,
            validation_report=None,
            error=None,
        )

    # THE AUTHENTICATION MODE, decided before the worktree is
    # cut or anything is written; the runner decides it again before its spawn.
    from env_scrub import AuthModeRefused, resolve_auth_mode  # noqa: E402

    try:
        resolve_auth_mode()
    except AuthModeRefused as e:
        return DispatchResult(
            exit_code=3,  # operator-error
            dispatch_id=str(dispatch.id),
            worktree_id=None,
            validation_report=None,
            error=f"refused before the worktree: {e}",
        )

    # WorktreeManager + worktree creation. Lazy-imported to avoid loading
    # subprocess-heavy code on dry-run paths.
    sys.path.insert(
        0, str(Path(__file__).parent.parent / "worktree-manager")
    )
    from manager import WorktreeManager  # noqa: E402
    from port_allocator import allocate_ports  # noqa: E402

    runtime_dir = project_root / ".mission-runtime"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    mgr = WorktreeManager(project_root)

    # Determine base_commit from HEAD of project_root.
    import subprocess

    base_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=str(project_root),
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    try:
        wt_record = mgr.create(
            dispatch=dispatch,
            kind=inputs.kind,
            base_commit=base_commit,
        )
    except (ValueError, RuntimeError) as e:
        return DispatchResult(
            exit_code=2,
            dispatch_id=str(dispatch.id),
            worktree_id=None,
            validation_report=None,
            error=f"worktree creation failed: {e}",
        )

    # COMPLETION-DRIVER: from this point on, the worktree record exists
    # in state ACTIVE. EVERY return path below must transition it to
    # DISCARDED before returning so the §10 state machine reaches a
    # terminal state and the slot becomes Path-Y-reusable on the next
    # dispatch. Without this, every successful-or-failed dispatch leaves
    # the worktree stuck ACTIVE, blocking the next mainline dispatch.
    # Promotion/merge to MERGED is a SEPARATE, operator-authorized step
    # (mission-promote-handoff.ps1, deferred); the worktree state
    # machine tracks the runtime worktree, not branch integration.
    # ACTIVE -> DISCARDED is the legal §10 transition.
    try:
        # Rewrite the dispatch's worktree_id field now that we know it. Note
        # that this requires bypassing frozen=True via model_copy.
        dispatch = dispatch.model_copy(update={"worktree_id": wt_record.id})

        # Resolve model class to concrete model name.
        try:
            model_name = resolve_model_class(inputs.model_class)
        except ModelRoutingError as e:
            return DispatchResult(
                exit_code=3,
                dispatch_id=str(dispatch.id),
                worktree_id=wt_record.id,
                validation_report=None,
                error=f"model routing failed: {e}",
            )
        logger.info(
            "dispatch %s resolved model_class=%s → %s",
            dispatch.id,
            inputs.model_class.value,
            model_name,
        )

        # Trace store + framework wiring.
        trace_db = runtime_dir / "traces.sqlite"
        with TraceStore(trace_db) as store:
            gateway = Gateway(CapabilityMap.default())
            audit = AuditLog(store)
            runner = WorkerRunner(
                dispatch,
                store=store,
                gateway=gateway,
                audit=audit,
                worktree_path=Path(wt_record.path),
                worktree_base_commit=base_commit,
                project_root=project_root,
                operator_note=inputs.operator_note,
            )

            try:
                import asyncio

                handoff: Handoff = asyncio.run(runner.run())
            except Exception as e:  # broad: any runtime failure
                return DispatchResult(
                    exit_code=2,
                    dispatch_id=str(dispatch.id),
                    worktree_id=wt_record.id,
                    validation_report=None,
                    error=f"runner failure: {e!r}",
                )

            # PERSISTENCE: if the worker didn't write its own handoff.json,
            # the Handoff above was synthesized in-memory by the runner --
            # carrying the failure's subprocess_exit_code + subprocess_stderr
            # in issues_observed. Without disk persistence the diagnostic
            # signal is GC'd with the runner instance and post-mortem becomes
            # impossible (the trail we lost on an earlier dispatch). Mirror of
            # FIX B's "no signal silently dropped" principle: write the
            # synthesized handoff to a distinct path before validation. The
            # filename differs from `handoff.json` so worker-written vs
            # framework-synthesized handoffs remain distinguishable on disk.
            worker_handoff_path = (
                project_root
                / ".mission-runtime"
                / "dispatches"
                / str(dispatch.id)
                / "handoff.json"
            )
            if not worker_handoff_path.is_file():
                synthesized_path = (
                    worker_handoff_path.parent / "synthesized-handoff.json"
                )
                synthesized_path.parent.mkdir(parents=True, exist_ok=True)
                synthesized_path.write_text(
                    handoff.model_dump_json(indent=2), encoding="utf-8"
                )

            # Cross-artifact handoff validation (step 6).
            report = validate_handoff_against_dispatch(
                handoff, dispatch, store=store
            )

        exit_code = 0 if report.is_valid else 1
        return DispatchResult(
            exit_code=exit_code,
            dispatch_id=str(dispatch.id),
            worktree_id=wt_record.id,
            validation_report={
                "is_valid": report.is_valid,
                "cross_artifact_errors": list(report.cross_artifact_errors),
                "denial_count": report.denial_count,
                "denied_capabilities": list(report.denied_capabilities),
                "denied_tools": list(report.denied_tools),
            },
            error=None,
        )
    finally:
        # COMPLETION-DRIVER (continued): fire on EVERY return path above,
        # including normal-completion and the inner early-returns
        # (model_routing failure, runner failure). Idempotent: if the
        # state was already advanced by reconcile() or a future test
        # path, transition_state raises ValueError -- swallow.
        # FileNotFoundError swallowed for the rare case where the record
        # was unlinked under us (e.g., concurrent cleanup).
        try:
            mgr.transition_state(wt_record.id, WorktreeState.DISCARDED)
        except (ValueError, FileNotFoundError):
            pass


# ---------- CLI entry ----------


def main(argv: Optional[list[str]] = None) -> int:
    """CLI entry: reads a JSON args file from argv[1], runs dispatch, prints
    DispatchResult as JSON to stdout, exits with the result's exit_code.

    mission-dispatch.ps1 invokes this via:
        python tools/worker-runner/dispatch_entry.py <args-json-path>
    """
    args = argv if argv is not None else sys.argv[1:]
    if not args:
        print(
            json.dumps(
                {
                    "exit_code": 3,
                    "error": "missing args-json path",
                }
            )
        )
        return 3

    args_path = Path(args[0])
    if not args_path.is_file():
        print(json.dumps({"exit_code": 3, "error": f"args file not found: {args_path}"}))
        return 3

    try:
        args_doc = json.loads(args_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(
            json.dumps(
                {"exit_code": 3, "error": f"args JSON decode failed: {e}"}
            )
        )
        return 3

    try:
        # operator_note: tolerate null / missing / whitespace-only; treat as None.
        raw_operator_note = args_doc.get("operator_note")
        if isinstance(raw_operator_note, str) and raw_operator_note.strip():
            operator_note: Optional[str] = raw_operator_note
        else:
            operator_note = None

        inputs = DispatchInputs(
            feature_id=args_doc["feature_id"],
            milestone_id=args_doc["milestone_id"],
            kind=WorktreeKind(args_doc.get("kind", "fanout")),
            model_class=ModelClass(args_doc.get("model_class", "coding-strong")),
            tool_scope=list(args_doc.get("tool_scope", ["repo.read"])),
            assertion_targets=args_doc.get("assertion_targets"),
            cost_cap_usd=float(args_doc.get("cost_cap_usd", _DEFAULT_COST_CAP_USD)),
            wallclock_cap_minutes=int(
                args_doc.get("wallclock_cap_minutes", _DEFAULT_WALLCLOCK_MINUTES)
            ),
            dry_run=bool(args_doc.get("dry_run", False)),
            operator_note=operator_note,
        )
    except (KeyError, ValueError) as e:
        print(json.dumps({"exit_code": 3, "error": f"args parse failed: {e}"}))
        return 3

    project_root_str = args_doc.get("project_root")
    project_root = (
        Path(project_root_str) if project_root_str else Path.cwd()
    ).resolve()

    result = run_dispatch(inputs, project_root)
    if not inputs.dry_run:
        # Non-dry-run prints the structured DispatchResult JSON to stdout;
        # the PS caller reads + surfaces. Dry-run already printed its YAML
        # on stdout in run_dispatch.
        print(
            json.dumps(
                {
                    "exit_code": result.exit_code,
                    "dispatch_id": result.dispatch_id,
                    "worktree_id": result.worktree_id,
                    "validation_report": result.validation_report,
                    "error": result.error,
                },
                indent=2,
            )
        )
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
