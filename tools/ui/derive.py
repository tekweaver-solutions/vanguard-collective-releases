"""What the feed says the mission's state is, read from its events at query time (no statistic here:
ui.metrics computes those). An event is a dict {key, path, seq, ts, kind, line}; a mission's events from
all its streams are read in (ts, checkout path, seq) order -- the feed's own clock, never this host's.

A schema-valid line can still carry an id that is not a string (the schema leaves most payload ids untyped)
or a ts that matches the pattern but names no real instant (2026-02-30): ids are read through _id, and a ts
that does not parse gives None, so no line of any one feed can make an answer fail.
"""
import heapq
import json
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


def dispatches(events):
    """dispatch id -> {opened, finalized (the latest)}."""
    out = {}
    for e in of_kind(events, "dispatch_opened", "dispatch_finalized"):
        d = out.setdefault(_id(e["line"]["payload"]["dispatch_id"]), {"opened": None, "finalized": None})
        d["opened" if e["kind"] == "dispatch_opened" else "finalized"] = e
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
    out = {}
    for aid in sorted(set(st) | set(rounds)):
        rs = rounds.get(aid) or {}
        if rs:
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


def milestone_times(events):
    """milestone id -> {opened_at, opened_basis, closed_at, closed_basis}. THE FIRST-SEEN RULE: opened = the latest map's
    started_ts (the writer's observed start), else the ts of the first snapshot whose map shows the milestone active, when
    no earlier snapshot showed it passed or withdrawn (a milestone first seen already closed was never seen open: its
    opening is unknown, never its closing); closed = the latest map's done_ts, else the ts of the first snapshot showing it
    passed or withdrawn -- cleared when a later snapshot shows it in neither."""
    out = {}
    for e in of_kind(events, "mission_snapshot"):
        for mid, m in snapshot_map(e, "milestones").items():
            if not isinstance(m, dict):
                continue
            st = milestone_status(m.get("status"))
            t = out.setdefault(mid, {"opened_at": None, "opened_basis": None, "closed_at": None, "closed_basis": None, "seen_closed": False})
            if st in ("passed", "withdrawn") and t["opened_at"] is None and not t["seen_closed"]:
                t["seen_closed"], t["opened_basis"] = True, "unknown: first seen already %s (seq %s)" % (st, e["seq"])
            if t["opened_at"] is None and not t["seen_closed"] and st == "active":
                t["opened_at"], t["opened_basis"] = e["ts"], "the first snapshot showing it active (seq %s)" % e["seq"]
            if st in ("passed", "withdrawn"):
                if t["closed_at"] is None:
                    t["closed_at"], t["closed_basis"] = e["ts"], "the first snapshot showing it %s (seq %s)" % (st, e["seq"])
            else:
                t["closed_at"], t["closed_basis"] = None, None
    for mid, m in snapshot_map(latest_snapshot(events), "milestones").items():
        if isinstance(m, dict) and mid in out:
            if isinstance(m.get("started_ts"), str):
                out[mid]["opened_at"], out[mid]["opened_basis"] = m["started_ts"], "the snapshot's started_ts"
            if isinstance(m.get("done_ts"), str):
                out[mid]["closed_at"], out[mid]["closed_basis"] = m["done_ts"], "the snapshot's done_ts"
    for t in out.values():
        t.pop("seen_closed", None)
    return out


HALT_PRECEDENCE = ("raised_at: the HALT's own Raised stamp, else the halt_raised line's ts, else the HALT file's last write time "
                   "(a HALT under .mission-runtime is never committed); answered_at: the HALT's own Answered/Resolved stamp, else the "
                   "halt_resolved line's ts (ANSWERED or RESOLVED), else the ruling-citation's cited_at. A HALT is answered when a "
                   "halt_resolved (ANSWERED or RESOLVED) follows its halt_raised or the snapshot reads an unrevoked halt-ruling gate for it.")


def halt_times(events):
    """halt id -> {state (open / answered / withdrawn), raised_at, raised_basis, answered_at, answered_basis}: the feed's
    halt_raised / halt_resolved lines and the latest snapshot's halts map (the artifacts), by HALT_PRECEDENCE."""
    hs, art = halts(events), snapshot_map(latest_snapshot(events), "halts")
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
        state = "answered" if answered else "withdrawn" if (res is not None and word == "WITHDRAWN") else "open"
        out[hid] = {"state": state, "raised_at": raised, "raised_basis": rb, "answered_at": ans, "answered_basis": ab}
    return out


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
