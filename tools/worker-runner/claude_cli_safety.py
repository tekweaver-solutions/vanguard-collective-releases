"""
claude_cli_safety.py -- structural guard against forbidden Claude Code
CLI flags that would violate ADR-014's subscription-auth invariant.

ADR-014 requires the worker-runner to invoke `claude -p` under the
operator's Pro/Max OAuth subscription. Two complementary seams enforce
this:

1. **Environment seam** (env_scrub.build_scrubbed_env): strips
   ANTHROPIC_API_KEY from the child env. Even if the variable leaks
   via the operator's shell rc, system env, or parent shell, the
   child subprocess does not see it. (In the API-key mode the
   operator selects with VANGUARD_AUTH_MODE=api-key it keeps the key
   instead -- LAM-INSTALL.md section 7c; --bare stays refused.)

2. **CLI flag seam** (this module): blocks invocation with flags
   that would force Claude Code's auth posture to API-key billing
   regardless of env. The canonical example is `--bare`, which per
   claude's own help text "sets CLAUDE_CODE_SIMPLE=1. Anthropic auth
   is strictly ANTHROPIC_API_KEY or apiKeyHelper via --settings (OAuth
   and keychain are never read)" -- bypassing the OAuth keychain the
   subscription depends on.

Both seams enforce the same ADR-014 invariant. The runner runs both
checks before spawning the subprocess; either failure stops the
dispatch with a clear error.

Extending the deny-list: when a future Claude Code version adds a new
flag that would bypass subscription auth, add it to
_FORBIDDEN_CLI_FLAGS with an inline comment naming the version that
introduced it. Same amendment-driven growth pattern as env_scrub's
_DENY_LIST.
"""

from __future__ import annotations

from typing import Final

_FORBIDDEN_CLI_FLAGS: Final[frozenset[str]] = frozenset(
    {
        # --bare forces ANTHROPIC_API_KEY / apiKeyHelper auth regardless
        # of env_scrub's removal of ANTHROPIC_API_KEY from the child env:
        # if apiKeyHelper is configured (which it may be operator-wide for
        # other purposes), --bare flips the auth posture even with the
        # env var scrubbed. Block outright. Discovered during step-5 CLI
        # verification 2026-05-29 against claude v2.1.123.
        "--bare",
    }
)


def validate_claude_argv(argv: list[str]) -> None:
    """Raise RuntimeError if argv contains any forbidden CLI flag.

    Run before subprocess spawn. Belt-and-braces with env_scrub:
    env_scrub guards the env-var seam; this guards the flag seam.
    Both must pass before the child process starts.
    """
    for flag in _FORBIDDEN_CLI_FLAGS:
        if flag in argv:
            raise RuntimeError(
                f"Forbidden CLI flag {flag!r} in argv (per ADR-014). "
                f"This flag would flip Claude Code's auth posture to "
                f"API-key billing, bypassing the subscription."
            )
