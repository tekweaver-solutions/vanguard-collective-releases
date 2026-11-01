# Evidence-Placement Input Contract

    STATUS ............ PROPOSED, NOT RATIFIED. This document is the artifact the sequencing assertion requires
                        to exist before any hook code. It is not in force until the operator
                        ratifies it and the ratification is banked as an amendment or ledger entry
                        (the sequencing assertion: a figure that exists only in agent prose does not exist).
                        **RATIFIED by the operator -- banked as an amendment.
                        RE-RATIFIED by the operator together with the
                        SS 5.4 REVISION -- banked as a further amendment.
                        RE-RATIFIED A THIRD TIME by the operator for this STATUS cure
                        itself -- banked at this ceremony's amendment. The PROPOSED line above is
                        preserved as the record of what this document said before ratification and
                        NO LONGER DESCRIBES ITS STATE; SS 12.1 is the governing ratification
                        record.**
    AUTHORITY ......... the operator's spec-first ruling (option (i)); the sequencing assertion and the
                        placement assertion (mission contract proposals); the guard's layer-c defect registered
                        as a finding.
    SEAM .............. the evidence-placement input seam.
    DERIVED AT ........ the commit it was written at.
    HOUSE SHAPE ....... peer specification, sibling to docs/framework/mission-verify-spec.md.

---

## 1. WHAT THIS DOCUMENT DECIDES, AND WHAT IT MAY NOT

**1.1** THE SEQUENCING ASSERTION CONSTRAINS SEQUENCE, NOT CONTENT. It does not pre-decide what this
contract says. **This document decides the content, and the operator ratifies it.** A contract whose
content were fixed by the assertion that ordered it would be a class already registered as an erratum.

**1.2** The sequencing assertion makes four items MANDATORY and states that a contract **SILENT ON ANY OF THE
FOUR FAILS**: the TRIGGER (SS 4), the INPUT LOCATION AND SHAPE (SS 5), the TRUST MODEL for an
out-of-repo source (SS 6), and the FAILURE SEMANTICS for absent / malformed / partially written
input (SS 7). Each has a stated answer below. Where a derivation forces a fork the operator must
rule, the fork is marked **OPEN** and a recommendation is given -- an OPEN is not silence, but SS 4's
OPEN-A is load-bearing and this document should not be ratified without ruling it.

**1.3** THIS DOCUMENT AUTHORS NO HOOK CODE and rewires NEITHER settings surface. The sequencing assertion makes
each of those an independent RED: "a hook file authored ahead of the ratification REDs the ORDER item
ONLY; a contract authored as commentary INSIDE the hook rather than as a ratifiable standalone
artifact REDs the EXISTENCE item ONLY."

**1.4** IT DOES NOT RETIRE THE INTERIM. The sequencing assertion FAILS a retirement of the interim
operator-copy route before the hook that replaces it exists. SS 9 states the retirement conditions;
it does not perform the retirement.

---

## 2. PREMISES, EACH CITED TO DISK

Every premise below was read at the commit this document was written at. Premises carried on authority rather than derived
are segregated in SS 11.4.

**2.1 THE FOUR WIRED HOOKS.** `tools/framework/hooks/` holds exactly four hook scripts plus the
settings fragment: `evidence-guard-pretooluse.ps1`, `evidence-post-tool-use.ps1`,
`evidence-stop-finalize.ps1`, `evidence-pre-compact.ps1`. The fragment wires PostToolUse (:12-23),
PreToolUse (:24-35), Stop (:36-47) and PreCompact (:48-59). **There is no fifth hook.**

**2.2 THE TWO SETTINGS SURFACES, AND WHICH IS AUTHORITATIVE.**
`tools/framework/hooks/settings.evidence-hooks.json:7` says of itself: "This file is the TRACKED
SOURCE OF TRUTH. It is NOT settings.json. `tools/framework/install-evidence-hooks.ps1`
merges the `hooks` key of this fragment into `.claude/settings.json`, which is gitignored and
therefore a derived, uncommitted install. The `_meta` key is documentation and is never merged."
`.gitignore:7` is `.claude/`. The derived install exists in the working tree and carries **only** the
`hooks` key -- no `_meta` -- with matchers identical to the fragment (`.claude/settings.json:12`
carries `Write|Edit|MultiEdit|NotebookEdit|Bash|PowerShell`, matching the fragment's `:26`).

**2.3 WIRING IS UNVERIFIED, BY THE FRAGMENT'S OWN DECLARATION.**
`settings.evidence-hooks.json:9`: `wiring_status` is "UNVERIFIED against a live harness. A1 proves
the mechanism by driving the hook scripts directly with synthesized payloads; it does not prove the
harness invokes them with the payload shape assumed here."

**2.4 EXACTLY ONE PAYLOAD SHAPE IS ATTESTED ON THIS HOST.** `evidence-stop-finalize.ps1:54-57`
records that the Stop payload carries **eleven** fields -- `session_id`, `transcript_path`, `cwd`,
`prompt_id`, `permission_mode`, `effort`, `hook_event_name`, `stop_hook_active`,
`last_assistant_message`, `background_tasks`, `session_crons` -- "derived by an
operator-registered raw-stdin probe" (the capture's hash and date are recorded at the cited lines). That is the
**SENDS** register; the **READS** register is documented separately, and `:58-59` warns that
conflating the two "is how this cure's space was nearly mis-derived". The Stop hook reads three of
the eleven (`:60-70`).

**2.5 NO HOOK EVENT BEYOND THE FOUR IS ATTESTED ANYWHERE ON DISK.** A grep over `docs/framework/`
for `SessionStart|SessionEnd|UserPromptSubmit|SubagentStop|Notification|hook_event_name` returns
**zero matches**. Whatever the harness may offer in general, **this repository's record attests to
four events and one probed payload.**

**2.6 THE DESTINATION AND THE PROPERTY.** The placement destination is
`.mission/evidence/<dispatch_id>/` (the placement assertion; design SS4.1 as quoted at
`evidence-stop-finalize.ps1:11-13`). `.mission/evidence` is a member of
`$script:EvidenceProtectedPaths` (`evidence-common.ps1:1059`), and the guard's deny text is "an
agent-writable evidence store launders testimony as evidence".

**2.7 THE GUARD IS A TRIPWIRE, NOT A BOUNDARY.** `evidence-guard-pretooluse.ps1:8-15`: "[The scoping ruling] is
the governing scope: this is NOT a boundary... The guard raises the cost of an ACCIDENTAL write; an
agent that wants in gets in." The placement assertion makes a discharge reading "the guard now guarantees" a
FAIL. **Nothing in this contract promotes the guard.**

**2.8 THE RECORDER'S FAILURE DIRECTION IS FIXED.** `evidence-guard-pretooluse.ps1:27-29`: "a
record-write failure lands in hook-errors.log and THE DENY STILL FIRES -- the recorder fails toward
denial-without-record, never toward allow." SS 7 inherits this direction.

**2.9 THE SUBSTRATE GATE.** `Test-WitnessedSubstrate` (`tools/mission-lib.ps1:700-746`, invoked at
`mission-close-milestone.ps1:524`) requires, under `.mission/evidence/<name>/`: a `02-compose-ps*`
file matching `Up\b.*healthy` (`:713`), a `03-pytest*` file matching a pass (`:716`), a
`04-event-history*` file carrying real event SHAPE **and** the terminal activity in real event
structure -- a JSON `"name"` field or an `ACTIVITY_TASK_SCHEDULED` line -- and
`declared-terminal-activity.txt`, REQUIRED, whose first non-empty line matches `^[A-Za-z0-9_.-]+$`.
Undeclared is refused: the gate has no built-in default terminal activity.

**2.10 THE INTERIM.** THE OPERATOR-COPY PLACEMENT ROUTE: when the guard refuses a builder's write to
`.mission/evidence`, the builder HALTS; under an operator ruling the builder stages the complete
substrate in a scratchpad outside the repository and **the operator performs the placement with a
single `Copy-Item`**, so the evidence plane is never agent-written and the guard's property holds
intact. Staging is verified builder-side: sha256 + byte length + first-3-bytes BOM check for
each file. **DISCLOSED LIMIT of that route:** sha256 can NOT be re-derived at the
DESTINATION, because the guard also refuses shell commands referencing `.mission/evidence`.
Destination verification is therefore presence-and-names (Glob, every file) plus the content of
`declared-terminal-activity.txt` (Read); no independent destination re-derivation is performed and
none can be claimed.

### 2.11 A STALE-CITATION FINDING, DERIVED WHILE GROUNDING THIS DOCUMENT

**The placement assertion (in two places) and the ruling's own record all cite `$script:EvidenceProtectedPaths` at
`evidence-common.ps1:1003-1010` and `$script:EvidenceCeremonyPaths` at `:1021`. BOTH CITATIONS ARE
NOW STALE.** On disk at the commit this document was written at, the arrays are at **`:1057-1064`** and **`:1075`**, with
`$script:EvidenceParentPaths` at `:1065-1069`. The shift is **+54 lines**, exactly the net line delta
of the stream-integrity correct-form delta (56 added, 2 deleted) committed before it.

This matters because it is load-bearing, not cosmetic: **the placement assertion's acceptance criterion requires that
"a diff over those two regions is EMPTY"**, and a discharge that diffs `:1003-1010` at today's bytes
would be diffing an unrelated region of the file and reporting EMPTY for the wrong reason.

This is **the carried-figure-superseded-by-ratified-rule class -- arriving
in LINE CITATIONS rather than in hashes.** The sealed assertion bytes are NOT edited here; the
correction is registered, and this document cites the **current** lines throughout. **Recommended for
the ratification's banking as a propagation item.**

---

## 3. THE GAP THIS CONTRACT GUARDS

**3.1** No existing hook reads an out-of-repo staging directory (the sequencing assertion's header).
`evidence-stop-finalize.ps1` is a sibling **at the output end only**: it fires at session end on
harness-supplied data and copies INTO `.mission/evidence/<dispatch_id>/`. The interim route
stages a builder-assembled substrate **FROM** a scratchpad outside the repository. **The input end,
its trigger and its trust model are unbuilt and unspecified.** The spec-first ruling chose the larger build with that
gap disclosed rather than glossed ("THE COST OF THE OPTION TAKEN").

**3.2 THE REFLEXIVE FACT.** Both forks must write inside the protected set: option
(i) creates a hook under `tools/framework/hooks` and rewires `.claude/settings.json`, both protected
(`evidence-common.ps1:1060`, `:1063`). **The hook's own landing therefore uses the
operator-placement route** -- an earlier erratum's precedent. This contract's
ratification does not change that.

---

## 4. THE TRIGGER

**4.1 THE DERIVED CONSTRAINT.** A fifth hook's trigger MUST be drawn from what the harness actually
offers on this host, and SS 2.5 establishes that **disk attests to four events and no more**. A
contract naming a fifth event would be carrying it on authority while presenting it as derived.

**4.2 NONE OF THE FOUR IS A PLACEMENT TRIGGER, AND THIS IS THE HEART OF THE PROBLEM.** Derived per
event:

| Event | Why it is not a placement trigger |
|---|---|
| `PreToolUse` | It is the guard (`:24-35`). It fires **before** a tool call, on a matcher of write-verbs. A placement here would run on every candidate write. |
| `PostToolUse` | Fires after **every** tool call, matcher `*` (`:12-23`). Placement would be attempted hundreds of times per session. |
| `Stop` | Fires **per turn** on this harness, not per ceremony (`evidence-stop-finalize.ps1:40-41`, cure D10, E5-iv). It already carries the finalizer, the supersession chain and the reconciler. Placement here races the finalize it must not disturb. |
| `PreCompact` | Fires on context compaction -- an event with no relation to substrate readiness. |

**4.3 THE POSITIVE STATEMENT.** **There is no harness event on this host that corresponds to "a
witness substrate has been assembled and is ready to place."** Substrate readiness is an
**operator-observable fact**, not a harness-observable one: under the interim route a substrate becomes ready
when the operator has witnessed a live walk and adopted its attestation artifacts.

**4.4 THE CONTRACT'S ANSWER.** **The placement MUST be operator-initiated, and MUST NOT be initiated
by a harness event.** The placement path is a harness-side script executed by the operator, not a
settings-wired hook firing on a session event.

**4.5 THE VERIFICATION LEG MAY BE HOOK-WIRED, AND SHOULD BE.** A wired hook is the right shape for
*checking*, not for *placing*. A `Stop`-wired verification leg MAY re-derive the digests of anything
present under `.mission/evidence/<dispatch_id>/` and record the result, because that is a read plus a
write to the plane by a harness-side actor, and it is the one thing the interim placement could not do
(SS 2.10). **If a fifth hook is wired at all, its verb is VERIFY, not PLACE.**

### OPEN-A -- THE ONE FORK THAT MUST BE RULED BEFORE RATIFICATION -- SATISFIED; see the ruled block.

The ruling's language is "the harness-side placement **hook**", and the sequencing assertion requires this contract to
address both settings surfaces -- which presupposes something wired. SS 4.4 derives that the placing
act cannot be a wired hook on this host. Two readings, and **the operator must pick one, because they
produce different discharges of the placement assertion**:

- **(A-i) RECOMMENDED -- placement is an operator-invoked harness-side script; only the VERIFY leg is
  wired (Stop).** Satisfies the placement assertion's "placed harness-side and never agent-written" literally, keeps
  every protected array byte-unchanged, and closes the interim's destination-derivation limit. Both
  settings surfaces are still addressed, because the verify leg is wired into both (SS 8). Cost: "the
  placement hook" of the ruling's phrasing becomes a placement **script** plus a verify **hook**, and that
  wording difference should be ruled rather than absorbed.
- **(A-ii) A wired hook performs the placement on one of the four events, gated on a marker file.**
  Rejected on derivation: every one of the four fires on session activity rather than on operator
  intent, so the gate would be a file an agent can write -- which SS 6 shows is exactly the
  laundering the placement assertion forbids. Recorded so it cannot return quietly.

**(A-i) RULED** (operator, banked at the ratification amendment): placement is an
operator-invoked harness-side script; only the VERIFY leg is hook-wired (Stop). The ruling's "placement
hook" phrasing is read as placement-script-plus-verify-hook, ruled not absorbed. **(A-ii) rejected**
on the derivation above, recorded so it cannot return.

---

## 5. THE INPUT LOCATION AND ITS SHAPE

**5.1 LOCATION.** The staging directory is a single directory **outside the repository working
tree**, supplied to the placement script as an explicit absolute path parameter. It MUST NOT be
defaulted, and it MUST NOT be discovered by search. A discovered input location is settled by
whatever the script happens to find first, which is the implicit-contract failure the sequencing
assertion exists to prevent.

**5.2 IT MUST NOT LIE INSIDE THE REPOSITORY.** A staging directory inside the working tree would be
git-visible and would appear in `git status --porcelain`, which several ceremony gates read as a
cleanliness precondition. It would also be inside the guard's parent tier
(`evidence-common.ps1:1065-1069`).

**5.3 THE SUBSTRATE SHAPE -- WHAT A WELL-FORMED INPUT IS.** Derived from `Test-WitnessedSubstrate`
(SS 2.9) and from the interim substrate that passed it. A well-formed substrate:

1. **MUST** contain a `02-compose-ps*` file whose text matches `Up\b.*healthy`.
2. **MUST** contain a `03-pytest*` file whose text shows a pass.
3. **MUST** contain a `04-event-history*` file carrying real event structure **and** the terminal
   activity in a JSON `"name"` field or an `ACTIVITY_TASK_SCHEDULED` line.
4. **MUST** carry `declared-terminal-activity.txt` whose first non-empty line matches
   `^[A-Za-z0-9_.-]+$`. **The declaration is REQUIRED by this contract, as it is by the gate**
   (`Test-WitnessedSubstrate` has no built-in default terminal activity): a placement path that
   admitted an undeclared substrate would place evidence that can never close. **Explicit or refuse.**
5. **MUST** be flat -- files directly under the staging directory, no subdirectories. The
   interim route's substrates are flat.
6. **MUST** be accompanied by a manifest of its own contents: for every file, its name, byte length,
   sha256, and first-three-bytes BOM check. This is the interim staging table (SS 2.10) promoted
   from a practice to a requirement, and it is what makes SS 7's partial-write case decidable.
7. Every file **MUST** be BOM-free. The interim staging check verified this per file.

**5.4 THE DESTINATION NAME.** `.mission/evidence/<name>/`, where `<name>` is supplied explicitly and
MUST match `^[A-Za-z0-9_.-]+$`. It is the `SubstrateName` `Test-WitnessedSubstrate` takes
(`mission-lib.ps1:701-702`) and the value a ValidatorResult manifest carries as
`witnessed_substrate`, which `mission-close-milestone.ps1:498-523` auto-detects -- and
an omitted field silently SKIPS the gate.

**SS 5.4 -- REVISED (operator ruling; banked as an amendment).**

**AS RATIFIED**, SS 5.4 required `<name>` to match `^[A-Za-z0-9_.-]+$`. **A later review found that
predicate accepts `.` and `..`**, either of which resolves `.mission/evidence/<name>/` to the
evidence root or its parent. The finding was **registered and implemented-as-ratified** -- the
build implemented the contract as written, which is the correct behavior -- and is cured here.

**THE PREDICATE IS NOW `^[A-Za-z0-9][A-Za-z0-9_.-]*$`.** A name MUST begin with an alphanumeric.
**This is what the placement script implements**; the prior predicate is preserved above as the
record of what was ratified and no longer binds.

**DERIVATION.** A substrate name is named for its walk (SS 5.5) and in practice begins with an
alphanumeric and uses only lowercase letters, digits and hyphen -- the shape of the names under
`.mission/evidence/*/` and of the `witnessed_substrate` values a ValidatorResult manifest records.
**The cure therefore admits every conventional name.** It is **wider than the finding**, and deliberately so: it also excludes names
beginning `.` (a hidden directory under the evidence root) and `-` (parsed by PowerShell as a
parameter at the SS 6.5 operator command). **The widening is stated rather than absorbed.**

**UNCHANGED:** everything else in SS 5.4 -- the destination form, the `SubstrateName` linkage to
`mission-lib.ps1:701-702`, and the `witnessed_substrate` / `mission-close-milestone.ps1:498-523`
auto-detection note.

**5.5 IDENTITY RESOLUTION.** The destination name **MUST** be supplied by the operator, and **MUST
NOT** be derived from a hook payload's `session_id` or from any `<dispatch_id>` the script infers. A
witness substrate is named for the walk it records, not for the session that assembled it: a name
such as `<milestone>-<walk>-live` is one no session identifier would have produced.

> **A NOTE ON A PRODUCT-SIDE URI SCHEME.** This document deliberately specifies **no** resolution
> input for a product's own URI scheme. A **product-side** scheme for uploaded documents was
> proposed as an input; it addresses a product's documents, not the evidence plane,
> -- and it has **zero occurrences** under `tools/framework/**`, in either assertion,
> or in the ruling record. It addresses a product's uploaded documents, not evidence substrates. Importing
> it here would introduce a scheme with no bearing on the evidence plane. **Flagged for the operator
> at the ratification gate rather than silently adopted or silently dropped** (see SS 11.4).
>
> **RULED (operator): non-adoption RATIFIED; an erratum records the commissioning
> instruction's provenance.**

---

## 6. THE TRUST MODEL FOR AN OUT-OF-REPO SOURCE

**6.1 THE HONEST ANSWER IS: NOTHING ABOUT THE LOCATION MAKES IT TRUSTWORTHY.** Being outside the
repository is not a trust property. The interim scratchpad was outside the repository **and
fully agent-writable** -- the builder assembled it there precisely because it could write there.

**6.2 THE LAUNDERING ARGUMENT, STATED PLAINLY.** If a harness-side actor copies bytes from an
agent-writable source into the evidence plane without an independent check, then the composite
"agent writes staging, harness copies to plane" places agent-authored bytes in the plane. The
guard's own words for this are at `evidence-guard-pretooluse.ps1:148-150`: **"an agent-writable
evidence store launders testimony as evidence."** A placement path built that way re-opens the exact
hole the placement assertion requires be closed **by construction, not by exemption**, and it does so
without touching either protected array -- so **the placement assertion's array-diff criterion would pass while the
property was gone.** This is the most important sentence in this document.

**6.3 WHAT AN AGENT CANNOT DO, DERIVED RATHER THAN ASSUMED.** An agent on this host can write the
staging directory, can compute any digest, and can compose any command. **What it cannot do is cause
the operator to execute one.** No channel on this host is both readable by a harness-side script and
unwritable by the agent, other than the operator's own terminal. This is a derived limit, not a
policy preference, and every trust model that ignores it is wishful.

**6.4 THEREFORE: THE OPERATOR STAYS IN THE LOOP, AND THIS CONTRACT SAYS SO.** There is no
construction on this host under which an agent-assembled substrate becomes admissible to the
evidence plane without an operator act. **The contract does not pretend otherwise.**

**6.5 THE MINIMAL OPERATOR ACT.** The operator act is reduced to its irreducible core, and no
further:

> **The operator executes ONE command, in the operator's own terminal, naming the staging directory
> and the destination substrate name. That command is the whole of the operator's trust
> contribution.**

Everything else MUST be performed by the script, not by the operator: re-deriving every source
digest, comparing them against the substrate's own manifest (SS 5.3 item 6), performing the copy,
**re-deriving every digest at the destination**, comparing source to destination, and writing a
placement record.

**6.6 WHAT IS ACTUALLY GAINED, STATED SO THE RULING IS NOT READ AS COST-FREE.** Option (i) does
**not** remove the operator from the loop; SS 6.3 shows it cannot. What it removes is the
**unverifiable** part of the interim. In the interim the operator hand-composed a `Copy-Item` and the
destination could not be re-derived by anyone. Under this contract the operator runs one fixed,
auditable command and the destination **is** re-derived -- by a harness-side actor to which the
guard's refusal does not apply. **The win is destination verification and a placement record, not
operator elimination.** A discharge claiming the operator was removed from the loop is false.

**6.7 THE SCRIPT MUST NOT BE AGENT-INVOCABLE IN EFFECT.** The placement script lands under
`tools/framework/hooks` (`evidence-common.ps1:1060`, protected), so an agent naming its path in a
shell command is denied by the existing matcher. **No new refusal is added and no array is widened**
-- the property is preserved by construction, exactly as the placement assertion requires.

---

## 7. FAILURE SEMANTICS -- THREE CASES, STATED SEPARATELY

**7.0 THE GOVERNING DIRECTION, INHERITED.** `evidence-guard-pretooluse.ps1:27-29` fixes the
recorder's failure direction: it "fails toward denial-without-record, never toward allow." **The
placement path inherits this. It fails toward NOT-PLACED, never toward partially-placed and never
toward placed-without-record.** A placement path that fails toward "placed something" is the wrong
direction, and a substrate half-present under `.mission/evidence/` is worse than one absent, because
`Test-WitnessedSubstrate` reads presence and shape and a partial substrate can satisfy a shape check
it should have failed.

**7.1 ABSENT INPUT** -- the staging directory does not exist, is not a directory, or is empty.
**REFUSE. Place nothing. Exit non-zero with a message naming the path as given.** MUST NOT search for
a substitute, MUST NOT create the destination, and MUST NOT emit a partial record. An absent input is
an operator error at the command line and its correct outcome is a refusal the operator sees
immediately.

**7.2 MALFORMED INPUT** -- the directory exists but violates SS 5.3: a missing core file, a missing
or malformed `declared-terminal-activity.txt`, a BOM, a subdirectory, a missing manifest, or any file
whose re-derived sha256 or byte length disagrees with the manifest.
**REFUSE. Place nothing. Report EVERY violation found, not the first.** MUST NOT place the
well-formed subset -- a partial placement is SS 7.3's state reached deliberately. The report MUST
name each failing file and the specific predicate it failed, because a refusal that says only
"malformed" makes the operator re-derive the contract by trial.

**7.3 PARTIALLY WRITTEN INPUT** -- the hardest case, and the one an implicit contract settles wrongly.

**7.3.1** A directory being written **while** it is read is indistinguishable from a complete one by
listing alone. This is why SS 5.3 item 6 requires the substrate to carry its own manifest: **the
manifest is the completeness declaration**, and a substrate without one is not partially written, it
is malformed (SS 7.2).

**7.3.2** With a manifest present, the predicate is decidable: **the placement MUST re-derive every
file's sha256 and byte length and require exact agreement with the manifest, and MUST require that
the set of files present is exactly the set the manifest names -- no missing member and no extra
file.** An extra file is as disqualifying as a missing one: it means the manifest does not describe
what is on disk.

**7.3.3** The manifest **MUST** be written last by the assembling party and **MUST** be re-derived
first by the placing script. Any disagreement is a partial write.

**7.3.4** On detection: **REFUSE, place nothing, and report the disagreement per file.** MUST NOT
retry and MUST NOT wait-and-re-read -- a retry loop converts a partial write into a race the record
cannot describe.

**7.4 FAILURE DURING PLACEMENT** -- not one of the sequencing assertion's four, specified because SS 7.0's direction
demands it. If the copy fails partway, or if any destination digest disagrees with its source after
the copy, the script **MUST** report the destination as INDETERMINATE, naming every file placed and
every file not, and **MUST NOT** report success. **It MUST NOT attempt rollback**: deleting under
`.mission/evidence` is a destructive operation in the guard's parent tier
(`evidence-common.ps1:1065-1069`), and destructive rollback is the failure class that loses
evidence. **The operator resolves an INDETERMINATE destination; the script never does.**

---

## 8. BOTH SETTINGS SURFACES

**8.1 WHICH IS AUTHORITATIVE.** `tools/framework/hooks/settings.evidence-hooks.json` is the **TRACKED
SOURCE OF TRUTH**, by its own note at `:7`. `.claude/settings.json` is a **derived,
gitignored, uncommitted install** produced by `tools/framework/install-evidence-hooks.ps1` merging
the fragment's `hooks` key. **This contract states that and invents no different answer.**

**8.2 THE ORDER OF OPERATIONS.** Any wired leg (SS 4.5) **MUST** be added to the tracked fragment
**first**, and the derived install **MUST** be regenerated from it by the installer -- never
hand-edited. A `.claude/settings.json` carrying a hook the fragment does not is an install no reader
can see in git, which is precisely the incompleteness the sequencing assertion names.

**8.3 BOTH ARE PROTECTED.** `tools/framework/hooks` (`evidence-common.ps1:1060`) and
`.claude/settings.json` (`:1063`) are both in the protected set, so **both** land by the
operator-placement route (SS 3.2).

**8.4 THE WIRING REMAINS UNVERIFIED UNTIL PROBED.** Per SS 2.3 and SS 2.4, a newly wired leg's
payload shape is **not** attested by anything on disk. **Before any wired leg is relied upon, its
payload MUST be captured by an operator-registered raw-stdin probe of the same kind that produced the
Stop-payload capture (SS 2.4), and the capture recorded.** A leg whose payload shape is assumed is a leg whose
contract is implicit -- the thing this document exists to prevent.

---

## 9. THE INTERIM AND ITS RETIREMENT CONDITIONS -- STATED, NOT PERFORMED

**9.1 THE INTERIM STANDS.** The operator-copy route is the **LAWFUL INTERIM** placement
path (per the sequencing assertion) and **is not a defect to be routed around.** The placement assertion FAILS a dispatch
treating the interim as already discharged.

**9.2 RETIREMENT CONDITIONS -- ALL FIVE, CONJUNCTIVE.** The interim retires when, and only when:

1. This contract is **ratified** and the ratification is **banked** as an amendment or ledger entry
   (the sequencing assertion).
2. The placement path **exists on disk** and was landed by the operator-placement route, in a commit
   **later in the chain** than that banking (the sequencing assertion).
3. Its wired leg, if any, has an **operator-registered payload capture** recorded (SS 8.4).
4. It has **placed a real substrate** that passes `Test-WitnessedSubstrate`, with the destination
   digests **re-derived and recorded** -- discharging the interim's disclosed limit rather than
   restating it (the placement assertion requires a discharge to say which of the two states holds).
5. `$script:EvidenceProtectedPaths` (`evidence-common.ps1:1057-1064`) and
   `$script:EvidenceCeremonyPaths` (`:1075`) are **byte-unchanged**, verified by a diff over the
   **current** line ranges (SS 2.11).

**9.3 RETIRING IT EARLIER FAILS THE SEQUENCING ASSERTION**, and this document performs no retirement.

---

## 10. NON-GOALS

**10.1** This contract does **not** authorize hook code. **10.2** It does **not** rewire either
settings surface. **10.3** It does **not** widen, narrow or touch any guard array; the placement assertion makes
widening a RED "EVEN IF every placement leg passes". **10.4** It does **not** promote the
guard from tripwire to boundary (SS 2.7). **10.5** It does **not** discharge either assertion --
the sequencing assertion's discharge needs the banked ratification plus the order property; the placement assertion's needs a real
placement. **10.6** It does **not** edit sealed bytes: the placement assertion's and the ruling record's stale line citations are
**registered** at SS 2.11, not corrected in place. **10.7** It does **not** rule OPEN-A. **10.8** It
does **not** specify the placement script's implementation -- only the contract it must satisfy.

---

## 11. RESIDUALS, LIMITS, AND WHAT IS CARRIED RATHER THAN DERIVED

**11.1 THE TRUST MODEL IS A REDUCTION, NOT A SOLUTION.** SS 6 does not make an agent-writable source
trustworthy; it establishes that nothing can, and reduces the operator's act to one command. **A
future reader must not read SS 6.5 as having closed the trust problem.** It bounds it.

**11.2 THE VERIFY LEG CANNOT DETECT A SUBSTRATE THAT WAS NEVER STAGED.** It re-derives what is
present. A witness that was never assembled leaves nothing to verify, and no arm here reports it --
the same E5-ii shape the manifest-completeness residual carries.

**11.3 `Test-WitnessedSubstrate` HAS A KNOWN HOLE, NOT RELIED UPON HERE.** an interim-placement finding
registers that `Up\b.*healthy` (`mission-lib.ps1:713`) also matches the literal
`Up 2 days (unhealthy)`. SS 5.3 item 1 inherits that predicate and therefore inherits the hole.
**Registered, not cured, and this contract rests no claim on that clause.**

**11.4 CARRIED ON AUTHORITY, NOT DERIVED FROM DISK.**
- The operator's rulings, including the spec-first ruling itself -- a builder cannot derive a
  ruling from disk. Their consequences are derived and cited; their existence is testimony.
- The dispatch's instruction to specify a product-side URI scheme's resolution inputs. **NOT ADOPTED**, with the
  derivation at SS 5.5: the named scheme is a product-side document scheme with zero
  presence in the framework seam. **Raised for the operator's ruling rather than resolved by this
  seat**; if the operator meant identity resolution generally, SS 5.5 answers it, and if a distinct
  scheme was intended, this document is silent on it by choice and says so.
  **RULED (operator): non-adoption RATIFIED; an erratum records the commissioning
  instruction's provenance.**
- `wiring_status: UNVERIFIED` (SS 2.3) is the fragment's own declaration about itself; this seat did
  not test the live harness.
- The eleven-field Stop payload (SS 2.4) is carried from `evidence-stop-finalize.ps1:54-57`, whose
  own basis is an operator-registered probe. **Not re-probed here.**

**11.5 NOTHING UNDER `tools/framework/**` WAS WRITTEN, STAGED, HASHED OR RUN** in producing this
document. Every citation above came from a file-tool read. Scope: the window from the authoring
session's first tool call to the writing of this file.

**11.6 NO FIGURE IN THIS DOCUMENT IS AN OPERATOR FIGURE.** Every line citation is this seat's
read of disk at the commit it was written at and is re-checkable by read-only git plus a file read, which is the
standard the sequencing assertion sets.

---

## 12. RATIFICATION

**12.1** This document is **PROPOSED**. It carries no force until the operator ratifies it and the
ratification is banked (the sequencing assertion).
**RATIFIED by the operator: the ratification is banked as an amendment.
The PROPOSED line above is preserved as the record of what this document said before
ratification and no longer describes its state. RE-RATIFIED by the operator together with the
SS 5.4 REVISION, banked at this ceremony's amendment.**

**12.2 BEFORE RATIFYING, THE OPERATOR SHOULD RULE -- ALL THREE RULED:**
1. **OPEN-A** (SS 4) -- (A-i) operator-invoked placement script with a wired verify leg, or (A-ii).
   **This must be ruled; it changes what the placement assertion's discharge looks like.**
   **RESOLVED: (A-i) RULED -- placement script plus a Stop-wired verify leg; (A-ii) rejected.**
2. The **product-side URI scheme** item (SS 5.5, SS 11.4) -- not adopted, with derivation.
   **RESOLVED: non-adoption RATIFIED; an erratum banks the commissioning instruction's provenance.**
3. Whether the **SS 2.11 stale-citation** finding rides this ratification's banking as an
   erratum propagation item.
   **RESOLVED: YES -- it rides this banking as an erratum propagation item.**

**12.3** On ratification, the banking entry should record: that the contract exists as its own
artifact on disk (the sequencing assertion's EXISTENCE item), that it addresses all four content items (the CONTENT
item), that it addresses both settings surfaces and says which is authoritative (the SURFACES item),
and that **no hook code exists at the time of banking** -- which is what makes the ORDER item
checkable by read-only git thereafter.
