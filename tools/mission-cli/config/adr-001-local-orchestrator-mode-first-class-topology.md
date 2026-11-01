# ADR-001 — Local Orchestrator Mode is a first-class deployment topology

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-001-local-orchestrator-mode-first-class-topology.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Recognize Local Orchestrator Mode alongside Hosted Autonomous Mode as a supported topology of the same framework. Both consume the same schemas, principles, and lifecycle.

**Alternative considered.** Treat local development as an "out-of-scope, use a single agent" case (per Section 13).

**Tradeoff accepted.** Adds a second topology to maintain. Justified because the artifact discipline that makes hosted mode trustworthy is exactly what makes local mode resumable and replayable. The framework earns its keep at any horizon over a few hours.

**Invariance check.** All schemas in `expanded-schemas.md` work unchanged across both modes. This is the test that the variant fits inside the existing contract instead of bending it.
