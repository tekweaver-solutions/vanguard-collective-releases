"""The host registry reader: <home>/projects.yaml, in the dialect tools/lam/mission-telemetry.ps1 writes.

A row starts at `- host_id: <uuid>` and continues with two-space-indented `key: value` lines; a value is
'single-quoted' ('' for a quote), null or ~, or a bare token. Rows are never pruned by anyone: a row whose
checkout_path is not a folder is listed with stale: true. A row that does not read (a key line out of shape,
an unterminated quote, host_id not a UUID, no checkout_path, a checkout already registered) is counted and
shown as a registry error with its line number -- never fatal. READ ONLY: the file is opened for reading only.
"""
import hashlib
import os
import re
from dataclasses import dataclass

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
_LINE = re.compile(r"^(- |  )([A-Za-z_][A-Za-z0-9_]*):(?:[ \t]+(.*?))?[ \t]*$")
_QUOTED = re.compile(r"^'((?:[^']|'')*)'(?:[ \t]+#.*)?$")


def feed_path(checkout_path):
    return os.path.join(checkout_path, ".mission-runtime", "telemetry", "events.jsonl")


def stream_key(host_id, checkout_path):
    """The stream identity (host, checkout path) as a short stable key; the same on every rebuild."""
    ident = host_id + "\n" + os.path.normcase(os.path.normpath(checkout_path))
    return hashlib.sha256(ident.encode("utf-8")).hexdigest()[:16]


@dataclass(frozen=True)
class Row:
    line: int
    host_id: str
    checkout_path: str
    mission_id: object
    registered_at: object
    framework_version: object

    @property
    def key(self):
        return stream_key(self.host_id, self.checkout_path)

    @property
    def stale(self):
        return not os.path.isdir(self.checkout_path)

    @property
    def feed(self):
        return feed_path(self.checkout_path)

    def identity(self):
        return {"host_id": self.host_id, "checkout_path": self.checkout_path}


@dataclass(frozen=True)
class Registry:
    path: str
    present: bool
    rows: tuple
    errors: tuple


def _value(raw):
    """(ok, value) for one scalar as the writer spells it."""
    if raw is None or raw == "":
        return True, None
    if raw.startswith("'"):
        m = _QUOTED.match(raw)
        if not m:
            return False, "unterminated or malformed quoted value"
        return True, m.group(1).replace("''", "'")
    v = re.sub(r"[ \t]+#.*$", "", raw).strip()
    if v in ("", "null", "~"):
        return True, None
    return True, v


def _finish(start, fields, problems, seen, rows, errors):
    host_id, path = fields.get("host_id"), fields.get("checkout_path")
    if not isinstance(host_id, str) or not UUID.match(host_id):
        problems.append("host_id is not a lowercase UUID")
    if not isinstance(path, str) or not path:
        problems.append("checkout_path is absent or null")
    elif not os.path.isabs(path):
        problems.append("checkout_path is not absolute")
    if not problems:
        row = Row(start, host_id, path, fields.get("mission_id"), fields.get("registered_at"), fields.get("framework_version"))
        if row.key in seen:
            problems.append("checkout already registered at line %d" % seen[row.key])
        else:
            seen[row.key] = start
            rows.append(row)
            return
    errors.append({"line": start, "reason": "; ".join(problems)})


def read_registry(path):
    if not os.path.isfile(path):
        return Registry(path, False, (), ())
    with open(path, "rb") as f:
        data = f.read()
    rows, errors, seen = [], [], {}
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return Registry(path, True, (), ({"line": 0, "reason": "the registry is not UTF-8"},))
    start, fields, problems = None, None, None
    for n, ln in enumerate(text.split("\n"), 1):
        ln = ln.rstrip("\r")
        if ln.strip() == "" or ln.lstrip().startswith("#"):
            continue
        m = _LINE.match(ln)
        if m and m.group(1) == "- ":
            if start is not None:
                _finish(start, fields, problems, seen, rows, errors)
            start, fields, problems = n, {}, []
        elif start is None:
            errors.append({"line": n, "reason": "a line outside any row"})
            continue
        if not m:
            problems.append("line %d is not a `key: value` line of the row" % n)
            continue
        ok, v = _value(m.group(3))
        if not ok:
            problems.append("line %d: %s" % (n, v))
        elif m.group(2) in fields:
            problems.append("line %d: key %s repeated" % (n, m.group(2)))
        else:
            fields[m.group(2)] = v
    if start is not None:
        _finish(start, fields, problems, seen, rows, errors)
    rows.sort(key=lambda r: (os.path.normcase(r.checkout_path), r.host_id))
    return Registry(path, True, tuple(rows), tuple(errors))
