# D8 -- BUILD DISPATCH: failure and denial capture (cures E5-ii and E5-iii)

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>"
> denote `docs/framework/vanguard-collective-local-modes-v2.3.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** Its author built nothing.
>
> **THIS IS THE ONE THAT REACHES DESIGN, NOT ONLY BUILD.** A1's founding
> claim -- *a fabricated `git rev-parse` cannot survive this* -- holds today for claims backed by
> successful, permitted commands **and only those**. A claim about a command that failed, or that
> the guard refused, has no evidence trail at all. This dispatch is what makes the founding claim
> true or states honestly that it cannot be made true from inside the hook contract.
>
> **D10 MUST LAND FIRST.** Stop-time reconciliation is incoherent while `Stop` is per-turn:
> reconciling a turn's transcript against a manifest finalized on turn one reconciles the wrong
> two things. If D10 has not landed, HALT and say so.

---

## P0 GROUNDING

Read-only, first reply. Report each with the command and its raw output.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. **HAS D10 LANDED?** Derive it from the ledger and from `evidence-stop-finalize.ps1`'s current
   hash, not from recollection. If it has not, HALT.
3. **THE FIRST TECHNICAL QUESTION, AND IT IS DRIVEN, NOT READ.** Does the harness send a
   transcript path on `Stop`? A prior amendment records that `Stop` reads `session_id` **only**,
   while `PreCompact` receives `transcript_path`. **Register a raw-stdin probe on `Stop`, drive
   a real session, and report the payload verbatim.** Do not answer this from A1's assumptions,
   from this dispatch, or from documentation: assuming a payload shape is the exact class erratum
   E5 consists of (design SS4.5 law 10). The probe is authored under `.claude/`, derived and
   uncommitted, on the established probe pattern, and is de-registered and verified absent
   afterwards -- the installer treats any non-marker command as FOREIGN and will refuse on your
   own probe if you leave it.
4. **The absence, measured.** Drive a deliberate tool failure and a deliberate guard denial in a
   live session, then show that neither produced a log entry, a `seq` gap, or a `hook-errors.log`
   line. Earlier controlled experiments established this by elimination; re-establish it, because you are
   about to build against it.
5. **`seq` allocation from source** (`tools/framework/hooks/lib/evidence-common.ps1`, sealed
   `189f811b`) -- confirm it is `(non-blank log lines) + 1`, derived from the log's own length.
6. **Design SS4.6 E5-ii/E5-iii, SS4.7 D8, and SS17.2** -- the falsified assumptions and the
   scoped `wiring_status`, in full.
7. **The authorizing amendment** -- the candidate narrowing this dispatch inherits, including why candidate
   (a) is not yours to build.
8. **D11's status.** If D11 has landed, read what identity scheme it produced. You **consume** it;
   you do not design one.

**HALT AND REPORT if:** D10 has not landed; or the probe shows `Stop` receiving a payload
materially different from the recorded shape (grounding item 3) in a way that changes the design (that is a finding worth
more than the build); or any sealed hash named in AUTHORITY has moved unexpectedly.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; **never**
  `Invoke-AtomicCommit` (registered defect R2). Ledger appends use `-NoCommit`.
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-10 bind. Laws 4, 6, 9 and 10 govern the acceptance.
- LEDGER-GOVERNS. AM files are immutable once placed.
- Evidence is verbatim fresh-run output plus sha256 prefixes.
- **Probe hygiene, binding**: nothing under `.claude/` is staged or committed;
  probe output is quoted in the report as path plus hash plus small verbatim excerpt; raw payloads
  may carry session content, so no secret bytes are displayed and anything credential-shaped is
  identified by hash prefix only.

## AUTHORITY

- **The authorizing amendment's scope and candidate narrowing** (P0 GROUNDING item 7).
- **design, "### 4.6 Erratum E5 -- four SS4.1 assumptions falsified by the live harness"**
  -- errata E5-ii and E5-iii, the falsified assumptions, per member.
- **design, "### 4.7 Registered dispatches arising from E5"**
  -- the D8 registration, including "the hook cannot fix this alone: it is never
  invoked", and the candidate space it names.
- **design, "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- places D8 last in Arc 1, after D10.
- **The controlled experiments** that established the absence by elimination, and the candidate
  space they left -- re-established under P0 GROUNDING item 4, not taken on trust.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: .claude/wiring-probe.ps1
MOVES A SEALED HASH: YES
SEALED FILE: tools/framework/hooks/evidence-stop-finalize.ps1 d1f69b6b
SEALED FILE: tools/framework/hooks/lib/evidence-common.ps1 189f811b
SEALED FILE: tools/framework/hooks/settings.evidence-hooks.json a5a8c166
SEALED FILE: tools/framework/tests/test-a1-negative.ps1 a27d008b

**WHAT `AMENDMENT COVERS` MEANS HERE, AND THE QUALIFIER IS LOAD-BEARING.**
`.claude/wiring-probe.ps1` is covered as a **DERIVED, UNCOMMITTED** artifact on the established
raw-stdin probe pattern (design, "### 17.1 What was done") -- authored, driven, de-registered, and
**never staged and never committed**.
It is NOT a tracked write-surface grant, and an amendment that reads it as one has granted
something nobody asked for.

**Why an amendment is required.** Not for `tools/framework/**`, which is inside
the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`), but because it **moves sealed hashes** (each recorded in a ledger
entry), because the commit is operator-mediated, and
because **it reaches design**: if the outcome is that the failure dimension cannot be closed from
inside the hook contract, that is a design-authority statement and belongs in an amendment, not
in a build report.

**THE ENUMERATION ABOVE IS DERIVED, NOT AUTHORED.** It is the intersection of this dispatch's
WRITE SURFACE with the full, non-abbreviated set of sealed anchors. The
`settings.evidence-hooks.json` row moves only if the `Stop` registration changes; it is declared
conservatively because a hash that moves undeclared is a finding, while a hash declared and not
moved is reported as not moved.

Report old and new prefix **and byte length** for each that actually moves, and record every one
in a ledger entry.

## WRITE SURFACE

- `tools/framework/hooks/lib/evidence-common.ps1`
- `tools/framework/hooks/evidence-stop-finalize.ps1`
- `tools/framework/hooks/settings.evidence-hooks.json` -- only if grounding item 3 requires it
- `tools/framework/tests/test-a1-negative.ps1`
- `docs/framework/**` -- if the outcome is a registered residual rather than a cure
- `.claude/wiring-probe.ps1` and its gitignored output -- **derived, uncommitted**, grounding
  item 3 only, removed and verified absent afterwards
- `.mission/ledger/entries.jsonl` -- append only, `-NoCommit`

All tracked paths are inside the standing write surface. **NONE UNDER `tools/framework/**` IS STAGEABLE BY AN
AGENT SESSION**; the commit is an operator act. Hand the operator the exact `Get-FileHash` and
`git add` commands and record that you did.

## FORBIDDEN

- **Designing a `seq` identity scheme.** That is D11. Candidate (a) -- a call-counter `seq`
  independent of log length -- cures the collision D11 owns, and it does **not** cure E5-ii/iii:
  a counter maintained by `PostToolUse` cannot count the calls `PostToolUse` never sees. A denial
  fires no hook, so no counter it maintains advances, so no gap appears. Consume D11's scheme;
  do not invent one.
- **Curing the turn/dispatch mismatch.** That is D10 and it is your precondition.
- **Presenting a partial mechanism as a cure.** If reconciliation can see failures but not
  denials, or denials but not failures, say which and register the remainder per member.
- **Reasoning from `exit_code`.** Erratum E5-i: neither spelling appears in any captured payload;
  every entry records `null` permanently. Any arm reasoning from it is reasoning from a constant.
- **An agent-writable evidence store.** Whatever reconciliation writes must be written by hook or
  runner machinery outside the model's pen. Principle 11 is not relaxed to close this gap; a
  store the agent can write is worse than none.
- **Claiming the guard now records what it refused** unless a denial is demonstrably in the
  record, per member, with the detector shown.
- **Touching the mission record, `src/`, `tests/`, the schema without declaring it, or D9's
  committed-plane question.**

## ACCEPTANCE

Stated as a goal condition a validator can decide from disk.

1. **A FAILED tool call is either recorded, or its absence is DETECTABLE from the committed
   artifacts alone.** Demonstrated by driving a real failure, per member, with the detector's
   output shown. "The manifest no longer reads complete" is an acceptable cure; "nothing changed
   but we know about it" is not.
2. **A GUARD-DENIED call gets the same treatment**, demonstrated by driving a real denial. E5-iii
   is its own member and needs its own demonstration; a single combined demonstration fails
   law 4.
3. **THE TRANSCRIPT QUESTION IS ANSWERED WITH A RAW PAYLOAD**, quoted verbatim, and the design
   follows the answer rather than the assumption.
4. **If the honest outcome is that this cannot be closed from inside the hook contract**, that is
   an ACCEPTABLE OUTCOME and is stated as a registered residual with its reach per member -- not
   as a cure, and not as silence. Candidate (c) is named in the authorizing amendment precisely so this
   answer is available without inventing a weaker mechanism to avoid it.
5. **`manifest completeness != call completeness` is either resolved or still stated.** Design
   SS4.6's warning stands until a consumer can decide completeness from the committed set.
6. **No false-positive class is introduced.** Reconciliation that reports a gap on ordinary
   behaviour is worse than the gap: it is the `TAMPERED`-for-continuing-to-work defect one layer
   up. Drive the negative.
7. **`test-a1-negative.ps1` covers every new detector**, with counts derived rather than typed.
8. **The probe is de-registered and VERIFIED ABSENT, and the verification is shown, not
   asserted**.
9. **Regression.** RESIDUE-KEEP untouched; porcelain compared before and after; acceptance suites
   **operator-run**; any suite not executed reported as NOT RUN with the denial
   cited, never as a result.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- **The raw `Stop` payload** from grounding item 3, verbatim, with the probe's path and sha256
  prefix, and the verified-absent derivation from ACCEPTANCE item 8.
- **The driven failure and the driven denial** from ACCEPTANCE items 1 and 2, each verbatim and
  each separately labelled, with the evidence-plane state before and after.
- **The driven negative** from ACCEPTANCE item 6.
- Old and new sha256 prefix **and byte length** for every anchor that moved, plus an explicit
  "declared and did not move" line for every anchor declared in AUTHORITY that did not.
- The A1 negative suite result with its exit code, or the verbatim denial plus NOT RUN.
- The ledger entry id and line number, and the exact commands handed to the operator for staging.
- **An explicit statement of what you did not verify**, and -- if the outcome is item 4 -- the
  registered residual stated per member.
