# LAM-SUCCESSOR — the brief for whoever picks this up

**State at the head this was written:** the completion ruling (rulings A–E) is executed,
the operator minted the completion-acceptance gate against the residual manifest, and the goal check
returned **MET** — `6 of 6`, five packages `=PASS`, WP-2 `ACCEPTED-WITH-RESIDUALS(4 residuals, gate
<file>)`, every instrument exit 0, no open HALT. The four pending
operator items were then ruled (all four leans ratified) and executed; the final contract amendment
closes the contract with its members all named. **Nothing further is the
builder's.** What remains is the operator's post-goal sequence, printed in the closure report and
summarised in §6.

---

## 1. Where the goal actually is

`validator_pass_count` reads `tests/lam/validator-WP-*.result.yaml` and, under the stopping rule, counts a
package COMPLETE on a ledger-bound PASS **or** on a ledger-bound REFUTED that an unrevoked
`completion-acceptance-*.yaml` gate accepts by binding the residual manifest's sha256, provided the
manifest carries a `### RES-nn [WP-x]` heading for that package. The final round banked five PASS and one
REFUTED (WP-2). So the goal reads `5 of 6` until the gate exists and `6 of 6` afterwards,
and the detail names every package as `PASS` or `ACCEPTED-WITH-RESIDUALS(n residuals, gate <file>)`.

**Do not touch the manifest after the gate is minted.** It is bound by hash; an edit un-accepts every
package until the gate is re-minted. That is the property that makes the acceptance mean something.

---

## 2. Rulings that are the operator's, not yours — what is settled and what is still pending

**Settled by the completion ruling:**

| ruling | what | where it landed |
|---|---|---|
| A | The glob-denoted junction: option 2 as interim, closed by §2's swap; next-gen guard cured (glob expansion + protected-target link denial), members T-3c / R-12b falsified both ways; sealed guard disclosed open on LAM-INSTALL §5.5 with a post-install probe | the next-gen guard; LAM-INSTALL §5.5 |
| B | The fence-stripping deviation RATIFIED and folded into C-3; ratified algorithm replaces the toggle; eleven cases, the live artifacts re-read, no verdict moved; four fixture closers that had never closed a fence corrected | the contract's C-3 |
| C | The shape scan is a tracked lint at `tools/lam/shape-scan.py` — six shapes with their origins on its face, S5 declared unscanned, exit always 0 | `tools/lam/shape-scan.py` |
| D | The stopping rule: PASS or accepted-REFUTED; kind `completion-acceptance`, class governance, permanent until revoked; `validator_pass_count` admits it loudly; six vocabulary sites moved; six-cell falsification through the real evaluator and the real gate tool | the stopping-rule amendment |
| E | The residual manifest (33 entries); V-2's convergence exhibit from the ledger with the v2.4 round-budget rule; V-3's ten-step operator sequence on one page | the residual manifest; V-2; V-3 |

**The four that were pending — all four leans ratified, none deferred by silence:**

1. **WP-5's K-4 scope — RULED: the narrow reading.** Code-to-code parity is the clause; followability
   was never contracted and is recorded in v2.4 (delta §6.7) as a candidate clause for a future arc.
   The contract's K-4 now says so in one sentence (the final contract amendment).
2. **The eighth sealed-table row — RULED: ratified, operator-placed.** The amendment AM-LAM-1 is
   drafted with its ledger content
   beside it. No sealed byte moves. **The builder does not place it**; placement is step 2
   of the post-goal sequence.
3. **RES-10 — RULED: operator sweep at the terminal before §2's swap.** LAM-INSTALL §5 step 1b now
   carries the exact commands, the shadowing analysis and the seal-move decision rule. **And the
   premise measured false at closure:** driven read-only at the sealed anchor LAM-INSTALL 1b names, with
   the page's own commands, the sealed library carries **zero** sites of the class in any spelling,
   while the same pattern finds sites in the next-gen library before the WP-3 newline cure and none after. The
   manifest is hash-bound and unedited; the correction lives in delta §6.7 and LAM-INSTALL 1b/10. The
   terminal run remains the step; the decision rule resolves to no seal move unless it disagrees.
4. **K-5 into the contract — RULED: the final contract amendment**, text only, committed alone with the chain verified
   (one file). The contract closes with its members all named.

**Withdrawn and not to be re-escalated:** `uploadpack.hideRefs`. Two client-side
mitigations work for the local-path origin the gate declares; `--upload-pack` is not honoured on
https, so it is not general across transports. A note, not a ruling request.

---

## 3. The commit sequence of the closure, in order, so it can be audited

| step | what | class |
|---|---|---|
| 1 | a WP-1 finding — credential value carrying a newline smuggled a second `-c`; `-z` records, key re-checked, newline-bearing values dropped; another finding's stray backslash | bypass (+ degradation, pre-ruling) |
| 2 | a WP-2 finding — the exemption asked scope, not reachability; `--show-scope`; R-26 thirteenth row; further findings | bypass (+ documentation, member-vacuity, pre-ruling) |
| 3 | a WP-3 finding — fifteen newline-crossing sites, two on the authorization path; my first cure broke three instruments on CRLF and wrote a literal TAB | bypass |
| 4 | ruling A | bypass |
| 5 | ruling B | contract + degradation |
| 6 | ruling C | tooling |
| 7 | ruling D — the stopping rule, alone | contract |
| 8 | ruling E — the residual manifest | record |
| 9 | ruling E — V-2, V-3 | record |
| 10 | ruling E — this brief at closure state | record |
| 11 | closure rulings 1–3 — K-4's scope in v2.4; the AM-LAM-1 draft and its ledger content; LAM-INSTALL step 1b (RES-10 sweep, shadowing analysis, decision rule) and the measured-false correction | record |
| 12 | closure ruling 4 — the final contract amendment: K-5 named, K-4's scope stated; alone, chain verified | contract |
| (this commit) | this brief, final | record |

Every code commit above carries its falsification in its message: the cells, the row ownership, the
restore hash. Where a first draft was wrong, the message says so and says what caught it.

---

## 4. What the record says about this build, in one paragraph

Many rounds, and most banked verdicts refuted. Several rounds refuted a cure a
previous round had written. The score never converged and the reason is in the record: defect
discovery was bounded by reader-rounds, not by defect supply, and roughly one round in two found the
previous remedy rather than a fresh defect. The completion rule had to be written from outside the
contract. **v2.4 must say: a validation contract declares its round budget or convergence criterion
up front, so stopping is a pre-committed touchpoint.** That sentence, with the table behind it, is
§6 item 6 of the delta and is the most useful thing this build produced.

---

## 5. Session law not written anywhere else — the ones that cost something this closure

* **A patch replacement string is processed by the layer that applies it.** `re.sub` with a string
  template turned `\t` into a TAB inside a regex class; a bash heredoc halved backslashes; a
  PowerShell double-quoted fixture turned `` ``````n`n `` into the line ```` ```n ````. Use a lambda,
  use the Write tool, count the backticks. Then audit the bytes.
* **`\s` matches CR.** A cure that replaces `\s*$` with `[ \t]*$` turns every check on a CRLF artifact
  OFF. The live gate artifacts are CRLF. Drive a cure against a live artifact, not only against
  crafted LF text.
* **A fixture inside protected territory measures its own address.** WP-4's sandbox lives under
  `.mission-runtime`; every relative token's cwd-joined form carries a protected parent, so control
  rows deny on the fixture and attack rows deny under regression for the wrong reason. A short TEMP
  root with its own `.mission` subtree is judged by the guard's suffix rule exactly as the live one.
* **A glob resolver must expand the longest existing prefix.** Resolving the whole token offers
  nothing for a NEW leaf under a glob-denoted directory — which is the minting route.
* **A row that reads the same under the rule and its regression asserts nothing.** The
  "closer shorter than opener" row read HALT either way until the ANSWERED marker was moved after the
  short closer.
* **The guard refuses a shell command that names a protected path beside a metacharacter, even in
  a status filter or a note.** Write the note through a file tool, and never name the path in the
  same command as a pipe.

---

## 6. The operator's post-goal sequence

The gate is minted and the goal is MET. What follows is the operator's, in this order, every command
verbatim in the closure report: **(1)** the host's push gate bound to the final tip, the push, and
the `ls-remote` / `gh` confirmation; **(2)** the AM-LAM-1 admission — copy the draft into
`.mission/amendments/`, add the eighth row to LAM-INSTALL §1's sealed table with a terminal-derived
`Get-FileHash`, append the ledger entry with `tools/mission-ledger-append.ps1`; **(3)** LAM-INSTALL
§5's sequence, steps 1 → 1b → 2 → … → 10, with the RES-10 sweep at 1b; **(4)** the residual
dispositions by id. Two facts the sequence rests on: if the host has **no** pre-push decider installed
(`core.hooksPath` empty, `.git/hooks/pre-push` absent — §5.4 is step 4), the push gate is
minted for the record and consumed by your own `ls-remote` confirmation rather than by a hook; and
your `.mission/gates/` directory is untracked — committing the acceptance and push gates into history
is your call, not the builder's.
---

**A carried commit id is checked against the repository before it is cited.** A transposed id is corrected by a ledger correction entry appended at the next ceremony, because history is annotated, never edited.
---

## After the install -- the next session is a MISSION session, not a build session.

**Install sequence:** LAM-INSTALL §5 steps 1 through 10, each executed with evidence. Origin's
`refs/heads/main` is confirmed at the install tip by the operator (`ls-remote`, `gh api` or the browser)
after the newly installed pre-push decider allows the push. The install push gate settles afterwards through PostToolUse
asking the declared origin: `mission-gate.ps1 list` at settlement reads the install push gate CONSUMED (build-authorization, tip bound to the install tip); the closure push gate REVOKED; the completion-acceptance gate open (governance, permanent until revoked).

**When the install is complete** (LAM-INSTALL SS5 steps 1 through 10 executed with evidence), the
next-generation hooks are registered and live in `.claude/settings.json`; the sealed A1 library carries
SS5.1/5.2/5.3 at the anchor LAM-INSTALL §1 records; the SS5.4 decider is at `.git/hooks/pre-push`;
RES-04, RES-08 and the glob gap are closed by the swap; the RES-10 sweep is recorded with its hit count.

**The install amendments are approved and ledgered**: the first (the omnibus admission of the toolchain,
the contract, the v2.4 delta, LAM-RESIDUALS by hash, ADR-036..040, the SS14 update and
AM-LAM-1 folded in) committed, then approved
in a commit of its own; the second (the sealed-hash move and the install) placed approved at the install tip. Ledger
entries record the omnibus admission decision, any carried-id correction
and the install's sealed-hash move decision; the commit
ledger under `.mission-runtime/lam` carries every commit of the install session and the backfilled closure
sequence.

**The standing untracked lines, by kind -- never stage, tidy or delete them:**
the verify evidence stores `.mission/evidence/verify-<id>/`, one per verified dispatch
(permanent
evidence stores), the operator's untracked sample inputs under `.mission/inputs/samples/`,
and the operator's run log (together, the
RESIDUE-KEEP operator files).

**Open by construction, operator-side, two items:** (1) the D9 clean-tree patch decision for the host
(LAM-INSTALL SS9) -- until it is taken, `Assert-CleanWorkingTree` refuses on the verify-* stores
and every ledger append is `-NoCommit` plus an explicit-pathspec commit; (2) RES-07 (a write through a
pre-existing link), D6 (the sealed set is re-verified only at the operator's terminal or by a script
invoked by path) and D4 (origin-side attestation), all as registered in LAM-RESIDUALS and the delta.

**Session law this closure paid for, carried in LAM-INSTALL SS2:** the install
grant is an operator edit by construction (the auto-mode classifier blocks an agent's writes into the
sealed machinery, the settings files and the hooks directory, and blocks the agent granting itself a
rule that would); a permission rule needs forward slashes; a one-letter helper name is an alias
(`H` is Get-History); the live guard refuses compound commands that carry a `git` token it cannot
read, and the readable form is the one to issue; and a double-quoted here-string eats backticks and
turns `r `a `f into control bytes -- a block appended that way is corrupted and must be
replaced from its marker (SS5 above records the class).
