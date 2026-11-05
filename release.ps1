#Requires -Version 5.1
<#
.SYNOPSIS
  Build dist\vanguard-collective-v<VERSION>.zip, dist\MEMBERS.sha256 and dist\SHA256SUMS
  deterministically from HEAD: HEAD's files less the dashboard's private source, the dashboard's build
  output, the third-party notices, and RELEASE.

.DESCRIPTION
  FROM HEAD, NEVER FROM THE WORKING TREE. Every member taken from the commit is a blob read out of HEAD's
  tree through git's own plumbing (git ls-tree, git cat-file blob), each checked against its own blob id;
  nothing on disk in the working tree is read, so an uncommitted edit cannot reach the archive and two
  builds at one HEAD read the same bytes. The dashboard is built from HEAD's ui/ blobs too, written into a
  build folder of their own outside the checkout.

  THE MEMBERS (UI-1 S4, ADR-045 "Distribution"):
    - every path git ls-tree -r --full-tree HEAD lists, but the dashboard's private source and the
      service's tests: any path under ui/ (its src/, tests/ and scripts/, and its toolchain files -- the
      frontend ships as build output only), a path under tools/ui/tests/, a .ts, .tsx or .map file, or a
      path with a node_modules segment ($script:Excluded). Each must be a file the installer does not own
      (a row of another class), or the build refuses.
    - ui/dist/**, the dashboard's build output: HEAD's ui/ written to <temp>\vcrel-<HEAD's first 12>\ui,
      then `npm ci --offline` (the lockfile's packages from the npm cache; one `npm ci` under ui\ with
      network fills it) and `npm run build` there, under node and npm exactly as ui\.nvmrc and
      package.json's engines pin them. No .map file may come out of it.
    - THIRD-PARTY-NOTICES, generated here (below).
    - RELEASE, the one file no commit can hold, since it names the commit.
  ui/dist/** and THIRD-PARTY-NOTICES are installer-owned, class MOVE. HEAD must not track either (a path
  there would collide with the generated one), nor a path whose first segment is RELEASE in any case.
  HEAD must carry install.ps1, mission.ps1, VERSION, LICENSE, README.md, INSTALL.md,
  provenance/manifest.jsonl, ui/.nvmrc, ui/package.json, ui/package-lock.json, tools/ui/requirements.txt
  and the release notes docs/RELEASE-NOTES-v<VERSION>.md. git runs with GIT_DIR and its other redirecting
  variables cleared.

  THE ZIP'S MANIFEST. provenance/manifest.jsonl in the ZIP is HEAD's, its header and every row kept byte
  for byte, but the rows of the excluded paths, which are dropped; then one row per generated member,
  sorted by path: source host, class MOVE, its sha256, bytes, eol (LF, CRLF, MIXED or NONE; BINARY for a
  file holding a 0x00 byte) and bom, reason "generated at release by release.ps1", flags ["generated"].
  So the ZIP's manifest names exactly the ZIP's members (RELEASE and itself aside), and the installer
  holds every file it installs to it. Every member taken from HEAD is held to its HEAD row (sha256 and
  bytes) before the archive is written. RELEASE reads:
      name: vanguard-collective
      version: <VERSION>
      framework_repo_tip: <HEAD, 40 hex>
      manifest_sha256: <sha256 of the ZIP's provenance/manifest.jsonl>

  THIRD-PARTY-NOTICES (ADR-045; UI-1 S4 P-3). Two sets, each package with its licence, its source URL and
  its licence text, LF, UTF-8 without a byte-order mark, sorted by name, no time stamp and no local path:
    - ui/dist: every production package of the tree `npm ci` installed from ui/package-lock.json, as
      the lockfile's pinned licence checker (license-checker-rseidelsohn, --production) reads it, the
      private root aside; and the build-time packages whose output the bundle carries
      ($script:BuildEmitters: vite's module-preload helper, tailwindcss's base styles, tailwindcss-animate).
    - tools/.venv: exactly the names and versions tools/ui/requirements.txt pins, read by pip-licenses
      (-LicensePython, an interpreter whose environment holds pip-licenses -- never the shipped set's own)
      over -ServicePython's environment, where that set is installed; a name missing, added or at another
      version refuses the build.
  THE ALLOW-LIST ($script:Allowed): MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, ISC, 0BSD, PSF-2.0,
  Unlicense, MPL-2.0 (file-level); and OFL-1.1 for a font package only (@fontsource/*,
  @fontsource-variable/*; operator ruling of 2026-11-04). An SPDX expression passes when every term of an
  AND, or one alternative of an OR, is on the list; a licence a checker guessed (a trailing '*') or could
  not read does not. A package outside the list refuses the build.

  THE UPGRADE COUNTS. The installer-owned set of the ZIP is compared with that of the latest release
  tag v<x.y.z> below VERSION that HEAD's history holds -- that tag's manifest -- as install.ps1 would
  judge an upgrade of a project that release installed and nobody edited: a TEMPLATE or HOST-CONFIG file
  present kept; a MOVE file identical after the fold already-identical, else upgraded; a path new to the
  set installed; a path gone retired. The release notes must carry the line
      install.ps1: done: written=<W> already-identical=<I> kept=<K> retired=<R> refused=0
  so the notes cannot state counts this build does not derive; without it the build refuses and prints
  the line. (A tag whose release generated members its tree does not hold -- 1.1.0 onward -- is read
  through its tree's manifest, which names no generated member: the counts then call those installed.)

  DETERMINISM, entry by entry: sorted by path in ordinal order; forward slashes; file entries only
  (no directory entries); every timestamp the ZIP epoch, 1980-01-01 00:00; no external attributes
  and no extra fields; deflate at CompressionLevel Optimal. The archive is written to a temporary
  name and moved into place. The bundle and the notices hold no time stamp, so two builds from one
  HEAD, with the same npm cache and the same Python environments, write the same bytes.

  dist\MEMBERS.sha256: one line per ZIP member, RELEASE included, `<sha256 lowercase>  <path>` (two
  spaces, forward slashes), sorted by path in ordinal order, LF line ends, a final LF, UTF-8 without
  a byte-order mark. The expanded tree is checked against it file for file.

  dist\SHA256SUMS: two lines, LF, the ZIP's first and MEMBERS.sha256's second, each
  `<sha256 lowercase>  <file name>`. Two builds from one HEAD write the same bytes to all three.

  dist\ is ignored by the repository's .gitignore (/dist/).

.PARAMETER LicensePython
  The interpreter of a Python environment holding pip-licenses (a scratch venv; never tools\.venv).
.PARAMETER ServicePython
  The interpreter of the environment holding the set tools/ui/requirements.txt pins; by default this
  checkout's tools\.venv\Scripts\python.exe.

.NOTES
  EXIT: 0 built; 1 refused (the reason printed; nothing is left in dist\ under the final names).
#>
[CmdletBinding()]
param(
    [string]$LicensePython,
    [string]$ServicePython
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$script:Latin1       = [System.Text.Encoding]::GetEncoding(28591)
$script:OwnedClasses = @('MOVE', 'TEMPLATE', 'HOST-CONFIG')
$script:Required     = @('install.ps1', 'mission.ps1', 'VERSION', 'LICENSE', 'README.md', 'INSTALL.md', 'provenance/manifest.jsonl',
                         'ui/.nvmrc', 'ui/package.json', 'ui/package-lock.json', 'tools/ui/requirements.txt')
$script:Excluded     = '^(ui/(?!dist/)|tools/ui/tests/)|\.(ts|tsx|map)$|(^|/)node_modules(/|$)'
$script:Generated    = '^(ui/dist/|THIRD-PARTY-NOTICES$)'
$script:BuildEmitters = @('vite', 'tailwindcss', 'tailwindcss-animate')
$script:Allowed      = @('MIT', 'BSD-2-Clause', 'BSD-3-Clause', 'Apache-2.0', 'ISC', '0BSD', 'PSF-2.0', 'Unlicense', 'MPL-2.0')
$script:FontOnly     = @{ 'OFL-1.1' = '^@fontsource(-variable)?/' }
$script:ZipEpoch     = New-Object System.DateTimeOffset(1980, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
# git reads these from the environment and would answer for another repository, or with injected configuration
# (install.ps1's $script:GitRedirects): cleared for this process before the first git call, so every git call
# below -- Invoke-GitText's and Read-Blob's alike -- reads this checkout's HEAD.
foreach ($v in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY',
        'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_NAMESPACE', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG_COUNT')) {
    [System.Environment]::SetEnvironmentVariable($v, $null, 'Process')
}

function Say { param([string]$Text) [Console]::Out.WriteLine('release.ps1: ' + $Text) }
function Stop-Release { param([string]$Text) Say ('REFUSED: ' + $Text); exit 1 }

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { $d = $h.ComputeHash($Bytes) } finally { $h.Dispose() }
    return ([System.BitConverter]::ToString($d)).Replace('-', '').ToLowerInvariant()
}

function Get-FoldSha256 {
    # install.ps1's judged form: a file holding a 0x00 byte raw, any other with every CR LF folded to LF.
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    if ([System.Array]::IndexOf($Bytes, [byte]0) -ge 0) { return (Get-Sha256Hex -Bytes $Bytes) }
    return (Get-Sha256Hex -Bytes $script:Latin1.GetBytes($script:Latin1.GetString($Bytes).Replace("`r`n", "`n")))
}

function Get-Field {
    param($Object, [string]$Name)
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = @(& git -C $script:Repo @GitArgs 2>$null); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prev }
    if ($code -ne 0) { Stop-Release "git $($GitArgs -join ' ') exited $code." }
    return ((@($out) | ForEach-Object { [string]$_ }) -join "`n")
}

# --- git cat-file blob <sha>: one process per blob, stdout read as BYTES ---------------------------
# NOT --batch: .NET's Process.Start flushes the stdin writer's encoding preamble the moment it starts
# the process, so the first request reached git as "<UTF-8 BOM><sha>" (measured: "<BOM><sha> missing").
# No stdin is opened here at all. Each blob is then checked against its own git id.
function Read-Blob {
    param([Parameter(Mandatory = $true)][string]$Sha)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = '-C "' + $script:Repo + '" cat-file blob ' + $Sha
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    try {
        $proc.StandardOutput.BaseStream.CopyTo($ms)
        $proc.WaitForExit()
        $code = $proc.ExitCode
    } finally { $proc.Dispose() }
    if ($code -ne 0) { Stop-Release "git cat-file blob $Sha exited $code." }
    $bytes = $ms.ToArray()
    # The blob's git id is sha1("blob <length>\0" + bytes): a short or altered read cannot pass.
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $pre = [System.Text.Encoding]::ASCII.GetBytes('blob ' + $bytes.Length + [char]0)
        $null = $sha1.TransformBlock($pre, 0, $pre.Length, $null, 0)
        $null = $sha1.TransformFinalBlock($bytes, 0, $bytes.Length)
        $id = ([System.BitConverter]::ToString($sha1.Hash)).Replace('-', '').ToLowerInvariant()
    } finally { $sha1.Dispose() }
    if ($id -ne $Sha) { Stop-Release "the bytes read for blob $Sha hash to blob id $id." }
    return , $bytes
}

function Invoke-Native {
    # One program, its stdout and stderr read whole as UTF-8 (each on its own thread, so neither pipe fills),
    # in a working folder of its own. Returns { code; out; err }.
    param([Parameter(Mandatory = $true)][string]$File, [string[]]$ArgList, [Parameter(Mandatory = $true)][string]$Cwd)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = (@($ArgList) | ForEach-Object { if ($_ -match '[\s"]' -or $_ -eq '') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $Cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $script:Utf8NoBom
    $psi.StandardErrorEncoding = $script:Utf8NoBom
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $errTask = $proc.StandardError.ReadToEndAsync()
        $out = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        $err = $errTask.Result
        $code = $proc.ExitCode
    } finally { $proc.Dispose() }
    return [pscustomobject]@{ code = $code; out = $out; err = $err }
}

function Get-EolWord {
    # The manifest's eol word for these bytes: BINARY (a 0x00 byte), NONE (no LF), LF, CRLF or MIXED.
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    if ([System.Array]::IndexOf($Bytes, [byte]0) -ge 0) { return 'BINARY' }
    $s = $script:Latin1.GetString($Bytes)
    $crlf = ($s.Length - $s.Replace("`r`n", '').Length) / 2
    $lf = ($s.Length - $s.Replace("`n", '').Length) - $crlf
    if ($crlf -eq 0 -and $lf -eq 0) { return 'NONE' }
    if ($crlf -eq 0) { return 'LF' }
    if ($lf -eq 0) { return 'CRLF' }
    return 'MIXED'
}

function ConvertTo-JsonText {
    # One JSON string literal, escaped by hand (install.ps1's ConvertTo-JsonText): no \u escape of ' < > &.
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return 'null' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in ([string]$Value).ToCharArray()) {
        if ($ch -eq [char]'"') { [void]$sb.Append('\"') }
        elseif ($ch -eq [char]'\') { [void]$sb.Append('\\') }
        elseif ([int]$ch -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Test-Licence {
    # '' when the SPDX expression passes THE ALLOW-LIST (header) for this package, else the reason.
    param([string]$Expression, [string]$Package)
    if (-not $Expression) { return 'no licence declared' }
    if ($Expression.Contains('*')) { return "a licence the checker guessed ($Expression)" }
    $e = $Expression.Trim()
    while ($e.StartsWith('(') -and $e.EndsWith(')')) { $e = $e.Substring(1, $e.Length - 2).Trim() }
    if ($e -match '\(') { return "an expression this check does not read ($Expression)" }
    $termOk = {
        param([string]$T)
        $T = $T.Trim()
        if ($script:Allowed -ccontains $T) { return $true }
        if ($script:FontOnly.ContainsKey($T) -and $Package -match $script:FontOnly[$T]) { return $true }
        return $false
    }
    if ($e -match ' OR ') { if (@($e -split ' OR ' | Where-Object { & $termOk $_ }).Count -gt 0) { return '' }; return "no alternative of $Expression is allowed" }
    $terms = @($e -split ' AND ')
    $bad = @($terms | Where-Object { -not (& $termOk $_) })
    if ($bad.Count -eq 0) { return '' }
    return "$($bad -join ', ') is not on the allow-list"
}

function ConvertTo-Spdx {
    # pip-licenses' licence string as SPDX: the metadata's expression as it stands, a classifier's name by the map
    # below, "BSD License" read by its text (a non-endorsement clause makes it BSD-3-Clause), anything else as given.
    param([string]$Name, [string]$Text)
    switch -exact ($Name) {
        'MIT License' { return 'MIT' }
        'Apache Software License' { return 'Apache-2.0' }
        'ISC License (ISCL)' { return 'ISC' }
        'Python Software Foundation License' { return 'PSF-2.0' }
        'BSD License' { if ($Text -match '(?i)neither the name') { return 'BSD-3-Clause' } else { return 'BSD-2-Clause' } }
    }
    return $Name.Replace(';', ' AND').Trim()
}

function Get-LicenceText {
    # A licence file's text, LF, trailing blank lines dropped; '' when the file is not a licence file (a README).
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    if ((Split-Path -Leaf $Path) -notmatch '^(?i)(licen[cs]e|copying|notice)') { return '' }
    return ($script:Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($Path)).Replace("`r`n", "`n").TrimEnd())
}

# ------------------------------------------------------------------------------------------------
$script:Repo = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$top = (Invoke-GitText -GitArgs @('rev-parse', '--show-toplevel')) -replace '/', '\'
if (-not [string]::Equals($top.TrimEnd('\'), $script:Repo, [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-Release "release.ps1 must sit at the top level of its git checkout ($top)."
}
$head = (Invoke-GitText -GitArgs @('rev-parse', 'HEAD')).Trim()
if ($head -notmatch '^[0-9a-f]{40}$') { Stop-Release 'HEAD is not a commit.' }
if (-not $ServicePython) { $ServicePython = Join-Path $script:Repo 'tools\.venv\Scripts\python.exe' }
if (-not $LicensePython) { Stop-Release 'name -LicensePython, the interpreter of a Python environment holding pip-licenses (a scratch venv, never tools\.venv).' }
foreach ($py in @($LicensePython, $ServicePython)) { if (-not (Test-Path -LiteralPath $py -PathType Leaf)) { Stop-Release "no interpreter at $py." } }

# HEAD's tree, NUL-separated so no path is quoted or re-encoded.
$tree = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::Ordinal)
foreach ($ent in (Invoke-GitText -GitArgs @('ls-tree', '-r', '-z', '--full-tree', $head)).Split([char]0)) {
    if (-not $ent) { continue }
    if ($ent -notmatch '^(\d{6}) (\w+) ([0-9a-f]{40})\t(.+)$') { Stop-Release "unreadable tree entry '$ent'." }
    if ($Matches[2] -ne 'blob') { Stop-Release "HEAD carries a $($Matches[2]) at $($Matches[4]); only blobs are released." }
    $tree[$Matches[4]] = $Matches[3]
}

foreach ($m in $script:Required) { if (-not $tree.ContainsKey($m)) { Stop-Release "HEAD does not carry $m." } }
$manifestBytes = Read-Blob -Sha $tree['provenance/manifest.jsonl']
$versionText = ($script:Utf8NoBom.GetString((Read-Blob -Sha $tree['VERSION']))).Trim()
# The form install.ps1 accepts: major.minor.patch in ASCII digits, no leading zero, no pre-release tag.
if ($versionText -cnotmatch '^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\z') { Stop-Release "HEAD's VERSION is not a version install.ps1 accepts: '$versionText'." }

$lines = ($script:Utf8NoBom.GetString($manifestBytes)).Split([char]10)
$header = $lines[0] | ConvertFrom-Json
if ((Get-Field $header 'manifest') -ne 'provenance') { Stop-Release "HEAD's manifest does not begin with its provenance header." }
$byDest = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
$keptLines = New-Object System.Collections.Generic.List[string]
$keptLines.Add($lines[0])
$droppedRows = 0
for ($i = 1; $i -lt $lines.Count; $i++) {
    if (-not $lines[$i]) { continue }
    $r = $lines[$i] | ConvertFrom-Json
    $dest = Get-Field $r 'destination'
    if ($null -ne $dest) {
        if ($byDest.ContainsKey([string]$dest)) { Stop-Release "the manifest names destination $dest twice." }
        $byDest[[string]$dest] = $r
        if ([string]$dest -match $script:Excluded) {
            if ((Get-Field $r 'source') -eq 'host' -and $script:OwnedClasses -contains [string](Get-Field $r 'class')) {
                Stop-Release "$dest is installer-owned (class $(Get-Field $r 'class')) but excluded from the release; the installer would refuse its absence."
            }
            $droppedRows++
            continue
        }
    }
    $keptLines.Add($lines[$i])
}

$notes = "docs/RELEASE-NOTES-v$versionText.md"
if (-not $tree.ContainsKey($notes)) { Stop-Release "HEAD does not carry $notes, the release notes for $versionText." }
# By the first path segment, without regard to case: a tracked 'release', or a folder such as 'Release/notes.md',
# would be RELEASE, or stand where it goes, once expanded on Windows. A tracked generated path would collide too.
$collide = @($tree.Keys | Where-Object { [string]::Equals($_.Split('/')[0], 'RELEASE', [System.StringComparison]::OrdinalIgnoreCase) -or $_ -match $script:Generated })
if ($collide.Count -gt 0) { Stop-Release "a tracked $($collide[0]) would collide with a generated member." }

# THE MEMBERS taken from HEAD: every path HEAD's tree holds, less the excluded ones, each held to its row.
$fromHead = [string[]]@($tree.Keys | Where-Object { $_ -notmatch $script:Excluded })
$excludedCount = $tree.Count - $fromHead.Count
$content = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]' ([System.StringComparer]::Ordinal)
foreach ($p in $fromHead) {
    # Two statements, not `$bytes = if ...`: an if-expression enumerates a byte[] into object[].
    if ($p -eq 'provenance/manifest.jsonl') { continue }
    $bytes = Read-Blob -Sha $tree[$p]
    if (-not $byDest.ContainsKey($p)) { Stop-Release "$p has no manifest line." }
    $want = [string](Get-Field $byDest[$p] 'sha256')
    $have = Get-Sha256Hex -Bytes $bytes
    if ($have -ne $want -or $bytes.Length -ne [long](Get-Field $byDest[$p] 'bytes')) {
        Stop-Release "$p at HEAD is $have/$($bytes.Length) bytes; its manifest line says $want/$(Get-Field $byDest[$p] 'bytes')."
    }
    $content[$p] = $bytes
}

# ------------------------------------------------------------------------------------------------
# THE DASHBOARD, built from HEAD's ui/ in a folder of its own
# ------------------------------------------------------------------------------------------------
$nvmrc = ($script:Utf8NoBom.GetString((Read-Blob -Sha $tree['ui/.nvmrc']))).Trim()
$pkg = $script:Utf8NoBom.GetString((Read-Blob -Sha $tree['ui/package.json'])) | ConvertFrom-Json
$npmWant = [string](Get-Field (Get-Field $pkg 'engines') 'npm')
$nodeHave = (Invoke-Native -File 'node.exe' -ArgList @('--version') -Cwd $script:Repo).out.Trim()
$npmHave = (Invoke-Native -File 'cmd.exe' -ArgList @('/d', '/c', 'npm', '--version') -Cwd $script:Repo).out.Trim()
if ($nodeHave -ne "v$nvmrc") { Stop-Release "node is $nodeHave; ui/.nvmrc pins v$nvmrc." }
if ($npmHave -ne $npmWant) { Stop-Release "npm is $npmHave; ui/package.json's engines pin $npmWant." }
$build = Join-Path ([System.IO.Path]::GetTempPath()) ('vcrel-' + $head.Substring(0, 12))
if (Test-Path -LiteralPath $build) { [System.IO.Directory]::Delete($build, $true) }
$uiDir = Join-Path $build 'ui'
foreach ($p in @($tree.Keys | Where-Object { $_.StartsWith('ui/') })) {
    $dst = Join-Path $build ($p -replace '/', '\')
    $null = [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($dst))
    [System.IO.File]::WriteAllBytes($dst, (Read-Blob -Sha $tree[$p]))
}
foreach ($kv in @(@('npm_config_update_notifier', 'false'), @('npm_config_audit', 'false'), @('npm_config_fund', 'false'))) { [System.Environment]::SetEnvironmentVariable($kv[0], $kv[1], 'Process') }
foreach ($step in @(@('ci', '--offline'), @('run', 'build'))) {
    $r = Invoke-Native -File 'cmd.exe' -ArgList (@('/d', '/c', 'npm') + $step) -Cwd $uiDir
    if ($r.code -ne 0) { Stop-Release ("npm $($step -join ' ') in $uiDir exited $($r.code): " + (($r.out + "`n" + $r.err).Trim() -split "`n" | Select-Object -Last 8) -join ' | ') }
}
$distDir = Join-Path $uiDir 'dist'
$distFiles = @(Get-ChildItem -LiteralPath $distDir -Recurse -File | ForEach-Object { 'ui/dist/' + $_.FullName.Substring($distDir.Length + 1).Replace('\', '/') })
if ($distFiles.Count -eq 0) { Stop-Release "npm run build left no file in $distDir." }
$generatedRows = New-Object System.Collections.Generic.List[string]
foreach ($p in $distFiles) {
    if ($p -match $script:Excluded) { Stop-Release "the build wrote $p, which the release excludes (a source map or source file)." }
    $content[$p] = [System.IO.File]::ReadAllBytes((Join-Path $build ($p -replace '/', '\')))
}

# ------------------------------------------------------------------------------------------------
# THIRD-PARTY-NOTICES
# ------------------------------------------------------------------------------------------------
$checkerBin = Join-Path $uiDir 'node_modules\license-checker-rseidelsohn\bin\license-checker-rseidelsohn.js'
if (-not (Test-Path -LiteralPath $checkerBin -PathType Leaf)) { Stop-Release 'ui/package-lock.json does not pin license-checker-rseidelsohn, the licence checker the notices are read by.' }
$checkerVersion = [string]((Get-Content -Raw -LiteralPath (Join-Path $uiDir 'node_modules\license-checker-rseidelsohn\package.json') | ConvertFrom-Json).version)
$entries = New-Object System.Collections.Generic.List[object]
$refusals = New-Object System.Collections.Generic.List[string]
$prodRead = Invoke-Native -File 'node.exe' -ArgList @($checkerBin, '--production', '--json', '--start', $uiDir) -Cwd $uiDir
if ($prodRead.code -ne 0) { Stop-Release "the licence checker exited $($prodRead.code): $($prodRead.err.Trim())" }
$prod = $prodRead.out | ConvertFrom-Json
foreach ($prop in @($prod.PSObject.Properties)) {
    if ($prop.Name -notmatch '^(@?[^@]+)@(.+)$') { Stop-Release "the licence checker named an entry '$($prop.Name)' it gave no version." }
    $name = $Matches[1]; $ver = $Matches[2]
    if ($name -eq [string](Get-Field $pkg 'name')) { continue }
    $lic = Get-Field $prop.Value 'licenses'
    $lic = if ($lic -is [array]) { (@($lic) -join ' AND ') } else { [string]$lic }
    $entries.Add([pscustomobject]@{ set = 'ui/dist'; name = $name; version = $ver; licence = $lic; url = [string](Get-Field $prop.Value 'repository'); text = (Get-LicenceText ([string](Get-Field $prop.Value 'licenseFile'))); notice = '' })
}
foreach ($name in $script:BuildEmitters) {
    $pj = Join-Path $uiDir ("node_modules\$name\package.json")
    if (-not (Test-Path -LiteralPath $pj -PathType Leaf)) { Stop-Release "the build-time package $name is not in the installed tree." }
    $pp = Get-Content -Raw -LiteralPath $pj | ConvertFrom-Json
    $lf = @(Get-ChildItem -LiteralPath (Split-Path -Parent $pj) -File | Where-Object { $_.Name -match '^(?i)(licen[cs]e|copying)' } | Sort-Object Name | Select-Object -First 1)
    $repoField = Get-Field $pp 'repository'
    $url = if ($repoField -is [string]) { $repoField } elseif ($null -ne $repoField) { [string](Get-Field $repoField 'url') } else { '' }
    $entries.Add([pscustomobject]@{ set = 'ui/dist (build-time; its output is in the bundle)'; name = $name; version = [string]$pp.version; licence = [string](Get-Field $pp 'license'); url = $url
        text = $(if ($lf.Count) { Get-LicenceText $lf[0].FullName } else { '' }); notice = '' })
}
$npmCount = $entries.Count
# The Python set: exactly what requirements.txt pins, read by pip-licenses over -ServicePython's environment.
$reqText = $script:Utf8NoBom.GetString((Read-Blob -Sha $tree['tools/ui/requirements.txt']))
$pins = [ordered]@{}
foreach ($m in [regex]::Matches($reqText, '(?m)^([A-Za-z0-9][A-Za-z0-9._-]*)==(\S+)')) { $pins[$m.Groups[1].Value.ToLowerInvariant().Replace('_', '-')] = $m.Groups[2].Value }
if ($pins.Count -eq 0) { Stop-Release 'tools/ui/requirements.txt pins no package.' }
$plv = (Invoke-Native -File $LicensePython -ArgList @('-X', 'utf8', '-I', '-m', 'piplicenses', '--version') -Cwd $script:Repo)
if ($plv.code -ne 0) { Stop-Release "-LicensePython $LicensePython has no pip-licenses (exit $($plv.code))." }
$plVersion = ($plv.out.Trim() -split '\s+')[-1]
$plRead = Invoke-Native -File $LicensePython -ArgList (@('-X', 'utf8', '-I', '-m', 'piplicenses', '--python', $ServicePython, '--from=mixed', '--format=json', '--with-license-file',
    '--no-license-path', '--with-notice-file', '--with-urls', '--packages') + @($pins.Keys)) -Cwd $script:Repo
if ($plRead.code -ne 0) { Stop-Release "pip-licenses exited $($plRead.code): $($plRead.err.Trim())" }
$seen = @{}
# Assigned before it is enumerated: Windows PowerShell 5.1's ConvertFrom-Json writes a JSON array as ONE object.
$plRows = $plRead.out | ConvertFrom-Json
foreach ($d in $plRows) {
    $n = ([string]$d.Name).ToLowerInvariant().Replace('_', '-')
    if (-not $pins.Contains($n)) { $refusals.Add("pip-licenses read $n, which requirements.txt does not pin"); continue }
    if ([string]$d.Version -ne $pins[$n]) { $refusals.Add("$n is $($d.Version) in $ServicePython; requirements.txt pins $($pins[$n])"); continue }
    $seen[$n] = $true
    $text = ([string]$d.LicenseText).Replace("`r`n", "`n").TrimEnd()
    if ($text -eq 'UNKNOWN') { $text = '' }
    $notice = ([string](Get-Field $d 'NoticeText')).Replace("`r`n", "`n").TrimEnd()
    if ($notice -eq 'UNKNOWN') { $notice = '' }
    $entries.Add([pscustomobject]@{ set = 'tools/.venv (the vanguard ui service)'; name = $n; version = [string]$d.Version; licence = (ConvertTo-Spdx ([string]$d.License) $text); url = [string]$d.URL; text = $text; notice = $notice })
}
foreach ($n in $pins.Keys) { if (-not $seen.ContainsKey($n)) { $refusals.Add("requirements.txt pins $n==$($pins[$n]), which pip-licenses did not read in $ServicePython") } }
foreach ($e in $entries) { $why = Test-Licence -Expression $e.licence -Package $e.name; if ($why) { $refusals.Add("$($e.name) $($e.version) ($($e.set)): $why") } }
if ($refusals.Count -gt 0) { foreach ($x in $refusals) { Say "  LICENCE  $x" }; Stop-Release "$($refusals.Count) package(s) above are outside the allow-list or the pinned set; nothing was built." }
$sorted = @($entries | Sort-Object @{ Expression = { if ($_.set.StartsWith('ui/')) { 0 } else { 1 } } }, @{ Expression = { $_.name } })
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("THIRD-PARTY-NOTICES -- Vanguard Collective $versionText`n`n")
[void]$sb.Append("The release carries third-party software in two places, each package under the licence named with it below. Every`n")
[void]$sb.Append("licence is on the release's allow-list -- $($script:Allowed -join ', '); OFL-1.1 for font packages only -- and the`n")
[void]$sb.Append("build refuses any other.`n")
[void]$sb.Append("- ui/dist, the dashboard's build output: the $($npmCount - $script:BuildEmitters.Count) production packages of ui/package-lock.json, read by license-checker-rseidelsohn`n")
[void]$sb.Append("  $checkerVersion over the tree npm ci installed, and $($script:BuildEmitters.Count) build-time packages whose output the bundle carries.`n")
[void]$sb.Append("- tools/.venv, the vanguard ui service's Python set: the $($pins.Count) packages tools/ui/requirements.txt pins, read by pip-licenses $plVersion.`n")
[void]$sb.Append("Generated by release.ps1; never edited by hand.`n")
$licCount = @{}
foreach ($e in $sorted) {
    $licCount[$e.licence] = 1 + $(if ($licCount.ContainsKey($e.licence)) { $licCount[$e.licence] } else { 0 })
    [void]$sb.Append("`n" + ('=' * 80) + "`n")
    [void]$sb.Append("$($e.name) $($e.version)`nLicence: $($e.licence)`n")
    if ($e.url) { [void]$sb.Append("Source: $($e.url)`n") }
    [void]$sb.Append("Shipped in: $($e.set)`n`n")
    if ($e.text) { [void]$sb.Append($e.text + "`n") } else { [void]$sb.Append("(The package carries no licence file; its metadata declares $($e.licence).)`n") }
    if ($e.notice) { [void]$sb.Append("`nNOTICE:`n" + $e.notice + "`n") }
}
$content['THIRD-PARTY-NOTICES'] = $script:Utf8NoBom.GetBytes($sb.ToString())

# THE ZIP'S MANIFEST: HEAD's, less the excluded rows, and a row per generated member.
$genNames = [string[]]@($content.Keys | Where-Object { $_ -match $script:Generated })
[System.Array]::Sort($genNames, [System.StringComparer]::Ordinal)
foreach ($p in $genNames) {
    $b = $content[$p]
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $keptLines.Add('{"source":"host","path":' + (ConvertTo-JsonText $p) + ',"class":"MOVE","blob":null,"sha256":' + (ConvertTo-JsonText (Get-Sha256Hex -Bytes $b)) +
        ',"bytes":' + $b.Length + ',"eol":' + (ConvertTo-JsonText (Get-EolWord -Bytes $b)) + ',"bom":' + $(if ($bom) { 'true' } else { 'false' }) + ',"destination":' + (ConvertTo-JsonText $p) +
        ',"reason":"generated at release by release.ps1 (UI-1 S4): ' + $(if ($p -eq 'THIRD-PARTY-NOTICES') { 'the third-party notices of ui/dist and tools/.venv' } else { 'the dashboard''s build output, npm run build over HEAD''s ui/' }) +
        '; installer-owned, class MOVE","flags":["generated"]}')
}
$zipManifest = $script:Utf8NoBom.GetBytes((($keptLines -join "`n") + "`n"))
$content['provenance/manifest.jsonl'] = $zipManifest
$manifestSha = Get-Sha256Hex -Bytes $zipManifest

# ------------------------------------------------------------------------------------------------
# THE UPGRADE COUNTS, from the latest earlier release tag HEAD's history holds
# ------------------------------------------------------------------------------------------------
$vParts = [int[]]@($versionText.Split('.') | ForEach-Object { [int]$_ })
$prev = $null; $prevParts = $null
foreach ($t in @((Invoke-GitText -GitArgs @('tag', '--list', 'v*', '--merged', $head)).Split([char]10) | Where-Object { $_ })) {
    if ($t -cnotmatch '^v(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$') { continue }
    $tp = [int[]]@([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
    $below = $false; for ($k = 0; $k -lt 3; $k++) { if ($tp[$k] -ne $vParts[$k]) { $below = ($tp[$k] -lt $vParts[$k]); break } }
    if (-not $below) { continue }
    $newer = $true
    if ($null -ne $prevParts) { $newer = $false; for ($k = 0; $k -lt 3; $k++) { if ($tp[$k] -ne $prevParts[$k]) { $newer = ($tp[$k] -gt $prevParts[$k]); break } } }
    if ($newer) { $prev = $t; $prevParts = $tp }
}
if (-not $prev) { Stop-Release "HEAD's history holds no release tag below $versionText to derive the upgrade counts from." }
$owned = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($l in @($keptLines | Select-Object -Skip 1)) {
    $r = $l | ConvertFrom-Json
    if ((Get-Field $r 'source') -eq 'host' -and $script:OwnedClasses -contains [string](Get-Field $r 'class') -and $null -ne (Get-Field $r 'destination')) { $owned[[string]$r.destination] = $r }
}
$oldOwned = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($l in (Invoke-GitText -GitArgs @('show', "${prev}:provenance/manifest.jsonl")).Split([char]10) | Select-Object -Skip 1) {
    if (-not $l) { continue }
    $r = $l | ConvertFrom-Json
    if ((Get-Field $r 'source') -eq 'host' -and $script:OwnedClasses -contains [string](Get-Field $r 'class') -and $null -ne (Get-Field $r 'destination')) { $oldOwned[[string]$r.destination] = $r }
}
$oldTree = @{}
foreach ($ent in (Invoke-GitText -GitArgs @('ls-tree', '-r', '-z', '--full-tree', $prev)).Split([char]0)) { if ($ent -match '^\d{6} blob ([0-9a-f]{40})\t(.+)$') { $oldTree[$Matches[2]] = $Matches[1] } }
$up = 0; $ins = 0; $same = 0; $kept = 0
foreach ($p in $owned.Keys) {
    if (-not $oldOwned.ContainsKey($p)) { $ins++; continue }
    if ([string]$owned[$p].class -ne 'MOVE') { $kept++; continue }
    if ([string]$oldOwned[$p].sha256 -eq [string]$owned[$p].sha256) { $same++; continue }
    $oldPath = [string]$oldOwned[$p].destination
    if ($oldTree.ContainsKey($oldPath) -and (Get-FoldSha256 -Bytes (Read-Blob -Sha $oldTree[$oldPath])) -eq (Get-FoldSha256 -Bytes $content[$p])) { $same++ } else { $up++ }
}
$retired = @($oldOwned.Keys | Where-Object { -not $owned.ContainsKey($_) }).Count
$doneLine = "install.ps1: done: written=$($up + $ins) already-identical=$same kept=$kept retired=$retired refused=0"
$notesText = $script:Utf8NoBom.GetString((Read-Blob -Sha $tree[$notes]))
if (-not $notesText.Contains($doneLine)) {
    Stop-Release "$notes does not state the upgrade from $prev this build derives -- the line '$doneLine' (upgraded $up, installed $ins)."
}

# ------------------------------------------------------------------------------------------------
# THE ARCHIVE
# ------------------------------------------------------------------------------------------------
$releaseText = "name: vanguard-collective`nversion: $versionText`nframework_repo_tip: $head`nmanifest_sha256: $manifestSha`n"
$content['RELEASE'] = $script:Utf8NoBom.GetBytes($releaseText)
$names = [string[]]@($content.Keys)
[System.Array]::Sort($names, [System.StringComparer]::Ordinal)

$dist = Join-Path $script:Repo 'dist'
$null = [System.IO.Directory]::CreateDirectory($dist)
$zipName = "vanguard-collective-v$versionText.zip"
$zipPath = Join-Path $dist $zipName
$sumsPath = Join-Path $dist 'SHA256SUMS'
$membersName = 'MEMBERS.sha256'
$membersPath = Join-Path $dist $membersName
$tmpPath = $zipPath + '.tmp'
foreach ($p in @($zipPath, $sumsPath, $membersPath, $tmpPath)) { if (Test-Path -LiteralPath $p) { [System.IO.File]::Delete($p) } }

Add-Type -AssemblyName System.IO.Compression
$fs = New-Object System.IO.FileStream($tmpPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
try {
    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($n in $names) {
            $e = $zip.CreateEntry($n, [System.IO.Compression.CompressionLevel]::Optimal)
            $e.LastWriteTime = $script:ZipEpoch
            $s = $e.Open()
            try { $b = $content[$n]; if ($b.Length -gt 0) { $s.Write($b, 0, $b.Length) } } finally { $s.Dispose() }
        }
    } finally { $zip.Dispose() }
} finally { $fs.Dispose() }
[System.IO.File]::Move($tmpPath, $zipPath)
try { [System.IO.Directory]::Delete($build, $true) } catch { Say "NOTE: the build folder $build could not be removed: $($_.Exception.Message)" }

$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$zipSha = Get-Sha256Hex -Bytes $zipBytes
# MEMBERS.sha256: each member's sha256, in the ZIP's own order (ordinal by path), RELEASE included.
$membersText = New-Object System.Text.StringBuilder
foreach ($n in $names) { [void]$membersText.Append((Get-Sha256Hex -Bytes $content[$n]) + '  ' + $n + "`n") }
$membersBytes = $script:Utf8NoBom.GetBytes($membersText.ToString())
[System.IO.File]::WriteAllBytes($membersPath, $membersBytes)
$membersSha = Get-Sha256Hex -Bytes $membersBytes
# SHA256SUMS: the ZIP's line first, as every earlier release wrote it, then MEMBERS.sha256's.
[System.IO.File]::WriteAllText($sumsPath, "$zipSha  $zipName`n$membersSha  $membersName`n", $script:Utf8NoBom)

$classCount = @{}
foreach ($c in $script:OwnedClasses) { $classCount[$c] = @($owned.Values | Where-Object { [string]$_.class -eq $c }).Count }
Say "HEAD $head (version $versionText)"
Say ("members: {0} = HEAD's {1} tracked files less {2} excluded (ui/ but ui/dist, tools/ui/tests, .ts/.tsx/.map) = {3}, + {4} ui/dist + THIRD-PARTY-NOTICES + RELEASE" -f $names.Count, $tree.Count, $excludedCount, $fromHead.Count, $distFiles.Count)
Say ("installer-owned {0} (MOVE {1}, TEMPLATE {2}, HOST-CONFIG {3}); release notes {4}" -f $owned.Count, $classCount['MOVE'], $classCount['TEMPLATE'], $classCount['HOST-CONFIG'], $notes)
Say ("notices: {0} npm packages ({1} production, {2} build-time; license-checker-rseidelsohn {3}), {4} Python packages (pip-licenses {5}); licences {6}" -f $npmCount, ($npmCount - $script:BuildEmitters.Count), $script:BuildEmitters.Count, $checkerVersion, $pins.Count, $plVersion, ((@($licCount.Keys | Sort-Object | ForEach-Object { "$_ $($licCount[$_])" })) -join ', '))
Say ("upgrade from {0}: {1} (upgraded {2}, installed {3})" -f $prev, $doneLine, $up, $ins)
Say "manifest_sha256 $manifestSha (the ZIP's manifest: HEAD's less $droppedRows excluded row(s), + $($genNames.Count) generated)"
Say "zip $zipPath  bytes $($zipBytes.Length)  sha256 $zipSha"
Say "MEMBERS.sha256 $membersPath  lines $($names.Count)  sha256 $membersSha"
Say "SHA256SUMS $sumsPath"
exit 0
