#Requires -Version 5.1
<#
.SYNOPSIS
  transcribe-validator-results -- transcribe bound LAM validator results into
  .mission/validator-results/, the store tools/mission-close-milestone.ps1's A-127/A-128 gate reads.
  THE BRIDGE, NOT THE CURE.

.DESCRIPTION
  THE DEFECT, from the register:

    "THE CLOSE-MILESTONE CLI READS A STORE THE LAM VALIDATORS NEVER WRITE: A-127 requires
     .mission/validator-results/manifest.json entries (verdict pass, current attempt) for every roster
     assertion; the LAM validators' results live at tests/lam/ bound on the spawn ledger, and the
     manifest ended at A-568. BRIDGED, NOT CURED, by a transcription ceremony
     (eight records, every field the validator's own text, each source sha256
     asserted equal to its bound result_sha256; one explicit-pathspec commit, ledgered).
     The cure -- the CLI reading the spawn-ledger binding -- is FW-1. defect-cure, S, FW-1."

  THE HALF OF THAT DEFECT THIS TOOL CURES is the SECOND half: the bridge was a ONE-ARC SCRIPT IN THE RUNTIME
  PLANE, re-authored by every arc. Two copies stood side by side --
  .mission-runtime/lam/helpers/transcribe-validator-results.py and
  .mission-runtime/lam/helpers/transcribe-validator-results-l22.py -- and the second exists
  only because the first could not be re-pointed at another arc. They had already diverged in five
  places: the hardcoded PLAN of (assertion, seq) pairs, the session id, the attest string, the commit
  message, and a first act that ABORTS when the manifest already carries the arc's first assertion.
  That last divergence broke the check-only mode outright: driven with no flag after its own write, the
  second helper exits 1 with "STOP: the manifest already carries A-576" and verifies nothing -- a
  check-only mode that cannot check.

  So this tool is PARAMETERISED BY ASSERTION IDS with no arc baked in; it READS IDENTITY FROM THE SPAWN
  LEDGER (not from the result files, which do not share a schema across an arc); it ASSERTS EACH SOURCE
  SHA256 against the result_sha256 bound on its own `complete` line and REFUSES on any inequality,
  printing both figures; it COPIES EVERY CONTENT STRING VERBATIM, the whole document key by key; and its
  CHECK-ONLY MODE (the default) RUNS OVER AN ALREADY-TRANSCRIBED ARC, reporting manifest presence as a
  FACT rather than aborting on it. In -Write mode, refusing to overwrite an existing entry is correct
  and stays.

  THE CURE PROPER -- the close-milestone CLI reading the spawn-ledger binding directly, so that no
  transcription is needed at all -- is FW-1 work named on the row and is NOT in this tool.

  PowerShell 5.1 has no YAML parser and the validator results are YAML, so the work is done by
  tools/lam/transcribe_validator_results.py beside this file, under the framework venv's interpreter.

.EXAMPLE
  # CHECK ONLY -- writes nothing, and may be run over an arc that is already transcribed.
  tools\lam\transcribe-validator-results.ps1 -Arc <arc> `
      -Assertion A-576,A-577,A-578,A-579,A-580,A-581,A-582

.EXAMPLE
  # WRITE -- the operator's act. Refuses any assertion the store already carries.
  tools\lam\transcribe-validator-results.ps1 -Arc <arc> -Assertion A-576,A-577 -Write
#>
[CmdletBinding()]
param(
    # Assertion ids (A-576), or explicit id:seq pairs (A-576:149) where ledger resolution cannot settle
    # the spawn sequence on its own. NOTHING about any arc is baked into this tool.
    [Parameter(Mandatory)][string[]]$Assertion,

    # The arc label these results belong to. Names the records; appears in the prose.
    [Parameter(Mandatory)][string]$Arc,

    # The repository root the mission planes hang off. Defaults to the parent of this script's tools dir.
    [string]$Root,

    # Write the records and the manifest entries. WITHOUT IT THE TOOL WRITES NOTHING.
    [switch]$Write,

    [string]$SourceTemplate = 'tests/lam/validator-{assertion}.result.yaml',
    [string]$SpawnLedger = '.mission-runtime/lam/spawn-ledger.jsonl',
    [string]$ResultsDir = '.mission/validator-results',

    # The ruling this transcription runs under, recorded verbatim on every record.
    [string]$Law = '',

    # The orchestrator/operator session id, recorded on every record.
    [string]$Session = '',

    # STOP on any result whose verdict is not PASS.
    [switch]$RequirePass,

    # An explicit interpreter. Otherwise: $env:MISSION_PYTHON, then tools\.venv\Scripts\python.exe,
    # then `python` on PATH.
    [string]$PythonExe
)

$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $PSScriptRoot
if (-not $Root -or $Root -eq '') { $Root = Split-Path -Parent $toolsDir }
$Root = (Resolve-Path -LiteralPath $Root).Path

$worker = Join-Path $PSScriptRoot 'transcribe_validator_results.py'
if (-not (Test-Path -LiteralPath $worker)) {
    Write-Error "transcribe_validator_results.py not found beside this script at $worker"
    exit 3
}

# --- resolve the interpreter (PowerShell 5.1 has no YAML parser; PyYAML lives in the framework venv) ---
$py = $null
foreach ($cand in @(
        $PythonExe,
        $env:MISSION_PYTHON,
        (Join-Path $toolsDir '.venv\Scripts\python.exe'),
        (Join-Path $toolsDir '.venv/bin/python'))) {
    if ($cand -and (Test-Path -LiteralPath $cand)) { $py = (Resolve-Path -LiteralPath $cand).Path; break }
}
if (-not $py) {
    $onPath = Get-Command python -ErrorAction SilentlyContinue
    if ($onPath) { $py = $onPath.Source }
}
if (-not $py) {
    Write-Error "no Python interpreter found. Run 'uv sync' in tools\, or pass -PythonExe."
    exit 3
}

$argv = @($worker)
foreach ($a in $Assertion) { $argv += $a }
$argv += @('--root', $Root, '--arc', $Arc, '--source-template', $SourceTemplate,
           '--spawn-ledger', $SpawnLedger, '--results-dir', $ResultsDir)
if ($Law -and $Law -ne '') { $argv += @('--law', $Law) }
if ($Session -and $Session -ne '') { $argv += @('--session', $Session) }
if ($RequirePass) { $argv += '--require-pass' }
if ($Write) { $argv += '--write' }

& $py @argv
exit $LASTEXITCODE
