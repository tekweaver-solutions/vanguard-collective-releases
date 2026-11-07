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


def build_home(home, plant_stop=False, mission_name=None, registry_name=None, plant_finalized=(), plant_run=None):
    shutil.rmtree(home, ignore_errors=True)
    os.makedirs(home)
    rows, mission_id, stop_session = [], None, None
    for ck, fn in FEEDS:
        src = lines_of(os.path.join(FIX, fn))
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
    total = sum(len(lines_of(os.path.join(home, ck, ".mission-runtime", "telemetry", "events.jsonl"))) for ck, _ in FEEDS)
    return {"home": home, "mission_id": mission_id, "stop_session": stop_session, "lines": total}


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def api(home, **plants):
    info = build_home(home, **plants)
    port = free_port()
    env = dict(os.environ, PYTHONPATH=os.path.join(REPO, "tools"), PYTHONDONTWRITEBYTECODE="1")
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
        want = sum(len(lines_of(os.path.join(home, ck, ".mission-runtime", "telemetry", "events.jsonl"))) for ck, _ in FEEDS)
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
        elif a == "--plant-finalized":
            i += 1
            plants["plant_finalized"] = tuple(plants.get("plant_finalized", ())) + (argv[i],)
        else:
            rest.append(a)
        i += 1
    if cmd == "home":
        return build_home(rest[0], **plants)
    if cmd == "api":
        return api(rest[0], **plants)
    raise SystemExit("unknown command " + cmd)


if __name__ == "__main__":
    sys.stdout.write(json.dumps(main(sys.argv[1:]), ensure_ascii=False) + "\n")
