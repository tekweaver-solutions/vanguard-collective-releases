"""
stream_json.py -- parser for Claude Code's --output-format stream-json output.

Newline-delimited JSON events emitted by `claude -p --output-format stream-json`.
Each line is one complete JSON object describing one runtime event (system/init,
rate_limit_event, assistant, user/tool_result, result, and -- with
--include-hook-events -- hook lifecycle events).

Real-world quirks the parser must handle:

1. **Chunk boundaries.** subprocess pipe reads may end mid-line; the parser
   buffers partial reads and splits on newlines.
2. **Trailing partial at EOF.** Some streams don't terminate with a final
   newline; the parser attempts to parse the trailing buffered content.
3. **Event ordering.** system/init is generally first, but rate_limit_event
   and assistant messages may interleave. Consumers must not assume order
   beyond what they explicitly observe.

Errors on malformed JSON surface as StreamJsonParseError; the runner decides
the response policy (typically: emit an error trace event + terminate the
dispatch).
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator


class StreamJsonParseError(RuntimeError):
    """Raised when a line in the stream fails JSON decoding."""


async def parse_stream(
    reader: asyncio.StreamReader,
    *,
    chunk_size: int = 4096,
) -> AsyncIterator[dict]:
    """Yield one parsed event dict per newline-delimited JSON object.

    Chunk-buffer: reads up to ``chunk_size`` bytes at a time and splits on
    newlines. Handles chunks that end mid-line; carries the leftover into
    the next iteration.

    EOF handling: if a trailing partial line is buffered when the reader
    closes, attempts to parse it (some claude -p invocations don't
    terminate stdout with a final newline).
    """
    buffer = b""
    while True:
        chunk = await reader.read(chunk_size)
        if not chunk:
            tail = buffer.strip()
            if tail:
                try:
                    yield json.loads(tail)
                except json.JSONDecodeError as e:
                    raise StreamJsonParseError(
                        f"Trailing partial line at EOF: {tail[:80]!r} ({e})"
                    ) from e
            return
        buffer += chunk
        while b"\n" in buffer:
            line, _, buffer = buffer.partition(b"\n")
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as e:
                raise StreamJsonParseError(
                    f"Malformed JSON line: {line[:80]!r} ({e})"
                ) from e


def parse_lines(lines: list[bytes]) -> list[dict]:
    """Synchronous helper: parse a list of complete JSON byte-lines into
    event dicts. Useful for unit tests against on-disk fixtures."""
    events: list[dict] = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        try:
            events.append(json.loads(ln))
        except json.JSONDecodeError as e:
            raise StreamJsonParseError(
                f"Malformed JSON line: {ln[:80]!r} ({e})"
            ) from e
    return events
