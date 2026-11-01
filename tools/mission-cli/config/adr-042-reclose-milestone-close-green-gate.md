# ADR-042 — Reclose / milestone-close green-gate: a baseline-relative full-collection-green precondition on the close transitions

> **Status:** **Accepted** — operator-ruled framework doctrine, resting-status rule S1 per ADR-033.
> Rests at **"Accepted"** in the native S1 form. **Standalone-canonical in `tools/mission-cli/config/`** (same
> family + home as ADR-019..041) per ADR-033; the standalone file IS the decision.
>
> **Nature & path.** A **framework capability / lifecycle decision in the lifecycle-CLI family** — it hardens the
> *constructive* lifecycle CLI's two CLOSE transitions (`reclose`, `close-milestone`) with a new
> precondition. Authored as a framework-ADR; it **discharges** the
> reclose-gate recommendation that a closure-integrity finding raises (a close transition
> that proceeded over a masked failure, with no automated gate to stop it).
> Follows the
> **framework-ADR path** (a standalone `adr-0NN-<slug>.md`), **NOT** the mid-mission amendment ceremony: it
> **changes no spec version**, adds no schema/field/enum, and **writes no CLI code and no validation contract** —
> the gate function, its contract assertions, the manifest seeding, and the two call-site insertions are the
> **next seams (DECOMPOSE → CONTRACT-BEFORE-CODE → BUILD), gated by this ADR**. It records **gating doctrine only**.

## Context

**The empirical grounding is a recurring closure-integrity finding — THREE classes of instance.** A mission
milestone or re-closure transitioned to a closed/"green" state while the relevant test suite carried a masked or
uncaught failure, because **no close transition ever gated a COMPLETE green run**:

1. **Masked failure** — a milestone closed with every assertion passing while a test carried a `finalize`-signal
   `AttributeError`, masked because its test folder was outside the default `testpaths`.
2. **Unsatisfied clause** — an architecture model carried cosmetic-FALSE infra edges across several spec
   versions; an assertion's "no cosmetic infra edge" clause was never genuinely satisfied at its milestone close.
3. **Framework-suite drift** — a change
   lands without the matching update in a framework test,
   leaving real `tools/` failures.
   A gate run before the close catches this class **prospectively**, before the close is recorded.

What the three share: the close commands gate on **recorded/ledger state**, never on a **live, complete green
run**. `reclose` gates a clean tree + the mission state + an open-obligation ledger query;
`close-milestone` gates a clean tree + the state + a mechanical *read* of recorded ValidatorResults. **A re-closure
without this gate proceeds on a MANUALLY-verified green** because no automated gate exists — that manual step is exactly
what this ADR makes a CLI precondition. A bare `pytest && exit==0` gate would NOT catch the masked failure: it was 0-failed
*because* its suite was not collected — so the gate's collection half is load-bearing, not cosmetic.

## Decision

Add a **green-gate**: a precondition on BOTH close transitions that the target suite is **baseline-relative
green** — not absolute `exit==0`, but green *relative to a committed per-suite baseline*. The gate passes iff
**all three conjuncts** hold for the suite the transition targets:

1. **NO-UNEXPECTED-FAIL** — every failing test ID is in that suite's `expected_failure_test_ids[]` manifest.
   Both suites seed this set **EMPTY** (a prerequisite seam removes the last expected failures, so src/ and
   tools/ both start 0-failed), so *any* failure is unexpected → RED. (Catches the masked-failure class.)
2. **NO-COLLECTION-REGRESSION** — the collected-and-runnable count ≥ that suite's `stored_floor`. (Catches the
   `testpaths`-omission / path-silently-dropped class — the masked-failure mechanism.)
3. **NO-COLLECTION-ERROR** — pytest did not error during collection. (Catches a path present-but-broken/empty.)

**Baseline-relative, not absolute.** "Green" is defined against a committed baseline; suite identity (src/ vs
tools/) selects which manifest + floor to load. There is currently no tripwire-aware special case — both suites
are 0-expected-failure after the prerequisite seam — but the expected-failure manifest is the general mechanism
that would admit a sanctioned-red baseline if one were ever deliberately introduced.

**Floor derivation: stored-floor-at-last-green, write-back on pass.** `stored_floor` is the collected count from
the **most recent GREEN close**; on each passing close the gate writes the new collected count back to the
manifest. The floor ratchets to reality rather than being hardcoded (a hardcoded count rots — a collected count
recorded earlier in the ledger drifts from the live count as tests are added). The count is **deselection-aware**: it counts
the collected-and-runnable number *after* by-design deselection (src/ counts collected minus the docker-marked tests deselected via
`addopts = "-m 'not docker'"`; docker-deselection is by-design, not a regression).

**Artifact model: hybrid manifest + ledger.** A **committed per-suite manifest file** is the gate's
DETERMINISTIC read source (`stored_floor` + `expected_failure_test_ids[]`); **each change ALSO appends a ledger
baseline-record** (the audit trail). A **consistency obligation** binds them: the manifest floor MUST equal the
latest ledger baseline-record for that suite (authored later as a contract assertion — see the contract-preview).

**Seeding: empty-seed + verify.** Both manifests seed with EMPTY expected-failure sets. Seed-time verification is
"confirm 0 failures on a fresh run of each suite **before** writing the manifest." If a fresh run shows ANY
failure at seed time → STOP + surface (the manifest must not seed over a real red — the seam resolves any
prior declared-count mismatch first, so seeding starts from a genuine 0-failed baseline).

**Failure mode: hard-stop + recorded override.** The gate refuses the transition on failure **by default**. An
explicit operator flag `-OverrideGreenGate -Reason "..."` (mirroring `mission-spec-accept`'s `-Confirm` doctrine
and ADR-029's operator-gated lifecycle) **proceeds AND appends a ledger override-record** (who / when / why). No
silent bypass; no absolute block — operator authority is preserved and every bypass is auditable.

**Structural placement: one new `mission-lib.ps1` function, two inline call-site insertions.** GROUND confirmed
there is **no shared close-path function** — `reclose` and `close-milestone` each dot-source the lib's primitives
but define their own gate inline (`Assert-NoOpenObligations`, `Test-RosterClosable`). The green-gate is **one new
shared function** in `mission-lib.ps1` (e.g. `Assert-DefaultRunGreen`), **called from two distinct insertion
points** (one in `mission-reclose.ps1`, one in `mission-close-milestone.ps1`). It is a NEW predicate alongside
`Assert-NoOpenObligations` / `Test-RosterClosable`, not a modification of them (green was never a precondition at all).

## Consequences — what this GATES, and what it GIVES UP

GATES: the closure-integrity bug class — a milestone/reclose can no longer close while the target suite carries an
unexpected failure, a dropped collection path, or a collection error. The very class of all three recorded
instances.

GIVES UP / new surface (named deliberately):
- **Not an absolute block.** The `-OverrideGreenGate` escape means the gate can be bypassed. This is deliberate —
  it preserves operator authority (ADR-029 lifecycle is operator-gated, never automated) and makes every bypass
  **auditable** (the ledger override-record). The alternative (an un-overridable block) would put the CLI above
  the operator, contra the whole lifecycle doctrine.
- **Write-state on green.** The write-back-on-pass means a close transition now MUTATES gate state (the manifest
  floor). This is a NEW invariant surface: the write-back must itself be atomic with the close (it rides the
  existing `Invoke-AtomicCommit` one-logical-unit discipline) and must not advance the floor on a *failed* close.
- **New artifact surface.** The per-suite manifest is a new committed artifact that itself must be kept
  consistent with the ledger baseline-record — the consistency obligation becomes its own contract assertion (the
  manifest can drift from the ledger if a hand-edit bypasses the gate; the assertion guards that).
- **Run cost at close.** Each gated close now runs the full target suite (all of src/, not a subset). Acceptable for an
  operator-gated, infrequent transition; noted so it is not a surprise.

## Invariance check

Changes no spec version, adds no schema/field/enum, writes no CLI code and no validation contract this phase
(ADR-033 framework-ADR path, as ADR-041). Authoring an ADR is not a lifecycle transition; the mission's
state does not change. The gate function, manifest seeding, contract assertions, and the two call-site insertions are the
next seams (DECOMPOSE → CONTRACT-BEFORE-CODE → BUILD), gated by this ADR. The milestone that builds the gate closes THROUGH the very gate it
ships, and the next milestone-close then dogfoods it (the sequencing rationale).

## References

- ADR-041 (destructive lifecycle-op gating) -- the sibling framework-ADR in the same
  lifecycle-CLI family, on the same framework-ADR path.
- `reclose` and `close-milestone` -- the two close transitions this gate
  hardens, and the inline gates they already carry (`Assert-NoOpenObligations`,
  `Test-RosterClosable`).
- The lifecycle CLI's shared library -- the home of the one new shared gate function (Decision).
- The pytest collection and exit signals -- what the gate's three conjuncts read
  (Decision).
- `Invoke-AtomicCommit` -- the one-logical-unit discipline the manifest write-back rides.
- ADR-029 (operator-gated lifecycle), ADR-033 (ADRs canonical as standalone files), the constructive
  lifecycle CLI this hardens, and its existing close-transition gates.
