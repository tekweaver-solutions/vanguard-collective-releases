# D4 -- BUILD DISPATCH: the origin-side attestation channel

> **Citation convention**. `LM2-ADR-0NN` / "design SS<n>" denote
> `docs/framework/vanguard-collective-local-modes-v2.2.md`. "spec SS<n>" denotes
> `docs/framework/mission-verify-spec.md`. "schemas SS<n>" denotes
> `docs/framework/expanded-schemas.md`. `SS` is this file's ASCII spelling of the section mark.
>
> **This is a prompt, not a build.** A4 authored it and built nothing.

---

## P0 GROUNDING

Read-only, first reply.

1. `git rev-parse HEAD`, `git status --porcelain=v1`, ahead/behind.
2. `docs/framework/mission-verify-spec.md` SS6 IN FULL -- the independence ladder (SS6.1), the
   motivating datum from this repository (SS6.2), and the sketch with its four residuals
   (SS6.3). Expect sha256 prefix `46312f76`.
3. `docs/framework/expanded-schemas.md` SS13 (Push Authorization) and design SS10.5 / SS12.4 --
   what this channel does **not** replace.
4. Confirm `.github/` still does not exist. If it does, HALT: someone widened the surface and
   this dispatch's premise has moved.
5. Derive what host tooling is actually available -- `gh --version`, and whether an
   authenticated context exists -- **without displaying any credential bytes**. Availability
   is a channel fact; it is not a build authorization.
6. `git ls-remote origin refs/heads/main` and `git reflog show origin/main` -- the two facts
   disk can supply about origin. Note the SS6.2 datum: at A3 grounding these were the only
   local evidence that a push had happened, and the A2 seal text said the opposite.

## STANDING LAW

- No `git push`. No force flags. Explicit-path staging only.
- Ceremony commits use `git add <explicit paths>` + `git commit -F`; never
  `Invoke-AtomicCommit` (registered defect R2; D3 is its cure).
- Strict UTF-8, no BOM, LF-only; any `.ps1` is **pure ASCII**.
- Design SS4.5 laws 1-9 bind; law 4 governs every claim about what this channel detects.
- LEDGER-GOVERNS.
- **Credentials are never displayed.** No secret bytes appear in any artifact, evidence file,
  report, log, or command line. Where a credential must be identified at all, identify it by
  hash prefix. This is standing law in this repository and it is restated here because this
  is the one dispatch whose subject is an authenticated remote channel.

## AUTHORITY

- **spec, "### 6.3 The interim independent channel -- REGISTERED, NOT BUILT"** and **spec,
  "## 12. Registered by this document"** -- register the channel as REGISTERED, NOT BUILT, and
  record that building it requires widening the write surface.
- **local-modes v2.3 (`docs/framework/vanguard-collective-local-modes-v2.3.md`), "## 14. Adoption Sequence -- status at v2.3, and the complete remaining backlog"**
  -- registers this dispatch as backlog item 20 (D4).

NEEDS ITS OWN AMENDMENT: YES
AMENDMENT COVERS: .github/**
MOVES A SEALED HASH: NO

`.github/**` is outside the dispatch set's standing write surface (`docs/framework/**`, `tools/framework/**`,
`tools/mission-cli/config/**`, append-only `.mission/ledger/` and `.mission/amendments/`) entirely, and `.github/` does not exist in this
repository. This is a scope fact, not an intention. The amendment that admits `.github/**`
should also rule on **who may modify the workflow file after it exists**, because the first
residual below makes that question load-bearing rather than administrative.

## WRITE SURFACE

- `.github/workflows/<name>.yml` -- the workflow (new)
- `docs/framework/**` -- documentation of the channel and its residuals
- `.mission/ledger/entries.jsonl` -- append only
- `.mission/amendments/<the authorizing amendment>.yaml` -- placement only

## FORBIDDEN

- **Executing a push**, or building anything that pushes. This channel observes; it does not
  act.
- **Reading the pushed head from a command the workflow shells out to.** Take it from the
  host-supplied event context. A workflow that runs `git rev-parse` to learn what was pushed
  has re-created the middle rung inside the top rung.
- **Posting to a surface the session can write.** If the session can write it, the top rung
  collapses back to the middle and the machinery buys nothing.
- **Treating absence as agreement.** A workflow that fails to run is silence; a consumer
  reads it as `UNREACHABLE` and refuses.
- Presenting a hook-captured `git ls-remote` as origin-side proof. Spec SS6.1: this document
  specifies the top rung and does not possess it; claiming otherwise is the overclaim class
  wearing the clothes of a security control.
- Claiming this attests **authorization**. It attests what origin **received**. Authorization
  is the Push Authorization artifact's job (schemas SS13).
- Displaying any credential, token, or secret in workflow logs, artifacts, or your report.

## ACCEPTANCE

1. **The workflow triggers on push to the tracked branch** and posts the pushed tip, a
   timestamp, and the run's own identity to an operator surface.
2. **The head is read from the host-supplied event context**, not from a shelled-out command.
   Show the mechanism.
3. **The operator surface has no session write path**, and that claim is demonstrated
   per-member: name the surface, name what write access the session has to it, and show the
   check you ran. "The session cannot write it" asserted without a demonstration is exactly
   the class claim law 4 forbids.
4. **History is retained** so a later reader compares a sequence rather than a snapshot.
5. **Silence is consumable as `UNREACHABLE`.** A consumer can distinguish "the workflow ran
   and reported X", "the workflow ran and reported nothing", and "the workflow did not run".
   Three states, three signals, demonstrated.
6. **All four residuals from spec SS6.3 are carried WITH the artifact, inline, not appended
   as a caveats section:** whoever can push can alter the workflow file, so the attestation
   is only as independent as push authorization is; the operator surface must be
   session-unwritable; silence must not read as consent; and it attests receipt, not
   authorization.
7. **The independence claim is stated at its true strength.** Altering the workflow is a
   visible, committed, reviewable act -- which is more than the middle rung offers and is
   **not** a boundary. Say both halves.
8. **Spec SS4.4's ORIGIN-ATTESTATION arm can consume this channel** as its second, non-shared
   -failure-mode channel, and the consumption contract is written down. If D1 has shipped,
   demonstrate the arm consuming it; if not, specify the contract and say plainly that it is
   unexercised.
9. **Regression:** A1 14/14 exit 0; A2 acceptance exit 3; A3 acceptance exit 0; RESIDUE-KEEP
   untouched; sealed hashes unmoved.

## PROOF-OF-ACT

- `git rev-parse HEAD` and `git status --porcelain=v1`, verbatim, before and after.
- sha256 prefix and byte length for every file created.
- **A real triggered run**, with its output quoted verbatim and its identity shown -- or, if
  no push authorization exists to trigger one, an explicit statement that the workflow is
  **unexercised**, which is a materially weaker result and must not be reported as anything
  else.
- The demonstration required by ACCEPTANCE item 3.
- The three-state demonstration required by ACCEPTANCE item 5.
- Confirmation that no credential bytes appear anywhere in what you produced.
- An explicit statement of what you did **not** verify.
