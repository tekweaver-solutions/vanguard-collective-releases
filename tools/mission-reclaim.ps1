#Requires -Version 5.1
<#
.SYNOPSIS
  mission-reclaim (M-13 / ADR-041 Decision 2) -- the GATED mission-state reclaim/prune command:
  remove a SUPERSEDED / ORPHANED .mission/ artifact, but ONLY by RELOCATING it to an archive store
  first (archive-before-prune). The operator/CLI-layer counterpart to the object-store prune
  (mission-prune-objects.ps1, M-12); both are ADR-041's bounded + recorded + recoverable gating, the
  destructive tier ADR-026 deferred.

.DESCRIPTION
  REFUSE-BEFORE-MUTATE. Gate map (ADR-041 Decision 2 / contract A-139..A-142):
    (i)   A-139  provably superseded / orphaned -- MECHANICAL (a later entry supersedes it, OR the
                 current spec/manifest chain no longer references it). NEVER age-as-proxy. A still-
                 referenced / current target is REFUSED.
    (ii)  A-140  ARCHIVE-BEFORE-PRUNE (the ADR-030 keystone) -- the target's bytes are written to the
                 archive store FIRST and READ BACK + hash-verified to match the source BEFORE the live
                 drop runs. The relocation PRECEDES and GATES the removal. If the archive copy is
                 absent / incomplete / corrupt, the live drop does NOT run (zero mutation; target stays
                 in live). Sealed history is RELOCATED, never destroyed -- "append-only" becomes
                 "append-only + archive-on-reclaim". Prune-in-place is impossible by construction.
    (iii) A-141  reclaim ledger record -- an entry citing the reclaimed target + its archive location is
                 appended BEFORE the live drop; no committed reclaim effect without it.
    A-142 HAPPY  superseded target -> archive written FIRST -> archived bytes read back + matched
                 (recoverability proven) -> THEN dropped from live. Post: archived recoverable, live no
                 longer carries the target, ADR-030 invariant holds (no sealed byte unrecoverable).

  INPUT DOMAIN (recorded narrowing -- like M-12's commit-level boundary): M-13 reclaims exactly the
  THREE artifact KINDS ADR-041 D2 names -- a SUPERSEDED spec version (vNNN.yaml), an ORPHANED
  validator-result file, or a SUPERSEDED ledger entry (by id). Arbitrary-file reclaim is OUT OF M-13
  scope (refused). One target per invocation (the bound is per-artifact, explicit).

  ISOLATION (builder + validator discipline): -MissionPath is ALWAYS a throwaway .mission/-shaped
  fixture in build/test; the LIVE .mission/ is NEVER the reclaim target. The command acts only under
  -MissionPath, so a fixture path confines every reclaim to the fixture.

  Scaffold-not-author: the operator supplies -LedgerContentFile (the reclaim prose) + names the target;
  the command does the mechanical supersession proof, the archive+verify, the ledger record, the drop.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$MissionPath,                                  # root containing .mission/ (a fixture in build/test)
    [Parameter(Mandatory)][ValidateSet('spec','validator-result','ledger-entry')][string]$TargetKind,
    [Parameter(Mandatory)][string]$TargetId,                                     # vNNN | <result-filename> | <ledger-entry-id>
    [Parameter(Mandatory)][string]$ArchiveStore,                                 # relocation destination (SI-4)
    [Parameter(Mandatory)][string]$LedgerContentFile,                            # operator-authored reclaim prose (A-141 input)
    [string]$LedgerId,
    [switch]$NoCommit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')

if (-not (Test-Path $MissionPath)) { Stop-WithError "MissionPath does not exist: $MissionPath" }
$MissionPath = (Resolve-Path $MissionPath).Path
$mdir   = Join-Path $MissionPath ".mission"
if (-not (Test-Path $mdir)) { Stop-WithError "MissionPath has no .mission/ tree: $MissionPath" }
$specDir = Join-Path $mdir "spec"
$vrDir   = Join-Path $mdir "validator-results"
$ledger  = Join-Path $mdir "ledger\entries.jsonl"

function Get-Sha256Bytes { param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') } finally { $sha.Dispose() }
}

# === GATE (i) A-139 -- provably superseded / orphaned (MECHANICAL; never age-as-proxy) ============
$srcBytes = $null; $archRel = $null; $dropAction = $null
switch ($TargetKind) {
    'spec' {
        if ($TargetId -notmatch '^v\d{3}$') { Stop-WithError "REFUSED: spec TargetId must be a vNNN token (e.g. v085); got '$TargetId'." }
        $curTxt = Join-Path $specDir "current.txt"
        if (-not (Test-Path $curTxt)) { Stop-WithError "REFUSED: no spec/current.txt under $mdir." }
        $current = ([System.IO.File]::ReadAllText($curTxt)).Trim()
        $targetFile = Join-Path $specDir "$TargetId.yaml"
        if (-not (Test-Path $targetFile)) { Stop-WithError "REFUSED: spec version $TargetId not present in $specDir (nothing to reclaim)." }
        if ($TargetId -eq $current) { Stop-WithError "REFUSED (A-139): $TargetId is the CURRENT spec version (current.txt) -- still referenced, NOT superseded. Age is not a proxy for superseded." }
        $curNum = [int]($current -replace '^v','' ); $tgtNum = [int]($TargetId -replace '^v','')
        if ($tgtNum -ge $curNum) { Stop-WithError "REFUSED (A-139): $TargetId is not superseded by a later version (current is $current)." }
        $srcBytes = [System.IO.File]::ReadAllBytes($targetFile)
        $archRel = "spec/$TargetId.yaml"
        $dropAction = { Remove-Item -LiteralPath $targetFile -Force }
        Write-Pass "A-139: spec $TargetId is SUPERSEDED (later version $current is current) -- reclaimable."
    }
    'validator-result' {
        $manifestPath = Join-Path $vrDir "manifest.json"
        if (-not (Test-Path $manifestPath)) { Stop-WithError "REFUSED: no validator-results/manifest.json under $mdir." }
        $targetFile = Join-Path $vrDir $TargetId
        if (-not (Test-Path $targetFile)) { Stop-WithError "REFUSED: validator-result $TargetId not present in $vrDir (nothing to reclaim)." }
        $referenced = @((Get-Content $manifestPath -Raw | ConvertFrom-Json).entries | ForEach-Object { $_.file })
        if ($referenced -contains $TargetId) { Stop-WithError "REFUSED (A-139): $TargetId is REFERENCED by the current manifest (a live, non-superseded result) -- NOT orphaned. Age is not a proxy." }
        $srcBytes = [System.IO.File]::ReadAllBytes($targetFile)
        $archRel = "validator-results/$TargetId"
        $dropAction = { Remove-Item -LiteralPath $targetFile -Force }
        Write-Pass "A-139: validator-result $TargetId is ORPHANED (on disk, not referenced by the manifest) -- reclaimable."
    }
    'ledger-entry' {
        if (-not (Test-Path $ledger)) { Stop-WithError "REFUSED: no ledger/entries.jsonl under $mdir." }
        $lines = [System.IO.File]::ReadAllText($ledger) -split "`r?`n"
        $targetLine = $null; $superseded = $false
        foreach ($ln in $lines) {
            if (-not ($ln.Trim())) { continue }
            try { $o = $ln | ConvertFrom-Json } catch { continue }
            if ($o.id -eq $TargetId) { $targetLine = $ln }
            if ($o.supersedes) { foreach ($s in @($o.supersedes)) { if ([string]$s -eq $TargetId) { $superseded = $true } } }
        }
        if (-not $targetLine) { Stop-WithError "REFUSED: ledger entry id '$TargetId' not present (nothing to reclaim)." }
        if (-not $superseded) { Stop-WithError "REFUSED (A-139): ledger entry '$TargetId' is NOT superseded by any later entry (no later entry's 'supersedes' names it) -- age is not a proxy for superseded." }
        $srcBytes = [System.Text.Encoding]::UTF8.GetBytes($targetLine)
        $archRel = "ledger/$TargetId.json"
        $dropAction = {
            $kept = @(); foreach ($ln in ([System.IO.File]::ReadAllText($ledger) -split "`r?`n")) {
                if (-not ($ln.Trim())) { continue }
                try { $o = $ln | ConvertFrom-Json } catch { $kept += $ln; continue }
                if ($o.id -ne $TargetId) { $kept += $ln }
            }
            [System.IO.File]::WriteAllText($ledger, (($kept -join "`r`n") + "`r`n"))
        }
        Write-Pass "A-139: ledger entry $TargetId is SUPERSEDED (a later entry's 'supersedes' names it) -- reclaimable."
    }
}

# === GATE (ii) A-140 -- ARCHIVE-BEFORE-PRUNE: write archive FIRST, READ BACK + hash-verify =========
$srcHash = Get-Sha256Bytes -Bytes $srcBytes
$archPath = Join-Path $ArchiveStore $archRel
$archDir  = Split-Path $archPath -Parent
try {
    if (-not (Test-Path $archDir)) { New-Item -ItemType Directory -Path $archDir -Force -ErrorAction Stop | Out-Null }
    [System.IO.File]::WriteAllBytes($archPath, $srcBytes)
} catch {
    Stop-WithError "REFUSED (A-140): could not write the archive copy to $archPath ($($_.Exception.Message)). The live drop does NOT run -- relocation must precede and gate removal (ADR-030: relocate, never destroy). Zero mutation."
}
if (-not (Test-Path $archPath)) { Stop-WithError "REFUSED (A-140): archive copy absent after write ($archPath). Live drop refused; zero mutation." }
$archHash = Get-Sha256Bytes -Bytes ([System.IO.File]::ReadAllBytes($archPath))
if ($archHash -ne $srcHash) { Stop-WithError "REFUSED (A-140): archived bytes do NOT match the source (read-back hash mismatch: src=$srcHash arch=$archHash). The relocation is not recoverable -- live drop refused; zero mutation." }
Write-Pass "A-140: archive-before-prune -- copy written to $archPath and READ-BACK hash-verified recoverable (src==arch=$($srcHash.Substring(0,12))...). Relocation precedes the drop."

# === GATE (iii) A-141 -- reclaim ledger record (BEFORE the live drop) =============================
if (-not (Test-Path $LedgerContentFile)) { Stop-WithError "REFUSED (A-141): reclaim ledger content file not found: $LedgerContentFile. No committed reclaim effect without the record." }
$prose = [System.IO.File]::ReadAllText($LedgerContentFile)
$record = "MISSION-STATE RECLAIM (ADR-041 D2, gated, archive-before-prune). KIND=$TargetKind TARGET=$TargetId. " +
          "ARCHIVE LOCATION: $archPath (read-back hash-verified recoverable; sha256 $srcHash). RELOCATED, not destroyed (ADR-030). OPERATOR NOTE: $prose"
if (-not $LedgerId) { $LedgerId = "ledger-correction-reclaim-$TargetKind-$([regex]::Replace($TargetId,'[^A-Za-z0-9]','-'))" }
$entry = [ordered]@{
    id = $LedgerId; created_at = (Get-UtcStamp); created_by = 'claude-code:orchestrator-guide'
    ts = (Get-UtcStamp); author = 'claude-code:orchestrator-guide'; type = 'correction'; scope = 'framework'
    scope_ref = ".mission/$archRel"; content = $record; source_trace_id = $null; supersedes = $null
    tags = @('reclaim','mission-state-prune','archive-before-prune','adr-041','adr-030','gated','recoverable',$TargetKind,'framework')
}
Add-LedgerEntry -Root $MissionPath -Entry $entry
Write-Pass "A-141: reclaim record appended (citing target + archive location) BEFORE the live drop."

# === DROP from live (only reachable AFTER archive verified + record written) =======================
& $dropAction
Write-Pass "live drop: $TargetKind $TargetId removed from $mdir (its bytes are recoverable from $archPath)."

# --- post-op proof: archived recoverable + live no longer carries the target (A-142) --------------
$archStillOk = (Test-Path $archPath) -and ((Get-Sha256Bytes -Bytes ([System.IO.File]::ReadAllBytes($archPath))) -eq $srcHash)
$liveGone = switch ($TargetKind) {
    'spec'             { -not (Test-Path (Join-Path $specDir "$TargetId.yaml")) }
    'validator-result' { -not (Test-Path (Join-Path $vrDir $TargetId)) }
    'ledger-entry'     { -not ((( [System.IO.File]::ReadAllText($ledger) -split "`r?`n") | Where-Object { $_.Trim() } | ForEach-Object { try { ($_ | ConvertFrom-Json).id } catch { '' } }) -contains $TargetId) }
}
if (-not $archStillOk) { Stop-WithError "POST-OP FAIL: archived bytes not recoverable after drop ($archPath) -- ADR-030 invariant broken." }
if (-not $liveGone)    { Stop-WithError "POST-OP FAIL: target $TargetId still present in live $mdir after drop." }
Write-Pass "A-142: reclaim complete -- archived bytes recoverable (sha256 match), live no longer carries $TargetId; ADR-030 invariant holds (relocated, not destroyed)."

if (-not $NoCommit) {
    $body = "reclaim($TargetKind): $TargetId archived+pruned (ADR-041 D2) in $MissionPath`r`n`r`narchive-before-prune; recoverable from $archRel.`r`n"
    $msg = New-CommitMessageFile -Root $MissionPath -Body $body
    Invoke-AtomicCommit -Root $MissionPath -Paths @('.mission') -MessageFile $msg | Out-Null
}
Write-Host "mission reclaim: done ($TargetKind $TargetId; confined to $MissionPath)" -ForegroundColor Cyan
