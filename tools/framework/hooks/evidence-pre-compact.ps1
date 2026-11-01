#Requires -Version 5.1
<#
.SYNOPSIS
  PreCompact hook -- snapshot the transcript before compaction. (A1, AM-417)

.DESCRIPTION
  Citation convention (AM-417 PB2): LM2-ADR-0NN / "design SS<n>" denote
  docs/framework/vanguard-collective-local-modes-v2.1.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/.

  Design SS4.1: "PreCompact snapshots the full transcript into the evidence store before any
  compaction, so compaction never destroys replay material."

  Snapshots are numbered and never overwritten -- a session may compact many times, and the
  Nth snapshot is not a replacement for the (N-1)th. Each snapshot's sha256 is appended to
  the dispatch's append-only log as a `_precompact` entry, so a manifest built later carries
  the snapshot in its chain of custody rather than beside it.
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

try {
    $payload    = Read-HookStdin
    $sessionId  = [string](Get-HookField $payload 'session_id' '')
    $transcript = [string](Get-HookField $payload 'transcript_path' '')
    $trigger    = [string](Get-HookField $payload 'trigger' 'unknown')

    $root       = Get-EvidenceRepoRoot
    $dispatchId = Get-EvidenceDispatchId -SessionId $sessionId
    $rt         = Get-EvidenceRuntimeDir -Root $root -DispatchId $dispatchId
    $snapDir    = Join-Path $rt 'transcripts'
    if (-not (Test-Path -LiteralPath $snapDir)) { New-Item -ItemType Directory -Path $snapDir -Force | Out-Null }

    $n = (@(Get-ChildItem -LiteralPath $snapDir -Filter 'precompact-*.jsonl' -ErrorAction SilentlyContinue)).Count + 1
    $snapRel  = "transcripts/precompact-{0:d3}.jsonl" -f $n
    $snapFull = Join-Path $snapDir ("precompact-{0:d3}.jsonl" -f $n)

    $captured = $false
    $sha      = $null
    if ($transcript -and (Test-Path -LiteralPath $transcript)) {
        Copy-Item -LiteralPath $transcript -Destination $snapFull -Force
        $sha = Get-Sha256OfFile -Path $snapFull
        $captured = $true
    }

    Add-EvidenceLogLine -LogPath (Join-Path $rt 'log.jsonl') -Entry ([ordered]@{
        ts              = Get-UtcStampZ
        session_id      = $sessionId
        dispatch_id     = $dispatchId
        tool            = '_precompact'
        command         = "PreCompact trigger=$trigger source=$transcript"
        exit_code       = $(if ($captured) { 0 } else { 1 })
        transcript_sha256 = $sha
        captured        = $captured
        path            = $snapRel
    })
    exit 0
}
catch {
    # CURE B5 (trail visibility): per-dispatch log -- the path Get-EvidenceState reads and the
    # finalizer commits.
    try { Write-EvidenceHookError -Hook 'PreCompact' -Message $_.Exception.Message -SessionId $sessionId } catch { }
    exit 0
}
