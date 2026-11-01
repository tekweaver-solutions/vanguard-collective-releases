# ADR-013 — QA validator uses Claude Code headless with Playwright-captured screenshots

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-013-qa-validator-claude-code-playwright.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** The QA validator role runs as a Claude Code headless invocation that consumes screenshots and traces produced by Playwright (or equivalent) running in the worker sandbox. There is no separate API path. There is no `provider: anthropic` route. Visual evaluation happens by passing image paths into the `claude -p` prompt with `@<path>` references, which Claude Code resolves and feeds to the vision-capable model.

**Mechanism.**

1. A worker (or a dedicated QA harness) runs Playwright inside the sandbox to drive the application and capture screenshots into `./qa-evidence/<assertion_id>/*.png`.
2. The QA validator is invoked as `claude -p "<prompt with @qa-evidence/A-088/01.png @qa-evidence/A-088/02.png>" --append-system-prompt prompts/validator-qa-vision-v01.md ...`.
3. The validator emits a `ValidatorResult` (per `expanded-schemas.md`) with the screenshots referenced as `EvidenceItem` entries pointing to the captured files.

**For text-only QA assertions** (those whose `evidence_required` is limited to `test_output`, `http_trace`, `log`, or `metric`), the same routing applies but no screenshots are passed — the validator works from the trace and log evidence alone. The Ollama fallback declared in `model-routing.yaml` covers these text-only assertions when Claude Code is rate-limited; the fallback explicitly does not cover screenshot-based assertions, which require a vision-capable model.

**Alternatives considered.**

- *Hybrid routing with `provider: anthropic` for visual evidence (the previous ADR-013).* Rejected — required `ANTHROPIC_API_KEY`, which contradicts the user's stated preference for a subscription-only local-mode flow. Claude Code headless covers the same capability via subscription auth.
- *Local vision-language model on Ollama (Llama 3.2 Vision, Qwen2-VL).* Maturing but currently weaker than Claude for screenshot interpretation. Will revisit when local VLMs close the gap; the routing config is the only file that changes when that happens.
- *Headless integration tests only, no vision.* Rejected — loses visual assertions like "the modal is visually distinguishable" or "the layout is not broken on this viewport." These are real and worth catching.

**Tradeoff accepted.** Screenshot-based assertions cannot fall back to Ollama today; if Claude Code is rate-limited, those assertions wait for the window reset (per ADR-014). For most local-mode missions this is acceptable — visual assertions are a minority of the contract, and the wait is bounded.

**Known capability gap.** As of May 2026, Claude Code headless does not have an autonomous *agent tool* for reading image files from disk — Anthropic issue [#30925](https://github.com/anthropics/claude-code/issues/30925). The `@path` reference pattern works because the CLI resolves it before the model runs. If the QA validator needs the model to *decide which image to look at next* during its own run, the `@path` pattern is insufficient. Mitigation: the harness pre-selects the screenshots and references them all up front; the model evaluates the set rather than choosing among them iteratively. This is sufficient for assertion-checking but limits more exploratory QA. Track issue #30925 for resolution.
