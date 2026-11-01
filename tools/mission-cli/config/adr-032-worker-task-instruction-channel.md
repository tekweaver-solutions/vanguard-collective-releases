# ADR-032 — Worker Task-Instruction Channel

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the
> decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Renumbered from a colliding ADR-007.** This decision was originally
> authored as "ADR-007", which collided with the *different* folded ADR-007 in
> `local-orchestrator-mode.md` §3 ("Bootstrap is a deterministic script") — a number
> collision, not a duplicate. Resolved by renumbering this standalone "Worker
> Task-Instruction Channel" decision to ADR-032 (next free id); the folded ADR-007
> (Bootstrap script) retains 007.
>
> **Drafted to close** a gap a first-dispatch pre-flight can surface:
> the worker is never told its task. First ADR to use the
> `config/proposals/` physical staging path (promoted via git mv, mirroring the
> mcp-tools.yaml acceptance); ADRs 019–025 were authored directly into
> `config/` with the Stage-A status line as their staging signal.
>
> **Empirical grounding:** A worker spawned as
> `claude -p` with only `_HANDOFF_INSTRUCTION_TEMPLATE` (the handoff
> *reporting* protocol) via `--append-system-prompt` receives no positional prompt, no
> piped stdin, and no spec-derived objective
> reaches it. The worker is told
> how to file its handoff but never what to build.
> No framework decision
> specified how the framework's `claude -p` worker receives its
> per-dispatch task. This was an **unseen gap**, not a deferred decision: the
> design implicitly assumed the worker would derive its task from `feature_id` +
> `assertion_targets`, and the presence of those fields in the handoff-write
> instruction (as the `completed_assertions` allowlist) masked the absence of a
> task-input channel through every sub-deliverable and passing test before the first live dispatch.

---

## Context

A worker has three logically distinct inputs, only two of which the framework
previously accounted for:

1. **Role** — how a worker behaves overall (per ADR-023, a versioned role-prompt
   read at agent-construction time; registry-distributed per ADR-012/ADR-017).
2. **Task-level know-how** — how to produce an artifact *kind* (per ADR-023,
   versioned skills under `skills/`, read at task-execution time).
3. **The per-dispatch task itself** — *produce THIS artifact, for THIS feature,
   against THESE assertions.* This third channel was never specified.

ADR-023 deliberately separated role (prompt) from know-how (skill) and asserted
both are orthogonal, versioned, and independently registry-pinned. The
per-dispatch task is a third surface, orthogonal to both: a role-prompt teaches
behavior, a skill teaches how-to-produce-an-artifact-kind, and neither says
"produce the <artifact> for <feature> such that its assertions pass." That
sentence is the task, and nothing in the framework constructed or delivered it.

This ADR defines that third channel. It must conform to:
- **Brief §2 (agents are pure functions on artifacts).** The task is derived from
  versioned artifacts (the spec feature definition + the assertion files the
  dispatch names), not from out-of-artifact operator improvisation. An operator
  freeform prompt as the *primary* task source would route an unversioned,
  non-reproducible instruction to the worker — the exact alignment-drift entry
  point the framework exists to prevent.
- **ADR-023's construction/execution split.** The task brief is a third surface,
  not an overload of the role-prompt (system-prompt) channel.
- **Brief §14.3 (replayability).** Any past dispatch's task must be inspectable
  and reconstructible from the trace store and committed artifacts.

---

## Decision

The framework constructs a **per-dispatch task brief** and delivers it to the
worker as a committed, inspectable artifact. Six sub-decisions:

### 1. Channel shape — a task-brief file the worker is instructed to read

The runner writes a `task-brief.md` for the dispatch and instructs the worker to
read it via the existing `--append-system-prompt` channel (a short pointer added
alongside the handoff protocol). The task brief is **not** passed as a positional
prompt, not piped to stdin, and **not** merged into the role-prompt
system-prompt fragment.

This keeps three surfaces clean and separately versionable: **role** (system
prompt, per ADR-023), **task** (the brief file, this ADR), **reporting** (the
handoff instruction). Pre-spawn, the runner verifies the brief file exists and is
non-empty (extending the `_validate_pre_spawn` gate); a missing brief is a
dispatch-construction error, not a silent empty-task spawn.

### 2. Composition source — framework-constructed from artifacts

The runner assembles the brief deterministically from the dispatch metadata:
- `feature_id` → the feature's definition in `spec/v{spec_version}.yaml`.
- each id in `assertion_targets[]` → the corresponding
  `.mission/contract/assertions/A-NNN.yaml`.

The brief states the objective ("implement {feature_id}; make {assertion_targets}
pass"), **points the worker at the versioned artifacts to read** (it indexes them
by path + version; it does not inline their full text, so the brief cannot drift
from the source), and references the handoff protocol. The worker reads the
frozen contract directly. The brief is the *objective + index*, not a copy of the
contract.

### 3. Skills interaction — optional pointer in v1; auto-selection deferred

The brief schema includes an optional `skills:` list naming skill ids the worker
should consult (per ADR-023). In v1 this is **hand-specified** by the dispatching
operator when a worker is known to need a particular skill; the framework does
**not** auto-resolve skills by artifact kind. Skill auto-selection and `skills/`
registry wiring remain post-MVP (per the existing prompt/skill-registry
deferral). Rationale: skill *selection* is its own design problem; coupling it to
the blocking task-channel fix would widen this ADR past its purpose.

### 4. Reproducibility — the task brief is a committed artifact

The constructed `task-brief.md` is committed under
`.mission/dispatches/<dispatch_id>/task-brief.md` (a new committed artifact kind),
not left runtime-only in `.mission-runtime/`. This gives full git-inspectable
history of the exact task each worker was given, independent of the ability to
regenerate it.

This introduces a new committed artifact to the `.mission/` tree and a
corresponding schema entry in `expanded-schemas.md` (the Task Brief artifact:
fields, authorship, lifecycle, readers). The dispatch's runtime scratch
(`tool_scope.json`, `hook-settings.json`, `handoff.json`) stays gitignored under
`.mission-runtime/`; the task brief is promoted to `.mission/` because it is part
of the dispatch's durable, replayable contract — the worker's input of record.

### 5. Operator override — bounded optional addendum

`mission-dispatch.ps1` gains an optional `-OperatorNote` (string) parameter. When
supplied, the runner appends it to the constructed brief under a clearly labeled
`## Operator note (out-of-contract)` section — **additive to**, never replacing,
the artifact-derived objective. Its purpose is bounded context: rework guidance
("the prior worker's handoff stubbed the migration; complete it"), or focus
hints. Because the note is operator-supplied and not reproducible from the
contract, it is **recorded** in the committed task brief and traced (see §6) so
the audit trail is complete even where reproducibility-from-contract does not
apply. A note that contradicts the spec is visible beside the spec-derived
objective, not a silent override; any worker action on it surfaces in the handoff.

### 6. Trace surface — `brief_version` on LLMCallTrace; closes the runner gap

`expanded-schemas.md §9` (TraceEvent / LLMCallTrace) gains an optional
`brief_version` field, parallel to the existing `prompt_version`. `prompt_version`
tracks the role-prompt; `brief_version` tracks the version of the **task-brief
template** that generated the dispatch's brief. Capturing the constructed task
brief in the trace also closes the runner gap (`runner.py` notes the user-message /
task fragment is not currently captured): the eval loop (§14.5) can now correlate
which task-brief template produced which handoff outcomes.

The task-brief *template* (the framework-side generator that turns dispatch
metadata into brief prose) has the same v0 home and registry-promotion debt as
`_HANDOFF_INSTRUCTION_TEMPLATE`: an inlined constant now, registry-pulled when
`prompts/` is initialized (post-MVP, per the existing ledger deferral). Its
inlined version string is what `brief_version` records until promotion.

---

## Alternatives considered

**Operator-supplied freeform prompt as the primary task source.** Rejected. Not
reproducible, bypasses the frozen spec, and is precisely the unversioned-
instruction path that produces alignment drift (brief §2). Operator input is
retained only as the bounded §5 addendum, recorded and traced.

**Deliver the task via the role-prompt (`--append-system-prompt`) fragment.**
Rejected. Collapses the role/task distinction ADR-023 deliberately drew; a worker's
role ("how you behave as a coding worker") and its task ("build this feature's schema")
version and change independently and must remain separate surfaces.

**Positional-prompt or stdin delivery.** Rejected. Both make the task ephemeral —
it exists only in the spawn invocation, not as a durable artifact — which defeats
inspectability and replay (§14.3). The worker's spawn leaves the
stdin channel unused; formalizing it as the
task channel would bind the worker's task to a non-artifact.

**Runtime-only task brief (gitignored), reconstructed-on-demand for replay.**
Considered and rejected in favor of §4's committed artifact. The brief *is* a pure
function of committed inputs, so determinism alone would satisfy replay — but a
committed brief additionally gives git-inspectable history of the exact text each
worker saw, which is the stronger audit position. The cost (a new committed
artifact kind + schema entry) is accepted deliberately.

**Inline a `_TASK_INSTRUCTION_TEMPLATE` constant with no schema/trace work
(mirror the existing handoff-instruction shortcut).** Rejected as the *complete*
solution. The inlined template is the accepted v0 *home* for the generator (§6),
but stopping there would repeat the un-versioned-prompt debt the ledger already
flags for `_HANDOFF_INSTRUCTION_TEMPLATE` and would leave the new channel
invisible to the eval loop. The `brief_version` trace field (§6) is the minimum
needed to avoid building the channel blind.

---

## Tradeoff accepted

- **Two framework-document changes.** The §4 committed-artifact choice and the §6
  trace field both modify `expanded-schemas.md` (a new Task Brief artifact schema;
  a `brief_version` field on §9). This is heavier than a runtime-only design would
  have been, and per the amendment-ceremony precedent, framework-document changes
  go through a framework-level ADR (this one), not a mission amendment. The cost is
  paid for the audit position in §4.
- **A new committed artifact kind in `.mission/`.** `.mission/dispatches/` becomes
  a tracked tree. Cost: every dispatch leaves a committed brief; the `.mission/`
  tree grows per dispatch. Mitigated by the brief being small (objective + index +
  optional note) and high-value for replay/audit.
- **Inlined template debt carried, not closed.** The brief generator lives as an
  inlined constant until `prompts/` registry init (post-MVP). Same deferred-
  promotion debt as the handoff instruction; `brief_version` records the inlined
  version meanwhile. Accepted because standing up the registry is out of scope for
  unblocking dispatch.
- **No automatic skill provisioning in v1.** Workers get task-level know-how only
  if the operator hand-names a skill (§3). Acceptable: the blocking problem is the
  task channel, not skill resolution; a schema-production dispatch needs no committed skill.
- **Operator note is an un-reproducible surface.** §5 admits operator-supplied
  text that cannot be regenerated from the contract. Bounded (additive, labeled,
  recorded, traced) so the audit trail stays complete, but it is the one place a
  human can introduce non-contract content into a worker's input. Named here so
  the tradeoff is explicit rather than hidden.

---

## Consequences for implementation

- `runner._build_argv` / pre-spawn: construct + write `task-brief.md`, verify it
  exists, add the read-the-brief pointer to the appended system prompt.
- New brief-generator module (inlined template v0) turning `WorkerDispatch`
  metadata + spec + assertion files into brief prose.
- `mission-dispatch.ps1`: add optional `-OperatorNote`; thread through args.json →
  `DispatchInputs` → the generator.
- `expanded-schemas.md`: add the Task Brief artifact schema; add `brief_version`
  to §9 LLMCallTrace.
- `schemas.py`: add `brief_version` to the LLMCallTrace model; add a TaskBrief
  model. The committed artifact is schema-validated at write time (required,
  per the write-time-enforcement cross-cutting note).
- Trace: populate `brief_version` and capture the constructed brief (closes the runner gap).

## Doc-update targets

- `expanded-schemas.md` — new **Task Brief** artifact section; `brief_version`
  field added to §9 TraceEvent/LLMCallTrace. (Operator owns framework-doc edits.)
- `local-orchestrator-mode.md` — fold ADR-032 into the canonical ADR list on
  acceptance; note the third worker-input channel in the §6 worker-runtime
  description.

## References

- ADR-023 (skills as committed artifacts) — the role/task channel split this
  conforms to and extends with the third (per-dispatch task) channel.
- ADR-012 / ADR-017 (prompt registry; out-of-repo) — the eventual home for the
  brief-generator template, post-MVP.
- Brief §2 (pure functions on artifacts), §14.3 (replayability), §14.5 (eval loop).
- `expanded-schemas.md` §4 (WorkerDispatch — the metadata this ADR composes from),
  §5 (Handoff — the reporting surface this ADR is distinct from), §9 (TraceEvent).
- `_HANDOFF_INSTRUCTION_TEMPLATE` (the handoff-write instruction) — the sibling
  prompt surface, once treated as the only one; this ADR
  identifies the second, unseen surface (the per-dispatch task)
  that the template's allowlist fields had masked.
