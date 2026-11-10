# vanguard-collective-local-modes — v2.4 DELTA

**What this document is.** The delta from v2.3, written **last and from the record** — the HALT
artifacts, the two provenance ledgers, the commit history, and the six V-1 validator results. It
records what building the Local Autonomous Mode toolchain **falsified** in v2.3, the five ADRs the
build establishes, and the §14 status as it actually stands.

**What it is not.** It is not written from intent, and it is not a summary of what the build meant
to do. Where a claim has no detector, it is marked as a claim. Where the record does not carry
something, this document says so rather than filling the gap.

**Provenance, stated because it is load-bearing.** A document of this name exists under
`.mission-runtime/lam/quarantine/`. It is **not a source for this one** and was not read as one
(by operator ruling): it is an unattributed artifact that appeared at a counted path during a
concurrent-session window, and its content quality is irrelevant to that. Every finding below is
cited to an artifact a reader can open.

**Naming.** This delta continues the local-modes family's ADR namespace and cites its decisions, v2.3's
and its own, as **`LM2-ADR-0NN`** -- v2.3's standing convention (its Erratum E2). A bare `ADR-0NN` denotes
the on-disk file `tools/mission-cli/config/adr-0NN-*.md`, a namespace of its own. The two series overlap:
the five decisions this build establishes are LM2-ADR-036 … LM2-ADR-040, and the on-disk series holds
`adr-040`, `adr-041`, `adr-042` and `adr-044` (no `adr-043`), so the number 040 names two different decisions --
LM2-ADR-040 is this delta's runner; the on-disk `adr-040` is the meta-framework rework route.

---

## 1. The one-line summary

**v2.3 described a system that would work if its mechanisms worked. Roughly a third of the
mechanisms this build touched had never worked at all** — not "worked and then regressed", but
*never once ran the code path their name describes*, while every local signal stayed green. That
is the delta, and everything below is an instance of it.

These are worth tabling together, because they are one defect repeated — and the count kept rising
as outside readers arrived, which is itself the point:

| mechanism | what it claimed | what it did | how it was found |
|---|---|---|---|
| `Test-LamAdvanceAdmission`'s per-mission porcelain parameter | each mission judged against its own porcelain contract | **no caller ever supplied it**; every mission was judged against the first mission's residue shape | a second mission existed for the first time (E21) |
| `Test-LamLedgerBound`'s provenance binding | a result file counts only if its sha256 matches a ledger line | it matched on `result_sha256`; **every ledger line written carried `sha256`** — no line had ever matched | fixing an unrelated detector unmasked it |
| `gate_present`'s consumed-gate check | a gate counts if it exists and is unconsumed | it tested `consumed_at:\s*\S`, and every real gate carries the literal `consumed_at: null` — **a fresh gate read as consumed** | a goal needed it to *pass* for the first time (E34) |
| `runner_anchors.head_sha` | the mission repository's HEAD | it was `git -C <worktree> rev-parse HEAD`, while `porcelain` on the next line was the mission root — **one anchor block, two repositories** | the first dispatch to verify against an anchor whose worktree branch was never merged (E35) |
| R-1's mandated **anchor grammar** | every proceeding dispatch records which of the gate outcomes it took | the whole grammar had **zero hits outside the contract**; a run with verify **never spawned** and a run with verify spawned and passing left **identical** gate records | a validator asked for the tokens and found them only in the document requiring them (round 2) |
| **Stop-time gap reconciliation** | the transcript's call count is compared with the log | the sidecar was **never written for an unowned session**, and the comparison used a counter incremented *inside* the capture path — **a lost call was invisible to both sides** (E45) | two probes, the failing one leaving no entry at all (round 2) |
| `worker.json`'s **two closed exceptions** | the worker may write its evidence session and its handoff | a blanket deny above them shadowed both; **zero obtained, not two**, and the handoff R-3 requires was unwritable (E40) | driving the real CLI with a control write that passed (round 2) |
| The protected-path matcher | every enumerated path is defended against agent writes | it compared **case-sensitively** on a case-INSENSITIVE filesystem, so any of them was writable by changing one letter, and an agent minted its own push authorization (E49) | a validator tried the obvious variation (round 3) |
| The push-gate **consumption** half | a successful push marks its gate consumed | PreToolUse answered for the repository the command NAMED and PostToolUse for the SESSION's, so a `-C` push left the pushed repo's gate open and stamped an unrelated one consumed — an audit record of an act that never happened | driving both halves against two fixture repositories (round 4) |
| The capture-gap **reconciliation**, after its E45 cure | a vanished call can never coexist with an empty sidecar | it was one subtraction over two differently-scoped populations, so a surplus entry cancelled a vanished call **exactly**, and the manifest block beside it read "incomplete" in the same finalize (E53) | two instances, each with a one-record control (round 4) |
| LAM-INSTALL §5.2's worker-plane snippet | the addition an operator installs is EQUIVALENT to the one built | it printed the **superseded wide form**, which an operator would have hand-installed into the sealed guard, reopening a peer-handoff hole a prior round closed (E48 amendment) | instantiating both snippets and evaluating them side by side (round 4) |
| The capture-gap reconciliation, after its SESSION-SCOPING cure | the log side and the second arm are compared over one session's calls | the runner addresses the store with a synthetic `session-<dispatch>` while entries carry the worker's real harness id, so **every log entry was discarded** and a store with nothing missing reported phantom gaps, including per-seq claims that entries present on disk were never written | re-deriving against hash-verified mirrors of three live stores (round 7) |
| The push detector's segment scan | every operator-separated command in the line is examined | it split on `[;&|()]` and **not on a NEWLINE**, so an ordinary three-line `add`/`commit`/`push` block ran forward from the first `git`, saw `add`, and concluded "not a push" — allowed, ungated, and driven to a real publication, while the `;` spelling of the same act denied | driving the shape the Bash tool actually executes (round 7) |

Each was invisible because **nothing had ever asked it to succeed**. A detector that only ever
fails is indistinguishable from one that works until something depends on it passing — and an
anchor field is only ever *read by the next dispatch*, so a wrong one is invisible until something
verifies against it.

**The rows arrived in six batches, each against a tree already corrected and green again.** The
proportion in the opening sentence is therefore a floor, not an estimate: it is what **seven** rounds
of independent reading found, and every round found something the previous one had walked past.

**The last two rows are worse than a floor: they are mechanisms whose CURE created them.** Both were
introduced by fixes this build made in earlier rounds and shipped green — session scoping that was
correct for a transcript and wrong for a per-dispatch log, and a positional subcommand scan that
replaced a regex without inheriting its separators. A build that only counts what readers find will
not see this class at all, because the readers are finding the same mechanism a third time.
**The honest form of the summary is that this build cannot state how many of its mechanisms have
never run** — only how many have been *shown* not to, and by how many readers.

**Round 4's three rows are a different shape from the first seven, and the difference is the
warning.** Each of them is a mechanism that had been FOUND WRONG ONCE ALREADY and fixed — at the
exact site the previous reader named, and nowhere wider. A second reader then walked one step to the
side and found it again: the gate lifecycle's other half, the reconciliation's other direction, the
install page's second printing of an implementation. **A build converges on the defect only if each
cure names the class; otherwise it converges on the readers** (E53, E56, E48 amendment).

---

## 2. Errata — per member, with evidence

Numbering was assigned as findings were made, and it is **not contiguous**. That is recorded rather
than tidied: **E17 and E29 were never assigned**, and renumbering afterwards would break every
existing cross-reference in the HALT artifacts and both ledgers.

### E6 — §4.7 lists D10 open; an amendment closed its motive
What remained after that amendment was **boundary ownership**, not the original D10 problem. Carried into
the build as H-1 (`OWNER` file present ⇒ the manifest finalizes on the runner-written
`DISPATCH-END` marker, not on `Stop`). §4.7's open item should be restated as ownership, not
lifecycle.

### E7 — §9.3 assumes rooted hook scoping; the live guard is suffix-matched and unrooted
The A1 guard canonicalises a path and matches the protected set as a **suffix**, with **no
repository rooting**. Consequences measured during this build: *every* `.claude/settings.json` on
the filesystem is unwritable to the building agent, including in unrelated repositories and outside
any repository. **v2.4 must state the matching model explicitly**, because a reader who assumes
repo-rooted scoping will design an install step that cannot run.

### E8 — the verify spec's sealed table is stale in one row
`tools/evidence-hooks-next/tests/test-a1-negative.ps1` is `f64797fe…` / **75387** bytes against
§10's recorded `a27d008b` / 54272. A sealed table with a stale row is worse than no table: it
converts a genuine mismatch into an expected one.

### E9 — the kickoff carried the deny/allow contradiction behind an early halt
The permission layer denied a path the contract's Scope of writes required. Cured by session-law
amendment (one narrowing, logged with before/after sha256). **The lesson is the ordering**: the
contract and the permission layer must be reconciled *before* the build starts, not on first
collision.

### E10 — verify cured its library-path cwd coupling but not its schema-path one
Confirmed live. `Resolve-RepoRoot` walks up from **cwd first**, and the normative-schema path is
resolved as a single candidate under that root. Worked around in this build by running verify with
cwd set to the mission root and by giving the smoke repo a byte-identical copy of the schema
(`0a6862f1…`, re-derived). **The workaround is not the cure**, and v2.4 should say the cure is
resolving the schema relative to the *program*, not the *caller*.

### E11 — verify's imported A1 library has no `OPEN` state
An owned, unfinished dispatch reads `PARTIAL`. H-1 introduces `OPEN` on the next-gen side; the two
vocabularies now differ, and v2.4 must reconcile them or verify will keep reporting a state the
runner does not use.

### E12 — LM2-ADR-032's "settings-enforced" memory-off has no settings key
**CLI 2.1.241 exposes no settings key and no flag that disables auto memory on its own.** The only
documented control is `--bare`, which also skips hooks — and a worker without hooks has no evidence
plane at all, which is strictly worse than the leak it would prevent. Verified independently by
three parties: the build, the WP-5 validator (`claude --version`, `claude --help`), and the WP-2
validator. **LM2-ADR-032's intent stands; its mechanism is struck**.
What is achievable and checkable, and what the role templates now carry as fields, is: the declared
mechanism, the **separation actually obtained**, and the **disable named as unobtainable on this
CLI**. See §3, LM2-ADR-036.

### E13 — a continuation Stop hook traps every nested session in its project
Measured: **200 s versus 4 s**. A project's Stop hook is inherited by every nested session in that
project, so a hook that blocks until a goal is met will hold a worker open until it times out.
Cured by the `LAM_DISPATCH` marker, which releases workers. **That marker is now load-bearing in a
second place too** — see E31 — and v2.4 should treat it as an interface, not an implementation
detail.

### E14 — subagent isolation covers the conversation, not project-level auto memory
**Registered, not cured.** The isolation probe reported verbatim *"I have no knowledge of the parent
conversation"* and then **volunteered, unprompted**, that it did hold project-level context
including the auto-memory block. The compensating control is that S-2 verdicts bind by **execution
and byte comparison**, not by the validator's account of itself.

### E15 — verify's suite arm is an unimplemented increment boundary
It makes LM2-ADR-022 unsatisfiable for build-class dispatches: `suite.passed/failed/skipped` are
hardcoded `ABSENT`. **Interim cure: PASS-DIB** (LM2-ADR-037 below). The real cure is
verify increment 2 (suite execution), registered as follow-on work outside this build. **LM2-ADR-022's
v2.4 text must name PASS-DIB a transitional verdict class that dissolves when the arm lands.**

### E16 — presence-based evaluation was insufficient
Unattributed artifacts satisfying goal criteria appeared at counted paths during a
concurrent-session window. **The evaluator caught nothing; the builder's porcelain discipline did.**
Cured by the spawn-ledger provenance binding (session-law amendment 3a): a file at a counted path
whose sha256 matches no completed ledger line is reported **FOREIGN** and **fails** the detector,
never passes it. **v2.4 must name single-writer-per-repo a checked precondition — `ListAgents` at
session start and before each commit — not an assumption.**

### E18 — dispatch artifacts are immutable and run-once by design, and nothing enforced it
**Causal note amended by operator ruling.** E18 originally attributed D-1's lost stream
bodies to worktree churn under a reused id. **Worktree churn was the context, not the operative
defect** — the bodies were never consolidated in the first place (see E19); churn is only why
D-1's are now *unrecoverable*. D-1b proved it: one dispatch, one worktree, no reuse, same empty
plane. Interim cure: explicit supersession markers plus an id-reuse refusal. **For v2.4: the
evidence plane should bind bodies at append time** (content-addressed or copy-on-write), so a body
cannot exist only in an ephemeral worktree.

### E19 — a copy that cannot fail is not a copy that succeeded
The plane-crossing consolidation ran for **two** dispatches copying **nothing**.
`Copy-Item -LiteralPath (Join-Path $srcStreams '*')` asks for a file literally named `*`:
`-LiteralPath` suppresses wildcard expansion **by design**, so it matched nothing — and the block's
`'Continue'` error preference, itself a correct PS 5.1 native-stderr precaution, guaranteed the miss
was **silent**. Every local signal stayed green: the manifest declared the bodies, `log_sha256`
matched, `capture_gaps_count` was 0. **Only the cross-plane parity arm could see it, and it did,
twice.** For v2.4: a plane-crossing copy must **assert its own arity at the point of copy**;
`-LiteralPath` with a glob deserves a lint; and E18's claim-check proposal would have made this
class *impossible* rather than merely detectable.

### E20 — hermetic instruments certify component behaviour, not integration properties
WP-2 ran green **twice** (8/8, then 9/9) while consolidation copied **zero bytes in production**,
because the sandbox worker is a stub that never grows a worktree evidence store — so the defective
line never executed under test. **The instrument was not weak; it was hermetic, and hermeticism is
exactly what excluded the integration seam.** Cure: the **planted-evidence pattern** (WP-2 R-7) —
manufacture the upstream artefact the real hook would write, then assert it survives the boundary.
**v2.4 should name as law: every cross-boundary copy gets an arity-checked instrument member.**
Corollary for reviewers: a green instrument over a component says nothing about the seam it is
wired into.

### E21 — shared admission code defaulted one mission's porcelain contract for all missions
`Test-LamAdvanceAdmission` accepted `$AdmittedPorcelainPatterns`; **no caller ever supplied it**; so
every mission was judged against the first mission's residue shape, and the smoke mission could not pass a
gate it was never measured against. Cure: mission-declared data (`admitted_porcelain`) with
**mandatory verbatim recording at point of use** — patterns, tolerated entries, source path and
sha256, all into the anchors. The cure deliberately does **not** add a parameter for callers to
pass: the admission reads the declaration from the mission root it already has, so it is **live by
construction**. **v2.4 rule: every per-mission judgement parameter must be declared mission-side or
the gate refuses — never silently inherit another mission's shape.**

### E22 — an authorization artifact needs a consumption witness where the authorized act happens
The push gate's lifecycle assumed the push would occur where the hook could see it; the procedure
required a human act **outside** the session. Cure: bind consumption to the **irreversible effect**
(origin's tip) rather than to a local flag — the effect is witnessed by the party that cannot be
persuaded. This moves the assertion **up** the ladder (SESSION-REPORTED < HOOK-CAPTURED <
ORIGIN-SIDE ATTESTED) rather than relaxing it. `consumed_at: null` is then recorded **together with
its reason**, never asserted away.

### E23 — the smoke mission was authored to the design's schema and closed by the product's
WP-6 assumed one mission CLI spanned both `expanded-schemas.md`'s Living Spec shape and the first
mission's own product shape. **Nothing checked that assumption until the last member of the last work
package.** v2.4 should say which schema `.mission/` is normative in, and any tool consuming a
mission should **fail loudly on an unrecognised schema** rather than on the fifth field it happens
to read. *(This one is a WP-6 authoring defect, not a toolchain defect, and is recorded as such.)*

### E24 — a path-pattern gate must be written against what `git status --porcelain` EMITS
**git collapses a wholly-untracked directory to its shallowest path**, so a pattern anchored deeper
silently matches nothing — which in a *gate* means it refuses everything, and in an *exemption list*
means the exemption never fires. Found **twice, independently**: `admitted_porcelain` (E21) and the
D9 patch itself. **v2.4 rule: every porcelain-matching pattern carries the porcelain line
it was validated against, and a pattern matching nothing at authoring time is a build error, not a
silent no-op.** Proven both ways since: the exemption *fires* once the plane has tracked content,
and the broadened prefix covers the fresh-install case where it has none. **The cure order mattered
and is part of the finding:** state first, then pattern as hardening — done the other way round, the
broadened pattern would have made the ceremony pass while the plane was still wholly untracked, and
nobody would ever have learned the original pattern was inert. *Pathspec corollary:* one unmatched
pathspec aborts the **entire** `git add`, so bundling speculative pathspecs with real ones is
all-or-nothing.

### E25 — two sibling gates disagreed about the same directory for the life of the build
`Assert-CleanGitTree` exempts `?? .claude/` wholesale "per the bootstrap doc";
`Assert-CleanWorkingTree` exempts it nowhere. Both guard the same class of transition. The S-5
ceremony surfaced it, because it is the first thing to run **both** gates over one tree. Cured by
naming the path through **`-AllowPaths`** rather than widening a pattern — the right mechanism,
because the worktrees location is fixed and knowable in advance, whereas a session id is not, which
is exactly why D9 needed a pattern. **v2.4: gates that guard the same transition class should share
one exemption source, or state in writing why they differ.**

### E26 — a contract clause that no instrument tests will drift until an outsider reads it
K-3 named four properties; its member tested two of them, and tested one of those with a substring
match. The clause and the implementation diverged in **three** places and every run stayed green.
**The V-1 fresh-identity validator caught in one pass what the whole instrument suite had missed all
build.** **Corollary for v2.4: an acceptance clause should name the check that would fail if it were
false, and a member that cannot fail for a listed property should not report on that property at
all.**

### E27 — **VERBATIM, per operator ruling**

> **E27 — six instruments exiting 0 is not six work packages being correct.** Round 1 of V-1 refuted
> five of six against a tree whose full suite was green, and three of the five refutations landed on
> members that had been *strengthened or authored in the same session that shipped them*. The
> instrument author and the instrument share a blind spot by construction; only an outside reader
> with the contract and no build history breaks it. **v2.4 should state that a work package is not
> complete when its instrument passes, but when an independent reader who was given only the
> contract agrees — and that the instrument's job is regression, not acceptance.**

### E28 — "ran with hooks live" is a claim about WHERE something ran, and nothing checked it
The S-5 ceremony ran under the orchestrator's own hooks because it was a **child process**; the
next-gen hooks are registered for sessions in another repo and could not have observed it. The
member could not tell, because it asked whether *some* manifests were finalized rather than whether
*this operation* produced one. **A claim about an operation's execution context must be evidenced by
an artifact that operation itself produced.** Now implemented: the S-5 member identifies the
ceremony's session **by content** — an evidence session in the mission's own plane whose captured
calls name both the ceremony wrapper and the ceremony id — never by counting sessions.

### E30 — the thing ratified and the thing ratifying must not both be agent-writable
*Provenance note: this number was assigned before any text was drafted for it. The text here is
written from the ruling that produced it, and is marked so that a reader knows the number was
assigned before the words.*

The first draft of supersession ratification made **STATUS.md** the provenance source. STATUS.md is
a gitignored prose file **the building agent writes**, so ratifying markers against it would have
reintroduced the hole one layer up: the marker and the registry vouching for it would both have been
agent-writable. The ratified design binds a marker to an unrevoked **gate artifact** under
`.mission/gates/`, which **T-3 hard-denies every agent role from writing**, and binds it by the
marker's **re-derived sha256** rather than by filename — so editing a marker changes its hash and
the runner stops honouring it. **No gate, no skip: an unratified marker refuses the dispatch (exit
2) rather than being quietly ignored. v2.4 rule: for any ratification mechanism, name the party that
can write the ratifying artifact, and refuse the design if that party is the one being ratified.**

### E31 — **each attestation record names its compensating control** (ruled; in the contract)
The zero-paste attestation rests on two registers, and they are not equally strong. Register (a),
**gate artifacts**, has a real compensating control: **T-3 makes a gate agent-unmintable**, so each
gate genuinely is one human act. Register (b), the **prompt log**, has only a convention —
`record-operator-prompt.ps1` classifies a prompt as machine-submitted **iff** `$env:LAM_DISPATCH`
is set, which only the runner sets — so **anything reaching a session without going through the
runner reads as a human paste**: an operator, a future tool, or the builder's own diagnostic.

**THE RULE, as ruled and as now carried in LAM-ACCEPT: each attestation record NAMES ITS
COMPENSATING CONTROL, and a multi-record attestation is only as strong as its weakest record's.**
An attestation that reports one number over two registers of unequal strength is reporting the
stronger one's confidence about the weaker one's evidence.

*Live instances, both of which forced the rule rather than illustrating it:* one halt (satisfying
S-5 the obvious way would have manufactured an operator act, because a hand-prompted session
bypasses the marker) and another (a builder diagnostic did exactly that).

### E32 — a recorded figure whose name does not match its value
`prompt_bytes` in the operator-prompt register does not measure the prompt. **Measured by
reproduction:** a 24-byte prompt records as `prompt_bytes=35`; the CLI's hook payload carries more
than what was typed. The field sits in an attestation register, where a reader will take it for the
length of what a human typed. **v2.4: any figure written into an evidence or attestation record must
be defined by the derivation that produces it, not by the name of the thing it is about.**

### E33 — a diagnostic run inside a live evidence plane is a mutation of it
The plane cannot tell a probe from a participant; it records what happened, which is its whole
value. A read-only *intention* is irrelevant once the working directory is inside the instrumented
tree. **v2.4 should state that the working directory is part of a command's blast radius, and that
probes against a live mission are run from outside it or not at all.** Live instance: one halt, where
a two-word probe put an operator act into the register the mission is graded on.

### E34 — a predicate two consumers share must live in one place, and this build proved it three times
1. **The `halt_absent` regex existed twice.** Fixing the detector left the verdict path on the old
   form, and the two disagreed **inside a single run**: the detector said 2 open, the summary line
   beneath it said 3.
2. **The consumed-gate predicate existed twice.** `mission-gate.ps1`'s copy carried a load-bearing
   `(?!null)` **with a comment explaining exactly why**; `mission-goal-check.ps1`'s copy did not.
   Every gate the tool writes ends `consumed_at: null`, and `null` is itself `\S`, so the second
   copy reported a **fresh** gate as consumed and **could never pass on a real artifact**.
3. **It hid behind a fixture.** A hand-rolled test gate that simply *omits* `consumed_at` takes the
   other branch and passes — which is why an independent validator driving all nine detector types
   individually did not catch it. **A fixture that omits a field the real writer always emits will
   exercise the wrong branch.**

**v2.4 rule: a predicate consumed in more than one place is a shared definition or it is a defect
waiting for the two copies to diverge; and a fixture must be produced by the real writer, or the
member is testing the fixture.**

### E35 — an anchor is a claim about ONE repository, and a field taken from another is false
`runner_anchors.head_sha` was sourced from `git -C <worktree> rev-parse HEAD`; `runner_anchors.
porcelain`, on the **adjacent line of the same block**, was sourced from the mission root. Verify
re-derives both at the mission root, so `head_sha` was compared against a value it was never taken
from, and the advance admission's ancestry test asked whether the mission's HEAD descends from a
commit that exists only on a worktree branch.

**It needs two conditions at once, which is why four dispatches did not expose it:** a worker that
**commits** in its worktree, **and** a branch **nobody merges**. D-1's worker committed and was
fast-forwarded into main — ancestor by luck. D-1b and D-1c committed nothing, so the worktree tip
*was* the mission HEAD and the two fields were identical by coincidence. D-2 was the first to do
both. **And an anchor field is only ever read by the NEXT dispatch**, so even then it stayed
invisible until something verified against it.

**v2.4: every field in an anchor block declares the root it was derived from, and a consumer that
re-derives at a different root refuses rather than compares.** A valid sha from the wrong repository
is not a weaker claim than a missing one — it is a false one that passes every syntactic check.

### E36 — integration is a step, and nothing owned it
The runner creates the worktree, the worker commits into it, the runner anchors it — and **nothing
merges it back**. For D-1 the orchestrator did it by hand and ledgered it. For D-2 nobody did, so
the mission's main branch never received the build its own contract assertions were validated
against, and **no gate noticed for the rest of the build**. *(A-4's `verification` field is
explicitly worktree-scoped, so the validators judged exactly what they were asked to and passed
honestly — which is what made the gap survivable and invisible at once.)*

**v2.4: a dispatch's definition of done must state where its work ends up. A dispatch whose branch
is never integrated is either an explicit design choice recorded as one, or an unfinished
dispatch — and the record must say which.** *Landed in the acceptance contract, which also names
the two checks that already enforce it: an unledgered commit in an admission range is FOREIGN, and
`head_sha` is pinned to the mission root (R-13). No new instrument member was needed.*

### E37 — the handoff path is outside the worker's own world, and every worker pays for it
`LAM_HANDOFF` names a path in the **shared checkout**, while a worker is worktree-isolated. So a
worker cannot write its handoff by redirect: the guard refuses any command combining a shell
metacharacter with a reference to protected territory, and the harness's worktree isolation refuses
a `git -C` pointed back at the shared checkout. **Three dispatches in a row composed the handoff in
a scratchpad and copied it**, each disclosing the workaround in `issues_observed` — which is the
system working, but paying the same toll three times.

**v2.4: the one artifact a worker must produce should be reachable from the world the worker is
confined to.** Either `LAM_HANDOFF` is worktree-relative and the runner collects it at the boundary
(it already crosses that boundary to consolidate evidence), or a sanctioned writer exists for it.
A required output that the required sandbox forbids writing is a contradiction the worker resolves
by improvising, and improvisation is what the dispatch contract exists to remove.

> **AMENDED — THIS ERRATUM NAMED ONE CAUSE AND THERE WERE TWO.** The account above attributed the
> three scratchpad workarounds to the evidence guard and worktree isolation. An independent
> validator (V-1 round 2, WP-5) found a **second, independent cause** by driving the real CLI:
> `worker.json` denied `Edit(.mission/**)` outright, so the handoff was **also** refused at the
> permission layer — see **E40**. Each cause alone was sufficient; fixing either would have left the
> workaround in place, and the workaround's own disclosure notes named only the first.
> **The general form is worth more than the fix: a workaround disclosed three times was still
> attributed to one cause, because the first plausible cause was found and the search stopped.**
> A toll paid repeatedly is evidence of a mechanism, and a mechanism deserves an exhaustive cause
> list rather than the first one that explains the symptom.

### E38 — a continuation gate cannot tell "stopped early" from "blocked on work it must not preempt"
The Stop hook does exactly what C-2 asks: when the goal is NOT_MET it blocks and names the failing
detector, so the session continues on evidence rather than on a transcript evaluator's opinion. But
it has **no notion of work in flight**. With six fresh-identity validators running — spawned,
ledgered, and by construction not yet finished — the goal is honestly unmet, the hook blocks
repeatedly, and its reason ends *"Continue working"* at the one moment when **there is no honest
work to do**: the only acts that would move `validator_pass_count` are writing `complete` ledger
lines for work that has not returned, or hashing files that are still being written. Both are
fabrication, and the second is fabrication that would *look* like diligence.

**This is a pressure, not merely an inconvenience, and that is why it belongs in the record.** The
gate exists to stop a session ending while the goal is unmet; applied to a session that is
*correctly waiting*, it pushes toward manufacturing activity — which is the failure mode the whole
apparatus exists to prevent. A gate that can only say "not yet" will eventually be satisfied by
someone who mistakes motion for progress.

**The cure is already on disk and unused: the spawn ledger knows.** A spawn line with no matching
`complete` line is an open spawn, and that is a mechanical fact requiring no new bookkeeping.
**v2.4: the goal evaluator should distinguish NOT_MET-and-actionable from NOT_MET-and-blocked**,
reporting open spawns as such — *"blocked on 6 in-flight spawns (seq 14–19)"* — and a continuation
gate should not press a session that is waiting on evidence it is not allowed to invent. Stated as
a rule: **a gate that demands progress must be able to recognise the state in which progress would
be dishonest.**

*Related, from the same handoff and worth carrying:* the D-3 worker's prescribed read-back
(`git -C <mission root> log -1`) was refused for the same reason, and the worker substituted
`git rev-parse main` **from inside its own worktree** — sound, because linked worktrees share the
ref store — and **said so, naming both the deviation and why the substitute answers the same
question**. That is the disclosure standard this build asks for, met by a worker that was given no
instruction to disclose anything.

### E39 — "needs a ruling" must be an ARTIFACT, not a paragraph
Two findings whose resolution was an operator decision sat in a status document's prose across many
turns. The goal evaluator therefore reported **`NOT_MET`** — a verdict that says *the agent has work
left*. The agent did not. The evaluator has a **`HALT`** verdict for exactly that state, and it was
never reached, because nothing had written the file that triggers it.

**The mechanism designed to stop the loop was bypassed by the habit of explaining.** Prose scales
to any amount of nuance, which is precisely why it is the wrong carrier: a paragraph can hold "this
needs a ruling" indefinitely without anything changing state.

**v2.4: a finding whose resolution is an operator decision is recorded as a HALT artifact AT THE
MOMENT IT IS IDENTIFIED**, not summarised in a status document and raised later. The artifact is
cheap, it is what the evaluator reads, and it converts a description into a state.

### E40 — a deny-before-allow permission grammar cannot express "a subtree except named members"
K-3 required *no `.mission/**` writes except exactly two closed members*. The template wrote that
literally: the blanket deny in `deny`, both exceptions in `allow`. **Claude Code evaluates deny,
then ask, then allow; the first match wins; specificity does not change the order; and a deny rule
cannot carry allowlist exceptions.** The broad deny shadowed both exceptions and **the number that
obtained was zero, not two** — including the worker's own handoff, which R-3 requires and which the
runner passes this template for **every** dispatched worker. The role obliged to produce the one
artifact that completes a dispatch could not write it.

**The file read as protection and delivered its opposite**, and the reasoning that would have caught
it was already written *in the same directory*: `validator.json`'s residual says a blanket deny
"would ALSO block this role's result file, and the template would read as protection while
forbidding the one write the role exists to make." **The insight was present and applied to one of
two files.**

**v2.4, two rules.** (1) **State restrictions in a layer that can express them.** Where the grammar
cannot carry an exception set, the restriction belongs somewhere that can — here, the guard, which
tokenises paths and can name members — and the permission file must say **on its own face** where
its protection actually lives, so a reader does not budget for absent protection. (2) **A rule that
reads as a restriction and enforces nothing is worse than an absent rule**, because an absent rule
is visibly absent. This build had already applied that principle to inert `Write(...)`/`MultiEdit(...)`
spellings; the shadowed-allow case is the same defect with better camouflage.

### E41 — a member that reads RULES cannot see a rule that has no EFFECT
The instrument covering K-3 asserted "exactly two allow entries touching `.mission`", in both
directions, from parsed JSON — a genuine improvement over the substring matching it replaced, and
it reported **PASS** on the file described in E40 for the entire build. It was measuring the right
text. **It never asked whether an entry did anything**, because evaluating an allow requires
evaluating it *against the deny list*, which is a different question from reading it.

The cure is to instantiate a concrete path **from** the allow pattern and test it **against** each
deny pattern; a shadowed allow then names itself. But the general lesson is the one to carry:

**v2.4: configuration is asserted by CAPABILITY, not by CONTENT.** "The rule is present and correctly
spelled" and "the rule has the effect it names" are different propositions, and only the second is
what a contract clause about permissions means. Where driving the real evaluator is possible, drive
it; where it is not, evaluate the rules against each other rather than counting them. **Every
verification-by-reading in this build that was ever falsified failed in exactly this direction.**

### E42 — a contract that states TWO mechanisms for one thing has stated none
R-1 required supersession markers to be ratified against a **registry in a status document**;
WP-6 and a later ruling required ratification against a **gate artifact**, and gave the reason —
the status document is a gitignored prose file *the agent writes*, so ratifying against it puts the
thing ratified and the thing ratifying in one pair of hands. The implementation followed the gate.
**R-1's text was never updated**, so the contract carried both.

**An independent validator refused to judge which governed, and was right to.** It measured both
directions — a marker with the registry row and no gate was **refused**; a marker with a gate and no
registry entry at all was **honoured** — and reported the contradiction rather than picking the
reading that matched the code. Picking would have been marking the implementation's homework on the
one question where the contract is the authority.

**v2.4: an amendment that replaces a mechanism must strike the mechanism it replaces, in the clause
that carries it.** Adding the new rule elsewhere and leaving the old text standing is not a partial
improvement — it converts a specification into a pair of claims, and every later reader must guess.
**Corollary, learned the same way: the reader who reports "the contract contradicts itself" is
delivering the finding, not failing to reach a verdict.**

### E43 — an anchored path regex over a WHOLE COMMAND cannot match after a space
Three predicates in this build guarded protected paths with a `(^|/)`-anchored regex applied to the
entire command string. A path preceded by a **space** has neither start-of-string nor a `/` before
it, so:

| shape | verdict |
|---|---|
| `Write` tool, absolute **or** relative | DENY |
| `cp seed.yaml <abs>/.mission/gates/x.yaml` | DENY |
| **`cp seed.yaml .mission/gates/x.yaml`** | **ALLOW** |
| **`cp seed.yaml ./.mission/gates/x.yaml`** | **ALLOW** |

A validator drove the whole chain from there: write a gate face, copy it in, the gate tool reads it
back as a valid open build-authorization gate, and `git push` answers **"push authorized"**. **An
agent minted its own authorization and published on it** — the exact act the rule exists to forbid,
and the compensating control that two other clauses cite by name.

**The anchor is correct WITHIN A TOKEN and wrong ACROSS A COMMAND.** The library's original
protected-path matcher never had this bug, because it **tokenises first** and resolves dot segments
before testing. Every predicate that had the bug had bypassed that machinery and reinvented the
matching. **The cure was to stop reinventing it**, which is E34 arriving for the fourth time.

**And the fixture lesson is inseparable from it:** the member covering one of these predicates
**passed**, because its fixture used an **absolute** path — the one shape that happened to work.
Testing a single shape of a multi-shape input and generalising is how a predicate ships holed with
a green tick over it. **v2.4: a path predicate is exercised over the shape MATRIX — absolute,
relative, `./`-prefixed, mid-command, and by both the file-tool and shell reaches — or it is
untested.**

### E44 — an unbuilt outcome named in a contract is a promise, and there are only two honest endings
R-1 named **three** gate outcomes and nothing ever produced the third. Building it meant building an
admission that lets a dispatch proceed **without verify passing**, so it was refused — correctly —
and the refusal was disclosed rather than hidden. But the name stayed in the contract, and a name in
a contract is a commitment a later reader will either implement or work around.

**The resolution is binary: build it, or strike it.** It was struck, the refusal ratified, and the
replacement rule stated positively — *no code path may let a dispatch proceed without verify passing
or a NAMED admission, and the named admissions are a closed set*. The runner now **refuses** an
outcome it cannot name rather than annotating itself, and refuses **before** spawning.

**The substantive point, which outlives this clause:** an operator who wants a dispatch through
despite verify is **making a contract amendment, not exercising an admission**. That mechanism
already existed — numbered, hash-chained, committed alone, leaving an artifact that names who
decided what. A per-run admission flag reaches the same effect by a route with none of those
properties, and **when two routes reach the same effect, the weaker one is the one that gets used.**
**v2.4: do not build a second, cheaper path to a decision that already has an accountable one.**

### E45 — reconciliation that compares a COUNTER to a LOG is blind to what reached neither
Stop-time reconciliation was specified to compare the transcript's tool-call count against the log
and write a capture-gaps sidecar. Two defects, and the second is the instructive one.

First, **the sidecar was never written for an unowned session** — the only caller refused without a
dispatch-end marker, so a session whose lifecycle the design deliberately preserves finalized with
**no gap accounting at all**. Second, and worse: the comparison used the **seq counter**, and the
counter increments **inside** the post-call hook. **A call that never reaches that hook is invisible
to both sides of the comparison**, so the reconciliation certifies a clean capture over a lost call.
Demonstrated live with two probes, the failing one leaving no entry whatsoever.

**A reconciliation is only as good as the independence of its two sides.** Comparing a counter to a
log that the same code path writes is comparing a thing to itself. **v2.4: the count a gap detector
compares against must come from OUTSIDE the capture path** — the transcript, which is written by the
harness — and a detector whose two inputs share a failure mode must say so on its own face.

### E46 — a register the counter never opened, under an output claiming it opened everything
The zero-paste attestation read **one** prompt register. The mission had **six**: the hook writes to
the project directory, and dispatched workers run under `--worktree`, so five worktree-rooted shards
held **eleven further hook-recorded lines** the attestation never opened — while its output asserted
*"EVERY line … nothing is hidden"*.

**The count was still true** — all eleven were machine-submitted — and that is why this is an
erratum rather than a cured falsehood. **A human prompting a worktree-rooted session would have been
recorded in a shard the counter does not read**, so the marker named as this record's compensating
control was guarding a register the counter never opened.

**v2.4: an attestation that enumerates must enumerate over the SET, and the set must be derived
rather than assumed.** Where a record is sharded by a mechanism the build itself introduced
(here, worktree isolation), the enumerator must discover the shards. **A count that happens to be
right is not the same as a count that could not have been wrong** — and an output that says
"everything" while reading one of six is the overclaim this build's own laws forbid, committed by
the attestation whose purpose is to prevent overclaiming.

### E38 AMENDMENT — the second occurrence, measured rather than argued
E38 was written from **one** occurrence and reasoned forward about the pressure it creates. It
happened a **second** time under round 3, and the recurrence removes the last doubt about the
mechanism: this is what the gate does **every time** validation is in flight, not an artefact of one
unlucky moment.

With six validators spawned, ledgered, and none yet returned, the gate fired repeatedly with the
same reason and the same closing instruction, *"Continue working."* A read-only check confirmed why:
all six result files were still the **previous round's**, every sha256 matching the archived copies
byte for byte. **The gate was accurately describing a state nothing honest could change.**

And the second occurrence surfaces a consequence the first did not. The three acts that would have
satisfied the detector were: writing `complete` lines for work that had not returned; hashing files
while they were being written; **or editing tracked files** — and the third is not merely dishonest,
it is **destructive**, because the round in flight is judging that tree. **A gate pressing for
activity during validation presses toward the one act that invalidates the validation.**

The cure is unchanged and still costs nothing: a spawn line with no matching `complete` line is an
open spawn, and the evaluator already reads that ledger for provenance binding.

### E45 AMENDMENT — the cure, and the rule it generalises to
E45 named the defect: both arms of the Stop-time reconciliation shared a failure mode, so a call
that never reached PostToolUse was invisible to each and the sidecar certified a clean capture over
a lost one. **The cure is in: the transcript arm counts ALL tool calls regardless of
outcome**, denied calls are accounted separately so a denial is not a false gap, and the shortfall
is written as `post-hook-not-fired`. **A vanished call can no longer coexist with an empty sidecar.**

Two things are worth carrying past the fix.

**The contract clause had to move, not just the code.** "A failed call writes `outcome: failed`" was
**unobtainable** — PostToolUse never fires on a failed call — and it had been *passing* for the
life of the build because the instrument called the hook **by hand** with a synthesized
`exit_code`. The member manufactured the evidence it then found. **A check that constructs its own
input is not measuring the system; it is measuring the check.** Where a clause cannot be satisfied
by the platform, the honest repair is to amend the clause to what the platform can witness, and to
DELETE the check rather than leave it as decoration.

**And the general rule about reconciliation:** *the two sides of a comparison must fail
independently, or it is one measurement taken twice.* Ask of any such check: what event would both
arms miss? Here the answer was "every failed call", and nothing in the design said so because both
arms were written by the same hand from the same mental model. **v2.4: a reconciliation must name,
on its own face, the population each arm can and cannot see** — the sidecar now emits
`transcript_calls`, `logged_calls` and `denied_calls` precisely so a reader can re-derive the
arithmetic instead of trusting the verdict.

### E52 — a contract sentence can be FALSE the day it is committed
A contract amendment stated that a gate is **"agent-unmintable by T-3"**, and it was not: the guard's
protected-path matcher was **case-sensitive** on a case-insensitive filesystem, so `.MISSION/GATES/`
was allowed by every route and an agent could mint its own push authorization — driven end to end
by an independent reader one round later (E49).

**The sentence was not careless.** T-3 exists, is exercised, has a member, and denies the lowercase
form. What the author checked was that the *rule* existed; what was false was the *property* the
rule was cited for. **Four separate clauses — T-3, R-1 and two contract amendments — leaned on
that one property by name**, so a single unchecked assumption propagated into four places that each
read as independent corroboration.

**Cured** in the next-gen guard (one option on one call, in the single predicate the whole tier
funnels through) and covered by a member. **It remains FALSE of the sealed guard**, which no
agent may write: the install step is now REQUIRED and carries a probe, because a re-sealed hash
proves which bytes are installed and not what they do.

**v2.4, and this is the expensive one:** **a compensating control must be DRIVEN at the moment it is
cited, not inherited from the clause that first named it.** Citation is not verification, and the
more clauses lean on a control the more it looks verified — each citation reads as evidence that
someone else checked. **Count citations of a control as a risk signal rather than a comfort:** the
most-cited control in this build was the one nobody had exercised across the shape that mattered.

### E47 — moving a restriction to another layer requires knowing what that layer ALREADY denies
A ruling moved a role restriction from the permission file, which could not express it, to the
guard, which could. The permission file's exception set had two members. **One of them was already
denied, unconditionally and for every role, by the sealed layer the guard delegates to** — so "move
the restriction and the exceptions become live" was true of one member and false of the other, and
nobody knew which until it was driven.

It was driven **before** the amendment was authored, which is the only reason the contract says
something true. Had the text been written first and the implementation fitted to it, the contract
would have promised a capability the stack denies.

**A layered permission system does not compose by inspection.** Each layer's answer is a function of
every layer beneath it. **v2.4: when a restriction moves layers, drive the FULL composition — every
member of the exception set, through every reach — BEFORE the text is written.** And where a lower
layer is stricter than the clause promises, say which layer makes the promise and which overrides
it: **a promise the stack does not keep is a defect; a promise the stack over-keeps is a
disclosure.**

### E48 — an install document that PRINTS an implementation ships a second copy of it
The operator-facing install procedure told a human to mirror a predicate into a sealed library no
agent may write, and **printed the code to mirror**. The printed snippet was the **pre-cure**
version, whose hole let an agent mint a gate with a plain `cp` and publish on it (E43). The
implementation had been fixed; **its copy in the install document had not**, and nothing could have
noticed — a document is not executed, so no member covers it and no suite goes red.

**This is E34 in the one place it is most expensive.** When the second copy is an install procedure,
the drift is not merely stale — it is **a defect being actively distributed to the one party who
cannot test it**, who is following the document precisely because they cannot derive the answer.

**v2.4:** an install document must either **reference** the implementation by path and hash rather
than reproducing it, or carry **a check that fails when its excerpt diverges** from the source it
quotes. Prose about code is cheap to keep honest; **code inside prose is a fork with no merge and no
test.**

### E49 — a guard whose matcher disagrees with its filesystem is not a guard
The protected-path tier matched **case-sensitively** while every sibling predicate in the same
library matched case-insensitively, and the host filesystem is **case-insensitive**. So an
upper-cased spelling named the same real file and was allowed: the evidence plane, the runtime
plane, **the sealed guard library itself**, the settings file, and the gates directory. An
independent validator drove the last one end to end — an agent minted its own push authorization and
the push guard answered *"push authorized"* — which voids the agent-unmintability that four separate
clauses cite by name as their compensating control.

**The defect was one missing option on one call**, in the one predicate the whole tier funnels
through. Everything above it was correct and none of it mattered.

**v2.4, and it generalises past case:** **a path predicate must be tested against the identity
semantics of the filesystem it defends** — case folding, Unicode normalisation, short (8.3) names,
trailing dots and spaces, alternate data streams, and separator forms. Each is a way for two
different strings to name one file, and a guard that treats them as different is measuring strings
while claiming to protect files. **The test is not "does the pattern look right" but "can I name
this file in a way the pattern does not recognise".**

### E50 — a SCAN is a predicate too
This build unified the "is this halt answered?" test into one shared function, and left the "which
files are halts?" **enumeration** duplicated across its two consumers. Correcting one copy made the
two **disagree inside a single run** — the detector naming an open halt while the verdict beneath it
read none, which is the exact failure the shared predicate had been written to end.

**The rule about which inputs count is as much a predicate as the rule about what they say**, and it
drifts the same way. The earlier lesson had been learned in the narrow form — *share the test* —
and the broad form was still open: **share the selection.** Caught by a member whose rows returned
the wrong verdict class, not by reading.

**v2.4: when a predicate is extracted into one place, extract the enumeration that feeds it in the
same move**, or the pair will disagree the first time either is corrected.

### E51 — a convenience must never suppress an artifact
The runner's wake signal had a branch that, when an orchestrator session was named, printed the
signal to **stdout** and **suppressed the durable `.wake` file**. The contract's own wording is
"otherwise writes `<dispatch>.wake`", and neither of the two mechanisms named as the alternative
exists on this harness — so the suppressed branch was the only one the contract actually described.

**Stdout is not a channel.** Nothing reads it after the run, it is not the dispatch's face, and the
completion review cannot open it. Printing was a convenience for a human watching a run live; it was
allowed to replace the record.

**v2.4: an observability affordance may be added beside an artifact and never instead of one.**
Where a clause says "otherwise write X", a branch that writes nothing is not an optimisation of that
clause — it is a different clause, and one nobody ratified.

---

### E48 AMENDMENT — the second occurrence, and why a third correct excerpt is not the cure
E48 recorded that an install document printing an implementation ships a **second copy** of it. The
page then did it again: §5.2 printed the **superseded wide form** of the worker-plane rule —
`.mission/dispatches/[^/]*\.handoff\.yaml$`, with no dispatch scoping — while the live rule a
directory away had been narrowed to the dispatching id precisely because the wildcard let a worker
overwrite a **peer's** handoff. An independent reader instantiated both and evaluated them: they
agree on the shared case and diverge exactly on the peer-handoff hole. An operator following the
page would have installed, by hand, into the **sealed** guard, the defect a prior round found.

Both occurrences were caught by a reader. Nothing on disk could have caught either, and that is the
whole of the finding: **the page was the only artifact in this build that no instrument read.**

**The cure is not a third correct excerpt.** Every function-shaped block on the page is now located
in its source by name and compared as CODE — tokenised, commentary and layout dropped, every
remaining token equal — and the member fails when the two drift. It also asserts the page still
CARRIES at least four such excerpts, because deleting them would otherwise be a way to go green,
which would make the check an incentive to remove the instructions it exists to protect.

**v2.4: a document that instructs an operator to MIRROR code must be executable against that code.**
If an excerpt cannot be checked, it must not be presented as the thing to copy — cite the file and
the symbol instead, and let the operator read the source.

---

### E53 — a NET DIFFERENCE is not a reconciliation, and reporting both directions does not make it one
H-2's sidecar compared a per-**dispatch** log count against a per-**session** transcript count by
subtraction, and reported only a positive remainder. A reader drove two independent instances in
which a **surplus** log entry cancelled a **vanished** call one for one — a subagent call captured
into the same store but excluded from the transcript count by design, and two sessions sharing one
dispatch id — each producing `capture_gaps: []` over a call that was gone, each with a control
differing by a single record.

**My first cure reported the surplus separately, and it was still wrong.** When the surplus and the
shortfall are the *same subtraction*, an EXACT cancellation is still zero: the branch that would
have named the surplus never fires, because there is no remainder to name. A second direction on one
number is still one number.

The arms are reconciled **per outcome category** now — failed, succeeded, denied — each paired with
what it can be paired with, so a surplus in one cannot pay for a deficit in another. Every failed
call in the transcript is by construction a call with no log entry, which is not a discrepancy to be
netted but the population the clause names. The log side is filtered to the session the transcript
describes, and where no session is known the comparison is reported as **uncomparable** rather than
performed.

The corroborating detail is the sharpest one: the manifest's own `call_completeness` block, computed
beside this sidecar by the sealed library, read **"incomplete, unmatched=1"** in the same finalize in
which the sidecar read clean — because it reconciles per category with absolute differences. **The
artifact the clause nominated as its capture point was strictly weaker than the block next to it.**

**v2.4: two counts may only be subtracted when they are known to describe the same population, and a
detector must state which population each of its arms measured.** Where the populations differ,
"we could not compare" is the finding — never a quieter way of saying nothing was lost.

---

### E54 — "it failed under the defect" proves nothing unless it passed without one
Falsify-first is this build's strongest habit and it has a silent failure mode. A falsification
asserts that reintroducing a defect makes a member FAIL. If the member was **already failing**, that
assertion holds for free.

Measured: T-9's first fixture bound both repositories' gates to a single tip, so the gate in the
pushed repository could never be consumed and the member could never pass. Its falsification row
read `[ok]` — the defect was reintroduced, the member failed, the harness was satisfied — over a
member that measured nothing. The full suite caught it minutes later, which is the only reason it is
recorded here as a lesson rather than as a shipped hole.

Both falsification harnesses now run every target instrument **clean first** and require the member
to PASS on the untouched tree before its defect is reintroduced.

**v2.4: a falsification is a PAIR of observations — green on the true tree, red on the perturbed
one — and a harness that records only the red half is measuring its own perturbation.**

---

### E55 — a fixture that does not pin its root will reach for the live plane
The evidence hooks resolve their repository from `CLAUDE_PROJECT_DIR`, falling back to a `.git`
ancestor walk. A member that drives a real hook as a child process therefore inherits **this
session's** project directory unless it says otherwise — so T-9's first run, exercising push-gate
consumption, went looking for **the live repository's own** push gate. Nothing was mutated, because that
repository had no gates directory at all. That is luck, and luck is not a control: had a live gate
existed and matched, a test would have stamped a real authorization consumed.

E33 already forbids probes inside a live evidence plane. This is its neighbour: **the fixture did
not run inside the live plane, it merely failed to say which plane it meant**, and the default was
the live one.

**v2.4: every fixture that invokes harness machinery must pin the environment that machinery reads —
root, dispatch id, session id — and restore it afterwards. A default that resolves to the live plane
is a defect in the fixture, not a property of the machinery.**

---

### E56 — the cure was applied where the finding pointed, and nowhere else
A round-3 finding named `file_exists` resolving relative paths against the **cwd**. I fixed
`file_exists`. Three other detectors take a path — `instrument_exit0`, `validator_pass_count`'s
`dir`, and `time_cap`'s `since_file` — and all three still resolved against the cwd, in the same
file, in the same evaluator, for the same reason. The residual survived a cure that reported the
class fixed.

The same shape appears twice more in this round: a gate lookup taught to read `kind` for four gate
kinds and not the fifth, and a marker scan corrected for parsing while its **directory scope** stayed
one level deep.

**v2.4: a finding names an INSTANCE; a cure must name the CLASS and enumerate its members.** When a
defect is "X resolves against the wrong root", the fix is not "X resolves correctly" but "every
consumer of that root is listed, and here they all are".

---

### E57 — the orchestrator chooses a validator's subjects, and a path left off the list is unguarded
Subject integrity — hash every artifact a validator is handed, re-hash on return, void the verdict on
any mismatch — is the compensating control for a validator role whose shell surface is bounded only
by a deny enumeration. It is only as wide as the **subject set**, and the subject set is composed by
the orchestrator, by hand, before the spawn.

Measured in round 4: the set handed to the WP-5 validator omitted three paths that work package's
own clause names — the next-gen library, the install document, and the runner. Those artifacts were
in scope for the judgment and outside the control that protects it. Nothing moved; nothing would
have been detected if it had.

**v2.4: a compensating control that takes an enumeration must derive that enumeration from the
contract clause under test, not from the author's recollection of it** — and the derivation belongs
in the tooling, so a forgotten path is a failure rather than a silence.


---

### E58 — a cure can NARROW a second axis while widening its own, and nothing will say so
H-2's reconciliation was refuted in round 4 for netting a surplus against a vanished call. The cure
replaced one subtraction with a per-category comparison — correct, and strictly stronger on the axis
it was written for. It also **read three of the summariser's five outcome states**, where the
arithmetic it replaced had implicitly covered all of them: `tool_use_total` includes `unresolved`
calls, so the old net difference reported them and the new, better form did not.

An `unresolved` call is a `tool_use` the transcript never resolves — no outcome record, therefore no
PostToolUse, therefore no log entry. **That is precisely the population H-2 exists to name**, and a
session stopping while a call is in flight is the most reachable way to produce one. The sidecar
whose whole claim is "a vanished call can never coexist with an empty sidecar" returned clean for it.

No reader found this. It was found by pointing the previous batch's own rule (E56) at the previous
batch. And the tell had been in hand the whole time: A1's `call_completeness`, which I read while
designing the fix, reports exactly these states as `unreconciled`. I took its per-category
arithmetic and left the branch directly beneath it.

**v2.4: when a cure replaces a coarse measure with a finer one, enumerate what the coarse measure
covered INCIDENTALLY.** A finer instrument is not automatically a superset. The regression is
invisible precisely because the new form is better on the axis everyone is looking at.

---

### E59 — a falsification is a PAIR, and a harness that records only the red half measures nothing
Falsify-first is this build's strongest habit and it has a silent failure mode: asserting that
reintroducing a defect makes a member FAIL is free **if the member was already failing**.

Measured twice. T-9's first fixture bound both repositories' gates to a single tip, so the gate in
the pushed repository could never be consumed; its falsification row read `[ok]` over a member that
could not pass. And T-3b's first fixture sat inside a sandbox under the gitignored runtime plane —
itself protected territory — so joining any cwd inside it made every relative path resolve to a
protected one, all six rows denied, and the member would have gone green while measuring where its
own sandbox lived.

**v2.4: every falsification harness runs the target instrument CLEAN first and requires the member to
PASS on the untouched tree.** And a fixture for a path-sensitive rule must be built OUTSIDE the
territory that rule defends, or it cannot tell the rule from its own location.

---

### E60 — the control row is where the second defect lives
Three of round 5's findings were not found by the assertion a member was written for. They were found
by its **control** — the row that exists only to prove the member can report the other answer.

* `mission-gate revoke` refusing a mismatched kind worked; its control, revoking a well-formed gate,
  did not — because the revocation predicate had been restated without `(?!null)`, so a gate carrying
  the literal `revoked_at: null` read as ALREADY REVOKED and revoke reported success having changed
  nothing. For a `supersession` gate that is the only withdrawal mechanism there is.
* The push-gate kind check worked; its control failed for the same reason, in the guard — two
  adjacent lines about two fields of one artifact, and only `consumed_at` carried the negative
  lookahead. **Fourth instance of one defect.**
* `halt_absent` resolving a relative dir worked; the verdict it produced was `NOT_MET` rather than
  `HALT`, because sharing the ENUMERATOR was not sharing the SCAN — the detector passed its declared
  dir and the C-3 verdict path passed `$null`. `NOT_MET` blocks and means "the agent has work left";
  `HALT` hands control to a human. The wrong one of those was being reported over an open HALT.

**v2.4: the control is not ceremony and it is not symmetry — it is a second measurement of a
different mechanism, and it fails more often than the assertion does.** A member without one has
tested half of what it claims.

---

### E61 — a predicate that means "the document's own statement" must be anchored, and anchoring is not always enough
`Test-HaltAnswered` took the first line matching a `Status:` shape, and the shape admitted leading
whitespace — so a HALT artifact showing the marker's shape in an **indented example above its own
marker** read ANSWERED while open. These documents explain their own conventions constantly, so the
shape is routine rather than contrived. Third instance of one class in one file:
`validator_pass_count` counted indented per-member `verdict:` lines until it was anchored, and the
C-3 scan had it too.

**And the obvious cure was half a cure.** Anchoring at column 0 fixes the indented example and does
nothing about a **fenced** one, which sits at column 0 too. Measured across four example shapes
before applying: of the four, anchoring alone still misread one. The cure strips fenced blocks and
then anchors.

**v2.4: when a cure is written for a defect that was found in one shape, enumerate the shapes.** The
reader who reports a defect reports the instance they hit; the shapes they did not hit are the ones
the cure will miss.

---

### E62 — a compensating control is only as wide as its enumeration, and a phantom entry is worse than a short list
Subject integrity is the enforcing control for a validator role whose shell surface is bounded only
by a deny list. Round 4's finding was that the subject SET omitted three paths the clause named
(E57). Round 5's is one step further in: a subject can be named and **not exist**.

`tools/lam/mission-verify.ps1` was in WP-2's set; the real file is `tools/mission-verify.ps1`. The
capture tool recorded the phantom honestly as `state: absent` with no hash — the tool was right — and
the composition step asserted only that the COUNT matched, which it did, because an absent subject
still counts as one of eight. **The set looked complete while protecting nothing at that path, and
verification would have returned OK forever, because absent stays absent.** The artifact was covered
only because the validator noticed, found the real file and re-hashed it itself.

The derivation tool asked "is every clause path covered by a subject?" and never "is every subject a
real path?" — one direction of a two-directional question, which is the defect design §4.5 law 3 and
the N10 pattern exist to forbid, found in the tool written to enforce that very rule.

**v2.4: an enumeration-based control must validate its own enumeration, in both directions, and a
member of it that cannot be resolved is a FAILURE at composition time — never a silent pass.**

---

### E63 — subject integrity is scoped to SUBJECTS; a validator's doubt is not
Round 6's WP-4 reported, unprompted, that `mission-goal-check.ps1` changed in the working tree
during its run and that two peer result files disappeared — and concluded that another party was
writing the repository concurrently. It was right. It was me: fixing WP-3's findings, and preparing
the round, while WP-4 was still measuring.

**No verdict was voided, and that is checkable rather than assertable.** Every subject set was
re-hashed while the round was still in flight and all five were byte-identical; the files I touched
were in nobody's set. The control did its job.

**But the control answers a narrower question than the reader was asking.** Subject integrity says
"the artifacts you judged did not move". A validator watching the tree mutate around it is asking
something else: *can I vouch for what I measured at all?* A reader that cannot answer that has to
either qualify its verdict or spend effort proving the change was irrelevant — and both are costs
the orchestrator imposed for no benefit.

**v2.4: while any fresh identity is in flight, the orchestrator writes NOTHING to the repository —
not merely nothing to a subject set.** Staging, drafting and analysis belong outside the working
tree until every identity has returned. "Outside the subject set" is a statement about hashes;
"invisible to the reader" is a statement about trust, and only the second one buys a clean verdict.

---

### E64 — when you enumerate the shapes, the plainest one is the one you will miss
E61 said: a cure written for a defect found in one shape must ENUMERATE THE SHAPES. It was written
after `Test-HaltAnswered` misread an **indented** example of a status marker, and the cure enumerated
indented and **fenced** — the two exotic forms — and shipped.

Round 6 drove the third: a halt whose body **quotes a neighbour's marker at column 0**. No
indentation, no fence, just prose citing another halt, which these documents do constantly. Verdict
MET, `open_halts: []`, exit 0, hook approve, over an unanswered HALT.

**The shapes an author enumerates are the ones they had to think about.** The plain case is skipped
precisely because it feels already handled — it is the case the original code was written for. So an
enumeration produced by the person who wrote the cure will reliably contain the unusual members and
omit the obvious one.

The cure that finally held stopped enumerating shapes altogether and changed the question: every
column-0 marker is collected and the document is answered only if they **agree**, because a file
saying two things about its own status has answered nothing. **v2.4: prefer a rule that makes the
shapes irrelevant over a list of the shapes you thought of** — and where a list is unavoidable, have
someone who did not write the cure produce it.

---

### E65 — a count in a comment reads as though somebody counted
A comment in the goal evaluator read: *"So: six inputs — file_exists.path, instrument_exit0.path,
validator_pass_count.dir, time_cap.since_file, halt_absent.dir, verify_pass_or_dib.path — and every
one of them now calls Resolve-DetectorPath."*

There were seven. `gate_present`'s `path:` override was never counted and never resolved, and a
reader drove a goal satisfying one mission's gate detector with **another repository's gate**.

The comment was worse than the earlier version it replaced, which had merely claimed "every
path-taking detector calls it". A bare claim invites checking; **a number implies the checking has
already happened.** Both were written by the same hand in the same file, and the second was written
specifically to fix the vagueness of the first.

**v2.4: a completeness figure stated in prose must be DERIVED and ASSERTED, not counted by hand.**
The member now asserts the call-site count, so an eighth input fails the suite rather than the next
reader.

---

### E66 — the evidence you have just plumbed in is the evidence you will forget to hand the other consumer
In one commit, the guard was taught to read the `cwd` its payload had always carried — with three
paragraphs explaining that throwing that evidence away was how a `cd`-and-write sequence walked past
the protected tier. In the **same commit**, the push-target resolver was left unable to see it, so
`git push` with the process simply standing in another repository published an ungated one, and
PostToolUse tombstoned the session's gate for it.

Not two batches apart. Not two files apart. One commit, one function's blast radius: the fix
enumerated the consumers it was thinking about (the path predicates) and not the consumer it was not.

**v2.4: when a new input becomes available to a component, enumerate every decision inside that
component which was previously made without it.** New evidence is not a patch to one call site; it
is a question asked again of everything that had to guess before.

---

### E67 — resolve the thing the ACT changes, not the thing the command mentions
The push-target resolver gave `--work-tree` priority. That is wrong on the merits, and the wrongness
is not subtle once stated: **a push publishes the repository — the object store, the git dir — not
the working tree.** `--work-tree` selects which files are staged; it does not change where objects
go. So `git -C <other> --work-tree <session> push` publishes **other**, and the resolver answered
**session**.

It was built by collecting the spellings that had been seen fail, rather than by asking what a push
actually does. Enumerating spellings is how the previous two rounds' fixes were built too — and each
time the next reader found a spelling outside the list.

**v2.4: a resolver must be derived from the SEMANTICS of the act it guards, not from a list of the
inputs that have embarrassed it so far.** The list is unbounded and the semantics are not: a push
has exactly one object store, and every spelling is just a way of naming or standing in it.

---

### E68 — an artifact's PRESENCE is not its COMPLETION
Round 6's WP-5 result file appeared on disk, 299 lines, well-formed, `verdict: PASS` at column 0,
ending on a complete sentence. Every signal a reader would use to call it finished.

Its sha256 changed minutes later. The agent was still writing.

**Banking it on sight would have been a self-inflicted provenance failure.** The completion line
records the hash the orchestrator measured; the file would then have moved underneath it, and
`validator_pass_count` — which counts a result only if its sha256 matches a completed ledger line —
would have reported the package FOREIGN forever. The detector would have been right, the file would
have been genuine, and the ledger would have been the thing that was wrong.

The near-miss is instructive because the artifact looked MORE finished than a half-written one
usually does: YAML parses, the top-level verdict is present and anchored, the prose ends cleanly. A
completeness check over the content would have passed.

**v2.4: the signal that a spawned identity has returned belongs to the SPAWNING MECHANISM, never to
the artifact.** A file is a result when the thing that produced it says it has stopped — and the
hash is measured at that moment, not before. Where no such signal exists, the artifact must carry an
explicit terminator the writer emits last, and its absence must be a refusal rather than a wait.

---

### E69 — a member that calls a function the way the CALLER does not is testing something else
H-2's transcript arm was refined across three rounds: the E45 cure, then the per-category
reconciliation, then the unresolved-state fix. Every one of those rounds ended with a green member.

**The arm had never run in the delivered lifecycle.** For a runner-owned dispatch the Stop hook is a
no-op, so `evidence-dispatch-end.ps1` is the only writer of the sidecar, and it learns a transcript
path from nothing but its stdin payload — which the runner filled with `{"session_id": …}` and
nothing else. The transcript arm was skipped every time, leaving the call counter alone: the arm that
increments *inside* PostToolUse, which E45 itself established cannot see a call that never got there.

**Every member reached the writer directly, with a transcript path in hand.** That is not how the
production caller invokes it, and the difference was the entire defect. Three rounds of increasingly
careful work on a function's internals, while the argument that decides whether any of it executes
was never the one the member passed.

This also explains why the earlier errata did not catch it. E56 says enumerate the class; the class
was enumerated inside the function. E58 says a finer measure may drop what a coarse one covered; the
measures were compared inside the function. **The question none of them asked is whether the function
is reached with those arguments at all.**

**v2.4: a member must exercise the PRODUCTION CALL PATH, not the unit.** Where a unit test is
genuinely wanted, pair it with one row that drives the real caller with the real payload — and if
the two disagree about what the function receives, the unit test is the one that is wrong.

**AMENDED IN ROUND 7, BY THE MEMBER WRITTEN TO OBEY IT.** `H-2f` was written for this erratum and
does drive the real `evidence-dispatch-end.ps1` with the runner's real payload shape. It passed
`$gapId` as the session id **and stamped the fixture's log entries with that same id**. In
production those are two different namespaces — the runner composes a synthetic `session-<dispatch>`
to address the store, while PostToolUse stamps entries with the worker's real harness session id —
so the log filter discarded every entry and a complete store reported phantom gaps.

**The call path was right and the arguments were fiction.** A fixture in which two identifiers
coincide cannot see a defect that exists only when they differ, and nothing about driving the real
entry point fixes that.

**v2.4, strengthened: a member must supply what the production caller supplies — the same values, in
the same namespaces, under the same normalisation.** Where two identifiers can differ in production,
the fixture must make them differ. Where an input has spellings, the fixture must carry the ones the
author did not choose. A fixture built from the author's own vocabulary tests the author's
assumptions and reports the result as a property of the system.

---

### E70 — a cure that narrows what a rule RECOGNISES widens what it ACCEPTS
Four of round 7's findings share a mechanism worth separating from E69, because it is not about
fixtures at all. Each cure made a rule stricter in the dimension it was written for, and in doing so
made the rule's INPUT SET smaller — and a rule that sees less can conclude more.

* Session scoping made the reconciliation stricter about which population it compares. It also made
  the log side EMPTY on the delivered path, and an empty side has no discrepancies.
* "Collect every marker and require agreement" made the halt predicate stricter about ambiguity. It
  also depends on collecting the document's OWN marker, and one unrecognised spelling reduced the
  set to a quoted neighbour's marker — which then agreed with itself.
* Anchoring the marker at column 0 made the predicate stricter about indentation. It also stopped
  recognising forms that are ordinary Markdown.
* Narrowing the push resolver to the push SEGMENT correctly stopped a `-C` in an earlier command
  answering for a later push. It also stopped `cd <other>; git push` resolving anywhere but the
  session repository — reinstating, through round 7's cure, the defect round 6 had fixed.

In every case the cure was right about the thing it was watching and wrong about what it could still
see. **A filter that removes the wrong things is indistinguishable, from inside, from a filter that
finds nothing wrong.**

**A fifth instance arrived while this erratum was being written, and it is the reason for the
wording.** The cure for the newline defect was to stop hand-rolling a segment scan and call the
library splitter that already existed in the file it dot-sources — an unambiguous improvement, and
the right call. That splitter does not split on PARENTHESES, and the scan it replaced did. So
`(git push origin main)` — a shape an independent reader drove in round 2, which the function's own
doc comment lists among the four fail-open spellings it exists to close — went back to ALLOWED.
Nothing about that substitution looks like a narrowing; it reads as replacing worse code with better
code. The loss was invisible in the diff and visible in one line of output the moment the old
control rows were driven against the new function.

**v2.4: after tightening a rule, measure what it still ADMITS, not only what it now rejects** — and
treat adopting a better implementation as a tightening too, because that is precisely when nobody
thinks to ask. The regression question is not "does the new rule reject the defect" but "does the
new rule still see everything the old one saw", and it is answerable cheaply by running both forms
over the live corpus and diffing the readings. That check caught a widened marker regex that would
have read `**Status:** **ANSWERED**` as "no marker", turned an answered halt into an open one, and
pinned the goal at HALT permanently.

---

### E71 — a check written from a CLAIM inherits the claim's error
Round 6 cured a defect in the goal evaluator and recorded the reason in the code: a colon-space in
the unreadable-halt entry "made the whole verdict artifact unparsable — PyYAML refused the
document."

Round 7 wrote a member to guard that cure, and the member asserted exactly what the comment said:
run `yaml.safe_load` over the artifact and require success. It passed. The suite was green.

**Falsification reported the member BLIND** — reverting the cure left it passing — and one line of
measurement showed why. PyYAML does not refuse the document. `- name [UNREADABLE: msg]` is a
well-formed block **mapping**, so the list entry silently stops being a string and becomes a
single-key dict. The claim was false, and the check had been written from the claim rather than from
the artifact, so it could only ever confirm it.

The real defect is also worse than the one I had described, which is the part worth keeping. A parse
error is loud and stops the reader. This passes every parse, and then `"<halt>.md" -in $open_halts`
is **false**, the halt's name comes back with `[UNREADABLE` glued to it, and every consumer iterating
the list gets a mapping where a filename belongs — in the one artifact whose entire purpose is to
report that a halt could not be read.

**v2.4: derive the assertion from the ARTIFACT, not from the sentence explaining the artifact.**
Where a cure's rationale names a specific failure mode — "this makes it unparsable", "this makes it
ambiguous", "this loses the value" — the member must MEASURE that failure mode against real output
before asserting it. A rationale is a hypothesis; a member built on an unmeasured hypothesis tests
the author's belief and reports it as a property of the system.

**Corollary, paid for in the same batch: a cure with two halves needs two perturbations.** The
literal was not the only route to a colon-space in that scalar — an exception message carrying its
own reaches it by the same mechanism. The first falsification pass perturbed one half and reported
the pair held.

---

### E72 — the OS resolves the path after the matcher has finished with it
Round 8 cured a case-sensitivity hole in the evidence guard, and falsifying that cure raised the
question the cure invites: if `.MISSION` and `.mission` must both match, what else does Windows treat
as the same path?

**Win32 strips trailing dots and trailing spaces from every path component when it resolves one.**
Measured here, directly: a file written as `tdprobe.txt` is found by `Test-Path` under both
`tdprobe.txt.` and `tdprobe.txt ` — `True` for both. The matcher compares **strings**, as a canonical
suffix test, and it runs before the filesystem is consulted at all. So a spelling the matcher does
not recognise as protected can still land on the protected file.

Two things make this sharper than an ordinary spelling gap.

**It reaches the file-tool route, which has no second tier.** The shell route also applies a
metacharacter test, so an oddly spelled protected path can still trip *that*. The file-tool branch
tests protected paths and nothing else, so on that route the spelling is the whole distance between
refused and written.

**It is not curable by a delta.** `Get-EvidencePathHits` is SEALED in the A1 library
(`evidence-common.ps1`, sha256 `EC27AB3A…`, the sealed anchor). A delta may dot-source and redefine,
and this build's delta already offers resolved spellings as extra text tokens for exactly this class
of gap — but the sealed matcher stays the thing every consumer calls, and what it is handed is still
matched as a string. The exposure is therefore a property of the installed A1, not of the delta.

**A re-measurement attempted while writing this erratum FAILED ITS OWN CONTROLS, and that is
recorded here rather than dropped.** A harness calling `Get-EvidenceGuardDecision` directly returned
`allow` with reason *"no protected path in the target path"* for **every** row — including the plain,
correctly spelled, absolute protected path that exists only to prove the harness is reachable. A run
whose control does not deny measures nothing about the rows beneath it (E60), so those rows are not
evidence and are not reported as any. Two things were nevertheless learned and are worth the trip:
the OS fact above is measured and holds, and `.mission/gates` is **not in the protected set at all** —
LAM-INSTALL §5.3 already says so in as many words, which is why a probe built on that path could
never have tested anything.

**v2.4: a matcher that compares path STRINGS must say so, and its reach must be stated as "before
OS resolution".** Every unmintability claim resting on it is a claim about the matcher, not about the
filesystem, and the gap between the two is one character wide. Record the exposure where the CLAIM is
made rather than where the cure would go: a cure that cannot be written still has to be disclosed,
and an undisclosed sealed exposure reads exactly like an absent one.

---

### E73 — a deletion filter is a claim about a set, and it must be READ before it is run
Cleaning up a directory created by a typo, this build wrote `if '<TOKEN>' in name: rmtree(name)`, `<TOKEN>` a substring of the project's own name, and
ran it. The substring matched nineteen unrelated sibling directories — harness scratch state for
nested probe sessions from earlier rounds — and destroyed them before an unrelated Unicode error in
the *logging* stopped the loop. The loop never reached the one directory it had been written to
remove.

Nothing in the evidence plane was lost: the mission's own records of those sessions live in
`.mission/evidence/session-*/` and were untouched, as were every RESIDUE-KEEP file and every
`verify-*` store. **That is luck about blast radius, not correctness about method**, and the
distinction is the erratum.

The failure is precisely the one this register keeps recording in other clothes: an assertion written
from a belief about what a predicate matches, executed without measuring what it actually matched.
E64 is the same shape (the plainest spelling is the one you miss); so is E71 (a check written from a
claim inherits the claim's error). What makes this instance worse is that the operation was
**destructive and unrecoverable**, so there was no falsification pass available afterwards — the
measurement had to happen first or not at all.

**v2.4: enumerate, print, and read the match set before any destructive call — and match by exact
identity, not by substring, whenever the target is known exactly.** The target here was one literal
name. A substring filter was never needed; it was reached for because it was shorter to type. Where a
loop deletes, the print belongs on the line ABOVE the deletion and the operator's eye belongs between
them.

---

### E74 — curing a restated constant in one stage of a pipeline says nothing about the next stage
Round 9's spawn script was repaired before the round because `round = 8` was hardcoded in it while
`seq` was correctly derived from the ledger's own maximum. Run verbatim it would have banked six
round-9 spawns tagged round 8 — silently, with correct sequence numbers. The repair was driven, the
defect class was named in the handover, and the fix was written up at length.

**The collector that CONSUMES those spawn lines carried the identical defect and was handed forward
as the tool to use.** `v1r8-complete.ps1` restates the round in five places — the spawn filter
(`round -ne 8`), both baseline filenames, the duplicate-completion guard (`"round":8`) and the
completion record it writes. Run against round 9 it pairs round-9 results with round-8 baselines;
because the tree moved between the rounds, the subject-integrity tool correctly reports a mismatch,
and this build's own rule converts that to **verdict void, identity spent, HALT raised** — six
times, for a reason that is an artifact of the collector rather than a fact about the build.

Then the rule was applied properly, with `grep` rather than recall, across every script on the
round-9 path. **The class has three members, and reading had found only one.**
`check-subjects-intact.ps1` hardcodes `r7-` baselines and `r8-integrity-now.ps1` hardcodes `r8-`;
both are subject-integrity checkers, and both answer *"has anything moved while the round is in
flight?"* — a question worth asking at any moment during a round — with violations that are
artifacts of their own filenames. The sweep took one command and found twice what reading did.

Two things make this worse than an ordinary recurrence of E56. The class had been named **in the
same session, in the same pipeline, an hour earlier** — so this is not a lesson that had yet to be
learned, it is one that had been written down and then scoped to the file being edited. And the
shared fact is encoded in a **filename** (`r<N>-baseline-WP-<n>.json`), which every consumer
re-derives by string-building; a naming convention is a restated predicate that does not look like
one, so a reader scanning for duplicated logic passes straight over it.

All three fail toward VIOLATED rather than toward a false green, which is the safe direction and is
the only mercy here. But a confidently wrong loud answer still costs a round, and it would have put
six HALTs describing nothing in front of the operator.

**v2.4: when a restated constant is found in one stage of a pipeline, the enumeration is every
stage that reads the same fact — and it is performed mechanically, not from memory.** Grep the
pipeline, not the file. And prefer eliminating the restatement to correcting it: the location of
round 9's baselines was already recorded in the spawn line that banked them
(`subject_baseline`), so no consumer ever needed to reconstruct it from a naming convention. The
replacement collector reads that field, which is why it cannot drift — a fact kept in one place
cannot disagree with itself.

---

---

### E75 — a guard that compares path STRINGS is answering a question the filesystem decides
Three rounds have now found the same defect wearing a different spelling. Each time, a path form that
a string comparison called different named **the same real file**, and each time the chain ran to the
end: the write landed in the real gates directory, `mission-gate.ps1 list` read the artifact back as
a valid open build-authorization gate, and the agent-unmintability that R-1 and two contract
amendments each cite *by name* was void.

| round | spelling | what opens |
|---|---|---|
| 3 | case — `.MISSION/GATES/x` | `.mission/gates/x` |
| 8 | trailing dot — `.mission/gates./x` | `.mission/gates/x` |
| 9 | 8.3 alias — `MISSIO~1/gates/x` | `.mission/gates/x` |

**Each was cured on its own, and none of the first two prompted the question that would have found
the next: what ELSE resolves?** That question is cheap to ask and was never asked, because each
finding arrived as a specific spelling and was answered as one — E56's lesson, at the level of the
platform rather than of a function.

**The third member differs from its siblings in a way that decides how it can be cured, and the
difference is worth more than the cure.** Case and trailing dots are pure STRING transforms: the
guard can compute them from the text and needs nothing else. An 8.3 alias is a **FILESYSTEM FACT** —
nothing in `MISSIO~1` says what it stands for, and only the volume can answer. So a string-only
matcher cannot be *taught* this one at all. What the delta does instead is resolve the alias against
the filesystem and ask the sealed matcher **again** with the resolved spelling. That defence exists
only where the prefix exists on disk, which makes it strictly weaker than the other two, and the
install page now says so rather than implying parity.

**And the sweep found a route no report named.** After the reported rows were cured, the same
question asked of the OTHER route showed A1's own protected tier — `.mission/evidence`,
`.mission-runtime/evidence` — still reachable through the alias by the **file-tool** route, while the
shell spelling of the identical act denied. The delta rewrites the text it hands A1 for a shell call
and had offered the file-tool route the Win32 form alone: one route cured, one not, for the fourth
recorded time in that file.

**v2.4: a guard whose subject is a PATH must state, on its own face, whether it is comparing strings
or asking the filesystem — and every normalisation the platform performs is part of its threat
model, enumerated rather than discovered one refutation at a time.** On Win32 that enumeration is at
least: case, trailing dots and spaces, 8.3 aliases, dot segments, and the cwd a relative path is
resolved against. Where a normalisation cannot be computed from text, the guard must say what it
does instead and how much weaker that is. **And a cure applied to one route is not a cure**: the
routes are enumerated with the spellings.

---

### E76 — a setup step whose failure is invisible is not a setup step
The member written to guard round 9's push-redirection cure minted a gate for its fixture with
`-AuthorizedTipSha`. The tool's parameter is `-TipSha`. The call failed, its result was assigned to
`$null` and never inspected, and **no gate was ever created** — so the three rows asserting that a
redirected push is DENIED would have denied because no gate existed anywhere, not because the
resolver answered for the right repository. The member would have passed, with every row green,
while measuring nothing about the thing it was written for.

It was caught by the one row that *had* to change its answer: the positive control asserting the
plain, legitimate push is ALLOWED on its own gate. That row failed, and it was the only reason the
setup failure was visible at all.

**This is the control-row lesson (E60) pointed at SETUP rather than at assertions.** A fixture's
preconditions are claims like any other, and an unasserted precondition is the cheapest place in a
harness for a silent failure to hide: nothing about it appears in the output, and the assertions it
invalidates go green.

**v2.4: every fixture precondition that a member's rows depend on is asserted as its own row.** The
gate was minted; the repository was created; the directory exists; the environment variable is
pinned. And where a member's rows expect a REFUSAL, it must carry a positive control that expects
permission — otherwise "everything denied" and "the cure works" are the same observation.

---

---

### E77 — a "dry run" that mutates is worse than no dry run, because it is believed

`round<N>-prepare.ps1` takes `-DryRun`, and its own brief said it "does everything except append".
It did more than that: the archive-and-remove block ran **unconditionally**, so a dry run copied six
validator result files into an archive directory and **deleted the originals** while printing
`[dry-run] would append seq 71` and reporting the ledger byte-identical afterwards.

The archive was sound — hash-verified copies, nothing lost — and that is precisely why this survived.
A destructive step that destroys correctly leaves no wreckage to notice. The operator reads "would
append", concludes the tree is untouched, and is wrong about a different part of the tree than the
one the message is about.

**The rule.** A dry-run flag is a claim about the *whole* invocation, not about its noisiest step.
Every side-effecting block inside a `-DryRun`-capable script is either gated or the flag is a lie.
When gating one, say what is being skipped in the output — `[dry-run] archive+remove SKIPPED` — so
the skip is visible rather than inferred from silence.

**Related:** [E68] an artifact's presence is not its completion. Both are cases of a report that is
accurate about the thing it names and silent about the thing that matters.

---

### E78 — an implication passes vacuously, so non-vacuity belongs in the verdict, not in a comment

WP-4's T-2f asks: *whenever the verdict calls a gate usable, is it always stamped consumed?* Each row
computed `$ok = (-not $usable) -or ($stamped -and $keys -eq 1)`.

That is a correct implication and a defective member. When an unrelated fixture defect made every
gate unusable, all five rows evaluated `ok`, the member reported **PASS**, and it had measured
nothing at all. This is not hypothetical: it happened during this round's work, and it was found only
because a *different* member failed loudly enough to make the fixture suspect.

**The rule.** A member whose predicate is `A ⟹ B` must also assert that `A` occurred. Non-vacuity is
part of the verdict, not a remark beside it:

```powershell
$ok = ($t2fOk -and $t2fAnyUsable)   # not $t2fOk alone
```

and the count belongs in the printed detail, so a reader can see the member had something to judge.

**The general form.** Any member that can be satisfied by *the absence of its own subject matter*
needs a positive control in the same breath. "It refused everything" satisfies most refusal tests.

**Related:** [E80], the same failure arriving from the falsification side. [E60] the control row is
where the second defect lives.

---

### E79 — a member's evidence must be its own, or it is not evidence

T-2e and T-2f both built their detail text into a variable named `$detail`. T-2f's assignment ran
last. T-2e's `Check` call then re-read it, so **T-2e printed T-2f's rows** — five lines about
`consumed_at` sentinel shapes, under a heading about gate `kind` and revocation.

Nobody saw this for as long as T-2e passed, because a passing member's detail is not read. It
surfaced the first time T-2e failed, and the failure report described a different member's work.

**The rule.** Detail text is part of a member's verdict, not decoration attached afterward. Give each
member its own variable (`$t2eDetail`, `$t2fDetail`), and treat a shared accumulator in a file of
sequential members as the defect it is. The cost of getting this wrong is paid at exactly the moment
you can least afford it: when something has broken and the report is lying about what.

---

### E80 — a perturbation must express the failure it is named for, or "unmeasured" is a false reading

Falsifying "a removed decider is detected" meant breaking the installation check so it would report a
**missing hook as installed**. The first attempt disabled the absent-file branch:

```powershell
if (-not (Test-Path -LiteralPath $hookPath)) {   →   if ($false) {
```

Execution then fell through to `ReadAllBytes` on a file that does not exist, which **threw**. The
checker exited non-zero. "Not installed" was still the answer, the suite stayed green, and the
direction was reported **STILL GREEN — THE MEMBERS DO NOT MEASURE THIS**.

They measured it fine. The perturbation did not perturb. It replaced a lie with a crash, and a crash
is indistinguishable from the truthful refusal at the only interface the test reads — the exit code.

**The rule.** Before believing "this direction is unmeasured", confirm the perturbed code **actually
produces the wrong answer**, not merely a different failure. The corrected perturbation returned early
with `installed = $true` before anything could throw, and the member reddened immediately.

**Why this matters more than it looks.** A false "unmeasured" reading invites you to write a member
that already exists, or worse, to conclude a property is untestable. One of the two directions that
did not redden on first attempt in this round was a real coverage gap ([a finding below]); the
other was this. Telling them apart is the whole job.

---

### E81 — a fixture helper may add a remote; it may not restyle the repository it was handed

Converting WP-4's consumption members to real publications needed each fixture repo to have a bare
origin. The helper written for it also ran, for uniformity:

```powershell
git -C $Repo symbolic-ref HEAD refs/heads/main
```

`git init` in these fixtures produces **`master`**. That line pointed HEAD at an unborn branch. From
then on `git rev-parse HEAD` answered *"ambiguous argument 'HEAD'"*, and **three members that had
nothing to do with publication went red** — one of them a member about gate `kind` and revocation.
Time went into reading those as product defects.

**The rule.** A fixture helper's blast radius must not exceed its name. `New-BareOriginFor` may create
a bare repo and add a remote. It may not change the branch, the config, or the working tree of the
repository it was given. Where uniformity is genuinely needed, **ask** rather than impose:

```powershell
function Get-RepoBranch { param([string]$Repo) ... }   # and push THAT
```

**Related:** [E82]. Both are the fixture failing while wearing the product's clothes.

---

### E82 — MAX_PATH voids a fixture silently, and the failure arrives dressed as a product defect

The falsification harness mirrors the tree and runs the instrument against the copy. Placed under the
session scratchpad, the mirror root was already ~200 characters. WP-4 then builds a git repository at
`<root>\.mission-runtime\lam-wp4-sandbox\mission`, and git writes `.git\…` beneath *that*.

Nothing said "path too long". The fixture repository simply **did not come into existence**, and the
first thing to notice was the guard reporting *"the local tip could not be re-derived, so no
authorization can be checked against it."* That is a coherent, plausible product message. Seven
members were red. Moving the mirror to `%TEMP%\lamfx12` fixed six of them outright.

**The rule.** On Windows, a fixture root is a resource with a budget. Keep it short — under ~40
characters — and when a fixture-heavy suite fails in a way that looks like the product refusing,
**measure the path length before reading the message**. The related trap is already recorded: a plain
`git clone` of this repo leaves an empty tree on Windows for the same reason.

**The deeper point.** The guard's message was not wrong. It could not derive a tip, and it refused
rather than guessing, which is what it is supposed to do. Fail-closed machinery reports the *symptom*
faithfully and tells you nothing about the *cause*. That is a property to value, not to fix — but it
means the reader must supply the causal step, and "the fixture is fine" is the assumption to attack
first.

---

### E83 — a file's own header is a claim, and it goes stale the same way code does

`tests/lam/instrument-WP-4.ps1` carried, in its `.DESCRIPTION`:

> NO REAL PUSH IS EVER ATTEMPTED. The hooks are driven with synthesized PreToolUse/PostToolUse
> payloads…

A later amendment made a synthesized payload unable to consume a gate — deliberately, since a payload
*asserting* a push happened is the false witness round 8 measured. Four members were converted to
publish for real into throwaway bare origins. The header kept its sentence and the suite kept passing,
because **no member reads the header**.

**The rule.** This is [E34] — a restated predicate is a defect the moment it is written — arriving in
documentation rather than in code. When a change makes a file behave differently in a way the file's
own prose describes, the prose is part of the change set. And when correcting it, say what it used to
claim: a header that silently acquires the truth teaches nobody, whereas one that records *"this used
to say X, and here is when that stopped being true"* is the only durable form of the lesson.

The corrected header also states the safety property the old sentence was really carrying — every
remote in that file is a `git init --bare` directory under `.mission-runtime/`, so no push there can
reach a real remote — which is the thing a reader actually needed to know.

---

### E84 — when a test gains a host dependency, failing loudly is correct and must be SAID

Converting four WP-4 members to real publications gave the instrument a dependency it never had: it
now needs **git bash on the host** to drive a command through a real shell. A new fixture check
(`F-1`) asserts that dependency and **fails the package** when it is missing.

That looks like a package made fragile by its test harness, and the instinct is to skip those rows
when the shell is absent. **The instinct is wrong here, and the reason is worth stating**, because it
is the same reason as [E78]: without a shell, `Invoke-RealPushIn` returns `$null`, no publication
happens, no gate is consumed — and members whose predicate is *"if the gate was usable it must be
stamped"* would be satisfied by a fixture in which nothing was ever usable. A skipped row and a
vacuous pass are indistinguishable in a summary line that says `all N checks passed`.

So the dependency is asserted at the top, in its own member, where a missing shell reads as
**FIXTURE ABSENT** rather than as a product verdict. What must accompany that choice:

* the check names the dependency in its detail (`git bash (the shell that performs the real
  publications): <path or NOT FOUND>`), so the failure is self-diagnosing;
* the dependency is written into the acceptance record rather than discovered by whoever next runs
  the suite on a clean host;
* and it is placed **after** the machinery that resolves it, not beside the other presence checks —
  the first draft asserted `$bashExe` seventy lines before the variable was assigned and reported
  `NOT FOUND` on a host where git bash was installed. A check that fails on its own ordering is a
  vacuous pass arriving from the other direction.

**The general rule.** A test that acquires an environmental dependency has changed its own contract.
Assert it explicitly, fail closed on it, say what it is in the failure text, and record it where a
future operator reads before running — not in a comment inside the file that fails.

---

### E85 — a field written and never read makes a record look like it is doing work it is not

*Found by self-review AFTER the amendment's commit, not by the falsification. Recorded here rather
than quietly patched, because the round it belongs to was already frozen and judging that code.*

The ruling required that "consumption becomes conditional on an actual ref advance (**compare remote
ref before/after**, or the command's own result)". The in-flight record the decider writes carries
`remote_sha_before` for exactly that comparison, and `written_at` beside it.

`Complete-EvidencePushGate` compares origin against the **authorized sha** instead:

```powershell
$sha      = [string]$flight.authorized_sha
$observed = Get-EvidenceRemoteRefSha ...
if ($observed -ne $sha) { ...not consumed... }
```

That is the ruling's *second* branch and it is arguably the stronger one — binding to the value the
operator authorized is tighter than binding to "something moved". **But `remote_sha_before` and
`written_at` are then written and read nowhere in the tree** — those two assignments are their only
occurrences anywhere under `tools/`.

**Two things follow, and only the second is a risk:**

* **The record over-advertises.** A reader — human or a later maintainer — sees `remote_sha_before`
  in an audit artifact and reasonably concludes a before/after comparison happened. It did not. A
  persisted field is a claim about what the machinery consults.
* **There is no staleness bound.** When the remote cannot be asked what it holds, the code
  deliberately leaves the record in place "for the next attempt" — correctly, so a transient network
  failure does not strand the operator. With `written_at` unread, that record has **no expiry**. It
  can outlive the push it describes indefinitely, and a later `PostToolUse` in the same repository
  will consume the gate once the remote becomes answerable and holds the authorized sha.

**How bad, stated precisely.** Consumption still requires origin to *actually hold the authorized
sha*, so no unpublished sha can spend a gate — the round-11 defect stays closed. What is imprecise is
**provenance**: `consumed_basis` asserts *"the decider witnessed the publication"* when it may have
witnessed an attempt whose success arrived later, or from somewhere else. That is an audit-record
accuracy problem, not an authorization bypass, and it should be described as the smaller thing it is.

**The rule.** Either consult the field or do not persist it. If it stays for diagnostic value, say so
on its face (`# recorded for diagnosis; not consulted by consumption`) so the next reader does not
infer a check that is not there. And any record deliberately allowed to survive a failure needs an
age bound, because "left in place for the next attempt" and "left in place forever" are the same code.

---

### E86 — "each was checked" is the most dangerous sentence a list can carry

*Found by self-review after the amendment's commit. **Not driven** — this is a code-and-documentation
reading, and it is recorded as such. The way to settle it is stated at the end.*

The amendment restored nineteen git subcommands to the non-push list, and the code says why:

> `# None of these publishes: each was checked against what it does, not against whether it looked
> harmless.`

**At least four of the nineteen publish.**

| entry | how it publishes | does `pre-push` fire? |
|---|---|---|
| `subtree` | `git subtree push --prefix=… <remote> <branch>` | **yes** — delegates to `git push`, so the DECIDER still covers it |
| `for-each-repo` | `git for-each-repo --config=… push` runs a git command in every configured repo | **yes** — the inner `git push` runs the hook |
| `svn` | `git svn dcommit` commits to an SVN server | **no** — not the git wire protocol, no ref update, no hook |
| `lfs` | `git lfs push <remote> <ref>` uploads LFS objects | **no** — an object transfer, not a ref update |

The first two are survivable: the tripwire stops recognising them, the decider still refuses them, and
that is exactly the layering that amendment installed. **The last two are not covered by any layer.**
The tripwire now allows them by name, `pre-push` never runs for them, and **S-4's origin binding reads
the git remote**, so a `dcommit` to SVN or an LFS object upload is invisible to the detector as well.
All three layers miss the same two commands.

**This is [E70] again — a cure that narrows what a rule RECOGNISES widens what it ACCEPTS** — arriving
this time through a list edit that read as pure paying-down of over-refusal.

**Where the nineteen came from matters.** The number was supplied by the builder, in the HALT that
asked for the ruling, and the ruling then directed that "the 19 over-refused subcommands are
restored". Four of them were not over-refused; they were correctly refused. A figure offered to an
operator inside a request for a decision comes back as an instruction, and it arrives carrying
whatever care went into producing it. **The list was written from what each subcommand is *usually*
for, and then the comment asserted it had been checked against what each one *does*.**

**Why the sentence is worse than the list.** A wrong list is a defect. A wrong list wearing *"each was
checked"* is a defect plus a reason for the next reader not to look. It is [E71] — a check written
from a claim inherits the claim's error — pointed at a future person instead of at code.

**The rule.** A membership list whose entries were *reasoned* about must say so in those words.
Reserve "checked" for entries that were driven, and if only some were, name which. Where a list
governs a safety property, the entry test is not "is this command usually harmless" but **"can this
command, under any documented invocation, do the thing the guard exists to prevent"** — and for a
publication guard that includes publication to a remote that is not a git remote.

**How it was settled, and how far.** Under a follow-up amendment all four are **removed from the list**, so the
tripwire recognises them again. One row is measured and three are not, and that amendment's own sentence
discipline (T-2s) requires saying which is which:

* **`git subtree push` — DRIVEN.** An independent reader (V-1 round 12, WP-1) ran it with the decider
  installed and no gate anywhere: **refused at the publication point, origin unmoved**, with a
  publication control (decider deleted) proving the probe could see a publication. `subtree` delegates
  to `git push`, so the decider covers it regardless of the list.
* **`git for-each-repo … push` — reasoned, not driven.** It invokes `git push` per repository, so the
  same reasoning applies; nobody ran it.
* **`git svn dcommit` and `git lfs push` — UNVERIFIED.** Neither was driven to a publication. `svn` is
  **not installed on the build host**, so that row needs a host that has it. These are the two that
  matter most, because they do not take git's ref-push path: no `pre-push` hook runs for them, and
  S-4 reads git refs, so **the subcommand list is the only local layer that ever sees them**. That
  claim is itself a reading, and it is recorded as one.

**The remaining work is a host, not a decision.** Until someone drives those two, the honest statement
is "removed from the list on a reading of what they do", and the contract says so rather than
implying a measurement that was never taken.

---

### E87 — the instinct to EXCLUDE the foreign thing can delete the thing you were protecting

Round 12 refuted `Test-HaltAnswered` for the fifth time: a halt whose own face read
`1. **Status:** OPEN` was invisible, a *quoted neighbour's* `> **Status:** ANSWERED` stood alone, and
a set of one agreed with itself. The obvious cure is to stop collecting the neighbour — a blockquote
is, after all, another document speaking.

**That cure was written, and it was wrong in both directions at once.** A halt may write its OWN
status inside a blockquote, so the rule made the own face invisible — the exact defect it was written
to fix. And a quoted neighbour is very often *not* a blockquote: this build's own C-3c fixtures cite
one as plain prose. Driven against the instrument: `B/blockquote` — own marker OPEN in a quote,
neighbour ANSWERED in prose — returned **MET**. A false MET, the silent direction, *introduced by the
cure*, in the predicate whose failure lets a session end over an unanswered HALT.

**What was actually wrong was smaller than it looked.** The round-6 rule — collect EVERY marker,
answer only if they AGREE — was already sound against a quoted neighbour: neighbour ANSWERED plus own
OPEN is a disagreement, and disagreement resolves to NOT answered. Round 12's defect was purely that
the own marker was *invisible*. The correct fix was therefore only "make every shape visible", and
nothing else. Five cures on one clause, and the fifth nearly made it worse than the fourth.

**The rule.** When a predicate misreads because it collected the wrong thing, check whether the
existing resolution rule already handles the wrong thing before adding an exclusion. **An exclusion is
a new way to miss something**, and it will miss the case where the excluded shape is the one you
needed. Prefer widening what you can SEE over narrowing what you will LOOK AT.

---

### E88 — a perturbation whose anchor has drifted reports "still green", and that reads as coverage

A falsification harness edits one line and demands the suite redden. When the code moves, the anchor
stops matching — and a `.Replace()` that matches nothing changes nothing, the suite stays green, and
the direction is reported **STILL GREEN — THE MEMBERS DO NOT MEASURE THIS**. That is a false coverage
gap: it invites you to write a member that already exists, or to conclude a property is untestable.

This happened twice while implementing a later amendment — `Complete-EvidencePushGate` and the decider's
witness call were both rewritten, and both perturbations named lines that no longer existed. **Both
were caught only because the harness asserts its anchor matches EXACTLY ONCE and throws otherwise.**

**The rule.** A perturbation must fail loudly when it cannot apply. `if ($n -ne 1) { throw }` is not
defensive programming here, it is the difference between "this direction is unmeasured" and "my
harness is out of date" — two conclusions that look identical in the output and lead to opposite work.
Same family as [E80]: a perturbation must express the failure it names, and it must first *happen*.

---

### E89 — a character class where a hyphen becomes a range, and the tool goes blind fail-closed

The rebuilt status predicate assembled its separator class from code points:

```powershell
$sep = ':' + [char]0x2013 + [char]0x2014 + '-|'    # -> [:<en><em>-|]
```

The hyphen between the em dash and the pipe is a **range operator**, and `<em>` to `|` is a reverse
range: a .NET regex parse error, thrown at *runtime*, from inside the goal evaluator. Every HALT
artifact then produced `UNHANDLED ERROR`, the tool exited 9, and `halt_absent` read that as "not
answered" for all 24 of them.

**It failed CLOSED, which is why this is subtle rather than catastrophic** — and also why it could
have survived. A blanket "everything is open" is loud in a build with one open HALT and *silent* in a
build with none, where every artifact reading OPEN looks like nothing at all until someone asks why
the goal never clears.

**The rule.** In a character class, a literal `-` goes first, last, or escaped — and when the class is
BUILT rather than written, that is easy to lose sight of, because no single line shows you the result.
Print the assembled pattern once while developing it. More generally: a regex assembled from parts is
a program, and it needs the same "run it before believing it" discipline as any other program. This
one was caught by the falsification pairs, because the ANSWERED half of every row could not clear.

---

## EXHIBIT — why a string classifier cannot carry a publication guarantee

*Required verbatim by an operator ruling. This is the evidence for the rule, and the
rule is: **put the decision where the information is, keep the tripwire for the record, and bind the
truth at origin.***

### The three-round spelling ledger

Each row is a spelling that **beat the guard and really published a repository holding no gate at
all**, observed as a change in a bare origin's own ref — not as a hook's opinion.

| round | spellings that published | outcome |
|---|---|---|
| 9 | `$VAR` indirection · ANSI-C quoting `$'\x70ush'` · quoted `GIT_DIR` · `pushd` | cured |
| 10 | brace expansion · backslash-newline continuation · git **aliases** (inline `-c` and configured) · `Set-Location` / `sl` / `Push-Location` | cured |
| 11 | `g\it push` · `gi\t push` · `$G push` · `${G} push` · `echo … \| xargs git` · `& (Get-Command git).Source push` | **not curable in text** |

Round 10's cure was structural and it **worked**: the classifier was inverted so that a segment naming
git is a push *unless* its subcommand is a plain literal on a recognised non-push list. Round 11
re-drove all eighteen previously-refuted spellings and confirmed every one still denies.

Round 11 refuted the **other half**. The subcommand question — "given this is git, is this a push?" —
has an enumerable answer. The **executable** question — "does this command line invoke git?" — does
not: a variable, a substitution, a pipe into `xargs`, a call operator, a wrapper, a renamed binary.
The alias case settles it on its own: no reading of the command text can tell you that `zz` means
`push`.

### The false-consumption measurement

Tightening the classifier does not merely fail to close the hole; it **actively breaks the other half
of T-2**, and this was measured rather than argued:

> With a live, unconsumed push gate bound to the current tip, `git lfs env` was ALLOWED, **published
> nothing**, and PostToolUse **stamped the gate consumed**. `mission-gate.ps1 list` then read
> `CONSUMED`, and the operator's real push was DENIED.

A false audit record asserting a publication that never happened, and the operator locked out of the
one act they had authorized. At the same time, **19 of 28 legitimate non-publishing git subcommands
were being refused** — `prune`, `stage`, `subtree`, `lfs`, `bugreport` among them.

That is the tension in one paragraph: over-classification breaks consumption exactly as surely as
under-classification breaks blocking, and both halves were being asked of one mechanism reading one
string. **An earlier amendment had already conceded the guard is a TRIPWIRE, NOT A BOUNDARY. T-2 was written as
though it were a boundary.** The contract said two things about one mechanism.

### What replaced it

By the time a `pre-push` hook runs, every expansion has happened, and git hands it — on stdin — the
real local ref, the sha it is about to publish, the remote ref, and what the remote currently holds.
**Spelling is irrelevant there.** The three layers, as the contract amendment now states them:

* **TRIPWIRE** (PreToolUse) — refuses what it can read, records every attempt, and *claims nothing
  about what it cannot read*. That amendment's own words, now the contract's.
* **DECIDER** (`pre-push`) — refuses unauthorized publication at the point of publication.
* **DETECTOR** (S-4's origin binding) — origin holds only what a gate authorized, or the mismatch is
  the finding.

Measured after the change: `G=git; $G push origin main` and `echo push origin main | xargs git` are
both **refused, origin unmoved**. With the hook removed, both **published**. That pair is the claim.

### The gap the falsification found, recorded because the amendment nearly shipped without it

Breaking the origin-observation step left the entire suite **green**. A push the decider had
*witnessed* — record written — but which never reached origin (remote rejects it, the connection
drops, a concurrent update wins) would still have spent the operator's single-use authorization.
The amendment asserted that property; the instrument measured it nowhere. It is now T-13's
`a19 a WITNESSED push that never reached origin consumes NOTHING`, with a real publication of the
same sha as its positive half.

**A pre-push hook runs BEFORE the transfer.** That is the whole reason its witness is necessary but
not sufficient.

---

## REGISTRATION — the pre-push layer is a D4 down-payment, not D4

The A3 ladder is **SESSION-REPORTED < HOOK-CAPTURED < ORIGIN-SIDE ATTESTED**. The decider is a
hook-side control that runs on the machine doing the pushing. It governs publication **from this
repository, through git**. It does **not** govern:

* a push made from a clone elsewhere;
* a push made by another tool that speaks the wire protocol;
* anything done by someone with direct write access to the remote.

Those are origin-side concerns, which is exactly why **S-4's binding remains the detector** and why
**D4 origin-side attestation stays registered and unbuilt**. The top rung of the A3 ladder is now
*occupied* — something stands there — but it is not *filled*. Recording the distinction is the point:
a green install of this layer must not be read as D4 delivered, and LAM-INSTALL §5.4 says so on the
page an operator actually reads, in a paragraph headed *what this does NOT do*.

---

### E90 — "additive" is a claim about bytes, and it has to be checked like one

A ruling permits an operator to ADD a declaration to a gate artifact minted before that field
existed, as a dated annotation, provided it never alters an existing field. That permission is only
as good as the check behind it, because **"I only appended" is exactly what someone would say either
way** — and on this artifact the honest version and the damaging version look identical in a diff
summary.

**Three independent witnesses were taken, and each catches something the others do not:**

* **the first N bytes compared one at a time**, and their sha256 shown to equal the file's own
  pre-edit hash — this is the only check that proves *nothing above the annotation moved*;
* **a count of each immutable key**, asserting `created_at`, `authorized_by`, `binds`,
  `binds_sha256`, `revoked_at` and `authorized_tip_sha` occur **exactly once** — because an
  annotation that RESTATED a field would still be an append, would still leave the prefix intact,
  and would still produce a clean-looking diff, while leaving the artifact saying two things;
* **`git diff --stat` reading `5 insertions, 0 deletions`** — a witness from a different tool
  entirely, which is worth having precisely because it shares no code with the other two.

**AND THE LINE ENDINGS DECIDED THE METHOD.** The file was mixed — fourteen CRLF lines, three LF. An
editor normalising on save would have rewritten every line above the annotation, altering immutable
fields while the operator did nothing but paste. So the instruction was an `>>` append, not a paste,
and the predicted sha256 was computed by writing the predicted bytes to a scratch file and hashing it
**from disk** rather than from a string in memory.

**The rule.** When a rule permits an additive edit to a record, the permission comes with a
verification, and the verification must be able to tell *addition* from *alteration* — which a
recomputed hash alone cannot, because it only tells you the file changed. Prove the prefix. Count the
keys. Prefer an append command over a human paste when the file's own encoding could betray the
editor.

**And the side effect nobody planned for.** Annotating a *tracked* file dirtied the mission repo, and
a member with nothing to do with the ruling — S-5's clean-tree gate — refused. That is the machinery
working: an evidence-plane edit is a repository event, and the repository's own gates see it.

---

### E91 — a rule with no specification cannot be completed by patching, because nothing says when it is done

*Registered by operator ruling.*

The goal evaluator excluded a HALT artifact from `open_halts` when its status marker read ANSWERED.
**Five consecutive V-1 rounds refuted that check**, each on a spelling the previous cure had not
imagined:

| round | the spelling that was invisible | the cure |
|---|---|---|
| 5 | an indented example above the real marker | anchor at column 0 |
| 6 | a quoted neighbour's marker at column 0 | collect all markers, require agreement |
| 7 | `**Status**:` — colon outside the bold | widen the label pattern |
| 8 | twelve decorated forms; an unbalanced fence swallowing the own marker | drop the anchor, widen decoration |
| 12 | `1. **Status:** OPEN` — an ordered list item | scan lines, widen again |
| 13 | **13 of 26** — `**Current Status:**`, a markdown table, a heading with the value beneath | *— none attempted* |

Round 13's reader then found the thing five rounds had missed, and it was not a spelling:

> `grep -i answered` over the contract returns two hits, **neither about HALT artifacts**.

C-3 said a HALT artifact makes verdict HALT. Full stop. **There was no answered-exception in the
contract and there never had been.** Every cure had been inventing a little more of a specification
nobody wrote — which decorations count, which separators, whether a value may sit on the next line,
what happens when markers disagree — so "correct" could only ever mean *"handles the spellings we have
thought of so far"*. A fresh reader found a new one every single round, and would have kept finding
them, because **there was no condition under which the work could be finished.**

**The rule.** When a check is refuted repeatedly on new inputs of the same kind, stop widening it and
go read what it is supposed to implement. If the specification does not exist, **the missing
specification is the defect** — and writing it is the cure, not the next patch. A predicate can only be
as complete as the rule it implements; where there is no rule, "complete" has no meaning.

**What it cost and what it bought.** A contract amendment specified one canonical form and the implementation
went from **188 lines to 45**, with 21 rows falsified both ways and a regression over all 26 live
artifacts. Five rounds were spent discovering a sentence the contract needed from the start.

**The tell to look for**, since it is visible earlier than the fifth round: each cure was written
against *the examples that round had produced* rather than against a definition. If you cannot say
what would make a check finished, you are enumerating, not specifying.

---

### E92 — a guard clause that SKIPS a check is not a guard, it is an off switch

Three instances shipped in one session, all the same shape:

```powershell
if ($expected -and ($actual -cne $expected)) { return NOT-INSTALLED }
if ($OriginUrl -and ((canon $gateUrl) -cne (canon $OriginUrl))) { skip this gate }
if ($RemoteRef -and ($gateRef -cne $RemoteRef))                 { skip this gate }
```

Each reads as defensive. Each means **"when this value is missing, do not perform the check"** — and in
every case missing was reachable. Driven: with the shipped decider absent, the first one reported
`installed:true` over an allow-everything script; with both parameters empty the other two authorised a
publication on the sha alone, which is the behaviour the amendment had just replaced.

**The rule.** An operand you cannot compute is a REFUSAL, not a pass. Write it as its own branch with
its own reason — *"there is nothing to compare against, so I cannot say this is right"* — rather than
as a conjunct that silently disables the comparison. The two are one character apart in the source and
opposite in effect.

**Why it is so easy to write:** the guard is genuinely needed. Some callers legitimately have no URL —
the PreToolUse tripwire cannot know one, and says so. **The same function had two callers with
opposite requirements**, and the parameter was made optional for the caller that needed it optional
without asking what the other caller would get. When a check is shared, its degradation must be decided
per caller, not once at the definition.

---

### E93 — a member can exercise the right code path through a state that cannot occur

A cure made a stale in-flight witness disqualify its gate. The member minted a gate with the default
**60-minute** expiry and backdated its witness to **121 minutes** — a witness predating the gate it
belongs to. It passed. It proved the code path runs.

**It could not have proved the mechanism ever fires**, because a witness is written at PUSH time,
always after the gate's `created_at`, so `witness_age ≤ gate_age`. And with a 60-minute expiry against
a 120-minute witness bound, a gate whose witness is stale has **already expired** and is refused for
that reason instead. Under default settings the disqualification is unreachable. It becomes reachable
only above ~120 minutes of expiry — which an operator may well mint for a slow ceremony, so the cure
stands; the member did not.

**The rule.** After writing a member, ask whether the state it constructs can arise from the system's
own operation. A fixture assembled field-by-field can hold combinations the machinery would never
produce, and a member built on one tests the implementation rather than the situation. **Check the
constants against each other**, too: two independently-chosen numbers — an expiry and an age bound —
silently decided whether a whole branch was live, and neither cure nor member had compared them.

---

### E94 — the correct handling of a sub-case can INVERT when the resolution rule changes

The status predicate had always stripped fenced code blocks, except when the fence count was odd: an
unclosed fence was deliberately left unstripped, because under *"collect every marker and require
agreement"* over-collection could only produce more disagreement, and disagreement meant OPEN. Leaving
it in was the fail-closed choice, and the comment said so.

The canonical-form amendment changed the resolution rule to *"the first canonical line wins"*. **Under that rule
over-collection hands the verdict to whichever marker comes first** — including one inside an example.
The same code, unchanged, flipped from fail-closed to fail-open.

**The rule.** When you change how a set of candidates is RESOLVED, re-derive every decision that was
justified by the old resolution — especially the ones whose comments explain why they are safe. Those
comments are the record of an argument that may no longer hold, and they read as reassurance long
after they have stopped being true. Here the fix was to invert the sub-case: an unclosed fence now runs
to EOF and takes the rest with it, losing markers, which under the new rule means OPEN, which is loud.

---

### E95 — one defect can conceal the next, and fixing the first is what makes the second reachable

S-4's ref reader parsed **zero** refs on any multi-line remote, because git's output array was joined
with a space before an anchored per-line regex ever saw it. Fixing that made every ref visible for the
first time — and immediately exposed a second defect that had been unreachable: **every ordinary remote
advertises `HEAD`**, which no gate names, so the stray-ref predicate would have flagged it against any
correctly-configured origin.

The second defect was always present. It could not be observed while the first one returned nothing.

**The rule.** After curing a defect that suppressed information, **re-examine everything downstream of
it** — not because the cure was wrong, but because consumers of that data have never run on real input
before. Treat the first green run after such a fix as a first run, not a regression check. The related
trap is the one this same member demonstrated for four rounds: it had been green only because the one
origin it was ever pointed at advertises a single line, its `HEAD` symref dangling. **A member that can
only ever see the easy case cannot find the defect**, and the cure is a fixture that produces the hard
case, not a sharper eye.

---

### E96 — a class has LEVELS, and a cure aimed at one level walks back in at the next

The single-use property has now been broken three times, in the same function, by the same shape.

* **Round 6** — a gate was never stamped, so the same gate authorised the next push.
* **Round 12** — `Write-EvidencePushInFlight` witnessed `$authorized[0]` alone. `git push origin main
  b1` published BOTH refs, spent only the `main` gate, and the `b1` gate authorised a second real
  publication. Cured: **every ref in one push** is witnessed.
* **Round 14** — the witness was still ONE FILE per repository, written whole. Two *pushes* in one
  tool call both published; the second record erased the first; the pass that followed spent only
  the second gate; the first later authorised a second real publication. Same sentence, one level up.

The round-12 cure sits under a comment that ends, in its own words, *"E56 in code written while
quoting E56"* — and that cure was itself an instance fix. E56 says a finding names an instance and a
cure must name the class. What round 14 adds is that **"the class" is not one thing**: refs within a
push, pushes within a tool call, tool calls within a session, sessions within a machine. A cure that
enumerates one level reads as complete, passes review, and leaves the level above untouched.

**The rule.** When you cure a "first of many" defect, write down the aggregation level you just
closed and name the one above it explicitly — either close it too, or record why it cannot occur. A
cure that cannot say which level it stopped at has not named the class; it has named a bigger
instance.

---

### E97 — a comment asserting compliance is where non-compliance hides

An operator ruling required consumption to become **conditional on an actual ref advance**. What
shipped computed the flag, wrote it into `consumed_basis` as prose, and **read it in no branch** —
consumption was byte-identical whether it was true or false. Directly above those lines:

> `remote_sha_before` IS CONSULTED, not merely stored (E85). A field a record carries but nothing
> reads is a claim about a check that does not happen; the choice is to wire it or drop it, and here
> it earns its place by distinguishing a real ADVANCE from a ref that already held the authorized sha.

The comment cites E85 and then commits E85, in the next three lines. It survived three readings —
including two of mine — **because it answered the question a reader would have asked.** The reader
checks whether the concern was considered; the comment says it was; the reader moves on. An
uncommented version of the same code would have been caught sooner.

The same round produced a second instance in prose: LAM-INSTALL carried a note saying a sentence
eighteen lines above *"previously called all of them"* guard rules — asserting, in the past tense, a
correction that `git diff` shows was never made.

**The rule.** Treat a comment that asserts a property as a **claim to be checked, not evidence that
it holds** — and weight it *higher* for suspicion than uncommented code, not lower. A claim in the
past tense ("this was corrected", "this is now consulted") is a claim about a diff, and a diff can be
read. This is T-2s pointed inward: the sentence needs the driven result as much as the contract does.

---

### E98 — the ORDER of two fail-closed checks decides which of them fails closed

`Complete-EvidencePushGate` tested the witness's age **before** asking the declared origin what it
held. Both checks are individually conservative. In that order they produced a denial of service on
the operator's own approved publication:

* `git push --dry-run` writes an in-flight witness, and no pre-push hook can tell a dry run from a
  publication;
* an out-of-session operator push fires no PostToolUse at all — **S-4/E22, the contract's own
  canonical publication path**;
* so past the age bound, the next hook-visible command disqualified the gate for a publication that
  had never happened, stamping the artifact *"the declared origin could not be asked to confirm it"* —
  a sentence written by a branch that had made no such call, and which WP-1 drove false with an origin
  answering `ls-remote` immediately before and after.

Reordered so the age bound governs **only** the unconfirmable branch, the earlier cure is not lost but
strengthened: a stale witness for a push that DID land now *consumes* on origin's own answer instead
of disqualifying on a guess.

**The rule.** "Fail closed" is a property of a *decision*, not of a *check*. When two conservative
checks compose, ask which one runs first and against whom each one is conservative — a check that
fires before the authoritative source is consulted is not being careful, it is guessing early. Put
the question that can be *answered* before the question that can only be *assumed*.

---

### E99 — machinery that is written but never invoked is the same defect as a field nobody reads

`Test-EvidencePushIsDryRun` was written in round 3: correct, standalone-token matching only,
documented at length about which direction it must err in and why — and **called from nowhere** for
eleven rounds. `Complete-EvidencePushGate` carried an `-OriginTip` parameter its only caller passed
`$null` and no line read. E85 names the field version of this; the callable version is worse in one
specific way: **it looks like the work was done.** A reader searching for "do we handle dry runs?"
finds the function, reads its careful docblock, and stops.

**The rule.** E85 extends to functions and parameters. Before shipping a predicate, grep for its own
name and count the call sites; a definition plus zero callers is a defect, not a utility awaiting a
user. When a reader can find a mechanism by name, its existence becomes an answer to a question — so
an uncalled one is a false answer sitting in the codebase waiting to be believed.

---

### E100 — a control that fails SILENT on an unexpected input shape has no failure mode at all

One JSON shape — `tool_response: {}`, an empty object — killed the entire push-gate consumption path.
`$toolResp.PSObject.Properties.Name` throws on a zero-property object; the hook's outer `catch` wrote
one line to a log file and `exit 0`. Isolated by varying that single field:

| `tool_response` | consumption |
|---|---|
| `{"stdout":"ok","stderr":""}` | **ran** |
| `{}` | **DEAD** |
| absent | ran |
| `null` | ran |
| `""` | ran |

Absent, null and empty-string were all handled. The one unhandled case is the one a tool producing no
output would most naturally emit — and E5-i already records that this harness varies payload shape.
The consequence was not an error: **rc 0, empty stderr, a green run, and the single-use property
quietly not working.**

**The rule.** A guarantee-bearing control needs its failure mode designed, not inherited. A broad
`catch` that logs and exits 0 converts every future defect above it into silent non-enforcement. Ask
of any control: *if the code before this throws, does the guarantee fail loud or just stop?* And when
you find one instance, remember the trigger is the shallow half — the class is that an unrelated
failure can disable an unrelated guarantee.

---

### E101 — PowerShell 5.1: string concatenation inside an array literal in ARGUMENT position silently splits

```powershell
Gx $repo @('config', 'url.' + $decoy + '.insteadOf', $value)
```

yields **five** elements — `'config'`, `'url.'`, `<decoy>`, `'.insteadOf'`, `<value>` — not three. No
error, no warning; git answered `error: no action specified` (rc 129) and the member went red for a
reason with nothing to do with the property under test. Wrapping the expression in parentheses,
`('url.' + $decoy + '.insteadOf')`, restores the intended arity, which is why the same line typed
interactively with parentheses had worked minutes earlier.

Same family as the `-LiteralPath`-with-a-glob that silently shipped two dispatches with empty evidence
streams: **PowerShell's failure direction for argument construction is a wrong-sized array, not an
exception.**

**The rule.** Build any non-trivial argument in a named variable first, then assert its element count
before the call. `if ($argv.Count -ne 3) { throw }` is one line and it converts a silent
misconstruction into a loud one.

---

### E102 — a diagnostic that ASSERTS an outcome cannot report one, and a fixture the real system never emits cannot test it

Two harness defects in one round, both of which made harness faults read as product faults.

**The asserting diagnostic.** A check helper printed its `Detail` string identically whether the check
passed or failed, and the string I wrote said *"a bare ls-remote of the DECLARED url returned the decoy
sha … — the defect WP-6 drove."* When the member went red, the report still stated the defect as
observed. Rewriting the detail to print *measured* values — the config set's exit code, what git
resolved the url to, the first line of output — surfaced the real cause immediately (`rc=129`).
**This is T-2s committed inside the harness written to falsify T-2s violations.**

**The impossible fixture.** A PostToolUse payload built with `tool_response=@{}` produced a shape the
real harness does not emit, killed the hook, and presented as "the cure does not work". The control
that settled it was not a sharper eye but a *discriminating* arm: a state where the block's execution
and non-execution give different answers. `lam-gate-class.ps1`'s own docblock had already recorded
this shape — a hand-rolled gate that omits a field "takes the other branch and passes".

**The rule.** A test's diagnostics are output, not narration: print what was measured, never what was
expected to happen, and make them differ between pass and fail. And before believing a red member,
drive a control that proves the mechanism under test *ran at all* — an unexecuted block and a
malfunctioning one look identical from the outside.

---

### E103 — a member's EXPECTATION goes stale when a ruling changes, and the cure is to split it, not soften it

After the reordering in E98, instrument WP-4's row `an expired witness DISQUALIFIES its gate` went
red. The code was right and the row was wrong: it drove a **reachable** origin with nothing published
and expected disqualification, which is the pre-ruling semantics.

This is the one moment a green suite is genuinely dangerous, because the cheapest repair — relax the
row — would have deleted the evidence for a property the contract still requires. What the row was
protecting (round 13's cure: an unsettleable witness must not leave a gate usable) is real; it was
simply being driven in the wrong state.

The member was **split so that one field varies** — whether the declared origin can be asked — and now
asserts both ruled properties: *reachable and never published* leaves the gate usable; *unreachable
and stale* disqualifies it. Two rows where there was one, and neither weakened.

**The rule.** When a ruling changes behaviour and a member goes red, decide explicitly whether the
member encodes the OLD rule or catches a real regression — and say which, in the commit. If it
encodes the old rule, re-drive it in the state the new rule governs and keep the original assertion
alive somewhere. Deleting a row because a ruling moved is how a suite forgets what it was for.

---

### E104 — when a better mechanism already answers the question, the cure is DELETION, not a guard

Round 8 added `Test-EvidencePushIsDryRun` so a dry run could not spend a gate. It was written
carefully — standalone tokens only, a docblock explaining which direction it must err in — and then
**called from nowhere for eleven rounds.** Round 14 read E99 ("dead code is wired or dropped"), chose
*wire*, and the first code ever to call it failed in precisely the direction its own docblock had
warned about:

> *"Wrongly calling a REAL push a dry run leaves the gate open for a second publication, which is the
> single-use property gone."*

Round 15 drove exactly that: a `--dry-run` anywhere in a tool call cleared **every** accumulated
witness, and a stranded gate then authorized a second real publication.

**The predicate was not broken. It was OBSOLETE.** A later amendment had, in the meantime, made every
witness settle against what the declared origin actually holds — and a dry run publishes nothing, so
origin does not hold the sha, so nothing is consumed. The property the round-8 predicate existed to
provide was already guaranteed by a strictly better mechanism, one that does not depend on reading
command text at all.

**The rule.** When E99 offers "wire it or drop it", the choice is not stylistic. Ask first whether
something else now answers the same question **better** — from git's own facts rather than from a
string, at a layer that cannot be spelled around. If so, wiring the old answer adds a second, weaker
authority for one decision, and two authorities for one decision is how both halves of this
lifecycle drifted apart four times. Delete, and leave a comment saying what superseded it, so the
next reader does not re-add it.

---

### E105 — refuse the ambiguity; do not resolve it and hope

Two round-15 cures took the same shape, and it is the opposite of what this build had been doing.

* A wrapper naming its decider with a **relative** `-File`: git resolves that against the working
  tree the push is issued from, this build's runner **creates worktrees**, and nothing in the wrapper
  text says which tree that will be. Round 14 resolved it against the root it happened to hold, under
  a comment claiming it resolved "the way git will resolve it". A real push from a worktree published.
* A gate minted with a **drive-relative** `-Binds` (`C:name`): anchored to the current directory *of
  drive C*, which is per-process state, so no root the tool holds can resolve it to a determinate
  file. It bound whatever sat in the operator's shell directory, permanently, on an artifact the operator's ruling
  rules immutable.

In both cases the honest answer is that the input **cannot be resolved**, and a checker that picks an
interpretation and returns a verdict is guessing while wearing the costume of a decision.

**The rule.** When an input's meaning depends on state the code does not hold, refuse it by name and
say what the caller should pass instead. A refusal removes the whole class; a better guess removes one
member and leaves the next reader believing the class is closed. And check *how* it refuses: the first
draft of the `-Binds` cure joined an unjoinable path and **threw**, exiting 9 — fail-closed by
accident. "It crashed" and "it refused" are different outcomes and only one of them tells an operator
anything.

---

### E106 — a predicate that ALMOST means what you need is worse than one that plainly does not

`[IO.Path]::IsPathRooted` sounds like "is this an absolute path". It is not. It returns **True** for
`C:e.txt` (the current directory of drive C) and for `\dir\file` (the current drive's root) — both
anchored to per-process state. Two separate cures in this build were built on it, and both let
exactly the ambiguous shapes through while reading, at the call site, as though they had handled them.

A predicate that is plainly wrong gets noticed. One that is right for every case the author tried is
invisible: the author reaches for the standard-library name that matches their sentence, the tests
they write use the shapes they had in hand, and the gap is only in the cases nobody thought to type.

.NET Framework has no `IsPathFullyQualified` (it arrived in .NET Core 2.1), which is precisely why
the almost-right name was reached for.

**The rule.** When a check carries an authorization, do not accept a library predicate on the strength
of its NAME. Write down the property in a sentence, then drive the predicate against the shapes that
sit just outside it — and print the library's answer beside yours in the member's output, so the
divergence is on the record rather than in a commit message.

---

### E107 — search for the SIBLING before the edit, and record that you did

Every round-14 cure was correct at the site it changed, and round 15 refuted four of them because the
class had another site: a second copy of the origin read, a fourth copy of the gate-state predicate, a
different resolution root, a whole-file *delete* mirroring the whole-file *write* that had just been
cured.

Round 15 inverted the order — enumerate the sites, then edit — and it paid immediately and cheaply:

* deleting the dry-run predicate would have left `Get-EvidencePushSegment` dead (one caller, itself);
* `Clear-EvidencePushInFlight`'s body was duplicated inside `Set-...Records`, so removing its only
  other caller would have made the *copy* the sole survivor;
* the origin read had two implementations and only one had been hardened.

None of that is clever. It is `grep`, before rather than after.

**The rule.** Before shipping a cure, enumerate every site of the shape you are curing and write the
list into the commit — including "none", which is a result and not an assumption. A cure that cannot
name the sites it did *not* change has not named the class.

---

### E108 — the control that must pass regardless is what tells you the HARNESS is broken

Three harness defects in one round were each exposed by the same thing: a control that had nothing to
do with the change under test, and therefore had to pass whatever the change did.

* A stray-detection member reported "no strays" for an ordinary unauthorized branch — impossible if
  the loop ran at all — which revealed the scriptblock was accumulating into a child scope, not that
  the narrowing was wrong.
* A push-gate member reported the settle pass never ran, which revealed the fixture was emitting a
  payload shape the real harness never emits.
* A perturbation "did not apply" because gate artifacts are CRLF and the pattern ended `[ \t]*$` —
  caught only because the member ASSERTED its own perturbation had landed.

Without those, all three read as product defects, and two of them would have been reported as such.

**The rule.** Every harness needs at least one member whose result is independent of the change being
tested, and every perturbation needs an assertion that it actually applied. A red result is a claim
about the product only *after* something has shown the mechanism executed at all — an unexecuted block
and a broken one are indistinguishable from outside.

---

### E109 — a suite that does not cover the most recently changed thing is measuring the past

Two changes to what a push gate MEANS — which URL it declares, which file it binds — shipped across
two rounds with **no instrument member at all**. The suite was 98/98 the entire time. An independent
reader found it by grepping `tests/` for the field names and getting nothing.

The suite was not weak in general; it was strongest exactly where the code had been stable longest,
because every previous refutation had added a member there. Coverage accretes around old defects and
thins around new behaviour, which is the reverse of where risk lives.

**The rule.** A change to a trust-bearing artifact's MEANING ships with its member, in the same
commit. And when reviewing a suite, do not ask "is it green" — ask which files moved most recently and
grep the tests for their new field names. A green run over the previous version of the code is not
evidence about this one.

---

### E110 — an isolation that RELOCATES a surface is worse than the one it replaced

Round 14 hardened the origin read against `.git/config` by pointing `HOME`, `USERPROFILE` and
`XDG_CONFIG_HOME` at the temp root and calling that environment neutral. **Those variables are git's
global-config search paths.** A file at `%TEMP%\.gitconfig` therefore became live global config — in a
world-writable directory the instrument itself writes into — and `GIT_CONFIG_NOSYSTEM` closed only
the system layer, so nothing closed the layer the cure had just created.

Driven with mission, gate and origin byte-identical between runs: nothing planted → S-4 FAIL with two
strays; **one file planted → S-4 PASS, "stray refs: (none)"** — both runs printing *"DECLARED origin
(from the gate, never .git/config)"*.

The original defect needed write access to the gated repository. The replacement needed **a temp
file**. The cure enlarged the attack surface while reading, at every call site, as a hardening.

**The rule.** When a cure moves a dependency rather than removing it, name the new location and ask
who can write there. "Neutral" is not a property of a directory; it is a claim about permissions, and
it has to be checked. A hardening that cannot say what it closed has probably only moved it.

---

### E111 — name the mechanism the tool documents; do not guess at how it behaves

Three defects in one round, one shape:

| the guess | what it actually does | the instruction that replaced it |
|---|---|---|
| move `HOME` to isolate config | HOME *is* a config search path | `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM` |
| resolve git's relative `--git-path hooks` myself | git resolves against a different tree | `--path-format=absolute` |
| `IsPathRooted` for "is this absolute" | true for `C:name` and `\dir\f` | an explicit fully-qualified test |

Each guess was *about* the tool: where git looks, what git will resolve against, what "rooted" means.
Each was replaced by something the tool **obeys** rather than something it might happen to do. The
resolution moves from my model of git into git.

**The rule.** Before writing code that anticipates a tool's behaviour, look for the flag or variable
that makes the behaviour explicit. If one exists, the anticipating version is a defect waiting for the
case you did not imagine — and the tool's own documentation is a cheaper oracle than a round of
validation.

---

### E112 — validate at the INPUT, not at each site that can throw

`mission-gate`'s `-Binds` reached `GetFullPath` and threw on paths Windows forbids, which the script
trap converted into `UNHANDLED ERROR` and exit 9 — fail-closed, but a crash rather than a refusal,
which tells an operator nothing.

The first fix wrapped the join in `try/catch`. It caught `*` and `?` and **missed `<` and `|`**,
because an earlier path call throws on those first. Chasing which call throws is endless: there are as
many sites as there are path operations.

The question was never "which call fails" but **"can this string name one file at all"** — and that
is answerable before anything tries to resolve it. A gate binds one file by hash, so a wildcard cannot
be bound even in principle: it names a set.

**The rule.** When an input can be rejected on its own terms, reject it there. A guard placed at a
throw site protects that site; a guard placed at the input protects every site, including the ones
added later — and it produces one refusal instead of whichever exception happened to fire first.

---

### E113 — a disclosed duplication buys nothing unless a TEST detects the drift

Two implementations of the origin read were kept deliberately, with a comment explaining that the
duplication was disclosed so divergence would be visible. Round 16 measured what that bought:
**nothing.** Both copies carried the identical defect — it was driven in each — so there was no
divergence to notice, and the same cure then had to be applied twice, which is exactly the doubled
repair surface the disclosure was meant to justify avoiding.

The file also said both things at once: one comment declared *"ONE DEFINITION"* while another twenty
lines below admitted it was the second. Both sentences shipped.

The property that makes duplication tolerable is not disclosure. It is a member that asks both
implementations the same question and requires the same answer — which now exists, and would have
gone red the moment either was hardened alone.

**The rule.** If you keep a second implementation, ship the test that compares them in the same
change. A comment describing a risk does not manage the risk; it only means nobody can say they were
not told. And never let a file assert singularity it does not have — the next reader believes the
comment, not the code.

---

### E114 — "removes the whole class" is a claim, and it gets checked like any other

The round-15 commit stated that refusing an unresolvable decider path *"removes the whole class rather
than one of its members."* Round 16 measured it: it removed one member. The **hooks directory**
carried the identical ambiguity — a relative `core.hooksPath` resolved against the mission root while
git resolves it against the tree the push is issued from — one function above the cure, in a sibling
variable, driven to a real ungated publication.

E107 asks for a sibling search before the edit. It was done, and it still missed this, because the
search was for siblings of the **`-File` resolution** rather than of the **ambiguity class**: *a path
git hands us that we resolve ourselves*. The wrong noun makes the search vacuous while feeling
thorough.

**The rule.** Write the class as a sentence about the *shape*, not about the site, before searching —
and put that sentence in the commit so the next reader can judge whether the search was for the right
thing. A class claim in a commit message is a testable assertion; if you cannot name the sibling sites
you checked and ruled out, you have not made one.

---

### E115 — a cure that moves what a check LOOKS AT must re-drive that the check can still FAIL

**Round 17's finding, and four validators reached it separately on four packages with no contact
between them.** Every round-16 cure below was correct about its target and left the measuring half
inert, so the result looked green — and in each case the green was produced by the *same mechanism*
that produced the control, which means the check had no discriminating power and could never go red.

| package | the cure | what was left inert |
|---|---|---|
| a WP-2 and a WP-1 finding | `--path-format=absolute` | the **anchor** — git answered authoritatively about the wrong tree |
| WP-5 | step 7's target moved to a protected path | the **probe** — the dot sat where it could not change the answer |
| WP-6 | S-4d added, asserting two readers agree | the **fixture** — no configuration existed to steer either |
| WP-4 (its own discarded harnesses) | a 20-row denial battery | the **payload** — a `$Input` parameter name meant every case arrived empty |

WP-4 stated it generally, from a harness it threw away rather than from the product: *a battery whose
only controls expect ALLOW cannot distinguish "nothing is protected" from "the harness sent nothing."*

**Why it is worse than the defect it replaces.** The defect was findable. The all-clear is **cited** —
step 7 told the operator that its unanimous DENY meant the exposure was gone, on the exact question
the step exists to answer. A green with no failing arm does not report the absence of a problem; it
reports the absence of a measurement, and it does so in the voice of a result.

**The rule.** When a cure changes *what* a check examines, drive **both arms** — the one that must
pass and the one that must fail — and put the fact that they **differed** in the verdict, not in the
commit message. E78 says an implication that passes vacuously belongs in the verdict; this is E78 one
level up, about the probe rather than the predicate. Every member written for round 17 carries the
assertion in its own body: R-26 fails unless its rows split, K-5 fails if it parses fewer rows than
the tables carry, S-4d fails unless an unisolated read is *proved* steerable first, T-14 and T-15 fail
unless both answers appear.

**WP-4 is the counter-example that makes this a class and not a mood.** Its round-16 ARM-2 cure *did*
carry a non-vacuity control, and a five-build matrix proved it load-bearing: replacing the
disqualification with a *revocation* leaves `.ok = $false`, so the row passes for the wrong reason —
and the control row catches it. Under the old single-assertion form **both B2 and B4 would have
reported green**. The discipline works when applied. It was simply not applied four times.

---

### E116 — a blacklist of a tool's configuration surfaces cannot be completed by inspection

Three consecutive rounds closed one named route into the origin read and were refuted by the next
filename over: `.git/config` (round 15), `%TEMP%\.gitconfig` (round 16, E110), `%TEMP%\.git\config`
(round 17, CRITICAL, found independently by WP-1 and WP-6). Each cure was correct about the route it
named. Two validators then listed four *more* live routes between them — `GIT_CONFIG_COUNT` with its
`KEY_n`/`VALUE_n`, `GIT_CONFIG_PARAMETERS`, `GIT_DIR` — which is the evidence that enumeration was
never going to terminate.

**The rule.** Where the surface is *"anything the environment can say to this tool"*, eliminate the
surface rather than enumerate it: clear the whole namespace and set back only what is required. A new
route the tool adds next year is then closed by construction rather than by the next round finding
it. And falsify it the way a whitelist can be falsified and a blacklist cannot — plant a hostile value
in **every named route plus one nobody named**, and require the answer to be unchanged.

State plainly what is still not defended, in the same breath. `PATH` is not: anyone who can set the
environment can replace the executable, and no amount of variable hygiene survives that. The boundary
here is config injection and repository discovery, which is what the reachable route actually needed.

---

### E117 — the class you name in the cure is the class the next sweep will search for

E107 asks for a sibling search; E114 records that the search can be done and still miss, because it
was aimed at the wrong noun. Round 17 shows the third turn of that screw: the class E114 wrote down —
*a path git hands us that we resolve ourselves* — is now **empty**, so a sweep against it comes back
clean, while the live defect sits one axis over as *a question about the worker's tree, asked about
the mission root*. WP-2 flagged this without being asked, as a finding in its own right.

**The rule.** A class written into an erratum is not a description of a bug that has been fixed; it is
a **search string future rounds will run**. Choose the axis the defect actually varies along, and when
a cure empties a class, say what the class was so the next reader can judge whether it was the right
one — an empty class and a wrong class produce identical sweeps.

---

### E118 — restoring a file is not a neutral act on a build whose evidence is bytes

`git checkout -- <file>` with `core.autocrlf=true` rewrote a pure-LF working file to CRLF — 209756
bytes became 212774 — while `git diff` reported the file **unchanged**, because git normalises on
comparison. On this build that is a measurement moving under a check that says nothing moved: the
section-1 tables record byte counts and hashes, validator subject-integrity verification hashes
working-tree files between capture and verify, and `git cat-file -s HEAD:<path>` returns the LF size.
A CRLF working tree disagrees with HEAD, with the table, and with every prior measurement, and it
would read as a validator having moved a subject.

**The rule.** After any restore that touches a measured file — `checkout --`, `restore`, `stash pop`,
a fresh clone — byte-audit before measuring and before an authoritative suite run. Prefer restoring
from a hash-verified copy taken before the edit over asking git for one.

---

### E119 — a differential check compares outputs, and a divergence in the mechanism behind them is invisible until the input demands it

The origin reader is deliberately duplicated: the library's `Get-EvidenceRemoteRefs` and the
instrument's `Read-OriginRefs`, so a defect in either shows up as disagreement with the other and
with ground truth read a third way. That is S-4d's whole purpose. Round 18's transport cure — clear
the `GIT_*` namespace, restore twelve transport names by name — landed in the **library alone**, and
S-4d passed every round afterwards.

It could not have done otherwise. S-4d compares **ref sets**, and both readers returned identical,
correct refs, because the fixture origin is a local bare repository that needs no transport variable
and no credential to read. The divergence was in isolation **shape**, which only becomes an output
difference on an origin that demands the thing that diverged. Driven against the declared https
origin, the two answers separate immediately: the reader without the carry-forward answers `notok`,
the reader with it answers `refs=5`, matching bare git. One input the check never used, and the
duplication it was policing had been broken for two rounds.

The prose half is worse than the code half. Round 17 wrote a shared explanatory block into **both**
copies; round 18 fixed one. The instrument then carried a paragraph stating that this reader
"clears the CONFIG namespace and restores twelve transport names by name" directly above a function
that did neither — so the file's own documentation had become a false claim about the file, and a
reader checking the cure by reading would have confirmed it.

**The rule.** When a differential check polices a duplication, the question is not "do the copies
agree" but **"what input would make them disagree, and is that input in the check?"** An agreeing
pair on an undemanding input is not evidence of sameness. E113 asked for a test that detects drift;
this is the sharper form — a test whose **input can distinguish the copies**. And a comment
duplicated across copies must be treated as code for this purpose: it drifts the same way, silently,
and it drifts into assertion rather than into behaviour.

---

### E120 — a filename is not a unique key, and the substitution that assumes it is will retarget silently

> **THE MEASURED SIZE OF THE CLASS, added at closure (RES-28).** This erratum was minted from one row.
> Swept, `LAM-INSTALL.md` carries fifteen section-1 rows over ten distinct filenames, and **five of the
> ten appear in BOTH tables** — `evidence-guard-pretooluse.ps1` (41 / 53), `evidence-post-tool-use.ps1`
> (42 / 54), `evidence-pre-compact.ps1` (44 / 56), `evidence-stop-finalize.ps1` (43 / 55),
> `lib/evidence-common.ps1` (47 / 60) — sealed line first, next-gen line second. A pattern-keyed
> re-derivation therefore has an even chance of rewriting a SEALED row on any of five filenames. The
> rule below does not change; the count is what makes a reader take it literally.

`LAM-INSTALL.md` carries **two** byte tables — the sealed A1 set and the next generation — and both
contain a row named `lib/evidence-common.ps1`. Re-deriving the next-generation row after a library
edit, a `re.sub(..., count=1)` matched the **first** occurrence and overwrote the SEALED row, turning
the sealed anchor `80479 / ec27ab3a33639b95` into the next-generation file's measurements. The guard
that should have caught it did not exist: `assert s2 != s` passes just as happily when the wrong row
changed, and the script printed "row re-derived".

It was caught only because the line printed back afterwards still showed the old value — the one
symptom of having edited a different row than intended — and it was one commit away from recording a
seal that matched no file.

**The rule.** When a document repeats a key across sections, address the row by **position or by
section**, never by a pattern that the whole file can satisfy. And verify a re-derived measurement
**against the file it claims to describe** rather than against the fact that something changed: two
lines of `open().read()` and a hash comparison distinguish "the right row now matches its file" from
"a row moved". Both rows here were checked against both files before the commit, which is the only
reason the seal is known intact rather than assumed intact.

---

## 3. ADRs as built (LM2-ADR-036 … LM2-ADR-040)

v2.3's highest ADR is LM2-ADR-035. These five are what this build establishes, stated as built rather
than as intended.

### LM2-ADR-036 — Memory hygiene is *separation*, not a disable, and the residual travels on the artifact
**Supersedes the mechanism of LM2-ADR-032; its intent stands verbatim.** No settings key disables auto
memory on CLI 2.1.241 (E12), and `--bare` is unusable because it also removes hooks. Each role
settings template therefore carries four checkable fields: `intent`, `declared_mechanism`, the
**`separation_obtained`** (worktree-level directory separation for a worker; fresh-identity session
separation for a validator; **none at the memory layer** for the orchestrator, stated rather than
left blank), and a **`disable_status`** naming the disable unobtainable on 2.1.241 and citing E12.
**A claim with no working detector is an overclaim, so the artifact carries the residual and the
instrument checks the fields rather than the prose.**

### LM2-ADR-037 — PASS-DIB: a transitional verdict class with an expiry built into its definition
A verify run whose refusing subjects are exactly a subset of
`{suite.passed, suite.failed, suite.skipped}`, **each with outcome `ABSENT` and verify's own
increment-boundary residual on its own subject**, and every other subject `MATCHED` or
`NOT_APPLICABLE`. Any other refusing subject, any `DIVERGED`, or any crash is still a refusal.
**Defined once and consumed by every verdict consumer in the toolchain, never restated.** It
dissolves without an edit when verify increment 2 lands: the subjects begin reporting `MATCHED` and
take the PASS branch. **The per-subject reading is the load-bearing part** — the first
implementation tested the residual as one global substring over the report and admitted a suite
subject refusing with `DIVERGED` (recorded 12, derived 4), which is precisely the mismatch LM2-ADR-022
exists to catch.

### LM2-ADR-038 — Advance admission: ancestry, declared cleanliness, and ledger provenance, jointly
A tree that has legitimately moved on is admitted **iff all three** hold: **(a) ancestry**
(`git merge-base --is-ancestor`); **(b) cleanliness** against **the mission's own declared
`admitted_porcelain`** (never another mission's shape — E21); **(c) provenance** — every commit in
the range appears in the orchestrator's commit ledger. **A commit in range absent from the ledger is
FOREIGN and refuses**, which is what stops committed foreign content from riding ancestry into
admission (E16). Admission covers **exactly** `ANCHOR/head_sha` and `ANCHOR/porcelain`, and when
used it is recorded **verbatim in the anchors** — declared patterns, the entries each tolerated, and
the declaration's source path and sha256. **A declaration may never act silently.**

### LM2-ADR-039 — Ratification binds to an artifact the ratified party cannot write
A supersession marker is honoured **iff** an unrevoked `supersession` gate carries a `binds_sha256`
equal to the marker's **re-derived** hash. Agents cannot mint one (T-3). **No gate, no skip** —
exit 2 naming the unratified marker. Hash-binding rather than filename-binding is what makes it
non-forgeable. **Lifecycle is per kind, and conflating them was a defect:** a `push` gate must
expire and be single-use, because a standing publish capability is what LM2-ADR-033 abolishes; a
`supersession` gate is **not a capability** but a recorded ruling, so it neither expires nor is
consumed, and **revocation** is the mechanism that withdraws it. **Gates additionally carry a
`gate_class`** — `build-authorization` (push, dispatch) or `governance` (supersession,
amendment-material, witness-attested) — because an attestation about irreversible acts must not
count a human adjudicating a HALT as one, and must say so on its face rather than by omission.
**The attestation counts HUMAN build-authorization acts**, and its two exclusion rules are shaped
alike: a **gate** is excluded by its **declared class**, and a **prompt-register line** is excluded
**iff it carries a written classification bound to a disclosure artifact**. Neither exclusion may be
silent — the attestation **enumerates every gate and every prompt line with why it counted or did
not**, because an exclusion a reader cannot see is a hole. **The registers are not restartable**,
and an unclassified operator-kind line still fails. **The rule is fixed before the number is
recomputed**, never fitted to it, which is the only thing that stops an exclusion list from becoming
a way to make any number come out right.

### LM2-ADR-040 — The runner is a PowerShell program over the headless CLI, and the boundary is owned
`mission-dispatch.ps1` composes `claude -p` with `--worktree` (LM2-ADR-026), a routed model (LM2-ADR-031),
a role settings file, the dispatch artifact as the **entire** prompt, and `/goal` from the dispatch
(LM2-ADR-025). It owns the dispatch boundary explicitly: it writes `OWNER` and `DISPATCH-END`, so the
manifest finalizes on the marker rather than on `Stop`, and a pre-marker continuation derives
`OPEN`. It validates the handoff against the closed schema, populates the anchors, and checks every
git return code. **Two ledgers make provenance checkable rather than assumed**: one line per spawn
and one per commit, written at the event.

**A CEREMONY-CLASS OPERATION IS A DISPATCH** (ratified design decision).
It is authored as a `close`-kind artifact and run through the runner, and the route is **required**,
for a reason that is not stylistic: a ceremony must run where the evidence hooks can observe it,
which means inside a session whose project is the mission repo — and **every prompt to such a
session records as a human act unless it carries the runner's `LAM_DISPATCH` marker**. Prompting one
by hand manufactures an operator act and breaks the attestation by construction. Dispatching it does
not, *and* the runner then owns the boundary, consolidates the evidence and validates the handoff. A
ceremony run outside the runner is a ceremony whose evidence nothing is responsible for.

**Revisit trigger, registered not built:** the Agent SDK runner branch (LM2-ADR-023/024/025). Nothing here depends on the runner being PowerShell except the
fact that a PowerShell script cannot call an agent tool — which is why R-4's wake signal falls back
to a file rather than `SendMessage`, and why that substitution is disclosed rather than hidden.

---

## 4. The six-gate refusal table — **VERBATIM, per operator ruling**

> `mission-close-milestone.ps1` refuses at **six** independent gates, each before any mutation:
>
> | # | gate | requires | smoke mission has |
> |---|---|---|---|
> | 1 | A-130 `Assert-MissionState` | `state: Reworking` | `state: Created` |
> | 2 | milestone status (`:79`) | `status: pending` inside the `M-1` block | the M-1 block has **no `status` field** |
> | 3 | roster (`:80-82`) | `contract_assertion_ids: [...]` | the spec says `assertions: [...]` |
> | 4 | A-127 (`:41`) | `.mission/validator-results/manifest.json` | individual result YAMLs, **no manifest** |
> | 5 | green gate | a green-gate manifest for suite `product` | `tools/mission-cli/config/` holds only `expected-failures.yaml` |
> | 6 | A-126 clean tree | clean but for the amendment | `?? .mission/gates/`, `?? .mission/evidence/`, `?? .claude/worktrees/` |

**Why it is here.** The table is the evidence for E23 and for the rescoping of S-5. Four
of the six gates could have been satisfied by *writing mission state*, and the fifth would have
required **inventing a green-gate floor** — manufacturing a gate's answer. That is why S-5's
mission-state `Closed` requirement was dropped and replaced by a **ceremony-class operation
exercising both patched clean-tree gates through a real invocation**: the original requirement
tested schema conformance between two CLIs, not this toolchain.

---

## 5. §14 status update

**§14 is the authoritative backlog. This build moves five items and moves none of them to "sealed".**

| §14 item | v2.3 status | status now | evidence |
|---|---|---|---|
| **7. D9** — evidence residue / clean-tree blocker | remaining | **BUILT, applied in the smoke repo only** | patch at `tools/evidence-hooks-next/patches/clean-tree-exemption.patch`, regenerated mechanically and asserted appliable by `git apply --check`; both exemption forms required (E24) |
| **8. D10** — dispatch versus turn lifecycle | remaining | **BUILT** as H-1: `OWNER`/`DISPATCH-END` boundary ownership, `OPEN` before the marker, A1 semantics unchanged when unowned | WP-1 instrument, 12 members |
| **(new) integration ownership** | not identified | **RULED AND BUILT** — the orchestrator integrates the worktree branch after validation and ledgers every commit made reachable, before the next dispatch gates | E36; enforced by the FOREIGN-commit check + R-13 |
| **9. D8** — failure and denial capture | remaining | **BUILT** as H-2: per-session `seq` counter independent of log length, `outcome ∈ {denied, failed}` entries, Stop-time reconciliation into `capture-gaps.yaml` | WP-1 instrument |
| **15. LM2-ADR-031** model routing | remaining | **BUILT** — `model-routing.yaml`, four closed roles, Ollama retained and flagged `live: false` | WP-5 K-1 |
| **18. LM2-ADR-026** native worktrees | remaining | **BUILT into the runner** — `--worktree`, CLI-convention paths, `.worktreeinclude` | WP-5 K-2, WP-2 R-2 |

**Not moved, and stated so rather than implied:**

- **14. D1 (`mission verify` implementation)** — increment 1 exists and is *sealed and untouched* by
  this build. Its **suite arm is unimplemented** (E15), which is the whole reason PASS-DIB exists.
  **Increment 2 is the real cure and is outside this build.**
- **20. D4 origin-side attestation** — out of scope by the contract, and the reason matters: S-4
  reaches the top of the assurance ladder for *one* fact (origin's tip) by asking origin directly,
  but there is still **no origin-side attestation workflow**. The ladder is
  SESSION-REPORTED < HOOK-CAPTURED < ORIGIN-SIDE ATTESTED, and only the middle rung is generally
  occupied.
- **22. D5 expected-failure reconciliation** — out of scope; the mechanism exists and was not
  reconciled.
- **10–13 (D2, D7, D3, D6)** — untouched. **D6 in particular is unchanged and still half a
  pathway:** the guard denies re-hashing the machinery by shell, so porcelain-absence — strictly
  weaker than a digest — remains the only available proof of an unmodified sealed set.

**One §14 item this build adds to the backlog:**

- **D11 — bind evidence bodies at append time.** E18 and E19 are the same wound seen twice: a stream
  body can exist only inside an ephemeral worktree, and a plane-crossing copy can succeed vacuously.
  Content-addressing or copy-on-write at append time would make **both** impossible rather than
  merely detectable. This is the single highest-value evidence-plane change the build surfaced.

---

## 6. What v2.4 should say about how this build was validated

Three statements, each earned:

1. **The instrument's job is regression, not acceptance** (E27, verbatim in §2). Six instruments
   exiting 0 was consistent with five of six work packages being wrong.
2. **Falsify a member before trusting it, in both directions.** Every defect this build cured late
   was cured after a member was made to fail on purpose. A member that has never failed has not been
   shown to measure anything — and a member that only ever fails is equally uninformative (E34).
3. **Treat a fail-closed detector's downstream verdicts as *unknown*, never as passing.** A false
   PASS in the goal evaluator — `validator_pass_count` reporting "6 of 6 carry verdict PASS" over
   five REFUTED results on disk — was **masked** by a second defect that had never worked since
   birth. Fixing the provenance binding is what unmasked it.
4. **ONE ROUND OF INDEPENDENT VALIDATION IS NOT ENOUGH, and this build has the control group.**
   Round 1 refuted **5 of 6** work packages against a suite that was entirely green. Every
   refutation was re-checked and held; each was fixed and covered by a member written to fail if it
   returned. Round 2 — **fresh identities, against the fixed tree, with the suite green again** —
   refuted **5 of 6** once more, on **entirely different and deeper defects**. Not the same findings
   restated: round 1 found members testing *adjacent propositions*; round 2 found **mechanisms that
   did not exist**, in the very parts of the contract that other parts cite as their compensating
   control.

   **The same score twice is the finding.** It says the defect rate was not driven down by the first
   round so much as the *visible* defects were, and that the instruments and the contract were
   agreeing with each other in a way no amount of internal rigour detects. **v2.4: independent
   validation is a repeated measure, not a gate to pass once**, and a round that returns clean is
   the first evidence of completeness rather than a formality — which is why round 3 exists and why
   a REFUTED result buys a **new identity**, never a re-ask of a spent one.

   **ROUND 3 RETURNED THE SAME SCORE A THIRD TIME — 1 PASS, 5 REFUTED — and found the worst defect
   of the build.** The protected-path matcher was case-SENSITIVE on a case-INSENSITIVE filesystem,
   so every path the guard defends was writable by changing case, and an agent could mint its own
   push authorization (E49). Three rounds of instruments, two prior rounds of validators and any
   amount of self-review had not touched it.

   **Three data points make a shape two did not.** The score is not converging, and each round's
   defects were *deeper* than the last: round 1 found members testing adjacent propositions; round 2
   found mechanisms that did not exist; round 3 found a mechanism that existed, was exercised, was
   passing — and was **inverted**, defending nothing. **The honest reading is that defect discovery
   here is bounded by reader-rounds rather than by defect supply.** A build that stops when it runs
   out of patience stops with defects of exactly this class still in it. **v2.4: report the number
   of independent rounds a claim has survived, never that it "was validated".**

   **ROUND 4 IS THE FIRST ROUND WHERE THE SCORE MOVED: 3 PASS, 3 REFUTED.** Two rounds' worth of
   contract amendment sit between it and round 3, so it is not a clean comparison — but the shape of
   what it found changed too. Rounds 1–3 found propositions, missing mechanisms, and an inverted
   one. Round 4 found **cures that were correct at the site the previous finding named and nowhere
   else** (E56), an arithmetic that could not distinguish "nothing was lost" from "two things
   cancelled" (E53), and a page of install instructions that had printed a superseded implementation
   for the second time (E48 amendment).

   **That is a different class, and it is the class a build produces when it is fixing findings
   rather than defects.** A finding is one reader's route to a defect; the defect is usually wider.
   **v2.4: when a round's refutations are mostly incomplete cures of the previous round's findings,
   the correct reading is that the build is converging on the READERS, not on correctness** — and
   the response is to enumerate each defect's class before fixing it, not to fix faster.

   **ROUND 5 IS THE FIRST ROUND A MAJORITY PASSED: 5 PASS, 1 REFUTED.** The single refutation was
   a mechanism found wrong in round 4, fixed, and found wrong again one spelling to the side — the
   push-target resolver, which had been taught `-C` while the enumeration it needed sat three
   functions above it in the same file. Two PASSing packages carried driven residuals their clauses
   did not reach, and one of those was a fail-OPEN path in the HALT predicate.

   **The score moved, and the more useful measure is WHERE the findings came from.** Round 5's own
   refutation is one item. Alongside it, a self-audit that pointed the previous batch's rule (E56) at
   the previous batch found three more classes, including a cure that had made a second detector
   NARROWER while fixing it (E58); and three further defects surfaced from the CONTROL rows of
   members written for unrelated fixes (E60). **Independent readers found one; the build's own
   discipline found six.**

   That is the first sign in five rounds that defect discovery here is not purely reader-bound. It
   is not evidence the build is clean: the self-audit only became possible because a reader supplied
   the rule to audit against, and the rule was written three days into a build that had already run
   four rounds. **v2.4: a build should report not just how many independent rounds a claim has
   survived, but how many of its own findings it produced between them.** A build that finds nothing
   between rounds is being tested, not testing itself.

   **ROUND 6: 3 PASS, 3 REFUTED — and it was the first round sized by MEASUREMENT rather than by
   policy.** Five identities were spawned, not six. Every round-5 subject baseline was re-verified
   against the tree after the fix batch; WP-2's was byte-identical, so its verdict described exactly
   the code it had judged and it was not re-asked. **The goal detector does not check that a PASS
   judged the CURRENT tree** — so re-spawning only the refuted package would have satisfied it while
   five verdicts described bytes that had moved.

   **All three refutations were previous cures that were one step too narrow, and one had been inert
   from the start.** H-2's transcript arm — refined across three rounds — never ran in the delivered
   lifecycle at all, because every member called the sidecar writer the way the runner does not
   (E69). The push resolver answered for naming a repository and not for standing in one, using a
   `cwd` plumbed into the same file in the same commit (E66). And the halt predicate misread the
   plainest shape of the defect its own erratum had told it to enumerate (E64).

   **The score has now been 5/6, 5/6, 5/6, 3/6, 1/6, 3/6 refuted across six rounds.** The middle
   figures are not a trend to celebrate: rounds 5 and 6 changed the tree substantially between them,
   so they do not measure the same object. What has changed is where findings come from. Rounds 1–4
   were almost entirely reader-driven; rounds 5 and 6 produced roughly as many findings from the
   build's own sweeps and control rows as from the validators — including a defect class swept to
   closure (the null sentinel) and one caught by a harness reporting its own blindness.

   **v2.4: report the score, the provenance of the findings, and whether the tree moved between
   rounds.** A score alone invites the reading that a build is converging, and three of these six
   rounds refuted mechanisms that a previous round had already found and fixed.

   **ROUND 7: 3 PASS, 3 REFUTED — and every refutation was a cure this build had written,
   each invisible to the member written to guard it.** The push classifier and the push target
   resolver normalised the same command differently, so the ordinary three-line commit-and-push
   block — the shape the Bash tool actually executes — was ALLOWED with no gate, no denial record
   and no consumption, and was driven to a real publication; separately, a quoted `--git-dir` was
   classified a push and resolved to the WRONG repository, publishing one that held no gate at all
   and tombstoning the session's gate for it. The capture-gap reconciliation filtered its log by a
   session id the caller fills from a different namespace, so a store with nothing missing reported
   36, 35 and 13 phantom gaps on hash-verified mirrors of three live stores. And the halt predicate
   collected a QUOTATION rather than the document's own marker, so a set of one agreed with itself.

   **The round's most useful finding was about this build's own record, and it came from the
   falsification harness.** A member written to guard round 6's YAML cure asserted what the cure's
   comment CLAIMED — that the bad form was unparsable. Falsification reported the member BLIND, and
   one line of measurement showed the comment was false: the bad form parses, and silently yields a
   MAPPING where a filename belongs, which is quieter and worse than the refusal I had described
   (E71). A green suite cannot distinguish a member that guards a cure from a member that restates a
   mistake. Only perturbing the cure and watching the member fail to notice can.

   **The score is now 5/6, 5/6, 5/6, 3/6, 1/6, 3/6, 3/6 refuted across seven rounds**, and the flat
   tail is not convergence — rounds 6 and 7 refuted mechanisms that rounds 4 and 5 had already
   found and fixed. Round 7 also produced the first defect this build introduced **by adopting a
   better implementation**: replacing a hand-rolled command scan with the library splitter it should
   always have used silently dropped parentheses as separators, re-opening a fail-open spelling
   round 2 had paid for (E70).
5. **Two of round 2's six refutations were not defects to fix but CONTRACT DECISIONS** (E40, E42),
   and stopping to say so was the correct move rather than a stall. A build that can only produce
   patches will patch a contradiction into one of its two readings and call it fixed. **The record
   needs a state that means "this is not mine to settle"** — and it must be an artifact, because a
   paragraph does not change what the evaluator reports (E39).

6. **THE CONVERGENCE EXHIBIT — twenty rounds, from the ledger.** The narrative above stops at round 7.
   The table below is tallied from `.mission-runtime/lam/spawn-ledger.jsonl` by a script, not from
   memory; round 1 predates the ledger's `round` field and is attributed from the ledger's note line
   recording its result.

   | round | spawned | banked | PASS | REFUTED | what the round found (from the record) |
   |---|---|---|---|---|---|
   | 1 | 6 | 6 | 1 | 5 | members testing adjacent propositions |
   | 2 | 6 | 6 | 1 | 5 | mechanisms that did not exist; two contract decisions (E40, E42) |
   | 3 | 6 | 6 | 1 | 5 | the case-sensitive matcher — defending nothing (E49) |
   | 4 | 11 | 6 | 3 | 3 | cures correct at the named site and nowhere else (E56) |
   | 5 | 6 | 6 | 5 | 1 | one cure one spelling to the side; six self-audit findings |
   | 6 | 5 | 5 | 2 | 3 | three previous cures one step too narrow; one inert from birth (E69) |
   | 7 | 4 | 4 | 1 | 3 | every refutation a cure this build had written (E70, E71) |
   | 8 | 6 | 6 | 1 | 5 | the marker-shape matrix — twelve spellings invisible |
   | 9 | 6 | 6 | 5 | 1 | the 8.3 short-name alias mints a gate |
   | 10 | 3 | 3 | 2 | 1 | the extended-length prefix hides every normalisation |
   | 11 | 3 | 3 | 2 | 1 | the executable question is not enumerable (the classifier exhibit) |
   | 12 | 6 | 6 | 3 | 3 | E77–E89: a dry run that mutated; vacuous implications |
   | 13 | 6 | 6 | 2 | 4 | 13 of 26 status spellings still invisible → a halt |
   | 14 | 6 | 6 | 2 | 4 | a field consulted on the branch that returns, not the one that writes |
   | 15 | 6 | 6 | 0 | 6 | the fence deviation's mirror case; every package refuted |
   | 16 | 5 | 5 | 1 | 4 | an install page probing a path that did not exist |
   | 17 | 5 | 5 | 1 | 4 | one shape found by four identities independently (E115) |
   | 18 | 5 | 5 | 1 | 4 | round 17's cures held; its non-vacuity assertions did not |
   | 19 | 5 | 5 | 3 | 2 | round 18's fixes each opened something new |
   | 20 | 6 | 6 | 5 | 1 | two CRITICALs, both introduced by round 19's cures |
   | **Σ** | **112** | **107** | **42** | **65** | refutation rate over banked verdicts **60.7 %** |

   **The score never converged, and the reason is in the last column.** Nine of the twenty rounds
   refuted a cure a previous round had written — 4, 5, 6, 7, 17, 18, 19, 20, and the fence rule across
   13–15. That is the **cure-introduces-defect rate**, and it is the figure a build should report
   beside its score: **in this build, roughly one round in two found the previous round's remedy
   rather than a fresh defect.** Round 20 is the sharpest instance — both CRITICALs (a credential
   value carrying a newline; an exemption asking scope where the question was reachability) were
   introduced by round-19 cures the builder was confident in, and the builder's own closure work
   introduced a CRLF regression that turned three instruments off before the suite caught it. The
   record does not show the defect supply running out; it shows reader-rounds being the bound.

   **What v2.4 must therefore say, and this ruling is the evidence for it:** *a validation contract
   declares its round budget or its convergence criterion **up front**, so that stopping is a
   pre-committed touchpoint rather than an operator's late judgment.* This build's contract said "6/6
   PASS on the final tree" and no round ever reached it; the operator's completion ruling (round 20)
   had to be written from outside the contract, as an amendment — a package is complete on a PASS or
   on a REFUTED whose residuals are registered and accepted by hash. That is the right rule, and it
   should have been in the contract before round 1, with the number of rounds it was prepared to
   spend. Without it, every round's end is a judgment call the record cannot audit.

   **The five errata that carry this section** (E91–E95, all from rounds 12–15): a rule with no
   specification cannot be completed by patching (E91); a guard clause that skips a check is an off
   switch (E92); a member can exercise the right code path through a state that cannot occur (E93);
   the correct handling of a sub-case can invert when the resolution rule changes (E94); one defect can
   conceal the next, and fixing the first is what makes the second reachable (E95). Each of them is a
   way a round's refutation turned out to be the previous round's cure.

   **This ruling, verbatim in its consequences:** the halt cured in the next generation only, the sealed
   guard disclosed open on the install page (ruling A); the fence deviation ratified as an amendment
   (ruling B); the shape scan a tracked lint, never a gate (ruling C); a contract amendment the stopping rule
   (ruling D); this exhibit, the residual manifest, and the install sequence finalized (ruling E).

7. **THE FOUR PENDING ITEMS, RULED AT CLOSURE, and one premise measured false.**
   * **K-4's scope is the narrow reading.** Code-to-code parity — every `function`-shaped block on
     the install page located in the next-gen library by name and compared as code — is the clause,
     and was from the amendment that introduced it. **Followability of §5 was never contracted.** Three rounds of
     charters asked for it and no validator ever judged it a clause; round 20's WP-5 disclosed the
     un-driven K-4 arm as a scope choice, correctly. v2.4 records followability as a **candidate
     clause for a future arc**, not this one: a page that is followable is a good property and it
     needs its own member, its own falsification and its own reader-round, none of which this build
     spent on it.
   * **The eighth sealed-table row** is ratified; the operator places the sealed-table amendment,
     drafted beside the build as an amendment file of its own, at the admission
     ceremony. The builder does not place it.
   * **RES-10's premise measured FALSE at closure.** The residual manifest says the sealed library
     "very likely" shares the newline-crossing regex spelling. It was swept read-only at closure, at
     anchor `ec27ab3a33639b95` / 80479 bytes, for **both** spellings — the `(?m)^key:\s*` idiom and
     any `key:\s*` inside a quoted literal — and for `(?m)`-mode `\s*$` end anchors: **zero sites in
     every form.** The class was introduced by the next-gen library's YAML-field readers, which the
     sealed library never had. The manifest is bound by the operator's gate and is **not edited**;
     this paragraph and LAM-INSTALL §5's pre-swap step carry the correction beside it. The operator
     re-runs the sweep at the terminal before §2's swap (ruling 3) — a builder's read-only run is
     prior evidence, not a substitute for the step.
   * **K-5 enters the contract by its own amendment**, text only, committed alone — the contract closes
     with its members all named.

---

## 7. The arc retrospective's errata E-1..E-8, and what the post-arc toolchain batch added

**What this section is.** The ruling this section implements: "v2.4-DELTA
errata E-1..E-8 land by one doc-only amendment at the batch's end, each citing the amendment that cured it."
This section is that landing, made by one doc-only amendment, the batch's last work package.
It is written under the prose standing this package's dispatch states -- no figure is unsourced --
and each erratum is stated as the rule it established and the mechanism that made it necessary. The
records that measured each one stay with the project that kept them; this document cites no line of a
register it does not ship.
No sentence above this heading is edited.

**The labels, because other series already use them.** "E-1".."E-8" below are the retrospective's errata as
ruling (vii) names them. They are not this document's E6..E120 (section 2, no hyphen). They are not a
recording seat's ledger corrections, which can carry the same shape: a ledger's "ERRATUM E-n" may
share its subject with the E-n here or have another subject altogether. They are not a work package's
own item numbers either, which can take the same E-n form, nor the sub-items of a package
that splits.
And a ledger can carry older series of the same shape, from a close-prep or from an amendment's own
errata, so an erratum here is keyed by this document and this section, never by its label alone.
So that no further series is added,
the batch's own errata in 7.2 are labelled B-1..B-7.

### 7.1 The retrospective's errata, E-1..E-8

**E-1 -- the attention tally counts console acts by kind, arc-scoped by gate id, `tool_exit=0` only.** Under
the rule, an arc's figure is derived from `.mission-runtime/operator-acts.log`: the
kind is read off the gate id's prefix, because the `kind=` field reads `gate-act` on every line; a line counts
for the arc only if its gate id is one of the arc's; and a line with a non-zero `tool_exit` is a record of a
try -- "A FAILED ATTEMPT IS A LINE, NOT AN ACT". So an arc's tally is not the log's line count: the log
also holds pre-arc tooling pushes and failed attempts, and counting its lines overstates both the acts and
the pushes. It is a rule of counting;
no code changes for it, and a figure
derived before the rule is corrected beside it, not edited in place.

**E-2 -- a placement window cost a halt-ruling act on top of the amendment-material act.** A placement
window is a HALT whose own title says it places an amendment; such HALTs are
read by file tool from the root checkout's
`.mission-runtime/halts/`, and the amendments they place are among those whose amendment-material acts the
tally counts. Every HALT is answered by a halt-ruling gate, so each
placement costs the operator two acts. The mechanism: a seat that placed an amendment for the
operator to ratify could not stop on
it, because the goal read NOT_MET and the Stop hook blocked, so the seat raised a placement-window HALT to
hand control back. Cured by a later amendment,
under ruling (ii): the detector type `ungated_placement_absent` makes an
untracked file under `.mission/amendments/` that no canonical, unrevoked amendment-material gate binds an
admitted stop, verdict `AWAITING_AMENDMENT_GATE`, and the mint is the release. The cure acts only where a
goal file declares the type. Declaring it is
a standing for every charter, and a charter that declares it raises no
placement-window HALT; a goal already closed is not retrofitted.

**E-3 -- a push gate's settle is stamped by the actor that performs the push.** A push made from the
operator's terminal fires no PostToolUse, so its gate had nobody to stamp it.
Ruling (i): the in-session hook stamps the push its
session performs, and the operator's console stamps a terminal push with `settle -Kind push -Id <id>`, which
observes the gate's own `origin_url` holding `authorized_tip_sha` at `remote_ref`, refuses otherwise or if
consumed or revoked, and writes the five `consumed_*` fields; the first stamp wins and the second refuses.
Built by a later amendment. An expired push gate can still be settled from the console,
because the settle is a record of use and not an authorization:
"expires_at binds the pre-push decider
(authorization), not the settle (record of use)". A settled, expired gate still admits
its ORIGIN-ATTESTATION subjects, by design.
A dispatch gate is stamped by the runner at spawn.
Both branches of the console settle, OK and Cancel, are to be driven: a deployment that has
exercised only the OK branch holds the Cancel branch open until a push gate's Cancel probe
is run before its OK settle.

**E-4 -- mission-plane ceremony runs only from a root seat bearing the orchestrator hooks.** Ruling (v)
states it. Its occasion: a close ceremony run from a linked
worktree leaves no evidence sidecar in either plane. A later amendment
built the seat tripwire in the next-gen evidence guard: a mission-plane write from a
session whose project directory is a linked worktree is refused, deny-side (WP-1 H-25). It is a tripwire, not
a boundary: write verbs outside A1's two classes, a classified verb that names no plane path, and a script
invoked by path such as `tools/lam/mission-*.ps1 -MissionRoot .` are not refused by it, so ceremony at the
root "holds by discipline there, not by the guard". A tooling seat is
guarded at all only once `.claude/settings.json` is tracked in the root commit;
a seat worktree cut before that holds no `.claude` directory at all.
A worktree cut before that commit is guarded only after it merges `main`, and
only for commands after the merge.
The tracked registration is measured live in a fresh tooling
seat by a guard control, which reads DENIED. A linked worktree cut before settings.json was
tracked holds no `.claude/settings.json` until it merges `main`.

**E-5 -- rulings, charters and briefs name rules, not files; a named figure is a claim to verify.** Ruling
(iii): "Charters, rulings and briefs name RULES ("the newest anchors on disk"), never files
or figures a seat can derive; a named figure is a claim the seat re-derives and asserts before use." The
reasons are general. A figure handed to a seat can be a miscount: re-derived, it can come back different.
A ledger entry's own counts, a directory count or a page-citation count, can each be
a miscount of the seat's own tool output. A ruling's
premise, such as that two runs overlapped, can be contradicted by the timestamps on disk. A dispatch's
premise that a class is already recorded in `docs/framework/LAM-RESIDUALS.md` can be false.
And a brief can name a path, such as a short form of a document's name, where the file has
another. No code cures it; it is a
standing.

**E-6 -- the spawn ledger's `round` is an integer, a label lives in `round_label`, and the tracked composer
writes it.** Ruling (iv), enforced forward-only from a cutoff line,
the label-shaped lines before it admitted as legacy. A later amendment
built `tools/lam/spawn_ledger.py` for it:
`append` reads one JSON object, applies the check -- an integer `round`, a `round_label` only beside one, no
`round_number` -- and stamps `composed_by: tools/lam/spawn_ledger.py@<blob8>`, never taken from the caller.
WP-4 T-42 audits every line after the cutoff through it, forward-only, the legacy lines named;
a PASS is no violation after the cutoff
and every legacy line named. What stays is detection, not prevention: `composed_by`
is a declaration, and a hand-written line that copies a real stamp and passes the check in the composer's
exact form is not caught (residual (a)). The standing owed to
every charter: its seat brief mandates the composer.

**E-7 -- the zero-margin product floor: its exposure, and the response.** The product gate admits no margin:
it passes only with runnable at or above the stored floor and every failure declared by the expected-failures
mirror (the gate's M2 line has the form "runnable <n> >= floor <n>, 0 failure(s) and every one of them declared
by the mirror's <k> id(s)"), and the floor equals the runnable count (one run's
tally). Ruling (vi) keeps it: "a drop below
floor is a HALT naming the cause; the cure is a reconciled expected-failure or a regression fix; the floor is
never lowered by hand." The exposure:
a product test
that fails intermittently on unchanged product code, with the product's
services running, reads red on the gate's C1
conjunct (an unexpected failure), not C2 (a collection drop). For such a row, ruling
(vi) is not engaged, the mirror is not edited, the floor is not touched, the test is a product row owned by
the product, and a root stop needing one retry is an accepted bounded cost. The row
records how often it failed. A second face of the exposure: a
product run that waits out the instrument's 900 s wall while the container backend is silent
yields a killed run
whose tally, "runnable 0 < floor <n>", reads like the drop ruling (vi) governs and is not one; a fail-fast precondition
is owed.

**E-8 -- `autoMemoryEnabled: false` is tracked; the harness maps a worktree to its main project's memory;
and the setting holds only for sessions opened with the file present.** The key is in the tracked
`.claude/settings.json` since the root commit, as ruling (v) asks,
and WP-1 H-26 reads it there. The mapping is registered
and measurable from the harness side by a probe: from a
linked worktree, memory is on, and it is the main project's folder. Settings load at session start, so a
session opened before its worktree held the file keeps memory on (a registered standing; notes such a
session writes after its merge of `main` land in the main project's folder, consistent with
it). Whether a session opened with the file present honours the key is still unmeasured: the probe ruling
(v) names is owed, and none has been run. The notes such sessions left are
inventoried, and their toolchain facts promoted, in `docs/framework/LAM-AUTHORING-NOTES.md`.

### 7.2 What the batch itself surfaced, B-1..B-7

**B-1 -- instrument totals taken inside the peer-worktree home are RED->GREEN evidence, not acceptance
figures.** An earlier amendment states it: a table of readings across commits at one path is a sound
differential, and the acceptance run is WP-1..WP-6 at the repository root after the merge. The reason is
a registered location-dependent class: WP-1 H-8 and WP-4 T-5 and T-10 drive the live
guard, whose peer-worktree rule denies inside `<repo>-worktrees\`; WP-2 R-36a needs a `\U` segment in its
sandbox path; WP-6's F-0 and its eight dependents need the smoke mission that resolves only beside the
repository of record; and the pre-push checker hashes the raw bytes it reads. So the acceptance
run is taken at the root after each merge of a batch's amendments, and once more after the
root commit, the row count rising as the merges add members.
An amendment's own serials, taken away from the root, keep showing the class; they are read as
RED->GREEN differentials between commits at one path, never as acceptance figures: the figure
that accepts a package is the one taken at the root.

**B-2 -- the validator round cap of four, and law 7's termination rule.** A package refuted at its
fourth fresh-context round stops there: the dispatch allows a
fourth round and no fifth. A package refuted at a round on reporting findings only may close
text-only on an operator ruling, with no further round, and merge on that ruling;
the ledger records the ruling beside the merge.
A package whose fourth round refutes out of enumeration
stops under the contract's stopping rule, and may merge on an operator's
law-7 ruling that the finding is a residual, which is then registered. Law 7 (design v2.3 SS4.5), as the page
states it: once claims are derived, demonstrated, or class-stated with working detectors,
"blocking narrows to a named fix that did not land, a regression, or an overclaim", and everything else
registers non-blocking. A package whose last findings are reporting findings only may close them
text-only under the same law.

**B-3 -- validators are spawned through the Agent tool only.** A validator
round launched through a workflow can arrive framed: the workflow harness adds a paragraph of its
own and indents every line, so the prompt arrives longer than, and with a different sha256 from, the prompt
written. Such a launch is stopped and the round relaunched through the Agent tool.
The detector is the check run on every round: the prompt as received, read out
of the validator's transcript, byte-compared with the prompt written.

**B-4 -- a model switch forced by a safeguard flag is recorded, never silent.**
A seat whose model is switched under it, for example by a safeguard, and whose amendment's
lines carry no word of the switch, leaves the record silent about it. A seat whose
model changes under it states the model it ran on, where the switch came from and when, in its amendment's
text, and the recording seat carries it to the ledger. A page that omitted it records it in its erratum
at a later amendment.

**B-5 -- NOT_MET at a root stop closes the window, and commit-ledger lines land before any goal
evaluation.** A brief that evaluates the arc's goal before ledgering the commits a merge
brought in is refused by the advance admission on the brief's own step order, a
registered shape; forbidden to cure, a seat in that state stops with its window open, and a silent
container backend can make the product instrument wait out its 900 s wall meanwhile. Ledgering the
commits first lets
the same decider admit them. The standings
are "A SEAT LEDGERS EVERY COMMIT A MERGE BROUGHT IN BEFORE ANY GOAL EVALUATION WHOSE VERIFY RANGE
SPANS THEM -- commit-ledger first, then evaluate", and "NOT_MET at a root stop: close the window", the
window being the operator's to close. The same order holds for every later merge's commits and the
merge itself.

**B-6 -- the guard's spelling class closed to a fixpoint; the residue printed; LAM-RESIDUALS.md
gate-bound and unedited.** A later amendment closed the NTFS stream spelling
in the T-3 gate rule and A1's protected tier. Successive cures each missed a composition of
normalisations the previous cure had not applied, so the cure stopped adding one-offs:
`Get-EvidenceA1OfferForms` closes each seed under the Win32 trailing-dot strip, the 8.3 alias inversion and
the stream strip to a fixpoint, a 64-step counter the backstop. The class is closed over the
transforms it enumerates; outside the enumeration stay
UNC admin-share and NT device prefixes, pre-existing and rooted in the sealed
`ConvertTo-CanonicalPathText`, which this build may not write. They are printed on the page for the operator as residuals,
and `docs/framework/LAM-RESIDUALS.md` is not edited: it is bound by the
completion-acceptance gate by sha256, and an edit un-accepts every package until the operator
re-mints the gate.

**B-7 -- the precondition standing: stop at the first arrow that does not match.** A root
commit made by a step list, each step
printing an expected output after `->`, can read the proposal's CRLF hash at STEP 1 where the original's
is expected, because the steps have run once already; the backup the first run made then holds
the proposal, not the original, even when the committed blobs are the prescribed ones.
The standing: a step list whose lines print an expected output after `->` is a chain of preconditions, and
the first arrow that does not match is a STOP, whatever its cause, until the steps are re-derived.

### 7.3 The standing this section starts

Every future arc's retrospective lands its errata in this document by one doc-only LAM-ACCEPT amendment, in
this section's form: each erratum one paragraph, each citing the ledger entry or amendment that cured or
measured it, and the labels stated against every series they could be confused with.
