#Requires -Version 5.1
<#
.SYNOPSIS
  mission init / mission smoke -- the first two things to run after install.ps1.

.DESCRIPTION
  init   Creates an EMPTY mission in the target: .mission/mission.yaml, .mission/spec/current.txt and
         .mission/spec/v001.yaml, an empty .mission/ledger/entries.jsonl, the folders amendments,
         contract, dispatches, evidence, gates, goals, handoffs, inputs and validator-results, and the
         goal .mission/goals/SMOKE-MISSION.yaml. The shape is the smoke mission's
         (tools/lam/smoke-mission/dot-mission/); no value is copied from it. Every value written is a
         placeholder for the operator to fill in, or a fresh identifier. It REFUSES, writing nothing,
         if any file it would write is already there -- a mission is never overwritten.

         spec/current.txt reads v001, with no final newline, and the spec file is v001.yaml: the form
         the framework's own spec tools read and write. tools/mission-lib.ps1 Invoke-SpecBump takes
         the token by '^v(\d+)$' (:297) and opens 'v{0:000}.yaml' (:300, :302); under tools/,
         close-milestone, promote-contract and gen_brief.py open '<token>.yaml'
         (mission-close-milestone.ps1:476-477, mission-promote-contract.ps1:60-61,
         lam/gen_brief.py:487-490), and spec-accept and reclaim admit only '^v\d{3}$'
         (mission-spec-accept.ps1:122, mission-reclaim.ps1:69). Only a three-digit
         token names the same file for all of them, and v001 is it. No final newline because
         Invoke-SpecBump (:316) and spec-accept (:644) write the token without one; every reader trims.

         THE TARGET'S ROOT .gitignore. Once the mission is written, init makes the target's own
         .gitignore ignore Claude Code's two per-checkout paths, the rules the framework repository's
         .gitignore carries: /.claude/settings.local.json and /.claude/worktrees/ (.claude/settings.json
         is named by neither and stays tracked). WP-1 H-26 reads both as ignored (git check-ignore
         --no-index) once .claude/settings.json is tracked. A THIRD RULE, /.mission-runtime/telemetry/
         (UI-1 S1, ADR-045): the mission-event feed is never committed; a line .mission-runtime/ (anchored or
         not) already ignores it and counts as the rule held. No .gitignore: it is created holding a
         one-line comment and the three rules, LF. One there: a rule it already holds -- a line equal to
         the rule, with or without its leading slash (a middle slash anchors it either way), trailing
         spaces aside -- is left alone, and only the missing ones are appended after the same one-line
         comment, in the line ending the file's first line break uses (LF if it has none), after a
         line break if its last line has none. No byte already there is rewritten, removed or moved,
         and a file holding both is left byte for byte. init prints one line saying which of the three
         it did. A later negation (!...) of a rule is not read: the file is the project's own. A
         .gitignore that is a folder, that cannot be read, or that lacks a rule and cannot be appended
         to (read-only, or denied) makes the target unusable (exit 1, nothing written): the whole
         .gitignore decision is made before the first write. A refused
         init (exit 2) does not touch .gitignore either.

  smoke  Runs the TARGET's own installed evaluator,
           <target>\tools\lam\mission-goal-check.ps1 -Goal SMOKE-MISSION -MissionRoot <target>
         prints what it prints (its first line is the verdict line), and exits 0 if and only if the
         verdict is MET -- otherwise with the evaluator's own exit code. It is the target's copy that
         runs, so a MET says the installed evaluator reads the initialised mission.

  WHY init DOES NOT WRAP tools/mission-init.ps1. That script creates a NEW folder named -ProjectName
  under the current directory and refuses one that exists (tools/mission-init.ps1:45-50) -- and the
  install target always exists by then. It also lays out a whole v1 product monorepo (prompts/, src/,
  docker/, tools/worker-runner/ ...; :53-72), writes the folder's .gitignore and README.md
  (:198-199), and runs git init, git add . and a first commit (:203-207), which would commit the
  installed framework. Its mission skeleton has no spec/current.txt, no spec file (only
  spec/proposals/) and no goals/, gates/ or evidence/. So init is new, and mission-init.ps1 is left as it is.

  NO .gitkeep FILES. The goal's admitted-stop arms walk .mission/amendments/ and
  .mission/dispatches/; an empty folder is nothing to classify (mission-goal-check.ps1:1781, :2267),
  while a file there that git does not track -- or cannot classify, outside a git repository -- is
  a placement awaiting its gate. Measured: one empty .gitkeep under .mission/amendments/ reads
  AWAITING_AMENDMENT_GATE, exit 4; removed, MET. The folders are therefore left empty. Git does not carry an empty folder, so a clone of the mission loses them:
  harmless to the arms (an absent folder admits nothing, :1751, :2245), but SMOKE-MISSION's
  file_exists rows then fail until the folders are made again.

.PARAMETER Verb
  init, smoke or register. register (UI-1 S1, ADR-045) registers an EXISTING checkout on this host for the
  mission-event feed -- a mission initialised before the feed existed, or a worktree made by hand: host-id
  once, its own registry row, .mission-runtime/telemetry/, the root .gitignore rule. EXIT 0 registered, 1 no
  mission or no registration step on disk.
.PARAMETER Target
  The folder install.ps1 installed into.

.NOTES
  EXIT: init 0 written (the mission, and .gitignore as above), 2 refused (nothing written), 1 unusable
  target (nothing written). smoke 0 MET, the evaluator's
  own non-zero code otherwise, 1 when the evaluator or the goal is not there.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][ValidateSet('init', 'smoke', 'register')][string]$Verb,
    [Parameter(Mandatory = $true)][string]$Target
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Say { param([string]$Text) [Console]::Out.WriteLine('mission.ps1: ' + $Text) }

$root = [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $root -PathType Container)) { Say "no folder at $root -- run install.ps1 -Target first."; exit 1 }

if ($Verb -eq 'init') {
    $now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
    $id = [guid]::NewGuid().ToString()
    # THE MISSION'S NAME (RELEASE-4 S1, F-P5a): the target folder's name, the one the operator already calls the project by;
    # the snapshot carries it to the dashboard. The operator may rename it here.
    $nameQ = "'" + ((Split-Path -Leaf $root) -replace "'", "''") + "'"

    $missionYaml = @"
# Mission record -- written by mission.ps1 init. An EMPTY mission: every value below is a placeholder
# for the operator, or a fresh identifier. The shape follows the smoke mission's record
# (tools/lam/smoke-mission/dot-mission/mission.yaml); no value is taken from it.
#
# current_spec_version stays null until the spec is accepted; spec/current.txt already names the
# draft, v001 (spec/v001.yaml).
# A mission that needs a porcelain contract or a commit ledger declares them here itself
# (admitted_porcelain, declared_commit_ledger); this one declares neither.
# name is the target folder's name, the one the dashboard shows; rename it here.

id: $id
name: $nameQ
created_at: $now
created_by: "TODO - operator identifier"

goal: "TODO - the mission's goal, filled in during the design phase"
clarified_scope: null

state: Created
current_spec_version: null
current_milestone: null

budget:
  cost_soft_cap_usd: null
  cost_hard_cap_usd: null
  wallclock_soft_cap_hours: null
  wallclock_hard_cap_hours: null
  tokens_used: 0
  cost_used_usd: 0.00

risk_level: null

human_owner: "TODO - operator identifier"
notification_channel: null

completed_at: null
"@

    $specYaml = @"
# Living Spec v001 -- written by mission.ps1 init. A DRAFT with nothing in it: no feature, no
# milestone, no decision. The shape follows the smoke mission's spec
# (tools/lam/smoke-mission/dot-mission/spec/spec-v1.yaml); no value is taken from it. The file
# is named v001.yaml, the token spec/current.txt carries, as the mission tools read it.

version: 1
mission_id: $id
created_at: $now
state: draft

features: []

milestones: []

decisions: []
"@

    $goalYaml = @'
# SMOKE-MISSION -- the goal `mission.ps1 smoke` holds a freshly initialised mission to.
#
# EVERY DETECTOR READS DISK, AND EVERY ONE CAN BE READ IN AN EMPTY MISSION. The types are the
# evaluator's own (tools/lam/mission-goal-check.ps1, Invoke-Detector):
#   halt_absent               :5032  no unanswered HALT; the default scan is .mission-runtime/halts
#                                    and .mission-runtime/lam, which an empty mission does not have
#   file_exists               :5019  the skeleton init wrote; a relative path resolves against
#                                    -MissionRoot (:5022-:5027), so the answer does not depend on cwd
#   ungated_placement_absent  :5068  the admitted-stop arm over .mission/amendments/: an empty folder
#                                    is nothing to classify (:1781), so it admits nothing
#   ungated_manifest_absent   :5106  the admitted-stop arm over .mission/dispatches/: no
#                                    *.manifest.yaml, so it admits nothing (:2267)
#   handoff_brief_present     :5144  the handoff arm: with no .mission-runtime/lam/STATUS.md it is
#                                    inert (:2579), which passes
# A failing file_exists is a skeleton that is not there; any admitted stop or HALT is a mission
# that is no longer empty. Either way the verdict is not MET.
#
# CHEAPEST FIRST, as the fixture's goal orders its detectors: a Stop hook stops at the first failure.

id: SMOKE-MISSION
description: "A freshly initialised mission is complete and empty: its skeleton is on disk, no HALT is open, and no admitted-stop arm has anything to admit."

detectors:
  - type: halt_absent

  - type: file_exists
    path: .mission/mission.yaml
  - type: file_exists
    path: .mission/spec/current.txt
  - type: file_exists
    path: .mission/spec/v001.yaml
  - type: file_exists
    path: .mission/ledger/entries.jsonl
  - type: file_exists
    path: .mission/goals/SMOKE-MISSION.yaml
  - type: file_exists
    path: .mission/amendments
  - type: file_exists
    path: .mission/contract
  - type: file_exists
    path: .mission/dispatches
  - type: file_exists
    path: .mission/evidence
  - type: file_exists
    path: .mission/gates
  - type: file_exists
    path: .mission/handoffs
  - type: file_exists
    path: .mission/inputs
  - type: file_exists
    path: .mission/validator-results

  - type: ungated_placement_absent
  - type: ungated_manifest_absent
  - type: handoff_brief_present
'@

    $files = [ordered]@{
        '.mission\mission.yaml'             = $missionYaml
        '.mission\spec\current.txt'         = 'v001'
        '.mission\spec\v001.yaml'           = $specYaml
        '.mission\ledger\entries.jsonl'     = ''
        '.mission\goals\SMOKE-MISSION.yaml' = $goalYaml
    }
    # The spec pointer is the token alone, as Invoke-SpecBump and spec-accept write it (see above).
    $noFinalNewline = @('.mission\spec\current.txt')
    $folders = @('amendments', 'contract', 'dispatches', 'evidence', 'gates', 'goals', 'handoffs', 'inputs', 'ledger', 'spec', 'validator-results')

    $present = @($files.Keys | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) })
    if ($present.Count -gt 0) {
        foreach ($p in $present) { Say "  ALREADY PRESENT  $($p -replace '\\', '/')" }
        Say "REFUSED: a mission is already here ($($present.Count) of its files exist). Nothing was written."
        exit 2
    }
    # THE ROOT .gitignore (header): the two rules, each with the spellings that already ignore the same path.
    $giPath = Join-Path $root '.gitignore'
    if (Test-Path -LiteralPath $giPath -PathType Container) { Say "$giPath is a folder, not a file -- init cannot make it ignore Claude Code's per-checkout files. Nothing was written."; exit 1 }
    # The third rule is the runtime plane's (RELEASE-4 S1, F-P7a): everything under .mission-runtime/ is per-checkout and
    # never committed -- the mission-event feed (UI-1 S1, ADR-045) and the evidence, LAM and HALT folders the hooks and
    # verbs write beside it -- so the rule ignores the whole plane, not its telemetry folder alone.
    $giRules = [ordered]@{
        '/.claude/settings.local.json' = @('/.claude/settings.local.json', '.claude/settings.local.json')
        '/.claude/worktrees/'          = @('/.claude/worktrees/', '.claude/worktrees/')
        '/.mission-runtime/'           = @('/.mission-runtime/', '.mission-runtime/')
    }
    $giComment = '# Claude Code''s per-checkout files at this root, its local settings and its worktrees, and the runtime plane .mission-runtime/ (the mission-event feed, the evidence, LAM and HALT folders), are never committed (written by mission.ps1 init); .claude/settings.json is named by none and stays tracked.'
    $giWhy = 'per-checkout files, never committed'
    # The whole .gitignore decision is made HERE, before the first write: a .gitignore that cannot be read, or that
    # lacks a rule and cannot be appended to, makes the target unusable (exit 1) with nothing written -- never a
    # half-initialised mission that a second init then refuses as "already here".
    $giOld = $null
    $giMissing = @()
    if (Test-Path -LiteralPath $giPath -PathType Leaf) {
        # Read only to decide; the file is then APPENDED to, never rewritten. A UTF-8 BOM is not part of the first line.
        try { $giOld = $script:Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($giPath)) }
        catch { Say "$giPath cannot be read ($($_.Exception.Message)) -- init cannot make it ignore Claude Code's per-checkout files. Nothing was written."; exit 1 }
        $giHave = @(($giOld.TrimStart([char]0xFEFF) -split "`n") | ForEach-Object { $_.TrimEnd(' ', "`r") })
        $giMissing = @($giRules.Keys | Where-Object { $giKey = $_; @($giRules[$giKey] | Where-Object { $giHave -ccontains $_ }).Count -eq 0 })
        if ($giMissing.Count -gt 0) {
            # Opened for write and closed at once: nothing is written, the open itself is the question.
            try { [System.IO.File]::Open($giPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite).Dispose() }
            catch { Say "$giPath cannot be appended to ($($_.Exception.Message)) -- init cannot make it ignore Claude Code's per-checkout files. Nothing was written."; exit 1 }
        }
    }

    foreach ($f in $folders) { $null = [System.IO.Directory]::CreateDirectory((Join-Path $root (Join-Path '.mission' $f))) }
    foreach ($k in $files.Keys) {
        # LF and no BOM: a here-string carries this file's own line endings, so they are normalised here.
        $text = ([string]$files[$k]) -replace "`r`n", "`n"
        if ($text.Length -gt 0 -and -not $text.EndsWith("`n") -and $noFinalNewline -notcontains $k) { $text += "`n" }
        $full = Join-Path $root $k
        [System.IO.File]::WriteAllText($full, $text, $script:Utf8NoBom)
        Say ("  written  {0} ({1} bytes)" -f ($k -replace '\\', '/'), (Get-Item -LiteralPath $full).Length)
    }
    foreach ($f in $folders) { Say "  folder   .mission/$f/" }
    if ($null -eq $giOld) {
        $giText = $giComment + "`n" + ((@($giRules.Keys) | ForEach-Object { $_ + "`n" }) -join '')
        [System.IO.File]::WriteAllText($giPath, $giText, $script:Utf8NoBom)
        Say ("  .gitignore created: it ignores {0} ({1})" -f (@($giRules.Keys) -join ' and '), $giWhy)
    } else {
        # Decided above, before the first write; only the append is left.
        if ($giMissing.Count -eq 0) {
            Say ("  .gitignore unchanged: it already ignores {0}" -f (@($giRules.Keys) -join ' and '))
        } else {
            $giNl = $giOld.IndexOf("`n")
            $giEol = if (($giNl -gt 0) -and ($giOld[$giNl - 1] -eq [char]13)) { "`r`n" } else { "`n" }
            $giAdd = ''
            if (($giOld.Length -gt 0) -and -not $giOld.EndsWith("`n")) { $giAdd += $giEol }
            $giAdd += $giComment + $giEol + (($giMissing | ForEach-Object { $_ + $giEol }) -join '')
            $giBytes = $script:Utf8NoBom.GetBytes($giAdd)
            $giStream = [System.IO.File]::Open($giPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
            try { $giStream.Write($giBytes, 0, $giBytes.Length) } finally { $giStream.Dispose() }
            Say ("  .gitignore appended {0} rule(s): {1} ({2}); no line already there was changed" -f $giMissing.Count, ($giMissing -join ' and '), $giWhy)
        }
    }
    # UI-1 S1 (ADR-045): THE HOST REGISTRATION, after every refusal above, so a refused init writes nothing
    # anywhere. Register-MissionCheckout mints <home>/host-id once, appends this checkout's registry row unless
    # it has one, and makes .mission-runtime/telemetry/ -- the folder the emitter never makes. Then the first
    # mission_snapshot. A registration that cannot complete is said, and does not un-initialise the mission:
    # nothing in the mission depends on the feed.
    $tmI = Join-Path $PSScriptRoot 'tools\lam\mission-telemetry.ps1'
    if (Test-Path -LiteralPath $tmI -PathType Leaf) {
        try {
            . $tmI
            $regI = Register-MissionCheckout -Root $root
            Say ("  registered on this host: host_id {0}, {1} ({2})" -f $regI.host_id, $(if ($regI.row_added) { 'a row added to ' + $regI.registry } else { 'already a row in ' + $regI.registry }), 'the mission-event feed folder .mission-runtime/telemetry/ made')
            Invoke-MissionTelemetry -Root $root -Snapshot -Verb 'mission-init'
        } catch { Say "  registration on this host did not complete ($($_.Exception.Message)); the mission is initialised and nothing in it depends on the feed." }
    }
    Say "initialised an empty mission at $root (id $id). Next: mission.ps1 smoke -Target $root"
    exit 0
}

if ($Verb -eq 'register') {
    # UI-1 S1 (ADR-045): REGISTER AN EXISTING CHECKOUT ON THIS HOST -- a mission initialised before the feed
    # existed, or a worktree made by hand (git never brings the ignored telemetry folder along, and a worktree
    # is its own stream). The installer's step init runs: host-id once, this checkout's own registry row unless
    # it has one, the folder .mission-runtime/telemetry/; then the ignore rule init writes, appended to the
    # root .gitignore when no line already ignores the folder (a .mission-runtime/ line counts); then the
    # first snapshot. Nothing in the mission itself is written.
    $mfR = Join-Path $root '.mission\mission.yaml'
    if (-not (Test-Path -LiteralPath $mfR -PathType Leaf)) { Say "no mission at $root (no .mission/mission.yaml) -- run mission.ps1 init -Target first."; exit 1 }
    $tmR = Join-Path $PSScriptRoot 'tools\lam\mission-telemetry.ps1'
    if (-not (Test-Path -LiteralPath $tmR -PathType Leaf)) { Say "the registration step is not on disk at $tmR. Nothing was written."; exit 1 }
    . $tmR
    $regR = Register-MissionCheckout -Root $root
    # the line init prints for its own registration (RELEASE-4 S1, F-P7b; INSTALL.md section 7 gives it)
    Say ("registered on this host: host_id {0}, {1} ({2})" -f $regR.host_id, $(if ($regR.row_added) { 'a row added to ' + $regR.registry } else { 'already a row in ' + $regR.registry }), 'the mission-event feed folder .mission-runtime/telemetry/ made')
    $giR = Join-Path $root '.gitignore'
    # the rule init writes (F-P7a): the whole runtime plane
    $giHeld = @('/.mission-runtime/', '.mission-runtime/')
    $giText = if (Test-Path -LiteralPath $giR -PathType Leaf) { $script:Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($giR)) } else { $null }
    $giLinesR = if ($null -ne $giText) { @(($giText.TrimStart([char]0xFEFF) -split "`n") | ForEach-Object { $_.TrimEnd(' ', "`r") }) } else { @() }
    if (@($giHeld | Where-Object { $giLinesR -ccontains $_ }).Count -gt 0) { Say "  .gitignore unchanged: it already ignores /.mission-runtime/" }
    else {
        $giNlR = if ($null -ne $giText) { $giText.IndexOf("`n") } else { -1 }
        $giEolR = if (($giNlR -gt 0) -and ($giText[$giNlR - 1] -eq [char]13)) { "`r`n" } else { "`n" }
        $giAddR = ''
        if (($null -ne $giText) -and ($giText.Length -gt 0) -and -not $giText.EndsWith("`n")) { $giAddR += $giEolR }
        $giAddR += '# The runtime plane .mission-runtime/ (the mission-event feed, the evidence, LAM and HALT folders) is never committed (written by mission.ps1 register).' + $giEolR + '/.mission-runtime/' + $giEolR
        $giS = [System.IO.File]::Open($giR, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
        try { $giB = $script:Utf8NoBom.GetBytes($giAddR); $giS.Write($giB, 0, $giB.Length) } finally { $giS.Dispose() }
        Say "  .gitignore $(if ($null -eq $giText) { 'created' } else { 'appended 1 rule' }): /.mission-runtime/ (the runtime plane, never committed)"
    }
    Invoke-MissionTelemetry -Root $root -Snapshot -Verb 'mission-register'
    exit 0
}

# smoke
$evaluator = Join-Path $root 'tools\lam\mission-goal-check.ps1'
if (-not (Test-Path -LiteralPath $evaluator -PathType Leaf)) { Say "no evaluator at $evaluator -- run install.ps1 -Target first."; exit 1 }
if (-not (Test-Path -LiteralPath (Join-Path $root '.mission\goals\SMOKE-MISSION.yaml') -PathType Leaf)) { Say "no .mission/goals/SMOKE-MISSION.yaml under $root -- run mission.ps1 init first."; exit 1 }
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $evaluator -Goal SMOKE-MISSION -MissionRoot $root 2>&1)
    $code = $LASTEXITCODE
} finally { $ErrorActionPreference = $prev }
foreach ($line in $out) { [Console]::Out.WriteLine([string]$line) }
$verdictLine = @($out | ForEach-Object { [string]$_ } | Where-Object { $_ -like 'mission-goal-check: SMOKE-MISSION -> *' } | Select-Object -First 1)
if ($verdictLine.Count -eq 0) { Say "the evaluator printed no verdict line (exit $code)."; if ($code -eq 0) { exit 1 }; exit $code }
if ($code -eq 0 -and $verdictLine[0] -ceq 'mission-goal-check: SMOKE-MISSION -> MET') { Say 'smoke: MET'; exit 0 }
Say "smoke: NOT MET -- $($verdictLine[0]) (exit $code)"
if ($code -eq 0) { exit 1 }
exit $code
