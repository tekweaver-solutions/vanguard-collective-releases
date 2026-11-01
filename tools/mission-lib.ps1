#Requires -Version 5.1
<#
.SYNOPSIS
  mission-lib.ps1 -- the shared F-032 lifecycle-CLI core (dot-sourced by each mission-<verb>.ps1).

.DESCRIPTION
  WHY a shared module (the pre-Executing CLI had none -- it was standalone scripts with inline-
  duplicated helpers): F-032 introduces several post-Executing commands that share ONE mechanical
  primitive (spec-bump, A-117) plus ONE atomic-commit/rollback discipline plus the gate + helper set.
  A-117 ratifies spec-bump as a CALLED primitive; close-milestone (A-118) + reclose (A-119) in M-11
  call Invoke-SpecBump as a FUNCTION so the pre-SHA / commit / rollback all stay in ONE process --
  which is what honours A-123 (atomicity, no partial state) and A-124 (one logical-unit commit).
  Operator ruling (F-032 BUILD M-10): a dot-sourced mission-lib.ps1, NOT a subprocess-called script
  (a subprocess child that commits would split the atomic boundary across two processes).

  This file defines functions only; it performs no action when dot-sourced. The invariants
  A-121..A-126 are built into these helpers so every command inherits them:
    A-121 append-not-rewrite -- Invoke-SpecBump writes a NEW vNNN, never edits a prior one
    A-122 lockstep atomicity -- Invoke-SpecBump moves vNNN + current.txt + current_spec_version together
    A-123 rollback+phantom    -- Invoke-AtomicCommit resets --hard to the pre-SHA + guards no-advance
    A-124 one-unit + -F       -- Invoke-AtomicCommit stages ONLY the named paths, commits via -F file
    A-125 ledger CRLF/append  -- Add-LedgerEntry appends one CRLF-terminated JSON line, never rewrites
    A-126 tree-clean precond  -- Assert-CleanWorkingTree refuses on a dirty tree before any mutation
#>

$ErrorActionPreference = 'Stop'

# --- output helpers (mirror mission-spec-accept.ps1:151-166, which defines them inline; shared here) ---
function Write-Pass { param([string]$m) Write-Host "  [PASS] $m" -ForegroundColor Green }
function Write-Fail { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Write-Info { param([string]$m) Write-Host "  $m" -ForegroundColor Gray }
function Stop-WithError { param([string]$m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# --- F-072 (M-56): comment-tolerant single-field writer. Replaces ONLY the value token on the first
#     column-0 `^<Key>:` line, PRESERVING any trailing `# comment` (and its leading spacing) AND the
#     line's EOL verbatim. On a comment-free line the value advances exactly as before. Pure text-in/
#     text-out. $Value is injected via a MatchEvaluator (NOT interpolated into the pattern), so regex
#     metacharacters in $Value are safe. Supersedes the 5 comment-blind `^...\S+\s*$` Replace sites
#     (close-milestone current_milestone + this file's spec-bump version/previous_version/
#     created_from_amendment/current_spec_version) whose `\s*$` end-anchor silently no-op'd a commented
#     line (REOPEN #19 T1). The EOL is matched by a lookahead (?=\r?\n|$) so it is never consumed/altered
#     -- unlike the old `\s*$` form, which stripped a trailing \r on CRLF lines. #>
function Set-MissionFieldValue {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    # group 1 = key + leading spaces ; group 2 = the bare value (non-space, non-#) ; group 3 = trailing
    # spaces + optional `# comment` (preserved). The EOL is asserted by lookahead, never matched.
    $pat = '(?m)^(' + [regex]::Escape($Key) + ':[ \t]*)([^\s#]+)([ \t]*(?:#[^\r\n]*)?)(?=\r?\n|$)'
    return [regex]::Replace($Text, $pat, { param($m) $m.Groups[1].Value + $Value + $m.Groups[3].Value })
}

# --- F-073 (M-56): reopen-matched lifecycle numbering. The explicit reopen-matched number is
#     AUTHORITATIVE; a cross-check against the SEALED block history in $MissionText HALTS LOUD (the
#     sentinel REOPEN-NUMBER-MISMATCH + non-zero exit via Stop-WithError) rather than silently emitting a
#     number. Replaces the `$reN/$reopenN = maxN + 1` derivations (reclose:89-91 / reopen:34-38) that
#     MISNUMBER after a skipped/re-chartered cycle (REOPEN #19 T2: no `# --- REOPEN #19` block, no
#     `# --- RE-CLOSURE #18` block, so maxN+1 desyncs from the reopen-matched number). The cross-check is
#     deliberately conservative: the emitted number must be STRICTLY AHEAD of the highest existing block of
#     the same kind (no collision with / regression below sealed history); a missing or colliding explicit
#     number is refused loudly, never silently maxN+1. #>
function Resolve-ReopenMatchedNumber {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$MissionText,
        [Parameter(Mandatory)][ValidateSet('REOPEN','RE-CLOSURE')][string]$BlockKind,
        [int]$ExplicitNumber = 0
    )
    $maxN = 0
    $rx = '(?m)^# --- ' + [regex]::Escape($BlockKind) + ' #(\d+)'
    foreach ($mm in [regex]::Matches($MissionText, $rx)) {
        $n = [int]$mm.Groups[1].Value; if ($n -gt $maxN) { $maxN = $n }
    }
    if ($ExplicitNumber -le 0) {
        Stop-WithError "REOPEN-NUMBER-MISMATCH ($BlockKind): no explicit -ReopenNumber supplied. maxN+1 silently misnumbers after a skipped/re-chartered cycle (highest existing $BlockKind block is #$maxN); pass the reopen-matched -ReopenNumber explicitly."
    }
    if ($ExplicitNumber -le $maxN) {
        Stop-WithError "REOPEN-NUMBER-MISMATCH ($BlockKind): explicit number $ExplicitNumber collides with / regresses below sealed history (highest existing $BlockKind block is #$maxN). The reopen-matched number must be strictly ahead of sealed history; refusing to emit a colliding number."
    }
    return $ExplicitNumber
}

# --- repo root (the mission-*.ps1 live in tools/; the repo root is its parent) ---
function Get-MissionRoot { (Get-Item $PSScriptRoot).Parent.FullName }

function Get-UtcStamp { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture) }

# --- A-126: working-tree-clean precondition (ADR-021 atomic commit; spec-accept.ps1:199) ---
function Assert-CleanWorkingTree {
    # A-126: refuse a DIRTY working tree before mutation. $AllowPaths names SANCTIONED operation
    # INPUTS that are permitted to be uncommitted -- e.g. the operator-authored amendment a spec-bump
    # is ABOUT to bundle (the corpus oracle's bump commit has the amendment as a NEW uncommitted file in the
    # bump commit). Any OTHER uncommitted path is still STRAY drift -> refuse. A-126 stays honest: with
    # no $AllowPaths (reopen / promote-contract / ledger-append) the gate is strict; with $AllowPaths it
    # exempts ONLY the named inputs and still refuses genuine stray state.
    #
    # =============================================================================================
    # THE ADMITTED SET IS THE MISSION'S DECLARATION,
    # NOT A CODE CONSTANT.
    # =============================================================================================
    # WHAT WAS HERE AND WHAT IT COST. Two code lines exempted `^\.mission/evidence/` and
    # `^\.mission/gates/` outright. They matched the PATH ONLY, after the porcelain XY code had been
    # stripped, so they exempted a path AT ANY GIT STATUS -- a MODIFIED or DELETED tracked evidence
    # file passed exactly as an untracked store did -- and they exempted the WHOLE evidence plane
    # rather than the declared `verify-` prefix. Being CODE, no mission could narrow them.
    # DRIVEN at the base of this row against a scratch mission root reproducing the real
    # shape: with 5 admitted lines the offending list was EMPTY, and a planted
    # `?? .mission/evidence/scratch-oops/`, a planted ` M .mission/evidence/verify-0001/report.json`
    # and a planted ` D` of the same file ALL passed the gate. The repository of record measured
    # 166 porcelain lines at this HEAD -- 112 `?? .mission/evidence/verify-<id>/`, 54
    # `?? .mission/gates/...`, ZERO outside those two prefixes -- so the number A-126 had left to
    # judge was ZERO.
    #
    # WHAT GOVERNS NOW: `admitted_porcelain` in the mission's own `.mission/mission.yaml`, read and
    # matched by THE SAME LIBRARY the advance-admission gate reads it with --
    # tools/lam/lam-verify-admission.ps1, Get-LamDeclaredAdmittedPorcelain (:526) and
    # Get-LamPorcelainState (:818). That file is DOT-SOURCED rather than restated: two readers of
    # one declaration that disagree is this repository's oldest defect class, and amendment 5 exists
    # because a second dialect of THIS VERY KEY read a block-form declaration as absent.
    # The declared entries carry the STATUS CODE (`"?? .mission/evidence/verify-"`), and the match
    # is the library's own anchored prefix over the WHOLE porcelain line `XY path` -- so a declared
    # prefix at a NON-`?? ` status is JUDGED. That is the status-blindness above, closed.
    #
    # FAIL-CLOSED IN EVERY DEGRADATION, because A-126 is a fail-closed gate:
    #   git status FAILS               -> REFUSE. A failing status produces no output, which the
    #     earlier code read as "clean" -- fail-open on the one condition whose whole job is to
    #     notice uncommitted drift. Get-LamPorcelainState checks the return code; this uses it.
    #   declaration UNREADABLE/MALFORMED -> REFUSE, on the library's own rule, unchanged:
    #     "a declared set is honoured exactly or not at all".
    #   NO declaration at all          -> ADMIT NOTHING. Every porcelain line is judged and only
    #     $AllowPaths exempts. There is no code default to inherit here and there must not be one:
    #     a code default is exactly what this row removes.
    #
    # THE D9 `session-` EXEMPTION IS DROPPED, DELIBERATELY, AND THE PRICE IS STATED.
    # D9 (LAM-ACCEPT WP-1 H-3) exempted `^\.mission/evidence/session-` BY NAME PATTERN because the
    # regenerating evidence session directory's id does not exist until the session starts, so no
    # CALLER can name it in advance. That premise is about $AllowPaths, and the DECLARATION satisfies
    # it just as well: `"?? .mission/evidence/session-"` is a PREFIX, writable in advance without
    # knowing any session id, per-mission and operator-visible. Keeping it in CODE would have
    # reinstated a hole of exactly the shape this row closes -- path-only, status-blind, unnarrowable
    # by any mission -- differing only in being one prefix narrower.
    # MEASURED BEFORE DROPPING: the repository of record carries ZERO `session-` porcelain lines at
    # this HEAD.
    # WHAT BREAKS IF ONE REAPPEARS: a Stop finalize publishes `.mission/evidence/<dispatch_id>/`, and
    # the dispatch id falls back to `session-<id>` when no CURRENT_DISPATCH pointer exists
    # (tools/framework/hooks/lib/evidence-common.ps1:60), so the directory IS reachable. Every
    # lifecycle ceremony then REFUSES until the operator adds that one entry to admitted_porcelain.
    # The refusal below names the offending lines AND names the file the set is declared in, so the
    # block is self-curing rather than mysterious. That is the trade, stated rather than hidden.
    #
    # =============================================================================================
    # REGISTER ROW 173: THE COMPENSATING-CONTROL CITATION, CORRECTED.
    # =============================================================================================
    # THE SENTENCE THAT STOOD HERE read: "Both directories are agent-unwritable (evidence guard;
    # T-3), which is the compensating control for tolerating them whole." It NAMED THE WRONG TIER,
    # and it was load-bearing: if the claim is false the exemption above was never justified, which
    # is why the two corrections are one job. The exemption is gone, so what follows is no longer a
    # justification for tolerating anything -- it is the record of what actually guards the two
    # planes, with a file:line for every route, each read in source at this HEAD.
    #
    # WHICH GUARD IS LIVE. `.claude/settings.json` registers PreToolUse at
    # tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1 (the A1 registration is retired
    # beside it as settings.json.a1-retired). That entry point dot-sources
    # tools/evidence-hooks-next/hooks/lib/evidence-common.ps1 (:60), which dot-sources the SEALED A1
    # library tools/framework/hooks/lib/evidence-common.ps1 (:73) and redefines over it. Routes below
    # name whichever of the two files they live in; they are not interchangeable.
    #
    # `.mission/evidence` -- THE PROTECTED-PATH TIER. This half of the old sentence was TRUE.
    #   tools/framework/hooks/lib/evidence-common.ps1:1057-1064 lists `.mission/evidence` and
    #   `.mission-runtime/evidence` in $EvidenceProtectedPaths; the file-tool branch denies on that
    #   list at :1650-1652 and the shell branch at :1758, for every role, reads included.
    #
    # `.mission/gates` -- NOT ON THAT TIER, and that is the whole of this correction. The list at :1057-1064
    #   does not contain it. `.mission` sits on the PARENT tier (:1065-1070), which denies only when
    #   a shell METACHARACTER is present ($ShellMetaPattern :1122, gate :1702-1706) or when the
    #   segment's verb is DESTRUCTIVE or RELOCATING (:1731-1735) -- guarded against `rm -rf .mission`,
    #   not against writing inside it (:1052-1056). A plain copy into a gates path carries neither and
    #   falls through to `allow` (:1765); the guard's own docblock records exactly that command as
    #   having "once returned ALLOW" (:1485). THREE GUARD ROUTES AND ONE PERMISSION ROUTE DO reach it:
    #     (i)   TEXT MATCH, FILE TOOLS -- Test-EvidenceGatePath,
    #           tools/evidence-hooks-next/hooks/lib/evidence-common.ps1:3272-3281, called at :4076 for
    #           every tool that is neither read-only nor a shell. Every role, no exemption.
    #     (ii)  TEXT MATCH, SHELL -- the same predicate, called at :4280. Every role.
    #     (iii) ACT MATCH, SHELL -- AN EARLIER TRIPWIRE, and the load-bearing one.
    #           Test-EvidenceGateToolMutation (:3464), called at :4276, denies any invocation of
    #           tools/lam/mission-gate.ps1 in EXECUTABLE POSITION with any verb but `list`. It exists
    #           because the ratified mint convention -- `mission-gate.ps1 approve -Kind push
    #           -MissionRoot .` -- NAMES THE GATES DIRECTORY NOWHERE: the tool computes it from
    #           -MissionRoot inside the child process, so (i) and (ii), which match TERRITORY, both
    #           allowed a real self-minted open push gate (driven, exit 0, read back as open by the
    #           tool's own `list`). T-3 as enforced after that tripwire: docs/framework/LAM-ACCEPT.md:1277-1340.
    #     (iv)  PERMISSION LAYER -- `Edit(.mission/gates/**)` at tools/lam/settings/worker.json:13 and
    #           tools/lam/settings/orchestrator.json:13. TWO CORRECTIONS to the register's own wording,
    #           both re-derived here: the rule is spelled `Edit(...)`, NOT `Write(...)` -- worker.json's
    #           own residual records that CLI 2.1.241 rejects `Write(path)` as "not matched by file
    #           permission checks" -- and tools/lam/settings/validator.json carries NO gates entry in
    #           its deny list at all (:16-25), so this route covers two role templates, not three.
    #
    # WHAT THESE ROUTES ARE NOT. All four are TRIPWIRES, not boundaries. (iii) in
    # particular is a tripwire ON THE RATIFIED SPELLING -- a shell that computes an invocation whose
    # text never names the tool defeats it, and no reading of command TEXT recovers that.
    # REGISTER ROW 165 is the durable fix and is being built in parallel with this row: it asserts
    # that tools/lam/mission-gate.ps1 REFUSE NON-HUMAN INVOCATION FROM INSIDE ITSELF -- the tool as
    # it stands has no TTY check, no UserInteractive check, no environment check and no confirmation
    # prompt, and writes $env:USERNAME onto the artifact without ever comparing it. Cited as the
    # FIX and what it asserts, not as a file:line, because the fix's code did not exist when
    # this was written.
    # THE RE-DERIVATION PASS THIS BLOCK ASKED FOR HAS BEEN RUN (after merging
    # main). The fix landed, and a later merge then shifted the next-gen library by ~159
    # lines, staling every number above at once. Each was re-anchored by reading the named line at
    # this tip; the LAM-ACCEPT ranges moved too (:718-731 -> :777-790 there, :1050-1089 -> :1277-1340
    # here). A citation is a measurement, so it stales exactly the way a hash does -- if a later
    # merge moves that library again, these numbers need the same pass and nothing warns you.
    param([string]$Root, [string[]]$AllowPaths = @())

    # THE ONE READER OF THE DECLARATION, dot-sourced INSIDE the function on purpose: it adds no
    # global function names to the many tools that dot-source this file, and a missing or broken
    # library cannot fail their LOAD -- it fails this GATE, closed, where the failure belongs.
    # $PSScriptRoot is tools/ (the file that DEFINES the function), which Get-MissionRoot above
    # already relies on.
    $admLib = Join-Path $PSScriptRoot 'lam\lam-verify-admission.ps1'
    if (-not (Test-Path -LiteralPath $admLib)) {
        Stop-WithError "A-126 REFUSES: the admitted-porcelain reader is absent at $admLib, so the mission's declared set cannot be read. A gate that cannot read its own rule does not pass the tree."
    }
    . $admLib

    $porc = Get-LamPorcelainState -MissionRoot $Root
    if (-not $porc.ok) {
        Stop-WithError "A-126 REFUSES: $($porc.reason)."
    }
    $lines = @($porc.lines)
    if ($lines.Count -eq 0) { Write-Pass "Working tree clean."; return }

    $decl = Get-LamDeclaredAdmittedPorcelain -MissionRoot $Root
    if ($decl.error) { Stop-WithError "A-126 REFUSES: $($decl.error)" }
    $admitted = @($decl.regexes)

    $allow = @($AllowPaths | ForEach-Object { ($_ -replace '\\','/').Trim().Trim('"') })
    $offending = @()
    $tolerated = 0
    foreach ($raw in $lines) {
        $line = ($raw -replace "`r$", '')
        # THE DECLARED SET, matched over the WHOLE porcelain line, status code included, by the
        # regexes the shared library built ('^' + [regex]::Escape(entry)).
        if (@($admitted | Where-Object { $line -match $_ }).Count -gt 0) { $tolerated++; continue }
        # $AllowPaths still names PATHS, not porcelain lines. Unchanged: it exempts ONLY its named
        # inputs and still refuses genuine stray state.
        $p = ($line.Substring([Math]::Min(3,$line.Length))).Trim()   # porcelain "XY <path>"
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1] }        # rename: take the destination
        $p = ($p.Trim('"') -replace '\\','/').Trim()
        if ($allow -contains $p) { continue }
        $offending += $line
    }
    if ($offending.Count -gt 0) {
        $whose = if ($decl.declared) { "declared by the mission at $($decl.source)" }
                 else { 'NONE -- this mission declares no admitted_porcelain, so nothing is admitted' }
        Stop-WithError ("Working tree must be clean before a lifecycle command (ADR-021 atomic commit). " +
            "$($offending.Count) porcelain line(s) outside the admitted set ($whose) and outside -AllowPaths: " +
            ($offending -join ' ; ') + ". Commit them, or -- if they are genuinely admitted residue -- add the " +
            "matching '?? <prefix>' entry to admitted_porcelain in the mission's own mission.yaml, which is the ONE place that set is declared.")
    }
    $suffix = if ($allow.Count -gt 0) { "; sanctioned input(s): " + ($allow -join ', ') } else { '' }
    Write-Pass ("Working tree clean: $tolerated porcelain line(s) admitted by the mission's declared set$suffix.")
}

# --- A-130 / E4: mission-state precondition (the ^state: gate -- design-start:53 / spec-accept:270) ---
function Assert-MissionState {
    param([string]$MissionFile, [string]$Expected)
    $c = [System.IO.File]::ReadAllText($MissionFile)
    if ($c -notmatch "(?m)^state:\s*$([regex]::Escape($Expected))\s*$") {
        $cur = if ($c -match '(?m)^state:\s*(\S+)\s*$') { $Matches[1] } else { 'unknown' }
        Stop-WithError "This command requires Mission.state = $Expected. Current state: $cur"
    }
    Write-Pass "Mission.state = $Expected (precondition met)."
}

function Get-CurrentSpecName { param([string]$Root)
    ([System.IO.File]::ReadAllText((Join-Path $Root ".mission\spec\current.txt"))).Trim()
}

# --- A-117: the SPEC-BUMP primitive -- the 5-file lockstep, MECHANICAL. Called by spec-bump (the
#     command) + close-milestone + reclose. Does the SPEC move only (new vNNN + current.txt +
#     current_spec_version); the CALLER supplies the operation-specific body change ($BodyTransform)
#     and bundles the amendment + ledger + the atomic commit so the whole op is one logical unit. ---
function Invoke-SpecBump {
    param(
        [string]$Root,
        [string]$AmendmentId,         # e.g. "AM-NNN" (operator-authored amendment file already on disk)
        [scriptblock]$BodyTransform   # ($text) -> $text : the operation-specific spec-body change (e.g. a status flip or an appended record). $null = metadata-only bump.
    )
    $specDir    = Join-Path $Root ".mission\spec"
    $currentTxt = Join-Path $specDir "current.txt"
    $missionFile= Join-Path $Root ".mission\mission.yaml"

    $curName = ([System.IO.File]::ReadAllText($currentTxt)).Trim()
    if ($curName -notmatch '^v(\d+)$') { Stop-WithError "current.txt is not a vNNN token: '$curName'" }
    $curNum = [int]$Matches[1]
    $newNum = $curNum + 1
    $curFile = Join-Path $specDir ("v{0:000}.yaml" -f $curNum)
    $newFile = Join-Path $specDir ("v{0:000}.yaml" -f $newNum)
    if (-not (Test-Path $curFile)) { Stop-WithError "current spec file missing: $curFile" }
    # A-121 append-not-rewrite: refuse if the next file already exists (never clobber sealed history)
    if (Test-Path $newFile) { Stop-WithError "next spec file already exists: $newFile (append-not-rewrite)" }

    # v(NNN+1) = vNNN VERBATIM except the 3 version-metadata lines + the supplied body change
    $text = [System.IO.File]::ReadAllText($curFile)
    $text = Set-MissionFieldValue -Text $text -Key 'version'                -Value $newNum        # F-072: comment-tolerant
    $text = Set-MissionFieldValue -Text $text -Key 'previous_version'       -Value $curNum        # F-072: comment-tolerant
    $text = Set-MissionFieldValue -Text $text -Key 'created_from_amendment' -Value $AmendmentId   # F-072: comment-tolerant
    if ($BodyTransform) { $text = (& $BodyTransform $text) }

    # write the NEW spec file (the prior vNNN is NEVER touched -- A-121)
    [System.IO.File]::WriteAllText($newFile, $text)
    # A-122 lockstep: move current.txt + mission.yaml current_spec_version together with the vNNN write
    [System.IO.File]::WriteAllText($currentTxt, ("v{0:000}" -f $newNum))   # no trailing newline (matches corpus)
    $m = [System.IO.File]::ReadAllText($missionFile)
    $m = Set-MissionFieldValue -Text $m -Key 'current_spec_version' -Value $newNum   # F-072: comment-tolerant (replaces the old comment-blind \d+\s*$ Replace)
    [System.IO.File]::WriteAllText($missionFile, $m)

    Write-Pass ("spec-bump v{0:000} -> v{1:000} (lockstep: vNNN + current.txt + current_spec_version)" -f $curNum, $newNum)
    return [pscustomobject]@{
        OldNum  = $curNum; NewNum = $newNum
        OldName = ("v{0:000}" -f $curNum); NewName = ("v{0:000}" -f $newNum)
        NewFile = $newFile
    }
}

# --- A-120 / A-125: append ONE schema-valid, CRLF-terminated, append-only ledger entry. The command
#     supplies the entry as an [ordered] hashtable (field order = the corpus convention); this writes
#     compact valid JSON + CRLF, appending bytes (it NEVER rewrites an existing line). ---
function Add-LedgerEntry {
    param([string]$Root, $Entry)   # $Entry: [ordered]@{ id=..; type=..; ... }
    $led = Join-Path $Root ".mission\ledger\entries.jsonl"
    # M-70 attempt-2 (A-338): FAIL-CLOSED duplicate-id guard -- refuse to append
    # an entry whose id already exists as a live ledger line. Duplicate ids make two events
    # indistinguishable in the audit trail (the same-second seed-mint collision, validator finding
    # F-V1). Governs NEW appends only; the historical pre-fix duplicates (the superseded fixed-id
    # seeds) stay as sealed history and are never re-appended by any ceremony.
    if (Test-Path $led) {
        $dupPat = '"id":\s*"' + [regex]::Escape([string]$Entry.id) + '"'
        if ([regex]::IsMatch([System.IO.File]::ReadAllText($led), $dupPat)) {
            Stop-WithError "REFUSED (duplicate ledger id, A-338): an entry with id '$($Entry.id)' already exists in $led -- ledger ids are one-per-event; mint a fresh id."
        }
    }
    $json = ($Entry | ConvertTo-Json -Compress -Depth 12)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json + "`r`n")   # UTF8 w/o BOM; CRLF
    $fs = [System.IO.File]::Open($led, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
    try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
    Write-Pass "ledger entry appended (CRLF, append-only): $($Entry.id)"
}

# --- A-123 + A-124: stage ONLY the named paths and commit as ONE logical unit via a -F message file;
#     verify HEAD advanced (phantom-commit guard, spec-accept:553); on ANY failure roll back via
#     Invoke-GuardedRollback -- reset --hard to the pre-operation SHA, then remove ONLY the unstaged
#     remainder of the NAMED paths (D3, site 1: never a bare clean of .mission; the prior
#     form deleted every untracked non-ignored bystander under .mission, R2). ---
function Invoke-AtomicCommit {
    param(
        [string]$Root,
        [string[]]$Paths,            # exact intended files -- NO stray (A-124)
        [string]$MessageFile         # commit message authored to a file, committed via -F (A-124)
    )
    $preSha = (& git -C $Root rev-parse HEAD).Trim()
    try {
        foreach ($p in $Paths) {
            & git -C $Root add -- $p | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "git add failed for: $p" }
        }
        & git -C $Root commit -F $MessageFile | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
        $newSha = (& git -C $Root rev-parse HEAD).Trim()
        if ($newSha -eq $preSha) { throw "git commit did not advance HEAD (phantom-commit risk) -- aborting." }
        Write-Pass "atomic commit: $newSha"
        return $newSha
    }
    catch {
        Write-Host ""
        Write-Host "COMMAND FAILED mid-operation: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Rolling back to pre-operation SHA: $preSha (no partial state)" -ForegroundColor Yellow
        # D3 (site 1): PATHS-SCOPED rollback. The removal set is the UNSTAGED untracked
        # remainder of the DECLARED intent set ($Paths) -- nothing else. Bystander safety is
        # STRUCTURAL: a path this commit never named can never be cleaned (R2 cured; the prior
        # `git clean -fd -- .mission` here deleted EVERY untracked non-ignored path under .mission,
        # the operator's RESIDUE-KEEP files included). Staged members need no clean: reset --hard
        # itself deletes staged-but-uncommitted new files (driven). The set is
        # enumerated before the reset and is identical either side of it (ls-files --others
        # excludes staged paths; reset creates no untracked file). Enumeration failure degrades
        # to NO clean -- fail-safe on the destructive side, disclosed by the warning line.
        $removePaths = @()
        try {
            $rawZ = (& git -C $Root ls-files --others --exclude-standard -z -- @($Paths) 2>$null)
            $removePaths = @(((@($rawZ) -join '') -split "`0") | Where-Object { $_ })
        } catch {
            Write-Host "  [WARN] rollback enumeration failed; scoped clean skipped (nothing is deleted)." -ForegroundColor Yellow
        }
        Invoke-GuardedRollback -Root $Root -PreSha $preSha -RemovePaths $removePaths
        Stop-WithError "Rolled back. The mission is at the pre-operation state. Correct the cause and re-run."
    }
}

# --- D3: the ONE guarded-rollback implementation, composed by BOTH rollback sites
#     (Invoke-AtomicCommit's catch with its $Paths-derived set; the close-milestone A-169 refusal
#     with its snapshot-derived delta -- one implementation, two set-derivations, the A-184/A-185
#     shared-predicate discipline). reset --hard restores tracked state to the pre-operation SHA
#     (A-123) and ALSO deletes staged-but-uncommitted new files (driven at build); the scoped clean
#     then removes EXACTLY the named RemovePaths -- never a bare `-- .mission` sweep (R2: that form
#     deleted every untracked non-ignored bystander under .mission). An empty set cleans nothing. ---
function Invoke-GuardedRollback {
    param(
        [string]$Root,
        [string]$PreSha,
        [string[]]$RemovePaths = @()
    )
    & git -C $Root reset --hard $PreSha 2>&1 | Out-Null
    $rp = @($RemovePaths | Where-Object { $_ })
    if ($rp.Count -gt 0) {
        & git -C $Root clean -fd -- @($rp) 2>&1 | Out-Null
    }
}

# --- D3 (site 2): the pre-operation untracked snapshot under .mission. A CALLER takes
#     it BEFORE its first mutation; the later delta (current minus snapshot) is exactly the
#     operation's own creation set, so a rollback removes what the operation made and preserves
#     what predated it (the pre-placed amendment survives an A-169 refusal). NUL-framed (-z) so
#     quoted/exotic path names round-trip. Reach: exactly git's untracked view -- ignored paths
#     are invisible on both sides of any delta and are therefore never cleaned. ---
function Get-MissionUntrackedPaths {
    param([string]$Root)
    $raw = (& git -C $Root ls-files --others --exclude-standard -z -- .mission 2>$null)
    return @(((@($raw) -join '') -split "`0") | Where-Object { $_ })
}

# --- shared scaffolding helper: write a commit message to a gitignored runtime file, return its path
#     (the message is authored via file so -F handles multi-line/apostrophe content -- A-124). ---
function New-CommitMessageFile {
    param([string]$Root, [string]$Body)
    $dir = Join-Path $Root ".mission-runtime"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $path = Join-Path $dir ("commit-msg-{0}.txt" -f ([guid]::NewGuid().ToString('N').Substring(0,8)))
    [System.IO.File]::WriteAllText($path, $Body)
    return $path
}

# =====================================================================================
# F-034 / M-14 -- the RECLOSE / MILESTONE-CLOSE GREEN-GATE (ADR-042, A-144..A-150).
# A baseline-relative full-collection-green PRECONDITION on the close transitions. NOT a
# bare exit==0: "green" = all three conjuncts hold for the target suite against a committed
# per-suite manifest (stored_floor + expected_failure_test_ids). ADDITIVE -- composed
# ALONGSIDE the existing close gates (A-126/A-130/A-129 + A-127/A-128), never replacing them.
# =====================================================================================

function Get-GreenGateManifestPath { param([string]$Root,[string]$SuiteId) Join-Path $Root ".mission\green-gate\$SuiteId.json" }

function Read-GreenGateManifest {
    param([string]$Root,[string]$SuiteId)
    $mp = Get-GreenGateManifestPath -Root $Root -SuiteId $SuiteId
    if (-not (Test-Path $mp)) { Stop-WithError "green-gate manifest missing for suite '$SuiteId': $mp -- seed it first (mission-green-gate-seed)." }
    return (Get-Content $mp -Raw | ConvertFrom-Json)
}

# Run a suite's DEFAULT unnamed pytest in its cwd; parse runnable count (deselection-aware:
# passed+failed+skipped, EXCLUDING deselected), failing node-ids, and collection-error status.
function Invoke-SuiteDefaultRun {
    param([string]$Root,[string]$Cwd)
    $dir = Join-Path $Root $Cwd
    if (-not (Test-Path $dir)) { Stop-WithError "green-gate: suite cwd not found: $dir" }
    $prev = Get-Location
    Set-Location $dir
    # LAUNCHER ONLY (REOPEN #19 capstone): `uv run python -m pytest` (module form) instead of `uv run pytest`
    # (the .exe shim) -- Windows Application Control blocks the pytest.exe shim (os error 4551). The module
    # form is the SAME invocation the manual clean-green proof used; gate LOGIC (failure count, runnable>=floor,
    # skip handling) is UNCHANGED. See ledger-decision-framework-fix-greengate-pytest-module-form-reopen19.
    try { $raw = (& uv run python -m pytest -q -rfE -p no:cacheprovider 2>&1 | Out-String); $code = $LASTEXITCODE }
    finally { Set-Location $prev }
    $passed=0;$failed=0;$skipped=0;$errs=0;$desel=0
    if ($raw -match '(\d+)\s+passed')     { $passed=[int]$Matches[1] }
    if ($raw -match '(\d+)\s+failed')     { $failed=[int]$Matches[1] }
    if ($raw -match '(\d+)\s+skipped')    { $skipped=[int]$Matches[1] }
    if ($raw -match '(\d+)\s+error')      { $errs=[int]$Matches[1] }
    if ($raw -match '(\d+)\s+deselected') { $desel=[int]$Matches[1] }
    $runnable = $passed + $failed + $skipped     # deselection-aware: deselected are NOT counted
    $failedIds = @()
    foreach ($ln in ($raw -split "`r?`n")) { if ($ln -match '^FAILED\s+(\S+)') { $failedIds += $Matches[1] } }
    # C3 signal: a collection-phase error (exit 2 / 'error' in summary / collection-error lines) -- NOT a runtime test failure
    $collErr = ($code -eq 2) -or ($errs -gt 0) -or ($raw -match 'error(s)?\s+during\s+collection') -or ($raw -match '(?m)^ERROR\s')
    return [pscustomobject]@{ Runnable=$runnable; Passed=$passed; Failed=$failed; Skipped=$skipped; Errors=$errs;
        Deselected=$desel; FailedIds=@($failedIds); CollectionError=[bool]$collErr; ExitCode=$code; Raw=$raw }
}

# The three-conjunct predicate. Returns Green + per-conjunct results + the run. Pure (no mutation).
function Test-GreenGate {
    param([string]$Root,$Manifest)
    $run = Invoke-SuiteDefaultRun -Root $Root -Cwd $Manifest.cwd
    $expected = @($Manifest.expected_failure_test_ids)
    $unexpected = @($run.FailedIds | Where-Object { $expected -notcontains $_ })
    $c1 = ($unexpected.Count -eq 0)                          # C1 no-unexpected-fail (A-144)
    $c2 = ($run.Runnable -ge [int]$Manifest.stored_floor)    # C2 no-collection-regression (A-145)
    $c3 = (-not $run.CollectionError)                        # C3 no-collection-error (A-146)
    $bad = @()
    if (-not $c1) { $bad += "C1 unexpected-fail [$($unexpected -join ', ')]" }
    if (-not $c2) { $bad += "C2 collection-regression [runnable $($run.Runnable) < floor $($Manifest.stored_floor)]" }
    if (-not $c3) { $bad += "C3 collection-error [exit $($run.ExitCode)]" }
    return [pscustomobject]@{ Green=($c1 -and $c2 -and $c3); C1=$c1; C2=$c2; C3=$c3; FailedConjuncts=@($bad); Run=$run; Manifest=$Manifest }
}

# The GATE precondition. Refuses (hard-stop) on a non-green target suite, UNLESS -OverrideGreenGate
# -Reason is given (then it appends a ledger override-record via the existing decision-entry shape and
# proceeds). Does NOT advance the floor (write-back is on a GREEN close only -- Write-GreenGateFloor).
function Assert-DefaultRunGreen {
    param([string]$Root,[string]$SuiteId,[switch]$OverrideGreenGate,[string]$Reason)
    $man = Read-GreenGateManifest -Root $Root -SuiteId $SuiteId
    $r = Test-GreenGate -Root $Root -Manifest $man
    if ($r.Green) { Write-Pass "green-gate ($SuiteId): runnable=$($r.Run.Runnable) >= floor=$($man.stored_floor); 0 unexpected failures; collection clean."; return $r }
    $detail = ($r.FailedConjuncts -join '; ')
    if ($OverrideGreenGate) {
        if (-not $Reason) { Stop-WithError "green-gate ($SuiteId) RED [$detail]; -OverrideGreenGate REQUIRES -Reason (the audit record)." }
        $stamp = ((Get-UtcStamp) -replace '[:\-]','' -replace 'T','-' -replace 'Z','')
        $content = "GREEN-GATE OVERRIDE ($SuiteId) -- an operator bypassed a RED green-gate. FAILED CONJUNCT(S): $detail. RUN: runnable=$($r.Run.Runnable), floor=$($man.stored_floor), failed_ids=[$($r.Run.FailedIds -join ', ')], collection_error=$($r.Run.CollectionError), exit=$($r.Run.ExitCode). REASON: $Reason. The transition PROCEEDS under explicit operator override (mirrors mission-spec-accept -Confirm); this record is the A-149 audit trail (actor + time + reason + which conjunct failed)."
        $entry = [ordered]@{ id="ledger-override-green-gate-$SuiteId-$stamp"; created_at=(Get-UtcStamp); created_by='human via claude-code:orchestrator-guide'; ts=(Get-UtcStamp); author='claude-code:orchestrator-guide'; type='decision'; scope='framework'; scope_ref=(Get-GreenGateManifestPath -Root $Root -SuiteId $SuiteId); content=$content; source_trace_id=$null; supersedes=$null; tags=@('green-gate','override',$SuiteId,'framework') }
        Add-LedgerEntry -Root $Root -Entry $entry
        Write-Host "  [OVERRIDE] green-gate ($SuiteId) RED [$detail] -- BYPASSED by operator; override-record appended (A-149)." -ForegroundColor Yellow
        return $r
    }
    Stop-WithError "REFUSED (green-gate, $SuiteId): $detail. The DEFAULT unnamed run of the '$SuiteId' suite is not baseline-green. Fix the suite, or re-run with -OverrideGreenGate -Reason '<why>' (appends an audit record). [ADR-042 / A-144..A-146]"
}

# Write-back on a GREEN close: ratchet stored_floor to the just-passed runnable count + record
# last_green_close. Called by the close commands AFTER a green gate + successful transition; the
# manifest is included in the close's atomic commit. NEVER advances on a failed/overridden close.
function Write-GreenGateFloor {
    param([string]$Root,[string]$SuiteId,[int]$Collected,[string]$Transition,[string]$Ref)
    $mp = Get-GreenGateManifestPath -Root $Root -SuiteId $SuiteId
    $m = Get-Content $mp -Raw | ConvertFrom-Json
    $m.stored_floor = $Collected
    $m | Add-Member -NotePropertyName last_green_close -NotePropertyValue ([pscustomobject]@{ transition=$Transition; ref=$Ref; collected=$Collected; at=(Get-UtcStamp) }) -Force
    ($m | ConvertTo-Json -Depth 8) | Set-Content -Path $mp -Encoding ascii
    Write-Pass "green-gate floor ($SuiteId) ratcheted to $Collected (last_green_close: $Transition $Ref)."
}

# F-036/M-16 (A-164/A-165): select a suite's authoritative green-gate baseline-record by the STRUCTURED
# suite_id FIELD -- NOT a scope tag. The old tag-match (green-gate AND baseline-record AND a literal
# '<suite>' tag) collided with the ADR-028 'framework' scope tag every product record carries (GROUND T4),
# so a product record could be picked for the framework check, passing only by file-ordering luck.
# FAIL-CLOSED (A-165): any NON-superseded baseline-record lacking a suite_id field makes selection a hard
# fault -- never a skip, tolerate, or tag-fallback. Pure: no exit, no mutation; the CALLER decides how to
# fail (Test-GreenGateManifestConsistency exits; the close-milestone A-169 gate rolls back then exits).
function Resolve-SuiteBaselineRecord {
    param([string]$Root,[string]$SuiteId)
    $led = Join-Path $Root ".mission\ledger\entries.jsonl"
    if (-not (Test-Path $led)) { return [pscustomobject]@{ Ok=$false; FailClosed=$false; Floor=$null; Record=$null; Reason="no ledger file at $led" } }
    $entries=@(); $superseded = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in [System.IO.File]::ReadAllText($led) -split "`r?`n") {
        if (-not ($line.Trim())) { continue }
        try { $o = $line | ConvertFrom-Json } catch { continue }
        $entries += $o
        if ($o.supersedes) { foreach ($s in @($o.supersedes)) { if ($s) { [void]$superseded.Add([string]$s) } } }
    }
    $latest = $null
    foreach ($e in $entries) {
        if (-not ((@($e.tags) -contains 'green-gate') -and (@($e.tags) -contains 'baseline-record'))) { continue }
        if ($superseded.Contains([string]$e.id)) { continue }       # superseded (e.g. backfilled legacy) records leave the live pool
        $hasSuite = (($e.PSObject.Properties.Name) -contains 'suite_id') -and $e.suite_id
        if (-not $hasSuite) {                                        # A-165 FAIL-CLOSED -- no skip, no tag-fallback
            return [pscustomobject]@{ Ok=$false; FailClosed=$true; Floor=$null; Record=$e; Reason="non-superseded baseline-record '$($e.id)' lacks a suite_id field" }
        }
        if ([string]$e.suite_id -eq $SuiteId) { $latest = $e }       # A-164: select on the FIELD (last same-suite write wins -- order-independent vs other suites)
    }
    if (-not $latest) { return [pscustomobject]@{ Ok=$false; FailClosed=$false; Floor=$null; Record=$null; Reason="no non-superseded baseline-record with suite_id=$SuiteId" } }
    if ($latest.content -notmatch 'stored_floor=(\d+)') { return [pscustomobject]@{ Ok=$false; FailClosed=$false; Floor=$null; Record=$latest; Reason="baseline-record '$($latest.id)' has no parseable stored_floor" } }
    return [pscustomobject]@{ Ok=$true; FailClosed=$false; Floor=[int]$Matches[1]; Record=$latest; Reason=$null }
}

# F-036/M-16 (A-162/A-166/A-168): the SINGLE green-gate baseline-record writer -- carries the suite_id
# FIELD (A-164) + 'stored_floor=N' in content (the A-147 floor parse). Used by close-milestone (recurring,
# GAP 1) AND the one-time backfill -- so there is NO divergent inline writer across those paths. Optionally
# supersedes prior records (the backfill supersedes the legacy seeds/reconciles).
function Add-GreenGateBaselineRecord {
    param(
        [string]$Root,[string]$SuiteId,[int]$StoredFloor,[string]$Transition,[string]$Ref,
        [string]$Content=$null,[string[]]$Supersedes=@(),[string[]]$ExtraTags=@(),[string]$Id=$null
    )
    $now = Get-UtcStamp
    if (-not $Id) {
        $Id = "ledger-decision-green-gate-baseline-$SuiteId-floor$StoredFloor-$($Transition -replace '[^A-Za-z0-9]','')-$($now -replace '[^0-9]','')"
        # M-70 attempt-2 (A-338): the timestamp above is SECOND-granular, so two
        # same-suite/same-floor/same-transition mints inside one UTC second collide (validator
        # finding F-V1 -- reproduced on the frozen A-338 harness). Disambiguate DETERMINISTICALLY at
        # mint: the id format is UNCHANGED when no collision; on collision append -2, -3, ... until
        # the id is not yet a live ledger line. Explicit -Id callers are untouched here (the
        # Add-LedgerEntry duplicate guard still refuses a reused explicit id).
        $ledPath = Join-Path $Root ".mission\ledger\entries.jsonl"
        $ledText = if (Test-Path $ledPath) { [System.IO.File]::ReadAllText($ledPath) } else { '' }
        $idBase = $Id; $idN = 2
        while ([regex]::IsMatch($ledText, ('"id":\s*"' + [regex]::Escape($Id) + '"'))) { $Id = "$idBase-$idN"; $idN++ }
    }
    if (-not $Content) { $Content = "GREEN-GATE BASELINE-RECORD ($SuiteId, $Transition) -- stored_floor=$StoredFloor (collected-and-runnable, deselection-aware). Audit twin of .mission/green-gate/$SuiteId.json; the A-147 consistency obligation is manifest.stored_floor == this latest baseline-record floor (selected by the suite_id FIELD, A-164). transition=$Transition; ref=$Ref." }
    $entry = [ordered]@{
        id=$Id; created_at=$now; created_by='claude-code:orchestrator-guide'; ts=$now; author='claude-code:orchestrator-guide'
        type='decision'; scope='framework'; scope_ref=".mission/green-gate/$SuiteId.json"; suite_id=$SuiteId
        content=$Content; source_trace_id=$null; supersedes=$(if ($Supersedes.Count) { $Supersedes } else { $null })
        tags=(@('green-gate','baseline-record',$SuiteId) + $ExtraTags + @('framework'))
    }
    Add-LedgerEntry -Root $Root -Entry $entry
    return $Id
}

# A-147: the manifest stored_floor for a suite must equal the floor in its LATEST ledger green-gate
# baseline-record. Divergence (hand-edited manifest, one-sided write) is detected. Selection is by the
# suite_id FIELD (A-164) and HARD-FAILS on a suite_id-less candidate (A-165) -- via Resolve-SuiteBaselineRecord.
function Test-GreenGateManifestConsistency {
    param([string]$Root,[string]$SuiteId)
    $man = Read-GreenGateManifest -Root $Root -SuiteId $SuiteId
    $sel = Resolve-SuiteBaselineRecord -Root $Root -SuiteId $SuiteId
    if (-not $sel.Ok) {
        if ($sel.FailClosed) { Stop-WithError "REFUSED (green-gate consistency, $SuiteId): $($sel.Reason) -- A-147 hard-fails on a suite_id-less baseline-record (no skip, no tag-fallback) [A-165]." }
        Stop-WithError "green-gate consistency ($SuiteId): $($sel.Reason) -- cannot confirm manifest<->ledger consistency (A-147)."
    }
    if ([int]$man.stored_floor -ne $sel.Floor) {
        Stop-WithError "REFUSED (green-gate consistency, $SuiteId): manifest stored_floor=$($man.stored_floor) != latest ledger baseline-record floor=$($sel.Floor) (selected by suite_id field) -- the deterministic read source and the audit trail DISAGREE (A-147)."
    }
    Write-Pass "green-gate consistency ($SuiteId): manifest floor=$($man.stored_floor) == latest ledger baseline-record floor=$($sel.Floor) (matched on the suite_id field, A-164)."
}

# F-040/M-20 (A-183): the write-path reconcile primitive for the validator-results manifest. Append-when
# -absent (legacy behaviour preserved); reconcile-IN-PLACE-when-present -- the current (max-attempt) entry's
# verdict is re-synced to the AUTHORITATIVE A-NNN.validator-result.json verdict, attempt_number UNCHANGED, no
# bump/supersedes (a record correction, NOT a new attempt; re-validation stays the separate
# in-place-bump idiom). The verdict is SOURCED by reading the JSON, NEVER a caller literal -- the root of the
# A-182 stale vector (a caller "pass if ok else fail" diverging from the JSON). Closes audit item A's mechanical face.
function Set-ValidatorResultManifestEntry {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$AssertionId,
        [Parameter(Mandatory)][string]$ResultFile,    # the A-NNN.validator-result.json under validator-results/ (AUTHORITATIVE)
        [string]$CommitSha = $null
    )
    $vrDir = Join-Path $Root ".mission\validator-results"
    $manifestPath = Join-Path $vrDir "manifest.json"
    $jsonPath = Join-Path $vrDir $ResultFile
    if (-not (Test-Path $manifestPath)) { Stop-WithError "Set-ValidatorResultManifestEntry: no manifest at $manifestPath." }
    if (-not (Test-Path $jsonPath)) { Stop-WithError "Set-ValidatorResultManifestEntry: authoritative JSON '$ResultFile' not found under validator-results/ -- the verdict is SOURCED from the JSON, never a caller literal (A-183)." }
    # A-183 (write fidelity): delegate the WRITE to tools/mission_manifest_write.py. The manifest is a
    # python json.dump(indent=2) artifact; writing it through the SAME serializer is BOM-less (PS Set-Content
    # -Encoding UTF8 prepended a BOM that broke json.load), MINIMAL-DIFF (untouched entries serialize byte-
    # identically -> a 3-entry change diffs as ~3 entries, not a full ConvertTo-Json reformat), and DETERMINISTIC
    # (load->modify->dump preserves order). The append/reconcile LOGIC + verdict-from-JSON sourcing live in the
    # helper (the behaviour VALIDATE confirmed correct -- only the write mechanism changes). python is already a
    # mission-CLI dependency (the green-gate runs the default pytest via it).
    $sha = if ($CommitSha) { $CommitSha } else { '' }
    $helper = Join-Path $PSScriptRoot 'mission_manifest_write.py'
    $action = (& python $helper $Root $AssertionId $ResultFile $sha 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { Stop-WithError "Set-ValidatorResultManifestEntry: manifest write failed (exit $LASTEXITCODE) -- $action" }
    Write-Pass "manifest entry $AssertionId $action -- verdict sourced from $ResultFile (A-183; BOM-less + minimal-diff + deterministic write)."
}

# F-040/M-20 (A-184 + A-185): the SHARED manifest-verdict-divergence predicate. ONE implementation, two call
# sites (close-milestone roster scope; mission-reclose full-manifest scope -- the asymmetry is the $AssertionIds
# ARGUMENT, NOT a re-implementation; a divergent re-impl would itself be a divergence vector). For each in-scope
# assertion's CURRENT (max-attempt) entry -- the one the gate CONSUMES -- the entry verdict MUST agree with its
# authoritative A-NNN.validator-result.json verdict. Divergence OR an absent/unreadable JSON -> REFUSE fail-closed
# (Stop-WithError; A-153 fail-loud discipline -- never a silent pass). The dual-home (verdict in both the entry and
# the JSON, the gate trusting the entry) is the staleness vector this gate closes.
function Test-ManifestVerdictConsistency {
    param([string]$Root, [string[]]$AssertionIds = $null)    # null/empty = ALL current entries (the reclose seal scope)
    $vrDir = Join-Path $Root ".mission\validator-results"
    $manifestPath = Join-Path $vrDir "manifest.json"
    if (-not (Test-Path $manifestPath)) { Stop-WithError "REFUSED (manifest verdict-integrity): no validator-results manifest at $manifestPath." }
    $entries = @((Get-Content $manifestPath -Raw | ConvertFrom-Json).entries)
    $ids = if ($AssertionIds) { @($AssertionIds) } else { @($entries | ForEach-Object { $_.assertion_id } | Select-Object -Unique) }
    foreach ($aid in $ids) {
        $hits = @($entries | Where-Object { $_.assertion_id -eq $aid })
        if ($hits.Count -eq 0) { continue }      # absence is the A-127 roster gate's concern, NOT this divergence check
        $current = $hits | Sort-Object { [int]($_.attempt_number) } | Select-Object -Last 1   # the consumed max-attempt entry
        $jsonPath = if ($current.file) { Join-Path $vrDir ([string]$current.file) } else { $null }
        if (-not $jsonPath -or -not (Test-Path $jsonPath)) {
            Stop-WithError "REFUSED (manifest verdict-integrity): $aid current entry references authoritative JSON '$($current.file)' which is ABSENT/unreadable under validator-results/ -- agreement cannot be confirmed (fail-closed, A-184/A-185)."
        }
        try { $jv = [string]((Get-Content $jsonPath -Raw | ConvertFrom-Json).verdict) }
        catch { Stop-WithError "REFUSED (manifest verdict-integrity): authoritative JSON '$($current.file)' for $aid is unreadable/not-JSON -- agreement cannot be confirmed (fail-closed)." }
        if ([string]$current.verdict -ne $jv) {
            Stop-WithError "REFUSED (manifest verdict-integrity): $aid manifest entry verdict='$($current.verdict)' DIVERGES from authoritative JSON verdict='$jv' ($($current.file)) -- the gate consumes the ENTRY; a divergent entry masks the real result (A-184/A-185, fail-closed). Set-ValidatorResultManifestEntry reconciles; this gate refuses."
        }
    }
    Write-Pass "manifest verdict-integrity: $($ids.Count) assertion(s) -- every consumed (max-attempt) entry verdict AGREES with its authoritative JSON (A-184/A-185)."
}

# The honest-close gate: the committed WITNESSED-SUBSTRATE check, the PRESENCE direction of the substrate-shape
# discriminator, and the ONE committed implementation of it (one shared predicate, never a second copy). A
# milestone whose close requires a witnessed live discharge (mission-close-milestone.ps1 -WitnessedSubstrate
# <name>, or a roster entry's witnessed_substrate field) cannot close
# unless .mission/evidence/<name>/ holds the NON-NARRATABLE CORE -- 02-compose-ps (a container Up healthy),
# 03-pytest (a live pass), 04-event-history-dump (a real-run SHAPE: WorkflowExecution events + the
# substrate's DECLARED terminal activity). SHAPE, not mere existence: a zero-byte / prose-only 04 FAILS (the
# narration-masquerade this gate catches). NOTE the two-guard LAYERING (this is not a hole): the gate does NOT
# itself prove the run was live -- a shape-valid FIXTURE would pass it. It does NOT need to, because the
# UPSTREAM mechanical guard (the substrate's own client fails without its real engine -> no real 03/04 can be
# produced) is what makes narration impossible; this DOWNSTREAM gate is what makes an un-witnessed CLOSE
# impossible. Phase B + the 06-operator-witness-attestation (tying the human to the real run_id in 04) close the loop.
function Test-WitnessedSubstrate {
    param([string]$Root, [string]$SubstrateName)
    $dir = Join-Path $Root ".mission\evidence\$SubstrateName"
    if (-not (Test-Path $dir)) {
        Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): .mission/evidence/$SubstrateName/ is ABSENT -- no witnessed live discharge was captured. The close requires the WITNESS, NOT the narration (fail-closed)."
    }
    $ps   = @(Get-ChildItem -Path $dir -Filter '02-compose-ps*'    -File -ErrorAction SilentlyContinue)[0]
    $pyt  = @(Get-ChildItem -Path $dir -Filter '03-pytest*'        -File -ErrorAction SilentlyContinue)[0]
    $hist = @(Get-ChildItem -Path $dir -Filter '04-event-history*' -File -ErrorAction SilentlyContinue)[0]
    foreach ($pair in @(@('02-compose-ps',$ps), @('03-pytest',$pyt), @('04-event-history-dump',$hist))) {
        if (-not $pair[1]) { Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): the non-narratable core is incomplete -- missing $($pair[0]) (have: $((Get-ChildItem $dir -File | ForEach-Object Name) -join ', ')) [fail-closed]." }
    }
    $psC = Get-Content $ps.FullName -Raw; $pyC = Get-Content $pyt.FullName -Raw; $hC = Get-Content $hist.FullName -Raw
    if ($psC -notmatch '(?im)Up\b.*healthy') {
        Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): 02-compose-ps shows NO container 'Up ... (healthy)' -- a stub/empty compose-ps is not a witness (fail-closed)."
    }
    if ($pyC -notmatch '(?im)\b\d+\s+passed\b' -and $pyC -notmatch '(?im)\bpassed\b') {
        Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): 03-pytest shows NO pass -- a stub/skipped run is not a witness (fail-closed)."
    }
    # The expected TERMINAL ACTIVITY is DATA-DRIVEN and REQUIRED: the substrate's own evidence record
    # declares it (declared-terminal-activity.txt, first non-empty line: the declaration TRAVELS WITH THE
    # EVIDENCE). There is NO built-in default -- a framework cannot know a project's terminal activity, and a
    # default would let an undeclared substrate be judged against a name nobody chose. Undeclared -> REFUSED,
    # the contract the placement path (evidence-place-substrate.ps1, SS 5.3 item 4) enforces before placing.
    $declFile = Join-Path $dir 'declared-terminal-activity.txt'
    $declLine = $null
    if (Test-Path $declFile) { $declLine = @(Get-Content $declFile | Where-Object { $_.Trim() })[0] }
    if (-not $declLine) {
        Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): declared-terminal-activity.txt is absent or holds no non-empty line -- the terminal activity is declared by the substrate's own evidence record and has NO default (fail-closed)."
    }
    $expected = $declLine.Trim(); $declSrc = 'declared-terminal-activity.txt'
    if ($expected -notmatch '^[A-Za-z0-9_.-]+$') {
        Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): declared terminal activity '$expected' is malformed (activity names are [A-Za-z0-9_.-]+) -- a malformed declaration cannot gate a close (fail-closed)."
    }
    $hasHistory = ($hC -match '(?im)WorkflowExecution' -or $hC -match '(?im)ActivityTask' -or $hC -match '(?im)HistoryLength')
    # The teeth, STRENGTHENED (never weakened): the expected activity must appear in REAL EVENT
    # STRUCTURE -- a JSON event history's activityType name field OR an ACTIVITY_TASK_SCHEDULED
    # event line -- NOT merely anywhere in prose (the prior anywhere-in-text match was satisfiable by
    # narration; the planted-masquerade probe now goes RED).
    $esc = [regex]::Escape($expected)
    $hasTerminal = ($hC -match ('(?i)"name"\s*:\s*"' + $esc + '"')) -or
                   ($hC -match ('(?im)ACTIVITY_TASK_SCHEDULED\b.*\bactivity=' + $esc + '\b'))
    if (-not ($hasHistory -and $hasTerminal)) {
        Stop-WithError "REFUSED (witnessed-substrate, $SubstrateName): 04-event-history-dump lacks the real-run SHAPE (WorkflowExecution/ActivityTask events AND the '$expected' terminal activity [$declSrc] in REAL event structure -- a JSON activityType name field or an ACTIVITY_TASK_SCHEDULED event line) -- a zero-byte / prose-only dump is the narration-masquerade this gate catches (fail-closed)."
    }
    Write-Pass "witnessed-substrate ($SubstrateName): the non-narratable core is present + shape-valid (02 container healthy, 03 pytest pass, 04 event-history w/ terminal activity '$expected' [$declSrc] in event structure)."
}
