# D11 -- BUILD DISPATCH: stream-payload identity

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>"
> denote `docs/framework/vanguard-collective-local-modes-v2.3.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** Its author built nothing.
>
> **D11 IS NOT REGISTERED IN design SS4.7.** It was registered by **amendment**, after
> grounding found the defect on disk. The corresponding design-document
> correction is **ERRATUM E6**, carried by the operator into v2.4 and not written by this
> dispatch.
>
> **IT IS NOT A LIFECYCLE BUG AND NOT A CAPTURE-VISIBILITY BUG.** It is a **key collision in a
> namespace a prior seal ruled was not a key**. It shares no root cause with D10 or D8 and is
> independent of the D10-then-D8 chain. It is precondition (c) of its amendment's commit gate.

---

## P0 GROUNDING

Read-only, first reply. Report each with the command and its raw output.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. **THE DEFECT, RE-DERIVED FROM DISK -- DO NOT TRANSCRIBE IT FROM THIS DISPATCH.** Find a
   `.mission/evidence/session-*/manifest.json` in which two entries declare the same
   `"path": "streams/NNNNNN.json"`. A collision has this shape: two consecutive entries,
   for example entries 13 and 14, both declaring
   `streams/000013.json`, one millisecond apart, with `streams/000014.json` absent and
   `streams/000015.json` present. Report, per member:
   - the two entries with their `ts`, `tool`, `command` and `stdout_sha256`;
   - which entry's payload the surviving file actually holds, decided by reading it;
   - the manifest's `entry_count` against the count of stream files on disk;
   - the manifest's `state`, `unparsable_lines`, `hook_errors_present` and `streams_committed`.
   If that session is gone, find another instance. **If you cannot find one, HALT** -- do not
   build against a defect you have not observed (law 10). Note it is a race and may be rare;
   absence in one sample is not absence of the defect, and saying so is part of the report.
3. **`seq` allocation and stream naming, from source** (`tools/framework/hooks/lib/
   evidence-common.ps1` sealed `189f811b`, `tools/framework/hooks/evidence-post-tool-use.ps1`
   sealed `169611f0`) -- derive exactly where `seq` is computed, where the stream filename is
   formed from it, and where the file is written. Confirm `seq` is `(non-blank log lines) + 1`.
4. **Where `path` is projected into the manifest** (`evidence-stop-finalize.ps1`, sealed
   `d1f69b6b`).
5. **The schema's `path` field** (`docs/framework/evidence-manifest.schema.json`, sealed
   `2a04099d`) -- what it declares, and whether uniqueness is asserted anywhere.
6. **A2's N-e resolution**, read in full from `docs/framework/expanded-schemas.md` (sealed
   `db3a8946`), *Registered decisions*: `seq` DECLARED NON-UNIQUE, NOT MADE SAFE; treat it as an
   ordering hint and never as a key.
7. **The registering amendment's ruling and finding** -- the ruling, the per-member finding, and the falsification.

**HALT AND REPORT if:** no collision instance can be found anywhere on disk; or `seq` is already
decoupled from the stream filename; or A2's resolution reads differently from item 6.

**A NOTE ON GROUNDING, BECAUSE IT WILL BITE YOU.** With the A1 guard live, `Get-FileHash` and any
shell command naming `tools/framework/hooks` are DENIED. Read those sources with the **file
tools**. Read the evidence store with the file tools too -- the guard denies shell reads of
`.mission/evidence` and `.mission-runtime/evidence`. Report any denial verbatim; it is the
standing condition, and your anchor basis for the sealed set is then
porcelain-absence, which is **strictly weaker than a digest**. Say so.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; **never**
  `Invoke-AtomicCommit` (a registered defect). Ledger appends use `-NoCommit`.
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-10 bind. Laws 3, 4, 6, 9 and 10 govern the acceptance.
- LEDGER-GOVERNS. AM files are immutable once placed.
- Evidence is verbatim fresh-run output plus sha256 prefixes.

## AUTHORITY

- **The registering amendment** (P0 GROUNDING item 7) -- the registration, the operator ruling
  that separated it from D8 and D10, and the candidate space.
- **The collision, per member, with its evidence** (P0 GROUNDING item 2).
- **design, "### 4.6 Erratum E5 -- four SS4.1 assumptions falsified by the live harness"**
  -- E5-ii: `seq` derives from log length, not a call counter, which is the allocation that
  collides.
- **schemas, "## Registered decisions"**, row N-e, and
  **schemas, "### The append-only log (`log.jsonl`)"** -- the resolution this dispatch **falsifies**.

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: tools/framework/hooks/evidence-post-tool-use.ps1, tools/framework/hooks/lib/evidence-common.ps1, tools/framework/hooks/evidence-stop-finalize.ps1, tools/framework/tests/test-a1-negative.ps1, docs/framework/evidence-manifest.schema.json, docs/framework/expanded-schemas.md
MOVES A SEALED HASH: YES
SEALED FILE: docs/framework/evidence-manifest.schema.json 2a04099d
SEALED FILE: docs/framework/expanded-schemas.md db3a8946
SEALED FILE: tools/framework/hooks/evidence-post-tool-use.ps1 169611f0
SEALED FILE: tools/framework/hooks/evidence-stop-finalize.ps1 d1f69b6b
SEALED FILE: tools/framework/hooks/lib/evidence-common.ps1 189f811b
SEALED FILE: tools/framework/tests/test-a1-negative.ps1 a27d008b

**Why an amendment is required.** Not for the write surface -- `tools/framework/**` is inside
the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`) -- but because it **moves sealed hashes** (each recorded in a ledger
entry), because the commit is
operator-mediated, and because it **reverses a sealed A2 resolution**, which is a governance act
and needs an amendment that says it is reversing one.

**THE ENUMERATION ABOVE IS DERIVED, NOT AUTHORED, AND THE FIRST DRAFT OF THIS DISPATCH PROVES WHY
THAT MATTERS.** It is the intersection of this dispatch's WRITE SURFACE with the full,
non-abbreviated set of sealed anchors. The first draft hand-listed FIVE and omitted
`docs/framework/expanded-schemas.md` (`db3a8946`), which its own WRITE SURFACE declares -- the
exact defect A4's validator caught in D2 and for which A4's G9 check was built. A builder
following that draft literally would have moved six sealed hashes and recorded five.

Note the sixth carries a condition: `expanded-schemas.md` is touched only if the amendment directs
the N-e correction be made here rather than deferred to E6, and **the default is DEFER**. It is
enumerated anyway, because a conditional path in a write surface is still a declared path.

Report old and new prefix **and byte length** for each that moves, an explicit "declared and did
not move" for each that does not, and record every one in a ledger entry.

**THE A2 FALSIFICATION IS PART OF THE DELIVERABLE, NOT A FOOTNOTE.** "Treat `seq` as an ordering
hint and never as a key" cannot hold when `seq` **is** the stream filename: that makes it a key by
construction, no matter how a consumer chooses to treat it. Guidance to downstream readers cannot
repair a namespace collision upstream of them. Design, "### 4.5 Evidence-plane laws (earned by the A1 program, LM2-ADR-021 addenda)",
law 9 -- a resolution refuted by
evidence is reversed on the record, not defended. Your ledger entry states the reversal; **E6 in
the design document is the operator's act, not yours.**

## WRITE SURFACE

- `tools/framework/hooks/evidence-post-tool-use.ps1`
- `tools/framework/hooks/lib/evidence-common.ps1`
- `tools/framework/hooks/evidence-stop-finalize.ps1`
- `tools/framework/tests/test-a1-negative.ps1`
- `docs/framework/evidence-manifest.schema.json` -- only if `path` semantics change
- `docs/framework/expanded-schemas.md` -- only if the amendment directs the N-e entry be
  corrected here rather than deferred to E6; **default is DEFER**
- `.mission/ledger/entries.jsonl` -- append only, `-NoCommit`

All are inside the protected-path set. **NONE UNDER `tools/framework/**` IS STAGEABLE BY AN AGENT SESSION**;
the commit is an operator act. Hand over the exact `Get-FileHash` and `git add` commands and
record that you did.

## FORBIDDEN

- **Restating the falsified resolution.** A cure that keeps `seq` as the filename and adds
  guidance about how to read it has not cured anything.
- **Repairing existing residue.** The destroyed payload is destroyed. Do not reconstruct,
  back-fill, or synthesize a `streams/000014.json`; fabricating evidence to cover an evidence
  defect is the worst available outcome. Existing residue is D9's, and D9's Q1 is ruled NOT
  COMMITTED.
- **Curing E5-ii/iii or E5-iv here.** Those are D8 and D10.
- **Introducing an agent-writable path** into the stream store.
- **Choosing a scheme without stating its trade.** A content-hash name makes two identical
  payloads share one file -- deduplication, which may be desirable or may break a
  one-entry-one-file assumption elsewhere. Derive which from the sealed source; do not assume.
- **Touching `.claude/`, the mission record, `src/`, or `tests/`.**

## ACCEPTANCE

Stated as a goal condition a validator can decide from disk.

1. **TWO CONCURRENT HOOK INVOCATIONS CANNOT RESOLVE THE SAME STREAM FILENAME.** Demonstrated by
   DRIVING concurrency -- the defect is a race and inspection cannot decide it (law 6, law 10).
   A demonstration that runs the two writes sequentially has not tested the thing.
2. **Every manifest entry's declared `path` resolves to a file whose bytes hash to that entry's
   recorded `stdout_sha256`.** A detector exists for this, it is demonstrated firing on a
   constructed violation, and it is demonstrated silent on a clean set. Per member, per law 4.
3. **`entry_count` and the count of distinct stream files agree, or the disagreement is
   DETECTED.** A collision leaves `entry_count` one above the stream files on disk while
   the manifest reads `streams_committed: true`, and nothing reports it.
4. **The chosen scheme's trade is stated on the face of the artifact**, per FORBIDDEN above.
5. **Ordering is still recoverable.** `seq` may stop being the filename; entries must still be
   orderable, and how is stated. N-g's resolution (gap detection lives in the log, not the
   manifest) is either preserved or its change is declared.
6. **A2's N-e resolution is recorded as FALSIFIED in the ledger**, with the reason -- `seq` is the
   filename, therefore a key by construction -- and with E6 named as the design correction the
   operator carries.
7. **`test-a1-negative.ps1` covers the collision case and the detector**, with counts derived
   rather than typed.
8. **Regression.** RESIDUE-KEEP untouched; porcelain compared before and after; acceptance suites
   **operator-run**; any suite not executed reported as NOT RUN with the denial
   cited, never as a result.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- **The re-derived collision instance** from grounding item 2, per member, verbatim -- including
  which entry's payload the surviving file holds, decided by reading it.
- **The driven concurrency demonstration** from ACCEPTANCE item 1, verbatim, with enough detail
  that a reader can see the two invocations really overlapped.
- **The detector firing and staying silent** from ACCEPTANCE item 2, both runs, verbatim.
- Old and new sha256 prefix **and byte length** for every anchor that moved, plus an explicit
  "declared and did not move" line for each declared anchor that did not.
- The ledger entry id and line number, carrying the N-e falsification.
- The exact commands handed to the operator for staging.
- An explicit statement of what you did **not** verify -- including, if it applies, that the race
  was observed only under the conditions you could produce.
