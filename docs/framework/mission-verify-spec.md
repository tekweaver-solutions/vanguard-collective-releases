# `mission verify` -- Specification

> **Status.** Specification only. Artifact A3 of the evidence-plane program, authorized by its
> amendment. It implements no CLI, creates no workflow file, installs no hooks, and verifies no
> harness wiring. A4's build dispatches are what build to this document.
>
> **Citation convention** (the standing convention of design v2.2). `LM2-ADR-0NN`
> and "design SS<n>" denote `docs/framework/vanguard-collective-local-modes-v2.2.md`. "schemas
> SS<n>" denotes `docs/framework/expanded-schemas.md`. Bare `ADR-0NN` denotes the on-disk file
> under `tools/mission-cli/config/`. `SS` is this document's ASCII spelling of the section mark.
>
> **Design authority.** Design SS4.3 and LM2-ADR-022 specify the gate; this document specifies
> the instrument. Where this document and design v2.2 disagree, v2.2 governs and the
> disagreement is surfaced rather than resolved silently.
>
> **Encoding.** This file is deliberately **pure ASCII**, which is stricter than the strict-UTF-8
> requirement that binds it. The reason is the A1 record: a BOM-less `.ps1` is parsed by
> PowerShell 5.1 in the ANSI codepage, so a checker that must pattern-match this document either
> wildcards every non-ASCII character or silently matches nothing. Removing the characters
> removes the class. Stated as a choice, not as a rule this document invented for others.

---

## 1. What verify is, and what it is not

`mission verify` is a **comparison between a recorded derivation and a live one**. A prior report
carries `runner_anchors` (schemas SS5, shared shape with SS6) written by the runner from evidence.
Verify re-derives the same subjects now, diffs them, and decides whether the next dispatch may
execute. Design SS4.3: "The manually-ceremonied P0 becomes a gate."

It is not an integrity proof, and this document does not let the word "verify" imply one. Every
subject it compares is compared by a named detector with a stated reach, and every reach has a
residual beside it (design SS4.5 law 4). The honest summary of what verify buys is: **claims that
disagree with re-derivable state stop being consumable.** Claims that agree with state are not
thereby true -- state can be wrong, and the arms below each name the way theirs can be.

Verify does not replace the operator. Design SS4.3 keeps operator spot-checks; design SS10.5 and
schemas SS13 keep operator browser confirmation of the origin tip as standing law and as the final
layer. Verify narrows the window in which a divergence goes unnoticed. It does not close it.

**Nothing here runs today.** No CLI exists. The hooks whose capture this document assumes are
authored and **not installed** -- `.claude/settings.json` is absent from this repository and the
settings fragment self-declares `wiring_status: UNVERIFIED`, per design SS14.2. Every arm below is
the specification of a check, not a check.

---

## 2. Outcome vocabulary, and the gate rule

The vocabulary is closed. Each arm reports exactly one outcome per subject it compares, and each
outcome maps to a gate action with no discretion in between.

| Outcome | Meaning | Gate |
|---|---|---|
| `MATCHED` | Same basis; recorded and derived agree. | proceed |
| `DIVERGED` | Same basis; recorded and derived disagree. **The finding.** | REFUSE |
| `MOVED` | The basis differs, so the comparison cannot decide. Not a disagreement. | REFUSE |
| `UNREACHABLE` | A channel the check requires could not be contacted. Not an absence. | REFUSE |
| `ABSENT` | The subject the check requires does not exist. | REFUSE |
| `NOT_APPLICABLE` | The subject is correctly absent for this dispatch kind. | proceed |

**The gate rule: a dispatch proceeds only when every arm reports `MATCHED` or `NOT_APPLICABLE`.
Every other outcome refuses.** A check that cannot decide reports that it cannot decide; it never
reports agreement. This is the A2 instrument's lesson generalized -- a consumer reading only an
exit code must be able to tell INCOMPLETE from CLEAN, and an instrument that reports its own
incompleteness as a pass is the false-PASS class design SS4.5 law 5 exists for.

**`MOVED` is a distinct outcome and collapsing it is the defect.** Folded into `MATCHED`, a moved
basis silently launders a stale figure as agreement. Folded into `DIVERGED`, ordinary progress
reads as an integrity event and the gate is switched off within a week. Section 9 specifies how
basis is stated so `MOVED` is decidable rather than judged.

**`UNREACHABLE` is not `ABSENT`, and the distinction is load-bearing for the origin arm.**
`git ls-remote` conflates them -- a fact already on record in an earlier architecture note,
which chose the GitHub API's status
semantics precisely because of it. Verify keeps them apart and refuses on either.

**`NOT_APPLICABLE` is an allow-side exemption, and it is disclosed as such** (design SS4.5 law 2:
deny-side heuristics fail safe, allow-side exemptions fail open, and every one is a standing
claim). Its sole admissible member in this document is the `suite` block on read-only and
micro-ceremony dispatches, where schemas SS5's anchor-scoping constraint declares the absence
correct. Any further member requires an amendment naming it. An arm may not invent a
`NOT_APPLICABLE` for a subject the schema does not scope away.

**Lint is not an outcome.** Contradictions in free prose are surfaced as lint for the human and
never as automated verdicts, in both directions (schemas SS5 constraints; design SS12.2). Lint
never refuses a dispatch and never appears in the arm table of a divergence report.

---

## 3. CLI contract

### 3.1 Invocation

```
mission verify --against <report-path> [--dispatch-kind <kind>] [--branch <name>]
               [--evidence-root <path>] [--format yaml|json] [--out <path>]
```

`--against` is the prior report or handoff carrying `runner_anchors`. `--dispatch-kind` selects
anchor scoping (schemas SS5) and defaults to the kind recorded in the artifact under comparison;
verify refuses rather than guessing when neither supplies it. The remaining flags are plumbing.

The runner invokes verify before every dispatch (design SS4.3). A human may invoke it directly;
section 8 gives the form that exists before any CLI does.

### 3.2 The derivation command set

Verify prints the command it ran and the raw output it derived from, for every derivation, and
writes both to the evidence store (section 7). This is LM2-ADR-022's own tradeoff: the gate adds
one more component to keep honest, "mitigated by making `verify` itself trivially auditable (it
prints the commands and raw output it derived from)". A derivation that appears in a verdict
without its command and its raw output beside it is not admissible in a verify report.

| Subject | Command |
|---|---|
| head | `git rev-parse HEAD` |
| tree | `git status --porcelain=v1` |
| origin, git protocol | `git ls-remote origin refs/heads/<branch>` |
| origin, API | the repository host's ref endpoint for `heads/<branch>` |
| suite | the canonical suite command from mission config |
| evidence state | `Get-EvidenceState -Root <repo> -DispatchId <id>` |
| plane parity | `Test-EvidencePlaneParity -Root <repo> -DispatchId <id>` |
| stream integrity | `Test-EvidenceStreamIntegrity -Root <repo> -DispatchId <id>` |
| manifest hash | sha256 over the manifest file |
| schema validity | the manifest validated against `docs/framework/evidence-manifest.schema.json` |

**`git rev-parse origin/<branch>` is not in this table and must never be added to it.** It reads
the local remote-tracking ref, which is a cache updated only by fetch or push. It is not an
observation of origin. Section 6 gives the case that makes the point.

### 3.3 The divergence report

Machine-readable, written to disk, and the artifact a consumer reads. Prose about a verify run is
testimony; this file is the result.

```yaml
verify_version: "1"
verify_id: <id>
invoked_at: <utc-iso8601>
against:
  path: <report path>
  sha256: <64 hex>
basis:
  head: <40 hex>
  tree: worktree            # worktree | index | commit -- see section 9
  untracked_included: true
  hash_class: worktree      # never "clone-stable"
dispatch_kind: <kind>
arms:
  - arm: ANCHOR
    subject: head_sha
    outcome: MATCHED
    recorded: <value from runner_anchors>
    derived:  <value re-derived now>
    detector: "git rev-parse HEAD"
    residual: "<the reach this detector does not cover>"
derivations:
  - command: "git rev-parse HEAD"
    exit_code: 0
    stdout_sha256: <64 hex>
    stderr_sha256: <64 hex>
    stdout: |
      <verbatim>
lint:
  - "<prose contradiction, informational, never gating>"
gate: PASS | REFUSE
refused_by: [ <arm>/<subject>, ... ]     # empty on PASS
```

Rules the format enforces by shape rather than by exhortation:

- **Every arm entry carries its `detector` and its `residual`** (design SS4.5 law 4). An arm entry
  without both is malformed and verify fails rather than emitting it.
- **`recorded` and `derived` are both present on every entry**, including `MATCHED` ones, so a
  reader can check the comparison instead of trusting the verdict.
- **`refused_by` names the subject, not just the arm**, because a class-level refusal reason is
  the overclaim design SS4.5 law 4 forbids.
- **`basis` is mandatory and complete.** A report without a full basis cannot be re-run, and a
  comparison that cannot be re-run is testimony with a schema.

### 3.4 Refusal semantics

- Verify refuses on any outcome other than `MATCHED` or `NOT_APPLICABLE` (section 2).
- Verify refuses when it cannot construct its own basis -- unresolvable HEAD, unreadable
  `--against` artifact, absent `dispatch_kind`.
- Verify refuses when its own evidence write path fails (section 7). A gate that cannot record
  what it did is a gate whose output is prose.
- **Refusal is not an error.** A refusal is a successful run with a `REFUSE` gate and a complete
  report; it is distinguished in the exit contract from verify failing to run at all.

Exit contract, on the A2 instrument's precedent and for the same reason:

| Code | Meaning |
|---|---|
| `0` | ran; gate `PASS` |
| `1` | ran; gate `REFUSE` |
| `2` | did not complete -- verify itself failed, and no verdict exists |

A consumer reading only the code can distinguish "checked, refused" from "did not check". The
failure this prevents: a docstring that says exit 0 means passed-and-nothing-skipped, on code
that exits 0 on a skipped run, where the instrument is the honest one.

---

## 4. The verification arms

Each arm below is stated per-member: what it compares, the named detector, the residual that
detector does not reach, and what the arm emits. Design SS4.5 law 4 governs this section
absolutely -- a class claim requires a working detector for each disclosed member, and an arm that
names a detector this repository cannot point at is an overclaim.

| Arm | Subject | Detector | Section |
|---|---|---|---|
| ANCHOR | `runner_anchors` vs re-derived disk and origin state | `git rev-parse` / `git status --porcelain=v1` / the suite command / manifest hash | 4.1 |
| MANIFEST | evidence manifest state and schema validity | `Get-EvidenceState` + the sealed JSON schema | 4.2 |
| PLANE-PARITY | committed plane vs runtime manifest assertions | `Test-EvidencePlaneParity`, with `Test-EvidenceStreamIntegrity` | 4.3 |
| ORIGIN-ATTESTATION | local origin claims vs origin | `git ls-remote` and the repository host's API | 4.4 |

### 4.1 Arm: ANCHOR

**Compares.** The `runner_anchors` block of the artifact under `--against` (schemas SS5, one shape
carried by SS5 and SS6) against state re-derived now, subject by subject: `head_sha`; `porcelain`;
the `suite` block where present, member by member (`command`, `passed`, `failed`, `skipped`,
`expected_failures_matched`); `evidence_manifest` and `evidence_manifest_sha256`; and
`testimony_conflict`.

**Detector.** `git rev-parse HEAD` for `head_sha`. `git status --porcelain=v1` for `porcelain`,
compared as an ordered list of verbatim lines -- an empty list means a clean tree and never means
the field was skipped (schemas SS5). The canonical suite command from mission config for the
`suite` block. sha256 over the manifest file for `evidence_manifest_sha256`. For
`testimony_conflict`: the decidability rule -- the flag fires only when a **model-populated
structured field** contradicts a runner anchor, never on prose (schemas SS5 constraints; design
SS12.2). The model has no anchor fields to populate; a handoff in which it supplied them is
invalid rather than merely suspect, and that invalidity is this arm's finding, not a lint.

**Residual.**
- **Every file hash this arm compares is a worktree anchor, not a clone-stable one.**
  `core.autocrlf` is `true` in this repository and no `.gitattributes` rule covers `.mission/**`
  or `docs/framework/**`, so a fresh clone smudges LF to CRLF on checkout and the sha changes.
  Verify run in a clone therefore diverges from a worktree-derived anchor **legitimately**. The
  arm handles this by carrying `basis.hash_class` (section 3.3) and reporting `MOVED`, never
  `DIVERGED`, when the recorded and live hash classes differ. It cannot detect the case where a
  hash class is misdeclared; that residual has no detector here.
- **`expected_failures_matched` has no data source in this repository.** Design SS12.2 and schemas
  SS5 name `tools/mission-cli/config/expected-failures.yaml` as its framework home; that file is
  absent. Where it is absent the member is reported `ABSENT` and refuses, rather than being
  silently treated as satisfied. It is not reported `NOT_APPLICABLE`: nothing in the anchor-scoping
  rule scopes it away, and stretching an allow-side exemption to cover a missing file is the
  failure mode design SS4.5 law 2 names.
- **Anchor scoping is honored, and absence of the `suite` block on a read-only or micro-ceremony
  dispatch is correct** -- it is the sole `NOT_APPLICABLE` member (section 2). A full suite run per
  micro-dispatch would contradict the micro-dispatch doctrine.
- **`porcelain` comparison is exact and therefore noisy by construction.** Standing untracked
  residue moves it. This is a property of the subject, not a defect of the detector, and the arm
  does not acquire an ignore-list: an ignore-list here would be an allow-side exemption over the
  exact field that reports unexpected mutation.

**Emits.** One entry per subject, each with `recorded`, `derived`, `detector`, `residual`. `MOVED`
where the basis differs; `DIVERGED` where it does not and the values do; `ABSENT` where the subject
the comparison requires does not exist; `NOT_APPLICABLE` only for the scoped `suite` case.

### 4.2 Arm: MANIFEST

**Compares.** The evidence manifest named by `runner_anchors.evidence_manifest` against what is on
disk, on both axes the schemas declare independent: **derived state** and **schema validity**.

**Detector.** `Get-EvidenceState` (`tools/framework/hooks/lib/evidence-common.ps1`) for state,
whose derived vocabulary is `ABSENT`, `PARTIAL`, `FINALIZED`, `TAMPERED`; and validation against
`docs/framework/evidence-manifest.schema.json`, which schemas SS12 declares **normative** for this
artifact. `FINALIZED` is the only state that permits consumption; `TAMPERED` is `log_sha256` no
longer matching the log on disk; `PARTIAL` blocks consumption while fully supporting forensic
re-ground.

**Verify owes both checks, and neither subsumes the other.** This is NB-1's resolution carried
forward as a rule verify obeys rather than restates (schemas SS12 constraints): a log line that is
valid JSON but carries none of the declared fields yields a manifest that **fails schema validation
while still deriving `FINALIZED`**. An implementation that runs only the state derivation and reports
the artifact good has reintroduced the defect the resolution recorded.

**Residual.**
- **State is a header check.** `Get-EvidenceState` reads `finalized_at` and re-hashes `log.jsonl`.
  It does not read stream bodies. A mutated stream body with an untouched log still derives
  `FINALIZED` from state alone -- which is why arm 4.3 exists and why threat notes R3 records this
  as detected-not-prevented.
- **`hook_errors_present: true` on a `FINALIZED` manifest means `entry_count` may undercount
  reality.** Verify must not consume such a manifest as complete merely because it is finalized
  (schemas SS12, Fields). The arm reports the flag on every entry rather than only when it
  refuses, because a consumer that never sees the flag cannot weigh it.
- **The manifest carries no `seq`** (N-g, resolved deliberately): gap detection lives in
  `log.jsonl`, not in the artifact reports cite. Verify reading only the manifest cannot detect a
  dropped entry by sequence gap, and `entry_count` does not help, being derived from the same
  entries.
- **A `seq` gap is not proof of a dropped capture.** The counter counts all log lines while only
  tool-call lines carry `seq`, so a `_precompact` line consumes a number without recording one.
  A capture gap and an interleaved transcript snapshot are indistinguishable from tool-call `seq`
  values alone. The scope matters and is stated: the gap appears only when a later tool-call line
  takes the next number, so a session that compacted as its last act leaves no gap at all.
- **`seq` is not unique under concurrency** (N-e, declared rather than made safe). Verify treats
  `seq` as an ordering hint and never as a key.
- **A hook that was never installed is undetectable from inside** (threat notes R5, R10). Verify
  running in a session whose hooks never fired sees `ABSENT` and refuses, which is correct; verify
  cannot distinguish "hooks absent" from "dispatch never ran" beyond what `Get-EvidenceState`'s
  own reason string and `hook-errors.log` hint supply. Install-time wiring verification is the
  only control, and it is a separate operator-gated act.

**Emits.** The derived state with its verbatim `reason` string, the schema-validation verdict with
its first failing pointer, `hook_errors_present`, and the `entry_count` the manifest declares.
`FINALIZED` plus schema-valid is `MATCHED`; `PARTIAL` and `TAMPERED` are `DIVERGED`; a manifest at
a path that holds nothing is `ABSENT`.

### 4.3 Arm: PLANE-PARITY

**Compares.** The committed evidence plane against what the runtime manifest asserts was
published, and -- as a distinct subject with a distinct detector -- the stream bodies against the
hashes recorded for them.

**Detector.** `Test-EvidencePlaneParity` for the committed-plane subject.
`Test-EvidenceStreamIntegrity` for the stream-body subject. Both are sealed in
`tools/framework/hooks/lib/evidence-common.ps1`; the parity function is shaped in its own comments
as pre-work for this document.

**The demonstrated class is narrow and this document restates it narrowly.** What
`Test-EvidencePlaneParity` demonstrates is: **a committed artifact the runtime manifest says was
published, which is absent from its canonical path.** Nothing broader. It is not plane integrity
in general -- it compares the committed plane against the runtime manifest's own assertions, and a
runtime manifest that lies about what it published is outside it entirely.

**Its own arms are not uniform, and saying otherwise was a defect an earlier revision of the
sealed source carried.** Verify inherits the asymmetry and states it:

| Subject inside the parity check | What it compares |
|---|---|
| the manifest itself | existence and hash, against the runtime copy |
| `log.jsonl` | existence and hash, against `log_sha256` |
| `hook-errors.log` | existence and hash, against `hook_errors_sha256`, when the manifest says one exists |
| stream bodies | **existence only -- no hash is compared** |

A committed stream body that is present but corrupt passes the parity check. The hash-bearing
check for stream bodies is `Test-EvidenceStreamIntegrity`, which re-derives `stdout_sha256` and
`stderr_sha256` from the body. **Verify runs both, and reports them as separate subjects**, because
reporting parity alone as "the plane is intact" is precisely the class claim law 4 forbids.

**Residual.**
- **The trust boundary is the ceremony commit, and no arm moves it.** Pre-commit runtime evidence
  is provisional and destroyable from inside the session with no marker -- a session can erase
  and repopulate the record and still produce a clean, consumable, self-consistent manifest
  whose `log_sha256` matches. Post-commit evidence is git-protected;
  detection of its destruction belongs to the git, origin, and operator layers. Verify inherits
  this boundary and reports against it; it does not raise it.
- **Ordering matters and is specified in section 5** (NB-2). Run in the wrong order, or with the
  entry variants undiscriminated, these detectors report an honest, already-disclosed capture
  failure as an integrity violation.
- **`transcript_sha256` is compared by nothing.** Verified against the sealed sources: the
  PreCompact hook writes it, the Stop hook projects it into the manifest, the A1 negative suite
  asserts its presence -- and no code path in the sealed set re-derives it from the transcript
  file. The parity check reaches transcripts by existence only, and only when `streams_committed`
  is true. Verify therefore states plainly that a committed transcript's **contents** are
  unverified by any arm in this document. Closing it is a change to sealed A1 code and is
  registered, not specified here as though it existed.
- **Nothing runs any of these automatically today.** Until verify exists as code, an incomplete
  committed plane goes unnoticed unless a person looks.

**Emits.** One entry for the committed-plane subject, carrying the parity function's `checked`
count and its verbatim `problems` list; one entry for the stream-body subject, carrying its
`checked` count and its verbatim mismatch list; and, per section 5, one entry for the capture-gap
subject. Any problem is `DIVERGED`. A runtime manifest that is absent or unparsable is `ABSENT`,
not a parity failure -- the parity function itself distinguishes these and verify does not flatten
them.

### 4.4 Arm: ORIGIN-ATTESTATION

**Compares.** Every claim an artifact makes about origin -- most often a pushed tip -- against
origin itself, through channels that do not share a failure mode: the git protocol, and the
repository host's API. Section 6 states what independence these channels do and do not have.

**Detector.** `git ls-remote origin refs/heads/<branch>`, and the host's ref endpoint for
`heads/<branch>` (`gh api` or equivalent). Both are run; both are recorded with their raw output.

**Rules this arm carries, each of which has cost a program somewhere:**

- **The remote-tracking ref is not origin.** `git rev-parse origin/<branch>` reads a local cache
  updated only by fetch or push. It is not admissible as an origin observation and is excluded
  from the derivation command set (section 3.2). Section 6 illustrates the case.
- **Unreachable is not absent.** `git ls-remote` conflates them. Verify emits `UNREACHABLE` as its
  own outcome, distinct from `DIVERGED` and from `ABSENT`, and refuses on it. It does not retry
  into a verdict.
- **Disagreement between the channels is an operator escalation, never an automated tiebreak.**
  If the channels disagree, verify refuses and escalates with both raw outputs. Picking a winner
  between channels chosen for independence destroys the property the second channel exists for.
- **Credentials are never displayed.** The API channel authenticates through the tool's own
  credential store; no secret bytes appear in any artifact, evidence file, report, or command line
  verify prints. Where a credential must be identified at all, it is identified by hash prefix.
- **Operator browser confirmation of the origin tip remains standing law and remains the final
  layer** (design SS10.5; schemas SS13 constraints). This arm narrows the window. It does not
  replace the human looking at origin.

**Residual.**
- **Both channels run on the session's host.** Hook capture records what they emitted here; it
  does not make the observer independent of the observed. Section 6 states the ladder in full and
  is the honest statement of this arm's ceiling.
- **This arm detects divergence, not authorization.** That origin holds a commit says nothing
  about whether the push was authorized. Push authorization is a separate artifact with its own
  mechanics -- created by the human, TOCTOU-closed by re-derivation at push time, single-use and
  tombstoned on consumption (schemas SS13; design SS12.4) -- and verify does not stand in for it.
- **Silence is not consent.** A channel that fails to answer is `UNREACHABLE` and refuses. This
  rule exists because the companion item in section 6 fails in exactly that shape.
- **Push authorization is Local Autonomous Mode's form of the gate; in Local Orchestrator Mode the
  paste of the push dispatch is the authorization act** (design SS10.5). Verify checks neither
  form. It checks what origin holds.

**Emits.** One entry per channel, each carrying the raw ref line it received, plus one entry for
the comparison against the artifact's claim. Agreement across both channels and with the claim is
`MATCHED`. Any channel failing to answer is `UNREACHABLE`. Channels disagreeing with each other,
or agreeing with each other and disagreeing with the claim, is `DIVERGED` -- and the report keeps
those two cases distinguishable in `refused_by` rather than merging them.

---

## 5. NB-2, resolved

NB-2 is a registered item, carried explicitly as **DEFERRED TO A3 at
wiring time** -- stated as a deferral so it would not look resolved. It comes due here.

**The registered statement.** `Test-EvidenceStreamIntegrity`'s ordering false-positives on an
honest capture failure; recorded at the A1 seal as a one-line fix.

**What the sealed source shows.** In the per-entry loop, the stream-file existence test precedes
the entry-variant discrimination. A `_precompact` entry whose transcript capture honestly failed
carries `captured: false`, a null `transcript_sha256`, and a `path` -- because the schema requires
`path` on that variant. The existence test finds no file, records `stream file missing`, and the
function's `ok` goes false. An evidence gap the manifest already discloses is thereby reported as
an integrity violation.

### 5.1 The rule verify obeys

**Verify discriminates entry variant before it tests existence, and reports capture gaps in their
own category.** Concretely:

1. **Manifest state first** (arm 4.2). A manifest that is not `FINALIZED` makes the remaining
   subjects unreadable rather than failing; verify does not report stream mismatches against a
   manifest it has already refused.
2. **Plane parity next** (arm 4.3), on the committed plane.
3. **Stream integrity last**, and only over **tool-call** entries.
4. **A `_precompact` entry with `captured: false` is a CAPTURE GAP.** It is emitted as its own
   subject with its own outcome and never as a stream-integrity mismatch. It is not silently
   dropped either: a transcript that was supposed to exist and does not is a real evidence gap, and
   the manifest's own `captured` boolean exists as a separate field precisely so that a false there
   is not read as an absent event.

### 5.2 The code delta, stated and not applied

A3 does not touch `tools/framework/hooks/lib/evidence-common.ps1`. It is sealed A1 code, editing
it would move a seal hash, and the authorizing amendment rules this arm SPECIFY-ONLY. The delta below is registered as
an A4-dispatch build item.

**Minimal form -- the "one-line fix" as registered.** Hoist the variant discrimination above the
existence test: move the `stdout_sha256` fetch and its `continue` so they precede the `Join-Path`
and `Test-Path` block. This closes the false positive.

**The registered characterization understates it, and that is recorded here rather than inherited.**
Verified against the sealed source: the minimal hoist buys the cure at the price of **dropping the
existence check for honestly-captured transcripts**. Today a `_precompact` entry with
`captured: true` reaches the existence test and is checked; after a bare hoist it is skipped before
reaching it. The trade is a false positive removed for a coverage hole opened, in a function whose
whole purpose is coverage.

**Correct form -- what A4 should build.** Branch on the variant rather than falling through it:

- tool-call entry: existence, then `stdout_sha256` and `stderr_sha256` re-derived from the body.
  Unchanged.
- `_precompact` entry with `captured: false`: emit a CAPTURE GAP for the entry. No existence test,
  no mismatch.
- `_precompact` entry with `captured: true`: existence test, **and** compare
  `transcript_sha256` against the sha256 of the snapshot file -- a comparison **no code in the
  sealed set performs today** (arm 4.3, residual). This is the coverage the bare hoist would have
  removed, plus the coverage that was never there.

This is more than one line, and calling it one line would be the kind of authored claim design
SS4.5 law 3 exists to stop. Design SS4.5 law 9 applies to the register as it applies to rulings:
a registered characterization refuted by source is corrected on the record.

---

## 6. The independence ladder, and the origin-side companion item

### 6.1 The ladder, in full

Design SS4.1 established where integrity is and is not achievable for evidence capture. The origin
arm needs the same treatment, because "we checked origin" is a claim whose strength depends
entirely on who did the checking.

| Rung | What it is | What it is worth |
|---|---|---|
| **SESSION-REPORTED** | a sha in an agent's prose | Nothing under Principle 11. A figure that exists only in agent prose does not exist. |
| **HOOK-CAPTURED** | the harness recorded what the command emitted | A real gain, and where A1's integrity claim lives (design SS4.1 layer (b)): the model never held the pen. |
| **ORIGIN-SIDE ATTESTED** | a party that is not the session host asserts what origin holds | The only rung on which the observer is independent of the observed. |

**Reading the ladder.** A SESSION-REPORTED figure is testimony: design SS4.4's rule that a figure
existing only in agent prose does not exist is this rung being refused. A HOOK-CAPTURED figure is
the gain A1 built -- the hook process is spawned by the harness, so the model never held the pen --
and it is where design SS4.1 places the integrity claim for evidence capture. ORIGIN-SIDE ATTESTED
is the rung at which the party doing the asserting is not the party being asked about, and it is
the only rung on which "we checked origin" means something an adversary on this host cannot
arrange.

**The middle rung's limit, stated rather than glossed.** A HOOK-CAPTURED `git ls-remote` is still a
command run on the session's host, with the session's PATH, network path, and credential store. It
raises "the model said so" to "the harness recorded what ran here". It does not make the observer
independent of the observed. A compromised or merely misconfigured host defeats it in the git
channel and the API channel at once, which is exactly the shared failure mode that same-host
channels cannot rule out -- and it is why the companion item in 6.3 has to execute somewhere else
to be worth building at all.

**This document specifies the top rung. It does not possess it.** Saying otherwise -- presenting a
hook-captured `ls-remote` as origin-side proof -- would be the overclaim class this program exists
to stop, wearing the clothes of a security control.

### 6.2 The motivating datum

Stated as an illustration of a sequence any program with a separate push ceremony can produce.

A sealing ledger entry closes: "No push: origin remains behind, and push authorization stays an
operator act." At the next grounding, `git ls-remote origin refs/heads/main` returns the sealed
commit itself -- origin's tip equals HEAD -- and the local reflog carries `update by push` against it.

Nothing need be fabricated for this to happen. The sentence is true at authorship; the push is
operator-authorized through the paste-as-gate dispatch that design SS10.5
names as the authorization act in Local Orchestrator Mode; it is executed by a dedicated
single-act session; operator browser confirmation of the tip closes the ceremony;
and that session is instructed to record nothing, so the confirmation lands in the next
ceremony's consolidated entry. The ceremony is performed correctly and completely.

**And a consuming session still reads "origin remains behind" with nothing in the local record to
tell it otherwise.** That is the durable finding: the staleness class survives the ceremony being
performed perfectly, because a local record cannot surface an origin move to a later reader. It is
not a discipline failure and no amount of more careful authorship prevents it. It is the case this
arm exists for.

### 6.3 The interim independent channel -- REGISTERED, NOT BUILT

A workflow running on the repository host's infrastructure, triggered on push, posting the pushed
tip to an operator surface the session cannot write. Executing off the session's host is what makes
it the top rung.

**Sketch.** Trigger on push to the tracked branch. Read the pushed head from the host-supplied
event context, not from a command the workflow shells out to. Post it, with a timestamp and the
run's own identity, to a surface the session has no write path to. Retain history so a later
reader compares a sequence rather than a snapshot.

**Residuals, carried with the sketch instead of after it:**

- **Whoever can push can also alter the workflow file.** The attestation is only as independent as
  push authorization is. This does not make it worthless -- altering it is a visible, committed,
  reviewable act, which is more than the middle rung offers -- but it is not a boundary.
- **The operator surface must be one the session has no write path to.** If the session can write
  it, the top rung collapses back to the middle and the extra machinery buys nothing.
- **A workflow that fails to run is silence, and silence must not read as consent.** A consumer of
  this channel treats absence as `UNREACHABLE`, per section 2, and refuses.
- **It attests what origin received, not that the push was authorized.** Authorization is the
  Push Authorization artifact's job (schemas SS13).

**Status: REGISTERED, NOT BUILT.** No workflow file is created by A3, and this is a scope fact
rather than an intention: `.github/` does not exist in this repository and `.github/**` is outside
the program's declared write surface. Building it requires an amendment that widens that surface.

---

## 7. Evidence self-capture

Verify's own derivation rides the evidence plane. Design SS4.3: its output "is subject to
Principle 11 like everything else".

- **In the runner or harness process**, verify writes its derivation -- commands, raw output,
  verdict -- to the evidence store directly, outside any session's pen.
- **Invoked inside a session** (the L0/L1 use in section 8), verify's execution is hook-captured
  like any other tool call, and its report is committed at the next ceremony boundary.
- **A verify result that exists only in agent prose does not exist.** A conversation carries the
  report's path, its sha256, and a small verbatim excerpt -- never the verdict as prose standing
  alone, and never an attachment as the sole carrier (design SS4.4).
- **Verify refuses if it cannot write its own evidence** (section 3.4). A gate whose record is
  optional degrades silently into a ceremony.

**What this inherits, stated rather than assumed.** The hooks are authored and not installed;
`wiring_status` reads `UNVERIFIED` and upgrading it is the first act after an operator-gated
install. Until then the self-capture path above is a specification of a capture path. And even
after install, the trust boundary is the ceremony commit: verify's own report, before it is
committed, is provisional and destroyable from inside the session with no marker -- which is the
argument for committing evidence at the earliest ceremony boundary rather than the most convenient
one.

---

## 8. The L0/L1 pasted-dispatch form

The discipline is adoptable before the CLI exists, and design SS11.4 keeps the pasted form
available permanently as a manual instrument. The pasted P0 and the future gate are **the same
check in two carriers**: same command set, same outcome vocabulary, same gate rule.

The pasted form is a read-only dispatch that:

1. **States its basis first** -- HEAD, tree state, whether untracked files are included, hash class
   (section 9). A P0 that reports figures without its basis cannot be compared to anything later.
2. **Runs the derivation command set** (section 3.2) and shows each command with its verbatim
   output. Not a summary of the output. The output.
3. **Walks the arms in the section-5 order**, reporting one outcome per subject from the closed
   vocabulary, with the recorded value and the derived value side by side.
4. **Applies the gate rule literally**: anything other than `MATCHED` or `NOT_APPLICABLE` halts and
   reports, and the report is what the operator reads. A pasted P0 that finds a divergence and
   proceeds anyway has taught the next one that the gate is advisory.
5. **Ends by naming what it did not check.** The arms it could not run, and why. An unrun arm
   reported as absent from the findings is the false-PASS class in prose form.

Two properties of the pasted form are worse than the gate's and are stated so nobody mistakes the
transition for a formality: it runs when a human remembers to run it, and its output is chat until
it is committed. Design SS11.4's assessment stands -- the pasted form worked, and it scales with
human attention rather than with mission length.

---

## 9. Sequencing rules -- the standing law, generalized

**The standing law.** Acceptance evidence over derived populations is taken at anchor HEAD before
any mutation of `.mission/amendments/`. The reason: an authorizing amendment placed after a
derivation is taken enters the very population that derivation counted, so the derived figure
goes stale the moment the amendment lands, and an instrument that re-derives it catches the drift
at the next grounding.

**The generalization.** Verify is a comparison between a recorded derivation and a live one.
Therefore **every derived figure states its basis, and no comparison is admissible without one.**

A basis is: which tree (worktree, index, or commit), at which HEAD, with untracked files included
or excluded, and under which hash class (worktree or clone-stable). All of it, or
the figure is not comparable.

**The outcomes stay distinct, and collapsing any pair is the defect** (section 2): `MATCHED`;
`MOVED` -- the basis differs, so re-derive or re-run at the anchor; `DIVERGED` -- the basis is the
same and the answers are not.

**Consequences that bind an implementation:**

- **A derivation taken before a mutation that moves its subject is stale, and the stale window is
  exactly the interval in which the check FAILS rather than skips.** In that window the failure is
  the instrument correctly reporting a stale figure, not a defect in the ceremony.
- **Prefer bases that the ceremony does not move.** An artifact that derives no population from
  `.mission/amendments/` cannot be destabilized by placing an amendment there. This document takes
  that route deliberately: **no figure in it is derived from the contents of
  `.mission/amendments/`**, so its anchor is insensitive to when its authorizing amendment is placed. Sequencing
  correctly is still required; not needing to is better.
- **Where a basis genuinely must move, state the self-reference in the artifact** rather than
  leaving a reader to discover it -- the disclosure pattern schemas uses at its derivation anchor.
- **A skip is not a pass.** An instrument that cannot decide at the current basis says so, and the
  exit contract keeps that distinguishable from clean (section 3.4).

---

## 10. Derivation anchor, and the sealed sources this document is verified against

**Derivation anchor.** Every figure below is re-pinned at this release's HEAD to the files as
this release ships them (LF bytes); a later edit to a listed file leaves its row stale until the
row is re-derived, and framework member A3 (check K3a) re-derives every row from disk and fails
until it is. Re-derive from the repository root:

```powershell
git rev-parse HEAD
Get-FileHash -Algorithm SHA256 -LiteralPath <path>
```

Sealed sources this document cites, with the sha256 prefix and byte length each re-derives to (LF bytes, as this
release ships them):

```
3849bd6d  105431  tools/framework/hooks/lib/evidence-common.ps1
f4b3ac5d  30300  docs/framework/evidence-manifest.schema.json
a88f0a38  92040  docs/framework/expanded-schemas.md
d2f84056  48528  docs/framework/vanguard-collective-local-modes-v2.2.md
b99c02a7  35571  docs/framework/evidence-write-path-threat-notes.md
03322c44  74992  tools/framework/tests/test-a1-negative.ps1
```

Every claim this document makes about A1 or A2 code was verified against those sources rather than
against a predecessor's description of them; the list above is re-pinned at this release's HEAD to
the files as this release ships them, so a reader can re-derive the figures. The functions it names --
`Get-EvidenceState`, `Test-EvidencePlaneParity`, `Test-EvidenceStreamIntegrity` -- resolve in the
first of them.

---

## 11. What this document does not claim

It is a specification. It builds no CLI, creates no workflow file, installs no hooks, and does not
verify harness wiring -- which remains `UNVERIFIED` and operator-gated per design SS14.2.

The evidence-plane enforcement claims are inherited from A1 and are not re-argued here: mount
exclusion (design SS4.1 layer (a)) is unavailable for natively-run sessions;
harness-side capture (layer (b)) carries the integrity claim and is unverified under a real
harness; the PreToolUse guard (layer (c)) is an accident tripwire and is not a write boundary.

It does not apply the section-5 code delta (ruled SPECIFY-ONLY); does not create
`tools/mission-cli/config/expected-failures.yaml`; does not build the section-6 workflow; does not
touch root `.gitattributes` (the durable fix for the line-ending residual of section 4.1, registered and outside the write surface);
does not extract a framework repository (a registered durable fix); does not move the
delegation ladder; and does not touch the sealed mission record.

**No standing enforcement exists for this document's own shape.** An acceptance test ships beside
it at `tools/framework/tests/test-a3-acceptance.ps1`. **Nothing invokes it** -- no hook, no gate,
no ceremony step -- so it decides only when a person runs it, and this document can drift between
runs of it. It is an instrument, not a boundary. What it checks, it derives from this document and
from the sealed sources rather than from a list maintained inside the test; where a check's reach
is narrower than its name suggests, the check prints its own reach.

## 12. Registered by this document

- **The section-5 correct-form delta** to `Test-EvidenceStreamIntegrity`, including the
  `transcript_sha256` comparison that no sealed code performs -- an A4-dispatch build item.
- **The section-6.3 origin-side attestation workflow** -- needs an amendment widening the write
  surface to `.github/**`.
- **`tools/mission-cli/config/expected-failures.yaml`** -- declared home, absent file; its content
  is mission truth.
- **A committed transcript's contents are unverified by any arm here** (arm 4.3 residual).
- **Misdeclared hash class has no detector** (arm 4.1 residual).
