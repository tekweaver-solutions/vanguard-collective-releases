#Requires -Version 5.1
<#
.SYNOPSIS
  LAM runner -- executes one Worker Dispatch as a pure function. (LAM-ACCEPT WP-2, R-1..R-5)

.DESCRIPTION
  Design v2.3 SS9.2: the orchestrator does not drive an interactive session. It writes an immutable
  dispatch artifact and invokes this runner, which verifies the mission plane, spawns a fresh
  headless worker in a worktree, and -- when the worker exits -- declares the dispatch boundary,
  validates the handoff, populates anchors from evidence, and emits a completion signal.

  THE RUNNER IS THE PARTY THAT OWNS THE DISPATCH BOUNDARY. It writes
  OWNER before the spawn and DISPATCH-END after the worker exits. Neither is writable by the
  worker: both sit under the evidence root, which the guard protects, and the next-gen guard names
  them explicitly. That ownership is what lets a worker's Stop hooks fire repeatedly without
  sealing anything -- the state derives OPEN until this runner says otherwise.

  THREE INJECTION SEAMS, DEFAULTING TO THE REAL THING AND DISCLOSED HERE:
    -VerifyCommand      default: tools/mission-verify.ps1     (the ADR-022 gate)
    -WorkerCommand      default: the `claude` CLI              (the headless worker)
    -LoginProbeCommand  default: the `claude` CLI, asked       (the pre-spawn login probe;
                        `-p "Reply with exactly the word OK     skipped when -WorkerCommand
                        and nothing else." --output-format     names a stub and this seam is not
                        text` from an empty scratch folder     given, since no CLI is then spawned)
  They exist so WP-2's instrument can drive this file hermetically -- an instrument that needs the
  network or a live agent is an instrument that gets skipped, and design SS4.5 law 6 says the
  runner must be DRIVEN, not inspected. WP-6's S-1b runs this same file with a verify stub and the
  worker and the probe at their defaults; that, not the instrument, is the end-to-end proof.

  EXIT CONTRACT
    0  dispatch ran, handoff valid, anchors written
    2  refused before spawning -- the verify gate did not PASS, or the inputs are unusable
       (one more such input: the worktree could not be placed at the
       base_head_at_authoring -- or, for a validator, the tip_judged -- that the dispatch
       declares. The refusal names both the sha the tree stands at and the sha it should.
       The run record is CLOSED before that refusal, so a refused dispatch does not
       read as still running. The worktree relocation adds more such inputs. Refused
       BEFORE the run record opens: a mission root with no parent or leaf to derive the sibling
       worktree home from (a drive root, or a provider-qualified UNC spelling), and a composed
       worktree path of 216 or more UTF-8 bytes, git's linked-worktree ceiling. Refused AFTER
       .started, each closing the run record first in the run record's order: a mission root that is
       not a git repository; one with no commit at HEAD when the dispatch declares no base; a
       tree git could not create; a directory at the tree's path that is not this mission
       root's own linked worktree; a .worktreeinclude placement that could not be planned (the
       console could not be switched to UTF-8 to read the names, or a git listing failed), that
       could not tell whether a source's or a destination's path passes through a junction or
       symbolic link, that met one on a destination's path inside the tree, that could not
       remove an existing destination before placing it afresh (read-only, or held open by
       another process without delete sharing), that copied or verified fewer files than it
       planned, or that -- where the mission root has .claude/settings.json on disk and
       .worktreeinclude's patterns match that path, tracked or not -- did not leave the tree
       holding it, either placed by this run and byte-equal to the mission root's or committed
       at the tree's HEAD and unmodified against it (the refusal names which case failed:
       placed but absent or not byte-equal; committed at the tree's HEAD but absent, modified
       or not comparable; or neither, because the placement skipped it -- as reached through a
       link, or otherwise -- because the mission root tracks it and the tree's HEAD, the
       declared base where one is declared, does not commit it, or because it is untracked
       but not ignored in the mission root); and a tree that could not be entered as the
       worker's working directory.)
       A dispatch that names a dispatch gate (-DispatchGate) is also refused, exit 2, printing
       DISPATCH-GATE-<CODE> (the codes are listed in tools/lam/lam-dispatch-gate.ps1): by the
       decision taken before verify runs, with nothing written; or at the spawn, when the decision
       taken again under the gate's exclusive handle refuses -- the gate changed, stayed held,
       expired in between, or its manifest or artifact moved -- with the run record closed first;
       either way no worker is spawned and the stamp has written nothing. An exception escaping
       either decision is reported as DISPATCH-GATE-FAULT, exit 2, after the same closing.
       A run under VANGUARD_AUTH_MODE whose mode refuses is refused too, exit 2, printing
       AUTH-MODE-<CODE> (the codes are listed in tools/lam/lam-auth-mode.ps1), before -PlanOnly's
       print and before the verify gate, the login probe or the worker is started; with the variable
       unset the library is not loaded and nothing of it runs.
    3  the worker ran but the dispatch is REJECTED (handoff.status: rejected) -- its handoff failed
       schema validation, a real YAML parser refuses it (DECLARED-HANDOFF-UNPARSEABLE),
       or a declared repair was not delivered. A validator writes no
       handoff, so this is also a validator's designed completion; a validator result the runner
       would not place at the mission root (RESULT-PLACEMENT-REFUSED-<CODE>) is
       one more such problem, written to the spawn ledger as a note as well; and so is a validator
       session that exits leaving NO result at its declared result_path (NO-RESULT-AT-SESSION-END-<CODE>):
       the runner waits, no longer than -NoResultWaitSeconds, for the session's
       descendant processes to end, reads the result once more, and then names the refusal
    4  the worker exited non-zero (recorded, never reported as success -- R-5)
    7  refused before spawning because the worker CLI's login probe did not answer OK
       (LOGIN-PROBE-<CODE>). Refused BEFORE the evidence session, the run record,
       the worktree, the dispatch gate's stamp and the anchors, so the same dispatch id runs again
       once the CLI can authenticate. Under the mission root it leaves the verify gate's own store
       for the verify run first, and one spawn-ledger note, through tools/lam/spawn_ledger.py.

  -CheckRunRecord IS A READ-ONLY QUERY MODE WITH ITS OWN EXIT CONTRACT. It
  answers the run-record predicate over an existing record and returns: 0 the record is COMPLETE,
  1 it is not. It spawns nothing, writes nothing, and runs no gate.

  -DispatchGate <id> NAMES THE OPERATOR'S DISPATCH GATE THIS SPAWN RUNS UNDER (operator ruling (i),
  "Dispatch gates are stamped by the runner at spawn"). The gate is
  .mission/gates/dispatch-<id>.yaml. At the first spawn under it the runner stamps consumed_at and
  lists the spawn; each later spawn appends one line; the anchors record the gate id in a
  dispatch_gate block. Without -DispatchGate the library is not loaded, no gate is read or written,
  and no plan line, stamp line or dispatch_gate block is produced.

  -NoResultWaitSeconds <n> BOUNDS THE WAIT FOR A VALIDATOR SESSION'S DESCENDANTS (default
  300, and 0 switches the wait off). It applies only to a validator dispatch that declares a result_path,
  and only when that file is absent from the validator's own tree as the session's process exits. A
  session that wrote its result before it exited is not waited for, and nothing of this is printed or
  recorded for it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MissionRoot,
    [Parameter(Mandatory = $true)][string]$Dispatch,
    [ValidateSet('coding-strong','coding-fast','qa-validator','small-fast')]
    [string]$Role = 'coding-strong',
    [string]$VerifyCommand,
    [string]$WorkerCommand,
    [switch]$PlanOnly,
    [switch]$NoOrchestrator,
    [switch]$AllowIdReuse,
    [switch]$CheckRunRecord,
    [string]$DispatchGate,
    [string]$LoginProbeCommand,
    [ValidateRange(1, 600)]
    [int]$LoginProbeTimeoutSeconds = 120,
    [ValidateRange(0, 3600)]
    [int]$NoResultWaitSeconds = 300
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Write-Line { param([string]$m) Write-Output $m }

# R-5 IN ITS MOST BASIC FORM: a runner that dies must say where. Without this, an unhandled
# terminating error surfaces as a bare "You cannot call a method on a null-valued expression" with
# no line and no stage, which is indistinguishable from a dispatch that silently did nothing --
# the exact shape of failure this program refuses to ship. Exit 5 is distinct from every planned
# code so a caller can tell "the runner broke" from "the runner refused".
trap {
    Write-Line "mission-dispatch: UNHANDLED ERROR -- $($_.Exception.Message)"
    Write-Line "  type  : $($_.Exception.GetType().FullName)"
    Write-Line "  stack : $(($_.ScriptStackTrace -split "`r?`n") -join ' | ')"
    exit 5
}

function Deny-Dispatch {
    param([string]$Reason)
    Write-Line "mission-dispatch: REFUSED -- $Reason"
    exit 2
}

# =============================================================================================
# THE RUN RECORD -- .started / .rc / .ended
# =============================================================================================
# THE RUNNER OWNS ITS RUN RECORD. It writes .started at launch, BEFORE the spawn, and .rc and
# .ended at exit, in its own end path. No seat helper and no worker writes any of the three.
#
# WHY A SEPARABLE TRIPLE WHEN OWNER AND DISPATCH-END ALREADY CARRY THE SAME THREE FACTS.
# OWNER carries spawned_at; DISPATCH-END carries ended_at AND worker_exit. So the pair already IS
# a run record -- but the rc is BUNDLED into the end stamp, and both files are written under names
# that say who wrote them rather than what state the run is in. A launcher that polls has to read
# and parse DISPATCH-END to learn anything, and a launcher that keys on the PRESENCE of whatever
# file carries the rc cannot tell 'the rc is here because THIS run returned' from 'the rc is here
# because the PREVIOUS run returned into the same evidence root'. That second reading is the
# STALE-RC class. Keeping the rc in a file of its own -- absent until the run
# returns, and DELETED at every launch -- is what makes the question answerable by a reader that
# only stats files.
#
# THE THREE STATES A READER MUST BE ABLE TO TELL APART, and what decides each:
#   .started absent or empty
#       -> NEVER STARTED. Nothing was spawned. This is NOT the same statement as 'still running'.
#   .started non-empty, and .rc or .ended empty or absent
#       -> STARTED AND NOT FINISHED. Still running, or died without reaching the end path.
#   .started, .ended and .rc all non-empty, and .ended not earlier than .started
#       -> FINISHED, and ONLY THEN is the value in .rc this run's exit code.
#
# OWNER AND DISPATCH-END ARE NOT REMOVED, and that is deliberate. Nothing under tools/ reads
# either one today, but a durable artifact that consumers outside this tree may hold is not this
# row's to delete. The triple is ADDITIVE: the two older files keep their bytes and their meaning,
# and the same three facts are now ALSO readable without parsing anything.

# THE ONE COMPOSITION of the evidence root and of the run-record paths. This repo has its own
# record of what happens when one directory is composed in two places, so the query mode below and
# the dispatch path both read their paths from here rather than each spelling the join.
function Get-RunRecordPath {
    param([string]$Root, [string]$DispatchId)
    $session = "session-$DispatchId"
    $ev      = Join-Path $Root ".mission-runtime\evidence\$session"
    return [pscustomobject]@{
        session  = $session
        evidence = $ev
        started  = (Join-Path $ev "$DispatchId.started")
        rc       = (Join-Path $ev "$DispatchId.rc")
        ended    = (Join-Path $ev "$DispatchId.ended")
    }
}

function Read-RunRecordStamp {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    try { return ([System.IO.File]::ReadAllText($Path)).Trim() } catch { return '' }
}

# THE PREDICATE, AND THE ONLY DEFINITION OF IT. A reader NEVER re-spells this test: it calls this
# runner with -CheckRunRecord. LAWFUL COMPLETION IS
#     .ended is NOT EARLIER than .started   AND   .rc is NON-EMPTY.
# Presence alone is not completion, and that is the whole of the rule. A run that never returned can
# still leave a file behind, and a .ended that precedes its own .started is not one run's record at
# all -- it is two runs' fragments in one directory, which is exactly what a reader must refuse.
function Test-RunRecordComplete {
    param([psobject]$Record)
    $s = Read-RunRecordStamp -Path $Record.started
    $e = Read-RunRecordStamp -Path $Record.ended
    $r = Read-RunRecordStamp -Path $Record.rc
    $state = ''
    $ok = $false
    if (-not $s) {
        $state = 'never-started'
    } elseif ((-not $r) -or (-not $e)) {
        $state = 'started-not-finished'
    } else {
        $sd = [datetime]::MinValue
        $ed = [datetime]::MinValue
        $fmt = 'yyyy-MM-ddTHH:mm:ss.fffZ'
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        $sty = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
        $sOk = [datetime]::TryParseExact($s, $fmt, $inv, $sty, [ref]$sd)
        $eOk = [datetime]::TryParseExact($e, $fmt, $inv, $sty, [ref]$ed)
        if (-not ($sOk -and $eOk)) {
            $state = 'unparseable-stamp'
        } elseif ($ed -lt $sd) {
            $state = 'ended-precedes-started'
        } else {
            $state = 'finished'
            $ok = $true
        }
    }
    return [pscustomobject]@{ complete = $ok; state = $state; started = $s; ended = $e; rc = $r }
}

# THE READ SIDE. It exists so that a launcher which polls calls THE OWNER'S predicate instead of
# spelling its own, and it is placed HERE -- ahead of every gate -- on purpose: asking 'has it
# finished' must not require authority to dispatch into the repository being asked about.
if ($CheckRunRecord) {
    $rrQuery = Get-RunRecordPath -Root $MissionRoot -DispatchId $Dispatch
    $rrState = Test-RunRecordComplete -Record $rrQuery
    Write-Line "run-record: $($rrState.state)"
    Write-Line "  complete : $($rrState.complete)"
    Write-Line "  started  : $(if ($rrState.started) { $rrState.started } else { '(absent)' })"
    Write-Line "  ended    : $(if ($rrState.ended) { $rrState.ended } else { '(absent)' })"
    Write-Line "  rc       : $(if ($rrState.rc) { $rrState.rc } else { '(absent)' })"
    if ($rrState.complete) { exit 0 }
    exit 1
}

# --- tiny YAML reader ------------------------------------------------------------------------
# PS 5.1 ships no YAML parser and this program takes no dependency it cannot read (the same
# reasoning mission-verify.ps1 gives for hand-rolling its JSON-schema subset). REACH, STATED:
# top-level `key: value` scalars and `key: [a, b]` inline lists only. It does NOT implement block
# lists, nesting, anchors, or multi-line scalars. Dispatch and handoff artifacts are flat by
# construction; anything richer is out of reach and is reported as a MISSING FIELD rather than
# silently mis-parsed -- the direction that refuses.
function Read-FlatYaml {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            $k = $Matches[1]
            $v = $Matches[2].Trim()
            if ($v -match '^\[(.*)\]$') {
                $inner = $Matches[1].Trim()
                if ($inner) { $map[$k] = @($inner -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }) }
                else        { $map[$k] = @() }
            } else {
                $map[$k] = $v.Trim('"').Trim("'")
            }
        }
    }
    return $map
}

# --- the strict-YAML admission -----------------------------------------------
# WHAT READ-FLATYAML ABOVE CANNOT SEE, AND WHY THAT IS NOT ENOUGH. Its reach is stated honestly and
# its failures are meant to fall toward MISSING FIELD. But the reach comment describes what it
# cannot READ; it does not describe what it WRONGLY ACCEPTS. `^key:\s*(.*)$` takes everything after
# the FIRST colon as the value, so a plain scalar carrying ': ' -- `sample_f1: SAMPLE-F1 PASS -- RED
# at the base: the sample check ...` -- is read as one tidy key/value pair, while a
# parser that implements YAML refuses the same line with "mapping values are not allowed here".
# A HANDOFF IN THAT STATE -- a worker can write one without knowing it -- is ADMITTED by the
# schema check above, with no problem reported, and is shut to every downstream reader that
# uses a real parser. A validator that passes what no consumer can
# read is not validating the artifact; it is validating its own reader.
#
# THE DEPENDENCY, DECIDED IN THE OPEN. PS 5.1 ships no YAML parser, and this program's own rule is
# that it takes no dependency it cannot read -- which is why Read-FlatYaml exists at all. There is
# no way to say "what a YAML parser refuses" without asking one, and a hand-rolled approximation
# would be a PARAPHRASE: it could not carry the parser's own message or its line, and every shape
# it failed to model would be a fresh instance of this same defect. So the runner asks a real
# parser, through tools/lam/handoff-strict-parse.py (readable, forty lines, beside this file), run
# by whatever python is on PATH.
#
# AND THE PARSER IS NOT ALWAYS THERE. That is the case this function exists to get right, because
# both easy answers are worse than the defect:
#   * PASS SILENTLY when no parser can be reached -- that is the defect, re-created, and worse for
#     being invisible: the artifact would claim a check that never ran.
#   * REFUSE EVERY DISPATCH on a machine with no python -- that breaks every mission on a host that
#     was never asked to have one, to enforce a rule about file syntax.
# SO: THREE OUTCOMES, NOT TWO. `parsed` and `refused` are verdicts; `unavailable` is the explicit
# third, and it is LOUD -- printed at the dispatch's end and written into the anchors as
# `handoff_strict_yaml: unavailable` with the reason. The dispatch proceeds on the schema check
# alone, exactly as it did before this row, and the record says so in as many words. A later reader
# can always tell a handoff that PASSED a parser from one that was never shown to one.
$script:StrictYamlProbeScript = Join-Path $PSScriptRoot 'handoff-strict-parse.py'
$script:StrictYamlLast        = $null

# A SINGLE-QUOTED YAML SCALAR, and the reason is this very row. The rest of this file writes notes
# as "..." with inner quotes swapped, which is fine for prose and WRONG for a Windows path: in a
# DOUBLE-quoted YAML scalar `\U` in an expanded `%USERPROFILE%\...` path is an invalid escape, and eight D-V-A-* handoffs
# on this mission are refused by a real parser for exactly that ("expected escape sequence of 8
# hexadecimal numbers, but found 's'"). The fields this row adds carry paths and a parser's own
# text, so they are written the one way that has no escapes at all.
#
# THE REACH OF THIS HELPER WIDENS TO THE ANCHORS WRITER. The row above cured
# the handoff; the anchors writer was in neither cure's reach and went on emitting Windows paths
# inside DOUBLE-quoted scalars, so 39 of the 40 *.anchors*.yaml files on this mission are refused
# by yaml.safe_load -- every one of them at the `reason:` field of verify_advance_admission, whose
# text names the mission config by absolute path. The cure is this same function, applied at every
# anchors-writer site that interpolates anything at all into a scalar; there are now NONE left
# that do not. FORWARD-ONLY: the 39 files already on disk are records, several bound by sha256 in
# gate artifacts and ledger entries, and nothing here rewrites them.
#
# WHAT SINGLE-QUOTING CHANGES BESIDES THE ESCAPE. The sites it replaces wrote `"..."` with inner
# double quotes swapped for single ones -- so a value that genuinely contained a `"` came out
# altered. A single-quoted scalar keeps the `"` and doubles the `'` instead, which is a
# representation change and not a value change. mission-verify's reader accepts both spellings
# (ConvertFrom-YamlScalar, tools/mission-verify.ps1:774-775: it strips "..." and un-doubles
# '...'), so no consumer reads a different value than it read before.
function ConvertTo-YamlSingleQuoted {
    param([string]$Text)
    $t = ([string]$Text) -replace "`r`n", ' ' -replace "`r", ' ' -replace "`n", ' '
    return "'" + ($t -replace "'", "''") + "'"
}

function Test-HandoffStrictYaml {
    param([string]$Path)
    $res = [pscustomobject]@{
        outcome = 'unavailable'   # parsed | refused | unavailable -- the closed set
        problem = ''
        line    = 0
        column  = 0
        parser  = ''
        detail  = ''
        path    = $Path
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        $res.detail = "there is no file at $Path to parse"
        $script:StrictYamlLast = $res
        return $res
    }
    if (-not (Test-Path -LiteralPath $script:StrictYamlProbeScript)) {
        $res.detail = "the strict-parse probe is not beside the runner at $script:StrictYamlProbeScript"
        $script:StrictYamlLast = $res
        return $res
    }
    # TWO SPELLINGS OF THE SAME INTERPRETER, because a Windows host may carry either. `py -3` is the
    # launcher the python.org installer leaves; `python` is what the Store build and every venv put
    # on PATH. Resolved with Get-Command rather than called speculatively: `& python` where nothing
    # is on PATH raises, and a raise here would be the hard-refusal this function exists to avoid.
    $tried = @()
    foreach ($cand in @(
        [pscustomobject]@{ exe = 'python'; pre = @() },
        [pscustomobject]@{ exe = 'py';     pre = @('-3') }
    )) {
        $cmd = @(Get-Command $cand.exe -CommandType Application -ErrorAction SilentlyContinue) |
               Select-Object -First 1
        if (-not $cmd) { $tried += "$($cand.exe): not on PATH"; continue }
        $spelling = (@($cand.exe) + @($cand.pre)) -join ' '
        $out = ''
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $argv = @($cand.pre) + @($script:StrictYamlProbeScript, $Path)
            $raw = & $cmd.Source @argv 2>&1
            $out = ((@($raw) | ForEach-Object { "$_" }) -join "`n")
        } catch {
            $out = ''
            $tried += "$($spelling): $($_.Exception.Message)"
        } finally { $ErrorActionPreference = $prevEap }
        if ($out -match '(?m)^ROW155-PARSE-OK\s*$') {
            $res.outcome = 'parsed'
            $res.parser  = "$spelling + PyYAML"
            $res.detail  = "yaml.safe_load accepted the artifact"
            $script:StrictYamlLast = $res
            return $res
        }
        if ($out -match "(?m)^ROW155-PARSE-ERR`t([^`t]*)`t(\d+)`t(\d+)\s*$") {
            $res.outcome = 'refused'
            $res.problem = $Matches[1]
            $res.line    = [int]$Matches[2]
            $res.column  = [int]$Matches[3]
            $res.parser  = "$spelling + PyYAML"
            $script:StrictYamlLast = $res
            return $res
        }
        if ($out -match "(?m)^ROW155-PARSE-UNAVAILABLE`t(.*)$") {
            # A REAL ANSWER OF "NO VERDICT" -- python ran, PyYAML was not there (or the file could
            # not be opened). Try the next spelling: a second interpreter may well have it.
            $tried += "$($spelling): $($Matches[1].Trim())"
            continue
        }
        $tried += "$($spelling): no sentinel line in its output -- $(((($out -split "`r?`n") | Where-Object { $_ -and $_.Trim() }) | Select-Object -First 1))"
    }
    $res.detail = "no strict YAML parser could be reached -- $($tried -join '; ')"
    $script:StrictYamlLast = $res
    return $res
}

# =============================================================================================
# THE PRE-SPAWN LOGIN PROBE (BATCH-2 WP-G (a))
# =============================================================================================
# THE DEFECT. Spawn seq 184, D-PB-2-S1: this runner verified, cut the tree and spawned a
# worker whose CLI could not authenticate -- the worker exited 1 after 7 s on "Failed to authenticate:
# OAuth session expired and could not be refreshed" -- and the dispatch cost a verify, a worktree, the
# runner's suite run, a dispatch id and an operator HALT. Nothing here asked the CLI first.
#
# THE PROBE, AS THE CHARTER RULED IT (WP-G (a)): before the spawn the runner runs
#     claude -p "Reply with exactly the word OK and nothing else." --output-format text
# from an EMPTY scratch folder -- never the repository, never the home directory -- and refuses the
# dispatch on anything but OK. An empty folder because a `claude -p` started inside a repository takes up
# that repository's project settings and hooks: the probe asks the CLI one question and must not run a
# mission's Stop hook or evidence guard to ask it. The folder is a new directory under the user's temp
# path, refused if it would be the home directory, sit inside the mission root or sit inside any git
# work tree, shown empty before the probe starts, and removed when it returns.
#
# WHAT OK MEANS, READ STRICTLY: the probe exited inside the bound with exit code 0, and its standard
# output, surrounding whitespace trimmed, is exactly `OK` (ordinal, case-sensitive). The face this was
# written against -- one real probe of claude 2.1.284 from an empty folder outside any repository -- is
# exit 0, stdout the three bytes 4f 4b 0a, stderr empty, 5228 ms, nothing written to the folder.
# Anything else refuses under its own name, tested in this order:
#     FAULT         the probe could not be started, or its scratch folder could not be made as above
#     TIMEOUT       no exit inside the bound; the probe's process tree is killed
#     NONZERO-EXIT  it exited non-zero, whatever it printed
#     EMPTY         exit 0 and nothing but whitespace on stdout
#     NOT-OK        exit 0 and a stdout that is not exactly OK
# Standard error is recorded and never decides.
#
# THE BOUND, -LoginProbeTimeoutSeconds, default 120: about 23 times the measured 5.2 s, so a slow network
# or a token refresh still answers inside it, while a CLI waiting on a login nobody will give it is cut
# off in two minutes instead of holding the dispatch for as long as it waits.
#
# THE SEAM, -LoginProbeCommand: a PowerShell script run in the probe's place, with the same arguments
# after it and the same empty working directory, so an instrument can make the probe answer OK, not OK,
# nothing, a non-zero exit or no exit at all without a real `claude -p`. The callers of this runner never
# pass it.
function Invoke-LamLoginProbe {
    param(
        [string]$ProbeCommand,
        [int]$TimeoutSeconds = 120,
        [string]$MissionRoot,
        [string]$Prompt = 'Reply with exactly the word OK and nothing else.'
    )
    $res = [pscustomobject]@{
        ok = $false; code = 'FAULT'; reason = ''; command = ''; cwd = ''; cwd_removed = $false
        exit_code = $null; wall_ms = 0; stdout = ''; stderr = ''; timed_out = $false
    }
    $argText = '-p "' + $Prompt + '" --output-format text'
    $fileName = ''
    $arguments = ''
    if ($ProbeCommand) {
        $res.command = "powershell -File $ProbeCommand $argText (the -LoginProbeCommand seam, in place of claude)"
        if ($ProbeCommand.Contains('"') -or (-not (Test-Path -LiteralPath $ProbeCommand -PathType Leaf))) {
            $res.reason = "the -LoginProbeCommand script '$ProbeCommand' is not a file this runner can start"
            return $res
        }
        $fileName = Join-Path $PSHOME 'powershell.exe'
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $ProbeCommand + '" ' + $argText
    } else {
        $res.command = "claude $argText"
        $probeCli = @(Get-Command 'claude' -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
        if (-not $probeCli) {
            $res.reason = 'no claude CLI is on PATH, so whether the worker can authenticate cannot be asked'
            return $res
        }
        $res.command = "claude $argText ($($probeCli.Source))"
        $fileName = $probeCli.Source
        $arguments = $argText
    }
    # THE SCRATCH FOLDER, AND WHAT IT MAY NOT BE.
    $scratch = ''
    $scratchWhy = ''
    try {
        $scratch = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) ('lam-login-probe-' + [guid]::NewGuid().ToString('N'))))
        $rootKey = [System.IO.Path]::GetFullPath($MissionRoot).TrimEnd('\') + '\'
        $homeKey = [System.IO.Path]::GetFullPath([Environment]::GetFolderPath('UserProfile')).TrimEnd('\')
        if (($scratch.TrimEnd('\') + '\').StartsWith($rootKey, [System.StringComparison]::OrdinalIgnoreCase)) {
            $scratchWhy = "it would sit inside the mission root $MissionRoot"
        } elseif ($scratch.TrimEnd('\') -ieq $homeKey) {
            $scratchWhy = 'it would be the home directory'
        }
    } catch { $scratchWhy = "its path could not be composed ($($_.Exception.Message))" }
    if ($scratchWhy) {
        $res.reason = "the probe's scratch folder '$scratch' was refused: $scratchWhy"
        return $res
    }
    $proc = $null
    try {
        try { [void][System.IO.Directory]::CreateDirectory($scratch) }
        catch { $res.reason = "the probe's scratch folder '$scratch' could not be made ($($_.Exception.Message))"; return $res }
        $res.cwd = $scratch
        if (@([System.IO.Directory]::GetFileSystemEntries($scratch)).Count -ne 0) {
            $res.reason = "the probe's scratch folder '$scratch' is not empty"
            return $res
        }
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $inTree = @(& git -C $scratch rev-parse --is-inside-work-tree 2>&1 | ForEach-Object { "$_" })
            $inTreeExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prevEap }
        if (($inTreeExit -eq 0) -and (($inTree -join '').Trim() -ceq 'true')) {
            $res.reason = "the probe's scratch folder '$scratch' sits inside a git work tree, where the CLI would take up a project's settings"
            return $res
        }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $fileName
        $psi.Arguments = $arguments
        $psi.WorkingDirectory = $scratch
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { $proc = [System.Diagnostics.Process]::Start($psi) }
        catch { $res.reason = "the probe could not be started ($($_.Exception.Message))"; return $res }
        # STDIN IS CLOSED AT ONCE: a `claude -p` given no stdin waits for it before it answers.
        $proc.StandardInput.Close()
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $res.timed_out = $true
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try { $null = & taskkill.exe /PID $proc.Id /T /F 2>&1 } catch { } finally { $ErrorActionPreference = $prevEap }
            try { if (-not $proc.HasExited) { $proc.Kill() } } catch { }
            [void]$proc.WaitForExit(10000)
        } else {
            $proc.WaitForExit()
        }
        $sw.Stop()
        $res.wall_ms = [long]$sw.ElapsedMilliseconds
        if ($outTask.Wait(5000)) { $res.stdout = [string]$outTask.Result }
        if ($errTask.Wait(5000)) { $res.stderr = [string]$errTask.Result }
        if (-not $res.timed_out) { $res.exit_code = [int]$proc.ExitCode }
    } finally {
        if ($null -ne $proc) { $proc.Dispose() }
        if ($res.cwd) {
            try { Remove-Item -LiteralPath $res.cwd -Recurse -Force -ErrorAction Stop } catch { }
            $res.cwd_removed = (-not (Test-Path -LiteralPath $res.cwd))
        }
    }
    $shown = ($res.stdout.Trim() -replace "`r", '\r' -replace "`n", '\n')
    if ($shown.Length -gt 120) { $shown = $shown.Substring(0, 120) + '...' }
    if ($res.timed_out) {
        $res.code = 'TIMEOUT'
        $res.reason = "the probe did not exit within $TimeoutSeconds s and its process tree was killed"
    } elseif ($res.exit_code -ne 0) {
        $res.code = 'NONZERO-EXIT'
        $res.reason = "the probe exited $($res.exit_code) (stdout `"$shown`")"
    } elseif (-not $res.stdout.Trim()) {
        $res.code = 'EMPTY'
        $res.reason = 'the probe exited 0 and printed nothing on stdout'
    } elseif ($res.stdout.Trim() -cne 'OK') {
        $res.code = 'NOT-OK'
        $res.reason = "the probe exited 0 and answered `"$shown`", not exactly OK"
    } else {
        $res.ok = $true
        $res.code = 'OK'
        $res.reason = 'the probe exited 0 and answered exactly OK'
    }
    return $res
}

# =============================================================================================
# THE RUNNER'S SPAWN-LEDGER NOTES (BATCH-2 WP-G)
# =============================================================================================
# Three refusals are decided inside this runner -- a login probe that did not answer OK, a validator
# result it would not place, and a validator session that exited leaving no result
# at all -- and each is written to the spawn ledger as ONE note at the moment of the
# act, by the tracked composer tools/lam/spawn_ledger.py, never by a line this
# runner spells into the file: the composer checks it (its rule (13) is the refusal note's form), stamps it
# composed_by, and appends it in the one form its forward-only audit admits. The ledger is the mission
# root's (Get-LamLedgerPath); the composer appends to an existing ledger and creates none. A note that
# could not be written -- no ledger, no python, the composer refusing -- does not change the refusal: the
# runner refuses exactly as it would have, and says the line was NOT WRITTEN, and why.
function Write-LamSpawnLedgerNote {
    param([string]$ComposerPath, [string]$LedgerPath, [System.Collections.IDictionary]$Record)
    $res = [pscustomobject]@{ ok = $false; said = '' }
    if (-not (Test-Path -LiteralPath $ComposerPath -PathType Leaf)) { $res.said = "the composer is not on disk at $ComposerPath"; return $res }
    $py = $null
    foreach ($cand in @([pscustomobject]@{ exe = 'python'; pre = @() }, [pscustomobject]@{ exe = 'py'; pre = @('-3') })) {
        $cmd = @(Get-Command $cand.exe -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($cmd) { $py = [pscustomobject]@{ source = $cmd.Source; pre = @($cand.pre) }; break }
    }
    if (-not $py) { $res.said = 'no python is on PATH (python, py -3) to run the composer'; return $res }
    $lineFile = ''
    $prevEap = $ErrorActionPreference
    try {
        $lineFile = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-spawn-ledger-line-' + [guid]::NewGuid().ToString('N') + '.json')
        [System.IO.File]::WriteAllText($lineFile, (ConvertTo-Json -InputObject $Record -Compress -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
        $ErrorActionPreference = 'Continue'
        $raw = & $py.source @($py.pre) $ComposerPath 'append' '--ledger' $LedgerPath '--line-file' $lineFile 2>&1
        $code = $LASTEXITCODE
        $said = ((@($raw) | ForEach-Object { "$_" }) -join ' | ').Trim()
        $res.ok = (($code -eq 0) -and ($said -match '^APPENDED line '))
        $res.said = if ($said) { $said } else { "the composer printed nothing (exit $code)" }
    } catch {
        $res.said = "the composer could not be run ($($_.Exception.Message))"
    } finally {
        $ErrorActionPreference = $prevEap
        if ($lineFile) { Remove-Item -LiteralPath $lineFile -Force -ErrorAction SilentlyContinue }
    }
    return $res
}

# =============================================================================================
# THE PLACEMENT OF ONE VALIDATOR RESULT (BATCH-2 WP-G (b))
# =============================================================================================
# Copies $Source to $Destination, or refuses and writes nothing there. NO OVERWRITE, EVER: a destination
# already present -- file or directory -- is refused, and hashed before and after to show it did not move.
# BOTH ENDS HASHED: the source is hashed, copied to a temp name beside the destination, the temp copy
# hashed and the source hashed AGAIN; the copy is renamed into place only if all three agree, and the
# rename itself refuses a destination that arrived meanwhile. So a source that moved between the hash and
# the copy is refused and nothing reaches the destination. TIME-PRESERVING: the copy takes the source's
# creation, last-write and last-access times as they stood before the runner read it.
# AN INSTRUMENT SEAM: -AfterSourceHash, a scriptblock run after the source is hashed and before it is
# copied, so an instrument can move the source in that window; the runner never passes it. The function
# reads nothing outside its parameters, so an instrument can lift it out of this file with the parser.
function Invoke-LamResultPlacement {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [scriptblock]$AfterSourceHash
    )
    $res = [pscustomobject]@{
        outcome = 'refused-fault'; code = 'FAULT'; reason = ''; source = $Source; destination = $Destination
        source_sha256 = ''; copy_sha256 = ''; source_sha256_after = ''
        destination_sha256_before = ''; destination_sha256_after = ''; bytes = 0; mtime = ''
    }
    $hashOf = { param([string]$P) (Get-FileHash -Algorithm SHA256 -LiteralPath $P).Hash.ToLowerInvariant() }
    $placing = ''
    $renamed = $false
    try {
        if (-not [System.IO.File]::Exists($Source)) {
            $res.reason = "there is no file at the source $Source, so nothing was placed at $Destination"
            return $res
        }
        if ([System.IO.File]::Exists($Destination) -or [System.IO.Directory]::Exists($Destination)) {
            $res.outcome = 'refused-destination-present'
            $res.code = 'DESTINATION-PRESENT'
            if ([System.IO.File]::Exists($Destination)) { $res.destination_sha256_before = & $hashOf $Destination }
            $res.source_sha256 = & $hashOf $Source
            if ([System.IO.File]::Exists($Destination)) { $res.destination_sha256_after = & $hashOf $Destination }
            $res.reason = "something already stands at $Destination$(if ($res.destination_sha256_before) { " (sha256 $($res.destination_sha256_before))" }), and a result is never overwritten, under any flag: the one standing there is archived first, then this one is placed"
            return $res
        }
        $srcItem = Get-Item -LiteralPath $Source
        $srcCreated = $srcItem.CreationTimeUtc
        $srcWritten = $srcItem.LastWriteTimeUtc
        $srcRead = $srcItem.LastAccessTimeUtc
        $res.source_sha256 = & $hashOf $Source
        if ($null -ne $AfterSourceHash) { $null = & $AfterSourceHash }
        $dstDir = Split-Path -Parent $Destination
        [void][System.IO.Directory]::CreateDirectory($dstDir)
        $placing = Join-Path $dstDir ('.' + (Split-Path -Leaf $Destination) + '.placing-' + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::Copy($Source, $placing, $false)
        $res.copy_sha256 = & $hashOf $placing
        $res.source_sha256_after = & $hashOf $Source
        if (($res.copy_sha256 -cne $res.source_sha256) -or ($res.source_sha256_after -cne $res.source_sha256)) {
            $res.outcome = 'refused-source-moved'
            $res.code = 'SOURCE-MOVED'
            $res.reason = "the source changed between the runner's hash and its copy (hashed $($res.source_sha256), copied $($res.copy_sha256), hashed again $($res.source_sha256_after)), so nothing was placed at $Destination"
            return $res
        }
        try {
            [System.IO.File]::Move($placing, $Destination)
            $placing = ''
            $renamed = $true
        } catch {
            if ([System.IO.File]::Exists($Destination) -or [System.IO.Directory]::Exists($Destination)) {
                $res.outcome = 'refused-destination-present'
                $res.code = 'DESTINATION-PRESENT'
                if ([System.IO.File]::Exists($Destination)) {
                    $res.destination_sha256_before = & $hashOf $Destination
                    $res.destination_sha256_after = $res.destination_sha256_before
                }
                $res.reason = "something arrived at $Destination while the copy was being made, and a result is never overwritten: nothing was placed"
                return $res
            }
            throw
        }
        $placed = Get-Item -LiteralPath $Destination
        $placed.CreationTimeUtc = $srcCreated
        $placed.LastWriteTimeUtc = $srcWritten
        $res.destination_sha256_after = & $hashOf $Destination
        $placed.LastAccessTimeUtc = $srcRead
        if ($res.destination_sha256_after -cne $res.source_sha256) {
            $res.outcome = 'refused-unverified'
            $res.code = 'UNVERIFIED'
            $res.reason = "the file renamed into place at $Destination hashes to $($res.destination_sha256_after), not the source's $($res.source_sha256); it is left there for the operator and is not a placement"
            return $res
        }
        $res.bytes = [long]$placed.Length
        $res.mtime = $srcWritten.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [System.Globalization.CultureInfo]::InvariantCulture)
        $res.outcome = 'placed'
        $res.code = 'PLACED'
        $res.reason = "placed at $Destination"
        return $res
    } catch {
        $res.outcome = 'refused-fault'
        $res.code = 'FAULT'
        $res.reason = "the placement could not be completed ($($_.Exception.Message)); $(if ($renamed) { "the copy WAS renamed into place at $Destination and is left there for the operator" } else { "nothing was placed at $Destination" })"
        return $res
    } finally {
        if ($placing -and [System.IO.File]::Exists($placing)) { try { [System.IO.File]::Delete($placing) } catch { } }
    }
}

# =============================================================================================
# NO RESULT AT SESSION END (BATCH-3 WP-K (a))
# =============================================================================================
# THE DEFECT. Spawn seq 211, D-V-A-596-R2: a headless validator started its full suite in the
# background, ended its turn, and its session exited 0 with no result file. This runner read "validator result --
# not-found", placed nothing and exited 3 -- which the ruling calls correct -- and the complete line the ceremony
# then composed for it was a bare null-result line. The round was re-issued for one more dispatch act.
#
# WHAT THIS RUNNER DOES NOW, AND ONLY FOR A VALIDATOR THAT DECLARES A result_path. When the session's process has
# exited and no file stands at that path in the validator's own tree, the runner asks which DESCENDANT processes of
# the session are still alive, WAITS for them to end -- never longer than -NoResultWaitSeconds -- and then lets the
# validator-result check further down read the result ONCE. A result that appeared is read, placed and bound exactly
# as one written before the exit. A result still absent is refused under a NAME, NO-RESULT-AT-SESSION-END-<CODE>, in
# the anchors, in the rejection record and in ONE spawn-ledger note:
#     NO-DESCENDANTS       none was alive at the session's exit, so nothing was waited for
#     DESCENDANTS-ENDED    some were alive, they ended inside the bound, and no result was there
#     BOUND-ELAPSED        some were still alive when the bound elapsed
#     DESCENDANTS-UNKNOWN  they could not be enumerated (the wait switched off with 0, or the session job could
#                          not be made or read), so nothing was waited for
# The exit code is the one it was: 3, through $handoffProblems. A session that wrote its result before it exited is
# not asked about, and no line of this is printed or recorded for it.
#
# HOW THE DESCENDANTS ARE ENUMERATED: A JOB OBJECT, NOT A PARENT-PID WALK. Before the spawn the runner makes an
# unnamed Windows job object and assigns ITS OWN process to it; every process created from then on by the runner, or
# by anything it started, is in that job, whoever its parent is and whether or not that parent is still alive. After
# the session exits, the job's live processes other than the runner are the session's descendants: the runner starts
# nothing else between the spawn's return and that reading. A parent-pid walk needs the session's pid, which
# `& claude` does not give, and it loses a descendant whose parent has exited; the job does neither.
# ITS REACH: processes created through the session's own process tree. ITS BLIND SIDE: a process started OUTSIDE that
# tree on the session's behalf -- by a service, the Task Scheduler, WMI's Win32_Process.Create, an elevation broker --
# and a process that asks to BREAK AWAY from the job (CREATE_BREAKAWAY_FROM_JOB). The job ALLOWS the break-away, so
# that a tool which asks for one behaves as it did before the job existed; such a process is not seen. The job sets
# no other limit and kills nothing; the runner stays in it for the rest of its run, and so does what it starts later
# (the suite). The reader is compiled once per run, as the reparse-tag reader below is; a job that cannot be made or
# read is DESCENDANTS-UNKNOWN, never a guess.
# WHAT THE BOUND DOES NOT COVER: a descendant that holds the session's own output handle. PowerShell's `& ... 2>&1`
# does not return until that handle closes -- before this change as after it -- so such a descendant is waited for by
# the spawn itself, unbounded, and has ended by the time the job is read. And the wait ends when the descendants do,
# not when a file appears: a result is read once, after its writers are gone.
$script:LamSessionJobState = ''
$script:LamSessionJobSource = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace LamDispatch {
    public static class SessionJob {
        [StructLayout(LayoutKind.Sequential)]
        private struct BasicLimit {
            public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
            public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct IoCounters { public ulong ReadOps; public ulong WriteOps; public ulong OtherOps; public ulong ReadBytes; public ulong WriteBytes; public ulong OtherBytes; }
        [StructLayout(LayoutKind.Sequential)]
        private struct ExtendedLimit {
            public BasicLimit Basic; public IoCounters Io;
            public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateJobObjectW(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimit info, int length);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool QueryInformationJobObject(IntPtr job, int infoClass, IntPtr info, int length, IntPtr returned);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);
        private static IntPtr job = IntPtr.Zero;
        // Makes the job, allows break-away (JOB_OBJECT_LIMIT_BREAKAWAY_OK, 0x800, through the extended limit class 9) and
        // assigns the calling process. Returns "" on success and otherwise what failed; a job that was made and could
        // not be joined is closed again.
        public static string Join() {
            if (job != IntPtr.Zero) { return ""; }
            IntPtr made = CreateJobObjectW(IntPtr.Zero, null);
            if (made == IntPtr.Zero) { return "the session job could not be created (" + new Win32Exception(Marshal.GetLastWin32Error()).Message + ")"; }
            ExtendedLimit limit = new ExtendedLimit();
            limit.Basic.LimitFlags = 0x800u;
            if (!SetInformationJobObject(made, 9, ref limit, Marshal.SizeOf(typeof(ExtendedLimit)))) {
                string why = new Win32Exception(Marshal.GetLastWin32Error()).Message;
                CloseHandle(made);
                return "the session job's break-away permission could not be set (" + why + ")";
            }
            if (!AssignProcessToJobObject(made, GetCurrentProcess())) {
                string why = new Win32Exception(Marshal.GetLastWin32Error()).Message;
                CloseHandle(made);
                return "this runner could not be assigned to the session job (" + why + ")";
            }
            job = made;
            return "";
        }
        // The ids of the job's live processes (JobObjectBasicProcessIdList, class 3), the caller's own among them.
        public static int[] Members() {
            if (job == IntPtr.Zero) { throw new InvalidOperationException("no session job was joined"); }
            int slots = 64;
            while (true) {
                int size = 8 + slots * IntPtr.Size;
                IntPtr buffer = Marshal.AllocHGlobal(size);
                try {
                    if (QueryInformationJobObject(job, 3, buffer, size, IntPtr.Zero)) {
                        int listed = Marshal.ReadInt32(buffer, 4);
                        int[] ids = new int[listed];
                        for (int i = 0; i < listed; i++) { ids[i] = (int)(long)Marshal.ReadIntPtr(buffer, 8 + i * IntPtr.Size); }
                        return ids;
                    }
                    int error = Marshal.GetLastWin32Error();
                    if ((error != 234) || (slots > 65536)) { throw new Win32Exception(error); }
                    slots *= 4;
                } finally { Marshal.FreeHGlobal(buffer); }
            }
        }
    }
}
'@
function Join-LamSessionJob {
    # '' when this process stands in the session job; otherwise the reason it does not. Asked once per run.
    if ($script:LamSessionJobState -ceq 'joined') { return '' }
    if ($script:LamSessionJobState) { return $script:LamSessionJobState }
    try {
        if (-not ('LamDispatch.SessionJob' -as [type])) { Add-Type -TypeDefinition $script:LamSessionJobSource -Language CSharp -ErrorAction Stop }
        $jobSaid = [string][LamDispatch.SessionJob]::Join()
        $script:LamSessionJobState = if ($jobSaid) { $jobSaid } else { 'joined' }
    } catch {
        $script:LamSessionJobState = "the session job could not be made ($(("$($_.Exception.Message)" -replace '\s+', ' ').Trim()))"
    }
    if ($script:LamSessionJobState -ceq 'joined') { return '' }
    return $script:LamSessionJobState
}
function Get-LamSessionDescendant {
    # The session job's live processes other than this runner: .ok, .error, and .list of { pid; name }.
    $res = [pscustomobject]@{ ok = $false; error = ''; list = @() }
    if ($script:LamSessionJobState -cne 'joined') {
        $res.error = if ($script:LamSessionJobState) { $script:LamSessionJobState } else { 'no session job was made for this spawn' }
        return $res
    }
    try {
        $found = @()
        foreach ($jobPid in @([LamDispatch.SessionJob]::Members())) {
            if ([int]$jobPid -eq $PID) { continue }
            $jobName = ''
            # A member that has exited between the job's reading and this one is not alive, and is not listed.
            try { $jobName = [string](Get-Process -Id ([int]$jobPid) -ErrorAction Stop).ProcessName } catch { continue }
            $found += [pscustomobject]@{ pid = [int]$jobPid; name = $jobName }
        }
        $res.list = @($found)
        $res.ok = $true
    } catch {
        $res.error = "the session job could not be read ($(("$($_.Exception.Message)" -replace '\s+', ' ').Trim()))"
    }
    return $res
}
function Wait-LamSessionDescendant {
    # Waits, no longer than $BoundSeconds, for the session job to hold no live process but this runner. $First is the
    # reading taken as the session exited. Returns the code of the four named above, what was seen then, what was
    # still alive at the end, and how long was waited. A process a descendant starts during the wait is in the job
    # too, and is waited for like the rest.
    param($First, [int]$BoundSeconds)
    $res = [pscustomobject]@{ code = 'DESCENDANTS-UNKNOWN'; seen = @(); alive = @(); waited_ms = [long]0; bound_seconds = $BoundSeconds; bound_elapsed = $false; error = '' }
    if (-not $First.ok) { $res.error = [string]$First.error; return $res }
    $res.seen = @($First.list)
    if ($res.seen.Count -eq 0) { $res.code = 'NO-DESCENDANTS'; return $res }
    $boundMs = [long]$BoundSeconds * 1000
    $alive = @($First.list)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (($alive.Count -gt 0) -and ($sw.ElapsedMilliseconds -lt $boundMs)) {
        Start-Sleep -Milliseconds ([int][Math]::Max(1, [Math]::Min(250, ($boundMs - $sw.ElapsedMilliseconds))))
        $now = Get-LamSessionDescendant
        if (-not $now.ok) {
            $sw.Stop()
            $res.waited_ms = [long]$sw.ElapsedMilliseconds
            $res.alive = @($alive)
            $res.error = [string]$now.error
            return $res
        }
        $alive = @($now.list)
    }
    $sw.Stop()
    $res.waited_ms = [long]$sw.ElapsedMilliseconds
    $res.alive = @($alive)
    if ($alive.Count -gt 0) { $res.code = 'BOUND-ELAPSED'; $res.bound_elapsed = $true } else { $res.code = 'DESCENDANTS-ENDED' }
    return $res
}

# --- the declared expected-failure set -------------------------
# Read-FlatYaml above cannot see this file: the mirror's `expected_failures:` key carries a BLOCK
# list, which that reader explicitly does not implement. This reader is for that one key and is used
# at exactly one site (the suite anchor). REACH, STATED: the block form (`expected_failures:` then
# `  - <id>` lines) and the inline form (`expected_failures: [a, b]`); `expected_failures: []`
# declares NONE; `#` comment lines are ignored.
#
# ABSENT vs EMPTY is the distinction the whole member turns on, so it is carried in the RETURN TYPE
# rather than in a count: $null means the file is not there (declares nothing, and the suite anchor
# writes the member false with the note `absent`); an empty array means the file is there and
# declares no expected failure (a clean run over it matches). A function that returned @() for both
# would erase exactly the difference the caller needs.
function Read-DeclaredExpectedFailures {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $ids = New-Object System.Collections.Generic.List[string]
    $inBlock = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^expected_failures:\s*(.*)$') {
            # $Matches is GLOBAL and the next -match overwrites it, so take the capture out first.
            $rest = $Matches[1].Trim()
            $inBlock = $false
            if ($rest -match '^\[(.*)\]$') {
                $inner = $Matches[1].Trim()
                if ($inner) {
                    foreach ($part in ($inner -split ',')) {
                        $t = $part.Trim().Trim('"').Trim("'")
                        if ($t) { [void]$ids.Add($t) }
                    }
                }
            } elseif (-not $rest) {
                $inBlock = $true
            }
            continue
        }
        if ($inBlock) {
            if ($line -match '^\s+-\s*(.*)$') {
                $t = $Matches[1].Trim().Trim('"').Trim("'")
                if ($t) { [void]$ids.Add($t) }
                continue
            }
            if ($line.Trim() -eq '') { continue }
            # any other top-level or non-item line ends the block
            $inBlock = $false
        }
    }
    # the comma keeps a single-element or empty result an ARRAY through the return
    return ,$ids.ToArray()
}

# --- the declared repairs ---------------------------
# Read-FlatYaml cannot see this key either: `declared_repairs:` carries a BLOCK LIST OF MAPS, which
# is two shapes past that reader's stated reach. One key, one reader, one call site -- the same
# arrangement the expected-failure mirror's reader above uses.
#
# ALL THREE FIELDS ARE REQUIRED OF EVERY ENTRY, and a missing one is an ERROR rather than a skipped
# entry. `test_id` is what the admission and the delivery check both compare against; `reason` and
# `repairing_commit_label` are what make the declaration answerable by a human reading the artifact
# afterwards -- a bare list of ids would admit a basis on an unexplained assertion, which is the
# operator-admitted flag an earlier revision struck, spelled differently.
#
# PRESENT BUT UNREADABLE FAILS LOUD, for the reason every other declaration reader in this toolchain
# gives: "I could not read your declaration" and "you made no declaration" are different facts and
# must not share a return value. `declared:$false` with no error is the second; an error is the first.
function Read-DeclaredRepairs {
    param([string]$Path)
    $out = [pscustomobject]@{ declared = $false; entries = @(); test_ids = @(); error = $null }
    if (-not (Test-Path -LiteralPath $Path)) { return $out }

    $entries = New-Object System.Collections.Generic.List[object]
    $cur     = $null
    $inBlock = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^declared_repairs:\s*(.*)$') {
            $rest = $Matches[1].Trim()
            $out.declared = $true
            if ($rest) {
                # The inline form is not implemented and is REPORTED rather than half-parsed: an
                # inline `[a, b]` carries ids with no reason and no commit label, so it could not be
                # a well-formed declaration even if it parsed.
                $out.error = "UNREADABLE declared_repairs at ${Path}: the key carries an inline value ('$rest'). This reader implements the BLOCK form only -- each entry a '- test_id:' item with 'reason:' and 'repairing_commit_label:' beneath it"
                return $out
            }
            $inBlock = $true
            continue
        }
        if (-not $inBlock) { continue }
        # A column-0 key ends the block. Without this the next top-level key's value would be read
        # as a field of the last entry.
        if ($line -match '^\S') { $inBlock = $false; continue }
        if ($line -match '^\s+-\s*test_id:\s*(.*?)\s*$') {
            # CAPTURE IMMEDIATELY: $Matches is global and the next -match overwrites it.
            $idVal = $Matches[1].Trim().Trim('"').Trim("'")
            if ($cur) { [void]$entries.Add($cur) }
            $cur = [pscustomobject]@{ test_id = $idVal; reason = ''; repairing_commit_label = '' }
            continue
        }
        if ($null -eq $cur) { continue }
        if ($line -match '^\s+reason:\s*(.*?)\s*$')                 { $cur.reason                 = $Matches[1].Trim().Trim('"').Trim("'"); continue }
        if ($line -match '^\s+repairing_commit_label:\s*(.*?)\s*$') { $cur.repairing_commit_label = $Matches[1].Trim().Trim('"').Trim("'"); continue }
    }
    if ($cur) { [void]$entries.Add($cur) }
    if (-not $out.declared) { return $out }

    if ($entries.Count -eq 0) {
        $out.error = "UNREADABLE declared_repairs at ${Path}: the key is present but no entry could be parsed from it. A declaration that cannot be read is not an absent declaration"
        return $out
    }
    $bad = @()
    foreach ($e in $entries) {
        $miss = @()
        if (-not $e.test_id)                { $miss += 'test_id' }
        if (-not $e.reason)                 { $miss += 'reason' }
        if (-not $e.repairing_commit_label) { $miss += 'repairing_commit_label' }
        if ($miss.Count -gt 0) { $bad += "entry '$(if ($e.test_id) { $e.test_id } else { '(no test_id)' })' is missing: $($miss -join ', ')" }
    }
    $out.entries = @($entries.ToArray())
    if ($bad.Count -gt 0) {
        $out.error = "MALFORMED declared_repairs at ${Path}: $($bad -join ' ; '). Every entry requires test_id, reason and repairing_commit_label -- a declared set is honoured exactly or not at all"
        return $out
    }
    $out.test_ids = @($out.entries | ForEach-Object { $_.test_id })
    return $out
}

# --- the basis's unexpected-failure set --------------------------------
# WHERE THE OBSERVED SET COMES FROM, and why it is this file. The declared-repair admission compares
# the declaration against what the BASIS actually observed, and the basis's `suite:` block is the
# only runner-observed record of it: the suite anchor writes `expected_failures_note` as
# `declared N; failed M; unexpected K[: <id> <id> ...]` from the suite the runner itself ran. Verify
# does not carry the ids -- it reports the subject DIVERGED and stops -- so reading them off the
# report would give a count and no names.
#
# THE COUNT IS CHECKED AGAINST THE NAMES, and a disagreement is UNREADABLE rather than a best guess.
# `K` and the id list are written by the same statement, so they can only disagree if the note was
# truncated, re-wrapped, or hand-edited -- and a set parsed out of a damaged note would be compared
# for EQUALITY against the declaration, where one lost id silently becomes an admission the mission
# never declared. Unreadable returns $null, the admission gets an empty observed set, and the
# equality test refuses.
function Read-BasisUnexpectedFailures {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $note = $null
    $inSuite = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s{2}suite:\s*$') { $inSuite = $true; continue }
        if (-not $inSuite) { continue }
        if ($line -match '^\s{4}expected_failures_note:\s*(.*?)\s*$') { $note = $Matches[1]; break }
        if ($line.Trim() -eq '') { continue }
        if ($line -match '^\s{4}\S') { continue }
        $inSuite = $false
    }
    if ($null -eq $note) { return $null }
    # Single-quoted by the writer, with any inner quote doubled.
    $n = $note.Trim()
    if ($n.Length -ge 2 -and $n.StartsWith("'") -and $n.EndsWith("'")) { $n = ($n.Substring(1, $n.Length - 2) -replace "''", "'") }
    if ($n -notmatch 'unexpected\s+(\d+)') { return $null }
    $count = [int]$Matches[1]
    if ($count -eq 0) { return ,@() }
    if ($n -notmatch 'unexpected\s+\d+:\s*(.+)$') { return $null }
    $ids = @(($Matches[1].Trim()) -split '\s+' | Where-Object { $_ })
    if ($ids.Count -ne $count) { return $null }
    return ,$ids
}

# THE SCHEMA HALF: THE ANCHORS LEARN WHAT ORIGIN HELD, OR WHY NOBODY COULD SAY.
#
# THE DEFECT AS REGISTERED: verify's ORIGIN-ATTESTATION arm "did not engage at DIAG's
# R-1: no runner_anchors.origin_tip field exists in any schema ... so the arm has nothing to
# compare and reports 'a finding for ruling'". REPRODUCED at this parent rather than inferred:
# mission-verify.ps1 --against a real .mission/dispatches/*.anchors.yaml puts ORIGIN-ATTESTATION in
# arms_not_run carrying exactly that sentence, and THE SAME FILE with one origin_tip line planted
# engages the arm, issues `git ls-remote origin refs/heads/<branch>` and reports on it. The missing
# field is the whole of the gap; nothing else about the arm is broken.
#
# NULL IS A FIRST-CLASS ANSWER AND IT CARRIES ITS REASON. mission-verify.ps1:1337-1339 treats a
# null claim exactly as it treats an absent one -- the arm stays disengaged -- and that is RIGHT: an
# origin nobody could read is no claim about origin, and writing one would be manufacturing the
# leg. But it makes this artifact the only place where "unreachable", "no such branch" and "nobody
# asked" can be told apart. So the reason is written on EVERY outcome, never only on failure.
#
# UNREACHABLE AND ABSENT ARE NOT MERGED. `git ls-remote` conflates them -- the conflation
# mission-verify records at spec:73-76 and 385-387, and the one record-origin-attestation.ps1:294
# refuses over -- and the ONLY separator is the exit code with no ref line. Exit 0 with no ref line
# is ABSENT; a non-zero exit is UNREACHABLE. Both are recorded, and neither is inferred.
#
# IT CANNOT HANG AND IT CANNOT KILL THE RUN. This is the only NETWORK call in this runner. It is
# bounded by a wall clock and the process is KILLED at the bound; GIT_TERMINAL_PROMPT=0 stops git
# blocking on a terminal credential prompt; and every failure path -- git absent, origin absent,
# detached HEAD, timeout, throw -- lands on null-with-a-reason. Nothing here throws past its caller
# and nothing here refuses a dispatch. The reading is a RECORD of the run, exactly as the anchors
# are, and destroying a completed run over its own record would lose the record with it.
#
# THE ORIGIN URL IS NEVER RECORDED. It is consulted only to tell "no origin configured" from
# "origin did not answer". A remote URL can carry userinfo -- mission-verify.ps1 carries
# Assert-NoUserInfo for precisely that hazard -- and an anchors file is a durable artifact a
# reviewer reads.
#
# NOT SHARED WITH tools/lam/record-origin-attestation.ps1, and the reason is not neatness. That
# file is a SCRIPT, not a library: its ls-remote is top-level code (:271-284) gated on a push-gate
# artifact declaring origin_url and remote_ref, and its answer to a silent origin is Write-Refusal
# and exit 4. Dot-sourcing it would run its param block, its gate reads and its exits. This runner
# needs the opposite contract -- never refuse, always degrade -- and it asks about the branch THIS
# mission root is on rather than about a gate's declared triple. Nothing there is reusable as-is;
# extracting a function from it would mean editing a file this seat does not own.
function Get-LamOriginTip {
    param(
        [Parameter(Mandatory = $true)][string]$MissionRoot,
        [int]$TimeoutSeconds = 20
    )
    $res = [pscustomobject]@{ sha = $null; ref = $null; exit_code = $null; reason = 'not attempted' }
    if (-not $MissionRoot) {
        $res.reason = 'no mission root was supplied, so no repository could be asked'
        return $res
    }

    # THE LOCAL READS, IN THIS FILE'S OWN IDIOM. "$x" and NOT [string]$x: a native command that
    # printed nothing returns an EMPTY ARRAY and [string]@() is $null, so .Trim() would throw on the
    # ordinary case. $LASTEXITCODE is consulted on the very next line. Both calls are local and
    # instantaneous and neither can reach a network.
    $branch = ''
    $topLevel = ''
    $originConfigured = $false
    $localError = ''
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # THE ROOT MUST BE THE REPOSITORY'S OWN TOP LEVEL, AND THIS IS NOT A FORMALITY. `git -C <dir>`
        # WALKS UP: pointed at a directory that merely LIVES INSIDE some other repository, it answers
        # with that repository's branch and that repository's origin. Driven during this build -- a
        # probe aimed at a scratch directory inside this worktree came back carrying a foreign
        # branch, on its way into an anchors file. That is the same "one anchor block describing TWO
        # REPOSITORIES" defect the head_sha note above records, and it is refused here rather than
        # recorded.
        $tl = & git -C $MissionRoot rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -eq 0) { $topLevel = ("$tl").Trim() }
        $br = & git -C $MissionRoot rev-parse --abbrev-ref HEAD 2>&1
        if ($LASTEXITCODE -eq 0) { $branch = ("$br").Trim() }
        # THE URL IS CONSULTED AND DISCARDED. Only whether one EXISTS is kept -- see the header.
        $ou = & git -C $MissionRoot config --get remote.origin.url 2>&1
        $originConfigured = (($LASTEXITCODE -eq 0) -and (("$ou").Trim() -ne ''))
    } catch {
        $localError = $_.Exception.Message
    } finally { $ErrorActionPreference = $prevEap }
    if ($localError) {
        $res.reason = "the mission root could not be asked for a branch or a remote: $localError"
        return $res
    }
    if (-not $topLevel) {
        $res.reason = 'the mission root is not inside a git repository (git rev-parse --show-toplevel did not answer), so there is no origin to ask. NOTHING WAS ASKED.'
        return $res
    }
    # Compared as FULL PATHS with separators normalised: git answers in forward slashes, Windows
    # hands this runner backslashes, and a case difference between C:\ and c:\ is not a difference.
    $tlNorm   = ''
    $rootNorm = ''
    try {
        $tlNorm   = ([System.IO.Path]::GetFullPath(($topLevel -replace '/', '\'))).TrimEnd('\')
        $rootNorm = ([System.IO.Path]::GetFullPath(([string]$MissionRoot -replace '/', '\'))).TrimEnd('\')
    } catch { $tlNorm = ''; $rootNorm = '' }
    if ((-not $tlNorm) -or (-not $rootNorm) -or ($tlNorm -ne $rootNorm)) {
        $res.reason = "the mission root is NOT the top level of the repository git found from it (git says '$topLevel'), so any branch or origin read here would belong to a DIFFERENT repository. NOTHING WAS ASKED."
        return $res
    }
    if (-not $branch) {
        $res.reason = 'no branch could be resolved at the mission root (git rev-parse --abbrev-ref HEAD did not answer), so no ref could be named. NOTHING WAS ASKED of origin.'
        return $res
    }
    if ($branch -eq 'HEAD') {
        $res.reason = 'the mission root is on a DETACHED HEAD, so there is no branch whose origin tip could be read. NOTHING WAS ASKED of origin.'
        return $res
    }
    $res.ref = "refs/heads/$branch"
    if (-not $originConfigured) {
        $res.reason = "no remote named 'origin' is configured at the mission root, so there is nowhere to read $($res.ref) from. NOTHING WAS ASKED -- this is not unreachable."
        return $res
    }

    # A TRAILING SEPARATOR WOULD ESCAPE THE CLOSING QUOTE. Start-Process joins ArgumentList with
    # spaces and does no quoting, so the root is quoted here -- and "C:\x\" would reach the CRT
    # argv parser as an escaped quote and swallow the rest of the command line.
    $rootArg = ([string]$MissionRoot).TrimEnd('\', '/')
    # BUILT IN ASSIGNMENT POSITION AND ITS ARITY ASSERTED. An array literal in ARGUMENT position
    # splits silently in PS 5.1 as soon as one element is a concatenation, and a five-element vector
    # arriving as seven would ask origin a question nobody wrote.
    $argv = @('-C', ('"' + $rootArg + '"'), 'ls-remote', 'origin', $res.ref)
    if ($argv.Count -ne 5) {
        $res.reason = "INTERNAL: the ls-remote argument vector came out with $($argv.Count) elements instead of 5, so nothing was launched"
        return $res
    }

    $outFile = Join-Path ([System.IO.Path]::GetTempPath()) ("lam-origin-$([guid]::NewGuid().ToString('N')).out")
    $errFile = Join-Path ([System.IO.Path]::GetTempPath()) ("lam-origin-$([guid]::NewGuid().ToString('N')).err")
    # GIT MUST NOT BE ABLE TO BLOCK ON A PROMPT. GIT_TERMINAL_PROMPT=0 turns a terminal credential
    # prompt into a fast failure; credential HELPERS still answer, so an authenticated origin keeps
    # working and this does not quietly convert a reachable origin into an unreachable one. It is
    # RESTORED to what it was, and REMOVED when it was unset -- an empty value is not an absent one,
    # and git reads the empty string as false.
    # SET AND RESTORED THROUGH THE .NET PRIMITIVE, NOT THROUGH THE Env: PROVIDER. The first drive of
    # this function left GIT_TERMINAL_PROMPT=0 standing in the caller's process after the rows that
    # reached a network, and `Remove-Item Env:\...` is a provider call whose failure an
    # -ErrorAction can swallow. SetEnvironmentVariable(..., $null, 'Process') is the same operation
    # with no provider, no error stream and no preference to honour; $null REMOVES the variable,
    # where assigning '' would leave an empty one standing and git reads the empty string as false.
    # The leak has not reappeared since, and the restore is now driven on every row.
    $prevPrompt = [System.Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT', 'Process')
    [System.Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', '0', 'Process')
    $launchError = ''
    $timedOut    = $false
    $code        = $null
    try {
        # A CMDLET, NOT A NATIVE INVOCATION: no NativeCommandError can be raised by the child's
        # stderr here. The streams go to FILES rather than to pipes this process would have to
        # drain, which is the shape that cannot deadlock on a full pipe buffer while it waits.
        $proc = Start-Process -FilePath 'git' -ArgumentList $argv -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        # TOUCHING .Handle IS LOAD-BEARING AND IS NOT A SUPERSTITION. A Start-Process -PassThru
        # object in PS 5.1 does not cache the process handle, and once the child exits the kernel
        # object is gone and .ExitCode reports nothing -- the first drive of this function came back
        # "no exit code could be read back" on EVERY row that reached the network, which would have
        # collapsed UNREACHABLE and ABSENT into one silence: exactly what this field exists to keep
        # apart. Reading .Handle here makes .NET cache it, and .ExitCode answers afterwards.
        try { $null = $proc.Handle } catch { }
        if ($proc.WaitForExit($TimeoutSeconds * 1000)) {
            # The parameterless overload returns at once for a process that has already exited, and
            # it is what flushes the redirected streams before they are read.
            $proc.WaitForExit()
            try { $code = $proc.ExitCode } catch { $code = $null }
        } else {
            $timedOut = $true
            try { $proc.Kill() } catch { }
        }
    } catch {
        $launchError = $_.Exception.Message
    } finally {
        # $prevPrompt is $null when the variable was unset, and passing $null back REMOVES it -- so
        # the absent case and the present case are one line, with no branch to get the wrong way round.
        [System.Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', $prevPrompt, 'Process')
    }

    $stdout = ''
    $stderr = ''
    try {
        if (Test-Path -LiteralPath $outFile) { $stdout = [System.IO.File]::ReadAllText($outFile) }
        if (Test-Path -LiteralPath $errFile) { $stderr = [System.IO.File]::ReadAllText($errFile) }
    } catch { }
    Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue

    if ($launchError) {
        $res.reason = "git ls-remote could not be launched at all, so origin was never asked: $launchError"
        return $res
    }
    if ($timedOut) {
        $res.reason = "git ls-remote did not answer within $TimeoutSeconds seconds and the process was TERMINATED. UNREACHABLE, not absent -- origin was asked and did not reply in time."
        return $res
    }
    if ($null -eq $code) {
        $res.reason = "git ls-remote ran but no exit code could be read back from the process, so unreachable and absent cannot be separated. NEITHER is claimed."
        return $res
    }
    $res.exit_code = [int]$code

    foreach ($lsLine in ($stdout -split '\r?\n')) {
        if ($lsLine -match '^([0-9a-fA-F]{40})\s+(\S+)\s*$') {
            if ($Matches[2] -eq $res.ref) { $res.sha = $Matches[1].ToLowerInvariant(); break }
        }
    }
    if ($res.sha) {
        $res.reason = "read from 'git ls-remote origin $($res.ref)' at the mission root, exit 0. A SAME-HOST reading -- this runner's PATH, its network path and its credential store -- which is the MIDDLE RUNG and is NOT origin-side attestation."
        return $res
    }
    $whyText = (@(($stderr -split '\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' | ')
    if ($whyText.Length -gt 400) { $whyText = $whyText.Substring(0, 400) + ' ...(truncated)' }
    if (-not $whyText) { $whyText = '(no stderr)' }
    if ($code -eq 0) {
        $res.reason = "git ls-remote origin ANSWERED (exit 0) and origin carries no $($res.ref). ABSENT, not unreachable -- the branch has not been pushed."
    } else {
        $res.reason = "git ls-remote origin exited $code without answering for $($res.ref). UNREACHABLE, not absent -- this command does not separate the two and neither is claimed here. stderr: $whyText"
    }
    return $res
}

function Get-RoutedModel {
    param([string]$RoutingPath, [string]$RoleName)
    if (-not (Test-Path -LiteralPath $RoutingPath)) { return $null }
    $inRole = $false
    $model  = $null
    $live   = $null
    foreach ($line in [System.IO.File]::ReadAllLines($RoutingPath)) {
        if ($line -match '^\s\s([A-Za-z0-9_-]+):\s*$') {
            $inRole = ($Matches[1] -eq $RoleName)
            continue
        }
        if ($line -match '^\S') { $inRole = $false; continue }
        if ($inRole) {
            if ($line -match '^\s{4}model:\s*(\S+)') { $model = $Matches[1] }
            if ($line -match '^\s{4}live:\s*(\S+)')  { $live  = $Matches[1] }
        }
    }
    if (-not $model) { return $null }
    # policy.not_live_role: refuse. A silent default is how a validator ends up on the small model.
    if ($live -and ($live -eq 'false')) { return $null }
    return $model
}

# =============================================================================================
# inputs
# =============================================================================================
if (-not (Test-Path -LiteralPath $MissionRoot -PathType Container)) {
    Deny-Dispatch "mission root does not exist: $MissionRoot"
}
$MissionRoot = (Resolve-Path -LiteralPath $MissionRoot).Path

# THE WORKER WORKTREE HOME IS A SIBLING OF THE MISSION ROOT (operator ruling), so
# its two parts are read HERE, before anything else is read from the mission root. A root with no
# parent directory or no leaf name -- a drive root such as C:\ -- has no sibling, and composing one
# anyway yields a path nobody chose (a 'C:-worktrees' or a bare separator). It is REFUSED rather than
# guessed, and refused before the dispatch artifact is looked for, so a drive root is refused for
# what it is and not for the artifact it cannot hold. A PROVIDER-QUALIFIED root -- Resolve-Path's
# spelling of a UNC share, 'Microsoft.PowerShell.Core\FileSystem::\\host\share\...' -- is refused the
# same way: measured on PS 5.1, GetDirectoryName folds its '\\' to '\', and git cannot read the
# prefix at all, so no worktree could be placed from it.
$missionRootTrimmed = ([string]$MissionRoot).TrimEnd('\', '/')
$missionRootParent  = ''
$missionRootLeaf    = ''
if ($missionRootTrimmed -notmatch '::') {
    try {
        $missionRootParent = [string][System.IO.Path]::GetDirectoryName($missionRootTrimmed)
        $missionRootLeaf   = [string][System.IO.Path]::GetFileName($missionRootTrimmed)
    } catch { $missionRootParent = ''; $missionRootLeaf = '' }
}
if ((-not $missionRootParent) -or (-not $missionRootLeaf)) {
    Deny-Dispatch "the mission root '$MissionRoot' has no parent directory and leaf name, so the worker worktree home <parent>\<leaf>-worktrees\wt-<dispatch> cannot be derived from it. A drive root or a provider-qualified path has no sibling; place the mission in a named directory."
}

$dispatchPath = Join-Path $MissionRoot ".mission\dispatches\$Dispatch.yaml"
if (-not (Test-Path -LiteralPath $dispatchPath)) {
    Deny-Dispatch "no dispatch artifact at $dispatchPath"
}

# NAMED $dispatchDoc, NOT $dispatch, AND THAT IS LOAD-BEARING. PowerShell variable names are
# CASE-INSENSITIVE, so `$dispatch` and the `-Dispatch` parameter are THE SAME VARIABLE. Assigning
# the parsed map to `$dispatch` replaced the dispatch id with a Hashtable, and every path derived
# from it afterwards became ".mission\dispatches\System.Collections.Hashtable.yaml". The runner
# still exited 0 and reported success, which is exactly the shape of defect this program exists to
# refuse -- it was caught by driving the runner, not by reading it.
$dispatchDoc = Read-FlatYaml -Path $dispatchPath

# =============================================================================================
# THE IDENTITY-AGREEMENT LINT, A PRE-SPAWN REFUSAL
# =============================================================================================
# THE DEFECT, REPRODUCED FROM DISK BEFORE THIS WAS WRITTEN. A validator round brief is hand-authored
# YAML in the mission plane, and this runner reads it VERBATIM as the prompt: there is no generator,
# no template engine, and nothing here authors a byte of it. So when a round-2 artifact was made by
# copying its round-1 predecessor, the RESULT TEMPLATE -- the block that tells the validator what to
# write -- kept the predecessor's values. `.mission/dispatches/D-V-A-575-R2.yaml` is that file on
# this repository: its own `id:` is D-V-A-575-R2 (:16) and its own `round:` is 2 (:30), while the
# result template it hands the validator says `round: 1` (:207) and `dispatch_id: D-V-A-575` (:208).
# Nothing read either line, so nothing could disagree with it, and the validator wrote the true
# values under keys that claimed otherwise -- its own finding.
#
# THE RULE, NAMED: SELF-REFERENTIAL IDENTITY AGREEMENT. Every claim the artifact makes about ITS OWN
# identity must agree with the dispatch this runner was actually told to run. It is a rule about
# IDENTITY FIELDS -- `id`, `dispatch_id`, `round` -- and not a special case for any one key.
#
# THE WHOLE DIFFICULTY IS THE OTHER DIRECTION, AND IT IS SETTLED BY MEASUREMENT RATHER THAN BY
# TASTE. A brief routinely names ANOTHER dispatch as a subject to judge, and a lint that refused
# those would be unusable. So the census was taken first, over all 39 dispatch artifacts under
# `.mission/dispatches`: 65 indented identity-key lines exist, 62 of them inside a `brief:` block
# and 3 in the structured head. ALL THREE head ones sit under `predecessor_round:` /
# `predecessor_rounds:` (D-V-A-581-R2:65, D-V-A-581-R3:68 and :73) and deliberately name an earlier
# round. NOT ONE brief cites another dispatch as an identity KEY LINE: briefs cite by PATH and in
# PROSE (a `.mission/dispatches/<id>.handoff.yaml` path, or an `<id>:<line>` reference). That is the line this
# lint draws, and it is the corpus's line rather than one invented here:
#
#   A SELF-REFERENTIAL CLAIM is an indented `key: value` line, inside the block scalar the artifact
#     ships as its INSTRUCTION (`brief:`), whose key is an identity field.
#   A CITATION is everything else -- a key in the structured head, a path, a sentence.
#
# AND IT IS NARROWED ONCE MORE, on the same evidence. A `dispatch_id:` in the brief refuses ONLY
# when it names a DIFFERENT ROUND OF THIS SAME SERIES -- the same id once a trailing `-R<n>` suffix
# is stripped. A brief naming an unrelated dispatch is a citation and is not touched at all. The
# narrowing is principled rather than convenient: a predecessor round is cited in the HEAD on this
# mission, three artifacts doing exactly that, so a predecessor's id appearing inside the
# instruction's own result template has no honest reading left.
#
# WHAT THIS DOES NOT CHECK, STATED RATHER THAN IMPLIED:
#   * FREE-FORM ID LABELS. D-V-A-575-R2:204 also carries `id: V-1-round-1-A-575` -- the third of the
#     three values the register names -- and its round lives inside a prose label. Parsing that is a
#     special case for one spelling, so it is not done. The line is caught INDIRECTLY, by the
#     `round: 1` three lines below it in the same template, which refuses the artifact and sends the
#     seat back to the whole block.
#   * THE STRUCTURED HEAD'S NESTED MAPPINGS. Deliberate: that is the citation slot.
#   * ANY BLOCK SCALAR OTHER THAN `brief:`. D-V-A-581-R2 carries `record_entry_content: |`, a QUOTED
#     SUBJECT rather than an instruction, and an identity line inside a quoted document is not a
#     claim about this run. The reach is one key, and this sentence is the reach.
#   * A `dispatch_id:` NAMING AN UNRELATED SERIES. That is indistinguishable from a citation without
#     more context, and refusing it is the unusable lint this row was warned against.
#   * THE ROUND SUFFIX IN THE ID AGAINST THE `round:` FIELD. A naming convention, not a claim.
#
# THE COMPARISON IS AGAINST WHAT THE RUNNER WAS TOLD TO RUN, never against what the file says about
# itself, because a file that lies about its own id would otherwise be checked against its own lie.
# Read-FlatYaml cannot see any of this: its key pattern is anchored at COLUMN 0, so every indented
# line inside a block scalar is invisible to it and `brief: |` reads as the scalar "|". So the lint
# reads the artifact's TEXT -- which is also exactly what the worker is about to be handed.
#
# CHEAP, AND REFUSING BEFORE ANYTHING IS TOUCHED: one pass over the lines of a file this runner has
# already opened, before the model is routed, before the decider is checked and before the id-reuse
# guard. No process is started and nothing is written.
function Get-DispatchSeriesStem {
    param([string]$Id)
    return ($Id -replace '-R[0-9]+[A-Za-z]*$', '')
}

$identityProblems = @()
$statedId = ([string]$dispatchDoc['id']).Trim()
if ($statedId -and ($statedId -ne $Dispatch)) {
    $identityProblems += "the artifact's own top-level 'id:' states '$statedId', but this run was told to run '$Dispatch'"
}
$statedRound  = ([string]$dispatchDoc['round']).Trim()
$thisStem     = Get-DispatchSeriesStem -Id $Dispatch
$inBriefBlock = $false
$identLine    = 0
foreach ($identText in [System.IO.File]::ReadAllLines($dispatchPath)) {
    $identLine++
    if ($identText -match '^brief:\s*[|>][-+0-9]*\s*$') { $inBriefBlock = $true; continue }
    # A block scalar opened by a COLUMN-0 key ends at the next non-blank COLUMN-0 line, because its
    # content must be indented deeper than the key that opened it. That is the whole scope rule.
    if ($identText.Trim() -and ($identText -notmatch '^\s')) { $inBriefBlock = $false }
    if (-not $inBriefBlock) { continue }
    if ($identText -notmatch '^\s+([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') { continue }
    $identKey = $Matches[1]
    $identVal = $Matches[2].Trim().Trim('"').Trim("'")
    if ($identKey -eq 'dispatch_id') {
        if ($identVal -and ($identVal -ne $Dispatch) -and ((Get-DispatchSeriesStem -Id $identVal) -eq $thisStem)) {
            $identityProblems += "line ${identLine}: the brief states 'dispatch_id: $identVal', which is a DIFFERENT ROUND of this same dispatch series ('$thisStem'). The dispatch being run is '$Dispatch'"
        }
    } elseif ($identKey -eq 'round') {
        if (($identVal -match '^[0-9]+$') -and ($statedRound -match '^[0-9]+$') -and ($identVal -ne $statedRound)) {
            $identityProblems += "line ${identLine}: the brief states 'round: $identVal', but this artifact's own top-level 'round:' is $statedRound"
        }
    }
}
if ($identityProblems.Count -gt 0) {
    Write-Line "mission-dispatch: REFUSED -- this dispatch artifact contradicts itself about its own identity (register row 130)."
    foreach ($identProblem in $identityProblems) { Write-Line "  $identProblem" }
    Write-Line "  The artifact IS the prompt and nothing authors it, so a stale value in its result template"
    Write-Line "  reaches the worker as an instruction. A round brief copied from its predecessor carries the"
    Write-Line "  predecessor's id, round and dispatch_id under the template's keys; correct the artifact."
    Write-Line "  A brief that CITES another dispatch is untouched by this rule."
    exit 2
}

# Hoisted above the gate: R-1 as amended must know, BEFORE admitting a PASS-DIB, whether this
# dispatch can produce the runner-observed tally that binds the admitted subjects.
$suiteCmd = [string]$dispatchDoc['suite_command']

# THE DECLARED REPAIRS: the declaration is read HERE, beside the suite command, because it is bound to it.
# A declared repair is a debt the worker's own suite run has to discharge, so a dispatch that
# declares one and runs no suite could never be shown to have paid it -- and would reach its end
# with the assertion unmakeable. Refusing before the spawn costs nothing; refusing after costs a
# worker. A MALFORMED declaration refuses here too: it is present, it could not be read, and
# proceeding would mean proceeding on a declaration nobody could check.
$declaredRepairs = Read-DeclaredRepairs -Path $dispatchPath
if ($declaredRepairs.error) { Deny-Dispatch $declaredRepairs.error }
if ($declaredRepairs.declared -and (-not $suiteCmd)) {
    Deny-Dispatch "this dispatch declares $($declaredRepairs.test_ids.Count) repair(s) but no suite_command, so nothing at the end of the dispatch could show the declared test(s) passing. A declared repair is a debt, and a debt with no means of settlement is not a declaration"
}

$routingPath = Join-Path $RepoRoot 'model-routing.yaml'
$roleForRun  = if ($dispatchDoc['model_class']) { [string]$dispatchDoc['model_class'] } else { $Role }
if ($PSBoundParameters.ContainsKey('Role')) { $roleForRun = $Role }
$model = Get-RoutedModel -RoutingPath $routingPath -RoleName $roleForRun
if (-not $model) {
    Deny-Dispatch "role '$roleForRun' is absent from $routingPath or is flagged live:false (policy: refuse, never fall back)"
}

# ================================================================================================
# THE PUBLICATION DECIDER MUST BE INSTALLED, OR THIS DISPATCH DOES NOT RUN.
# ================================================================================================
# An earlier revision moved T-2's publication guarantee off the PreToolUse tripwire, which three V-1 rounds
# proved cannot carry it, and onto a `pre-push` hook that git runs after every shell expansion. That
# hook can be deleted -- so the ruling answers deletion with DETECTION rather than by pretending it
# cannot happen, and this is one of the three links in that chain:
#
#   * WP-4 asserts the hook's presence and sha256, so a removed or edited decider reddens the suite;
#   * THIS refusal stops a dispatch from running in a repository whose decider is missing or altered;
#   * and S-4 still binds to what ORIGIN holds, so even a defeated decider leaves the mismatch
#     between origin and the gate register as the finding.
#
# MEASURED, not assumed: with the decider removed from a fixture, `G=git; $G push origin main` and
# `echo push origin main | xargs git` BOTH published an ungated bare origin -- the exact round-11
# refutation reproduced. With it installed, both are refused and origin does not move. So a dispatch
# into a repository without it is a dispatch into a repository where T-2 does not hold, and the
# runner refuses on the same principle as R-1's verify gate: machinery that cannot verify its own
# preconditions does not proceed.
#
# THE RULE IS NOT RESTATED HERE. It is asked of the guard library through its own checker, in a
# CHILD PROCESS -- the library redefines A1 functions by design and must not be dot-sourced into
# this scope by accident, and the dependency direction (tools/lam -> evidence-hooks-next, never the
# reverse) is what LAM-INSTALL sec 2 requires.
$prePushChecker = Join-Path $RepoRoot 'tools\evidence-hooks-next\hooks\check-prepush-installed.ps1'
if (Test-Path -LiteralPath $prePushChecker) {
    $ppOut = $null; $ppExit = 1
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $ppOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $prePushChecker -RepoRoot $MissionRoot 2>&1 | Out-String
        $ppExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
    if ($ppExit -ne 0) {
        $ppReason = "the pre-push decider is not installed or does not match the shipped wrapper"
        try {
            $ppDoc = ($ppOut | ConvertFrom-Json)
            if ($ppDoc -and $ppDoc.reason) { $ppReason = [string]$ppDoc.reason }
        } catch { $ppReason = "$ppReason (checker output was not parsable: $(($ppOut -split "`n" | Select-Object -First 1)))" }
        Deny-Dispatch ("T-2's publication guarantee is carried by the pre-push decider (amendment 19), and it is not in force for '$MissionRoot'. " + $ppReason + " Install it before dispatching: LAM-INSTALL sec 5.")
    }
} else {
    # The checker itself is part of the shipped tree. Its absence means the toolchain is incomplete,
    # which is not a state in which to start authorising work.
    Deny-Dispatch "the pre-push installation checker is missing at $prePushChecker, so T-2's decider could not be verified. Refusing rather than proceeding unverified."
}

# The ONE shared definition of gate state. `revoked_at: null` means NOT revoked, and this file
# restated that test rather than using the definition one dot-source away -- the same shape as the
# four null-sentinel defects already cured here. $PSScriptRoot, never cwd, so it resolves from a
# worktree exactly as mission-goal-check.ps1 does.
. (Join-Path $PSScriptRoot 'lam-gate-class.ps1')

$runRecord   = Get-RunRecordPath -Root $MissionRoot -DispatchId $Dispatch
$sessionId   = $runRecord.session
$evRoot      = $runRecord.evidence

# THE ID-REUSE GUARD (operator ruling, recurrence guard).
# A dispatch artifact is immutable and RUN ONCE. Design intent said so; nothing enforced it, and
# the cost was concrete: D-1 was re-run about eight times as a development loop while the runner
# was under repair, its append-only log grew to 170 entries, and because each run got a fresh
# worktree the stream bodies left with the worktrees while their log entries stayed. The result was
# a manifest asserting publications that exist nowhere -- a plane verify was right to refuse.
#
# From here, reusing an id is refused before anything is touched. Development loops get fresh ids
# by construction. -AllowIdReuse exists for instruments that legitimately drive the same fixture id
# repeatedly inside a disposable sandbox, and is never used against a real mission.
if (-not $AllowIdReuse) {
    $existing = @()
    foreach ($p in @($evRoot, (Join-Path $MissionRoot ".mission\evidence\$sessionId"))) {
        if (Test-Path -LiteralPath $p) { $existing += $p }
    }
    if ($existing.Count -gt 0) {
        Write-Line "mission-dispatch: REFUSED -- dispatch id reuse; issue a new id."
        Write-Line "  '$Dispatch' already has an evidence session at: $($existing -join ' ; ')"
        Write-Line "  A dispatch artifact is immutable and runs once. Re-running one appends to an"
        Write-Line "  append-only log while its worktree is recreated, which is how a manifest comes"
        Write-Line "  to assert stream bodies that exist nowhere."
        exit 2
    }
}
$ownerPath   = Join-Path $evRoot 'OWNER'
$endPath     = Join-Path $evRoot 'DISPATCH-END'
$startedPath = $runRecord.started
$rcPath      = $runRecord.rc
$endedPath   = $runRecord.ended
$streamPath  = Join-Path $evRoot 'runner-stream.jsonl'
$handoffPath = Join-Path $MissionRoot ".mission\dispatches\$Dispatch.handoff.yaml"
$anchorsPath = Join-Path $MissionRoot ".mission\dispatches\$Dispatch.anchors.yaml"

# =============================================================================================
# R-2 (composition) -- composed BEFORE the gate so -PlanOnly can print it without side effects
# =============================================================================================
$worktreeName = "wt-$Dispatch"
# THE ONE EXPRESSION THAT OWNS THE WORKTREE PATH. It used to be composed TWICE: here as
# "<root>\.mission-runtime\worktrees\<name>", which is what -PlanOnly printed, and again at the
# spawn as the CLI's own "<root>\.claude\worktrees\<name>", which is what every live run actually
# used. Nothing ever created the first form -- `.mission-runtime\worktrees\` on this repo holds only
# pre-ADR-026 entries (wt-fanout-*), while every later worktree (wt-<dispatch>,
# wt-D-V-A-581, ...) sits under `.claude\worktrees\`. So the plan told an operator to look somewhere
# the dispatch would never appear, and the two sites could drift without either one going red.
# Composed ONCE, here, because -PlanOnly must print the path the run will really use, and a second
# assignment further down is exactly how a plan and a run stop agreeing.
#
# SUPERSEDED, KEPT AS HISTORY: "ADR-026 SAYS NATIVE WORKTREES, SO THE CLI OWNS THE WORKTREE, NOT THIS
# RUNNER: this value is the CLI's convention, measured rather than chosen (`claude -p --worktree
# <name>` creates <repo>/.claude/worktrees/<name> on branch worktree-<name> and LOCKS it)." That
# measurement stands; the home it produced does not. The defect was closed as
# NOT CURABLE BY EXEMPTION after four refutations: a tree under the mission root's .claude/ -- and,
# measured this session through the real guard, one under .mission-runtime/worktrees/ just the same
# -- sits inside the guard's parent tier, which refuses every metacharacter-bearing or destructive
# command the worker aims at its OWN tree. The operator ruled the tree out of the mission root.
#
# THE HOME NOW: <parent of the mission root>\<leaf of the mission root>-worktrees\wt-<dispatch>, e.g.
# C:\work\<project>-worktrees\wt-<dispatch>. The folder name stays wt-<id> and the branch
# stays worktree-wt-<id> (operator ruling), because batch 1's peer-worktree deny rule is being keyed
# on exactly <leaf>-worktrees\wt-<LAM_DISPATCH>. This path is THE RUNNER'S OWN: the runner creates the tree
# before the spawn and hands it to the CLI as its WORKING DIRECTORY -- no --worktree flag (see the
# argv below). It is still checked against `git worktree list --porcelain` after the run, by exact
# normalised equality, and a path git does not list is a git_errors entry rather than an assumption.
# The parts were derived, and a leafless root refused, where the mission root was resolved.
$worktreePath = Join-Path $missionRootParent "$($missionRootLeaf)-worktrees\$worktreeName"
# GIT'S OWN CEILING, REFUSED BEFORE THE RUNNER CREATES ANYTHING OR OPENS THE RUN RECORD.
# git refuses a linked worktree whose path is 216 bytes or more. Measured: exit 128, "fatal:
# '$GIT_DIR' too big", at 216. LAM-ACCEPT.md records 215 exiting 0, 216 and 217
# exiting 128 with that message on every core.longpaths channel, and -- the reason this comment no
# longer says "216 and above exits 128" -- 230 with nothing set exiting 1 with no message: a refusal
# either way, not always the same one. THE UNIT IS UTF-8 BYTES, NOT CHARACTERS (found in
# review): git counts the bytes of the path it is handed. A path holding one non-ASCII character
# was measured refused at 215 characters / 216 bytes and accepted at 214 / 215, while .Length --
# UTF-16 code units -- let -PlanOnly print that path and the run open its record before git refused
# it. git measures the string it is given (an 8.3 short spelling is not expanded first), so the limit
# is a pure function of the mission root as given and the dispatch id, and it is refused here: before
# -PlanOnly prints a path no run could create, and before the run record opens. (The pre-push decider
# check above has already asked git read-only questions by this point; nothing has been created.)
if ([System.Text.Encoding]::UTF8.GetByteCount($worktreePath) -ge 216) {
    Deny-Dispatch "the worker worktree path is $([System.Text.Encoding]::UTF8.GetByteCount($worktreePath)) bytes in UTF-8 ($($worktreePath.Length) characters: $worktreePath), and git refuses a linked worktree whose path is 216 bytes or more ('`$GIT_DIR' too big). Shorten the mission root's path or the dispatch id so the composed path stays under 216 bytes."
}
# THE WORKER'S WORKING DIRECTORY, COMPOSED HERE, WHERE THE PLAN READS IT (review,
# a finding). It is the tree, and it used to be assigned only after -PlanOnly had exited, so the plan's
# 'worker cwd' line printed the TREE PATH under a cwd label and could not show a run whose cwd had
# drifted from it. The plan now prints this variable, and the spawn below enters this variable.
$workerCwd = $worktreePath
# A MODEL CLASS IS NOT A ROLE KIND, and conflating them names a settings file that does not exist.
# model-routing.yaml routes by model class (coding-strong, qa-validator, ...); K-3's templates are
# per ROLE KIND (orchestrator, worker, validator), because authority is a property of what the
# agent is for, not of how strong its model is. --settings pointing at a missing file would fail
# open: the role's hard-deny set would silently never apply, which is the worst direction.
$roleKind = switch ($roleForRun) {
    'qa-validator' { 'validator' }
    default        { 'worker' }
}
$roleSettings = Join-Path $RepoRoot "tools\lam\settings\$roleKind.json"
if (-not (Test-Path -LiteralPath $roleSettings)) {
    Deny-Dispatch "no role settings template at $roleSettings for role kind '$roleKind'. Refusing to spawn a worker whose deny set would silently not apply."
}
# =============================================================================================
# THE CUT POINT IS READ HERE AND ASSERTED BELOW; IT IS NO LONGER THE CLI'S TO CHOOSE
# =============================================================================================
# THE DEFECT, CONFIRMED BY GIT'S OWN RECORD AND NOT BY ANY SESSION REPORT. All 39 worktree branches
# the CLI has ever created for this program carry the same reflog creation line -- `branch: Created
# from origin/main` -- and each distinct cut point is a
# former value of origin/main. A remote-tracking ref is not the tip anyone asked for: measured on
# the day this was written, origin/main stood 74 commits behind HEAD and those four cut points
# stood 210, 280, 298 and 220 behind it. So a validator told to judge a tip, and a worker told to
# build on a base, were handed a tree from some earlier day, and nothing here said so.
#
# NO VERDICT WAS EVER WRONG BECAUSE OF IT, AND THAT IS THE PROBLEM. Every artifact ordered
# `git merge --ff-only <base_head_at_authoring>` before anything was touched, and the reflogs show
# the workers obeying: two of the worktree-wt-<id> branches each carry a
# `Fast-forward` entry immediately above their `Created from origin/main`. The guard was the
# BRIEF'S WORDING. A worker that instead reasoned "my worktree is the tip" would have judged
# origin/main and returned a confident, wrong answer, and no machinery would have noticed.
#
# MEASURED BEFORE IT WAS BUILT, in a throwaway repository, never against this one. `claude -p
# --worktree <name>` with no pre-existing directory cut the worktree at origin/main, two commits
# behind that fixture's HEAD -- the row, reproduced. With <root>/.claude/worktrees/<name> ALREADY
# PRESENT at the declared base, the CLI REUSED IT: its own init event named that directory as the
# worker's cwd, the tree still stood at the declared base afterwards, no second worktree and no
# second branch appeared, and the CLI merely locked what it found. BOTH shapes were reused -- one
# created on the CLI's own branch convention (worktree-<name>), one created detached. So the runner
# can decide the cut point simply by getting there first, and that is what it now does.
# THAT PREMISE IS SUPERSEDED BY THE WORKTREE RELOCATION, AND THE CURE OUTLIVES IT. The runner no
# longer relies on the CLI reusing anything: no --worktree is passed, so the CLI neither creates nor
# locks a tree, and the tree the runner places at the declared base IS the worker's working directory
# (measured by the lead with one real spawn of claude 2.1.258: the init event's cwd was the pre-placed
# tree, no .claude/worktrees appeared anywhere, no second worktree or branch, the tree not locked).
# The CLI's origin/main cut cannot happen at all now; it needed --worktree to happen.
#
# THE PROMPT IS NOT TOUCHED, DELIBERATELY. R-2's recorded sha256 is re-derived from the artifact
# FILE at spawn time, so it attests the exact bytes sent. Injecting a fast-forward instruction into
# the composed prompt would have made that hash attest something the file on disk does not contain
# -- a recorder that stops recording the thing it names. The cure is entirely in the machinery, so
# the hash goes on attesting what was sent, byte for byte.
#
# WHICH FIELD, AND WHY TWO OF THEM. A worker is told what it BUILDS ON (base_head_at_authoring); a
# validator is told what it JUDGES (tip_judged). Those are different questions and the artifacts
# spell them differently, so the field is chosen by role kind rather than guessed. A validator
# artifact carrying only base_head_at_authoring falls back to it rather than going unchecked.
$declaredBaseField = if ($roleKind -eq 'validator') { 'tip_judged' } else { 'base_head_at_authoring' }
$declaredBase      = [string]$dispatchDoc[$declaredBaseField]
if ((-not $declaredBase) -and ($roleKind -eq 'validator')) {
    $declaredBaseField = 'base_head_at_authoring'
    $declaredBase      = [string]$dispatchDoc[$declaredBaseField]
}

# The dispatch artifact IS the prompt (SS9.2: "the dispatch as its full input"), with the
# goal_condition translated to /goal per ADR-025. The model is given no other instruction.
$prompt = [System.IO.File]::ReadAllText($dispatchPath)
# =============================================================================================
# R-2's "RECORDED sha256" -- THE RECORDER.
# =============================================================================================
# R-2 has always cited "verbatim self-contained prompts with recorded sha256" and NOTHING ANYWHERE
# RECORDED ONE. A citation with no recorder is a claim with no detector, which is the class of
# defect three rounds of independent readers kept finding.
#
# There is nothing separate to hash: the artifact above IS the prompt. So the sha256 is re-derived
# FROM THE FILE, HERE, at spawn time -- not carried forward from the read at :139, because a value
# re-used from an earlier read attests to that read rather than to the bytes being sent.
#
# SCOPED HONESTLY: this is the ORCHESTRATOR's record of what it SENT. A worker still cannot attest
# to what it RECEIVED, and that residual is stated in the contract rather than implied by silence.
$dispatchSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $dispatchPath).Hash.ToLowerInvariant()
if ($dispatchDoc['goal_condition']) {
    $prompt = $prompt + "`n`n/goal " + [string]$dispatchDoc['goal_condition'] + "`n"
}

$workerArgv = @(
    '-p'
    # NO --worktree (operator ruling). ADR-026's native worktree is still the unit
    # of isolation, but the RUNNER creates it at the sibling home and spawns the CLI with that tree as
    # its WORKING DIRECTORY. `--worktree` cannot carry a path -- CLI 2.1.258's --help reads
    # '-w, --worktree [name]', a name only -- and given a name it creates <repo>/.claude/worktrees/<name>,
    # the home the operator ruled out. Measured by the lead with one real spawn (no --worktree, cwd = a
    # pre-placed linked worktree at <repo>-worktrees\wt-D-CLI, every other flag as here): the init
    # event's cwd was the tree; the tree's own .claude/settings.json hooks fired with
    # CLAUDE_PROJECT_DIR = the tree; memory_paths.auto was the MAIN repository's project dir, the same
    # identity every recorded --worktree init reports; and the tree was NOT locked. Nothing in this
    # runner locks or unlocks a tree either.
    '--model', $model                    # ADR-031, resolved from model-routing.yaml
    # ADR-032 AS AMENDED. This comment used to read
    # "auto-memory off is settings-enforced", and it was FALSE -- flatly contradicted by all three
    # templates it points at, each of which states in its own residuals that the disable is
    # UNOBTAINABLE on CLI 2.1.241 (no settings key exists; the only control is --bare,
    # which also skips hooks and would leave a worker with no evidence plane at all). What
    # --settings actually enforces is the role's PERMISSION posture -- its deny set, its closed
    # allow exceptions, and for the validator a deny-by-default mode. The memory separation each
    # role obtains is named on its own artifact (`_memory_off.separation_obtained`), and it is
    # separation, not a disable. A comment that overstates the mechanism is how the overclaim
    # survived three amendments.
    '--settings', $roleSettings
    '--output-format', 'stream-json'
    '--verbose'
    # A worker is a PURE FUNCTION of its dispatch (design SS9.2), so it is given no ambient
    # machinery it did not ask for. Measured, not assumed: an unconstrained nested spawn loaded the
    # full MCP surface and had produced 769 KB of initialisation stream before doing any work.
    '--strict-mcp-config'
    # A FILE, not an inline JSON string. PowerShell strips the double quotes when handing an
    # argument to a native command, so '{"mcpServers":{}}' arrived at the CLI as {mcpServers:{}},
    # which it then read as a FILENAME -- the first live dispatch died on
    # "MCP config file not found: ...\{mcpServers:{}}". A path has no quotes to lose.
    '--mcp-config', (Join-Path $RepoRoot 'tools\lam\empty-mcp.json')
    # Its transcript is not a resumable session -- the handoff and the evidence store are the only
    # things that outlive it, which is Principle 2 expressed in a flag.
    '--no-session-persistence'
    # THE ONE THING OUTSIDE THE WORKTREE A WORKER MUST REACH. The worktree is the worker's world by
    # design, but the handoff is the single artifact that has to OUTLIVE it -- design SS9.2 makes
    # the handoff "the only information that propagates" -- and it is written into the mission
    # plane, not into the tree the worker is about to be finished with. Without this the worker
    # does the work, verifies it, and then cannot hand it back.
    '--add-dir', $MissionRoot
)

# =============================================================================================
# A DISPATCH GATE IS STAMPED BY THE RUNNER AT SPAWN (operator ruling (i), candidate C5;
# and the rulings that followed it)
# =============================================================================================
# THE DEFECT: both dispatch gates of an earlier arc's validator rounds read `consumed_at: null` after the
# spawns they authorized, although each says `single_use: true` -- this runner read no dispatch gate.
# The decision and the stamp live in lam-dispatch-gate.ps1, and the decision is taken TWICE. HERE,
# over a plain read, so a spawn the gate does not authorize refuses before verify runs or a tree is
# cut, and so -PlanOnly can show it. And AGAIN at the spawn, under the gate's exclusive handle -- the
# decision the stamp is written on. Both compare the manifest's artifacts row with $dispatchSha, the
# sha256 the anchors record as dispatch_sha256, so the gate and the record name the same bytes.
# THE LIBRARY IS LOADED ONLY WHEN A GATE IS NAMED, and its absence refuses only such a dispatch.
$dgEarly = $null
$dgStamp = $null
if ($PSBoundParameters.ContainsKey('DispatchGate')) {
    $dispatchGateLib = Join-Path $PSScriptRoot 'lam-dispatch-gate.ps1'
    if (Test-Path -LiteralPath $dispatchGateLib) { . $dispatchGateLib }
    if (-not (Get-Command -Name 'Get-LamDispatchGateDecision' -CommandType Function -ErrorAction SilentlyContinue)) {
        Deny-Dispatch "DISPATCH-GATE-UNREADABLE: this dispatch names dispatch gate '$DispatchGate' and $dispatchGateLib is not loaded, so whether the gate authorizes this spawn cannot be decided. Nothing was written and no worker was spawned."
    }
    try {
        $dgEarly = Get-LamDispatchGateDecision -MissionRoot $MissionRoot -GateId $DispatchGate -DispatchId $Dispatch -DispatchPath $dispatchPath -DispatchSha256 $dispatchSha
    } catch {
        Deny-Dispatch "DISPATCH-GATE-FAULT: the decision on dispatch gate '$DispatchGate' threw ($($_.Exception.Message)). Nothing was written and no worker was spawned."
    }
    if (-not $dgEarly.ok) {
        Write-Line "mission-dispatch: REFUSED -- DISPATCH-GATE-$($dgEarly.code): $($dgEarly.reason)"
        if ($dgEarly.gate_path) { Write-Line "  gate : $($dgEarly.gate_path)" }
        Write-Line "  Nothing was written and no worker was spawned."
        exit 2
    }
}

# =============================================================================================
# THE AUTHENTICATION MODE, decided before -PlanOnly's print, the verify gate and the probe
# =============================================================================================
# VANGUARD_AUTH_MODE unset or empty: nothing here runs and nothing is loaded -- the probe and the worker inherit this
# runner's environment as they always have, and the CLI authenticates as Claude Code is signed in. Set: the library
# decides from which credentials the environment carries, by presence only. In key mode it holds the spawn's arguments,
# its prompt, the settings files and the files the CLI loads at the root of its tree (CLAUDE.md, CLAUDE.local.md,
# .claude\CLAUDE.md, .mcp.json) to carrying no key-shaped value, and the settings to naming no credential setting; under
# subscription, the settings to naming none but the subscription's own token. The settings files are the two the argv
# names and the .claude settings. The worker's tree does not exist yet, and it is not the mission root's working copy:
# it is cut at the declared base (else HEAD), so its root files and .claude settings are read as that commit holds them,
# in any letter case -- or, where a tree already stands at the worktree path, it is reused as it stands, and read there.
# The mission root's own are held too, since the placement copies the root's ignored .claude entries into the tree. A
# refusal is exit 2 before the verify gate, the login probe or the worker is started (the pre-push checker above has
# run, and reads no credential); an admitted mode prints nothing. In key mode the key reaches every child this runner
# starts, the verify gate and its suite among them, in the environment it inherits.
if (-not [string]::IsNullOrEmpty($env:VANGUARD_AUTH_MODE)) {
    $authLib = Join-Path $PSScriptRoot 'lam-auth-mode.ps1'
    if (Test-Path -LiteralPath $authLib) { . $authLib }
    if (-not (Get-Command -Name 'Get-LamAuthMode' -CommandType Function -ErrorAction SilentlyContinue)) {
        Deny-Dispatch "AUTH-MODE-UNREADABLE: VANGUARD_AUTH_MODE is set and $authLib is not loaded, so the mode cannot be decided. Nothing was written, and no verify gate, login probe or worker was started."
    }
    $authDecision = Get-LamAuthMode
    if ($authDecision.ok) {
        $authSettings = @()
        for ($ai = 0; $ai -lt ($workerArgv.Count - 1); $ai++) {
            if (@('--settings', '--mcp-config') -ccontains [string]$workerArgv[$ai]) { $authSettings += [string]$workerArgv[$ai + 1] }
        }
        $authSettings += (Join-Path $MissionRoot '.claude\settings.json')
        $authSettings += (Join-Path $MissionRoot '.claude\settings.local.json')
        # The tree: a standing one's files on disk, and the files the cut point holds (a file absent is skipped).
        $authTreeSettings = @(Get-LamAuthSettingsFiles -Root $worktreePath)
        $authTreeFiles = @(Get-LamAuthSessionFiles -Root $worktreePath)
        $authCutAt = ''
        $authCutRef = if ($declaredBase) { $declaredBase } else { 'HEAD' }
        $authPrevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $authCutRev = & git -C $MissionRoot rev-parse --verify --quiet ($authCutRef + '^{commit}') 2>&1
            if ($LASTEXITCODE -eq 0) { $authCutAt = ("$authCutRev").Trim() }
        } finally { $ErrorActionPreference = $authPrevEap }
        $authCommitted = [pscustomobject]@{ texts = [ordered]@{}; settings = [ordered]@{} }
        if ($authCutAt) {
            try { $authCommitted = Get-LamAuthCommittedFiles -Repo $MissionRoot -Rev $authCutAt -Mode $authDecision.mode }
            catch { Deny-Dispatch "AUTH-MODE-UNREADABLE: VANGUARD_AUTH_MODE is set and the files the worker's tree carries at $authCutAt could not be read ($($_.Exception.Message)), so they cannot be held to the mode. Nothing was written, and no verify gate, login probe or worker was started." }
        }
        if ($authDecision.mode -ceq 'api-key') {
            $authProbeArgs = @('-p', 'Reply with exactly the word OK and nothing else.', '--output-format', 'text')
            $authTexts = [ordered]@{ "prompt (the dispatch artifact $dispatchPath, piped to the worker on stdin)" = $prompt }
            foreach ($k in @($authCommitted.texts.Keys)) { $authTexts[$k] = $authCommitted.texts[$k] }
            $authDecision = Test-LamAuthSpawnInputs -Arguments (@($workerArgv) + $authProbeArgs) -Texts $authTexts -Files (@($authSettings) + @(Get-LamAuthSessionFiles -Root $MissionRoot) + $authTreeSettings + $authTreeFiles) -SettingsFiles (@($authSettings) + $authTreeSettings) -SettingsTexts $authCommitted.settings
        } else {
            $authDecision = Test-LamAuthSpawnInputs -Mode 'subscription' -SettingsFiles (@($authSettings) + $authTreeSettings) -SettingsTexts $authCommitted.settings
        }
    }
    if (-not $authDecision.ok) {
        Write-Line "mission-dispatch: REFUSED -- $($authDecision.code): $($authDecision.reason)"
        Write-Line "  Nothing was written, and no verify gate, login probe or worker was started."
        exit 2
    }
    # Admitted: nothing is printed, so the run's output is what it is without the variable.
}

if ($PlanOnly) {
    Write-Line "mission-dispatch PLAN for $Dispatch (role $roleForRun)"
    Write-Line "  worker command : $(if ($WorkerCommand) { $WorkerCommand } else { 'claude' })"
    Write-Line "  argv           : $($workerArgv -join ' ')"
    Write-Line "  worktree path  : $worktreePath"
    Write-Line "  worker cwd     : $workerCwd   (the runner creates this tree and spawns the worker in it)"
    Write-Line "  declared base  : $(if ($declaredBase) { "$declaredBaseField $declaredBase" } else { "(none declared -- the runner cuts a new tree at the mission root's HEAD and records it, not asserted)" })"
    Write-Line "  stream capture : $streamPath"
    Write-Line "  settings file  : $roleSettings"
    if ($null -ne $dgEarly) {
        $dgPlanAct = if ($dgEarly.first) { "this spawn would CONSUME it, seq 1 of $($dgEarly.count)" } else { "this spawn would record seq $($dgEarly.next_seq) of $($dgEarly.count)" }
        Write-Line "  dispatch gate  : $(Split-Path -Leaf $dgEarly.gate_path) -- $dgPlanAct (manifest sha256 $($dgEarly.manifest_sha256)); the plan writes nothing"
    }
    Write-Line "  --- prompt (the dispatch artifact, plus /goal) ---"
    foreach ($l in ($prompt -split "`r?`n")) { Write-Line "  | $l" }
    exit 0
}

# =============================================================================================
# R-1 -- the verify gate (ADR-022). NOTHING IS SPAWNED UNTIL THIS PASSES.
# =============================================================================================
$verifyExe = if ($VerifyCommand) { $VerifyCommand } else { Join-Path $RepoRoot 'tools\mission-verify.ps1' }
if (-not (Test-Path -LiteralPath $verifyExe)) {
    Deny-Dispatch "the verify gate is not on disk at $verifyExe -- a gate that cannot run is not a gate"
}
# WHAT verify IS GIVEN, and the one case where there is nothing to give it.
# `mission verify --against <artifact>` re-derives the state a PRIOR artifact recorded and compares
# (verify-spec SS3.1: "--against is the prior report or handoff carrying runner_anchors"). For the
# FIRST dispatch of a mission no such artifact exists -- there is no prior recorded state, so
# there is nothing that can have drifted from it.
#
# That case is RECORDED, never silent. A gate that quietly skips itself is the failure mode
# design SS4.5 law 2 names, so the skip is announced on stdout, the reason is explicit, and it is
# narrow: it applies only when no prior anchors or handoff exists anywhere in the dispatch
# directory. The moment one does, verify runs against the newest of them and its verdict binds.

# =============================================================================================
# THE ARTIFACT-NAME RULES, WRITTEN DOWN. TWO OF THEM, POINTING OPPOSITE WAYS.
# =============================================================================================
# Until this block the dispatch directory was read through one anonymous glob pair --
# `*.anchors.yaml -or *.handoff.yaml` -- and everything the glob happened not to match was excluded
# by ACCIDENT OF NAMING rather than by a rule. The accident was doing real work: the rejection
# path retains the worker's placed handoff as `<id>.handoff.worktree-placed.yaml`, and the ONLY
# reason those retained bytes could never be picked as a verify basis is that `-like
# '*.handoff.yaml'` does not match a name carrying a qualifier after `handoff`. Driven, the accident
# is plain: `D-X.handoff.worktree-placed.yaml` -> no match, but rename that same artifact to
# `D-X.worktree-placed.handoff.yaml` and the SAME glob matches it. The safe outcome was one rename
# away from the unsafe one, and no rule anywhere said which of the two was intended.
#
# SO THE RULE IS STATED, AND IT IS A SHAPE RULE, NOT A SUFFIX RULE.
#   RULE 1 (ADMITTING, NARROW) -- Test-IsVerifyBasisCandidate. An artifact may be offered as a
#     verify BASIS only if its name is exactly `<id>.anchors.yaml` or `<id>.handoff.yaml`: three
#     dot-separated segments, the middle one exactly `anchors` or `handoff`. ANY QUALIFIER SEGMENT
#     DISQUALIFIES IT, wherever that qualifier sits. That is what makes the rule survive the rename
#     -- `.handoff.worktree-placed.` and `.worktree-placed.handoff.` are both four-segment names and
#     both refused, where the glob refused the first and admitted the second.
#   RULE 2 (REFUSING, WIDE) -- Test-IsDispatchRanRecord. A name is EVIDENCE THAT A DISPATCH RAN if
#     any of its middle segments is `anchors` or `handoff`, qualified or not. It feeds REFUSALS
#     only: the two vacuity denials below (a rejection record on disk; since the name rules' residual, any
#     other record that a dispatch ran) and the count the vacuous-first record carries. It never
#     contributes a basis.
#     ITS REACH, STATED. Rule 2 is a test on a NAME, applied to the names the scan below lists: the
#     TOP LEVEL of .mission/dispatches, non-recursive (Get-ChildItem -File, no -Recurse and no -Force,
#     so a hidden file is not listed either), less this dispatch's own id. A name must end in a `.yaml` segment and carry `anchors` or `handoff` as a
#     whole dot-separated middle segment. So `D-X.anchors.aborted-seq1.yaml` and
#     `D-X.handoff.worktree-placed.yaml` are ran records, while `D-X.anchors.yaml.bak`,
#     `D-X.anchors.yml`, `D-X.anchors-aborted.yaml`, `D-X_anchors.yaml` and ANY record moved into a
#     subdirectory are not seen at all -- they deny nothing, and they are not in the count.
# The asymmetry is the point. Widening a scan that ADMITS A BASIS hands verify an artifact it should
# never have been given; widening a scan that REFUSES can only refuse more. That is the same
# fail-closed reasoning the marker scan states in its own words below, applied to the same directory.
# Rule 1 is therefore as narrow as the contract allows, and rule 2 as wide as the names permit.
#
# WHAT BREAKS IF THE RETAINED NAME CHANGES -- nothing silently. $RetainedPlacedHandoffSuffix is the
# single place that artifact is named (the R-3 writer composes the file from it, and no longer spells
# the literal), and the self-check below refuses to run this program AT ALL if the name is ever
# changed into a shape rule 1 would admit. Rename it to `.worktree-placed.handoff.yaml` and the safe
# outcome holds BY RULE; collapse it to `.handoff.yaml` and the next dispatch gets a hard refusal
# naming the reason, instead of a rejected dispatch's retained handoff quietly becoming its basis.
$RetainedPlacedHandoffSuffix = '.handoff.worktree-placed.yaml'

function Test-IsVerifyBasisCandidate {
    param([Parameter(Mandatory=$true)][string]$Name)
    $segs = @($Name -split '\.')
    if ($segs.Count -ne 3) { return $false }
    if ($segs[2] -ne 'yaml') { return $false }
    return (($segs[1] -eq 'anchors') -or ($segs[1] -eq 'handoff'))
}

function Test-IsDispatchRanRecord {
    param([Parameter(Mandatory=$true)][string]$Name)
    $segs = @($Name -split '\.')
    if ($segs.Count -lt 3) { return $false }
    if ($segs[$segs.Count - 1] -ne 'yaml') { return $false }
    $middle = @($segs[1..($segs.Count - 2)])
    return (($middle -contains 'anchors') -or ($middle -contains 'handoff'))
}

# ================================================================================================
# THE MARKER SCAN STOPS AT A NESTED-REPOSITORY BOUNDARY.
# ================================================================================================
# THIS NARROWS THE SCAN, AND NARROWING IS THE FAIL-OPEN DIRECTION. The clause at the scan site says
# widening is "the only direction in which widening a scan is safe", and that reasoning is not
# withdrawn here: it is about WHERE IN THIS MISSION'S PLANE a marker may sit, and it still holds
# everywhere in this mission's plane. What it never considered is a file that is not in this
# mission's plane at all.
#
# WHAT WAS OBSERVED. `Get-ChildItem -Recurse` carries no boundary of any kind, so it descends out
# of this repository and into every foreign checkout parked under either plane. A recorded
# case had three fixture markers inside a validation clone refusing every dispatch of the OUTER
# mission. It reproduces on demand here: ONE run of
# tests/lam/instrument-WP-2.ps1 leaves 24 `*.superseded.yaml` fixtures inside nested repositories
# under `.mission-runtime/` -- 23 of them inside linked worktrees of a nested clone -- every one
# unratified by THIS mission's gates, and the next dispatch is then refused, exit 2, naming 24
# markers no human here ever wrote. Measured, not argued: 24 markers enumerated, 24 unratified,
# 0 of them under `.mission/`, and no `.gitmodules` anywhere in the repository.
#
# WHY THAT IS NOT FAIL-CLOSED BEHAVIOUR WORTH KEEPING. A marker is "a human ruling on one named
# dispatch" of THIS mission -- the clause above says so. A file inside a foreign checkout is that
# checkout's content and rules on nothing here. A refusal with no ruling behind it is not caution,
# and it is not stable either: the only ways out of it are to delete other repositories' files or
# to delete the scan, and a gate whose enforcement pressure is to remove the gate is already
# failing open, only more slowly.
#
# THE BOUNDARY IS GIT'S OWN, NOT A HEURISTIC ON NAMES OR CONTENT. A `.git` entry is git saying "a
# different repository is rooted here". It is tested as a PATH, not as a directory: `.git` is a
# DIRECTORY in a clone and a FILE holding `gitdir: ...` in a linked worktree or a submodule -- this
# very repository's own root `.git` is a file -- and a rule that looked only for a directory would
# miss every worktree, which is the commonest nested shape under `.mission-runtime/`. `Test-Path`
# answers for both shapes, and it also sees the HIDDEN attribute git puts on `.git`, which
# `Get-ChildItem` without -Force does not.
#
# DEPTH ZERO IS NEVER TESTED, BY CONSTRUCTION. The walk starts AT a plane root and applies the
# boundary test only to directories it discovers BELOW one. $MissionRoot's own `.git` is therefore
# never consulted and can never prune the mission's own plane. That is the trap a "walk up from
# each marker until you find a .git" implementation falls into on its first run -- every marker
# under `.mission/` has $MissionRoot as an ancestor, so that spelling prunes everything. A plane
# root carrying a `.git` of its own is not pruned either: the contract names the two planes, and
# what sits directly in them is this mission's by definition.
#
# WHAT IS GIVEN UP, SAID PLAINLY. A marker a human deliberately placed INSIDE a foreign checkout
# under a plane is no longer honoured, and no longer refuses -- it is invisible. If an operator
# wants to retire a dispatch, the marker belongs in this mission's own plane, which is where every
# marker this program has ever been shown has lived.
#
# COST. Each directory below a plane root is enumerated exactly once and gets exactly one
# Test-Path; matching files are listed once per directory. That is O(paths visited), and it is
# strictly LESS work than the -Recurse it replaces, which walked every foreign checkout in full
# before anything could discard the result. It is not quadratic because no marker ever causes its
# ancestors to be re-walked: the pruning happens on the way DOWN, once per directory, never on the
# way up, once per marker.
function Get-LamPlaneMarkerFile {
    param([Parameter(Mandatory=$true)][string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return }
    # AN EXPLICIT WALK, because Get-ChildItem -Recurse cannot be asked to prune a subtree: there is
    # no -Exclude that means "and nothing beneath it", so the choice is to walk or to descend into
    # the foreign checkout and filter afterwards. Filtering afterwards would pay the descent anyway.
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        $dir = $pending.Pop()
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.superseded.yaml' -ErrorAction SilentlyContinue)) { $f }
        foreach ($sub in @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue)) {
            # THE BOUNDARY. A directory holding a `.git` entry of EITHER shape is another
            # repository's root, and nothing beneath it belongs to this mission's plane.
            if (Test-Path -LiteralPath (Join-Path $sub.FullName '.git')) { continue }
            $pending.Push($sub.FullName)
        }
    }
}

# THE RULE CHECKS ITSELF AGAINST THE NAME THIS PROGRAM ACTUALLY WRITES. Without this the rename is
# invisible until a live dispatch verifies against a rejected dispatch's retained handoff; with it,
# the rename is a refusal here, before anything is spawned.
if (Test-IsVerifyBasisCandidate -Name ('X' + $RetainedPlacedHandoffSuffix)) {
    Deny-Dispatch "the retained-handoff name 'X$RetainedPlacedHandoffSuffix' is admissible as a verify BASIS under rule 1 -- the retained bytes of a REJECTED dispatch would become the next dispatch's basis. Give the artifact a qualifier segment, or change rule 1 deliberately."
}

$against = $null
$priorArtifacts = @()
# Defined before the branch below so the vacuity denial and the vacuous-first count read an empty set,
# never an undefined one (@($null).Count is 1 in PowerShell, which would be a false count).
$ranRecords = @()
$ranNotRejected = @()
$dispDir = Join-Path $MissionRoot '.mission\dispatches'
if (Test-Path -LiteralPath $dispDir) {
    # PRIOR means prior. An artifact belonging to THIS dispatch is not a prior state to verify
    # against -- and a failed earlier attempt at this same dispatch leaves one behind, which is
    # how the first live run came to verify D-1 against D-1's own rejected handoff. This filter is
    # applied to the WHOLE directory, once, so both rules below inherit it: the retained handoff of
    # THIS dispatch is excluded by the same clause that excludes its earlier attempt's anchors.
    $dirFiles = @(Get-ChildItem -LiteralPath $dispDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "$Dispatch.*" } |
        Sort-Object LastWriteTimeUtc -Descending)
    $priorArtifacts = @($dirFiles | Where-Object { Test-IsVerifyBasisCandidate -Name $_.Name })

    # A REJECTED handoff records a refusal, not a state. It carries no anchors by construction, so
    # verify would refuse on it every time -- turning a stale failure into a permanent gate. It is
    # therefore not a verify BASIS.
    #
    # BUT IT IS STILL PROOF THAT A DISPATCH RAN, and conflating those two things was a hole. Because
    # the rejected handoff was filtered out entirely, a mission whose only prior artifact was one --
    # the exact artifact THIS RUNNER writes on an R-3 rejection -- reported "no prior artifact",
    # took the vacuous-first path, and proceeded with verify NEVER INVOKED. An independent validator
    # drove it: a verify stub rigged to hard-refuse was never spawned and the runner exited 0
    # (V-1 round 2, WP-2). The same reasoning the marker ruling applies to markers applies here: a mission
    # that has already run a dispatch is not a mission having its first.
    # AND THE HOLE THAT LEFT OPEN, MEASURED. This denial was written against $priorArtifacts, i.e.
    # against rule 1's NARROW set -- so it could only ever see a rejection record sitting at the
    # plain `<id>.handoff.yaml` name. Every rejection an operator has ARCHIVED by renaming was
    # invisible to it. Counted over this repo's own dispatch directory at the time of writing: 39
    # rejection records on disk, 9 of them visible here, 30 invisible -- 26 `*.handoff.rejected-stub`
    # and 4 `*.handoff.aborted-seq*`. A mission whose only prior artifacts were archived rejections
    # therefore still reported `no prior artifact`, still took the vacuous-first path, and still
    # walked through the ADR-022 gate unrun: the exact hole the paragraph above claims to have
    # closed, still open through every name but one. It is closed here by reading rule 2's WIDE set.
    # This can only ADD refusals -- $rejectedPriors is consumed at exactly one place, the vacuity
    # denial, and never contributes a basis.
    $ranRecords = @($dirFiles | Where-Object { Test-IsDispatchRanRecord -Name $_.Name })
    $rejectedPriors = @($ranRecords | Where-Object {
        ([System.IO.File]::ReadAllText($_.FullName)) -match '(?m)^status:[ \t]*rejected'
    })
    $priorArtifacts = @($priorArtifacts | Where-Object {
        ([System.IO.File]::ReadAllText($_.FullName)) -notmatch '(?m)^status:[ \t]*rejected'
    })
    # THE OTHER HALF OF THE WIDE SET: every record that a dispatch ran and that is NOT a rejection. The
    # test is the one the narrow priors are filtered by just above, the same regex over the same file.
    # It is NOT one reading: this line reads each file again, separately from the $rejectedPriors pass,
    # so the two sets partition $ranRecords only while no file's status line changes between the reads.
    # A file rewritten in that window would land in neither set. That window is not known to reach the
    # vacuity branch -- a rejecting dispatch writes its plain anchors before its stub, so any other
    # dispatch already has a basis -- but it is read, not driven. Consumed only by the ran-record
    # vacuity denial below (the name rules' residual); it never contributes a basis.
    $ranNotRejected = @($ranRecords | Where-Object { ([System.IO.File]::ReadAllText($_.FullName)) -notmatch '(?m)^status:[ \t]*rejected' })

    # SUPERSESSION (operator ruling). An artifact is skipped IFF an explicit marker names
    # its dispatch as superseded -- NEVER because verify refused it. A gate that skipped whatever it
    # refused would skip exactly what it exists to catch. The marker is a human ruling on one named
    # dispatch, and the skip is recorded verbatim in the consuming dispatch's anchors.
    # THE MARKER RULING (revised). A marker is honoured ONLY against a `supersession` GATE ARTIFACT whose
    # binds_sha256 equals the marker's re-derived sha256. An agent cannot mint one: T-3 hard-denies
    # every agent role from writing under the gates directory. The earlier design resolved markers
    # against a registry in STATUS.md -- a gitignored prose file THIS AGENT WRITES -- which would
    # have reintroduced, one layer up, the very hole ratification exists to close.
    # NO GATE, NO SKIP: an unratified marker is not ignored, it REFUSES the dispatch (exit 2).
    $allMarkers    = @()
    $unratified    = @()
    $supersededIds = @{}
    # THE MARKER SCAN IS RECURSIVE OVER THE MISSION PLANE, NOT TWO FIXED DIRECTORIES
    # (V-1 round 4, WP-2). It looked only in `.mission/dispatches` and `.mission-runtime/lam`, so a
    # `*.superseded.yaml` one level up -- `.mission/D-0.superseded.yaml` -- was INVISIBLE, and the
    # dispatch proceeded on `vacuous-first` recording `markers: 0` while a marker sat on disk. The
    # contract names no directory, and a marker's location is not what makes it a marker.
    #
    # Widening a marker scan can only find MORE markers, and more markers means more REFUSALS
    # (an unratified one refuses; a ratified one skips a prior that a human retired). That is the
    # fail-closed direction, which is the only direction in which widening a scan is safe.
    #
    # AND IT STOPS AT NESTED-REPOSITORY BOUNDARIES. The widening above is
    # about WHERE IN THIS MISSION'S PLANE a marker may sit; Get-LamPlaneMarkerFile is about
    # WHOSE PLANE IT IS AT ALL. Its header carries the observation, what the narrowing gives up,
    # and why depth zero is never tested.
    $markerDirs = @((Join-Path $MissionRoot '.mission'), (Join-Path $MissionRoot '.mission-runtime'))
    foreach ($mdir in $markerDirs) {
        if (-not (Test-Path -LiteralPath $mdir)) { continue }
        foreach ($m in @(Get-LamPlaneMarkerFile -Root $mdir)) {
            $allMarkers += $m.FullName
            $mt = [System.IO.File]::ReadAllText($m.FullName)
            # =================================================================================
            # RATIFICATION IS KEYED ON THE MARKER, NOT ON A REGEX MATCHING IT.
            # =================================================================================
            # This whole block used to sit inside `if ($mt -match '(?m)^dispatch_id:\s*(\S+)')`,
            # so a marker whose id line was ABSENT, or merely INDENTED ONE SPACE, fell through
            # the check entirely: not ratified, not refused, not mentioned. The dispatch proceeded
            # to exit 0 with `superseded_prior: []` and nothing anywhere naming the marker. The
            # mirror failed too -- `dispatch_id: "D-prior"` (quoted, and perfectly valid YAML) did
            # not match `(\S+)` cleanly, so a RATIFIED marker was silently not honoured and verify
            # ran against the prior the operator had retired.
            #
            # Driven by an independent validator (V-1 round 3, WP-2), and it is precisely the harm
            # this clause's own words name: "ignoring it would leave the prior in play while
            # telling nobody the marker had been disregarded."
            #
            # THE MARKER'S EXISTENCE IS THE TRIGGER. A `*.superseded.yaml` file is either ratified
            # and honoured, or it REFUSES the dispatch. There is no third path, and in particular
            # no path where a parse failure buys silence -- an unreadable marker is the one most
            # in need of a human, not least.
            $mSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $m.FullName).Hash.ToLowerInvariant()
            # TOLERANT ID PARSE: leading whitespace and quoted scalars are valid YAML and were not
            # accepted before. Captured IMMEDIATELY -- $Matches is global and every later -match
            # overwrites it; the gate-text regexes below have no capture group, so reading
            # $Matches[1] after them indexes null and the runner dies with "array index evaluated
            # to null" (exit 5). Caught by T-4 on its first run rather than by a live dispatch.
            $mDispatchId = $null
            if ($mt -match '(?m)^\s*dispatch_id:\s*["'']?([^"''\r\n]+?)["'']?\s*$') { $mDispatchId = $Matches[1] }
            if (-not $mDispatchId) {
                $unratified += "$($m.Name) [sha256 $($mSha.Substring(0,16)) -- no readable dispatch_id: a marker that cannot say which dispatch it retires cannot be honoured, and is not ignored]"
                continue
            }
            # Find a supersession gate binding EXACTLY these bytes. Matching on the hash rather
            # than the filename is what makes it non-forgeable: edit the marker and the gate
            # stops matching it.
            $gate = $null
            $gDir = Join-Path $MissionRoot '.mission\gates'
            if (Test-Path -LiteralPath $gDir) {
                foreach ($g in @(Get-ChildItem -LiteralPath $gDir -File -Filter 'supersession-*.yaml' -ErrorAction SilentlyContinue)) {
                    $gt = [System.IO.File]::ReadAllText($g.FullName)
                    # REVOCATION is the only thing that withdraws a supersession ratification.
                    # EXPIRY IS DELIBERATELY NOT CONSULTED HERE, and the omission is reasoned
                    # rather than an oversight: a ratified supersession is a recorded ruling, not
                    # a capability, so it does not lapse. The first two gates placed under this
                    # kind were written with push-shaped `expires_at`/`single_use` fields before
                    # that was separated (see mission-gate.ps1); honouring their expiry would
                    # have retired both markers 60 minutes after ratification and refused every
                    # dispatch thereafter until they were re-ratified, hourly, forever.
                    # AND THE THIRD STATE IS NOT CONSULTED EITHER, WHICH IS NOW SAID RATHER
                    # THAN LEFT TO BE INFERRED. A later revision added
                    # DISQUALIFIED (`witness_expired_at`) after the reasoning above was
                    # written, and this line was not revisited -- so an auditor found a
                    # consumer reading ONE of three states with no statement about the other
                    # two, which from outside is indistinguishable from an oversight.
                    #
                    # It cannot occur here, and that is a fact about who writes the field
                    # rather than a hope: `witness_expired_at` is stamped in exactly one place,
                    # `Complete-EvidencePushGate`, onto gate paths taken from a push witness --
                    # and those come from `Get-EvidencePushGateForSha`, which scans
                    # `push-*.yaml` AND verifies `kind: push` FROM THE ARTIFACT. A supersession
                    # gate can never be named by a push witness, so it can never carry the
                    # field. Adding a `.disqualified` branch here would be a check that can
                    # never fire -- the same dead-branch defect removed from the hook checker.
                    #
                    # A known defect class, in its quiet form: the class was named -- what withdraws a
                    # ratification -- and not re-enumerated when the class grew.
                    if ((Get-LamGateState -Path $g.FullName).revoked) { continue }
                    # THE KIND IS READ FROM THE ARTIFACT, NOT INFERRED FROM ITS FILENAME
                    # (V-1 round 4, WP-2). The scan is `-Filter 'supersession-*.yaml'`, so a gate
                    # of ANY kind that merely happened to be NAMED that way ratified a marker -- a
                    # `kind: push` gate was measured doing exactly that. Filenames are chosen by
                    # whoever creates the file; the kind is the thing the classifier and the
                    # zero-paste attestation both read. A ratification must rest on what the
                    # artifact SAYS it is.
                    # THE SHARED READER, NOT A LOCAL REGEX (operator ruling). Same two
                    # defects as mission-goal-check.ps1's acceptance-gate scan: `-notmatch` is
                    # case-INSENSITIVE, so `kind: SUPERSESSION` ratified a marker, and it asked
                    # whether the line existed ANYWHERE rather than reading the FIRST top-level
                    # kind. This file already dot-sources lam-gate-class.ps1 (:1000), so the ask
                    # costs no new dependency.
                    if ((Resolve-LamGateKind -Kind (Get-LamGateClassForArtifact -Path $g.FullName).kind) -cne 'supersession') { continue }
                    if ($gt -match "(?m)^binds_sha256:\s*$([regex]::Escape($mSha))\s*$") { $gate = $g.FullName; break }
                }
            }
            if (-not $gate) {
                $unratified += "$($m.Name) [sha256 $($mSha.Substring(0,16)) -- no unrevoked supersession gate binds these bytes]"
                continue
            }
            $supersededIds[$mDispatchId] = [pscustomobject]@{
                id     = $mDispatchId
                path   = $m.FullName
                sha256 = $mSha
                gate   = $gate
            }
        }
    }
    $skippedPrior = @()
    if ($supersededIds.Count -gt 0) {
        $priorArtifacts = @($priorArtifacts | Where-Object {
            $base = ($_.Name -split '\.')[0]
            if ($supersededIds.ContainsKey($base)) { $script:skippedPrior += $supersededIds[$base]; $false } else { $true }
        })
        # DEDUPE BY DISPATCH ID. The filter runs once per prior ARTIFACT FILE, and a dispatch leaves
        # two of them (.anchors.yaml and .handoff.yaml), so an un-deduped list records one
        # supersession as two. D-1b's anchors banked D-1 twice that way. One dispatch superseded is
        # one entry, however many artifacts carried its name.
        $skippedPrior = @($script:skippedPrior | Sort-Object -Property id -Unique)
    }
}

# NO GATE, NO SKIP. An unratified marker refuses the dispatch rather than being quietly ignored:
# ignoring it would leave the prior in play while telling nobody the marker was disregarded, and
# honouring it would be the hole. Refusal is the only reading that is both safe and legible.
if ($unratified.Count -gt 0) {
    Write-Line "mission-dispatch: REFUSED -- $($unratified.Count) UNRATIFIED supersession marker(s) present."
    foreach ($u in $unratified) { Write-Line "    $u" }
    Write-Line "  A marker is honoured only against an unrevoked 'supersession' gate whose binds_sha256"
    Write-Line "  equals the marker's bytes. The operator ratifies one with:"
    Write-Line "    mission-gate.ps1 approve -Kind supersession -Id <dispatch-id> -Binds <marker-path> -MissionRoot $MissionRoot"
    exit 2
}

# THE VERIFY BASIS IS THE NEWEST *.anchors.yaml. A handoff denies vacuity (it is
# proof a dispatch ran) and a REJECTED handoff keeps R-15's meaning above, but neither is a BASIS: a
# handoff carries no runner_anchors, so verify refuses on it every time. This used to take the newest
# artifact of EITHER kind, and an accepted handoff newer than its anchors -- the shape the handoff placement
# produces at every integration -- became the basis: a live dispatch was refused on
# ANCHOR/against_artifact against an earlier dispatch's handoff. Priors that hold no anchors file refuse here,
# by name, and never fall through to vacuity.
$anchorPriors = @($priorArtifacts | Where-Object { $_.Name -like '*.anchors.yaml' })
if ($anchorPriors.Count -gt 0) {
    $against = $anchorPriors[0].FullName
} elseif ($priorArtifacts.Count -gt 0) {
    Write-Line "mission-dispatch: REFUSED -- $($priorArtifacts.Count) prior artifact(s) exist but none is an anchors file."
    foreach ($pa in $priorArtifacts) { Write-Line "    $($pa.Name)" }
    Write-Line "  A handoff is proof that a dispatch ran and is not a verify BASIS (amendment 27): with no anchors on"
    Write-Line "  disk there is nothing to verify against, and vacuity is not lawful either."
    exit 2
}

# VACUOUS-FIRST is lawful ONLY for a genuinely-first dispatch: zero prior artifacts AND zero
# markers of any kind. A mission holding a superseded dispatch is not a mission having its first,
# and it was exactly that combination -- marker-skipping plus a permissive vacuity -- that let a
# dispatch proceed with verify never invoked.
if ((-not $against) -and ($rejectedPriors.Count -gt 0)) {
    Write-Line "mission-dispatch: REFUSED -- no usable prior artifact, but $($rejectedPriors.Count) REJECTED handoff(s) exist."
    foreach ($rp in $rejectedPriors) { Write-Line "    $($rp.Name)" }
    Write-Line "  A rejected handoff is not a verify BASIS -- it carries no anchors, so verify would refuse on it"
    Write-Line "  every time. But it is PROOF THAT A DISPATCH RAN, so this mission is not having its first, and"
    Write-Line "  vacuity is not lawful. Admitting it here is the path by which a failed dispatch launders itself"
    Write-Line "  into a clean slate and the ADR-022 gate is walked through unrun."
    exit 2
}

if ((-not $against) -and ($allMarkers.Count -gt 0)) {
    Write-Line "mission-dispatch: REFUSED -- no prior artifact remains, but $($allMarkers.Count) supersession marker(s) exist."
    Write-Line "  Vacuity is lawful only for a GENUINELY-first dispatch: zero priors AND zero markers. A mission"
    Write-Line "  that has retired a dispatch is not a mission having its first, and admitting it here is the"
    Write-Line "  path by which every prior could be retired and the ADR-022 gate walked through unrun."
    exit 2
}

# =============================================================================================
# A DISPATCH THAT RAN DENIES VACUITY, NOT ONLY A DISPATCH THAT WAS REJECTED (the name rules' residual)
# =============================================================================================
# A later revision named this and did not take it unasked: the denial above is keyed on `status:
# rejected`, so a record that a dispatch ran WITHOUT that line, under a name rule 1 refuses as a
# basis, denied nothing. Measured on this repository's own dispatch directory: four archived
# `*.anchors.aborted-seq*` files carry no status line (each records `outcome: verified-pass`),
# so a mission whose only priors were those four would have taken the vacuous-first path, never
# invoked verify, and recorded `prior_artifacts: 0` beside them -- a derivation false on its face.
# No id of this mission was in that shape when this was written (a read-only census over the
# directory: 0 of 40 ids change outcome, because every one of them has a plain anchors basis). The
# runner's own retained `<id>.handoff.worktree-placed.yaml` joins that class only once BOTH its
# rejection stub AND its dispatch's plain `<id>.anchors.yaml` have left rule 2's set. The runner
# writes those anchors before the R-3 block writes the retained handoff, so a rejected dispatch
# always leaves a basis for every other id; and a stub archived by an in-rule rename keeps
# `status: rejected` and still refuses above. (Their sibling `*.handoff.aborted-seq*` files DO carry
# `status: rejected` and already refused above.) R-1 makes vacuity lawful only for zero prior
# artifacts, and this denial covers what rule 2 recognises: a name with `anchors` or `handoff` as a
# whole middle segment, at the TOP LEVEL of .mission/dispatches (the scan is non-recursive), under
# another dispatch's id. A record under another spelling (`.yaml.bak`, `.yml`, a hyphenated
# qualifier) or moved into a subdirectory is not seen: vacuity still proceeds beside it, and the
# count below still records 0.
#
# WHERE IT SITS, AND WHY. After the rejected-handoff denial and after the marker denial, so both of
# those keep their messages byte for byte: when a rejection record exists this block is never
# reached, and so it never lists a retained handoff beside a rejection stub. It is pre-spawn, exit 2,
# and nothing has been written yet (the evidence root is created further down).
#
# RECORDS UNDER A SUPERSEDED ID ARE NOT EXCLUDED, and no filter for them is written, because none
# could ever fire here. $supersededIds is filled only from markers, every marker is in $allMarkers,
# and with no basis any marker at all has already refused above. The narrow priors are filtered by
# supersession because a retired dispatch must not become a BASIS; this set admits nothing, and a
# retired dispatch still ran -- the marker denial above says exactly that in its own words.
if ((-not $against) -and ($ranNotRejected.Count -gt 0)) {
    Write-Line "mission-dispatch: REFUSED -- no usable prior artifact, but $($ranNotRejected.Count) record(s) of a dispatch that RAN exist, and none records a rejection."
    foreach ($rn in $ranNotRejected) { Write-Line "    $($rn.Name)" }
    Write-Line "  None of these is a verify BASIS: rule 1 admits only a plain '<id>.anchors.yaml' or '<id>.handoff.yaml', and a"
    Write-Line "  name carrying a qualifier segment (an archived or retained copy) is refused as one. But each is PROOF THAT A"
    Write-Line "  DISPATCH RAN (rule 2), so this mission is not having its first, and vacuity is not lawful. Proceeding would"
    Write-Line "  walk the ADR-022 gate through unrun beside these files. A mission whose every anchors file has been set"
    Write-Line "  aside has no basis to verify against; that is for a human to resolve, not for vacuity to absorb."
    exit 2
}

# =============================================================================================
# A DECLARED `verify_basis` IS A CLAIM THE RUNNER CHECKS, NEVER ONE IT SILENTLY OVERRIDES.
#
# =============================================================================================
# Dispatch artifacts have declared `verify_basis:` since an earlier revision, and until now the
# string `verify_basis` appeared NOWHERE in tools/: the artifact named a basis, the runner took the
# newest anchors on disk, and WHEN THOSE TWO DIVERGED THE RUN PROCEEDED AGAINST A FILE THE ARTIFACT
# NEVER NAMED -- with the scoping that file implies, which is not a cosmetic difference. The basis's
# own `dispatch_kind` is what the gate is scoped by (the block below), so a substituted
# basis can scope a gate `build` where the artifact expected `read-only`, or the reverse.
#
# IT DIVERGED TWICE, LIVE, and neither time was caught by this program:
#   seq 163 -- seq 162 halted before its first commit and made ZERO commits of three, yet the runner
#     still wrote it anchors carrying a GREEN suite block. By mtime those were the newest on disk, so
#     A RUN THAT BUILT NOTHING would have become the basis for the arc's last seam. Caught by the
#     seat's own pre-spawn check; cured by an operator RENAMING the anchors `.aborted-seq162`.
#   seq 166 -- a dispatch artifact was authored naming its prior's anchors file, which WAS the newest at
#     authoring; the A-579 validator's runner then wrote anchors two and a half hours newer, and the
#     declared basis was one round stale. Caught at ACT 1, by a human reading two files.
# A round's own anchors land AFTER the next artifact is drafted, so this is not an unlucky shape --
# it is the shape every round has.
#
# THE REFUSAL PRINTS BOTH PATHS, NAMED AS WHAT THEY ARE. "The basis moved" is not actionable; "you
# declared X, I would have used Y" is, and it is the whole content of both STOPs above.
#
# DECLARING NOTHING IS STILL LAWFUL. The newest-anchors substitution is the correct path for an artifact
# that names no basis -- the field is not mandatory here, and making it so would be a different
# ruling than the one this check carries out. Only a DECLARED-and-DIFFERENT basis refuses.
#
# THE COMPARISON IS NORMALISED BEFORE IT IS MADE, and getting that wrong would refuse every correct
# dispatch rather than the defective one. The declared value is repo-relative with forward slashes
# (`.mission/dispatches/X.anchors.yaml`); the pick above is an absolute Windows path with backslashes
# taken from Get-ChildItem. Both are made absolute against $MissionRoot -- which is where
# `.mission\dispatches` lives, the same root $anchorsPath is built from -- run through GetFullPath to
# fold `.\` and `..`, and compared OrdinalIgnoreCase because NTFS is case-insensitive. The two
# candidates share $MissionRoot's own spelling BY CONSTRUCTION (the pick enumerates a directory built
# from it with Join-Path, and the declared path is joined to the same string), so there is no second
# spelling of the prefix for the comparison to disagree about.
#
# THE SHA FIELDS ARE DELIBERATELY NOT CHECKED HERE, and the omission is reasoned rather than an
# oversight. Artifacts carry `verify_basis_sha256_lf_blob` AND `verify_basis_sha256_working_copy`
# because core.autocrlf is true in this repository and the two figures LEGITIMATELY DIFFER for the
# same correct file -- seq 166's own face records `agree: DIFFER` for this very path. A check that
# compared one declared figure against one derived reading would refuse correct dispatches, which is
# the one direction a fail-closed check must not fail in. The divergence this check names is a
# divergence of IDENTITY, and the path is what names identity; a bytes check is a second, different
# member and is not smuggled in under this one.
$declaredBasis = ''
if ($dispatchDoc.ContainsKey('verify_basis')) { $declaredBasis = ([string]$dispatchDoc['verify_basis']).Trim() }
if ($declaredBasis) {
    $declaredNorm = $declaredBasis -replace '/', '\'
    if (-not [System.IO.Path]::IsPathRooted($declaredNorm)) { $declaredNorm = Join-Path $MissionRoot $declaredNorm }
    $declaredFull = [System.IO.Path]::GetFullPath($declaredNorm)
    $againstFull  = if ($against) { [System.IO.Path]::GetFullPath($against) } else { '' }
    if (-not [string]::Equals($declaredFull, $againstFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Line "mission-dispatch: REFUSED -- the DECLARED verify_basis is not the basis this runner would use."
        Write-Line "    declared by the artifact : $declaredBasis"
        Write-Line "      resolved to            : $declaredFull"
        Write-Line "      on disk                : $(if (Test-Path -LiteralPath $declaredFull -PathType Leaf) { 'present' } else { 'ABSENT' })"
        if ($againstFull) {
            Write-Line "    newest anchors on disk   : $(Split-Path -Leaf $againstFull)"
            Write-Line "      resolved to            : $againstFull"
        } else {
            Write-Line "    newest anchors on disk   : (none -- this run would take the VACUOUS-FIRST path and never invoke verify)"
        }
        Write-Line "  Amendment 27 takes the newest *.anchors.yaml, and until this check it did so SILENTLY: the"
        Write-Line "  run proceeded against a file the artifact never named, scoped by THAT file's dispatch_kind. Two"
        Write-Line "  live rounds diverged this way (spawn seq 163 and seq 166) and a human caught both."
        Write-Line "  Reconcile them before dispatching -- correct the artifact's verify_basis to the file that is"
        Write-Line "  actually newest, or retire the newer anchors if they record a run that must not be a basis."
        exit 2
    }
}

# WHICH OF R-1'S THREE DISTINGUISHABLE OUTCOMES THIS RUN TOOK. Recorded as a variable here and
# written into the anchors below, because R-1 requires every proceeding dispatch to record which it
# was -- and until now nothing did. `operator-admitted` is deliberately absent from this switch: it
# is named in the contract, it has NO code path, and inventing one would be inventing an admission
# that lets a dispatch proceed without verify passing. That is not a gap to fill quietly.
$gateOutcome     = ''
$vacuityPriors   = $null
$vacuityMarkers  = $null

# A DISPATCH KIND IS NOT A SCOPING CLASS. A dispatch artifact declares a kind TOKEN
# (schemas SS4 names mainline, fanout and rework; this repository's artifacts also declare read-only);
# mission-verify's anchor-scoping table (schemas SS5) admits only the CLASSES build, rework, close,
# read-only and micro-ceremony, and refuses any other word at ANCHOR/dispatch_kind before a single arm
# runs. This ONE translation serves both places the runner hands a kind to verify: the argv of the gate
# below and the dispatch_kind the anchors writer records for this dispatch.
# IT IS DEFINED HERE, AT SCRIPT SCOPE AND BEFORE THE GATE BRANCHES, because the anchors writer runs on
# the vacuous-first path too. Defined inside the gate's else-branch, as it once was, the
# function does not exist on that path and the writer could not call it.
#   mainline, fanout, build -> build      rework -> rework, close -> close, read-only -> read-only
#   THE SWITCH IS CASE-INSENSITIVE (PowerShell's default): MAINLINE and Mainline also become build,
#   and READ-ONLY becomes read-only, so a token matching a row case-insensitively is NORMALISED to
#   the row's lower-case class. Everything else passes through verbatim (micro-ceremony, a leading
#   space, an empty string, any unknown word), so verify still refuses a kind it cannot scope rather
#   than this runner guessing a class for it. dispatch_kind_token keeps the declared casing.
# MAINLINE STAYS IN THE TABLE: anchors written before this translation record the token verbatim, and the gate
# below translates whatever kind it reads off a prior.
function ConvertTo-VerifyClass {
    param([string]$KindToken)
    switch ($KindToken) {
        'mainline'  { 'build' }
        'fanout'    { 'build' }
        'build'     { 'build' }
        'rework'    { 'rework' }
        'close'     { 'close' }
        'read-only' { 'read-only' }
        default     { $KindToken }
    }
}

if (-not $against) {
    $gateOutcome    = 'vacuous-first'
    # COUNTED, NOT WRITTEN AS A LITERAL 0 (the name rules' residual). Every record that a dispatch ran, rule 2's
    # wide set, which is what R-1's "zero prior artifacts" counts. With the denials above it is 0 by
    # construction on this path; if a later edit to THOSE DENIALS ever lets a ran record through, the
    # anchors say how many instead of recording a zero beside them. It guards nothing else: the count
    # and the denials read the same $ranRecords, so an edit that narrows rule 2 or widens the own-id
    # filter empties both, and the count still reads 0. Its reach is rule 2's (stated at rule 2's
    # header). R-1's grammar is exactly these two members, so no field is added.
    $vacuityPriors  = @($ranRecords).Count
    $vacuityMarkers = @($allMarkers).Count
    Write-Line "mission-dispatch: ADR-022 gate -- VACUOUS-FIRST: no prior artifact and no supersession marker."
    Write-Line "  This is the genuinely first dispatch of this mission: there is no recorded prior state, so nothing"
    Write-Line "  can have diverged from it. Recorded as its own DISTINGUISHABLE outcome carrying its derivation,"
    Write-Line "  never as a pass. Every later dispatch verifies against the newest prior artifact and that binds."
    $verifyExit = 0
    $verifyOut  = @('gate: VACUOUS -- first dispatch, no prior artifact')
} else {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # PS 5.1: a native exe's stderr is fatal under 'Stop'
    try {
        # --dispatch-kind is supplied EXPLICITLY. verify-spec SS3.1 says it "defaults to the kind
        # recorded in the artifact under comparison; verify refuses rather than guessing when
        # neither supplies it" -- and recording the kind in the anchors file was not enough: verify
        # still reported ANCHOR/dispatch_kind ABSENT. The runner knows the kind from the dispatch it
        # is running, so it says so rather than relying on the artifact being read the way expected.
        # A DISPATCH KIND IS NOT A SCOPING CLASS, and verify scopes by class. schemas SS4 names the
        # dispatch kinds (mainline, fanout, rework); the anchor-scoping rule (schemas SS5, design
        # SS12.2) speaks of BUILD-, REWORK- and CLOSE-class dispatches. Driven: `--dispatch-kind
        # rework` was accepted and scoped, while `--dispatch-kind mainline` came back
        # ANCHOR/dispatch_kind ABSENT -- verify refuses rather than guessing at a word it does not
        # know, which is correct of it and was wrong of the runner to send.
        # THE SCOPING IS THE PRIOR'S. verify-spec:100-102 says --dispatch-kind
        # "defaults to the kind recorded in the artifact under comparison"; the runner supplies it
        # explicitly (above), so it must supply THAT kind -- the prior artifact's own -- and not this
        # dispatch's. Scoping a read-only prior's anchors as a build's demands a suite block the prior
        # lacks by design (schemas SS5 :458): one live dispatch was refused on ANCHOR/suite
        # against a read-only prior's anchors. This dispatch's class is the fallback ONLY when the prior
        # records no kind. Verify scopes by CLASS, so the kind is mapped through ConvertTo-VerifyClass
        # (defined at script scope above this gate), and a class already recorded
        # maps to itself. Anchors written since the translation record the class in dispatch_kind and the
        # declared token in dispatch_kind_token; anchors written before it record the TOKEN
        # (mainline, read-only, ...) in dispatch_kind, and the mapping reads both the same way.
        $kindRaw = if ($dispatchDoc['kind']) { [string]$dispatchDoc['kind'] } else { 'mainline' }
        $priorKind = ''
        if ($against -and (Test-Path -LiteralPath $against)) {
            $priorText = [System.IO.File]::ReadAllText($against)
            if ($priorText -match '(?m)^dispatch_kind:[ \t]*(\S+)') { $priorKind = $Matches[1] }
        }
        $kindForVerify = if ($priorKind) { ConvertTo-VerifyClass -KindToken $priorKind } else { ConvertTo-VerifyClass -KindToken $kindRaw }
        if ($priorKind) { Write-Line "mission-dispatch: verify scoping -- the prior's recorded dispatch_kind '$priorKind' -> --dispatch-kind $kindForVerify (amendment 27)" }
        else { Write-Line "mission-dispatch: verify scoping -- the prior records no dispatch_kind; this dispatch's kind '$kindRaw' -> --dispatch-kind $kindForVerify (amendment 27, the fallback)" }
        # VERIFY RUNS IN THE MISSION ROOT, and this is not incidental. Resolve-RepoRoot walks up
        # from the WORKING DIRECTORY first (mission-verify.ps1:2303-2311), so a verify invoked from
        # <project> verifies <project>: it derived <project>'s HEAD, compared it to the smoke
        # mission's recorded head_sha, and reported DIVERGED -- a true statement about two
        # unrelated repositories and a useless one about this dispatch. The same coupling decides
        # where it looks for the normative manifest schema, which is why the smoke repo carries a
        # byte-identical copy of it.
        Push-Location $MissionRoot
        try {
            $verifyOut  = & powershell -NoProfile -ExecutionPolicy Bypass -File $verifyExe --against $against --dispatch-kind $kindForVerify 2>&1
            $verifyExit = $LASTEXITCODE
        } finally { Pop-Location }
    } finally { $ErrorActionPreference = $prevEap }
    Write-Line "mission-dispatch: ADR-022 gate -- verified against $(Split-Path -Leaf $against) (exit $verifyExit)"
}

# PASS-DIB classification comes from the ONE shared definition, never restated here.
. (Join-Path $PSScriptRoot 'lam-verify-admission.ps1')
$verifyText = (@($verifyOut) | ForEach-Object { "$_" }) -join "`n"
# The recorded head_sha comes from the artifact verify was pointed at -- the advance admission
# compares THAT basis against the live tree, never a sha this runner picked.
$recordedHead = ''
if ($against -and (Test-Path -LiteralPath $against)) {
    $againstText = [System.IO.File]::ReadAllText($against)
    if ($againstText -match '(?m)^\s*head_sha:\s*([0-9a-f]{40})') { $recordedHead = $Matches[1] }
}
# THE OBSERVED SET is read from THE SAME artifact verify was pointed at. Deriving it
# from anywhere else -- the live tree, this dispatch's own suite -- would compare the declaration
# against a run the gate is not judging, and the admission would then rest on a basis nobody
# verified. $null (no note, or a note whose count and names disagree) reaches the decider as an
# empty set and the equality test refuses, which is the direction that refuses.
$basisUnexpected = @()
if ($declaredRepairs.declared -and $against) {
    $bu = Read-BasisUnexpectedFailures -Path $against
    if ($null -ne $bu) { $basisUnexpected = @($bu) }
    else { Write-Line "mission-dispatch: the basis records no readable expected_failures_note, so its unexpected-failure set reads EMPTY (amendment 29) -- a declared repair cannot be admitted against it" }
}
$vv = Get-LamVerifyVerdict -VerifyOutput $verifyText -ExitCode $verifyExit `
        -MissionRoot $MissionRoot -RecordedHeadSha $recordedHead `
        -DeclaredRepairTestIds $declaredRepairs.test_ids -BasisUnexpectedFailures $basisUnexpected
$verifyAdmission = @()
$verifyAdvance = $null
$verifyRepair = $null

if ($vv.verdict -eq 'REFUSE') {
    Write-Line "mission-dispatch: verify gate did not PASS (exit $verifyExit). ADR-022 refusal -- no worker was spawned."
    Write-Line "  reason: $($vv.reason)"
    foreach ($l in @($verifyOut)) { Write-Line "  verify| $l" }
    exit 2
}
# Anything reaching here ran verify and got a verdict it could proceed on. If the gate was vacuous
# the outcome is already set above and verify was never invoked -- the distinction R-1 exists to
# keep visible, and which the anchors could not previously express.
if (-not $gateOutcome) { $gateOutcome = 'verified-pass' }
# THE DECLARED-REPAIR ADMISSION ADDS EXACTLY ONE NAMED STATE, and it is named at the gate rather than left inside
# 'verified-pass'. The whole point of the closed vocabulary below is that a proceeding dispatch says
# WHICH admission carried it; a declared repair carried this one, so the anchors say so and a
# completion review does not have to read the admitted-subject list to find out.
if (($gateOutcome -eq 'verified-pass') -and ($null -ne $vv.declared_repair) -and $vv.declared_repair.admitted) {
    $gateOutcome = 'admitted-by-declared-repair'
}
# THE ORIGIN-ATTESTATION ADMISSION ADDS THE FOURTH NAMED STATE, named at the gate for the reason the block above
# gives: a proceeding dispatch says WHICH admission carried it. Before this, a dispatch that
# proceeded ONLY because the tip an unrevoked push gate authorizes is the tip verify derived from
# origin was recorded as 'verified-pass' -- the same words an ordinary passing verify writes -- so
# the durable artifact a completion review reads could not tell the two apart. That is the
# unaccounted admission R-1 exists to make impossible, and it was satisfied here only because the
# class was never wired to an outcome at all: the letter of the law and not its point.
#
# THE ORDER IS THE RULE, NOT AN ACCIDENT OF PLACEMENT. This test runs AFTER the declared-repair
# test above, so A DECLARED REPAIR WINS. The reason is not precedence for its own sake: a declared
# repair creates an END-OF-DISPATCH DEBT that this artifact has to carry so the delivery assertion
# can be checked against it, and this class creates no such obligation. The contract states the
# same rule, because R-1 saying a dispatch records WHICH outcome it took presumes one answer.
# WHAT THE NAME MEANS, AND IT IS NARROWER THAN THIS COMMENT ONCE CLAIMED. ERRATUM, ROUND 2
# (found in review): this read "So the fourth name means exactly what WP-2's R-A asserts -- this dispatch
# proceeded ONLY on the gate." THE TEST BELOW NEVER ASKS THAT. It reads the gate outcome and the
# origin-attestation list and nothing else, so a dispatch whose verdict ALSO admitted a suite
# subject under PASS-DIB is recorded under this name with both subjects listed. The name records
# WHICH BRANCH WON, under the precedence rule above; admitted_subjects records what was admitted.
# R-A's row (a) drives the origin-only case, which is why no row here could have caught this.
#
# THE READ IS GUARDED AND ITS SIBLING ABOVE IS NOT, which is deliberate rather than untidy. Of the
# verdict object's return shapes only PASS-DIB and four refusal shapes carry this field; the plain
# PASS shape does not. This script sets no Set-StrictMode, so the sibling above yields $null on
# those shapes by LENIENCY rather than by design -- and the same library IS loaded under
# Set-StrictMode -Version Latest by other consumers. Testing for the property before taking it
# means this line does not rest on that leniency and adds no member to the unguarded-read class
# an earlier revision left open. That class is carried on the contract's face
# with its sites; it is not cured here, and this is not a cure for it.
#
# ONE READ, BANKED. The field is taken exactly once in this file, so the reader count WP-3's C-1v
# derives over the tracked source is a number and not an estimate.
$verifyOrigin = $null
if (@($vv.PSObject.Properties.Name) -contains 'origin_attestation') { $verifyOrigin = $vv.origin_attestation }
if (($gateOutcome -eq 'verified-pass') -and ($null -ne $verifyOrigin) -and (@($verifyOrigin).Count -gt 0)) {
    $gateOutcome = 'admitted-by-authorized-publication'
}

# =============================================================================================
# THE CLOSED-SET ASSERTION (the operator's ruling on the third outcome).
# =============================================================================================
# R-1 named a THIRD outcome, `operator-admitted`, and nothing ever produced it. The refusal to
# build it is now RATIFIED and the outcome is STRUCK from the contract: building it would have
# been building an admission that lets a dispatch proceed WITHOUT VERIFY PASSING, and the record
# already has a mechanism for an operator who wants that -- a contract amendment, which is
# numbered, hash-chained, committed alone, and names who decided what. A per-run admission flag is
# the same effect by a weaker route, and the weaker route is the one that gets used.
#
# So the outcome vocabulary is CLOSED at FOUR, and this is where that is enforced: BEFORE a worker
# is spawned, not in the anchors afterwards. The rule the amendment states is "no code path may
# let a dispatch proceed without verify passing or a NAMED ADMISSION", and the ruled admissions
# are a closed set -- PASS-DIB, the advance admission, vacuous-first, the declared-repair admission
# and the origin-attestation admission. A state this
# runner cannot NAME is an unaccounted admission, so it refuses rather than annotating itself.
#
# Dead today by construction: every assignment to $gateOutcome above names a member of this set. It is
# written as a live check anyway, because "unreachable" is a property of the code as it stands and
# a third assignment added later would otherwise proceed unnamed and be recorded as an oddity
# instead of refused. This build has three separate instances of a mechanism that was dead on
# arrival and passed anyway; a fail-closed assertion costs one comparison.
# EXTENDED BY EXACTLY TWO MEMBERS: the declared-repair admission and the
# origin-attestation admission (built, then RATIFIED). The set is still
# CLOSED -- at FOUR, as the paragraph above says -- and still enumerated here, which is the
# property that matters: a proceeding state this runner cannot name still refuses.
# ERRATUM, ROUND 2 (found in review): this read "EXTENDED BY EXACTLY ONE MEMBER (the declared repair). The set is
# still CLOSED and still enumerated here", SIX LINES BELOW the paragraph round 1's cure had
# rewritten to say CLOSED AT FOUR and to name the origin-attestation admission. That cure
# corrected four stale sentences in this block and missed the fifth. The ratifying amendment's own
# census of what the ratification makes stale calls itself MEASURED and looks only at the contract
# page -- never at the file the cure lives in, which is how a block came to contradict itself.
# 'admitted-by-declared-repair' is a NAMED admission of the kind R-1 already contemplates -- it is
# granted by machinery, on a declaration the mission committed in advance, and it is answerable at
# the end of the dispatch. It is not the struck 'operator-admitted': nothing here lets a dispatch
# through on an assertion nobody has to make good on.
$closedGateOutcomes = @('verified-pass', 'vacuous-first', 'admitted-by-declared-repair', 'admitted-by-authorized-publication')
if ($closedGateOutcomes -notcontains $gateOutcome) {
    Write-Line "mission-dispatch: REFUSED -- the ADR-022 gate reached a proceeding state it cannot name ('$gateOutcome')."
    Write-Line "  R-1 as amended closes the outcome vocabulary at exactly $($closedGateOutcomes.Count): $($closedGateOutcomes -join ', ')."
    Write-Line "  The outcome 'operator-admitted' was STRUCK by amendment 15 rather than implemented. An operator who wants a"
    Write-Line "  dispatch through despite verify is making a CONTRACT AMENDMENT, not an admission -- that mechanism"
    Write-Line "  exists, it is hash-chained, and it leaves an artifact naming who decided what."
    Write-Line "  No worker was spawned."
    exit 2
}
if ($vv.verdict -eq 'PASS-DIB') {
    # R-1 as amended: THE TALLY RULE BINDS ADMITTED SUITE SUBJECTS, AND ONLY THEM.
    # A suite member among the admitted subjects is what needs a runner-observed tally, so a suite
    # member admitted with no suite_command declared is what refuses here. An advance-only admission
    # (head_sha, porcelain -- the companion admission) admits no suite subject and needs no tally.
    # This used to test the DECLARED suite_command alone, so an advance-only admission with no suite
    # was refused although nothing needed binding: a live diagnostic dispatch was refused AFTER its
    # advance admission had passed. Read from the admitted-subject list the verdict already carries.
    $admittedSuite = @($vv.admitted | Where-Object { (($_ -split '/')[-1]) -match '^suite\.(passed|failed|skipped)$' })
    if (($admittedSuite.Count -gt 0) -and (-not $suiteCmd)) {
        Write-Line "mission-dispatch: verify returned PASS-DIB, but this dispatch declares no suite_command, so there is no runner-observed tally to bind the admitted subjects."
        Write-Line "  admitted suite subject(s): $($admittedSuite -join ', ')"
        Write-Line "  admitted would have been: $($vv.admitted -join ', ')"
        Write-Line "  ADR-022 refusal -- no worker was spawned."
        exit 2
    }
    $verifyAdmission = @($vv.admitted)
    $verifyAdvance   = $vv.advance
    $verifyRepair    = $vv.declared_repair
    Write-Line "mission-dispatch: ADR-022 gate -- PASS-DIB. Admitted: $($verifyAdmission -join ', ')"
    # SAME GRAMMAR AS THE LINE ABOVE, AND IT NAMES THE IDS. An admission line that said only
    # "admitted by declared repair" would leave the one fact an operator needs -- WHICH failing test
    # this dispatch is now on the hook for -- to be recovered from the artifact.
    if (($null -ne $verifyRepair) -and $verifyRepair.admitted) {
        Write-Line "mission-dispatch: ADR-022 gate -- ADMITTED-BY-DECLARED-REPAIR. Declared: $($verifyRepair.declared -join ', ')"
        Write-Line "  $($verifyRepair.reason)"
        Write-Line "  This dispatch is REJECTED at its end if the worker's own suite run does not show every declared id passing (DECLARED-REPAIR-NOT-DELIVERED)."
    }
    if ($admittedSuite.Count -eq 0) { Write-Line "  no suite subject admitted, so no runner-observed tally is required (amendment 26)" }
    Write-Line "  $($vv.reason)"
}
# TOOLCHAIN NOTE (i), THE PRE-SPAWN HALF. The ADMITTED-BY-DECLARED-REPAIR line
# above is printed only where the gate RESTED on the declaration -- PASS-DIB, plus an admitted
# repair. A dispatch that declares repairs and passes the gate on its own merits was announced at
# NEITHER end: not here, because the gate did not rest on it, and not at the end of the run,
# because the end spoke only on failure. THE DEBT IS CREATED BY THE DECLARATION, NOT BY THE
# GRANT -- which is exactly why the assessment at the end of this file is unconditional on the
# grant -- so it is now said out loud wherever it is incurred, closing with the same sentence the
# admission uses.
if ($declaredRepairs.declared -and (-not (($null -ne $verifyRepair) -and $verifyRepair.admitted))) {
    Write-Line "mission-dispatch: this dispatch DECLARES $($declaredRepairs.test_ids.Count) repair(s) the ADR-022 gate did not rest on. Declared: $($declaredRepairs.test_ids -join ', ')"
    Write-Line "  This dispatch is REJECTED at its end if the worker's own suite run does not show every declared id passing (DECLARED-REPAIR-NOT-DELIVERED)."
}

# =============================================================================================
# THE LOGIN PROBE, BEFORE THE RUNNER CREATES ANYTHING OF THE DISPATCH (BATCH-2 WP-G (a))
# =============================================================================================
# WHERE, AND WHY HERE. After every refusal above -- identity, markers, vacuity, the verify gate, the
# closed set -- and before the first thing this runner creates: the evidence session and OWNER just below,
# the run record, the worktree, the dispatch gate's stamp, the anchors. A refusal here therefore creates
# NONE OF THOSE: the run record reads NEVER STARTED, no tree was cut, no dispatch gate was consumed, and
# because no evidence session exists the id-reuse guard admits the SAME id again once the CLI can
# authenticate. It leaves the verify gate's store for the verify run above, and one spawn-ledger note.
# WHAT THIS PLACE GIVES UP: the verify gate runs before the probe, so a probe refusal still costs one
# verify; and the refusals that come after the runner's first creation still follow the probe. A dispatch
# spawns once, so this is the first spawn's probe and the only one. EXIT 7, a code of its own: refused
# before spawning as exit 2 is, but answered by logging the CLI in and running the SAME id, which exit 2's
# causes are not. A run that names a stub worker (-WorkerCommand) and no -LoginProbeCommand spawns no
# claude CLI at all, so there is nothing to probe: the probe is SKIPPED, and says so.
$loginProbe = $null
if ($WorkerCommand -and (-not $LoginProbeCommand)) {
    Write-Line "mission-dispatch: login probe -- SKIPPED: -WorkerCommand names a stub worker and no -LoginProbeCommand was given, so this run spawns no claude CLI and there is none to probe (register row 345)"
} else {
    $loginProbe = Invoke-LamLoginProbe -ProbeCommand $LoginProbeCommand -TimeoutSeconds $LoginProbeTimeoutSeconds -MissionRoot $MissionRoot
    if (-not $loginProbe.ok) {
        Write-Line "mission-dispatch: REFUSED -- LOGIN-PROBE-$($loginProbe.code): $($loginProbe.reason)"
        Write-Line "  probe       : $($loginProbe.command)"
        Write-Line "  probe cwd   : $(if ($loginProbe.cwd) { "$($loginProbe.cwd) -- an empty scratch folder this runner made; removed: $($loginProbe.cwd_removed)" } else { '(none was made)' })"
        Write-Line "  exit / wall : $(if ($null -ne $loginProbe.exit_code) { $loginProbe.exit_code } else { '(none)' }) / $($loginProbe.wall_ms) ms (bound $LoginProbeTimeoutSeconds s)"
        if ($loginProbe.stderr.Trim()) { Write-Line "  stderr      : $((@($loginProbe.stderr.Trim() -split "`r?`n") | Select-Object -First 1))" }
        Write-Line "  Refused BEFORE the spawn: no evidence session, run record, worktree, dispatch-gate stamp or anchors was created, so this dispatch id runs again unchanged once the worker CLI can authenticate."
        $probeNote = [ordered]@{
            event = 'note'; ts = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture); dispatch_id = $Dispatch
            outcome = 'REFUSED-BEFORE-SPAWN'; refusal = "LOGIN-PROBE-$($loginProbe.code)"; runner_exit = 7; reason = $loginProbe.reason
            probe_command = $loginProbe.command; probe_cwd = $loginProbe.cwd; probe_exit_code = $loginProbe.exit_code
            probe_wall_ms = [long]$loginProbe.wall_ms; probe_timeout_seconds = $LoginProbeTimeoutSeconds
            runner = 'tools/lam/mission-dispatch.ps1'; register_row = 345
        }
        $probeLedger = Write-LamSpawnLedgerNote -ComposerPath (Join-Path $PSScriptRoot 'spawn_ledger.py') -LedgerPath (Get-LamLedgerPath -MissionRoot $MissionRoot) -Record $probeNote
        Write-Line "  spawn ledger: $(if ($probeLedger.ok) { $probeLedger.said } else { 'NOT WRITTEN -- ' + $probeLedger.said })"
        exit 7
    }
    Write-Line "mission-dispatch: login probe -- OK: $($loginProbe.command) answered exactly OK in $($loginProbe.wall_ms) ms from an empty scratch folder this runner made and removed ($($loginProbe.cwd_removed))"
}

# =============================================================================================
# OWNERSHIP -- declared BEFORE the spawn (LAM-ACCEPT H-1)
# =============================================================================================
if (-not (Test-Path -LiteralPath $evRoot)) { New-Item -ItemType Directory -Path $evRoot -Force | Out-Null }
$startedAt = Get-Date
$stampStart = $startedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
[System.IO.File]::WriteAllText($ownerPath,
    "runner_id: mission-dispatch.ps1`ndispatch_id: $Dispatch`nsession_id: $sessionId`nspawned_at: $stampStart`nrole: $roleForRun`nmodel: $model`n",
    (New-Object System.Text.UTF8Encoding($false)))

# THE RUN RECORD OPENS HERE, BEFORE THE SPAWN, and the rc and end stamp of any PREVIOUS
# run into this evidence root are REMOVED FIRST. A launcher that polls must never be able to read
# an rc that belongs to an earlier run: clearing them at launch is precisely what makes 'the rc is
# present' mean 'THIS run returned'. .started is then written whatever happens next -- if the spawn
# below throws, the record still reads STARTED AND NOT FINISHED, which is the true thing and is a
# different statement from NEVER STARTED.
foreach ($stalePath in @($rcPath, $endedPath)) {
    if (Test-Path -LiteralPath $stalePath) { Remove-Item -LiteralPath $stalePath -Force }
}
[System.IO.File]::WriteAllText($startedPath, "$stampStart`n", (New-Object System.Text.UTF8Encoding($false)))

# UI-1 S1 (ADR-045): dispatch_opened, once the ownership and the run record exist. kind, feature and the
# assertion targets are read off the dispatch artifact (a flow list or a block list); source_path is that
# artifact. Through tools\lam\mission-telemetry.ps1; it can fail nothing and prints nothing.
try {
    $tmD = Join-Path $PSScriptRoot 'mission-telemetry.ps1'
    $dArt = Join-Path $MissionRoot ".mission\dispatches\$Dispatch.yaml"
    if ((Test-Path -LiteralPath $tmD -PathType Leaf) -and (Test-Path -LiteralPath $dArt -PathType Leaf)) {
        . $tmD
        $dText = [System.IO.File]::ReadAllText($dArt)
        $dTargets = @()
        $dFlow = [regex]::Match($dText, '(?m)^assertion_targets:\s*\[([^\]]*)\]')
        if ($dFlow.Success) { $dTargets = @($dFlow.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ }) }
        else {
            $dBlock = [regex]::Match($dText, '(?ms)^assertion_targets:[ \t]*\r?\n((?:[ \t]+-[^\r\n]*\r?\n?)+)')
            if ($dBlock.Success) { $dTargets = @([regex]::Matches($dBlock.Groups[1].Value, '(?m)^[ \t]+-[ \t]*([^\s#]+)') | ForEach-Object { $_.Groups[1].Value.Trim('"', "'") }) }
        }
        $dFeature = Get-MissionTelemetryYamlScalar -Text $dText -Key 'feature_id'
        if (-not $dFeature) { $dFeature = Get-MissionTelemetryYamlScalar -Text $dText -Key 'feature' }
        $dKind = Get-MissionTelemetryYamlScalar -Text $dText -Key 'kind'
        if (-not $dKind) { $dKind = 'mainline' }
        Invoke-MissionTelemetry -Root $MissionRoot -Verb 'mission-dispatch' -Snapshot -Events @(@{ Kind = 'dispatch_opened'; SourcePath = $dArt
            Payload = [ordered]@{ dispatch_id = $Dispatch; kind = $dKind; feature = $dFeature; assertion_targets = @($dTargets); session_id = $sessionId } })
    }
} catch { }

# --- the worktree ------------------------------------------------------------------------------
# THE RUNNER CREATES THE TREE, AT THE SIBLING HOME, AND IT IS THE WORKER'S WORKING DIRECTORY
# (operator ruling). The path was composed once, above, where the
# plan reads it. Every git return code is checked (R-5).
#
# SUPERSEDED, KEPT AS HISTORY: "ADR-026 SAYS NATIVE WORKTREES, SO THE CLI OWNS THE WORKTREE, NOT THIS
# RUNNER. Measured rather than assumed: `claude -p --worktree <name>` in a repo creates
# <repo>/.claude/worktrees/<name> on branch worktree-<name>, LOCKS it, and runs the worker with that
# as its working directory. A runner that pre-created its own worktree would either collide with
# that or, worse, anchor a directory the worker never touched." The measurement was right about the
# CLI; the conclusion is retired. With no --worktree in the argv the CLI creates nothing and locks
# nothing, so there is no second tree to collide with, and the tree the runner anchors is the one
# the worker is spawned IN -- the anchors describe the directory the worker worked in by construction.
$gitErrors = @()
$isRepo = Test-Path -LiteralPath (Join-Path $MissionRoot '.git')
# $worktreePath IS NOT RECOMPOSED HERE. It was, and the copy it overwrote -- the one
# -PlanOnly had already printed -- named a different directory, so the plan and the run disagreed
# by construction. The single composition sits with the rest of R-2 above, where the plan reads it;
# it is still verified against `git worktree list --porcelain` after the run, below. The worker's
# working directory is composed there too, next to the path, for the same reason.
$worktreeHome = Split-Path -Parent $worktreePath

# ONE KEY FOR "THE SAME DIRECTORY", used before the spawn (is this tree the mission root's own?) and
# after it (does git list it?). git answers in forward slashes, this runner composes backslashes, and
# a drive letter's case is not a difference -- so both sides are slash-normalised, made full, stripped
# of a trailing separator and compared case-insensitively. EXACT equality on that key and nothing
# looser: the old post-run test was a -like prefix match, under which wt-D-1 also matched wt-D-1b.
function ConvertTo-WorktreePathKey {
    param([string]$PathText)
    if (-not $PathText) { return '' }
    try { return ([System.IO.Path]::GetFullPath(($PathText.Trim() -replace '/', '\'))).TrimEnd('\').ToUpperInvariant() }
    catch { return '' }
}

# A REFUSAL THAT FIRES AFTER .started CLOSES THE RUN RECORD FIRST, IN THE RUN RECORD'S ORDER (.rc, then
# .ended). Every refusal in this section can fire after .started is on disk, and one that simply
# walked away would leave a dispatch that IS finished reading `started-not-finished` for ever -- the
# exact ambiguity the run record exists to remove. The rc written is the code Deny-Dispatch returns.
function Close-RunRecordBeforeRefusal {
    [System.IO.File]::WriteAllText($rcPath, "2`n", (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($endedPath, "$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture))`n", (New-Object System.Text.UTF8Encoding($false)))
}

# ENTER THE TREE, AND PROVE IT WAS ENTERED (found in review). A plain `Push-Location
# <path>` reads '[' and ']' as a WILDCARD: measured on PS 5.1, a directory named wt-D-[1] made it fail
# NON-terminating ("Cannot find path ... because it does not exist"), and with a wt-D-1 beside it the
# same push LANDED IN wt-D-1. Under 'Continue' either way the next native child starts wherever the
# runner already stood. So the push is -LiteralPath, the location is READ BACK, and it must be the
# tree on the same key every other "same directory" question in this file uses. Returns '' when the
# location IS the tree -- the caller then owns exactly one Pop-Location -- and otherwise a refusal
# text, with nothing left pushed. WHAT A CHILD SEES, MEASURED: a native child started from that
# location gets the tree as its process working directory, brackets and all (cmd.exe's `cd` prints
# it). A powershell.exe child is the one exception in what it REPORTS: it cannot set its own initial
# location to a path holding '[' or ']' and answers Get-Location with $PSHOME, while its process
# working directory is still the tree -- so a stub that wants to prove where it ran reads
# [Environment]::CurrentDirectory, and a PowerShell suite script in such a tree should not trust
# Get-Location.
function Enter-WorktreeLocation {
    param([string]$Location, [string]$Tree)
    try { Push-Location -LiteralPath $Location -ErrorAction Stop }
    catch { return "the worker worktree $Tree could not be entered as the working directory ($($_.Exception.Message)). Nothing was spawned or run in it." }
    $hereNow = ''
    try { $hereNow = [string](Get-Location).ProviderPath } catch { $hereNow = '' }
    $treeKey = ConvertTo-WorktreePathKey $Tree
    if ((-not $hereNow) -or (-not $treeKey) -or ((ConvertTo-WorktreePathKey $hereNow) -ne $treeKey)) {
        Pop-Location
        return "the working directory reached was '$hereNow', which is not the worker worktree $Tree, so nothing was spawned or run there: a worker never runs outside its own tree."
    }
    return ''
}

# THE FIRST JUNCTION OR SYMBOLIC LINK ON A PATH (review, and its second
# round). Walks from $Top -- itself included only with -IncludeTop -- down through every component of
# $PathText and answers with an object: .link is the first EXISTING entry that IS a junction or a
# symbolic link, .unknown is the first entry whose nature could not be determined (with the reason), and
# both are '' when the path is clear. An entry that does not exist ends the walk clear (nothing below it
# can exist either).
#
# A LINK IS A REPARSE TAG, NOT THE REPARSE-POINT ATTRIBUTE. [System.IO.File]::GetAttributes reads the
# entry itself without following it, and FILE_ATTRIBUTE_REPARSE_POINT is set on EVERY reparse point, most
# of which are not links. Measured read-only in review round 2: the OneDrive folder
# %USERPROFILE%\OneDrive\Documents reads 'ReadOnly, Directory, ReparsePoint' with reparse tag 0x9000601A
# (a cloud-files placeholder), and every directory under a OneDrive root carries the attribute -- so the
# attribute test this replaced skipped every .worktreeinclude source under such a mission root as "a
# junction or symbolic link", the plan came out empty, 0 copied equalled 0 planned, and the worker was
# spawned without its .claude/. So an entry that carries the attribute has its TAG read -- FindFirstFileW's
# dwReserved0, through the helper below, compiled once per run and only when an entry first needs it --
# and only IO_REPARSE_TAG_MOUNT_POINT (0xA0000003: a junction, or a mounted volume) and
# IO_REPARSE_TAG_SYMLINK (0xA000000C) are links. A cloud-files, dedup, WOF or any other tag is the entry's
# own content, and the walk goes on through it. Measured on the host that wrote this: a junction reads
# 0xA0000003 and the OneDrive folder reads 0x9000601A; a directory symbolic link could not be created there
# without the privilege to create one, so 0xA000000C is the documented value and was not measured.
#
# FAILS CLOSED, and says why in .unknown: a path that does not lie under $Top, an entry whose attributes
# cannot be read for any reason other than its absence, a helper that could not be compiled, and a tag
# that could not be read. What .unknown means is the CALLER's: a destination refuses the dispatch, and a
# source refuses the placement -- it is never merely skipped, because a skip is how the empty plan above
# was reached.
$script:LinkTagReaderState = ''
$script:LinkTagReaderSource = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace LamDispatch {
    public static class ReparseTagReader {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct FindData {
            public uint Attributes;
            public uint CreationLow; public uint CreationHigh;
            public uint AccessLow; public uint AccessHigh;
            public uint WriteLow; public uint WriteHigh;
            public uint SizeHigh; public uint SizeLow;
            public uint Reserved0; public uint Reserved1;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string FileName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)] public string AlternateFileName;
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr FindFirstFileW(string fileName, out FindData data);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FindClose(IntPtr handle);
        // The reparse tag of the entry itself (0 when it carries no reparse point). The query is made in
        // the \\?\ form so a path of MAX_PATH or more is read too. Throws when the entry cannot be read.
        public static uint ReadTag(string fullPath) {
            string query = fullPath.StartsWith(@"\\?\") ? fullPath : (fullPath.StartsWith(@"\\") ? @"\\?\UNC\" + fullPath.Substring(2) : @"\\?\" + fullPath);
            FindData data;
            IntPtr handle = FindFirstFileW(query, out data);
            if (handle == new IntPtr(-1)) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            FindClose(handle);
            return ((data.Attributes & 0x400u) != 0u) ? data.Reserved0 : 0u;
        }
        public static bool IsLinkTag(uint tag) { return (tag == 0xA0000003u) || (tag == 0xA000000Cu); }
        public static string Hex(uint tag) { return "0x" + tag.ToString("X8"); }
    }
}
'@
function Get-LinkTagOfEntry {
    param([string]$EntryPath)
    if (-not $script:LinkTagReaderState) {
        if ('LamDispatch.ReparseTagReader' -as [type]) { $script:LinkTagReaderState = 'ready' }
        else {
            try {
                Add-Type -TypeDefinition $script:LinkTagReaderSource -Language CSharp -ErrorAction Stop
                $script:LinkTagReaderState = 'ready'
            } catch {
                # The compiler's message spans lines; it is folded to one so the refusal that carries it stays one line.
                $tagCompileError = ("$($_.Exception.Message)" -replace '\s+', ' ').Trim()
                $script:LinkTagReaderState = "the reparse-tag reader could not be compiled ($tagCompileError)"
            }
        }
    }
    if ($script:LinkTagReaderState -ne 'ready') { return [pscustomobject]@{ isLink = $false; tag = ''; error = $script:LinkTagReaderState } }
    try {
        $tagValue = [LamDispatch.ReparseTagReader]::ReadTag($EntryPath)
        return [pscustomobject]@{ isLink = [LamDispatch.ReparseTagReader]::IsLinkTag($tagValue); tag = [LamDispatch.ReparseTagReader]::Hex($tagValue); error = '' }
    } catch {
        $tagEx = $_.Exception
        if (($tagEx -is [System.Management.Automation.MethodInvocationException]) -and $tagEx.InnerException) { $tagEx = $tagEx.InnerException }
        return [pscustomobject]@{ isLink = $false; tag = ''; error = "its reparse tag could not be read ($($tagEx.Message))" }
    }
}
function Get-FirstLinkOnPath {
    param([string]$Top, [string]$PathText, [switch]$IncludeTop)
    $topFull = ''; $pathFull = ''
    try {
        $topFull  = [System.IO.Path]::GetFullPath($Top).TrimEnd('\')
        $pathFull = [System.IO.Path]::GetFullPath($PathText).TrimEnd('\')
    } catch { return [pscustomobject]@{ link = ''; unknown = "$PathText (its full path could not be formed: $($_.Exception.Message))" } }
    if (-not $pathFull.StartsWith($topFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return [pscustomobject]@{ link = ''; unknown = "$pathFull (not under $topFull)" } }
    $walkEntries = @()
    if ($IncludeTop) { $walkEntries += $topFull }
    $walkAt = $topFull
    foreach ($walkPart in $pathFull.Substring($topFull.Length + 1).Split('\')) {
        if (-not $walkPart) { continue }
        $walkAt = $walkAt + '\' + $walkPart
        $walkEntries += $walkAt
    }
    foreach ($walkEntry in $walkEntries) {
        try { $walkAttr = [System.IO.File]::GetAttributes($walkEntry) }
        catch {
            $walkEx = $_.Exception
            if (($walkEx -is [System.Management.Automation.MethodInvocationException]) -and $walkEx.InnerException) { $walkEx = $walkEx.InnerException }
            if (($walkEx -is [System.IO.FileNotFoundException]) -or ($walkEx -is [System.IO.DirectoryNotFoundException])) { return [pscustomobject]@{ link = ''; unknown = '' } }
            return [pscustomobject]@{ link = ''; unknown = "$walkEntry (its attributes could not be read: $($walkEx.Message))" }
        }
        if (-not $walkAttr.HasFlag([System.IO.FileAttributes]::ReparsePoint)) { continue }
        $walkTag = Get-LinkTagOfEntry -EntryPath $walkEntry
        if ($walkTag.error) { return [pscustomobject]@{ link = ''; unknown = "$walkEntry (it carries a reparse point, and $($walkTag.error))" } }
        if ($walkTag.isLink) { return [pscustomobject]@{ link = "$walkEntry"; unknown = '' } }
    }
    return [pscustomobject]@{ link = ''; unknown = '' }
}

# --- NOW FOR EVERY DISPATCH: MATERIALISE THE TREE AT ITS CUT POINT, BEFORE THE WORKER EXISTS --
# This ladder was built for a DECLARED base so the CLI would find the tree already cut and reuse
# it (measured; see the read above). The relocation removes the CLI's half entirely, so the ladder is
# now the ONLY creation site -- for a real worker and for a -WorkerCommand stub alike. The stub path
# used to add its own `worktree add --detach` because the CLI was not there to do it; that second
# site is gone, and a stub now runs in exactly the tree a real worker would.
#
# THE LADDER, and what each rung is for:
#   0. REFUSE a mission root that is not a git repository. There was once a proceed-and-record branch
#      here ("no worktree, and worktree anchors will be null"), because the CLI was the one creating
#      trees. Without --worktree nothing would create one, and a worker spawned with no tree would
#      work in a directory nobody placed; so it refuses, before the spawn. (Reached rarely in
#      practice: the pre-push decider check above already refuses a root git cannot answer for.)
#   1. RESOLVE the cut point IN THIS REPOSITORY. A declared base naming no commit here is a dispatch
#      nobody can honour; saying so now costs nothing, and saying it after a worker has run costs the
#      run. NO DECLARED BASE: the cut point is the mission root's own HEAD. Before the relocation the
#      CLI chose it and chose origin/main (the cut-point defect); that cut no longer exists, because only
#      --worktree could make it. The HEAD cut is RECORDED and not asserted (worktree_base_honoured
#      stays false), exactly as the undeclared case always was.
#   2. CREATE the directory when it is absent, its parent '<leaf>-worktrees' first, on branch
#      worktree-<name> -- the convention ADR-026 documented and the operator kept. Where that branch
#      already exists -- the shape seq 159 hit, a retired tree leaving its branch behind --
#      `worktree add -b` fails with "a branch named ... already exists" (measured: exit 255), so the
#      runner retries DETACHED. The retry is RECORDED in git_errors, never silent. An EXISTING tree is
#      reused where it stands, and for a declared base is then fast-forwarded (rung 4).
#   3. PROVE THE DIRECTORY IS THIS MISSION ROOT'S OWN LINKED WORKTREE before any command that changes
#      anything runs in it (two read-only `git rev-parse` queries are how it is proved). The home is
#      outside the mission root, so a stray directory there that is not a worktree would make
#      `git -C <tree>` walk UP into whatever repository contains the home -- and rung 4's
#      `merge --ff-only` would then move that repository. So: its top level must be the tree itself
#      and its common git dir must be the mission root's. Asked of git, compared on the key above.
#      RESIDUAL, RECORDED AND DELIBERATELY NOT CURED (review, and its second
#      round): git prints --show-toplevel with links RESOLVED and the key above does not resolve
#      them, so a dispatch whose mission root, <leaf>-worktrees home or tree was reached through a
#      junction, a symbolic link or a subst drive refuses even the tree this runner has just created.
#      Measured through a junction on the MISSION ROOT: the `worktree add` succeeded, this check refused
#      (exit 2, run record closed), every re-dispatch through the link refused the same way, and the
#      same dispatch given the root's REAL path ran and used that tree. Measured through a junction on
#      the HOME, the mission root given by its real path: the same refusal, git reporting the tree
#      under the junction's target -- where no real path for the root helps, and removing or pruning
#      the tree does not either, because the next dispatch recreates it through the same junction. It
#      stays fail-closed -- no link-resolution code -- and the refusal says to give real paths and to
#      un-link the home. The same refusal names `git worktree remove` / `git worktree prune` rather
#      than deleting the directory,
#      because a registered tree deleted by hand is refused on the next dispatch too (measured in the
#      review: the `-b` add fails on the existing branch, and the detached retry on "a missing but
#      already registered worktree").
#   4. FAST-FORWARD an existing tree to a declared base (`git merge --ff-only <base>`, the interim's own
#      command, moved out of the brief's prose into the machinery) and ASSERT: a tree not
#      at the declared base REFUSES, naming BOTH shas. Before the spawn, which is "before the worker's
#      first commit" in the strongest sense available: before the worker exists at all.
#
# WHAT REMAINS THE BRIEF'S. The S3b/S4 clause ordering a worker to fast-forward and to assert its own
# HEAD is this runner's act for every dispatch that declares a base. What the brief still owns is the
# SELF-DISCIPLINE half -- materialise revisions with `git show` / `git archive` rather than checking
# them out -- because that governs what a worker does INSIDE a tree the runner has already placed.
#
# WHAT HAPPENS WHEN NOTHING IS DECLARED: the run PROCEEDS and the absence is RECORDED, and that
# asymmetry is deliberate rather than timid. A runner cannot know the right cut point for a dispatch
# that names none, so refusing there would impose a new requirement on the artifact template, which
# is that template's business. Measured before this cure chose it: all 39 real dispatch artifacts under
# .mission/dispatches carry base_head_at_authoring, so the recorded branch is unreachable for live work
# today. worktree_base_observed now carries the sha the tree stood at BEFORE the worker ran -- the
# mission root's HEAD for a tree this runner cut, or wherever a reused tree stood -- which hands the
# operator the exact sha to put in the artifact rather than a complaint.
$declaredBaseResolved = ''
$worktreeBaseObserved = ''
$worktreeBaseHonoured = $false
$baseDenial           = ''
$treeDenial           = ''
$worktreeCutAt        = ''
$worktreeCreatedHere  = $false
if (-not $isRepo) {
    $treeDenial = "the mission root '$MissionRoot' is not a git repository (no .git at its top), so no worktree can be cut for this dispatch and a worker would run in a directory nobody placed. Nothing was spawned."
} else {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # PARENTHESISED, not '$declaredBase^{commit}': an argument-position concatenation is the
        # shape that splits silently on PS 5.1, and a rev-parse handed three arguments instead of
        # one resolves something nobody asked about.
        if ($declaredBase) {
            $baseRev = & git -C $MissionRoot rev-parse --verify --quiet ($declaredBase + '^{commit}') 2>&1
            if ($LASTEXITCODE -ne 0) {
                $baseDenial = "the dispatch declares $declaredBaseField $declaredBase, and that is not a commit in $MissionRoot. A cut point this repository does not have is not a cut point a worker can be placed on."
            } else {
                $declaredBaseResolved = ("$baseRev").Trim()
                $worktreeCutAt = $declaredBaseResolved
            }
        } else {
            $headRev = & git -C $MissionRoot rev-parse --verify --quiet 'HEAD^{commit}' 2>&1
            if ($LASTEXITCODE -ne 0) {
                $treeDenial = "the mission root '$MissionRoot' has no commit at HEAD, and this dispatch declares no $declaredBaseField, so there is no cut point to create its worktree at. Nothing was spawned."
            } else {
                $worktreeCutAt = ("$headRev").Trim()
            }
        }
        if ($worktreeCutAt -and (-not (Test-Path -LiteralPath $worktreePath))) {
            if (-not (Test-Path -LiteralPath $worktreeHome)) {
                try { New-Item -ItemType Directory -Path $worktreeHome -Force | Out-Null }
                catch { $gitErrors += "the worktree home $worktreeHome could not be created: $($_.Exception.Message)" }
            }
            $wtNew = & git -C $MissionRoot worktree add -b "worktree-$worktreeName" $worktreePath $worktreeCutAt 2>&1
            if ($LASTEXITCODE -ne 0) {
                $gitErrors += "worktree add -b worktree-$worktreeName failed ($LASTEXITCODE): $wtNew -- retrying detached"
                $wtDet = & git -C $MissionRoot worktree add --detach $worktreePath $worktreeCutAt 2>&1
                if ($LASTEXITCODE -ne 0) { $gitErrors += "worktree add --detach failed ($LASTEXITCODE): $wtDet" }
                else { $worktreeCreatedHere = $true }
            } else { $worktreeCreatedHere = $true }
            if (-not (Test-Path -LiteralPath $worktreePath)) {
                $treeDenial = "no worktree could be created at $worktreePath from $MissionRoot at $worktreeCutAt (git said: $(@($gitErrors | Select-Object -Last 2) -join ' / ')). Nothing was spawned."
            }
            # UI-1 S1 (ADR-045): a worktree is its own stream -- its own registry row and its own telemetry
            # folder, which git never brings along (the folder is ignored). Registered only when the mission
            # root itself is a stream; it prints nothing and can fail nothing.
            if ($worktreeCreatedHere -and (Test-Path -LiteralPath $worktreePath)) {
                try {
                    $tmW = Join-Path $PSScriptRoot 'mission-telemetry.ps1'
                    if (Test-Path -LiteralPath $tmW -PathType Leaf) { . $tmW; $null = Register-MissionWorktree -PrimaryRoot $MissionRoot -WorktreeRoot $worktreePath }
                } catch { }
            }
        }
        if ($worktreeCutAt -and (-not $treeDenial) -and (Test-Path -LiteralPath $worktreePath)) {
            $wtTop    = & git -C $worktreePath rev-parse --show-toplevel 2>&1
            $wtTopOk  = ($LASTEXITCODE -eq 0)
            $wtCommon = & git -C $worktreePath rev-parse --path-format=absolute --git-common-dir 2>&1
            $wtComOk  = ($LASTEXITCODE -eq 0)
            $mrCommon = & git -C $MissionRoot rev-parse --path-format=absolute --git-common-dir 2>&1
            $mrComOk  = ($LASTEXITCODE -eq 0)
            $isOwnTree = ($wtTopOk -and $wtComOk -and $mrComOk -and
                          ((ConvertTo-WorktreePathKey "$wtTop") -eq (ConvertTo-WorktreePathKey $worktreePath)) -and
                          ((ConvertTo-WorktreePathKey "$wtCommon") -ne '') -and
                          ((ConvertTo-WorktreePathKey "$wtCommon") -eq (ConvertTo-WorktreePathKey "$mrCommon")))
            if (-not $isOwnTree) {
                $treeDenial = "the directory at $worktreePath is not a linked worktree of $MissionRoot (git reports its top level as '$("$wtTop".Trim())' and its common git dir as '$("$wtCommon".Trim())'; the mission root's is '$("$mrCommon".Trim())'). No command that changes anything was run in it (only read-only git rev-parse queries), and nothing was spawned. If the mission root, its worktrees home $worktreeHome or the tree itself was reached through a junction, a symbolic link or a subst drive, give real paths and un-link the home (and the tree, if it is the link): git reports top levels with links resolved and this check does not resolve them, so removing or pruning the tree alone does not help -- the next dispatch recreates it through the same link. Otherwise, if the directory is a worktree git has registered, remove it with 'git worktree remove' (or, once its directory is gone, 'git worktree prune') -- deleting the directory alone leaves it registered and the next dispatch is refused for that instead; if it is a stray directory, remove it. Then dispatch again."
            } else {
                $headOut = & git -C $worktreePath rev-parse HEAD 2>&1
                if ($LASTEXITCODE -eq 0) { $worktreeBaseObserved = ("$headOut").Trim() }
                if ($declaredBaseResolved) {
                    if ($worktreeBaseObserved -and ($worktreeBaseObserved -ne $declaredBaseResolved)) {
                        $ffOut = & git -C $worktreePath merge --ff-only $declaredBaseResolved 2>&1
                        if ($LASTEXITCODE -ne 0) { $gitErrors += "merge --ff-only $declaredBaseResolved failed ($LASTEXITCODE): $ffOut" }
                        $headOut = & git -C $worktreePath rev-parse HEAD 2>&1
                        if ($LASTEXITCODE -eq 0) { $worktreeBaseObserved = ("$headOut").Trim() }
                    }
                    if ($worktreeBaseObserved -eq $declaredBaseResolved) { $worktreeBaseHonoured = $true }
                    if (-not $worktreeBaseHonoured) {
                        $standsAt = if ($worktreeBaseObserved) { $worktreeBaseObserved } else { 'no readable HEAD' }
                        $baseDenial = "the worktree for this dispatch stands at $standsAt and the dispatch declares $declaredBaseField $declaredBaseResolved. It could not be brought to the declared base, so a worker would build on -- or judge -- a tree nobody asked for. Worktree: $worktreePath"
                    }
                }
            }
        }
    } finally { $ErrorActionPreference = $prevEap }
}
# DENIED AFTER THE PREFERENCE IS RESTORED. Deny-Dispatch exits, and an exit taken while
# $ErrorActionPreference is still forced to 'Continue' leaves the process in a state this script
# never chose -- the finally above must have run first.
if ($treeDenial) {
    Close-RunRecordBeforeRefusal
    Deny-Dispatch $treeDenial
}
if ($baseDenial) {
    # THE RUN RECORD IS CLOSED BEFORE THIS REFUSAL, IN ITS OWN ORDER (.rc, then .ended).
    # This was the FIRST refusal in the file that could fire after .started is on disk -- every
    # earlier Deny-Dispatch site sits above the run record -- and a refusal that simply walked away
    # from it would leave a dispatch that IS finished reading `started-not-finished` for ever, which
    # is the exact ambiguity the run record exists to remove. The tree refusal above now shares the closure.
    Close-RunRecordBeforeRefusal
    Deny-Dispatch $baseDenial
}
if ($worktreeBaseHonoured) {
    # The leading clause is kept word for word: WP-6 S-1b reads "worktree cut at the declared <field> <sha>".
    Write-Line "mission-dispatch: worktree cut at the declared $declaredBaseField $declaredBaseResolved -- this runner's act, at $worktreePath, and the worker is spawned in it."
} elseif (-not $declaredBase) {
    $cutVerb = if ($worktreeCreatedHere) { "created at the mission root's HEAD $worktreeBaseObserved" } else { "reused where it stands, at $worktreeBaseObserved" }
    Write-Line "mission-dispatch: this dispatch declares no $declaredBaseField -- the worktree at $worktreePath was $cutVerb. The cut point is RECORDED in the anchors, not asserted."
}

# =============================================================================================
# LAM-ACCEPT WP-5 K-2 -- THE RUNNER PLACES .worktreeinclude's IGNORED ENTRIES INTO THE TREE
# =============================================================================================
# `git worktree add` gives a tree every TRACKED file and nothing else. What the mission root carries
# UNTRACKED AND IGNORED -- above all its .claude/, which holds the hook registration and without
# which a worker has no evidence plane (.worktreeinclude:16-19) -- is absent unless something copies
# it. .worktreeinclude exists to name those entries (LAM-ACCEPT WP-5 K-2) and under --worktree that
# copy was left to the CLI; without --worktree the runner does it, here, after the tree stands at its
# base and BEFORE the spawn.
#
# THE SEMANTICS, MEASURED IN A SCRATCH REPOSITORY BEFORE THIS WAS WRITTEN. A file is placed exactly
# when it is BOTH
#   (A) untracked and ignored in the mission root under git's standard excludes
#       -- `git ls-files -z --others --ignored --exclude-standard`, and
#   (B) matched by .worktreeinclude's own gitignore-syntax patterns
#       -- `git ls-files -z --others --ignored --exclude-from=<root>\.worktreeinclude`.
# (B) alone is not enough: it also lists untracked files that are NOT ignored (measured: an
# untracked-not-ignored file named in .worktreeinclude, and a new untracked file under the listed
# .mission/contract/). A TRACKED entry such as .mission/contract/ is in neither list -- the tree has
# it at its base already, and a divergent working copy in the mission root must not overwrite it --
# and any path COMMITTED AT THE TREE'S HEAD is excluded again by name, in case the base commits what
# the mission root's index does not (a declared older base that tracked a path the mission root has
# since untracked and ignored). That list is `git ls-tree -r -z --name-only HEAD` in the tree, NOT the
# tree's index (review round 4): in a reused tree an entry a worker only staged, with 'git add -f',
# is not committed, so it is placed afresh -- deleted first, then copied -- and the worker's staged
# bytes are not what the tree holds. THAT NAME COMPARISON IGNORES CASE (found in review): on NTFS
# a tree tracking 'Cfg/app.json' and a mission root listing 'cfg/app.json' name ONE file, and an
# ordinal comparison let the copy overwrite the tracked base bytes (measured). On a case-sensitive
# filesystem the same comparison can only over-skip -- withhold a placement whose name differs from a
# committed one in case alone -- which is the safe direction: nothing committed is ever overwritten.
#
# NEVER A NESTED REPOSITORY OR A LINKED WORKTREE. The real main checkout's .claude/ holds
# .claude/worktrees/ with dozens of locked linked worktrees, each a full checkout. Measured: git lists
# an embedded repository and a linked worktree as ONE 'dir/' entry and does not descend into either,
# so an entry ending in '/' is skipped, and so -- belt and braces -- is any entry lying under a
# directory that holds a .git entry (a file in a linked worktree, a directory in a clone), and any
# entry that is not a plain file on disk.
#
# NEVER CONTENT FROM BEHIND A LINK, ON EITHER SIDE (review, and its second
# round). A LINK here is a junction or a symbolic link, told apart by its reparse TAG
# (Get-FirstLinkOnPath, above): a OneDrive or other cloud-files folder also carries the reparse-point
# attribute, and it is not one.
#   SOURCE: git for Windows follows a junction, so an ignored junction such as .claude/ext pointing
#   outside the repository listed its target's files as ordinary ignored entries, and they were
#   placed as plain files the worker could read (measured). An entry whose source path passes through
#   a junction or symbolic link at any directory between the mission root and the file -- or is one --
#   is SKIPPED and named among the skipped entries; it is not the mission root's own content. A source
#   whose path CANNOT BE CLASSIFIED refuses the placement rather than being skipped, naming that source.
#   DESTINATION: on a REUSED tree a worker may have left a junction where an ignored directory was,
#   and the copy wrote THROUGH it, outside the tree, while the length check looked through it too and
#   passed (measured). Before each copy every existing entry from the tree root down to the
#   destination file is checked, and one that is a junction or symbolic link -- or that cannot be
#   classified -- REFUSES the dispatch: nothing further is copied, and the run record is closed first.
#   A HARD LINK is not a reparse point at all, so no walk sees it (review round 2): a destination
#   file hard-linked to a file outside the tree was overwritten IN PLACE by a copy with overwrite, and
#   the outside file received the placed bytes (measured: exit 0, 'placed 2'). So once the walk has
#   cleared the path, an EXISTING destination is DELETED and the copy is made WITHOUT overwrite:
#   deleting a name breaks the link and leaves the other name's bytes alone. A delete that fails
#   refuses, record closed, and nothing is overwritten instead; a destination that reappears between
#   the delete and the copy fails that copy, which refuses as a short copy. THAT REFUSAL IS DELIBERATE
#   FOR BOTH SHAPES A DELETE FAILS ON (review round 3): a READ-ONLY destination (which the overwrite
#   refused too), and one HELD OPEN by another process without delete sharing -- which the overwrite
#   placed successfully, measured against a handle that shared read and write. Falling back to the
#   overwrite there is exactly the write through a hard link this rule exists to stop, so it fails closed.
#
# THE EVIDENCE PLANE IS CHECKED, NOT INFERRED (review round 3; review round 4). Round 2
# refused when the plan came out empty with at least one entry skipped as a link, and that guarded the
# wrong thing twice, both measured. It REFUSED a tree whose .claude/settings.json is tracked at its base,
# and one whose only listed entries sit behind pnpm-style node_modules junctions, saying the worker "has
# no .claude/" -- false both times. And it MISSED a junctioned ROOT .claude/ whenever any other entry (a
# .mission/contract/ file) was planned: exit 0, the worker spawned with no .claude/ and no evidence
# plane. Round 3 checked the invariant itself, but twice too narrowly, both measured. It ran only when
# git listed an untracked, ignored entry under the root .claude/, so a mission root that TRACKS
# .claude/settings.json, dispatched at a declared base older than the commit that added it, with nothing
# ignored under .claude/, spawned the worker without it (exit 0) -- while one unrelated ignored
# settings.local.json turned the same shape into a refusal. And it read "tracked" from the tree's INDEX,
# so in a reused tree a worker's altered settings.json, staged and never committed, was skipped as
# tracked and counted as held (exit 0, the tree holding '{}').
#   THE TRIGGER IS THE PATTERN. The check applies when the mission root has .claude/settings.json ON DISK
#   and .worktreeinclude's patterns MATCH that path, tracked or not: `git --icase-pathspecs -C <root>
#   ls-files -z --cached --others --ignored --exclude-from=<root>\.worktreeinclude -- .claude/settings.json`
#   names it. Measured: it lists a tracked file, an untracked ignored one and an untracked unignored one,
#   and it lists nothing when the patterns do not match or a later '!' pattern negates the match. The
#   pathspec IGNORES CASE because this filesystem does: with core.ignorecase=true a plain pathspec listed
#   nothing for a mission root's .Claude/Settings.json, tracked or untracked, and a plain 'git diff' in a
#   tree saw neither a modified nor a deleted one (measured). It is the global option and not the
#   ':(icase)' magic because GIT_LITERAL_PATHSPECS=1 in the environment makes the magic a literal name
#   that matches nothing -- the check silently off -- and makes the option fail, exit 128 (measured),
#   which refuses. A listing that fails refuses the placement as unplannable, record closed.
#   HELD MEANS THE RIGHT BYTES ARE IN THE TREE. After the copies the tree's .claude/settings.json must
#   EXIST and either (a) have been PLACED by this run and read back byte-equal to the mission root's, or
#   (b) be COMMITTED AT THE TREE'S HEAD -- in the ls-tree list the placement's skip reads, not the index --
#   with the working file unmodified against HEAD: `git diff --quiet HEAD -- .claude/settings.json` exits 0
#   (measured: 0 unmodified, including a CRLF checkout of an LF blob; 1 modified, staged or not, and 1
#   deleted; and 0 for a file HEAD does not have at all, which is why (b) also asks ls-tree). Otherwise
#   the dispatch is REFUSED, record closed, naming which case failed: placed but absent or not byte-equal;
#   committed at the tree's HEAD but absent, modified, or not comparable; or neither committed nor placed,
#   because the placement skipped it (reached through a link, or otherwise), because the mission root
#   TRACKS it and the tree's HEAD -- the declared base, where one is declared -- does not commit it, or
#   because it is untracked but not ignored in the mission root.
#   WHAT IT DOES NOT CHECK. A settings.json committed at the tree's HEAD is held whoever committed it: a
#   worker that commits an altered one in its own reused tree passes (the staging route is closed; the
#   commit route is not). What keeps a worker from writing or naming a .claude/settings.json at all is the
#   guard, not this check. And a mission root with NO .claude/settings.json on disk is not checked --
#   neither a root .claude/ holding other files only (whose pattern listing is empty anyway) nor a root
#   whose index still tracks a settings.json deleted from its disk: there is no registration on the
#   mission root's own disk to carry into the tree.
# It is checked last, after the short-copy refusal, so a copy that failed is refused as what it is. An
# unclassifiable source never reaches it: that refuses the whole placement first, naming the source. An
# entry skipped as a link anywhere else -- node_modules/pkg/.claude/x.json behind a junction -- is skipped
# and named, and refuses nothing.
#
# ENCODING, MEASURED: PS 5.1 decodes native stdout with [Console]::OutputEncoding, and under the
# default code page a non-ASCII file name came back as a path that does not exist. The reads run under
# UTF-8 and the encoding is restored. IF IT CANNOT BE SET, THE PLACEMENT IS REFUSED before git is asked
# (found in review). Nothing later would refuse it: a mis-decoded name reads identically
# wrong in both lists, so it passes their intersection, fails the plain-file test and is skipped --
# measured with the console left at code page 1252 and the setter planted to throw, the worker was
# spawned without that file and the run exited 0. With the encoding set, a listed name that still is
# not a plain file on disk is skipped and named among the skipped entries (the first eight are
# printed), not refused.
#
# ARITY, ASSERTED, AND A SHORT COPY FAILS CLOSED BEFORE THE SPAWN, because a worker spawned without its
# .claude/ has no evidence plane and nothing afterwards could tell. The verify reads each source and
# destination back without throwing (found in review): a file that vanished after its copy counts as
# unverified and refuses through the same closed-record path, rather than escaping to the top-level
# trap (exit 5) with .started written and .rc/.ended never. A MISSING .worktreeinclude is not refused
# -- plenty of repositories have none -- and says so in one line.
#
# BYTE-EQUAL, READ BACK (THE EVIDENCE PLANE, above, case (a)): a placed .claude/settings.json must carry the
# mission root's bytes, not merely its length. A file that cannot be read compares unequal.
function Test-SameFileBytes {
    param([string]$Left, [string]$Right)
    $hasher = $null
    try {
        $hasher    = [System.Security.Cryptography.SHA256]::Create()
        $leftHash  = [System.BitConverter]::ToString($hasher.ComputeHash([System.IO.File]::ReadAllBytes($Left)))
        $rightHash = [System.BitConverter]::ToString($hasher.ComputeHash([System.IO.File]::ReadAllBytes($Right)))
        return ($leftHash -ceq $rightHash)
    } catch {
        return $false
    } finally {
        if ($null -ne $hasher) { $hasher.Dispose() }
    }
}
$includeFile     = Join-Path $MissionRoot '.worktreeinclude'
$includeDenial   = ''
$wtiPlan         = @()
$wtiSkipped      = @()
$wtiCopied       = 0
$wtiCopyErrors   = @()
$wtiSrcDenial    = ''
# THE EVIDENCE PLANE's file (above), in the mission root and in the tree, and whether the mission root has it on disk.
$wtiRootSettings       = Join-Path $MissionRoot '.claude\settings.json'
$wtiTreeSettings       = Join-Path $worktreePath '.claude\settings.json'
$wtiRootSettingsOnDisk = [System.IO.File]::Exists($wtiRootSettings)
if (-not (Test-Path -LiteralPath $includeFile -PathType Leaf)) {
    Write-Line "mission-dispatch: no .worktreeinclude at $includeFile -- nothing was placed into the worktree."
} else {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $prevOutEnc = $null
    # (B) FIRST, because it is small: measured read-only on the real main checkout, (B) listed 49
    # entries in about 2 s while (A) listed 158,054 in about 3.4 s. (A) is read only when (B) names
    # something; THE EVIDENCE PLANE's pattern listing (above) only when the mission root has
    # .claude/settings.json on disk (measured there in about 0.5 s, against 30 ms for the same listing
    # without --icase-pathspecs); and the tree's committed list only when either of the two names something.
    $wtiListedOut  = @(); $wtiListedExit  = 0
    $wtiIgnoredOut = @(); $wtiIgnoredExit = 0
    $wtiMatchOut   = @(); $wtiMatchExit   = 0
    $wtiTrackedOut = @(); $wtiTrackedExit = 0
    $wtiEncodingError = ''
    try {
        try { $prevOutEnc = [Console]::OutputEncoding; [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { $wtiEncodingError = "$($_.Exception.Message)" }
        if (-not $wtiEncodingError) {
            $wtiListedOut   = @(& git -C $MissionRoot ls-files -z --others --ignored ('--exclude-from=' + $includeFile) 2>&1)
            $wtiListedExit  = $LASTEXITCODE
            $wtiListedAny   = (($wtiListedExit -eq 0) -and (@($wtiListedOut | Where-Object { ($_ -is [string]) -and $_ }).Count -gt 0))
            if ($wtiRootSettingsOnDisk) {
                $wtiMatchOut  = @(& git --icase-pathspecs -C $MissionRoot ls-files -z --cached --others --ignored ('--exclude-from=' + $includeFile) -- '.claude/settings.json' 2>&1)
                $wtiMatchExit = $LASTEXITCODE
            }
            $wtiMatchAny    = (($wtiMatchExit -eq 0) -and (@($wtiMatchOut | Where-Object { ($_ -is [string]) -and $_ }).Count -gt 0))
            if ($wtiListedAny) {
                $wtiIgnoredOut  = @(& git -C $MissionRoot ls-files -z --others --ignored --exclude-standard 2>&1)
                $wtiIgnoredExit = $LASTEXITCODE
            }
            if ($wtiListedAny -or $wtiMatchAny) {
                $wtiTrackedOut  = @(& git -C $worktreePath ls-tree -r -z --name-only HEAD 2>&1)
                $wtiTrackedExit = $LASTEXITCODE
            }
        }
    } finally {
        if ($null -ne $prevOutEnc) { try { [Console]::OutputEncoding = $prevOutEnc } catch { } }
        $ErrorActionPreference = $prevEap
    }
    if ($wtiEncodingError) {
        $includeDenial = "the .worktreeinclude placement could not be planned: the console output encoding could not be set to UTF-8 ($wtiEncodingError), so git's file names could not be read reliably, and a name read in the wrong code page is skipped rather than refused by anything later. Nothing was placed, and nothing was spawned."
    } elseif (($wtiListedExit -ne 0) -or ($wtiIgnoredExit -ne 0) -or ($wtiMatchExit -ne 0) -or ($wtiTrackedExit -ne 0)) {
        $includeDenial = "the .worktreeinclude placement could not be planned: git exited $wtiListedExit (ls-files, the files .worktreeinclude matches), $wtiIgnoredExit (ls-files, the ignored files in the mission root), $wtiMatchExit (ls-files, whether .worktreeinclude matches the mission root's .claude/settings.json) and $wtiTrackedExit (ls-tree, the files committed at the tree's HEAD). A worker spawned without its ignored configuration, or with a hook registration nobody checked, has no evidence plane to rely on, so nothing was spawned."
    } else {
        # -z SEPARATES WITH NUL. Only the [string] items are stdout; anything else is an error record.
        $wtiIgnored = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        foreach ($wtiName in @((@($wtiIgnoredOut | Where-Object { $_ -is [string] }) -join "`n") -split "`0" | Where-Object { $_ })) { [void]$wtiIgnored.Add($wtiName) }
        # OrdinalIgnoreCase: see "THAT NAME COMPARISON IGNORES CASE" above (found in review).
        $wtiTracked = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($wtiName in @((@($wtiTrackedOut | Where-Object { $_ -is [string] }) -join "`n") -split "`0" | Where-Object { $_ })) { [void]$wtiTracked.Add($wtiName) }
        $wtiListedNames = @((@($wtiListedOut | Where-Object { $_ -is [string] }) -join "`n") -split "`0" | Where-Object { $_ })
        $wtiMatchNames  = @((@($wtiMatchOut | Where-Object { $_ -is [string] }) -join "`n") -split "`0" | Where-Object { $_ })
        $wtiRootKey = ConvertTo-WorktreePathKey $MissionRoot
        foreach ($wtiName in $wtiListedNames) {
            if (-not $wtiIgnored.Contains($wtiName)) { continue }
            if ($wtiName.EndsWith('/')) { $wtiSkipped += "$wtiName (a nested repository or linked worktree, as git lists one)"; continue }
            if ($wtiTracked.Contains($wtiName)) { $wtiSkipped += "$wtiName (committed at the tree's HEAD)"; continue }
            $wtiRel = $wtiName -replace '/', '\'
            $wtiSrc = Join-Path $MissionRoot $wtiRel
            $wtiSrcWalk = Get-FirstLinkOnPath -Top $MissionRoot -PathText $wtiSrc
            if ($wtiSrcWalk.unknown) { $wtiSrcDenial = "the .worktreeinclude placement could not tell whether the source of $wtiName passes through a junction or symbolic link: $($wtiSrcWalk.unknown). A source that cannot be classified is neither placed nor skipped, so nothing was placed, and nothing was spawned."; break }
            if ($wtiSrcWalk.link) {
                $wtiSkipped += "$wtiName (its source passes through a junction or symbolic link at $($wtiSrcWalk.link), so it is not the mission root's own content)"; continue
            }
            $wtiNested = ''
            $wtiDir = Split-Path -Parent $wtiSrc
            while ($wtiDir -and ((ConvertTo-WorktreePathKey $wtiDir) -ne $wtiRootKey) -and ((ConvertTo-WorktreePathKey $wtiDir).Length -gt $wtiRootKey.Length)) {
                if (Test-Path -LiteralPath (Join-Path $wtiDir '.git')) { $wtiNested = $wtiDir; break }
                $wtiDir = Split-Path -Parent $wtiDir
            }
            if ($wtiNested) { $wtiSkipped += "$wtiName (under $wtiNested, which holds a .git entry)"; continue }
            if (-not (Test-Path -LiteralPath $wtiSrc -PathType Leaf)) { $wtiSkipped += "$wtiName (not a plain file on disk)"; continue }
            $wtiPlan += [pscustomobject]@{ rel = $wtiRel; src = $wtiSrc; dst = (Join-Path $worktreePath $wtiRel) }
        }
        # A SOURCE THAT COULD NOT BE CLASSIFIED REFUSES THE WHOLE PLACEMENT: nothing is copied.
        if ($wtiSrcDenial) { $wtiPlan = @() }
        $wtiDstDenial = ''
        foreach ($wtiEntry in $wtiPlan) {
            $wtiDstWalk = Get-FirstLinkOnPath -Top $worktreePath -PathText $wtiEntry.dst -IncludeTop
            if ($wtiDstWalk.link) {
                $wtiDstDenial = "the .worktreeinclude placement met a junction or symbolic link at $($wtiDstWalk.link) on the destination path of $($wtiEntry.rel) inside the tree $worktreePath, so the copy would have been written through it, outside the tree. $wtiCopied file(s) had been placed before it and nothing further was copied. A reused tree with a link in it is not a tree to hand a worker; remove the link, or the tree with 'git worktree remove', and dispatch again. Nothing was spawned."
                break
            }
            if ($wtiDstWalk.unknown) {
                $wtiDstDenial = "the .worktreeinclude placement could not tell whether the destination path of $($wtiEntry.rel) inside the tree $worktreePath passes through a junction or symbolic link: $($wtiDstWalk.unknown). A destination that cannot be classified is refused as a link would be: $wtiCopied file(s) had been placed before it and nothing further was copied. Nothing was spawned."
                break
            }
            # THE WALK HAS CLEARED THE PATH; AN EXISTING DESTINATION IS DELETED, THEN COPIED WITHOUT OVERWRITE,
            # so a hard link left there is broken rather than written through (review round 2, above).
            if ([System.IO.File]::Exists($wtiEntry.dst)) {
                $wtiDeleteError = ''
                try { [System.IO.File]::Delete($wtiEntry.dst) } catch { $wtiDeleteError = "$($_.Exception.Message)" }
                if ($wtiDeleteError) {
                    $wtiDstDenial = "the .worktreeinclude placement could not remove the existing $($wtiEntry.rel) in the tree $worktreePath before placing it afresh ($wtiDeleteError). An existing destination is removed first so that a hard link left there is broken rather than written through, and one that cannot be removed is not overwritten instead. $wtiCopied file(s) had been placed before it and nothing further was copied. Nothing was spawned."
                    break
                }
            }
            try {
                $wtiDstDir = Split-Path -Parent $wtiEntry.dst
                if (-not (Test-Path -LiteralPath $wtiDstDir)) { New-Item -ItemType Directory -Path $wtiDstDir -Force | Out-Null }
                [System.IO.File]::Copy($wtiEntry.src, $wtiEntry.dst, $false)
                $wtiCopied++
            } catch { $wtiCopyErrors += "$($wtiEntry.rel): $($_.Exception.Message)" }
        }
        $wtiVerified = 0
        foreach ($wtiCheck in $wtiPlan) {
            try {
                $wtiDstItem = Get-Item -LiteralPath $wtiCheck.dst -Force -ErrorAction SilentlyContinue
                $wtiSrcItem = Get-Item -LiteralPath $wtiCheck.src -Force -ErrorAction SilentlyContinue
                if ($wtiDstItem -and $wtiSrcItem -and (-not $wtiDstItem.PSIsContainer) -and (-not $wtiSrcItem.PSIsContainer) -and ($wtiDstItem.Length -eq $wtiSrcItem.Length)) { $wtiVerified++ }
            } catch { }
        }
        # THE EVIDENCE PLANE (above): where the mission root has .claude/settings.json on disk and .worktreeinclude's
        # patterns match it, the tree must hold it -- placed by this run and byte-equal, or committed at its HEAD and unmodified.
        $wtiEvidenceDenial = ''
        $wtiEvidenceApplies = ($wtiRootSettingsOnDisk -and ($wtiMatchNames.Count -gt 0))
        if ($wtiEvidenceApplies) {
            $wtiEvidenceInTree    = [System.IO.File]::Exists($wtiTreeSettings)
            $wtiEvidenceEntry     = @($wtiPlan | Where-Object { $_.rel -eq '.claude\settings.json' } | Select-Object -First 1)
            $wtiEvidencePlanned   = ($wtiEvidenceEntry.Count -gt 0)
            $wtiEvidenceSame      = ($wtiEvidencePlanned -and $wtiEvidenceInTree -and (Test-SameFileBytes -Left $wtiEvidenceEntry[0].src -Right $wtiTreeSettings))
            $wtiEvidenceCommitted = $wtiTracked.Contains('.claude/settings.json')
            $wtiEvidenceDiffExit  = -1
            $wtiEvidenceDiffSaid  = ''
            if ($wtiEvidenceCommitted -and $wtiEvidenceInTree) {
                $prevEap = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    $wtiEvidenceDiffOut  = @(& git --no-optional-locks --icase-pathspecs -C $worktreePath diff --quiet HEAD -- '.claude/settings.json' 2>&1)
                    $wtiEvidenceDiffExit = $LASTEXITCODE
                } finally { $ErrorActionPreference = $prevEap }
                $wtiEvidenceDiffSaid = (@(@($wtiEvidenceDiffOut) | ForEach-Object { ("$_" -replace '\s+', ' ').Trim() } | Where-Object { $_ }) -join ' | ')
            }
            $wtiEvidenceHeld = ($wtiEvidenceInTree -and ($wtiEvidenceSame -or ($wtiEvidenceCommitted -and ($wtiEvidenceDiffExit -eq 0))))
            if (-not $wtiEvidenceHeld) {
                $wtiEvidenceName = $wtiMatchNames[0]
                $wtiEvidenceAt   = if ($declaredBaseResolved) { "the declared $declaredBaseField $declaredBaseResolved, where the tree stands" } else { "the tree's HEAD $worktreeBaseObserved" }
                $wtiEvidenceSkip = @($wtiSkipped | Where-Object { $_.StartsWith('.claude/settings.json (', [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
                $wtiEvidenceListed = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($wtiName in $wtiListedNames) { [void]$wtiEvidenceListed.Add($wtiName) }
                if ($wtiEvidencePlanned) {
                    $wtiEvidenceWhy = "it was placed by this run and, read back, is $(if (-not $wtiEvidenceInTree) { 'absent from the tree' } else { 'not byte-equal to the mission root''s' })"
                } elseif ($wtiEvidenceCommitted -and (-not $wtiEvidenceInTree)) {
                    $wtiEvidenceWhy = "it is committed at $wtiEvidenceAt and absent from the tree"
                } elseif ($wtiEvidenceCommitted -and ($wtiEvidenceDiffExit -eq 1)) {
                    $wtiEvidenceWhy = "it is committed at $wtiEvidenceAt and the tree's working file is modified against HEAD (git diff --quiet exited 1)"
                } elseif ($wtiEvidenceCommitted) {
                    $wtiEvidenceWhy = "it is committed at $wtiEvidenceAt and git could not compare the tree's working file against HEAD (git diff exited $wtiEvidenceDiffExit$(if ($wtiEvidenceDiffSaid) { ': ' + $wtiEvidenceDiffSaid }))"
                } elseif ($wtiEvidenceSkip.Count -gt 0) {
                    $wtiEvidenceWhy = "it is not committed at $wtiEvidenceAt and was not placed, because the placement skipped it: $($wtiEvidenceSkip[0])"
                } elseif (-not $wtiEvidenceListed.Contains($wtiEvidenceName)) {
                    $wtiEvidenceWhy = "the mission root TRACKS it, and it is not committed at $wtiEvidenceAt -- a file the mission root tracks is never placed, only an untracked, ignored one is"
                } elseif (-not $wtiIgnored.Contains($wtiEvidenceName)) {
                    $wtiEvidenceWhy = "it is untracked in the mission root but not ignored there, and it is not committed at $wtiEvidenceAt -- only a file untracked AND ignored AND matched by .worktreeinclude is placed"
                } else {
                    $wtiEvidenceWhy = "it is not committed at $wtiEvidenceAt, and it was neither placed nor named as skipped"
                }
                $wtiEvidenceDenial = "the .worktreeinclude placement cannot hand the tree $worktreePath its .claude\settings.json: the mission root has $wtiEvidenceName on disk and .worktreeinclude's patterns match it, so the tree must hold it -- placed by this run and byte-equal to the mission root's, or committed at the tree's HEAD and unmodified -- but $wtiEvidenceWhy. A worker spawned without that hook registration has no evidence plane to rely on, so nothing was spawned ($wtiCopied listed file(s) had been placed).$(if (($wtiEvidenceSkip.Count -gt 0) -and ($wtiEvidenceSkip[0] -match 'junction or symbolic link')) { ' If the mission root''s .claude/ is a junction or symbolic link, give the mission root a real .claude/ with its own settings.json, and dispatch again.' })"
            }
        }
        if ($wtiSrcDenial) {
            $includeDenial = $wtiSrcDenial
        } elseif ($wtiDstDenial) {
            $includeDenial = $wtiDstDenial
        } elseif (($wtiCopied -ne $wtiPlan.Count) -or ($wtiVerified -ne $wtiPlan.Count)) {
            $includeDenial = "the .worktreeinclude placement copied $wtiCopied of $($wtiPlan.Count) planned file(s) into $worktreePath and $wtiVerified of them verify (present, same length)$(if ($wtiCopyErrors.Count -gt 0) { '; ' + ($wtiCopyErrors -join ' | ') }). A short copy can leave the worker without its .claude/ and so without an evidence plane, so nothing was spawned."
        } elseif ($wtiEvidenceDenial) {
            $includeDenial = $wtiEvidenceDenial
        }
    }
    if (-not $includeDenial) {
        Write-Line "mission-dispatch: .worktreeinclude placed $wtiCopied ignored file(s) from $MissionRoot into $worktreePath; $($wtiSkipped.Count) listed entr$(if ($wtiSkipped.Count -eq 1) { 'y' } else { 'ies' }) skipped."
        foreach ($wtiSkip in @($wtiSkipped | Select-Object -First 8)) { Write-Line "  skipped: $wtiSkip" }
        if ($wtiSkipped.Count -gt 8) { Write-Line "  ... and $($wtiSkipped.Count - 8) more skipped." }
    }
}
if ($includeDenial) {
    Close-RunRecordBeforeRefusal
    Deny-Dispatch $includeDenial
}

# =============================================================================================
# R-2 (behaviour) -- spawn the worker and CAPTURE ITS STREAM
# =============================================================================================
# THE WORKER'S WORKING DIRECTORY IS THE TREE, for the real CLI and for a stub alike. PowerShell hands
# its current FileSystem location to a native child as that child's working directory, so entering
# the tree below is the whole of how the CLI is handed its tree -- which is why the entry is ASSERTED
# (found in review). It was a plain `Push-Location`, and a dispatch id 'D-[1]' made it
# fail non-terminating under this block's 'Continue': measured, the worker was spawned in the directory
# that launched the runner -- no isolation, and that directory's hooks -- while LAM_WORKTREE still
# named the tree, so the anchors looked healthy. Enter-WorktreeLocation (above) pushes -LiteralPath and
# reads the location back; a location that is not the tree REFUSES before the spawn, record closed.
$env:LAM_WORKTREE = $worktreePath
$env:LAM_HANDOFF  = $handoffPath
$env:LAM_DISPATCH = $Dispatch
$env:MISSION_DISPATCH_ID = $sessionId

# THE SESSION JOB, JOINED BEFORE THE SPAWN. Only for a validator that declares a result_path, and
# only where the wait is not switched off: a worker dispatch, and a validator given -NoResultWaitSeconds 0, runs in
# no job, as it did. A join that failed is kept by the function and said where the descendants are asked for.
$noResultRel = if ($roleKind -eq 'validator') { ([string]$dispatchDoc['result_path']).Trim() } else { '' }
if ($noResultRel -and ($NoResultWaitSeconds -gt 0)) { $null = Join-LamSessionJob }

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$workerCwdDenial = Enter-WorktreeLocation -Location $workerCwd -Tree $worktreePath
if ($workerCwdDenial) {
    $ErrorActionPreference = $prevEap
    Close-RunRecordBeforeRefusal
    Deny-Dispatch $workerCwdDenial
}
# THE STAMP (operator ruling (i)). Taken HERE, the last thing before the worker starts, so every
# earlier refusal leaves the gate untouched, and decided again under the gate's exclusive handle.
# A refusal now comes after .started, so the run record closes first, in the run record's order. An
# exception escaping the stamp closes it the same way instead of reaching the script trap, which
# would exit 5 and leave the record reading started-not-finished.
if ($null -ne $dgEarly) {
    $dgFault = ''
    try {
        $dgStamp = Invoke-LamDispatchGateStamp -MissionRoot $MissionRoot -GateId $DispatchGate -DispatchId $Dispatch -DispatchPath $dispatchPath -DispatchSha256 $dispatchSha
    } catch { $dgFault = [string]$_.Exception.Message; $dgStamp = $null }
    if ($dgFault -or (-not $dgStamp.ok)) {
        Pop-Location
        $ErrorActionPreference = $prevEap
        Close-RunRecordBeforeRefusal
        if ($dgFault) {
            Write-Line "mission-dispatch: REFUSED -- DISPATCH-GATE-FAULT: the stamp on dispatch gate '$DispatchGate' threw ($dgFault)."
            Write-Line "  No worker was spawned. Whether the gate's bytes moved is not known here: compare them."
        } else {
            Write-Line "mission-dispatch: REFUSED -- DISPATCH-GATE-$($dgStamp.code): $($dgStamp.reason)"
            if ($dgStamp.gate_path) { Write-Line "  gate : $($dgStamp.gate_path)" }
            Write-Line "  Refused at the spawn: the stamp wrote nothing and no worker was spawned."
        }
        exit 2
    }
    $dgStampAct = if ($dgStamp.first) { 'CONSUMED by this spawn' } else { 'this spawn recorded' }
    Write-Line "mission-dispatch: dispatch gate $(Split-Path -Leaf $dgStamp.gate_path) -- $dgStampAct, seq $($dgStamp.spawn_seq) of $($dgStamp.count), consumed_at $($dgStamp.consumed_at)"
}
try {
    if ($WorkerCommand) {
        $workerOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $WorkerCommand @workerArgv 2>&1
    } else {
        # THE DISPATCH GOES OVER STDIN, NOT AS AN ARGUMENT, and this is the single most important
        # line in the file. Passed positionally, PowerShell's native-argument marshalling TRUNCATED
        # the prompt at the first embedded double quote: the first live worker received 155 bytes
        # of a 4 KB dispatch -- three comment lines, cut mid-sentence -- and had no way to know the
        # rest existed. It did the right thing and refused to reconstruct its own targets, but a
        # less careful worker would have guessed, and the guess would have looked like work.
        #
        # Piping also removes the CLI's 3-second "no stdin data received" wait, which the argument
        # form incurred on every spawn.
        $workerOut = $prompt | & claude @workerArgv 2>&1
    }
    $workerExit = $LASTEXITCODE
} catch {
    $workerOut  = @("runner: worker spawn threw -- $($_.Exception.Message)")
    if ($null -ne $dgStamp) { $workerOut += "runner: dispatch gate $DispatchGate was stamped for this spawn (seq $($dgStamp.spawn_seq)) before the worker failed to start" }
    $workerExit = 1
} finally {
    Pop-Location
    $ErrorActionPreference = $prevEap
}

# THE SESSION'S PROCESS HAS EXITED. IS ITS RESULT AT THE SOURCE? Asked HERE, before this runner
# starts anything else, so the session job's live processes are the session's descendants and nothing of the
# runner's. A result standing in the validator's own tree ends the matter: nothing is enumerated, waited for, printed
# or recorded. An absent one has the descendants READ here and WAITED FOR below, once the stream, DISPATCH-END and
# the run record are on disk as they always were at the session's exit. A path that cannot be formed or asked about
# is left to the validator-result check further down, as before.
$noResultWait     = $null
$noResultFirst    = $null
$noResultSource   = ''
$noResultWaitSaid = ''
$noResultVanished = $false
if ($noResultRel) {
    $noResultAbsent = $false
    try {
        $noResultSource = Join-Path $worktreePath $noResultRel
        $noResultAbsent = (-not [System.IO.File]::Exists($noResultSource))
    } catch { $noResultAbsent = $false }
    if ($noResultAbsent) {
        if ($NoResultWaitSeconds -le 0) {
            $noResultFirst = [pscustomobject]@{ ok = $false; list = @(); error = '-NoResultWaitSeconds 0 switches the wait off, so no session job was made and nothing was enumerated' }
        } else {
            $noResultFirst = Get-LamSessionDescendant
        }
    }
}

# RESOLVE THE WORKTREE THE WORKER USED, from git rather than from expectation. The path is the
# runner's own now, so this is a CONFIRMATION by exact normalised equality against
# `git worktree list --porcelain` -- never the old `-like "*wt-<id>*"` prefix match, which also matched
# wt-D-1b for wt-D-1. A tree git does not list is recorded in git_errors rather than assumed.
if ($isRepo) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $wl = & git -C $MissionRoot worktree list --porcelain 2>&1
        if ($LASTEXITCODE -eq 0) {
            $wantKey  = ConvertTo-WorktreePathKey $worktreePath
            $resolved = ''
            foreach ($wlLine in @(@($wl) | Where-Object { $_ -is [string] })) {
                if ($wlLine -match '^worktree (.+)$') {
                    $wlPath = $Matches[1].Trim()
                    if ((ConvertTo-WorktreePathKey $wlPath) -eq $wantKey) { $resolved = ($wlPath -replace '/', '\'); break }
                }
            }
            if ($resolved) {
                if (Test-Path -LiteralPath $resolved) { $worktreePath = $resolved }
            } else {
                $gitErrors += "no worktree named '$worktreeName' at $worktreePath appears in git worktree list --porcelain -- the tree this runner created is not registered with git"
            }
        } else { $gitErrors += "worktree list failed ($LASTEXITCODE, --porcelain): $wl" }
    } finally { $ErrorActionPreference = $prevEap }
}
$worktreeMade = (Test-Path -LiteralPath $worktreePath)

# The stream is written whatever happened. A spawn that failed still produced a record of the
# attempt, and a missing stream would be indistinguishable from a dispatch that never ran.
$streamLines = @(@($workerOut) | ForEach-Object { [string]$_ })
[System.IO.File]::WriteAllLines($streamPath, $streamLines, (New-Object System.Text.UTF8Encoding($false)))

# =============================================================================================
# R-3 -- the boundary, then the handoff, then the anchors
# =============================================================================================
$endedAt = Get-Date
$stampEnd = $endedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
[System.IO.File]::WriteAllText($endPath,
    "dispatch_id: $Dispatch`nsession_id: $sessionId`nended_at: $stampEnd`nworker_exit: $workerExit`n",
    (New-Object System.Text.UTF8Encoding($false)))

# THE RUN RECORD CLOSES HERE, in the runner's OWN end path, and THE ORDER IS LOAD-BEARING:
# .rc first, .ended last, so a reader that has seen .ended can rely on .rc already being on disk.
# The predicate demands both, so neither order could report a torn record as finished -- but this
# order additionally makes .ended's presence sufficient, which is the cheaper thing for a poller.
# $workerExit is assigned on BOTH branches above (the try from $LASTEXITCODE, the catch to 1), so
# the guard below is belt-and-braces: an EMPTY .rc would make the predicate read this FINISHED run
# as still running, which is the very confusion the record exists to remove. 'unknown' is written
# rather than a plausible 0, because inventing an exit code is how a failed run reads as a pass.
$rcText = [string]$workerExit
if ($rcText.Trim() -eq '') { $rcText = 'unknown' }
[System.IO.File]::WriteAllText($rcPath, "$rcText`n", (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($endedPath, "$stampEnd`n", (New-Object System.Text.UTF8Encoding($false)))

# THE WAIT. Taken here -- the stream, DISPATCH-END and the run record already written, at the
# session's exit as before -- and before this runner starts anything that outlives its own call, so the job's live
# processes are still the session's descendants. No longer than the bound; the validator-result check further down
# then reads the result ONCE, and names the refusal if it is still not there.
if ($null -ne $noResultFirst) {
    if ($noResultFirst.ok -and (@($noResultFirst.list).Count -gt 0)) {
        Write-Line "mission-dispatch: no result at $noResultSource as the validator's session exited (worker exit $workerExit), and $(@($noResultFirst.list).Count) descendant process(es) of the session alive -- waiting up to $NoResultWaitSeconds s for them to end"
    }
    $noResultWait = Wait-LamSessionDescendant -First $noResultFirst -BoundSeconds $NoResultWaitSeconds
    $noResultSeenSaid  = (@($noResultWait.seen)  | ForEach-Object { "pid $($_.pid) $($_.name)".Trim() }) -join ', '
    $noResultAliveSaid = (@($noResultWait.alive) | ForEach-Object { "pid $($_.pid) $($_.name)".Trim() }) -join ', '
    $noResultWaitSaid = switch -CaseSensitive ([string]$noResultWait.code) {
        'NO-DESCENDANTS'    { 'no descendant process of the session was alive at its exit, so nothing was waited for' }
        'DESCENDANTS-ENDED' { "$(@($noResultWait.seen).Count) descendant process(es) of the session alive at its exit ($noResultSeenSaid); they ended after $($noResultWait.waited_ms) ms, inside the $($noResultWait.bound_seconds) s bound" }
        'BOUND-ELAPSED'     { "$(@($noResultWait.seen).Count) descendant process(es) of the session alive at its exit ($noResultSeenSaid); the $($noResultWait.bound_seconds) s bound ELAPSED after $($noResultWait.waited_ms) ms with $(@($noResultWait.alive).Count) still alive ($noResultAliveSaid)" }
        default             { "the session's descendant processes could not be enumerated ($($noResultWait.error)), so nothing was waited for$(if (@($noResultWait.seen).Count -gt 0) { " past $($noResultWait.waited_ms) ms; $(@($noResultWait.seen).Count) had been seen ($noResultSeenSaid)" })" }
    }
    Write-Line "mission-dispatch: no result at $noResultSource as the validator's session exited (worker exit $workerExit) -- $noResultWaitSaid (register row 365)"
}


# CONSOLIDATE THE WORKER'S EVIDENCE INTO THE MISSION'S PLANE, BEFORE FINALIZING.
#
# The worker runs in a worktree, so ITS hooks write ITS log and streams under the WORKTREE's
# evidence root. The runner's own root holds only the boundary markers and the runner-stream. Two
# consequences, both real:
#   1. The worktree is EPHEMERAL. It is removed when the dispatch is done, and evidence that lived
#      only there would go with it.
#   2. Every consumer derives the plane from the MISSION root and the dispatch id -- verify does
#      exactly that (spec:122-124) -- so a manifest sitting in the worktree is a manifest at a path
#      nothing looks in. Driven: verify reported MANIFEST and PLANE-PARITY ABSENT for precisely
#      this reason, and PASS-DIB correctly refused to admit them.
#
# The bytes are COPIED, never rewritten: log.jsonl and the stream bodies move verbatim, so the
# manifest the finalizer then computes over them re-derives its own log_sha256. The runner is
# harness-side, not the model; this is the runner placing hook-written evidence where the dispatch's
# plane says it lives, not an agent authoring evidence.
if ($worktreeMade) {
    $wtEv = Join-Path $worktreePath ".mission-runtime\evidence\$sessionId"
    if (Test-Path -LiteralPath $wtEv) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            foreach ($item in @('log.jsonl', 'seq.counter')) {
                $src = Join-Path $wtEv $item
                if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $evRoot $item) -Force }
            }
            $srcStreams = Join-Path $wtEv 'streams'
            if (Test-Path -LiteralPath $srcStreams) {
                $dstStreams = Join-Path $evRoot 'streams'
                if (-not (Test-Path -LiteralPath $dstStreams)) { New-Item -ItemType Directory -Path $dstStreams -Force | Out-Null }
                # -LiteralPath SUPPRESSES wildcard expansion by design, so `Join-Path $srcStreams '*'`
                # asked for a file literally NAMED '*', matched nothing, and -- under the 'Continue'
                # preference this block runs with -- copied ZERO bodies while raising nothing at all.
                # D-1 and D-1b both consolidated empty streams/ directories that way. That, not the
                # finalizer no-op, is the PLANE-PARITY cause a fresh session id was never going to
                # cure. Enumerate instead: no wildcard semantics, safe for any name a hook writes.
                $bodies = @(Get-ChildItem -LiteralPath $srcStreams -Force)
                foreach ($b in $bodies) {
                    Copy-Item -LiteralPath $b.FullName -Destination $dstStreams -Force -Recurse
                }
                # A SILENT zero-copy is what let this survive two dispatches undetected. Count both
                # sides and record any mismatch as a git error, so it reaches the anchors rather
                # than nowhere.
                $copied = @(Get-ChildItem -LiteralPath $dstStreams -Force).Count
                if ($copied -ne $bodies.Count) {
                    $gitErrors += "evidence consolidation: $($bodies.Count) stream bodies at $srcStreams but $copied at $dstStreams"
                }
            }
            $srcErr = Join-Path $wtEv 'hook-errors.log'
            if (Test-Path -LiteralPath $srcErr) { Copy-Item -LiteralPath $srcErr -Destination (Join-Path $evRoot 'hook-errors.log') -Force }
        }
        catch { $gitErrors += "evidence consolidation failed: $($_.Exception.Message)" }
        finally { $ErrorActionPreference = $prevEap }
    }
}

# Finalize the evidence store through the next-gen dispatch-end finalizer, and lift the sidecar
# figures into the anchors (R-3).
$gapsCount = $null
$gapsSha   = $null
$dispatchEnd = Join-Path $RepoRoot 'tools\evidence-hooks-next\hooks\evidence-dispatch-end.ps1'
if (Test-Path -LiteralPath $dispatchEnd) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $env:CLAUDE_PROJECT_DIR = $MissionRoot
        $endPayload = (@{ session_id = $sessionId } | ConvertTo-Json -Compress)
        $endOut = $endPayload | & powershell -NoProfile -ExecutionPolicy Bypass -File $dispatchEnd 2>&1
        foreach ($l in @($endOut)) {
            $s = [string]$l
            if ($s -match 'capture_gaps_count:\s*(\d+)')        { $gapsCount = [int]$Matches[1] }
            if ($s -match 'capture_gaps_sha256:\s*([0-9a-f]+)') { $gapsSha   = $Matches[1] }
        }
    } finally { $ErrorActionPreference = $prevEap }
}
$sidecarPath = Join-Path $evRoot 'capture-gaps.yaml'
if ((-not $gapsSha) -and (Test-Path -LiteralPath $sidecarPath)) {
    $gapsSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $sidecarPath).Hash.ToLowerInvariant()
}
if (($null -eq $gapsCount) -and (Test-Path -LiteralPath $sidecarPath)) {
    $sc = [System.IO.File]::ReadAllText($sidecarPath)
    if ($sc -match 'capture_gaps_count:\s*(\d+)') { $gapsCount = [int]$Matches[1] }
}

# --- handoff validation (expanded-schemas SS5) --------------------------------------------------
# runner_anchors is deliberately NOT required of the model: the schema gives it no such fields, and
# "a handoff in which the model supplied them is invalid rather than merely suspect". The runner
# writes them, below, from evidence.
#
# ONE DEFINITION OF "SCHEMA-VALID", used by the placement below and by the judgement further down.
# A second copy would let the runner place a handoff its own validator then rejects -- two answers
# to one question, which is how a rule stops meaning what its name says.
function Get-HandoffProblems {
    param([string]$Path)
    $requiredFields = @('id','from_worker','dispatch_id','feature_id','spec_version',
                        'completed_assertions','unfinished','commits','commands_run',
                        'issues_observed','procedure_adherence','terminated_reason')
    $enums = @{
        procedure_adherence = @('confirmed','deviated')
        terminated_reason   = @('completed','budget_exhausted','tool_blocked','amendment_filed','crash_recovered')
    }
    $problems = @()
    # THE STRICT-YAML CHECK COMES FIRST because "can any parser read this file" precedes "does it
    # carry the fields". The token is the refusal's name and the message is the PARSER'S OWN, with
    # its line and column -- not a paraphrase, because the operator's next act is to open that line.
    # It joins THIS function, not a second check further down, so that the one definition of a valid
    # handoff stays one definition: the placement above and the judgement below ask the same
    # question and cannot give two answers to it.
    $strict = Test-HandoffStrictYaml -Path $Path
    if ($strict.outcome -eq 'refused') {
        $where = if ($strict.line -gt 0) { "line $($strict.line), column $($strict.column)" } else { 'no line reported' }
        $problems += "DECLARED-HANDOFF-UNPARSEABLE: $($strict.problem) ($where, per $($strict.parser)) -- the runner's flat reader admits this file and a real YAML parser refuses it"
    }
    $h = Read-FlatYaml -Path $Path
    foreach ($f in $requiredFields) {
        if (-not $h.ContainsKey($f)) { $problems += "missing required field: $f" }
    }
    foreach ($f in @($enums.Keys)) {
        if ($h.ContainsKey($f)) {
            $v = [string]$h[$f]
            if ($enums[$f] -notcontains $v) {
                $problems += "field $f has value '$v', outside the closed enum ($($enums[$f] -join '|'))"
            }
        }
    }
    if ($h.ContainsKey('procedure_adherence') -and ([string]$h['procedure_adherence'] -eq 'deviated') -and
        (-not $h.ContainsKey('deviation_notes'))) {
        $problems += "procedure_adherence is 'deviated' without deviation_notes"
    }
    if ($h.ContainsKey('unfinished') -and $h.ContainsKey('terminated_reason')) {
        $unf = @($h['unfinished'])
        if (($unf.Count -gt 0) -and ([string]$h['terminated_reason'] -eq 'completed')) {
            $problems += "non-empty unfinished with terminated_reason 'completed' is invalid"
        }
    }
    if ($h.ContainsKey('runner_anchors')) {
        $problems += "the model supplied runner_anchors, which it may never write"
    }
    return $problems
}

# =============================================================================================
# THE RUNNER PLACES THE WORKTREE'S HANDOFF AT THE SHARED PATH, TIME-PRESERVING
# =============================================================================================
# LAM_HANDOFF names the SHARED path <mission-root>\.mission\dispatches\<id>.handoff.yaml, and the
# CLI's worktree isolation refuses to let a confined worker write it: the worker can only write the
# SAME RELATIVE PATH under its own worktree root. Eighteen dispatch artifacts therefore
# instructed their workers to write the handoff in the WORKTREE and to EXPECT this runner to reject
# the dispatch for the missing shared-path artifact -- rc 3, no wake -- with a human seat renaming
# the runner's stub and copying the worktree file across afterwards, by hand, every time.
# (That confinement was observed with the CLI spawned under --worktree. The worktree
# relocation spawns it in the runner-placed tree instead, and whether a worker there can write the
# shared path has not been re-measured; this placement does not depend on the answer, since it fires
# only when the shared path is absent and the worktree copy is present.)
#
# THE RENAME WAS ALWAYS MECHANICAL, SO IT IS THE RUNNER'S ACT. A contract the worker it spawns
# cannot satisfy is not a contract; it is a ritual with a person at the end of it, and the person
# was the only thing standing between a complete dispatch and an exit-3 fossil.
#
# VERIFY, THEN PLACE -- the order is the whole point. A worktree copy that fails the same schema
# check the shared path would face is NOT placed: it is reported against its own path and the
# dispatch is rejected exactly as before. Placing first and judging afterwards would make the
# shared path a record of "something was written", which is the state this class of defect lives
# in.
#
# THE STRICT-YAML CHECK RIDES ON THAT ORDER RATHER THAN AROUND IT, and the consequence is deliberate: a worktree
# handoff a real YAML parser refuses is NOT PLACED EITHER. Placing it would install, as the mission's
# artifact of record, a file every downstream reader with a real parser is locked out of -- which is
# the exact harm the strict check names, committed by the runner's own hand. Nothing is lost by refusing:
# the worker's bytes stay where the worker wrote them, the rejection names that path AND the
# parser's line, and the artifact of record stays a record a reader can open. The alternative --
# place it and reject afterwards -- would also give two answers to one question, since the placement
# gate and the final judgement would then disagree about what a valid handoff is.
#
# SHARED PATH PRESENT => USED UNCHANGED. Some workers can write it directly; for those this whole
# section is inert and nothing is copied, printed or recorded.
$wtHandoffPath     = $null
# UI-1 S1 (ADR-045): THE CLOSE MOVES THE DERIVED STATE. The snapshot counts a dispatch open while <id>.yaml has no
# <id>.handoff.yaml beside it, and by the end of the run one stands at the shared path -- the worker's, the one placed
# below, or the rejection record -- so the runner offers the snapshot again once the handoff is settled, as it did at
# open: one line when snapshot_sha256 moved, none when it did not. It prints nothing and can fail nothing.
function Send-LamDispatchSnapshot {
    try {
        $tmS = Join-Path $PSScriptRoot 'mission-telemetry.ps1'
        if (-not (Test-Path -LiteralPath $tmS -PathType Leaf)) { return }
        . $tmS
        Invoke-MissionTelemetry -Root $MissionRoot -Snapshot -Verb 'mission-dispatch'
    } catch { }
}

$handoffPlacedFrom = $null
$handoffPlacedSha  = $null
$handoffPlacedTime = $null
$placementProblems = @()
if ($worktreeMade) {
    $wtHandoffPath = Join-Path $worktreePath ".mission\dispatches\$Dispatch.handoff.yaml"
}
if ((-not (Test-Path -LiteralPath $handoffPath)) -and $wtHandoffPath -and (Test-Path -LiteralPath $wtHandoffPath)) {
    $wtProblems = @(Get-HandoffProblems -Path $wtHandoffPath)
    if ($wtProblems.Count -gt 0) {
        # NOT PLACED, AND SAID SO. The rejection now names the path the handoff actually occupies,
        # which is the one an operator has to open.
        Write-Line "mission-dispatch: a handoff was found in the WORKTREE and was NOT placed -- it fails the schema:"
        Write-Line "    at $wtHandoffPath"
        foreach ($p in $wtProblems) { Write-Line "      - $p" }
        foreach ($p in $wtProblems) { $placementProblems += "the worktree handoff at $wtHandoffPath is invalid and was not placed: $p" }
    } else {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $src = Get-Item -LiteralPath $wtHandoffPath
            Copy-Item -LiteralPath $wtHandoffPath -Destination $handoffPath -Force
            # TIME-PRESERVING, EXPLICITLY rather than by trusting the copy's side effects: the
            # placed file carries the worktree copy's own times, so "when did the worker finish"
            # remains readable off the artifact of record (the seat's place-*-handoff.py helpers
            # used shutil.copy2 for precisely this, and this mechanises them).
            $dst = Get-Item -LiteralPath $handoffPath
            $dst.CreationTimeUtc   = $src.CreationTimeUtc
            $dst.LastWriteTimeUtc  = $src.LastWriteTimeUtc
            $dst.LastAccessTimeUtc = $src.LastAccessTimeUtc
            $srcSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $wtHandoffPath).Hash.ToLowerInvariant()
            $dstSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $handoffPath).Hash.ToLowerInvariant()
            $timeKept = ((Get-Item -LiteralPath $handoffPath).LastWriteTimeUtc -eq $src.LastWriteTimeUtc)
            if (($srcSha -ne $dstSha) -or (-not $timeKept)) {
                # FAIL CLOSED. A placement that is not byte-for-byte the worker's file, at the
                # worker's time, is not a placement -- remove it rather than leave a near-copy
                # standing as the artifact of record.
                Remove-Item -LiteralPath $handoffPath -Force -ErrorAction SilentlyContinue
                $placementProblems += "placing the worktree handoff from $wtHandoffPath did not reproduce it exactly (sha256 $srcSha -> $dstSha; mtime kept: $timeKept); nothing was placed"
                Write-Line "mission-dispatch: PLACEMENT REFUSED -- the copy of $wtHandoffPath was not exact; nothing placed."
            } else {
                $handoffPlacedFrom = $wtHandoffPath
                $handoffPlacedSha  = $dstSha
                $handoffPlacedTime = $src.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
                Write-Line "mission-dispatch: the handoff was written IN THE WORKTREE, not at the shared path -- the runner PLACED it (row 116)."
                Write-Line "    from       : $wtHandoffPath"
                Write-Line "    to         : $handoffPath"
                Write-Line "    sha256     : $handoffPlacedSha   (byte-equal to the worktree copy)"
                Write-Line "    mtime kept : $handoffPlacedTime   (time-preserving)"
            }
        } catch {
            $placementProblems += "placing the worktree handoff from $wtHandoffPath failed: $($_.Exception.Message)"
            Write-Line "mission-dispatch: PLACEMENT FAILED -- $($_.Exception.Message)"
        } finally { $ErrorActionPreference = $prevEap }
    }
}
# the worker's handoff (written at the shared path, or placed just above) is settled: offer the snapshot
Send-LamDispatchSnapshot

$handoffProblems = @()
if (-not (Test-Path -LiteralPath $handoffPath)) {
    if ($placementProblems.Count -gt 0) {
        $handoffProblems += $placementProblems
    } else {
        $absent = "no handoff artifact at $handoffPath"
        if ($wtHandoffPath) { $absent += " (nor at the worktree path $wtHandoffPath)" }
        $handoffProblems += $absent
    }
} else {
    $handoffProblems += @(Get-HandoffProblems -Path $handoffPath)
}

# --- the strict-YAML verdict is announced under its own name -------------------
# Printed ONCE, from the verdict the validator actually reached, so the operator gets the parser's
# line whichever path was judged -- the shared artifact, or the worktree copy that was not placed
# because of it. The refusal itself travels in $handoffProblems above; this block is the reading.
if ($null -ne $script:StrictYamlLast) {
    if ($script:StrictYamlLast.outcome -eq 'refused') {
        Write-Line "mission-dispatch: DECLARED-HANDOFF-UNPARSEABLE -- a real YAML parser refuses this handoff."
        Write-Line "    at     : $($script:StrictYamlLast.path)"
        Write-Line "    parser : $($script:StrictYamlLast.parser)"
        if ($script:StrictYamlLast.line -gt 0) {
            Write-Line "    line $($script:StrictYamlLast.line), column $($script:StrictYamlLast.column): $($script:StrictYamlLast.problem)"
        } else {
            Write-Line "    $($script:StrictYamlLast.problem)"
        }
        Write-Line "  The runner's flat reader takes everything after the FIRST colon as the value, so a plain scalar carrying ': ' passes the schema check and still refuses to parse. An artifact of record no YAML reader can open is not a handoff: single-quote the scalar, or take the colon off the line."
    } elseif ($script:StrictYamlLast.outcome -eq 'unavailable') {
        Write-Line "mission-dispatch: HANDOFF-STRICT-PARSE-UNAVAILABLE -- the handoff was NOT shown to a YAML parser; the schema check alone admitted it."
        Write-Line "    reason : $($script:StrictYamlLast.detail)"
        Write-Line "  This does NOT refuse the dispatch -- a runner that hard-failed wherever no python is installed would be worse than the defect it closes -- and it is never silent: the anchors record handoff_strict_yaml: unavailable, so a later reader can tell a handoff a parser ACCEPTED from one no parser ever saw."
    }
}

# --- anchors (v2.3 SS4.2) ----------------------------------------------------------------------
$wtSha    = $null
$diffstat = $null
# TOOLCHAIN NOTE (ii): THE DIFFSTAT IS MEASURED AGAINST THE POINT THE RUN
# STARTED FROM, NOT AGAINST THE TREE THE RUN PRODUCED.
#
# WHAT IT USED TO DO: `git diff --shortstat HEAD` INSIDE THE WORKTREE -- the diff between the
# worktree's working tree and the worktree's OWN tip, which is the worker's UNCOMMITTED
# leftovers and nothing else. A worker that does what every dispatch artifact orders it to do --
# commit its work and leave the tree clean -- therefore measured as NOTHING. All 36 anchors files
# this mission has written carry an empty diffstat, several of them for runs whose own handoff
# reports twelve files and fifteen hundred insertions.
#
# THE CUT POINT IS NOT THE CAUSE. One report reads the same empty field as a consequence of
# a worktree cut behind main. Reproduced hermetically in a throwaway repo cut EXACTLY at its base:
# one commit of 2 files / 3 insertions, `diff --shortstat HEAD` prints nothing while
# `diff --shortstat <base>` prints ' 2 files changed, 3 insertions(+)'. The stale cut is real and
# it is a separate defect; it is not what empties this field, and a fix aimed only at it would have left
# the field empty on every well-behaved run.
#
# THE BASIS IS THE DECLARED BASE'S, NOT A SECOND ONE. $declaredBaseResolved is the sha this runner PLACED
# the worktree at before the spawn and $worktreeBaseHonoured is its own assertion that it got
# there. Re-deriving a base here -- from origin/main, from a merge-base, from the reflog -- would
# be a second answer to a question this file already answers, and the two would drift.
#
# BASE -> WORKING TREE, NOT base..tip. `git diff --shortstat <base>` with no second revision
# compares the base commit against the WORKING TREE, so committed and uncommitted work are
# counted together. That is the honest reading of "what this run did to this tree": the run that
# committed everything and the run that left it staged both measure, and the case that produced
# this note -- committed work reading as nothing -- cannot come back in either shape.
#
# WHY THE OUTPUT IS FILTERED. `2>&1` merges git's stderr into the value, and a repository with
# core.safecrlf at its default emits one 'warning: ... LF will be replaced by CRLF' line PER PATH
# on exactly the diffs this measures. Glued onto the front of the stat, that warning becomes the
# diffstat of record. Warnings carry a fixed prefix and the stat carries a fixed grammar, so both
# are used: a clean tree still measures as '', a noisy one still measures as its stat.
$diffstatBasis   = ''
$diffstatAgainst = ''
if ($worktreeMade) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # "$x" NOT [string]$x. A native command that printed nothing returns an EMPTY ARRAY, and
        # [string]@() evaluates to $null -- so ([string]$d).Trim() throws on the perfectly ordinary
        # case of a clean worktree, where `git diff --shortstat` correctly says nothing. String
        # interpolation yields '' for null and for an empty array, and never yields null.
        $s = & git -C $worktreePath rev-parse HEAD 2>&1
        if ($LASTEXITCODE -eq 0) { $wtSha = ("$s").Trim() }
        else { $gitErrors += "rev-parse failed ($LASTEXITCODE): $s" }
        # A DECLARED BASE THAT WAS NOT HONOURED CANNOT REACH HERE: the block above denies the
        # dispatch and exits before the spawn, and so does a mission root that is no repository
        # (the worktree relocation). So the else below is the UNDECLARED case, and it says so
        # rather than measuring something else and letting the field be read as the run. The cut
        # point IS recorded for that case (worktree_base_observed, taken before the spawn), but it
        # was never ASSERTED, so this field is deliberately not measured against it.
        if ($worktreeBaseHonoured -and $declaredBaseResolved) {
            $diffstatAgainst = $declaredBaseResolved
            $diffstatBasis   = "the declared $declaredBaseField $declaredBaseResolved, committed and uncommitted work counted together. Empty here means this run changed nothing against that base."
        } else {
            $diffstatAgainst = 'HEAD'
            $diffstatBasis   = "the worktree's own tip -- UNCOMMITTED WORK ONLY, and committed work is invisible to it. This dispatch declares no $declaredBaseField this runner could honour, so the point the run started from is recorded (worktree_base_observed) but was never asserted. Declare $declaredBaseField to have this field measure the run."
        }
        $d = & git -C $worktreePath diff --shortstat $diffstatAgainst 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dLines = @(@($d) | ForEach-Object { "$_" } | Where-Object { ($_ -notmatch '^\s*warning:') -and ($_.Trim()) })
            if ($dLines.Count -gt 0) { $diffstat = ($dLines[0]).Trim() } else { $diffstat = '' }
        }
        else { $gitErrors += "diff --shortstat $diffstatAgainst failed ($LASTEXITCODE): $d" }
    } finally { $ErrorActionPreference = $prevEap }
}
# THE DECLARED BASE, THE CORROBORATING HALF: does the tree the worker ACTUALLY used still descend from the
# declared base? The pre-spawn rung is the guard -- it refuses before anything has happened -- and
# this is taken from the tree `git worktree list` says the worker used, rather than from the one
# the runner prepared. It is RECORDED and does not refuse: by the time it can be taken the work is
# already done, and a refusal here would discard evidence rather than prevent harm.
$worktreeBaseKept = $null
if ($worktreeBaseHonoured -and $wtSha -and $declaredBaseResolved) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $null = & git -C $worktreePath merge-base --is-ancestor $declaredBaseResolved $wtSha 2>&1
        $worktreeBaseKept = ($LASTEXITCODE -eq 0)
    } finally { $ErrorActionPreference = $prevEap }
    if ($worktreeBaseKept -eq $false) {
        $gitErrors += "the declared base $declaredBaseResolved is NOT an ancestor of the worktree tip $wtSha -- the tree the worker used is not the tree this runner prepared"
    }
}
$wall = [int](New-TimeSpan -Start $startedAt -End $endedAt).TotalSeconds

# THE MISSION ROOT'S OWN HEAD. `runner_anchors.head_sha` is the field `mission verify`'s ANCHOR arm
# re-derives with `git rev-parse HEAD` AT THE MISSION ROOT, so it must be taken from there.
#
# IT USED TO BE TAKEN FROM THE WORKTREE, and the porcelain line written immediately after it was
# already taken from the mission root -- one anchor block describing TWO REPOSITORIES. The worktree
# tip has its own field (`worktree_tip_sha`, below), which is the one R-3 names; head_sha was
# duplicating it under a name that means something else.
#
# IT SURVIVED FOUR DISPATCHES BECAUSE IT NEEDS TWO THINGS AT ONCE: a worker that COMMITS in its
# worktree, AND a branch nobody merges. D-1's worker committed and was fast-forwarded into main, so
# the value was an ancestor by luck. D-1b and D-1c committed nothing, so the worktree tip WAS the
# mission HEAD and the fields were identical by coincidence. D-2 was the first to do both -- and
# nothing verified against D-2's anchors until the next dispatch tried, which is when the advance
# admission asked whether the mission's HEAD descends from a commit that exists only on a worktree
# branch, and correctly said no. R-13 covers it.
$missionHeadSha = ''
if ($isRepo) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $mh = & git -C $MissionRoot rev-parse HEAD 2>&1
        if ($LASTEXITCODE -eq 0) { $missionHeadSha = ("$mh").Trim() }
        else { $gitErrors += "mission-root rev-parse failed ($LASTEXITCODE): $mh" }
    } finally { $ErrorActionPreference = $prevEap }
}

# THE ORIGIN-TIP READING, TAKEN HERE. Beside the mission root's own HEAD, because origin_tip is a fact
# about THE SAME REPOSITORY this block describes and because mission-verify.ps1 re-derives it with
# `git ls-remote` run at that root. Taken AFTER the worker has finished and BEFORE the anchors are
# signed, so the reading names the state the artifact is about.
#
# NOT A git_errors ENTRY, ON ANY OUTCOME. git_errors means "this runner tried to do something and it
# failed"; an origin that is unreachable, unconfigured, or simply has no such branch yet is a fact
# about the world, and filing it there would print "completed with git errors" on every offline run
# and teach an operator to ignore the line. The reason rides its own anchors field and its own
# stdout line below.
$originTip = Get-LamOriginTip -MissionRoot $MissionRoot
$originTipSaid = 'null'
if ($originTip.sha) { $originTipSaid = [string]$originTip.sha }
$originTipRefSaid = '(no ref)'
if ($originTip.ref) { $originTipRefSaid = [string]$originTip.ref }
# SAID OUT LOUD ON EVERY OUTCOME, like the strict-YAML verdict at the end of this script, so a
# reader of the stream never has to infer from silence whether origin was asked.
Write-Line "mission-dispatch: origin tip -- $originTipSaid for $originTipRefSaid"
Write-Line "    reason : $($originTip.reason)"

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# runner anchors -- written by the runner from evidence, never by the model.")
[void]$sb.AppendLine("# design v2.3 SS4.2 / expanded-schemas SS5 RunnerAnchors, plus LAM-ACCEPT amendment 2.")
[void]$sb.AppendLine("#")
[void]$sb.AppendLine("# The runner_anchors BLOCK below is the shape expanded-schemas SS5 declares and the shape")
[void]$sb.AppendLine("# `mission verify --against` consumes. The flat LAM fields that follow it are this build's")
[void]$sb.AppendLine("# additions (LAM-ACCEPT R-3 as amended) and are deliberately kept OUTSIDE the block: the")
[void]$sb.AppendLine("# block's field set is declared elsewhere and is not this build's to extend AT WILL.")
[void]$sb.AppendLine("#")
[void]$sb.AppendLine("# ONE EXCEPTION, NAMED RATHER THAN SLID IN: origin_tip was added to the block because the")
[void]$sb.AppendLine("# defect was that the field did not exist -- mission verify reads")
[void]$sb.AppendLine("# runner_anchors.origin_tip by name and its ORIGIN-ATTESTATION arm cannot engage without it.")
[void]$sb.AppendLine("# expanded-schemas SS5 RunnerAnchors now declares origin_tip (optional; a string or a bare null),")
[void]$sb.AppendLine("# so it is no longer declared by its consumer alone. origin_tip_ref / origin_tip_exit_code /")
[void]$sb.AppendLine("# origin_tip_note are NOT members of that shape and stay OUTSIDE, under the rule above.")
[void]$sb.AppendLine("runner_anchors:")
[void]$sb.AppendLine("  head_sha: $(if ($missionHeadSha) { $missionHeadSha } else { 'null' })")
# THE ONE GIT CALL WHOSE FAILURE WAS DISCARDED, AND IT FAILED TOWARD A CLEAN ANCHOR (V-1 round 8,
# WP-2). The old form consulted $LASTEXITCODE and left the failure branch EMPTY, so a failing
# `git status` produced an empty list and the block below wrote `porcelain: []`. Driven with a PATH
# shim failing only on --porcelain: a DIRTY tree was anchored clean, nothing in git_errors, exit 0.
#
# `head_sha` two lines up already writes `null` when it cannot be derived. An unreadable tree now
# says the same thing, because "empty" and "unknown" are different claims and only one of them is
# true here. The failure is also recorded in git_errors, exactly as the rev-parse failure above is.
$porc = @()
$porcDerived = $true
if ($isRepo) {
    $porcState = Get-LamPorcelainState -MissionRoot $MissionRoot
    if ($porcState.ok) { $porc = @($porcState.lines) }
    else {
        $porcDerived = $false
        $gitErrors += "mission-root porcelain failed ($($porcState.code)): $($porcState.reason)"
    }
}
if (-not $porcDerived) {
    # THE COMMENT GOES ON ITS OWN LINE (V-1 round 9). mission-verify.ps1 skips WHOLE-LINE comments
    # and does not strip a trailing `#`, so `porcelain: null   # ...` parsed as the STRING
    # "null   # ..." and reported DIVERGED, where head_sha's bare null reports ABSENT. Two
    # underivable anchors, one intent, two verdicts -- and the commented form was mine.
    [void]$sb.AppendLine("  # porcelain UNDERIVABLE -- git status failed; see git_errors. NOT an assertion of cleanliness.")
    [void]$sb.AppendLine("  porcelain: null")
} elseif ($porc.Count -eq 0) {
    [void]$sb.AppendLine("  porcelain: []")
} else {
    [void]$sb.AppendLine("  porcelain:")
    foreach ($l in $porc) { [void]$sb.AppendLine("    - $(ConvertTo-YamlSingleQuoted ([string]$l))") }
}
# WHERE THE DISPATCH'S MANIFEST ACTUALLY IS. The worker runs in the worktree, so ITS hooks write
# ITS evidence there and the Stop finalizer copies the committed plane into the worktree's
# .mission/evidence/. The runner's own evidence root holds the runner-stream and the boundary
# markers, but no hook-captured log -- so the mission root has no manifest to anchor. Anchoring the
# path where a manifest is SUPPOSED to be, and recording null because nothing is there, would be an
# anchor that points at an absence. The worker's manifest IS this dispatch's evidence manifest.
# The anchor names the path the PLANE derives -- the mission's own runtime evidence root -- because
# that is where every consumer looks. The worktree fallback below survives only for the case where
# consolidation could not run; it is a disclosed degradation, not the normal path.
$manRel = ".mission-runtime/evidence/$sessionId/manifest.json"
$manAbs = Join-Path $evRoot 'manifest.json'
if ((-not (Test-Path -LiteralPath $manAbs)) -and $worktreeMade) {
    $wtMan = Join-Path $worktreePath ".mission\evidence\$sessionId\manifest.json"
    if (Test-Path -LiteralPath $wtMan) {
        $manAbs = $wtMan
        # A REAL PATH, not a <placeholder>. Angle brackets are illegal path characters, and verify
        # calls IsPathRooted on this field -- a placeholder here made verify itself throw and exit
        # 2 ("did not complete"), which is strictly worse than a refusal: a refusal is a verdict,
        # a crash is no verdict at all.
        $manRel = ($wtMan -replace '\\', '/')
    }
}
[void]$sb.AppendLine("  evidence_manifest: $manRel")
[void]$sb.AppendLine("  evidence_manifest_sha256: $(if (Test-Path -LiteralPath $manAbs) { (Get-FileHash -Algorithm SHA256 -LiteralPath $manAbs).Hash.ToLowerInvariant() } else { 'null' })")
[void]$sb.AppendLine("  testimony_conflict: false")
# THE SEVENTH MEMBER OF THIS BLOCK, AND THE ONE FIELD THIS BUILD *IS* AUTHORISED TO ADD.
# The header at the top of this writer says the runner_anchors block "is not this build's to
# extend". That stood until the ABSENCE OF THIS EXACT FIELD was registered as the defect:
# mission-verify.ps1:1321-1322 reads runner_anchors.origin_tip BY NAME, finds it in no artifact, and
# its ORIGIN-ATTESTATION arm reports "a finding for ruling" (:1401) instead of engaging. The field is
# added here for that defect and the header has been rewritten to say so, so the comment and the code
# do not contradict each other.
#
# THE SCHEMA HALF, NOW DISCHARGED. docs/framework/expanded-schemas.md SS5
# RunnerAnchors declares origin_tip as an optional member, typed string or null, written by the
# runner from evidence. Before that entry this field was DECLARED BY ITS CONSUMER and WRITTEN BY THIS
# RUNNER alone, and the half was reported DEFERRED. The declaration says what this writer does: null
# is the absence of an origin claim, and its reason stays OUTSIDE the block as origin_tip_ref /
# origin_tip_exit_code / origin_tip_note, which that shape does not declare.
#
# THE COMMENT GOES ON ITS OWN LINE in the null case, for the reason V-1 round 9 found on porcelain:
# mission-verify.ps1 skips WHOLE-LINE comments and does not strip a trailing one, so
# `origin_tip: null   # ...` parses as the STRING "null   # ..." -- which is a claim about origin,
# where a bare null is the absence of one.
if ($originTip.sha) {
    [void]$sb.AppendLine("  origin_tip: $($originTip.sha)")
} else {
    [void]$sb.AppendLine("  # origin_tip UNDERIVABLE -- see origin_tip_note below. NOT an assertion that origin lacks the ref.")
    [void]$sb.AppendLine("  origin_tip: null")
}

# THE SUITE ANCHOR, AND A DEVIATION FROM R-3 THAT IS STATED RATHER THAN SLID PAST.
#
# LAM-ACCEPT R-3 says the runner takes "suite exit codes from the evidence log". ON THIS HARNESS IT
# CANNOT. Erratum E5-i records that exit_code never appears in any captured payload, and this build
# re-measured it on the smoke mission's own live log: EVERY entry reads "exit_code":null. A suite
# block derived from that log would be a block of nulls wearing an anchor's name.
#
# So the runner OBSERVES the suite itself, in the worktree, and records what it actually saw. That
# is a weaker provenance than hook capture -- the runner is reporting on a command it ran rather
# than reading a record something else wrote -- and the block says so on its face. It is not a
# stronger claim dressed up; it is the strongest claim this harness supports.
$suiteTallyWritten = $false
# THE ONE SHARED DEFINITION OF "RUN AN INSTRUMENT AND KEEP WHAT IT SAID", IN TWO HALVES.
# The goal evaluator's instrument_exit0 detector runs the SAME
# instrument and, before its own cure, kept only the exit code; both halves call this file so the
# persisted transcript and the tally an artifact carries cannot be two readings of one run.
. (Join-Path $PSScriptRoot 'lam-instrument-run.ps1')
# $null MEANS THE SUITE DID NOT RUN, and that is not the same as "it ran and nothing failed"
# The delivery check below turns on exactly that difference: a run that never
# happened cannot show a declared repair delivered, and collapsing the two into an empty array
# would report every undelivered repair as delivered whenever the worktree failed.
$suiteFailedIds = $null
if ($suiteCmd -and $worktreeMade) {
    # THE SUITE'S OUTPUT IS PERSISTED, NOT DISCARDED. What stood here ran the
    # instrument, mined ONE regex out of its output and dropped the rest on the floor -- so a
    # 1912-test run that took eight minutes left `passed: 1` on the anchors and nothing else
    # anywhere, and every one of the thirty-four *.anchors.yaml files on this mission carries that
    # same 1/0/0-or-0/1/0 shape. The helper keeps the exit-code contract exactly (it sets
    # $LASTEXITCODE and returns it as exit_code) and adds the transcript beside it.
    $suiteRun = $null
    # THE SUITE RUNS IN THE TREE OR NOT AT ALL. It is entered the way
    # the worker's spawn enters it: a plain `Push-Location` here, under this point's 'Stop', threw a
    # bracketed tree name to the top-level trap (exit 5). The worker has already run and its own end
    # path has already closed the run record, so a location that is not the tree is not an exit-2
    # refusal here: it takes the degradation that names a suite that could not be invoked -- exit_code
    # 1 -- and no tally is ever read from a suite run in some other directory.
    $suiteCwdDenial = Enter-WorktreeLocation -Location $worktreePath -Tree $worktreePath
    if ($suiteCwdDenial) {
        $suiteOut = @("suite not invoked: $suiteCwdDenial"); $suiteExit = 1
    } else {
        try {
            $suiteRun  = Save-LamInstrumentRun -InstrumentPath $suiteCmd -MissionRoot $MissionRoot -RunKey $Dispatch
            $suiteExit = $suiteRun.exit_code
            $suiteOut  = $suiteRun.stdout
        } catch {
            # Save-LamInstrumentRun does not throw by contract; this stays because the degradation it
            # names -- a suite that could not be invoked at all -- must keep the shape it had before.
            $suiteRun  = $null
            $suiteOut = @("suite invocation threw: $($_.Exception.Message)"); $suiteExit = 1
        } finally { Pop-Location }
    }

    # expected_failures_matched IS A MEASUREMENT, NOT A SPELLING.
    # The reader this replaces recorded true only when the mirror carried the literal line
    # `expected_failures: []` AND the suite exited 0 -- a rule written for the smoke mission's
    # zero-expected-failure suite. Over a mirror that DECLARES ids it recorded false while
    # mission-verify.ps1:1215-1220 derived true by counting non-comment lines in the same file, so the
    # ANCHOR member read DIVERGED and R-1 refused every build-class dispatch. Neither side measured the
    # run. The cure does: the DECLARED set comes from the mirror's `expected_failures:` key, the FAILED
    # set from the suite's own `FAILED <node-id>` lines, and the member is true iff every id that failed
    # was declared. It is INDEPENDENT of $suiteExit -- exit_code carries that on its own, and a suite
    # that exits non-zero BECAUSE its expected failures failed is exactly the case this must call true.
    $efPath = Join-Path $MissionRoot 'tools\mission-cli\config\expected-failures.yaml'
    $efDeclared = Read-DeclaredExpectedFailures -Path $efPath
    # $suiteOut is whatever `& powershell ... 2>&1` produced: strings, ErrorRecords, or a single string
    # carrying embedded newlines. Flatten to lines before matching, or a FAILED line that arrived inside
    # a multi-line chunk is never seen and an unexpected failure reads as no failure at all.
    # ONE EXTRACTION, NOT TWO. The helper mines the FAILED ids with THIS SAME
    # pattern, out of the same flattened text it persisted, so the transcript on disk and the
    # note on the anchors are two views of one reading rather than two readings. The loop below
    # is reached only on the invocation-threw path, where there is no helper result to take.
    $efFailed = New-Object System.Collections.Generic.List[string]
    if ($null -ne $suiteRun) {
        foreach ($efId in @($suiteRun.failed_ids)) { [void]$efFailed.Add([string]$efId) }
    } else {
        foreach ($efItem in @($suiteOut)) {
            foreach ($efLine in (([string]$efItem) -split '\r?\n')) {
                if ($efLine -match '^FAILED\s+(\S+)') { [void]$efFailed.Add($Matches[1]) }
            }
        }
    }
    # The SAME observed set both the tally member and the delivery check read. Deriving the ids a
    # second time from the same output is how two readers of one run come to disagree.
    $suiteFailedIds = @($efFailed.ToArray())
    if ($null -eq $efDeclared) {
        # An ABSENT mirror declares nothing, and "nothing was declared" is not "the run matched".
        $efOk = $false
        $efNote = 'absent'
    } else {
        # -cnotcontains, not -notcontains: a pytest node id is a case-sensitive identifier, and
        # PowerShell's default comparison is case-INSENSITIVE. A case-only difference is a real
        # difference; refusing on it is the direction that refuses.
        $efUnexpected = @($efFailed | Where-Object { $efDeclared -cnotcontains $_ })
        $efOk = ($efUnexpected.Count -eq 0)
        $efNote = "declared $($efDeclared.Count); failed $($efFailed.Count); unexpected $($efUnexpected.Count)"
        if ($efUnexpected.Count -gt 0) { $efNote += ": $($efUnexpected -join ' ')" }
    }
    # A single-quoted YAML scalar on ONE line: double every embedded single quote, and never let a
    # newline out of this value -- the anchors file is read line by line by name.
    $efNoteYaml = ($efNote -replace '[\r\n]+', ' ') -replace "'", "''"
    # THE THREE FIGURES COME FROM THE INSTRUMENT'S OWN TALLY. What stood here
    # wrote `passed: $(if ($suiteExit -eq 0) { 1 } else { 0 })` with `failed:` its inverse and
    # `skipped: 0` hard-coded -- so `passed: 1` meant "the instrument exited 0" and nothing finer,
    # and a run that reported passed=1901 failed=0 skipped=11 banked the same three digits as a
    # run of one trivial assertion. The instrument prints the measurement;
    # it was emitted and ignored.
    #
    # THE FALLBACK IS THE OLD BEHAVIOUR AND IT IS NAMED ON THE ARTIFACT. An instrument that emits
    # no TALLY line must not crash the runner and must not have a tally invented for it, so the
    # exit-code synthesis stays -- but `tally_source` says which of the two produced the numbers,
    # and a reader can tell "1 test passed" from "the thing exited 0" without leaving the file.
    $stTally = [pscustomobject]@{
        source        = 'exit-code-fallback'
        passed        = $(if ($suiteExit -eq 0) { 1 } else { 0 })
        failed        = $(if ($suiteExit -eq 0) { 0 } else { 1 })
        skipped       = 0
        line          = "no TALLY line at column 0 in the instrument's output; passed/failed/skipped synthesized from exit_code $suiteExit"
        extra         = [ordered]@{}
        stdout_path   = '(not persisted)'
        stdout_sha256 = '(not persisted)'
        stdout_bytes  = 0
    }
    if ($null -ne $suiteRun) {
        if ($suiteRun.persisted) {
            $stTally.stdout_path   = ([string]$suiteRun.stdout_path -replace '\\', '/')
            $stTally.stdout_sha256 = [string]$suiteRun.stdout_sha256
            $stTally.stdout_bytes  = [int]$suiteRun.stdout_bytes
        } else {
            $stTally.stdout_path = "(not persisted) $([string]$suiteRun.persist_note)"
        }
        if ($suiteRun.tally_found) {
            # ALL THREE OR NONE. A TALLY that carries two of the three, or a non-integer where a
            # count belongs, is a tally this runner cannot read -- and half a measurement mixed
            # with half a synthesis is the shape nobody could later take apart.
            $stP = [string]$suiteRun.fields['passed']
            $stF = [string]$suiteRun.fields['failed']
            $stS = [string]$suiteRun.fields['skipped']
            if (($stP -match '^\d+$') -and ($stF -match '^\d+$') -and ($stS -match '^\d+$')) {
                $stTally.source  = 'instrument-tally'
                $stTally.passed  = [int]$stP
                $stTally.failed  = [int]$stF
                $stTally.skipped = [int]$stS
                $stTally.line    = [string]$suiteRun.tally_line
            } else {
                $stTally.source = 'exit-code-fallback-unreadable-tally'
                $stTally.line   = "a TALLY line was present but did not carry all three integer counts: $([string]$suiteRun.tally_line)"
            }
            # WHATEVER ELSE THE TALLY CARRIES survives too, prefixed so it can never collide with a
            # contract member of this block -- deselected, runnable, stored_floor, collection_error,
            # pytest_exit, elapsed_seconds today, and whatever the instrument adds next.
            foreach ($stKey in @($suiteRun.fields.Keys)) {
                if (@('passed', 'failed', 'skipped') -contains $stKey) { continue }
                $stTally.extra[$stKey] = [string]$suiteRun.fields[$stKey]
            }
        }
    }
    [void]$sb.AppendLine("  suite:")
    # SINGLE quotes and forward slashes. In a double-quoted YAML scalar a Windows path's \t is a
    # TAB escape -- "tests\test-smoke.ps1" parses as "tests<TAB>est-smoke.ps1", which is a wrong
    # value that still looks right to a human reading the file.
    [void]$sb.AppendLine("    command: '$($suiteCmd -replace '\\', '/')'")
    [void]$sb.AppendLine("    passed: $($stTally.passed)")
    [void]$sb.AppendLine("    failed: $($stTally.failed)")
    [void]$sb.AppendLine("    skipped: $($stTally.skipped)")
    # EVERY MEMBER OF THIS BLOCK IS A FLAT FOUR-SPACE SCALAR, AND THAT IS LOAD-BEARING, NOT STYLE.
    # Read-BasisUnexpectedFailures (:360-384) walks this block to expected_failures_note
    # and stops scanning at the first line that is NOT `^\s{4}\S` -- so a nested map under any member
    # here would end its scan early, the basis's observed failure set would read EMPTY, and a declared
    # repair would be admitted against nothing. Read-R27SuiteMember and mission-verify's
    # Get-AnchorMember read the block the same way.
    [void]$sb.AppendLine("    tally_source: $($stTally.source)")
    [void]$sb.AppendLine("    tally_line: $(ConvertTo-YamlSingleQuoted ([string]$stTally.line))")
    foreach ($stKey in @($stTally.extra.Keys)) {
        [void]$sb.AppendLine("    tally_${stKey}: $(ConvertTo-YamlSingleQuoted ([string]$stTally.extra[$stKey]))")
    }
    [void]$sb.AppendLine("    tally_stdout_path: $(ConvertTo-YamlSingleQuoted ([string]$stTally.stdout_path))")
    [void]$sb.AppendLine("    tally_stdout_sha256: $(ConvertTo-YamlSingleQuoted ([string]$stTally.stdout_sha256))")
    [void]$sb.AppendLine("    tally_stdout_bytes: $($stTally.stdout_bytes)")
    [void]$sb.AppendLine("    expected_failures_matched: $(if ($efOk) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("    expected_failures_note: '$efNoteYaml'")
    [void]$sb.AppendLine("    exit_code: $suiteExit")
    [void]$sb.AppendLine("    provenance: runner-observed")
    [void]$sb.AppendLine("    provenance_note: `"R-3 says 'from the evidence log'. E5-i makes that impossible here -- every captured exit_code is null, re-measured on this mission's own log -- so the runner ran the suite and recorded what it saw.`"")
    $suiteTallyWritten = $true
}
# THE KIND IS RECORDED AS THE CLASS VERIFY SCOPES BY, WITH THE DECLARED TOKEN BESIDE IT.
# Previously this line wrote the dispatch artifact's own kind token verbatim. mission-verify
# reads only the top-level dispatch_kind when --dispatch-kind is not supplied, and its scoping table
# admits no mainline, so a flagless mission verify --against of an anchors file from a mainline
# dispatch refused at ANCHOR/dispatch_kind before any arm ran. The runner already translated the kind
# in the argv it passes verify; the artifact it wrote was not translated. Now:
#   dispatch_kind       -- THIS dispatch's own declared kind (mainline where none is declared), through
#                          ConvertTo-VerifyClass, so an unknown word still reaches verify unchanged.
#   dispatch_kind_token -- the declared token itself (or mainline), so mainline and fanout stay
#                          distinguishable on the artifact's face. Column 0, outside runner_anchors and
#                          outside suite; the gate's '^dispatch_kind:' reader does not match it.
# THE TOKEN IS A SINGLE-QUOTED SCALAR (ConvertTo-YamlSingleQuoted), because it is the artifact's own
# string: Read-FlatYaml trims its quotes and checks no enum, so a declared kind of 'x: y' written bare
# is a line no YAML parser accepts, and null or yes would change type. Its readers are unaffected:
#   * the gate's prior reader, '(?m)^dispatch_kind:[ \t]*(\S+)', needs a colon straight after
#     dispatch_kind and so never lands on this key, quoted or bare;
#   * mission-verify's restricted reader splits a line at its first colon and un-doubles a
#     single-quoted scalar (ConvertFrom-YamlScalar), and it reads only runner_anchors, basis and
#     dispatch_kind from an --against artifact, never this key.
# A reader that takes (\S+) after this key gets the quotes as well: 'mainline', not mainline.
# THE dispatch_kind LINE STAYS BARE, and that is not an oversight. The gate's reader above takes the
# prior's kind with (\S+), so a quoted class would be read with its quotes and pass through
# ConvertTo-VerifyClass untranslated. An unknown declared word therefore still reaches that line
# unquoted, as it did before; that hazard is not cured here.
# FORWARD ONLY: anchors already on disk are not rewritten, and a flagless verify against one that
# records dispatch_kind: mainline still refuses.
$anchorsKindToken = if ($dispatchDoc['kind']) { [string]$dispatchDoc['kind'] } else { 'mainline' }
[void]$sb.AppendLine("dispatch_kind: $(ConvertTo-VerifyClass -KindToken $anchorsKindToken)")
[void]$sb.AppendLine("dispatch_kind_token: $(ConvertTo-YamlSingleQuoted $anchorsKindToken)")
# R-1 as amended: on PASS-DIB the refusing subject list is recorded VERBATIM, so a reader of the
# anchors can see exactly which members were admitted un-derived rather than having to infer it
# from a clean-looking gate. An empty list means the gate was a plain PASS.
if ($verifyAdmission.Count -gt 0) {
    [void]$sb.AppendLine("verify_admission:")
    foreach ($a in $verifyAdmission) { [void]$sb.AppendLine("  - $a") }
    [void]$sb.AppendLine("verify_admission_note: `"PASS-DIB (LAM-ACCEPT amendment 3) and/or advance admission (amendment 4). Suite subjects are bound instead by the runner-observed tally above; head_sha and porcelain are admitted only on ancestry + cleanliness + ledger provenance. Both are transitional: the suite members bind normally once verify increment 2 lands.`"")
    # The advance admission is recorded VERBATIM when used, so a reader sees the exact
    # basis it was granted on rather than a bare 'admitted'.
    if ($null -ne $verifyAdvance) {
        [void]$sb.AppendLine("verify_advance_admission:")
        [void]$sb.AppendLine("  admitted: $(if ($verifyAdvance.admitted) { 'true' } else { 'false' })")
        [void]$sb.AppendLine("  recorded_sha: $($verifyAdvance.recorded)")
        [void]$sb.AppendLine("  current_sha: $($verifyAdvance.current)")
        [void]$sb.AppendLine("  commit_count: $($verifyAdvance.commit_count)")
        [void]$sb.AppendLine("  ledger_match: $(if ($verifyAdvance.ledger_match) { 'true' } else { 'false' })")
        [void]$sb.AppendLine("  reason: $(ConvertTo-YamlSingleQuoted ([string]$verifyAdvance.reason))")
        # LOUDNESS. A declaration may never act silently: the
        # anchors carry the declared patterns VERBATIM, the entries each one tolerated, and the
        # declaration's source with its sha256 -- so the completion review reads what was tolerated,
        # and on whose authority, off this artifact's face instead of re-deriving it.
        # THE DECLARED LEDGER, RECORDED WHERE THE DECLARATION IS USED.
        # Beside porcelain_declaration and NOT inside runner_anchors: this is the ADMISSION's
        # declaration, and the runner_anchors header states that block is the expanded-schemas shape
        # and "not this build's to extend". Two-space indent alone would not have put it there
        # anyway -- position relative to the first column-0 key decides that, and a block that looks
        # correctly indented can land in the wrong section entirely.
        #
        # Emitted ONLY when a declaration exists. A mission that declares nothing is governed by
        # the default rule and this artifact stays exactly as it was, which is what keeps every existing
        # anchors reader working.
        $ld = $null
        if ($verifyAdvance.PSObject.Properties.Name -contains 'ledger_declaration') { $ld = $verifyAdvance.ledger_declaration }
        if ($null -ne $ld -and $ld.declared) {
            [void]$sb.AppendLine("  ledger_declaration:")
            [void]$sb.AppendLine("    declared: true")
            [void]$sb.AppendLine("    path: $(([string]$ld.path) -replace '\\', '/')")
            [void]$sb.AppendLine("    required_repo_tag: $($ld.required_repo_tag)")
            [void]$sb.AppendLine("    source: $(([string]$ld.source) -replace '\\', '/')")
            [void]$sb.AppendLine("    source_sha256: $($ld.source_sha256)")
        }
        $pd = $verifyAdvance.porcelain_declaration
        if ($null -ne $pd) {
            [void]$sb.AppendLine("  porcelain_declaration:")
            [void]$sb.AppendLine("    declared: $(if ($pd.declared) { 'true' } else { 'false' })")
            if ($pd.declared) {
                [void]$sb.AppendLine("    source: $(([string]$pd.source) -replace '\\', '/')")
                [void]$sb.AppendLine("    source_sha256: $($pd.source_sha256)")
                [void]$sb.AppendLine("    patterns:")
                foreach ($p in @($pd.patterns)) { [void]$sb.AppendLine("      - $(ConvertTo-YamlSingleQuoted ([string]$p))") }
            } else {
                [void]$sb.AppendLine("    note: `"no admitted_porcelain declared; the shared code default applied, so this mission's tolerance is not mission-declared.`"")
            }
        }
        $tolerated = @($verifyAdvance.porcelain_tolerated)
        if ($tolerated.Count -gt 0) {
            [void]$sb.AppendLine("  porcelain_tolerated:")
            foreach ($t in $tolerated) {
                [void]$sb.AppendLine("    - pattern: $(ConvertTo-YamlSingleQuoted ([string]$t.pattern))")
                [void]$sb.AppendLine("      entries:")
                foreach ($e in @($t.entries)) { [void]$sb.AppendLine("        - $(ConvertTo-YamlSingleQuoted ([string]$e))") }
            }
        } else {
            [void]$sb.AppendLine("  porcelain_tolerated: []")
        }
    }
}
# =============================================================================================
# THE verify_gate BLOCK -- R-1's mandated anchor grammar, which did not exist until now.
# =============================================================================================
# R-1: "Exactly THREE distinguishable gate outcomes exist, and every proceeding dispatch records
# which it took", and "No path records `verify_admission: []` and proceeds -- the subject list is
# OMITTED rather than emitted empty, so the distinction holds by construction."
#
# THE RUNNER DID BOTH THINGS THE CLAUSE FORBIDS. It emitted a literal `verify_admission: []` on
# every proceeding dispatch that was not PASS-DIB, and it recorded the outcome nowhere at all -- so
# a run that took the VACUOUS-FIRST path with verify NEVER SPAWNED and a run that took the
# verified-pass path with verify spawned and passing left IDENTICAL gate records. The durable
# artifact could not distinguish a gate that never ran from one that passed, which is the precise
# thing R-1 was amended to make impossible. Found by V-1 round 2 (WP-2); three of the five anchors
# files in the smoke mission still carry the empty list from before this cure.
#
# THE EMPTY LIST IS NOW OMITTED, NOT EMPTIED. That is what makes the distinction structural rather
# than a convention a later edit can quietly drop: `verify_admission` appears if and only if there
# were admitted subjects to name.
[void]$sb.AppendLine("verify_gate:")
[void]$sb.AppendLine("  outcome: $gateOutcome")
if ($gateOutcome -eq 'vacuous-first') {
    # The derivation is recorded, not the conclusion. A reader checks the two numbers that made
    # vacuity lawful rather than taking the word `vacuous-first` on trust.
    [void]$sb.AppendLine("  vacuity_derivation:")
    [void]$sb.AppendLine("    prior_artifacts: $vacuityPriors")
    [void]$sb.AppendLine("    markers: $vacuityMarkers")
    [void]$sb.AppendLine("  note: `"verify was NEVER INVOKED on this dispatch. Vacuity is lawful only for a genuinely-first dispatch -- zero priors AND zero markers -- and both figures are recorded above so the claim is checkable.`"")
}
elseif ($gateOutcome -eq 'verified-pass') {
    [void]$sb.AppendLine("  verify_exit: $verifyExit")
    if ($verifyAdmission.Count -gt 0) {
        [void]$sb.AppendLine("  admitted_subjects:")
        foreach ($a in $verifyAdmission) { [void]$sb.AppendLine("    - $a") }
    }
    # NO `admitted_subjects: []` BRANCH, deliberately. Omission is the signal: a plain PASS names
    # no subjects because none were admitted un-derived.
}
elseif ($gateOutcome -eq 'admitted-by-declared-repair') {
    # THE NEW STATE NEEDS ITS OWN BRANCH HERE, not only a seat in the closed set above. The `else`
    # below THROWS on any outcome this block cannot write, which is the assertion working: adding a
    # name to the vocabulary without teaching the artifact to record it would have produced a runner
    # that admitted a dispatch and then died writing its anchors. Driven -- the first run of the
    # instrument's row (a) exited 5 here.
    [void]$sb.AppendLine("  verify_exit: $verifyExit")
    if ($verifyAdmission.Count -gt 0) {
        [void]$sb.AppendLine("  admitted_subjects:")
        foreach ($a in $verifyAdmission) { [void]$sb.AppendLine("    - $a") }
    }
    [void]$sb.AppendLine("  declared_repair_ids:")
    foreach ($d in @($verifyRepair.declared)) { [void]$sb.AppendLine("    - $d") }
    # THE GATE IDS ARE RECORDED HERE TOO, and the reason is that they were being LOST. Precedence
    # decides which OUTCOME NAME the artifact carries, not which facts it carries. A dispatch that
    # carried both a declared repair and an authorizing gate recorded the declared repair -- which is
    # right -- and then wrote no gate id anywhere, while its admitted_subjects listed a subject only
    # the gate could have admitted. The comment on the branch below calls the gate id the only
    # per-subject provenance this class produces and says a completion review has nowhere else to get
    # it; under precedence that was true and the artifact had it nowhere. Round-1 validator finding.
    if (($null -ne $verifyOrigin) -and (@($verifyOrigin).Count -gt 0)) {
        [void]$sb.AppendLine("  authorizing_gate_ids:")
        foreach ($g in @($verifyOrigin)) { [void]$sb.AppendLine("    - $($g.gate_id)") }
    }
    [void]$sb.AppendLine("  note: `"ADMITTED-BY-DECLARED-REPAIR (amendment 29). The basis's unexpected-failure set equalled the ids this dispatch declared, exactly. The declared_repairs block below records whether the worker's own suite run then delivered them; it is a DEBT, not a waiver, and an undelivered one rejects this dispatch. If authorizing_gate_ids appears above, the origin-attestation class ALSO admitted on this dispatch and a declared repair took precedence over it -- the gate ids are recorded because precedence decides the outcome NAME and not which facts the artifact carries.`"")
}
elseif ($gateOutcome -eq 'admitted-by-authorized-publication') {
    # THE FOURTH STATE NEEDS ITS OWN BRANCH HERE FOR THE REASON RECORDED ABOVE FOR THE DECLARED REPAIR, and
    # the ratified anchor grammar names the field: `authorizing_gate_ids` under this
    # outcome. A ratified outcome the writer has no branch for is a dispatch admitted, spawned, and
    # then killed at its artifact by the else below -- which is not a hypothetical, it is what
    # the declared-repair admission's own first run did, exiting 5.
    #
    # THE GATE IDS, NOT THE SUBJECTS. The subject list says WHICH claims were admitted; it does not
    # say WHAT authorized them. The gate id is the only per-subject provenance this class produces,
    # and a completion review that wants to know WHICH ARTIFACT authorized a subject has nowhere
    # else to get it. ERRATUM, ROUND 2 (found in review): this read "the artifact an operator minted". The
    # gate id identifies the artifact the admission MATCHED. Whether an operator minted it is not
    # tested anywhere on this path -- kind, tip, url, ref and revocation are -- and the contract
    # carries that as an open residual rather than a property this comment may assume.
    [void]$sb.AppendLine("  verify_exit: $verifyExit")
    if ($verifyAdmission.Count -gt 0) {
        [void]$sb.AppendLine("  admitted_subjects:")
        foreach ($a in $verifyAdmission) { [void]$sb.AppendLine("    - $a") }
    }
    [void]$sb.AppendLine("  authorizing_gate_ids:")
    foreach ($g in @($verifyOrigin)) { [void]$sb.AppendLine("    - $($g.gate_id)") }
    [void]$sb.AppendLine("  note: `"ADMITTED-BY-AUTHORIZED-PUBLICATION (built by amendment 51, ratified by amendment 52). This dispatch proceeded with a PASSING verify gate whose verdict ALSO carried a non-empty origin-attestation list: the tip an UNREVOKED push gate authorizes for its declared ref at its declared origin is the tip verify derived from origin. THIS NAME RECORDS WHICH BRANCH WROTE THIS ARTIFACT, NOT THAT NOTHING ELSE ADMITTED. The assignment tests the gate outcome and that list and NOTHING ELSE -- it does not test exclusivity -- so another ruled admission may also have fired on this dispatch, and admitted_subjects above is the list that says. (ERRATUM, ROUND 2 (found in review): this note read 'proceeded ONLY because', which the subject list on a dispatch also carrying an admitted suite subject refutes on its own face.) CONSUMPTION IS NOT TESTED AND THIS NOTE DOES NOT CLAIM IT: the admission's own comment records consumed_at as LOAD-BEARING and deliberately untested, because the settle verb's first exercise stamps it onto the very gate that admits a closed arc's goal, and filtering consumed gates out would send that goal back to NOT_MET the moment it was settled. The gate ids above are the artifacts THIS ADMISSION MATCHED. NO PROVENANCE OF ANY KIND IS TESTED: the admission checks kind, tip, url, ref and revocation, so a hand-authored file at a name no mint would choose is admitted and recorded here -- which this contract carries as an open residual. (ERRATUM, ROUND 2 (found in review): this read 'the artifacts an operator minted'.) A declared repair, had this dispatch also carried one, would have taken precedence and this outcome would not have been written.`"")
}
else {
    # UNREACHABLE, AND IT THROWS RATHER THAN RECORDING A NOTE. The gate above closes
    # the outcome vocabulary at four and refuses anything else BEFORE a worker is spawned, so
    # arriving here means that assertion was bypassed -- a runner defect, not a gate outcome.
    #
    # The previous form wrote an `outcome_unrecognised:` line and carried on. That was right while
    # `operator-admitted` was an unbuilt third outcome and the honest answer was "my accounting is
    # incomplete". It is wrong now: the outcome is STRUCK, the set is closed, and an anchor that
    # records a proceeding dispatch the runner cannot name is precisely the unaccounted admission
    # this clause exists to make impossible. A runner that cannot name its own gate outcome dies
    # loudly instead of writing an artifact a completion review would have to interpret.
    throw "mission-dispatch: INVARIANT VIOLATED -- gate outcome '$gateOutcome' is outside the closed set ($($closedGateOutcomes -join ', ')) at anchor-writing time, which the pre-spawn assertion should have refused. This is a runner defect; no anchor is written for an outcome the runner cannot name."
}
# The supersession skip is recorded VERBATIM, so a reader sees which prior
# artifact was passed over and on what marker -- never an unexplained absence of a basis.
if ($skippedPrior.Count -gt 0) {
    [void]$sb.AppendLine("superseded_prior:")
    foreach ($s in $skippedPrior) {
        [void]$sb.AppendLine("  - dispatch_id: $($s.id)")
        [void]$sb.AppendLine("    marker: $(($s.path) -replace '\\', '/')")
        [void]$sb.AppendLine("    marker_sha256: $($s.sha256)")
    }
} else {
    [void]$sb.AppendLine("superseded_prior: []")
}
[void]$sb.AppendLine("dispatch_id: $Dispatch")
# R-2 as amended: the prompt IS the dispatch artifact, and this is its sha256,
# re-derived from the file at spawn time. It makes the prompt the worker actually received
# checkable against the artifact on disk, which is what "recorded sha256" was always for.
[void]$sb.AppendLine("dispatch_sha256: $dispatchSha")
# THE GATE THIS SPAWN RAN UNDER (operator ruling (i), candidate C5), on the runner's own record of the
# dispatch. Written only when -DispatchGate named one, so no other dispatch's anchors change.
if ($null -ne $dgStamp) {
    [void]$sb.AppendLine("dispatch_gate:")
    [void]$sb.AppendLine("  gate_id: $(ConvertTo-YamlSingleQuoted ([string]$DispatchGate))")
    [void]$sb.AppendLine("  gate_file: $(ConvertTo-YamlSingleQuoted ('.mission/gates/dispatch-' + $DispatchGate + '.yaml'))")
    [void]$sb.AppendLine("  spawn_seq: $($dgStamp.spawn_seq)")
    [void]$sb.AppendLine("  of_count: $($dgStamp.count)")
    [void]$sb.AppendLine("  first_stamp: $(if ($dgStamp.first) { 'true' } else { 'false' })")
    [void]$sb.AppendLine("  consumed_at: $(ConvertTo-YamlSingleQuoted ([string]$dgStamp.consumed_at))")
    [void]$sb.AppendLine("  manifest_sha256: $($dgStamp.manifest_sha256)")
    [void]$sb.AppendLine("  gate_sha256_after: $($dgStamp.sha_after)")
}
[void]$sb.AppendLine("session_id: $sessionId")
[void]$sb.AppendLine("role: $roleForRun")
[void]$sb.AppendLine("model_id: $model")
[void]$sb.AppendLine("worktree_path: $worktreePath")
# THE CUT POINT, ON THE DURABLE RECORD. Five closed facts, so a later reader never has to
# infer which case applied -- which field was consulted, what it said, whether the tree the worker
# got was actually there, and whether it stayed there. `declared_base: null` is the honest shape
# for a dispatch that named none, and `worktree_base_observed` then carries the sha the tree stood at
# BEFORE the worker ran -- the sha the runner cut it at, or where a reused tree stood -- which is the
# one thing an operator needs in order to fill the field in. (It used to name "the sha the CLI chose";
# with no --worktree the CLI chooses nothing.)
$declaredBaseNote = if (-not $declaredBase) {
    "NOT DECLARED -- this dispatch names no base_head_at_authoring and no tip_judged. The runner cut a new worktree at the mission root's HEAD (or reused an existing one where it stood) and did not assert it; worktree_base_observed records the sha the tree stood at before the worker ran. Declare the field to have the cut point ASSERTED rather than merely recorded."
} elseif ($worktreeBaseHonoured) {
    "The runner materialised the worktree at the declared $declaredBaseField BEFORE the spawn and spawned the worker in it. A tree that could not be brought to the declared base refuses the dispatch (exit 2) rather than running."
} else {
    "DECLARED BUT NOT HONOURED -- written because the anchors are recorded before any refusal."
}
[void]$sb.AppendLine("declared_base_field: $(if ($declaredBase) { $declaredBaseField } else { 'null' })")
[void]$sb.AppendLine("declared_base: $(if ($declaredBaseResolved) { $declaredBaseResolved } elseif ($declaredBase) { $declaredBase } else { 'null' })")
[void]$sb.AppendLine("worktree_base_honoured: $(if ($worktreeBaseHonoured) { 'true' } else { 'false' })")
[void]$sb.AppendLine("worktree_base_observed: $(if ($worktreeBaseObserved) { $worktreeBaseObserved } elseif ($wtSha) { $wtSha } else { 'null' })")
[void]$sb.AppendLine("worktree_base_still_descends: $(if ($null -eq $worktreeBaseKept) { 'null' } elseif ($worktreeBaseKept) { 'true' } else { 'false' })")
[void]$sb.AppendLine("declared_base_note: $(ConvertTo-YamlSingleQuoted $declaredBaseNote)")
[void]$sb.AppendLine("worktree_tip_sha: $(if ($wtSha) { $wtSha } else { 'null' })")
[void]$sb.AppendLine("diffstat: $(ConvertTo-YamlSingleQuoted ([string]$diffstat))")
# THE FIELD ABOVE IS NOW POPULATED, AND WHAT IT WAS MEASURED AGAINST TRAVELS WITH IT. An empty
# diffstat is a real answer -- a run that changed nothing -- and it used to be indistinguishable
# from a runner that never asked the question. It is distinguishable now: the basis names the sha.
[void]$sb.AppendLine("diffstat_basis: $(ConvertTo-YamlSingleQuoted ([string]$diffstatBasis))")
# THE ORIGIN TIP'S SATELLITES, DELIBERATELY OUTSIDE THE BLOCK. `origin_tip` itself is inside because that
# is the name mission-verify reads and the name the schema declares; these three are THIS BUILD'S
# additions and the header's rule governs them unchanged. Together they make the null case readable:
# WHICH ref was asked for, WHAT the command answered, and WHY there is no sha -- so "origin could not
# be reached", "origin has no such branch" and "nobody asked" are three different records instead of
# one shared silence. The exit code is load-bearing and not metadata: it is the only thing that
# separates unreachable from absent.
#
# THE ORIGIN URL IS NOT AMONG THEM AND WILL NOT BE. A remote URL can carry userinfo; this artifact is
# durable, is committed, and is read by reviewers.
[void]$sb.AppendLine("origin_tip_ref: $(if ($originTip.ref) { ConvertTo-YamlSingleQuoted ([string]$originTip.ref) } else { 'null' })")
[void]$sb.AppendLine("origin_tip_exit_code: $(if ($null -ne $originTip.exit_code) { [int]$originTip.exit_code } else { 'null' })")
[void]$sb.AppendLine("origin_tip_note: $(ConvertTo-YamlSingleQuoted ([string]$originTip.reason))")
[void]$sb.AppendLine("wall_clock_seconds: $wall")
[void]$sb.AppendLine("worker_exit_code: $workerExit")
[void]$sb.AppendLine("runner_stream: $streamPath")
# WHERE THE HANDOFF CAME FROM, ON THE DURABLE RECORD. This runner's own R-4 comment says
# STDOUT IS NOT A CHANNEL, and that applies to the placement too: printing it is for the human
# watching the run, and the anchors are what a later reader opens. `handoff_source` is one of three
# closed values, so a reader never has to infer the provenance from an absence.
[void]$sb.AppendLine("handoff_path: $handoffPath")
if ($handoffPlacedFrom) {
    [void]$sb.AppendLine("handoff_source: placed-from-worktree-by-the-runner")
    [void]$sb.AppendLine("handoff_placed_from: $handoffPlacedFrom")
    [void]$sb.AppendLine("handoff_placed_sha256: $handoffPlacedSha")
    [void]$sb.AppendLine("handoff_placed_mtime_utc: $handoffPlacedTime")
} elseif (Test-Path -LiteralPath $handoffPath) {
    [void]$sb.AppendLine("handoff_source: written-at-the-shared-path-by-the-worker")
} else {
    [void]$sb.AppendLine("handoff_source: absent")
}
# THE STRICT-YAML VERDICT, ON THE DURABLE RECORD: was this handoff shown to a real YAML parser, and what
# did it say. `handoff_strict_yaml` is one of FOUR closed values -- parsed, refused, unavailable,
# not-applicable -- and the fourth is not padding: a dispatch with no handoff at all parsed nothing,
# and recording that as `parsed` or as `unavailable` would both be untrue. The point of the field is
# that a later reader never has to infer from an absence whether the check ran; `unavailable` is a
# fact about the HOST, and it is the only value under which the dispatch proceeds unparsed.
if ($null -eq $script:StrictYamlLast) {
    [void]$sb.AppendLine("handoff_strict_yaml: not-applicable")
    [void]$sb.AppendLine("handoff_strict_yaml_note: $(ConvertTo-YamlSingleQuoted 'no handoff artifact was validated, so nothing was handed to a parser')")
} else {
    [void]$sb.AppendLine("handoff_strict_yaml: $($script:StrictYamlLast.outcome)")
    [void]$sb.AppendLine("handoff_strict_yaml_path: $(ConvertTo-YamlSingleQuoted $script:StrictYamlLast.path)")
    if ($script:StrictYamlLast.outcome -eq 'refused') {
        [void]$sb.AppendLine("handoff_strict_yaml_parser: $(ConvertTo-YamlSingleQuoted $script:StrictYamlLast.parser)")
        [void]$sb.AppendLine("handoff_strict_yaml_problem: $(ConvertTo-YamlSingleQuoted $script:StrictYamlLast.problem)")
        [void]$sb.AppendLine("handoff_strict_yaml_line: $($script:StrictYamlLast.line)")
        [void]$sb.AppendLine("handoff_strict_yaml_column: $($script:StrictYamlLast.column)")
    } elseif ($script:StrictYamlLast.outcome -eq 'parsed') {
        [void]$sb.AppendLine("handoff_strict_yaml_parser: $(ConvertTo-YamlSingleQuoted $script:StrictYamlLast.parser)")
    } else {
        [void]$sb.AppendLine("handoff_strict_yaml_note: $(ConvertTo-YamlSingleQuoted $script:StrictYamlLast.detail)")
    }
}
[void]$sb.AppendLine("capture_gaps_count: $(if ($null -ne $gapsCount) { $gapsCount } else { 'null' })")
[void]$sb.AppendLine("capture_gaps_sha256: $(if ($gapsSha) { $gapsSha } else { 'null' })")
if ($gitErrors.Count -gt 0) {
    [void]$sb.AppendLine("git_errors:")
    foreach ($e in $gitErrors) { [void]$sb.AppendLine("  - $(ConvertTo-YamlSingleQuoted ([string]$e))") }
} else {
    [void]$sb.AppendLine("git_errors: []")
}
# =============================================================================================
# THE DECLARED REPAIR IS ASSESSED AGAINST THE WORKER'S OWN SUITE RUN
# =============================================================================================
# WHY THIS RUNS WHENEVER A DECLARATION EXISTS, and not only when the admission was granted. The
# grant is what a declaration BUYS; delivering it is what a declaration COSTS, and tying the cost to
# the grant would leave a path where a dispatch declares repairs, the gate happens to pass for some
# other reason, and nothing ever asks whether the named tests were fixed. Unconditional is one rule
# with no branch to slip through -- if you declare it, you deliver it.
#
# THE OBSERVATION IS WRITTEN INTO THE ANCHORS BEFORE ANY REFUSAL, exactly as the PASS-DIB tally is:
# the artifact records what actually happened, and the refusal below is about whether the run
# SUCCEEDED, never about suppressing the evidence that it did not.
$repairUndelivered = @()
$repairAssessed    = $false
if ($declaredRepairs.declared) {
    [void]$sb.AppendLine("declared_repairs:")
    if ($null -eq $suiteFailedIds) {
        # NOT ASSESSED IS NOT DELIVERED. The suite never ran, so every declared id is recorded
        # `delivered: null` -- an honest absence -- and the dispatch is rejected below.
        foreach ($e in @($declaredRepairs.entries)) {
            [void]$sb.AppendLine("  - test_id: $($e.test_id)")
            [void]$sb.AppendLine("    reason: $(ConvertTo-YamlSingleQuoted ([string]$e.reason))")
            [void]$sb.AppendLine("    repairing_commit_label: $($e.repairing_commit_label)")
            [void]$sb.AppendLine("    delivered: null")
        }
        [void]$sb.AppendLine("declared_repairs_note: `"NOT ASSESSED -- no suite run was observed for this dispatch, so nothing shows the declared test(s) passing.`"")
        $repairUndelivered = @($declaredRepairs.test_ids)
    } else {
        # -ccontains, not -contains: a pytest node id is a case-sensitive identifier and
        # PowerShell's default comparison is case-INSENSITIVE (the same care is taken at
        # the tally site). A case-only difference is a real difference.
        $repairAssessed = $true
        foreach ($e in @($declaredRepairs.entries)) {
            $stillFailing = ($suiteFailedIds -ccontains $e.test_id)
            if ($stillFailing) { $repairUndelivered += $e.test_id }
            [void]$sb.AppendLine("  - test_id: $($e.test_id)")
            [void]$sb.AppendLine("    reason: $(ConvertTo-YamlSingleQuoted ([string]$e.reason))")
            [void]$sb.AppendLine("    repairing_commit_label: $($e.repairing_commit_label)")
            [void]$sb.AppendLine("    delivered: $(if ($stillFailing) { 'false' } else { 'true' })")
        }
        [void]$sb.AppendLine("declared_repairs_note: $(ConvertTo-YamlSingleQuoted "Assessed against the runner-observed suite run of this dispatch: delivered iff the id is absent from that run's FAILED lines. $($declaredRepairs.test_ids.Count) declared; $($repairUndelivered.Count) still failing.")")
    }
    [void]$sb.AppendLine("declared_repair_admission: $(if (($null -ne $verifyRepair) -and $verifyRepair.admitted) { 'ADMITTED-BY-DECLARED-REPAIR' } else { 'none -- the gate did not rest on this declaration' })")
}
# =============================================================================================
# A VALIDATOR'S RESULT CARRIES THE PAIR THE DETECTOR COUNTS, OR THE DISPATCH
# IS REJECTED WITH THE OFFENDING LINE PRINTED
# =============================================================================================
# THE ROW. The validator-result template standing says the result's first line is `verdict: PASS`
# or `verdict: FAIL`. FAIL IS IN NO RESULT VOCABULARY THIS BUILD DEFINES -- V-1's pair is
# PASS / REFUTED -- and it is not a wording quibble: `verdict: FAIL` matches NEITHER of
# mission-goal-check.ps1's two `validator_pass_count` regexes, so the detector's `continue` fires
# BEFORE its ledger-binding test and the result is neither counted NOR reported FOREIGN. It is
# INVISIBLE, and the goal reads one short for ever with nothing on disk naming the reason.
# REPRODUCED, NOT INFERRED: .mission/dispatches/D-V-A-579-R3.yaml orders "THE FIRST NON-COMMENT LINE
# OF YOUR RESULT FILE IS EXACTLY ONE OF THESE, AT COLUMN 0 ... verdict: PASS / verdict: FAIL", then
# quotes the correct PASS regex three lines below it, then adds "`verdict: FAIL` is a complete and
# successful outcome". Four dispatch artifacts on this mission carry that pair; D-V-A-569.yaml is
# the one that says "PASS or REFUTED" instead.
#
# WHY THE RUNNER IS THE PLACE. Until now NOTHING between the validator and the goal evaluator ever
# opened a result file: `result.yaml` and `REFUTED` each returned zero matches in this program, and
# the only thing that distinguished a validator dispatch from a worker dispatch was which settings
# file went into the argv. The evaluator runs LATER, against whatever is on disk, and its answer to
# a foreign verdict is silence by construction. The runner is the last moment at which the artifact
# and the dispatch that ordered it are both in hand.
#
# THE PAIR IS NOT RESTATED HERE. Get-LamValidatorVerdict comes from lam-verify-admission.ps1, the
# file whose whole purpose is that each admission constant has exactly one copy, and which the goal
# evaluator ALSO dot-sources. The two patterns it holds are character-identical to the evaluator's
# own inline literals -- verified, not assumed -- so this assertion admits exactly what the detector
# counts and refuses exactly what the detector cannot see.
#
# POSITION IS READ AND REPORTED, NEVER ASSERTED, and the measurement is the reason. The template
# demands the verdict be the FIRST NON-COMMENT LINE. All seven validator results this build has
# produced open with `id:` or `workpackage:` and carry the verdict on line 2 to 5; NOT ONE would
# survive that rule. A runner enforcing the wording would reject every result the build has ever
# made, which is a cure worse than the row. `validator_result_at_first_line` records the reading.
#
# NOT DECLARED IS RECORDED, NOT REFUSED -- the same asymmetry the cut point chose one block up for
# declared_base, and for the same reason: a runner cannot invent the path a dispatch declined to
# name, and refusing there imposes a new requirement on the artifact template rather than curing
# this row. Measured before choosing: all 21 validator dispatch artifacts on this mission declare
# `result_path:` at the top level, so the branch is unreachable for live work. DECLARED AND ABSENT
# is the opposite case and it REFUSES: a dispatch that named its own product and did not produce it
# has not succeeded, and a silent pass there is the defect this row is about.
#
# IT REJECTS THROUGH $handoffProblems -- the same rc-3 mechanism the declared-repair debt and the
# strict handoff parse already use -- so a run that gets two things wrong reports both instead of
# teaching the operator to fix one and rediscover the other. No exit code in the contract changes.
$validatorResult = [pscustomobject]@{
    outcome = 'not-applicable'; path = ''; line = ''; first = ''; atFirst = $false
    note    = 'this dispatch is not a validator, so no result artifact was expected or read'
}
if ($roleKind -eq 'validator') {
    $declaredResult = ([string]$dispatchDoc['result_path']).Trim()
    if (-not $declaredResult) {
        $validatorResult.outcome = 'not-declared'
        $validatorResult.note    = "this validator dispatch declares no result_path, so the runner has no artifact to open. RECORDED, NOT REFUSED -- naming the file is the artifact template's job, not this runner's to guess."
    } else {
        # WHERE A VALIDATOR'S RESULT ACTUALLY LANDS. The worktree first, because that is where the
        # validator writes: tools/lam/settings/validator.json allows exactly one edit path and the
        # spawn runs in the worktree, which is why D-V-A-579-R3's own handoff_note says the seat
        # "reads the result from the worktree". The mission root second, for a validator run without
        # one and for a result already placed. BOTH are recorded when neither holds a file, because
        # "not found" without the paths searched is an accusation rather than a finding.
        $resultCandidates = @()
        if ($worktreeMade) { $resultCandidates += (Join-Path $worktreePath $declaredResult) }
        $resultCandidates += (Join-Path $MissionRoot $declaredResult)
        $resultHit = ''
        foreach ($c in $resultCandidates) {
            if ((-not $resultHit) -and (Test-Path -LiteralPath $c -PathType Leaf)) { $resultHit = $c }
        }
        if (-not $resultHit) {
            $validatorResult.outcome = 'not-found'
            $validatorResult.path    = ($resultCandidates -join ' ; ')
            $validatorResult.note    = "the dispatch declares result_path '$declaredResult' and no file stands at it. Searched: $($resultCandidates -join ' ; ')"
        } else {
            $validatorResult.path = $resultHit
            $resultText = $null
            try { $resultText = [System.IO.File]::ReadAllText($resultHit) }
            catch {
                $validatorResult.outcome = 'unreadable'
                $validatorResult.note    = "the result at $resultHit could not be read -- $($_.Exception.Message)"
            }
            if ($null -ne $resultText) {
                $vres = Get-LamValidatorVerdict -Text $resultText
                $validatorResult.outcome = $vres.outcome
                $validatorResult.line    = $vres.line
                $validatorResult.first   = $vres.first_noncomment
                $validatorResult.atFirst = $vres.at_first_line
                $validatorResult.note    = switch ($vres.outcome) {
                    'PASS'      { "a top-level verdict at column 0 reading PASS -- the pattern mission-goal-check.ps1's validator_pass_count counts" }
                    'REFUTED'   { "a top-level verdict at column 0 reading REFUTED -- COMPLETE under LAM-ACCEPT amendment 23 when its findings are registered residuals accepted by a completion-acceptance gate; that acceptance is the goal evaluator's to judge, not this runner's" }
                    'foreign'   { "the one top-level verdict line matches neither PASS nor REFUTED, so the goal evaluator will not count it and will not report it foreign either -- it would be invisible" }
                    'absent'    { "no top-level verdict line at column 0 at all; an indented verdict inside a mapping does not count, which is exactly the false-PASS the detector's column-0 anchor exists to stop" }
                    'ambiguous' { "$($vres.count) top-level verdict lines; the detector tests REFUTED before PASS, so a file answering twice would be counted as whichever it names first, not as whichever its author meant" }
                    default     { "outcome $($vres.outcome)" }
                }
            }
        }
    }
}
[void]$sb.AppendLine("validator_result: $($validatorResult.outcome)")
if ($validatorResult.path)  { [void]$sb.AppendLine("validator_result_path: $(ConvertTo-YamlSingleQuoted $validatorResult.path)") }
if ($validatorResult.line)  { [void]$sb.AppendLine("validator_result_verdict_line: $(ConvertTo-YamlSingleQuoted $validatorResult.line)") }
if ($validatorResult.first) {
    [void]$sb.AppendLine("validator_result_first_noncomment: $(ConvertTo-YamlSingleQuoted $validatorResult.first)")
    [void]$sb.AppendLine("validator_result_at_first_line: $(if ($validatorResult.atFirst) { 'true' } else { 'false' })")
}
[void]$sb.AppendLine("validator_result_note: $(ConvertTo-YamlSingleQuoted $validatorResult.note)")

# SAID OUT LOUD ON EVERY OUTCOME, so a reader of the stream never infers from silence whether the
# check ran -- the same discipline the anchors strict-parse verdict takes twenty lines below.
if ($roleKind -eq 'validator') {
    Write-Line "mission-dispatch: validator result -- $($validatorResult.outcome)$(if ($validatorResult.path -and ($validatorResult.outcome -ne 'not-found')) { " at $($validatorResult.path)" } else { '' })"
}
$validatorAdmitted = @('PASS', 'REFUTED', 'not-applicable', 'not-declared')
if (-not ($validatorAdmitted -ccontains $validatorResult.outcome)) {
    Write-Line "mission-dispatch: VALIDATOR-RESULT-$(($validatorResult.outcome).ToUpperInvariant()) -- this validator's result does not carry the verdict the goal evaluator counts."
    Write-Line "    declared : result_path $(([string]$dispatchDoc['result_path']).Trim())"
    if ($validatorResult.outcome -eq 'not-found') {
        Write-Line "    searched : $($validatorResult.path)"
    } else {
        Write-Line "    at       : $($validatorResult.path)"
    }
    if ($validatorResult.line) {
        # THE OFFENDING LINE, VERBATIM AND IN QUOTES. A refusal that paraphrases the bytes is the
        # refusal an author cannot act on: `verdict: FAIL` and `verdict:  FAIL ` fail for different
        # reasons and a summary hides which.
        Write-Line "    the line : `"$($validatorResult.line)`""
    } else {
        Write-Line "    the first non-comment line is: `"$($validatorResult.first)`""
    }
    Write-Line "    the pair : verdict: PASS  |  verdict: REFUTED   (at COLUMN 0; the goal evaluator's own $($script:LamValidatorVerdictPassPattern) and $($script:LamValidatorVerdictRefutedPattern))"
    Write-Line "  $($validatorResult.note)"
    Write-Line "  Recorded in the anchors; this run is NOT a success."
    $handoffProblems += "VALIDATOR-RESULT-$(($validatorResult.outcome).ToUpperInvariant()): $($validatorResult.note)"
}
# =============================================================================================
# A VALIDATOR SESSION THAT LEFT NO RESULT IS REFUSED UNDER A NAME (BATCH-3 WP-K (a))
# =============================================================================================
# The check above has now read the result ONCE MORE, after whatever wait followed the session's exit. Two things are
# written here. (1) THE WAIT, wherever the result was absent from the validator's own tree as the session exited:
# what was seen, how long was waited and how it ended, as validator_result_session_end and validator_result_wait*
# -- also where the result then appeared and was read (the placement below takes it as it takes any other).
# (2) THE REFUSAL, where the result is still nowhere (validator_result: not-found): its NAME,
# NO-RESULT-AT-SESSION-END-<CODE>, and its reason, as validator_result_refusal and validator_result_refusal_reason;
# the same name joins $handoffProblems beside VALIDATOR-RESULT-NOT-FOUND, whose lines above are unchanged; and ONE
# note goes to the spawn ledger through the composer at the moment of the act, as for the other two refusals.
# THE COMPLETE LINE IS STILL NOT THIS RUNNER'S (per the acceptance contract: it pairs the seq the seat's spawn
# line took, which the runner does not hold). The seat composes it from these anchors, and it carries this refusal
# and this reason in the ledger's existing `refusal` and `reason` fields beside its null result: no field is added,
# and result_sha256 keeps its name and its meaning. The composer's rule (14) gives that line its form.
if ($null -ne $noResultWait) {
    [void]$sb.AppendLine("validator_result_session_end: absent-at-source")
    [void]$sb.AppendLine("validator_result_session_end_source: $(ConvertTo-YamlSingleQuoted $noResultSource)")
    [void]$sb.AppendLine("validator_result_wait: $(([string]$noResultWait.code).ToLowerInvariant())")
    [void]$sb.AppendLine("validator_result_wait_bound_seconds: $([int]$noResultWait.bound_seconds)")
    [void]$sb.AppendLine("validator_result_wait_ms: $([long]$noResultWait.waited_ms)")
    [void]$sb.AppendLine("validator_result_wait_descendants_seen: $(@($noResultWait.seen).Count)")
    [void]$sb.AppendLine("validator_result_wait_descendants: $(ConvertTo-YamlSingleQuoted ((@($noResultWait.seen) | ForEach-Object { "$($_.pid) $($_.name)".Trim() }) -join '; '))")
    [void]$sb.AppendLine("validator_result_wait_alive_at_end: $(@($noResultWait.alive).Count)")
    [void]$sb.AppendLine("validator_result_wait_note: $(ConvertTo-YamlSingleQuoted $noResultWaitSaid)")
}
if (($roleKind -eq 'validator') -and ($validatorResult.outcome -ceq 'not-found')) {
    if ($null -eq $noResultWait) {
        # A file stood in the tree as the session exited and none stands there at this reading: nothing was waited for.
        $noResultWait = [pscustomobject]@{ code = 'DESCENDANTS-UNKNOWN'; seen = @(); alive = @(); waited_ms = [long]0; bound_seconds = $NoResultWaitSeconds; bound_elapsed = $false
                                           error = 'a file stood at the source as the session exited and none stands there now' }
        $noResultWaitSaid = "the session's descendants were not enumerated and nothing was waited for"
        $noResultVanished = $true
    }
    $noResultCode   = "NO-RESULT-AT-SESSION-END-$($noResultWait.code)"
    $noResultStood  = if ($noResultVanished) { 'a file stood' } else { 'no result stood' }
    $noResultReason = "$noResultStood at '$noResultRel' in the validator's own tree as its session exited (worker exit $workerExit), and none stands there or at the mission root now: $noResultWaitSaid"
    [void]$sb.AppendLine("validator_result_refusal: $noResultCode")
    [void]$sb.AppendLine("validator_result_refusal_reason: $(ConvertTo-YamlSingleQuoted $noResultReason)")
    Write-Line "mission-dispatch: $noResultCode -- $noResultReason"
    $noResultNote = [ordered]@{
        event = 'note'; ts = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture); dispatch_id = $Dispatch
        outcome = 'NO-RESULT-AT-SESSION-END'; refusal = $noResultCode; runner_exit = 3; reason = $noResultReason
        result_path = $noResultRel; source_path = $noResultSource; worker_exit_code = $workerExit
        descendants_seen = @($noResultWait.seen).Count; descendant_pids = @(@($noResultWait.seen) | ForEach-Object { [int]$_.pid })
        descendants_alive_at_end = @($noResultWait.alive).Count; wait_bound_seconds = [int]$noResultWait.bound_seconds
        waited_ms = [long]$noResultWait.waited_ms; bound_elapsed = [bool]$noResultWait.bound_elapsed
        runner = 'tools/lam/mission-dispatch.ps1'; register_row = 365
    }
    $noResultLedger = Write-LamSpawnLedgerNote -ComposerPath (Join-Path $PSScriptRoot 'spawn_ledger.py') -LedgerPath (Get-LamLedgerPath -MissionRoot $MissionRoot) -Record $noResultNote
    Write-Line "    spawn ledger: $(if ($noResultLedger.ok) { $noResultLedger.said } else { 'NOT WRITTEN -- ' + $noResultLedger.said })"
    Write-Line "  Recorded in the anchors; this run is NOT a success."
    $handoffProblems += "${noResultCode}: $noResultReason"
}
# =============================================================================================

# THE RUNNER PLACES A VALIDATOR'S RESULT AT THE MISSION ROOT (BATCH-2 WP-G (b))
# =============================================================================================
# THE DEFECT: the block above reads a validator's result where it lands and copied it
# nowhere, while the goal's validator_pass_count reads tests/lam at the ROOT -- so every result reached it
# by an operator's act, the placement loop a retrospective names (refuse if it
# exists, hash both ends). The loop is this runner's now. A validator dispatch whose result was read in ITS
# OWN TREE and carries PASS or REFUTED -- the pair above -- has that file copied to the same declared
# result_path at the mission root, by Invoke-LamResultPlacement (no overwrite, ever; both ends hashed;
# time-preserving; its header says how):
#   * THE PATH IS tests/lam/<name>.result.yaml OR NOTHING: the charter's words, and the shape each of the
#     35 validator dispatch artifacts tracked when this was written declares. Any other declared path is
#     REFUSED by name and never written -- it is text from an artifact, and a copy aimed by it could land
#     wherever a relative path reaches;
#   * a destination already present is REFUSED and left byte-unchanged. A round-2 result at its round-1
#     name is exactly that case, and the answer stays the operator's archive of the round-1 file first.
# The placement is recorded in the anchors (validator_result_placement*) and said on stdout. A REFUSAL
# rejects the dispatch through $handoffProblems -- the rc-3 mechanism the check above uses, so no exit
# code in the contract changes -- and is written to the spawn ledger as a note, through the composer, at the
# moment of the act. THE COMPLETE LINE IS NOT THIS RUNNER'S: it pairs the seq the seat's spawn line took
# and carries the ceremony's facts, so the seat composes it from these anchors through the same composer --
# result_sha256 the copy's, result_source_sha256, result_source_path and result_dest_path beside it -- and
# the composer re-derives the file at result_dest_path and refuses a line whose hashes do not name it.
$placement = [pscustomobject]@{
    outcome = 'not-applicable'; code = ''; reason = ''; source = ''; destination = ''
    source_sha256 = ''; copy_sha256 = ''; source_sha256_after = ''
    destination_sha256_before = ''; destination_sha256_after = ''; bytes = 0; mtime = ''
}
$placementNote = 'this dispatch is not a validator, or it produced no result carrying PASS or REFUTED, so there is nothing to place'
if (($roleKind -eq 'validator') -and $validatorResult.path -and (@('PASS', 'REFUTED') -ccontains $validatorResult.outcome)) {
    $placeRel  = ([string]$dispatchDoc['result_path']).Trim()
    $placeFrom = ConvertTo-WorktreePathKey $validatorResult.path
    $placeTree = if ($worktreeMade) { ConvertTo-WorktreePathKey (Join-Path $worktreePath $placeRel) } else { '' }
    if ((-not $placeTree) -or ($placeFrom -ne $placeTree)) {
        $placement.outcome = 'not-placed-at-mission-root'
        $placementNote = "the result was read at $($validatorResult.path), not in this validator's own tree, so there is no copy to make"
    } elseif ($placeRel -notmatch '^tests[\\/]lam[\\/][A-Za-z0-9][A-Za-z0-9._-]*\.result\.yaml$') {
        $placement.outcome = 'refused-path'
        $placement.code = 'PATH'
        $placement.source = $validatorResult.path
        $placement.reason = "the declared result_path '$placeRel' is not tests/lam/<name>.result.yaml, so the runner places it nowhere"
    } else {
        $placement = Invoke-LamResultPlacement -Source $validatorResult.path -Destination (Join-Path $MissionRoot ($placeRel -replace '/', '\'))
    }
}
if ($placement.outcome -ceq 'placed') {
    $placementNote = "copied from this validator's own tree to the mission root, byte-equal and time-preserving; the complete line binds result_sha256 $($placement.copy_sha256), the copy's, with result_source_sha256, result_source_path and result_dest_path beside it"
    Write-Line "mission-dispatch: validator result PLACED at $($placement.destination) -- sha256 $($placement.copy_sha256), $($placement.bytes) bytes, copied from $($placement.source) (sha256 $($placement.source_sha256)); the two hashes are EQUAL (register row 349)"
} elseif ($placement.outcome -like 'refused-*') {
    $placementNote = $placement.reason
    Write-Line "mission-dispatch: RESULT-PLACEMENT-REFUSED-$($placement.code) -- $($placement.reason)"
    Write-Line "    source      : $($placement.source)$(if ($placement.source_sha256) { " (sha256 $($placement.source_sha256))" })"
    if ($placement.destination) { Write-Line "    destination : $($placement.destination)$(if ($placement.destination_sha256_before) { " (sha256 before $($placement.destination_sha256_before), after $($placement.destination_sha256_after))" })" }
    $placeNote = [ordered]@{
        event = 'note'; ts = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture); dispatch_id = $Dispatch
        outcome = 'RESULT-PLACEMENT-REFUSED'; refusal = "RESULT-PLACEMENT-$($placement.code)"; runner_exit = 3; reason = $placement.reason
        source_path = $placement.source; source_sha256 = $placement.source_sha256; destination_path = $placement.destination
        destination_sha256_before = $placement.destination_sha256_before; destination_sha256_after = $placement.destination_sha256_after
        runner = 'tools/lam/mission-dispatch.ps1'; register_row = 349
    }
    $placeLedger = Write-LamSpawnLedgerNote -ComposerPath (Join-Path $PSScriptRoot 'spawn_ledger.py') -LedgerPath (Get-LamLedgerPath -MissionRoot $MissionRoot) -Record $placeNote
    Write-Line "    spawn ledger: $(if ($placeLedger.ok) { $placeLedger.said } else { 'NOT WRITTEN -- ' + $placeLedger.said })"
    Write-Line "  Recorded in the anchors; this run is NOT a success."
    $handoffProblems += "RESULT-PLACEMENT-REFUSED-$($placement.code): $($placement.reason)"
} elseif ($placement.outcome -ceq 'not-placed-at-mission-root') {
    Write-Line "mission-dispatch: validator result not placed -- $placementNote"
}
[void]$sb.AppendLine("validator_result_placement: $($placement.outcome)")
if ($placement.source) { [void]$sb.AppendLine("validator_result_placement_source: $(ConvertTo-YamlSingleQuoted $placement.source)") }
if ($placement.source_sha256) { [void]$sb.AppendLine("validator_result_placement_source_sha256: $($placement.source_sha256)") }
if ($placement.source_sha256_after -and ($placement.source_sha256_after -cne $placement.source_sha256)) { [void]$sb.AppendLine("validator_result_placement_source_sha256_after: $($placement.source_sha256_after)") }
if ($placement.destination) { [void]$sb.AppendLine("validator_result_placement_destination: $(ConvertTo-YamlSingleQuoted $placement.destination)") }
if ($placement.outcome -ceq 'placed') {
    [void]$sb.AppendLine("validator_result_placement_sha256: $($placement.copy_sha256)")
    [void]$sb.AppendLine("validator_result_placement_bytes: $($placement.bytes)")
    [void]$sb.AppendLine("validator_result_placement_mtime: $(ConvertTo-YamlSingleQuoted $placement.mtime)")
}
if ($placement.destination_sha256_before) {
    [void]$sb.AppendLine("validator_result_placement_destination_sha256_before: $($placement.destination_sha256_before)")
    [void]$sb.AppendLine("validator_result_placement_destination_sha256_after: $($placement.destination_sha256_after)")
}
[void]$sb.AppendLine("validator_result_placement_note: $(ConvertTo-YamlSingleQuoted $placementNote)")
# =============================================================================================
# THE ANCHORS ARE SHOWN TO A REAL PARSER BEFORE THE RUNNER SIGNS THEM
# =============================================================================================
# The strict-YAML check made this runner ASK a real YAML parser about the HANDOFF. This block asks the same
# question about the artifact the runner writes ITSELF, because the answer was no: 39 of the 40
# *.anchors*.yaml files on this mission are refused by yaml.safe_load. A writer that never asks
# whether its own output is readable is exactly the writer that produced them, and the cure above
# is only as durable as the check that would notice it being undone.
#
# THE VERDICT IS RECORDED, NOT ENFORCED, and the direction is the whole argument. The anchors are
# written AFTER the work is done and they are a RECORD of it. Rejecting the dispatch because its
# own record failed to parse would destroy a run over the RUNNER's defect, and it would not even
# remove the bad bytes -- they would still be on disk, now with a rejection stapled to them. So
# this reads like the git-errors report at the end of this script: reported loudly, recorded
# durably, never a refusal. No exit code in the contract changes because of it.
#
# THREE OUTCOMES, NOT TWO -- parsed / refused / unavailable, the closed set the handoff check fixed. PS 5.1
# ships no YAML parser, so a host that was never asked to carry python must neither hard-fail nor
# pass silently; `unavailable` is a fact about the HOST and it is written down as one.
#
# THE BODY IS PROBED THROUGH A SCRATCH COPY so that $anchorsPath is still written EXACTLY ONCE.
# Every dispatch scans this directory for prior artifacts and ReadAllText()s what it finds; a
# two-step write would let a concurrent run catch a half-built anchors file.
#
# SCOPE, STATED RATHER THAN IMPLIED: the verdict is taken on the body ABOVE, before the
# anchors_strict_yaml block that carries it is appended. That block is single-quoted scalars and
# integers only, so it introduces no escape of its own and cannot change the answer it reports.
$anchorsBody   = $sb.ToString()
$anchorsStrict = [pscustomobject]@{ outcome = 'unavailable'; problem = ''; line = 0; column = 0
                                    parser = ''; detail = 'the anchors body was never handed to a parser'; path = $anchorsPath }
# The banked verdict belongs to the HANDOFF -- the handoff_strict_yaml_* fields above were read off
# it -- and probing a second artifact must not overwrite the record of the first.
$strictSaved  = $script:StrictYamlLast
$anchorsProbe = Join-Path ([System.IO.Path]::GetTempPath()) ("lam-anchors-probe-$([guid]::NewGuid().ToString('N')).yaml")
try {
    [System.IO.File]::WriteAllText($anchorsProbe, $anchorsBody, (New-Object System.Text.UTF8Encoding($false)))
    $anchorsStrict = Test-HandoffStrictYaml -Path $anchorsProbe
} catch {
    # A scratch file this runner could not write is a fact about the host, not about the anchors.
    $anchorsStrict.detail = "the anchors body could not be handed to a parser -- $($_.Exception.Message)"
} finally {
    $script:StrictYamlLast = $strictSaved
    Remove-Item -LiteralPath $anchorsProbe -Force -ErrorAction SilentlyContinue
}
[void]$sb.AppendLine("anchors_strict_yaml: $($anchorsStrict.outcome)")
if ($anchorsStrict.outcome -eq 'refused') {
    [void]$sb.AppendLine("anchors_strict_yaml_parser: $(ConvertTo-YamlSingleQuoted $anchorsStrict.parser)")
    [void]$sb.AppendLine("anchors_strict_yaml_problem: $(ConvertTo-YamlSingleQuoted $anchorsStrict.problem)")
    [void]$sb.AppendLine("anchors_strict_yaml_line: $($anchorsStrict.line)")
    [void]$sb.AppendLine("anchors_strict_yaml_column: $($anchorsStrict.column)")
} elseif ($anchorsStrict.outcome -eq 'parsed') {
    [void]$sb.AppendLine("anchors_strict_yaml_parser: $(ConvertTo-YamlSingleQuoted $anchorsStrict.parser)")
} else {
    [void]$sb.AppendLine("anchors_strict_yaml_note: $(ConvertTo-YamlSingleQuoted $anchorsStrict.detail)")
}
[void]$sb.AppendLine("anchors_strict_yaml_scope: $(ConvertTo-YamlSingleQuoted 'the verdict was taken on this file body BEFORE this block was appended; the block is single-quoted scalars and integers only and carries no escape of its own')")
[System.IO.File]::WriteAllText($anchorsPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

# THE VERDICT IS SAID OUT LOUD ON EVERY OUTCOME. One line always, so a reader of the stream never
# has to infer from silence whether the check ran; the detail below it only on the two outcomes a
# human can act on.
Write-Line "mission-dispatch: anchors strict YAML -- $($anchorsStrict.outcome)$(if ($anchorsStrict.parser) { " ($($anchorsStrict.parser))" } else { '' })"
if ($anchorsStrict.outcome -eq 'refused') {
    Write-Line "mission-dispatch: ANCHORS-STRICT-PARSE-REFUSED -- the anchors this runner just wrote are NOT readable by a real YAML parser."
    Write-Line "    at     : $anchorsPath"
    if ($anchorsStrict.line -gt 0) {
        Write-Line "    line $($anchorsStrict.line), column $($anchorsStrict.column): $($anchorsStrict.problem)"
    } else {
        Write-Line "    $($anchorsStrict.problem)"
    }
    Write-Line "  Recorded as anchors_strict_yaml: refused. This is NOT a refusal of the dispatch -- the anchors record work already done, and destroying the run over its own record would lose the record with it."
} elseif ($anchorsStrict.outcome -eq 'unavailable') {
    Write-Line "mission-dispatch: ANCHORS-STRICT-PARSE-UNAVAILABLE -- no strict YAML parser could be reached, so nothing was asked about the anchors."
    Write-Line "    reason : $($anchorsStrict.detail)"
}

# A DECLARED REPAIR THAT WAS NOT DELIVERED REJECTS THE DISPATCH, through the same
# rc-3 mechanism a schema-invalid handoff uses: the handoff is replaced by a `status: rejected`
# record naming the problem. It is appended to the SAME list so a run that got both wrong reports
# both, rather than teaching the operator to fix one and rediscover the other.
if ($repairUndelivered.Count -gt 0) {
    $why = if ($repairAssessed) { "still failing in this dispatch's own suite run" } else { "not assessed -- no suite run was observed" }
    Write-Line "mission-dispatch: DECLARED-REPAIR-NOT-DELIVERED -- $($repairUndelivered.Count) of $($declaredRepairs.test_ids.Count) declared repair(s) $why."
    foreach ($u in $repairUndelivered) { Write-Line "    $u" }
    Write-Line "  The declaration is what the ADR-022 gate weighed; delivering it is what the declaration owed. Recorded in the anchors; this run is NOT a success."
    $handoffProblems += "DECLARED-REPAIR-NOT-DELIVERED: $($repairUndelivered -join ' ') ($why)"
}
# TOOLCHAIN NOTE (i): THE RUNNER SPEAKS ON DELIVERY AS WELL AS ON FAILURE.
#
# The `if` above had no `else` for the whole first life of the declared-repair rule. A dispatch that declared three
# repairs and delivered all three printed NOTHING about them, and the only record of the success
# was `delivered: true` per entry on the anchors. PART 6 of the ruling asked for "the runner's
# delivery line"; on the success path there was none, and it was read off the artifact instead.
# The ANCHORS were already symmetric -- true / false / null -- and stdout was not.
#
# THE FAILURE LINE ABOVE IS UNTOUCHED, TO THE CHARACTER. It is quoted verbatim in rulings and
# matched verbatim by instrument members; a success line is an ADDITION and never an edit of it.
#
# THE TWO TOKENS ARE NOT SUBSTRINGS OF EACH OTHER. `DECLARED-REPAIR-NOT-DELIVERED` does not
# contain `DECLARED-REPAIR-DELIVERED` -- the failure token reads REPAIR-NOT-DELIVERED -- so a
# reader matching on either one cannot be answered by the other. That is worth stating, because
# the obvious alternative spelling of the success token, a bare DELIVERED, IS a substring of
# NOT-DELIVERED and would have made every existing "did the debt go unpaid?" grep report success.
#
# SILENT ON ZERO DECLARED, DELIBERATELY. A dispatch that declares no repair incurred no debt, and
# a line reading "0 of 0" on every run of a mission that mostly declares none is noise that
# trains a reader to skip the whole family -- the failure line with it. The `elseif` tests the
# DECLARATION, so the runner is silent exactly where there was nothing to say.
elseif ($declaredRepairs.declared) {
    # REACHABLE ONLY WITH $repairAssessed TRUE. A declaration with no runner-observed suite run
    # fills $repairUndelivered with every declared id at the anchors site above, so it takes the
    # NOT-DELIVERED branch; it can never arrive here and be reported as a delivery.
    Write-Line "mission-dispatch: DECLARED-REPAIR-DELIVERED -- $($declaredRepairs.test_ids.Count) of $($declaredRepairs.test_ids.Count) declared repair(s) passing in this dispatch's own suite run."
    foreach ($e in @($declaredRepairs.entries)) { Write-Line "    $($e.test_id)" }
    Write-Line "  The declaration is what the ADR-022 gate weighed; this run made it good. Recorded in the anchors as delivered: true."
}

# --- R-3 rejection ------------------------------------------------------------------------------
if ($handoffProblems.Count -gt 0) {
    # THE PLACEMENT'S DESTRUCTIVE HALF. The rejection record goes at the shared path -- every consumer
    # reads it there, and R-15 rests on it -- but it must never be the thing that DESTROYS the
    # worker's handoff. Where the runner placed the worktree copy and the dispatch is then rejected
    # for some LATER reason (an undelivered declared repair, say), the placed bytes are retained
    # beside the stub, time-preserving, before the stub is written over them. Nothing the worker
    # wrote is lost to a record about it.
    if ($handoffPlacedFrom -and (Test-Path -LiteralPath $handoffPath)) {
        # THE NAME COMES FROM THE RULE BLOCK, NOT FROM A LITERAL HERE. Spelling it
        # twice is what let the writer and the prior-artifact scan drift apart in the first place.
        $retained = Join-Path $MissionRoot ('.mission\dispatches\' + $Dispatch + $RetainedPlacedHandoffSuffix)
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $placed = Get-Item -LiteralPath $handoffPath
            Copy-Item -LiteralPath $handoffPath -Destination $retained -Force
            $keep = Get-Item -LiteralPath $retained
            $keep.CreationTimeUtc   = $placed.CreationTimeUtc
            $keep.LastWriteTimeUtc  = $placed.LastWriteTimeUtc
            $keep.LastAccessTimeUtc = $placed.LastAccessTimeUtc
            Write-Line "mission-dispatch: the placed worktree handoff is RETAINED at $retained before the rejection record replaces it (sha256 $handoffPlacedSha)."
        } catch {
            Write-Line "mission-dispatch: could not retain the placed handoff -- $($_.Exception.Message)"
        } finally { $ErrorActionPreference = $prevEap }
    }
    # THE STRICT-YAML CHECK, THE HALF THIS RUNNER OWES ITSELF. The problems below are FREE TEXT and, since
    # the placement, they carry WINDOWS PATHS -- and `"  - \"...<an expanded %USERPROFILE% path>...\""` is a DOUBLE-quoted YAML
    # scalar in which the path's `\U` is an invalid escape. Every one of the 26 *.handoff.rejected-stub.yaml
    # files this runner has written on this mission is refused by a real parser for exactly that
    # ("expected escape sequence of 8 hexadecimal numbers, but found 's'", line 5, column 33). A
    # refusal that says "no YAML reader can open this artifact", written into an artifact no YAML
    # reader can open, is not a record -- it is the same defect signed by the runner. Single-quoted
    # scalars have no escapes at all, so a path is just a path.
    $body = "status: rejected`ndispatch_id: $Dispatch`nrejected_at: $stampEnd`nproblems:`n"
    foreach ($p in $handoffProblems) { $body = $body + "  - $(ConvertTo-YamlSingleQuoted $p)`n" }
    [System.IO.File]::WriteAllText($handoffPath, $body, (New-Object System.Text.UTF8Encoding($false)))
    # the rejection record now stands at the shared path (where no handoff stood, the dispatch has just closed)
    Send-LamDispatchSnapshot
    Write-Line "mission-dispatch: handoff REJECTED for $Dispatch"
    foreach ($p in $handoffProblems) { Write-Line "  - $p" }
    exit 3
}

# =============================================================================================
# R-4 -- the completion signal. NOTHING ELSE IS EVER SENT.
# =============================================================================================
$hoffSha  = (Get-FileHash -Algorithm SHA256 -LiteralPath $handoffPath).Hash.ToLowerInvariant()
$wakeLine = "WAKE $handoffPath $hoffSha"
if (-not $NoOrchestrator) {
    # An orchestrator is reachable only where a listing mechanism names one. This runner does not
    # invent a recipient.
    if ($env:LAM_ORCHESTRATOR_SESSION) {
        Write-Line "mission-dispatch: orchestrator named by LAM_ORCHESTRATOR_SESSION -- the signal is the wake line below."
        Write-Line $wakeLine
    }
}
# =============================================================================================
# THE INBOX FILE IS WRITTEN UNCONDITIONALLY (V-1 round 3, WP-2).
# =============================================================================================
# R-4: emit the signal via SendMessage "if one is listed by ListAgents; OTHERWISE writes
# <mission-root>/.mission-runtime/inbox/<dispatch>.wake".
#
# Neither named mechanism exists -- `SendMessage` and `ListAgents` appear nowhere in tools/ -- so
# the "otherwise" is the ONLY branch the contract actually describes on this harness. A third
# branch keyed on LAM_ORCHESTRATOR_SESSION printed the line to stdout and SUPPRESSED the file, so
# the one durable act R-4 requires did not happen: an independent validator drove it and got no
# .wake file and no inbox directory at all.
#
# STDOUT IS NOT A CHANNEL. It is not the dispatch's face, nothing reads it after the run, and the
# completion review cannot open it. Printing the line is a convenience for a human watching the
# run; it is not a substitute for the artifact, and it must never suppress one.
$inbox = Join-Path $MissionRoot '.mission-runtime\inbox'
if (-not (Test-Path -LiteralPath $inbox)) { New-Item -ItemType Directory -Path $inbox -Force | Out-Null }
[System.IO.File]::WriteAllText((Join-Path $inbox "$Dispatch.wake"), "$wakeLine`n",
                               (New-Object System.Text.UTF8Encoding($false)))

# =============================================================================================
# R-5 -- a non-zero worker exit is RECORDED and never reported as success
# =============================================================================================
if ($workerExit -ne 0) {
    Write-Line "mission-dispatch: the worker exited non-zero (exit_code: $workerExit). Recorded in the anchors; this run is NOT a success."
    exit 4
}
# =============================================================================================
# PASS-DIB WITHOUT THE TALLY IS NOT A SUCCESS (V-1 round 3, WP-2).
# =============================================================================================
# R-1: "a dispatch may not proceed on PASS-DIB without that runner-observed tally present."
# The gate up front tested only that the dispatch DECLARES a suite_command -- a statement of
# intent. The tally is written much later, under `if ($suiteCmd -and $worktreeMade)`, so any run
# whose worktree creation failed proceeded to exit 0, emitted the WAKE, and recorded the three
# admitted subjects with NO suite block and NO `provenance: runner-observed` anywhere. A validator
# drove exactly that (a real repo with an unborn HEAD, so `worktree add` failed).
#
# DECLARING A SUITE IS NOT RUNNING ONE. The admitted SUITE subjects are precisely the three verify
# cannot derive; if nothing bound them, the dispatch proceeded on an unbound suite, which is the
# state the clause exists to forbid. Checked HERE, after the anchors are written, so the artifact
# still records what actually happened -- the refusal is about the run's success, not about
# suppressing the evidence of it. It is read from the admitted SUITE subjects, not from the
# admission count -- an advance-only admission (head_sha, porcelain) has no tally to be missing.
$admittedSuiteAfter = @($verifyAdmission | Where-Object { (($_ -split '/')[-1]) -match '^suite\.(passed|failed|skipped)$' })
if (($admittedSuiteAfter.Count -gt 0) -and (-not $suiteTallyWritten)) {
    Write-Line "mission-dispatch: PASS-DIB admitted $($admittedSuiteAfter.Count) suite subject(s) but NO runner-observed suite tally was produced, so nothing binds them."
    Write-Line "  admitted: $($verifyAdmission -join ', ')"
    Write-Line "  A declared suite_command is intent; the tally is the evidence. This run is NOT a success."
    exit 6
}
if ($gitErrors.Count -gt 0) {
    Write-Line "mission-dispatch: completed with git errors recorded in the anchors:"
    foreach ($e in $gitErrors) { Write-Line "  - $e" }
}

Write-Line "mission-dispatch: $Dispatch complete. handoff valid, anchors at $anchorsPath"
exit 0
