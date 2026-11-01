# ADR-015 — MCP tool recommendations from the orchestrator (user installs manually)

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-015-mcp-tool-recommendations.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** The orchestrator (in design-phase batch-job mode) recommends required MCP tools. The recommendation is committed to `tools/mission-cli/config/mcp-tools.yaml`. The user activates the recommendation by committing the file and installing the servers manually — there is no formal `accept` ceremony for tools (unlike spec and contract, which have hard-gate acceptance). **The framework does not auto-provision MCP servers.** The human installs them manually using whatever each tool requires (`npm install ...`, `docker run ...`, vendor instructions, etc.). The committed file remains the single source of truth for *what tools workers may invoke* — the existing tool gateway (Section 6.2 of the brief) enforces scope against this file.

```yaml
# tools/mission-cli/config/mcp-tools.yaml — committed to monorepo
mcp_tools:
  - name: playwright
    purpose: "Browser automation for QA validator screenshot capture"
    server: "@anthropic/mcp-playwright"
    install_hint: "npx @anthropic/mcp-playwright"
    isolation: subagent           # see ADR-016
    scope: [qa-validator]         # which roles may use it
  - name: github
    purpose: "Issue and PR management"
    server: "@github/github-mcp"
    install_hint: "see https://github.com/github/github-mcp"
    isolation: direct
    scope: [orchestrator-thinking-partner, worker]
    auth: gh-cli                  # user pre-configures gh auth
```

**Lifecycle.**

1. Designer agent reads `.mission/inputs/` and proposes the MCP tool list as part of design output.
2. Proposal lands at `tools/mission-cli/config/proposals/mcp-tools.yaml` alongside the spec proposal.
3. Human reviews the recommendation. To activate it, the human moves the file to `tools/mission-cli/config/mcp-tools.yaml` (committed) and **installs the recommended servers manually** using each tool's `install_hint`. There is no formal `accept` ceremony for tools — the act of committing the file is itself the acceptance.
4. `mission infra up` brings up Ollama, the sandbox base image, and worker harness — but not MCP servers. MCP server lifecycle is the human's responsibility.
5. Adding or removing an MCP tool from the committed file requires an amendment, since workers depend on the declaration.

**Why "recommend, don't provision."** Auto-provisioning MCP servers means owning auth dance, network calls, and per-tool install quirks at framework startup. That's a class of failure modes (expired tokens, registry rate-limits, vendor-specific install steps) that doesn't belong in `mission infra up`. Pushing the install to the human is operationally honest: the user already knows how to run `npm install` and `docker run`, and the recommendation file gives them everything they need.

**Failure mode if the user skips an install.** A worker's first call to the missing MCP tool returns a runtime error from the MCP transport layer. The framework surfaces this as a tool-call failure in the trace, the user sees the error in `mission watch`, and they install the tool. Recoverable. The cost is one wasted dispatch; the alternative — auto-provisioning — risks subtler failures across many missions.

**Tool gateway role unchanged.** The gateway treats MCP tool names as capability tags. A worker with `tool_scope: [playwright]` may invoke any Playwright MCP method; one without it gets a gateway rejection. Whether the server is actually running is enforced at the next layer down by the MCP transport itself.

**Alternatives considered.**

- *Auto-provisioning at `mission infra up`.* Rejected — couples mission startup to external services in ways that reduce reproducibility and add operational burden.
- *Bake MCP tools into worker prompts.* Rejected — couples tooling to prompt versions, breaks the eval loop's ability to vary one without the other.
- *Add `required_mcp_tools` to LivingSpec schema.* Rejected — schemas are explicitly portable across modes, and a runtime config file is the right home for runtime concerns.

**Tradeoff accepted.** A new config file to maintain, plus a manual install step the user owns. In exchange: reproducible mission startup, no framework-owned auth/install machinery, no schema changes, and the gateway still enforces scope. The "user installs manually" step is brief and one-time per laptop per tool.
