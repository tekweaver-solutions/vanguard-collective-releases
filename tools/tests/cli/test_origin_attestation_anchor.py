"""The ORIGIN-ATTESTATION ANCHOR (tools/lam/record-origin-attestation.ps1).

The register's row recorded that mission-verify's ORIGIN-ATTESTATION arm never engaged on
`runner_anchors.origin_tip`. That schema half has since been discharged:
schemas SS5 now declares the member optional. THAT HALF IS NOT WHAT THIS MODULE DRIVES -- the
anchors schema and verify's admission library belong to another batch. What it drives is the cure the
operator ruled instead: a tool that turns the push annotation's three prose readings into FIELDS OF
ONE ARTIFACT, each carrying whose reading it is.

HERMETIC, WITHOUT EXCEPTION. No test here reaches a network. `origin` is a local bare repository
created inside the sandbox with `git init --bare` (the WP-4 instrument's own device), the push gate
is HAND-WRITTEN in a SCRATCH mission root under tmp_path, and the real .mission is never read or
written by anything in this file. The `gh api` leg is exercised only through the operator-supplied
form, which contacts nothing; the tool's own `-WithGhApi` switch is deliberately never passed.

THE DIRECTION EACH CASE COVERS is named in its docstring: acceptance cases assert the artifact is
written and correct, refusal cases assert the tool refuses rather than crashing and says why.
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]                       # repo/tools
_TOOL_SRC = _TOOLS / "lam" / "record-origin-attestation.ps1"

BROWSER_NOT_ATTESTED = (
    "NOT ATTESTED -- no operator browser attestation was supplied to this tool, "
    "and this tool cannot take one."
)


def _powershell():
    for cand in ("pwsh", "powershell", "powershell.exe"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (pwsh/powershell) on PATH -- cannot shell the .ps1 CLI")


def _git():
    path = shutil.which("git")
    if not path:
        pytest.skip("no git on PATH -- the sandbox origin cannot be built")
    return path


def _run(args, cwd=None, timeout=180):
    env = dict(os.environ)
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                          cwd=str(cwd) if cwd else None, env=env)


class Sandbox:
    """A scratch mission root, a local bare `origin`, and a copy of the tool under test."""

    def __init__(self, tmp_path):
        self.root = tmp_path / "sandbox"
        self.root.mkdir(parents=True, exist_ok=True)
        self.ps = _powershell()
        self.git = _git()

        # The tool, copied -- the house pattern: never invoke the checked-out file in place.
        tools_lam = self.root / "tools" / "lam"
        tools_lam.mkdir(parents=True, exist_ok=True)
        self.tool = tools_lam / "record-origin-attestation.ps1"
        shutil.copy2(_TOOL_SRC, self.tool)

        # The SCRATCH mission root. Nothing here is a real gate and nothing here is the real plane.
        self.gates_dir = self.root / ".mission" / "gates"
        self.gates_dir.mkdir(parents=True, exist_ok=True)

        # `origin`, standing in for the remote, entirely inside the sandbox.
        self.origin = tmp_path / "origin.git"
        assert _run([self.git, "init", "--bare", "--initial-branch=main", str(self.origin)]).returncode == 0

        work = tmp_path / "work"
        work.mkdir()
        assert _run([self.git, "init", "--initial-branch=main", "."], cwd=work).returncode == 0
        _run([self.git, "config", "user.email", "row111@example.invalid"], cwd=work)
        _run([self.git, "config", "user.name", "row111"], cwd=work)
        (work / "seed.txt").write_text("row 111 fixture\n", encoding="utf-8")
        assert _run([self.git, "add", "seed.txt"], cwd=work).returncode == 0
        assert _run([self.git, "commit", "-m", "fixture seed"], cwd=work).returncode == 0
        assert _run([self.git, "push", str(self.origin), "main"], cwd=work).returncode == 0
        head = _run([self.git, "rev-parse", "HEAD"], cwd=work)
        assert head.returncode == 0
        self.tip = head.stdout.strip()
        self.work = work

    # -- fixture gates -------------------------------------------------------------------
    def write_gate(self, gate_id, tip=None, origin_url="<default>", remote_ref="refs/heads/main",
                   kind="push"):
        if tip is None:
            tip = self.tip
        if origin_url == "<default>":
            origin_url = str(self.origin)
        lines = [
            "# Gate artifact -- HAND-WRITTEN FIXTURE in a scratch mission root. Not a real gate.",
            "kind: %s" % kind,
            "gate_class: build-authorization",
            "id: %s" % gate_id,
            "push_id: push-%s" % gate_id,
            "binds: .mission\\amendments\\AM-000-fixture.yaml",
            "binds_sha256: " + ("0" * 64),
        ]
        if tip is not None:
            lines.append("authorized_tip_sha: %s" % tip)
        if origin_url is not None:
            lines.append("origin_url: %s" % origin_url)
        if remote_ref is not None:
            lines.append("remote_ref: %s" % remote_ref)
        lines += [
            'origin_binding_note: "Amendment 20: consumers read THIS url, never remote.origin.url."',
            "authorized_by: fixture",
            "host: FIXTURE",
            "created_at: 2026-09-11T12:01:32.332Z",
            "expires_at: 2026-09-11T13:01:32.332Z",
            "single_use: true",
        ]
        p = self.gates_dir / ("push-%s.yaml" % gate_id)
        p.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return p

    # -- driving the tool ----------------------------------------------------------------
    def record(self, gate_id, *extra):
        args = [self.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(self.tool),
                "-PushGateId", gate_id, "-MissionRoot", str(self.root)]
        args.extend(extra)
        return _run(args)

    def anchor_path(self, gate_id):
        return (self.root / ".mission-runtime" / "origin-attestations"
                / ("origin-attestation-%s.yaml" % gate_id))


@pytest.fixture
def sandbox(tmp_path):
    return Sandbox(tmp_path)


# -----------------------------------------------------------------------------------------
# small readers over the produced artifact
# -----------------------------------------------------------------------------------------
def _block_field(text, block, field):
    """Value of `field` inside the 4-space `block:` under `readings:`, unquoted."""
    lines = text.splitlines()
    want_block = "  %s:" % block
    for i, line in enumerate(lines):
        if line.rstrip() == want_block:
            for j in range(i + 1, len(lines)):
                nxt = lines[j]
                if nxt.strip() == "" or nxt.lstrip().startswith("#"):
                    continue
                indent = len(nxt) - len(nxt.lstrip())
                if indent <= 2:
                    break
                key = "    %s: " % field
                if nxt.startswith(key):
                    v = nxt[len(key):].strip()
                    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
                        v = v[1:-1]
                    return v
    return None


# =========================================================================================
# ACCEPTANCE
# =========================================================================================
def test_acceptance_all_three_readings_are_fields_each_with_its_provenance(sandbox):
    """ACCEPTANCE. Gate present, the declared origin holds the authorized tip, and the operator
    supplied both of their own readings -> the anchor is written and carries all three readings as
    FIELDS, each stating WHOSE reading it is. This is the whole point of the artifact: the prose of
    the push annotation becomes something a consumer can read without parsing English."""
    sandbox.write_gate("row111-accept")
    r = sandbox.record(
        "row111-accept",
        "-GhReading", sandbox.tip,
        "-GhReadingBy", "fixture-operator, at the terminal",
        "-BrowserAttestation", "origin/main = %s at /commit/%s" % (sandbox.tip, sandbox.tip[:8]),
        "-BrowserAttestedBy", "fixture-operator",
        "-BrowserAttestedAt", "2026-09-11T12:06Z",
    )
    assert r.returncode == 0, "stdout:\n%s\nstderr:\n%s" % (r.stdout, r.stderr)

    p = sandbox.anchor_path("row111-accept")
    assert p.is_file(), "no anchor at %s; stdout:\n%s" % (p, r.stdout)
    text = p.read_text(encoding="utf-8")

    # (i) the tool's own, taken against the GATE'S declared origin.
    assert _block_field(text, "ls_remote", "reading") == sandbox.tip
    assert "TAKEN HERE" in _block_field(text, "ls_remote", "provenance")
    assert "DECLARED ON THE PUSH GATE" in _block_field(text, "ls_remote", "provenance")
    assert str(sandbox.origin) in _block_field(text, "ls_remote", "command")

    # (ii) the operator's, recorded as theirs and not re-taken.
    assert _block_field(text, "gh_api", "reading") == sandbox.tip
    assert _block_field(text, "gh_api", "taken_by").startswith("THE OPERATOR")
    assert "ATTESTED, NOT TAKEN HERE" in _block_field(text, "gh_api", "provenance")

    # (iii) the operator's, verbatim.
    assert sandbox.tip in _block_field(text, "browser", "reading")
    assert _block_field(text, "browser", "attested_by") == "THE OPERATOR: fixture-operator"
    assert _block_field(text, "browser", "attested_at") == "2026-09-11T12:06Z"
    assert "ATTESTED BY THE OPERATOR AND RECORDED VERBATIM" in _block_field(text, "browser", "provenance")

    # every reading carries a provenance, and none of them is empty.
    for block in ("ls_remote", "gh_api", "browser"):
        prov = _block_field(text, block, "provenance")
        assert prov and len(prov) > 30, "%s carries no provenance: %r" % (block, prov)

    # the gate is cited by hash, and the origin URL's source is named.
    assert "  sha256: " in text
    assert "never remote.origin.url" in text


def test_acceptance_records_the_place_it_is_not(sandbox):
    """ACCEPTANCE. The artifact declares on its own face that it is neither a gate nor
    evidence-plane material, and it lands in the runtime plane by default -- not under
    .mission/gates (which authorizes) and not under .mission/evidence (which hooks write)."""
    sandbox.write_gate("row111-place")
    r = sandbox.record("row111-place")
    assert r.returncode == 0, r.stdout

    p = sandbox.anchor_path("row111-place")
    assert p.is_file()
    assert ".mission-runtime" in str(p)
    text = p.read_text(encoding="utf-8")
    assert "THIS IS NOT A GATE" in text
    assert "THIS IS NOT EVIDENCE-PLANE MATERIAL" in text
    # and it does not pretend to be the schema field the register row's other half names -- a field
    # schemas SS5 now declares optional, so the old "no schema
    # declares" sentence is false and must not come back.
    assert "THIS IS NOT runner_anchors.origin_tip" in text
    assert "schemas SS5 :462 declares that member optional" in text
    assert "no schema declares" not in text.lower()

    # nothing was written under the scratch gates directory or any evidence directory.
    assert sorted(q.name for q in sandbox.gates_dir.iterdir()) == ["push-row111-place.yaml"]
    assert not (sandbox.root / ".mission" / "evidence").exists()


def test_acceptance_output_path_is_the_operators_choice(sandbox):
    """ACCEPTANCE. The location is a parameter: the operator decides where an arc's anchor lives,
    and the tool creates the directory rather than refusing on a missing parent."""
    sandbox.write_gate("row111-outpath")
    dest = sandbox.root / "chosen" / "deeper" / "anchor.yaml"
    r = sandbox.record("row111-outpath", "-OutputPath", str(dest))
    assert r.returncode == 0, r.stdout
    assert dest.is_file()
    assert not sandbox.anchor_path("row111-outpath").exists()


# =========================================================================================
# CONTROL / ACCEPTANCE -- the un-authored slot
# =========================================================================================
def test_control_no_browser_attestation_still_writes_and_the_slot_says_not_attested(sandbox):
    """CONTROL, AND ACCEPTANCE. With no browser attestation supplied the anchor is STILL written --
    a missing operator leg does not make the tool's own reading unrecordable -- and the browser
    field reads the exact 'not attested' text and nothing else. A visibly empty slot is the record;
    an absent field would let a later reader mistake silence for a reading that was simply not
    transcribed."""
    sandbox.write_gate("row111-nobrowser")
    r = sandbox.record("row111-nobrowser")
    assert r.returncode == 0, r.stdout

    p = sandbox.anchor_path("row111-nobrowser")
    assert p.is_file()
    text = p.read_text(encoding="utf-8")

    assert _block_field(text, "browser", "reading") == BROWSER_NOT_ATTESTED
    assert _block_field(text, "browser", "attested_by") == "(none)"
    assert _block_field(text, "browser", "attested_at") == "(none)"
    assert "THE OPERATOR'S OR NOBODY'S" in _block_field(text, "browser", "provenance")

    # the tool's own reading is still there and still correct.
    assert _block_field(text, "ls_remote", "reading") == sandbox.tip
    # and the gh leg, unasked-for, says so rather than being absent.
    assert _block_field(text, "gh_api", "reading").startswith("NOT TAKEN")


# =========================================================================================
# THE KILL -- no input can author a browser attestation
# =========================================================================================
@pytest.mark.parametrize(
    "label,extra",
    [
        ("nothing supplied at all", []),
        ("an ls-remote agreeing with the tip is not a browser reading", []),
        ("a gh reading supplied, agreeing", ["-GhReading", "<TIP>", "-GhReadingBy", "the operator"]),
        ("both other legs agreeing", ["-GhReading", "<TIP>", "-GhReadingBy", "the operator"]),
        ("browser metadata WITHOUT a reading", ["-BrowserAttestedBy", "fixture-operator",
                                                "-BrowserAttestedAt", "2026-09-11T12:06Z"]),
        ("an empty browser attestation", ["-BrowserAttestation", ""]),
        ("a whitespace browser attestation", ["-BrowserAttestation", "   "]),
        ("gh agreeing AND browser metadata", ["-GhReading", "<TIP>", "-GhReadingBy", "the operator",
                                              "-BrowserAttestedBy", "fixture-operator"]),
    ],
)
def test_kill_nothing_but_an_explicit_attestation_fills_the_browser_slot(sandbox, label, extra):
    """THE KILL. Drive every obvious route by which a browser reading might get manufactured --
    an ls-remote that agrees with the authorized tip, a gh reading supplied and agreeing, both
    agreeing at once, the attestation's metadata supplied without the attestation itself, and an
    empty or whitespace attestation -- and assert the browser field still reads exactly
    'not attested'. Two channels agreeing is still two channels; a tool that wrote a third leg
    because the first two agreed would be manufacturing the one reading the standing keeps
    separate, and the artifact would claim three independent readings while holding one."""
    slug = "".join(c if c.isalnum() else "-" for c in label)[:48].strip("-")
    gate_id = "row111-kill-%s" % slug
    sandbox.write_gate(gate_id)
    args = [a.replace("<TIP>", sandbox.tip) for a in extra]
    r = sandbox.record(gate_id, *args)
    assert r.returncode == 0, "%s -- stdout:\n%s\nstderr:\n%s" % (label, r.stdout, r.stderr)

    text = sandbox.anchor_path(gate_id).read_text(encoding="utf-8")
    assert _block_field(text, "browser", "reading") == BROWSER_NOT_ATTESTED, label
    # and the tip never leaks into the browser slot by any route.
    assert sandbox.tip not in _block_field(text, "browser", "reading"), label
    assert sandbox.tip not in _block_field(text, "browser", "attested_by"), label
    assert _block_field(text, "browser", "attested_by") == "(none)", label


def test_kill_the_tool_has_exactly_one_writer_of_the_browser_slot(sandbox):
    """THE KILL, STRUCTURALLY. Read the tool's own source and assert that `$browserReading` is
    assigned on exactly two lines: the un-authored default and the one branch guarded by
    `-BrowserAttestation`. A future edit that defaults the slot from any other value has to add a
    third assignment, and this member fails the moment it does."""
    import re

    src = _TOOL_SRC.read_text(encoding="utf-8").splitlines()
    # Anywhere on a line, not only at its start: an assignment tucked after `if (...) {` is exactly
    # how such an edit arrives, and a start-of-line check would sail past it.
    assigns = [ln.strip() for ln in src
               if re.search(r"\$browserReading\s*=[^=]", ln) and not ln.strip().startswith("#")]
    assert len(assigns) == 2, "browser slot writers: %r" % (assigns,)
    assert assigns[0].startswith("$browserReading  = $BROWSER_NOT_ATTESTED")
    assert assigns[1] == "$browserReading = $BrowserAttestation.Trim()"
    # and the second one is inside the -BrowserAttestation guard, not merely after it.
    guard = [i for i, ln in enumerate(src)
             if "if (-not [string]::IsNullOrWhiteSpace($BrowserAttestation))" in ln]
    assert len(guard) == 1
    target = [i for i, ln in enumerate(src) if ln.strip() == "$browserReading = $BrowserAttestation.Trim()"]
    assert len(target) == 1 and target[0] == guard[0] + 1


# =========================================================================================
# REFUSALS
# =========================================================================================
def test_refusal_remote_tip_differs_from_the_gates_authorized_tip_prints_both(sandbox):
    """REFUSAL. The declared origin does not hold the gate's authorized tip -> refuse, printing
    BOTH figures and preferring neither. Writing an anchor here would assert an agreement that is
    not there; choosing a winner would be the tiebreak the second reading exists to prevent."""
    bogus = "1" * 40
    sandbox.write_gate("row111-diverged", tip=bogus)
    r = sandbox.record("row111-diverged")
    assert r.returncode == 3, "stdout:\n%s" % r.stdout
    assert "does NOT hold the authorized tip" in r.stdout
    assert bogus in r.stdout, "the gate's figure is not printed"
    assert sandbox.tip in r.stdout, "the remote's figure is not printed"
    assert "UNHANDLED ERROR" not in r.stdout, "a CRASH is not a refusal (E112/E105)"
    assert not sandbox.anchor_path("row111-diverged").exists()


def test_refusal_push_gate_absent(sandbox):
    """REFUSAL. No gate at the named id -> refuse. An origin reading with no authorization beside
    it records what origin holds and nothing about whether it was allowed to hold it."""
    r = sandbox.record("row111-nosuchgate")
    assert r.returncode == 2, "stdout:\n%s" % r.stdout
    assert "ABSENT" in r.stdout
    assert "push-row111-nosuchgate.yaml" in r.stdout
    assert "UNHANDLED ERROR" not in r.stdout
    assert not sandbox.anchor_path("row111-nosuchgate").exists()


def test_refusal_gate_declares_no_origin_url(sandbox):
    """REFUSAL. The gate declares no origin_url -> refuse, and do NOT fall back to
    remote.origin.url. The design rules .git/config an unprotectable control surface; a consumer
    that reads it is reading the attacker's own configuration and calling it evidence."""
    sandbox.write_gate("row111-nourl", origin_url=None)
    r = sandbox.record("row111-nourl")
    assert r.returncode == 2, "stdout:\n%s" % r.stdout
    assert "NO origin_url" in r.stdout
    assert "remote.origin.url" in r.stdout
    assert "UNHANDLED ERROR" not in r.stdout
    assert not sandbox.anchor_path("row111-nourl").exists()


def test_refusal_gate_declares_no_remote_ref(sandbox):
    """REFUSAL. The ref is the other third of the origin-binding triple; guessing refs/heads/main would
    be the tool inventing the question it then answers."""
    sandbox.write_gate("row111-noref", remote_ref=None)
    r = sandbox.record("row111-noref")
    assert r.returncode == 2, "stdout:\n%s" % r.stdout
    assert "no remote_ref" in r.stdout
    assert not sandbox.anchor_path("row111-noref").exists()


def test_refusal_artifact_is_not_a_push_gate(sandbox):
    """REFUSAL. Only a push gate carries the declared triple; any other kind authorizes something
    else and has no origin to be read against."""
    sandbox.write_gate("row111-wrongkind", kind="amendment-material")
    r = sandbox.record("row111-wrongkind")
    assert r.returncode == 2, "stdout:\n%s" % r.stdout
    assert "not a PUSH gate" in r.stdout
    assert not sandbox.anchor_path("row111-wrongkind").exists()


def test_refusal_declared_origin_gives_no_reading(sandbox):
    """REFUSAL. The declared origin cannot be asked (here: a path that is not a repository) ->
    refuse with the command and its exit code. `git ls-remote` conflates unreachable with absent,
    so neither is claimed -- silence is not consent, and no anchor is written on a reading nobody
    took."""
    dead = sandbox.root / "not-a-repo"
    dead.mkdir()
    sandbox.write_gate("row111-silent", origin_url=str(dead))
    r = sandbox.record("row111-silent")
    assert r.returncode == 4, "stdout:\n%s" % r.stdout
    assert "no reading for that ref" in r.stdout
    assert "exit_code" in r.stdout
    assert "UNHANDLED ERROR" not in r.stdout
    assert not sandbox.anchor_path("row111-silent").exists()


def test_refusal_existing_anchor_is_not_overwritten_without_force(sandbox):
    """REFUSAL, then acceptance under -Force. Silently replacing a record of what origin held at a
    moment is how a superseded reading comes back wearing the current one's name."""
    sandbox.write_gate("row111-exists")
    assert sandbox.record("row111-exists").returncode == 0
    again = sandbox.record("row111-exists")
    assert again.returncode == 2, "stdout:\n%s" % again.stdout
    assert "already exists" in again.stdout
    forced = sandbox.record("row111-exists", "-Force")
    assert forced.returncode == 0, forced.stdout


def test_refusal_no_gate_named_at_all(sandbox):
    """REFUSAL. Neither -PushGateId nor -PushGatePath -> refuse rather than default to something."""
    r = _run([sandbox.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(sandbox.tool),
              "-MissionRoot", str(sandbox.root)])
    assert r.returncode == 2, "stdout:\n%s" % r.stdout
    assert "no push gate named" in r.stdout.lower()
