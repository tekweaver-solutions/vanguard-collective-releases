#Requires -Version 5.1
<#
.SYNOPSIS
  Is the pre-push DECIDER installed in a repository, and is it the one we shipped?
  (LAM-ACCEPT T-2 as amended.)

.DESCRIPTION
  ONE DEFINITION, INVOKED THE SAME WAY BY EVERY CONSUMER. The rule for "correctly installed" lives
  in `Test-EvidencePrePushHookInstalled` in the guard library and nowhere else. The runner and the
  WP-4 instrument both reach it through THIS script, as a child process, for two reasons:

    * the guard library may not be dot-sourced into an arbitrary caller's scope -- it redefines A1
      functions by design, and a caller that happens to use one would get the delta's version by
      accident rather than by choice;
    * the dependency direction is fixed. The guard library deliberately does NOT depend on
      `tools/lam` (LAM-INSTALL sec 2 installs the next-gen tree on its own, into repositories that
      may not contain `tools/lam` at all), so the runner depends on the library and never the
      reverse.

  Prints one JSON object and exits 0 when installed and matching, 1 otherwise. Exit code and payload
  agree by construction; a caller may read either.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [string]$DeciderPath
)
$ErrorActionPreference = 'Stop'
if (-not $DeciderPath) { $DeciderPath = (Join-Path $PSScriptRoot 'evidence-pre-push.ps1') }

try {
    . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
} catch {
    # A checker that cannot load its own rule must not report "installed". Unanswerable is refused,
    # which is the same direction every other precondition in this toolchain takes.
    (@{ installed = $false; path = $null; sha256 = $null; expected = $null
        reason = "the guard library could not be loaded ($($_.Exception.Message)), so installation could not be verified. Refusing rather than guessing." } |
        ConvertTo-Json -Compress)
    exit 1
}

$r = Test-EvidencePrePushHookInstalled -Root $RepoRoot -DeciderPath $DeciderPath
($r | ConvertTo-Json -Compress)
exit $(if ($r.installed) { 0 } else { 1 })
