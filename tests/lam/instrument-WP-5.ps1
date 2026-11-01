#Requires -Version 5.1
<#
.SYNOPSIS
  LAM-ACCEPT WP-5 instrument -- configuration (K-1, K-2, K-3, K-4, K-5).
  THIS LINE HAS NOW GONE STALE ON THE SAME AXIS THREE TIMES. Round 8: the prose promised more than
  the body ran. Round 16: it promised less, naming K-1..K-3 while the body ran K-4. Round 18: it
  named K-1..K-4 while the body ran K-5 -- and it went stale IN THE COMMIT THAT ADDED K-5, three
  lines below this narration of the previous instance (V-1 round 18, WP-5 finding).
  A synopsis nobody executes goes stale in both directions, and writing about that does not stop it.
  WHOEVER ADDS K-6 EDITS THIS LINE IN THE SAME COMMIT. There is no detector for it: the K-5 member
  reads the section-1 tables, not this docblock, and a member that read its own file's prose would
  be asserting a comment against itself.

.DESCRIPTION
  THE EXIT CODE IS THE CONTRACT: 0 = every member passed, non-zero = the failure count.

  "Check: instrument parses each file and asserts the closed field sets above." CLOSED is the
  operative word and it is checked in BOTH directions, per design SS4.5 law 3 (the N10 pattern):
  every role the contract names must be present, AND no role may appear that the contract does not
  name. A one-directional check lets an unnamed role drift in and route work to a model nobody
  chose.

  This instrument is READ-ONLY. It parses artifacts; it starts nothing and spawns nothing.
#>
[CmdletBinding()]
param(
    # -SettingsDir exists so K-3 can be FALSIFIED against perturbed copies of the templates without
    # touching the real ones. A member that can only ever be run against the artifacts it is
    # supposed to judge cannot be shown to fail, and a member that cannot fail is not a measurement.
    [string]$SettingsDir
)

$ErrorActionPreference = 'Stop'

$repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$routing    = Join-Path $repoRoot 'model-routing.yaml'
$wtInclude  = Join-Path $repoRoot '.worktreeinclude'
if (-not $SettingsDir) { $SettingsDir = Join-Path $repoRoot 'tools\lam\settings' }
$settingsDir = $SettingsDir

$failures  = 0
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

Write-Host "=============================================================================="
Write-Host " LAM WP-5 INSTRUMENT -- configuration"
Write-Host "=============================================================================="
Write-Host "repo root : $repoRoot"

$required = [ordered]@{
    'model-routing.yaml'                     = $routing
    '.worktreeinclude'                       = $wtInclude
    'tools/lam/settings/orchestrator.json'   = (Join-Path $settingsDir 'orchestrator.json')
    'tools/lam/settings/worker.json'         = (Join-Path $settingsDir 'worker.json')
    'tools/lam/settings/validator.json'      = (Join-Path $settingsDir 'validator.json')
}
$missing = @()
$detail = ''
foreach ($k in $required.Keys) {
    $p = Test-Path -LiteralPath $required[$k]
    if (-not $p) { $missing += $k }
    $detail += "    [$(if ($p) { 'present' } else { 'ABSENT ' })] $k`n"
}
Check -Id 'F-0' -Title 'every configuration artifact is present' -Ok ($missing.Count -eq 0) -Detail $detail
if ($missing.Count -gt 0) {
    Write-Host ""; Write-Host " FIXTURE ABSENT -- behavioural members NOT run."; Write-Host "EXIT: $failures"; exit $failures
}

# =============================================================================================
# K-1 -- model routing
# =============================================================================================
$routingText = [System.IO.File]::ReadAllText($routing)

function Get-RoleBlock {
    param([string]$Text, [string]$Role)
    $model = $null; $live = $null; $inRole = $false
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s\s([A-Za-z0-9_-]+):\s*$') { $inRole = ($Matches[1] -eq $Role); continue }
        if ($line -match '^\S') { $inRole = $false; continue }
        if ($inRole) {
            if ($line -match '^\s{4}model:\s*(\S+)') { $model = $Matches[1] }
            if ($line -match '^\s{4}live:\s*(\S+)')  { $live  = $Matches[1] }
        }
    }
    return [pscustomobject]@{ model = $model; live = $live }
}

$expected = [ordered]@{
    'coding-strong' = 'claude-opus-5'
    'qa-validator'  = 'claude-opus-5'
    'coding-fast'   = 'claude-sonnet-5'
    'small-fast'    = 'claude-haiku-4-5-20251001'
}
$k1 = @{}
$detail = "  role -> model, as K-1 names them:`n"
foreach ($r in $expected.Keys) {
    $b = Get-RoleBlock -Text $routingText -Role $r
    $ok = ($b.model -eq $expected[$r]) -and ($b.live -eq 'true')
    $k1[$r] = $ok
    $detail += "    [$(if ($ok) { 'ok  ' } else { 'MISS' })] $r -> $($b.model) (live: $($b.live)); expected $($expected[$r])`n"
}

# CLOSED IN BOTH DIRECTIONS: no role may exist that K-1 does not name.
$declaredRoles = @()
$inRoles = $false
foreach ($line in ($routingText -split "`r?`n")) {
    if ($line -match '^roles:\s*$') { $inRoles = $true; continue }
    if ($inRoles -and ($line -match '^\S')) { $inRoles = $false; continue }
    if ($inRoles -and ($line -match '^\s\s([A-Za-z0-9_-]+):\s*$')) { $declaredRoles += $Matches[1] }
}
$extra = @($declaredRoles | Where-Object { $expected.Keys -notcontains $_ })
$detail += "  declared roles: $($declaredRoles -join ', ')`n"
$detail += "  undeclared extras: $(if ($extra.Count) { $extra -join ', ' } else { '(none)' })   (expect none -- the set is CLOSED)`n"

# Ollama retained but NOT live
$ollamaRetained = $routingText -match '(?m)^\s{2}ollama:'
$ollamaNotLive  = $routingText -match '(?ms)ollama:.*?live:\s*false'
$detail += "  ollama entries retained : $ollamaRetained   (expect True)`n"
$detail += "  ollama flagged live:false: $ollamaNotLive   (expect True)`n"

$k1ok = (-not ($k1.Values -contains $false)) -and ($extra.Count -eq 0) -and $ollamaRetained -and $ollamaNotLive
Check -Id 'K-1' -Title 'model-routing.yaml routes every named role and no others, with Ollama retained but not live' `
      -Ok $k1ok -Detail $detail

# =============================================================================================
# K-2 -- .worktreeinclude
# =============================================================================================
$wtText  = [System.IO.File]::ReadAllText($wtInclude)
$wtLines = @(($wtText -split "`r?`n") | Where-Object { $_.Trim() -and ($_.Trim() -notmatch '^#') })
# The contract's one hard exclusion: product .venv paths must not be dragged into a worktree.
$venvListed = @($wtLines | Where-Object { $_ -match '(^|/|\\)\.?venv' -and ($_ -notmatch '^\s*!') })
$hasEntries = $wtLines.Count -gt 0
$claudeIncluded = @($wtLines | Where-Object { $_ -match '\.claude' }).Count -gt 0
$detail = @"
  entries (non-comment) : $($wtLines.Count)   (expect > 0)
$(($wtLines | ForEach-Object { "    $_" }) -join "`n")
  product .venv paths INCLUDED : $($venvListed.Count)   (expect 0 -- K-2 excludes them)
  .claude present so the worker's hooks fire : $claudeIncluded   (expect True)
"@
Check -Id 'K-2' -Title '.worktreeinclude lists what a worker worktree needs and excludes product .venv paths' `
      -Ok ($hasEntries -and ($venvListed.Count -eq 0) -and $claudeIncluded) -Detail $detail

# =============================================================================================
# K-3 -- role settings templates
# =============================================================================================
# WHAT THIS MEMBER USED TO DO, AND WHY IT WAS WORTHLESS (V-1 round 1, WP-5 validator).
# K-3 names four properties. This member tested two of them, and tested one of those with a
# substring match:
#   * the validator branch accepted ANY deny rule starting `Write(` or `Edit(` -- which is exactly
#     the enumeration the comment one line above it said it must reject. `read-only` was therefore
#     satisfied by the very shape that made the file NOT read-only;
#   * `permissions.allow` was NEVER READ, so the worker's second .mission exception -- the one the
#     contract had to be amended for -- was invisible to it;
#   * memory-off was tested by searching the RAW TEXT for the word "memory", which the _memory_off
#     prose satisfies trivially.
# It carried a green tick through every run of this build until an outside reader opened the files.
# This rewrite reads the PARSED JSON, reads `deny` AND `allow`, and asserts CLOSED sets in both
# directions -- every member the contract names is present, and no member it does not name appears.
$permissiveModes = @('auto','acceptEdits','bypassPermissions')
$inertRuleForms  = @('Write(','MultiEdit(','NotebookEdit(')

$roleSpec = [ordered]@{
    'orchestrator' = [pscustomobject]@{
        modes          = @('auto')
        denyMustHave   = @('Edit(src/**)')
        closedAllow    = $null
        closedAllowWhat = ''
    }
    'worker' = [pscustomobject]@{
        modes          = @('auto')
        # `Edit(.mission/**)` IS DELIBERATELY NOT REQUIRED ANY MORE, and requiring
        # it was this member demanding the defect. Deny is evaluated before
        # allow and a deny rule cannot carry allowlist exceptions, so that entry SHADOWED both of
        # K-3's exceptions and the number that obtained was ZERO -- while this member reported PASS,
        # because it counted allow entries textually and never asked whether one had any effect.
        # The restriction now lives in the guard (T-5); the shadowing check below is what makes a
        # return of the defect fail HERE rather than in production.
        denyMustHave   = @('Edit(.mission/gates/**)')
        denyMustNotHave = @('Edit(.mission/**)')
        # EXACTLY TWO closed .mission exceptions, each named. Checked in
        # both directions -- a third would widen the worker's reach into the mission plane, and a
        # missing one breaks every dispatch.
        closedAllow    = @('Edit(.mission/evidence/session-*/**)','Edit(.mission/dispatches/*.handoff.yaml)')
        closedAllowWhat = 'allow entries touching .mission'
        allowFilter    = '\.mission'
    }
    'validator' = [pscustomobject]@{
        # DENY-BY-DEFAULT IS A MODE, NOT A DENY LIST. `dontAsk` auto-denies anything not named in
        # `allow`, so no forbidden path has to be foreseen. This is asserted as its own property
        # BELOW as well (`mode is not a permissive one`), because a member that only checked
        # membership of a list would go green again the moment the list gained `auto`.
        modes          = @('dontAsk')
        denyMustHave   = @()
        closedAllow    = @('Edit(tests/lam/validator-*.result.yaml)')
        closedAllowWhat = 'Edit allow entries'
        allowFilter    = '^Edit\('
    }
}

$k3 = @{}
$detail = ''
foreach ($role in $roleSpec.Keys) {
    $spec = $roleSpec[$role]
    $p = Join-Path $settingsDir "$role.json"
    $j = $null
    $parseErr = ''
    try { $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json } catch { $parseErr = $_.Exception.Message }

    # FAIL LOUD on an unreadable template. Reporting "no rules found" over a file that failed to
    # parse is the silent-inheritance shape the fail-loud rule exists to forbid, one layer over.
    $parsed = ($null -ne $j) -and ($null -ne $j.permissions)
    if (-not $parsed) {
        $k3[$role] = $false
        $detail += "  $role.json`n    [MISS] parses as JSON with a permissions block   $parseErr`n"
        continue
    }

    $denies = @()
    if ($null -ne $j.permissions.deny)  { $denies = @($j.permissions.deny  | ForEach-Object { "$_" }) }
    $allows = @()
    if ($null -ne $j.permissions.allow) { $allows = @($j.permissions.allow | ForEach-Object { "$_" }) }
    $mode = "$($j.permissions.defaultMode)"

    # (1) MODE -- the posture K-3 names for this role.
    $modeOk = ($spec.modes -contains $mode)
    # (1b) For the validator the posture is the point, so it gets its own named assertion.
    $notPermissive = $true
    if ($role -eq 'validator') { $notPermissive = ($permissiveModes -notcontains $mode) }

    # (2) push denied, in both shell spellings the templates use.
    $noPush = @($denies | Where-Object { $_ -match 'git push' }).Count -gt 0

    # (3) the role's named deny entries, matched as WHOLE RULES, not as substrings.
    $denyOk = $true
    $denyMissing = @()
    foreach ($needle in @($spec.denyMustHave)) {
        if ($denies -notcontains $needle) { $denyOk = $false; $denyMissing += $needle }
    }

    # (4) THE CLOSED ALLOW SET, BOTH DIRECTIONS. This is the half that was never read at all.
    $allowOk = $true
    $allowExtra = @()
    $allowMissing = @()
    $allowSeen = @()
    if ($null -ne $spec.closedAllow) {
        $allowSeen = @($allows | Where-Object { $_ -match $spec.allowFilter })
        foreach ($e in @($spec.closedAllow)) { if ($allowSeen -notcontains $e) { $allowMissing += $e } }
        foreach ($e in $allowSeen) { if (@($spec.closedAllow) -notcontains $e) { $allowExtra += $e } }
        $allowOk = ($allowMissing.Count -eq 0) -and ($allowExtra.Count -eq 0)
    }

    # (5) RULE FORM. CLI 2.1.241 consults `Edit(path)` and `Read(path)` only; a path rule written
    # for Write/MultiEdit/NotebookEdit is accepted, never consulted, and warned about at startup.
    # A rule that reads as a restriction and enforces nothing is worse than an absent one.
    $inert = @()
    foreach ($r in ($denies + $allows)) {
        foreach ($form in $inertRuleForms) { if ($r.StartsWith($form)) { $inert += $r } }
    }
    $formOk = ($inert.Count -eq 0)

    # (6) MEMORY HYGIENE as K-3 AS AMENDED names it -- three carried fields, not the word "memory".
    $mo = $j.'_memory_off'
    $memIntent   = ($null -ne $mo) -and ("$($mo.intent)".Trim().Length -gt 0)
    $memMech     = ($null -ne $mo) -and ("$($mo.declared_mechanism)".Trim().Length -gt 0)      # (i)
    $memSep      = ($null -ne $mo) -and ("$($mo.separation_obtained)".Trim().Length -gt 0)     # (ii)
    $memDisable  = ($null -ne $mo) -and ("$($mo.disable_status)" -match '2\.1\.241') -and
                                        ("$($mo.disable_status)" -match 'E12')                # (iii)
    # AND NO TEMPLATE MAY CARRY A REAL MEMORY SETTING. The underscore keys are documentation; a
    # non-underscore key claiming to disable memory would be the overclaim E12 forbids.
    $realMemKeys = @($j.PSObject.Properties.Name | Where-Object { $_ -notlike '_*' -and $_ -match 'memor' })
    $memOk = $memIntent -and $memMech -and $memSep -and $memDisable -and ($realMemKeys.Count -eq 0)

    # (7) the residual block travels with the artifact, and is not empty.
    $res = $j.'lam_residuals'
    $residual = ($null -ne $res) -and (@($res).Count -gt 0)

    # (8) NO DENY RULE MAY SHADOW AN ALLOW RULE. THIS IS THE ONE THAT WAS MISSING, and its absence
    # is why an outside reader found a defect this instrument had reported green all build.
    #
    # Claude Code evaluates deny, then ask, then allow; the FIRST match wins and specificity does
    # not change the order, so a broad deny silently voids every narrower allow beneath it. A
    # member that reads RULES cannot see that -- the rules are all present and correctly spelled.
    # This asks the only question that matters: does any deny rule match a path this allow rule
    # exists to permit? A path is instantiated FROM the allow glob and tested AGAINST the deny
    # glob, so the check evaluates effect rather than text.
    $shadowed = @()
    foreach ($a in $allows) {
        if ($a -notmatch '^(?<tool>\w+)\((?<pat>.+)\)$') { continue }
        $aTool = $Matches['tool']; $aPat = $Matches['pat']
        if ($aTool -notin @('Edit','Read','Write')) { continue }   # path rules only
        # A concrete path the allow rule admits. `**` first, or the `*` pass would eat half of it.
        $concrete = $aPat -replace '\*\*', 'zzSEGa/zzSEGb'
        $concrete = $concrete -replace '\*', 'zzTOK'
        foreach ($d in $denies) {
            if ($d -notmatch '^(?<tool>\w+)\((?<pat>.+)\)$') { continue }
            if ($Matches['tool'] -ne $aTool) { continue }
            $dPat = $Matches['pat']
            $rx = '^' + ([regex]::Escape($dPat) -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*') + '$'
            if ($concrete -match $rx) { $shadowed += "$d  shadows  $a   (via '$concrete')" }
        }
    }
    $noShadow = ($shadowed.Count -eq 0)

    # (9) rules the role must NOT carry, as whole rules.
    $denyForbidden = @()
    foreach ($needle in @($spec.denyMustNotHave)) {
        if ($denies -contains $needle) { $denyForbidden += $needle }
    }
    $denyNotOk = ($denyForbidden.Count -eq 0)

    $ok = $modeOk -and $notPermissive -and $noPush -and $denyOk -and $denyNotOk -and $allowOk -and $formOk -and $memOk -and $residual -and $noShadow
    $k3[$role] = $ok
    $detail += "  $role.json`n"
    $detail += "    [$(if ($modeOk) { 'ok  ' } else { 'MISS' })] defaultMode = '$mode'   (K-3 for this role: $($spec.modes -join '/'))`n"
    if ($role -eq 'validator') {
        $detail += "    [$(if ($notPermissive) { 'ok  ' } else { 'MISS' })] the mode is NOT a permissive one ($($permissiveModes -join ', ')) -- deny-by-default is the POSTURE, not a deny list`n"
    }
    $detail += "    [$(if ($noPush) { 'ok  ' } else { 'MISS' })] git push denied`n"
    $detail += "    [$(if ($denyOk) { 'ok  ' } else { 'MISS' })] named deny rules present$(if ($denyMissing.Count) { " -- MISSING: $($denyMissing -join ', ')" } else { '' })`n"
    if ($null -ne $spec.closedAllow) {
        $detail += "    [$(if ($allowOk) { 'ok  ' } else { 'MISS' })] CLOSED allow set ($($spec.closedAllowWhat)) -- expected exactly $(@($spec.closedAllow).Count): $($spec.closedAllow -join ', ')`n"
        $detail += "         observed: $(if ($allowSeen.Count) { $allowSeen -join ', ' } else { '(none)' })`n"
        if ($allowMissing.Count) { $detail += "         MISSING : $($allowMissing -join ', ')`n" }
        if ($allowExtra.Count)   { $detail += "         UNNAMED : $($allowExtra -join ', ')   (the set is CLOSED)`n" }
    }
    $detail += "    [$(if ($formOk) { 'ok  ' } else { 'MISS' })] every path rule uses Edit(...) -- no inert Write/MultiEdit/NotebookEdit forms$(if ($inert.Count) { ": $($inert -join ', ')" } else { '' })`n"
    $detail += "    [$(if ($memOk) { 'ok  ' } else { 'MISS' })] memory hygiene: declared_mechanism=$memMech separation_obtained=$memSep disable_status names 2.1.241+E12=$memDisable real-memory-setting-keys=$($realMemKeys.Count)`n"
    $detail += "    [$(if ($residual) { 'ok  ' } else { 'MISS' })] lam_residuals travels with the artifact ($(@($res).Count) entries)`n"
    $detail += "    [$(if ($denyNotOk) { 'ok  ' } else { 'MISS' })] carries no deny rule the contract forbids it$(if ($denyForbidden.Count) { " -- PRESENT: $($denyForbidden -join ', ')" } else { '' })`n"
    $detail += "    [$(if ($noShadow) { 'ok  ' } else { 'MISS' })] NO DENY RULE SHADOWS AN ALLOW RULE (deny is evaluated first; a shadowed allow obtains ZERO times)`n"
    foreach ($s in $shadowed) { $detail += "         SHADOWED: $s`n" }
}
Check -Id 'K-3' -Title 'each role template carries the CLOSED field sets K-3 names, read from parsed deny AND allow' `
      -Ok (-not ($k3.Values -contains $false)) -Detail $detail

# the runner must resolve a model class to one of these three templates, or --settings names a
# file that does not exist and the role's deny set silently never applies.
$runner = Join-Path $repoRoot 'tools\lam\mission-dispatch.ps1'
$runnerSrc = [System.IO.File]::ReadAllText($runner)
$mapsRoles = ($runnerSrc -match 'qa-validator') -and ($runnerSrc -match 'validator\b') -and ($runnerSrc -match 'worker')
Check -Id 'K-3b' -Title 'the runner maps a model class to one of the three role templates' -Ok $mapsRoles `
      -Detail "  the runner resolves --settings from a role-kind, not from the raw model class:`n  mapping present: $mapsRoles   (expect True -- otherwise --settings names a file that does not exist)"

# =============================================================================================
# K-3c -- worker.json's FACE says where the restriction is actually enforced
# =============================================================================================
# Dropping the blanket deny is correct and it is also DANGEROUS TO READ. A later reviewer opening
# worker.json sees a template with no `.mission/**` deny and reasonably concludes the mission plane
# is unprotected for this role. K-3 as amended therefore requires the file to say, on its own face,
# that the protection moved to the guard -- and this member holds it to that, because a residual
# nobody can read is the same hole one layer down (the rule this build applies to gate exclusions
# and to prompt-register exclusions, applied here).
$wjText = [System.IO.File]::ReadAllText((Join-Path $settingsDir 'worker.json'))
$wj = $wjText | ConvertFrom-Json
$faceKeys = @($wj.PSObject.Properties.Name | Where-Object { $_ -match 'guard_enforced' })
$faceText = if ($faceKeys.Count) { "$($wj.($faceKeys[0]))" } else { '' }
$namesGuard    = $faceText -match 'guard'
$namesWhy      = ($faceText -match 'deny before allow') -and ($faceText -match 'cannot carry allowlist exceptions')
$namesFunction = $faceText -match 'Test-EvidenceWorkerPlanePath'
$namesRuling   = ($faceText -match 'amendment 15') -or ($faceText -match 'HALT-20')
# and the evidence-session residual travels too: the exception is live HERE and denied by the
# sealed guard, which is stricter than K-3 promises and must not read as a promise.
$residualText = (@($wj.lam_residuals) | ForEach-Object { "$_" }) -join ' '
$namesSealed  = ($residualText -match 'sealed') -and ($residualText -match 'evidence')
$k3cOk = ($faceKeys.Count -eq 1) -and $namesGuard -and $namesWhy -and $namesFunction -and $namesRuling -and $namesSealed
$detail = @"
  worker.json carries no blanket .mission deny by design, so its FACE must say where the
  restriction went -- otherwise the next reader budgets for protection that is not there.
    [$(if ($faceKeys.Count -eq 1) { 'ok  ' } else { 'MISS' })] exactly one guard-enforced face key present ($($faceKeys.Count) found)
    [$(if ($namesGuard)    { 'ok  ' } else { 'MISS' })] it names the guard as the enforcing layer
    [$(if ($namesWhy)      { 'ok  ' } else { 'MISS' })] it states WHY the permission layer cannot express the rule (deny before allow; no allowlist exceptions)
    [$(if ($namesFunction) { 'ok  ' } else { 'MISS' })] it names the enforcing predicate, so a reader can go and check it
    [$(if ($namesRuling)   { 'ok  ' } else { 'MISS' })] it cites the amendment/ruling that moved it
    [$(if ($namesSealed)   { 'ok  ' } else { 'MISS' })] the residual records that exception 1 is additionally denied by the SEALED guard -- stricter than K-3 promises, and stated so it is not read as a promise
"@
Check -Id 'K-3c' -Title "worker.json's face states that mission-plane protection is guard-enforced, and why" `
      -Ok $k3cOk -Detail $detail

# =============================================================================================
# K-3d -- SUBJECT INTEGRITY, the validator role's enforcing control
# =============================================================================================
# K-3 no longer claims the validator is read-only at the shell layer, because it is not: bare
# `Bash`/`PowerShell` are allowed (a validator that cannot run commands cannot measure by
# execution), and redirection targets are checked against deny rules only. Closing that would leave
# a reader that can only read -- an instrument this build has three rounds of evidence against.
#
# SO THE CONTROL IS DETECTION, AND THIS MEMBER IS WHAT MAKES IT REAL. The orchestrator hashes every
# artifact a validator is given to judge before the spawn and re-hashes on return; any mismatch
# VOIDS the verdict, raises a HALT and spends the identity. A verdict rendered over a subject that
# moved under it is not a weaker verdict -- nobody can say which bytes it describes.
#
# FIVE DIRECTIONS, CONTROL FIRST. A tool that returned VIOLATED for everything would pass a
# one-directional check and make every validator result unusable.
$k3dRoot = Join-Path $env:TEMP "lam-wp5-si-$([guid]::NewGuid().ToString('N').Substring(0,8))"
$null = New-Item -ItemType Directory -Path (Join-Path $k3dRoot 'sub') -Force
[System.IO.File]::WriteAllText((Join-Path $k3dRoot 'a.txt'), "alpha`n")
[System.IO.File]::WriteAllText((Join-Path $k3dRoot 'sub\b.txt'), "beta`n")
$k3dSubjFile = Join-Path $k3dRoot 'subjects.txt'
[System.IO.File]::WriteAllLines($k3dSubjFile, @('a.txt', 'sub', 'missing.txt'))
$k3dBase = Join-Path $k3dRoot 'baseline.json'
$k3dTool = Join-Path $repoRoot 'tools\lam\lam-validator-subjects.ps1'

function Invoke-SI {
    param([string]$Mode, [string]$Baseline)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $k3dTool `
                 -Mode $Mode -RepoRoot $k3dRoot -SubjectsFile $k3dSubjFile -BaselineFile $Baseline 2>&1 | Out-String
        return [pscustomobject]@{ exit = $LASTEXITCODE; text = $o }
    } finally { $ErrorActionPreference = $prev }
}
$k3dRows = New-Object System.Collections.Generic.List[string]
$k3dOk = $true
function K3D {
    param([string]$Label, [int]$Got, [int]$Expect)
    $pass = ($Got -eq $Expect)
    if (-not $pass) { $script:k3dOk = $false }
    $script:k3dRows.Add(('      {0,-52} exit={1,-3} expect={2,-3} {3}' -f $Label, $Got, $Expect, $(if ($pass) { 'ok' } else { 'MISMATCH' })))
}
K3D 'capture the baseline' (Invoke-SI -Mode 'capture' -Baseline $k3dBase).exit 0
# CONTROL FIRST: an untouched subject set must verify clean, or every row below means nothing.
K3D 'CONTROL: nothing touched -> verdict stands' (Invoke-SI -Mode 'verify' -Baseline $k3dBase).exit 0
[System.IO.File]::WriteAllText((Join-Path $k3dRoot 'a.txt'), "alpha-MUTATED`n")
K3D 'a subject FILE is edited -> VOID' (Invoke-SI -Mode 'verify' -Baseline $k3dBase).exit 3
[System.IO.File]::WriteAllText((Join-Path $k3dRoot 'a.txt'), "alpha`n")
# MEMBERSHIP COUNTS, NOT ONLY BYTES: a file added to a directory subject changes what was judged.
[System.IO.File]::WriteAllText((Join-Path $k3dRoot 'sub\c.txt'), "gamma`n")
K3D 'a file APPEARS in a directory subject -> VOID' (Invoke-SI -Mode 'verify' -Baseline $k3dBase).exit 3
Remove-Item -LiteralPath (Join-Path $k3dRoot 'sub\c.txt') -Force
# ABSENT IS A STATE, NOT A SKIP.
[System.IO.File]::WriteAllText((Join-Path $k3dRoot 'missing.txt'), "appeared`n")
K3D 'an ABSENT subject appears -> VOID' (Invoke-SI -Mode 'verify' -Baseline $k3dBase).exit 3
Remove-Item -LiteralPath (Join-Path $k3dRoot 'missing.txt') -Force
# AN UNRUN CHECK IS NOT A PASSED CHECK.
K3D 'NO baseline -> VOID, never a silent pass' (Invoke-SI -Mode 'verify' -Baseline (Join-Path $k3dRoot 'nope.json')).exit 2
K3D 'restored -> verdict stands again' (Invoke-SI -Mode 'verify' -Baseline $k3dBase).exit 0
try { Remove-Item -LiteralPath $k3dRoot -Recurse -Force -ErrorAction Stop } catch { }

$detail = @"
    K-3's validator clause is enforced by DETECTION, not prevention: the shell layer's write surface
    is bounded by a deny enumeration (a grammar limitation, disclosed on the artifact's face), so
    what makes it tolerable is that a moved subject cannot go unnoticed or have its verdict counted.
$($k3dRows -join "`n")
    exit 0 = the verdict stands; 3 = a subject moved, VOID; 2 = integrity could not be asserted.
"@
Check -Id 'K-3d' -Title 'subject integrity voids a verdict whose subject moved, in every direction, and leaves an untouched one standing' `
      -Ok $k3dOk -Detail $detail

# =============================================================================================
# K-3e -- THE NAMED EXEMPLARS ARE REAL EXEMPLARS (V-1 round 4, WP-5, K-3.6)
# =============================================================================================
# K-3 requires the validator role's residual to travel on the artifact's own face "naming the
# exemplars that remain writable". The face named NONE, and its two adjacent sentences were worse
# than silence: it said redirection targets were checked against the Edit rules (they are checked
# against DENY ONLY, so the write surface is wider than the face claimed), and it concluded that
# nothing unnamed was reachable -- while a reader wrote two of the four paths it had just listed as
# a cured problem. A face that asserts a closure the configuration does not have is the defect this
# clause exists to prevent, stated by the file that was supposed to prevent it.
#
# WHAT MAKES THIS MEMBER MORE THAN A SPELL-CHECK: an exemplar is only an exemplar if it really is
# reachable, so every path the prose names is cross-checked against the PARSED rule lists. A path
# that appears in allow or deny is not writable-by-omission and naming it would be a second, softer
# overclaim -- so the prose and the permissions must agree, or this fails.
$vText = [System.IO.File]::ReadAllText((Join-Path $settingsDir 'validator.json'))
$vJson = $vText | ConvertFrom-Json
$k3eRows = New-Object System.Collections.Generic.List[string]
$k3eOk = $true
$vResiduals = @($vJson.lam_residuals)
$exRes = @($vResiduals | Where-Object { $_ -match 'EXEMPLARS THAT REMAIN WRITABLE' })
$k3eNamesRes = ($exRes.Count -eq 1)
if (-not $k3eNamesRes) { $k3eOk = $false }
[void]$k3eRows.Add(('      {0,-52} {1}   (expect exactly 1)' -f 'a residual naming the exemplars', $exRes.Count))
$exemplars = @()
if ($k3eNamesRes) {
    $exemplars = @([regex]::Matches($exRes[0], '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value } |
                   Where-Object { $_ -match '[\\/.]' })
}
$k3eEnough = ($exemplars.Count -ge 3)
if (-not $k3eEnough) { $k3eOk = $false }
[void]$k3eRows.Add(('      {0,-52} {1}   (expect at least 3)' -f 'paths it names', $exemplars.Count))
# Every allow/deny rule as a bare path pattern, so an exemplar can be tested against them.
$vRules = @(@($vJson.permissions.allow) + @($vJson.permissions.deny) |
            ForEach-Object { if ($_ -match '^[A-Za-z]+\((.+)\)$') { $Matches[1] } })
foreach ($ex in $exemplars) {
    # A `**` exemplar names a family; test the family's root, since that is what a rule would list.
    $probe = ($ex -replace '\*+$', '') -replace '/$', ''
    $covered = @($vRules | Where-Object {
        $rx = '^' + ([regex]::Escape($_) -replace '\\\*\\\*', '.*' -replace '(?<!\.\*)\\\*', '[^/]*') + '$'
        ($ex -match $rx) -or ($probe -match $rx) -or ($_ -like "$probe*")
    })
    $isReal = ($covered.Count -eq 0)
    if (-not $isReal) { $k3eOk = $false }
    [void]$k3eRows.Add(('      {0,-52} listed in a rule: {1,-6} {2}' -f $ex, (-not $isReal), $(if ($isReal) { 'genuinely reachable' } else { "NOT AN EXEMPLAR -- covered by: $($covered -join ', ')" })))
}
# And the sentence that was measured false must not come back. The face must say the DENY list is
# the whole shell boundary; if it goes back to claiming the allow list constrains redirection, the
# prose is once again narrower than the layer.
$k3eDenyOnly = @($vResiduals | Where-Object { $_ -match 'BOUNDED BY THE DENY LIST ALONE' }).Count -eq 1
if (-not $k3eDenyOnly) { $k3eOk = $false }
[void]$k3eRows.Add(('      {0,-52} {1}   (expect True)' -f 'the shell surface is stated as deny-bounded', $k3eDenyOnly))
$detail = @"
    validator.json's face, cross-checked against validator.json's own permission lists:
$($k3eRows -join "`n")
    An exemplar that turns out to be listed is not a disclosure, it is a second overclaim wearing
    the first one's apology.
"@
Check -Id 'K-3e' -Title "the validator face names exemplars that remain writable, and each one is genuinely unlisted in allow and deny" `
      -Ok $k3eOk -Detail $detail

# =============================================================================================
# K-4 -- THE INSTALL DOC'S CODE EXCERPTS TRACK THE CODE THEY QUOTE (V-1 round 4)
# =============================================================================================
# LAM-INSTALL is a MIRRORING procedure: an operator copies these blocks into a sealed library by
# hand. A stale excerpt is therefore not a documentation defect, it is a DEFECT-INSTALLING
# INSTRUCTION -- and it has happened twice on this page, each time printing a superseded form of a
# predicate whose newer form existed a directory away. Both were caught by a reader; nothing on
# disk could have caught either.
#
# So the fix for the second occurrence is not a third correct excerpt. It is this member: every
# function-shaped block on the page is located in its source by name and compared as CODE, so an
# edit to the source that leaves the page behind FAILS HERE, in the suite, before an operator
# mirrors it. That is the difference between correcting an instance and closing the class.
$k4Rows = New-Object System.Collections.Generic.List[string]
$k4Ok = $true
function Norm-Lines {
    param([string[]]$Lines)
    return @($Lines | ForEach-Object { ($_ -replace "`r", '').TrimEnd() })
}
$k4DocPath = Join-Path $repoRoot 'docs\framework\LAM-INSTALL.md'
$k4SrcPath = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1'
$k4SealPath = Join-Path $repoRoot 'tools\framework\hooks\lib\evidence-common.ps1'
$k4Doc  = Norm-Lines @([System.IO.File]::ReadAllText($k4DocPath)  -split "`n")
$k4Src  = Norm-Lines @([System.IO.File]::ReadAllText($k4SrcPath)  -split "`n")
$k4Seal = Norm-Lines @([System.IO.File]::ReadAllText($k4SealPath) -split "`n")
# Every ```powershell fence on the page, in order.
$k4Fences = New-Object System.Collections.Generic.List[object]
$inFence = $false; $cur = $null; $startLine = 0
for ($i = 0; $i -lt $k4Doc.Count; $i++) {
    $ln = $k4Doc[$i]
    if (-not $inFence) {
        if ($ln.Trim() -eq '```powershell') { $inFence = $true; $cur = New-Object System.Collections.Generic.List[string]; $startLine = $i + 2 }
    } elseif ($ln.Trim() -eq '```') {
        $inFence = $false
        [void]$k4Fences.Add([pscustomobject]@{ Line = $startLine; Body = @($cur) })
    } else { [void]$cur.Add($ln) }
}
# FUNCTION-SHAPED FENCES. Located in the source BY NAME, then compared for exactly as many lines as
# the page prints -- so a source function that GREW is caught too: the page's last line is its `}`,
# and the source's would no longer be.
$k4FnCount = 0
# A fence may print MORE THAN ONE function -- §5.2 prints two, and taking only the first would have
# left the second unchecked while this member reported a clean page.
$k4Blocks = New-Object System.Collections.Generic.List[object]
foreach ($f in $k4Fences) {
    $body = @($f.Body)
    $starts = @(0..([Math]::Max($body.Count - 1, 0)) | Where-Object { $body[$_] -match '^function\s+\S+' })
    for ($s = 0; $s -lt $starts.Count; $s++) {
        $from = $starts[$s]
        $to   = if ($s + 1 -lt $starts.Count) { $starts[$s + 1] - 1 } else { $body.Count - 1 }
        while ($to -gt $from -and $body[$to].Trim() -eq '') { $to-- }
        [void]$k4Blocks.Add([pscustomobject]@{ Line = $f.Line + $from; Body = @($body[$from..$to]) })
    }
}
# COMPARED AS CODE, NOT AS TEXT, using PowerShell's own tokeniser. The page abbreviates the
# source's commentary on purpose -- the library carries paragraphs of rationale an install step has
# no use for -- so a byte comparison would fail on every excerpt for a reason that is not a defect,
# and a member that fails for a non-defect gets suppressed rather than read. Comments and layout
# are dropped; every remaining token, type and content both, must agree.
function Code-Tokens {
    param([string]$Text)
    $errs = $null
    $toks = [System.Management.Automation.PSParser]::Tokenize($Text, [ref]$errs)
    return @($toks | Where-Object { $_.Type -ne 'Comment' -and $_.Type -ne 'NewLine' } |
             ForEach-Object { "$($_.Type):$($_.Content)" })
}
foreach ($f in $k4Blocks) {
    $body = @($f.Body)
    if ($body.Count -lt 1 -or $body[0] -notmatch '^function\s+([A-Za-z0-9\-_]+)') { continue }
    $k4FnCount++
    $fname = $Matches[1]
    $at = -1
    for ($i = 0; $i -lt $k4Src.Count; $i++) { if ($k4Src[$i] -match ('^function\s+' + [regex]::Escape($fname) + '\s*\{?\s*$')) { $at = $i; break } }
    if ($at -lt 0) {
        $k4Ok = $false
        [void]$k4Rows.Add(('      {0,-42} NOT FOUND in the next-gen library at all' -f $fname))
        continue
    }
    # The function runs to the first `}` in column 0 -- this library's universal shape, and brace
    # counting is not an option: Test-PathHit carries a `}` inside a character class in a string.
    $end = -1
    for ($i = $at + 1; $i -lt $k4Src.Count; $i++) { if ($k4Src[$i] -eq '}') { $end = $i; break } }
    if ($end -lt 0) {
        $k4Ok = $false
        [void]$k4Rows.Add(('      {0,-42} its definition in the source is unterminated' -f $fname))
        continue
    }
    $pageToks = @(Code-Tokens ($body -join "`n"))
    $srcToks  = @(Code-Tokens (($k4Src[$at..$end]) -join "`n"))
    $diff = -1
    for ($i = 0; $i -lt [Math]::Max($pageToks.Count, $srcToks.Count); $i++) {
        $a = if ($i -lt $pageToks.Count) { $pageToks[$i] } else { '<end of excerpt>' }
        $b = if ($i -lt $srcToks.Count)  { $srcToks[$i] }  else { '<end of function>' }
        if ($a -ne $b) { $diff = $i; break }
    }
    if ($diff -ge 0) {
        $k4Ok = $false
        [void]$k4Rows.Add(('      {0,-42} DIVERGED at token {1} of {2} (fence at doc line {3})' -f $fname, ($diff + 1), $srcToks.Count, $f.Line))
        [void]$k4Rows.Add(('          page  : {0}' -f $(if ($diff -lt $pageToks.Count) { $pageToks[$diff] } else { '<end of excerpt>' })))
        [void]$k4Rows.Add(('          source: {0}' -f $(if ($diff -lt $srcToks.Count)  { $srcToks[$diff] }  else { '<end of function>' })))
    } else {
        [void]$k4Rows.Add(('      {0,-42} agrees with its source, token for token ({1} tokens)' -f $fname, $srcToks.Count))
    }
}
# THE ARRAY EXCERPTS, WHICH THE FUNCTION-SHAPED CHECK WALKED PAST (V-1 round 5 self-audit).
# Section 5.1 also prints the SEALED library's protected/parent lists, and until now only the LINE
# CITATION above them was checked -- not whether the entries match. That is the one excerpt on the
# page naming the guard's entire defended surface, so a stale copy of it is the most consequential
# thing an operator could mirror. Curing the function-shaped case and calling the page covered is
# the same defect again, in the member written to close its class.
function Get-ArrayEntries {
    param([string[]]$Lines, [string]$Name)
    $at = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^\$script:' + [regex]::Escape($Name) + '\s*=\s*@\(')) { $at = $i; break }
    }
    if ($at -lt 0) { return $null }
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = $at + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\)') { break }
        foreach ($m in [regex]::Matches($Lines[$i], "'([^']+)'")) { [void]$out.Add($m.Groups[1].Value) }
    }
    return @($out)
}
$k4ArrayNames = @([regex]::Matches(($k4Fences | ForEach-Object { $_.Body -join "`n" }) -join "`n",
                                   '\$script:(\w+)\s*=\s*@\(') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$k4ArraysChecked = 0
foreach ($name in $k4ArrayNames) {
    $docEntries  = Get-ArrayEntries -Lines $k4Doc  -Name $name
    $sealEntries = Get-ArrayEntries -Lines $k4Seal -Name $name
    if ($null -eq $sealEntries) {
        $k4Ok = $false
        [void]$k4Rows.Add(('      {0,-42} NOT FOUND in the sealed library' -f $name))
        continue
    }
    $k4ArraysChecked++
    $missing = @($sealEntries | Where-Object { $docEntries -notcontains $_ })
    $extra   = @($docEntries  | Where-Object { $sealEntries -notcontains $_ })
    if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
        [void]$k4Rows.Add(('      {0,-42} matches the sealed library ({1} entries)' -f $name, $sealEntries.Count))
    } else {
        $k4Ok = $false
        if ($missing.Count) { [void]$k4Rows.Add(('      {0,-42} the page OMITS: {1}' -f $name, ($missing -join ', '))) }
        if ($extra.Count)   { [void]$k4Rows.Add(('      {0,-42} the page ADDS : {1}' -f $name, ($extra -join ', '))) }
    }
}
# Both lists, or the check has quietly narrowed to whichever one the page still happens to print.
if ($k4ArraysChecked -lt 2) {
    $k4Ok = $false
    [void]$k4Rows.Add(('      {0,-42} {1} checked, expect 2 (protected AND parent)' -f 'array excerpts on the page', $k4ArraysChecked))
} else {
    [void]$k4Rows.Add(('      {0,-42} {1} checked against the sealed library' -f 'array excerpts on the page', $k4ArraysChecked))
}

# The page must still CARRY excerpts. Deleting them would otherwise be a way to pass this member,
# which would make the check an incentive to remove the instructions it exists to protect.
$k4Enough = ($k4FnCount -ge 4)
if (-not $k4Enough) { $k4Ok = $false }
[void]$k4Rows.Add(('      {0,-42} {1} found, at least 4 required' -f 'function-shaped excerpts on the page', $k4FnCount))

# THE EXCERPT'S PROVENANCE LINE IS ITSELF MEASURED.
# An excerpt re-cut from the source is only re-cut ONCE; what makes it auditable afterwards is the
# line saying which file, which lines, and which file hash it came from. That line is a figure, and
# a figure nothing reads is the defect K-5 exists for, one section away. So it is parsed and
# the hash is re-measured here, ON THE BASIS THE LINE ITSELF DECLARES (LF-normalised bytes, the
# same basis as SS1's tables, stated on the page precisely so this is not a guess).
#
# It is NOT enough that the tokens agree: the token comparison proves the code is current, and says
# nothing about whether the provenance line still describes the file it names. A correct excerpt
# under a stale provenance line is an instruction to mirror from a file that has moved.
$k4DocText = ($k4Doc -join "`n")
$k4Prov = [regex]::Matches($k4DocText,
    '\*\*Cut from\*\*\s+`([^`]+)`\s+\*\*lines\s+(\d+)-(\d+)\*\*[\s\S]{0,240}?sha256 \(16\) is \*\*`([0-9a-fA-F]{16})`\*\* over (\d+) bytes')
if ($k4Prov.Count -lt 1) {
    $k4Ok = $false
    [void]$k4Rows.Add(('      {0,-42} NONE FOUND -- an excerpt with no provenance cannot be audited' -f 'provenance lines on the page'))
} else {
    foreach ($pv in $k4Prov) {
        $pvRel   = $pv.Groups[1].Value
        $pvLo    = [int]$pv.Groups[2].Value
        $pvHi    = [int]$pv.Groups[3].Value
        $pvSha   = $pv.Groups[4].Value.ToLowerInvariant()
        $pvBytes = [int]$pv.Groups[5].Value
        $pvPath  = Join-Path $repoRoot ($pvRel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $pvPath)) {
            $k4Ok = $false
            [void]$k4Rows.Add(('      {0,-42} names a file that is not there: {1}' -f 'provenance', $pvRel))
            continue
        }
        # LF-NORMALISED, IN-PROCESS, NO GIT. A native exe writing to stderr is fatal under this
        # file's EAP=Stop, so the measurement must not shell out; the page states the blob equality
        # as a measured corollary and gives both routes.
        $pvRaw = [System.IO.File]::ReadAllBytes($pvPath)
        $pvList = New-Object 'System.Collections.Generic.List[byte]'
        for ($pi = 0; $pi -lt $pvRaw.Length; $pi++) {
            if ($pvRaw[$pi] -eq 13 -and ($pi + 1) -lt $pvRaw.Length -and $pvRaw[$pi + 1] -eq 10) { continue }
            [void]$pvList.Add($pvRaw[$pi])
        }
        $pvArr = $pvList.ToArray()
        $pvRealBytes = $pvArr.Length
        $pvRealSha = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($pvArr)).Replace('-', '').ToLowerInvariant().Substring(0, 16)
        # AND THE CITED LINE RANGE MUST STILL HOLD A FUNCTION. A hash that matches while the line
        # numbers point at commentary sends an operator to the wrong place with full confidence.
        $pvLinesOk = ($pvLo -ge 1) -and ($pvHi -le $k4Src.Count) -and ($pvLo -lt $pvHi) -and
                     ($k4Src[$pvLo - 1] -match '^function\s+\S+') -and ($k4Src[$pvHi - 1] -eq '}')
        $pvOk = ($pvRealBytes -eq $pvBytes) -and ($pvRealSha -eq $pvSha) -and $pvLinesOk
        if (-not $pvOk) { $k4Ok = $false }
        [void]$k4Rows.Add(('      {0,-42} says {1} {2}; measured {3} {4}; lines {5}-{6} bracket a function: {7}  {8}' -f `
            'provenance', $pvBytes, $pvSha, $pvRealBytes, $pvRealSha, $pvLo, $pvHi, $pvLinesOk, $(if ($pvOk) { 'ok' } else { 'STALE' })))
    }
}

# THE SEALED-LIBRARY BLOCK AND ITS LINE CITATION. §5.1 quotes the protected/parent arrays and cites
# them by line number -- a citation that rots silently on the next edit above it.
$k4Cite = @($k4Doc | Where-Object { $_ -match 'evidence-common\.ps1:(\d+)-(\d+)' })
$k4CiteOk = $false
if ($k4Cite.Count -ge 1 -and ($k4Cite[0] -match 'evidence-common\.ps1:(\d+)-(\d+)')) {
    $lo = [int]$Matches[1]; $hi = [int]$Matches[2]
    $pAt = -1; $qAt = -1
    for ($i = 0; $i -lt $k4Seal.Count; $i++) {
        if ($k4Seal[$i] -match '^\$script:EvidenceProtectedPaths\s*=\s*@\(') { $pAt = $i + 1 }
        if ($k4Seal[$i] -match '^\$script:EvidenceParentPaths\s*=\s*@\(')    { $qAt = $i + 1 }
    }
    $k4CiteOk = ($pAt -eq $lo) -and ($qAt -gt $lo) -and ($qAt -le $hi)
    [void]$k4Rows.Add(('      {0,-42} cites {1}-{2}; arrays begin at {3} and {4}' -f 'the sealed protected-list citation', $lo, $hi, $pAt, $qAt))
} else {
    [void]$k4Rows.Add(('      {0,-42} NO line citation found to check' -f 'the sealed protected-list citation'))
}
if (-not $k4CiteOk) { $k4Ok = $false }
$detail = @"
    Each function-shaped block in LAM-INSTALL is found in the next-gen library BY NAME and compared
    against it as CODE -- tokenised, commentary and layout dropped, every remaining token equal:
$($k4Rows -join "`n")
    Twice this page has printed a SUPERSEDED predicate while the current one sat a directory away,
    and an operator mirroring either would have installed the exact hole the section was written to
    close. A page of instructions that no instrument reads is a page that can only be corrected
    after it has already been followed.
"@
Check -Id 'K-4' -Title "LAM-INSTALL's code excerpts are compared against the code they instruct an operator to mirror, and diverge loudly" `
      -Ok $k4Ok -Detail $detail

# ================================================================================================
# K-5 -- THE SECTION-1 HASH TABLES ARE READ BY SOMETHING (V-1 round 17, WP-5 finding)
# ================================================================================================
# THE SAME ROW WAS WRONG IN FOUR CONSECUTIVE ROUNDS. It was re-derived in round 13, again in round
# 14, again in round 16 -- and each time the next commit that touched the file put it back. The note
# beside the table says re-deriving belongs in the change that moves a file, and says it twice, and
# predicts in writing that it will go stale again. It did.
#
# A REPOSITORY-WIDE SEARCH FOR THE ROW'S OWN FIGURES RETURNED ONE HIT: THE ROW. No instrument, test
# or gate read them, so nothing could catch the drift and the only control was somebody remembering.
# That is the defect -- a fact a record carries that nothing reads is a claim about a check that does not
# happen -- and it is the whole explanation for four recurrences. Writing the note more emphatically
# was tried three times.
#
# THE PARSE IS ASSERTED FOR NON-VACUITY, because a table-checker that silently reads nothing is
# indistinguishable from a table that is correct -- this round's finding, applied to the member
# written for this round's finding.
$k5doc = Join-Path $repoRoot 'docs\framework\LAM-INSTALL.md'
$k5bases = @{
    'SEALED' = Join-Path $repoRoot 'tools\framework\hooks'
    'NEXT'   = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks'
}
$k5rows = @()
$k5bad = 0
$k5which = $null
$k5seen = $false
# A FIGURE WITHOUT ITS BASIS IS NOT A MEASUREMENT, AND THIS MEMBER SPENT A ROUND PROVING IT.
# This member used to hash
# [System.IO.File]::ReadAllBytes -- a CRLF working copy -- while every figure in both tables was
# recorded over LF-normalised bytes, and reported ALL SIXTEEN ROWS STALE against a tree in which
# fifteen of them were exact. Four rounds of "re-derive, never type" could not have caught that:
# everybody re-deriving was re-deriving a different quantity from the one recorded, so each
# correction was wrong in a new way.
#
# So the basis is now DECLARED ON THE PAGE and MEASURED HERE, and the two are tied together:
#   * measurement -- every CRLF collapsed to a single LF, in-process, byte level. No git call: a
#     native exe writing to stderr is a fatal NativeCommandError under this file's EAP=Stop, and an
#     instrument that can be killed by a warning on stderr is not a measurement either.
#   * equality with the git blob is a MEASURED corollary, not an assumption. At the commit that
#     introduced this, all 16 files satisfied  normalised bytes == `git cat-file -s`  and
#     normalised sha == the blob's sha; the page states that and gives both routes. (`-text` in
#     .gitattributes would break the corollary for a path, which is why the page states the
#     normalisation as the definition and the blob as the corollary, not the other way round.)
#   * $k5basis below asserts the page still SAYS which bytes it means, per table. Deleting the
#     declaration and leaving the figures would restore exactly the ambiguity this round cured, and
#     it would do it silently -- so it turns this member red instead.
$k5basis = @{ 'SEALED' = $false; 'NEXT' = $false }
foreach ($line in (Get-Content -LiteralPath $k5doc -Encoding UTF8)) {
    # BOTH THE LABEL AND THE DIRECTORY, AND THE BLOCK ENDS AT A BLANK LINE (V-1 round 18, WP-5
    # finding). Matching the prose "the sealed set" alone armed the selector at four later places in
    # the document; nothing had gone wrong yet, which is exactly when to fix a coupling to wording.
    if ($line -match 'the sealed set' -and $line -match 'tools/framework/hooks') { $k5which = 'SEALED'; $k5seen = $false }
    elseif ($line -match 'Next generation' -and $line -match 'tools/evidence-hooks-next/hooks') { $k5which = 'NEXT'; $k5seen = $false }
    elseif ($k5seen -and -not $line.Trim()) { $k5which = $null; $k5seen = $false }
    # THE BASIS DECLARATION, WHICH MUST SIT BETWEEN A TABLE'S HEADING AND ITS FIRST ROW. Checked
    # per table rather than document-wide: a single sentence somewhere on a 1300-line page is not a
    # label on this table, and the one thing this round proved is that a reader who has to go
    # looking for the basis assumes one instead.
    if ($k5which -and -not $k5seen -and $line -match 'BASIS: LF-NORMALISED BYTES') { $k5basis[$k5which] = $true }
    # Only the section-1 tables have this exact shape: name, decimal bytes, 16-hex sha.
    # HEX IS CASE-INSENSITIVE AND THIS REGEX WAS NOT (V-1 round 19, WP-5 finding, driven). Requiring
    # [0-9a-f] meant an UPPER-CASE sha never parsed as a row at all, so the normalisation twenty
    # lines down -- .ToLowerInvariant() on the parsed value -- could never be reached. Worse than
    # unreachable: a file whose row exists and is CORRECT then reported "ON DISK WITH NO ROW IN THE
    # TABLE", and an operator doing what that message says ADDS A SECOND ROW for a file that has one.
    # Driven by upper-casing a real row and reading this member's own output back.
    $m = [regex]::Match($line, '^\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|\s*`([0-9a-fA-F]{16})`\s*\|\s*$')
    if (-not $m.Success -or -not $k5which) { continue }
    $k5seen = $true
    $name = $m.Groups[1].Value
    $docBytes = [int]$m.Groups[2].Value
    $docSha = $m.Groups[3].Value
    $file = Join-Path $k5bases[$k5which] ($name -replace '/', '\')
    if (-not (Test-Path -LiteralPath $file)) {
        $k5rows += ("    {0,-6} {1,-34} FILE MISSING at {2}" -f $k5which, $name, $file)
        $k5bad++
        continue
    }
    $raw = [System.IO.File]::ReadAllBytes($file)
    # THE DECLARED BASIS, MEASURED: every CRLF collapsed to a single LF. A lone CR and a lone LF are
    # both left alone, which is what git's own clean filter does under core.autocrlf -- so this is a
    # definition in its own right, reproducible without git, and the blob equality stated on the
    # page is its corollary rather than its premise.
    $lfList = New-Object 'System.Collections.Generic.List[byte]'
    for ($bi = 0; $bi -lt $raw.Length; $bi++) {
        if ($raw[$bi] -eq 13 -and ($bi + 1) -lt $raw.Length -and $raw[$bi + 1] -eq 10) { continue }
        [void]$lfList.Add($raw[$bi])
    }
    $lfBytesArr = $lfList.ToArray()
    $realBytes = $lfBytesArr.Length
    $realSha = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($lfBytesArr)).Replace('-', '').ToLowerInvariant().Substring(0, 16)
    # THE OTHER BASIS IS PRINTED TOO, AND IT IS NOT DECORATION. It is what `Get-FileHash` answers,
    # so a reader who ran that and got a different number can see, on this row, that the difference
    # is the CR count and not a corrupt file -- which is the exact confusion that made sixteen
    # healthy rows read as stale for four rounds.
    $wcBytes = $raw.Length
    $wcSha = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($raw)).Replace('-', '').ToLowerInvariant().Substring(0, 16)
    # `-eq` on strings folds case in PowerShell, so an UPPERCASE sha in the table -- which is what
    # Get-FileHash emits, and therefore the likeliest thing a hurried operator pastes -- compares
    # equal. That is the right outcome for a hash and the wrong one to leave implicit, so it is
    # stated: the row is normalised before comparison rather than relying on the operator's `-eq`.
    $rowOk = ($realBytes -eq $docBytes -and $realSha -eq $docSha.ToLowerInvariant())
    if (-not $rowOk) { $k5bad++ }
    # MEASUREMENTS, NOT ASSERTIONS: the row prints what the document says AND what the file is, so a
    # failure hands the reader the corrected row instead of the news that something is wrong.
    $k5rows += ("    {0,-6} {1,-34} doc {2,-8} {3}   LF {4,-8} {5}  {6,-5}  (working copy {7,-8} {8})" -f `
                $k5which, $name, $docBytes, $docSha, $realBytes, $realSha, $(if ($rowOk) { 'ok' } else { 'STALE' }), `
                $wcBytes, $wcSha)
}
# AND EVERY FILE MUST HAVE A ROW (V-1 round 18, WP-5 finding). The check above is one-directional:
# it proves each row describes its file and says nothing about a file with no row. That is not a
# hypothetical -- the note beside the table records an earlier revision adding two files without adding
# rows, which is this exact gap, and the `>= 15` floor is a LOWER bound that a new unrowed file
# sails past. The instrument's own law is that closure is checked in both directions.
$k5rowed = @{}
foreach ($r in $k5rows) {
    $rm = [regex]::Match($r, '^\s*(SEALED|NEXT)\s+(\S+)')
    if ($rm.Success) { $k5rowed[($rm.Groups[1].Value + '|' + $rm.Groups[2].Value)] = $true }
}
foreach ($which in @('SEALED', 'NEXT')) {
    $base = $k5bases[$which]
    # EVERY POWERSHELL CODE FILE, AND HIDDEN ONES (V-1 round 19, WP-5 finding). `-Filter '*.ps1'`
    # missed a `.psm1` module, and Get-ChildItem without -Force does not return hidden files -- so a
    # file could be added to either tree, be loaded at runtime, and never appear as unrowed.
    #
    # DELIBERATELY NOT EVERY FILE. Widening to all extensions would immediately flag
    # `settings.evidence-hooks.json`, whose row is the SEALED table's known eighth entry and is
    # waiting on a ratified amendment (successor brief, operator ruling). Turning this member red
    # for a pending ruling would make it a nag rather than a check, and would say a defect exists
    # where a decision is outstanding.
    foreach ($f in @(Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction SilentlyContinue |
                     Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') })) {
        $rel = $f.FullName.Substring($base.Length).TrimStart('\') -replace '\\', '/'
        if (-not $k5rowed.ContainsKey($which + '|' + $rel)) {
            $k5rows += ("    {0,-6} {1,-34} ON DISK WITH NO ROW IN THE TABLE" -f $which, $rel)
            $k5bad++
        }
    }
}
$k5parsed = @($k5rows).Count
# Both tables together carry 15 rows today. The floor is deliberately the real count and not zero:
# a regex that stops matching because the table was reformatted must go RED, not quietly pass.
$k5enough = ($k5parsed -ge 15)
# THE BASIS MUST STILL BE STATED, PER TABLE, AND IT MUST STILL BE REPRODUCIBLE. A basis nobody can
# run is a basis nobody can check, so the page is held to carrying both routes it names: the
# git-side one and the in-process one this member actually performs.
$k5docText = [System.IO.File]::ReadAllText($k5doc)
$k5repro = ($k5docText -match 'git cat-file -s') -and ($k5docText -match 'ReadAllBytes')
$k5basisOk = $k5basis['SEALED'] -and $k5basis['NEXT'] -and $k5repro
$k5ok = ($k5bad -eq 0 -and $k5enough -and $k5basisOk)
$k5detail = @"
    Every row of both section-1 tables, re-measured from the file it names ON THE BASIS THE TABLE
    DECLARES -- every CRLF collapsed to one LF -- with the working copy's bytes shown alongside so a
    ``Get-FileHash`` reader can see that any difference is the CR count, not a defect:
$($k5rows -join "`n")
    rows parsed: $k5parsed   (expect >= 15; a parse that finds fewer has stopped reading the table
    and must not pass quietly)   stale rows: $k5bad
    basis declared above the SEALED table: $($k5basis['SEALED'])   above the NEXT table: $($k5basis['NEXT'])   reproduction routes on the page: $k5repro   (all expect True)
    THE ROW FOR ``lib/evidence-common.ps1`` HAS BEEN WRONG IN FOUR CONSECUTIVE ROUNDS, each time
    because a commit moved the file and did not re-derive. The note beside the table already said to,
    and predicted in writing that it would go stale again. It is not a wording problem: nothing read
    the figures, so nothing could fail. This member is the reader.
    AND FOR ONE ROUND THIS MEMBER READ THE WRONG QUANTITY: it hashed a CRLF working copy against
    figures recorded over LF bytes and called all sixteen rows stale, fifteen of which were exact.
    A reader on a different basis from the record is not a check, it is a second unverified claim --
    so the basis is declared on the page, asserted here, and measured here, and the three are one
    thing rather than three hopes.
"@
Check -Id 'K-5' -Title "section 1's byte counts and hashes are re-measured from the files they name, in both tables" `
      -Ok $k5ok -Detail $k5detail

Write-Host ""
Write-Host "------------------------------------------------------------------------------"
if ($failures -eq 0) { Write-Host " WP-5: all $checksRun checks passed." }
else { Write-Host " WP-5: $failures of $checksRun checks FAILED." }
Write-Host "------------------------------------------------------------------------------"
Write-Host "EXIT: $failures"
exit $failures
