# ADR-014 — Claude Code headless mode with subscription auth, no API key required

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-014-claude-code-headless-subscription-auth.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Workers requiring `coding-strong` model class, the QA validator, and the orchestrator thinking-partner are all dispatched by shelling out to `claude -p` (Claude Code headless mode) using the user's Pro/Max OAuth auth from the keychain. **Local Orchestrator Mode does not require `ANTHROPIC_API_KEY` to be set.** Direct API calls are not used. Ollama is the fallback when Claude Code rate-limits and is the right-caliber default for `coding-fast` and `narrow-validator` work.

**Invocation shape.**

```bash
claude -p "$(cat dispatch-context.md)" \
  --append-system-prompt "$(cat prompts/worker-coding-v17.md)" \
  --allowedTools "Read,Edit,Bash(pnpm test *),Bash(pnpm lint *),Bash(git *)" \
  --max-turns 60 \
  --output-format stream-json \
  --permission-mode acceptEdits
```

The `stream-json` output is parsed by the worker-runner into `TraceEvent` records as messages arrive. The terminal `result` message provides `num_turns`, `duration_ms`, `session_id`, and `total_cost_usd` — the cost field is recorded in the trace for observability but **is not used for budget-driven control flow**, see below.

**Budget philosophy: out of scope for local mode.** The framework does not impose dollar-budget caps in local mode. The user has chosen a flat-rate subscription specifically to avoid per-call cost reasoning, and the framework should honor that. Routing picks the right caliber model for the task (ADR-005); rate-limit windows naturally pace the work; no soft/hard dollar caps are enforced. *No new fields are added to the `Mission.budget` schema.* The existing schema fields are kept for hosted-mode use.

**Rate-limit handling.** Pro/Max subscriptions use rolling 5-hour token windows plus weekly caps. When a window is exhausted:

1. The Claude Code CLI returns a rate-limit error with the reset timestamp.
2. The framework's circuit breaker enters `open` state with reason `subscription_rate_limited` and the captured reset time.
3. Affected workers are paused. The mission stays alive; durable runtime checkpoints persist.
4. At the reset time, the breaker auto-transitions to `half-open` and resumes.
5. No human escalation. The user does not need to do anything; the wait is bounded by the published reset time.

If a worker hits the weekly cap and the reset is far enough out that wallclock budgets matter, the mission's existing `wallclock_hard_cap_hours` (already in the `Mission.budget` schema) is what bounds the total wait — that's a separate, pre-existing safety net. The framework does not need new schema fields for rate-limit handling.

**Critical environment-variable rule.** If `ANTHROPIC_API_KEY` happens to be set in the environment when `claude` runs, Claude Code uses API auth and bills the user's API account, *not* the subscription. The worker-runner **must scrub `ANTHROPIC_API_KEY` from the environment before invoking `claude`**. This is defensive — local mode does not require the variable for any positive reason, but users may have it set globally for other purposes. Enforced in the runner code, not relied on as user discipline. (The operator may choose the opposite on purpose: with `VANGUARD_AUTH_MODE=api-key` the worker-runner keeps the key -- LAM-INSTALL.md section 7c.) The scrub is the worker-runner's alone, and it removes `ANTHROPIC_API_KEY` and nothing else: with `VANGUARD_AUTH_MODE` unset the LAM runner and wake starter check and remove nothing, and a key (on their paths), a bearer token (`ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`) or a cloud-provider selector (`CLAUDE_CODE_USE_BEDROCK`, `_VERTEX`, `_FOUNDRY`) left in the environment is picked by Claude Code's own precedence before the subscription it is signed in with. `VANGUARD_AUTH_MODE=subscription` refuses such a credential (the subscription's own `CLAUDE_CODE_OAUTH_TOKEN` excepted) -- LAM-INSTALL.md section 7c.

**Do not use `--bare`.** `--bare` forces API-key auth and is incompatible with subscription mode. The bootstrap protocol's interactive `claude` invocation is what establishes the OAuth/keychain auth that the headless invocation reuses.

**Alternatives considered.**

- *Direct Anthropic API auth for some roles.* Rejected — user explicitly prefers subscription billing; introduces a key-management burden the framework should not carry.
- *Subscription-only with no Ollama fallback.* Rejected — a single rate-limit window block would halt the mission. Ollama fallback for `coding-strong` keeps the mission moving (with weaker output) when Claude Code is unavailable.
- *Capacity-aware budget tracking* (subscription window utilization in `Mission.budget`). Rejected — adds schema surface for a problem the user has explicitly de-scoped. The "wait for reset" model is sufficient.

**Tradeoff accepted.** Subscription auth introduces operational concerns (env-var scrubbing, no per-call dollar metering, rate-limit waits) that API auth doesn't have. In exchange, the user keeps their existing billing relationship, no API key management is required, and the framework absorbs the operational complexity at the runner seam exactly as it should.
