# CONTRACT-M-56 guard driver: dot-source the (copied) mission-lib.ps1 and invoke the
# F-073 reopen-matched numbering helper against a fixture mission text, writing the
# resolved number to stdout. On an explicit-number/sealed-history mismatch the helper must
# HALT (Stop-WithError -> 'ERROR: ...REOPEN-NUMBER-MISMATCH...' + exit 1). The helper does
# not exist until F-073 builds it -- so this driver terminates non-zero at the RED baseline.
param(
    [Parameter(Mandatory)][string]$Lib,
    [Parameter(Mandatory)][string]$TxtFile,
    [Parameter(Mandatory)][string]$BlockKind,
    [Parameter(Mandatory)][int]$Explicit
)
$ErrorActionPreference = 'Stop'
. $Lib
$t = [System.IO.File]::ReadAllText($TxtFile)
$n = Resolve-ReopenMatchedNumber -MissionText $t -BlockKind $BlockKind -ExplicitNumber $Explicit
[Console]::Out.Write($n)
