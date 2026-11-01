"""The upgrade prediction names the manifest the release tag will carry (tools/provenance/upgrade-diff.py).

THE FINDING. The prediction for 0.1.1 -> 0.2.0 named the new manifest by the sha256 of its FILE, read at the commit the
prediction was made from. Every later commit re-measured a record -- the prediction document's own record first -- so
the manifest at the tag's commit had another sha256, and the document named a manifest the tag does not carry. Naming
the whole file cannot be cured by regenerating later: the document is itself a tracked file with a manifest record, so
the manifest at the commit that holds the document records the document's sha256.

THE CURE THESE TESTS HOLD.
- The prediction names each manifest by the digest of its installer-owned records' destination, class, sha256, bytes
  and eol, which a commit changing only AUTHORED records or reasons leaves unchanged; `--digest <manifest>` prints it.
- A manifest that is a git work tree's provenance/manifest.jsonl, and the --repo checkout's own, must equal HEAD's: a
  working tree whose manifest differs from HEAD's is refused, by name, and nothing is written -- with --repo naming a
  folder below the work tree's top, and with an inherited GIT_DIR naming another repository, too.

HERMETIC. Each case builds a scratch repository under tmp_path holding only provenance/manifest.jsonl, with no system
git configuration, no signing and an empty hooks folder; every record's eol is LF, so the tool reads no blob beyond the
manifests. The tool is run as the tracked file, with `python -I`.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parents[3]                        # the repository root
_TOOL = _REPO / "tools" / "provenance" / "upgrade-diff.py"
_HEADER = {"manifest": "provenance", "host_base": "0" * 40, "lam_smoke_base": "1" * 40}


def _rec(dest, cls, sha, source="host", reason="a record"):
    return {"source": source, "path": dest, "class": cls, "blob": None, "sha256": sha, "bytes": 10, "eol": "LF",
            "bom": False, "destination": dest, "reason": reason, "flags": []}


_OLD = [_rec("tools/a.ps1", "MOVE", "a" * 64), _rec("tools/b.ps1", "MOVE", "b" * 64),
        _rec("tools/t.yaml", "TEMPLATE", "c" * 64), _rec("NOTES.md", "AUTHORED", "d" * 64, source="authored")]
_NEW = [_rec("tools/a.ps1", "MOVE", "e" * 64), _rec("tools/b.ps1", "MOVE", "b" * 64),
        _rec("tools/n.ps1", "MOVE", "f" * 64), _rec("tools/t.yaml", "TEMPLATE", "c" * 64),
        _rec("NOTES.md", "AUTHORED", "d" * 64, source="authored")]


def _text(records):
    return "".join(json.dumps(r, separators=(",", ":")) + "\n" for r in [_HEADER] + records).encode("utf-8")


def _env(**extra):
    env = dict((k, v) for k, v in os.environ.items() if not k.upper().startswith("GIT_"))
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env.update(extra)
    return env


def _git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, env=_env()).stdout


def _tool(*args, env=None):
    return subprocess.run([sys.executable, "-I", str(_TOOL), *[str(a) for a in args]], capture_output=True,
                          env=env if env is not None else _env())


class Scratch:
    """A git work tree whose only file is provenance/manifest.jsonl: OLD committed and tagged, then NEW committed."""

    def __init__(self, tmp_path):
        self.root = tmp_path / "repo"
        self.manifest = self.root / "provenance" / "manifest.jsonl"
        self.manifest.parent.mkdir(parents=True)
        hooks = tmp_path / "no-hooks"
        hooks.mkdir()
        _git(self.root.parent, "init", "-q", "-b", "main", str(self.root))
        for key, value in (("user.name", "t"), ("user.email", "t@example.invalid"), ("core.autocrlf", "false"),
                           ("commit.gpgsign", "false"), ("tag.gpgsign", "false"), ("core.hooksPath", str(hooks))):
            _git(self.root, "config", key, value)
        self.commit(_OLD, "old release")
        _git(self.root, "tag", "v-old")
        self.commit(_NEW, "new release")
        self.old_copy = tmp_path / "old.jsonl"                      # outside any work tree
        self.old_copy.write_bytes(_text(_OLD))
        self.out = tmp_path / "prediction.md"

    def commit(self, records, message):
        self.manifest.write_bytes(_text(records))
        _git(self.root, "add", "-A")
        _git(self.root, "commit", "-q", "-m", message)

    def head_manifest(self):
        return _git(self.root, "cat-file", "blob", "HEAD:provenance/manifest.jsonl")

    def dirty(self):
        """The working tree's manifest edited after HEAD: one AUTHORED record's reason extended, nothing else."""
        records = [dict(r) for r in _NEW]
        records[-1]["reason"] += "; edited after the commit"
        self.manifest.write_bytes(_text(records))


def _digest(path):
    p = _tool("--digest", path)
    assert p.returncode == 0, p.stderr.decode()
    m = re.fullmatch(rb"installer-owned (\d+)  records sha256 ([0-9a-f]{64})\n", p.stdout)
    assert m, "the --digest line, one line ended by LF: %r" % p.stdout
    return m.group(2).decode("ascii")


def test_a_dirty_working_tree_manifest_is_refused_by_name_and_nothing_is_written(tmp_path):
    s = Scratch(tmp_path)
    s.dirty()
    p = _tool(s.old_copy, s.manifest, "--old-version", "0.1.0", "--out", s.out)
    err = p.stderr.decode()
    assert p.returncode == 1, (p.returncode, err)
    assert "differs from HEAD" in err, err
    assert hashlib.sha256(s.manifest.read_bytes()).hexdigest() in err, err
    assert hashlib.sha256(s.head_manifest()).hexdigest() in err, err
    assert not s.out.exists()
    # An inherited GIT_DIR naming another repository does not make git answer for that one instead.
    other = tmp_path / "other"
    _git(tmp_path, "init", "-q", str(other))
    p = _tool(s.old_copy, s.manifest, "--old-version", "0.1.0", "--out", s.out, env=_env(GIT_DIR=str(other / ".git")))
    assert p.returncode == 1 and "differs from HEAD" in p.stderr.decode(), (p.returncode, p.stderr.decode())
    assert not s.out.exists()


def test_the_repo_checkouts_dirty_manifest_is_refused_even_when_the_manifests_given_are_committed(tmp_path):
    s = Scratch(tmp_path)
    new_copy = tmp_path / "new.jsonl"
    new_copy.write_bytes(s.head_manifest())
    s.dirty()
    for repo in (s.root, s.root / "provenance"):                    # the top, and a folder below it
        p = _tool(s.old_copy, new_copy, "--old-version", "0.1.0", "--repo", repo, "--old-rev", "v-old",
                  "--new-rev", "HEAD", "--out", s.out)
        assert p.returncode == 1, (repo, p.returncode, p.stderr.decode())
        assert "differs from HEAD" in p.stderr.decode(), repo
        assert not s.out.exists()


def test_the_prediction_names_the_records_digest_and_the_next_authored_commit_keeps_it(tmp_path):
    s = Scratch(tmp_path)
    p = _tool(s.old_copy, s.manifest, "--old-version", "0.1.0", "--new-version", "0.2.0", "--out", s.out)
    assert p.returncode == 0, p.stderr.decode()
    doc = s.out.read_text(encoding="utf-8")
    assert "planned: written=2 already-identical=1 kept=1 retired=0 refused=0" in doc
    named = _digest(s.manifest)
    assert named in doc
    file_sha_then = hashlib.sha256(s.manifest.read_bytes()).hexdigest()
    assert file_sha_then not in doc, "the new manifest's file sha256 is the number a later commit makes stale"
    # The next commit, as a release seat makes it: the document tracked, with an AUTHORED record of its own.
    (s.root / "prediction.md").write_bytes(s.out.read_bytes())
    s.commit(_NEW + [_rec("prediction.md", "AUTHORED", hashlib.sha256(s.out.read_bytes()).hexdigest(),
                          source="authored")], "the prediction")
    assert hashlib.sha256(s.head_manifest()).hexdigest() != file_sha_then
    tag_copy = tmp_path / "tag.jsonl"
    tag_copy.write_bytes(s.head_manifest())
    assert _digest(tag_copy) == named


def test_a_root_gitattributes_new_in_the_release_reads_not_written(tmp_path):
    """install.ps1 writes the root .gitattributes on a fresh install only -- an upgrade adds none where
    the project has none -- so a TEMPLATE .gitattributes the old release did not own reads not-written, written by no
    one; one the old release owned reads kept, as any template."""
    attrs = _rec(".gitattributes", "TEMPLATE", "9" * 64)
    old, new, out = tmp_path / "old.jsonl", tmp_path / "new.jsonl", tmp_path / "prediction.md"
    old.write_bytes(_text(_OLD))
    new.write_bytes(_text(_NEW + [attrs]))
    p = _tool(old, new, "--old-version", "0.1.0", "--out", out)
    assert p.returncode == 0, p.stderr.decode()
    doc = out.read_text(encoding="utf-8")
    assert "planned: written=2 already-identical=1 kept=1 not-written=1 retired=0 refused=0" in doc, doc
    assert "| `.gitattributes` | -- | template | not-written |" in doc, doc
    assert "- `.gitattributes`\n" not in doc, "a not-written file is no path the host's diff names"
    both = tmp_path / "both.jsonl"
    both.write_bytes(_text(_OLD + [attrs]))
    p = _tool(both, new, "--old-version", "0.1.0", "--out", out)
    assert p.returncode == 0, p.stderr.decode()
    doc = out.read_text(encoding="utf-8")
    assert "planned: written=2 already-identical=1 kept=2 retired=0 refused=0" in doc, doc
    assert "not-written=" not in doc and "| not-written |" not in doc, doc


def test_the_digest_moves_with_an_installer_owned_record_and_with_nothing_else(tmp_path):
    base = tmp_path / "base.jsonl"
    base.write_bytes(_text(_NEW))
    d0 = _digest(base)
    variants = {
        "a MOVE record's sha256": (lambda r: r.update(sha256="9" * 64), 0, True),
        "a MOVE record's bytes": (lambda r: r.update(bytes=11), 0, True),
        "a MOVE record's eol": (lambda r: r.update(eol="CRLF"), 1, True),
        "a MOVE record's destination": (lambda r: r.update(destination="tools/a2.ps1"), 0, True),
        "a TEMPLATE record's class": (lambda r: r.update({"class": "MOVE"}), 3, True),
        "a MOVE record's reason": (lambda r: r.update(reason="another reason"), 1, False),
        "a MOVE record's flags": (lambda r: r.update(flags=["a flag"]), 2, False),
        "an AUTHORED record's sha256": (lambda r: r.update(sha256="8" * 64), 4, False),
    }
    for n, (name, (change, index, moves)) in enumerate(variants.items()):
        records = [dict(r) for r in _NEW]
        change(records[index])
        f = tmp_path / ("v%d.jsonl" % n)
        f.write_bytes(_text(records))
        assert (_digest(f) != d0) is moves, name
