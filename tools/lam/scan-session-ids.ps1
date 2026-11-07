#Requires -Version 5.1
<#
.SYNOPSIS
  The session-id class of the zero-host-data reading (RELEASE-4 S2 F-H4; row 495 (2)): the host's evidence-session ids
  found in a release tree's fixtures and pins.

.DESCRIPTION
  -IdFile is a file of the HOST's record, read at run time and never copied: every GUID it holds (8-4-4-4-12 hex) is a
  session id of the host. Every file under -Root's -Under folders (default tests, which holds the shipped fixtures and
  pinned bases, tests/lam/fixtures) is read for those ids; each hit is printed as "SESSION-ID <path>:<line>" with the id's
  first 8 hex only, then "scan-session-ids: <n> hit(s) of <d> host id(s) under <folders> (<f> file(s))".
  Like the gate's pattern file, the id file names the host's data, so it may not lie inside -Root.
  NO VACUOUS PASS (RELEASE-4 S3 F-X4; S2 validator X-4): -Under given through -File as one comma-joined string is split into
  its folders, and a -Under folder that does not stand below -Root is REFUSED by name (exit 2) -- never skipped, which read
  0 file(s) and passed. (The default once named tools/lam/fixtures, which no tree holds.)
  EXIT: 0 no hit; 1 a hit; 2 a parameter refused.
#>
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$IdFile,
    [string[]]$Under = @('tests')
)
$ErrorActionPreference = 'Stop'
function Say { param([string]$T) [Console]::Out.WriteLine('scan-session-ids: ' + $T) }
$rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
$idFull = [System.IO.Path]::GetFullPath($IdFile)
if (-not [System.IO.Directory]::Exists($rootFull)) { Say "-Root is not a folder: $rootFull"; exit 2 }
if (-not [System.IO.File]::Exists($idFull)) { Say "-IdFile is not a file: $idFull"; exit 2 }
if ($idFull.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { Say "-IdFile lies inside -Root; the host's record is never put in the tree it is read against"; exit 2 }
$Under = @(@($Under) | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if (-not $Under.Count) { Say "-Under names no folder"; exit 2 }
foreach ($u in $Under) {
    if (-not [System.IO.Directory]::Exists((Join-Path $rootFull ($u -replace '/', '\')))) { Say "-Under folder does not stand: $u (below $rootFull); nothing was read"; exit 2 }
}
$rx = [regex]'(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
$ids = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($m in $rx.Matches([System.IO.File]::ReadAllText($idFull))) { [void]$ids.Add($m.Value.ToLowerInvariant()) }
$hits = 0; $files = 0
foreach ($u in $Under) {
    $d = Join-Path $rootFull ($u -replace '/', '\')
    foreach ($f in @(Get-ChildItem -LiteralPath $d -Recurse -File -Force)) {
        $files++
        $lines = [System.IO.File]::ReadAllLines($f.FullName)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($m in $rx.Matches($lines[$i])) {
                if ($ids.Contains($m.Value.ToLowerInvariant())) { $hits++; Say ("SESSION-ID {0}:{1} {2}..." -f $f.FullName.Substring($rootFull.Length + 1).Replace('\', '/'), ($i + 1), $m.Value.Substring(0, 8)) }
            }
        }
    }
}
Say ("{0} hit(s) of {1} host id(s) under {2} ({3} file(s))" -f $hits, $ids.Count, ($Under -join ', '), $files)
if ($hits) { exit 1 }
exit 0
