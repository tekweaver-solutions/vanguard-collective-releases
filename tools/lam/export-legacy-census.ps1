#Requires -Version 5.1
<#
.SYNOPSIS
  Write a project's legacy HALT census, tools/lam/legacy-halt-census.txt, from the census literal of an earlier
  tools/lam/mission-goal-check.ps1 -- the step an upgrade from a release that carried the census inside the evaluator
  takes BEFORE install.ps1 runs (docs/framework/LAM-INSTALL.md section 10).

.DESCRIPTION
  In earlier releases the evaluator carried its legacy census as a literal, $script:HaltLegacyCensusText: the HALTs a
  project had answered by their own marker when that rule was retired, by file name and the sha256 of their bytes. It
  now reads tools/lam/legacy-halt-census.txt beside it, a HOST-CONFIG file the framework ships EMPTY. An upgrade
  installs that empty file where a project has none and replaces the evaluator, so a project whose goals honour legacy
  HALTs runs this first, against the evaluator it has, and keeps its census.

  THE OLD EVALUATOR IS READ, NEVER RUN. -From is parsed with the PowerShell parser and the one assignment to
  $script:HaltLegacyCensusText is taken from the syntax tree; nothing in it is dot-sourced, invoked or evaluated. Its
  value must be a single-quoted here-string. Every non-blank line of it, trimmed, must be one member,
  <HALT file name>@<64 lower-case hex sha256>, with no member twice. Where the old file's comments carry one
  '#  count : N' line and one '#  census_sha256 : <hex>' line, the extraction is held to both.

  THE CENSUS IS WRITTEN IN THE EVALUATOR'S FORM: a header of '#' comments carrying the count and the census_sha256
  (the sha256 of the members sorted ordinal, each followed by one LF, ASCII), then the members in ordinal order, LF,
  UTF-8 without a byte-order mark. The same -From gives the same bytes.

  WHERE: -To, or legacy-halt-census.txt beside -From. A census that is not empty is the project's and is never
  overwritten:
    absent, or holding no member line (the empty file the framework ships)  -> written
    holding exactly the bytes this export writes                            -> nothing written (exit 0)
    holding any other line that is neither blank nor a comment              -> REFUSED (exit 2), nothing written
  The file is written whole under a temporary name in the same folder, re-read and held to the export, then moved
  into place. A census entry is never printed: counts and sha256s only.

.PARAMETER From
  An earlier release's tools/lam/mission-goal-check.ps1 -- the project's own, before it upgrades.
.PARAMETER To
  The census file to write; by default legacy-halt-census.txt in -From's folder.

.NOTES
  EXIT: 0 written, already written, or a literal of no member (nothing to write); 2 refused, nothing written;
  1 -From or -To could not be used, nothing written.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$From,
    [string]$To
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:MemberForm = '\A([^@\\/:*?"<>|]+)@([0-9a-f]{64})\z'
$script:ReadBound = 67108864

function Say { param([string]$Text) [Console]::Out.WriteLine('export-legacy-census.ps1: ' + $Text) }
function Stop-Export { param([int]$Code, [string]$Text) Say $Text; exit $Code }

function Get-FullPath {
    # Resolved against PowerShell's location, as install.ps1 resolves its target (.NET would resolve a relative path
    # against the process directory, which Set-Location does not move).
    param([Parameter(Mandatory = $true)][string]$Path)
    $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/')
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { $d = $h.ComputeHash($Bytes) } finally { $h.Dispose() }
    return ([System.BitConverter]::ToString($d)).Replace('-', '').ToLowerInvariant()
}

function Get-MemberLines {
    # The member lines of a census text: every line, trimmed, that is neither blank nor a '#' comment.
    param([string]$Text)
    return @(($Text -split "`n") | ForEach-Object { $_.TrimEnd("`r").Trim() } | Where-Object { $_ -and (-not $_.StartsWith('#')) })
}

# ------------------------------------------------------------------------------------------------
# THE OLD EVALUATOR, PARSED
# ------------------------------------------------------------------------------------------------
$fromPath = Get-FullPath $From
if (-not (Test-Path -LiteralPath $fromPath -PathType Leaf)) { Stop-Export 1 "-From: no file at $fromPath" }
$fromItem = Get-Item -LiteralPath $fromPath -Force
if (($fromItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Export 1 "-From: $fromPath is a reparse point; name the file itself" }
if ($fromItem.Length -gt $script:ReadBound) { Stop-Export 1 "-From: $fromPath is larger than $($script:ReadBound) bytes" }
$fromBytes = [System.IO.File]::ReadAllBytes($fromPath)
$fromSha = Get-Sha256Hex -Bytes $fromBytes
$fromText = $null
try { $fromText = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($fromBytes) } catch { Stop-Export 1 "-From: $fromPath is not UTF-8" }
if ($fromText.Length -gt 0 -and [int]$fromText[0] -eq 0xFEFF) { $fromText = $fromText.Substring(1) }

$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($fromText, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) { Stop-Export 1 "-From: $fromPath does not parse ($(@($errors).Count) error(s)); nothing was read from it" }
$assignments = @($ast.FindAll({
    param($n)
    ($n -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
    ($n.Left -is [System.Management.Automation.Language.VariableExpressionAst]) -and
    ([string]::Equals($n.Left.VariablePath.UserPath, 'script:HaltLegacyCensusText', [System.StringComparison]::OrdinalIgnoreCase))
}, $true))
if ($assignments.Count -eq 0) { Stop-Export 1 "-From: $fromPath assigns no `$script:HaltLegacyCensusText -- it carries no census literal (an evaluator of this release reads legacy-halt-census.txt instead)" }
if ($assignments.Count -gt 1) { Stop-Export 1 "-From: $fromPath assigns `$script:HaltLegacyCensusText $($assignments.Count) times; which one is the census cannot be told" }
$right = $assignments[0].Right
$literal = $null
if (($assignments[0].Operator -eq [System.Management.Automation.Language.TokenKind]::Equals) -and
    ($right -is [System.Management.Automation.Language.CommandExpressionAst]) -and
    ($right.Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and
    ($right.Expression.StringConstantType -eq [System.Management.Automation.Language.StringConstantType]::SingleQuotedHereString)) {
    $literal = $right.Expression.Value
}
if ($null -eq $literal) { Stop-Export 1 "-From: $fromPath assigns `$script:HaltLegacyCensusText something other than a single-quoted here-string; nothing was read from it" }

$members = @(Get-MemberLines -Text $literal)
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
for ($i = 0; $i -lt $members.Count; $i++) {
    $m = [regex]::Match($members[$i], $script:MemberForm)
    if (-not ($m.Success -and ($m.Groups[1].Value -ceq $m.Groups[1].Value.Trim()))) {
        Stop-Export 1 "-From: member $($i + 1) of the literal is not <HALT file name>@<64 lower-case hex sha256> (it is not shown); nothing was written"
    }
    if (-not $seen.Add($members[$i])) { Stop-Export 1 "-From: member $($i + 1) of the literal stands twice (it is not shown); nothing was written" }
}
$sorted = [string[]]@($members)
[System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
$canon = (@($sorted) | ForEach-Object { $_ + "`n" }) -join ''
$censusSha = Get-Sha256Hex -Bytes ([System.Text.Encoding]::ASCII.GetBytes($canon))

$hdrCount = [regex]::Matches($fromText, '(?m)^#\s+count\s*:\s*(\d+)\b')
$hdrSha = [regex]::Matches($fromText, '(?m)^#\s+census_sha256\s*:\s*([0-9a-f]{64})\b')
if (($hdrCount.Count -gt 1) -or ($hdrSha.Count -gt 1)) { Stop-Export 1 "-From: $fromPath carries more than one census count or census_sha256 line; which one the literal is held to cannot be told" }
$held = @()
if ($hdrCount.Count -eq 1) {
    if ([int]$hdrCount[0].Groups[1].Value -ne $sorted.Count) { Stop-Export 1 "-From: the literal holds $($sorted.Count) member(s) and the file's own header says $($hdrCount[0].Groups[1].Value); nothing was written" }
    $held += 'count'
}
if ($hdrSha.Count -eq 1) {
    if ($hdrSha[0].Groups[1].Value -cne $censusSha) { Stop-Export 1 "-From: the literal's census_sha256 is $censusSha and the file's own header says $($hdrSha[0].Groups[1].Value); nothing was written" }
    $held += 'census_sha256'
}
Say ("from $fromPath (sha256 $fromSha): $($sorted.Count) member(s), census_sha256 $censusSha" + $(if ($held.Count) { "; equal to the file's own header (" + ($held -join ', ') + ')' } else { '; the file carries no header to hold it to' }))
if ($sorted.Count -eq 0) { Say 'the literal holds no member: there is no census to export, and nothing was written.'; exit 0 }

# ------------------------------------------------------------------------------------------------
# THE CENSUS FILE
# ------------------------------------------------------------------------------------------------
$header = @(
    '# tools/lam/legacy-halt-census.txt -- THE LEGACY HALT CENSUS that tools/lam/mission-goal-check.ps1 reads.',
    '#',
    '# Written by tools/lam/export-legacy-census.ps1 from the census literal of an earlier evaluator, a',
    "# mission-goal-check.ps1 of sha256 $($fromSha): the HALTs this project answered by",
    '# their own marker when that rule was retired, by file name and the sha256 of their bytes. Its form is the form of',
    "# the file the framework ships: '#' lines are comments, every other line is one member, in ordinal order. It is",
    '# HOST-CONFIG: an upgrade never rewrites it.',
    "#   count : $($sorted.Count)",
    "#   census_sha256 : $censusSha"
)
$exportText = (($header + @($sorted)) -join "`n") + "`n"
$exportBytes = $script:Utf8NoBom.GetBytes($exportText)

$toPath = if ($To) { Get-FullPath $To } else { Join-Path (Split-Path -Parent $fromPath) 'legacy-halt-census.txt' }
$toDir = Split-Path -Parent $toPath
if (-not (Test-Path -LiteralPath $toDir -PathType Container)) { Stop-Export 1 "-To: no folder $toDir" }
if (Test-Path -LiteralPath $toPath) {
    if (-not (Test-Path -LiteralPath $toPath -PathType Leaf)) { Stop-Export 1 "-To: $toPath is not a file" }
    $toItem = Get-Item -LiteralPath $toPath -Force
    if (($toItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Export 1 "-To: $toPath is a reparse point" }
    $have = [System.IO.File]::ReadAllBytes($toPath)
    if ((Get-Sha256Hex -Bytes $have) -ceq (Get-Sha256Hex -Bytes $exportBytes)) {
        Say "$toPath already holds this census ($($have.Length) bytes, sha256 $(Get-Sha256Hex -Bytes $have)); nothing was written."
        exit 0
    }
    $own = @(Get-MemberLines -Text ((New-Object System.Text.UTF8Encoding($false, $false)).GetString($have)))
    if ($own.Count -gt 0) {
        Stop-Export 2 "REFUSED: $toPath holds $($own.Count) line(s) of its own that are neither blank nor comments ($($have.Length) bytes, sha256 $(Get-Sha256Hex -Bytes $have)); a census that is not empty is the project's and is never overwritten. Nothing was written."
    }
}
$temp = Join-Path $toDir ('.legacy-halt-census-' + [guid]::NewGuid().ToString('N').Substring(0, 12) + '.tmp')
try {
    [System.IO.File]::WriteAllBytes($temp, $exportBytes)
    if ((Get-Sha256Hex -Bytes ([System.IO.File]::ReadAllBytes($temp))) -cne (Get-Sha256Hex -Bytes $exportBytes)) { throw 'the written copy does not read back as the export' }
    # No backup copy: [NullString]::Value, since PowerShell hands a .NET string parameter $null as ''.
    if (Test-Path -LiteralPath $toPath) { [System.IO.File]::Replace($temp, $toPath, [NullString]::Value) } else { [System.IO.File]::Move($temp, $toPath) }
} catch {
    $why = $_.Exception.Message
    try { if (Test-Path -LiteralPath $temp) { [System.IO.File]::Delete($temp) } } catch { }
    Stop-Export 1 "WRITE FAILED: $why. Nothing was written to $toPath."
}
Say "wrote $toPath ($($exportBytes.Length) bytes, sha256 $(Get-Sha256Hex -Bytes $exportBytes)): $($sorted.Count) member(s)."
exit 0
