#Requires -Version 5.1
<#
.SYNOPSIS
  WP-1 H-3 and H-16 execution driver -- dot-source ONE mission-lib.ps1 and invoke A-126's
  Assert-CleanWorkingTree against ONE isolated scratch mission root.

.DESCRIPTION
  H-3 derives a POST-IMAGE TREE FROM THE PATCH BODY (since an earlier revision: a
  FORWARD apply to the patch's own pinned pre-image fixture) and needs to EXECUTE the
  Assert-CleanWorkingTree that tree contains. A text assertion over a patch's post-image cannot
  bind a BEHAVIOURAL property of the code in that post-image -- three rounds of closed lists were
  driven through by three different spellings of the same defect. This file is how the post-image
  gets run.

  WHICH -Lib, AND WHY THERE ARE TWO CALLERS THAT MAY NOT SUBSTITUTE FOR EACH OTHER.
  WP-1 H-3 passes the DERIVED copy, never tools/mission-lib.ps1. The point of that leg is that the
  code under execution came out of the patch, so a defect planted in the patch is carried into the
  process this script starts; pointing -Lib at the repository's own file there would measure the
  repository and prove nothing about the artifact.
  WP-1 H-16 passes the LIVE tools/mission-lib.ps1, dot-sourced
  in place, because ITS subject is the repository's own gate: once H-3 stopped reading the live
  tools/ tree, the live Assert-CleanWorkingTree had to be judged somewhere, and H-16 judges it by
  behaviour over the same scratch mission roots. For its reader-absent rows H-16 passes a copy of
  the live file placed alone in a scratch directory.

  THE COPY'S LAYOUT IS PART OF THE CONTRACT. Assert-CleanWorkingTree resolves its
  admitted-porcelain reader as $PSScriptRoot\lam\lam-verify-admission.ps1, so the caller must
  place that library beside the copied mission-lib.ps1 or the gate refuses for want of its own
  reader -- a refusal that would look like a cure working and is not one.

  THE EXIT CODE IS THE VERDICT. The gate refuses through Stop-WithError, which prints
  'ERROR: ...' on stdout and exits 1; it passes through Write-Pass and falls off the end at 0.
  So the caller reads $LASTEXITCODE for the verdict and stdout for the reason.

  $AllowPathsCsv IS A SINGLE STRING, SPLIT HERE. PowerShell 5.1's argument-mode parsing of
  `-X a,b` after -File is exactly the silent-arity surprise this repository has been bitten by
  (an array literal in ARGUMENT position yielding a different element count than it reads), so
  one string goes in and the split is asserted here.

  ACKNOWLEDGEMENT, because the technique is not invented here. tools/tests/cli/
  _drv_clean_working_tree.ps1 and test_a126_admitted_porcelain.py drive
  the same cure from pytest. That pair is BATCH 3'S FILE SET: it was READ to learn how a scratch
  mission root and a scratch git repository are stood up so porcelain really emits the planted
  lines, and it is neither edited nor invoked from here. WP-1 needs the leg inside its own
  instrument because H-3's subject is the PATCH ARTIFACT, which that suite never reads.
#>
param(
    [Parameter(Mandatory = $true)][string]$Lib,
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$AllowPathsCsv = ''
)
$ErrorActionPreference = 'Stop'
. $Lib
$paths = @()
if ($AllowPathsCsv) { $paths = @($AllowPathsCsv -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if ($paths.Count -gt 0) { Assert-CleanWorkingTree -Root $Root -AllowPaths $paths }
else                    { Assert-CleanWorkingTree -Root $Root }
