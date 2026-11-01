"""Test-WitnessedSubstrate guards: shell the REAL mission-lib against ISOLATED fixture roots (nothing
touches the real .mission).

The checker validates against the substrate's DECLARED terminal activity (data-driven: the declaration
travels with the evidence as declared-terminal-activity.txt) and has NO built-in default. (1) the
event-line dump shape with its declaration is accepted; (2) the JSON dump shape with its declaration is
accepted; (3) the narration-masquerade is REFUSED (planted non-vacuity); (4) a shape-valid dump with NO
declaration is REFUSED -- there is no default to fall back on; (5) a malformed declaration fails closed.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]           # repo/tools
_DRV = Path(__file__).resolve().parent / "_drv_witnessed_substrate.ps1"

_JSON_ACTIVITY = "store_step_result"     # an invented activity name for the JSON dump shape


def _powershell():
    for cand in ("pwsh", "powershell", "powershell.exe"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (pwsh/powershell) on PATH -- cannot shell mission-lib")


def _substrate(tmp_path: Path, dump: str, declaration: str | None) -> tuple[Path, str]:
    """Build an isolated fixture root with one substrate dir; returns (root, name)."""
    tools = tmp_path / "tools"
    tools.mkdir(parents=True, exist_ok=True)
    shutil.copy2(_TOOLS / "mission-lib.ps1", tools / "mission-lib.ps1")
    name = "fixture-substrate"
    d = tmp_path / ".mission" / "evidence" / name
    d.mkdir(parents=True, exist_ok=True)
    (d / "02-compose-ps.txt").write_text("project-agent     Up 2 days (healthy)\n", encoding="ascii")
    (d / "03-pytest.txt").write_text("4 passed in 5.36s\n", encoding="ascii")
    (d / "04-event-history-dump.txt").write_text(dump, encoding="ascii")
    if declaration is not None:
        (d / "declared-terminal-activity.txt").write_text(declaration + "\n", encoding="ascii")
    return tmp_path, name


def _run(tmp_path: Path, name: str):
    ps = _powershell()
    lib = tmp_path / "tools" / "mission-lib.ps1"
    return subprocess.run(
        [ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(_DRV),
         "-Lib", str(lib), "-Root", str(tmp_path), "-Name", name],
        capture_output=True, text=True, timeout=180)


def test_witnessed_1_event_line_shape_accepted_with_declaration(tmp_path):
    """(1) The event-line dump shape + a travelling declaration -> ACCEPT."""
    dump = ("===== sample-x (type=ExampleWorkflow, status=COMPLETED, HistoryLength=22) =====\n"
            "  event 10: WORKFLOW_EXECUTION_SIGNALED signal=finalize\n"
            "  event 16: ACTIVITY_TASK_SCHEDULED activity=record_step_completed\n"
            "  event 22: WORKFLOW_EXECUTION_COMPLETED\n")
    root, name = _substrate(tmp_path, dump, "record_step_completed")
    p = _run(root, name)
    assert p.returncode == 0, f"the event-line shape must be ACCEPTED with its declaration; got {p.returncode}: {p.stdout} {p.stderr}"
    assert "record_step_completed" in p.stdout, "the PASS line must name the declared activity"


def test_witnessed_2_json_shape_accepted_with_declaration(tmp_path):
    """(2) The JSON dump shape (an activityType name field) + its declaration -> ACCEPT."""
    dump = ('{ "events": [ { "eventType": "ActivityTaskScheduled",\n'
            '    "activityTaskScheduledEventAttributes": { "activityType": {\n'
            f'          "name": "{_JSON_ACTIVITY}"\n'
            "    } } } ] }\nWorkflowExecutionCompleted recorded; HistoryLength=40\n")
    root, name = _substrate(tmp_path, dump, _JSON_ACTIVITY)
    p = _run(root, name)
    assert p.returncode == 0, f"the JSON shape must be ACCEPTED with its declaration; got {p.returncode}: {p.stdout} {p.stderr}"
    assert _JSON_ACTIVITY in p.stdout, "the PASS line must name the declared activity"


def test_witnessed_3_masquerade_refused_planted(tmp_path):
    """(3) PLANTED non-vacuity: the declared name + history words in PROSE ONLY (no real event
    structure) -> REFUSED."""
    dump = ("This prose CLAIMS the run executed record_step_completed and that WorkflowExecution\n"
            "completed with ActivityTask events and HistoryLength=22 -- with NO real event structure.\n")
    root, name = _substrate(tmp_path, dump, "record_step_completed")
    p = _run(root, name)
    assert p.returncode != 0, f"the narration-masquerade must be REFUSED (teeth); got {p.returncode}: {p.stdout}"
    combined = p.stdout + p.stderr
    assert "REAL event structure" in combined, f"refusal must cite the structural requirement: {combined}"


def test_witnessed_4_undeclared_refused_no_default(tmp_path):
    """(4) NO DEFAULT: the same shape-valid JSON dump as (2), with NO declaration -> REFUSED. Only the
    missing declaration separates it from the accepted case, so this refusal is the declaration's teeth."""
    dump = ('{ "events": [ { "eventType": "ActivityTaskScheduled",\n'
            '    "activityTaskScheduledEventAttributes": { "activityType": {\n'
            f'          "name": "{_JSON_ACTIVITY}"\n'
            "    } } } ] }\nWorkflowExecutionCompleted recorded; HistoryLength=40\n")
    root, name = _substrate(tmp_path, dump, None)
    p = _run(root, name)
    assert p.returncode != 0, f"an undeclared substrate must be REFUSED (no default); got {p.returncode}: {p.stdout}"
    assert "has NO default" in (p.stdout + p.stderr), "the refusal must say the terminal activity has no default"


def test_witnessed_5_malformed_declaration_fail_closed(tmp_path):
    """A malformed declaration (regex metacharacters / spaces) must fail CLOSED, not be interpolated
    into the match."""
    dump = "  event 16: ACTIVITY_TASK_SCHEDULED activity=record_step_completed\nWorkflowExecution\n"
    root, name = _substrate(tmp_path, dump, "bad name .* injection")
    p = _run(root, name)
    assert p.returncode != 0, f"malformed declaration must REFUSE fail-closed; got {p.returncode}: {p.stdout}"
    assert "malformed" in (p.stdout + p.stderr), "refusal must say the declaration is malformed"
