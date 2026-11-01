"""THE TOOL -- tools/lam/prune-worktrees.ps1, the
operator's prune tool: -List a listing in s4_prune_listing.py's grammar, -Copy the trees copy-first, -Verify the
listing's digests against the copy (or, with -DryRun, against the source trees), and -Remove under a per-tree
confirmation bound to the tree's HEAD.

THE ROW. Each arc's prune was a block composed by hand from a seat's own script (one arc's h17_blocks_facts.py,
another's s4_prune_listing.py, a third's prune_scan.py): three grammars for one act. The tool keeps the form of
record -- s4's lines, line for line, LF, UTF-8 without a BOM -- and the blocks' acts (robocopy's switches, the digest
loop, `git worktree remove --force`, `git branch -d` and never -D, one `git worktree prune`).

WHY THIS HOME. The framework suite is the green gate's own suite (.mission/green-gate/framework.json: cwd tools); the
prune fixture belongs here, beside test_close_milestone_lam_roster.py, whose form this file follows. Being in the
gate (named at grounding) binds it: hermetic (every repository and tree lives in pytest's tmp_path), fast (a handful
of files per tree), and it removes the synthetic trees it made through `git worktree remove` at teardown, so nothing
registered is left inside the tmp roots pytest keeps.

THE FIXTURES. (1) SYNTHETIC TREES by a real `git worktree add -b worktree-wt-D-X <tmp>/m-worktrees/wt-D-X` (the
runner's home form) in a temp repository whose git dir is asserted inside tmp_path before any `git config`; untracked
and ignored files, a path with a space and a non-ASCII path (porcelain is read with -z), a TRACKED handoff of another
dispatch in every tree, the tree's own handoff untracked (a worker), absent (a validator) or tracked; an OWNER sidecar
at <root>/.mission-runtime/evidence/session-D-X/OWNER and spawn-ledger lines in the temp root; expected rows computed
here, independently, with hashlib and s4's own expressions. (2) THE RECORD LISTINGS: the tool's own listing parser
over the four RECORDS listings (v2, an earlier one, a legacy one and a fourth) reads 219475 / 354 / 5169 / 219207 entries --
each file read from the PRIMARY checkout's runtime plane, read-only, pinned by sha256, SKIPPED with a reason when
absent. (3) A BYTE SLICE: the first entries of two v2 trees copied out of scratch-copies/arc-pb-6-trees/<tree>/
(all 219475 verified there) into synthetic trees of the same names at the same relative paths; their
sidecar and spawn-ledger inputs are written here from the record's own values (the evidence plane is not read); the
tool's SESSION and entry lines then equal v2's lines byte for byte. The fourth listing's two trees the same way, out of
scratch-copies/arc-pb-7-trees/, stepping over the CITED line that listing holds between SESSION and the entries.

THE PER-TREE LINES. -List prints, to stdout
only and as each tree finishes, one ELAPSED line: the tree's time and where it went (ancestry, walk, session, status,
digests). The -Out bytes do not move: HEAD's tool at the charter's tip, read from the installed synthetic base
base-700e19e5-s11 (no history) and pinned, and this tree's run over the module's three-tree mission, and the two -Out files are byte-equal but for line
1's stamp. The spawn ledger is read once per run, not once per tree -- already so at the charter's tip; a counting
harness pins it.

THE FALSIFIERS, each to its test:
  the tool over the three fixtures -> rows as the listings expect ......... test_the_listing_parser_reads_...
  a tracked HANDOFF -> SESSION lines from the sidecar's / spawn ledger's
    session, never the handoff's (v2's three lines; the handoff line
    only from the tree's own UNTRACKED handoff) ............................ test_session_lines_never_read_a_tracked_handoff
  remove without the confirmation argument -> refused, nothing removed ..... test_remove_without_confirmation_...
  with it -> removed, the -d refusal on the unmerged one printed ........... test_remove_with_confirmation_...
  -DryRun -> the digest loop's line and its elapsed time, nothing copied ... test_dry_run_...
  a cited tree is refused unless its confirmation names the citation ....... test_remove_refuses_a_cited_tree_...
The per-tree lines':
  the fourth fixture's listing -> its rows as recorded ................... test_the_listing_parser_reads_...[arc-pb-7];
                                                                            test_the_tools_lines_reproduce_arc_pb_7_...
  per-tree lines present, the listing's bytes unchanged ................... test_list_ab_the_out_bytes_unchanged_...
  the spawn ledger opened once, counted by the member ..................... test_list_reads_the_spawn_ledger_once_...

Once tracked, the tool joins two censuses of tracked source -- WP-4 T-36's (the writers of a column-0 consume key)
and WP-3 C-1v's (the one token that only lam-verify-admission.ps1 may carry in code). test_the_tool_carries_neither_
census_token holds the tool outside both; this file spells the two tokens in pieces so that it enters neither itself.

NOTHING HERE WRITES OUTSIDE tmp_path. The primary checkout's listings and copies are only read.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]              # repo/tools
_REPO = _TOOLS.parent                                     # repo root (this checkout)
_TOOL = _TOOLS / "lam" / "prune-worktrees.ps1"

# THE RECORD LISTINGS, under the primary checkout's .mission-runtime/lam/: path, sha256, entries, trees.
RECORDS = {
    "arc-pb-6-v2": ("close/arc-pb-6-close/prune-listing.v2.txt",
                    "ff6047540728232289e8c5fd751f5cc44e3182ff0134d182cc3b15ff4cb5b2af", 219475, 7),
    "arc-pb-5": ("close/arc-pb-5-close/prune-listing.txt",
                 "7fa421d78aeb2f4aaea463518ba7d30bb6fecf77cb44fb877180436d7a41a61a", 354, 7),
    "batch-4-legacy": ("close/batch-4-rec-a/prune-listing-legacy.txt",
                       "ca536e1ac9b3a7614e0bdbbaf3475a7b96eb63fa977bf14769c864a8c83ba2e9", 5169, 115),
    "arc-pb-7": ("close/arc-pb-7-close/prune-listing-arc-pb-7.txt",
                 "0e0d4b9d621c42f4b6d7d7380e96cbad037746ff24bcf057e1e0622a7d9d86ad", 219207, 7),
}

OTHER_WORKER = "OTHER-DISPATCH-HANDOFF-MUST-NOT-BE-READ"
TRACKED_OWN_WORKER = "TRACKED-OWN-HANDOFF-MUST-NOT-BE-READ"
OWN_WORKER = "fixture worker (session 11111111-2222-4333-8444-555555555555)"

TITLE = re.compile(r"^(\S+ -- )?THE PRUNE LISTING: .* at HEAD [0-9a-f]{40}, "
                   r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z; ancestry against the tip ([0-9a-f]{40})\.$")

# The child for the tool's own functions: dot-sourced, the tool must run nothing of its own. A dot-source binds the
# tool's own parameters (-Listing among them) in this scope, so the harness keeps its arguments under other names first.
DOT_HARNESS = r"""param([string]$Tool, [string]$Listing, [string]$PorcelainFile)
$ErrorActionPreference = 'Stop'
$harnessTool = $Tool
$harnessListing = $Listing
$harnessPorcelain = $PorcelainFile
. $harnessTool
if ($harnessListing) {
    $r = Read-PwListing -Path $harnessListing
    Write-Output ('ENTRIES ' + $r.Entries.Count + ' NOTAFILE ' + $r.NotAFile + ' TREES ' + $r.Trees.Count)
}
if ($harnessPorcelain) {
    $text = [System.IO.File]::ReadAllText($harnessPorcelain, (New-Object System.Text.UTF8Encoding($false)))
    foreach ($e in @(ConvertFrom-PwPorcelain -Text $text)) {
        Write-Output ('TREE ' + $e.Path + ' PRUNABLE ' + $(if ($null -ne $e.Prunable) { '[' + $e.Prunable + ']' } else { 'no' }))
    }
}
Write-Output 'HARNESS DONE'
exit 0
"""


def _powershell():
    for cand in ("powershell", "powershell.exe", "pwsh"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (powershell/pwsh) on PATH -- cannot run the tool")


def _sha(b):
    return hashlib.sha256(b).hexdigest()


def _git(*args, check=True):
    cp = subprocess.run(["git"] + [str(a) for a in args], capture_output=True)
    if check:
        assert cp.returncode == 0, (args, cp.stdout.decode("utf-8", "replace"), cp.stderr.decode("utf-8", "replace"))
    return cp


def _out(cp):
    return cp.stdout.decode("utf-8").strip()


def _tool(*args, timeout=300, tool=None):
    tool = tool or _TOOL
    assert tool.is_file(), "THE TOOL IS ABSENT: %s -- it is not built" % tool
    argv = [_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(tool)] + [str(a) for a in args]
    cp = subprocess.run(argv, capture_output=True, timeout=timeout)
    cp.text = (cp.stdout + cp.stderr).decode("utf-8", "replace")
    return cp


def _dot(tmp, **params):
    assert _TOOL.is_file(), "THE TOOL IS ABSENT: %s -- it is not built" % _TOOL
    harness = tmp / "dot-harness.ps1"
    harness.write_text(DOT_HARNESS, encoding="utf-8")
    argv = [_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(harness), "-Tool", str(_TOOL)]
    for k, v in params.items():
        argv += ["-" + k, str(v)]
    cp = subprocess.run(argv, capture_output=True, timeout=600)
    cp.text = (cp.stdout + cp.stderr).decode("utf-8", "replace")
    return cp


def _main_checkout():
    common = Path(_out(_git("-C", _REPO, "rev-parse", "--git-common-dir")))
    if not common.is_absolute():
        common = (_REPO / common).resolve()
    return common.parent


def _porcelain(top):
    """`git worktree list --porcelain -z`, as a list of {field: value} -- the first is the main worktree."""
    raw = _git("-C", top, "worktree", "list", "--porcelain", "-z").stdout.decode("utf-8")
    entries, cur = [], None
    for field in raw.split("\0"):
        if not field:
            cur = None
            continue
        key, _, value = field.partition(" ")
        if key == "worktree":
            cur = {"worktree": value}
            entries.append(cur)
        elif cur is not None:
            cur[key] = value
    return entries


def _expected_entries(tree):
    """The entry rows, computed here: porcelain -z, then each path's bytes and sha256 by hashlib (s4 :62-:78)."""
    raw = _git("-C", tree, "--no-optional-locks", "status", "--porcelain", "-z",
               "--untracked-files=all", "--ignored").stdout
    recs, rows, i = raw.split(b"\0"), [], 0
    while i < len(recs):
        rec = recs[i]
        i += 1
        if not rec:
            continue
        code, rel = rec[:2].decode("utf-8"), rec[3:].decode("utf-8")
        if code[0] in "RC":
            i += 1                                       # a rename's source path is its own field under -z
        fp = Path(tree) / rel
        if fp.is_file():
            b = fp.read_bytes()
            rows.append("   [%s] %s | %d B | sha256 %s" % (code, rel, len(b), _sha(b)))
        else:
            rows.append("   [%s] %s | NOT A FILE" % (code, rel))
    return rows


def _walked(tree):
    return sum(len(fs) for _, _, fs in os.walk(tree))                  # s4 :64


def _blocks(text):
    """Split a listing into its title, per-tree blocks (header, SESSION, CITED, entries, in that order) and TOTAL."""
    assert text.endswith("\n"), "the listing does not end with LF"
    lines = text[:-1].split("\n")
    blocks, cur, kinds = {}, None, {}
    order = {"session": 0, "cited": 1, "entries": 2}
    total = None
    for line in lines[1:]:
        if line.startswith("== "):
            cur = line.split(" | ")[0][3:]
            blocks[cur] = {"header": line, "session": [], "cited": [], "entries": []}
            kinds[cur] = -1
            continue
        kind = ("session" if line.startswith("   SESSION ") else "cited" if line.startswith("   CITED ")
                else "entries" if line.startswith("   [") else None)
        if line.startswith("TOTAL: "):
            total = line
            continue
        assert kind is not None and cur is not None, "a line outside the grammar: %r" % line
        assert order[kind] >= kinds[cur], "%s: a %s line after a later kind: %r" % (cur, kind, line)
        kinds[cur] = order[kind]
        blocks[cur][kind].append(line)
    return lines, blocks, total


def _s4_sidecar(text):
    o = dict(re.findall(r"^(\w+): (.*)$", text, re.M))                                   # s4 :49-:50
    return "   SESSION sidecar session_id %s spawned_at %s model %s" % (o.get("session_id"), o.get("spawned_at"),
                                                                       o.get("model"))


def _s4_spawn(rec):
    keys = {k: v for k, v in rec.items() if "session" in k.lower() and v}                # s4 :53-:54
    return "   SESSION spawn-ledger complete seq %s %s" % (rec.get("seq"), keys or "(no session key)")


class Mission:
    """A temp repository that plays the primary checkout, with linked trees under <tmp>/m-worktrees/."""

    def __init__(self, tmp):
        self.tmp = tmp
        self.root = tmp / "root"
        self.base = tmp / "m-worktrees"
        self.root.mkdir(parents=True)
        _git("init", "--quiet", self.root)
        # THE GIT DIR IS ASSERTED INSIDE THE FIXTURE BEFORE ANY git config (a standing rule).
        gd = Path(_out(_git("-C", self.root, "rev-parse", "--absolute-git-dir")))
        assert gd.resolve().is_relative_to(tmp.resolve()), gd
        for key, value in (("user.email", "prune@fixture.invalid"), ("user.name", "prune fixture"),
                           ("core.autocrlf", "false"), ("commit.gpgsign", "false")):
            _git("-C", self.root, "config", key, value)
        _git("-C", self.root, "symbolic-ref", "HEAD", "refs/heads/main")
        self.write(self.root, ".gitignore", "*.log\n")
        self.write(self.root, "README.txt", "prune fixture\n")
        self.write(self.root, ".mission/dispatches/D-OTHER.handoff.yaml",
                   "id: D-OTHER\nfrom_worker: %s\n" % OTHER_WORKER)
        self.commit(self.root, "base")
        self.tip = self.head(self.root)
        self.trees = {}

    @staticmethod
    def write(top, rel, text):
        p = Path(top) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(text.encode("utf-8"))
        return p

    @staticmethod
    def commit(top, message):
        _git("-C", top, "add", "-A")
        _git("-C", top, "commit", "--quiet", "-m", message)

    @staticmethod
    def head(top):
        return _out(_git("-C", top, "rev-parse", "HEAD"))

    def tree(self, disp, handoff=None, unmerged=False, notes=True):
        path = self.base / ("wt-" + disp)
        _git("-C", self.root, "worktree", "add", "--quiet", "-b", "worktree-wt-" + disp, path)
        if handoff == "tracked":
            self.write(path, ".mission/dispatches/%s.handoff.yaml" % disp,
                       "id: %s\nfrom_worker: %s\n" % (disp, TRACKED_OWN_WORKER))
            self.commit(path, "the tree's own handoff, tracked")
        elif handoff == "untracked":
            self.write(path, ".mission/dispatches/%s.handoff.yaml" % disp,
                       "id: %s\nstatus: complete\nfrom_worker: %s\n" % (disp, OWN_WORKER))
        if unmerged and handoff != "tracked":
            self.write(path, "work.txt", "unmerged work\n")
            self.commit(path, "unmerged work")
        if notes:
            self.write(path, "notes/a.txt", "an untracked note\n")
            self.write(path, "notes/with space.txt", "a path with a space\n")
            self.write(path, "notes/caf\u00e9.txt", "a non-ASCII path\n")
            self.write(path, "build/out.log", "an ignored log\n")
        self.trees[disp] = path
        return path

    def owner(self, disp, session_id, spawned_at, model, role="coding-strong"):
        return self.write(self.root, ".mission-runtime/evidence/session-%s/OWNER" % disp,
                          "runner_id: mission-dispatch.ps1\ndispatch_id: %s\nsession_id: %s\nspawned_at: %s\n"
                          "role: %s\nmodel: %s\n" % (disp, session_id, spawned_at, role, model))

    def ledger(self, records):
        self.write(self.root, ".mission-runtime/lam/spawn-ledger.jsonl",
                   "".join(json.dumps(r, separators=(",", ":")) + "\n" for r in records))

    def porcelain(self):
        return _porcelain(self.root)

    def branch_exists(self, name):
        return bool(_out(_git("-C", self.root, "branch", "--list", name)))

    def teardown(self):
        for e in self.porcelain()[1:]:
            _git("-C", self.root, "worktree", "remove", "--force", e["worktree"], check=False)
        _git("-C", self.root, "worktree", "prune", check=False)


@pytest.fixture
def mission(tmp_path):
    m = Mission(tmp_path)
    yield m
    m.teardown()


def _snapshot(top):
    out = {}
    for dirpath, _, files in os.walk(top):
        for f in files:
            p = Path(dirpath) / f
            out[str(p.relative_to(top))] = _sha(p.read_bytes())
    return out


# ============================================================ (1) -List, OVER SYNTHETIC TREES (ONE LISTING, READ) ==
W1_COMPLETE = {"event": "complete", "seq": 901, "ts": "2026-10-16T01:30:00.000Z", "kind": "worker",
               "role": "coding-strong", "dispatch_id": "D-W1", "worker_session": "the worker's own session",
               "validator_session": "", "session_count": 0, "seat_Session_note": "C:\\fixture\\seat",
               "session_ids": ["a", "b'c"], "session_seq": 7, "session_live": True,
               "seat_session_extra": "tab\there caf\u00e9", "result_sha256": None,
               "seat_session": "aaaaaaaa-0000-4000-8000-000000000001"}
VA_COMPLETE = {"event": "complete", "seq": 902, "kind": "validator", "dispatch_id": "D-V-A-1", "validates": "A-1",
               "validator_session": "", "verdict": "PASS"}
LEDGER = [
    {"event": "spawn", "seq": 901, "dispatch_id": "D-W1", "worker_session": "THE SPAWN LINE IS NOT READ"},
    W1_COMPLETE,
    {"event": "spawn", "seq": 902, "dispatch_id": "D-V-A-1"},
    VA_COMPLETE,
    {"event": "complete", "seq": 903, "dispatch_id": "D-W1X", "worker_session": "A PREFIX DECOY IS NOT READ"},
]
W1_OWNER = ("session-D-W1", "2026-10-16T01:02:03.004Z", "fixture-model")
VA_OWNER = ("session-D-V-A-1", "2026-10-16T05:06:07.008Z", "fixture-model")


@pytest.fixture(scope="module")
def listed(tmp_path_factory):
    """THREE TREES AND ONE LISTING, read by the four tests below: wt-D-W1 (a worker: its own handoff UNTRACKED, a
    sidecar, a complete line), wt-D-V-A-1 (a validator: no own handoff, a sidecar, a complete line with no session key,
    cited by an anchors file twice), wt-D-T1 (its own handoff TRACKED, its branch unmerged, no sidecar, no ledger
    line). Every tree also carries D-OTHER's TRACKED handoff from the base commit."""
    tmp = tmp_path_factory.mktemp("listed")
    m = Mission(tmp)
    try:
        w1 = m.tree("D-W1", handoff="untracked")
        va = m.tree("D-V-A-1")
        t1 = m.tree("D-T1", handoff="tracked", unmerged=True)
        m.owner("D-W1", *W1_OWNER)
        m.owner("D-V-A-1", *VA_OWNER, role="qa-validator")
        m.ledger(LEDGER)
        va_manifest = str(va / ".mission" / "evidence" / "session-D-V-A-1" / "manifest.json")
        m.write(m.root, ".mission/dispatches/D-V-A-1.anchors.yaml",
                "dispatch_id: D-V-A-1\nanchors:\n  evidence_manifest: %s\nworktree_path: %s\n" % (va_manifest, va))
        m.write(m.root, ".mission/dispatches/D-W1.anchors.yaml",
                "dispatch_id: D-W1\nanchors:\n  evidence_manifest: .mission-runtime/evidence/session-D-W1/manifest.json\n"
                "worktree_path: %s\n" % (m.base / "wt-D-W1b"))
        m.write(m.root, ".mission-runtime/lam/wake/seat-1.wake.json",
                json.dumps({"head_sha": m.tip, "batch": "fixture", "worktree_path": str(w1)}))
        out = tmp / "listing.txt"
        cp = _tool("-MissionRoot", m.root, "-List", "-Out", out, "-Trees", ",".join(str(p) for p in (w1, va, t1)),
                   "-Tip", m.tip)
        data = out.read_bytes() if out.exists() else b""
        yield {"m": m, "cp": cp, "out": out, "data": data, "w1": w1, "va": va, "t1": t1, "va_manifest": va_manifest}
    finally:
        m.teardown()


def test_list_writes_s4s_grammar_line_for_line(listed):
    m, cp, data = listed["m"], listed["cp"], listed["data"]
    assert cp.returncode == 0, cp.text
    assert data, "no listing was written: %s" % cp.text
    assert not data.startswith(b"\xef\xbb\xbf"), "the listing carries a BOM"
    assert b"\r" not in data, "the listing carries a CR"
    lines, blocks, total = _blocks(data.decode("utf-8"))
    title = TITLE.match(lines[0])
    assert title and title.group(2) == m.tip, lines[0]
    assert list(blocks) == ["wt-D-W1", "wt-D-V-A-1", "wt-D-T1"], list(blocks)
    pors = {Path(e["worktree"]).name: e for e in m.porcelain()[1:]}
    rcs = {}
    for disp in ("D-W1", "D-V-A-1", "D-T1"):
        name, e = "wt-" + disp, pors["wt-" + disp]
        rcs[disp] = _git("-C", m.root, "merge-base", "--is-ancestor", e["HEAD"], m.tip, check=False).returncode
        expect = ("== %s | %s | branch %s | HEAD %s | merge-base --is-ancestor HEAD %s exit %d | branch tip == the "
                  "tree's HEAD: True | files walked %d" % (name, e["worktree"], "worktree-" + name, e["HEAD"],
                                                           m.tip[:8], rcs[disp], _walked(m.trees[disp])))
        assert blocks[name]["header"] == expect
        assert blocks[name]["entries"] == _expected_entries(m.trees[disp]), name
    assert rcs == {"D-W1": 0, "D-V-A-1": 0, "D-T1": 1}, rcs
    w1 = {(row[4:6], row[8:].split(" | ")[0]) for row in blocks["wt-D-W1"]["entries"]}
    assert w1 == {("??", ".mission/dispatches/D-W1.handoff.yaml"), ("??", "notes/a.txt"),
                  ("??", "notes/caf\u00e9.txt"), ("??", "notes/with space.txt"), ("!!", "build/out.log")}, w1
    n = sum(len(b["entries"]) for b in blocks.values())
    assert total == "TOTAL: 3 tree(s), %d entries" % n, total


def test_session_lines_never_read_a_tracked_handoff(listed):
    """The SESSION rule: v2's three SESSION lines -- the mission root's OWNER sidecar, the spawn ledger's
    complete line, and the handoff line from the tree's OWN dispatch's UNTRACKED handoff only. D-OTHER's handoff,
    tracked in every tree, and wt-D-T1's own handoff, tracked, are never read."""
    cp, data = listed["cp"], listed["data"]
    assert cp.returncode == 0, cp.text
    text = data.decode("utf-8")
    _, blocks, _ = _blocks(text)
    sidecar_w1 = _s4_sidecar((listed["m"].root / ".mission-runtime/evidence/session-D-W1/OWNER").read_text("utf-8"))
    sidecar_va = _s4_sidecar((listed["m"].root / ".mission-runtime/evidence/session-D-V-A-1/OWNER").read_text("utf-8"))
    assert blocks["wt-D-W1"]["session"] == [
        sidecar_w1, _s4_spawn(W1_COMPLETE),
        "   SESSION handoff D-W1.handoff.yaml from_worker %s" % OWN_WORKER]
    assert blocks["wt-D-V-A-1"]["session"] == [
        sidecar_va, _s4_spawn(VA_COMPLETE), "   SESSION handoff D-V-A-1.handoff.yaml: none in the tree"]
    assert blocks["wt-D-T1"]["session"] == ["   SESSION handoff D-T1.handoff.yaml: tracked in the tree, not read"]
    for never in (OTHER_WORKER, TRACKED_OWN_WORKER, "THE SPAWN LINE IS NOT READ", "A PREFIX DECOY IS NOT READ"):
        assert never not in text, never


def test_the_spawn_ledger_line_is_pythons_dict_repr(listed):
    """s4 printed the complete line's session keys as a PYTHON DICT REPR (v2 :94221 holds a double-quoted value): the
    expected line is Python's own repr of the same dict -- key order, falsy values dropped, quotes and escapes."""
    _, blocks, _ = _blocks(listed["data"].decode("utf-8"))
    line = blocks["wt-D-W1"]["session"][1]
    assert line == ("   SESSION spawn-ledger complete seq 901 {'worker_session': \"the worker's own session\", "
                    "'seat_Session_note': 'C:\\\\fixture\\\\seat', 'session_ids': ['a', \"b'c\"], 'session_seq': 7, "
                    "'session_live': True, 'seat_session_extra': 'tab\\there caf\u00e9', "
                    "'seat_session': 'aaaaaaaa-0000-4000-8000-000000000001'}"), line
    assert blocks["wt-D-V-A-1"]["session"][1] == "   SESSION spawn-ledger complete seq 902 (no session key)"


def test_cited_lines_name_every_record_pointing_into_a_tree(listed):
    """The cited-tree rule: an anchors file's evidence_manifest / worktree_path, or a wake artifact's worktree_path, that
    names a path INTO a tree is printed under that tree. A root-relative manifest and a sibling whose name only begins
    with the tree's name cite nothing."""
    _, blocks, _ = _blocks(listed["data"].decode("utf-8"))
    assert blocks["wt-D-V-A-1"]["cited"] == [
        "   CITED .mission/dispatches/D-V-A-1.anchors.yaml evidence_manifest -> %s" % listed["va_manifest"],
        "   CITED .mission/dispatches/D-V-A-1.anchors.yaml worktree_path -> %s" % listed["va"]]
    assert blocks["wt-D-W1"]["cited"] == [
        "   CITED .mission-runtime/lam/wake/seat-1.wake.json worktree_path -> %s" % listed["w1"]]
    assert blocks["wt-D-T1"]["cited"] == []


# ============================================================================= (1) -List, ITS REFUSALS ==========
def test_list_refuses_before_any_act(mission):
    w1 = mission.tree("D-W1")
    out = mission.tmp / "listing.txt"
    out.write_bytes(b"an earlier listing\n")
    common = ("-MissionRoot", mission.root, "-Tip", mission.tip)
    cases = {
        "an existing out file": ("-List", "-Out", out, "-Trees", w1) + common,
        "the root as a tree": ("-List", "-Out", mission.tmp / "l2.txt", "-Trees", mission.root) + common,
        "a folder that is no tree": ("-List", "-Out", mission.tmp / "l3.txt", "-Trees", mission.tmp) + common,
        "no mode": ("-Out", mission.tmp / "l4.txt", "-Trees", w1) + common,
        "two modes": ("-List", "-Copy", "-Set", "s1", "-Out", mission.tmp / "l5.txt", "-Trees", w1) + common,
        "a tip that resolves to nothing": ("-List", "-Out", mission.tmp / "l6.txt", "-Trees", w1,
                                           "-MissionRoot", mission.root, "-Tip", "0" * 40),
    }
    for why, args in cases.items():
        cp = _tool(*args)
        assert cp.returncode == 2, "%s: exit %d\n%s" % (why, cp.returncode, cp.text)
    assert out.read_bytes() == b"an earlier listing\n"
    assert not any((mission.tmp / ("l%d.txt" % i)).exists() for i in range(2, 7))


# ============================================================== (1) -Copy AND -Verify, -DryRun ==================
def test_dry_run_prints_the_loop_line_and_its_elapsed_time_and_copies_nothing(mission):
    w1 = mission.tree("D-W1", handoff="untracked")
    va = mission.tree("D-V-A-1")
    listing = mission.tmp / "listing.txt"
    cp = _tool("-MissionRoot", mission.root, "-List", "-Out", listing, "-Trees", "%s,%s" % (w1, va),
               "-Tip", mission.tip)
    assert cp.returncode == 0, cp.text
    _, blocks, _ = _blocks(listing.read_text("utf-8"))
    n = sum(1 for b in blocks.values() for row in b["entries"] if not row.endswith("| NOT A FILE"))
    before = _snapshot(mission.tmp)
    cp = _tool("-MissionRoot", mission.root, "-Verify", "-Listing", listing, "-DryRun")
    assert cp.returncode == 0, cp.text
    assert re.search(r"^STARTED \d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\r?$", cp.text, re.M), cp.text
    assert re.search(r"^listed %d; missing 0; mismatched 0\r?$" % n, cp.text, re.M), cp.text
    assert re.search(r"^ENDED \S+ ELAPSED \d+(\.\d+)? s\r?$", cp.text, re.M), cp.text
    assert _snapshot(mission.tmp) == before, "the dry run wrote or copied a file"
    assert not (mission.root / ".mission-runtime" / "scratch-copies").exists()
    (w1 / "notes" / "a.txt").write_bytes(b"changed after the listing\n")
    cp = _tool("-MissionRoot", mission.root, "-Verify", "-Listing", listing, "-DryRun")
    assert cp.returncode == 3, cp.text
    assert re.search(r"^listed %d; missing 0; mismatched 1\r?$" % n, cp.text, re.M), cp.text
    assert "MISMATCH wt-D-W1 " in cp.text


def test_copy_then_verify_against_the_copy(mission):
    w1 = mission.tree("D-W1", handoff="untracked")
    va = mission.tree("D-V-A-1")
    trees = "%s,%s" % (w1, va)
    listing = mission.tmp / "listing.txt"
    assert _tool("-MissionRoot", mission.root, "-List", "-Out", listing, "-Trees", trees,
                 "-Tip", mission.tip).returncode == 0
    _, blocks, _ = _blocks(listing.read_text("utf-8"))
    n = sum(1 for b in blocks.values() for row in b["entries"] if not row.endswith("| NOT A FILE"))
    cp = _tool("-MissionRoot", mission.root, "-Copy", "-Set", "fixture-trees", "-Trees", trees)
    assert cp.returncode == 0, cp.text
    for name in ("wt-D-W1", "wt-D-V-A-1"):
        m = re.search(r"^robocopy %s exit (\d+)\r?$" % re.escape(name), cp.text, re.M)
        assert m and int(m.group(1)) < 8, cp.text
    dest = mission.root / ".mission-runtime" / "scratch-copies" / "fixture-trees"
    assert _snapshot(dest / "wt-D-W1") == _snapshot(w1)
    again = _tool("-MissionRoot", mission.root, "-Copy", "-Set", "fixture-trees", "-Trees", trees)
    assert again.returncode == 2, again.text
    cp = _tool("-MissionRoot", mission.root, "-Verify", "-Listing", listing, "-Set", "fixture-trees")
    assert cp.returncode == 0, cp.text
    for name, path in (("wt-D-W1", w1), ("wt-D-V-A-1", va)):
        c = _walked(path)
        assert re.search(r"^%s %d = %d True\r?$" % (re.escape(name), c, c), cp.text, re.M), cp.text
    assert re.search(r"^listed %d; missing 0; mismatched 0\r?$" % n, cp.text, re.M), cp.text
    (dest / "wt-D-V-A-1" / "notes" / "a.txt").unlink()
    cp = _tool("-MissionRoot", mission.root, "-Verify", "-Listing", listing, "-Set", "fixture-trees")
    assert cp.returncode == 3, cp.text
    assert re.search(r"^listed %d; missing 1; mismatched 0\r?$" % n, cp.text, re.M), cp.text
    assert re.search(r"^wt-D-V-A-1 \d+ = \d+ False\r?$", cp.text, re.M), cp.text


# ===================================================================================== (1) -Remove ===============
def _confirm(mission, disp, *cited):
    head = mission.head(mission.trees[disp])
    return "@".join(["wt-" + disp, head[:8]] + list(cited))


def test_remove_without_confirmation_is_refused_and_nothing_is_removed(mission):
    w1 = mission.tree("D-W1")
    va = mission.tree("D-V-A-1")
    trees = "%s,%s" % (w1, va)
    before = mission.porcelain()
    for args in ((), ("-ConfirmRemove", _confirm(mission, "D-W1")),
                 ("-ConfirmRemove", "wt-D-W1@00000000,%s" % _confirm(mission, "D-V-A-1")),
                 ("-ConfirmRemove", "%s,%s,wt-D-NOT-LISTED@12345678" % (_confirm(mission, "D-W1"),
                                                                         _confirm(mission, "D-V-A-1")))):
        cp = _tool("-MissionRoot", mission.root, "-Remove", "-Trees", trees, *args)
        assert cp.returncode == 2, "%r: exit %d\n%s" % (args, cp.returncode, cp.text)
        assert w1.is_dir() and va.is_dir()
        assert mission.branch_exists("worktree-wt-D-W1") and mission.branch_exists("worktree-wt-D-V-A-1")
        assert mission.porcelain() == before


def test_remove_with_confirmation_removes_and_prints_the_d_refusal_on_the_unmerged_one(mission):
    w1 = mission.tree("D-W1", handoff="untracked")
    t1 = mission.tree("D-T1", handoff="tracked", unmerged=True)
    gone = mission.tree("D-GONE", notes=False)
    shutil.rmtree(gone)                       # a registration left behind by hand: prunable before the run
    assert any("prunable" in e for e in mission.porcelain()), mission.porcelain()
    cp = _tool("-MissionRoot", mission.root, "-Remove", "-Trees", "%s,%s" % (w1, t1),
               "-ConfirmRemove", "%s,%s" % (_confirm(mission, "D-W1"), _confirm(mission, "D-T1")))
    assert cp.returncode == 4, cp.text
    assert not w1.exists() and not t1.exists()
    assert not mission.branch_exists("worktree-wt-D-W1"), "the merged branch was not deleted"
    assert mission.branch_exists("worktree-wt-D-T1"), "the unmerged branch was not left"
    for line in ("remove wt-D-W1 exit 0", "branch -d worktree-wt-D-W1 exit 0", "remove wt-D-T1 exit 0"):
        assert re.search(r"^%s\r?$" % re.escape(line), cp.text, re.M), line + "\n" + cp.text
    assert re.search(r"^branch -d worktree-wt-D-T1 exit [1-9]\d*\r?$", cp.text, re.M), cp.text
    assert re.search(r"^FINDING: git branch -d worktree-wt-D-T1 refused", cp.text, re.M), cp.text
    assert "not fully merged" in cp.text.lower(), cp.text
    left = mission.porcelain()
    assert len(left) == 1 and not any("prunable" in e for e in left), left
    assert "a prunable registration" not in cp.text


def test_remove_refuses_a_cited_tree_unless_the_confirmation_names_the_citation(mission):
    va = mission.tree("D-V-A-1")
    w1 = mission.tree("D-W1")
    mission.write(mission.root, ".mission/dispatches/D-V-A-1.anchors.yaml", "worktree_path: %s\n" % va)
    anchors = ".mission/dispatches/D-V-A-1.anchors.yaml"
    for confirm in (_confirm(mission, "D-V-A-1"),
                    _confirm(mission, "D-V-A-1", anchors, ".mission/dispatches/D-W1.anchors.yaml")):
        cp = _tool("-MissionRoot", mission.root, "-Remove", "-Trees", va, "-ConfirmRemove", confirm)
        assert cp.returncode == 2, "%s: exit %d\n%s" % (confirm, cp.returncode, cp.text)
        assert "CITED" in cp.text and anchors in cp.text, cp.text
        assert va.is_dir() and mission.branch_exists("worktree-wt-D-V-A-1")
    cp = _tool("-MissionRoot", mission.root, "-Remove", "-Trees", va,
               "-ConfirmRemove", _confirm(mission, "D-V-A-1", anchors))
    assert cp.returncode == 0, cp.text
    assert not va.exists() and not mission.branch_exists("worktree-wt-D-V-A-1")
    assert w1.is_dir() and mission.branch_exists("worktree-wt-D-W1"), "a tree not named was touched"


def test_the_porcelain_reader_flags_a_prunable_registration(tmp_path):
    """RES-01 and the grounding: after its one `git worktree prune` the tool reads the porcelain again and prints ANY
    `prunable` registration as a FINDING (exit 4). git's prune leaves no unlocked prunable registration behind, so the
    fixture cannot make one survive it; the reader the tool uses is driven here directly, dot-sourced (and the
    dot-source itself must run nothing)."""
    nul = "\0"
    text = (nul.join(["worktree C:/fixture/root", "HEAD " + "a" * 40, "branch refs/heads/main", ""]) + nul +
            nul.join(["worktree C:/fixture/m-worktrees/wt-D-X", "HEAD " + "b" * 40, "branch refs/heads/worktree-wt-D-X",
                      "prunable gitdir file points to non-existent location", ""]) + nul +
            nul.join(["worktree C:/fixture/m-worktrees/wt-D-Y", "HEAD " + "c" * 40, "detached", "locked", ""]) + nul)
    pf = tmp_path / "porcelain.bin"
    pf.write_bytes(text.encode("utf-8"))
    cp = _dot(tmp_path, PorcelainFile=pf)
    assert cp.returncode == 0, cp.text
    assert cp.text.replace("\r\n", "\n").strip().split("\n") == [
        "TREE C:/fixture/root PRUNABLE no",
        "TREE C:/fixture/m-worktrees/wt-D-X PRUNABLE [gitdir file points to non-existent location]",
        "TREE C:/fixture/m-worktrees/wt-D-Y PRUNABLE no",
        "HARNESS DONE"], cp.text


# =================================================================================== THE CENSUSES AND D1 ================
def test_the_tool_carries_neither_census_token(tmp_path):
    assert _TOOL.is_file(), "THE TOOL IS ABSENT: %s -- it is not built" % _TOOL
    src = _TOOL.read_text(encoding="utf-8")
    assert ("consumed" + "_") not in src, "T-36's census: the tool must compose no consume key"
    assert ("origin" + "_attestation") not in src, "C-1v's census: the token is lam-verify-admission.ps1's alone"
    assert "branch -D" not in src and "'-D'" not in src and '"-D"' not in src, "ADR-041 D1: never git branch -D"
    assert "'-d'" in src or "branch -d" in src
    assert all(ord(ch) < 128 for ch in src), "the tool is not ASCII"


# ============================================================================== (2) THE RECORD LISTINGS ==========
@pytest.mark.parametrize("key", sorted(RECORDS))
def test_the_listing_parser_reads_the_three_record_listings(tmp_path, key):
    rel, pin, entries, trees = RECORDS[key]
    path = _main_checkout() / ".mission-runtime" / "lam" / Path(rel)
    if not path.is_file():
        pytest.skip("the record listing %s is absent on this machine (runtime plane of the primary checkout)" % path)
    assert _sha(path.read_bytes()) == pin, "the record listing's bytes moved: %s" % path
    cp = _dot(tmp_path, Listing=path)
    assert cp.returncode == 0, cp.text
    m = re.search(r"^ENTRIES (\d+) NOTAFILE (\d+) TREES (\d+)\r?$", cp.text, re.M)
    assert m, cp.text
    assert (int(m.group(1)), int(m.group(2)), int(m.group(3))) == (entries, 0, trees), cp.text


# =================================================================================== (3) THE BYTE SLICE ==========
# The two v2 trees' SESSION inputs, from the record's own values (v2 :3-:4, :94220-:94221, and the
# OWNER lines). The evidence plane and the live spawn ledger are not read.
SLICE = {
    "D-PB-6-S1": {"owner": ("session-D-PB-6-S1", "2026-10-14T22:59:03.604Z", "claude-opus-5", "coding-strong"),
                  "complete": {"event": "complete", "seq": 230, "kind": "worker", "dispatch_id": "D-PB-6-S1",
                               "worker_session": "see from_worker on the handoff",
                               "seat_session": "0000a641-0000-4000-8000-00000000a641"}},
    "D-V-A-606": {"owner": ("session-D-V-A-606", "2026-10-15T14:27:27.778Z", "claude-opus-5", "qa-validator"),
                  "complete": {"event": "complete", "seq": 234, "kind": "validator", "dispatch_id": "D-V-A-606",
                               "validator_session": (
                                   "session 0000b5ef-0000-4000-8000-00000000b5ef (Claude Code, worktree wt-D-V-A-606); "
                                   "model claude-opus-5, the model named Opus 5 as the CLI reports it. A fresh "
                                   "identity: I had not seen this work before this session, and no handoff claim above "
                                   "is reported except where I re-derived it myself."),
                               "validator_session_note": "read from the result's validator_identity",
                               "seat_session": "00003dbf-0000-4000-8000-000000003dbf"}},
}
SLICE_N = 4


def test_the_tools_lines_reproduce_v2_byte_for_byte(mission):
    main = _main_checkout()
    rel, pin, _, _ = RECORDS["arc-pb-6-v2"]
    v2 = main / ".mission-runtime" / "lam" / Path(rel)
    copies = main / ".mission-runtime" / "scratch-copies" / "arc-pb-6-trees"
    if not v2.is_file() or not copies.is_dir():
        pytest.skip("v2 or scratch-copies/arc-pb-6-trees is absent on this machine: %s / %s" % (v2, copies))
    data = v2.read_bytes()
    assert _sha(data) == pin, "v2's bytes moved"
    v2_lines = data.decode("utf-8").split("\n")
    want, paths = {}, []
    for disp, spec in SLICE.items():
        start = next(i for i, l in enumerate(v2_lines) if l.startswith("== wt-%s | " % disp))
        session = [l for l in v2_lines[start + 1:start + 8] if l.startswith("   SESSION ")]
        first = start + 1 + len(session)
        rows = v2_lines[first:first + SLICE_N]
        assert all(r.startswith("   [??] ") for r in rows), rows
        path = mission.tree(disp, notes=False)
        for row in rows:
            rel_path = row[8:].split(" | ")[0]
            src = copies / ("wt-" + disp) / Path(rel_path)
            if not src.is_file():
                pytest.skip("the copy lacks %s" % src)
            dst = path / Path(rel_path)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
        sid, at, model, role = spec["owner"]
        mission.owner(disp, sid, at, model, role=role)
        want["wt-" + disp] = (session, rows)
        paths.append(path)
    mission.ledger([SLICE[d]["complete"] for d in SLICE])
    out = mission.tmp / "slice-listing.txt"
    cp = _tool("-MissionRoot", mission.root, "-List", "-Out", out, "-Trees", ",".join(str(p) for p in paths),
               "-Tip", mission.tip)
    assert cp.returncode == 0, cp.text
    _, blocks, _ = _blocks(out.read_text("utf-8"))
    for name, (session, rows) in want.items():
        assert blocks[name]["session"] == session, name
        assert blocks[name]["entries"][:SLICE_N] == rows, name
        assert len(blocks[name]["entries"]) == SLICE_N, blocks[name]["entries"]


# The fourth record's two trees, a worker and a validator; their SESSION inputs from the record's own values
# (prune-listing-arc-pb-7.txt :3-:5 and :94025-:94027). The worker's handoff line reads its own untracked handoff,
# which is the tree's first entry and so is copied with the slice.
SLICE7 = {
    "D-PB-7-S1": {"owner": ("session-D-PB-7-S1", "2026-10-18T10:45:27.577Z", "claude-opus-5", "coding-strong"),
                  "complete": {"event": "complete", "seq": 238, "kind": "worker", "dispatch_id": "D-PB-7-S1",
                               "worker_session": "see from_worker on the handoff",
                               "seat_session": "00008246-0000-4000-8000-000000008246"}},
    "D-V-A-610": {"owner": ("session-D-V-A-610", "2026-10-18T13:10:00.434Z", "claude-opus-5", "qa-validator"),
                  "complete": {"event": "complete", "seq": 241, "kind": "validator", "dispatch_id": "D-V-A-610",
                               "validator_session": (
                                   "session 00008814-0000-4000-8000-000000008814, model claude-opus-5 (Claude Code, "
                                   "the model named Opus 5). The seat that authored the dispatch is session "
                                   "00008246-0000-4000-8000-000000008246; that is not me."),
                               "validator_session_note": "read from the result's validator_identity",
                               "seat_session": "00008246-0000-4000-8000-000000008246"}},
}


def test_the_tools_lines_reproduce_arc_pb_7_byte_for_byte(mission):
    """The fourth fixture, sliced as v2 is above -- with one difference: the tool that wrote that listing
    prints the CITED lines, so one stands between a tree's SESSION lines and its first entry (:6, :94028). The slice
    steps over it and compares no CITED line (it names the live paths; this fixture writes no anchors)."""
    main = _main_checkout()
    rel, pin, _, _ = RECORDS["arc-pb-7"]
    record = main / ".mission-runtime" / "lam" / Path(rel)
    copies = main / ".mission-runtime" / "scratch-copies" / "arc-pb-7-trees"
    if not record.is_file() or not copies.is_dir():
        pytest.skip("the fourth listing or scratch-copies/arc-pb-7-trees is absent on this machine: %s / %s"
                    % (record, copies))
    data = record.read_bytes()
    assert _sha(data) == pin, "the fourth listing's bytes moved"
    rec_lines = data.decode("utf-8").split("\n")
    want, paths = {}, []
    for disp, spec in SLICE7.items():
        start = next(i for i, l in enumerate(rec_lines) if l.startswith("== wt-%s | " % disp))
        first = start + 1
        while rec_lines[first].startswith(("   SESSION ", "   CITED ")):
            first += 1
        session = [l for l in rec_lines[start + 1:first] if l.startswith("   SESSION ")]
        cited = [l for l in rec_lines[start + 1:first] if l.startswith("   CITED ")]
        assert len(session) == 3 and len(cited) == 1, rec_lines[start:first]
        rows = rec_lines[first:first + SLICE_N]
        assert all(r.startswith("   [??] ") for r in rows), rows
        path = mission.tree(disp, notes=False)
        for row in rows:
            rel_path = row[8:].split(" | ")[0]
            src = copies / ("wt-" + disp) / Path(rel_path)
            if not src.is_file():
                pytest.skip("the copy lacks %s" % src)
            dst = path / Path(rel_path)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
        sid, at, model, role = spec["owner"]
        mission.owner(disp, sid, at, model, role=role)
        want["wt-" + disp] = (session, rows)
        paths.append(path)
    mission.ledger([SLICE7[d]["complete"] for d in SLICE7])
    out = mission.tmp / "slice-listing.txt"
    cp = _tool("-MissionRoot", mission.root, "-List", "-Out", out, "-Trees", ",".join(str(p) for p in paths),
               "-Tip", mission.tip)
    assert cp.returncode == 0, cp.text
    _, blocks, _ = _blocks(out.read_text("utf-8"))
    for name, (session, rows) in want.items():
        assert blocks[name]["session"] == session, name
        assert blocks[name]["cited"] == [], blocks[name]["cited"]
        assert blocks[name]["entries"][:SLICE_N] == rows, name
        assert len(blocks[name]["entries"]) == SLICE_N, blocks[name]["entries"]


# ======================================================= (4) THE A-B, THE ELAPSED LINES, THE LEDGER READ ONCE ===
# HEAD's tool at the charter's tip -- the version before this cure -- read (below) and held to its pin, run beside this
# tree's over the module's three-tree mission.
# WHERE THE BASE IS READ, as the instruments read theirs: the installed fixture
# tests/lam/fixtures/base-700e19e5-s11/tools/lam/prune-worktrees.ps1.base and nothing else -- no git history is read. It
# is a synthetic base: that version's program, built from the framework's own file at the import commit 700e19e5 by the
# recipe tests/lam/fixtures/synthetic-bases.json. Held to the sha256 of its exact bytes; absent, or present and not at
# the pin, the test FAILS.
BASE_LABEL = "700e19e5-s11"
BASE_FIXTURE = _REPO / "tests" / "lam" / "fixtures" / ("base-" + BASE_LABEL) / "tools" / "lam" / "prune-worktrees.ps1.base"
BASE_FIXTURE_SHA256 = "57e5f3239f03e5f6985c766d419a48c9b6ee37eaa50bf2f26b94da4355d3dc3c"


def _base_tool(tmp):
    """The base tool's bytes, read as the comment above says, and where they came from."""
    assert BASE_FIXTURE.is_file(), "NOT READ: no fixture %s" % BASE_FIXTURE
    b = BASE_FIXTURE.read_bytes()
    assert _sha(b) == BASE_FIXTURE_SHA256, (
        "the fixture %s does NOT hold: sha256 %s, pin %s" % (BASE_FIXTURE, _sha(b), BASE_FIXTURE_SHA256))
    return b, "the fixture base-" + BASE_LABEL + ", the synthetic base"
ELAPSED = re.compile(r"^ELAPSED (\S+) (\d+\.\d{3}) s: ancestry (\d+\.\d{3}) s, walk (\d+\.\d{3}) s, "
                     r"session (\d+\.\d{3}) s, status (\d+\.\d{3}) s, digests (\d+\.\d{3}) s over (\d+) entries$")
CLOCK = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z")
LISTING = re.compile(r"^LISTING (.+): (\d+) lines, (\d+) B, sha256 ([0-9a-f]{64}), (\d+) entries$")


def test_list_ab_the_out_bytes_unchanged_and_one_elapsed_line_per_tree(listed, tmp_path):
    """-List prints one ELAPSED line per tree, to stdout only, as the tree finishes; nothing else moves. The
    rows are gathered and asserted together so that a RED names each one. RED at the charter's tip on the stdout and ELAPSED
    rows (HEAD's tool prints none); GREEN after the cure."""
    m = listed["m"]
    names = ["wt-D-W1", "wt-D-V-A-1", "wt-D-T1"]
    trees = ",".join(str(listed[k]) for k in ("w1", "va", "t1"))
    blob, _ = _base_tool(tmp_path)
    base_tool = tmp_path / "prune-worktrees.base.ps1"
    base_tool.write_bytes(blob)
    out, cp, data, stdout = {}, {}, {}, {}
    for side, tool in (("base", base_tool), ("tree", _TOOL)):
        (tmp_path / side).mkdir()
        out[side] = tmp_path / side / "listing.txt"
        cp[side] = _tool("-MissionRoot", m.root, "-List", "-Out", out[side], "-Trees", trees, "-Tip", m.tip, tool=tool)
        assert cp[side].returncode == 0, "%s: exit %d\n%s" % (side, cp[side].returncode, cp[side].text)
        data[side] = out[side].read_bytes()
        stdout[side] = cp[side].stdout.decode("utf-8").splitlines()
    lines = {side: data[side].decode("utf-8").split("\n") for side in data}
    stamp = {side: [LISTING.match(l) for l in stdout[side] if LISTING.match(l)] for side in stdout}

    def masked(side):
        return [LISTING.sub(r"LISTING <OUT>: \2 lines, \3 B, sha256 <SHA>, \5 entries", l) for l in stdout[side]
                if not l.startswith("ELAPSED ")]

    _, blocks, _ = _blocks(data["tree"].decode("utf-8"))
    elapsed = [l for l in stdout["tree"] if l.startswith("ELAPSED ")]
    forms = [ELAPSED.match(l) for l in elapsed]
    rows = {
        "-Out: the base's and the tree's byte-equal but for line 1's stamp":
            lines["base"][1:] == lines["tree"][1:] and
            CLOCK.sub("<CLOCK>", lines["base"][0]) == CLOCK.sub("<CLOCK>", lines["tree"][0]),
        "LISTING: each run's line names its own -Out file and that file's sha256":
            all(len(stamp[s]) == 1 and os.path.normcase(stamp[s][0].group(1)) == os.path.normcase(str(out[s])) and
                stamp[s][0].group(4) == _sha(data[s]) for s in stamp),
        "stderr: the base's and the tree's equal": cp["base"].stderr == cp["tree"].stderr,
        "stdout: the tree's = the base's + exactly one ELAPSED line per tree, in -Trees order, before the summary":
            [l.split(" ")[1] for l in elapsed] == names and stdout["tree"][:len(elapsed)] == elapsed and
            masked("tree") == masked("base"),
        "ELAPSED: every line in the form, over its tree's listed entries, its phases within its time":
            len(forms) == len(names) and all(forms) and all(
                f.group(1) in blocks and int(f.group(8)) == len(blocks[f.group(1)]["entries"]) and
                sum(float(f.group(i)) for i in range(3, 8)) <= float(f.group(2)) + 0.005 for f in forms),
        "ELAPSED: none in either -Out file": not any(l.startswith("ELAPSED") for s in lines for l in lines[s]),
    }
    report = "\n".join("%-5s %s" % (ok, why) for why, ok in rows.items())
    assert all(rows.values()), "%s\n--- base stdout\n%s\n--- tree stdout\n%s" % (
        report, "\n".join(stdout["base"]), "\n".join(stdout["tree"]))


# The counting harness for the ledger clause: the tool dot-sourced, Read-PwLedger wrapped by a counter, and
# -List driven through the tool's own Invoke-PwMain with its parameters set in this scope (the dot-source bound them to
# their defaults, so the harness keeps its arguments under other names first, as DOT_HARNESS does).
LEDGER_HARNESS = r"""param([string]$Tool, [string]$Root, [string]$OutFile, [string]$TreeList, [string]$TipCommit)
$ErrorActionPreference = 'Stop'
$harnessTool = $Tool
$harnessRoot = $Root
$harnessOut = $OutFile
$harnessTrees = $TreeList
$harnessTip = $TipCommit
. $harnessTool
$script:harnessReads = 0
$harnessRead = ${function:Read-PwLedger}
function Read-PwLedger {
    param([string]$Root)
    $script:harnessReads++
    $r = & $harnessRead -Root $Root
    return ,$r
}
$MissionRoot = $harnessRoot
$List = [switch]$true
$Out = $harnessOut
$Trees = @($harnessTrees)
$Tip = $harnessTip
$script:PwBound = @{ MissionRoot = $MissionRoot; List = $List; Out = $Out; Trees = $Trees; Tip = $Tip }
$rc = @(Invoke-PwMain)
Write-Output ('RC ' + $rc[$rc.Count - 1])
Write-Output ('LEDGER READS ' + $script:harnessReads)
Write-Output 'HARNESS DONE'
exit 0
"""


def test_list_reads_the_spawn_ledger_once_per_run(listed, tmp_path):
    """The second clause, MET AT THE CHARTER'S TIP: one read of the spawn ledger per run,
    before the tree loop, for three trees as for one -- counted over the module's mission, and its one call site
    pinned in the text. GREEN at the charter's tip and after; no index is built."""
    src = _TOOL.read_text(encoding="utf-8")
    assert len(re.findall(r"\bRead-PwLedger\b", src)) == 2, "Read-PwLedger: one definition and one call site"
    body = src[src.index("function Invoke-PwList {"):src.index("function Invoke-PwCopy {")]
    call = "$ledger = Read-PwLedger -Root $Root"
    assert body.count(call) == 1, "the call site is not Invoke-PwList's"
    loop = "\n    foreach ($t in $picked) {\n"                   # the tree loop's own line, not the out-file check's
    assert body.count(loop) == 1 and body.index(call) < body.index(loop), "the ledger is not read before the tree loop"
    assert src.count("'spawn-ledger.jsonl'") == 1, "one site names the spawn ledger's file in code"
    m = listed["m"]
    out = tmp_path / "ledger-listing.txt"
    harness = tmp_path / "ledger-harness.ps1"
    harness.write_text(LEDGER_HARNESS, encoding="utf-8")
    argv = [_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(harness), "-Tool", str(_TOOL),
            "-Root", str(m.root), "-OutFile", str(out),
            "-TreeList", ",".join(str(listed[k]) for k in ("w1", "va", "t1")), "-TipCommit", m.tip]
    cp = subprocess.run(argv, capture_output=True, timeout=300)
    text = (cp.stdout + cp.stderr).decode("utf-8", "replace")
    assert cp.returncode == 0 and re.search(r"^RC 0\r?$", text, re.M), text
    _, blocks, _ = _blocks(out.read_text("utf-8"))
    assert list(blocks) == ["wt-D-W1", "wt-D-V-A-1", "wt-D-T1"], list(blocks)
    assert blocks["wt-D-W1"]["session"][1] == _s4_spawn(W1_COMPLETE), "the counted read did not reach the listing"
    assert re.search(r"^LEDGER READS 1\r?$", text, re.M), text
