#Requires -Version 5.1
<#
.SYNOPSIS
  emit-mission-event -- ONE mission-event line, appended by Write-MissionEvent, for a caller that is not
  PowerShell (UI-1 S1; LM2-ADR-045; expanded-schemas SS14).

.DESCRIPTION
  ONE WRITER, ONE LOCK. The feed's seq is allocated under a named mutex the emitter holds, so a second emitter
  in another language would be a second writer with a second lock. A Python verb (tools/lam/commit_ledger.py)
  therefore never writes the feed: it runs THIS file as a subprocess, and this file dot-sources the
  next-generation hooks' library and calls Write-MissionEvent -- the same function every hook and verb calls.

  THE FIELDS ARE ARGUMENTS, typed, one per token after the named parameters -- never a JSON string, which does
  not survive Windows command-line quoting intact:
      int:<name>=<integer>    str:<name>=<text>    bool:<name>=true|false    null:<name>
  in the order the payload carries them.

  NEVER FAILS ITS CALLER. It prints nothing and always exits 0. A failed append is recorded by Write-MissionEvent
  in the evidence plane's hook-errors.log, as SS14 prescribes; a malformed token is recorded there the same way
  and no line is written. A checkout that is not a telemetry stream writes nothing and records nothing.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\emit-mission-event.ps1 -Root <checkout> `
      -Kind ledger_row -SourcePath <ledger> -Hook commit-ledger int:entry=7 null:row str:type=commit
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Kind,
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [string]$Hook = 'verb',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Field = @()
)

try {
    $lib = Join-Path $PSScriptRoot '..\evidence-hooks-next\hooks\lib\evidence-common.ps1'
    if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) { exit 0 }
    . $lib
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $payload = [ordered]@{}
    $bad = @()
    foreach ($tok in @($Field)) {
        $m = [regex]::Match([string]$tok, '^(int|str|bool|null):([A-Za-z_][A-Za-z0-9_]*)(?:=(.*))?$', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $v = $null
        if (-not $m.Success) { $bad += [string]$tok; continue }
        $type = $m.Groups[1].Value; $name = $m.Groups[2].Value; $has = $m.Groups[3].Success; $raw = $m.Groups[3].Value
        if ($type -eq 'null') { if ($has) { $bad += [string]$tok; continue } }
        elseif (-not $has) { $bad += [string]$tok; continue }
        elseif ($type -eq 'int') { $n = [int64]0; if (-not [int64]::TryParse($raw, [ref]$n)) { $bad += [string]$tok; continue }; $v = $n }
        elseif ($type -eq 'bool') { if ($raw -ceq 'true') { $v = $true } elseif ($raw -ceq 'false') { $v = $false } else { $bad += [string]$tok; continue } }
        else { $v = $raw }
        $payload[$name] = $v
    }
    if ($bad.Count -gt 0) {
        if (Test-MissionTelemetryStream -Root $rootFull) {
            Write-MissionTelemetryError -Root $rootFull -Hook $Hook -Message ("telemetry: a '$Kind' line was not written to .mission-runtime/telemetry/events.jsonl: emit-mission-event.ps1 was handed field token(s) it cannot read (" + ($bad -join ' ') + ")")
        }
    } else {
        $null = Write-MissionEvent -Root $rootFull -Kind $Kind -Payload $payload -SourcePath $SourcePath -Hook $Hook
    }
} catch { }
exit 0
