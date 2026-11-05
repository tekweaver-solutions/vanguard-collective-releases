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
    $a1Exit = $LASTEXITCODE

    # THE MISSION-EVENT FEED (UI-1 S1): compact, after A1 has snapshotted the transcript. transcript_sha256
    # is the hash of the transcript the harness named; source_path is A1's snapshot of it inside the
    # checkout (a transcript lives outside the repository, and a source_path is repo-relative), else the
    # dispatch's log. The forwarding above is unchanged; this addition never changes the hook's exit code.
    try {
        . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
        $pc = $null
        try { if ($stdin -and $stdin.Trim()) { $pc = $stdin | ConvertFrom-Json } } catch { $pc = $null }
        $sid = ''; $tp = ''
        if ($null -ne $pc) { $sid = [string](Get-HookField $pc 'session_id' ''); $tp = [string](Get-HookField $pc 'transcript_path' '') }
        $root = Get-EvidenceRepoRoot
        $did = Get-EvidenceDispatchId -SessionId $sid
        $rt = Get-EvidenceRuntimeDir -Root $root -DispatchId $did
        $trSha = $null
        if ($tp -and (Test-Path -LiteralPath $tp -PathType Leaf)) { $trSha = Get-Sha256OfFile -Path $tp }
        if ($trSha) {
            $src = Join-Path $rt 'log.jsonl'
            $snapDir = Join-Path $rt 'transcripts'
            if (Test-Path -LiteralPath $snapDir) {
                foreach ($sn in @(Get-ChildItem -LiteralPath $snapDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)) {
                    if ((Get-Sha256OfFile -Path $sn.FullName) -eq $trSha) { $src = $sn.FullName; break }
                }
            }
            $null = Write-MissionEvent -Root $root -Kind 'compact' -SourcePath $src -Hook 'PreCompact' -SessionId $sid -DispatchId $did `
                        -Payload ([ordered]@{ session_id = $sid; transcript_sha256 = $trSha })
        } elseif (Test-MissionTelemetryStream -Root $root) {
            Write-MissionTelemetryError -Root $root -Hook 'PreCompact' -SessionId $sid -DispatchId $did `
                -Message "telemetry: no compact line was appended to .mission-runtime/telemetry/events.jsonl -- the payload named no readable transcript ('$tp'), so there is no transcript_sha256"
        }
    } catch { }
    exit $a1Exit
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
