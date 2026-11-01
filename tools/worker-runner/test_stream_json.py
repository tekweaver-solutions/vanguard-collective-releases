"""
Tests for stream_json -- the Claude Code --output-format stream-json parser.

Coverage targets:
- Real-world fixture round-trip (sample-stream-llm-only.jsonl).
- Async parse_stream against an in-memory StreamReader fed in chunks.
- Chunk-boundary handling (chunk ends mid-line).
- Trailing partial line at EOF without newline.
- Malformed JSON raises StreamJsonParseError.
"""

from __future__ import annotations

import asyncio
from pathlib import Path

import pytest

from stream_json import StreamJsonParseError, parse_lines, parse_stream

FIXTURE_DIR = Path(__file__).parent / "fixtures"
LLM_ONLY_FIXTURE = FIXTURE_DIR / "sample-stream-llm-only.jsonl"


# ---------- sync helper tests ----------

def test_parse_lines_on_llm_only_fixture() -> None:
    """sync helper round-trips the 4 events in the redacted fixture."""
    with LLM_ONLY_FIXTURE.open("rb") as f:
        raw_lines = f.readlines()
    events = parse_lines(raw_lines)
    assert len(events) == 4
    types = [e.get("type") for e in events]
    # Exactly one of each:
    assert sorted(types) == sorted(["rate_limit_event", "system", "assistant", "result"])


def test_parse_lines_skips_blank_lines() -> None:
    """Blank lines between events are tolerated."""
    events = parse_lines(
        [
            b'{"type":"a"}',
            b"",
            b"   \n",
            b'{"type":"b"}',
        ]
    )
    assert [e["type"] for e in events] == ["a", "b"]


def test_parse_lines_raises_on_malformed() -> None:
    """Bad JSON raises StreamJsonParseError with the offending line excerpt."""
    with pytest.raises(StreamJsonParseError) as excinfo:
        parse_lines([b'{"type":"a"}', b"not-json"])
    assert "not-json" in str(excinfo.value)


# ---------- async parse_stream tests ----------

class _FakeReader:
    """Minimal stand-in for asyncio.StreamReader that yields preset chunks."""

    def __init__(self, chunks: list[bytes]) -> None:
        self._chunks = list(chunks)

    async def read(self, n: int) -> bytes:
        if not self._chunks:
            return b""
        chunk = self._chunks.pop(0)
        # Honor the requested size by splitting oversized chunks back.
        if len(chunk) > n:
            self._chunks.insert(0, chunk[n:])
            return chunk[:n]
        return chunk


async def _collect(reader, **kwargs) -> list[dict]:
    out = []
    async for evt in parse_stream(reader, **kwargs):
        out.append(evt)
    return out


@pytest.mark.asyncio
async def test_parse_stream_single_chunk_complete_lines() -> None:
    """Two events in one chunk, properly newline-delimited."""
    reader = _FakeReader([b'{"type":"a"}\n{"type":"b"}\n'])
    events = await _collect(reader)
    assert [e["type"] for e in events] == ["a", "b"]


@pytest.mark.asyncio
async def test_parse_stream_chunk_ends_mid_line() -> None:
    """Chunk boundary in the middle of a JSON object -- buffer + resume."""
    reader = _FakeReader(
        [
            b'{"type":"a","value":12',
            b'34}\n{"type":"b"}\n',
        ]
    )
    events = await _collect(reader)
    assert events == [{"type": "a", "value": 1234}, {"type": "b"}]


@pytest.mark.asyncio
async def test_parse_stream_chunk_ends_inside_string() -> None:
    """Chunk boundary inside a JSON string with no newlines yet."""
    reader = _FakeReader(
        [
            b'{"msg":"hello ',
            b'world"}\n',
        ]
    )
    events = await _collect(reader)
    assert events == [{"msg": "hello world"}]


@pytest.mark.asyncio
async def test_parse_stream_trailing_partial_no_final_newline() -> None:
    """EOF without a trailing newline: parser parses the buffered tail."""
    reader = _FakeReader([b'{"type":"a"}\n{"type":"b"}'])
    events = await _collect(reader)
    assert [e["type"] for e in events] == ["a", "b"]


@pytest.mark.asyncio
async def test_parse_stream_empty_stream() -> None:
    """Empty stream yields no events."""
    reader = _FakeReader([])
    events = await _collect(reader)
    assert events == []


@pytest.mark.asyncio
async def test_parse_stream_skips_blank_lines() -> None:
    """Multiple newlines / blank lines between events are tolerated."""
    reader = _FakeReader([b'{"type":"a"}\n\n\n{"type":"b"}\n'])
    events = await _collect(reader)
    assert [e["type"] for e in events] == ["a", "b"]


@pytest.mark.asyncio
async def test_parse_stream_raises_on_malformed() -> None:
    """Malformed JSON line raises StreamJsonParseError."""
    reader = _FakeReader([b'{"type":"a"}\nnot-json\n'])
    with pytest.raises(StreamJsonParseError) as excinfo:
        await _collect(reader)
    assert "not-json" in str(excinfo.value)


@pytest.mark.asyncio
async def test_parse_stream_tiny_chunk_size_handles_big_event() -> None:
    """Small chunk_size forces many partial reads; parser still recovers
    a multi-KB event from the fixture."""
    # Read the real fixture bytes and feed them in 64-byte chunks.
    with LLM_ONLY_FIXTURE.open("rb") as f:
        raw = f.read()
    # Split into bite-sized chunks
    n = 64
    chunks = [raw[i : i + n] for i in range(0, len(raw), n)]
    reader = _FakeReader(chunks)
    events = await _collect(reader, chunk_size=n)
    assert len(events) == 4
    assert {e.get("type") for e in events} == {
        "rate_limit_event",
        "system",
        "assistant",
        "result",
    }
