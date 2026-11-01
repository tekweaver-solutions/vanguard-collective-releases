#Requires -Version 5.1
<#
.SYNOPSIS
  Build dist\vanguard-collective-v<VERSION>.zip, dist\MEMBERS.sha256 and dist\SHA256SUMS
  deterministically from HEAD.

.DESCRIPTION
  FROM HEAD, NEVER FROM THE WORKING TREE. Every member is a blob read out of HEAD's tree through
  git's own plumbing (git ls-tree, git cat-file blob), each checked against its own blob id; nothing
  on disk in the working tree is read, so an uncommitted edit cannot reach the archive and two builds
  at one HEAD read the same bytes.

  THE MEMBERS: EXACTLY what the commit holds -- every path git ls-tree -r --full-tree HEAD lists --
  plus one generated member, RELEASE, the one file no commit can hold, since it names the commit. The
  operator tags this HEAD and publishes this repository, so the expanded ZIP is the tagged commit's
  tree file for file, and RELEASE beside it. HEAD must carry install.ps1, mission.ps1, VERSION,
  LICENSE, README.md, INSTALL.md, provenance/manifest.jsonl and the release notes
  docs/RELEASE-NOTES-v<VERSION>.md (a HEAD without any of them builds nothing), and must not track a
  path whose first segment is RELEASE in any case, a file or a folder (it would collide with the
  generated one). git runs with GIT_DIR and its other redirecting variables cleared. RELEASE reads:
      name: vanguard-collective
      version: <VERSION>
      framework_repo_tip: <HEAD, 40 hex>
      manifest_sha256: <sha256 of HEAD's provenance/manifest.jsonl>
  Every member but the manifest itself (whose own line cannot carry its digest) must have a manifest
  line whose destination is its path -- the tree law guarantees one -- and is held to it (sha256 and
  bytes) before the archive is written; a member without one, or that does not match, refuses the
  build. RELEASE does not carry the ZIP's own sha256 and cannot: it is inside the ZIP.
  dist\SHA256SUMS carries it.

  DETERMINISM, entry by entry: sorted by path in ordinal order; forward slashes; file entries only
  (no directory entries); every timestamp the ZIP epoch, 1980-01-01 00:00; no external attributes
  and no extra fields; deflate at CompressionLevel Optimal. The archive is written to a temporary
  name and moved into place.

  dist\MEMBERS.sha256: one line per ZIP member, RELEASE included, `<sha256 lowercase>  <path>` (two
  spaces, forward slashes), sorted by path in ordinal order, LF line ends, a final LF, UTF-8 without
  a byte-order mark. Every line but RELEASE's names a file of the commit; the expanded tree is checked
  against it file for file.

  dist\SHA256SUMS: two lines, LF, the ZIP's first and MEMBERS.sha256's second, each
  `<sha256 lowercase>  <file name>`. Two builds from one HEAD write the same bytes to all three.

  dist\ is ignored by the repository's .gitignore (/dist/).

.NOTES
  EXIT: 0 built; 1 refused (the reason printed; nothing is left in dist\ under the final names).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$script:OwnedClasses = @('MOVE', 'TEMPLATE', 'HOST-CONFIG')
$script:Required     = @('install.ps1', 'mission.ps1', 'VERSION', 'LICENSE', 'README.md', 'INSTALL.md', 'provenance/manifest.jsonl')
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

# ------------------------------------------------------------------------------------------------
$script:Repo = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$top = (Invoke-GitText -GitArgs @('rev-parse', '--show-toplevel')) -replace '/', '\'
if (-not [string]::Equals($top.TrimEnd('\'), $script:Repo, [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-Release "release.ps1 must sit at the top level of its git checkout ($top)."
}
$head = (Invoke-GitText -GitArgs @('rev-parse', 'HEAD')).Trim()
if ($head -notmatch '^[0-9a-f]{40}$') { Stop-Release 'HEAD is not a commit.' }

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
$manifestSha = Get-Sha256Hex -Bytes $manifestBytes
$versionText = ($script:Utf8NoBom.GetString((Read-Blob -Sha $tree['VERSION']))).Trim()
# The form install.ps1 accepts: major.minor.patch in ASCII digits, no leading zero, no pre-release tag.
if ($versionText -cnotmatch '^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\z') { Stop-Release "HEAD's VERSION is not a version install.ps1 accepts: '$versionText'." }

$lines = ($script:Utf8NoBom.GetString($manifestBytes)).Split([char]10)
$header = $lines[0] | ConvertFrom-Json
if ((Get-Field $header 'manifest') -ne 'provenance') { Stop-Release "HEAD's manifest does not begin with its provenance header." }
$byDest = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
$owned = New-Object System.Collections.Generic.List[string]
for ($i = 1; $i -lt $lines.Count; $i++) {
    if (-not $lines[$i]) { continue }
    $r = $lines[$i] | ConvertFrom-Json
    $dest = Get-Field $r 'destination'
    if ($null -eq $dest) { continue }
    if ($byDest.ContainsKey([string]$dest)) { Stop-Release "the manifest names destination $dest twice." }
    $byDest[[string]$dest] = $r
    if ((Get-Field $r 'source') -eq 'host' -and $script:OwnedClasses -contains [string](Get-Field $r 'class')) { $owned.Add([string]$dest) }
}

$notes = "docs/RELEASE-NOTES-v$versionText.md"
if (-not $tree.ContainsKey($notes)) { Stop-Release "HEAD does not carry $notes, the release notes for $versionText." }
# THE MEMBERS: every path HEAD's tree holds, and RELEASE.
$members = [string[]]@($tree.Keys)
# By the first path segment, without regard to case: a tracked 'release', or a folder such as 'Release/notes.md',
# would be RELEASE, or stand where it goes, once expanded on Windows.
$collide = @($members | Where-Object { [string]::Equals($_.Split('/')[0], 'RELEASE', [System.StringComparison]::OrdinalIgnoreCase) })
if ($collide.Count -gt 0) { Stop-Release "a tracked $($collide[0]) would collide with the generated RELEASE." }

$content = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]' ([System.StringComparer]::Ordinal)
foreach ($p in $members) {
    # Two statements, not `$bytes = if ...`: an if-expression enumerates a byte[] into object[].
    if ($p -eq 'provenance/manifest.jsonl') { $bytes = $manifestBytes } else { $bytes = Read-Blob -Sha $tree[$p] }
    if ($p -ne 'provenance/manifest.jsonl') {
        if (-not $byDest.ContainsKey($p)) { Stop-Release "$p has no manifest line." }
        $want = [string](Get-Field $byDest[$p] 'sha256')
        $have = Get-Sha256Hex -Bytes $bytes
        if ($have -ne $want -or $bytes.Length -ne [long](Get-Field $byDest[$p] 'bytes')) {
            Stop-Release "$p at HEAD is $have/$($bytes.Length) bytes; its manifest line says $want/$(Get-Field $byDest[$p] 'bytes')."
        }
    }
    $content[$p] = $bytes
}

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

Say "HEAD $head (version $versionText)"
Say "members: $($names.Count) = HEAD's $($members.Count) tracked files (installer-owned $($owned.Count) among them; release notes $notes) + RELEASE"
Say "manifest_sha256 $manifestSha"
Say "zip $zipPath  bytes $($zipBytes.Length)  sha256 $zipSha"
Say "MEMBERS.sha256 $membersPath  lines $($names.Count)  sha256 $membersSha"
Say "SHA256SUMS $sumsPath"
exit 0
