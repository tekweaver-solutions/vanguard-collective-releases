#Requires -Version 5.1
<#
.SYNOPSIS
  SUBJECT INTEGRITY for fresh-identity validators. (LAM-ACCEPT
  K-3.)

.DESCRIPTION
  WHY THIS EXISTS. K-3 requires the validator role to be "read-only plus its result file". The
  FILE-TOOL layer delivers that -- `dontAsk` auto-denies any tool not named in `permissions.allow`.
  The SHELL layer does not: `validator.json` allows bare `Bash`/`PowerShell` because a validator
  that cannot run commands cannot do the one job V-1 exists for, and redirection targets are checked
  against deny rules only. So the write surface is bounded by an enumeration, which is precisely the
  shape K-3's own words forbade -- and closing it would leave a reader that can only read, an
  instrument this build has three rounds of evidence against.

  SO THE CONTROL MOVES FROM PREVENTION TO DETECTION, AND SAYS SO. The permission layer cannot stop a
  validator writing its subject. The ORCHESTRATOR can prove whether it did: hash every artifact the
  validator is given to judge BEFORE the spawn, ledger those hashes WITH the spawn line, and
  re-hash them on return.

  ANY MISMATCH VOIDS THE VERDICT, RAISES A HALT, AND SPENDS THE IDENTITY. Not "flags", not
  "re-reads", not "asks the validator about it". A verdict rendered over a subject that moved under
  it is not a weaker verdict -- it is not a verdict, because nobody can say which bytes it describes.
  Spending the identity follows from V-1's own rule that a REFUTED gets a new validator rather than
  a re-ask: an identity that has seen a moving subject cannot un-see it.

  THIS IS NOT A BOUNDARY. A validator can still write a subject. What it
  cannot do is have that go unnoticed, or have the resulting verdict counted -- and a control that
  catches every occurrence after the fact is worth more than a rule that reads as prevention and
  enforces nothing. That distinction is the whole reason this file is not another deny list.

  SCOPE, STATED: this covers artifacts named as SUBJECTS. A validator that writes something nobody
  declared a subject is outside this control's reach, and the residual is real -- which is why the
  subject list is derived from the contract paths a work package names rather than from the
  validator's own account of what it read.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('capture', 'verify')][string]$Mode,
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    # SUBJECTS COME FROM A FILE, ONE PATH PER LINE, and that is a deliberate choice rather than a
    # style preference. A `[string[]]` parameter does NOT bind multiple values through
    # `powershell -File`: the extra values fall through to positional binding and the invocation
    # fails with "a positional parameter cannot be found". This build has already lost time to the
    # same trap on a comma-separated `-Tags`, so the subject list travels as data, where the arity
    # is unambiguous and reviewable.
    [Parameter(Mandatory = $true)][string]$SubjectsFile,
    [string]$BaselineFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SubjectsFile)) { throw "subjects file not found: $SubjectsFile" }
$Subjects = @([System.IO.File]::ReadAllLines($SubjectsFile) |
              ForEach-Object { $_.Trim() } |
              Where-Object { $_ -and -not $_.StartsWith('#') })
if ($Subjects.Count -eq 0) { throw "subjects file is empty: $SubjectsFile -- an empty subject set would make integrity vacuously true" }

function Get-SubjectHashes {
    param([string]$Root, [string[]]$Paths)
    $out = @()
    foreach ($rel in ($Paths | Sort-Object -Unique)) {
        if (-not $rel) { continue }
        # RESOLVE BEFORE MEASURING. A subject named with `../` (WP-6's subjects live in the smoke
        # repository) produces a joined path like `<root>\../lam-smoke/...` whose LENGTH exceeds the
        # resolved FullName it is later subtracted from, and the directory walk died with
        # "startIndex cannot be larger than length of string". Found by running it, not by reading
        # it -- the file-subject path had no such arithmetic and looked fine.
        $joined = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $Root $rel }
        $abs = $joined
        try { $abs = [System.IO.Path]::GetFullPath($joined) } catch { $abs = $joined }
        if (Test-Path -LiteralPath $abs -PathType Leaf) {
            $out += [pscustomobject]@{
                path   = ($rel -replace '\\', '/')
                sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $abs).Hash.ToLowerInvariant()
                bytes  = (Get-Item -LiteralPath $abs).Length
                state  = 'present'
            }
        }
        elseif (Test-Path -LiteralPath $abs -PathType Container) {
            # A DIRECTORY IS HASHED OVER ITS MEMBERS, name and content both, so a file ADDED or
            # REMOVED moves the hash exactly as an edit does. A subject that is a directory whose
            # membership changed is as compromised as one whose bytes changed.
            $acc = New-Object System.Text.StringBuilder
            foreach ($f in @(Get-ChildItem -LiteralPath $abs -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object FullName)) {
                $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
                [void]$acc.AppendLine("$($f.FullName.Substring($abs.Length).TrimStart('\','/') -replace '\\','/') $h")
            }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($acc.ToString())
            $sha = [System.BitConverter]::ToString(
                       ([System.Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)
                   ).Replace('-', '').ToLowerInvariant()
            $out += [pscustomobject]@{ path = ($rel -replace '\\', '/'); sha256 = $sha; bytes = $bytes.Length; state = 'directory' }
        }
        else {
            # ABSENT IS A STATE, NOT A SKIP. A subject that does not exist at capture and DOES at
            # verify has appeared under the validator, which is a mismatch worth the same refusal.
            $out += [pscustomobject]@{ path = ($rel -replace '\\', '/'); sha256 = ''; bytes = 0; state = 'absent' }
        }
    }
    return $out
}

$hashes = Get-SubjectHashes -Root $RepoRoot -Paths $Subjects

if ($Mode -eq 'capture') {
    $doc = [ordered]@{ captured_subjects = @($hashes) }
    if ($BaselineFile) {
        [System.IO.File]::WriteAllText($BaselineFile, ($doc | ConvertTo-Json -Depth 6),
                                       (New-Object System.Text.UTF8Encoding($false)))
    }
    $doc | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

# --- verify ------------------------------------------------------------------------------------
if (-not $BaselineFile -or -not (Test-Path -LiteralPath $BaselineFile)) {
    # NO BASELINE IS A FAILURE, NOT A PASS. If the capture did not happen, nothing can attest that
    # the subjects held still, and "we did not look" must never read as "nothing moved".
    Write-Output "SUBJECT-INTEGRITY: NO BASELINE at '$BaselineFile' -- integrity cannot be asserted. Treated as a VIOLATION: an unrun check is not a passed check."
    exit 2
}
$base = ([System.IO.File]::ReadAllText($BaselineFile) | ConvertFrom-Json).captured_subjects
$byPath = @{}
foreach ($b in @($base)) { $byPath[[string]$b.path] = $b }

$violations = @()
foreach ($h in $hashes) {
    $b = $byPath[$h.path]
    if ($null -eq $b) { $violations += "$($h.path): not in the baseline -- the subject set changed between capture and verify"; continue }
    if ([string]$b.state -ne [string]$h.state) { $violations += "$($h.path): state $($b.state) -> $($h.state)"; continue }
    if ([string]$b.sha256 -ne [string]$h.sha256) {
        $violations += "$($h.path): sha256 $($b.sha256) -> $($h.sha256)"
    }
}
foreach ($p in $byPath.Keys) {
    if (-not (@($hashes | Where-Object { $_.path -eq $p }).Count)) { $violations += "$p : present at capture, missing from the verify set" }
}

if ($violations.Count -eq 0) {
    Write-Output "SUBJECT-INTEGRITY: OK -- $($hashes.Count) subject(s) byte-identical between capture and verify."
    foreach ($h in $hashes) { Write-Output "  $($h.path)  $($h.state)  $(if ($h.sha256) { $h.sha256.Substring(0,16) } else { '(absent)' })" }
    exit 0
}
Write-Output "SUBJECT-INTEGRITY: VIOLATED -- $($violations.Count) subject(s) moved while the validator held them."
foreach ($v in $violations) { Write-Output "  $v" }
Write-Output ""
Write-Output "THE VERDICT IS VOID. It is not weakened and it is not re-readable: nobody can say which"
Write-Output "bytes it describes. Raise a HALT, spend the identity, and spawn a new one against a"
Write-Output "re-captured baseline. Do NOT ask the validator about it -- its account of the window is"
Write-Output "exactly the thing now in question."
exit 3
