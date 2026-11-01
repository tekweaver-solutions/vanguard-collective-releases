#Requires -Version 5.1
<#
.SYNOPSIS
  A6 acceptance instrument -- D11 stream-payload identity. (dispatch d43a8143)

.DESCRIPTION
  Citation convention: "design SS<n>" denotes
  docs/framework/vanguard-collective-local-modes-v2.3.md.

  Decides the D11 ACCEPTANCE (dispatch d43a8143 items 1-8) from disk. It obeys
  the three instrument laws: pure ASCII asserting its own bytes; Path-suffixed
  path variables; no native stderr surprises under PS 5.1. It is CONTENT-ANCHORED: fixtures
  are constructed under a sandbox, populations are never derived from a directory a ceremony
  perturbs, and the two REAL residue directories are consulted read-only under a SKIP-if-absent
  rule so this instrument still decides at any future HEAD (their disposition is D9's).

  REACH -- THE WINDOW THIS HARNESS DRIVES, stated per operator constraint 2 on the approved
  D11 plan (2026-08-10). The collision window is READ-TO-APPEND: the interval between one
  hook's log-length read and its log append, spanning payload serialization and the stream
  write. Live instances measured 1 ms, 16 ms and 18 ms spreads -- NOT a same-tick race, and a
  harness tuned to a sub-millisecond window would under-reproduce and could pass a broken
  cure. G1/G2/G3 release both contenders through a shared start barrier and let them race the
  real window with no artificial widening and no sleeps inside it.

  TWO FAILURE CLASSES IN THAT WINDOW, BOTH CLOSED BY THE CURE (operator ruling, 2026-08-10).
  The overwrite-era window fails two ways, and the split is SIZE-DEPENDENT -- measured at the
  A6-1 gate: at 2 KB payloads, 8/10 rounds landed the duplicate-path signature (one file, two
  log lines -- a payload silently destroyed under a clean manifest); at 60 KB, 3/10 landed the
  duplicate and 7/10 LOST THE ENTRY ENTIRELY to a sharing violation on the overwrite open,
  exiting through the sealed hook's catch with no log line and no stream -- a third
  silent-incompleteness mechanism beyond F-4/F-5. A reader who sees only "duplicate path"
  would not know why large payloads mattered. G1 counts and prints BOTH classes; G2 requires
  zero losses of either kind under the same drive: CreateNew contention moves the loser to
  the next name instead of overwriting or throwing.

  Exit contract: 0 = all checks passed, none skipped. N>0 = N failing checks. 3 = passed with
  skips -- DISCLOSED AS NON-UNIQUE: a run with exactly three failing checks also exits 3; read
  the summary, not just the code.

  WHAT THIS INSTRUMENT IS NOT. Nothing invokes it automatically. It decides that the cure and
  detectors behave as specified; it cannot decide that no other identity defect exists.
#>
[CmdletBinding()]
param(
    [switch]$KeepSandbox,
    [int]$ReproRounds = 10,
    [int]$ReproPayloadChars = 2000
)

$ErrorActionPreference = 'Stop'

# Tree-anchored via $PSScriptRoot, no cwd dependence.
# tools/framework/tests/<this file> -> up three -> repo root
$RepoRootPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$HooksDirPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'hooks'
$LibPath      = Join-Path $HooksDirPath 'lib\evidence-common.ps1'
$SandboxPath  = Join-Path $RepoRootPath '.mission-runtime\a6-stream-identity-test'

$failures = 0
$skips    = 0
$checksRun = 0
function Check {
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail)
    $script:checksRun++
    $tag = if ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ""
    Write-Host "[$tag] $Id -- $Title"
    if ($Detail) { Write-Host $Detail }
    if (-not $Ok) { $script:failures++ }
}
function Skip {
    param([string]$Id, [string]$Title, [string]$Reason)
    $script:checksRun++
    $script:skips++
    Write-Host ""
    Write-Host "[SKIP] $Id -- $Title"
    Write-Host "  $Reason"
}
function Write-Reach {
    param([string]$Text)
    Write-Host "  reach: $Text"
}

if (Test-Path -LiteralPath $SandboxPath) { Remove-Item -LiteralPath $SandboxPath -Recurse -Force }
New-Item -ItemType Directory -Path $SandboxPath -Force | Out-Null

Write-Host "=============================================================================="
Write-Host " A6 -- D11 STREAM-PAYLOAD IDENTITY (dispatch d43a8143)"
Write-Host "=============================================================================="
Write-Host "repo root : $RepoRootPath"
Write-Host "hooks     : $HooksDirPath"
Write-Host "sandbox   : $SandboxPath   (under .mission-runtime/, gitignored)"
Write-Host "window    : read-to-append (live spreads 1/16/18 ms); barrier drive, no widening"
Write-Host "NOTE      : this instrument is OPERATOR-RUN. In an agent session the guard denies"
Write-Host "            executing, hashing, staging and writing anything under tools/framework/**."

. $LibPath

# --- runtime-generated worker scripts (kept inside this one file by construction) -------------
$WorkerDirPath = Join-Path $SandboxPath 'workers'
New-Item -ItemType Directory -Path $WorkerDirPath -Force | Out-Null

# Pre-cure replica: faithful to sealed 169611f0 lines 78-90 (count -> name -> overwrite write)
# and 189f811b Add-EvidenceLogLine (exclusive append with retry). This is the DEFECT preserved
# as a fixture so the harness can prove it still knows how to fire it (dispatch ACCEPTANCE 1:
# a check that cannot reproduce the defect cannot prove the cure).
$PrecureWorkerPath = Join-Path $WorkerDirPath 'worker-precure.ps1'
[System.IO.File]::WriteAllText($PrecureWorkerPath, @'
param([string]$FixtureDir, [string]$BarrierPath, [string]$Marker, [int]$Repeat = 2000)
$ErrorActionPreference = 'Stop'
$logPath   = Join-Path $FixtureDir 'log.jsonl'
$streamDir = Join-Path $FixtureDir 'streams'
$deadline = (Get-Date).AddSeconds(15)
while (-not (Test-Path -LiteralPath $BarrierPath)) {
    if ((Get-Date) -gt $deadline) { exit 9 }
}
$stdout = ($Marker * $Repeat)
$seq = 1
if (Test-Path -LiteralPath $logPath) {
    $seq = @([System.IO.File]::ReadAllLines($logPath) | Where-Object { $_.Trim() }).Count + 1
}
$seqStr = '{0:d6}' -f $seq
$streamFull = Join-Path $streamDir "$seqStr.json"
$streamObj = [ordered]@{ seq = $seq; tool = 'Bash'; stdout = $stdout; stderr = '' }
[System.IO.File]::WriteAllText($streamFull, ($streamObj | ConvertTo-Json -Depth 8),
                               (New-Object System.Text.UTF8Encoding($false)))
$entry = [ordered]@{ seq = $seq; marker = $Marker; path = "streams/$seqStr.json" }
$json  = ($entry | ConvertTo-Json -Compress -Depth 12)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json + "`n")
for ($attempt = 1; $attempt -le 20; $attempt++) {
    try {
        $fs = [System.IO.File]::Open($logPath, [System.IO.FileMode]::Append,
                                     [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
        break
    } catch [System.IO.IOException] { Start-Sleep -Milliseconds (10 * $attempt) }
}
exit 0
'@, (New-Object System.Text.UTF8Encoding($false)))

# Cured worker: the same barrier and the same window, against New-EvidenceStreamFile.
$CuredWorkerPath = Join-Path $WorkerDirPath 'worker-cured.ps1'
[System.IO.File]::WriteAllText($CuredWorkerPath, @'
param([string]$FixtureDir, [string]$BarrierPath, [string]$Marker, [string]$LibPath, [int]$Repeat = 2000)
$ErrorActionPreference = 'Stop'
. $LibPath
$logPath   = Join-Path $FixtureDir 'log.jsonl'
$streamDir = Join-Path $FixtureDir 'streams'
$deadline = (Get-Date).AddSeconds(15)
while (-not (Test-Path -LiteralPath $BarrierPath)) {
    if ((Get-Date) -gt $deadline) { exit 9 }
}
$stdout = ($Marker * $Repeat)
$startSeq = 1
if (Test-Path -LiteralPath $logPath) {
    $startSeq = @([System.IO.File]::ReadAllLines($logPath) | Where-Object { $_.Trim() }).Count + 1
}
$alloc = New-EvidenceStreamFile -StreamDir $streamDir -StartSeq $startSeq -Tool 'Bash' -Stdout $stdout -Stderr ''
Add-EvidenceLogLine -LogPath $logPath -Entry ([ordered]@{
    seq = $alloc.seq; marker = $Marker; stdout_sha256 = (Get-Sha256OfString $stdout); path = $alloc.rel })
exit 0
'@, (New-Object System.Text.UTF8Encoding($false)))

# Hook-driver worker: barrier, then pipe a recorded payload into the PLACED PostToolUse hook.
$HookWorkerPath = Join-Path $WorkerDirPath 'worker-hook.ps1'
[System.IO.File]::WriteAllText($HookWorkerPath, @'
param([string]$HookPath, [string]$PayloadPath, [string]$BarrierPath)
$ErrorActionPreference = 'Stop'
$deadline = (Get-Date).AddSeconds(15)
while (-not (Test-Path -LiteralPath $BarrierPath)) {
    if ((Get-Date) -gt $deadline) { exit 9 }
}
$json = [System.IO.File]::ReadAllText($PayloadPath)
$json | & powershell -NoProfile -ExecutionPolicy Bypass -File $HookPath
exit $LASTEXITCODE
'@, (New-Object System.Text.UTF8Encoding($false)))

function Invoke-BarrierPair {
    param([string]$WorkerPath, [object[]]$ArgsA, [object[]]$ArgsB, [string]$BarrierPath)
    $pa = Start-Process powershell -ArgumentList (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$WorkerPath) + $ArgsA) -PassThru -WindowStyle Hidden
    $pb = Start-Process powershell -ArgumentList (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$WorkerPath) + $ArgsB) -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 900
    New-Item -ItemType File -Path $BarrierPath -Force | Out-Null
    $null = $pa.WaitForExit(30000)
    $null = $pb.WaitForExit(30000)
    return @($pa.ExitCode, $pb.ExitCode)
}

# =============================================================================
# G1 -- THE REPRODUCTION GATE (dispatch ACCEPTANCE 1; operator constraint 1)
# =============================================================================
# The barrier pair drives the PRE-CURE replica. REQUIRED: at least one round lands the live
# signature -- ONE surviving stream file, TWO log lines declaring it. Zero reproductions in
# ReproRounds rounds is a FAIL, not a skip: a harness that cannot fire the defect proves
# nothing about the cure. The second observed failure class (a sharing violation losing the
# entry entirely -- worker exit 1, one log line) is counted and reported; it is the same
# window failing a different way, and the class split is SIZE-DEPENDENT (gate measurement:
# 8/10 dup at 2 KB; 3/10 dup + 7/10 lost at 60 KB), which is why large payloads mattered.
$g1Rows = @()
for ($r = 1; $r -le $ReproRounds; $r++) {
    $fxPath = Join-Path $SandboxPath ("g1-{0:d2}" -f $r)
    New-Item -ItemType Directory -Path (Join-Path $fxPath 'streams') -Force | Out-Null
    $barrierPath = Join-Path $fxPath 'GO'
    $exits = Invoke-BarrierPair -WorkerPath $PrecureWorkerPath -BarrierPath $barrierPath `
        -ArgsA @('-FixtureDir',$fxPath,'-BarrierPath',$barrierPath,'-Marker','A','-Repeat',"$ReproPayloadChars") `
        -ArgsB @('-FixtureDir',$fxPath,'-BarrierPath',$barrierPath,'-Marker','B','-Repeat',"$ReproPayloadChars")
    $fileCount = @(Get-ChildItem -LiteralPath (Join-Path $fxPath 'streams') -File).Count
    $lineCount = 0
    $lgPath = Join-Path $fxPath 'log.jsonl'
    if (Test-Path -LiteralPath $lgPath) {
        $lineCount = @([System.IO.File]::ReadAllLines($lgPath) | Where-Object { $_.Trim() }).Count
    }
    $g1Rows += [pscustomobject]@{ round = $r; files = $fileCount; lines = $lineCount
                                  dupCollision = ($fileCount -eq 1 -and $lineCount -eq 2)
                                  lostEntry    = ($fileCount -eq 1 -and $lineCount -eq 1)
                                  exitA = $exits[0]; exitB = $exits[1] }
}
$g1Dup  = @($g1Rows | Where-Object { $_.dupCollision }).Count
$g1Lost = @($g1Rows | Where-Object { $_.lostEntry }).Count
$detail = @"
  rounds x payload : $ReproRounds x $ReproPayloadChars chars
$(($g1Rows | ForEach-Object { "    round {0,2}: files={1} lines={2} dup={3} lost={4} exits={5}/{6}" -f $_.round, $_.files, $_.lines, $_.dupCollision, $_.lostEntry, $_.exitA, $_.exitB }) -join "`n")
  HIT RATE (dup signature, files=1 lines=2) : $g1Dup/$ReproRounds
  lost-entry class (sharing violation)      : $g1Lost/$ReproRounds
  every dup round is a destroyed payload the pre-cure manifest would have vouched for
"@
Check -Id 'G1' -Title 'reproduction gate: the barrier drive fires the pre-cure collision' `
      -Ok ($g1Dup -ge 1) -Detail $detail
Write-Reach "drives the read-to-append window with the pre-cure allocator replica (quoted from sealed 169611f0/189f811b in the worker source); zero hits would mean the harness proves nothing and FAILS"

# =============================================================================
# G2 -- THE CURE AT THE ALLOCATOR, SAME HARNESS (dispatch ACCEPTANCE 1)
# =============================================================================
$g2Rows = @()
for ($r = 1; $r -le $ReproRounds; $r++) {
    $fxPath = Join-Path $SandboxPath ("g2-{0:d2}" -f $r)
    New-Item -ItemType Directory -Path (Join-Path $fxPath 'streams') -Force | Out-Null
    $barrierPath = Join-Path $fxPath 'GO'
    $exits = Invoke-BarrierPair -WorkerPath $CuredWorkerPath -BarrierPath $barrierPath `
        -ArgsA @('-FixtureDir',$fxPath,'-BarrierPath',$barrierPath,'-Marker','A','-LibPath',$LibPath,'-Repeat',"$ReproPayloadChars") `
        -ArgsB @('-FixtureDir',$fxPath,'-BarrierPath',$barrierPath,'-Marker','B','-LibPath',$LibPath,'-Repeat',"$ReproPayloadChars")
    $streamFiles = @(Get-ChildItem -LiteralPath (Join-Path $fxPath 'streams') -File | Sort-Object Name)
    $lgPath = Join-Path $fxPath 'log.jsonl'
    $entries = @()
    if (Test-Path -LiteralPath $lgPath) {
        foreach ($ln in [System.IO.File]::ReadAllLines($lgPath)) {
            if ($ln.Trim()) { $entries += ($ln | ConvertFrom-Json) }
        }
    }
    $seqs = @($entries | ForEach-Object { [int]$_.seq } | Sort-Object)
    $bodiesOk = $true
    foreach ($e in $entries) {
        $bPath = Join-Path $fxPath ([string]$e.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $bPath)) { $bodiesOk = $false; continue }
        $body = [System.IO.File]::ReadAllText($bPath) | ConvertFrom-Json
        if ((Get-Sha256OfString ([string]$body.stdout)) -ne [string]$e.stdout_sha256) { $bodiesOk = $false }
    }
    $g2Rows += [pscustomobject]@{ round = $r; files = $streamFiles.Count; lines = $entries.Count
                                  distinctSeq = (@($seqs | Select-Object -Unique).Count -eq $entries.Count)
                                  bodiesOk = $bodiesOk; exitA = $exits[0]; exitB = $exits[1] }
}
$g2Clean = @($g2Rows | Where-Object { $_.files -eq 2 -and $_.lines -eq 2 -and $_.distinctSeq -and $_.bodiesOk -and $_.exitA -eq 0 -and $_.exitB -eq 0 }).Count
$detail = @"
  rounds x payload : $ReproRounds x $ReproPayloadChars chars (identical harness to G1)
$(($g2Rows | ForEach-Object { "    round {0,2}: files={1} lines={2} distinctSeq={3} bodiesOk={4} exits={5}/{6}" -f $_.round, $_.files, $_.lines, $_.distinctSeq, $_.bodiesOk, $_.exitA, $_.exitB }) -join "`n")
  CLEAN ROUNDS : $g2Clean/$ReproRounds   (required: all -- two payloads survive every race)
"@
Check -Id 'G2' -Title 'cure at the allocator: two contenders, two files, two distinct seqs, zero losses' `
      -Ok ($g2Clean -eq $ReproRounds) -Detail $detail
Write-Reach "same barrier, same window, cured allocator; also covers the lost-entry class -- CreateNew contention moves the loser to the next name instead of throwing"

# =============================================================================
# G3 -- THE CURE AT THE PLACED HOOK (dispatch ACCEPTANCE 1, end to end)
# =============================================================================
$env:CLAUDE_PROJECT_DIR  = $SandboxPath
$env:MISSION_DISPATCH_ID = 'a6-hook-race'
$hookPath = Join-Path $HooksDirPath 'evidence-post-tool-use.ps1'
$evRacePath = Join-Path $SandboxPath '.mission-runtime\evidence\a6-hook-race'
$payloadAPath = Join-Path $WorkerDirPath 'payload-a.json'
$payloadBPath = Join-Path $WorkerDirPath 'payload-b.json'
$bigA = ('A' * 200000); $bigB = ('B' * 200000)
[System.IO.File]::WriteAllText($payloadAPath, (@{ session_id = 'a6'; hook_event_name = 'PostToolUse'
    tool_name = 'Bash'; tool_input = @{ command = 'a6 race call A' }
    tool_response = @{ stdout = $bigA; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress),
    (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($payloadBPath, (@{ session_id = 'a6'; hook_event_name = 'PostToolUse'
    tool_name = 'Bash'; tool_input = @{ command = 'a6 race call B' }
    tool_response = @{ stdout = $bigB; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress),
    (New-Object System.Text.UTF8Encoding($false)))
$barrierPath = Join-Path $WorkerDirPath 'GO-hook'
$exits = Invoke-BarrierPair -WorkerPath $HookWorkerPath -BarrierPath $barrierPath `
    -ArgsA @('-HookPath',$hookPath,'-PayloadPath',$payloadAPath,'-BarrierPath',$barrierPath) `
    -ArgsB @('-HookPath',$hookPath,'-PayloadPath',$payloadBPath,'-BarrierPath',$barrierPath)
$raceLogPath = Join-Path $evRacePath 'log.jsonl'
$raceEntries = @(Read-EvidenceLog -LogPath $raceLogPath)
$raceFiles = @()
if (Test-Path -LiteralPath (Join-Path $evRacePath 'streams')) {
    $raceFiles = @(Get-ChildItem -LiteralPath (Join-Path $evRacePath 'streams') -File | Sort-Object Name)
}
$raceSeqs = @($raceEntries | ForEach-Object { [int](Get-EntryField $_ 'seq' 0) } | Sort-Object)
$raceBodiesOk = $true
foreach ($e in $raceEntries) {
    $bPath = Join-Path $evRacePath ([string](Get-EntryField $e 'path' '') -replace '/', '\')
    if (-not (Test-Path -LiteralPath $bPath)) { $raceBodiesOk = $false; continue }
    $body = [System.IO.File]::ReadAllText($bPath) | ConvertFrom-Json
    if ((Get-Sha256OfString ([string](Get-EntryField $body 'stdout' ''))) -ne [string](Get-EntryField $e 'stdout_sha256' '')) { $raceBodiesOk = $false }
}
$raceTs = @($raceEntries | ForEach-Object { [string](Get-EntryField $_ 'ts' '') })
$detail = @"
  hook          : $hookPath
  worker exits  : $($exits[0]) / $($exits[1])   (expect 0/0)
  log entries   : $($raceEntries.Count)   (expect 2)
  stream files  : $($raceFiles.Count)   (expect 2: $(($raceFiles | ForEach-Object { $_.Name }) -join ', '))
  seq values    : $($raceSeqs -join ', ')   (expect 1, 2)
  entry ts      : $($raceTs -join '  |  ')
  bodies re-derive to their own recorded hashes : $raceBodiesOk   (expect True)
  payloads      : 200000 chars each, distinct content per contender
"@
Check -Id 'G3' -Title 'cure at the placed hook: two barrier-released invocations, two payloads, both re-derive' `
      -Ok ($exits[0] -eq 0 -and $exits[1] -eq 0 -and $raceEntries.Count -eq 2 -and
           $raceFiles.Count -eq 2 -and (@($raceSeqs | Select-Object -Unique).Count -eq 2) -and
           $raceBodiesOk) -Detail $detail
Write-Reach "drives the PLACED evidence-post-tool-use.ps1 as two processes; overlap of the hook-internal window is probabilistic (process startup jitter), which is why the deterministic window proof is G1/G2 -- this check asserts the end-to-end OUTCOME is loss-free regardless"

# =============================================================================
# G4 -- FINALIZE-TIME DIVERGENCE IS RECORDED (dispatch ACCEPTANCE 3)
# =============================================================================
$env:MISSION_DISPATCH_ID = 'a6-diverge'
$evDivPath = Join-Path $SandboxPath '.mission-runtime\evidence\a6-diverge'
$divPayload = @{ session_id = 'a6'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'a6 diverge call' }
    tool_response = @{ stdout = 'diverge-payload'; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress
$divPayload | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookPath | Out-Null
# destroy the payload INSIDE THE SANDBOX -- reproducing on a fixture what the live defect did
Remove-Item -LiteralPath (Join-Path $evDivPath 'streams\000001.json') -Force
$stopPayload = @{ session_id = 'a6'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress
$stopPayload | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $HooksDirPath 'evidence-stop-finalize.ps1') | Out-Null
$divManPath = Join-Path $evDivPath 'manifest.json'
$divMan = if (Test-Path -LiteralPath $divManPath) { [System.IO.File]::ReadAllText($divManPath) | ConvertFrom-Json } else { $null }
$divErrPath = Join-Path $evDivPath 'hook-errors.log'
$divErrTxt = if (Test-Path -LiteralPath $divErrPath) { [System.IO.File]::ReadAllText($divErrPath) } else { '' }
$divCommittedErrPath = Join-Path $SandboxPath '.mission\evidence\a6-diverge\hook-errors.log'
$detail = @"
  entries in manifest        : $(if ($divMan) { $divMan.entry_count } else { 'n/a' })   (1 declared)
  stream files on disk       : 0   (payload deleted before finalize)
  hook_errors_present        : $(if ($divMan) { $divMan.hook_errors_present } else { 'n/a' })   (expect True)
  divergence recorded        : $($divErrTxt -like '*stream identity divergence*count-mismatch*')   (expect True)
  error trail committed      : $(Test-Path -LiteralPath $divCommittedErrPath)   (expect True)
  hook-errors.log:
    $($divErrTxt.Trim())
"@
Check -Id 'G4' -Title 'a manifest can no longer read clean over a divergent store: finalize records the divergence' `
      -Ok ($null -ne $divMan -and $divMan.hook_errors_present -eq $true -and
           ($divErrTxt -like '*stream identity divergence*count-mismatch*') -and
           (Test-Path -LiteralPath $divCommittedErrPath)) -Detail $detail
Write-Reach "the pre-cure instances finalized entry_count 15 over 14 files with hook_errors_present false; this drives the same divergence shape on a fixture and requires it recorded"

# =============================================================================
# G5 -- DETECTOR FIRES, PER MEMBER (dispatch ACCEPTANCE 2; design SS4.5 law 4)
# =============================================================================
# (a) missing stream file        -- integrity member, via a manifest fixture on disk
# (b) mismatched stream bytes    -- integrity member, via a manifest fixture on disk
# (c) duplicate declared path    -- identity member, isolated (file population kept consistent)
# (d) count divergence (orphan)  -- identity member, isolated (no duplicate present)
$fxAPath = Join-Path $SandboxPath 'g5-missing'
New-Item -ItemType Directory -Path (Join-Path $fxAPath 'streams') -Force | Out-Null
$manA = [ordered]@{ entries = @([ordered]@{ ts = 'x'; tool = 'Bash'; command = 'c'; exit_code = $null
    stdout_sha256 = (Get-Sha256OfString 'gone'); stderr_sha256 = (Get-Sha256OfString ''); path = 'streams/000001.json' }) }
[System.IO.File]::WriteAllText((Join-Path $fxAPath 'manifest.json'), ($manA | ConvertTo-Json -Depth 8),
    (New-Object System.Text.UTF8Encoding($false)))
$resA = Test-EvidenceStreamIntegrity -Dir $fxAPath
$aFired = (@($resA.mismatches | Where-Object { $_.problem -eq 'stream file missing' }).Count -eq 1)

$fxBPath = Join-Path $SandboxPath 'g5-mismatch'
New-Item -ItemType Directory -Path (Join-Path $fxBPath 'streams') -Force | Out-Null
$bodyB = [ordered]@{ seq = 1; tool = 'Bash'; stdout = 'the wrong bytes'; stderr = '' }
[System.IO.File]::WriteAllText((Join-Path $fxBPath 'streams\000001.json'), ($bodyB | ConvertTo-Json -Depth 8),
    (New-Object System.Text.UTF8Encoding($false)))
$manB = [ordered]@{ entries = @([ordered]@{ ts = 'x'; tool = 'Bash'; command = 'c'; exit_code = $null
    stdout_sha256 = (Get-Sha256OfString 'the right bytes'); stderr_sha256 = (Get-Sha256OfString ''); path = 'streams/000001.json' }) }
[System.IO.File]::WriteAllText((Join-Path $fxBPath 'manifest.json'), ($manB | ConvertTo-Json -Depth 8),
    (New-Object System.Text.UTF8Encoding($false)))
$resB = Test-EvidenceStreamIntegrity -Dir $fxBPath
$bFired = (@($resB.mismatches | Where-Object { $_.problem -like 'stdout_sha256 mismatch*' }).Count -eq 1)

$fxCPath = Join-Path $SandboxPath 'g5-duplicate'
New-Item -ItemType Directory -Path (Join-Path $fxCPath 'streams') -Force | Out-Null
foreach ($nm in @('000001.json', '000002.json', '000003.json')) {
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $fxCPath 'streams') $nm), '{}')
}
$idC = @(Get-EvidenceStreamIdentityFindings -Entries @(
    [pscustomobject]@{ path = 'streams/000001.json' },
    [pscustomobject]@{ path = 'streams/000001.json' },
    [pscustomobject]@{ path = 'streams/000002.json' }) -StreamDir (Join-Path $fxCPath 'streams'))
$cFired = (@($idC | Where-Object { $_.kind -eq 'duplicate-path' -and $_.path -eq 'streams/000001.json' }).Count -eq 1)
$cOnly  = (@($idC | Where-Object { $_.kind -ne 'duplicate-path' }).Count -eq 0)

$fxDPath = Join-Path $SandboxPath 'g5-orphan'
New-Item -ItemType Directory -Path (Join-Path $fxDPath 'streams') -Force | Out-Null
foreach ($nm in @('000001.json', '000002.json')) {
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $fxDPath 'streams') $nm), '{}')
}
$idD = @(Get-EvidenceStreamIdentityFindings -Entries @([pscustomobject]@{ path = 'streams/000001.json' }) `
    -StreamDir (Join-Path $fxDPath 'streams'))
$dFired = (@($idD | Where-Object { $_.kind -eq 'count-mismatch' }).Count -eq 1)
$dOnly  = (@($idD | Where-Object { $_.kind -ne 'count-mismatch' }).Count -eq 0)

$detail = @"
  (a) missing stream file  : fired=$aFired -- $(($resA.mismatches | ForEach-Object { $_.problem }) -join ' | ')
  (b) mismatched bytes     : fired=$bFired -- $(($resB.mismatches | ForEach-Object { $_.problem }) -join ' | ')
  (c) duplicate path       : fired=$cFired onlyThatMember=$cOnly -- $(($idC | ForEach-Object { "[$($_.kind)] $($_.path)" }) -join ' | ')
  (d) count divergence     : fired=$dFired onlyThatMember=$dOnly -- $(($idD | ForEach-Object { "[$($_.kind)] $($_.path)" }) -join ' | ')
"@
Check -Id 'G5' -Title 'detector fires per member: missing, mismatch, duplicate-path, count-mismatch' `
      -Ok ($aFired -and $bFired -and $cFired -and $cOnly -and $dFired -and $dOnly) -Detail $detail
Write-Reach "members (c) and (d) are driven in isolation from each other; (a) and (b) ride Test-EvidenceStreamIntegrity via -Dir"

# =============================================================================
# G6 -- DETECTOR SILENT ON A CLEAN SET (dispatch ACCEPTANCE 2, the other direction)
# =============================================================================
$fxEPath = Join-Path $SandboxPath 'g6-clean'
New-Item -ItemType Directory -Path (Join-Path $fxEPath 'streams') -Force | Out-Null
$cleanEntries = @()
foreach ($i in 1..2) {
    $txt = "clean payload $i"
    $bodyE = [ordered]@{ seq = $i; tool = 'Bash'; stdout = $txt; stderr = '' }
    [System.IO.File]::WriteAllText((Join-Path $fxEPath ("streams\{0:d6}.json" -f $i)), ($bodyE | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))
    $cleanEntries += [ordered]@{ ts = 'x'; tool = 'Bash'; command = "c$i"; exit_code = $null
        stdout_sha256 = (Get-Sha256OfString $txt); stderr_sha256 = (Get-Sha256OfString ''); path = ("streams/{0:d6}.json" -f $i) }
}
$manE = [ordered]@{ entries = $cleanEntries }
[System.IO.File]::WriteAllText((Join-Path $fxEPath 'manifest.json'), ($manE | ConvertTo-Json -Depth 8),
    (New-Object System.Text.UTF8Encoding($false)))
$resE = Test-EvidenceStreamIntegrity -Dir $fxEPath
# and the live G3 dispatch, finalized, must record no divergence
$stopPayload | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $HooksDirPath 'evidence-stop-finalize.ps1') -DispatchId 'a6-hook-race' | Out-Null
$raceManPath = Join-Path $evRacePath 'manifest.json'
$raceMan = if (Test-Path -LiteralPath $raceManPath) { [System.IO.File]::ReadAllText($raceManPath) | ConvertFrom-Json } else { $null }
$raceErrPath = Join-Path $evRacePath 'hook-errors.log'
$detail = @"
  constructed clean set  : checked=$($resE.checked) ok=$($resE.ok)   (expect True) -- $($resE.reason)
  live raced dispatch    : finalized=$($null -ne $raceMan) entry_count=$(if ($raceMan) { $raceMan.entry_count } else { 'n/a' })
  hook_errors_present    : $(if ($raceMan) { $raceMan.hook_errors_present } else { 'n/a' })   (expect False -- the raced store is loss-free and divergence-free)
  hook-errors.log exists : $(Test-Path -LiteralPath $raceErrPath)   (expect False)
"@
Check -Id 'G6' -Title 'detector and finalize-time check are silent on clean sets, including the raced one' `
      -Ok ($resE.ok -eq $true -and $resE.checked -eq 2 -and $null -ne $raceMan -and
           $raceMan.entry_count -eq 2 -and $raceMan.hook_errors_present -eq $false -and
           -not (Test-Path -LiteralPath $raceErrPath)) -Detail $detail
Write-Reach "a detector that cannot stay silent on a clean set proves nothing when it fires (law 6); the raced dispatch doubles as the positive control for the cure"

# =============================================================================
# G7 -- HISTORICAL DETECTION IN PLACE (operator constraint 3)
# =============================================================================
# The two REAL residue directories, read-only, via -Dir at the committed plane. SKIP if a
# directory is absent -- their disposition is D9's (DURABLE UNTRACKED, PRECONDITION-GATED) and
# this instrument must still decide at a HEAD where they are gone. When present, BOTH members
# MUST fire; silence over the known damage is a FAIL.
$residueCases = @(
    @{ id = 'G7a'; dir = '.mission\evidence\session-00004f11-0000-4000-8000-000000004f11'
       dupPath = 'streams/000013.json'; entries = 15; files = 14 },
    @{ id = 'G7b'; dir = '.mission\evidence\session-0000659f-0000-4000-8000-00000000659f'
       dupPath = 'streams/000003.json'; entries = 33; files = 32 }
)
foreach ($case in $residueCases) {
    $resDirPath = Join-Path $RepoRootPath $case.dir
    $resManPath = Join-Path $resDirPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $resManPath)) {
        Skip $case.id "historical detection on $($case.dir)" `
            "residue not on disk at this HEAD (its disposition is D9's); nothing to decide"
        continue
    }
    $resMan = [System.IO.File]::ReadAllText($resManPath) | ConvertFrom-Json
    $idR = @(Get-EvidenceStreamIdentityFindings -Entries @($resMan.entries) -StreamDir (Join-Path $resDirPath 'streams'))
    $dupHit = @($idR | Where-Object { $_.kind -eq 'duplicate-path' -and $_.path -eq $case.dupPath })
    $cntHit = @($idR | Where-Object { $_.kind -eq 'count-mismatch' })
    $intR = Test-EvidenceStreamIntegrity -Dir $resDirPath
    $detail = @"
  directory        : $($case.dir)   (read-only; nothing here writes to it)
  manifest entries : $($resMan.entry_count)   (expected $($case.entries))
  identity findings:
    $(($idR | ForEach-Object { "[$($_.kind)] $($_.problem)" }) -join "`n    ")
  full integrity   : checked=$($intR.checked) ok=$($intR.ok) -- $($intR.reason)
"@
    Check -Id $case.id -Title "historical detection in place: $($case.dir)" `
          -Ok ($dupHit.Count -eq 1 -and $cntHit.Count -eq 1) -Detail $detail
    Write-Reach ("duplicate-path must name {0}; count-mismatch must report {1} entries over {2} files; the destroyed payloads stay destroyed and stay REPORTED -- nothing is repaired (dispatch FORBIDDEN)" -f $case.dupPath, $case.entries, $case.files)
}

# =============================================================================
# G8 -- INSTRUMENT INTEGRITY (instrument laws)
# =============================================================================
$selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
$nonAscii = 0
foreach ($b in $selfBytes) { if ($b -gt 127) { $nonAscii++ } }
$hasBom = ($selfBytes.Length -ge 3 -and $selfBytes[0] -eq 0xEF -and $selfBytes[1] -eq 0xBB -and $selfBytes[2] -eq 0xBF)
$detail = @"
  own bytes        : $($selfBytes.Length)
  non-ASCII bytes  : $nonAscii   (expect 0)
  BOM              : $hasBom   (expect False)
  tree anchor      : `$PSScriptRoot = $PSScriptRoot
  counts           : derived from the Check/Skip helpers, never typed
  exit contract    : 0 clean; N = failing checks; 3 = pass-with-skips (NON-UNIQUE: three
                     failures also exits 3 -- read the summary)
"@
Check -Id 'G8' -Title 'instrument integrity: pure ASCII, BOM-less, tree-anchored, derived counts' `
      -Ok ($nonAscii -eq 0 -and -not $hasBom) -Detail $detail
Write-Reach "in-session reach is ZERO by design: an agent session cannot execute, hash, stage or Write this file (guard-denied); every figure this instrument prints is operator-run"

# --- summary ---------------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================================="
if ($failures -eq 0 -and $skips -eq 0) {
    Write-Host " ALL $checksRun CHECKS PASSED"
} elseif ($failures -eq 0) {
    Write-Host " $($checksRun - $skips)/$checksRun CHECKS PASSED, $skips SKIPPED -- exit 3 (pass-with-skips, non-unique)"
} else {
    Write-Host " $failures FAILURE(S) across $checksRun CHECK(S) -- SUITE FAILED"
}
Write-Host "=============================================================================="

$env:CLAUDE_PROJECT_DIR = $null
Remove-Item Env:\CLAUDE_PROJECT_DIR  -ErrorAction SilentlyContinue
Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue
if (-not $KeepSandbox) {
    Remove-Item -LiteralPath $SandboxPath -Recurse -Force
    Write-Host "sandbox removed: $SandboxPath"
} else {
    Write-Host "sandbox kept for inspection: $SandboxPath"
}

if ($failures -gt 0) { exit $failures }
if ($skips -gt 0) { exit 3 }
exit 0
