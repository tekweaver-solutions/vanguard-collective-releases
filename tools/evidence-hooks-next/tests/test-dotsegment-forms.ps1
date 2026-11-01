#Requires -Version 5.1
<#
.SYNOPSIS
  THE '..' FORM-BUILDER MEMBER.

.DESCRIPTION
  WHAT THIS MEMBER EXISTS TO CATCH. `Get-EvidencePathForms` resolved dot segments BEFORE the cwd
  join, and `Resolve-DotSegments` popped a leading `..` off an EMPTY stack and DISCARDED it. From a
  worker's cwd of `<repo>/.claude/worktrees/wt-X`:

      ../../settings.json  ->  settings.json  ->  <cwd>/settings.json

  The joined form was ALWAYS under the worktree root, so no form naming the real
  `<repo>/.claude/settings.json` was ever produced and an un-metachared `cat ../../settings.json`
  was ALLOWED.

  WHY IT IS A SEPARATE FILE AND NOT A CHECK IN test-a1-negative.ps1. That suite's N10 enforces SET
  EQUALITY between its deny-case names and a mirror block in
  docs/framework/evidence-write-path-threat-notes.md, and its summary enforces the documented
  `TALLY checks` against the number of Check calls. Adding a case or a check there turns N10 red
  through a document this session does not own. The suite is left byte-for-byte untouched and is
  driven as a REGRESSION CONTROL instead (LAM-ACCEPT H-4: 14 checks, unchanged, must still pass).
  tests/lam/instrument-WP-1.ps1 was the other candidate and was declined for the same reason in
  reverse: WP-1 is the acceptance instrument for the WP-1 clause set, and this is a defect in a
  shared path primitive that every route reaches -- it belongs beside the library it tests.

  THE RELATIVE SPELLINGS COME FIRST, deliberately. The defect's transferable lesson is that the
  44-row member which missed this defect used a bare relative `..` in ZERO of its rows -- every
  traversal row spelled the path absolutely, and the absolute spellings already denied. So F-1
  leads with `..`, `../..`, `../../x`, `./../x`, `..\..\x` and the trailing-slash forms.

  BOTH DIRECTIONS. F-1/F-5 go red when the cure is reverted. F-2/F-3/F-4 are the fail-closed side:
  interior `..` must resolve exactly as before, every legacy form must still be produced, and rooted
  paths must be byte-identical. F-6 is the run's validity control -- a deny population that must
  stay denied and an allow population that must stay allowed, driven through the real hook. If F-6
  ever reports all-allow the apparatus is broken and the whole run must be discarded.

  ZERO REPO RESIDUE. The fixture lives outside the repository, under $env:TEMP; CLAUDE_PROJECT_DIR
  points the hooks' evidence plane at a temp sandbox. Nothing is written inside the tree.

  Exit code 0 = all checks passed. Non-zero = count of failures.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# tools/evidence-hooks-next/tests/<this file> -> up one -> tools/evidence-hooks-next
$nextRoot = Split-Path -Parent $PSScriptRoot
$libPath  = Join-Path $nextRoot 'hooks\lib\evidence-common.ps1'
$guard    = Join-Path $nextRoot 'hooks\evidence-guard-pretooluse.ps1'

$failures = 0
$checksRun = 0
function Write-CheckResult {
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail)
    $script:checksRun++
    $tag = if ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ''
    Write-Host "[$tag] $Id -- $Title"
    if ($Detail) { Write-Host $Detail }
    if (-not $Ok) { $script:failures++ }
}

# --- fixture, OUTSIDE the repository ----------------------------------------------------------
$fixture = Join-Path $env:TEMP 'lam-dotsegment-forms-fixture'
if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $fixture '.claude\worktrees\wt-X\src') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture '.claude\worktrees\wt-Y\src') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture '.mission\gates') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture 'tools\framework\hooks') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $fixture '.claude\settings.json') -Value '{}' -Encoding ascii
Set-Content -LiteralPath (Join-Path $fixture '.claude\worktrees\wt-Y\src\peer.txt') -Value 'peer' -Encoding ascii

$sandbox = Join-Path $env:TEMP 'lam-dotsegment-forms-sandbox'
if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null

$repo = ((Resolve-Path -LiteralPath $fixture).Path) -replace '\\', '/'
$wtX  = "$repo/.claude/worktrees/wt-X"

. $libPath

Write-Host '=============================================================================='
Write-Host " THE '..' FORM-BUILDER MEMBER -- amendment 37"
Write-Host '=============================================================================='
Write-Host "library  : $libPath"
Write-Host "fixture  : $repo   (outside the repository)"
Write-Host "worker   : $wtX"

# ==============================================================================================
# F-1 -- A TOKEN WHOSE REAL TARGET LIES OUTSIDE THE CWD PRODUCES A FORM THAT SAYS SO.
#        The ordinary relative spellings lead. This is the check the defect fails.
# ==============================================================================================
$f1Cases = @(
    @{ tok = '..';                    real = "$repo/.claude/worktrees" },
    @{ tok = '../..';                 real = "$repo/.claude" },
    @{ tok = '../../';                real = "$repo/.claude" },
    @{ tok = '../../settings.json';   real = "$repo/.claude/settings.json" },
    @{ tok = './../../settings.json'; real = "$repo/.claude/settings.json" },
    @{ tok = '..\..\settings.json';   real = "$repo/.claude/settings.json" },
    @{ tok = '../wt-Y';               real = "$repo/.claude/worktrees/wt-Y" },
    @{ tok = '../wt-Y/';              real = "$repo/.claude/worktrees/wt-Y" },
    @{ tok = '../wt-Y/src/peer.txt';  real = "$repo/.claude/worktrees/wt-Y/src/peer.txt" },
    @{ tok = '..\wt-Y\src\peer.txt';  real = "$repo/.claude/worktrees/wt-Y/src/peer.txt" },
    @{ tok = './../wt-Y';             real = "$repo/.claude/worktrees/wt-Y" },
    @{ tok = '../../../.mission/gates/g.yaml'; real = "$repo/.mission/gates/g.yaml" },
    @{ tok = '../../../tools/framework/hooks/x.ps1'; real = "$repo/tools/framework/hooks/x.ps1" }
)
$f1Lines = @(); $f1Ok = $true
foreach ($case in $f1Cases) {
    $forms = @(Get-EvidencePathForms -Text $case.tok -Cwd $wtX)
    $named = ($forms -contains $case.real)
    if (-not $named) { $f1Ok = $false }
    $f1Lines += ("    {0,-34} -> {1}" -f $case.tok, $(if ($named) { "names the real target  ok" } else { "NO FORM NAMES '$($case.real)'  <-- FAIL" }))
    if (-not $named) { $f1Lines += ("        forms produced: " + ($forms -join ' | ')) }
}
Write-CheckResult -Id 'F-1' -Title 'every leading-''..'' spelling produces a form naming its REAL target' `
      -Ok $f1Ok -Detail (@"
  cwd = $wtX
$($f1Lines -join "`n")
"@)

# ==============================================================================================
# F-2 -- INTERIOR '..' RESOLVES EXACTLY AS IT DID. The cure touches the branch where the stack is
#        EMPTY and nothing else; a `foo/../bar` still collapses.
# ==============================================================================================
$f2Cases = @(
    @{ tok = 'foo/../bar';                          want = 'bar' },
    @{ tok = 'a/b/../../c';                         want = 'c' },
    @{ tok = '.mission-runtime/zz/../evidence/x';   want = '.mission-runtime/evidence/x' },
    @{ tok = '.mission/./evidence/x';               want = '.mission/evidence/x' },
    @{ tok = 'src/../src/peer.txt';                 want = 'src/peer.txt' },
    @{ tok = 'a/../b/../c';                         want = 'c' }
)
$f2Lines = @(); $f2Ok = $true
foreach ($case in $f2Cases) {
    $got = Resolve-DotSegments -Token $case.tok
    $ok = ($got -eq $case.want)
    if (-not $ok) { $f2Ok = $false }
    $f2Lines += ("    {0,-34} -> {1,-34} {2}" -f $case.tok, $got, $(if ($ok) { 'ok' } else { "expected '$($case.want)'  <-- FAIL" }))
}
# and rooted paths are byte-identical to A1: `/..` is `/`, which is what the filesystem does.
$f4Cases = @(
    @{ tok = '/a/../../x';   want = '/x' },
    @{ tok = '/../x';        want = '/x' },
    @{ tok = '/..';          want = '/' },
    @{ tok = '/a/b/../c';    want = '/a/c' }
)
foreach ($case in $f4Cases) {
    $got = Resolve-DotSegments -Token $case.tok
    $ok = ($got -eq $case.want)
    if (-not $ok) { $f2Ok = $false }
    $f2Lines += ("    {0,-34} -> {1,-34} {2}  (rooted)" -f $case.tok, $got, $(if ($ok) { 'ok' } else { "expected '$($case.want)'  <-- FAIL" }))
}
Write-CheckResult -Id 'F-2' -Title 'interior ''..'' and rooted paths resolve exactly as before the cure' `
      -Ok $f2Ok -Detail ($f2Lines -join "`n")

# ==============================================================================================
# F-3 -- ADD, NEVER SUBSTITUTE. Every form the guard produced BEFORE the cure is still produced,
#        which is what makes the change fail-closed by construction rather than by survey.
# ==============================================================================================
$f3Toks = @('..', '../..', '../../settings.json', '../wt-Y', '../wt-Y/src/peer.txt',
            'foo/../bar', '.mission-runtime/zz/../evidence/x', 'plain.txt', '/a/../b')
$f3Lines = @(); $f3Ok = $true
foreach ($tokText in $f3Toks) {
    $forms  = @(Get-EvidencePathForms -Text $tokText -Cwd $wtX)
    $legacy = Resolve-DotSegmentsLegacy -Token (ConvertTo-CanonicalPathText -Text $tokText)
    $missing = @()
    if ($legacy) {
        if ($forms -notcontains $legacy) { $missing += $legacy }
        if (-not (Test-EvidenceRootedPath -Path $legacy)) {
            $legacyJoin = Resolve-DotSegmentsLegacy -Token "$wtX/$legacy"
            if ($forms -notcontains $legacyJoin) { $missing += $legacyJoin }
        }
    } else {
        # The legacy resolution was EMPTY, and an empty resolution joined to the cwd named the cwd.
        if ($forms -notcontains $wtX) { $missing += $wtX }
    }
    if ($missing.Count -gt 0) { $f3Ok = $false }
    $f3Lines += ("    {0,-34} legacy forms retained: {1}" -f $tokText, $(if ($missing.Count -eq 0) { 'ok' } else { ('MISSING ' + ($missing -join ' , ') + '  <-- FAIL') }))
}
Write-CheckResult -Id 'F-3' -Title 'every form the pre-cure builder produced is STILL produced (add, never substitute)' `
      -Ok $f3Ok -Detail ($f3Lines -join "`n")

# ==============================================================================================
# F-5 -- THE REAL PREDICATE, END TO END. Worker role, PSCustomObject tool input, cwd inside the
#        worktree, through the installed guard hook -- the apparatus that found the defect.
# ==============================================================================================
$prevProject  = $env:CLAUDE_PROJECT_DIR
$prevDispatch = $env:MISSION_DISPATCH_ID
$prevLam      = $env:LAM_DISPATCH
$env:CLAUDE_PROJECT_DIR  = $sandbox
$env:MISSION_DISPATCH_ID = 'lam-dotsegment-forms'
$env:LAM_DISPATCH        = 'D-DOTSEGMENT-FORMS'

function Invoke-GuardRow {
    param([string]$ToolName, $ToolInput, [string]$Cwd)
    $json = @{
        session_id      = 'sess-dotsegment-forms'
        hook_event_name = 'PreToolUse'
        tool_name       = $ToolName
        tool_input      = $ToolInput
        cwd             = $Cwd
    } | ConvertTo-Json -Depth 8 -Compress
    # A native exe's stderr is a FATAL NativeCommandError under EAP 'Stop' in PS 5.1, and the guard
    # writes its denial reason to stderr on every deny. So the preference is lowered around the call
    # and restored immediately -- never left lowered, which would hide a real failure later.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out  = $json | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guard 2>$null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $text = ($out -join "`n")
    $verdict = if ($text -like '*"permissionDecision":"deny"*') { 'deny' }
               elseif ($text -like '*"permissionDecision":"allow"*') { 'allow' }
               else { 'other' }
    return [pscustomobject]@{ verdict = $verdict; exit = $code; text = $text }
}

# THE ROWS THIS CURE IS FOR: an un-metachared token naming .claude/settings.json from a worker
# worktree. These were ALLOWED before the cure -- pre-existing, not the revert.
$f5Cases = @(
    @{ n = 'cat ../../settings.json';        tool = 'Bash';  inp = @{ command = 'cat ../../settings.json' } },
    @{ n = 'cat ..\..\settings.json';        tool = 'Bash';  inp = @{ command = 'cat ..\..\settings.json' } },
    @{ n = 'cat ./../../settings.json';      tool = 'Bash';  inp = @{ command = 'cat ./../../settings.json' } },
    @{ n = 'head -n1 ../../settings.json';   tool = 'Bash';  inp = @{ command = 'head -n1 ../../settings.json' } },
    @{ n = 'cp x ../../settings.json';       tool = 'Bash';  inp = @{ command = 'cp forged.json ../../settings.json' } },
    @{ n = 'Write ../../settings.json';      tool = 'Write'; inp = @{ file_path = '../../settings.json'; content = '{}' } },
    @{ n = 'Edit ../../settings.json';       tool = 'Edit';  inp = @{ file_path = '../../settings.json'; old_string = 'a'; new_string = 'b' } }
)
$f5Lines = @(); $f5Ok = $true
foreach ($case in $f5Cases) {
    $res = Invoke-GuardRow -ToolName $case.tool -ToolInput ([pscustomobject]$case.inp) -Cwd $wtX
    # THE ROW MUST DENY FOR ITS OWN STATED REASON, not incidentally: the reason must name the
    # protected path the token really reaches. A deny for some other reason is not this evidence.
    $rightReason = ($res.text -like '*.claude/settings.json*')
    $ok = ($res.verdict -eq 'deny' -and $res.exit -eq 2 -and $rightReason)
    if (-not $ok) { $f5Ok = $false }
    $f5Lines += ("    {0,-28} verdict={1,-5} exit={2} names '.claude/settings.json'={3}  {4}" -f `
        $case.n, $res.verdict, $res.exit, $rightReason, $(if ($ok) { 'ok' } else { '<-- FAIL' }))
}
Write-CheckResult -Id 'F-5' -Title 'the real guard DENIES a leading-''..'' token that reaches .claude/settings.json, naming it in the reason' `
      -Ok $f5Ok -Detail (@"
  worker role (LAM_DISPATCH set), PSCustomObject tool input, cwd = $wtX
$($f5Lines -join "`n")
"@)

# ==============================================================================================
# F-6 -- THE RUN'S VALIDITY CONTROL. A guard harness that allows everything proves nothing, and a
#        synthetic call that allows everything is how a green run gets banked on no apparatus at
#        all. These rows must land on both sides, before the cure and after it.
# ==============================================================================================
$f6Deny = @(
    @{ n = 'rm -rf runtime evidence';   tool = 'Bash';  inp = @{ command = 'rm -rf .mission-runtime/evidence' } },
    @{ n = 'rm -f settings.json';       tool = 'Bash';  inp = @{ command = 'rm -f .claude/settings.json' } },
    @{ n = 'edit the sealed library';   tool = 'Edit';  inp = @{ file_path = 'tools/framework/hooks/lib/evidence-common.ps1'; old_string = 'a'; new_string = 'b' } },
    @{ n = 'write committed evidence';  tool = 'Write'; inp = @{ file_path = '.mission/evidence/x/manifest.json'; content = 'forged' } },
    @{ n = 'parent hop zz/..';          tool = 'Write'; inp = @{ file_path = '.mission-runtime/zz/../evidence/x/log.jsonl'; content = 'forged' } },
    @{ n = 'redirect into evidence';    tool = 'Bash';  inp = @{ command = 'printf "forged" > .mission-runtime/evidence/d/log.jsonl' } },
    @{ n = 'git blame --output';        tool = 'Bash';  inp = @{ command = 'git blame --output=.mission-runtime/evidence/d/log.jsonl tracked.txt' } },
    @{ n = 'bash cat a manifest';       tool = 'Bash';  inp = @{ command = 'cat .mission/evidence/d/manifest.json' } }
)
$f6Allow = @(
    @{ n = 'ordinary doc write';        tool = 'Write'; inp = @{ file_path = 'docs/framework/some-note.md'; content = 'ordinary work' } },
    @{ n = 'git status';                tool = 'Bash';  inp = @{ command = 'git status --porcelain=v1' } },
    @{ n = 'Read an evidence log';      tool = 'Read';  inp = @{ file_path = '.mission/evidence/x/log.jsonl' } },
    @{ n = 'Grep over evidence';        tool = 'Grep';  inp = @{ pattern = 'rev-parse'; path = '.mission/evidence' } },
    @{ n = 'write into own worktree';   tool = 'Write'; inp = @{ file_path = 'src/new.txt'; content = 'x' } },
    @{ n = 'read a peer worktree file'; tool = 'Bash';  inp = @{ command = 'cat ../wt-Y/src/peer.txt' } }
)
$f6Lines = @(); $f6Ok = $true
foreach ($case in $f6Deny) {
    $res = Invoke-GuardRow -ToolName $case.tool -ToolInput ([pscustomobject]$case.inp) -Cwd $wtX
    $ok = ($res.verdict -eq 'deny')
    if (-not $ok) { $f6Ok = $false }
    $f6Lines += ("    DENY-CONTROL  {0,-26} verdict={1,-5} {2}" -f $case.n, $res.verdict, $(if ($ok) { 'ok' } else { 'NOT DENIED  <-- APPARATUS BROKEN' }))
}
foreach ($case in $f6Allow) {
    $res = Invoke-GuardRow -ToolName $case.tool -ToolInput ([pscustomobject]$case.inp) -Cwd $wtX
    $ok = ($res.verdict -eq 'allow')
    if (-not $ok) { $f6Ok = $false }
    $f6Lines += ("    ALLOW-CONTROL {0,-26} verdict={1,-5} {2}" -f $case.n, $res.verdict, $(if ($ok) { 'ok' } else { 'NOT ALLOWED  <-- FAIL' }))
}
Write-CheckResult -Id 'F-6' -Title 'validity control: the deny population still denies and the allow population still allows' `
      -Ok $f6Ok -Detail ($f6Lines -join "`n")

$env:CLAUDE_PROJECT_DIR  = $prevProject
$env:MISSION_DISPATCH_ID = $prevDispatch
$env:LAM_DISPATCH        = $prevLam

# --- summary ----------------------------------------------------------------------------------
Write-Host ''
Write-Host '=============================================================================='
if ($failures -eq 0) {
    Write-Host " ALL $checksRun CHECKS PASSED"
} else {
    Write-Host " $failures of $checksRun CHECKS FAILED"
}
Write-Host '=============================================================================='

if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }

exit $failures
