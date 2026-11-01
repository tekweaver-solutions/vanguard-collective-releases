"""THE FW CURE -- guards for tools/mission-close-milestone.ps1's A-127/A-128 roster
gate now that it reads the LAM binding on .mission-runtime/lam/spawn-ledger.jsonl DIRECTLY.

THE DEFECT THESE GUARDS CLOSE. The LAM validators never write .mission/validator-results/. Each writes
ONE result file at tests/lam/validator-<A-NNN>.result.yaml (gitignored), bound only by result_sha256 on
its own 'complete' line in the spawn ledger. Before the cure, a roster validated exactly that way was
REFUSED by the close with "roster assertion A-NNN has NO recorded ValidatorResult" -- right about the
store and wrong about the work. test_lam_shape_roster_closes_where_it_used_to_refuse is that case;
test_seven_real_bound_results_close, which drove it against real results, is a named skip (not carried).

WHY THIS HOME. Its closest neighbour, test_validator_result_transcription.py, guards the transcription
BRIDGE for the same defect; this file guards the CURE that makes the bridge optional, so the two
halves sit side by side. conftest.py's isolation idiom is exactly what driving close-milestone
needs -- Get-MissionRoot resolves to (parent of the script dir), so copying the .ps1 into <tmp>/tools/ and
invoking THAT makes the CLI operate on <tmp>/.mission/ and nothing else. tests/lam/instrument-WP-* is the
alternative and was not chosen: those are PowerShell work-package acceptance instruments, not a home for a
CLI regression guard, and the pytest suite is what the close ceremony's own green-gate runs.

NOTHING HERE TOUCHES THE REAL MISSION PLANE. Every fixture root lives in pytest's tmp_path, and every
spawn-ledger line and result file a case drives is synthetic; no case reads a checkout's runtime plane.
The checkout is read only for the tools under test and the installed synthetic base fixture.
"""

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]              # repo/tools
_REPO = _TOOLS.parent                                     # repo root (this worktree)
_CLOSE = _TOOLS / "mission-close-milestone.ps1"
_LIB = _TOOLS / "mission-lib.ps1"


def _powershell():
    for cand in ("powershell", "powershell.exe", "pwsh"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (powershell/pwsh) on PATH -- cannot shell the .ps1 CLI")


def _sha(b):
    return hashlib.sha256(b).hexdigest()


RESULT_BODY = """\
# a synthetic LAM validator result, in the shape the real ones use
verdict: {verdict}
id: D-V-{aid}
validates: {aid}
checks:
  - check: the fixture check
    verdict: {verdict}
findings: []
"""


class Root:
    """An isolated mission root: tools/ copies, a spec with one pending milestone and its roster, an
    amendment, a ledger file -- plus whichever validation stores the case wants."""

    def __init__(self, tmp, roster=("A-901", "A-902")):
        self.root = tmp
        self.roster = list(roster)
        tools = tmp / "tools"
        tools.mkdir(parents=True, exist_ok=True)
        shutil.copy2(_LIB, tools / _LIB.name)
        shutil.copy2(_CLOSE, tools / _CLOSE.name)
        self.cli = tools / _CLOSE.name
        m = tmp / ".mission"
        for sub in ("spec", "amendments", "ledger"):
            (m / sub).mkdir(parents=True, exist_ok=True)
        (tmp / "tests" / "lam").mkdir(parents=True, exist_ok=True)
        (tmp / ".mission-runtime" / "lam").mkdir(parents=True, exist_ok=True)
        self.ledger_path = tmp / ".mission-runtime" / "lam" / "spawn-ledger.jsonl"
        self.vr = m / "validator-results"
        (m / "mission.yaml").write_text(
            "id: FIXTURE\nstate: Reworking\ncurrent_spec_version: v010\ncurrent_milestone: M-98\n",
            encoding="utf-8")
        (m / "spec" / "current.txt").write_text("v010\n", encoding="utf-8")
        (m / "spec" / "v010.yaml").write_text(
            "version: v010\n"
            "features:\n"
            "  - id: F-901\n"
            "    status: pending\n"
            "milestones:\n"
            "  - id: M-99\n"
            "    status: pending\n"
            "    features: [F-901]\n"
            "    contract_assertion_ids: [%s]\n"
            "trailer: end\n" % ", ".join(self.roster), encoding="utf-8")
        (m / "amendments" / "AM-099-fixture.yaml").write_text("id: AM-099\n", encoding="utf-8")
        (m / "ledger" / "entries.jsonl").write_text("", encoding="utf-8")
        (tmp / "led.txt").write_text("fixture ledger content\n", encoding="utf-8")
        self.lines = []

    # -- the LAM store: result files + spawn-ledger complete lines ------------------------------
    def result(self, aid, verdict="PASS", body=None):
        blob = (body if body is not None else
                RESULT_BODY.format(aid=aid, verdict=verdict)).encode("utf-8")
        (self.root / "tests" / "lam" / ("validator-%s.result.yaml" % aid)).write_bytes(blob)
        return _sha(blob)

    def complete(self, seq, aid, sha, rnd=1, verdict="PASS", validates=None, result_path=None,
                 dispatch=None, drop=()):
        rec = {"event": "complete", "seq": seq, "kind": "validator", "role": "qa-validator",
               "dispatch_id": dispatch or ("D-V-%s-R%d" % (aid, rnd)),
               "validates": aid if validates is None else validates,
               "round": rnd, "verdict": verdict, "result_sha256": sha,
               "result_path": result_path if result_path is not None
               else "tests/lam/validator-%s.result.yaml" % aid}
        for k in drop:
            rec.pop(k, None)
        self.lines.append({"event": "spawn", "seq": seq, "kind": "validator",
                           "dispatch_id": rec["dispatch_id"], "validates": aid, "round": rnd})
        self.lines.append(rec)
        self.flush()

    def raw_ledger_line(self, text):
        self.ledger_path.write_text(
            self.ledger_path.read_text(encoding="utf-8") + text + "\n", encoding="utf-8")

    def flush(self):
        self.ledger_path.write_text(
            "".join(json.dumps(r) + "\n" for r in self.lines), encoding="utf-8")

    def lam_pass(self, aid, seq, rnd=1):
        self.complete(seq, aid, self.result(aid), rnd=rnd)

    # -- the section-6 store: manifest + per-assertion JSONs ------------------------------------
    def manifest(self, specs):
        """specs: [(assertion_id, verdict, attempt_number, extra-entry-fields)]"""
        self.vr.mkdir(parents=True, exist_ok=True)
        entries = []
        for aid, verdict, attempt, extra in specs:
            fname = "%s.validator-result.json" % aid
            (self.vr / fname).write_text(json.dumps(
                {"id": "fixture-%s" % aid.lower(), "assertion_id": aid, "verdict": verdict,
                 "attempt_number": attempt, "validator_id": "fixture", "evidence": []},
                indent=4), encoding="utf-8")
            entry = {"assertion_id": aid, "verdict": verdict, "attempt_number": attempt,
                     "file": fname, "id": "fixture-%s" % aid.lower()}
            entry.update(extra)
            entries.append(entry)
        (self.vr / "manifest.json").write_text(
            json.dumps({"entries": entries}, indent=2), encoding="utf-8")

    # -- driving -------------------------------------------------------------------------------
    def run(self, *extra):
        argv = [_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.cli),
                "-Milestone", "M-99", "-AmendmentId", "AM-099",
                "-LedgerContentFile", str(self.root / "led.txt"),
                "-NoCommit", "-RosterGateOnly"] + list(extra)
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=600)
        proc.merged = (proc.stdout or "") + (proc.stderr or "")
        return proc

    def snapshot(self):
        out = {}
        for p in sorted(self.root.rglob("*")):
            if p.is_file():
                out[str(p.relative_to(self.root)).replace("\\", "/")] = _sha(p.read_bytes())
        return out


@pytest.fixture
def rt(tmp_path):
    return Root(tmp_path)


# ------------------------------------------------------------------ THE CURE, THE ACCEPTANCE --
def test_lam_shape_roster_closes_where_it_used_to_refuse(rt):
    """THE DEFECT, INVERTED. Result files + spawn-ledger complete lines, NO manifest at all. Before
    the cure this refused with 'no validator-results manifest'; it must now PERMIT."""
    rt.lam_pass("A-901", 901)
    rt.lam_pass("A-902", 902)
    before = rt.snapshot()
    proc = rt.run()
    assert proc.returncode == 0, proc.merged
    assert "roster closable: all 2 assertions" in proc.merged
    assert "2 from the spawn-ledger binding alone" in proc.merged
    assert "roster gate PERMITS M-99" in proc.merged
    assert rt.snapshot() == before, "the roster gate must not write a byte"


def test_seven_real_bound_results_close(tmp_path):
    """NOT CARRIED, A NAMED SKIP. This guard drove the close against seven real bound result files and
    the spawn ledger that binds them, copied out of a checkout's runtime plane. Those records belong to
    the project the framework was extracted from, and the framework does not carry them. The synthetic
    cases in this file drive the same path: result files bound only by their spawn-ledger complete lines."""
    pytest.skip("not carried: the seven real bound results and their spawn ledger belong to the project "
                "the framework was extracted from")


# ------------------------------------------------------------------- THE FOUR REFUSAL CAUSES --
def test_sha256_mismatch_refuses_and_prints_both_figures(rt):
    rt.lam_pass("A-901", 901)
    bound = rt.result("A-902")                 # bind the honest bytes ...
    rt.complete(902, "A-902", bound)
    (rt.root / "tests" / "lam" / "validator-A-902.result.yaml").write_bytes(
        RESULT_BODY.format(aid="A-902", verdict="PASS").encode("utf-8") + b"# tampered\n")
    actual = _sha((rt.root / "tests" / "lam" / "validator-A-902.result.yaml").read_bytes())
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "SHA256 MISMATCH" in proc.merged
    assert bound in proc.merged and actual in proc.merged
    assert bound != actual


def test_result_file_absent_refuses(rt):
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902"))
    (rt.root / "tests" / "lam" / "validator-A-902.result.yaml").unlink()
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "RESULT FILE ABSENT" in proc.merged
    assert "tests/lam/validator-A-902.result.yaml" in proc.merged


def test_no_complete_line_binding_a_roster_assertion_refuses(rt):
    rt.lam_pass("A-901", 901)
    rt.result("A-902")                          # the file exists but NOTHING binds it
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "roster assertion A-902 has NO recorded ValidatorResult" in proc.merged
    assert "NO BINDING" in proc.merged


def test_unreadable_ledger_line_refuses(rt):
    rt.lam_pass("A-901", 901)
    rt.lam_pass("A-902", 902)
    rt.raw_ledger_line("{not json at all")
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "UNREADABLE BINDING" in proc.merged
    assert "not JSON" in proc.merged


def test_complete_line_without_a_round_refuses(rt):
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902"), drop=("round",))
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "UNREADABLE BINDING" in proc.merged
    assert "carries no 'round'" in proc.merged


def test_ambiguous_highest_round_refuses_rather_than_picking_one(rt):
    rt.lam_pass("A-901", 901)
    sha = rt.result("A-902")
    rt.complete(902, "A-902", sha, rnd=2, dispatch="D-V-A-902-R2a")
    rt.complete(903, "A-902", sha, rnd=2, dispatch="D-V-A-902-R2b")
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "will not pick the first of a class" in proc.merged


# ---------------------------------------------------------- THE A-128 SUPERSESSION PROPERTY --
def test_later_round_non_pass_supersedes_an_earlier_pass(rt):
    """A round-1 PASS that a round-2 non-pass supersedes is NOT closeable -- the same property the
    manifest path has with attempt_number. The result file carries the CURRENT round's bytes, which is
    how the real ledger behaves (every round names the same result path and overwrites it)."""
    rt.lam_pass("A-901", 901)
    pass_sha = rt.result("A-902", verdict="PASS")
    rt.complete(902, "A-902", pass_sha, rnd=1, verdict="PASS")
    fail_sha = rt.result("A-902", verdict="FAIL")       # round 2 overwrites the file
    rt.complete(903, "A-902", fail_sha, rnd=2, verdict="FAIL")
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "current ValidatorResult verdict is 'fail'" in proc.merged
    assert "spawn-ledger round 2" in proc.merged


def test_round_3_pass_over_a_round_2_fail_closes(rt):
    """The mirror of the case above, and a shape real rounds take: rounds 1 PASS, 2 FAIL,
    3 PASS -- the CURRENT round decides, so this PERMITS."""
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902", verdict="PASS"), rnd=1, verdict="PASS")
    rt.complete(903, "A-902", rt.result("A-902", verdict="FAIL"), rnd=2, verdict="FAIL")
    rt.complete(904, "A-902", rt.result("A-902", verdict="PASS"), rnd=3, verdict="PASS")
    proc = rt.run()
    assert proc.returncode == 0, proc.merged
    assert "roster closable: all 2 assertions" in proc.merged


def test_a_non_pass_vocabulary_verdict_refuses(rt):
    """structural-pass / docker-pending / inconclusive are NOT 'pass' -- a non-pass vocabulary verdict."""
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902", verdict="structural-pass"), verdict="structural-pass")
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "verdict is 'structural-pass'" in proc.merged


def test_verdict_is_read_from_the_document_not_the_ledger_prose(rt):
    """The ledger says PASS, the document the ledger BINDS says FAIL. The gate reads the document, and
    the contradiction itself is a refusal."""
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902", verdict="FAIL"), verdict="PASS")
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "the binding contradicts itself" in proc.merged


# ------------------------------------------------------------------- THE MIGRATION PATH LIVES --
def test_already_transcribed_manifest_record_still_closes(rt):
    """No spawn ledger at all -- the pre-cure world. The manifest path must be untouched."""
    rt.ledger_path.unlink(missing_ok=True)
    rt.manifest([("A-901", "pass", 1, {}), ("A-902", "pass", 1, {})])
    proc = rt.run()
    assert proc.returncode == 0, proc.merged
    assert "2 from the manifest alone" in proc.merged
    assert "manifest verdict-integrity" in proc.merged and "A-184/A-185" in proc.merged


def test_manifest_non_pass_still_refuses_with_the_message_it_always_had(rt):
    rt.ledger_path.unlink(missing_ok=True)
    rt.manifest([("A-901", "pass", 1, {}), ("A-902", "fail", 2, {})])
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "roster assertion A-902 current ValidatorResult verdict is 'fail'" in proc.merged


def test_neither_store_binds_the_assertion_refuses_as_it_always_did(rt):
    rt.ledger_path.unlink(missing_ok=True)
    rt.manifest([("A-901", "pass", 1, {})])
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "roster assertion A-902 has NO recorded ValidatorResult" in proc.merged


def test_both_stores_present_and_in_agreement_closes(rt):
    s1 = rt.result("A-901")
    rt.complete(901, "A-901", s1)
    s2 = rt.result("A-902")
    rt.complete(902, "A-902", s2)
    rt.manifest([("A-901", "pass", 1, {"result_sha256": s1}),
                 ("A-902", "pass", 1, {"result_sha256": s2})])
    proc = rt.run()
    assert proc.returncode == 0, proc.merged
    assert "2 from BOTH stores in agreement" in proc.merged


# ------------------------------------------------------- THE FAIL-CLOSED PRECEDENCE RULE --
def test_manifest_and_ledger_disagree_on_the_verdict_refuses(rt):
    """Neither store wins. A disagreement means one of them is stale, and a stale record must never
    decide a close."""
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902", verdict="FAIL"), verdict="FAIL")
    rt.manifest([("A-901", "pass", 1, {}), ("A-902", "pass", 1, {})])
    before = rt.snapshot()
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "TWO-STORE DIVERGENCE" in proc.merged
    assert "ONE OF THEM IS STALE" in proc.merged
    assert rt.snapshot() == before


def test_manifest_and_ledger_disagree_on_the_bound_sha_refuses(rt):
    rt.lam_pass("A-901", 901)
    s2 = rt.result("A-902")
    rt.complete(902, "A-902", s2)
    rt.manifest([("A-901", "pass", 1, {}),
                 ("A-902", "pass", 1, {"result_sha256": "0" * 64})])
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "TWO-STORE DIVERGENCE" in proc.merged
    assert "DIFFERENT result bytes" in proc.merged


def test_manifest_and_ledger_disagree_on_which_attempt_is_current_refuses(rt):
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902"), rnd=3)
    rt.manifest([("A-901", "pass", 1, {}), ("A-902", "pass", 1, {})])
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "disagree about WHICH ATTEMPT IS CURRENT" in proc.merged


def test_a_broken_ledger_does_not_get_papered_over_by_a_green_manifest(rt):
    """The ledger binds A-902 to bytes that are not there. A manifest entry saying 'pass' must NOT
    rescue it -- the gate does not fall back to the other store."""
    rt.lam_pass("A-901", 901)
    rt.complete(902, "A-902", rt.result("A-902"))
    (rt.root / "tests" / "lam" / "validator-A-902.result.yaml").unlink()
    rt.manifest([("A-901", "pass", 1, {}), ("A-902", "pass", 1, {})])
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "RESULT FILE ABSENT" in proc.merged
    assert "does NOT fall back to the other store" in proc.merged


# ---------------------------------- THE FIVE NULL-RESULT FORMS --
# Five synthetic 'complete' lines whose result_sha256 is JSON null, numbered 1 to 5. Each is in the shape
# the runner and its seat write such a line: the key set and order, the round and the null fields of a
# real closure of its class, every id, time and digest in it synthetic. A long prose value is cut to its
# opening words and ends " [cut]", as a cut value would be.
# 1 and 2 are a WORKER's closure -- no `validates` -- so this gate never takes them as candidates.
# 3, 4 and 5 are a VALIDATOR's: each binds no result and claims no round (the complete line's
# reading). The gate was already right on all five; these tests hold it there,
# and the last of them shows they can fail, on the CLI as it stood before that reading.
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
# the CLI before the complete line's reading: the installed synthetic base, read from nothing else (no history)
_BASE_CLOSE_FIXTURE = _REPO / "tests" / "lam" / "fixtures" / "base-700e19e5-s08" / "tools" / "mission-close-milestone.ps1.base"
_BASE_CLOSE_SHA256 = "2a3acc78b5a8d0b0e3f949321593e0934782ee0126ba78db1dd5d32a71688f30"


def _null_line_first(rt, form_no):
    """Put the embedded form AHEAD of whatever the root has flushed, as such a line stands on a ledger."""
    rest = rt.ledger_path.read_text(encoding="utf-8") if rt.ledger_path.exists() else ""
    rt.ledger_path.write_text(json.dumps(NULL_FORMS[form_no]) + "\n" + rest, encoding="utf-8")


def _beside_a_bound_line(tmp, form_no):
    """The embedded validator form and, at its own round, one honest line that binds a result."""
    form = NULL_FORMS[form_no]
    rt = Root(tmp, roster=(form["validates"],))
    rt.lam_pass(form["validates"], 900 + form["round"], rnd=form["round"])
    _null_line_first(rt, form_no)
    return rt, form


def test_null_result_worker_closures_are_never_read(tmp_path):
    """CLASSES 1 AND 2 (forms 1 and 2). A worker's exit-2 closure carries no `validates`, so
    it is no candidate for any roster assertion: beside an honest roster the gate PERMITS and names
    nothing SET ASIDE."""
    rt = Root(tmp_path, roster=("A-901",))
    rt.lam_pass("A-901", 901)
    for form_no in (1, 2):
        rt.raw_ledger_line(json.dumps(NULL_FORMS[form_no]))
    before = rt.snapshot()
    proc = rt.run()
    assert proc.returncode == 0, proc.merged
    assert "roster gate PERMITS M-99" in proc.merged
    assert "1 from the spawn-ledger binding alone" in proc.merged
    assert "SET ASIDE" not in proc.merged
    assert rt.snapshot() == before


@pytest.mark.parametrize("form_no", NULL_VALIDATOR_FORMS)
def test_null_result_validator_line_alone_refuses_in_the_gates_own_sentence(tmp_path, form_no):
    """CLASSES 3, 4 AND 5, ALONE. The line holds the highest round and binds no result, so the
    assertion has no current result: REFUSED, naming the round and the seq."""
    form = NULL_FORMS[form_no]
    rt = Root(tmp_path, roster=(form["validates"],))
    _null_line_first(rt, form_no)
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "UNREADABLE BINDING" in proc.merged
    assert ("the highest round (%d) for %s is held only by 1 'complete' line(s) that bind no result "
            "(seq %d)" % (form["round"], form["validates"], form["seq"])) in proc.merged
    assert "this gate will not fall back to an earlier round" in proc.merged


@pytest.mark.parametrize("form_no", NULL_VALIDATOR_FORMS)
def test_null_result_validator_line_beside_a_bound_line_permits_and_is_set_aside(tmp_path, form_no):
    """CLASSES 3, 4 AND 5, BESIDE A LINE THAT BINDS A RESULT AT THE SAME ROUND -- the shape a
    ledger takes. The gate PERMITS on the bound line and NAMES the other on its pass line."""
    rt, form = _beside_a_bound_line(tmp_path, form_no)
    before = rt.snapshot()
    proc = rt.run()
    assert proc.returncode == 0, proc.merged
    assert "roster gate PERMITS M-99" in proc.merged
    assert ("SET ASIDE, claiming no round: 1 'complete' line(s) that bind no result -- %s seq %d "
            "(round %d)." % (form["validates"], form["seq"], form["round"])) in proc.merged
    assert rt.snapshot() == before


def test_null_result_line_above_an_earlier_bound_round_still_refuses(tmp_path):
    """FAIL-CLOSED KEPT. Form 4 holds round 2 above an honest round 1: the gate does not
    fall back to the earlier result."""
    form = NULL_FORMS[4]
    rt = Root(tmp_path, roster=(form["validates"],))
    rt.lam_pass(form["validates"], 901, rnd=1)
    _null_line_first(rt, 4)
    proc = rt.run()
    assert proc.returncode == 1, proc.merged
    assert "is held only by 1 'complete' line(s) that bind no result (seq 504)" in proc.merged


def test_non_vacuity_the_cli_before_the_complete_lines_reading_fails_classes_3_to_5(tmp_path):
    """NON-VACUITY. The three 'beside a bound line' cases above PERMIT. The same three ledgers, driven
    through the close CLI as it stood BEFORE the complete line's reading -- the installed synthetic base
    tests/lam/fixtures/base-700e19e5-s08/tools/mission-close-milestone.ps1.base, held to the sha256 pinned
    here -- are each REFUSED as a tie, with nothing set aside. So those tests can fail, and on that reader did."""
    assert _BASE_CLOSE_FIXTURE.is_file(), "NOT READ: no fixture %s" % _BASE_CLOSE_FIXTURE
    base = _BASE_CLOSE_FIXTURE.read_bytes()
    assert _sha(base) == _BASE_CLOSE_SHA256, "the base fixture's bytes are not the pinned ones"
    for form_no in NULL_VALIDATOR_FORMS:
        sub = tmp_path / ("base-%d" % form_no)
        sub.mkdir()
        rt, form = _beside_a_bound_line(sub, form_no)
        rt.cli.write_bytes(base)
        proc = rt.run()
        assert proc.returncode == 1, "form %d: %s" % (form_no, proc.merged)
        assert "will not pick the first of a class" in proc.merged, form_no
        assert "SET ASIDE" not in proc.merged, form_no
