# ADR-027 — Dispatch write-time validation: the brief-asserts-what-the-system-cannot-honor defect class

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** a post-run review, after the same defect shape recurred five times across one mission's setup and execution.
>
> **Empirical grounding:** a live-run report's finding (the brief instructed commit-then-handoff while `tool_scope` excluded every git-capable tag); the false-objective finding (`objective` rendered "make all assertions pass" while most were structurally un-closeable without another feature); the doc-stopgap finding (every ADR Status header asserted promotion into a doc that was not version-controlled); the recurring untracked-task-brief finding; the schema-layer finding that `tool_scope` accepts any non-empty string (a typo'd tag silently produces a 100%-DENY run).

---

## Decision

There is one recurring defect, observed five times in one mission:

1. **False objective.** The task-brief `objective` field, deterministically derived as "implement <feature> such that [all assertion_targets] pass," asserted an outcome most targets could not reach (their `evidence_required: test_output` is produced by another, not-yet-built feature's validator).
2. **Commit-vs-scope contradiction.** The `operator_note` instructed commit-then-handoff while the dispatched `tool_scope` (`[repo.read, worktree.write]`) contained no git-capable capability — a worker so dispatched cannot commit; at best it identifies the contradiction and exits honestly without commits.
3. **Typo'd capability.** `tool_scope` is typed as a list of any non-empty strings (`schemas.py`); a mistyped tag (`worktree.wrte`) passes schema validation and produces a 100%-DENY run that burns wall-clock before the cause is visible.
4. **Phantom promotion target.** *(Resolved by ADR-033.)* Every standalone ADR's Status header then asserted "promotion into `local-orchestrator-mode.md`" — a file not version-controlled or present until a stopgap copy. ADR-033 abolished the fold-in promotion (standalone is canonical), so the phantom target no longer exists.
5. **Untracked committed-truth.** The runner writes the committed task-brief to `.mission/dispatches/<id>/` but does not commit it, leaving committed-truth artifacts untracked and dirtying the tree until a manual catch-up — a recurring catch-up, not a one-off.

The common shape: **an artifact asserts something the system cannot honor, and nothing checks the assertion against reality at the point the artifact is produced.** The fix is uniform — validate dispatch artifacts against the reality they assert, at construction time, before the dispatch is acted on.

This ADR establishes **dispatch write-time validation** as a framework discipline and specifies the first three checks (the ones with a concrete locus today). The other two instances (4: ADR promotion targets; 5: runner-commits-the-brief) are recorded here as the same class with their own follow-up loci, so the discipline is understood as general rather than three-checks-specific.

### Decision 1 — `tool_scope` is validated against the capability vocabulary at dispatch-construction

Every entry in a `WorkerDispatch.tool_scope` must be a known capability tag (a key of the merged `CapabilityMap`, i.e. `_NATIVE_MAP` ∪ `_MCP_MAP`, plus the worker-grantable subset). An unknown tag fails dispatch-construction with a reason naming the offending tag and listing the valid vocabulary — it does not reach a live spawn. This converts the typo→100%-DENY-run failure (instance 3) into a construction-time rejection.

### Decision 2 — `shell.exec.*` is rejected at dispatch-construction until C2 (enforces ADR-026 Decision 3)

A `tool_scope` containing `shell.exec.sandboxed` or `shell.exec.unsandboxed` is rejected at construction with a reason pointing at the unbuilt C2 sandbox/egress layer (ADR-026 Decision 3). This is the enforcement arm of ADR-026's grant-level egress-deferral: the prohibition lives here because dispatch-construction is where `tool_scope` is assembled, and the gateway (`Gateway.check`) is deliberately pure-decision and has no dispatch-construction context.

**This construction-time check is the SOLE defense, not a backstop.** The gateway will still ALLOW a `shell.exec.*`-authorized Bash call if such a tag somehow reaches a worker's scope: `is_command_in_allowlist` returns ALLOW immediately for any `authorized_capability != "test.run"` (confirmed by the test `test_shell_exec_sandboxed_bash_bypasses_test_run_allowlist`, where a `shell.exec.sandboxed` worker runs a charset-failing command and gets exit 0). There is no second wall. Until C2 exists, the only thing standing between a `shell.exec.*` grant and the ungated egress surface is this construction-time rejection — so it must be unconditional and must fail closed (a malformed or unparseable `tool_scope` is rejected, not waved through).

### Decision 3 — the objective is reconciled against assertion evidence-dependencies

The task-brief `objective` must not assert closure of assertions whose `evidence_required` cannot be satisfied within the dispatch's own feature scope. Where an assertion's evidence is produced by another feature's validator (a cross-feature dependency, e.g. one feature's `test_output` assertions depending on a validator another feature builds), the brief-generator's objective-derivation must produce "produce <feature>'s artifacts; N of M targets are evidence-blocked on other features" rather than "make all M pass."

Until the brief-generator is fixed (a `brief_version` bump that makes objective-derivation consult `evidence_required` per target), the **`operator_note` stopgap** is the interim mechanism — but it is recorded as a **stopgap, not the fix**, so the generator defect is not marked resolved by the workaround. The `operator_note` reframes the goal additively without contradicting the (still-wrong) auto-derived `objective`; the durable fix is the generator change.

### Non-goal for this ADR (recorded so the class is not under-scoped)

- **Instance 4 (ADR promotion targets)** is the same defect at the documentation layer; its fix was the ADR-extraction resolved by ADR-033 (standalone-canonical) + seam b1, not a dispatch-construction check.
- **Instance 5 (runner-commits-the-brief)** is the same defect at the runner layer; its fix is an ADR-032-implementation change (commit the task-brief at spawn so committed-truth is durable immediately), recorded as its own ledger entry.

Naming these here, outside this ADR's enforced checks, is deliberate: it makes "validate the artifact against what the system can honor" a recognized class so future artifacts (briefs, ADRs, runner outputs) are checked against it, rather than rediscovering the shape a sixth time.

---

## Why this is forced by the framework's principles

- **§2.7 — alignment drift goes to the validation contract, factual drift to the ledger.** A brief that asserts an unreachable outcome is alignment drift introduced *by the framework itself*; catching it at construction is the validation-contract-before-action discipline applied to the dispatch artifact.
- **ADR-020 — verify at the seam.** ADR-020 verifies tool-call *effects* against filesystem truth at the runner seam. This ADR is the same principle applied one step earlier: verify the dispatch artifact's *assertions* against capability/contract truth at the construction seam, before the worker is spawned.
- **§14 criterion 4 — contract violations caught before reaching the human.** A 100%-DENY run from a typo'd tag, or an honest-but-confused worker thrashing against a false objective, are failures that should be caught at construction, not surfaced to the operator after wall-clock is spent.

## Operational integration

- The dispatch-construction validator lives where `WorkerDispatch` + `TaskBrief` are assembled (the runner's pre-spawn path / `mission-dispatch.ps1` dry-run render). Decision 1 and Decision 2 are `tool_scope` checks against `CapabilityMap.tags()` and the `shell.exec.*` prohibition list. Decision 3 is a brief-generator change consulting each target assertion's `evidence_required`.
- Decisions 1–2 are mechanical and land first. Decision 3 (generator objective-derivation) is the `brief_version`-bumped change; the operator_note stopgap covers the interim and is explicitly labeled as such in its ledger entry.

## Invariants preserved

- **The gateway stays pure-decision.** None of these checks move into `Gateway.check`; they live at dispatch-construction, upstream of the gateway.
- **The brief still indexes, does not inline** (ADR-032 decision 2). Decision 3 changes the *objective sentence*, not the no-inline-contract rule; the brief still points the worker at the frozen assertion files.

## Consequences for implementation

1. Dispatch-construction validator: `tool_scope` ⊆ known vocabulary (Decision 1); no `shell.exec.*` until C2 (Decision 2).
2. Brief-generator objective-derivation consults `evidence_required` per target (Decision 3); `brief_version` bump.
3. Regression probes: typo'd tag rejected at construction; `shell.exec.*` in `tool_scope` rejected; an objective derived for a feature with cross-feature-dependent assertions reads "N evidence-blocked" not "all pass."
4. A ledger entry records the defect class and its five instances.

## Doc-update targets

- Canonical as this standalone file per ADR-033 (standalone-canonical); no fold-in step.
- Update brief §6.2 / the dispatch lifecycle description to name dispatch-construction validation as a pre-spawn gate.

---

## Alternatives considered

- **Fix each instance independently, no named class.** Rejected: the shape recurred five times; treating each as a one-off guarantees a sixth. Naming the class is what makes future artifacts self-check.
- **Enforce the `shell.exec.*` prohibition in the gateway.** Rejected: the gateway is pure capability→tool matching with no dispatch-construction context (it cannot know a `tool_scope` was *assembled* with a prohibited tag vs. a worker *attempting* one). Construction-time is the correct seam.
- **Make `tool_scope` a typed enum at the schema layer instead of a construction check.** Reasonable and complementary — a Pydantic `Literal`/enum would reject unknown tags at parse time. Deferred as an implementation choice within Decision 1 rather than a competing decision; the construction check is the floor, a typed schema is a stronger form of the same guarantee and can replace it.
- **Treat the false objective as a worker-prompting problem, not a generator defect.** Rejected: the worker behaved correctly given a wrong objective (it did not fabricate). The defect is in the artifact the framework generated, so the fix belongs in generation, not in compensating prompts.

## Tradeoff accepted

- **Dispatch-construction does more work before spawn.** A vocabulary check, a prohibition check, and (Decision 3) an evidence-dependency analysis per target. Mitigated: all three are cheap relative to a spawned run, and each prevents a class of failure that currently costs wall-clock or operator attention to diagnose.
- **Decision 3 requires the brief-generator to read the contract's `evidence_required`**, coupling objective-derivation to assertion content it previously ignored. This is the point — the previous decoupling is exactly what produced the false objective — but it does add a contract read to brief construction.
- **The class names two instances (4, 5) it does not fix here.** Recording-without-enforcing risks looking like deferral-as-avoidance. Mitigated by each having a named follow-up locus (the extraction mission; the ADR-032 runner change) and a ledger entry, so they are tracked, not dropped.
