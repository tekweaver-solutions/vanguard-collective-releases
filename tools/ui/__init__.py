"""vanguard ui -- the read-only local projection of the projects' mission-event feeds (LM2-ADR-045).

The service reads the host registry (<home>/projects.yaml), tails each registered checkout's
.mission-runtime/telemetry/events.jsonl into a disposable SQLite projection (<home>/ui.db), and serves
four endpoints, /api/stream and the built dashboard. It owns no truth: delete ui.db and --rebuild.
It never writes a feed or the registry.
"""
