"""
Tests for claude_cli_safety.validate_claude_argv -- the ADR-014 CLI-flag seam.
"""

from __future__ import annotations

import pytest

from claude_cli_safety import validate_claude_argv


def test_clean_argv_passes() -> None:
    """Normal claude -p invocation with safe flags passes the validator."""
    validate_claude_argv(
        [
            "claude",
            "-p",
            "--output-format",
            "stream-json",
            "--settings",
            "/tmp/settings.json",
            "the prompt",
        ]
    )


def test_bare_flag_raises_with_adr_014_message() -> None:
    """--bare flag fails the validator with an ADR-014-citing message."""
    with pytest.raises(RuntimeError) as excinfo:
        validate_claude_argv(
            [
                "claude",
                "-p",
                "--bare",
                "--output-format",
                "stream-json",
                "the prompt",
            ]
        )
    msg = str(excinfo.value)
    assert "--bare" in msg
    assert "ADR-014" in msg
    assert "subscription" in msg


def test_bare_at_end_of_argv_still_caught() -> None:
    """Position-independent -- --bare at any argv position fails."""
    with pytest.raises(RuntimeError):
        validate_claude_argv(["claude", "-p", "prompt", "--bare"])


def test_substring_match_does_not_falsely_trip() -> None:
    """Membership is exact-token; a hypothetical legit flag like
    --barely-not-a-real-flag does NOT collide with --bare."""
    validate_claude_argv(
        ["claude", "-p", "--barely-not-a-real-flag", "prompt"]
    )


def test_empty_argv_passes() -> None:
    """Degenerate case: empty argv has no forbidden flags."""
    validate_claude_argv([])
