"""Pytest conftest: make hyphenated subpackage dirs importable in tests.

Until the framework moves to underscore-named dirs (the directory
layout reconciliation),
tests need to import modules from hyphenated subdirs like
`tools/worker-runner/`. This conftest injects each subdir into sys.path
so tests can do `from schemas import ...` without per-file sys.path
manipulation.

`validator_runner/` (F-002) is the first underscore-named package under
`tools/`; for it we add the `tools/` dir itself to sys.path so the
package can be imported as `validator_runner` (and run as
`python -m validator_runner.cli ...`).
"""

import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).parent

# Every test starts with no authentication mode and no
# credential variable in its environment, whatever the shell running pytest
# holds (an operator who set VANGUARD_AUTH_MODE for the toolchain, say); a
# test that needs one sets it itself. LAM-INSTALL.md section 7c.
_AUTH_VARIABLES = (
    "VANGUARD_AUTH_MODE", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
)


@pytest.fixture(autouse=True)
def _no_authentication_mode(monkeypatch):
    for name in _AUTH_VARIABLES:
        monkeypatch.delenv(name, raising=False)
    yield

for subdir in ("worker-runner", "tool-gateway", "worktree-manager"):
    sys.path.insert(0, str(_HERE / subdir))

# Underscore-named packages (importable as `<name>` from any pytest run
# rooted under tools/) live alongside the hyphenated ones; add the
# tools/ dir itself to sys.path so `import validator_runner` works.
sys.path.insert(0, str(_HERE))
