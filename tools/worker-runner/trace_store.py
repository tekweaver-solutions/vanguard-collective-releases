"""
trace_store.py -- SQLite-backed trace event store for the worker-runner.

Per kickoff prompt §12.7: schema is OTel-compatible -- exportable to
OTLP on demand by a downstream tool that reads SQLite rows and emits
OTLP `ResourceSpans` protos. The downstream tool is NOT implemented
here; the mapping is documented below.

Per expanded-schemas.md cross-cutting note 3: sensitive content
redaction happens at the trace-store write path, NOT in the Pydantic
schemas. `TraceStore.insert(event, ...)` runs a caller-supplied
redactor over the payload before INSERT. Default redactor is identity
(no-op). The runner provides the actual policy.

Per kickoff prompt §14.3: replayability is the primary read use case.
Mission-scoped iteration in chronological order is the killer query;
served by the composite (mission_id, started_at) index.

----------------------------------------------------------------------
DDL header comment block:
  (a) Idempotency contract -- the DDL constant below is safe to re-run
      on an existing DB; every CREATE uses IF NOT EXISTS. This does
      NOT make schema CHANGES auto-migrating. Bumping `schema_version`
      in the `meta` table REQUIRES an explicit migration function
      (`_migrate_v1_to_v2()` etc.); do not assume new columns or new
      constraints appear via re-running DDL.
  (b) Migration requirement -- when this module's schema version
      changes, add a migration function with discriminator check at
      __init__ time, before any writes. The first migration is the
      template for the rest.
  (c) VACUUM advisory -- after significant row deletes (retention
      pruning, which is post-MVP per cross-cutting note 6), call
      `VACUUM` to reclaim disk space. SQLite does not reclaim
      automatically. Not implemented in step 2; flagged for the
      future retention work.
----------------------------------------------------------------------

OTLP mapping (downstream exporter consumes SQLite rows):
  mission_id              -> trace_id              (one mission = one trace)
  id                      -> span_id
  parent_id               -> parent_span_id
  type + agent_role       -> span name (composed) + attribute
  started_at              -> start_time_unix_nano (parse + convert)
  started_at + duration_ms -> end_time_unix_nano  (computed)
  status                  -> status.code (success -> OK; error/timeout -> ERROR)
  error                   -> status.message
  payload (llm_call)      -> attributes prefixed `llm.*`
  payload (tool_call)     -> attributes prefixed `tool.*`
  payload.input/output    -> events on the span
"""

from __future__ import annotations

import json
import sqlite3
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter

from schemas import TraceEvent, TraceEventAdapter, TraceEventBase

# ----- DDL -----
#
# Note on PRAGMA inside executescript(): `PRAGMA journal_mode = WAL` works
# via executescript() on the bundled sqlite3 in Python 3.12+. Older or
# alternative SQLite builds may require the PRAGMA executed via `.execute()`
# separately (the script-vs-statement boundary handling differs).

DDL: str = """
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
INSERT OR IGNORE INTO meta (key, value) VALUES ('schema_version', '1');

CREATE TABLE IF NOT EXISTS trace_events (
    id          TEXT PRIMARY KEY NOT NULL,
    parent_id   TEXT,
    mission_id  TEXT NOT NULL,
    agent_id    TEXT NOT NULL,
    agent_role  TEXT NOT NULL,
    type        TEXT NOT NULL,
    started_at  TEXT NOT NULL,
    duration_ms INTEGER NOT NULL,
    status      TEXT NOT NULL,
    error       TEXT,
    payload     TEXT NOT NULL,
    inserted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    CHECK ((status = 'success' AND error IS NULL)
           OR (status != 'success' AND error IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_te_mission_id      ON trace_events(mission_id);
CREATE INDEX IF NOT EXISTS idx_te_parent_id       ON trace_events(parent_id);
CREATE INDEX IF NOT EXISTS idx_te_started_at      ON trace_events(started_at);
CREATE INDEX IF NOT EXISTS idx_te_type            ON trace_events(type);
CREATE INDEX IF NOT EXISTS idx_te_mission_started ON trace_events(mission_id, started_at);
CREATE INDEX IF NOT EXISTS idx_te_errors
    ON trace_events(mission_id)
    WHERE status != 'success';

CREATE INDEX IF NOT EXISTS idx_te_prompt_version
    ON trace_events(json_extract(payload, '$.prompt_version'))
    WHERE type = 'llm_call';

CREATE INDEX IF NOT EXISTS idx_te_capability_tag
    ON trace_events(json_extract(payload, '$.capability_tag'))
    WHERE type = 'tool_call';
"""


# ----- Constants -----

_BASE_FIELDS: frozenset[str] = frozenset(
    {
        "id",
        "parent_id",
        "mission_id",
        "agent_id",
        "agent_role",
        "type",
        "started_at",
        "duration_ms",
        "status",
        "error",
    }
)

_ADAPTER: TypeAdapter[TraceEvent] = TraceEventAdapter

Redactor = Callable[[dict[str, Any]], dict[str, Any]]


def _identity_redactor(payload: dict[str, Any]) -> dict[str, Any]:
    return payload


# ----- TraceStore -----

class TraceStore:
    """
    Wraps the SQLite trace database. Single-mission-scoped instance.

    Use as a context manager:

        with TraceStore(Path('.mission-runtime/traces.sqlite')) as store:
            store.insert(event)
            for evt in store.mission_events(mission_id):
                ...

    Threading: this class wraps a single sqlite3 connection; not thread-
    safe. For concurrent writes from multiple worker subprocesses, hold
    one TraceStore per process. The DDL enables WAL journal mode so
    multiple processes can write to the same file safely.
    """

    def __init__(
        self,
        db_path: Path,
        *,
        redactor: Redactor = _identity_redactor,
    ) -> None:
        self._db_path = db_path
        self._redactor = redactor
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path))
        self._conn.row_factory = sqlite3.Row
        self._conn.executescript(DDL)
        self._conn.commit()

    # --- Writes ---

    def insert(self, event: TraceEventBase) -> None:
        """
        Insert one event. Validates via Pydantic (the caller already did this
        by virtue of having a TraceEventBase-subclass instance); applies the
        redactor to the payload portion only; runs INSERT OR ABORT.

        Raises sqlite3.IntegrityError on PK collision or CHECK violation.
        The CHECK constraint is belt-and-braces against direct-SQL bypass --
        Pydantic's _validate_error_consistency on TraceEventBase already
        enforces the same invariant.
        """
        full = event.model_dump(mode="json")
        payload = {k: v for k, v in full.items() if k not in _BASE_FIELDS}
        payload = self._redactor(payload)

        self._conn.execute(
            """
            INSERT OR ABORT INTO trace_events
                (id, parent_id, mission_id, agent_id, agent_role,
                 type, started_at, duration_ms, status, error, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                full["id"],
                full.get("parent_id"),
                full["mission_id"],
                full["agent_id"],
                full["agent_role"],
                full["type"],
                full["started_at"],
                full["duration_ms"],
                full["status"],
                full.get("error"),
                json.dumps(payload),
            ),
        )
        self._conn.commit()

    # --- Reads (all return iterators; never materialize entire history) ---

    def get(self, event_id: str) -> TraceEvent:
        """Fetch one event by id. Raises KeyError if not found."""
        cur = self._conn.execute(
            "SELECT * FROM trace_events WHERE id = ?", (event_id,)
        )
        row = cur.fetchone()
        if row is None:
            raise KeyError(event_id)
        return self._row_to_event(row)

    def mission_events(self, mission_id: str) -> Iterator[TraceEvent]:
        """All events for a mission, in chronological order. Uses idx_te_mission_started."""
        cur = self._conn.execute(
            """
            SELECT * FROM trace_events
            WHERE mission_id = ?
            ORDER BY started_at ASC
            """,
            (mission_id,),
        )
        for row in cur:
            yield self._row_to_event(row)

    def children_of(self, parent_id: str) -> Iterator[TraceEvent]:
        """Direct children of an event. Tree-traversal building block."""
        cur = self._conn.execute(
            "SELECT * FROM trace_events WHERE parent_id = ? ORDER BY started_at ASC",
            (parent_id,),
        )
        for row in cur:
            yield self._row_to_event(row)

    def errors_in(self, mission_id: str) -> Iterator[TraceEvent]:
        """Non-success events for a mission. Uses idx_te_errors partial index."""
        cur = self._conn.execute(
            """
            SELECT * FROM trace_events
            WHERE mission_id = ? AND status != 'success'
            ORDER BY started_at ASC
            """,
            (mission_id,),
        )
        for row in cur:
            yield self._row_to_event(row)

    def llm_calls_by_prompt_version(
        self, prompt_version: str
    ) -> Iterator[TraceEvent]:
        """Mine LLM calls by prompt version; closes the prompt-iteration loop (note 4)."""
        cur = self._conn.execute(
            """
            SELECT * FROM trace_events
            WHERE type = 'llm_call'
              AND json_extract(payload, '$.prompt_version') = ?
            ORDER BY started_at ASC
            """,
            (prompt_version,),
        )
        for row in cur:
            yield self._row_to_event(row)

    def denied_tool_attempts(self, mission_id: str) -> Iterator[TraceEvent]:
        """Mine denied tool calls; surfaces capabilities workers want but don't have."""
        cur = self._conn.execute(
            """
            SELECT * FROM trace_events
            WHERE mission_id = ?
              AND type = 'tool_call'
              AND json_extract(payload, '$.gateway_decision') = 'denied'
            ORDER BY started_at ASC
            """,
            (mission_id,),
        )
        for row in cur:
            yield self._row_to_event(row)

    def count(self, mission_id: str) -> int:
        """Total event count for a mission; cheap query for the mission-watch
        TUI (see kickoff prompt §"Mission Control UI" -- TUI is a future deliverable)."""
        cur = self._conn.execute(
            "SELECT COUNT(*) FROM trace_events WHERE mission_id = ?",
            (mission_id,),
        )
        return int(cur.fetchone()[0])

    # --- Lifecycle ---

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> "TraceStore":
        return self

    def __exit__(self, exc_type: object, exc_val: object, exc_tb: object) -> None:
        self.close()

    # --- Internal ---

    def _row_to_event(self, row: sqlite3.Row) -> TraceEvent:
        """Reconstruct a discriminated-union TraceEvent from a SQLite row."""
        d = dict(row)
        payload = json.loads(d.pop("payload"))
        d.pop("inserted_at", None)  # bookkeeping; not part of the §9 schema
        # Merge: base fields stay; payload's type-specific fields layer on top.
        # §9 base/payload field names are disjoint by design; the assertion
        # catches the regression at test-run time if a future §9 revision
        # introduces a colliding field name.
        overlap = _BASE_FIELDS & payload.keys()
        assert not overlap, f"Payload field collision with base: {overlap}"
        d.update(payload)
        return _ADAPTER.validate_python(d)
