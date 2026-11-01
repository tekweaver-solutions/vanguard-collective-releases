#Requires -Version 5.1
<#
.SYNOPSIS
  A1 acceptance test -- the negative test.

.DESCRIPTION
  Citation convention: LM2-ADR-0NN / "design SS<n>" denote
  docs/framework/vanguard-collective-local-modes-v2.1.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/.

  ACCEPTANCE CLAUSE, and its true source. The clause below is quoted from the OPERATOR'S A1
  BUILD-DISPATCH KICKOFF PROMPT -- it is NOT text in the amendment, and earlier revisions of this file
  wrongly attributed it to the amendment. A validator caught the misattribution; the operator
  supplied the provenance. Cite the build dispatch, not the amendment:

    "in a scratch session/simulation, a deliberately false sha in prose is contradicted by the
     hook-captured log -- show both, side by side."

  Checks: no inventory is written here. A hand-maintained list of checks drifts exactly the way
  a hand-maintained count does -- this docstring listed N1-N6 while eleven checks ran. Each
  check states its own purpose at its own definition, and the suite prints its own total.
  D10 NOTE: lifecycle coverage -- GREW, append-verified supersession, and the
  preserved TAMPERED directions -- is FOLDED into N5's slot rather than appended as new
  checks, because the threat-notes mirror freezes the check tally.
  D8 NOTE: failure-and-denial-capture coverage -- the guard's '_denied' records, the
  call_completeness matrix (complete / incomplete / unreconciled), and the stop_hook_active
  re-entry no-op -- is FOLDED into N2, N4 and N7's slots, under the same rule.

  ZERO REPO RESIDUE BY CONSTRUCTION. The test sets CLAUDE_PROJECT_DIR to a sandbox under
  .mission-runtime/ (gitignored), so every path the hooks resolve -- including the committed
  plane .mission/evidence/ -- lands inside that sandbox and never in the real repository.
  The only command run against the real repo is `git rev-parse HEAD`, which is read-only and
  is the whole point: N1 needs a REAL anchor to contradict.

  Exit code 0 = all checks passed. Non-zero = count of failures.
#>
[CmdletBinding()]
param(
    [switch]$KeepSandbox
)

$ErrorActionPreference = 'Stop'

$hooksDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'hooks'
# Finding 4: $repoRoot is anchored to THIS SCRIPT, never to the caller's cwd.
# Previously it came from `git rev-parse --show-toplevel`, so a copy of the test run from
# another directory validated N10 against a DIFFERENT tree's threat notes -- and printed green
# on a mutated copy. A test whose subject depends on where it was invoked from is not a test.
# tools/framework/tests/<this file>  ->  up three  ->  repo root
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$sandbox  = Join-Path $repoRoot '.mission-runtime\a1-negative-test'
$dispatch = 'a1-negative-test'

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

# --- sandbox -------------------------------------------------------------------------------
if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$env:CLAUDE_PROJECT_DIR  = $sandbox
$env:MISSION_DISPATCH_ID = $dispatch

Write-Host "=============================================================================="
Write-Host " A1 NEGATIVE TEST"
Write-Host "=============================================================================="
Write-Host "repo root : $repoRoot"
Write-Host "sandbox   : $sandbox   (under .mission-runtime/, gitignored)"
Write-Host "dispatch  : $dispatch"

$evDir   = Join-Path $sandbox ".mission-runtime\evidence\$dispatch"
$logPath = Join-Path $evDir 'log.jsonl'
$manPath = Join-Path $evDir 'manifest.json'

function Invoke-Hook {
    param([string]$Script, [string]$Json)
    $p = Join-Path $hooksDir $Script
    $out = $Json | & powershell -NoProfile -ExecutionPolicy Bypass -File $p
    return [pscustomobject]@{ stdout = ($out -join "`n"); exit = $LASTEXITCODE }
}

# =============================================================================
# N1 -- a deliberately FALSE sha in prose, contradicted by the hook-captured log
# =============================================================================
# The real anchor. This is the only command run against the real repository.
$realSha = (& git -C $repoRoot rev-parse HEAD).Trim()

# Simulate the harness delivering a PostToolUse event for that command.
$payload = @{
    session_id    = 'sess-a1-negative'
    hook_event_name = 'PostToolUse'
    tool_name     = 'Bash'
    tool_input    = @{ command = 'git rev-parse HEAD' }
    tool_response = @{ stdout = "$realSha`n"; stderr = ''; exit_code = 0 }
} | ConvertTo-Json -Depth 8 -Compress

$r = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json $payload

# The report the agent WOULD have written. The sha is deliberately wrong: first hex digit
# rotated. Everything else about the sentence is plausible, which is the failure mode.
$flipped  = '{0:x}' -f ((([Convert]::ToInt32($realSha.Substring(0,1), 16)) + 1) % 16)
$falseSha = $flipped + $realSha.Substring(1)
if ($falseSha -eq $realSha) { throw "test fixture defect: false sha equals real sha" }
if ($falseSha -notmatch '^[0-9a-f]{40}$') { throw "test fixture defect: false sha is not 40 hex chars -- '$falseSha'" }
$mockReport = "Ceremony complete. Committed at HEAD $falseSha with a clean tree."

# The comparator: pull the anchor out of the LOG, not out of the prose.
$log = @()
if (Test-Path -LiteralPath $logPath) {
    foreach ($line in [System.IO.File]::ReadAllLines($logPath)) {
        if ($line.Trim()) { $log += ($line | ConvertFrom-Json) }
    }
}
$anchorEntry = $log | Where-Object { $_.command -eq 'git rev-parse HEAD' } | Select-Object -First 1
$capturedSha = if ($anchorEntry) { ([string]$anchorEntry.stdout).Trim() } else { '<NO EVIDENCE CAPTURED>' }
$claimedSha  = if ($mockReport -match '\b([0-9a-f]{40})\b') { $Matches[1] } else { '<NO SHA IN PROSE>' }

$detail = @"
  hook exit code            : $($r.exit)
  log entries captured      : $($log.Count)

  SIDE BY SIDE
    claimed in agent prose  : $claimedSha
    captured by the hook    : $capturedSha
    real (git rev-parse)    : $realSha
    verdict                 : $(if ($claimedSha -ne $capturedSha) { 'CONTRADICTED -- report blocked' } else { 'agreement' })

  agent prose, verbatim:
    $mockReport

  log entry, verbatim:
    $((Get-Content -LiteralPath $logPath -TotalCount 1))
"@
# The assertion is deliberately strict about the FIXTURE as well as the result: the prose must
# actually contain a well-formed 40-hex sha. A malformed fixture would otherwise satisfy
# "claimed != captured" trivially and report a PASS for a test that checked nothing. (Found the
# hard way: the first version of this test did exactly that.)
Check -Id 'N1' -Title 'false sha in prose is contradicted by hook-captured log' `
      -Ok ($capturedSha -eq $realSha -and
           $claimedSha -match '^[0-9a-f]{40}$' -and
           $claimedSha -eq $falseSha -and
           $claimedSha -ne $capturedSha -and
           $log.Count -ge 1) -Detail $detail

# =============================================================================
# N2 -- the PreToolUse guard denies a write aimed at an evidence path
#       + D8: every deny leaves a '_denied' record; no allow writes one
# =============================================================================
# Every case below that must DENY. The path-shape variants (cure B3) were
# demonstrated by a validator writing to the SAME guarded file while the pre-cure guard
# allowed them; the machinery cases (cure B4) were demonstrated as unprotected entirely.
# D8 FOLD: the guard cases run under their OWN dispatch id, so the '_denied' records they
# produce can be counted against the deny population without perturbing the main dispatch's
# entry counts (N4/N5 semantics unchanged).
$denyCases = @(
    # --- cure B6: destructive/relocating commands naming a parent directory. A
    #     validator proved each of these erasing the runtime record and leaving a clean,
    #     consumable, self-consistent manifest behind.
    @{ n = 'rm -rf .mission-runtime';    t = 'Bash';       i = @{ command = 'rm -rf .mission-runtime' } },
    @{ n = 'rm -rf .mission';            t = 'Bash';       i = @{ command = 'rm -rf .mission' } },
    @{ n = 'rm -rf .mission-runtime/ev*';t = 'Bash';       i = @{ command = 'rm -rf .mission-runtime/ev*' } },
    @{ n = 'mv .mission-runtime away';   t = 'Bash';       i = @{ command = 'mv .mission-runtime /tmp/x' } },
    @{ n = 'Remove-Item -Recurse';       t = 'PowerShell'; i = @{ command = 'Remove-Item -Recurse -Force .mission-runtime' } },
    @{ n = 'git clean -xfd';             t = 'Bash';       i = @{ command = 'git clean -xfd' } },
    @{ n = 'rm -rf tools/framework';     t = 'Bash';       i = @{ command = 'rm -rf tools/framework' } },
    # --- cure B7: the uninstall CATEGORY, proven -- not one spelling claimed as a category.
    @{ n = 'rm -rf .claude';             t = 'Bash';       i = @{ command = 'rm -rf .claude' } },
    @{ n = 'rm -f .claude/settings*';    t = 'Bash';       i = @{ command = 'rm -f .claude/settings*' } },
    # --- cure NB-5 deny-side twins: every exemption must not itself be a bypass.
    @{ n = 'git add a hook script';      t = 'Bash';       i = @{ command = 'git add tools/framework/hooks/evidence-post-tool-use.ps1' } },
    @{ n = 'git add the test';           t = 'Bash';       i = @{ command = 'git add tools/framework/tests/test-a1-negative.ps1' } },
    @{ n = 'git commit a hook script';   t = 'Bash';       i = @{ command = 'git commit -- tools/framework/hooks/evidence-guard-pretooluse.ps1' } },
    @{ n = 'readonly THEN destructive';  t = 'Bash';       i = @{ command = 'cat README.md && rm -rf .mission-runtime' } },
    @{ n = 'readonly THEN evidence wr';  t = 'Bash';       i = @{ command = 'ls -la ; echo forged >> .mission/evidence/x/log.jsonl' } },
    @{ n = 'git checkout evidence';      t = 'Bash';       i = @{ command = 'git checkout -- .mission/evidence' } },
    @{ n = 'plain evidence path';        t = 'Write';      i = @{ file_path = '.mission-runtime/evidence/a1-negative-test/log.jsonl'; content = 'forged' } },
    @{ n = 'dot segment  /./';           t = 'Write';      i = @{ file_path = '.mission-runtime/./evidence/x/log.jsonl'; content = 'forged' } },
    @{ n = 'double separator  //';       t = 'Write';      i = @{ file_path = '.mission-runtime//evidence/x/log.jsonl'; content = 'forged' } },
    @{ n = 'parent hop  zz/..';          t = 'Write';      i = @{ file_path = '.mission-runtime/zz/../evidence/x/log.jsonl'; content = 'forged' } },
    @{ n = 'dot segment in .mission';    t = 'Write';      i = @{ file_path = '.mission/./evidence/x/manifest.json'; content = 'forged' } },
    @{ n = 'backslash spelling';         t = 'Write';      i = @{ file_path = '.mission-runtime\evidence\x\log.jsonl'; content = 'forged' } },
    @{ n = 'bash cd then write';         t = 'Bash';       i = @{ command = 'cd .mission-runtime/./evidence/x && echo forged >> log.jsonl' } },
    @{ n = 'edit the PostToolUse hook';  t = 'Edit';       i = @{ file_path = 'tools/framework/hooks/evidence-post-tool-use.ps1'; old_string = 'a'; new_string = 'b' } },
    @{ n = 'edit the guard itself';      t = 'Edit';       i = @{ file_path = 'tools/framework/hooks/evidence-guard-pretooluse.ps1'; old_string = 'a'; new_string = 'b' } },
    @{ n = 'edit the shared library';    t = 'Edit';       i = @{ file_path = 'tools/framework/hooks/lib/evidence-common.ps1'; old_string = 'a'; new_string = 'b' } },
    @{ n = 'uninstall hooks (write)';    t = 'Write';      i = @{ file_path = '.claude/settings.json'; content = '{}' } },
    @{ n = 'uninstall hooks (rm)';       t = 'Bash';       i = @{ command = 'rm -f .claude/settings.json' } },
    # --- B1: the metacharacter gate. Every one of these was ALLOWED before the descope,
    #     through a read-only-verb exemption that returned before any path matching. A validator
    #     proved the first one erasing a three-entry log and leaving a clean FINALIZED manifest.
    @{ n = 'redirect into evidence';     t = 'Bash';       i = @{ command = 'printf "forged" > .mission-runtime/evidence/d/log.jsonl' } },
    @{ n = 'truncate via cat /dev/null'; t = 'Bash';       i = @{ command = 'cat /dev/null > .mission-runtime/evidence/d/log.jsonl' } },
    @{ n = 'append into evidence';       t = 'Bash';       i = @{ command = 'cat forged.txt >> .mission-runtime/evidence/d/log.jsonl' } },
    @{ n = 'redirect into committed';    t = 'Bash';       i = @{ command = 'head -c 0 f > .mission/evidence/d/manifest.json' } },
    @{ n = 'overwrite a hook script';    t = 'Bash';       i = @{ command = 'cat forged.ps1 > tools/framework/hooks/evidence-post-tool-use.ps1' } },
    @{ n = 'redirect into settings';     t = 'Bash';       i = @{ command = 'tail -n 1 forged.json > .claude/settings.json' } },
    @{ n = 'backgrounded destruction';   t = 'Bash';       i = @{ command = 'cat README.md & rm -rf .mission-runtime' } },
    @{ n = 'command substitution';       t = 'Bash';       i = @{ command = 'cat $(rm -rf .mission-runtime)' } },
    @{ n = 'backtick substitution';      t = 'Bash';       i = @{ command = 'ls `rm -rf .mission-runtime`' } },
    @{ n = 'sort -o into evidence';      t = 'Bash';       i = @{ command = 'sort -o .mission-runtime/evidence/d/log.jsonl forged.txt' } },
    # --- the read-verb exemption is DELETED. Bash naming protected territory denies,
    #     reads included. These were ALLOW cases until the exemption that admitted
    #     `git blame --output=` was removed with it.
    @{ n = 'bash cat a manifest';        t = 'Bash';       i = @{ command = 'cat .mission/evidence/d/manifest.json' } },
    @{ n = 'bash head an evidence log';  t = 'Bash';       i = @{ command = 'head -n 5 .mission-runtime/evidence/d/log.jsonl' } },
    @{ n = 'bash ls the hooks dir';      t = 'Bash';       i = @{ command = 'ls tools/framework/hooks' } },
    @{ n = 'bash git log on evidence';   t = 'Bash';       i = @{ command = 'git log --oneline -- .mission/evidence' } },
    @{ n = 'bash git diff on evidence';  t = 'Bash';       i = @{ command = 'git diff -- .mission/evidence' } },
    @{ n = 'bash git show evidence';     t = 'Bash';       i = @{ command = 'git show HEAD:.mission/evidence/d/manifest.json' } },
    # --- the --output family: metacharacter-free writers that the read exemption called "reads".
    #     `git blame --output=<path>` TRUNCATES the named file; a validator zeroed an evidence
    #     log with the guard reporting "plain read".
    @{ n = 'git blame --output';         t = 'Bash';       i = @{ command = 'git blame --output=.mission-runtime/evidence/d/log.jsonl tracked.txt' } },
    @{ n = 'git diff --output';          t = 'Bash';       i = @{ command = 'git diff --output=.mission-runtime/evidence/d/log.jsonl' } },
    @{ n = 'git log --output';           t = 'Bash';       i = @{ command = 'git log --output=.mission/evidence/d/manifest.json' } },
    @{ n = 'git show --output';          t = 'Bash';       i = @{ command = 'git show --output=.mission-runtime/evidence/d/log.jsonl HEAD' } },
    @{ n = 'git shortlog --output';      t = 'Bash';       i = @{ command = 'git shortlog --output=.mission-runtime/evidence/d/log.jsonl HEAD' } },
    @{ n = 'tool_input is a string';     t = 'Bash';       i = '.mission/evidence/x' },
    @{ n = 'unparsable payload';         t = $null;        raw = 'not json at all' },
    @{ n = 'empty payload';              t = $null;        raw = '' }
)
# Cure NB-5: the guard must not deny design-sanctioned or read-only work. A guard
# that blocks the workflow it protects gets switched off, which is a security failure with
# extra steps. Every exemption below has a deny-side twin above.
$allowCases = @(
    @{ n = 'ordinary doc write';         t = 'Write'; i = @{ file_path = 'docs/framework/some-note.md'; content = 'ordinary work' } },
    @{ n = 'doc CONTENT names evidence'; t = 'Write'; i = @{ file_path = 'docs/framework/evidence-write-path-threat-notes.md'; content = 'Protected: .mission/evidence and .mission-runtime/evidence' } },
    @{ n = 'unrelated bash';             t = 'Bash';  i = @{ command = 'git status --porcelain=v1' } },
    @{ n = 'ceremony: git add evidence'; t = 'Bash';  i = @{ command = 'git add .mission/evidence/d1' } },
    @{ n = 'ceremony: git commit ev';    t = 'Bash';  i = @{ command = 'git commit -m "evidence for d1" -- .mission/evidence/d1' } },
    @{ n = 'ledger append (not evid.)';  t = 'Bash';  i = @{ command = 'git add .mission/ledger/entries.jsonl' } },
    @{ n = 'amendment placement';        t = 'Write'; i = @{ file_path = '.mission/amendments/AM-999-x.yaml'; content = 'id: AM-999' } },
    # THE READ PATH IS THE FILE TOOLS. Read/Grep/Glob cannot write, structurally,
    # so they need no verb reasoning and get none. Bash gets no benefit of the doubt.
    @{ n = 'Read tool on evidence log';  t = 'Read';  i = @{ file_path = '.mission/evidence/x/log.jsonl' } },
    @{ n = 'Read tool on a manifest';    t = 'Read';  i = @{ file_path = '.mission-runtime/evidence/d/manifest.json' } },
    @{ n = 'Grep over evidence';         t = 'Grep';  i = @{ pattern = 'rev-parse'; path = '.mission/evidence' } },
    @{ n = 'Glob over evidence';         t = 'Glob';  i = @{ pattern = '.mission/evidence/**/manifest.json' } },
    # The metacharacter gate must not sweep up ordinary work that names nothing protected.
    @{ n = 'commit msg with parens';     t = 'Bash';  i = @{ command = 'git commit -m "close(M-110): status done"' } },
    @{ n = 'ordinary pipeline';          t = 'Bash';  i = @{ command = 'uv run pytest -q | tee out.txt' } }
)

# D8 FOLD: the guard drives run under their own dispatch so the '_denied' records are countable.
$dispatchG = 'a1-negative-test-guard'
$env:MISSION_DISPATCH_ID = $dispatchG

$denyLines = @(); $denyOk = $true
foreach ($c in $denyCases) {
    if ($c.ContainsKey('raw')) { $json = $c.raw }
    else { $json = @{ session_id = 'sess-a1-negative'; hook_event_name = 'PreToolUse'; tool_name = $c.t; tool_input = $c.i } | ConvertTo-Json -Depth 8 -Compress }
    $r = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $json
    $ok = ($r.exit -eq 2 -and $r.stdout -like '*"permissionDecision":"deny"*')
    if (-not $ok) { $denyOk = $false }
    $denyLines += ("    {0,-28} exit={1} {2}" -f $c.n, $r.exit, $(if ($ok) { 'DENY  ok' } else { 'NOT DENIED  <-- FAIL' }))
}
$allowLines = @(); $allowOk = $true
foreach ($c in $allowCases) {
    $json = @{ session_id = 'sess-a1-negative'; hook_event_name = 'PreToolUse'; tool_name = $c.t; tool_input = $c.i } | ConvertTo-Json -Depth 8 -Compress
    $r = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json $json
    $ok = ($r.exit -eq 0 -and $r.stdout -like '*"permissionDecision":"allow"*')
    if (-not $ok) { $allowOk = $false }
    $allowLines += ("    {0,-28} exit={1} {2}" -f $c.n, $r.exit, $(if ($ok) { 'ALLOW ok' } else { 'NOT ALLOWED  <-- FAIL' }))
}

$env:MISSION_DISPATCH_ID = $dispatch

# D8 FOLD ASSERTIONS: one '_denied' record per deny case, none per allow case, every
# reason verbatim from the guard's own preamble. Counts DERIVED from the case tables above.
$guardLogPath = Join-Path $sandbox ".mission-runtime\evidence\$dispatchG\log.jsonl"
$gRecs = @()
if (Test-Path -LiteralPath $guardLogPath) {
    foreach ($line in [System.IO.File]::ReadAllLines($guardLogPath)) {
        if ($line.Trim()) { $gRecs += ($line | ConvertFrom-Json) }
    }
}
$gDenied  = @($gRecs | Where-Object { $_.tool -eq '_denied' })
$gVerbatim = @($gDenied | Where-Object { ([string]$_.reason) -like 'DENIED by evidence-guard*' })
$recordFoldOk = ($gRecs.Count -eq $denyCases.Count -and
                 $gDenied.Count -eq $denyCases.Count -and
                 $gVerbatim.Count -eq $denyCases.Count)

$detail = @"
  MUST DENY ($($denyCases.Count) cases):
$($denyLines -join "`n")

  MUST ALLOW ($($allowCases.Count) cases):
$($allowLines -join "`n")

  D8 '_denied' RECORDS (dispatch $dispatchG):
    log lines written        : $($gRecs.Count)   (expect $($denyCases.Count) -- one per deny, none per allow)
    tool == '_denied'        : $($gDenied.Count)   (expect $($denyCases.Count))
    verbatim guard preamble  : $($gVerbatim.Count)   (expect $($denyCases.Count))
"@
Check -Id 'N2' -Title 'guard denies evidence paths, bypass spellings, and machinery edits; allows ordinary work; every deny leaves a verbatim ''_denied'' record' `
      -Ok ($denyOk -and $allowOk -and $recordFoldOk) -Detail $detail

# =============================================================================
# N3 -- crash before Stop: state derives to PARTIAL, log still readable
# =============================================================================
. (Join-Path $hooksDir 'lib\evidence-common.ps1')
$stateBefore = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$logReadable = @(Read-EvidenceLog -LogPath $logPath).Count

$detail = @"
  manifest present : $(Test-Path -LiteralPath $manPath)   (expect False -- Stop never ran)
  derived state    : $($stateBefore.state)
  reason           : $($stateBefore.reason)
  consumable       : $($stateBefore.consumable)   (expect False -- consumption blocked)
  forensics        : $($stateBefore.forensics)    (expect True  -- re-ground supported)
  log entries still readable : $logReadable
"@
Check -Id 'N3' -Title 'crash before finalize derives PARTIAL; forensics intact' `
      -Ok ($stateBefore.state -eq 'PARTIAL' -and -not $stateBefore.consumable -and
           $stateBefore.forensics -and $logReadable -ge 1) -Detail $detail

# =============================================================================
# N4 -- finalize once; re-running Stop on an UNCHANGED log is a no-op (CURE D10)
#       + D8: no transcript_path degrades to 'unreconciled', stated not silent;
#         a stop_hook_active Stop is a NO-OP in its entirety
# =============================================================================
# Pre-D10 this branch was a blanket refusal to finalize twice. The D10 cure narrows it: an
# unchanged log still gets a no-op (nothing to re-seal), a GROWN log supersedes (N5), and
# only TAMPERED refuses. The unchanged-log no-op is asserted here: byte-identical manifest.
# D8 FOLD: the Stop payloads here carry NO transcript_path, so the manifest's
# call_completeness block must read 'unreconciled' with basis 'none' -- the conservative
# degradation, on the face of the artifact instead of silence. A third Stop with
# stop_hook_active=true must change NOTHING (the re-entry guard, operator ruling).
$stopPayload = @{ session_id = 'sess-a1-negative'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json $stopPayload
$state1 = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$man1   = Get-Sha256OfFile -Path $manPath

Start-Sleep -Milliseconds 1100          # ensure a second finalize would carry a later stamp
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json $stopPayload
$man2 = Get-Sha256OfFile -Path $manPath
$state2 = Get-EvidenceState -Root $sandbox -DispatchId $dispatch

# D8: the re-entry no-op -- driven with a GROWN error surface deliberately absent; the point
# is that NOTHING runs, not that some branch behaves.
$stopReentrant = @{ session_id = 'sess-a1-negative'; hook_event_name = 'Stop'; stop_hook_active = $true } | ConvertTo-Json -Compress
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json $stopReentrant
$man2r = Get-Sha256OfFile -Path $manPath

$manObj = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json
$ccN4 = Get-EntryField $manObj 'call_completeness' $null
$detail = @"
  after 1st Stop : state=$($state1.state) consumable=$($state1.consumable)
                   manifest sha256 = $man1
  after 2nd Stop : state=$($state2.state) consumable=$($state2.consumable)
                   manifest sha256 = $man2
  unchanged      : $($man1 -eq $man2)   (expect True -- unchanged log, no-op)
  after stop_hook_active=true Stop:
                   manifest sha256 = $man2r
  unchanged      : $($man2 -eq $man2r)   (expect True -- the re-entry guard, nothing ran)

  manifest header:
    schema_version   = $($manObj.schema_version)   (expect 1.3.0)
    dispatch_id      = $($manObj.dispatch_id)
    state            = $($manObj.state)
    entry_count      = $($manObj.entry_count)
    finalized_at     = $($manObj.finalized_at)
    log_sha256       = $($manObj.log_sha256)
    log_bytes_sealed = $($manObj.log_bytes_sealed)   (the sealed prefix, explicit)
    finalize_count   = $($manObj.finalize_count)   (expect 1 -- first and only finalize)

  call_completeness (D8 -- no transcript_path in the synthesized payload):
    status = $(if ($ccN4) { $ccN4.status } else { 'MISSING' })   (expect unreconciled -- stated, never silent)
    basis  = $(if ($ccN4) { $ccN4.basis } else { 'MISSING' })   (expect none)
    reason = $(if ($ccN4) { $ccN4.reason } else { 'MISSING' })
"@
Check -Id 'N4' -Title 'finalize once; unchanged-log and stop_hook_active Stops are no-ops; completeness degrades to ''unreconciled'' stated on the artifact' `
      -Ok ($state1.state -eq 'FINALIZED' -and $state1.consumable -and $man1 -eq $man2 -and
           $man2 -eq $man2r -and $state2.state -eq 'FINALIZED' -and
           $manObj.schema_version -eq '1.3.0' -and
           $manObj.finalize_count -eq 1 -and $manObj.log_bytes_sealed -gt 0 -and
           $null -ne $ccN4 -and $ccN4.status -eq 'unreconciled' -and $ccN4.basis -eq 'none') -Detail $detail

# =============================================================================
# N5 -- the dispatch/turn lifecycle (CURE D10): append derives GREW and the
#       next Stop SUPERSEDES; mutation, truncation, and mutate-then-extend still
#       derive TAMPERED and are REFUSED
# =============================================================================
# Pre-D10 this check appended a line to a finalized log and asserted TAMPERED -- which was
# asserting E5-iv's collapsed verdict: append-growth and byte-mutation were one state, and
# every multi-turn session read as tampered (manifests frozen at entry_count 14/33/55 over
# logs grown to 52/183/177 lines on this repository's own residue, with seventeen REFUSED
# entries and zero actual tampering). The cure splits the verdict. This slot now carries
# the whole lifecycle matrix, per member, in both directions -- the TAMPERED direction is
# the gate: a cure that made TAMPERED unreachable would have destroyed the detector D11's
# divergence findings rely on. Folded here rather than appended as new checks because the
# threat-notes mirror freezes the check tally.

# (a) GROWTH BY APPEND -- a real later-turn shape: stream body first, then the log line.
$sealedLen0 = ([System.IO.File]::ReadAllBytes($logPath)).Length
$growthOut  = 'growth-payload-after-first-finalize'
$growthBody = [ordered]@{ seq = 2; tool = 'Bash'; stdout = $growthOut; stderr = '' } | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText((Join-Path (Join-Path $evDir 'streams') '000002.json'), $growthBody, (New-Object System.Text.UTF8Encoding($false)))
$growthEntry = [ordered]@{
    ts = '2026-08-11T00:00:02.000Z'; session_id = 'sess-a1-negative'; dispatch_id = $dispatch
    seq = 2; tool = 'Bash'; command = 'echo growth'; exit_code = $null
    stdout = $growthOut; stderr = ''
    stdout_truncated = $false; stderr_truncated = $false
    stdout_sha256 = (Get-Sha256OfString $growthOut); stderr_sha256 = (Get-Sha256OfString '')
    path = 'streams/000002.json'
} | ConvertTo-Json -Compress -Depth 8
[System.IO.File]::AppendAllText($logPath, $growthEntry + "`n")
$stGrew = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$grewOk = ($stGrew.state -eq 'GREW' -and -not $stGrew.consumable -and
           $stGrew.reason -like '*append-extension*')

# (b) THE NEXT STOP SUPERSEDES, RETAINING THE PRIOR MANIFEST IN BOTH PLANES
$manBeforeSup = Get-Sha256OfFile -Path $manPath
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json $stopPayload
$supRt = Join-Path $evDir 'manifest.superseded-001.json'
$supCm = Join-Path $sandbox ".mission\evidence\$dispatch\manifest.superseded-001.json"
$manSup = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json
$stAfterSup = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$supOk = ((Test-Path -LiteralPath $supRt) -and (Test-Path -LiteralPath $supCm) -and
          (Get-Sha256OfFile -Path $supRt) -eq $manBeforeSup -and
          $manSup.entry_count -eq 2 -and $manSup.finalize_count -eq 2 -and
          $stAfterSup.state -eq 'FINALIZED' -and $stAfterSup.consumable)

# (c) MUTATION OF A SEALED BYTE -- TAMPERED. The gate direction.
$origBytes = [System.IO.File]::ReadAllBytes($logPath)
$mutBytes = [byte[]]$origBytes.Clone()
$mutBytes[40] = $(if ($mutBytes[40] -eq [byte][char]'x') { [byte][char]'y' } else { [byte][char]'x' })
[System.IO.File]::WriteAllBytes($logPath, $mutBytes)
$stMut = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$mutOk = ($stMut.state -eq 'TAMPERED' -and -not $stMut.consumable -and
          $stMut.reason -like '*sealed*')

# (d) STOP ON THE MUTATED LOG REFUSES -- manifest untouched, REFUSED on the error trail.
$manBeforeRefuse = Get-Sha256OfFile -Path $manPath
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json $stopPayload
$errN5 = Join-Path $evDir 'hook-errors.log'
$refuseOk = ((Get-Sha256OfFile -Path $manPath) -eq $manBeforeRefuse -and
             (Test-Path -LiteralPath $errN5) -and
             ([System.IO.File]::ReadAllText($errN5) -like '*REFUSED to finalize TAMPERED*'))

# (e) TRUNCATION BELOW THE SEALED PREFIX -- TAMPERED. A shorter log can never supersede.
[System.IO.File]::WriteAllBytes($logPath, [byte[]]$origBytes[0..($sealedLen0 - 11)])
$stTrunc = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$truncOk = ($stTrunc.state -eq 'TAMPERED' -and $stTrunc.reason -like '*SHORTER*')

# (f) MUTATE-THEN-EXTEND -- growth cannot mask mutation; the case a length check would miss.
$mutGrow = [byte[]]$origBytes.Clone()
$mutGrow[40] = $(if ($mutGrow[40] -eq [byte][char]'x') { [byte][char]'y' } else { [byte][char]'x' })
[System.IO.File]::WriteAllBytes($logPath, $mutGrow)
[System.IO.File]::AppendAllText($logPath, $growthEntry + "`n")
$stMutGrow = Get-EvidenceState -Root $sandbox -DispatchId $dispatch
$mutGrowOk = ($stMutGrow.state -eq 'TAMPERED')

# restore the true log so downstream state is coherent
[System.IO.File]::WriteAllBytes($logPath, $origBytes)

$detail = @"
  (a) APPEND AFTER FINALIZE
      derived state : $($stGrew.state)   (expect GREW -- NOT TAMPERED; the E5-iv cure)
      consumable    : $($stGrew.consumable)   (expect False -- the manifest does not cover the tail)
      reason        : $($stGrew.reason)
  (b) NEXT STOP SUPERSEDES
      superseded retained (runtime)   : $(Test-Path -LiteralPath $supRt)
      superseded retained (committed) : $(Test-Path -LiteralPath $supCm)
      retained == prior manifest      : $((Get-Sha256OfFile -Path $supRt) -eq $manBeforeSup)
      new entry_count / finalize_count: $($manSup.entry_count) / $($manSup.finalize_count)   (expect 2 / 2)
      state after supersession        : $($stAfterSup.state)   (expect FINALIZED, consumable)
  (c) SEALED BYTE MUTATED
      derived state : $($stMut.state)   (expect TAMPERED -- the preserved detector)
      reason        : $($stMut.reason)
  (d) STOP ON MUTATED LOG
      manifest unchanged : $((Get-Sha256OfFile -Path $manPath) -eq $manBeforeRefuse)   (expect True -- REFUSED)
      REFUSED on trail   : $((Test-Path -LiteralPath $errN5) -and ([System.IO.File]::ReadAllText($errN5) -like '*REFUSED to finalize TAMPERED*'))
  (e) TRUNCATED BELOW SEALED PREFIX
      derived state : $($stTrunc.state)   (expect TAMPERED)
      reason        : $($stTrunc.reason)
  (f) MUTATE-THEN-EXTEND
      derived state : $($stMutGrow.state)   (expect TAMPERED -- growth cannot mask mutation)
"@
Check -Id 'N5' -Title 'append derives GREW and supersedes with retention; mutation, truncation, and mutate-then-extend derive TAMPERED and refuse' `
      -Ok ($grewOk -and $supOk -and $mutOk -and $refuseOk -and $truncOk -and $mutGrowOk) -Detail $detail

# =============================================================================
# N6 -- PostToolUse -> PreCompact -> Stop must reach FINALIZED (cure B1/B2)
# =============================================================================
# The defect this check exists to catch: a _precompact log entry has no stdout_sha256, the
# finalizer read that property directly under StrictMode, threw, and the outer catch swallowed
# it -- so EVERY session that compacted was permanently stuck PARTIAL with no manifest, and
# the PARTIAL reason string blamed a crash that never happened. Long sessions are the ones
# that compact, and the ones whose evidence matters most. The pre-cure test passed 5/5 solely
# because it never fired PreCompact.
$dispatch2 = 'a1-negative-test-compact'
$env:MISSION_DISPATCH_ID = $dispatch2
$ev2  = Join-Path $sandbox ".mission-runtime\evidence\$dispatch2"
$man2p = Join-Path $ev2 'manifest.json'

# a stand-in transcript for PreCompact to snapshot
$tr = Join-Path $sandbox 'fake-transcript.jsonl'
[System.IO.File]::WriteAllText($tr, '{"role":"user","content":"hello"}' + "`n")

$p1 = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
        session_id = 'sess-compact'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
        tool_input = @{ command = 'git rev-parse HEAD' }
        tool_response = @{ stdout = "$realSha`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
$p2 = Invoke-Hook -Script 'evidence-pre-compact.ps1' -Json (@{
        session_id = 'sess-compact'; hook_event_name = 'PreCompact'
        transcript_path = $tr; trigger = 'auto' } | ConvertTo-Json -Depth 8 -Compress)
$p3 = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
        session_id = 'sess-compact'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)

$state6 = Get-EvidenceState -Root $sandbox -DispatchId $dispatch2
$man6 = $null
if (Test-Path -LiteralPath $man2p) { $man6 = [System.IO.File]::ReadAllText($man2p) | ConvertFrom-Json }

$pcEntry = $null; $toolEntry = $null
if ($man6) {
    $pcEntry   = @($man6.entries | Where-Object { $_.tool -eq '_precompact' })   | Select-Object -First 1
    $toolEntry = @($man6.entries | Where-Object { $_.tool -ne '_precompact' })   | Select-Object -First 1
}
$errLog = Join-Path $ev2 'hook-errors.log'
$errTxt = if (Test-Path -LiteralPath $errLog) { [System.IO.File]::ReadAllText($errLog).Trim() } else { '(none)' }

# streams + transcripts must have reached the committed plane (cure N-b)
$committed2 = Join-Path $sandbox ".mission\evidence\$dispatch2"
$hasStreams = Test-Path -LiteralPath (Join-Path $committed2 'streams')
$hasTrans   = Test-Path -LiteralPath (Join-Path $committed2 'transcripts')
$streamCheck = Test-EvidenceStreamIntegrity -Root $sandbox -DispatchId $dispatch2

$detail = @"
  hook exits     : PostToolUse=$($p1.exit) PreCompact=$($p2.exit) Stop=$($p3.exit)
  hook-errors.log: $errTxt   (expect none)
  manifest present: $(Test-Path -LiteralPath $man2p)   (expect True -- this is the whole check)
  derived state  : $($state6.state)   (expect FINALIZED)
  consumable     : $($state6.consumable)   (expect True)
  entry_count    : $(if ($man6) { $man6.entry_count } else { 'n/a' })   (expect 2)
  schema_version : $(if ($man6) { $man6.schema_version } else { 'n/a' })
  streams_committed flag : $(if ($man6) { $man6.streams_committed } else { 'n/a' })

  tool-call entry keys  : $(if ($toolEntry) { ($toolEntry.PSObject.Properties.Name -join ', ') } else { 'MISSING' })
  _precompact entry keys: $(if ($pcEntry) { ($pcEntry.PSObject.Properties.Name -join ', ') } else { 'MISSING' })
  _precompact captured  : $(if ($pcEntry) { $pcEntry.captured } else { 'n/a' })
  _precompact sha256    : $(if ($pcEntry) { $pcEntry.transcript_sha256 } else { 'n/a' })

  committed plane: streams/=$hasStreams transcripts/=$hasTrans
  stream integrity: checked=$($streamCheck.checked) ok=$($streamCheck.ok) -- $($streamCheck.reason)
"@
Check -Id 'N6' -Title 'PostToolUse -> PreCompact -> Stop reaches FINALIZED with a valid two-variant manifest' `
      -Ok ($state6.state -eq 'FINALIZED' -and $state6.consumable -and $null -ne $man6 -and
           $man6.entry_count -eq 2 -and $null -ne $pcEntry -and $null -ne $toolEntry -and
           $pcEntry.captured -eq $true -and
           ($pcEntry.PSObject.Properties.Name -contains 'transcript_sha256') -and
           -not ($pcEntry.PSObject.Properties.Name -contains 'stdout_sha256') -and
           ($toolEntry.PSObject.Properties.Name -contains 'stdout_sha256') -and
           $hasStreams -and $hasTrans -and $streamCheck.ok -and $errTxt -eq '(none)') -Detail $detail

# =============================================================================
# N7 -- MULTIPLE PostToolUse events in ONE dispatch (cure B5)
#       + D11 stream identity: the collision case and the detector
#       + D8: the call_completeness matrix -- 'complete' with failed and denied
#         calls DISCLOSED, and 'incomplete' when the accounting positively fails
# =============================================================================
# The B5 defect this exists to catch: `(... | Where-Object ...).Count` throws under StrictMode when the
# pipeline yields exactly ONE object, so after the first captured call every subsequent one
# threw, was swallowed by the outer catch, exited 0, and vanished. The dispatch then finalized
# as FINALIZED/consumable with entry_count=1 -- missing evidence presented as complete evidence.
#
# Both prior test generations passed while this was live, because no dispatch in either fired
# two PostToolUse events. Coverage, not greenness, is what a check is worth.
$dispatch3 = 'a1-negative-test-multi'
$env:MISSION_DISPATCH_ID = $dispatch3
$ev3   = Join-Path $sandbox ".mission-runtime\evidence\$dispatch3"
$man3p = Join-Path $ev3 'manifest.json'

$N = 4
for ($i = 1; $i -le $N; $i++) {
    $null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
        session_id = 'sess-multi'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
        tool_input = @{ command = "echo call-$i" }
        tool_response = @{ stdout = "output-of-call-$i`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
}
$logLines3 = @()
$log3p = Join-Path $ev3 'log.jsonl'
if (Test-Path -LiteralPath $log3p) { $logLines3 = @([System.IO.File]::ReadAllLines($log3p) | Where-Object { $_.Trim() }) }

# D8 FOLD (1/3): one REAL guard denial under this dispatch -- its '_denied' record is the
# second denial recorder the completeness block cross-checks.
$null = Invoke-Hook -Script 'evidence-guard-pretooluse.ps1' -Json (@{
    session_id = 'sess-multi'; hook_event_name = 'PreToolUse'; tool_name = 'Write'
    tool_input = @{ file_path = '.mission-runtime/evidence/x/log.jsonl'; content = 'forged' } } | ConvertTo-Json -Depth 8 -Compress)

# D8 FOLD (2/3): a synthesized transcript in the DERIVED live shape: four
# succeeded pairs matching the four logged calls, one failed pair (is_error, no guard text --
# the E5-ii member), one denied pair (is_error carrying the guard preamble -- the E5-iii
# member). Counts below are DERIVED from these tables, never typed.
$n7TranscriptPath = Join-Path $sandbox 'n7-transcript.jsonl'
$n7Lines = New-Object System.Collections.Generic.List[string]
for ($i = 1; $i -le $N; $i++) {
    $n7Lines.Add((@{ isSidechain = $false; sessionId = 'sess-multi'; type = 'assistant'
                     message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = "tu-ok-$i"; name = 'Bash'; input = @{ command = "echo call-$i" } }) } } | ConvertTo-Json -Depth 10 -Compress))
    $n7Lines.Add((@{ isSidechain = $false; sessionId = 'sess-multi'; type = 'user'
                     message = @{ role = 'user'; content = @(@{ type = 'tool_result'; tool_use_id = "tu-ok-$i"; content = "output-of-call-$i" }) } } | ConvertTo-Json -Depth 10 -Compress))
}
$n7Lines.Add((@{ isSidechain = $false; sessionId = 'sess-multi'; type = 'assistant'
                 message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = 'tu-fail-1'; name = 'Read'; input = @{ file_path = 'does-not-exist.md' } }) } } | ConvertTo-Json -Depth 10 -Compress))
$n7Lines.Add((@{ isSidechain = $false; sessionId = 'sess-multi'; type = 'user'
                 message = @{ role = 'user'; content = @(@{ type = 'tool_result'; tool_use_id = 'tu-fail-1'; content = 'File does not exist.'; is_error = $true }) } } | ConvertTo-Json -Depth 10 -Compress))
$n7Lines.Add((@{ isSidechain = $false; sessionId = 'sess-multi'; type = 'assistant'
                 message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = 'tu-deny-1'; name = 'Write'; input = @{ file_path = '.mission-runtime/evidence/x/log.jsonl' } }) } } | ConvertTo-Json -Depth 10 -Compress))
$n7Lines.Add((@{ isSidechain = $false; sessionId = 'sess-multi'; type = 'user'
                 message = @{ role = 'user'; content = @(@{ type = 'tool_result'; tool_use_id = 'tu-deny-1'; content = "DENIED by evidence-guard (AM-417 / design SS4.1 layer c): tool 'Write' targets the protected path '.mission-runtime/evidence'."; is_error = $true }) } } | ConvertTo-Json -Depth 10 -Compress))
[System.IO.File]::WriteAllText($n7TranscriptPath, (($n7Lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
$n7FailedSynth = 1
$n7DeniedSynth = 1
$n7UseTotal    = $N + $n7FailedSynth + $n7DeniedSynth

$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-multi'; hook_event_name = 'Stop'
    transcript_path = $n7TranscriptPath } | ConvertTo-Json -Compress)
$state7 = Get-EvidenceState -Root $sandbox -DispatchId $dispatch3
$man7 = $null
if (Test-Path -LiteralPath $man3p) { $man7 = [System.IO.File]::ReadAllText($man3p) | ConvertFrom-Json }

# Every call's CONTENT must survive to the manifest, not merely the right number of rows.
$cmdsSeen = @()
$streamsOk = $true
$deniedEntries7 = @()
if ($man7) {
    foreach ($e in @($man7.entries)) {
        $cmdsSeen += [string]$e.command
        if ([string]$e.tool -eq '_denied') { $deniedEntries7 += $e; continue }   # D8: no stream, null path
        $sp = Join-Path $ev3 ([string]$e.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $sp)) { $streamsOk = $false; continue }
        $body = [System.IO.File]::ReadAllText($sp) | ConvertFrom-Json
        if ((Get-Sha256OfString ([string]$body.stdout)) -ne [string]$e.stdout_sha256) { $streamsOk = $false }
    }
}
$allCmds = @(1..$N | ForEach-Object { "echo call-$_" })
$missing = @($allCmds | Where-Object { $cmdsSeen -notcontains $_ })

$err3 = Join-Path $ev3 'hook-errors.log'
$err3Txt = if (Test-Path -LiteralPath $err3) { [System.IO.File]::ReadAllText($err3).Trim() } else { '(none)' }
$errGlobal = Join-Path $sandbox '.mission-runtime\evidence\hook-errors-UNATTRIBUTED.log'
$committed3 = Join-Path $sandbox ".mission\evidence\$dispatch3"

# --- D8: the completeness verdicts, derived from the manifest --------------------------------
$cc7 = $null
if ($man7) { $cc7 = Get-EntryField $man7 'call_completeness' $null }
$cc7Ok = ($null -ne $cc7 -and $cc7.status -eq 'complete' -and $cc7.basis -eq 'payload-transcript-path' -and
          $cc7.unmatched -eq 0 -and
          $cc7.transcript_calls -eq $n7UseTotal -and
          $cc7.logged_entries -eq $N -and
          $cc7.failed_seen -eq $n7FailedSynth -and
          $cc7.denied_seen -eq $n7DeniedSynth -and
          $cc7.denied_records -eq @($deniedEntries7).Count -and
          $cc7.transcript_sha256 -eq (Get-Sha256OfFile -Path $n7TranscriptPath))

# D8 FOLD (3/3): the INCOMPLETE direction -- a transcript that resolved one more succeeded
# call than the log captured must read 'incomplete' with the counts saying where.
$dispatchC = 'a1-negative-test-ccheck'
$env:MISSION_DISPATCH_ID = $dispatchC
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
    session_id = 'sess-ccheck'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'echo only-logged-call' }
    tool_response = @{ stdout = "ok`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
$ccTranscriptPath = Join-Path $sandbox 'ccheck-transcript.jsonl'
$ccLines = New-Object System.Collections.Generic.List[string]
foreach ($cid in @('cc-1', 'cc-2')) {
    $ccLines.Add((@{ isSidechain = $false; sessionId = 'sess-ccheck'; type = 'assistant'
                     message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = $cid; name = 'Bash'; input = @{ command = 'echo x' } }) } } | ConvertTo-Json -Depth 10 -Compress))
    $ccLines.Add((@{ isSidechain = $false; sessionId = 'sess-ccheck'; type = 'user'
                     message = @{ role = 'user'; content = @(@{ type = 'tool_result'; tool_use_id = $cid; content = 'x' }) } } | ConvertTo-Json -Depth 10 -Compress))
}
[System.IO.File]::WriteAllText($ccTranscriptPath, (($ccLines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{
    session_id = 'sess-ccheck'; hook_event_name = 'Stop'
    transcript_path = $ccTranscriptPath } | ConvertTo-Json -Compress)
$manC = [System.IO.File]::ReadAllText((Join-Path (Join-Path $sandbox ".mission-runtime\evidence\$dispatchC") 'manifest.json')) | ConvertFrom-Json
$ccC = Get-EntryField $manC 'call_completeness' $null
$ccIncompleteOk = ($null -ne $ccC -and $ccC.status -eq 'incomplete' -and $ccC.unmatched -eq 1 -and
                   $ccC.logged_entries -eq 1 -and $ccC.transcript_calls -eq 2)
$env:MISSION_DISPATCH_ID = $dispatch3

# --- D11: the collision case and the detector, folded INTO N7 rather
# than added as new checks. N10's mirror block in the sealed threat notes (NOT in
# D11's write surface) fixes the deny population and the check tally (TALLY checks: 14), so
# the check population must not change; coverage rides here instead. Four members:
#   (a) the clean dispatch above reads identity-clean;
#   (b) a constructed duplicate-path set fires the duplicate-path member and ONLY it -- the
#       signature of the live instances (entries 13/14 of one session, 3/4 of
#       another);
#   (c) a constructed orphan-file set fires the count-mismatch member and ONLY it;
#   (d) two allocations from ONE probe floor cannot resolve the same name -- the cure, driven
#       deterministically in-process. The cross-process barrier drive lives in A6 (G1/G2).
$idClean = @()
if ($man7) { $idClean = @(Get-EvidenceStreamIdentityFindings -Entries @($man7.entries) -StreamDir (Join-Path $ev3 'streams')) }

$fxDup = Join-Path $sandbox 'd11-fixture-dup'
New-Item -ItemType Directory -Path (Join-Path $fxDup 'streams') -Force | Out-Null
foreach ($nm in @('000001.json', '000002.json', '000003.json')) {
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $fxDup 'streams') $nm), '{}')
}
$dupEntries = @(
    [pscustomobject]@{ path = 'streams/000001.json' },
    [pscustomobject]@{ path = 'streams/000001.json' },
    [pscustomobject]@{ path = 'streams/000002.json' }
)
$idDup = @(Get-EvidenceStreamIdentityFindings -Entries $dupEntries -StreamDir (Join-Path $fxDup 'streams'))
$dupFired = (@($idDup | Where-Object { $_.kind -eq 'duplicate-path' -and $_.path -eq 'streams/000001.json' }).Count -eq 1)
$dupOnly  = (@($idDup | Where-Object { $_.kind -ne 'duplicate-path' }).Count -eq 0)

$fxOrp = Join-Path $sandbox 'd11-fixture-orphan'
New-Item -ItemType Directory -Path (Join-Path $fxOrp 'streams') -Force | Out-Null
foreach ($nm in @('000001.json', '000002.json')) {
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $fxOrp 'streams') $nm), '{}')
}
$orpEntries = @([pscustomobject]@{ path = 'streams/000001.json' })
$idOrp = @(Get-EvidenceStreamIdentityFindings -Entries $orpEntries -StreamDir (Join-Path $fxOrp 'streams'))
$orpFired = (@($idOrp | Where-Object { $_.kind -eq 'count-mismatch' }).Count -eq 1)
$orpOnly  = (@($idOrp | Where-Object { $_.kind -ne 'count-mismatch' }).Count -eq 0)

$fxRace = Join-Path $sandbox 'd11-fixture-race'
New-Item -ItemType Directory -Path (Join-Path $fxRace 'streams') -Force | Out-Null
$alloc1 = New-EvidenceStreamFile -StreamDir (Join-Path $fxRace 'streams') -StartSeq 1 -Tool 'Bash' -Stdout 'first payload' -Stderr ''
$alloc2 = New-EvidenceStreamFile -StreamDir (Join-Path $fxRace 'streams') -StartSeq 1 -Tool 'Bash' -Stdout 'second payload' -Stderr ''
$raceFiles = @(Get-ChildItem -LiteralPath (Join-Path $fxRace 'streams') -File)
$raceBody1 = [System.IO.File]::ReadAllText($alloc1.full) | ConvertFrom-Json
$raceBody2 = [System.IO.File]::ReadAllText($alloc2.full) | ConvertFrom-Json
$raceOk = ($alloc1.seq -eq 1 -and $alloc2.seq -eq 2 -and $raceFiles.Count -eq 2 -and
           [string]$raceBody1.stdout -eq 'first payload' -and
           [string]$raceBody2.stdout -eq 'second payload')

$detail = @"
  PostToolUse events fired : $N
  log.jsonl lines at read  : $($logLines3.Count)   (expect $N -- this is the B5 assertion; the '_denied' line lands after)
  derived state            : $($state7.state)   (expect FINALIZED)
  entry_count              : $(if ($man7) { $man7.entry_count } else { 'n/a' })   (expect $($N + 1) -- $N tool calls + 1 '_denied')
  schema_version           : $(if ($man7) { $man7.schema_version } else { 'n/a' })
  hook_errors_present flag : $(if ($man7) { $man7.hook_errors_present } else { 'n/a' })   (expect False)

  commands surviving to the manifest:
    $($cmdsSeen -join "`n    ")
  missing commands         : $(if ($missing.Count) { $missing -join ', ' } else { '(none)' })
  stream bodies re-derive  : $streamsOk
  '_denied' entries        : $(@($deniedEntries7).Count)   (expect 1 -- the driven denial, with its verbatim reason)

  per-dispatch hook-errors.log : $err3Txt
  UNATTRIBUTED global log      : $(Test-Path -LiteralPath $errGlobal)   (expect False)
  committed plane exists       : $(Test-Path -LiteralPath $committed3)

  D8 CALL COMPLETENESS
    status / basis / unmatched   : $(if ($cc7) { "$($cc7.status) / $($cc7.basis) / $($cc7.unmatched)" } else { 'MISSING' })   (expect complete / payload-transcript-path / 0)
    N / M / F / D / D-records    : $(if ($cc7) { "$($cc7.transcript_calls) / $($cc7.logged_entries) / $($cc7.failed_seen) / $($cc7.denied_seen) / $($cc7.denied_records)" } else { 'MISSING' })   (expect $n7UseTotal / $N / $n7FailedSynth / $n7DeniedSynth / 1)
    transcript anchor re-derives : $(if ($cc7) { $cc7.transcript_sha256 -eq (Get-Sha256OfFile -Path $n7TranscriptPath) } else { 'n/a' })
    INCOMPLETE direction         : $(if ($ccC) { "$($ccC.status) unmatched=$($ccC.unmatched) M=$($ccC.logged_entries) N=$($ccC.transcript_calls)" } else { 'MISSING' })   (expect incomplete unmatched=1 M=1 N=2)

  D11 STREAM IDENTITY
    clean dispatch identity findings : $($idClean.Count)   (expect 0)
    duplicate-path fixture           : fired=$dupFired onlyThatMember=$dupOnly
      $(($idDup | ForEach-Object { "[$($_.kind)] $($_.problem)" }) -join "`n      ")
    orphan-file fixture              : fired=$orpFired onlyThatMember=$orpOnly
      $(($idOrp | ForEach-Object { "[$($_.kind)] $($_.problem)" }) -join "`n      ")
    one probe floor, two allocations : seq $($alloc1.seq) and seq $($alloc2.seq), $($raceFiles.Count) files, bodies distinct=$raceOk
"@
Check -Id 'N7' -Title 'multiple PostToolUse events all survive; the completeness matrix decides complete and incomplete; stream identity detectors fire per member' `
      -Ok ($logLines3.Count -eq $N -and $state7.state -eq 'FINALIZED' -and $null -ne $man7 -and
           $man7.entry_count -eq ($N + 1) -and $missing.Count -eq 0 -and $streamsOk -and
           @($deniedEntries7).Count -eq 1 -and
           ([string]$deniedEntries7[0].reason) -like 'DENIED by evidence-guard*' -and
           $man7.hook_errors_present -eq $false -and $err3Txt -eq '(none)' -and
           $cc7Ok -and $ccIncompleteOk -and
           $idClean.Count -eq 0 -and $dupFired -and $dupOnly -and $orpFired -and $orpOnly -and
           $raceOk) -Detail $detail

$env:MISSION_DISPATCH_ID = $dispatch

# =============================================================================
# N8 -- a hook error is visible in the committed artifact (cure B5 trail)
# =============================================================================
# B5 was invisible for three reasons: errors went to a global log, the state machine read a
# per-dispatch one, and the finalizer committed neither. All three are asserted here.
$dispatch4 = 'a1-negative-test-errtrail'
$env:MISSION_DISPATCH_ID = $dispatch4
$ev4 = Join-Path $sandbox ".mission-runtime\evidence\$dispatch4"
New-Item -ItemType Directory -Path $ev4 -Force | Out-Null
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
    session_id = 'sess-err'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'git rev-parse HEAD' }
    tool_response = @{ stdout = "$realSha`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
# simulate a hook failure having been recorded during the dispatch
Write-EvidenceHookError -Hook 'PostToolUse' -Message 'SIMULATED capture failure for N8' -DispatchId $dispatch4
$state8pre = Get-EvidenceState -Root $sandbox -DispatchId $dispatch4
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{ session_id = 'sess-err'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)
$man8 = [System.IO.File]::ReadAllText((Join-Path $ev4 'manifest.json')) | ConvertFrom-Json
$committed4 = Join-Path $sandbox ".mission\evidence\$dispatch4"
$errCommitted = Test-Path -LiteralPath (Join-Path $committed4 'hook-errors.log')

$detail = @"
  error written to per-dispatch log : $(Test-Path -LiteralPath (Join-Path $ev4 'hook-errors.log'))   (expect True)
  Get-EvidenceState saw it (errHint): $($state8pre.reason -like '*hook-errors.log EXISTS*')   (expect True)
  manifest hook_errors_present      : $($man8.hook_errors_present)   (expect True)
  manifest hook_errors_sha256       : $($man8.hook_errors_sha256)
  hook-errors.log in committed plane: $errCommitted   (expect True)
"@
Check -Id 'N8' -Title 'a hook error reaches the state machine, the manifest, and the committed plane' `
      -Ok ((Test-Path -LiteralPath (Join-Path $ev4 'hook-errors.log')) -and
           ($state8pre.reason -like '*hook-errors.log EXISTS*') -and
           $man8.hook_errors_present -eq $true -and
           $man8.hook_errors_sha256 -match '^[0-9a-f]{64}$' -and $errCommitted) -Detail $detail

# =============================================================================
# N9 -- an error raised AFTER manifest computation still surfaces
# =============================================================================
# A validator measured hook_errors_present=false on a dispatch that DID error: the flag was
# computed before the fallible committed-plane copy, and Get-EvidenceState carried its error
# hint only in the PARTIAL branches, so a FINALIZED dispatch hid it twice over. Here the
# committed-plane path is blocked with a FILE where the directory must go, so the publish phase
# throws AFTER the entries are built -- exactly the window that was invisible.
$dispatch5 = 'a1-negative-test-posterr'
$env:MISSION_DISPATCH_ID = $dispatch5
$ev5 = Join-Path $sandbox ".mission-runtime\evidence\$dispatch5"
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
    session_id = 'sess-posterr'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'git rev-parse HEAD' }
    tool_response = @{ stdout = "$realSha`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)

# block the committed plane: a FILE at the directory path the finalizer must create
$blocked = Join-Path $sandbox ".mission\evidence\$dispatch5"
New-Item -ItemType Directory -Path (Split-Path -Parent $blocked) -Force | Out-Null
[System.IO.File]::WriteAllText($blocked, 'not a directory')

$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{ session_id = 'sess-posterr'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)

$state9 = Get-EvidenceState -Root $sandbox -DispatchId $dispatch5
$man9p  = Join-Path $ev5 'manifest.json'
$man9   = $null
if (Test-Path -LiteralPath $man9p) { $man9 = [System.IO.File]::ReadAllText($man9p) | ConvertFrom-Json }
$err9   = Join-Path $ev5 'hook-errors.log'
$err9Txt = if (Test-Path -LiteralPath $err9) { [System.IO.File]::ReadAllText($err9).Trim() } else { '(none)' }

# F4: the anchor must ANCHOR. Asserting only `^[0-9a-f]{64}$` let a stale hash pass --
# a validator measured the manifest recording a one-line error log while two lines were on disk,
# and this check stayed green. The schema calls this field an anchor "the same way log_sha256
# anchors the log", and re-hash-and-compare is what makes log_sha256 mean anything. So this
# check now does exactly that. This scenario is also the double-error case: phase 1 AND phase 3
# both fail, so the pre-cure reconcile gate could never fire.
$err9Sha = if (Test-Path -LiteralPath $err9) { (Get-FileHash -Algorithm SHA256 -LiteralPath $err9).Hash.ToLower() } else { $null }
$anchorHolds = ($null -ne $man9) -and ($man9.hook_errors_sha256 -eq $err9Sha)

$detail = @"
  committed plane blocked by a file : $(Test-Path -LiteralPath $blocked)
  manifest written                  : $(Test-Path -LiteralPath $man9p)
  derived state                     : $($state9.state)
  hook_errors_present               : $(if ($man9) { $man9.hook_errors_present } else { 'n/a' })   (expect True)
  errors recorded (double-error)    : $(@($err9Txt -split "`n").Count)   (expect 2 -- phase 1 AND phase 3 failed)

  ANCHOR CHECK -- recorded vs re-hashed, not merely well-formed
    manifest hook_errors_sha256     : $(if ($man9) { $man9.hook_errors_sha256 } else { 'n/a' })
    re-hash of hook-errors.log      : $err9Sha
    ANCHOR HOLDS                    : $anchorHolds   (expect True)

  reconciled flag                   : $(if ($man9 -and ($man9.PSObject.Properties.Name -contains 'reconciled')) { $man9.reconciled } else { '(absent)' })   (expect True here)
  state reason mentions hook-errors : $($state9.reason -like '*hook-errors.log EXISTS*')   (expect True)
  hook-errors.log content           : $err9Txt
"@
# Finding 6: `reconciled` is asserted, not merely printed. This scenario is the one
# that must set it -- an error at phase 2 AND phase 3 -- so its absence is a real defect.
$reconciledSet = ($null -ne $man9) -and ($man9.PSObject.Properties.Name -contains 'reconciled') -and ($man9.reconciled -eq $true)
Check -Id 'N9' -Title 'a post-manifest error surfaces in the flag, the state reason, and an anchor that re-derives' `
      -Ok ($null -ne $man9 -and $man9.hook_errors_present -eq $true -and $anchorHolds -and $reconciledSet -and
           ($state9.reason -like '*hook-errors.log EXISTS*') -and
           $err9Txt -ne '(none)') -Detail $detail

$env:MISSION_DISPATCH_ID = $dispatch

# =============================================================================
# N10 -- the documented Catches list IS the N2 deny population
# =============================================================================
# The era rule: "Itemizations are derived by grepping for the evolving clause across the
# tree, never by enumerating known sites from memory." Twice the threat notes claimed a category
# the test did not run -- B7, then BF2 in the very list whose header promised it could not
# happen. Hand-authored completeness claims fail structurally, so the document no longer authors
# the list: it mirrors this test's deny-case names between markers, and THIS CHECK ENFORCES SET
# EQUALITY IN BOTH DIRECTIONS. A documented catch with no case fails here. A case missing from
# the document fails here. Overclaim stops being a thing that can be written.
$notesPath = Join-Path $repoRoot 'docs\framework\evidence-write-path-threat-notes.md'
$notesTxt  = if (Test-Path -LiteralPath $notesPath) { [System.IO.File]::ReadAllText($notesPath) } else { '' }
$beginMark = 'N2-DENY-CASES:BEGIN'
$endMark   = 'N2-DENY-CASES:END'

$documented = @()
$docTallies = @{}
$blockFound = $false
if ($notesTxt -match "(?s)$beginMark(.*?)$endMark") {
    $blockFound = $true
    $block = $Matches[1]
    foreach ($m in [regex]::Matches($block, '`([^`]+)`')) { $documented += $m.Groups[1].Value }
    # DERIVED-COUNTS RULE: counts in prose are mirrored or deleted. The stale-count
    # defect recurred three times (ALL 5 while six ran; "30 deny / 13 allow" while 40/18 ran;
    # "Six checks:" while ten ran). A number a human types is a number that goes stale, so the
    # document no longer types them -- it mirrors these, and they are enforced below.
    foreach ($m in [regex]::Matches($block, 'TALLY\s+([a-z-]+):\s*(\d+)')) {
        $docTallies[$m.Groups[1].Value] = [int]$m.Groups[2].Value
    }
}
$caseNames = @($denyCases | ForEach-Object { $_.n })
$missingFromDoc  = @($caseNames  | Where-Object { $documented -notcontains $_ })
$extraInDoc      = @($documented | Where-Object { $caseNames  -notcontains $_ })

# Actual tallies, derived here and nowhere else. `checks` is emitted by the summary line below.
$actualTallies = @{
    'deny-cases'  = $caseNames.Count
    'allow-cases' = @($allowCases).Count
}
$tallyMismatch = @()
foreach ($k in $actualTallies.Keys) {
    if (-not $docTallies.ContainsKey($k))          { $tallyMismatch += "$k MISSING from notes" }
    elseif ($docTallies[$k] -ne $actualTallies[$k]) { $tallyMismatch += "$k notes=$($docTallies[$k]) actual=$($actualTallies[$k])" }
}
foreach ($k in $docTallies.Keys) {
    if (-not $actualTallies.ContainsKey($k) -and $k -ne 'checks') { $tallyMismatch += "$k documented but not derived here" }
}
# 'checks' is special: it must equal the number of Check calls, known only at the end. Verified
# by the summary assertion instead -- see the tail of this script.
$script:DocumentedCheckCount = $(if ($docTallies.ContainsKey('checks')) { $docTallies['checks'] } else { -1 })

$detail = @"
  mirror block found in threat notes : $blockFound
  IN TEST, MISSING FROM NOTES        : $(if ($missingFromDoc.Count) { $missingFromDoc -join ' | ' } else { '(none)' })
  IN NOTES, NOT A TEST CASE          : $(if ($extraInDoc.Count) { $extraInDoc -join ' | ' } else { '(none)' })
  TALLY mismatches                   : $(if ($tallyMismatch.Count) { $tallyMismatch -join ' | ' } else { '(none)' })
  documented TALLY checks            : $script:DocumentedCheckCount  (verified against the run total at the summary)

  An entry in MISSING FROM NOTES would be an undemonstrated claim -- the BF2/B7 defect.
  An entry in NOT A TEST CASE would be a documented catch the test never runs -- same defect.
  A TALLY mismatch would be a stale authored count -- the defect that recurred three times.
"@
Check -Id 'N10' -Title 'threat-notes Catches list and tallies are exactly the N2 population (derived, not authored)' `
      -Ok ($blockFound -and $missingFromDoc.Count -eq 0 -and $extraInDoc.Count -eq 0 -and
           $tallyMismatch.Count -eq 0) -Detail $detail

# =============================================================================
# N11 -- a first-hook error is visible even when NOTHING else was captured (F3)
# =============================================================================
# Attempt-4 Scenario A, promoted to an assertion: PostToolUse throws before it can append, so
# there is no log and no manifest -- only an error log. The state read "no log and no manifest
# on disk", indistinguishable from a dispatch that never ran, while two artifact files claimed
# the hint rode on every branch.
$dispatch6 = 'a1-negative-test-firsthook'
$env:MISSION_DISPATCH_ID = $dispatch6
Write-EvidenceHookError -Hook 'PostToolUse' -DispatchId $dispatch6 -Message 'SIMULATED first-hook failure for N11'
$ev6 = Join-Path $sandbox ".mission-runtime\evidence\$dispatch6"
$state11 = Get-EvidenceState -Root $sandbox -DispatchId $dispatch6

$detail = @"
  log.jsonl present            : $(Test-Path -LiteralPath (Join-Path $ev6 'log.jsonl'))   (expect False)
  manifest.json present        : $(Test-Path -LiteralPath (Join-Path $ev6 'manifest.json'))   (expect False)
  hook-errors.log present      : $(Test-Path -LiteralPath (Join-Path $ev6 'hook-errors.log'))   (expect True)
  derived state                : $($state11.state)   (expect ABSENT)
  reason mentions hook-errors  : $($state11.reason -like '*hook-errors.log EXISTS*')   (expect True)
  forensics                    : $($state11.forensics)   (expect True -- the error log is forensic material)
  reason                       : $($state11.reason)
"@
Check -Id 'N11' -Title 'ABSENT state still surfaces a hook error (no log, no manifest, error log present)' `
      -Ok ($state11.state -eq 'ABSENT' -and ($state11.reason -like '*hook-errors.log EXISTS*') -and
           $state11.forensics -eq $true) -Detail $detail

$env:MISSION_DISPATCH_ID = $dispatch

# =============================================================================
# N12 -- residual (b): the empty catch fires, records nothing, and only parity sees it
# =============================================================================
# RESIDUAL (b) AS DEFINED: the reconcile pass's own committed-plane re-copy failing inside an
# EMPTY CATCH. To drive that code path the publish must genuinely THROW, twice:
#   phase 1 copy fails    -> error recorded  (1 line)
#   phase 3 copy fails    -> error recorded  (2 lines)
#   reconcile fires       -> because the recorded hash no longer matches the grown error log
#   reconcile's re-copy fails -> swallowed by the EMPTY CATCH, recording nothing
#
# METHOD: plant a FILE at the committed DISPATCH DIRECTORY path -- N9's mechanics. Creating the
# directory fails, so every copy beneath it fails.
#
# WHY NOT A DIRECTORY AT manifest.json: an earlier revision of this check planted a directory
# where the manifest file must go and claimed it made the copy fail. It does not.
# `Copy-Item -Destination <existing directory>` SUCCEEDS -- it puts the file INSIDE the
# directory. That produced the right outcome (nothing at the canonical path, anchor blind,
# parity catches it) by the wrong mechanism, and the comment asserted the mechanism it intended
# rather than the one that ran. A validator measured it; `reconciled` was the witness, absent
# where the comment implied it must be present. That scenario is real and is kept as N12c.
$dispatch7 = 'a1-negative-test-planeparity'
$env:MISSION_DISPATCH_ID = $dispatch7
$ev7 = Join-Path $sandbox ".mission-runtime\evidence\$dispatch7"
$cm7 = Join-Path $sandbox ".mission\evidence\$dispatch7"
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
    session_id = 'sess-parity'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'git rev-parse HEAD' }
    tool_response = @{ stdout = "$realSha`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
New-Item -ItemType Directory -Path (Split-Path -Parent $cm7) -Force | Out-Null
[System.IO.File]::WriteAllText($cm7, 'not a directory')      # the blocker: a FILE at the dir path
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{ session_id = 'sess-parity'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)

$state12  = Get-EvidenceState        -Root $sandbox -DispatchId $dispatch7
$parity12 = Test-EvidencePlaneParity -Root $sandbox -DispatchId $dispatch7
$man12p = Join-Path $ev7 'manifest.json'
$man12  = if (Test-Path -LiteralPath $man12p) { [System.IO.File]::ReadAllText($man12p) | ConvertFrom-Json } else { $null }
$err12  = Join-Path $ev7 'hook-errors.log'
$err12Lines = if (Test-Path -LiteralPath $err12) { @([System.IO.File]::ReadAllLines($err12) | Where-Object { $_.Trim() }).Count } else { 0 }
$err12Sha = if (Test-Path -LiteralPath $err12) { (Get-FileHash -Algorithm SHA256 -LiteralPath $err12).Hash.ToLower() } else { $null }
$anchorAgrees12 = ($null -ne $man12) -and ($man12.hook_errors_sha256 -eq $err12Sha)
$reconciled12   = ($null -ne $man12) -and ($man12.PSObject.Properties.Name -contains 'reconciled') -and ($man12.reconciled -eq $true)

$detail = @"
  MECHANISM -- the empty-catch path really ran
    committed dispatch path is a FILE : $(Test-Path -LiteralPath $cm7 -PathType Leaf)   (the blocker)
    publish errors recorded           : $err12Lines   (expect >=2 -- phase 1 AND phase 3 threw)
    reconciled flag in manifest       : $reconciled12   (expect True -- the reconcile pass fired,
                                        so its own re-copy ran and failed inside the EMPTY CATCH)

  THE ANCHOR DETECTOR -- provably blind here
    manifest hook_errors_sha256       : $(if ($man12) { $man12.hook_errors_sha256 } else { 'n/a' })
    re-hash of hook-errors.log        : $err12Sha
    anchor AGREES (detects nothing)   : $anchorAgrees12   (expect True)

  THE PLANE-COMPARISON DETECTOR -- the one that works
    derived state                     : $($state12.state)
    checked                           : $($parity12.checked)
    ok                                : $($parity12.ok)   (expect False)
    reason                            : $($parity12.reason)
    problems:
      $($parity12.problems -join "`n      ")
"@
Check -Id 'N12' -Title 'residual (b): reconcile fires, its re-copy dies in the empty catch, and only parity sees it' `
      -Ok ($reconciled12 -and $err12Lines -ge 2 -and $anchorAgrees12 -and
           $parity12.ok -eq $false -and $parity12.checked -ge 2) -Detail $detail

# The positive control: a clean dispatch must report parity OK, or the detector proves nothing.
$parityClean = Test-EvidencePlaneParity -Root $sandbox -DispatchId $dispatch3
$detail = @"
  clean dispatch ($dispatch3)
    checked : $($parityClean.checked)
    ok      : $($parityClean.ok)   (expect True)
    reason  : $($parityClean.reason)
"@
Check -Id 'N12b' -Title 'plane comparison reports OK on a cleanly published dispatch (positive control)' `
      -Ok ($parityClean.ok -eq $true -and $parityClean.checked -ge 2) -Detail $detail

# =============================================================================
# N12c -- SILENT MISPUBLISH: a copy that succeeds to the wrong place
# =============================================================================
# A distinct member of the same outcome class, kept because it was measured and is real: plant a
# DIRECTORY where the committed manifest.json must go. `Copy-Item -Destination <directory>`
# SUCCEEDS and puts the file inside it, so the canonical path holds no manifest, NOTHING is
# recorded, the reconcile pass never fires -- and the anchor is blind for a different reason
# than in N12 (there is no error at all, rather than an error whose hash matches).
$dispatch8 = 'a1-negative-test-mispublish'
$env:MISSION_DISPATCH_ID = $dispatch8
$ev8 = Join-Path $sandbox ".mission-runtime\evidence\$dispatch8"
$cm8 = Join-Path $sandbox ".mission\evidence\$dispatch8"
$null = Invoke-Hook -Script 'evidence-post-tool-use.ps1' -Json (@{
    session_id = 'sess-mispublish'; hook_event_name = 'PostToolUse'; tool_name = 'Bash'
    tool_input = @{ command = 'git rev-parse HEAD' }
    tool_response = @{ stdout = "$realSha`n"; stderr = ''; exit_code = 0 } } | ConvertTo-Json -Depth 8 -Compress)
New-Item -ItemType Directory -Path (Join-Path $cm8 'manifest.json') -Force | Out-Null   # the blocker
$null = Invoke-Hook -Script 'evidence-stop-finalize.ps1' -Json (@{ session_id = 'sess-mispublish'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)

$parity8 = Test-EvidencePlaneParity -Root $sandbox -DispatchId $dispatch8
$man8p = Join-Path $ev8 'manifest.json'
$man8  = if (Test-Path -LiteralPath $man8p) { [System.IO.File]::ReadAllText($man8p) | ConvertFrom-Json } else { $null }
$err8  = Join-Path $ev8 'hook-errors.log'
$nested8 = Join-Path (Join-Path $cm8 'manifest.json') 'manifest.json'

$detail = @"
  MECHANISM -- a successful copy to the wrong path, not a failure
    committed manifest.json is a DIR  : $(Test-Path -LiteralPath (Join-Path $cm8 'manifest.json') -PathType Container)
    manifest landed INSIDE it         : $(Test-Path -LiteralPath $nested8 -PathType Leaf)   (the mispublish)
    canonical path holds a FILE       : $(Test-Path -LiteralPath (Join-Path $cm8 'manifest.json') -PathType Leaf)   (expect False)
    hook-errors.log exists            : $(Test-Path -LiteralPath $err8)   (expect False -- nothing recorded)
    reconciled flag                   : $(if ($man8 -and ($man8.PSObject.Properties.Name -contains 'reconciled')) { $man8.reconciled } else { '(absent -- reconcile never fired)' })

  PARITY -- catches it anyway
    ok                                : $($parity8.ok)   (expect False)
    problems:
      $($parity8.problems -join "`n      ")
"@
Check -Id 'N12c' -Title 'silent mispublish: copy succeeds to the wrong path, nothing recorded, parity still catches it' `
      -Ok ($parity8.ok -eq $false -and (-not (Test-Path -LiteralPath $err8)) -and
           (Test-Path -LiteralPath $nested8 -PathType Leaf) -and
           @($parity8.problems | Where-Object { $_ -like '*manifest.json*' }).Count -ge 1) -Detail $detail

$env:MISSION_DISPATCH_ID = $dispatch

# --- summary ---------------------------------------------------------------------------------
Write-Host ""
Write-Host "=============================================================================="
# DERIVED-COUNTS RULE, final arm: the check total documented in the threat notes'
# mirror block must equal the number of checks that actually ran. Known only here.
#
# Finding 5: this runs BEFORE the summary. The previous order printed
# "ALL 11 CHECKS PASSED" and only then the TALLY failure, so a failing run (exit 1) read green
# to anyone who skimmed the last box. No green line may appear on a failing run.
if ($script:DocumentedCheckCount -ne $checksRun) {
    Write-Host ""
    Write-Host "[FAIL] TALLY checks -- notes say $script:DocumentedCheckCount, this run executed $checksRun"
    $failures++
}

# The count is derived from checks actually run, never hardcoded -- a stale "ALL 5" while six
# ran is a small lie of exactly the kind this artifact exists to make impossible.
if ($failures -eq 0) { Write-Host " ALL $checksRun CHECKS PASSED" } else { Write-Host " $failures FAILURE(S) across $checksRun CHECK(S) -- SUITE FAILED" }
Write-Host "=============================================================================="

if (-not $KeepSandbox) {
    Remove-Item -LiteralPath $sandbox -Recurse -Force
    Write-Host "sandbox removed: $sandbox"
} else {
    Write-Host "sandbox kept for inspection: $sandbox"
}
Remove-Item Env:\CLAUDE_PROJECT_DIR  -ErrorAction SilentlyContinue
Remove-Item Env:\MISSION_DISPATCH_ID -ErrorAction SilentlyContinue

exit $failures
