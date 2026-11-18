#Requires -Version 5.1
<#
.SYNOPSIS
  The falsifiers of ADR-046 (Accepted, amended twice): the operator-wait stop -- run by path, never part of a whole
  instrument run.

.DESCRIPTION
  THE EXIT CODE IS THE CONTRACT: the number of rows that do not hold, GUARD and FALSIFIER together.

  Each member builds a synthetic mission under -Scratch (a %TEMP% folder by default), runs the stop evaluator
  tools/lam/mission-goal-check.ps1 over it -- as the Stop hook (a Stop payload on stdin, -AsStopHook) and by
  hand -- and reads ONLY what the evaluator produced: the verdict artifact's `verdict:`, `short_circuited:` and list
  keys, the hook's JSON decision and reason, and the process exit. What a row looks for in a list or a reason is an
  INVENTED ID of its own fixture, never a word that names the form; no row reads a comment or the record.

  Every row carries one of two tags:
    GUARD      holds before AND after the build: a stop this form must never admit, or a verdict it must never move.
    FALSIFIER  what ADR-046 would change: RED on a tree without the form -- the evaluator refuses the unknown detector
               type, which each row prints as its reason -- and GREEN after the build. Every refused or released case
               carries one, reading the arm's own refused or released list, so an arm that refused everything could
               not turn its member green. AMENDMENT 2's rows (ruling (y): `settled` for push only; the evaluator calls
               nothing) are RED on the tree that built ruling (v), 38311c10, and GREEN after its removal -- except
               W-4's two settled rows with no gate, which that tree refused too.

  W-16, W-17, W-18 and W-24 were ruling (v)'s members; they are retired with it, and their numbers are not reused.
  W-27's FALSIFIER rows are RED on 63685de5, whose added refusal Amendment 2's validator round 1 found (D1).
  W-26 enters a job object of its own, so every process this script creates as a descendant from that member on is
  counted in it (one started through WMI, the task scheduler or COM is not). W-28's rows are GUARDs.

  Every id, gate, goal and file below is invented; nothing names a host. The fixtures are removed at the end unless
  -Keep is given.
#>
[CmdletBinding()]
param(
    [string]$Scratch = (Join-Path ([System.IO.Path]::GetTempPath()) 'lam-opwait'),
    [string]$Evaluator,
    [switch]$Keep
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Evaluator) { $Evaluator = Join-Path $repoRoot 'tools\lam\mission-goal-check.ps1' }
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$Scratch = [System.IO.Path]::GetFullPath($Scratch)
if (-not $Scratch.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output "REFUSED: -Scratch must lie under $tempRoot; fixtures are never built elsewhere."
    exit 99
}
$runDir = Join-Path $Scratch ('run-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$script:guardFail = 0
$script:falsifierRed = 0
$script:fxCount = 0
$script:shaGen = [System.Security.Cryptography.SHA256]::Create()
$verdictWord = 'AWAITING_OPERATOR'

function Write-Fx {
    param([string]$Path, [string]$Text)
    $d = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
function Get-FxSha {
    param([string]$Path)
    return ([BitConverter]::ToString($script:shaGen.ComputeHash([System.IO.File]::ReadAllBytes($Path)))).Replace('-', '').ToLowerInvariant()
}
function New-Fx {
    # One synthetic mission: .mission\goals, an evidence\built.txt, nothing else.
    param([string]$Tag)
    $script:fxCount++
    $root = Join-Path (Join-Path $runDir ($Tag + '-' + $script:fxCount)) 'm'
    New-Item -ItemType Directory -Path (Join-Path $root '.mission\goals') -Force | Out-Null
    Write-Fx -Path (Join-Path $root 'evidence\built.txt') -Text "built`n"
    return $root
}
function Write-FxGoal {
    # -Wait declares the arm; -Met makes the goal's other detector pass; -Manifest declares the dispatch-manifest arm.
    param([string]$Root, [string]$GoalId, [switch]$Wait, [switch]$Met, [switch]$Manifest)
    $lines = @(('id: ' + $GoalId), 'detectors:')
    if ($Manifest) { $lines += '  - type: ungated_manifest_absent' }
    if ($Wait) { $lines += '  - type: operator_wait_present' }
    $lines += '  - type: file_exists'
    $lines += $(if ($Met) { '    path: evidence/built.txt' } else { '    path: evidence/absent.txt' })
    Write-Fx -Path (Join-Path $Root ('.mission\goals\' + $GoalId + '.yaml')) -Text (($lines -join "`n") + "`n")
}
function Write-FxHead {
    param([string]$Root, [string]$Head)
    Write-Fx -Path (Join-Path $Root '.mission-runtime\lam\STATUS.md') -Text ($Head + "`n`nthe seat's edition body`n")
}
function Get-FxGatePath {
    param([string]$Root, [string]$Kind, [string]$Id)
    return (Join-Path (Join-Path (Join-Path $Root '.mission') 'gates') ($Kind + '-' + $Id + '.yaml'))
}
function Write-FxGate {
    # A gate in the line set and order of a real console mint (CR LF). -ConsumedAt/-Basis append a consume block;
    # -RevokedAt the three revoke lines; -IdField overrides the id: value; -ExtraId writes a second id: line.
    param([string]$Root, [string]$Kind, [string]$Id, [string]$ConsumedAt = '', [string]$Basis = '', [string]$RevokedAt = '',
          [string]$IdField = '', [switch]$ExtraId, [string]$BindsRel = 'inputs/bound.txt', [string]$Sha = ('ab' * 32))
    if (-not $IdField) { $IdField = $Id }
    $gClass = if (@('push', 'dispatch') -contains $Kind) { 'build-authorization' } else { 'governance' }
    $gLines = @(
        '# Gate artifact -- created by a human, consumed once, retained for audit.',
        '# synthetic fixture of the operator-wait falsifiers.',
        ('kind: ' + $Kind), ('gate_class: ' + $gClass), ('id: ' + $IdField), ('push_id: ' + $Kind + '-' + $IdField),
        ('binds: ' + $BindsRel),
        'binds_resolved_note: "RECORD, not an input: the absolute path this mint actually hashed. Consumers re-derive rather than trust it."',
        'binds_resolved: fixture', ('binds_sha256: ' + $Sha), 'authorized_by: fx-operator', 'host: fx',
        'operator_credential: injected-seam', 'created_at: 2026-11-01T00:00:00.000Z', 'expires_at: 2026-11-01T01:00:00.000Z',
        'single_use: true', ('consumed_at: ' + $(if ($ConsumedAt) { $ConsumedAt } else { 'null' })))
    if ($ExtraId) { $gLines += ('id: ' + $IdField + '-b') }
    $gText = ($gLines -join "`r`n") + "`r`n"
    if ($ConsumedAt) { $gText += "consumed_origin_tip: 0000000000000000000000000000000000000000`r`nconsumed_ref: refs/heads/main`r`nconsumed_origin_before: not observed at mint`r`nconsumed_basis: $Basis`r`n" }
    if ($RevokedAt) { $gText += 'revoked_at: ' + $RevokedAt + "`nrevoked_by: fx-operator`nrevoked_reason: `"fixture revocation`"`n" }
    Write-Fx -Path (Get-FxGatePath -Root $Root -Kind $Kind -Id $Id) -Text $gText
}
function Invoke-FxGit {
    # git in a fixture root: commit identity on the command line, never `git config`; the GIT_* variables that
    # redirect a repository are taken out for the child. Throws on a non-zero exit.
    param([string]$Root, [string[]]$GitArgs)
    $saved = @{}
    foreach ($v in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY')) {
        $saved[$v] = [Environment]::GetEnvironmentVariable($v); [Environment]::SetEnvironmentVariable($v, $null)
    }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $o = & git -C $Root -c user.name=fx-seat -c user.email=fx-seat@example.invalid -c core.autocrlf=false -c commit.gpgsign=false @GitArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
        foreach ($v in @($saved.Keys)) { [Environment]::SetEnvironmentVariable($v, $saved[$v]) }
    }
    if ($code -ne 0) { throw ('git ' + ($GitArgs -join ' ') + ' exited ' + $code + ': ' + ((@($o) | ForEach-Object { [string]$_ }) -join ' ')) }
}
function New-FxRepo {
    # A synthetic mission that is a git repository with one first commit (README.txt), the git dir its own.
    param([string]$Tag)
    $root = New-Fx -Tag $Tag
    Invoke-FxGit -Root $root -GitArgs @('init', '-q')
    Write-Fx -Path (Join-Path $root 'README.txt') -Text "a synthetic mission`n"
    Invoke-FxGit -Root $root -GitArgs @('add', '--', 'README.txt')
    Invoke-FxGit -Root $root -GitArgs @('commit', '-q', '-m', 'first')
    return $root
}
function Get-FxListKey {
    param([string]$Text, [string]$Key)
    $items = New-Object System.Collections.Generic.List[string]
    $in = $false
    foreach ($ln in (($Text -replace "`r", '') -split "`n")) {
        if (-not $in) { if ($ln -ceq ($Key + ':')) { $in = $true }; continue }
        $m = [regex]::Match($ln, '^  - ''(.*)''$')
        if (-not $m.Success) { break }
        $items.Add($m.Groups[1].Value.Replace("''", "'"))
    }
    return $items.ToArray()
}
function Invoke-FxEval {
    # The evaluator over one fixture: -Hook as the Stop hook runs it, else by hand. The prior artifact is removed
    # first so what is read is this run's; LAM_DISPATCH is cleared for the child.
    param([string]$Root, [string]$GoalId, [switch]$Hook)
    $vf = Join-Path $Root ('.mission\goals\' + $GoalId + '.verdict.yaml')
    if (Test-Path -LiteralPath $vf) { Remove-Item -LiteralPath $vf -Force }
    $saved = $env:LAM_DISPATCH; $env:LAM_DISPATCH = $null
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        if ($Hook) {
            $payload = (@{ session_id = 'fx-opwait'; hook_event_name = 'Stop' } | ConvertTo-Json -Compress)
            $o = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $Evaluator -Goal $GoalId -MissionRoot $Root -AsStopHook 2>&1
        } else {
            $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $Evaluator -Goal $GoalId -MissionRoot $Root 2>&1
        }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev; if ($null -ne $saved) { $env:LAM_DISPATCH = $saved } }
    $lines = @(@($o) | ForEach-Object { [string]$_ })
    $text = if (Test-Path -LiteralPath $vf) { [System.IO.File]::ReadAllText($vf) } else { '' }
    $v = '(no verdict file)'
    $vm = [regex]::Match($text, '(?m)^verdict:[ \t]*(\S+)')
    if ($vm.Success) { $v = $vm.Groups[1].Value }
    $sc = -1
    $scm = [regex]::Match($text, '(?m)^short_circuited:[ \t]*(\d+)')
    if ($scm.Success) { $sc = [int]$scm.Groups[1].Value }
    $dec = ''; $reason = ''
    foreach ($ln in $lines) {
        if ($ln -match '^\s*\{.*"decision"') { try { $j = $ln | ConvertFrom-Json; $dec = [string]$j.decision; $reason = [string]$j.reason } catch { } }
    }
    # The first failing detector's detail, the root taken out -- printed as the reason for a reading, never asserted.
    $why = ''
    $fm = [regex]::Match($text, '(?m)^  - type: (\S+)\r?\n    ok: false\r?\n    detail: ''(.*)''\r?$')
    if ($fm.Success) { $why = $fm.Groups[1].Value + ': ' + $fm.Groups[2].Value.Replace("''", "'") }
    $why = $why.Replace($Root, '<fx>')
    if ($why.Length -gt 110) { $why = $why.Substring(0, 110) + '...' }
    return [pscustomobject]@{ verdict = $v; decision = $dec; reason = $reason; exit = $code; text = $text; why = $why; sc = $sc
                              openHalts = [bool]($text -match '(?m)^open_halts:[ \t]*\r?\n  - ')
                              wait = @(Get-FxListKey -Text $text -Key 'operator_wait')
                              released = @(Get-FxListKey -Text $text -Key 'operator_wait_released')
                              refused = @(Get-FxListKey -Text $text -Key 'operator_wait_refused')
                              admitted = (($dec -ceq 'approve') -and ($code -eq 0)) }
}
function Format-Fx {
    param($R, [string]$Mode)
    return ('{0}: {1}, {2}exit {3}' -f $Mode, $R.verdict, $(if ($R.decision) { $R.decision + ', ' } else { '' }), $R.exit) + $(if ($R.why) { ' -- ' + $R.why } else { '' })
}
function Test-FxNames {
    # Does exactly one item of the list name this invented id (ASCII case folded)?
    param([object[]]$List, [string]$Id)
    return (@(@($List) | Where-Object { ([string]$_).IndexOf($Id, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -ge 1)
}
function G { param([bool]$Ok, [string]$Said) return [pscustomobject]@{ tag = 'GUARD'; ok = $Ok; said = $Said } }
function F { param([bool]$Ok, [string]$Said) return [pscustomobject]@{ tag = 'FALSIFIER'; ok = $Ok; said = $Said } }
function Report {
    param([string]$Id, [string]$Title, [object[]]$Rows)
    $g = @($Rows | Where-Object { ($_.tag -eq 'GUARD') -and (-not $_.ok) }).Count
    $f = @($Rows | Where-Object { ($_.tag -eq 'FALSIFIER') -and (-not $_.ok) }).Count
    $script:guardFail += $g
    $script:falsifierRed += $f
    $face = if ($g -gt 0) { 'GUARD BROKEN' } elseif ($f -gt 0) { 'RED' } else { 'HOLDS' }
    Write-Output ''
    Write-Output ('[{0}] {1} -- {2}' -f $face, $Id, $Title)
    foreach ($row in $Rows) { Write-Output ('    {0} {1,-9} {2}' -f $(if ($row.ok) { 'ok  ' } else { 'FAIL' }), $row.tag, $row.said) }
}
# Rows shared by every case the arm must REFUSE: the stop is refused (GUARD) and the arm says why (FALSIFIER).
function Get-RefusedRows {
    param($R, [string]$What, [string]$Id)
    return @((G ((-not $R.admitted) -and ($R.verdict -ceq 'NOT_MET')) ($What + ' -- not admitted, NOT_MET -- ' + (Format-Fx $R 'hook'))),
             (F (@($R.refused).Count -ge 1) ($What + ' -- the arm''s refused list is not empty (' + @($R.refused).Count + ')')))
}

Write-Output '=============================================================================='
Write-Output ' ADR-046 FALSIFIERS -- the operator-wait stop (Accepted, amended twice)'
Write-Output '=============================================================================='
Write-Output ('evaluator : ' + $Evaluator.Replace($repoRoot, '<repo>') + ' sha256 ' + (Get-FxSha -Path $Evaluator))

try {
# ---- W-1: an unmet, testable wait, no HALT -> admitted -------------------------------------------------
$r = New-Fx -Tag 'w1'
Write-FxGoal -Root $r -GoalId 'G-W1' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w1-r1 minted'
$h = Invoke-FxEval -Root $r -GoalId 'G-W1' -Hook
$hd = Invoke-FxEval -Root $r -GoalId 'G-W1'
Report -Id 'W-1' -Title 'an unmet wait on one testable condition, no HALT: admitted, and the verdict names the wait and what was read' -Rows @(
    (F ($h.admitted -and ($h.verdict -ceq $verdictWord)) ('hook: approve, exit 0, ' + $verdictWord + ' -- ' + (Format-Fx $h 'hook'))),
    (F (($h.sc -ge 1) -and ($h.verdict -ceq $verdictWord)) ('hook: the goal''s other detector NOT EVALUATED because the wait admitted (' + $h.verdict + ', short_circuited ' + $h.sc + ')')),
    (F (($hd.exit -eq 7) -and ($hd.verdict -ceq $verdictWord)) ('hand: exit 7, ' + $verdictWord + ' -- ' + (Format-Fx $hd 'hand'))),
    (F ((Test-FxNames $hd.wait 'w1-r1') -and (Test-FxNames $hd.wait 'dispatch-w1-r1.yaml')) ('the wait list names the id and the gate read (' + @($hd.wait).Count + ' item(s))')))

# ---- W-1m: an unmet wait over a MET goal (D6) ------------------------------------------------------------
$r = New-Fx -Tag 'w1m'
Write-FxGoal -Root $r -GoalId 'G-W1M' -Wait -Met
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate completion-acceptance w1m-c1 minted'
$hd = Invoke-FxEval -Root $r -GoalId 'G-W1M'
Report -Id 'W-1m' -Title 'D6: an unmet wait outranks a met goal, as every arm does' -Rows @(
    (F (($hd.exit -eq 7) -and ($hd.verdict -ceq $verdictWord)) ('hand: exit 7, ' + $verdictWord + ' -- ' + (Format-Fx $hd 'hand'))))

# ---- W-2: minted met by an open, a consumed and a revoked gate -----------------------------------------------
$rows = @()
foreach ($st in @('open', 'consumed', 'revoked')) {
    $r = New-Fx -Tag ('w2' + $st)
    $id = 'w2-' + $st
    Write-FxGoal -Root $r -GoalId 'G-W2' -Wait
    Write-FxHead -Root $r -Head ('OPERATOR WAIT gate dispatch ' + $id + ' minted')
    if ($st -eq 'open') { Write-FxGate -Root $r -Kind 'dispatch' -Id $id }
    elseif ($st -eq 'consumed') { Write-FxGate -Root $r -Kind 'dispatch' -Id $id -ConsumedAt '2026-11-01T00:20:00.000Z' -Basis 'spawn by the runner under this gate' }
    else { Write-FxGate -Root $r -Kind 'dispatch' -Id $id -RevokedAt '2026-11-01T00:25:00.000Z' }
    $h = Invoke-FxEval -Root $r -GoalId 'G-W2' -Hook
    $rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('a ' + $st + ' gate stands -- not admitted, NOT_MET -- ' + (Format-Fx $h 'hook')))
    $rows += (F (Test-FxNames $h.released $id) ('a ' + $st + ' gate stands -- the released list names ' + $id))
}
Report -Id 'W-2' -Title 'a minted wait whose gate stands, in any state, admits nothing and is released' -Rows $rows

# ---- W-2p: push settled by the console ------------------------------------------------------------------------
$r = New-Fx -Tag 'w2p'
Write-FxGoal -Root $r -GoalId 'G-W2P' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate push w2-p1 settled'
Write-FxGate -Root $r -Kind 'push' -Id 'w2-p1' -ConsumedAt '2026-11-01T00:30:00.000Z' -Basis 'post-push witness by console: the DECLARED origin observed holding the authorized sha'
$h = Invoke-FxEval -Root $r -GoalId 'G-W2P' -Hook
Report -Id 'W-2p' -Title 'a push wait settled by the console admits nothing and is released' -Rows @(
    (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('not admitted, NOT_MET -- ' + (Format-Fx $h 'hook'))),
    (F (Test-FxNames $h.released 'w2-p1') 'the released list names w2-p1'))

# ---- W-2m: a released wait over a met goal ---------------------------------------------------------------------
$r = New-Fx -Tag 'w2m'
Write-FxGoal -Root $r -GoalId 'G-W2M' -Wait -Met
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate amendment-material w2m-a1 minted'
Write-FxGate -Root $r -Kind 'amendment-material' -Id 'w2m-a1'
$h = Invoke-FxEval -Root $r -GoalId 'G-W2M' -Hook
Remove-Item -LiteralPath (Get-FxGatePath -Root $r -Kind 'amendment-material' -Id 'w2m-a1') -Force
$h2 = Invoke-FxEval -Root $r -GoalId 'G-W2M' -Hook
$hd = Invoke-FxEval -Root $r -GoalId 'G-W2M'
Report -Id 'W-2m' -Title 'a released wait leaves the goal judged as if it had never been: MET, and MET again once its gate is gone' -Rows @(
    (F ($h.admitted -and ($h.verdict -ceq 'MET') -and (Test-FxNames $h.released 'w2m-a1')) ('gate stands: approve, exit 0, MET, released names w2m-a1 -- ' + (Format-Fx $h 'hook'))),
    (F ($h2.admitted -and ($h2.verdict -ceq 'MET') -and (Test-FxNames $h2.released 'w2m-a1')) ('gate gone: approve, exit 0, MET, released (before) names w2m-a1 -- ' + (Format-Fx $h2 'hook'))),
    (F (($hd.exit -eq 0) -and ($hd.verdict -ceq 'MET')) ('hand: exit 0, MET -- ' + (Format-Fx $hd 'hand'))))

# ---- W-3: after release -------------------------------------------------------------------------------------------
$rows = @()
$r = New-Fx -Tag 'w3'
Write-FxGoal -Root $r -GoalId 'G-W3' -Wait
Write-FxGoal -Root $r -GoalId 'G-W3B' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate supersession w3-s1 minted'
$null = Invoke-FxEval -Root $r -GoalId 'G-W3' -Hook
Write-FxGate -Root $r -Kind 'supersession' -Id 'w3-s1'
$null = Invoke-FxEval -Root $r -GoalId 'G-W3' -Hook
Remove-Item -LiteralPath (Get-FxGatePath -Root $r -Kind 'supersession' -Id 'w3-s1') -Force
$h = Invoke-FxEval -Root $r -GoalId 'G-W3' -Hook
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('the same triple again, its gate gone -- not admitted -- ' + (Format-Fx $h 'hook')))
$rows += (F ((Test-FxNames $h.released 'w3-s1') -or (Test-FxNames $h.refused 'w3-s1')) 'the arm names w3-s1 as released before')
$h = Invoke-FxEval -Root $r -GoalId 'G-W3B' -Hook
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('the same triple under another goal -- not admitted -- ' + (Format-Fx $h 'hook')))
$rows += (F ((Test-FxNames $h.released 'w3-s1') -or (Test-FxNames $h.refused 'w3-s1')) 'another goal: the arm names w3-s1 as released before')
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate supersession W3-S1 minted'
$h = Invoke-FxEval -Root $r -GoalId 'G-W3' -Hook
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('the id in another case -- not admitted -- ' + (Format-Fx $h 'hook')))
$rows += (F ((Test-FxNames $h.released 'w3-s1') -or (Test-FxNames $h.refused 'w3-s1')) 'another case: the arm names w3-s1 as released before')
$r = New-Fx -Tag 'w3h'
Write-FxGoal -Root $r -GoalId 'G-W3H' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate reclose w3h-c1 minted'
Write-FxGate -Root $r -Kind 'reclose' -Id 'w3h-c1'
$null = Invoke-FxEval -Root $r -GoalId 'G-W3H'
Remove-Item -LiteralPath (Get-FxGatePath -Root $r -Kind 'reclose' -Id 'w3h-c1') -Force
$h = Invoke-FxEval -Root $r -GoalId 'G-W3H' -Hook
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('a release a HAND run read, then the gate gone -- not admitted -- ' + (Format-Fx $h 'hook')))
$rows += (F ((Test-FxNames $h.released 'w3h-c1') -or (Test-FxNames $h.refused 'w3h-c1')) 'the hand run''s release is named')
Report -Id 'W-3' -Title 'a wait read met once never admits again: same goal, another goal, another case, a hand run''s reading' -Rows $rows

# ---- W-4: R5, the grammar ---------------------------------------------------------------------------------------------
$heads = @('OPERATOR WAIT', 'OPERATOR WAIT the operator recreates the container',
           'OPERATOR WAIT gate dispatch w4-r1 minted gate push w4-p1 settled', 'OPERATOR WAIT gate permit w4-r1 minted',
           'OPERATOR WAIT gate dispatch w4-r1 MINTED', 'OPERATOR WAIT gate dispatch w4-r1 pushed',
           ('OPERATOR WAIT gate supersession w4' + ('x' * 199) + ' minted'), 'OPERATOR WAIT gate halt-ruling HALT-W4 minted',
           'OPERATOR WAIT gate witness-attested w4-w1 minted', 'OPERATOR WAIT gate dispatch w4-r1 settled',
           'OPERATOR WAIT gate Dispatch w4-r1 minted', 'OPERATOR WAIT gate dispatch w4 r1 minted', 'OPERATOR WAIT: gate dispatch w4-r1 minted',
           ('OPERATOR WAIT gate dispatch w4-' + [char]0x212A + ' minted'), ('OPERATOR WAIT gate dispatch w4-' + [char]0x0130 + ' minted'),
           'OPERATOR WAIT gate amendment-material w4-a1 settled', 'OPERATOR WAIT gate reclose w4-c1 settled')
$rows = @()
foreach ($hdText in $heads) {
    $r = New-Fx -Tag 'w4'
    Write-FxGoal -Root $r -GoalId 'G-W4' -Wait
    Write-FxHead -Root $r -Head $hdText
    $h = Invoke-FxEval -Root $r -GoalId 'G-W4' -Hook
    $shown = if ($hdText.Length -gt 60) { $hdText.Substring(0, 44) + '...(' + $hdText.Length + ' chars)' } else { $hdText }
    $rows += (Get-RefusedRows -R $h -What ('"' + $shown + '"'))
}
Report -Id 'W-4' -Title 'R5: no condition, free text, two conditions, an unknown kind or state, an over-long id, an id outside ASCII that a culture-aware match would fold (the Kelvin sign, a dotted capital I), a kind or state left out, settled on amendment-material and reclose (D8 (a))' -Rows $rows

# ---- W-5: R5, observables a seat writes ---------------------------------------------------------------------------------
$rows = @()
$r = New-Fx -Tag 'w5'
Write-FxGoal -Root $r -GoalId 'G-W5' -Wait
Write-Fx -Path (Join-Path $r '.mission\ledger\entries.jsonl') -Text ('{"id":"L-1","tags":["w5-ready"],"text":"ready"}' + "`n")
Write-FxHead -Root $r -Head 'OPERATOR WAIT ledger tag w5-ready'
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W5' -Hook) -What 'a ledger tag the seat appended')
Write-Fx -Path (Join-Path $r '.mission-runtime\operator-acts.log') -Text "2026-11-01T00:00:00Z kind=gate-act verb=approve gate=dispatch-w5 preview_digest=0 credential=fx tool_exit=0`n"
Write-FxHead -Root $r -Head 'OPERATOR WAIT operator-acts gate-act dispatch-w5'
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W5' -Hook) -What 'an operator-acts line the seat appended')
Write-Fx -Path (Join-Path $r 'evidence\w5.txt') -Text "the seat wrote this`n"
Write-FxHead -Root $r -Head ('OPERATOR WAIT file evidence/w5.txt sha256 ' + (Get-FxSha -Path (Join-Path $r 'evidence\w5.txt')))
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W5' -Hook) -What 'a file and its sha256 the seat wrote')
Report -Id 'W-5' -Title 'R5: an observable a seat can write is not in the grammar (R2 itself rests on the console and the guard, not this arm)' -Rows $rows

# ---- W-6: an open HALT governs ------------------------------------------------------------------------------------------
$r = New-Fx -Tag 'w6'
Write-FxGoal -Root $r -GoalId 'G-W6' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate reclose w6-c1 minted'
Write-Fx -Path (Join-Path $r '.mission-runtime\halts\HALT-W6.md') -Text "# HALT-W6`n`n**Status:** OPEN`n"
$h = Invoke-FxEval -Root $r -GoalId 'G-W6' -Hook
$hd = Invoke-FxEval -Root $r -GoalId 'G-W6'
Report -Id 'W-6' -Title 'R4: a wait under an open HALT -- the HALT governs, and its reason still names the wait' -Rows @(
    (G ($h.admitted -and ($h.verdict -ceq 'HALT')) ('hook: approve, exit 0, HALT -- ' + (Format-Fx $h 'hook'))),
    (G (($hd.exit -eq 3) -and ($hd.verdict -ceq 'HALT')) ('hand: exit 3, HALT -- ' + (Format-Fx $hd 'hand'))),
    (F ($h.reason.IndexOf('w6-c1', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 'the HALT reason names w6-c1 beside the HALT'))

# ---- W-7: the record beside the HALT scan ---------------------------------------------------------------------------------
$r = New-Fx -Tag 'w7'
Write-FxGoal -Root $r -GoalId 'G-W7' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate completion-acceptance w7-c1 minted'
$rec = '{"event":"operator_wait_released","at":"2026-11-01T00:00:00.000Z","goal":"G-W7","kind":"completion-acceptance","id":"w7-c1","state":"minted","head":"","read":""}' + "`n"
Write-Fx -Path (Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl') -Text $rec
$h = Invoke-FxEval -Root $r -GoalId 'G-W7' -Hook
Write-Fx -Path (Join-Path $r '.mission-runtime\lam\halt-operator-wait-releases.jsonl') -Text $rec
$hc = Invoke-FxEval -Root $r -GoalId 'G-W7' -Hook
Report -Id 'W-7' -Title 'R6: the wait''s record, kept in the scanned runtime plane, is never read as a HALT' -Rows @(
    (G (($h.verdict -cne 'HALT') -and (-not $h.openHalts)) ('the record alone -- no HALT, open_halts [] -- ' + (Format-Fx $h 'hook'))),
    (G (($hc.verdict -ceq 'HALT') -and $hc.openHalts) ('CONTROL the same bytes under a halt-* name are an open HALT -- ' + (Format-Fx $hc 'hook'))))

# ---- W-8: opt-in --------------------------------------------------------------------------------------------------------
$r = New-Fx -Tag 'w8'
Write-FxGoal -Root $r -GoalId 'G-W8'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w8-r1 minted'
$h = Invoke-FxEval -Root $r -GoalId 'G-W8' -Hook
Report -Id 'W-8' -Title 'D3: a wait head under a goal that does not declare the arm admits nothing' -Rows @(
    (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('not admitted, NOT_MET -- ' + (Format-Fx $h 'hook'))))

# ---- W-9: a push consumed in session is refused, never held ----------------------------------------------------------------
$rows = @()
$r = New-Fx -Tag 'w9'
Write-FxGoal -Root $r -GoalId 'G-W9' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate push w9-p1 settled'
Write-FxGate -Root $r -Kind 'push' -Id 'w9-p1' -ConsumedAt '2026-11-01T00:40:00.000Z' -Basis 'pre-push in-flight witness for this ref + the DECLARED origin observed holding the authorized sha, having ADVANCED from ''(none)'' (amendment 20)'
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W9' -Hook) -What 'a push gate consumed by the seat''s own push')
$r = New-Fx -Tag 'w9r'
Write-FxGoal -Root $r -GoalId 'G-W9R' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate push w9-p2 settled'
Write-FxGate -Root $r -Kind 'push' -Id 'w9-p2' -RevokedAt '2026-11-01T00:45:00.000Z'
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W9R' -Hook) -What 'a revoked push gate the console can no longer settle')
Report -Id 'W-9' -Title 'D7: a settled wait no operator act can release is refused, never held' -Rows $rows

# ---- W-10: the gate's absence must be established ---------------------------------------------------------------------------
$r = New-Fx -Tag 'w10'
Write-FxGoal -Root $r -GoalId 'G-W10' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w10-r1 minted'
Write-Fx -Path (Join-Path (Join-Path $r '.mission') 'gates') -Text "not a folder`n"
Report -Id 'W-10' -Title 'D5: where the gates folder is not a folder, absence is not established and the head is refused' -Rows (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W10' -Hook) -What 'gates is a file')

# ---- W-11: a standing gate whose id differs in case -------------------------------------------------------------------------
$r = New-Fx -Tag 'w11'
Write-FxGoal -Root $r -GoalId 'G-W11' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w11-r1 minted'
Write-FxGate -Root $r -Kind 'dispatch' -Id 'w11-r1' -IdField 'W11-R1'
Report -Id 'W-11' -Title 'a gate stands at the leaf but its id: differs in case: refused, since no mint can stand there' -Rows (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W11' -Hook) -What 'id: W11-R1 under the head w11-r1')

# ---- W-12: a gate not UTF-8, or with two id: keys -----------------------------------------------------------------------------
$rows = @()
$r = New-Fx -Tag 'w12'
Write-FxGoal -Root $r -GoalId 'G-W12' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w12-r1 minted'
$gp = Get-FxGatePath -Root $r -Kind 'dispatch' -Id 'w12-r1'
New-Item -ItemType Directory -Path (Split-Path -Parent $gp) -Force | Out-Null
[System.IO.File]::WriteAllBytes($gp, [byte[]](0x6B, 0x69, 0x6E, 0x64, 0x3A, 0x20, 0xFF, 0xFE, 0x0A))
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W12' -Hook) -What 'a gate whose bytes are not UTF-8')
$r = New-Fx -Tag 'w12d'
Write-FxGoal -Root $r -GoalId 'G-W12' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w12-r2 minted'
Write-FxGate -Root $r -Kind 'dispatch' -Id 'w12-r2' -ExtraId
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W12' -Hook) -What 'a gate with two id: keys')
Report -Id 'W-12' -Title 'a gate the arm cannot read as one kind, one id and one sha refuses the head' -Rows $rows

# ---- W-13: a record that cannot be read --------------------------------------------------------------------------------------
$r = New-Fx -Tag 'w13'
Write-FxGoal -Root $r -GoalId 'G-W13' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w13-r1 minted'
New-Item -ItemType Directory -Path (Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl') -Force | Out-Null
Report -Id 'W-13' -Title 'a record that cannot be read refuses every head: a prior release cannot be ruled out' -Rows (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W13' -Hook) -What 'the record is a folder')

# ---- W-14: the ladder against the dispatch-manifest arm ------------------------------------------------------------------------
$r = New-Fx -Tag 'w14'
Write-FxGoal -Root $r -GoalId 'G-W14' -Wait -Manifest
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate supersession w14-s1 minted'
Write-Fx -Path (Join-Path $r '.mission\dispatches\D-W14.manifest.yaml') -Text "id: w14-r1`nkind: validator-manifest`n"
$h = Invoke-FxEval -Root $r -GoalId 'G-W14' -Hook
Report -Id 'W-14' -Title 'the ladder: AWAITING_DISPATCH_GATE outranks the wait, and the wait is still named' -Rows @(
    (G ($h.admitted -and ($h.verdict -ceq 'AWAITING_DISPATCH_GATE')) ('hook: approve, exit 0, AWAITING_DISPATCH_GATE -- ' + (Format-Fx $h 'hook'))),
    (F (Test-FxNames $h.wait 'w14-s1') 'the wait list names w14-s1 beside it'))

# ---- W-15: D9, one unreleased wait at a time ---------------------------------------------------------------------------------
$r = New-Fx -Tag 'w15'
Write-FxGoal -Root $r -GoalId 'G-W15' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w15-r1 minted'
$h1 = Invoke-FxEval -Root $r -GoalId 'G-W15' -Hook
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w15-r2 minted'
$h2 = Invoke-FxEval -Root $r -GoalId 'G-W15' -Hook
Report -Id 'W-15' -Title 'D9 (b): a second triple while the first is admitted and unreleased is refused, naming the first' -Rows @(
    (F ($h1.admitted -and ($h1.verdict -ceq $verdictWord)) ('the first wait is admitted -- ' + (Format-Fx $h1 'hook'))),
    (G ((-not $h2.admitted) -and ($h2.verdict -ceq 'NOT_MET')) ('the second -- not admitted -- ' + (Format-Fx $h2 'hook'))),
    (F (Test-FxNames $h2.refused 'w15-r1') 'the refusal names w15-r1'),
    (F ($h2.reason.IndexOf('w15-r1', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 'the hook''s block reason names w15-r1'))

# ==== THE ROWS VALIDATOR ROUND 1 OF THE BUILD ADDED ===============================================================
# Those that cure a finding read RED at 76769023, the first build: W-4's two ids outside ASCII, W-20, W-22 and W-24
# (W-24, ruling (v)'s deadline, is retired by Amendment 2).
# W-19, W-21 and W-23 give a row to what the record already said and the first build already did.
# ---- W-19: an admission the record cannot take ----------------------------------------------------------------
$r = New-Fx -Tag 'w19'
Write-FxGoal -Root $r -GoalId 'G-W19' -Wait -Met
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w19-r1 minted'
$w19Rec = Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl'
Write-Fx -Path $w19Rec -Text ''
[System.IO.File]::SetAttributes($w19Rec, [System.IO.FileAttributes]::ReadOnly)
$h = Invoke-FxEval -Root $r -GoalId 'G-W19' -Hook
$hd = Invoke-FxEval -Root $r -GoalId 'G-W19'
[System.IO.File]::SetAttributes($w19Rec, [System.IO.FileAttributes]::Normal)
Report -Id 'W-19' -Title 'D3 as amended: an admission the record cannot take admits nothing -- the hook blocks NOT_MET, the wait named; a hand run records nothing and reads the wait' -Rows @(
    (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('hook over a read-only record -- not admitted, NOT_MET -- ' + (Format-Fx $h 'hook'))),
    (F (Test-FxNames $h.wait 'w19-r1') 'the hook''s wait list names w19-r1 and the admission it could not record'),
    (F (($hd.exit -eq 7) -and ($hd.verdict -ceq $verdictWord)) ('hand: exit 7, ' + $verdictWord + ' -- ' + (Format-Fx $hd 'hand'))))

# ---- W-20: an admitted settled wait that can never be met is VOID, and frees the one-wait slot ---------------------
$rows = @()
$r = New-Fx -Tag 'w20'
Write-FxGoal -Root $r -GoalId 'G-W20' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate push w20-p1 settled'
$h1 = Invoke-FxEval -Root $r -GoalId 'G-W20' -Hook
Write-FxGate -Root $r -Kind 'push' -Id 'w20-p1' -ConsumedAt '2026-11-01T01:00:00.000Z' -Basis 'pre-push in-flight witness for this ref + the DECLARED origin observed holding the authorized sha, having ADVANCED from ''(none)'' (amendment 20)'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w20-r2 minted'
$h2 = Invoke-FxEval -Root $r -GoalId 'G-W20' -Hook
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate push w20-p1 settled'
Remove-Item -LiteralPath (Get-FxGatePath -Root $r -Kind 'push' -Id 'w20-p1') -Force
$h3 = Invoke-FxEval -Root $r -GoalId 'G-W20' -Hook
$rows += (F ($h1.admitted -and ($h1.verdict -ceq $verdictWord)) ('the push wait admitted on an absent gate -- ' + (Format-Fx $h1 'hook')))
$rows += (F ($h2.admitted -and ($h2.verdict -ceq $verdictWord) -and (Test-FxNames $h2.wait 'w20-r2')) ('its gate then consumed by the seat''s own push: the next wait is admitted, the first voided -- ' + (Format-Fx $h2 'hook')))
$rows += (F (Test-FxNames $h2.refused 'w20-p1') 'the void of w20-p1 is named')
$rows += (G ((-not $h3.admitted) -and ($h3.verdict -ceq 'NOT_MET')) ('the voided triple written again, its gate gone -- not admitted -- ' + (Format-Fx $h3 'hook')))
Report -Id 'W-20' -Title 'R2 of round 1: an admitted settled wait that no operator act can release any more is recorded VOID; it frees the one-wait slot and never admits again' -Rows $rows

# ---- W-21: the one-wait slot is freed by the earlier triple's release, read under another head ----------------------
$r = New-Fx -Tag 'w21'
Write-FxGoal -Root $r -GoalId 'G-W21' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w21-r1 minted'
$null = Invoke-FxEval -Root $r -GoalId 'G-W21' -Hook
Write-FxGate -Root $r -Kind 'dispatch' -Id 'w21-r1'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w21-r2 minted'
$h = Invoke-FxEval -Root $r -GoalId 'G-W21' -Hook
Report -Id 'W-21' -Title 'D9: once the earlier admitted triple reads met under a later head, it is released and the later wait is admitted' -Rows @(
    (F ($h.admitted -and ($h.verdict -ceq $verdictWord) -and (Test-FxNames $h.released 'w21-r1') -and (Test-FxNames $h.wait 'w21-r2')) ('w21-r1 released, w21-r2 admitted -- ' + (Format-Fx $h 'hook'))))

# ---- W-22: a push gate carrying part of a consume block -------------------------------------------------------------
$r = New-Fx -Tag 'w22'
Write-FxGoal -Root $r -GoalId 'G-W22' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate push w22-p1 settled'
Write-FxGate -Root $r -Kind 'push' -Id 'w22-p1'
Add-Content -LiteralPath (Get-FxGatePath -Root $r -Kind 'push' -Id 'w22-p1') -Value 'consumed_ref: refs/heads/main' -Encoding UTF8
Report -Id 'W-22' -Title 'D2 of round 1: a push gate carrying part of a consume block, which the console settle refuses (first stamp wins), refuses the wait' -Rows (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W22' -Hook) -What 'consumed_at null under a consumed_ref line')

# ---- W-23: what the record names that had no row -------------------------------------------------------------------
$rows = @()
$r = New-Fx -Tag 'w23a'
Write-Fx -Path (Join-Path $r '.mission\goals\G-W23.yaml') -Text "id: G-W23`ndetectors:`n  - type: operator_wait_present`n  - type: operator_wait_present`n  - type: file_exists`n    path: evidence/absent.txt`n"
New-Item -ItemType Directory -Path (Join-Path $r '.mission-runtime\lam') -Force | Out-Null
[System.IO.File]::WriteAllBytes((Join-Path $r '.mission-runtime\lam\STATUS.md'), ([byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::ASCII.GetBytes("OPERATOR WAIT gate supersession w23-s1 minted  `r`n`r`nbody`r`n")))
$h = Invoke-FxEval -Root $r -GoalId 'G-W23' -Hook
$rows += (F ($h.admitted -and ($h.verdict -ceq $verdictWord) -and (@($h.wait).Count -eq 1) -and (Test-FxNames $h.wait 'w23-s1')) ('a BOM, CR LF and trailing blanks, the arm declared twice: one wait admitted -- ' + (Format-Fx $h 'hook')))
$r = New-Fx -Tag 'w23b'
Write-FxGoal -Root $r -GoalId 'G-W23' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w23-r2 minted'
Write-Fx -Path (Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl') -Text "not a record, but it names w23-r2`n"
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W23' -Hook) -What 'a record line that does not parse and spells the id')
$r = New-Fx -Tag 'w23c'
Write-FxGoal -Root $r -GoalId 'G-W23' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w23-r3 minted'
Write-FxGate -Root $r -Kind 'dispatch' -Id 'w23-r3'
$w23Leaf = Get-FxGatePath -Root $r -Kind 'dispatch' -Id 'w23-r3'
[System.IO.File]::Move($w23Leaf, ($w23Leaf + '.tmp'))
[System.IO.File]::Move(($w23Leaf + '.tmp'), (Join-Path (Split-Path -Parent $w23Leaf) 'Dispatch-W23-r3.yaml'))
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W23' -Hook) -What 'the leaf spelt in another case')
$r = New-Fx -Tag 'w23d'
Write-FxGoal -Root $r -GoalId 'G-W23' -Wait
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w23-r4 minted'
$w23Target = Join-Path (Split-Path -Parent $r) 'elsewhere'
New-Item -ItemType Directory -Path $w23Target -Force | Out-Null
New-Item -ItemType Junction -Path (Join-Path (Join-Path $r '.mission') 'gates') -Target $w23Target | Out-Null
$rows += (Get-RefusedRows -R (Invoke-FxEval -Root $r -GoalId 'G-W23' -Hook) -What 'a gates folder that is a junction')
Report -Id 'W-23' -Title 'the head as the handoff arm reads it; the arm declared twice; a loose record line; a leaf in another case; a junction' -Rows $rows

# ==== AMENDMENT 2's ROWS (ruling (y): ruling (v) withdrawn, D8 is option (a)) =====================================
# RED on the tree that built ruling (v), 38311c10; GREEN after its removal. W-4 carries the two settled heads with no gate
# (those two hold on 38311c10 too, which refused a settle wait on an absent gate).
# ---- W-25: D8 (a) -- settled on amendment-material and reclose is refused BY THE GRAMMAR --------------------------
# The fixtures are those in which ruling (v) admitted (the console's settle would succeed now) or released (the
# console's stamp stands). "By the grammar" is read without a word of the form: each refusal, its own kind and id put
# back as <kind> <id>, is the very refusal the arm gives `settled` on dispatch over a gate of the same shape -- the
# grammar's own.
function Get-FxRefusalShape {
    param([object[]]$Refused, [string]$Kind, [string]$Id)
    $one = @(@($Refused) | Where-Object { ([string]$_).IndexOf($Id, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object -First 1)
    if ($one.Count -eq 0) { return ('(no refusal names ' + $Id + ')') }
    return ([string]$one[0]).Replace(($Kind + ' ' + $Id), '<kind> <id>')
}
$rows = @()
$amendText = "an amendment body`n"
$r = New-Fx -Tag 'w25d'
Write-FxGoal -Root $r -GoalId 'G-W25' -Wait
Write-FxGate -Root $r -Kind 'dispatch' -Id 'w25-r4'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w25-r4 settled'
$h = Invoke-FxEval -Root $r -GoalId 'G-W25' -Hook
$w25Grammar = Get-FxRefusalShape -Refused $h.refused -Kind 'dispatch' -Id 'w25-r4'
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET') -and (Test-FxNames $h.refused 'w25-r4')) ('CONTROL settled on dispatch, its gate open: refused by the grammar, the refusal names w25-r4 -- ' + (Format-Fx $h 'hook')))
$r = New-FxRepo -Tag 'w25a'
Write-FxGoal -Root $r -GoalId 'G-W25' -Wait
Write-Fx -Path (Join-Path $r 'inputs\amend.txt') -Text $amendText
$amendSha = Get-FxSha -Path (Join-Path $r 'inputs\amend.txt')
Invoke-FxGit -Root $r -GitArgs @('add', '--', 'inputs/amend.txt')
Invoke-FxGit -Root $r -GitArgs @('commit', '-q', '-m', 'the seat commits the amendment')
Write-FxGate -Root $r -Kind 'amendment-material' -Id 'w25-a1' -BindsRel 'inputs/amend.txt' -Sha $amendSha
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate amendment-material w25-a1 settled'
$h = Invoke-FxEval -Root $r -GoalId 'G-W25' -Hook
$rows += (F ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('amendment-material, the bound file committed at the gate''s bytes (the console''s settle would succeed) -- not admitted, NOT_MET -- ' + (Format-Fx $h 'hook')))
$w25Shape = Get-FxRefusalShape -Refused $h.refused -Kind 'amendment-material' -Id 'w25-a1'
$rows += (F ($w25Shape -ceq $w25Grammar) ('amendment-material: refused with the grammar''s own refusal -- ' + $(if ($w25Shape -ceq $w25Grammar) { 'the same' } else { 'it reads: ' + $w25Shape })))
$r = New-FxRepo -Tag 'w25b'
Write-FxGoal -Root $r -GoalId 'G-W25' -Wait
Write-Fx -Path (Join-Path $r '.mission\mission.yaml') -Text "id: fx-mission`nstate: Complete`n"
Write-Fx -Path (Join-Path $r '.mission\ledger\entries.jsonl') -Text ('{"id":"L-9","text":"re-closure"}' + "`n")
Invoke-FxGit -Root $r -GitArgs @('add', '--', '.mission/mission.yaml', '.mission/ledger/entries.jsonl')
Invoke-FxGit -Root $r -GitArgs @('commit', '-q', '-m', 'reclose: Reworking -> Complete (ADR-029) -- RE-CLOSURE #w25-c1')
Write-FxGate -Root $r -Kind 'reclose' -Id 'w25-c1' -BindsRel '.mission/ledger/entries.jsonl'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate reclose w25-c1 settled'
$h = Invoke-FxEval -Root $r -GoalId 'G-W25' -Hook
$rows += (F ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('reclose, the re-closure commit made (the console''s settle would succeed) -- not admitted, NOT_MET -- ' + (Format-Fx $h 'hook')))
$w25Shape = Get-FxRefusalShape -Refused $h.refused -Kind 'reclose' -Id 'w25-c1'
$rows += (F ($w25Shape -ceq $w25Grammar) ('reclose: refused with the grammar''s own refusal -- ' + $(if ($w25Shape -ceq $w25Grammar) { 'the same' } else { 'it reads: ' + $w25Shape })))
$r = New-Fx -Tag 'w25c'
Write-FxGoal -Root $r -GoalId 'G-W25' -Wait
Write-FxGate -Root $r -Kind 'amendment-material' -Id 'w25-a3' -BindsRel 'inputs/amend.txt' -Sha $amendSha -ConsumedAt '2026-11-01T00:50:00.000Z' -Basis 'record of use by console -- the newest commit on HEAD holding the bound file at binds_sha256'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate amendment-material w25-a3 settled'
$h = Invoke-FxEval -Root $r -GoalId 'G-W25' -Hook
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET')) ('amendment-material, the console''s settle stamp standing -- not admitted, NOT_MET -- ' + (Format-Fx $h 'hook')))
$rows += (F (-not (Test-FxNames $h.released 'w25-a3')) ('the console''s stamp releases nothing: the released list does not name w25-a3 (' + @($h.released).Count + ' item(s))'))
$w25Shape = Get-FxRefusalShape -Refused $h.refused -Kind 'amendment-material' -Id 'w25-a3'
$rows += (F ($w25Shape -ceq $w25Grammar) ('stamped: refused with the grammar''s own refusal -- ' + $(if ($w25Shape -ceq $w25Grammar) { 'the same' } else { 'it reads: ' + $w25Shape })))
# BEFORE ANY GATE OR RECORD IS READ (Amendment 2's validator round 1, R1 and D2): states and record lines that a refusal
# made after reading the gate or the record would answer otherwise -- NOT ESTABLISHED, revoked, a consume block, RELEASED
# BEFORE, VOID. Only the grammar's refusal, made first, gives the same refusal for each.
$w25Rec = { param([string]$Ev, [string]$K, [string]$I) ('{"event":"' + $Ev + '","at":"2026-11-01T00:00:00.000Z","goal":"G-W25","kind":"' + $K + '","id":"' + $I + '","state":"settled","head":"","read":""}' + "`n") }
$w25States = @(
    @{ k = 'amendment-material'; i = 'w25-e1'; what = 'gates NOT ESTABLISHED (a file in its place)'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path (Join-Path $R '.mission') 'gates') -Text "not a folder`n" } },
    @{ k = 'reclose'; i = 'w25-e2'; what = 'gates NOT ESTABLISHED (a file in its place)'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path (Join-Path $R '.mission') 'gates') -Text "not a folder`n" } },
    @{ k = 'amendment-material'; i = 'w25-e3'; what = 'the gate revoked'; set = { param($R, $K, $I) Write-FxGate -Root $R -Kind $K -Id $I -RevokedAt '2026-11-01T00:55:00.000Z' } },
    @{ k = 'amendment-material'; i = 'w25-e4'; what = 'the gate carrying part of a consume block'; set = { param($R, $K, $I) Write-FxGate -Root $R -Kind $K -Id $I; Add-Content -LiteralPath (Get-FxGatePath -Root $R -Kind $K -Id $I) -Value 'consumed_ref: refs/heads/main' -Encoding UTF8 } },
    @{ k = 'amendment-material'; i = 'w25-e5'; what = 'a released line of the triple in the record'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Text (& $w25Rec 'operator_wait_released' $K $I) } },
    @{ k = 'reclose'; i = 'w25-e6'; what = 'a released line of the triple in the record'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Text (& $w25Rec 'operator_wait_released' $K $I) } },
    @{ k = 'amendment-material'; i = 'w25-e7'; what = 'a voided line of the triple in the record'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Text (& $w25Rec 'operator_wait_voided' $K $I) } },
    @{ k = 'amendment-material'; i = 'w25-e8'; what = 'an admitted line of the triple in the record, its gate absent'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Text (& $w25Rec 'operator_wait_admitted' $K $I) } },
    # Ruling (z), D-B(i): the record's own checks -- one that cannot be read, a loose line spelling the id. Read first on
    # 4e9051e2: each is refused with the grammar's reason, which runs before the record's readability and loose lines.
    @{ k = 'amendment-material'; i = 'w25-e9'; what = 'the record unreadable (a folder in its place)'; set = { param($R, $K, $I) New-Item -ItemType Directory -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Force | Out-Null } },
    @{ k = 'reclose'; i = 'w25-e10'; what = 'the record unreadable (a folder in its place)'; set = { param($R, $K, $I) New-Item -ItemType Directory -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Force | Out-Null } },
    @{ k = 'amendment-material'; i = 'w25-e11'; what = 'a loose record line spelling the id'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Text ('not a record, but it names ' + $I + "`n") } },
    @{ k = 'reclose'; i = 'w25-e12'; what = 'a loose record line spelling the id'; set = { param($R, $K, $I) Write-Fx -Path (Join-Path $R '.mission-runtime\lam\operator-wait-releases.jsonl') -Text ('not a record, but it names ' + $I + "`n") } })
foreach ($st in $w25States) {
    $r = New-Fx -Tag 'w25e'
    Write-FxGoal -Root $r -GoalId 'G-W25' -Wait
    & $st.set $r $st.k $st.i
    Write-FxHead -Root $r -Head ('OPERATOR WAIT gate ' + $st.k + ' ' + $st.i + ' settled')
    $h = Invoke-FxEval -Root $r -GoalId 'G-W25' -Hook
    $w25Shape = Get-FxRefusalShape -Refused $h.refused -Kind $st.k -Id $st.i
    $rows += (F ((-not $h.admitted) -and ($w25Shape -ceq $w25Grammar)) ($st.k + ', ' + $st.what + ': refused with the grammar''s own refusal -- ' + $(if ($w25Shape -ceq $w25Grammar) { 'the same' } else { 'it reads: ' + $w25Shape })))
}
Report -Id 'W-25' -Title 'D8 (a), ruling (y): settled on amendment-material and reclose is refused by the grammar, where the console''s settle would succeed and where its stamp stands' -Rows $rows

# ---- W-26: every head form starts no process and creates no file outside the mission root --------------------------
# Amendment 2, item 2. This script enters a job object of its own: every process created as its descendant from here on
# is in it, and the job's TotalProcesses counts each one ever started there, however short its life. A process started
# through WMI, the task scheduler or COM is not a descendant and is not counted; those routes are ruled out by reading
# the functions the arm reaches (the record's N2, corrected under ruling (z)). A file watcher on the member's
# folder sees every file and folder made in it. Each evaluation runs with TEMP and TMP pointed at the member's tmp
# folder, beside the mission roots. A row holds when the evaluation started ONE process -- the evaluator's own
# powershell -- and made nothing outside its mission root but the host's own `__PSScriptPolicyTest_*` probe files,
# which powershell.exe makes at start-up whatever it runs (the CONTROL runs a bare powershell under the same harness).
$rows = @()
$w26Src = @(
    'using System; using System.Runtime.InteropServices;',
    'public static class FxOpWaitJob {',
    '  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObjectW(IntPtr a, string n);',
    '  [DllImport("kernel32.dll", SetLastError = true)] static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);',
    '  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();',
    '  [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryInformationJobObject(IntPtr j, int c, byte[] info, int len, IntPtr ret);',
    '  static IntPtr job = IntPtr.Zero;',
    '  public static string Enter() { if (job != IntPtr.Zero) { return ""; } IntPtr j = CreateJobObjectW(IntPtr.Zero, null); if (j == IntPtr.Zero) { return "CreateJobObject failed, " + Marshal.GetLastWin32Error(); } if (!AssignProcessToJobObject(j, GetCurrentProcess())) { return "AssignProcessToJobObject failed, " + Marshal.GetLastWin32Error(); } job = j; return ""; }',
    '  public static int Total() { byte[] b = new byte[48]; if ((job == IntPtr.Zero) || !QueryInformationJobObject(job, 1, b, 48, IntPtr.Zero)) { return -1; } return BitConverter.ToInt32(b, 36); }',
    '}') -join "`n"
if (-not ('FxOpWaitJob' -as [type])) { Add-Type -TypeDefinition $w26Src }
$w26Entered = [FxOpWaitJob]::Enter()
$rows += (G ((-not $w26Entered) -and ([FxOpWaitJob]::Total() -ge 1)) ('this script runs in a job object of its own' + $(if ($w26Entered) { ' -- ' + $w26Entered } else { '' })))
$w26Dir = Join-Path $runDir 'w26'
$w26Tmp = Join-Path $w26Dir 'tmp'
New-Item -ItemType Directory -Path $w26Tmp -Force | Out-Null
# Each form: the head, the gate that stands for it (kind, id) or none, F for a form ruling (v) answered by calling the
# console, and -Hand for a hand run. A last form carries an admitted settled triple of amendment-material in the record.
$w26Forms = New-Object System.Collections.Generic.List[object]
$w26No = 0
foreach ($k in @('push', 'amendment-material', 'dispatch', 'supersession', 'completion-acceptance', 'reclose')) {
    $w26No++
    $w26Forms.Add([pscustomobject]@{ head = ('OPERATOR WAIT gate ' + $k + ' w26-m' + $w26No + ' minted'); kind = ''; id = ''; v = $false; hand = $false; rec = '' })
    $w26Forms.Add([pscustomobject]@{ head = ('OPERATOR WAIT gate ' + $k + ' w26-s' + $w26No + ' settled'); kind = $k; id = ('w26-s' + $w26No); v = (@('amendment-material', 'reclose') -contains $k); hand = $false; rec = '' })
}
foreach ($k in @('amendment-material', 'reclose')) {
    $w26Forms.Add([pscustomobject]@{ head = ('OPERATOR WAIT gate ' + $k + ' w26-h' + $k.Length + ' settled'); kind = $k; id = ('w26-h' + $k.Length); v = $true; hand = $true; rec = '' })
}
foreach ($hdText in @('OPERATOR WAIT gate halt-ruling HALT-W26 minted', 'OPERATOR WAIT gate witness-attested w26-w1 minted', 'OPERATOR WAIT',
                      'OPERATOR WAIT the operator recreates the container', 'the seat''s edition, no wait head')) {
    $w26Forms.Add([pscustomobject]@{ head = $hdText; kind = ''; id = ''; v = $false; hand = $false; rec = '' })
}
$w26Forms.Add([pscustomobject]@{ head = 'OPERATOR WAIT gate dispatch w26-r9 minted'; kind = 'amendment-material'; id = 'w26-a9'; v = $false; hand = $false
                                 rec = ('{"event":"operator_wait_admitted","at":"2026-11-01T00:00:00.000Z","goal":"G-W26","kind":"amendment-material","id":"w26-a9","state":"settled","head":"","read":""}' + "`n") })
$w26No = 0
foreach ($fm in $w26Forms) {
    $w26No++
    $fm | Add-Member -NotePropertyName root -NotePropertyValue (Join-Path (Join-Path $w26Dir ('h' + $w26No)) 'm')
    Write-Fx -Path (Join-Path $fm.root 'evidence\built.txt') -Text "built`n"
    Write-FxGoal -Root $fm.root -GoalId 'G-W26' -Wait
    Write-FxHead -Root $fm.root -Head $fm.head
    if ($fm.kind) { Write-FxGate -Root $fm.root -Kind $fm.kind -Id $fm.id }
    if ($fm.rec) { Write-Fx -Path (Join-Path $fm.root '.mission-runtime\lam\operator-wait-releases.jsonl') -Text $fm.rec }
}
$w26Watch = New-Object System.IO.FileSystemWatcher($w26Dir)
$w26Watch.IncludeSubdirectories = $true
$w26Watch.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName'
$null = Register-ObjectEvent -InputObject $w26Watch -EventName Created -SourceIdentifier 'fxw26c'
$null = Register-ObjectEvent -InputObject $w26Watch -EventName Renamed -SourceIdentifier 'fxw26r'
$w26Watch.EnableRaisingEvents = $true
function Invoke-FxW26 {
    # One run under the harness: processes the job counted, and every path made outside -Root that is not the host's probe.
    param([string]$Root, [scriptblock]$Run)
    $saveTemp = $env:TEMP; $saveTmp = $env:TMP
    $env:TEMP = $w26Tmp; $env:TMP = $w26Tmp
    try { $t0 = [FxOpWaitJob]::Total(); $res = & $Run; $t1 = [FxOpWaitJob]::Total() }
    finally { $env:TEMP = $saveTemp; $env:TMP = $saveTmp }
    Start-Sleep -Milliseconds 600
    $made = @(@(Get-Event | Where-Object { @('fxw26c', 'fxw26r') -contains $_.SourceIdentifier }) | ForEach-Object { [string]$_.SourceEventArgs.FullPath } | Sort-Object -Unique)
    @(Get-Event | Where-Object { @('fxw26c', 'fxw26r') -contains $_.SourceIdentifier }) | Remove-Event
    $foreign = @($made | Where-Object { (-not $_.StartsWith($Root + '\', [System.StringComparison]::OrdinalIgnoreCase)) -and
                                        ([System.IO.Path]::GetFileName($_) -notlike '__PSScriptPolicyTest_*') })
    return [pscustomobject]@{ procs = ($t1 - $t0); foreign = $foreign; res = $res }
}
function Format-FxW26 {
    param($W)
    $names = @($W.foreign | Select-Object -First 4 | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    return ([string]$W.procs + ' process(es) started, ' + @($W.foreign).Count + ' path(s) made outside the mission root' + $(if ($names.Count -gt 0) { ' (' + ($names -join ', ') + $(if (@($W.foreign).Count -gt 4) { ', ...' } else { '' }) + ')' } else { '' }))
}
$w26Ctl = Invoke-FxW26 -Root (Join-Path $w26Dir 'control') -Run { $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; try { $null = & powershell -NoProfile -NonInteractive -Command 'exit 0' 2>&1 } finally { $ErrorActionPreference = $prev } }
$rows += (G (($w26Ctl.procs -eq 1) -and (@($w26Ctl.foreign).Count -eq 0)) ('CONTROL a bare powershell under the same harness: ' + (Format-FxW26 $w26Ctl)))
foreach ($fm in $w26Forms) {
    $fmRoot = $fm.root
    $w = Invoke-FxW26 -Root $fmRoot -Run $(if ($fm.hand) { { Invoke-FxEval -Root $fmRoot -GoalId 'G-W26' } } else { { Invoke-FxEval -Root $fmRoot -GoalId 'G-W26' -Hook } })
    $said = $(if ($fm.hand) { 'hand' } else { 'hook' }) + ' "' + $fm.head + '"' + $(if ($fm.kind) { ', ' + $fm.kind + '-' + $fm.id + '.yaml standing' + $(if ($fm.rec) { ' and admitted settled in the record' } else { ' open' }) } else { '' }) + ': ' + (Format-FxW26 $w)
    $ok = ($w.procs -eq 1) -and (@($w.foreign).Count -eq 0) -and ($w.res.verdict -cne '(no verdict file)')
    $rows += $(if ($fm.v) { F $ok $said } else { G $ok $said })
}
$w26Watch.EnableRaisingEvents = $false
Unregister-Event -SourceIdentifier 'fxw26c'; Unregister-Event -SourceIdentifier 'fxw26r'
$w26Watch.Dispose()
Report -Id 'W-26' -Title 'Amendment 2: for every head form, as the hook and by hand, the evaluation starts no process but itself, compiles nothing and makes no file outside the mission root' -Rows $rows

# ---- W-27: D-4 -- an admitted settled triple of amendment-material or reclose already in the record ---------------------
# As the 38311c10 build could have written it. `settled` is push's alone, so such a triple is read by push's rule: its
# gate stamped by the console's record-of-use settle is consumed on another basis -- VOID, the slot freed; its gate open
# -- it holds the slot. Its FALSIFIER rows are RED on 63685de5, whose added refusal held it after the console's settle
# (Amendment 2's validator round 1, D1).
$rows = @()
foreach ($w27 in @(@{ k = 'amendment-material'; i = 'w27-a1'; n = 'w27-r1' }, @{ k = 'reclose'; i = 'w27-c1'; n = 'w27-r2' })) {
    $r = New-Fx -Tag 'w27'
    Write-FxGoal -Root $r -GoalId 'G-W27' -Wait
    Write-Fx -Path (Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl') -Text ('{"event":"operator_wait_admitted","at":"2026-11-01T00:00:00.000Z","goal":"G-W27","kind":"' + $w27.k + '","id":"' + $w27.i + '","state":"settled","head":"","read":""}' + "`n")
    Write-FxGate -Root $r -Kind $w27.k -Id $w27.i -ConsumedAt '2026-11-01T00:50:00.000Z' -Basis 'record of use by console -- the commit this gate binds'
    Write-FxHead -Root $r -Head ('OPERATOR WAIT gate dispatch ' + $w27.n + ' minted')
    $h = Invoke-FxEval -Root $r -GoalId 'G-W27' -Hook
    $w27Void = @(@($h.refused) | Where-Object { (([string]$_).IndexOf($w27.i, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) -and (([string]$_).IndexOf($w27.n, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) }).Count
    $rows += (F ($h.admitted -and ($h.verdict -ceq $verdictWord) -and (Test-FxNames $h.wait $w27.n)) ($w27.k + ' ' + $w27.i + ' settled admitted in the record, its gate stamped by the console: the slot is free, ' + $w27.n + ' admitted -- ' + (Format-Fx $h 'hook')))
    $rows += (F ($w27Void -ge 1) ('the earlier triple ' + $w27.i + ' is named apart from the new head (recorded void) -- ' + $w27Void + ' item(s)'))
}
$r = New-Fx -Tag 'w27'
Write-FxGoal -Root $r -GoalId 'G-W27' -Wait
Write-Fx -Path (Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl') -Text ('{"event":"operator_wait_admitted","at":"2026-11-01T00:00:00.000Z","goal":"G-W27","kind":"amendment-material","id":"w27-a3","state":"settled","head":"","read":""}' + "`n")
Write-FxGate -Root $r -Kind 'amendment-material' -Id 'w27-a3'
Write-FxHead -Root $r -Head 'OPERATOR WAIT gate dispatch w27-r3 minted'
$h = Invoke-FxEval -Root $r -GoalId 'G-W27' -Hook
$rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET') -and (Test-FxNames $h.refused 'w27-a3')) ('amendment-material w27-a3 settled admitted in the record, its gate open: it holds the slot, w27-r3 refused naming it -- ' + (Format-Fx $h 'hook')))
Report -Id 'W-27' -Title 'D-4: an admitted settled triple of amendment-material or reclose in the record is read by push''s rule -- void once its gate is consumed on any other basis, held while its gate is open' -Rows $rows

# ---- W-28: a revoked gate is not void (Amendment 1 item 2; ruling (z), D-C) -----------------------------------------
# The operator's reapprove mints a fresh gate at the same path, so an admitted settled triple whose gate is revoked
# holds the one-wait slot and is never recorded void: for push, and for a D-4 triple. GUARD rows: they hold on every
# tree that has the form; a mutant that counts revoked as void reads them RED.
$rows = @()
foreach ($w28 in @(@{ k = 'push'; i = 'w28-p1'; n = 'w28-r1' }, @{ k = 'amendment-material'; i = 'w28-a1'; n = 'w28-r2' })) {
    $r = New-Fx -Tag 'w28'
    Write-FxGoal -Root $r -GoalId 'G-W28' -Wait
    Write-Fx -Path (Join-Path $r '.mission-runtime\lam\operator-wait-releases.jsonl') -Text ('{"event":"operator_wait_admitted","at":"2026-11-01T00:00:00.000Z","goal":"G-W28","kind":"' + $w28.k + '","id":"' + $w28.i + '","state":"settled","head":"","read":""}' + "`n")
    Write-FxGate -Root $r -Kind $w28.k -Id $w28.i -RevokedAt '2026-11-01T00:25:00.000Z'
    Write-FxHead -Root $r -Head ('OPERATOR WAIT gate dispatch ' + $w28.n + ' minted')
    $h = Invoke-FxEval -Root $r -GoalId 'G-W28' -Hook
    $w28Held = @(@($h.refused) | Where-Object { (([string]$_).IndexOf($w28.i, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) -and (([string]$_).IndexOf($w28.n, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) }).Count
    $w28Void = @(@($h.refused) | Where-Object { (([string]$_).IndexOf($w28.i, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) -and (([string]$_).IndexOf($w28.n, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) }).Count
    $rows += (G ((-not $h.admitted) -and ($h.verdict -ceq 'NOT_MET') -and ($w28Held -ge 1)) ($w28.k + ' ' + $w28.i + ' settled admitted, its gate revoked: the slot is held, ' + $w28.n + ' refused naming it -- ' + (Format-Fx $h 'hook')))
    $rows += (G (($w28Void -eq 0) -and (-not (Test-FxNames $h.released $w28.i))) ($w28.k + ' ' + $w28.i + ': not recorded void and not released (' + $w28Void + ' item(s) name it apart from the head)'))
}
Report -Id 'W-28' -Title 'a revoked gate is not void: an admitted settled triple whose gate is revoked holds the one-wait slot, for push and for a D-4 triple' -Rows $rows
}
catch {
    $script:guardFail++
    Write-Output ('MEMBER ABORTED -- line ' + $_.InvocationInfo.ScriptLineNumber + ': ' + ($_.Exception.Message -replace '[\r\n]+', ' '))
}
finally {
    if (-not $Keep) { try { Remove-Item -LiteralPath $runDir -Recurse -Force -ErrorAction Stop } catch { Write-Output ('fixtures NOT removed: ' + $_.Exception.Message) } }
}
$total = $script:guardFail + $script:falsifierRed
Write-Output ''
Write-Output ('GUARD rows broken: ' + $script:guardFail + '   FALSIFIER rows RED: ' + $script:falsifierRed)
Write-Output ('EXIT: ' + $total + '   (on a tree without the form every GUARD row holds -- most of them only because the type is unknown, which is why each refused case carries a FALSIFIER row -- and every FALSIFIER row the build added is RED; on the tree that built ruling (v), 38311c10, Amendment 2''s FALSIFIER rows are RED; after the build both counts are 0)')
exit $total
