#Requires -Version 5.1
<#
.SYNOPSIS
  mission-promote-contract (A-116 / C2a) -- move named contract proposals
  .mission/contract/proposals/A-NNN.yaml -> .mission/contract/assertions/ CONTENT-IDENTICAL (a
  rename; no text change). The accepted home is assertions/ (location-is-marker).

.DESCRIPTION
  Promotion is the FIRST half of accept-contract (the ratify spec-bump is the separate
  mission-spec-bump command, per the two-command scoping). This command ONLY moves files, byte-for-
  byte, via `git mv` (so git records a rename). It REFUSES if a named proposal does not exist
  (mutates nothing). Invariants inherited from mission-lib.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Ids,   # e.g. A-115 A-116 ... or a manifest name (F-032-...-SCOPE.md sans path)
    [switch]$NoCommit
)

. (Join-Path $PSScriptRoot 'mission-lib.ps1')
$root = Get-MissionRoot
$propDir   = Join-Path $root ".mission\contract\proposals"
$assertDir = Join-Path $root ".mission\contract\assertions"

if (-not $NoCommit) { Assert-CleanWorkingTree -Root $root }   # A-126

# Resolve + verify EVERY named proposal exists BEFORE moving any (no silent partial promotion).
$moves = @()
foreach ($id in $Ids) {
    $name = if ($id -match '\.(yaml|md)$') { $id } else { "$id.yaml" }
    $src  = Join-Path $propDir $name
    if (-not (Test-Path $src)) {
        Stop-WithError "proposal does not exist: .mission/contract/proposals/$name (refusing -- nothing moved)."
    }
    $moves += [pscustomobject]@{ Name = $name; SrcRel = ".mission/contract/proposals/$name"; DstRel = ".mission/contract/assertions/$name"; Src = $src; Dst = (Join-Path $assertDir $name) }
}

$paths = @()
foreach ($m in $moves) {
    # content-identical move (A-116): capture the bytes BEFORE, git mv, verify bytes AFTER are identical.
    $before = [System.IO.File]::ReadAllBytes($m.Src)
    & git -C $root mv -- $m.SrcRel $m.DstRel | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-WithError "git mv failed for $($m.Name)" }
    $after = [System.IO.File]::ReadAllBytes($m.Dst)
    if (-not ([System.Linq.Enumerable]::SequenceEqual($before, $after))) {
        Stop-WithError "promotion altered content of $($m.Name) -- aborting (promotion must be byte-identical)."
    }
    # `git mv` ALREADY staged the rename (source-deletion + dest-add). Stage ONLY the destination here
    # (a no-op re-add that keeps the commit-path set explicit); re-adding the SOURCE path fails exit 128
    # ("pathspec did not match") because git mv moved it away -- the A-116 defect. The staged rename is
    # what the atomic commit captures.
    $paths += $m.DstRel
    Write-Pass "promoted $($m.Name) (proposals -> assertions, byte-identical)"
}

# R-y/R-z shift-left advisory: a promoted assertion whose milestone roster does NOT yet list it will fail the
# roster-invariant lint (test_assertion_roster_invariant.py) + block CLOSE (empty/partial-roster guard). This
# tool is MOVE-ONLY by design -- it does NOT mutate the spec; roster population is a spec-bump amendment.
# Warn now so the gap is caught at promote time, not at close.
$specName = ((Get-Content (Join-Path $root ".mission\spec\current.txt") -Raw)).Trim()
$specText = [System.IO.File]::ReadAllText((Join-Path $root ".mission\spec\$specName.yaml"))
foreach ($m in $moves) {
    if ($m.Name -notmatch '\.yaml$') { continue }
    $aid = [System.IO.Path]::GetFileNameWithoutExtension($m.Name)
    $atext = [System.IO.File]::ReadAllText($m.Dst)
    $mm = [regex]::Match($atext, '(?m)^\s*milestone_id:\s*(\S+)')
    if (-not $mm.Success) { continue }
    $mid = $mm.Groups[1].Value.Trim()
    if ($mid -in @('null', '~', '')) { continue }
    $mb = [regex]::Match($specText, "(?ms)^  - id: $([regex]::Escape($mid))\b.*?(?=^  - id: |\Z)")
    if (-not $mb.Success) {
        Write-Host "  [WARN] $aid names milestone $mid, ABSENT from the current spec ($specName)." -ForegroundColor Yellow
        continue
    }
    $rm = [regex]::Match($mb.Value, 'contract_assertion_ids:\s*\[([^\]]*)\]')
    $roster = if ($rm.Success) { @($rm.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
    if ($roster -notcontains $aid) {
        Write-Host "  [WARN] $aid promoted but NOT in $mid's contract_assertion_ids roster -- populate it via a roster amendment (spec-bump), else the roster-invariant lint + CLOSE-$mid will fail." -ForegroundColor Yellow
    }
}

if (-not $NoCommit) {
    $list = ($moves | ForEach-Object { $_.Name }) -join ', '
    $body = "promote-contract: $list`r`n`r`nMove named proposals -> assertions/ content-identical (A-116).`r`n"
    $msg = New-CommitMessageFile -Root $root -Body $body
    Invoke-AtomicCommit -Root $root -Paths $paths -MessageFile $msg | Out-Null
}
Write-Host "mission promote-contract: done ($($moves.Count) promoted)" -ForegroundColor Cyan
