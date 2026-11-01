#Requires -Version 5.1
<#
.SYNOPSIS
  evidence-hooks-next PreToolUse guard -- A1's guard, bound to the next-gen library.

.DESCRIPTION
  THE DECISION LOGIC IS UNCHANGED. Every allow/deny in this file is A1's, reached through
  Get-EvidenceGuardDecision. What differs is which library that name resolves to: this hook
  dot-sources tools/evidence-hooks-next/hooks/lib/evidence-common.ps1, whose delta

    (a) denies the two dispatch-boundary markers by name before delegating to A1's decision, and
    (b) writes `outcome: denied` on the '_denied' record.

  THE STANDING RULE STILL GOVERNS AND IS NOT WEAKENED BY EITHER. This is a tripwire, not a boundary. The
  marker rule raises the cost of a worker forging its own dispatch boundary; it does not make the
  path unreachable, and no reader should infer from "the guard now names the markers" that the
  guard now guarantees them. Recording a denial changes what the guard OBSERVES, not what it
  PREVENTS -- the operator ruling carried forward verbatim in substance.

  FAILURE DIRECTION, unchanged from A1: a record-write failure lands in hook-errors.log and THE
  DENY STILL FIRES. The recorder fails toward denial-without-record, never toward allow.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$script:DenySessionId = ''
$script:DenyToolName  = ''
$script:DenyToolInput = $null

function Write-Decision {
    param([string]$Decision, [string]$Reason)
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $Decision
            permissionDecisionReason = $Reason
        }
    }
    Write-Output ($out | ConvertTo-Json -Compress -Depth 6)
}

function Deny {
    param([string]$Reason)
    Write-Decision -Decision 'deny' -Reason $Reason
    try {
        Write-EvidenceDeniedRecord -SessionId $script:DenySessionId -ToolName $script:DenyToolName `
                                   -ToolInput $script:DenyToolInput -Reason $Reason
    }
    catch {
        try { Write-EvidenceHookError -Hook 'PreToolUse' -SessionId $script:DenySessionId `
                -Message "denial record failed: $($_.Exception.Message) -- the deny itself still fired" } catch { }
    }
    [Console]::Error.WriteLine($Reason)
    exit 2
}

try {
    . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')

    $payload = Read-HookStdin

    # CURE (a review finding), carried: fail closed on a payload the guard cannot read.
    if ($null -eq $payload) {
        Deny ("DENIED by evidence-guard (fail-closed): the hook payload resolved to null, so " +
              "the guard cannot determine what this tool call touches.")
    }
    if ((Get-HookField $payload '_unparsable' $false)) {
        Deny ("DENIED by evidence-guard (fail-closed): the hook payload was not parsable JSON, " +
              "so the guard cannot determine what this tool call touches. A guard that allows " +
              "when it cannot see is not a guard.")
    }
    if ((Get-HookField $payload '_empty' $false)) {
        Deny ("DENIED by evidence-guard (fail-closed): the hook payload was empty, so the guard " +
              "cannot determine what this tool call touches.")
    }

    $script:DenySessionId = [string](Get-HookField $payload 'session_id' '')
    $toolName  = [string](Get-HookField $payload 'tool_name' '')
    $toolInput = Get-HookField $payload 'tool_input' $null
    $script:DenyToolName  = $toolName
    $script:DenyToolInput = $toolInput

    # THE PAYLOAD'S cwd IS EVIDENCE AND WAS BEING THROWN AWAY (V-1 round 5, WP-4 residual). The
    # guard judged command TEXT alone, so `cd .mission` / `cd gates` / `echo x > y.yaml` passed at
    # every step -- no protected path appears in any one of those commands, and the Bash tool's
    # working directory persists between calls. Handed the cwd, the third command's relative token
    # resolves to the gates directory and is denied.
    $d = Get-EvidenceGuardDecision -ToolName $toolName -ToolInput $toolInput `
                                   -Cwd ([string](Get-HookField $payload 'cwd' ''))

    if ($d.decision -eq 'deny') {
        $reasonCore = ([string]$d.reason).TrimEnd('.')
        Deny ("DENIED by evidence-guard (design SS4.1 layer c): $reasonCore. " +
              "The evidence plane is written only by harness-side hooks; an agent-writable " +
              "evidence store launders testimony as evidence, and agent-editable machinery is " +
              "worse still. If this is legitimate harness work, run it outside the session.")
    }

    Write-Decision -Decision 'allow' -Reason $d.reason
    exit 0
}
catch {
    $reason = "DENIED by evidence-guard (fail-closed): guard error -- $($_.Exception.Message). " +
              "A guard that allows when broken is not a guard; design SS6 halts mutation-bearing " +
              "dispatches on hook failure."
    try { Write-Decision -Decision 'deny' -Reason $reason } catch { }
    try {
        Write-EvidenceDeniedRecord -SessionId $script:DenySessionId -ToolName $script:DenyToolName `
                                   -ToolInput $script:DenyToolInput -Reason $reason
    }
    catch {
        try { Write-EvidenceHookError -Hook 'PreToolUse' -SessionId $script:DenySessionId `
                -Message "denial record failed in guard-error path: $($_.Exception.Message)" } catch { }
    }
    [Console]::Error.WriteLine($reason)
    exit 2
}
