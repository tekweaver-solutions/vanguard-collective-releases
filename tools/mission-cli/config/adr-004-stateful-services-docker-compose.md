# ADR-004 — Stateful services as user-owned Docker Compose containers

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-004-stateful-services-docker-compose.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Postgres (if used), Ollama, and the sandbox pool run as containers defined in `docker/compose.yaml` inside the repo. Named volumes for persistence. The user owns the lifecycle (`mission infra up`, `docker logs`, etc.).

**Alternative considered.** Hide infrastructure behind an opaque `mission` daemon.

**Tradeoff accepted.** The user has to understand they have containers running. In exchange, when something breaks, they can debug it with the standard Docker tooling they already know. Hosted mode hides infrastructure because operators run it; local mode exposes it because the user runs it.
