# ADR-044 — Two-step bump (accept-unbound → decompose-bind) is the default; consolidation is an operator-gated per-use exception

> **Status:** **Accepted** — operator-ruled framework doctrine, resting-status rule S1 per ADR-033.
> Rests at **"Accepted"** in the native S1 form. **Standalone-canonical in `tools/mission-cli/config/`** (same
> family + home as ADR-019..043) per ADR-033; the standalone file IS the decision.
>
> **Nature & path.** A **lifecycle-CLI process/governance decision** about the lifecycle CLI's contract ceremony (the
> `mission-promote-contract` → `mission-spec-bump` bind sequence). It records ceremony doctrine only:
> **no spec version, no contract, no code, no mission-state change.** Follows the framework-ADR path (a
> standalone `adr-0NN-<slug>.md`), NOT the mid-mission amendment ceremony. It does not reach back to
> consolidations made before it; it is a forward rule.

## Context

The lifecycle CLI's contract ceremony binds a contract family to feature(s)/milestone in TWO spec-bumps: (1) **accept
-unbound** — ratify the promoted assertions into the spec chain with `feature_id`/`milestone_id` null; (2)
**decompose-bind** — create the feature + milestone and flip the assertions' binding. The two bumps can
also be **consolidated** into a single
bind-bump (for example when the bind step is itself a supersession amendment).
Until this ADR there was no recorded doctrine on when consolidation is permissible; this ADR fixes it.

## Decision

**Two-step bump (accept-unbound → decompose-bind): default, with operator-gated consolidation.**

The contract ceremony's two-step bump is the DEFAULT. It preserves an operator-review checkpoint between (1)
accepting a contract family as accepted-unbound and (2) binding it to feature(s)/milestone. The gap is the
cheapest place to catch a wrong binding (wrong feature, wrong milestone, an assertion that shouldn't be in the
roster) BEFORE it is sealed in spec history.

The two bumps MAY be consolidated into a SINGLE bump ONLY with explicit, per-use operator approval, granted
AFTER a pros/cons explanation. Charter authorization alone is NOT sufficient: consolidation WAIVES the
inter-bump review gate, so waiving it requires its own review. This is a per-use exception, NOT a blanket —
each future use requires fresh operator approval.

Rationale recorded: the split fails cheap (a bad binding is a re-author); consolidation fails expensive (a
sealed bad binding needs a correction entry + possibly a supersession). The exception is warranted mainly when
the bind step is ITSELF a supersession amendment (so consolidation makes the supersession one unambiguous entry
the guard assertion points at) AND the charter has already fixed the feature topology.

Earlier uses (RETROACTIVE NOTE): bindings consolidated into a single bump before this gate was established
(each bind step itself a supersession amendment) are not retroactively violations. Such bindings can be validated,
closed, and correct — no bad-binding harm — but they were NOT themselves operator-gated by this rule (it did not
yet exist). The rule applies forward, to every consolidation after it; earlier ungated uses are
not reopened. The default two-step split needs no approval.

## Consequences

- The default (two-step) is the safe path; orchestrators take it unless the operator has explicitly approved
  consolidation for the specific bind, after the pros/cons.
- A future consolidated bump that ships WITHOUT a recorded per-use operator approval is a process violation, not
  a style choice — the review gate it waived was waived without review.
- This ADR changes no tooling: `mission-spec-bump` already supports both shapes (the split is two invocations;
  consolidation is one bind-bump). The gate is procedural, enforced at the contract ceremony, not in code.

## Reference

Lifecycle-CLI family ADR-033 (standalone-canonical). Related: the two-step default and the
consolidated bind-bump it permits (Decision). The contract-ceremony tooling: `mission-promote-contract.ps1`
+ `mission-spec-bump.ps1`.
