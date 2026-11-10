"""The tailer and the ingest (expanded-schemas SS14 "Rules").

Each registered stream is tailed from its persisted position: the byte offset after the last complete line
read, the line count, and the last ingested seq -- so a restart resumes where it stopped, with no re-ingest.
Only complete lines (ending LF) are read; a partial last line waits for its newline. Resume first checks the
file against what was read: its size, a hash of its first line, and a hash of the bytes immediately before
the stored offset (the last TAIL_BYTES of what was ingested). A file that shrank, whose first line changed, or
whose bytes before the offset changed was truncated, replaced, or truncated and regrown past the offset
(between two polls, or while the service was down): what was ingested no longer stands, so that stream is
re-ingested from what the file holds, as a rebuild would read it. A file that is gone empties its stream, as
a rebuild over the same files would.

Every line is validated against the published schema. A line is REJECTED -- counted per stream, with its
reason and its seq (or line number), shown, never silently dropped and never an event -- when it is not
JSON (malformed_json), has no sha256 (missing_sha256), fails the schema (schema_invalid), or repeats a seq
already ingested (duplicate_seq), or -- valid, but beyond what the projection can hold (a seq past SQLite's
64-bit range) -- unprojectable. One line never stops its stream, and one stream never stops the others.
NaN and Infinity are not JSON (RFC 8259) and read as malformed_json. Unknown kinds are kept as events and
counted at query time. Gaps in seq are derived at query time from what was ingested and rejected. Feeds are
opened for reading only.
"""
import hashlib
import json
import os
import sqlite3

from ui import registry as reg
from ui import settings as cfg

_SQLITE_MAX = 2 ** 63 - 1
# the bytes immediately before the stored offset whose hash resume compares (UI-1 S4 C-1): more than any one line. The
# default of the service setting tail_window_bytes (register row 525; settings.py THE TAIL WINDOW states the limit).
TAIL_BYTES = cfg.DEFAULT_TAIL_WINDOW_BYTES


def _sha(b):
    return hashlib.sha256(b).hexdigest()


def canonical(obj):
    """The stored form. A number no double holds (1e400 reads as inf) is refused here, so its line is unprojectable."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def _not_json(token):
    raise ValueError("%s is not JSON" % token)


def _text(v):
    """A snapshot column holds a string or nothing; any other JSON value stays in the payload column only."""
    return v if isinstance(v, str) else None


class Ingestor:
    def __init__(self, settings, validator):
        self.settings = settings
        self.validator = validator

    def poll(self, conn):
        """One pass over the registry's streams. Returns the number of lines read."""
        registry = reg.read_registry(self.settings.registry_path)
        n = 0
        for row in registry.rows:
            try:
                n += self._tail(conn, row)
            except (OSError, sqlite3.Error):  # this stream is retried next pass; the others go on
                conn.rollback()
        return n

    def _state(self, conn, row):
        st = conn.execute("SELECT byte_offset, line_no, last_seq, head_sha256, tail_sha256 FROM streams WHERE stream_key = ?", (row.key,)).fetchone()
        if st is None:
            conn.execute("INSERT INTO streams (stream_key, host_id, checkout_path) VALUES (?, ?, ?)", (row.key, row.host_id, row.checkout_path))
            conn.commit()
            return 0, 0, None, None, None
        return st

    def _reset(self, conn, key):
        for table in ("events", "rejections", "snapshots"):
            conn.execute("DELETE FROM %s WHERE stream_key = ?" % table, (key,))
        conn.execute("UPDATE streams SET byte_offset = 0, line_no = 0, last_seq = NULL, head_sha256 = NULL, tail_sha256 = NULL WHERE stream_key = ?", (key,))
        conn.commit()

    def _tail(self, conn, row):
        offset, line_no, last_seq, head, tail = self._state(conn, row)
        tw = getattr(self.settings, "tail_window_bytes", TAIL_BYTES)
        try:
            size = os.path.getsize(row.feed)
        except FileNotFoundError:
            # ADR-045: a deleted feed -- the projection holds what the file holds, which is nothing
            if line_no:
                self._reset(conn, row.key)
            return 0
        except OSError:
            return 0
        with open(row.feed, "rb") as f:
            before = b""
            if offset > 0:
                first = f.readline()
                if size >= offset:
                    f.seek(offset - min(offset, tw))
                    before = f.read(min(offset, tw))
                if size < offset or _sha(first) != head or _sha(before) != tail:
                    # truncated, replaced, or regrown past the offset: what was ingested no longer stands
                    self._reset(conn, row.key)
                    offset, line_no, last_seq, before = 0, 0, None, b""
                elif size == offset:
                    return 0
            f.seek(offset)
            data = f.read(size - offset)
        end = data.rfind(b"\n")
        if end < 0:
            return 0
        chunk = data[:end + 1]
        lines = chunk.split(b"\n")[:-1]
        for raw in lines:
            line_no += 1
            seq = self._one(conn, row, raw, line_no)
            if seq is not None:
                last_seq = seq
        if offset == 0:
            head = _sha(chunk[:chunk.find(b"\n") + 1])
        conn.execute("UPDATE streams SET byte_offset = ?, line_no = ?, last_seq = ?, head_sha256 = ?, tail_sha256 = ? WHERE stream_key = ?",
                     (offset + len(chunk), line_no, last_seq, head, _sha((before + chunk)[-tw:]), row.key))
        conn.commit()
        return len(lines)

    def _reject(self, conn, row, line_no, seq, reason, detail):
        if seq is not None and abs(seq) > _SQLITE_MAX:
            seq = None  # shown by line number; the column cannot hold it
        conn.execute("INSERT OR REPLACE INTO rejections (stream_key, line_no, seq, reason, detail) VALUES (?, ?, ?, ?, ?)",
                     (row.key, line_no, seq, reason, detail))
        return None

    def _one(self, conn, row, raw, line_no):
        """Ingest one line; returns its seq when it became an event, None when it was rejected."""
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as e:
            return self._reject(conn, row, line_no, None, "malformed_json", "not UTF-8: %s" % e.reason)
        try:
            obj = json.loads(text, parse_constant=_not_json)
        except ValueError as e:
            return self._reject(conn, row, line_no, None, "malformed_json", str(e))
        seq = obj.get("seq") if isinstance(obj, dict) else None
        if isinstance(seq, float) and seq.is_integer():
            seq = int(seq)  # 2.0 is an integer to JSON Schema
        if isinstance(seq, bool) or not isinstance(seq, int):
            seq = None
        if not isinstance(obj, dict):
            return self._reject(conn, row, line_no, None, "schema_invalid", "/: the line is not a JSON object")
        if "sha256" not in obj:
            return self._reject(conn, row, line_no, seq, "missing_sha256", "a line without its source_path@sha256 is rejected (SS14)")
        err = self.validator.first_error(obj)
        if err:
            return self._reject(conn, row, line_no, seq, "schema_invalid", err)
        if seq > _SQLITE_MAX:
            return self._reject(conn, row, line_no, None, "unprojectable", "seq beyond the projection's 64-bit range")
        prior = conn.execute("SELECT line_no FROM events WHERE stream_key = ? AND seq = ?", (row.key, seq)).fetchone()
        if prior is not None:
            return self._reject(conn, row, line_no, seq, "duplicate_seq", "seq %d already ingested from line %d" % (seq, prior[0]))
        try:
            cur = conn.execute("INSERT INTO events (stream_key, seq, line_no, mission_id, kind, ts, commit_sha, line) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                               (row.key, seq, line_no, obj["mission_id"], obj["kind"], obj["ts"], obj["commit"], canonical(obj)))
            if obj["kind"] == "mission_snapshot":
                p = obj["payload"]
                try:
                    conn.execute("INSERT INTO snapshots (stream_key, seq, ts, state, current_milestone, payload) VALUES (?, ?, ?, ?, ?, ?)",
                                 (row.key, seq, obj["ts"], _text(p.get("state")), _text(p.get("current_milestone")), canonical(p)))
                except (sqlite3.Error, OverflowError, TypeError, ValueError):
                    conn.execute("DELETE FROM events WHERE id = ?", (cur.lastrowid,))
                    raise
        except (sqlite3.Error, OverflowError, TypeError, ValueError) as e:
            return self._reject(conn, row, line_no, seq, "unprojectable", "the projection cannot hold this line: %s: %s" % (type(e).__name__, e))
        return seq
