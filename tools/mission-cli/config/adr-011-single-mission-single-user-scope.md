# ADR-011 — Single-mission, single-user, single-monorepo scope (Local Orchestrator Mode only)

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-011-single-mission-single-user-scope.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.
>
> **Partially superseded by ADR-031.** Two clauses are superseded (see ADR-031 Decision 4): the *new-monorepo-per-successor* clause is reversed (a successor mission runs in place in the existing monorepo), and the *single-instance-lock* claim is downgraded to a rule-without-enforcement (no `.mission-runtime/mission.lock` exists). The rest of ADR-011 stands.

---

**Decision.** *This ADR applies only to Local Orchestrator Mode.* It does not constrain Hosted Autonomous Mode, which retains multi-tenant, multi-mission semantics. Within Local Orchestrator Mode: one user per laptop, one monorepo per mission, one active mission at a time. The `mission` CLI enforces a single-instance lock against the monorepo; attempts to start a second mission process for the same repo are rejected. There is no multi-mission scheduling, no per-user namespacing, no cross-mission resource pooling.

**Alternative considered.** Allow concurrent missions in the same monorepo, or multiple users on shared laptop infrastructure.

**Tradeoff accepted.** No concurrent missions in local mode. A user finishing mission A and starting mission B does so by opening a new monorepo. Justified because: (a) the human is the orchestrator and cannot meaningfully drive two missions in parallel, (b) GPU contention on a laptop already caps fan-out (ADR-006) — multi-mission contention would compound it pathologically, (c) it eliminates an entire class of correctness bugs around port collisions, sandbox pool sizing, and runtime state isolation.

**What this lets us assume in local mode.** Fixed port range for sandboxes and Ollama (no per-mission allocation). Single `.mission-runtime/` directory, no namespacing. One CLI process at a time, enforced via a PID lockfile in `.mission-runtime/mission.lock`. No identity layer needed beyond the laptop user — the OS user is the identity.

**This does not bleed into hosted mode.** Hosted Autonomous Mode is explicitly multi-tenant; nothing here changes that. The artifact-portability invariant (Section 9) means a mission can move from local to hosted without re-architecting around concurrency.
