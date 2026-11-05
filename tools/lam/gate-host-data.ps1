#Requires -Version 5.1
<#
.SYNOPSIS
  The zero-host-data gate (UI-1 S4, ruling F2): read a release tree and/or an expanded release ZIP for data of the
  host project the framework was extracted from -- HARD classes that must read zero, SOFT classes that are listed and
  never block -- and write a report naming every hit by path:line and class.

.DESCRIPTION
  READ ONLY. Nothing under -Root, -Zip, -HostRepo or -FrameworkRepo is written; git is asked read-only questions
  (ls-files, rev-parse, cat-file --batch-check, log --raw, show, remote get-url) with its redirecting variables
  cleared. The only file written is the report, which may not lie inside -Root or -Zip.

  WHAT IS READ. -Root, a tree: a git checkout's tracked files (git ls-files), read from disk, or every file under a
  folder git does not hold; -Zip, an expanded release ZIP's root: every file under it. Either or both. A file holding a
  0x00 byte is read as ISO-8859-1 for the name and path classes only; any other file as UTF-8.

  NO HOST WORD IS WRITTEN IN THIS FILE. The host's names reach the gate from three places, each at run time:
    -PatternFile  the operator's HARD pattern file: one literal per line ('#' comments and blank lines skipped),
                  matched case-insensitively anywhere in a line. It is given by parameter and never tracked.
    -HostRepo     a host repository, read only: its folder's name and its parent folder (an organisation folder),
                  <name>-worktrees beside it, and its origin remote's owner and repository names.
    this host     $env:USERNAME and $env:COMPUTERNAME (four characters or more) and the profile path $env:USERPROFILE.

  HARD (exit 0 only when every HARD class reads zero):
    H1 host-name    a pattern-file literal, or a name derived above.
    H2 host-path    the profile path, -HostRepo's path or its parent folder, written with \, \\ or / separators or in
                    the /c/... form; the origin remote's host and owner (github.com/<owner>) or <owner>/<repository>.
    H3 host-id      a 7-40-character hex token -- at least one digit; not part of a UUID; not a prefix of a 64-hex
                    digest that stands anywhere in the files read; not a PowerShell variable; not inside a <...>
                    placeholder -- that -HostRepo resolves (an object or a commit) and the framework's own history does
                    not. Without -HostRepo this class is not evaluated, and the report says so.
    H4 pinned-host-copy  a file under tests/lam/fixtures/base-*/ that is none of: synthetic by name
                    (instrument-sample-suite.ps1.base, SAMPLE-GOAL.yaml, HALT-SAMPLE-*); synthetic by recipe (its path
                    a target of tests/lam/fixtures/synthetic-bases.json, its sha256 the recipe's, and the recipe,
                    rebuilt from the framework's own blob at the recipe's source commit, giving its bytes); or
                    framework-held (a <path>.base whose git blob id the framework's history recorded at <path>).
    H5 provenance-cites-host  an H1, H2 or H3 hit in a file under provenance/ -- also counted under its own class.

  SOFT (listed, never blocking):
    B3-FIXTURE-BASE / B3-TESTS / B3-OTHER  a bare row, AM, ARC, HALT, ledger or gate number (and R-n on a line naming a
                    ruling): inside the pinned bytes of tests/lam/fixtures/base-*/; elsewhere under tests/ (instrument
                    data and the tool output the members compare with a base); anywhere else.
    FIXTURE-ID / HEX-UNRESOLVED  a hex token as H3 reads it that neither repository resolves (or, without -HostRepo,
                    that the framework's history does not): under tests/ (an id an instrument or fixture made);
                    elsewhere.
    UUID            a UUID, listed for review (never a git id).

  THE FRAMEWORK'S OWN HISTORY: -FrameworkRepo; by default -Root when it is a git checkout's top level, else the checkout
  this file sits in. H3 and H4 need it: where none can be read, the gate reports both classes not evaluated and exits 3.

.PARAMETER Root
  A tree to read: a git checkout (its tracked files) or a folder.
.PARAMETER Zip
  An expanded release ZIP's root.
.PARAMETER PatternFile
  The operator's HARD pattern file.
.PARAMETER HostRepo
  A host repository, read only.
.PARAMETER FrameworkRepo
  The framework's own repository (its history), read only.
.PARAMETER Report
  The report file; by default gate-host-data-<UTC stamp>.txt in the temporary folder.

.NOTES
  EXIT: 0 HARD reads zero; 1 HARD reads more than zero; 2 a parameter could not be used; 3 the framework's history
  could not be read, so H3 and H4 were not evaluated.
#>
[CmdletBinding()]
param(
    [string]$Root,
    [string]$Zip,
    [Parameter(Mandatory = $true)][string]$PatternFile,
    [string]$HostRepo,
    [string]$FrameworkRepo,
    [string]$Report
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:Latin1    = [System.Text.Encoding]::GetEncoding(28591)
$script:GitRedirects = @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY',
    'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_NAMESPACE', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG_COUNT')
foreach ($v in $script:GitRedirects) { [System.Environment]::SetEnvironmentVariable($v, $null, 'Process') }

function Say { param([string]$Text) [Console]::Out.WriteLine('gate-host-data: ' + $Text) }
function Stop-Gate { param([int]$Code, [string]$Text) Say $Text; exit $Code }

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { $d = $h.ComputeHash($Bytes) } finally { $h.Dispose() }
    return ([System.BitConverter]::ToString($d)).Replace('-', '').ToLowerInvariant()
}

function Get-BlobId {
    # git's id for these bytes as a blob: sha1("blob <length>\0" + bytes).
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $pre = [System.Text.Encoding]::ASCII.GetBytes('blob ' + $Bytes.Length + [char]0)
        $null = $sha1.TransformBlock($pre, 0, $pre.Length, $null, 0)
        $null = $sha1.TransformFinalBlock($Bytes, 0, $Bytes.Length)
        return ([System.BitConverter]::ToString($sha1.Hash)).Replace('-', '').ToLowerInvariant()
    } finally { $sha1.Dispose() }
}

function Invoke-GitLines {
    # One read-only git call; stdout as lines. Stdin, when given, is piped as ASCII lines ($OutputEncoding of 5.1),
    # so no byte-order mark reaches git.
    param([Parameter(Mandatory = $true)][string]$Repo, [Parameter(Mandatory = $true)][string[]]$GitArgs, [string[]]$Stdin)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($null -ne $Stdin) { $out = @($Stdin | & git -C $Repo @GitArgs 2>$null) } else { $out = @(& git -C $Repo @GitArgs 2>$null) }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ ok = ($code -eq 0); code = $code; lines = @($out | ForEach-Object { [string]$_ }) }
}

function Invoke-GitBytes {
    # git show <rev>:<path>, stdout read as BYTES (no stdin opened).
    param([Parameter(Mandatory = $true)][string]$Repo, [Parameter(Mandatory = $true)][string]$Spec)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = '-C "' + $Repo + '" show "' + $Spec + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    try {
        $errTask = $proc.StandardError.ReadToEndAsync()
        $proc.StandardOutput.BaseStream.CopyTo($ms)
        $proc.WaitForExit()
        $null = $errTask.Result
        $code = $proc.ExitCode
    } finally { $proc.Dispose() }
    if ($code -ne 0) { return $null }
    return , $ms.ToArray()
}

function Test-GitTop {
    # Whether Dir is the top level of a git work tree.
    param([string]$Dir)
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    $g = Invoke-GitLines -Repo $Dir -GitArgs @('rev-parse', '--is-inside-work-tree', '--show-prefix')
    return ($g.ok -and $g.lines.Count -ge 1 -and $g.lines[0] -eq 'true' -and ($g.lines.Count -lt 2 -or -not $g.lines[1]))
}

function ConvertTo-PathPattern {
    # A path written with \, \\ or / between its segments (and, for a drive path, the /c/... form), case-insensitive,
    # not followed by another name character.
    param([Parameter(Mandatory = $true)][string]$Path)
    $segs = @($Path.TrimEnd('\', '/') -split '[\\/]+' | Where-Object { $_ })
    if ($segs.Count -eq 0) { return $null }
    $sep = '(?:\\\\|\\|/)+'
    $tail = '(?![A-Za-z0-9_])'
    $alts = @((($segs | ForEach-Object { [regex]::Escape($_) }) -join $sep) + $tail)
    if ($segs[0] -match '^([A-Za-z]):$') {
        $alts += '/' + $Matches[1].ToLowerInvariant() + '/' + ((@($segs | Select-Object -Skip 1) | ForEach-Object { [regex]::Escape($_) }) -join '/+') + $tail
    }
    return '(?:' + ($alts -join '|') + ')'
}

# ------------------------------------------------------------------------------------------------
# PARAMETERS
# ------------------------------------------------------------------------------------------------
if (-not $Root -and -not $Zip) { Stop-Gate 2 'name a tree with -Root, an expanded ZIP with -Zip, or both.' }
$scopes = New-Object System.Collections.Generic.List[object]
foreach ($pair in @(@('ROOT', $Root), @('ZIP', $Zip))) {
    if (-not $pair[1]) { continue }
    if (-not (Test-Path -LiteralPath $pair[1] -PathType Container)) { Stop-Gate 2 "-$($pair[0].Substring(0,1))$($pair[0].Substring(1).ToLowerInvariant()) is not a folder: $($pair[1])" }
    $scopes.Add([pscustomobject]@{ label = $pair[0]; dir = (Resolve-Path -LiteralPath $pair[1]).Path.TrimEnd('\') })
}
if (-not (Test-Path -LiteralPath $PatternFile -PathType Leaf)) { Stop-Gate 2 "-PatternFile is not a file: $PatternFile" }
if ($HostRepo -and -not (Test-GitTop $HostRepo)) { Stop-Gate 2 "-HostRepo is not the top level of a git work tree: $HostRepo" }
if ($HostRepo) { $HostRepo = (Resolve-Path -LiteralPath $HostRepo).Path.TrimEnd('\') }
if (-not $Report) { $Report = Join-Path ([System.IO.Path]::GetTempPath()) ('gate-host-data-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss', [System.Globalization.CultureInfo]::InvariantCulture) + '.txt') }
$Report = [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Report))
foreach ($s in $scopes) {
    if ($Report.StartsWith($s.dir + '\', [System.StringComparison]::OrdinalIgnoreCase)) { Stop-Gate 2 "the report may not lie inside the $($s.label) scope: $Report" }
}
if (-not $FrameworkRepo) {
    $rootScope = @($scopes | Where-Object { $_.label -eq 'ROOT' })
    if ($rootScope.Count -and (Test-GitTop $rootScope[0].dir)) { $FrameworkRepo = $rootScope[0].dir }
    elseif (Test-GitTop (Join-Path $PSScriptRoot '..\..')) { $FrameworkRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
}
$fwOk = [bool]($FrameworkRepo -and (Test-GitTop $FrameworkRepo))

# ------------------------------------------------------------------------------------------------
# THE NAMES AND PATHS, from the pattern file, the host repository and this host
# ------------------------------------------------------------------------------------------------
$names = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
$patternCount = 0
foreach ($line in [System.IO.File]::ReadAllLines($PatternFile)) {
    $w = $line.Trim()
    if (-not $w -or $w.StartsWith('#')) { continue }
    $patternCount++
    if (-not $names.ContainsKey($w)) { $names[$w] = 'pattern-file' }
}
if ($patternCount -eq 0) { Stop-Gate 2 "-PatternFile holds no literal: $PatternFile" }
foreach ($kv in @(@('USERNAME', $env:USERNAME), @('COMPUTERNAME', $env:COMPUTERNAME))) {
    if ($kv[1] -and $kv[1].Length -ge 4 -and -not $names.ContainsKey($kv[1])) { $names[$kv[1]] = 'this host ' + $kv[0] }
}
$pathRx = New-Object System.Collections.Generic.List[object]
if ($env:USERPROFILE) { $pathRx.Add([pscustomobject]@{ kind = 'profile-path'; rx = (ConvertTo-PathPattern $env:USERPROFILE) }) }
$hostNote = 'no -HostRepo'
if ($HostRepo) {
    $leaf = Split-Path -Leaf $HostRepo
    $parent = Split-Path -Parent $HostRepo
    if ($leaf.Length -ge 3 -and -not $names.ContainsKey($leaf)) { $names[$leaf] = 'host repository folder' }
    $pathRx.Add([pscustomobject]@{ kind = 'host-repo-path'; rx = (ConvertTo-PathPattern $HostRepo) })
    if ($parent -and $parent.Length -gt 3) { $pathRx.Add([pscustomobject]@{ kind = 'host-org-path'; rx = (ConvertTo-PathPattern $parent) }) }
    $pathRx.Add([pscustomobject]@{ kind = 'host-worktrees'; rx = ('(?<![A-Za-z0-9_])' + [regex]::Escape($leaf + '-worktrees')) })
    $url = Invoke-GitLines -Repo $HostRepo -GitArgs @('remote', 'get-url', 'origin')
    $hostNote = "host repository $HostRepo; origin remote $(if ($url.ok -and $url.lines.Count) { 'read' } else { 'none' })"
    if ($url.ok -and $url.lines.Count -and $url.lines[0] -match '^(?:[a-z+]+://)?(?:[^@/]+@)?([^/:]+)[:/]+([^/]+)/([^/]+?)(?:\.git)?/?$') {
        $rHost = $Matches[1]; $owner = $Matches[2]; $repoName = $Matches[3]
        foreach ($n in @($owner, $repoName)) { if ($n.Length -ge 3 -and -not $names.ContainsKey($n)) { $names[$n] = 'host origin remote' } }
        $pathRx.Add([pscustomobject]@{ kind = 'host-repo-url'; rx = ([regex]::Escape($rHost) + '[:/]+' + [regex]::Escape($owner) + '(?![A-Za-z0-9_-])') })
        $pathRx.Add([pscustomobject]@{ kind = 'host-repo-name'; rx = ([regex]::Escape($owner) + '/' + [regex]::Escape($repoName) + '(?![A-Za-z0-9_-])') })
    }
}
$opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$nameKeys = [string[]]@($names.Keys)
[System.Array]::Sort($nameKeys, [System.Collections.Generic.Comparer[string]]::Create([System.Comparison[string]]{ param($a, $b) $b.Length.CompareTo($a.Length) }))
$nameRegex = New-Object System.Text.RegularExpressions.Regex ('(?:' + (($nameKeys | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'), $opts
foreach ($p in $pathRx) { $p.rx = New-Object System.Text.RegularExpressions.Regex $p.rx, $opts }

$hexRx   = New-Object System.Text.RegularExpressions.Regex '\b[0-9a-fA-F]{7,40}\b'
$h64Rx   = New-Object System.Text.RegularExpressions.Regex '\b[0-9a-fA-F]{64}\b'
$uuidRx  = New-Object System.Text.RegularExpressions.Regex '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'
$placeRx = New-Object System.Text.RegularExpressions.Regex '<(?!!--)[^<>\r\n]{1,60}>'
$b3 = [ordered]@{
    'ledger' = '\bledger\s+1\d{3}'
    'row'    = '\brow\s+\d{3}\b'
    'AM'     = '\bAM-\d+\b'
    'ARC'    = '\bARC-[A-Z0-9]+(?:-\d+)?\b'
    'HALT'   = '\bHALT-\d+\b'
    'gate'   = 'push-batch-[0-9a-f]{8}|completion-acceptance-round-\d+|push-lam-closure-[0-9a-f]+|supersession-D-\w+'
}
$b3Rx = @{}
foreach ($k in $b3.Keys) { $b3Rx[$k] = New-Object System.Text.RegularExpressions.Regex $b3[$k], $opts }
$rRx = New-Object System.Text.RegularExpressions.Regex '\bR-\d+\b'
$rulingRx = New-Object System.Text.RegularExpressions.Regex '\brulings?\b', $opts

# ------------------------------------------------------------------------------------------------
# THE FILES
# ------------------------------------------------------------------------------------------------
$files = New-Object System.Collections.Generic.List[object]
foreach ($s in $scopes) {
    $rels = @()
    if ($s.label -eq 'ROOT' -and (Test-GitTop $s.dir)) {
        $ls = Invoke-GitLines -Repo $s.dir -GitArgs @('-c', 'core.quotePath=false', 'ls-files')
        if (-not $ls.ok) { Stop-Gate 2 "git ls-files failed in $($s.dir)" }
        $rels = @($ls.lines | Where-Object { $_ })
        $s | Add-Member -NotePropertyName how -NotePropertyValue 'tracked files (git ls-files), read from disk'
    } else {
        $rels = @(Get-ChildItem -LiteralPath $s.dir -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git(\\|$)' } | ForEach-Object { $_.FullName.Substring($s.dir.Length + 1).Replace('\', '/') })
        $s | Add-Member -NotePropertyName how -NotePropertyValue 'every file under the folder'
    }
    $s | Add-Member -NotePropertyName count -NotePropertyValue $rels.Count
    foreach ($rel in $rels) {
        $full = Join-Path $s.dir ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $bin = ([System.Array]::IndexOf($bytes, [byte]0) -ge 0)
        $text = if ($bin) { $script:Latin1.GetString($bytes) } else { $script:Utf8NoBom.GetString($bytes) }
        $starts = New-Object System.Collections.Generic.List[int]
        $starts.Add(0)
        $i = $text.IndexOf([char]10)
        while ($i -ge 0) { $starts.Add($i + 1); $i = $text.IndexOf([char]10, $i + 1) }
        $files.Add([pscustomobject]@{ scope = $s.label; rel = $rel; bytes = $bytes; bin = $bin; text = $text; starts = $starts.ToArray() })
    }
}

function Get-LineNo { param($F, [int]$Index)
    $k = [System.Array]::BinarySearch($F.starts, $Index)
    if ($k -lt 0) { $k = (-bnot $k) - 1 }
    return $k + 1
}
function Get-LineText { param($F, [int]$LineNo)
    $a = $F.starts[$LineNo - 1]
    $b = if ($LineNo -lt $F.starts.Count) { $F.starts[$LineNo] - 1 } else { $F.text.Length }
    return $F.text.Substring($a, [Math]::Max(0, $b - $a)).TrimEnd([char]13)
}

$hard = New-Object System.Collections.Generic.List[object]
$soft = New-Object System.Collections.Generic.List[object]
function Add-Hit { param($List, [string]$Class, $F, [int]$Line, [string]$Token, [string]$Note)
    $List.Add([pscustomobject]@{ class = $Class; scope = $F.scope; path = $F.rel; line = $Line; token = $Token; note = $Note })
}

# ------------------------------------------------------------------------------------------------
# H1, H2: names and paths (every file, binary ones as ISO-8859-1)
# ------------------------------------------------------------------------------------------------
foreach ($f in $files) {
    foreach ($m in $nameRegex.Matches($f.text)) { Add-Hit $hard 'H1 host-name' $f (Get-LineNo $f $m.Index) $m.Value $names[$m.Value] }
    foreach ($p in $pathRx) { foreach ($m in $p.rx.Matches($f.text)) { Add-Hit $hard ('H2 host-path:' + $p.kind) $f (Get-LineNo $f $m.Index) $m.Value '' } }
}

# ------------------------------------------------------------------------------------------------
# H3 and the hex SOFT classes: every candidate token, resolved once per repository
# ------------------------------------------------------------------------------------------------
$prefixes = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($f in $files) {
    if ($f.bin) { continue }
    foreach ($m in $h64Rx.Matches($f.text)) { $h = $m.Value.ToLowerInvariant(); for ($k = 7; $k -le 40; $k++) { $null = $prefixes.Add($h.Substring(0, $k)) } }
}
$pending = New-Object System.Collections.Generic.List[object]
$digestPrefixes = 0
foreach ($f in $files) {
    if ($f.bin) { continue }
    $uspans = @($uuidRx.Matches($f.text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    foreach ($u in $uuidRx.Matches($f.text)) { Add-Hit $soft 'UUID' $f (Get-LineNo $f $u.Index) $u.Value 'listed for review (not a git id)' }
    $pspans = @($placeRx.Matches($f.text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    foreach ($m in $hexRx.Matches($f.text)) {
        $tok = $m.Value; $s = $m.Index
        if (-not ($tok -match '[0-9]')) { continue }
        if ($s -gt 0 -and $f.text[$s - 1] -eq '$' -and $tok -match '^[A-Za-z_]') { continue }
        $inU = $false; foreach ($sp in $uspans) { if ($s -ge $sp[0] -and $s -lt $sp[1]) { $inU = $true; break } }
        if ($inU) { continue }
        $inP = $false; foreach ($sp in $pspans) { if ($s -gt $sp[0] -and $s -lt $sp[1]) { $inP = $true; break } }
        if ($inP) { continue }
        if ($prefixes.Contains($tok.ToLowerInvariant())) { $digestPrefixes++; continue }
        $pending.Add([pscustomobject]@{ f = $f; line = (Get-LineNo $f $s); tok = $tok })
    }
}
$distinct = [string[]]@($pending | ForEach-Object { $_.tok.ToLowerInvariant() } | Sort-Object -Unique)
function Resolve-Tokens {
    # token -> 'commit' | '<object type>' | 'ambiguous' | $null, by one cat-file --batch-check over the repository.
    param([string]$Repo, [string[]]$Tokens)
    $res = @{}
    if (-not $Tokens.Count) { return $res }
    $q = New-Object System.Collections.Generic.List[string]
    foreach ($t in $Tokens) { $q.Add($t + '^{commit}'); $q.Add($t) }
    $g = Invoke-GitLines -Repo $Repo -GitArgs @('cat-file', '--batch-check') -Stdin $q.ToArray()
    if (-not $g.ok -or $g.lines.Count -lt $q.Count) { throw "git cat-file --batch-check failed in $Repo (exit $($g.code), $($g.lines.Count) of $($q.Count) answers)" }
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        $a = $g.lines[2 * $i]; $b = $g.lines[2 * $i + 1]
        if ($a -match ' commit \d+$') { $res[$Tokens[$i]] = 'commit' }
        elseif ($a.EndsWith('ambiguous') -or $b.EndsWith('ambiguous')) { $res[$Tokens[$i]] = 'ambiguous' }
        elseif (-not $b.EndsWith('missing')) { $res[$Tokens[$i]] = (@($b -split ' ') + @('object'))[1] }
        else { $res[$Tokens[$i]] = $null }
    }
    return $res
}
$mine = @{}; $theirs = @{}
if ($fwOk) { $mine = Resolve-Tokens -Repo $FrameworkRepo -Tokens $distinct }
if ($HostRepo) { $theirs = Resolve-Tokens -Repo $HostRepo -Tokens $distinct }
$hexBoth = 0; $hexMine = 0
foreach ($pd in $pending) {
    $d = $pd.tok.ToLowerInvariant()
    $a = if ($fwOk) { $mine[$d] } else { $null }
    $b = if ($HostRepo) { $theirs[$d] } else { $null }
    if ($b -and -not $a) { Add-Hit $hard ('H3 host-id:' + $b) $pd.f $pd.line $pd.tok 'the host repository resolves it; the framework''s history does not' }
    elseif ($a) { if ($b) { $hexBoth++ } else { $hexMine++ } }
    elseif ($pd.f.rel.StartsWith('tests/')) { Add-Hit $soft 'FIXTURE-ID' $pd.f $pd.line $pd.tok $(if ($HostRepo) { 'neither repository resolves it' } else { 'the framework''s history does not resolve it (no -HostRepo)' }) }
    else { Add-Hit $soft 'HEX-UNRESOLVED' $pd.f $pd.line $pd.tok $(if ($HostRepo) { 'neither repository resolves it' } else { 'the framework''s history does not resolve it (no -HostRepo)' }) }
}

# ------------------------------------------------------------------------------------------------
# H4: the pinned bases
# ------------------------------------------------------------------------------------------------
$baseRx = New-Object System.Text.RegularExpressions.Regex '^tests/lam/fixtures/(base-[^/]+)/(.+)$'
$synthName = New-Object System.Text.RegularExpressions.Regex '(^|/)(instrument-sample-suite\.ps1\.base|SAMPLE-GOAL\.yaml|HALT-SAMPLE-[^/]*)$'
$b4 = @{}
$baseFiles = @($files | Where-Object { $baseRx.IsMatch($_.rel) })
if ($fwOk -and $baseFiles.Count) {
    # Every blob the framework's history recorded at a path, from one log over all of it.
    $held = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $lg = Invoke-GitLines -Repo $FrameworkRepo -GitArgs @('-c', 'core.quotePath=false', 'log', '--all', '-m', '--root', '--raw', '--no-abbrev', '--no-renames', '--format=')
    if (-not $lg.ok) { $fwOk = $false }
    foreach ($ln in $lg.lines) { if ($ln -match '^:\d{6} \d{6} [0-9a-f]{40} ([0-9a-f]{40}) [A-Z]\d*\t(.+)$') { $null = $held.Add($Matches[2] + [char]0 + $Matches[1]) } }
    # The recipes: the scope's own synthetic-bases.json, else the framework's at HEAD.
    $recipes = @{}
    $rj = @($files | Where-Object { $_.rel -eq 'tests/lam/fixtures/synthetic-bases.json' } | Select-Object -First 1)
    $rjText = if ($rj.Count) { $rj[0].text } else { $rb = Invoke-GitBytes -Repo $FrameworkRepo -Spec 'HEAD:tests/lam/fixtures/synthetic-bases.json'; if ($null -ne $rb) { $script:Utf8NoBom.GetString($rb) } else { '' } }
    if ($rjText) { foreach ($r in @(($rjText | ConvertFrom-Json).synthetic)) { $recipes[[string]$r.target] = $r } }
    $built = @{}
    function Test-RecipeBuilds { param($R, [byte[]]$Bytes)
        $key = [string]$R.target
        if ($built.ContainsKey($key)) { return $built[$key] }
        $ok = $false
        $src = Invoke-GitBytes -Repo $FrameworkRepo -Spec ([string]$R.source.commit + ':' + [string]$R.source.path)
        if ($null -ne $src -and (Get-Sha256Hex -Bytes $src) -eq [string]$R.source.sha256) {
            # The recipe's offsets count code points (the recipe was written by Python): the source as code points.
            $st = $script:Utf8NoBom.GetString($src)
            $cps = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $st.Length; $i++) {
                if ([char]::IsHighSurrogate($st[$i]) -and $i + 1 -lt $st.Length) { $cps.Add($st.Substring($i, 2)); $i++ } else { $cps.Add([string]$st[$i]) }
            }
            $sb = New-Object System.Text.StringBuilder
            foreach ($seg in @($R.segments)) {
                if ([string]$seg[0] -eq 'F') { for ($i = [int]$seg[1]; $i -lt [int]$seg[2]; $i++) { [void]$sb.Append($cps[$i]) } }
                else { [void]$sb.Append([string]$seg[1]) }
            }
            $ok = ((Get-Sha256Hex -Bytes $script:Utf8NoBom.GetBytes($sb.ToString())) -eq (Get-Sha256Hex -Bytes $Bytes))
        }
        $built[$key] = $ok
        return $ok
    }
    foreach ($f in $baseFiles) {
        $m = $baseRx.Match($f.rel); $rel = $m.Groups[2].Value
        $kind = $null
        if ($synthName.IsMatch($rel)) { $kind = 'synthetic-by-name' }
        elseif ($recipes.ContainsKey($f.rel) -and [string]$recipes[$f.rel].sha256 -eq (Get-Sha256Hex -Bytes $f.bytes) -and (Test-RecipeBuilds $recipes[$f.rel] $f.bytes)) { $kind = 'synthetic-by-recipe' }
        elseif ($rel.EndsWith('.base') -and $held.Contains($rel.Substring(0, $rel.Length - 5) + [char]0 + (Get-BlobId -Bytes $f.bytes))) { $kind = 'framework-held' }
        else { $kind = 'PINNED-HOST-COPY'; Add-Hit $hard 'H4 pinned-host-copy' $f 0 $f.rel 'neither synthetic nor bytes the framework''s history recorded at its path' }
        $b4[$kind] = 1 + $(if ($b4.ContainsKey($kind)) { $b4[$kind] } else { 0 })
    }
}

# ------------------------------------------------------------------------------------------------
# H5, and the B3 SOFT numbers
# ------------------------------------------------------------------------------------------------
foreach ($h in @($hard | Where-Object { $_.path.StartsWith('provenance/') -and $_.class -match '^H[123] ' })) {
    $hard.Add([pscustomobject]@{ class = 'H5 provenance-cites-host'; scope = $h.scope; path = $h.path; line = $h.line; token = $h.token; note = $h.class })
}
foreach ($f in $files) {
    if ($f.bin) { continue }
    $kind = if ($baseRx.IsMatch($f.rel)) { 'B3-FIXTURE-BASE' } elseif ($f.rel.StartsWith('tests/')) { 'B3-TESTS' } else { 'B3-OTHER' }
    foreach ($k in $b3Rx.Keys) { foreach ($m in $b3Rx[$k].Matches($f.text)) { Add-Hit $soft $kind $f (Get-LineNo $f $m.Index) $m.Value $k } }
    foreach ($m in $rRx.Matches($f.text)) {
        $ln = Get-LineNo $f $m.Index
        if ($rulingRx.IsMatch((Get-LineText $f $ln))) { Add-Hit $soft $kind $f $ln $m.Value 'R (on a line naming a ruling)' }
    }
}

# ------------------------------------------------------------------------------------------------
# THE REPORT
# ------------------------------------------------------------------------------------------------
$classes = [ordered]@{ 'H1' = 'host names'; 'H2' = 'host paths/URLs'; 'H3' = 'host commit/blob ids'; 'H4' = 'pinned host copies'; 'H5' = 'provenance citing the host' }
$out = New-Object System.Collections.Generic.List[string]
$out.Add('gate-host-data report (UI-1 S4, F2)')
$out.Add('generated ' + [DateTime]::UtcNow.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture))
foreach ($s in $scopes) { $out.Add("scope $($s.label): $($s.dir) -- $($s.how), $($s.count) file(s)") }
$out.Add("pattern file: $PatternFile ($patternCount literal(s), sha256 $(Get-Sha256Hex -Bytes ([System.IO.File]::ReadAllBytes($PatternFile))))")
$out.Add("names matched (H1): $($names.Count) -- $patternCount from the pattern file, the rest derived ($hostNote; this host's user and computer names)")
$out.Add("path patterns (H2): $($pathRx.Count) ($(@($pathRx | ForEach-Object { $_.kind }) -join ', '))")
$out.Add("framework history: $(if ($fwOk) { $FrameworkRepo } else { 'NOT READ -- H3 and H4 not evaluated' })")
$out.Add("hex tokens: $($pending.Count) occurrence(s), $($distinct.Count) distinct; digest prefixes passed over $digestPrefixes; the framework's history resolves $hexMine occurrence(s) the host does not, both resolve $hexBoth")
$out.Add("H3: $(if (-not $HostRepo) { 'NOT EVALUATED (no -HostRepo)' } elseif (-not $fwOk) { 'NOT EVALUATED (no framework history)' } else { 'evaluated against ' + $HostRepo })")
$out.Add("H4 pinned bases: $($baseFiles.Count) file(s) -- $(if ($b4.Count) { (@($b4.Keys | Sort-Object | ForEach-Object { "$_ $($b4[$_])" }) -join ', ') } elseif ($fwOk) { 'none' } else { 'NOT EVALUATED' })")
$out.Add('')
$hardTotal = $hard.Count
$out.Add("HARD $hardTotal")
foreach ($c in $classes.Keys) {
    $hs = @($hard | Where-Object { $_.class.StartsWith($c + ' ') })
    $out.Add(("  {0} {1,-28} {2}" -f $c, $classes[$c], $hs.Count))
}
foreach ($h in @($hard | Sort-Object class, scope, path, line)) {
    $out.Add(("  [{0}] {1}:{2}:{3}  {4}{5}" -f $h.class, $h.scope, $h.path, $h.line, $h.token, $(if ($h.note) { '  -- ' + $h.note } else { '' })))
}
$out.Add('')
$out.Add("SOFT $($soft.Count) (listed, never blocking)")
foreach ($g in @($soft | Group-Object class | Sort-Object Name)) { $out.Add(("  {0,-18} {1}" -f $g.Name, $g.Count)) }
foreach ($h in @($soft | Sort-Object class, scope, path, line)) {
    $out.Add(("  [{0}] {1}:{2}:{3}  {4}{5}" -f $h.class, $h.scope, $h.path, $h.line, $h.token, $(if ($h.note) { '  -- ' + $h.note } else { '' })))
}
$dir = Split-Path -Parent $Report
if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
[System.IO.File]::WriteAllText($Report, (($out -join "`n") + "`n"), $script:Utf8NoBom)

$byClass = (@($classes.Keys | ForEach-Object { $c = $_; "$c $(@($hard | Where-Object { $_.class.StartsWith($c + ' ') }).Count)" }) -join ', ')
Say ("HARD {0} ({1}){2}; SOFT {3}; files {4}" -f $hardTotal, $byClass, $(if (-not $HostRepo) { '; H3 not evaluated (no -HostRepo)' } else { '' }), $soft.Count, $files.Count)
Say "report $Report"
if (-not $fwOk) { Say 'NOT EVALUATED: the framework''s history could not be read, so H3 and H4 are not evaluated.'; exit 3 }
if ($hardTotal -gt 0) { exit 1 }
exit 0
