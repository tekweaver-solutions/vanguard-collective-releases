"""A-126's ADMITTED SET and its COMPENSATING-CONTROL CITATION -- the pair, because the
citation describes the routes the narrowed admitted-set code relies on.



THE ADMITTED SET -- A-126 judges the porcelain against the MISSION'S DECLARED admitted_porcelain set,
not against a code constant.

WHY THIS SUITE AND NOT AN instrument-WP-*.ps1. Assert-CleanWorkingTree is a tools/mission-lib.ps1
helper -- the mission lifecycle CLI core -- and this directory is where mission-lib helpers are
already driven: test_reopen_matched_numbering.py drives Resolve-ReopenMatchedNumber through
_drv_resolve_number.ps1 against an isolated fixture root built in a temp dir. The tests/lam/
instruments are LAM-ACCEPT work-package instruments; WP-1's only contact with this function is
H-3, which checks a PATCH ARTIFACT rather than the function's behaviour. A reader looking for a
behavioural test of a mission-lib gate looks here.

WHAT WAS REPRODUCED BEFORE THE CURE, on this same fixture shape:
  * the real porcelain shape passed with the offending list EMPTY -- as did
  * '?? .mission/evidence/scratch-oops/', which is inside the evidence plane but outside the
    DECLARED 'verify-' prefix, and
  * ' M .mission/evidence/verify-0001/report.json' and its ' D' counterpart -- a TRACKED file
    modified and deleted under a declared prefix, at a status the declaration does not admit.
The pre-cure exemption matched the PATH ONLY, after the porcelain XY code had been stripped.

EVERY FIXTURE ROOT IS A SCRATCH GIT REPO UNDER pytest's tmp_path. Nothing here reads or writes
the real .mission, and no gate file is ever written outside the temp dir.
"""

import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]                 # repo/tools
_CLI = Path(__file__).resolve().parent                       # repo/tools/tests/cli
_DRV = _CLI / "_drv_clean_working_tree.ps1"

# The declaration verbatim from the repository of record's .mission/mission.yaml, in the BLOCK
# form it is written in. Re-derived at this HEAD; if it moves, these fixtures should move with it.
_DECLARATION = (
    'admitted_porcelain:\n'
    '  - "?? .mission/evidence/verify-"\n'
    '  - "?? .mission/gates/"\n'
)


def _powershell():
    for cand in ("pwsh", "powershell", "powershell.exe"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (pwsh/powershell) on PATH -- cannot shell the .ps1 CLIs")


def _git():
    path = shutil.which("git")
    if not path:
        pytest.skip("no git on PATH -- A-126 judges `git status --porcelain`")
    return path


def _run(args, cwd=None, timeout=180):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, cwd=cwd)


class Fixture:
    """An isolated scratch mission root plus a copy of the two libraries the gate needs."""

    def __init__(self, tmp, declaration=_DECLARATION):
        self.ps = _powershell()
        self.git = _git()
        self.root = tmp / "scratch-root"
        self.root.mkdir(parents=True, exist_ok=True)

        # mission-lib.ps1 resolves its admitted-porcelain reader as $PSScriptRoot\lam\..., so the
        # copied tree must carry BOTH files in that relationship.
        tools = tmp / "libs"
        (tools / "lam").mkdir(parents=True, exist_ok=True)
        self.lib = tools / "mission-lib.ps1"
        shutil.copy2(_TOOLS / "mission-lib.ps1", self.lib)
        shutil.copy2(_TOOLS / "lam" / "lam-verify-admission.ps1",
                     tools / "lam" / "lam-verify-admission.ps1")

        mission = self.root / ".mission"
        mission.mkdir(parents=True, exist_ok=True)
        (mission / "mission.yaml").write_text(
            "id: SCRATCH-1\nstate: Executing\n" + declaration, encoding="utf-8")

        # TRACKED ANCHORS inside both planes. git collapses a WHOLLY-untracked directory to its
        # shallowest path, so without these the whole evidence plane emits ONE line
        # '?? .mission/evidence/' and no fixture below would have the shape it claims. That
        # collapse is an earlier finding; the fixture must not hide it, and the
        # repository of record has tracked content under both planes.
        self.evidence = mission / "evidence"
        self.gates = mission / "gates"
        for d in (self.evidence, self.gates):
            d.mkdir(parents=True, exist_ok=True)
            (d / "ANCHOR.txt").write_text("tracked\n", encoding="utf-8")
        (self.root / "README.md").write_text("scratch\n", encoding="utf-8")
        self._git("init", "--quiet")
        self.commit()

    def _git(self, *args):
        return _run([self.git, "-C", str(self.root), *args])

    def commit(self, msg="fixture"):
        self._git("add", "-A")
        return _run([self.git, "-C", str(self.root), "-c", "user.email=s@s", "-c", "user.name=s",
                     "commit", "-q", "-m", msg])

    def plant(self, relpath, text="x\n"):
        p = self.root / relpath
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        return p

    def porcelain(self):
        return [l for l in self._git("status", "--porcelain").stdout.splitlines() if l.strip()]

    def judge(self, allow_paths=()):
        argv = [self.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(_DRV),
                "-Lib", str(self.lib), "-Root", str(self.root)]
        if allow_paths:
            argv += ["-AllowPathsCsv", ";".join(allow_paths)]
        return _run(argv)


@pytest.fixture
def fx(tmp_path):
    return Fixture(tmp_path)


def _real_shape(f):
    """A faithful reduction of the real porcelain shape.

    FIDELITY, STATED. The repository of record measured 166 porcelain lines at this HEAD --
    `git -C <repo> status --porcelain` -- of which 112 are '?? .mission/evidence/verify-<id>/',
    54 are '?? .mission/gates/...', and ZERO fall outside those two declared prefixes. This
    reduction keeps the SHAPE that decides the verdict -- both declared prefixes present, every
    line at the '?? ' status, untracked stores appearing as collapsed DIRECTORY lines -- and
    reduces only the COUNT, from 112/54 to 3/2. The predicate is per-line, so the count is not a
    property any branch depends on.
    """
    for i in (1, 2, 3):
        f.plant(".mission/evidence/verify-%04d/report.json" % i)
    for i in (1, 2):
        f.plant(".mission/gates/push-%d.yaml" % i)


def test_real_arc_l2_2_shape_is_clean(fx):
    """Both declared prefixes, at the declared status: nothing is judged."""
    _real_shape(fx)
    lines = fx.porcelain()
    assert len(lines) == 5, lines
    assert all(l.startswith("?? ") for l in lines), lines
    r = fx.judge()
    assert r.returncode == 0, r.stdout + r.stderr
    assert "[PASS]" in r.stdout
    assert "5 porcelain line(s) admitted" in r.stdout


def test_planted_stray_is_refused_and_the_refusal_names_it(fx):
    """ONE stray outside the declaration -- the gate refuses and NAMES the path."""
    _real_shape(fx)
    fx.plant("stray.txt")
    r = fx.judge()
    assert r.returncode == 1, r.stdout + r.stderr
    assert "stray.txt" in r.stdout
    assert "1 porcelain line(s) outside the admitted set" in r.stdout


def test_evidence_path_outside_the_verify_prefix_is_refused(fx):
    """THE NARROWING ITSELF. Inside the evidence plane, outside the declared 'verify-' prefix.

    This is the case the pre-cure code let through: its exemption was the whole plane.
    """
    fx.plant(".mission/evidence/scratch-oops/leak.txt")
    lines = fx.porcelain()
    assert lines == ["?? .mission/evidence/scratch-oops/"], lines
    r = fx.judge()
    assert r.returncode == 1, r.stdout + r.stderr
    assert "scratch-oops" in r.stdout


def test_declared_prefix_at_a_non_untracked_status_is_refused(fx):
    """STATUS-BLINDNESS, CLOSED -- and this test PINS the ruling either way it is read.

    The declaration admits '?? .mission/evidence/verify-': the status code is PART of the
    declared entry. A TRACKED file under that same prefix, MODIFIED, is ' M <path>' and is
    therefore NOT admitted. Pre-cure it passed, because the exemption was tested against the
    path with the XY code already stripped off.
    """
    fx.plant(".mission/evidence/verify-0001/report.json")
    fx.commit("track the verify store")
    fx.plant(".mission/evidence/verify-0001/report.json", "TAMPERED\n")
    lines = fx.porcelain()
    assert len(lines) == 1 and lines[0].startswith(" M "), lines
    r = fx.judge()
    assert r.returncode == 1, r.stdout + r.stderr
    assert "verify-0001/report.json" in r.stdout


def test_evidence_session_directory_is_no_longer_exempt(fx):
    """THE DROPPED D9 EXEMPTION, PINNED.

    '?? .mission/evidence/session-' is NOT in the declaration, so it is judged. That is a
    deliberate decision recorded in mission-lib.ps1: D9's premise ("no CALLER can name the
    session id in advance") is satisfied by a declaration PREFIX just as well as by a code
    pattern, and keeping it in code would reinstate a hole of exactly the shape this narrowing closes.
    A mission that needs it declares it. If that decision is ever reversed, this test is the
    place the reversal has to be argued.
    """
    fx.plant(".mission/evidence/session-abcdef/log.jsonl")
    r = fx.judge()
    assert r.returncode == 1, r.stdout + r.stderr
    assert "session-abcdef" in r.stdout


def test_allowpaths_exempts_exactly_its_named_inputs(fx):
    """-AllowPaths is unchanged: it names PATHS, exempts only those, and still refuses the rest."""
    fx.plant("amendment.md")
    fx.plant("other.md")
    r = fx.judge(allow_paths=["amendment.md"])
    assert r.returncode == 1, r.stdout + r.stderr
    assert "other.md" in r.stdout
    assert "1 porcelain line(s) outside the admitted set" in r.stdout

    r2 = fx.judge(allow_paths=["amendment.md", "other.md"])
    assert r2.returncode == 0, r2.stdout + r2.stderr
    assert "sanctioned input(s): amendment.md, other.md" in r2.stdout


def test_a_mission_with_no_declaration_admits_nothing(tmp_path):
    """FAIL-CLOSED. No admitted_porcelain means no admitted porcelain -- not a code default."""
    f = Fixture(tmp_path, declaration="")
    _real_shape(f)
    r = f.judge()
    assert r.returncode == 1, r.stdout + r.stderr
    assert "this mission declares no admitted_porcelain" in r.stdout
    assert "5 porcelain line(s) outside the admitted set" in r.stdout


def test_a_malformed_declaration_refuses_rather_than_falling_back(tmp_path):
    """FAIL-CLOSED, on the shared library's own rule: honoured exactly or not at all.

    Entries without the '?? ' status prefix are MALFORMED to
    tools/lam/lam-verify-admission.ps1, and A-126 adopts that verdict rather than inventing a
    second reading of the same key.
    """
    f = Fixture(tmp_path, declaration=(
        'admitted_porcelain:\n'
        '  - ".mission/evidence/verify-"\n'
        '  - ".mission/gates/"\n'
    ))
    _real_shape(f)
    r = f.judge()
    assert r.returncode == 1, r.stdout + r.stderr
    assert "MALFORMED admitted_porcelain declaration" in r.stdout
    assert "honoured exactly or not at all" in r.stdout


# =====================================================================================
# THE COMPENSATING-CONTROL CITATION.
# =====================================================================================
# The retired sentence claimed both exempted directories were "agent-unwritable (evidence guard;
# T-3)". It named the wrong tier, and it was the stated justification for the whole exemption --
# so these members re-derive, FROM SOURCE, each fact the rewritten citation asserts. They fail if
# the citation drifts from the guard AND if the guard drifts from the citation, which is the only
# way a comment can be held to anything.

_REPO = Path(__file__).resolve().parents[3]
_SEALED_GUARD = _REPO / "tools" / "framework" / "hooks" / "lib" / "evidence-common.ps1"
_NEXT_GUARD = _REPO / "tools" / "evidence-hooks-next" / "hooks" / "lib" / "evidence-common.ps1"
_MISSION_LIB = _REPO / "tools" / "mission-lib.ps1"
_SETTINGS = _REPO / "tools" / "lam" / "settings"

_RETIRED_SENTENCE = "Both directories are agent-unwritable (evidence guard; T-3)"


def _read(p):
    if not p.exists():
        pytest.skip("%s is not present in this checkout" % p)
    return p.read_text(encoding="utf-8", errors="replace")


def _ps_array(text, name):
    """Pull the string entries out of a `$script:<name> = @( ... )` literal."""
    head = "$script:%s = @(" % name
    i = text.index(head) + len(head)
    j = text.index(")", i)
    body = text[i:j]
    return [s.strip().strip("'").strip('"') for s in body.split(",") if s.strip()]


def test_the_premise_of_row_173_the_gates_directory_is_not_on_the_protected_tier():
    """THE FACT THE RETIRED SENTENCE GOT WRONG, re-derived rather than quoted.

    `.mission/evidence` IS on the sealed guard's protected tier -- half the sentence was true.
    `.mission/gates` is NOT, and only `.mission` (the PARENT tier, which denies for a shell
    metacharacter or a destructive verb, not for writing inside) covers it there.
    """
    src = _read(_SEALED_GUARD)
    protected = _ps_array(src, "EvidenceProtectedPaths")
    parents = _ps_array(src, "EvidenceParentPaths")
    assert ".mission/evidence" in protected, protected
    assert ".mission-runtime/evidence" in protected, protected
    assert ".mission/gates" not in protected, (
        "the protected tier now lists .mission/gates -- the citation in mission-lib.ps1 "
        "says it does not, and one of the two has to move")
    assert ".mission" in parents, parents


def test_every_route_the_citation_names_exists_in_source():
    """The three guard routes and the permission route, each located where the citation says."""
    nxt = _read(_NEXT_GUARD)
    assert "function Test-EvidenceGatePath" in nxt
    # the text-match route reaches BOTH the file tools and the shell
    assert nxt.count("Test-EvidenceGatePath -Path") >= 2, nxt.count("Test-EvidenceGatePath -Path")
    # the tripwire: the ACT deny, which fires on a command naming no gates path at all
    assert "function Test-EvidenceGateToolMutation" in nxt
    assert "Test-EvidenceGateToolMutation -Command" in nxt

    worker = _read(_SETTINGS / "worker.json")
    orch = _read(_SETTINGS / "orchestrator.json")
    validator = _read(_SETTINGS / "validator.json")
    assert "Edit(.mission/gates/**)" in worker
    assert "Edit(.mission/gates/**)" in orch
    # STATED, NOT GLOSSED: the permission route covers two of the three role templates. The
    # register's own wording said `Write(.mission/gates/**)`, a spelling worker.json itself
    # records as inert on CLI 2.1.241; nothing in the tree carries it.
    assert "gates" not in validator, (
        "validator.json has grown a gates rule -- the citation says it has none")
    for f in (worker, orch, validator):
        assert "Write(.mission/gates/**)" not in f


def test_the_citation_names_routes_and_no_longer_names_the_wrong_tier():
    """The comment itself. This is the member the planted revert flips."""
    lib = _read(_MISSION_LIB)
    assert _RETIRED_SENTENCE not in lib, (
        "the retired sentence is back in mission-lib.ps1: it names the protected-path "
        "tier for .mission/gates, which does not cover it")
    assert "REGISTER ROW 173" in lib
    for cited in (
        "Test-EvidenceGatePath",
        "Test-EvidenceGateToolMutation",
        "tools/lam/settings/worker.json",
        "tools/lam/settings/orchestrator.json",
        "tools/lam/settings/validator.json",
        "tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1",
        "tools/framework/hooks/lib/evidence-common.ps1",
        "REGISTER ROW 165",
    ):
        assert cited in lib, "the citation no longer names %s" % cited
