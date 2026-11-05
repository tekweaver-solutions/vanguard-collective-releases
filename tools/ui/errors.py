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
    for hid, h in sorted(derive.halts(events).items()):
        if h["raised"] is not None and h["resolved"] is None:
            sev = h["raised"]["line"]["payload"].get("severity")
            out.append(_error("open_halt", h["raised"], "HALT %s (severity %s) raised, not resolved" % (hid, sev), identity,
                              HALT_SEVERITY.get(halt_word(sev), HALT_WARNING)))
    for did, d in sorted(derive.dispatches(events).items()):
        f = d["finalized"]
        if f is not None and derive.is_partial(f):
            out.append(_error("partial_manifest", f, "dispatch %s finalized with manifest_state %s" % (did, f["line"]["payload"].get("manifest_state")), identity))
    v = derive.latest_verify(events)
    if v is not None:
        p = v["line"]["payload"]
        div = derive.as_int(p.get("divergences"))
        if div is not None and div > 0:
            out.append(_error("testimony_conflict", v, "the last mission verify (verdict %s) found %d divergence(s) between testimony and the runner's anchors" % (p.get("verdict"), div), identity))
        elif p.get("verdict") != "PASS":
            out.append(_error("failed_verify", v, "the last mission verify's verdict is %s" % p.get("verdict"), identity))
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
