# LAM-RESIDUALS — the registered residual manifest (the stopping rule, ruling D)

**What this file is.** It is written after the final validation round. Under the stopping rule a package is
COMPLETE when it carries a fresh-identity PASS, **or** a REFUTED whose findings are enumerated here
as registered residuals and accepted by an operator `completion-acceptance` gate that binds **this
file's sha256**. So this file is an evidence artifact: every residual below is a defect the build
knows about and did not cure, classified honestly, with the control or install step that bounds it.
The gate binds these bytes — an edit after acceptance un-accepts every package until re-bound.

**What is and is not here.** From the final round's refutations, only findings of the **bypass** class in
delivered machinery were fixed, each falsified and committed separately: WP-1 F1, WP-2
F-20-1, WP-3 F-1, and a halt under ruling A. Three
non-bypass items rode in those same commits before the ruling arrived — WP-1 F2, WP-2 F-20-2/3 —
and are recorded below as cured-before-ruling rather than pretended residual. Everything else in
the final round's record, the builder's three queued self-review items, and the shape-scan hits are
residuals, not cures.

**Classes.** `bypass` — a route by which a guarded act completes unguarded; `degradation` — a
mechanism answers, but worse than it claims; `documentation` — prose that overclaims or contradicts
the code; `member-vacuity` — a test that cannot go red on the thing it names.

**Reachability vocabulary.** `live` — reachable on the installed configuration today; `next-gen
only` — reachable only once §2's registration swap is performed; `fixture-only` — reachable in the
instrument's fixture but not in any delivered topology; `none known` — no route driven.

---

## Package states

| package | final-round verdict | state under the stopping rule |
|---|---|---|
| WP-1 | PASS | PASS |
| WP-2 | **REFUTED** | **ACCEPTED-WITH-RESIDUALS** on the operator's gate |
| WP-3 | PASS | PASS |
| WP-4 | PASS | PASS |
| WP-5 | PASS | PASS |
| WP-6 | PASS | PASS |

WP-2's refuting finding (F-20-1, the exemption's reachability hole) was bypass class and is **cured**
and falsified with a thirteenth R-26 row. What remains registered against WP-2 is below.
The five PASS packages carry residuals too — a PASS is scoped to its clauses, and every validator
routed findings out of its clauses on purpose — and they are registered here under the package the
finding belongs to, so nothing dies for want of a home.

---

## WP-2 — residuals

### RES-01 [WP-2] a prunable worktree registration flips the tree-variance answer while its `config.worktree` is on disk
- **class:** degradation · **erratum class:** E115 · **found by:** WP-2 F-20-4, driven
- **reachability:** none known — measured **not** exploitable via re-add; a sensitivity, not a hole
- **bound by:** the narrowing re-runs on every dispatch, so a pruned-then-readded worktree is re-judged before anything runs

### RES-02 [WP-2] the refusal's first named remedy is true only of a global include
- **class:** documentation · **erratum class:** E71 · **found by:** WP-2 F-20-2, driven
- **state:** cured-before-ruling (the remedy now names the scope it is true of); registered so the record shows it was not a bypass fix

### RES-03 [WP-2] R-26 could not see a locally-reachable conditional
- **class:** member-vacuity · **erratum class:** E109 · **found by:** WP-2 F-20-3
- **state:** cured-before-ruling (row `localreach+local`, falsified both directions); registered for the same reason as RES-02

### RES-04 [WP-2] the marker rule and the gate rule are next-gen only
- **class:** bypass · **erratum class:** E115 · **found by:** LAM-INSTALL §5 (standing), re-driven by WP-5 in the final round
- **reachability:** **live** — the sealed guard allows a file-tool write to `.mission/gates/*` and to a `*.superseded.yaml` marker; where the permission layer denies `Write/Edit(.mission/**)` (for example in `settings.local.json`), that is what stops it, and a role template can change that
- **bound by:** §2's registration swap (LAM-INSTALL Part 6), which installs `Test-EvidenceGatePath`, the marker rule and the whole push-gating path; until then, Ruling A2 makes a marker inert without an unrevoked supersession gate, and the permission layer holds the gates directory

---

## WP-1 — residuals

### RES-05 [WP-1] the origin-read failure classifier is five HTTP-flavoured strings
- **class:** degradation · **erratum class:** E56 · **found by:** WP-1 V20-WP1-F3, driven (`auth` against a real 401)
- **reachability:** live for an ssh origin — `Permission denied (publickey)` returns flag `''`, so the gate note reads "WAS ASKED and could not answer" for a credential refusal
- **bound by:** the outcome is still **not consumed** (the permissive-but-true direction, per the transport-trade record at evidence-common `:1837`); the misnaming is in the note text, not the decision

### RES-06 [WP-1] the transport allow-list admits `GIT_SSH_COMMAND` / `GIT_PROXY_COMMAND`
- **class:** bypass · **erratum class:** E116 · **found by:** an earlier WP-1 finding; both halves driven
- **reachability:** requires an adversary who can set this process's environment — who can equally set `PATH` and replace `git`; not reachable from configuration on disk
- **bound by:** the gate's single-use binding to (origin url, ref, sha) and the durability of the consumed artifact; the decision stands and is recorded with both halves of its cost on the library's face. Not re-fixed under ruling D: the recorded access bound was re-established real once WP-1 F1 (newline injection) was cured

### RES-07 [WP-1] a write through a link that already exists is not resolved
- **class:** bypass · **erratum class:** E116 · **found by:** builder, while curing a halt under ruling A
- **reachability:** requires a junction created **outside** the session (ruling A denies creation from inside it); an operator-side fact
- **bound by:** ruling A's link-creation denial closes every in-session route driven; LAM-INSTALL §5.5 states this bound on its face

### RES-08 [WP-1] the sealed guard's glob gap
- **class:** bypass · **erratum class:** E115 · **found by:** WP-5 V19-F2; re-driven by the builder
- **reachability:** **live** — the registered PreToolUse hook is the sealed copy, which answers ALLOW on a `.mis*` junction target, a `.mis*` read, and a new file under a `.mis*` directory
- **bound by:** §2's registration swap (ruling A, option 2 as interim); the post-install probe in LAM-INSTALL §5.5; the route recorded never-to-be-used

---

## WP-3 — residuals

### RES-09 [WP-3] C-1 says "Exit 0 iff MET" unqualified while `-AsStopHook` exits 0 on every verdict
- **class:** documentation · **erratum class:** E34 · **found by:** WP-3 F-2
- **reachability:** none — the decision JSON is only honoured on exit 0, and C-2 requires it; a contradiction in wording
- **bound by:** C-2's own text; the hook behaviour is the correct one

### RES-10 [WP-3] the sealed library shares the newline-crossing regex spelling
- **class:** degradation · **erratum class:** E56 · **found by:** builder, while curing WP-3 F-1 across fifteen sites
- **reachability:** live in `tools/framework/hooks/lib/evidence-common.ps1` for whichever `(?m)^key:\s*` sites it carries — **not enumerated**, because the sealed library is not readable by shell from inside the session and was not swept
- **bound by:** the next-gen library is the copy §2 installs; an operator sweep of the sealed copy is listed as a pending item in LAM-SUCCESSOR §2

---

## WP-4 — residuals

### RES-11 [WP-4] F3's cure is half done — the comment at evidence-common `:1361-1366` contradicts the message it annotates
- **class:** documentation · **erratum class:** E97 · **found by:** WP-4 V20-WP4-01
- **reachability:** none — prose only
- **bound by:** the message is the one a user reads; the comment is the one a maintainer reads, and this entry is what tells them which is current

### RES-12 [WP-4] F3 has no failing arm anywhere in the tree
- **class:** member-vacuity · **erratum class:** E109 · **found by:** WP-4 V20-WP4-02
- **reachability:** the expired-pre-a20-gate contradiction can be reintroduced with the suite at 28/28
- **bound by:** nothing mechanical; registered as the one earlier-round cure with no arm

### RES-13 [WP-4] T-15's `why` assertions miss the `absent file` row
- **class:** member-vacuity · **erratum class:** E56 · **found by:** WP-4 V20-WP4-03, driven — swapping that row's sentence leaves the package 28/28
- **reachability:** fixture-only
- **bound by:** the other eight rows carry `why`

### RES-14 [WP-4] T-17's digest arm asserts one shape, not the four its commit message claimed
- **class:** documentation · **erratum class:** E38 · **found by:** WP-4 V20-WP4-04 — all four driven byte-identical, no defect
- **reachability:** none
- **bound by:** the arm that exists is correct; the claim was in a commit message, which this entry corrects

### RES-15 [WP-4] T-16's here-string scan ends early at a nested terminator
- **class:** member-vacuity · **erratum class:** E100 · **found by:** WP-4 V20-WP4-05
- **reachability:** fixture-only — the only nested case (`instrument-WP-6.ps1:1022/1029`) is saved by trailing text on its closer
- **bound by:** the scan's stated scope is narrow and now stated; widening it produces 141 false positives (driven)

---

## WP-5 — residuals

### RES-16 [WP-5] K-1's Ollama predicate is satisfied by a prose comment
- **class:** member-vacuity · **erratum class:** E115 · **found by:** WP-5 F1, driven three ways — flip Ollama to `live: true` and K-1 still passes
- **reachability:** fixture-only; the artifact is correct, so the clause holds
- **bound by:** nothing mechanical; the same `(?ms).*?` family as WP-3 F-1, in a test rather than delivered machinery, which is why it is residual and not cure

### RES-17 [WP-5] the shell-exemption comment justifies itself by a claim the tier below contradicts
- **class:** documentation · **erratum class:** E97 · **found by:** WP-5 F2 — `cat` on a gate IS denied; the cure's comment says judging shell tools "would refuse `cat`" while the tier 130 lines down does exactly that
- **reachability:** none — prose; not a regression from the cure's commit, verified by WP-5 against its diff
- **bound by:** the denial is the correct behaviour; the comment overclaims the alternative

### RES-18 [WP-5] the nested-path cure is a key-name blacklist
- **class:** degradation · **erratum class:** E116 · **found by:** WP-5 F3 — ten other key names allow
- **reachability:** none via any registered tool (Write/Edit/MultiEdit/NotebookEdit carry paths under the four keys); a future tool with a different path key
- **bound by:** `.claude/settings.json` routes PreToolUse for six named tools only; the key set was chosen deliberately to avoid the `content` false positive, and that choice is now stated as a blacklist

### RES-19 [WP-5] "AT ANY DEPTH" is capped at depth 8
- **class:** documentation · **erratum class:** E34 · **found by:** WP-5 F4 (comment at `:3014`, cap at `:3032`)
- **reachability:** none known — no registered tool nests a path nine deep
- **bound by:** the cap is a bound on the walk, and this entry is the comment's correction

### RES-20 [WP-5] "every PowerShell code extension" is three
- **class:** documentation · **erratum class:** E34 · **found by:** WP-5 F6 — `.ps1xml` and `.cdxml` exist
- **reachability:** none — a sweep scope statement
- **bound by:** the three scanned extensions are the ones this repository uses

### RES-21 [WP-5] K-5 is not a contract clause
- **class:** documentation · **erratum class:** E91 · **found by:** WP-5, routed to the orchestrator
- **reachability:** none — a contract gap; two of the final round's judged cures were K-5's
- **bound by:** K-5 runs in the suite regardless; naming it in LAM-ACCEPT is a pending contract item

### RES-22 [WP-5] K-4's failing arm was not re-driven in the final round
- **class:** member-vacuity · **erratum class:** E80 · **found by:** WP-5, disclosed in their result as a scope choice
- **reachability:** fixture-only — materialising a protected-suffix directory under a fixture would sit in the live guard's blind spot
- **bound by:** an earlier round's validator did build one; the arm exists and was driven once

---

## WP-6 — residuals

### RES-23 [WP-6] the S-4d siting arms accept any failure as proof of siting
- **class:** member-vacuity · **erratum class:** E115 · **found by:** WP-6 V20-F1, driven — a "ghost" library with three shipped-before edits passes every S-4d row green while genuinely steered
- **reachability:** fixture-only; relocation alone IS caught
- **bound by:** the library computes `$script:EvidenceOriginReadFailure = 'isolation'` on the shipped path and nothing for the ghost — the discriminating value exists and the arm does not read it

### RES-24 [WP-6] the instrument reader lacks the library's `< 2.32` HOME guard
- **class:** degradation · **erratum class:** E119 · **found by:** WP-6 V20-F2 — inside the git child the instrument reader has a neutral HOME while the library has the real one
- **reachability:** latent false **red** on a host whose credential store is HOME-resident; never false green
- **bound by:** S-4d judges both readers against ground truth read a third way; a false red is loud

### RES-25 [WP-6] the M3 commit message claims both `GIT_CONFIG_PARAMETERS` spellings; the member plants one
- **class:** documentation · **erratum class:** E38 · **found by:** WP-6 V20-F3 — the older spelling does steer a naive read, and the shipped library resists it
- **reachability:** none — the cure resists both; the witness plants one
- **bound by:** the library's behaviour; this entry corrects the message

### RES-26 [WP-6] S-4d's fixture origin cannot distinguish the two readers on transport or credentials
- **class:** member-vacuity · **erratum class:** E119 · **found by:** builder self-review (HOLD §3) — the erratum I wrote and did not apply
- **reachability:** fixture-only — the two readers diverged on transport for two rounds while S-4d stayed green
- **bound by:** the transport-trade driver proves a hermetic distinguishing origin is buildable (`ssh://nowhere.invalid` served by `GIT_SSH_COMMAND`); the member does not yet use it

### RES-27 [WP-6] `(?m)^authorized_by:\s*(\S+)` at instrument-WP-6 `:1316` crosses newlines
- **class:** member-vacuity · **erratum class:** E56 · **found by:** builder, during the fifteen-site sweep — a display field in a test, not delivered machinery
- **reachability:** fixture-only; affects only the enumerated `authorized_by` label on the ZP attestation
- **bound by:** the count ZP asserts does not read that field

---

## Cross-package — the builder's three queued self-review items

### RES-28 [WP-5] five of ten section-1 byte-table filenames appear in BOTH tables
- **class:** documentation · **erratum class:** E120 · **found by:** builder self-review (HOLD §1) — E120 was minted from one instance; the sweep found five ambiguous rows
- **reachability:** a pattern-keyed re-derivation has an even chance of rewriting a SEALED row
- **bound by:** the rule in E120 (address rows by position, verify each figure against its file), which every re-derivation in this closure followed; the measured table belongs in E120 and is placed there by V-2

### RES-29 [WP-4] three non-vacuity guards were added and never falsified
- **class:** member-vacuity · **erratum class:** E78 · **found by:** builder self-review (HOLD §4) — `$t16Reached` (WP-4 `:2664`), `$held` (WP-4 `:2577`), `$s4dBareOk` (WP-6 `:621`)
- **reachability:** fixture-only — each exists to stop a member passing vacuously and none has been shown able to fail
- **bound by:** each guarded member's positive detection WAS falsified; what is unfalsified is the guard, not the member. WP-6's final-round validator independently confirmed `$s4dBareOk` measures (six git operations exit 0 under the impossible TEMP); the other two are as stated

### RES-30 [WP-3] a relayed figure was presented as driven in WP-3's final-round charter
- **class:** documentation · **erratum class:** E38 · **found by:** builder self-review (HOLD §5), disclosed on the charter
- **reachability:** none — WP-3 verified the figure against history themselves and found it accurate
- **bound by:** T-2s applied to charters: any figure not driven in the current round is written as "recorded in <artifact> by round <n>"

---

## Shape-scan hits at this head (ruling C: a lint, not a gate)

`python tools/lam/shape-scan.py` reports **43 hits** at the head this manifest was written against.
They are not defects to fix under ruling D; they are places a reader looks. The ones read during this
closure, with the reading:

### RES-31 [WP-4] shape-scan S1 at `lam-gate-class.ps1:188` — `if ($declared -and ($declared -ne $derived))`
- **class:** documentation · **erratum class:** E92 · **reading:** intentional — read-time classification derives the class when none is written, so a missing `gate_class` is the normal pre-amendment-12 artifact, not a skipped check; and `-ne` folds case on two fixed lowercase literals
- **bound by:** `Get-LamGateClassForKind` refuses an unknown kind regardless

### RES-32 [WP-1] shape-scan S4 — thirteen snake_case keys assigned and read nowhere in the scanned set
- **class:** documentation · **erratum class:** E85 · **reading:** `stdout_sha256`, `stderr_sha256`, `*_truncated`, `session_id`, `dispatch_id`, `written_by`, `log_path`, `decider_path`, `denied_tool`, `conditional_includes`, `procedure_adherence`, `terminated_reason`, `declared_class` are evidence-record fields read by validators and operators, not by the scanned code; E85 governs a field that implies a check which does not happen, and these imply none
- **bound by:** each is named on the artifact it is written to

### RES-33 [WP-1] shape-scan S7 at `evidence-pre-push.ps1:88` — `git rev-parse --show-toplevel` with no `-C`
- **class:** degradation · **erratum class:** E66 · **reading:** a pre-push hook runs with the repository as cwd by git's own contract, so the caller's cwd IS the repository here; the shape is the one that bit three other sites and this one is the exception the rule allows
- **bound by:** git's hook-invocation contract; the decider's repository is the one git is pushing from

The remaining hits (S2 case-folding on non-path variables, S3 `[0]` over a `split` result that is a
single record by construction) were read in earlier rounds and are unchanged.

---

## What this manifest asks of the operator

Mint the gate against these bytes and nothing else:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\lam\mission-gate.ps1 approve -Kind completion-acceptance -Id residuals -Binds docs\framework\LAM-RESIDUALS.md -MissionRoot .
```

Then run the goal check. `validator_pass_count` will name every package as `PASS` or
`ACCEPTED-WITH-RESIDUALS(n residuals, gate <gate file>)`. If this file is
edited afterwards, that line goes back to `0 of 6` until the gate is re-minted — which is the
behaviour that makes the acceptance mean something.
