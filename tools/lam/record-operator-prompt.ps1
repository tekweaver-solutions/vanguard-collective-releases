#Requires -Version 5.1
<#
.SYNOPSIS
  UserPromptSubmit hook -- the zero-paste attestation's second, independent record.
  (LAM-ACCEPT WP-6)

.DESCRIPTION
  WP-6 asserts that exactly ONE operator act occurred across S-1..S-5, and that it was the push
  gate. A count is only as good as the thing that produced it, so the attestation rests on two
  records that fail in different ways rather than on one:

    (a) GATE ARTIFACTS. A gate can only be created by a human running mission-gate.ps1: the guard
        hard-denies every agent role from writing under the gates directory (T-3, driven in WP-4).
        Each gate artifact is therefore one operator act, self-recording.

    (b) THIS HOOK. Every interactive prompt submitted in the smoke repo appends one line here.
        The smoke mission is driven entirely by the runner and the headless CLI, so a correct run
        leaves this log EMPTY. A non-empty log means a human typed into the mission -- which is
        exactly what "zero paste" denies.

  (a) counts what a human DID; (b) counts what a human SAID. Neither can cover for the other, and
  the attestation requires both to agree: one act by (a), zero by (b).

  CONTENT-FREE BY CONSTRUCTION. It records a timestamp, the session id and the prompt's BYTE
  LENGTH -- never the prompt text. The operator ruling on content applies unchanged: an
  evidence store that embeds session prose is a different artifact than the one this program is
  building. A length is enough to prove that something was typed; the words are not the plane's
  business.

  It never blocks and never fails a prompt: it exits 0 on every path, because an attestation
  mechanism that can stop the work it observes is a liability.
#>
[CmdletBinding()]
param()

try {
    # A DISPATCHED WORKER'S PROMPT IS NOT AN OPERATOR ACT. The runner submits the dispatch as the
    # worker's prompt, so this hook fires for it -- and the first live run duly logged that
    # submission, which would have made the zero-paste attestation read one operator act where a
    # human had done nothing. The runner marks every worker it spawns; seeing that marker here
    # means the prompt came from the machinery, not from a person.
    #
    # Recorded as a distinct kind rather than dropped, so the log still shows that a prompt
    # happened. An attestation that silently discards events is not an attestation.
    if ($env:LAM_DISPATCH) {
        $root = $env:CLAUDE_PROJECT_DIR
        if (-not $root) { $root = (Get-Location).Path }
        $dir = Join-Path $root '.mission-runtime'
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = "{0} kind=worker dispatch={1}" -f `
                ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)), $env:LAM_DISPATCH
        Add-Content -LiteralPath (Join-Path $dir 'operator-prompts.log') -Value $line -Encoding UTF8
        exit 0
    }

    $raw = ''
    try { $raw = [Console]::In.ReadToEnd() } catch { $raw = '' }

    $sessionId = ''
    $promptLen = 0
    try {
        if ($raw -and $raw.Trim()) {
            $p = $raw | ConvertFrom-Json
            if ($p.PSObject.Properties.Name -contains 'session_id') { $sessionId = [string]$p.session_id }
            foreach ($n in @('prompt', 'user_prompt', 'text')) {
                if ($p.PSObject.Properties.Name -contains $n) {
                    $promptLen = [System.Text.Encoding]::UTF8.GetByteCount([string]$p.$n)
                    break
                }
            }
        }
    } catch { }

    $root = $env:CLAUDE_PROJECT_DIR
    if (-not $root) { $root = (Get-Location).Path }
    $dir = Join-Path $root '.mission-runtime'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $log = Join-Path $dir 'operator-prompts.log'

    $line = "{0} kind=operator session={1} prompt_bytes={2}" -f `
            ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)), $sessionId, $promptLen

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($line + "`n")
    for ($i = 1; $i -le 10; $i++) {
        try {
            $fs = [System.IO.File]::Open($log, [System.IO.FileMode]::Append,
                                         [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
            break
        } catch [System.IO.IOException] { Start-Sleep -Milliseconds (10 * $i) }
    }
}
catch { }

exit 0
