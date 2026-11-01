"""THE CURE -- the two rewrites in
tools/mission-reclose.ps1 keep a CR LF mission.yaml's carriage returns.

THE DEFECT. :243 rewrites `state: Reworking` and :245 rewrites `completed_at:`, each with a pattern ending `\\s*$`
under (?m). In .NET `$` matches before a `\\n` and `\\s` matches `\\r`, so the match ends AFTER the line's CR and the
replacement writes the line back without it: a CR LF mission.yaml reads CR = LF - 2 after a re-closure (each
re-closure drops the CR of the two lines it rewrites). The cure keeps the CR outside the match, `\\s*?(?=\\r?$)`, and
leaves the two guards (:185 and :241) as they are: wherever `\\s*$` matches from a position, the lazy form matches
from the same one, so a guard and its rewrite still agree on every line.

WHY THIS HOME. The framework suite is the green gate's own suite (.mission/green-gate/framework.json: cwd tools),
the gate mission-reclose runs before every re-closure. A CLI regression guard belongs here, beside
test_close_milestone_lam_roster.py, whose isolation form this file follows. tests/lam/instrument-WP-4.ps1 T-20 drives
the script's pre-mutation gates and stops before the rewrite; this file drives the rewrite and nothing else.

WHY AN AST LIFT AND NOT THE WHOLE SCRIPT. Before :243 the script runs six gates, and its green gate runs
`uv run python -m pytest` in the mission root's suite folders -- a nested pytest inside this suite, in front of every
re-closure. So this file LIFTS the read (:183-:185) and the rewrite (:226-:246) out of the REAL script by their line
extents and runs exactly those statements in a child PowerShell, with the helpers of the tree's own mission-lib.ps1.
The lift REFUSES when the rewrite extent no longer holds the two [regex]::Replace statements (or the read and the write
are not where the extents say), so a moved line cannot leave this file green over nothing.

TWO SUBJECTS. THE BASE, the defect's subject whose reading is the RED (CR = LF - 2), is a blob of the project the
framework was extracted from; it is not carried, BASE_BLOB and BASE_SHA256 hold null ids, so the RED leg skips. THE
TREE is this checkout's file: the cure's subject (CR == LF).

NOTHING HERE TOUCHES THE REAL MISSION PLANE. Every mission.yaml, script copy and repository lives in pytest's
tmp_path; the real script, the tree's mission-lib.ps1 and the base blob are only read.
"""

import hashlib
import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]              # repo/tools
_REPO = _TOOLS.parent                                     # repo root (this checkout)
_RECLOSE = _TOOLS / "mission-reclose.ps1"
_LIB = _TOOLS / "mission-lib.ps1"

BASE_BLOB = "0000000000000000000000000000000000000000"
BASE_SHA256 = "0000000000000000000000000000000000000000000000000000000000000000"

READ_EXTENT = (183, 185)        # $text = ReadAllText; $eol; the completed_at guard
REWRITE_EXTENT = (226, 246)     # $now ... the two Replace statements ... WriteAllText
BLOCK_LINES = 8                 # the RE-CLOSURE block the rewrite inserts ($blk, :228-:237)

# The child. It parses the subject, selects the top-level statements inside the two extents, refuses unless they are
# the statements this file means, then dot-sources the tree's mission-lib.ps1 and runs them over -MissionFile.
HARNESS = r"""param([string]$Subject, [string]$Lib, [string]$MissionFile,
      [int]$ReadFirst, [int]$ReadLast, [int]$RewriteFirst, [int]$RewriteLast)
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Subject, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) { Write-Output ('LIFT REFUSED: the subject does not parse: ' + $errors[0].Message); exit 3 }
$stmts = @($ast.EndBlock.Statements)
$read = @($stmts | Where-Object { ($_.Extent.StartLineNumber -ge $ReadFirst) -and ($_.Extent.EndLineNumber -le $ReadLast) })
$rewrite = @($stmts | Where-Object { ($_.Extent.StartLineNumber -ge $RewriteFirst) -and ($_.Extent.EndLineNumber -le $RewriteLast) })
$replaces = @($rewrite | Where-Object { $_.Extent.Text -match '^\$text = \[regex\]::Replace\(\$text, ' })
$reads = @($read | Where-Object { $_.Extent.Text -match '^\$text = \[System\.IO\.File\]::ReadAllText\(\$missionFile\)$' })
$writes = @($rewrite | Where-Object { $_.Extent.Text -match '^\[System\.IO\.File\]::WriteAllText\(\$missionFile, \$text\)$' })
if ($replaces.Count -ne 2) {
    Write-Output ('LIFT REFUSED: lines ' + $RewriteFirst + '-' + $RewriteLast + ' hold ' + $replaces.Count + ' [regex]::Replace statement(s) over $text, not 2')
    exit 3
}
if (($reads.Count -ne 1) -or ($writes.Count -ne 1)) {
    Write-Output ('LIFT REFUSED: the read (' + $reads.Count + ') or the write (' + $writes.Count + ') is not where the extents say')
    exit 3
}
foreach ($s in @($read + $rewrite)) { Write-Output ('LIFTED :' + $s.Extent.StartLineNumber + '-' + $s.Extent.EndLineNumber) }
. $Lib
$missionFile = $MissionFile
$reN = 52
$Basis = 'reclose fixture'
$LedgerId = 'ledger-reclose-fixture'
$priorCompleted = '2026-01-01T00:00:00Z'
$lifted = (@($read + $rewrite) | ForEach-Object { $_.Extent.Text }) -join "`n"
. ([scriptblock]::Create($lifted))
Write-Output 'REWRITE DONE'
exit 0
"""

CRLF = b"\r\n"
MAIN_LINES = [
    b"id: FIXTURE-RECLOSE",
    b"state: Reworking",
    b"completed_at: 2026-01-01T00:00:00Z",
    b"current_spec_version: v010",
    b"#",
    b"# --- RE-CLOSURE #51 (2026-01-01) -- per ADR-029 Reworking -> Complete ---",
    b"# a sealed block, preserved unchanged",
]


def _crlf(lines):
    return CRLF.join(lines) + CRLF


def _powershell():
    for cand in ("powershell", "powershell.exe", "pwsh"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (powershell/pwsh) on PATH -- cannot run the lifted statements")


def _git(*args, cwd=None):
    return subprocess.run(["git"] + list(args), cwd=cwd, capture_output=True)


def _sha(b):
    return hashlib.sha256(b).hexdigest()


def _base_subject(tmp):
    """The base blob, read by git cat-file out of this checkout's object store and pinned by sha256; it skips
    where the store does not hold it, as no carried checkout does."""
    if not shutil.which("git"):
        pytest.skip("no git on PATH -- cannot read the base blob")
    got = _git("-C", str(_REPO), "cat-file", "blob", BASE_BLOB)
    if got.returncode != 0:
        pytest.skip("the base blob %s is not carried (a blob of the project the framework was extracted from) -- "
                    "the RED subject cannot be read" % BASE_BLOB)
    assert _sha(got.stdout) == BASE_SHA256, "the base blob's bytes moved: sha256 %s, pinned %s" % (_sha(got.stdout), BASE_SHA256)
    path = tmp / "base" / "mission-reclose.ps1"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(got.stdout)
    return path


def _rewrite(tmp, subject, mission_bytes, name):
    """Run the lifted read and rewrite of SUBJECT over a mission.yaml holding MISSION_BYTES. Returns (rc, out, bytes)."""
    ps = _powershell()
    root = tmp / name
    (root / ".mission").mkdir(parents=True, exist_ok=True)
    mission = root / ".mission" / "mission.yaml"
    mission.write_bytes(mission_bytes)
    harness = tmp / "lift-harness.ps1"
    harness.write_text(HARNESS, encoding="utf-8")
    cp = subprocess.run(
        [ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(harness),
         "-Subject", str(subject), "-Lib", str(_LIB), "-MissionFile", str(mission),
         "-ReadFirst", str(READ_EXTENT[0]), "-ReadLast", str(READ_EXTENT[1]),
         "-RewriteFirst", str(REWRITE_EXTENT[0]), "-RewriteLast", str(REWRITE_EXTENT[1])],
        capture_output=True, timeout=120)
    out = (cp.stdout + cp.stderr).decode("utf-8", "replace")
    return cp.returncode, out, mission.read_bytes()


def _counts(b):
    return b.count(b"\r"), b.count(b"\n")


def test_the_base_subject_is_the_pinned_blob(tmp_path):
    path = _base_subject(tmp_path)
    assert _sha(path.read_bytes()) == BASE_SHA256


def test_the_lift_refuses_when_the_extents_move(tmp_path):
    # Two lines added above the extents move every statement two lines down: the rewrite extent then holds one
    # Replace, not two, and the lift must refuse rather than run whatever now sits there.
    moved = tmp_path / "moved" / "mission-reclose.ps1"
    moved.parent.mkdir(parents=True, exist_ok=True)
    moved.write_bytes(b"# moved\r\n# moved\r\n" + _RECLOSE.read_bytes())
    before = _crlf(MAIN_LINES)
    rc, out, after = _rewrite(tmp_path, moved, before, "moved-root")
    assert rc == 3, out
    assert "LIFT REFUSED" in out, out
    assert after == before, "a refused lift wrote the mission file"


def test_the_base_subject_reads_the_defect(tmp_path):
    # THE RED READING: the base drops the CR of the two lines it rewrites.
    rc, out, after = _rewrite(tmp_path, _base_subject(tmp_path), _crlf(MAIN_LINES), "base-root")
    assert rc == 0, out
    cr, lf = _counts(after)
    assert lf == len(MAIN_LINES) + BLOCK_LINES, (cr, lf, out)
    assert cr == lf - 2, "the base subject was expected to read CR = LF - 2; it read CR %d / LF %d" % (cr, lf)


def test_the_tree_keeps_every_cr(tmp_path):
    rc, out, after = _rewrite(tmp_path, _RECLOSE, _crlf(MAIN_LINES), "tree-root")
    assert rc == 0, out
    cr, lf = _counts(after)
    assert lf == len(MAIN_LINES) + BLOCK_LINES, (cr, lf, out)
    assert cr == lf, "after the rewrite the tree's mission.yaml reads CR %d / LF %d (the defect reads CR = LF - 2)" % (cr, lf)
    assert b"\r\nstate: Complete\r\n" in after
    assert b"\r\ncompleted_at: " in after and b"state: Reworking" not in after


def test_the_tree_keeps_a_blank_line_after_the_state_line(tmp_path):
    lines = [MAIN_LINES[0], b"state: Reworking", b"", b"completed_at: 2026-01-01T00:00:00Z", b"#"]
    rc, out, after = _rewrite(tmp_path, _RECLOSE, _crlf(lines), "blank-root")
    assert rc == 0, out
    assert b"state: Complete\r\n\r\ncompleted_at: " in after, after


def test_the_tree_transitions_an_lf_only_state_line(tmp_path):
    # mission-reopen's own rewrite leaves its `state: Reworking` line LF-only on a CR LF file (the sibling of this
    # cure, tools/mission-reopen.ps1 :60/:63): the cured pattern must still find it, and the guard at :241 still does.
    mixed = CRLF.join([MAIN_LINES[0], b"state: Reworking\ncompleted_at: 2026-01-01T00:00:00Z"] + MAIN_LINES[3:]) + CRLF
    rc, out, after = _rewrite(tmp_path, _RECLOSE, mixed, "lf-root")
    assert rc == 0, out
    assert b"state: Complete\n" in after and b"state: Reworking" not in after, after


def test_the_staged_blob_is_lf_only_and_unaffected(tmp_path):
    # THE COMMITTED BYTES. Under core.autocrlf=true the index holds LF only, so the defect never reached a commit and
    # the cure moves no committed byte: the tree's output and the base's output stage to the SAME blob.
    rc_t, out_t, tree_after = _rewrite(tmp_path, _RECLOSE, _crlf(MAIN_LINES), "stage-tree")
    rc_b, out_b, base_after = _rewrite(tmp_path, _base_subject(tmp_path), _crlf(MAIN_LINES), "stage-base")
    assert rc_t == 0 and rc_b == 0, out_t + out_b
    # Each run stamps its own clock ($now) into completed_at and into the block (the full stamp and its date), so the
    # base's stamp is replaced by the tree's before staging: what remains different is the line endings alone.
    def _now(body):
        return [l for l in body.split(b"\n") if l.startswith(b"completed_at: ")][0][len(b"completed_at: "):].rstrip(b"\r")
    tree_now, base_now = _now(tree_after), _now(base_after)
    base_after = base_after.replace(base_now, tree_now).replace(base_now[:10], tree_now[:10])
    repo = tmp_path / "stage-repo"
    repo.mkdir()
    assert _git("init", "--quiet", str(repo)).returncode == 0
    # ASSERT THE GIT DIR BEFORE ANY git config: it must resolve inside the fixture.
    gd = _git("-C", str(repo), "rev-parse", "--absolute-git-dir").stdout.decode().strip()
    assert Path(gd).resolve().is_relative_to(repo.resolve()), gd
    for key, value in (("core.autocrlf", "true"), ("core.safecrlf", "false"),
                       ("user.email", "reclose@fixture.invalid"), ("user.name", "reclose fixture")):
        assert _git("-C", str(repo), "config", key, value).returncode == 0
    target = repo / ".mission" / "mission.yaml"
    target.parent.mkdir(parents=True)
    blobs = {}
    for name, body in (("tree", tree_after), ("base", base_after)):
        target.write_bytes(body)
        assert _git("-C", str(repo), "add", "--", ".mission/mission.yaml").returncode == 0
        blobs[name] = _git("-C", str(repo), "rev-parse", ":.mission/mission.yaml").stdout.decode().strip()
    staged = _git("-C", str(repo), "cat-file", "blob", blobs["tree"]).stdout
    assert b"\r" not in staged, "the staged blob carries a CR"
    assert blobs["tree"] == blobs["base"], "the cure moved a committed byte: blobs %s / %s" % (blobs["tree"], blobs["base"])
