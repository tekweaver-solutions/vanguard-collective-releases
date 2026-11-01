#Requires -Version 5.1
<#
.SYNOPSIS
  Run an instrument, PERSIST its stdout and its TALLY beside the run, and hand back the parsed
  tally. The ONE shared definition, dot-sourced by the runner (tools/lam/mission-dispatch.ps1)
  and by the goal evaluator's instrument_exit0 detector (tools/lam/mission-goal-check.ps1).

.DESCRIPTION
  TWO PROBLEMS, EACH THE OTHER'S HALF: A TALLY GUESSED FROM AN EXIT CODE, AND A RUN WITH NO RECORD.

  The first: mission-dispatch.ps1 synthesized the anchors' suite.passed / failed / skipped from the
  suite's EXIT CODE -- 1/0/0 or 0/1/0 -- reading neither the instrument's own TALLY line nor its
  PASS/FAIL member lines, and then discarded the suite's stdout. Every *.anchors.yaml file written
  that way carries that shape and not one of them carries a real tally: an anchors file could bank
  passed: 1 for a run whose own handoff records a product suite of thousands of tests passing.

  The second: mission-goal-check.ps1's instrument_exit0 detector runs the same instrument as
  $null = and keeps only $LASTEXITCODE. A detector that runs for minutes and executes a product
  suite of thousands of tests can therefore fail and leave no member name, no tally, no pytest output
  -- nothing a later reader can refute. That can happen: several goal readings at one HEAD, one
  of them NOT_MET, and the failing run's reason not on disk anywhere.

  THE CURE IS ONE FUNCTION BOTH CALLERS USE, so the persisted transcript and whatever an artifact
  says about the run cannot come from two different readings of it.

  THE CONTRACT, and every clause of it is a thing that would otherwise break a caller:

  (a) THE EXIT CODE IS THE CONTRACT. Save-LamInstrumentRun sets $LASTEXITCODE to the instrument's
      exit code and runs NOTHING NATIVE afterwards -- the detector reads the ambient value on its
      very next line, and a git or uv call in here would silently overwrite the verdict input.
      WriteAllText, New-Item, Join-Path, SHA256 and regex are .NET or cmdlet calls, not native
      processes, and do not touch it. The value is ALSO re-asserted explicitly before the return,
      so the guarantee does not rest on that reasoning alone.

  (b) IT MUST NOT THROW. A throw propagates to the detector's per-detector catch and turns a GREEN
      instrument into a FAILED detector -- the cure causing the class of failure it was written to
      make legible. An unwritable output directory degrades to persisted = false with a reason;
      it never degrades to a verdict. PERSISTENCE IS A SIDE EFFECT.

  (c) THE MIXED PIPELINE IS FLATTENED BEFORE ANYTHING READS IT. powershell ... 2>&1 yields both
      System.String and ErrorRecord, and ONE item can carry embedded newlines, so a FAILED line
      or a TALLY line can arrive inside a multi-line chunk and be invisible to a per-item match.
      The house idiom is the one mission-goal-check.ps1's verify_pass_or_dib detector applies to
      verify's output: every item rendered as a string, the items joined with a bare LF.

  (d) TWO READERS OF ONE RUN CANNOT DISAGREE. The TALLY is matched ANCHORED AT COLUMN 0 under
      RegexOptions Multiline; the FAILED ids are mined with EXACTLY the runner's own pattern,
      over the SAME flattened text that gets persisted.

  (e) UTF-8 WITHOUT BOM, because everything else in this tree is.

  (f) IDEMPOTENT AND BOUNDED: the two files are OVERWRITTEN IN PLACE, never appended. A store
      that only ever grows is the failure this clause rules out.

  (g) THE FILENAME IS DERIVABLE BY BOTH CALLERS from what each already holds, so neither has to be
      told it: Get-LamInstrumentRunPath is the one derivation.

  (h) THE CAPTURE STATES ITSELF. The private capture this
      helper replaced inside mission-goal-check.ps1 kept four things the first version of this
      file lost. All four are back:
      1. EVERY TALLY LINE. <base>.tally.txt keeps every column-0 TALLY line, in order. Its FIRST
         line is what it always was -- the first TALLY line, or NO-TALLY exit_code=<n> (or, since
         (h) 5 was added, the CHECKS record of (h) 5 where a count line was printed and no TALLY) -- and the
         further TALLY lines follow it, bounded at 64 with a BOUND line saying so when the bound
         is hit. Each kept line is bounded in LENGTH as well: a TALLY line longer than 2048
         characters keeps its first 2048 (2047 rather than split a surrogate pair) and carries,
         on the same line, a bracketed TRUNCATED note stating its true length. So the tally file's
         size is bounded, not only its line count, and its first line is what it always was for
         every TALLY line inside that bound. The whole line stays in the stdout file's verbatim
         body, and fields and tally_line are still read from the whole first line. The grammar is
         contract (d)'s, column 0: NOT the private capture's leading-whitespace 'TALLY passed='
         grammar, so an indented or mid-line TALLY still does not count. fields and tally_line
         remain the FIRST line's, so no anchors figure moves.
      2. A PROVENANCE HEADER. <base>.stdout.txt opens with writer, capture_format, run_key, goal,
         detector_ordinal, instrument (as given), cwd, captured_at (UTC, from .NET), ran,
         exit_code, tally_count, body_bytes and body_sha256 -- and, after them, the five keys of (i)
         and, where the caller bound a list, the one key of (j) -- then the instrument's output VERBATIM
         between two delimiter lines. Every control character in a header value -- CR and LF
         included -- becomes a space, so no RunKey or Goal can forge a column-0 TALLY or FAILED
         line in either file. detector_ordinal is DERIVED, never passed: it is read back from
         run_key under mission-goal-check.ps1's own RunKey fold (Get-LamCaptureDetectorOrdinal
         below states the fold), its value says DERIVED, and for any run_key outside that fold it
         says 'not derivable' rather than guess. The runner passes no goal, so its captures always
         say 'not derivable'.
         HOW A READER SPLITS THE FILE. The header is every line BEFORE the FIRST line that is
         exactly '--- instrument stdout and stderr, verbatim ---'. Read header keys from there and
         nowhere else, one 'key: value' per line: the body is the instrument's, and it can print
         any line at all, both delimiter lines, 'exit_code: 0' and an EXIT line included. The body
         starts on the line after that first delimiter. When body_bytes is above 0 the body is
         exactly body_bytes bytes of UTF-8, followed by one LF, the closing line
         '--- end of instrument output ---' and its LF, which end the file. Cut the body by that
         count, or at the file's LAST closing line; never at the first closing line found.
      3. NEVER A ZERO-BYTE BODY, AND THE HEADER TELLS SILENCE FROM SPEECH. body_bytes counts the
         instrument's flattened output. When it is above 0, everything between the delimiters is
         the instrument's own, including any sentence it chose to print. When it is 0, the
         flattened output is empty, and the helper writes ONE sentence of its own between the
         delimiters, saying which of two things happened: the instrument printed nothing at all
         ('It was run and it said nothing'), or it printed exactly one empty line, which flattens
         to no text and is recorded as an empty line, not as a silence. A reader therefore tests
         the header's column-0 body_bytes, read under the splitting rule above, and reads the
         sentence only when body_bytes is 0. A test for the sentence alone is forgeable by any
         instrument that prints it, and a file-length test is vacuous, since the header alone is
         hundreds of bytes.
      4. THE EXIT CODE BESIDE THE TALLY. <base>.tally.txt always ENDS with
         EXIT exit_code=<n> ran=<bool> tally_count=<k> captured_at=<UTC>, carrying the
         instrument's OWN exit code -- never a pytest_exit= its TALLY happened to print. The line
         cannot begin TALLY, FAILED or NO-TALLY, and its captured_at is the stdout header's, so
         the two files of one run can be paired and a stale file of another key told apart.
      WHAT A PLANTED REVERT OF EACH LINE REMOVES. Each guarantee rests on one line of
      Save-LamInstrumentRun, but the lines are not independent, and this is what each one's revert
      really removes. The loop that adds the second and later TALLY lines: those lines only; line
      1 and the EXIT line stay. The line that joins the header to the body: the whole header, which
      is all of guarantee 2, detector_ordinal included, AND the numeric half of guarantee 3, AND
      the header that guarantee 4's captured_at pairs with. Under that revert a silent capture and
      a capture whose instrument printed exactly the silence sentence are byte-identical, and the
      EXIT line pairs with nothing. The line that puts the sentence in an empty body: the sentence
      only, leaving body_bytes: 0 and an empty body. The line that writes the EXIT line: the EXIT
      line only, leaving exit_code in the header. The detector_ordinal line, the one-empty-line
      line and the TALLY length bound each remove only their own statement.
      WHAT A READER OF THE RETURN OBJECT MUST KNOW: stdout_sha256 and stdout_bytes measure the file
      AS WRITTEN, header included, so two identical runs no longer hash equal (captured_at moves).
      body_sha256 and body_bytes measure the instrument's own output. tally_lines (bounded in
      length exactly as in the file) and tally_count are guarantee 1 in memory. failed_ids,
      fields and tally_line are mined from the body alone, first TALLY wins, exactly as before.
      5. THE INSTRUMENTS' OWN COUNT LINE. The six LAM instruments print no
         TALLY; each ends on its own summary line, and before this clause every tally file of an
         acceptance run read NO-TALLY beside a stdout that said how many checks passed. The three
         forms are read from the instruments' code (ConvertFrom-LamInstrumentChecksLine states
         them) and recorded as ONE line beginning CHECKS: instrument, result
         (passed / FAILED / passed_with_skips), checks, passed, failed, skipped, lines (how many
         count lines the output carried; the LAST is the one read) and exit_code_agrees. With no
         TALLY it is the tally file's first line; with a TALLY it follows the TALLY lines. NO-TALLY
         exit_code=<n> remains the first line of a stdout that carries NEITHER, byte for byte.
         The return object gains checks_found, checks_line, checks and checks_count. tally_found,
         tally_line, fields, tally_lines and tally_count are the TALLY grammar's as before, so a
         caller that banks them -- the runner's anchors -- sees no figure move.

  (i) THE CAPTURE SAYS WHAT IT WAS TAKEN ON. After every key that was there the
      stdout header carries head, tree_clean, tree_reason, instrument_sha256 and
      instrument_resolved, read BEFORE the instrument is launched (Get-LamCaptureProvenance states
      each). capture_format stays 1. The return object carries the same five. head and tree_clean
      are about -MissionRoot and are read only where it is the top level of a git repository;
      instrument_resolved is the file the child runs, and its sha256 is that file's. They exist so that mission-goal-check.ps1's
      instrument_exit0 detector can refuse to reuse a reading it cannot tie to the tree in front
      of it; nothing in this file decides anything from them.

  (j) ... AND, WHERE THE CALLER SAYS WHAT IS NOT AN INPUT, THE INPUT TREE IT STOOD ON.
      Save-LamInstrumentRun takes a FIFTH
      parameter, -InstrumentInputsExcept <string[]>: repository-relative paths that are NOT inputs of
      the instrument. ONLY WHEN IT IS BOUND the header carries a NINETEENTH key, after
      instrument_resolved and last: `input_tree: <64 hex>`, or `input_tree: not derivable (<why>)`
      -- the line is written either way, and the capture is taken either way. The figure is
      Get-LamInputTree's, over the head the provenance read has just stated, BEFORE the launch
      (contract (a)): the sha256 of that head's tree entries less the listed paths AND OF THE LIST
      ITSELF, so a figure binds the list it was taken under -- two captures of one head taken
      under two lists carry two figures (the function's own comment says why).
      The return object carries input_tree as well: that value, and '' where the
      parameter is not bound. WITH THE PARAMETER NOT BOUND THE CAPTURE IS WHAT IT WAS, the eighteen
      keys and no other, byte for byte but for the clock: no other caller's capture moves.
      capture_format stays 1 -- a reader that wants the key treats its absence as "not taken under
      a list". As with (i), nothing in this file decides anything from it.

  WHERE IT WRITES, AND WHY NOT BESIDE THE VERDICT. The one ignore rule written for .mission/goals/
  is the verdict glob, /.mission/goals/*.verdict.yaml, so a capture there would be an undeclared
  '?? .mission/goals/<file>' porcelain line. The clean-tree gate is Assert-CleanWorkingTree in
  tools/mission-lib.ps1, and the lifecycle commands that gate on it run it unless -NoCommit:
  close-milestone, reclose, reopen, spec-bump, promote-contract, ledger-append, green-gate-seed
  and prune-objects. Not every lifecycle command gates: mission-reclaim commits the whole .mission
  directory with no clean-tree gate at all. The gate carries
  NO code exemption: a line passes only if the WHOLE line, status code included,
  begins with an entry the mission DECLARES under admitted_porcelain in .mission/mission.yaml (the
  declaration read by Get-LamDeclaredAdmittedPorcelain and the porcelain by Get-LamPorcelainState,
  both in tools/lam/lam-verify-admission.ps1), or its path is named exactly in the caller's
  -AllowPaths. A failing git status refuses. No declared entry begins '?? .mission/goals/', so that
  line would refuse every gated command, close included, and spec-accept's Assert-CleanGitTree
  exempts no .mission/goals/ path either.
  WHAT THE GATE JUDGES, AND WHAT IT DOES NOT. It judges the porcelain git status prints under
  git's default index flags, excludes and status configuration. Under those defaults a capture
  there is admitted only by something committed -- a declaration line, or an ignore rule in a
  committed .gitignore -- and an uncommitted widening of the declaration is itself a line such as
  ' M .mission/mission.yaml', which no declaration can admit (every entry must begin '?? ') and no
  gated command's -AllowPaths (at most its amendment file) names. Outside those defaults the gate
  is NOT closed. These routes admit a .mission/goals/ capture with nothing committed and nothing
  in the porcelain: skip-worktree or assume-unchanged set on .mission/mission.yaml, so that an
  uncommitted widening prints no porcelain line; an entry in .git/info/exclude or in the file
  core.excludesFile names; and status.showUntrackedFiles=no, because the porcelain is read
  without pinning --untracked-files. Each of these is local index or configuration state, and the
  gate does not see it. So a widening CAN happen quietly, and the home does not rest on the gate
  being closed: it is <MissionRoot>/.mission-runtime/lam/instrument-runs/, ignored whole by the
  .mission-runtime/ rule.

  THE RESIDUAL, DISCLOSED AND NOT RESOLVED: a gitignored home is NOT durable evidence. These files
  do not survive a fresh clone, are not bound by any sha256 on a gate, and nothing stops a later
  run of the same key from overwriting them. That is strictly more than the nothing that stood
  here before, and strictly less than evidence. Where the record must be durable it is the
  anchors artifact that carries it -- which is why the runner also writes the tally INTO the
  anchors rather than merely pointing at this file. The detector has no artifact of its own to
  write into, so for it this file is the whole of the improvement. THAT REMAINS AN OPEN DECISION.
#>

# ------------------------------------------------------------------------------------------------
# THE FILENAME DERIVATION -- one definition, so both callers compute the same name from what they
# already hold. The runner holds a dispatch id; the detector holds a goal name. Neither is reported
# back to the other.
# ------------------------------------------------------------------------------------------------
function ConvertTo-LamRunToken {
    param([string]$Text)
    # A FILENAME SEGMENT, not a path: every separator and every shell metacharacter collapses to a
    # dash. A goal name or a dispatch id that contained a slash would otherwise choose a directory.
    $t = ([string]$Text) -replace '[^A-Za-z0-9._-]', '-'
    if ($t.Length -gt 80) { $t = $t.Substring(0, 80) }
    if (-not $t) { $t = 'x' }
    return $t
}

function Get-LamInstrumentRunPath {
    param(
        [string]$MissionRoot,
        [string]$InstrumentPath,
        [string]$RunKey = '',
        [string]$Goal = ''
    )
    # RunKey wins, Goal is the fallback, and 'run' is the floor -- so a caller that passes neither
    # still gets a stable name rather than a crash or an empty one.
    $key = [string]$RunKey
    if (-not $key) { $key = [string]$Goal }
    if (-not $key) { $key = 'run' }
    $leaf = ''
    try { $leaf = [System.IO.Path]::GetFileNameWithoutExtension([string]$InstrumentPath) } catch { $leaf = '' }
    if (-not $leaf) { $leaf = 'instrument' }
    $base = (ConvertTo-LamRunToken $key) + '.' + (ConvertTo-LamRunToken $leaf)
    $dir  = Join-Path ([string]$MissionRoot) '.mission-runtime\lam\instrument-runs'
    return [pscustomobject]@{
        dir    = $dir
        base   = $base
        stdout = (Join-Path $dir ($base + '.stdout.txt'))
        tally  = (Join-Path $dir ($base + '.tally.txt'))
    }
}

# ------------------------------------------------------------------------------------------------
# THE TALLY GRAMMAR, READ AND NOT GUESSED. A product-suite instrument emits exactly one
# line of the form (the figures here are illustrative):
#   TALLY passed=120 failed=0 skipped=3 deselected=2 runnable=123 stored_floor=100 \
#         collection_error=False pytest_exit=0 elapsed_seconds=42
# The parser is GENERIC over key=value pairs rather than positional, because the whole point
# is that whatever the instrument chose to measure is what should survive -- a positional reader
# would silently drop the next field someone adds.
#
# EVERY MATCH IS COUNTED AND THE FIRST 64 ARE KEPT (contract (h) 1), but fields and line stay the
# FIRST match's: an instrument that prints a second TALLY does not get to move the figures a
# caller already banks from the first.
# ------------------------------------------------------------------------------------------------
function ConvertTo-LamBoundedTallyLine {
    # A KEPT LINE CUT TO ITS BOUND, AND SAYING SO ON THE SAME LINE (contract (h) 1). The note has
    # no '=' in it, so a key=value reader of the kept line picks up no pair from the note; what it
    # can pick up is a pair cut short at the bound, which is why the note states the true length
    # and where the whole line is.
    param([string]$Line, [int]$Max)
    if ($Line.Length -le $Max) { return $Line }
    $cut = $Max
    # Never between the two halves of a surrogate pair: UTF-8 would write the lone half as a
    # replacement character, which is a byte the instrument never printed.
    if ([char]::IsHighSurrogate($Line[$cut - 1])) { $cut = $cut - 1 }
    return ($Line.Substring(0, $cut) + ' [TRUNCATED by lam-instrument-run: this TALLY line is ' +
            [string]$Line.Length + ' characters and only the first ' + [string]$cut +
            ' are kept here; the whole line is in the stdout file''s verbatim body]')
}

function ConvertFrom-LamInstrumentTally {
    param([string]$Text)
    $res = [pscustomobject]@{
        found  = $false
        line   = ''
        fields = [ordered]@{}
        lines  = [string[]]@()
        count  = 0
    }
    if (-not $Text) { return $res }
    # ANCHORED AT COLUMN 0, MULTILINE. Without (?m) the anchor means start-of-STRING and the line
    # is never found in a transcript; without the anchor, a line that merely MENTIONS a tally --
    # a comment, a quoted example, an echoed command -- is read as the measurement itself.
    $all = [regex]::Matches($Text, '(?m)^TALLY[ \t]+(.+?)[ \t\r]*$')
    if ($all.Count -eq 0) { return $res }
    $res.count = $all.Count
    $kept = New-Object System.Collections.Generic.List[string]
    $lamTallyLineMax = 2048
    foreach ($tm in $all) {
        # BOUNDED, for the same reason the pairs below are: a transcript must not be able to grow
        # the tally file without limit. The count above is still the TRUE count. The bound is on
        # BOTH axes: at most 64 lines, and each kept line at most $lamTallyLineMax characters plus
        # the note that says it was cut -- a line count alone would let one line be a megabyte.
        if ($kept.Count -ge 64) { break }
        $keptLine = 'TALLY ' + $tm.Groups[1].Value
        if ($keptLine.Length -gt $lamTallyLineMax) { $keptLine = ConvertTo-LamBoundedTallyLine -Line $keptLine -Max $lamTallyLineMax }
        [void]$kept.Add($keptLine)
    }
    $res.lines = $kept.ToArray()
    $m = $all[0]
    $res.found = $true
    $res.line  = 'TALLY ' + $m.Groups[1].Value
    $pairs = @(($m.Groups[1].Value -split '\s+') | Where-Object { $_ })
    $taken = 0
    foreach ($pair in $pairs) {
        # BOUNDED: a garbled or hostile instrument printing a thousand pairs must not be able to
        # grow an artifact without limit. Twenty-four is four more than the grammar above carries.
        if ($taken -ge 24) { break }
        $eq = $pair.IndexOf('=')
        if ($eq -lt 1) { continue }
        $tkey = $pair.Substring(0, $eq)
        $tval = $pair.Substring($eq + 1)
        # A KEY IS AN IDENTIFIER OR IT IS NOT A KEY. Anything else is how a transcript gets to
        # choose what an artifact's YAML says.
        if ($tkey -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }
        if ($res.fields.Contains($tkey)) { continue }
        $res.fields[$tkey] = $tval
        $taken++
    }
    return $res
}

# ------------------------------------------------------------------------------------------------
# THE INSTRUMENTS' OWN COUNT LINE, READ FROM THEIR CODE AND NOT GUESSED (contract
# (h) 5). The six LAM instruments print no TALLY: each ends on a summary line of its own, written
# with Write-Host and ONE LEADING SPACE (tests/lam/instrument-WP-1.ps1 .. instrument-WP-6.ps1, the
# lines above each file's `EXIT:` line). There are THREE forms -- passed, FAILED (which WP-3 may
# close with a skip count) and WP-3's passed-with-skips -- and only these are read:
#    WP-<n>: all <N> checks passed.                                        (all six)
#    WP-<n>: <F> of <N> checks FAILED.                                     (all six)
#    WP-<n>: <F> of <N> checks FAILED.  (<K> SKIPPED.)                     (WP-3, a skip beside a failure)
#    WP-<n>: <P> of <N> checks passed, <K> SKIPPED -- a skip is not a pass; see the [SKIP] line(s) above.
#                                                                          (WP-3, no failure and a skip)
# ANCHORED AS THE INSTRUMENTS PRINT IT: column 0, exactly one space, the whole line, case as
# written. A line indented further, a line that merely quotes one, and WP-6's column-0 refusal
# `WP-6: the gate-class map is missing ...` are not count lines. EVERY MATCH IS COUNTED AND THE
# LAST ONE IS THE LINE: an instrument prints its summary last, so text it echoed earlier -- a
# fixture's own output, a nested run -- does not become its count. This is the opposite of the
# TALLY rule (first wins) and it is so on purpose: a TALLY is one measurement an instrument banks,
# a count line is the instrument's closing statement.
# IT DECIDES NOTHING. fields, tally_line and tally_found stay the TALLY grammar's alone, so no
# anchors figure the runner banks moves; the exit code stays the contract.
# ------------------------------------------------------------------------------------------------
function ConvertFrom-LamInstrumentChecksLine {
    param([string]$Text)
    $res = [pscustomobject]@{
        found  = $false
        line   = ''
        fields = [ordered]@{}
        count  = 0
    }
    if (-not $Text) { return $res }
    $lamForms = @(
        @{ result = 'passed';            rx = '(?m)^ WP-(?<wp>[0-9]{1,3}): all (?<n>[0-9]{1,9}) checks passed\.\r?$' },
        @{ result = 'FAILED';            rx = '(?m)^ WP-(?<wp>[0-9]{1,3}): (?<f>[0-9]{1,9}) of (?<n>[0-9]{1,9}) checks FAILED\.(?:  \((?<s>[0-9]{1,9}) SKIPPED\.\))?\r?$' },
        @{ result = 'passed_with_skips'; rx = '(?m)^ WP-(?<wp>[0-9]{1,3}): (?<p>[0-9]{1,9}) of (?<n>[0-9]{1,9}) checks passed, (?<s>[0-9]{1,9}) SKIPPED -- a skip is not a pass; see the \[SKIP\] line\(s\) above\.\r?$' }
    )
    $lamBest = $null
    $lamBestAt = -1
    $lamBestResult = ''
    foreach ($lamForm in $lamForms) {
        foreach ($lamHit in [regex]::Matches($Text, [string]$lamForm.rx)) {
            $res.count++
            if ($lamHit.Index -gt $lamBestAt) { $lamBest = $lamHit; $lamBestAt = $lamHit.Index; $lamBestResult = [string]$lamForm.result }
        }
    }
    if ($null -eq $lamBest) { return $res }
    # ...AND ITS NUMBERS MUST BE AN INSTRUMENT'S. A FAILED line counts at least one failure, and
    # failures and skips together never exceed the checks; a skip line's passes and skips ARE the
    # checks, with at least one skip. No instrument can print a line that breaks these (each
    # computes its line from its own counters), so a line that does is not an instrument's: nothing
    # is read from it and the stdout is treated as carrying no count line at all.
    $lamTotal = [int]$lamBest.Groups['n'].Value
    if ($lamBestResult -eq 'FAILED') {
        $lamF = [int]$lamBest.Groups['f'].Value
        $lamS = 0
        if ($lamBest.Groups['s'].Success) { $lamS = [int]$lamBest.Groups['s'].Value }
        if (($lamF -lt 1) -or (($lamF + $lamS) -gt $lamTotal)) { $res.count = 0; return $res }
    } elseif ($lamBestResult -eq 'passed_with_skips') {
        $lamP = [int]$lamBest.Groups['p'].Value
        $lamS = [int]$lamBest.Groups['s'].Value
        if (($lamS -lt 1) -or (($lamP + $lamS) -ne $lamTotal)) { $res.count = 0; return $res }
    }
    $lamChecks = [int]$lamBest.Groups['n'].Value
    $lamPassed = 0
    $lamFailed = 0
    $lamSkipped = 0
    if ($lamBestResult -eq 'passed') { $lamPassed = $lamChecks }
    elseif ($lamBestResult -eq 'FAILED') {
        $lamFailed = [int]$lamBest.Groups['f'].Value
        if ($lamBest.Groups['s'].Success) { $lamSkipped = [int]$lamBest.Groups['s'].Value }
        $lamPassed = $lamChecks - $lamFailed - $lamSkipped
    } else {
        $lamPassed = [int]$lamBest.Groups['p'].Value
        $lamSkipped = [int]$lamBest.Groups['s'].Value
    }
    $res.found = $true
    $res.line  = $lamBest.Value.Trim()
    $res.fields['instrument'] = 'WP-' + $lamBest.Groups['wp'].Value
    $res.fields['result']     = $lamBestResult
    $res.fields['checks']     = [string]$lamChecks
    $res.fields['passed']     = [string]$lamPassed
    $res.fields['failed']     = [string]$lamFailed
    $res.fields['skipped']    = [string]$lamSkipped
    return $res
}

# ------------------------------------------------------------------------------------------------
# ONE LINE OR IT IS NOT A HEADER VALUE (contract (h) 2). RunKey and Goal are token-sanitised only
# for the FILENAME; what goes INTO the file is the caller's text, and a Goal carrying a newline and
# 'TALLY passed=999' would otherwise put a forged column-0 TALLY line in the capture. Every control
# character, and the three Unicode line separators a reader might split on, becomes a space.
# ------------------------------------------------------------------------------------------------
function ConvertTo-LamCaptureHeaderValue {
    param([string]$Text)
    # The three separators are built from their code points so this file stays pure ASCII: PS 5.1
    # reads a BOM-less script as CP1252, and a literal U+2028 here would not survive that read.
    $lamLineSeps = [string][char]0x0085 + [string][char]0x2028 + [string][char]0x2029
    return (([string]$Text) -replace ('[\x00-\x1F\x7F' + $lamLineSeps + ']'), ' ')
}

# ------------------------------------------------------------------------------------------------
# THE DETECTOR ORDINAL, DERIVED AND LABELLED SO (contract (h) 2). The capture's provenance
# guarantee has every capture restate its own ordinal, and this helper takes no ordinal parameter:
# the one caller that has ordinals, mission-goal-check.ps1's instrument_exit0 detector, folds the
# ordinal into RunKey instead. THE FOLD, as that file builds it (read there, not re-decided here):
# one mission-goal-check.ps1 run evaluates one goal; a script-scope counter advances once for each
# instrument_exit0 detector that has a path and an instrument on disk -- a detector with no path, or
# whose instrument is not on disk, returns before the counter moves; one that then reuses a capture,
# refuses a key it declares or reads the engine down has moved it and never calls this helper -- and
# a detector that does call it passes
# RunKey = the goal when the counter is 1, and the goal + '.' + the counter when it is 2 or more.
# So the ordinal is read back from exactly those two shapes, compared ordinally and case-sensitively,
# as the fold builds them. ANY OTHER run_key IS NOT DERIVABLE AND SAYS SO: no goal, an empty
# run_key, goal.1, goal.02, goal.x, a trailing space or newline, a case variant of the goal, or a
# key that does not start with the goal. Nothing is guessed. The returned text is always one line
# of ASCII, so it needs no scrubbing on its way into the header.
# ------------------------------------------------------------------------------------------------
function Get-LamCaptureDetectorOrdinal {
    param([string]$RunKey = '', [string]$Goal = '')
    $lamFold = 'mission-goal-check.ps1''s RunKey fold'
    $rk = [string]$RunKey
    $gl = [string]$Goal
    if ($gl.Length -eq 0) {
        return ('not derivable (no goal was passed, and ' + $lamFold + ' is defined over a goal; no ordinal is guessed)')
    }
    if ([string]::Equals($rk, $gl, [System.StringComparison]::Ordinal)) {
        return ('1 (DERIVED from run_key, not passed by the caller: run_key equals goal, which is the key ' + $lamFold + ' gives its first instrument_exit0 detector)')
    }
    $lamStem = $gl + '.'
    if ($rk.StartsWith($lamStem, [System.StringComparison]::Ordinal)) {
        $lamN = $rk.Substring($lamStem.Length)
        # \z, not $: in .NET a $ also matches before a final newline, and 'goal.2' + LF is not a key
        # the fold writes.
        if (($lamN -cmatch '\A[1-9][0-9]*\z') -and ($lamN -cne '1')) {
            return ($lamN + ' (DERIVED from run_key, not passed by the caller: run_key is goal + .' + $lamN + ', which is the key ' + $lamFold + ' gives its instrument_exit0 detector number ' + $lamN + ')')
        }
    }
    return ('not derivable (run_key is neither goal nor goal.<n> for an n of 2 or more, the only two keys ' + $lamFold + ' writes; no ordinal is guessed)')
}

function Get-LamCaptureSha256 {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

# ------------------------------------------------------------------------------------------------
# WHAT THE RUN STOOD ON, READ BEFORE THE INSTRUMENT IS LAUNCHED (contract (i)).
# A reading can be reused by mission-goal-check.ps1's instrument_exit0 detector only if the capture
# says what it was taken on, and before contract (i) it did not: the header carried no HEAD and no
# measure of the instrument file. Three facts are read here, each by itself and each degrading to a
# 'not derivable' sentence rather than throwing (contract (b)):
#   head               `git -C <MissionRoot> rev-parse HEAD`, 40 hex
#   tree_clean         True / False / not derivable -- VERIFY'S OWN PREDICATE, never restated here:
#                      Test-LamAdvanceAdmission (tools/lam/lam-verify-admission.ps1) asked whether
#                      HEAD is an admitted advance from ITSELF, which holds exactly when the tree is
#                      clean apart from the porcelain set the mission declares (or the shared
#                      default) and its ledger declaration reads; tree_reason is that function's
#                      own sentence. Both callers dot-source that library before this file; a
#                      caller that did not (the operator's wrapper) gets it from beside this file,
#                      inside this function's scope only, and where it is not there the value says
#                      so and the capture is simply never reused.
#   instrument_sha256  sha256 of the instrument file's bytes as they are on disk
# NATIVE CALLS, AND WHY CONTRACT (a) STANDS: git runs here, and this function is called BEFORE the
# instrument, never after it -- the instrument's exit code is read on the line after its own call,
# and the last word is still the re-assertion at the end of Save-LamInstrumentRun.
# ------------------------------------------------------------------------------------------------
#   instrument_resolved  THE FILE THAT IS LAUNCHED, as a full path. A relative -InstrumentPath is run by
#                      the child against the POWERSHELL LOCATION, while a .NET file call would read it
#                      against the PROCESS working directory, and the two differ under Push-Location --
#                      the runner's own call shape, from a worker's worktree. So the path is resolved
#                      ONCE, against the PowerShell location, and THAT file is the one hashed: the
#                      sha256 is of the instrument that runs, never of a namesake elsewhere. A reader
#                      that reuses a capture holds this path equal to its own instrument's.
# WHAT head AND tree_clean ARE ABOUT, said because the runner passes a mission root its suite does
# not run in: they describe -MissionRoot, and ONLY where -MissionRoot is itself the top level of a
# git repository. Asked at a plain directory inside another repository -- an instrument's sandbox
# under a worktree's runtime plane is one -- git would answer for the ENCLOSING repository; that
# is refused here, head says so, and nothing more is asked. And the tree is asked with optional
# locks OFF (GIT_OPTIONAL_LOCKS=0, set and put back around the call), so reading a tree never takes
# its index lock.
$script:LamInstrumentRunHome = $PSScriptRoot
function Get-LamCaptureProvenance {
    param([string]$MissionRoot, [string]$InstrumentPath)
    $lamProv = [pscustomobject]@{
        head                = 'not derivable (not read)'
        tree_clean          = 'not derivable'
        tree_reason         = 'not read'
        instrument_sha256   = 'not derivable (not read)'
        instrument_resolved = 'not derivable (not read)'
    }
    try {
        $lamInstFull = [string]$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string]$InstrumentPath)
        $lamProv.instrument_resolved = $lamInstFull
        try { $lamProv.instrument_sha256 = Get-LamCaptureSha256 -Bytes ([System.IO.File]::ReadAllBytes($lamInstFull)) }
        catch { $lamProv.instrument_sha256 = 'not derivable (the instrument file could not be read)' }
    } catch {
        $lamProv.instrument_resolved = 'not derivable (the instrument path could not be resolved against the PowerShell location)'
        $lamProv.instrument_sha256 = 'not derivable (the instrument path could not be resolved)'
    }
    $lamProvEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lamLocksWas = $env:GIT_OPTIONAL_LOCKS
    try {
        $env:GIT_OPTIONAL_LOCKS = '0'
        # THE TOP LEVEL, FIRST: git must answer -MissionRoot itself, or nothing is asked of it.
        $lamTop = ''
        $lamTopExit = 1
        try {
            $lamTop = ("$(& git -C ([string]$MissionRoot) rev-parse --show-toplevel 2>&1)").Trim()
            $lamTopExit = $LASTEXITCODE
        } catch { $lamTop = ''; $lamTopExit = 1 }
        $lamTopIsRoot = $false
        if (($lamTopExit -eq 0) -and $lamTop) {
            try {
                $lamTopIsRoot = [string]::Equals([System.IO.Path]::GetFullPath($lamTop.Replace('/', '\')).TrimEnd('\'), [System.IO.Path]::GetFullPath([string]$MissionRoot).TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)
            } catch { $lamTopIsRoot = $false }
        }
        if (-not $lamTopIsRoot) {
            $lamProv.head = 'not derivable (the mission root is not the top level of a git repository, so no HEAD is read for it)'
            $lamProv.tree_reason = 'not read: no HEAD to ask verify''s predicate about'
            return $lamProv
        }
        $lamHead = ''
        $lamHeadExit = 1
        try {
            $lamHead = ("$(& git -C ([string]$MissionRoot) rev-parse HEAD 2>&1)").Trim()
            $lamHeadExit = $LASTEXITCODE
        } catch { $lamHead = ''; $lamHeadExit = 1 }
        if (($lamHeadExit -ne 0) -or ($lamHead -cnotmatch '\A[0-9a-f]{40}\z')) {
            $lamProv.head = 'not derivable (git rev-parse HEAD did not answer one 40-hex sha at the mission root)'
            $lamProv.tree_reason = 'not read: no HEAD to ask verify''s predicate about'
            return $lamProv
        }
        $lamProv.head = $lamHead
        try {
            if (-not (Get-Command -Name Test-LamAdvanceAdmission -CommandType Function -ErrorAction SilentlyContinue)) {
                # THE LIBRARY, FROM BESIDE THIS FILE, into this function's scope only. The home is the
                # file this function was DEFINED in -- no caller's scope can hide that -- and the
                # variable set at load is the fallback.
                $lamHome = ''
                try { $lamHome = [string](Split-Path -Parent ([string]$MyInvocation.MyCommand.ScriptBlock.File)) } catch { $lamHome = '' }
                if (-not $lamHome) { $lamHome = [string]$script:LamInstrumentRunHome }
                $lamAdmLib = ''
                if ($lamHome) { $lamAdmLib = Join-Path $lamHome 'lam-verify-admission.ps1' }
                if ($lamAdmLib -and (Test-Path -LiteralPath $lamAdmLib -PathType Leaf)) { . $lamAdmLib }
                elseif (-not $lamHome) { $lamProv.tree_reason = 'verify''s predicate (Test-LamAdvanceAdmission) is not loaded and this file''s own folder could not be derived' }
                else { $lamProv.tree_reason = 'verify''s predicate (Test-LamAdvanceAdmission) is not loaded and lam-verify-admission.ps1 is not beside this file' }
            }
            if (Get-Command -Name Test-LamAdvanceAdmission -CommandType Function -ErrorAction SilentlyContinue) {
                $lamAdm = Test-LamAdvanceAdmission -MissionRoot ([string]$MissionRoot) -RecordedHeadSha $lamHead
                # True ONLY for the head this capture states: the predicate reads HEAD again itself,
                # and a HEAD that moved between the two reads is not the one written above.
                $lamProv.tree_clean = [string]([bool]$lamAdm.admitted -and ([string]$lamAdm.current -ceq $lamHead))
                $lamProv.tree_reason = [string]$lamAdm.reason
            }
        } catch {
            $lamProv.tree_clean = 'not derivable'
            $lamProv.tree_reason = 'verify''s predicate threw: ' + [string]$_.Exception.Message
        }
    } finally {
        $env:GIT_OPTIONAL_LOCKS = $lamLocksWas
        $ErrorActionPreference = $lamProvEap
    }
    return $lamProv
}

# ------------------------------------------------------------------------------------------------
# THE INPUT TREE A HEAD HOLDS, LESS WHAT IS NOT AN INPUT (contract (j)).
# A capture is tied to a HEAD (contract (i)), and a
# commit that touches no input of the instrument -- a ledger line -- moved HEAD and cost a whole run of
# it. A goal may now say what is NOT an input, and a capture taken under that list carries this figure;
# mission-goal-check.ps1 reuses a capture at another head where its figure is HEAD's.
# ONE FUNCTION, HANDED THE HEAD, AND BOTH CALLERS USE IT: Save-LamInstrumentRun hands it the head the
# provenance read has just stated, the evaluator the head it has just read and proved the tree clean
# for. Neither reads HEAD a second time for it, so the figure is of the head beside it on both sides.
# WHAT IT READS, exactly: `git -C <MissionRoot> -c core.quotePath=true ls-tree <head40>` -- the head's
# ROOT tree -- and, for every directory that is a proper ancestor of an exclusion,
# `... ls-tree <head40>:<dir>`. Of each call: exit 0, and of its STDOUT lines alone (stderr is kept
# apart and never read) every one `<mode> <type> <oid><TAB><name>`; anything else is "not derivable".
# Git's own sentences are never parsed. The WORKING TREE IS NOT READ AT ALL: these are the ids of the
# objects that head stores, so line endings, a smudge, .gitattributes or core.autocrlf cannot enter,
# and two checkouts of one head give one figure. core.quotePath=true keeps every line ASCII.
# THE KEPT ENTRIES are every entry of the root tree, each ancestor directory of an exclusion replaced
# by its own entries (and so on down), each excluded path itself DROPPED; an entry's text is git's own
# line, its path the FULL path.
# THE FIGURE is the sha256, lower-case hex, of the UTF-8 text of TWO runs of lines, each line followed
# by LF: FIRST the kept entries, sorted by full path with an ORDINAL comparer (never by culture); THEN
# THE LIST ITSELF -- one line for each distinct exclusion as it was handed over, in ordinal order: the
# word `except`, a TAB, the path. (A kept entry opens with six octal digits, so no kept line can read
# as a line of the list, nor one of the list as an entry.)
# WHY THE LIST IS IN THE FIGURE: the kept entries do
# not say which list they were kept under. Without it a capture taken under a WIDER list is admitted
# under a narrower one once a commit removes the path the narrower list did not exclude -- the two trees
# then keep the same entries, and the reading was taken while an input of the narrower list stood that
# has since been removed. With it, two figures are equal only where the kept entries AND the list are.
# NOT DERIVABLE -- ok = $false, figure = '', why a sentence -- AND NEVER A GUESS, when: an exclusion
# names a path the head does not hold (it is never hashed as "absent": a misspelled `scr` would stand
# for `src` for ever) -- matched ORDINALLY, CASE-SENSITIVELY, against what git prints, so a case
# variant, a directory that is on disk and untracked, and THE PLAIN SPELLING of a name git prints
# QUOTED (a non-ASCII byte, a quote, a control character in it) are each "not a path of" the head; an
# ancestor of an exclusion is not a tree; an exclusion equals, or is an ancestor of, one of the three tracked files that decide what "the
# tree is clean" certifies -- .gitattributes (the bytes a checkout gets), .gitignore (what porcelain
# never prints) and .mission/mission.yaml (the admitted untracked prefixes): HEAD equality pinned all
# three, so no list may take one out of the figure -- and THIS ONE TEST FOLDS CASE:
# on a file system that folds case git reads its rules from a file the head tracks as `.GitIgnore`,
# and an exclusion spelled that way would otherwise match the head's entry and take it out; -Head is
# not 40 hex; no exclusion is given; or git does not answer.
# AND WHAT "AGAINST WHAT git PRINTS" ADMITS, stated: the
# match is with the line AS PRINTED. Handed git's OWN QUOTED SPELLING of such a name -- `"uni\303\251"`,
# the two quote marks and the backslashes part of the string handed over -- it matches the quoted line,
# and that entry IS excluded: ok is $true, and the figure is taken without it (measured for a directory
# of the root tree). Nothing is guessed there: the caller named, to the byte, a line git printed. But it
# is not "not a path of" the head, which an earlier reading of this rule said of every such name.
# (As the ANCESTOR of an exclusion, `"uni\303\251"/n.txt`, the quoted spelling excludes nothing: the
# directory is then asked of git by that spelling, `<head>:"uni\303\251"`, git holds no such path and
# does not answer, and the figure is "not derivable" -- measured too.)
# THE EVALUATOR NEVER HANDS ONE OVER: git quotes a name by writing a backslash before what it escapes, and
# the evaluator's item rule (Get-GoalInputsExceptFault, in mission-goal-check.ps1) refuses an item that
# holds a backslash -- "it holds one of the characters [ ] \ : * ?" -- before a list reaches this
# function by either of its two roads, the reuse decision and -InstrumentInputsExcept. Only a direct
# caller of this helper can hand that spelling in.
# WHAT THE FIGURE DOES NOT SEE, stated because it is the whole of the risk it adds:
#   IT COMPARES ENDPOINTS, NOT HISTORY (by design: there is no history condition). HEAD equality proved that no
#   commit lay between a capture and an evaluation; two equal figures prove only that the two heads
#   store the same objects outside the list, under the same list. A change to an input and its revert,
#   both committed between them with nothing evaluated between, is not seen.
#   IT IS BLIND WHERE VERIFY'S PREDICATE IS BLIND, and it is on the same side of it: it reads the head's
#   tree and never the working tree, so "the tree is clean" is still asked of verify's predicate by
#   each caller, and what that predicate does not see -- a file edited under skip-worktree or
#   assume-unchanged, every ignored file, the untracked files under an admitted prefix, and the state
#   no tree holds (.git/info/exclude, a global excludes file, status.showUntrackedFiles,
#   core.autocrlf) -- this does not see either.
# WHERE IT MAY BE ASKED: of a -MissionRoot that is the top level of its repository, which is the only
# place either caller has a head to hand it (each reads a head there and nowhere else). Asked from a
# directory below one, git would answer for that directory and not for the head's root tree; no
# caller does, and nothing here checks it.
# IT NEVER THROWS, under 'Stop' or 'Continue' (contract (b)): its git calls are guarded as the
# provenance read's are, and a throw is a "not derivable" sentence. NATIVE CALLS, AND CONTRACT (a):
# git runs here, and both callers call this BEFORE any instrument is launched, never after one.
# Returns ok, figure, why and entries (the lines the figure is the sha256 of, in its order: the kept
# entries, then the list's `except` lines).
# ------------------------------------------------------------------------------------------------
function Get-LamInputTree {
    param([string]$MissionRoot, [string]$Head, [string[]]$Except)
    $lamTree = [pscustomobject]@{ ok = $false; figure = ''; why = ''; entries = [string[]]@() }
    $lamTreeEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lamTreeLocksWas = $env:GIT_OPTIONAL_LOCKS
    try {
        $env:GIT_OPTIONAL_LOCKS = '0'
        $lamTreeHead = [string]$Head
        if ($lamTreeHead -cnotmatch '\A[0-9a-f]{40}\z') { $lamTree.why = 'the head handed over is not a 40-hex commit id, so no tree is read'; return $lamTree }
        if (-not ([string]$MissionRoot)) { $lamTree.why = 'no mission root was handed over, so no tree is read'; return $lamTree }
        $lamTreeOrdinal = [System.StringComparer]::Ordinal
        $lamTreeExcept = New-Object 'System.Collections.Generic.HashSet[string]' ($lamTreeOrdinal)
        foreach ($lamTreeGiven in @($Except)) { if (($null -ne $lamTreeGiven) -and (([string]$lamTreeGiven).Length -gt 0)) { [void]$lamTreeExcept.Add([string]$lamTreeGiven) } }
        if ($lamTreeExcept.Count -eq 0) { $lamTree.why = 'no excluded path was given, so there is no list to take a figure under'; return $lamTree }
        # THE THREE FILES THAT DEFINE "CLEAN" STAY IN THE FIGURE, asked before git is: no list takes one out,
        # IN ANY CASE -- the one comparison here that folds case (an exclusion spelled `.GitIgnore` names
        # the ignore file wherever the head tracks it so, and git reads it on a file system that folds case).
        foreach ($lamTreePath in $lamTreeExcept) {
            foreach ($lamTreeFixed in @('.gitattributes', '.gitignore', '.mission/mission.yaml')) {
                if ([string]::Equals($lamTreeFixed, $lamTreePath, [System.StringComparison]::OrdinalIgnoreCase) -or $lamTreeFixed.StartsWith(($lamTreePath + '/'), [System.StringComparison]::OrdinalIgnoreCase)) {
                    $lamTree.why = "the exclusion '" + $lamTreePath + "' would take '" + $lamTreeFixed + "' out of the figure"
                    return $lamTree
                }
            }
        }
        # THE TREES, each read ONCE and only when an exclusion leads into it: '' is the head's root tree, any
        # other key a directory that is a proper ancestor of an exclusion. A directory is opened only after
        # its own name was found, exactly, as a tree entry of its parent -- so nothing reaches git's command
        # line but the 40 hex and names found among the lines git itself printed: printed PLAINLY, for
        # every list the evaluator hands over (the block above says why, and what a direct caller that
        # hands git's quoted spelling of an ancestor gets: that spelling after `<head>:`, and no answer).
        $lamTreeRead = New-Object 'System.Collections.Generic.Dictionary[string,object]' ($lamTreeOrdinal)
        foreach ($lamTreePath in $lamTreeExcept) {
            $lamTreeSegments = @($lamTreePath.Split('/'))
            $lamTreeDir = ''
            for ($lamTreeAt = 0; $lamTreeAt -lt $lamTreeSegments.Count; $lamTreeAt++) {
                if (-not $lamTreeRead.ContainsKey($lamTreeDir)) {
                    $lamTreeSpec = if ($lamTreeDir) { $lamTreeHead + ':' + $lamTreeDir } else { $lamTreeHead }
                    $lamTreeOut = @(& git -C ([string]$MissionRoot) -c core.quotePath=true ls-tree $lamTreeSpec 2>&1)
                    $lamTreeExit = $LASTEXITCODE
                    if ($lamTreeExit -ne 0) { $lamTree.why = 'git ls-tree ' + $lamTreeSpec + ' did not answer (exit ' + [string]$lamTreeExit + ')'; return $lamTree }
                    $lamTreeNames = New-Object 'System.Collections.Generic.Dictionary[string,object]' ($lamTreeOrdinal)
                    foreach ($lamTreeLine in $lamTreeOut) {
                        # STDOUT LINES ONLY: what git wrote to stderr arrives here as error records, and is not read.
                        if ($lamTreeLine -is [System.Management.Automation.ErrorRecord]) { continue }
                        $lamTreeMatch = [regex]::Match([string]$lamTreeLine, '\A([0-7]{6} (blob|tree|commit) [0-9a-f]{40}\t)(.+)\z')
                        if (-not $lamTreeMatch.Success) { $lamTree.why = 'git ls-tree ' + $lamTreeSpec + ' printed a line that is not a tree entry'; return $lamTree }
                        $lamTreeNames[$lamTreeMatch.Groups[3].Value] = [pscustomobject]@{ lead = $lamTreeMatch.Groups[1].Value; type = $lamTreeMatch.Groups[2].Value }
                    }
                    $lamTreeRead[$lamTreeDir] = $lamTreeNames
                }
                $lamTreeSegment = [string]$lamTreeSegments[$lamTreeAt]
                if (-not $lamTreeRead[$lamTreeDir].ContainsKey($lamTreeSegment)) {
                    $lamTree.why = "the excluded path '" + $lamTreePath + "' is not a path of " + $lamTreeHead
                    return $lamTree
                }
                # A SEGMENT THAT IS NOT THE LAST IS AN ANCESTOR: it must be a tree, and it is the next one opened.
                if ($lamTreeAt -lt ($lamTreeSegments.Count - 1)) {
                    $lamTreeFound = $lamTreeRead[$lamTreeDir][$lamTreeSegment]
                    $lamTreeDir = if ($lamTreeDir) { $lamTreeDir + '/' + $lamTreeSegment } else { $lamTreeSegment }
                    if ([string]$lamTreeFound.type -cne 'tree') {
                        $lamTree.why = "the excluded path '" + $lamTreePath + "' lies under '" + $lamTreeDir + "', which is not a directory of " + $lamTreeHead
                        return $lamTree
                    }
                }
            }
        }
        # THE KEPT ENTRIES: from the root down, an excluded path dropped, an opened directory replaced by its
        # own entries, every other entry kept as git printed it with its full path. Sorted as they are added.
        $lamTreeKept = New-Object 'System.Collections.Generic.SortedDictionary[string,string]' ($lamTreeOrdinal)
        $lamTreeOpen = New-Object 'System.Collections.Generic.Stack[string]'
        $lamTreeOpen.Push('')
        while ($lamTreeOpen.Count -gt 0) {
            $lamTreeDir = $lamTreeOpen.Pop()
            foreach ($lamTreeName in @($lamTreeRead[$lamTreeDir].Keys)) {
                $lamTreeFull = if ($lamTreeDir) { $lamTreeDir + '/' + $lamTreeName } else { [string]$lamTreeName }
                if ($lamTreeExcept.Contains($lamTreeFull)) { continue }
                if ($lamTreeRead.ContainsKey($lamTreeFull)) { $lamTreeOpen.Push($lamTreeFull); continue }
                $lamTreeKept[$lamTreeFull] = [string]$lamTreeRead[$lamTreeDir][$lamTreeName].lead + $lamTreeFull
            }
        }
        # THE HASHED TEXT: the kept entries, and THEN THE LIST THEY WERE KEPT UNDER -- `except`, a TAB and the
        # path, one line for each distinct exclusion in ordinal order -- so that a figure taken under one
        # list is never equal to a figure taken under another over the same kept entries.
        $lamTreeHashed = New-Object System.Collections.Generic.List[string]
        foreach ($lamTreeEntry in $lamTreeKept.Values) { $lamTreeHashed.Add([string]$lamTreeEntry) }
        $lamTreeListed = [string[]]@($lamTreeExcept)
        [Array]::Sort($lamTreeListed, $lamTreeOrdinal)
        foreach ($lamTreeListedPath in $lamTreeListed) { $lamTreeHashed.Add('except' + "`t" + $lamTreeListedPath) }
        $lamTreeText = New-Object System.Text.StringBuilder
        foreach ($lamTreeEntry in $lamTreeHashed) { [void]$lamTreeText.Append($lamTreeEntry + "`n") }
        $lamTree.entries = [string[]]@($lamTreeHashed.ToArray())
        $lamTree.figure = Get-LamCaptureSha256 -Bytes ((New-Object System.Text.UTF8Encoding($false)).GetBytes($lamTreeText.ToString()))
        $lamTree.ok = $true
        return $lamTree
    } catch {
        $lamTree.ok = $false
        $lamTree.figure = ''
        $lamTree.entries = [string[]]@()
        $lamTree.why = 'the input tree could not be read (' + ((([string]$_.Exception.Message) -replace '[\r\n]+', ' ')) + ')'
        return $lamTree
    } finally {
        $env:GIT_OPTIONAL_LOCKS = $lamTreeLocksWas
        $ErrorActionPreference = $lamTreeEap
    }
}

# ------------------------------------------------------------------------------------------------
# THE ONE ENTRY POINT.
# ------------------------------------------------------------------------------------------------
function Save-LamInstrumentRun {
    param(
        [Parameter(Mandatory = $true)][string]$InstrumentPath,
        [Parameter(Mandatory = $true)][string]$MissionRoot,
        [string]$RunKey = '',
        [string]$Goal = '',
        # (j) WHAT IS NOT AN INPUT OF THE INSTRUMENT: repository-relative paths, forward
        # slashes. BOUND -- an empty list too -- the header gains input_tree; not bound, nothing moves.
        [string[]]$InstrumentInputsExcept
    )
    # BOUND, NOT "NON-EMPTY": what decides whether the nineteenth line is written is that the caller
    # passed the parameter, read here before anything else can assign the variable.
    $lamInputsBound = $PSBoundParameters.ContainsKey('InstrumentInputsExcept')

    $res = [pscustomobject]@{
        exit_code     = 1
        ran           = $false
        stdout        = ''
        tally_found   = $false
        tally_line    = ''
        fields        = [ordered]@{}
        failed_ids    = @()
        persisted     = $false
        persist_note  = ''
        stdout_path   = ''
        tally_path    = ''
        stdout_sha256 = ''
        stdout_bytes  = 0
        body_sha256   = ''
        body_bytes    = 0
        tally_lines   = [string[]]@()
        tally_count   = 0
        # ADDITIVE (contracts (h) 5 and (i)). No field above changes its name or its meaning.
        checks_found  = $false
        checks_line   = ''
        checks        = [ordered]@{}
        checks_count  = 0
        head              = ''
        tree_clean        = ''
        tree_reason       = ''
        instrument_sha256 = ''
        instrument_resolved = ''
        # ADDITIVE (contract (j)): the header's input_tree value where the caller bound
        # -InstrumentInputsExcept -- the figure, or the "not derivable (...)" sentence -- and '' where not.
        input_tree = ''
    }

    # (i) WHAT THE RUN STANDS ON, READ BEFORE THE INSTRUMENT IS LAUNCHED AND NEVER AFTER IT
    # (contract (a)). It cannot throw; every part of it degrades to a sentence.
    try {
        $lamProvenance = Get-LamCaptureProvenance -MissionRoot $MissionRoot -InstrumentPath $InstrumentPath
        $res.head                = [string]$lamProvenance.head
        $res.tree_clean          = [string]$lamProvenance.tree_clean
        $res.tree_reason         = [string]$lamProvenance.tree_reason
        $res.instrument_sha256   = [string]$lamProvenance.instrument_sha256
        $res.instrument_resolved = [string]$lamProvenance.instrument_resolved
    } catch {
        $res.head = 'not derivable (the provenance read threw)'
        $res.tree_clean = 'not derivable'
        $res.tree_reason = 'the provenance read threw'
        $res.instrument_sha256 = 'not derivable (the provenance read threw)'
        $res.instrument_resolved = 'not derivable (the provenance read threw)'
    }

    # (j) THE INPUT TREE, ONLY WHERE THE CALLER BOUND A LIST, and from the head just stated above -- HEAD
    # is not read a second time for it. HERE, BEFORE THE LAUNCH: Get-LamInputTree runs git (contract (a)).
    # A figure that is not derivable is a sentence and the capture is taken all the same; one line, as
    # every header value is.
    if ($lamInputsBound) {
        try {
            $lamInputTree = Get-LamInputTree -MissionRoot $MissionRoot -Head ([string]$res.head) -Except $InstrumentInputsExcept
            if ($lamInputTree.ok -and ([string]$lamInputTree.figure -cmatch '\A[0-9a-f]{64}\z')) { $res.input_tree = [string]$lamInputTree.figure }
            else { $res.input_tree = 'not derivable (' + [string]$lamInputTree.why + ')' }
        } catch { $res.input_tree = 'not derivable (the input tree read threw)' }
        $res.input_tree = ConvertTo-LamCaptureHeaderValue $res.input_tree
    }

    # PS 5.1: under ErrorActionPreference 'Stop' a native exe's stderr is a FATAL
    # NativeCommandError, and 2>$null does not help. Saved and restored around THE LAUNCH OF THE
    # INSTRUMENT, the one native call of this function. (It was "the one native call in this file"
    # until contract (i); git runs too now -- in Get-LamCaptureProvenance and, since contract (j), in
    # Get-LamInputTree -- each before this launch, each saving and restoring the preference around
    # its own calls.) The variable is NEVER named $p -- PS variable names fold case and $p would BE
    # the parameter $P of some caller that dot-sourced this.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw  = @()
    $code = 1
    try {
        $raw  = & powershell -NoProfile -ExecutionPolicy Bypass -File $InstrumentPath 2>&1
        $code = $LASTEXITCODE
        $res.ran = $true
    } catch {
        # (b) NEVER A THROW. The caller asked for an exit code; a failure to launch IS a non-zero
        # one, and it is reported in the transcript rather than raised past the caller's catch.
        $raw  = @("instrument invocation threw: $($_.Exception.Message)")
        $code = 1
    } finally { $ErrorActionPreference = $prevEap }
    if ($null -eq $code) { $code = 1 }
    $res.exit_code = $code

    # (c) FLATTEN BEFORE ANYTHING READS IT.
    $flat = ''
    try { $flat = ((@($raw) | ForEach-Object { "$_" }) -join "`n") } catch { $flat = '' }
    $res.stdout = $flat
    # HOW MANY ITEMS CAME BACK, counted before the flatten can hide it (contract (h) 3). A silent
    # instrument returns no item at all; one that printed exactly one empty line returns ONE item
    # that renders as no text. Both flatten to '', and only this count tells them apart.
    $rawItemCount = 0
    try { $rawItemCount = @($raw).Count } catch { $rawItemCount = 0 }

    # (d) ONE READING OF ONE RUN.
    try {
        $tally = ConvertFrom-LamInstrumentTally -Text $flat
        $res.tally_found = $tally.found
        $res.tally_line  = $tally.line
        $res.fields      = $tally.fields
        $res.tally_lines = [string[]]@($tally.lines)
        $res.tally_count = [int]$tally.count
    } catch { $res.tally_found = $false; $res.tally_line = ''; $res.tally_lines = [string[]]@(); $res.tally_count = 0 }

    # (h) 5 -- THE INSTRUMENTS' OWN COUNT LINE, over the same flattened text and beside the TALLY
    # reading, never instead of it: nothing above is moved by what this finds.
    try {
        $checksRead = ConvertFrom-LamInstrumentChecksLine -Text $flat
        $res.checks_found = [bool]$checksRead.found
        $res.checks_line  = [string]$checksRead.line
        $res.checks       = $checksRead.fields
        $res.checks_count = [int]$checksRead.count
    } catch { $res.checks_found = $false; $res.checks_line = ''; $res.checks = [ordered]@{}; $res.checks_count = 0 }

    # EXACTLY the runner's pattern (mission-dispatch.ps1, the expected_failures_matched site), over
    # the same flattened text that is about to be persisted.
    try {
        $ids = New-Object System.Collections.Generic.List[string]
        foreach ($idLine in ($flat -split '\r?\n')) {
            if ($idLine -match '^FAILED\s+(\S+)') { [void]$ids.Add($Matches[1]) }
        }
        $res.failed_ids = @($ids.ToArray())
    } catch { $res.failed_ids = @() }

    # THE BODY'S OWN MEASURE, taken before and apart from persistence, so a run whose files could
    # not be written still reports what the instrument said.
    $enc = New-Object System.Text.UTF8Encoding($false)
    try {
        $bodyBytes = $enc.GetBytes($flat)
        $res.body_bytes  = $bodyBytes.Length
        $res.body_sha256 = Get-LamCaptureSha256 -Bytes $bodyBytes
    } catch { $res.body_bytes = 0; $res.body_sha256 = '' }

    # (b) AGAIN, AND THIS IS THE CLAUSE THAT MATTERS MOST: everything from here to the return is a
    # SIDE EFFECT. An unwritable directory, a locked file, a full disk -- each of them degrades to
    # persisted = false with the reason recorded, and NONE of them changes exit_code.
    try {
        $paths = Get-LamInstrumentRunPath -MissionRoot $MissionRoot -InstrumentPath $InstrumentPath -RunKey $RunKey -Goal $Goal
        $res.stdout_path = $paths.stdout
        $res.tally_path  = $paths.tally
        if (-not (Test-Path -LiteralPath $paths.dir)) {
            $null = New-Item -ItemType Directory -Path $paths.dir -Force -ErrorAction Stop
        }
        # ONE captured_at FOR BOTH FILES, from .NET: no cmdlet here can non-terminate under a
        # caller's 'Stop', and the shared value is what pairs the two files of one run.
        $capturedAt = [DateTime]::UtcNow.ToString('o')
        $cwdNow = ''
        try { $cwdNow = [string]$ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath } catch { $cwdNow = '' }

        # (h) 2 -- THE PROVENANCE HEADER. One key per line; every value scrubbed to one line.
        $header = New-Object System.Collections.Generic.List[string]
        [void]$header.Add('# lam-instrument-run capture. The instrument''s own output is between the two --- lines below, verbatim.')
        [void]$header.Add('writer: tools/lam/lam-instrument-run.ps1 Save-LamInstrumentRun')
        [void]$header.Add('capture_format: 1')
        [void]$header.Add('run_key: ' + (ConvertTo-LamCaptureHeaderValue $RunKey))
        [void]$header.Add('goal: ' + (ConvertTo-LamCaptureHeaderValue $Goal))
        [void]$header.Add('detector_ordinal: ' + (Get-LamCaptureDetectorOrdinal -RunKey $RunKey -Goal $Goal))
        [void]$header.Add('instrument: ' + (ConvertTo-LamCaptureHeaderValue $InstrumentPath))
        [void]$header.Add('cwd: ' + (ConvertTo-LamCaptureHeaderValue $cwdNow))
        [void]$header.Add('captured_at: ' + $capturedAt)
        [void]$header.Add('ran: ' + [string]$res.ran)
        [void]$header.Add('exit_code: ' + [string]$code)
        [void]$header.Add('tally_count: ' + [string]$res.tally_count)
        [void]$header.Add('body_bytes: ' + [string]$res.body_bytes)
        [void]$header.Add('body_sha256: ' + [string]$res.body_sha256)
        # (i) FIVE KEYS MORE, AFTER EVERY KEY THAT WAS HERE: what the run stood
        # on, read before the instrument was launched. capture_format stays 1 -- no key above
        # moved, and a reader that wants these treats their absence as "not reusable".
        [void]$header.Add('head: ' + (ConvertTo-LamCaptureHeaderValue $res.head))
        [void]$header.Add('tree_clean: ' + (ConvertTo-LamCaptureHeaderValue $res.tree_clean))
        [void]$header.Add('tree_reason: ' + (ConvertTo-LamCaptureHeaderValue $res.tree_reason))
        [void]$header.Add('instrument_sha256: ' + (ConvertTo-LamCaptureHeaderValue $res.instrument_sha256))
        [void]$header.Add('instrument_resolved: ' + (ConvertTo-LamCaptureHeaderValue $res.instrument_resolved))
        # (j) ONE KEY MORE, AFTER EVERY KEY THAT WAS HERE, AND ONLY WHERE -InstrumentInputsExcept WAS BOUND
        # (contract (j)): the input tree the run stood on, or why it could not be derived. Not bound,
        # the line is not written at all -- the header is the eighteen keys it was, and capture_format
        # stays 1 either way.
        if ($lamInputsBound) { [void]$header.Add('input_tree: ' + (ConvertTo-LamCaptureHeaderValue $res.input_tree)) }
        $headerText = ($header -join "`n") + "`n"

        # (h) 3 -- NEVER A ZERO-BYTE BODY. The sentence is the record of the silence.
        $silentStatement = '(THE INSTRUMENT PRINTED NOTHING on stdout or stderr. It was run and it said nothing; this sentence is the record of that silence, not the absence of a record, and body_bytes: 0 above says the same as a number.)'
        if (-not $res.ran) { $silentStatement = '(NOTHING CAME BACK AND THE INSTRUMENT DID NOT RUN TO COMPLETION: ran is False above, and body_bytes: 0 says no text was returned.)' }
        # ONE EMPTY LINE IS NOT SILENCE. The empty body then gets a sentence that says what was
        # printed, and never the silence sentence.
        $emptyLineStatement = '(THE INSTRUMENT PRINTED ONE EMPTY LINE AND NOTHING ELSE on stdout or stderr. It was run and its whole output is that one empty line, which flattens to no text, so body_bytes: 0 above counts no text; this sentence is the record of that empty line, and it is not a record of silence.)'
        if ($res.ran -and ($rawItemCount -gt 0)) { $silentStatement = $emptyLineStatement }
        $bodyInner = $flat
        if ($flat.Length -eq 0) { $bodyInner = $silentStatement }
        $bodyBlock = "--- instrument stdout and stderr, verbatim ---`n" + $bodyInner + "`n--- end of instrument output ---`n"
        $stdoutText = $headerText + $bodyBlock

        # (h) 1 and 4 -- THE TALLY FILE. Line 1 is exactly what it always was; every further TALLY
        # line follows in order; the EXIT line always ends the file.
        $tallyOut = New-Object System.Collections.Generic.List[string]
        $tallyKept = @($res.tally_lines)
        # Line 1 is the first KEPT line, so the length bound reaches it too; for any TALLY line
        # inside the bound that is byte-for-byte the first TALLY line, as it always was.
        $tallyFirst = $res.tally_line
        if (-not $res.tally_found) { $tallyFirst = "NO-TALLY exit_code=$code" }
        elseif ($tallyKept.Count -gt 0) { $tallyFirst = [string]$tallyKept[0] }
        # (h) 5 -- THE COUNT LINE'S RECORD. One line, key=value, beginning
        # CHECKS: it cannot begin TALLY, FAILED, NO-TALLY, BOUND or EXIT. Where the instrument
        # printed NO TALLY it is the FIRST line, so NO-TALLY stays the word for a stdout that
        # carries neither; where a TALLY was printed line 1 is still the first TALLY, as it always
        # was, and this record sits after the TALLY lines and before the EXIT line, which still
        # ends the file. exit_code_agrees says whether the instrument's own exit code is the one
        # its count line implies (0 for a passed form, the failure count for the FAILED form).
        $checksRecord = ''
        if ($res.checks_found) {
            $checksPairs = New-Object System.Collections.Generic.List[string]
            foreach ($checksKey in @($res.checks.Keys)) { [void]$checksPairs.Add([string]$checksKey + '=' + [string]$res.checks[$checksKey]) }
            $checksImplied = 0
            if ([string]$res.checks['result'] -ceq 'FAILED') { $checksImplied = [int]$res.checks['failed'] }
            $checksRecord = 'CHECKS ' + ($checksPairs -join ' ') + ' lines=' + [string]$res.checks_count + ' exit_code_agrees=' + [string]($code -eq $checksImplied)
        }
        if ($checksRecord -and (-not $res.tally_found)) { $tallyFirst = $checksRecord }
        [void]$tallyOut.Add($tallyFirst)
        for ($tallyAt = 1; $tallyAt -lt $tallyKept.Count; $tallyAt++) { [void]$tallyOut.Add([string]$tallyKept[$tallyAt]) }
        if ($res.tally_count -gt $tallyKept.Count) {
            [void]$tallyOut.Add("BOUND tally_lines_kept=$($tallyKept.Count) tally_count=$($res.tally_count) -- the column-0 TALLY lines past the bound are in the stdout file's verbatim body and are not repeated here")
        }
        if ($checksRecord -and $res.tally_found) { [void]$tallyOut.Add($checksRecord) }
        [void]$tallyOut.Add("EXIT exit_code=$code ran=$($res.ran) tally_count=$($res.tally_count) captured_at=$capturedAt")
        $tallyText = ($tallyOut -join "`n") + "`n"

        # (f) OVERWRITE IN PLACE. WriteAllText truncates; nothing here appends.
        [System.IO.File]::WriteAllText($paths.stdout, $stdoutText, $enc)
        [System.IO.File]::WriteAllText($paths.tally, $tallyText, $enc)
        $res.persisted = $true
        # Hashed from the BYTES THAT WERE WRITTEN, not by re-reading the file: a re-read would
        # measure whatever is on disk now, which is the thing a later reader wants to check
        # against this figure rather than have derived from it. These are the FILE's bytes, header
        # included; the instrument's own bytes are body_sha256 / body_bytes.
        $bytes = $enc.GetBytes($stdoutText)
        $res.stdout_bytes  = $bytes.Length
        $res.stdout_sha256 = Get-LamCaptureSha256 -Bytes $bytes
    } catch {
        $res.persisted    = $false
        $res.persist_note = "not persisted: $($_.Exception.Message)"
    }

    # (a) THE LAST WORD, AND NOTHING NATIVE AFTER IT. mission-goal-check.ps1's detector reads
    # $LASTEXITCODE on the line after this call returns; this assignment makes that value the
    # instrument's own, whatever the persistence branch above did or did not do.
    $global:LASTEXITCODE = $code
    return $res
}
