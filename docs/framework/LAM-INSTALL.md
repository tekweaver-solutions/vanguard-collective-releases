# LAM-INSTALL — the operator's procedure for adopting the Local Autonomous Mode toolchain

**Who runs this: the operator, at their own terminal. Every step below is operator-only, and not
by convention.** The agent that built this toolchain can neither write, stage, hash **nor run**
anything under `tools/framework/**`, and cannot write `.claude/settings.json` at all — the A1 guard
denies all of it, in every repository on the filesystem, because it matches protected paths by
**canonicalised suffix with no repository rooting** (erratum E7). That is the property that makes
the swap trustworthy: the thing being replaced cannot be replaced by the thing that wants it
replaced.

**Read this whole document before running step 1.** Step 3 moves a sealed hash, and a sealed-hash
move is an amendment-before-source act.

---

## 0. Preconditions

| # | precondition | how to check |
|---|---|---|
| 0.1 | You are on the branch you intend to install into, and the working tree is clean apart from the four RESIDUE-KEEP entries | `git status --porcelain` |
| 0.2 | The next-gen hooks are present and committed | `git log --oneline -1 -- tools/evidence-hooks-next` |
| 0.3 | You have read §5 (the guard addition) and §6 (retirement), because both are part of the install and neither is optional | — |
| 0.4 | You can restore the previous state without consulting anyone | §8 |

**A note on what "clean" means here.** The evidence plane is *deliberately* untracked until a
ceremony boundary commits it, and `verify-<id>/` self-capture directories are permanent runtime
residue. Do not tidy them. `Remove-Item` under `.mission` is denied unconditionally, which is the
mechanism agreeing with this paragraph rather than the paragraph asking you to trust it.

---

## 1. What actually changes

Two hook sets exist. **They are not the same shape, and a naive directory replacement destroys
functionality.**

> **BASIS: LF-NORMALISED BYTES.** Every `bytes` and `sha256 (16)` figure in **both** tables below is
> taken over the file's content **with every CRLF collapsed to a single LF** — not over the bytes
> sitting in your working copy. Where `.gitattributes` turns conversion off for these paths (the
> template's `* -text`) the working copy is LF; where git converts them -- `core.autocrlf=true` and **no entry covering `tools/framework/**` or
> `tools/evidence-hooks-next/**`** (`git check-attr -a <path>` answers nothing), or a `text`/`eol=crlf` rule -- it is CRLF. Either
> way the LF-normalised form is **byte-identical to the git blob**. So there are two ways to reproduce any row, and they agree:
> ```powershell
> # (a) from the blob -- which IS the normalised form for these paths
> git cat-file -s "HEAD:tools/framework/hooks/lib/evidence-common.ps1"          # -> bytes
>
> # (b) from the working copy, normalised in-process -- no git, byte-safe, and this is
> #     exactly what instrument-WP-5.ps1 K-5 does
> $raw = [System.IO.File]::ReadAllBytes('tools/framework/hooks/lib/evidence-common.ps1')
> $lf  = New-Object 'System.Collections.Generic.List[byte]'
> for ($i = 0; $i -lt $raw.Length; $i++) {
>     if ($raw[$i] -eq 13 -and ($i + 1) -lt $raw.Length -and $raw[$i + 1] -eq 10) { continue }
>     [void]$lf.Add($raw[$i])
> }
> $lf.Count                                                                     # -> bytes
> [BitConverter]::ToString(
>     [Security.Cryptography.SHA256]::Create().ComputeHash($lf.ToArray())
>   ).Replace('-','').ToLowerInvariant().Substring(0,16)                        # -> sha256 (16)
> ```
> **`Get-FileHash` REPRODUCES THESE ROWS ONLY ON AN LF WORKING COPY.** On a CRLF working copy it
> hashes the CRLF bytes, so for the first row below it answers another hash over more bytes than
> the row reads — for a file nothing is wrong with. The paragraph at the foot of this
> section told you to use `Get-FileHash` for four rounds while every figure was on the other basis,
> and that single mismatch is what `WP-5 K-5` reported as **sixteen stale rows** until this was
> stated.
>
> **EQUALITY OF THE TWO ROUTES IS MEASURED, NOT ASSUMED.** For all 16 files below, route (b)'s byte
> count equals `git cat-file -s`'s answer and route (b)'s sha equals the blob's sha — measured for
> every file, not spot-checked, at the commit that states this. A normalisation that merely *usually*
> agrees would be a fourth instance of this table's own defect class, so it was driven: run the pair
> above on any row.

**Current (A1), `tools/framework/hooks/` — the sealed set:**

**BASIS: LF-NORMALISED BYTES** (the block above — *not* `Get-FileHash`).

| file | bytes | sha256 (16) |
|---|---:|---|
| `evidence-guard-pretooluse.ps1` | 8912 | `73f1c0a4a0363696` |
| `evidence-post-tool-use.ps1` | 7152 | `331c021f57936fea` |
| `evidence-stop-finalize.ps1` | 22846 | `27e704e26bfd89c5` |
| `evidence-pre-compact.ps1` | 2766 | `5428c5a041bc033a` |
| `evidence-verify-placement.ps1` | 11903 | `142e8892f5fc5aa4` |
| `evidence-place-substrate.ps1` | 32035 | `29f4943d26017eac` |
| `lib/evidence-common.ps1` | 105431 | `3849bd6d46544e03` |
| `settings.evidence-hooks.json` | 2531 | `a5a8c1663a88e9c8` |

**Next generation, `tools/evidence-hooks-next/hooks/`:**

**BASIS: LF-NORMALISED BYTES** (the block above — *not* `Get-FileHash`).

| file | bytes | sha256 (16) |
|---|---:|---|
| `evidence-guard-pretooluse.ps1` | 5409 | `4835cff6ed2b02b8` |
| `evidence-post-tool-use.ps1` | 15287 | `5f08812113d0979e` |
| `evidence-stop-finalize.ps1` | 6235 | `909331638d77340e` |
| `evidence-pre-compact.ps1` | 2055 | `3d56009be038d655` |
| `evidence-dispatch-end.ps1` | 8310 | `a5a3c272bdd00b9f` |
| `evidence-pre-push.ps1` | 10059 | `160976931b1e7b45` |
| `check-prepush-installed.ps1` | 2067 | `ed36ac62e4b4a468` |
| `lib/evidence-common.ps1` | 503493 | `d2a401cfb3fcd709` |

> **THIS TABLE WAS STALE IN 5 OF 6 ROWS, and the library row was off by 141,267 bytes** — it read
> 29246 against a live 170513. (That figure read *131,946* until a later WP-5 reading subtracted it:
> 170513 − 29246 = 141,267. The one **typed** number in the paragraph whose entire thesis is that
> typing plausible figures destroys a table's value — and a later orchestrator appended a
> paragraph to this very note about re-deriving rather than typing, reading straight past it.) Found by an independent reader (a WP-5 validation), who also
> confirmed the **sealed A1 table above is 7/7 accurate**. Two rows are new: `evidence-pre-push.ps1`
> and `check-prepush-installed.ps1` did not exist when this table was written, and the change that brought the push gate
> added them without adding rows.
>
> **The figures above were RE-DERIVED from the files, not corrected by hand.** A hash table edited by
> hand is the same defect with fresher numbers: the whole value of a table like this is that somebody
> measured it, and typing plausible figures destroys exactly that. If you update it, re-derive it.
>
> **AND IT WENT STALE AGAIN ONE ROUND LATER, WHICH IS THE REAL LESSON.** The next validation round moved
> `lib/evidence-common.ps1`, `evidence-post-tool-use.ps1` and `evidence-pre-push.ps1`, so three rows
> were wrong the moment those cures landed. They were re-derived by measurement in the same change
> that moved them. A table like this is stale by default: it is correct only between the last
> measurement and the next edit, so **re-deriving it belongs in the change that moves a file**, not in
> the round that later notices. The A1 sealed table above was re-verified at the same time and is
> 7/7 accurate; its rows are sealed and moving one needs its own amendment, ratified
> before the bytes move.
>
> **And it will go stale again**, because it is the state at one commit and the tree keeps moving.
> That is why the paragraph below says to re-derive every figure before acting on it — a rule this
> table's own five wrong rows are the argument for.
>
> **IT WENT STALE A FOURTH TIME, IN THE SAME ROW, AND THE PARAGRAPH ABOVE PREDICTED IT** (a later
> WP-5 reading, driven). The row read 197648 / `f75d3dfeaf220a0b` against a live 200401 /
> `38f6f9ff53aff666`. It was correct at the previous re-derivation — `git cat-file -s` at that commit
> returns 197648 — and a later commit then changed that library **and nothing else** (+31/−1)
> without re-deriving, breaking the rule this note states on its own face, two paragraphs up.
>
> **So the note was not the cure, and four rounds of writing it more emphatically was not either.**
> A repository-wide search for the row's own figures returned exactly one hit: the row. **No
> instrument, test or gate read them** — which is precisely why nothing caught three of the four
> recurrences until a validator measured by hand. A fact with no reader is a claim about a check
> that does not happen.
>
> **`instrument-WP-5.ps1` K-5 now reads this table.** Every row in both tables is re-measured from
> the file it names and compared, and the member fails if a row is wrong OR if the parse finds fewer
> rows than both tables carry — because a table-checker that silently reads nothing is
> indistinguishable from a table that is correct. The figures are still re-derived by measurement
> and never typed; what changed is that typing one now turns the suite red.
>
> **AND THEN K-5 REPORTED ALL SIXTEEN ROWS STALE — BECAUSE THE READER AND THE TABLE WERE ON
> DIFFERENT BASES** (driven). The figures were, and always had been,
> LF-normalised/blob bytes; the paragraph below declared them *worktree-class* and prescribed
> `Get-FileHash`, which hashed a CRLF working copy; and K-5 measured
> `[System.IO.File]::ReadAllBytes`, also a CRLF working copy. Fifteen of the sixteen rows were
> **numerically correct on the basis they were actually recorded on** and were reported stale anyway.
> The one genuinely stale row was `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1`
> (252347 / `21a3a0b663c1499d`), which matched **neither** basis — ordinary staleness, the file
> moved and nobody re-derived — and it has been re-derived by measurement, not typed. **No sealed
> figure changed:** all eight A1 rows were already exact on the stated basis, so stating the basis
> moved no seal and needed no amendment.
>
> **A FIGURE WITHOUT ITS BASIS IS NOT A MEASUREMENT.** Four rounds of "re-derive, do not type" did
> not help here, because everyone re-deriving was re-deriving the wrong quantity and getting a
> different wrong answer each time. The basis is now stated above **each** table, the reproduction
> is on the page in two independent routes, and K-5 measures the stated basis — and asserts that the
> basis is still stated, so deleting the declaration turns the suite red rather than quietly
> restoring the ambiguity.

> **EVERY RECORDED INSTANCE OF THE NEXT-GEN LIBRARY ROW GOING STALE, ENUMERATED — AND NUMBERED BY
> NONE**. The notes above number their instances as they were
> written. A running number is a count under a definition nobody stated, and this one already reads
> differently on a branch than on `main`. So this list carries commits and figures, and each
> count beneath it names the definition it counts under. Measured at the commit that wrote this list, from
> `git log --full-history` over this page and `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1`,
> every row value and library value read from the blob at the commit concerned (the LF basis above), and
> cross-read against the change history. "Stale from"
> names the commit that moved the library away from the recorded value (the earliest, where several
> branches did); "mainline" means `git log --first-parent` from that commit. **Extended as
> later commits moved the library**, by the same method over the
> commits each extension covered, **and again each time** over every commit `main` brought
> after the previous extension, through each later merge, **so the list
> stays complete** over every commit since the first entry was recorded,
> for the row this page now carries.
>
> - **29246 / `c0a3fe55454ad03b`** — stale when the library moved to 32207;
>   re-derived to 170513 / `9b81e024629b2b25`. Mainline.
> - **170513 / `9b81e024629b2b25`** — stale when the library moved to 183394; re-derived
>   to 183394 / `d6b7b44af8900f53`. Mainline.
> - **183394 / `d6b7b44af8900f53`** — stale when the library moved to 184134; re-derived
>   to 197648 / `f75d3dfeaf220a0b`. Mainline.
> - **197648 / `f75d3dfeaf220a0b`** — stale when the library moved to 200401 / `38f6f9ff53aff666`;
>   re-derived to 209756 / `ee0762ea94f560ac` in the commit that added K-5. Mainline.
> - **252347 / `21a3a0b663c1499d`** — stale first on a branch
>   (library 271652), then on mainline (library 305310 /
>   `e2b51e30d87df6c6`), and still this row on mainline a few commits later (library 317544 /
>   `46af5b131b65c6cc`). Read on a CRLF working copy this state shows sixteen stale rows; read
>   on the LF blob it shows one — both readings name this row value — and the difference is the bytes
>   each reading hashed (CRLF working copy against LF blob), not either table moving. Re-derived
>   on a branch to 305310 / `e2b51e30d87df6c6`; mainline took the cure
>   later, by then at 317544 / `46af5b131b65c6cc`.
> - **305310 / `e2b51e30d87df6c6`** — branch-only; stale at that
>   branch's merge of `main` (library 317544 / `46af5b131b65c6cc`); re-derived to
>   317544 / `46af5b131b65c6cc`. Never on mainline.
> - **317544 / `46af5b131b65c6cc`** — stale first on a branch, on
>   mainline later (library 324749 / `923eae1204e0e634`).
>   Re-derived by the change that wrote this list to 324749 / `923eae1204e0e634`, by both routes of
>   the basis block, which agree at that commit for this file and for all 16 rows. Re-derived
>   independently on another branch to 339553 /
>   `2c40664f79888d22`, in the same commit that moved the library again; mainline took that
>   in a merge, which closed this state on `main`.
> - **324749 / `923eae1204e0e634`** — recorded on a branch; branch-only.
>   Never stale in any commit: the library on that branch stayed 324749 until its merge of `main`
>   — and that merge's own resolution took 339553 / `2c40664f79888d22`. Never on
>   mainline.
> - **356103 / `4732b57f2185b211`** — recorded on a branch in the same
>   commit that moved the library to it, and put back to 339553 /
>   `2c40664f79888d22` in the same commit that reverted the library. Branch-only; never
>   stale in any commit.
> - **339553 / `2c40664f79888d22`** — on mainline, and re-measured
>   over the merged tree by both routes of the basis block, which agree; re-derived on a work branch
>   (since integrated) to 349012 / `7613a1ee3aa85155`
>   in the same commit that moved the library to it. Never stale in any commit.
> - **349012 / `7613a1ee3aa85155`** — recorded in that commit, and re-derived on a
>   later branch to 373052 / `a8de75482ed12f27` in the same
>   commit that moved the library to it. Branch-only; never stale in any commit.
> - **373052 / `a8de75482ed12f27`** — recorded in that commit, then on mainline from that branch's
>   merge, and re-measured by both routes of the
>   basis block, which agree; re-derived on one branch to 394842 /
>   `44f2c4e36f15c46b` and on another to 382188 / `bd7f5c1325e50d04`, each in the
>   same commit that moved the library to it. Never stale in any commit.
> - **394842 / `44f2c4e36f15c46b`** and **382188 /
>   `bd7f5c1325e50d04`** — branch-only. Their integration resolved the
>   row to **403978 / `fb04a35fcdf1d119`** over a library of that size, and a third change
>   re-derived it to **438093 / `5bbd04cbd5fc2c19`** in the same commit that moved the library to it.
>   None of the four is stale in any commit.
> - **466720 / `438d4076b2156670`** — the row this page carried until the seat tripwire
>   (WP-1 `H-25`) re-derived it to **494977 /
>   `10022c3444794ffb`** in the same commit that moved the library, which added 409 lines: a doctrine
>   block and seven functions above `Get-EvidenceGuardDecision` (the session test, the territory test,
>   the form builder, a quote-aware shell reader, the segment reader, the hit finder and the
>   sentence), and a deny-only block at that function's foot. Every added line sits below §5.2's cut,
>   which stays at `4188-4264`; the CRLF parenthetical moved to 501930 / `4162b404f0ad395a` on the
>   same commit. Re-derived by measurement before reporting, on both bases.
> - **461051 / `f1d8fac95fbf6576`** — the row this page carried until a later cure
>   of the DECIDER's own unguarded candidate read (WP-1 `H-23`) re-derived
>   it to **466720 / `438d4076b2156670`** in the same commit that moved the library, which added 66
>   lines inside `Get-EvidencePushGateForSha`: a `try`/`catch` around the `push-*.yaml` candidate read
>   that refuses BY NAME in that function's own `{ok; reason; path}` shape, and the measurement that
>   chose RETURN over `continue` after the admission's stated reason for the same choice was driven
>   FALSE. Because the insertion sits above them, every line below it shifted by 66 and §5.2's cut
>   moved with the library from `4122-4198` to `4188-4264`; the CRLF parenthetical moved to
>   473264 / `daf578ff46ba95bb` on the same commit. Re-derived by measurement before reporting, on both
>   bases.
> - **458824 / `736895f26172ddb7`** — the row this page carried until a later cure of the
>   decider-versus-admission divergence on the TIP comparison, the third of that family after
>   the earlier review findings (WP-1 `H-22`), re-derived it to **461051 / `f1d8fac95fbf6576`** in the same commit that moved
>   the library, which added 27 lines inside `Get-EvidencePushGateForSha`: one comparison
>   normalised to the canonical lowercase form, and the measurement that chose that direction
>   over the ordinal one `kind` takes. Because the insertion sits above it,
>   §5.2's cut moved with the library from `4095-4171` to `4122-4198`; the CRLF parenthetical moved to
>   467529 / `cbf4fa6ec2cfa018` on the same commit. Re-derived by measurement before reporting, on both bases.
> - **453032 / `5abc55e86b21c19c`** — the row this page carried until a later cure of the
>   settle guards' field-vs-gate weakness and of the `authorized_tip_sha` ambiguity (findings
>   of a review; WP-4 `T-35`, WP-3 `C-1t`) re-derived it to **458824 / `736895f26172ddb7`** in the same commit
>   that moved the library, which added 84 lines: a consume-block reader and a counting scalar
>   reader beside `Test-EvidenceGateFieldSet`, a refusal in `Get-EvidencePushGateForSha`, and a
>   widened guard in `Complete-EvidencePushGate`. Because every insertion sits above it,
>   §5.2's cut moved with the library from `4011-4087` to `4095-4171`; the CRLF parenthetical moved to
>   465275 / `c11819f46813ecf5` on the same commit. Re-derived by measurement before reporting, on both bases.
> - **449877 / `0c58f2eee8b49a08`** — the row this page carried until a later cure of
>   the pre-push decider's kind predicate (a validator finding, WP-1 `H-21`) re-derived
>   it to **453032 / `5abc55e86b21c19c`** in the same commit that moved the library, which added 36
>   lines inside `Get-EvidencePushGateForSha`. Because the insertion sits above them, every line
>   below it shifted by 36 and §5.2's cut moved with the library from `3975-4051` to `4011-4087`;
>   the CRLF parenthetical moved to 459399 / `747c8550c65d0d67` on the same commit. Re-derived by
>   measurement before reporting, on both bases, as the row below records the previous mover doing.
> - **448008 / `65d9f709199a16ba`** — the row this page carried until the change carrying
>   the hook half of first-stamp-wins re-derived it to **449877 / `0c58f2eee8b49a08`** in the
>   commit that moved the library, which added 23 lines inside `Complete-EvidencePushGate`.
>   Because the insertion sits above them, every line below it shifted by 23 and §5.2's cut moved with
>   the library from `3952-4028` to `3975-4051`; the CRLF parenthetical moved to 456208 /
>   `ed72abbfeb262ab7` on the same commit. WP-5 K-5 is what caught the staleness, on the run that
>   produced that change's own figures — the fifth consecutive round in which this row went stale
>   because a commit moved the file, and the first in which the mover re-derived it before reporting.
> - **447229 / `94bb217e3261c48b`** — the row this page carried until a later cure re-derived it to **448008 / `65d9f709199a16ba`** in the commits that moved the library (the intermediate 447774 / `79b68213d326e198`, 447801 / `accdb0af9d15989b` and 448023 / `8a0e69eb1b68ab68` are branch-only, never on `main`, though later commits carried the second and the third on another branch; none was stale in any commit): resolved at the integration
>   over a library of that size, then on mainline, and re-measured at
>   a later correction by both routes of the basis block, which agree.
>
> **§5.2's provenance line records the same hash and has gone stale with the row since it was
> introduced:** 305310 / `e2b51e30d87df6c6`, lines 3674-3750 — stale at a branch merge,
> re-cut to 317544 / `46af5b131b65c6cc`, lines 3833-3909 — stale from a later commit on
> its branch and from a later commit on mainline, re-derived to 324749 /
> `923eae1204e0e634`, lines 3952-4028 on one branch and to 339553 / `2c40664f79888d22`,
> the same lines, on another branch — the figure that reached `main` in its merge
> and that this page carried until the merge which brought a later change's 349012 /
> `7613a1ee3aa85155` and 373052 / `a8de75482ed12f27`, the same lines, each
> re-derived in the commit that moved the library — having moved with the library to 356103 /
> `4732b57f2185b211` and back in two later commits without a stale commit. Its CRLF
> parenthetical moved with it (309564 / `22e3e59483ad21f7`, then 321957 / `4beb389c7934b254`, then
> 329281 / `778b35297e13899c` on the first branch, then 344342 / `8f3fbba57aefc490`, which went
> stale at one of that change's library moves on a work branch, at its integration branch and at
> the merge to mainline, because neither of that change's library moves re-derived it (the library's
> blob at that move, rendered LF -> CRLF as its working copy would be, is 353923 / `50ade14eb8a232b9`),
> then 378344 / `bc8c8bec9dc99afc` from the next change, stale from one of the following change's library moves on
> a work branch and from its merge to mainline because that change's library moves re-derived only
> the two lines their mover owns, then 453537 / `6f62f1e1c32feed2` from that change's correction, then 454316 / `15c8341076eeb56f` from the change after it (the intermediate values 454082 / `619a313d91fcfb85`, 454109 / `05cb39073855b52e` and 454331 / `8e021b72bad8729d` are branch-only, never on `main`, though the second and the third were also carried on another branch), re-derived in the commits that moved the library) --
> **except on
> `main`, where an earlier change re-derived the two lines it owns and left the parenthetical at 321957 /
> `4beb389c7934b254`, stale on mainline up to and including that change's merge; no instrument reads it** — and so did
> §5.2's next-gen citation (`:3674`, then `:3833`, then `:3952`, then `:3975`, now `:4011`, which `main` still read as `:3833`
> at that change's merge). **§1.2's citation of the line that
> dot-sources A1's library** read line 62 when it was recorded, which was correct there; a later commit moved
> the dot-source to line 73, and nothing re-derived the citation until a later change —
> no instrument reads it.
>
> **The counts, each under its stated definition:**
> - **Re-derivations of the row** (non-merge commits that change its recorded value after the
>   first recording): **30** at the last count, each extension of the list above re-counting
>   over the commits it brought, so the figure is the total over every commit the list covers;
>   earlier counts were lower by the re-derivations the later commits added.
>   **22** of the 30 moved the row in the same commit that moved the library, so no stale
>   state existed for them (a run of earlier ones, then the later re-derivations a library
>   mover made in the commit that moved the library, on any branch);
>   **8**
>   re-derived a row that was already stale
>   — two of them re-derived the SAME stale state, 317544, on two branches. The merge
>   commits that took 339553 into `main` and into a session branch are
>   not counted, and neither are the merge that took 373052 into `main`, the three
>   integrations on an integration branch that carried 382188 and
>   resolved the row to 403978 and then 447229, or the merge that took 447229 to `main`.
> - **Stale states of the row on any branch** (a recorded value that stopped matching the library at
>   some commit): **7** — **4** before K-5 read the table, **3** after it (252347, 305310, 317544).
> - **Stale states of the row on mainline only:** **6** — **2** after K-5 read the table (252347,
>   which spanned two library values there, and 317544, closed on `main` at an amendment's merge); the 305310
>   state never reached `main`. The 324749, 356103, 349012 and 373052 values add no stale state on any
>   branch, and neither do 394842, 382188, 403978, 438093 and 447229.
> - **Stale states of §5.2's provenance line:** **2** on any branch (305310, 317544); **1** on
>   mainline (317544 — `main` received the line already at 317544).
> - **Stale states of §1.2's dot-source line citation:** **1**, from the commit that moved the dot-source.
>
> **CITED, NO LONGER OWED:** the hash-currency check — a member that catches this library moving
> without this page being re-derived, at the source of the move — has landed as **WP-1 H-15**
> (`tests/lam/instrument-WP-1.ps1`, `Check -Id 'H-15'`), added on a session
> branch and merged to `main` with an amendment. It installs the standing
> that **the mover of `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1` owns two lines of this
> page** — §5.2's provenance line and §1's next-gen row — and re-derives both in the same commit as
> each move; it reads those two lines, re-measures the live library on the LF basis in-process, and
> reds when either names a byte count or a hash the tree does not carry, or when §5.2's range does
> not bracket a function. **It reads nothing else on this page**: not the excerpt's code (WP-5 K-4
> compares that), not §5.2's `Get-FileHash` parenthetical, not §5.2's next-gen line citation, not
> §1.2's dot-source citation, and not this list. Until that member's merge this
> sentence read OWED, NOT CITED.

> **Re-derive every figure before acting on it** — these are the state at the commit that last
> measured them, not a live manifest. **Use the basis block above §1's first table**, route (a) or
> route (b); they are measured to agree for all 16 files.
>
> **DO NOT USE `Get-FileHash` FOR THESE TABLES.** It is the right tool for a sealed whole-file
> anchor (that is the §3 convention, and it is a *different* basis on purpose) and the wrong
> tool here: on a CRLF working copy it hashes CRLF bytes, so it disagrees with every row in §1. Erratum
> E4's observation describes such a checkout — `core.autocrlf` true and no `.gitattributes` covering
> `tools/framework/**` — and the conclusion drawn from it on this page was backwards: that
> configuration is exactly why the blob is LF and the worktree CRLF there, and §1's figures follow the
> blob.
>
> A table that quietly disagrees with disk is worse than no table. That is erratum E8, which is
> exactly this failure in the verify spec's own §10 — two of whose rows are stale today. **A table
> that disagrees with disk only because it never said which disk it meant is the same erratum with
> an alibi.**

### 1.1 THE ASYMMETRY — read this before you move anything

```
next-gen has, current does not :  evidence-dispatch-end.ps1
current has, next-gen does NOT :  evidence-place-substrate.ps1
                                  evidence-verify-placement.ps1
```

**`evidence-place-substrate.ps1` and `evidence-verify-placement.ps1` have no next-generation
counterpart.** They are not registered in `.claude/settings.json` (only four registrations exist —
see §2), but `tools/framework/tests/test-a15-placement-path.ps1` exercises them and two validator
results reference them. **A replacement that deletes the hooks directory removes them.** The
procedure below therefore **overlays named files** and never replaces a directory.

**`evidence-dispatch-end.ps1` is new and is not a registered hook.** It is the runner-side boundary
writer for H-1: the runner writes `DISPATCH-END` after worker exit, and the manifest finalizes on
that marker rather than on `Stop`. It needs no settings entry; it needs to be *present*.

### 1.2 The library is dot-sourced by a RELATIVE path, and that constrains where things may live

`tools/evidence-hooks-next/hooks/lib/evidence-common.ps1` line 73 dot-sources A1's library as
`..\..\..\framework\hooks\lib\evidence-common.ps1`, relative to its own `$PSScriptRoot`, and keeps
A1's decision function to delegate to. **The next-gen guard is a delta over A1, not a replacement
of it.** Consequences you must respect:

- Moving the next-gen hooks to a different depth **breaks that dot-source**, the guard's catch
  fires, and it **denies every call fail-closed**. That failure direction is correct and it is also
  silent about its cause until you read the reason string. *(Measured during the build: a flat copy
  of the two files denied even calls that should have been allowed.)*
- Therefore **do not flatten `tools/evidence-hooks-next/` into `tools/framework/`** as part of this
  install. Keep the next-gen tree where it is and point the registrations at it (§2), **or** perform
  a full merge in which the next-gen library's dot-source is rewritten — which is a code change and
  needs its own amendment.

**This procedure takes the first option.** It is reversible in one edit and it moves no sealed byte
in step 2.

---

## 2. Part 6 — the registration swap

**Current registrations** in `<project>/.claude/settings.json`, verbatim as they stand after the swap -- in the file's own order, every hook's `type` is `command`, the JSON string escapes (`\"`) are decoded and the matcher's pipes are escaped for this table:

| event | matcher | command | timeout |
|---|---|---|---|
| `PreToolUse` | `Write\|Edit\|MultiEdit\|NotebookEdit\|Bash\|PowerShell` | `powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1"` | `10` |
| `Stop` | `*` | `powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-stop-finalize.ps1"` | `60` |
| `PostToolUse` | `*` | `powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-post-tool-use.ps1"` | `30` |
| `PreCompact` | `*` | `powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-pre-compact.ps1"` | `60` |

*Provenance:* re-derive this table from your own `.claude/settings.json`, read with the file tool and hashed in-process by a script invoked by path; `.claude/` is gitignored and nothing under it is tracked, so the record of the registration is THIS TABLE, not a tracked file, and it is re-derived from the live file whenever the registration moves.

**Where the swap below has been performed**, all four commands above name `tools/evidence-hooks-next/hooks/`. **What a reading of the file does not confirm:** the table above is a reading of the registration FILE, not of a probe -- it records what the file registers, not that a session loads it ("A registration you have only read is a registration you have not tested", after the READY probe below). Confirm the live swap at the terminal with section 2's READY probe and section 5.5's probe pair (next-gen deny, `docs` control allow, sealed allow); re-deriving this table and section 5.5's heading from the live registration does not discharge that. A session started in a linked worktree that carries no `.claude/settings.json` registers no project hook from its own tree; where the repository tracks that file, as the framework repository does, every worktree carries it, and a session started there runs the guard, whose seat tripwire refuses a seat's file-tool and classified-verb writes under `.mission/**` and `.mission-runtime/lam/**` (a dispatched worker's own `.mission` writes are judged by the worker rule instead), so a seat opened there writes its handoff to its scratchpad (section 11). **For a FRESH mission it is still the procedure:** `tools/framework/install-evidence-hooks.ps1` merges `tools/framework/hooks/settings.evidence-hooks.json` into it -- it reads the fragment at `:48`, takes only its `hooks` key at `:99`, drops its own earlier entries (those carrying the `tools/framework/hooks/` marker set at `:49`) and appends the fragment's entries event by event at `:124-143` (the append is `:141`), serialises the result at `:146`, and writes `.claude/settings.json` at `:166`, which only `-Apply` reaches (without it the script exits at `:154-157`) -- and that fragment's four commands name `tools/framework/hooks/` -- the SEALED A1 library -- with the same events, matchers and timeouts as above, so a fresh install starts from the pre-swap registrations and the four edits below are what move it.

**The swap is four path edits — `tools/framework/hooks/` → `tools/evidence-hooks-next/hooks/` — and
nothing else.** Matchers do not change. No entry is added and none is removed.

```
tools/framework/hooks/evidence-guard-pretooluse.ps1   ->  tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1
tools/framework/hooks/evidence-post-tool-use.ps1      ->  tools/evidence-hooks-next/hooks/evidence-post-tool-use.ps1
tools/framework/hooks/evidence-stop-finalize.ps1      ->  tools/evidence-hooks-next/hooks/evidence-stop-finalize.ps1
tools/framework/hooks/evidence-pre-compact.ps1        ->  tools/evidence-hooks-next/hooks/evidence-pre-compact.ps1
```

**Add one registration you may want and the smoke repo has**, if you want the zero-paste attestation
to have a prompt register in your project as well:

```
UserPromptSubmit  matcher "*"  ->  tools/lam/record-operator-prompt.ps1
```

**Read errata E31 and E32 before you add it.**

- **E31 — name the compensating control.** That register classifies a prompt as machine-submitted
  **iff** `$env:LAM_DISPATCH` is set, so *every* prompt that does not come through the runner —
  including your own, and including any diagnostic — is recorded as an operator act. The gate
  register's control is T-3, which makes a gate agent-unmintable; **this register's control is only
  that marker**, and a multi-record attestation is only as strong as its weakest record's control.
  That is correct behaviour and it is also a foot-gun; this build has a live instance of it (below).
- **E32 — `prompt_bytes` does not measure the prompt.** Measured by reproduction: a 24-byte prompt
  records as `prompt_bytes=35`, because the CLI's hook payload carries more than what was typed.
  Do not read that field as the length of what a human typed; it is a payload size.

**If you register it, also decide up front how an excluded line is classified.** The acceptance
contract permits exactly one exclusion shape — a **written classification bound to a disclosure
artifact** — and requires the attestation to enumerate every line either way. Deciding that shape
*before* you have a line you would like to exclude is the whole point.

**Verify the swap took, from evidence rather than from the file:**

```powershell
claude -p "print the word READY and stop"
```

then confirm a fresh session directory appeared under `.mission-runtime/evidence/` and that its
manifest exists. **A registration you have only read is a registration you have not tested.**

> **RUN THAT PROBE WHERE YOU MEAN TO (erratum E33).** This one is *supposed* to land in your project's
> plane — it is the test. But the working directory is part of a command's blast radius, and a plane
> cannot tell a probe from a participant: it records what happened, which is its whole value.
> **Any diagnostic you do not want recorded must be run from outside the instrumented tree.** This
> build learned it the expensive way: a two-word probe run with the smoke repo as its working
> directory put a `kind=operator` line into the register that mission was being graded on,
> and the line could not be removed — correctly, because hook-written evidence is not
> deletable to make a number come out right.

> **THE INSTALL GRANT IS AN OPERATOR EDIT BY CONSTRUCTION** (at an install,
> measured under the operator's window). With the A1 hooks uninstalled, the harness's own auto-mode
> classifier still blocked every agent-issued write into `tools/framework/hooks/`, into
> `.claude/settings*.json` and into `.git/hooks` -- placement of the edited library, the settings
> swap, the decider install, and, one level up, the agent adding a permission rule whose target
> performs those writes (the Edit tool was blocked on the rule itself). Reads and runs against the
> same territory passed. So the steps of SS2, SS5.4 and the SS5 procedure's placement are performed
> by the operator at the terminal, or under a rule the OPERATOR writes into
> `.claude/settings.local.json`: an allow entry for one fixed script invoked by path. Two facts about
> that rule, both paid for: it must be spelled with **forward slashes** (the matcher's glob treats a
> backslash as an escape, so a `C:\...` pattern never matches), and it is removed by the operator when
> the verbs are done and the add/remove recorded with sha256 in STATUS.md. Nothing on this page
> assumes an agent can do any of it.

---

## 3. The sealed-hash re-seal

**There is no `sealed-hashes.json`.** The sealed set is a **declaration chain** recorded in
amendments and ledger entries, and the table in `docs/framework/mission-verify-spec.md` §10 is that
document's own derivation anchor — **not a live manifest**: its six rows are re-pinned to the files as this
release ships them (LF bytes), and any later edit to one of those files leaves its row stale until the row is
re-derived, and framework member A3 K3a fails until it is.

**If this install moves a sealed hash, it needs its own amendment, ratified BEFORE the bytes move.**
That is the dispatch-row discipline, and the amendment that re-anchored `evidence-common.ps1` is the worked example: it authorizes
the move in ratified text, retires the old anchor by name, records the new one, and states the
placement route.

**The re-seal commands, which only you can run:**

```powershell
git rev-parse HEAD
Get-FileHash -Algorithm SHA256 -LiteralPath tools\framework\hooks\lib\evidence-common.ps1
Get-FileHash -Algorithm SHA256 -LiteralPath tools\framework\hooks\evidence-guard-pretooluse.ps1
Get-FileHash -Algorithm SHA256 -LiteralPath tools\framework\hooks\evidence-post-tool-use.ps1
Get-FileHash -Algorithm SHA256 -LiteralPath tools\framework\hooks\evidence-stop-finalize.ps1
Get-FileHash -Algorithm SHA256 -LiteralPath tools\framework\hooks\evidence-pre-compact.ps1
Get-FileHash -Algorithm SHA256 -LiteralPath tools\framework\tests\test-a1-negative.ps1
```

**Why these are operator-derived, and why that is load-bearing rather than bureaucratic.** The
guard denies a shell command that combines a **metacharacter** with `tools/framework/hooks` — which
is most ordinary shell work against that path, reads included.

> **IT IS NOT A TOTAL BARRIER, AND THIS PARAGRAPH USED TO CLAIM IT WAS** (a WP-5 validator, driven
> — the validator measured every figure in the A1 table above **in session**, with the guard
> demonstrably live: it denied two of their own commands). A script FILE invoked by path names no
> protected path in the command, and a file-reading tool is not a shell command at all. The sentence
> said *"an agent cannot hash the sealed set"*, and an agent can.
>
> **The conclusion survives; the argument for it changes.** Operator-derivation is a **provenance**
> claim, not an enforcement one — the same distinction the goal artifact already makes about itself:
> *"the protection is provenance, not directory permissions."* What makes a figure yours is that
> **you** derived it at your terminal, not that nobody else could have.

So a figure an agent produces about the sealed set is **carried unless somebody says where they got
it**, which is a rule about attribution rather than about capability. The moment a hash is derived by you, at your
terminal, it stops being a number the record passed along and becomes a number somebody measured.
The worked example above records that distinction explicitly, and it is the only step at which any figure about these
files becomes yours.

**If this install does NOT change a sealed file** — and the procedure in §2 does not, because it
only edits `.claude/settings.json` — then **no re-seal is required** and no anchor moves. Say so on
the record rather than skipping the step silently.

---

## 4. Registered gap: D6 is still half a pathway

§14 item 13 is unchanged by this build and bears on you directly. The maintenance pathway specifies
how the sealed set is **committed** but not how it is **re-verified**: the guard denies re-hashing
the machinery by shell *from inside a session*, leaving **porcelain-absence** — strictly weaker than
a digest — as the only in-session proof that the sealed set is unmodified. Your terminal is
currently the only place a digest can be taken. **Do not treat a clean `git status` as equivalent to
a matching hash.**

---

## 5. The host project's guard additions (OPERATOR-ONLY)

**There are FIVE of them, and they are one procedure.** **Four** are rules this build installed in
the next-gen guard and **cannot** install in the host project's, because
`tools/framework/hooks/lib/evidence-common.ps1` is agent-unwritable. **The fourth, §5.4,
is not a guard rule at all** — it installs a `/bin/sh` git hook at the hooks path git itself reports,
which is a different mechanism at a different point in time, and the sealed library's unwritability
has nothing to do with why it is an operator step. Do them in the same sealed-hash move rather than
one at a time.

> **THIS SENTENCE WAS CORRECTED LATE, AND THE WAY IT WAS MISSED IS THE POINT.** The note below the
> table said this line *"previously called all of them"* guard rules — asserting, in the past tense, a
> correction that had never been made: `git diff` over that commit shows the sentence untouched. A
> claim that its own fix has already been applied is worse than an uncited one, because it stops the
> next reader looking. Found by an independent reader in a WP-5 validation, who diffed the commit
> against its own note. Nothing in a green suite reads prose.

> **The count on this line has been wrong.** It said "TWO" while the table below listed three and the
> procedure heading said four — three numbers for one list, in a section whose whole job is to be
> followed literally. Found by an independent reader in a validation round. If you add a row, fix the count
> in both places or the next operator will trust whichever they read first.

> **YOUR PROJECT ITSELF IS NOT EXEMPT, and a red dispatch before you do this is INTENDED.** Since
> the push-gate amendment the runner refuses to dispatch (exit 2) into any repository whose pre-push decider is
> not installed — your project included. Until §5.4 is done here, `mission-dispatch.ps1` will refuse in
> this repository, and that refusal is the machinery working, not a defect to route around.

| # | rule | contract | driven by |
|---|---|---|---|
| 5.1 | `*.superseded.yaml` marker writes | R-1 | instrument member `WP-2 R-12` (both reaches + over-reach control) |
| 5.2 | a dispatched worker's non-excepted `.mission/**` writes | K-3, **the worker-plane amendment** | instrument member `WP-4 T-5` (both routes, both scopes) |
| **5.3** | **case-INSENSITIVE protected-path matching** | **the case-folding amendment** | instrument member `WP-4 T-6` |
| **5.4** | **the `pre-push` DECIDER is installed** | **the push-gate contract** | instrument members `WP-4 T-13`, `WP-6 S-4b`, runner member `R-25` |
| **5.5** | **glob-denoted protected paths are resolved; links into protected territory are refused** | **an operator ruling** | instrument members `WP-4 T-3c`, `WP-2 R-12b` (each half falsified separately) |

> **5.4 IS NOT A GUARD RULE, unlike the three above it.** They change what the next-gen PreToolUse
> guard refuses; 5.4 installs a **git hook**, which is a different mechanism at a different point in
> time. It is listed here because it is an operator-only step in the same procedure, not because it
> is the same kind of thing. The line above this table now says so; **it did not when this note was
> first written**, and the note asserted otherwise in the past tense for a full round.

> **WHAT §5 DOES NOT CLOSE, AND §5.3'S OWN EXAMPLE IS THE PROOF.** §5.3 opens by describing an
> agent minting its own gate under `.mission/gates`. **Performing all of §5 does not stop that.**
> Measured side by side (a WP-5 validator): after §5.3, and after every step in §5, an `Edit` to
> `.mission/gates/probe.yaml` is still **allowed by A1** — and so is the UPPER-cased spelling
> `.MISSION/GATES/probe.yaml`. That clause used to read "and so is the lower-cased spelling", which
> is the spelling the example already uses: it contrasted the path with itself, in the summary of
> the section whose whole subject is case (a later WP-5 reading). Driven both ways: A1 allows
> BOTH spellings, the next-generation guard denies BOTH.
> `.mission/gates` is not in A1's protected array, and the rule that denies it,
> `Test-EvidenceGatePath`, is **delta-only**.
>
> **NAME THE GUARD, BECAUSE THIS PAGE USED TO SAY BOTH THINGS** (a WP-5 validator, driven). This
> passage said the lower-cased spelling is ALLOWED; step 6 said it must DENY. **Both are true, of
> different guards** — A1 allows it, the next-generation guard denies it — and neither passage said
> which. Two true sentences that cannot both be about the same thing are worse than one wrong
> sentence: a reader who checks either one confirms the page and stops looking.
> Controls moved correctly in the same fixture, so the measurement reached the cure.
>
> **§5 hardens what A1 already does. §2 is what installs gate protection and push gating at all.**
> If you perform §5 and skip §2 you have three extra rules and no publication gate — which is the
> reverse of what finishing this section feels like.

> **§5.3 IS REQUIRED, NOT OPTIONAL, AND IT IS THE MOST IMPORTANT ITEM ON THIS PAGE.** Until it is
> done, **your project's guard protects nothing that an upper-case spelling cannot reach** — see the
> section below. 5.1 and 5.2 are defence in depth; **5.3 is the difference between a guard and a
> decoration.** Do this one first if you do only one.

> **THESE THREE ARE NOT PARITY WITH THE DELTA, AND SECTION 2 IS WHAT DELIVERS THE REST.** Driven
> side by side against both guards, with A1's own protected paths as controls: the sealed guard
> ALLOWS a file-tool write to `.mission/gates/push-*.yaml`, to `.mission/gates/dispatch-*.yaml` and
> to a `*.superseded.yaml` marker, all of which the next-gen guard denies. `Test-EvidenceGatePath`,
> `Get-EvidencePushGateVerdict` and **the entire push-gating path exist only in the delta**.
>
> So an operator who performs THIS SECTION and not **§2's registration swap** has three new rules
> and **no push gating at all** — while this section's framing invites them to believe the gap is
> closed. §5 is defence in depth ON TOP OF §2, never a substitute for it.
>
> Note also what is doing the work in the meantime: at the repository of record the gate artifacts are protected by
> the PERMISSION layer (`settings.local.json` denies `Write/Edit(.mission/**)`), not by the guard —
> a different mechanism from the one T-3 names, and one a role template can change. `worker.json`
> deliberately drops that deny (the worker-plane amendment), which is safe only because the smoke repository and
> every worktree under it register the NEXT-GEN guard, where the worker-plane rule lives. Verified,
> not assumed.

> **THE CODE ON THIS PAGE IS CHECKED AGAINST THE CODE IT QUOTES.** Instrument member `WP-5 K-4`
> locates every `function`-shaped block below in `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1`
> **by name** and compares it as CODE — tokenised, so the source's longer commentary is not a
> difference — and the suite FAILS if the two drift. It also requires the page to keep at least four
> such blocks, so deleting an excerpt is not a way to go green.
>
> **This exists because the page has printed a superseded implementation twice**, each time caught by
> a reader rather than by anything on disk, and each time an operator who mirrored it would have
> hand-installed a defect into the sealed guard. If you edit a snippet here, run the suite. If you
> edit the library, run the suite. **A block below that no longer matches its source is a bug in this
> page, and the instrument says so before an operator does.**

### 5.1 `*.superseded.yaml`

**What it is.** A `*.superseded.yaml` marker retires a prior dispatch. An agent placed one with a
plain `cp` before anything stopped it. LAM-ACCEPT R-1 makes the pattern protected territory for
agent writes.

**Where it goes.** The protected/parent tiers are at
`tools/framework/hooks/lib/evidence-common.ps1:1057-1070`:

```powershell
$script:EvidenceProtectedPaths = @(
    '.mission-runtime/evidence',
    '.mission/evidence',
    'tools/framework/hooks',
    'tools/framework/install-evidence-hooks.ps1',
    'tools/framework/tests',
    '.claude/settings.json'
)
$script:EvidenceParentPaths = @(
    '.mission-runtime',
    '.mission',
    'tools/framework',
    '.claude'
)
```

**DO NOT ADD `.mission/dispatches` TO THE PROTECTED LIST.** That directory also holds
`<dispatch_id>.handoff.yaml`, which is the worker's **entire** output obligation, which R-3
validates, and which K-3 names as one of exactly two closed exceptions. Protecting the directory
denies the handoff and **no dispatch can ever complete**. The rule must be scoped to the **marker
suffix**. The next-gen implementation to mirror is:

**AND IT SPANS BOTH PLANES, RECURSIVELY, WHICH IS NOT AN OVERSIGHT.** The runner's marker scan is
recursive over `.mission` **and** `.mission-runtime`; a rule narrower than the scan leaves locations
an agent can write and the runner will honour as a refusal. Before this was corrected, four such
locations existed, and `.mission-runtime/` was reachable even by a **dispatched worker**, whose
plane rule covers `.mission/` only. Widening can only ADD denials: the operator hand-places markers
outside the session, where the guard does not apply, and the runner never writes one. Instrument
member `WP-4 T-10` drives every location under both roles, with controls proving ordinary files in
those same directories stay writable.

```powershell
function Test-EvidenceSupersessionMarkerPath {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    # TOKENISE FIRST, THEN ANCHOR WITHIN THE TOKEN.
    foreach ($f in @(Get-EvidencePathForms -Text $Path)) {
        if ($f -match '(^|/)\.mission(-runtime)?/.*\.superseded\.yaml$') { return $true }
    }
    return $false
}
```

> **CORRECTED SNIPPET — an earlier revision of this section printed the WRONG ONE, and mirroring it
> would have installed a hole.** That version ran a `(^|/)`-anchored regex over the **whole command
> string**. A path preceded by a **space** has neither start-of-string nor a `/` before it, so
> `cp seed.yaml .mission/dispatches/D-1.superseded.yaml` matched **nothing** and the guard returned
> **ALLOW** — the identical defect that let an agent mint a gate with a plain `cp` and publish on
> it. It passed its own member because that fixture used an **absolute** path. Use the form above:
> it delegates to `Get-EvidencePathForms`, which splits the command into tokens and resolves dot
> segments before matching, so a relative destination inside a command is caught exactly as an
> absolute one is.
>
> **IF YOUR SEALED LIBRARY HAS NO `Get-EvidencePathForms`, PORTING IT VERBATIM WILL BRICK YOUR
> GUARD.** Measured by an independent reader (a WP-5 validator): the delta's version calls
> `Test-EvidenceRootedPath` and reads `$script:EvidenceCwd`, and **neither exists in the sealed
> library**. Under its `Set-StrictMode -Version Latest` the missing variable *throws* —
> `The variable '$script:EvidenceCwd' cannot be retrieved because it has not been set` — and per
> §1.2 a throwing guard fails closed, so **every tool call in every session is denied.** The same
> code outside strict scope does not throw, which is why this is easy to miss in a quick test.
>
> **Port all three or none:** `Get-EvidencePathForms`, `Test-EvidenceRootedPath`, and an
> initialisation of `$script:EvidenceCwd` (`''` is correct when the payload carries no cwd — it
> restores command-text-only behaviour exactly). An anchored regex over a command string is the
> whole bug; these three together are the whole cure.
>
> **THE COUNT IS FIVE, NOT THREE, AT THE INSTALL** (measured
> while porting). The current `Get-EvidencePathForms` in the authority also calls
> `ConvertTo-EvidenceWin32ComponentForm`, `ConvertTo-EvidenceLongNameForm` and
> `Resolve-EvidenceGlobForms` (later rounds added them after this note was written), and under
> `Set-StrictMode` a missing one throws exactly as the missing variable does. The install ported the
> whole closure verbatim -- eight functions and the variable -- and the sealed library's own header
> block above them says so. The three named here were the closure when this paragraph was written;
> the rule that survives is "port the dependency closure of the authority's current definition, or
> none of it", and the closure is re-derived at each install rather than read off this page.

wired into `Get-EvidenceGuardDecision` on **both** reaches — the write-tool candidate paths and the
command text.

> **Not "exactly as `Test-EvidenceGatePath` is".** That sentence stood here and named a function
> **absent from the library you are editing** — it is delta-only, and §2 is what installs it. A
> wiring instruction that compares against something the reader does not have is not an instruction.

### 5.2 The dispatched worker's mission plane

**What it is.** K-3 restricts a worker to **two closed members** under `.mission/**` — its own
evidence session and its own handoff. **That shape is not writable as permission rules at all:**
Claude Code evaluates **deny before allow**, specificity does not change the order, and *a deny
rule cannot carry allowlist exceptions*. `worker.json` carried `Edit(.mission/**)` in `deny`
alongside both exceptions in `allow`, and the broad deny shadowed them — **zero exceptions
obtained, not two** — so R-3's required handoff was unwritable by the role obliged to produce it.
The blanket deny is gone from `worker.json` and **enforcement is here**.

**Cut from** `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1` **lines 4188-4264**, whose
file sha256 (16) is **`d2a401cfb3fcd709`** over 503493 bytes — **BASIS: LF-NORMALISED BYTES**, the
same basis as §1's tables and reproduced by the block above them. (On a checkout whose working
copy has CRLF line endings, `Get-FileHash` answers another hash over more bytes; that is the
working copy's basis and it is *not* what this line states. The two bases are named here on purpose: the round that cut this excerpt is
the round that found §1's tables and §1's reader sitting on different ones.) `WP-5 K-4` re-measures
this hash and compares the code below token-for-token against that file, so a stale excerpt **and** a
stale provenance line each turn the suite red. The line bracket runs from
`Test-EvidenceWorkerPlanePath`'s `function` line to its own closing brace — the shape K-4 holds
this line to, and the shape the bracket it replaces had at the commit that recorded it;
`Test-EvidenceDispatchedWorker`, printed after it in the same block, follows one blank line later
in the file. **This line records the same
file hash as §1's next-gen library row, so every move of that library stales both**: every
recorded instance of either going stale, with its commits and figures, is enumerated in §1 beside
that table's staleness notes.

```powershell
function Test-EvidenceWorkerPlanePath {
    param([AllowNull()][string]$Path, [AllowNull()][string]$DispatchId)
    if (-not $Path) { return $false }
    # A READ-ONLY HASH OF A DISPATCH OR CONTRACT FILE IS NOT A WRITE, and K-3 scopes this rule to
    # writes. First clause on purpose, inside the function so that all four call sites -- this
    # library's two and the SEALED copies that call it by name -- see the same answer. It can only
    # SUPPRESS this rule's deny: the protected tier, the metacharacter tier, the gate rule and the
    # two marker rules all run afterwards regardless.
    if (Test-EvidenceReadOnlyMissionHashCommand -Text $Path -Cwd $script:EvidenceCwd) { return $false }
    # SCOPED TO THE DISPATCHING ID. An unknown id closes the exception entirely -- fail closed.
    $ownHandoff = if ($DispatchId) {
        '(^|/)\.mission/dispatches/' + [regex]::Escape($DispatchId) + '\.handoff\.yaml$'
    } else { $null }
    foreach ($f in @(Get-EvidencePathForms -Text $Path)) {
        # TOKENS ONLY, NEVER THE WHOLE COMMAND TEXT. Form #1 is the entire canonicalised string;
        # once an absolute plane path is appended to it, it matches the plane pattern while the
        # `$`-anchored exceptions below can only be satisfied if the command ENDS with the excepted
        # path. `cp h.yaml <own handoff>` was allowed and `cp <own handoff> backup` was DENIED --
        # the same act, written the other way round. Nothing is lost: every path is also offered as
        # its own token form.
        if ($f -match '\s') { continue }
        if ($f -notmatch '(^|/)\.mission/') { continue }
        if ($f -match '(^|/)\.mission/evidence/session-[^/]+/') { continue }   # closed member 1
        if ($ownHandoff -and ($f -match $ownHandoff)) { continue }             # closed member 2
        return $true
    }
    return $false
}
function Test-EvidenceDispatchedWorker { return [bool]$env:LAM_DISPATCH }
```

wired into `Get-EvidenceGuardDecision` on **both** reaches, each gated on
`Test-EvidenceDispatchedWorker` and passing `-DispatchId $env:LAM_DISPATCH`.

> **CORRECTED SNIPPET — this page printed the SUPERSEDED form, and mirroring it would have reopened
> a closed defect.** The earlier version matched `[^/]*\.handoff\.yaml$` — a **wildcard over every
> dispatch id** — so a dispatched worker could overwrite a **peer** dispatch's handoff. That was
> found and scoped to the dispatching id in the live rule; **this document's copy was not updated
> with it**, and its prose said "its own handoff" while its code said "any handoff". An independent
> reader instantiated both forms side by side and measured the difference (a WP-5 validator).
>
> **This is the same erratum recurring in the very document that records it**, one round later, written
> by its author: *code inside prose is a fork with no merge and no test*. Until §5 carries a check
> that fails when an excerpt diverges from its source, **treat every snippet on this page as a
> reading aid and the named function in `tools/evidence-hooks-next/` as the authority** — diff the
> two before you mirror anything.

> **AND A THIRD TIME, CAUGHT BY THE CHECK RATHER THAN BY A READER**.
> A later change added a first clause to the live predicate — the read-only mission-hash suppression — and
> the excerpt above stayed **one `if` short**. `WP-5 K-4` reported it precisely:
> `Test-EvidenceWorkerPlanePath DIVERGED at token 31 of 121 (fence at doc line 498) / page:
> Variable:ownHandoff / source: Keyword:if`. That is the difference the member was written to make:
> the first two occurrences were found by people, this one by the suite, before an operator mirrored
> it. The block above has been **re-cut from the shipped source**, not patched by hand, and it now
> carries a provenance line that `K-4` re-measures — so the excerpt and the record of where it came
> from go stale together or not at all.
>
> **The authority for this excerpt is `tools/evidence-hooks-next/`, and that is what K-4 compares
> against** — not the sealed library, whose copy of this function is genuinely different: it does
> **not** carry that first clause (sealed `evidence-common.ps1:1468`, next-gen `:4011`). Mirroring
> this block into the sealed library is §5's whole point, so the difference is the instruction, not
> a discrepancy to reconcile.

**THE SCOPING IS LOAD-BEARING — do not drop it to make the rule "stronger".** A role-blind
`.mission/**` deny refuses `git add .mission/ledger/entries.jsonl` and amendment placement, which
is **ordinary mission ceremony**, and this guard's own doctrine says so in as many words: *a guard
that blocks the workflow it protects gets switched off*. `LAM_DISPATCH` is set by the runner
outside the agent's reach and is already the contract-named control distinguishing machinery from a
human. **T-3 (`.mission/gates`) stays role-blind and is not touched by this** — there is no role for
which minting one's own authorization is legitimate, which is not true of writing the plane.

**Two behaviours to expect, so neither reads as a bug later.** A worker's write to
`.mission/evidence/session-*/` is denied anyway by the protected-path set above — correct, because
that session is **hook-written**, and an agent-writable evidence store launders testimony as
evidence. And a mutation performed **inside a script** the worker invokes is not a tool call, so
the guard never sees it: that is how a `close`-class ceremony dispatch legitimately appends the
mission ledger, and it is the guard's known residual rather than a gap in this rule.

**Where the dispatched worker's tree lives.** `tools/lam/mission-dispatch.ps1` composes each dispatch's worktree once, as `<parent of the mission root>\<leaf of the mission root>-worktrees\wt-<dispatch id>` on branch `worktree-wt-<dispatch id>` -- for a checkout at `C:\work\<project>`, the sibling directory `C:\work\<project>-worktrees\wt-<id>` -- and `-PlanOnly` prints that path on its `worktree path` line. **The runner creates the tree itself, before the spawn:** at the dispatch's declared `base_head_at_authoring` (a validator's `tip_judged`), fast-forwarding an existing tree and refusing one it cannot bring there; or, when nothing is declared, at the mission root's HEAD -- and if the tree already exists it is reused where it stands -- recorded in the anchors and not asserted. It refuses a mission root that is not a git repository, that has no commit at HEAD when nothing is declared, or that has no parent and leaf to derive the home from (a drive root), and it refuses a directory at the tree's path that is not the mission root's own linked worktree. That last refusal is also what a dispatch meets when its mission root, the `<leaf>-worktrees` home or the tree was reached through a junction, a symbolic link or a `subst` drive, because git reports the resolved path and the runner does not resolve links: give real paths, and un-link the home -- removing or pruning the tree alone does not help, because the next dispatch recreates it through the same link. A stale tree git has registered is removed with `git worktree remove` (or `git worktree prune` once its directory is gone); deleting the directory alone leaves it registered, and the next dispatch is refused for that instead. The runner then spawns the CLI with the tree as its **working directory** -- entered by literal path and read back, so a dispatch id holding `[` or `]` still lands in its tree, and a location that is not the tree refuses the dispatch -- and passes no `--worktree`, which takes only a name and would create `<mission root>\.claude\worktrees\<name>`. `.worktreeinclude` names what a worker's tree needs that `git worktree add` does not put there -- ignored files only, since every tracked file is in the tree already. **What it places, before the spawn:** every file that is untracked **and** ignored in the mission root **and** matched by `.worktreeinclude`'s patterns, read with gitignore semantics -- so a pattern whose only slash is a trailing one, such as `.claude/`, matches a directory of that name at any depth, while a pattern with a slash in the middle, such as the `.mission/contract/` the file once listed, is anchored at the root and takes every ignored file beneath it. Expect that to match the root `.claude/` files, without which the worker has no evidence plane, and also any `.claude/` directory nested under a dependency folder and any ignored cache, such as pytest's `__pycache__` `.pyc` files, inside a matched directory. Whether those patterns should be anchored, or should exclude `__pycache__`, is for `.worktreeinclude`'s owner to decide; this procedure places what they match. The framework's file no longer lists `.mission/contract/`: the path is tracked, so the entry placed nothing a worktree lacked and copied only its ignored residue. It never copies a nested repository or a linked worktree (the main checkout's `.claude/worktrees/` is skipped whole) or an entry whose source path passes through a junction or symbolic link (skipped, and named) -- a link is told by its reparse tag, a mount point or a symbolic link, so a OneDrive or other cloud-files folder, which carries the reparse-point attribute too, is not one; it never overwrites a file committed at the tree's HEAD -- read from that commit, not from the tree's index, so an entry a worker only staged in a reused tree is placed afresh -- comparing names without regard to case; in a reused tree it deletes an existing destination and then copies afresh, so a hard link left there is broken rather than written through; and it refuses the dispatch, before the spawn, if the placement cannot be planned (including when the console cannot be switched to UTF-8 to read the names), cannot tell whether a source's or a destination's path passes through a link, meets a junction or symbolic link on a destination's path inside the tree, cannot remove an existing destination (a read-only one, or one another process holds open without delete sharing -- deliberately fail-closed, although an overwrite would have succeeded against the latter), copies or verifies fewer files than it planned, or -- when the mission root has `.claude/settings.json` on disk and `.worktreeinclude`'s patterns match that path, whether the mission root tracks it or not (the path is matched without regard to case, and a listing that fails refuses) -- does not leave the tree holding it, either placed by this run and byte-equal to the mission root's or committed at the tree's HEAD and unmodified against it, naming which case failed (placed but absent or not byte-equal; committed at the tree's HEAD but absent, modified or not comparable; skipped as reached through a link, or skipped otherwise; tracked by the mission root but not committed at the tree's HEAD, which is the declared base where one is declared; or untracked but not ignored in the mission root). A `settings.json` committed at the tree's HEAD is accepted whoever committed it -- what stops a worker writing one is the guard, not this check -- and a mission root with no `.claude/settings.json` on its own disk is not checked. An entry skipped as a link anywhere else, such as a file under a pnpm-style `node_modules` junction, is skipped and named and refuses nothing. **Why not under `.claude/` or `.mission-runtime/`:** inside the mission root the guard's parent tier refuses every metacharacter-bearing or destructive command a worker aims at its own tree; that placement was closed as not curable by exemption after four refuted attempts, and a measurement through the real guard in the session that relocated the tree showed `.mission-runtime/worktrees/` reproducing it exactly, so the tree now sits outside the mission root altogether. **Keep the mission root's path short enough that the composed path stays under 216 bytes** (UTF-8, so a non-ASCII character counts two bytes or more): git refuses a linked worktree whose path is 216 bytes or more (measured: exit 128, `'$GIT_DIR' too big`, at 216, whether or not `core.longpaths` is set), and the runner refuses such a dispatch, naming the length, before it creates anything or opens the run record. **Dependency:** at this home, what stops one dispatched worker writing into a **peer** dispatch's tree is the next-gen guard's peer-worktree deny rule; this procedure does not provide that protection, and until that rule is in the guard you register, nothing does. The rule's homes are `<parent>\<leaf>-worktrees` for every main repository it derives; the environment variable `LAM_WORKTREE_HOME_NAME`, set to one folder name (a letter or digit, then letters, digits, `.`, `_`, `-`; anything else is ignored), adds one more home name -- it can only add denials.

### 5.3 Case-insensitive protected-path matching — **REQUIRED**

**What it is.** `Test-PathHit` compares with `[regex]::IsMatch($Text, $rx)` — **case-sensitive** —
while every sibling predicate in the same library is case-insensitive. **Windows filesystems are
case-insensitive**, so an upper-cased spelling names the *same real file* and was **ALLOWED**:

| path | before | after |
|---|---|---|
| `.mission/evidence/…` | deny | deny |
| **`.MISSION/EVIDENCE/…`** | **allow** | deny |
| **`.MISSION-RUNTIME/EVIDENCE/…`** | **allow** | deny |
| **`TOOLS/FRAMEWORK/HOOKS/…`** (the guard library itself) | **allow** | deny |
| **`.CLAUDE/SETTINGS.JSON`** | **allow** | deny |
| `.MISSION/GATES/…` | allow | **allow — 5.3 DOES NOT CLOSE THIS ROW, see below** |

An independent validator drove the last row end to end: write a gate face, copy it in with an
upper-cased path, `mission-gate.ps1 list` reads it back as a **valid open build-authorization
gate**, and `git push` answers **"push authorized"**. **An agent minted its own authorization and
published on it.** That voids the agent-unmintability which T-3, R-1 and two later amendments
each cite *by name* as their compensating control.

> **THAT EXPOSURE IS REAL AND §5.3 IS NOT WHAT CLOSES IT** (a WP-5 validator, driven; the
> figures below re-measured here before this correction was written, on both guards, with controls).
>
> | path | sealed A1 | next-generation |
> |---|---|---|
> | `docs/note.md` (control) | allow | allow |
> | `.mission/evidence/…` (control) | deny | deny |
> | `.MISSION/EVIDENCE/…` | **allow** | deny |
> | **`.mission/gates/…` — lower case** | **allow** | deny |
> | **`.MISSION/GATES/…`** | **allow** | deny |
>
> **The lower-case sibling allows too**, and that settles it: `.mission/gates` is not in
> `EvidenceProtectedPaths` at all, so there is no match for case-folding to extend. **A case
> insensitivity option cannot manufacture a match that does not exist in lower case.** Applying
> §5.3 leaves this row exactly where it was — the validator applied it to a copy of the sealed
> library and drove all six rows; five flip, this one does not.
>
> What closes it is the **delta's own gate-path rule**, which denies both spellings unconditionally.
> So an operator who applies §5.3 and reads its table records this exposure as closed **while it is
> still open on the guard they just edited**, and only completing the next-generation installation
> actually shuts it.
>
> **The page already contained the correct fact and did not reconcile it:** §5 step 7 says
> `.mission/gates` "is unprotected and so can prove nothing here." Step 7 was right; this table row
> was wrong; they sat two headings apart for four rounds. Same shape K-5 was built for — a
> behavioural table with no reader — one heading away from the member.

**The change is one option on one call**, in the single predicate the whole protected tier funnels
through:

```powershell
function Test-PathHit {
    param([AllowNull()][string]$Text, [string]$Pattern)
    if (-not $Text) { return $false }
    $rx = [regex]::Escape($Pattern) + '(?=$|[/\s;,:|&)\]}"''`]|\\)'
    return [regex]::IsMatch($Text, $rx, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
```

**Direction check, so you can reason about the blast radius:** this can only **ADD** denials. It
cannot make anything newly permitted, which is the only direction in which widening a guard is safe.

### 5.4 The `pre-push` DECIDER — **REQUIRED**

**What it is, and why it is not another guard rule.** T-2 used to say a push "is hook-blocked
unless" a gate authorizes it, and the PreToolUse guard was asked to keep that promise by reading
command **text**. Three consecutive validation rounds refuted it, each on a spelling the previous cure could
not reach, each driven to a **real publication of an ungated origin**:

| round | spellings that published | |
|---|---|---|
| first | `$VAR`, ANSI-C `$'\x70ush'`, quoted `GIT_DIR`, `pushd` | cured |
| second | brace expansion, backslash-newline, git **aliases**, `Set-Location`/`sl`/`Push-Location` | cured |
| third | `g\it push`, `gi\t push`, `$G push`, `${G} push`, `xargs git`, `& (Get-Command git).Source push` | **not curable in text** |

The second round's cure closed the *subcommand* question, because "given this is git, is the subcommand a
push" has an enumerable answer. The third refuted the *executable* question, which does not — a
variable, a substitution, a pipe into `xargs`, a call operator, a wrapper, a renamed binary.

**Git already knows.** By the time a `pre-push` hook runs, every expansion has happened and git hands
it, on stdin, the real local ref, the sha it is about to publish, the remote ref and what the remote
currently holds. Spelling is irrelevant there. **This is the strongest LOCAL layer, and a later amendment
retracted the claim that it carries the guarantee** — `--no-verify` and `core.hooksPath` skip it, and
only what origin accepts cannot be flagged around;
the PreToolUse guard keeps doing the job it can actually do — refusing what it can read,
and recording every attempt.

**Install it.** The logic lives in the tracked file
`tools/evidence-hooks-next/hooks/evidence-pre-push.ps1`. What goes into `.git/hooks/pre-push` is a
fixed nine-line wrapper (one executable line; the rest is the shebang and the comment naming
`--no-verify` and `core.hooksPath` as its documented skips), and **you should not compose it by hand** — the runner and `WP-4` both
verify its sha256 against one definition in the guard library, so a hand-typed variant will read as
tampered. Generate and place it:

```powershell
. .\tools\evidence-hooks-next\hooks\lib\evidence-common.ps1
$d = (Resolve-Path .\tools\evidence-hooks-next\hooks\evidence-pre-push.ps1).Path
$t = Get-EvidencePrePushWrapperText -DeciderPath $d
# THE TARGET IS ASKED FOR, NOT ASSUMED. Two reasons, and the second one bites silently:
#   * `git rev-parse --git-path hooks` is git's own answer, so it is right under a worktree and
#     under core.hooksPath, which a hard-coded `.git/hooks` is not;
#   * .NET resolves a RELATIVE path against the PROCESS working directory, which `cd` and
#     `Set-Location` do NOT move. The earlier version of this block used `'.git/hooks/pre-push'`
#     directly, and from a shell started inside a DIFFERENT repository it completed without error
#     and installed the wrapper into that BYSTANDER repository, while this one got none.
$hooks = & git rev-parse --git-path hooks
# ABSOLUTE OR RELATIVE -- git returns EITHER, and the difference is not cosmetic. In a linked
# worktree, and under an absolute core.hooksPath, `git rev-parse --git-path hooks` answers with a
# ROOTED path; joining that onto the current directory produces a malformed path and GetFullPath
# throws NotSupportedException. An earlier version of this block joined unconditionally while the
# comment beside it claimed the block was "right under a worktree and under core.hooksPath" -- it
# named as its justification the two cases it could not do. Driven by an independent reader in a
# later round. (The LIBRARY has always handled this; only this page was wrong.)
$dest  = if ([IO.Path]::IsPathRooted($hooks)) {
    Join-Path $hooks 'pre-push'
} else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location).Path (Join-Path $hooks 'pre-push')))
}
[IO.File]::WriteAllText($dest, $t, (New-Object Text.UTF8Encoding($false)))
"installed to: $dest"
```

**Read that last line before continuing.** If the path printed is not inside the repository you meant
to install into, you have just written a hook somewhere else: delete it there, or it will silently
refuse someone else's legitimate pushes later. A hook in an unexpected repository is worse than no
hook, because nobody will think to look for it.

**LF and no BOM matter here** and are not style: it is a `/bin/sh` script, and a BOM or a CR makes
the shebang unparsable — which fails in the shape this whole layer exists to remove, namely a hook
that appears installed and does nothing.

**Verify it, and verify it the way the machinery does:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\evidence-hooks-next\hooks\check-prepush-installed.ps1 -RepoRoot .
```

Exit 0 and `"installed":true` is the pass. **Then drive it, because installation is not behaviour.**

In a throwaway repository with a bare origin and no gate, run **both** of these and confirm the bare
origin still holds nothing (`git --git-dir <bare> rev-parse refs/heads/main` must fail):

```powershell
git push origin main
$G = (Get-Command git).Source ; & $G push origin main
```

**The second line is the one that matters, and it must be written for the shell you are actually in.**
This page previously gave `G=git; $G push origin main` — *bash* syntax on a *PowerShell* page. Run
literally in PowerShell it is a parse error that never reaches git, so it "fails" identically whether
the decider is installed or not: **a verification step with zero discriminating power**, which is the
same defect as a test that passes vacuously. Driven by an independent reader in a validation round.

**Prove the probe can see a failure.** Remove the hook, re-run both lines, and confirm the bare origin
*does* advance; then restore it. A probe that has never shown you a red is not evidence.

**And know what it does NOT stop.** `git push --no-verify` skips every pre-push hook by design, as
does `core.hooksPath` pointed elsewhere. Both are documented git behaviour. The decider is a
**tripwire at the publication point, not a boundary** (T-2 as amended).

**What happens if someone deletes it.** The ruling answers deletion with detection rather than by
pretending it cannot happen, and the chain has three links — state them in your install record:

* **`WP-6`'s `S-4b`** asserts the decider's presence and fingerprint **in the mission being graded**,
  at the hooks path git itself reports, so a removed, redirected or edited decider reddens the suite.
  *This line used to name `WP-4`, and that was wrong twice over:* the push-gate amendment claimed the link
  without delivering it — every hook assertion in `WP-4` was about a throwaway fixture it created and
  deleted — and the member that does deliver it lives in `WP-6`. Found by an independent reader
  (in a validation round) applying T-2s to a sentence written in the amendment that added T-2s;
* **the runner refuses a dispatch (exit 2)** when the hook is absent or its hash does not match, on
  the same principle as R-1's verify gate — machinery that cannot verify its preconditions does not
  proceed;
* **S-4 still binds to origin's own answer**, so even a defeated decider leaves the mismatch between
  what origin holds and what the gate register authorized as the finding.

**What this does NOT do, stated so a green install is not read for more than it is.** It governs
publication from *this* repository through *git*. It does not govern a push made from a clone
elsewhere, by another tool that speaks the wire protocol, or by someone with direct write access to
the remote. Those are origin-side concerns, which is exactly why S-4's binding is the detector and
why the registered-but-unbuilt **D4 origin-side attestation** remains the layer above this one. This
is a down-payment on D4, not a substitute for it.

### 5.5 A glob denotes protected territory without spelling it — **where section 2's swap is done the registered guard is the next-gen library, which carries the cure; a FRESH install registers the SEALED guard, which is OPEN to this until §2 is done there**

**What it is.** The guard judges the **path text it is handed**. Its two tiers — a protected-path
match and a metacharacter-plus-protected-path refusal — are defeated by ONE input, because the glob
is what stops the protected path being detected and the metacharacter tier fires only when one *is*
detected. Driven in a validation round, in a scratch tree whose `.mission` the guard judges by the same
filesystem-wide suffix rule as the live one:

| route | sealed A1 | next-gen |
|---|---|---|
| `New-Item -ItemType Junction -Path l -Target .mission\evidence` (spelled) | deny | deny |
| **`New-Item -ItemType Junction -Path l -Target .mis*\evidence`** | **ALLOW — junction created, writes through it land in `.mission`** | deny |
| `cmd /c mklink /J l .mis*\evidence` | ALLOW (inert: cmd.exe does not glob) | deny |
| `type .mis*\evidence\x` — a glob **read** | **ALLOW** | deny |
| `cp x .mis*/dispatches/D-1.superseded.yaml` — a **new** file under a glob-denoted directory | **ALLOW** | deny |
| `New-Item -ItemType Junction -Path l -Target docs` — unprotected target | allow | allow |
| `dir *.txt` — a bare glob in unprotected territory | allow | allow |

**The sealed guard answers ALLOW on the bold rows at the head this page was last driven against, and
nothing on this page changes that.** The interim: the next-gen
guard is cured, the sealed guard stays as it is, and **§2's registration swap is the closure**. Until
§2 is performed, the live PreToolUse hook is open to every bold row. That is stated here, on the page
an operator reads, rather than implied by a green suite — a green `T-3c` is a claim about the
next-gen guard only.

**What the next-gen guard does, in two halves that were falsified separately** (regress one and only
its rows flip):

1. **Glob-bearing path tokens are resolved against the filesystem and every expansion is offered as
   an extra form** — the 8.3-alias mechanism exactly: add, never substitute, so this can only ADD
   denials. A bare `*` is never refused on its own; it expands to whatever is there. The resolver
   expands the **longest existing prefix** and re-appends the tail, because the minting route is a
   *new* leaf under a glob-denoted directory, and the first draft of the cure missed exactly that
   (caught by `R-12b`'s first row on its first run).
2. **A junction, symbolic link or hard link whose resolved target lies in protected territory is
   refused**, for every role, with its own reason. Needed on its own because a link to `.mission`
   spelled in full carries no metacharacter and reached no tier at all.

```powershell
function Resolve-EvidenceGlobForms {
    param([AllowNull()][string]$Token, [AllowNull()][string]$CwdCanon)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Token -or $Token -notmatch '[*?]') { return $out.ToArray() }
    $probe = $Token
    if ($CwdCanon -and -not (Test-EvidenceRootedPath -Path $Token)) { $probe = "$CwdCanon/$Token" }
    if ($probe -notmatch '^[A-Za-z]:/') { return $out.ToArray() }
    $native = $probe -replace '/', '\'
    $head = $native; $tail = ''; $hits = @()
    for ($i = 0; $i -lt 8; $i++) {
        try { $hits = @(Resolve-Path -Path $head -ErrorAction Stop | Select-Object -First 64) } catch { $hits = @() }
        if ($hits.Count -gt 0) { break }
        $cut = $head.LastIndexOf('\')
        if ($cut -lt 3) { break }
        $tail = $head.Substring($cut) + $tail
        $head = $head.Substring(0, $cut)
        if ($head -notmatch '[*?]') { $hits = @(); break }
    }
    foreach ($h in $hits) {
        $c = ConvertTo-CanonicalPathText -Text (([string]$h.Path) + $tail)
        if ($c) { [void]$out.Add($c) }
    }
    return $out.ToArray()
}
```

**What is NOT closed, stated so nobody infers it.** A write **through a link that already exists**
is not resolved by either guard. The ruling asks that such links cannot be *created* from inside a
session; a link created by other means is an operator-side fact and is carried as a registered
residual with that bound, not as a cure.

**POST-INSTALL PROBE, run at your own terminal after §2's swap, and only meaningful with its
control.** From the repository root, with a scratch directory `C:\probe` that exists:

```powershell
'{"session_id":"probe","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"New-Item -ItemType Junction -Path C:\\probe\\l -Target .mis*\\evidence"},"cwd":"<your repo root>"}' |
  powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\evidence-hooks-next\hooks\evidence-guard-pretooluse.ps1
```

**Expect exit 2 and `"permissionDecision":"deny"`.** Then the control — the same payload with
`-Target docs` — must **allow, exit 0**; if it denies, you are measuring a guard that refuses every
link and not the rule. And run the same `.mis*` payload through the SEALED script path
(`.\tools\framework\hooks\evidence-guard-pretooluse.ps1`) once, **before** the swap: it will allow.
That flip — sealed allow, next-gen deny — is the whole measurement, and it is what tells you the swap
closed the gap rather than that the gap was never there.

**The route is recorded never-to-be-used.** It is carried as an operator
ruling; a guard being wrong is not permission, and no probe in this build ever performed the bypass
against the real evidence plane.

### 5.6 THE OPERATOR CONSOLE -- how you mint, re-mint and revoke a gate now (STAGE 1)

**This is a behaviour change to `tools/lam/mission-gate.ps1`, and it changes how YOU work.** A gate
is a human touchpoint, and until now the tool refused an agent session by four session conditions --
a refusal, not a proof of humanity, and a scrubbed console defeated it (WP-4's T-25 residual). STAGE
1 adds a secure-desktop credential behind a compose-and-confirm console, and the tool now requires
**both**: a gate-mutating verb is admitted **if and only if none of the four session conditions fires
AND the call arrives through the console's verified path**. Neither admits on its own, and every
condition that fires is reported. (The row's first draft let a valid console token admit the mint even
where a condition fired; that weakened the tool relative to its base and was withdrawn on review.)

**You no longer run `mission-gate.ps1 approve/reapprove/revoke/settle` directly. You run the console,
in your own terminal** -- an interactive console with nothing redirected, not inside an agent session,
a hook or a runner-dispatched worker, where the session conditions would refuse it:

```text
tools\lam\lam-console.ps1 approve   -Kind <kind> -Id <id> -Binds <path> -MissionRoot .
tools\lam\lam-console.ps1 reapprove -Kind <kind> -Id <id> -Binds <path> -Reason "..." -MissionRoot .
tools\lam\lam-console.ps1 revoke    -Kind <kind> -Id <id> -Reason "..." -MissionRoot .
tools\lam\lam-console.ps1 settle    -Kind push  -Id <id> -MissionRoot .
```

`settle` is the fourth mutating verb (an operator ruling). It RECORDS THE USE of
a push gate: it reads the gate, asks the gate's **own declared `origin_url`** -- never
`remote.origin.url` -- what it holds at the declared `remote_ref`, and appends `consumed_at`,
`consumed_origin_tip`, `consumed_ref`, `consumed_origin_before` and `consumed_basis`. It refuses if
origin does not hold `authorized_tip_sha`, if the gate is already consumed (**first stamp wins** --
the in-session PostToolUse settle stays, and whichever lands first is the record), or if it is
revoked. **`expires_at` does not bind it**: expiry binds the pre-push decider, which asks whether a
publication MAY happen, while a settle records that one DID. An expired gate therefore still settles.

The parameters are `mission-gate.ps1`'s own. Running `mission-gate.ps1` with a mutating verb
directly -- by you or by anything else -- is now **refused** (exit 3, a `CONSOLE-VERIFIED-PATH`
condition, beside any session condition that also fired), because the tool requires an in-process
token the console mints only after a credential succeeds. And a console run where a session condition
fires is refused too, naming that condition, even though its token was valid (the token is then
spent). `list` is unchanged and is still the tool, not the console.

**What the console does, in order:**
0. **ROOT** -- it resolves `-MissionRoot` **once** to an absolute directory (`Resolve-Path
   -LiteralPath`, refused unless it is a directory -- the same resolution `mission-gate.ps1` uses) and
   uses only that absolute path from then on: compose, preview, the bound-file re-derivation, the mint
   and the attestation. A relative root is resolved against your PowerShell location. (Before the
   review's fix the attestation line was built from the relative root and handed to .NET, which
   resolves against the process current directory instead; it could land in the wrong tree or be lost.)
1. **COMPOSE** -- it calls `mission-gate.ps1 -ComposeOnly` in process, which runs every refusal and
   composition step and **writes nothing**, emitting the exact bytes of every file the mint would
   write, the resolved bound-file path and its sha256, and one **act digest** over the ordered writes.
2. **PREVIEW** -- it first prints **where the act lands**: `mission root (resolved, absolute)` -- the
   one absolute directory step 0 resolved -- and `gates directory (absolute)` --
   `<mission root>\.mission\gates`, the directory every gate write goes into. **Check both before
   anything else**: a gate act against the wrong tree is authorized just as firmly as one against the
   right one. Then it prints **every planned write in full, with every byte visible**: the write's name
   and its **absolute target path** (`target:`), each line of the write after a fixed `  | ` prefix,
   `<CR>` and `<LF>` for the carriage-return and line-feed bytes (a printed line ends after its `<LF>`),
   and `<0xNN>` for every other control byte, every non-ASCII byte (a UTF-8 byte-order mark shows as
   `<0xEF><0xBB><0xBF>`) and the `<` character itself, so no text can imitate an escape; then the
   write's byte length and sha256. The mission root, the gates directory and every target path are
   printed through that same rendering. A `revoke` binds no file, so its preview shows the bound file
   as `(none -- this act binds no file)`; its root, gates directory and target are what name the gate
   it withdraws. The console **refuses** a write whose name is not a plain file name (a path separator,
   a colon, a control byte or any other character Windows refuses in a file name -- reachable because
   `mission-gate.ps1` applies no character pattern to `-Id` for any kind but `halt-ruling`, whose `-Id`
   it refuses unless it matches `^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$` -- section 5.6.2), because its target
   could not be shown
   truthfully as `<gates directory>\<name>`. (The console spells the gates directory the way the tool
   spells it; the compose output does not carry it. The paths are lexical: a junction or symbolic link
   under the mission root is shown as its link path, not its destination.) Then the resolved bound-file
   path, the bound file's sha256 **re-derived by the console itself**, and the act digest **re-derived
   by the console itself over the bytes it just printed**. It refuses here, before any credential is
   collected, if either re-derivation disagrees with the compose output or a write's declared length
   is not its byte count. **Read the preview.** It is printed to your console and nothing more: nothing
   forces you to read it and nothing stops it scrolling past. It is the only thing standing between
   you and authorizing bytes you did not mean to -- a request an agent composed and you waved through
   is the residual the preview exists to close, and reading it is your act.
3. **CONFIRM** -- one announcement line naming the verb, the gate (`<kind>-<id>`), the mission root
   and the preview digest's first 16 characters, each printed through the preview's visible-byte
   rendering (an `-Id` carrying an escape sequence or a carriage return shows as `<0x1B>` or `<CR>`,
   never as a raw byte on your console); then one keystroke, then a **secure-desktop** credential prompt
   (`CredUIPromptForWindowsCredentialsW` with `dwFlags` `CREDUIWIN_SECURE_PROMPT` (0x1000) **only**,
   and a valid `CREDUI_INFO` whose caption and message are fixed text -- no gate name or other caller
   data reaches the prompt). **What it sends, exactly:** the authentication buffer the
   credential provider you used serializes is copied (CredUI's copy zeroed and freed) and submitted
   **unmodified and never unpacked** to `LsaLogonUser` (logon type Interactive, over
   `LsaConnectUntrusted`) under the authentication package CredUI reported for it; the logon's user SID
   must equal yours, or it fails. The console never holds your user name, domain or password as text
   (an earlier draft unpacked them into memory it never used or cleared; that is gone). **Designed
   for**, per the Windows documentation and not measured here: the credential kinds a Windows credential
   provider serializes for an interactive logon -- a password for a local or domain account, and the
   certificate-based kinds (smart card, Windows Hello). **The first real drive of an earlier build of this default
   provider FAULTED**: `System.AccessViolationException`
   inside `CredUIPromptForWindowsCredentials`, before any prompt was displayed, nothing written --
   because the helper passed no `CREDUI_INFO`. That is fixed, and the fixed call is measured not to
   fault on a no-UI drive (WP-4 T-28: `CREDUIWIN_IN_CRED_ONLY` with no incoming buffer returns rc 87 and
   shows no window). **No session has raised or completed the secure prompt, and `LsaLogonUser` has
   still never been called**: whether it accepts the buffer from an untrusted LSA connection is
   unverified, and your next real run is that verification. A native fault in any confirm provider is
   now a **REFUSAL at CONFIRM** (exit 3, no gate written) whose reason names the exception type, not a
   crashed console. **Run the credential probe (section 5.6.3) before your next real act.** It fails
   closed on cancel, on error, and on a host with no console.
4. **MINT** -- only on success does it mint the token and call `mission-gate.ps1 <verb> ...` in
   process; the tool evaluates its four session conditions (refusing, and spending the token, if any
   fires), re-derives the act digest from the bytes it is about to write, requires it to equal the one
   you previewed, and mints. The token is 32 random bytes, single-use, short-lived, and is **never
   written to disk, printed, put in an environment variable or on a command line**.
5. **ATTEST** -- one content-free line is appended to
   `<resolved MissionRoot>\.mission-runtime\operator-acts.log`: a UTC timestamp, `kind=gate-act`, the
   verb, the gate id, the preview digest, the credential provider, and the tool's exit code. Never the
   ruling text, never the token. **If the line cannot be written the console says so** (`the
   attestation record did NOT land`, with the reason) and leaves the act's exit code as it was: the act
   stands, its record is missing, and you record it by hand.

   **That log records CONSOLE ACTS, not mints, and it is not an independent second record of a mint**
   (session validator, DRIVEN). `lam-console.ps1` is the only writer of the line;
   `mission-gate.ps1` never attests. So a mint that does not come through the console -- in-process
   code in a console where the four session conditions do not fire, residual (3) below -- leaves a real
   gate in `<mission root>\.mission\gates` and **no line at all**, which the validator measured after
   driving exactly such a mint. **Ask the gates directory, not the log, which gates exist**; an absent
   line means either the console could not write it or the mint never came through the console, and the
   log alone cannot tell you which. (The candidate cure -- moving the attestation write into
   `mission-gate.ps1`, so every mint attests whatever called it -- is a design change nobody has ruled
   on. It is named here for you, not taken.)

**`-ComposedAt` is validated by the tool, for every verb.** The console supplies it (the instant it
composed); if it is given at all it must be exactly `yyyy-MM-ddTHH:mm:ss.fffZ` -- 24 characters, no
whitespace, no control character, a real UTC instant -- or the tool refuses with exit 2
(`COMPOSED-AT-MALFORMED`). For `approve`, `reapprove` and `revoke`, in compose and mint alike, it must
also lie within 10 minutes of the current UTC time, or the tool refuses with exit 2
(`COMPOSED-AT-OUT-OF-WINDOW`). Either refusal writes nothing. The console composes and mints with the
same value, so if you leave the preview or the credential prompt waiting more than 10 minutes, the mint
is refused as out of window; re-run the console.

**Every minted artifact now carries `operator_credential:`** -- `secure-desktop-credui` or
`injected-seam`. **Read it as the label the minting caller declared, not as evidence of how the mint
was authorized** (session validator, DRIVEN). The console declares the label before
the flow runs, independently of which confirm provider is wired, so in-process code in a console where
the four session conditions do not fire can mint with the provider replaced -- or with no credential
step at all -- and the artifact's face still reads `secure-desktop-credui`; the validator minted
exactly those, through the console's own files. What the field earns its place for is telling a scratch
fixture's gate apart from one of your own acts. Two consistency checks do run -- the tool requires the
label to match the one registered with the console token, and the console refuses, writing nothing, if
its confirm provider reports a different one -- but both compare values the same in-process caller
supplied, so neither makes the field a measurement.

**THE ONE INJECTION SEAM, AND WHY IT EXISTS.** The confirm act -- the keystroke and the credential
together -- sits behind a single replaceable provider so the WP-3 and WP-4 instruments can drive
success and failure without putting a prompt on your desktop. It is reachable **only in process, in
library mode** (a dot-sourced script installing it); there is no environment variable, switch or file
that selects it. Do not add one.

**WHAT A COMPUTER-USE AGENT CAN AND CANNOT REACH, MEASURED ON THIS HOST (narrowly).**
`OpenDesktop("Winlogon", DESKTOP_READOBJECTS)` from an agent session returns **handle 0,
GetLastError 5 (ACCESS_DENIED)**; the control `OpenInputDesktop` on the interactive desktop succeeds.
So the credential prompt is on the **secure (Winlogon) desktop**, which is isolated from the
interactive session and is not screenshot- or inject-reachable from a user-session or browser-pane
surface. The one keystroke before it is NOT: it is read by `[Console]::ReadKey` on your ordinary
console, where input can be injected; it only raises the prompt and authorizes nothing by itself. Everything else about the secure desktop's isolation is
a documented Windows property, labelled as such, not a measurement.

**RESIDUALS STAGE 1 LEAVES, STATED NOT HIDDEN.** (1) A direct file write into `.mission/gates` needs
no tool at all until STAGE 2 makes that directory unwritable to your interactive user. (2) The tools
(`mission-gate.ps1`, `lam-console.ps1`) are tracked files an agent can edit; the guard and the
permission layer are what deny that in a harness session, and they are the other layers. (3) The
in-process token registry and the injected provider are reachable to any code running in process in a
console where the four session conditions do not fire -- and an agent can start such a console, by
building a scrubbed console process tree (the WP-3 and WP-4 instruments do exactly that, in the open,
to drive the console). The session conditions stop a console driven from inside an agent session;
they do not stop that. STAGE 1 moves the *secret* off every surface this agent reaches, it does not
make in-process code trustworthy. (4) Social engineering you into confirming an agent-composed request
whose preview you did not read. The preview renders every byte and re-derives what it shows, but it is
ordinary console output: nothing makes it un-skippable, so reading it is load-bearing and it is yours.

### 5.6.1 STAGE 2 -- the gate-owner ACL (DOCUMENTED here, NOT built)

STAGE 1 keeps the authorizing secret off the agent's surface. It does **not** yet make the gate
directory unwritable, so residual (1) above stands until you do STAGE 2 yourself. STAGE 2 is your own
host setup, and it is deliberately not shipped as a script an agent could run:

1. **Create a `gate-owner` local principal** distinct from your interactive user, and take ownership
   of `.mission\gates` with it. **Your interactive user must not hold ownership of, or admin/
   take-ownership over, that directory** -- if it does, it can re-ACL around the control, and the hole
   reopens one layer up.
2. **ACL `.mission\gates` to deny your interactive user WRITE** and grant write only to `gate-owner`.
   The mint verbs would then write under the gate-owner token; the console would collect the
   **gate-owner's** credential on the secure desktop and impersonate it for the write.
3. **Forbid `runas /savecred`** for the gate-owner account, and forbid a **PIN-on-the-normal-desktop**
   fallback for the credential: either one puts the authorizing secret back on a keyloggable surface
   and every later mint runs with no real prompt. Require the biometric / security-key / secure-
   desktop path.

Why a second principal is the point: with the gate directory writable only by `gate-owner` and the
console the only thing that can impersonate it, an agent that has satisfied every session condition
still cannot write a gate, because it holds neither the ACL nor the credential. STAGE 1 is the secret;
STAGE 2 is the wall. Ship them together for the full property; STAGE 1 alone is a ratchet with
residual (1) named on the register, not a closure.

### 5.6.2 HALT RULINGS -- how a HALT is answered now

**This is a behaviour change to `tools/lam/mission-goal-check.ps1`, and it changes how YOU answer a
HALT.** Until now a HALT was answered when the first column-0 `**Status:**` line of the HALT file
read `ANSWERED`. The HALT file is agent-writable on every layer -- neither guard's protected set
names `.mission-runtime/halts` or `.mission-runtime/lam`, and the permission layer allows
`Write/Edit(.mission-runtime/**)` -- so one Edit by the seat flipped the goal verdict and let the
session end. **Now a HALT is ANSWERED if and only if a live, unrevoked `halt-ruling` gate binds the
HALT file's CURRENT bytes.** The `**Status:**` line answers nothing (one exception, the legacy
allowlist below, which is empty unless you write it).

**What you will see the moment this lands.** In a project whose HALTs predate this rule, each was answered, where it was
answered at all, by a seat-written `**Status:**` line, and no `halt-ruling` gate exists yet -- so every
such HALT reads OPEN. WP-3's C-3e member drives exactly that against a byte-verified copy of the
primary checkout's runtime plane and prints the count (a reading of today's plane, which grows as HALTs
are raised). **That project's goal therefore reads `HALT` until you choose a
migration path** (the end of this section); nothing in this change edits that goal or any gate.

**How you answer a HALT, at your own terminal (the console, section 5.6):**

```text
tools\lam\lam-console.ps1 approve -Kind halt-ruling -Id <HALT BaseName> -Binds <mission-relative HALT path> -Ruling "<your ruling>" -MissionRoot .
```

For example `-Id HALT-EX-01 -Binds .mission-runtime\halts\HALT-EX-01.md`. Read the
preview: the artifact is `.mission\gates\halt-ruling-<HALT BaseName>.yaml`, and it carries
`kind: halt-ruling`, `gate_class: governance`, `halt_id: <HALT BaseName>`, `binds` and
`binds_sha256` (the HALT's bytes as you are ruling on them), `ruling: "<your words, on one line>"`
(or the recorded absence `(NO RULING TEXT GIVEN -- -Ruling was not supplied)`), `permanence:
until-revoked` and a `lifecycle_note` -- and no `expires_at` and no `single_use`: a ruling does not
expire and is not spent by being read. `mission-gate.ps1` **refuses** (exit 2, nothing written) a
`halt-ruling` whose `-Id` does not match `^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$` (the `HALT-` prefix in any
case, as the scan matches it), whose `-Id` is not exactly the `-Binds` leaf's BaseName, or whose `-Binds`
leaf does not begin `HALT-` -- a gate under any other id would sit where no reader looks, and an id
holding a space or other character outside that class is a ruling the reader might not read back (the
review of this rule drove `-Id "HALT-A B"`: it minted, and answered nothing). A HALT name a census lists must match the
pattern; a HALT whose name does not is renamed before you
rule on it. `-ExpiresMinutes` is ignored for this kind.

**What the evaluator checks, every time it runs** (`Test-HaltRuled`; every other case is OPEN):

1. a file exists at `<MissionRoot>\.mission\gates\halt-ruling-<HALT BaseName>.yaml`;
2. its column-0 `kind:` is exactly `halt-ruling` (case-sensitive), with no `gate_class` conflict;
3. the shared gate-state predicate reports it neither revoked, consumed nor disqualified;
4. its one column-0 `binds_sha256:` equals the sha256 of the HALT file's bytes **now**;
5. its one column-0 `halt_id:` -- the whole value to end of line, trimmed -- equals the HALT BaseName
   (case-sensitive);
6. and none of `kind`, `binds_sha256`, `halt_id` appears twice at column 0.

**AFTER YOU RULE, NOBODY EDITS THAT HALT.** Any change to its bytes -- a seat appending "ANSWERED", a
formatter, a line-ending conversion -- moves its sha256 and the HALT reads OPEN again until you re-rule.
That is the ruled fork (B) and it is deliberate: an answer never silently stands over changed text. If
the HALT genuinely has to change (a follow-up question, a correction), re-rule over the new bytes in
one act: `lam-console.ps1 reapprove -Kind halt-ruling -Id <BaseName> -Binds <same path> -Reason "..."
-Ruling "..." -MissionRoot .`. To withdraw a ruling: `lam-console.ps1 revoke -Kind halt-ruling -Id
<BaseName> -Reason "..." -MissionRoot .` -- the HALT reads OPEN again at once.

**THE SEAT CITES; IT DOES NOT WRITE INTO THE RULED HALT.** The seat's write-back moves out of the HALT
file into a sidecar beside it, `<HALT BaseName>.ruling-citation.yaml`. The sidecar is
**non-authoritative**: the evaluator sets it aside **before reading it** (it would otherwise match
`HALT-*` and read OPEN forever), lists it in the verdict artifact under
`halt_scan_skipped_citation_sidecars:` with that reason, and never lets its presence or content answer
anything. The suffix is matched case-sensitively, so a differently-cased sidecar is scanned as a HALT
and reads OPEN -- loudly. Its minimal format:

```yaml
# HALT-EX-01.ruling-citation.yaml -- written by the seat beside the ruled HALT. NON-AUTHORITATIVE.
halt: HALT-EX-01.md
gate: .mission/gates/halt-ruling-HALT-EX-01.yaml
binds_sha256: <the gate's binds_sha256, as the seat cites it>
cited_at: <UTC timestamp, yyyy-MM-ddTHH:mm:ss.fffZ>
cited_by: <the seat or session that wrote the citation>
note: "one line -- what the seat did on the strength of the ruling"
```

**THE LEGACY ALLOWLIST -- DEFAULT EMPTY, AND AN OPERATOR ACT.** A `halt_absent` detector in a goal file
may carry one line naming HALTs answered under the old marker rule, each at the exact bytes you read:

```yaml
  - type: halt_absent
    legacy_answered_allowlist: "HALT-EX-01.md@<sha256>, HALT-EX-02.md@<sha256>"
```

An entry is honoured **only if all of**: its `<name>@<sha256>` is a member of the **legacy HALT census**,
`tools/lam/legacy-halt-census.txt` beside `tools/lam/mission-goal-check.ps1`; a HALT file of exactly that name is being scanned and its
current bytes hash to that sha256; **and** its old `**Status:**` marker reads `ANSWERED`. A live
`halt-ruling` gate outranks it. Every honoured HALT is named `LEGACY-ALLOWLISTED` on the detector's detail
and under `halts_answered_by_legacy_allowlist:` in the verdict artifact; every entry **not** honoured --
malformed, `not-in-legacy-census`, file absent, sha moved, marker not `ANSWERED` -- is listed with its
reason under `legacy_allowlist_report:`. Both keys are written on every run (`[]` when empty). With no key,
no legacy HALT is honoured. When a goal has more than one `halt_absent` detector, their entries are
unioned **once**, and every `halt_absent` detector and the HALT verdict use that same union with every
entry's disposition decided over the same run-wide scan -- so a detector never reports a HALT OPEN that the
verdict calls answered, and the detectors' "NOT HONOURED" lists are the verdict's `legacy_allowlist_report`.

**THE LEGACY HALT CENSUS, AND WHY THE BOUND IS NOT THE GOAL FILE.** The census is every HALT that was
live in a project when it retired the marker rule, by name and the sha256 of their bytes, captured
read-only from the primary checkout's `.mission-runtime\halts` and `.mission-runtime\lam`. Through
release 0.2.0 it was a literal inside the evaluator, so an installed tool carried its builder's HALTs into every
project; it is now `tools\lam\legacy-halt-census.txt`, a HOST-CONFIG file beside the evaluator that the framework
ships **empty** and an upgrade never rewrites (section 10 says how a project upgrading from a release that carried the
literal keeps its census). Its header comment carries the member count and a sha256 over the canonical census text,
and WP-3's C-3d recomputes both from the file. It is **data, not configuration**: no parameter or environment
variable extends it, and a line of it that is neither a member nor a comment makes it unreadable: a goal that
consults it reads NOT_MET, its `evaluator_error` naming the file and the line, and its Stop hook blocks until the
line is mended. Absent or empty, it honours no legacy HALT. It exists because the review of this rule drove the
allowlist as first built: a seat rewrote its own HALT to `**Status:** ANSWERED`, hashed it, named it in the
goal's `halt_absent` detector, and the verdict read MET -- two file edits, no gate, no console act. **The
goal file is the operator's by convention only**: a goal file may say of itself that every change to it is
an amendment naming the detector it changes, but the permission layer allows `Write/Edit(.mission/**)` and
the fallback goal location `.mission-runtime/lam/goals` is agent-writable by design, so nothing but that
convention stops a seat editing it. With the census, a goal-file edit can honour only a HALT that already
read ANSWERED under the marker rule on the day that rule was retired; a HALT raised or edited after the
census is answered by a `halt-ruling` gate or not at all.

**THE MIGRATION CHOICE IS YOURS, AND UNTIL YOU MAKE IT THE GOAL READS HALT.** Either (a) mint a
`halt-ruling` gate through the console for each HALT you have ruled on -- for a goal, that is the
HALT files of its own arc that it scans, and every other live HALT under the two scanned
directories as well, since the scan is not limited to one arc's names; or (b) amend the goal with a
`legacy_answered_allowlist` naming the HALTs you ruled on before this change at their current sha256
(WP-3's C-3e prints which of its own arc's HALTs such an allowlist would honour today, and why each other one
would not). (a) is the rule going forward; (b) is a bridge for history, bounded by the frozen legacy census
and the sha256 of every entry -- a census HALT edited since the capture can no longer be allowlisted and
needs (a). **Whichever you choose, it has to cover the whole scanned plane, not only its own arc's HALTs.**
A goal whose scanned directories also hold older HALTs, from an earlier numbering or an earlier arc,
still reads HALT with those OPEN when its allowlist names only its own arc's HALTs: every HALT answered
under the marker rule reads OPEN under the new one until a gate or an allowlist entry answers it.
WP-3's C-3e prints the count for your plane, over a byte-verified copy of the primary checkout's two
directories.

**OWED OUTSIDE THIS CHANGE, AND NOT EDITED BY IT.** Any project-side helper under
`.mission-runtime/lam/helpers/` that writes `**Status:**` lines into HALT files, or otherwise writes
`ANSWERED` into one,
still writes into the HALT itself; under this rule that write re-opens a ruled HALT and
answers nothing. A helper there that extracts `Test-HaltAnswered` and `Get-OpenHalts` by AST
and applies the marker reader alone shows an ANSWERED column that disagrees with the evaluator (and an
AST-extracted `Get-OpenHalts` no longer carries the script-level census and scan state it reads).

**RESIDUALS, STATED NOT HIDDEN.** (1) Section 5.6's residual (1) carries straight through: until STAGE 2
makes `.mission\gates` unwritable to your interactive user, a hand-written file declaring `kind:
halt-ruling` over the right bytes reads ANSWERED -- WP-3's C-3d drives that control row in the open.
On the gate route the cost moved from one Edit into an agent-writable HALT file to forging a gate artifact.
That sentence was first written as if the gate route were the only one, and it was not: the legacy
allowlist cost two file edits until the frozen legacy census bounded it (see above). (2)
Two HALT files with the same BaseName in different scanned directories share one canonical gate path;
a gate answers each of them only where its bytes are identical to the ruled ones. (3) A genuine HALT
named `*.ruling-citation.yaml` is set aside as a sidecar, as a genuine HALT named `HALT-xx.py` already
is set aside as tooling; nothing in this build writes either. (4) A goal-file edit can still honour a
census member at its captured bytes -- a HALT that already read ANSWERED under the marker rule when that
rule was retired -- and extending the census is a modification of its tracked file beside the tool, the same
residual as editing any tracked tool until STAGE 2 and review close it.

**A TOOLING SEAT'S HALT, AND ITS RESOLVED RECORD.** A tooling or recording seat -- one that builds or
records the framework rather than executing a mission -- raises its HALT in its own runtime plane,
`<MissionRoot>\.mission-runtime\seats\<seat>\HALT-<id>.md`. That plane is a sibling of the mission planes:
the default scan (`.mission-runtime\halts` and `.mission-runtime\lam`) does not read it, and a goal reads it
only by declaring a `halt_absent` `dir` there. You answer such a HALT by having a RESOLVED record written into
the HALT file itself, in the HALT's own shape: its first column-0 `**Status:**` line reads `RESOLVED`, and one
column-0 `## RESOLVED` block carries five fields, each exactly once at column 0 and none empty -- the HALT id,
the ruling as you gave it, who ruled, when, and where the seat resumes. For example,
`.mission-runtime\seats\example-seat\HALT-EX-01.md`:

```text
# HALT-EX-01 -- the seat stops for the operator's word

**Raised:** by the seat, before the step its brief names next.
**HEAD:** `<sha>`
**Status:** RESOLVED -- answered by the RESOLVED block below; no gate was minted.

---

## What was expected
...
## What was observed
...

## RESOLVED

**HALT:** HALT-EX-01
**Ruling:** Take the step the second way the HALT offered, and record in the handoff that it was taken so.
**Ruled by:** the operator, in the seat's session
**Ruled at:** 2026-10-25T18:00:00Z
**Resume at:** the step the brief names next, taken the second way
```

**What the evaluator checks** (`Get-HaltSeatResolution`, consulted only where neither a `halt-ruling` gate
nor the legacy allowlist answered the HALT; every other case is OPEN):

1. the file sits directly inside one seat folder under `<MissionRoot>\.mission-runtime\seats\` -- not in a
   subfolder of it, and not in any other plane;
2. its first column-0 `**Status:**` line outside fenced blocks reads `RESOLVED` (the first word, emphasis
   stripped, as for `ANSWERED`);
3. exactly one column-0 `## RESOLVED` heading stands outside fenced blocks;
4. each of `**HALT:**`, `**Ruling:**`, `**Ruled by:**`, `**Ruled at:**` and `**Resume at:**` stands exactly
   once at column 0, inside that block (before the next `## ` heading), with a value;
5. `**HALT:**` is the file's BaseName (case-sensitive), and `**Ruled at:**` begins with a date, `YYYY-MM-DD`.

Fenced blocks are set aside first, by the same fence rule as the `**Status:**` reader, so a record shown as
an example -- like the one above -- answers nothing. A HALT so answered is named on the `halt_absent` detail
and under `halts_resolved_by_seat_record:` in the verdict artifact, a key written only when one is, so every
other artifact is byte for byte what it was. A HALT whose `**Status:**` reads `RESOLVED` and whose record is
not honoured is OPEN, and its `open_halts` entry says why (`[seat RESOLVED record NOT honoured - <reason>]`).
In a checkout of the framework repository, `tests/lam/fixtures/seat-halt` holds this example and a goal that
scans the seat plane, and `tools/tests/cli/test_seat_halt_resolved.py` drives it with its controls; neither
is installed.

**The one difference from a mission HALT:** a mission HALT reads closed only when an operator-minted
`halt-ruling` gate binds its current bytes, and that gate is what a push and every other operator-gated act
can rest on; a RESOLVED record is text in a seat's own plane, so it closes that seat's HALT for the evaluator,
mints no gate and authorises nothing. The same record on a HALT anywhere else -- `.mission-runtime\halts`,
`.mission-runtime\lam`, a seat's subfolder, any other declared `dir` -- answers nothing. The residual, stated:
the record is as writable as the HALT file is, so a seat can write its own; it is honoured only where a goal
chose to scan the seat plane.

### 5.6.3 THE CREDENTIAL PROBE -- drive the secure-desktop prompt without minting

**Why it exists.** The first real drive of an earlier build of the console's confirm step (`approve
-Kind push`) died of `System.AccessViolationException` inside `CredUIPromptForWindowsCredentials`,
before any prompt appeared and with nothing written. The cause -- the helper passed no `CREDUI_INFO` --
is fixed, and the fixed call is measured not to fault on a no-UI drive. **But nothing an agent session
ran has shown that the secure prompt works**: no session has raised it, completed it or called
`LsaLogonUser`, and none may, because a secure-desktop prompt raised from a session lands on your screen.
The next measurement is yours, and `tools/lam/lam-console-probe.ps1` lets you take it with nothing at
stake.

**What it calls, and what it never does.** It dot-sources `tools\lam\lam-console.ps1` in library mode
(the console's functions, not its flow), compiles the `LamConsoleCred` helper with
`Initialize-LamConsoleCredType`, and calls exactly one thing that reaches a credential:
`LamConsoleCred.PromptSecureDesktop` -- the same secure-desktop prompt the console's default confirm
provider raises (`CredUIPromptForWindowsCredentialsW`, `CREDUIWIN_SECURE_PROMPT` only, a fixed caption
and message, no incoming buffer). It **never** composes a gate act, mints or registers a token, calls
`VerifyIsCurrentUser` or `LsaLogonUser`, calls `mission-gate.ps1`, writes an attestation line, writes a
file or sets an environment variable. **It never shows your credential**: of the packed authentication
buffer it prints only the length, beside the authentication package number, and it zeroes the buffer
before it returns, whatever happened. **It never checks the credential either** -- only `LsaLogonUser`
would, and the probe never calls it -- so a wrong password still collects. (Compiling the helper uses
the .NET compiler exactly as the console does, and that compiler's own transient temporary files are
its behaviour, not a file the probe writes; not measured here.)

**Where to run it.** Your own interactive PowerShell terminal -- not an agent session, a hook or a
runner -- with nothing redirected, from the root of the checkout you will mint from. The probe loads the
`lam-console.ps1` beside it and prints that file's sha256, so the identity you record is the console you
will run. With stdin redirected, or with no console at all, it refuses before loading anything.

**The exact command** (then read the exit code in the same terminal):

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\lam-console-probe.ps1
$LASTEXITCODE
```

**What it prints, in this order:**

```text
lam-console-probe: PROBE ONLY -- calls LamConsoleCred.PromptSecureDesktop and nothing else: no compose, no token, no LsaLogonUser, no gate, no attestation line, nothing written.
lam-console-probe: lam-console.ps1 <absolute path> sha256 <64 hex> (<n> bytes)
lam-console-probe: process 64-bit <True|False>; CREDUI_INFO marshalled size <n> bytes; dwFlags 0x<8 hex>
lam-console-probe: raising the SECURE-DESKTOP credential prompt now -- enter your own credential to test collection, or press Cancel.
LAMPROBE collected=<true|false> rc=<decimal> packed_length=<n> auth_package=<n> reason=<reason>
```

1. **PROBE ONLY** -- the probe's own statement of what it calls and what it does not.
2. **The identity line** -- the absolute path of the `lam-console.ps1` it loaded, that file's sha256
   (lower-case hex over its bytes as read, before loading) and its size in bytes.
3. **The platform line** -- whether the process is 64-bit (`True` from `powershell` on this host), the
   marshalled size of the `CREDUI_INFO` the prompt is given (40 bytes in a 64-bit process, 20 in a
   32-bit one) and the flags it is raised with (expect `0x00001000`, `CREDUIWIN_SECURE_PROMPT` alone).
4. **The raising line** -- printed immediately before the secure desktop takes the screen.
5. **The LAMPROBE line**, field by field:
   - `collected` -- what `PromptSecureDesktop` returned: `true` only when the prompt returned rc 0 with a
     non-empty buffer.
   - `rc` -- the prompt's return code in decimal: `0` success, `1223` you cancelled
     (`ERROR_CANCELLED`), any other number a CredUI error, and `4294967295`
     (`LamConsoleCred.PromptFaulted`) a native exception caught at the P/Invoke boundary.
   - `packed_length` -- the length in bytes of the packed authentication buffer the credential provider
     serialized (`0` when none). Its length only, never its bytes.
   - `auth_package` -- the authentication package number CredUI reported for the credential provider you
     used (`0` when none).
   - `reason` -- the helper's reason, through the console's visible-byte rendering: `collected`,
     `operator cancelled the secure-desktop prompt (rc 1223 ERROR_CANCELLED)`,
     `CredUIPromptForWindowsCredentials rc=<n>`, `no credential was collected (rc 0, empty buffer)`, or
     `native exception <Type> inside CredUIPromptForWindowsCredentials: <message>`.

A refusal before the prompt prints **one line instead of all five**, and no LAMPROBE line:
`lam-console-probe: REFUSED before any prompt -- <why>.`

**Exit codes.** `0` collected. `1` cancelled (rc 1223). `2` refused before any prompt: no interactive
console (stdin redirected, or no console at all -- the default confirm provider's own test),
`lam-console.ps1` absent or not loadable, or the helper would not compile. `3` the prompt failed
otherwise: any other rc, rc 4294967295, or an empty buffer.

**THE OWED SEQUENCE, IN THIS ORDER.**

1. **Run the probe and press Cancel on the secure prompt.** Expect exit `1` and `rc=1223`:
   `LAMPROBE collected=false rc=1223 packed_length=0 auth_package=0 reason=operator cancelled the secure-desktop prompt (rc 1223 ERROR_CANCELLED)`.
2. **Run the probe and enter your own credential.** Expect exit `0`, `collected=true`, `rc=0`,
   `packed_length` above 0 and an `auth_package` number. The probe never checks the credential, so this
   shows that the secure prompt collects, not that the credential is right.
3. **Only then the second real drive**: `tools\lam\lam-console.ps1 approve -Kind push ...`, exactly as in
   section 5.6.

**Transcribe, for each run: the LAMPROBE line, the exit code (`$LASTEXITCODE`) and the `lam-console.ps1`
sha256 line** -- to be recorded with your project's own operator evidence.
The console in step 3 prints no LAMPROBE line
and no sha256 line of its own: for it, transcribe the line that reports its CONFIRM outcome (the
`REFUSED at CONFIRM` line, or the mint's output) and its exit code, beside the sha256 line of your step 2
probe run from the same checkout, which names the same file if nothing changed it in between.

**What a native fault looks like now.** If `CredUIPromptForWindowsCredentials` faults again, the probe
does not crash. It prints, and exits `3`:

```text
LAMPROBE collected=false rc=4294967295 packed_length=0 auth_package=0 reason=native exception <Type> inside CredUIPromptForWindowsCredentials: <message>
```

Transcribe it the same way -- the LAMPROBE line, the exit code and the sha256 line -- and do not go on to
step 3. (Should the console meet a fault in step 3, it refuses at CONFIRM, exit 3, naming the exception
type, and writes no gate.)

**Nothing an agent session ran has shown that the prompt works.** Every measurement of the probe in this
build (WP-4 T-29) plants the prompt call in a child process, runs the probe's main flow with stdin
redirected so that it refuses, or reads the file statically. No session has raised the secure-desktop
prompt through the probe or the console, and `LsaLogonUser` has never been called. Your three runs are the
first measurements of that path.

### 5.7 THE WAKE STARTER -- how you wake a seat in the worktree you prepared

**Why it exists.** The CLI has no live-injection -- measured on CLI 2.1.258 in
`docs/framework/design/batch-4-proposals.md` item 2: `--resume` on a running session is refused,
`--fork-session` copies the transcript from disk, and the harness's live-inject tools are unreachable
from a headless runner. So waking the next seat is **your** act, and `tools/lam/lam-wake.ps1` turns the
copy-paste into one command. By design it **embeds**
STATUS.md's head brief into the worktree; it does not `--add-dir` the main checkout, which would widen
the seat's file-tool reach into the repository of record.

**What the closing runner must write, and where.** One JSON object per wake, at
`<mission root>/.mission-runtime/lam/wake/<stamp>-<sid>.wake.json`, carrying seven fields, each a
non-empty string:

| field | what it carries |
|---|---|
| `head_sha` | the full commit the operator-prepared worktree must stand on |
| `batch` | the batch and session label (printed; not part of the argv) |
| `seat_name` | the seat's name: the `-n` value and the name in the opening prompt |
| `model` | the `--model` value |
| `effort` | the `--effort` value |
| `worktree_path` | the **absolute, drive-qualified** path (`X:\...`, on a drive that is not a network drive) of the worktree you prepared |
| `brief_source` | resolved against the mission root; ordinarily `.mission-runtime/lam/STATUS.md` |

The starter takes the newest artifact by **ordinal file-name sort, never by timestamp**, so `<stamp>`
must sort as text: write it as UTC `yyyyMMddTHHmmssZ`. A file whose name does not end `.wake.json` is
ignored. Every field that reaches the argv is held to what its slot can hold, and refused otherwise
(`ARTIFACT-FIELD-UNSAFE`, naming the field; the value itself is never echoed) -- **the argv decision**,
below, says why:

| field | its slot holds | refused unless it matches |
|---|---|---|
| `seat_name` | a name (`-n`, and the name in the prompt) | `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` |
| `model` | a model id (`--model`) | `^[A-Za-z0-9][A-Za-z0-9._:\[\]-]{0,99}$` |
| `effort` | a level (`--effort`) | one of the values the installed CLI's `--help` lists for `--effort`; when it lists none, `^[a-z]{1,16}$` |
| `head_sha` | a full commit id (compared with the worktree's HEAD) | `^[0-9a-f]{40}$` |

Each pattern is matched case-sensitively, with `$` as the end of the string (a trailing newline does
not pass). The effort values are read from `claude --help` at launch; **measured on CLI 2.1.258
(2026-09-15, read-only):** its `--help` lists `(low, medium, high, xhigh, max)` on the line under
`--effort`, so the enumerated rule is the one that applies today, and the starter prints which rule it
applied. The prompt is composed from the validated `seat_name` alone.

**Your one command, from the main checkout,** once you have prepared the worktree at `head_sha`
yourself -- the starter never creates, removes or merges a worktree and never pushes; STATUS.md
section E's rules 1, 2 and 5 stay yours:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\lam-wake.ps1
```

`-MissionRoot` defaults to `.` and is resolved once to a full path, which must be drive-qualified on a
drive that is not a network drive (run it from the main checkout by its drive-letter path, not through
a UNC path). The starter prints the artifact,
the worktree, the brief's byte count and sha256, the resolved `claude.exe`, the effort rule it applied
and the seven argv tokens, writes `<worktree_path>\.wake-brief.md` -- after examining whatever already
stands at that name (**the target decision**, below) -- then puts the shell **in** the worktree and proves
it is there (**the launch location decision**, below), and only then runs the resolved `claude.exe`
with:

```text
claude -n <seat_name> --model <model> --effort <effort> "You are the <seat_name> seat; read ./.wake-brief.md and begin."
```

No `-w` (you cut the worktree; the app's worktree checkbox stays off) and no `-p` (the seat is
interactive), and nothing else. It exits with claude's exit code.

**The argv decision (a review finding).** The design note documents the launch as
`Set-Location <worktree>; & claude -n <name> --model <m> --effort <e> "<prompt>"`
(`batch-4-proposals.md` item 2), and that argv is what an
**application** receives. The reviewer measured what a shim does to it: with a `claude.cmd` stub first
on PATH and the `seat_name` `x&echo.INJECTED>rv-pwn.txt&rem`, cmd.exe re-parsed the command line, the
stub received only `-n x` instead of seven tokens, and cmd.exe created `rv-pwn.txt` -- and the wake
artifact is written on a plane agents can write. A shim that re-parses the argv delivers something
other than the documented argv, so the starter launches **only** a resolved `.exe`: `claude` must
resolve, by PowerShell's own precedence (the one command a bare `claude` would run), to an application
whose file is a `.exe`; a `.cmd`, `.bat` or `.ps1` shim, a function or an alias is refused
`CLAUDE-NOT-EXE` before anything is read from the artifact, and nothing is invoked to find out. And
because each argv slot is documented as a value of one kind, each field is held to its slot (the table
above) -- refused, never escaped or repaired. **If your `claude` is an npm global install** (it leaves
`claude.cmd` and `claude.ps1`), the starter refuses it: put the directory holding the native
`claude.exe` first on PATH (on the host this was measured on, `%USERPROFILE%\.local\bin\claude.exe`).

**What it writes.** Its only write **into the mission root or the worktree** is
`<worktree_path>\.wake-brief.md`. That file lies under the
mission root whenever the worktree does: a `<mission root>\.claude\worktrees\<id>` tree -- where
dispatched workers' trees were placed until the runner relocated them, and where the unmigrated legacy trees
still stand -- is a legitimate seat placement and is admitted, and the brief is then written there.
(Since then the runner places each dispatched worker's tree outside the mission root, at
`<parent>\<leaf>-worktrees\wt-<id>`, section 5.2; the starter composes no placement of its own and
reads `worktree_path` from the wake artifact.) A
worktree inside `<mission root>\.mission` or `<mission root>\.mission-runtime` -- the planes the
starter must not write -- is refused `WORKTREE-IN-MISSION-PLANE`, and a worktree that **is** the
mission root is refused `WORKTREE-IS-MISSION-ROOT`. The runtime plane is read, never written.
Elsewhere it writes one thing more, and it is not its own: `Add-Type` compiles the starter's interop type
on first use through the CLR's CodeDom, which puts temporary compiler files under `%TEMP%` and removes
them again. Nothing else on the machine is written.

**The alias decision (a re-review defect).** The design note launches claude "in the
operator-prepared worktree", the length band below is the one WP-2 measured over
drive-qualified local worktree roots, and the refusals above say the worktree is neither the mission
root nor inside a plane. A comparison of path **strings** did not hold that. Measured: a
`worktree_path` of `\\localhost\C$\<root>\.mission-runtime\seat-wt` or `\\localhost\C$\<root>\.mission\seat-wt`
(and the same through `\\127.0.0.1`), a repository at `head_sha`, and `\\localhost\C$\<root>` for a
mission root that is itself a repository at `head_sha`, each exited 0, wrote `.wake-brief.md` there and
launched claude there -- `GetFullPath` leaves a UNC path as it is, and git answers `--show-toplevel` in
the same form; so did a `-MissionRoot` named through UNC or through a SUBST drive letter over a literal
worktree inside its `.mission-runtime`. So, before anything is written:
- `worktree_path` and the resolved mission root must be **drive-qualified** (`^[A-Za-z]:\\`) on a drive
  whose `System.IO.DriveInfo.DriveType` is not `Network`: a UNC, `\\?\` or `\\.\` form is refused
  `WORKTREE-NOT-LOCAL` / `MISSION-ROOT-NOT-LOCAL`, and so is a network-mapped drive letter (measured: a
  letter mapped to `\\localhost\C$` reports `Network`);
- the mission-root and plane comparisons use **canonical final paths** for the worktree, the mission
  root and both plane directories: each existing directory is opened (`CreateFile` with
  `FILE_FLAG_BACKUP_SEMANTICS`, share read|write|delete) and named by `GetFinalPathNameByHandle`
  (`VOLUME_NAME_DOS`); the `\\?\` prefix is removed, case is folded, and the paths are compared with a
  trailing separator. A plane where **nothing stands** cannot contain the worktree and is not
  canonicalised -- and whether anything stands there is decided by an open of its own, not by
  `[System.IO.Directory]::Exists` (**the plane-absence decision**, below). Any failure to canonicalise --
  an open or a naming that fails, or a final path that is not drive-qualified -- is refused
  `PATH-NOT-CANONICAL` (fail closed).

**What the canonical comparison covers, and what it does not (measured 2026-09-15).** It covers a SUBST
drive letter aliasing the mission root (the final path is the directory's own), a junction (the final
path is its target) and an 8.3 short name (`GetFullPath` already expanded it; its final path is the long
one). It examines **directories**, and the write opens a **file**, so the write's own target is examined
separately (**the target decision**, below). Not measured, and not claimed: a volume mounted at a folder
path (mounting one needs administrative rights, which the measuring session did not hold) and symbolic
links (creating one was refused "Administrator privilege required").

**The plane-absence decision (a final review defect).** The plane loop used to skip a
plane whenever `[System.IO.Directory]::Exists` said false, and `Exists` says false for more than absence
-- so a plane whose name could not be **read** was a plane never compared, in front of a comparison this
page calls fail-closed. **Measured 2026-09-15:** with `ListDirectory` denied to the running user on the
mission root and `ReadAttributes` denied on `<root>\.mission-runtime`, and the worktree a real repository
at `head_sha` **inside** that plane, `Exists` answered false, the plane was never compared, and the
starter exited 0, wrote `.wake-brief.md` **inside the plane** and launched. (That shape is what it takes:
a deny on the plane alone changes nothing, because a caller is granted `FILE_READ_ATTRIBUTES` implicitly
through the parent's `ListDirectory`.) So a plane counts as absent **only** when opening its name --
`FILE_READ_ATTRIBUTES`, share read|write|delete, `FILE_FLAG_BACKUP_SEMANTICS` **and**
`FILE_FLAG_OPEN_REPARSE_POINT` -- fails with `ERROR_FILE_NOT_FOUND` (2) or `ERROR_PATH_NOT_FOUND` (3).
Any other failure, `ERROR_ACCESS_DENIED` (5) included, is refused `PATH-NOT-CANONICAL`. Not following
reparse points keeps the other direction honest: a plane that is a junction to nothing **stands** at its
name, so it is canonicalised -- and refused when that fails -- instead of being read as absent.

**The target decision (final review, the hard link).** **Measured 2026-09-15:** a
`.wake-brief.md` planted in an **admitted** worktree as a **hard link** to a file inside
`<root>\.mission-runtime` was written **through**, and the plane file's bytes changed -- so "the only
write is `.wake-brief.md` inside the worktree" did not hold. So before the write, whatever stands at the
target is opened without following reparse points and named by `GetFileInformationByHandle`: a reparse
point (`FILE_ATTRIBUTE_REPARSE_POINT`) or more than one hard link (`nNumberOfLinks > 1`) is refused
`BRIEF-TARGET-UNSAFE` -- remove the file and run the starter again -- and so is any other failure to
examine it. Nothing standing there is the ordinary case and the write creates the file; an **ordinary**
pre-existing `.wake-brief.md` is still overwritten as before, and a **directory** standing there is still
left to the write, which fails `BRIEF-WRITE-FAILED`.

**The launch location decision (a final review defect).** The note launches claude
**in** the operator-prepared worktree. The launch used to push there with a bare `Push-Location` under
`ErrorActionPreference` `Continue`, so a push that failed printed an error and the script carried straight
on. **Measured 2026-09-15**, in library mode, with the worktree renamed away after the brief was written:
the push failed and the CLI was launched anyway, with its current directory the **caller's** -- the
mission root; the same shape was measured against a worktree the push could not enter for want of access.
So the push is `-ErrorAction Stop` inside a `try`, and the directory it actually reached is then compared
with the worktree **by canonical final path**; a push that fails, a location that cannot be canonicalised,
or a location that is not the worktree is refused `LAUNCH-LOCATION-FAILED` and **nothing is launched**.
The brief has been written by then, and the refusal says so -- it is yours to remove.

**The residual this does not close: a directory swapped between the check and the write.** The plane
comparison and the write are separate opens, so a worktree that passes `Assert-LamWakeWorktree` and is
then replaced is written wherever its name then leads. **Measured 2026-09-15 in library mode:** with the
admitted worktree renamed away after `Assert-LamWakeWorktree` returned and a junction into
`<root>\.mission-runtime` put at its name, the write landed in the plane. It is **recorded, not fixed**,
and it is recorded under the note's own residual below: the wake's safety rests on a human being the only
one at the keyboard, and anything able to swap a directory under the starter mid-run already owns the
machine. Closing it would mean holding one handle from the check through the write and writing through
that handle -- a larger change than this starter's job, and one to make only if the residual below ever
stops holding.

**What the brief is.** The **bytes** of `brief_source` from offset 0 up to the first byte of the first
line matching `^## 10\.` -- never decoded, re-encoded or newline-normalised. **Where STATUS.md stacks
several editions above its first `## 10.` line, the slice spans all of them** -- the newest brief,
which may carry no `## 10.` section of its own, and every edition beneath it down to the marker.
The design note measured its slice when only one edition stood
above the marker. The marker is the ruled boundary; if only the newest edition should be embedded, it
is the edition layout, not the starter, that has to change.

**`.wake-brief.md` is a snapshot, and it is yours to ignore and clean.** It is the brief as it stood
at launch; a later STATUS.md edition does not reach a seat already running. It sits untracked in the
worktree: delete it when the seat is done, and never stage it (a seat staging by explicit pathspec
never picks it up).

**What it refuses -- exit 2, the reason named as `REFUSED [<CODE>]`, nothing written, no CLI
launched.** Every assertion but the last runs before the one write, in this order (the last,
`LAUNCH-LOCATION-FAILED`, comes after it, and says so):
- with `VANGUARD_AUTH_MODE` set, first of all: `AUTH-MODE-UNKNOWN`, `AUTH-MODE-KEY-ABSENT` and
  `AUTH-MODE-BOTH-CLAIMED` (section 7c);
- the mission root and the CLI's kind: `MISSION-ROOT-ABSENT`; `MISSION-ROOT-NOT-LOCAL` (not
  drive-qualified, or on a network drive); `CLAUDE-ABSENT` (`claude` resolves to no command);
  `CLAUDE-NOT-EXE` (it resolves to anything but a `.exe` application -- nothing is invoked);
- the artifact: `WAKE-DIR-ABSENT` and `WAKE-DIR-EMPTY` (no `*.wake.json`); `ARTIFACT-UNPARSABLE`,
  `ARTIFACT-FIELD-MISSING`, `ARTIFACT-FIELD-UNSAFE` (`head_sha`, `seat_name` or `model` outside its
  slot, named);
- the brief: `BRIEF-SOURCE-ESCAPES` (it resolves outside the mission root), `BRIEF-SOURCE-ABSENT`,
  `BRIEF-MARKER-ABSENT` (no `^## 10\.` line), `BRIEF-EMPTY`;
- the worktree: `WORKTREE-NOT-ABSOLUTE` (checked when the artifact is read; the starter's second
  check of it is unreachable from the main flow, and stays for library mode); `WORKTREE-NOT-LOCAL` (not
  drive-qualified, or on a network drive); `WORKTREE-ABSENT`; `PATH-NOT-CANONICAL` (the worktree, the
  mission root or a plane cannot be canonicalised -- a plane counts as absent only when opening its name
  fails with not-found, so one that cannot be read is refused, not skipped);
  `WORKTREE-IS-MISSION-ROOT` (a
  seat never opens at the repository of record) and `WORKTREE-IN-MISSION-PLANE` (inside `.mission` or
  `.mission-runtime`), both by canonical final path; `WORKTREE-TOO-LONG`; `GIT-ABSENT`;
  `WORKTREE-NOT-A-REPOSITORY` and
  `WORKTREE-NOT-TOPLEVEL` (git's `--show-toplevel` must name the path itself);
  `WORKTREE-HEAD-MISMATCH` (its HEAD is not `head_sha`);
- the CLI's flags: `CLAUDE-HELP-FAILED`; `CLAUDE-FLAG-ABSENT` (`claude --help` does not list
  `-n, --name`, `--model` or `--effort` -- only `--help` is read, and no session is started to find
  out); then `ARTIFACT-FIELD-UNSAFE` naming `effort`, when it is outside the values that help lists (or
  outside `^[a-z]{1,16}$` when it lists none);
- with `VANGUARD_AUTH_MODE` set: `AUTH-MODE-KEY-IN-ARGUMENT` and `AUTH-MODE-KEY-IN-FILE` (key mode: the argv,
  the brief, the worktree's `.claude` settings and its root files the CLI loads -- `CLAUDE.md`, `CLAUDE.local.md`,
  `.claude\CLAUDE.md`, `.mcp.json`), or `AUTH-MODE-BOTH-CLAIMED` (subscription: a credential setting other than the
  subscription's own token, or a key-shaped value, in those settings);
- the write's target: `BRIEF-TARGET-UNSAFE` (what already stands at `<worktree_path>\.wake-brief.md` is
  a reparse point, or carries more than one hard link, or cannot be examined); and
  `BRIEF-WRITE-FAILED`;
- **after** the write, and the only refusal that leaves `.wake-brief.md` behind:
  `LAUNCH-LOCATION-FAILED` (the shell could not be put in the worktree, or the directory it reached is
  not the worktree by canonical final path) -- nothing is launched, and the refusal says the brief was
  written and is yours to remove;
- and `INTERNAL-ERROR` for any exception that is not one of the refusals
  above -- not unreachable: STATUS.md held open by another process with no sharing while the starter
  runs makes the brief's read throw, and the starter refuses `INTERNAL-ERROR`, writing nothing.

**The length band, and its source.** `worktree_path`, as a full path with no trailing separator, is
refused above **136** characters: the largest worktree root WP-2 arm G measured GREEN
(at a root of 136 with candidate 2, where the uncured arm F was
red at the same root). Its cured ceiling (about 141) and fidelity bound (about 138) are
**computed, not run**, and the starter does not admit up to them; git itself refuses a linked-worktree
path of 216 bytes or more in UTF-8 (`'$GIT_DIR' too big`) -- 216 characters only when every character
is ASCII: a path holding one non-ASCII character was measured refused at 215
characters, 216 bytes -- and no `core.longpaths` setting moves that. The refusal names all four figures
(its text still says characters). This replaces the note's "< ~150 chars (MAX_PATH)", which
a later erratum found too loose and naming the wrong mechanism. The measured band stays open; when it
moves, this bound is re-derived with it. **The worker-tree relocation moved those computed
companions**: `tests/lam/instrument-WP-2.ps1` recomputes them over the
relocated worker suffix to a last green root of 149 (was 141) and fidelity to 146 (was 138), with the
instrument-wide green ceiling near a root of 143 -- **computed, not run**. The 136 the starter admits
was measured at the earlier placement and is not re-run here.

**Checked by WP-3 C-4a**, which drives the real starter in a child process with a compiled stub
`claude.exe` first on that process's PATH and every real `claude` removed from it, over a scratch root
under `%TEMP%`: the argv is exactly the seven tokens, the stub runs in the worktree, `.wake-brief.md`
equals the fixture STATUS.md's bytes up to the marker byte for byte (CRLF, bare LF and a non-ASCII byte
in it), the newer artifact by name wins over a later-written older one, a 136-character worktree and a
`.claude\worktrees\<id>` worktree under the mission root are admitted (the latter gaining exactly
`.wake-brief.md`), and **every** refusal above, `INTERNAL-ERROR` included (STATUS.md held open with
`FileShare.None` for the starter's run), has a row that exits 2, names it, writes nothing, and calls
no stub -- or, for the four reachable only after `--help` (`CLAUDE-FLAG-ABSENT`, `CLAUDE-HELP-FAILED`,
the `effort` slot and `BRIEF-WRITE-FAILED`), calls the `.exe` stub for `--help` alone;
`ARTIFACT-UNPARSABLE` is driven both by text that does not parse and by a JSON array holding one
otherwise valid artifact. The re-review's aliases are driven with a real repository at `head_sha`
behind each, a control proving the alias reaches it: `worktree_path` through `\\localhost\C$` into
`.mission-runtime` and into `.mission`, through `\\127.0.0.1\C$` into `.mission-runtime`, and
`\\localhost\C$\<root>` for a mission root that is a repository, each refused `WORKTREE-NOT-LOCAL`; a
`-MissionRoot` through `\\localhost\C$` refused `MISSION-ROOT-NOT-LOCAL`; a free SUBST drive letter
aliasing a mission root, as `<letter>:\.mission-runtime\seat-wt` and as `-MissionRoot <letter>:\.` over
a literal worktree in its `.mission-runtime`, and a junction outside the root reaching its
`.mission-runtime`, each refused `WORKTREE-IN-MISSION-PLANE` by the canonical comparison (the letters are
removed in the member's `finally`); and a `.mission` that is a junction to nothing, refused
`PATH-NOT-CANONICAL`. The review's shape
is driven too: a `claude.cmd` stub resolving ahead of the `claude.exe` stub, with the reviewer's
injecting `seat_name` planted, is refused `CLAUDE-NOT-EXE` with neither stub called and no
`rv-pwn.txt` anywhere under the scratch root; a `claude.ps1` likewise; the same `seat_name` with only
the `.exe` stub is refused naming `seat_name`; a `model`, a `head_sha` and an `effort` outside their
slots are refused naming the field, the `effort` both against an enumerating `--help` and, with a
`--help` that enumerates nothing, against `^[a-z]{1,16}$`.

The final review's three defects have rows there too, each with the ordinary case beside it as a control.
A mission root whose `.mission-runtime` cannot be **read** -- `ListDirectory` denied to the running user
on the root and `ReadAttributes` denied on the plane, with a repository at `head_sha` inside it that
carries an explicit grant so it stays reachable -- is refused `PATH-NOT-CANONICAL`, with nothing written
into the plane and the stub never called; a control first asserts that `[System.IO.Directory]::Exists`
really does answer false for that plane while the worktree inside it is still there, and the member
compares both directories' **ACE lists** before and after and removes the deny ACEs in its own `finally`
as well as in the row (ACE lists rather than raw SDDLs, because `Get-Acl` reports `D:(...)` before
anything touches a directory and `D:AI(...)` after). A `.wake-brief.md` planted in an admitted worktree
as a **hard link** to a file inside `.mission-runtime` is refused `BRIEF-TARGET-UNSAFE` with that plane
file's sha256 unchanged and the stub called for `--help` alone -- and beside it an **ordinary**
pre-existing `.wake-brief.md` is still overwritten with the brief's bytes and launched in the worktree,
so a cure that refused every re-wake would turn the control red. And the launch's location is driven in
**library mode**, the only place that can stand between the one write and the launch:
`Invoke-LamWakePrepare` writes the brief, `Enter-LamWakeWorktree` is shown to admit the prepared worktree
and move the shell into it, the worktree is then moved away, and the second call must refuse
`LAUNCH-LOCATION-FAILED` with the stub called for `--help` alone, never launched, and the location left
where it was found.

**Residual under computer-use (the note's, carried).** The starter closes the copy-paste gap and
changes nothing about the live-inject boundary. An agent **with** computer-use can type into an
already-interactive orchestrator's window, `claude attach` a background session and type into it, or
drive the desktop app to reach the live-inject a headless runner cannot; it can run `lam-wake.ps1`
without you, and -- worse -- drive your terminal through the acts STATUS.md section E reserves to you:
cutting a `-w` worktree (rule 2), or a `git merge` or push that lands a branch with no human merge
boundary (rules 1 and 5). The wake's safety rests on a human being the only one at the keyboard; this
starter only makes the **lawful** path one command instead of a paste. Keep the 1800 s Stop-hook wedge
(it holds a stray headless wake, buying detection time) and keep merge and push behind a terminal you
control; neither stops a computer-use agent that owns the desktop.

### THE COMPLETE OPERATOR INSTALL SEQUENCE, IN ORDER

Everything this page asks of you, top to bottom, each step naming the section that carries its
detail and the member that checks it. Do them in this order; several later steps are only
meaningful against the result of an earlier one.

1. **Preconditions** — §0. Confirm the sealed A1 set re-measures against §1's first table (K-5 does
   this from the suite; run it before you move anything).
1b. **PRE-SWAP: sweep the sealed library for the newline-crossing regex class (RES-10).**
   A next-gen cure fixed fifteen sites of `(?m)^key:\s*VALUE` across the next-gen library
   and `tools/lam` — a spelling that lets `\s` cross a newline, so an empty `kind:` followed by
   `push` on the next line read as a push gate. The sealed library could not be swept from inside a
   session by shell. Run this at your terminal, from the repository root, before §2:

   ```powershell
   Select-String -Path .\tools\framework\hooks\lib\evidence-common.ps1 -Pattern '[A-Za-z_]+:\\s\*' |
     Where-Object { $_.Line -notmatch '^\s*#' } | Select-Object LineNumber, Line
   ```

   Then, for `(?m)`-mode end anchors, the second spelling of the same hazard:

   ```powershell
   Select-String -Path .\tools\framework\hooks\lib\evidence-common.ps1 -Pattern '\(\?m\).*\\s\*\$' |
     Where-Object { $_.Line -notmatch '^\s*#' } | Select-Object LineNumber, Line
   ```

   **The shadowing analysis, which decides what a hit means.** The next-gen library dot-sources the
   sealed one and then REDEFINES functions by name. After §2's swap, a sealed site inside a function
   the next-gen library redefines is **shadowed** — never executed — and a site inside a function it
   does not redefine stays **live through delegation**. So for each hit, take its enclosing
   `function` name and check whether `tools/evidence-hooks-next/hooks/lib/evidence-common.ps1`
   defines a function of that name:

   ```powershell
   Select-String -Path .\tools\evidence-hooks-next\hooks\lib\evidence-common.ps1 -Pattern '^function\s+(\S+)' |
     ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique
   ```

   **The seal-move decision rule:** **zero hits → no seal move**, record the sweep and proceed to §2.
   **One or more hits, all shadowed → no seal move**, record each with its shadowing function and
   proceed. **Any live hit → a seal-move amendment first**, the edited library authored to a
   scratch path and placed by you, re-hashed, the new anchor recorded — §3's discipline, because a
   sealed hash moves.

   **What the builder measured at closure, read-only, at anchor `ec27ab3a33639b95` / 80479 bytes:
   ZERO sites in every spelling** — the `(?m)^key:\s*` idiom, any `key:\s*` inside a quoted literal,
   and `(?m)`-mode `\s*$` end anchors all return nothing. The class was born in the next-gen library's
   YAML-field readers, which the sealed library never had. That is prior evidence for the decision
   rule, not a substitute for this step: run it, record what it says, and if it disagrees with the
   figure above, the sweep is right and the figure is stale.

2. **The registration swap** — §2 (Part 6). Point every PreToolUse / PostToolUse / Stop / PreCompact
   registration at `tools/evidence-hooks-next/hooks/`. **This is the step that installs gate
   protection and push gating at all**, and it is the closure for the two live gaps this page
   discloses: the sealed guard's `.mission/gates` allow (§5, "what §5 does not close") and the
   sealed guard's glob gap (§5.5). Nothing in §5 substitutes for it.
3. **The sealed-hash re-seal** — §3. Ratify the amendment that moves the anchor; place the edited
   library yourself; `Get-FileHash` it at your terminal; record the new anchor.
4. **Your project's pre-push DECIDER** — §5.4. Install the `/bin/sh` hook at the hooks path git
   itself reports. Until this is done, `mission-dispatch.ps1` refuses to dispatch into your project,
   and that refusal is the machinery working.
5. **The sealed-guard rule additions** — §5.1 (the `*.superseded.yaml` marker rule), §5.2 (the
   dispatched worker's plane), §5.3 (case-insensitive matching — **the most important item on this
   page**). One sealed-hash move for all three.
6. **The A1 negative suite** — §6. The guard change must not move a single A1 verdict.
7. **The four probes, at your own terminal, each with its control, each recorded whatever it says:**
   * **case** — §5 procedure step 6: `.MISSION/EVIDENCE/...` must deny on the guard §5.3 edits;
   * **trailing dot** — step 7: `.mission-runtime/evidence./x.jsonl` — record both results; on the
     sealed guard the dotted form ALLOWS while its control DENIES, and the next-gen guard denies both;
   * **8.3 short name, and behind the extended-length prefix** — step 8: all four combinations must
     deny and the ordinary path behind the prefix must allow;
   * **glob** — §5.5: the `.mis*` junction payload must deny on the next-gen script and its `docs`
     control must allow; run the same payload through the SEALED script once, before the swap, and
     see it allow. **That flip is what tells you the swap closed the gap rather than that the gap was
     never there.**
8. **Re-run the instrument members** that drive the real hook against the swapped registration —
   `WP-2 R-12`, `WP-2 R-12b`, `WP-4 T-3c`, `WP-4 T-5`, `WP-4 T-6` (procedure step 5).
9. **The §17.3 install-validation step** — §6. Not a formality.
10. **What stays open after all of it, stated so it is read:** a write *through* a link that
    already existed before the session is not resolved by either guard (§5.5, RES-07); the sealed
    library was swept read-only at closure and carries **no** site of the newline-crossing class in
    any spelling (RES-10's "very likely" premise measured false; step 1b is where you confirm it);
    D6 is still half a pathway (§4); and D4 origin-side attestation
    is registered and unbuilt (§5.4, *what this does NOT do*). The registered residual manifest is
    `docs/framework/LAM-RESIDUALS.md`, and the completion-acceptance gate binds it by hash.

### Procedure (all five additions, one move)

It moves a sealed hash, so §3's amendment discipline applies:

1. Ratify an amendment authorizing the sealed-hash move, naming the current anchor to retire.
2. Have the edited library authored to a scratch path, and **place it yourself**.
3. `Get-FileHash` the placed file at your terminal and record the new anchor.
4. Re-run the A1 negative suite (§6) — the guard change must not move a single A1 verdict.
5. Re-run instrument members `WP-2 R-12`, `WP-2 R-12b`, `WP-4 T-3c`, `WP-4 T-5` and `WP-4 T-6`
   against the swapped registration. Each drives the real hook, and each checks **both directions** — the denials *and*
   the writes that must still succeed. A one-directional check would bless a rule that denies
   everything, which breaks every dispatch and is the failure this whole item exists to undo.
6. **VERIFICATION PROBE for §5.3, run at your own terminal after the swap.** Do not take the
   re-hash as proof the behaviour changed — a sealed hash proves *which bytes are installed*, not
   *what they do*. Pipe a case-varied write through the installed guard and confirm it is DENIED:

   ```powershell
   '{"session_id":"probe","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":".MISSION/EVIDENCE/probe.yaml"}}' |
     powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\framework\hooks\evidence-guard-pretooluse.ps1
   ```

   > **THIS BLOCK POINTED AT A PATH THAT DOES NOT EXIST, AND SO DID ITS OWN CONTROL** (found by
   > WP-5, driven). Steps 6, 7 and 8 all piped into `.\.claude\hooks\evidence-guard-pretooluse.ps1`;
   > `.claude/` has no `hooks` directory, and §2's swap registers `tools/evidence-hooks-next/hooks/`.
   > Driven verbatim: exit **-196608**, *"the argument to the -File parameter does not exist"* — never
   > a `permissionDecision`. **The probe and the control below it failed identically**, for a reason
   > with nothing to do with the guard, so the block could not distinguish a working guard from a
   > broken one. A control that fails the same way as its probe is not a control.
   >
   > The guard itself is sound: against the path §2 actually registers, the same payload denies
   > `.MISSION/GATES` and `.mission/gates` at exit 2 and allows `README.md` at exit 0.

   **Expect exit 2 and `"permissionDecision":"deny"` — and this step is only meaningful if you run it
   BEFORE applying §5.3 as well.** Before: **allow, exit 0**. After: **deny, exit 2**. That flip is
   the whole measurement, and it is exactly the row §5.3's own table promises.

   > **THIS BLOCK HAS BEEN WRONG TWICE, IN TWO DIFFERENT WAYS, AND THE SECOND WAS THE FIX FOR THE
   > FIRST.**
   >
   > *First:* it piped into a hooks directory under the agent-settings folder that **does not
   > exist** — exit `-196608`, *"the argument to the -File parameter does not exist"*, never a
   > `permissionDecision` — and **the probe and its own control failed identically**, so it could not
   > tell a working guard from a broken one. A control that fails the same way as its probe is not a
   > control.
   >
   > *Second:* the first fix routed it to the **next-generation** guard. But §5.3 edits the
   > **SEALED** library, and the next-generation guard redefines `Test-PathHit` *after* dot-sourcing
   > A1 — shadowing the very function §5.3 changes. Driven with §5.3 applied and not applied: **deny,
   > exit 2, both times, byte-identical.** Still no discriminating power, and now in the unsafe
   > direction: the operator was told to read that deny as *"§5.3 took effect."*
   >
   > It now probes the guard §5.3 edits, at a path §5.3 changes the answer for.
   >
   > **AND ITS OLD RED WAS UNREACHABLE, WHICH IS A THIRD DEFECT IN THE SAME BLOCK** (found by
   > WP-5, driven). The step used to end *"if the upper-case probe allows, the swap did not take
   > effect"* — but the probe names the guard with `-File`, so the hook **registration** is never
   > consulted, and the validator's fixture had **no agent-settings directory at all** and still
   > produced the "pass" result. A probe that invokes a script directly can tell you what that script
   > DECIDES; it can tell you nothing about whether the harness would ever CALL it.
   >
   > **So this step no longer claims to verify the swap.** It verifies §5.3. Whether the registration
   > took effect is a different question with a different answer: read the registered command out of
   > the settings file (§2's table shows what it should say) and confirm it names the next-generation
   > path — or drive an ordinary denied write through the harness itself and see the denial arrive.
   >
   > **The shape of both errors is the same:** each fix corrected the half of the instruction that was
   > visibly wrong without asking whether the corrected version measured the thing it names.

7. **TRAILING-DOT CASE, run at the same terminal and in the same breath as step 6.** Repeat the probe
   with a trailing dot appended to the PROTECTED COMPONENT — `.mission-runtime/evidence./x.jsonl`,
   not a `.mission/gates` path, which §5.3 above already tells you is unprotected and so can prove
   nothing here.

   > **THIS STEP NAMED AN UNPROTECTED PATH TOO, AND ITS OWN LAST SENTENCE CONDEMNED IT** (found by
   > WP-5, driven: the undotted control **allowed, exit 0**, on every route — Edit and Bash, with
   > and without `cwd`, relative and absolute, on both guards). It read `.mission-runtime/lam/x.jsonl.`
   > It rejected `.mission/gates` for being unprotected and substituted another unprotected path.
   >
   > **The guard keeps TWO arrays and the difference is the whole trap:** `EvidenceProtectedPaths`
   > holds `.mission-runtime/evidence`, `.mission/evidence`, `tools/framework/hooks`,
   > `tools/framework/install-evidence-hooks.ps1`, `tools/framework/tests` and
   > `.claude/settings.json` — **six entries, and this sentence said four** (a WP-5
   > finding). The code block below it is correct and K-4 checks it; only the prose was short, which
   > is the failure mode of an enumeration written out twice; `EvidenceParentPaths` holds `.mission-runtime`, `.mission`,
   > `tools/framework` and `.claude`. The parent list is the **metacharacter tier** — it denies a
   > shell command that combines one of those with a metacharacter — and it does **not** protect a
   > file-tool write to an arbitrary path beneath it. `.mission-runtime/lam` looked protected because
   > its parent is on a list; it was the wrong list. Run the same path without the dot first, as the control.

   > **THE DOT USED TO SIT AFTER THE FILENAME, WHERE IT PROVABLY CANNOT CHANGE THE ANSWER** (found
   > by WP-5, driven). `.mission-runtime/evidence/x.jsonl.` keeps the protected prefix
   > `.mission-runtime/evidence` intact, so the matcher denies it for the ordinary reason and the
   > probe returned **deny, exit 2, byte-identical to its own control, in all four guard-and-variant
   > combinations**. It could not produce ALLOW on any route. A probe whose two arms are produced by
   > the same mechanism is not a probe, and this one then told the operator that its unanimous DENY
   > meant the exposure was gone — **a documented all-clear manufactured on the exact question the
   > step exists to answer.** Step 8 below is the counter-example: same page, same exposure class,
   > perturbation placed where it decides something.

   **Record both results; this step does not predict either one.** Windows strips trailing dots when
   it resolves a path, so that spelling reaches the protected file while not necessarily matching the
   protected string, and the matcher compares strings before the OS resolves anything (E72).

   **What was measured at the head this page was last driven against** (found by WP-5, and
   re-run it rather than trusting it): on the **sealed A1 guard** the dotted form **ALLOWS, exit 0**
   while its undotted control **DENIES, exit 2** — and the exposure is not theoretical, because a
   write through that spelling was driven to completion and `Test-Path` on the **undotted** real path
   returned True. **The file lands in the protected directory.** On the **next-generation guard** the
   same spelling **DENIES**.

   > **SO IT IS CURABLE FROM THE DELTA, AND THIS STEP SAID IT WAS NOT** (found by WP-5,
   > driven). The next-gen guard denies every dot spelling the sealed one allows. That matters for
   > what you do about it: the exposure is a reason to COMPLETE this installation, not a permanent
   > gap to carry — and it needs no seal-move amendment, because nothing sealed has to move.

   If the dotted form ALLOWS on A1 while its control DENIES, you have reproduced the exposure:
   record it, and note that the delta you are installing closes it. If A1 DENIES it too, your A1 is
   newer than the one this page was written against — **say so, and do not read that as an all-clear
   for the class**; check the delta's answer as well, because the two guards are what this step is
   comparing. **If the CONTROL allows, stop: you are measuring nothing, and the dotted row means
   nothing either.**

8. **8.3 SHORT-NAME CASE, run at the same terminal and in the same breath as steps 6 and 7.**
   Windows exposes an 8.3 alias for any component whose name is not 8.3-legal, and a leading dot
   alone disqualifies one — so `.mission` is *also* addressable as `MISSIO~1`. Read the alias for
   your own installation first; do not assume the numbering, and do not assume the alias exists at
   all (8dot3 generation can be disabled per volume):

   ```powershell
   $fso = New-Object -ComObject Scripting.FileSystemObject
   $fso.GetFolder("$PWD\.mission").ShortName
   $fso.GetFolder("$PWD\.mission-runtime").ShortName
   ```

   That is a read-only metadata query: it creates and modifies nothing. **If it returns the long name
   unchanged, this volume generates no aliases and there is nothing to probe — record that, because
   it is a property of your volume and not of the guard.** Otherwise probe BOTH routes, since this is
   the exposure that reached one route and not the other:

   ```powershell
   '{"session_id":"probe","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"MISSIO~1/evidence/probe.txt"},"cwd":"<your repo root>"}' |
     powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\evidence-hooks-next\hooks\evidence-guard-pretooluse.ps1
   ```

   **Expect exit 2 and `"permissionDecision":"deny"`, and run the long-name spelling of the same path
   first as the control.** Then repeat with `"tool_name":"Bash"` and
   `{"command":"cp x.txt MISSIO~1/evidence/probe.txt"}`. **All four must deny.**

   **What this is actually verifying, stated precisely so a green result is not read for more than it
   is.** The alias is not a string transform — nothing in `MISSIO~1` says what it stands for, and only
   the volume can. The sealed A1 matcher therefore cannot be taught it, and **it has not been**: what
   the next-gen guard does is resolve the alias against the filesystem and ask A1 *again* with the
   resolved spelling, for the file-tool route as well as the shell route. So a passing probe tells
   you the DELTA is installed and interposing correctly. **It does not tell you A1 is safe on its
   own** — if these registrations are ever pointed back at A1 directly, the exposure returns in full.
   Where the prefix does not exist on disk the alias cannot be resolved and nothing is added, which
   makes this defence strictly weaker than the case-insensitivity fix in §5.3.

   **AND PROBE IT BEHIND THE EXTENDED-LENGTH PREFIX, which is the composition that actually got
   through.** `\\?\C:\<repo>\MISSIO~1\gates\x.yaml` was allowed by both routes, landed in the real
   gates directory, was listed by `mission-gate.ps1` as `open build-authorization`, and then
   authorized a real push — while the same path with `.mission` spelled out, in the same run, denied.
   The prefix alone is not the bypass; it is the alias *inside* it, because the canonicaliser
   collapses `\\?\` to `/?/` and nothing can resolve an alias against a prefix that exists on no
   volume. Probe all four combinations and expect all four to deny:

   | path | why it is in the set |
   |---|---|
   | `.mission/gates/x.yaml` | the control — must deny, or you are measuring nothing |
   | `MISSIO~1/gates/x.yaml` | the alias alone |
   | `\\?\<abs>\.mission\gates\x.yaml` | the prefix alone |
   | `\\?\<abs>\MISSIO~1\gates\x.yaml` | **the composition — this is the one that got through** |

   Add an ordinary path behind the prefix (`\\?\<abs>\docs\note.md`) and expect it to be
   **allowed**: without that row, a guard that denies everything looks like a cured one.

   **If a probe ALLOWS while its control DENIES, the swap did not take effect for this route**, and
   the agent-unmintability claim on this page is false for your installation until it does. An
   independent validator drove exactly that chain before the cure: the write landed in the real gates
   directory and `mission-gate.ps1 list` read it back as `push-forged  open  build-authorization`.

**State the reach honestly when you record it.** Both are defence in depth, not the controls that
make the thing safe. Under the supersession ruling a marker is inert unless an unrevoked `supersession` gate binds
its **re-derived** sha256, and gates are agent-unmintable under T-3. So each remains what it was ruled:
**a tripwire, not a boundary.**

---

## 6. §17.3 retirement — the install-validation step (REQUIRED, and it is not a formality)

The smoke harness retires the §17.3 evidence constraint **for itself only**, and its retirement
for a host project is re-homed here, explicitly: the harness carries no such step and claims none
for the host. This is that step.

**After the registration swap, run BOTH of these, in this order:**

**(a) One real ceremony-class operation in your project, with the next-gen hooks live.**

Use a ceremony you would run anyway — a ledger append through `Invoke-AtomicCommit`, or a milestone
close. It must exercise **both** patched clean-tree gates (`Assert-CleanGitTree` and
`Assert-CleanWorkingTree`) through a **real invocation**, never a direct function call in isolation.

*Accept:* the ceremony completes; **an evidence session exists for that operation** and its manifest
reads `"state": "finalized"`; its `capture-gaps.yaml` is `capture_gaps: []`.

> **Check the session the ceremony itself produced, by name, not the count of sessions.** This is
> erratum E28, and it is here because the build got it wrong: the smoke S-5 member asserted "all
> manifests are finalized", which was a true statement about four *other* sessions and no
> measurement of the ceremony's at all. A claim about **where** something ran must be evidenced by
> an artifact **that operation itself produced**.

**(b) The A1 negative suite, with the next-gen hooks live.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\framework\tests\test-a1-negative.ps1
```

*Accept:* all 14 checks pass, **unchanged**. This is acceptance member H-4, the regression that
says the next generation did not quietly relax A1. The build carries a byte-identical vendored copy
at `tools/evidence-hooks-next/tests/test-a1-negative.ps1` (74992 bytes, sha256 `03322c44…`; git blob
`9a664ba5…`) so the same suite can be run against either set.

**Only when both pass is §17.3 retired for your project.** If (a) passes and (b) does not, you have a
hook set that works for the thing you just did and has silently relaxed something else — **roll
back** (§8) rather than reasoning about which A1 check "does not matter here".

---

## 7. Closing the memory-off residual (routed here by `worker.json`)

`tools/lam/settings/worker.json` routes its memory-off residual to this document for closure at
install time. **Here is its closure, and it is not the one anybody wanted.**

**It cannot be closed on CLI 2.1.241.** No settings key disables Claude Code auto memory; the only
documented control is `--bare`, which also skips **hooks**, and a worker without hooks has no
evidence plane at all — strictly worse than the leak it would prevent. This is erratum E12,
independently confirmed three times.

**What is in force instead**, and what each template now carries as a checkable field rather than
prose (ADR-036):

| role | `separation_obtained` |
|---|---|
| worker | **none at the memory-directory layer, measured** — neither the worktree nor `worker.json` separates it: `memory_paths.auto` is the MAIN repository's per-project directory in every recorded init of a `--worktree` worker dispatch that carries the field (lam-smoke `session-D-1`, `-D-1b`, `-D-1c` and `-D-2` on 2.1.241, `-D-3` on 2.1.252) and in one probe spawn with the runner's argv in a throwaway repository, the tree as its working directory, `worker.json` handed in and no `--worktree` (2.1.258), measured. An earlier text of this row said `--worktree` gives it a different project identity; no recorded reading ever showed that |
| validator | fresh-identity session separation — and WP-6 S-2 **probes** it empirically rather than trusting it |
| orchestrator | **none at the memory layer**, stated rather than left blank; what constrains it is that its learnings reach the record only by ceremony |

**The worker row was corrected from that measurement; the
validator and orchestrator rows were not re-measured.** One memory control is on record, and it is in
no template: `autoMemoryEnabled: false` in the main checkout's `.claude/settings.local.json` turns
memory off for the orchestrator on CLI 2.1.258 and later; reconciling it with the templates
is owed.
The runner's `.worktreeinclude` placement plan includes that file for every
worker tree dispatched from the main checkout (planned read-only, by measurement
and a validator finding), and **whether a worker honours it is not measured**. No template can carry that key the way the action below says: WP-5 K-3
refuses any top-level template key that does not start with an underscore and whose name matches
`memor`, so the instruction and the member disagree (an open finding).

**Your action at install time: re-check whether the CLI you are installing against has grown a
memory-off key**, and if it has, set it in all three templates and record the version that made it
possible. If it has not, **the residual stays open and stays visible** — that is the honest state,
and a template that claimed a disable it does not have would be the overclaim design §4.5 law 4
forbids.

---

## 7b. The validator role: what the permission layer does NOT give you

**Read this before you trust `validator.json` to hold a validator read-only, because it does not.**

- **The file-tool layer is deny-by-default and works.** `dontAsk` auto-denies any tool not named in
  `permissions.allow`; only the role's result file is writable through `Edit`.
- **The shell layer is not.** `validator.json` allows bare `Bash`/`PowerShell` — a validator that
  cannot run commands cannot measure by execution, which is the one thing a fresh-identity reader
  exists to do. Redirection targets are checked against **deny rules only**, so `echo … >` and
  `sed -i` reach anything not enumerated there. This is a **grammar limitation**, disclosed on the
  artifact's own face, not an oversight you should try to close by deleting the shell.

**The enforcing control is SUBJECT INTEGRITY, and it is an ORCHESTRATOR duty — nothing in the
settings file performs it.** Before spawning a validator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\lam-validator-subjects.ps1 `
  -Mode capture -RepoRoot . -SubjectsFile <subjects.txt> -BaselineFile <baseline.json>
```

ledger the captured hashes **with the spawn line**, and after the validator returns run the same
command with `-Mode verify`. **Exit 0 = the verdict stands. Exit 3 = a subject moved: the verdict is
VOID — raise a HALT, spend the identity, spawn a new one against a re-captured baseline. Exit 2 =
no baseline, which is also a violation, because an unrun check is not a passed check.**

**Do not ask the validator what happened during the window** — its account of that window is exactly
the thing in question. And note the scope honestly: this covers artifacts named as **subjects**; a
validator that writes something nobody declared a subject is outside its reach, which is why the
subject list is derived from the contract paths a work package names rather than from the
validator's own report of what it read.

> **THE CONTROL IS EXACTLY AS WIDE AS THE SUBJECT LIST, AND THE LIST IS COMPOSED BY HAND.** Measured
> in a validation round: the set handed to the WP-5 validator **omitted three paths that WP-5's own clause
> names** — the next-gen library, this document, and the runner. Those artifacts were in scope for
> the judgment and outside the control protecting it. Nothing moved, and nothing would have been
> detected if it had.
>
> **So derive the list from the clause, in writing, before the spawn:** read the work package's text,
> list every path it names, and diff that against your subjects file. A path you remember is not a
> path the contract names. Treat a short list as a defect in the spawn, not as a smaller check.

---

## 7c. Authentication: the subscription, or an API key

Every Claude Code CLI this toolchain starts is authenticated the way the shell that starts it says, and by nothing
else -- not a mission's record, a settings file or an argument. One environment variable decides,
`VANGUARD_AUTH_MODE`:

- **Unset (the default): nothing is checked.** Every spawn inherits your environment as it always has (the
  worker-runner's child less `ANTHROPIC_API_KEY`), and the library below is not even loaded. The CLI's own precedence
  decides: the subscription Claude Code is signed in with only when no credential is in the environment -- a key, a
  bearer token or a cloud-provider selector left in the shell is used instead. `subscription` refuses one (below).
- **`api-key`: an Anthropic API key.** Set it in your own terminal -- the one you run the toolchain from, never inside
  a Claude Code session, whose hooks record every command:

  ```powershell
  $env:ANTHROPIC_API_KEY = [System.Net.NetworkCredential]::new('', (Read-Host -AsSecureString 'Anthropic API key')).Password
  $env:VANGUARD_AUTH_MODE = 'api-key'
  ```

  Never type the key itself on a command line: PSReadLine, which Windows PowerShell 5.1 ships, saves every line
  typed at its prompt to `%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`.
  `Read-Host -AsSecureString` reads the key without echoing it and keeps it out of that file.

  `ANTHROPIC_API_KEY` is the provider's documented variable, and in print mode (`claude -p`, which the runner's probe
  and workers use) the CLI uses it whenever it is present. The key reaches the CLI in the environment the spawn
  inherits, and nowhere else.
- **`subscription`: the subscription, claimed out loud.** As unset, except that a key, a bearer token or a
  cloud-provider selector in the environment, or a credential setting in a settings file the session loads (the
  subscription's own `CLAUDE_CODE_OAUTH_TOKEN` excepted), is refused, since print mode would use it instead.

In either mode nothing else changes: a mode that is admitted prints nothing, so the runner and the wake starter
print what they print with the variable unset, and only a refusal is new.

**Why an environment variable, and not a key in the mission.** The key travels in the environment only, so the
claim stands beside it, in the one place you control per shell; a mission's committed record is read by everyone
who runs the mission, and a mode there would make one operator's billing a property of the record; and none of the
four paths below reads a framework configuration of the mission, so one variable is read alike by all of them. It
is never sniffed for: a credential in the environment with the variable unset changes nothing the toolchain does.

**Where it is read.** Four places start the CLI to call a model; each reads the one variable alike, and none sniffs
for a key:

| path | what it starts | with `api-key` |
|---|---|---|
| `tools\lam\mission-dispatch.ps1`, the login probe | `claude -p "Reply with exactly the word OK and nothing else." --output-format text`, from an empty scratch folder | inherits the key; a key the CLI rejects fails the probe, and the runner refuses LOGIN-PROBE (exit 7) before any worker |
| `tools\lam\mission-dispatch.ps1`, a worker or a validator | `claude -p --model ... --settings ... --output-format stream-json ...`, in its tree | inherits the key |
| `tools\lam\lam-wake.ps1`, a seat | `claude -n <seat> --model ... --effort ... "<the brief line>"`, interactive | inherits the key; the interactive CLI asks once whether to use the custom API key -- answer yes; the CLI then records your answer in its own configuration (`.claude.json`, or the folder `CLAUDE_CONFIG_DIR` names) under the key's last 20 characters, and the toolchain writes nothing of it |
| `tools\worker-runner\runner.py`, through `tools\mission-dispatch.ps1` | `claude -p --output-format stream-json ... --settings <hook settings> ...` | keeps the key, which it removes from its child's environment in every other mode |

Two other places start the CLI without calling a model, and inherit the key the same way: the wake starter asks it
for `claude --help` before its scans, and WP-6's S-1b runs `claude --version` itself before it clones the smoke
repository -- S-1b reaches a model only through the runner. No hook starts a CLI, and there is no validator outside
the runner: a validator is the runner's worker spawn under the validator role.

**The decision and its refusals.** `tools\lam\lam-auth-mode.ps1` decides for the runner and the wake starter, and
`tools\worker-runner\env_scrub.py` the same way for the worker-runner. The mode is decided first: the runner
before `-PlanOnly`'s print, the verify gate and the probe (only the pre-push checker, which reads no credential,
has run); the wake starter before the CLI is looked up; the worker-runner's `dispatch_entry.py` before it cuts the
worktree, and its runner again before it writes its brief. The scans run once their inputs exist: the runner's
with the decision; the wake starter's after `claude --help` (which calls no model) and before the brief is
written; the worker-runner's after it writes its brief, system prompt and hook settings, and before its
subprocess. Each refuses (exit 2; in the worker-runner a raised refusal, which `dispatch_entry.py` turns into exit 3
where its own decision refuses, before the worktree, and into exit 2, a runner failure, where its runner's does):

- `AUTH-MODE-UNKNOWN` -- the variable is neither `api-key` nor `subscription` (its value is not shown);
- `AUTH-MODE-KEY-ABSENT` -- `api-key`, and `ANTHROPIC_API_KEY` is not set or is empty;
- `AUTH-MODE-BOTH-CLAIMED` -- `api-key` beside `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN` or a
  `CLAUDE_CODE_USE_BEDROCK`, `_VERTEX` or `_FOUNDRY` selector, which the CLI would use instead of the key or beside
  it; or `subscription` beside `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` or such a selector, or beside a
  settings file the session loads -- read as the next bullet but one reads the `.claude` settings, in any letter
  case -- that names a credential setting other than `CLAUDE_CODE_OAUTH_TOKEN` or carries a key-shaped value;
- `AUTH-MODE-KEY-IN-ARGUMENT` -- in key mode, an argument of the spawn carries a key-shaped value (`sk-ant-` and 20 or
  more of `[A-Za-z0-9_-]`);
- `AUTH-MODE-KEY-IN-FILE` -- in key mode, a file the spawn hands the CLI, or one the CLI reads by itself at the root
  of the tree it runs in, carries one: the prompt, the settings files its argv names and the `.claude` settings the
  session loads, the worker-runner's hook settings, system prompt and brief, and that root's `CLAUDE.md`,
  `CLAUDE.local.md`, `.claude\CLAUDE.md` and `.mcp.json`; or a settings file names a credential setting
  (`apiKeyHelper`, or one of the variables above in its `env` block). The tree is read as it will stand when the CLI
  starts, and each of those names in any letter case: a case-insensitive file system gives the CLI a `claude.md` or a
  `.Claude\settings.json` as `CLAUDE.md` and `.claude\settings.json`. The wake starter and the worker-runner read their
  worktree, which exists by then, through the file system (the worker-runner lists its root and `.claude` folders, so
  a reason names a file as it stands). The runner decides before the worker's tree exists, so it reads those files as
  the commit the tree is cut at holds them (the dispatch's declared base, else HEAD) -- the commit's root listed once,
  and every root folder of it named `.claude` but for letter case, and every file whose name is one of those but for
  letter case read; a folder or a submodule at such a name is no file -- and, where a tree already stands at the
  worktree path and is reused, as they stand there; it reads the mission root's own too, since it places the root's
  ignored `.claude` entries in the tree. A file is read with its NUL bytes dropped, so a UTF-16 file hides nothing.
  Letter case is ASCII's, the case a case-insensitive file system folds onto these names. A committed symbolic link is
  read as the text git stores for it, which is what a checkout writes where `core.symlinks` is false (Git for
  Windows' default); where git checks links out as links, what the CLI reads through one is not examined. A parent folder's
  `CLAUDE.md`, a file a `CLAUDE.md` imports, and your user-level memory and settings are not examined.
- `AUTH-MODE-UNREADABLE` -- the runner's own: the variable is set and `tools\lam\lam-auth-mode.ps1` is not loaded, or
  the commit the worker's tree is cut at names one of those root files or settings, in any letter case, and git cannot
  read it (its object missing), or cannot list that commit's root or a `.claude` folder of it, so the mode cannot be
  held to what the tree will carry. A file the commit does not hold, and a folder or a submodule at one of those
  names, is not read; under `subscription` the memory files and `.mcp.json` are not read at all, so one git cannot read
  refuses nothing there.

A refusal names a variable, an argument by its index or a file by its path and line, and says nothing of what was
started: each path's own last line does (the runner: no verify gate, login probe or worker; the wake starter: nothing
written and no session). A credential variable is read for whether it is set and not empty, nothing more: the
toolchain puts the key in no argument, file or record of its own, and prints, logs, captures or hashes no value.

**Where the key goes, and what key mode does not do.** Every program a spawn path starts inherits the key with the
rest of your shell's environment: the runner's verify gate and the product suite it runs, the probe, the worker, and
the tools and hooks the CLI starts. A product test suite that calls the API whenever `ANTHROPIC_API_KEY` is present
will call it, and bill it, under the verify gate. Key mode sets nothing in a child but what it inherits: no `--bare`
(which would skip the hooks, and the evidence plane with them), no `CLAUDE_CONFIG_DIR`, no
`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` -- the provider's control for keeping the key out of the tools and hooks the CLI
starts; set it to `1` in the same shell if your workers run commands you have not read. The framework's hooks never
read the key. What the toolchain cannot keep out of a record is what a child prints: a worker that printed its
environment would put the key into its stream, which the runner captures, and into the evidence plane, whose
PostToolUse hook captures every tool's output and whose Stop finalizer seals it into the session's manifest; and an
interactive seat's CLI records the key's last 20 characters in its own configuration once you approve it. Run the
acceptance instruments and the Python tests with `VANGUARD_AUTH_MODE` unset: the instruments were measured under the
default, and with the variable set a stub drive whose environment fails its mode is refused (`api-key` with no key
in it, `subscription` beside a credential) while one that passes runs as under the default (the Python tests clear it
for themselves, in `tools\conftest.py`); WP-6's S-1b at a live smoke root would bill its one worker to the key.

---

## 8. Rollback

**Rollback is one file, and that is deliberate** — the procedure in §2 changes only
`.claude/settings.json`, so nothing is destroyed and nothing needs restoring from a copy.

1. **Revert the four path edits** in `<project>/.claude/settings.json` back to
   `tools/framework/hooks/…`, and remove the `UserPromptSubmit` entry if you added it.
2. **Verify by evidence, not by reading the file**: start a session, make one tool call, and confirm
   a session directory appears under the plane the A1 hooks write to, with a manifest.
3. **Re-run the A1 negative suite** (§6b). 14 of 14.
4. **Nothing under `tools/evidence-hooks-next/` needs removing.** It is inert when unregistered.
5. **Do not delete any evidence the next-gen hooks wrote while they were live.** It is the record of
   what happened, including the fact that you tried this. Sessions written by either hook set are
   readable by both; the manifest schema is unchanged at 1.3.0.

**If you took §5's guard addition and are rolling back the registrations, you may keep it.** It is
independent of which hook set is registered, and removing it means moving a sealed hash a second
time for no gain.

**What rollback does NOT undo:** any commit a ceremony made while the next-gen hooks were live, and
any gate artifact. Those are forward-only by design; a rollback of the observation machinery does
not un-observe what it saw.

---

## 9. What this procedure deliberately does not do

- **It does not delete or overwrite any sealed file** in the §2 path. If you choose the merge route
  instead (§1.2), that is a different procedure with its own amendment.
- **It does not install anything into another repository.** The smoke repo registers the next-gen
  hooks in its own `.claude/settings.local.json` and is unaffected by this; it is a repository of its
  own, made beside the project only when the operator runs the builder (§10), never by the install.
- **It does not run the D9 clean-tree patch against the host project.**
  `tools/evidence-hooks-next/patches/clean-tree-exemption.patch` was applied **only in the smoke
  repo** during the build. Applying it here is a separate decision about two live gates, and
  erratum E25 (two sibling gates that disagreed about the same directory for the life of the build)
  is the reason it deserves one.
- **It does not claim the toolchain is validated by being installed.** §6 is what validates the
  install; V-1's six independent validators are what validate the toolchain.

---

## 10. Running the acceptance instruments: the smoke mission and the wrapper

The smoke-mission builder and its sources, and the acceptance wrapper, are installed into a project as they stand in
the framework repository; the builder makes the smoke mission the instruments read, after install. So are
the pinned bases the instruments read, and read from nowhere else -- no git history: `tests\lam\fixtures\base-700e19e5\`
(the libraries the base evaluators dot-source -- the framework's own files at its import commit, or at a later commit
less comment lines naming commits this repository does not hold -- beside the synthetic suite version and goal of
record that stand for the import commit's own state), `tests\lam\fixtures\base-700e19e5-s01\` ...
`base-700e19e5-s13\` (synthetic bases: the earlier version of a framework tool a member holds the tool to, built from
the framework's own file at the import commit by a recipe the framework repository keeps, which
does not ship) and `tests\lam\fixtures\legacy-census-halts\`: a project's reading of the members that hold a tool to an
earlier version of itself reads the same bytes as the framework repository's. They are pinned by the sha256 of their exact
bytes, so the installed `tests\lam\fixtures\.gitattributes` (`* -text`) keeps git from converting their line endings
in a checkout or a clone, whatever `core.autocrlf` says; commit it with them.

**The root `.gitattributes`.** A fresh install into a folder that holds no file a git repository tracks also writes the
framework's own root `.gitattributes` -- `* -text` and the two family lines `.mission/** -text` and
`docs/framework/** -text` -- as a TEMPLATE, never merged with a project's own; an upgrade keeps a project's own. With it
git stores and checks out every file exactly as it is, whatever `core.autocrlf` says: a project's first `git add`
prints no line-ending warning, a checkout or a clone stands at the release's bytes, and framework.lock's `eol` reads
`lf` for every LF file. Without it -- a project that keeps its own, narrows this one, or never received it -- a
`core.autocrlf=true` checkout is CRLF and git warns on add, and the installer does not mind: framework.lock and
`-Verify` judge a text file by the fold (every CR LF made LF, INSTALL.md section 5), so line endings never decide
whether a file is the framework's, and no file is rewritten for them; without the two family lines
`tools\mission-verify.ps1` calls its hashes worktree anchors rather than clone-stable. What it costs: `* -text` turns
conversion off for the project's own files too. A project that wants conversion for them narrows the first line to the
framework's paths and keeps the two family lines; that edited copy reads CHANGED under `-Verify`, as any TEMPLATE a
project edits does.
An upgrade where a project has none, and a first install into a repository with files of its own (the target, or a
repository it lies in, tracking files there -- or git unable to say), write none: a framework install does not change a
project's line-ending policy for the project's own files. The installer prints one `not-written` line naming the file
and why, counts `not-written=1` after `kept=`, and records a `not-written` line in framework.lock, its `sha256` and
`eol` null, which `-Verify` and a run at the same version pass over and a later upgrade reads;
`tools\provenance\upgrade-diff.py` predicts it so. Such a project that wants the framework's rules copies
`.gitattributes` from the release tree and commits it. In an existing repository on a `core.autocrlf=true` host whose
own files git stored LF and checked out CRLF, that stops the conversion for them as well: a file git re-examines then
reads as modified (CRLF on disk against the LF it stored), and what an editor writes is committed as it stands. Narrow
the first line to the framework's paths before you commit, or, with nothing uncommitted, run `git rm -r --cached .` and
then `git reset --hard` once, so the tree stands as stored.

**The synthetic fixtures.** Three groups of them stand in for project files and carry no project's names.
The product instrument WP-2 R-57 and WP-3 C-1k and C-1be run is `tests\lam\instrument-sample-suite.ps1.base` in
`base-700e19e5\`, `base-700e19e5-s11\`, `base-700e19e5-s04\` and `base-700e19e5-s01\`, one version each: a sample product test instrument at
that version with every identifier in its comments, its banner and its mirror line replaced by neutral words and
its code otherwise unchanged, so the versions differ only where the instrument's code changed. Those members read these versions
only, never a live instrument in the tree or a version from history. The goal of record WP-3 C-1ah reads, at its
sha256 and in no live goal's place, is `base-700e19e5\.mission\goals\SAMPLE-GOAL.yaml`; the goal censuses read it as one
of every goal the tree tracks. The legacy HALTs WP-3 C-3d copies, where the primary checkout's plane holds fewer than
two census members, are `legacy-census-halts\HALT-SAMPLE-01.md` and `HALT-SAMPLE-02.md`: in no real census, they are
honoured only by a sandbox double -- the evaluator's own bytes beside a sandbox census file that names them -- and the
member's control row shows the real evaluator, over the real census file, honouring neither. A project upgraded from a release that installed the files these replace
keeps those at their old paths -- an upgrade retires a path the release no longer carries, leaving it in place and
dropping it from the lock -- and may delete them: no member reads them by name, though the goal censuses read a retired
goal file for as long as the project tracks it.

**The acceptance record, in a project.** `docs\framework\LAM-ACCEPT.md` is a project's acceptance record, not a
framework document, and no release after 0.2.0 ships it. Six members measure
the framework against sentences of it -- WP-1 H-12, WP-2 R-16 and R-B, WP-3 C-1v, C-1w and C-2d -- and read it as
0.2.0 carries it, held to its sha256 (after the fold, so a CRLF checkout reads): at its path, where a project 0.2.0
installed keeps it in place (an upgrade retires it, leaving it there), else from this repository's history. A project
the framework installs afresh, or one an upgrade carries from 0.1.x (whose copy is another version of it), holds
neither, and there those six members SKIP by name -- never a pass, never a failure; a project upgraded from 0.2.0 that
keeps the retired file keeps them measuring. No other member reads the record.

**The legacy HALT census, on an upgrade from a release that carried it inside the evaluator** (0.2.0 and every
earlier release). The census that bounds a goal's `legacy_answered_allowlist` (section 5.6.2) is now
`tools\lam\legacy-halt-census.txt`, a HOST-CONFIG file the framework ships empty. An upgrade installs that empty file
where a project has none and replaces the evaluator, whose literal was the census until now: **a project whose goals
allowlist legacy HALTs runs the exporter against its PRE-upgrade evaluator before it runs `install.ps1`, or its legacy
HALTs are honoured no longer** -- each reads OPEN, and its goal HALT, until it is written back or a `halt-ruling` gate
answers it. The exporter is new in this release, so it runs from the expanded release (or a checkout), naming the
project's own evaluator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <the release>\tools\lam\export-legacy-census.ps1 -From C:\work\my-project\tools\lam\mission-goal-check.ps1
```

It parses that file and never runs it, takes its `$script:HaltLegacyCensusText` literal, holds it to the header's
count and census_sha256, and writes `legacy-halt-census.txt` beside it: a header, then each member in ordinal order --
each legacy HALT with its recorded digest. It prints counts and sha256s, never an entry. A second run
writes nothing; a census file with members of its own is refused (exit 2) and left as it is; the empty file the
framework ships is no census of the project's and is written over. Then upgrade as section 6 of INSTALL.md says: the
census is HOST-CONFIG, so the upgrade keeps it byte for byte (its lock row `kept`, its `upstream_sha256` the empty
file's). After the upgrade the project's evaluator is this release's, which carries no literal, and the exporter
refuses it (exit 1): written late, the census comes from the pre-upgrade evaluator recovered from the project's own
history into a scratch file, `-From` naming that file and `-To` the project's `tools\lam\legacy-halt-census.txt`; it
replaces the installed empty one, and `-Verify` then names it CHANGED until the next upgrade keeps it. A fresh install refuses a census already standing in the target that
differs from the empty one (`not-installed-by-framework`, as any HOST-CONFIG file): install first, then write it. A
project with no legacy HALTs -- every project started on this framework -- leaves the file empty.

**The smoke root.** The instruments that reach the smoke mission -- WP-2 (R-35a, R-49), WP-3 (C-2c) and WP-6 --
resolve its root from their `-SmokeRoot` parameter (WP-3 and WP-6); without it, from the environment variable
`LAM_SMOKE_ROOT` (the wrapper's channel, since the shared helper launches every instrument with no argument); without
that, the DEFAULT: `lam-smoke` beside the primary checkout (beside this checkout when git names no other), where the
builder below builds it, so the primary checkout and every linked worktree read the same mission. There is no tracked
fixture. Each instrument prints the root it read and where the value came from, and where nothing stands at the default
it says ABSENT and names the builder. With no smoke mission found and none named, WP-3's C-2c and WP-2's R-35a and
R-49 SKIP by name, and WP-6's members fail against nothing, F-0 first; a root named with `-SmokeRoot` or
`LAM_SMOKE_ROOT` is always measured. A root of files only -- a folder with no `.git` of its own -- has no history, no
origin and no runtime plane: the members that need those SKIP and say why. A built smoke mission is measured whole,
and then WP-6's S-1b spawns one real, billed worker.

**Building the smoke mission.** After install, from the project (or a checkout of the framework repository):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\build-smoke-mission.ps1 [-SmokeRoot <folder>\lam-smoke]
```

builds a LIVE git repository at the root -- by default `lam-smoke` beside the primary checkout; `-SmokeRoot`, else
`LAM_SMOKE_ROOT`, names another -- and its bare origin `lam-smoke-origin.git` beside it, from the plain files under
`tools\lam\smoke-mission\` and five framework files its ceremony runs. It spawns no CLI worker: it performs the run's
residue itself, with the framework's own tools -- the commits (fixed identity and dates, and git kept from the host's
global and system configuration, its global ignore and attributes files and every GIT_* variable but those the builder
sets, so the pushed history has the same ids on every machine for the same framework files), one worktree per dispatch (D-1, D-1b, D-1c, D-2, D-3), its
own checks behind every validator result, the evidence hooks driven with the calls it made (a finalised session per
dispatch, every capture-gaps sidecar empty, and a push the guard denies before any push gate exists), the two
supersession gates and the push gate composed by `tools\lam\mission-gate.ps1 -ComposeOnly` -- the push gate AFTER the
push, bound to the tip the origin then holds, and then revoked; each gate says on its first line that no operator
confirmed it -- the pre-push decider, the close ceremony, and one prompt-register line per worktree plus one
builder-diagnostic line at the root, disclosed in `.mission-runtime\disclosures\builder-diagnostic-prompt.md`. No file
in the work tree or the origin names a host or a host commit; `.git\hooks\pre-push` is the one machine-local path: the
decider wrapper, which names the decider of the checkout the builder ran from by its full path, as the pre-push checker
requires. The mission's README says which records name the builder and which keep a tool's fixed shape, and WP-6's S-4
and ZP say on their face that its push gate is builder-composed (`operator_credential: injected-seam`), no human's. It
refuses, before writing anything, a root or an origin
that already exists (it never overwrites: delete both folders to rebuild), a root that lands inside a `.mission` or
`.mission-runtime` folder or inside a git work tree -- judged where it really lands, short names expanded and junctions
followed, folders still to be made included -- a path segment ending in a dot or a space, and a git older than 2.48;
every date it writes is in the invariant culture, whatever the host's regional format; it prints each step, the commit
ids it made and `EXIT: 0`. Nothing about the smoke mission is recorded by the install, and nothing in a project
refers to it but the instruments' default.

**What a built mission runs.** Every WP-6 member measures it -- F-0, F-1, S-1, S-1b (one billed worker), S-2, S-3,
S-4c, S-4d, S-4b, S-4, S-5 and ZP -- and WP-2's R-35a and R-49 read its five handoffs and its dispatch directory.
WP-3's C-2c reads its `.claude\settings.local.json` beside the `.claude\settings.local.json` of the checkout it runs from
-- or, where that checkout has none, the primary checkout's, as from a linked worktree, which has no `.claude\` of its
own -- and SKIPS while neither has one. A Claude session started in the smoke mission runs only the hooks whose scripts
it finds under its project folder: the builder copies in the files its ceremony and clean-tree gates run
(`tools\mission-lib.ps1`, `tools\mission-spec-accept.ps1`, `tools\lam\lam-verify-admission.ps1`,
`tools\lam\lam-gate-class.ps1`) and the evidence schema, not the hook scripts, which it drives from the project it runs
from.

**The acceptance run.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\instrument-acceptance.ps1 -RunKey <key> [-Root <checkout>] [-SmokeRoot <root>]
```

runs WP-1..6 in order through `tools\lam\lam-instrument-run.ps1` and writes each capture to
`<Root>\.mission-runtime\lam\instrument-runs\<key>.instrument-WP-<n>.stdout.txt` and `.tally.txt`.
`-Root` defaults to the checkout the script sits in, so in a linked worktree run the worktree's own copy;
`-SmokeRoot` is handed to the instruments as `LAM_SMOKE_ROOT`; without it the variable is cleared for the run and each instrument reads its default, the smoke mission beside the primary checkout. It prints `RUNKEY`, `ROOT`, `HEAD`,
`BRANCH`, `PORCELAIN`, `PATH-DERIVATION`, `STARTED`, one block per instrument with its exit code and
seconds, `ENDED`, `HEAD-AFTER`, `PORCELAIN-AFTER`, `CAPTURES` -- every capture written since `STARTED`,
with its size and sha256 -- and `SUMMARY`. A run key that already names a capture is refused (exit 9): a
reading is never overwritten. A whole run takes about an hour.

**At a worktree.** A reading taken in a linked worktree equals the primary checkout's, or names the
dependence as a SKIP whose reason says where it stood. To compare the two, build the smoke mission once,
cut the worktree in the dispatcher's own place (`<parent>\<repo>-worktrees\<tree>`), run the wrapper at
the primary checkout and the worktree's copy in the worktree -- both read the default beside the primary checkout, or
pass both the same `-SmokeRoot` -- and compare the two `CHECKS` lines of every tally field by field.

**The prune-worktrees test, kept per host.** `tools\tests\cli\test_prune_worktrees.py` is installed as HOST-CONFIG:
a fresh install writes it, and an upgrade keeps the project's copy whatever it holds. It stays so because six of its
items read a project's own runtime records, each pinned by sha256, on the primary checkout's runtime plane -- four
prune listings under `.mission-runtime\lam\close\` and two scratch-copy trees under
`.mission-runtime\scratch-copies\` -- and compare them with the session data the test carries. Where
those files are absent the six SKIP by name; where a listing stands at its path with other bytes, the items that
reach it FAIL (the two that also need a scratch-copy tree skip while that tree is absent); outside a git work tree
all six FAIL. Its A-B item reads its base tool from the installed fixture
`tests\lam\fixtures\base-700e19e5-s11\tools\lam\prune-worktrees.ps1.base`, and from nowhere else; the other items build their own trees under pytest's temporary folder. What a project does: on a
fresh install, nothing -- the six named skips are expected; write nothing at those plane paths; and where an upgrade
from 0.1.x kept the 0.1.x copy, whose A-B item reads a base commit from git and fails without it, replace the file
with the release's and commit it.

---

## 11. A seat that commits in a host project

A prompt that seats a session to commit in a host project carries this line among its rules:

> Every commit this seat makes in the host's primary checkout is appended to the host's commit ledger through the primary checkout's tracked composer, in the same prompt or block that creates it -- `python -I <mission root>\tools\lam\commit_ledger.py append --sha <the commit> --line-file <a file holding by, attested_by and note> --ledger <mission root>\.mission-runtime\lam\commit-ledger.jsonl` -- because the push admission refuses a commit absent from it. A commit this seat makes in a worktree is not appended by the seat: the ledger is the primary checkout's and its lines are composed there, and the primary's composer refuses a commit that is not in the history of its HEAD, main -- so that commit's line is written in the act that makes it an ancestor of main, the merge block.

The operator's merge block carries this line:

> The block appends to the host's commit ledger, through the primary checkout's composer and in the same block that merges, the line of each worktree commit the merge brings into main and then the merge commit's (a fast-forward makes none) -- one `append` per commit, since `append` takes a single `--sha`; a commit whose line already stands is refused as a duplicate, and its line is there -- because the push admission refuses a commit absent from it.

A prompt that seats a session in a linked worktree carries this line too:

> This seat writes nothing into a mission plane: the guard's seat tripwire refuses a linked worktree's file-tool and classified-verb writes under `.mission/**` and `.mission-runtime/lam/**` (section 2). Its handoff goes to its scratchpad, and the record is that file's path and its sha256.
