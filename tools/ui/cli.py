"""The `vanguard` command (Typer). `vanguard ui` starts the read-only dashboard service (ADR-045): uvicorn
in-process, bound to 127.0.0.1 unless --host names another address. Ctrl+C (SIGINT), Ctrl+Break (SIGBREAK, Windows)
or SIGTERM stops it cleanly, open SSE clients or not: every stream closes, ui.db and the port are released, one line
is printed, the exit code is 0 (UI-1 S4 C-8)."""
import signal
import sys

import typer
import uvicorn

from ui import settings as cfg, store


class _Server(uvicorn.Server):
    """uvicorn's server, stopping cleanly. A stop asked for first sets the app's closing flag, so every SSE stream ends
    and its connection closes -- uvicorn's shutdown waits for open connections, so an open stream held it forever. The
    signal is then NOT raised again after shutdown, as uvicorn's own handler arranges (that would end the process as an
    interrupt -- exit 130 or 3, no line of ours); a second Ctrl+C still forces the exit, as uvicorn's does."""

    def __init__(self, config, closing):
        super().__init__(config)
        self.closing = closing
        self.stopped_by = None

    def handle_exit(self, sig, frame):
        self.stopped_by = self.stopped_by or sig
        self.closing.set()
        if self.should_exit and sig == signal.SIGINT:
            self.force_exit = True
        else:
            self.should_exit = True

app = typer.Typer(name="vanguard", add_completion=False, no_args_is_help=True,
                  help="Vanguard Collective -- host commands.")


@app.callback()
def vanguard():
    """Vanguard Collective -- host commands."""


@app.command("ui")
def ui(
    host: str = typer.Option(cfg.DEFAULT_HOST, "--host", help="Bind address, 127.0.0.1 by default. Version 1 serves loopback only: a request whose Host is "
                             "not loopback is answered 421, so binding another address serves nothing -- the flag is reserved for the v2 hub."),
    port: int = typer.Option(cfg.DEFAULT_PORT, "--port", help="TCP port."),
    rebuild: bool = typer.Option(False, "--rebuild", help="Delete the projection (ui.db) and regenerate it from the feeds before serving."),
    home: str = typer.Option(None, "--home", help="The Vanguard home holding projects.yaml and ui.db (default $VANGUARD_HOME, else ~/.vanguard)."),
    ahead_days: int = typer.Option(cfg.DEFAULT_AHEAD_DAYS, "--ahead-days", min=1, help="N for the error 'main ahead of origin beyond N days'."),
    tail_window_bytes: int = typer.Option(cfg.DEFAULT_TAIL_WINDOW_BYTES, "--tail-window-bytes", min=1, help="The tail window: the bytes before a stream's stored offset whose hash resume compares (the user guide, section 12)."),
):
    """Serve the read-only dashboard: /api/missions, /api/missions/{id}, .../events, .../stats, /api/stream."""
    from ui.app import create_app

    settings = cfg.Settings(home=cfg.vanguard_home(home), host=host, port=port, ahead_days=ahead_days, tail_window_bytes=tail_window_bytes)
    if rebuild:
        store.delete(settings.db_path)
    print("vanguard ui: http://%s:%d/  (home %s)" % (host, port, settings.home), flush=True)
    app_ = create_app(settings)
    config = uvicorn.Config(app_, host=host, port=port, log_level="warning", access_log=False,
                            date_header=False, server_header=False, lifespan="on")
    server = _Server(config, app_.state.closing)
    server.run()
    if server.stopped_by is not None:
        print("vanguard ui: stopped (%s)" % signal.Signals(server.stopped_by).name, flush=True)


def main():
    app(prog_name="vanguard")


if __name__ == "__main__":
    sys.exit(main())
