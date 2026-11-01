# CONTRACT-M-56 guard driver: dot-source the (copied) mission-lib.ps1 and invoke the
# F-072 comment-tolerant field-writer helper against a fixture text, writing the result
# to stdout. The helper does not exist until F-072 builds it -- so this driver terminates
# non-zero (CommandNotFound under $ErrorActionPreference='Stop') at the contract RED baseline.
param(
    [Parameter(Mandatory)][string]$Lib,
    [Parameter(Mandatory)][string]$TxtFile,
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][string]$Value
)
$ErrorActionPreference = 'Stop'
. $Lib
$t = [System.IO.File]::ReadAllText($TxtFile)
$r = Set-MissionFieldValue -Text $t -Key $Key -Value $Value
[Console]::Out.Write($r)
