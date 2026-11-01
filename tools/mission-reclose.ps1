#Requires -Version 5.1
<#
.SYNOPSIS
  mission-reclose (A-119 / C6) -- transition Reworking -> Complete per ADR-029: UPDATE completed_at,
  APPEND a RE-CLOSURE block chained to the prior completions (never rewrite a sealed block), run the
  re-closure gate-query. GATED by A-129: it REFUSES if any un-superseded discharge-before-reclosure
  obligation is still open in the ledger. GATED a second time: it REFUSES, before any mutation, unless
  an operator-minted re-closure gate is on disk, open, governance class, and binds by sha256 the
  exact -LedgerContentFile this run was given.

.DESCRIPTION
  Composes the M-10-validated mission-lib.ps1 (Assert-CleanWorkingTree A-126, Assert-MissionState
  A-130, Invoke-AtomicCommit A-123/A-124, Add-LedgerEntry A-120/A-125). Reclose is BOOKKEEPING on a
  passed gate -- NO spec bump (mirrors the corpus RE-CLOSURE: mission.yaml state + completed_at
  + the chaining ledger entry only). Scaffold-not-author: the operator supplies the gate-passed basis
  (-Basis) + the ledger prose; the tool does the mechanical transition + the gate-query.

  WHAT CHANGED, AND WHAT DID NOT. The operator still MINTS the gate; only a human can
  (the guard hard-denies every agent role from writing under the mission gates directory, T-3).
  What changed is that the CONFIRMATION stopped being a human reading two files side by side and
  became a check this tool performs and refuses on. Accepted spellings: `reclose-<id>.yaml`
  (preferred) and `completion-acceptance-reclose-<id>.yaml` (the TRANSITIONAL form reclose-44 and
  reclose-45 already carry -- announced on its own line whenever it is the one relied on).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Basis,              # operator-supplied gate-passed basis (scaffold-not-author)
    [Parameter(Mandatory)][string]$LedgerContentFile,  # operator-authored chaining ledger content
    [string]$LedgerId,
    [Alias('ReN')][int]$ReopenNumber = 0,              # F-073 (M-56): reopen-matched RE-CLOSURE number (authoritative); HALTS if it collides with sealed history. Required -- no silent maxN+1.
    [string]$GateId,                                   # the re-closure gate's id; defaults to the reopen-matched RE-CLOSURE number, so #44 looks for reclose-44.yaml (or the transitional completion-acceptance-reclose-44.yaml)
    [hashtable]$GreenGateOverrides = @{},              # F-036/M-16 (A-161): PER-SUITE waive map @{ product='reason'; framework='reason' } -- a waive of one suite does NOT waive the other (NOT a blanket override)
    [switch]$NoCommit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')
# THE SHARED GATE PREDICATES, NOT A FOURTH COPY OF THEM. Get-LamGateState and
# Get-LamGateClassForArtifact live in exactly one file, and that file's own header records THREE
# separate defects caused by restating one of them (`consumed_at` naive in gate_present, `revoked_at`
# naive in mission-gate revoke, the indented-field divergence in Test-LamGateFieldSet). This reader
# is the fourth consumer and it restates nothing.
$lamGateClassLib = Join-Path $PSScriptRoot 'lam\lam-gate-class.ps1'
if (-not (Test-Path -LiteralPath $lamGateClassLib)) {
    Write-Host "mission reclose: REFUSED -- the gate-class library is not on disk at $lamGateClassLib. The re-closure gate cannot be read, and an unreadable gate is not an open one." -ForegroundColor Red
    exit 1
}
. $lamGateClassLib
$root = Get-MissionRoot
$missionFile = Join-Path $root ".mission\mission.yaml"

# --- A-129 GATE-QUERY: a MECHANICAL reader of the ledger. Open obligation = a type:constraint entry
#     tagged 'discharge-before-reclosure' whose id is NOT superseded by any later entry. ---
function Assert-NoOpenObligations {
    param([string]$Root)
    $led = Join-Path $Root ".mission\ledger\entries.jsonl"
    if (-not (Test-Path $led)) { return }
    $superseded = New-Object System.Collections.Generic.HashSet[string]
    $entries = @()
    foreach ($line in [System.IO.File]::ReadAllText($led) -split "`r?`n") {
        if (-not ($line.Trim())) { continue }
        try { $o = $line | ConvertFrom-Json } catch { continue }
        $entries += $o
        if ($o.supersedes) { foreach ($s in @($o.supersedes)) { if ($s) { [void]$superseded.Add([string]$s) } } }
    }
    $open = @()
    foreach ($e in $entries) {
        if ($e.type -eq 'constraint' -and (@($e.tags) -contains 'discharge-before-reclosure') -and (-not $superseded.Contains([string]$e.id))) {
            $open += $e.id
        }
    }
    if ($open.Count -gt 0) {
        Stop-WithError ("REFUSED (A-129): " + $open.Count + " open discharge-before-reclosure obligation(s) -- the mission cannot re-close until they are discharged (superseded): " + ($open -join ', '))
    }
    Write-Pass "re-closure gate: ZERO open discharge-before-reclosure obligations."
}

# =================================================================================================
# THE RE-CLOSURE GATE IS READ BY THIS TOOL, NOT ONLY BY THE OPERATOR'S EYES.
# =================================================================================================
# WHAT WAS WRONG. Two re-closures have been gated by an operator-minted artifact (reclose-44,
# reclose-45), and this script read NEITHER. The operator minted; the seat "confirmed from disk"
# by hand -- kind, id, binds and binds_sha256 compared by a human reading two files. A gate no code
# reads is E85 in its plainest form: an artifact whose face implies a check that does not happen.
# The consequences were live, not theoretical -- a reclose could run with the gate REVOKED, with no
# gate at all, or bound to a DIFFERENT ledger content file than the one actually appended, and
# nothing in the tool would notice.
#
# FAIL CLOSED, AND BEFORE ANY MUTATION. This sits with the other pre-mutation gates and ahead of all
# of them: it is cheaper than the A-129 ledger scan, the manifest-verdict check and the two pytest
# suites, and there is no reason to run those for a transition that is not authorized. Nothing has
# been written when it refuses, so a refusal leaves ZERO transition state (the A-160 property the
# green-gate ordering already claims).
#
# THE PREDICATES ARE THE SHARED ONES. Get-LamGateState decides ABSENT / REVOKED / CONSUMED /
# DISQUALIFIED / open and Get-LamGateClassForArtifact decides kind and class. No regex for any gate
# field is written here. lam-gate-class.ps1's own header records three defects that came from
# restating one of these, each in the permissive direction; this reader is the fourth consumer and
# adds no fourth copy.
#
# THE TRANSITIONAL FORM, DECIDED DELIBERATELY AND DISCLOSED IN THIS TOOL'S OWN OUTPUT.
# completion-acceptance-reclose-44.yaml and completion-acceptance-reclose-45.yaml are on disk NOW,
# carrying kind: completion-acceptance, and they are IMMUTABLE audit records: they cannot
# be rewritten to the new kind, and mission-gate refuses to overwrite an existing gate, so the same
# id cannot be re-minted without first REVOKING a gate that recorded a lawful act. Requiring
# `reclose` outright would therefore strand both of them and make this tool refuse the only two
# re-closures for which an operator gate has ever existed.
#
# SO BOTH FORMS ARE ACCEPTED, AND THE TOOL SAYS WHICH ONE IT READ, EVERY TIME. The preferred spelling
# is `reclose-<id>.yaml`; `completion-acceptance-reclose-<id>.yaml` is accepted as the TRANSITIONAL
# form and is announced as such on the line above the PASS, so the acceptance is never silent and a
# reader of the transcript can see that a stretched kind was relied on. Every other check --
# artifact-declared kind, governance class, live state, and the re-derived digest -- is IDENTICAL
# for the two forms; the transitional form is a naming concession, not a weaker gate.
function Assert-RecloseGate {
    param([string]$Root, [string]$Id, [string]$ContentFile)

    $gatesDir     = Join-Path $Root ".mission\gates"
    $newForm      = Join-Path $gatesDir ("reclose-" + $Id + ".yaml")
    $transitional = Join-Path $gatesDir ("completion-acceptance-reclose-" + $Id + ".yaml")

    $path = $null; $form = $null
    if     (Test-Path -LiteralPath $newForm      -PathType Leaf) { $path = $newForm;      $form = 'reclose' }
    elseif (Test-Path -LiteralPath $transitional -PathType Leaf) { $path = $transitional; $form = 'transitional' }

    if (-not $path) {
        Stop-WithError ("REFUSED (row 142, re-closure gate): NO GATE on disk for re-closure id '" + $Id + "'. Looked for '" + $newForm + "' and, as the transitional form, '" + $transitional + "'. A re-closure is an operator-gated transition; with no artifact there is nothing that authorized it. Mint one at your own terminal, outside any agent session, through the operator console: tools\lam\lam-console.ps1 approve -Kind reclose -Id " + $Id + " -Binds <the -LedgerContentFile> -MissionRoot .")
    }

    # THE ARTIFACT DECIDES ITS OWN KIND, NOT THE FILENAME. mission-gate's own `revoke` learned this
    # the hard way (T-1c): a file NAMED for a kind is not a gate of that kind, and reading one under
    # the wrong name is how an operator believes one thing is authorized while another actually is.
    $cls = Get-LamGateClassForArtifact -Path $path
    # THE ONE CASE RULE: the artifact's kind text is resolved to the map's
    # canonical key ORDINALLY by the shared reader, and THAT is compared against the two this
    # transition accepts. `-ne` FOLDED, so a gate whose face read `kind: RECLOSE` authorized a
    # Reworking -> Complete transition under a spelling no kind carries.
    $clsCanon = Resolve-LamGateKind -Kind $cls.kind
    if ($clsCanon -cne 'reclose' -and $clsCanon -cne 'completion-acceptance') {
        $caseNote = if (-not $clsCanon) { ' ' + (Get-LamGateKindRefusalReason -Kind $cls.kind) + '.' } else { '' }
        Stop-WithError ("REFUSED (row 142, re-closure gate): the artifact at '" + $path + "' declares 'kind: " + $cls.kind + "', which is neither 'reclose' nor the transitional 'completion-acceptance'." + $caseNote + " A file named for a re-closure is not a re-closure gate.")
    }
    if (-not $cls.ok -or $cls.class -ne 'governance') {
        Stop-WithError ("REFUSED (row 142, re-closure gate): the artifact at '" + $path + "' does not classify as governance -- class='" + $cls.class + "', reason: " + $cls.reason + ". An unclassified or self-contradicting gate authorizes nothing.")
    }

    # OPEN / REVOKED / CONSUMED / DISQUALIFIED comes from the one shared predicate. CONSUMED has its own words (BATCH-6 WP-P (b), ruling Q12): settle records a use AFTER the re-closure, so a consumed gate names a SPENT re-closure, and reapprove refuses a consumed prior -- no re-mint under its id.
    $state = Get-LamGateState -Path $path
    if ($state.state -ne 'open') {
        if ($state.consumed) { Stop-WithError ("REFUSED (row 142, re-closure gate): the gate at '" + $path + "' is CONSUMED, not open: settle recorded its use at the re-closure it authorized, so it names a SPENT re-closure and authorizes no further transition. A new re-closure has its own number and its own gate: mint reclose-<that number> at your own terminal through the operator console. A consumed gate is never re-minted under its id (reapprove refuses a consumed prior).") } else { Stop-WithError ("REFUSED (row 142, re-closure gate): the gate at '" + $path + "' is " + $state.state + ", not open. Revoked, consumed and disqualified all mean the same thing here: no live authorization for this transition. Re-mint under the same id (revoke, rename .revoked-N.yaml, approve) if the operator means to authorize it again.") }
    }

    # THE DIGEST IS RE-DERIVED FROM THE FILE ACTUALLY PASSED, NEVER READ FROM binds_resolved.
    # `binds_resolved` says so on its own face: RECORD, not an input. What matters is that the bytes
    # this run is about to append to the ledger are the bytes the operator ruled on -- so the hash is
    # taken of -LedgerContentFile as given on THIS command line, and compared to binds_sha256.
    $declared = ''
    $gateText = [System.IO.File]::ReadAllText($path)
    if ($gateText -match '(?m)^binds_sha256:[ \t]*([0-9a-fA-F]{64})[ \t]*\r?$') { $declared = $Matches[1].ToLowerInvariant() }
    if (-not $declared) {
        Stop-WithError ("REFUSED (row 142, re-closure gate): the gate at '" + $path + "' carries no usable binds_sha256. A gate that binds nothing authorizes everything.")
    }
    $actual = (Get-FileHash -LiteralPath $ContentFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $declared) {
        Stop-WithError ("REFUSED (row 142, re-closure gate): BINDING MISMATCH. The gate at '" + $path + "' binds sha256 " + $declared + ", but -LedgerContentFile '" + $ContentFile + "' hashes to " + $actual + ". The operator ruled on different bytes than this run would append; an authorization cannot be silently re-pointed at different content.")
    }

    if ($form -eq 'transitional') {
        Write-Host ("  [TRANSITIONAL FORM] the gate read is '" + (Split-Path -Leaf $path) + "' -- kind completion-acceptance, accepted for a re-closure because reclose-44 and reclose-45 were minted before the 'reclose' kind existed and are immutable audit records. New re-closures should be gated with -Kind reclose.") -ForegroundColor Yellow
    }
    Write-Pass ("re-closure gate (row 142): " + (Split-Path -Leaf $path) + " is open, governance class, and binds the -LedgerContentFile by sha256 " + $declared.Substring(0, 16) + "... (re-derived here, not read from binds_resolved).")
}

if (-not (Test-Path $LedgerContentFile)) { Stop-WithError "ledger content file not found: $LedgerContentFile" }
if (-not $NoCommit) { Assert-CleanWorkingTree -Root $root }            # A-126 (strict: reclose has no sanctioned input)
Assert-MissionState -MissionFile $missionFile -Expected 'Reworking'    # A-130

# --- read the prior completion (PRESERVED in the chain) and settle the RE-CLOSURE number ---
# HOISTED ABOVE THE GATES. These lines are PURE READS -- they mutate nothing -- and the
# re-closure gate below is addressed by the reopen-matched number, so the number has to be settled
# before the gate can be looked up. Resolving it here also moves its HALT (REOPEN-NUMBER-MISMATCH)
# ahead of the two pytest suites, which is the fail-closed direction: a number that collides with
# sealed history was never going to produce a lawful re-closure.
$text = [System.IO.File]::ReadAllText($missionFile)
$eol  = if ($text -match "`r`n") { "`r`n" } else { "`n" }
if ($text -notmatch '(?m)^completed_at:\s*(\S+)\s*$') { Stop-WithError "completed_at not found in mission.yaml" }
$priorCompleted = $Matches[1]
# F-073 (M-56): reopen-matched RE-CLOSURE number -- explicit -ReopenNumber is AUTHORITATIVE; the helper
# HALTS LOUD (REOPEN-NUMBER-MISMATCH + exit 1) on a number that collides with sealed history. Replaces the
# old `$reN = maxN + 1`, which misnumbers after a skipped reopen (RE-CLOSURE #18 was skipped, so maxN+1
# would emit #18 where the reopen-matched number was #19 -- the very misnumbering bug this fixes).
$reN = Resolve-ReopenMatchedNumber -MissionText $text -BlockKind 'RE-CLOSURE' -ExplicitNumber $ReopenNumber
if (-not $LedgerId) { $LedgerId = "ledger-decision-mission-reclosure-reworking-to-complete-reclose-$reN" }
if (-not $GateId)   { $GateId   = "$reN" }

# --- refuse before any mutation unless the operator's re-closure gate authorizes THIS
#     transition over THESE ledger bytes. First of the gates, because it is the cheapest and because
#     there is no reason to run a ledger scan or two test suites for an unauthorized transition. ---
Assert-RecloseGate -Root $root -Id $GateId -ContentFile $LedgerContentFile

# --- A-129: refuse before any mutation if an obligation is open ---
Assert-NoOpenObligations -Root $root

# --- A-185 (F-040/M-20): manifest-verdict-integrity over the FULL sealing manifest -- the SAME shared
#     predicate as A-184 (close-milestone), here with no roster scope (every current entry). The reclose runs
#     no roster gate (Test-RosterClosable is close-milestone's), so without this the seal is BLIND to a
#     divergent consumed entry (a real failure masked as pass would reach Complete -- the A-182 vector at the
#     layer where it would actually seal). Divergence/missing-JSON -> REFUSE fail-closed, BEFORE any mutation. ---
Test-ManifestVerdictConsistency -Root $root

# --- F-034/M-14 GREEN-GATE (ADR-042), HARDENED by F-036/M-16 (A-159/A-160/A-161): the reclose gate runs
#     BOTH suites (product + framework), not one. A single-suite reclose hard-gate is a masked state by
#     construction -- the un-gated suite rides the honor system (found at grounding: at RE-CLOSURE #7 the framework
#     suite was hand-verified OUTSIDE the script). PER-SUITE override only (A-161): -GreenGateOverrides
#     @{suite='reason'} waives ONLY the named suite; overriding product does NOT waive a red framework. The
#     FIRST red-and-unwaived suite hard-stops (Assert-DefaultRunGreen) naming it -- this runs BEFORE any
#     mission.yaml/ledger mutation, so a refusal leaves ZERO transition state (A-160). The M-14 predicate is
#     UNCHANGED (already suite-parameterized -- this is a caller-side loop). Both suites' default pytest runs. ---
foreach ($suite in @('product','framework')) {
    $ov  = $GreenGateOverrides.ContainsKey($suite) -and [string]$GreenGateOverrides[$suite]   # waived only if the suite is named with a non-empty reason
    $rsn = if ($ov) { [string]$GreenGateOverrides[$suite] } else { $null }
    Assert-DefaultRunGreen -Root $root -SuiteId $suite -OverrideGreenGate:$ov -Reason $rsn | Out-Null
}

# --- scaffold the RE-CLOSURE block ($text, $eol, $priorCompleted, $reN and $LedgerId were settled
#     above the gates: those reads are pure and the gate lookup needs the number) ---
$now = Get-UtcStamp

$blk = @(
    "#",
    "# --- RE-CLOSURE #$reN ($($now.Substring(0,10))) -- per ADR-029 Reworking -> Complete ---",
    "# Re-closed Reworking -> Complete on $($now.Substring(0,10)) (operator-gated). BASIS (operator-",
    "# supplied): $Basis",
    "# CHAIN (ADR-029): the prior completion $priorCompleted is PRESERVED in the chaining ledger entry",
    "# $LedgerId; completed_at is UPDATED to $now below. The re-closure gate is empty (A-129: zero open",
    "# discharge-before-reclosure obligations). NO spec bump (bookkeeping on a passed gate). Prior",
    "# transition blocks ABOVE are sealed -- preserved unchanged; this block is APPENDED."
)
$block = ($blk -join $eol)

# A-121 append-not-rewrite: insert the block immediately before `state: Reworking`, flip to Complete
if ($text -notmatch '(?m)^state:\s*Reworking\s*$') { Stop-WithError "could not find 'state: Reworking' to transition." }
$rep = "$block$eol" + "state: Complete"
$text = [regex]::Replace($text, '(?m)^state:\s*Reworking\s*?(?=\r?$)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $rep }, 1)   # lazy, the line's CR left outside the match; matches wherever :241's guard does
# A-119: UPDATE completed_at to the reclose timestamp (prior preserved in the chaining ledger entry)
$text = [regex]::Replace($text, '(?m)^completed_at:\s*\S+\s*?(?=\r?$)', "completed_at: $now", 1)   # the same cure; matches wherever :185's read does
[System.IO.File]::WriteAllText($missionFile, $text)
Write-Pass "RE-CLOSURE #$reN block appended; state Reworking -> Complete; completed_at $priorCompleted -> $now (prior preserved in the chain)"

# chaining ledger entry (operator content; preserves the prior completions)
$content = [System.IO.File]::ReadAllText($LedgerContentFile)
$entry = [ordered]@{
    id = $LedgerId; created_at = $now; created_by = 'human via claude-code:orchestrator-guide'
    ts = $now; author = 'claude-code:orchestrator-guide'; type = 'decision'; scope = 'framework'
    scope_ref = '.mission/mission.yaml'; content = $content; source_trace_id = $null; supersedes = $null
    tags = @('re-closure','reworking-to-complete','adr-029','completion-chain',"reclose-$reN",'framework')
}
Add-LedgerEntry -Root $root -Entry $entry

if (-not $NoCommit) {
    $body = "reclose: Reworking -> Complete (ADR-029) -- RE-CLOSURE #$reN`r`n`r`n$Basis`r`n"
    $msg = New-CommitMessageFile -Root $root -Body $body
    Invoke-AtomicCommit -Root $root -Paths @('.mission/mission.yaml','.mission/ledger/entries.jsonl') -MessageFile $msg | Out-Null
}
Write-Host "mission reclose: done (RE-CLOSURE #$reN; state Complete, completed_at $now)" -ForegroundColor Cyan
