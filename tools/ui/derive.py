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
