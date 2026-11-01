# THE v2.3 DELTA PASS: FINDINGS

    DISPATCH ......... a delta pass comparing the verify spec against design v2.3, approved by the
                       operator with two scope rules stated below.
    SESSION .......... a fresh builder session.
    HEAD ............. the commit the pass was run at (== origin/main).
    MUTATION ......... NONE. Nothing written in the repository, nothing staged, nothing
                       committed, nothing appended, origin unchanged. This artifact lives in
                       the scratchpad, outside the repository.
    SCOPE ............ Stated in SS 0 below.
    TIER SET RUN ..... TIER 1 (eleven rows) + TIER 2 (SS 4.6, SS 4.7, SS 17.1-17.5).
    PROPOSED, NEVER RULED. Every class below is a proposal. The operator rules each finding.

---

## SS 0. THE SCOPE OF THE PASS

The pass ran under two scope rules:

> **OPEN-1: TIER 2 IS IN.** Read SS 4.6, SS 4.7 and SS 17 (all five subsections)
> alongside the eleven TIER 1 rows. Every TIER 2 finding is LABELED ADJACENCY-SOURCED and never
> presented as a spec-vs-cited-section deviation, per the draft's own counterweight.

> **BANKING: the pass banks nothing** -- a dedicated post-pass ceremony places one
> amendment and one consolidated entry. THAT CEREMONY IS NOT THIS PASS.
> You bank nothing: no amendment, no append, no commit, no push. The append route for that
> ceremony is derived at that ceremony.

Both were honored. TIER 2 findings are marked `[ADJACENCY-SOURCED]` on their face. Nothing was
banked.

---

## SS 0a. CORRECTIONS TO THE DISPATCH'S OWN TESTIMONY

Per the draft SS 1 doubled rider and SS 7 step 2: the draft's excerpts and line ranges are
the drafter's testimony; the files are evidence. Four corrections. **None is a finding** -- a wrong
navigation aid is not a finding, but building on it silently would have been.

**COR-1 -- v2.3 is 883 lines, not 882.** The carried figure (draft OPEN-5)
is off by one. The last line of `vanguard-collective-local-modes-v2.3.md` is line 883:

```
- **PreCompact: NOT EXERCISED.** Compaction cannot be forced on demand; not inferred.
```

Consequence: TIER 2's SS 17 range is **:800-883**, not `:800-882`. Read at :800-883.

**COR-2 -- OPEN-2's first out-of-repo referent RESOLVES IN-REPO.** The draft says the citation
chain "leaves the repository" at "Principle 11". It does not. Principle 11 is carried in full,
verbatim and identically, in **design SS 2 of both versions** (v2.2:75-80, v2.3:89-94):

```
> **11. Evidence is captured by the harness, never authored by the agent.** An agent's report is
> testimony. Anchors — commit shas, suite figures, porcelain output, push confirmations, API
```

v2.3:675 places Principle 11 in the **brief's amendment set** (`SS2 add Principle 11`) -- that is
the brief being told to adopt it, not the principle living only there. The pass therefore did
**not** need to stop at that boundary. (The second referent, "the anti-fabrication rider", was not
chased: the draft's own derivation that its sentence is identical at v2.2:497 and v2.3:575 is
CONFIRMED -- see row 2 -- so it is not a v2.3 change and generates no finding either way.)

**COR-3 -- OPEN-3 / TIER 1 row 11: `design SS14.2` RESOLVES.** The draft anticipated an
unresolvable citation and instructed "report the citation as unresolved -- do not invent a
referent." No referent needed inventing. The document uses a `SS<n>.<m>` convention for **numbered
in-body items of sections that have no subsection headings**, and it establishes that convention
itself: both versions write "As specified in SS10.5" (v2.2:501, v2.3:579) pointing at item **5** of
SS 10, which has no subsection headings in either version. `design SS14.2` is SS 14 **item 2** under
the identical convention, and v2.2 item 2 carries exactly the subject the spec cites it for. This
is the substance of DP-05 and it is a **resolved** citation, not an unresolved one.

**COR-4 -- TIER 2's grounds for SS 17 overstate.** The draft says SS 17.2 "is the only place in
either document that carries its subject by name". Re-derived: the literal token `wiring_status`
occurs in **v2.2 at :628 and :633** as well as in v2.3 at :48, :337 and :824. v2.2 SS 14 items 1
and 2 carry it by name. TIER 2 was still correctly ruled in -- SS 17.2 is where the *current*
status lives -- but the stated ground was wrong and the correct ground is DP-05's.

**Every other SS 4 line range verified correct.** Re-derived independently from my own heading map
(SS 7 step 2). All eleven TIER 1 ranges on both sides, and TIER 2's SS 4.6 and SS 4.7 ranges,
confirm exactly as drafted. Only SS 17's end bound (COR-1) moves.

---

## SS 0b. THE RULING FORM

Fixed text of draft SS 6, carried on every finding below without variation:

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

# FINDINGS

## DP-01 -- SS 4.5 law 9's earning evidence changed in v2.3; the rule did not

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation) -- **with a stated qualification**, see below.
TIER 1 row 6.

**SPEC SIDE.** `mission-verify-spec.md:479-481`, verbatim:

```
This is more than one line, and calling it one line would be the kind of authored claim design
SS4.5 law 3 exists to stop. Design SS4.5 law 9 applies to the register as it applies to rulings:
a registered characterization refuted by source is corrected on the record.
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:267-269`, verbatim but for the errata count:

```
9. **Rulings are testimony.** Operator and thinking-partner rulings enter the same refutation
   loop as builder claims — <a larger count of> operator errata across the program prove it. A ruling refuted by
   evidence is reversed on the record, not defended.
```

**v2.2's line** (`vanguard-collective-local-modes-v2.2.md:253-255`), verbatim but for the errata count -- the three-way
quote class A requires:

```
9. **Rulings are testimony.** Operator and thinking-partner rulings enter the same refutation
   loop as builder claims — <a count of> operator errata in one program prove it. A ruling refuted by
   evidence is reversed on the record, not defended.
```

**THE QUALIFICATION, STATED RATHER THAN RESOLVED** (draft SS 3 law 4 -- record uncertainty, do not
choose). The three-way quote shows a genuine **v2.2 -> v2.3 change inside a cited section**: the
earning evidence moved from an errata count "in one program" to a larger errata count "across
the program". But the spec never quotes the count -- it cites the *rule*, and the rule is
byte-identical across versions. So this is a v2.3 change the spec neither shares nor contradicts.
Whether that is a class-A finding at all, or a sub-class the draft's three-way test does not reach,
**is not this pass's to decide.** It is recorded rather than dropped because dropping it would make
a change inside the most-cited governing section invisible.

**WHAT IT BEARS ON.** spec:480-481, the sole clause invoking law 9. Assertions citing law 9 or the
laws generally: the contract's registered assertions that cite them.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-02 -- v2.3 adds a TENTH law to SS 4.5; the spec declares SS 4.5 governs it absolutely and carries no counterpart

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation). TIER 1 row 6.

**SPEC SIDE.** `mission-verify-spec.md:208-211`, verbatim:

```
Each arm below is stated per-member: what it compares, the named detector, the residual that
detector does not reach, and what the arm emits. Design SS4.5 law 4 governs this section
absolutely -- a class claim requires a working detector for each disclosed member, and an arm that
names a detector this repository cannot point at is an overclaim.
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:270-275`, verbatim -- present in v2.3
and **absent from v2.2 entirely** (v2.2's SS 4.5 ends at law 9, :255, with `---` at :257):

```
10. **Installation is a falsification event, not a deployment step** (added v2.3). Machinery that
   has never run against its real substrate is a specification wearing an implementation's
   clothes. The first install is the cheapest falsification available and must be treated as an
   experiment with pre-stated falsifiers, a halt-don't-patch rule,
   and an outcome that is *reported*, never *achieved*. A session repairing the machinery whose
   failure it just discovered is the pen-on-its-own-evidence problem one level up.
```

**v2.2's line: none exists.** The three-way quote's second leg is empty by construction, which is
itself the finding's shape: this is a v2.3 *addition*, not a v2.3 *revision*.

**Derived, and load-bearing for the ruling:** law numbering 1 through 9 is **unchanged** between
versions -- identical numbers, identical rule text, save DP-01's law-9 count. Every numbered law
citation the spec makes (laws 2, 3, 4, 5, 9, at spec:78, :480, :173/:178/:209, :66, :480) therefore
still resolves to the same law in v2.3. Law 10 is appended, not inserted. **No citation is broken
by this addition** -- the deviation is that a governing section grew an obligation the specified
instrument has no answer to, not that a pointer moved.

**WHAT IT BEARS ON.** spec:206-211 (the arms preamble, where SS 4.5 law 4 is declared to govern
"absolutely"); spec:3-5 and spec:41-44 (the spec disclaims installing anything, so law 10 imposes
no obligation the spec *violates* -- but law 10 is now standing law over the install that has since
occurred, and the spec's SS 1 and SS 7 premises are the ones DP-06 and DP-12 report on).
Assertions: the registered assertions citing law 2 (spec:78-80), law 5, and laws 3 and 9.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-03 -- `expected_failures_matched`: the spec says no data source exists; v2.3 says the mechanism already exists and must be reconciled, not created

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation). TIER 1 rows 9 and 11.

**SPEC SIDE.** `mission-verify-spec.md:245-250`, verbatim:

```
- **`expected_failures_matched` has no data source in this repository.** Design SS12.2 and schemas
  SS5 name `tools/mission-cli/config/expected-failures.yaml` as its framework home; that file is
  absent. Where it is absent the member is reported `ABSENT` and refuses, rather than being
  silently treated as satisfied. It is not reported `NOT_APPLICABLE`: nothing in the anchor-scoping
  rule scopes it away, and stretching an allow-side exemption to cover a missing file is the
  failure mode design SS4.5 law 2 names.
```

and `mission-verify-spec.md:716-717`, verbatim:

```
- **`tools/mission-cli/config/expected-failures.yaml`** -- declared home, absent file; its content
  is mission truth.
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:755-756`, verbatim:

```
22. **D5** expected-failures reconciliation (mission-reaching amendment; the mechanism already
    exists at `.mission/green-gate/product.json` under A-148 — reconcile, do not create).
```

**v2.2's line: none exists.** v2.2's SS 14 (:620-643) has no expected-failures item at any position;
its seven-item list runs evidence-plane authorship, hook installation, `mission verify`, A2 schemas,
runner, ladder L1, L2->L3. So the spec does **not** share this with v2.2: the statement is new in
v2.3, which makes this a v2.3 *change* the spec could not have answered to, rather than a spec
error at authorship.

**Internal tension inside v2.3, recorded because it bears on the ruling.** v2.3's own SS 12.2
(:626-628) still names the other home, byte-identically with v2.2 (:548-550):

```
**Expected-failure manifest** gets a framework home: `tools/mission-cli/config/
expected-failures.yaml`, committed, amendment-gated (mission-agnostic mechanism; each mission
populates its own — the manifest content is mission truth, the mechanism is framework).
```

So v2.3 SS 12.2 and v2.3 SS 14 item 22 name two different homes for the same subject. **This pass
does not decide which governs.**

**WHAT IT BEARS ON.** spec:245-250 (arm 4.1's `ABSENT`-and-refuse rule for this member);
spec:716-717 (the SS 12 registration). Assertions: the registered assertions citing these
spec lines.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-04 -- premise-staleness occurrence: repository state falsifies "no data source in this repository"

**PROPOSED CLASS: B** (premise-staleness, an already-ruled class). **LOGGED SEPARATELY from class A per
the class-B ruling.** New occurrence of a ruled class; needs its own ruling per that ruling's own terms. That ruling is
not re-litigated here.

**SPEC SIDE.** `mission-verify-spec.md:245`, verbatim:

```
- **`expected_failures_matched` has no data source in this repository.** Design SS12.2 and schemas
```

**OTHER SIDE -- a host's mission artifact.** A host's `.mission/green-gate/<suite>.json` carries, verbatim:

```
    "expected_failure_test_ids":  [
```

**Derived, both legs, at finding time.** (a) `tools/mission-cli/config/expected-failures.yaml` is
**still absent** -- a glob over `tools/mission-cli/config/*` finds no file of that name
among its files. The spec's narrow claim about *that path* remains true. (b) The spec's
**broader** claim -- "has no data source **in this repository**" -- is what repository state
falsifies: a host's green-gate suite manifest exists and carries `expected_failure_test_ids`.

**Distinguished from DP-03 deliberately.** DP-03 is v2.3 saying something different from the spec.
DP-04 is the *disk* saying something different from the spec. They are the same subject through two
channels, and the class-B ruling's whole point is that filing the second in the procedure built for the first is
itself the defect. Ruled separately.

**WHAT IT BEARS ON.** spec:245-250 -- specifically whether arm 4.1 still reports this member
`ABSENT`-and-refuses when a data source exists at an unnamed path. Assertions: the registered
assertions citing spec:245-250.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-05 -- `design SS14.2` re-points in v2.3, and its new target says the opposite of what the spec cites it for

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation). TIER 1 row 11. **This is the pass's principal
finding.**

**SPEC SIDE, first site.** `mission-verify-spec.md:41-44`, verbatim:

```
**Nothing here runs today.** No CLI exists. The hooks whose capture this document assumes are
authored and **not installed** -- `.claude/settings.json` is absent from this repository and the
settings fragment self-declares `wiring_status: UNVERIFIED`, per design SS14.2. Every arm below is
the specification of a check, not a check.
```

**SPEC SIDE, second site.** `mission-verify-spec.md:689-690`, verbatim:

```
It is a specification. It builds no CLI, creates no workflow file, installs no hooks, and does not
verify harness wiring -- which remains `UNVERIFIED` and operator-gated per design SS14.2.
```

**OTHER SIDE -- what `SS14.2` resolves to in v2.2** (`vanguard-collective-local-modes-v2.2.md:630-634`),
verbatim, SS 14 **item 2**:

```
2. **Hook installation** (new explicit step, operator-gated): run
   `tools/framework/install-evidence-hooks.ps1 -Apply` on the operator's word only; **first act
   after install is wiring verification** — a live session's real payloads confirmed against the
   assumed shape, upgrading `wiring_status`. Until then the evidence plane is specification, not
   protection.
```

The spec's two citations are **exact**: "operator-gated" is v2.2:630's own word, and
`wiring_status` is v2.2:633's own token. The citation was correct when authored.

**OTHER SIDE -- what `SS14.2` resolves to in v2.3** (`vanguard-collective-local-modes-v2.3.md:709-710`),
verbatim, SS 14 **item 2**:

```
2. ✅ **A2 consolidated schemas** — §12 deltas applied; registered
   schema decisions resolved; three enum claims retired on evidence.
```

**And where the cited subject went** (`vanguard-collective-local-modes-v2.3.md:716-717`), verbatim,
now SS 14 **item 5**:

```
5. ✅ **A4 Phase 2 hook installation and wiring verification**.
   Hooks LIVE. Outcome: §17.
```

**The deviation, stated precisely.** Two independent defects ride the same pointer:

1. **The pointer moved.** v2.3 rewrote SS 14 from a seven-item forward plan into a 24-item
   Done/Remaining backlog under one continuous numbering. Item 2 is now a different subject
   entirely. A reader following `design SS14.2` into v2.3 lands on A2 schemas.
2. **The proposition inverted.** The subject the spec cites did not merely move -- it now asserts
   the negation. v2.2 item 2: hooks not yet installed, `wiring_status` to be upgraded, "the
   evidence plane is specification, not protection." v2.3 item 5: **"Hooks LIVE."**

**Bound stated:** the spec's citation convention (spec:7-8) declares `design SS<n>` to mean **v2.2**,
so the spec is not *wrong* to cite v2.2 -- it is pinned to a superseded version whose successor
reverses the fact. Which of "the citation is correct and stale" or "the citation must be re-pointed"
governs is **the operator's ruling, not this pass's**. Both spec:43 and spec:690 are affected
identically.

**WHAT IT BEARS ON.** spec:41-44 (the spec's SS 1 standing premise "Nothing here runs today");
spec:689-690 (SS 11's non-claim). Assertions: a registered assertion cites `mission-verify-spec.md:41-42`
directly in its own header; another cites spec:693-695, the adjacent SS 11 clause.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-06 -- premise-staleness occurrence: `.claude/settings.json` is present, and the hooks are installed

**PROPOSED CLASS: B** (premise-staleness, an already-ruled class). **LOGGED SEPARATELY from class A.** New
occurrence of a ruled class; own ruling required. The class-B ruling is not re-litigated.

**SPEC SIDE.** `mission-verify-spec.md:41-42`, verbatim:

```
**Nothing here runs today.** No CLI exists. The hooks whose capture this document assumes are
authored and **not installed** -- `.claude/settings.json` is absent from this repository and the
```

**OTHER SIDE -- install state.** Once the hooks are installed, a glob over `.claude/settings*.json`
returns:

```
.claude\settings.json
(and any local settings file the host keeps beside it)
```

`.claude/settings.json` **exists** after install. The design document names that exact file as the installation's
physical form (`vanguard-collective-local-modes-v2.3.md:854-855`, verbatim):

```
- **IF MISSION LIFECYCLE WORK RESUMES BEFORE D9 LANDS, THE HOOKS COME OFF FIRST.** Uninstall is
  deleting `.claude/settings.json` from the operator's shell; hooks re-arm on the next tool call
```

**Relationship to the RECOGNIZED occurrence, stated and NOT resolved** (draft SS 3 law 4). The
operator's earlier recognition of this premise-staleness names spec **:576-577** and **:584-586**. This
occurrence is at spec **:41-42** -- a different location, in a different section, carrying the same
falsified premise and additionally carrying the `SS14.2` citation of DP-05. Whether the earlier
recognition already covers it as one premise with three sites, or whether :41-42 is a separate
occurrence needing its own ruling, **this pass does not decide.** It is filed as its own finding so
the question is visible; if the ruling is "already covered", nothing is lost. The site the
recognition *does* name is reported separately and correctly at DP-12, as CONFIRMING.

**Not silently merged with DP-05.** DP-05 is a citation-target defect. DP-06 is a state-of-disk
defect. The class-B ruling's rule -- a third class filed in a procedure built for a second is itself the defect --
applies in both directions.

**WHAT IT BEARS ON.** spec:41-44 (the standing "nothing runs today" premise on which the whole
document's tense rests). Assertions: the registered assertion that quotes `mission-verify-spec.md:41-42` in its
own header comment.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-07 -- token-level absence: the literal `14.2` occurs zero times in both design versions

**PROPOSED CLASS: C** (token-level absence). **No other side exists, by construction.**

**SPEC SIDE.** `mission-verify-spec.md:43` and `mission-verify-spec.md:690`, both citing
`design SS14.2` -- quoted verbatim in full at DP-05.

**THE EXACT SEARCH PERFORMED, AND ITS RESULT.** Re-derived at finding time, file tools only, so
the absence is reproducible rather than asserted:

```
Grep  pattern: 14.2   path: docs/framework/vanguard-collective-local-modes-v2.3.md
      output_mode: count
      RESULT: No matches found -- 0 total occurrences across 0 files.

Grep  pattern: 14.2   path: docs/framework/vanguard-collective-local-modes-v2.2.md
      output_mode: count
      RESULT: No matches found -- 0 total occurrences across 0 files.
```

**Note on the search's own reach, stated:** `14.2` was issued as a **regex**, in which `.` matches
any character. The regex result is therefore a **superset** of the literal-substring result, and a
zero on the superset proves a zero on the literal. The draft's carried datum is CONFIRMED on a
strictly stronger search than the one it claimed.

**What the absence does and does not mean.** It means the referent is not addressable by literal
string match. It does **not** mean the referent is unresolvable: per COR-3, `SS14.2` resolves as
SS 14 item 2 under the document's own `SS10.5` convention, and DP-05 is the finding that follows.
This class-C entry exists so that a later reader who greps for `14.2` and finds nothing does not
re-derive "unresolved citation" and re-open a question DP-05 answers.

**WHAT IT BEARS ON.** spec:43, spec:690. Assertions: the registered assertion that quotes spec:41-42.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-08 -- token-level absence: the five outcome tokens occur zero times in both design versions

**PROPOSED CLASS: C** (token-level absence). **The drafter is named as this datum's origin**, per the
draft's instruction; it was **re-derived here rather than inherited**.

**SPEC SIDE.** `mission-verify-spec.md:53-60`, verbatim -- the closed vocabulary:

```
| Outcome | Meaning | Gate |
|---|---|---|
| `MATCHED` | Same basis; recorded and derived agree. | proceed |
| `DIVERGED` | Same basis; recorded and derived disagree. **The finding.** | REFUSE |
| `MOVED` | The basis differs, so the comparison cannot decide. Not a disagreement. | REFUSE |
| `UNREACHABLE` | A channel the check requires could not be contacted. Not an absence. | REFUSE |
| `ABSENT` | The subject the check requires does not exist. | REFUSE |
| `NOT_APPLICABLE` | The subject is correctly absent for this dispatch kind. | proceed |
```

**THE EXACT SEARCH PERFORMED, AND ITS RESULT.** Re-derived at finding time:

```
Grep  pattern: MATCHED|DIVERGED|MOVED|UNREACHABLE|NOT_APPLICABLE
      path: docs/framework/vanguard-collective-local-modes-v2.3.md   output_mode: count
      RESULT: No matches found -- 0 total occurrences across 0 files.

Grep  pattern: MATCHED|DIVERGED|MOVED|UNREACHABLE|NOT_APPLICABLE
      path: docs/framework/vanguard-collective-local-modes-v2.2.md   output_mode: count
      RESULT: No matches found -- 0 total occurrences across 0 files.
```

The drafter's carried datum is **CONFIRMED**, on both files, case-sensitive.

**The bound the draft insisted on, restated so it is not lost.** This is a token-level absence and
**nothing more.** It is consistent with the spec's own division of labour (spec:12-13: "Design SS4.3
and LM2-ADR-022 specify the gate; this document specifies the instrument"), and it **does NOT
establish that v2.3's gate prose agrees with the spec's gate rule.** On that question this pass's
answer is separate and is reported at row 1 and row 2 of the completion table: SS 4.3 and SS 11.4 are
byte-identical between versions, so v2.3 introduced no gate-prose change for the spec to disagree
with. Note also that `ABSENT` -- a sixth token the spec's table carries -- was not in the drafted
five and was not searched for as such; it appears in v2.2:559 / v2.3:637 in the **manifest-state**
sense, a different vocabulary from the outcome vocabulary. Recorded so the "five" is not later read
as "all six".

**WHAT IT BEARS ON.** spec:48-87 (SS 2, the outcome vocabulary and gate rule). Assertions:
the registered assertions citing the six-member closed set at spec:53-60 and the gate rule at spec:62-63.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-09 -- [ADJACENCY-SOURCED] E5-iv makes arm 4.2's `TAMPERED` -> `DIVERGED` mapping fire on ordinary work

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation) -- **but LABELED ADJACENCY-SOURCED per the OPEN-1
ruling: it is sourced from v2.3 SS 4.6, a section new in v2.3 with no v2.2 counterpart, which the
spec never claimed to answer to. It is NOT presented as a spec-vs-cited-section deviation.**
TIER 2, SS 4.6.

**SPEC SIDE.** `mission-verify-spec.md:309-310`, verbatim:

```
`FINALIZED` plus schema-valid is `MATCHED`; `PARTIAL` and `TAMPERED` are `DIVERGED`; a manifest at
a path that holds nothing is `ABSENT`.
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:288`, verbatim (E5-iv row):

```
| E5-iv | `Stop` marks the end of a dispatch | `Stop` fires at the end of **every assistant turn**. The first turn's Stop finalizes permanently; every later turn is logged but orphaned; the state machine then derives **`TAMPERED`** — the word reserved for evidence tampering — for a session that merely continued working. A multi-turn session keeps logging lines against a manifest frozen at its first-turn `entry_count`. | **FALSE** |
```

and `vanguard-collective-local-modes-v2.3.md:835-838`, verbatim (SS 17.2, the scoped status):

```
> consumable regardless — **at the moment of finalization; the same dispatch flips to `TAMPERED`
> one tool call later** (E5-iv), because `Stop` is per-turn while A1 treats it as
> end-of-dispatch. A consumer reading the manifest *file* sees complete; a consumer deriving
> *state* sees tampering. **Neither is true: the evidence is incomplete and untampered.**
```

**v2.2's line: none exists.** SS 4.6 is new in v2.3. This is why the finding is adjacency-sourced
and not a citation deviation.

**The deviation.** The spec maps `TAMPERED` to `DIVERGED`, and `DIVERGED` is the spec's own
"**The finding.**" (spec:56) with gate action REFUSE (spec:62-63). Under E5-iv, every multi-turn
session derives `TAMPERED`. An arm built to spec:309 therefore refuses every dispatch whose session
took more than one turn, and reports the refusal in the vocabulary reserved for evidence tampering
-- which v2.3 states in terms is not true ("the evidence is incomplete and untampered").

**WHAT IT BEARS ON.** spec:309-310 (arm 4.2's state mapping); spec:62-63 (the gate rule the mapping
feeds). Assertions: the registered assertions citing spec:309-310 and spec:62-63.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-10 -- [ADJACENCY-SOURCED] E5-ii/iii open a residual arm 4.2 does not disclose: manifest completeness is not call completeness

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation) -- **LABELED ADJACENCY-SOURCED per the OPEN-1
ruling; sourced from v2.3 SS 4.6, which has no v2.2 counterpart and which the spec never claimed to
answer to.** TIER 2, SS 4.6. Bears on TIER 1 row 4 (SS 4.1), whose assumptions it falsifies.

**SPEC SIDE.** `mission-verify-spec.md:281-289`, verbatim -- arm 4.2's disclosed residual list,
opening entries:

```
**Residual.**
- **State is a header check.** `Get-EvidenceState` reads `finalized_at` and re-hashes `log.jsonl`.
  It does not read stream bodies. A mutated stream body with an untouched log still derives
  `FINALIZED` from state alone -- which is why arm 4.3 exists and why threat notes R3 records this
  as detected-not-prevented.
- **`hook_errors_present: true` on a `FINALIZED` manifest means `entry_count` may undercount
  reality.** Verify must not consume such a manifest as complete merely because it is finalized
  (schemas SS12, Fields). The arm reports the flag on every entry rather than only when it
  refuses, because a consumer that never sees the flag cannot weigh it.
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:286-287`, verbatim (E5-ii, E5-iii):

```
| E5-ii | PostToolUse fires on every tool call | It fires only on **successful, permitted** calls. A failed call produces no entry, no hook error, and **no `seq` gap** — because `seq` derives from log length, not a call counter. | **FALSE** |
| E5-iii | Guard denials are recorded | A denied call produces no PostToolUse and therefore no entry. **What the guard refused exists nowhere in the evidence plane.** | **FALSE** |
```

and `vanguard-collective-local-modes-v2.3.md:296-302`, verbatim:

```
**The consequence for Principle 11, stated exactly.** A1's founding claim — *a fabricated
`git rev-parse` cannot survive this* — **holds for claims backed by successful, permitted
commands, and only those.** A claim about a command that failed, or that the guard refused, has
no evidence trail at all: an agent reporting "the suite passed" after a failed run leaves the
same evidence as one that never ran it — none. The failure dimension of the evidence plane is
empty, and until D8 lands, verification must not treat manifest completeness as call
completeness.
```

**v2.2's line: none exists.** Note additionally that TIER 1 row 4 (SS 4.1) is **byte-identical**
between v2.2 and v2.3 -- v2.3 did not amend the assumptions; it appended a section declaring four
of them false and left SS 4.1 standing. That is itself part of this finding's shape.

**The deviation.** The spec's arm 4.2 discloses residuals for `hook_errors_present`, for missing
`seq`, for `seq` under concurrency, and for uninstalled hooks (spec:281-305). It discloses **no**
residual for the case E5-ii/iii establish: a call that failed or was denied leaves the manifest
*correct on its face and silently short*, with no hook error and no `seq` gap to betray it. The
spec's closest neighbour, spec:301-305 ("A hook that was never installed is undetectable from
inside"), covers the all-or-nothing case, not the per-call one. v2.3's instruction --
"verification **must not** treat manifest completeness as call completeness" -- has no counterpart
clause in the spec, and under design SS4.5 law 4 (which spec:209-211 declares governs the arms
absolutely) an undisclosed residual in a per-member detection claim is the named defect.

**WHAT IT BEARS ON.** spec:281-310 (arm 4.2's residual and emit rules); spec:220-261 (arm 4.1,
whose `porcelain` and `suite` subjects are derived from the same capture); spec:62-63. Assertions:
the registered assertions citing spec:286-289, spec:309-310 and spec:282-285,
and spec:62-63.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-11 -- [ADJACENCY-SOURCED] E5-i: the spec's derivation record carries an `exit_code` field the evidence plane never populates

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation) -- **LABELED ADJACENCY-SOURCED per the OPEN-1
ruling; sourced from v2.3 SS 4.6 and SS 14 item 14, neither of which has a v2.2 counterpart.**
TIER 2, SS 4.6.

**SPEC SIDE.** `mission-verify-spec.md:158-164`, verbatim -- the divergence report's derivation
block:

```
derivations:
  - command: "git rev-parse HEAD"
    exit_code: 0
    stdout_sha256: <64 hex>
    stderr_sha256: <64 hex>
    stdout: |
      <verbatim>
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:285`, verbatim (E5-i):

```
| E5-i | `exit_code` is captured per tool call | Neither `exit_code` nor `exitCode` appears in the captured hook payloads, for any tool; the upstream signal is `interrupted: false`, which nothing reads. Every log and manifest entry records `exit_code: null` permanently. | **FALSE** |
```

and v2.3's own statement of the consequence for the build item, `vanguard-collective-local-modes-v2.3.md:739-741`, verbatim:

```
14. **D1** — `mission verify` implementation to A3's spec, at `tools/mission-verify.ps1` (needs
    its own amendment; `tools/mission-cli/` holds only `config/`). Note E5-i: any arm reasoning
    from `exit_code` is reasoning from a constant.
```

**v2.2's line: none exists.**

**The deviation, with its own bound stated.** The scope is narrower than E5-i's headline and the
narrowing is this pass's, not v2.3's: a verify process that shells out **directly** reads its own
child exit codes and can populate spec:160 honestly. The falsified case is the one spec:576-577
specifies -- verify **invoked inside a session**, where its execution is hook-captured, and where
the hook-written record carries `exit_code: null` permanently. In that carrier the spec's
`derivations[].exit_code` is a constant, and spec:109-113's admissibility rule ("A derivation that
appears in a verdict without its command and its raw output beside it is not admissible") is
satisfied on command and output but hollow on exit code. **Whether that makes the field a defect,
a disclosed-residual candidate, or nothing at all is not decided here.**

**WHAT IT BEARS ON.** spec:158-164 (report format); spec:109-113 (the auditability rule inherited
from LM2-ADR-022); spec:576-577 (the in-session carrier). Assertions: the registered assertions citing
spec:109-113, the spec:115-126 command set and spec:571-580.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-12 -- [ADJACENCY-SOURCED] CONFIRMING THE RECOGNIZED OCCURRENCE -- not a new finding

**PROPOSED CLASS: B, CONFIRMING.** Per the draft's SS 5 class-B standing note and the operator's
earlier recognition, this occurrence is **already recognized and relied on by nothing in the
current increment.** It is recorded here **as
confirmation, explicitly NOT as a new finding**, because the pass re-derived it and silence would
have been indistinguishable from not having looked.

**SPEC SIDE, the recognized mode** (`mission-verify-spec.md:576-577`), verbatim:

```
- **Invoked inside a session** (the L0/L1 use in section 8), verify's execution is hook-captured
  like any other tool call, and its report is committed at the next ceremony boundary.
```

**SPEC SIDE, the recognized stale caveat** (`mission-verify-spec.md:584-586`), verbatim:

```
**What this inherits, stated rather than assumed.** The hooks are authored and not installed;
`wiring_status` reads `UNVERIFIED` and upgrading it is the first act after an operator-gated
install. Until then the self-capture path above is a specification of a capture path.
```

**OTHER SIDE -- the repository artifact and its design record.**
`vanguard-collective-local-modes-v2.3.md:824-838`, SS 17.2, verbatim in part:

```
### 17.2 The scoped `wiring_status` — the artifact this phase produces

Recorded in the ledger, never in the sealed fragment (editing `settings.evidence-hooks.json`
would move a sealed hash; LEDGER-GOVERNS applies to status the same way it applies to amendments):

> **WIRING VERIFIED FOR THE SUCCESS PATH ONLY.** Payload shape, field names including
> `tool_response`, `$CLAUDE_PROJECT_DIR` expansion in the command string, matcher behavior in
> both directions, and faithful hook recording are all verified against the live harness for
> **successful, permitted** tool calls.
```

**CONFIRMED, and one nuance recorded.** The recognition holds: the hooks are live, so the caveat's
premise is stale and the in-session hook-captured mode is available. The nuance is that
spec:584-585's narrow clause -- "`wiring_status` reads `UNVERIFIED`" **on the fragment** -- remains
literally true, because v2.3:826-827 states the upgraded status was recorded in the ledger and
deliberately **not** written into the sealed fragment. So the sentence is stale in its conclusion
and accurate in its parenthetical. Recorded, not resolved.

**WHAT IT BEARS ON.** spec:569-590 (SS 7, evidence self-capture). Assertions: the registered assertions
citing spec:571-580, :574-575 and :578-580.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

## DP-13 -- [ADJACENCY-SOURCED] the ceremony boundary the spec commits evidence at is, by v2.3's own record, unconditionally blocked

**PROPOSED CLASS: A** (spec-vs-v2.3 deviation) -- **LABELED ADJACENCY-SOURCED per the OPEN-1
ruling; sourced from v2.3 SS 4.6's second registered finding and SS 17.3, neither with a v2.2
counterpart.** TIER 2, SS 4.6 + SS 17.3.

**SPEC SIDE.** `mission-verify-spec.md:576-577` and `mission-verify-spec.md:586-590`, verbatim:

```
- **Invoked inside a session** (the L0/L1 use in section 8), verify's execution is hook-captured
  like any other tool call, and its report is committed at the next ceremony boundary.
```

```
after install, the trust boundary is the ceremony commit: verify's own report, before it is
committed, is provisional and destroyable from inside the session with no marker -- which is the
argument for committing evidence at the earliest ceremony boundary rather than the most convenient
one.
```

**OTHER SIDE.** `vanguard-collective-local-modes-v2.3.md:315-322`, verbatim (SS 4.6):

```
- **Clean-tree preconditions become unsatisfiable by construction while hooks are live.**
  `Assert-CleanGitTree` exempts `?? .claude/` and `?? .mission-runtime/` by name; the A-126 gate
  `Assert-CleanWorkingTree` exempts nothing without `-AllowPaths`. `.mission/evidence/` is
  exempt in neither, and **it regenerates** — a new `session-<id>/` per session, created by the
  act of running one — so relocate-and-restore is defeated in kind: the path's name is not known
  in advance and reappears mid-run. Framework ceremonies using `-NoCommit` plus explicit-path
  commits are unaffected; **mission lifecycle ceremonies (spec-accept, promote-contract, reopen,
  close) are blocked unconditionally.** See §17.3 for the standing constraint.
```

and `vanguard-collective-local-modes-v2.3.md:845-856`, verbatim (SS 17.3), in part:

```
- **Mission lifecycle ceremonies are blocked unconditionally** — spec-accept, promote-contract,
  reopen, close.
- **IF MISSION LIFECYCLE WORK RESUMES BEFORE D9 LANDS, THE HOOKS COME OFF FIRST.**
```

**v2.2's line: none exists.**

**The deviation.** The spec's SS 7 rests its whole integrity argument on "the earliest ceremony
boundary" being reachable, and specifies that an in-session verify report is committed there.
v2.3 records that while hooks are live, the mission-lifecycle half of those boundaries is blocked
unconditionally, and that the standing remedy is to **uninstall the hooks** -- which removes the
capture the same sentence depends on. The spec has no clause for the state in which capture and
commit are mutually exclusive.

**A second, narrower leg, recorded separately within this finding.**
`vanguard-collective-local-modes-v2.3.md:307-314` registers as D9 that the committed plane
materializes outside its declared write surface, and states the precondition problem in terms:

```
  whether committed evidence is ever committed, and under what completeness precondition —
  noting that committing a set E5-ii/iii prove incomplete, under a manifest that calls itself
  finalized and consumable, reproduces the same defect permanently in the tracked plane.
```

The spec instructs committing at the earliest boundary; v2.3 registers as an open governance
question whether committing at all is correct yet. **Not resolved here.**

**WHAT IT BEARS ON.** spec:576-577, spec:586-590 (SS 7); spec:345-350 (arm 4.3's trust-boundary
residual, which inherits the same boundary). Assertions: the registered assertions citing spec:571-582
and :581-582.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

---

# COMPLETION TABLES

## TIER 1 -- one line per row, regardless of outcome

Ranges are the ones **actually read**, re-derived from my own heading map before use.

| # | Subject | v2.2 read | v2.3 read | Outcome |
|---|---|---|---|---|
| 1 | SS 4.3 `mission verify` | :182-195 | :196-209 | **No divergence found.** Byte-identical across versions, including "The manually-ceremonied P0 becomes a gate." (v2.2:184 / v2.3:198) which spec:29 quotes, and the Principle-11 sentence spec:571-572 quotes (v2.2:190 / v2.3:204). |
| 2 | SS 11.4 ADR-022 gate | :490-498 | :568-576 | **No divergence found.** Byte-identical. The tradeoff clause spec:110-112 quotes ("mitigated by making `verify` itself trivially auditable...") is unchanged at v2.2:495-497 / v2.3:573-575. Also confirms the draft's OPEN-2 derivation: the "anti-fabrication rider" sentence is identical at v2.2:497 and v2.3:575. |
| 3 | SS 2 Core Principles | :70-93 | :84-107 | **No divergence found.** Byte-identical, Principle 11 included. See COR-2: this row is what resolves OPEN-2's first referent in-repo. |
| 4 | SS 4.1 Hook-captured evidence store | :121-172 | :135-186 | **No divergence found within the row** -- byte-identical, all three layers (a)/(b)/(c) unchanged, so spec:693-695's inheritance still resolves. **But four of its assumptions are declared FALSE by v2.3 SS 4.6**, which left SS 4.1 itself unedited. See DP-10, DP-11, DP-09. |
| 5 | SS 4.4 Evidence-channel doctrine | :196-214 | :210-228 | **No divergence found.** Byte-identical. spec:499-500 and spec:580 both still resolve. |
| 6 | SS 4.5 Evidence-plane laws | :215-258 | :229-276 | **DIVERGENCE: two.** DP-01 (law 9's earning evidence: an errata count in one program -> a larger count across the program). DP-02 (law 10 added in v2.3). Laws 1-9 numbering and rule text otherwise identical, so every numbered citation the spec makes still resolves. |
| 7 | SS 10 Human Touchpoints (item 10.5 located by content) | :421-447 | :499-525 | **No divergence found.** Byte-identical. Item 5 is push authorization in both; its closing sentence "Operator browser confirmation of the origin tip after push remains standing law." (v2.2:435-436 / v2.3:513-514) is what spec:37, :394-396 and :408-409 cite. |
| 8 | SS 11.5 ADR-033 Push authorization | :499-509 | :577-587 | **No divergence found.** Byte-identical. Its "As specified in SS10.5" (v2.2:501 / v2.3:579) is the locator that establishes the `SS<n>.<m>` in-body-item convention -- the convention COR-3 and DP-05 turn on. |
| 9 | SS 12.2 Handoff / ValidatorResult / Report | :520-551 | :598-629 | **No divergence found within the row** -- byte-identical, `runner_anchors` block and all three prose paragraphs. **But v2.3 SS 14 item 22 names a different home for this section's expected-failure manifest.** See DP-03, DP-04. |
| 10 | SS 12.4 Push Authorization artifact | :576-588 | :654-666 | **No divergence found.** Byte-identical. spec:405's TOCTOU/single-use citation still resolves. |
| 11 | SS 14 / the `14.2` citation | :620-643 | :698-768 | **DIVERGENCE: the row's principal one.** The citation **resolves** (COR-3), contrary to the draft's expectation -- and both re-points and inverts in v2.3. See DP-05, DP-06, DP-07. Additional in-row deltas: v2.3 restructures 7 forward-plan items into 24 Done/Remaining backlog items; item 22 sources DP-03; item 14's E5-i note sources DP-11. |

## TIER 2 -- one line per section, per the OPEN-1 ruling

| Section | v2.3 read | Outcome |
|---|---|---|
| SS 4.6 Erratum E5 | :277-323 | **DIVERGENCE: four.** DP-09 (E5-iv vs spec:309), DP-10 (E5-ii/iii vs spec:281-289), DP-11 (E5-i vs spec:160), DP-13 (clean-tree blocker vs spec:576-590). All labeled adjacency-sourced. |
| SS 4.7 Registered dispatches | :324-359 | **No divergence found.** D8/D9/D10 are registrations, not claims the spec contradicts; spec:710-719's own registered set does not overlap them. One structural observation, below. |
| SS 17.1 What was done | :802-823 | **No divergence found.** Narrative provenance for E5; the probe-then-install reversal and the four-source clean state introduce no claim the spec answers to. |
| SS 17.2 The scoped `wiring_status` | :824-844 | **CONFIRMING only** -- DP-12, the recognized occurrence. No new finding. |
| SS 17.3 The standing operational constraint | :845-857 | **DIVERGENCE: one**, folded into DP-13 rather than double-counted. |
| SS 17.4 The ladder, climbed one rung | :858-869 | **No divergence found, and one CONFIRMATION.** v2.3:866-868 ("The **ORIGIN-SIDE ATTESTED** rung remains unoccupied") agrees exactly with spec:515-517 ("This document specifies the top rung. It does not possess it."). The spec's SS 6.1 ladder and v2.3 SS 17.4 are consistent. |
| SS 17.5 Minor findings | :870-883 | **No divergence found.** F-2/F-3/F-6 and the D6 bites are hook-implementation facts; none contradicts a spec clause. Note the range end is :883, not :882 -- COR-1. |

## THE DELIBERATE OMISSION, RECORDED AS A STRUCTURAL OBSERVATION, NOT A FINDING

v2.2 SS 5 "Runtime Substrate -- v2 Decisions" (:259-281) has **no v2.3 heading at levels 2-4**, and
the spec cites no `design SS5`, so it is outside the closure. Re-derived here, and the observation
is **larger than the draft's**: v2.3 did not remove the section -- it removed only the **heading**.
v2.2's `## 5. Runtime Substrate — v2 Decisions` (:259) is gone, while its intro line and its entire
ADR-023..ADR-035 table survive verbatim at **v2.3:339-356**, now falling inside SS 4.7's body with
no heading of their own. v2.3 SS 14 item 15 (:743) still cites them as "ratified in v2.2 SS5, none
built", a pointer to a section number v2.3 no longer has. Stated as a structural observation only.
**The derivation's own bound, restated:** the heading search covered levels 2-4 only.

---

# OPEN ITEMS FROM THIS PASS

**OPEN-P1 -- a v2.3 self-declared change list exists and was NOT read.** Grep context surfaced
`vanguard-collective-local-modes-v2.3.md:48` ("> `wiring_status`, and the standing operational
constraint that follows from it."), which reads as one bullet of a v2.3 preamble summarizing what
v2.3 changed, in the region :38-55. **That region is in neither ruled tier, so the pass did not
read it and did not widen its own scope to do so.** It is flagged because a document's own account
of its deltas either corroborates or contradicts this pass's independently-derived ones, and a
later ruling could scope it in cheaply. The bytes that caused this OPEN are the grep line above.

**OPEN-P2 -- DP-06's relationship to the earlier recognition is genuinely undecided.** Stated at
DP-06 rather than resolved, per draft SS 3 law 4. The operator's recognition names spec:576-577 and
:584-586; DP-06 sits at spec:41-42. Whether that is the same premise at a third site or a separate
occurrence is the ruling.

**OPEN-P3 -- DP-01's class is uncertain and was not chosen.** A v2.2->v2.3 change inside a cited
section that the spec neither quotes nor contradicts does not fit class A, B, or C cleanly. Filed
as A with the qualification stated on its face.

**OPEN-P4 -- carried, not re-derived, and labeled as such.** Per draft OPEN-5: the carried
anchor and its byte length (spec SS 10) were **not re-hashed** --
hashing needs a shell command naming `tools/framework/hooks`, which the live guard denies. v2.3's
line total **was** re-derived here and corrected (COR-1).

---

    PASS ENDS. No cure applied. No ruling made. No amendment placed. No ledger append. No commit.
    No push. Nothing written in the repository. This artifact is the pass's sole product and it
    lives outside the repository.

---
---

# ADDENDUM A -- v2.3's SELF-DECLARED CHANGE LIST (OPEN-P1 RULED IN)

    AUTHORITY ........ OPEN-P1 scoped in: **the self-declared change list is read.** The one boundary
                       that kept the change list unread is resolved. Nothing else about the pass's
                       scope changes.
    SESSION .......... CONTINUE, the same builder -- same pass, same doubled rider, same scope law.
    RIDER ............ Re-run at the head of this addendum against the same commit as the pass.
                       The tree read as it did for the pass.
                       Nothing differed.
    MUTATION ......... NONE in the repository. This scratchpad file is the only thing written.
    NOTHING ELSE IN THIS ARTIFACT WAS TOUCHED. DP-01..DP-13, the completion tables, SS 0a's
    corrections and the original OPEN list stand exactly as first written.

## A.1 THE BOUNDS, DERIVED HERE

The pass's earlier estimate -- "the region :38-55" -- was a **grep-context guess and is now
corrected by derivation.** The bounds were derived by reading v2.3's front matter in full and
diffing it against v2.2's, not by eyeballing a blockquote:

| Object | Bounds | How derived |
|---|---|---|
| The enclosing status/provenance blockquote in v2.3 | **:4-52** | Contiguous `>`-prefixed run from :4 to :52; `---` at :54; `## 1.` at :56 |
| The same blockquote in v2.2 | **:4-38** | Contiguous `>`-prefixed run; `---` at :40; `## 1.` at :42 |
| **Carried history, NOT v2.3's declaration** | **:4-38** | v2.3:4-38 is **byte-identical to v2.2:4-38**, line number for line number: Status (:4-7), Provenance (:9-14), Naming + erratum E2 (:16-22), Revision v2.1 (:24-28), Revision v2.2 (:30-38) |
| **The block v2.3 ADDS to the front matter** | **:39-52** | Everything after the last carried line: the `>` separator at :39, the v2.3 revision paragraph, the `>` separator at :49, and the closing lesson paragraph |
| **THE SELF-DECLARED CHANGE LIST PROPER** | **:40-48** | The paragraph opening `> **Revision: v2.3 — post-installation. THE FIRST REVISION CORRECTED BY A RUNNING SYSTEM.**` and running to `> `wiring_status`, and the standing operational constraint that follows from it.` |
| Closing lesson paragraph | **:50-52** | v2.3-authored, about v2.3, but outside the revision paragraph. **Read and tabled anyway**, per the ruling's "read the whole list block, wherever it starts and ends" |

**Derivation bound, stated:** the byte-identity of :4-38 was established by reading both files'
front matter and comparing paragraph by paragraph, not by a diff tool. The two files' line
numbering coincides through :38 because their first 38 lines are the same lines.

## A.2 PER-CHANGE TABLE -- ONE LINE EACH

Seven self-declared changes, C-1 through C-7. Verbatim bytes for each are carried in A.3.

| # | Line(s) | The self-declared change, in brief | Verdict |
|---|---|---|---|
| C-1 | :40 | "post-installation. THE FIRST REVISION CORRECTED BY A RUNNING SYSTEM." | **CORROBORATES DP-02** -- the framing is law 10's ("Installation is a falsification event, not a deployment step"), self-declared at the top of the document |
| C-2 | :41-42 | Hooks installed and wiring-verified (Phase 2) | **CORROBORATES DP-05 and DP-06** -- v2.3 declares in its own front matter the installation that inverts SS 14 item 2's proposition and falsifies spec:41-42 |
| C-3 | :42-45 | "The harness confirmed the payload-shape assumptions A1 was built on -- `tool_response` is present under exactly that name, so the B5 falsifier did not fire -- and the hooks recorded faithfully everything the harness sent." | **CONTRADICTS DP-11** -- and is therefore itself reportable. See **DP-14**. The hook-faithfulness half corroborates SS 17.2 and is not in tension |
| C-4 | :45-46 | "It also **falsified four §4.1 assumptions**, enumerated as erratum **E5** in §4.6." | **CORROBORATES DP-09, DP-10, DP-11** -- and corroborates the pass's TIER 1 row 4 observation that SS 4.1 stands byte-unedited while a later section declares four of its assumptions false |
| C-5 | :46-47 | "Two of those four were structurally uncatchable by any synthesized payload, because they concern calls the harness never makes." | **CORROBORATES DP-10** exactly -- the two are E5-ii and E5-iii, the failed-call and denied-call members DP-10 is built on |
| C-6 | :47-48 | "§17 carries the installation record, the scoped `wiring_status`, and the standing operational constraint that follows from it." | **CORROBORATES DP-12 and DP-13** -- names the scoped `wiring_status` (DP-12's subject) and the standing operational constraint (SS 17.3, DP-13's second leg) as v2.3 deliverables |
| C-7 | :50-52 | "inspection alone did not surface these; the first installation did. Specifications can only be checked against specifications until something runs." | **CORROBORATES DP-02**, and independently corroborates the draft SS 6 ruling form's own rationale (design SS4.5 law 6, execution-beats-inspection) -- a pass run before any code is inspection, and v2.3 says so about itself |

**Tally: 6 CORROBORATES, 1 CONTRADICTS, 0 NEITHER.** No self-declared change fell outside the
pass's tiers, so no row is dismissed as out-of-subject. Six of the seven corroborate findings this
pass derived independently, before the list was read -- which is the corroboration being worth
something.

**TWO ABSENCES FROM THE LIST, RECORDED AS OBSERVATIONS, NOT AS FINDINGS.** The instruction is one
line per self-declared change; an absence is not a change. Both are recorded because the pass's
completeness claim is easier to check with them stated:

- **The list does not mention SS 14's restructuring.** The change DP-05 turns on -- seven
  forward-plan items rewritten into a 24-item Done/Remaining backlog under one continuous
  numbering, moving what `SS14.2` resolves to -- is nowhere in :40-48. It is visible only by
  reading SS 14 on both sides, which is what TIER 1 row 11 did.
- **The list does not mention the loss of SS 5's heading.** The structural observation recorded
  above (v2.2 SS 5's heading gone at v2.3, its intro line and ADR table surviving orphaned at
  v2.3:339-356) is not self-declared either.

Neither absence is asserted to be a defect. They are stated so that "v2.3's change list is
complete" is not inferred from this addendum.

## A.3 NEW FINDING

## DP-14 -- [ADJACENCY-SOURCED] v2.3's front matter declares the payload-shape assumptions confirmed; v2.3 SS 4.6 declares one of them false

**PROPOSED CLASS: A** (nearest fit) -- **with the class problem stated on its face, not resolved.**
See OPEN-P5. **LABELED ADJACENCY-SOURCED**: the front matter is outside both original tiers and
enters only by the OPEN-P1 ruling.

**Sourced from the change list, but NOT evidenced by it.** Per the ruling's own terms -- the list
is v2.3's testimony about itself -- the finding below quotes the **underlying sections** on the
other side. The list supplies one side only, and is quoted as the claim under test.

**SIDE 1 -- the self-declared change** (`vanguard-collective-local-modes-v2.3.md:42-45`), verbatim:

```
> Phase 2). The harness confirmed
> the payload-shape assumptions A1 was built on — `tool_response` is present under exactly that
> name, so the B5 falsifier did not fire — and the hooks recorded faithfully everything the
> harness sent. It also **falsified four §4.1 assumptions**, enumerated as erratum **E5** in
```

**SIDE 2 -- the underlying section, E5-i** (`vanguard-collective-local-modes-v2.3.md:285`), verbatim:

```
| E5-i | `exit_code` is captured per tool call | Neither `exit_code` nor `exitCode` appears in the captured hook payloads, for any tool; the upstream signal is `interrupted: false`, which nothing reads. Every log and manifest entry records `exit_code: null` permanently. | **FALSE** |
```

**SIDE 2 -- the underlying section's own classification of E5-i**
(`vanguard-collective-local-modes-v2.3.md:290-292`), verbatim:

```
**Two root causes, and they cure at different layers.** E5-i/ii/iii are **payload-shape and
call-visibility** facts about the harness contract — the plane never sees what it assumed it
would. E5-iv is a **lifecycle mismatch**: A1's dispatch model and the harness's turn model are
```

**SIDE 2 -- how SS 17.2 states the same claim, scoped**
(`vanguard-collective-local-modes-v2.3.md:829-833`), verbatim:

```
> **WIRING VERIFIED FOR THE SUCCESS PATH ONLY.** Payload shape, field names including
> `tool_response`, `$CLAUDE_PROJECT_DIR` expansion in the command string, matcher behavior in
> both directions, and faithful hook recording are all verified against the live harness for
> **successful, permitted** tool calls. **NOT VERIFIED, and demonstrated ABSENT,** for failed
> calls (E5-ii) and guard-denied calls (E5-iii)
```

**THE CONTRADICTION, STATED PRECISELY.** SS 4.6:290-291 classes **E5-i as a payload-shape fact**,
and E5-i is `FALSE`: the payload-shape assumption that `exit_code` is captured per tool call was
**falsified**. The front matter says, without scope, that "**the harness confirmed the
payload-shape assumptions A1 was built on**" and offers `tool_response` as the instance. SS 17.2
says the same thing correctly, by scoping the confirmation to **successful, permitted** calls and
naming what was not verified. The front matter carries no such scope.

**Why this is not merely a summary compressing.** v2.3's own SS 4.5 law 4 (:247-251) is the test
it fails -- "A detection claim is stated per-member and demonstrated per-member; a class claim
requires a working detector for *each* disclosed member." The front-matter sentence is an unscoped
**class claim** over a class one of whose members the same document declares false, in a document
whose central lesson (C-7) is that unscoped claims survive inspection until something runs. The
per-member statement exists at SS 17.2; the front matter is where a reader meets the class version
first.

**What this does NOT claim.** It does not claim `tool_response` was unconfirmed -- it was, and the
hook-faithfulness half of the sentence agrees with SS 17.2's second verdict exactly. It does not
claim E5-i is newly discovered here. It claims one thing: **the front matter's scope and SS 4.6's
scope disagree about the same subject**, and DP-11 is the finding that rests on SS 4.6's reading.

**WHAT IT BEARS ON.** Directly on **DP-11**, whose entire ground is that a payload-shape assumption
was falsified; a reader who takes the front matter at face value would reject DP-11 without opening
SS 4.6. Onward: spec:158-164 (the `derivations[].exit_code` field), spec:109-113 (the
auditability rule). Assertions: the registered assertions citing spec:109-113 and the
spec:115-126 command set.

> **RULING FORM.** This finding is disposed by a **per-finding operator ruling**. It is not cured
> by the pass, not batched with other findings, and not resolved by a builder's judgement. Any
> ruling on it is **RE-OPENABLE**: any later increment whose execution contradicts the ruling
> **re-surfaces this finding**, and the contradiction is reported rather than absorbed.

## A.4 REVISED COUNTS BY CLASS -- KEPT SEPARATE PER THE CLASS-B RULING

| Class | Original | Addendum | Total | Members |
|---|---|---|---|---|
| **A** -- spec-vs-v2.3 deviation | 8 | +1 | **9** | DP-01, DP-02, DP-03, DP-05 (TIER 1); DP-09, DP-10, DP-11, DP-13 (TIER 2 adjacency); **DP-14** (front matter, adjacency, class contested) |
| **B** -- premise-staleness, NEW occurrences | 2 | +0 | **2** | DP-04, DP-06 |
| **B** -- CONFIRMING, not new | 1 | +0 | **1** | DP-12 |
| **C** -- token-level absence | 2 | +0 | **2** | DP-07, DP-08 |

**14 numbered findings, DP-01..DP-14. 13 need a ruling** (DP-12 is confirmation of an
already-recognized occurrence). The class-B ruling remains un-re-litigated; the class-B count is
unchanged by this addendum.

## A.5 OPENS -- ONE CLOSED, ONE ADDED

**OPEN-P1 -- CLOSED.** The change list was located (:40-48, in the v2.3-added block :39-52), read
in full, and every self-declared change is tabled at A.2. Six corroborate; one contradicts and is
filed as DP-14. The pass's earlier bound estimate is corrected at A.1.

**OPEN-P5 -- NEW: the SS 5 class table does not cover intra-document inconsistency.** DP-14 is
v2.3-vs-v2.3, not spec-vs-v2.3 (class A), not premise-vs-repository-state (class B), and not a
token-level absence (class C). It is filed as A because A is nearest, with the mismatch stated
rather than hidden. **This is the second instance of the same gap** -- OPEN-P3 records the first,
at DP-01, where a v2.2->v2.3 change inside a cited section that the spec neither quotes nor
contradicts also fit none of the three cleanly. Two instances from one pass is offered as evidence
that the gap is structural rather than incidental. **Not resolved here; the pass does not widen
its own class table any more than it widens its own scope.**

**OPEN-P2, OPEN-P3, OPEN-P4 -- unchanged**, exactly as first written above.

---

    ADDENDUM A ENDS. No cure applied. No ruling made. No amendment placed. No ledger append.
    No commit. No push. Nothing written in the repository. Both this artifact and the checkpoint
    live outside the repository.
