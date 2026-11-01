# ADR-003 — `.mission/` (committed truth) vs `.mission-runtime/` (ephemeral cache)

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-003-mission-vs-mission-runtime.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Two top-level directories with different durability contracts:

| Directory | Git status | Contents | Lose it → |
|---|---|---|---|
| `.mission/` | committed | spec versions, contract, handoffs, validator results, amendments, ledger, mission record | mission is gone |
| `.mission-runtime/` | gitignored | trace store, durable-runtime checkpoints, worktree working dirs | replay from `.mission/` |

**Alternative considered.** Single `.mission/` directory holding both. Simpler at first glance; collapses on first `docker system prune`.

**Tradeoff accepted.** Two directories instead of one; the operational contract has to be taught and enforced. Worth it because consumer hardware is hostile to runtime state — Docker Desktop gets reinstalled, volumes get pruned, disks fill. The split lets the user be cavalier with Docker without being cavalier with the mission.

**This is the load-bearing decision of local mode.** The most likely violation by a well-meaning implementer is "let's just put everything in Postgres for consistency." Doing that silently regresses crash recovery to "depends on Docker Desktop's mood."
