# worker-runner test fixtures

Stream-json captures from real `claude -p` invocations and PreToolUse
hook stdin payloads, redacted for portability across operators. Each
file lands with explicit provenance in this README.

## Canonical placeholder vocabulary

When redacting future captures, use these placeholders. The vocabulary
is fixed; new categories require an addition here first.

| Placeholder | Category | Replaces |
|---|---|---|
| `<WORKER_CWD>` | path | The worker's `cwd` at runtime (`cwd` field on `system/init`). |
| `<WORKER_FILE>` | path | Any expanded `%USERPROFILE%\...`-shaped path in tool inputs, hook stdin, etc. Generic operator-portable substitute. |
| `<OPERATOR_MEMORY_PATH>` | path | Anything under `memory_paths.*` in `system/init`. Operator-specific Claude Code memory store. |
| `<TRANSCRIPT_PATH>` | path | The `transcript_path` field on hook stdin (operator-specific path to the claude session transcript JSONL). |
| `<HOOK_PYTHON_EXE>` | path | Absolute path to the framework venv Python interpreter inside hook `command` fields and rendered command strings. |
| `<HOOK_SCRIPT>` | path | Absolute path to the hook script inside hook `command` fields and rendered command strings. |
| `<CLAUDE_CODE_EXECPATH>` | path | Operator-specific path to `claude.exe` (CLAUDE_CODE_EXECPATH env var) -- reserved; not yet used in committed fixtures. |
| `00000000-0000-4000-8000-000000000000` | id | All `session_id` occurrences. Same placeholder UUID across all events of one capture for cross-event referential integrity. |
| `9999999999` | timestamp | `rate_limit_info.resetsAt` -- sentinel that avoids implying when the fixture was captured. |
| `<project>` | name | The host project's own name wherever a capture quotes it (e.g. the first line of its README in a `Read` result). |

**Capture-time random identifiers KEPT verbatim:** per-event `uuid`, `hook_id`,
`tool_use_id`, Claude message `id` (`msg_...`). These are non-sensitive,
randomly-generated per-invocation, and useful for testing fixture
round-trip integrity.

**Subscription-auth evidence KEPT verbatim:** `apiKeySource: "none"` in
`system/init` is the ADR-014-compliance indicator; future readers see what
a properly-configured subscription run looks like.

**Cross-version evidence KEPT verbatim:** `claude_code_version: "2.1.123"`
is the canonical record of which Claude Code version produced the fixture.

## Credential-pattern scan (applied to every fixture pre-commit)

Belt-and-braces scan per the credential-hygiene discipline. All fixtures must
pass with `clean` before commit.

| Pattern | Source |
|---|---|
| `PMAK-[A-Za-z0-9]+` | Postman API keys |
| `ANTHROPIC_API_KEY[=:][^,}"\s]+` | Anthropic API key assignments |
| `gh[_p]_[A-Za-z0-9]{20,}` | GitHub tokens (gh_ / ghp_) |
| `AKIA[0-9A-Z]{16}` | AWS access keys |
| `sk-[A-Za-z0-9]{20,}` | OpenAI-style API keys |
| the operator's own expanded `%USERPROFILE%` path (any case) | Unredacted operator-specific path |
| `mcp__claude_ai_` | Unredacted personal-connector tool/slash-command |

## Fixture files

### `sample-stream-llm-only.jsonl`

Captured 2026-05-29 from claude v2.1.123. Four events
(`system/init`, `rate_limit_event`, `assistant`, `result`) from a
no-tool-call invocation. Used by `test_stream_json.py` for parser
round-trip + chunk-boundary tests.

Capture command:
```
claude -p "What is 2 + 2? Respond with exactly the digit." \
    --output-format stream-json \
    --no-session-persistence \
    --verbose
```

Redactions per the canonical vocabulary above; cred scan: clean.

### `sample-stream-with-hook-events-allow.jsonl`

Captured 2026-05-29 from claude v2.1.123 with `--include-hook-events`
and a PreToolUse hook configured. Nine events including
`system/hook_started` + `system/hook_response` (exit_code=0).
Demonstrates the **allow** path of gateway-hook integration.

Capture command (paraphrased; settings path varies per operator):
```
claude -p "Read README.md and tell me only its first line." \
    --output-format stream-json --verbose \
    --no-session-persistence \
    --include-hook-events \
    --settings <path-to-allow-hook-settings.json> \
    --permission-mode acceptEdits
```

Used by `test_gateway_hook.py` + `test_hook_config.py` for hook protocol
fidelity tests.

### `sample-stream-with-hook-events-deny.jsonl`

Captured 2026-05-29 from claude v2.1.123 with the same hook configuration
but the hook exits with code 2 (denial). Nine events; demonstrates:
- `hook_response.exit_code=2` + `outcome=error` + `stderr` carrying the denial reason.
- `user/tool_result` with `is_error=True` and content prefixed `"PreToolUse:<ToolName> hook error: ..."`.
- Terminal `result.permission_denials` array populated with `{tool_name, tool_use_id, tool_input}`.

The **canonical denial signal for the runner** is `system/hook_response`
(closest to source). The `tool_result` and terminal `permission_denials`
are downstream re-encodings; they cross-check but do not override.

### `hook-stdin-allow.jsonl`

The exact JSON payload the PreToolUse hook receives via stdin during
the allow-path capture. One record. Canonical PreToolUse stdin shape per
claude v2.1.123:

```json
{
  "session_id": "<uuid>",
  "transcript_path": "<path>",
  "cwd": "<path>",
  "permission_mode": "default|auto|bypassPermissions|acceptEdits|dontAsk|plan",
  "hook_event_name": "PreToolUse",
  "tool_name": "<ToolName>",
  "tool_input": <tool-specific object>,
  "tool_use_id": "<id>"
}
```

The capture record also stores `argv` (the hook script's argv) and an
`env_subset` containing `CLAUDE*` and `HOOK*` env vars Claude Code exposes
to hooks.

### `hook-stdin-deny.jsonl`

Same shape as `hook-stdin-allow.jsonl` from the deny-path capture. One
record. The stdin payload is structurally identical to the allow case;
the difference is in the hook script's exit code, not its input.

### `sample-handoff.json`

Synthetic valid §5 Handoff document, hand-authored 2026-05-30 for
test_runner.py's happy-path validation test. NOT captured from a
real worker; constructed to satisfy every §5 schema constraint
(status/error consistency, unfinished-vs-completed,
deviation_notes-vs-procedure_adherence, git-SHA shape on commits).

Used by `test_handoff_validation_from_disk_happy_path` to verify
`Handoff.model_validate_json(...)` accepts a structurally clean
worker handoff.

Operator-portable values:
- id, dispatch_id, worker id: synthetic UUIDs/strings.
- commits: empty (no SHA shape to validate without a real worktree).
- feature_id: "F-001", a `<project>` spec feature.

### `sample-handoff-malformed.json`

Synthetic §5-invalid Handoff, hand-authored 2026-05-30. Missing the
required `from_worker` field; Pydantic raises ValidationError on
parse.

Used by `test_handoff_validation_rejects_malformed` to verify the
runner's `_validate_handoff_from_disk` propagates schema errors
rather than silently coercing.

Operator-portable values: same shape as `sample-handoff.json` minus
the `from_worker` key.

## fake-claude.py

Stand-in for the live `claude` binary in spawn tests (the fake-binary
option of the spawn-test design). Emits a captured fixture to stdout when
invoked; supports a `--debug` flag that emits structured DEBUG_ARGV
and DEBUG_ENV lines to stderr (used by tests to assert argv
composition + env scrubbing).

See the file header for full usage. Used only by `test_runner.py`'s
spawn tests; not part of production code.

## Future siblings (anticipated)

- `sample-stream-with-multiple-tool-calls.jsonl` -- a richer dispatch
  exercising several distinct tools. Lands when runner.py integration
  tests need it.
- `hook-stdin-PostToolUse.jsonl` -- if/when the gateway extends to post-tool
  hook events (audit-only telemetry).
