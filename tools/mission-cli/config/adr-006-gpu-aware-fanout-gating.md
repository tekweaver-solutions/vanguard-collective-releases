# ADR-006 — GPU-aware fan-out gating

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-006-gpu-aware-fanout-gating.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Fan-out width is bounded by the **minimum** of (a) conflict-free work available per the conflict scanner and (b) available local GPU memory. Practical fan-out width on consumer hardware is 1–3 workers, not 10.

**Tradeoff accepted.** Local mode cannot achieve hosted-mode parallelism. The conflict scanner (Section 6.5) remains the primary gate; GPU memory becomes a second gate.

**Documentation note.** This adds a clause to Section 6.5 / Section 10 only for local mode. It does not change the principle that parallel is permitted only on provably non-conflicting work.
