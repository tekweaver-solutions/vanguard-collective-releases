# Guard driver: dot-source the (copied) mission-lib.ps1 and invoke A-126's
# Assert-CleanWorkingTree against an ISOLATED scratch mission root in a temp dir. NEVER the real
# .mission. The gate REFUSES via Stop-WithError, which prints 'ERROR: ...' and exits 1, so the
# exit code is the verdict and stdout carries the reason the test asserts on.
#
# THE COPY IS PART OF THE CONTRACT. Assert-CleanWorkingTree reads the mission's declared
# admitted_porcelain through tools/lam/lam-verify-admission.ps1, resolved as
# $PSScriptRoot\lam\lam-verify-admission.ps1 -- so the fixture must place that library beside the
# copied mission-lib.ps1 or the gate refuses for want of its own reader. Pinning that here means a
# later move of either file fails this suite instead of failing a live ceremony.
#
# $AllowPathsCsv IS A SINGLE STRING, SPLIT HERE, and deliberately not a [string[]] bound through
# -File: PowerShell 5.1's argument-mode parsing of `-X a,b` after -File is exactly the kind of
# silent arity surprise this repository has been bitten by (an array literal in ARGUMENT position
# yielding a different element count than it reads). One string in, an asserted split here.
param(
    [Parameter(Mandatory)][string]$Lib,
    [Parameter(Mandatory)][string]$Root,
    [string]$AllowPathsCsv = ''
)
$ErrorActionPreference = 'Stop'
. $Lib
$paths = @()
if ($AllowPathsCsv) { $paths = @($AllowPathsCsv -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if ($paths.Count -gt 0) { Assert-CleanWorkingTree -Root $Root -AllowPaths $paths }
else                    { Assert-CleanWorkingTree -Root $Root }
