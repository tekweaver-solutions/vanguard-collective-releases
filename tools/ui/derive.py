"""What the feed says the mission's state is, read from its events at query time (no statistic here:
ui.metrics computes those). An event is a dict {key, path, seq, ts, kind, line}; a mission's events from
all its streams are read in (ts, checkout path, seq) order -- the feed's own clock, never this host's.

A schema-valid line can still carry an id that is not a string (the schema leaves most payload ids untyped)
or a ts that matches the pattern but names no real instant (2026-02-30): ids are read through _id, and a ts
that does not parse gives None, so no line of any one feed can make an answer fail.
"""
import heapq
import json
import os
import re
from datetime import datetime


def parse_ts(ts):
    """The feed's ts as a datetime, or None when it names no real instant."""
    try:
        return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S.%fZ")
    except (TypeError, ValueError):
        return None


def as_int(v):
    """An integer as JSON Schema reads one (3 and 3.0 alike), else None."""
    if isinstance(v, bool):
        return None
    if isinstance(v, int):
        return v
    if isinstance(v, float) and v.is_integer():
        return int(v)
    return None


def _id(v):
    """An id as a string key: itself when it is one, else its canonical JSON."""
    return v if isinstance(v, str) else json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def ordered(events):
    """A mission's events in feed order. Within one stream seq is the order (allocated under the file's lock; a
    host clock that steps back does not reorder it); streams are merged by ts, then checkout path, then seq."""
    streams = {}
    for e in events:
        streams.setdefault(e["key"], []).append(e)
    runs = [sorted(s, key=lambda e: e["seq"]) for _, s in sorted(streams.items())]
    return list(heapq.merge(*runs, key=lambda e: (e["ts"], e["path"], e["seq"])))


def of_kind(events, *kinds):
    return [e for e in events if e["kind"] in kinds]


MILESTONE_STATUSES = ("passed", "active", "pending", "withdrawn")


def milestone_status(word):
    """A snapshot milestone's status in the closed set of expanded-schemas SS14 (schema 1.1): a 1.0 writer passed the spec's
    words through, so its done is read as passed; any other word is returned as it stands (a 1.1 line carries none)."""
    return "passed" if word == "done" else word


def mission_name(events):
    """The mission's name (RELEASE-4 S1, F-P5a): the latest mission_snapshot's mission_name, in feed order, when it is a
    non-empty string; None otherwise (no snapshot yet, a snapshot from before the field, or a record with no name). Never
    the host registry's row: a row is stale by design after a prune."""
    snaps = of_kind(events, "mission_snapshot")
    n = snaps[-1]["line"]["payload"].get("mission_name") if snaps else None
    return n if isinstance(n, str) and n else None


def latest_snapshot(events):
    snaps = of_kind(events, "mission_snapshot")
    return snaps[-1] if snaps else None


# RELEASE-5 group B, FRESHNESS (RB-15, RB-16): THE ONE DOCUMENTED COMMAND THAT WRITES A FRESH SNAPSHOT, and how a reading the
# newest snapshot does not carry is said. Every writer of a mission_snapshot line goes through
# tools/lam/mission-telemetry.ps1's Write-MissionSnapshot, which appends only when the derived state moved: mission.ps1 init
# and register; every stage verb that commits through mission-lib's Invoke-AtomicCommit (close-milestone, green-gate-seed,
# reopen, reclose, reclaim, prune-objects, promote-contract, ledger-append, spec-bump, spec-accept); spec-accept's own
# commit; design-start; the dispatch entry and the LAM runner's open, close and rejection close; mission-gate revoke,
# settle and approve / reapprove; transcribe-validator-results -Write. mission verify and the hooks write none. The command
# an operator runs to write one now is mission.ps1 register (INSTALL.md section 7, the user guide section 12).
# RELEASE-5 group B, amendment 3 (RB-28, ruling (bj)): THE COMMAND NAMES THE PROJECT. Where the dashboard knows the folder the
# reading comes from -- the registry row's checkout_path of the stream that wrote the snapshot read (every event carries its
# row's folder as "root"), or the mission's one checkout where no snapshot is read -- the command carries that folder in the
# placeholder's place, quoted as PowerShell reads a literal (single quotes, a quote inside doubled), so a folder holding a
# space pastes as printed. Where it does not know the folder, it says so in words; no angle-bracket placeholder is printed.
# Validator round 1: every character PowerShell reads as a single quote -- the ASCII one and U+2018, U+2019, U+201A, U+201B --
# is doubled; and the head is .\mission.ps1, as PowerShell runs a script from the release folder (the user guide writes it so).
# UI-3 (1.3.3) UC-19, register row 579: THE COMMAND RUNS AS PASTED where the execution policy refuses a bare script (Restricted,
# or a tree carrying the mark of the web): it carries the bypass in the form every command of INSTALL.md uses -- powershell
# -NoProfile -ExecutionPolicy Bypass -File <script> <arguments> -- run from the release folder. -File hands the folder to
# mission.ps1 as one literal argument, so RB-28's quoting is kept unchanged.
COMMAND_HEAD = "powershell -NoProfile -ExecutionPolicy Bypass -File .\\mission.ps1 register -Target"
PS_SINGLE_QUOTES = "'\u2018\u2019\u201a\u201b"
FRESH_SNAPSHOT_COMMAND = (COMMAND_HEAD + " followed by the project folder in single quotes -- the dashboard does not know which "
                          "folder this reading comes from")
# the payload keys the group B contract adds (each 1.3.1 snapshot carries them, null or empty where nothing is read)
ADDED_SNAPSHOT_KEYS = ("assertion_reading", "goal_verdicts", "halt_reading", "milestone_tally", "spec_version")
# amendment 3 (RB-26): the readings it adds inside a snapshot's entries -- each assertion's evidence, each milestone's count of
# assertions held on the record alone; a snapshot an earlier writer wrote (1.3.1 or 1.3.0) carries neither
ADDED_ENTRY_READINGS = ("assertion_detail.evidence", "milestone_tally.assertions_record_alone")
EVIDENCE_SINCE = "1.3.2"


def quote_ps(path):
    """A folder as PowerShell reads a literal argument: in single quotes, each character PowerShell reads as a single quote
    doubled."""
    return "'" + "".join(c + c if c in PS_SINGLE_QUOTES else c for c in str(path)) + "'"


def reading_root(events, roots=None):
    """RB-28: the folder of the checkout the reading comes from -- the latest snapshot's stream's checkout_path; with no
    snapshot, the mission's one checkout (roots: the checkout paths of the mission's streams, else those its events carry);
    None where it is not known (no snapshot and several checkouts, or none)."""
    snap = latest_snapshot(events)
    if snap is not None:
        r = snap.get("root")
        return r if isinstance(r, str) and r else None
    rs = sorted({r for r in (roots if roots is not None else [e.get("root") for e in events]) if isinstance(r, str) and r})
    return rs[0] if len(rs) == 1 else None


def fresh_command(root):
    """RB-28: the documented command that writes a fresh snapshot, naming the checkout's folder where it is known."""
    return COMMAND_HEAD + " " + quote_ps(root) if root else FRESH_SNAPSHOT_COMMAND


def not_in_snapshot(events, since="1.3.1", root=None):
    """RB-16, RB-26: how a reading the newest snapshot does not carry is said -- with the command that writes a fresh one, for
    the checkout the reading comes from (root, else the reading's own)."""
    cmd = fresh_command(root if root else reading_root(events))
    return "not in this snapshot: its writer predates %s -- write a fresh one with %s" % (since, cmd)


def snapshot_lacks(events, key):
    """True when there IS a latest snapshot and it does not carry the 1.3.1 key (a snapshot an earlier writer wrote)."""
    snap = latest_snapshot(events)
    return snap is not None and key not in (snap["line"].get("payload") or {})


def snapshot_lacks_entry(events, reading):
    """amendment 3 (RB-26): True when there IS a latest snapshot and it does not carry the reading "<map>.<key>" -- the map
    absent, or any of its entries without the key (a snapshot the 1.3.1 or the 1.3.0 writer wrote). A map with no entries
    lacks nothing."""
    snap = latest_snapshot(events)
    if snap is None:
        return False
    m, k = reading.split(".", 1)
    v = (snap["line"].get("payload") or {}).get(m)
    if not isinstance(v, dict):
        return True
    return any(not (isinstance(e, dict) and k in e) for e in v.values())


def snapshot_reading(events, roots=None):
    """RB-15: the snapshot the readings come from -- its stream, seq and ts -- the number of the mission's feed lines after it
    in feed order, the command that writes a fresh one (RB-28: naming the checkout's folder where it is known), and the 1.3.1
    keys it does not carry (RB-16) and the readings of amendment 3 it does not carry (RB-26)."""
    snap = latest_snapshot(events)
    f = ("the mission's latest mission_snapshot in feed order (derive.ordered); lines_after = the mission's lines after it in that "
         "order; missing = the keys the 1.3.1 writer adds that it does not carry; missing_since_132 = the readings the 1.3.2 writer "
         "adds that it does not carry; command = the one documented command that writes a fresh one (it appends only when the "
         "derived state moved), naming the folder of the checkout the snapshot came from")
    root = reading_root(events, roots)
    cmd = fresh_command(root)
    if snap is None:
        return {"stream_key": None, "seq": None, "ts": None, "lines_after": len(events), "command": cmd, "root": root, "missing": None,
                "missing_since_132": None, "not_in_snapshot": not_in_snapshot(events, root=root), "formula": f}
    at = next(i for i, e in enumerate(events) if e is snap)
    p = snap["line"].get("payload") or {}
    return {"stream_key": snap["key"], "seq": snap["seq"], "ts": snap["ts"], "lines_after": len(events) - at - 1, "command": cmd, "root": root,
            "missing": sorted(k for k in ADDED_SNAPSHOT_KEYS if k not in p),
            "missing_since_132": [r for r in ADDED_ENTRY_READINGS if snapshot_lacks_entry(events, r)],
            "not_in_snapshot": not_in_snapshot(events, root=root), "formula": f}


def assertions(events):
    """assertion id -> {status, feature, event}: the latest of the snapshots' assertion maps and the
    assertion_result lines, in feed order. feature comes from assertion_result, else from a dispatch_opened
    that targeted the assertion."""
    out, target_feature = {}, {}
    for e in events:
        p = e["line"]["payload"]
        feature = None if p.get("feature") is None else _id(p.get("feature"))
        if e["kind"] == "dispatch_opened":
            for aid in p.get("assertion_targets") or []:
                target_feature[_id(aid)] = feature
        elif e["kind"] == "mission_snapshot":
            amap = p.get("assertions") if isinstance(p.get("assertions"), dict) else {}
            for aid, st in sorted(amap.items()):
                prev = out.get(aid, {})
                out[aid] = {"status": st, "feature": prev.get("feature"), "event": e}
        elif e["kind"] == "assertion_result":
            out[_id(p["assertion_id"])] = {"status": p["result"], "feature": feature, "event": e}
    for aid, a in out.items():
        if a["feature"] is None:
            a["feature"] = target_feature.get(aid)
    return out


def halts(events):
    """halt id -> {raised, resolved}: a halt_resolved after its halt_raised closes it."""
    out = {}
    for e in of_kind(events, "halt_raised", "halt_resolved"):
        hid = _id(e["line"]["payload"]["halt_id"])
        h = out.setdefault(hid, {"raised": None, "resolved": None})
        if e["kind"] == "halt_raised":
            h["raised"], h["resolved"] = e, None
        else:
            h["resolved"] = e
    return out


def open_sessions(events):
    started, stopped = {}, set()
    for e in of_kind(events, "session_start", "session_stop"):
        sid = _id(e["line"]["payload"]["session_id"])
        if e["kind"] == "session_start":
            started[sid] = e
            stopped.discard(sid)
        else:
            stopped.add(sid)
    return sorted(s for s in started if s not in stopped)


def _sessions_named(e):
    """The session ids a line names: payload session_id, and parent_session_id (a subagent_stop's parent)."""
    p = e["line"].get("payload") or {}
    return {_id(v) for v in (p.get("session_id"), p.get("parent_session_id")) if v is not None}


def subagents_finished(events):
    """UI-2 S1 (A-4, register row 500): parent session id -> the subagent_stop lines naming it, in feed order. A
    subagent's end is read as "subagent finished" -- never as its parent's stop (schema 1.2)."""
    out = {}
    for e in of_kind(events, "subagent_stop"):
        p = e["line"].get("payload") or {}
        if p.get("parent_session_id") is not None:
            out.setdefault(_id(p["parent_session_id"]), []).append(e)
    return out


def subagent_calls(events):
    """UI-2 S2 (B-12, decision 11): parent session id -> the subagents whose own tool_call lines name it, in order of
    their first call: [{agent_id, agent_type, calls, tools {tool: count}, first_seq, last_seq}]. A subagent's call is
    stamped with its PARENT's session_id and carries agent_id (and agent_type) where the hook was given them (schema 1.2,
    optional payload fields); a line without agent_id is the parent's own call and is not counted here. Lines of streams
    are kept apart by the session id they name, as open_sessions keeps them."""
    out = {}
    for e in of_kind(events, "tool_call"):
        p = e["line"].get("payload") or {}
        aid, sid = p.get("agent_id"), p.get("session_id")
        if not isinstance(aid, str) or not aid or sid is None:
            continue
        rows = out.setdefault(_id(sid), {})
        r = rows.get(aid)
        if r is None:
            r = rows[aid] = {"agent_id": aid, "agent_type": None, "calls": 0, "tools": {}, "first_seq": e["seq"], "last_seq": e["seq"]}
        if isinstance(p.get("agent_type"), str) and p["agent_type"]:
            r["agent_type"] = p["agent_type"]
        r["calls"] += 1
        t = str(p.get("tool"))
        r["tools"][t] = r["tools"].get(t, 0) + 1
        r["last_seq"] = e["seq"]
    return {sid: sorted(rows.values(), key=lambda r: r["first_seq"]) for sid, rows in out.items()}


def stopped_early(events):
    """UI-2 S1 (A-4, register row 500): the sessions a session_stop says stopped while the same stream goes on naming them
    -- a later line of that session after its session_stop (a later session_start reopens it, and is not such a line).
    RELEASE-4's SubagentStop hook wrote a subagent's stop as its parent's session_stop, so a 1.0/1.1 feed shows the
    orchestrator stopped while it works; this is that shape, said, never shown as "stopped". One entry per session: its
    first such stop and the first later line, {session_id, stop_seq, stop_ts, later_seq, later_kind, stream_key}."""
    out = {}
    by_stream = {}
    for e in events:
        by_stream.setdefault(e["key"], []).append(e)
    for key, evs in by_stream.items():
        stops = {}
        for e in sorted(evs, key=lambda x: x["seq"]):
            p = e["line"].get("payload") or {}
            if e["kind"] == "session_start":
                if p.get("session_id") is not None:
                    stops.pop(_id(p["session_id"]), None)
                continue
            for sid in _sessions_named(e):
                if sid in stops and sid not in out:
                    s = stops[sid]
                    out[sid] = {"session_id": sid, "stop_seq": s["seq"], "stop_ts": s["ts"], "later_seq": e["seq"],
                                "later_kind": e["kind"], "stream_key": key}
            if e["kind"] == "session_stop" and p.get("session_id") is not None:
                stops.setdefault(_id(p["session_id"]), e)
    return [out[k] for k in sorted(out)]


def _session_join(events):
    """RELEASE-5 group B (RB-12): session id -> dispatch id, from the dispatch_opened lines that carry a session_id. The LAM
    runner's opened line names the dispatch (D-x) and its session (session-D-x); its finalized line, written by the hooks,
    names the session as its dispatch_id. A dispatch_id that is itself an opened line's dispatch_id is never re-read."""
    opened, join = set(), {}
    for e in of_kind(events, "dispatch_opened"):
        p = e["line"]["payload"]
        opened.add(_id(p["dispatch_id"]))
        if p.get("session_id") is not None:
            join[_id(p["session_id"])] = _id(p["dispatch_id"])
    return {s: d for s, d in join.items() if s not in opened}


def dispatches(events):
    """dispatch id -> {opened, finalized (the latest)}. RELEASE-5 group B (RB-12): a dispatch_finalized whose dispatch_id is
    an opened line's session_id belongs to that opened line's dispatch; a finalized line no opened line names stays its
    own entry, with no opened line -- never an open dispatch."""
    out, join = {}, _session_join(events)
    for e in of_kind(events, "dispatch_opened", "dispatch_finalized"):
        did = _id(e["line"]["payload"]["dispatch_id"])
        if e["kind"] == "dispatch_finalized":
            did = join.get(did, did)
        d = out.setdefault(did, {"opened": None, "finalized": None})
        d["opened" if e["kind"] == "dispatch_opened" else "finalized"] = e
    return out


def manifests(events):
    """RELEASE-5 group B (RB-13): the sealed manifests, in their own terms, on the session they belong to -- the latest
    dispatch_finalized line of each session (its payload's dispatch_id is the session the hooks finalized):
    [{session, dispatch_id (the joined opened line's, else None), manifest_state, partial, capture_gaps_count, seq, ts}], by
    session. capture_gaps_count is the number of gap RECORDS the hooks' Get-EvidenceCaptureGaps wrote for the session's
    manifest (its capture-gaps.yaml sidecar), each a place where the evidence store and the session's own record of its calls
    disagree: a call slot allocated with no log entry, the session's failed tool calls (the post-tool hook is not called for a
    failed call; one record covers them all), a count surplus or a denial mismatch, or a transcript that could not be compared
    at all (validator round 1). partial is true when the manifest is not FINALIZED or has a capture gap."""
    join, latest = _session_join(events), {}
    opened = {_id(e["line"]["payload"]["dispatch_id"]) for e in of_kind(events, "dispatch_opened")}
    for e in of_kind(events, "dispatch_finalized"):
        latest[_id(e["line"]["payload"]["dispatch_id"])] = e
    out = []
    for sid, e in sorted(latest.items()):
        p = e["line"]["payload"]
        gaps = as_int(p.get("capture_gaps_count"))
        out.append({"session": sid, "dispatch_id": join.get(sid, sid if sid in opened else None), "manifest_state": p.get("manifest_state"),
                    "partial": p.get("partial") is True, "capture_gaps_count": gaps, "seq": e["seq"], "ts": e["ts"]})
    return out


def is_partial(e):
    p = e["line"]["payload"]
    return p.get("partial") is True or p.get("manifest_state") == "PARTIAL"


def partial_fields(e):
    """What a PARTIAL dispatch_finalized says, in caption order (RELEASE-4 S1, F-P4): the field that fired first --
    partial: true -- then the manifest_state the line carries (which fired too when it is PARTIAL). Empty when neither fired."""
    if not is_partial(e):
        return []
    p = e["line"]["payload"]
    out = ["partial: true"] if p.get("partial") is True else []
    if "manifest_state" in p:
        out.append("manifest_state %s" % p.get("manifest_state"))
    return out


def gates(events):
    """gate id -> its latest gate event (gate_minted / gate_consumed / gate_expired)."""
    out = {}
    for e in of_kind(events, "gate_minted", "gate_consumed", "gate_expired"):
        out[_id(e["line"]["payload"]["gate_id"])] = e
    return out


def latest_verify(events):
    v = of_kind(events, "verify_result")
    return v[-1] if v else None


def is_installer_check(e):
    """UI-3 (UC-9): a verify_result whose arms_run is solely install-verify -- the installer's check of the framework files
    against framework.lock (install.ps1 -Verify), never a mission verify."""
    arms = (e["line"].get("payload") or {}).get("arms_run") if e else None
    return isinstance(arms, list) and len(arms) > 0 and all(a == "install-verify" for a in arms)


def latest_mission_verify(events):
    """UI-3 (UC-9): the newest verify_result whose arms_run is not solely install-verify -- the run "Last verify" and
    "Verify detail" show; an installer check newer than it never takes them."""
    v = [e for e in of_kind(events, "verify_result") if not is_installer_check(e)]
    return v[-1] if v else None


def latest_installer_check(events):
    """UI-3 (UC-9): the installer's newest check (is_installer_check), shown as its own line on the framework version card."""
    v = [e for e in of_kind(events, "verify_result") if is_installer_check(e)]
    return v[-1] if v else None


# RELEASE-5 group B (RB-7): THE STOP EVALUATOR'S READING OF A VERIFY RUN. Its verify_pass_or_dib detector runs mission verify
# and writes "mission verify exited <n> -> <PASS | PASS-DIB | REFUSE>. admitted: <subject>, ... <the boundary it disclosed>"
# into the goal verdict on disk, which the 1.3.1 snapshot carries (goal_verdicts). The verdict file names no verify run id,
# so a reading is joined to a verify_result by what both state.
VERIFY_READING_RULE = (
    "a goal verdict's verify_pass_or_dib reading read the newest verify_result V when: its evaluated_at is at or after V's ts "
    "and no other verify_result falls between them; it names verify's exit for V's verdict (0 for PASS, 1 for REFUSE); and, "
    "where it admitted V as PASS-DIB, the subjects it admitted are exactly V's refused_by; and, where the goal file's "
    "verify_pass_or_dib detector declares the artifact it runs verify against, V's against is that artifact (validator round 1: "
    "a newer run against another artifact is not the run the evaluator read). A reading admits the run when its "
    "detector passed with PASS or PASS-DIB; an admitted refusal is shown beside the evaluator's word and boundary, not as "
    "blocking. Of several such readings the latest evaluated_at is shown. Validator round 2: the goal verdicts read are those "
    "of the newest snapshot of V's OWN stream -- a checkout's evaluator runs verify in that checkout, so a run made in another "
    "of the mission's checkouts is never joined to it -- and the other runs that may not fall between are that stream's; of a "
    "goal's several verify_pass_or_dib detectors (in the order the goal declares them, one verdict entry each) the one read is "
    "the one whose declared artifact is V's. THE LIMITS the record leaves (the verdict names no run): a run of the same "
    "checkout against the same artifact falling between the run the evaluator read and its evaluated_at is joined -- for "
    "PASS-DIB only where its refused subjects equal the ones admitted; for PASS or REFUSE on the verdict word alone, so a "
    "REFUSE reading may be shown beside another refused run, which it never admits; where the evaluator's own verify run "
    "wrote no verify_result line, its reading is joined to the run before it on the same terms; and the detectors are "
    "paired with the goal file as it stands when the snapshot is written, so a goal file edited after the evaluation shifts "
    "the pairing. An admitting reading of a run outside these is never joined (validator round 3). UI-3 (UC-9): the runs "
    "are the mission verifies -- a verify_result whose arms_run is solely install-verify (the installer's check against "
    "framework.lock) is never V, never falls between, and is read by no evaluator. UI-3 amendment 3 (UC-36): A SECOND SOURCE, "
    "the goal_verdict line the evaluator appends after each evaluation (framework 1.3.3), read from V's own stream, of each goal "
    "its newest line alone (as a snapshot holds each goal's newest verdict alone): where its "
    "reading names the report the verify run wrote (report_path and report_sha256), it read V exactly when those are V's "
    "source_path and sha256 -- a line naming another run's report never reads V; where it names none, it is joined on the terms "
    "above, its evaluated_at, exit, word, admitted subjects and against standing for the snapshot's. Of every reading of V, the "
    "snapshot's and the lines', the newest evaluated_at is shown (on a tie, the later in feed order); source says which. An "
    "evaluation a line covers (the same goal and evaluated_at) is read from the line alone: the snapshot's copy of that verdict "
    "never overrides what the line says of the run it read. Where the two differ for one verdict: the line writes a declared "
    "against that lies under the mission root relative (as verify_result does), and a boundary naming a host path with that "
    "path replaced, where the snapshot keeps the goal file's and the verdict's own text.")
def _norm_rel(p):
    """A relative path as both writers spell it, for comparison: forward slashes, no leading ./, case folded."""
    s = str(p or "").strip().replace("\\", "/")
    while s.startswith("./"):
        s = s[2:]
    return s.lower()


_VERIFY_DETAIL = re.compile(r"^mission verify exited (-?\d+) -> (PASS-DIB|PASS|REFUSE)\.(?: admitted: ((?:\S+, )*\S+))?\s*(.*)$", re.S)


def verify_reading(events, v=None):
    """The evaluator's reading of a verify run (VERIFY_READING_RULE) -- v, else the newest mission verify
    (latest_mission_verify): {goal, word, ok, admits, admitted, boundary, evaluated_at, goal_verdict, file, against,
    against_checked, source ("mission_snapshot" | "goal_verdict", UI-3 amendment 3), source_seq (that line's seq),
    verify_identified (the line named the run's report and sha256)}, or None when no
    goal verdict the latest snapshot carries read that run, or v is the installer's check (UI-3, UC-9)."""
    v = latest_mission_verify(events) if v is None else v
    if v is None or is_installer_check(v):
        return None
    p, vt = v["line"].get("payload") or {}, parse_ts(v["ts"])
    if vt is None:
        return None
    # validator round 2: the run's own stream -- its newest snapshot's goal verdicts, its other runs (UI-3: its other mission
    # verifies; an installer check is no run the evaluator reads)
    own = [e for e in events if e["key"] == v["key"]]
    others = [parse_ts(e["ts"]) for e in of_kind(own, "verify_result") if e is not v and not is_installer_check(e)]

    def in_window(at):
        return at is not None and at >= vt and not any(t is not None and vt < t <= at for t in others)

    cands = []  # (evaluated_at, feed position, reading)
    # builder review: an evaluation the evaluator's own line covers (same goal, same evaluated_at) is read from that line alone --
    # a snapshot copying the same verdict file never overrides what the line says of the run it read
    covered = {}
    for e in own:
        if e["kind"] == "goal_verdict":
            gp = e["line"].get("payload") or {}
            if isinstance(gp.get("goal"), str) and isinstance(gp.get("evaluated_at"), str):
                covered.setdefault(gp["goal"], set()).add(gp["evaluated_at"])
    snap = latest_snapshot(own)
    for goal, g in sorted(snapshot_map(snap, "goal_verdicts").items()):
        if not isinstance(g, dict):
            continue
        if isinstance(g.get("evaluated_at"), str) and g.get("evaluated_at") in covered.get(goal, ()):
            continue
        at = parse_ts(g.get("evaluated_at")) if isinstance(g.get("evaluated_at"), str) else None
        if not in_window(at):
            continue
        dets = g.get("verify_detectors") if isinstance(g.get("verify_detectors"), list) and g.get("verify_detectors") else [g.get("verify")]
        for r in dets:
            x = _detector_reading(goal, g, r, p)
            if x is not None:
                x.update(source="mission_snapshot", source_seq=snap["seq"], verify_identified=False)
                cands.append((at, own.index(snap), x))
                break
    # UI-3 amendment 3 (UC-36): the goal_verdict lines of V's own stream -- of each goal, its newest line alone, as a snapshot
    # holds each goal's newest verdict alone (a trap's rewrite of a verdict supersedes the line written before it)
    newest = {}
    for i, e in enumerate(own):
        if e["kind"] == "goal_verdict":
            gk = (e["line"].get("payload") or {}).get("goal")
            newest[gk if isinstance(gk, str) else ("#", i)] = i
    keep = set(newest.values())
    for i, e in enumerate(own):
        if e["kind"] != "goal_verdict" or i not in keep:
            continue
        gp = e["line"].get("payload") or {}
        at = parse_ts(gp.get("evaluated_at")) if isinstance(gp.get("evaluated_at"), str) else None
        g = {"verdict": gp.get("verdict"), "evaluated_at": gp.get("evaluated_at"), "file": e["line"].get("source_path")}
        for r in gp.get("verify_readings") if isinstance(gp.get("verify_readings"), list) else []:
            if not isinstance(r, dict):
                continue
            named = isinstance(r.get("report_path"), str) and isinstance(r.get("report_sha256"), str)
            if named:
                if _norm_rel(r["report_path"]) != _norm_rel(v["line"].get("source_path")) or r["report_sha256"] != v["line"].get("sha256"):
                    continue
            elif not in_window(at):
                continue
            x = _line_reading(gp.get("goal"), g, r, p)
            if x is not None:
                x.update(source="goal_verdict", source_seq=e["seq"], verify_identified=named)
                cands.append((at or vt, i, x))
                break
    if not cands:
        return None
    return max(cands, key=lambda c: (c[0], c[1]))[2]


def _detector_reading(goal, g, r, p):
    """One verify_pass_or_dib detector's reading of the run p, or None when it did not read that run (VERIFY_READING_RULE)."""
    det = r.get("detail") if isinstance(r, dict) else None
    m = _VERIFY_DETAIL.match(det) if isinstance(det, str) else None
    if m is None:
        return None
    # validator round 1: and the artifact -- the goal file's verify_pass_or_dib detector declares the `against` it runs
    # verify with; a run against another artifact is not the run that detector read
    decl = r.get("against") if isinstance(r.get("against"), str) and r.get("against").strip() else None
    admitted = [x.strip() for x in m.group(3).split(",")] if m.group(3) else []
    return _reading(goal, g, p, int(m.group(1)), m.group(2), admitted, m.group(4).strip() or None, r.get("ok") is True, decl)


def _line_reading(goal, g, r, p):
    """UI-3 amendment 3 (UC-36): one reading of a goal_verdict line (its verify_readings entry r) of the run p, or None -- the
    same reading _detector_reading gives for the verdict detail the entry was taken from."""
    code, word = as_int(r.get("exit_code")), r.get("word")
    if code is None or word not in ("PASS", "PASS-DIB", "REFUSE") or not isinstance(goal, str):
        return None
    admitted = [str(x) for x in r.get("admitted")] if isinstance(r.get("admitted"), list) else []
    decl = r.get("against") if isinstance(r.get("against"), str) and r.get("against").strip() else None
    boundary = r.get("boundary").strip() or None if isinstance(r.get("boundary"), str) else None
    return _reading(goal, g, p, code, word, admitted, boundary, r.get("ok") is True, decl)


def _reading(goal, g, p, code, word, admitted, boundary, ok, decl):
    """The reading of the run p by a detector that said (code, word, admitted, boundary, ok, decl), or None when what it said is
    not of p (VERIFY_READING_RULE): another artifact, another exit, other subjects."""
    if decl is not None and _norm_rel(decl) != _norm_rel(p.get("against")):
        return None
    rb = p.get("refused_by") if isinstance(p.get("refused_by"), list) else None
    if p.get("verdict") == "PASS":
        same = code == 0 and word == "PASS"
    elif p.get("verdict") == "REFUSE":
        same = code == 1 and (word == "REFUSE" or (word == "PASS-DIB" and rb is not None and sorted(str(x) for x in rb) == sorted(admitted)))
    else:
        same = False
    if not same:
        return None
    return {"goal": goal, "word": word, "ok": ok, "admits": ok and word in ("PASS", "PASS-DIB"), "admitted": admitted,
            "boundary": boundary, "evaluated_at": g.get("evaluated_at"), "goal_verdict": g.get("verdict"), "file": g.get("file"),
            "against": decl, "against_checked": decl is not None}


def main_tip_run(stream_events):
    """For one stream: (latest tip_observed of main, first tip_observed of the unbroken run of ahead > 0 that
    ends there) or (latest, None) when main is not ahead. The branch is the line's ref (the push hook's) or
    its upstream (mission verify's, e.g. origin/main); a line naming another branch is not about main, and a
    line naming neither is taken as main. A line with ahead unknown (null) neither starts nor breaks a run."""
    def branch(p):
        b = p.get("ref") or p.get("upstream") or "main"
        return str(b).rsplit("/", 1)[-1]
    tips = [e for e in of_kind(stream_events, "tip_observed") if branch(e["line"]["payload"]) == "main"]
    known = [e for e in tips if as_int(e["line"]["payload"].get("ahead")) is not None]
    if not known:
        return None, None
    latest = known[-1]
    if as_int(latest["line"]["payload"]["ahead"]) <= 0:
        return latest, None
    start = latest
    for e in reversed(known[:-1]):
        if as_int(e["line"]["payload"]["ahead"]) <= 0:
            break
        start = e
    return latest, start



# =================================================================================================
# UI-2 S2, GROUP B (register rows 501, 498; the S2 contract B-1..B-11): what the snapshot writer reads from the mission's
# artifacts -- the mission_snapshot's additive assertion_detail, dispatch_detail, halts and framework_lock_version -- read
# beside the feed's own lines. Each reader is tolerant of a snapshot without the field (a 1.2.0 writer's): it reads none.
# =================================================================================================
ROUND_RULE = ("round r = a validator result's attempt_number (assertion_result.round on the feed; the snapshot's "
              "assertion_detail rounds, read from .mission/validator-results). A result's verdict reaches every assertion it lists; "
              "a failing result naming ONE assertion refutes that one and confirms the others it lists. On the same assertion and "
              "round, the later line in feed order wins. green = confirmed, red = refuted; skipped is neither.")


def snapshot_map(snap, key):
    """A map field of one mission_snapshot event (or {} when absent, or not a map)."""
    m = (snap["line"].get("payload") or {}).get(key) if snap else None
    return m if isinstance(m, dict) else {}


def judged(result):
    """A result word as a verdict: green -> confirmed, red -> refuted, anything else -> None (not judged)."""
    return "confirmed" if result == "green" else "refuted" if result == "red" else None


def assertion_rounds(events):
    """assertion id -> {round: result}: the assertion_result lines (round, result) and the latest snapshot's
    assertion_detail rounds, read at the snapshot's place in feed order; on the same assertion and round the later wins."""
    out, snap = {}, latest_snapshot(events)
    for e in events:
        if e["kind"] == "assertion_result":
            p = e["line"]["payload"]
            r = as_int(p.get("round"))
            if r is not None and r >= 1:
                out.setdefault(_id(p.get("assertion_id")), {})[r] = p.get("result")
        elif snap is not None and e is snap:
            for aid, d in sorted(snapshot_map(snap, "assertion_detail").items()):
                for x in (d.get("rounds") if isinstance(d, dict) and isinstance(d.get("rounds"), list) else []):
                    r = as_int(x.get("round")) if isinstance(x, dict) else None
                    if r is not None and r >= 1:
                        out.setdefault(aid, {})[r] = x.get("verdict")
    return out


def assertion_record(events):
    """RELEASE-5 group B (RB-1..RB-5): assertion id -> {rounds, reason, source} for the Project page and the API.
    rounds = [{round, verdict}] in round order, verdict confirmed / refuted (None for a word that is neither), from
    assertion_rounds (the assertion_result lines and the latest snapshot's assertion_detail, which the 1.3.1 writer reads
    from the spawn ledger's bound results by the close tool's own reader); reason and source = the latest snapshot's
    assertion_detail entry's, None where it carries none."""
    det = snapshot_map(latest_snapshot(events), "assertion_detail")
    out = {}
    for aid, rs in assertion_rounds(events).items():
        out.setdefault(aid, {})["rounds"] = [{"round": r, "verdict": judged(rs[r])} for r in sorted(rs)]
    for aid, d in det.items():
        x = out.setdefault(aid, {})
        x.setdefault("rounds", [])
        if isinstance(d, dict):
            x["reason"] = d.get("reason") if isinstance(d.get("reason"), str) else None
            x["source"] = d.get("source") if isinstance(d.get("source"), str) else None
            # amendment 3 (RB-25, RB-26): the evidence the assertion stands on, in the snapshot's own word, and the path read
            # for it -- and whether the snapshot carries the reading at all (a 1.3.1 or 1.3.0 writer's does not)
            # (validator round 2: a value that is not a string -- a malformed snapshot -- reads as no word, never a fault)
            x["evidence"] = d.get("evidence") if isinstance(d.get("evidence"), str) and d.get("evidence") in EVIDENCE_WORDS else None
            x["evidence_path"] = d.get("evidence_path") if isinstance(d.get("evidence_path"), str) else None
            x["evidence_read"] = "evidence" in d
    return out


# amendment 3 (RB-24): the four words an assertion's evidence is said in, each with what it proves
EVIDENCE_WORDS = {
    "working copy": "the result file the complete line binds, where it binds it, re-hashed equal to the bound sha256",
    "archive copy": "a file of the result's own name under the validators archive (.mission-runtime/lam/validators), re-hashed "
                    "equal to the bound sha256 -- the working copy is gone and the milestone is closed",
    "record alone": "the spawn ledger's complete line and the verdict it states, with no copy of the bound bytes found where they "
                    "were read -- the working copy is gone and the milestone is closed; the bytes are not verified",
    "old results folder": "a result in .mission/validator-results, for an assertion the spawn ledger does not bind",
}


def assertion_features(events):
    """assertion id -> feature id: the contract's own feature_id (the latest snapshot's assertion_detail) where it names one,
    else derive.assertions' binding (assertion_result.feature, else a dispatch_opened that targeted it)."""
    out = {aid: a["feature"] for aid, a in assertions(events).items()}
    for aid, d in snapshot_map(latest_snapshot(events), "assertion_detail").items():
        if isinstance(d, dict) and d.get("feature_id") is not None:
            out[aid] = _id(d["feature_id"])
    return out


def feature_members(events):
    """feature id (None for unbound) -> [{assertion_id, verdict, round}]: each assertion's latest verdict -- its latest
    round's, else its latest status (the snapshot's or an assertion_result's) -- in assertion id order."""
    st, rounds, feat = assertions(events), assertion_rounds(events), assertion_features(events)
    # RELEASE-5 group B (validator round 1): over a 1.3.1 snapshot -- which reads each status by the close tool's own rule --
    # an assertion's verdict IS its status (green confirmed, red refuted, anything else not judged); its rounds are its
    # history, never its verdict. An assertion held not judged is never served "confirmed" from an earlier round.
    # Validator round 3: over ANY snapshot -- one page's figures (the feature roll-up, the Assertions tile, the milestones) read
    # one verdict per assertion, its status; over a 1.3.0 snapshot the features panel says the trusted record's reading is
    # not in it (views.features_note)
    by_status = latest_snapshot(events) is not None
    out = {}
    for aid in sorted(set(st) | set(rounds)):
        rs = rounds.get(aid) or {}
        if by_status and aid in st:
            verdict, rnd = judged(st[aid]["status"]), (max(rs) if rs else None)
        elif rs:
            last = max(rs)
            verdict, rnd = judged(rs[last]), last
        else:
            verdict, rnd = judged((st.get(aid) or {}).get("status")), None
        out.setdefault(feat.get(aid), []).append({"assertion_id": aid, "verdict": verdict, "round": rnd})
    return out


def rollup(members):
    """One feature's roll-up: assertions_total, confirmed, refuted, unjudged, latest_round, and its chip -- refuted when any
    is refuted, confirmed when all are, unjudged when none is judged, else partial; None (no verdict) with no assertion."""
    n = len(members)
    c = sum(1 for m in members if m["verdict"] == "confirmed")
    r = sum(1 for m in members if m["verdict"] == "refuted")
    rs = [m["round"] for m in members if m["round"] is not None]
    chip = None if n == 0 else "refuted" if r else "confirmed" if c == n else "unjudged" if c == 0 else "partial"
    return {"assertions_total": n, "confirmed": c, "refuted": r, "unjudged": n - c - r, "latest_round": max(rs) if rs else None, "verdict": chip}


def round_series(events, only=None):
    """[{round, confirmed, refuted, confirmed_ids, refuted_ids}] by round, over every assertion (or those in only)."""
    per = {}
    for aid, rs in assertion_rounds(events).items():
        if only is not None and aid not in only:
            continue
        for r, res in rs.items():
            j = judged(res)
            x = per.setdefault(r, {"confirmed": [], "refuted": []})
            if j:
                x[j].append(aid)
    return [{"round": r, "confirmed": len(per[r]["confirmed"]), "refuted": len(per[r]["refuted"]),
             "confirmed_ids": sorted(per[r]["confirmed"]), "refuted_ids": sorted(per[r]["refuted"])} for r in sorted(per)]


def dispatch_targets(events):
    """dispatch id -> its assertion_targets: the dispatch_opened line's, else the latest snapshot's dispatch_detail."""
    out = {}
    for e in of_kind(events, "dispatch_opened"):
        p = e["line"]["payload"]
        out[_id(p["dispatch_id"])] = [_id(x) for x in (p.get("assertion_targets") or [])]
    for did, d in snapshot_map(latest_snapshot(events), "dispatch_detail").items():
        if did not in out and isinstance(d, dict):
            out[did] = [_id(x) for x in (d.get("assertion_targets") or []) if x is not None]
    return out


def dispatch_first_seen(events):
    """dispatch id -> the ts it was first seen: its dispatch_opened line, else the first snapshot whose dispatch_detail names it."""
    out = {}
    for e in events:
        if e["kind"] == "dispatch_opened":
            out.setdefault(_id(e["line"]["payload"]["dispatch_id"]), e["ts"])
        elif e["kind"] == "mission_snapshot":
            for did in snapshot_map(e, "dispatch_detail"):
                out.setdefault(did, e["ts"])
    return out


CLOSED_MILESTONE = ("passed", "withdrawn")
# UI-3 (UC-14): a milestone the feed first shows already closed was never observed open -- no time of it is shown
NOT_RECORDED = "not recorded: closed before the feed began"
# UI-3 amendment 1 (UC-31): a planned milestone that is not the mission's next has no window
NOT_STARTED = "not started"
MILESTONE_TIMES_RULE = (
    "times observed at snapshots, in feed order. The mission's next milestone is the snapshot's current milestone when that "
    "milestone is listed and not closed; only otherwise the earliest milestone not closed, in the milestones' natural order "
    "(passed and withdrawn are closed; a withdrawn one is never the next). A milestone is taken as started when it became the "
    "mission's next milestone or was seen active, whichever a snapshot shows first: its window opens at that snapshot's ts. A "
    "planned milestone that is not the next has no running window (" + NOT_STARTED + " when it has no other). A window closes at "
    "the first snapshot showing the milestone closed: at its done_ts when that lies at or after the window's opening, else at "
    "that snapshot's ts. A window that ended because the milestone stopped being the next, with no close, is not counted. A "
    "closed milestone is reopened -- seen active, or again the next -- only by a snapshot of a checkout that itself showed it "
    "closed; a checkout that never showed it closed changes nothing about it. Reopened, it runs again and closed_at is its "
    "latest close. A milestone's elapsed is the sum of its windows: those that ended in a close, and the open one to the clock "
    "while it runs; a planned milestone keeps the sum and count of its windows that ended in a close. A milestone whose first "
    "appearance in the feed is already closed has no time (" + NOT_RECORDED + ") until it is reopened; a writer's started_ts is "
    "never read")


def _natural_id(mid):
    """A milestone id's natural order (M2 before M10) -- metrics.MILESTONE_ORDER's."""
    parts = re.split(r"(\d+)", str(mid))
    return [int(x) if n % 2 else x for n, x in enumerate(parts)], str(mid)


def milestone_times(events):
    """milestone id -> {opened_at, opened_basis, closed_at, closed_basis, elapsed_reason, windows}: UI-3 (UC-13..UC-17) as
    amendment 1 (UC-31..UC-33) and amendment 2 (UC-41..UC-44) rule it -- THE ONE DERIVATION of a milestone's windows,
    MILESTONE_TIMES_RULE. windows = [{opened_at, opened_seq, opened_basis, closed_at, closed_basis}] in order, the last with
    closed_at null while it runs; opened_at = the first window's opening, closed_at = the latest close (null while a window is
    open); each basis names the seq and states the number of windows; a window not counted (the milestone stopped being the
    next) is said with its seqs. elapsed_reason: NOT_RECORDED for a milestone first seen closed and never reopened,
    NOT_STARTED for a planned one with no window."""
    st_of, win, last_next = {}, {}, None
    for e in of_kind(events, "mission_snapshot"):
        mm = {k: v for k, v in snapshot_map(e, "milestones").items() if isinstance(v, dict)}
        sts = {mid: milestone_status(m.get("status")) for mid, m in mm.items()}
        cur = (e["line"].get("payload") or {}).get("current_milestone")
        # amendment 2 (UC-42): the snapshot's current milestone, where it is listed and open; else the earliest not closed
        if isinstance(cur, str) and sts.get(cur) is not None and sts[cur] not in CLOSED_MILESTONE:
            nxt, nxt_how = cur, "the mission's next milestone (the snapshot's current milestone)"
        else:
            open_ids = sorted((mid for mid, s in sts.items() if s not in CLOSED_MILESTONE), key=_natural_id)
            nxt, nxt_how = (open_ids[0] if open_ids else None), "the mission's next milestone (the earliest not closed)"
        last_next = nxt
        for mid, m in mm.items():
            st = sts[mid]
            x = st_of.get(mid)
            if x is None:
                x = st_of[mid] = {"first_closed": st in CLOSED_MILESTONE, "first_seq": e["seq"], "first_status": st, "last_status": st,
                                  "closed_in": set(), "dropped": []}
                win[mid] = []
            # amendment 2 (UC-41): once a checkout showed the milestone closed, a checkout that never did changes nothing about it
            if x["closed_in"] and e["key"] not in x["closed_in"] and st not in CLOSED_MILESTONE:
                continue
            x["last_status"] = st
            ws = win[mid]
            running = bool(ws) and ws[-1]["closed_at"] is None
            # amendment 1 (UC-31), amendment 2 (UC-43): a window held as the next ends uncounted when the milestone, still
            # planned, stops being the next -- said with its seqs
            if running and st not in CLOSED_MILESTONE and st != "active" and mid != nxt:
                w = ws.pop()
                x["dropped"].append((w["opened_seq"], e["seq"]))
                running = False
            if not running and st not in CLOSED_MILESTONE and (st == "active" or mid == nxt):
                how = "showing it active" if st == "active" else "in which it is " + nxt_how
                again = ", after its close" if (ws or x["first_closed"] or x["closed_in"]) else ""
                ws.append({"opened_at": e["ts"], "opened_seq": e["seq"],
                           "opened_basis": "the ts of the first mission_snapshot %s%s (seq %s)" % (how, again, e["seq"]),
                           "closed_at": None, "closed_basis": None})
            elif running and st in CLOSED_MILESTONE:
                w = ws[-1]
                done = m.get("done_ts") if isinstance(m.get("done_ts"), str) else None
                dt, ot = parse_ts(done), parse_ts(w["opened_at"])
                if dt is not None and ot is not None and dt >= ot:
                    w["closed_at"], w["closed_basis"] = done, "the done_ts of the first mission_snapshot showing it %s (seq %s), at or after the window's opening" % (st, e["seq"])
                else:
                    why = ("it carries no done_ts" if done is None else "its done_ts names no real instant" if dt is None else
                           "the opening names no real instant" if ot is None else "its done_ts lies before the window's opening")
                    w["closed_at"], w["closed_basis"] = e["ts"], "the ts of the first mission_snapshot showing it %s (seq %s); %s" % (st, e["seq"], why)
            if st in CLOSED_MILESTONE:
                x["closed_in"].add(e["key"])
    out = {}
    for mid, x in st_of.items():
        ws = win[mid]
        planned = x["last_status"] not in CLOSED_MILESTONE and x["last_status"] != "active"
        if planned and mid != last_next and ws and ws[-1]["closed_at"] is None:
            ws.pop()  # UC-31 at the feed's end: a planned milestone that is not the next has no running window
        dropped = "; ".join("was the mission's next milestone from seq %s to seq %s; not counted" % d for d in x["dropped"])
        if not ws:
            if x["first_closed"]:
                why = "%s (first seen %s, at seq %s)" % (NOT_RECORDED, x["first_status"], x["first_seq"])
                out[mid] = {"opened_at": None, "opened_basis": why + ("; " + dropped if dropped else ""), "closed_at": None, "closed_basis": why,
                            "elapsed_reason": NOT_RECORDED, "windows": []}
            elif x["last_status"] in CLOSED_MILESTONE:
                why = "not recorded: %s without being seen started (first listed at seq %s)" % (x["last_status"], x["first_seq"])
                out[mid] = {"opened_at": None, "opened_basis": why + ("; " + dropped if dropped else ""), "closed_at": None, "closed_basis": why,
                            "elapsed_reason": why, "windows": []}
            else:
                why = "%s: %s" % (NOT_STARTED, dropped if dropped else "planned, never the mission's next milestone nor seen active (first listed at seq %s)" % x["first_seq"])
                out[mid] = {"opened_at": None, "opened_basis": why, "closed_at": None, "closed_basis": None, "elapsed_reason": NOT_STARTED, "windows": []}
            continue
        n, last = len(ws), ws[-1]
        # UC-32: the basis states the number of windows, one included; UC-43: a window not counted is said with its seqs
        ob = ("1 window -- opened at " + ws[0]["opened_basis"]) if n == 1 else "%d windows -- the first opened at %s; reopened at %s" % (
            n, ws[0]["opened_basis"], "; ".join(w["opened_basis"] for w in ws[1:]))
        if dropped:
            ob += "; also " + dropped
        cb = None if last["closed_basis"] is None else "%s; the latest close of %d window%s" % (last["closed_basis"], n, "" if n == 1 else "s")
        out[mid] = {"opened_at": ws[0]["opened_at"], "opened_basis": ob, "closed_at": last["closed_at"], "closed_basis": cb,
                    "elapsed_reason": None, "windows": [dict(w) for w in ws]}
    # amendment 2 (UC-41; validator round 1, turn 3): the status the derivation accepted -- a checkout that never showed a
    # closed milestone closed changes nothing about it, its status included
    for mid, x in st_of.items():
        out[mid]["status"] = x["last_status"]
    return out


HALT_PRECEDENCE = ("raised_at: the HALT's own Raised stamp, else the halt_raised line's ts, else the HALT file's last write time "
                   "(a HALT under .mission-runtime is never committed); answered_at: the HALT's own Answered/Resolved stamp, else the "
                   "halt_resolved line's ts (ANSWERED or RESOLVED), else the ruling-citation's cited_at. A HALT is answered when a "
                   "halt_resolved (ANSWERED or RESOLVED) follows its halt_raised or the snapshot reads an unrevoked halt-ruling gate for it. "
                   "RELEASE-5 (ruling (m)): a HALT the snapshot reads as set_aside -- the stop evaluator's own detector does not count it "
                   "and no ruling record answers it -- is counted apart, never as open. A HALT raised after that snapshot is decided "
                   "by its place, as the evaluator's rule decides it: under a place the snapshot's scan set aside (scratch-copies, a "
                   "nested mission root) or outside the homes it scans, apart; in a home it scans, open. Amendment 1: each HALT is "
                   "decided by the newest snapshot of the checkout that holds it, and that snapshot's reading is the evaluator's for "
                   "the governing goal -- the one goal the mission's Stop hook runs: a HALT that goal's legacy allowlist answers is "
                   "answered by the allowlist, counted apart from the HALTs a gate answers, never open.")


def set_aside_halts(events):
    """RELEASE-5 group B (RB-8): the HALT ids read as set_aside -- HALT files the stop evaluator's own detector does not count
    and no ruling record answers (ruling (m): shown apart, never as open) -- each by its own checkout's newest snapshot."""
    return {k for k, v in halt_times(events).items() if v["state"] == "set_aside"}


# amendment 1 (RB-8): of one HALT id read in two checkouts, the state shown -- open where any checkout's evaluator counts it
HALT_STATE_RANK = {"open": 5, "answered": 4, "answered_allowlist": 3, "withdrawn": 2, "set_aside": 1}
# amendment 1 (RB-17): the states a 1.3.1 snapshot's halts map may carry, each the stop evaluator's reading
SNAPSHOT_HALT_STATES = ("open", "answered", "answered_allowlist", "set_aside")


def checkout_snapshots(events):
    """amendment 1: stream key -> the newest mission_snapshot of that stream (one checkout of the mission), for each stream
    that has one, in key order."""
    out = {}
    for e in of_kind(events, "mission_snapshot"):
        out[e["key"]] = e
    return {k: out[k] for k in sorted(out)}


def goal_readings(events):
    """amendment 1 (RB-17): per checkout, the governing goal its newest snapshot read -- [{checkout (the folder's name),
    goal (the snapshot's halt_reading.goal: read, goal, goal_file, named_in, why, ...) or None, note}]; note says the reading
    is not in a snapshot an earlier writer wrote (RB-16), with the command that writes a fresh one."""
    out = []
    snaps = checkout_snapshots(events)
    for key, snap in snaps.items():
        hr = (snap["line"].get("payload") or {}).get("halt_reading")
        g = hr.get("goal") if isinstance(hr, dict) else None
        out.append({"checkout": os.path.basename(str(snap.get("path") or "").rstrip("\\/")) or None, "goal": g if isinstance(g, dict) else None,
                    "note": None if isinstance(g, dict) else "the governing goal the HALT rule was read for is " + not_in_snapshot(events, root=snap.get("root"))})
    # validator round 1 (RB-16 over RB-8): a checkout with HALT lines and NO snapshot of its own (a work tree the LAM runner
    # registered and no verb has snapshotted) is said too -- its HALTs are decided by place, by the evaluator's default rule
    by_key = {}
    for e in of_kind(events, "halt_raised", "halt_resolved"):
        if e["key"] not in snaps:
            by_key.setdefault(e["key"], e)
    for key in sorted(by_key):
        name = os.path.basename(str(by_key[key].get("path") or "").rstrip("\\/")) or None
        out.append({"checkout": name, "goal": None,
                    "note": ("checkout %s has no snapshot of its own: its HALTs are decided by their place, by the stop evaluator's "
                             "default rule (.mission-runtime/halts and .mission-runtime/lam, scratch copies and nested mission roots set "
                             "apart), and no governing goal is read for it -- write one with %s" % (name, fresh_command(by_key[key].get("root"))))})
    return out


# validator round 1 (RB-8): the stop evaluator's default scan, as a reader for a checkout no snapshot of its own has read:
# its two homes, and the scratch-copies tree its rule always sets apart (a nested mission root is read from the checkout's disk)
DEFAULT_SCAN_READER = {"line": {"payload": {"halt_reading": {"scan_homes": [".mission-runtime/halts", ".mission-runtime/lam"],
                                                             "excluded_roots": [".mission-runtime/scratch-copies"]}}}}


def halt_holders(events):
    """validator round 1 (RB-8): halt id -> the stream key (the checkout) whose reading halt_times shows for it."""
    return _halt_times_by_checkout(events)[1]


def halt_times(events):
    """halt id -> {state (open / answered / withdrawn / set_aside), raised_at, raised_basis, answered_at, answered_basis}: the
    feed's halt_raised / halt_resolved lines and the newest snapshot's halts map (the artifacts), by HALT_PRECEDENCE.
    RELEASE-5 group B, amendment 1 (RB-8): EACH CHECKOUT ITS OWN SNAPSHOT. A HALT lives in one checkout's .mission-runtime
    (never committed), and that checkout's stop evaluator is the one that counts it; so each stream -- one checkout of the
    mission -- is read alone: its own lines and its own newest snapshot, as verify_reading reads a run's own stream. A
    snapshot another checkout of the mission wrote moves no HALT of this one. A HALT id read in more than one checkout takes
    the strongest state among them (HALT_STATE_RANK: open, then answered, withdrawn, set aside). Validator round 1: a
    checkout with no snapshot of its own -- a work tree the LAM runner registers at spawn writes none -- is read by its own
    lines, each HALT decided by its place under the stop evaluator's default rule (DEFAULT_SCAN_READER), wherever another
    checkout of the mission carries a 1.3.1 snapshot (the dashboard then reads the evaluator's rule); a mission no 1.3.1
    writer has snapshotted reads as 1.3.0 did."""
    return _halt_times_by_checkout(events)[0]


def _halt_times_by_checkout(events):
    """(halt_times, halt_holders) -- see halt_times."""
    streams = {}
    for e in events:
        streams.setdefault(e["key"], []).append(e)
    by_place = any("halt_reading" in (s["line"].get("payload") or {}) for s in checkout_snapshots(events).values())
    out, holder = {}, {}
    for key in sorted(streams):
        for hid, v in _halt_times_of_checkout(streams[key], by_place).items():
            if hid not in out or HALT_STATE_RANK.get(v["state"], 0) > HALT_STATE_RANK.get(out[hid]["state"], 0):
                out[hid], holder[hid] = v, key
    return out, holder


def _halt_times_of_checkout(events, by_place=False):
    """halt_times over ONE stream's events (one checkout): its lines and its own newest snapshot; with no snapshot of its own
    and by_place, its raised lines decided by place under the stop evaluator's default rule."""
    hs, art = halts(events), snapshot_map(latest_snapshot(events), "halts")
    snap = latest_snapshot(events)
    reader = None if snap is None or snapshot_lacks(events, "halt_reading") else snap
    placer = DEFAULT_SCAN_READER if (snap is None and by_place) else None
    pos = {id(e): i for i, e in enumerate(events)} if reader is not None else {}
    snap_at = pos.get(id(snap), -1) if reader is not None else -1
    out = {}
    for hid in sorted(set(hs) | set(art)):
        f = hs.get(hid) or {"raised": None, "resolved": None}
        a = art.get(hid) if isinstance(art.get(hid), dict) else {}
        if a.get("raised_basis") == "stamp" and isinstance(a.get("raised_at"), str):
            raised, rb = a["raised_at"], "the HALT's own Raised stamp"
        elif f["raised"] is not None:
            raised, rb = f["raised"]["ts"], "the halt_raised line's ts"
        elif isinstance(a.get("raised_at"), str):
            raised, rb = a["raised_at"], "the HALT file's last write time"
        else:
            raised, rb = None, None
        res = f["resolved"]
        word = res["line"]["payload"].get("resolution") if res is not None else None
        answered = (res is not None and word in ("ANSWERED", "RESOLVED")) or a.get("state") == "answered"
        ans, ab = None, None
        if answered:
            if a.get("answered_basis") == "stamp" and isinstance(a.get("answered_at"), str):
                ans, ab = a["answered_at"], "the HALT's own Answered/Resolved stamp"
            elif res is not None and word in ("ANSWERED", "RESOLVED"):
                ans, ab = res["ts"], "the halt_resolved line's ts (%s)" % word
            elif isinstance(a.get("answered_at"), str):
                ans, ab = a["answered_at"], "the ruling-citation's cited_at"
        state = "answered" if answered else "withdrawn" if (res is not None and word == "WITHDRAWN") else \
            "set_aside" if a.get("state") == "set_aside" else "answered_allowlist" if a.get("state") == "answered_allowlist" else "open"
        reason = a.get("reason") if isinstance(a.get("reason"), str) else None
        # RELEASE-5 group B (validator round 1, ruling (m)): over a 1.3.1 snapshot -- whose HALT states are the stop
        # evaluator's own reading -- the snapshot decides every HALT whose feed lines it already saw: a halt_resolved line
        # before it does not outrank the evaluator (a gate revoked after its ANSWERED line reads open again), and a HALT the
        # feed raised before it that its scan does not hold (under scratch-copies, say) is set apart, never open. A feed
        # line AFTER the snapshot is newer than it and decides as before.
        if reader is not None:
            fe = res if res is not None else f["raised"]
            newer = fe is not None and pos.get(id(fe), -1) > snap_at
            if not newer:
                if hid in art:
                    state = a.get("state") if a.get("state") in SNAPSHOT_HALT_STATES else state
                elif f["raised"] is not None and state == "open":
                    state, reason = "set_aside", ("set aside: the stop evaluator's scan in the newest snapshot does not hold this HALT "
                                                  "(it lies outside the places that scan reads, or is gone); never shown as open")
                if state != "answered":
                    ans, ab = None, None
            elif state == "open" and f["raised"] is not None:
                # validator round 2: a HALT raised AFTER the snapshot is decided by its place, as the evaluator's rule decides it
                # -- on the PATH: a place that rule set aside in the snapshot's scan (its scratch-copies tree, a nested mission
                # root it named) or outside the homes it scans is never open; in a home it scans, open until a fresh snapshot
                # reads it (a new HALT file there moves the derived state, so the documented command writes one)
                why = _halt_place(f["raised"]["line"].get("source_path"), reader, f["raised"].get("path"))
                if why is not None:
                    state, reason = "set_aside", ("set aside: raised after the newest snapshot, where the stop evaluator does not "
                                                  "count it -- " + why + "; never shown as open")
        elif placer is not None and state == "open" and f["raised"] is not None:
            # validator round 1: a checkout no snapshot of its own has read -- each raised HALT by its place, under the stop
            # evaluator's default rule, on the checkout's disk as it stands
            why = _halt_place(f["raised"]["line"].get("source_path"), placer, f["raised"].get("path"))
            if why is not None:
                state, reason = "set_aside", ("set aside: no snapshot of this checkout reads it, and the stop evaluator's default rule "
                                              "does not count it -- " + why.replace(" in the newest snapshot", "") + "; never shown as open")
        out[hid] = {"state": state, "raised_at": raised, "raised_basis": rb, "answered_at": ans, "answered_basis": ab}
        if state in ("set_aside", "answered_allowlist"):
            out[hid]["reason"] = reason
    return out


HALT_SCAN_HOMES = (".mission-runtime/halts", ".mission-runtime/lam")


def _halt_place(path, snap, checkout=None):
    """Validator rounds 2, 3: why a HALT at <path> (relative to its checkout) is not counted by the stop evaluator -- None when
    it is. By the places its scan in <snap> (a 1.3.1 mission_snapshot) recorded: a place it set aside, or outside the homes it
    scans. Then, where the checkout folder is on this host, by the checkout's disk as it stands now, read only: a HALT no
    longer at its path is not counted (moved out of the scanned planes, or gone), and one under a directory strictly below
    its scan home that carries its own .mission\\ lies under a nested mission root. The rule is the evaluator's
    (tools/lam/mission-goal-check.ps1 Get-HaltScanExclusion, decided on the path and on nothing a file says; its scan of the
    homes, Get-OpenHalts); the evaluator cannot be called from this service, so its rule is applied here to its own
    recorded places and to the disk it reads."""
    if not isinstance(path, str) or not path.strip():
        return None
    hr = ((snap["line"].get("payload") or {}).get("halt_reading") or {}) if snap is not None else {}
    homes = [h.replace("\\", "/").strip("/") for h in (hr.get("scan_homes") or HALT_SCAN_HOMES) if isinstance(h, str)]
    p = _norm_rel(path)
    for x in [_norm_rel(e) for e in (hr.get("excluded_roots") or []) if isinstance(e, str)]:
        if x and (p == x or p.startswith(x + "/")):
            return "it lies under %s, a place the evaluator's scan in the newest snapshot set aside" % x
    home = next((h for h in homes if p.startswith(_norm_rel(h) + "/")), None)
    if home is None:
        return "it lies outside the homes the evaluator scans (%s)" % ", ".join(homes)
    if isinstance(checkout, str) and checkout and os.path.isdir(checkout):
        parts = [s for s in path.replace("\\", "/").split("/") if s and s != "."]
        if not os.path.isfile(os.path.join(checkout, *parts)):
            return "it is no longer at %s (moved out of the scanned planes, or gone)" % "/".join(parts)
        below = parts[len(home.split("/")):]
        d = os.path.join(checkout, *home.split("/"))
        for seg in below[:-1]:
            d = os.path.join(d, seg)
            if os.path.isdir(os.path.join(d, ".mission")):
                return "it lies under a nested mission root (it carries its own .mission\\) at %s" % os.path.relpath(d, checkout).replace("\\", "/")
    return None


def open_halt_ids(events):
    """RELEASE-5 group B (validator rounds 1, 2): the HALTs every open figure counts -- the HALT card's, the HALTs-open KPI's,
    the fleet's and the errors' -- one set: the halt_times states. Over a 1.3.1 snapshot those are the stop evaluator's own
    reading, and newer feed lines decided by place; over an earlier snapshot, the 1.3.0 reading (which cannot tell the HALTs
    the evaluator does not count apart, and the card says so) -- the card and the figures read the same set either way."""
    return {k for k, v in halt_times(events).items() if v["state"] == "open"}


# B-10 (register row 498): the kinds a verify_result's additive divergence_list entry may name. kept-equal (a kept file now
# equal to upstream, row 518) is no divergence; a word outside the map is not listed, and is counted as unrecognized.
# UI-2 S2 (B-10's emitter): install.ps1 -Verify prints and lists CHANGED, MISSING, REFUSED (a path the guard refuses) and
# kept-differs; read without regard to case. "extra" is kept for a writer that lists one.
DIVERGENCE_KINDS = {"changed": "changed", "missing": "missing", "extra": "extra", "kept-differs": "kept-differs", "refused": "refused"}
NO_DIVERGENCE = ("kept-equal",)


def verify_divergences(e):
    """The latest verify_result's divergences, listed: {listed: [{path, kind, lock_sha8, now_sha8}], unrecognized,
    kept_equal}, or None when the line carries no divergence_list (only its count)."""
    lst = (e["line"].get("payload") or {}).get("divergence_list") if e else None
    if not isinstance(lst, list):
        return None
    listed, unknown, kept = [], 0, 0
    for d in lst:
        word = str(d.get("kind")).strip().lower() if isinstance(d, dict) else None
        if word in NO_DIVERGENCE:
            kept += 1
            continue
        kind = DIVERGENCE_KINDS.get(word)
        if kind is None:
            unknown += 1
            continue
        a, b = d.get("lock_sha256"), d.get("now_sha256")
        both = isinstance(a, str) and isinstance(b, str)
        listed.append({"path": d.get("path"), "kind": kind, "lock_sha8": a[:8] if both else None, "now_sha8": b[:8] if both else None})
    return {"listed": listed, "unrecognized": unknown, "kept_equal": kept}
