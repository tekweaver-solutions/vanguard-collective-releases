"""WP-7's group-B members (UI-2 S2; the S2 contract B-1..B-11): U-39 .. U-49, the API halves and the planted faces.

Run by tools\\.venv's interpreter with -I; prints one JSON object {"ok": bool, "detail": [lines], ...}. Every figure a
member asserts is DERIVED HERE FROM THE FIXTURE by this file's own reading -- the smoke mission's .mission files and git
history (regex, git), the hand-composed feeds' lines -- never by the snapshot writer's or the service's code, which are
what is under test: the writer through tests\\lam\\wp7-smoke-feed.ps1 (the replay), the service through
tests\\lam\\wp7-real-feed.py api.

  <member> <run-dir> [--smoke-root R] [--smoke-feed F]      member = u39 u40 u42 u44 u46 u48 u49 u50 (B-12) u51 (B-14)
  u52 <run-dir> <feed>                                      B-10's emitter: the verify card over a -Verify-written feed
  plant-face <member> <run-dir> [--smoke-feed F]            a scratch copy of ui/ with that member's face literal broken,
                                                            built to <run-dir>, its spec run over it (VG_W7_DIST): the
                                                            member's planted-RED is the spec failing there
"""
import datetime
import glob
import importlib.util
import json
import os
import re
import shutil
import statistics
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
FIXUI = os.path.join(REPO, "tests", "lam", "fixtures", "ui")
_spec = importlib.util.spec_from_file_location("w7rf", os.path.join(HERE, "wp7-real-feed.py"))
rf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rf)
PS = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")


# ---------------------------------------------------------------------------------------------- the fixture, read here
def scalar(text, key):
    m = re.findall(r"(?m)^%s:[ \t]*(.*?)[ \t]*$" % re.escape(key), text)
    if len(m) != 1:
        return None
    v = re.sub(r"(^|\s)#.*$", "", m[0]).strip().strip("\"'")
    return None if v in ("", "null", "~") else v


def id_list(text, key):
    m = re.search(r"(?m)^%s:\s*\[([^\]]*)\]" % re.escape(key), text)
    return [x.strip().strip("\"'") for x in m.group(1).split(",") if x.strip()] if m else []


def read_tree(files):
    """files: rel path -> text. The contract (id -> feature_id), the validator results [(attempt, ids, verdict, only)]."""
    contract, results = {}, []
    for p, t in files.items():
        if re.match(r"\.mission/contract/assertions/[^/]+\.yaml$", p):
            contract[scalar(t, "id") or os.path.basename(p)[:-5]] = scalar(t, "feature_id")
        elif re.match(r"\.mission/validator-results/[^/]+\.yaml$", p) and id_list(t, "assertion_ids"):
            v = (scalar(t, "verdict") or "").lower()
            results.append((int(scalar(t, "attempt_number") or 0), id_list(t, "assertion_ids"), v, scalar(t, "assertion_id")))
    return contract, results


def rounds_of(results):
    """round -> {id: 'confirmed'|'refuted'}: THE CONTRACT'S READING (B-4: round 1 reads 4 confirmed / 1 refuted): a pass
    confirms every id it lists; a fail naming one id refutes that one and confirms the rest it lists; a fail naming none
    refutes all it lists."""
    out = {}
    for att, ids, v, only in sorted(results, key=lambda r: r[0]):
        if att < 1 or v not in ("pass", "fail"):
            continue
        for i in ids:
            out.setdefault(att, {})[i] = "confirmed" if v == "pass" or (only and only != i) else "refuted"
    return out


def tree_files(root):
    out = {}
    for p in glob.glob(os.path.join(root, ".mission", "**", "*.yaml"), recursive=True):
        out[os.path.relpath(p, root).replace(os.sep, "/")] = open(p, encoding="utf-8").read()
    return out


def git(root, *a):
    return subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True, encoding="utf-8", check=True).stdout


def commit_files(root, c):
    out = {}
    for p in git(root, "ls-tree", "-r", "--name-only", c, ".mission").split("\n"):
        if p.endswith(".yaml") or p.endswith(".txt"):
            out[p] = git(root, "show", "%s:%s" % (c, p))
    return out


def iso(d):
    return datetime.datetime.fromisoformat(d.strip()).astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def secs(a, b):
    f = lambda x: datetime.datetime.strptime(x, "%Y-%m-%dT%H:%M:%S.%fZ")
    return (f(b) - f(a)).total_seconds()


def expect_features(contract, results):
    """feature -> {total, confirmed, refuted, unjudged, latest_round, verdict} from each assertion's latest round."""
    rs = rounds_of(results)
    out = {}
    for aid, fid in contract.items():
        mine = [r for r in rs if aid in rs[r]]
        v = rs[max(mine)][aid] if mine else None
        f = out.setdefault(fid, {"assertions_total": 0, "confirmed": 0, "refuted": 0, "unjudged": 0, "latest_round": None})
        f["assertions_total"] += 1
        f["confirmed" if v == "confirmed" else "refuted" if v == "refuted" else "unjudged"] += 1
        if mine:
            f["latest_round"] = max(f["latest_round"] or 0, max(mine))
    for f in out.values():
        n, c, r = f["assertions_total"], f["confirmed"], f["refuted"]
        f["verdict"] = "refuted" if r else "confirmed" if c == n else "unjudged" if c == 0 else "partial"
    return out


def expect_series(results, only=None):
    rs = rounds_of(results)
    out = []
    for r in sorted(rs):
        ids = {k: v for k, v in rs[r].items() if only is None or k in only}
        out.append({"round": r, "confirmed": sum(1 for v in ids.values() if v == "confirmed"), "refuted": sum(1 for v in ids.values() if v == "refuted"),
                    "refuted_ids": sorted(k for k, v in ids.items() if v == "refuted")})
    return out


def expect_milestone(root, mid):
    """B-8 from git: opened = the author date of the first first-parent commit whose mission.yaml names mid current while its
    assertions are not all confirmed; closed = the first whose every assertion of mid (the spec's list) reads confirmed in its
    latest round; dispatches = <id>.yaml first added (author date) within [opened, closed]."""
    commits = [c for c in git(root, "rev-list", "--first-parent", "--reverse", "HEAD").split("\n") if c]
    opened = closed = None
    for c in commits:
        fs = commit_files(root, c)
        cur = scalar(fs.get(".mission/mission.yaml", ""), "current_milestone")
        spec = fs.get(".mission/spec/spec-v1.yaml", "")
        blk = re.search(r"(?ms)^\s*-\s+id:\s*%s\b(.*?)(?=^\s*-\s+id:|^\S|\Z)" % re.escape(mid), spec.split("milestones:", 1)[-1])
        ids = id_list(blk.group(1).replace("    assertions:", "assertions:"), "assertions") if blk else []
        rs = rounds_of(read_tree(fs)[1])
        latest = {a: rs[max(r for r in rs if a in rs[r])][a] for a in ids if any(a in rs[r] for r in rs)}
        done = bool(ids) and all(latest.get(a) == "confirmed" for a in ids)
        d = iso(git(root, "log", "-1", "--format=%aI", c))
        if opened is None and cur == mid and not done:
            opened = d
        if closed is None and done:
            closed = d
    added = {}
    for c in commits:
        d = iso(git(root, "log", "-1", "--format=%aI", c))
        for p in git(root, "ls-tree", "--name-only", c, ".mission/dispatches/").split("\n"):
            b = os.path.basename(p)
            if re.match(r"^[^.]+\.yaml$", b):
                added.setdefault(b[:-5], d)
    within = sorted(k for k, d in added.items() if opened and closed and opened <= d <= closed)
    return {"opened_at": opened, "closed_at": closed, "elapsed_s": secs(opened, closed) if opened and closed else None, "dispatch_ids": within, "added": added}


# ---------------------------------------------------------------------------------------------- the service, read through the reader
def api(run, tag, feed, ui_tools=None, until=None):
    a = {"feed": feed}
    if until is not None:
        a["until_seq"] = until
    if ui_tools:
        a["ui_tools"] = ui_tools
    return rf.api(os.path.join(run, tag), **a)


def replay(run, smoke_root=None, tree=None, out=None):
    out = out or os.path.join(run, "replay-%s.jsonl" % (os.path.basename(tree) if tree else "smoke"))
    argv = [PS, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(HERE, "wp7-smoke-feed.ps1"), "-Out", out, "-Framework", REPO]
    argv += ["-Tree", tree] if tree else ["-SmokeRoot", smoke_root]
    r = subprocess.run(argv, capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise SystemExit("the replay failed: " + (r.stdout + r.stderr)[-400:])
    return out


def scratch_tree(run, smoke_root, name, edit):
    """A copy of the smoke root's .mission as it stands, under run/name/lam-smoke, with edit(path_of) applied."""
    dst = os.path.join(run, name, "lam-smoke")
    shutil.rmtree(os.path.dirname(dst), ignore_errors=True)
    shutil.copytree(os.path.join(smoke_root, ".mission"), os.path.join(dst, ".mission"), ignore=shutil.ignore_patterns("evidence", "gates"))
    edit(lambda rel: os.path.join(dst, rel.replace("/", os.sep)))
    return dst


def sub(path, pat, rep):
    t = open(path, encoding="utf-8").read()
    n = len(re.findall(pat, t))
    open(path, "w", encoding="utf-8", newline="").write(re.sub(pat, rep, t))
    return n


def plant_tools(run, name, rel, pat, rep):
    """A scratch copy of tools/ui (a planted-RED of the service), one pattern replaced; returns (tools dir, count)."""
    base = os.path.join(run, "plant-" + name)
    shutil.rmtree(base, ignore_errors=True)
    root = os.path.join(base, "tools")
    shutil.copytree(os.path.join(REPO, "tools", "ui"), os.path.join(root, "ui"), ignore=shutil.ignore_patterns("__pycache__", "tests"))
    # the service reads the schema beside its tools folder (ui.settings.schema_path): the copy carries it
    os.makedirs(os.path.join(base, "docs", "framework"))
    shutil.copy2(os.path.join(REPO, "docs", "framework", "mission-event.schema.json"), os.path.join(base, "docs", "framework"))
    return root, sub(os.path.join(root, "ui", rel), pat, rep)


def feats(m):
    return {f["feature_id"]: f for f in m.get("features", [])}


# ---------------------------------------------------------------------------------------------- the members
def u39(run, smoke_root, feed):
    d, ok = [], True
    contract, results = read_tree(tree_files(smoke_root))
    exp = expect_features(contract, results)
    got = feats(api(run, "u39a", feed)["mission"])
    for fid, e in sorted(exp.items()):
        g = (got.get(fid) or {}).get("rollup")
        good = g is not None and all(g.get(k) == e[k] for k in e)
        ok &= good
        d.append("smoke %s: derived %s; served %s -> %s" % (fid, e, g, good))
    nc = feats(api(run, "u39b", ":nocontract:")["mission"]).get("F-001") or {}
    r = nc.get("rollup") or {}
    good = r.get("assertions_total") == 0 and r.get("verdict") is None and nc.get("assertions") == []
    ok &= good
    d.append("a feed with no contract (:nocontract:): F-001 rollup %s (expect assertions_total 0, no verdict) -> %s" % (r or "(none)", good))
    # planted-RED: A-2's feature_id moved F-002 -> F-001 in a scratch copy; the roll-up moves by one
    n = []
    tree = scratch_tree(run, smoke_root, "u39p", lambda at: n.append(sub(at(".mission/contract/assertions/A-2.yaml"), r"(?m)^feature_id: F-002$", "feature_id: F-001")))
    pexp = expect_features(*read_tree(tree_files(tree)))
    pgot = feats(api(run, "u39c", replay(run, tree=tree))["mission"])
    moved = [(fid, (got.get(fid) or {}).get("rollup", {}).get("assertions_total"), (pgot.get(fid) or {}).get("rollup", {}).get("assertions_total")) for fid in sorted(exp)]
    good = n == [1] and all((pgot.get(f) or {}).get("rollup", {}).get("assertions_total") == pexp[f]["assertions_total"] for f in pexp) and \
        any(b is not None and a is not None and abs(b - a) == 1 for _, a, b in moved)
    ok &= good
    d.append("planted: A-2's feature_id F-002 -> F-001 in a scratch copy (%s replaced): assertions_total before/after %s; derived after %s -> %s"
             % (n, moved, {f: pexp[f]["assertions_total"] for f in pexp}, good))
    return ok, d


def u40(run, smoke_root, feed):
    d, ok = [], True
    contract, results = read_tree(tree_files(smoke_root))
    rs = rounds_of(results)
    m = api(run, "u40a", feed)["mission"]
    shape = all(set(["feature_id", "status", "assertions", "rollup"]) <= set(f) for f in m["features"]) and \
        all(set(["assertion_id", "status", "source", "verdict", "round"]) <= set(a) for f in m["features"] for a in f["assertions"])
    ok &= shape
    d.append("features[]: every entry keeps feature_id/status/assertions (1.2.0) and adds rollup; every assertion keeps assertion_id/status/source and adds verdict/round -> %s" % shape)
    for f in m["features"]:
        for a in f["assertions"]:
            mine = [r for r in rs if a["assertion_id"] in rs[r]]
            e = (rs[max(mine)][a["assertion_id"]], max(mine)) if mine else (None, None)
            good = (a["verdict"], a["round"]) == e and contract.get(a["assertion_id"]) == f["feature_id"]
            ok &= good
            d.append("  %s under %s: served %s round %s; derived %s round %s, contract feature %s -> %s" % (a["assertion_id"], f["feature_id"], a["verdict"], a["round"], e[0], e[1], contract.get(a["assertion_id"]), good))
    tools, n = plant_tools(run, "u40", "derive.py", r'return "confirmed" if result == "green" else "refuted" if result == "red" else None',
                           'return "refuted" if result == "green" else "confirmed" if result == "red" else None')
    pm = api(run, "u40b", feed, ui_tools=tools)["mission"]
    wrong = sum(1 for f in pm["features"] for a in f["assertions"] if (a["verdict"], a["round"]) != ((rs[a["round"]][a["assertion_id"]], a["round"]) if a["round"] else (None, None)))
    good = n == 1 and wrong > 0
    ok &= good
    d.append("planted: derive.judged's mapping inverted in a scratch copy of tools/ui (%d replaced): %d assertion verdict(s) now differ from the derived (expect > 0) -> %s" % (n, wrong, good))
    return ok, d


def u42(run, smoke_root, feed):
    d, ok = [], True
    contract, results = read_tree(tree_files(smoke_root))
    m = api(run, "u42a", feed)["mission"]
    vr = m.get("validator_rounds") or {}
    got = [{k: r[k] for k in ("round", "confirmed", "refuted", "refuted_ids")} for r in (vr.get("value") or [])]
    exp = expect_series(results)
    good = got == exp
    ok &= good
    d.append("the mission's rounds: served %s; derived %s -> %s" % (got, exp, good))
    targets = {}
    for p, t in tree_files(smoke_root).items():
        if re.match(r"\.mission/dispatches/[^/.]+\.yaml$", p):
            targets[scalar(t, "id")] = set(id_list(t, "assertion_targets"))
    for did in sorted(targets):
        g = [{k: r[k] for k in ("round", "confirmed", "refuted", "refuted_ids")} for r in (vr.get("by_dispatch") or {}).get(did, [])]
        e = [x for x in expect_series(results, targets[did]) if x["confirmed"] or x["refuted"]]
        g = [x for x in g if x["confirmed"] or x["refuted"]]
        good = g == e
        ok &= good
        d.append("  dispatch %s (targets %s): served %s; derived %s -> %s" % (did, sorted(targets[did]), g, e, good))
    n = []

    def flip(at):
        p = at(".mission/validator-results/val-b-attempt-2.yaml")
        n.append(sub(p, r"(?m)^verdict: pass$", "assertion_id: A-4\nverdict: fail"))
    tree = scratch_tree(run, smoke_root, "u42p", flip)
    pres = read_tree(tree_files(tree))[1]
    pv = (api(run, "u42b", replay(run, tree=tree))["mission"].get("validator_rounds") or {}).get("value") or []
    r2 = [r for r in pv if r["round"] == 2]
    e2 = [x for x in expect_series(pres) if x["round"] == 2]
    good = n == [1] and bool(r2) and (r2[0]["confirmed"], r2[0]["refuted"]) == (4, 1) == (e2[0]["confirmed"], e2[0]["refuted"])
    ok &= good
    d.append("planted: attempt 2's A-4 result flipped in a scratch copy (%s replaced): round 2 served %s (expect 4/1, derived %s) -> %s" % (n, r2, e2, good))
    return ok, d


def expect_halts(lines, clock):
    """B-6 from the fixture's lines by the stated precedence (the member's own reading)."""
    objs = [json.loads(l) for l in lines]
    snap = [o for o in objs if o["kind"] == "mission_snapshot"]
    art = (snap[-1]["payload"].get("halts") or {}) if snap else {}
    raised = {o["payload"]["halt_id"]: o["ts"] for o in objs if o["kind"] == "halt_raised"}
    res = {o["payload"]["halt_id"]: (o["ts"], o["payload"]["resolution"]) for o in objs if o["kind"] == "halt_resolved"}
    rows = {}
    for h in sorted(set(raised) | set(art)):
        a = art.get(h, {})
        r = a["raised_at"] if a.get("raised_basis") == "stamp" else raised.get(h) or a.get("raised_at")
        answered = (h in res and res[h][1] in ("ANSWERED", "RESOLVED")) or a.get("state") == "answered"
        an = None
        if answered:
            an = a["answered_at"] if a.get("answered_basis") == "stamp" else (res[h][0] if h in res and res[h][1] in ("ANSWERED", "RESOLVED") else a.get("answered_at"))
        rows[h] = (r, an, answered)
    spans = [secs(r, an) for r, an, ans in rows.values() if ans and r and an]
    opn = [(secs(r, clock), h) for h, (r, an, ans) in rows.items() if not ans and r]
    return {"open": sum(1 for v in rows.values() if not v[2]), "answered": sum(1 for v in rows.values() if v[2]),
            "mean_ttr_s": round(sum(spans) / len(spans), 3) if spans else None, "median_ttr_s": round(statistics.median(spans), 3) if spans else None,
            "oldest": max(opn)[0] if opn else None}


def u44(run, smoke_root, feed):
    d, ok = [], True
    src = os.path.join(FIXUI, "h6.jsonl")
    lines = rf.lines_of(src)
    clock = max(json.loads(l)["ts"] for l in lines)
    e = expect_halts(lines, clock)
    h = api(run, "u44a", src)["mission"]["halt_card"]
    g = {"open": h["open"], "answered": h["answered"], "mean_ttr_s": h["mean_ttr_s"], "median_ttr_s": h["median_ttr_s"], "oldest": (h["oldest_open"] or {}).get("age_s")}
    good = g == e and e["open"] == 1 and e["answered"] == 2
    ok &= good
    d.append("h6 (three HALTs, two answered at known stamps, one open): served %s; derived %s -> %s" % (g, e, good))
    s = api(run, "u44b", feed)["mission"]["halt_card"]
    good = (s["open"], s["answered"], s["mean_ttr_s"], s["median_ttr_s"]) == (0, 0, None, None)
    ok &= good
    d.append("the smoke fixture (no HALT): open %s, answered %s, mean %s (expect 0 / 0 / no data) -> %s" % (s["open"], s["answered"], s["mean_ttr_s"], good))
    moved = [l.replace('"ts":"2026-03-01T11:00:00.000Z","kind":"halt_resolved"', '"ts":"2026-03-01T12:00:00.000Z","kind":"halt_resolved"') for l in lines]
    pf = os.path.join(run, "u44-plant.jsonl")
    open(pf, "w", encoding="utf-8", newline="\n").write("\n".join(moved) + "\n")
    pe = expect_halts(moved, clock)
    ph = api(run, "u44c", pf)["mission"]["halt_card"]
    good = moved != lines and ph["mean_ttr_s"] == pe["mean_ttr_s"] and ph["mean_ttr_s"] - h["mean_ttr_s"] == 1800
    ok &= good
    d.append("planted: HALT-SYN-01's answered stamp moved by an hour: mean %s -> %s (derived %s; expect +1800 s, half the hour over two answered) -> %s" % (h["mean_ttr_s"], ph["mean_ttr_s"], pe["mean_ttr_s"], good))
    return ok, d


def u46(run, smoke_root, feed):
    d, ok = [], True
    e = expect_milestone(smoke_root, "M-1")
    rows = {r["id"]: r for r in (api(run, "u46a", feed)["mission"]["milestone_timing"]["value"] or [])}
    g = rows.get("M-1") or {}
    good = (g.get("opened_at"), g.get("closed_at"), g.get("elapsed_s"), g.get("running"), g.get("dispatch_ids")) == (e["opened_at"], e["closed_at"], e["elapsed_s"], False, e["dispatch_ids"])
    ok &= good
    d.append("M-1 over the smoke replay: served opened %s closed %s elapsed %s running %s dispatches %s; derived from git %s / %s / %s / %s -> %s"
             % (g.get("opened_at"), g.get("closed_at"), g.get("elapsed_s"), g.get("running"), g.get("dispatch_ids"), e["opened_at"], e["closed_at"], e["elapsed_s"], e["dispatch_ids"], good))
    objs = [json.loads(l) for l in rf.lines_of(feed)]
    cut = max(o["seq"] for o in objs if o["ts"] < e["closed_at"])
    clock = max(o["ts"] for o in objs if o["seq"] <= cut)
    run_ = {r["id"]: r for r in (api(run, "u46b", feed, until=cut)["mission"]["milestone_timing"]["value"] or [])}.get("M-1") or {}
    within = sorted(k for k, dd in e["added"].items() if e["opened_at"] <= dd <= clock)
    good = run_.get("running") is True and run_.get("closed_at") is None and run_.get("elapsed_s") == secs(e["opened_at"], clock) and run_.get("dispatch_ids") == within
    ok &= good
    d.append("the feed cut at seq %d (before M-1 passed): running %s, elapsed %s (derived %s against the feed's clock %s), dispatches %s (derived %s) -> %s"
             % (cut, run_.get("running"), run_.get("elapsed_s"), secs(e["opened_at"], clock), clock, run_.get("dispatch_ids"), within, good))
    closer = min(o["seq"] for o in objs if o["ts"] == e["closed_at"])
    moved = [json.dumps(dict(o, ts="2026-01-01T01:12:00.000Z") if o["seq"] == closer else o, ensure_ascii=False, separators=(",", ":")) for o in objs]
    pf = os.path.join(run, "u46-plant.jsonl")
    open(pf, "w", encoding="utf-8", newline="\n").write("\n".join(moved) + "\n")
    p = {r["id"]: r for r in (api(run, "u46c", pf)["mission"]["milestone_timing"]["value"] or [])}.get("M-1") or {}
    good = p.get("elapsed_s") is not None and g.get("elapsed_s") is not None and p["elapsed_s"] != g["elapsed_s"] and p["elapsed_s"] == secs(e["opened_at"], "2026-01-01T01:12:00.000Z")
    ok &= good
    d.append("planted: the closing snapshot (seq %d) restamped 2026-01-01T01:12:00.000Z: elapsed %s -> %s -> %s" % (closer, g.get("elapsed_s"), p.get("elapsed_s"), good))
    return ok, d


def expect_verify(path):
    o = json.loads(rf.lines_of(path)[-1])
    lst = o["payload"].get("divergence_list") or []
    kinds = {"changed", "missing", "extra", "kept-differs"}
    return [(x["path"], x["kind"]) for x in lst if x["kind"] in kinds]


def u48(run, smoke_root, feed):
    d, ok = [], True
    for tag, name in (("u48a", "v10.jsonl"), ("u48b", "v10-clean.jsonl")):
        src = os.path.join(FIXUI, name)
        e = expect_verify(src)
        v = api(run, tag, src)["mission"]["verify_card"]
        g = [(x["path"], x["kind"]) for x in (v["listed"] or [])]
        good = g == e and v["count"] == len(e)
        ok &= good
        d.append("%s: served %d listed %s; derived %d %s -> %s" % (name, v["count"], g, len(e), e, good))
    tools, n = plant_tools(run, "u48", "derive.py", r'DIVERGENCE_KINDS = \{"changed": "changed", "missing": "missing", ', 'DIVERGENCE_KINDS = {"changed": "changed", ')
    pv = api(run, "u48c", os.path.join(FIXUI, "v10.jsonl"), ui_tools=tools)["mission"]["verify_card"]
    good = n == 1 and pv["count"] == 2
    ok &= good
    d.append("planted: missing dropped from the kinds map in a scratch copy of tools/ui (%d replaced): the card reads %s (expect 2) -> %s" % (n, pv["count"], good))
    return ok, d


def u49(run, smoke_root, feed):
    d, ok = [], True
    st = api(run, "u49a", feed)["stats"]
    f = st.get("face") or {}
    keys = ("sessions", "dispatches", "validator_rounds", "halt_card", "milestone_timing", "verify_card", "tail_window_bytes", "framework")
    good = all(k in f for k in keys) and f["sessions"]["value"] is None and f["verify_card"]["value"] is None and f["validator_rounds"]["value"] is not None
    ok &= good
    d.append("the smoke replay's /stats face: cards %s; sessions %s and verify %s (no such line on the feed: expect no data, never 0); rounds %s -> %s"
             % ([k for k in keys if k in f], f.get("sessions", {}).get("value"), f.get("verify_card", {}).get("value"), (f.get("validator_rounds") or {}).get("value") is not None, good))
    nf = api(run, "u49b", ":nocontract:")["stats"].get("face") or {}
    good = all((nf.get(k) or {}).get("value") is None for k in ("sessions", "validator_rounds", "verify_card", "dispatches", "milestone_timing"))
    ok &= good
    d.append("a feed of one snapshot and no session, verify, dispatch or round (:nocontract:): those cards read no data -> %s" % good)
    return ok, d


def expect_subagent_calls(lines):
    """B-12, derived from the composed lines themselves: parent session id -> [(agent_id, agent_type, calls)] in order
    of first call, over the tool_call lines whose payload carries agent_id."""
    out = {}
    for l in lines:
        o = json.loads(l)
        p = o.get("payload") or {}
        if o["kind"] != "tool_call" or not p.get("agent_id"):
            continue
        rows = out.setdefault(p["session_id"], {})
        r = rows.setdefault(p["agent_id"], [p["agent_id"], None, 0, o["seq"]])
        r[1] = p.get("agent_type") or r[1]
        r[2] += 1
    return {s: [tuple(r[:3]) for r in sorted(rows.values(), key=lambda r: r[3])] for s, rows in out.items()}


def served_subagent_calls(m):
    h = (m.get("mission") or {}).get("header") or {}
    return {s: [(r["agent_id"], r["agent_type"], r["calls"]) for r in rows] for s, rows in (h.get("subagent_calls") or {}).items()}


def u50(run, smoke_root, feed):
    """B-12 (decision 11): the subagent's own tool_call lines carry agent_id / agent_type, and /api/missions/{id}'s
    header.subagent_calls attributes them to that subagent under its parent. The hook half (the PostToolUse hook given a
    subagent's payload, and its planted copy) is WP-7's, in the U fixture."""
    d, ok = [], True
    e = expect_subagent_calls(rf.cured_agent_feed())
    g = served_subagent_calls(api(run, "u50a", ":cured-agent:"))
    good = g == e and len(e) == 1 and sum(r[2] for rows in e.values() for r in rows) == 2
    ok &= good
    d.append(":cured-agent: (the subagent's Read and SubagentHandback carry its agent_id): served %s; derived %s -> %s" % (g, e, good))
    e6 = expect_subagent_calls(rf.cured_agent_feed()[:6])
    g6 = served_subagent_calls(api(run, "u50b", ":cured-agent:", until=6))
    good = g6 == e6 and g6 == e
    ok &= good
    d.append(":cured-agent: cut at seq 6 (the parent still running, as the face reads it): served %s; derived %s -> %s" % (g6, e6, good))
    e0 = expect_subagent_calls(rf.cured_feed())
    g0 = served_subagent_calls(api(run, "u50c", ":cured:"))
    good = g0 == e0 == {}
    ok &= good
    d.append(":cured: (the same calls with no agent_id, the 1.3.0-S1 hook's shape): served %s; derived %s (expect none attributed) -> %s" % (g0, e0, good))
    tools, n = plant_tools(run, "u50", "derive.py", r'aid, sid = p\.get\("agent_id"\), p\.get\("session_id"\)', 'aid, sid = p.get("agent"), p.get("session_id")')
    pg = served_subagent_calls(api(run, "u50d", ":cured-agent:", ui_tools=tools))
    good = n == 1 and pg == {}
    ok &= good
    d.append("planted: the agent_id key misread in a scratch copy of tools/ui (%d replaced): served %s (expect none attributed) -> %s" % (n, pg, good))
    return ok, d


def two_turn_expect(lines):
    """B-14, derived from the composed lines: the session, its turn ends (the seqs of its dispatch_finalized lines, each a
    turn's Stop), and for a cut at seq c whether the session reads running -- started, and no session_stop of it at or
    before c."""
    objs = [json.loads(l) for l in lines]
    sid = next(o["payload"]["session_id"] for o in objs if o["kind"] == "session_start")
    ends = [o["seq"] for o in objs if o["kind"] == "dispatch_finalized"]
    running = lambda c: any(o["kind"] == "session_start" and o["seq"] <= c for o in objs) and not any(
        o["kind"] == "session_stop" and o["seq"] <= c and o["payload"].get("session_id") == sid for o in objs)
    return sid, ends, running, max(o["seq"] for o in objs)


def u51(run, smoke_root, feed):
    """B-14 (register row 528): an interactive session of two turns reads running between its turns and stopped only after
    the one session_stop SessionEnd says. Over :two-turn: (the B-14 hooks' shape) and :two-turn-s1: (UI-2 S1's, a
    session_stop at each turn's Stop), the API's open_sessions at each turn end and whole equals the reading derived here
    from the lines. The hook half (Stop says no session_stop, SessionEnd says it, the template registers SessionEnd, and a
    Stop copy that says session_stop again) is WP-7's, in the U fixture."""
    d, ok = [], True
    for name, fn in ((":two-turn:", rf.two_turn_feed), (":two-turn-s1:", rf.two_turn_s1_feed)):
        sid, ends, running, last = two_turn_expect(fn())
        for c in sorted(set(ends + [last])):
            m = api(run, "u51-%s-%d" % (name.strip(":"), c), name, until=c)["mission"]
            h = m.get("header") or {}
            served = sid in ((h.get("open_sessions") or {}).get("ids") or [])
            early = (h.get("stopped_early") or {}).get("count")
            good = served == running(c)
            ok &= good
            d.append("%s cut at seq %d (%s): the session served %s; derived %s; stopped early %s -> %s"
                     % (name, c, "a turn's end" if c != last else "the whole feed", "running" if served else "not running", "running" if running(c) else "stopped", early, good))
    sid, ends, running, last = two_turn_expect(rf.two_turn_feed())
    good = running(ends[0]) and not running(last)
    ok &= good
    d.append(":two-turn: reads running between its turns and stopped after SessionEnd's session_stop (derived): %s" % good)
    sid, ends, running, last = two_turn_expect(rf.two_turn_s1_feed())
    good = not running(ends[0])
    ok &= good
    d.append(":two-turn-s1: (UI-2 S1's Stop) reads stopped between its turns (derived): %s -- the shape B-14 cures" % good)
    return ok, d


def u52(run, smoke_root, feed):
    """B-10's emitter (open decision 2, ruled): over the feed of WP-7's registered project after install.ps1 -Verify read
    one file changed and one removed, the API's verify card and header.last_verify list what the feed's latest
    verify_result lists -- derived here from that line (kinds lowercased, kept-equal not listed) -- and read 2."""
    d, ok = [], True
    lines = [json.loads(l) for l in rf.lines_of(feed)]
    vr = [o for o in lines if o["kind"] == "verify_result"]
    if not vr:
        return False, ["the registered project's feed holds no verify_result line: -Verify wrote none"]
    last = vr[-1]["payload"]
    e = sorted((x["path"], str(x["kind"]).lower()) for x in last.get("divergence_list") or [] if str(x["kind"]).lower() != "kept-equal")
    m = api(run, "u52a", feed)["mission"]
    v = m["verify_card"]
    g = sorted((x["path"], x["kind"]) for x in (v.get("listed") or []))
    lv = (m.get("header") or {}).get("last_verify") or {}
    good = g == e and v["count"] == len(e) == 2 and lv.get("divergences") == 2 and len(lv.get("divergence_list") or []) == 2
    ok &= good
    d.append("the registered project's feed (%d verify_result line(s)): the card served %s listed %s, header.last_verify divergences %s; derived from the latest line %d %s -> %s"
             % (len(vr), v["count"], g, lv.get("divergences"), len(e), e, good))
    return ok, d


MEMBERS = {"u39": u39, "u40": u40, "u42": u42, "u44": u44, "u46": u46, "u48": u48, "u49": u49, "u50": u50, "u51": u51, "u52": u52}

# ---------------------------------------------------------------------------------------------- the planted faces
FACE_PLANTS = {  # member -> (spec, source file under ui/src, pattern, replacement): one literal broken per face
    "u41": ("u41", "components/GroupB.tsx", r'refuted: "Refuted", partial', 'refuted: "Confirmed", partial'),
    "u43": ("u43", "components/GroupB.tsx", r'data-refuted=\{r\.refuted\}', "data-refuted={r.confirmed}"),
    "u45": ("u45", "components/GroupB.tsx", r'\{count\(h\.open\)\}', "{count(h.answered)}"),
    "u47": ("u47", "components/GroupB.tsx", r'data-dispatch-count=\{m\.dispatch_count \?\? "none"\}', "data-dispatch-count={m.dispatch_ids.length + 1}"),
    "u48": ("u48", "components/GroupB.tsx", r'data-kind=\{d\.kind\}', 'data-kind={d.kind === "missing" ? "changed" : d.kind}'),
    "u49": ("u49", "components/GroupB.tsx", r'<div data-face-card="halts">', '<div data-face-card="halt">'),
    "u50": ("u50", "pages/ProjectPage.tsx", r'data-subagent-calls=\{a\.calls\}', "data-subagent-calls={a.calls + 1}"),
}


def plant_face(member, run, smoke_feed):
    spec, rel, pat, rep = FACE_PLANTS[member]
    ui = os.path.join(REPO, "ui")
    cp = os.path.join(run, "plant-ui-" + member)
    shutil.rmtree(cp, ignore_errors=True)
    shutil.copytree(ui, cp, ignore=shutil.ignore_patterns("node_modules", "dist", "test-results", "tests"))
    subprocess.run(["cmd.exe", "/d", "/c", "mklink", "/J", os.path.join(cp, "node_modules"), os.path.join(ui, "node_modules")], capture_output=True, check=True)
    n = sub(os.path.join(cp, "src", rel.replace("/", os.sep)), pat, rep)
    dist = os.path.join(run, "plant-dist-" + member)
    b = subprocess.run(["node", os.path.join(cp, "node_modules", "vite", "bin", "vite.js"), "build", "--outDir", dist, "--emptyOutDir"], cwd=cp, capture_output=True, text=True, encoding="utf-8")
    subprocess.run(["cmd.exe", "/d", "/c", "rmdir", os.path.join(cp, "node_modules")], capture_output=True)
    if b.returncode != 0:
        return {"ok": False, "detail": ["the planted build failed: " + (b.stdout + b.stderr)[-300:]]}
    rep_ = os.path.join(run, "pw-plant-%s.json" % member)
    env = dict(os.environ, VG_W7_DIST=dist, PLAYWRIGHT_JSON_OUTPUT_NAME=rep_, FORCE_COLOR="0", CI="1")
    if smoke_feed:
        env["W7_SMOKE_FEED"] = smoke_feed
    subprocess.run(["node", os.path.join(ui, "node_modules", "@playwright", "test", "cli.js"), "test", "tests/%s.spec.ts" % spec], cwd=ui, env=env, capture_output=True, text=True, encoding="utf-8")
    passed = failed = 0
    if os.path.isfile(rep_):
        st = json.load(open(rep_, encoding="utf-8")).get("stats") or {}
        passed, failed = st.get("expected", 0), st.get("unexpected", 0)
    ok = n == 1 and failed > 0
    return {"ok": ok, "replaced": n, "passed": passed, "failed": failed,
            "detail": ["planted face: %s in a scratch copy of ui/src (%d replaced), built and served: ui/tests/%s.spec.ts %d passed, %d failed (expect a failure) -> %s"
                       % (rel, n, spec, passed, failed, ok)]}


def main(argv):
    opts, rest, i = {}, [], 0
    while i < len(argv):
        if argv[i] in ("--smoke-root", "--smoke-feed"):
            opts[argv[i][2:].replace("-", "_")] = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    if rest[0] == "plant-face":
        os.makedirs(rest[2], exist_ok=True)
        return plant_face(rest[1], rest[2], opts.get("smoke_feed"))
    run = rest[1]
    os.makedirs(run, exist_ok=True)
    if rest[0] == "u52":  # its feed is WP-7's registered project's, named after the run dir
        ok, d = u52(run, None, rest[2])
        return {"ok": bool(ok), "detail": d}
    feed = opts.get("smoke_feed")
    if not feed and opts.get("smoke_root"):
        feed = replay(run, smoke_root=opts["smoke_root"])
    ok, d = MEMBERS[rest[0]](run, opts.get("smoke_root"), feed)
    return {"ok": bool(ok), "detail": d}


if __name__ == "__main__":
    try:
        out = main(sys.argv[1:])
    except SystemExit as e:
        out = {"ok": False, "detail": ["the member could not run: %s" % e]}
    except Exception as e:  # a member that cannot read its fixture or the service fails, it never passes
        out = {"ok": False, "detail": ["the member threw: %s: %s" % (type(e).__name__, e)]}
    sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
