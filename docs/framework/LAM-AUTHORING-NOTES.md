# LAM authoring notes -- toolchain facts, each with the record that measured it

**What this document is.** Toolchain facts that otherwise lived only in a Claude Code
project memory folder,
`%USERPROFILE%\.claude\projects\<project-slug>\memory\`,
collected while the framework's acceptance instruments were authored. Each fact is stated in one
paragraph from the measurement that established it, not from the note's wording. Measured
against the record, most of them had already been measured while the instruments were built,
and the notes carried them as a seat's lessons; where no earlier record measured a fact, the seat
that wrote this document measured it itself with a scratch probe, and the paragraph names the probe
(P1 to P6) and what it showed.
The build's own contract record is not part of the release: each fact stands on its probe and on
the tracked code it cites.

**Which facts.** The PowerShell 5.1 authoring traps
(section 1), the member and reading rules (section 2), the tool and harness facts (section 3) and the
validator-record rules (section 4). Section 5 lists the notes the facts were drawn from, and says of
each whether its fact is here, elsewhere, or nowhere tracked; the notes themselves do not ship.

**Why the folder held them.** The harness maps a linked worktree's session to its main project's memory
(measured from the harness side with a probe),
so tooling seats wrote their lessons there. `autoMemoryEnabled: false` is tracked in `.claude/settings.json`
and it holds only for sessions opened with the file present; whether such a session honours it is still
unmeasured.
No note was edited, moved or deleted by this package.

---

## 1. PowerShell 5.1 authoring traps

### 1.1 An array crosses a boundary unrolled, in both directions

A helper that returns its array with the unary comma (`return , $out`) hands it back whole under
assignment, but inside an array subexpression the whole array arrives as ONE element: measured
on Windows PowerShell 5.1 (probe P2: assigned, `.Count` 2; `@(Get-P2Wrapped)`,
`.Count` 1, its element 0 a `System.Object[]`; assigned and then wrapped, 2). Assign first, normalise
second. The opposite direction bites on assignment from a statement: the value of an `if` statement is
unrolled, so an inner `@()` holding exactly ONE element arrives as that element. WP-4's member T-32
once aborted the instrument twice on exactly this under
`Set-StrictMode -Version Latest`: at RED the operator-acts log held one line and `.Count` threw
(`PropertyNotFoundException`), and at GREEN it would hold two and the identical code would
have passed by luck. Probe P3 reproduces it: `$x = if ($true) { @('only') } else { @() }`
is a `System.String`, `.Count` on it throws `PropertyNotFoundException` under StrictMode Latest and reads 1
without it, two elements stay an `Object[]`, and `@(if ...)` keeps the array. The second direction is
self-concealing: it fires only at exactly one element.

### 1.2 A backtick continuation that meets a comment ends the call, and the parameters after it are unbound

A comment line placed between a backtick line-continuation and the next
parameter breaks the continuation; PowerShell parses a complete call with that parameter unbound, a `[bool]`
parameter takes its default `$false`, and the row reports False whatever it measured. A parse check does
not see it. The tell: the row printed `: False` with no `-Said` suffix while every
neighbouring row carried one. Probe P4 drove both spellings beside a control -- a comment
line after the backtick (P4a), a comment after the backtick on the same line (P4b), and the plain
continuation (P4c). All three parse with 0 errors. In P4a and P4b the call completes as
`Ok=False Said=[]` where the control reads `Ok=True Said=[bound]`, and the orphaned parameter line then
runs as a command of its own and raises `CommandNotFoundException` ("The term '-Ok' is not recognized as
the name of a cmdlet ..."): non-terminating under the default `$ErrorActionPreference`, so the script goes
on, and terminating under `'Stop'` (P4d), where the script ends at that line with exit 1. An earlier
description, "with no error anywhere", is therefore not what a plain `-File` run shows; the instrument context
it described was not re-derived here.

### 1.3 A variable followed by a colon inside a double-quoted string is a scope-qualified name

No earlier record measured this trap; the measurement is probe P1.
`"the page ratifies $declared: [x]"` does not parse -- the parser's message, verbatim:
`Variable reference is not valid. ':' was not followed by a valid variable name character. Consider using ${} to delimit the name.`
-- and `"the page ratifies ${declared}: [x]"` parses with 0 errors. Tracked code uses the delimited form at
this kind of site: `tests/lam/instrument-WP-2.ps1:1405` and `tests/lam/instrument-WP-2.ps1:1409`, the
R-16 derivation. A parse check catches this one; a read does not.

### 1.4 A regular expression inside a double-quoted string is expanded before the match runs

Recorded at the site of its cure, WP-2's member R-B, `tests/lam/instrument-WP-2.ps1:10593-10596`:
the pattern first stood in a double-quoted string, PowerShell expanded `$closedGateOutcomes` before the
match ran, and the reference to a variable the instrument never defines killed the instrument partway,
with no summary line and the member never emitted. It fails at run, not at parse. A pattern is data:
single-quote it. The same instrument records a second abort at its member R-A's
site, `tests/lam/instrument-WP-2.ps1:10325-10329`, where `Add-Content` met a directory a fresh
fixture root did not have; its cure reads "R-A's ledger append creates its
directory".

### 1.5 The row count is the abort tell

An exception that escapes a member kills the instrument: every later row goes unmeasured, no summary line
is printed, and exit 1 with a fail list is also what one genuine failure looks like. It was
measured on a title whose apostrophe closed a single-quoted string: the file parsed
clean and died at run, WP-3 emitting no summary line, exit 1 and zero failing rows -- "A RUN WITH NO SUMMARY
LINE AND AN EMPTY FAIL LIST IS THE ABSENCE OF A MEASUREMENT, NOT A GREEN RUN" -- so a row count is
reported beside every summary line. Each count is checked against
the declared member count: a run can abort with neither the exit code nor the fail list
showing it, and only the count does. Inside a member the cure is
the T-32 wrapper: the body in `try/catch`, a crash becoming a failing row that names its line,
"because an abort is the absence of a measurement".

---

## 2. Members, probes and readings

### 2.1 A member's probe runs in the mode the production code runs in

A validator finding: `Get-LamOriginAttestationGate`'s early return carried other
field names than its caller read, and it refused only because PowerShell's default property access yields
`$null`; under `Set-StrictMode -Version Latest` it threw. WP-3 C-1q's probe set `$ErrorActionPreference`
but not StrictMode, so the member written for that path ran under weaker conditions than the code it
measures. C-1q was strengthened to run its probe under StrictMode, RED before its cure and GREEN after.
The class: "[THE FINDING] WAS CURED AT THE INSTANCE,
NOT THE CLASS" -- any instrument-authored child script can run under weaker conditions than the production
code it measures -- and its cure is per member: each probe sets the production shape explicitly and
says which.

### 2.2 A shared library's dot-source of a sibling is a load-time dependency

An unconditional dot-source of
`lam-gate-class.ps1` took the admission library down whenever a consumer copied that library alone, and
WP-1 H-3 and H-16 went RED over functions that had not changed; it entered at one commit and was cured at
a later one, whose commit reads "the load dependency made conditional and fail-closed".
The cure is a pair: "the sibling is loaded WHEN PRESENT, and its absence is answered AT THE CALL
by the one function that needs it, which refuses naming the missing predicate and its file".
A four-point reading across the defect's entry and its cure attributes the two RED members to it and to
nothing else.

### 2.3 Guard-rule members read their location, not only their commit

Six members: WP-1 H-8 and WP-4 T-5 and T-10 drive the live installed
guard's dispatched-worker role, whose peer-worktree rule denies from inside the `<project>-worktrees\`
home -- FAIL there, PASS outside it; WP-2 R-36a needs a `\U`
segment in its sandbox path; WP-6's F-0 and its eight dependents need the smoke mission beside the
repository of record; and `check-prepush-installed.ps1` hashes the raw bytes of the file as checked out, so
it answers by EOL. "A reading of any of these ... members is a statement about a
PATH as much as about a commit." Acceptance runs taken at the
root read the class's instrument members PASS,
while member (6), the pre-push checker's EOL dependence, is not part of the
acceptance run. A reading of these members is stated with its
path.

### 2.4 WP-6 run away from the root needs `-SmokeRoot`

WP-6 resolves its smoke mission beside the tree's parent unless `-SmokeRoot` is given
(`tests/lam/instrument-WP-6.ps1:59`). Away from the root that smoke mission is
not there: run away from the root without `-SmokeRoot`, WP-6 finds no smoke repository and most of
its checks fail; such a run is not a reading. With `-SmokeRoot` at the real smoke mission, the checks
that need it read that mission instead of failing on its absence. A run launched away from the root
without the smoke root is never a reading of record. `-SmokeRoot` binds both of WP-6's anchors.
The fixture is
`<folder>\lam-smoke`, with its bare origin beside it;
runs of record taken away from the root pass it with `-SmokeRoot`,
and at the root WP-6 resolves it by location.

### 2.5 Falsify first: the RED reading finishes before the cure is committed

A validator finding: a text said a RED was
read before the correction was committed, and git's commit times against the runner's own
`started=`/`ended=` stamps showed otherwise. Commit times checked against those stamps can show that
a RED reading was still running when its cure was committed; a RED taken after the
correction is committed and after its GREEN is no RED; and a reading that ends early because the session stopped the
background shell that launched the chain is discarded as an apparatus
cut. Only a red reading that finished before its cure was committed counts. A
falsify-first claim is a claim about time as well as about the tree read: commit the member, let the RED
reading finish, then commit the cure, and write the timeline from the stamps.

### 2.6 The text-only proof uses the language's own lexer, and carries an inverted control

A diff is proved text-only by tokenizing each file at base and tip,
dropping every Comment and String token -- and the NewLine that ends a comment-only line, or adding a
comment line would read as an added token -- and diffing what is left; a parse error is fatal. "IT CARRIES
ITS INVERTED CONTROL, BECAUSE A PROOF THAT CANNOT FAIL PROVES NOTHING." An independent validator re-checked
it with the v3 AST parser recursing into `StringExpandableToken.NestedTokens`, which the v2 `PSParser`
cannot expose, so the v2 lexer is blind inside an expandable string. The
proof therefore runs both lexers, and its inverted controls show the v2 lexer reading nothing where v3 reads tokens on code
planted inside a here-string. A later form compares working copy against
working copy, adds Python's `tokenize` and `ast` views, and runs four inverted controls.
A token count depends on the counting convention and is stated with it.

---

## 3. Tools and harness

### 3.1 A heredoc does not deliver the bytes typed

The record shows inline Python composed inside a Bash heredoc whose backslash-n escapes the shell
consumed, caught by an assertion and redone with a file tool, and a worker's Bash heredoc
that died on an unmatched quote in the shell itself, the file then written with the Write tool. Probe
P6 measured the Bash tool with a QUOTED heredoc (`<<'EOF'`): a doubled backslash
typed as `X\\Y` landed as one backslash, a backslash-u escape of four hex digits landed as the character it
names, and a single backslash before `n` was kept. Write scripts and patch files with the Write tool, not
heredocs, and check the written bytes for the construct intended before running them.

### 3.2 The Write and Edit tools decode a backslash-u escape

No earlier record measured this; the measurement is probe P5. A Write whose
content carried, between `X` and `Y`, a backslash, the letter `u` and four hex digits wrote the bytes
`58 41 59` -- the letter the escape names -- while `\x41`, `\t` and `\q` arrived as typed; an Edit adding
the same shape wrote `58 42 59`. Text meant to carry that escape literally (a regular expression, a JSON
fragment, a comment quoting one) arrives as the character, and an ASCII file can become non-ASCII without
a sign. Build such text with a placeholder a script replaces (`chr(92)`), and count the bytes at or above
0x80 after every write.

### 3.3 The workflow harness frames prompts; the Agent tool is the route for a validator

A workflow harness can frame a prompt with a paragraph of its own and indent every line, so the
prompt received differs from the prompt written, in size and in sha256; a validator launched
that way is not judging the prompt written, and its launch is stopped. A validator of
record is one whose prompt as received is byte-identical to the file. So
validators are spawned through the Agent tool only. The check:
the prompt as received, read out of the validator's transcript,
byte-compared with the prompt written.

---

## 4. Validator records

### 4.1 A validator's prompt and report are hashed from its own transcript

Validators' prompts and reports are recorded by size and sha256 read out of the
validator's transcript, so the prompt as
received is compared byte for byte with the prompt written and the report is the validator's final text as
the transcript holds it, not a hand copy. A prompt received can be the written bytes
less the final LF, so both are hashed. The case
that makes the transcript necessary: a validator's Write of its report file can be refused by its harness, so its
report is its returned text and the file it named does not exist. A page records where
its first round's transcript was read and the prompt and report hashes taken from it; a later round
that judges the page carrying that record takes its own hashes from the seat's report.

### 4.2 A validator's drive flags are read before its finding is restated

A validator reported that an id could
spawn again under a second dispatch gate. Its drive script passes
`-AllowIdReuse`, and without that flag the runner's id-reuse guard (`mission-dispatch.ps1:1031`,
ahead of the gate decision at `mission-dispatch.ps1:1258`) refuses a reused id; the closure states the class
with the condition the runner puts on it. A report summarises what a drive showed, not the switches the drive
needed: open the drive script a finding names, and list its non-default flags, before the finding becomes
page text.

---

## 5. The notes, inventoried

**Read whole**, every note by file tool. The notes do not ship, and their sizes and modification
times are not recorded here; a note about one host's product, builds or rounds is listed by kind
only, not by name. The DISPOSITION column says
where each note's fact now stands:

- **promoted, section N** -- this document carries it, cited as above.
- **carried by v2.4-DELTA E-n** -- `docs/framework/vanguard-collective-local-modes-v2.4-DELTA.md` section 7
  carries it.
- **not promoted: session or build state** -- a record of one seat's or one build's state, superseded by
  the ledger.
- **not promoted: the folder's index** -- `MEMORY.md`, which names the other notes.
- **not promoted: outside this package's list (kind)** -- a durable fact this package was not asked to
  promote. Whether it already stands on a tracked page was not established note by note, except where the
  row says so. **Deleting such a note may lose its fact.**

| note | disposition |
|---|---|
| a note: the clean-tree gate is unsatisfiable, use `-NoCommit` | not promoted: outside this package's list (ceremony) |
| `a3-ladder-classify-from-spec.md` | not promoted: outside this package's list (method) |
| `agent-worktree-isolation-wrong-base.md` | not promoted: outside this package's list (harness) |
| `amendment-hash-columns-two-commands.md` | not promoted: outside this package's list (method) |
| a note on one host product build's state | not promoted: session or build state (a product build) |
| `auto-mode-classifier-blocks-agent-writes-into-guarded-territory.md` | not promoted: outside this package's list (harness) |
| `bash-heredoc-halves-backslashes.md` | promoted, section 3.1 |
| `c1v-token-scan-forbids-mentions.md` | not promoted: outside this package's list (instrument) |
| `check-e5-register-before-reporting-capture-findings.md` | not promoted: outside this package's list (method) |
| `close-cli-uv-nosync-stderr.md` | not promoted: outside this package's list (ceremony) |
| `close-gate-flaky-test-retry.md` | not promoted: outside this package's list (ceremony) |
| `close-milestone-gates-and-witness.md` | not promoted: outside this package's list (ceremony) |
| `combined-mutate-and-measure-drops-rows.md` | not promoted: outside this package's list (method) |
| `commit-message-encoding-discipline.md` | not promoted: outside this package's list (git) |
| `commit-message-key-value-last-line-is-a-trailer.md` | not promoted: outside this package's list (git) |
| `credential-handling-hash-only.md` | not promoted: outside this package's list (conduct) |
| `credui-null-uiinfo-faults.md` | not promoted: outside this package's list (platform) |
| `edit-tool-flips-lf-to-crlf.md` | not promoted: outside this package's list (harness) |
| `evidence-hooks-installed-live.md` | not promoted: outside this package's list (guard) |
| `falsify-first-red-must-finish-before-cure-commit.md` | promoted, section 2.5 |
| `fixture-config-writethrough-to-host-git-config.md` | not promoted: outside this package's list (git) |
| a note on one host product's mechanics | not promoted: outside this package's list (product) |
| `fresh-clone-needs-longpaths.md` | not promoted: outside this package's list (git) |
| `git-apply-check-crlf-depends-on-autocrlf.md` | not promoted: outside this package's list (git) |
| `git-checkout-autocrlf-flips-lf.md` | not promoted: outside this package's list (git) |
| `guard-glob-bypass-escalated-not-patched.md` | not promoted: outside this package's list (guard) |
| `guard-metachar-tier-shapes-commands.md` | not promoted: outside this package's list (guard) |
| `guard-probe-apparatus-traps.md` | not promoted: outside this package's list (guard) |
| `guard-protected-match-is-filesystem-wide-suffix.md` | not promoted: outside this package's list (guard) |
| `guard-rule-members-are-environment-dependent.md` | promoted, section 2.3 |
| `instrument-probes-must-match-production-strictmode.md` | promoted, section 2.1 |
| `lam-install-byte-tables-are-lf-blob-basis.md` | not promoted: outside this package's list (method) |
| `ledger-append-tags-file-comma-trap.md` | not promoted: outside this package's list (PowerShell) |
| `lifecycle-cli-untracked-doc-relocate.md` | not promoted: outside this package's list (ceremony) |
| a second note on the host product's mechanics | not promoted: outside this package's list (product) |
| a third note on the host product's mechanics | not promoted: outside this package's list (product) |
| a note on one host's build state | not promoted: session or build state |
| a fourth note on the host product's mechanics | not promoted: outside this package's list (product) |
| `measure-object-line-skips-blank-lines.md` | not promoted: outside this package's list (PowerShell) |
| `member-commit-wording-not-alone.md` | not promoted: outside this package's list (reporting) |
| `MEMORY.md` | not promoted: the folder's index |
| `mission-lifecycle-ceremony.md` | not promoted: outside this package's list (ceremony) |
| `operator-prefers-ground-then-halt.md` | not promoted: outside this package's list (conduct) |
| `parallel-builders-lock-script.md` | not promoted: outside this package's list (method) |
| `protected-instrument-rewrite-handover.md` | not promoted: outside this package's list (method) |
| `ps51-array-literal-arg-concat-splits.md` | not promoted: outside this package's list (PowerShell); carried as v2.4-DELTA E101 |
| `ps51-authoring-traps-parse-only-on-run.md` | promoted in part, sections 1.3, 1.4 and 1.5; its three earlier traps (a backslash-quote in a double-quoted string, a nested block-comment close, a late `param()`) not promoted: outside this package's list (PowerShell) |
| `ps51-bomless-script-mangles-utf8-literals.md` | not promoted: outside this package's list (PowerShell) |
| `ps51-comma-wrap-return-vs-array-subexpression.md` | promoted, section 1.1 |
| `ps51-literalpath-glob-silent-nulling.md` | not promoted: outside this package's list (PowerShell) |
| `ps51-native-av-uncatchable-use-hpcse.md` | not promoted: outside this package's list (PowerShell) |
| `ps51-native-stderr-terminates.md` | not promoted: outside this package's list (PowerShell) |
| `ps51-one-letter-function-names-lose-to-aliases.md` | not promoted: outside this package's list (PowerShell) |
| `ps51-param-binding-probe-real-block.md` | not promoted: outside this package's list (PowerShell) |
| `ps51-variable-names-fold-case.md` | not promoted: outside this package's list (PowerShell) |
| `pytest-fresh-worktree-needs-tools-venv.md` | not promoted: outside this package's list (environment) |
| a note grounding one build | not promoted: session or build state (a build's grounding) |
| `reclose-ceremony-amendment-prep-commit.md` | not promoted: outside this package's list (ceremony) |
| `register-is-authority-not-the-dispatch.md` | not promoted: outside this package's list (method) |
| `relay-figures-can-be-fabricated.md` | not promoted: outside this package's list (method) |
| `repo-eol-is-mixed-per-file.md` | not promoted: outside this package's list (git) |
| `residue-keep-is-four-operator-files.md` | not promoted: outside this package's list (ceremony) |
| `runtime-plane-docs-unreachable-from-worktrees.md` | not promoted: outside this package's list (seat) |
| a note: superseded sealed-set anchors, use the current amendment's | not promoted: outside this package's list (method) |
| `sed-i-strips-cr-invisibly.md` | not promoted: outside this package's list (git) |
| `sendmessage-to-workflow-agent-spawns-duplicate.md` | not promoted: outside this package's list (harness) |
| `shared-library-dot-source-is-a-load-time-dependency.md` | promoted, section 2.2 |
| `spawn-ledger-writers-are-seat-scratch.md` | carried by v2.4-DELTA E-6 |
| `state-not-reached-by-class.md` | not promoted: outside this package's list (method) |
| `text-only-proof-via-psparser.md` | promoted, section 2.6 |
| `tool-filter-misreads-cmd-slash-d.md` | not promoted: outside this package's list (harness) |
| `validator-drive-flags-before-restating.md` | promoted, section 4.2 |
| `validator-must-be-subagent-isolated.md` | not promoted: outside this package's list (conduct) |
| `validator-report-sha-from-subagent-jsonl.md` | promoted, section 4.1 |
| `verify-instrument-hermetic-channel-fixtures.md` | not promoted: outside this package's list (instrument) |
| `verify-plane-root-and-lib-resolution-coupling.md` | not promoted: outside this package's list (instrument) |
| `witness-mutation-commands-composed-fresh.md` | not promoted: outside this package's list (conduct) |
| `workflow-harness-frames-prompts-not-verbatim.md` | promoted, section 3.3 |
| `worktree-seat-has-no-guard.md` | carried by v2.4-DELTA E-4 |
| a note on one work package's closure state | not promoted: session or build state (a closure, landed) |
| `wp6-needs-smokeroot-via-runner.md` | promoted, section 2.4 |
| `write-edit-tools-decode-unicode-escapes.md` | promoted, section 3.2 |

**The counts, by disposition:** promoted 13 (one of them in part); carried by v2.4-DELTA section 7, 2;
session or build state, 4; the index, 1; outside this package's list, 62.
None of the notes ships with the framework.
