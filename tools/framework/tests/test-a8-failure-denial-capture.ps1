#Requires -Version 5.1
<#
.SYNOPSIS
  A8 acceptance instrument -- failure and denial capture (cure D8).
  OPERATOR-STAGED, OPERATOR-RUN.

.DESCRIPTION
  Citation convention: "design SS<n>" denotes
  docs/framework/vanguard-collective-local-modes-v2.3.md.

  WHAT THIS DECIDES, from disk, per member (design SS4.5 law 4):
    A8-1   the probe outcome is IN THE DESIGN: the placed finalizer carries the eleven-field
           Stop-payload register and the payload-path basis (content check, stable at any
           HEAD); the raw capture, where still present at its gitignored path, re-derives its
           recorded digest.
    A8-2   E5-ii END-TO-END: a real failed call's absence is DETECTABLE from the manifest --
           the call_completeness block reports failed_seen with zero unmatched.
    A8-3   E5-iii END-TO-END: a real guard denial produces a '_denied' record whose reason is
           VERBATIM the emitted decision reason, and the manifest reports it. Separate member,
           separate demonstration (law 4).
    A8-4   THE CROSS-CHECK, BOTH DIRECTIONS: a transcript denial without a guard record reads
           'incomplete'; a guard record without a transcript witness reads 'incomplete'.
    A8-5   THE NEGATIVE: an ordinary multi-call dispatch reconciles 'complete' with zero
           unmatched -- no false-gap class (dispatch ACCEPTANCE 6).
    A8-6   CONSERVATIVE DEGRADATION: no transcript_path, and a dead transcript_path, each
           derive 'unreconciled' -- stated on the artifact, never silent, never 'complete'.
    A8-7   RECORDER FAILURE DIRECTION: with the record write forced to fail, the deny STILL
           fires and the failure lands on the error trail -- denial-without-record, never
           allow.
    A8-8   the A1 negative suite carries the D8 folds (content check on the sibling file).
    A8-9   the wiring probe is DEREGISTERED: the real .claude/settings.json carries exactly
           the sealed finalizer on Stop and no probe registration.
    A8-11  stop_hook_active IS A NO-OP IN ITS ENTIRETY: on a store a normal Stop WOULD
           supersede, a re-entrant Stop changes nothing, shown by hash comparison.
  A8-10 (REGRESSION) IS THE OPERATOR'S CLAUSE, NOT A CHECK HERE: A1/A6/A7 green -- A6 or A7
  red is BLOCKING regardless of attribution (operator constraint 4) -- A2 documented exit 3,
  A3/A4/A5 red exactly on the declared moves (A3 K3a, A4 G6, A5 G9; the D12 arithmetic).
  This instrument PRINTS that contract and decides none of it; suites are run from the
  operator's terminal, and a suite not run is reported NOT RUN, never as a result.

  INSTRUMENT LAWS: (a) pure ASCII source asserting its own bytes; (b) path
  variables carry the Path suffix; (c) no native calls on any assertion path, so PS 5.1's
  native-stderr hazard has no surface here. CONTENT-ANCHORED: this file anchors to named-file
  CONTENT and fixture-driven behaviour, never to a population a ceremony perturbs and never
  to its own build's digests (the digest anchors live in A3/A5, where the D12 stale-anchor
  class is already registered; anchoring them here too would add a second permanently-red
  member per future authorized move).

  ZERO REPO RESIDUE BY CONSTRUCTION: CLAUDE_PROJECT_DIR points every hook at a sandbox under
  .mission-runtime/ (gitignored). The only real-repo reads are content checks on placed files
  and on .claude/settings.json; nothing outside the sandbox is written.

  Exit code 0 = all checks passed. Non-zero = count of failures.
#>
[CmdletBinding()]
param(
    [switch]$KeepSandbox
)

$ErrorActionPreference = 'Stop'

$hooksDirPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'hooks'
$repoRootPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$sandboxPath  = Join-Path $repoRootPath '.mission-runtime\a8-fixture'

$failures = 0
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

if (Test-Path -LiteralPath $sandboxPath) { Remove-Item -LiteralPath $sandboxPath -Recurse -Force }
New-Item -ItemType Directory -Path $sandboxPath -Force | Out-Null
$env:CLAUDE_PROJECT_DIR = $sandboxPath

. (Join-Path $hooksDirPath 'lib\evidence-common.ps1')

Write-Host "=============================================================================="
Write-Host " A8 -- FAILURE AND DENIAL CAPTURE (cure D8)"
Write-Host "=============================================================================="
Write-Host "repo root : $repoRootPath"
Write-Host "sandbox   : $sandboxPath   (under .mission-runtime/, gitignored)"

# --- instrument law (a): this file asserts its own bytes --------------------------------------
$selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
$selfNonAscii = 0
foreach ($b in $selfBytes) { if ($b -gt 127) { $selfNonAscii++ } }
if ($selfNonAscii -ne 0 -or ($selfBytes.Length -ge 3 -and $selfBytes[0] -eq 0xEF)) {
    Write-Host ""
    Write-Host "[FAIL] SELF -- instrument bytes are not BOM-less pure ASCII (nonASCII=$selfNonAscii)"
    $failures++
}

function Invoke-Hook {
    param([string]$Script, [string]$Json)
    $p = Join-Path $hooksDirPath $Script
    $out = $Json | & powershell -NoProfile -ExecutionPolicy Bypass -File $p
    return [pscustomobject]@{ stdout = ($out -join "`n"); exit = $LASTEXITCODE }
}

function New-SynthTranscript {
    # Emits records in the DERIVED live shape: tool_use blocks with id+name,
    # tool_result blocks with tool_use_id; is_error present on errors, absent on successes.
    param([string]$OutPath, [string]$SessionId, $Calls)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($c in @($Calls)) {
        $lines.Add((@{ isSidechain = $false; sessionId = $SessionId; type = 'assistant'
                       message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = $c.id; name = $c.tool; input = @{ command = 'x' } }) } } | ConvertTo-Json -Depth 10 -Compress))
        if ($c.ContainsKey('noresult') -and $c.noresult) { continue }
        $blk = @{ type = 'tool_result'; tool_use_id = $c.id; content = [string]$c.body }
        if ($c.ContainsKey('err') -and $c.err) { $blk['is_error'] = $true }
        $lines.Add((@{ isSidechain = $false; sessionId = $SessionId; type = 'user'
                       message = @{ role = 'user'; content = @($blk) } } | ConvertTo-Json -Depth 10 -Compress))
    }
    [System.IO.File]::WriteAllText($OutPath, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

$guardDenyPreamble = 'DENIED by evidence-guard'
$okCallBody = 'ok-output'

function Invoke-SuccessCall {
    param([string]$SessionId, [string]$Command)
    $null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
        session_id = $SessionId; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
        tool_input = @{ command = $Command }
        tool_response = @{ stdout = "$okCallBody`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
}

# =============================================================================
# A8-1 -- the probe outcome is in the design (content), and the capture re-derives
# =============================================================================
$finalizerPath = Join-Path $hooksDirPath 'evidence-stop-finalize.ps1'
$finalizerTxt  = [System.IO.File]::ReadAllText($finalizerPath)
$elevenA = 'session_id, transcript_path, cwd, prompt_id, permission_mode, effort, hook_event_name'
$elevenB = 'stop_hook_active, last_assistant_message, background_tasks, session_crons'
$hasEleven   = ($finalizerTxt -like "*$elevenA*") -and ($finalizerTxt -like "*$elevenB*")
$hasCapture  = ($finalizerTxt -like '*b0eb6687*')
$hasHygiene  = ($finalizerTxt -like '*last_assistant_message IS NEVER READ AND NEVER RECORDED*')
$hasReentry  = ($finalizerTxt -like '*stop_hook_active*') -and ($finalizerTxt -like '*RE-ENTRY GUARD*')

$capturePath = Join-Path $repoRootPath '.claude\wiring-probe-out\probe-20260811T150044026-Stop-1b98edcc.bin'
$captureExpected = 'B0EB6687A6B66436C8D4721BC24E19FE280D18E11276A4DA032F8D454F2FC6EA'
$captureNote = 'capture absent at its gitignored path (cleaned)'
$captureOk = $true
if (Test-Path -LiteralPath $capturePath) {
    $captureActual = (Get-FileHash -Algorithm SHA256 -LiteralPath $capturePath).Hash
    $captureOk = ($captureActual -eq $captureExpected)
    $captureNote = "capture present, sha256 $captureActual (expect $captureExpected)"
}

$detail = @"
  finalizer names all eleven Stop-payload fields : $hasEleven
  finalizer cites the capture (b0eb6687)         : $hasCapture
  finalizer carries the content-hygiene ruling   : $hasHygiene
  finalizer carries the re-entry guard ruling    : $hasReentry
  raw capture: $captureNote
"@
Check -Id 'A8-1' -Title 'the Stop-payload derivation is in the placed design, and the raw capture re-derives where present' `
      -Ok ($hasEleven -and $hasCapture -and $hasHygiene -and $hasReentry -and $captureOk) -Detail $detail

# =============================================================================
# A8-2 -- E5-ii end-to-end: a real failed call is DETECTABLE from the manifest
# =============================================================================
$d2 = 'a8-e5ii'
$env:MISSION_DISPATCH_ID = $d2
$ev2Path = Join-Path $sandboxPath ".mission-runtime\evidence\$d2"
Invoke-SuccessCall -SessionId 'sess-a8-e5ii' -Command 'echo the-one-logged-call'

# BEFORE: the absence, shown -- one logged entry, no hook error, nothing about the failure.
$preLines = @([System.IO.File]::ReadAllLines((Join-Path $ev2Path 'log.jsonl')) | Where-Object { $_.Trim() })
$preErr   = Test-Path -LiteralPath (Join-Path $ev2Path 'hook-errors.log')

$tr2Path = Join-Path $sandboxPath 'a8-e5ii-transcript.jsonl'
New-SynthTranscript -OutPath $tr2Path -SessionId 'sess-a8-e5ii' -Calls @(
    @{ id = 'ok-1';   tool = 'Bash'; body = $okCallBody },
    @{ id = 'fail-1'; tool = 'Read'; body = 'File does not exist.'; err = $true }
)
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-e5ii'; hook_event_name = 'Stop'; transcript_path = $tr2Path } | ConvertTo-Json -Compress)
$man2 = [System.IO.File]::ReadAllText((Join-Path $ev2Path 'manifest.json')) | ConvertFrom-Json
$cc2 = Get-EntryField $man2 'call_completeness' $null

$detail = @"
  BEFORE (the absence, live): log lines=$($preLines.Count) (the failed call is not among them);
  hook-errors.log exists=$preErr (expect False); no gap by construction.
  AFTER (the detector):
    status / basis / unmatched : $(if ($cc2) { "$($cc2.status) / $($cc2.basis) / $($cc2.unmatched)" } else { 'MISSING' })   (expect complete / payload-transcript-path / 0)
    failed_seen                : $(if ($cc2) { $cc2.failed_seen } else { 'n/a' })   (expect 1 -- THE FAILED CALL, NAMED IN COUNT on the committed artifact)
    logged_entries / N         : $(if ($cc2) { "$($cc2.logged_entries) / $($cc2.transcript_calls)" } else { 'n/a' })   (expect 1 / 2)
    transcript anchor          : $(if ($cc2) { $cc2.transcript_sha256 -eq (Get-Sha256OfFile -Path $tr2Path) } else { 'n/a' })   (re-derives)
"@
Check -Id 'A8-2' -Title 'E5-ii: a failed call produces a reconciliation record that names it (failed_seen=1, zero unmatched)' `
      -Ok ($preLines.Count -eq 1 -and -not $preErr -and $null -ne $cc2 -and
           $cc2.status -eq 'complete' -and $cc2.unmatched -eq 0 -and $cc2.failed_seen -eq 1 -and
           $cc2.logged_entries -eq 1 -and $cc2.transcript_calls -eq 2 -and
           $cc2.transcript_sha256 -eq (Get-Sha256OfFile -Path $tr2Path)) -Detail $detail

# =============================================================================
# A8-3 -- E5-iii end-to-end: a real denial produces a guard-written record, verbatim
# =============================================================================
$d3 = 'a8-e5iii'
$env:MISSION_DISPATCH_ID = $d3
$ev3Path = Join-Path $sandboxPath ".mission-runtime\evidence\$d3"
$rDeny = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json (@{
    session_id = 'sess-a8-e5iii'; hook_event_name = 'PreToolUse'; tool_name = 'Write'
    tool_input = @{ file_path = '.mission-runtime/evidence/x/log.jsonl'; content = 'forged' } } | ConvertTo-Json -Depth 8 -Compress)
$emitted = $null
try { $emitted = ($rDeny.stdout | ConvertFrom-Json).hookSpecificOutput.permissionDecisionReason } catch { }
$recs3 = @(Read-EvidenceLog -LogPath (Join-Path $ev3Path 'log.jsonl'))
$den3 = @($recs3 | Where-Object { ([string](Get-EntryField $_ 'tool' '')) -eq '_denied' })
$verbatimMatch = ($den3.Count -eq 1 -and $null -ne $emitted -and ([string]$den3[0].reason) -eq [string]$emitted)

Invoke-SuccessCall -SessionId 'sess-a8-e5iii' -Command 'echo after-the-denial'
$tr3Path = Join-Path $sandboxPath 'a8-e5iii-transcript.jsonl'
New-SynthTranscript -OutPath $tr3Path -SessionId 'sess-a8-e5iii' -Calls @(
    @{ id = 'deny-1'; tool = 'Write'; body = "$guardDenyPreamble (AM-417 / design SS4.1 layer c): tool 'Write' targets the protected path '.mission-runtime/evidence'."; err = $true },
    @{ id = 'ok-1';   tool = 'Bash';  body = $okCallBody }
)
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-e5iii'; hook_event_name = 'Stop'; transcript_path = $tr3Path } | ConvertTo-Json -Compress)
$man3 = [System.IO.File]::ReadAllText((Join-Path $ev3Path 'manifest.json')) | ConvertFrom-Json
$cc3 = Get-EntryField $man3 'call_completeness' $null
$manDen3 = @()
foreach ($e in @($man3.entries)) { if ([string](Get-EntryField $e 'tool' '') -eq '_denied') { $manDen3 += $e } }

$detail = @"
  guard exit / decision       : $($rDeny.exit) / deny (expect 2 / deny)
  '_denied' records in log    : $($den3.Count)   (expect 1)
  record reason == emitted    : $verbatimMatch   (VERBATIM equality of the two texts)
  manifest '_denied' entries  : $($manDen3.Count)   (expect 1 -- the refusal on the committed artifact)
  status / D / D-records / U  : $(if ($cc3) { "$($cc3.status) / $($cc3.denied_seen) / $($cc3.denied_records) / $($cc3.unmatched)" } else { 'MISSING' })   (expect complete / 1 / 1 / 0)
"@
Check -Id 'A8-3' -Title 'E5-iii: a denied call produces a guard-written record, verbatim, and the manifest reports it' `
      -Ok ($rDeny.exit -eq 2 -and $verbatimMatch -and $manDen3.Count -eq 1 -and
           $null -ne $cc3 -and $cc3.status -eq 'complete' -and $cc3.denied_seen -eq 1 -and
           $cc3.denied_records -eq 1 -and $cc3.unmatched -eq 0) -Detail $detail

# =============================================================================
# A8-4 -- the cross-check, both directions
# =============================================================================
# Direction (i): the transcript resolved a denial the guard never recorded.
$d4a = 'a8-xchk-nodrec'
$env:MISSION_DISPATCH_ID = $d4a
Invoke-SuccessCall -SessionId 'sess-a8-x1' -Command 'echo x1'
$tr4aPath = Join-Path $sandboxPath 'a8-x1-transcript.jsonl'
New-SynthTranscript -OutPath $tr4aPath -SessionId 'sess-a8-x1' -Calls @(
    @{ id = 'ok-1';   tool = 'Bash';  body = $okCallBody },
    @{ id = 'deny-1'; tool = 'Write'; body = "$guardDenyPreamble (AM-417 / design SS4.1 layer c): x."; err = $true }
)
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-x1'; hook_event_name = 'Stop'; transcript_path = $tr4aPath } | ConvertTo-Json -Compress)
$cc4a = Get-EntryField ([System.IO.File]::ReadAllText((Join-Path $sandboxPath ".mission-runtime\evidence\$d4a\manifest.json")) | ConvertFrom-Json) 'call_completeness' $null

# Direction (ii): the guard recorded a denial the transcript does not witness.
$d4b = 'a8-xchk-notx'
$env:MISSION_DISPATCH_ID = $d4b
$null = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json (@{
    session_id = 'sess-a8-x2'; hook_event_name = 'PreToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'rm -rf .mission-runtime' } } | ConvertTo-Json -Depth 8 -Compress)
Invoke-SuccessCall -SessionId 'sess-a8-x2' -Command 'echo x2'
$tr4bPath = Join-Path $sandboxPath 'a8-x2-transcript.jsonl'
New-SynthTranscript -OutPath $tr4bPath -SessionId 'sess-a8-x2' -Calls @(
    @{ id = 'ok-1'; tool = 'Bash'; body = $okCallBody }
)
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-x2'; hook_event_name = 'Stop'; transcript_path = $tr4bPath } | ConvertTo-Json -Compress)
$cc4b = Get-EntryField ([System.IO.File]::ReadAllText((Join-Path $sandboxPath ".mission-runtime\evidence\$d4b\manifest.json")) | ConvertFrom-Json) 'call_completeness' $null

$detail = @"
  (i)  transcript denial, no guard record : $(if ($cc4a) { "$($cc4a.status) unmatched=$($cc4a.unmatched) D=$($cc4a.denied_seen) D-records=$($cc4a.denied_records)" } else { 'MISSING' })   (expect incomplete, unmatched>=1, D=1, D-records=0)
  (ii) guard record, no transcript denial : $(if ($cc4b) { "$($cc4b.status) unmatched=$($cc4b.unmatched) D=$($cc4b.denied_seen) D-records=$($cc4b.denied_records)" } else { 'MISSING' })   (expect incomplete, unmatched>=1, D=0, D-records=1)
"@
Check -Id 'A8-4' -Title 'denial recorders cross-check in both directions; divergence reads incomplete, not reconciled-away' `
      -Ok ($null -ne $cc4a -and $cc4a.status -eq 'incomplete' -and $cc4a.unmatched -ge 1 -and
           $cc4a.denied_seen -eq 1 -and $cc4a.denied_records -eq 0 -and
           $null -ne $cc4b -and $cc4b.status -eq 'incomplete' -and $cc4b.unmatched -ge 1 -and
           $cc4b.denied_seen -eq 0 -and $cc4b.denied_records -eq 1) -Detail $detail

# =============================================================================
# A8-5 -- the negative: ordinary work reconciles clean (no false-gap class)
# =============================================================================
$d5 = 'a8-negative'
$env:MISSION_DISPATCH_ID = $d5
$n5 = 4
$calls5 = @()
for ($i = 1; $i -le $n5; $i++) {
    Invoke-SuccessCall -SessionId 'sess-a8-neg' -Command "echo neg-$i"
    $calls5 += @{ id = "ok-$i"; tool = 'Bash'; body = $okCallBody }
}
$tr5Path = Join-Path $sandboxPath 'a8-neg-transcript.jsonl'
New-SynthTranscript -OutPath $tr5Path -SessionId 'sess-a8-neg' -Calls $calls5
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-neg'; hook_event_name = 'Stop'; transcript_path = $tr5Path } | ConvertTo-Json -Compress)
$cc5 = Get-EntryField ([System.IO.File]::ReadAllText((Join-Path $sandboxPath ".mission-runtime\evidence\$d5\manifest.json")) | ConvertFrom-Json) 'call_completeness' $null

$detail = @"
  status / unmatched / F / D : $(if ($cc5) { "$($cc5.status) / $($cc5.unmatched) / $($cc5.failed_seen) / $($cc5.denied_seen)" } else { 'MISSING' })   (expect complete / 0 / 0 / 0)
  N / M                      : $(if ($cc5) { "$($cc5.transcript_calls) / $($cc5.logged_entries)" } else { 'n/a' })   (expect $n5 / $n5 -- counts derived)
"@
Check -Id 'A8-5' -Title 'the negative: an ordinary multi-call dispatch reads complete with zero unmatched -- no false gap' `
      -Ok ($null -ne $cc5 -and $cc5.status -eq 'complete' -and $cc5.unmatched -eq 0 -and
           $cc5.failed_seen -eq 0 -and $cc5.denied_seen -eq 0 -and
           $cc5.transcript_calls -eq $n5 -and $cc5.logged_entries -eq $n5) -Detail $detail

# =============================================================================
# A8-6 -- conservative degradation: absent path and dead path both read 'unreconciled'
# =============================================================================
$d6a = 'a8-degrade-none'
$env:MISSION_DISPATCH_ID = $d6a
Invoke-SuccessCall -SessionId 'sess-a8-d1' -Command 'echo d1'
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-d1'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)
$cc6a = Get-EntryField ([System.IO.File]::ReadAllText((Join-Path $sandboxPath ".mission-runtime\evidence\$d6a\manifest.json")) | ConvertFrom-Json) 'call_completeness' $null

$d6b = 'a8-degrade-dead'
$env:MISSION_DISPATCH_ID = $d6b
Invoke-SuccessCall -SessionId 'sess-a8-d2' -Command 'echo d2'
$deadPath = Join-Path $sandboxPath 'no-such-transcript.jsonl'
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-d2'; hook_event_name = 'Stop'; transcript_path = $deadPath } | ConvertTo-Json -Compress)
$cc6b = Get-EntryField ([System.IO.File]::ReadAllText((Join-Path $sandboxPath ".mission-runtime\evidence\$d6b\manifest.json")) | ConvertFrom-Json) 'call_completeness' $null

$detail = @"
  no transcript_path : $(if ($cc6a) { "$($cc6a.status) basis=$($cc6a.basis)" } else { 'MISSING' })   (expect unreconciled basis=none)
  dead transcript_path: $(if ($cc6b) { "$($cc6b.status) basis=$($cc6b.basis)" } else { 'MISSING' })   (expect unreconciled basis=payload-transcript-path)
  neither asserts 'complete'; the block is PRESENT in both -- stated, never silent.
"@
Check -Id 'A8-6' -Title 'degradation is conservative and stated: unreconciled on absent or dead transcript, never a fabricated verdict' `
      -Ok ($null -ne $cc6a -and $cc6a.status -eq 'unreconciled' -and $cc6a.basis -eq 'none' -and
           $null -ne $cc6b -and $cc6b.status -eq 'unreconciled' -and $cc6b.basis -eq 'payload-transcript-path') -Detail $detail

# =============================================================================
# A8-7 -- recorder failure direction: the deny still fires; the failure is on the trail
# =============================================================================
$d7 = 'a8-recfail'
$env:MISSION_DISPATCH_ID = $d7
$ev7Path = Join-Path $sandboxPath ".mission-runtime\evidence\$d7"
# Force the record write to fail: a DIRECTORY at the log.jsonl path.
New-Item -ItemType Directory -Path (Join-Path $ev7Path 'log.jsonl') -Force | Out-Null
$rFail = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json (@{
    session_id = 'sess-a8-rf'; hook_event_name = 'PreToolUse'; tool_name = 'Write'
    tool_input = @{ file_path = '.mission/evidence/x/manifest.json'; content = 'forged' } } | ConvertTo-Json -Depth 8 -Compress)
$err7Path = Join-Path $ev7Path 'hook-errors.log'
$err7Txt = if (Test-Path -LiteralPath $err7Path) { [System.IO.File]::ReadAllText($err7Path) } else { '' }

$detail = @"
  guard exit                : $($rFail.exit)   (expect 2 -- the deny fired regardless)
  stdout carries deny       : $($rFail.stdout -like '*"permissionDecision":"deny"*')   (expect True)
  trail records the failure : $($err7Txt -like '*denial record failed*')   (expect True -- denial-without-record, disclosed)
"@
Check -Id 'A8-7' -Title 'a record-write failure never turns a deny into an allow; the failure lands on the error trail' `
      -Ok ($rFail.exit -eq 2 -and ($rFail.stdout -like '*"permissionDecision":"deny"*') -and
           ($err7Txt -like '*denial record failed*')) -Detail $detail

# =============================================================================
# A8-8 -- the A1 suite carries the D8 folds (content check on the sibling file)
# =============================================================================
$a1Path = Join-Path $PSScriptRoot 'test-a1-negative.ps1'
$a1Txt  = [System.IO.File]::ReadAllText($a1Path)
$a1HasFoldNote  = ($a1Txt -like '*D8 NOTE: failure-and-denial-capture coverage*')
$a1HasRecFold   = ($a1Txt -like "*D8 FOLD ASSERTIONS: one '_denied' record per deny case*")
$a1HasCcFold    = ($a1Txt -like '*call_completeness*')
$a1HasReentry   = ($a1Txt -like '*stop_hook_active*')

$detail = @"
  docstring fold note   : $a1HasFoldNote
  '_denied' record fold : $a1HasRecFold
  completeness fold     : $a1HasCcFold
  re-entry no-op fold   : $a1HasReentry
"@
Check -Id 'A8-8' -Title 'the A1 negative suite carries every D8 detector fold on its face' `
      -Ok ($a1HasFoldNote -and $a1HasRecFold -and $a1HasCcFold -and $a1HasReentry) -Detail $detail

# =============================================================================
# A8-9 -- the wiring probe is deregistered from the real settings
# =============================================================================
$settingsPath = Join-Path $repoRootPath '.claude\settings.json'
$probeAbsent = $true; $stopHookCount = -1; $stopMarkerOk = $false; $settingsNote = ''
if (Test-Path -LiteralPath $settingsPath) {
    $settingsTxt = [System.IO.File]::ReadAllText($settingsPath)
    $probeAbsent = ($settingsTxt -notlike '*wiring-probe*')
    try {
        $settingsObj = $settingsTxt | ConvertFrom-Json
        $stopHooks = @($settingsObj.hooks.Stop[0].hooks)
        $stopHookCount = $stopHooks.Count
        $stopMarkerOk = ($stopHookCount -eq 1 -and ([string]$stopHooks[0].command) -like '*tools/framework/hooks/evidence-stop-finalize.ps1*')
    } catch { $settingsNote = 'settings.json present but unparsable' }
} else {
    $settingsNote = 'settings.json ABSENT -- hooks are off; no probe registration can exist'
    $stopMarkerOk = $true; $stopHookCount = 0
}

$detail = @"
  settings.json           : $(if ($settingsNote) { $settingsNote } else { 'present, parsed' })
  probe registration      : $(if ($probeAbsent) { 'ABSENT (verified)' } else { 'PRESENT <-- FAIL' })
  Stop hooks / marker ok  : $stopHookCount / $stopMarkerOk   (expect 1 / True when hooks are installed)
"@
Check -Id 'A8-9' -Title 'the probe is deregistered: Stop carries the sealed finalizer alone, no probe registration anywhere' `
      -Ok ($probeAbsent -and $stopMarkerOk) -Detail $detail

# =============================================================================
# A8-11 -- stop_hook_active is a NO-OP in its entirety, on a store that WOULD supersede
# =============================================================================
$d11 = 'a8-reentry'
$env:MISSION_DISPATCH_ID = $d11
$ev11Path = Join-Path $sandboxPath ".mission-runtime\evidence\$d11"
Invoke-SuccessCall -SessionId 'sess-a8-re' -Command 'echo re-1'
$tr11Path = Join-Path $sandboxPath 'a8-re-transcript.jsonl'
New-SynthTranscript -OutPath $tr11Path -SessionId 'sess-a8-re' -Calls @(@{ id = 'ok-1'; tool = 'Bash'; body = $okCallBody })
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-re'; hook_event_name = 'Stop'; transcript_path = $tr11Path } | ConvertTo-Json -Compress)
# grow the log so a NORMAL Stop would supersede -- the sharpest possible no-op subject
Invoke-SuccessCall -SessionId 'sess-a8-re' -Command 'echo re-2'
$before11 = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $ev11Path -File -Recurse)) { $before11[$f.FullName] = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash }
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-a8-re'; hook_event_name = 'Stop'; stop_hook_active = $true
    transcript_path = $tr11Path } | ConvertTo-Json -Compress)
$after11 = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $ev11Path -File -Recurse)) { $after11[$f.FullName] = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash }
$sameCount = ($before11.Count -eq $after11.Count)
$sameBytes = $true
foreach ($k in $before11.Keys) {
    if (-not $after11.ContainsKey($k) -or $after11[$k] -ne $before11[$k]) { $sameBytes = $false }
}
$noSup2 = -not (Test-Path -LiteralPath (Join-Path $ev11Path 'manifest.superseded-001.json'))

$detail = @"
  store files before/after   : $($before11.Count) / $($after11.Count)   (expect equal)
  every byte identical       : $sameBytes   (expect True -- nothing ran)
  no supersession happened   : $noSup2   (expect True -- a normal Stop here WOULD have superseded)
"@
Check -Id 'A8-11' -Title 'a re-entrant Stop (stop_hook_active=true) changes nothing, even where a normal Stop would supersede' `
      -Ok ($sameCount -and $sameBytes -and $noSup2) -Detail $detail

# --- A8-10: the operator's regression clause, printed, not decided ---------------------------
Write-Host ""
Write-Host "[INFO] A8-10 -- REGRESSION IS THE OPERATOR'S CLAUSE, run from the operator's terminal:"
Write-Host "  A1 negative       expect exit 0 (D8 folds included)"
Write-Host "  A6 stream identity expect exit 0 -- RED IS BLOCKING regardless of attribution (constraint 4)"
Write-Host "  A7 lifecycle       expect exit 0 -- RED IS BLOCKING regardless of attribution (constraint 4)"
Write-Host "  A2                 documented exit 3 (post-seal, unchanged)"
Write-Host "  A3 / A4 / A5       expect red EXACTLY on the declared moves (D12 arithmetic)"
Write-Host "  Any suite not run is reported NOT RUN with the denial cited -- never as a result."

# --- summary ---------------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================================="
if ($failures -eq 0) { Write-Host " ALL $checksRun CHECKS PASSED" } else { Write-Host " $failures FAILURE(S) across $checksRun CHECK(S) -- SUITE FAILED" }
Write-Host "=============================================================================="

if (-not $KeepSandbox) {
    Remove-Item -LiteralPath $sandboxPath -Recurse -Force
    Write-Host "sandbox removed: $sandboxPath"
} else {
    Write-Host "sandbox kept for inspection: $sandboxPath"
}
Remove-Item Env:\CLAUDE_PROJECT_DIR  -ErrorAction SilentlyContinue
Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue

exit $failures
