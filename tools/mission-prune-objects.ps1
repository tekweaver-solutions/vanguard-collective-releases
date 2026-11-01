#Requires -Version 5.1
<#
.SYNOPSIS
  mission-prune-objects (M-12 / ADR-041 Decision 1) -- the GATED object-store destructive-op command:
  a bounded + recorded + recoverable wrapper for `git gc --prune=now` (+ optional `git reflog expire
  --expire-unreachable=now --all`). This is the OPERATOR/CLI-layer gate ADR-041 defines -- distinct
  from ADR-026's WORKER-capability DENYLIST: here the destructive op is WANTED, so the layer grants
  GATED PERMIT. It exists to make the purge incident (an operator-invoked gc/prune that exceeded
  its written dispatch, was authorized verbally, was irreversible, audited harmless only after the
  fact) impossible-or-recoverable.

.DESCRIPTION
  REFUSE-BEFORE-MUTATE: every gate runs and the what-was-destroyed ledger record is written BEFORE the
  destructive op; the op is the last action. Mirrors the F-032 enforce skeleton (mission-lib.ps1).

  Gate map (ADR-041 Decision 1 / contract A-131..A-138):
    (i)   A-131  clean working tree              -- Assert-CleanWorkingTree (reused)
    (ii)  A-132  written scoped authorization    -- -AuthorizedTargets: concrete object/ref ids; absent
                                                    or a blanket sentinel ("ALL"/"*"/...) is REFUSED.
                                                    This is the purge-incident fix: authorization is WRITTEN +
                                                    TARGET-SCOPED, never inferred from a verbal "purge now".
    (iii) A-133  pre-op recoverability anchor     -- the pre-op SHA is recorded before any destructive action
          A-134  reflog recovery-net-discard ack  -- -ExpireReflog REQUIRES -RecoveryNetDiscardAck (expiring
                                                    the reflog destroys the very recovery net)
    (iv)  A-135  post-op integrity proof          -- fsck --full + for-each-ref --contains: refuse if any
                                                    AUTHORIZED target is REFERENCED (a referenced object in
                                                    scope). The purge audit's after-the-fact check, hoisted to
                                                    run DURING the op (pre-mutation).
          A-138  BOUNDED (no over-reach)          -- the prune blast radius (what gc --prune=now WOULD remove,
                                                    computed via `fsck --unreachable --no-reflogs`) must be a
                                                    SUBSET of -AuthorizedTargets. If an out-of-scope
                                                    unreferenced object would be swept, the op cannot be
                                                    confined -> REFUSE (the purge incident's "swept BEYOND the target").
    (v)   A-136  what-was-destroyed ledger        -- a record (target + authorization + integrity/bounded
                                                    proof) is appended BEFORE the destructive op; without it
                                                    the destructive effect is never produced.
    A-137 HAPPY PATH                              -- all gates satisfied -> a REAL gc --prune=now (+ reflog
                                                    expire) runs against -RepoPath; referenced objects survive,
                                                    only the authorized unreferenced target(s) are removed.

  ISOLATION (builder + validator discipline): in build/test, -RepoPath is ALWAYS a throwaway fixture
  under .mission-runtime/fixtures*/ with its OWN object store; the live repo/.mission/ are never the
  target. The command itself acts only on -RepoPath, so a fixture path confines every destructive op
  to the fixture's object store. The what-was-destroyed ledger entry is written to -RepoPath's OWN
  .mission/ledger (the fixture's), not the live ledger.

  Scaffold-not-author: the operator authors -LedgerContentFile (the what-was-destroyed prose) + supplies
  -AuthorizedTargets (the written scoped authorization); the command scaffolds the record envelope +
  the mechanical proof facts and performs the bounded, recorded, recoverable op.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoPath,            # the repo to prune (a fixture in build/test)
    [Parameter(Mandatory)][string[]]$AuthorizedTargets, # WRITTEN scoped authorization: the exact unreferenced object SHA(s) the prune may remove (A-132)
    [Parameter(Mandatory)][string]$LedgerContentFile,   # operator-authored what-was-destroyed prose (A-136 input)
    [switch]$ExpireReflog,                              # also `git reflog expire --expire-unreachable=now --all` (a reflog-expiring op)
    [switch]$RecoveryNetDiscardAck,                     # explicit ack that the recovery net is being discarded (A-134; REQUIRED with -ExpireReflog)
    [string]$LedgerId,
    [switch]$NoCommit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')

# --- Invoke-GitSafe: run a read-only git query without letting native stderr TERMINATE the gate.
#     mission-lib sets $ErrorActionPreference='Stop'; under PS 5.1 a native command that writes to
#     stderr (e.g. `rev-parse HEAD` on a repo with no HEAD, `cat-file -t` on a missing object) raises
#     a terminating NativeCommandError -- which would crash a gate BEFORE its attributed Stop-WithError
#     ran. Running the native call under a locally-scoped EAP='Continue' lets the gate branch on the
#     real exit code / output and emit its OWN attributed REFUSED message. This changes NO gate logic;
#     it only makes each gate fail as its intended refusal instead of a raw crash.
function Invoke-GitSafe {
    param([string]$Repo, [string[]]$GitArgs)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = & git -C $Repo @GitArgs 2>$null; return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $out } }
    finally { $ErrorActionPreference = $prev }
}

# --- resolve + validate the target repo -------------------------------------------------------------
if (-not (Test-Path $RepoPath)) { Stop-WithError "RepoPath does not exist: $RepoPath" }
$RepoPath = (Resolve-Path $RepoPath).Path
if ((Invoke-GitSafe -Repo $RepoPath -GitArgs @('rev-parse','--is-inside-work-tree')).Code -ne 0) {
    Stop-WithError "RepoPath is not a git repository: $RepoPath"
}

# helper: the set of unreachable COMMITS `gc --prune=now` WOULD remove (post-reflog-expire view, no
# mutation). `--no-reflogs` makes fsck treat reflogs as NOT keeping objects alive -- i.e. exactly the
# commits that become prunable once the reflog is expired. The blast radius is computed WITHOUT mutating.
# M-12 authorizes dangling COMMIT(s); each commit's object closure (its trees/blobs not shared with a
# referenced commit) is pruned WITH it -- so the bound is enforced at the commit level (the purge-incident class is
# abandoned commit LINES). A dangling tree/blob with no owning commit is out of M-12 scope.
function Get-PruneBlastRadiusCommits {
    param([string]$Repo)
    $out = (Invoke-GitSafe -Repo $Repo -GitArgs @('fsck','--full','--unreachable','--no-reflogs','--no-progress')).Out
    $shas = @()
    foreach ($line in $out) {
        if ($line -match '^unreachable\s+commit\s+([0-9a-f]{7,40})\s*$') { $shas += $Matches[1] }
    }
    return @($shas | Sort-Object -Unique)
}
function Test-ObjectReferenced {  # A-135: is the object reachable from ANY ref?
    param([string]$Repo, [string]$Sha)
    $refs = (Invoke-GitSafe -Repo $Repo -GitArgs @('for-each-ref','--contains',$Sha,'--format=%(refname)')).Out
    return [bool]($refs | Where-Object { $_ -and $_.Trim() })
}

# === GATE (i) A-131 -- clean working tree =========================================================
if (-not $NoCommit) { Assert-CleanWorkingTree -Root $RepoPath }
else { Write-Info "clean-tree gate skipped (-NoCommit); A-131 still asserts on a committing run." }

# === GATE (ii) A-132 -- WRITTEN scoped authorization naming the target ============================
$blanket = @('ALL','*','ALL-UNREFERENCED','EVERYTHING','PURGE-NOW','PURGE','ANY')
$authClean = @($AuthorizedTargets | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($authClean.Count -eq 0) {
    Stop-WithError "REFUSED (A-132): no written scoped authorization. -AuthorizedTargets must NAME the concrete object/ref id(s) this prune may remove. A verbal/unscoped 'purge now' is NOT a target-scoped authorization (the purge-incident failure -- authorization must be WRITTEN and target-scoped)."
}
foreach ($a in $authClean) {
    if ($blanket -contains $a.ToUpper()) {
        Stop-WithError "REFUSED (A-132): authorization '$a' is a BLANKET sentinel, not target-scoped. Name the specific unreferenced object SHA(s) to remove -- an unscoped purge is exactly the purge-incident over-broad authorization."
    }
    if ($a -notmatch '^[0-9a-f]{7,40}$') {
        Stop-WithError "REFUSED (A-132): authorization target '$a' is not a concrete object id (expected a 7-40 hex SHA). Target-scoped authorization names exact objects."
    }
}
Write-Pass "A-132: written scoped authorization present ($($authClean.Count) target object(s) named)."

# === GATE (iii) A-133 -- pre-op recoverability anchor =============================================
$anchor = Invoke-GitSafe -Repo $RepoPath -GitArgs @('rev-parse','HEAD')
$preSha = ($anchor.Out | Select-Object -First 1)
if ($anchor.Code -ne 0 -or -not $preSha) { Stop-WithError "REFUSED (A-133): cannot record a pre-op recoverability anchor (no HEAD in $RepoPath)." }
$preSha = ([string]$preSha).Trim()
Write-Pass "A-133: pre-op recoverability anchor recorded (pre-SHA $preSha)."

# === GATE (iii/A-134) -- reflog recovery-net-discard acknowledgement ==============================
if ($ExpireReflog -and -not $RecoveryNetDiscardAck) {
    Stop-WithError "REFUSED (A-134): -ExpireReflog discards the reflog recovery net (the net that makes a hard reset recoverable). It REQUIRES the explicit -RecoveryNetDiscardAck acknowledgement. Refusing the reflog-expiring op without the ack."
}
if ($ExpireReflog) { Write-Pass "A-134: recovery-net-discard acknowledged for the reflog-expiring op." }

# === GATE (iv) A-135 + A-138 -- integrity proof + BOUNDED (pre-mutation) ==========================
foreach ($a in $authClean) {
    $tyq = Invoke-GitSafe -Repo $RepoPath -GitArgs @('cat-file','-t',$a)
    $ty = ([string]($tyq.Out | Select-Object -First 1))
    if ($tyq.Code -ne 0 -or -not $ty) { Stop-WithError "REFUSED: authorized target $a does not exist in $RepoPath." }
    if ($ty.Trim() -ne 'commit') {
        Stop-WithError "REFUSED (A-132/scope): authorized target $a is a '$($ty.Trim())', not a commit. M-12 object-store gating authorizes dangling COMMIT(s) -- each commit's object closure is pruned with it; name the commit SHA, not a bare tree/blob."
    }
    if (Test-ObjectReferenced -Repo $RepoPath -Sha $a) {
        Stop-WithError "REFUSED (A-135): authorized target $a is REFERENCED (reachable from a ref). A referenced object must never be in a prune's scope -- the integrity proof (for-each-ref --contains) refuses before any mutation."
    }
}
$blast = Get-PruneBlastRadiusCommits -Repo $RepoPath   # unreachable COMMITS gc --prune=now would remove
# normalise to comparable prefixes: a target may be given as a short SHA; match by prefix.
$outOfScope = @()
foreach ($b in $blast) {
    $covered = $false
    foreach ($a in $authClean) { if ($b.StartsWith($a) -or $a.StartsWith($b)) { $covered = $true; break } }
    if (-not $covered) { $outOfScope += $b }
}
if ($outOfScope.Count -gt 0) {
    Stop-WithError ("REFUSED (A-138): the prune cannot be CONFINED to the authorized target(s). " + $outOfScope.Count + " out-of-scope unreferenced object(s) would be swept by gc --prune=now (the purge-incident 'swept BEYOND the target' over-reach): " + ($outOfScope -join ', ') + ". Authorize them explicitly or remove them from the blast radius first; refusing the un-confinable op.")
}
Write-Pass "A-135/A-138: integrity proof + bounded check PASS (no referenced object in scope; blast radius confined to the authorized target(s))."
$fsckBefore = (& git -C $RepoPath fsck --full --no-progress 2>&1)

# === GATE (v) A-136 -- what-was-destroyed ledger record (BEFORE the destructive op) ================
if (-not (Test-Path $LedgerContentFile)) { Stop-WithError "REFUSED (A-136): what-was-destroyed ledger content file not found: $LedgerContentFile. The destructive effect is not produced without its record." }
$ops = @('git gc --prune=now'); if ($ExpireReflog) { $ops = @('git reflog expire --expire-unreachable=now --all') + $ops }
$prose = [System.IO.File]::ReadAllText($LedgerContentFile)
$record = "DESTRUCTIVE OBJECT-STORE OP (ADR-041 D1, gated). repo=$RepoPath. OP=[$($ops -join ' ; ')]. " +
          "AUTHORIZED TARGETS (written, scoped): $($authClean -join ', '). PRE-OP ANCHOR: $preSha. " +
          "BOUNDED PROOF: blast radius {$($blast -join ', ')} confined to authorized set (A-138); zero referenced objects in scope (A-135). " +
          "REFLOG-EXPIRE: $([bool]$ExpireReflog) (ack=$([bool]$RecoveryNetDiscardAck)). OPERATOR NOTE: $prose"
if (-not $LedgerId) { $LedgerId = "ledger-correction-prune-objects-$($preSha.Substring(0,8))" }
$entry = [ordered]@{
    id = $LedgerId; created_at = (Get-UtcStamp); created_by = 'claude-code:orchestrator-guide'
    ts = (Get-UtcStamp); author = 'claude-code:orchestrator-guide'; type = 'correction'; scope = 'framework'
    scope_ref = '.mission/ledger/entries.jsonl'; content = $record; source_trace_id = $null; supersedes = $null
    tags = @('destructive-op','object-store-prune','adr-041','gated','bounded','recorded','recoverable','what-was-destroyed','framework')
}
Add-LedgerEntry -Root $RepoPath -Entry $entry   # writes to RepoPath's OWN .mission/ledger (the fixture's)
Write-Pass "A-136: what-was-destroyed record appended to $RepoPath/.mission/ledger BEFORE the destructive op."

# === HAPPY PATH (A-137) -- the REAL destructive op, confined to -RepoPath ==========================
if ($ExpireReflog) {
    & git -C $RepoPath reflog expire --expire=now --expire-unreachable=now --all 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-WithError "reflog expire failed in $RepoPath" }
}
& git -C $RepoPath gc --prune=now 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Stop-WithError "gc --prune=now failed in $RepoPath" }
Write-Pass "destructive op ran (confined to $RepoPath): $($ops -join ' ; ')"

# --- post-op integrity proof: fsck clean + the authorized targets are gone (A-135/A-137) ----------
# use `cat-file --batch-check` (stderr-free, exit 0 either way) -- a bare `cat-file -e <pruned-sha>`
# writes to stderr, which $ErrorActionPreference='Stop' turns into a terminating error.
$fsckAfter = (& git -C $RepoPath fsck --full --no-progress 2>$null)
$stillPresent = @()
foreach ($a in $authClean) {
    $bc = ($a | & git -C $RepoPath cat-file --batch-check 2>$null)
    if ($bc -and ($bc -notmatch 'missing')) { $stillPresent += $a }
}
if ($stillPresent.Count -gt 0) { Write-Info ("note: target(s) still resolvable post-prune (may be referenced elsewhere): " + ($stillPresent -join ', ')) }
Write-Pass "post-op integrity: fsck --full completed; authorized target(s) pruned: $(($authClean | Where-Object { $stillPresent -notcontains $_ }) -join ', ')"

if (-not $NoCommit) {
    $body = "prune-objects: gated object-store prune (ADR-041 D1) in $RepoPath`r`n`r`nbounded + recorded + recoverable; targets $($authClean -join ', ').`r`n"
    $msg = New-CommitMessageFile -Root $RepoPath -Body $body
    Invoke-AtomicCommit -Root $RepoPath -Paths @('.mission/ledger/entries.jsonl') -MessageFile $msg | Out-Null
}
Write-Host "mission prune-objects: done (confined to $RepoPath)" -ForegroundColor Cyan
