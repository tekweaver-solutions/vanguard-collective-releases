# Evidence Write-Path Threat Notes

> **Artifact:** A1, under its amendment (operator-ratified; the ratification is recorded in the
> ledger, not in the amendment file — see §8 on where an amendment's status lives).
> **Revision:** guard descope + trail cure. Three fresh-identity validators
> returned **REFUTED** on three successive builds (B1–B4, then B5–B7, then BF1–BF3), each on a
> *different* bypass of the same component. This revision accepts what that establishes: **layer (c)
> inspects a command string, and the shell does not agree with it.** The guard is re-scoped
> from boundary to **accident tripwire**, its Catches list is derived from the test rather than
> authored, and the capture-trail defect is fixed. §7 records what each refutation changed;
> §7.1 records the pattern they share, which is more useful than any one finding.
>
> **Read this document with that scope in mind.** Where any sentence about the guard could be
> read as a guarantee against an adversary, the sentence is wrong — not the reader.
> **Design authority:** `docs/framework/vanguard-collective-local-modes-v2.1.md` §4.1
> (write-path enforcement), §4.4, §6.
> **Citation convention:** `LM2-ADR-0NN` denotes a decision in the local-modes
> v2.1 design document. A bare `ADR-0NN` denotes the on-disk file under
> `tools/mission-cli/config/`. The two namespaces collide numerically — the v2.1 document
> mints IDs that are already occupied on disk — and are **not** related.
> **Measurement discipline:** every empirical claim below is labelled **measured** or
> **not measured**. Nothing is labelled by inference.

---

## 1. What the design requires

§4.1 states the enforcement requirement plainly, and states the failure mode if it is not met:

> Three layers: (a) the evidence directory is excluded from the session sandbox's writable
> mounts — the worker's filesystem view cannot reach it; (b) hooks execute harness-side,
> outside the sandbox, and hold the only write path; (c) PreToolUse deny rules on evidence
> paths as defense-in-depth for topologies where mount exclusion is unavailable.

> An evidence store the agent can write is worse than none — it launders testimony as evidence.

That last sentence is the standard this document is measured against. The question is not
"did we install hooks" but "can the agent reach the pen".

---

## 2. Host facts

Environment: Windows 11 Pro 10.0.26200, Docker Desktop 29.5.2, Linux containers,
context `desktop-linux`.

### 2.1 Bind mounts are 9p/drvfs, and `:ro` is honoured — **measured**

```
$ docker run --rm -v "<scratch>:/probe:ro" alpine:3 sh -c '...'
write_exit=1
touch: /probe/PRIV_WROTE: Read-only file system
C:\134 /probe 9p ro,noatime,aname=drvfs;path=C:\;uid=0;gid=0;metadata;
symlinkroot=/mnt/host/,cache=5,access=client,msize=65536,trans=fd,rfd=5,wfd=5 0 0
```

A read-only bind is real. The write was refused with `EROFS`, not silently dropped.

### 2.2 The mount cannot be remounted read-write from a default container — **measured**

```
$ ... mount -o remount,rw /probe
remount_exit=1
mount: permission denied (are you root?)
CapEff:	00000000a80425fb
```

`CapEff = 0xa80425fb` has bit 21 (`CAP_SYS_ADMIN`, `0x200000`) clear. The container runs as
uid 0 and still cannot remount.

**`--privileged` defeats it — measured.** The first revision of this document asserted this
without measuring it, which violated the discipline the document itself sets. Measured now:

```
$ docker run --rm --privileged -v "<scratch>:/probe:ro" alpine:3 sh -c '...'
CapEff:	000001ffffffffff
remount_exit=0
write_exit=0
$ (host side)  PRIV_WROTE   <-- the file appeared on the host
```

A `--privileged` container regains `CAP_SYS_ADMIN`, remounts the `:ro` bind read-write, and
writes through to the host. **A sandbox profile that allows `--privileged` has no layer (a).**

### 2.3 POSIX permissions carry no information on this host — **measured**

```
$ ls -ldn /repo/.mission/evidence
drwxrwxrwx    1 0        0             4096 Aug  6 13:31 /repo/.mission/evidence
```

The 9p mount is created with `uid=0;gid=0`, so every path presents as `root:root 0777`
regardless of what Windows thinks. **Any enforcement that leans on ownership or mode bits is
decorative here.** `chmod`/`chown` inside the container do not produce a durable boundary.

### 2.4 The `:ro`-subpath-over-`rw`-parent layering — **not measured**

Mounting the repo writable at `/repo` and the evidence directory read-only over it was **not**
tested. Testing it honestly requires attempting a write that, if the layer failed, would land
in the repository. It is the first empirical act of any session that intends to rely on
layer (a).

Recording a non-measurement as a non-measurement is the point of this document.

---

## 3. What is actually achievable here

| Layer | §4.1 intent | Status on this host |
|---|---|---|
| **(a)** mount exclusion | Worker's filesystem view cannot reach evidence | **UNAVAILABLE for native sessions.** Available in principle for containerized workers (§2.1–2.2), untested for the subpath case (§2.4), **void under `--privileged` (measured, §2.2)** |
| **(b)** harness-side hooks hold the only pen | Hook process writes; model does not | **HOLDS**, given the hooks are installed and firing. Hook processes are spawned by the harness, not by the model |
| **(c)** PreToolUse deny rules | Defense-in-depth | **HOLDS as a policy check, carries nearly the whole load, and is a heuristic — not a boundary** |

### 3.1 The load-bearing gap — erratum E1

**Layer (a) does not exist for the topology this repository actually runs**, and not because
Windows is weak. It is because **L0/L1 sessions run natively on Windows with no container at
all.** There is no mount namespace, no bind, and therefore no boundary to exclude anything
from. The design's §4.1 assumes a sandboxed session; the delegation ladder's own L0/L1 rungs
(§9.5) describe a human pasting dispatches into a session that is not sandboxed.

Consequence, stated without softening:

- Against a **non-adversarial** agent — the failure mode this framework is designed for,
  where a model fabricates under completion pressure rather than schemes —
  layers (b) and (c) close the vector. The agent has no ordinary path to the log, and the
  captured `git rev-parse` contradicts the fabricated one. This is the case the framework was
  built for, and A1 addresses it.
- Against an **adversarial** agent, layer (c) is a policy check running in the same process
  tree as the actor, gated on inspection of tool inputs. It raises cost. It does not make the
  path unreachable. §4.1's phrase "machinery the agent *cannot* edit" is **achieved** for
  containerized workers and **approximated** for native sessions.

Calling that approximation an achievement is exactly the laundering §4.1 warns about, so it is
written down here instead.

Registered as design-doc **erratum E1**; cured in design v2.2 by the thinking-partner
session after A1 lands. This session does not edit the design doc.

### 3.2 What layer (c) catches and misses

`evidence-guard-pretooluse.ps1` delegates to `Get-EvidenceGuardDecision`, which uses **two
path tiers** plus a metacharacter gate. Matching is done on a **canonicalized** form: separators
normalised, `//` collapsed, `/./` removed, `..` resolved per path-shaped token, and hits
required to end at a path boundary.

Verb classification is gone from the allow side **except for the one disclosed exemption**
(§3.2.2). Two classes survive:

- `destructive` — **deny-side only.** Being wrong about it costs a false refusal, never a false
  permit.
- `staging` — gates the single Bash allow-side exemption (the §4.1 ceremony), constrained to
  targets under `.mission/evidence`. So "no allow depends on a Bash verb" would be false; **"the
  only allow that depends on a Bash verb is the one disclosed exemption"** is what holds.

The "sole exemption" claim is scoped to **Bash**. The file-tool read path (`Read`/`Grep`/`Glob`)
is a second structural allow, described in §3.2.2 — it exists because those tools cannot write,
not because of anything the guard reasoned about.

```
PROTECTED (writes denied when the      PARENT (destructive/relocating operations only)
guard can see them -- see below)
  .mission-runtime/evidence              .mission-runtime
  .mission/evidence                      .mission
  tools/framework/hooks                  tools/framework
  tools/framework/install-…ps1           .claude
  tools/framework/tests
  .claude/settings.json
```

> **The guard is an ACCIDENT TRIPWIRE, not a boundary.** Everything in this section
> raises the cost of an *accidental* write. None of it is a boundary against an agent that
> wants in. The earlier revision of this table said "PROTECTED (no write, ever)"; that was
> false, and a validator proved it false with `printf "forged" > <protected path>`. Read every
> sentence below with that framing — where a claim could be read as a guarantee against an
> adversary, the claim is wrong, not the reader.

**Why two tiers.** A blanket ban on `.mission` would deny `git add .mission/ledger/entries.jsonl`
and amendment placement — ordinary mission ceremony that is not evidence at all. A guard that
blocks the workflow it protects gets switched off, which is a security failure with extra
steps. So the parents are guarded against `rm -rf .mission`, not against writing inside them.

### 3.2.1 Catches — DERIVED, not authored

A standing rule governs this list, quoted verbatim: *"Itemizations are derived by grepping
for the evolving clause across the tree, never by enumerating known sites from memory."*

Twice a hand-authored version of this list claimed a category the test did not run — once as
finding B7, then again as BF2, inside the very list whose header promised it could not happen.
Hand-authored completeness claims fail structurally, so this list is no longer authored. It
**mirrors the deny-case names in `tools/framework/tests/test-a1-negative.ps1`**, and check
**N10 enforces set equality in both directions**: a documented catch with no test case fails
the suite, and a test case missing from this list fails the suite. Overclaim here is no longer
something a careful writer avoids — it is something the test refuses to let exist.

Do not hand-edit between the markers.

<!-- N2-DENY-CASES:BEGIN (mirrored from tools/framework/tests/test-a1-negative.ps1; enforced by check N10) -->
- TALLY deny-cases: 51
- TALLY allow-cases: 13
- TALLY checks: 14
- `rm -rf .mission-runtime`
- `rm -rf .mission`
- `rm -rf .mission-runtime/ev*`
- `mv .mission-runtime away`
- `Remove-Item -Recurse`
- `git clean -xfd`
- `rm -rf tools/framework`
- `rm -rf .claude`
- `rm -f .claude/settings*`
- `git add a hook script`
- `git add the test`
- `git commit a hook script`
- `readonly THEN destructive`
- `readonly THEN evidence wr`
- `git checkout evidence`
- `plain evidence path`
- `dot segment  /./`
- `double separator  //`
- `parent hop  zz/..`
- `dot segment in .mission`
- `backslash spelling`
- `bash cd then write`
- `edit the PostToolUse hook`
- `edit the guard itself`
- `edit the shared library`
- `uninstall hooks (write)`
- `uninstall hooks (rm)`
- `redirect into evidence`
- `truncate via cat /dev/null`
- `append into evidence`
- `redirect into committed`
- `overwrite a hook script`
- `redirect into settings`
- `backgrounded destruction`
- `command substitution`
- `backtick substitution`
- `sort -o into evidence`
- `bash cat a manifest`
- `bash head an evidence log`
- `bash ls the hooks dir`
- `bash git log on evidence`
- `bash git diff on evidence`
- `bash git show evidence`
- `git blame --output`
- `git diff --output`
- `git log --output`
- `git show --output`
- `git shortlog --output`
- `tool_input is a string`
- `unparsable payload`
- `empty payload`
<!-- N2-DENY-CASES:END -->

Each name is one driven case in N2 with its exact payload in the test. The `TALLY` lines are
mirrored the same way and enforced the same way.

**The rule, scoped:** *every count describing the CURRENT artifact is emitted by the test or
does not appear.* §7 is historical narrative about superseded builds — counts there are quoted
or recounted history, they cannot drift because the builds they describe are frozen, and they
are **outside the enforcement**. The rule is stated with its scope because an unscoped absolute
was falsified by counts in the very paragraph asserting it.

A stale hand-typed count went undetected three times running — *quoted history:* `ALL 5` while
six checks ran; `30 deny / 13 allow` while the real figures were larger; `Six checks:` while ten
ran. So counts describing the current artifact are no longer hand-typed.

The redirection and substitution cases exist because an earlier build of the guard **allowed** them: a
read-only-verb exemption returned before any path matching, so
`printf "forged" > .mission-runtime/evidence/d/log.jsonl` was never checked at all. The descope
removed that exemption and put a metacharacter gate ahead of everything.

### 3.2.2 How to read evidence, and the one exemption that survives

**Read evidence with the Read tool. Bash gets no benefit of the doubt.**

`Read`, `Grep` and `Glob` on an evidence path **allow** — they are matched by path field and
they cannot write, structurally, so they need no reasoning about what they might do. A Bash
command naming protected territory **denies, reads included**:
`cat .mission/evidence/d/manifest.json` is a deny case.

That is a real cost and it is deliberate. There used to be a read-only verb list here, admitting
Bash commands that "only read", maintained against the criterion *a verb qualifies only if it
cannot modify the filesystem without a metacharacter*. It was audited twice and was wrong both
times — `sort -o`, then `file -C -m`, then `git blame --output=<path>`, which **truncated an
evidence log while the guard reported "plain read"**. The list is deleted rather than corrected:
maintaining a whitelist of "things that only read" against every flag of every tool on the host
is not a task anyone finishes. A guard that classifies commands by verb will eventually classify
one wrong; a guard that does not classify cannot.

**THE SOLE SURVIVING ALLOW-SIDE EXEMPTION** — one member, and nothing joins it without an
amendment:

- **The §4.1 ceremony.** `git add` / `git commit` whose protected targets are all under
  `.mission/evidence/**` — the design's own workflow: *"copies … into
  `.mission/evidence/<dispatch_id>/` for commit at the next ceremony boundary."*
  Evaluated after the metacharacter gate. Deny-side twins: `git add a hook script`,
  `git add the test`, `git commit a hook script`.
  **Its residual, named rather than argued away:** a staging command can manipulate the git
  index in ways this check does not model. That residual is caught one layer up, by the
  committed-plane hash chain — what is committed is hashed, and a manifest whose `log_sha256`
  does not re-derive reads `TAMPERED`.

Not an exemption, but worth stating: file tools are matched on **path fields only**, never on
`content`, so a document may discuss evidence paths — this one does. Deny-side twin: every
`Write`/`Edit` case whose *path* is protected.

### 3.2.3 Misses — stated as CLASSES

Instances are examples, never a population. Each class below is unmitigated:

- **Indirection class.** Any path the guard does not see as text: assembled from variables,
  encoded, quoted or globbed into shape, or reached through a helper script written earlier and
  merely executed now.
- **Working-directory class.** State carried between tool calls. `cd .mission-runtime` in one
  call and `cd evidence/x` in the next names nothing protected in either, and the Bash working
  directory persists. Both calls are plain literal text; this is not obfuscation and it is not
  caught.
- **Destruction-mechanism class.** Any destructive mechanism not on the verb list —
  `find -delete`, `find -exec rm`, `xargs rm`, `robocopy /MIR`, `python -c shutil.rmtree`,
  `[System.IO.Directory]::Delete`, an ancestor-relative `cd .. && rm -rf <repo>`. The verb list
  is a list; destruction is not.
- **Bulk-staging class.** `git add .`, `git add -A`, `git add --all`, `git add tools`,
  `git commit -a`, `git commit -am` reach machinery; only explicit paths deny. See §3.2.4.
- **Out-of-matcher class.** Any tool the settings fragment's matcher does not cover, and any
  process the session spawns.
- **Unprotected-by-decision class.** `.claude/settings.local.json` can carry hook configuration
  and is deliberately not protected — it is the harness's own permission-approval file, and
  denying writes to it would break the operator's approval flow (R9).
  `docs/framework/evidence-manifest.schema.json` and this file are also unprotected: they are
  documents, not capture machinery, so editing them changes what is *claimed*, not what is
  *recorded*. The installer and the test tree **are** protected — the installer writes
  `settings.json`, and the test defines what "verified" means.

### 3.2.4 Machinery commits are operator-mediated — by design

The guard denies `git add tools/framework/hooks/…` with an explicit path. That is **intended
behaviour, not a false positive**: Principle 11 puts integrity where the agent cannot reach, and
a session that could edit the capture machinery and seal that change into history would hold the
pen on its own evidence one level up. Modifying the evidence machinery is an **operator act** —
performed outside the session, or with hooks deliberately uninstalled for the duration.

**Disclosed limit:** bulk staging (`git add .`, `-A`, `git commit -a`) reaches machinery anyway.
The property is not enforced; the deny covers the explicit spelling only.

Registered for A2 / design v2.2: define the operator pathway for post-install
framework-maintenance commits, so this is a named procedure rather than an obstacle people route
around. Until that exists, the pathway is the operator's own hands.

### 3.3 Self-protection is still layer (c) — say it plainly

Adding the machinery to the protected set (cure B4) closes the ordinary case. It does **not**
make the machinery unreachable, and it must not be read that way.

The protection is **circular by construction: the guard is what protects the guard.** If the
guard does not fire — a tool outside the matcher, hooks removed from settings, a path built
from variables, a helper script executed rather than written — then nothing downstream
applies, because everything downstream depends on the same component. **An agent that reaches
the guard by any route the guard does not catch defeats the guard, and with it every
protection listed here.** There is no second lock behind this one on a native session.

The cure raises cost. It is not a boundary. Only layers (a)/(b) make the path unreachable, and
§3.1 explains why (a) is absent for the sessions this repository actually runs.

This paragraph exists because the previous revision claimed layer (c) "catches" spellings it
demonstrably allowed, and omitted the machinery vector entirely. The correction is not an
occasion to overclaim in the other direction.

---

## 4. Residual risks, named

| # | Risk | Mitigated? |
|---|---|---|
| R1 | Native session, adversarial agent, path built dynamically → guard bypassed, log editable | **No.** Requires layer (a): run the session containerized with evidence excluded |
| R2 | `--privileged` container → `CAP_SYS_ADMIN` → remount rw → host write | **No** (measured, §2.2). Sandbox policy must forbid `--privileged` |
| R3 | Evidence edited after finalization | **Detected, not prevented.** `log.jsonl` → `log_sha256` re-hash yields `TAMPERED`. Stream bodies → `Test-EvidenceStreamIntegrity` re-derives each `stdout_sha256`/`stderr_sha256` from the committed body. **Residual:** nothing in A1 runs the stream check automatically; `Get-EvidenceState` is a header check only, so a mutated stream body with an untouched log still reads `FINALIZED` from state alone until A3's `mission verify` wires the check into the dispatch gate |
| R4 | Session dies before Stop | **Handled** — derives to `PARTIAL`; consumption blocked, forensics intact |
| R5 | Hook errors, or a hook that silently stops firing → evidence gap reads as "clean run" | **Partially, and rescoped.** A hook that *errors* is now visible three ways: the error goes to the per-dispatch `hook-errors.log`, `Get-EvidenceState` points readers at it, and the manifest carries `hook_errors_present` + `hook_errors_sha256` and the log is committed. A hook **never installed** remains undetectable from inside; install-time wiring verification is the only control. The manifest still does **not** carry `seq`, so gap-detection lives in `log.jsonl`, not in the artifact reports cite — registered for A2 |
| R11 | Runtime evidence destroyed wholesale before it is committed | **Raised in cost, not prevented.** See §4.1 |
| R6 | Manifest hash stable in worktree, changes on fresh clone | **Detected, not fixed** — see §5 |
| R7 | Guard denies a legitimate harness write, blocking the runner | **Accepted.** The runner writes evidence from outside the session, where the guard does not run |
| R8 | Agent edits the hook scripts or the shared library | **Ordinary case denied** (cure B4). Not a boundary — see §3.3. Editing the PostToolUse hook is *worse* than editing the log: the log keeps being written, looks structurally perfect, and is under the agent's control |
| R9 | Agent disables capture via `.claude/settings.local.json` | **No.** Deliberately unprotected (§3.2). Known, accepted, unmitigated |
| R10 | Guard never fires — tool outside the matcher, hooks uninstalled before the attempt, or the session running without the fragment installed | **No.** This is the parent case of R1/R8/R9 and is the reason §3.3 exists |

### 4.1 The trust boundary is the ceremony commit

A validator proved this end to end: with the pre-cure guard, `rm -rf .mission-runtime` was
allowed, the runtime record was erased, the dispatch was re-populated with sanitised output,
and `Stop` produced a **clean, consumable, self-consistent manifest whose `log_sha256`
matched** — with no marker anywhere that anything had been removed.

The cure denies the demonstrated spellings, and that is worth having. It does not change the
underlying fact, which must be stated plainly rather than papered over by the deny list:

> **The evidence plane's trust boundary is the CEREMONY COMMIT.** Pre-commit runtime evidence
> is *provisional* and is destroyable from inside the session with no marker left behind.
> Nothing in layer (c) can make that untrue: the guard inspects tool inputs, and destruction
> has more spellings than any inspection list will hold. Post-commit evidence is git-protected
> — it lives in an object store with a hash chain, and destroying it means rewriting history.
> Detection of *that* belongs to the git, origin, and operator layers, not to this hook.

Two consequences follow, and they are the operational point of the whole section:

1. **Commit evidence at the earliest ceremony boundary, not the most convenient one.** Every
   minute a dispatch's evidence sits only in `.mission-runtime/` is a minute it is provisional.
2. **A dispatch whose evidence was never committed is not evidence.** It is a runtime artifact
   that happens to still be on disk, and a consumer should treat it as such.

---

## 5. Erratum E4 — hashes are worktree-stable, not clone-stable

**Measured** (this section previously carried these unlabelled, contrary to the document's own
rule): `git config --get core.autocrlf` → `true`. The root `.gitattributes` measured covered
binary types and product fixture trees only
— **not** `.mission/**` and **not** `docs/framework/**`; `git check-attr -a`
returns nothing for the A1 paths. Every A1 file is CR-free in the worktree.

**Not measured:** that a fresh clone actually smudges these particular files. The inference
follows from autocrlf semantics and the absence of a covering attribute, but no clone was made.

Consequence: an LF-authored artifact is byte-stable in *this* working tree, but a fresh clone
smudges LF → CRLF on checkout and **its sha256 changes**. Every hash of a file on disk — in
this document, in reports, in `log_sha256` — is therefore a **worktree-bytes anchor**, not a
clone-stable one.

Two observations for the cure, which is **not** A1's to make:

1. Anchors computed over *content the hook produced in-process* (`stdout_sha256`,
   `stderr_sha256`, `transcript_sha256`) are unaffected — they hash bytes that never
   round-tripped through git.
2. Anchors computed over *files on disk* (`log_sha256`, artifact hashes in reports) are
   affected.

The `.gitattributes` fix (`-text` on the evidence tree, or a canonical-form rule) is deferred
to design v2.2 adoption. Root `.gitattributes` is outside this session's write surface
and is **not** touched.

---

## 6. What A1 proves, and what it does not

**Proves** — by the negative test at `tools/framework/tests/test-a1-negative.ps1`, run against
real files on disk. Case and check counts live in §3.2.1's `TALLY` lines, mirrored from the test
and enforced by N10; they are not repeated here, because a count repeated in prose is a count
that goes stale.

- **N9** an error raised *after* manifest computation still surfaces as
  `hook_errors_present=true` and in the state reason (BF3).
- **N10** §3.2.1's Catches list and tallies are exactly the N2 population, enforced in both
  directions — a documented catch with no case fails the suite, a case missing from the document
  fails the suite, and a stale count fails the suite (BF2/B7, and the stale-count class).
- **N11** a first-hook error is visible even when nothing else was captured: `ABSENT` state with
  no log and no manifest still names `hook-errors.log` (F3).

Including:

1. **N1** A deliberately false sha in prose is contradicted by the hook-captured log.
2. **N2** evidence paths in several spellings, destructive and
   relocating commands naming a parent, repo-wide destruction naming nothing, machinery edits,
   hook uninstall, git staging of machinery, read-only-then-destructive compounds,
   string-shaped `tool_input`, unreadable payloads, and Bash reads of evidence — while allowing the file-tool read path (Read/Grep/Glob), the §4.1
   evidence ceremony (`git add`/`git commit` under `.mission/evidence`), ledger appends,
   amendment placement, and documents whose *content* names evidence paths.
3. **N3** A session that ends without Stop derives to `PARTIAL`, and its log stays readable.
4. **N4** Finalization refuses to run twice.
5. **N5** A log mutated after finalization derives to `TAMPERED`.
6. **N6** `PostToolUse → PreCompact → Stop` reaches `FINALIZED` with a two-variant manifest,
   stream and transcript bodies committed, and every committed stream body re-deriving to its
   recorded hash.
7. **N7** Several PostToolUse events in **one** dispatch all reach the manifest with their content
   intact — `entry_count` equals the number fired, every command present, every stream body re-deriving.
8. **N8** A hook error reaches the per-dispatch log, the state machine's reason string, the
   manifest (`hook_errors_present`, `hook_errors_sha256`), and the committed plane.

**Does not prove** — and no amount of this session's testimony would:

- **That the harness invokes these hooks with the payload shape assumed.** The scripts are
  driven with synthesized payloads. Wiring is verified at install, which is a separate
  operator-gated act. Until then the fragment's `wiring_status` reads `UNVERIFIED`.
- That layer (a) works for the subpath case (§2.4).
- That layer (b) holds under a real harness — that hook processes genuinely execute outside
  any sandbox the model can reach.
- **That the guard stops an adversary. It does not, and this revision stopped claiming it might.**
  Three validators found three different ways through. The classes in §3.2.3 are unmitigated,
  and a fourth class almost certainly exists that nobody has named yet. Integrity rests on
  harness-side capture (layer b), the ceremony-commit trust line (§4.1), and the
  git/origin/operator layers above it — not here.
- N1 synthesizes the tool response from a real `git rev-parse HEAD`, so it proves faithful
  persistence and prose contradiction — not live command capture.

---

## 7. What the refutation changed

The first build of A1 passed its own five checks and was **REFUTED** by a fresh-identity
validator. Recorded because the pattern is the point:

- **B1** — a `PreCompact` entry has no `stdout_sha256`; the finalizer read that property
  directly under `StrictMode`, threw, and the outer `catch` swallowed it. Every session that
  compacted was permanently stuck `PARTIAL`. The five checks passed **because the test never
  fired PreCompact.** A test that exercises only the paths the author thought about will
  confirm only the author's thinking.
- **B2** — the schema forbade a record shape its own field descriptions promised.
- **B3** — this document claimed layer (c) "catches" literal path spellings that a validator
  demonstrated writing straight through it.
- **B4** — the machinery was entirely unprotected, and the gap was not disclosed. Found by
  probing, not by reading.

Cures were taken for all four, plus seven non-blocking findings. One further defect surfaced
during the cure and is fixed: PS 5.1's `ConvertFrom-Json` returns `$null` for whitespace-only
input **without throwing**, so an empty payload fell past both the `_empty` and `_unparsable`
branches and the guard allowed it — the exact silent permission the docstring promised could
not happen.

Three findings were **registered, not built**: the `seq` allocation race, the manifest dropping
`seq`, and the absence of a schema for `log.jsonl`. They are schema-shape decisions for A2's
deltas.

### 7.1 What the SECOND refutation changed

The cured build passed its own suite and was **REFUTED again**. Recorded in full, because
the pattern repeated exactly:

- **B5** — `(… | Where-Object …).Count` throws under `StrictMode` when the pipeline yields one
  object. So after the first captured tool call, every subsequent one threw, was swallowed, and
  vanished — and the dispatch finalized as `FINALIZED`/`consumable` with `entry_count = 1`.
  **Missing evidence presented as complete evidence**, which is the exact failure this artifact
  exists to prevent. Both prior test generations passed while it was live, because no dispatch
  in either fired **two** PostToolUse events. The sibling call sites already had the `@()` fix;
  this one did not.
- The B5 trail was invisible for **three independent reasons** — a global error log nothing
  read, a state machine reading a different path, and a finalizer committing neither. All three
  are closed (N8).
- **B6** — parent-directory destruction was unguarded and produced a laundered clean manifest.
- **B7** — the Catches list claimed a category (`uninstall by rm`) while demonstrating one
  spelling.

Twice now the defect has been *the path the test did not walk*, not the path it walked wrongly.
A green run is evidence about the cases in the run and nothing else. The honest conclusion is
not "the test is now sufficient" — it is that this artifact's assurance comes from adversarial
re-derivation by someone who did not write it, and that this remains true after every cure.

### 7.2 The THIRD refutation, and why it ended the cure loop

The cured-twice build passed its suite again and was **REFUTED again**:

- **BF1** — the read-only-verb exemption (itself the second build's cure for NB-5) returned *before*
  any path matching, so `printf "forged" > .mission-runtime/evidence/d/log.jsonl` was never
  checked. A validator erased a three-entry log with an allowed command and produced a clean,
  consumable, self-consistent manifest. `sort -o <path>`, `cat … & rm -rf …`, `cat $(rm -rf …)`
  and backtick substitution all did the same.
- **BF2** — the Catches list claimed a repo-wide-destruction *category* while N2 ran one case.
  The same defect as B7, in the same list, under a header that promised it could not happen.
- **BF3** — `hook_errors_present=false` on a dispatch that *did* error: the flag was computed
  before the fallible copy, and the state machine carried its hint only in the PARTIAL branches.

Three refutations, three *different* bypasses, one component. That is not bad luck; it is the
approach. **Matching shell semantics correctly — redirection, substitution, backgrounding,
quoting, globbing, interpreters, .NET calls — is implementing a shell**, and a reimplemented
shell inside a PreToolUse hook is a larger attack surface than the one it guards.

So this revision stopped curing and changed the claim. The guard keeps what it can do — stop the
accident, which is the failure mode the framework targets, where models
fabricate under completion pressure rather than scheme — and claims nothing more. Two
structural changes make the claim hard to inflate again: the metacharacter gate refuses rather
than reasons, and §3.2.1 is enforced against the test by check N10.

An artifact that overclaims its own protection commits the error it was built to prevent, one
level up. That is the whole reason this section exists.

Four further findings were **registered, not built** under C2: NB-1 (a fieldless valid-JSON log
line yields a schema-invalid manifest that still reads consumable), NB-2 (stream-integrity
ordering false-positives on an honest capture failure — a one-line fix deferred to A3 wiring
time), NB-6 (a JSON scalar payload is allowed; adjacent shapes deny via the outer catch rather
than the declared branches), and NB-8 (N2's category breakdown was hardcoded prose; the
breakdown has since been removed rather than left to drift).

---

## 8. Where an amendment's status lives

An amendment's file can carry `status: proposed` after the operator has ratified it. That is not a
stale record: **amendment files are immutable once placed, and status transitions live in the
ledger.** A ratification is recorded in
`.mission/ledger/entries.jsonl` under
a decision entry of its own, naming the sha256 of the amendment it ratifies.

A reader who wants an amendment's current status reads the ledger, not the amendment's
`status` field. Recorded here so the field misleads no one.

---

## 9. Recommendation

Adopt A1 as the mechanism, and treat the native-session gap as the open item it is:

1. Install the hooks (operator-gated) and verify wiring — the one thing A1 cannot self-certify.
2. Prefer containerized workers with the evidence directory excluded for any
   **mutation-bearing** dispatch; native sessions remain acceptable for read-only work, which
   cannot mutate the evidence it is judged by (the read-only/mutation asymmetry is
   load-bearing).
3. Forbid `--privileged` in the sandbox profile — measured, §2.2.
4. Wire `Test-EvidenceStreamIntegrity` into A3's `mission verify` so R3's residual closes —
   fixing NB-2's ordering first, so an honest capture failure does not read as tampering.
5. **Commit evidence at the earliest ceremony boundary.** Pre-commit evidence is provisional
   (§4.1); the ceremony commit is the trust boundary, and shortening the provisional window is
   the single highest-leverage operational control available.
6. Carry E1 and E4 into design v2.2.
