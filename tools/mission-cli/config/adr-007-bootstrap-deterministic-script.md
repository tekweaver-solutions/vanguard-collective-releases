# ADR-007 — Bootstrap is a deterministic script, invokable two ways

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-007-bootstrap-deterministic-script.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** Mission monorepo creation is performed by a `mission init` script that produces an identical layout every time. The user reaches the script via either:

```powershell
PS> mkdir my-solution
PS> cd my-solution
PS> claude              # Claude Code trusts the folder; nothing else happens
PS> mission init        # bootstrap script — direct invocation
```

…or by asking Claude Code (after the trust step) to set up a mission monorepo, in which case Claude Code invokes `mission init` itself. **Both paths produce identical output.**

**Alternative considered.** Have Claude Code generate the layout via LLM. Rejected: LLM-generated bootstrap is non-deterministic, drifts version-to-version, and breaks the "blow away and recreate" guarantee.

**Tradeoff accepted.** A binary/script must be installed alongside Claude Code. Worth it to keep bootstrap reproducible.
