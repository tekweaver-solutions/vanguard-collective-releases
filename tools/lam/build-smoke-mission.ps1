#Requires -Version 5.1
<#
.SYNOPSIS
  Builds the smoke mission the acceptance instruments read: a LIVE git repository <parent>\lam-smoke
  with its bare origin <parent>\lam-smoke-origin.git beside it, carrying the residue of one dispatch
  run (D-1, D-1b, D-1c, D-2, D-3). No CLI worker is spawned.

.DESCRIPTION
  WHERE. -SmokeRoot names the mission root; without it, LAM_SMOKE_ROOT; without that, the DEFAULT:
  lam-smoke beside the PRIMARY checkout of the repository this file sits in (git's own answer, so a
  linked worktree builds where the primary checkout reads), else beside this checkout. The origin is
  always lam-smoke-origin.git beside the root, which is where WP-6 looks for it. The builder REFUSES,
  before writing anything, a root or an origin that already exists, a root that lands inside a .mission or
  .mission-runtime folder (a goal evaluator scans those and would read the mission's records as its
  own), a root that lands inside a git work tree, and a segment ending in a dot or a space -- each judged
  where the root really lands: its nearest existing folder resolved to its final path (short names
  expanded, junctions followed), the folders still to be made appended. It never overwrites and never
  deletes: to rebuild, remove both folders first.

  FROM WHAT. The plain files under tools\lam\smoke-mission\ (shipped with the framework): every path
  segment spelled dot-<name> becomes .<name>, a trailing .src is dropped, and *.supersession-marker.yaml
  becomes *.superseded.yaml; templates\ is the builder's own and is not copied. Into the mission it also
  copies, with line endings made LF, the five framework files its ceremony and its clean-tree gates run:
  tools\mission-lib.ps1, tools\mission-spec-accept.ps1, tools\lam\lam-verify-admission.ps1,
  tools\lam\lam-gate-class.ps1 and docs\framework\evidence-manifest.schema.json.

  WHAT IT DOES, IN ORDER -- every act the residue records, performed for real:
    git      the commits (fixed identity, fixed dates), one worktree per dispatch under
             .claude\worktrees with relative links, the merges onto main, the push to the origin;
    checks   each validator result is written only after the builder's own check of each assertion
             came out as the result records it;
    hooks    this checkout's evidence hooks, driven with the payloads a session sends
             (CLAUDE_PROJECT_DIR = the mission root): a runner-owned evidence session per dispatch,
             finalised by the dispatch-end finaliser with an empty capture-gaps sidecar; the builder's
             own session, whose one push attempt the guard DENIES before any push gate exists, then
             finalised; one prompt-register line per worktree (kind=worker) and one builder-diagnostic
             line at the root (kind=operator), disclosed in .mission-runtime\disclosures\;
    gates    tools\lam\mission-gate.ps1 -ComposeOnly composes the two supersession ratifications and,
             AFTER the push, the push gate bound to the tip the origin then holds (no sha is guessed),
             then its revocation; the builder writes the composed bytes. USERNAME and COMPUTERNAME
             read smoke-operator / SMOKE-HOST in that child, and binds_resolved is written relative to
             the mission root, so no gate names the host. operator_credential reads injected-seam:
             no operator confirmed these gates, and the artifact says so;
    decider  the pre-push decider installed for this checkout's evidence-pre-push.ps1;
    ceremony this mission's tools\mission-ceremony-record.ps1, both clean-tree gates, a ledger append
             and an atomic commit.

  DETERMINISM. Every commit up to and including the pushed tip carries fixed content, identity and
  dates, so two builds from the same framework files give the same ids for them. The commits after the
  push carry what the run measured -- the anchors' capture-gaps digests and the ledger's timestamp --
  and differ between builds.

  The install records nothing about this mission. It is a post-install step (LAM-INSTALL section 10).

  EXIT: 0 built; 2 refused before anything was written; 1 the build failed part way (the folders are
  left for inspection and the message names the step).
#>
[CmdletBinding()]
param(
    [string]$SmokeRoot,
    # INTERNAL (RELEASE-4 S2 F-H18): the build runs as a child of the invocation, so every environment variable it sets
    # (the fixed identity, GIT_CONFIG_*, the removal of every GIT_* it inherits) dies with that child and the caller's
    # process is left as it was -- the operator's next commit in the same terminal carried the fixture identity before.
    # The parent makes the isolation folder (the absent global configuration git is pointed at), hands it over, and
    # removes it when the child ends; nothing is written beside the smoke root.
    [switch]$BuilderChild,
    [string]$IsolationDir
)

$ErrorActionPreference = 'Stop'
if (-not $BuilderChild) {
    $iso = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-smoke-iso-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    $null = [System.IO.Directory]::CreateDirectory($iso)
    $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-BuilderChild', '-IsolationDir', $iso)
    if ($SmokeRoot) { $childArgs += @('-SmokeRoot', $SmokeRoot) }
    # The child is Windows PowerShell 5.1 by its own path, never $PSHOME's: under PowerShell 7 $PSHOME holds pwsh.exe and
    # no powershell.exe (UI-2 S1c A-12, register row 522); the hooks the build drives run under 5.1 as the harness runs them.
    $winPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    try { & $winPs @childArgs; $childExit = $LASTEXITCODE }
    finally { try { [System.IO.Directory]::Delete($iso, $true) } catch { } }
    exit $childExit
}
$repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceRoot = Join-Path $PSScriptRoot 'smoke-mission'
$utf8       = New-Object System.Text.UTF8Encoding($false)

# The builder's own session (the denial and the diagnostic prompt) and its one diagnostic prompt. WP-6
# ZP's exclusion table names this session and the disclosure written below: the two change together.
$builderSession = '5e1fb11d-0b5e-4d1a-9c0d-00000000d1a6'
$diagPrompt     = 'smoke builder: is the prompt register hook live here?'
$ceremonyId     = 'ledger-ceremony-smoke-001'
$identity       = @{ name = 'Smoke Builder'; email = 'smoke-builder@example.invalid' }
$script:hooksDir = ''

function Fail { param([string]$Step, [string]$Why) Write-Host "BUILD FAILED at $Step -- $Why"; Write-Host "EXIT: 1"; exit 1 }
function Refuse { param([string]$Why) Write-Host "REFUSED: $Why"; Write-Host "EXIT: 2"; exit 2 }
function Say { param([string]$Text) Write-Host $Text }

function Get-PrimaryCheckoutRoot {
    # WP-6's derivation: `git worktree list --porcelain` names the primary first; else the parent of
    # --git-common-dir; outside any repository, ''.
    param([string]$From)
    $root = ''
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $wl = & git -C $From worktree list --porcelain 2>&1
        if ($LASTEXITCODE -eq 0) { foreach ($line in @($wl)) { if ("$line" -match '^worktree\s+(.+?)\s*$') { $root = $Matches[1]; break } } }
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

function Invoke-Git {
    # Every git call. -Date pins author and committer dates; the identity and the configuration are pinned for the
    # whole process (below, before the first repository is made), and the commit-time settings again here.
    param([string]$Dir, [string[]]$Argv, [string]$Date, [switch]$Check)
    $pin = @('-c', 'core.autocrlf=false', '-c', 'core.safecrlf=false', '-c', 'commit.gpgsign=false', '-c', 'merge.log=false', '-c', 'commit.cleanup=strip',
             '-c', 'i18n.commitEncoding=UTF-8')
    if ($script:hooksDir) { $pin += @('-c', ('core.hooksPath=' + $script:hooksDir)) }
    $saved = @{ A = $env:GIT_AUTHOR_DATE; C = $env:GIT_COMMITTER_DATE }
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        if ($Date) { $env:GIT_AUTHOR_DATE = $Date; $env:GIT_COMMITTER_DATE = $Date }
        $o = @(& git -C $Dir @pin @Argv 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
        $env:GIT_AUTHOR_DATE = $saved.A; $env:GIT_COMMITTER_DATE = $saved.C
    }
    if ($Check -and $code -ne 0) { Fail ("git " + ($Argv -join ' ')) ("exit $code -- " + ($o -join ' | ')) }
    return [pscustomobject]@{ out = (($o -join "`n").Trim()); exit = $code }
}

function Get-Sha256 { param([byte[]]$Bytes)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return (($h.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $h.Dispose() }
}
function Get-FileSha256 { param([string]$Path) return (Get-Sha256 -Bytes ([System.IO.File]::ReadAllBytes($Path))) }

function Write-LfFile {
    # UTF-8 without BOM, every CR LF made LF.
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8)
}

function Expand-Template {
    # {{NAME}} placeholders; a placeholder left unfilled is a build failure, never a literal.
    param([string]$Text, [hashtable]$Values)
    foreach ($k in $Values.Keys) { $Text = $Text.Replace('{{' + $k + '}}', [string]$Values[$k]) }
    if ($Text -match '\{\{[A-Z0-9_]+\}\}') { Fail 'template' "unfilled placeholder $($Matches[0])" }
    return $Text
}

function Get-MissionPath {
    # A source path, relative to tools\lam\smoke-mission, as the mission spells it.
    param([string]$Rel)
    $segs = @($Rel -split '[\\/]' | ForEach-Object { if ($_ -like 'dot-*') { '.' + $_.Substring(4) } else { $_ } })
    $p = ($segs -join '\')
    if ($p.EndsWith('.src')) { $p = $p.Substring(0, $p.Length - 4) }
    if ($p.EndsWith('.supersession-marker.yaml')) { $p = $p.Substring(0, $p.Length - '.supersession-marker.yaml'.Length) + '.superseded.yaml' }
    return $p
}

function Invoke-WithEnv {
    # Run -Body with -Set variables set and -Clear variables removed, restoring every one afterwards.
    param([hashtable]$Set, [string[]]$Clear, [scriptblock]$Body)
    $names = @(@($Set.Keys) + @($Clear) | Select-Object -Unique)
    $saved = @{}
    foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
    try {
        # [NullString]::Value removes a variable under 5.1 and PowerShell 7 alike; a bare $null arrives as '' and under 7
        # leaves it set and empty (UI-2 S1c A-12, register row 522).
        foreach ($n in @($Clear)) { [Environment]::SetEnvironmentVariable($n, [NullString]::Value) }
        foreach ($n in @($Set.Keys)) { [Environment]::SetEnvironmentVariable($n, [string]$Set[$n]) }
        return (& $Body)
    } finally {
        foreach ($n in $names) { if ($null -eq $saved[$n]) { [Environment]::SetEnvironmentVariable($n, [NullString]::Value) } else { [Environment]::SetEnvironmentVariable($n, $saved[$n]) } }
    }
}

# Session markers a hook or the gate tool would read from this process; each child is handed exactly
# the ones its step names.
$sessionVars = @('CLAUDECODE', 'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_ENTRYPOINT', 'CLAUDE_PROJECT_DIR',
                 'LAM_DISPATCH', 'MISSION_DISPATCH_ID', 'LAM_ORCHESTRATOR_SESSION', 'VANGUARD_AUTH_MODE')

function Invoke-Hook {
    # One hook script, as a child, with its stdin and the environment its step names.
    param([string]$Script, [string]$Stdin, [hashtable]$Env)
    return (Invoke-WithEnv -Set $Env -Clear $sessionVars -Body {
        $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try {
            if ($null -ne $Stdin) { $o = @($Stdin | & powershell -NoProfile -ExecutionPolicy Bypass -File $Script 2>&1 | ForEach-Object { "$_" }) }
            else { $o = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Script 2>&1 | ForEach-Object { "$_" }) }
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prevEap }
        [pscustomobject]@{ out = ($o -join "`n"); exit = $code }
    })
}

function ConvertTo-JsonLine { param($Object) return ($Object | ConvertTo-Json -Compress -Depth 12) }

# Before git is first asked anything -- even where the primary checkout is -- every GIT_* variable is removed from this
# process: one naming another repository, work tree or ceiling would move the default root or flip a refusal below.
foreach ($gv in @(Get-ChildItem Env: | Where-Object { $_.Name -like 'GIT_*' } | ForEach-Object { $_.Name })) {
    [Environment]::SetEnvironmentVariable($gv, [NullString]::Value)
}

# =================================================================================================
# WHERE
# =================================================================================================
$primaryRoot = Get-PrimaryCheckoutRoot -From $repoRoot
$anchor      = if ($primaryRoot) { $primaryRoot } else { $repoRoot }
$smokeEnv    = [Environment]::GetEnvironmentVariable('LAM_SMOKE_ROOT')
if ($SmokeRoot)    { $source = 'parameter -SmokeRoot' }
elseif ($smokeEnv) { $SmokeRoot = $smokeEnv; $source = 'environment LAM_SMOKE_ROOT' }
else               { $SmokeRoot = Join-Path (Split-Path -Parent $anchor) 'lam-smoke'; $source = "default -- beside $(if ($primaryRoot) { 'the primary checkout' } else { 'this checkout' }) $anchor" }
$SmokeRoot  = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SmokeRoot).TrimEnd('\')
$parentDir  = Split-Path -Parent $SmokeRoot
$leaf       = Split-Path -Leaf $SmokeRoot
$originLeaf = 'lam-smoke-origin.git'
$originPath = Join-Path $parentDir $originLeaf
# The origin as the mission names it -- in its remote and in the push gate's origin_url -- is RELATIVE to the root,
# so neither carries the folder the mission was built in.
$originUrl  = '../' + $originLeaf
Say "smoke root  : $SmokeRoot   ($source)"
Say "origin      : $originPath"
Say "framework   : $repoRoot"

if (-not $parentDir -or -not $leaf) { Refuse "the smoke root $SmokeRoot has no parent folder" }
if (Test-Path -LiteralPath $SmokeRoot)  { Refuse "the smoke root $SmokeRoot already exists -- the builder never overwrites; remove it (and the origin) to rebuild" }
if (Test-Path -LiteralPath $originPath) { Refuse "the origin $originPath already exists -- the builder never overwrites; remove it (and the root) to rebuild" }
if ($SmokeRoot.Length -gt 120) { Refuse "the smoke root path is $($SmokeRoot.Length) characters; the deepest file it holds needs it at 120 or fewer" }
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { Refuse "the sources are absent at $sourceRoot" }

# WHERE THE ROOT REALLY LANDS, NOT HOW IT IS SPELLED. The nearest folder of the root that exists is resolved to its
# FINAL path -- short (8.3) names expanded, junctions and symbolic links followed -- and the segments still to be made
# are appended. A segment Windows would silently trim (a trailing dot or space) is refused outright, since what it names
# is not what would be made. The refusals below judge that real path.
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using Microsoft.Win32.SafeHandles;
public static class SmokeFinalPath {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr sa, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern uint GetFinalPathNameByHandleW(SafeFileHandle h, StringBuilder buf, uint size, uint flags);
    public static string Of(string path) {
        using (SafeFileHandle h = CreateFileW(path, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero)) {
            if (h.IsInvalid) { return null; }
            StringBuilder b = new StringBuilder(32768);
            uint n = GetFinalPathNameByHandleW(h, b, 32768, 0);
            if (n == 0 || n >= 32768) { return null; }
            string s = b.ToString();
            if (s.StartsWith(@"\\?\UNC\")) { return @"\\" + s.Substring(8); }
            if (s.StartsWith(@"\\?\")) { return s.Substring(4); }
            return s;
        }
    }
}
'@
$toMake = @()
$existing = $SmokeRoot
while ($existing -and -not (Test-Path -LiteralPath $existing -PathType Container)) {
    if (Test-Path -LiteralPath $existing) { Refuse "$existing is a file, not a folder, so the smoke root $SmokeRoot cannot be made" }
    $toMake = @(Split-Path -Leaf $existing) + $toMake
    $existing = Split-Path -Parent $existing
}
if (-not $existing) { Refuse "no folder of the smoke root $SmokeRoot exists" }
foreach ($seg in $toMake) { if ($seg -match '[. ]$') { Refuse "the smoke root $SmokeRoot has a segment ending in a dot or a space ('$seg'), which Windows would silently trim" } }
$existingFinal = [SmokeFinalPath]::Of($existing)
if (-not $existingFinal) { Refuse "the final path of $existing, the nearest folder of the smoke root that exists, could not be read" }
$realRoot = $existingFinal.TrimEnd('\')
foreach ($seg in $toMake) { $realRoot = Join-Path $realRoot $seg }
if (@($realRoot -split '\\' | ForEach-Object { $_.TrimEnd('. ') } | Where-Object { $_ -ieq '.mission' -or $_ -ieq '.mission-runtime' }).Count -gt 0) {
    Refuse "the smoke root $SmokeRoot lands inside a .mission or .mission-runtime folder ($realRoot), where a goal evaluator would read the mission's records as its own"
}
if ($realRoot.Length -gt 120) { Refuse "the smoke root lands at $realRoot, $($realRoot.Length) characters; the deepest file it holds needs it at 120 or fewer" }
if ($realRoot -ne $SmokeRoot) { Say "lands at    : $realRoot" }

# THE BUILDER'S GIT IS THIS HOST'S IN NOTHING BUT ITS EXECUTABLE. For this process and every child it starts -- the
# hooks, the gate tool, the ceremony -- the commit identity is the fixed one (GIT_AUTHOR_* and GIT_COMMITTER_* override
# any repository configuration, so they are SET, never left to the host); the global and system configuration are not
# read (a host's commit template, encoding, hooks path or include cannot reach a commit); and the global ignore and
# attributes files, which git reads from XDG_CONFIG_HOME or HOME whatever the configuration says, are pointed at files
# that do not exist, so a host's global ignore cannot hide a mission file from `git add` and its global attributes
# cannot re-encode one. Every other GIT_* variable was removed above. Repositories are made with an empty template, so
# no template hook is copied in.
# F-H18: inside the isolation folder the parent made (and removes), never beside the smoke root.
if (-not $IsolationDir) { $IsolationDir = Join-Path ([System.IO.Path]::GetTempPath()) ('lam-smoke-iso-' + [guid]::NewGuid().ToString('N').Substring(0, 12)); $null = [System.IO.Directory]::CreateDirectory($IsolationDir) }
$noGlobal = Join-Path $IsolationDir 'no-global-gitconfig'
if (Test-Path -LiteralPath $noGlobal) { Refuse "$noGlobal exists; the builder names it as the global configuration, ignore and attributes file git must find absent" }
$env:GIT_AUTHOR_NAME     = $identity.name; $env:GIT_AUTHOR_EMAIL    = $identity.email
$env:GIT_COMMITTER_NAME  = $identity.name; $env:GIT_COMMITTER_EMAIL = $identity.email
$env:GIT_CONFIG_NOSYSTEM = '1'
$env:GIT_CONFIG_GLOBAL   = $noGlobal
$env:GIT_CONFIG_COUNT    = '2'
$env:GIT_CONFIG_KEY_0    = 'core.excludesFile';  $env:GIT_CONFIG_VALUE_0 = $noGlobal
$env:GIT_CONFIG_KEY_1    = 'core.attributesFile'; $env:GIT_CONFIG_VALUE_1 = $noGlobal
# Asked of the nearest folder that EXISTS, by its final path, and with the host's configuration already shut out: a
# root whose parent is yet to be made inside a work tree, or reached through a junction into one, is refused too.
if ((Invoke-Git -Dir $existingFinal -Argv @('rev-parse', '--is-inside-work-tree')).out -eq 'true') {
    Refuse "the smoke root $SmokeRoot lands inside a git work tree ($existingFinal is inside one): the smoke mission must be the top level of its own repository"
}
$gitVer = (Invoke-Git -Dir $repoRoot -Argv @('--version')).out
if ($gitVer -notmatch 'git version (\d+)\.(\d+)' -or ([int]$Matches[1] -lt 2) -or (([int]$Matches[1] -eq 2) -and ([int]$Matches[2] -lt 48))) {
    Refuse "git 2.48 or later is required (worktrees with relative links); found '$gitVer'"
}

$fw = [ordered]@{
    guard       = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-guard-pretooluse.ps1'
    post        = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-post-tool-use.ps1'
    stop        = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-stop-finalize.ps1'
    dispatchEnd = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-dispatch-end.ps1'
    decider     = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\evidence-pre-push.ps1'
    checker     = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\check-prepush-installed.ps1'
    hookLib     = Join-Path $repoRoot 'tools\evidence-hooks-next\hooks\lib\evidence-common.ps1'
    prompt      = Join-Path $repoRoot 'tools\lam\record-operator-prompt.ps1'
    gateTool    = Join-Path $repoRoot 'tools\lam\mission-gate.ps1'
}
foreach ($k in $fw.Keys) { if (-not (Test-Path -LiteralPath $fw[$k] -PathType Leaf)) { Refuse "the framework file $($fw[$k]) is absent" } }
$vendored = @('tools\mission-lib.ps1', 'tools\mission-spec-accept.ps1', 'tools\lam\lam-verify-admission.ps1',
              'tools\lam\lam-gate-class.ps1', 'docs\framework\evidence-manifest.schema.json')
foreach ($v in $vendored) { if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $v) -PathType Leaf)) { Refuse "the framework file $v is absent from $repoRoot" } }

$sources = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($sourceRoot.Length + 1) })
$mirror  = @($sources | Where-Object { $_ -notlike 'templates\*' })
$tmplDir = Join-Path $sourceRoot 'templates'
function Get-Source { param([string]$Rel) return [System.IO.File]::ReadAllText((Join-Path $sourceRoot $Rel)) }
function Get-Template { param([string]$Rel) return [System.IO.File]::ReadAllText((Join-Path $tmplDir $Rel)) }
Say "sources     : $($sources.Count) file(s) under $sourceRoot ($($mirror.Count) mirrored into the mission, $($sources.Count - $mirror.Count) builder templates)"

# =================================================================================================
# THE REPOSITORIES
# =================================================================================================
$null = New-Item -ItemType Directory -Path $originPath -Force
$null = New-Item -ItemType Directory -Path $SmokeRoot -Force
$script:hooksDir = (Join-Path $SmokeRoot '.git\hooks') -replace '\\', '/'
$null = Invoke-Git -Dir $originPath -Argv @('init', '--bare', '--quiet', '--template=', '-b', 'main') -Check
$null = Invoke-Git -Dir $SmokeRoot  -Argv @('init', '--quiet', '--template=', '-b', 'main') -Check
foreach ($kv in @(@('user.name', $identity.name), @('user.email', $identity.email), @('core.autocrlf', 'false'),
                  @('core.safecrlf', 'false'), @('commit.gpgsign', 'false'), @('worktree.useRelativePaths', 'true'))) {
    $null = Invoke-Git -Dir $SmokeRoot -Argv @('config', $kv[0], $kv[1]) -Check
}
$null = Invoke-Git -Dir $SmokeRoot -Argv @('remote', 'add', 'origin', $originUrl) -Check
Say "init        : $SmokeRoot (main) and $originPath (bare, main), origin = $originUrl"

# Fixed dates, one minute apart, in commit order.
$script:tick = 0
# EVERY TIME THE BUILDER WRITES IS FORMATTED IN THE INVARIANT CULTURE: a custom format's ':' is the culture's time
# separator and its year the culture's calendar, so a host's regional format would otherwise change the dates git is
# given (and refuse them) and the ids that carry them.
$script:inv = [System.Globalization.CultureInfo]::InvariantCulture
function Next-Date { $script:tick++; return ([datetime]'2026-01-01T00:00:00Z').ToUniversalTime().AddMinutes($script:tick).ToString('yyyy-MM-dd HH:mm:ss', $script:inv) + ' +0000' }
# The date the NEXT commit will carry, as a record inside it spells a time: a marker's marked_at, the probe's ran_at.
function Peek-Date { return ([datetime]'2026-01-01T00:00:00Z').ToUniversalTime().AddMinutes($script:tick + 1).ToString('yyyy-MM-ddTHH:mm:ssZ', $script:inv) }
function Commit-Main {
    param([string]$Message, [string[]]$Paths)
    foreach ($p in $Paths) { $null = Invoke-Git -Dir $SmokeRoot -Argv @('add', '--', $p) -Check }
    $null = Invoke-Git -Dir $SmokeRoot -Argv @('commit', '--quiet', '-m', $Message) -Date (Next-Date) -Check
    return (Invoke-Git -Dir $SmokeRoot -Argv @('rev-parse', 'HEAD') -Check).out
}
function Put-Mission {
    # A mirrored source into the mission, placeholders filled.
    param([string]$Rel, [hashtable]$Values = @{})
    $dst = Join-Path $SmokeRoot (Get-MissionPath -Rel $Rel)
    Write-LfFile -Path $dst -Text (Expand-Template -Text (Get-Source -Rel $Rel) -Values $Values)
    return ((Get-MissionPath -Rel $Rel) -replace '\\', '/')
}

# --- c0: the scaffold ---------------------------------------------------------------------------
$runArtifacts = @($mirror | Where-Object { $_ -match '^dot-mission\\(dispatches|validator-results)\\' })
$scaffold     = @($mirror | Where-Object { $runArtifacts -notcontains $_ })
$c0Paths = @()
foreach ($rel in $scaffold) { $c0Paths += (Put-Mission -Rel $rel) }
foreach ($v in $vendored) {
    Write-LfFile -Path (Join-Path $SmokeRoot $v) -Text ([System.IO.File]::ReadAllText((Join-Path $repoRoot $v)))
    $c0Paths += ($v -replace '\\', '/')
}
$c0 = Commit-Main -Message 'smoke mission scaffold: spec v1, five-assertion contract, goal, settings, the ceremony and the framework files it runs' -Paths $c0Paths
Say "c0 scaffold : $c0 ($($c0Paths.Count) files)"

# =================================================================================================
# A DISPATCH: worktree, register, work, evidence session, handoff, anchors
# =================================================================================================
$work = @{
    greeting = Get-Template -Rel 'work\greeting.txt'
    reworked = Get-Template -Rel 'work\greeting-reworked.txt'
    counter  = Get-Template -Rel 'work\counter.ps1.src'
    test     = Get-Template -Rel 'work\test-smoke.ps1.src'
}
$sessions = [ordered]@{}

function New-DispatchWorktree {
    param([string]$Id, [string]$Base)
    $rel = ".claude/worktrees/wt-$Id"
    # -Date pins the committer date the branch's and HEAD's reflog entries carry (+0000, not the host's zone); Peek-Date
    # reads the next fixed date without advancing it, so no commit's date, and so no commit id, moves.
    $null = Invoke-Git -Dir $SmokeRoot -Argv @('worktree', 'add', '--quiet', '--relative-paths', '-b', "worktree-wt-$Id", $rel, $Base) -Date (Peek-Date) -Check
    $wt = Join-Path $SmokeRoot ($rel -replace '/', '\')
    # The worktree's prompt register: the dispatch marker set, so the line is a worker's.
    $r = Invoke-Hook -Script $fw.prompt -Stdin '{}' -Env @{ CLAUDE_PROJECT_DIR = $wt; LAM_DISPATCH = $Id }
    if ($r.exit -ne 0) { Fail "register $Id" "record-operator-prompt exit $($r.exit): $($r.out)" }
    return $wt
}

function Invoke-Suite {
    param([string]$Dir)
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir 'tests\test-smoke.ps1') 2>&1 | Out-String).Trim(); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prevEap }
    return [pscustomobject]@{ out = $o; exit = $code }
}
function Invoke-Counter {
    param([string]$Dir)
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir 'src\counter.ps1') 2>&1 | Out-String).Trim(); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prevEap }
    return [pscustomobject]@{ out = $o; exit = $code }
}

function Invoke-DispatchSession {
    # A runner-owned evidence session, finalised: OWNER, one PostToolUse per call, the stream that is
    # the capture-gaps second arm, DISPATCH-END, then the dispatch-end finaliser -- whose figures are
    # returned. Every call is one the builder made; the stream says it was the builder's.
    param([string]$Id, [object[]]$Calls)
    $sid = "session-$Id"
    $rt  = Join-Path $SmokeRoot ".mission-runtime\evidence\$sid"
    $null = New-Item -ItemType Directory -Path $rt -Force
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', $script:inv)
    Write-LfFile -Path (Join-Path $rt 'OWNER') -Text "runner_id: build-smoke-mission.ps1`ndispatch_id: $Id`nsession_id: $sid`nspawned_at: $now`nrole: coding-strong`nmodel: none`n"
    $stream = @(ConvertTo-JsonLine @{ type = 'system'; subtype = 'builder'; note = "no CLI worker ran: the calls below are build-smoke-mission.ps1's own, made for dispatch $Id" })
    $n = 0
    foreach ($c in $Calls) {
        $n++
        $tid = 'toolu_smoke_{0}_{1:D2}' -f ($Id -replace '-', ''), $n
        $resp = @{ stdout = [string]$c.stdout; stderr = '' }
        if ($c.tool -in @('Bash', 'PowerShell')) { $resp['exit_code'] = 0 }
        $payload = ConvertTo-JsonLine @{ session_id = $sid; hook_event_name = 'PostToolUse'; tool_name = $c.tool; tool_input = $c.input; tool_response = $resp }
        $r = Invoke-Hook -Script $fw.post -Stdin $payload -Env @{ CLAUDE_PROJECT_DIR = $SmokeRoot; MISSION_DISPATCH_ID = $sid }
        if ($r.exit -ne 0) { Fail "PostToolUse $Id #$n" "exit $($r.exit): $($r.out)" }
        $stream += (ConvertTo-JsonLine @{ type = 'assistant'; message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = $tid; name = $c.tool; input = $c.input }) } })
        $stream += (ConvertTo-JsonLine @{ type = 'user'; message = @{ role = 'user'; content = @(@{ type = 'tool_result'; tool_use_id = $tid; content = [string]$c.stdout }) } })
    }
    Write-LfFile -Path (Join-Path $rt 'runner-stream.jsonl') -Text (($stream -join "`n") + "`n")
    $end = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', $script:inv)
    Write-LfFile -Path (Join-Path $rt 'DISPATCH-END') -Text "dispatch_id: $Id`nsession_id: $sid`nended_at: $end`nworker_exit: 0`n"
    $r = Invoke-Hook -Script $fw.dispatchEnd -Stdin (ConvertTo-JsonLine @{ session_id = $sid }) -Env @{ CLAUDE_PROJECT_DIR = $SmokeRoot; MISSION_DISPATCH_ID = $sid }
    $count = if ($r.out -match '(?m)^capture_gaps_count:\s*(\d+)') { [int]$Matches[1] } else { -1 }
    $gsha  = if ($r.out -match '(?m)^capture_gaps_sha256:\s*([0-9a-f]{64})') { $Matches[1] } else { '' }
    $mf    = Join-Path $rt 'manifest.json'
    $sc    = Join-Path $rt 'capture-gaps.yaml'
    if ($r.exit -ne 0 -or $count -ne 0 -or -not $gsha) { Fail "finalise $sid" "dispatch-end exit $($r.exit), capture_gaps_count $count -- $($r.out)" }
    if (-not (Test-Path -LiteralPath $mf) -or ([System.IO.File]::ReadAllText($mf) -notmatch '"state":\s*"finalized"')) { Fail "finalise $sid" 'no finalized manifest' }
    if (-not (Test-Path -LiteralPath $sc) -or ([System.IO.File]::ReadAllText($sc) -notmatch '(?m)^capture_gaps:\s*\[\]\s*$')) { Fail "finalise $sid" 'the capture-gaps sidecar is not empty' }
    $script:sessions[$Id] = [pscustomobject]@{ session = $sid; gaps = $count; gapsSha = $gsha; manifestSha = (Get-FileSha256 -Path $mf) }
    return $script:sessions[$Id]
}

function Write-Anchors {
    param([string]$Id, [string]$Kind, [string]$Base, [string]$Wt)
    $s = $script:sessions[$Id]
    $suite = Invoke-Suite -Dir $Wt
    $passed = if ($suite.exit -eq 0 -and $suite.out -ceq 'PASS') { 1 } else { 0 }
    $vals = @{
        HEAD_SHA = (Invoke-Git -Dir $SmokeRoot -Argv @('rev-parse', 'HEAD') -Check).out
        SESSION = $s.session; MANIFEST_SHA256 = $s.manifestSha
        SUITE_PASSED = $passed; SUITE_FAILED = (1 - $passed); SUITE_EXIT = $suite.exit
        DISPATCH_KIND = $Kind; DISPATCH_ID = $Id
        DISPATCH_SHA256 = (Get-FileSha256 -Path (Join-Path $SmokeRoot ".mission\dispatches\$Id.yaml"))
        BASE = $Base; TIP_SHA = (Invoke-Git -Dir $Wt -Argv @('rev-parse', 'HEAD') -Check).out
        GAPS_COUNT = $s.gaps; GAPS_SHA256 = $s.gapsSha
    }
    Write-LfFile -Path (Join-Path $SmokeRoot ".mission\dispatches\$Id.anchors.yaml") -Text (Expand-Template -Text (Get-Template -Rel 'anchors.yaml') -Values $vals)
    if ($passed -ne 1) { Fail "suite $Id" "tests\test-smoke.ps1 in the worktree: exit $($suite.exit), '$($suite.out)'" }
    return ".mission/dispatches/$Id.anchors.yaml"
}

function Invoke-BuildDispatch {
    # D-1, D-1b, D-1c: the three files, the suite, the worktree commit, the session.
    param([string]$Id, [string]$Base)
    $wt = New-DispatchWorktree -Id $Id -Base $Base
    Write-LfFile -Path (Join-Path $wt 'src\greeting.txt') -Text $work.greeting
    Write-LfFile -Path (Join-Path $wt 'src\counter.ps1') -Text $work.counter
    Write-LfFile -Path (Join-Path $wt 'tests\test-smoke.ps1') -Text $work.test
    $suite = Invoke-Suite -Dir $wt
    if ($suite.exit -ne 0 -or $suite.out -cne 'PASS') { Fail "build $Id" "the suite did not pass in the worktree: exit $($suite.exit), '$($suite.out)'" }
    $null = Invoke-Git -Dir $wt -Argv @('add', '--', 'src/greeting.txt', 'src/counter.ps1', 'tests/test-smoke.ps1') -Check
    $null = Invoke-Git -Dir $wt -Argv @('commit', '--quiet', '-m', "${Id}: greeting artifact, counter script and its test") -Date (Next-Date) -Check
    $tip = (Invoke-Git -Dir $wt -Argv @('rev-parse', 'HEAD') -Check).out
    $calls = @(
        @{ tool = 'Write'; input = @{ file_path = 'src/greeting.txt'; content = $work.greeting }; stdout = 'build-smoke-mission.ps1 wrote src/greeting.txt in the worktree' }
        @{ tool = 'Write'; input = @{ file_path = 'src/counter.ps1'; content = $work.counter }; stdout = 'build-smoke-mission.ps1 wrote src/counter.ps1 in the worktree' }
        @{ tool = 'Write'; input = @{ file_path = 'tests/test-smoke.ps1'; content = $work.test }; stdout = 'build-smoke-mission.ps1 wrote tests/test-smoke.ps1 in the worktree' }
        @{ tool = 'PowerShell'; input = @{ command = 'powershell -NoProfile -ExecutionPolicy Bypass -File tests/test-smoke.ps1' }; stdout = $suite.out }
        @{ tool = 'PowerShell'; input = @{ command = "git commit -m `"${Id}: greeting artifact, counter script and its test`"" }; stdout = $tip }
    )
    $null = Invoke-DispatchSession -Id $Id -Calls $calls
    return [pscustomobject]@{ wt = $wt; tip = $tip }
}

# --- D-1 -----------------------------------------------------------------------------------------
$base = $c0
$null = Put-Mission -Rel 'dot-mission\dispatches\D-1.yaml' -Values @{ BASE = $base }
$c1 = Commit-Main -Message 'dispatch D-1: the build' -Paths @('.mission/dispatches/D-1.yaml')
$d1 = Invoke-BuildDispatch -Id 'D-1' -Base $base
$null = Write-Anchors -Id 'D-1' -Kind 'build' -Base $base -Wt $d1.wt
Say "D-1         : dispatch $c1, worktree commit $($d1.tip)"

# --- D-1b, superseding D-1 -----------------------------------------------------------------------
$base = $c1
$p = @(
    (Put-Mission -Rel 'dot-mission\dispatches\D-1.handoff.yaml' -Values @{ COMMIT = $d1.tip }),
    (Put-Mission -Rel 'dot-mission\dispatches\D-1.supersession-marker.yaml' -Values @{ DATE = (Peek-Date) }),
    (Put-Mission -Rel 'dot-mission\dispatches\D-1b.yaml' -Values @{ BASE = $base })
)
$c2 = Commit-Main -Message 'D-1 handoff; D-1 superseded by D-1b (marker); dispatch D-1b' -Paths $p
$d1b = Invoke-BuildDispatch -Id 'D-1b' -Base $base
$null = Write-Anchors -Id 'D-1b' -Kind 'build' -Base $base -Wt $d1b.wt
Say "D-1b        : main $c2, worktree commit $($d1b.tip)"

# --- D-1c, superseding D-1b ----------------------------------------------------------------------
$base = $c2
$p = @(
    (Put-Mission -Rel 'dot-mission\dispatches\D-1b.handoff.yaml' -Values @{ COMMIT = $d1b.tip }),
    (Put-Mission -Rel 'dot-mission\dispatches\D-1b.supersession-marker.yaml' -Values @{ DATE = (Peek-Date) }),
    (Put-Mission -Rel 'dot-mission\dispatches\D-1c.yaml' -Values @{ BASE = $base })
)
$c3 = Commit-Main -Message 'D-1b handoff; D-1b superseded by D-1c (marker); dispatch D-1c' -Paths $p
$d1c = Invoke-BuildDispatch -Id 'D-1c' -Base $base
$null = Write-Anchors -Id 'D-1c' -Kind 'build' -Base $base -Wt $d1c.wt
$null = Invoke-Git -Dir $SmokeRoot -Argv @('merge', '--quiet', '--no-ff', '-m', "integrate D-1c's build onto main", 'worktree-wt-D-1c') -Date (Next-Date) -Check
$c4 = (Invoke-Git -Dir $SmokeRoot -Argv @('rev-parse', 'HEAD') -Check).out
Say "D-1c        : main $c3, worktree commit $($d1c.tip), integrated $c4"

# --- validation, attempt 1: judged against main at c4 ----------------------------------------------
function Test-Assertions {
    # The builder's own checks, against the tree at the mission root; A-5 against one dispatch's anchors.
    param([string]$AnchorsId)
    $g = Join-Path $SmokeRoot 'src\greeting.txt'
    $lines = @(([System.IO.File]::ReadAllText($g) -replace "`r`n", "`n").TrimEnd("`n") -split "`n")
    $ctr = Invoke-Counter -Dir $SmokeRoot
    $sui = Invoke-Suite -Dir $SmokeRoot
    $anc = [System.IO.File]::ReadAllText((Join-Path $SmokeRoot ".mission\dispatches\$AnchorsId.anchors.yaml"))
    $ancTip = if ($anc -match '(?m)^worktree_tip_sha:\s*([0-9a-f]{40})') { $Matches[1] } else { '' }
    $wtTip = (Invoke-Git -Dir (Join-Path $SmokeRoot ".claude\worktrees\wt-$AnchorsId") -Argv @('rev-parse', 'HEAD') -Check).out
    return [ordered]@{
        'A-1' = ($lines[0] -ceq 'hello from the smoke worker')
        'A-2' = (($ctr.exit -eq 0) -and ($ctr.out -ceq '3'))
        'A-3' = (($sui.exit -eq 0) -and ($sui.out -ceq 'PASS'))
        'A-4' = (($lines.Count -ge 2) -and ($lines[1] -ceq 'REWORKED'))
        'A-5' = (($ancTip -eq $wtTip) -and ($anc -match '(?m)^capture_gaps_count:\s*0\s*$'))
    }
}
$v1 = Test-Assertions -AnchorsId 'D-1c'
$want1 = [ordered]@{ 'A-1' = $true; 'A-2' = $true; 'A-3' = $true; 'A-4' = $false; 'A-5' = $true }
foreach ($k in $want1.Keys) { if ($v1[$k] -ne $want1[$k]) { Fail 'validation attempt 1' "$k came out $($v1[$k]), the record says $($want1[$k])" } }
$base = $c4
$p = @(
    (Put-Mission -Rel 'dot-mission\dispatches\D-1c.handoff.yaml' -Values @{ COMMIT = $d1c.tip }),
    (Put-Mission -Rel 'dot-mission\validator-results\isolation-probe.yaml' -Values @{ DATE = (Peek-Date) }),
    (Put-Mission -Rel 'dot-mission\validator-results\val-a-attempt-1.yaml' -Values @{ COMMIT = $c4 }),
    (Put-Mission -Rel 'dot-mission\validator-results\val-b-attempt-1.yaml' -Values @{ COMMIT = $c4 }),
    (Put-Mission -Rel 'dot-mission\dispatches\D-2.yaml' -Values @{ BASE = $base })
)
$c5 = Commit-Main -Message 'D-1c handoff; validation attempt 1 (A-4 fails, as planted); dispatch D-2, the rework' -Paths $p
Say "validation 1: judged $c4 -- A-1 A-2 A-3 A-5 pass, A-4 fails; main $c5"

# --- D-2, the rework ---------------------------------------------------------------------------------
$wt2 = New-DispatchWorktree -Id 'D-2' -Base $base
Write-LfFile -Path (Join-Path $wt2 'src\greeting.txt') -Text $work.reworked
$null = Invoke-Git -Dir $wt2 -Argv @('add', '--', 'src/greeting.txt') -Check
$null = Invoke-Git -Dir $wt2 -Argv @('commit', '--quiet', '-m', 'D-2 rework: satisfy A-4') -Date (Next-Date) -Check
$d2tip = (Invoke-Git -Dir $wt2 -Argv @('rev-parse', 'HEAD') -Check).out
$null = Invoke-DispatchSession -Id 'D-2' -Calls @(
    @{ tool = 'Edit'; input = @{ file_path = 'src/greeting.txt'; old_string = "hello from the smoke worker`n"; new_string = "hello from the smoke worker`nREWORKED`n" }; stdout = 'build-smoke-mission.ps1 appended the line REWORKED to src/greeting.txt in the worktree' }
    @{ tool = 'Read'; input = @{ file_path = 'src/greeting.txt' }; stdout = "hello from the smoke worker`nREWORKED" }
    @{ tool = 'PowerShell'; input = @{ command = 'git commit -m "D-2 rework: satisfy A-4"' }; stdout = $d2tip }
)
$null = Write-Anchors -Id 'D-2' -Kind 'rework' -Base $base -Wt $wt2
$null = Invoke-Git -Dir $SmokeRoot -Argv @('merge', '--quiet', '--no-ff', '-m', "integrate D-2's rework onto main", 'worktree-wt-D-2') -Date (Next-Date) -Check
$c6 = (Invoke-Git -Dir $SmokeRoot -Argv @('rev-parse', 'HEAD') -Check).out
Say "D-2         : worktree commit $d2tip, integrated $c6"

$v2 = Test-Assertions -AnchorsId 'D-2'
foreach ($k in $v2.Keys) { if (-not $v2[$k]) { Fail 'validation attempt 2' "$k came out False, the record says True" } }
$base = $c6
$p = @(
    (Put-Mission -Rel 'dot-mission\dispatches\D-2.handoff.yaml' -Values @{ COMMIT = $d2tip }),
    (Put-Mission -Rel 'dot-mission\validator-results\val-a-attempt-2.yaml' -Values @{ COMMIT = $c6 }),
    (Put-Mission -Rel 'dot-mission\validator-results\val-b-attempt-2.yaml' -Values @{ COMMIT = $c6 }),
    (Put-Mission -Rel 'dot-mission\dispatches\D-3.yaml' -Values @{ BASE = $base })
)
$c7 = Commit-Main -Message 'D-2 handoff; validation attempt 2 (all five pass); dispatch D-3, the close' -Paths $p
Say "validation 2: judged $c6 -- all five pass; main $c7"

# =================================================================================================
# GATES (composed by the real tool), THE DENIAL, THE PUSH, THE PUSH GATE, ITS REVOCATION
# =================================================================================================
function Invoke-GateCompose {
    # mission-gate.ps1 -ComposeOnly in a child whose USERNAME / COMPUTERNAME are neutral and which
    # carries no session marker. Returns the composed writes, binds_resolved made mission-relative.
    param([string[]]$Argv)
    $r = Invoke-WithEnv -Set @{ USERNAME = 'smoke-operator'; COMPUTERNAME = 'SMOKE-HOST' } -Clear $sessionVars -Body {
        $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $fw.gateTool @Argv -ComposeOnly 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $prevEap }
        [pscustomobject]@{ out = $o; exit = $code }
    }
    if ($r.exit -ne 0) { Fail ("gate compose " + ($Argv -join ' ')) ("exit $($r.exit) -- " + ($r.out -join ' | ')) }
    $writes = @()
    foreach ($line in $r.out) {
        if ($line -match '^LAMCOMPOSE write (\S+) (\d+) (\S+)$') {
            $name  = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Matches[1]))
            $bytes = [Convert]::FromBase64String($Matches[3])
            if ($bytes.Length -ne [int]$Matches[2]) { Fail 'gate compose' "the write for $name declares $($Matches[2]) bytes and carries $($bytes.Length)" }
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            $rootRx = [regex]::Escape($SmokeRoot.TrimEnd('\') + '\')
            $text = [regex]::Replace($text, '(?m)^binds_resolved:[ \t]*' + $rootRx + '(?<rel>[^\r\n]*)(?<eol>\r?)$', {
                param($m) "# binds_resolved is written relative to the mission root by build-smoke-mission.ps1; mission-gate.ps1 composed it absolute.$($m.Groups['eol'].Value)`nbinds_resolved: $($m.Groups['rel'].Value)$($m.Groups['eol'].Value)" }, 'IgnoreCase')
            if ($text -match ([regex]::Escape($SmokeRoot))) { Fail 'gate compose' "the composed $name still names the mission root's absolute path" }
            # SAID ON THE ARTIFACT, ABOVE THE TOOL'S OWN HEADER: no human minted it. (A revocation is
            # composed over the file already on disk, which carries this line.)
            $built = '# BUILT, NOT MINTED: composed by mission-gate.ps1 -ComposeOnly for build-smoke-mission.ps1 and written by it; no operator confirmed this gate.'
            if (-not $text.StartsWith($built)) { $text = $built + $(if ($text -match '\r\n') { "`r`n" } else { "`n" }) + $text }
            $writes += [pscustomobject]@{ name = $name; bytes = $utf8.GetBytes($text) }
        }
    }
    if ($writes.Count -ne 1) { Fail 'gate compose' "expected one composed write, found $($writes.Count)" }
    return $writes[0]
}
$gatesDir = Join-Path $SmokeRoot '.mission\gates'
$null = New-Item -ItemType Directory -Path $gatesDir -Force
foreach ($sid in @('D-1', 'D-1b')) {
    $w = Invoke-GateCompose -Argv @('approve', '-Kind', 'supersession', '-Id', $sid, '-Binds', ".mission\dispatches\$sid.superseded.yaml",
                                    '-MissionRoot', $SmokeRoot, '-ConsoleCredential', 'injected-seam')
    [System.IO.File]::WriteAllBytes((Join-Path $gatesDir $w.name), $w.bytes)
    Say "gate        : $($w.name) (supersession, binds .mission\dispatches\$sid.superseded.yaml)"
}

# The builder's own session: one push attempted before any push gate exists, which the guard denies
# and records, then finalised against a transcript that carries the same denied call.
$deny = Invoke-Hook -Script $fw.guard -Stdin (ConvertTo-JsonLine @{ session_id = $builderSession; hook_event_name = 'PreToolUse'; tool_name = 'PowerShell'; tool_input = @{ command = 'git push origin main' } }) -Env @{ CLAUDE_PROJECT_DIR = $SmokeRoot }
$denyLog = Join-Path $SmokeRoot ".mission-runtime\evidence\session-$builderSession\log.jsonl"
if ($deny.exit -ne 2 -or -not (Test-Path -LiteralPath $denyLog) -or ([System.IO.File]::ReadAllText($denyLog) -notmatch '"tool":\s*"_denied"')) {
    Fail 'denial' "the guard did not deny and record the push: exit $($deny.exit) -- $($deny.out)"
}
$denyReason = (([System.IO.File]::ReadAllLines($denyLog) | Select-Object -Last 1) | ConvertFrom-Json).reason
$transcript = Join-Path $SmokeRoot ".mission-runtime\transcripts\$builderSession.jsonl"
Write-LfFile -Path $transcript -Text ((@(
    (ConvertTo-JsonLine @{ type = 'assistant'; sessionId = $builderSession; message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; id = 'toolu_smoke_builder_push'; name = 'PowerShell'; input = @{ command = 'git push origin main' } }) } }),
    (ConvertTo-JsonLine @{ type = 'user'; sessionId = $builderSession; message = @{ role = 'user'; content = @(@{ type = 'tool_result'; tool_use_id = 'toolu_smoke_builder_push'; is_error = $true; content = $denyReason }) } })
) -join "`n") + "`n")
$stop = Invoke-Hook -Script $fw.stop -Stdin (ConvertTo-JsonLine @{ session_id = $builderSession; hook_event_name = 'Stop'; stop_hook_active = $false; transcript_path = $transcript }) -Env @{ CLAUDE_PROJECT_DIR = $SmokeRoot }
$bsc = Join-Path $SmokeRoot ".mission-runtime\evidence\session-$builderSession\capture-gaps.yaml"
if ($stop.exit -ne 0 -or -not (Test-Path -LiteralPath $bsc) -or ([System.IO.File]::ReadAllText($bsc) -notmatch '(?m)^capture_gaps:\s*\[\]\s*$')) {
    Fail 'builder session' "the stop finaliser did not finalise the builder's session with an empty sidecar: exit $($stop.exit) -- $($stop.out)"
}
Say "denial      : the guard denied 'git push origin main' with no push gate (exit 2), recorded in session-$builderSession, finalised"

# The push: the decider is not installed yet, and the hooks path is pinned to the empty hooks folder.
# The push writes reflog entries (the remote-tracking ref here, the branch in the origin): their committer date is
# pinned the same way, without advancing the fixed clock.
$null = Invoke-Git -Dir $SmokeRoot -Argv @('push', '--quiet', 'origin', 'main') -Date (Peek-Date) -Check
$originTip = ''
foreach ($l in @((Invoke-Git -Dir $SmokeRoot -Argv @('ls-remote', 'origin', 'refs/heads/main') -Check).out -split "`n")) {
    if ($l -match '^([0-9a-f]{40})\s+refs/heads/main$') { $originTip = $Matches[1] }
}
if ($originTip -ne $c7) { Fail 'push' "the origin holds '$originTip' at refs/heads/main, not $c7" }
Say "push        : origin refs/heads/main = $originTip"

# The push gate, minted AFTER the push and bound to the tip the origin holds, then revoked.
$w = Invoke-GateCompose -Argv @('approve', '-Kind', 'push', '-Id', 'smoke-1', '-Binds', "..\$leaf\.mission\dispatches\D-2.anchors.yaml",
                                '-MissionRoot', $SmokeRoot, '-TipSha', $originTip, '-OriginUrl', $originUrl,
                                '-RemoteRef', 'refs/heads/main', '-ConsoleCredential', 'injected-seam')
$pushGate = Join-Path $gatesDir $w.name
[System.IO.File]::WriteAllBytes($pushGate, $w.bytes)
$w = Invoke-GateCompose -Argv @('revoke', '-Kind', 'push', '-Id', 'smoke-1', '-MissionRoot', $SmokeRoot,
                                '-Reason', 'the push it authorized has landed; no standing capability remains')
if ((Join-Path $gatesDir $w.name) -ne $pushGate) { Fail 'revoke' "the revocation composed $($w.name), not $(Split-Path -Leaf $pushGate)" }
[System.IO.File]::WriteAllBytes($pushGate, $w.bytes)
Say "gate        : $(Split-Path -Leaf $pushGate) (push, authorized_tip_sha $originTip, binds ..\$leaf\.mission\dispatches\D-2.anchors.yaml), then revoked"

# The pre-push decider, for this checkout's decider, written by the guard library in a child.
$null = New-Item -ItemType Directory -Path (Join-Path $SmokeRoot '.git\hooks') -Force
$installer = Join-Path $SmokeRoot '.mission-runtime\builder\install-decider.ps1'
Write-LfFile -Path $installer -Text "param([string]`$Library, [string]`$Decider, [string]`$Hook)`n`$ErrorActionPreference = 'Stop'`n. `$Library`n[System.IO.File]::WriteAllText(`$Hook, (Get-EvidencePrePushWrapperText -DeciderPath `$Decider), (New-Object System.Text.UTF8Encoding(`$false)))`nexit 0`n"
$r = Invoke-WithEnv -Set @{} -Clear $sessionVars -Body {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Library $fw.hookLib -Decider $fw.decider -Hook (Join-Path $SmokeRoot '.git\hooks\pre-push') 2>&1
        $i = $LASTEXITCODE
        $co = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $fw.checker -RepoRoot $SmokeRoot 2>&1 | ForEach-Object { "$_" })
        [pscustomobject]@{ install = $i; check = $LASTEXITCODE; out = ($co -join ' ') }
    } finally { $ErrorActionPreference = $prevEap }
}
if ($r.install -ne 0 -or $r.check -ne 0) { Fail 'decider' "install exit $($r.install), checker exit $($r.check) -- $($r.out)" }
Remove-Item -LiteralPath (Split-Path -Parent $installer) -Recurse -Force
Say "decider     : installed for $($fw.decider); check-prepush-installed exit 0"

# =================================================================================================
# AFTER THE PUSH: the anchors, the close ceremony, D-3's record
# =================================================================================================
$c8 = Commit-Main -Message 'anchors for D-1, D-1b, D-1c and D-2' -Paths @('.mission/dispatches/D-1.anchors.yaml', '.mission/dispatches/D-1b.anchors.yaml', '.mission/dispatches/D-1c.anchors.yaml', '.mission/dispatches/D-2.anchors.yaml')
$wt3 = New-DispatchWorktree -Id 'D-3' -Base $c6
$null = New-Item -ItemType Directory -Path (Join-Path $SmokeRoot '.mission\ledger') -Force
$cerCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File tools\mission-ceremony-record.ps1 -CeremonyId $ceremonyId -Author build-smoke-mission.ps1"
$cer = Invoke-WithEnv -Set @{ GIT_AUTHOR_DATE = (Next-Date); GIT_COMMITTER_DATE = $null } -Clear $sessionVars -Body {
    $env:GIT_COMMITTER_DATE = $env:GIT_AUTHOR_DATE
    Push-Location -LiteralPath $SmokeRoot
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SmokeRoot 'tools\mission-ceremony-record.ps1') -CeremonyId $ceremonyId -Author 'build-smoke-mission.ps1' 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prevEap; Pop-Location }
    [pscustomobject]@{ out = ($o -join "`n"); exit = $code }
}
if ($cer.exit -ne 0) { Fail 'ceremony' "exit $($cer.exit) -- $($cer.out)" }
$c9 = (Invoke-Git -Dir $SmokeRoot -Argv @('rev-parse', 'HEAD') -Check).out
if ((Invoke-Git -Dir $SmokeRoot -Argv @('log', '-1', '--format=%s') -Check).out -ne "ceremony: $ceremonyId") { Fail 'ceremony' 'HEAD is not the ceremony commit' }
# The commit message mission-lib wrote to a scratch file for `git commit -F` is not evidence; its name is
# a random hex token. It is removed once the commit carries the message.
Get-ChildItem -LiteralPath (Join-Path $SmokeRoot '.mission-runtime') -File -Filter 'commit-msg-*.txt' | Remove-Item -Force
$null = Invoke-DispatchSession -Id 'D-3' -Calls @(
    @{ tool = 'PowerShell'; input = @{ command = $cerCmd }; stdout = $cer.out }
    @{ tool = 'PowerShell'; input = @{ command = 'git log -1 --format=%H' }; stdout = $c9 }
)
$p = @((Put-Mission -Rel 'dot-mission\dispatches\D-3.handoff.yaml' -Values @{ COMMIT = $c9 }), (Write-Anchors -Id 'D-3' -Kind 'close' -Base $c6 -Wt $wt3))
$c10 = Commit-Main -Message 'D-3 handoff and anchors: the close ceremony' -Paths $p
Say "ceremony    : $ceremonyId, commit $c9; D-3 record $c10"

# =================================================================================================
# THE BUILDER-DIAGNOSTIC REGISTER LINE AND ITS DISCLOSURE
# =================================================================================================
$r = Invoke-Hook -Script $fw.prompt -Stdin (ConvertTo-JsonLine @{ session_id = $builderSession; hook_event_name = 'UserPromptSubmit'; prompt = $diagPrompt }) -Env @{ CLAUDE_PROJECT_DIR = $SmokeRoot }
$reg = Join-Path $SmokeRoot '.mission-runtime\operator-prompts.log'
$regLine = @(if (Test-Path -LiteralPath $reg) { [System.IO.File]::ReadAllLines($reg) | Where-Object { $_ -match "kind=operator session=$builderSession" } })
if ($r.exit -ne 0 -or $regLine.Count -ne 1) { Fail 'register' "the root register does not carry exactly one builder-diagnostic line: exit $($r.exit) -- $($r.out)" }
$bytes = if ($regLine[0] -match 'prompt_bytes=(\d+)') { $Matches[1] } else { '?' }
Write-LfFile -Path (Join-Path $SmokeRoot '.mission-runtime\disclosures\builder-diagnostic-prompt.md') -Text (Expand-Template -Text (Get-Template -Rel 'builder-diagnostic-prompt.md') -Values @{ SESSION = $builderSession; BYTES = $bytes; PROMPT = $diagPrompt })
Say "register    : one builder-diagnostic line (session $builderSession, $bytes bytes), disclosed in .mission-runtime\disclosures\builder-diagnostic-prompt.md"

# =================================================================================================
# THE BUILT MISSION, CHECKED
# =================================================================================================
$cc = Invoke-WithEnv -Set @{} -Clear $sessionVars -Body {
    Push-Location -LiteralPath $SmokeRoot
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SmokeRoot 'tools\mission-ceremony-record.ps1') -CeremonyId 'build-check' -CheckOnly 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prevEap; Pop-Location }
    [pscustomobject]@{ out = ($o -join "`n"); exit = $code }
}
if ($cc.exit -ne 0 -or $cc.out -notmatch 'Assert-CleanGitTree passed' -or $cc.out -notmatch 'Working tree clean') { Fail 'final check' "the ceremony's -CheckOnly did not pass both gates: exit $($cc.exit) -- $($cc.out)" }
$porc = @((Invoke-Git -Dir $SmokeRoot -Argv @('status', '--porcelain=v1') -Check).out -split "`n" | Where-Object { $_ })
$admitted = @('?? .mission/evidence/', '?? .claude/worktrees/', '?? .mission/gates/')
$stray = @($porc | Where-Object { $admitted -notcontains $_ })
if ($stray.Count -gt 0) { Fail 'final check' ("porcelain outside the admitted set: " + ($stray -join ' ; ')) }
$caps = @(Get-ChildItem -LiteralPath (Join-Path $SmokeRoot '.mission-runtime\evidence') -Recurse -File -Filter 'capture-gaps.yaml')
$mfs  = @(Get-ChildItem -LiteralPath (Join-Path $SmokeRoot '.mission-runtime\evidence') -Recurse -File -Filter 'manifest.json')
$badCap = @($caps | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -notmatch '(?m)^capture_gaps:\s*\[\]\s*$' })
$badMf  = @($mfs | Where-Object { [System.IO.File]::ReadAllText($_.FullName) -notmatch '"state":\s*"finalized"' })
if ($badCap.Count -or $badMf.Count) { Fail 'final check' "$($badCap.Count) non-empty sidecar(s), $($badMf.Count) unfinalised manifest(s)" }
$anc = (Invoke-Git -Dir $SmokeRoot -Argv @('merge-base', '--is-ancestor', $originTip, 'HEAD')).exit
if ($anc -ne 0) { Fail 'final check' "HEAD does not descend from the origin tip $originTip" }

Say ""
Say "BUILT: $SmokeRoot"
Say "  pushed history (origin refs/heads/main), fixed content, identity and dates:"
Say "    c0 $c0   scaffold"
Say "    c1 $c1   dispatch D-1"
Say "    c2 $c2   D-1 handoff, marker, D-1b"
Say "    c3 $c3   D-1b handoff, marker, D-1c"
Say "    c4 $c4   integrate D-1c"
Say "    c5 $c5   D-1c handoff, validation 1, D-2"
Say "    c6 $c6   integrate D-2"
Say "    c7 $c7   D-2 handoff, validation 2, D-3   <- origin"
Say "    worktree commits: D-1 $($d1.tip)  D-1b $($d1b.tip)  D-1c $($d1c.tip)  D-2 $d2tip"
Say "  after the push (carry measured digests and the ledger timestamp):"
Say "    c8 $c8   anchors D-1..D-2"
Say "    c9 $c9   ceremony: $ceremonyId"
Say "    c10 $c10  D-3 handoff and anchors   <- HEAD"
Say "  gates: supersession-D-1, supersession-D-1b, push-smoke-1 (revoked); evidence sessions: $($mfs.Count) finalised, $($caps.Count) empty sidecar(s)"
Say "  porcelain: $($porc -join ' ; ')"
Say "  WP-6 reads it as the DEFAULT when it is the sibling of the primary checkout; elsewhere hand it over with -SmokeRoot or LAM_SMOKE_ROOT."
Say "EXIT: 0"
exit 0
