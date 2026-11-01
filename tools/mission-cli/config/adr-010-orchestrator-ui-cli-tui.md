# ADR-010 — Orchestrator UI is CLI + TUI co-located with the repo

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-010-orchestrator-ui-cli-tui.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** The Mission Control UI for local mode is a `mission` CLI plus a TUI (terminal UI). Optionally a VS Code extension reading the same artifacts. No web server.

**Alternative considered.** Web UI parity with hosted mode.

**Tradeoff accepted.** No browser-based dashboards locally. Worth it because the human orchestrator is already in their terminal and IDE; another browser tab is friction that compounds across a day, and a web app means another container to run.

This resolves Section 12.9 *Mission Control UI* for local mode toward terminal/IDE.
