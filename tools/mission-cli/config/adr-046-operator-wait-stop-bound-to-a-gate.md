# ADR-046 — The operator-wait stop: a seat may stop while ONE named gate it cannot produce does not yet stand

> **Status:** **Accepted** — operator-ruled, resting-status rule S1 per ADR-033.
>
> **Ratified by** the operator's ratification file `adr-046-ratification.md`, sha256
> `caa7aee8aa52a300007a8fbe79a3be1f6e35b4010262964f508fc724a3552c07`. It ratifies:
>
> - the draft at framework commit b1b98fb1;
> - the falsifiers at 6c3820c0;
> - four rulings:
>   - (u) the choices this record marked as taken stand;
>   - (v) D8 is option (b) on one condition: the seat's own part is already done, decided by the console's own settle
>     precondition, CALLED as the tool holds it, never restated -- **WITHDRAWN** (below);
>   - (w) D1-W stays (a);
>   - (x) D9 stays (b).
>
> **Amended by** the operator's ratification amendment `adr-046-ratification-amendment-1.md`, sha256
> `463c17cafab2e3ee7d5c971c3e224a1220e3386e94b2c0aaea88fdab67467ae9`. Its ruling (y) withdraws ruling (v): D8 is
> option (a), and `settled` is in the grammar for push only.
>
> This text is the draft brought to those rulings. It is standalone in `tools/mission-cli/config/`, and class AUTHORED
> in the manifest (not installed). Whether it ships is left to packaging.
>
> **Amended twice.** Amendment 1 followed the build's validator round 1, within rulings (u)..(x). Amendment 2 is
> ruling (y), after the build's validator round 2. Where a section "Amendment N" and the text below differ, the later
> governs, and the text below has been brought to both.
>
> **Nature & path.** A framework-ADR (a standalone `adr-0NN` file), not the mid-mission amendment ceremony. The three
> admitted-stop arms before it were each admitted by a numbered amendment to the first host's acceptance record,
> which is not in this tree. The amendment this form needs is drafted, unnumbered, in the last section.

## Context

The stop evaluator, `tools/lam/mission-goal-check.ps1`, run as the Stop hook, admits a stop:

- when the goal is MET;
- under an open HALT;
- for an absent goal;
- under three bounded arms:
  - `ungated_placement_absent`: an untracked amendment awaiting its gate;
  - `ungated_manifest_absent`: an untracked round manifest awaiting its gate;
  - `handoff_brief_present`: a HANDOFF head, admitted once.

It has no form for "this seat has done its part and the next act is the operator's". On the last product arc that
state arose at least seven times: a settle awaited, a gate to be minted, a push, a container recreate, a ruling.

Each time, the seat placed an untracked holding manifest under `.mission/dispatches/` to borrow the manifest arm's
stop. The manifest was never minted, and the operator's block later moved it to the close folder: one console act and
one cleanup act each. Once, an operator window was raised as a HALT for want of a form, and a HALT costs a ruling.

A wait bound to an observable costs no attention; as free text it is a way out of the goal. This record binds it to
the one observable on disk a seat cannot produce, a gate, and only where an operator act can always release it.

## Decision (proposed)

### The rule, in the evaluator's terms

**Opt-in.** A goal may declare a fourth arm, detector type **`operator_wait_present`**. It takes no key, and any key
it is given is named "not read by this type". Where no goal declares it, nothing below runs, and the verdict artifact
is what it is today. If the type is declared twice, the first reading is the run's, as for the handoff arm (the
detector loop keeps each arm's first reading).

**The head.** The arm reads the FIRST line of `<MissionRoot>\.mission-runtime\lam\STATUS.md` as the handoff arm reads
it (`Get-HandoffDecision`): the byte-order mark is not part of the text, and CR and trailing blanks are
dropped, so `... minted ` reads as `... minted`. A first line that begins `OPERATOR WAIT` (ordinally) is a WAIT HEAD.
Any other first line is no wait head, and the arm is inert. A wait head must read, whole:

    OPERATOR WAIT gate <kind> <id> <state>

- **`<kind>`** is one of `push`, `amendment-material`, `dispatch`, `supersession`, `completion-acceptance` or
  `reclose`, compared ordinally. Two kinds of the gate tool's closed set (mission-gate.ps1:369) are left out:
  - `halt-ruling`, because a ruling is asked by a HALT;
  - `witness-attested`, until the operator rules choice D1-W.
- **`<id>`** is one token `[A-Za-z0-9][A-Za-z0-9._-]*`, 1 to 200 characters. The pattern is the dispatch runner's
  gate-id rule (lam-dispatch-gate.ps1:92). The bound is the one the placement arm keeps, because a longer id made the
  console refuse the mint (mission-goal-check.ps1, `Limit-PlacementId`). The gate tool itself checks no id pattern
  except for halt-ruling.
- **`<state>`** is `minted`, or `settled` with kind `push` only (D8 (a), ruling (y)). The console's `settle` verb
  also takes amendment-material and reclose (mission-gate.ps1:1110), but a wait on their settle is not in the grammar
  and stays a HALT.

The prefix is not `AWAITING` because the AWAITING lines are the evaluator's own output (the placement arm's ruling
(4)). `seat.py head --replace-handoff` refuses a new line 1 beginning HANDOFF, AWAITING or OPERATOR WAIT (seat.py,
`run_head`), so a successor cannot replace a HANDOFF head with a wait.

**The condition, read from disk with no judgement.** The gate's canonical path is
`<MissionRoot>\.mission\gates\<kind>-<id>.yaml` (`Get-GatePath`, mission-gate.ps1:501-506). The arm reaches exactly
one of four readings:

- **ABSENT (unmet), established positively.**
  - `.mission` is a real directory (no reparse point) that enumerates without error.
  - Either it holds no entry whose name folds (ASCII case) to `gates`, or `gates` is such a directory, it enumerates
    without error, and it holds no entry whose name folds to `<kind>-<id>.yaml`.

  Anything else is NOT ESTABLISHED. That covers a `gates` that is a file or a link, an enumeration that throws, and
  an entry whose name folds to the leaf but is not spelt exactly so.
- **STANDS.** The exact leaf is a file whose bytes decode as strict UTF-8. It carries exactly one column-0 `kind:`,
  one `id:` and one `binds_sha256:`, each counted as `Get-PlacementGateField` counts them:
  - `kind:` equals `<kind>`, and the shared classifier `Get-LamGateClassForText` reads it the same;
  - `id:` equals `<id>` ordinally;
  - `binds_sha256:` is 64 hex.

  A file there that fails any of these is NOT ESTABLISHED. That includes an `id:` that differs from the head's only
  in case: `approve` refuses where any file already stands (mission-gate.ps1:163), so no mint could ever fix it.
- **`minted` is met** when the gate STANDS, whatever its state: open, consumed, revoked or disqualified.
- **`settled` (push) has three outcomes:**
  - It is **met** when the gate STANDS with `consumed_at` set and its one `consumed_basis:` begins
    `post-push witness by console` (mission-gate.ps1:1343).
  - It is **unmet**, and the stop is admitted, when the gate is ABSENT, or STANDS unconsumed, unrevoked and not
    disqualified.
  - It is **REFUSED** when the gate STANDS consumed on any other basis, carrying part of a consume block with
    `consumed_at` null, revoked, or disqualified (`witness_expired_at`). The first two are VOID (Amendment 1, item 2).

  The refused case covers the seat's own in-session push, which the hook stamps "pre-push in-flight witness ..."
  (evidence-common.ps1:2767). After that, the console's settle refuses "first stamp wins"
  (mission-gate.ps1:1155-1189), and it refuses a revoked gate (mission-gate.ps1:191), so no operator act could ever
  meet the condition. A wait no operator act can release is refused, never held.
- **`settled` on any other kind is not in the grammar (D8 (a), ruling (y)).** A head naming it is refused by the
  grammar, with the reason the grammar gives `settled` on dispatch, whatever its gate's state or the record's lines,
  so the settle of amendment-material and reclose stays a HALT. The order the code takes (corrected under ruling (z)):
  the record is read first, and every earlier admitted triple's gate with it, so a D-4 triple may be released or
  recorded void in the same evaluation; then the head; then the grammar refuses it, before the record's readability,
  its loose lines, its lines for this triple, or this triple's gate decide anything.

**The evaluator reads; it calls nothing.** For every head and every gate state the arm reads files under the mission
root and writes only the verdict artifact and its record there. It starts no process, compiles nothing and writes no
temporary file (Amendment 2).

**The record.** `<MissionRoot>\.mission-runtime\lam\operator-wait-releases.jsonl` sits in the runtime plane that
.gitignore excludes, and its name does not match the HALT scan's `HALT-*` (`Get-OpenHalts`). It holds JSON lines
`{"event": "operator_wait_admitted" | "operator_wait_released" | "operator_wait_voided", "at", "goal", "kind", "id", "state", "head", "read"}`,
and this arm is its only writer.

- Triples are matched with kind and state ordinal and the id ASCII case-folded, so `W3-S1` is `w3-s1`.
- A line that does not parse as such a record refuses every head whose id (folded) it spells. This is the handoff
  record's fail-closed rule (`Find-HandoffRecordedLine`).
- A record that exists and cannot be read refuses every head.

Every append is made under one exclusive handle, after the record is re-read through that handle
(`Add-HandoffAdmission`'s way). There are two kinds of append:

- **ADMITTED (hook only).** A Stop hook that admits a triple not yet admitted appends one `operator_wait_admitted`
  line. This is the durable trace of the claim, kept after STATUS.md and the verdict artifact are rewritten.
- **RELEASED (any evaluation).** An evaluation, hook or hand, that reads a head's condition met appends
  `operator_wait_released`. It also does so for every earlier admitted and unreleased triple in the record whose
  condition it now reads met. From then on the triple is REFUSED under any goal and in any edition, and the goal
  decides as if the wait had never been.

**One unreleased wait at a time (choice D9, taken).** A head whose triple differs from an admitted, unreleased triple
in the record is REFUSED, naming that triple, until that triple is released or voided (Amendment 1, item 2).

**Fail closed.** The seat writes the claim, so everything the arm cannot establish REFUSES the head. This is the
handoff arm's direction (its block's "FAIL CLOSED"), the opposite of the two AWAITING arms. It covers:

- a head out of the form;
- NOT ESTABLISHED;
- a `settled` refusal;
- an unreadable record, or a record line that spells the id;
- the D9 bound;
- an arm that throws.

A refused head fails no detector: it blocks nothing the goal would not block. An admission whose ADMITTED append
fails, or is refused when re-decided under the handle, is NOT admitted. The verdict is then NOT_MET and the hook
blocks, as for the handoff arm: in hook mode the goal's other detectors were already recorded NOT EVALUATED. The
failure is named (Amendment 1, item 3). A RELEASED append that fails leaves
the wait not admitted (its condition is met) and names the failure.

**The verdict.** An established, unmet, unreleased wait within the bound ADMITS the stop with the verdict
**`AWAITING_OPERATOR`** (by hand, exit **7**). The ladder:

1. the halt-scope grammar fault: NOT_MET
2. **HALT**
3. AWAITING_AMENDMENT_GATE
4. AWAITING_DISPATCH_GATE
5. **AWAITING_OPERATOR**
6. HANDOFF_ADMITTED
7. unknown: NOT_MET
8. MET
9. NOT_MET

The wait sits after the two arms that spend nothing and before the handoff arm, which spends its brief only when
nothing else admits. In hook mode, once the wait admits, every non-arm detector is recorded NOT EVALUATED, as for the
other arms (the detector loop's hook-mode short-circuit). An open HALT outranks it exactly as it outranks every arm (R4), and the wait line is named in
the HALT reason's "Also admitted:".

### The verdict's new fields (R7)

These keys are written only when the goal declares the arm, and each is `[]` when empty. `<gate>` is the gate's path
relative to the mission root; `<record>` is the record's.

The strings below are the code's own words, as amended (Amendment 1, item 7).

- **`operator_wait`** holds the admissible wait:
  `OPERATOR WAIT gate <kind> <id> <state> -- ADMITTED -- read <gate>: <ABSENT | STANDS, consumed_at null>; <record>: no release of this triple`.
  One of these endings follows:
  - `; admission recorded at line <n>`
  - `; admitted before, at line <n>`
  - `; a hand run records no admission`
  - `; NOT ADMITTED: the admission could not be recorded (<why>)`
  - `; NOT THE VERDICT: <verdict> outranks it, and nothing is recorded for it`
- **`operator_wait_released`** holds each triple this evaluation released, or found released before:
  - `OPERATOR WAIT gate <kind> <id> <state> -- RELEASED: read <gate>: STANDS, <consumed_at null | consumed_at <ts>, consumed_basis <basis>>[, REVOKED][, DISQUALIFIED]; recorded at <record> line <n>`
    (a `minted` wait is released by an open, a consumed or a revoked gate, so its read may say `consumed_at null` or
    `REVOKED`; where the record cannot be written, the ending is `; the record could not be written (<why>), so it is read again at the next evaluation`)
  - `... -- RELEASED BEFORE, at <record> line <n>; this line admits nothing`
- **`operator_wait_refused`** holds why a wait line was refused, `OPERATOR WAIT line NOT admitted -- <why> -- line: <the line>`.
  It also holds each admitted triple recorded void, `... -- VOIDED: <why> (read <what>); recorded at <record> line <n>, and it frees the one-wait slot`.

The hook reasons:

- **The approve reason** names the `operator_wait` line and its release: "the operator's mint of `<gate>`" or "the
  console's settle of `<gate>`".
- **The NOT_MET block reason:**
  - It names a refusal, as the handoff refusal is named.
  - Its list of admitted stops gains "an OPERATOR WAIT line first on STATUS.md naming one gate not yet minted or
    settled (operator_wait_present)".
  - Its "Nearest for this state" names the OPERATOR WAIT line when one was read and refused.

### What is refused (R5)

Every one of the following admits nothing; each lands in `operator_wait_refused`:

- a first line `OPERATOR WAIT` with nothing after it;
- free text;
- two conditions;
- an unknown kind word, `halt-ruling` or `witness-attested`;
- an id that is not one token, or longer than 200 characters;
- a state other than `minted` or `settled` (case-sensitive, so `MINTED` is refused);
- `settled` on any kind but push (D8 (a), ruling (y)): on amendment-material and reclose too, whatever their gate's
  state;
- any observable that is not a gate: a ledger tag, an operator-acts line, a file and a sha256, a commit, an origin
  state.

The grammar has no slot for an untestable condition, so one cannot be written.

### R2: who can produce the observable

**R2 rests on the gate tool, the console and the guard, not on this arm.** No falsifier over the evaluator can show
that a seat cannot mint. The layers that stop it are:

- the tool's refusal under four session conditions without the console's in-process token (mission-gate.ps1:28-53);
- the guard's file-tool deny of `.mission/gates` (evidence-common.ps1:3627-3635, 6683-6687);
- the shell-route text-match deny (6898-6900);
- the mint-verb tripwire (6894-6896).

**These are tripwires, not a boundary** (mission-gate.ps1:75-95). A hand-written gate is the residual that the
stage-2 ownership setup closes (LAM-INSTALL 5.6.1). A scrubbed console tree an agent builds is a further residual
(mission-gate.ps1:111-120). Both already forge every authorization, and this form adds nothing to either.

The other candidates are all seat-writable, and the guard names none of them, so none is in the grammar:

- the memory ledger, by `mission-ledger-append.ps1`;
- `.mission-runtime\operator-acts.log`, which the console calls "not an independent record";
- any file with a sha256 outside `.mission/gates`.

A dispatch gate's consumption and an in-session push consumption are the seat's own acts, so neither releases a wait.

### Options, and the case against each choice

| # | choice | options (what each gives up) | taken | the strongest case against it |
|---|---|---|---|---|
| D1 | the release observable | (a) a gate only: gives up host acts and free rulings; (b) also a ledger tag, an operator-acts line or a file and sha256: all seat-writable, so R2 fails | (a) | a host act still costs a HALT |
| D1-W | `witness-attested` as the operator's attestation of a host act or a ruling | (a) excluded; (b) admitted in the kind set, giving the kind a use no ruling has defined | (a), RULED (w) | with (b) a container recreate costs one mint instead of a HALT and a ruling; the ruling answers that such a mint saves no console act over a HALT and its ruling gate |
| D2 | where the wait is declared | (a) STATUS.md's first line: overwritten by the next edition, nothing tracked; (b) a wait file under `.mission-runtime/lam/waits/`: accumulates; (c) a goal-file key: tracked, the operator's contract, and a seat editing its goal is the escape R5 forbids | (a) | one head at a time: a seat cannot wait and hand off in one edition; a seat in a linked worktree that may not write `.mission-runtime/lam/**` cannot declare one, as for the handoff head |
| D3 | opt-in | (a) the goal declares the type; (b) every goal admits waits | (a) | one more line per goal, and a goal that forgets it costs the old HALT |
| D4 | once only (R3) | (a) a record of releases; (b) none, relying on the gate standing: a gate moved out of the folder re-arms the wait; (c) spend at admission, the handoff way: contradicts "admits while unmet" | (a) | a seat can truncate the record, since the runtime plane is seat-writable. That re-arms only a wait whose gate no longer stands, and it erases the admission trace; the record is a tripwire like the handoff record |
| D4b | who records a release | (a) any evaluation; (b) the Stop hook only | (a) | a hand run then writes a runtime file outside its verdict. Hand runs of `instrument_exit0` already write captures and kept copies (its reuse block), so this is not new in kind. A release only takes a stop away |
| D5 | the direction on doubt | (a) refuse; (b) admit, the AWAITING arms' way | (a) | a seat genuinely waiting behind an unreadable gates folder is blocked, and has only a HALT |
| D6 | the rank against MET | (a) above MET, as every arm; (b) below MET | (a) | a met goal with an unmet wait exits 7, not 0, by hand |
| D7 | `settled` on push | (a) met only by the console's basis; consumed on another basis, carrying part of a consume block (Amendment 1), revoked or disqualified REFUSES; (b) any consumed push gate meets it | (a) | it reads a basis sentence: if the console's wording changes, push waits are refused, toward a block, not a free stop |
| D8 | `settled` on amendment-material and reclose | (a) not in the grammar: the console's settle needs the SEAT's commit holding the bound bytes on HEAD (mission-gate.ps1:184-190), so a seat could withhold it and hold the operator's release hostage; (b) admitted only while that commit is already on HEAD, decided by the console's own settle precondition | (a), RULED (y) (Amendment 2). (b) was ruled (v), built at 38311c10 by calling the tool's `settle -ComposeOnly` from the Stop hook, and withdrawn | "awaiting a settle" of an amendment or a re-closure is not covered and stays a HALT |
| D9 | how many unreleased waits | (a) no bound: a seat can stop again and again on fresh invented ids; (b) one admitted, unreleased triple at a time | (b), RULED (x) | an abandoned wait blocks every later one until the operator mints its gate (`minted`), settles it, or reapproves a revoked one and settles it (`settled`, push). A push `settled` wait that no act can release any more is recorded VOID and frees the slot (Amendment 1, item 2). The seat can defeat the bound by truncating the record, the D4 residual. A triple outside the grammar in the record can hold the slot (Amendment 2, D-4) |
| D10 | an admission trace | (a) the hook appends `operator_wait_admitted` once per triple; (b) none: the claim vanishes when STATUS.md is rewritten | (a) | one more append in hook mode, and one more way a write failure turns an admitted stop into a block |

### What the form gives up (R9)

**What a seat can now do that it could not.** In a goal that declares the arm, a seat can stop with the goal unmet,
no HALT raised and no file placed, by writing one line naming a gate that does not stand. It stays stopped while that
gate does not stand, one such wait at a time.

**The worst misuse.** The seat names an invented gate the operator never means to mint, such as
`OPERATOR WAIT gate supersession zz-1 minted`, and stops with nothing done. The design does NOT refuse it: no reading
of disk tells a pretext from a wait. What bounds it:

1. The goal must opt in.
2. The verdict and the hook's reason print the claim itself.
3. The record keeps it after STATUS.md moves on (D10).
4. D9 allows one such wait at a time, until the operator mints the named gate. Minting a gate that nobody needs
   releases it and authorizes nothing the seat can use: a supersession, completion-acceptance or reclose gate binds
   bytes the operator chooses.
5. Truncating the record defeats 3 and 4. That is the stated residual.

Compared with the manifest arm, this form leaves less residue (a record line, not a placed file). Every wait it admits
can be released by operator acts as it was admitted. A push `settled` wait whose gate later becomes one no act can
settle (consumed on another basis, or carrying part of a consume block) is refused from then on, and recorded VOID
where it was admitted, so it holds neither a stop nor the one-wait slot (Amendment 1, item 2).

**What it refuses that a careless form would admit:**

- a wait the operator cannot release: a seat-consumed or revoked push gate, any settle of an amendment or a
  re-closure, whose commit the seat could withhold (D8 (a)), an unmintable id, or an id differing only in case;
- admission on doubt about a gate's absence;
- re-arming a released triple by case;
- a successor's first stop through `seat.py --replace-handoff`, closed by turn 2's seat.py change.

### Cases it does not cover

- **A host act or a free ruling.** It stays a HALT (ruling (w)).
- **A settle of an amendment-material or reclose gate.** It stays a HALT (D8 (a), ruling (y)). A seat may still wait
  `minted` on such a gate.
- **A push the operator makes and does not settle.**
- **A wait on two conditions, on an external state (CI, origin, a container), or on time.**
- **A dispatched worker.** The hook already approves under `LAM_DISPATCH`.
- **A wait and a handoff in one edition.**
- **A gate the operator moves out of `.mission/gates/` before any evaluation reads it standing.** The wait admits
  again until a gate stands.
- **An arm that throws.** Specified (it refuses), but no falsifier: it cannot be forced from disk without a fault seam
  in the evaluator. A failed append CAN be forced (a read-only record), and has a row (W-19).
- **Two evaluations at once.** The record is held with no sharing, so a second evaluation that cannot open it refuses
  its head, and the goal decides. Concurrent hooks may block each other spuriously; they never both admit, because the
  admission is re-decided under the handle (Amendment 1, item 4).
- **What the build's validator round 2 left open** is stated under Amendment 2: D-4 and its notes 5, 7 and 9.

### Contact with the rest of the tree, and R8

The build changes no sealed file: `tools/framework/**` and `tools/evidence-hooks-next/hooks/**` hold no verdict, goal
or STATUS logic.

`tools/lam/mission-telemetry.ps1` AST-lifts the HALT functions, `Read-GoalDetectors`, the grammar functions and
`ConvertTo-ManifestDisplayText`, and it lifts four statement ranges by prefix (mission-telemetry.ps1:855-889). The arm
calls these and changes none of them, and its code sits outside the four ranges. The snapshot reads `verdict` as a
scalar, so the dashboard does not move.

The build changes:

- the evaluator;
- `provenance/manifest.jsonl`;
- this record (Accepted; AUTHORED);
- `tests/lam/falsify-operator-wait.ps1`, which gains the members below;
- `tests/lam/instrument-WP-3.ps1`:
  - C-1c's known list gains the type;
  - C-1as's arm-type list gains it, because an arm is evaluated after a short-circuit and that list exempts arms;
  - C-2d gains the count word "seven" and a PARSER row for the ratified seven-verdict sentence. Its pinned page and its
    drives are unchanged.
  - C-1ba is NOT changed. Its goals declare none of this arm, and its BASE rows run a pinned evaluator that would read
    the type as unknown.
- `tools/lam/seat.py`: the verdict word, and the `--replace-handoff` refusal of `OPERATOR WAIT`;
- `docs/framework/vanguard-collective-user-guide.md`: the verdict list, how a goal opts in, the head, what releases
  each wait, and what stays a HALT.

The smoke goal does not declare the arm, so `mission.ps1` and `INSTALL.md` are unchanged. `mission-gate.ps1` is
unchanged, and the evaluator does not call it. `tests/install/falsify.ps1` is as it was at 6c3820c0: its case ra10's
census row for the evaluator, changed for ruling (v)'s child, is returned (Amendment 2).

### The falsifiers

`tests/lam/falsify-operator-wait.ps1` is run by path. It builds synthetic missions under %TEMP% and reads only the
evaluator's verdict artifact (its `verdict:`, `short_circuited:` and list keys), the hook's decision and reason, and
the exit. It asserts the invented ids in them, never a word naming the form.

Every row is one of:

- **GUARD**: holds before and after the build.
- **FALSIFIER**: RED on a tree without the form, because the type is unknown; GREEN after. Amendment 2's rows are
  RED on the tree that built ruling (v) (38311c10), where the form admitted or called what D8 (a) refuses, and GREEN
  after its removal -- except W-4's two `settled` rows with no gate, which that tree refused too (ruling (z), D-B(ii)).
  W-28's rows are GUARDs: they hold on every tree that has the form.

Every refused or released case carries a FALSIFIER row that reads the arm's own `operator_wait_refused` or
`operator_wait_released`. So an arm that refused everything would not turn the guards' members green.

| member | case |
|---|---|
| W-1 | unmet wait admitted: hook, hand exit 7, NOT EVALUATED short-circuit, what was read |
| W-1m | an unmet wait over a met goal: AWAITING_OPERATOR, exit 7 (D6) |
| W-2 | `minted` met by an open, a consumed and a revoked gate: not admitted, released |
| W-2p | push settled by the console: released |
| W-2m | a released wait over a met goal: MET, released; and MET again after its gate is gone |
| W-3 | after release: the same triple, another goal, the id in another case, and a release a hand run recorded |
| W-4 | R5: no condition, free text, two conditions, an unknown kind, `MINTED`, a 201-character id, `halt-ruling`, `witness-attested`, `settled` on dispatch, amendment-material and reclose |
| W-5 | R5: observables a seat writes (a ledger tag, an operator-acts line, a file and sha256) |
| W-6 | an open HALT governs, and its reason names the wait |
| W-7 | the record beside the HALT scan is not a HALT; control: the same bytes under `halt-*` are |
| W-8 | opt-in |
| W-9 | a push gate consumed in session is refused, not held |
| W-10 | `gates` not established (a file in its place) refuses |
| W-11 | a standing gate whose `id:` differs in case refuses |
| W-12 | a gate not UTF-8, or with two `id:` keys, refuses |
| W-13 | an unreadable record refuses |
| W-14 | the ladder: AWAITING_DISPATCH_GATE outranks the wait, and the wait is still named |
| W-15 | D9: a second triple while the first is unreleased is refused, and the block reason names it |
| W-19 | an admission the record cannot take (a read-only record): the hook blocks NOT_MET, the wait named; by hand, exit 7 |
| W-20 | an admitted `settled` wait whose gate the seat's own push then consumed: recorded VOID, the next wait admitted, the void triple never again |
| W-21 | the earlier admitted triple read met under a later head: released, and the later wait admitted |
| W-22 | a push gate carrying part of a consume block refuses |
| W-23 | a BOM, CR LF and trailing blanks on the head; the arm declared twice; a loose record line spelling the id; the leaf in another case; a `gates` junction |
| W-25 | D8 (a), in git fixtures: `settled` on amendment-material and reclose is refused BY THE GRAMMAR where the console's settle would succeed now (the bound file committed at the gate's bytes; the re-closure commit made) and where the console's settle stamp stands (not released); and, whatever the gate's state or the record's lines, where `gates` is NOT ESTABLISHED, the gate is revoked or carries part of a consume block, the record holds a released, a voided or an admitted line of the same triple, the record cannot be read, or a loose record line spells the id (both kinds). Each refusal gives the very reason `settled` on dispatch is given |
| W-26 | every head form (each kind `minted` and `settled`, the kinds left out, no condition, free text, no wait head), as the hook and, for the two settled forms ruling (v) answered, by hand; gates absent or open: the evaluation starts no process but itself and creates no file outside the mission root. A job object counts the processes created as its descendants; a process started through WMI, the task scheduler or COM is not counted, and those routes are ruled out by the reading of the functions the arm reaches (N2). A watcher sees the files made in the member's folder |
| W-27 | D-4: an admitted `settled` triple of amendment-material or reclose already in the record (as 38311c10 could write it): its gate stamped by the console's settle -- recorded VOID, and a new wait admitted; its gate open -- it holds the slot, the new head refused naming it |
| W-28 | a revoked gate is not void (Amendment 1 item 2; ruling (z), D-C): an admitted push `settled` triple, and an admitted D-4 triple, whose gate is revoked, under another head -- the slot is held, the new head refused naming the triple, and the triple not recorded void |

W-4 also carries ids outside ASCII (the Kelvin sign, a dotted capital I), and its two `settled` rows on
amendment-material and reclose with no gate. W-16, W-17, W-18 and W-24 were ruling (v)'s members; they are retired
with it (Amendment 2), and their numbers are not reused.

## Amendment 1 (after the build's validator round 1, within rulings (u)..(x))

The first build (76769023) was read by a fresh validator. Two refutations and five defects were accepted. Each item
below is now the rule, and each is built.

1. **The id is matched case-sensitively** (`-cnotmatch`), so an id outside ASCII is refused. PowerShell's `-notmatch`
   folds culture-aware: it read the Kelvin sign as `k` and a dotted capital I as `i`.
2. **VOID.** A `settled` gate (push, since Amendment 2) is one no operator act can settle any more when it is:
   - consumed on another basis than the console's; or
   - carrying part of a consume block with `consumed_at` null, a shape the console settle refuses ("first stamp
     wins").

   A head naming such a gate is refused. Where its triple was ADMITTED, any evaluation records
   `operator_wait_voided`. A voided triple counts as released for the one-wait bound, so it frees the slot, and like a
   released one it never admits again.

   A revoked or disqualified gate is NOT void. The operator's reapprove mints a fresh gate at the same path, so it is
   refused while it stands so, and it holds the slot until a settle releases it.
3. **A failed admission blocks.** When an admission's append fails, or the append re-decides the admission away, the
   verdict is NOT_MET and the hook blocks, as for the handoff arm. A hand run records nothing and reads the wait.
4. **The admission is re-decided under the record's handle.** It is not written where the re-read record now holds a
   release or a void of its triple, or another admitted triple that nothing released or voided.
5. **WITHDRAWN by Amendment 2.** It ran ruling (v)'s settle precondition in a child process under a 30-second
   deadline. With D8 (a) there is no precondition to run.
6. **The head is read as the handoff arm reads it**, with a StreamReader that detects a byte-order mark. A UTF-8,
   UTF-16 or UTF-32 STATUS.md with a mark, CR LF and trailing blanks reads the same line.
7. **The verdict strings** in "The verdict's new fields" are the code's own words.

The draft text above is brought to these items.

## Amendment 2 (ruling (y): ruling (v) withdrawn, D8 is option (a))

By the operator's ratification amendment `adr-046-ratification-amendment-1.md`, sha256
`463c17cafab2e3ee7d5c971c3e224a1220e3386e94b2c0aaea88fdab67467ae9`, which amends the ratification (sha256
`caa7aee8aa52a300007a8fbe79a3be1f6e35b4010262964f508fc724a3552c07`). Every item below is the rule.

**What the build's validator round 2 showed** (at 38311c10). To call the console's settle precondition under a
deadline, the evaluator as built started a child process, compiled a small helper at hook time, and read the answer
back from a file in the user's temporary folder. A process left running as the same user could write that file first,
so a settle wait was admitted while the console's own settle refused it. It could also alter the helper's source
before it was compiled, so code from outside the evaluator ran inside the Stop hook. Before that build the evaluator
compiled nothing and wrote no temporary file. Both channels existed only to serve ruling (v).

1. **`settled` is in the grammar for push only.** A wait on the settle of an amendment-material or reclose gate is
   refused by the grammar, whatever its gate's state or the record's lines, and both cases stay a HALT. (The record
   and earlier admitted triples are read first; see the order under "The condition".) `minted` on those kinds is
   unchanged.
2. **The evaluator starts no process, compiles nothing and writes no temporary file for this form**, for any head and
   any gate state. What the arm writes is the verdict artifact and its record, under the mission root (W-26).
3. **What goes with ruling (v):**
   - the call of `mission-gate.ps1 settle -ComposeOnly`, its child, its deadline and its temporary file (Amendment 1,
     item 5);
   - the `record of use by console` reading, and the VOID of amendment-material and reclose gates;
   - members W-16, W-17, W-18 and W-24;
   - falsify case ra10's census row for the evaluator, which returns to its 6c3820c0 value `amp=3 psi=2`.
4. **What stays, because it does not rest on ruling (v):**
   - the ASCII-only id rule (Amendment 1, item 1);
   - the VOID of a push wait consumed on another basis or carrying part of a consume block (item 2);
   - a failed admission blocks (item 3);
   - the admission re-decided under the record's handle (item 4);
   - the head read as the handoff arm reads it (item 6);
   - the verdict strings (item 7).
5. **Not taken** (the ruling's words): curing the two channels with a prebuilt helper and an inherited handle, which
   adds native process code to the Stop hook in a patch release; shipping the build as it stood.

### What round 2 left, stated and not cured

- **D-4. An admitted triple outside the grammar can hold the one-wait slot.** The evaluation that releases or voids
  earlier admitted triples skips a triple whose kind is not one of the six, whose state is not `minted` or `settled`,
  or whose id is not one ASCII token. Such a line is never released or voided, so every other head is refused under D9
  until the record is mended by hand: a Kelvin-sign id the first build (76769023) recorded, or a hand-written line.

  An admitted `settled` triple of amendment-material or reclose (the 38311c10 build could record one) is read as
  `settled` is read, by push's rule, because `settled` is push's alone (Amendment 2, round 1 of its validators, D1):
  - its gate consumed on any basis but `post-push witness by console`, the console's own `record of use by console`
    stamp included, or carrying part of a consume block: VOID, recorded `operator_wait_voided` (its reason says
    "consumed on another basis than the console's settle"), which frees the slot;
  - its gate consumed on the console's push basis, `post-push witness by console`: RELEASED;
  - its gate absent, open, revoked, disqualified or NOT ESTABLISHED: it holds the slot. For an amendment-material
    gate the console's settle needs the seat's commit, so the seat can keep that slot held.

  Either way it fails closed: it blocks, never admits. No released edition wrote such a line.
- **Note 7.** Where the admission is re-decided away under the handle, the hook's block reason quotes the generic
  detail ("the record ... could not take the admission"), while the verdict's `operator_wait` line carries the
  re-decision's own reason. Its "Nearest for this state" is then a HALT. Where an earlier triple was voided, "Nearest"
  names the OPERATOR WAIT line, though the head itself may not be what needs mending.
- **Note 9: clauses with no row.**
  - a RELEASED append that fails;
  - a disqualified gate (`witness_expired_at`);
  - the void of an ADMITTED triple carrying part of a consume block;
  - reapprove of a revoked push gate, then its settle;
  - the admission's re-decision under the handle, which is a race and has no row.
- **Note 5 (the R7 strings).** The RELEASED read of a `minted` wait (`consumed_at null`, `REVOKED`) is brought to the
  code above.
- **Note 8.** The falsifier's "(DRAFT, not built)" banner is corrected. This record's citations of the evaluator and
  of seat.py, which predated the build, now name functions and blocks.

### What Amendment 2's validator round 1 showed, and what became of it

- **R1, accepted.** W-25 compared refusal texts only, so a build that read the gate and the record before refusing
  passed it. W-25 now also carries gate states and record lines a refusal made after reading this triple's gate or
  its record lines would answer otherwise: `gates` NOT ESTABLISHED, a revoked gate, part of a consume block, and a
  released, a voided and an admitted line for the same triple in the record. (Round 2 showed they do not catch a
  refusal made after the record's own checks; ruling (z) added those rows, below.)
- **D1, accepted.** The removal had added a second refusal of `settled` on other kinds where the condition is read. No
  head reached it, it had no row, and it held a 38311c10-written amendment-material or reclose triple even after the
  console's settle. It is taken out: this is a removal. D-4 states what then holds, and W-27 gives it rows.
- **D2, accepted.** Folded into R1's rows.
- **N1, stated.** "Under the mission root" holds by path name: a link the seat places at `.mission-runtime\lam` sends
  the record's write through it. The handoff record is the same. The seat can already write the record (the D4
  residual), so this gives it nothing new.
- **N2, stated.** W-26's watcher sees what is made in the member's own folder, where TEMP and TMP point, and its job
  object counts the processes created as its descendants; a process started through WMI, the task scheduler or COM is
  not counted (corrected under ruling (z), D-D). A write to another absolute path, and those routes, are shown absent
  by reading the code: the functions the arm reaches (Get-OperatorWaitDecision, Add-OperatorWaitRecordLines and their
  callees) start no process, call no WMI, scheduler or COM object, compile nothing, and name no path outside the
  mission root but its own folder's tools.
- **N3.** A UTF-32 STATUS.md with a mark is read as the handoff arm reads it; Amendment 1 item 6 now says so.
- **N4.** A disqualified push gate holds the slot (note 9 lists it as having no row).

### Corrections after Amendment 2's validator round 2 (the operator's ruling (z), 2026-11-14)

Ruling (z): round 2's defects D-A, D-B, D-C and D-D and its notes N-a and N-d are corrected as record text and
falsifier rows, with no change to the evaluator and no further validator round. Not taken: closing them by ruling
and shipping sentences known to be wrong.

- **D-A.** A settled head on amendment-material or reclose is refused by the grammar whatever its gate's state or the
  record's lines, not "before any gate or record is read": the record and earlier admitted triples are read first,
  and a D-4 triple may be recorded void in the same evaluation. "The condition" now states the order.
- **D-B.** (i) W-25 gains `settled` on amendment-material and on reclose with an unreadable record and with a loose
  record line spelling the id. Read first on 4e9051e2, each is refused with the grammar's reason; a mutant that moves
  the grammar line after the record's checks reads them RED. (ii) W-4's two no-gate rows are excepted from "RED on
  38311c10", here and in the falsifier's banner.
- **D-C.** W-28: a revoked gate is not void, for push and for a D-4 triple; a mutant that counts revoked as void reads
  it RED.
- **D-D.** W-26's job object counts descendants; WMI, the task scheduler and COM are ruled out by reading (N2).
- **N-a.** D-4's list gains its two omitted cases (NOT ESTABLISHED holds; the push console basis releases).
- **N-d.** The evaluator's header cites the ratification (caa7...) only. It is not changed; the amendment's sha256,
  463c17cafab2e3ee7d5c971c3e224a1220e3386e94b2c0aaea88fdab67467ae9, is recorded in this record's status block and
  under Amendment 2.
- **N-b and N-c** are not taken by the ruling: N-c (the VOID wording for a D-4 triple the operator settled) is
  stated under D-4; N-b (W-26's narrower coverage) is now in W-26's own description.

## Draft acceptance amendment (UNNUMBERED; for the acceptance record, which is not in this tree)

> **Amendment [number to be assigned by the operator] -- the operator-wait stop (ADR-046).**
>
> **C-1.** Detector type `operator_wait_present`. The FIRST line of `.mission-runtime/lam/STATUS.md`, read as the
> handoff arm reads it, `OPERATOR WAIT gate <kind> <id> <minted|settled>` (settled for push only), admits a stop with
> the verdict `AWAITING_OPERATOR` while the canonical gate `.mission/gates/<kind>-<id>.yaml` is positively absent
> (`minted`), or is absent or stands open and unconsumed (`settled`). Once an evaluation reads the condition met, the triple is
> recorded in `.mission-runtime/lam/operator-wait-releases.jsonl` and never admits again. Everything not established,
> and every wait no operator act could release, refuses. C-1's verdict set gains `AWAITING_OPERATOR`.
>
> **C-2.** The enumeration reads: "A seat may stop on exactly **seven** verdicts, ... `AWAITING_OPERATOR` (the goal
> declares `operator_wait_present` and the first line is an OPERATOR WAIT head naming a gate that does not yet stand)
> ..., and the hook blocks on `NOT_MET` alone."
>
> **C-3.** Unamended: a HALT outranks it.
