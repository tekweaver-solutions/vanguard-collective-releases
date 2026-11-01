# D6 -- BUILD DISPATCH: the post-install framework-maintenance pathway

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>" denote
> `docs/framework/vanguard-collective-local-modes-v2.2.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** A4 authored it and built nothing.
>
> **This is the only one of the seven dispatches buildable under existing authority.** It is
> also the one the other framework-tree dispatches depend on once hooks are installed.

---

## P0 GROUNDING

Read-only, first reply.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. **Does `.claude/settings.json` exist?** This single fact determines whether the problem
   this dispatch solves is live or hypothetical. Report it first.
3. `tools/framework/hooks/evidence-guard-pretooluse.ps1` and the guard-decision function in
   `tools/framework/hooks/lib/evidence-common.ps1` -- **derive from source** exactly which
   staging operations deny.
4. `docs/framework/expanded-schemas.md`, the *Registered decisions* section, the
   **Operator-maintenance pathway** entry -- resolved AS PROCESS with schema impact none, and
   with its disclosed limit.
5. **Design SS4.5 law 8** -- machinery modification is an operator-mediated act.
6. `docs/framework/evidence-write-path-threat-notes.md` SS3.2.4 -- "Machinery commits are
   operator-mediated -- by design".
7. The registered ruling -- the guard denies `git add
   tools/framework/hooks/...` **by design, not by accident**, with the bulk-staging limit
   disclosed.

**HALT AND REPORT if:** the guard no longer denies machinery staging (someone changed it, and
this dispatch's premise has moved), or if the ledger records a maintenance pathway already
written.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; never
  `Invoke-AtomicCommit` (registered defect R2; D3 is its cure).
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-9 bind.
- LEDGER-GOVERNS.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **design, "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)", law 8** -- names the pathway as a registered design item.
- **schemas, "## Registered decisions"**, *Operator-maintenance pathway* -- resolves it AS
  PROCESS: post-install maintenance commits are made by the operator; schema impact none; the
  constraint is on authorship.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 13 (D6). It is a dispatch rather than a
  note because the moment the hooks are installed, D2, D3 and D7 become unstageable by any
  agent session. The pathway is resolved in principle and absent in practice, and installation
  is what makes the absence bite.

NEEDS ITS OWN AMENDMENT: NO
MOVES A SEALED HASH: NO

`docs/framework/**` is inside the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`). This dispatch writes documentation only; it
changes no machinery, which is the point -- a pathway that required editing the guard to work
would be the guard's own defect, not its pathway.

## WRITE SURFACE

- `docs/framework/**` -- the pathway document (new)
- `.mission/ledger/entries.jsonl` -- append only

## FORBIDDEN

- **Editing the guard, the installer, the hooks, or the settings fragment.** All of it is
  sealed A1 machinery, and a pathway that begins by weakening the constraint it exists to work
  within has removed the property rather than served it.
- **Granting an agent session the staging capability the guard withholds.** Schemas records
  this explicitly: the pathway is written down so a future runner design does not quietly
  grant it.
- **Recommending bulk staging** (`git add .`, `git add -A`, `git commit -a`) as the pathway.
  It reaches the machinery anyway -- that is the disclosed limit -- and enshrining a known
  bypass as procedure would convert an accident tripwire into a formality.
- **Recommending uninstalling the hooks to do maintenance and reinstalling after.** It works,
  and it means the maintenance window is exactly the window with no evidence capture.
  If you judge it the least-bad option, say so explicitly and state that cost; do not present
  it as clean.
- Claiming the pathway makes machinery modification safe. It makes it **attributable**.

## ACCEPTANCE

1. **The document states, per-member, exactly which operations deny** -- derived from the
   guard source at grounding, not transcribed from prose about it -- and for each, what the
   operator does instead.
2. **The pathway is executable by a human at a terminal without agent assistance**, written as
   steps with the actual commands, not as principles.
3. **It covers the three live cases by name**: D2 (`evidence-common.ps1`), D3
   (`mission-lib.ps1`), D7 (`install-evidence-hooks.ps1`). Each of those moves a sealed hash,
   so each also needs a ledger entry; the pathway says who writes it and when.
4. **The disclosed limit is carried inline**: bulk staging reaches the machinery anyway, so
   the property is **not enforced** and the guard is an accident tripwire, not a boundary. A
   pathway document that omits this reads as a security control and is not one.
5. **The pathway does not depend on the hooks being uninstalled** -- or, if the honest answer
   is that some case requires it, that case is named with its evidence-gap cost stated.
6. **It is demonstrated, not asserted.** Drive at least one denial and show the guard's
   verbatim output, then show the pathway's alternative producing the commit. If hooks are not
   installed, drive the guard script directly with a synthesized payload, and label that as
   the weaker evidence it is.
7. **Design SS4.5 law 8 and the schemas entry are cited and not contradicted.** If your
   derivation contradicts either, the contradiction is surfaced rather than resolved silently
   (law 9).
8. **Regression:** A1 14/14 exit 0; A2 acceptance exit 3; A3 acceptance exit 0; RESIDUE-KEEP
   untouched; all sealed hashes unmoved -- this dispatch moves none.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- The `.claude/settings.json` presence fact from grounding item 2.
- sha256 prefix and byte length of the document created.
- The **driven denial** and the **driven alternative** from ACCEPTANCE item 6, verbatim, with
  a plain label saying whether the guard was live or driven synthetically.
- The per-member deny list with the source lines it was derived from.
- Full regression outputs with exit codes.
- An explicit statement of what you did **not** verify.
