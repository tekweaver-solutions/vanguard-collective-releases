# Local Orchestrator Mode — topology & design overview

> **ADR source-of-truth: RESOLVED (ADR-033, Accepted 2026-06-15).** Every ADR is canonical as a standalone
> `adr-0NN-<slug>.md` under `tools/mission-cli/config/`. This file is a **topology / design overview** that
> **references** ADRs by number (see the §3 reference list); it does **not** own or duplicate ADR content.
> The earlier STOPGAP banner (a version-controlled copy "pending ADR extraction") is **retired**: ADR-001..018
> were extracted to standalone files, so the extraction it described is done, and ADR-033 supersedes the prior
> Framing-A ("awaiting promotion into ADRs"), Framing-B ("planned extraction mission"), and Framing-C ("fold
> standalone drafts into this doc") framings.
>
> **ADR-007 / ADR-032 collision (factual record, still true).** ADR-007 was once a number collision — two
> distinct decisions shared id 007. Resolved 2026-06-15 by renumbering the standalone "Worker Task-Instruction
> Channel" decision to **ADR-032**; the "Bootstrap is a deterministic script" decision keeps **ADR-007** (now
> the standalone `adr-007-bootstrap-deterministic-script.md`). See
> `adr-032-worker-task-instruction-channel.md` and `adr-007-bootstrap-deterministic-script.md`.

---

# Local Orchestrator Mode — Design Summary

> **Status:** A topology / design-overview document. The architecture decisions it summarizes are canonical as standalone ADRs (`adr-0NN-*.md` under `tools/mission-cli/config/`; see the §3 reference list) per ADR-033 — this doc references them, it does not own them. (An optional Section 15 *Deployment Topologies* section in the architecture brief remains a possible future addition.)
>
> **Companion docs:**
> - `multi-agent-framework-design-brief.md` (referenced as Section 1, Section 2, etc.)
> - `expanded-schemas.md` (artifact field schemas — **unchanged** by this mode)

---

## 1. Purpose & Scope

Local Orchestrator Mode is a deployment topology of the framework in which **the human is the orchestrator** rather than a strong-reasoner model in that role. It is intended for a single developer working on a Windows 11 laptop (or equivalent) with Docker Desktop providing all stateful infrastructure, Claude Code as the interactive thinking partner, and Ollama-hosted coding models as the default execution-stage workhorse.

This mode is a *real second topology*, not a configuration tweak. It trades the default mode's multi-day unattended autonomy horizon for human leverage: dispatch and amendment decisions are gated on human availability; worker execution still runs unattended for hours.

The mode is **not** a relaxation of the framework's principles. The Section 2 principles, the Section 7 lifecycle, the role separation in Section 4, and every schema in `expanded-schemas.md` apply unchanged. What changes is *where things run* and *how the human interacts with the artifact store*.

---

## 2. The Three Forces That Shape Local Mode

Every layout and runtime decision below traces back to one or more of these. Naming them up front is what keeps the design honest — anything not derivable from these forces is suspect.

1. **One human, one filesystem, one git history.** No multi-tenant isolation needed. The orchestrator's working directory and the mission's artifact store can be the same directory.
2. **Docker Desktop is the only ambient infrastructure.** No managed Postgres, no S3, no Temporal cluster, no Kubernetes. Anything stateful that isn't a file runs as a local container.
3. **The human IS the orchestrator.** They need to *read and edit* artifacts directly in the tools they already have open (VS Code, `git diff`, `grep`), not just observe through a UI.

---

## 3. Architecture Decisions

> **The ADR bodies have been extracted to standalone files** under `tools/mission-cli/config/` per ADR-033
> (standalone-canonical). The standalone `adr-0NN-<slug>.md` file is the **canonical** copy of each decision;
> this section is a **reference list**, not a store. See ADR-033 for the source-of-truth doctrine, and the
> per-ADR Status header in each file for its lifecycle state.

| ADR | Title | Canonical file |
|---|---|---|
| ADR-001 | Local Orchestrator Mode is a first-class deployment topology | `adr-001-local-orchestrator-mode-first-class-topology.md` |
| ADR-002 | Monorepo Topology with co-located mission artifacts | `adr-002-monorepo-topology-colocated-artifacts.md` |
| ADR-003 | `.mission/` (committed truth) vs `.mission-runtime/` (ephemeral cache) | `adr-003-mission-vs-mission-runtime.md` |
| ADR-004 | Stateful services as user-owned Docker Compose containers | `adr-004-stateful-services-docker-compose.md` |
| ADR-005 | Local inference routing via per-mission config | `adr-005-local-inference-routing.md` |
| ADR-006 | GPU-aware fan-out gating | `adr-006-gpu-aware-fanout-gating.md` |
| ADR-007 | Bootstrap is a deterministic script, invokable two ways | `adr-007-bootstrap-deterministic-script.md` |
| ADR-008 | Design Phase as artifact-mediated batch job | `adr-008-design-phase-batch-job.md` |
| ADR-009 | *Superseded by ADR-012* | `adr-009-superseded-by-012.md` |
| ADR-010 | Orchestrator UI is CLI + TUI co-located with the repo | `adr-010-orchestrator-ui-cli-tui.md` |
| ADR-011 | Single-mission, single-user, single-monorepo scope (Local Orchestrator Mode only) | `adr-011-single-mission-single-user-scope.md` |
| ADR-012 | Pinned-pull prompt registry with manifest | `adr-012-pinned-pull-prompt-registry.md` |
| ADR-013 | QA validator uses Claude Code headless with Playwright-captured screenshots | `adr-013-qa-validator-claude-code-playwright.md` |
| ADR-014 | Claude Code headless mode with subscription auth, no API key required | `adr-014-claude-code-headless-subscription-auth.md` |
| ADR-015 | MCP tool recommendations from the orchestrator (user installs manually) | `adr-015-mcp-tool-recommendations.md` |
| ADR-016 | Context cleanliness at every level of the agent hierarchy | `adr-016-context-cleanliness.md` |
| ADR-017 | Prompt registry hosted on GitHub with semver | `adr-017-prompt-registry-github-semver.md` |
| ADR-018 | Sandbox base image distributed via GHCR with semver | `adr-018-sandbox-base-image-ghcr.md` |

---

## 4. Bootstrap Protocol

Three commands by the user, in order:

```powershell
PS> mkdir my-solution
PS> cd my-solution
PS> claude              # Claude Code trusts the folder
PS> mission init        # deterministic bootstrap
```

`claude` and `mission init` are intentionally separate. `claude` establishes Claude Code's trust relationship with the folder (a Claude Code-level concern). `mission init` is the framework's deterministic bootstrap.

After `mission init`, git is initialized, `.mission/` is committed at minute zero, and the user has a usable monorepo. There is no "I'll commit later" gap where mission state is uncommitted.

---

## 5. Monorepo Layout

```
my-solution/                          ← monorepo root, git-tracked
├── .mission/                         ← framework state (committed truth)
│   ├── inputs/                       ← user drops requirements docs here
│   ├── spec/
│   │   ├── proposals/                ← designer writes drafts here
│   │   ├── v001.yaml                 ← immutable spec versions (Section 5.1)
│   │   └── current → v001.yaml       ← symlink to active version
│   ├── contract/
│   │   ├── proposals/
│   │   └── assertions/
│   │       ├── A-001.yaml            ← one file per assertion
│   │       └── A-002.yaml
│   ├── handoffs/
│   ├── dispatches/
│   ├── validator-results/
│   ├── amendments/
│   │   └── inbox/                    ← pending; UI surfaces these
│   ├── ledger/
│   │   └── entries.jsonl             ← append-only
│   └── mission.yaml                  ← top-level Mission record
│
├── .mission-runtime/                 ← gitignored; ephemeral cache
│   ├── traces.sqlite                 ← trace store
│   ├── checkpoints.sqlite            ← durable runtime
│   └── worktrees/                    ← managed by worktree mgr
│       ├── wt-mainline/
│       └── wt-fanout-c3/
│
├── prompts/                          ← pulled from GitHub registry per ADR-012/017
│   ├── manifest.yaml                  ← registry version pin + per-file SHAs
│   ├── worker-coding-v17.md
│   ├── validator-narrow-v04.md
│   └── orchestrator-thinking-partner-v02.md
│
├── tools/                            ← orchestrator CLI + runners
│   ├── mission-cli/                  ← `mission` command
│   │   └── config/
│   │       ├── model-routing.yaml    ← model class → provider mapping (ADR-005)
│   │       └── mcp-tools.yaml        ← MCP tools required by mission (ADR-015)
│   ├── worker-runner/                ← spawns Claude Code / Ollama
│   ├── validator-runner/
│   └── tool-gateway/                 ← capability allowlist enforcement
│
├── docker/
│   ├── compose.yaml                  ← references ghcr.io sandbox image (ADR-018)
│   ├── sandbox.Dockerfile            ← per-monorepo extension; FROMs the base
│   └── ollama-models.txt
│
├── src/                              ← THE PRODUCT being built
└── tests/                            ← product tests (separate from contract)
```

### Key directories explained

| Directory | Purpose |
|---|---|
| `.mission/inputs/` | User drops requirements markdown, existing-system notes, design constraints. Read by the designer. Immutable once design starts. |
| `.mission/spec/proposals/` | Designer writes draft spec versions here. Promoted to `.mission/spec/vNNN.yaml` only on `mission spec accept`. |
| `.mission-runtime/` | Lose it → replay from `.mission/`. The split in ADR-003 is what makes "blow away Docker Desktop" safe. |
| `prompts/` | Pulled from GitHub registry at a pinned semver tag; `manifest.yaml` is the version pin (ADR-012, ADR-017). Forks are explicit and visible. |
| `tools/mission-cli/config/` | Per-mission CLI config: `model-routing.yaml` (ADR-005) and `mcp-tools.yaml` (ADR-015). |
| `docker/` | First-class part of the monorepo in local mode (ADR-004). Base image from GHCR (ADR-018); per-monorepo extension via `sandbox.Dockerfile`. |

---

## 6. Two-Phase Workflow

The mission moves through two phases, each with its own cadence and artifact contracts.

### 6.1 Design Phase

```
   user drafts requirements.md          ← chat with Claude Code is OK here
            │                              (chat is private DM until file
            ▼                               is committed to .mission/inputs/)
   .mission/inputs/requirements.md
            │
            ▼
   mission design start                 ← BATCH JOB, not chat
            │
            ▼
   .mission/spec/proposals/v001.yaml
   .mission/contract/proposals/*.yaml
   tools/mission-cli/config/proposals/mcp-tools.yaml
   design-notes-001.md
            │
            ▼
   user reviews ──── feedback ────► mission design refine
            │                       (fresh designer reads
            │                        committed artifacts)
            ▼
   mission spec accept v005.yaml       ← HARD GATE
   mission contract accept
   user moves mcp-tools.yaml from      ← ADR-015 (file move = acceptance)
     proposals/ to config/ and
     installs MCP servers per the
     install_hint fields (manual)
   mission infra up                    ← brings up Ollama + sandbox image
                                          (does NOT install MCP servers)
   mission state set Executing
```

**Drafting requirements *with* Claude Code.** Chat is fine here. The user works through the requirements interactively. Output is a committed file at `.mission/inputs/requirements.md`. Anything in the chat that does not land in a file does not exist for the designer.

**Designer as a batch job.** `mission design start` spawns the orchestrator-in-design-mode as a long-running agent run. It reads `.mission/inputs/`, drafts proposed spec + assertions + design notes + recommended MCP tool list, terminates. Every LLM call and tool call is checkpointed (Section 6.4). This is exactly the "structure beats cleverness on long horizons" principle (Section 2.5) applied to the design loop.

**MCP tool recommendation, manual install (ADR-015).** The designer's responsibility extends to recommending which MCP tools the mission will need. The recommendation lands as a proposal at `tools/mission-cli/config/proposals/mcp-tools.yaml`, including `install_hint` text for each tool. There is no formal `accept` command for tools — the user activates the recommendation by moving the file from `proposals/` to `config/` (committing it) and **installs the servers manually** following the hints. The framework does not auto-provision MCP servers. Adding or removing tools from the committed file requires an amendment, since workers depend on the declaration.

**Iteration loop.** `mission design refine --feedback <file>` spawns a *new* designer instance that reads (previous proposal + user feedback + previous design notes) from disk. There is no chat thread that lives across iterations. Each iteration is reproducible from its inputs.

**The hard gate.** `mission spec accept` + `mission contract accept` + `mission state set Executing` is a deliberate ceremony. Up to that moment, no worker has been dispatched and no product code has been written. After that moment, autonomous execution can run for hours or days against the now-frozen contract. This is the local-mode equivalent of Section 11.1 plus the implicit contract-acceptance moment that hosted mode has built into platform onboarding.

### 6.2 Execution Phase

Same as the Section 7 lifecycle in the brief. Workers are dispatched via `mission dispatch`, validators run per milestone, amendments flow back to the human via `.mission/amendments/inbox/`. Mission completion still requires human signoff (Section 7).

The user closes the laptop. Workers in flight keep running on Ollama; the durable runtime checkpoints continue. If a worker stalls in a loop overnight, the circuit breaker (Section 6.3) opens cleanly until morning.

---

## 7. Touchpoint Mapping

The Section 11 touchpoints in local mode:

| Section  | Touchpoint | Local-mode form |
|---|---|---|
| 11.1 | Mission kickoff | Drafting `requirements.md` → `mission design start` → iteration → `mission spec accept` + `mission contract accept` + commit `mcp-tools.yaml` and manually install MCP servers per `install_hint` (ADR-015) |
| 11.2 | Material amendments | `mission amend approve` from TUI; reads `.mission/amendments/inbox/*.yaml`. Adding/removing MCP tools mid-mission is an amendment. |
| 11.3 | Read→write escalation | First `mission dispatch --kind mainline` after a read-only run; configurable per `Mission.risk_level` |
| 11.4 | Repeated failure | Circuit breaker opens; TUI surfaces the escalation |
| 11.5 | Mission completion | `mission complete` — never automated |

Most touchpoints collapse in *count* because the human is continuously present. They do not collapse in *semantics*: each is still a deliberate action against a committed artifact.

---

## 8. Resolutions to Section 12 Open Architectural Decisions

Local mode resolves several Section 12 items. These resolutions are **local-mode-specific**; hosted mode may resolve them differently.

| Section 12 item | Local-mode resolution | Notes |
|---|---|---|
| 12.1 Durable runtime | SQLite + custom checkpointer | Postgres migration trigger: concurrent reads from a UI while mission writes hot, or trace pooling across missions. |
| 12.2 Storage backend | YAML on disk for artifacts; SQLite for traces/checkpoints | ADR-002, ADR-003. |
| 12.3 Sandboxing | Rootless Docker via Docker Desktop | QA validator captures screenshots via Playwright in-sandbox; Claude Code headless evaluates them via `@path` references (ADR-013). |
| 12.5 Worktree management | Bare git worktrees under `.mission-runtime/worktrees/` | Custom orchestration via `tools/worktree-manager`. |
| 12.7 Trace store backend | SQLite, OpenTelemetry-compatible schema | Hot store for mission life + 30 days; archive optional. |
| 12.9 Mission Control UI | CLI + TUI; optional VS Code extension | ADR-010. No web app. |
| 12.10 Multi-mission resource management | **Out of scope.** Single mission per laptop. | ADR-011. |
| 12.11 Identity and permissions | Single-user laptop; OS user is the identity. Subscription auth via Claude Code OAuth/keychain. | ADR-011, ADR-014. |

Items deferred to hosted mode or future decisions: 12.4 schema enforcement, 12.6 conflict scanner implementation level, 12.8 eval framework specifics, 12.12 cost attribution.

---

## 9. Invariants Preserved

This is the test that local mode extends rather than bends the framework. Each of these is unchanged from the brief:

- **All Section 2 principles.** Especially: agents do not DM, contract before code, two-drift-two-fixes, model-agnostic role typing, durable execution, human attention is precious.
- **All schemas in `expanded-schemas.md`.** `Mission`, `LivingSpec`, `Assertion`, `Dispatch`, `Handoff`, `ValidatorResult`, `Ledger`, `Amendment`, `TraceEvent`, `Worktree` — every field, every constraint.
- **The Section 4 role separation.** Three roles: Orchestrator, Worker, Validator. The "designer" is the orchestrator in batch-job mode (ADR-008), not a fourth role.
- **The Section 7 lifecycle state machine.** `Created → Planning → Executing → Validating → ... → Complete`. Local mode adds *no* states.
- **The Section 10 concurrency rules.** Serial on shared mutable state; parallel only when isolated. Local mode adds GPU memory as a *second* gate (ADR-006); the principle is unchanged.
- **The Section 14 success criteria.** All six apply. Section 14.5 (eval loop) is *weakened* by single-user trace volume — flagged as a known risk, mitigated by the pinned-pull prompt registry (ADR-012) and the user-archive trace pool recommended in Section 13.2.

**Portability claim.** A Local Orchestrator Mode mission can be migrated to a small-team hosted deployment by:
1. Importing artifacts from `.mission/` into the hosted Postgres.
2. Replaying traces from `.mission-runtime/traces.sqlite` into the hosted trace store.
3. Pointing model routing at hosted-managed endpoints.

The artifacts are portable by design. This portability is itself a success criterion for any local-mode change.

---

## 10. Tradeoffs and Risks Named

| Tradeoff / risk | What we accept | Mitigation |
|---|---|---|
| Ollama is weaker per-token than Claude | More amendments, more rework cycles, longer wallclock when fallback is engaged | The contract and handoff machinery absorb this. Routing keeps Claude Code as the workhorse and only falls back to Ollama on rate-limit. |
| Fan-out width capped by laptop GPU | Practical max 1–3 parallel workers | ADR-006. Conflict scanner remains the primary gate. |
| Screenshot-based QA assertions cannot fall back to Ollama | When Claude Code is rate-limited, vision QA waits for window reset | Acceptable — visual assertions are a minority. The wait is bounded by published reset times (ADR-014). Local VLMs may close this gap in time. |
| Eval loop weakens with single-user traces | Section 14.5 not fully achieved in pure-local deployments | Pinned-pull prompt registry (ADR-012) keeps prompt versions correlatable; opt-in trace pooling as a future feature (Section 13.2). |
| YAML-on-disk artifacts don't scale to teams | Local mode is single-user (ADR-011) | The schemas are portable; migration path to Postgres exists. |
| Chat session devolution | Human + Claude Code in chat may slip into "let's just iterate, skip the contract" | Two guardrails: (a) `mission dispatch` refuses to launch without a versioned spec snapshot and `assertion_targets`; (b) thinking-partner Claude Code has read access only — writes go through `mission ... propose` commands. |
| Implementer collapses `.mission/` and `.mission-runtime/` | Crash recovery silently regresses | Document ADR-003 as load-bearing. Code review must catch this. |
| Claude Code subscription rate-limit windows pause work | Workers pause when a 5-hour or weekly window is exhausted | Circuit breaker pauses and auto-resumes at reset time (ADR-014). No human escalation. The mission's existing `wallclock_hard_cap_hours` bounds total wait for very long resets. |
| Stray `ANTHROPIC_API_KEY` in environment could hijack auth | If user has the var set globally for unrelated purposes, Claude Code would silently use API auth | Worker-runner scrubs `ANTHROPIC_API_KEY` before invoking `claude`. Defensive measure; not a positive requirement (ADR-014). With `VANGUARD_AUTH_MODE=api-key` it keeps the key instead (LAM-INSTALL.md section 7c). Only the worker-runner scrubs, and only that variable: with `VANGUARD_AUTH_MODE` unset the LAM runner and wake starter check and remove nothing, and a key (on their paths), a bearer token or a cloud-provider selector left in the environment is used by Claude Code's own precedence instead of the subscription; `VANGUARD_AUTH_MODE=subscription` refuses one (LAM-INSTALL.md section 7c). |
| Forked prompts fragment the eval loop | A user editing `prompts/worker-coding-v17.md` produces traces with a `prompt_version` that doesn't correspond to any registry version | Forks are visible (manifest gap) and require explicit `mission prompts fork` (ADR-012). Code review can flag unintentional forks. |
| Claude Code agent cannot autonomously read images from disk in headless mode | Visual QA requires harness to pre-select screenshots and pass via `@path` in the prompt | Sufficient for assertion-checking. Tracked at upstream issue #30925; revisit when resolved (ADR-013). |

---

## 11. Day-in-the-Life Reference

Captured separately during conversation. Key pattern:

- **08:30** — `mission new`, `mission infra up`, `claude`. Drafting and contract acceptance.
- **09:30** — First `mission dispatch`. Worker runs in sandbox container. `coding-strong` routes to Claude Code headless (subscription) per `model-routing.yaml`.
- **09:50** — User walks away. Laptop sleeps mid-run. Durable runtime checkpoints; on wake, worker resumes from last checkpoint (Section 14.2).
- **11:15** — First handoff arrives. Worker filed an amendment on encountering spec ambiguity (alignment-drift defense, Section 2.7).
- **11:20** — `mission validate --milestone M-1`. Narrow validators fan out in parallel on Ollama (right caliber for single-assertion checks); one fails with evidence the worker missed.
- **11:30** — `mission amend approve` — produces spec v002.
- **11:35** — `mission dispatch --rework`. Fresh worker, no inherited baggage.
- **13:00** — User fans out two non-conflicting features. Both `coding-strong`, both routed to Claude Code. Conflict scanner active.
- **14:45** — Claude Code 5-hour window exhausted mid-run. Circuit breaker pauses both fan-out workers, captures reset time. Mission stays alive.
- **15:30** — Conflict surfaces *during* work (between the previously paused workers and a new arrival), not at PR time. User picks merge order.
- **17:00** — User closes laptop. Workers continue or wait per circuit-breaker state. The breaker auto-resumes at the window reset time overnight.

---

## 12. Documentation Updates Required

These should land in the canonical reference docs. Listed so decisions don't escape into conversation history alone.

1. **New Section 15 *Deployment Topologies*** in `multi-agent-framework-design-brief.md` — name the two modes (Hosted Autonomous, Local Orchestrator), summarize each, and assert the artifact-portability invariant.
2. **ADR-001 through ADR-018**, extracted to standalone `adr-0NN-*.md` files under `tools/mission-cli/config/` per ADR-033 (§3 is now a reference list). ADR-009 is superseded by ADR-012; both retained for traceability. (Home is `tools/mission-cli/config/`, matching ADR-019..033; ADR-033 records the earlier `docs/adr/` suggestion as superseded-by-practice.)
3. **Section 6.2 update** — tool gateway treats MCP tool names as capability tags; `mcp-tools.yaml` is the declaration of what tools workers may invoke (ADR-015). Server installation is the human's responsibility; the gateway does not validate that servers are running.
4. **Section 6.3 update** — circuit breaker for local mode: `subscription_rate_limited` is added as a trigger; the response is "pause and auto-resume at reset time," with no human escalation. Budget-breach trigger remains in the brief but is *not enforced* in local mode (ADR-014). The hosted mode wording is unchanged.
5. **Section 6.5 / Section 10 footnote** — local-mode GPU gate on fan-out width (ADR-006).
6. **Section 11.1 update** — mission-kickoff touchpoint expanded to include the MCP tool recommendation step: the user commits `mcp-tools.yaml` and installs servers manually following `install_hint` (ADR-015). Note that this is *not* a hard gate like spec/contract acceptance.
7. **Section 12 resolutions table** — mark items resolved by local mode with a pointer to the relevant ADR. 12.10 and 12.11 are now resolved for local mode.
8. **Section 14.5 caveat** — eval-loop efficacy degrades with single-user trace volume; flag the mitigations (ADR-012, archive-based pooling per Section 13.2 item 1, opt-in community pooling deferred).
9. **No changes to `expanded-schemas.md`.** This is a feature, not a gap. MCP tools are declared in a separate config file (ADR-015) so the LivingSpec schema stays portable across modes.

---

## 13. Resolved Questions and Remaining Open Items

### 13.1 Resolved

| Question | Resolution | ADR |
|---|---|---|
| Multi-user laptop semantics | Out of scope for local mode. Single user, single laptop, single active mission per monorepo. Hosted mode is unaffected. | ADR-011 |
| Concurrent missions on one laptop | Out of scope for local mode. CLI lockfile enforces single-instance. | ADR-011 |
| Prompt registry distribution | Pinned-pull from a tagged registry version, recorded in `prompts/manifest.yaml`. Forking is opt-in and visible. | ADR-012 (supersedes ADR-009) |
| Local QA validator pathway | Claude Code headless evaluates Playwright-captured screenshots via `@path` references. No API path. Ollama fallback for text-only assertions. | ADR-013 |
| Claude Code as runner | Worker-runner shells out to `claude -p` in headless mode using subscription auth. The default workhorse for `coding-strong`, QA, and orchestrator thinking-partner. | ADR-014 |
| `ANTHROPIC_API_KEY` requirement | Not required in local mode. Worker-runner defensively scrubs it before invoking `claude` to prevent accidental hijack; `VANGUARD_AUTH_MODE=api-key` selects it on purpose (LAM-INSTALL.md section 7c). | ADR-014 |
| Capacity-aware budget tracking | Out of scope. The framework does not enforce dollar caps in local mode; rate-limit waits handle pacing. No schema changes. | ADR-014 |
| MCP tools in the framework | Orchestrator recommends required MCP tools during Design Phase; recommendation lands in `tools/mission-cli/config/mcp-tools.yaml` with `install_hint` per tool; human commits the file and installs servers manually. Framework does not auto-provision. | ADR-015 |
| Context cleanliness | System-wide design discipline at every level of the agent hierarchy: compaction at task boundaries, sub-agent isolation for context-heavy work (Playwright et al.), structured note-taking via the artifact store, tool-output filtering. Operationalizes Section 9 of the brief. | ADR-016 |
| Prompt registry hosting | Single GitHub repo, semver-tagged, framework-maintained. `mission prompts update` refuses MAJOR-version transitions without `--confirm-breaking`. | ADR-017 |
| Sandbox base image distribution | GHCR-hosted, semver-tagged, per-monorepo extension via `docker/sandbox.Dockerfile`. Explicit version pinning in `compose.yaml`. | ADR-018 |

### 13.2 Remaining open items

These are roadmap notes with concrete recommendations and trigger criteria, not architectural decisions for v1.

#### 1. Cross-mission trace pooling for the local user

**Recommendation.** For v1, a user-level archive at `~/.claude-missions/archive/<mission-id>/traces.sqlite`. When a mission completes, `mission complete --archive` copies the closed mission's traces into the archive. The eval loop scans the archive for failure clusters across this user's missions over time. No network involved, no opt-in dialog, fully private.

**Defer to v2.** A community trace corpus (cross-user pooling) is real value for the eval loop's broader effectiveness but requires redaction tooling, schema versioning, and hosting. Not necessary for v1 single-user value.

**Trigger to revisit.** When ≥3 framework users exist and at least one is willing to opt into trace sharing, define the privacy/redaction protocol and build the corpus.

#### 2. Local computer-use migration

**Recommendation.** Build a benchmark suite of 50–100 representative screenshot+assertion pairs with ground-truth verdicts. Migration trigger: a local VLM (Ollama-hosted) achieves ≥90% of Claude Code's pass rate on the suite, with no more than 5% false-positives (validator says "pass" when truth is "fail" — this is the dangerous direction).

**Architectural impact when migrated.** None. The `model-routing.yaml` file's `qa-validator.primary` flips from `claude-code-subscription` to `ollama`. Single-line config change. ADR-014's invariant (Section 14.6) holds.

**Trigger to revisit.** Each new vision-capable Ollama model release is evaluated against the suite as part of framework CI.

#### 3. Claude Code agent autonomous image reading

**Recommendation.** Continue with the `@path` reference pattern, paired with the sub-agent isolation pattern from ADR-016. The harness (sub-agent) pre-selects screenshots and references them up front; the parent agent evaluates the set. This is sufficient for assertion-checking.

**Architectural impact when resolved.** When Anthropic issue [#30925](https://github.com/anthropics/claude-code/issues/30925) lands, the agent gains a `Read` tool that handles image files. This enables more exploratory QA flows (the agent decides which screenshots to inspect mid-run) but does not require any framework changes — the `@path` pattern keeps working.

**Trigger to revisit.** Issue #30925 status changes to closed/resolved.
