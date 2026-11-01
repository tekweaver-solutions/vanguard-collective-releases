# Guard driver -- dot-source the (copied) mission-lib and run the pure
# Test-WitnessedSubstrate helper against an ISOLATED fixture root.
param(
    [Parameter(Mandatory)][string]$Lib,
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Name
)
. $Lib
Test-WitnessedSubstrate -Root $Root -SubstrateName $Name
