# ADR-002 — Monorepo Topology with co-located mission artifacts

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-002-monorepo-topology-colocated-artifacts.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** A Local Orchestrator Mode mission lives in a single git repository on the laptop. Mission artifacts (`.mission/`), ephemeral runtime state (`.mission-runtime/`), prompts, runner tools, Docker definitions, and product code (`src/`) all live in the same repo.

**Alternative considered.** Keep mission state in Postgres (parity with hosted mode); product code in repo only.

**Tradeoff accepted.** YAML-on-disk does not scale to high-write-rate concurrent editing. In local mode that is fine — there is one human, and amendments are seconds-apart, not millis-apart. In a hosted multi-tenant context this layout would melt; the schemas are portable, the layout is not.

**Why this is forced by the three forces.**
- *Force 3:* the human needs `git diff .mission/spec/` and `grep -r` over assertions.
- *Force 1:* `git log` interleaves spec amendments with code commits — the audit trail *is* the git log.
- *Force 2:* files survive `docker compose down`; a Postgres-backed spec does not.
