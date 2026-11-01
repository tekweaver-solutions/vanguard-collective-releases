"""The legacy HALT census leaves the evaluator.

tools/lam/mission-goal-check.ps1 carried its legacy census -- the first host's own HALTs, by name and sha256 -- as a
literal, so every installed project carried them. It now reads tools/lam/legacy-halt-census.txt beside it, a
HOST-CONFIG file the framework ships EMPTY, and tools/lam/export-legacy-census.ps1 writes that file from an earlier
evaluator's literal (docs/framework/LAM-INSTALL.md section 10).

THE CASES.
- NO CENSUS IS ONE VERDICT: the evaluator over an absent census file, an empty one and the file the framework ships
  writes one artifact, byte for byte but its evaluated_at line; and it is the artifact the evaluator before this item
  (f425c0b, the last whose evaluator carries the literal) writes with its literal emptied -- but for the
  not-in-legacy-census reason's words after its code, which name where the census is.
- A TWO-ENTRY CENSUS: HALT-SAMPLE-01 and -02 at their census sha256 are honoured, and a third HALT, allowlisted and
  ANSWERED by its own marker, is reported not-in-legacy-census and stays OPEN.
- A CENSUS LINE OF NO FORM: the census does not parse and admits nothing -- NOT_MET, the evaluator_error naming the
  file and its line; a goal that allowlists nothing never reads it.
- THE EXPORTER over the 0.2.0 evaluator, read from git at v0.2.0 into a scratch folder: its 89 member lines are the
  literal's entries, with the count and digest that evaluator's header records; a second run writes nothing; a census
  of other members is refused and left as it was; a source is parsed, never run; an evaluator with no literal is
  refused.

HERMETIC, as test_seat_halt_resolved.py: each evaluator runs as a COPY, beside copies of its three libraries, in a
scratch mission root under tmp_path; this checkout's git is read, never written. No census entry is printed by the
exporter, and none is compared here but against the literal it came from.
"""

import hashlib
import re
import shutil
import subprocess
from pathlib import Path

import pytest

_REPO = Path(__file__).resolve().parents[3]                        # the repository root
_LAM = _REPO / "tools" / "lam"
_FIXTURE = _REPO / "tests" / "lam" / "fixtures" / "legacy-census-halts"
_EVALUATOR_FILES = ("mission-goal-check.ps1", "lam-verify-admission.ps1", "lam-gate-class.ps1", "lam-instrument-run.ps1")
_BEFORE = "f425c0b9c7e819b2700086bd10aed342a37a1363"   # the last commit whose evaluator carries the census literal
_TAG = "v0.2.0"
_SAMPLE = {"HALT-SAMPLE-01.md": "0b3f575ab30397129850548edc98c883e6e36458973f31ffe2a4a19f3e2c5e2a",
           "HALT-SAMPLE-02.md": "0faf0e7dc6de0e342b85ba29324ddac7e84a1534d70a664244974c24ad8881a5"}
_LITERAL = re.compile(r"(?s)(\$script:HaltLegacyCensusText = @'\r?\n)(.*?)(\r?\n'@)")
_REASON_TAIL = re.compile(r"( -- NOT HONOURED -- not-in-legacy-census -- )[^\n]*")


def _powershell():
    for cand in ("powershell", "powershell.exe", "pwsh"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell on PATH -- cannot run the evaluator")


def _git_blob(spec):
    p = subprocess.run(["git", "-C", str(_REPO), "cat-file", "blob", spec], capture_output=True)
    if p.returncode != 0:
        pytest.skip("this checkout's history does not hold %s (a shallow clone?)" % spec)
    return p.stdout


def _census_text(members, comment="a census of tools/tests/cli/test_legacy_census.py"):
    canon = "".join(m + "\n" for m in sorted(members))
    sha = hashlib.sha256(canon.encode("ascii")).hexdigest()
    return "# %s\n#   count : %d\n#   census_sha256 : %s\n%s" % (comment, len(members), sha, canon)


class Root:
    """A scratch mission root: copies of an evaluator and its libraries under tools/lam (the tree's, or -- given
    ``evaluator`` as name -> bytes -- another), a census file there or none, and the HALTs a case copies in."""

    def __init__(self, tmp_path, name, census=None, evaluator=None):
        self.root = tmp_path / name
        self.lam = self.root / "tools" / "lam"
        self.lam.mkdir(parents=True)
        for f in _EVALUATOR_FILES:
            if evaluator is None:
                shutil.copy2(_LAM / f, self.lam / f)
            else:
                (self.lam / f).write_bytes(evaluator[f])
        if census is not None:
            (self.lam / "legacy-halt-census.txt").write_bytes(census)
        self.halts = self.root / ".mission-runtime" / "halts"
        self.halts.mkdir(parents=True)
        (self.root / ".mission" / "goals").mkdir(parents=True)
        self.ps = _powershell()

    def halt(self, name, text=None):
        p = self.halts / name
        if text is None:
            shutil.copy2(_FIXTURE / name, p)
        else:
            p.write_bytes(text.encode("utf-8"))
        return hashlib.sha256(p.read_bytes()).hexdigest()

    def evaluate(self, entries):
        """The goal G-LC: one halt_absent detector allowlisting ``entries`` (none: no allowlist key)."""
        detector = "  - type: halt_absent\n"
        if entries:
            detector += '    legacy_answered_allowlist: "%s"\n' % ", ".join(entries)
        goal = self.root / ".mission" / "goals" / "G-LC.yaml"
        goal.write_bytes(("id: G-LC\ndetectors:\n" + detector).encode("utf-8"))
        verdict_path = self.root / ".mission" / "goals" / "G-LC.verdict.yaml"
        if verdict_path.exists():
            verdict_path.unlink()
        proc = subprocess.run([self.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.lam / "mission-goal-check.ps1"),
                               "-Goal", "G-LC", "-MissionRoot", str(self.root)], capture_output=True, timeout=300)
        out = proc.stdout.decode("utf-8", errors="replace")
        verdict = verdict_path.read_bytes().decode("utf-8").replace("\r\n", "\n") if verdict_path.exists() else ""
        return proc.returncode, out, verdict


def _list(verdict, key):
    m = re.search(r"(?m)^%s:(.*)\n((?:  - .*\n)*)" % re.escape(key), verdict)
    if not m:
        return None
    if m.group(1).strip() == "[]":
        return []
    entries = [line[4:] for line in m.group(2).splitlines()]
    return [e[1:-1].replace("''", "'") if len(e) > 1 and e.startswith("'") and e.endswith("'") else e for e in entries]


def _verdict_word(verdict):
    m = re.search(r"(?m)^verdict:[ \t]*(\S+)", verdict)
    return m.group(1) if m else None


def _artifact(verdict, root):
    """The artifact but its evaluated_at line, each run's own mission root written as one token."""
    text = "\n".join(l for l in verdict.split("\n") if not l.startswith("evaluated_at:"))
    for form in (str(root.root), str(root.root).replace("\\", "/"), str(root.root).replace("\\", "\\\\")):
        text = text.replace(form, "<root>")
    return text


def _sample_entry(name):
    return name + "@" + _SAMPLE[name]


def test_no_census_is_one_verdict_absent_empty_shipped_and_a_literal_of_zero_entries(tmp_path):
    shipped = (_LAM / "legacy-halt-census.txt").read_bytes()
    before = {f: _git_blob(_BEFORE + ":tools/lam/" + f) for f in _EVALUATOR_FILES}
    m = _LITERAL.search(before["mission-goal-check.ps1"].decode("utf-8"))
    assert m and len([l for l in m.group(2).splitlines() if l.strip()]) == 89, "the evaluator before this item carries the 89-member literal"
    src = before["mission-goal-check.ps1"].decode("utf-8")
    before["mission-goal-check.ps1"] = (src[:m.start(2)] + src[m.end(2):]).encode("utf-8")
    roots = {"absent": Root(tmp_path, "absent"), "empty": Root(tmp_path, "empty", census=b""),
             "shipped": Root(tmp_path, "shipped", census=shipped), "zero literal": Root(tmp_path, "zero", evaluator=before)}
    runs = {}
    for label, r in roots.items():
        sha = r.halt("HALT-SAMPLE-01.md")
        assert sha == _SAMPLE["HALT-SAMPLE-01.md"]
        runs[label] = r.evaluate([_sample_entry("HALT-SAMPLE-01.md")])
    for label, (code, out, verdict) in runs.items():
        assert code == 3, (label, out)
        assert _verdict_word(verdict) == "HALT", (label, verdict)
        assert _list(verdict, "open_halts") and _list(verdict, "open_halts")[0].startswith("HALT-SAMPLE-01.md [seat marker ANSWERED"), (label, verdict)
        assert _list(verdict, "halts_answered_by_legacy_allowlist") == [], (label, verdict)
        report = _list(verdict, "legacy_allowlist_report")
        assert report and len(report) == 1 and report[0].startswith(_sample_entry("HALT-SAMPLE-01.md") + " -- NOT HONOURED -- not-in-legacy-census -- "), (label, verdict)
    art = {label: _artifact(runs[label][2], roots[label]) for label in roots}
    assert art["empty"] == art["absent"], "an empty census file and none are one census"
    assert art["shipped"] == art["absent"], "the shipped file is an empty census"
    assert _REASON_TAIL.sub(r"\1", art["zero literal"]) == _REASON_TAIL.sub(r"\1", art["absent"]), \
        "the evaluator before this item, its literal emptied, writes the same artifact but for the reason's words"
    assert "legacy-halt-census.txt" in _list(runs["absent"][2], "legacy_allowlist_report")[0], "the reason names the census file"


def test_a_two_entry_census_honours_both_and_rejects_a_third(tmp_path):
    r = Root(tmp_path, "two", census=_census_text([_sample_entry(n) for n in _SAMPLE]).encode("ascii"))
    for n in _SAMPLE:
        assert r.halt(n) == _SAMPLE[n]
    third = r.halt("HALT-SAMPLE-03.md", "# HALT-SAMPLE-03\n\n**Status:** ANSWERED -- by its own marker, after the census.\n")
    code, out, verdict = r.evaluate([_sample_entry(n) for n in _SAMPLE] + ["HALT-SAMPLE-03.md@" + third])
    assert code == 3 and _verdict_word(verdict) == "HALT", out
    honoured = _list(verdict, "halts_answered_by_legacy_allowlist")
    assert honoured is not None and len(honoured) == 2, verdict
    for n, e in zip(sorted(_SAMPLE), sorted(honoured)):
        assert e.startswith(_sample_entry(n) + " -- LEGACY-ALLOWLISTED"), e
    report = _list(verdict, "legacy_allowlist_report")
    assert report and len(report) == 1 and report[0].startswith("HALT-SAMPLE-03.md@" + third + " -- NOT HONOURED -- not-in-legacy-census -- "), verdict
    opened = _list(verdict, "open_halts")
    assert opened and len(opened) == 1 and opened[0].startswith("HALT-SAMPLE-03.md"), verdict


@pytest.mark.parametrize("line", ["HALT-SAMPLE-01.md@" + _SAMPLE["HALT-SAMPLE-01.md"].upper(), "HALT-SAMPLE-01.md", "not a member line"],
                         ids=["upper-case hex", "no sha256", "free text"])
def test_a_census_line_of_no_form_admits_nothing(tmp_path, line):
    r = Root(tmp_path, "bad", census=("# a census\n" + _sample_entry("HALT-SAMPLE-02.md") + "\n" + line + "\n").encode("ascii"))
    r.halt("HALT-SAMPLE-02.md")
    code, out, verdict = r.evaluate([_sample_entry("HALT-SAMPLE-02.md")])
    assert _verdict_word(verdict) == "NOT_MET", (out, verdict)
    assert code != 0, out
    assert re.search(r"THE LEGACY HALT CENSUS DOES NOT PARSE -- .*legacy-halt-census\.txt line 3 ", verdict + out), verdict + out
    assert _list(verdict, "halts_answered_by_legacy_allowlist") in (None, []), "a census that does not parse admits nothing"
    # A goal that names no entry never reads the census: the HALT is open, as with no census at all.
    code, out, verdict = r.evaluate([])
    assert code == 3 and _verdict_word(verdict) == "HALT", (out, verdict)


def _export(tmp_path, source, *extra):
    p = subprocess.run([_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(_LAM / "export-legacy-census.ps1"),
                        "-From", str(source), *extra], capture_output=True, timeout=300)
    return p.returncode, p.stdout.decode("utf-8", errors="replace") + p.stderr.decode("utf-8", errors="replace")


def test_the_exporter_writes_the_0_2_0_literal_and_never_overwrites_a_census(tmp_path):
    old = tmp_path / "old" / "mission-goal-check.ps1"
    old.parent.mkdir()
    old.write_bytes(_git_blob(_TAG + ":tools/lam/mission-goal-check.ps1"))
    text = old.read_bytes().decode("utf-8")
    m = _LITERAL.search(text)
    literal = [l.strip() for l in m.group(2).splitlines() if l.strip()]
    hdr_count = re.search(r"(?m)^#\s+count\s*:\s*(\d+)\b", text).group(1)
    hdr_sha = re.search(r"(?m)^#\s+census_sha256\s*:\s*([0-9a-f]{64})\b", text).group(1)
    assert len(literal) == 89 and hdr_count == "89"
    code, out = _export(tmp_path, old)
    assert code == 0, out
    census = old.parent / "legacy-halt-census.txt"
    lines = census.read_bytes().decode("ascii").split("\n")
    assert lines[-1] == "" and b"\r" not in census.read_bytes() and not census.read_bytes().startswith(b"\xef\xbb\xbf")
    members = [l for l in lines[:-1] if l.strip() and not l.startswith("#")]
    assert members == sorted(literal) == literal, "89 member lines, the literal's entries, in ordinal order"
    assert re.search(r"(?m)^#\s+count\s*:\s*89$", census.read_text()) and re.search(r"(?m)^#\s+census_sha256\s*:\s*%s$" % hdr_sha, census.read_text())
    assert hashlib.sha256("".join(l + "\n" for l in members).encode("ascii")).hexdigest() == hdr_sha
    assert not any(e in out for e in literal), "no census entry is printed"
    # Idempotent: a second run writes nothing.
    before = census.read_bytes(); stamp = census.stat().st_mtime_ns
    code, out = _export(tmp_path, old)
    assert code == 0 and "nothing was written" in out, out
    assert census.read_bytes() == before and census.stat().st_mtime_ns == stamp
    # A census of other members is the project's: refused, left as it was.
    other = _census_text(["HALT-OTHER.md@" + "a" * 64]).encode("ascii")
    census.write_bytes(other)
    code, out = _export(tmp_path, old)
    assert code == 2 and "REFUSED" in out, out
    assert census.read_bytes() == other
    # The empty file the framework ships is no census of the project's: written over.
    census.write_bytes((_LAM / "legacy-halt-census.txt").read_bytes())
    code, out = _export(tmp_path, old)
    assert code == 0 and census.read_bytes() == before, out
    # An evaluator with no literal -- this tree's -- is refused, and nothing is written.
    code, out = _export(tmp_path, _LAM / "mission-goal-check.ps1", "-To", str(tmp_path / "none.txt"))
    assert code == 1 and not (tmp_path / "none.txt").exists(), out


def test_the_exporter_parses_its_source_and_never_runs_it(tmp_path):
    sentinel = tmp_path / "ran.txt"
    src = tmp_path / "planted" / "mission-goal-check.ps1"
    src.parent.mkdir()
    src.write_bytes(("[System.IO.File]::WriteAllText('%s', 'ran')\n$script:HaltLegacyCensusText = @'\n%s\n'@\n"
                     % (sentinel, _sample_entry("HALT-SAMPLE-01.md"))).encode("utf-8"))
    code, out = _export(tmp_path, src)
    assert code == 0, out
    assert not sentinel.exists(), "the source's top level was run"
    assert _sample_entry("HALT-SAMPLE-01.md") + "\n" in (src.parent / "legacy-halt-census.txt").read_text()
    dq = tmp_path / "dq" / "mission-goal-check.ps1"
    dq.parent.mkdir()
    dq.write_bytes(('$script:HaltLegacyCensusText = @"\n%s\n"@\n' % _sample_entry("HALT-SAMPLE-01.md")).encode("utf-8"))
    code, out = _export(tmp_path, dq)
    assert code == 1 and not (dq.parent / "legacy-halt-census.txt").exists(), out
