"""
Tests for env_scrub.build_scrubbed_env -- the ADR-014 invariant seam.

Three test surfaces:
  1. The returned dict does not contain ANTHROPIC_API_KEY.
  2. The PARENT's os.environ is NOT mutated. This catches the naive
     `os.environ.pop(...); return dict(os.environ)` regression that
     passes the child-subprocess test but breaks the parent's env
     for the rest of the session (operator-named guardrail
     2026-05-29).
  3. A spawned child subprocess sees the variable as ABSENT. End-to-end
     proof that the env passed through `subprocess.run(..., env=...)`
     does not leak the variable.
"""

from __future__ import annotations

import os
import subprocess
import sys
from collections.abc import Iterator

import pytest

from env_scrub import build_scrubbed_env

SENTINEL = "DEFINITELY_NOT_REAL_TEST_VALUE"


@pytest.fixture
def anthropic_key_set(monkeypatch: pytest.MonkeyPatch) -> Iterator[str]:
    """Set ANTHROPIC_API_KEY to a sentinel for the duration of the test.
    monkeypatch auto-restores os.environ on teardown."""
    monkeypatch.setenv("ANTHROPIC_API_KEY", SENTINEL)
    yield SENTINEL


def test_scrubbed_env_excludes_anthropic_api_key(anthropic_key_set: str) -> None:
    """The returned dict must not contain ANTHROPIC_API_KEY."""
    scrubbed = build_scrubbed_env()
    assert "ANTHROPIC_API_KEY" not in scrubbed


def test_scrubbed_env_does_not_mutate_parent(anthropic_key_set: str) -> None:
    """Operator-named guardrail: build_scrubbed_env must NOT mutate
    os.environ. The naive implementation
    (os.environ.pop('ANTHROPIC_API_KEY', None); return dict(os.environ))
    passes the child-subprocess test but breaks the parent's env for the
    rest of the session. This assertion catches that regression."""
    _ = build_scrubbed_env()
    assert os.environ.get("ANTHROPIC_API_KEY") == SENTINEL


def test_child_subprocess_sees_no_anthropic_api_key(anthropic_key_set: str) -> None:
    """End-to-end: spawn a child with the scrubbed env; child reports ABSENT.

    On Windows, `subprocess.run(env=...)` replaces the child env entirely
    (does not merge with the parent's). The scrubbed dict starts from
    `dict(os.environ)` so SystemRoot/PATH/etc. are preserved; only
    ANTHROPIC_API_KEY is removed.
    """
    scrubbed = build_scrubbed_env()
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            "import os; print(os.environ.get('ANTHROPIC_API_KEY', 'ABSENT'))",
        ],
        env=scrubbed,
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout.strip() == "ABSENT"
