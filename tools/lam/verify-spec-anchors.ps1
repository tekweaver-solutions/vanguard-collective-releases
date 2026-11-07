#Requires -Version 5.1
<#
.SYNOPSIS
  docs/framework/mission-verify-spec.md section 10's anchor table, read against the files it names (RELEASE-4 S2 F-H16).

.DESCRIPTION
  Section 10 ("Derivation anchor, and the sealed sources this document is verified against") carries lines of the form
  "<sha256, first 8 hex>  <bytes>  <repo-relative path>". For each, the file is read and its sha256 taken on
  framework.lock's basis, fold-crlf-text (a file holding no 0x00 byte hashed with every CR LF made LF; one holding a 0x00
  raw), and its length raw, as it stands on disk; the row equals the file when both agree. In an LF checkout the fold
  sha256 is the raw one, which is what framework member A3 (check K3a, tools/framework/tests/test-a3-acceptance.ps1)
  re-derives; a CRLF checkout of the same files reads the same sha256 here and the CRLF length, and the line says so.

  -Rederive rewrites each row that differs, in place (the sha256 prefix and the byte length, nothing else on the line,
  the rest of the file byte for byte) and then reads the table again.

  One line per row, "anchor ok|DIFFERS <path> ...", then "verify-spec-anchors: <n> row(s), <d> differ".
  EXIT: 0 every row equals its file; 1 a row differs (or names no file); 2 the table could not be read.
#>
param(
    [string]$Root,
    [string]$Spec = 'docs/framework/mission-verify-spec.md',
    [switch]$Rederive
)
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$specPath = Join-Path $Root ($Spec -replace '/', '\')
function Say { param([string]$T) [Console]::Out.WriteLine('verify-spec-anchors: ' + $T) }
if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) { Say "no spec at $specPath"; exit 2 }
$L1 = [System.Text.Encoding]::GetEncoding(28591)
function Get-FoldSha256 { param([byte[]]$B)
    if ([System.Array]::IndexOf($B, [byte]0) -lt 0) { $B = $L1.GetBytes($L1.GetString($B).Replace("`r`n", "`n")) }
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($B))).Replace('-', '').ToLowerInvariant() } finally { $h.Dispose() }
}
function Read-Table {
    $text = $L1.GetString([System.IO.File]::ReadAllBytes($specPath))
    $s = [regex]::Match($text, '(?m)^## 10\. ')
    $e = [regex]::Match($text, '(?m)^## 11\. ')
    if (-not $s.Success -or -not $e.Success -or $e.Index -le $s.Index) { return $null }
    $sec = $text.Substring($s.Index, $e.Index - $s.Index)
    $rows = @()
    foreach ($m in [regex]::Matches($sec, '(?m)^([0-9a-f]{8})([ \t]+)(\d+)([ \t]+)(\S+)[ \t]*\r?$')) {
        $rows += [pscustomobject]@{ at = $s.Index + $m.Index; text = $m.Value.TrimEnd("`r"); sha8 = $m.Groups[1].Value; gap1 = $m.Groups[2].Value
                                    bytes = [long]$m.Groups[3].Value; gap2 = $m.Groups[4].Value; path = $m.Groups[5].Value }
    }
    return [pscustomobject]@{ text = $text; rows = $rows }
}
function Measure-Rows { param($Table)
    $out = @()
    foreach ($r in $Table.rows) {
        $full = Join-Path $Root ($r.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { $out += [pscustomobject]@{ row = $r; ok = $false; sha8 = ''; bytes = -1; why = 'no such file' }; continue }
        $b = [System.IO.File]::ReadAllBytes($full)
        $f8 = (Get-FoldSha256 -B $b).Substring(0, 8)
        $ok = ($f8 -ceq $r.sha8) -and ($b.Length -eq $r.bytes)
        $out += [pscustomobject]@{ row = $r; ok = $ok; sha8 = $f8; bytes = $b.Length; why = $(if ($ok) { '' } else { "the row says $($r.sha8)/$($r.bytes), the file is $f8/$($b.Length) (sha256 on fold-crlf-text, bytes raw)" }) }
    }
    return $out
}
$t = Read-Table
if ($null -eq $t -or @($t.rows).Count -eq 0) { Say "section 10 of $Spec carries no anchor row (or no section 10 / 11 heading)"; exit 2 }
$m = @(Measure-Rows $t)
if ($Rederive -and @($m | Where-Object { -not $_.ok -and $_.bytes -ge 0 }).Count) {
    $text = $t.text
    foreach ($x in @($m | Where-Object { -not $_.ok -and $_.bytes -ge 0 } | Sort-Object { $_.row.at } -Descending)) {
        $new = $x.sha8 + $x.row.gap1 + $x.bytes + $x.row.gap2 + $x.row.path
        $text = $text.Substring(0, $x.row.at) + $new + $text.Substring($x.row.at + $x.row.text.Length)
        Say "re-derived $($x.row.path): $($x.row.sha8)/$($x.row.bytes) -> $($x.sha8)/$($x.bytes)"
    }
    [System.IO.File]::WriteAllBytes($specPath, $L1.GetBytes($text))
    $t = Read-Table; $m = @(Measure-Rows $t)
}
foreach ($x in $m) { if ($x.ok) { Say "anchor ok      $($x.row.path) $($x.row.sha8)/$($x.row.bytes)" } else { Say "anchor DIFFERS $($x.row.path) -- $($x.why)" } }
$d = @($m | Where-Object { -not $_.ok }).Count
Say "$($m.Count) row(s), $d differ"
if ($d) { exit 1 }
exit 0
