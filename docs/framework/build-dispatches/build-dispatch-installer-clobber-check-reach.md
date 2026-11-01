# D7 -- BUILD DISPATCH: the installer's clobber-check reach

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>" denote
> `docs/framework/vanguard-collective-local-modes-v2.2.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** A4 authored it and built nothing.
>
> **This dispatch exists because of a defect found at A4 grounding, not because of a ledger
> backlog item.** It is the one dispatch of the seven that answers a premise break rather than
> a registered item, which is why the dispatch set is noted as not the backlog
> set.

---

## P0 GROUNDING

Read-only, first reply, before writing anything.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. `tools/framework/install-evidence-hooks.ps1` IN FULL. Expect sha256 prefix `fe5ae434`,
   7593 bytes. The clobber check is the `$conflicts` loop; read it together with the
   `$settingsPath` assignment that decides what it reads.
3. `tools/framework/hooks/settings.evidence-hooks.json` -- the four events the fragment
   installs, which is the exact set the clobber check iterates. Expect `a5a8c166`.
4. **`.claude/` as it actually stands right now.** List it. Read every settings file present.
   Report, per file, whether it carries a `hooks` key. A typical `.claude/` holds
   `settings.local.json` with permission entries and **no** `hooks` key, and
   `settings.json` was absent. **Re-derive both facts; do not trust these.**
5. **The harness's own settings precedence** -- which files it merges, in what order, and
   whether any of them may carry hooks. This is the load-bearing derivation of the whole
   dispatch and it is the one item you cannot get from this repository. Derive it from the
   harness documentation available to you, state your source, and state plainly what you
   could not establish.
6. The ledger record of the premise break and the operator ruling that registered this dispatch.

**HALT AND REPORT if:** the clobber check already reads more than `settings.json` (someone
cured this), or if any settings file now carries a `hooks` key -- in which case the
hypothetical this dispatch guards against is live, and that fact outranks the cure.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; never
  `Invoke-AtomicCommit` (a registered defect; D3 is its cure).
- Strict UTF-8, no BOM, LF-only; `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-9 bind. **Law 4 is the subject of this dispatch**, not merely a
  constraint on it: a detection claim is stated per-member and demonstrated per-member.
- LEDGER-GOVERNS.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **The disclosure ruling on the reach defect**: disclose-and-proceed, with the cure registered
  as this dispatch rather than taken opportunistically mid-install by the session that found it
  -- local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)",
  law 10: a session repairing the machinery whose failure it just discovered is the
  pen-on-its-own-evidence problem one level up.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 11 (D7).
- **design, "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)", law 4** -- the law the current code violates.

NEEDS ITS OWN AMENDMENT: NO
MOVES A SEALED HASH: YES
SEALED FILE: tools/framework/install-evidence-hooks.ps1 fe5ae434

**Read both lines together, as in D2.** The write surface is fine -- `tools/framework/**` is
inside the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`). What is not free is the seal: this moves sealed A1 anchor
`fe5ae434`, and a moved sealed hash must be recorded. Append a ledger entry recording the old
and new prefixes, the byte length, and what moved them.

**AND THE OPERATIONAL FACT D2 CARRIES APPLIES HERE TOO.** If the A1 hooks are installed, the
PreToolUse guard **denies** `git add tools/framework/...` by design (design, "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)",
law 8). Your
commit is then an operator-mediated act per D6's pathway -- and note the ordering hazard
peculiar to this dispatch: **you are modifying the installer while the thing it installs is
what blocks you from committing the modification.** Check whether `.claude/settings.json`
exists before you plan your ceremony.

## WRITE SURFACE

- `tools/framework/install-evidence-hooks.ps1` -- the clobber check and its reporting only
- `tools/framework/tests/**` -- a test for the widened check
- `.mission/ledger/entries.jsonl` -- append only (the seal-move record)

## FORBIDDEN

- **Changing what the installer WRITES.** It writes `.claude/settings.json` and that is
  correct. This dispatch changes only what it **READS when deciding whether
  to refuse**. Widening the write target would put the installer's output into a file the
  harness merges differently, which is a different act needing a different amendment.
- **Merging foreign hooks automatically.** The current behaviour on conflict is to REFUSE and
  exit non-zero. That stays. A wider check that resolves conflicts instead of reporting them
  would convert a deny-side refusal into an allow-side exemption, which is design SS4.5 law 2
  exactly backwards.
- **Claiming the check now covers every settings source** unless you can enumerate them from
  the harness's own documented precedence and demonstrate each. If you cannot, the check
  covers the sources you name and **prints that list on every run** -- see ACCEPTANCE item 3.
- Editing any other part of the installer, or any hook script, or the settings fragment.
- Suppressing the existing `REFUSING TO CLOBBER` output or changing its exit code.

## ACCEPTANCE

Stated as a goal condition.

1. **The check's reach and its label agree, in both directions.** Today the message says
   "foreign hook entries already present on events this fragment installs" while the code
   reads `.claude/settings.json` alone. After the cure, either the reach matches the label or
   the label matches the reach -- and a driven case proves it for each source read.
2. **A foreign hook entry in a NON-`settings.json` source is detected**, proven by a driven
   case: plant a `hooks` key in `settings.local.json` in a scratch tree, run the installer,
   and show it REFUSING. Show the **pre-cure** installer against the identical fixture
   reporting no conflict and proceeding. That pair is the acceptance evidence for this item.
3. **The check PRINTS THE SOURCES IT ACTUALLY READ on every run**, including runs that find
   no conflict. A source the harness merges but the check does not read must be visibly
   **unread** rather than silently uncovered -- otherwise the next settings file the harness
   adds inherits exactly this defect in silence. This is the derived-claims law applied to a
   detector's own coverage.
4. **The no-conflict path still installs**, proven by a driven clean install in a scratch
   tree, with the resulting `settings.json` shown.
5. **Idempotence and `-Remove` still hold**, each driven: a second `-Apply` does not duplicate
   our entries, and `-Remove -Apply` removes exactly ours and leaves foreign entries alone.
6. **The residual is stated per-member.** Name what the widened check still does not cover --
   user-scope settings outside the repository, harness versions with different precedence, a
   source added after this cure -- and for each, say whether a detector exists. "No detector"
   is an acceptable answer; an unstated member is not.
7. **A test ships on disk** under `tools/framework/tests/`, anchored to `$PSScriptRoot`, pure
   ASCII, operating only on a scratch tree, leaving zero residue in the real repository, with
   a true exit contract.
8. **Regression:** A1 negative suite 14/14 exit 0; A2 acceptance exit 3; A3 acceptance exit 0;
   A4 acceptance exit 0; the four RESIDUE-KEEP paths untouched; every other sealed hash
   unmoved -- this dispatch moves exactly one.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- The old and new sha256 prefix and byte length of `install-evidence-hooks.ps1`, and the
  ledger entry recording the seal move.
- The **paired driven outputs** from ACCEPTANCE item 2 -- pre-cure missing the conflict,
  post-cure refusing on it. This is the core evidence of the dispatch; a report without it has
  not demonstrated the thing it claims.
- The verbatim sources-read line from ACCEPTANCE item 3, from a run that found no conflict.
- The driven cases from ACCEPTANCE items 4 and 5.
- The per-member residual list from ACCEPTANCE item 6.
- The harness-precedence derivation from P0 item 5, with its source named and its gaps stated.
- Full regression outputs with exit codes.
- An explicit statement of what you did **not** verify.
