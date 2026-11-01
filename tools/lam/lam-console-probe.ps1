#Requires -Version 5.1

<#
.SYNOPSIS
  The operator's credential probe: drive lam-console.ps1's SECURE-DESKTOP credential prompt WITHOUT
  MINTING ANYTHING.

.DESCRIPTION
  WHY IT EXISTS. The operator's first real drive of lam-console.ps1's confirm step (2026-09-16T13:48Z,
  approve -Kind push) died of System.AccessViolationException inside CredUIPromptForWindowsCredentials,
  before any prompt was displayed; nothing was written. The helper had passed no CREDUI_INFO. That is
  fixed in lam-console.ps1 (Initialize-LamConsoleCredType) and measured not to fault on a no-UI drive,
  but NO AGENT SESSION HAS RAISED OR COMPLETED THE SECURE PROMPT, and none may: the prompt would land on
  the operator's screen. This probe lets the operator drive exactly that prompt on its own, before the
  next real gate act, with nothing at stake.

  WHAT IT CALLS. It dot-sources tools\lam\lam-console.ps1 in LIBRARY MODE (which defines the console's
  functions and does NOT run the console's flow), calls Initialize-LamConsoleCredType to compile the
  LamConsoleCred helper, and then calls ONE method that reaches a credential:
  LamConsoleCred.PromptSecureDesktop -- CredUIPromptForWindowsCredentialsW with a CREDUI_INFO whose
  caption and message are fixed text, no incoming buffer, and dwFlags CREDUIWIN_SECURE_PROMPT (0x1000)
  only. That is the same call the console's default confirm provider makes.

  WHAT IT NEVER DOES. It never composes a gate act, never mints or registers a token, never calls
  VerifyIsCurrentUser or LsaLogonUser, never calls mission-gate.ps1 or any gate act, never writes an
  attestation line, writes nothing to disk and sets no environment variable. IT NEVER SHOWS THE
  CREDENTIAL: of the packed authentication buffer it reports only the LENGTH, beside the authentication
  package number CredUI reported. No byte of the buffer, in any rendering, reaches output, a file, a
  variable that outlives the call or the environment, and the buffer is zeroed in a finally before the
  probe returns, whatever happened. It never CHECKS the credential either: a wrong password still
  collects, because only LsaLogonUser would test it, and the probe never calls LsaLogonUser.

  WHERE TO RUN IT. Your own interactive PowerShell terminal -- not an agent session, a hook or a runner
  -- from the checkout you will mint from.

  OUTPUT, EXACTLY THESE LINES IN THIS ORDER:
    lam-console-probe: PROBE ONLY -- calls LamConsoleCred.PromptSecureDesktop and nothing else: ...
    lam-console-probe: lam-console.ps1 <absolute path> sha256 <64 hex> (<n> bytes)
    lam-console-probe: process 64-bit <True|False>; CREDUI_INFO marshalled size <n> bytes; dwFlags 0x<8 hex>
    lam-console-probe: raising the SECURE-DESKTOP credential prompt now -- ...
    LAMPROBE collected=<true|false> rc=<decimal> packed_length=<n> auth_package=<n> reason=<reason>
  collected, rc, auth_package and reason are what PromptSecureDesktop returned; packed_length is the
  length of the buffer it returned (0 when none); reason is printed through lam-console.ps1's visible-byte
  rendering (Format-LamConsoleVisibleText). The sha256 is lower-case hex over the file's bytes as read,
  before it is loaded. A refusal before the prompt prints ONE line instead of all five, and no LAMPROBE
  line:
    lam-console-probe: REFUSED before any prompt -- <why>.

  EXIT CODES.
    0  collected: PromptSecureDesktop returned true, rc 0 and a non-empty buffer.
    1  cancelled: rc 1223 (ERROR_CANCELLED).
    2  refused before any prompt: no interactive console ([Console]::KeyAvailable throws or
       [Console]::IsInputRedirected is true -- the default confirm provider's own test), lam-console.ps1
       absent or not loadable, or the LamConsoleCred helper would not compile or lacks the contract.
    3  the prompt failed otherwise: any other rc, rc 4294967295 (LamConsoleCred.PromptFaulted -- a native
       exception caught at the P/Invoke boundary, its type named in the reason), an empty buffer, or a
       prompt call that raised.

  LIBRARY MODE AND THE ONE TEST SEAM. When this file is DOT-SOURCED ($MyInvocation.InvocationName -eq '.')
  it defines its functions and does NOT prompt. $script:LamConsoleProbePrompt is the one seam: a
  scriptblock that, by default, makes the real PromptSecureDesktop call and returns
  @{ collected; packed; authPackage; reason; rc }. Invoke-LamConsoleProbe calls it; an instrument (WP-4
  T-29) replaces it in process after dot-sourcing. No environment variable, switch or file selects it.
  Invoke-LamConsoleProbe returns @{ exit; lines } and writes the lines to the host; when this file is
  invoked rather than dot-sourced, the main block runs it and exits with its code.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\lam-console-probe.ps1
  $LASTEXITCODE

  From the root of the checkout you will mint from, at your own interactive terminal. Run it once and
  press Cancel on the secure prompt (expect exit 1, rc=1223), then once entering your own credential
  (expect exit 0, packed_length above 0), and only then drive lam-console.ps1 for real (LAM-INSTALL
  section 5.6.3).
#>
[CmdletBinding()]
param()

# THE ONE TEST SEAM. By default: the real prompt call, and nothing else. Every variable name in this file
# avoids lam-console.ps1's parameter names (Command, Kind, Id, Binds, MissionRoot, TipSha, OriginUrl,
# RemoteRef, Reason, ExpiresMinutes, ComposedAt, Ruling): Invoke-LamConsoleProbe dot-sources that file,
# which binds those names into its scope, and PowerShell 5.1 folds variable-name case.
$script:LamConsoleProbePrompt = {
    $promptPacked = $null
    $promptPackage = [uint32]0
    $promptWhy = ''
    $promptRc = [uint32]0
    $promptCollected = [LamConsoleCred]::PromptSecureDesktop([ref]$promptPacked, [ref]$promptPackage, [ref]$promptWhy, [ref]$promptRc)
    return @{ collected = [bool]$promptCollected; packed = $promptPacked; authPackage = $promptPackage; reason = $promptWhy; rc = $promptRc }
}

function New-LamConsoleProbeRefusal {
    # ONE line, exit 2, and nothing else: no LAMPROBE line, because no prompt was raised. The reason is
    # reduced to printable ASCII here because a refusal can come before lam-console.ps1 is loaded.
    param([string]$Why)
    $refusalText = 'lam-console-probe: REFUSED before any prompt -- ' + ($Why -replace '[^\x20-\x7E]', '?').TrimEnd('.') + '.'
    Write-Host $refusalText
    return @{ exit = 2; lines = [string[]]@($refusalText) }
}

function Write-LamConsoleProbeLine {
    param($Sink, [string]$Text)
    Write-Host $Text
    $Sink.Add($Text)
}

function Clear-LamConsoleProbeBuffer {
    # ZERO EVERY BUFFER THE PROMPT CALL HANDED BACK, IN PLACE, and drop the dictionary's reference to it.
    # In place matters: the zeroing must reach every other reference to the same array.
    param($Items)
    foreach ($clearItem in @($Items)) {
        if ($clearItem -is [System.Collections.IDictionary]) {
            if ($clearItem.Contains('packed')) {
                $clearHeld = $clearItem['packed']
                if ($clearHeld -is [byte[]]) { [Array]::Clear($clearHeld, 0, $clearHeld.Length) }
                $clearHeld = $null
                $clearItem['packed'] = $null
            }
        } elseif ($clearItem -is [byte[]]) {
            [Array]::Clear($clearItem, 0, $clearItem.Length)
        }
    }
}

function Invoke-LamConsoleProbe {
    <#
      THE PROBE. Returns @{ exit; lines } and writes every line to the host as it is produced, so the
      operator sees the raising line BEFORE the prompt appears. See the file header for the lines, the
      exit codes and the seam.
    #>
    [CmdletBinding()]
    param()
    $ErrorActionPreference = 'Stop'
    $probeLines = New-Object System.Collections.Generic.List[string]

    # (1) NO INTERACTIVE CONSOLE -> REFUSED before anything is read, loaded, compiled or called. The
    #     default confirm provider's own test: a redirected stdin, or a host with no console at all.
    $probeHasConsole = $true
    try { $null = [Console]::KeyAvailable } catch { $probeHasConsole = $false }
    try { if ([Console]::IsInputRedirected) { $probeHasConsole = $false } } catch { $probeHasConsole = $false }
    if (-not $probeHasConsole) {
        return (New-LamConsoleProbeRefusal -Why 'no interactive console ([Console]::KeyAvailable threw or [Console]::IsInputRedirected is True), so the secure-desktop prompt is not raised from here; run the probe in your own interactive terminal')
    }

    $probeLibPath = ''
    $probeLibSha = ''
    $probeLibLength = 0
    $probeFlags = [uint32]0
    $probeFaulted = [int64]0
    $probeInfoSize = 0
    try {
        # (2) lam-console.ps1 BESIDE THIS FILE, its identity measured from its bytes before it is loaded.
        $probeLibPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'lam-console.ps1'))
        if (-not (Test-Path -LiteralPath $probeLibPath -PathType Leaf)) {
            return (New-LamConsoleProbeRefusal -Why ('lam-console.ps1 is absent: ' + $probeLibPath))
        }
        try {
            $probeLibBytes = [System.IO.File]::ReadAllBytes($probeLibPath)
            $probeHasher = [System.Security.Cryptography.SHA256]::Create()
            try { $probeLibSha = ([BitConverter]::ToString($probeHasher.ComputeHash($probeLibBytes))).Replace('-', '').ToLowerInvariant() }
            finally { $probeHasher.Dispose() }
            $probeLibLength = $probeLibBytes.Length
            $probeLibBytes = $null
        } catch {
            return (New-LamConsoleProbeRefusal -Why ('lam-console.ps1 could not be read: ' + $_.Exception.GetType().FullName))
        }

        # (3) LIBRARY MODE: the console's functions, without its flow.
        try {
            . (Join-Path $PSScriptRoot 'lam-console.ps1')
        } catch {
            return (New-LamConsoleProbeRefusal -Why ('lam-console.ps1 could not be loaded in library mode: ' + $_.Exception.GetType().FullName))
        }
        $probeHasInit = $null -ne (Get-Command -Name 'Initialize-LamConsoleCredType' -CommandType Function -ErrorAction SilentlyContinue)
        $probeHasVisible = $null -ne (Get-Command -Name 'Format-LamConsoleVisibleText' -CommandType Function -ErrorAction SilentlyContinue)
        if (-not ($probeHasInit -and $probeHasVisible)) {
            return (New-LamConsoleProbeRefusal -Why 'lam-console.ps1 did not define Initialize-LamConsoleCredType and Format-LamConsoleVisibleText')
        }

        # (4) COMPILE THE HELPER, and require the contract this probe prints and calls.
        try {
            Initialize-LamConsoleCredType
        } catch {
            return (New-LamConsoleProbeRefusal -Why ('the LamConsoleCred helper would not compile: ' + (Format-LamConsoleVisibleText -Text ([string]$_.Exception.Message))))
        }
        $probeType = 'LamConsoleCred' -as [type]
        $probeOutTypes = [type[]]@([byte[]].MakeByRefType(), [uint32].MakeByRefType(), [string].MakeByRefType(), [uint32].MakeByRefType())
        $probeContract = ($null -ne $probeType) -and ($null -ne $probeType.GetMethod('PromptSecureDesktop', $probeOutTypes)) -and
                         ($null -ne $probeType.GetField('PromptFlags')) -and ($null -ne $probeType.GetField('PromptFaulted')) -and
                         ($null -ne $probeType.GetProperty('CredUiInfoSize'))
        if (-not $probeContract) {
            return (New-LamConsoleProbeRefusal -Why 'the LamConsoleCred helper in this process does not carry PromptSecureDesktop(out packed, out authPackage, out reason, out rc), PromptFlags, PromptFaulted and CredUiInfoSize')
        }
        $probeFlags = [uint32][LamConsoleCred]::PromptFlags
        $probeFaulted = [int64][LamConsoleCred]::PromptFaulted
        $probeInfoSize = [int][LamConsoleCred]::CredUiInfoSize
    } catch {
        return (New-LamConsoleProbeRefusal -Why ('the probe could not prepare the prompt: ' + $_.Exception.GetType().FullName))
    }

    Write-LamConsoleProbeLine -Sink $probeLines -Text 'lam-console-probe: PROBE ONLY -- calls LamConsoleCred.PromptSecureDesktop and nothing else: no compose, no token, no LsaLogonUser, no gate, no attestation line, nothing written.'
    Write-LamConsoleProbeLine -Sink $probeLines -Text ('lam-console-probe: lam-console.ps1 {0} sha256 {1} ({2} bytes)' -f (Format-LamConsoleVisibleText -Text $probeLibPath), $probeLibSha, $probeLibLength)
    Write-LamConsoleProbeLine -Sink $probeLines -Text ('lam-console-probe: process 64-bit {0}; CREDUI_INFO marshalled size {1} bytes; dwFlags 0x{2:X8}' -f [Environment]::Is64BitProcess, $probeInfoSize, $probeFlags)
    Write-LamConsoleProbeLine -Sink $probeLines -Text 'lam-console-probe: raising the SECURE-DESKTOP credential prompt now -- enter your own credential to test collection, or press Cancel.'

    # (5) THE PROMPT, THROUGH THE SEAM. Only the buffer's LENGTH leaves this block; the buffer itself is
    #     zeroed in the finally, whatever happened.
    $probeRaw = @()
    try {
        $probeCollected = $false
        $probeRc = $probeFaulted
        $probeLength = 0
        $probePackage = [int64]0
        $probeWhy = ''
        try {
            $probeRaw = @(& $script:LamConsoleProbePrompt)
            $probeOne = @($probeRaw | Where-Object { $_ -is [System.Collections.IDictionary] })
            if (($probeRaw.Count -eq 1) -and ($probeOne.Count -eq 1)) {
                $probeCollected = [bool]$probeOne[0]['collected']
                $probeRc = [int64]$probeOne[0]['rc']
                $probePackage = [int64]$probeOne[0]['authPackage']
                $probeWhy = [string]$probeOne[0]['reason']
                if ($probeOne[0]['packed'] -is [byte[]]) { $probeLength = $probeOne[0]['packed'].Length }
            } else {
                $probeWhy = ('the prompt call returned {0} results, not one dictionary' -f $probeRaw.Count)
            }
            $probeOne = $null
        } catch {
            $probeCollected = $false
            $probeRc = $probeFaulted
            $probeLength = 0
            $probePackage = [int64]0
            $probeWhy = ('the prompt call raised {0}: {1}' -f $_.Exception.GetType().FullName, $_.Exception.Message)
        }
        $probeExit = 3
        if ($probeCollected -and ($probeRc -eq 0) -and ($probeLength -gt 0)) { $probeExit = 0 }
        elseif ((-not $probeCollected) -and ($probeRc -eq 1223)) { $probeExit = 1 }
        $probeCollectedText = 'false'
        if ($probeCollected) { $probeCollectedText = 'true' }
        Write-LamConsoleProbeLine -Sink $probeLines -Text ('LAMPROBE collected={0} rc={1} packed_length={2} auth_package={3} reason={4}' -f `
            $probeCollectedText, $probeRc, $probeLength, $probePackage, (Format-LamConsoleVisibleText -Text $probeWhy))
        return @{ exit = $probeExit; lines = $probeLines.ToArray() }
    } finally {
        Clear-LamConsoleProbeBuffer -Items $probeRaw
        $probeRaw = $null
    }
}

# =================================================================================================
# MAIN. Runs only when this file is INVOKED, never when it is dot-sourced (library mode).
# =================================================================================================
if ($MyInvocation.InvocationName -ne '.') {
    $probeMainExit = 3
    try {
        foreach ($probeMainItem in @(Invoke-LamConsoleProbe)) {
            if (($probeMainItem -is [System.Collections.IDictionary]) -and $probeMainItem.Contains('exit')) { $probeMainExit = [int]$probeMainItem['exit'] }
        }
    } catch {
        Write-Host ('lam-console-probe: FAILED -- the probe itself raised ' + $_.Exception.GetType().FullName + '; record this run as a failed prompt (exit 3).')
        $probeMainExit = 3
    }
    exit $probeMainExit
}
