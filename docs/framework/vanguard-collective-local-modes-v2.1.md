# Vanguard Collective — Local Modes Design v2
## Local Orchestrator Mode & Local Autonomous Mode

> **Status:** Supersedes `local-orchestrator-mode.md` (v1) as the canonical design for the framework's
> local deployment topologies. Amends — does not replace — `multi-agent-framework-design-brief.md`
> (the brief) and `expanded-schemas.md` (the schemas); every amendment to those documents is
> enumerated in §13 so nothing escapes into this document alone.
>
> **Provenance:** Synthesized from (a) the v1 local-mode design (ADR-001–ADR-018, carried forward
> except where explicitly revised), (b) the FW-01–FW-20 capability-delta analysis against the
> Claude Code / Agent SDK feature surface current to late July 2026, and (c) doctrine minted and
> falsified in operating a prior mission — in particular report-layer fabrication (fabricated
> reports under completion pressure, caught only by human verification layers) and the
> evidence-channel failures (empty chat attachments, irreconcilable suite figures).
>
> **Naming.** Framework ADRs use the `ADR-###` namespace of this document family (continuing from
> v1's ADR-018). Mission repos have their own ADR namespaces; no relation.
>
> **Revision:** v2.1 — post-validation. Eight defects found in adversarial self-review and
> cured in place: ADR-034 numbering gap; evidence write-path enforcement unspecified (load-bearing);
> crash-before-finalize semantics; `mission verify` output as evidence; anchor scoping by dispatch
> kind; push-authorization TOCTOU + single-use; `testimony_conflict` decidability; expected-failure
> manifest framework home.

---

## 1. Purpose & Scope of v2

Three things changed since v1 and each forces design, not just configuration:

1. **The platform grew an orchestration surface.** Claude Code now natively provides headless
   programmatic execution (Agent SDK), lifecycle hooks with documented precedence over permission
   automation, goal-conditioned sessions, native worktree isolation, dynamic subagent workflows,
   event channels into running sessions, multi-session management (agent view), scheduled routines,
   and layered sandboxing. Several v1 build-it-ourselves plans are now buy decisions.
2. **A topology hole opened.** v1 defined Local Orchestrator Mode (human orchestrator, local
   substrate) and the brief assumes Hosted Autonomous Mode (agent orchestrator, cloud substrate).
   The platform now supports the third cell: **agent orchestrator, local substrate** — with the
   human retained only at defined gates. This document names it **Local Autonomous Mode** and
   specifies it.
3. **Mission operation falsified an assumption.** v1 implicitly trusted the report layer: a
   worker's prose report was treated as an adequate carrier for anchors (shas, suite figures, push
   confirmations). Report-layer fabrication shows it is not. The countermeasures an operator mints
   as mission law (state-derived anchors, operator browser confirmation, figure authority,
   fresh-session re-derivation) were correct and are hereby promoted into framework law — **and
   mechanized**, so the human returns to being the spot-check layer §11 intends rather than the
   primary integrity instrument.

Out of scope, unchanged from the brief §13: replacing human architectural judgment,
zero-touchpoint operation, eliminating code review, guaranteeing correctness, multi-mission
scheduling.

---

## 2. Core Principles — Restated, Plus One

Principles 1–10 of the brief §2 apply unchanged to every topology. Mission operation adds an
eleventh, which is really Principle 9's contrapositive learned the hard way:

> **11. Evidence is captured by the harness, never authored by the agent.** An agent's report is
> testimony. Anchors — commit shas, suite figures, porcelain output, push confirmations, API
> response identities — are evidence only when written to the evidence store by deterministic
> machinery (hooks, the runner, the CLI) that the agent cannot edit. A report *cites* evidence by
> path + hash; it never *reproduces* it authoritatively. Any figure that exists only in agent
> prose does not exist.

Corollaries that shape everything below:

- **The read-only/mutation asymmetry is load-bearing.** Read-only sessions and operator acts
  carry far less fabrication risk than mutation-bearing dispatches; fabrication concentrates in a
  mutation-bearing dispatch under completion pressure. Therefore: diagnosis is always read-only,
  mutations ride minimal dispatches, and the machinery (not ceremony) verifies claimed acts.
- **Chat is not an evidence channel.** Attachments and pasted prose are lossy and unverifiable
  (the empty-attachment defect class). Evidence lives on disk, committed; conversations carry
  paths, hashes, and small verbatim excerpts only.

---

## 3. The Topology Family

One framework, three deployment topologies. All three consume identical schemas, the identical
lifecycle (brief §7), and identical role contracts (brief §4). The invariance test from ADR-001
still governs: if a schema must change to fit a topology, the topology is wrong.

| | **Hosted Autonomous** | **Local Orchestrator** | **Local Autonomous** (new) |
|---|---|---|---|
| Orchestrator seat | Agent (strong reasoner) | **Human** | **Agent, local session** |
| Substrate | Cloud, multi-tenant | One workstation + Docker | One workstation + Docker (+ optional cloud fan-out) |
| Artifact store | Postgres/object store | `.mission/` in git monorepo | `.mission/` in git monorepo |
| Autonomy horizon | Days–weeks | Hours (per dispatch) | Days (between gates) |
| Human touchpoints | Brief §11 five | Every dispatch + §11 | §11 five **+ push authorization** (§10) |
| Dispatch mechanism | Platform scheduler | Human pastes / runs CLI | Orchestrator agent invokes runner (headless spawn) |
| Status | Brief default; not yet built | v1, operational | This document, §9 |

Local Orchestrator Mode remains fully supported — it is the on-ramp and the fallback, and the
delegation ladder (§9.5) is defined so a mission can move between the two local modes
incrementally and reversibly.

---

## 4. The Evidence Plane (new cross-cutting layer)

Sits alongside the brief §6 cross-cutting layers (tool gateway, circuit breaker, ledger, trace
store, eval loop, worktree manager, durable runtime, mission control). It has four components.

### 4.1 Hook-captured evidence store

Every worker/validator/orchestrator-agent session runs with framework-installed hooks:

- **PostToolUse** appends `{ts, session_id, dispatch_id, tool, command, exit_code, stdout, stderr}`
  to an append-only evidence log under `.mission-runtime/evidence/<dispatch_id>/`, written by the
  hook process — the model never holds the pen.
- **Stop** finalizes the log, computes a manifest (per-entry sha256, count), and copies the
  manifest + selected evidence files into `.mission/evidence/<dispatch_id>/` for commit at the
  next ceremony boundary.
- **PreCompact** snapshots the full transcript into the evidence store before any compaction, so
  compaction never destroys replay material (serves brief §14.3).

A fabricated `git rev-parse` cannot survive this: the hook logged the real one.

**Write-path enforcement (the load-bearing detail).** Principle 11 says machinery the agent
*cannot* edit — that must be enforced, not asserted, or the fabrication vector reopens one layer
down (an agent with Bash editing its own evidence log). Three layers: (a) the evidence directory
is excluded from the session sandbox's writable mounts — the worker's filesystem view cannot
reach it; (b) hooks execute harness-side, outside the sandbox, and hold the only write path;
(c) PreToolUse deny rules on evidence paths as defense-in-depth for topologies where mount
exclusion is unavailable. An evidence store the agent can write is worse than none — it launders
testimony as evidence.

**Crash-before-finalize.** A session that dies before its Stop hook leaves an append-only log
with no finalized manifest. The log survives on disk (it was written per-call, not at exit); the
runner marks the dispatch's evidence `PARTIAL`, which blocks report consumption (§6) but fully
supports the forensic re-ground that decides replay-vs-respawn — mutations that hit disk before
the crash are in the log.

### 4.2 Runner-populated anchors

Structured report/handoff fields that carry anchors are **populated by the runner from evidence,
not by the model**. The runner executes the anchor commands itself (`git rev-parse HEAD`,
`git status --porcelain=v1`, the canonical suite command) after the session terminates and writes
the results into the report's `runner_anchors` block (§12 schema delta). The model's own claims,
if present, are diffed against runner anchors; divergence flags the report `testimony_conflict`
and blocks downstream consumption.

### 4.3 Automated cross-session verification (`mission verify`)

The manually-ceremonied P0 becomes a gate. Before any dispatch executes, the runner runs
`mission verify --against <prior-report>`: it re-derives current disk/origin state and diffs it
against the prior report's runner anchors. Mismatch refuses the dispatch with a machine-readable
divergence report. The human paste-as-gate era performed this by attention; the gate performs it
by construction. Operator spot-checks continue — as spot-checks.

`verify`'s own output is subject to Principle 11 like everything else: it executes in the
runner/harness process and writes its derivation (commands + raw output + verdict) to the
evidence store directly. When invoked inside a session (L0/L1 pasted-dispatch use), its output
is hook-captured like any other tool call. A verify result that exists only in agent prose does
not exist.

### 4.4 Evidence-channel doctrine

- Load-bearing content crosses conversations as **path + sha8 + small verbatim excerpt**, never
  as attachment-only.
- Verdict tables, suite tallies, and push confirmations are consumed from committed evidence
  files, not from prose or attachments.
- A successor brief is testimony; every session opens by re-deriving state from disk
  (v1 ADR-008 discipline, now universal).

**Tradeoff accepted.** Evidence volume grows; `.mission/evidence/` needs a retention policy
(full retention through mission completion; archive on `mission complete --archive`). Hook
overhead adds milliseconds per tool call. Both trivially worth it: the alternative is
fabrications caught only by human checks, each consuming operator attention — the one resource the
framework exists to conserve.

---

## 5. Runtime Substrate — v2 Decisions

Short-form decisions; full ADR treatment in §11 for the load-bearing ones.

| ID | Decision | Supersedes / resolves |
|---|---|---|
| ADR-023 | **Runner substrate:** Agent SDK where the auth path permits (structured outputs, hooks, session persistence, OTel emission); `claude -p` + settings-file hooks as the subscription-auth fallback. Decision gated on documented per-plan auth verification. | Revises ADR-014 |
| ADR-024 | **Schema-enforced boundaries:** Handoff, ValidatorResult, Report, Amendment compiled to Pydantic; enforced at the runner boundary (SDK structured outputs, or post-run validation in CLI mode). Invalid → reject + respawn per brief §8. | Resolves brief §12.4 |
| ADR-025 | **Goal-conditioned workers:** optional `goal_condition` on Worker Dispatch, translated to `/goal` — "assertion targets pass locally AND schema-valid handoff exists." Scoped to one feature per worker lifespan; never spans features. Shrinks premature-stop; does not touch the unobservable-incompletion class (§11 witness remains). | Schema delta §12.1 |
| ADR-026 | **Native worktrees:** Claude Code `--worktree` + `.worktreeinclude` for fan-out isolation; custom worktree orchestration deleted. Merge sequencing and the conflict scanner remain framework-owned (brief §12.6 stays open — nothing native detects cross-worktree conflicts). | Resolves brief §12.5 |
| ADR-027 | **Layered sandboxing:** Docker (user-owned, v1 ADR-004/ADR-018) remains the outer boundary; the sandboxed Bash tool is the near-zero-startup inner layer for validator swarms where container spin-up dominates. | Updates brief §12.3 |
| ADR-028 | **Channels as event transport:** rate-limit resets, validator verdicts, CI events push into the orchestrator session; human replies return via Slack integration. Hard constraint: every channel message carrying a decision is the delivery vehicle for an artifact in `.mission/` — a message with no backing artifact is a Principle-1 violation. Sender gating whitelists exactly one producer per consumer. Workers never consume worker-fed channels. | Updates brief §6.3, §6.7 |
| ADR-029 | **Mission Control v1 via native surfaces:** agent view (live session board, needs-input flags), channels (escalation inbox), Claude Code Artifacts (shareable status pages). Custom web UI deferred. | Resolves brief §12.9 (v1) |
| ADR-030 | **Routines for cadence work:** eval-loop archive scans, prompt-regression checks, pre-witness deploy-currency verification run as scheduled routines. Anything a routine produces must land in `.mission/` to count as having happened (routines execute on Anthropic-managed infrastructure). | Updates v1 §13.2.1, brief §12.8 |
| ADR-031 | **Model routing refresh:** `coding-strong` / `qa-validator` primaries → Opus 5 (Claude Code default; 1M context); evaluate Sonnet 5 for `coding-fast`; advisor tool wired so workers get a strong-reasoner consult at amendment-proposal moments without a role change. One file (`model-routing.yaml`); brief §14.6 demonstrated. Ollama fallbacks re-benchmarked per release. | Updates v1 ADR-005 config |
| ADR-032 | **Memory hygiene:** Claude Code auto memory disabled (settings-enforced) in worker and validator sandboxes — it is persistent agent state outside the artifact store and can leak implementation history into validators. Orchestrator-side learnings are promoted to the ledger via ceremony or discarded. Fifth technique appended to v1 ADR-016. | Amends ADR-016 |
| ADR-034 | **Witness environment uniqueness:** QA-validator dispatch preconditions include an environment-fingerprint assertion (image digest, listener identity). Where the product under test consumes external events, prevention is preferred over probing: a singleton listener lease the system enforces, verified — not established — by the pre-walk probe. Generalizes the deploy-currency-before-witness doctrine. | New (from a split-brain listener incident) |
| ADR-035 | **MCP spec alignment:** `mcp-tools.yaml` gains a first-class per-tool `auth` mode field aligned with the MCP 2026-07-28 stateless/OAuth model; `claude mcp login` reduces the manual-install burden ADR-015 accepted. Recommend-don't-provision stance unchanged. | Updates ADR-015 |
| — | **ADR-013 retired** (trigger fired): computer use is built into the CLI and image handling has advanced; the `@path` pre-selection constraint relaxes to exploratory QA screenshot inspection. No framework changes required — which was the ADR's design intent. | Retires ADR-013 |
| — | **Watchlist (no decision):** agent teams graduation from experimental (governed by ADR-019 §11.1 until then); Claude Managed Agents as hosted-mode substrate (brief §12.1 note; not decided on a research preview). | — |

---

## 6. Failure Handling — Additions to Brief §8

| Failure | Detection | Response |
|---|---|---|
| **Report-layer fabrication** (claimed act absent from disk/origin) | `mission verify` anchor diff; runner-anchor vs testimony diff (`testimony_conflict`) | Refuse dispatch / block report consumption; log to ledger as integrity event; repeated instances from one prompt version escalate to human and flag the prompt in the eval loop |
| **Invalid, missing, or unfinalized (PARTIAL) evidence manifest** | Stop-hook manifest check; runner detects absent finalization after crash | Report consumption blocked; read-only forensic re-ground over the surviving append-only log decides replay-from-checkpoint vs respawn-from-handoff |
| **False-failure on async operation** (client timeout on landed work) | Read-only store check against registered class | Witness EXPECTs model async completion ("card within Ns OR store record present"); walk continues, instance banked |
| **Environment non-uniqueness at witness** (split-brain listener) | Environment-fingerprint assertion in QA dispatch preconditions (ADR-034) | Witness refuses to start until fingerprint matches; prevention preferred over probe where the product can enforce a singleton lease |
| **Evidence store unreachable / hook failure** | Hook exit-code monitoring | Halt mutation-bearing dispatches (evidence-blind mutation is the fabrication precondition); read-only work may continue |

---

## 7. Drift Defenses — One Addition to Brief §9

| Drift type | What it is | Defense |
|---|---|---|
| **Integrity drift** (new) | Agent narratives diverge from performed acts under completion pressure | Evidence plane (§4): hook-captured evidence, runner anchors, automated verify; read-only/mutation asymmetry in dispatch design; human spot-check layer retained |

The four existing rows (factual, alignment, context rot, specification) are unchanged. Note the
placement: integrity drift is *not* alignment drift — the agent knows what done means; it
misreports whether done happened. The contract can't fix it (the contract consumes reports); only
the evidence plane can.

---

## 8. Local Orchestrator Mode v2 — Deltas from v1

The v1 document's three forces, monorepo layout, `.mission/`–`.mission-runtime/` split (ADR-003,
still the load-bearing decision), bootstrap (ADR-007), batch design phase (ADR-008), and
recommend-don't-provision MCP stance (ADR-015) all stand. Deltas:

1. **Evidence plane installed** (§4) — hooks ship in the sandbox base image and `mission init`
   settings; `mission verify` gates every dispatch. This lands **first**, because it changes no
   workflow — it only makes the existing ceremony mechanical.
2. **Runner** per ADR-023/024/025: schema-validated handoffs, runner anchors, `/goal` translation.
3. **Fan-out** per ADR-026 (native worktrees) with the ADR-006 GPU gate now binding only
   Ollama-routed roles: a `mode: remote` provider option lets Claude-routed fan-out workers
   execute in Anthropic's cloud sandbox (`--remote`/`--teleport`) and survive laptop sleep.
   Tradeoff carried from FW-05: remote workers' network policy is Anthropic's surface, not the
   user's Compose file; mainline stays local by default.
4. **Ops surfaces** per ADR-028/029/030: agent view is the live board; channels feed the breaker
   and inbox; routines carry cadence work.
5. **Day-in-the-life update:** the 14:45 rate-limit pause now auto-resumes on a channel event;
   the 09:50 laptop-sleep scenario applies only to Ollama-routed workers when remote mode is
   configured for fan-out.

The human-pastes-dispatches mechanic is unchanged in this mode — that is what distinguishes it.
What changes is that the paste is verified by machinery before it executes.

---

## 9. Local Autonomous Mode (ADR-020 — full specification)

### 9.1 Definition

A deployment topology in which the **orchestrator role is held by an agent running on the same
workstation** as the artifact store, workers, and validators, with the human retained at the
touchpoints in §10. It occupies the cell between Local Orchestrator Mode (human orchestrator,
local substrate) and Hosted Autonomous Mode (agent orchestrator, cloud substrate). It is a
topology of the same framework: every schema, the lifecycle, and the role contracts apply
unchanged. **Invariance check:** the dispatch artifact a human used to paste is byte-identical in
shape to the one the orchestrator agent now writes — that is the test this mode passes.

### 9.2 Interaction mechanism — headless spawn, not session-driving

The orchestrator agent does **not** drive an interactive coding session by typing into it. It
spawns workers as pure functions:

1. Orchestrator reads spec + milestone + prior handoff from `.mission/`.
2. Orchestrator writes an immutable Worker Dispatch artifact (schema §4 of expanded-schemas,
   plus `goal_condition`).
3. Orchestrator invokes the runner (`mission dispatch <id>`); the runner runs `mission verify`,
   then spawns a fresh headless worker (Agent SDK or `claude -p`) in a worktree + sandbox with
   the dispatch as its full input.
4. Worker terminates; Stop hook finalizes evidence; runner populates anchors, validates the
   handoff schema, and emits a completion event on the orchestrator's channel.
5. Orchestrator proceeds: next dispatch, validator swarm (dynamic workflow), rework dispatch
   with failure evidence, or amendment draft.

Rejected alternative — *driving a live interactive session* (via agent-teams mailbox or channel
conversation): unversioned mid-session instructions are unreplayable inter-agent DMs
(Principle 1), and the long-lived session reintroduces context rot (Principle 5). Rejected
alternative — *agent teams as the coordination fabric*: governed by ADR-019 (§11.1); experimental
status and resumption limitations disqualify it as a foundation today.

### 9.3 Workstation wiring

| Framework element | Surface |
|---|---|
| Orchestrator (agent) | Dedicated Claude Code session at repo root, hook-scoped to brief §4.1: read-only on `src/`, write only under `.mission/` + runner invocation. PreToolUse deny rules enforce this deterministically; documented hook-over-auto-mode precedence makes hooks authoritative regardless of permission mode. |
| Workers | Headless processes in worktrees + layered sandbox, one per dispatch; visible only through artifacts, evidence, and agent view. |
| Validators | Dynamic-workflow subagent swarms at milestone boundaries. Precondition (empirically verified before trust): workflow subagents receive only assertion + built artifact — no parent context (brief §4.3 isolation contract). |
| Mission Control | Agent view (board) + channels→Slack (inbox) + Artifacts (status pages). |
| Host shell | Claude Code Desktop as the container: orchestrator pane, agent view, witness terminal, visual diff review. Desktop is furniture, not an actor. |
| Cowork | **Read-side only.** The human's leverage surface for artifacts around the mission (escalation packets, status docs, spec review). It never mutates the mission repo: a second uncoordinated mutator on shared state is exactly what brief §10 forbids. |

### 9.4 Orchestrator-agent authority boundaries

Delegable to the orchestrator agent (within §10 gates):

- Dispatch authoring and execution for mainline, fan-out, and rework.
- Validator swarm scheduling; consuming verdicts; scoping corrective work with evidence.
- **Immaterial** amendment adjudication (brief §8: "orchestrator decides; human approves if
  material"). Materiality threshold, written down: any change to scope, cost/budget, external
  commitments, contract assertions, tool scope, or anything the ledger tags operator-ratified is
  material. When in doubt, material — misclassifying toward the human costs minutes;
  misclassifying away from the human is the failure mode the framework exists to prevent.
- Circuit-breaker responses (pause/resume on rate limits, retry policy inside caps).

Never delegable (see §10): kickoff, material amendments, push, live witness, completion.

### 9.5 The delegation ladder — migration path from Local Orchestrator Mode

Adoption is incremental and reversible; each rung is one CLAUDE.md scope line + one hook rule,
diffable on disk. A mission moves up only after the evidence plane (§4) is live — autonomy
without mechanized integrity is how report-layer fabrication happens at machine speed.

| Rung | Who authors dispatches | Who executes | Human acts |
|---|---|---|---|
| **L0** (= Local Orchestrator Mode) | Human (with thinking-partner) | Human pastes/runs | Everything |
| **L1** | Orchestrator agent drafts | Human reviews + runs | Review-and-run each dispatch |
| **L2** | Orchestrator agent | Agent auto-executes **rework** dispatches (lowest judgment content: contract + evidence fully determine them); human runs the rest | Initial dispatches, amendments, gates |
| **L3** (= Local Autonomous Mode) | Orchestrator agent | Agent executes all dispatches | §10 gates only |

Rollback at any rung is deleting the scope line. The rung is recorded in the mission record so
replay knows who held the seat when.

### 9.6 Failure semantics specific to this mode

- Orchestrator-agent crash: stateless by Principle 2 — respawn reads `.mission/` and continues;
  no conversation thread is load-bearing.
- Orchestrator scope violation attempt (write to `src/`): PreToolUse deny; logged as integrity
  event; repeated attempts halt the mission to human.
- Runaway dispatch loops: circuit breaker's loop-detect (brief §6.3) applies to the orchestrator's
  dispatch rate, not just worker retries — same-feature re-dispatch beyond N without a new
  amendment or new evidence escalates.

---

## 10. Human Touchpoints — Revised (amends brief §11)

1. **Mission kickoff** — goal capture, scope negotiation, contract acceptance. Human by definition.
2. **Material amendments** — per the §9.4 materiality threshold. Immaterial amendments are
   adjudicated autonomously in Local Autonomous Mode and logged.
3. **Read→write escalation** — unchanged (configurable).
4. **Repeated failure** — unchanged (circuit breaker escalation).
5. **Push authorization** (new, first-class — ADR-033). Publishing to origin is an operator-gated
   irreversible in every local topology. In Local Orchestrator Mode the paste-of-the-push-dispatch
   is the authorization act (v1 practice, unchanged). In Local Autonomous Mode, where no paste
   exists, the gate takes physical form: `git push` is hook-blocked unless a human-created
   authorization artifact (`.mission/authorizations/<push-id>.yaml`, written by the human, hash
   binding it to the exact local tip sha) is present and current. The platform closed the
   fabricated-approval vector from its side (background-task notifications self-declare that no
   human input occurred); the artifact requirement closes it from ours. Operator browser
   confirmation of the origin tip after push remains standing law.
6. **Live witness / behavioral validation** — the human personally witnesses live-behavioral
   claims (v1 §11-witness doctrine, promoted from mission law). This cannot be
   delegated: the failure class is unobservable to the machine's own checks.
   Witness preconditions include the environment-fingerprint assertion (§6).
7. **Mission completion** — final signoff. Never automated (brief §7, §13).

Between touchpoints the human monitors via agent view and the channel inbox but is not expected
to act.

---

## 11. Load-Bearing ADRs (full form)

### 11.1 ADR-019 — Agent-teams adoption policy

**Decision.** Agent teams (experimental, flag-gated) are adopted only under constraint:
(a) teammate-to-teammate mailbox messaging **between workers is forbidden** — Principle 1; DM'd
context is unversioned, unreplayable, invisible to the trace store; (b) the shared task list is
usable only if mirrored by hook from `~/.claude/tasks/` into `.mission/` so it is a versioned
artifact — as shipped it lives outside the monorepo and therefore outside mission truth;
(c) lead-as-dispatcher mapping (lead→orchestrator function, teammates→fan-out workers) is
permitted in principle but **not adopted as the topology foundation** while the feature is
experimental with documented resumption/shutdown limitations — resumption gaps are disqualifying
where replayability is the price of admission (Principle 9).

**Alternative considered.** Full adoption as the Local Autonomous coordination fabric.

**Tradeoff accepted.** We forgo built-in coordination convenience and pay for headless-spawn
plumbing we own. In exchange: every inter-agent communication remains an artifact, and the
topology stands on GA surface area. **Trigger to revisit:** feature exits experimental AND
per-team messaging can be disabled or scoped.

### 11.2 ADR-020 — Local Autonomous Mode

As specified in §9. **Alternative considered:** skip straight to Hosted Autonomous Mode.
Rejected: the local artifact store, the operator's verification layers, and the witness doctrine
are exactly what make report-layer fabrication survivable; hosted autonomy without a proven evidence
plane repeats them without the uncheatable human nearby. Local Autonomous Mode is the proving
ground for the machinery hosted mode will require. **Tradeoff accepted:** a third topology to
maintain; bounded by the fact that it shares every layer with Local Orchestrator Mode except who
holds the orchestrator seat. **Invariance check:** all schemas unchanged; the dispatch artifact
is identical whether a human or the orchestrator agent writes it.

### 11.3 ADR-021 — The evidence plane

As specified in §4 (hook-captured evidence, runner anchors, automated verify, channel doctrine).
**Alternative considered:** stricter anti-fabrication prompting plus continued human ceremony.
Rejected: prompting does not hold under completion pressure;
ceremony works but consumed the resource the framework exists to conserve (brief §1). **The
principle:** integrity is enforced where the agent cannot reach — the hook process, the runner,
the human's browser — never by exhortation. **Invariance check:** no schema changes to existing
artifacts; the Report/Handoff gain an additive `runner_anchors` block (§12).

### 11.4 ADR-022 — `mission verify` as a dispatch gate

As specified in §4.3. **Alternative considered:** keep P0 as a pasted read-only dispatch.
Rejected as the default: it works (a P0 or an operator check is what catches report-layer
fabrication) but scales with human attention, not mission length. The pasted form remains available
as a manual instrument. **Tradeoff accepted:** the gate adds seconds per dispatch and one more
component to keep honest — mitigated by making `verify` itself trivially auditable (it prints
the commands and raw output it derived from, per the anti-fabrication rider's own rules).

### 11.5 ADR-033 — Push authorization as a first-class touchpoint

As specified in §10.5. **Alternative considered:** trust the orchestrator agent to push after
green gates, notifying the human. Rejected: push is the framework's irreversibility boundary
with the outside world, push confirmations are among the claims an agent can fabricate,
and the paste-as-gate mechanism this replaced was load-bearing precisely because a human
act stood between green and origin. **Invariance check:** Local Orchestrator Mode behavior
unchanged (paste remains the act); only the physical form of the gate varies by topology.

---

## 12. Schema Deltas (amendments to `expanded-schemas.md`)

All additive; no existing field changes. Portability across topologies preserved.

### 12.1 Worker Dispatch — new optional field

| Field | Type | Required | Description |
|---|---|---|---|
| `goal_condition` | string | no | Completion condition the runner translates to `/goal`. Must be expressible as: all `assertion_targets` pass locally AND a schema-valid handoff exists at the expected path. Scoped to this dispatch only. |

### 12.2 Handoff / ValidatorResult / Report — new runner-populated block

```yaml
runner_anchors:                 # written by the runner from evidence, never by the model
  head_sha: "..."               # git rev-parse HEAD at session end — always present
  porcelain: [ "...", "..." ]   # git status --porcelain=v1, verbatim — always present
  suite:                        # present only for dispatch kinds that gate on the suite
    command: "<canonical suite command from mission config>"
    passed: 0
    failed: 0
    skipped: 0
    expected_failures_matched: true   # against tools/mission-cli/config/expected-failures.yaml
  evidence_manifest: ".mission/evidence/<dispatch_id>/manifest.json"
  evidence_manifest_sha256: "..."
  testimony_conflict: false     # structured-field mismatch only; see below
```

**Anchor scoping by dispatch kind.** `head_sha`, `porcelain`, and the manifest fields are
universal. The `suite` block is required for build-, rework-, and close-class dispatches and
absent for read-only and micro-ceremony dispatches — a full-suite run per micro would contradict
the micro-dispatch doctrine, which keeps mutation-bearing dispatches minimal.

**`testimony_conflict` is decidable, not fuzzy.** The model never populates anchor fields (the
schema gives it no such fields); the flag fires only when a model-populated structured field
(e.g., a claimed test tally in a summary field) contradicts a runner anchor. Contradictions in
free prose are surfaced as lint warnings for the human, never as automated verdicts — prose is
testimony and is treated as such in both directions.

**Expected-failure manifest** gets a framework home: `tools/mission-cli/config/
expected-failures.yaml`, committed, amendment-gated (mission-agnostic mechanism; each mission
populates its own — the manifest content is mission truth, the mechanism is framework).

### 12.3 New artifact — Evidence Manifest

Per dispatch: `{dispatch_id, session_id, entries: [{ts, tool, command, exit_code, stdout_sha256,
stderr_sha256, path}], finalized_at}`. Written by the Stop hook. Append-only during the session;
immutable after finalization. Committed at ceremony boundaries.

### 12.4 New artifact — Push Authorization (Local Autonomous Mode only)

`{push_id, authorized_tip_sha, authorized_by: human, created_at, expires_at}` — created by the
human, consumed once by the hook-gated push, retained for audit. Mechanics that close the two
obvious holes: (a) **TOCTOU** — the hook re-derives `git rev-parse HEAD` at push time and refuses
unless it equals `authorized_tip_sha` exactly; an authorization is for one specific tip, and any
commit landing after authorization voids it; (b) **single use** — on successful push the hook
rewrites the artifact with `consumed_at` + the origin tip it verified, tombstoning it; a consumed
or expired authorization is refused. Operator browser confirmation of the origin tip remains the
final layer regardless.

---

## 13. Supersession & Documentation Map

So decisions don't escape into this document alone:

1. **`local-orchestrator-mode.md`** — superseded by this document as the local-modes canon.
   ADR-001–ADR-012, ADR-015–ADR-018 carried forward unchanged; ADR-005 config refreshed
   (ADR-031); ADR-006 scope-narrowed (§8.3); ADR-013 retired; ADR-014 revised (ADR-023);
   ADR-016 amended (ADR-032).
2. **Brief** — amendments: new §15 *Deployment Topologies* (the §3 table); §2 add Principle 11;
   §6 add the Evidence Plane; §6.2/§6.3/§6.7 per ADR-028/029; §8 add the §6 rows; §9 add
   integrity drift; §11 replaced by §10 above; §12 resolutions — 12.4 (ADR-024), 12.5 (ADR-026),
   12.7 (OTel via SDK emission), 12.9 (ADR-029 for v1); 12.6 explicitly still open.
3. **`expanded-schemas.md`** — additive deltas per §12.
4. **`amendment-ceremony-precedent.md`** — unchanged; gains a note that in Local Autonomous Mode
   phases owned by "the human moving a file" are owned by the human *creating the authorization
   artifact* for material amendments, and by the orchestrator agent for immaterial ones.
5. **`bootstrap-instructions-for-claude-code.md`** — regenerate after the runner/evidence-plane
   implementation exists (bootstrap must install hooks + verify into `mission init` output).

## 14. Adoption Sequence for a Running Mission

Framework changes land between arcs; the mission continues under current standing law until each
component exists. Order is chosen so every step reduces risk before any step adds autonomy:

1. **Evidence plane** (§4.1–4.2): hooks + runner anchors. No workflow change — current ceremony
   becomes mechanically backed. Standing fabrication countermeasures remain in force throughout.
2. **`mission verify`** (§4.3): automated P0 gates dispatches; pasted P0 becomes the spot-check.
3. **Runner** (ADR-023/024/025): schema-validated handoffs, `/goal` dispatches.
4. **Ladder L1** (§9.5): orchestrator agent drafts dispatches; the operator reviews and runs —
   formalizing what the thinking-partner session already does, with the drafts now machine-checked.
5. **L2 → L3** as trust accumulates, each rung a reversible one-line change, with §10 gates
   (witness, material amendments, push authorization, completion) never delegated at any rung.

## 15. Success Criteria (extends brief §14)

7. A full milestone cycle (dispatch → build → validate → rework → close) completes in Local
   Autonomous Mode with human action only at §10 gates.
8. Zero report-layer fabrications reach a consumed artifact across an arc — measured, not
   asserted: every anchor in every consumed report matches its evidence-manifest entry.
9. The operator's per-arc attention cost measurably drops from the pre-adoption baseline while catch
   capability (spot-check + witness) is preserved.
