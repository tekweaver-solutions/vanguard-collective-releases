# D1 -- BUILD DISPATCH: `mission verify`

> **Citation convention** (v2.2's standing convention). `LM2-ADR-0NN` and
> "design SS<n>" denote `docs/framework/vanguard-collective-local-modes-v2.2.md`. "schemas
> SS<n>" denotes `docs/framework/expanded-schemas.md`. "spec SS<n>" denotes
> `docs/framework/mission-verify-spec.md`. Bare `ADR-0NN` denotes the on-disk file under
> `tools/mission-cli/config/`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** A4 authored it and built nothing. Nobody may act on it
> until the amendment named under AUTHORITY exists and is ratified.

---

## P0 GROUNDING

Read-only, in your first reply, before you write a line. Re-derive from disk; do not trust
this dispatch's figures, and report any that no longer hold.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind against origin.
2. `docs/framework/mission-verify-spec.md` IN FULL. It is the specification you build to.
   Expect sha256 prefix `46312f76`, 43712 bytes.
3. `docs/framework/expanded-schemas.md` SS5 (`runner_anchors`, `SuiteAnchor`) and SS12
   (Evidence Manifest, the append-only log, Constraints). Expect `db3a8946`.
4. `docs/framework/evidence-manifest.schema.json` -- normative for the manifest artifact.
   Expect `2a04099d`.
5. `tools/framework/hooks/lib/evidence-common.ps1` -- the three functions you call:
   `Get-EvidenceState`, `Test-EvidencePlaneParity`, `Test-EvidenceStreamIntegrity`. Expect
   `189f811b`.
6. `tools/mission-lib.ps1` and two existing verbs (`tools/mission-dispatch.ps1`,
   `tools/mission-close-milestone.ps1`) -- the house style your verb must match.
7. This dispatch's authorizing record and the amendment named under AUTHORITY.

**HALT AND REPORT if:** any expected hash has moved; the spec is absent; or the amendment
under AUTHORITY does not exist on disk. A moved hash means the ground under this dispatch
shifted, and building on it would produce an artifact nobody can re-derive.

## STANDING LAW

- No `git push`. No force flags of any kind. Explicit-path staging only -- never `git add
  -A`, never `git add .`, never `git commit -a`.
- Ceremony commits use `git add <explicit paths>` + `git commit -F <file>`. Do **not** use
  `Invoke-AtomicCommit`: its failure path runs `git clean -fd -- .mission` and would delete
  the operator's RESIDUE-KEEP files (registered defect R2; D3 is its cure).
- Strict UTF-8, no BOM, LF-only. Any `.ps1` you write is **pure ASCII** -- a BOM-less `.ps1`
  is parsed by PowerShell 5.1 in the ANSI codepage, so a non-ASCII character in a regex
  decodes to mojibake and the match silently never fires.
- Design SS4.5 laws 1-9 bind. In particular: law 3 (derived claims -- itemizations and
  counts are mirrored from what the tests emit, or deleted), law 4 (detection claims stated
  and demonstrated per-member), law 6 (execution beats inspection), law 9 (rulings are
  testimony).
- Amendment files are immutable once placed. Status transitions live in the ledger
  (LEDGER-GOVERNS).
- Evidence is verbatim fresh-run output with the command shown, plus sha256 prefixes for
  every file created or modified. Anything else is testimony and is labelled as such.

## AUTHORITY

- **spec, "# `mission verify` -- Specification"** -- the sealed specification this builds to.
- **design, "### 4.3 Automated cross-session verification (`mission verify`)"** and
  **design, "### 11.4 ADR-022 -- `mission verify` as a dispatch gate"** (the design's heading as it reads; the
  decision is LM2-ADR-022, not the on-disk adr-022) -- specify the gate itself.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 14 (D1), at `tools/mission-verify.ps1`, needing its
  own amendment.
- **the design brief (`docs/framework/multi-agent-framework-design-brief.md`), "### 5.5 Amendment"** -- the protocol
  through which that amendment is proposed and approved.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: tools/mission-verify.ps1, tools/mission-lib.ps1
MOVES A SEALED HASH: NO

**Why an amendment is required, derived rather than assumed.** `tools/mission-cli/` contains
only `config/`. Every mission verb is a flat script at `tools/*.ps1` --
`mission-dispatch.ps1`, `mission-close-milestone.ps1` and fourteen siblings. So `mission
verify` lands at `tools/mission-verify.ps1` and consumes `tools/mission-lib.ps1`, and
the dispatch set's standing write surface under `tools/` is `tools/framework/**` and `tools/mission-cli/config/**` and no other part of
`tools/`. This dispatch cannot be built under that surface, nor under the amendment that
registered the dispatch set. **Do not relocate the
verb into `tools/framework/` to fit the standing surface** -- that would put a mission verb
outside the mission CLI to dodge an amendment, and the next reader would find it nowhere it
belongs.

## WRITE SURFACE

- `tools/mission-verify.ps1` -- the verb (new)
- `tools/mission-lib.ps1` -- only if shared helpers are genuinely needed; prefer not to touch it
- `.mission/ledger/entries.jsonl` -- append only
- `.mission/amendments/<the authorizing amendment>.yaml` -- placement only

## FORBIDDEN

- Editing **any** sealed A1/A2/A3 artifact. You **call** `evidence-common.ps1`; you never
  modify it. The NB-2 delta is D2's build and not yours -- if you hit the NB-2
  false positive while testing, report it and route around it; do not fix it here.
- Creating `tools/mission-cli/config/expected-failures.yaml`, or reading
  `.mission/green-gate/**` as a substitute for it. See ACCEPTANCE item 6.
- Creating `.github/**` (that is D4), touching root `.gitattributes`, or moving the
  delegation ladder.
- Adding `git rev-parse origin/<branch>` to the derivation command set. It reads a local
  cache updated only by fetch or push and is not an observation of origin. Spec SS3.2
  excludes it by name and SS6.2 records the incident that earned the exclusion.
- Inventing a `NOT_APPLICABLE` for any subject the schema does not scope away. The sole
  admissible member is the `suite` block on read-only and micro-ceremony dispatches.
- Retrying an `UNREACHABLE` channel into a verdict.
- Any allow-side exemption not already named in the spec. Each one is a standing claim about
  arbitrary binary semantics and fails open (design SS4.5 law 2); each new one needs its own
  amendment.

## ACCEPTANCE

Stated as a goal condition. A validator decides these from disk, not from your report.

1. **The four arms exist, each stated and demonstrated per-member** -- ANCHOR, MANIFEST,
   PLANE-PARITY, ORIGIN-ATTESTATION -- with every subject spec SS4.1-4.4 names, each carrying
   its own detector and its own residual in the emitted report. An arm entry lacking either
   is malformed and verify fails rather than emitting it.
2. **The outcome vocabulary is closed and the gate rule is literal.** `MATCHED`, `DIVERGED`,
   `MOVED`, `UNREACHABLE`, `ABSENT`, `NOT_APPLICABLE`; proceed only on `MATCHED` or
   `NOT_APPLICABLE`; every other outcome refuses. `MOVED` is not foldable into either
   neighbour, and a driven case proves each collapse would change a verdict.
3. **The exit contract is true as written**: `0` ran/PASS, `1` ran/REFUSE, `2` did not
   complete. A consumer reading only the code can tell "checked, refused" from "did not
   check". Driven at every value.
4. **MANIFEST runs both checks and neither subsumes the other** -- derived state via
   `Get-EvidenceState`, and schema validation against the sealed
   `evidence-manifest.schema.json`. NB-1's resolution: a fieldless valid-JSON log line
   yields a manifest that fails schema validation while still deriving `FINALIZED`. A driven
   case proves an implementation running only the state derivation reports the artifact good.
5. **PLANE-PARITY reports parity and stream integrity as SEPARATE subjects**, because
   `Test-EvidencePlaneParity` reaches stream bodies by existence only and no hash is
   compared there. Reporting parity alone as "the plane is intact" is the class claim law 4
   forbids.
6. **`expected_failures_matched` reports `ABSENT` and REFUSES.** It is not reported
   `NOT_APPLICABLE`, and the green-gate file is **not** silently read in its place.
   Substituting an undeclared source for a declared one is the same defect wearing a
   solution's clothes.
7. **NB-2's ordering rule is obeyed** even though the code delta is D2's: manifest state
   first, plane parity next, stream integrity last and only over tool-call entries; a
   `_precompact` entry with `captured: false` is a CAPTURE GAP in its own category and never
   a stream-integrity mismatch.
8. **Every derivation prints its command and its raw output**, and both are written to the
   evidence store. A derivation appearing in a verdict without them is inadmissible
   (LM2-ADR-022's own tradeoff).
9. **`basis` is mandatory and complete** -- which tree, at which HEAD, untracked included or
   not, and which `hash_class`. Class mismatch reports `MOVED`, never `DIVERGED`. The
   misdeclared-hash-class residual is disclosed as having no detector.
10. **Verify refuses when it cannot write its own evidence.** A gate whose record is
    optional degrades silently into a ceremony.
11. **The L0/L1 pasted form is documented** and is the same check in a second carrier: same
    command set, same vocabulary, same gate rule, ending by naming what it did not check.
12. **An acceptance test ships on disk** (A1 R1 / A2 R-A2-1 precedent), anchored to
    `$PSScriptRoot`, pure ASCII, with a true exit contract, deriving its populations rather
    than carrying an inventory, and printing its own reach wherever a check is narrower than
    its name.
13. **Regression:** A1 negative suite 14/14 exit 0; A2 acceptance exit 3 (documented
    post-seal clean result away from its anchor); A3 acceptance exit 0; the four RESIDUE-KEEP
    paths untouched; all sealed hashes unmoved.

## PROOF-OF-ACT

Nothing below is optional, and a claim without its evidence is testimony.

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- sha256 prefix and byte length for every file created or modified.
- The full acceptance suite output, verbatim, with its exit code shown.
- **Driven negative cases**, not inspected ones: for each acceptance item that can fail,
  a case that makes it fail, with the failure message naming the specific defect -- plus a
  positive control on a clean mirror. Execution beats inspection (law 6), and this program
  has three separate instances of a defect surviving because no case walked that path.
- The regression results above, each with its exit code.
- An explicit statement of what you did **not** verify.
