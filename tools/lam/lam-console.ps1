#Requires -Version 5.1

# THE BLANK LINE ABOVE IS LOAD-BEARING (mission-gate.ps1's own header records
# the measurement): PowerShell 5.1 attaches comment-based help only when a BLANK line, not a comment,
# separates #Requires from the <# block. Do not close it up.

<#
.SYNOPSIS
  The operator console -- compose-and-confirm for every gate act (approve, reapprove, revoke).
  (Batch 4 item 1, STAGE 1.)

.DESCRIPTION
  THIS IS THE ONE WAY AN OPERATOR MINTS, RE-MINTS OR REVOKES A GATE, AND IT RUNS IN THE OPERATOR'S OWN
  TERMINAL. mission-gate.ps1's mutating verbs are admitted IF AND ONLY IF BOTH hold: none of the tool's
  four session conditions fires (LAM_DISPATCH, the harness session environment, non-interactivity, a
  hook invocation) AND the call carries this console's verified path -- a per-invocation token this
  console mints in process memory AFTER its confirm act succeeds, which the tool checks and which is
  NEVER WRITTEN TO DISK, an environment variable or a command line. Neither half admits on its own.
  Running mission-gate.ps1 approve/reapprove/revoke directly, by anyone, is refused; and running this
  console inside an agent session is refused too, by the session conditions, whatever the confirm act
  returned. In an operator's own terminal the conditions do not fire, so requiring both costs the
  operator nothing.

  THE FLOW, AND WHY EACH STEP IS THERE:
    ROOT     -- -MissionRoot is resolved to ONE absolute path first (Resolve-Path -LiteralPath, refused
                unless it is a directory), exactly as mission-gate.ps1 resolves it, and only that
                absolute path is used from then on: for compose, the preview, the binds re-derivation,
                the mint and the attestation. A relative root is never handed to a .NET file API,
                because .NET resolves against the PROCESS current directory while PowerShell cmdlets
                resolve against the PowerShell location, and the two differ whenever a script has
                called Set-Location (a review's finding -- an attestation line landed in the
                wrong tree that way, or was lost).
    COMPOSE  -- this console calls `mission-gate.ps1 -ComposeOnly` IN PROCESS (the call operator, so
                the tool's `exit` does not kill the console and the AppDomain is shared). Compose runs
                every refusal and composition step the real mint runs and WRITES NOTHING; it emits the
                exact bytes of every file the mint would write, the resolved binds path and its
                sha256, and ONE act digest over the ordered writes.
    PREVIEW  -- the console first prints WHERE the act lands (a re-review finding): the
                resolved absolute mission root and the absolute gates directory (<root>\.mission\gates,
                the directory mission-gate.ps1 writes every gate file into). Then it renders EVERY PLANNED
                WRITE IN FULL, WITH EVERY BYTE VISIBLE: the write's name and its ABSOLUTE TARGET PATH, each
                line of the write printed behind a fixed prefix, CR shown as <CR> and LF as <LF> (a printed
                line ends after its <LF>), and every other control byte, every non-ASCII byte, and '<'
                itself shown as <0xNN> -- so the rendering is unambiguous -- followed by the write's byte
                length and sha256. The root, the gates directory and every target path go through the same
                visible-byte rendering. A write whose name is not a plain file name (a path separator, a
                colon, a control byte or any other character Windows refuses in a file name) is REFUSED
                here, because its absolute target could not be shown truthfully as <gates>\<name>. Then
                the resolved binds path, the binds_sha256 the console RE-DERIVED ITSELF
                from that path (a FileStream with FileShare ReadWrite|Delete, the same read mission-gate
                uses, NOT Get-FileHash), and the act digest the console RE-DERIVED ITSELF from the bytes
                it just showed. If either re-derivation disagrees with the composed output, or a write's
                declared length disagrees with its bytes, it refuses here, before any credential is
                collected. The preview is printed to the console; nothing forces the operator to read
                it, and nothing stops it scrolling -- reading it is the operator's act.
    CONFIRM  -- ONE act behind ONE replaceable provider ($script:LamConsoleConfirmProvider): the
                default provider prints ONE announcement line (the verb, the gate name and the mission
                root, each through the preview's visible-byte rendering, because mission-gate.ps1 applies
                no character pattern to -Id for any kind but halt-ruling, whose -Id it refuses unless it
                matches its HALT id pattern -- a re-review finding), reads a single keystroke and then raises a
                SECURE-DESKTOP credential
                prompt (CredUIPromptForWindowsCredentialsW with a valid CREDUI_INFO and dwFlags
                CREDUIWIN_SECURE_PROMPT 0x1000 ONLY -- CREDUIWIN_ENUMERATE_CURRENT_USER 0x200 is no longer
                sent) and submits the
                credential to LsaLogonUser, requiring the resulting logon's SID to equal the operator's
                own. It fails closed on cancel, error, a native fault or a host with no console. THE
                OPERATOR'S FIRST DRIVE OF THAT DEFAULT PROVIDER (2026-09-16T13:48Z, approve -Kind push)
                FAULTED: System.AccessViolationException inside CredUIPromptForWindowsCredentials, before
                any prompt was displayed, nothing written. The root cause, measured in the batch 4
                session 3 lead's grounding, was the NULL pUiInfo the extern passed; the fix, and the one
                no-UI measurement of it, are in Initialize-LamConsoleCredType. NO SESSION HAS COMPLETED OR
                EVEN RAISED THE SECURE PROMPT, LsaLogonUser HAS STILL NEVER BEEN CALLED, AND THE
                OPERATOR'S SECOND DRIVE IS OWED (the probe first, tools\lam\lam-console-probe.ps1, built
                next). A native exception raised anywhere in a provider is refused at CONFIRM, naming
                its type (THE CONFIRM SEAM'S FAILURE PATH, below). The secure (Winlogon) desktop
                is isolated from the interactive session (measured: OpenDesktop('Winlogon',
                DESKTOP_READOBJECTS) from an agent session returns handle 0 / GetLastError 5
                ACCESS_DENIED).
    MINT     -- the console mints a 32-byte CSPRNG token (hex), registers it in process memory with
                the verb/kind/id, the ComposedAt and the previewed act digest, and calls
                `mission-gate.ps1 <verb> ... -ConsoleToken <token>` IN PROCESS. The tool evaluates its
                four session conditions (refusing, and spending the token, if any fires), re-derives the
                act digest from the bytes it is about to write, requires it to equal the previewed one,
                marks the token used BEFORE the first write, and mints. The registry entry is cleared
                afterwards whatever happened.
    ATTEST   -- one CONTENT-FREE line is appended to <resolved MissionRoot>\.mission-runtime\operator-acts.log
                in record-operator-prompt.ps1's form: a UTC timestamp, kind=gate-act, the verb, the
                gate id, the preview digest, the credential provider and the tool's exit code. Never
                the ruling text, never the token. IF THE LINE DOES NOT LAND it is REPORTED on the
                console and in the result (attested = false, with the reason); the tool's exit code
                already obtained is not changed by it.
                THIS LOG RECORDS CONSOLE ACTS, NOT MINTS (session validator,
                DRIVEN). This file is the only writer of that line -- mission-gate.ps1 never attests
                -- so a mint that does not run through this flow (in-process code in a console where
                the four session conditions do not fire: the residual stated below) leaves a real
                gate in <root>\.mission\gates and NO line at all, and the validator measured the log
                absent after such a mint. It is NOT an independent second record of a mint: a reader
                reconciles against the gates directory, never against this log, and an absent line
                means EITHER the console could not write it OR the mint never came through the
                console. Moving the attestation into mission-gate.ps1, so every mint attests whatever
                called it, is the candidate cure, is a design change nobody has ruled on, and is
                named here rather than taken.

  LIBRARY MODE. When this file is DOT-SOURCED it defines its functions and does NOT run the main
  flow, so an instrument can install a provider that returns success or failure without a prompt and
  drive Invoke-LamConsoleGateAct directly. Detection is $MyInvocation.InvocationName -eq '.'.

  THE ONE INJECTION SEAM. $script:LamConsoleConfirmProvider wraps the confirm act -- the keystroke
  AND the credential together, because a hidden instrument console cannot press a key. There is NO
  environment variable, switch or file that selects a provider: the seam is reachable only in
  process, in library mode, by code that has already dot-sourced this file. THE RESIDUAL THAT
  SENTENCE LEAVES, STATED: the in-process token registry and this seam are reachable to any code
  running in process in a console where the four session conditions do not fire -- and an agent can
  start such a console, by building a scrubbed console process tree (the WP-3/WP-4 instruments do
  exactly that, in the open, to drive this flow). The session conditions stop a console driven from
  inside an agent session; they do not stop that.

  THE CONFIRM SEAM'S FAILURE PATH. A real native access violation is NOT catchable
  by a PowerShell try/catch in 5.1: the process dies 0xC0000005, printing "Unhandled Exception:
  System.AccessViolationException", which is how the operator's first drive ended. So the provider is
  no longer called with the call operator: Invoke-LamConsoleConfirm compiles LamConsoleSeam
  (Initialize-LamConsoleSeamType) and invokes the provider through LamConsoleSeam.Invoke, a C# method
  marked [HandleProcessCorruptedStateExceptions], which catches ANY exception the provider raises,
  managed or native. A caught exception is a REFUSAL at CONFIRM (exit 3, stage confirm, nothing
  written, the same attestation line as any confirm refusal) whose reason names the innermost exception
  type, the type it surfaced as, and its message through the visible-byte rendering. A
  PipelineStoppedException is rethrown, so Ctrl+C still stops the console. A provider that returns
  anything but exactly one dictionary carrying 'ok' is refused, and a seam that cannot be compiled
  refuses too (fail closed). THE C# BOUNDARY GUARD: the default provider's own native calls
  (LamConsoleCred.PromptWithFlags and VerifyIsCurrentUser) catch a fault AT THE P/INVOKE BOUNDARY and
  return it as a refusal reason, so their faults never cross PowerShell frames. THE MEASURED RESIDUAL:
  after a real native fault unwinds THROUGH PowerShell frames to the seam (a provider whose own
  PowerShell code reaches a faulting native call), a 'powershell -File' process's exit code reads 2
  even where the script says 'exit 3', while the same script invoked in process with & sets
  $LASTEXITCODE to 3. The refusal and the absence of a gate are unaffected. The default provider's own
  faults are caught at the P/Invoke boundary and never cross PowerShell frames, so they do not reach
  that residual.

  WHAT AN AGENT WITH COMPUTER-USE CAN AND CANNOT REACH (measured on this host, stated narrowly):
    * It CANNOT open the Winlogon (secure) desktop -- OpenDesktop('Winlogon', DESKTOP_READOBJECTS)
      returns handle 0, GetLastError 5. So the credential prompt is not screenshot- or
      inject-reachable from a user-session or browser-pane surface.
    * It CAN open the input/Default desktop (control). Everything else about the secure desktop's
      isolation is a documented Windows property, labelled as such, not a measurement.

  STAGE 2 IS THE OPERATOR'S OWN SETUP AND IS DOCUMENTED, NOT BUILT (LAM-INSTALL): the gate directory
  ACL'd to a gate-owner principal the operator's interactive user cannot write, no runas /savecred,
  no PIN-on-normal-desktop fallback. This console is STAGE 1: it moves the authorizing secret off
  every surface this agent reaches; it does not yet make the gate directory unwritable.

.PARAMETER Command
  approve | reapprove | revoke | settle. Positional 0. Same verbs as mission-gate.ps1's mutating
  set; `list` is not a console act (it mutates nothing and is run against the tool directly).
  `settle` RECORDS THE USE of a push gate the operator has already published against -- or of an
  amendment-material or reclose gate whose amendment or re-closure is committed
  -- and takes this same verified path: it is the operator's stamping instrument (operator
  ruling (i)), the actor that performs a gated act stamps its gate, and a
  TERMINAL push leaves no session behind to do it.

.PARAMETER Kind
  The gate kind, forwarded to mission-gate.ps1 unchanged.

.PARAMETER Id
  The gate id, forwarded unchanged.

.PARAMETER Binds
  The one file the authorization is about, forwarded unchanged. Resolved against the resolved
  -MissionRoot by the tool; the console RE-DERIVES its sha256 from the resolved path for the preview.

.PARAMETER MissionRoot
  The mission root. Resolved ONCE to an absolute directory path (refused if it is not one), and that
  absolute path is what is forwarded to the tool and what the attestation log is written under.

.PARAMETER TipSha
  For push gates, forwarded unchanged.

.PARAMETER OriginUrl
  For push gates, forwarded unchanged.

.PARAMETER RemoteRef
  For push gates, forwarded unchanged.

.PARAMETER Reason
  For revoke and reapprove, forwarded unchanged.

.PARAMETER Ruling
  For halt-ruling gates, forwarded unchanged: the operator's ruling words, which
  mission-gate.ps1 records on the artifact. The preview shows them and the act digest covers them.

.PARAMETER ExpiresMinutes
  Lifetime of an expiring gate, forwarded unchanged.

.PARAMETER ComposedAt
  A UTC round-trip timestamp (yyyy-MM-ddTHH:mm:ss.fffZ) that makes composition deterministic: the
  tool substitutes it for every Get-Date in the composed bytes (created_at, expires_at, revoked_at),
  so the preview digest and the mint digest are computed over identical bytes. When omitted the
  console generates one at COMPOSE time and uses that same value for the mint. The tool refuses a
  value not of exactly that form, and one more than 10 minutes from the current UTC time.

.EXAMPLE
  tools\lam\lam-console.ps1 approve -Kind push -Id p-1 -Binds .mission\dispatches\D.yaml -MissionRoot .

.EXAMPLE
  tools\lam\lam-console.ps1 revoke -Kind dispatch -Id v-a-1 -Reason "round 1 superseded"

.EXAMPLE
  tools\lam\lam-console.ps1 settle -Kind push -Id p-1 -MissionRoot .
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('approve','reapprove','revoke','settle')]
    [string]$Command,

    [string]$Kind,
    [string]$Id,
    [string]$Binds,
    [string]$MissionRoot = '.',
    [string]$TipSha,
    [string]$OriginUrl,
    [string]$RemoteRef,
    [string]$Reason,
    [int]$ExpiresMinutes = 60,
    [string]$ComposedAt,
    [string]$Ruling
)

# =================================================================================================
# THE SHARED CONTRACT WITH mission-gate.ps1. These two constants and the entry shape are the ONLY
# coupling between the console and the tool, and they are stated in both files, character for
# character. The registry lives in [AppDomain]::CurrentDomain, which a Start-Process child does NOT
# share (measured: GetData returns null across a process boundary) -- that is exactly the property
# that makes the token un-forgeable from a child process and un-writable to disk.
# =================================================================================================
$script:LamConsoleTokenRegistryKey = 'LamConsoleTokenRegistry'
$script:LamConsoleCredentialSet    = @('secure-desktop-credui', 'injected-seam')

# THE DEFAULT CREDENTIAL LABEL AND THE DEFAULT PROVIDER. The label is DECLARED here, before the flow
# runs, so COMPOSE can put it on the artifact and the preview stays byte-exact with what the mint
# writes. IT IS A DECLARATION, NOT A MEASUREMENT OF THE CONFIRM ACT, and the artifact's
# operator_credential line is therefore a record of what the minting caller declared, never evidence
# of how the mint was authorized (session validator, DRIVEN): this variable and
# $script:LamConsoleConfirmProvider are set independently, so in-process code in library mode can
# replace the provider -- or skip this flow altogether -- and leave the label reading
# secure-desktop-credui, and the validator minted artifacts whose face read exactly that with no
# credential step anywhere. What CONFIRM does check is that the provider reports the same label the
# artifact was composed with, refusing and writing nothing otherwise: that stops a provider
# contradicting the label; it does not make the label evidence. An instrument overrides provider and
# label in library mode; outside library mode nothing selects either.
$script:LamConsoleCredentialLabel = 'secure-desktop-credui'

function Get-LamConsoleGateToolPath {
    return (Join-Path $PSScriptRoot 'mission-gate.ps1')
}

function Get-LamConsoleComposedAt {
    <# A UTC round-trip timestamp in the tool's own created_at format. #>
    param([string]$Given)
    if ($Given) { return $Given }
    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Resolve-LamConsoleMissionRoot {
    <#
      RESOLVE -MissionRoot ONCE, TO ONE ABSOLUTE DIRECTORY PATH (a review's finding). The same
      shape mission-gate.ps1 uses -- Resolve-Path -LiteralPath, refused unless it is a container -- so
      the console and the tool agree on which directory a relative root names: the one relative to the
      PowerShell location. Returns @{ ok; path; reason }. ProviderPath, not Path, so a root reached
      through a PowerShell drive still yields a path a .NET file API can open.
    #>
    param([string]$Root)
    if (-not $Root) { return [pscustomobject]@{ ok = $false; path = ''; reason = 'no -MissionRoot was given' } }
    $resolved = $null
    try { $resolved = Resolve-Path -LiteralPath $Root -ErrorAction Stop } catch { $resolved = $null }
    $one = @($resolved)
    if ($one.Count -ne 1 -or $null -eq $one[0]) {
        return [pscustomobject]@{ ok = $false; path = ''; reason = "the mission root was not found: $Root" }
    }
    if ($one[0].Provider.Name -ne 'FileSystem') {
        return [pscustomobject]@{ ok = $false; path = ''; reason = "the mission root is not a file-system path: $Root" }
    }
    $full = $one[0].ProviderPath
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        return [pscustomobject]@{ ok = $false; path = ''; reason = "the mission root is not a directory: $full" }
    }
    return [pscustomobject]@{ ok = $true; path = $full; reason = 'resolved' }
}

function New-LamConsoleToken {
    <# 32 CSPRNG bytes, lower-hex. Never written to disk, printed, put in an env var or on a command
       line -- it lives only as the key of the in-process registry entry. #>
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}

function Build-LamConsoleGateParams {
    <#
      THE NAMED PARAMETERS FORWARDED TO mission-gate.ps1, returned as a HASHTABLE for splatting. It
      MUST be a hashtable, not an array: `& script.ps1 @array` splats POSITIONALLY (a `-Kind` element
      is a positional value, not a named parameter -- measured), while `& script.ps1 $verb @hash`
      binds named parameters. The verb is passed positionally beside the splat.
    #>
    param(
        [string]$K, [string]$I, [string]$B, [string]$Root,
        [string]$Tip, [string]$Url, [string]$Ref, [string]$Why, [int]$Expires,
        [string]$At, [string]$Credential, [string]$Rul
    )
    $h = @{}
    if ($K)    { $h['Kind']        = $K }
    if ($I)    { $h['Id']          = $I }
    if ($B)    { $h['Binds']       = $B }
    if ($Root) { $h['MissionRoot'] = $Root }
    if ($Tip)  { $h['TipSha']      = $Tip }
    if ($Url)  { $h['OriginUrl']   = $Url }
    if ($Ref)  { $h['RemoteRef']   = $Ref }
    if ($Why)  { $h['Reason']      = $Why }
    if ($PSBoundParameters.ContainsKey('Expires')) { $h['ExpiresMinutes'] = $Expires }
    if ($At)         { $h['ComposedAt']       = $At }
    if ($Credential) { $h['ConsoleCredential'] = $Credential }
    if ($Rul)        { $h['Ruling']            = $Rul }
    return $h
}

function Invoke-LamConsoleCompose {
    <#
      CALL mission-gate.ps1 -ComposeOnly IN PROCESS and parse its machine-readable lines. Returns
      @{ ok; exit; out; writes=@(@{name;length;bytes}); bindsPath; bindsSha; actDigest }.
    #>
    param([string]$Verb, [hashtable]$Params)
    $tool = Get-LamConsoleGateToolPath
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # A parameter-binder refusal (an unmapped -Kind against the tool's ValidateSet) is a
        # TERMINATING error at bind time; caught here it becomes a clean non-zero compose refusal
        # rather than a raw exception at the caller.
        try {
            $raw = & $tool $Verb @Params -ComposeOnly 2>&1
            $code = $LASTEXITCODE
        } catch {
            $raw = @("mission-gate: REFUSED at compose -- $($_.Exception.Message)")
            $code = 2
        }
    } finally { $ErrorActionPreference = $prevEap }
    $lines = @($raw | ForEach-Object { [string]$_ })
    $writes = New-Object System.Collections.Generic.List[object]
    $bindsPath = ''
    $bindsSha  = ''
    $actDigest = ''
    foreach ($line in $lines) {
        if ($line -match '^LAMCOMPOSE binds_path (\S+)$') {
            $bindsPath = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Matches[1]))
        } elseif ($line -match '^LAMCOMPOSE binds_sha256 (\S+)$') {
            $bindsSha = $Matches[1]
        } elseif ($line -match '^LAMCOMPOSE act_digest (\S+)$') {
            $actDigest = $Matches[1]
        } elseif ($line -match '^LAMCOMPOSE write (\S+) (\d+) (\S+)$') {
            $writes.Add([pscustomobject]@{
                name   = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Matches[1]))
                length = [int]$Matches[2]
                bytes  = [Convert]::FromBase64String($Matches[3])
            })
        }
    }
    return [pscustomobject]@{
        ok = ($code -eq 0); exit = $code
        out = (@($lines | Where-Object { $_ -notmatch '^LAMCOMPOSE ' }) -join "`n")
        writes = @($writes.ToArray()); bindsPath = $bindsPath; bindsSha = $bindsSha; actDigest = $actDigest
    }
}

function Get-LamConsoleFileSha256 {
    # RE-DERIVE binds_sha256 THE SAME WAY mission-gate.ps1 DOES: a FileStream with
    # FileShare::ReadWrite|Delete, not Get-FileHash. Get-FileHash asks for FileShare::Read, which a
    # holder's WRITE handle refuses -- so an ordinary "a log is being appended to" file (and WP-4's
    # T-17 writer-held case) would be unreadable and the re-derivation would throw. The digest is
    # byte-identical to Get-FileHash on an ordinary file. Returns '' if it genuinely cannot read.
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    try {
        $stream = New-Object System.IO.FileStream(
            $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
            ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        try {
            $hasher = [System.Security.Cryptography.SHA256]::Create()
            try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
            finally { $hasher.Dispose() }
        } finally { $stream.Dispose() }
    } catch { return '' }
}

function Get-LamConsoleBytesSha256 {
    param([byte[]]$Bytes)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}

function Get-LamConsoleActDigest {
    # THE CONSOLE'S OWN RE-DERIVATION OF THE ACT DIGEST, over the bytes it previewed, in the framing
    # mission-gate.ps1's Get-LamActDigest documents: for each write, in order, UTF8 of
    # (name + LF + decimal-byte-length + LF) and then the raw bytes; sha256 the whole. Restated here
    # rather than dot-sourced, because the console must not take the tool's word for the digest of the
    # bytes it is about to show the operator.
    param($Writes)
    $ms = New-Object System.IO.MemoryStream
    try {
        foreach ($w in @($Writes)) {
            $hdr = [System.Text.Encoding]::UTF8.GetBytes($w.name + "`n" + $w.bytes.Length + "`n")
            $ms.Write($hdr, 0, $hdr.Length)
            $ms.Write($w.bytes, 0, $w.bytes.Length)
        }
        return (Get-LamConsoleBytesSha256 -Bytes $ms.ToArray())
    } finally { $ms.Dispose() }
}

function Format-LamConsoleVisibleBytes {
    <#
      EVERY BYTE VISIBLE (a review's finding). Printable ASCII 0x20-0x7E is shown as itself
      EXCEPT '<' (0x3C), which is shown as <0x3C> so that no literal text can imitate an escape; CR is
      shown as <CR> and LF as <LF>; every other byte -- control or non-ASCII, each byte of a multi-byte
      UTF-8 sequence separately, a byte-order mark included -- is shown as <0xNN>. With -BreakAtLf a
      printed line ends after each <LF>, so a write renders line by line; without it the result is one
      line (for names and paths). Returns an array of strings.
    #>
    param([byte[]]$Bytes, [switch]$BreakAtLf)
    $lines = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    foreach ($b in @($Bytes)) {
        if ($b -eq 10) {
            [void]$sb.Append('<LF>')
            if ($BreakAtLf) { $lines.Add($sb.ToString()); [void]$sb.Clear() }
        } elseif ($b -eq 13) {
            [void]$sb.Append('<CR>')
        } elseif ($b -ge 0x20 -and $b -le 0x7E -and $b -ne 0x3C) {
            [void]$sb.Append([char]$b)
        } else {
            [void]$sb.Append(('<0x{0:X2}>' -f $b))
        }
    }
    if ($sb.Length -gt 0 -or $lines.Count -eq 0) { $lines.Add($sb.ToString()) }
    $result = $lines.ToArray()
    return , $result
}

function Format-LamConsoleVisibleText {
    param([string]$Text)
    $vis = Format-LamConsoleVisibleBytes -Bytes ([System.Text.Encoding]::UTF8.GetBytes([string]$Text))
    return ($vis -join '')
}

function Get-LamConsoleGatesDirectory {
    <#
      THE ABSOLUTE GATES DIRECTORY FOR AN ABSOLUTE MISSION ROOT (a re-review finding). Spelled
      exactly as mission-gate.ps1 spells it -- Join-Path <resolved root> '.mission\gates' -- because
      every write the tool composes (approve's gate file, revoke's re-stamped gate file, reapprove's
      .revoked-N name and new gate file) lands in that one directory under its write name. Restated
      here, not read from the compose output, because the tool emits no such line; a change to the
      tool's directory layout must change this function with it.
    #>
    param([string]$Root)
    return (Join-Path $Root '.mission\gates')
}

function Get-LamConsoleWriteTarget {
    <#
      THE ABSOLUTE TARGET PATH OF ONE PLANNED WRITE, OR A REFUSAL. Returns @{ ok; path; reason }. The
      write name must be a PLAIN FILE NAME: non-empty and free of every character
      [System.IO.Path]::GetInvalidFileNameChars() lists (path separators, the colon, control bytes,
      wildcards, quotes, pipes and angle brackets). mission-gate.ps1 applies no character pattern to
      -Id for any kind but halt-ruling (whose -Id it refuses unless it matches
      ^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$ anchored \A..\z, with the HALT- prefix matched in ANY case --
      section 5.6.2 of LAM-INSTALL carries the full rule), and it names the .revoked-N write by its LEAF, so a name
      carrying a separator would make
      <gates>\<name> a path the tool does not write to; showing it would be a false preview, so the
      console refuses instead. The path returned is [System.IO.Path]::GetFullPath of the join, which is
      the normalization .NET applies when the tool opens the file.
    #>
    param([string]$GatesDir, [string]$Name)
    if (-not $Name) { return [pscustomobject]@{ ok = $false; path = ''; reason = 'a planned write carries an empty name' } }
    if ($Name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return [pscustomobject]@{ ok = $false; path = ''; reason = ("the planned write '{0}' is not a plain file name (it carries a path separator, a colon, a control byte or another character Windows refuses in a file name), so its absolute target inside the gates directory cannot be shown truthfully" -f (Format-LamConsoleVisibleText -Text $Name)) }
    }
    try {
        $full = [System.IO.Path]::GetFullPath((Join-Path $GatesDir $Name))
    } catch {
        return [pscustomobject]@{ ok = $false; path = ''; reason = ("the absolute target of the planned write '{0}' could not be resolved: {1}" -f (Format-LamConsoleVisibleText -Text $Name), $_.Exception.Message) }
    }
    return [pscustomobject]@{ ok = $true; path = $full; reason = 'resolved' }
}

function Show-LamConsolePreview {
    <#
      BUILD THE PREVIEW AND RE-DERIVE WHAT IT SHOWS. Returns @{ ok; reason; lines; writes } where
      lines is the full rendering (the caller prints it unless -Quiet) and writes is one
      @{ name; length; sha256; target } per planned write, the sha256 computed by the console from the
      bytes it rendered. The rendering opens with the resolved absolute -MissionRoot and the absolute
      gates directory, and every write shows its absolute target path (found in review), all through the
      visible-byte rendering. Refuses (ok false) when a write's name is not a plain file name, when a
      write's declared length is not its byte count, when the console's own re-derivation of
      binds_sha256 from the bound file disagrees with the composed artifact's, or when the console's own
      act digest over the rendered bytes disagrees with the composed one -- the console never trusts the
      tool's word about the bytes it shows.
    #>
    param($Compose, [string]$MissionRoot)
    $lines = New-Object System.Collections.Generic.List[string]
    $summary = New-Object System.Collections.Generic.List[object]
    $allWrites = @($Compose.writes)
    $gatesDir = Get-LamConsoleGatesDirectory -Root $MissionRoot
    $lines.Add('lam-console: PREVIEW -- every byte of every planned write. Nothing is written unless the confirm act succeeds.')
    $lines.Add("  LEGEND: each line of a write is printed after '  | '. <CR> is byte 0x0D and <LF> is byte 0x0A (a printed")
    $lines.Add("  line ends after its <LF>); <0xNN> is any other control byte, any non-ASCII byte, and the '<' character.")
    $lines.Add(('  {0,-40} : {1}' -f 'mission root (resolved, absolute)', (Format-LamConsoleVisibleText -Text $MissionRoot)))
    $lines.Add(('  {0,-40} : {1}' -f 'gates directory (absolute)', (Format-LamConsoleVisibleText -Text $gatesDir)))
    # UI-2 S1 A-10 (register row 512, ruled at REC-P: one line on the console's face): the two clocks a reader compares.
    $lines.Add(('  {0,-40} : {1}' -f 'created_at (the artifact''s, below)', "composed at preview -- fixed once by the console before this preview; the feed's gate_minted ts is the write time, after the confirm act, and may trail it"))
    $n = 0
    foreach ($w in $allWrites) {
        $n++
        $sha = Get-LamConsoleBytesSha256 -Bytes $w.bytes
        if ([int]$w.length -ne $w.bytes.Length) {
            return [pscustomobject]@{ ok = $false; reason = ("the compose output declared {0} bytes for write '{1}' but carried {2}" -f $w.length, (Format-LamConsoleVisibleText -Text $w.name), $w.bytes.Length); lines = $lines.ToArray(); writes = @() }
        }
        $target = Get-LamConsoleWriteTarget -GatesDir $gatesDir -Name $w.name
        if (-not $target.ok) {
            return [pscustomobject]@{ ok = $false; reason = $target.reason; lines = $lines.ToArray(); writes = @() }
        }
        $lines.Add(('  WRITE {0} of {1}: {2}' -f $n, $allWrites.Count, (Format-LamConsoleVisibleText -Text $w.name)))
        $lines.Add('    target: ' + (Format-LamConsoleVisibleText -Text $target.path))
        # ASSIGNED FIRST: the helper returns `, $array`, which survives assignment and is double-wrapped
        # by `@(call)` -- iterating the call directly would print the whole write as one joined line.
        $visibleLines = Format-LamConsoleVisibleBytes -Bytes $w.bytes -BreakAtLf
        foreach ($vl in $visibleLines) { $lines.Add('  | ' + $vl) }
        $lines.Add(('    bytes: {0}   sha256: {1}' -f $w.bytes.Length, $sha))
        $summary.Add([pscustomobject]@{ name = $w.name; length = $w.bytes.Length; sha256 = $sha; target = $target.path })
    }
    if ($Compose.bindsSha) {
        $reDerived = ''
        if ($Compose.bindsPath) { $reDerived = Get-LamConsoleFileSha256 -Path $Compose.bindsPath }
        if (-not $reDerived) {
            return [pscustomobject]@{ ok = $false; reason = "the console could not re-derive binds_sha256 (the bound file is not readable at $($Compose.bindsPath))"; lines = $lines.ToArray(); writes = @() }
        }
        if ($reDerived -ne $Compose.bindsSha) {
            return [pscustomobject]@{ ok = $false; reason = "binds_sha256 re-derived by the console ($reDerived) does not match the composed artifact ($($Compose.bindsSha))"; lines = $lines.ToArray(); writes = @() }
        }
        $lines.Add('  bound file (resolved)                    : ' + (Format-LamConsoleVisibleText -Text $Compose.bindsPath))
        $lines.Add('  binds_sha256 (re-derived by the console) : ' + $reDerived + '  MATCHES the composed artifact')
    } else {
        $lines.Add('  bound file                               : (none -- this act binds no file)')
    }
    $consoleDigest = Get-LamConsoleActDigest -Writes $allWrites
    if ($consoleDigest -ne $Compose.actDigest) {
        return [pscustomobject]@{ ok = $false; reason = "the act digest re-derived by the console over the previewed bytes ($consoleDigest) does not match the composed one ($($Compose.actDigest))"; lines = $lines.ToArray(); writes = @() }
    }
    $lines.Add('  act digest (re-derived by the console over the bytes above) : ' + $consoleDigest + '  MATCHES the composed digest')
    return [pscustomobject]@{ ok = $true; reason = 'preview matches'; lines = $lines.ToArray(); writes = @($summary.ToArray()) }
}

function Get-LamConsoleDesktopReach {
    <#
      MEASURE, NARROWLY, WHAT A COMPUTER-USE AGENT CAN REACH: does OpenDesktop('Winlogon', read)
      succeed from this process? OpenInputDesktop / the Default desktop is the control that MUST
      succeed. Everything else about the secure desktop is a documented Windows property, not a
      measurement. Returns @{ winlogonHandle; winlogonError; inputHandle; inputError; winlogonDenied }.
    #>
    if (-not ('LamConsoleDesk' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LamConsoleDesk {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);
    public const uint DESKTOP_READOBJECTS = 0x0001;
}
'@ -Language CSharp
    }
    $wh = [LamConsoleDesk]::OpenDesktop('Winlogon', 0, $false, [LamConsoleDesk]::DESKTOP_READOBJECTS)
    $we = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($wh -ne [IntPtr]::Zero) { [void][LamConsoleDesk]::CloseDesktop($wh) }
    $ih = [LamConsoleDesk]::OpenInputDesktop(0, $false, [LamConsoleDesk]::DESKTOP_READOBJECTS)
    $ie = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($ih -ne [IntPtr]::Zero) { [void][LamConsoleDesk]::CloseDesktop($ih) }
    return @{
        winlogonHandle = ([int64]$wh); winlogonError = $we
        inputHandle = ([int64]$ih); inputError = $ie
        winlogonDenied = ($wh -eq [IntPtr]::Zero)
        inputOpened = ($ih -ne [IntPtr]::Zero)
    }
}

function Initialize-LamConsoleCredType {
    <#
      COMPILE THE SECURE-DESKTOP CREDENTIAL PROVIDER'S NATIVE SURFACE. Called lazily by the DEFAULT
      provider only. It is NOT reached in library mode (the instrument overrides the provider).

      WHAT THIS PATH SENDS, EXACTLY, AND WHAT IT WAS DESIGNED FOR (a review's finding):
        * CredUIPromptForWindowsCredentialsW is called with a VALID CREDUI_INFO (cbSize =
          Marshal.SizeOf(CREDUI_INFO), no parent window, no banner, and a FIXED caption and message --
          no gate name or other caller data -- allocated with Marshal.StringToCoTaskMemUni and freed
          after the call returns or faults), dwAuthError 0, no incoming buffer, pfSave false, and
          dwFlags = CREDUIWIN_SECURE_PROMPT (0x1000) ONLY. It returns an opaque AUTHENTICATION BUFFER
          serialized by the credential provider the operator used, and the authentication package that
          provider selected (pulAuthPackage).
        * CREDUIWIN_ENUMERATE_CURRENT_USER (0x200) IS NO LONGER SENT (the build lead's
          ruling): the design note (docs/framework/design/batch-4-proposals.md:52) asks only for the
          secure desktop, the flag's documented meaning is that only the incoming credentials should be
          enumerated and this call sends none, and CREDUIWIN_GENERIC cannot be combined with
          SECURE_PROMPT. The lead's grounding measured that 0x200 is NOT what faulted.
        * That buffer is copied, the CredUI copy is zeroed and freed (ole32 CoTaskMemFree -- copy, zero,
          free, in that order), and the buffer is submitted
          UNMODIFIED to LsaLogonUser (LogonType Interactive, via LsaConnectUntrusted) under THAT SAME
          authentication package. No Negotiate substitution, no unpacking.
        * THE BUFFER IS NEVER UNPACKED. An earlier draft called CredUnPackAuthenticationBuffer into
          user/domain/password StringBuilders it never used -- the plaintext password then sat in
          managed memory, uncleared -- while submitting the raw buffer anyway. That call is gone: this
          process never holds the user name, the domain or the password as text.
        * The logon's token user SID must equal the current process user's SID, or it fails.
        * DESIGNED FOR, per the Windows documentation (not measured here): the credential kinds a
          Windows credential provider serializes for an interactive logon -- a password credential for
          a local or domain account, and the certificate-based kinds (smart card, Windows Hello) --
          whose serialization LsaLogonUser accepts under the package CredUI reports.
        * THE OPERATOR'S FIRST DRIVE FAULTED (2026-09-16T13:48Z). Until then this path had been
          compiled only and never run on this host. The first real drive of the confirm step (approve
          -Kind push, the operator at an interactive terminal outside any session, Space pressed) threw
          System.AccessViolationException inside CredUIPromptForWindowsCredentials, called from
          PromptSecureDesktop, BEFORE ANY PROMPT WAS DISPLAYED; nothing was written. ROOT CAUSE,
          MEASURED in the build lead's grounding (child processes): the extern declared
          pUiInfo as IntPtr and passed NULL, and a NULL pUiInfo faults in 6-7 ms with flags 0x0, 0x20
          and 0x200 alike, while a VALID CREDUI_INFO does not fault. (wincred.h annotates pUiInfo
          _In_opt_; this host faults on NULL all the same.)
        * THE FIX. The private blittable struct CREDUI_INFO below, passed by reference; the extern bound
          by EntryPoint to CredUIPromptForWindowsCredentialsW with ExactSpelling, its DWORD parameters
          and return declared uint and pfSave marshalled as a Win32 BOOL; the flags above; and the ONE
          native call held inside PromptWithFlags, marked [HandleProcessCorruptedStateExceptions], so a
          native fault is returned as rc PromptFaulted (0xFFFFFFFF) with the exception type named,
          never an unhandled crash -- after a fault the out buffer is never touched, its value being
          unknown. VerifyIsCurrentUser carries the same boundary. Checked against the SDK and corrected
          with it: QUOTA_LIMITS is five SIZE_T and one LARGE_INTEGER (winnt.h:12945), where six
          pointer-sized fields were declared, and RtlZeroMemory's length is SIZE_T (UIntPtr).
          LsaLogonUser's LogonId is _Inout_ and is passed by reference; the zeroed LUID it carries is
          the same one the out form passed. What is sent to LsaLogonUser is otherwise unchanged,
          including the zeroed TOKEN_SOURCE.
        * WHAT IS MEASURED OF THE FIX, AND WHAT IS NOT. WP-4 T-28 reflects the compiled signature
          against the SDK, and drives the fixed call ONCE, with CREDUIWIN_IN_CRED_ONLY (0x20), no
          incoming buffer and never the secure bit: it returns rc 87 (ERROR_INVALID_PARAMETER) with NO
          UI. NO SESSION HAS COMPLETED OR EVEN RAISED THE SECURE-DESKTOP PROMPT through this path, and
          NO LsaLogonUser CALL HAS BEEN MADE through it, in any session. Whether LsaLogonUser accepts
          this buffer from an untrusted LSA connection with a zeroed TOKEN_SOURCE is therefore still
          UNVERIFIED. THE OPERATOR'S SECOND DRIVE IS OWED -- the probe first
          (tools\lam\lam-console-probe.ps1, built next), then this console -- and it is that
          verification; it fails closed if the answer is no.
      The P/Invoke constants, structs and signatures are verified against the Windows SDK (wincred.h,
      NTSecAPI.h, LsaLookup.h, winnt.h, combaseapi.h, handleapi.h) at
      C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0.
    #>
    if ('LamConsoleCred' -as [type]) { return }
    $cs = @'
using System;
using System.Globalization;
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Principal;
using System.Text;
public static class LamConsoleCred {
    public const uint PromptFlags = 0x00001000;     // CREDUIWIN_SECURE_PROMPT (wincred.h:787) -- the ONLY flag the operator path sends
    public const uint PromptFaulted = 0xFFFFFFFF;   // rc sentinel: the native call raised an exception, caught at the P/Invoke boundary

    // CREDUI_INFOW (wincred.h:684): DWORD cbSize; HWND hwndParent; PCWSTR pszMessageText;
    // PCWSTR pszCaptionText; HBITMAP hbmBanner. No string fields, so it stays blittable and is passed
    // by reference as-is: 40 B on x64, 20 B on x86.
    [StructLayout(LayoutKind.Sequential)]
    struct CREDUI_INFO {
        public int cbSize;
        public IntPtr hwndParent;
        public IntPtr pszMessageText;
        public IntPtr pszCaptionText;
        public IntPtr hbmBanner;
    }

    public static int CredUiInfoSize { get { return Marshal.SizeOf(typeof(CREDUI_INFO)); } }

    // FIXED TEXT ONLY: no gate name or other caller data reaches the prompt.
    const string PromptCaption = "lam-console: authorize a gate act";
    const string PromptMessage = "Confirm with your own Windows credential. This authorizes the gate act previewed in your console.";

    // CredUIPromptForWindowsCredentialsW (wincred.h:1450). The first operator drive faulted on the
    // IntPtr pUiInfo this extern used to pass as NULL (see Initialize-LamConsoleCredType's header).
    [DllImport("credui.dll", EntryPoint = "CredUIPromptForWindowsCredentialsW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    static extern uint CredUIPromptForWindowsCredentials(ref CREDUI_INFO pUiInfo, uint dwAuthError,
        ref uint pulAuthPackage, IntPtr pvInAuthBuffer, uint ulInAuthBufferSize, out IntPtr ppvOutAuthBuffer,
        out uint pulOutAuthBufferSize, [MarshalAs(UnmanagedType.Bool)] ref bool pfSave, uint dwFlags);

    [DllImport("ole32.dll")] static extern void CoTaskMemFree(IntPtr pv);   // combaseapi.h:1349

    [StructLayout(LayoutKind.Sequential)] struct LSA_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }   // LsaLookup.h:49
    [StructLayout(LayoutKind.Sequential)] struct LUID { public uint LowPart; public int HighPart; }   // winnt.h:978
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_SOURCE { [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)] public byte[] SourceName; public LUID SourceIdentifier; }   // winnt.h:12259
    // QUOTA_LIMITS (winnt.h:12945): five SIZE_T, then LARGE_INTEGER TimeLimit.
    [StructLayout(LayoutKind.Sequential)] struct QUOTA_LIMITS {
        public IntPtr PagedPoolLimit; public IntPtr NonPagedPoolLimit; public IntPtr MinimumWorkingSetSize;
        public IntPtr MaximumWorkingSetSize; public IntPtr PagefileLimit; public long TimeLimit;
    }

    [DllImport("secur32.dll")] static extern int LsaConnectUntrusted(out IntPtr LsaHandle);
    [DllImport("secur32.dll")] static extern int LsaLogonUser(IntPtr LsaHandle, ref LSA_STRING OriginName, uint LogonType, uint AuthenticationPackage,
        IntPtr AuthenticationInformation, uint AuthenticationInformationLength, IntPtr LocalGroups, ref TOKEN_SOURCE SourceContext,
        out IntPtr ProfileBuffer, out uint ProfileBufferLength, ref LUID LogonId, out IntPtr Token, out QUOTA_LIMITS Quotas, out int SubStatus);
    [DllImport("secur32.dll")] static extern int LsaDeregisterLogonProcess(IntPtr LsaHandle);
    [DllImport("secur32.dll")] static extern int LsaFreeReturnBuffer(IntPtr Buffer);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern void RtlZeroMemory(IntPtr dst, UIntPtr len);

    const uint Interactive = 2;   // SECURITY_LOGON_TYPE.Interactive (NTSecAPI.h:962)

    // Raise the secure-desktop prompt. Returns a COPY of the packed authentication buffer and the
    // authentication package the credential provider selected; the CredUI-owned buffer is copied,
    // zeroed and freed before return. dwAuthError 0, no incoming buffer, dwFlags PromptFlags only.
    public static bool PromptSecureDesktop(out byte[] packed, out uint authPackage, out string reason) {
        uint rc;
        return PromptSecureDesktop(out packed, out authPackage, out reason, out rc);
    }

    public static bool PromptSecureDesktop(out byte[] packed, out uint authPackage, out string reason, out uint rc) {
        return PromptWithFlags(PromptFlags, out packed, out authPackage, out reason, out rc);
    }

    // THE ONE NATIVE CALL, AND ITS BOUNDARY. A fault inside CredUI is caught HERE, at the P/Invoke
    // boundary, and returned as rc PromptFaulted with the exception named; it never crosses a
    // PowerShell frame. After a RETURNED call the out buffer is copied (rc 0 and size > 0 only), zeroed
    // and freed, in that order; after a FAULTED call it is never touched, because its value is unknown.
    [HandleProcessCorruptedStateExceptions, SecurityCritical]
    static bool PromptWithFlags(uint flags, out byte[] packed, out uint authPackage, out string reason, out uint rc) {
        packed = null; authPackage = 0; reason = "not-collected"; rc = PromptFaulted;
        IntPtr caption = IntPtr.Zero;
        IntPtr message = IntPtr.Zero;
        try {
            caption = Marshal.StringToCoTaskMemUni(PromptCaption);
            message = Marshal.StringToCoTaskMemUni(PromptMessage);
            CREDUI_INFO info = new CREDUI_INFO();
            info.cbSize = Marshal.SizeOf(typeof(CREDUI_INFO));
            info.hwndParent = IntPtr.Zero;
            info.pszMessageText = message;
            info.pszCaptionText = caption;
            info.hbmBanner = IntPtr.Zero;
            uint pul = 0;
            IntPtr outBuf = IntPtr.Zero;
            uint outSize = 0;
            bool save = false;
            uint returned;
            try {
                returned = CredUIPromptForWindowsCredentials(ref info, 0, ref pul, IntPtr.Zero, 0,
                                                             out outBuf, out outSize, ref save, flags);
            } catch (Exception e) {
                rc = PromptFaulted;
                reason = "native exception " + e.GetType().FullName + " inside CredUIPromptForWindowsCredentials: " + e.Message;
                return false;
            }
            rc = returned;
            byte[] copy = null;
            try {
                if (outBuf != IntPtr.Zero && returned == 0 && outSize > 0) {
                    copy = new byte[outSize];
                    Marshal.Copy(outBuf, copy, 0, (int)outSize);
                }
            } finally {
                if (outBuf != IntPtr.Zero) {
                    RtlZeroMemory(outBuf, (UIntPtr)outSize);
                    CoTaskMemFree(outBuf);
                }
            }
            if (returned == 1223) { reason = "operator cancelled the secure-desktop prompt (rc 1223 ERROR_CANCELLED)"; return false; }
            if (returned != 0) { reason = "CredUIPromptForWindowsCredentials rc=" + returned.ToString(CultureInfo.InvariantCulture); return false; }
            if (copy == null) { reason = "no credential was collected (rc 0, empty buffer)"; return false; }
            packed = copy;
            authPackage = pul;
            reason = "collected";
            return true;
        } finally {
            if (caption != IntPtr.Zero) Marshal.FreeCoTaskMem(caption);
            if (message != IntPtr.Zero) Marshal.FreeCoTaskMem(message);
        }
    }

    // Submit the packed buffer, UNMODIFIED and NEVER UNPACKED, to LsaLogonUser (Interactive) under the
    // authentication package CredUI reported, and require the logon's SID to be the current user's.
    // LsaLogonUser HAS NEVER BEEN CALLED through this method in any session (see
    // Initialize-LamConsoleCredType's header); WP-4 T-28 calls it only with a NULL buffer, which throws
    // on packed.Length -- the first statement inside the try, before LsaConnectUntrusted.
    [HandleProcessCorruptedStateExceptions, SecurityCritical]
    public static bool VerifyIsCurrentUser(byte[] packed, uint authPackage, out string reason) {
        reason = "not-verified";
        IntPtr pBuf = IntPtr.Zero; int pLen = 0;
        IntPtr lsa = IntPtr.Zero; IntPtr token = IntPtr.Zero; IntPtr profile = IntPtr.Zero; IntPtr onBuf = IntPtr.Zero;
        try {
            pLen = packed.Length;
            pBuf = Marshal.AllocHGlobal(pLen);
            Marshal.Copy(packed, 0, pBuf, pLen);
            if (LsaConnectUntrusted(out lsa) != 0) { reason = "LsaConnectUntrusted failed"; return false; }
            LSA_STRING origin = new LSA_STRING();
            byte[] on = Encoding.ASCII.GetBytes("LamConsole");
            onBuf = Marshal.AllocHGlobal(on.Length);
            Marshal.Copy(on, 0, onBuf, on.Length);
            origin.Length = (ushort)on.Length; origin.MaximumLength = (ushort)on.Length; origin.Buffer = onBuf;
            TOKEN_SOURCE src = new TOKEN_SOURCE(); src.SourceName = new byte[8];
            LUID lid = new LUID(); QUOTA_LIMITS q; int sub; uint plen;
            int lg = LsaLogonUser(lsa, ref origin, Interactive, authPackage, pBuf, (uint)pLen, IntPtr.Zero,
                                  ref src, out profile, out plen, ref lid, out token, out q, out sub);
            if (lg != 0) { reason = "LsaLogonUser status 0x" + lg.ToString("X") + " sub 0x" + sub.ToString("X"); return false; }
            using (WindowsIdentity id = new WindowsIdentity(token)) {
                using (WindowsIdentity current = WindowsIdentity.GetCurrent()) {
                    string got = id.User.Value;
                    string me = current.User.Value;
                    bool same = string.Equals(got, me, StringComparison.OrdinalIgnoreCase);
                    reason = same ? "verified against the current user's SID" : ("SID mismatch: logon SID " + got + " is not " + me);
                    return same;
                }
            }
        } catch (Exception e) {
            reason = "native exception " + e.GetType().FullName + " inside VerifyIsCurrentUser: " + e.Message;
            return false;
        } finally {
            if (pBuf != IntPtr.Zero) {
                RtlZeroMemory(pBuf, (UIntPtr)(uint)pLen);
                Marshal.FreeHGlobal(pBuf);
            }
            if (onBuf != IntPtr.Zero) Marshal.FreeHGlobal(onBuf);
            if (profile != IntPtr.Zero) LsaFreeReturnBuffer(profile);
            if (token != IntPtr.Zero) CloseHandle(token);
            if (lsa != IntPtr.Zero) LsaDeregisterLogonProcess(lsa);
        }
    }
}
'@
    Add-Type -TypeDefinition $cs -Language CSharp
}

function Get-LamConsoleConfirmAnnouncement {
    <#
      THE ONE LINE THE DEFAULT PROVIDER PRINTS BEFORE THE KEYSTROKE (a re-review finding).
      The gate name is Kind-Id and mission-gate.ps1 applies no character pattern to -Id for any kind but
      halt-ruling, whose -Id it refuses unless it matches its HALT id pattern (section 5.6.2), so a raw
      print
      could carry an escape sequence, a carriage return or look-alike text straight to the operator's
      console at the moment they are about to authorize. Every value in the line -- the verb, the gate
      name, the mission root and the digest prefix -- goes through Format-LamConsoleVisibleText, the
      preview's own visible-byte rendering, so the line is printable ASCII whatever the values hold.
      A pure function, so an instrument can measure it without running the provider.
    #>
    param($Context)
    $digest = [string]$Context.previewDigest
    if ($digest.Length -gt 16) { $digest = $digest.Substring(0, 16) }
    return ("lam-console: about to authorize {0} {1} in {2} (preview digest {3}...)." -f `
        (Format-LamConsoleVisibleText -Text ([string]$Context.verb)),
        (Format-LamConsoleVisibleText -Text ([string]$Context.gate)),
        (Format-LamConsoleVisibleText -Text ([string]$Context.missionRoot)),
        (Format-LamConsoleVisibleText -Text $digest))
}

# THE DEFAULT PROVIDER. Reads ONE key, then raises the secure-desktop credential and verifies it
# against the operator's own account. Fails closed on cancel, error, and on a host with no console or
# no authenticator. Returns @{ ok; reason; credential }. It is the ONLY provider on the operator's
# real path and is NEVER reached in the build session, where an instrument replaces it in library
# mode. NO env var / switch / file selects a provider. NO SESSION HAS RUN IT. THE OPERATOR RAN IT ONCE
# (2026-09-16T13:48Z) AND IT FAULTED -- System.AccessViolationException inside
# CredUIPromptForWindowsCredentials, before any prompt, nothing written; the root cause, measured in the
# build lead's grounding, was the NULL pUiInfo, fixed in Initialize-LamConsoleCredType,
# whose fixed call is measured only by WP-4 T-28's no-UI IN_CRED_ONLY drive (rc 87). NO SESSION HAS
# COMPLETED OR EVEN RAISED THE SECURE PROMPT, LsaLogonUser HAS NEVER BEEN CALLED, AND THE OPERATOR'S
# SECOND DRIVE IS OWED (the probe first, tools\lam\lam-console-probe.ps1, built next).
$script:LamConsoleConfirmProvider = {
    param($Context)
    # (1) No console at all -> fail closed. A host with no interactive console cannot present a
    #     secure-desktop prompt, and a redirected stdin cannot supply the keystroke.
    $hasConsole = $true
    try { $null = [Console]::KeyAvailable } catch { $hasConsole = $false }
    if ([Console]::IsInputRedirected) { $hasConsole = $false }
    if (-not $hasConsole) {
        return @{ ok = $false; reason = 'no interactive console: the one keystroke and the secure-desktop prompt cannot be presented here'; credential = 'secure-desktop-credui' }
    }
    Write-Host ""
    Write-Host (Get-LamConsoleConfirmAnnouncement -Context $Context)
    Write-Host "Press any key to raise the SECURE-DESKTOP credential prompt, or Q to cancel."
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq 'Q') {
        return @{ ok = $false; reason = 'operator cancelled at the keystroke'; credential = 'secure-desktop-credui' }
    }
    # (2) The secure-desktop credential. Compile the native surface lazily; a host without it fails
    #     closed rather than falling back to an ordinary-desktop prompt.
    try { Initialize-LamConsoleCredType } catch {
        return @{ ok = $false; reason = ("no secure-desktop authenticator available: " + $_.Exception.Message); credential = 'secure-desktop-credui' }
    }
    $packed = $null; $authPkg = [uint32]0; $reason = ''
    $collected = [LamConsoleCred]::PromptSecureDesktop([ref]$packed, [ref]$authPkg, [ref]$reason)
    if (-not $collected) {
        return @{ ok = $false; reason = ("secure-desktop prompt failed closed: " + $reason); credential = 'secure-desktop-credui' }
    }
    $vReason = ''
    $verified = $false
    try {
        $verified = [LamConsoleCred]::VerifyIsCurrentUser($packed, $authPkg, [ref]$vReason)
    } catch {
        $verified = $false; $vReason = $_.Exception.Message
    } finally {
        # zero the packed buffer this process holds in managed memory, whatever the verification did
        for ($zi = 0; $zi -lt $packed.Length; $zi++) { $packed[$zi] = 0 }
    }
    if (-not $verified) {
        return @{ ok = $false; reason = ("credential did not verify as the operator: " + $vReason); credential = 'secure-desktop-credui' }
    }
    return @{ ok = $true; reason = $vReason; credential = 'secure-desktop-credui' }
}

function Initialize-LamConsoleSeamType {
    <#
      COMPILE THE CONFIRM SEAM (the file header's THE CONFIRM SEAM'S FAILURE PATH).
      LamConsoleSeam.Invoke calls the provider scriptblock with the context and is marked
      [HandleProcessCorruptedStateExceptions, SecurityCritical], because a real native access violation
      raised under a provider is NOT catchable by a PowerShell try/catch in 5.1 -- the process dies
      0xC0000005. Any exception, managed or native, comes back as threw = true with outerType (the
      exception as caught), innerType and message (the innermost InnerException, or the exception
      itself when it has none). A PipelineStoppedException is rethrown, so Ctrl+C still stops the
      console. Otherwise threw = false and results holds the BaseObject of every non-null output.
    #>
    if ('LamConsoleSeam' -as [type]) { return }
    $cs = @'
using System;
using System.Collections;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Runtime.ExceptionServices;
using System.Security;
public static class LamConsoleSeam {
    [HandleProcessCorruptedStateExceptions, SecurityCritical]
    public static Hashtable Invoke(ScriptBlock provider, object context) {
        Hashtable result = new Hashtable();
        try {
            Collection<PSObject> output = provider.Invoke(context);
            ArrayList kept = new ArrayList();
            foreach (PSObject item in output) {
                if (item != null && item.BaseObject != null) kept.Add(item.BaseObject);
            }
            result["threw"] = false;
            result["results"] = kept.ToArray();
        } catch (PipelineStoppedException) {
            throw;
        } catch (Exception e) {
            Exception innermost = e;
            while (innermost.InnerException != null) innermost = innermost.InnerException;
            result["threw"] = true;
            result["outerType"] = e.GetType().FullName;
            result["innerType"] = innermost.GetType().FullName;
            result["message"] = innermost.Message;
        }
        return result;
    }
}
'@
    Add-Type -TypeDefinition $cs -Language CSharp -ReferencedAssemblies 'System.Management.Automation' -ErrorAction Stop
}

function Invoke-LamConsoleConfirm {
    <#
      THE CONFIRM ACT, THROUGH THE SEAM. Returns the provider's one result dictionary unchanged, or a
      refusal @{ ok = $false; reason; credential } when the seam cannot be compiled (fail closed), when the
      provider raised anything (the innermost type, the type it surfaced as, and the message, each
      through the visible-byte rendering -- the review's discipline), or when it returned anything but
      exactly ONE dictionary carrying an 'ok' key. Invoke-LamConsoleGateAct's CONFIRM refusal path (exit
      3, stage confirm, the attestation line) handles every refusal the same way.
    #>
    param($Context)
    try {
        Initialize-LamConsoleSeamType
    } catch {
        return @{ ok = $false; reason = ('the confirm seam could not be compiled: ' + (Format-LamConsoleVisibleText -Text ([string]$_.Exception.Message))); credential = $script:LamConsoleCredentialLabel }
    }
    if (-not ('LamConsoleSeam' -as [type])) {
        return @{ ok = $false; reason = 'the confirm seam could not be compiled: the LamConsoleSeam type is absent after compilation'; credential = $script:LamConsoleCredentialLabel }
    }
    $seam = [LamConsoleSeam]::Invoke($script:LamConsoleConfirmProvider, $Context)
    if ($seam['threw']) {
        $raisedReason = ('the confirm provider raised {0} (surfaced as {1}): {2}' -f `
            (Format-LamConsoleVisibleText -Text ([string]$seam['innerType'])),
            (Format-LamConsoleVisibleText -Text ([string]$seam['outerType'])),
            (Format-LamConsoleVisibleText -Text ([string]$seam['message'])))
        return @{ ok = $false; reason = $raisedReason; credential = $script:LamConsoleCredentialLabel }
    }
    $seamResults = @($seam['results'])
    $oneDictionary = ($seamResults.Count -eq 1) -and ($seamResults[0] -is [System.Collections.IDictionary]) -and $seamResults[0].Contains('ok')
    if (-not $oneDictionary) {
        return @{ ok = $false; reason = ('the confirm provider returned {0} results, not one' -f $seamResults.Count); credential = $script:LamConsoleCredentialLabel }
    }
    return $seamResults[0]
}

function Register-LamConsoleToken {
    <#
      Put ONE token entry into the process-memory registry. The entry is a hashtable held BY
      REFERENCE, so mission-gate.ps1 marking it used is visible here. Returns the token hex.
    #>
    param([string]$Verb, [string]$K, [string]$I, [string]$At, [string]$Credential, [string]$ActDigest, [int]$LifetimeSeconds = 120)
    $reg = [AppDomain]::CurrentDomain.GetData($script:LamConsoleTokenRegistryKey)
    if (-not ($reg -is [hashtable])) { $reg = @{}; [AppDomain]::CurrentDomain.SetData($script:LamConsoleTokenRegistryKey, $reg) }
    $token = New-LamConsoleToken
    $reg[$token] = @{
        verb = $Verb; kind = $K; id = $I; composedAt = $At; credential = $Credential
        actDigest = $ActDigest; expiresUtc = (Get-Date).ToUniversalTime().AddSeconds($LifetimeSeconds); used = $false
    }
    return $token
}

function Clear-LamConsoleToken {
    param([string]$Token)
    $reg = [AppDomain]::CurrentDomain.GetData($script:LamConsoleTokenRegistryKey)
    if ($reg -is [hashtable] -and $Token -and $reg.ContainsKey($Token)) { [void]$reg.Remove($Token) }
}

function Invoke-LamConsoleAttest {
    <#
      Append ONE content-free line, in record-operator-prompt.ps1's form and with its FileMode Append
      / FileShare Read retry loop. Never the ruling text, never the token. $Root MUST be the ABSOLUTE
      mission root Resolve-LamConsoleMissionRoot produced: every path below is built from it and handed
      to .NET, which would otherwise resolve a relative one against the PROCESS current directory.
      Returns @{ ok; path; reason } -- a line that did not land is RETURNED, never swallowed.
      WHAT THIS LINE IS, AND IS NOT (session validator, DRIVEN): it records a
      CONSOLE ACT, not a mint. This function is the only writer of operator-acts.log and it is called
      only from Invoke-LamConsoleGateAct -- mission-gate.ps1 never attests -- so a mint driven in
      process without this flow leaves a REAL gate and NO line here (measured). It is not an
      independent second record of a mint; a reader reconciles against the gates directory.
    #>
    param([string]$Root, [string]$Verb, [string]$Gate, [string]$Digest, [string]$Credential, [int]$ToolExit)
    $log = ''
    try {
        if (-not [System.IO.Path]::IsPathRooted($Root)) {
            return [pscustomobject]@{ ok = $false; path = ''; reason = "the attestation root is not absolute ($Root)" }
        }
        $dir = [System.IO.Path]::Combine($Root, '.mission-runtime')
        $log = [System.IO.Path]::Combine($dir, 'operator-acts.log')
        [void][System.IO.Directory]::CreateDirectory($dir)
        $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
        $line = "{0} kind=gate-act verb={1} gate={2} preview_digest={3} credential={4} tool_exit={5}" -f `
                $ts, $Verb, $Gate, $Digest, $Credential, $ToolExit
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($line + "`n")
        $lastError = ''
        for ($i = 1; $i -le 10; $i++) {
            try {
                $fs = [System.IO.File]::Open($log, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
                try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
                return [pscustomobject]@{ ok = $true; path = $log; reason = 'appended' }
            } catch [System.IO.IOException] {
                $lastError = $_.Exception.Message
                Start-Sleep -Milliseconds (10 * $i)
            }
        }
        return [pscustomobject]@{ ok = $false; path = $log; reason = "the log stayed locked through 10 attempts: $lastError" }
    } catch {
        return [pscustomobject]@{ ok = $false; path = $log; reason = $_.Exception.Message }
    }
}

function Invoke-LamConsoleGateAct {
    <#
    .SYNOPSIS
      The whole flow: ROOT -> COMPOSE -> PREVIEW -> CONFIRM -> MINT -> ATTEST. Returns
      @{ out; exit; minted; stage; digest; preview; writes; attested; attestPath; attestNote;
      missionRoot }. This is the entry point an instrument drives in library mode after installing a
      provider. Everything meant for the operator's eyes goes to the HOST (Write-Host), never to the
      pipeline, so the one object this returns is the only thing a caller captures.
    #>
    [CmdletBinding()]
    param(
        [string]$Verb, [string]$Kind, [string]$Id, [string]$Binds, [string]$MissionRoot = '.',
        [string]$TipSha, [string]$OriginUrl, [string]$RemoteRef, [string]$Reason, [int]$ExpiresMinutes = 60,
        [string]$ComposedAt, [switch]$Quiet, [string]$Ruling
    )
    $gateLabel = ("{0}-{1}" -f $Kind, $Id)
    $result = [pscustomobject]@{
        out = ''; exit = 2; minted = $false; stage = 'root'; digest = ''; preview = ''; writes = @()
        attested = $false; attestPath = ''; attestNote = ''; missionRoot = ''
    }

    # ROOT -- resolved once; only the absolute path is used from here on.
    $root = Resolve-LamConsoleMissionRoot -Root $MissionRoot
    if (-not $root.ok) {
        $msg = "lam-console: REFUSED -- $($root.reason). Nothing was composed, authorized or written."
        if (-not $Quiet) { Write-Host $msg }
        $result.out = $msg + "`n"
        return $result
    }
    $rootPath = $root.path
    $result.missionRoot = $rootPath

    $at = Get-LamConsoleComposedAt -Given $ComposedAt
    $credential = $script:LamConsoleCredentialLabel

    # COMPOSE
    $gateParams = Build-LamConsoleGateParams -K $Kind -I $Id -B $Binds -Root $rootPath `
        -Tip $TipSha -Url $OriginUrl -Ref $RemoteRef -Why $Reason -Expires $ExpiresMinutes -At $at -Credential $credential -Rul $Ruling
    $compose = Invoke-LamConsoleCompose -Verb $Verb -Params $gateParams
    if (-not $compose.ok) {
        # The tool refused at compose time (a bad -Binds, a consumed prior, a kind mismatch, a malformed
        # or out-of-window -ComposedAt). No credential is collected: composing is not authorizing.
        if (-not $Quiet) { Write-Host $compose.out }
        $result.out = $compose.out + "`n"; $result.exit = $compose.exit; $result.stage = 'compose'
        return $result
    }
    if (@($compose.writes).Count -eq 0) {
        # A no-op act (for example a revoke of an already-revoked gate): the tool did its work at
        # compose and there is nothing to authorize.
        if (-not $Quiet) { Write-Host $compose.out }
        $result.out = $compose.out + "`n"; $result.exit = $compose.exit; $result.stage = 'noop'; $result.digest = $compose.actDigest
        return $result
    }
    $result.digest = $compose.actDigest

    # PREVIEW
    $preview = Show-LamConsolePreview -Compose $compose -MissionRoot $rootPath
    $result.preview = (@($preview.lines) -join "`n")
    if (-not $Quiet) { foreach ($pl in @($preview.lines)) { Write-Host $pl } }
    if (-not $preview.ok) {
        $msg = "lam-console: REFUSED at PREVIEW -- $($preview.reason). Nothing was authorized and nothing was written."
        if (-not $Quiet) { Write-Host $msg }
        $result.out = $msg + "`n"; $result.exit = 3; $result.stage = 'preview'
        return $result
    }
    $result.writes = @($preview.writes)

    # CONFIRM (the one keystroke and the credential, both behind the seam)
    $ctx = [pscustomobject]@{ verb = $Verb; kind = $Kind; id = $Id; gate = $gateLabel; previewDigest = $compose.actDigest; missionRoot = $rootPath }
    $confirm = Invoke-LamConsoleConfirm -Context $ctx
    if (-not $confirm.ok) {
        $msg = "lam-console: REFUSED at CONFIRM -- $($confirm.reason). Nothing was written."
        if (-not $Quiet) { Write-Host $msg }
        $result.out = $msg + "`n"; $result.exit = 3; $result.stage = 'confirm'
        $att = Invoke-LamConsoleAttest -Root $rootPath -Verb $Verb -Gate $gateLabel -Digest $compose.actDigest -Credential $confirm.credential -ToolExit 3
        Set-LamConsoleAttestResult -Result $result -Attest $att
        return $result
    }
    if ($confirm.credential -ne $credential) {
        $msg = "lam-console: REFUSED -- the confirm provider reported credential '$($confirm.credential)' but the composed artifact was labelled '$credential'. Nothing was written."
        if (-not $Quiet) { Write-Host $msg }
        $result.out = $msg + "`n"; $result.exit = 3; $result.stage = 'confirm-label'
        return $result
    }

    # MINT
    $token = Register-LamConsoleToken -Verb $Verb -K $Kind -I $Id -At $at -Credential $credential -ActDigest $compose.actDigest
    $tool = Get-LamConsoleGateToolPath
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = & $tool $Verb @gateParams -ConsoleToken $token 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
        Clear-LamConsoleToken -Token $token
    }
    $out = (@($raw | ForEach-Object { [string]$_ }) -join "`n")
    if (-not $Quiet) { Write-Host $out }
    $result.out = $out + "`n"; $result.exit = $code; $result.minted = ($code -eq 0); $result.stage = 'mint'

    # ATTEST
    $att = Invoke-LamConsoleAttest -Root $rootPath -Verb $Verb -Gate $gateLabel -Digest $compose.actDigest -Credential $credential -ToolExit $code
    Set-LamConsoleAttestResult -Result $result -Attest $att
    return $result
}

function Set-LamConsoleAttestResult {
    <#
      RECORD THE ATTESTATION OUTCOME ON THE RESULT, AND REPORT A FAILURE ON THE CONSOLE (found in review). A
      line that did not land is written to the host even under -Quiet -- the operator must be told the
      record of the act is missing -- and appended to the result's out text. The exit code already
      obtained is NOT changed: the act happened (or was refused) regardless of whether its record landed.
    #>
    param($Result, $Attest)
    $Result.attested = [bool]$Attest.ok
    $Result.attestPath = [string]$Attest.path
    if ($Attest.ok) {
        $Result.attestNote = 'attested at ' + $Attest.path
    } else {
        $note = "lam-console: WARNING -- the attestation record did NOT land ($($Attest.reason)). The act's exit code ($($Result.exit)) stands; the operator-acts.log line for it is MISSING and must be recorded by hand."
        $Result.attestNote = $note
        $Result.out = $Result.out + $note + "`n"
        Write-Host $note
    }
}

# =================================================================================================
# MAIN. Runs only when this file is INVOKED, never when it is dot-sourced (library mode).
# =================================================================================================
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Command) {
        Write-Output "lam-console: a verb is required -- approve, reapprove, revoke or settle."
        Write-Output "  run 'tools\lam\lam-console.ps1 -?' for the parameters, which are mission-gate.ps1's own."
        exit 2
    }
    $r = Invoke-LamConsoleGateAct -Verb $Command -Kind $Kind -Id $Id -Binds $Binds -MissionRoot $MissionRoot `
            -TipSha $TipSha -OriginUrl $OriginUrl -RemoteRef $RemoteRef -Reason $Reason -ExpiresMinutes $ExpiresMinutes `
            -ComposedAt $ComposedAt -Ruling $Ruling
    exit $r.exit
}
