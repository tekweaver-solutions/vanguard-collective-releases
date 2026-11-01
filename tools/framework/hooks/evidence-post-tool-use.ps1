#Requires -Version 5.1
<#
.SYNOPSIS
  PostToolUse hook -- append one evidence entry per tool call. (A1)

.DESCRIPTION
  Citation convention: LM2-ADR-0NN / "design SS<n>" denote
  docs/framework/vanguard-collective-local-modes-v2.1.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/.

  Design SS4.1: "PostToolUse appends {ts, session_id, dispatch_id, tool, command, exit_code,
  stdout, stderr} to an append-only evidence log ... written by the hook process -- the model
  never holds the pen."

  Layout per dispatch, under .mission-runtime/evidence/<dispatch_id>/:
    log.jsonl              append-only, one entry per tool call
    streams/<seq>.json     the FULL stdout/stderr bytes for that entry

  The log line carries hashes computed over the FULL streams plus an inline excerpt capped at
  -InlineCap bytes; the untruncated bytes always live at the entry's `path`. Hashes are never
  computed over the truncated excerpt -- that would make the anchor unverifiable.

  Exit behaviour: this hook never fails a tool call. Capture errors are recorded to
  hook-errors.log in the dispatch directory and the hook exits 0. A capture gap is a
  detectable evidence gap (the runner sees missing seq numbers); a crashed session is not.
#>
[CmdletBinding()]
param(
    [int]$InlineCap = 8192
)

. (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

try {
    $payload   = Read-HookStdin
    $sessionId = [string](Get-HookField $payload 'session_id' '')
    $toolName  = [string](Get-HookField $payload 'tool_name' 'unknown')
    $toolInput = Get-HookField $payload 'tool_input' $null
    $toolResp  = Get-HookField $payload 'tool_response' $null

    $root       = Get-EvidenceRepoRoot
    $dispatchId = Get-EvidenceDispatchId -SessionId $sessionId
    $rt         = Get-EvidenceRuntimeDir -Root $root -DispatchId $dispatchId
    $logPath    = Join-Path $rt 'log.jsonl'
    $streamDir  = Join-Path $rt 'streams'
    if (-not (Test-Path -LiteralPath $streamDir)) { New-Item -ItemType Directory -Path $streamDir -Force | Out-Null }

    # `command` is the anchor-bearing field. Bash/PowerShell carry it directly; file tools
    # carry a path; everything else is serialised so nothing is silently dropped.
    $command = $null
    if ($null -ne $toolInput) {
        if ($toolInput.PSObject.Properties.Name -contains 'command')        { $command = [string]$toolInput.command }
        elseif ($toolInput.PSObject.Properties.Name -contains 'file_path')  { $command = "$toolName $($toolInput.file_path)" }
        elseif ($toolInput.PSObject.Properties.Name -contains 'pattern')    { $command = "$toolName $($toolInput.pattern)" }
        else { $command = ($toolInput | ConvertTo-Json -Compress -Depth 8) }
    }

    # Response shape varies by tool. Pull stdout/stderr/exit_code where present; otherwise
    # serialise the whole response as stdout so the bytes are captured either way.
    $stdout = ''; $stderr = ''; $exitCode = $null
    if ($null -ne $toolResp) {
        $names = $toolResp.PSObject.Properties.Name
        if ($names -contains 'stdout')    { $stdout   = [string]$toolResp.stdout }
        if ($names -contains 'stderr')    { $stderr   = [string]$toolResp.stderr }
        if ($names -contains 'exit_code') { $exitCode = $toolResp.exit_code }
        if ($names -contains 'exitCode')  { $exitCode = $toolResp.exitCode }
        if (-not $stdout -and -not $stderr) { $stdout = ($toolResp | ConvertTo-Json -Compress -Depth 8) }
    }

    # CURE B5: the @() wrap is load-bearing, not style. Under Set-StrictMode -Version Latest
    # (inherited from the dot-sourced library) a Where-Object pipeline yielding exactly ONE
    # object has no .Count and throws. The outer catch swallowed it and exited 0, so a dispatch
    # captured its FIRST tool call and silently discarded every one after it -- then finalized
    # as FINALIZED/consumable with entry_count=1. Missing evidence presented as complete
    # evidence, which is the precise failure this artifact exists to prevent. The sibling call
    # sites in evidence-pre-compact.ps1 and evidence-stop-finalize.ps1 already wrapped; this one
    # did not.
    #
    # CURE D11: the count below is now only the PROBE FLOOR, not the identity.
    # The pre-cure code took seq = (non-blank log lines) + 1, formed the stream filename from
    # it, and wrote with a plain overwrite -- so two hooks that both read length N both derived
    # N+1 and the second write silently destroyed the first payload while the manifest read
    # clean (driven; three instances on this repository's own residue, 1 ms, 16 ms and 18 ms
    # apart). The winning name now comes from New-EvidenceStreamFile's atomic CreateNew probe,
    # and THAT number is the entry's seq, its filename, and its log-line seq -- unique by
    # construction. A2's N-e resolution is falsified and reversed on the record.
    $startSeq = 1
    if (Test-Path -LiteralPath $logPath) {
        $startSeq = @([System.IO.File]::ReadAllLines($logPath) | Where-Object { $_.Trim() }).Count + 1
    }

    # Full bytes first, then the log line that points at them -- so a crash between the two
    # loses the pointer, never the evidence.
    $alloc = New-EvidenceStreamFile -StreamDir $streamDir -StartSeq $startSeq -Tool $toolName `
                                    -Stdout $stdout -Stderr $stderr
    $seq       = $alloc.seq
    $streamRel = $alloc.rel

    # CURE N-f: the cap is a BYTE budget. .Length counts UTF-16 code units, which diverges from
    # encoded size for any non-ASCII output -- the pre-cure code said "bytes" and measured
    # characters. Truncation never splits a surrogate pair.
    $stdoutTrunc = (Get-Utf8ByteCount $stdout) -gt $InlineCap
    $stderrTrunc = (Get-Utf8ByteCount $stderr) -gt $InlineCap

    $entry = [ordered]@{
        ts                = Get-UtcStampZ
        session_id        = $sessionId
        dispatch_id       = $dispatchId
        seq               = $seq
        tool              = $toolName
        command           = $command
        exit_code         = $exitCode
        stdout            = $(if ($stdoutTrunc) { Get-Utf8TruncatedString -Text $stdout -MaxBytes $InlineCap } else { $stdout })
        stderr            = $(if ($stderrTrunc) { Get-Utf8TruncatedString -Text $stderr -MaxBytes $InlineCap } else { $stderr })
        stdout_truncated  = $stdoutTrunc
        stderr_truncated  = $stderrTrunc
        stdout_sha256     = (Get-Sha256OfString $stdout)   # over FULL bytes, never the excerpt
        stderr_sha256     = (Get-Sha256OfString $stderr)   # over FULL bytes, never the excerpt
        path              = $streamRel
    }
    Add-EvidenceLogLine -LogPath $logPath -Entry $entry
    exit 0
}
catch {
    # CURE B5 (trail visibility): errors go to the PER-DISPATCH log -- the same path
    # Get-EvidenceState reads and the same one the finalizer commits. Previously this wrote to a
    # global log that nothing read and nothing committed, so the defect left no trace anywhere a
    # consumer looks.
    try { Write-EvidenceHookError -Hook 'PostToolUse' -Message $_.Exception.Message -SessionId $sessionId } catch { }
    exit 0
}
