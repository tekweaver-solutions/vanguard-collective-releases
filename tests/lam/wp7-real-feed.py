"""WP-7's reader of the real-feed fixture (RELEASE-4 S1, group P): tests/lam/fixtures/real-feed, read through the service.

Run by tools\\.venv's interpreter with -I; prints one JSON object on stdout. Never writes the fixture: a plant goes into
the per-run home's own copy of a feed.

  validate <jsonl>...                 every line against docs/framework/mission-event.schema.json, by tools/ui/schema.py:
                                      {"files": {name: {"lines": n, "errors": [[line, reason], ...]}}}
  home <dir> [plants]                 a VANGUARD_HOME at <dir> (removed first): projects.yaml with one row per feed (the
                                      worktree's and the primary's), each feed copied to <checkout>/.mission-runtime/
                                      telemetry/events.jsonl. {"home": dir, "mission_id": ..., "stop_session": ...}
  api <dir> [plants]                  home, then `vanguard ui --home <dir>` on a free 127.0.0.1 port, then /api/missions
                                      and /api/missions/{id}: {"home", "mission_id", "missions": ..., "mission": ...}
  shape <jsonl>                       (UI-2 S1, B-1) one feed's shape: {"lines", "kinds", "seq_first", "seq_last", "contiguous",
                                      "stop_seqs", "stop_sessions", "finalized": [[seq, dispatch_id]], "session_starts",
                                      "agent_call_seqs"}
  rule <jsonl>                        (UI-2 S1, A-1/A-2; register row 500) the stop rule over one feed, read here and not by the
                                      service (a member does not judge a cure by the cured code): R1 no session_stop for a
                                      session precedes a later line of that session; R2 no dispatch_finalized precedes its
                                      session's session_stop or a later line of that session, and one follows a session_stop of
                                      its session. A line names the sessions in payload.session_id and payload.parent_session_id;
                                      a dispatch's sessions are those whose lines carry its dispatch_id.
                                      {"verdict": "GREEN"|"RED", "violations": [[rule, seq, later_seq, kind, session], ...]}
  api <dir> --ui-tools <tools-dir>    (UI-2 S2, group B) the service run from <tools-dir> (a scratch copy of tools/, a planted-RED)
  home|api <dir> --feed :nocontract:  (UI-2 S2, B-1) one composed snapshot naming feature F-001 and no assertion
  home|api <dir> --feed :cured-agent: (UI-2 S2, B-12) the cured shape with the subagent's own calls carrying agent_id/agent_type
  home|api <dir> --feed :two-turn:    (UI-2 S2, B-14) one session of two turns, session_stop at SessionEnd only
  home|api <dir> --feed :two-turn-s1: (UI-2 S2, B-14) the same two turns with session_stop at each turn's Stop (UI-2 S1's shape)
  home|api <dir> --feed <jsonl>       (UI-2 S1, A-4) the home made of that ONE feed (checkout "feed") instead of the fixture's
                                      two (--feed :cured: -- the cured hooks' shape for one Agent call, composed here); with --until-seq N the home's copy ends at seq N (the feed as it stood then), and
                                      with --plant-early-stop a session_stop for the session of the feed's last line that
                                      names one is inserted before that line (it and the lines after it moved one seq on)
plants (each into the home's copy only):
  --plant-stop                        a session_stop for the session whose session_start is at seq 38 of the worktree
                                      feed, appended to that feed (seq + 1 of its last line)
  --mission-name NAME                 the latest mission_snapshot of each feed re-issued as schema_version 1.1 carrying
                                      mission_name NAME (appended, seq + 1), as the cured writer writes it
  --registry-name NAME                every registry row carries mission_name: NAME (a field the registry does not define)
  --plant-run MID                     two 1.1 snapshots appended to the worktree feed: current_milestone MID, then the feed's own
                                      (a current_milestone run for MID, e.g. the withdrawn M-46)
  --plant-finalized ID,PARTIAL,STATE  a dispatch_finalized for dispatch ID with partial PARTIAL (true/false) and manifest_state
                                      STATE, appended to the worktree feed (seq + 1); may be given more than once
"""
import json
import os
import shutil
import socket
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
FIX = os.path.join(REPO, "tests", "lam", "fixtures", "real-feed")
FEEDS = [("wt-ui-1", "wt-ui-1.events.jsonl"), ("root", "root.events.jsonl")]
sys.path.insert(0, os.path.join(REPO, "tools"))


def lines_of(path):
    with open(path, "rb") as f:
        return [l for l in f.read().decode("utf-8").split("\n") if l]


def dumps(o):
    return json.dumps(o, ensure_ascii=False, separators=(",", ":"))


def validate(paths):
    from ui.schema import Validator
    v = Validator.from_file(os.path.join(REPO, "docs", "framework", "mission-event.schema.json"))
    out = {}
    for p in paths:
        errs = []
        ls = lines_of(p)
        for n, l in enumerate(ls, 1):
            try:
                o = json.loads(l)
            except ValueError:
                errs.append([n, "not JSON"])
                continue
            e = v.first_error(o)
            if e:
                errs.append([n, e])
        out[os.path.basename(p)] = {"lines": len(ls), "errors": errs}
    return {"files": out}


def shape(path):
    objs = [json.loads(l) for l in lines_of(path)]
    kinds, seqs = {}, [o["seq"] for o in objs]
    for o in objs:
        kinds[o["kind"]] = kinds.get(o["kind"], 0) + 1
    stops = [o for o in objs if o["kind"] == "session_stop"]
    return {"lines": len(objs), "kinds": kinds, "seq_first": seqs[0] if seqs else None, "seq_last": seqs[-1] if seqs else None,
            "contiguous": seqs == list(range(seqs[0], seqs[0] + len(seqs))) if seqs else False,
            "stop_seqs": [o["seq"] for o in stops],
            "stop_sessions": sorted({(o.get("payload") or {}).get("session_id") for o in stops}),
            "finalized": [[o["seq"], (o.get("payload") or {}).get("dispatch_id")] for o in objs if o["kind"] == "dispatch_finalized"],
            "session_starts": kinds.get("session_start", 0),
            "agent_call_seqs": [o["seq"] for o in objs if o["kind"] == "tool_call" and (o.get("payload") or {}).get("tool") == "Agent"]}


def _sessions_of(o):
    p = o.get("payload") or {}
    return {s for s in (p.get("session_id"), p.get("parent_session_id")) if s}


def rule(path):
    objs = sorted([json.loads(l) for l in lines_of(path)], key=lambda o: o["seq"])
    viol = []
    for i, s in enumerate(objs):
        if s["kind"] != "session_stop":
            continue
        sid = (s.get("payload") or {}).get("session_id")
        for later in objs[i + 1:]:
            if sid in _sessions_of(later):
                viol.append(["R1 session_stop before a later line of its session", s["seq"], later["seq"], later["kind"], sid])
    disp_sessions = {}
    for o in objs:
        p = o.get("payload") or {}
        if p.get("dispatch_id") and p.get("session_id"):
            disp_sessions.setdefault(p["dispatch_id"], set()).add(p["session_id"])
    for i, f in enumerate(objs):
        if f["kind"] != "dispatch_finalized":
            continue
        did = (f.get("payload") or {}).get("dispatch_id")
        for sid in sorted(disp_sessions.get(did, ())):
            if not any(o["kind"] == "session_stop" and (o.get("payload") or {}).get("session_id") == sid for o in objs[:i]):
                viol.append(["R2 dispatch_finalized with no session_stop of its session before it", f["seq"], None, None, sid])
            for later in objs[i + 1:]:
                if sid in _sessions_of(later):
                    viol.append(["R2 dispatch_finalized before a later line of its session", f["seq"], later["seq"], later["kind"], sid])
    return {"verdict": "RED" if viol else "GREEN", "violations": viol}


SLICE = "rec-q-1.2.0.events.jsonl"
CURED_SESSION = "00000000-0000-4000-8000-000000000035"


def cured_feed():
    """--feed :cured: (UI-2 S1, A-4): a feed of the shape the cured hooks write for one Agent call, as the live harness
    runs it (A-3): the parent's session_start and Agent call, the subagent's calls stamped with the parent, its
    SubagentHandback, ONE subagent_stop, a parent call, the parent's own session_stop, then dispatch_finalized. Its
    mission, host, commit, source and digest are the 1.2.0 slice's first line's (already neutral)."""
    t = json.loads(lines_of(os.path.join(FIX, SLICE))[0])
    s, d = CURED_SESSION, "session-" + CURED_SESSION
    def line(seq, kind, payload):
        return dumps({"schema_version": "1.2", "mission_id": t["mission_id"], "host_id": t["host_id"], "seq": seq,
                      "ts": "2026-11-08T00:00:%02d.000Z" % seq, "kind": kind, "payload": payload, "source_path": t["source_path"],
                      "sha256": t["sha256"], "commit": t["commit"]})
    tc = lambda tool: {"tool": tool, "exit_code": None, "paths": [], "session_id": s, "dispatch_id": d}
    return [line(1, "session_start", {"session_id": s, "dispatch_id": d}), line(2, "tool_call", tc("Agent")), line(3, "tool_call", tc("Read")),
            line(4, "tool_call", tc("SubagentHandback")),
            line(5, "subagent_stop", {"agent_id": "a0000000000000035", "agent_type": "general-purpose", "parent_session_id": s, "dispatch_id": d}),
            line(6, "tool_call", tc("Read")),
            line(7, "session_stop", {"session_id": s, "dispatch_id": d, "manifest_state": "FINALIZED", "entry_count": 3, "evidence_state": "FINALIZED"}),
            line(8, "dispatch_finalized", {"dispatch_id": d, "manifest_state": "FINALIZED", "partial": False, "capture_gaps_count": 0})]


def nocontract_feed():
    """--feed :nocontract: (UI-2 S2, B-1): one mission_snapshot, as a writer with no contract writes it -- feature F-001,
    no assertion, no assertion_detail. Mission, host, commit, source and digest are the 1.2.0 slice's first line's."""
    t = json.loads(lines_of(os.path.join(FIX, SLICE))[0])
    p = {"state": "Executing", "current_milestone": None, "features": {"F-001": "pending"}, "assertions": {},
         "counts": {"features": 1, "assertions": 0, "open_halts": 0, "open_dispatches": 0}, "snapshot_sha256": "0" * 64}
    return [dumps({"schema_version": "1.2", "mission_id": t["mission_id"], "host_id": t["host_id"], "seq": 1, "ts": "2026-11-08T00:00:01.000Z",
                   "kind": "mission_snapshot", "payload": p, "source_path": t["source_path"], "sha256": t["sha256"], "commit": t["commit"]})]


AGENT_ID, AGENT_TYPE = "a0000000000000b12", "general-purpose"


def cured_agent_feed():
    """--feed :cured-agent: (UI-2 S2, B-12): the cured shape (cured_feed) as the B-12 hook writes it -- the subagent's own
    tool_call lines (the Read at seq 3 and its SubagentHandback at seq 4, as A-3's cured-bg feed recorded them) carry the
    agent_id and agent_type the harness gives PostToolUse; the parent's calls carry neither."""
    out = []
    for l in cured_feed():
        o = json.loads(l)
        if o["kind"] == "tool_call" and o["seq"] in (3, 4):
            o["payload"] = dict(o["payload"], agent_id=AGENT_ID, agent_type=AGENT_TYPE)
        if o["kind"] == "subagent_stop":
            o["payload"] = dict(o["payload"], agent_id=AGENT_ID, agent_type=AGENT_TYPE)
        out.append(dumps(o))
    return out


TWO_TURN_SESSION = "00000000-0000-4000-8000-000000000528"


def _two_turn(stop_on_turn_end):
    t = json.loads(lines_of(os.path.join(FIX, SLICE))[0])
    s, d = TWO_TURN_SESSION, "session-" + TWO_TURN_SESSION
    out, seq = [], [0]
    def line(kind, payload):
        seq[0] += 1
        out.append(dumps({"schema_version": "1.2", "mission_id": t["mission_id"], "host_id": t["host_id"], "seq": seq[0],
                          "ts": "2026-11-08T00:01:%02d.000Z" % seq[0], "kind": kind, "payload": payload, "source_path": t["source_path"],
                          "sha256": t["sha256"], "commit": t["commit"]}))
    tc = {"tool": "Read", "exit_code": None, "paths": [], "session_id": s, "dispatch_id": d}
    stop = {"session_id": s, "dispatch_id": d, "manifest_state": "FINALIZED", "entry_count": 1, "evidence_state": "FINALIZED"}
    fin = {"dispatch_id": d, "manifest_state": "FINALIZED", "partial": False, "capture_gaps_count": 0}
    line("session_start", {"session_id": s, "dispatch_id": d})
    for turn in (1, 2):
        line("tool_call", tc)
        if stop_on_turn_end:
            line("session_stop", dict(stop, entry_count=turn))
        line("dispatch_finalized", fin)
    if not stop_on_turn_end:
        line("session_stop", dict(stop, entry_count=2))
    return out


def two_turn_feed():
    """--feed :two-turn: (UI-2 S2, B-14): one interactive session of two turns as the B-14 hooks write it -- each turn's
    Stop says dispatch_finalized and no session_stop; SessionEnd says the one session_stop at the end."""
    return _two_turn(False)


def two_turn_s1_feed():
    """--feed :two-turn-s1: (UI-2 S2, B-14): the same two turns as 1.3.0's first build (UI-2 S1) wrote them -- each turn's
    Stop said session_stop, then dispatch_finalized; the feed reads the session stopped between its turns."""
    return _two_turn(True)


COMPOSED = {":cured:": cured_feed, ":nocontract:": nocontract_feed, ":cured-agent:": cured_agent_feed,
            ":two-turn:": two_turn_feed, ":two-turn-s1:": two_turn_s1_feed}


def build_home(home, plant_stop=False, mission_name=None, registry_name=None, plant_finalized=(), plant_run=None,
               feed=None, until_seq=None, plant_early_stop=False):
    shutil.rmtree(home, ignore_errors=True)
    os.makedirs(home)
    rows, mission_id, stop_session = [], None, None
    # a relative --feed is the repository's path (the browser specs run from ui\)
    feeds = [("feed", feed if (feed in COMPOSED or os.path.isabs(feed)) else os.path.join(REPO, feed))] if feed else [(ck, os.path.join(FIX, fn)) for ck, fn in FEEDS]
    for ck, fp in feeds:
        src = COMPOSED[fp]() if fp in COMPOSED else lines_of(fp)
        if until_seq is not None:
            src = [l for l in src if json.loads(l)["seq"] <= until_seq]
        if plant_early_stop:
            # A-4's planted-RED: a hand-composed session_stop for the session of the feed's last line that names one, inserted
            # before that line; it and every line after it move one seq on
            objs0 = [json.loads(l) for l in src]
            idx = max(i for i, o in enumerate(objs0) if _sessions_of(o))
            at = objs0[idx]
            sid = sorted(_sessions_of(at))[0] if not (at.get("payload") or {}).get("parent_session_id") else at["payload"]["parent_session_id"]
            stop = {**at, "kind": "session_stop", "payload": {"session_id": sid, "dispatch_id": (at.get("payload") or {}).get("dispatch_id") or ("session-" + str(sid)),
                                                               "manifest_state": "PARTIAL", "entry_count": 0, "evidence_state": "OPEN"}}
            src = src[:idx] + [dumps(stop)] + [dumps({**o, "seq": o["seq"] + 1}) for o in objs0[idx:]]
        objs = [json.loads(l) for l in src]
        mission_id = objs[0]["mission_id"]
        extra = []
        if plant_stop and ck == "wt-ui-1":
            s38 = [o for o in objs if o["seq"] == 38 and o["kind"] == "session_start"][0]
            stop_session = s38["payload"]["session_id"]
            last = objs[-1]
            extra.append({**last, "seq": last["seq"] + 1, "kind": "session_stop", "source_path": s38["source_path"],
                          "payload": {"session_id": stop_session, "dispatch_id": s38["payload"]["dispatch_id"], "manifest_state": "ABSENT",
                                      "entry_count": 0, "evidence_state": "ABSENT"}})
        if ck == "wt-ui-1":
            for spec in plant_finalized:
                did, partial, state = spec.split(",")
                fin = [o for o in objs if o["kind"] == "dispatch_finalized"][0]
                last = (objs + extra)[-1]
                extra.append({**fin, "seq": last["seq"] + 1, "ts": last["ts"],
                              "payload": {"dispatch_id": did, "manifest_state": state, "partial": partial == "true", "capture_gaps_count": 0}})
        if plant_run is not None and ck == "wt-ui-1":
            # two snapshots as the cured writer writes them: current_milestone plant_run, then back to the feed's own
            snap = [o for o in objs if o["kind"] == "mission_snapshot"][-1]
            ms = {k: dict(v, status="passed" if v.get("status") == "done" else v.get("status")) for k, v in snap["payload"]["milestones"].items()}
            for cur in (plant_run, snap["payload"]["current_milestone"]):
                last = (objs + extra)[-1]
                extra.append({**snap, "schema_version": "1.1", "seq": last["seq"] + 1, "ts": last["ts"],
                              "payload": {**snap["payload"], "milestones": ms, "current_milestone": cur}})
        if mission_name is not None:
            snap = [o for o in objs if o["kind"] == "mission_snapshot"][-1]
            last = (objs + extra)[-1]
            # as the cured writer writes it: schema 1.1, each milestone's done read as passed
            ms = {k: dict(v, status="passed" if v.get("status") == "done" else v.get("status")) for k, v in snap["payload"]["milestones"].items()}
            extra.append({**snap, "schema_version": "1.1", "seq": last["seq"] + 1, "ts": last["ts"],
                          "payload": {**snap["payload"], "milestones": ms, "mission_name": mission_name}})
        d = os.path.join(home, ck, ".mission-runtime", "telemetry")
        os.makedirs(d)
        with open(os.path.join(d, "events.jsonl"), "wb") as f:
            f.write(("\n".join(src + [dumps(o) for o in extra]) + "\n").encode("utf-8"))
        rows.append((objs[0]["host_id"], os.path.join(home, ck), objs[0]["mission_id"]))
    text = "# Vanguard host registry -- WP-7's real-feed home (RELEASE-4 S1).\n"
    for host_id, path, mid in rows:
        text += "- host_id: %s\n  checkout_path: '%s'\n  mission_id: '%s'\n  registered_at: '2026-11-04T21:40:00.000Z'\n  framework_version: '1.1.0'\n" % (host_id, path.replace("'", "''"), mid)
        if registry_name is not None:
            text += "  mission_name: '%s'\n" % registry_name.replace("'", "''")
    with open(os.path.join(home, "projects.yaml"), "wb") as f:
        f.write(text.encode("utf-8"))
    copies = [lines_of(os.path.join(home, ck, ".mission-runtime", "telemetry", "events.jsonl")) for ck, _ in feeds]
    total = sum(len(c) for c in copies)
    # what a reader waits for: each copy's last seq (a slice's seq does not start at 1, so its line count is no wait)
    seq_total = sum(json.loads(c[-1])["seq"] for c in copies if c)
    return {"home": home, "mission_id": mission_id, "stop_session": stop_session, "lines": total, "seq_total": seq_total,
            "checkouts": [ck for ck, _ in feeds]}


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def api(home, ui_tools=None, **plants):
    info = build_home(home, **plants)
    port = free_port()
    env = dict(os.environ, PYTHONPATH=ui_tools or os.path.join(REPO, "tools"), PYTHONDONTWRITEBYTECODE="1")
    env.pop("VANGUARD_UI_DIST", None)
    p = subprocess.Popen([sys.executable, "-m", "ui", "ui", "--home", home, "--port", str(port)], env=env,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    base = "http://127.0.0.1:%d" % port
    try:
        for _ in range(300):
            try:
                ms = get(base + "/api/missions")
                break
            except OSError:
                if p.poll() is not None:
                    raise SystemExit("vanguard ui exited %s" % p.returncode)
                time.sleep(0.1)
        # the tailer ingests asynchronously: wait until the mission's line count is the feeds' own
        want = info["seq_total"]
        m = None
        for _ in range(300):
            m = get(base + "/api/missions/" + info["mission_id"])
            got = sum(int(s.get("last_seq") or 0) for s in m.get("streams", []))
            if got >= want:
                break
            time.sleep(0.1)
        info.update({"missions": get(base + "/api/missions"), "mission": m, "stats": get(base + "/api/missions/" + info["mission_id"] + "/stats")})
        return info
    finally:
        p.terminate()
        p.wait(30)


def main(argv):
    cmd = argv[0]
    if cmd == "validate":
        return validate(argv[1:])
    if cmd == "shape":
        return shape(argv[1])
    if cmd == "rule":
        return rule(argv[1])
    plants, rest, i = {}, [], 1
    while i < len(argv):
        a = argv[i]
        if a == "--plant-stop":
            plants["plant_stop"] = True
        elif a == "--mission-name":
            i += 1
            plants["mission_name"] = argv[i]
        elif a == "--registry-name":
            i += 1
            plants["registry_name"] = argv[i]
        elif a == "--plant-run":
            i += 1
            plants["plant_run"] = argv[i]
        elif a == "--feed":
            i += 1
            plants["feed"] = argv[i]
        elif a == "--until-seq":
            i += 1
            plants["until_seq"] = int(argv[i])
        elif a == "--ui-tools":
            i += 1
            plants["ui_tools"] = argv[i]
        elif a == "--plant-early-stop":
            plants["plant_early_stop"] = True
        elif a == "--plant-finalized":
            i += 1
            plants["plant_finalized"] = tuple(plants.get("plant_finalized", ())) + (argv[i],)
        else:
            rest.append(a)
        i += 1
    if cmd == "home":
        plants.pop("ui_tools", None)
        return build_home(rest[0], **plants)
    if cmd == "api":
        return api(rest[0], **plants)
    raise SystemExit("unknown command " + cmd)


if __name__ == "__main__":
    sys.stdout.write(json.dumps(main(sys.argv[1:]), ensure_ascii=False) + "\n")
