"""Guards for tools/lam/transcribe-validator-results.ps1, the transcription BRIDGE
between the LAM validators' bound result files and .mission/validator-results/, the store
tools/mission-close-milestone.ps1's A-127/A-128 gate reads.

The defect these guards close is two-headed. (1) The bridge was a ONE-ARC SCRIPT IN THE RUNTIME PLANE,
re-authored per arc: two copies of one helper script, each written for its own arc, had
already diverged in five places -- the hardcoded
PLAN, the session id, the attest string, the commit message, and a first act that ABORTS if the manifest
already carries the arc's first assertion. (2) That last one broke CHECK-ONLY MODE: driven with no flag
over the arc it had itself transcribed, such a helper exits 1 with "STOP: the manifest already carries
A-NNN" and verifies nothing. test_control_check_only_over_already_transcribed_arc is that case, asked of
the tool that replaces them.

Every fixture here is synthetic and lives in pytest's tmp_path, following conftest.py's pattern: the
.ps1 and its .py are COPIED into <tmp>/tools/lam/ and driven against an isolated mission root in the
same tmp dir. Nothing here reads or writes the real .mission or .mission-runtime.
"""

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]              # repo/tools
_PS1 = _TOOLS / "lam" / "transcribe-validator-results.ps1"
_PY = _TOOLS / "lam" / "transcribe_validator_results.py"


def _powershell():
    for cand in ("pwsh", "powershell", "powershell.exe"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (pwsh/powershell) on PATH -- cannot shell the .ps1 CLI")


def _sha(b):
    return hashlib.sha256(b).hexdigest()


RESULT_BODY = """\
id: VR-{aid}
verdict: PASS
what_the_verdict_covers: the synthetic fixture assertion {aid}
checks:
  - check: the fixture check
    verdict: PASS
    evidence: 'the validator wrote this line and nobody else did'
findings: []
"""


class Fixture:
    """An isolated mission root: tools/lam copies, a spawn ledger, a manifest, and result files."""

    def __init__(self, tmp):
        self.root = tmp
        lam = tmp / "tools" / "lam"
        lam.mkdir(parents=True, exist_ok=True)
        shutil.copy2(_PS1, lam / _PS1.name)
        shutil.copy2(_PY, lam / _PY.name)
        self.ps1 = lam / _PS1.name
        (tmp / "tests" / "lam").mkdir(parents=True, exist_ok=True)
        self.vr = tmp / ".mission" / "validator-results"
        self.vr.mkdir(parents=True, exist_ok=True)
        (tmp / ".mission-runtime" / "lam").mkdir(parents=True, exist_ok=True)
        self.ledger = tmp / ".mission-runtime" / "lam" / "spawn-ledger.jsonl"
        self.lines = []
        self.write_manifest([])

    # -- fixture construction -------------------------------------------------
    def write_manifest(self, entries):
        (self.vr / "manifest.json").write_text(
            json.dumps({"entries": entries}, indent=2), encoding="utf-8")

    def result(self, aid, body=None, extra=""):
        """Write a validator result file; return its real sha256."""
        text = (body if body is not None else RESULT_BODY.format(aid=aid)) + extra
        p = self.root / "tests" / "lam" / f"validator-{aid}.result.yaml"
        p.write_bytes(text.encode("utf-8"))
        return _sha(p.read_bytes())

    def spawn_pair(self, seq, aid, sha, rnd=1, dispatch=None, validates=None,
                   tip="a" * 40, verdict="PASS"):
        dispatch = dispatch or f"D-V-{aid}"
        validates = aid if validates is None else validates
        self.lines.append({"event": "spawn", "seq": seq, "kind": "validator", "role": "qa-validator",
                           "dispatch_id": dispatch, "validates": validates, "round": rnd,
                           "rounds_max": 4, "tip_judged": tip})
        self.lines.append({"event": "complete", "seq": seq, "kind": "validator", "dispatch_id": dispatch,
                           "validates": validates, "round": rnd, "tip_judged": tip,
                           "verdict": verdict, "result_sha256": sha,
                           "result_path": f"tests/lam/validator-{aid}.result.yaml"})
        self.flush()

    def flush(self):
        self.ledger.write_text(
            "".join(json.dumps(r) + "\n" for r in self.lines), encoding="utf-8")

    # -- driving --------------------------------------------------------------
    def run(self, *assertions, arc="ARC-FIXTURE", write=False, extra=()):
        argv = [_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.ps1),
                "-Arc", arc, "-Assertion", ",".join(assertions),
                "-Root", str(self.root), "-PythonExe", sys.executable]
        if write:
            argv.append("-Write")
        argv.extend(extra)
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=300)
        proc.merged = (proc.stdout or "") + (proc.stderr or "")
        return proc

    # -- observation ----------------------------------------------------------
    def snapshot(self):
        """Every file under the root, by relative path, by sha256 -- so 'writes nothing' is asked of
        the filesystem rather than of the tool's own claim."""
        out = {}
        for p in sorted(self.root.rglob("*")):
            if p.is_file():
                out[str(p.relative_to(self.root)).replace("\\", "/")] = _sha(p.read_bytes())
        return out


@pytest.fixture
def fx(tmp_path):
    return Fixture(tmp_path)


def _seed_two(fx):
    """Two honest assertions, bound correctly."""
    s1 = fx.result("A-901")
    s2 = fx.result("A-902")
    fx.spawn_pair(901, "A-901", s1)
    fx.spawn_pair(902, "A-902", s2)
    return s1, s2


# ---------------------------------------------------------------- ACCEPTANCE --
def test_acceptance_check_only_reports_the_equalities_and_writes_nothing(fx):
    s1, s2 = _seed_two(fx)
    before = fx.snapshot()
    proc = fx.run("A-901", "A-902")
    assert proc.returncode == 0, proc.merged
    assert "CHECK-ONLY" in proc.stdout
    assert s1 in proc.stdout and s2 in proc.stdout
    assert "ALL 2 EQUALITIES HELD." in proc.stdout
    assert "NOTHING WRITTEN" in proc.stdout
    assert fx.snapshot() == before          # the filesystem, not the tool's word for it


def test_acceptance_write_transcribes_the_roster_into_the_store(fx):
    s1, s2 = _seed_two(fx)
    proc = fx.run("A-901", "A-902", write=True)
    assert proc.returncode == 0, proc.merged
    manifest = json.loads((fx.vr / "manifest.json").read_text(encoding="utf-8"))
    assert [e["assertion_id"] for e in manifest["entries"]] == ["A-901", "A-902"]
    assert {e["verdict"] for e in manifest["entries"]} == {"pass"}
    assert [e["result_sha256"] for e in manifest["entries"]] == [s1, s2]
    rec = json.loads((fx.vr / "A-901.validator-result.json").read_text(encoding="utf-8"))
    assert rec["assertion_id"] == "A-901" and rec["verdict"] == "pass"
    assert rec["transcription"]["source_sha256"] == s1
    assert rec["transcription"]["spawn_seq"] == 901
    # the whole document key by key, not a fixed selection: one item per top-level key
    contents = "\n".join(e["content"] for e in rec["evidence"])
    assert "VERDICT LINE, VERBATIM: verdict: PASS" in contents
    assert "the validator wrote this line and nobody else did" in contents   # copied verbatim
    for key in ("id", "what_the_verdict_covers", "checks", "findings"):
        assert any(e["content"].startswith(key + ":") for e in rec["evidence"]), key
    # nothing is authored on a validator's behalf: no witnessed_substrate is ever written
    assert "witnessed_substrate" not in json.dumps(rec)


# ------------------------------------------------------------------- REFUSAL --
def test_refusal_source_sha_mismatch_prints_both_figures(fx):
    honest = fx.result("A-901")
    fx.spawn_pair(901, "A-901", honest)
    # the source moves after it was bound -- exactly what the equality exists to catch
    moved = fx.result("A-901", extra="\n# one byte the bound figure never saw\n")
    assert moved != honest
    before = fx.snapshot()
    proc = fx.run("A-901", write=True)
    assert proc.returncode != 0
    assert "THE SOURCE IS NOT THE BOUND FIGURE" in proc.merged
    assert honest in proc.merged, "the bound figure must be printed"
    assert moved in proc.merged, "the computed figure must be printed"
    assert fx.snapshot() == before


def test_refusal_spawn_line_validates_disagrees_with_the_requested_assertion(fx):
    sha = fx.result("A-901")
    fx.spawn_pair(901, "A-901", sha, validates="A-999")     # the ledger binds another assertion
    proc = fx.run("A-901:901", write=True)
    assert proc.returncode != 0
    assert "`validates`" in proc.merged
    assert "'A-999'" in proc.merged and "'A-901'" in proc.merged
    assert not (fx.vr / "A-901.validator-result.json").exists()


def test_refusal_result_file_identity_field_disagrees_with_the_spawn_ledger(fx):
    body = RESULT_BODY.format(aid="A-901") + "dispatch_id: D-V-A-999\nround: 1\n"
    sha = fx.result("A-901", body=body)
    fx.spawn_pair(901, "A-901", sha, dispatch="D-V-A-901")
    proc = fx.run("A-901", write=True)
    assert proc.returncode != 0
    assert "dispatch_id disagrees" in proc.merged
    assert "'D-V-A-901'" in proc.merged and "'D-V-A-999'" in proc.merged
    assert not (fx.vr / "A-901.validator-result.json").exists()


def test_refusal_write_mode_will_not_overwrite_an_entry_the_store_already_carries(fx):
    _seed_two(fx)
    assert fx.run("A-901", "A-902", write=True).returncode == 0
    before = fx.snapshot()
    again = fx.run("A-901", "A-902", write=True)
    assert again.returncode != 0
    assert "WRITE mode refuses to overwrite" in again.merged
    assert fx.snapshot() == before


# -------------------------------------------------------------------- CONTROL --
def test_control_check_only_over_already_transcribed_arc(fx):
    """THE CASE THE RUNTIME-PLANE CEREMONY GOT WRONG. Its first act aborted on a manifest that already
    carried the arc's first assertion, so its check-only mode could never re-verify its own equalities.
    Here presence is a FACT on the report, the equalities are re-asked, and the exit is 0."""
    s1, s2 = _seed_two(fx)
    assert fx.run("A-901", "A-902", write=True).returncode == 0
    before = fx.snapshot()
    proc = fx.run("A-901", "A-902")
    assert proc.returncode == 0, proc.merged
    assert "ALREADY IN THE STORE" in proc.stdout
    assert "a fact, not a refusal, in check-only mode" in proc.stdout
    assert "ALL 2 EQUALITIES HELD." in proc.stdout
    assert s1 in proc.stdout and s2 in proc.stdout
    assert "EQUAL to the source read now" in proc.stdout
    assert "NOTHING WRITTEN" in proc.stdout
    assert fx.snapshot() == before


def test_seq_resolution_takes_the_highest_round_and_refuses_a_tie(fx):
    """No PLAN is baked in: the current attempt is RESOLVED from the ledger. A tie at the top round is
    a STOP that lists the candidates, never a first-of-a-class pick."""
    sha = fx.result("A-901")
    fx.spawn_pair(901, "A-901", "0" * 64, rnd=1, dispatch="D-V-A-901", verdict="FAIL")
    fx.spawn_pair(903, "A-901", sha, rnd=2, dispatch="D-V-A-901-R2")
    proc = fx.run("A-901")
    assert proc.returncode == 0, proc.merged
    assert "seq 903" in proc.stdout and "attempt 2" in proc.stdout

    fx.spawn_pair(904, "A-901", sha, rnd=2, dispatch="D-V-A-901-R2b")
    tie = fx.run("A-901")
    assert tie.returncode != 0
    assert "more than one complete line" in tie.merged
    assert "[903, 904]" in tie.merged


# ---------------------------------- THE FIVE NULL-RESULT FORMS --
# Five synthetic 'complete' lines whose result_sha256 is JSON null, numbered 1 to 5. Each is in the shape
# the runner and its seat write such a line: the key set and order, the round and the null fields of a
# real closure of its class, every id, time and digest in it synthetic. A long prose value is cut to its
# opening words and ends " [cut]", as a cut value would be.
# 1 and 2 are a WORKER's closure -- no `validates`, and no spawn line here to borrow one from -- so
# the bare-id path never takes them as candidates. 3, 4 and 5 are a VALIDATOR's: each binds no
# result and claims no round (the complete line's reading). The tool was
# already right on all five; these tests hold it there, and the last of them shows they can fail, on
# the tool as it stood before that reading.
NULL_FORMS = {
    1: {"event": "complete", "seq": 501, "ts": "2026-01-05T10:00:01.000Z", "kind": "worker",
        "role": "coding-strong", "dispatch_id": "D-W-1-R1", "rung": "L3", "charter": "AM-901",
        "result_path": None, "result_bytes": None, "result_sha256": None, "anchors_sha256": None,
        "null_reason": "REFUSED BEFORE SPAWN: the runner's ADR-022 verify gate refused (exit 2) [cut]",
        "rework_of": "D-W-1",
        "outcome": "REFUSED BEFORE SPAWN BY THE RUNNER'S ADR-022 VERIFY GATE -- runner exit 2 [cut]",
        "runner_exit": 2, "worker_exit_code": None, "worker_commits": [], "rows_cured": [],
        "rows_unfinished": ["R-1"], "census_note": "no worker ran [cut]",
        "seat_session": "00000000-0000-4000-8000-000000000001", "backfilled": False},
    2: {"event": "complete", "seq": 502, "ts": "2026-01-05T10:10:02.000Z", "kind": "worker",
        "role": "coding-strong", "dispatch_id": "D-W-2-R1", "rung": "L3", "charter": "AM-902",
        "result_path": None, "result_bytes": None, "result_sha256": None, "anchors_sha256": None,
        "null_reason": "REFUSED BEFORE SPAWN: the runner's ADR-022 verify gate refused (exit 2) [cut]",
        "rework_of": "D-W-2",
        "outcome": "REFUSED BEFORE SPAWN BY THE RUNNER'S ADR-022 VERIFY GATE -- runner exit 2 [cut]",
        "worker_exit_code": None, "runner_exit": 2, "runner_started": "2026-01-05T10:08:00.000Z",
        "runner_ended": "2026-01-05T10:08:15.000Z",
        "runner_out_sha256": "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1",
        "runner_out_path": ".mission-runtime/lam/close/arc-x-2/runner-D-W-2-R1.out",
        "worker_commits": [], "next": "D-W-2-R1b [cut]",
        "seat_session": "00000000-0000-4000-8000-000000000002", "backfilled": False,
        "composed_by": "tools/lam/spawn_ledger.py@fab06f90"},
    3: {"event": "complete", "seq": 503, "ts": "2026-01-05T10:20:03.000Z", "kind": "validator",
        "role": "qa-validator", "dispatch_id": "D-V-A-913", "validates": "A-913", "round": 1,
        "round_label": "R-X-3", "rung": "L3", "charter": "AM-902", "gate": "dispatch-v-r-x-3-r1",
        "result_path": None, "result_bytes": None, "result_sha256": None, "anchors_sha256": None,
        "null_reason": "REFUSED BEFORE SPAWN: the runner's ADR-022 verify gate refused (exit 2) [cut]",
        "outcome": "REFUSED BEFORE SPAWN BY THE RUNNER'S ADR-022 VERIFY GATE -- runner exit 2 [cut]",
        "worker_exit_code": None, "runner_exit": 2,
        "runner_out_path": ".mission-runtime/lam/close/arc-x-3/runner-D-V-A-913.out [cut]",
        "seat_session": "00000000-0000-4000-8000-000000000002", "backfilled": False,
        "composed_by": "tools/lam/spawn_ledger.py@fab06f90"},
    4: {"event": "complete", "seq": 504, "ts": "2026-01-05T11:30:04.000Z", "kind": "validator",
        "role": "qa-validator", "dispatch_id": "D-V-A-914-R2", "validates": "A-914", "round": 2,
        "round_label": "R-X-4-R2", "rung": "L3", "charter": "AM-902", "gate": "dispatch-v-r-x-4-r2",
        "rework_of": "D-V-A-914", "result_path": None, "result_bytes": None, "result_sha256": None,
        "null_reason": "NO RESULT WAS WRITTEN: the validator's session ended its turn [cut]",
        "outcome": "NO VERDICT -- THE ROUND'S ONE VALIDATOR LEFT NO RESULT [cut]",
        "worker_exit_code": 0, "runner_exit": 3, "runner_started": "2026-01-05T10:40:00.000Z",
        "runner_ended": "2026-01-05T11:25:00.000Z",
        "runner_out_path": ".mission-runtime/lam/close/arc-x-4/runner-D-V-A-914-R2.out",
        "runner_out_sha256": "a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2",
        "login_probe": "OK -- the runner's line: answered exactly OK [cut]",
        "anchors_path": ".mission/dispatches/D-V-A-914-R2.anchors.yaml",
        "anchors_sha256": "a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3",
        "anchors_sha256_lf_blob": "a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4",
        "handoff_path": ".mission/dispatches/D-V-A-914-R2.handoff.yaml",
        "handoff_sha256": "a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5",
        "handoff_status": "rejected",
        "suite_runner_run": "the runner's instrument run in the validator's tree [cut]",
        "census_bracket": "0 RUNNING at 2026-01-05T10:4xZ before the spawn (witness "
                          "census-x-4-before.json) and 0 RUNNING at 11:26:00.000Z after "
                          "(12 in all; witness census-x-4-after.json)",
        "next": "the round re-issued under a fresh id, D-V-A-914-R2b [cut]",
        "seat_session": "00000000-0000-4000-8000-000000000002", "backfilled": False,
        "composed_by": "tools/lam/spawn_ledger.py@fab06f90"},
    5: {"event": "complete", "seq": 505, "ts": "2026-01-05T12:00:05.000Z", "kind": "validator",
        "role": "qa-validator", "dispatch_id": "D-V-A-915", "validates": "A-915", "round": 1,
        "round_label": "R-X-5", "rung": "L3", "charter": "AM-903", "gate": "dispatch-v-r-x-5-r1",
        "result_path": "tests/lam/validator-A-915.result.yaml", "result_sha256": None, "verdict": None,
        "outcome": "RUNNER REFUSED BEFORE SPAWNING, exit 2 -- the verify gate did not PASS [cut]",
        "runner_lines": ["mission-dispatch: verify scoping [cut]",
                         "mission-dispatch: ADR-022 gate -- verified against D-V-A-916.anchors.yaml (exit 1)",
                         "mission-dispatch: verify gate did not PASS (exit 1). ADR-022 refusal [cut]",
                         "reason: advance admission REFUSED: UNCOMMITTED DRIFT [cut]"],
        "gate_consumed_spawns_after": ["{seq: 1, dispatch_id: D-V-A-916}"], "runner_exit": 2,
        "runner_started": "2026-01-05T11:55:00.000Z", "runner_ended": "2026-01-05T11:55:14.000Z",
        "runner_out_path": ".mission-runtime/lam/close/arc-x-5/runner-D-V-A-915.attempt-1-exit-2.out",
        "runner_out_sha256": "a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6",
        "next": "the same dispatch id is run again under a NEW seq [cut]",
        "seat_session": "00000000-0000-4000-8000-000000000003", "backfilled": False,
        "composed_by": "tools/lam/spawn_ledger.py@fab07c67"},
}
NULL_VALIDATOR_FORMS = (3, 4, 5)
_REPO = _TOOLS.parent                                     # repo root (this worktree)
# the tool before the complete line's reading: the installed synthetic base, read from nothing else (no history)
_BASE_PY_FIXTURE = _REPO / "tests" / "lam" / "fixtures" / "base-700e19e5-s08" / "tools" / "lam" / "transcribe_validator_results.py.base"
_BASE_PY_SHA256 = "7428c6fecfc746080532c02c6a4f47cd63281eff445abc6b4de127520ddddab5"


def _beside_a_bound_line(fx, form_no):
    """The embedded validator form first, as such a line stands on a ledger, and at its own round one honest pair
    that binds a result. Returns the form and the bound seq."""
    form = NULL_FORMS[form_no]
    bound_seq = 900 + form["round"]
    fx.spawn_pair(bound_seq, form["validates"], fx.result(form["validates"]), rnd=form["round"])
    fx.lines.insert(0, dict(form))
    fx.flush()
    return form, bound_seq


def test_null_result_worker_closures_are_never_read(fx):
    """CLASSES 1 AND 2 (forms 1 and 2). A worker's exit-2 closure carries no `validates`:
    beside one honest assertion the tool resolves that assertion and names nothing SET ASIDE."""
    fx.spawn_pair(901, "A-901", fx.result("A-901"))
    for form_no in (1, 2):
        fx.lines.append(dict(NULL_FORMS[form_no]))
    fx.flush()
    before = fx.snapshot()
    proc = fx.run("A-901")
    assert proc.returncode == 0, proc.merged
    assert "seq 901" in proc.stdout
    assert "ALL 1 EQUALITIES HELD." in proc.stdout
    assert "SET ASIDE" not in proc.merged
    assert fx.snapshot() == before


@pytest.mark.parametrize("form_no", NULL_VALIDATOR_FORMS)
def test_null_result_validator_line_alone_stops_in_the_tools_own_sentence(fx, form_no):
    """CLASSES 3, 4 AND 5, ALONE. The line holds the highest round and binds no result: a STOP that
    names the round and the seq, never a resolution."""
    form = NULL_FORMS[form_no]
    fx.lines.append(dict(form))
    fx.flush()
    before = fx.snapshot()
    proc = fx.run(form["validates"])
    assert proc.returncode != 0, proc.merged
    assert ("%s: the highest round (%d) is held only by complete line(s) that bind no result -- "
            "seqs [%d]" % (form["validates"], form["round"], form["seq"])) in proc.merged
    assert "will not fall back to an earlier round" in proc.merged
    assert fx.snapshot() == before


@pytest.mark.parametrize("form_no", NULL_VALIDATOR_FORMS)
def test_null_result_validator_line_beside_a_bound_pair_resolves_and_is_set_aside(fx, form_no):
    """CLASSES 3, 4 AND 5, BESIDE A PAIR THAT BINDS A RESULT AT THE SAME ROUND. The bare-id path
    resolves the bound seq and NAMES the other on its resolution line."""
    form, bound_seq = _beside_a_bound_line(fx, form_no)
    before = fx.snapshot()
    proc = fx.run(form["validates"])
    assert proc.returncode == 0, proc.merged
    assert ("seq %d" % bound_seq) in proc.merged
    assert ("SET ASIDE, claiming no round: 1 complete line(s) that bind no result -- seq %d "
            "(round %d)" % (form["seq"], form["round"])) in proc.merged
    assert "ALL 1 EQUALITIES HELD." in proc.stdout
    assert fx.snapshot() == before


def test_null_result_line_above_an_earlier_bound_round_still_stops(fx):
    """FAIL-CLOSED KEPT. Form 4 holds round 2 above an honest round 1: the tool does not
    fall back to the earlier result."""
    form = NULL_FORMS[4]
    fx.spawn_pair(901, form["validates"], fx.result(form["validates"]), rnd=1)
    fx.lines.append(dict(form))
    fx.flush()
    proc = fx.run(form["validates"])
    assert proc.returncode != 0, proc.merged
    assert "is held only by complete line(s) that bind no result -- seqs [504]" in proc.merged


def test_non_vacuity_the_tool_before_the_complete_lines_reading_fails_classes_3_to_5(tmp_path):
    """NON-VACUITY. The three 'beside a bound pair' cases above RESOLVE. The same three ledgers, driven
    through the transcription tool as it stood BEFORE the complete line's reading -- the installed synthetic
    base tests/lam/fixtures/base-700e19e5-s08/tools/lam/transcribe_validator_results.py.base, held to the
    sha256 pinned here, behind this tree's own wrapper -- each STOP as a tie, with nothing set aside. So those
    tests can fail, and on that reader did."""
    assert _BASE_PY_FIXTURE.is_file(), "NOT READ: no fixture %s" % _BASE_PY_FIXTURE
    base = _BASE_PY_FIXTURE.read_bytes()
    assert _sha(base) == _BASE_PY_SHA256, "the base fixture's bytes are not the pinned ones"
    for form_no in NULL_VALIDATOR_FORMS:
        sub = tmp_path / ("base-%d" % form_no)
        sub.mkdir()
        fx = Fixture(sub)
        (sub / "tools" / "lam" / _PY.name).write_bytes(base)
        form, _ = _beside_a_bound_line(fx, form_no)
        proc = fx.run(form["validates"])
        assert proc.returncode != 0, "form %d: %s" % (form_no, proc.merged)
        assert "more than one complete line" in proc.merged, form_no
        assert "SET ASIDE" not in proc.merged, form_no
