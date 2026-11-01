#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next PreCompact hook -- NO DELTA. Forwards to the sealed A1 hook.

.DESCRIPTION
  WP-1 changes nothing about transcript snapshotting, so this generation adds nothing to it. The
  honest way to say that in code is to run A1's hook rather than to copy its body: a copy would
  be a second implementation to keep in step, and the first time the two drifted the drift would
  be silent.

  The payload is read from stdin and piped through unchanged. A1's hook then dot-sources A1's
  library, which is correct here precisely because there is no delta to apply.

  ARCHITECTURAL NOTE, stated because it is load-bearing for WP-6. These hooks run from
  tools/evidence-hooks-next/ and reach A1 by relative path within the host checkout. The smoke repo
  registers them by absolute path (LAM-ACCEPT WP-1: "built in a staging path ... registered only
  in the smoke repo's own .claude/settings.local.json, where they are exercised live"), so the
  staging tree is the deployment unit and this reference resolves for the smoke repo too. Nothing
  in tools/framework/** is written, moved, or re-hashed -- it is executed in place, exactly as
  A1's own registration executes it.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $stdin = [Console]::In.ReadToEnd()
    # tools/evidence-hooks-next/hooks -> up two -> tools
    $a1 = Join-Path $PSScriptRoot '..\..\framework\hooks\evidence-pre-compact.ps1'
    if (-not (Test-Path -LiteralPath $a1)) {
        throw "evidence-hooks-next: the A1 PreCompact hook is not at $a1"
    }
    $stdin | & powershell -NoProfile -ExecutionPolicy Bypass -File $a1
    exit $LASTEXITCODE
}
catch {
    # Same doctrine as A1: a thrown PreCompact must not wedge the session. The error is recorded
    # where Get-EvidenceState will point a reader at it, and the hook exits 0.
    try {
        . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
        Write-EvidenceHookError -Hook 'PreCompact' -Message $_.Exception.Message
    } catch { }
    exit 0
}
