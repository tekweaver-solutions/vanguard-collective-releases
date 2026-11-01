"""CONTRACT-M-56 (REOPEN #20 / M-56) -- pytest fixtures for the FIRST PowerShell CLI
regression guards (F-074). These guards shell the REAL mission CLIs / dot-source the REAL
mission-lib helpers against ISOLATED fixture mission roots in a temp dir.

Isolation is load-bearing: Get-MissionRoot resolves to `(parent of the script dir)`, so the
guards copy the .ps1 files into `<tmp>/tools/` and invoke THOSE -- the CLI then operates on
`<tmp>/.mission/`, never the real repo mission. Nothing here touches the real .mission.

At the CONTRACT-M-56 RED baseline the F-072/F-073 helpers do not exist yet, so the dot-source
drivers terminate non-zero -- that is the contract-before-code RED proof. The guards flip GREEN
once BUILD-M-56 lands the helpers and rewires the sites.
"""

import shutil
import subprocess
from pathlib import Path

import pytest

_TOOLS = Path(__file__).resolve().parents[2]          # repo/tools
_CLI = Path(__file__).resolve().parent                 # repo/tools/tests/cli
_DRV_SET = _CLI / "_drv_set_field.ps1"
_DRV_NUM = _CLI / "_drv_resolve_number.ps1"


def _powershell():
    for cand in ("pwsh", "powershell", "powershell.exe"):
        path = shutil.which(cand)
        if path:
            return path
    pytest.skip("no PowerShell (pwsh/powershell) on PATH -- cannot shell the .ps1 CLIs")


def _run(args, timeout=180):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout)


class PsLib:
    """Dot-source the (freshly-copied) mission-lib.ps1 and call a pure helper."""

    def __init__(self, tmp):
        self.tmp = tmp
        tools = tmp / "tools"
        tools.mkdir(parents=True, exist_ok=True)
        self.lib = tools / "mission-lib.ps1"
        shutil.copy2(_TOOLS / "mission-lib.ps1", self.lib)
        self.ps = _powershell()

    def _txt(self, name, content):
        f = self.tmp / name
        f.write_text(content, encoding="utf-8")
        return f

    def set_field(self, text, key, value):
        f = self._txt("field_in.txt", text)
        return _run([self.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(_DRV_SET),
                     "-Lib", str(self.lib), "-TxtFile", str(f), "-Key", key, "-Value", value])

    def resolve_number(self, mission_text, block_kind, explicit):
        f = self._txt("num_in.txt", mission_text)
        return _run([self.ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(_DRV_NUM),
                     "-Lib", str(self.lib), "-TxtFile", str(f), "-BlockKind", block_kind,
                     "-Explicit", str(explicit)])


@pytest.fixture
def ps_lib(tmp_path):
    return PsLib(tmp_path)


class BumpResult:
    def __init__(self, proc, mission_text, spec011_text):
        self.proc = proc
        self.mission_text = mission_text
        self.spec011_text = spec011_text


@pytest.fixture
def bump_env(tmp_path):
    """Build an isolated mission root and run the REAL mission-spec-bump end-to-end (-NoCommit)."""
    ps = _powershell()

    def _build(mission_yaml, spec010_yaml):
        root = tmp_path
        tools = root / "tools"
        tools.mkdir(parents=True, exist_ok=True)
        shutil.copy2(_TOOLS / "mission-lib.ps1", tools / "mission-lib.ps1")
        shutil.copy2(_TOOLS / "mission-spec-bump.ps1", tools / "mission-spec-bump.ps1")
        m = root / ".mission"
        (m / "spec").mkdir(parents=True, exist_ok=True)
        (m / "amendments").mkdir(parents=True, exist_ok=True)
        (m / "ledger").mkdir(parents=True, exist_ok=True)
        (m / "mission.yaml").write_text(mission_yaml, encoding="utf-8")
        (m / "spec" / "current.txt").write_text("v010", encoding="utf-8")
        (m / "spec" / "v010.yaml").write_text(spec010_yaml, encoding="utf-8")
        (m / "amendments" / "AM-099-fixture.yaml").write_text("id: AM-099\n", encoding="utf-8")
        (m / "ledger" / "entries.jsonl").write_text("", encoding="utf-8")
        rec = root / "rec.txt"
        rec.write_text("# fixture spec-body record line\n", encoding="utf-8")
        led = root / "led.txt"
        led.write_text("fixture ledger content\n", encoding="utf-8")
        proc = _run([ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                     str(tools / "mission-spec-bump.ps1"), "-AmendmentId", "AM-099",
                     "-RecordFile", str(rec), "-LedgerContentFile", str(led), "-NoCommit"])
        mt = (m / "mission.yaml").read_text(encoding="utf-8")
        s11 = m / "spec" / "v011.yaml"
        st = s11.read_text(encoding="utf-8") if s11.exists() else ""
        return BumpResult(proc, mt, st)

    return _build
