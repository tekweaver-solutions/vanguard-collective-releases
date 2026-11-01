"""
fake-claude.py -- a stand-in for `claude` used by spawn tests in test_runner.py.

Emits a captured stream-json fixture to stdout when invoked, simulating
`claude -p --output-format stream-json --verbose ...`. Used in Option (ii)
test class (spawn tests) per the step-5 C3 design:
- Exercises real subprocess spawn + env propagation + stdio.
- Does NOT depend on the live `claude` binary.

Argv handling:
- `--debug` (anywhere in argv) enables stderr emission of DEBUG_ARGV
  and DEBUG_ENV lines. Spawn tests grep these to verify argv composition
  and env scrubbing (each found in review).
- The first argv token matching a known selector chooses the fixture:
    llm-only          -> sample-stream-llm-only.jsonl
    with-hook-allow   -> sample-stream-with-hook-events-allow.jsonl
    with-hook-deny    -> sample-stream-with-hook-events-deny.jsonl
- Other argv tokens (the runner's appended claude flags) are tolerated
  and surface verbatim in DEBUG_ARGV when --debug is set.
- No selector found -> exit 64 with usage to stderr.

Stream writes are flushed per line so the runner's async parser sees
realistic chunk-by-chunk arrival.

DEBUG_ARGV / DEBUG_ENV format (grep-friendly, structured):
    DEBUG_ARGV: ["...","..."]
    DEBUG_ENV: ANTHROPIC_API_KEY=<set>|<unset>   (presence only: a value is never printed)
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

_FIXTURE_DIR = Path(__file__).parent

_SELECTORS = {
    "llm-only": "sample-stream-llm-only.jsonl",
    "with-hook-allow": "sample-stream-with-hook-events-allow.jsonl",
    "with-hook-deny": "sample-stream-with-hook-events-deny.jsonl",
}

# Special-case selector that emits NO stream-json and exits non-zero with
# diagnostic text on stderr -- mirrors the real `claude -p` failure mode
# seen on a dispatch (exit 1, no assistant turns, only stderr).
# Used to exercise the synthesized-handoff persistence path. Distinguished
# from the fixture-driven selectors because no .jsonl file is read.
_ABORT_NO_STREAM_SELECTOR = "abort-no-stream"
_ABORT_NO_STREAM_STDERR = (
    "fake-claude: simulating no-stream abort\n"
    "fake-claude: this is the diagnostic that must round-trip into the "
    "synthesized handoff's issues_observed via subprocess_stderr.\n"
)
_ABORT_NO_STREAM_EXIT = 1

_DEBUG_FLAG = "--debug"


def _usage() -> None:
    print(
        f"usage: fake-claude.py [--debug] <selector> [other args...]\n"
        f"selectors: {', '.join(_SELECTORS)}",
        file=sys.stderr,
    )


def main() -> int:
    debug = _DEBUG_FLAG in sys.argv
    selector = None
    for arg in sys.argv[1:]:
        if arg == _ABORT_NO_STREAM_SELECTOR:
            selector = arg
            break
        if arg in _SELECTORS:
            selector = arg
            break

    if debug:
        print(f"DEBUG_ARGV: {json.dumps(sys.argv)}", file=sys.stderr, flush=True)
        print(
            f"DEBUG_ENV: ANTHROPIC_API_KEY={'<set>' if os.environ.get('ANTHROPIC_API_KEY') else '<unset>'}",
            file=sys.stderr,
            flush=True,
        )
        # Dump the appended-system-prompt body that ACTUALLY reaches the
        # subprocess. Read from --append-system-prompt-file <path> (the
        # current contract, post-Route-A fix) or --append-system-prompt
        # <value> (legacy / multi-line; for backward-compat probes). The
        # `DEBUG_APPEND_SP_BODY` channel closes the same coverage hole
        # the trigger fix's `DEBUG_STDIN` channel closed: existing tests
        # assert argv contents, not what survives the asyncio -> cmd.exe
        # /c transit on Windows. This dump lets the spawn-test seam
        # assert the FULL multi-line body reached the worker intact.
        append_sp_body = ""
        try:
            argv = sys.argv
            for i, a in enumerate(argv):
                if a == "--append-system-prompt-file" and i + 1 < len(argv):
                    fpath = argv[i + 1]
                    with open(fpath, "r", encoding="utf-8") as f:
                        append_sp_body = f.read()
                    break
                if a == "--append-system-prompt" and i + 1 < len(argv):
                    append_sp_body = argv[i + 1]
                    break
        except (OSError, ValueError) as e:
            append_sp_body = f"<DEBUG_APPEND_SP_BODY read failed: {e!r}>"
        print(
            f"DEBUG_APPEND_SP_BODY: {json.dumps(append_sp_body)}",
            file=sys.stderr,
            flush=True,
        )
        # Dump stdin to stderr so the spawn-test seam can observe what
        # the runner piped in (engagement trigger delivery). Read with
        # a non-blocking-then-eof pattern: if stdin is empty/closed
        # immediately we still emit the line (empty payload).
        try:
            stdin_bytes = sys.stdin.buffer.read()
        except (OSError, ValueError):
            stdin_bytes = b""
        # Emit on a single line with the JSON-escaped payload so the
        # newlines / quotes inside don't break the DEBUG_STDIN: prefix
        # the test parses on.
        print(
            f"DEBUG_STDIN: {json.dumps(stdin_bytes.decode('utf-8', errors='replace'))}",
            file=sys.stderr,
            flush=True,
        )

    if selector == _ABORT_NO_STREAM_SELECTOR:
        sys.stderr.write(_ABORT_NO_STREAM_STDERR)
        sys.stderr.flush()
        return _ABORT_NO_STREAM_EXIT

    if selector is None:
        _usage()
        return 64

    fixture_path = _FIXTURE_DIR / _SELECTORS[selector]
    with fixture_path.open("rb") as f:
        for line in f:
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
