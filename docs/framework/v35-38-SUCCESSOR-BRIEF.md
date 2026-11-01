# SUCCESSOR BRIEF -- the state of the program at a milestone close and its re-closure

    AUTHORED ....... the builder seat, under the dispatch that closes the arc.
    AUTHORED AT .... the commit it was written at, before the reclose.
    FOR ............ the opening session of the next arc.

This brief is a POINTER DOCUMENT. Its governing rule is: derived from disk, cited by entry id,
never re-enumerated. Where a figure is not derived at the authoring HEAD it is labelled CARRIED
and its source named. The carried backlog register is CITED AND NEVER RESTATED -- that is not
economy, it is a standing rule of the ledger.

---

## 1. GROUNDING -- what the next session grounds against

Ground these before doing anything. They are stated as the state that obtains AFTER the
RE-CLOSURE ceremony this brief was authored inside; the brief itself was committed BEFORE
that ceremony, so the reclose-dependent rows are marked accordingly.

| Subject | Expected | Note |
|---|---|---|
| `state` | `Complete` | set by the RE-CLOSURE; `Reworking` at this brief's authoring |
| `current_spec_version` | unchanged by the reclose | reclose bumps no spec -- it is bookkeeping on a passed gate |
| `current_milestone` | unchanged by the reclose | reclose moves no cursor |
| `completed_at` | the RE-CLOSURE stamp | the prior completion is PRESERVED in the chaining ledger entry, not overwritten in the record |
| highest RE-CLOSURE block | the one this ceremony writes | the series is reopen-matched, NOT dense. Never derive the next number as maxN+1; `Resolve-ReopenMatchedNumber` (`mission-lib`) refuses that by construction |
| ledger height | the height at authoring, +1 | +1 for the reclose's single chaining entry |
| acceptance instruments | `a1..a15` | the arc's own: a11 ANCHOR, a12 ORIGIN, a13 MANIFEST+PLANE-PARITY, a14 stream-integrity variant branching, a15 the placement path |
| untracked state | the RESIDUE-KEEP files | standing untracked evidence. NEVER deleted, NEVER gitignored |

**THE STANDING CONSTRAINT THE NEXT ARC INHERITS BEFORE IT DOES ANYTHING.** Mission-lifecycle
ceremonies are blocked while the evidence hooks are live. The bytes are at
`docs/framework/vanguard-collective-local-modes-v2.3.md:315-322` (SS 17.3 holds the standing
constraint): `Assert-CleanGitTree` exempts `?? .claude/` and `?? .mission-runtime/` by name, the
A-126 gate `Assert-CleanWorkingTree` exempts nothing without `-AllowPaths`, and
`.mission/evidence/` is exempt in neither **and regenerates** -- a new `session-<id>/` per
session, created by the act of running one. Relocate-and-restore is defeated in kind there,
because the path's name is not known in advance and reappears mid-run.

**That constraint is ROUTED AROUND, not solved**, by operator relocate-and-restore of the
untracked files across each strict-gate window, with every sha256 and byte length
recorded before the move and re-proven identical after. The next arc inherits the blocker
intact. Note the cited list names spec-accept, promote-contract, reopen and close explicitly;
**reclose is the same class** -- its A-126 call at `mission-reclose.ps1:57` is strict with no
`-AllowPaths` at all -- and every ceremony that routes around it pays the relocation
cost rather than fixing the cause.

---

## 2. THE BIRD'S-EYE BACKLOG

Cited, not restated. The DISTANCE marker is this seat's judgement of how far the item sits from
a finish line, with the reason given; it is a planning aid and rules nothing.

| Item | Home | State | What would discharge it | Distance |
|---|---|---|---|---|
| **The carried backlog register** | the development ledger, with its restatement rule | its rows and its aggregation arithmetic, CARRIED until ruled | an operator ruling on the arithmetic, or a fresh derivation superseding the current one | **NEAR to rule, FAR to clear.** Ruling the arithmetic is one sitting; clearing the rows is the program |
| A register row's number (the layer-C reconciliation) | the development ledger | a number **DISPATCH-SUPPLIED AND NEVER RE-DERIVED** is not a citation | re-derive the row number, or drop the number and cite the defect directly | NEAR. The DEFECT is verified open on disk independently of the number |
| **The layer-C defect** + the interim's **retirement conditions 3 and 4** | the development ledger | **OPEN**, independently confirmed by a validator. Condition 3 open because the verify leg is **BUILT AND WIRED TO NOTHING** and its "if any" is NOT read as vacuous satisfaction; condition 4 is **the binding gap and no fixture can satisfy it** | cond. 4: a real substrate placed with destination digests re-derived and recorded. cond. 3: the wired leg's operator-registered payload capture | **FAR.** Not technically far -- the contract, the placement script and a15 all exist -- but cond. 4 needs a real live walk and cond. 3 reopens the hooks-live blocker |
| **CLASS 2 / `capture_gaps`-no-consumer** | the development ledger | **LIVE CORRECTNESS GAP**, three sites. `mission-verify.ps1` derives capture gaps by reclassifying library mismatches the post-cure library no longer emits, while never reading `capture_gaps` | decide whether verify keeps its own reclassification for legacy manifests or defers to the library, then wire the consumer | **MID.** Small in bytes, but gated on a design question, and the registered trap is that a naive fix drops coverage the reclassification still provides |
| **Canon-errata cluster** | the development ledger | open | canon edits | **MID.** They name bytes this arc does not own; needs the owning seat |
| **Two close-adjacent registrations** | the development ledger | open | fix the exit-2 persistence ordering; strengthen the item-3 check, which is **weaker than the close gate** | **NEAR.** Both are narrow and both are already localised |
| **Green-gate floor-write divergence** | `mission-lib:375-377` vs `close-milestone:170-174` | open. The library comment states the write-back never advances on an overridden close; the close assigns the floor **unconditionally** | reconcile the two sites | **NEAR.** One call site, no design question. Reachable ONLY via an override, and **not reachable at reclose at all** -- reclose calls no `Write-GreenGateFloor` |
| **A carried self-capture constraint** | the development ledger | carried **ADVANCED, NOT EARNED** -- its self-capture leg is constrained BY ITS OWN LETTER to the runner/harness process | a route its letter allows, or an amended letter | **MID.** Not closed by the milestone close |
| **Real-validator follow-on** | the development ledger | registered | -- | MID |
| **Joined-tags latent class** | the development ledger | REGISTERED, NOT FIXED, NOT SIZED. Ledger entries carry joined tags; the exposure is the `-File` route | a guard or a validating append path | **NEAR.** The registerable risk is the LATENT one, not the banked entries -- and it is a **fail-open shape in a selector**, the class design SS4.5 law 2 says must never be widened |
| **D5 governance question** | the development ledger, with **a deviation** clustered in | open | a governance ruling | **FAR.** Not a code item |
| **A finding's tolerances** | the development ledger | unexercised | exercise them | MID |
| **Fifth guard trigger class**; **stale local branches**; **image-label follow-on** | the development ledger | registered, not fixed, not sized | each independently small | NEAR |
| **Corpus-enumeration record** | the development ledger | the substrate-name corpus and the SS 5.4 predicate it justified; the same record also notes a corpus-enumeration **drafting defect** | -- | MID |
| **THE ZERO-MARGIN STATE** | **NEW -- registered by this brief** | see SS 2.1 | headroom on either suite | **NEAR to observe, FAR to fix** |

### 2.1 The zero-margin state -- registered here because no prior record registers it

**A green-gate suite can stand at zero margin**: its last measured `Runnable`
equals its `stored_floor` exactly. The authoritative figures are the suite manifests
(`.mission/green-gate/<suite>.json`, one per suite) and the gate's own
run output; **this brief deliberately states no floor figure**, because a floor number written
into a document that is read before a gate runs is a prediction wearing a measurement's clothes
-- the off-plane-arithmetic class and the fabricated-figure class. Read
the manifests.

Why it matters, derived from the predicate rather than asserted:

- C2 is `-ge`, not `-gt` (`mission-lib:345`), so **zero margin passes**. The exposure is the
  next unit down.
- `Runnable = passed + failed + skipped`, and **deselected are excluded** (`mission-lib:329`).
  So a test that becomes unrunnable -- removed, renamed away, uncollected, or merely
  **deselected** -- drops `Runnable` below the floor and fails C2. **One test is enough.**
- A test that merely FAILS still counts in `Runnable`, so it does not touch C2. It hits C1, the
  no-unexpected-failure conjunct.
- **A suite whose `expected_failure_test_ids` is EMPTY** treats ANY failure as
  unexpected; a suite that allow-lists ids treats only those as expected.
- **A recorded flaky class is read from the ledger**, and only its allow-listed members may be
  retried as flakes. A consequence worth carrying: **a red on a suite with an empty
  allow-list can never be a
  recorded-flake retry.** It is a regression by construction.

There is no CLI that lowers a floor, and hand-editing a manifest is the off-plane-arithmetic
class. The only headroom that exists is headroom the suite earns.

---

## 3. THE HEADLINE CANDIDATES -- three, with their blocking dependencies

**No recommendation is made.** The choice is the operator's; this section's only job is to make
it decidable against real constraints.

### (a) PRODUCT WORK -- the host's own deliverable
the host's product backlog, which this brief does not restate.

**FOR:** it is *product* work on the actual deliverable, which framework-machinery arcs
defer.

**AGAINST / BLOCKING:** it touches the product's sources and therefore the **product** suite, which
may be the tightest gate and may stand at zero margin; its flaky class may have members that are **not**
allow-listed. Product work starts by pushing on that gate. A product-side reference scheme
is **deliberately not adopted** into the framework seam.

**CITE AT THIS HEAD:** a product-side citation carried by a dispatch is re-derived against the
product's source before it is used; a cite that resolves to neither the file nor the symbol at
the authoring HEAD is replaced by the derived one, and the divergence is stated.
Product constraints are proven by the product's own tests
and are read there, not restated here.
The brief names no product path, symbol or line;
the next session derives them at its own HEAD.

### (b) THE LAYER-C CURE -- retirement condition 4
**FOR:** it closes the arc's own longest-standing open defect, and everything it needs now
exists: the ratified input contract, the operator-invoked placement script, and a15.

**AGAINST / BLOCKING:** it needs a **real witness substrate** to place, which means a real live
walk; and condition 3 needs a **wired** verify leg, which reopens the hooks-live/lifecycle
blocker this arc routed around rather than solved.

**Nearest to done, and its dependency is operational rather than technical.**

### (c) CLASS 2 -- the `capture_gaps` consumer
**FOR:** a live correctness gap in a tool this arc just shipped, and the smallest of the three.

**AGAINST / BLOCKING:** fixing it properly means deciding whether verify keeps its own
reclassification for legacy manifests or defers to the library. That is a design question, and
the registered trap is that a naive fix drops coverage the reclassification still provides.

---

## 4. THE STANDING LAWS THIS ARC MINTED -- inherited as law

1. **READ-BACK-SHAPE VERIFICATION**. Every ceremony that appends the ledger reads
   the banked entry back **before staging** and verifies its **shape, not merely its count**:
   the id as minted, the type as ruled, the **tags as separate array elements**, and the content
   round-tripping intact. Before staging, because that is the only window in which a malformed
   append is curable -- after the commit it is sealed. The prior law confirmed only that the
   ledger grew by exactly one line, and a line count cannot see a malformed field.

2. **NEGATIVE-CLAIM SCOPING**. A ledger entry states **no ceremony-wide absence
   claims**. A banked negative is scoped to its own moment -- "as of this append" -- or it is not
   banked at all. The reason is structural, not a matter of care: **the ceremony outlives the
   entry.** Checkpoints close the windows they claim over.

3. **KILL-SIGNAL PROVENANCE**. A planted breakage is admissible only with a kill
   signal the code under test **actually produces**. A mutant whose signal a cure has retired is
   unkillable, and reporting it as killed is the defect.

4. **THE TRUE-FIGURE DISCIPLINE**. Prescribed figures are testimony. When a
   prescription's halves are not jointly satisfiable, **that is the finding** -- HALT and report;
   never pick a half, never reconstruct a figure to make the two agree.

5. **THE TRANSCRIPTION LAW**. A validator's report is authoritative. The ValidatorResult
   is transcription, and **no field is authored on a validator's behalf.**

---

## 5. THE PILOT'S HONEST RECORD -- in both directions

A tally against the pilot's criteria is the thinking partner's to bank. **It is deliberately
absent from this brief**, and its absence is recorded rather than silent. What follows is the
qualitative record, which the arc's own errata chain makes derivable.

**The errata chain is the record.** Some errata open an arc at
its outset; the arc itself adds others: ledger-route misprescriptions, withdrawn corrections,
joined tags, size predictions, over-scoped negative claims, carried figures superseded by a
ratified rule (with their propagation lists), unkillable mutants, commissioning instructions,
and fabricated ratification figures.

**What the builder seat is positioned to catch after two seats.** A ledger route
that contradicts the tool's own source. A command shape nobody has driven. A pair of
requirements that cannot both hold. An anchor-lineage falsification at a sealed-hash move. And
an unkillable mutant outside its own pre-attribution.

**What the orchestrator seat is positioned to catch by grounding.** A milestone missing at contract-bind; a
spec premise gone stale; an incomplete propagation list; a partial close under `-NoCommit`; a
ledger expectation of the wrong entry count; and a floor-write divergence.

**WHAT THE ORCHESTRATOR SEAT GETS WRONG IS NAMED.** **Errata that are a drafting seat's own,
and that survive a thinking-partner verdict before a builder catches them,
are named as that seat's.** The shape: a
draft pre-states an untested `-Tags` command shape, the thinking-partner verdict
APPROVES it, and the builder runs it as pre-stated (correctly, since a dispatch's pre-stated
command may not be self-resolved away from) and catches it at post-commit read-back; or a
dispatch prescribes a route whose behavior nobody had derived from the tool.
Where the ledger states a count of such errata but does not name the members, the count is
CARRIED and labelled so; names are never reconstructed to fit it
(a figure reconstructed to agree is the fabricated-figure class).

State it plainly, because the record is the evidence in both directions: **the three-seat design does not
claim that drafts are clean. It claims that the third seat is positioned to catch what the first two miss.**

**The thinking-partner errata** -- and any verdict that passed a later-caught erratum -- are
recorded with the same weight, per design SS4.5 law 9: a thinking-partner claim is testimony and
enters the same refutation loop as a builder's.

---

## 6. HOW THIS BRIEF WAS AUTHORED, disclosed

Derived from disk at the commit it was written at by the builder
seat. Every figure is derived at that commit or labelled CARRIED. The backlog register is cited at
the ledger and **no row of it is re-enumerated**, per the ledger's restatement rule. No floor figure is stated
anywhere in this document, by construction. Rows are cited by entry id.

**A divergent cite is replaced, not repeated:** a product-side cite that does not match the
dispatch draft when re-derived at the authoring HEAD is replaced by the derived cite, and the
divergence is stated in the open.

**Negative-claim scoping applies to this document.** Every negative above is scoped to the
authoring HEAD named in this section, and nothing is claimed about any window after it.
