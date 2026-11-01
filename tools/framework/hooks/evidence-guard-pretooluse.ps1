#Requires -Version 5.1
<#
.SYNOPSIS
  PreToolUse hook -- ACCIDENT TRIPWIRE over evidence paths and the evidence machinery.
  (A1; cured twice and re-scoped; F1/F2 cured under the re-scope;
  denial recording added by cure D8)

  The governing scope: this is NOT a boundary. Fresh-identity validators found several
  different ways past it, each after a correct cure for the last. The guard raises the cost of an
  ACCIDENTAL write; an agent that wants in gets in. What it retains after the descope: canonical
  path matching, the destructive-parent tier, repo-wide destructive detection, a metacharacter
  gate ahead of every exemption, and ONE Bash allow-side exemption -- the design SS4.1 evidence
  ceremony. The read-verb exemption that used to sit beside it is DELETED: Bash
  naming protected territory denies, reads included. Reads go through the file tools, which is a
  separate structural allow and is disclosed as such.

  CURE D8 -- THE GUARD RECORDS WHAT IT REFUSES, AND THE SCOPING IS NOT
  SILENTLY PROMOTED. Pre-cure, a denied call produced no PostToolUse, no entry, no hook error
  and no seq gap: what the guard refused existed nowhere in the evidence plane (E5-iii).
  Every deny path now writes a '_denied' record into the dispatch's append-only log
  via Write-EvidenceDeniedRecord BEFORE exiting 2. STATED PLAINLY, PER THE OPERATOR RULING:
  recording a denial changes what the guard OBSERVES, not what it PREVENTS. The
  tripwire-not-boundary ruling stands unamended -- enforcement logic, matcher reach
  and the allow/deny decisions are byte-for-byte unchanged by this cure, and a future reader
  must not infer from "the guard now records" that the guard now guarantees. Denials occur
  only where the guard fires, so the record is complete for the E5-iii member BY CONSTRUCTION;
  a call outside the matcher cannot BE a guard denial. FAILURE DIRECTION, FIXED: a
  record-write failure lands in hook-errors.log and THE DENY STILL FIRES -- the recorder fails
  toward denial-without-record, never toward allow.

.DESCRIPTION
  Citation convention: LM2-ADR-0NN / "design SS<n>" denote
  docs/framework/vanguard-collective-local-modes-v2.1.md. Bare ADR-0NN denotes the on-disk
  file under tools/mission-cli/config/.

  Design SS4.1 layer (c): "PreToolUse deny rules on evidence paths as defense-in-depth for
  topologies where mount exclusion is unavailable."

  On THIS host that is not defense-in-depth -- it is close to the whole defense. Layer (a)
  (mount exclusion) does not exist for sessions running natively on Windows: there is no
  container and therefore no mount boundary. See
  docs/framework/evidence-write-path-threat-notes.md, erratum E1.

  CURE B3. Paths are CANONICALIZED before matching (`/./` and `//` collapsed, `..` resolved
  per token). The pre-cure version normalized separators only, so
  `.mission-runtime/./evidence/x`, `//`, and `zz/../evidence/x` were all ALLOWED while
  reaching the same file. Those spellings were demonstrated writing to a guarded file.

  CURE B4. The protected set now includes `tools/framework/hooks` and `.claude/settings.json`
  -- the machinery is evidence infrastructure. Editing the PostToolUse hook is worse than
  editing the log: the log keeps being written, looks structurally perfect, and is under the
  agent's control.

  WHAT SELF-PROTECTION IS AND IS NOT. This is still layer (c), enforced by the component it
  protects. It is circular by construction. If the guard does not fire -- a tool outside the
  fragment's matcher, hooks removed from settings, a helper script written earlier and merely
  executed now, a path built from variables at runtime -- nothing here applies. The cure
  raises cost. It is not a boundary. Only layers (a)/(b) make the path unreachable.

  CURE N-a. FAIL CLOSED now matches the code. An unparsable or empty payload DENIES. Before
  the cure, Read-HookStdin's tolerant parse meant the catch never fired for a bad payload:
  tool_input came back null, the candidate list was empty, and the guard ALLOWED -- the exact
  silent permission the docstring promised never happened.

  DUAL DENY SIGNAL. A deny emits BOTH hookSpecificOutput.permissionDecision=deny on stdout AND
  exit code 2, so a harness honouring either contract refuses.

  CURE F-6 (rides the D8 move). The deny wrapper appends
  ". " to a library reason; a reason already ending in a period produced a doubled period in
  the emitted text. The wrapper now trims a trailing period from the reason before composing.
  Reason SEMANTICS are unchanged.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Context for the denial recorder (cure D8). Populated as the payload is read; a fail-closed
# deny that fires before the payload parses records with whatever is known at that point --
# a record with an empty session_id under the resolvable dispatch id beats no record at all.
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
    # CURE D8: record the refusal. OBSERVATION ONLY -- the deny below fires whether or not
    # this write lands (tripwire scoping unamended; fail toward denial-without-record).
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

    # CURE N-a -- fail closed on a payload we cannot read.
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

    # The decision logic lives in the library (Get-EvidenceGuardDecision) so it can be driven
    # directly by the acceptance test without spawning a process per case -- 40+ cases per run
    # otherwise, and a guard whose test is too slow to be thorough gets a thin test.
    $d = Get-EvidenceGuardDecision -ToolName $toolName -ToolInput $toolInput

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
