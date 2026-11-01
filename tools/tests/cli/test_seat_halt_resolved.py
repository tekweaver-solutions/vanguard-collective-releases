"""A tooling seat's HALT, answered by its own RESOLVED record (tools/lam/mission-goal-check.ps1,
Get-HaltSeatResolution; docs/framework/LAM-INSTALL.md section 5.6.2).

A tooling or recording seat raises its HALT in its own runtime plane, .mission-runtime/seats/<seat>/HALT-<id>.md,
and the operator answers it with a RESOLVED record written into the HALT file: a `**Status:** RESOLVED` line and
one `## RESOLVED` block carrying the HALT id, the ruling, who ruled, when, and the resumption point. No gate is
minted. The evaluator reads such a HALT closed ONLY directly inside a seat folder of .mission-runtime/seats; the
same record anywhere else answers nothing, and a mission HALT still needs its halt-ruling gate.

HERMETIC. The fixture tests/lam/fixtures/seat-halt is materialised into a SCRATCH mission root under tmp_path --
its runtime/ folder becomes .mission-runtime/, its goal .mission/goals/SEAT-HALT.yaml -- beside COPIES of the
evaluator and the three libraries it dot-sources (the house pattern: never the checked-out file in place). The
real .mission and .mission-runtime are never read or written.

THE CASES. The record honoured (MET, exit 0, named in the verdict artifact); then the controls, each a HALT
verdict (exit 3) whose open entry says why the record was not honoured: the same file in a mission plane, in a
seat's subfolder, a field missing, a field written twice, a field outside the block, an empty field, the HALT id
of another file, a time that is not a date, the record only inside a fenced example; an OPEN status, which is
not a RESOLVED claim at all; and no seat HALT, whose artifact carries no seat-record key.
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

_REPO = Path(__file__).resolve().parents[3]                        # the repository root
_LAM = _REPO / "tools" / "lam"
_FIXTURE = _REPO / "tests" / "lam" / "fixtures" / "seat-halt"
_EVALUATOR_FILES = ("mission-goal-check.ps1", "lam-verify-admission.ps1", "lam-gate-class.ps1", "lam-instrument-run.ps1")
_HALT_REL = Path(".mission-runtime") / "seats" / "example-seat" / "HALT-EX-01.md"


def _powershell():
    for cand in ("pwsh", "powershell", "powershell.exe"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (pwsh/powershell) on PATH -- cannot run the evaluator")


class SeatRoot:
    """A scratch mission root holding the materialised fixture and a copy of the evaluator."""

    def __init__(self, tmp_path):
        self.root = tmp_path / "mission"
        tools_lam = self.root / "tools" / "lam"
        tools_lam.mkdir(parents=True)
        for name in _EVALUATOR_FILES:
            shutil.copy2(_LAM / name, tools_lam / name)
        shutil.copytree(_FIXTURE / "runtime", self.root / ".mission-runtime")
        goals = self.root / ".mission" / "goals"
        goals.mkdir(parents=True)
        shutil.copy2(_FIXTURE / "goals" / "SEAT-HALT.yaml", goals / "SEAT-HALT.yaml")
        self.halt = self.root / _HALT_REL
        self.verdict_path = goals / "SEAT-HALT.verdict.yaml"
        self.ps = _powershell()

    def halt_text(self):
        return self.halt.read_bytes().decode("utf-8")

    def write_halt(self, text, rel=_HALT_REL):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode("utf-8"))
        if path != self.halt:
            self.halt.unlink()
        return path

    def evaluate(self):
        proc = subprocess.run(
            [self.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.root / "tools" / "lam" / "mission-goal-check.ps1"),
             "-Goal", "SEAT-HALT", "-MissionRoot", str(self.root)],
            capture_output=True, timeout=300)
        out = proc.stdout.decode("utf-8", errors="replace")
        # The artifact is written line by line with the platform's line end; read here as LF lines.
        verdict = self.verdict_path.read_bytes().decode("utf-8").replace("\r\n", "\n") if self.verdict_path.exists() else ""
        return proc.returncode, out, verdict


@pytest.fixture
def seat(tmp_path):
    return SeatRoot(tmp_path)


def _open_halts(verdict):
    m = re.search(r"(?m)^open_halts:(.*)\n((?:  - .*\n)*)", verdict)
    if not m:
        return None
    if m.group(1).strip() == "[]":
        return []
    # A bare file name stays bare; any other entry is single-quoted with its quotes doubled (the writer's rule).
    entries = [line[4:] for line in m.group(2).splitlines()]
    return [e[1:-1].replace("''", "'") if len(e) > 1 and e.startswith("'") and e.endswith("'") else e for e in entries]


def test_the_fixture_is_the_documented_form(seat):
    """The fixture's HALT carries the record's five fields once each at column 0, after one `## RESOLVED`."""
    text = seat.halt_text()
    assert "\r" not in text
    assert len(re.findall(r"(?m)^## RESOLVED[ \t]*$", text)) == 1
    for label in ("HALT", "Ruling", "Ruled by", "Ruled at", "Resume at"):
        assert len(re.findall(r"(?m)^\*\*" + re.escape(label) + r":\*\*", text)) == 1, label
    assert re.search(r"(?m)^\*\*Status:\*\* RESOLVED\b", text)


def test_resolved_seat_halt_reads_closed(seat):
    """ACCEPTANCE: the RESOLVED record directly inside a seat folder answers the HALT -- MET, exit 0, named."""
    code, out, verdict = seat.evaluate()
    assert code == 0, out
    assert out.splitlines()[0] == "mission-goal-check: SEAT-HALT -> MET"
    assert "1 seat-plane HALT(s) RESOLVED by their own RESOLVED record" in out
    assert _open_halts(verdict) == []
    assert re.search(r"(?m)^halts_resolved_by_seat_record:\n  - 'HALT-EX-01\.md -- RESOLVED by its own RESOLVED record in a tooling seat''s plane", verdict), verdict
    assert re.search(r"(?m)^halts_answered_by_ruling_gate: \[\]$", verdict)


def _not_honoured(seat, why_fragment):
    code, out, verdict = seat.evaluate()
    assert code == 3, out
    assert out.splitlines()[0] == "mission-goal-check: SEAT-HALT -> HALT"
    entries = _open_halts(verdict)
    assert entries is not None and len(entries) == 1, verdict
    assert entries[0].startswith("HALT-EX-01.md [seat RESOLVED record NOT honoured - "), entries
    assert why_fragment in entries[0], entries
    assert "halts_resolved_by_seat_record" not in verdict


def test_same_record_in_a_mission_plane_is_open(seat):
    """CONTROL: the identical file in .mission-runtime/halts -- a mission plane -- answers nothing."""
    seat.write_halt(seat.halt_text(), Path(".mission-runtime") / "halts" / "HALT-EX-01.md")
    _not_honoured(seat, "not directly inside a seat folder under .mission-runtime\\seats")


def test_same_record_in_a_seat_subfolder_is_open(seat):
    """CONTROL: one folder deeper than a seat folder is not the seat plane's place."""
    seat.write_halt(seat.halt_text(), Path(".mission-runtime") / "seats" / "example-seat" / "archive" / "HALT-EX-01.md")
    _not_honoured(seat, "not directly inside a seat folder")


@pytest.mark.parametrize("name, edit, why", [
    ("a field missing", lambda t: re.sub(r"(?m)^\*\*Ruled by:\*\*.*\n", "", t), "the field **Ruled by:** is written 0 time(s)"),
    ("a field written twice", lambda t: t + "**Ruling:** a second ruling\n", "the field **Ruling:** is written 2 time(s)"),
    ("a field outside the block", lambda t: t.replace("**Resume at:** the step the brief names next, taken the second way\n", "").replace(
        "## What was expected\n", "**Resume at:** above the block\n\n## What was expected\n"), "the field **Resume at:** stands outside the RESOLVED block"),
    ("an empty field", lambda t: re.sub(r"(?m)^\*\*Ruled by:\*\*.*$", "**Ruled by:**", t), "the field **Ruled by:** is empty"),
    ("another file's HALT id", lambda t: t.replace("**HALT:** HALT-EX-01", "**HALT:** HALT-EX-02"), "names HALT-EX-02, not this file's HALT-EX-01"),
    ("a time that is not a date", lambda t: t.replace("**Ruled at:** 2026-10-25T18:00:00Z", "**Ruled at:** yesterday"), "does not begin with a date"),
    ("the record only inside a fenced example", lambda t: t.replace("## RESOLVED\n", "```text\n## RESOLVED\n") + "```\n", "0 column-0 '## RESOLVED' heading(s)"),
])
def test_a_record_that_does_not_hold_is_open(seat, name, edit, why):
    """CONTROL: each way a RESOLVED record can fail leaves the HALT OPEN, and the open entry says why."""
    before = seat.halt_text()
    after = edit(before)
    assert after != before, name
    seat.write_halt(after)
    _not_honoured(seat, why)


def test_an_open_status_is_no_resolved_claim(seat):
    """CONTROL: `**Status:** OPEN` with the whole block below it is an OPEN HALT, reported bare."""
    seat.write_halt(seat.halt_text().replace("**Status:** RESOLVED", "**Status:** OPEN"))
    code, out, verdict = seat.evaluate()
    assert code == 3, out
    assert _open_halts(verdict) == ["HALT-EX-01.md"]
    assert "halts_resolved_by_seat_record" not in verdict


def test_no_seat_halt_writes_no_seat_record_key(seat):
    """CONTROL: with no seat HALT the goal is MET and the artifact carries no seat-record key at all."""
    seat.halt.unlink()
    code, out, verdict = seat.evaluate()
    assert code == 0, out
    assert _open_halts(verdict) == []
    assert "halts_resolved_by_seat_record" not in verdict
