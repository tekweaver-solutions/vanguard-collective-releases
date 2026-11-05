"""The projection: <home>/ui.db, stdlib sqlite3, no ORM. Disposable -- --rebuild deletes it and the feeds
regenerate it. It holds the raw events, per-stream state, the rejected lines and the snapshot rows derived
from mission_snapshot lines. It holds NO computed statistic: every statistic is computed at query time by
ui.metrics.
"""
import os
import sqlite3
import uuid
from urllib.request import pathname2url

PROJECTION_VERSION = "4"

_DDL = """
CREATE TABLE IF NOT EXISTS projection (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- per-stream state: the tail position (byte offset, lines read), the last ingested seq, and the hashes resume checks
-- the file against: its first line, and the bytes immediately before the offset
CREATE TABLE IF NOT EXISTS streams (
    stream_key    TEXT PRIMARY KEY,
    host_id       TEXT NOT NULL,
    checkout_path TEXT NOT NULL,
    byte_offset   INTEGER NOT NULL DEFAULT 0,
    line_no       INTEGER NOT NULL DEFAULT 0,
    last_seq      INTEGER,
    head_sha256   TEXT,
    tail_sha256   TEXT
);
-- raw events: each accepted line, re-serialised canonically (sorted keys, no whitespace); id is the SSE
-- event id, never reused (AUTOINCREMENT) when a truncated stream's rows are deleted and re-ingested
CREATE TABLE IF NOT EXISTS events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    stream_key TEXT NOT NULL,
    seq        INTEGER NOT NULL,
    line_no    INTEGER NOT NULL,
    mission_id TEXT NOT NULL,
    kind       TEXT NOT NULL,
    ts         TEXT NOT NULL,
    commit_sha TEXT,
    line       TEXT NOT NULL,
    UNIQUE (stream_key, seq)
);
-- rejected lines: kept with their reason, never dropped silently
CREATE TABLE IF NOT EXISTS rejections (
    stream_key TEXT NOT NULL,
    line_no    INTEGER NOT NULL,
    seq        INTEGER,
    reason     TEXT NOT NULL,
    detail     TEXT NOT NULL,
    PRIMARY KEY (stream_key, line_no)
);
-- derived snapshot rows: one per mission_snapshot line
CREATE TABLE IF NOT EXISTS snapshots (
    stream_key        TEXT NOT NULL,
    seq               INTEGER NOT NULL,
    ts                TEXT NOT NULL,
    state             TEXT,
    current_milestone TEXT,
    payload           TEXT NOT NULL,
    PRIMARY KEY (stream_key, seq)
);
"""


def delete(db_path):
    """--rebuild: the projection and its journal files go; the feeds regenerate them."""
    for suffix in ("", "-wal", "-shm", "-journal"):
        p = db_path + suffix
        if os.path.exists(p):
            os.remove(p)


def open_writer(db_path):
    """The ingest connection. A projection of another version is discarded and regenerated."""
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript(_DDL)
    row = conn.execute("SELECT value FROM projection WHERE key = 'version'").fetchone()
    if row is None or row[0] != PROJECTION_VERSION:
        conn.close()
        delete(db_path)
        conn = sqlite3.connect(db_path, check_same_thread=False)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.executescript(_DDL)
        conn.execute("INSERT INTO projection (key, value) VALUES ('version', ?)", (PROJECTION_VERSION,))
        # the SSE id's epoch: random per projection (never a clock), so an id from before a rebuild is known as such
        conn.execute("INSERT INTO projection (key, value) VALUES ('epoch', ?)", (uuid.uuid4().hex[:12],))
        conn.commit()
    return conn


def open_reader(db_path):
    conn = sqlite3.connect("file:" + pathname2url(db_path) + "?mode=ro", uri=True, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn
