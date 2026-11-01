"""
env_scrub.py -- build a child-process environment with framework-forbidden
variables removed.

Per ADR-014: the worker-runner shells out to `claude -p` under the
operator's Pro/Max OAuth subscription. If `ANTHROPIC_API_KEY` is set in
the child environment, Claude Code silently switches its auth posture
to API-key billing -- bypassing the subscription and charging the
operator's API account. This is the precise failure mode ADR-014
defends against. (It is the default; VANGUARD_AUTH_MODE=api-key selects
the key instead -- THE API-KEY MODE, below, and LAM-INSTALL.md section 7c.)
The scrub removes ANTHROPIC_API_KEY and nothing else: a bearer token
(ANTHROPIC_AUTH_TOKEN, CLAUDE_CODE_OAUTH_TOKEN) or a cloud-provider selector
(CLAUDE_CODE_USE_BEDROCK, _VERTEX, _FOUNDRY) left in the environment is
handed to the child and picked by Claude Code's own precedence before the
subscription it is signed in with. Only this worker-runner path removes the key; the LAM runner
and wake starter remove nothing with the mode unset.

`build_scrubbed_env()` is the seam through which every subprocess
spawned by the worker-runner machinery should receive its environment.
The function returns a COPY of `os.environ` with framework-forbidden
variables removed; it does NOT mutate `os.environ`. The latter
invariant is asserted in test_env_scrub.py because a naive
implementation (`os.environ.pop(...); return dict(os.environ)`) passes
the child-subprocess test but corrupts the parent's environment for
the rest of the session.

Deny-list discipline: scrub ONLY what the framework is invariantly
forbidden from inheriting. The list is deliberately minimal -- one
variable at v1. By the operator's decision: do not preemptively
add `OPENAI_API_KEY` (framework doesn't invoke), `AWS_*` (product-level
concern; workers may need), `GITHUB_TOKEN`/`GH_TOKEN` (github MCP needs),
or `POSTMAN_API_KEY` (postman MCP needs). Additions to this
list go through an amendment when a new invariant is discovered, not
preemptively.

THE API-KEY MODE. The scrub above is the default: with
`VANGUARD_AUTH_MODE` unset or empty it removes the key and nothing else
here changes or is checked, so the child uses the subscription only when no
bearer token or cloud-provider selector is in the environment either;
`VANGUARD_AUTH_MODE=subscription` refuses ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN
and the selectors (resolve_auth_mode). `VANGUARD_AUTH_MODE=api-key` selects the
key instead: the child keeps `ANTHROPIC_API_KEY`, which print mode uses whenever it is
present, and nothing else changes. `resolve_auth_mode()` decides the mode
and `check_spawn_inputs()` holds a key-mode spawn's arguments, the files
it hands the CLI and those the CLI loads at its root (`session_files()`)
to carrying no key-shaped value -- the key travels in the child's
environment only. Both are the decision tools/lam/lam-auth-mode.ps1 takes
for the LAM toolchain, with its codes; a reason names what was refused,
never what was or was not started.
CONTENT-BLIND: a credential variable is read for whether it is set and
not empty; its value is never printed, logged, compared or hashed, and a
refusal names an argument by its index and a file by its path and line.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Final, Iterable, Mapping, Optional

_DENY_LIST: Final[tuple[str, ...]] = (
    "ANTHROPIC_API_KEY",
)

AUTH_MODE_VAR: Final[str] = "VANGUARD_AUTH_MODE"
API_KEY_VAR: Final[str] = "ANTHROPIC_API_KEY"
_KEY_SHAPE: Final = re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")
# Beside a key: a bearer token and a cloud-provider selector are used BEFORE
# ANTHROPIC_API_KEY, and the OAuth token is a subscription's. Beside the
# subscription: each of these is used before it in print mode.
_BESIDE_KEY: Final[tuple[str, ...]] = (
    "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
)
_BESIDE_SUBSCRIPTION: Final[tuple[str, ...]] = (
    "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
)
_SETTING_NAMES: Final[tuple[str, ...]] = (
    "apiKeyHelper", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
)
# Under subscription a settings file may name the subscription's own OAuth
# token; every other credential setting is one print mode would use instead.
_SUBSCRIPTION_SETTING_NAMES: Final[tuple[str, ...]] = tuple(n for n in _SETTING_NAMES if n != "CLAUDE_CODE_OAUTH_TOKEN")
# The files the CLI reads by itself at the root of the tree it runs in when a
# session starts: its memory files and its project MCP configuration. A parent
# folder's and the user's own are outside what a spawn hands it.
_SESSION_FILE_NAMES: Final[tuple[str, ...]] = ("CLAUDE.md", "CLAUDE.local.md", ".claude/CLAUDE.md", ".mcp.json")
# The project settings the CLI loads from that root.
_SETTINGS_FILE_NAMES: Final[tuple[str, ...]] = (".claude/settings.json", ".claude/settings.local.json")


class AuthModeRefused(RuntimeError):
    """A spawn the authentication mode refuses; `code` is AUTH-MODE-<...>."""

    def __init__(self, code: str, reason: str) -> None:
        super().__init__(f"{code}: {reason}")
        self.code = code
        self.reason = reason


def _is_set(environ: Mapping[str, str], name: str) -> bool:
    # Set and not empty -- nothing else is asked of a credential variable.
    return bool(environ.get(name))


def resolve_auth_mode(environ: Optional[Mapping[str, str]] = None) -> str:
    """The mode VANGUARD_AUTH_MODE selects: '' (unset or empty -- nothing
    changes), 'api-key' or 'subscription'. Raises AuthModeRefused with
    AUTH-MODE-UNKNOWN, AUTH-MODE-KEY-ABSENT or AUTH-MODE-BOTH-CLAIMED."""
    env = os.environ if environ is None else environ
    selector = env.get(AUTH_MODE_VAR) or ""
    if not selector:
        return ""
    if selector == "api-key":
        if not _is_set(env, API_KEY_VAR):
            raise AuthModeRefused(
                "AUTH-MODE-KEY-ABSENT",
                "VANGUARD_AUTH_MODE is api-key and ANTHROPIC_API_KEY is not set or is empty. "
                "Set ANTHROPIC_API_KEY in the environment of the shell that runs this -- never in a "
                "file or an argument -- or unset VANGUARD_AUTH_MODE for the Claude subscription.",
            )
        beside = [n for n in _BESIDE_KEY if _is_set(env, n)]
        if beside:
            raise AuthModeRefused(
                "AUTH-MODE-BOTH-CLAIMED",
                f"VANGUARD_AUTH_MODE is api-key and {', '.join(beside)} is set too: the CLI would use "
                "that instead of the key, or beside it. Unset it for key mode.",
            )
        return "api-key"
    if selector == "subscription":
        beside = [n for n in _BESIDE_SUBSCRIPTION if _is_set(env, n)]
        if beside:
            raise AuthModeRefused(
                "AUTH-MODE-BOTH-CLAIMED",
                f"VANGUARD_AUTH_MODE is subscription and {', '.join(beside)} is set: the two claims "
                "contradict each other (this path removes ANTHROPIC_API_KEY from the CLI's environment, "
                "but print mode would use a bearer token or a cloud-provider selector instead of the "
                "subscription). Unset it, or set VANGUARD_AUTH_MODE to api-key.",
            )
        return "subscription"
    raise AuthModeRefused(
        "AUTH-MODE-UNKNOWN",
        "VANGUARD_AUTH_MODE is set to a value that is neither api-key nor subscription (the value "
        "is not shown). Set one of the two, or unset it for the Claude subscription.",
    )


def _shape_line(text: str) -> int:
    # The 1-based line of the first key-shaped value; 0 where none stands. The match is not kept.
    m = _KEY_SHAPE.search(text)
    return 0 if m is None else text.count("\n", 0, m.start()) + 1


def _file_text(p: Path) -> str:
    # NUL bytes dropped, one character a byte: an ASCII shape shows through
    # UTF-8, ANSI and UTF-16 alike.
    return p.read_bytes().replace(b"\x00", b"").decode("latin-1")


def _named(folder: Path, name: str) -> list[Path]:
    # Every entry of `folder` whose name is `name` but for ASCII letter case,
    # as it stands, in name order -- what a case-insensitive file system opens
    # under `name` (it folds no other letter onto these ASCII names); none
    # where `folder` is absent or no folder. Any other error is raised.
    try:
        names = os.listdir(folder)
    except (FileNotFoundError, NotADirectoryError):
        return []
    want = name.lower()
    return [Path(folder) / n for n in sorted(names) if n.isascii() and n.lower() == want]


def _tree_files(root: Path, rels: Iterable[str]) -> list[Path]:
    # Each of `rels` under `root`: every entry its path names
    # but for letter case, as it stands, then the path in the CLI's own
    # spelling where no entry is spelled so -- whatever the file system itself
    # opens under that name is still read.
    root = Path(root)
    out: list[Path] = []
    for rel in rels:
        *dirs, leaf = rel.split("/")
        folders = [root]
        for d in dirs:
            folders = [e for f in folders for e in _named(f, d) if e.is_dir()]
        found = [e for f in folders for e in _named(f, leaf)]
        own = root.joinpath(*dirs, leaf)
        out += found + ([] if str(own) in {str(e) for e in found} else [own])
    return out


def session_files(root: Path) -> list[Path]:
    """The session files of the tree rooted at `root`: every entry of the root
    and of its .claude folder whose name is a session file's but for letter
    case, as it stands, then each in the CLI's own spelling; whether each
    exists is the scan's to see."""
    return _tree_files(root, _SESSION_FILE_NAMES)


def settings_files(root: Path) -> list[Path]:
    """The .claude settings of the tree rooted at `root`, found as
    session_files() finds its files."""
    return _tree_files(root, _SETTINGS_FILE_NAMES)


def check_spawn_inputs(
    arguments: Iterable[str],
    texts: Optional[Mapping[str, str]] = None,
    files: Iterable[Path] = (),
    settings_files: Iterable[Path] = (),
    mode: str = "api-key",
) -> None:
    """mode 'api-key' (the default): no argument of the spawn and no file it
    hands the CLI carries a key-shaped value, and no settings file names a
    credential setting -- AUTH-MODE-KEY-IN-ARGUMENT, AUTH-MODE-KEY-IN-FILE.
    mode 'subscription': only the settings files are read, and a credential
    setting (the subscription's own OAuth token excepted) or a key-shaped
    value in one is AUTH-MODE-BOTH-CLAIMED. Raises AuthModeRefused. A file
    that is not there is skipped."""
    if mode == "subscription":
        for f in settings_files:
            p = Path(f)
            if not p.is_file():
                continue
            text = _file_text(p)
            named = [n for n in _SUBSCRIPTION_SETTING_NAMES if f'"{n}"' in text]
            if named or _KEY_SHAPE.search(text):
                what = f"names the credential setting {named[0]}" if named else "carries a key-shaped value (not shown)"
                raise AuthModeRefused(
                    "AUTH-MODE-BOTH-CLAIMED",
                    f"{p} {what}, and the session loads that settings file: with VANGUARD_AUTH_MODE="
                    "subscription the CLI would use it instead of the subscription. Remove it, or set "
                    "VANGUARD_AUTH_MODE to api-key.",
                )
        return
    for i, arg in enumerate(arguments):
        if _KEY_SHAPE.search(str(arg)):
            raise AuthModeRefused(
                "AUTH-MODE-KEY-IN-ARGUMENT",
                f"argument {i} of the spawn carries a key-shaped value (not shown). In key mode the "
                "key travels in the environment only.",
            )
    for what, text in (texts or {}).items():
        line = _shape_line(text)
        if line:
            raise AuthModeRefused(
                "AUTH-MODE-KEY-IN-FILE",
                f"the {what} carries a key-shaped value at its line {line} (not shown). In key mode "
                "the key travels in the environment only.",
            )
    for f in files:
        p = Path(f)
        if not p.is_file():
            continue
        line = _shape_line(_file_text(p))
        if line:
            raise AuthModeRefused(
                "AUTH-MODE-KEY-IN-FILE",
                f"{p} carries a key-shaped value at its line {line} (not shown), and the CLI would "
                "read that file. In key mode the key travels in the environment only.",
            )
    for f in settings_files:
        p = Path(f)
        if not p.is_file():
            continue
        text = _file_text(p)
        for name in _SETTING_NAMES:
            if f'"{name}"' in text:
                raise AuthModeRefused(
                    "AUTH-MODE-KEY-IN-FILE",
                    f"{p} names the credential setting {name}, and the CLI would load that settings "
                    "file. In key mode the key travels in the environment only.",
                )


def build_scrubbed_env() -> dict[str, str]:
    """Return a child-process environment with framework-forbidden vars removed.

    Returns a COPY of `os.environ`. Does NOT mutate `os.environ`; safe to
    call from any process without side effects on the parent's environment.
    In key mode (VANGUARD_AUTH_MODE=api-key, decided by resolve_auth_mode
    before the spawn) ANTHROPIC_API_KEY is the one variable kept.

    Usage:
        scrubbed = build_scrubbed_env()
        subprocess.run([...], env=scrubbed)
    """
    scrubbed = dict(os.environ)
    keep_key = os.environ.get(AUTH_MODE_VAR) == "api-key"
    for var in _DENY_LIST:
        if keep_key and var == API_KEY_VAR:
            continue
        scrubbed.pop(var, None)
    return scrubbed
