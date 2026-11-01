# ADR-005 — Local inference routing via per-mission config

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-005-local-inference-routing.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Model class → concrete model is resolved through `tools/mission-cli/config/model-routing.yaml`, committed to the repo. Local mode uses two providers: `claude-code-subscription` (shells out to `claude -p` using the user's Pro/Max OAuth — see ADR-014) and `ollama` (local inference). **No API-key path is used in local mode.** Claude Code is the default workhorse for coding-strong work and for vision-based QA evaluation; Ollama is the fallback when Claude Code rate-limits, and is the *right-caliber default* for tasks where coding-strong is overkill.

```yaml
# Default routing for Local Orchestrator Mode
coding-strong:
  primary:  { provider: claude-code-subscription, model: opus-4.7, mode: headless }
  fallback: { provider: ollama, model: qwen2.5-coder:32b }
coding-fast:
  primary:  { provider: ollama, model: qwen2.5-coder:7b }
narrow-validator:
  primary:  { provider: ollama, model: qwen2.5-coder:7b }
qa-validator:
  # Worker captures screenshots via Playwright; Claude Code evaluates
  # them via @path references in the prompt. See ADR-013.
  primary:  { provider: claude-code-subscription, model: opus-4.7, mode: headless }
  fallback: { provider: ollama, model: qwen2.5-coder:32b }   # text-only assertions
orchestrator-thinking-partner:
  primary:  { provider: claude-code-subscription, model: opus-4.7, mode: headless }
```

**Role-to-default rationale.**

| Role | Default | Why |
|---|---|---|
| Orchestrator thinking-partner | Claude Code (subscription) | Spec drafting and amendment adjudication — high stakes, low call volume. |
| Worker (coding-strong, mainline or fan-out) | Claude Code (subscription) | The workhorse. User's preferred path. |
| Worker (coding-fast) | Ollama 7B | Right caliber for the task — Claude Code is overkill. |
| Narrow validator | Ollama 7B | Hundreds per milestone of single-assertion checks; right caliber. |
| QA validator | Claude Code (subscription) | Vision-capable; evaluates Playwright-captured screenshots via `@path` references. |

**On rate limits.** Claude Code subscriptions have rolling 5-hour windows plus weekly caps. When a window is exhausted, the circuit breaker pauses the affected workers and resumes at the documented reset time (ADR-014). The framework does not impose its own dollar-budget caps for local mode — see ADR-014 for why this is the right default.

**Tradeoff accepted.** Ollama is weaker per-token than Claude Code. Where it appears in the routing, it's because the *task caliber* matches a small fast model, not because we're optimizing for cost. The fallback path on `coding-strong` does mean a rate-limit-induced fallback delivers a weaker model than the primary, with the consequences (more amendments, more rework) absorbed by the contract and handoff machinery as designed.

**Invariant preserved (Section 14.6).** Swapping model class for any role is a config change to one file, not a rewrite.
