"""THE metrics module (ADR-045): every statistic the service shows is computed here, at query time, from the
projection's raw events -- never stored, never computed twice. Every value carries its formula and its
window. Time spans are differences of the feed's own ts values, never this host's clock.
"""
import re
import statistics
from datetime import timedelta

from ui import derive, errors


def _stat(value, formula, window, **extra):
    s = {"value": value, "formula": formula, "window": window}
    s.update(extra)
    return s


def _ratio(num, den):
    return None if den == 0 else round(num / den, 6)


def _seconds(a, b):
    """b - a in seconds, or None when either ts names no real instant."""
    ta, tb = derive.parse_ts(a), derive.parse_ts(b)
    return None if ta is None or tb is None else (tb - ta).total_seconds()


def stream_counts(seqs, rejections, kinds, known_kinds):
    """One stream's ingest figures: seqs = the ingested seqs; rejections = [{seq, reason}]; kinds = the
    ingested lines' kinds. A gap is a run of seq missing between the lowest and highest seq seen (ingested
    or carried by a rejected line): loss, shown with its range."""
    seen = sorted(set(seqs) | {r["seq"] for r in rejections if isinstance(r["seq"], int)})
    gaps = [{"from": a + 1, "to": b - 1} for a, b in zip(seen, seen[1:]) if b - a > 1]
    by_reason, unknown = {}, {}
    for r in rejections:
        by_reason[r["reason"]] = by_reason.get(r["reason"], 0) + 1
    for k in kinds:
        if k not in known_kinds:
            unknown[k] = unknown.get(k, 0) + 1
    return {"events": len(seqs), "rejected": len(rejections), "rejected_by_reason": dict(sorted(by_reason.items())),
            "gaps": gaps, "gap_count": len(gaps), "unknown_kinds": dict(sorted(unknown.items())),
            "unknown_kind_count": sum(unknown.values()),
            "earliest_seq": min(seqs) if seqs else None, "last_seq": max(seqs) if seqs else None}


def stream_totals(counts):
    """A mission's feed figures: the sums of its streams' stream_counts."""
    return {k: sum(c[k] for c in counts) for k in ("events", "rejected", "gap_count", "unknown_kind_count")}


def _tally(st):
    """(all defined, green, red) over derive.assertions' map."""
    return (len(st), sum(1 for a in st.values() if a["status"] == "green"), sum(1 for a in st.values() if a["status"] == "red"))


def mission_stats(events, window):
    """The Stats screen's figures for one mission; events in feed order (derive.ordered)."""
    defined, green, red = _tally(derive.assertions(events))
    out = {}
    out["green"] = _stat(_ratio(green, defined), "green / all defined", window, label="Green", numerator=green, denominator=defined,
                         basis="each assertion's latest status, from the mission_snapshot assertion maps and assertion_result lines in feed order")
    out["pass_rate_evaluated"] = _stat(_ratio(green, green + red), "green / (green + red)", window, label="pass rate of evaluated",
                                       numerator=green, denominator=green + red, basis="assertions whose latest status is green or red")

    disp = derive.dispatches(events)
    fin = [d["finalized"] for d in disp.values() if d["finalized"] is not None]
    partial = sum(1 for f in fin if derive.is_partial(f))
    out["dispatches_finalized"] = _stat(len(fin) - partial, "count of dispatches whose latest dispatch_finalized is not partial", window)
    out["dispatches_partial"] = _stat(partial, "count of dispatches whose latest dispatch_finalized has partial true or manifest_state PARTIAL", window)
    # RELEASE-5 group B (RB-13; validator round 1): partial is the manifest's word, never a state of the dispatch -- the
    # dispatches finalized, whatever their manifest, and the partial manifests with their capture gaps, apart (the two
    # figures above keep their 1.2.0 meaning for the series that read them)
    mf = derive.manifests(events)
    out["dispatches_closed"] = _stat(len(fin), "count of dispatches with a dispatch_finalized line (a finalized line whose dispatch_id is an "
                                               "opened line's session_id is that dispatch's), whatever their manifest", window)
    out["manifests_partial"] = _stat(sum(1 for m in mf if m["partial"]), "count of sealed manifests whose latest dispatch_finalized line reads "
                                     "partial true, on the sessions they belong to; capture_gaps = the sum of their capture_gaps_count", window,
                                     capture_gaps=sum(m["capture_gaps_count"] or 0 for m in mf if m["partial"]))

    rounds = {}
    for e in derive.of_kind(events, "assertion_result"):
        p = e["line"]["payload"]
        r = rounds.setdefault(p["round"], {"confirmed": 0, "refuted": 0})
        if p["result"] == "green":
            r["confirmed"] += 1
        elif p["result"] == "red":
            r["refuted"] += 1
    out["validator_by_round"] = _stat(
        [{"round": n, "confirmed": rounds[n]["confirmed"], "refuted": rounds[n]["refuted"]} for n in sorted(rounds)],
        "per round: assertion_result lines with result green (confirmed) and red (refuted)", window)

    hs = derive.halts(events)
    raised = [h for h in hs.values() if h["raised"] is not None]
    resolved = [h for h in raised if h["resolved"] is not None]
    spans = [x for x in (_seconds(h["raised"]["ts"], h["resolved"]["ts"]) for h in resolved) if x is not None]
    out["halts_raised"] = _stat(len(raised), "count of HALT ids with a halt_raised line", window)
    out["halts_resolved"] = _stat(len(resolved), "count of raised HALT ids whose latest halt_raised is followed by a halt_resolved", window)
    out["halt_mean_time_to_resolve_s"] = _stat(round(sum(spans) / len(spans), 3) if spans else None,
                                               "mean over resolved HALTs of (halt_resolved ts - halt_raised ts), seconds; a pair whose ts names no real instant is left out", window,
                                               resolved_measured=len(spans))

    calls = derive.of_kind(events, "tool_call")
    captured = [e for e in calls if e["line"]["payload"].get("exit_code") is not None]
    nonzero = sum(1 for e in captured if e["line"]["payload"]["exit_code"] != 0)
    out["tool_call_nonzero_exit_rate"] = _stat(
        _ratio(nonzero, len(captured)) if captured else "not captured",
        "tool_call lines with exit_code non-zero / tool_call lines with exit_code captured; \"not captured\" when every exit_code is null",
        window, numerator=nonzero, denominator=len(captured), tool_calls=len(calls))

    out["elapsed_per_milestone"] = _stat(_segments(events), "per milestone: ts of the first snapshot naming the next milestone (or, for the current one, "
                                                            "the mission's last line) - ts of the first snapshot naming it, seconds", window)
    return out


def _segments(events):
    """The current_milestone runs of the mission's snapshots: [{milestone, from_ts, to_ts, closed, elapsed_s}]. A milestone the
    latest snapshot's map shows withdrawn has no run (it is out of every elapsed and slowest figure); the last run of a
    milestone that map shows passed is closed, ending at its done_ts -- unknown, so unmeasured, where the feed carries none."""
    snap = derive.latest_snapshot(events)
    mm = snap["line"]["payload"].get("milestones") if snap else None
    mm = mm if isinstance(mm, dict) else {}
    status = {k: derive.milestone_status(v.get("status")) for k, v in mm.items() if isinstance(v, dict)}
    segs, cur = [], None
    for e in derive.of_kind(events, "mission_snapshot"):
        m = e["line"]["payload"].get("current_milestone")
        if cur is not None and m == cur["milestone"]:
            continue
        if cur is not None:
            cur["to_ts"], cur["closed"] = e["ts"], True
            segs.append(cur)
        cur = None if m is None else {"milestone": m, "from_ts": e["ts"], "to_ts": None, "closed": False}
    if cur is not None:
        if status.get(cur["milestone"]) == "passed":
            done = mm[cur["milestone"]].get("done_ts")
            cur["to_ts"], cur["closed"] = (done if isinstance(done, str) else None), True
        else:
            cur["to_ts"] = events[-1]["ts"]
        segs.append(cur)
    segs = [s for s in segs if status.get(s["milestone"]) != "withdrawn"]
    for s in segs:
        s["elapsed_s"] = None if s["to_ts"] is None else _seconds(s["from_ts"], s["to_ts"])
    return segs


# =================================================================================================
# UI-1 S2-AM1 (V-16..V-20): the figures the dashboard's tiles, cards and charts show, so the SPA computes none.
# THE CLOCK of a mission's figures is the mission feed's last ts: the ts of the mission's last line in feed
# order (derive.ordered), its last_activity_ts. THE CLOCK of a fleet figure is the fleet's last ts: the latest
# of the missions' clocks. Every age_s and elapsed_s is a difference against one of them, never this host's.
# =================================================================================================
_DAY = timedelta(days=1)
_WEEK = timedelta(days=7)
DONE_STATES = ("Complete", "Aborted")
NOT_CAPTURED = "not captured"
MISSION_CLOCK = "the mission feed's last ts (the latest ts among the mission's lines: its last line's, unless a host clock stepped back)"
FLEET_CLOCK = "the fleet's last ts (the latest of the missions' last-line ts)"


def _fmt(dt):
    """A datetime in the feed's own ts form (milliseconds, Z)."""
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (dt.microsecond // 1000)


def mission_clock(events):
    """MISSION_CLOCK: the latest real instant among the lines. Within a stream seq is the order (derive.ordered), so after
    a host clock stepped back the last line in feed order is not the latest; measuring from it would put lines after the
    clock (a negative age, a bucket holding a line later than its end). The last line's ts when no ts is a real instant."""
    real = [e["ts"] for e in events if derive.parse_ts(e["ts"]) is not None]
    if real:
        return max(real, key=derive.parse_ts)
    return events[-1]["ts"] if events else None


def fleet_clock(clocks):
    """The latest of the missions' clocks that names a real instant, or None."""
    real = [c for c in clocks if derive.parse_ts(c) is not None]
    return max(real, key=derive.parse_ts) if real else None


def _milestone_at(events, target):
    """The current_milestone of the latest mission_snapshot at or before target, in feed order."""
    m = None
    for e in events:
        if e["kind"] == "mission_snapshot":
            m = e["line"]["payload"].get("current_milestone")
        if e is target:
            break
    return m


def _open_session_starts(events):
    """session id -> the latest session_start of each open session (derive.open_sessions' ids)."""
    starts = {}
    for e in derive.of_kind(events, "session_start"):
        starts[derive._id(e["line"]["payload"]["session_id"])] = e
    return {sid: starts[sid] for sid in derive.open_sessions(events)}


def _open_dispatches(events):
    """dispatch id -> its dispatch_opened, for dispatches with no dispatch_finalized."""
    return {d: v["opened"] for d, v in sorted(derive.dispatches(events).items()) if v["opened"] is not None and v["finalized"] is None}


def _open_halts(events):
    """The halt_raised lines of the open HALTs. RELEASE-5 group B (RB-8, ruling (m); validator round 1): the open set is
    derive.open_halt_ids -- over a 1.3.1 snapshot the stop evaluator's own reading -- the one every figure counts."""
    hs = derive.halts(events)
    return [hs[hid]["raised"] for hid in sorted(derive.open_halt_ids(events)) if hid in hs and hs[hid]["raised"] is not None]


def _open_halt_count(events):
    return len(derive.open_halt_ids(events))


def _partial_count(events):
    return sum(1 for d in derive.dispatches(events).values() if d["finalized"] is not None and derive.is_partial(d["finalized"]))


def _exit_codes(events):
    codes = [e["line"]["payload"].get("exit_code") for e in derive.of_kind(events, "tool_call")]
    captured = [c for c in codes if c is not None]
    return len(codes), len(captured), sum(1 for c in captured if c != 0)


ASSERTIONS_FORMULA = ("value = green / all defined; green, red = assertions whose latest status is green, red; "
                      "pending = all defined - green - red (pending, skipped or any other status); total = all defined")


def assertion_figure(events, window):
    """V-18: one mission's assertion donut and tile."""
    defined, green, red = _tally(derive.assertions(events))
    return _stat(_ratio(green, defined), ASSERTIONS_FORMULA, window, green=green, red=red, pending=defined - green - red, total=defined,
                 basis="each assertion's latest status, from the mission_snapshot assertion maps and assertion_result lines in feed order")


def top_error(errs, clock, window, against=MISSION_CLOCK):
    """V-18: the card's error strip -- the first of the mission's ranked errors. On /api/missions its age is against the
    fleet's clock (F5: one clock per card)."""
    f = ("the first of the mission's errors as ranked (severity rank, then class order, then ts); kind = its class; more = the number of "
         "the mission's other errors; age_s = " + against + " - the error line's ts, seconds")
    if not errs:
        return _stat(None, f, window, kind=None, title=None, severity=None, rank=None, detail=None, source_path=None, sha256=None, source=None,
                     stream=None, seq=None, ts=None, age_s=None, more=0)
    e = errs[0]
    return _stat(e["class"], f, window, kind=e["class"], title=e["title"], severity=e["severity"], rank=e["rank"], detail=e["detail"],
                 source_path=e["source_path"], sha256=e["sha256"], source=e["source"], stream=e["stream"], seq=e["seq"], ts=e["ts"],
                 age_s=_seconds(e["ts"], clock), more=len(errs) - 1)


def error_ages(errs, clock, window):
    """The Errors panel's age per row, in the errors' own (ranked) order."""
    return {"formula": "per error, in the errors' ranked order: age_s = " + MISSION_CLOCK + " - the error line's ts, seconds", "window": window,
            "ages": [{"class": e["class"], "stream": e["stream"], "seq": e["seq"], "ts": e["ts"], "age_s": _seconds(e["ts"], clock)} for e in errs]}


def last_verify(events, clock, window, against=MISSION_CLOCK):
    """V-18: the latest verify -- verdict, what it covered (L-6: scope), checks, age. On /api/missions its age is against
    the fleet's clock (F5: one clock per card); on the Project tile, against the mission's."""
    f = ("the mission's latest verify_result in feed order: value = its verdict; scope = its arms_run and against, and the current_milestone "
         "of the latest mission_snapshot at or before it; checks = the number of arms run; age_s = " + against + " - its ts, seconds")
    v = derive.latest_verify(events)
    if v is None:
        return _stat(None, f, window, verdict=None, scope=None, checks=None, divergences=None, ts=None, age_s=None, source=None,
                     evaluator=None, blocking=None)
    p = v["line"]["payload"]
    arms = p.get("arms_run") if isinstance(p.get("arms_run"), list) else []
    ev = derive.verify_reading(events)
    return _stat(p.get("verdict"), f, window, verdict=p.get("verdict"),
                 scope={"milestone": _milestone_at(events, v), "arms_run": p.get("arms_run"), "against": p.get("against")},
                 checks=len(arms), divergences=p.get("divergences"), ts=v["ts"], age_s=_seconds(v["ts"], clock),
                 source=v["line"]["source_path"] + "@" + v["line"]["sha256"],
                 # RELEASE-5 group B (RB-7): the stop evaluator's reading of this run, and whether the card blocks
                 evaluator=ev, blocking=_verify_blocks(p, ev), evaluator_rule=derive.VERIFY_READING_RULE, evaluator_note=_evaluator_note(events, ev))


def _verify_blocks(payload, reading):
    """RB-7: a verify that did not PASS blocks unless the stop evaluator's reading of that same run admits it."""
    return payload.get("verdict") != "PASS" and not (reading is not None and reading["admits"])


def open_figure(events, window):
    """The card's open sessions and dispatches."""
    s, d = len(_open_session_starts(events)), len(_open_dispatches(events))
    return _stat(s, "value = sessions = session ids whose latest session_start has no session_stop after it; dispatches = dispatch ids "
                    "with a dispatch_opened and no dispatch_finalized", window, sessions=s, dispatches=d)


def spec_version(events, clock, window):
    """The Project tile "spec version"."""
    f = ("value = the to_version of the mission's latest spec_bumped line in feed order; amendments = the number of spec_bumped lines; "
         "age_s = " + MISSION_CLOCK + " - its ts, seconds")
    bumps = derive.of_kind(events, "spec_bumped")
    # RELEASE-5 group B (RB-6): the mission's current spec version as the latest snapshot read it from the mission's own state
    # (.mission/spec/current.txt); the spec_bumped lines stay the history (a close bumps the spec with no such line)
    sv = (derive.latest_snapshot(events) or {"line": {"payload": {}}})["line"].get("payload", {}).get("spec_version")
    state = sv.get("current") if isinstance(sv, dict) and isinstance(sv.get("current"), str) and sv.get("current") else None
    last = bumps[-1] if bumps else None
    lp = last["line"]["payload"] if last else {}
    if state is not None:
        fs = ("value = the mission's current spec version, read by the snapshot writer from the mission's own state (" + str(sv.get("source")) +
              "), the latest snapshot's spec_version; last_bumped = the to_version of the latest spec_bumped line (the history); amendments = the "
              "number of spec_bumped lines")
        return _stat(state, fs, window, amendments=len(bumps), from_version=lp.get("from_version"), amendment_id=lp.get("amendment_id"),
                     ts=last["ts"] if last else None, age_s=_seconds(last["ts"], clock) if last else None, reason=None, basis="state",
                     last_bumped=lp.get("to_version"), current_spec_version=sv.get("current_spec_version"), state_note=None)
    # RB-16: the state's version is not in a snapshot an earlier writer wrote -- said, with the command; the history stands
    note = ("the mission state's spec version is " + derive.not_in_snapshot(events)) if derive.snapshot_lacks(events, "spec_version") else None
    if not bumps:
        return _stat(None, f, window, amendments=0, from_version=None, amendment_id=None, ts=None, age_s=None, reason="no spec_bumped line",
                     basis=None, last_bumped=None, state_note=note)
    return _stat(lp.get("to_version"), f, window, amendments=len(bumps), from_version=lp.get("from_version"), amendment_id=lp.get("amendment_id"),
                 ts=last["ts"], age_s=_seconds(last["ts"], clock), reason=None, basis="spec_bumped", last_bumped=lp.get("to_version"), state_note=note)


def _evaluator_note(events, reading):
    """RB-16: where no evaluator reading is shown because the snapshot carries no goal verdicts (an earlier writer's), say so."""
    return ("the stop evaluator's reading is " + derive.not_in_snapshot(events)) if reading is None and derive.snapshot_lacks(events, "goal_verdicts") else None


def clock_window(window, clock, against=FLEET_CLOCK):
    """A window that names the clock its ages are against (F5): the window, then that clock and its ts."""
    return "%s; ages against %s: %s" % (window, against, clock if clock is not None else "none (no line names a real instant)")


def last_activity(events, clock, window, against=FLEET_CLOCK):
    """The last activity. On the card (/api/missions, the fleet's body) its age is against the fleet's clock; on the
    Project tile (/api/missions/{id}, which reads only the mission's own streams) against the mission's, where it is 0
    unless a host clock stepped back -- the fleet-relative age is the card's."""
    f = "value = the ts of the mission's last line in feed order; age_s = " + against + " - it, seconds"
    if not events:
        return _stat(None, f, window, kind=None, seq=None, stream_key=None, age_s=None)
    e = events[-1]
    return _stat(e["ts"], f, window, kind=e["kind"], seq=e["seq"], stream_key=e["key"], age_s=_seconds(e["ts"], clock))


LIVE_SESSION_FORMULA = ("an open session (its latest session_start has no session_stop after it); role and started_ts from that "
                        "session_start; tool_calls = the mission's tool_call lines naming the session; failed_calls = those with exit_code "
                        "captured and non-zero, null with note \"not captured\" when none of its exit_codes is captured; elapsed_s = "
                        + MISSION_CLOCK + " - started_ts, seconds")
LIVE_DISPATCH_FORMULA = ("an open dispatch (a dispatch_opened and no dispatch_finalized); kind and feature from the dispatch_opened; "
                         "milestone = the current_milestone of the latest mission_snapshot at or before it; elapsed_s = "
                         + MISSION_CLOCK + " - opened_ts, seconds")


def live(events, clock, window):
    """V-19: the Live activity panel -- open sessions with their tool-call counts, open dispatches. Each row carries its
    own formula and window (UI-1 S4 C-6), as well as the panel's map of them."""
    codes = {}
    for e in derive.of_kind(events, "tool_call"):
        codes.setdefault(derive._id(e["line"]["payload"].get("session_id")), []).append(e["line"]["payload"].get("exit_code"))
    sessions = []
    for sid, s in sorted(_open_session_starts(events).items()):
        cs = codes.get(sid, [])
        captured = [c for c in cs if c is not None]
        failed = sum(1 for c in captured if c != 0) if captured else None
        sessions.append({"session_id": sid, "role": s["line"]["payload"].get("role"), "host_id": s["line"]["host_id"], "started_ts": s["ts"],
                         "tool_calls": len(cs), "failed_calls": failed, "note": NOT_CAPTURED if failed is None else None,
                         "elapsed_s": _seconds(s["ts"], clock), "formula": LIVE_SESSION_FORMULA, "window": window})
    dispatches = []
    for did, o in _open_dispatches(events).items():
        p = o["line"]["payload"]
        dispatches.append({"dispatch_id": did, "kind": p.get("kind"), "feature": p.get("feature"), "milestone": _milestone_at(events, o),
                           "opened_ts": o["ts"], "elapsed_s": _seconds(o["ts"], clock), "formula": LIVE_DISPATCH_FORMULA, "window": window})
    # RELEASE-5 group B (RB-14; validator round 1): per open session, how many of its tool calls carry no exit code -- beside the
    # rows (whose fields V-19 holds closed), so a session of captured and null codes never reads a bare count over the null ones
    uncaptured = {s["session_id"]: sum(1 for c in codes.get(s["session_id"], []) if c is None) for s in sessions}
    return {"sessions": sessions, "dispatches": dispatches, "window": window, "exit_codes_not_captured": uncaptured, "formula": {
        "sessions": "the open sessions (session ids whose latest session_start has no session_stop after it), by id; role and started_ts from that session_start",
        "tool_calls": "the mission's tool_call lines naming the session",
        "failed_calls": "those of them with exit_code captured and non-zero; null, note \"not captured\", when no exit_code of the session is captured",
        "dispatches": "the open dispatches (a dispatch_opened and no dispatch_finalized), by id; kind and feature from the dispatch_opened",
        "milestone": "the current_milestone of the latest mission_snapshot at or before the dispatch_opened",
        "elapsed_s": MISSION_CLOCK + " - started_ts (a session) or opened_ts (a dispatch), seconds"}}


MILESTONE_ORDER = "ordered by id naturally (its digit runs read as numbers: M2 before M10)"
MILESTONE_ELAPSED = ("(done_ts, else " + MISSION_CLOCK + ") - started_ts, seconds; null while started_ts is null (elapsed_reason \"not "
                     "started\"), when a ts names no real instant (\"a ts names no real instant\"), or when it would be negative "
                     "(\"started_ts after the clock\", or \"started_ts after done_ts\")")
MILESTONE_ROW_FORMULA = ("a milestone of the latest mission_snapshot's milestones map, " + MILESTONE_ORDER + "; title, status, assertions_total "
                         "and assertions_green as the snapshot writer derived them; elapsed_s = " + MILESTONE_ELAPSED)


def _natural(mid):
    """A milestone id's natural order: its digit runs as numbers, then the id itself (M2 < M10; M02 beside M2)."""
    parts = re.split(r"(\d+)", mid)
    return [int(p) if n % 2 else p for n, p in enumerate(parts)], mid


def _milestone_elapsed(start, done, clock):
    """(elapsed_s, elapsed_reason) of one milestone row: never negative (UI-1 S4 C-6)."""
    if start is None:
        return None, "not started"
    end = done if done is not None else clock
    el = _seconds(start, end)
    if el is None:
        return None, "a ts names no real instant"
    if el < 0:
        return None, "started_ts after done_ts" if done is not None else "started_ts after the clock"
    return el, None


def milestones(events, clock, window):
    """V-20: the Milestones table and the milestone-progress tile, from the latest snapshot's milestones map (U-17).
    Returns {list, progress, reason, basis}; list and progress are None, with the reason, when the map is absent
    ("snapshot predates milestones field") or present but not a map ("malformed")."""
    snap = derive.latest_snapshot(events)
    basis = {"window": window, "snapshot": None if snap is None else {"stream_key": snap["key"], "seq": snap["seq"], "ts": snap["ts"]},
             "formula": {"milestones": "the latest mission_snapshot's milestones map, " + MILESTONE_ORDER + "; title, status, assertions_total and "
                                       "assertions_green as the snapshot writer derived them",
                         "elapsed_s": MILESTONE_ELAPSED}}
    pf = ("of = the milestones in the latest mission_snapshot's milestones map, each status read in the closed set (a 1.0 line's done as "
          "passed); passed = those with status passed; pending = those with status pending; withdrawn = those with status withdrawn, counted on "
          "their own and left out of every denominator; active = the others; progress = passed / (of - withdrawn); complete = passed and "
          "planned = pending (the 1.1.0 names); current = the snapshot's current_milestone")
    payload = None if snap is None else snap["line"]["payload"]
    mm = None if payload is None else payload.get("milestones")
    if snap is None:
        reason = "no mission_snapshot line"
    elif "milestones" not in payload:
        reason = "snapshot predates milestones field"
    elif not isinstance(mm, dict):
        reason = "malformed"
    else:
        reason = None
    if reason is not None:
        return {"list": None, "progress": None, "reason": reason, "basis": basis,
                "tile": _stat(None, pf, window, current=None, of=None, complete=None, active=None, planned=None, reason=reason)}
    rows = []
    for mid in sorted(mm, key=_natural):
        m = mm[mid] if isinstance(mm[mid], dict) else {}
        el, why = _milestone_elapsed(m.get("started_ts"), m.get("done_ts"), clock)
        rows.append({"id": mid, "title": m.get("title"), "status": derive.milestone_status(m.get("status")), "assertions_total": derive.as_int(m.get("assertions_total")),
                     "assertions_green": derive.as_int(m.get("assertions_green")), "elapsed_s": el, "elapsed_reason": why,
                     "formula": MILESTONE_ROW_FORMULA, "window": window})
    passed = sum(1 for r in rows if r["status"] == "passed")
    pending = sum(1 for r in rows if r["status"] == "pending")
    withdrawn = sum(1 for r in rows if r["status"] == "withdrawn")
    counted = len(rows) - withdrawn
    cur = snap["line"]["payload"].get("current_milestone")
    progress = _stat(cur, pf, window, current=cur, of=len(rows), passed=passed, active=counted - passed - pending, pending=pending, withdrawn=withdrawn,
                     progress=_ratio(passed, counted), progress_numerator=passed, progress_denominator=counted,
                     complete=passed, planned=pending, reason=None)
    return {"list": rows, "progress": progress, "reason": None, "basis": basis, "tile": progress}


def milestone_tally(events):
    """RELEASE-5 group B (RB-4): milestone id -> {total, green, judged}: the latest snapshot's milestones map, and its
    milestone_tally -- the writer's count of each milestone's judged assertions (green or red) over the same snapshot's
    assertions; judged None where the snapshot carries no such tally (a writer before 1.3.1). Amendment 3 (RB-25): record_alone,
    the writer's count of the milestone's assertions judged on the record alone, counted apart -- None where the snapshot
    carries no such count (a writer before 1.3.2)."""
    snap = derive.latest_snapshot(events)
    tally = derive.snapshot_map(snap, "milestone_tally")
    out = {}
    for mid, m in derive.snapshot_map(snap, "milestones").items():
        if isinstance(m, dict):
            t = tally.get(mid) if isinstance(tally.get(mid), dict) else {}
            out[mid] = {"total": derive.as_int(m.get("assertions_total")), "green": derive.as_int(m.get("assertions_green")),
                        "judged": derive.as_int(t.get("assertions_judged")), "record_alone": derive.as_int(t.get("assertions_record_alone"))}
    return out


def halts_open(events, window):
    t = derive.halt_times(events)
    readings = derive.goal_readings(events)
    goals = [g["goal"] for g in readings if isinstance(g["goal"], dict) and g["goal"].get("read")]
    names = sorted({str(g.get("goal")) for g in goals})
    # RB-16 over RB-17 (builder-side review): where no checkout's snapshot carries the goal reading, the allowlist figure is
    # null and the tile says so, with the command
    lacking = bool(readings) and all(g["goal"] is None for g in readings)
    return _stat(_open_halt_count(events), "count of HALT ids open, the one set the HALT card, the errors and the fleet count "
                                           "(derive.open_halt_ids): over a 1.3.1 snapshot, the HALTs the stop evaluator's own detector "
                                           "reports unanswered when run for the governing goal (the goal the mission's Stop hook runs, "
                                           "its legacy allowlist included), each by its own checkout's newest snapshot, and any raised "
                                           "after that snapshot in a place its rule counts (derive.HALT_PRECEDENCE); over an earlier "
                                           "snapshot, its halts map and the feed's halt_raised lines with no halt_resolved after them -- "
                                           "which cannot tell the HALTs the evaluator does not count apart", window,
                 # amendment 1 (RB-17): beside the open count, the HALTs the governing goal's legacy allowlist answers, and that goal
                 answered_allowlist=None if lacking else sum(1 for v in t.values() if v["state"] == "answered_allowlist"), goals=names,
                 goal_note=("the governing goal the HALT rule was read for is " + derive.not_in_snapshot(events)) if lacking else None)


def mission_kpis(events, stats, window):
    """L-7's four Stats tiles for one mission: three are mission_stats' own values, the fourth is counted here."""
    return {"assertions_green": stats["green"], "partial_manifests": stats["dispatches_partial"], "halts_open": halts_open(events, window),
            "tool_call_failure_rate": stats["tool_call_nonzero_exit_rate"]}


def _first_assertion_day(events):
    for e in events:
        if e["kind"] == "assertion_result" or (e["kind"] == "mission_snapshot" and isinstance(e["line"]["payload"].get("assertions"), dict)
                                               and e["line"]["payload"]["assertions"]):
            t = derive.parse_ts(e["ts"])
            if t is not None:
                return t.date()
    return None


def series(event_lists, clock, window):
    """V-16: the Stats charts' series over one mission (one list) or the fleet (every mission's list); each list in feed
    order. clock is the series' end: the mission's, or the fleet's, last ts."""
    end = derive.parse_ts(clock)
    lists = [evs for evs in event_lists if evs]
    days = [d for d in (_first_assertion_day(evs) for evs in lists) if d is not None]
    # an assertion's status moves only on these two kinds (derive.assertions); the day's replay reads them alone, and a
    # mission's tally is replayed only on a day one of its lines falls on -- on any other day its prefix is unchanged
    status_lines = [derive.of_kind(evs, "mission_snapshot", "assertion_result") for evs in lists]
    moves = [{e["ts"][:10] for e in evs} for evs in status_lines]
    green, rate = {}, {}
    if end is not None and days:
        d = min(days)
        tallies = [None] * len(status_lines)
        while d <= end.date():
            key = d.isoformat()
            g = defined = evaluated = 0
            for i, evs in enumerate(status_lines):
                if tallies[i] is None or key in moves[i]:
                    tallies[i] = _tally(derive.assertions([e for e in evs if e["ts"][:10] <= key]))
                n, gg, rr = tallies[i]
                g, defined, evaluated = g + gg, defined + n, evaluated + gg + rr
            green[key], rate[key] = _ratio(g, defined), _ratio(g, evaluated)
            d += _DAY
    span = ("every UTC day from the first assertion event (an assertion_result, or a mission_snapshot with assertions) to %s, "
            "each day's value as of that day's end, carried forward on days without events" % clock)
    out = {
        "green_daily": _stat(green, "per day: green / all defined, each assertion's latest status as of that day's end (null while none is defined)",
                             window, label="Green", days=len(green), span=span),
        "pass_rate_daily": _stat(rate, "per day: green / (green + red), each assertion's latest status as of that day's end (null while none is evaluated)",
                                 window, label="pass rate of evaluated", days=len(rate), span=span),
    }
    starts = [t for t in (derive.parse_ts(evs[0]["ts"]) for evs in lists) if t is not None]
    start = min(starts) if starts else None
    disp, halt, left_out = {}, {}, 0
    if end is not None and start is not None and start <= end:
        # n is the oldest bucket. It is closed on the left, at the first line, so a span of exactly whole weeks ends in
        # a full first bucket rather than one of zero length; it is partial only when it is shorter than 7 days.
        q, r = divmod(end - start, _WEEK)
        n = int(q) - 1 if q and not r else int(q)
        for k in range(n, -1, -1):
            b_end = end - k * _WEEK
            b_start = start if k == n else b_end - _WEEK
            short = k == n and b_end - start < _WEEK
            disp[_fmt(b_end)] = {"bucket_start": _fmt(b_start), "finalized": 0, "partial": 0, "partial_bucket": short}
            halt[_fmt(b_end)] = {"bucket_start": _fmt(b_start), "raised": 0, "resolved": 0, "partial_bucket": short}

        def bucket(ts):
            t = derive.parse_ts(ts)
            if t is None or t < start:
                return None
            return _fmt(end - min(n, max(0, int((end - t) // _WEEK))) * _WEEK)
        for evs in lists:
            for d in derive.dispatches(evs).values():
                f = d["finalized"]
                if f is None:
                    continue
                b = bucket(f["ts"])
                if b is None:
                    left_out += 1
                    continue
                disp[b]["partial" if derive.is_partial(f) else "finalized"] += 1
            raised = set()
            for e in derive.of_kind(evs, "halt_raised", "halt_resolved"):
                hid = derive._id(e["line"]["payload"]["halt_id"])
                b = bucket(e["ts"])
                if e["kind"] == "halt_raised":
                    raised.add(hid)
                elif hid in raised:
                    raised.discard(hid)
                else:
                    continue
                if b is None:
                    left_out += 1
                    continue
                halt[b]["raised" if e["kind"] == "halt_raised" else "resolved"] += 1
    weeks = ("7-day buckets (bucket_start, bucket_end] ending on %s and stepping back to the first line, %s; the first bucket is [that line, "
             "its bucket_end] and is flagged partial_bucket: true when it is shorter than 7 days" % (clock, "ts" if start is None else _fmt(start)))
    out["dispatches_weekly"] = _stat(disp, "per bucket: the dispatches whose latest dispatch_finalized falls in it, finalized (not partial) and "
                                           "partial (partial true or manifest_state PARTIAL)", window, buckets=len(disp), span=weeks, left_out=left_out)
    out["halts_weekly"] = _stat(halt, "per bucket: raised = halt_raised lines in it; resolved = halt_resolved lines in it that close a raised HALT",
                                window, buckets=len(halt), span=weeks, left_out=left_out)
    return out


def fleet(missions, window, left_out=()):
    """V-17: the Fleet's four KPI tiles. missions: [{mission_id, state, events (feed order), errors (ranked)}]; left_out:
    the ids of the missions whose figures could not be computed, which every fleet figure leaves out."""
    by_state = {}
    for m in missions:
        k = "(no snapshot)" if m["state"] is None else derive._id(m["state"])
        by_state[k] = by_state.get(k, 0) + 1
    in_flight = sum(1 for m in missions if m["state"] is not None and m["state"] not in DONE_STATES)
    errs = [len(m["errors"]) for m in missions]
    blocking = sum(1 for m in missions for h in _open_halts(m["events"]) if errors.halt_blocks(h["line"]["payload"].get("severity")))
    starts = [s for m in missions for s in _open_session_starts(m["events"]).values()]
    hosts = sorted({derive._id(s["line"]["host_id"]) for s in starts})
    open_d = sum(len(_open_dispatches(m["events"])) for m in missions)
    g = defined = red = 0
    for m in missions:
        n, gg, rr = _tally(derive.assertions(m["events"]))
        g, defined, red = g + gg, defined + n, red + rr
    return {
        "missions_in_flight": _stat(in_flight, "missions whose latest mission_snapshot state is neither Complete nor Aborted; of = every mission "
                                               "listed except those in left_out (a mission listed with a fault, its figures not computed, is left "
                                               "out of every fleet figure); by_state = missions per latest snapshot state, over the same missions",
                                    window, of=len(missions), by_state=dict(sorted(by_state.items()))),
        "open_errors": _stat(sum(errs), "the sum of the missions' error counts (the closed error set); missions = missions with at least one error; "
                                        "blocking_halts = open HALTs whose halt_raised severity is critical, high or blocking (an open HALT "
                                        "that is a blocking error; advisory, low or absent is a warning)", window,
                             missions=sum(1 for n in errs if n), blocking_halts=blocking),
        "active_sessions": _stat(len(starts), "open sessions over every mission (session ids whose latest session_start has no session_stop after it); "
                                              "hosts = distinct host_id of those session_start lines; open_dispatches = dispatch_opened with no "
                                              "dispatch_finalized, over every mission", window, hosts=len(hosts), host_ids=hosts, open_dispatches=open_d),
        "assertions_green": _stat(_ratio(g, defined), "the missions' green summed / their assertions all defined summed; red = their red summed; "
                                                      "pending = denominator - numerator - red", window,
                                  numerator=g, denominator=defined, red=red, pending=defined - g - red),
        "left_out": _stat(sorted(left_out), "the missions listed with a fault (their figures could not be computed); every fleet figure "
                                            "above leaves them out", window),
    }


def fleet_stats(missions, fleet_figures, clock, window):
    """V-17: the fleet Stats screen -- L-7's four tiles over every mission, the four series of V-16 over every mission,
    and the slowest milestones across the fleet."""
    calls = captured = nonzero = 0
    for m in missions:
        c, cp, nz = _exit_codes(m["events"])
        calls, captured, nonzero = calls + c, captured + cp, nonzero + nz
    slow = [dict(s, mission_id=m["mission_id"]) for m in missions for s in _segments(m["events"])]
    slow.sort(key=lambda s: (s["elapsed_s"] is None, -(s["elapsed_s"] or 0), s["mission_id"], str(s["milestone"])))
    return {
        "kpis": {
            "assertions_green": fleet_figures["assertions_green"],
            "partial_manifests": _stat(sum(_partial_count(m["events"]) for m in missions),
                                       "over every mission: dispatches whose latest dispatch_finalized has partial true or manifest_state PARTIAL", window),
            "halts_open": _stat(sum(_open_halt_count(m["events"]) for m in missions),
                                "over every mission: its HALTs-open figure (derive.open_halt_ids, the set its HALT card counts)", window),
            "tool_call_failure_rate": _stat(_ratio(nonzero, captured) if captured else NOT_CAPTURED,
                                            "over every mission: tool_call lines with exit_code non-zero / tool_call lines with exit_code captured; "
                                            "\"not captured\" when no exit_code is", window, numerator=nonzero, denominator=captured, tool_calls=calls),
        },
        "series": series([m["events"] for m in missions], clock, window),
        "slowest_milestones": _stat(slow, "every mission's elapsed_per_milestone runs, slowest first (elapsed_s descending, unmeasured last)", window),
    }



# =================================================================================================
# UI-2 S2, GROUP B (the S2 contract B-1..B-11; register rows 501, 498): the figures of the feature roll-up, the validator
# rounds, the HALT card, elapsed per milestone, the verify card and the per-mission Stats face. Every value carries its
# formula and window; a figure the feed cannot give is None ("no data" on the face), never 0.
# =================================================================================================
def feature_rollups(events):
    """feature id (None for unbound assertions) -> {members, rollup} (derive.feature_members, derive.rollup)."""
    return {fid: {"members": ms, "rollup": derive.rollup(ms)} for fid, ms in derive.feature_members(events).items()}


def validator_rounds(events, window):
    """B-4: the mission's round series, the latest round, and each dispatch's series over its assertion_targets."""
    series = derive.round_series(events)
    by_d = {did: derive.round_series(events, set(t)) for did, t in sorted(derive.dispatch_targets(events).items())}
    return _stat(series if series else None, "per round r: the assertions confirmed and refuted in r (" + derive.ROUND_RULE + ")", window,
                 latest=series[-1] if series else None, by_dispatch=by_d,
                 dispatch_rule="a dispatch's series = the mission's restricted to its assertion_targets (validator results name no dispatch)")


def halt_card(events, clock, window):
    """B-6: open, answered (and withdrawn) HALTs; mean and median time to resolve over answered HALTs whose two times are
    known (answered_at - raised_at, seconds, never negative); the answered HALTs whose time could not be read (unknown, never
    a zero); the oldest open HALT's age against the mission clock."""
    t = derive.halt_times(events)
    rows = [dict(v, halt_id=k) for k, v in sorted(t.items())]
    ans = [r for r in rows if r["state"] == "answered"]
    opn = [r for r in rows if r["state"] == "open"]
    spans, unknown = [], []
    for r in ans:
        s = _seconds(r["raised_at"], r["answered_at"]) if (r["raised_at"] and r["answered_at"]) else None
        if s is None or s < 0:
            unknown.append(r["halt_id"])
        else:
            r["ttr_s"] = s
            spans.append(s)
    oldest = None
    for r in opn:
        age = _seconds(r["raised_at"], clock) if (r["raised_at"] and clock) else None
        r["age_s"] = age
        if age is not None and age >= 0 and (oldest is None or age > oldest["age_s"]):
            oldest = {"halt_id": r["halt_id"], "age_s": age, "raised_at": r["raised_at"], "raised_basis": r["raised_basis"]}
    open_unknown = [r["halt_id"] for r in opn if r.get("age_s") is None or r["age_s"] < 0]
    # amendment 1: each checkout's HALTs by its own newest snapshot -- a figure no checkout's snapshot carries reads null, and
    # one that some checkout's snapshot does not carry says so (RB-16)
    snaps = list(derive.checkout_snapshots(events).values())
    lacks = [s for s in snaps if "halt_reading" not in (s["line"].get("payload") or {})]
    goals = derive.goal_readings(events)
    return _stat(len(opn), "HALTs open (" + derive.HALT_PRECEDENCE + ")", window, open=len(opn), answered=len(ans),
                 withdrawn=sum(1 for r in rows if r["state"] == "withdrawn"),
                 # RELEASE-5 group B (RB-8): the HALTs the stop evaluator does not count, counted apart -- never open; RB-16: a
                 # snapshot an earlier writer wrote cannot tell them apart, and says so
                 set_aside=None if (snaps and len(lacks) == len(snaps)) else sum(1 for r in rows if r["state"] == "set_aside"),
                 set_aside_note=("the HALTs the stop evaluator does not count are " + derive.not_in_snapshot(events)) if lacks else None,
                 # amendment 1 (RB-17): the HALTs the governing goal's legacy allowlist answers, counted apart from those a gate
                 # answers; and the goal each checkout's snapshot read (null and a note where a snapshot predates the reading)
                 answered_allowlist=None if (goals and all(g["goal"] is None for g in goals)) else sum(1 for r in rows if r["state"] == "answered_allowlist"),
                 goal_readings=goals,
                 mean_ttr_s=round(sum(spans) / len(spans), 3) if spans else None,
                 median_ttr_s=round(statistics.median(spans), 3) if spans else None, measured=len(spans),
                 unknown=unknown, oldest_open=oldest, open_unknown=open_unknown, clock=clock, against=MISSION_CLOCK,
                 precedence=derive.HALT_PRECEDENCE, halts=rows)


MILESTONE_TIMING = ("elapsed = closed_at - opened_at; for a milestone not closed, " + MISSION_CLOCK + " - opened_at, marked running; "
                    "dispatches = those first seen (dispatch_opened, else the first snapshot naming them) within [opened_at, closed_at "
                    "or the clock]")


def milestone_timing(events, clock, window):
    """B-8: per milestone of the latest snapshot's map, in the milestones' natural order: opened_at, closed_at (derive's
    first-seen rule), elapsed_s, running, and the dispatches first seen within it."""
    snap = derive.latest_snapshot(events)
    mm = derive.snapshot_map(snap, "milestones")
    times, seen = derive.milestone_times(events), derive.dispatch_first_seen(events)
    rows = []
    for mid in sorted(mm, key=_natural):
        m = mm[mid] if isinstance(mm[mid], dict) else {}
        t = times.get(mid) or {"opened_at": None, "opened_basis": None, "closed_at": None, "closed_basis": None}
        st = derive.milestone_status(m.get("status"))
        running = t["opened_at"] is not None and t["closed_at"] is None
        end = t["closed_at"] if t["closed_at"] is not None else (clock if running else None)
        el = _seconds(t["opened_at"], end) if (t["opened_at"] and end) else None
        if el is not None and el < 0:
            el = None
        lo, hi = derive.parse_ts(t["opened_at"]), derive.parse_ts(end)
        ids = sorted(d for d, ts in seen.items() if lo is not None and hi is not None and derive.parse_ts(ts) is not None and lo <= derive.parse_ts(ts) <= hi)
        rows.append(dict(t, id=mid, title=m.get("title"), status=st, elapsed_s=el, running=running,
                         dispatch_count=len(ids) if lo is not None else None, dispatch_ids=ids))
    return _stat(rows if rows else None, MILESTONE_TIMING, window, clock=clock)


def verify_card(events, window):
    """B-10: the latest verify_result's divergences, each listed (path, kind, the two digests' sha8s where both exist), from
    its additive divergence_list; with no such list, its divergences count only, and the list "not carried"."""
    v = derive.latest_verify(events)
    if v is None:
        return _stat(None, "no verify_result line", window, listed=None, count=None, carried=False, verify_verdict=None, evaluator=None, blocking=None)
    d = derive.verify_divergences(v)
    p = v["line"]["payload"]
    # RELEASE-5 group B (RB-7): the verify tool's own verdict in its own word, the stop evaluator's reading of that same run
    # (derive.VERIFY_READING_RULE) beside it, and whether the card blocks
    ev = derive.verify_reading(events)
    extra = {"verify_verdict": p.get("verdict"), "evaluator": ev, "blocking": _verify_blocks(p, ev), "evaluator_rule": derive.VERIFY_READING_RULE,
             "evaluator_note": _evaluator_note(events, ev)}
    if d is None:
        return _stat(p.get("divergences"), "the latest verify_result's divergences count (it carries no divergence_list)", window,
                     listed=None, count=p.get("divergences"), carried=False, verdict=p.get("verdict"), ts=v["ts"], seq=v["seq"], **extra)
    return _stat(len(d["listed"]), "the latest verify_result's divergence_list: kinds " + ", ".join(sorted(derive.DIVERGENCE_KINDS)) +
                 "; kept-equal (a kept file now equal to upstream) is no divergence", window, listed=d["listed"], count=len(d["listed"]),
                 carried=True, unrecognized=d["unrecognized"], kept_equal=d["kept_equal"], verdict=p.get("verdict"), ts=v["ts"], seq=v["seq"], **extra)


def sessions_card(events, window):
    """B-11: sessions running and stopped, subagents finished -- None (no data) when the feed holds no session line."""
    lines = derive.of_kind(events, "session_start", "session_stop", "subagent_stop")
    if not lines:
        return _stat(None, "no session_start, session_stop or subagent_stop line", window, running=None, stopped=None, subagents_finished=None)
    started = {derive._id(e["line"]["payload"]["session_id"]) for e in derive.of_kind(events, "session_start", "session_stop")}
    running = derive.open_sessions(events)
    return _stat(len(running), "running = sessions whose session_start has no session_stop after it; stopped = the other sessions named; "
                 "subagents finished = subagent_stop lines", window, running=len(running), stopped=len(started - set(running)),
                 subagents_finished=sum(len(v) for v in derive.subagents_finished(events).values()))


def dispatches_card(events, window):
    """B-11: dispatches by state -- on the feed (open / finalized, the opened and finalized lines of one dispatch joined on its
    session; RELEASE-5 group B: partial is no state of a dispatch, counted on the manifests apart with their capture gaps) and
    as the artifacts state them (the latest snapshot's dispatch_detail, each word of RB-11); None (no data) where neither is
    carried."""
    disp = derive.dispatches(events)
    feed = None
    manifests = None
    if disp:
        # RELEASE-5 group B (RB-12, RB-13): the opened / finalized pair joined on its session is one dispatch; partial is the
        # manifest's word, never a state of the dispatch -- counted with its capture gaps on the manifests, apart
        fin = [d["finalized"] for d in disp.values() if d["finalized"] is not None]
        feed = {"open": sum(1 for d in disp.values() if d["opened"] is not None and d["finalized"] is None), "finalized": len(fin)}
        mf = derive.manifests(events)
        manifests = {"partial": sum(1 for m in mf if m["partial"]), "capture_gaps": sum(m["capture_gaps_count"] or 0 for m in mf if m["partial"])}
    det = derive.snapshot_map(derive.latest_snapshot(events), "dispatch_detail")
    art = None
    # RB-16: the 1.3.1 dispatch words carry their basis; a snapshot whose entries carry none was written before them
    words_note = ("the dispatch words of 1.3.1 are " + derive.not_in_snapshot(events)) if det and any(isinstance(d, dict) and "basis" not in d for d in det.values()) else None
    if det:
        art = {}
        for d in det.values():
            s = d.get("state") if isinstance(d, dict) else None
            art[str(s)] = art.get(str(s), 0) + 1
    return _stat(None if feed is None and art is None else (feed or art), "the feed's dispatch_opened / dispatch_finalized lines (a finalized line "
                 "whose dispatch_id is an opened line's session_id is that dispatch's); the snapshot's dispatch_detail states; manifests = the "
                 "sealed manifests with partial true and their capture gaps, on their sessions -- no state of a dispatch",
                 window, feed=feed, artifacts=art, manifests=manifests, words_note=words_note)
