"""The API-key authentication mode, on every path that starts the Claude Code CLI.

VANGUARD_AUTH_MODE selects it: unset or empty, nothing changes; ``api-key``, the CLI bills ANTHROPIC_API_KEY, which
travels in the child's environment only; ``subscription``, the subscription claimed out loud. The decision is
tools/lam/lam-auth-mode.ps1's for the runner (tools/lam/mission-dispatch.ps1) and the wake starter
(tools/lam/lam-wake.ps1), and tools/worker-runner/env_scrub.py's for the first-generation worker-runner. This file
drives the library, the runner and the wake starter in child PowerShell processes, and env_scrub in process.

NO KEY IS EVER HERE. NOT_A_KEY fails the provider's key shape (it has no ``sk-ant-`` prefix), and SHAPED_DUMMY has the
shape but is one repeated character, used only where the point is that a key-shaped value is refused before any CLI
that calls a model starts -- so it is never sent anywhere, and never put in any environment. NOT_A_KEY is put into a
child's environment, or, for the in-process env_scrub tests, into this process's through monkeypatch for that test
alone; SHAPED_DUMMY is handed to the scans as an argument (a mission root's path), written into a scratch file (one a
scratch repository commits, among them), or written into a case file the wake starter's driving child reads. Every refusal is held to not repeating the value it
found, and its reason to claiming nothing about what was started (each caller says that). With either mode set and
nothing refused, the runner and the wake starter print exactly what they print without the variable. No test reaches
a real CLI: the runner is handed stub seams (a verify, a login probe and a worker that each only write a marker), a
refused run must leave all three unwritten, and the wake starter runs with every step before its argv stubbed.
"""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
LIB = REPO / "tools" / "lam" / "lam-auth-mode.ps1"
RUNNER = REPO / "tools" / "lam" / "mission-dispatch.ps1"
WAKE = REPO / "tools" / "lam" / "lam-wake.ps1"
GUARD_LIB = REPO / "tools" / "evidence-hooks-next" / "hooks" / "lib" / "evidence-common.ps1"
DECIDER = REPO / "tools" / "evidence-hooks-next" / "hooks" / "evidence-pre-push.ps1"
POWERSHELL = shutil.which("powershell")

pytestmark = pytest.mark.skipif(
    sys.platform != "win32" or POWERSHELL is None or shutil.which("git") is None,
    reason="the LAM toolchain runs under Windows PowerShell 5.1, with git",
)

NOT_A_KEY = "not-a-key-r2s3-test-dummy"
SHAPED_DUMMY = "sk-ant-api03-" + "x" * 40
CREDENTIALS = (
    "VANGUARD_AUTH_MODE", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
)


def _env(**values: str) -> dict:
    """A child's environment: this one, every credential variable removed, then ``values`` set."""
    env = {k: v for k, v in os.environ.items() if k.upper() not in CREDENTIALS}
    env.update(values)
    return env


def _ps(script: Path, env: dict, *args: str, timeout: int = 300) -> subprocess.CompletedProcess:
    return subprocess.run(
        [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script), *args],
        env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout,
    )


# ---------------------------------------------------------------------------------------------------------------------
# THE LIBRARY -- every case in one child, each with its own environment, one JSON line each
# ---------------------------------------------------------------------------------------------------------------------
LIB_CASES = [
    # (label, environment set, expect ok, expect mode, expect code, names the reason must carry)
    ("unset", {}, True, "", "", []),
    ("api-key, no key", {"VANGUARD_AUTH_MODE": "api-key"}, False, "api-key", "AUTH-MODE-KEY-ABSENT", ["ANTHROPIC_API_KEY"]),
    ("api-key, empty key", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": ""}, False, "api-key", "AUTH-MODE-KEY-ABSENT", ["ANTHROPIC_API_KEY"]),
    ("api-key, a dummy", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, True, "api-key", "", []),
    ("api-key beside a bearer token", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY, "ANTHROPIC_AUTH_TOKEN": NOT_A_KEY}, False, "api-key", "AUTH-MODE-BOTH-CLAIMED", ["ANTHROPIC_AUTH_TOKEN"]),
    ("api-key beside the OAuth token", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY, "CLAUDE_CODE_OAUTH_TOKEN": NOT_A_KEY}, False, "api-key", "AUTH-MODE-BOTH-CLAIMED", ["CLAUDE_CODE_OAUTH_TOKEN"]),
    ("api-key beside a cloud selector", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY, "CLAUDE_CODE_USE_BEDROCK": "1"}, False, "api-key", "AUTH-MODE-BOTH-CLAIMED", ["CLAUDE_CODE_USE_BEDROCK"]),
    ("subscription", {"VANGUARD_AUTH_MODE": "subscription"}, True, "subscription", "", []),
    ("subscription beside a key", {"VANGUARD_AUTH_MODE": "subscription", "ANTHROPIC_API_KEY": NOT_A_KEY}, False, "subscription", "AUTH-MODE-BOTH-CLAIMED", ["ANTHROPIC_API_KEY"]),
    ("subscription beside the OAuth token", {"VANGUARD_AUTH_MODE": "subscription", "CLAUDE_CODE_OAUTH_TOKEN": NOT_A_KEY}, True, "subscription", "", []),
    ("an unknown value", {"VANGUARD_AUTH_MODE": "API-KEY"}, False, "", "AUTH-MODE-UNKNOWN", ["api-key", "subscription"]),
    ("a stray value put in the selector", {"VANGUARD_AUTH_MODE": NOT_A_KEY}, False, "", "AUTH-MODE-UNKNOWN", []),
]
SESSION_FILES = ("CLAUDE.md", "CLAUDE.local.md", ".claude\\CLAUDE.md", ".mcp.json")


@pytest.fixture(scope="module")
def lib_answers(tmp_path_factory) -> dict:
    d = tmp_path_factory.mktemp("authlib")
    cases = d / "cases.json"
    cases.write_text(json.dumps([{"label": c[0], "env": c[1]} for c in LIB_CASES]), encoding="utf-8")
    shaped = d / "shaped.txt"
    shaped.write_bytes(("line one\nline two\n  token: " + SHAPED_DUMMY + "\n").encode("ascii"))
    helper = d / "settings.json"
    helper.write_bytes(b'{\n  "apiKeyHelper": "C:/no/such/helper.cmd"\n}\n')
    clean = d / "clean.json"
    clean.write_bytes(b'{\n  "permissions": {}\n}\n')
    oauth = d / "oauth.json"
    oauth.write_bytes(b'{\n  "env": { "CLAUDE_CODE_OAUTH_TOKEN": "x" }\n}\n')
    wide = d / "wide.txt"
    wide.write_bytes(("line one\n  token: " + SHAPED_DUMMY + "\n").encode("utf-16-le"))
    script = d / "drive.ps1"
    script.write_text(
        "param([string]$Lib, [string]$Cases, [string]$Shaped, [string]$Helper, [string]$Clean, [string]$OAuth, [string]$Wide, [string]$Dummy, [string]$NotKey)\n"
        "$ErrorActionPreference = 'Stop'\n"
        ". $Lib\n"
        "$names = @(" + ", ".join("'%s'" % n for n in CREDENTIALS) + ")\n"
        "foreach ($c in (Get-Content -Raw -LiteralPath $Cases | ConvertFrom-Json)) {\n"
        "    foreach ($n in $names) { [System.Environment]::SetEnvironmentVariable($n, $null, 'Process') }\n"
        "    foreach ($p in $c.env.PSObject.Properties) { [System.Environment]::SetEnvironmentVariable($p.Name, [string]$p.Value, 'Process') }\n"
        "    $r = Get-LamAuthMode\n"
        "    [Console]::Out.WriteLine((@{ label = $c.label; ok = $r.ok; selected = $r.selected; mode = $r.mode; code = $r.code; reason = $r.reason } | ConvertTo-Json -Compress))\n"
        "}\n"
        "$scan = [ordered]@{\n"
        "    'argument'       = (Test-LamAuthSpawnInputs -Arguments @('-p', '--model', $Dummy))\n"
        "    'not-a-key arg'  = (Test-LamAuthSpawnInputs -Arguments @('-p', $NotKey))\n"
        "    'prompt'         = (Test-LamAuthSpawnInputs -Texts @{ 'prompt' = ('first' + [char]10 + 'second ' + $Dummy) })\n"
        "    'file'           = (Test-LamAuthSpawnInputs -Files @($Shaped))\n"
        "    'settings'       = (Test-LamAuthSpawnInputs -Files @($Helper) -SettingsFiles @($Helper))\n"
        "    'clean'          = (Test-LamAuthSpawnInputs -Arguments @('-p', '--model', 'm') -Texts @{ 'prompt' = 'nothing here' } -Files @($Clean, 'C:\\no\\such\\file.json') -SettingsFiles @($Clean))\n"
        "    'oauth setting'  = (Test-LamAuthSpawnInputs -Files @($OAuth) -SettingsFiles @($OAuth))\n"
        "    'utf-16 file'    = (Test-LamAuthSpawnInputs -Files @($Wide))\n"
        "    'subscription settings' = (Test-LamAuthSpawnInputs -Mode subscription -Arguments @($Dummy) -SettingsFiles @($Helper))\n"
        "    'subscription clean'    = (Test-LamAuthSpawnInputs -Mode subscription -Arguments @($Dummy) -SettingsFiles @($Clean))\n"
        "    'subscription oauth'    = (Test-LamAuthSpawnInputs -Mode subscription -SettingsFiles @($OAuth))\n"
        "}\n"
        "foreach ($k in $scan.Keys) { $r = $scan[$k]; [Console]::Out.WriteLine((@{ label = 'scan ' + $k; ok = $r.ok; mode = $r.mode; code = $r.code; reason = $r.reason } | ConvertTo-Json -Compress)) }\n"
        "try { $sf = @(Get-LamAuthSessionFiles -Root 'C:\\r') } catch { $sf = @('ERROR: ' + $_.Exception.Message) }\n"
        "[Console]::Out.WriteLine((@{ label = 'session files'; files = $sf } | ConvertTo-Json -Compress))\n",
        encoding="utf-8",
    )
    p = _ps(script, _env(), "-Lib", str(LIB), "-Cases", str(cases), "-Shaped", str(shaped), "-Helper", str(helper),
            "-Clean", str(clean), "-OAuth", str(oauth), "-Wide", str(wide), "-Dummy", SHAPED_DUMMY, "-NotKey", NOT_A_KEY)
    answers = {}
    for line in p.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            a = json.loads(line)
            answers[a["label"]] = a
    answers["_stdout"] = p.stdout
    answers["_stderr"] = p.stderr
    answers["_paths"] = {"shaped": str(shaped), "helper": str(helper)}
    return answers


@pytest.mark.parametrize("case", LIB_CASES, ids=[c[0] for c in LIB_CASES])
def test_library_decides_the_mode_by_presence(lib_answers, case) -> None:
    label, _env_set, ok, mode, code, names = case
    a = lib_answers.get(label)
    assert a is not None, f"the library gave no answer for {label!r}: stderr {lib_answers['_stderr'][:400]!r}"
    assert (a["ok"], a["mode"], a["code"]) == (ok, mode, code)
    for n in names:
        assert n in a["reason"]
    assert NOT_A_KEY not in a["reason"] and SHAPED_DUMMY not in a["reason"]


def test_library_scan_refuses_a_key_shaped_value_naming_where_never_what(lib_answers) -> None:
    arg, notkey = lib_answers.get("scan argument"), lib_answers.get("scan not-a-key arg")
    prompt, f, settings, clean = (lib_answers.get("scan " + k) for k in ("prompt", "file", "settings", "clean"))
    assert arg and (arg["ok"], arg["code"]) == (False, "AUTH-MODE-KEY-IN-ARGUMENT") and "argument 2" in arg["reason"]
    assert notkey and notkey["ok"] is True, "the scan is by the key's shape: a value without it is not refused"
    assert prompt and (prompt["ok"], prompt["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and "line 2" in prompt["reason"]
    assert f and (f["ok"], f["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and lib_answers["_paths"]["shaped"] in f["reason"] and "line 3" in f["reason"]
    assert settings and (settings["ok"], settings["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and "apiKeyHelper" in settings["reason"]
    assert clean and clean["ok"] is True
    oauth, wide = lib_answers.get("scan oauth setting"), lib_answers.get("scan utf-16 file")
    sub_bad, sub_ok = lib_answers.get("scan subscription settings"), lib_answers.get("scan subscription clean")
    assert oauth and (oauth["ok"], oauth["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and "CLAUDE_CODE_OAUTH_TOKEN" in oauth["reason"]
    assert wide and (wide["ok"], wide["code"]) == (False, "AUTH-MODE-KEY-IN-FILE"), "a UTF-16 file must not hide the shape"
    assert sub_bad and (sub_bad["ok"], sub_bad["mode"], sub_bad["code"]) == (False, "subscription", "AUTH-MODE-BOTH-CLAIMED") and "apiKeyHelper" in sub_bad["reason"]
    assert sub_ok and sub_ok["ok"] is True and sub_ok["mode"] == "subscription", "under subscription only the settings files are read"
    sub_oauth = lib_answers.get("scan subscription oauth")
    assert sub_oauth and sub_oauth["ok"] is True, "the OAuth token is the subscription's own credential, not another one beside it"
    for r in (arg, prompt, f, settings, oauth, wide):
        assert "spawned" not in r["reason"], "a scan's reason claims nothing about what its caller started: " + r["reason"]
    assert SHAPED_DUMMY not in lib_answers["_stdout"] and NOT_A_KEY not in lib_answers["_stdout"]


def test_library_names_the_files_a_session_loads_at_its_root(lib_answers) -> None:
    a = lib_answers.get("session files")
    assert a is not None, lib_answers["_stderr"][:400]
    assert a["files"] == ["C:\\r\\" + n for n in SESSION_FILES]


# ---------------------------------------------------------------------------------------------------------------------
# THE RUNNER -- a mission root it dispatches into, and seams that only write markers
# ---------------------------------------------------------------------------------------------------------------------
DISPATCH = (
    "id: D-T1\nmission_id: t\nworker_id: w-t1\nkind: read-only\nfeature_id: F-001\nassertion_targets: []\n"
    "spec_version: 1\nmodel_class: small-fast\nbrief: |\n  Do nothing.\n"
)


def _git(cwd: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True)


def _mission(base: Path, leaf: str = "m", dispatch: str = DISPATCH, settings_local: str | None = None,
             extra: dict | None = None) -> dict:
    """A git repository with one commit holding one dispatch artifact (and ``extra``, relative path -> text), the
    pre-push decider installed by the guard library in a child (as WP-6 S-1b installs it), and three seam scripts that
    each write a marker when run."""
    root = base / leaf
    (root / ".mission" / "dispatches").mkdir(parents=True)
    (root / ".mission" / "dispatches" / "D-T1.yaml").write_bytes(dispatch.encode("utf-8"))
    if settings_local is not None:
        (root / ".claude").mkdir()
        (root / ".claude" / "settings.local.json").write_bytes(settings_local.encode("utf-8"))
    for rel, text in (extra or {}).items():
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_bytes(text.encode("utf-8"))
    _git(root.parent, "init", "-q", str(root))
    for k, v in (("user.name", "auth-mode-test"), ("user.email", "auth-mode-test@localhost"), ("core.autocrlf", "false")):
        _git(root, "config", k, v)
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "seed")
    installer = base / "install-decider.ps1"
    installer.write_text(
        "param([string]$Library, [string]$Decider, [string]$Hook)\n$ErrorActionPreference = 'Stop'\n. $Library\n"
        "[System.IO.File]::WriteAllText($Hook, (Get-EvidencePrePushWrapperText -DeciderPath $Decider), (New-Object System.Text.UTF8Encoding($false)))\nexit 0\n",
        encoding="utf-8",
    )
    assert _ps(installer, _env(), "-Library", str(GUARD_LIB), "-Decider", str(DECIDER), "-Hook", str(root / ".git" / "hooks" / "pre-push")).returncode == 0
    marks = base / "marks"
    marks.mkdir()
    seams = {}
    for name, body in (("verify", "Write-Output 'gate: PASS'"), ("probe", "Write-Output 'OK'"), ("worker", "Write-Output '{}'")):
        s = base / f"{name}-seam.ps1"
        s.write_text(f"[System.IO.File]::WriteAllText('{marks / (name + '.ran')}', 'ran')\n{body}\nexit 0\n", encoding="utf-8")
        seams[name] = s
    return {"root": root, "marks": marks, "seams": seams}


def _dispatch(m: dict, env: dict, plan_only: bool = False) -> subprocess.CompletedProcess:
    args = ["-MissionRoot", str(m["root"]), "-Dispatch", "D-T1", "-VerifyCommand", str(m["seams"]["verify"]),
            "-LoginProbeCommand", str(m["seams"]["probe"]), "-WorkerCommand", str(m["seams"]["worker"])]
    if plan_only:
        args.append("-PlanOnly")
    return _ps(RUNNER, env, *args)


def _ran(m: dict) -> list:
    return sorted(p.name for p in m["marks"].iterdir())


RUNNER_REFUSALS = [
    ("mode set, no key", {"VANGUARD_AUTH_MODE": "api-key"}, {}, "AUTH-MODE-KEY-ABSENT"),
    ("key beside a bearer token", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY, "ANTHROPIC_AUTH_TOKEN": NOT_A_KEY}, {}, "AUTH-MODE-BOTH-CLAIMED"),
    ("subscription beside a key", {"VANGUARD_AUTH_MODE": "subscription", "ANTHROPIC_API_KEY": NOT_A_KEY}, {}, "AUTH-MODE-BOTH-CLAIMED"),
    ("an unknown mode", {"VANGUARD_AUTH_MODE": "apikey"}, {}, "AUTH-MODE-UNKNOWN"),
    ("a key-shaped value in the dispatch", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, {"dispatch": DISPATCH + "  token " + SHAPED_DUMMY + "\n"}, "AUTH-MODE-KEY-IN-FILE"),
    ("a credential setting in the mission's settings", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, {"settings_local": '{\n  "apiKeyHelper": "C:/no/such/helper.cmd"\n}\n'}, "AUTH-MODE-KEY-IN-FILE"),
    ("a key-shaped value in an argument (the mission root's own path)", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, {"leaf": SHAPED_DUMMY}, "AUTH-MODE-KEY-IN-ARGUMENT"),
    ("subscription beside a credential in the mission's settings", {"VANGUARD_AUTH_MODE": "subscription"}, {"settings_local": '{\n  "env": { "ANTHROPIC_AUTH_TOKEN": "x" }\n}\n'}, "AUTH-MODE-BOTH-CLAIMED"),
    ("a key-shaped value in the mission's CLAUDE.md", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, {"extra": {"CLAUDE.md": "# notes\n  token " + SHAPED_DUMMY + "\n"}}, "AUTH-MODE-KEY-IN-FILE"),
    ("a key-shaped value in the mission's .mcp.json", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, {"extra": {".mcp.json": '{\n  "mcpServers": { "s": { "env": { "T": "' + SHAPED_DUMMY + '" } } }\n}\n'}}, "AUTH-MODE-KEY-IN-FILE"),
]


@pytest.mark.parametrize("case", RUNNER_REFUSALS, ids=[c[0] for c in RUNNER_REFUSALS])
def test_runner_refuses_before_anything_is_spawned(tmp_path, case) -> None:
    _label, env_set, mission, code = case
    m = _mission(tmp_path, **mission)
    p = _dispatch(m, _env(**env_set))
    refusal = [l for l in p.stdout.splitlines() if l.startswith("mission-dispatch: REFUSED -- ")]
    assert p.returncode == 2, p.stdout[-2000:]
    assert refusal and refusal[0].startswith(f"mission-dispatch: REFUSED -- {code}: "), p.stdout[-2000:]
    assert _ran(m) == [], "a refused run spawned a seam: " + ", ".join(_ran(m))
    assert not (m["root"] / ".mission-runtime").exists(), "a refused run wrote under the mission root"
    assert NOT_A_KEY not in p.stdout + p.stderr and SHAPED_DUMMY not in refusal[0]
    assert "spawned" not in refusal[0], "the reason claims nothing about what was started; the runner's next line does"


def test_runner_in_either_mode_prints_what_it_prints_without_the_variable(tmp_path) -> None:
    """Nothing else changes: a clean dispatch's plan in key mode, and in subscription mode, is the plan the runner
    prints with the variable unset, byte for byte -- no line about the mode, no value."""
    m = _mission(tmp_path)
    bare = _dispatch(m, _env(), plan_only=True)
    keyed = _dispatch(m, _env(VANGUARD_AUTH_MODE="api-key", ANTHROPIC_API_KEY=NOT_A_KEY), plan_only=True)
    sub = _dispatch(m, _env(VANGUARD_AUTH_MODE="subscription"), plan_only=True)
    assert bare.returncode == keyed.returncode == sub.returncode == 0, keyed.stdout[-2000:] + sub.stdout[-2000:]
    assert "mission-dispatch PLAN for D-T1" in bare.stdout
    assert keyed.stdout == bare.stdout, keyed.stdout[-2000:]
    assert sub.stdout == bare.stdout, sub.stdout[-2000:]
    assert NOT_A_KEY not in keyed.stdout + keyed.stderr
    assert _ran(m) == []


def test_runner_subscription_admits_the_subscription_token_in_the_mission_settings(tmp_path) -> None:
    """CLAUDE_CODE_OAUTH_TOKEN is the subscription's own credential: subscription mode does not refuse it beside
    itself, and prints the plan it prints without the variable."""
    m = _mission(tmp_path, settings_local='{\n  "env": { "CLAUDE_CODE_OAUTH_TOKEN": "x" }\n}\n')
    bare = _dispatch(m, _env(), plan_only=True)
    sub = _dispatch(m, _env(VANGUARD_AUTH_MODE="subscription"), plan_only=True)
    assert sub.returncode == 0, sub.stdout[-2000:]
    assert sub.stdout == bare.stdout


def test_runner_with_the_selector_unset_is_unchanged_by_a_key_in_the_environment(tmp_path) -> None:
    """Never by sniffing: unset, a key present changes nothing the runner prints."""
    m = _mission(tmp_path)
    bare = _dispatch(m, _env(), plan_only=True)
    keyed = _dispatch(m, _env(ANTHROPIC_API_KEY=NOT_A_KEY), plan_only=True)
    assert bare.returncode == keyed.returncode == 0
    assert bare.stdout == keyed.stdout
    assert "auth mode" not in bare.stdout


# ---------------------------------------------------------------------------------------------------------------------
# THE TREE THE WORKER RUNS IN -- cut at the dispatch's declared base, or already standing at the worktree path. The CLI
# loads that tree's root files and .claude settings, which need not be the mission root's working copy.
# ---------------------------------------------------------------------------------------------------------------------
def _mission_at_base(base: Path, at_base: dict) -> tuple[dict, str]:
    """A mission whose first commit -- the dispatch's declared base -- holds ``at_base`` (relative path -> text), and
    whose second, HEAD, removes those files and declares ``base_head_at_authoring`` as the first: the tree the runner
    cuts for the worker carries them, the mission root's working copy does not."""
    m = _mission(base, extra=at_base)
    root = m["root"]
    sha = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], check=True, capture_output=True,
                         text=True).stdout.strip()
    for rel in at_base:
        _git(root, "rm", "-q", "--", rel.replace("\\", "/"))
    (root / ".mission" / "dispatches" / "D-T1.yaml").write_bytes(
        (DISPATCH + "base_head_at_authoring: " + sha + "\n").encode("utf-8"))
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "declare the base")
    return m, sha


KEYED = {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}
BASE_REFUSALS = [
    ("a key-shaped value in CLAUDE.md at the declared base", KEYED, {"CLAUDE.md": "# notes\n  token " + SHAPED_DUMMY + "\n"}, "AUTH-MODE-KEY-IN-FILE"),
    ("a key-shaped value in .mcp.json at the declared base", KEYED, {".mcp.json": '{\n  "mcpServers": { "s": { "env": { "T": "' + SHAPED_DUMMY + '" } } }\n}\n'}, "AUTH-MODE-KEY-IN-FILE"),
    ("a credential setting in .claude/settings.json at the declared base", KEYED, {".claude/settings.json": '{\n  "apiKeyHelper": "C:/no/such/helper.cmd"\n}\n'}, "AUTH-MODE-KEY-IN-FILE"),
    ("subscription beside a credential in .claude/settings.json at the declared base", {"VANGUARD_AUTH_MODE": "subscription"}, {".claude/settings.json": '{\n  "env": { "ANTHROPIC_AUTH_TOKEN": "x" }\n}\n'}, "AUTH-MODE-BOTH-CLAIMED"),
]


@pytest.mark.parametrize("case", BASE_REFUSALS, ids=[c[0] for c in BASE_REFUSALS])
def test_runner_scans_the_tree_at_the_declared_base(tmp_path, case) -> None:
    """The worker's tree is cut at the dispatch's declared base: its root files are that commit's. A value there is
    refused before anything starts although HEAD's working copy no longer carries it; the reason names the commit."""
    _label, env_set, at_base, code = case
    m, sha = _mission_at_base(tmp_path, at_base)
    assert not any((m["root"] / rel).exists() for rel in at_base), "the working copy must not carry the files"
    p = _dispatch(m, _env(**env_set))
    refusal = [l for l in p.stdout.splitlines() if l.startswith("mission-dispatch: REFUSED -- ")]
    assert p.returncode == 2, p.stdout[-2000:]
    assert refusal and refusal[0].startswith(f"mission-dispatch: REFUSED -- {code}: "), p.stdout[-2000:]
    assert sha[:12] in refusal[0], "the reason names the commit the tree is cut at: " + refusal[0]
    assert _ran(m) == [], "a refused run spawned a seam: " + ", ".join(_ran(m))
    assert not (m["root"] / ".mission-runtime").exists(), "a refused run wrote under the mission root"
    assert NOT_A_KEY not in p.stdout + p.stderr and SHAPED_DUMMY not in refusal[0]
    assert "spawned" not in refusal[0]


def test_runner_admits_a_clean_tree_at_the_declared_base_and_prints_what_it_prints_without_the_variable(tmp_path) -> None:
    """A declared base whose root files carry nothing -- and the subscription's own token in its settings -- changes
    nothing: either mode's plan is the plan printed with the variable unset."""
    m, _sha = _mission_at_base(tmp_path, {"CLAUDE.md": "# notes\n", ".claude/settings.json": '{\n  "env": { "CLAUDE_CODE_OAUTH_TOKEN": "x" }\n}\n'})
    bare = _dispatch(m, _env(), plan_only=True)
    sub = _dispatch(m, _env(VANGUARD_AUTH_MODE="subscription"), plan_only=True)
    assert bare.returncode == sub.returncode == 0, sub.stdout[-2000:]
    assert sub.stdout == bare.stdout
    m2, _sha2 = _mission_at_base(tmp_path / "k", {"CLAUDE.md": "# notes\n"})
    bare2 = _dispatch(m2, _env(), plan_only=True)
    keyed = _dispatch(m2, _env(**KEYED), plan_only=True)
    assert bare2.returncode == keyed.returncode == 0, keyed.stdout[-2000:]
    assert keyed.stdout == bare2.stdout
    assert NOT_A_KEY not in keyed.stdout + keyed.stderr


STANDING_REFUSALS = [
    ("a key-shaped value in CLAUDE.md of the tree standing at the worktree path", KEYED, {"CLAUDE.md": "# notes\n  token " + SHAPED_DUMMY + "\n"}, "AUTH-MODE-KEY-IN-FILE"),
    ("a credential setting in the standing tree's .claude settings", KEYED, {".claude/settings.local.json": '{\n  "apiKeyHelper": "C:/no/such/helper.cmd"\n}\n'}, "AUTH-MODE-KEY-IN-FILE"),
    ("subscription beside a credential in the standing tree's .claude settings", {"VANGUARD_AUTH_MODE": "subscription"}, {".claude/settings.local.json": '{\n  "env": { "ANTHROPIC_API_KEY": "x" }\n}\n'}, "AUTH-MODE-BOTH-CLAIMED"),
]


@pytest.mark.parametrize("case", STANDING_REFUSALS, ids=[c[0] for c in STANDING_REFUSALS])
def test_runner_scans_a_tree_already_standing_at_the_worktree_path(tmp_path, case) -> None:
    """A tree that already stands where the worker's goes is reused as it stands: its files are scanned too."""
    _label, env_set, files, code = case
    m = _mission(tmp_path)
    tree = tmp_path / "m-worktrees" / "wt-D-T1"
    for rel, text in files.items():
        (tree / rel).parent.mkdir(parents=True, exist_ok=True)
        (tree / rel).write_bytes(text.encode("utf-8"))
    p = _dispatch(m, _env(**env_set))
    refusal = [l for l in p.stdout.splitlines() if l.startswith("mission-dispatch: REFUSED -- ")]
    assert p.returncode == 2, p.stdout[-2000:]
    assert refusal and refusal[0].startswith(f"mission-dispatch: REFUSED -- {code}: "), p.stdout[-2000:]
    assert "wt-D-T1" in refusal[0], "the reason names the standing tree's file: " + refusal[0]
    assert _ran(m) == [], "a refused run spawned a seam: " + ", ".join(_ran(m))
    assert NOT_A_KEY not in p.stdout + p.stderr and SHAPED_DUMMY not in refusal[0]


@pytest.fixture(scope="module")
def lib_tree_answers(tmp_path_factory) -> dict:
    """The library's two additions, in one child: settings handed over as text, and the files a commit holds at the
    root of a tree cut there."""
    d = tmp_path_factory.mktemp("authtree")
    repo = d / "r"
    (repo / ".claude").mkdir(parents=True)
    (repo / "CLAUDE.md").write_bytes(b"# notes\n")
    (repo / ".mcp.json").write_bytes(("line one\n  token: " + SHAPED_DUMMY + "\n").encode("utf-16-le"))
    (repo / ".claude" / "settings.json").write_bytes(b'{\n  "apiKeyHelper": "C:/no/such/helper.cmd"\n}\n')
    _git(d, "init", "-q", str(repo))
    for k, v in (("user.name", "auth-mode-test"), ("user.email", "auth-mode-test@localhost"), ("core.autocrlf", "false")):
        _git(repo, "config", k, v)
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", "seed")
    sha = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    script = d / "drive.ps1"
    script.write_text(
        "param([string]$Lib, [string]$Repo, [string]$Rev, [string]$Dummy)\n"
        "$ErrorActionPreference = 'Stop'\n"
        ". $Lib\n"
        "$c = Get-LamAuthCommittedFiles -Repo $Repo -Rev $Rev\n"
        "[Console]::Out.WriteLine((@{ label = 'committed'; texts = @($c.texts.Keys); settings = @($c.settings.Keys) } | ConvertTo-Json -Compress))\n"
        "$scan = [ordered]@{\n"
        "    'committed key'        = (Test-LamAuthSpawnInputs -Texts $c.texts -SettingsTexts $c.settings)\n"
        "    'settings text name'   = (Test-LamAuthSpawnInputs -SettingsTexts @{ 'the settings' = '{ \"apiKeyHelper\": \"x\" }' })\n"
        "    'settings text shape'  = (Test-LamAuthSpawnInputs -SettingsTexts @{ 'the settings' = ('{ \"x\": \"' + $Dummy + '\" }') })\n"
        "    'settings text clean'  = (Test-LamAuthSpawnInputs -SettingsTexts @{ 'the settings' = '{ \"permissions\": {} }' })\n"
        "    'subscription name'    = (Test-LamAuthSpawnInputs -Mode subscription -SettingsTexts @{ 'the settings' = '{ \"env\": { \"ANTHROPIC_API_KEY\": \"x\" } }' })\n"
        "    'subscription oauth'   = (Test-LamAuthSpawnInputs -Mode subscription -SettingsTexts @{ 'the settings' = '{ \"env\": { \"CLAUDE_CODE_OAUTH_TOKEN\": \"x\" } }' })\n"
        "}\n"
        "foreach ($k in $scan.Keys) { $r = $scan[$k]; [Console]::Out.WriteLine((@{ label = $k; ok = $r.ok; mode = $r.mode; code = $r.code; reason = $r.reason } | ConvertTo-Json -Compress)) }\n",
        encoding="utf-8",
    )
    p = _ps(script, _env(), "-Lib", str(LIB), "-Repo", str(repo), "-Rev", sha, "-Dummy", SHAPED_DUMMY)
    answers = {"_stdout": p.stdout, "_stderr": p.stderr, "_sha": sha}
    for line in p.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            a = json.loads(line)
            answers[a["label"]] = a
    return answers


def test_library_reads_the_files_a_commit_holds_at_the_root_of_its_tree(lib_tree_answers) -> None:
    a = lib_tree_answers.get("committed")
    assert a is not None, lib_tree_answers["_stderr"][:600]
    sha12 = lib_tree_answers["_sha"][:12]
    assert [k.split(" ")[0] for k in a["texts"]] == ["CLAUDE.md", ".mcp.json"], a["texts"]
    assert [k.split(" ")[0] for k in a["settings"]] == [".claude/settings.json"], a["settings"]
    assert all(sha12 in k for k in a["texts"] + a["settings"]), "each names the commit it was read from"
    r = lib_tree_answers.get("committed key")
    assert r and (r["ok"], r["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and ".mcp.json" in r["reason"], r
    assert SHAPED_DUMMY not in lib_tree_answers["_stdout"] and NOT_A_KEY not in lib_tree_answers["_stdout"]


def test_library_scans_settings_handed_over_as_text(lib_tree_answers) -> None:
    name, shape, clean = (lib_tree_answers.get("settings text " + k) for k in ("name", "shape", "clean"))
    sub_name, sub_oauth = lib_tree_answers.get("subscription name"), lib_tree_answers.get("subscription oauth")
    assert name and (name["ok"], name["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and "apiKeyHelper" in name["reason"] and "the settings" in name["reason"]
    assert shape and (shape["ok"], shape["code"]) == (False, "AUTH-MODE-KEY-IN-FILE"), shape
    assert clean and clean["ok"] is True
    assert sub_name and (sub_name["ok"], sub_name["mode"], sub_name["code"]) == (False, "subscription", "AUTH-MODE-BOTH-CLAIMED")
    assert sub_oauth and sub_oauth["ok"] is True
    for r in (name, shape, sub_name):
        assert "spawned" not in r["reason"]


def _drop_blob(root: Path, rel: str) -> None:
    """Delete the loose object of HEAD's ``rel``: the commit still names the file, and git can no longer read it."""
    sha = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD:" + rel], check=True, capture_output=True,
                         text=True).stdout.strip()
    obj = root / ".git" / "objects" / sha[:2] / sha[2:]
    os.chmod(obj, stat.S_IWRITE)
    obj.unlink()
    assert subprocess.run(["git", "-C", str(root), "cat-file", "-e", "HEAD:" + rel], capture_output=True).returncode != 0


UNREADABLE = [
    ("key mode, CLAUDE.md named by the commit and unreadable", KEYED, "CLAUDE.md", "# notes\n"),
    ("subscription, .claude/settings.json named by the commit and unreadable", {"VANGUARD_AUTH_MODE": "subscription"}, ".claude/settings.json", '{\n  "permissions": {}\n}\n'),
]


@pytest.mark.parametrize("case", UNREADABLE, ids=[c[0] for c in UNREADABLE])
def test_runner_refuses_a_commit_whose_root_file_git_cannot_read(tmp_path, case) -> None:
    """A file the commit the tree is cut at names, but git cannot read, is not taken as absent: the mode cannot be held
    to it, so the run is refused AUTH-MODE-UNREADABLE before the verify gate, the probe or the worker starts."""
    _label, env_set, rel, text = case
    m = _mission(tmp_path, extra={rel: text})
    _drop_blob(m["root"], rel)
    p = _dispatch(m, _env(**env_set))
    refusal = [l for l in p.stdout.splitlines() if l.startswith("mission-dispatch: REFUSED -- ")]
    assert p.returncode == 2, p.stdout[-2000:]
    assert refusal and refusal[0].startswith("mission-dispatch: REFUSED -- AUTH-MODE-UNREADABLE: "), p.stdout[-2000:]
    assert rel in refusal[0], "the reason names the file git could not read: " + refusal[0]
    assert _ran(m) == [], "a refused run spawned a seam: " + ", ".join(_ran(m))
    assert NOT_A_KEY not in p.stdout + p.stderr


def test_library_tells_a_file_the_commit_lacks_from_one_git_cannot_read(tmp_path) -> None:
    """Get-LamAuthCommittedFiles leaves out a file the commit does not hold, and throws for one it names that git cannot
    read -- the caller then cannot say what the tree carries."""
    m = _mission(tmp_path, extra={"CLAUDE.md": "# notes\n"})
    sha = subprocess.run(["git", "-C", str(m["root"]), "rev-parse", "HEAD"], check=True, capture_output=True,
                         text=True).stdout.strip()
    script = tmp_path / "drive-unreadable.ps1"
    script.write_text(
        "param([string]$Lib, [string]$Repo, [string]$Rev)\n$ErrorActionPreference = 'Stop'\n. $Lib\n"
        "try { $c = Get-LamAuthCommittedFiles -Repo $Repo -Rev $Rev; [Console]::Out.WriteLine('READ ' + (@($c.texts.Keys) -join '|')) }\n"
        "catch { [Console]::Out.WriteLine('THREW ' + $_.Exception.Message) }\n",
        encoding="utf-8",
    )
    before = _ps(script, _env(), "-Lib", str(LIB), "-Repo", str(m["root"]), "-Rev", sha)
    assert before.stdout.startswith("READ CLAUDE.md as commit "), before.stdout + before.stderr
    _drop_blob(m["root"], "CLAUDE.md")
    after = _ps(script, _env(), "-Lib", str(LIB), "-Repo", str(m["root"]), "-Rev", sha)
    assert after.stdout.startswith("THREW ") and "CLAUDE.md" in after.stdout, after.stdout + after.stderr


# ---------------------------------------------------------------------------------------------------------------------
# IN ANY LETTER CASE -- git matches a path's letter case exactly, a case-insensitive checkout does not:
# a commit holding claude.md or .Claude/settings.json gives the worker's tree files the CLI opens as CLAUDE.md and
# .claude\settings.json. The committed read takes every entry whose name is a session or settings file's but for ASCII
# letter case, a folder or a submodule at such a name is no file, and under subscription no memory file is read.
# ---------------------------------------------------------------------------------------------------------------------
SUBSCRIPTION = {"VANGUARD_AUTH_MODE": "subscription"}
HELPER_SETTING = '{\n  "apiKeyHelper": "C:/no/such/helper.cmd"\n}\n'
CASE_BASE_REFUSALS = [
    ("a key-shaped value in claude.md at the declared base", KEYED, "claude.md", "# notes\n  token " + SHAPED_DUMMY + "\n", "AUTH-MODE-KEY-IN-FILE"),
    ("a key-shaped value in Claude.local.md at the declared base", KEYED, "Claude.local.md", "# notes\n  token " + SHAPED_DUMMY + "\n", "AUTH-MODE-KEY-IN-FILE"),
    ("a key-shaped value in .CLAUDE/claude.md at the declared base", KEYED, ".CLAUDE/claude.md", "# notes\n  token " + SHAPED_DUMMY + "\n", "AUTH-MODE-KEY-IN-FILE"),
    ("a key-shaped value in .MCP.json at the declared base", KEYED, ".MCP.json", '{\n  "mcpServers": { "s": { "env": { "T": "' + SHAPED_DUMMY + '" } } }\n}\n', "AUTH-MODE-KEY-IN-FILE"),
    ("a credential setting in .Claude/settings.json at the declared base", KEYED, ".Claude/settings.json", HELPER_SETTING, "AUTH-MODE-KEY-IN-FILE"),
    ("subscription beside a credential setting in .Claude/settings.json at the declared base", SUBSCRIPTION, ".Claude/settings.json", HELPER_SETTING, "AUTH-MODE-BOTH-CLAIMED"),
    ("a credential setting in .claude/Settings.Local.json at the declared base", KEYED, ".claude/Settings.Local.json", HELPER_SETTING, "AUTH-MODE-KEY-IN-FILE"),
]


def _refusal(p: subprocess.CompletedProcess) -> list:
    return [l for l in p.stdout.splitlines() if l.startswith("mission-dispatch: REFUSED -- ")]


@pytest.mark.parametrize("case", CASE_BASE_REFUSALS, ids=[c[0] for c in CASE_BASE_REFUSALS])
def test_runner_reads_the_tree_at_the_declared_base_in_any_letter_case(tmp_path, case) -> None:
    """A root file or .claude setting the declared base holds under another letter case than the CLI's is what the
    worker's checkout gives the CLI: it is read, and refused, the reason naming it as the commit spells it."""
    _label, env_set, rel, text, code = case
    m, sha = _mission_at_base(tmp_path, {rel: text})
    listed = subprocess.run(["git", "-C", str(m["root"]), "ls-tree", "-r", "--name-only", sha], check=True,
                            capture_output=True, text=True).stdout.splitlines()
    assert rel in listed, "the declared base holds the file in its own letter case: " + ", ".join(listed)
    assert not (m["root"] / rel).exists(), "the working copy must not carry the file"
    p = _dispatch(m, _env(**env_set))
    refusal = _refusal(p)
    assert p.returncode == 2, p.stdout[-2000:]
    assert refusal and refusal[0].startswith(f"mission-dispatch: REFUSED -- {code}: "), p.stdout[-2000:]
    assert rel + " as commit " + sha[:12] in refusal[0], "the reason names the file as the commit spells it: " + refusal[0]
    assert _ran(m) == [], "a refused run spawned a seam: " + ", ".join(_ran(m))
    assert not (m["root"] / ".mission-runtime").exists(), "a refused run wrote under the mission root"
    assert NOT_A_KEY not in p.stdout + p.stderr and SHAPED_DUMMY not in refusal[0]


@pytest.mark.parametrize("name", ["claude.md", "CLAUDE.md"], ids=["in another letter case", "in the CLI's own spelling"])
def test_runner_reads_heads_root_file_its_working_copy_deleted(tmp_path, name) -> None:
    """HEAD is the cut point where the dispatch declares no base: a root file it holds and the working copy has
    deleted is still in the worker's tree, in whichever letter case it is committed."""
    m = _mission(tmp_path, extra={name: "# notes\n  token " + SHAPED_DUMMY + "\n"})
    sha = subprocess.run(["git", "-C", str(m["root"]), "rev-parse", "HEAD"], check=True, capture_output=True,
                         text=True).stdout.strip()
    (m["root"] / name).unlink()
    assert not (m["root"] / "CLAUDE.md").exists()
    p = _dispatch(m, _env(**KEYED))
    refusal = _refusal(p)
    assert p.returncode == 2, p.stdout[-2000:]
    assert refusal and refusal[0].startswith("mission-dispatch: REFUSED -- AUTH-MODE-KEY-IN-FILE: "), p.stdout[-2000:]
    assert name + " as commit " + sha[:12] in refusal[0], refusal[0]
    assert _ran(m) == [], "a refused run spawned a seam: " + ", ".join(_ran(m))
    assert NOT_A_KEY not in p.stdout + p.stderr and SHAPED_DUMMY not in refusal[0]


def test_runner_admits_a_clean_tree_in_another_letter_case(tmp_path) -> None:
    """Read in any letter case, a clean claude.md and the subscription's own token in .Claude/settings.json change
    nothing: either mode's plan is the plan printed with the variable unset."""
    m, _sha = _mission_at_base(tmp_path, {"claude.md": "# notes\n", ".Claude/settings.json": '{\n  "env": { "CLAUDE_CODE_OAUTH_TOKEN": "x" }\n}\n'})
    bare = _dispatch(m, _env(), plan_only=True)
    sub = _dispatch(m, _env(**SUBSCRIPTION), plan_only=True)
    assert bare.returncode == sub.returncode == 0, sub.stdout[-2000:]
    assert sub.stdout == bare.stdout
    m2, _sha2 = _mission_at_base(tmp_path / "k", {"claude.md": "# notes\n"})
    bare2 = _dispatch(m2, _env(), plan_only=True)
    keyed = _dispatch(m2, _env(**KEYED), plan_only=True)
    assert bare2.returncode == keyed.returncode == 0, keyed.stdout[-2000:]
    assert keyed.stdout == bare2.stdout
    assert NOT_A_KEY not in keyed.stdout + keyed.stderr


def test_runner_admits_a_folder_named_like_a_memory_file(tmp_path) -> None:
    """A folder named CLAUDE.md is no file the CLI reads (S3's open decision 22): neither mode refuses it, and each
    prints the plan the unset selector prints."""
    m = _mission(tmp_path, extra={"CLAUDE.md/notes.txt": "# notes\n"})
    bare = _dispatch(m, _env(), plan_only=True)
    keyed = _dispatch(m, _env(**KEYED), plan_only=True)
    sub = _dispatch(m, _env(**SUBSCRIPTION), plan_only=True)
    assert bare.returncode == 0, bare.stdout[-2000:]
    assert keyed.returncode == 0 and keyed.stdout == bare.stdout, keyed.stdout[-2000:]
    assert sub.returncode == 0 and sub.stdout == bare.stdout, sub.stdout[-2000:]
    assert _ran(m) == []


def test_runner_under_subscription_reads_no_memory_file(tmp_path) -> None:
    """Under subscription the memory files are not scanned, so one git cannot read refuses nothing (S3's open decision
    22); key mode still refuses it AUTH-MODE-UNREADABLE (test_runner_refuses_a_commit_whose_root_file_git_cannot_read)."""
    m = _mission(tmp_path, extra={"CLAUDE.md": "# notes\n"})
    _drop_blob(m["root"], "CLAUDE.md")
    bare = _dispatch(m, _env(), plan_only=True)
    sub = _dispatch(m, _env(**SUBSCRIPTION), plan_only=True)
    assert bare.returncode == 0, bare.stdout[-2000:]
    assert sub.returncode == 0 and sub.stdout == bare.stdout, sub.stdout[-2000:]
    assert _ran(m) == []


@pytest.fixture(scope="module")
def lib_fold_answers(tmp_path_factory) -> dict:
    """The committed read over a commit that holds one name in two letter cases and two .claude folders -- made with
    git's plumbing, since a case-insensitive file system holds one of each -- and over a commit holding a folder and
    submodules at the CLI's names; each run in one child."""
    d = tmp_path_factory.mktemp("authfold")

    def committed(name: str, entries: list) -> tuple[Path, str]:
        repo = d / name
        _git(d, "init", "-q", str(repo))
        for k, v in (("user.name", "auth-mode-test"), ("user.email", "auth-mode-test@localhost"), ("core.autocrlf", "false")):
            _git(repo, "config", k, v)
        for i, (rel, mode, payload) in enumerate(entries):
            if mode == "100644":
                f = d / f"{name}-{i}.txt"
                f.write_bytes(payload.encode("utf-8"))
                payload = subprocess.run(["git", "-C", str(repo), "hash-object", "-w", "--", str(f)], check=True,
                                         capture_output=True, text=True).stdout.strip()
            _git(repo, "-c", "core.ignorecase=false", "update-index", "--add", "--cacheinfo", f"{mode},{payload},{rel}")
        tree = subprocess.run(["git", "-C", str(repo), "write-tree"], check=True, capture_output=True, text=True).stdout.strip()
        rev = subprocess.run(["git", "-C", str(repo), "commit-tree", tree, "-m", "seed"], check=True, capture_output=True,
                             text=True).stdout.strip()
        return repo, rev

    folded, folded_rev = committed("folded", [
        ("CLAUDE.md", "100644", "# notes\n"),
        ("claude.md", "100644", "# notes\n  token " + SHAPED_DUMMY + "\n"),
        (".Claude/settings.json", "100644", HELPER_SETTING),
        (".claude/settings.local.json", "100644", '{\n  "permissions": {}\n}\n'),
    ])
    other, other_rev = committed("other", [
        ("CLAUDE.md/notes.txt", "100644", "# notes\n"),
        (".mcp.json", "160000", "1" * 40),
        (".claude", "160000", "2" * 40),
    ])
    listed = subprocess.run(["git", "-C", str(folded), "ls-tree", "-r", "--name-only", folded_rev], check=True,
                            capture_output=True, text=True).stdout.splitlines()
    script = d / "drive.ps1"
    script.write_text(
        "param([string]$Lib, [string]$Repo, [string]$Rev, [string]$Other, [string]$OtherRev)\n"
        "$ErrorActionPreference = 'Stop'\n"
        ". $Lib\n"
        "function Say { param($Answer) [Console]::Out.WriteLine(($Answer | ConvertTo-Json -Compress)) }\n"
        "try {\n"
        "    $c = Get-LamAuthCommittedFiles -Repo $Repo -Rev $Rev\n"
        "    Say @{ label = 'keyed'; texts = @($c.texts.Keys); settings = @($c.settings.Keys) }\n"
        "    $copy = [ordered]@{ 'prompt' = 'nothing here' }\n"
        "    foreach ($k in @($c.texts.Keys)) { $copy[$k] = $c.texts[$k] }\n"
        "    $r = Test-LamAuthSpawnInputs -Texts $copy -SettingsTexts $c.settings\n"
        "    Say @{ label = 'keyed scan'; copied = $copy.Count; ok = $r.ok; code = $r.code; reason = $r.reason }\n"
        "} catch { Say @{ label = 'keyed'; threw = $_.Exception.Message } }\n"
        "try {\n"
        "    $s = Get-LamAuthCommittedFiles -Repo $Repo -Rev $Rev -Mode subscription\n"
        "    Say @{ label = 'subscription'; texts = @($s.texts.Keys); settings = @($s.settings.Keys) }\n"
        "    $r = Test-LamAuthSpawnInputs -Mode subscription -SettingsTexts $s.settings\n"
        "    Say @{ label = 'subscription scan'; ok = $r.ok; code = $r.code; reason = $r.reason }\n"
        "} catch { Say @{ label = 'subscription'; threw = $_.Exception.Message } }\n"
        "foreach ($mode in @('api-key', 'subscription')) {\n"
        "    try {\n"
        "        $n = Get-LamAuthCommittedFiles -Repo $Other -Rev $OtherRev -Mode $mode\n"
        "        Say @{ label = 'not files ' + $mode; texts = @($n.texts.Keys); settings = @($n.settings.Keys) }\n"
        "    } catch { Say @{ label = 'not files ' + $mode; threw = $_.Exception.Message } }\n"
        "}\n",
        encoding="utf-8",
    )
    p = _ps(script, _env(), "-Lib", str(LIB), "-Repo", str(folded), "-Rev", folded_rev, "-Other", str(other), "-OtherRev", other_rev)
    answers = {"_stdout": p.stdout, "_stderr": p.stderr, "_rev": folded_rev, "_listed": listed}
    for line in p.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            a = json.loads(line)
            answers[a["label"]] = a
    return answers


def test_library_reads_every_letter_case_a_commit_holds(lib_fold_answers) -> None:
    a = lib_fold_answers
    assert sorted(a["_listed"]) == sorted(["CLAUDE.md", "claude.md", ".Claude/settings.json", ".claude/settings.local.json"]), a["_listed"]
    keyed, scan = a.get("keyed"), a.get("keyed scan")
    assert keyed and "threw" not in keyed, a["_stdout"] + a["_stderr"][:600]
    assert [k.split(" ")[0] for k in keyed["texts"]] == ["CLAUDE.md", "claude.md"], keyed["texts"]
    assert [k.split(" ")[0] for k in keyed["settings"]] == [".Claude/settings.json", ".claude/settings.local.json"], keyed["settings"]
    assert all(a["_rev"][:12] in k for k in keyed["texts"] + keyed["settings"]), "each names the commit it was read from"
    assert scan and scan["copied"] == 3, "the runner's copy keeps both spellings' texts: " + str(scan)
    assert (scan["ok"], scan["code"]) == (False, "AUTH-MODE-KEY-IN-FILE") and "claude.md as commit" in scan["reason"], scan
    sub, sub_scan = a.get("subscription"), a.get("subscription scan")
    assert sub and "threw" not in sub, a["_stdout"]
    assert sub["texts"] == [], "under subscription no memory file is read: " + str(sub["texts"])
    assert [k.split(" ")[0] for k in sub["settings"]] == [".Claude/settings.json", ".claude/settings.local.json"], sub["settings"]
    assert sub_scan and (sub_scan["ok"], sub_scan["code"]) == (False, "AUTH-MODE-BOTH-CLAIMED") and ".Claude/settings.json" in sub_scan["reason"], sub_scan
    assert SHAPED_DUMMY not in a["_stdout"] and NOT_A_KEY not in a["_stdout"]


def test_library_passes_over_a_folder_or_submodule_at_a_cli_name(lib_fold_answers) -> None:
    for mode in ("api-key", "subscription"):
        n = lib_fold_answers.get("not files " + mode)
        assert n and "threw" not in n, lib_fold_answers["_stdout"] + lib_fold_answers["_stderr"][:600]
        assert n["texts"] == [] and n["settings"] == [], n


# ---------------------------------------------------------------------------------------------------------------------
# THE WAKE STARTER -- in library mode, as WP-3 C-4a drives it; the decision comes before anything else
# ---------------------------------------------------------------------------------------------------------------------
def _wake(tmp_path: Path, env: dict) -> subprocess.CompletedProcess:
    s = tmp_path / "wake.ps1"
    s.write_text(
        "param([string]$Wake, [string]$Root)\n. $Wake\n$r = Invoke-LamWakePrepare -MissionRoot $Root\n"
        "[Console]::Out.WriteLine('EXIT=' + $r.exit)\n",
        encoding="utf-8",
    )
    return _ps(s, env, "-Wake", str(WAKE), "-Root", str(tmp_path / "no-such-mission-root"))


@pytest.mark.parametrize("env_set,code", [
    ({"VANGUARD_AUTH_MODE": "api-key"}, "AUTH-MODE-KEY-ABSENT"),
    ({"VANGUARD_AUTH_MODE": "subscription", "ANTHROPIC_API_KEY": NOT_A_KEY}, "AUTH-MODE-BOTH-CLAIMED"),
    ({"VANGUARD_AUTH_MODE": "neither"}, "AUTH-MODE-UNKNOWN"),
], ids=["no key", "both claimed", "unknown"])
def test_wake_starter_refuses_first(tmp_path, env_set, code) -> None:
    p = _wake(tmp_path, _env(**env_set))
    lines = p.stdout.splitlines()
    assert f"lam-wake: REFUSED [{code}] " in p.stdout and "EXIT=2" in lines, p.stdout[-1500:]
    assert "lam-wake: nothing was written and no session was started." in lines
    assert NOT_A_KEY not in p.stdout + p.stderr


def test_wake_starter_with_the_selector_unset_refuses_as_it_did(tmp_path) -> None:
    p = _wake(tmp_path, _env(ANTHROPIC_API_KEY=NOT_A_KEY))
    assert "lam-wake: REFUSED [" in p.stdout and "AUTH-MODE" not in p.stdout and "EXIT=2" in p.stdout.splitlines()


# The wake starter's SCANS, after its argv is known: every step before the argv replaced by a stub (no CLI is looked
# up or started -- the stubbed flag check stands where `claude --help` runs), the real argv, the real scans and the real
# one write. Each case is read from a JSON file by its own child, so the shaped literal never stands on a command line.
_WAKE_DRIVE = (
    "param([string]$Wake, [string]$Case)\n"
    "$c = Get-Content -Raw -LiteralPath $Case | ConvertFrom-Json\n"
    ". $Wake\n"
    "function Resolve-LamWakeMissionRoot { param($MissionRoot) return $c.wt }\n"
    "function Resolve-LamWakeClaude { return 'C:\\no\\such\\claude.exe' }\n"
    "function Get-LamWakeArtifact { param($Root) return [pscustomobject]@{ name = 'wake-t.yaml'; batch = '1'; brief_source = $c.brief; worktree_path = $c.wt; head_sha = ('0' * 40); seat_name = $c.seat; model = 'opus'; effort = 'high' } }\n"
    "function Resolve-LamWakeBriefSource { param($Root, $BriefSource) return $BriefSource }\n"
    "function Get-LamWakeBriefSlice { param($Bytes) return $Bytes }\n"
    "function Assert-LamWakeWorktree { param($WorktreePath, $HeadSha, $Root) return $WorktreePath }\n"
    "function Assert-LamWakeClaudeFlags { param($ClaudePath) return '--effort -n --model' }\n"
    "function Assert-LamWakeEffort { param($ArtifactName, $Effort, $HelpText) return 'stubbed' }\n"
    "$r = Invoke-LamWakePrepare -MissionRoot $c.wt\n"
    "[Console]::Out.WriteLine('EXIT=' + $r.exit)\n"
)
WAKE_SCANS = [
    # (label, environment set, seat name, brief text, worktree files, expect refusal code or '')
    ("unset, clean", {}, "seat-a", "brief line\n", {}, ""),
    ("api-key, clean", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, "seat-a", "brief line\n", {}, ""),
    ("subscription, clean", {"VANGUARD_AUTH_MODE": "subscription"}, "seat-a", "brief line\n", {}, ""),
    ("api-key, a key-shaped seat name", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, SHAPED_DUMMY, "brief line\n", {}, "AUTH-MODE-KEY-IN-ARGUMENT"),
    ("api-key, a key-shaped value in the brief", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, "seat-a", "one\ntwo " + SHAPED_DUMMY + "\n", {}, "AUTH-MODE-KEY-IN-FILE"),
    ("api-key, a credential setting in the worktree", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, "seat-a", "brief line\n", {".claude\\settings.local.json": '{"apiKeyHelper": "x"}\n'}, "AUTH-MODE-KEY-IN-FILE"),
    ("api-key, a key-shaped value in the worktree's CLAUDE.md", {"VANGUARD_AUTH_MODE": "api-key", "ANTHROPIC_API_KEY": NOT_A_KEY}, "seat-a", "brief line\n", {"CLAUDE.md": "# notes\n" + SHAPED_DUMMY + "\n"}, "AUTH-MODE-KEY-IN-FILE"),
    ("subscription, a bearer token in the worktree's settings", {"VANGUARD_AUTH_MODE": "subscription"}, "seat-a", "brief line\n", {".claude\\settings.local.json": '{"env": {"ANTHROPIC_AUTH_TOKEN": "x"}}\n'}, "AUTH-MODE-BOTH-CLAIMED"),
    ("subscription, the subscription token in the worktree's settings", {"VANGUARD_AUTH_MODE": "subscription"}, "seat-a", "brief line\n", {".claude\\settings.local.json": '{"env": {"CLAUDE_CODE_OAUTH_TOKEN": "x"}}\n'}, ""),
]


@pytest.fixture(scope="module")
def wake_scans(tmp_path_factory) -> dict:
    d = tmp_path_factory.mktemp("wakescan")
    drive = d / "drive.ps1"
    drive.write_text(_WAKE_DRIVE, encoding="utf-8")
    out = {}
    for i, (label, env_set, seat, brief, files, _want) in enumerate(WAKE_SCANS):
        case_dir = d / f"case{i}"
        wt = case_dir / "wt"
        wt.mkdir(parents=True)
        for rel, text in files.items():
            (wt / rel).parent.mkdir(parents=True, exist_ok=True)
            (wt / rel).write_bytes(text.encode("utf-8"))
        bf = case_dir / "brief.md"
        bf.write_bytes(brief.encode("utf-8"))
        cf = case_dir / "case.json"
        cf.write_text(json.dumps({"wt": str(wt), "brief": str(bf), "seat": seat}), encoding="utf-8")
        p = _ps(drive, _env(**env_set), "-Wake", str(WAKE), "-Case", str(cf))
        out[label] = {"stdout": p.stdout, "stderr": p.stderr, "case_dir": str(case_dir),
                      "brief_written": (wt / ".wake-brief.md").exists()}
    return out


@pytest.mark.parametrize("case", WAKE_SCANS, ids=[c[0] for c in WAKE_SCANS])
def test_wake_starter_scans_the_seat_before_its_one_write(wake_scans, case) -> None:
    label, _env_set, _seat, _brief, _files, want = case
    r = wake_scans[label]
    lines = r["stdout"].splitlines()
    assert NOT_A_KEY not in r["stdout"] + r["stderr"] and SHAPED_DUMMY not in r["stdout"] + r["stderr"]
    if want:
        assert f"lam-wake: REFUSED [{want}] " in r["stdout"] and "EXIT=2" in lines, r["stdout"][-1500:]
        assert "lam-wake: nothing was written and no session was started." in lines
        assert not r["brief_written"], "a refused seat wrote its brief"
        assert "spawned" not in r["stdout"], "the reason claims nothing about what was started"
    else:
        assert "EXIT=0" in lines and r["brief_written"], r["stdout"][-1500:]


def test_wake_starter_in_either_mode_prints_what_it_prints_without_the_variable(wake_scans) -> None:
    """Nothing else changes: the plan a clean seat prints in key mode and in subscription mode is the unset plan,
    each case's own folder written as one token."""
    def plan(label: str) -> str:
        r = wake_scans[label]
        return r["stdout"].replace(r["case_dir"], "<case>")
    assert "lam-wake: argv[" in plan("unset, clean")
    assert plan("api-key, clean") == plan("unset, clean")
    assert plan("subscription, clean") == plan("unset, clean")
    assert plan("subscription, the subscription token in the worktree's settings") == plan("unset, clean")


# ---------------------------------------------------------------------------------------------------------------------
# THE WORKER-RUNNER'S DECISION -- env_scrub, in process, over environments handed to it
# ---------------------------------------------------------------------------------------------------------------------
def _env_scrub():
    spec = importlib.util.spec_from_file_location("env_scrub_under_test", REPO / "tools" / "worker-runner" / "env_scrub.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.mark.parametrize("case", LIB_CASES, ids=[c[0] for c in LIB_CASES])
def test_worker_runner_decides_alike(case) -> None:
    es = _env_scrub()
    _label, env_set, ok, mode, code, names = case
    if ok:
        assert es.resolve_auth_mode(dict(env_set)) == mode
    else:
        with pytest.raises(es.AuthModeRefused) as e:
            es.resolve_auth_mode(dict(env_set))
        assert e.value.code == code
        for n in names:
            assert n in e.value.reason
        assert NOT_A_KEY not in str(e.value) and SHAPED_DUMMY not in str(e.value)


def test_worker_runner_keeps_the_key_in_key_mode_only(monkeypatch) -> None:
    es = _env_scrub()
    monkeypatch.setenv("ANTHROPIC_API_KEY", NOT_A_KEY)
    monkeypatch.delenv("VANGUARD_AUTH_MODE", raising=False)
    assert "ANTHROPIC_API_KEY" not in es.build_scrubbed_env()
    monkeypatch.setenv("VANGUARD_AUTH_MODE", "subscription")
    assert "ANTHROPIC_API_KEY" not in es.build_scrubbed_env()
    monkeypatch.setenv("VANGUARD_AUTH_MODE", "api-key")
    assert es.build_scrubbed_env().get("ANTHROPIC_API_KEY") == NOT_A_KEY
    assert os.environ.get("ANTHROPIC_API_KEY") == NOT_A_KEY


def test_worker_runner_scan_names_where_never_what(tmp_path) -> None:
    es = _env_scrub()
    f = tmp_path / "brief.md"
    f.write_bytes(("a\nb\n" + SHAPED_DUMMY + "\n").encode("ascii"))
    s = tmp_path / "hook-settings.json"
    s.write_bytes(b'{"apiKeyHelper": "x"}\n')
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs(["-p", SHAPED_DUMMY])
    assert e.value.code == "AUTH-MODE-KEY-IN-ARGUMENT" and "argument 1" in e.value.reason
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs(["-p"], files=[f])
    assert e.value.code == "AUTH-MODE-KEY-IN-FILE" and str(f) in e.value.reason and "line 3" in e.value.reason
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs(["-p"], settings_files=[s])
    assert e.value.code == "AUTH-MODE-KEY-IN-FILE" and "apiKeyHelper" in e.value.reason
    es.check_spawn_inputs(["-p", NOT_A_KEY], texts={"prompt": "clean"}, files=[tmp_path / "absent"])
    assert SHAPED_DUMMY not in str(e.value)
    w = tmp_path / "wide.txt"
    w.write_bytes(("a\n" + SHAPED_DUMMY + "\n").encode("utf-16-le"))
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs(["-p"], files=[w])
    assert e.value.code == "AUTH-MODE-KEY-IN-FILE"
    o = tmp_path / "oauth.json"
    o.write_bytes(b'{"env": {"CLAUDE_CODE_OAUTH_TOKEN": "x"}}\n')
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs(["-p"], settings_files=[o])
    assert e.value.code == "AUTH-MODE-KEY-IN-FILE" and "CLAUDE_CODE_OAUTH_TOKEN" in e.value.reason
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs([SHAPED_DUMMY], settings_files=[s], mode="subscription")
    assert e.value.code == "AUTH-MODE-BOTH-CLAIMED" and "apiKeyHelper" in e.value.reason
    es.check_spawn_inputs([SHAPED_DUMMY], settings_files=[tmp_path / "absent"], mode="subscription")
    # the OAuth token is the subscription's own credential, not another one beside it
    es.check_spawn_inputs([], settings_files=[o], mode="subscription")
    for args, kw in ((["-p", SHAPED_DUMMY], {}), (["-p"], {"files": [f]}), (["-p"], {"settings_files": [s]}),
                     (["-p"], {"texts": {"prompt": SHAPED_DUMMY}})):
        with pytest.raises(es.AuthModeRefused) as e:
            es.check_spawn_inputs(args, **kw)
        assert "spawned" not in e.value.reason, "a scan's reason claims nothing about what its caller started"


def test_worker_runner_names_the_files_a_session_loads_at_its_root() -> None:
    es = _env_scrub()
    root = Path("C:/r")
    assert es.session_files(root) == [root / n.replace("\\", "/") for n in SESSION_FILES]


def test_worker_runner_names_the_files_a_session_loads_in_another_letter_case(tmp_path) -> None:
    """A worktree's root files and .claude settings spelled in another letter case are what the CLI
    opens on a case-insensitive file system. session_files() and settings_files() name each as it stands (compared as
    str: a WindowsPath compares equal across letter case), and the scan refuses a credential setting there in key mode
    and under subscription, naming it so."""
    es = _env_scrub()
    for rel, data in (("claude.md", b"# notes\n"), ("Claude.Local.md", b"# notes\n"), (".Claude/claude.md", b"# notes\n"),
                      (".MCP.json", b"{}\n"), (".Claude/Settings.json", b'{"apiKeyHelper": "x"}\n')):
        (tmp_path / rel).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / rel).write_bytes(data)
    names = [str(p) for p in es.session_files(tmp_path)]
    for rel in ("claude.md", "Claude.Local.md", ".Claude/claude.md", ".MCP.json"):
        assert str(tmp_path / rel) in names, (rel, names)
    s = tmp_path / ".Claude" / "Settings.json"
    settings = es.settings_files(tmp_path)
    assert str(s) in [str(p) for p in settings], settings
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs(["-p"], settings_files=settings)
    assert e.value.code == "AUTH-MODE-KEY-IN-FILE" and str(s) in e.value.reason, e.value.reason
    with pytest.raises(es.AuthModeRefused) as e:
        es.check_spawn_inputs([], settings_files=settings, mode="subscription")
    assert e.value.code == "AUTH-MODE-BOTH-CLAIMED" and str(s) in e.value.reason, e.value.reason


def test_every_test_starts_with_no_authentication_mode() -> None:
    """tools/conftest.py clears the mode and every credential variable for each test, whatever the shell running
    pytest holds -- so an operator who set VANGUARD_AUTH_MODE for the toolchain can still run the suite."""
    for name in CREDENTIALS:
        assert name not in os.environ, name
