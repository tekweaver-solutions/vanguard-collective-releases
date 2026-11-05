"""The HTTP surface: the four endpoints (the v2 boundary), /api/stream (SSE), and the built dashboard.

Routes: /api/missions, /api/missions/{id}, /api/missions/{id}/events, /api/missions/{id}/stats, /api/stream,
and ONE non-/api route, the SPA path, which serves dist/ when present and a plain 404 when absent. No docs
or schema routes. Bodies are JSON, compact, keys in assembly order; no body carries a clock value.

Every request is answered only when its Host names this machine's loopback (127.0.0.1, localhost or [::1], with or
without a port); any other Host -- a page that rebinds its own name to 127.0.0.1 -- gets 421 and no body, from the API
and the SPA route alike (UI-1 S4 C-2). The bind address is not changed by this.
"""
import asyncio
import contextlib
import json
import os
import re
import threading

from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, PlainTextResponse, Response, StreamingResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from ui import settings as cfg, store, views
from ui.ingest import Ingestor
from ui.schema import Validator


LOOPBACK_HOST = re.compile(r"(127\.0\.0\.1|localhost|\[::1\])(:[0-9]{1,5})?", re.IGNORECASE)


class LoopbackHostOnly:
    """ASGI middleware: an HTTP request carrying exactly one Host header, naming loopback, goes on; any other gets 421
    Misdirected Request with no body. Outermost but for Starlette's own error middleware, so it answers before routing."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            hosts = [v for k, v in scope["headers"] if k == b"host"]
            if len(hosts) != 1 or not LOOPBACK_HOST.fullmatch(hosts[0].decode("latin-1")):
                await send({"type": "http.response.start", "status": 421, "headers": [(b"content-length", b"0")]})
                await send({"type": "http.response.body", "body": b""})
                return
        await self.app(scope, receive, send)


class Json(Response):
    media_type = "application/json"

    def render(self, content):
        return json.dumps(content, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")


def create_app(settings):
    """The app. app.state.closing is set when a stop is asked for (ui.cli's server, on Ctrl+C, Ctrl+Break or SIGTERM):
    every /api/stream ends within one of its 0.2 s turns, so its connection closes and the server's shutdown, which
    waits for open connections, completes (UI-1 S4 C-8)."""
    validator = Validator.from_file(cfg.schema_path())
    known_kinds = validator.known_kinds()
    ingestor = Ingestor(settings, validator)
    stop = threading.Event()
    closing = threading.Event()

    def ingest_loop(conn):
        while not stop.wait(settings.poll_seconds):
            try:
                ingestor.poll(conn)
            except Exception:  # a pass that fails (a feed mid-replace, a locked file) is retried next poll
                conn.rollback()

    @contextlib.asynccontextmanager
    async def lifespan(app):
        conn = store.open_writer(settings.db_path)
        try:
            ingestor.poll(conn)  # the first pass completes before the first request is answered
        except Exception:  # a pass that cannot run now (the registry locked) is the loop's to retry; never a failed start
            conn.rollback()
        t = threading.Thread(target=ingest_loop, args=(conn,), name="vanguard-ui-ingest", daemon=True)
        t.start()
        try:
            yield
        finally:
            stop.set()
            t.join(5)
            conn.close()

    app = FastAPI(title="vanguard ui", docs_url=None, redoc_url=None, openapi_url=None, lifespan=lifespan)
    app.add_middleware(LoopbackHostOnly)
    app.state.closing = closing

    def model():
        conn = store.open_reader(settings.db_path)
        try:
            return views.Model(conn, settings, known_kinds)
        finally:
            conn.close()

    def unknown(m, mid):
        return Json({"error": "unknown_mission", "mission_id": mid, "as_of": m.as_of()}, status_code=404)

    @app.exception_handler(RequestValidationError)
    async def bad_request(request, exc):
        detail = [{"loc": [str(x) for x in e.get("loc", ())], "msg": e.get("msg")} for e in exc.errors()]
        return Json({"error": "bad_request", "detail": detail, "as_of": model().as_of()}, status_code=422)

    @app.exception_handler(StarletteHTTPException)
    async def http_error(request, exc):
        if request.url.path.startswith("/api/"):
            return Json({"error": "not_found" if exc.status_code == 404 else "http_%d" % exc.status_code, "as_of": model().as_of()}, status_code=exc.status_code)
        return PlainTextResponse("Not Found" if exc.status_code == 404 else str(exc.detail), status_code=exc.status_code)

    @app.get("/api/missions")
    def api_missions():
        return Json(views.missions(model()))

    @app.get("/api/missions/{mission_id}")
    def api_mission(mission_id: str):
        m = model()
        if mission_id not in m.missions:
            return unknown(m, mission_id)
        return Json(views.mission(m, mission_id))

    @app.get("/api/missions/{mission_id}/events")
    def api_events(mission_id: str, since_seq: int = Query(0, ge=0), limit: int = Query(100, ge=1, le=1000),
                   kind: str = Query(None), stream: str = Query(None)):
        m = model()
        if mission_id not in m.missions:
            return unknown(m, mission_id)
        return Json(views.mission_events(m, mission_id, since_seq, limit, kind, stream))

    @app.get("/api/missions/{mission_id}/stats")
    def api_stats(mission_id: str):
        m = model()
        if mission_id not in m.missions:
            return unknown(m, mission_id)
        return Json(views.mission_stats(m, mission_id))

    @app.get("/api/stream")
    async def api_stream(request: Request):
        """One SSE event per ingested line: id = <projection epoch>.<projection row id>, data = mission_id, stream
        identity, seq, kind and as_of {seq, commit, ts}. Last-Event-ID of this projection resumes after that row;
        one of an earlier projection (a --rebuild renumbers the rows) replays every line, whose data carries
        (stream, seq) for the client to drop what it holds; without one, from now on."""
        conn = store.open_reader(settings.db_path)
        epoch = conn.execute("SELECT value FROM projection WHERE key = 'epoch'").fetchone()[0]
        last = (request.headers.get("last-event-id") or "").strip()
        head, _, row = last.partition(".")
        if last and head == epoch and row.isdigit():
            cursor = int(row)
        elif last:
            cursor = 0
        else:
            cursor = conn.execute("SELECT COALESCE(MAX(id), 0) FROM events").fetchone()[0]

        async def gen(cursor):
            try:
                yield "retry: 1000\n\n"
                idle = 0
                while not closing.is_set() and not await request.is_disconnected():
                    rows = conn.execute(
                        "SELECT e.id, e.mission_id, e.seq, e.kind, e.ts, e.commit_sha, s.host_id, s.checkout_path "
                        "FROM events e JOIN streams s ON s.stream_key = e.stream_key WHERE e.id > ? ORDER BY e.id LIMIT 500", (cursor,)).fetchall()
                    for r in rows:
                        cursor = r["id"]
                        data = {"mission_id": r["mission_id"], "stream": {"host_id": r["host_id"], "checkout_path": r["checkout_path"]},
                                "seq": r["seq"], "kind": r["kind"], "as_of": {"seq": r["seq"], "commit": r["commit_sha"], "ts": r["ts"]}}
                        yield "id: %s.%d\nevent: line\ndata: %s\n\n" % (epoch, cursor, json.dumps(data, ensure_ascii=False, separators=(",", ":")))
                    idle = 0 if rows else idle + 1
                    if idle >= 50:
                        idle = 0
                        yield ": keepalive\n\n"
                    await asyncio.sleep(0.2)
            finally:
                conn.close()

        return StreamingResponse(gen(cursor), media_type="text/event-stream", headers={"Cache-Control": "no-cache"})

    @app.get("/{path:path}")
    def spa(path: str):
        if path == "api" or path.startswith("api/"):
            return Json({"error": "not_found", "as_of": model().as_of()}, status_code=404)
        root = cfg.dist_dir()
        index = os.path.join(root, "index.html")
        if not os.path.isfile(index):
            return PlainTextResponse("Not Found", status_code=404)
        real_root = os.path.realpath(root)
        full = os.path.realpath(os.path.join(real_root, path))
        if path and (full == real_root or full.startswith(real_root + os.sep)) and os.path.isfile(full):
            return FileResponse(full)
        return FileResponse(index)

    return app
