"""The four endpoints' bodies, assembled from the registry (read live) and the projection.

Every body carries as_of: per stream, the {seq, commit, ts} of its highest ingested line -- the feed's own
values, so a body for a feed that has not moved is byte-identical, and a rebuilt projection answers
byte-identically. No value in a body comes from this host's clock.
"""
import json
import os

from ui import derive, errors, metrics, registry as reg


class Model:
    """One reading of the registry and the projection, for one request."""

    def __init__(self, conn, settings, known_kinds):
        self.settings = settings
        self.registry = reg.read_registry(settings.registry_path)
        self.streams = []
        for row in self.registry.rows:
            rows = conn.execute("SELECT seq, ts, kind, commit_sha, mission_id, line FROM events WHERE stream_key = ? ORDER BY seq", (row.key,)).fetchall()
            rej = [{"line": r["line_no"], "seq": r["seq"], "reason": r["reason"], "detail": r["detail"]}
                   for r in conn.execute("SELECT line_no, seq, reason, detail FROM rejections WHERE stream_key = ? ORDER BY line_no", (row.key,))]
            path = os.path.normcase(row.checkout_path)
            evs = [{"key": row.key, "path": path, "seq": r["seq"], "ts": r["ts"], "kind": r["kind"], "line": json.loads(r["line"])} for r in rows]
            last = rows[-1] if rows else None
            self.streams.append({
                "row": row, "key": row.key, "identity": row.identity(), "events": evs, "rejections": rej,
                "mission_id": last["mission_id"] if last else row.mission_id,
                "as_of": {"stream": row.identity(), "seq": last["seq"] if last else None,
                          "commit": last["commit_sha"] if last else None, "ts": last["ts"] if last else None},
                "counts": metrics.stream_counts([e["seq"] for e in evs], rej, [e["kind"] for e in evs], known_kinds),
            })
        self.missions = {}
        for s in self.streams:
            if s["mission_id"] is not None:
                self.missions.setdefault(s["mission_id"], []).append(s)
        self._ordered = {}

    def as_of(self, streams=None):
        return [s["as_of"] for s in (self.streams if streams is None else streams)]

    def events(self, mid):
        """The mission's events from all its streams, in feed order (derive.ordered), read once per request."""
        if mid not in self._ordered:
            self._ordered[mid] = derive.ordered([e for s in self.missions[mid] for e in s["events"]])
        return self._ordered[mid]

    def fleet_clock(self):
        """The fleet's last ts (ui.metrics.FLEET_CLOCK); a mission whose feed cannot be read is left out."""
        clocks = []
        for mid in self.missions:
            try:
                clocks.append(metrics.mission_clock(self.events(mid)))
            except Exception:
                pass
        return metrics.fleet_clock(clocks)


def _stream_entry(s):
    row = s["row"]
    c = s["counts"]
    return {"host_id": row.host_id, "checkout_path": row.checkout_path, "stream_key": row.key, "stale": row.stale,
            "feed_present": os.path.isfile(row.feed), "registered_mission_id": row.mission_id, "registry_line": row.line,
            "earliest_seq": c["earliest_seq"], "last_seq": c["last_seq"]}


def _window(streams):
    parts = ["%s seq %s..%s" % (s["row"].checkout_path, s["counts"]["earliest_seq"], s["counts"]["last_seq"])
             for s in streams if s["counts"]["last_seq"] is not None]
    return "every ingested line of the mission's streams: " + ("; ".join(parts) if parts else "(none yet)")


def _fleet_window(model):
    parts = ["%s %s seq %s..%s" % (s["mission_id"], s["row"].checkout_path, s["counts"]["earliest_seq"], s["counts"]["last_seq"])
             for s in model.streams if s["mission_id"] is not None and s["counts"]["last_seq"] is not None]
    return "every ingested line of every mission's streams: " + ("; ".join(parts) if parts else "(none yet)")


def _summary(model, mid, streams):
    evs = model.events(mid)
    snap = derive.latest_snapshot(evs)
    errs = errors.mission_errors(evs, streams, model.settings.ahead_days)
    totals = metrics.stream_totals([s["counts"] for s in streams])
    classes = []
    for e in errs:
        if e["class"] not in classes:
            classes.append(e["class"])
    return {
        "mission_id": mid,
        "streams": [_stream_entry(s) for s in streams],
        "state": snap["line"]["payload"]["state"] if snap else None,
        "current_milestone": snap["line"]["payload"]["current_milestone"] if snap else None,
        "snapshot": {"stream": model_identity(streams, snap), "seq": snap["seq"], "ts": snap["ts"]} if snap else None,
        "last_activity_ts": evs[-1]["ts"] if evs else None,
        "counts": snap["line"]["payload"]["counts"] if snap else None,
        "feed": totals,
        "errors": {"count": len(errs), "classes": classes},
    }, evs, errs


def model_identity(streams, e):
    for s in streams:
        if s["key"] == e["key"]:
            return s["identity"]
    return None


CARD_FIELDS = ("assertions", "top_error", "last_verify", "milestone_progress", "open", "last_activity")


def _card(model, mid, streams, evs, errs, fclock, fw):
    """V-18's per-mission figures on /api/missions (and the card's milestone progress, open counts and last activity
    age), each computed in ui.metrics. ONE CLOCK PER CARD (F5, UI-1 S4 C-5): every age on the card -- last activity,
    top error, last verify -- is against the fleet's clock, so its window is the fleet's and names that clock; the
    mission's own clock stays on /api/missions/{id}."""
    w, clock = _window(streams), metrics.mission_clock(evs)
    cw = metrics.clock_window(fw, fclock)
    return {"assertions": metrics.assertion_figure(evs, w), "top_error": metrics.top_error(errs, fclock, cw, against=metrics.FLEET_CLOCK),
            "last_verify": metrics.last_verify(evs, fclock, cw, against=metrics.FLEET_CLOCK), "milestone_progress": metrics.milestones(evs, clock, w)["tile"],
            "open": metrics.open_figure(evs, w), "last_activity": metrics.last_activity(evs, fclock, cw)}


def _fault(e):
    return "%s: %s" % (type(e).__name__, e)


def missions(model):
    out, fleet_in, left_out = [], [], []
    fclock, fw = model.fleet_clock(), _fleet_window(model)
    for mid in sorted(model.missions):
        try:
            summary, evs, errs = _summary(model, mid, model.missions[mid])
        except Exception as e:  # one mission's feed never takes the fleet down: it is listed with the fault
            streams = model.missions[mid]
            entry = {"mission_id": mid, "streams": [_stream_entry(s) for s in streams], "state": None, "current_milestone": None,
                     "snapshot": None, "last_activity_ts": None, "counts": None,
                     "feed": metrics.stream_totals([s["counts"] for s in streams]),
                     "errors": {"count": 0, "classes": []}, "fault": _fault(e)}
            entry.update({k: None for k in CARD_FIELDS})
            out.append(entry)
            left_out.append(mid)
            continue
        try:  # the added figures never mask the fields the summary already holds
            summary.update(_card(model, mid, model.missions[mid], evs, errs, fclock, fw))
            fleet_in.append({"mission_id": mid, "state": summary["state"], "events": evs, "errors": errs})
        except Exception as e:
            summary.update({k: None for k in CARD_FIELDS})
            summary["card_fault"] = _fault(e)
            left_out.append(mid)
        out.append(summary)
    out.sort(key=lambda m: (-m["errors"]["count"], m["last_activity_ts"] or "", m["mission_id"]))
    reg_ = model.registry
    try:
        fleet = metrics.fleet(fleet_in, fw, left_out)
        fleet_stats = metrics.fleet_stats(fleet_in, fleet, fclock, fw)
    except Exception as e:  # the fleet figures never take the mission list down
        fleet = fleet_stats = {"fault": _fault(e)}
    return {
        "missions": out,
        "registry": {
            "path": reg_.path, "present": reg_.present, "rows": len(reg_.rows),
            "stale": [dict(_stream_entry(s), mission_id=s["mission_id"]) for s in model.streams if s["row"].stale],
            "registry_errors": list(reg_.errors), "registry_error_count": len(reg_.errors),
            "unassigned_streams": [_stream_entry(s) for s in model.streams if s["mission_id"] is None],
        },
        "settings": {"ahead_days": model.settings.ahead_days},
        "as_of": model.as_of(),
        "fleet": fleet,
        "fleet_stats": fleet_stats,
    }


def mission(model, mid):
    streams = model.missions[mid]
    summary, evs, errs = _summary(model, mid, streams)
    st = derive.assertions(evs)
    snap = derive.latest_snapshot(evs)
    feats = dict((snap["line"]["payload"].get("features") or {}) if snap else {})
    fids = sorted(set(feats) | {a["feature"] for a in st.values() if a["feature"] is not None})
    features = []
    for fid in fids + [None]:
        members = [{"assertion_id": aid, "status": a["status"], "source": a["event"]["line"]["source_path"] + "@" + a["event"]["line"]["sha256"]}
                   for aid, a in sorted(st.items()) if a["feature"] == fid]
        if fid is None and not members:
            continue
        features.append({"feature_id": fid, "status": feats.get(fid) if fid is not None else None, "assertions": members})
    disp = derive.dispatches(evs)
    open_d = sorted(d for d, v in disp.items() if v["opened"] is not None and v["finalized"] is None)
    sess = derive.open_sessions(evs)
    v = derive.latest_verify(evs)
    last_verify = None
    if v is not None:
        p = v["line"]["payload"]
        last_verify = {"verdict": p["verdict"], "scope": {"arms_run": p["arms_run"], "against": p["against"]},
                       "divergences": p["divergences"], "ts": v["ts"], "seq": v["seq"], "stream": model_identity(streams, v),
                       "source": v["line"]["source_path"] + "@" + v["line"]["sha256"]}
    spec = [{"from_version": e["line"]["payload"]["from_version"], "to_version": e["line"]["payload"]["to_version"],
             "amendment_id": e["line"]["payload"]["amendment_id"], "ts": e["ts"], "seq": e["seq"],
             "stream": model_identity(streams, e), "source": e["line"]["source_path"] + "@" + e["line"]["sha256"]}
            for e in derive.of_kind(evs, "spec_bumped")]
    ingest = []
    for s in streams:
        c = s["counts"]
        ingest.append({"stream": s["identity"], "events": c["events"], "rejected": c["rejected"],
                       "rejected_by_reason": c["rejected_by_reason"], "rejections": s["rejections"],
                       "gaps": c["gaps"], "earliest_seq": c["earliest_seq"], "last_seq": c["last_seq"],
                       "unknown_kinds": c["unknown_kinds"]})
    body = {
        "mission_id": mid,
        "streams": summary["streams"],
        "header": {
            "state": summary["state"],
            "milestone": summary["current_milestone"],
            "open_sessions": {"count": len(sess), "ids": sess},
            "open_dispatches": {"count": len(open_d), "ids": open_d,
                                "snapshot_count": (summary["counts"] or {}).get("open_dispatches")},
            "last_verify": last_verify,
        },
        "last_activity_ts": summary["last_activity_ts"],
        "counts": summary["counts"],
        "features": features,
        "spec_timeline": spec,
        "errors": errs,
        "ingest": ingest,
        "unknown_kinds": [{"stream": s["identity"], "kinds": s["counts"]["unknown_kinds"]} for s in streams if s["counts"]["unknown_kinds"]],
        "as_of": model.as_of(streams),
    }
    try:  # the added fields never take the existing ones down
        body.update(_project(model, mid, streams, evs, errs))
    except Exception as e:
        body["project_fault"] = _fault(e)
    return body


def _project(model, mid, streams, evs, errs):
    """UI-1 S2-AM1's additions to /api/missions/{id}: the five header tiles (V-18), the milestones (V-20), the live
    activity (V-19) and the errors' ages, each computed in ui.metrics -- from this mission's streams alone, so a body
    whose streams have not moved does not move (the fleet-relative last-activity age is the card's, on /api/missions)."""
    w, clock = _window(streams), metrics.mission_clock(evs)
    ms = metrics.milestones(evs, clock, w)
    return {
        "tiles": {"milestone_progress": ms["tile"], "assertions": metrics.assertion_figure(evs, w), "spec_version": metrics.spec_version(evs, clock, w),
                  "last_verify": metrics.last_verify(evs, clock, w),
                  "last_activity": metrics.last_activity(evs, clock, w, against=metrics.MISSION_CLOCK)},
        "milestones": ms["list"],
        "milestone_progress": ms["progress"],
        "milestones_reason": ms["reason"],
        "milestones_basis": ms["basis"],
        "live": metrics.live(evs, clock, w),
        "error_ages": metrics.error_ages(errs, clock, w),
    }


def mission_events(model, mid, since_seq, limit, kind, stream):
    streams = [s for s in model.missions[mid] if stream is None or s["key"] == stream]
    rows = sorted((e for s in streams for e in s["events"] if e["seq"] > since_seq and (kind is None or e["kind"] == kind)),
                  key=lambda e: (e["seq"], e["path"]))
    page = rows[:limit]
    while page and len(page) < len(rows) and rows[len(page)]["seq"] == page[-1]["seq"]:
        page.append(rows[len(page)])
    ident = {s["key"]: s["identity"] for s in streams}
    return {
        "mission_id": mid, "since_seq": since_seq, "limit": limit, "kind": kind, "stream": stream,
        "events": [{"stream": ident[e["key"]], "seq": e["seq"], "line": e["line"]} for e in page],
        "next_since_seq": page[-1]["seq"] if page else since_seq,
        "more": len(page) < len(rows),
        "as_of": model.as_of(model.missions[mid]),
    }


def mission_stats(model, mid):
    streams = model.missions[mid]
    evs = model.events(mid)
    w = _window(streams)
    stats = metrics.mission_stats(evs, w)
    body = {"mission_id": mid, "stats": stats, "as_of": model.as_of(streams)}
    try:  # the added fields never take the existing ones down
        body.update({"series": metrics.series([evs], metrics.mission_clock(evs), w), "kpis": metrics.mission_kpis(evs, stats, w)})
    except Exception as e:
        body["stats_fault"] = _fault(e)
    return body
