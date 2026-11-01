"""
runner.py -- the worker-runner main async loop.

Spawns `claude -p --output-format stream-json` against a per-dispatch
hook config, parses the stream, emits trace events, and produces a
schema-validated Handoff at exit.

This module writes the **runtime-cache Handoff** under
`<project_root>/.mission-runtime/dispatches/<dispatch_id>/handoff.json`.
Acceptance promotion to `.mission/handoffs/` (committed truth per ADR-003)
is the orchestrator's job (forthcoming module) -- the same proposals/-vs-
committed split as `.mission/spec/proposals/` vs `.mission/spec/`.

**Schema-level Handoff validation only.** WorkerRunner.run() validates the
worker-produced handoff via `Handoff.model_validate_json(...)`, catching all
§5 schema constraints (status/error consistency, unfinished-vs-completed,
deviation_notes-vs-procedure_adherence, git-SHA shape) but NOT the
cross-artifact constraint §5.2 (every completed_assertions entry must be
in dispatch.assertion_targets). Cross-artifact validation lands in
`tools/worker-runner/handoff_validator.py` at step 6; until then, a Handoff
whose completed_assertions references an out-of-scope assertion passes
schema validation here but fails cross-artifact check when step 6 lands.

**Two Handoff-production paths.** The runner produces a Handoff under
two conditions:
  (a) Normal: the worker wrote `handoff.json` to the dispatch-cache path.
      The runner reads and Pydantic-validates.
  (b) Synthesized: the framework killed the worker before it could write
      (timeout, crash). The runner constructs a Handoff with
      `terminated_reason=BUDGET_EXHAUSTED` (timeout) or appropriate
      synthetic value, `procedure_adherence=CONFIRMED` (framework killed,
      not worker fault), and populates `commits` via
      `git rev-list <base_commit>..HEAD` introspection of the worktree.
  Path (b) is the most consequential failure mode: the framework MUST
  record what happened even when the worker didn't get to.

**Dispatch-root + closing trace events** (per the result-metadata
pattern):
  Root:    StateTransitionTrace, parent_id=None,
           from_state="dispatched" -> to_state="running",
           trigger="worker_runner.spawn".
  Closing: StateTransitionTrace, parent_id=root_id,
           from_state="running" -> to_state="completed"|"errored",
           trigger=f"claude_p.terminal_result:session={session_id}"
           (session_id v1 location; queryable form
           via a future amendment).
All in-dispatch LLMCallTrace events parent to root_id; all ToolCallTrace
events parent to their requesting LLMCallTrace (so a future tree-walker
can render assistant-by-assistant per-turn tool inventories).

**Hook-decision cross-check escalation.** When the runner's local
`Gateway.check(tool_name, tool_scope)` disagrees with the observed
`hook_response.exit_code`, the runner emits an EscalationTrace with a
**queryable colon-separated error format** (contract; do not free-form):
  `inconsistency:hook_decision_vs_local_gateway:tool=<name>:`
  `hook=<allowed|denied>:local=<allowed|denied>:`
  `hook_cap=<tag>:local_cap=<tag>`
Catches stale-tool_scope-file or stale-CapabilityMap scenarios.

**Deferred**: the handoff-write system-prompt
fragment lives inline as `_HANDOFF_INSTRUCTION_TEMPLATE`. Promotion to
the prompts/ registry per ADR-012/017 is post-MVP. ADR-007's task-brief
template (`brief_generator._TASK_BRIEF_TEMPLATE_VERSION`) carries the
same debt; both promote together.

**ADR-007 task-brief integration.** Pre-spawn, the runner constructs
the task brief via `brief_generator.build_and_render` and writes it to
`.mission/dispatches/<dispatch_id>/task-brief.md` (a committed artifact;
NOT the gitignored `.mission-runtime/` runtime scratch). The
`--append-system-prompt` content carries THREE distinct surfaces in
order: (1) a pointer to the brief file the worker must read (the task
channel, ADR-007); (2) the handoff-reporting protocol (the exit
channel). The role surface (ADR-023 system prompt) is the worker
agent's own concern. `_validate_pre_spawn` verifies the brief file
exists and is non-empty before any subprocess is spawned -- a missing
brief is a dispatch-construction error, not a silent empty-task spawn.
Every worker LLMCallTrace carries `brief_version`; the first call's
`input` dict captures the rendered brief content (closes a review finding).
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING, Any, Optional
from uuid import UUID, uuid4

if TYPE_CHECKING:
    from trace_store import TraceStore  # noqa: F401

from brief_generator import RenderedBrief, build_and_render
from claude_cli_safety import validate_claude_argv
from env_scrub import build_scrubbed_env, check_spawn_inputs, resolve_auth_mode, session_files, settings_files
from hook_config import write_dispatch_config
from schemas import (
    AgentRole,
    CommandLog,
    EscalationTrace,
    GatewayDecision,
    Handoff,
    LLMCallTrace,
    ProcedureAdherence,
    StateTransitionTrace,
    TerminatedReason,
    ToolCallTrace,
    TraceStatus,
    UnfinishedItem,
    WorkerDispatch,
)
from stream_json import parse_stream

# Cross-dir framework imports (tool-gateway).
_TOOL_GATEWAY = str(Path(__file__).parent.parent / "tool-gateway")
if _TOOL_GATEWAY not in sys.path:
    sys.path.insert(0, _TOOL_GATEWAY)
from audit_log import AuditLog  # noqa: E402
from mcp_capability_map import CapabilityMap  # noqa: E402
from policy import (  # noqa: E402
    HANDOFF_EXEMPTION_CAPABILITY,
    Gateway,
    Verdict,
    is_handoff_write_exemption,
)

# --- Constants ---

# `claude -p` (--print, headless mode) REQUIRES a prompt input to start the
# assistant turn -- either a positional argument at end of argv, or stdin.
# `--append-system-prompt` is a MODIFIER to the system prompt, not the
# prompt. Without a prompt input, claude waits 3s for stdin then exits 1
# with "Input must be provided either through stdin or as a prompt
# argument when using --print" (captured stderr from a dispatch).
#
# **Delivery channel: stdin, NOT argv.** A PowerShell-driven differential
# probe confirmed claude engages correctly when the trigger is the
# trailing positional argv element -- but asyncio.create_subprocess_exec
# on Windows wraps .CMD targets via cmd.exe /c, and that wrapping mangles
# the trailing multi-word positional (same family as the PATHEXT gap
# fixed earlier; further compounded by Python 3.13's
# CVE-2024-12254-related tightening of .CMD/.BAT handling on Windows).
# Stdin is the cross-platform channel claude -p supports first-class,
# bypasses .CMD shim quoting entirely, and works identically on
# Linux/macOS. _spawn_and_parse writes this constant to stdin then
# closes the pipe BEFORE entering the stdout parse loop, so claude
# sees EOF immediately and does not stall on the 3s stdin-wait timeout.
#
# This trigger is a content-free DIRECTIVE: an engagement signal that
# orients the worker to its system-prompt instructions (where the
# ADR-007 brief pointer lives). It is BYTE-IDENTICAL across every
# dispatch -- no feature_id, no assertion ids, no objective wording --
# so ADR-007's "the brief file is the durable task channel" stands
# unchanged (decisions 1+2). The brief in the appended system prompt
# remains the task surface; this string is purely the CLI-required
# engagement trigger. ADR-007's rejection of stdin-as-the-TASK-channel
# is preserved: the task is NOT in stdin -- only the content-free
# trigger is.
_TRIGGER_PROMPT = (
    "Read your task brief (referenced in the system prompt) and complete "
    "the work it specifies. Write your Handoff per the protocol when done."
)

# ADR-007 decision 1: the task surface is a brief file the worker is
# instructed to read via `--append-system-prompt`. This pointer sits
# alongside (NOT replacing) the handoff-reporting template below.
# Three distinct surfaces in the appended system prompt, in order:
#   1. Task brief pointer (this template; ADR-007).
#   2. Handoff-reporting protocol (`_HANDOFF_INSTRUCTION_TEMPLATE`).
# The role-prompt (ADR-023) is the worker agent's own surface and is
# constructed elsewhere.
_TASK_BRIEF_POINTER_TEMPLATE = """\
WORKER TASK BRIEF (framework-injected, do not omit).

Your task brief is at this exact absolute path:

  {brief_path}

READ THIS FILE NOW with the Read tool, using the exact path above. Do
NOT search for it (no Glob, no Bash ls, no Grep). Do NOT use a
relative path. The brief is at the absolute path shown -- read it
directly with that string.

Once you have read the brief, it tells you:
  - The objective for this dispatch (what to build).
  - Pointers to the versioned spec + assertion files you must read
    (those ARE under the worktree -- the brief gives you relative
    paths for them; the worktree is your current working directory).
  - Optional operator-supplied context, if present.

The brief is your task input of record (ADR-007). It INDEXES the
frozen contract; it does not inline it. When in doubt the spec
({spec_path}) and assertion files under
.mission/contract/assertions/ are authoritative.
"""

_HANDOFF_INSTRUCTION_TEMPLATE = """\
WORKER HANDOFF PROTOCOL (framework-injected, do not omit).

When you finish (or determine you cannot proceed further), write a Handoff
JSON document to the path below and exit. The runner Pydantic-validates the
file; malformed handoffs are rejected and the dispatch is marked
inconsistent.

Handoff path: {handoff_path}
Schema:       tools/worker-runner/schemas.py :: Handoff (§5 of expanded-schemas.md)

Required fields you must populate:
  id                 : UUID
  created_at         : ISO-8601 UTC timestamp (e.g. 2026-05-30T12:00:00Z)
  created_by         : your agent id (e.g. claude-code:worker)
  from_worker        : your worker instance id (= "{worker_id}")
  dispatch_id        : "{dispatch_id}"
  feature_id         : "{feature_id}"
  spec_version       : {spec_version}
  completed_assertions: assertion ids you believe you satisfied
                        (must be drawn from {assertion_targets})
  unfinished         : list of UnfinishedItem (empty if all targets done)
  commits            : git SHAs you created (hex, 7-40 chars)
  commands_run       : list of CommandLog (cmd + exit_code + optional stderr)
  issues_observed    : free-form notes that should feed the ledger
  procedure_adherence: "confirmed" or "deviated" (with deviation_notes)
  terminated_reason  : one of completed | budget_exhausted | tool_blocked |
                                 amendment_filed | crash_recovered

{handoff_vocabulary}
"""


def _derive_handoff_vocabulary() -> str:
    """Derive the handoff-protocol vocabulary block by introspecting
    schemas.Blocker and schemas.TerminatedReason, and DESCRIBE §5
    constraint 1 in prose.

    Closes the ENUM half of instance 7 of the ADR-027 defect class
    (ledger-handoff-recovery-instance-7-brief-doesnt-index-schemas-enums).
    The constraint half remains DESCRIBED-prose (drift-prone residual);
    option 3 (pre-exit handoff validation round-trip) is the target that
    closes this residual — scoped as a follow-up ADR, not built here.

    Derived-and-injected, synced-by-construction: any future addition to
    Blocker or TerminatedReason automatically flows into the vocabulary
    block on the next dispatch (drift-proof for the enum halves). Same
    pattern as hook_config._derive_permissions_allow().
    """
    # Lazy import so the runner's import topology doesn't pull schemas at
    # module-load when only the template constant is referenced.
    import schemas  # noqa: E402

    blocker_values = [m.value for m in schemas.Blocker]
    terminated_reason_values = [m.value for m in schemas.TerminatedReason]

    lines = [
        "ENUM VOCABULARY (derived-and-injected from schemas.py — sync-by-construction).",
        "",
        "  Blocker — valid values for UnfinishedItem.blocker (optional field):",
    ]
    for v in sorted(blocker_values):
        lines.append(f"    - {v}")
    lines.extend([
        "",
        "  terminated_reason — valid values for Handoff.terminated_reason:",
    ])
    for v in sorted(terminated_reason_values):
        lines.append(f"    - {v}")
    lines.extend([
        "",
        "§5 CONSTRAINT 1 (described prose, NOT derived — option 3 follow-up:",
        " pre-exit validation round-trip would catch a description/code drift).",
        "  When `unfinished` is NON-EMPTY, `terminated_reason` MUST NOT be",
        "  `completed`. Pick one of:",
        "    - `amendment_filed` (you filed a §5 amendment recording why the",
        "      unfinished items are structurally deferred — e.g. a sibling-",
        "      feature dependency that prevents within-dispatch closure).",
        "    - `tool_blocked` (an authorized tool/capability denied a call you",
        "      needed; the brief documents what should have been granted).",
        "    - `budget_exhausted` (cost or wallclock budget halted you).",
        "    - `crash_recovered` (synthesized by the runner on worker crash;",
        "      workers don't pick this themselves).",
        "  DO NOT INVENT values not in the enums above; the runner pydantic-",
        "  validates and will reject the handoff with a schema error.",
    ])
    return "\n".join(lines)

# Inconsistency escalation format. Documented as a queryable contract; do
# not free-form. Future eval-loop pattern-matchers depend on this shape.
_INCONSISTENCY_FORMAT = (
    "inconsistency:hook_decision_vs_local_gateway:"
    "tool={tool}:hook={hook}:local={local}:"
    "hook_cap={hook_cap}:local_cap={local_cap}"
)

# Parse the gateway_hook.py-emitted stderr format:
#   gateway_denied: tool='<name>' capability='<tag>' reason=...
# When the hook's stderr is non-empty, this lets the escalation carry
# the hook's actual capability_tag (otherwise sentinel '(unknown)').
_HOOK_CAP_PATTERN = re.compile(r"capability=['\"]([^'\"]+)['\"]")


def _now_iso() -> str:
    """ISO-8601 UTC, millisecond-precision, Z-suffixed."""
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def _parse_iso(s: str) -> datetime:
    """Parse the framework's ISO-8601 form; tolerate the Z suffix."""
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return datetime.fromisoformat(s)


@dataclass
class _PendingToolCall:
    """In-flight state for a tool call between assistant.tool_use and tool_result."""

    tool_use_id: str
    tool_name: str
    tool_input: dict
    parent_llm_id: UUID
    started_at: str
    started_at_dt: datetime
    hook_id: Optional[str] = None
    hook_exit_code: Optional[int] = None
    hook_stderr: str = ""
    output: dict = field(default_factory=dict)
    is_error: bool = False


class WorkerRunner:
    """Async runner: spawn claude -p with the dispatch config; emit traces;
    return validated Handoff. See module docstring for full design."""

    def __init__(
        self,
        dispatch: WorkerDispatch,
        *,
        store: "TraceStore",
        gateway: Gateway,
        audit: AuditLog,
        worktree_path: Path,
        worktree_base_commit: str,
        project_root: Path,
        claude_executable: Path = Path("claude"),
        claude_argv_prefix: Optional[list[str]] = None,
        operator_note: Optional[str] = None,
        skills: Optional[list[str]] = None,
    ) -> None:
        """
        ...

        claude_argv_prefix is a TEST SEAM (per an operator answer, step-5 C3 design).
        When set, the runner uses this list verbatim as the argv prefix
        instead of the default `[str(claude_executable)]`. Tests spawn
        `fake-claude.py` via `[sys.executable, str(FAKE_CLAUDE_PY),
        "--debug", "with-hook-allow"]`. **Production callers must not set
        this** -- operator-side wrapping of `claude` (timing, logging,
        sandbox prepending) belongs in shell aliasing or a separate
        wrapper executable, not in this constructor parameter.

        operator_note / skills (ADR-007 decisions 5 / 3). Optional
        per-dispatch context threaded into the task brief. operator_note
        renders under a labeled `## Operator note (out-of-contract)`
        section in the brief; skills lists skill ids the worker should
        consult. Both default to None.
        """
        self._dispatch = dispatch
        self._store = store
        self._gateway = gateway
        self._audit = audit
        self._worktree_path = worktree_path
        self._worktree_base_commit = worktree_base_commit
        self._project_root = project_root
        self._claude_executable = claude_executable
        # FIX A (Windows PATHEXT): asyncio.create_subprocess_exec on Windows
        # calls CreateProcess WITHOUT PATHEXT extension matching, so a bare
        # name like "claude" fails to spawn even when "claude.cmd" is on
        # PATH. Resolve via shutil.which (which DOES honor PATHEXT) for the
        # default executable path. The test seam (`claude_argv_prefix`) is
        # already fully-qualified -- e.g. `[sys.executable, FAKE_CLAUDE_PY]`
        # -- and must NOT be re-resolved (would change the spawn target).
        self._uses_default_executable: bool = claude_argv_prefix is None
        if claude_argv_prefix is not None:
            self._claude_argv_prefix = list(claude_argv_prefix)
        else:
            resolved = shutil.which(str(claude_executable))
            self._claude_argv_prefix = (
                [resolved] if resolved else [str(claude_executable)]
            )

        self._dispatch_id = str(dispatch.id)
        self._dispatch_dir = (
            project_root / ".mission-runtime" / "dispatches" / self._dispatch_id
        )
        self._handoff_path = self._dispatch_dir / "handoff.json"

        # ADR-007 decision 4: committed task-brief artifact path. Distinct
        # from `_dispatch_dir` (runtime scratch under .mission-runtime/).
        self._brief_dir = (
            project_root / ".mission" / "dispatches" / self._dispatch_id
        )
        self._brief_path = self._brief_dir / "task-brief.md"
        # `--append-system-prompt <multiline>` was silently truncating at
        # the first newline-pair through asyncio.create_subprocess_exec ->
        # cmd.exe /c on Windows (same family as the trigger-positional
        # mangling fixed earlier; the worker on one dispatch
        # diagnosed this from inside -- received only the heading line,
        # nothing else). Fix: write the appended system prompt body to a
        # file under the runtime dispatch dir, pass --append-system-prompt-file
        # <path>. Single short path through argv transits the .CMD shim
        # fine (same channel as --settings <path> which has worked every
        # dispatch).
        self._system_prompt_path = self._dispatch_dir / "system-prompt.txt"
        self._operator_note = operator_note
        self._skills = list(skills) if skills else None

        # Runtime state
        self._root_id: Optional[UUID] = None
        self._rendered_brief: Optional[RenderedBrief] = None
        self._brief_captured_in_trace: bool = False
        self._root_started_at_dt: Optional[datetime] = None
        self._current_llm_call_id: Optional[UUID] = None
        self._pending: dict[str, _PendingToolCall] = {}
        self._hook_id_to_tool_use: dict[str, str] = {}
        self._tool_use_id_queue: list[str] = []  # FIFO queue of tool_use_ids awaiting hook binding
        self._session_id: Optional[str] = None
        self._terminal_result: Optional[dict] = None
        self._timed_out = False
        # FIX B: spawn-itself failure (e.g. FileNotFoundError from
        # create_subprocess_exec) must NOT bypass the closing trace.
        # When set, `_emit_closing_trace` records an errored terminal
        # transition and `run()` re-raises after emission so the trace
        # store never has a dangling root with no closing pair
        # (§14.3 replayability).
        self._spawn_failure: Optional[BaseException] = None
        self._subprocess_exit_code: Optional[int] = None
        self._subprocess_stderr: bytes = b""
        self._commands_observed: list[CommandLog] = []

    # --- public entry ---

    async def run(self) -> Handoff:
        # THE AUTHENTICATION MODE, decided before anything is
        # written or spawned: VANGUARD_AUTH_MODE unset or empty changes nothing
        # (the key is scrubbed, as ADR-014 has it); a refusal raises here.
        auth_mode = resolve_auth_mode()
        self._construct_and_write_brief()
        self._write_system_prompt_file()
        self._validate_pre_spawn()

        argv = self._build_argv()
        validate_claude_argv(argv)  # ADR-014 flag-seam guard
        settings_path = write_dispatch_config(
            self._project_root,
            self._dispatch_id,
            list(self._dispatch.tool_scope),
            worktree_root=self._worktree_path,
            handoff_path=self._handoff_path,
        )
        # write_dispatch_config returned the settings path; argv already
        # references it (built above).
        assert settings_path == self._dispatch_dir / "hook-settings.json"

        wt_settings = settings_files(self._worktree_path) if auth_mode else []
        if auth_mode == "api-key":
            # No argument, no file handed over and none the CLI loads in its worktree may carry a key-shaped value.
            check_spawn_inputs(
                argv,
                texts={"trigger prompt (piped on stdin)": _TRIGGER_PROMPT},
                files=[settings_path, self._system_prompt_path, self._brief_path, *wt_settings, *session_files(self._worktree_path)],
                settings_files=[settings_path, *wt_settings],
            )
        elif auth_mode == "subscription":
            check_spawn_inputs([], settings_files=[settings_path, *wt_settings], mode="subscription")
        env = build_scrubbed_env()
        # NOTE: CLAUDE_PROJECT_DIR was previously injected here to honor
        # gateway_hook.py's env-based contract. That injection was a no-op
        # for the hook subprocess -- Claude Code overrides CLAUDE_PROJECT_DIR
        # for hook subprocesses (sets to its own cwd-derived value =
        # worktree, not monorepo root). The hook now derives project_root
        # from argv[2] (set by hook_config.py); env is no longer load-
        # bearing. Audit of CLAUDE_PROJECT_DIR consumers across tools/
        # confirmed gateway_hook.py was the sole consumer. See ledger
        # entries `ledger-hook-runner-contract-escapes-to-argv` and
        # `ledger-hook-derives-from-argv-not-ambient`. Injection removed
        # to avoid "code that lies about what it does" (a non-load-bearing
        # env set that looks load-bearing -- same anti-pattern family as
        # the dangling-trace bug).

        self._emit_root_trace()

        timeout_s = self._dispatch.budget.wallclock_cap_minutes * 60
        # FIX B: closing trace is emitted on ANY spawn-path outcome --
        # success, timeout, or spawn-itself failure (FileNotFoundError
        # from create_subprocess_exec, OSError on pipe setup, etc.). The
        # trace store must never be left with a root StateTransitionTrace
        # that has no closing pair (§14.3 replayability hole).
        try:
            await asyncio.wait_for(
                self._spawn_and_parse(argv, env), timeout=timeout_s
            )
        except asyncio.TimeoutError:
            self._timed_out = True
            await self._terminate_subprocess()
        except Exception as exc:
            # Spawn-itself failure: subprocess never started (or started
            # then crashed before parse could begin). Record and continue
            # to closing-trace emission; re-raise after so callers
            # (dispatch_entry) see the original error.
            self._spawn_failure = exc
            await self._terminate_subprocess()

        self._emit_closing_trace()

        if self._spawn_failure is not None:
            raise self._spawn_failure

        if not self._timed_out and self._handoff_path.is_file():
            return self._validate_handoff_from_disk()
        return self._synthesize_handoff_for_failure()

    # --- argv + lifecycle ---

    def _validate_pre_spawn(self) -> None:
        if not self._worktree_path.is_dir():
            raise RuntimeError(
                f"worktree_path is not a directory: {self._worktree_path}"
            )
        if not self._project_root.is_dir():
            raise RuntimeError(
                f"project_root is not a directory: {self._project_root}"
            )
        # ADR-007 decision 1: a missing brief is a dispatch-construction
        # error, not a silent empty-task spawn.
        if not self._brief_path.is_file():
            raise RuntimeError(
                f"task-brief.md missing pre-spawn: {self._brief_path}. "
                f"ADR-007 requires a constructed brief before worker spawn."
            )
        if self._brief_path.stat().st_size == 0:
            raise RuntimeError(
                f"task-brief.md is empty pre-spawn: {self._brief_path}. "
                f"ADR-007 requires a non-empty brief before worker spawn."
            )
        # FIX A guard: when using the default (non-test-seam) executable,
        # confirm argv[0] resolves to a runnable file. shutil.which already
        # tried; if it failed AND the bare name isn't a file on disk, fail
        # fast with a clear message rather than letting subprocess.exec
        # surface a cryptic FileNotFoundError.
        if self._uses_default_executable:
            argv0 = self._claude_argv_prefix[0]
            if not Path(argv0).is_file():
                raise RuntimeError(
                    f"claude executable not found on PATH: "
                    f"{self._claude_executable!r}. "
                    f"shutil.which returned no result and the resolved "
                    f"argv[0] ({argv0!r}) does not exist as a file. "
                    f"Install claude or ensure it is on PATH "
                    f"(PATHEXT-resolvable on Windows)."
                )

    def _write_system_prompt_file(self) -> None:
        """Compose the appended-system-prompt body (brief pointer + handoff
        protocol, with the three-surface separator between) and write it
        to a file under the runtime dispatch dir. _build_argv then passes
        `--append-system-prompt-file <path>` instead of the truncating
        `--append-system-prompt <multiline>` channel.

        Rationale: multi-line argv values get mangled at newline boundaries
        through asyncio.create_subprocess_exec -> cmd.exe /c on Windows.
        Same family as the trigger-positional mangling fixed earlier.
        A single short path through argv transits the .CMD shim fine
        (`--settings <path>` for hook-settings.json is the proof).

        File content is the same composition _build_argv used to inline:
        the directive brief pointer (with the actual brief absolute path
        substituted), the three-surface separator, the handoff-reporting
        protocol (with the actual handoff path + dispatch metadata
        substituted)."""
        spec_rel = (
            f".mission/spec/v{self._dispatch.spec_version:03d}.yaml"
        )
        brief_pointer = _TASK_BRIEF_POINTER_TEMPLATE.format(
            brief_path=str(self._brief_path),
            spec_path=spec_rel,
        )
        handoff_instruction = _HANDOFF_INSTRUCTION_TEMPLATE.format(
            handoff_path=str(self._handoff_path),
            worker_id=self._dispatch.worker_id,
            dispatch_id=self._dispatch_id,
            feature_id=self._dispatch.feature_id,
            spec_version=self._dispatch.spec_version,
            assertion_targets=list(self._dispatch.assertion_targets),
            handoff_vocabulary=_derive_handoff_vocabulary(),
        )
        body = brief_pointer + "\n---\n\n" + handoff_instruction
        self._dispatch_dir.mkdir(parents=True, exist_ok=True)
        # UTF-8 + LF line endings for cross-platform consistency; claude
        # reads the file as text so the OS-native newline isn't required.
        self._system_prompt_path.write_text(
            body, encoding="utf-8", newline="\n"
        )

    def _construct_and_write_brief(self) -> None:
        """ADR-007 decisions 1+4: deterministically construct the task brief
        from `WorkerDispatch` + frozen spec + assertion files, write-time-
        validate via the TaskBrief Pydantic model (raised at build-time by
        `build_and_render`), and write the rendered markdown to the
        committed-artifact path before any subprocess is spawned.

        Failures (missing spec, unknown feature, missing assertion file)
        propagate as `BriefConstructionError` and abort the dispatch
        before any side effect lands -- consistent with ADR-007 decision
        1's "missing brief is a dispatch-construction error".
        """
        rendered = build_and_render(
            self._dispatch,
            self._project_root,
            operator_note=self._operator_note,
            skills=self._skills,
        )
        self._brief_dir.mkdir(parents=True, exist_ok=True)
        # UTF-8 for cross-platform consumers; the rendered body is ASCII
        # but Pydantic JSON dumps and operator_note text may not be.
        self._brief_path.write_text(rendered.markdown, encoding="utf-8")
        self._rendered_brief = rendered

    def _build_argv(self) -> list[str]:
        settings_path = self._dispatch_dir / "hook-settings.json"
        # ADR-007: three distinct surfaces in the appended system prompt
        # (brief pointer + separator + handoff-reporting protocol). The
        # composed body is written to `self._system_prompt_path` by
        # `_write_system_prompt_file` (called pre-spawn from `run()`);
        # this argv passes `--append-system-prompt-file <path>` instead
        # of `--append-system-prompt <multiline>`. The multiline-value
        # channel is silently truncated at the first newline-pair through
        # asyncio.create_subprocess_exec -> cmd.exe /c on Windows (worker
        # on one dispatch diagnosed this from inside -- received
        # only the heading line). Same family as the earlier trigger
        # mangling fix. `--settings <path>` proves single-short-path
        # transits the .CMD shim intact; `--append-system-prompt-file`
        # uses the same pattern.
        return [
            *self._claude_argv_prefix,
            "-p",
            "--output-format",
            "stream-json",
            "--verbose",
            "--no-session-persistence",
            "--include-hook-events",
            "--settings",
            str(settings_path),
            "--append-system-prompt-file",
            str(self._system_prompt_path),
            "--max-budget-usd",
            f"{self._dispatch.budget.cost_cap_usd:.2f}",
            "--session-id",
            self._dispatch.worker_id
            if _looks_like_uuid(self._dispatch.worker_id)
            else str(uuid4()),
            # `acceptEdits` (NOT `default`): Claude's permission engine
            # auto-approves Read/Write/Edit inside cwd + any `--add-dir`
            # trusted directories, without prompting. `default` prompts,
            # and prompting in `-p` headless mode = denial -- which is
            # what blocked the brief Read and the handoff Write on
            # three dispatches even with the
            # gateway-hook exemption in place. Claude's engine is a
            # SECOND permission layer (path-based) below our gateway hook
            # (capability-based); `acceptEdits` keeps it active for
            # defense-in-depth -- writes OUTSIDE the trust set are still
            # denied by Claude's engine (verified by probe: writes to
            # paths outside cwd AND outside any --add-dir landed nowhere).
            #
            "--permission-mode",
            "acceptEdits",
            # `--add-dir <directories...>` extends Claude's permission-
            # engine trust set to include the two per-dispatch artifact
            # dirs:
            #   - self._brief_dir (.mission/dispatches/<id>/) -- the
            #     committed task-brief.md the worker must Read.
            #   - self._dispatch_dir (.mission-runtime/dispatches/<id>/)
            #     -- where the worker writes handoff.json AND where the
            #     runner-written system-prompt.txt + tool_scope.json +
            #     hook-settings.json live.
            # SCOPE GUARANTEE: these are TWO SPECIFIC DISPATCH DIRS, NOT
            # project-root-wide. Containment is preserved -- writes to
            # any other path outside cwd are denied by Claude's engine.
            #
            #
            # PLACEMENT: --add-dir is variadic-greedy (`--add-dir
            # <directories...>` per claude --help); it consumes following
            # args until another `--flag` or EOF. Must be the LAST flag
            # set; the engagement trigger is delivered via stdin, so
            # there's no positional prompt to be consumed. Adding any
            # new flag AFTER this --add-dir would break the trust-set
            # parsing.
            "--add-dir",
            str(self._brief_dir),
            str(self._dispatch_dir),
            # NOTE: claude -p engagement trigger is NOT appended as a
            # positional argv element. asyncio.create_subprocess_exec on
            # Windows mangles trailing positionals through the .CMD /
            # cmd.exe /c wrapper. The trigger is piped via stdin in
            # _spawn_and_parse instead (see _TRIGGER_PROMPT docstring).
        ]

    async def _spawn_and_parse(self, argv: list[str], env: dict[str, str]) -> None:
        process = await asyncio.create_subprocess_exec(
            *argv,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
            cwd=str(self._worktree_path),
        )
        self._process = process
        # Deliver the engagement trigger via stdin BEFORE entering the
        # stdout parse loop. Sequence: write bytes -> drain -> close
        # write end -> wait_closed. claude needs EOF on stdin to know
        # the input is complete; without the close it stalls 3s on the
        # stdin-wait timeout (captured stderr from two dispatches
        # before this fix). BrokenPipe / ConnectionReset are
        # tolerated -- if claude already crashed at startup, the stream
        # parse + exit-code paths below surface the actual failure,
        # masking the stdin write's pipe error would obscure it.
        try:
            process.stdin.write(_TRIGGER_PROMPT.encode("utf-8"))
            await process.stdin.drain()
            process.stdin.close()
            await process.stdin.wait_closed()
        except (BrokenPipeError, ConnectionResetError):
            pass
        try:
            async for event in parse_stream(process.stdout):
                self._handle_event(event)
            self._subprocess_stderr = await process.stderr.read()
        finally:
            self._subprocess_exit_code = await process.wait()

    async def _terminate_subprocess(self) -> None:
        """Cooperative termination: SIGTERM with 10s grace, SIGKILL fallback.
        Always attempt to capture trailing stderr (found in review): the synthesized
        Handoff's diagnostic value degrades meaningfully without it."""
        proc = getattr(self, "_process", None)
        if proc is None or proc.returncode is not None:
            return
        try:
            proc.terminate()
            try:
                await asyncio.wait_for(proc.wait(), timeout=10)
            except asyncio.TimeoutError:
                proc.kill()
                await proc.wait()
            # Capture any stderr the worker emitted before termination.
            # 2s cap so a stuck stderr pipe doesn't block the lifecycle.
            try:
                self._subprocess_stderr = await asyncio.wait_for(
                    proc.stderr.read(), timeout=2
                )
            except asyncio.TimeoutError:
                pass
        except ProcessLookupError:
            pass

    # --- event dispatch ---

    def _handle_event(self, event: dict) -> None:
        kind = event.get("type")
        if kind == "assistant":
            self._handle_assistant(event)
        elif kind == "system":
            sub = event.get("subtype")
            if sub == "hook_started":
                self._handle_hook_started(event)
            elif sub == "hook_response":
                self._handle_hook_response(event)
            # other system subtypes (init, etc.) -- recorded implicitly via
            # the root/closing pair; no per-event trace needed at v1.
        elif kind == "user":
            self._handle_user(event)
        elif kind == "result":
            self._terminal_result = event
            self._session_id = event.get("session_id")
        # rate_limit_event and unknown kinds: skip at v1

    def _handle_assistant(self, event: dict) -> None:
        message = event.get("message", {})
        usage = message.get("usage", {})
        llm_id = uuid4()
        self._current_llm_call_id = llm_id

        # ADR-007 decision 6: every worker LLMCallTrace carries
        # brief_version so the eval loop can correlate brief-template
        # iterations with handoff outcomes. Review-finding closure: capture the
        # rendered brief content + task-channel system-prompt fragments
        # on the FIRST assistant turn; subsequent turns get an empty
        # input (the brief is a per-dispatch constant; one capture is
        # sufficient for replay -- the committed task-brief.md is the
        # canonical source, and brief_version on every call points back).
        brief_version: Optional[str] = None
        first_turn_input: dict[str, Any] = {}
        if self._rendered_brief is not None:
            brief_version = self._rendered_brief.brief.brief_version
            if not self._brief_captured_in_trace:
                first_turn_input = {
                    "task_brief_id": str(self._rendered_brief.brief.id),
                    "task_brief_markdown": self._rendered_brief.markdown,
                    "system_prompt_appended": "task_brief_pointer + handoff_instruction",
                }
                self._brief_captured_in_trace = True

        self._store.insert(
            LLMCallTrace(
                id=llm_id,
                parent_id=self._root_id,
                mission_id=self._dispatch.mission_id,
                agent_id=self._dispatch.worker_id,
                agent_role=AgentRole.WORKER,
                started_at=_now_iso(),
                duration_ms=0,
                status=TraceStatus.SUCCESS,
                error=None,
                model=str(message.get("model") or "unknown"),
                prompt_version="inlined:_HANDOFF_INSTRUCTION_TEMPLATE",
                brief_version=brief_version,
                tokens_in=int(usage.get("input_tokens") or 0),
                tokens_out=int(usage.get("output_tokens") or 0),
                # Review note: per-message cost not in stream-json; total_cost_usd is
                # aggregated from the terminal result event via the
                # derivation pattern.
                cost_usd=0.0,
                # Review-finding closure (ADR-007 decision 6): brief captured once on
                # the first assistant turn. Subsequent turns leave input
                # empty -- the brief is a per-dispatch constant, and
                # brief_version above links every call back to the
                # committed brief artifact.
                input=first_turn_input,
                output={"content": message.get("content", [])},
            )
        )
        # Walk content for tool_use blocks; create PendingToolCall per block
        # (handles the multi-tool_use-in-one-assistant-message case).
        for block in message.get("content", []) or []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use":
                tool_use_id = block.get("id")
                if not isinstance(tool_use_id, str):
                    continue
                now = _now_iso()
                self._pending[tool_use_id] = _PendingToolCall(
                    tool_use_id=tool_use_id,
                    tool_name=str(block.get("name") or ""),
                    tool_input=dict(block.get("input") or {}),
                    parent_llm_id=llm_id,
                    started_at=now,
                    started_at_dt=_parse_iso(now),
                )
                self._tool_use_id_queue.append(tool_use_id)

    def _handle_hook_started(self, event: dict) -> None:
        hook_id = event.get("hook_id")
        if not isinstance(hook_id, str):
            return
        # Correlate hook to the next pending tool_use; pop FIFO on bind (found in review)
        # so a tool_use whose hook never responds doesn't poison the
        # binding of subsequent tool_uses' hooks. FIFO matches Claude Code's
        # tool_use processing order (array order in the assistant message).
        if not self._tool_use_id_queue:
            return
        tool_use_id = self._tool_use_id_queue.pop(0)
        self._hook_id_to_tool_use[hook_id] = tool_use_id
        pending = self._pending.get(tool_use_id)
        if pending is not None:
            pending.hook_id = hook_id

    def _handle_hook_response(self, event: dict) -> None:
        hook_id = event.get("hook_id")
        if not isinstance(hook_id, str):
            return
        tool_use_id = self._hook_id_to_tool_use.get(hook_id)
        if tool_use_id is None:
            return
        pending = self._pending.get(tool_use_id)
        if pending is None:
            return
        pending.hook_exit_code = event.get("exit_code")
        pending.hook_stderr = str(event.get("stderr", "") or "")

    def _handle_user(self, event: dict) -> None:
        # user/tool_result event finalizes a ToolCallTrace.
        message = event.get("message", {})
        for block in message.get("content", []) or []:
            if not isinstance(block, dict) or block.get("type") != "tool_result":
                continue
            tool_use_id = block.get("tool_use_id")
            if not isinstance(tool_use_id, str):
                continue
            pending = self._pending.pop(tool_use_id, None)
            if pending is None:
                continue
            # The stack was popped at hook_started; no removal needed here.
            pending.output = self._extract_tool_output(block.get("content"))
            pending.is_error = bool(block.get("is_error"))
            self._finalize_pending(pending)

    def _extract_tool_output(self, content: Any) -> dict:
        """Stuff the tool_result content into a dict for ToolCallTrace.output."""
        if isinstance(content, dict):
            return content
        return {"content": content}

    def _finalize_pending(self, pending: _PendingToolCall) -> None:
        # Reconstruct Verdict; cross-check against local Gateway.check.
        verdict, escalation_str = self._reconstruct_verdict(pending)
        if escalation_str is not None:
            self._emit_escalation(escalation_str)

        now_dt = datetime.now(timezone.utc)
        duration_ms = int((now_dt - pending.started_at_dt).total_seconds() * 1000)
        status, error = self._infer_status_error(pending, verdict)
        self._audit.log_call(
            verdict,
            mission_id=self._dispatch.mission_id,
            agent_id=self._dispatch.worker_id,
            agent_role=AgentRole.WORKER,
            started_at=pending.started_at,
            duration_ms=max(duration_ms, 0),
            tool_name=pending.tool_name,
            input=pending.tool_input,
            output=pending.output,
            status=status,
            parent_id=pending.parent_llm_id,
            error=error,
        )

    def _reconstruct_verdict(
        self, pending: _PendingToolCall
    ) -> tuple[Verdict, Optional[str]]:
        """Decide ALLOWED/DENIED from hook_response; cross-check against local
        Gateway.check. Return (Verdict, escalation_string-or-None).

        Handoff-protocol exemption: if the call is an exact-path Write to
        the dispatch's handoff_path, the runner-side decision short-
        circuits to ALLOWED with capability_tag=
        `framework.handoff_exemption` -- mirroring the hook-side
        exemption in `gateway_hook.py`. Both sides MUST agree on the
        exemption; otherwise the §6.2 cross-check would fire a false
        EscalationTrace on every legitimate handoff write. The
        observable capability_tag distinguishes exemption-allows from
        normal scope-authorized-allows in the ToolCallTrace store.
        """
        # Exemption check FIRST -- if this is the framework-protocol
        # handoff Write, both sides agree on ALLOWED + observable marker,
        # bypassing the normal scope check.
        if is_handoff_write_exemption(
            pending.tool_name, pending.tool_input, str(self._handoff_path)
        ):
            hook_exit = pending.hook_exit_code
            hook_decision = (
                GatewayDecision.ALLOWED
                if hook_exit == 0
                else GatewayDecision.DENIED
            )
            # If the hook disagrees with the local exemption (e.g., hook
            # was built before the exemption code, or the runner+hook are
            # out of sync), surface the disagreement as an Escalation --
            # but with `hook_cap=(unknown)` + `local_cap=
            # framework.handoff_exemption` so audit reads it correctly.
            if hook_decision != GatewayDecision.ALLOWED:
                hook_cap = "(unknown)"
                if pending.hook_stderr:
                    m = _HOOK_CAP_PATTERN.search(pending.hook_stderr)
                    if m:
                        hook_cap = m.group(1)
                escalation = _INCONSISTENCY_FORMAT.format(
                    tool=pending.tool_name,
                    hook=hook_decision.value,
                    local=GatewayDecision.ALLOWED.value,
                    hook_cap=hook_cap,
                    local_cap=HANDOFF_EXEMPTION_CAPABILITY,
                )
                return (
                    Verdict(
                        decision=GatewayDecision.DENIED,
                        capability_tag=HANDOFF_EXEMPTION_CAPABILITY,
                        reason=pending.hook_stderr.strip()
                        or "handoff-exemption blocked by hook",
                    ),
                    escalation,
                )
            return (
                Verdict(
                    decision=GatewayDecision.ALLOWED,
                    capability_tag=HANDOFF_EXEMPTION_CAPABILITY,
                    reason=None,
                ),
                None,
            )

        local = self._gateway.check(
            pending.tool_name, list(self._dispatch.tool_scope)
        )
        hook_exit = pending.hook_exit_code
        if hook_exit == 0:
            hook_decision = GatewayDecision.ALLOWED
        else:
            # exit_code != 0 (or None if no hook event observed) -> treat as denied.
            hook_decision = GatewayDecision.DENIED

        escalation = None
        if local.decision != hook_decision:
            # Parse hook_cap from gateway_hook.py's structured stderr
            # ("capability='<tag>' ..."). Sentinel '(unknown)' when stderr
            # is empty (allow path) or unparseable.
            hook_cap = "(unknown)"
            if pending.hook_stderr:
                m = _HOOK_CAP_PATTERN.search(pending.hook_stderr)
                if m:
                    hook_cap = m.group(1)
            escalation = _INCONSISTENCY_FORMAT.format(
                tool=pending.tool_name,
                hook=hook_decision.value,
                local=local.decision.value,
                hook_cap=hook_cap,
                local_cap=local.capability_tag,
            )

        if hook_decision == GatewayDecision.ALLOWED:
            return (
                Verdict(
                    decision=GatewayDecision.ALLOWED,
                    capability_tag=local.capability_tag,
                    reason=None,
                ),
                escalation,
            )
        return (
            Verdict(
                decision=GatewayDecision.DENIED,
                capability_tag=local.capability_tag,
                reason=pending.hook_stderr.strip() or local.reason or "(no reason)",
            ),
            escalation,
        )

    def _infer_status_error(
        self, pending: _PendingToolCall, verdict: Verdict
    ) -> tuple[TraceStatus, Optional[str]]:
        if verdict.decision == GatewayDecision.DENIED:
            return TraceStatus.ERROR, f"gateway_denied: {verdict.reason}"
        if pending.is_error:
            text = pending.output.get("content") if isinstance(pending.output, dict) else None
            return TraceStatus.ERROR, str(text) if text else "tool_execution_error"
        return TraceStatus.SUCCESS, None

    # --- lifecycle trace events ---

    def _emit_root_trace(self) -> None:
        now_iso = _now_iso()
        self._root_started_at_dt = _parse_iso(now_iso)
        self._root_id = uuid4()
        self._store.insert(
            StateTransitionTrace(
                id=self._root_id,
                parent_id=None,
                mission_id=self._dispatch.mission_id,
                agent_id=self._dispatch.worker_id,
                agent_role=AgentRole.WORKER,
                started_at=now_iso,
                duration_ms=0,
                status=TraceStatus.SUCCESS,
                error=None,
                from_state="dispatched",
                to_state="running",
                trigger="worker_runner.spawn",
            )
        )

    def _emit_closing_trace(self) -> None:
        assert self._root_id is not None
        now_iso = _now_iso()
        now_dt = _parse_iso(now_iso)
        duration_ms = (
            int((now_dt - self._root_started_at_dt).total_seconds() * 1000)
            if self._root_started_at_dt
            else 0
        )
        if self._spawn_failure is not None:
            # FIX B: subprocess never started (or started then crashed
            # before parsing). Record the failure shape so the trace
            # store has the closing pair and §14.3 replay can see what
            # happened. The exception itself is re-raised by run() right
            # after this method returns.
            status = TraceStatus.ERROR
            exc_name = type(self._spawn_failure).__name__
            error = f"spawn_failure: {exc_name}: {self._spawn_failure}"
            to_state = "errored"
            trigger = f"worker_runner.spawn_failure:{exc_name}"
        elif self._timed_out:
            status = TraceStatus.ERROR
            error = "dispatch exceeded wallclock_cap_minutes"
            to_state = "errored"
            trigger = "wallclock_timeout"
        elif self._terminal_result is not None and not self._terminal_result.get(
            "is_error"
        ):
            status = TraceStatus.SUCCESS
            error = None
            to_state = "completed"
            session = self._session_id or ""
            trigger = (
                f"claude_p.terminal_result:session={session}"
                if session
                else "claude_p.terminal_result"
            )
        else:
            status = TraceStatus.ERROR
            error_msg = ""
            if self._terminal_result is not None:
                error_msg = str(self._terminal_result.get("result") or "")
            elif self._subprocess_exit_code is not None:
                error_msg = f"subprocess exit {self._subprocess_exit_code}"
            error = error_msg or "claude_p exited without result"
            to_state = "errored"
            trigger = "claude_p.abnormal_exit"

        self._store.insert(
            StateTransitionTrace(
                id=uuid4(),
                parent_id=self._root_id,
                mission_id=self._dispatch.mission_id,
                agent_id=self._dispatch.worker_id,
                agent_role=AgentRole.WORKER,
                started_at=now_iso,
                duration_ms=duration_ms,
                status=status,
                error=error,
                from_state="running",
                to_state=to_state,
                trigger=trigger,
            )
        )

    def _emit_escalation(self, error_text: str) -> None:
        self._store.insert(
            EscalationTrace(
                id=uuid4(),
                parent_id=self._root_id,
                mission_id=self._dispatch.mission_id,
                agent_id=self._dispatch.worker_id,
                agent_role=AgentRole.WORKER,
                started_at=_now_iso(),
                duration_ms=0,
                status=TraceStatus.ERROR,
                error=error_text,
            )
        )

    # --- Handoff handling ---

    def _validate_handoff_from_disk(self) -> Handoff:
        raw = self._handoff_path.read_text(encoding="utf-8")
        return Handoff.model_validate_json(raw)

    def _synthesize_handoff_for_failure(self) -> Handoff:
        """Path (b): the framework killed the worker before it could write a handoff,
        or the worker exited abnormally. Construct a Handoff describing what
        happened so the runner produces a structured artifact regardless."""
        commits = self._git_revlist(self._worktree_base_commit) if self._worktree_path.is_dir() else []
        if self._timed_out:
            reason = TerminatedReason.BUDGET_EXHAUSTED
            issues = ["framework_killed_on_wallclock_timeout"]
        else:
            reason = TerminatedReason.CRASH_RECOVERED
            # Full stderr (not a 500-char tail): for a code-1-no-stream
            # exit, the stderr text IS the diagnostic. dispatch_entry
            # persists the synthesized handoff to disk so the trail
            # survives the runner instance.
            issues = [
                f"subprocess_exit_code={self._subprocess_exit_code}",
                f"subprocess_stderr={self._subprocess_stderr.decode('utf-8', errors='replace')}",
            ]
        return Handoff(
            id=uuid4(),
            created_at=_now_iso(),
            created_by="claude-code:worker-runner",
            from_worker=self._dispatch.worker_id,
            dispatch_id=self._dispatch_id,
            feature_id=self._dispatch.feature_id,
            spec_version=self._dispatch.spec_version,
            completed_assertions=[],
            unfinished=[
                UnfinishedItem(
                    assertion_id=str(a),
                    reason="framework-terminated dispatch before worker handoff",
                )
                for a in self._dispatch.assertion_targets
            ],
            commits=commits,
            commands_run=self._commands_observed,
            issues_observed=issues,
            suggested_next=None,
            procedure_adherence=ProcedureAdherence.CONFIRMED,
            deviation_notes=None,
            terminated_reason=reason,
        )

    def _git_revlist(self, base_commit: str) -> list[str]:
        try:
            r = subprocess.run(
                ["git", "rev-list", f"{base_commit}..HEAD"],
                capture_output=True,
                text=True,
                cwd=str(self._worktree_path),
                timeout=10,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return []
        if r.returncode != 0:
            return []
        return [sha for sha in r.stdout.split() if sha]


def _looks_like_uuid(s: str) -> bool:
    """Cheap UUID-shape check for --session-id pass-through."""
    try:
        UUID(s)
        return True
    except (ValueError, AttributeError):
        return False
