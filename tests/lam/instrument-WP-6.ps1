#Requires -Version 5.1
<#
.SYNOPSIS
  LAM-ACCEPT WP-6 instrument -- the smoke mission at -SmokeRoot (S-1..S-5 + zero-paste). Without
  the parameter: LAM_SMOKE_ROOT; without that, the DEFAULT -- the smoke mission
  tools\lam\build-smoke-mission.ps1 builds, lam-smoke beside the PRIMARY checkout (else beside this
  checkout). There is no tracked fixture.

.DESCRIPTION
  THE EXIT CODE IS THE CONTRACT: 0 = no member failed, non-zero = the failure count. A member that
  SKIPPED is neither: exit 0 beside a skip is not "every member passed", and the count line, which
  names the skips, is what a reader must read.

  THIS INSTRUMENT DOES NOT RUN THE MISSION. The mission is run by the orchestrator (this session)
  using the WP-2 runner and the WP-4 gate tool; the instrument READS WHAT THE RUN LEFT ON DISK and
  judges it. That separation is the point: an instrument that performed the steps it grades would
  be grading its own work, and design SS4.5 law 5 is explicit that the test is an artifact too.

  IT IS READ-ONLY ON THE SMOKE REPO, WITH NO EXCEPTION -- AND THIS PARAGRAPH CLAIMED ONE UNTIL
  ROUND 18 (WP-6 review finding). It said the instrument drives the push guard with a synthesized PreToolUse
  payload. It does not, and had not for several rounds: that was the only PreToolUse in the file and
  the mechanism was removed. No real push is ever attempted from here either -- a real push is an
  operator act (design SS10.5), and S-4 is precisely the point at which this build stops and waits.

  WHY THAT SENTENCE MATTERED MORE THAN AN ORDINARY STALE COMMENT: it is what a validator reads to
  decide whether RUNNING this instrument mutates the plane it is grading, and round 3's validator
  declined to run it for exactly that reason. A file that overstates its own side effects gets
  skipped, and a skipped instrument measures nothing.

  ONE MEMBER PERFORMS WHAT IT GRADES, AND WHAT IT GRADES IS THE CLI, NOT THE MISSION (S-1b).
  The runner's pre-placement rests on a property of the CLI that only a real spawn shows, so S-1b clones
  the smoke repository into %TEMP%\s1b, drives the real runner and ONE real small-fast worker there,
  and deletes the clone. The smoke repo and its origin are only read, so READ-ONLY ON THE SMOKE REPO
  above still holds. Handed a LIVE smoke repository (the top level of a git work tree, a bare origin
  beside it, its supersession ratifications on disk), running this file costs one billed worker spawn,
  and leaves two pieces of the CLI's own state for that fixed fixture path, neither removed: its
  per-project directory under ~/.claude/projects, and a projects entry in the user's GLOBAL
  ~/.claude.json whose activeWorktreeSession names the worktree S-1b deletes. That entry persists, so
  every run after the first starts with the previous run's entry present. At a smoke root of FILES
  only -- a folder with no .git entry of its own -- S-1b SKIPs by name before the CLI is so much as
  looked up: no clone, no CLI call, no spawn. At a LIVE repository it cannot drive (git
  does not answer for it, no bare origin beside it, or no supersession ratification) it FAILS, and
  still before the CLI is looked up: nothing is spawned. S-1b's comment and detail say all of this.

  WHERE THE SMOKE ROOT CAN ONLY BE READ AS FILES, A MEMBER SKIPS BY NAME, NEVER FAILS FOR LOCATION.
  A root is FILES-ONLY when it exists and carries no .git entry (file or directory) of its own; a
  root WITH one is a LIVE repository, and its git rows are MEASURED -- a git that refuses or cannot
  answer there is a MISS, never a skip. A member whose clause needs the smoke repository's git (its
  commits, its origin, its hooks, its status) or its untracked runtime plane (.mission-runtime:
  evidence sessions, prompt registers, denial records) reads [SKIP] at a root that cannot answer, with
  the reason -- the root and what it lacks -- on its own face. A row that WAS measured and missed still
  fails the member: a measured miss outranks an unmeasurable row. A skip is not a pass, and the count
  line says so.

  STAGED BY DESIGN. Each member fails until its stage has actually happened, so running this
  mid-build reports honestly where the mission is rather than collapsing into one opaque failure.
#>
[CmdletBinding()]
param(
    [string]$SmokeRoot
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# THE SMOKE ROOT. -SmokeRoot IS THE LAW. Without it, LAM_SMOKE_ROOT -- the channel an acceptance
# wrapper uses, since Save-LamInstrumentRun launches every instrument with no argument. Without that,
# the DEFAULT: lam-smoke beside the PRIMARY checkout, where tools\lam\build-smoke-mission.ps1 builds the
# smoke mission by default. There is no tracked fixture: the smoke mission is a LIVE repository with a
# bare origin and a runtime plane, which no folder of tracked files can be, and the builder makes it
# after install. Value and source are printed; where nothing stands at the default the source says
# ABSENT and names the builder.
# THE DEFAULT IS THE SIBLING OF THE PRIMARY CHECKOUT, AS WP-3's IS. A linked worktree's own parent is
# <parent>\<repo>-worktrees, where no lam-smoke stands, so the default is anchored on the primary
# checkout (git's own answer, below), and the primary checkout and every linked worktree read the same
# mission. Only where git names no primary checkout -- a copy of this file outside any repository,
# which is what F-1's mirror arms are -- is it anchored on this checkout. The source line says which.
# NO `-OriginPath` PARAMETER WAS ADDED, deliberately: PS 5.1 folds variable-name case, so a
# parameter `$OriginPath` and the `$originPath` this file already uses everywhere would be ONE
# variable, and the parameter would be silently overwritten by the assignment below it.
function Get-PrimaryCheckoutRoot {
    # The PRIMARY checkout of this repository, from anywhere inside it -- WP-3's derivation, mirrored.
    # `git worktree list --porcelain` names the primary FIRST and always absolutely; `rev-parse
    # --git-common-dir` is the fallback and can come back RELATIVE (it does, in the primary itself),
    # so it is rooted against $From before its parent is taken. Outside any repository: ''.
    param([string]$From)
    $root = ''
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $wl = & git -C $From worktree list --porcelain 2>&1
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in @($wl)) {
                if ("$line" -match '^worktree\s+(.+?)\s*$') { $root = $Matches[1]; break }
            }
        }
        if (-not $root) {
            $cd = & git -C $From rev-parse --git-common-dir 2>&1
            if ($LASTEXITCODE -eq 0 -and ("$cd").Trim()) {
                $cdp = ("$cd").Trim()
                if (-not [System.IO.Path]::IsPathRooted($cdp)) { $cdp = Join-Path $From $cdp }
                $root = Split-Path -Parent $cdp
            }
        }
    } finally { $ErrorActionPreference = $prevEap }
    if ($root -and (Test-Path -LiteralPath $root)) { return (Resolve-Path -LiteralPath $root).Path }
    return ''
}
$primaryRoot   = Get-PrimaryCheckoutRoot -From $repoRoot
$smokeAnchor   = if ($primaryRoot) { $primaryRoot } else { $repoRoot }
$smokeAnchorIs = if ($primaryRoot) { "the primary checkout $smokeAnchor" } else { "this checkout $smokeAnchor (git names no primary checkout for it)" }
$smokeDefault  = Join-Path (Split-Path -Parent $smokeAnchor) 'lam-smoke'
$smokeEnv      = [Environment]::GetEnvironmentVariable('LAM_SMOKE_ROOT')
if ($SmokeRoot) {
    $smokeSource = 'parameter -SmokeRoot'
} elseif ($smokeEnv) {
    $SmokeRoot   = $smokeEnv
    $smokeSource = 'environment LAM_SMOKE_ROOT'
} elseif (Test-Path -LiteralPath $smokeDefault -PathType Container) {
    $SmokeRoot   = $smokeDefault
    $smokeSource = "default -- the smoke mission beside $smokeAnchorIs"
} else {
    $SmokeRoot   = $smokeDefault
    $smokeSource = "default -- ABSENT: no smoke mission beside $smokeAnchorIs (tools\lam\build-smoke-mission.ps1 builds one there; -SmokeRoot or LAM_SMOKE_ROOT names another)"
}
$SmokeRoot  = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SmokeRoot).TrimEnd('\')
# THE ORIGIN ANCHOR IS BESIDE THE SMOKE ROOT, however the root was reached -- where the smoke mission's
# push gate declares it (origin_url: ../lam-smoke-origin.git). -SmokeRoot is therefore a COMPLETE
# override: it once rebound the smoke root alone while the origin stayed on the script's parent, and
# no argument could make this file whole away from that directory (F-1's override row pins the cure).
# For the DEFAULT this is the origin beside the sibling the source line names.
$originPath = Join-Path (Split-Path -Parent $SmokeRoot) 'lam-smoke-origin.git'
# `$guard` WAS ASSIGNED HERE AND NEVER USED (V-1 round 18, WP-6 review finding). It was the last trace of
# the removed PreToolUse mechanism the description above used to advertise. E99: dead code is wired
# or dropped, and a variable nobody reads is a claim about a capability this file does not have.

# THE GATE-CLASS MAP, dot-sourced rather than restated. mission-gate.ps1
# writes the class from this same file; a second copy here is exactly the defect that let the
# halt_absent regex disagree with itself inside one run.
$gateClassLib = Join-Path $repoRoot 'tools\lam\lam-gate-class.ps1'
if (-not (Test-Path -LiteralPath $gateClassLib)) {
    Write-Host "WP-6: the gate-class map is missing at $gateClassLib -- the zero-paste attestation cannot count by class."
    Write-Host "EXIT: 1"
    exit 1
}
. $gateClassLib

$failures  = 0
$checksRun = 0
$skips     = 0
function Check {
    # -Skipped: a member whose clause could not be MEASURED at this smoke root. Never a pass, never a
    # failure; the face reads [SKIP] and the summary withholds the word "all". The shape is WP-3's.
    # (The counter is $skips, not $skipped: PS 5.1 folds variable case, so a $skipped counter and
    #  this $Skipped parameter would be one and the same name inside this function.)
    param([string]$Id, [string]$Title, [bool]$Ok, [string]$Detail, [switch]$Skipped)
    $script:checksRun++
    $tag = if ($Skipped) { 'SKIP' } elseif ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ""
    Write-Host "[$tag] $Id -- $Title"
    if ($Detail) { Write-Host $Detail }
    if ($Skipped) { $script:skips++ }
    elseif (-not $Ok) { $script:failures++ }
}
function Write-Wp6Member {
    # A ROW IS $true (ok), $false (MISS) or a non-empty [string] (SKIP, the string its reason). A
    # MEASURED MISS OUTRANKS AN UNMEASURABLE ROW: the member SKIPs only when every row that could be
    # measured is ok, and the reason rides on its own face, not only in the detail, so a skip cannot be
    # read as a pass by anyone skimming the [TAG] column. An empty string is a MISS, never a skip.
    param([string]$Id, [string]$Title, [System.Collections.Specialized.OrderedDictionary]$Rows, [string]$Tail)
    $wmDetail = ''; $wmMiss = 0; $wmWhy = @()
    foreach ($wmKey in $Rows.Keys) {
        $wmVal = $Rows[$wmKey]
        if (($wmVal -is [string]) -and $wmVal) {
            $wmDetail += "    [SKIP] $wmKey -- $wmVal`n"
            if ($wmWhy -notcontains $wmVal) { $wmWhy += $wmVal }
        }
        elseif (($wmVal -isnot [string]) -and $wmVal) { $wmDetail += "    [ok  ] $wmKey`n" }
        else { $wmDetail += "    [MISS] $wmKey`n"; $wmMiss++ }
    }
    if ($Tail) { $wmDetail += $Tail }
    if (($wmWhy.Count -gt 0) -and ($wmMiss -eq 0)) {
        $wmReason = $wmWhy -join ' ; '
        Check -Id $Id -Title ($Title + '   [SKIPPED -- ' + $wmReason + ']') -Ok $false -Skipped -Detail ("    SKIPPED: $wmReason`n" + $wmDetail.TrimEnd())
    } else {
        Check -Id $Id -Title $Title -Ok ($wmMiss -eq 0) -Detail $wmDetail.TrimEnd()
    }
}
function ReadText { param([string]$P) if (Test-Path -LiteralPath $P) { return [System.IO.File]::ReadAllText($P) } return '' }
function Test-Wp6H3Applied {
    # F-H9 (RELEASE-4 S2; row 495 (8)): THE H-3 ROW READS THE PATCH's CODE, NEVER ITS COMMENTARY. In 1.0.0 F-0 matched
    # '.mission/evidence/session-' anywhere in tools/mission-lib.ps1, and the only lines that matched were COMMENTS (the D9
    # exemption itself dropped from the code, the comment explaining why left): the row passed on prose. The H-3 patch
    # (tools/evidence-hooks-next/patches/clean-tree-exemption.patch) installs the admitted-porcelain reader; the row is
    # its two calls, on code lines -- '<# ... #>' blocks and '#' lines removed before anything is read.
    param([AllowNull()][string]$Text)
    if (-not $Text) { return $false }
    $t = [regex]::Replace(($Text -replace "`r`n", "`n"), '(?s)<#.*?#>', '')
    $code = @($t -split "`n" | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') })
    $porc = @($code | Where-Object { $_ -match '\bGet-LamPorcelainState\s+-MissionRoot\b' }).Count
    $decl = @($code | Where-Object { $_ -match '\bGet-LamDeclaredAdmittedPorcelain\s+-MissionRoot\b' }).Count
    return (($porc -ge 1) -and ($decl -ge 1))
}
function Get-LfBasisSha256 {
    # THE LF/BLOB BASIS, WHICH IS ALREADY THIS REPOSITORY'S UNIT FOR EVERY FILE TABLE. F-0 compared
    # two checkouts BYTE FOR BYTE, and the two differ by EOL normalisation alone: the repository of
    # record holds docs\framework\evidence-manifest.schema.json LF (30300 B, 0 CR) and a CRLF
    # checkout holds the same content CRLF (30534 B, 234 CR). The predicate therefore MISSED from
    # every CRLF worktree even with the fixture fully present and correct -- a property of the
    # checkout, not of the fixture. CRLF is collapsed to LF on BOTH sides before hashing.
    # THE COMPARISON STAYS REAL: only the CR of a CRLF pair is dropped, so a lone CR and every other
    # byte still count, and a fixture whose CONTENT differs still misses. F-1's arm X is that control.
    param([string]$P)
    $raw = [System.IO.File]::ReadAllBytes($P)
    $buf = New-Object 'System.Collections.Generic.List[byte]'
    for ($i = 0; $i -lt $raw.Length; $i++) {
        if (($raw[$i] -eq 13) -and (($i + 1) -lt $raw.Length) -and ($raw[$i + 1] -eq 10)) { continue }
        $buf.Add($raw[$i])
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($buf.ToArray()) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}
function Get-RawSha256 {
    param([string]$P)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([System.IO.File]::ReadAllBytes($P)) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}
function Get-FoldRuleSha256 {
    # FRAMEWORK.LOCK'S FOLD RULE (its header's eol_rule, fold-crlf-text) -- the rule install.ps1, -Verify and the lock
    # judge every installed file by: a file holding no 0x00 byte is TEXT and is hashed on the basis above, every CR LF
    # made LF; a file holding one is BINARY and is hashed raw. S-4b judges the decider by it ACROSS CHECKOUTS, where
    # the decider the smoke mission's wrapper names and the one this checkout ships are two files.
    param([string]$P)
    if ([Array]::IndexOf([System.IO.File]::ReadAllBytes($P), [byte]0) -lt 0) { return (Get-LfBasisSha256 -P $P) }
    return (Get-RawSha256 -P $P)
}
function GitOut {
    param([string]$Root, [string[]]$Argv)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $o = & git -C $Root @Argv 2>&1; return [pscustomobject]@{ out = ("$o").Trim(); exit = $LASTEXITCODE } }
    finally { $ErrorActionPreference = $prev }
}

function GitStdout {
    # STDOUT ONLY, stderr kept apart. GitOut merges stderr into .out (2>&1), and the classification
    # below once read its probe that way: ONE stderr line -- a warning, a dubious-ownership refusal --
    # was enough to turn `true` into something else, a LIVE smoke repository was classified files-only,
    # and every git row of it then SKIPPED instead of failing. .err is for the banner, never a verdict.
    param([string]$Root, [string[]]$Argv)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $all = @(& git -C $Root @Argv 2>&1); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prev }
    $outL = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
    $errL = @($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    return [pscustomobject]@{ out = ($outL -join "`n").Trim(); err = ($errL -join ' | '); exit = $code }
}

# WHAT THE SMOKE ROOT IS, decided by the FILESYSTEM, not by whether git happens to answer. A root that
# exists and has NO `.git` entry of its own (file or directory) is FILES-ONLY -- a folder of copied
# files -- and only there may a member SKIP for "not a git work tree". A root WITH one is a
# LIVE repository: its git rows are MEASURED, and a git that refuses or cannot answer there (an exit
# 128, a dubious-ownership refusal) is a MISS, never a skip. An ABSENT root is neither, and is measured.
# git is still ASKED about a live root only where it answers, on STDOUT, that the root IS THE TOP LEVEL
# OF ITS WORK TREE: below one `git -C` discovers the ENCLOSING repository and answers for it -- its
# origin, HEAD, hooks and status -- and a member reading that would grade the framework, not the smoke
# mission. `--is-inside-work-tree --show-cdup` prints exactly `true` at a top level, `true` plus a ../
# chain below one, `false` in a bare repository, and exits non-zero outside any repository. Where a live
# root does not answer so, its git rows are not asked and read MISS, with git's own words in the banner.
$smokeExists    = Test-Path -LiteralPath $SmokeRoot -PathType Container
$smokeGitEntry  = Join-Path $SmokeRoot '.git'
$smokeGitKind   = ''
if ($smokeExists -and (Test-Path -LiteralPath $smokeGitEntry)) {
    $smokeGitKind = $(if (Test-Path -LiteralPath $smokeGitEntry -PathType Container) { 'directory' } else { 'file' })
}
$smokeIsFilesOnly = $smokeExists -and (-not $smokeGitKind)
$smokeIsLive      = $smokeExists -and [bool]$smokeGitKind
$smokeTop      = [pscustomobject]@{ out = ''; err = ''; exit = -1 }
$smokeTopLevel = [pscustomobject]@{ out = ''; err = ''; exit = -1 }
if ($smokeExists) {
    $smokeTop      = GitStdout -Root $SmokeRoot -Argv @('rev-parse', '--is-inside-work-tree', '--show-cdup')
    $smokeTopLevel = GitStdout -Root $SmokeRoot -Argv @('rev-parse', '--show-toplevel')
}
$smokeIsRepoTop = $smokeIsLive -and ($smokeTop.exit -eq 0) -and ($smokeTop.out -ceq 'true')
$originIsBare = $false
if (Test-Path -LiteralPath $originPath -PathType Container) {
    $originBareProbe = GitStdout -Root $originPath -Argv @('rev-parse', '--is-bare-repository')
    $originIsBare = ($originBareProbe.exit -eq 0) -and ($originBareProbe.out -ceq 'true')
}
$smokePlane      = $smokeExists -and (Test-Path -LiteralPath (Join-Path $SmokeRoot '.mission-runtime') -PathType Container)
$smokeGitSaid    = "git, asked from there, on stdout: top level $(if ($smokeTopLevel.out) { $smokeTopLevel.out } else { '(none)' }), is-inside-work-tree/show-cdup '$($smokeTop.out -replace "`n", ' ')', exit $($smokeTop.exit)$(if ($smokeTop.err) { '; on stderr: ' + $smokeTop.err })"
$smokeNotRepoWhy = "the smoke root $SmokeRoot has no .git entry of its own -- a root of tracked FILES, not a git work tree; members needing the smoke repository's git are not asked it"
$smokeLiveGitWhy = "the smoke root $SmokeRoot is a LIVE repository (its .git is a $smokeGitKind) but git does not answer that it is the top level of a work tree ($smokeGitSaid)"
$smokeNoPlaneWhy = "the smoke root $SmokeRoot holds no .mission-runtime -- untracked runtime state (evidence sessions, prompt registers, denial records) a folder of copied files does not carry"

Write-Host "=============================================================================="
Write-Host " LAM WP-6 INSTRUMENT -- smoke mission"
Write-Host "=============================================================================="
# THE TWO LINES F-1 READS STAY BYTE-IDENTICAL; the three after them carry labels F-1's `^<label>\s*:`
# reader cannot take for either ("smoke source" is not "smoke repo", and "origin source" has a word
# between "origin" and its colon).
Write-Host "smoke repo : $SmokeRoot"
Write-Host "origin     : $originPath"
Write-Host "smoke source: $smokeSource"
Write-Host ("origin source: beside the smoke root -- " + $(if ($originIsBare) { 'a bare repository' } elseif (Test-Path -LiteralPath $originPath) { 'present, NOT a bare repository' } else { 'ABSENT' }))
# WHICH OF THE THREE CASES APPLIES, AND WHY, on one line: ABSENT; FILES-ONLY (no .git entry -- the only
# case in which a git row may SKIP); LIVE (a .git entry -- git rows measured, asked only where git says
# the root is its work tree's top level, and MISS where it does not).
$smokeReach = $(if (-not $smokeExists) { 'ABSENT -- every member is measured against nothing, and misses' }
                elseif ($smokeIsFilesOnly) { "FILES-ONLY -- no .git entry at $smokeGitEntry, so members needing the smoke repository's git SKIP by name ($smokeGitSaid)" }
                elseif ($smokeIsRepoTop) { "LIVE REPOSITORY -- its .git is a $smokeGitKind and git answers that the root is the top level of its work tree: git is asked, and its rows are MEASURED ($smokeGitSaid)" }
                else { "LIVE REPOSITORY -- its .git is a $smokeGitKind but git does NOT answer that the root is the top level of a work tree: its git rows are MEASURED and MISS, never skipped ($smokeGitSaid)" })
Write-Host ("smoke reach: " + $smokeReach + "; runtime plane $(if ($smokePlane) { 'present' } else { 'absent' })")

$missionDir  = Join-Path $SmokeRoot '.mission'
$dispatchDir = Join-Path $missionDir 'dispatches'
$valDir      = Join-Path $missionDir 'validator-results'
$gatesDir    = Join-Path $missionDir 'gates'
$evRootBase  = Join-Path $SmokeRoot '.mission-runtime\evidence'

# =============================================================================================
# F-0 -- the smoke mission is set up as WP-6's preamble describes it
# =============================================================================================
$smokeSettings = Join-Path $SmokeRoot '.claude\settings.local.json'
$settingsText  = ReadText $smokeSettings
$schemaCopy    = Join-Path $SmokeRoot 'docs\framework\evidence-manifest.schema.json'
$schemaSrc     = Join-Path $repoRoot 'docs\framework\evidence-manifest.schema.json'
$schemaMatch = $false
$schemaBasis = '    schema compare basis: files absent'
if ((Test-Path -LiteralPath $schemaCopy) -and (Test-Path -LiteralPath $schemaSrc)) {
    $schemaCopyLf = Get-LfBasisSha256 -P $schemaCopy
    $schemaSrcLf  = Get-LfBasisSha256 -P $schemaSrc
    $schemaMatch  = ($schemaCopyLf -ceq $schemaSrcLf)
    $schemaBasis  = "    schema compare basis: CRLF collapsed to LF on both sides (see Get-LfBasisSha256)`n" +
                    "      fixture copy  : $($schemaCopyLf.Substring(0,16))  ($((Get-Item -LiteralPath $schemaCopy).Length) B on disk)`n" +
                    "      checkout copy : $($schemaSrcLf.Substring(0,16))  ($((Get-Item -LiteralPath $schemaSrc).Length) B on disk)"
}
# ASKED ONLY OF A TOP-LEVEL WORK TREE: below one, git answers with the enclosing repository's origin.
# A LIVE root git does not answer for is not asked either, and its row MISSES (below), never skips.
$originRemoteGot = if ($smokeIsRepoTop) { GitStdout -Root $SmokeRoot -Argv @('remote','get-url','origin') } else { $null }
$originRemote    = if ($originRemoteGot -and ($originRemoteGot.exit -eq 0)) { $originRemoteGot.out } else { '' }
$specText     = ReadText (Join-Path $missionDir 'spec\current.txt')
$assertions   = @()
if (Test-Path -LiteralPath (Join-Path $missionDir 'contract\assertions')) {
    $assertions = @(Get-ChildItem -LiteralPath (Join-Path $missionDir 'contract\assertions') -File -Filter '*.yaml' -ErrorAction SilentlyContinue)
}
$patchApplied = Test-Wp6H3Applied -Text (ReadText (Join-Path $SmokeRoot 'tools\mission-lib.ps1'))

# THE TWO GIT ROWS SKIP ONLY AT A FILES-ONLY ROOT (no .git entry: a folder of copied files). At a LIVE
# repository they are measured, and a git that cannot answer there MISSES them; an ABSENT root still
# MISSES them, so F-1's arm B, which has no smoke root at all, stays red.
$f0 = [ordered]@{
    'smoke repo is a git repo'                 = $(if ($smokeIsFilesOnly) { $smokeNotRepoWhy } else { [bool]$smokeIsRepoTop })
    'origin points at the bare lam-smoke-origin' = $(if ($smokeIsFilesOnly) { $smokeNotRepoWhy } else { [bool]($originRemote -match 'lam-smoke-origin') })
    'next-gen hooks registered in settings.local.json' = [bool]($settingsText -match 'evidence-hooks-next')
    'manifest schema copied, identical on the LF basis' = [bool]$schemaMatch
    'H-3 clean-tree patch applied here'        = [bool]$patchApplied
    'five contract assertions'                 = ($assertions.Count -eq 5)
}
Write-Wp6Member -Id 'F-0' -Title 'the smoke mission is set up as WP-6 describes' -Rows $f0 `
    -Tail ("    origin url: $(if ($originRemoteGot) { $(if ($originRemote) { $originRemote } else { "(none -- git remote get-url origin exit $($originRemoteGot.exit))" }) } elseif ($smokeIsLive) { "(not asked: $smokeLiveGitWhy)" } else { '(not asked)' })`n    assertions found: $($assertions.Count)`n$schemaBasis")

# =============================================================================================
# F-1 -- F-0'S OWN PRECONDITION CLASS: THIS INSTRUMENT'S FIXTURE ANCHORS ARE RESOLVED FROM WHERE
#        THE FILE SITS, so its verdict is a function of LOCATION and not only of the commit.
#
# WHY THIS MEMBER EXISTS. An earlier ruling set WP-6's failures aside as "a different and
# settled case ... one absent fixture and eight members that depend on it, which is a missing
# fixture rather than a defect, and unlike the other two it does not vary between runs". THE LAST
# CLAUSE IS FALSE, and this member is the measurement that says so. The resolution block at the head
# of this file anchored BOTH fixtures on `Split-Path -Parent $repoRoot`, and `$repoRoot` comes from
# `$PSScriptRoot` -- the SCRIPT's own location, not the caller's cwd. The same bytes at the same commit
# returned a different verdict from a different directory, which IS varying between runs. (The DEFAULT
# is still location-anchored: on the PRIMARY checkout's parent, and on `$repoRoot`'s parent only
# where git names no primary checkout -- which is where every mirror arm below sits, under %TEMP%
# outside any repository, so an arm's DEFAULT is the sibling beside its own mirror.)
#
# A MEMBER THAT MERELY ASSERTED "THE FIXTURE IS ABSENT" WOULD BE A BARE REFUSAL. It would pass
# vacuously everywhere the fixture is absent, which is everywhere this suite has ever run. So this
# member drives TWO MIRRORS OF ITSELF that differ in ONE WAY ONLY -- where they sit -- and requires
# their F-0 verdicts to DISAGREE. An arm that comes back inverted (A red or B green) means the
# APPARATUS produced the answer rather than the property; that VOIDS the run, and it is reported
# here as a failing row and a named note, never quietly absorbed.
#
# AND THE LOCATION DEPENDENCE IS NOW THE DEFAULT'S, AND IT NAMES ITSELF. There is no tracked fixture:
# the DEFAULT is the smoke mission the builder makes beside the PRIMARY checkout, so the primary checkout
# and every linked worktree read the same mission, and the banner says DEFAULT, or DEFAULT -- ABSENT where
# nothing stands there. Arms A and B still disagree, through the DEFAULT, by name. Arm D carries, INSIDE
# its mirror, a stale tests\lam\fixtures\lam-smoke folder planted with every file F-0 reads, AND a
# sibling: the sibling is read and the folder never is, so no checkout can steer this file back to a
# copy of files. The same folder, handed over as -SmokeRoot (run D+files), is a FILES-ONLY root, where
# F-0's git rows and S-1b SKIP by name. LAM_SMOKE_ROOT, the acceptance wrapper's channel, is CLEARED for
# every arm (an inherited channel would make every arm read one root) and handed to one arm on purpose,
# so the second channel is exercised, not assumed.
#
# IT ALSO PINS THE TWO CURES OF AN EARLIER ROUND, because both are claims about resolution:
#   (a) `-SmokeRoot` IS A COMPLETE OVERRIDE. Before the cure, the origin line ignored it: the smoke
#       root moved and the origin stayed behind, so NO argument could make this file whole from the
#       fixture's parent. docs/framework/LAM-ACCEPT.md:5211 had already recorded that WP-6 cannot be
#       run whole from a mirror; the acceptance run needs it to be, and a half-honoured override is
#       the reason it could not. The row drives arm B with arm A's smoke root and reads the banner.
#   (b) F-0'S SCHEMA PREDICATE COMPARED TWO CHECKOUTS BYTE-FOR-BYTE, and the two differ only in EOL
#       normalisation: the repository of record holds that file LF, a CRLF checkout holds it CRLF
#       (measured at this tip -- 30300 B / 0 CR against 30534 B / 234 CR, identical once collapsed).
#       The predicate therefore MISSED from every CRLF worktree even with the fixture fully present.
#       It is now taken on the LF basis this repository already uses for every file table. It stays
#       a REAL comparison: arm X plants a schema whose CONTENT genuinely differs and requires a MISS.
#
# COST: ZERO BILLED WORKER SPAWNS. No arm's smoke root is a smoke repository S-1b can drive -- none
# carries the supersession ratifications S-1b copies -- so S-1b's own guard stops it in every arm before
# the CLI is looked up: it SKIPs where the root is ABSENT (B) or FILES-ONLY (D+files), and FAILS, saying
# nothing was spawned, where the root is a LIVE repository it cannot drive (A, D, E, X, and B handed A's
# root). Two rows assert it, read off the arms' output, not trusted: every arm's S-1b block carries the
# guard's NOTHING WAS RUN line, and the guard's three answers land where they belong. `claude` is also
# still filtered off each child's PATH, as a second fence behind that guard.
#
# DISCLOSED APPARATUS ARTIFACT, NOT HIDDEN: S-4d fails in EVERY mirror arm, because a minimal mirror
# does not carry tools\evidence-hooks-next\hooks\lib\evidence-common.ps1, which S-4d dot-sources
# relative to $repoRoot. S-4d is therefore NOT in the compared set -- only F-0's verdict, F-0's
# schema predicate, the banner and S-1b's face are ever read from an arm, and the note below prints
# S-4d's arm verdicts so the exclusion is visible rather than asserted. Saying which rows an apparatus cannot speak for is the
# point of having one.
#
# DELIBERATELY NOT UNDER StrictMode: each arm is a BYTE COPY of this file, so each child runs the
# production shape exactly. Adding StrictMode to the arms would make them diverge from what ships,
# which is the defect a probe is supposed to catch, not commit.
# =============================================================================================
$f1Arm = [Environment]::GetEnvironmentVariable('LAM_WP6_F1_ARM')
if ($f1Arm) {
    Write-Host ""
    Write-Host "[----] F-1 -- SUPPRESSED: this run is F-1 arm '$f1Arm'. An arm that drove arms of its own would not terminate."
} else {

function New-F1Text {
    param([string]$Path, [string]$Text)
    $dirPart = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dirPart)) { $null = New-Item -ItemType Directory -Path $dirPart -Force }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}
function Invoke-F1Git {
    # EVERY native call in this member goes through here. Under PS 5.1 with EAP 'Stop', ANY stderr
    # byte from a native exe is a fatal NativeCommandError and `2>$null` does not help, so the
    # preference is lowered around the call and restored in `finally`.
    param([string[]]$Argv)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $o = & git @Argv 2>&1
        return [pscustomobject]@{ out = ((@($o) | ForEach-Object { "$_" }) -join ' ').Trim(); exit = $LASTEXITCODE }
    } finally { $ErrorActionPreference = $prevEap }
}
function New-F1SmokeFiles {
    # THE FILES F-0 READS, planted under -Dir: the settings naming the next-gen hooks, the H-3 marker,
    # five contract assertions and the schema in the mode asked for. One planting for both places an
    # arm can carry them -- the git-init'd sibling and the tracked-fixture folder inside the mirror.
    param([string]$Dir, [string]$SchemaMode, [byte[]]$SrcBytes)
    New-F1Text -Path (Join-Path $Dir '.claude\settings.local.json') -Text '{ "hooks": "tools/evidence-hooks-next/hooks/pre-tool-use.ps1" }'
    New-F1Text -Path (Join-Path $Dir 'tools\mission-lib.ps1') -Text "# F-1 fixture stub -- carries, as CODE, the H-3 patch's calls F-0 reads (Test-Wp6H3Applied):`n`$porc = Get-LamPorcelainState -MissionRoot `$Root`n`$decl = Get-LamDeclaredAdmittedPorcelain -MissionRoot `$Root`n"
    foreach ($n in 1..5) { New-F1Text -Path (Join-Path $Dir ".mission\contract\assertions\a$n.yaml") -Text "id: a$n`n" }
    $fSchema = Join-Path $Dir 'docs\framework\evidence-manifest.schema.json'
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $fSchema) -Force
    $txt = [System.Text.Encoding]::UTF8.GetString($SrcBytes)
    if ($SchemaMode -ceq 'bytecopy') {
        [System.IO.File]::WriteAllBytes($fSchema, $SrcBytes)
    } elseif ($SchemaMode -ceq 'lf') {
        # SAME CONTENT, DIFFERENT EOL -- exactly the relation between the repository of record
        # and a CRLF checkout. This arm is the one the second cure has to move.
        [System.IO.File]::WriteAllBytes($fSchema, [System.Text.Encoding]::UTF8.GetBytes(($txt -replace "`r`n", "`n")))
    } else {
        # GENUINELY DIFFERENT CONTENT -- the control that keeps the cure from degrading the
        # predicate into something that accepts anything.
        [System.IO.File]::WriteAllBytes($fSchema, [System.Text.Encoding]::UTF8.GetBytes(($txt -replace "`r`n", "`n") + "GENUINELY-DIFFERENT-CONTENT`n"))
    }
    if (-not (Test-Path -LiteralPath $fSchema)) { throw "fixture schema not placed under $Dir" }
}
function New-F1Arm {
    # An arm is a MINIMAL MIRROR (`r\`) plus, optionally, the two fixture siblings BESIDE it, and,
    # optionally, a stale folder of files at tests\lam\fixtures\lam-smoke INSIDE it (arm D). The
    # mirror carries only what this instrument needs to start: itself, the gate-class map it
    # dot-sources, and the schema F-0 compares against.
    param([string]$Name, [bool]$WithFixture, [string]$SchemaMode, [bool]$InRepoFixture = $false)
    $armRoot = Join-Path $f1Root $Name
    $mirror  = Join-Path $armRoot 'r'
    foreach ($sub in @('tests\lam', 'tools\lam', 'docs\framework')) {
        $null = New-Item -ItemType Directory -Path (Join-Path $mirror $sub) -Force
    }
    $mInstr  = Join-Path $mirror 'tests\lam\instrument-WP-6.ps1'
    $mGate   = Join-Path $mirror 'tools\lam\lam-gate-class.ps1'
    $mSchema = Join-Path $mirror 'docs\framework\evidence-manifest.schema.json'
    Copy-Item -LiteralPath $PSCommandPath -Destination $mInstr  -Force
    Copy-Item -LiteralPath $gateClassLib  -Destination $mGate   -Force
    Copy-Item -LiteralPath $schemaSrc     -Destination $mSchema -Force
    # ARITY AT EVERY PLANE-CROSSING COPY: a copy that silently places nothing would make every arm
    # agree for the wrong reason, and this member's whole claim is that two arms DISAGREE.
    $placedProbe = @($mInstr, $mGate, $mSchema)
    $placed = @($placedProbe | Where-Object { Test-Path -LiteralPath $_ })
    if ($placed.Count -ne 3) { throw "arm ${Name}: expected 3 mirror files placed, found $($placed.Count)" }

    if ($WithFixture) {
        $originDir = Join-Path $armRoot 'lam-smoke-origin.git'
        $smokeDir  = Join-Path $armRoot 'lam-smoke'
        # THE DIRECTORY IS CREATED BEFORE `git -C` EVER NAMES IT. A `git -C` into a directory that
        # does not exist walks UP and has written through to a host .git/config here before.
        $null = New-Item -ItemType Directory -Path $originDir -Force
        $null = New-Item -ItemType Directory -Path $smokeDir  -Force
        $gi1 = Invoke-F1Git -Argv @('-c','init.defaultBranch=main','-C',$originDir,'init','--bare','--quiet')
        $gi2 = Invoke-F1Git -Argv @('-c','init.defaultBranch=main','-C',$smokeDir,'init','--quiet')
        if (-not (Test-Path -LiteralPath (Join-Path $originDir 'HEAD'))) { throw "arm ${Name}: bare origin init left no HEAD (exit $($gi1.exit)) $($gi1.out)" }
        if (-not (Test-Path -LiteralPath (Join-Path $smokeDir '.git'))) { throw "arm ${Name}: smoke init created no .git (exit $($gi2.exit)) $($gi2.out)" }
        # FORWARD SLASHES in a scratch remote url: a backslash here has corrupted a whole repo's config.
        $gi3 = Invoke-F1Git -Argv @('-C',$smokeDir,'remote','add','origin','../lam-smoke-origin.git')
        if ($gi3.exit -ne 0) { throw "arm ${Name}: remote add failed (exit $($gi3.exit)) $($gi3.out)" }

        New-F1SmokeFiles -Dir $smokeDir -SchemaMode $SchemaMode -SrcBytes ([System.IO.File]::ReadAllBytes($mSchema))
    }
    $inRepo = Join-Path $mirror 'tests\lam\fixtures\lam-smoke'
    if ($InRepoFixture) {
        # A STALE FOLDER OF FILES, IN THE MIRROR, where the tracked fixture once stood: no repository of its
        # own, every file F-0 reads. Byte-copied schema, so its F-0 rows that CAN be measured are all ok.
        New-F1SmokeFiles -Dir $inRepo -SchemaMode 'bytecopy' -SrcBytes ([System.IO.File]::ReadAllBytes($mSchema))
        if (-not (Test-Path -LiteralPath (Join-Path $inRepo '.claude\settings.local.json'))) { throw "arm ${Name}: the in-mirror fixture was not placed" }
    }
    return [pscustomobject]@{ Name = $Name; Root = $armRoot; Script = $mInstr; Smoke = (Join-Path $armRoot 'lam-smoke'); InRepo = $inRepo }
}
function Invoke-F1Child {
    # -SmokeEnv: the value LAM_SMOKE_ROOT carries into the child; empty CLEARS it. The channel is set for
    # every arm, never inherited -- an acceptance wrapper that set it for this run would otherwise make
    # every arm read one root, and the arms' disagreement would be the wrapper's, not the property's.
    param([string]$Script, [string]$Arm, [string[]]$ExtraArgs, [string]$SmokeEnv = '')
    $prevPath = $env:PATH
    $prevArm  = [Environment]::GetEnvironmentVariable('LAM_WP6_F1_ARM')
    $prevSmokeEnv = [Environment]::GetEnvironmentVariable('LAM_SMOKE_ROOT')
    $kept = @(@($prevPath -split ';') | Where-Object { $_ -and ($_ -notmatch '\\\.local\\bin\\?$') })
    $lines = @()
    $code  = -1
    try {
        $env:PATH = ($kept -join ';')
        $env:LAM_WP6_F1_ARM = $Arm
        [Environment]::SetEnvironmentVariable('LAM_SMOKE_ROOT', $(if ($SmokeEnv) { $SmokeEnv } else { $null }))
        $argv = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Script)
        if ($ExtraArgs -and (@($ExtraArgs).Count -gt 0)) { $argv = @(@($argv) + @($ExtraArgs)) }
        if ($argv.Count -lt 5) { throw "arm ${Arm}: the child argument vector collapsed to $($argv.Count) elements" }
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $o = & powershell.exe @argv 2>&1
            $lines = @(@($o) | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prevEap }
    } finally {
        $env:PATH = $prevPath
        if ($null -eq $prevArm) { Remove-Item Env:\LAM_WP6_F1_ARM -ErrorAction SilentlyContinue }
        else { $env:LAM_WP6_F1_ARM = $prevArm }
        [Environment]::SetEnvironmentVariable('LAM_SMOKE_ROOT', $prevSmokeEnv)
    }
    return [pscustomobject]@{ Lines = $lines; Exit = $code }
}
function Get-F1Verdict {
    param([string[]]$Lines, [string]$Id)
    $rx  = '^\[(PASS|FAIL|SKIP)\] ' + [regex]::Escape($Id) + ' -- '
    $hit = @(@($Lines) | Where-Object { $_ -match $rx })
    if ($hit.Count -ne 1) { return "ABSENT/$($hit.Count)" }
    if ($hit[0] -match '^\[PASS\]') { return 'PASS' }
    if ($hit[0] -match '^\[SKIP\]') { return 'SKIP' }
    return 'FAIL'
}
function Get-F1SchemaPredicate {
    # SCOPED TO F-0'S OWN DETAIL BLOCK, not grepped across the whole transcript: another member's
    # detail line could carry the word and the reader would silently answer about the wrong row.
    param([string[]]$Lines)
    $arr = @($Lines)
    $n = $arr.Count
    $start = -1
    for ($i = 0; $i -lt $n; $i++) { if ($arr[$i] -match '^\[(PASS|FAIL|SKIP)\] F-0 -- ') { $start = $i; break } }
    if ($start -lt 0) { return 'F-0-ABSENT' }
    $hit = @()
    for ($i = $start + 1; $i -lt $n; $i++) {
        if ($arr[$i] -match '^\[(PASS|FAIL|SKIP)\] ') { break }
        if (($arr[$i] -match '^\s+\[(ok|MISS)') -and ($arr[$i] -match 'schema')) { $hit += $arr[$i] }
    }
    if (@($hit).Count -ne 1) { return "ABSENT/$(@($hit).Count)" }
    if ($hit[0] -match '\[ok') { return 'ok' }
    return 'MISS'
}
function Get-F1Banner {
    param([string[]]$Lines, [string]$Label)
    $rx  = '^' + [regex]::Escape($Label) + '\s*:\s*'
    $hit = @(@($Lines) | Where-Object { $_ -match $rx })
    if ($hit.Count -ne 1) { return "ABSENT/$($hit.Count)" }
    return ($hit[0] -replace $rx, '').Trim()
}
function Get-F1S1bFace {
    # S-1b'S FACE AND WHETHER ITS OWN GUARD STOPPED IT, scoped to S-1b's detail block as the schema
    # predicate is scoped to F-0's. '<face>/guard' when the block carries the guard's NOTHING WAS RUN
    # line; '<face>/past' when it does not -- a member that got past the guard, even only as far as a
    # CLI it could not find on PATH, is not one its guard stopped.
    param([string[]]$Lines)
    $arr  = @($Lines)
    $face = Get-F1Verdict -Lines $arr -Id 'S-1b'
    $start = -1
    for ($i = 0; $i -lt $arr.Count; $i++) { if ($arr[$i] -match '^\[(PASS|FAIL|SKIP)\] S-1b -- ') { $start = $i; break } }
    if ($start -lt 0) { return $face }
    $guarded = $false
    for ($i = $start + 1; $i -lt $arr.Count; $i++) {
        if ($arr[$i] -match '^\[(PASS|FAIL|SKIP)\] ') { break }
        if ($arr[$i] -match '^\s+NOTHING WAS RUN: ') { $guarded = $true }
    }
    return ($face + $(if ($guarded) { '/guard' } else { '/past' }))
}

$f1Root  = Join-Path $env:TEMP 'wp6f1'
$f1Rows  = [ordered]@{}
$f1Notes = @()
try {
    if (Test-Path -LiteralPath $f1Root) { Remove-Item -LiteralPath $f1Root -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $f1Root -Force

    $armA = New-F1Arm -Name 'A' -WithFixture $true  -SchemaMode 'bytecopy'
    $armB = New-F1Arm -Name 'B' -WithFixture $false -SchemaMode 'none'
    $armD = New-F1Arm -Name 'D' -WithFixture $true  -SchemaMode 'bytecopy' -InRepoFixture $true
    $armE = New-F1Arm -Name 'E' -WithFixture $true  -SchemaMode 'lf'
    $armX = New-F1Arm -Name 'X' -WithFixture $true  -SchemaMode 'different'

    $rA = Invoke-F1Child -Script $armA.Script -Arm 'A' -ExtraArgs @()
    $rB = Invoke-F1Child -Script $armB.Script -Arm 'B' -ExtraArgs @()
    $rD = Invoke-F1Child -Script $armD.Script -Arm 'D' -ExtraArgs @()
    $rE = Invoke-F1Child -Script $armE.Script -Arm 'E' -ExtraArgs @()
    $rX = Invoke-F1Child -Script $armX.Script -Arm 'X' -ExtraArgs @()
    # AN ARRAY LITERAL IN ARGUMENT POSITION CAN SPLIT under PS 5.1, and a split here would drive the
    # arm with no override at all and call the result a pass. Built first, counted, then passed.
    $ovArgs = @('-SmokeRoot', $armA.Smoke)
    if ($ovArgs.Count -ne 2) { throw "the override argument vector split into $($ovArgs.Count) elements, expected 2" }
    $rO = Invoke-F1Child -Script $armB.Script -Arm 'B' -ExtraArgs $ovArgs
    # THE SECOND CHANNEL: arm B, no argument, LAM_SMOKE_ROOT naming arm A's root.
    $rV = Invoke-F1Child -Script $armB.Script -Arm 'B' -ExtraArgs @() -SmokeEnv $armA.Smoke
    # A FILES-ONLY ROOT, HANDED OVER: arm D's stale in-mirror folder as -SmokeRoot.
    $ffArgs = @('-SmokeRoot', $armD.InRepo)
    if ($ffArgs.Count -ne 2) { throw "the files-only argument vector split into $($ffArgs.Count) elements, expected 2" }
    $rF = Invoke-F1Child -Script $armD.Script -Arm 'D' -ExtraArgs $ffArgs

    $vA = Get-F1Verdict -Lines $rA.Lines -Id 'F-0'
    $vB = Get-F1Verdict -Lines $rB.Lines -Id 'F-0'
    $vD = Get-F1Verdict -Lines $rD.Lines -Id 'F-0'
    $vF = Get-F1Verdict -Lines $rF.Lines -Id 'F-0'
    $sA = Get-F1SchemaPredicate -Lines $rA.Lines
    $sE = Get-F1SchemaPredicate -Lines $rE.Lines
    $sX = Get-F1SchemaPredicate -Lines $rX.Lines

    $bASmoke    = Get-F1Banner -Lines $rA.Lines -Label 'smoke repo'
    $bASource   = Get-F1Banner -Lines $rA.Lines -Label 'smoke source'
    $bDefSmoke  = Get-F1Banner -Lines $rB.Lines -Label 'smoke repo'
    $bDefOrigin = Get-F1Banner -Lines $rB.Lines -Label 'origin'
    $bBSource   = Get-F1Banner -Lines $rB.Lines -Label 'smoke source'
    $bDSmoke    = Get-F1Banner -Lines $rD.Lines -Label 'smoke repo'
    $bDSource   = Get-F1Banner -Lines $rD.Lines -Label 'smoke source'
    $bOvSmoke   = Get-F1Banner -Lines $rO.Lines -Label 'smoke repo'
    $bOvOrigin  = Get-F1Banner -Lines $rO.Lines -Label 'origin'
    $bOvSource  = Get-F1Banner -Lines $rO.Lines -Label 'smoke source'
    $bEnvSmoke  = Get-F1Banner -Lines $rV.Lines -Label 'smoke repo'
    $bEnvSource = Get-F1Banner -Lines $rV.Lines -Label 'smoke source'
    $bFSmoke    = Get-F1Banner -Lines $rF.Lines -Label 'smoke repo'
    $bFSource   = Get-F1Banner -Lines $rF.Lines -Label 'smoke source'

    $expDefSmoke  = Join-Path $armB.Root 'lam-smoke'
    $expDefOrigin = Join-Path $armB.Root 'lam-smoke-origin.git'
    $expOvOrigin  = Join-Path $armA.Root 'lam-smoke-origin.git'

    $armsDiffer = (($vA -ceq 'PASS') -and ($vB -ceq 'FAIL'))
    $f1Runs = [ordered]@{ 'A' = $rA; 'B' = $rB; 'D' = $rD; 'D+files' = $rF; 'E' = $rE; 'X' = $rX; 'B+override' = $rO; 'B+LAM_SMOKE_ROOT' = $rV }
    $f1S1b  = [ordered]@{}
    foreach ($f1K in @($f1Runs.Keys)) { $f1S1b[$f1K] = Get-F1S1bFace -Lines $f1Runs[$f1K].Lines }

    # Verdict tokens are compared ORDINALLY (-ceq). Paths are compared case-INSENSITIVELY (-eq),
    # because a Windows path is case-insensitive and `Resolve-Path` canonicalises casing from the
    # filesystem: an ordinal path compare here would manufacture a red row out of drive casing.
    $f1Rows['arm A -- a smoke mission beside the mirror -- resolves by the DEFAULT, names it, and reports F-0 PASS'] = (($vA -ceq 'PASS') -and ($bASmoke -eq $armA.Smoke) -and ($bASource -like 'default*') -and ($bASource -notlike '*ABSENT*'))
    $f1Rows['arm B -- no smoke mission beside the mirror -- reports F-0 FAIL'] = ($vB -ceq 'FAIL')
    $f1Rows['THE FINDING, NARROWED: same bytes, same commit, no arguments -- A and B disagree only through the DEFAULT, which names itself'] = $armsDiffer
    $f1Rows['the DEFAULT is the sibling: with no argument arm B names lam-smoke beside its own mirror, ABSENT, and the origin beside it'] = (($bDefSmoke -eq $expDefSmoke) -and ($bDefOrigin -eq $expDefOrigin) -and ($bBSource -like 'default*ABSENT*'))
    $f1Rows['arm D -- a stale folder of files at tests\lam\fixtures\lam-smoke in the mirror AND a smoke mission beside it -- the DEFAULT reads the sibling, never the folder, and F-0 PASSes'] = (($bDSmoke -eq $armD.Smoke) -and ($bDSmoke -ne $armD.InRepo) -and ($bDSource -like 'default*') -and ($bDSource -notlike '*ABSENT*') -and ($vD -ceq 'PASS'))
    $f1Rows['run D+files -- that folder handed over as -SmokeRoot -- is FILES-ONLY, and F-0 SKIPs by name'] = (($bFSmoke -eq $armD.InRepo) -and ($bFSource -like 'parameter*') -and ($vF -ceq 'SKIP'))
    $f1Rows['-SmokeRoot is a COMPLETE override: the ORIGIN moves with it, not the smoke root alone'] = (($bOvSmoke -eq $armA.Smoke) -and ($bOvOrigin -eq $expOvOrigin) -and ($bOvSource -like 'parameter*'))
    $f1Rows['LAM_SMOKE_ROOT is the second channel and says so: arm B handed it reads arm A''s root'] = (($bEnvSmoke -eq $armA.Smoke) -and ($bEnvSource -like 'environment*'))
    $f1Rows['schema compare, SAME content and different EOL (arm E: LF fixture against CRLF mirror), matches'] = ($sE -ceq 'ok')
    $f1Rows['schema compare, GENUINELY DIFFERENT content (arm X), still MISSES']                            = ($sX -ceq 'MISS')
    # A LIVE ARM'S S-1b NOW FAILS AT THE GUARD rather than skipping -- a live repository S-1b cannot
    # drive is a fixture not built as described, not an unmeasurable clause -- so "no arm reached the
    # CLI" is read off the guard's own NOTHING WAS RUN line, not off a [SKIP] face.
    $f1Rows['no arm reached the CLI: every arm''s S-1b was stopped by its own guard, which says nothing was run'] = (@($f1S1b.Values | Where-Object { $_ -cnotmatch '^(SKIP|FAIL)/guard$' }).Count -eq 0)
    $f1Rows['the guard SKIPs an ABSENT root (B) and a FILES-ONLY root (D+files), and FAILS a LIVE repository it cannot drive (A)'] = (($f1S1b['B'] -ceq 'SKIP/guard') -and ($f1S1b['D+files'] -ceq 'SKIP/guard') -and ($f1S1b['A'] -ceq 'FAIL/guard'))

    if (-not $armsDiffer) {
        $f1Notes += "RUN VOID -- THE ARMS CAME BACK INVERTED (A=$vA, B=$vB). An inverted arm means the apparatus, not the property, produced the answer; NO other row in this member may be read as evidence of anything."
    }
    $f1Notes += "arm roots under $f1Root -- A = smoke mission beside the mirror + byte-copied schema, B = none at all, D = a stale folder of files in the mirror AND a smoke mission beside it (D+files = that folder as -SmokeRoot), E = smoke mission beside + LF schema of the SAME content, X = smoke mission beside + genuinely different schema; LAM_SMOKE_ROOT cleared for every arm but the channel arm"
    $f1Notes += "EXCLUDED FROM THE COMPARED SET, disclosed not hidden: S-4d reads $(Get-F1Verdict -Lines $rA.Lines -Id 'S-4d') in arm A and $(Get-F1Verdict -Lines $rB.Lines -Id 'S-4d') in arm B, because a minimal mirror omits tools\evidence-hooks-next\hooks\lib\evidence-common.ps1 which S-4d dot-sources from `$repoRoot. Only F-0's verdict, F-0's schema predicate, the banner and S-1b's face are read from an arm."
    $f1Notes += "arm A schema predicate: $sA -- a byte copy matches on EITHER basis, which is what keeps the LOCATION finding independent of the EOL cure"
    $f1Notes += "arm F-0 verdicts: A=$vA B=$vB D=$vD D+files=$vF; arm S-1b faces: $((@($f1S1b.Keys) | ForEach-Object { $_ + '=' + $f1S1b[$_] }) -join ' ')"
    $f1Notes += "arm exit codes: A=$($rA.Exit) B=$($rB.Exit) D=$($rD.Exit) D+files=$($rF.Exit) E=$($rE.Exit) X=$($rX.Exit) B+override=$($rO.Exit) B+LAM_SMOKE_ROOT=$($rV.Exit)"
    $f1Notes += "banner, arm A with no argument   : smoke=$bASmoke | source=$bASource"
    $f1Notes += "banner, arm B with no argument   : smoke=$bDefSmoke | origin=$bDefOrigin | source=$bBSource"
    $f1Notes += "banner, arm D with no argument   : smoke=$bDSmoke | source=$bDSource"
    $f1Notes += "banner, arm D with -SmokeRoot its in-mirror folder: smoke=$bFSmoke | source=$bFSource"
    $f1Notes += "banner, arm B with -SmokeRoot A  : smoke=$bOvSmoke | origin=$bOvOrigin | source=$bOvSource   (origin required under A: $expOvOrigin)"
    $f1Notes += "banner, arm B with LAM_SMOKE_ROOT: smoke=$bEnvSmoke | source=$bEnvSource"
    $deep = @(Get-ChildItem -LiteralPath $f1Root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Length } | Sort-Object -Descending)
    if (@($deep).Count -gt 0) { $f1Notes += "arm files: $(@($deep).Count); longest path $($deep[0]) chars -- short-path discipline, a deep scratch fixture has failed here with 'Filename too long'" }
} catch {
    # A CRASH IS A FAILING ROW THAT NAMES ITS LINE, never an absent member that reads as silence.
    $f1Rows['the F-1 apparatus ran to completion'] = $false
    $f1Notes += "CRASH at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
}
if ($f1Rows.Count -eq 0) { $f1Rows['the F-1 apparatus produced at least one row'] = $false }
$f1Detail = ''
foreach ($k in $f1Rows.Keys) { $f1Detail += "    [$(if ($f1Rows[$k]) { 'ok  ' } else { 'MISS' })] $k`n" }
foreach ($note in $f1Notes) { $f1Detail += "    - $note`n" }
Check -Id 'F-1' -Title 'F-0''s location dependence is the named DEFAULT''s: the smoke mission beside the primary checkout, never a folder of files in the checkout; -SmokeRoot overrides BOTH anchors; the schema compare is EOL-insensitive and still real' `
      -Ok (-not ($f1Rows.Values -contains $false)) -Detail $f1Detail.TrimEnd()

}

# =============================================================================================
# F-2 -- F-H9 (RELEASE-4 S2; row 495 (8)): F-0's H-3 ROW READS THE PATCH's CODE, NOT COMMENT TEXT
# =============================================================================================
# The predicate F-0 uses (Test-Wp6H3Applied), over the smoke mission's own tools/mission-lib.ps1, over that file with
# every comment line removed (the code unchanged: still applied), and over a text holding the old marker and both calls
# only inside comments (not applied). RED at fc9dc67, where F-0 matched the whole text: comments-only read applied and
# the stripped file read not applied.
$f2Real = ReadText (Join-Path $SmokeRoot 'tools\mission-lib.ps1')
$f2Stripped = ((($f2Real -replace "`r`n", "`n") -split "`n") | Where-Object { -not $_.TrimStart().StartsWith('#') }) -join "`n"
$f2Comments = "# .mission/evidence/session-`n#   `$porc = Get-LamPorcelainState -MissionRoot `$Root`n#   `$decl = Get-LamDeclaredAdmittedPorcelain -MissionRoot `$Root`n<#`n`$porc = Get-LamPorcelainState -MissionRoot `$Root`n`$decl = Get-LamDeclaredAdmittedPorcelain -MissionRoot `$Root`n#>`n"
$f2 = [ordered]@{
    'the smoke mission''s tools/mission-lib.ps1 reads applied, by its code' = [bool](Test-Wp6H3Applied -Text $f2Real)
    'the same file with every comment line removed still reads applied'      = [bool]($f2Real -and (Test-Wp6H3Applied -Text $f2Stripped))
    'the marker and both calls only inside comments read NOT applied'        = (-not (Test-Wp6H3Applied -Text $f2Comments))
}
Write-Wp6Member -Id 'F-2' -Title 'F-H9 (row 495 (8)): F-0''s H-3 row is decided by the H-3 patch''s code (the admitted-porcelain reader''s two calls), never by comment text' -Rows $f2

# =============================================================================================
# S-1 -- dispatch D-1 authored, run, handoff valid, anchors present
# =============================================================================================
$d1        = Join-Path $dispatchDir 'D-1.yaml'
$d1Handoff = Join-Path $dispatchDir 'D-1.handoff.yaml'
$d1Anchors = Join-Path $dispatchDir 'D-1.anchors.yaml'
$hoffText  = ReadText $d1Handoff
$anchText  = ReadText $d1Anchors
$s1 = [ordered]@{
    'D-1 dispatch artifact exists'   = (Test-Path -LiteralPath $d1)
    'handoff exists'                 = (Test-Path -LiteralPath $d1Handoff)
    'handoff is NOT rejected'        = (($hoffText -ne '') -and ($hoffText -notmatch '(?m)^status:\s*rejected'))
    'anchors exist'                  = (Test-Path -LiteralPath $d1Anchors)
    'anchors carry a worktree tip'   = ($anchText -match '(?m)^worktree_tip_sha:\s*[0-9a-f]{40}')
    'anchors carry the sidecar figures' = (($anchText -match 'capture_gaps_count:') -and ($anchText -match 'capture_gaps_sha256:'))
    # The evidence session lives in the ignored runtime plane; a root of tracked files cannot show it.
    'runner-owned evidence session'  = $(if ($smokeExists -and -not $smokePlane) { $smokeNoPlaneWhy } else { (@(Get-ChildItem -LiteralPath $evRootBase -Directory -Filter 'session-D-1*' -ErrorAction SilentlyContinue).Count -ge 1) })
}
Write-Wp6Member -Id 'S-1' -Title 'D-1 authored and run: handoff valid, anchors present' -Rows $s1

# =============================================================================================
# S-1b -- THE CLI RUNS THE WORKER IN THE TREE THE RUNNER PRE-PLACED, AT THE DECLARED BASE
# =============================================================================================
# WHAT THE PRE-PLACEMENT CURE STANDS ON. The runner materialises the worktree for wt-<id>, at the home the
# runner itself composes, at the dispatch's declared base BEFORE it spawns the worker. This member
# does not spell that home: it reads it from the same runner's -PlanOnly (the plan prints the path
# the run uses), and goes red if the plan does not name exactly one. And the CLI -- still handed
# --worktree wt-<id> -- was measured on CLI 2.1.258 to REUSE a directory it finds under that name
# instead of cutting a new tree at origin/main. That was read off the CLI's own stream-json init
# event, in a throwaway repository. It is a measured property of
# one CLI build, not a documented contract. If a later CLI stops reusing, the cut returns to
# origin/main and the runner only RECORDS it -- worktree_base_still_descends, a git_errors entry --
# because by then the work is done. A record that no member asserts is not a red light. This member
# is the red light: it drives ONE real worker through the real runner, and it goes red the day the
# CLI stops running that worker in the tree it was given.
#
# WHERE IT RUNS, AND WHY NOT IN THE SMOKE REPOSITORY ITSELF. This instrument is read-only on the smoke
# repo with no exception (header), and S-5 and ZP grade every evidence session, gate and prompt
# register in that repo. A live dispatch there would add a session, a register line, a handoff and a
# worktree to the plane those members grade, and deleting evidence to tidy up is the one thing this
# build does not do (the S-4(a) comment below). So the smoke repository is CLONED into %TEMP%\s1b --
# the fixed-name throwaway convention S-4c and S-4d use -- everything the dispatch writes lands in the
# clone, and the clone is deleted afterwards. The smoke repository at the smoke root and the bare
# lam-smoke-origin.git beside it are only read.
#
# AND WHERE IT DOES NOT RUN AT ALL. An ABSENT smoke root, or a FILES-ONLY one (no .git entry: a
# folder of copied files), has no history to clone, and the member SKIPs and names
# why. A LIVE repository that git does not answer for as a work tree's top level, or that has no bare
# origin beside it, or that carries none of the untracked supersession ratifications, is a smoke
# mission whose S-1b fixture cannot be built as described -- that is a FAILURE, not an unmeasurable
# clause, and the member FAILS and names every missing piece. Either way the guard below decides
# BEFORE `Get-Command claude`, so such a root never reaches the CLI -- not even `claude --version` --
# and %TEMP%\s1b is not touched: nothing is spawned, and the detail says so.
#
# WHAT THE CLONE CARRIES FROM THE SMOKE REPOSITORY, EACH FOR A STATED REASON:
#   * its tracked tree at BLOB bytes (core.autocrlf=false), so its two supersession markers keep the
#     sha256 their gates bind. Measured: a clone under this host's global core.autocrlf=true gives
#     both markers a different sha256, and the runner refuses a marker no gate binds;
#   * its OWN refs/remotes/origin/main, fetched from it, so the cut point a CLI takes by itself is
#     the one the smoke mission would hand it;
#   * its two UNTRACKED supersession gates, copied byte for byte -- the markers are tracked and their
#     ratifications are not, so a plain clone is a mission holding unratified markers;
#   * origin re-pointed at a bare clone of lam-smoke-origin.git INSIDE the fixture, so a fetch,
#     ls-remote or push through the fixture's origin reaches only a throwaway.
# AND TWO THINGS THE SMOKE REPOSITORY CANNOT SUPPLY, EACH NAMED:
#   * the pre-push decider, installed for THIS toolchain's shipped decider the way WP-2's fixture
#     installs it, because the runner refuses a repository without one;
#   * a verify stub that PASSES. The ADR-022 gate is not what this member measures -- WP-2 R-1 owns
#     it -- and the clone has no evidence plane for the real verify to re-derive (.mission-runtime is
#     ignored, so it is never cloned). -VerifyCommand is the runner's disclosed seam. -WorkerCommand
#     is NOT used: the worker is the real CLI, which is the whole point.
#
# THE DECLARED BASE IS A COMMIT NO CLI CUT CAN LAND ON BY ITSELF. It is a fixture-only commit whose
# TREE is the smoke HEAD's tree and whose parent is that HEAD, on no branch. So it is neither HEAD nor
# origin/main and an ancestor of neither, and every cut point a CLI takes on its own is told apart
# from it -- including the reset-to-origin/main shape measured earlier for a surviving branch.
# HEAD~1 would have been discriminating only until the smoke main is next pushed; after that it is
# an ancestor of origin/main, a reset tree still descends from it, and this member would go inert
# without saying so. Row (5) asserts the property instead of assuming it.
#
# THE WORKER IS AS SMALL AS THE RUNNER PERMITS: model_class small-fast (model-routing.yaml), a
# read-only dispatch whose brief is to do nothing, and no handoff asked for -- so the runner ends 3
# (handoff rejected) or 0, both AFTER the anchors are written. Placement, cwd and base are judged;
# the handoff is not.
#
# THE FIVE PROPERTIES, AND WHAT EACH ONE READS:
#   (1) PRE-PLACED AT THE DECLARED BASE, BEFORE THE SPAWN -- the runner's pre-spawn line, the anchors'
#       declared_base / worktree_base_honoured / worktree_path, and git's reflog of the branch, whose
#       creation line is written by the act that created it (a CLI cut writes 'Created from
#       origin/main').
#   (2) THE CLI RAN THE WORKER THERE -- EVERY stream-json init event's cwd, path spelling and case
#       normalised, is the pre-placed directory.
#   (3) AT THAT BASE -- worktree_base_observed is the base, worktree_base_still_descends is true, no
#       git_errors entry concerns the cut, and git itself, asked by this member after the run, still
#       finds the base an ancestor of that tree's HEAD.
#   (4) NO SECOND TREE AND NO SECOND BRANCH -- git worktree list and refs/heads, before and after:
#       the only additions are the one directory and the one branch the runner itself creates.
#   (5) NOT VACUOUS -- the stream was parsed, an init event was found, the worker exited 0, the
#       anchors are THIS run's (their dispatch_sha256 is this artifact's), and the base is none of the
#       cut points a CLI takes by itself.
#
# AND THE PREDICATE IS SHOWN ABLE TO FAIL, ON THIS RUN'S OWN EVIDENCE. One function computes the five
# properties. It is then handed four copies of the evidence, each carrying one shape a non-reusing
# CLI would leave, and each copy must go red on the property it targets. That proves the predicate is
# not blind to those shapes. The copies alter evidence already extracted, so they do not exercise the
# parsing of the stream, the reflog or the worktree list, and they are NOT a live non-reusing CLI.
# THE REGRESSION'S OWN SHAPE IS SUMMONABLE, AND IT WAS DRIVEN ONCE, LIVE, THROUGH THIS MEMBER UNCHANGED
# (on its review). A toolchain mirror's runner was planted so that, after pre-placing the tree at
# the base and setting honoured, it removed that directory with 'git worktree remove --force' and kept
# the branch. The real CLI 2.1.258, finding the branch and no
# directory, recreated the tree and RESET THE BRANCH TO origin/main (reflog, newest first: 'Reset to
# origin/main', 'Created from <base>') and ran the worker there. The runner wrote
# worktree_base_honoured: true, worktree_base_still_descends: false and the git_errors entry
# '... is NOT an ancestor of the worktree tip <origin/main> ...'. This member went RED on exactly the
# three (3) rows that read the tree after the run -- still_descends, git_errors, and git's own
# ancestor check -- and stayed GREEN on every other row: all of (1), because the runner line, the
# anchors and the 'Created from <base>' reflog line all survive a reset; (2), same path; (3)
# worktree_base_observed, which is the PRE-SPAWN reading when the base is honoured and so cannot see a
# later reset; (4), one tree and one branch; and (5). WP-6 does not repeat that drive -- it needs a
# planted runner -- so a green run here does not re-summon the shape.
# WHY (2) IS NOT ENOUGH ON ITS OWN, MEASURED BEFORE THIS MEMBER LANDED: against a copy of the runner
# with the runner's pre-placement removed, the same live spawn let the CLI cut its own tree. Its init
# event STILL named <root>\.claude\worktrees\wt-<id> -- the same path -- while the reflog read
# 'Created from origin/main', the tree stood at origin/main, and the runner recorded
# worktree_base_still_descends: null with no git_errors entry at all. This member went red on (1)
# and (3) and stayed green on (2). A cwd check alone would have passed the defect the pre-placement cured.
#
# WHAT RUNNING IT COSTS AND LEAVES, stated here because a validator decides whether to run this file
# on what it says about itself: one billed small-fast worker spawn (seconds, measured); the fixture
# %TEMP%\s1b, deleted at the end (the detail reports whether that worked); and TWO PIECES OF THE CLI'S
# OWN STATE for the fixture repository, which are the CLI's and not this file's and are not removed here:
#   * its per-project directory under the user's .claude\projects, which the CLI makes for any
#     repository it runs in and which the init event names;
#   * a projects entry keyed by the fixture path in the user's GLOBAL ~/.claude.json. Its
#     activeWorktreeSession names the pre-placed worktree, its name and its branch -- a directory this
#     member deletes moments later. The entry persists after the run, so EVERY RUN AFTER THE FIRST
#     STARTS WITH THE PREVIOUS RUN'S ENTRY PRESENT for the same key and path: no run but the first on a
#     host starts from clean CLI state. Read by key names and booleans only, because that file may hold
#     secrets: before the seq 159 drive above the entry carried resumedExisting = true; after it, where
#     the CLI recreated the tree, the rewritten entry carried no resumedExisting key and a
#     creationDurationMs key instead; hasTrustDialogAccepted was false in both, so no trust grant is
#     persisted.
# Both names are fixed because the fixture path is fixed, so repeated runs leave one of each, not one
# per run. The worker's hooks are the ones the smoke repository's tracked .claude\settings.local.json
# registers, and they write under the worker's project directory, which is inside the clone.
$s1bId          = 'D-S1B'
$s1bRoot        = Join-Path $env:TEMP 's1b'
$s1bMission     = Join-Path $s1bRoot 'smoke'
$s1bBare        = Join-Path $s1bRoot 'origin.git'
$s1bVerify      = Join-Path $s1bRoot 'verify-pass.ps1'
$s1bInstaller   = Join-Path $s1bRoot 'install-decider.ps1'
$s1bWtName      = "wt-$s1bId"
$s1bExpected    = ''          # the runner's own -PlanOnly names it, below; never spelled here
$s1bBranch      = "refs/heads/worktree-$s1bWtName"
$s1bRunner      = Join-Path $repoRoot 'tools\lam\mission-dispatch.ps1'
$s1bOk          = $false
$s1bError       = ''
$s1bSteps       = @()
$s1bSetupOk     = $false
$s1bCliVersion  = '(not read)'
$s1bBase        = ''
$s1bFacts       = [ordered]@{}
$s1bRunExit     = '(not run)'
$s1bRunOut      = @()
$s1bRows        = $null
$s1bControls    = @()
$s1bGitErrors   = @()
$s1bInitCwds    = @()
$s1bProjectDir  = ''
$s1bRemoved     = $false

function ConvertTo-S1bPathKey {
    param([string]$PathText)
    if (-not $PathText) { return '' }
    $full = $PathText.Trim().Replace('/', '\')
    try { $full = [System.IO.Path]::GetFullPath($full) } catch { }
    if ($full.Contains('~')) { $full = Expand-S1bShortPath -PathText $full }
    return $full.TrimEnd('\').ToLowerInvariant()
}
# 8.3 SHORT NAMES ARE EXPANDED BEFORE KEYING (on its review). GetFullPath leaves C:\PROGRA~1 as it
# is, so one directory spelled short on one side -- a %TEMP% under a short-spelled %USERPROFILE% (a <user> folder such as LONGNA~1) feeding the
# expected path -- and long on the other -- git's worktree list, the CLI's own cwd -- gave two keys,
# and (1) worktree_path, (2) and (4) would go falsely red on such a host (this host's %TEMP% has no
# short spelling, so it never did here). Each component carrying '~' is looked up in its parent, and
# the directory listing answers with the long name; a component that does not exist, or matches more
# or less than one entry, is kept as written. Measured: C:\PROGRA~1\x and C:\Program Files\x now key
# the same.
function Expand-S1bShortPath {
    param([string]$PathText)
    $s1bRootPart = [System.IO.Path]::GetPathRoot($PathText)
    if (-not $s1bRootPart) { return $PathText }
    $s1bWalk = $s1bRootPart
    foreach ($s1bPart in $PathText.Substring($s1bRootPart.Length).Split('\')) {
        if (-not $s1bPart) { continue }
        $s1bNext = [System.IO.Path]::Combine($s1bWalk, $s1bPart)
        if ($s1bPart.Contains('~')) {
            try {
                $s1bHit = @([System.IO.Directory]::GetFileSystemEntries($s1bWalk, $s1bPart))
                if ($s1bHit.Count -eq 1) { $s1bNext = $s1bHit[0] }
            } catch { }
        }
        $s1bWalk = $s1bNext
    }
    return $s1bWalk
}
function Get-S1bGitLines {
    param([string]$Root, [string[]]$Argv)
    $prevS1b = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $gl = @(& git -C $Root @Argv 2>&1 | ForEach-Object { "$_" })
        $gc = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevS1b }
    return [pscustomobject]@{ lines = $gl; exit = $gc }
}
function Invoke-S1bGitStep {
    param([string]$Name, [string]$Root, [string[]]$Argv)
    $gr = GitOut -Root $Root -Argv $Argv
    return [pscustomobject]@{ name = $Name; out = $gr.out; exit = $gr.exit }
}
# THE PRE-PLACED DIRECTORY IS THE RUNNER'S TO NAME, NOT THIS MEMBER'S (operator ruling, batch 2
# session 4). Spelling the runner's home here a second time is a known shape -- two
# compositions of one path that can drift without either going red. So the same runner, with the
# same -MissionRoot, -Dispatch and -VerifyCommand the live run is given, is asked with -PlanOnly,
# which prints '  worktree path  : <path>' and exits 0 before the verify gate and before any spawn,
# and writes nothing: no run record, no evidence session, so the live run's id-reuse guard is not
# tripped by it. Exit 0 and EXACTLY ONE such line, or no path is returned and the reason says why.
# There is no fallback home: a guessed path would let (1), (2) and (4) agree with a directory the
# runner never named, and the member would be vacuous without saying so.
function Get-S1bPlannedWorktreePath {
    param([string]$PlanRunner, [string]$PlanMissionRoot, [string]$PlanDispatchId, [string]$PlanVerify)
    $planRes = [pscustomobject]@{ path = ''; exit = '(not run)'; hits = 0; lines = @(); reason = '' }
    $prevS1bPlan = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $planRes.lines = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $PlanRunner -MissionRoot $PlanMissionRoot -Dispatch $PlanDispatchId -VerifyCommand $PlanVerify -PlanOnly 2>&1 | ForEach-Object { "$_" })
        $planRes.exit = "$LASTEXITCODE"
    } finally { $ErrorActionPreference = $prevS1bPlan }
    $planHits = @($planRes.lines | Where-Object { $_ -match '^\s*worktree path\s*:\s*(.+?)\s*$' })
    $planRes.hits = $planHits.Count
    if ($planRes.exit -ne '0') {
        $planRes.reason = "the runner's -PlanOnly exited $($planRes.exit), not 0, so the runner named no worktree path"
    } elseif ($planHits.Count -ne 1) {
        $planRes.reason = "the runner's -PlanOnly printed $($planHits.Count) 'worktree path' lines, not exactly one"
    } elseif ($planHits[0] -match '^\s*worktree path\s*:\s*(.+?)\s*$') {
        $planRes.path = $Matches[1]
    }
    return $planRes
}
function Get-S1bAnchorValue {
    param([string]$Text, [string]$Key)
    if ($Text -match ('(?m)^' + [regex]::Escape($Key) + ':[ \t]*(.*?)[ \t]*\r?$')) { return $Matches[1] }
    return ''
}
# THE PREDICATE, ONCE. The live run and the four controls below are judged by this function and by
# nothing else, so a control that goes red is evidence about the check the live run passed.
function Test-S1bReuse {
    param($Ev)
    $cwds = @($Ev.initCwds)
    $wtAdd = @($Ev.wtAdded)
    $brAdd = @($Ev.brAdded)
    $rows = [ordered]@{}
    $rows['(1) the runner reported, before the spawn, cutting the tree at the declared base'] = [bool]$Ev.runnerCutLine
    $rows['(1) anchors: declared_base_field base_head_at_authoring, declared_base = the base'] = (($Ev.ancBaseField -eq 'base_head_at_authoring') -and ($Ev.ancDeclaredBase -eq $Ev.base))
    $rows['(1) anchors: worktree_base_honoured is true'] = ($Ev.ancHonoured -eq 'true')
    $rows['(1) anchors: worktree_path is the pre-placed directory'] = ($Ev.ancPathKey -eq $Ev.expectedKey)
    $rows['(1) git reflog: the branch was Created from the base'] = (($Ev.reflogFrom.Length -ge 7) -and $Ev.base.StartsWith($Ev.reflogFrom))
    $rows['(2) every init event names the pre-placed directory as cwd'] = (($cwds.Count -gt 0) -and (@($cwds | Where-Object { $_ -ne $Ev.expectedKey }).Count -eq 0))
    $rows['(3) anchors: worktree_base_observed = the base'] = ($Ev.ancObserved -eq $Ev.base)
    $rows['(3) anchors: worktree_base_still_descends is true'] = ($Ev.ancDescends -eq 'true')
    $rows['(3) no git_errors entry concerns the cut'] = (@($Ev.cutErrors).Count -eq 0)
    $rows['(3) git, asked after the run: the base is an ancestor of that tree''s HEAD'] = [bool]$Ev.gitDescends
    $rows['(4) exactly one worktree added, and it is the pre-placed directory'] = (($wtAdd.Count -eq 1) -and ($wtAdd[0] -eq $Ev.expectedKey) -and (@($Ev.wtRemoved).Count -eq 0))
    $rows['(4) exactly one branch added, and it is the runner''s worktree branch'] = (($brAdd.Count -eq 1) -and ($brAdd[0] -ceq $Ev.expectedBranch) -and (@($Ev.brRemoved).Count -eq 0))
    $rows['(5) the captured stream parsed to JSON objects'] = ($Ev.jsonObjects -gt 0)
    $rows['(5) an init event was found and parsed'] = ($cwds.Count -gt 0)
    $rows['(5) the worker exited 0'] = ($Ev.workerExit -eq '0')
    $rows['(5) the anchors are this run''s (dispatch_sha256 = the artifact)'] = [bool]$Ev.anchorsThisRun
    $rows['(5) the declared base is none of the cut points a CLI takes by itself'] = [bool]$Ev.baseDiscriminating
    return $rows
}
function Copy-S1bEvidence {
    param($Ev, [hashtable]$Change)
    $cp = [ordered]@{}
    foreach ($pr in $Ev.PSObject.Properties) { $cp[$pr.Name] = $pr.Value }
    foreach ($ck in $Change.Keys) { $cp[$ck] = $Change[$ck] }
    return [pscustomobject]$cp
}

# THE GUARD THAT KEEPS EVERY ROOT THIS MEMBER CANNOT DRIVE FROM THE CLI, asked BEFORE `Get-Command
# claude`: such a root never runs the CLI at all -- not even --version -- and %TEMP%\s1b is untouched.
# It has TWO answers, and which one is the point. An ABSENT or FILES-ONLY root SKIPs: there is no
# history to clone, and that is where the root sits, not what it holds. A LIVE repository that lacks
# what the fixture needs FAILS: a smoke repository whose git does not answer for it, with no bare
# origin beside it, or with no supersession ratification, is a smoke mission not built as described,
# and a skip there would swallow exactly the failure this member exists to show.
$s1bSkip      = ''
$s1bGuardFail = ''
if (-not $smokeExists) {
    $s1bSkip = "the smoke root $SmokeRoot is ABSENT ($smokeSource)"
} elseif ($smokeIsFilesOnly) {
    $s1bSkip = "$smokeNotRepoWhy ($smokeSource) -- S-1b clones the smoke repository's HISTORY, and a files-only root has none"
} else {
    $s1bMissing = @()
    if (-not $smokeIsRepoTop) { $s1bMissing += "$smokeLiveGitWhy -- no history S-1b can clone" }
    if (-not $originIsBare) {
        $s1bMissing += "no bare repository at $originPath, the origin anchor beside the smoke root ($(if (Test-Path -LiteralPath $originPath) { 'present, NOT a bare repository' } else { 'ABSENT' }))"
    }
    if (@(Get-ChildItem -LiteralPath $gatesDir -File -Filter 'supersession-*.yaml' -ErrorAction SilentlyContinue).Count -lt 1) {
        $s1bMissing += "no supersession-*.yaml ratification under $gatesDir"
    }
    if ($s1bMissing.Count -gt 0) {
        $s1bGuardFail = "the smoke root $SmokeRoot is a LIVE repository ($smokeSource) and S-1b's fixture cannot be built as described: " + ($s1bMissing -join ' ; ')
    }
}

if ((-not $s1bSkip) -and (-not $s1bGuardFail)) {
try {
    # --- the CLI, versioned before anything is built ---------------------------------------------
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        throw 'the claude CLI is not on PATH, so no live worker can be spawned and nothing here can be measured'
    }
    $s1bPrevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $s1bCliVersion = ((@(& claude --version 2>&1) | ForEach-Object { "$_" }) -join ' ').Trim() }
    finally { $ErrorActionPreference = $s1bPrevEap }

    # --- the fixture: a clone of the smoke repository, nothing written back ----------------------
    if (Test-Path -LiteralPath $s1bRoot) { Remove-Item -LiteralPath $s1bRoot -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $s1bRoot -Force
    $s1bSteps += Invoke-S1bGitStep -Name 'clone the smoke repository, blob bytes' -Root $s1bRoot `
                     -Argv @('clone', '-q', '--no-hardlinks', '-c', 'core.autocrlf=false', $SmokeRoot, $s1bMission)
    $s1bSteps += Invoke-S1bGitStep -Name 'mirror the smoke repository''s own remote-tracking refs' -Root $s1bMission `
                     -Argv @('fetch', '-q', '--prune', $SmokeRoot, '+refs/remotes/origin/*:refs/remotes/origin/*')
    $s1bSteps += Invoke-S1bGitStep -Name 'bare clone of lam-smoke-origin.git inside the fixture' -Root $s1bRoot `
                     -Argv @('clone', '-q', '--bare', '--no-hardlinks', $originPath, $s1bBare)
    $s1bSteps += Invoke-S1bGitStep -Name 'origin re-pointed at that bare clone' -Root $s1bMission `
                     -Argv @('remote', 'set-url', 'origin', ($s1bBare.Replace('\', '/')))
    $s1bSteps += Invoke-S1bGitStep -Name 'fixture identity (user.email)' -Root $s1bMission -Argv @('config', 'user.email', 'wp6@instrument.local')
    $s1bSteps += Invoke-S1bGitStep -Name 'fixture identity (user.name)' -Root $s1bMission -Argv @('config', 'user.name', 'WP6 Instrument')
    $s1bBaseStep = Invoke-S1bGitStep -Name 'the declared base: smoke HEAD tree, parent smoke HEAD, no branch' -Root $s1bMission `
                     -Argv @('commit-tree', 'HEAD^{tree}', '-p', 'HEAD', '-m', 'WP-6 S-1b declared base: the smoke HEAD tree, on no branch')
    $s1bSteps += $s1bBaseStep
    if ($s1bBaseStep.out -match '^[0-9a-f]{40}$') { $s1bBase = $s1bBaseStep.out }

    # The facts the discrimination rests on, each read from git rather than assumed.
    $s1bFacts['smoke HEAD']                    = (GitOut -Root $SmokeRoot -Argv @('rev-parse', 'HEAD')).out
    $s1bFacts['smoke origin/main']             = (GitOut -Root $SmokeRoot -Argv @('rev-parse', '--verify', '--quiet', 'refs/remotes/origin/main')).out
    $s1bFacts['fixture HEAD']                  = (GitOut -Root $s1bMission -Argv @('rev-parse', 'HEAD')).out
    $s1bFacts['fixture origin/main']           = (GitOut -Root $s1bMission -Argv @('rev-parse', '--verify', '--quiet', 'refs/remotes/origin/main')).out
    $s1bFacts['declared base']                 = $(if ($s1bBase) { $s1bBase } else { '(none -- commit-tree failed)' })
    $s1bFacts['base tree = smoke HEAD tree']   = ($s1bBase -and ((GitOut -Root $s1bMission -Argv @('rev-parse', ($s1bBase + '^{tree}'))).out -eq (GitOut -Root $s1bMission -Argv @('rev-parse', 'HEAD^{tree}')).out))
    $s1bFacts['is-ancestor base HEAD, exit (1 = no)'] = $(if ($s1bBase) { (GitOut -Root $s1bMission -Argv @('merge-base', '--is-ancestor', $s1bBase, 'HEAD')).exit } else { 'n/a' })
    $s1bFacts['is-ancestor base origin/main, exit (1 = no)'] = $(if ($s1bBase -and $s1bFacts['fixture origin/main']) { (GitOut -Root $s1bMission -Argv @('merge-base', '--is-ancestor', $s1bBase, 'refs/remotes/origin/main')).exit } else { 'n/a' })
    $s1bDiscriminating = [bool]($s1bBase -and $s1bFacts['fixture origin/main'] -and
                                ($s1bBase -ne $s1bFacts['fixture HEAD']) -and ($s1bBase -ne $s1bFacts['fixture origin/main']) -and
                                ($s1bFacts['is-ancestor base HEAD, exit (1 = no)'] -eq 1) -and
                                ($s1bFacts['is-ancestor base origin/main, exit (1 = no)'] -eq 1) -and
                                $s1bFacts['base tree = smoke HEAD tree'])

    # The smoke mission's untracked ratifications, byte for byte, and the arity asserted.
    $s1bGateSrc = @(Get-ChildItem -LiteralPath $gatesDir -File -Filter 'supersession-*.yaml' -ErrorAction SilentlyContinue)
    $s1bGateDst = Join-Path $s1bMission '.mission\gates'
    if (-not (Test-Path -LiteralPath $s1bGateDst)) { $null = New-Item -ItemType Directory -Path $s1bGateDst -Force }
    $s1bGateSame = 0
    foreach ($s1bG in $s1bGateSrc) {
        $s1bGd = Join-Path $s1bGateDst $s1bG.Name
        [System.IO.File]::WriteAllBytes($s1bGd, [System.IO.File]::ReadAllBytes($s1bG.FullName))
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $s1bGd).Hash -eq (Get-FileHash -Algorithm SHA256 -LiteralPath $s1bG.FullName).Hash) { $s1bGateSame++ }
    }
    $s1bMarkers = @(Get-ChildItem -LiteralPath (Join-Path $s1bMission '.mission') -Recurse -File -Filter '*.superseded.yaml' -ErrorAction SilentlyContinue)
    $s1bFacts['supersession gates copied (identical / found)'] = "$s1bGateSame / $($s1bGateSrc.Count)"
    $s1bFacts['supersession markers in the clone'] = $s1bMarkers.Count

    # The decider, for THIS toolchain, written by the guard library in a CHILD process, for the reason
    # the runner gives for reaching the checker that way: the library redefines A1 functions by design
    # and is not dot-sourced into a caller's scope by accident.
    $s1bInstallerText = @'
param([string]$Library, [string]$Decider, [string]$Hook)
$ErrorActionPreference = 'Stop'
. $Library
[System.IO.File]::WriteAllText($Hook, (Get-EvidencePrePushWrapperText -DeciderPath $Decider), (New-Object System.Text.UTF8Encoding($false)))
exit 0
'@
    [System.IO.File]::WriteAllText($s1bInstaller, $s1bInstallerText, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($s1bVerify, "Write-Output 'gate: PASS'`nexit 0`n", (New-Object System.Text.UTF8Encoding($false)))
    $s1bPrevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $s1bInstaller `
                    -Library (Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1') `
                    -Decider (Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-pre-push.ps1') `
                    -Hook (Join-Path $s1bMission '.git\hooks\pre-push') 2>&1
        $s1bFacts['decider installer exit'] = $LASTEXITCODE
        $null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\check-prepush-installed.ps1') -RepoRoot $s1bMission 2>&1
        $s1bFacts['decider checker exit (expect 0)'] = $LASTEXITCODE
    } finally { $ErrorActionPreference = $s1bPrevEap }

    # The dispatch. It is the worker's whole prompt, so it asks for nothing.
    $s1bDispatchText = @'
# WP-6 S-1b fixture dispatch. THIS ARTIFACT IS THE WORKER'S ENTIRE INPUT.
# It exists to observe WHERE the CLI runs a worker, so the work it asks for is none.
id: D-S1B
mission_id: smoke
worker_id: w-smoke-s1b
kind: read-only
feature_id: F-001
assertion_targets: []
spec_version: 1
model_class: small-fast
base_head_at_authoring: __S1B_BASE__
brief: |
  Do nothing. Use no tools, edit no file and run no command.
  Reply with the single word OK and end your turn.
'@
    $s1bDispatchText = ($s1bDispatchText -replace "`r`n", "`n").Replace('__S1B_BASE__', $s1bBase) + "`n"
    $s1bDispatchPath = Join-Path $s1bMission ".mission\dispatches\$s1bId.yaml"
    [System.IO.File]::WriteAllText($s1bDispatchPath, $s1bDispatchText, (New-Object System.Text.UTF8Encoding($false)))
    $s1bDispatchSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $s1bDispatchPath).Hash.ToLowerInvariant()

    # The HEAD equalities also require a 40-hex sha on the smoke side: two git error texts are equal
    # strings, and an equality of errors is not a fixture built as described.
    $s1bSetupOk = ((@($s1bSteps | Where-Object { $_.exit -ne 0 }).Count -eq 0) -and $s1bBase -and
                   ([string]$s1bFacts['smoke HEAD'] -match '^[0-9a-f]{40}$') -and ($s1bFacts['fixture HEAD'] -eq $s1bFacts['smoke HEAD']) -and
                   ([string]$s1bFacts['smoke origin/main'] -match '^[0-9a-f]{40}$') -and ($s1bFacts['fixture origin/main'] -eq $s1bFacts['smoke origin/main']) -and
                   ($s1bGateSrc.Count -ge 1) -and ($s1bGateSame -eq $s1bGateSrc.Count) -and
                   ($s1bFacts['decider checker exit (expect 0)'] -eq 0))
    if (-not $s1bSetupOk) { throw 'the fixture could not be built as described -- see the setup steps and facts below; nothing was spawned' }

    # --- the pre-placed directory, as the runner itself composes it -------------------------------
    $s1bPlan = Get-S1bPlannedWorktreePath -PlanRunner $s1bRunner -PlanMissionRoot $s1bMission -PlanDispatchId $s1bId -PlanVerify $s1bVerify
    $s1bFacts['runner -PlanOnly exit / worktree path lines'] = "$($s1bPlan.exit) / $($s1bPlan.hits)"
    $s1bFacts['runner -PlanOnly worktree path'] = $(if ($s1bPlan.path) { $s1bPlan.path } else { '(none)' })
    if (-not $s1bPlan.path) { throw "the pre-placed directory could not be read from the runner: $($s1bPlan.reason). No home is assumed in its place; nothing was spawned" }
    $s1bExpected = $s1bPlan.path

    # --- before, the spawn, after ------------------------------------------------------------------
    $s1bWtBefore = Get-S1bGitLines -Root $s1bMission -Argv @('worktree', 'list', '--porcelain')
    $s1bBrBefore = Get-S1bGitLines -Root $s1bMission -Argv @('for-each-ref', '--format=%(refname)', 'refs/heads')
    $s1bPrevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $s1bRunOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $s1bRunner -MissionRoot $s1bMission -Dispatch $s1bId -VerifyCommand $s1bVerify 2>&1 | ForEach-Object { "$_" })
        $s1bRunExit = "$LASTEXITCODE"
    } finally { $ErrorActionPreference = $s1bPrevEap }
    $s1bWtAfter = Get-S1bGitLines -Root $s1bMission -Argv @('worktree', 'list', '--porcelain')
    $s1bBrAfter = Get-S1bGitLines -Root $s1bMission -Argv @('for-each-ref', '--format=%(refname)', 'refs/heads')

    $s1bWtKeysBefore = @($s1bWtBefore.lines | Where-Object { $_ -match '^worktree ' } | ForEach-Object { ConvertTo-S1bPathKey ($_.Substring(9)) })
    $s1bWtKeysAfter  = @($s1bWtAfter.lines  | Where-Object { $_ -match '^worktree ' } | ForEach-Object { ConvertTo-S1bPathKey ($_.Substring(9)) })
    $s1bBrNamesBefore = @($s1bBrBefore.lines | Where-Object { $_ -match '^refs/heads/' })
    $s1bBrNamesAfter  = @($s1bBrAfter.lines  | Where-Object { $_ -match '^refs/heads/' })

    # --- the runner's record ------------------------------------------------------------------------
    $s1bAnchorsPath = Join-Path $s1bMission ".mission\dispatches\$s1bId.anchors.yaml"
    $s1bAnc = ReadText $s1bAnchorsPath
    $s1bInErr = $false
    foreach ($s1bLine in @($s1bAnc -split "`r?`n")) {
        if ($s1bLine -match '^git_errors:') { $s1bInErr = $true; continue }
        if ($s1bInErr) { if ($s1bLine -match '^  - (.*)$') { $s1bGitErrors += $Matches[1] } else { $s1bInErr = $false } }
    }
    $s1bCutErrors = @($s1bGitErrors | Where-Object { $_ -match 'worktree add|ff-only|NOT an ancestor|no worktree named|worktree list failed|rev-parse failed|not the tree this runner prepared|harness worktree' })

    # --- the CLI's own account: every init event in the stream the runner captured ------------------
    $s1bStreamPath = Get-S1bAnchorValue -Text $s1bAnc -Key 'runner_stream'
    if (-not $s1bStreamPath) { $s1bStreamPath = Join-Path $s1bMission ".mission-runtime\evidence\session-$s1bId\runner-stream.jsonl" }
    $s1bJsonObjects = 0
    $s1bInitVersion = ''
    $s1bInitModel = ''
    if (Test-Path -LiteralPath $s1bStreamPath) {
        # JavaScriptSerializer, not ConvertFrom-Json: PS 5.1's ConvertFrom-Json throws on any object
        # whose keys differ only by case, and a tool input inside the stream may carry one. A line
        # that threw would be skipped, and an init event skipped that way would read as absent.
        # PowerShell 7 has no System.Web.Extensions (a .NET Framework assembly); there ConvertFrom-Json -AsHashtable reads
        # keys that differ only by case as the serializer does (UI-2 S1c A-13, register row 522).
        $s1bSer = $null
        if ($PSVersionTable.PSEdition -ne 'Core') {
            Add-Type -AssemblyName System.Web.Extensions
            $s1bSer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
            $s1bSer.MaxJsonLength = [int]::MaxValue
        }
        foreach ($s1bLine in [System.IO.File]::ReadAllLines($s1bStreamPath)) {
            $s1bT = $s1bLine.Trim()
            if (-not $s1bT.StartsWith('{')) { continue }
            $s1bObj = $null
            try { if ($null -ne $s1bSer) { $s1bObj = $s1bSer.DeserializeObject($s1bT) } else { $s1bObj = ConvertFrom-Json -InputObject $s1bT -AsHashtable } } catch { continue }
            if ($s1bObj -isnot [System.Collections.IDictionary]) { continue }
            $s1bJsonObjects++
            if (([string]$s1bObj['type'] -ceq 'system') -and ([string]$s1bObj['subtype'] -ceq 'init')) {
                $s1bInitCwds += ConvertTo-S1bPathKey ([string]$s1bObj['cwd'])
                if (-not $s1bInitVersion) { $s1bInitVersion = [string]$s1bObj['claude_code_version'] }
                if (-not $s1bInitModel) { $s1bInitModel = [string]$s1bObj['model'] }
                $s1bMem = $s1bObj['memory_paths']
                if ((-not $s1bProjectDir) -and ($s1bMem -is [System.Collections.IDictionary]) -and $s1bMem['auto']) {
                    $s1bProjectDir = Split-Path -Parent (([string]$s1bMem['auto']).TrimEnd('\', '/'))
                }
            }
        }
    }

    # --- git, asked by this member after the run -----------------------------------------------------
    $s1bReflog = Get-S1bGitLines -Root $s1bMission -Argv @('reflog', 'show', '--format=%gs', $s1bBranch)
    $s1bCreated = @($s1bReflog.lines | Where-Object { $_ -match '^branch: Created from ' })
    $s1bReflogFrom = ''
    if ($s1bCreated.Count -gt 0) { if ($s1bCreated[$s1bCreated.Count - 1] -match '^branch: Created from (\S+)') { $s1bReflogFrom = $Matches[1] } }
    $s1bTreeTip = ''
    $s1bGitDescends = $false
    if (Test-Path -LiteralPath $s1bExpected) {
        $s1bTreeTip = (GitOut -Root $s1bExpected -Argv @('rev-parse', 'HEAD')).out
        if ($s1bTreeTip -match '^[0-9a-f]{40}$') {
            $s1bGitDescends = ((GitOut -Root $s1bMission -Argv @('merge-base', '--is-ancestor', $s1bBase, $s1bTreeTip)).exit -eq 0)
        }
    }

    $s1bEvidence = [pscustomobject]@{
        base               = $s1bBase
        expectedKey        = (ConvertTo-S1bPathKey $s1bExpected)
        expectedBranch     = $s1bBranch
        runnerCutLine      = (@($s1bRunOut | Where-Object { $_ -like "*worktree cut at the declared base_head_at_authoring $s1bBase*" }).Count -ge 1)
        ancBaseField       = (Get-S1bAnchorValue -Text $s1bAnc -Key 'declared_base_field')
        ancDeclaredBase    = (Get-S1bAnchorValue -Text $s1bAnc -Key 'declared_base')
        ancHonoured        = (Get-S1bAnchorValue -Text $s1bAnc -Key 'worktree_base_honoured')
        ancObserved        = (Get-S1bAnchorValue -Text $s1bAnc -Key 'worktree_base_observed')
        ancDescends        = (Get-S1bAnchorValue -Text $s1bAnc -Key 'worktree_base_still_descends')
        ancPathKey         = (ConvertTo-S1bPathKey (Get-S1bAnchorValue -Text $s1bAnc -Key 'worktree_path'))
        reflogFrom         = $s1bReflogFrom
        cutErrors          = @($s1bCutErrors)
        gitDescends        = $s1bGitDescends
        initCwds           = @($s1bInitCwds)
        jsonObjects        = $s1bJsonObjects
        wtAdded            = @($s1bWtKeysAfter | Where-Object { $s1bWtKeysBefore -notcontains $_ })
        wtRemoved          = @($s1bWtKeysBefore | Where-Object { $s1bWtKeysAfter -notcontains $_ })
        brAdded            = @($s1bBrNamesAfter | Where-Object { $s1bBrNamesBefore -cnotcontains $_ })
        brRemoved          = @($s1bBrNamesBefore | Where-Object { $s1bBrNamesAfter -cnotcontains $_ })
        workerExit         = (Get-S1bAnchorValue -Text $s1bAnc -Key 'worker_exit_code')
        anchorsThisRun     = ((Get-S1bAnchorValue -Text $s1bAnc -Key 'dispatch_sha256') -eq $s1bDispatchSha)
        baseDiscriminating = $s1bDiscriminating
    }
    $s1bRows = Test-S1bReuse -Ev $s1bEvidence
    $s1bFacts['runner exit (0 or 3 expected)'] = $s1bRunExit
    $s1bFacts['worktree lists read (before / after exit)'] = "$($s1bWtBefore.exit) / $($s1bWtAfter.exit)"
    $s1bFacts['worktrees before / after'] = "$($s1bWtKeysBefore.Count) / $($s1bWtKeysAfter.Count)"
    $s1bFacts['branches before / after'] = "$($s1bBrNamesBefore.Count) / $($s1bBrNamesAfter.Count)"
    $s1bFacts['stream JSON objects / init events'] = "$s1bJsonObjects / $($s1bInitCwds.Count)"
    $s1bFacts['init cwd (normalised)'] = $(if ($s1bInitCwds.Count) { ($s1bInitCwds | Select-Object -Unique) -join ' ; ' } else { '(no init event)' })
    $s1bFacts['pre-placed directory (normalised)'] = $s1bEvidence.expectedKey
    $s1bFacts['init claude_code_version / model'] = "$s1bInitVersion / $s1bInitModel"
    $s1bFacts['reflog: Created from'] = $(if ($s1bReflogFrom) { $s1bReflogFrom } else { '(no creation line)' })
    $s1bFacts['tree HEAD after the run'] = $s1bTreeTip
    $s1bFacts['anchors worktree_base_still_descends'] = $s1bEvidence.ancDescends

    # --- the controls: the same predicate over this run's evidence, each copy carrying one shape ------
    $s1bSibling = ConvertTo-S1bPathKey ($s1bExpected + '-2')
    $s1bMissionKey = ConvertTo-S1bPathKey $s1bMission
    $s1bControlSpecs = @(
        [pscustomobject]@{ name = 'the CLI cut its own tree beside the pre-placed one'; targets = @('(2)', '(4)')
                           change = @{ initCwds = @($s1bSibling); wtAdded = @($s1bEvidence.expectedKey, $s1bSibling); brAdded = @($s1bBranch, ($s1bBranch + '-2')) } }
        [pscustomobject]@{ name = 'the CLI ran the worker in the mission root'; targets = @('(2)')
                           change = @{ initCwds = @($s1bMissionKey) } }
        [pscustomobject]@{ name = 'the CLI reset the reused tree to origin/main'; targets = @('(3)')
                           change = @{ ancDescends = 'false'; gitDescends = $false
                                       cutErrors = @("the declared base $s1bBase is NOT an ancestor of the worktree tip $($s1bFacts['fixture origin/main'])") } }
        [pscustomobject]@{ name = 'the stream carries no init event'; targets = @('(5)')
                           change = @{ initCwds = @() } }
    )
    foreach ($s1bSpec in $s1bControlSpecs) {
        $s1bCr = Test-S1bReuse -Ev (Copy-S1bEvidence -Ev $s1bEvidence -Change $s1bSpec.change)
        $s1bRedOn = @()
        foreach ($s1bTg in @($s1bSpec.targets)) {
            if (@($s1bCr.Keys | Where-Object { $_.StartsWith($s1bTg) -and (-not $s1bCr[$_]) }).Count -gt 0) { $s1bRedOn += $s1bTg }
        }
        $s1bControls += [pscustomobject]@{
            name  = $s1bSpec.name
            want  = (@($s1bSpec.targets) -join ' ')
            redOn = ($s1bRedOn -join ' ')
            ok    = (($s1bRedOn.Count -eq @($s1bSpec.targets).Count) -and ($s1bCr.Values -contains $false))
        }
    }
} catch {
    $s1bError = $_.Exception.Message
} finally {
    if (Test-Path -LiteralPath $s1bRoot) { Remove-Item -LiteralPath $s1bRoot -Recurse -Force -ErrorAction SilentlyContinue }
    $s1bRemoved = -not (Test-Path -LiteralPath $s1bRoot)
}
}

$s1bLiveOk = ($null -ne $s1bRows) -and (-not ($s1bRows.Values -contains $false))
$s1bControlsOk = ($s1bControls.Count -eq 4) -and (@($s1bControls | Where-Object { -not $_.ok }).Count -eq 0)
$s1bOk = ((-not $s1bError) -and $s1bSetupOk -and $s1bLiveOk -and $s1bControlsOk)

# A RED S-1b IS NOT ALWAYS A REUSE FINDING, AND THE DETAIL'S FIRST VERDICT LINE SAYS WHICH KIND IT IS
# (on its review). A CLI that cannot run a worker at all -- missing, signed out, over a spend
# limit, offline -- leaves no init event, and (2) and (5) then go red beside a tree nobody used; a
# runner that refused before the spawn looks the same from here. That STAYS RED: nothing was
# measured, and turning "could not look" into green or into a skip is the silent kind of wrong. What
# this changes is only what a reader is told to read the red as, so that a billing failure is not
# taken for a CLI that stopped reusing. The kinds are tried in this order, and the first that fits
# is printed.
$s1bReadAs = ''
if ($s1bOk) {
    $s1bReadAs = 'GREEN -- the CLI ran the worker in the pre-placed tree at the declared base, and the predicate was shown able to fail.'
} elseif ($null -eq $s1bRows) {
    $s1bReadAs = 'RED, BUT NOT A REUSE FINDING -- the member stopped before any run could be judged (see THE MEMBER STOPPED). Whether the CLI reuses was NOT measured.'
} elseif (@($s1bInitCwds).Count -eq 0) {
    $s1bReadAs = "RED, BUT NOT A REUSE FINDING -- THE CLI DID NOT RUN A WORKER: the stream holds no init event (runner exit $s1bRunExit). A CLI that is missing, signed out, over a spend limit or offline reads like this, and so does a runner that refused before the spawn (see the runner output tail). Whether the CLI reuses was NOT measured."
} elseif (@($s1bRows.Keys | Where-Object { ($_ -match '^\([1-4]\)') -and (-not $s1bRows[$_]) }).Count -gt 0) {
    $s1bReadAs = 'RED ON REUSE -- the CLI ran a worker (an init event is present) and at least one of properties (1) to (4) failed. This is the regression this member guards; read the MISS rows.'
} elseif (@($s1bRows.Keys | Where-Object { ($_ -match '^\(5\)') -and (-not $s1bRows[$_]) }).Count -gt 0) {
    $s1bReadAs = 'RED ON NON-VACUITY ONLY -- the CLI ran a worker and (1) to (4) held, but a (5) row failed, so this run cannot vouch for itself. Not a reuse finding on its own; read the MISS rows.'
} elseif (-not $s1bControlsOk) {
    $s1bReadAs = 'RED ON THE CONTROLS -- the live run held, but the predicate was not shown able to fail on every altered copy. A blind predicate, not a reuse finding.'
} else {
    $s1bReadAs = 'RED -- read the rows, facts and setup steps below.'
}

$s1bRowText = ''
if ($null -ne $s1bRows) { foreach ($s1bK in $s1bRows.Keys) { $s1bRowText += "      [$(if ($s1bRows[$s1bK]) { 'ok  ' } else { 'MISS' })] $s1bK`n" } }
else { $s1bRowText = "      (not judged -- the member stopped before the run could be read)`n" }
$s1bFactText = ''
foreach ($s1bK in $s1bFacts.Keys) { $s1bFactText += ("      {0,-48} : {1}`n" -f $s1bK, $s1bFacts[$s1bK]) }
$s1bStepText = ''
foreach ($s1bS in $s1bSteps) { $s1bStepText += ("      {0,-64} exit {1}`n" -f $s1bS.name, $s1bS.exit) }
$s1bControlText = ''
foreach ($s1bC in $s1bControls) { $s1bControlText += ("      [{0}] {1} -- must go red on {2}; red on: {3}`n" -f $(if ($s1bC.ok) { 'ok  ' } else { 'MISS' }), $s1bC.name, $s1bC.want, $(if ($s1bC.redOn) { $s1bC.redOn } else { '(nothing)' })) }
if (-not $s1bControlText) { $s1bControlText = "      (not run)`n" }
$s1bErrorsText = $(if ($s1bGitErrors.Count) { ($s1bGitErrors | ForEach-Object { "      - $_" }) -join "`n" } else { '      (none)' })
$s1bTail = $(if ((-not $s1bOk) -and $s1bRunOut.Count) { (($s1bRunOut | Select-Object -Last 15) | ForEach-Object { "      | $_" }) -join "`n" } else { '      (shown only when this member fails)' })

$s1bDetail = @"
    claude --version                     : $s1bCliVersion
    $(if ($s1bError) { ">>> THE MEMBER STOPPED: $s1bError" } else { 'the member ran to the end' })
    READ THIS RESULT AS: $s1bReadAs
    FIXTURE (a clone of the smoke repository under %TEMP%\s1b; the smoke repo and its origin are only read):
$s1bStepText$s1bFactText    THE FIVE PROPERTIES, judged on the live run (one real small-fast worker, the real runner, verify stubbed):
$s1bRowText    THE PREDICATE CAN FAIL -- the same function over four copies of this run's evidence:
$s1bControlText    git_errors the runner recorded:
$s1bErrorsText
    runner output tail:
$s1bTail
    LEFT BEHIND: fixture removed = $s1bRemoved; the CLI's per-project directory for the fixture repository:
      $(if ($s1bProjectDir) { "$s1bProjectDir (exists: $(Test-Path -LiteralPath $s1bProjectDir); fixed name, one per host, the CLI's state)" } else { '(not reported by the init event)' })
      and a projects entry keyed by the fixture path in the user's GLOBAL ~/.claude.json, whose
      activeWorktreeSession names the worktree this member has just deleted. The CLI writes it, it
      persists, and the next run starts with it present; this member neither reads nor removes it.
    WHAT THIS DOES NOT CLAIM: the controls prove the predicate can go red on four altered copies of this
    run's evidence; they do not exercise the stream, reflog or worktree-list parsing, and they are not a
    live CLI that stops reusing. The regression's own shape -- honoured, then the CLI recreates the tree and
    resets its branch to origin/main -- is not summoned by this run; it was driven once, live, through
    this member, which went red on the three (3) rows that read the tree after the run (see the comment
    above S-1b). The run is one CLI build on one host, and the ADR-022 gate was stubbed because WP-2 R-1
    measures it. A green here says the CLI installed on THIS host reuses.
"@
$s1bTitle = 'the CLI runs a real worker in the tree the runner pre-placed, at the declared base, and cuts no tree of its own'
if ($s1bSkip) {
    Check -Id 'S-1b' -Title ($s1bTitle + '   [SKIPPED -- ' + $s1bSkip + ']') -Ok $false -Skipped `
          -Detail ("    SKIPPED: $s1bSkip`n    NOTHING WAS RUN: no clone, no CLI call, %TEMP%\s1b untouched. Hand this member a live smoke repository (-SmokeRoot or LAM_SMOKE_ROOT) to measure it; that costs one billed small-fast spawn.")
} elseif ($s1bGuardFail) {
    # RED, AND STILL NOT A REUSE FINDING: the member stopped at its guard, so whether the CLI reuses was
    # not measured -- but a live smoke repository that cannot carry this fixture is a failure to say so.
    Check -Id 'S-1b' -Title ($s1bTitle + '   [NOT DRIVEN -- the live smoke repository cannot carry the fixture]') -Ok $false `
          -Detail ("    NOT DRIVEN: $s1bGuardFail`n    NOTHING WAS RUN: no clone, no CLI call, %TEMP%\s1b untouched -- nothing was spawned. RED, BUT NOT A REUSE FINDING: whether the CLI reuses was NOT measured; build the smoke mission as described (a bare origin beside it, its supersession ratifications on disk) and run again.")
} else {
    Check -Id 'S-1b' -Title $s1bTitle -Ok $s1bOk -Detail $s1bDetail
}

# =============================================================================================
# S-2 -- validator swarm, attempt 1: two results, exactly one FAIL on the planted assertion
# =============================================================================================
$a1Results = @()
if (Test-Path -LiteralPath $valDir) {
    $a1Results = @(Get-ChildItem -LiteralPath $valDir -File -Filter '*attempt-1*.yaml' -ErrorAction SilentlyContinue)
}
$a1Pass = 0; $a1Fail = 0; $failedAssertions = @()
foreach ($f in $a1Results) {
    $t = ReadText $f.FullName
    if ($t -match '(?m)^verdict:\s*pass\s*$')  { $a1Pass++ }
    if ($t -match '(?m)^verdict:\s*fail\s*$')  {
        $a1Fail++
        if ($t -match '(?m)^assertion_id:\s*(\S+)') { $failedAssertions += $Matches[1] }
    }
}
$probeFile = Join-Path $valDir 'isolation-probe.yaml'
$probeText = ReadText $probeFile
$probeClean = ($probeText -match '(?m)^reported_parent_knowledge:\s*none\s*$')
$detail = @"
    attempt-1 validator results : $($a1Results.Count)   (expect 2)
    pass / fail                 : $a1Pass / $a1Fail   (expect 1 / 1 -- one FAIL on the planted assertion)
    failed assertion(s)         : $(if ($failedAssertions.Count) { $failedAssertions -join ', ' } else { '(none)' })
    isolation probe recorded    : $(Test-Path -LiteralPath $probeFile)
    probe reported NO parent knowledge : $probeClean   (v2.3 SS9.3 precondition, PROBED not assumed)
"@
Check -Id 'S-2' -Title 'two fresh validators, one FAIL on the planted assertion, isolation probed first' `
      -Ok (($a1Results.Count -eq 2) -and ($a1Fail -eq 1) -and ($a1Pass -eq 1) -and $probeClean) -Detail $detail

# =============================================================================================
# S-3 -- rework D-2 executed WITHOUT any gate; re-validation 2/2 PASS
# =============================================================================================
$d2        = Join-Path $dispatchDir 'D-2.yaml'
$d2Handoff = Join-Path $dispatchDir 'D-2.handoff.yaml'
$d2Text    = ReadText $d2
$a2Results = @()
if (Test-Path -LiteralPath $valDir) {
    $a2Results = @(Get-ChildItem -LiteralPath $valDir -File -Filter '*attempt-2*.yaml' -ErrorAction SilentlyContinue)
}
$a2Pass = 0
foreach ($f in $a2Results) { if ((ReadText $f.FullName) -match '(?m)^verdict:\s*pass\s*$') { $a2Pass++ } }
# "executed without any gate": a rework dispatch is the lowest-judgement dispatch there is --
# contract plus failure evidence fully determine it (design SS9.5 rung L2) -- so no gate artifact
# of kind `dispatch` may exist for it.
$dispatchGate = Join-Path $gatesDir 'dispatch-D-2.yaml'
$noGate = -not (Test-Path -LiteralPath $dispatchGate)
$detail = @"
    D-2 rework dispatch exists      : $(Test-Path -LiteralPath $d2)
    it is kind: rework              : $($d2Text -match '(?m)^kind:\s*rework')
    it carries rework_evidence      : $($d2Text -match 'rework_evidence')
    handoff exists and is not rejected : $((Test-Path -LiteralPath $d2Handoff) -and ((ReadText $d2Handoff) -notmatch '(?m)^status:\s*rejected'))
    NO dispatch gate was required   : $noGate   (expect True -- S-3 runs without any gate)
    attempt-2 results / passing     : $($a2Results.Count) / $a2Pass   (expect 2 / 2)
"@
Check -Id 'S-3' -Title 'rework D-2 runs with no gate and re-validation is 2/2 PASS' `
      -Ok ((Test-Path -LiteralPath $d2) -and $noGate -and ($a2Results.Count -eq 2) -and ($a2Pass -eq 2)) -Detail $detail

# =============================================================================================
# S-4 -- push blocked without a gate; then, after the OPERATOR's gate, origin matches local
# =============================================================================================
# =============================================================================================
# S-4(a) IS MEASURED FROM ARTIFACTS, NOT RE-SIMULATED.
# =============================================================================================
# THIS MEMBER USED TO MUTATE THE PLANE IT GRADES. It piped a synthetic push payload through the
# REAL guard with CLAUDE_PROJECT_DIR pointed at the smoke root -- and H-2 makes every deny write a
# record, so each run appended another `_denied` entry into `.mission-runtime/evidence/session-wp6`:
# a session with no manifest, which can never finalize, now holding dozens of them. The round-3
# validator declined to run this instrument for exactly that reason and measured from artifacts
# instead, which is E33's own lesson arriving via this build's own instrument.
#
# THE RECORD IS BETTER EVIDENCE THAN THE SIMULATION ANYWAY. S-4(a) asks whether the push WAS blocked
# while no gate existed -- a historical fact about the smoke run. A fresh probe today re-answers a
# different question (does it block NOW), and T-2 in WP-4 already covers that exhaustively across
# fifteen spellings and the whole gate lifecycle. So this reads the DURABLE denials the hooks wrote
# at the time, and asserts the ones that predate the operator's gate.
#
# The 49 records already accumulated are left exactly where they are: they are the honest residue of
# how this member used to work, and deleting evidence to tidy up is the one thing this build does not
# do. They are disclosed.
$gateCreatedAt = $null
$preGateDenials = @()
$denialScanned = 0
if (Test-Path -LiteralPath $gatesDir) {
    foreach ($g in @(Get-ChildItem -LiteralPath $gatesDir -File -Filter 'push-*.yaml' -ErrorAction SilentlyContinue)) {
        $gt = ReadText $g.FullName
        if ($gt -match '(?m)^created_at:\s*(\S+)') {
            [datetime]$parsed = [datetime]::MinValue
            if ([datetime]::TryParse($Matches[1], [ref]$parsed)) { $gateCreatedAt = $parsed.ToUniversalTime() }
        }
    }
}
foreach ($lg in @(Get-ChildItem -LiteralPath $SmokeRoot -Recurse -File -Force -Filter 'log.jsonl' -ErrorAction SilentlyContinue)) {
    foreach ($line in [System.IO.File]::ReadAllLines($lg.FullName)) {
        if (-not $line.Trim()) { continue }
        $rec = $null
        try { $rec = $line | ConvertFrom-Json } catch { continue }
        if ($null -eq $rec) { continue }
        if ([string]$rec.tool -ne '_denied') { continue }
        $reason = [string]$rec.reason
        if ($reason -notmatch 'push is BLOCKED|no gate directory') { continue }
        $denialScanned++
        if ($null -eq $gateCreatedAt) { continue }
        [datetime]$rts = [datetime]::MinValue
        # PowerShell 7's ConvertFrom-Json hands an ISO timestamp over as a [datetime] (its UTC kind kept); [string] of it
        # drops the kind and the zone, and TryParse then reads the UTC time as local. Taken as it comes; 5.1 keeps the
        # string (UI-2 S1c A-13, register row 522).
        if ($rec.ts -is [datetime]) { $rts = $rec.ts }
        elseif (-not [datetime]::TryParse([string]$rec.ts, [ref]$rts)) { continue }
        if ($rts.ToUniversalTime() -lt $gateCreatedAt) { $preGateDenials += $rec }
    }
}
$pgExit = $(if ($preGateDenials.Count -gt 0) { 2 } else { 0 })
$pgText = "measured from $denialScanned durable denial record(s) in the plane; $($preGateDenials.Count) predate the operator's gate"

$pushGates = @()
if (Test-Path -LiteralPath $gatesDir) {
    $pushGates = @(Get-ChildItem -LiteralPath $gatesDir -File -Filter 'push-*.yaml' -ErrorAction SilentlyContinue)
}
# ASKED ONLY OF A TOP-LEVEL WORK TREE: below one, HEAD is the enclosing repository's, and outside any
# repository GitOut hands back git's error text, which is not a tip. A LIVE root git does not answer
# for is not asked, and the row that needs the tip MISSES; only a FILES-ONLY root skips it.
$localTip  = ''
if ($smokeIsRepoTop) {
    $localTipGot = GitOut -Root $SmokeRoot -Argv @('rev-parse','HEAD')
    if (($localTipGot.exit -eq 0) -and ($localTipGot.out -match '^[0-9a-f]{40}$')) { $localTip = $localTipGot.out }
}

# ================================================================================================
# S-4 ENUMERATES EVERY REF OF THE GATE-DECLARED ORIGIN.
# ================================================================================================
# THREE defects were driven out of the four lines this replaces, and they compound:
#
#  1. `ls-remote origin main` TOOK THE FIRST 40-HEX IT SAW. `ls-remote` matches at slash boundaries
#     and sorts by refname, so `refs/heads/aaa/main` is returned BEFORE `refs/heads/main`. Driven by
#     an independent reader: the authorized sha parked on a decoy ref, an unauthorized commit on the
#     real one, and S-4 reported PASS. The control -- unauthorized commit, no decoy -- correctly
#     FAILED, so the harness was not blind; the selection was.
#
#  2. `origin` RESOLVED THROUGH `.git/config`. The acceptance contract rules that file an unprotectable control
#     surface. Repointing `remote.origin.url` at a decoy bare repo also produced PASS while the real
#     origin held an unauthorized commit -- so the same capability that removes the pre-push hook
#     also blinded the detector that was supposed to catch its removal. The origin is now read from
#     the GATE ARTIFACT, which an agent cannot write (T-3).
#
#  3. IT ONLY EVER LOOKED AT `main`. "Origin holds only what a gate authorized" is a statement about
#     the WHOLE remote; a member that inspects one ref cannot deliver it, however it is fixed. Every
#     ref is now enumerated and any ref no gate authorized is a failure.
# A SECOND DEFINITION OF "WHAT REFS DOES THIS ORIGIN HOLD" -- SAID PLAINLY, BECAUSE IT USED TO SAY
# "ONE DEFINITION" WHILE THE COMMENT TWENTY LINES BELOW ADMITTED IT WAS THE SECOND, AND BOTH
# SENTENCES SHIPPED (V-1 round 16, WP-6 review finding).
#
# The library owns the other one. Keeping this copy was argued as a disclosed duplication that bought
# drift-detection; it bought nothing, because both copies carried the IDENTICAL defect -- it was
# driven in both -- so there was no divergence to detect, and the same cure then had to be applied
# twice. That is the doubled repair surface the disclosure was meant to justify avoiding.
#
# It is still not merged: dot-sourcing the hooks library here imports Set-StrictMode into 900 lines
# that have never run under it, which is its own change and needs its own falsification. What has
# changed is that the file no longer claims to be what it is not, and member S-4d below ASSERTS THE
# TWO IMPLEMENTATIONS AGREE -- so the next divergence is caught by the suite rather than by a reader
# noticing that two comments contradict each other.
#
# It exists so the reader can be driven somewhere the smoke
# origin cannot take it. The smoke origin advertises exactly ONE line -- its HEAD symref dangles to a
# nonexistent refs/heads/master -- and a one-element array joins to itself, which is the only reason
# the join defect below survived. A member that can only ever see a one-line remote cannot find it.
function Read-OriginRefs {
    param([string]$Root, [string]$Url)
    # NOT `GitOut`: it returns `("$o").Trim()`, and `"$array"` joins git's output LINES with $OFS --
    # a SPACE. The caller then split on newlines and matched an anchored per-line regex, so any
    # multi-line ls-remote arrived as ONE line, matched nothing, and produced an EMPTY ref table
    # while the member reported "NO ref carries a sha no gate authorized: True" -- vacuously true of
    # an origin it never read (V-1 round 13, WP-6).
    # AND NOT THROUGH THE REPOSITORY'S OWN CONFIG (V-1 round 15, WP-6 review finding -- CRITICAL, driven).
    #
    # This read was `git -C $Root ls-remote $Url`, INSIDE the repository, with all config live. One
    # line -- `git config url.<decoy>.insteadOf <declared>` -- redirects it to a decoy while this
    # member prints "DECLARED origin (from the gate, never .git/config)". Driven on the shipped file:
    # S-4 flipped FAIL to PASS while the real origin still advertised the backdoor ref. The acceptance contract
    # makes S-4 the DETECTOR and the top rung while D4 is unbuilt, so a steerable read here is not a
    # test defect -- it is the guarantee.
    #
    # The library's `Get-EvidenceRemoteRefs` was hardened for exactly this in round 14 and the cure
    # never reached this file: the commit that carried it touched six files, not this one. THE HEADER ABOVE
    # CALLS THIS "ONE DEFINITION" AND IT IS THE SECOND; a comment asserting singularity does not
    # create it.
    #
    # Resolve relative -> absolute USING $Root (a declared origin may legitimately be `../o.git`),
    # then ASK FROM OUTSIDE the repository with global and system config suppressed. Driven in round
    # 14: `-c url.<x>.insteadOf=` does NOT neutralise it; reading from a neutral cwd does.
    $refs = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    $askUrl = $Url
    # A ROOTED path is used as given: Join-Path of a rooted child onto $Root is no path at all, and the
    # answer must not depend on GetFullPath throwing on it (which is all that used to send it through).
    if ($Root -and $Url -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://' -and $Url -notmatch '^[^/]+@' -and -not [IO.Path]::IsPathRooted($Url)) {
        try { $askUrl = [IO.Path]::GetFullPath((Join-Path $Root $Url)) } catch { $askUrl = $Url }
    }
    # NAME THE CONFIG FILES; DO NOT GUESS WHERE GIT LOOKS (V-1 round 16, WP-6 review finding -- CRITICAL).
    # Pointing HOME / USERPROFILE / XDG_CONFIG_HOME at the TEMP ROOT made `%TEMP%\.gitconfig` live
    # GLOBAL config in a world-writable directory -- this member was driven from FAIL to PASS by
    # planting one file there, while still printing "DECLARED origin (from the gate, never
    # .git/config)". The isolation relocated the surface rather than removing it.
    #
    # GIT_CONFIG_GLOBAL / GIT_CONFIG_SYSTEM aim those layers at files that cannot exist.
    # AND THAT CURE WAS ONE-THIRD INERT (V-1 round 17, WP-1 and WP-6 findings -- CRITICAL,
    # driven INDEPENDENTLY by two validators, each with the same strict-ancestor control, which is
    # what makes it a measurement rather than a reading of the manual).
    #
    #   * GIT_CEILING_DIRECTORIES was set to the directory being read FROM. A ceiling names
    #     directories git will not chdir UP INTO, and the starting directory never is one -- so it
    #     was no ceiling at all. Discovery climbed straight out into the temp root, and a bare
    #     `%TEMP%\.git\config` -- no repository, no mission, no guarded path, creatable by an
    #     ordinary tool call -- redirected this read to a decoy. Driven end to end: a real
    #     publication landed, the settle pass asked the DECOY, the gate stayed OPEN, and that SAME
    #     gate then authorized a SECOND real publication. Control: gate consumed, second push
    #     refused, origin left empty.
    #   * Round 15 closed `.git/config`. Round 16 closed `%TEMP%\.gitconfig`. Round 17 found
    #     `%TEMP%\.git\config`. Three cures, three named routes, each a ONE-DIRECTORY MOVE.
    #
    # SO THE LIST IS ABANDONED FOR A DEFAULT-DENY. Every `GIT_*` variable is removed for the duration
    # of the read and only the four this function actually needs are set back. That closes
    # GIT_CONFIG_COUNT/GIT_CONFIG_KEY_n/GIT_CONFIG_VALUE_n, GIT_CONFIG_PARAMETERS, GIT_DIR,
    # GIT_WORK_TREE and every route git adds in future BY CONSTRUCTION rather than by enumeration.
    # WP-1 and WP-6 findings each named four more live routes; the point of this shape is that
    # naming them was never going to terminate.
    #
    # AND THE CEILING IS NOW A STRICT ANCESTOR. Both directories are created here, microseconds
    # before use, so neither can be pre-planted: discovery starts in `<neutral>\read` and is
    # forbidden to climb into `<neutral>`.
    #
    # WHAT IS NOT DEFENDED, SAID PLAINLY RATHER THAN IMPLIED: `PATH`. Anyone who can set this
    # process's environment can replace `git` itself, and no GIT_* hygiene survives that. The
    # boundary drawn here is CONFIG INJECTION AND REPOSITORY DISCOVERY -- which is what the
    # file-plant route actually needed, and it is the route both validators drove.
    #
    # TRANSPORT VARIABLES ARE NO LONGER CLEARED, AND THE PARAGRAPH BELOW IS KEPT AS THE RECORD OF
    # WHY THEY WERE (V-1 round 18: a WP-1 finding drove UNCONFIRMABLE to a gate that stays open and
    # still authorizes; a WP-6 review finding showed the sweep never reached transport anyway, because it
    # matches the GIT_ name prefix and `http_proxy` / `ALL_PROXY` do not carry one -- four trials,
    # two controls, git routed through the host named in them). The reader now clears the CONFIG
    # namespace and restores twelve transport names by name.
    #
    # AND THIS COPY DID NOT HAVE THE CURE ITS OWN COMMENT DESCRIBED UNTIL ROUND 19 (WP-6 review finding).
    # The paragraph below travelled into both readers in round 17; round 18's transport fix went into
    # the library alone. The sentence was true of one function and false of the one it annotated, and
    # S-4d could not see it because both readers returned identical refs -- only the isolation shape
    # differed. Both now carry it.
    #
    # THE SUPERSEDED ARGUMENT, LEFT STANDING SO THE NEXT READER SEES WHAT WAS CLAIMED:
    # CLEARING TRANSPORT VARIABLES IS DELIBERATE AND IS A BEHAVIOUR CHANGE. An origin reachable only
    # through ambient `GIT_SSH_COMMAND` / `GIT_PROXY_COMMAND` now fails this read and is reported
    # UNCONFIRMABLE instead of being confirmed through a channel somebody else configured. For a
    # detector that is the correct direction -- and those variables can redirect the read outright,
    # so an allow-list containing them would not be an isolation at all. The shipped local-path
    # origins use no transport variables.
    #
    # THIS COPY IS DELIBERATE AND THE HEADER'S "ONE DEFINITION" IS STILL WRONG ABOVE. An instrument
    # that called the library's reader would inherit the library's defects and could never detect
    # them -- which is the argument the duplication was defended with. Round 16 backed that argument
    # with S-4d, and S-4d could not detect anything (V-1 round 17, WP-6 review finding). The argument is only
    # worth what the member behind it measures, so S-4d is rebuilt below to plant a steer and check
    # each reader against ground truth, rather than checking the two against each other on a fixture
    # with nothing to steer.
    $neutral = Join-Path ([IO.Path]::GetTempPath()) ('lam-neutral-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    $readDir = Join-Path $neutral 'read'
    $nowhere = Join-Path $neutral 'no-such-config'
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $svHome = $env:HOME; $svUp = $env:USERPROFILE; $svXdg = $env:XDG_CONFIG_HOME
    # THE TRANSPORT ALLOW-LIST AND THE CREDENTIAL FAMILY, WHICH THIS COPY DID NOT HAVE
    # (V-1 round 19, WP-6 review finding, driven). Round 18's cure landed in the library only, while the
    # comment above -- carried into BOTH copies by round 17 -- claimed this reader had it too.
    # The prose travelled and the code did not, and S-4d could not see it because both readers still
    # returned identical refs: only the isolation SHAPE differed.
    #
    # NOT COPIED FOR SAMENESS. Sameness is not what S-4d tests, and two identical readers would make
    # the duplication worthless. It is copied because without it this reader cannot read a
    # credential-gated origin either, and a witness that cannot see the origin is not a witness.
    $keepTransport = @(
        'GIT_SSH', 'GIT_SSH_COMMAND', 'GIT_SSH_VARIANT', 'GIT_PROXY_COMMAND',
        'GIT_SSL_CAINFO', 'GIT_SSL_CAPATH', 'GIT_SSL_CERT', 'GIT_SSL_KEY',
        'GIT_ASKPASS', 'GIT_TERMINAL_PROMPT', 'GIT_CURL_VERBOSE', 'GIT_TRACE'
    )
    $credHelpers = @()
    $prevCred2 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $ch2 = & git -C $Root config --get-regexp '^credential\.' 2>&1
        if ($LASTEXITCODE -eq 0) {
            foreach ($line2 in @($ch2)) {
                $t2 = "$line2".Trim()
                if (-not $t2) { continue }
                $sp2 = $t2.IndexOf(' ')
                if ($sp2 -lt 1) { continue }
                $credHelpers += ($t2.Substring(0, $sp2) + '=' + $t2.Substring($sp2 + 1))
            }
        }
    } catch { } finally { $ErrorActionPreference = $prevCred2 }
    $svGit = @{}
    foreach ($e in (Get-ChildItem Env: -ErrorAction SilentlyContinue)) {
        if ($e.Name -like 'GIT_*') { $svGit[$e.Name] = $e.Value }
    }
    try {
        $null = New-Item -ItemType Directory -Force -Path $readDir -ErrorAction SilentlyContinue
        # [NullString]::Value removes a variable under 5.1 and PowerShell 7 alike; a bare $null arrives as '' and under 7
        # leaves it set and empty (UI-2 S1c A-13, register row 522).
        foreach ($n in @($svGit.Keys)) { [Environment]::SetEnvironmentVariable($n, [NullString]::Value) }
        foreach ($n in $keepTransport) {
            if ($svGit.ContainsKey($n)) { [Environment]::SetEnvironmentVariable($n, $svGit[$n]) }
        }
        $env:HOME = $neutral; $env:USERPROFILE = $neutral; $env:XDG_CONFIG_HOME = $neutral
        $env:GIT_CONFIG_NOSYSTEM = '1'; $env:GIT_CONFIG_GLOBAL = $nowhere; $env:GIT_CONFIG_SYSTEM = $nowhere
        $env:GIT_CEILING_DIRECTORIES = $neutral
        $credArgv2 = @()
        foreach ($h2 in $credHelpers) { $credArgv2 += @('-c', $h2) }
        $lines = @(& git -C $readDir @credArgv2 ls-remote $askUrl 2>&1); $code = $LASTEXITCODE
    }
    finally {
        $env:HOME = $svHome; $env:USERPROFILE = $svUp; $env:XDG_CONFIG_HOME = $svXdg
        foreach ($n in @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GIT_CEILING_DIRECTORIES')) {
            [Environment]::SetEnvironmentVariable($n, [NullString]::Value)
        }
        foreach ($n in @($svGit.Keys)) { [Environment]::SetEnvironmentVariable($n, $svGit[$n]) }
        $ErrorActionPreference = $prev
        try { Remove-Item -LiteralPath $neutral -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
    if ($code -ne 0) { return [pscustomobject]@{ ok = $false; refs = $refs; lines = 0 } }
    foreach ($line in $lines) {
        $m = [regex]::Match("$line", '^([0-9a-f]{40})\s+(\S+)$')
        if ($m.Success) { $refs[$m.Groups[2].Value] = $m.Groups[1].Value }
    }
    return [pscustomobject]@{ ok = $true; refs = $refs; lines = @($lines).Count }
}

# ================================================================================================
# S-4c -- THE REF READER, DRIVEN AGAINST A MULTI-LINE ORIGIN (V-1 round 13, WP-6)
# ================================================================================================
# S-4's green was an ACCIDENT and this member exists so it cannot be one again. The live smoke origin
# advertises one line; every ordinary remote advertises HEAD as well as its branches. This builds a
# throwaway origin with a valid HEAD and two branches and asserts the reader sees all of them --
# which the joined-string version could not, at any count above one.
$s4cRoot = Join-Path $env:TEMP 's4c'
if (Test-Path -LiteralPath $s4cRoot) { Remove-Item -LiteralPath $s4cRoot -Recurse -Force }
$null = New-Item -ItemType Directory -Path $s4cRoot -Force
$s4cBare = Join-Path $s4cRoot 'o.git'
$s4cWork = Join-Path $s4cRoot 'w'
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
try {
    $null = & git init -q --bare $s4cBare 2>&1
    $null = & git init -q $s4cWork 2>&1
    $null = & git -C $s4cWork config user.email t@t 2>&1
    $null = & git -C $s4cWork config user.name t 2>&1
    [IO.File]::WriteAllText((Join-Path $s4cWork 'a.txt'), "a`n")
    $null = & git -C $s4cWork add -A 2>&1
    $null = & git -C $s4cWork commit -qm one 2>&1
    $null = & git -C $s4cWork branch -M main 2>&1
    $null = & git -C $s4cWork push -q $s4cBare main 2>&1
    $null = & git -C $s4cWork checkout -q -b second 2>&1
    [IO.File]::WriteAllText((Join-Path $s4cWork 'b.txt'), "b`n")
    $null = & git -C $s4cWork add -A 2>&1
    $null = & git -C $s4cWork commit -qm two 2>&1
    $null = & git -C $s4cWork push -q $s4cBare second 2>&1
    # A VALID HEAD, which is what every real remote has and the smoke origin does not.
    $null = & git --git-dir $s4cBare symbolic-ref HEAD refs/heads/main 2>&1
    $s4cRaw = @(& git -C $s4cWork ls-remote $s4cBare 2>&1 | Where-Object { "$_" -match '^[0-9a-f]{40}\s' }).Count
} finally { $ErrorActionPreference = $prevEap }
$s4cRead = Read-OriginRefs -Root $s4cWork -Url $s4cBare
$s4cDetail = @"
    A throwaway origin with a valid HEAD and two branches -- the ordinary shape of any real remote,
    and one the live smoke origin cannot provide because its HEAD symref dangles.
      lines git actually advertises      : $s4cRaw   (expect 3+ : HEAD, main, second)
      refs the reader parsed             : $($s4cRead.refs.Keys.Count)
      parsed == advertised               : $($s4cRead.refs.Keys.Count -eq $s4cRaw)   (expect True)
      HEAD present                       : $($s4cRead.refs.ContainsKey('HEAD'))
      refs/heads/main present            : $($s4cRead.refs.ContainsKey('refs/heads/main'))
      refs/heads/second present          : $($s4cRead.refs.ContainsKey('refs/heads/second'))
    BEFORE THE FIX this parsed ZERO of them: git's output ARRAY was joined with a space before the
    per-line regex ever saw it, so anything past one line matched nothing -- and the member that
    consumed it then reported "no ref carries an unauthorized sha" about an origin it never read.
"@
Check -Id 'S-4c' -Title 'the origin ref reader sees EVERY line a multi-line remote advertises' `
      -Ok ($s4cRead.ok -and $s4cRaw -ge 3 -and $s4cRead.refs.Keys.Count -eq $s4cRaw) -Detail $s4cDetail

# ================================================================================================
# S-4d -- BOTH ORIGIN READERS RESIST A PLANTED STEER (V-1 round 16 WP-6 review finding; rebuilt round 17)
# ================================================================================================
# THE ROUND-16 VERSION PASSED RATHER THAN DETECTED, AND WAS DRIVEN TO PROVE IT (WP-6 review finding, HIGH).
# It asked both readers the same question about a benign fixture and required the same answer. A
# validator regressed the LIBRARY reader all the way back to the round-15 shape -- zero isolation
# left -- and it still reported "same ref NAMES: True / same SHAS per ref: True" and PASSED. Worse,
# it passed in the same live run in which S-4 was being steered, because both copies steered
# IDENTICALLY. Agreement is not the property; RESISTANCE is, and two wrong answers agree.
#
# So the fixture now contains something to be steered BY, and the question changed from "do these
# two agree" to "does each still tell the truth while an attacker is talking". Ground truth is read
# a THIRD way -- `git --git-dir ... for-each-ref`, which goes to the object store and through no
# transport, url rewrite or discovery at all -- so neither reader under test is the standard the
# other is judged against.
#
# AND THE PLANT MUST BE PROVED TO WORK, which is the half whose absence made the old version
# vacuous. An UNISOLATED read is taken from inside the planted directory; if THAT is not steered,
# the plant never fired and this member reports itself INERT rather than green. WP-4 lost two
# harnesses this round to exactly that shape -- a battery whose only controls expect the safe
# answer cannot distinguish "defended" from "the payload never arrived".
$s4dDetail = ''
$s4dOk = $false
$s4dTmpSave = @{ TMP = $env:TMP; TEMP = $env:TEMP }
try {
    . (Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1')

    # --- the decoy, and the directory that will do the steering --------------------------------
    $s4dRoot = Join-Path $env:TEMP 's4d'
    if (Test-Path -LiteralPath $s4dRoot) { Remove-Item -LiteralPath $s4dRoot -Recurse -Force -ErrorAction SilentlyContinue }
    $null = New-Item -ItemType Directory -Path $s4dRoot -Force
    $s4dDecoy = Join-Path $s4dRoot 'decoy.git'
    $s4dPlant = Join-Path $s4dRoot 'plant'
    $s4dWork  = Join-Path $s4dRoot 'w'
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $null = & git init -q --bare $s4dDecoy 2>&1
        $null = & git init -q $s4dWork 2>&1
        $null = & git -C $s4dWork config user.email t@t 2>&1
        $null = & git -C $s4dWork config user.name t 2>&1
        [IO.File]::WriteAllText((Join-Path $s4dWork 'd.txt'), "decoy`n")
        $null = & git -C $s4dWork add -A 2>&1
        $null = & git -C $s4dWork commit -qm decoy 2>&1
        $null = & git -C $s4dWork branch -M main 2>&1
        $null = & git -C $s4dWork push -q $s4dDecoy main 2>&1
        # A ref the REAL origin does not have, so a steered read is recognisable by NAME and not
        # only by sha -- a decoy that merely differs in sha is harder to read in a failure report.
        $null = & git -C $s4dWork branch planted 2>&1
        $null = & git -C $s4dWork push -q $s4dDecoy planted 2>&1

        # GROUND TRUTH, THROUGH NEITHER READER. for-each-ref goes to the object store: no transport,
        # no url rewrite, no repository discovery, nothing this plant can reach.
        $s4dTruth = @{}
        foreach ($ln in @(& git --git-dir $s4cBare for-each-ref '--format=%(objectname) %(refname)' 2>&1)) {
            $mm = [regex]::Match("$ln", '^([0-9a-f]{40})\s+(\S+)$')
            if ($mm.Success) { $s4dTruth[$mm.Groups[2].Value] = $mm.Groups[1].Value }
        }

        # --- the plant ------------------------------------------------------------------------
        # A repository at an ANCESTOR of wherever the readers make their private directory, with one
        # url rewrite. TMP/TEMP is what `[IO.Path]::GetTempPath()` honours, so pointing them here
        # puts both readers' private directories inside the planted tree -- reproducing the round-17
        # CRITICAL without touching the host's real temp root.
        $null = New-Item -ItemType Directory -Path $s4dPlant -Force
        $null = & git init -q $s4dPlant 2>&1
        $null = & git -C $s4dPlant config ("url." + $s4dDecoy.Replace('\', '/') + ".insteadOf") $s4cBare 2>&1
        $env:TMP = $s4dPlant
        $env:TEMP = $s4dPlant

        # --- IS THE PLANT LIVE? The control that makes the rest mean anything. -----------------
        $s4dNaive = @{}
        foreach ($ln in @(& git -C $s4dPlant ls-remote $s4cBare 2>&1)) {
            $mm = [regex]::Match("$ln", '^([0-9a-f]{40})\s+(\S+)$')
            if ($mm.Success) { $s4dNaive[$mm.Groups[2].Value] = $mm.Groups[1].Value }
        }
        $s4dPlantLive = ($s4dNaive.ContainsKey('refs/heads/planted'))

        # AND THE PLANT ONLY REACHES A READER THAT SITES ITS PRIVATE DIRECTORY UNDER GetTempPath()
        # (V-1 round 18, WP-6 review finding, driven). "The plant is live" was measured by a read rooted AT
        # the plant, which is a weaker proposition than "the plant is on the ancestor path of where
        # these readers read" -- and the two were driven apart: a reader carrying the round-17
        # ceiling defect passed GREEN once its private directory moved to %LOCALAPPDATA%, printing
        # PLANT IS LIVE the whole time. That directory has moved in three consecutive rounds, so the
        # fourth relocation would turn this member into a green light.
        #
        # Where a black box reads cannot be proved from outside. What the member depends on CAN be
        # asserted: both readers derive their private directory from GetTempPath(), which TMP/TEMP
        # above redirects into the planted tree. If either stops doing that, this goes red and says
        # so, instead of passing over a defect it can no longer reach.
        # MEASURED, NOT GREPPED (V-1 round 19, WP-6 review finding, driven). The previous version searched
        # each reader's WHOLE FILE for `Join-Path ([IO.Path]::GetTempPath())` -- and in this file
        # that string occurs twice: once in the reader, once in THE ASSERTION'S OWN LITERAL. It
        # matched itself, so the instrument arm was True unconditionally and the fourth relocation
        # of the private read directory would have turned this member green, in the row written to
        # prevent exactly that.
        #
        # A reader's read location cannot be proved from outside, but it CAN be provoked: point
        # TMP/TEMP at a path that cannot be created -- its parent is a FILE -- and a reader that
        # derives its private directory from GetTempPath() must FAIL.
        #
        # THE CONTROL IS THE WHOLE ARGUMENT. "Both readers failed" says nothing about SITING on its
        # own: if git needed a usable TEMP for its own reasons, both would fail wherever they sited
        # their directory, and this row would pass for the wrong reason -- which is the defect being
        # repaired here. So bare git, through neither reader, runs under the SAME impossible
        # TMP/TEMP from an ordinary directory and must SUCCEED. Only then does a reader's failure
        # belong to the directory it tried to create. No source is read, so nothing matches itself.
        $s4dSiting = @()
        $s4dBlockFile = Join-Path $s4dRoot 'not-a-directory'
        [System.IO.File]::WriteAllText($s4dBlockFile, "x`n")
        $s4dImpossible = Join-Path $s4dBlockFile 'temp'
        $svT = @{ TMP = $env:TMP; TEMP = $env:TEMP }
        $s4dBareOk = $false
        try {
            $env:TMP = $s4dImpossible; $env:TEMP = $s4dImpossible
            $prevS4d = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $bareOut = @(& git -C $s4cWork ls-remote $s4cBare 2>&1)
            $s4dBareOk = ($LASTEXITCODE -eq 0 -and @($bareOut | Where-Object { "$_" -match '^[0-9a-f]{40}\s' }).Count -gt 0)
            $ErrorActionPreference = $prevS4d
            $probeMine = Read-OriginRefs -Root $s4cWork -Url $s4cBare
            $probeLib = Get-EvidenceRemoteRefs -Root $s4cWork -Url $s4cBare
        } finally { $env:TMP = $svT.TMP; $env:TEMP = $svT.TEMP }
        $s4dSiting += [pscustomobject]@{ name = 'CONTROL bare git'; sited = $s4dBareOk }
        $s4dSiting += [pscustomobject]@{ name = 'library reader'; sited = ($null -eq $probeLib) }
        $s4dSiting += [pscustomobject]@{ name = 'instrument reader'; sited = (-not ($probeMine -and $probeMine.ok)) }
        $s4dSitedOk = (@($s4dSiting | Where-Object { -not $_.sited }).Count -eq 0)

        # --- SECOND PLANT KIND: the ENVIRONMENT, which the file plant does not touch --------------
        # V-1 round 18, WP-6 review finding: deleting the GIT_* namespace clear -- the entire E116 cure --
        # left this member green, because a file at an ancestor is defended by the CEILING and the
        # clear defends something else. A member offered as a cure's non-vacuity witness has to
        # exercise the cure.
        # LIVENESS IS READ FROM A DIRECTORY CARRYING NO FILE PLANT (V-1 round 19, a WP-6 finding, driven).
        # This row used to read from $s4dPlant -- the directory that already carries the FILE plant --
        # so with the environment EMPTY it reported steered=True anyway. Measured: file-plant dir
        # steered=True with nothing set, clean dir steered=False. The row asserting "the env plant is
        # LIVE" was being satisfied by the other plant, and would have said True with the env triple
        # absent, misspelled or inert.
        $s4dClean = Join-Path $s4dRoot 'clean'
        $null = New-Item -ItemType Directory -Force -Path $s4dClean
        $null = & git -C $s4dClean init -q 2>&1
        $s4dNaive = {
            param([string]$Dir)
            $h = @{}
            foreach ($ln in @(& git -C $Dir ls-remote $s4cBare 2>&1)) {
                $mm = [regex]::Match("$ln", '^([0-9a-f]{40})\s+(\S+)$')
                if ($mm.Success) { $h[$mm.Groups[2].Value] = $mm.Groups[1].Value }
            }
            $h
        }
        $s4dInsteadKey = 'url.' + ($s4dDecoy.Replace('\', '/')) + '.insteadOf'

        # ROUTE 1 -- the COUNT/KEY_n/VALUE_n triple.
        $env:GIT_CONFIG_COUNT = '1'
        $env:GIT_CONFIG_KEY_0 = $s4dInsteadKey
        $env:GIT_CONFIG_VALUE_0 = $s4cBare
        $s4dEnvNaive = & $s4dNaive $s4dClean
        $s4dEnvPlantLive = ($s4dEnvNaive.ContainsKey('refs/heads/planted'))
        $s4dEnvMine = Read-OriginRefs -Root $s4cWork -Url $s4cBare
        $s4dEnvLib  = Get-EvidenceRemoteRefs -Root $s4cWork -Url $s4cBare
        $env:GIT_CONFIG_COUNT = $null; $env:GIT_CONFIG_KEY_0 = $null; $env:GIT_CONFIG_VALUE_0 = $null

        # ROUTE 2 -- GIT_CONFIG_PARAMETERS, a SECOND route the member did not witness (a WP-6 finding,
        # driven: it steers from a clean directory in both accepted spellings). Narrowing a cure to
        # the three names above would leave this member green while every read stayed redirected.
        $env:GIT_CONFIG_PARAMETERS = "'$s4dInsteadKey'='$s4cBare'"
        $s4dParamNaive = & $s4dNaive $s4dClean
        $s4dParamPlantLive = ($s4dParamNaive.ContainsKey('refs/heads/planted'))
        $s4dParamMine = Read-OriginRefs -Root $s4cWork -Url $s4cBare
        $s4dParamLib  = Get-EvidenceRemoteRefs -Root $s4cWork -Url $s4cBare
        $env:GIT_CONFIG_PARAMETERS = $null

        # --- the two readers under test, WITH the plant live ------------------------------------
        $s4dMine = Read-OriginRefs -Root $s4cWork -Url $s4cBare
        $s4dLib  = Get-EvidenceRemoteRefs -Root $s4cWork -Url $s4cBare
    } finally { $ErrorActionPreference = $prevEap }

    function Test-S4dMatchesTruth {
        param($Got, $Truth)
        if ($null -eq $Got) { return $false }
        $gk = @($Got.Keys | Sort-Object)
        $tk = @($Truth.Keys | Sort-Object)
        if (@($gk).Count -ne @($tk).Count) { return $false }
        foreach ($k in $tk) { if ($Got[$k] -cne $Truth[$k]) { return $false } }
        return $true
    }
    # HEAD is advertised by ls-remote and is not a ref in for-each-ref's sense, so it is compared
    # out of the key sets rather than being allowed to make every row disagree for a reason that has
    # nothing to do with steering.
    $s4dMineRefs = @{}
    if ($s4dMine -and $s4dMine.refs) { foreach ($k in $s4dMine.refs.Keys) { if ($k -ne 'HEAD') { $s4dMineRefs[$k] = $s4dMine.refs[$k] } } }
    $s4dLibRefs = @{}
    if ($s4dLib) { foreach ($k in $s4dLib.Keys) { if ($k -ne 'HEAD') { $s4dLibRefs[$k] = $s4dLib[$k] } } }

    $s4dMineOk = Test-S4dMatchesTruth -Got $s4dMineRefs -Truth $s4dTruth
    $s4dLibOk  = Test-S4dMatchesTruth -Got $s4dLibRefs  -Truth $s4dTruth
    $s4dMineSteered = $s4dMineRefs.ContainsKey('refs/heads/planted')
    $s4dLibSteered  = $s4dLibRefs.ContainsKey('refs/heads/planted')

    # THE MEMBER FAILS IF THE PLANT WAS NOT LIVE. An inert plant makes every other row meaningless.
    $s4dEnvMineRefs = @{}
    if ($s4dEnvMine -and $s4dEnvMine.refs) { foreach ($k in $s4dEnvMine.refs.Keys) { if ($k -ne 'HEAD') { $s4dEnvMineRefs[$k] = $s4dEnvMine.refs[$k] } } }
    $s4dEnvLibRefs = @{}
    if ($s4dEnvLib) { foreach ($k in $s4dEnvLib.Keys) { if ($k -ne 'HEAD') { $s4dEnvLibRefs[$k] = $s4dEnvLib[$k] } } }
    $s4dEnvMineOk = Test-S4dMatchesTruth -Got $s4dEnvMineRefs -Truth $s4dTruth
    $s4dEnvLibOk  = Test-S4dMatchesTruth -Got $s4dEnvLibRefs  -Truth $s4dTruth
    $s4dParamMineRefs = @{}
    if ($s4dParamMine -and $s4dParamMine.refs) { foreach ($k in $s4dParamMine.refs.Keys) { if ($k -ne 'HEAD') { $s4dParamMineRefs[$k] = $s4dParamMine.refs[$k] } } }
    $s4dParamLibRefs = @{}
    if ($s4dParamLib) { foreach ($k in $s4dParamLib.Keys) { if ($k -ne 'HEAD') { $s4dParamLibRefs[$k] = $s4dParamLib[$k] } } }
    $s4dParamMineOk = Test-S4dMatchesTruth -Got $s4dParamMineRefs -Truth $s4dTruth
    $s4dParamLibOk  = Test-S4dMatchesTruth -Got $s4dParamLibRefs  -Truth $s4dTruth

    # BOTH PLANTS MUST BE LIVE, BOTH READERS MUST RESIST BOTH, AND THE SITING THE FILE PLANT DEPENDS
    # ON MUST STILL HOLD. Any one of those failing makes the others unreadable.
    $s4dOk = ($s4dPlantLive -and $s4dEnvPlantLive -and $s4dParamPlantLive -and $s4dSitedOk -and
              $s4dMineOk -and $s4dLibOk -and $s4dEnvMineOk -and $s4dEnvLibOk -and
              $s4dParamMineOk -and $s4dParamLibOk -and $s4dTruth.Count -ge 2)

    $s4dDetail = @"
    A repository planted at an ancestor of both readers' private read directories, carrying one
    ``url.<decoy>.insteadOf`` line aimed at the origin under test.
      PLANT IS LIVE (unisolated read is steered) : $s4dPlantLive   (expect True -- if False this
                                                    member is INERT and reports nothing about either
                                                    reader, which is why it fails on it)
      ground-truth refs (for-each-ref)           : $($s4dTruth.Count)
      instrument reader == ground truth          : $s4dMineOk
      library reader    == ground truth          : $s4dLibOk
      instrument reader saw the decoy's ref      : $s4dMineSteered   (expect False)
      library reader    saw the decoy's ref      : $s4dLibSteered    (expect False)
    SITING THE FILE PLANT DEPENDS ON (V-1 round 18, WP-6 review finding):
$(($s4dSiting | ForEach-Object { "      {0,-20} {1}" -f $_.name, $_.sited }) -join "`n")
                                                   (CONTROL bare git True = git itself does NOT need
                                                    a usable TEMP, so the two failures below are
                                                    about SITING and not about git. Both readers
                                                    True = each derives its private directory from
                                                    GetTempPath and is therefore reachable by the
                                                    plant above. All three must be True. Provoked,
                                                    not read from source: the previous version
                                                    grepped the files and matched its OWN literal,
                                                    so the instrument arm was True whatever the
                                                    reader did.)
    SECOND PLANT, THROUGH THE ENVIRONMENT (V-1 round 18, WP-6 review finding) -- the file plant is stopped
    by the ceiling, so it exercises none of the GIT_* namespace clear:
      env plant IS LIVE (unisolated read steered) : $s4dEnvPlantLive   (expect True)
                                                   read from a directory carrying NO file plant, so
                                                   only the environment can steer it. It used to be
                                                   read from the file-plant directory and reported
                                                   True with the environment empty.
      instrument reader == ground truth           : $s4dEnvMineOk
      library reader    == ground truth           : $s4dEnvLibOk
    SECOND ENVIRONMENT ROUTE -- GIT_CONFIG_PARAMETERS (V-1 round 19, a WP-6 finding):
      param plant IS LIVE (unisolated read steered) : $s4dParamPlantLive   (expect True)
      instrument reader == ground truth             : $s4dParamMineOk
      library reader    == ground truth             : $s4dParamLibOk
                                                   A cure narrowed to GIT_CONFIG_COUNT/KEY_n/VALUE_n
                                                   passes the rows above and fails these.
    THE OLD VERSION ASKED WHETHER THE TWO AGREED. Two steered readers agree -- and did, in a live
    run, while S-4 was being steered (V-1 round 17, WP-6 review finding). Agreement is not the property.
    Each reader is now judged against an answer read through neither of them, while an attacker is
    talking, and the attacker is proved to be talking before any of it counts.
"@
} catch {
    $s4dDetail = "    the resistance check itself failed: $($_.Exception.Message)"
} finally {
    $env:TMP = $s4dTmpSave.TMP
    $env:TEMP = $s4dTmpSave.TEMP
}
# Under PowerShell 7 this member is graded as under 5.1 (UI-2 S1c validator round 1, F-2): the library reader's failure there
# was a drive-letter origin url made "<root>\C:\..." by 7's GetFullPath, cured in the library; no skip.
Check -Id 'S-4d' -Title 'both origin readers still report the truth while a planted repository is rewriting the origin url' `
      -Ok $s4dOk -Detail $s4dDetail

# ================================================================================================
# S-4b -- CHAIN LINK 1, IN THE MISSION BEING GRADED.
# ================================================================================================
# The acceptance contract wrote that "an instrument member asserts the hook's presence and sha256 in the mission
# being graded". No member did. Every `.git/hooks/pre-push` reference in the WP-4 instrument was to a
# temp repository it built and then deleted, so deleting the decider from lam-smoke -- the actual
# mission -- would have left the whole suite green. A link that asserts something about a fixture it
# created itself is not a link in a detection chain; it is a member testing its own setup.
#
# THIS ASKS GIT, in the smoke mission, where its hooks live and whether the file there is ours.
# NOT ASKED BELOW A WORK TREE'S TOP LEVEL: there git reports the ENCLOSING repository's hooks path, and
# this member would turn false-green the day that repository had a decider installed. It SKIPs only at
# a FILES-ONLY root (no .git entry). A LIVE repository git does not answer for as a top level is not
# asked either -- the same hazard -- and FAILS, naming why. An ABSENT root is still asked, and still fails.
$s4bSkip  = $(if ($smokeIsFilesOnly) { $smokeNotRepoWhy } else { '' })
$s4bNoAsk = $(if ($smokeIsLive -and -not $smokeIsRepoTop) { $smokeLiveGitWhy } else { '' })
$s4bChecker = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\check-prepush-installed.ps1'
$s4bShipped = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-pre-push.ps1'
$s4bOut = ''; $s4bExit = $(if ($s4bSkip -or $s4bNoAsk) { '(not run)' } else { 1 })
$s4bHooksDir = '(not asked)'
$s4bFold = ''
if ((-not $s4bSkip) -and (-not $s4bNoAsk) -and (Test-Path -LiteralPath $s4bChecker)) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $s4bOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $s4bChecker -RepoRoot $SmokeRoot 2>&1 | Out-String
        $s4bExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
    # THE DECIDER IS JUDGED BY THE FOLD RULE ACROSS CHECKOUTS. The checker compares the RAW sha256 of
    # the decider beside it -- THIS checkout's -- with the raw sha256 of the decider the mission's wrapper names,
    # which is another checkout's file (the primary's, or a vendored copy). Two checkouts of one commit differ by
    # line endings alone where one of them is CRLF, and the checker then gives its decider-contents refusal, worded
    # as a substitution though nothing was substituted: S-4b failed from a CRLF worktree against an LF primary, for
    # where it ran. The installer, -Verify and the lock judge text by the fold rule, and so does this member -- at
    # that one answer, the only one carrying decider_expected, and nowhere else.
    # THE SAME TEXT: the checker is asked again with -DeciderPath the named decider, so every question it asks after
    # the decider -- whether every worktree resolves the same hooks path among them -- is still asked, and its answer
    # decides. DIFFERENT TEXT: the first refusal stands; the fold hides line endings and nothing else.
    # A CRLF OR BOM WRAPPER is refused before any question about the decider (a /bin/sh shebang cannot carry a CR),
    # and so are a relative decider path and an absent decider: none of them reaches this, and none is folded.
    # THE ANSWER'S FIELDS ARE READ THROUGH A TABLE, NOT AS PROPERTIES: once S-4d has dot-sourced the guard library,
    # this file runs under the library's StrictMode, and naming a property an answer lacks -- every refusal but the
    # decider-contents one lacks decider_expected -- throws and ends the instrument instead of failing this member.
    $s4bFirst = @{}
    $s4bJsonLine = @(($s4bOut -split "`r?`n") | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1)
    if (($s4bExit -ne 0) -and ($s4bJsonLine.Count -eq 1)) {
        try { foreach ($s4bP in ($s4bJsonLine[0] | ConvertFrom-Json).PSObject.Properties) { $s4bFirst[$s4bP.Name] = [string]$s4bP.Value } }
        catch { $s4bFirst = @{} }
    }
    if ($s4bFirst['decider_expected'] -and $s4bFirst['decider_path'] -and
        (Test-Path -LiteralPath $s4bFirst['decider_path'] -PathType Leaf) -and (Test-Path -LiteralPath $s4bShipped -PathType Leaf)) {
        $s4bNamed      = $s4bFirst['decider_path']
        $s4bShippedRaw = Get-RawSha256 -P $s4bShipped
        $s4bNamedFold  = Get-FoldRuleSha256 -P $s4bNamed
        $s4bShipFold   = Get-FoldRuleSha256 -P $s4bShipped
        # THE FILE FOLDED IS THE FILE THE CHECKER COMPARED: its decider_expected is the raw sha256 of the decider
        # beside it, which is $s4bShipped. An answer about any other file is not this answer, and is not folded.
        $s4bSameText = ($s4bShippedRaw -ceq $s4bFirst['decider_expected']) -and ($s4bNamedFold -ceq $s4bShipFold)
        $s4bFold = "    THE DECIDER, JUDGED BY THE FOLD RULE ACROSS CHECKOUTS (CR LF made LF in a file holding no 0x00 byte):`n" +
                   "      the checker's first answer           : exit $s4bExit -- $($s4bFirst['reason'])`n" +
                   "      the decider the wrapper names        : $s4bNamed`n" +
                   "        raw sha256 / fold-rule sha256      : $($s4bFirst['decider_sha256']) / $s4bNamedFold`n" +
                   "      this checkout's shipped decider      : $s4bShipped`n" +
                   "        raw sha256 / fold-rule sha256      : $s4bShippedRaw / $s4bShipFold`n"
        if ($s4bSameText) {
            $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try {
                $s4bOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $s4bChecker -RepoRoot $SmokeRoot -DeciderPath $s4bNamed 2>&1 | Out-String
                $s4bExit = $LASTEXITCODE
            } finally { $ErrorActionPreference = $prevEap }
            $s4bFold += "      verdict                              : THE SAME TEXT -- the checker was asked again with -DeciderPath the named decider; that answer, above, decides`n" +
                        "      NOT CLAIMED: the runner (tools\lam\mission-dispatch.ps1) asks the same checker without this fold, so run from this checkout against this mission it still refuses the dispatch`n"
        } else {
            $s4bFold += "      verdict                              : DIFFERENT TEXT -- the checker's refusal stands`n"
        }
    }
}
if ((-not $s4bSkip) -and (-not $s4bNoAsk)) { $s4bHooksDir = (GitOut -Root $SmokeRoot -Argv @('rev-parse','--git-path','hooks')).out }
$s4bDetail = @"
$(if ($s4bNoAsk) { "    NOT ASKED, AND RED: $s4bNoAsk -- neither the checker nor git ran against the smoke root, and a live repository whose decider cannot be shown in force is not one that has it.`n" })    The decider is asserted where it has to be true -- the smoke mission -- not in a fixture this
    file builds and deletes. The hooks directory is GIT'S OWN answer, so core.hooksPath and
    worktrees are accounted for rather than assumed away:
      checker exit                        : $s4bExit   (expect 0)
      git's hooks path for the mission    : $s4bHooksDir
      checker said                        : $(($s4bOut -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1))
$s4bFold    WHAT THIS DOES NOT CLAIM: the decider is a TRIPWIRE at the publication point, not a boundary.
    ``git push --no-verify`` skips it and so does core.hooksPath pointed elsewhere (LAM-ACCEPT T-2,
    amendment 20). This member asserts it is IN FORCE, which is a different and smaller thing.
"@
$s4bTitle = 'the pre-push decider is installed and unedited IN THE MISSION BEING GRADED, at the hooks path git itself reports'
if ($s4bSkip) {
    Check -Id 'S-4b' -Title ($s4bTitle + '   [SKIPPED -- ' + $s4bSkip + ']') -Ok $false -Skipped `
          -Detail ("    SKIPPED: $s4bSkip`n    NOTHING WAS ASKED: neither the checker nor git ran against the smoke root.`n" + $s4bDetail)
} else {
    Check -Id 'S-4b' -Title $s4bTitle -Ok ($s4bExit -eq 0) -Detail $s4bDetail
}

$gatesForOrigin = @()
if (Test-Path -LiteralPath $gatesDir) {
    $gatesForOrigin = @(Get-ChildItem -LiteralPath $gatesDir -File -Filter 'push-*.yaml' -ErrorAction SilentlyContinue)
}
$declaredOrigin = ''
$declaredRef    = ''
foreach ($gf in $gatesForOrigin) {
    $gt = ReadText $gf.FullName
    if ($gt -match '(?m)^origin_url:\s*(\S+)') { $declaredOrigin = $Matches[1] }
    if ($gt -match '(?m)^remote_ref:\s*(\S+)')  { $declaredRef    = $Matches[1] }
    if ($declaredOrigin) { break }
}
# ORDINAL, for the reason given in Get-EvidenceRemoteRefs: git refs are case-sensitive and a
# PowerShell hashtable's keys are not, so a colliding ref name would hide a stray ref from the very
# enumeration that exists to find one.
$originRefs   = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
$originReadOk = $false
# THE DECLARED ORIGIN, RESOLVED ONE OF THREE WAYS AND NEVER BY A THROW: a URL (scheme://, or
# user@host:path) is read as it always was, through Read-OriginRefs; a ROOTED path is used as given
# (Join-Path of a rooted path onto the smoke root is no path at all); anything else is joined to the
# smoke root, which is what the gate's `origin_url: ../lam-smoke-origin.git` is relative to.
# IT IS READ ONLY WHERE IT CAN BE THE SMOKE MISSION'S: Read-OriginRefs asks `git -C <smoke root> config`
# for the credential helpers it carries into the read, and below a work tree's top level that is the
# ENCLOSING repository's config. ONLY AT A FILES-ONLY ROOT DO THE ORIGIN ROWS SKIP. At a LIVE repository
# a declared origin that cannot be read -- ABSENT, NOT a bare repository, a path that does not resolve,
# or a root git does not answer for -- is a MISS, and the detail says which.
$declaredIsUrl  = [bool]($declaredOrigin -and (($declaredOrigin -match '^[A-Za-z][A-Za-z0-9+.-]*://') -or ($declaredOrigin -match '^[^/\\]+@')))
$declaredKind   = '(no declared origin)'
$declaredAbs    = ''
$declaredIsBare = $false
$declaredState  = ''
if ($declaredOrigin -and $declaredIsUrl) {
    $declaredKind = 'a URL, read as given'
} elseif ($declaredOrigin) {
    try {
        if ([System.IO.Path]::IsPathRooted($declaredOrigin)) {
            $declaredKind = 'a rooted path, used as given'
            $declaredAbs  = [System.IO.Path]::GetFullPath($declaredOrigin)
        } else {
            $declaredKind = 'a relative path, joined to the smoke root'
            $declaredAbs  = [System.IO.Path]::GetFullPath((Join-Path $SmokeRoot $declaredOrigin))
        }
    } catch {
        $declaredAbs   = ''
        $declaredState = "it does not resolve to a path ($($_.Exception.Message))"
    }
    if ($declaredAbs) {
        if (-not (Test-Path -LiteralPath $declaredAbs -PathType Container)) {
            $declaredState = "$declaredAbs is ABSENT"
        } else {
            $declaredBareProbe = GitStdout -Root $declaredAbs -Argv @('rev-parse', '--is-bare-repository')
            $declaredIsBare = ($declaredBareProbe.exit -eq 0) -and ($declaredBareProbe.out -ceq 'true')
            if (-not $declaredIsBare) { $declaredState = "$declaredAbs is present but NOT a bare repository (git, on stdout: '$($declaredBareProbe.out)', exit $($declaredBareProbe.exit))" }
        }
    }
}
$declaredReadable = [bool]($declaredOrigin -and $smokeIsRepoTop -and ($declaredIsUrl -or $declaredIsBare))
$s4OriginWhy = "$smokeNotRepoWhy -- the declared origin is not read for a root of files"
$s4OriginNote = $(if (-not $declaredOrigin) { 'not read: the gate declares no origin -- a MISS' }
                  elseif ($smokeIsFilesOnly) { "not read, SKIPPED: $s4OriginWhy" }
                  elseif (-not $smokeExists) { "not read: the smoke root $SmokeRoot is ABSENT -- a MISS" }
                  elseif (-not $smokeIsRepoTop) { "not read: $smokeLiveGitWhy -- a MISS, never a skip" }
                  elseif ($declaredState) { "not read: the declared origin $declaredOrigin ($declaredKind) cannot be read -- $declaredState -- a MISS, never a skip" }
                  else { "asked of $(if ($declaredIsUrl) { $declaredOrigin } else { $declaredAbs }) ($declaredKind)" })
if ($declaredReadable) {
    # NOT `GitOut` HERE, AND THAT IS THE WHOLE DEFECT (V-1 round 13, WP-6). `GitOut` returns
    # `("$o").Trim()` where `$o` is git's ARRAY of output lines, and `"$array"` joins with `$OFS` --
    # a SPACE. This loop then split on `\r?\n` and matched the anchored `^([0-9a-f]{40})\s+(\S+)$`
    # per line, so a multi-line `ls-remote` arrived as ONE space-joined line, matched nothing, and
    # left the ref table EMPTY -- while the member went on to report "NO ref carries a sha no gate
    # authorized: True", vacuously true of an origin it never read. The leg that enumerates EVERY
    # ref enumerated nothing.
    #
    # AND IT HAS BEEN GREEN BY ACCIDENT. The real lam-smoke-origin.git advertises exactly ONE line,
    # because its HEAD symref points at refs/heads/master, which does not exist. A one-element array
    # joins to itself. Repair that dangling symref -- or point this member at any ordinary remote,
    # which advertises HEAD as well as its branches -- and it went red with the authorization
    # untouched. The reader drove both.
    #
    # The lines are taken from git directly, so no join happens between git and the regex.
    # A local origin is handed over already resolved (above), so there is one resolution, not two.
    $rr = Read-OriginRefs -Root $SmokeRoot -Url $(if ($declaredIsUrl) { $declaredOrigin } else { $declaredAbs })
    $originReadOk = $rr.ok
    $originRefs   = $rr.refs
}
$originTip = if ($declaredRef -and $originRefs.ContainsKey($declaredRef)) { $originRefs[$declaredRef] } else { '' }

if ($pushGates.Count -eq 0) {
    # THE STOPPING POINT. No operator gate exists yet, so the only thing that can be true here is
    # that the push is blocked -- and that IS the check, not a failure of it.
    $detail = @"
    push guard exit : $pgExit   (expect 2 -- blocked, no gate exists)
    blocked         : $($pgExit -eq 2)
    push gates present : 0
    local tip  : $localTip
    origin tip : $(if ($originTip) { $originTip } else { '(origin has no main yet)' })

    >>> AWAITING PUSH GATE (smoke) <<<
    The operator runs, personally:
      tools\lam\mission-gate.ps1 approve -Kind push -Id S4 -Binds <artifact> -MissionRoot $SmokeRoot
    This instrument does not simulate it, and this build does not push.
"@
    # The denial records live in the runtime plane; a root of tracked files cannot show them.
    $s4WaitRows = [ordered]@{
        'the push is blocked while no gate exists (durable denial records)' = $(if ($smokeExists -and -not $smokePlane) { $smokeNoPlaneWhy } else { ($pgExit -eq 2) })
    }
    Write-Wp6Member -Id 'S-4' -Title 'push is blocked with no gate; AWAITING PUSH GATE (smoke)' -Rows $s4WaitRows -Tail $detail
} else {
    # ---------------------------------------------------------------------------------------
    # BY THE OPERATOR'S RULING, S-4 is bound to ORIGIN'S OWN ANSWER, not to a local
    # flag. `consumed_at` can never be set here: consumption is the push hook's act, that hook
    # witnesses only IN-SESSION pushes, and this member requires an out-of-session human push.
    # Asserting it would be asserting something the procedure makes impossible. Origin's tip is
    # also the STRONGER witness -- one rung up the A3 ladder from a field the local machinery
    # writes about itself.
    # ---------------------------------------------------------------------------------------
    $gateText = ReadText $pushGates[0].FullName
    $gAuth    = if ($gateText -match '(?m)^authorized_tip_sha:\s*([0-9a-f]{40})') { $Matches[1] } else { '' }
    $gBy      = if ($gateText -match '(?m)^authorized_by:\s*(\S+)')               { $Matches[1] } else { '' }
    $gBinds   = if ($gateText -match '(?m)^binds:\s*(.+?)\s*$')                   { $Matches[1] } else { '' }
    $gBindSha = if ($gateText -match '(?m)^binds_sha256:\s*([0-9a-f]{64})')       { $Matches[1] } else { '' }

    # (b) bound by sha256 to a named artifact -- RE-DERIVED, never taken from the gate's own word.
    $bindsPath = $gBinds
    if ($bindsPath -and -not [System.IO.Path]::IsPathRooted($bindsPath)) {
        $bindsPath = Join-Path (Split-Path -Parent $SmokeRoot) ($bindsPath -replace '^\.\.[\\/]', '')
    }
    $bindLive = if ($bindsPath -and (Test-Path -LiteralPath $bindsPath)) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath $bindsPath).Hash.ToLowerInvariant()
    } else { '' }
    $bindOk = ($gBindSha -and $bindLive -and ($gBindSha -eq $bindLive))

    # (c) origin's answer equals the authorized tip, and that tip is an ancestor of the live HEAD.
    # NOT `origin -eq localTip`: the mission legitimately advances after the push -- it did, by the
    # amendment-6 mechanics -- and a member that froze the tree would re-create the very defect
    # the advance admission exists to cure. What must hold forever is that ORIGIN HOLDS
    # EXACTLY WHAT WAS AUTHORIZED, and that the local history still descends from it.
    # A GATE THAT PREDATES THE DECLARED-ORIGIN RULE CANNOT SUPPORT THIS CLAUSE, and that is reported rather than
    # papered over. Falling back to `remote.origin.url` would reintroduce exactly the surface the
    # amendment removed. Re-minting the gate is an OPERATOR act -- T-3 hard-denies agents write
    # access to the gates directory -- so this reads as a blocker for a human, which is what it is.
    # AN ANNOTATED GATE DECLARES FROM THE ANNOTATION DATE FORWARD, AND THE GAP IS SAID OUT LOUD
    # (folded into the acceptance contract).
    #
    # When a gate was minted before the declared-origin rule existed, the operator ADDS the
    # declaration as a dated annotation rather than re-minting -- because re-minting would stamp the
    # current date on an authorization a human gave earlier, falsifying the one artifact class whose
    # purpose is recording WHEN a human said yes.
    #
    # WHAT THAT COSTS, STATED RATHER THAN ABSORBED: between `created_at` and `annotated_at` this gate
    # declared no origin, so nothing observed which remote it was about. This member therefore
    # asserts what origin holds NOW against a declaration made THEN, and it cannot speak for the
    # window in between. A member that reported otherwise would be manufacturing evidence for a
    # period nobody observed -- which is worse than the gap it would be covering up.
    $gAnnotAt = if ($gateText -match '(?m)^annotated_at:\s*(\S+)') { $Matches[1] } else { '' }
    $gAnnotBy = if ($gateText -match '(?m)^annotated_by:\s*(\S+)') { $Matches[1] } else { '' }
    $gCreated = if ($gateText -match '(?m)^created_at:\s*(\S+)')   { $Matches[1] } else { '' }
    $isAnnotated = [bool]$gAnnotAt

    $declaredOk = [bool]($declaredOrigin -and $declaredRef)
    $originIsAuthorized = ($declaredOk -and $originReadOk -and $originTip -and $gAuth -and ($originTip -eq $gAuth))

    # EVERY REF, NOT JUST THE AUTHORIZED ONE. What any push gate authorized is the only thing origin
    # is permitted to hold; any other ref is a publication no operator approved.
    #
    # The sha-only list that used to be built here is GONE rather than left beside its replacement.
    # It was still being computed after the predicate stopped reading it, and a variable that looks
    # like it is doing work is the shape this file exists to catch.
    # A REF IS A (NAME, SHA) PAIR, AND THE OLD PREDICATE COMPARED ONLY THE SHA (V-1 round 13, WP-6).
    # So the authorized commit republished onto `refs/heads/attacker` was invisible: its sha was on
    # the authorized list, and nothing asked which ref carried it. A gate authorizes ONE ref; a
    # second ref holding the same commit is a publication nobody approved.
    $authorizedPairs = @()
    foreach ($gf in $gatesForOrigin) {
        $gt = ReadText $gf.FullName
        $gs = if ($gt -match '(?m)^authorized_tip_sha:\s*([0-9a-f]{40})') { $Matches[1] } else { '' }
        $gr = if ($gt -match '(?m)^remote_ref:\s*(\S+)')                  { $Matches[1] } else { '' }
        if ($gs -and $gr) { $authorizedPairs += "$gr`t$gs" }
    }
    $strayRefs = @()
    foreach ($k in $originRefs.Keys) {
        if ($k -match '\^\{\}$') { continue }                       # peeled tag entries are not refs
        # HEAD IS SKIPPED ONLY WHEN IT HOLDS A SHA SOME GATE AUTHORIZED (V-1 round 15, a WP-6 finding).
        #
        # It used to be skipped unconditionally. Round 14 measured the first justification false --
        # "safe to skip because it publishes nothing of its own" -- and replaced it with a SCOPE
        # claim: that reaching a detached origin HEAD "needs direct write access to origin ... which
        # is not the publication path this member guards". Round 15 drove THAT false too. The gate
        # declares `origin_url: ../lam-smoke-origin.git`, a sibling DIRECTORY, and one
        # `[IO.File]::WriteAllText` to `<origin>\HEAD` -- no git involved -- put an unauthorized
        # commit on HEAD, on no other ref, and this loop reported `stray refs: (none)`. The actor who
        # can write a sibling directory is the actor the threat model already covers.
        #
        # THE SKIP IS NARROWED, NOT REMOVED. Removing it would report a stray against every
        # correctly-configured origin: an ordinary remote advertises HEAD as a symref whose sha
        # equals some branch's, and `HEAD` appears in no gate, so the PAIR never matches. The precise
        # question was never "is this ref named HEAD" but "does HEAD hold a sha some gate authorized".
        #
        # Two things about git's parser remain true and were re-driven: `git push <origin> <sha>:HEAD`
        # is refused as not a full refname, and `HEAD:HEAD` lands on `refs/heads/HEAD`, which this
        # predicate already catches on its own line. Those bound what GIT will do; they never bounded
        # what a filesystem write can do, and the round-14 sentence conflated the two.
        if ($k -ceq 'HEAD') {
            $authorizedShas = @($authorizedPairs | ForEach-Object { ($_ -split "`t")[1] } | Where-Object { $_ })
            if ($authorizedShas -ccontains $originRefs[$k]) { continue }
            # else: HEAD holds a sha no gate authorized -- fall through and report it as a stray.
        }
        # THE PAIR, not the sha. `-cnotcontains` because git refs are case-sensitive.
        if ($authorizedPairs -cnotcontains ("$k`t" + $originRefs[$k])) { $strayRefs += ("$k=" + $originRefs[$k].Substring(0,8)) }
    }
    $noStrayRefs = ($originReadOk -and $strayRefs.Count -eq 0)
    # Ancestry is asked of the smoke repository's own object store, so only of a top-level work tree
    # with a tip; below one it would be asked of the enclosing repository. Not asked, at a LIVE root git
    # does not answer for, is $false and its row MISSES; only a FILES-ONLY root skips it.
    $descends = $false
    if ($smokeIsRepoTop -and $gAuth -and $localTip) {
        $anc = GitOut -Root $SmokeRoot -Argv @('merge-base','--is-ancestor',$gAuth,$localTip)
        $descends = ($anc.exit -eq 0)
    }

    # (d) no standing capability remains (ADR-033).
    # THE DOT-SOURCED DEFINITION, NOT A FOURTH COPY (V-1 round 15; a WP-4 and a WP-6 finding, found
    # independently). This file dot-sources `lam-gate-class.ps1` at line 43 -- the file whose entire
    # purpose is to be the ONE definition of gate state -- and then restated the revocation predicate
    # anyway. WP-4 swept five consumers of the gate's DISQUALIFIED state and this was the one
    # that did not move: it read `revoked=False expired=False notLive=False` for a disqualified gate,
    # identical to its reading of an open one. Fail-loud rather than a false green, but the detail
    # line then leaves an operator nowhere to look -- verbatim the complaint lam-gate-class exists to
    # prevent. The two also disagree outright on an indented `revoked_at`.
    #
    # Calling the shared function is the whole fix, and it picks up the fourth state for free. That
    # is what having one definition buys, as distinct from a comment asserting there is one.
    $gateState = Get-LamGateState -Path $pushGates[0].FullName
    $revoked = [bool]$gateState.revoked
    $disqualified = [bool]$gateState.disqualified
    $expired = $false
    if ($gateText -match '(?m)^expires_at:\s*(\S+)') {
        try { $expired = ([datetime]::Parse($Matches[1])).ToUniversalTime() -lt (Get-Date).ToUniversalTime() } catch { $expired = $false }
    }
    # DISQUALIFIED COUNTS AS NOT-LIVE. A gate whose witness aged out is unusable -- the decider
    # refuses every push it authorizes -- so a member asserting "no standing capability" must say so.
    $notLive = ($revoked -or $expired -or $disqualified)

    # (e) consumed_at null RECORDED WITH ITS REASON, not asserted away.
    # THE SHARED PREDICATE ANSWERS "IS IT CONSUMED"; THE EXTRA ASSERTION IS NAMED AS EXTRA
    # (V-1 round 16, WP-6 review finding). This re-derived the whole question itself, in a file that
    # dot-sources lam-gate-class.ps1 at line 43 and calls it thirty lines above. Driven over seven
    # gate texts, the two copies disagree on an INDENTED `consumed_at: null` and on the field being
    # absent: the library says open/unconsumed, this member failed. mission-gate.ps1 already records
    # `consumed_at` as having had "exactly this shape twice"; this was the third.
    #
    # The replacement is not a straight swap, because this member asks something NARROWER than "is it
    # consumed": ADR-033 requires an unconsumed gate to RECORD the field as literally null, so its
    # presence is asserted separately and labelled as the additional requirement it is.
    $consumedFieldPresent = ($gateText -match '(?m)^\s*consumed_at:')
    $consumedNull = ((-not $gateState.consumed) -and $consumedFieldPresent)

    # JUDGED ROW BY ROW. Where the smoke root is a folder of copied files (FILES-ONLY: no .git entry),
    # what needs the smoke repository's checkout or its origin SKIPs by name, and what needs the runtime
    # plane SKIPs where that plane is absent; what the gate's own text answers -- one gate, its
    # authorizer, its revocation, its consumed_at -- is still measured, and a miss there still fails the
    # member. At a LIVE repository the checkout and origin rows are MEASURED: an origin it cannot read,
    # or a git that does not answer for it, MISSES. The binds row SKIPs rather than compare on an LF
    # basis: the gate binds a checkout's exact bytes, and accepting an EOL equivalence would change what
    # it binds.
    $s4Rows = [ordered]@{
        '(a) the push WAS blocked while no gate existed (durable denial records)' = $(if ($smokeExists -and -not $smokePlane) { $smokeNoPlaneWhy } else { ($pgExit -eq 2) })
        '(b) exactly one push gate artifact'                     = ($pushGates.Count -eq 1)
        '(b) authorized_by recorded'                              = [bool]$gBy
        '(b) binds_sha256 re-derived and matches'                 = $(if ($smokeIsFilesOnly) { "the gate binds the bytes of the smoke repository's CHECKOUT; $smokeNotRepoWhy" } else { [bool]$bindOk })
        '(c) origin holds exactly what was authorized'            = $(if ($declaredOrigin -and $smokeIsFilesOnly) { $s4OriginWhy } else { [bool]$originIsAuthorized })
        '(c) NO ref carries a sha no gate authorized'             = $(if ($declaredOrigin -and $smokeIsFilesOnly) { $s4OriginWhy } else { [bool]$noStrayRefs })
        '(c) local HEAD descends from the authorized tip'         = $(if ($smokeIsFilesOnly) { $smokeNotRepoWhy } else { [bool]$descends })
        '(d) no standing capability remains'                      = [bool]$notLive
        '(e) consumed_at is null'                                 = [bool]$consumedNull
    }
    $detail = @"
    (a) the push WAS blocked while no gate existed : $($pgExit -eq 2)   (expect True)
        measured from the DURABLE denial records the hooks wrote at the time, not re-simulated:
        $pgText
        Re-probing would answer a different question (does it block NOW) and would append another
        record to the plane this member grades. WP-4 T-2 covers present-tense blocking across
        fifteen spellings and the whole gate lifecycle.
    (b) push gate artifacts                 : $($pushGates.Count)   (expect exactly 1)
        authorized_by (operator, T-3)       : $gBy
        binds                               : $gBinds
        binds_sha256 re-derived and matches : $bindOk   (expect True)
    (c) HOW THIS GATE CAME TO DECLARE AN ORIGIN : $(if ($isAnnotated) { "ANNOTATED $gAnnotAt by $gAnnotBy" } else { 'declared at mint time' })
$(if ($isAnnotated) { @"
        The gate was minted $gCreated, before amendment 20 required a declaration, and the operator
        ADDED one as a dated annotation rather than re-minting -- re-minting would have stamped a
        later date on an authorization given earlier.
        >>> DISCLOSED GAP: from $gCreated to $gAnnotAt this gate declared NO origin. Nothing observed
        >>> which remote it was about during that window, and this member does not claim to. What is
        >>> asserted below is what the DECLARED origin holds NOW, against a declaration dated
        >>> $gAnnotAt. The pre-annotation window is unobserved and is reported, not hidden.
"@ } else { '' })
        DECLARED origin (from the gate, never .git/config) : $(if ($declaredOrigin) { $declaredOrigin } else { '(NONE -- this gate predates amendment 20 and has not been annotated)' })
        declared ref                        : $(if ($declaredRef) { $declaredRef } else { '(none)' })
        declared origin resolved as         : $declaredKind$(if ($declaredAbs) { " -> $declaredAbs" })
        origin readable                     : $originReadOk   ($s4OriginNote)
        refs the declared origin holds      : $($originRefs.Keys.Count)
        sha at the declared ref             : $originTip
        gate authorized_tip_sha             : $gAuth
        origin holds exactly what was authorized : $originIsAuthorized   (expect True)
        NO ref carries a sha no gate authorized  : $noStrayRefs   (expect True)
        stray refs                          : $(if ($strayRefs.Count) { $strayRefs -join ', ' } else { '(none)' })
        local HEAD descends from it         : $descends   (expect True -- the mission may advance)
        local tip now                       : $localTip
    (d) revoked=$revoked expired=$expired disqualified=$disqualified -> no standing capability : $notLive   (expect True)
    (e) consumed_at is null                 : $consumedNull   (shared predicate says unconsumed=$(-not $gateState.consumed), field present=$consumedFieldPresent; expect True), AND THE REASON IS RECORDED:
        consumption is the push hook's act and that hook witnesses only IN-SESSION pushes; this
        push was the operator's, out of session, so nothing could witness it. Not a defect and not
        asserted away -- see erratum E22 / LAM-ACCEPT S-4 as amended.
"@
    # WHO AUTHORIZED IT IS READ OFF THE GATE (as ZP reads it): operator_credential injected-seam is the console seam's
    # label, a gate no human confirmed -- a built smoke mission's, whose push the builder made before composing it.
    $s4Seam = ($gateText -match '(?m)^operator_credential:[ \t]*injected-seam[ \t]*\r?$')
    if ($s4Seam) {
        $detail += "`n    AT THIS MISSION THE GATE IS BUILDER-COMPOSED (operator_credential: injected-seam): no human confirmed it, its authorized_by ($gBy) names no operator, and the push it binds was the builder's, made before the gate was composed. Rows (b) to (e) measure the artifact and the origin; 'operator' above does not hold for this gate."
    }
    Write-Wp6Member -Id 'S-4' -Title ('the push landed and origin holds exactly what the operator authorized; no standing capability remains' + $(if ($s4Seam) { '   [the gate is BUILDER-COMPOSED (operator_credential: injected-seam) -- no operator authorized it]' } else { '' })) -Rows $s4Rows -Tail $detail
}

# =============================================================================================
# S-5 -- close ran with hooks live; verify PASS; every manifest's capture_gaps empty
# =============================================================================================
$sidecars = @()
if (Test-Path -LiteralPath $evRootBase) {
    $sidecars = @(Get-ChildItem -LiteralPath $evRootBase -Recurse -File -Filter 'capture-gaps.yaml' -ErrorAction SilentlyContinue)
}
$nonEmpty = @($sidecars | Where-Object { (ReadText $_.FullName) -notmatch '(?m)^capture_gaps:\s*\[\]\s*$' })
# The mission-state `Closed` requirement is GONE. Closing a mission is the
# product CLI's job under the product's own schema, and this mission's .mission/ is authored to the
# v2.3 Living Spec schema -- requiring one to close the other tested schema conformance, not this
# toolchain. What S-5 was always for is proven instead: a ceremony-class operation completing with
# the hooks live and BOTH patched clean-tree gates doing their real job.
$ceremony = Join-Path $SmokeRoot 'tools\mission-ceremony-record.ps1'
$ledger   = Join-Path $missionDir 'ledger\entries.jsonl'

# (1) A ceremony really RAN to completion: its record is in the append-only ledger, and the commit
#     that carried it exists. Read from the artifacts, not from a remembered run.
$ledgerText  = ReadText $ledger
$ranCeremony = $ledgerText -match '"type":\s*"ceremony"'
# THE MOST RECENT CEREMONY, NOT THE FIRST. The ledger is APPEND-ONLY, so a plain `-match` returns
# the OLDEST ceremony id and this member would grade it forever -- which is exactly what it did on
# its first run after the ceremony was re-run as a dispatch: it went looking for a session that
# observed `...-001`, the child-process run that produced no session at all, and reported the
# cure as still broken. My defect, and the same family as the one this member exists to catch: it
# measured the wrong INSTANCE of the right thing.
#
# Grading the LATEST is also the stricter reading, and that is why it is the right one. "Some
# ceremony once had an observing session" is satisfied forever by one good run; "the most recent
# ceremony has one" goes red again the moment somebody runs a ceremony outside the dispatch route.
$ceremonyId = ''
$cerMatches = @([regex]::Matches($ledgerText, '"id":\s*"(ledger-ceremony-[^"]+)"'))
if ($cerMatches.Count -gt 0) { $ceremonyId = $cerMatches[$cerMatches.Count - 1].Groups[1].Value }
# WHAT THIS ROOT CAN ANSWER. The commit and both clean-tree gates are questions to the smoke
# repository's git: below a work tree's top level they would be asked of the ENCLOSING repository --
# its log, its working tree, even a refresh of its index -- and would grade the framework. The
# ceremony's session, the sidecars and the manifests live in the runtime plane. Each is a named SKIP
# where the root cannot answer it -- the git rows only at a FILES-ONLY root (no .git entry); the ledger
# record is tracked and is always measured. A LIVE repository git does not answer for as a top level is
# not asked (the same enclosing-repository hazard) and its git rows MISS. An ABSENT root is still asked
# everything, and still fails.
$s5GitWhy   = $(if ($smokeIsFilesOnly) { $smokeNotRepoWhy } else { '' })
$s5NoAsk    = $(if ($smokeIsLive -and -not $smokeIsRepoTop) { $smokeLiveGitWhy } else { '' })
$s5PlaneWhy = $(if ($smokeExists -and -not $smokePlane) { $smokeNoPlaneWhy } else { '' })
$ceremonyCommit = ''
$cOut  = @()
$cExit = '(not run)'
if ((-not $s5GitWhy) -and (-not $s5NoAsk)) {
    # A COMMIT IS A SHA THAT GIT ANSWERED WITH: GitOut hands back git's error text as .out, and that
    # text is truthy, so the exit code and the 40-hex form are both required.
    $ceremonyCommitGot = GitOut -Root $SmokeRoot -Argv @('log','--format=%H','-1','--grep',"ceremony: $ceremonyId")
    if (($ceremonyCommitGot.exit -eq 0) -and ($ceremonyCommitGot.out -match '^[0-9a-f]{40}$')) { $ceremonyCommit = $ceremonyCommitGot.out }

    # (2) BOTH gates still pass against the LIVE tree, re-exercised now rather than trusted from
    #     history -- the tree moves, so a gate that passed once is not a gate that passes today.
    #     -CheckOnly runs both and mutates nothing; ledger ids are one-per-event, so a mutating
    #     self-test would refuse on its second run.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $cOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $ceremony -CeremonyId 's5-checkonly' -CheckOnly 2>&1
        $cExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
}
$cText     = (@($cOut) | ForEach-Object { "$_" }) -join "`n"
$gate1Live = ($cText -match 'Assert-CleanGitTree passed')
$gate2Live = ($cText -match 'Working tree clean')
$bothGates = ($cExit -eq 0) -and $gate1Live -and $gate2Live

# (3) THE CEREMONY'S OWN EVIDENCE SESSION -- the clause this member used to substitute away.
#
# WHAT IT USED TO ASSERT, AND WHY THAT WAS NOT A MEASUREMENT (V-1 round 1, WP-6 validator; E28).
# S-5 requires that the ceremony run "WITH THE NEXT-GEN HOOKS LIVE" and that "ITS EVIDENCE SESSION
# FINALIZES". This member asserted instead that ALL mission manifests were finalized -- a true
# statement about four OTHER sessions, every one of them a dispatch that finished hours earlier,
# and not a measurement of the ceremony's session at all. The ceremony had in fact run as a CHILD
# PROCESS of the <project> orchestrator session, so the hooks that observed it were <project>'s A1
# hooks; the next-gen hooks are registered only in the smoke repo's settings and fire for Claude
# sessions whose project is that repo, which a plain child process is not. Consequently NO evidence
# session existed for the ceremony anywhere in this mission, and the member could not tell.
#
# E28 STATED AS THE RULE THIS NOW IMPLEMENTS: a claim about WHERE an operation ran must be
# evidenced by an artifact THAT OPERATION ITSELF PRODUCED. So the session is identified by CONTENT
# -- an evidence session in the SMOKE mission's plane whose captured calls name the ceremony
# wrapper and the ceremony id -- and never by counting sessions or by taking the newest one. A
# count would go green again the moment any unrelated fifth session appeared.
$manifests = @()
if (Test-Path -LiteralPath $evRootBase) {
    $manifests = @(Get-ChildItem -LiteralPath $evRootBase -Recurse -File -Filter 'manifest.json' -ErrorAction SilentlyContinue)
}
$finalized = @($manifests | Where-Object { (ReadText $_.FullName) -match '"state":\s*"finalized"' })

$ceremonySession   = ''
$ceremonyFinalized = $false
$ceremonySidecarOk = $false
$sessionDirs = @()
if (Test-Path -LiteralPath $evRootBase) {
    $sessionDirs = @(Get-ChildItem -LiteralPath $evRootBase -Directory -ErrorAction SilentlyContinue)
}
foreach ($sd in $sessionDirs) {
    # The captured calls, not the manifest: the manifest says a session finalized, the LOG AND
    # STREAMS say what it did. Both are read, because a hook that recorded the call without its
    # body would still prove the session observed the ceremony.
    $hay = ''
    foreach ($f in @(Get-ChildItem -LiteralPath $sd.FullName -Recurse -File -Include '*.json','*.jsonl' -ErrorAction SilentlyContinue)) {
        $hay += (ReadText $f.FullName)
    }
    if (-not $hay) { continue }
    # BOTH markers are required. The wrapper name alone would match a session that merely mentioned
    # it; the ceremony id alone could appear in a ledger copy. Together they name THIS run.
    if (($hay -match 'mission-ceremony-record') -and $ceremonyId -and ($hay -match [regex]::Escape($ceremonyId))) {
        $ceremonySession = $sd.Name
        $mf = Join-Path $sd.FullName 'manifest.json'
        $ceremonyFinalized = (Test-Path -LiteralPath $mf) -and ((ReadText $mf) -match '"state":\s*"finalized"')
        $sc = Join-Path $sd.FullName 'capture-gaps.yaml'
        $ceremonySidecarOk = (Test-Path -LiteralPath $sc) -and ((ReadText $sc) -match '(?m)^capture_gaps:\s*\[\]\s*$')
        break
    }
}

$detail = @"
$(if ($s5NoAsk) { "    GIT NOT ASKED, AND ITS ROWS RED: $s5NoAsk`n" })    (1) a ceremony record is in the append-only ledger : $ranCeremony   (expect True)
        ceremony id                                    : $ceremonyId
        the commit that carried it                     : $(if ($ceremonyCommit) { $ceremonyCommit } else { '(none found)' })
    (2) BOTH patched gates re-exercised against the LIVE tree just now (-CheckOnly, no mutation):
        wrapper exit                                   : $cExit   (expect 0)
        Assert-CleanGitTree passed                     : $gate1Live   (expect True)
        Assert-CleanWorkingTree passed                 : $gate2Live   (expect True)
    (3) THE CEREMONY'S OWN EVIDENCE SESSION, identified by CONTENT in this mission's plane:
        evidence sessions present in the plane         : $($sessionDirs.Count)
        the session whose captured calls name BOTH the wrapper and '$ceremonyId':
                                                       : $(if ($ceremonySession) { $ceremonySession } else { '(NONE -- no next-gen hook observed this ceremony)' })
        that session's manifest is finalized           : $ceremonyFinalized   (expect True)
        that session's capture-gaps sidecar is empty   : $ceremonySidecarOk   (expect True)
    (4) every OTHER evidence session in the mission is also accounted for:
        evidence sessions finalized                    : $($finalized.Count) of $($manifests.Count)
        capture-gaps sidecars found                    : $($sidecars.Count)
        sidecars that are NOT empty                    : $($nonEmpty.Count)   (expect 0)
    NOTE: mission-state 'Closed' is NOT asserted -- dropped by amendment 6.
    NOTE: (3) is what E28 asks for. A count of sessions, or 'all manifests are finalized', is a
          true statement about OTHER sessions and says nothing about where THIS operation ran.
"@
$s5Rows = [ordered]@{
    '(1) a ceremony record is in the append-only ledger'                  = [bool]$ranCeremony
    '(1) the commit that carried it exists'                               = $(if ($s5GitWhy) { $s5GitWhy } else { [bool]$ceremonyCommit })
    '(2) both patched clean-tree gates pass against the live tree'        = $(if ($s5GitWhy) { $s5GitWhy } else { [bool]$bothGates })
    '(3) the ceremony''s own evidence session, its manifest finalized, its sidecar empty' = $(if ($s5PlaneWhy) { $s5PlaneWhy } else { [bool]($ceremonySession -and $ceremonyFinalized -and $ceremonySidecarOk) })
    '(4) at least one evidence session and one capture-gaps sidecar'       = $(if ($s5PlaneWhy) { $s5PlaneWhy } else { [bool](($sidecars.Count -ge 1) -and ($manifests.Count -ge 1)) })
    '(4) every evidence session finalized, every sidecar empty'           = $(if ($s5PlaneWhy) { $s5PlaneWhy } else { [bool](($nonEmpty.Count -eq 0) -and ($finalized.Count -eq $manifests.Count)) })
}
Write-Wp6Member -Id 'S-5' -Title "a ceremony-class operation completes with the next-gen hooks live, and ITS OWN evidence session finalizes" -Rows $s5Rows -Tail $detail

# =============================================================================================
# ZERO-PASTE ATTESTATION -- exactly one operator act across S-1..S-5
# =============================================================================================
# HOW AN OPERATOR ACT IS COUNTED, stated so the number can be checked rather than trusted.
# Two independent records, and both must agree:
#   (a) GATE ARTIFACTS. A gate can only be created by a human running mission-gate.ps1: the guard
#       hard-denies every agent role from writing under the gates directory (T-3, driven in WP-4).
#       So each gate artifact IS one operator act, recorded.
#   (b) THE PROMPT LOG. The smoke repo registers a UserPromptSubmit hook that appends a line for
#       every interactive prompt submitted in that repo. The smoke mission is driven entirely by
#       the runner and the CLI, so this log must be EMPTY -- no human typed into it.
# One act by (a), zero by (b), and the one act is the push gate.
# THE PROMPT REGISTER, by the operator's ruling. The attestation counts HUMAN
# build-authorization acts. An operator-kind line is excluded from that count **iff** it carries a
# written classification BOUND TO A DISCLOSURE ARTIFACT -- a named classification and a reference to
# the artifact that discloses it. Nothing else is excludable, and an unclassified operator-kind line
# still FAILS.
#
# WHY THE EXCLUSIONS LIVE HERE, IN THE INSTRUMENT, AND NOT IN THE REGISTER. The register is
# hook-written and is NOT RESTARTABLE: there is no operation that clears it and none may be
# invented. So a line that should not count against the attestation is classified HERE, against the
# session id the hook recorded, and the classification names the artifact that discloses it. The
# register keeps saying exactly what happened; the attestation says what it counted and why.
#
# THE RULE WAS FIXED BEFORE THE NUMBER WAS RECOMPUTED. This table was written from the ruling, not
# fitted to a count -- which is the only thing that stops an exclusion list from becoming a way to
# make any number come out right.
$promptExclusions = @(
    [pscustomobject]@{
        session        = '5e1fb11d-0b5e-4d1a-9c0d-00000000d1a6'
        classification = 'builder-diagnostic'
        disclosure     = '.mission-runtime/disclosures/builder-diagnostic-prompt.md'
        note           = 'the one operator-kind line tools\lam\build-smoke-mission.ps1 writes at the smoke mission root, from its own session, by driving the UserPromptSubmit hook once with no dispatch marker set -- so the register carries a line this exclusion path really classifies. No human typed it; the builder writes the disclosure beside it.'
    }
)

# EVERY REGISTER IN THE MISSION, NOT JUST THE MISSION-ROOT ONE.
#
# THE DEFECT THIS REPLACES (V-1 round 2, WP-6). This member read exactly ONE file --
# <SmokeRoot>/.mission-runtime/operator-prompts.log -- while asserting on its own face that it
# printed EVERY prompt-register line and that "nothing is hidden". The UserPromptSubmit hook writes
# to $CLAUDE_PROJECT_DIR, and a dispatched worker's project dir is its WORKTREE, so this mission
# holds SIX registers: the mission root's and one per worktree. Eleven hook-recorded lines sat in
# shards the count never opened.
#
# WHY THAT WAS NOT MERELY UNTIDY. All eleven happen to be kind=worker today, so the asserted count
# was still true -- but a human prompting a worktree-rooted session would be recorded kind=operator
# in a register the counter never reads. The LAM_DISPATCH marker that E31 names as this record's
# compensating control was guarding a register the counter did not open, which makes the control
# decorative exactly where it matters. An attestation that claims completeness must go and get it.
# WHERE A DISCLOSURE MAY RESOLVE: the smoke root, this checkout, and THE PRIMARY CHECKOUT. The row's
# disclosure is a record on a runtime plane, and the runtime plane is ignored, so a linked worktree never carries it:
# read from a worktree, a live smoke repository's row was rejected -- and its line counted -- for where this file
# sat. The primary checkout is git's own answer ($primaryRoot, from Get-PrimaryCheckoutRoot above), the way WP-3
# reads the primary's HALT files; outside any repository (F-1's mirror arms) git names none, and nothing is added.
# THE RULE IS UNCHANGED: a disclosure that resolves at none of these places still rejects its row, and the line counts.
$zpLookedAt = 'the smoke root, this checkout' + $(if ($primaryRoot) { ' and the primary checkout ' + $primaryRoot } else { ' (git names no primary checkout)' })
function Resolve-Wp6Disclosure {
    param([string]$Disclosure)
    if (-not $Disclosure.Trim()) { return '' }
    $cands = @($(if ([System.IO.Path]::IsPathRooted($Disclosure)) { $Disclosure } else { Join-Path $SmokeRoot $Disclosure }), (Join-Path $repoRoot $Disclosure))
    if ($primaryRoot) { $cands += (Join-Path $primaryRoot $Disclosure) }
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
    return ''
}
$promptLogs = @()
if (Test-Path -LiteralPath $SmokeRoot) {
    $promptLogs = @(Get-ChildItem -LiteralPath $SmokeRoot -Recurse -File -Force `
                        -Filter 'operator-prompts.log' -ErrorAction SilentlyContinue |
                    Sort-Object FullName)
}
$promptRows = @()
foreach ($plog in $promptLogs) {
    $regName = $plog.FullName
    if ($regName.StartsWith($SmokeRoot)) { $regName = $regName.Substring($SmokeRoot.Length).TrimStart('\','/') }
    foreach ($l in [System.IO.File]::ReadAllLines($plog.FullName)) {
        if (-not $l.Trim()) { continue }
        $ts   = if ($l -match '^(\S+)\s') { $Matches[1] } else { '(no timestamp)' }
        $sess = if ($l -match 'session=(\S+)') { $Matches[1] } else { '' }
        $byts = if ($l -match 'prompt_bytes=(\d+)') { $Matches[1] } else { '-' }
        $kind = if ($l -match 'kind=(\S+)') { $Matches[1] } else { 'UNCLASSIFIED' }
        $exAll = @($promptExclusions | Where-Object { $_.session -eq $sess })
        # =====================================================================================
        # AN EXCLUSION ROW IS VALID IFF ITS DISCLOSURE RESOLVES.
        # =====================================================================================
        # The predicate checked only that a row EXISTED, never that its `disclosure` said anything
        # -- so an exclusion could be written with an empty reference, or with a path to an
        # artifact that does not exist, and the line would drop out of the count anyway. That makes
        # the exclusion list exactly what it was written to stop being: a way to make any number
        # come out right, needing only a plausible-looking string.
        #
        # Latent rather than live -- the one real row resolves -- and closed here rather than left
        # for the round that would have found it.
        $exValid = @($exAll | Where-Object { [bool](Resolve-Wp6Disclosure -Disclosure ([string]$_.disclosure)) })
        $exInvalid = @($exAll | Where-Object { $exValid -notcontains $_ })
        $promptRows += [pscustomobject]@{
            register = $regName
            ts = $ts; session = $sess; bytes = $byts; kind = $kind
            classification = $(if ($exValid.Count -eq 1) { $exValid[0].classification } elseif ($kind -eq 'worker') { 'runner-submitted' } else { $kind })
            disclosure     = $(if ($exValid.Count -eq 1) { $exValid[0].disclosure } else { '' })
            resolved       = $(if ($exValid.Count -eq 1) { Resolve-Wp6Disclosure -Disclosure ([string]$exValid[0].disclosure) } else { '' })
            # A REJECTED ROW MUST BE VISIBLE EVEN WHEN ITS DISCLOSURE IS EMPTY (V-1 round 4, WP-6).
            # This recorded the offending disclosure STRING, so a wholly-empty one produced '' --
            # and the annotation guard downstream is falsy on '', so the rejection printed nothing.
            # The empty-disclosure case is PRECISELY what the disclosure rule exists to close, and it was
            # the one case that closed silently: enforced correctly, explained not at all. An
            # exclusion nobody can read is a hole, and so is a REJECTION nobody can read.
            invalid_exclusion = $(if ($exInvalid.Count -ge 1) { "rejected: disclosure='$($exInvalid[0].disclosure)'" } else { '' })
            # COUNTS iff it is operator-kind AND carries no VALID disclosure-bound classification.
            counts         = (($kind -ne 'worker') -and ($exValid.Count -ne 1))
        }
    }
}
$promptLines   = @($promptRows | Where-Object { $_.counts }).Count
$workerPrompts = @($promptRows | Where-Object { $_.kind -eq 'worker' }).Count
$excludedRows  = @($promptRows | Where-Object { $_.disclosure })
# An UNCLASSIFIED line -- neither worker nor operator -- is counted, exactly as before. It is the
# case nobody has reasoned about, so it is the one least safe to wave through.
$unclassified  = @($promptRows | Where-Object { $_.kind -eq 'UNCLASSIFIED' }).Count
# GATE ACTS ARE COUNTED BY CLASS, not by filename.
# The attestation is about BUILD AUTHORIZATION -- a human authorizing an irreversible effect -- and
# a supersession ratification is not one of those: it is a GOVERNANCE act, a human adjudicating a
# HALT on a record that already exists (Ruling A2). Counting the two together made this member read
# 3 where the attestation says 1, and neither the attestation nor Ruling A2 was wrong.
# THE EXCLUSION IS STATED, NOT SILENT. Governance acts are enumerated on this member's own face
# with their kind and their authorizing operator, so a reader sees every human act in the window
# and sees which class each was counted in. An exclusion nobody can read is a hole.
# CLASSIFICATION IS SHARED CODE, not a second copy of the map: tools/lam/lam-gate-class.ps1 is the
# one definition, dot-sourced here and by mission-gate.ps1 which writes the field.
$gateFiles = @()
if (Test-Path -LiteralPath $gatesDir) {
    $gateFiles = @(Get-ChildItem -LiteralPath $gatesDir -File -Filter '*.yaml' -ErrorAction SilentlyContinue)
}
$classified          = @($gateFiles | ForEach-Object { Get-LamGateClassForArtifact -Path $_.FullName })
$buildActs           = @($classified | Where-Object { $_.class -eq 'build-authorization' })
$governanceActs      = @($classified | Where-Object { $_.class -eq 'governance' })
# A gate this member cannot classify is a FAILURE, never a quiet omission. Dropping what it did not
# recognise is how a new gate kind would slip past the attestation unmentioned.
$unclassifiableGates = @($classified | Where-Object { -not $_.ok })

$buildKinds  = @($buildActs | ForEach-Object { $_.kind })
$isPushGate  = (($buildActs.Count -eq 1) -and ($buildKinds[0] -eq 'push'))
# WHO CONFIRMED THE ACT IS READ OFF THE ARTIFACT, NOT ASSUMED. A gate the console minted carries the credential its
# confirm act used; `operator_credential: injected-seam` is the seam's label -- no human confirmed that gate (the
# smoke-mission builder composes its gates so, and says so on their first line). Such an act still COUNTS as the one
# build-authorization act by class, which is what (a) measures, and this member's face says it was not a human's.
$seamActs = @($buildActs | Where-Object { (ReadText $_.path) -match '(?m)^operator_credential:[ \t]*injected-seam[ \t]*\r?$' })
$zpSeamNote = $(if ($seamActs.Count -gt 0) { "   [the build-authorization act counted is BUILDER-COMPOSED (operator_credential: injected-seam) -- no human confirmed it]" } else { '' })

$govLines = ''
foreach ($g in $governanceActs) {
    $gt = ReadText $g.path
    $gBy2 = if ($gt -match '(?m)^authorized_by:\s*(\S+)') { $Matches[1] } else { '(unrecorded)' }
    $govLines += "          - $($g.name)  kind=$($g.kind)  authorized_by=$gBy2  [$($g.reason)]`n"
}
if (-not $govLines) { $govLines = "          (none)`n" }
$badLines = ''
foreach ($b in $unclassifiableGates) { $badLines += "          - $($b.name)  class=$($b.class)  $($b.reason)`n" }
if (-not $badLines) { $badLines = "          (none)`n" }

$promptTable = ''
foreach ($reg in @($promptLogs)) {
    $rn = $reg.FullName
    if ($rn.StartsWith($SmokeRoot)) { $rn = $rn.Substring($SmokeRoot.Length).TrimStart('\','/') }
    $inThis = @($promptRows | Where-Object { $_.register -eq $rn })
    $promptTable += ("          register: {0}   lines: {1}`n" -f $rn, $inThis.Count)
    foreach ($r in $inThis) {
        $promptTable += ("            - {0}  session={1}  bytes={2}  kind={3}  classification={4}  counts={5}`n" -f `
                         $r.ts, $(if ($r.session) { $r.session } else { '(none)' }), $r.bytes, $r.kind, $r.classification, $r.counts)
        if ($r.disclosure) { $promptTable += "                disclosed in: $($r.disclosure)   (resolved at $($r.resolved))`n" }
        if ($r.invalid_exclusion) { $promptTable += "                EXCLUSION ROW REJECTED -- $($r.invalid_exclusion) is empty or does not resolve at $zpLookedAt; this line COUNTS`n" }
    }
}
if (-not $promptTable) { $promptTable = "          (no prompt register exists anywhere in the mission)`n" }
# COMPUTED HERE, NOT IN THE HERE-STRING. `$($x | Where-Object {...}).Count` inside a here-string
# interpolates the PIPELINE and then renders `.Count` as LITERAL TEXT, so that line could never
# print a number (V-1 round 4, WP-6). Only `$(...)` around the WHOLE expression evaluates, and the
# simplest way to be sure is to compute it outside and interpolate a variable.
$rejectedExclusions = @($promptRows | Where-Object { $_.invalid_exclusion }).Count

$detail = @"
    (a) build-authorization acts: $($buildActs.Count) (expect 1); governance acts: $($governanceActs.Count), excluded by class, listed
        the one build-authorization act is a push gate : $isPushGate   (expect True)
        confirmed by a human (its operator_credential)  : $(if ($seamActs.Count -gt 0) { 'NO -- injected-seam: the act was composed through the console''s seam (a built smoke mission''s gate), so "HUMAN" in this member''s title does not hold for it' } else { 'not injected-seam' })
        build-authorization gates counted:
$(if ($buildActs.Count) { ($buildActs | ForEach-Object { "          - $($_.name)  kind=$($_.kind)  [$($_.reason)]" }) -join "`n" } else { '          (none)' })
        governance gates EXCLUDED BY CLASS, enumerated:
$govLines        gates that could NOT be classified : $($unclassifiableGates.Count)   (expect 0 -- an unclassifiable gate FAILS, it is never dropped)
$badLines    (b) THE PROMPT REGISTERS -- ALL $($promptLogs.Count) OF THEM, EVERY LINE, counted or not.
        The UserPromptSubmit hook writes to the PROJECT dir, and a dispatched worker's project dir
        is its WORKTREE, so a mission has one register per worktree plus the mission root's. This
        member read only the mission root's until V-1 round 2 opened the other five.
$promptTable        counted as HUMAN acts        : $promptLines   (expect 0)
        runner-submitted, not human  : $workerPrompts
        excluded, disclosure-bound   : $($excludedRows.Count)   (each names its classification and the artifact disclosing it, above)
        unclassified                 : $unclassified   (expect 0 -- an unclassified line is COUNTED, never assumed harmless)
    total HUMAN build-authorization acts across S-1..S-5 : $($buildActs.Count + $promptLines + $unclassified)   (expect exactly 1)
        exclusion rows REJECTED as invalid : $rejectedExclusions   (expect 0)
    RULE (amendment 16, superseding amendment 13's wording): register lines are
    IMMUTABLE and CONTENT-FREE -- the hook writes at submit time and the register is not restartable
    -- so classification is a READ-TIME JOIN against the disclosure table above, never something a
    line "carries". An exclusion row is valid IFF its disclosure reference is non-empty AND resolves
    to an existing artifact; otherwise the line COUNTS. The rule was fixed before this number was
    recomputed. E31: each record names its compensating control -- the gate register's is T-3
    (a gate is agent-unmintable); the prompt register's is the runner's LAM_DISPATCH marker.
"@
# THE GATES ARE TRACKED AND ALWAYS COUNTED; THE PROMPT REGISTERS ARE NOT. Where the smoke root holds no
# runtime plane, an empty register table is ABSENCE, not zero human prompts, and the two register rows
# SKIP by name rather than pass vacuously.
$zpSkip = $(if ($smokeExists -and -not $smokePlane) { $smokeNoPlaneWhy + ' -- an empty register table here would be absence, not zero human prompts' } else { '' })
$zpRows = [ordered]@{
    '(a) exactly one build-authorization act, and it is the push gate'    = [bool]$isPushGate
    '(a) no gate this member cannot classify'                           = ($unclassifiableGates.Count -eq 0)
    '(b) no prompt-register line counts as a human act'                 = $(if ($zpSkip) { $zpSkip } else { ($promptLines -eq 0) })
    '(b) no prompt-register line is unclassified'                       = $(if ($zpSkip) { $zpSkip } else { ($unclassified -eq 0) })
}
Write-Wp6Member -Id 'ZP' -Title ('exactly one HUMAN build-authorization act across S-1..S-5, and it is the push gate; every gate and every prompt-register line enumerated with why it counted' + $zpSeamNote) `
    -Rows $zpRows -Tail $detail

Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "------------------------------------------------------------------------------"
if ($failures -eq 0 -and $skips -eq 0) { Write-Host " WP-6: all $checksRun checks passed." }
elseif ($failures -eq 0) {
    Write-Host " WP-6: $($checksRun - $skips) of $checksRun checks passed, $skips SKIPPED -- a skip is not a pass; see the [SKIP] line(s) above."
}
else { Write-Host (" WP-6: $failures of $checksRun checks FAILED." + $(if ($skips -gt 0) { '  (' + $skips + ' SKIPPED.)' } else { '' })) }
Write-Host "------------------------------------------------------------------------------"
Write-Host "EXIT: $failures"
exit $failures
