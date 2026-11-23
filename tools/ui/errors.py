"""The error set (ADR-045), CLOSED at seven classes: open HALT, PARTIAL manifest, testimony conflict, failed
verify, expired gate, refuted assertion, main ahead of origin beyond N days. Nothing else is an error.
Each error names the artifact it derives from as source_path@sha256 -- the line's own fields.

An open HALT blocks (critical) only when the HALT's own severity is critical, high or blocking; an advisory, low or
absent severity -- or any other word -- makes it a warning (UI-1 S4 C-3): HALT_SEVERITY below.
"""
from datetime import timedelta

from ui import derive

# class -> (severity, rank); ranked by rank, then by this order, then by the feed's ts.
CLASSES = (
    ("open_halt", "critical", 1, "open HALT"),
    ("testimony_conflict", "critical", 1, "testimony conflict"),
    ("failed_verify", "high", 2, "failed verify"),
    ("refuted_assertion", "high", 2, "refuted assertion"),
    ("partial_manifest", "medium", 3, "PARTIAL manifest"),
    ("expired_gate", "medium", 3, "expired gate"),
    ("main_ahead_of_origin", "low", 4, "main ahead of origin"),
)
_BY = {c[0]: (n, c) for n, c in enumerate(CLASSES)}
# an open HALT's (severity, rank) by the HALT's own severity: critical, high and blocking block (critical and high in
# the set's words, blocking as critical); low warns as low; advisory, absent or any other word warns as medium
HALT_SEVERITY = {"critical": ("critical", 1), "blocking": ("critical", 1), "high": ("high", 2), "low": ("low", 4)}
HALT_WARNING = ("medium", 3)
BLOCKING_HALT = ("critical", "high", "blocking")


def halt_word(sev):
    """A HALT's severity as written, compared in lower case; None when it is absent or not a string."""
    return sev.strip().lower() if isinstance(sev, str) else None


def halt_blocks(sev):
    """True when an open HALT of this severity is a blocking error."""
    return halt_word(sev) in BLOCKING_HALT


def _error(cls, e, detail, identity, severity=None):
    line = e["line"]
    _, sev, rank, title = _BY[cls][1]
    if severity is not None:
        sev, rank = severity
    return {"class": cls, "severity": sev, "rank": rank, "title": title, "detail": detail,
            "stream": identity[e["key"]], "seq": e["seq"], "ts": e["ts"], "kind": e["kind"],
            "source_path": line["source_path"], "sha256": line["sha256"],
            "source": line["source_path"] + "@" + line["sha256"]}


def mission_errors(events, streams, ahead_days):
    """events: the mission's events in feed order; streams: [{key, identity, events}] (each stream's own,
    in seq order). Returns the errors, ranked."""
    identity = {s["key"]: s["identity"] for s in streams}
    out = []
    # RELEASE-5 group B (RB-8, ruling (m); validator round 1): the open set every figure counts -- over a 1.3.1 snapshot the
    # stop evaluator's own reading
    opened = derive.open_halt_ids(events)
    hs = derive.halts(events)
    # validator round 1 (RB-8): the record of an open HALT no hook raised a line for is the snapshot of the checkout that holds
    # it -- never another checkout's
    holders, snaps = derive.halt_holders(events), derive.checkout_snapshots(events)
    for hid in sorted(opened):
        snap = snaps.get(holders.get(hid)) or derive.latest_snapshot(events)
        h = hs.get(hid) or {}
        if h.get("raised") is not None:
            sev = h["raised"]["line"]["payload"].get("severity")
            out.append(_error("open_halt", h["raised"], "HALT %s (severity %s) raised, not resolved" % (hid, sev), identity,
                              HALT_SEVERITY.get(halt_word(sev), HALT_WARNING)))
        elif snap is not None:
            # validator round 2: an open HALT no hook raised a line for (the hook raises one for HALT-*.md only) -- the snapshot
            # that reads it open is the record; its severity is not recorded, so it is a warning (HALT_SEVERITY's absent word)
            out.append(_error("open_halt", snap, "HALT %s (severity not recorded: no halt_raised line names it; the newest snapshot "
                                                 "reads it open) not resolved" % hid, identity, HALT_SEVERITY.get(halt_word(None), HALT_WARNING)))
    for did, d in sorted(derive.dispatches(events).items()):
        f = d["finalized"]
        if f is not None and derive.is_partial(f):
            # RELEASE-5 group B (RB-13): and the session whose manifest it is, with its capture gaps (the hooks' count)
            fp = f["line"]["payload"]
            gaps = derive.as_int(fp.get("capture_gaps_count"))
            out.append(_error("partial_manifest", f, "dispatch %s finalized with %s -- the manifest of session %s, %s" % (
                did, ", ".join(derive.partial_fields(f)), derive._id(fp.get("dispatch_id")),
                "capture gaps not recorded" if gaps is None else "%d capture gap%s" % (gaps, "" if gaps == 1 else "s")), identity))
    # UI-3 amendment 1 (UC-28, ruling (n)): the newest MISSION verify -- the one "Last verify" shows; an installer check, older or
    # newer, never stands in for it
    v = derive.latest_mission_verify(events)
    if v is not None:
        p = v["line"]["payload"]
        div = derive.as_int(p.get("divergences"))
        # UI-3 (UC-12, register row 602): a verify the stop evaluator's reading of that same run admits (admits true, so the
        # card's blocking is false) is no error -- in no list and no count; the verify cards show the evaluator's reading. A
        # verify with no admitting reading stays an error exactly as RELEASE-5 group B (RB-7) made it.
        ev = derive.verify_reading(events, v)
        adm = ev is not None and ev["admits"] and p.get("verdict") != "PASS"
        if not adm and div is not None and div > 0:
            out.append(_error("testimony_conflict", v, "the last mission verify (verdict %s) found %d divergence(s) between testimony and the runner's anchors" % (p.get("verdict"), div),
                              identity))
        elif not adm and p.get("verdict") != "PASS":
            out.append(_error("failed_verify", v, "the last mission verify's verdict is %s" % p.get("verdict"), identity))
    # UI-3 amendment 1 (UC-29): the installer's newest check, with differences, is an error of the same class in its own words,
    # listed apart from the mission verify; an installer PASS with none lists nothing
    ic = derive.latest_installer_check(events)
    if ic is not None:
        p = ic["line"]["payload"]
        div = derive.as_int(p.get("divergences"))
        what = "the installer's check of the framework files against %s (verdict %s)" % (p.get("against") or "framework.lock", p.get("verdict"))
        if div is not None and div > 0:
            out.append(_error("testimony_conflict", ic, what + " found %d divergence(s) from the lock" % div, identity))
        elif p.get("verdict") != "PASS":
            out.append(_error("failed_verify", ic, what + " did not pass", identity))
    for gid, g in sorted(derive.gates(events).items()):
        if g["kind"] == "gate_expired":
            out.append(_error("expired_gate", g, "gate %s (%s) expired at %s" % (gid, g["line"]["payload"].get("kind"), g["line"]["payload"].get("expires_at")), identity))
    for aid, a in sorted(derive.assertions(events).items()):
        if a["status"] == "red":
            out.append(_error("refuted_assertion", a["event"], "assertion %s (feature %s) is red" % (aid, a["feature"]), identity))
    for s in streams:
        latest, start = derive.main_tip_run(s["events"])
        if start is None or not s["events"]:
            continue
        end = s["events"][-1]
        t0, t1 = derive.parse_ts(start["ts"]), derive.parse_ts(end["ts"])
        if t0 is None or t1 is None:  # a ts naming no real instant measures nothing
            continue
        if t1 - t0 > timedelta(days=ahead_days):
            out.append(_error("main_ahead_of_origin", latest,
                              "main ahead of origin by %d since %s, still at the stream's last line %s: beyond %d days"
                              % (derive.as_int(latest["line"]["payload"]["ahead"]), start["ts"], end["ts"], ahead_days), identity))
    out.sort(key=lambda x: (x["rank"], _BY[x["class"]][0], x["ts"], x["stream"]["checkout_path"], x["seq"]))
    return out
