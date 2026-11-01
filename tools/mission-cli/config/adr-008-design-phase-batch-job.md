# ADR-008 — Design Phase as artifact-mediated batch job

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-008-design-phase-batch-job.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** The Design Phase (initial spec drafting) runs as a **batch job**, not a chat. The designer agent is the orchestrator (Section 4.1) operating in initial-spec-drafting mode; it is not a fourth role. Each iteration is a fresh designer instance reading committed artifacts.

**Three sub-contracts.**

1. **Inputs are immutable once design starts.** A new design pass with new inputs is a new pass; old inputs are preserved in git history.
2. **Iteration spawns a fresh designer reading committed artifacts.** No conversation thread is persisted across iterations. The designer remembers nothing turn-to-turn except what is on disk.
3. **`Planning → Executing` is a deliberate human action.** The transition is a CLI command (`mission state set Executing`), not an automatic state change.

**Why this matters.**
- *Replayability (Section 14.3):* every design iteration is reproducible from its inputs.
- *Context rot defense (Section 9):* a 10-iteration design loop is 10 fresh ~5k-token contexts, not one 100k-token stew.
- *Alignment-drift defense (Section 2.7):* the contract is frozen *before* execution begins, exactly as the principle requires.

**Note on terminology.** The "designer" is fine in user-facing docs. In architecture docs, tag it as the **orchestrator role**, batch-job mode, to keep Section 4 unambiguous. Otherwise readers will think we have four roles.
