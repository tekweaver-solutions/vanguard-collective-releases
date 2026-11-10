"""The service's settings and the places it reads: the home, the schema, the built dashboard."""
import os
from dataclasses import dataclass

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
# F2: "main ahead of origin beyond N days" -- N is a service setting, 7 by default.
DEFAULT_AHEAD_DAYS = 7
POLL_SECONDS = 0.25
# THE TAIL WINDOW (register row 525; 505 (i)): on resume the tailer hashes the last N bytes before its stored offset and
# re-ingests a stream whose bytes there changed. A feed truncated and regrown between two polls, or while the service was
# down, with its first line and those N bytes as they were, is not seen as replaced: the limit, stated in the user
# guide's section 12 (and INSTALL.md section 5) and shown on the Fleet stats face. N is a service setting (--tail-window-bytes), 4096 by default -- more
# than any one line the hooks write.
DEFAULT_TAIL_WINDOW_BYTES = 4096

_TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAMEWORK_ROOT = os.path.dirname(_TOOLS)


def vanguard_home(override=None):
    """--home, else $VANGUARD_HOME, else ~/.vanguard -- the order tools/lam/mission-telemetry.ps1 writes by."""
    if override:
        return os.path.abspath(override)
    env = os.environ.get("VANGUARD_HOME")
    if env:
        return env
    profile = os.environ.get("USERPROFILE") or os.environ.get("HOME")
    return os.path.join(profile, ".vanguard")


def schema_path():
    return os.path.join(FRAMEWORK_ROOT, "docs", "framework", "mission-event.schema.json")


def dist_dir():
    """The built dashboard (S3): ui/dist beside tools/, or $VANGUARD_UI_DIST. /dist/ at the root is release.ps1's."""
    return os.environ.get("VANGUARD_UI_DIST") or os.path.join(FRAMEWORK_ROOT, "ui", "dist")


@dataclass(frozen=True)
class Settings:
    home: str
    host: str = DEFAULT_HOST
    port: int = DEFAULT_PORT
    ahead_days: int = DEFAULT_AHEAD_DAYS
    poll_seconds: float = POLL_SECONDS
    tail_window_bytes: int = DEFAULT_TAIL_WINDOW_BYTES

    @property
    def registry_path(self):
        return os.path.join(self.home, "projects.yaml")

    @property
    def db_path(self):
        return os.path.join(self.home, "ui.db")
