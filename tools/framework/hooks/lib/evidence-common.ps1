#Requires -Version 5.1
<#
.SYNOPSIS
  Shared library for the framework evidence-plane hooks (A1).

.DESCRIPTION
  Citation convention: decisions from
  docs/framework/vanguard-collective-local-modes-v2.1.md are cited as LM2-ADR-0NN or as
  "design SS<n>". A bare ADR-0NN always denotes the on-disk file under
  tools/mission-cli/config/. The two namespaces collide numerically and are NOT related.

  This library is dot-sourced by the hook entry points. It holds path resolution, hashing,
  append-only log writing, atomic stream allocation, sealed-prefix extension verification
  (cure D10), denial capture and transcript call reconciliation (cure D8),
  path canonicalization, and the evidence state machine. It performs NO I/O on import.

  Design refs: SS4.1 (hook-captured evidence store, write-path enforcement, crash-before-
  finalize), SS12.3 (Evidence Manifest artifact).
#>

Set-StrictMode -Version Latest

# Kept in lockstep with the `const` in docs/framework/evidence-manifest.schema.json.
#   1.0.0 -> 1.1.0: declared _precompact entry variant; streams_committed.
#   1.1.0 -> 1.2.0: hook_errors_present + hook_errors_sha256.
#   1.2.0 -> 1.3.0 (cure D8): declared _denied entry variant; call_completeness block.
# The optional `reconciled` flag is added without a version bump: it is additive, optional,
# and absent on every manifest that does not need it.
# Cure D10 adds `log_bytes_sealed` and `finalize_count` under the same precedent:
# additive, optional, absent on every pre-D10 manifest, which stays readable (the sealed
# prefix is then DERIVED from entry_count + unparsable_lines -- see
# Get-EvidenceSealedPrefixLength).
$script:EvidenceSchemaVersion = '1.3.0'

# --- repo root -------------------------------------------------------------------------
function Get-EvidenceRepoRoot {
    if ($env:CLAUDE_PROJECT_DIR -and (Test-Path -LiteralPath $env:CLAUDE_PROJECT_DIR)) {
        return (Resolve-Path -LiteralPath $env:CLAUDE_PROJECT_DIR).Path
    }
    $d = Split-Path -Parent $PSScriptRoot          # tools/framework/hooks
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d '.git')) { return $d }
        $parent = Split-Path -Parent $d
        if ($parent -eq $d) { break }
        $d = $parent
    }
    throw "evidence-common: cannot resolve repo root (no CLAUDE_PROJECT_DIR, no .git ancestor)."
}

# --- dispatch id -----------------------------------------------------------------------
function Get-EvidenceDispatchId {
    param([string]$SessionId)
    if ($env:MISSION_DISPATCH_ID) { return $env:MISSION_DISPATCH_ID }
    $root = Get-EvidenceRepoRoot
    $ptr = Join-Path $root '.mission-runtime\evidence\CURRENT_DISPATCH'
    if (Test-Path -LiteralPath $ptr) {
        $v = ([System.IO.File]::ReadAllText($ptr)).Trim()
        if ($v) { return $v }
    }
    if ($SessionId) { return "session-$SessionId" }
    return 'session-unknown'
}

function Get-EvidenceRuntimeDir {
    param([string]$Root, [string]$DispatchId)
    Join-Path $Root ".mission-runtime\evidence\$DispatchId"
}

function Get-EvidenceCommittedDir {
    param([string]$Root, [string]$DispatchId)
    Join-Path $Root ".mission\evidence\$DispatchId"
}

# --- hashing ---------------------------------------------------------------------------
function Get-Sha256OfString {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { $Text = '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

function Get-Sha256OfFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

# Hash over a byte buffer, optionally over only its first $Count bytes. The prefix form is
# what makes append-verified supersession (cure D10) checkable: the sealed
# prefix of a grown log must still hash to the recorded log_sha256, byte for byte.
function Get-Sha256OfBytes {
    param([AllowNull()][byte[]]$Bytes, [long]$Count = -1)
    if ($null -eq $Bytes) { return $null }
    if ($Count -lt 0 -or $Count -gt $Bytes.Length) { $Count = $Bytes.Length }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($Bytes, 0, [int]$Count) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

# --- UTF-8 byte-accurate truncation (cure N-f) --------------------------------------------
# The inline excerpt cap is a BYTE budget, not a character budget: .Length counts UTF-16 code
# units, which diverges from encoded size for any non-ASCII output. Truncation never splits a
# surrogate pair.
function Get-Utf8ByteCount {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return 0 }
    return [System.Text.Encoding]::UTF8.GetByteCount($Text)
}

function Get-Utf8TruncatedString {
    param([AllowNull()][string]$Text, [int]$MaxBytes)
    if ($null -eq $Text) { return '' }
    if ([System.Text.Encoding]::UTF8.GetByteCount($Text) -le $MaxBytes) { return $Text }
    $lo = 0; $hi = $Text.Length
    while ($lo -lt $hi) {
        $mid = [int][Math]::Floor(($lo + $hi + 1) / 2)
        if ([System.Text.Encoding]::UTF8.GetByteCount($Text.Substring(0, $mid)) -le $MaxBytes) { $lo = $mid }
        else { $hi = $mid - 1 }
    }
    if ($lo -gt 0 -and [char]::IsHighSurrogate($Text[$lo - 1])) { $lo-- }
    return $Text.Substring(0, $lo)
}

# --- defensive field access (cure B1) -------------------------------------------------------
# Set-StrictMode -Version Latest throws on a missing property. Entries in the log are NOT all
# the same shape (a _precompact entry has no stdout_sha256), so every read of a log entry field
# goes through here. The B1 defect was exactly this: a direct property read on a shape that
# legitimately lacked the field crashed the finalizer, and the outer catch swallowed it.
function Get-EntryField {
    param($Entry, [string]$Name, $Default = $null)
    if ($null -eq $Entry) { return $Default }
    if ($Entry.PSObject.Properties.Name -contains $Name) {
        $v = $Entry.$Name
        if ($null -ne $v) { return $v }
    }
    return $Default
}

# --- append-only log write --------------------------------------------------------------
function Add-EvidenceLogLine {
    param([string]$LogPath, $Entry)
    $dir = Split-Path -Parent $LogPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = ($Entry | ConvertTo-Json -Compress -Depth 12)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json + "`n")
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try {
            $fs = [System.IO.File]::Open($LogPath, [System.IO.FileMode]::Append,
                                         [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
            return
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds (10 * $attempt)
        }
    }
    throw "evidence-common: could not append to $LogPath after 20 attempts."
}

# --- atomic stream allocation (cure D11) ------------------------------------------------------
# THE DEFECT THIS REPLACES. The pre-cure hook computed seq = (non-blank log lines) + 1, formed
# the stream filename from it, and wrote with a plain overwrite. Two hooks that both read length
# N both derived N+1: the second write silently destroyed the first payload, the manifest then
# declared one file twice and read clean over it. Driven on this repository three times --
# manifest entries 13/14 of one session (1 ms apart), entries 3/4 of a second session
# (16 ms apart, a READ-ONLY session), and a three-way collision at seq 7 in the D11 build
# session itself (18 ms spread). A second failure class was driven at the same window: the two
# overwrite opens can also collide in a sharing violation, in which case the losing call's
# evidence vanishes entirely. A2's N-e resolution ("seq is an ordering hint, never a key") is
# FALSIFIED by construction -- seq IS the filename, therefore a key.
#
# THE CURE: ALLOCATION IS CREATION. The allocator probes upward from StartSeq, opening each
# candidate with FileMode::CreateNew -- an OS-atomic create exactly one contender can win per
# name -- and the WINNING number becomes the entry's seq, its filename, and its log-line seq.
# seq is UNIQUE BY CONSTRUCTION; contention moves the loser to the next name instead of
# destroying bytes or throwing. One entry, one file, is the rule from here on
# (Get-EvidenceStreamIdentityFindings is the detector).
#
# Name-taken is the expected contention signal and is distinguished from other IO failure by
# existence; any other failure propagates to the caller's capture-error path (recorded to
# hook-errors.log, hook exits 0, the gap stays detectable -- the doctrine is unchanged).
function New-EvidenceStreamFile {
    param([string]$StreamDir, [int]$StartSeq, [string]$Tool,
          [AllowNull()][string]$Stdout, [AllowNull()][string]$Stderr)
    if ($null -eq $Stdout) { $Stdout = '' }
    if ($null -eq $Stderr) { $Stderr = '' }
    if (-not (Test-Path -LiteralPath $StreamDir)) {
        New-Item -ItemType Directory -Path $StreamDir -Force | Out-Null
    }
    $seq = $StartSeq
    if ($seq -lt 1) { $seq = 1 }
    for ($attempt = 1; $attempt -le 10000; $attempt++) {
        $name = ('{0:d6}.json' -f $seq)
        $full = Join-Path $StreamDir $name
        $fs = $null
        try {
            $fs = [System.IO.File]::Open($full, [System.IO.FileMode]::CreateNew,
                                         [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        } catch [System.IO.IOException] {
            if (Test-Path -LiteralPath $full) { $seq++; continue }
            throw
        }
        try {
            $body  = [ordered]@{ seq = $seq; tool = $Tool; stdout = $Stdout; stderr = $Stderr }
            $json  = ($body | ConvertTo-Json -Depth 8)
            $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
            $fs.Write($bytes, 0, $bytes.Length)
        } finally { $fs.Dispose() }
        return [pscustomobject]@{ seq = $seq; rel = "streams/$name"; full = $full }
    }
    throw "evidence-common: could not allocate a stream name under $StreamDir after 10000 attempts."
}

# Same array-return discipline as Get-EvidencePathHits: a List, never `,@()`.
function Read-EvidenceLog {
    param([string]$LogPath)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $LogPath)) { return $out.ToArray() }
    foreach ($line in [System.IO.File]::ReadAllLines($LogPath)) {
        if (-not $line.Trim()) { continue }
        try { $out.Add(($line | ConvertFrom-Json)) }
        catch { $out.Add([pscustomobject]@{ _unparsable = $true; _raw = $line }) }
    }
    return $out.ToArray()
}

# --- sealed-prefix derivation and extension verdict (cure D10) --------------------------------
# THE DEFECT THIS CURES (E5-iv). Stop fires at the end of every assistant TURN; A1 treated it
# as end-of-DISPATCH. The first turn's Stop finalized permanently, every later turn was logged
# but orphaned, and the state machine derived TAMPERED -- the word reserved for evidence
# tampering -- for sessions that merely continued working. Measured live on four residue
# stores: manifests frozen at entry_count 14/33/55 over logs grown to 52/183/177 lines, with
# seventeen "REFUSED to finalize TAMPERED" entries and zero actual tampering anywhere.
#
# THE CURE keeps the detector and splits the verdict: "the log grew by append" and "the log's
# existing sealed bytes changed" are different facts. The sealed prefix of the log -- the
# bytes log_sha256 was computed over at finalization -- must still hash to log_sha256. If it
# does and the log is longer, that is GREW (a lifecycle fact; a newer finalize is pending at
# the next Stop). If it does not, or the log is shorter than the sealed prefix, that is
# TAMPERED, exactly as before. Every degradation is CONSERVATIVE: a prefix that cannot be
# derived, or a manifest without a recorded hash, derives TAMPERED, never GREW -- this
# function can fail toward a false alarm, never toward laundering.
#
# THE PREFIX LENGTH comes from `log_bytes_sealed` where the manifest records it (post-D10
# finalizers always do). PRE-D10 MANIFESTS carry no such field and are NOT migrated
# (re-read, never rewrite); for them the prefix is DERIVED from what they do
# carry: the log_sha256 was computed over the whole log file at finalization, and that file
# held exactly (entry_count + unparsable_lines) non-blank lines, so the sealed prefix ends at
# that non-blank line's terminating newline. If the derivation lands on the wrong byte -- a
# blank-line pathology the writer never produces -- the prefix hash simply fails to re-derive
# and the verdict degrades to TAMPERED, the conservative direction.
function Get-EvidenceSealedPrefixLength {
    param($Manifest, [byte[]]$LogBytes)
    $explicit = Get-EntryField $Manifest 'log_bytes_sealed' $null
    if ($null -ne $explicit) { return [long]$explicit }
    $ec = Get-EntryField $Manifest 'entry_count' $null
    if ($null -eq $ec) { return $null }
    $target = [int]$ec + [int](Get-EntryField $Manifest 'unparsable_lines' 0)
    if ($target -lt 0) { return $null }
    if ($target -eq 0) { return [long]0 }
    if ($null -eq $LogBytes) { return $null }
    $nonBlank = 0
    $lineStart = 0
    for ($i = 0; $i -lt $LogBytes.Length; $i++) {
        if ($LogBytes[$i] -eq 10) {
            $blank = $true
            for ($j = $lineStart; $j -lt $i; $j++) {
                $b = $LogBytes[$j]
                if ($b -ne 32 -and $b -ne 9 -and $b -ne 13) { $blank = $false; break }
            }
            if (-not $blank) {
                $nonBlank++
                if ($nonBlank -eq $target) { return [long]($i + 1) }
            }
            $lineStart = $i + 1
        }
    }
    if ($lineStart -lt $LogBytes.Length) {
        $blank = $true
        for ($j = $lineStart; $j -lt $LogBytes.Length; $j++) {
            $b = $LogBytes[$j]
            if ($b -ne 32 -and $b -ne 9 -and $b -ne 13) { $blank = $false; break }
        }
        if (-not $blank) {
            $nonBlank++
            if ($nonBlank -eq $target) { return [long]$LogBytes.Length }
        }
    }
    return $null
}

# Verdicts, one per member of the split:
#   intact      -- the whole log still hashes to log_sha256. FINALIZED.
#   grew        -- the sealed prefix re-derives AND the log is strictly longer. GREW.
#   truncated   -- the log is shorter than the sealed prefix. TAMPERED (a shorter log can
#                  never supersede a longer record -- the original refusal rationale, now a
#                  property of the predicate).
#   mutated     -- the sealed prefix does NOT re-derive. TAMPERED. This includes
#                  mutate-then-extend: growth cannot mask mutation, because the verdict is
#                  taken over the sealed prefix, not over lengths.
#   undecidable -- no recorded hash, or no derivable prefix. TAMPERED (conservative).
function Test-EvidenceLogExtension {
    param($Manifest, [string]$LogPath)
    $recorded = [string](Get-EntryField $Manifest 'log_sha256' '')
    if (-not (Test-Path -LiteralPath $LogPath)) {
        return [pscustomobject]@{ verdict = 'truncated'; sealed_bytes = $null; actual_bytes = [long]0
                                  recorded_sha256 = $recorded; prefix_sha256 = $null }
    }
    $bytes = [System.IO.File]::ReadAllBytes($LogPath)
    if (-not $recorded) {
        return [pscustomobject]@{ verdict = 'undecidable'; sealed_bytes = $null; actual_bytes = [long]$bytes.Length
                                  recorded_sha256 = $null; prefix_sha256 = $null }
    }
    $full = Get-Sha256OfBytes -Bytes $bytes
    if ($full -eq $recorded) {
        return [pscustomobject]@{ verdict = 'intact'; sealed_bytes = [long]$bytes.Length; actual_bytes = [long]$bytes.Length
                                  recorded_sha256 = $recorded; prefix_sha256 = $full }
    }
    $sealed = Get-EvidenceSealedPrefixLength -Manifest $Manifest -LogBytes $bytes
    if ($null -eq $sealed) {
        return [pscustomobject]@{ verdict = 'undecidable'; sealed_bytes = $null; actual_bytes = [long]$bytes.Length
                                  recorded_sha256 = $recorded; prefix_sha256 = $null }
    }
    if ($bytes.Length -lt $sealed) {
        return [pscustomobject]@{ verdict = 'truncated'; sealed_bytes = $sealed; actual_bytes = [long]$bytes.Length
                                  recorded_sha256 = $recorded; prefix_sha256 = $null }
    }
    $prefix = Get-Sha256OfBytes -Bytes $bytes -Count $sealed
    if ($prefix -eq $recorded) {
        if ($bytes.Length -gt $sealed) {
            return [pscustomobject]@{ verdict = 'grew'; sealed_bytes = $sealed; actual_bytes = [long]$bytes.Length
                                      recorded_sha256 = $recorded; prefix_sha256 = $prefix }
        }
        return [pscustomobject]@{ verdict = 'intact'; sealed_bytes = $sealed; actual_bytes = [long]$bytes.Length
                                  recorded_sha256 = $recorded; prefix_sha256 = $prefix }
    }
    return [pscustomobject]@{ verdict = 'mutated'; sealed_bytes = $sealed; actual_bytes = [long]$bytes.Length
                              recorded_sha256 = $recorded; prefix_sha256 = $prefix }
}

# --- the state machine (design SS4.1 crash-before-finalize; SS12.3 immutability) ---------
# ABSENT    -- no log and no manifest.
# PARTIAL   -- a log exists but no finalized manifest does. Consumption BLOCKED; forensic
#              re-ground FULLY SUPPORTED.
# FINALIZED -- manifest carries finalized_at AND its log_sha256 still matches the log on disk.
# GREW      -- manifest finalized, and the log is a VERIFIED append-extension of the sealed
#              prefix (cure D10). Not tampering: a session that continued working.
#              Consumption BLOCKED (the manifest does not cover the tail); a newer finalize is
#              pending at the next Stop, which supersedes with the prior manifest retained.
# TAMPERED  -- manifest is finalized and the sealed bytes cannot be re-derived: the prefix
#              hash fails, or the log is shorter than the sealed prefix. Post-D10 this
#              word means what it says -- growth by append never derives it.
#
# NOTE (A1 elaboration, flagged for A2): TAMPERED is not named in design SS12.3. It is the
# detection state for SS12.3's stated invariant "immutable after finalization" -- an invariant
# with no detector is an assertion. A2 aligns the vocabulary.
#
# CURE N-h: `reason` describes ONLY what was observed on disk. The previous wording asserted
# "session ended before Stop finalized", which is a cause this function cannot know -- and the
# B1 defect was a live counterexample (the session ended normally; the finalizer crashed).
function Get-EvidenceState {
    param([string]$Root, [string]$DispatchId)
    $rt = Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId
    $logPath = Join-Path $rt 'log.jsonl'
    $manPath = Join-Path $rt 'manifest.json'
    $errPath = Join-Path $rt 'hook-errors.log'
    $hasLog = Test-Path -LiteralPath $logPath
    $hasMan = Test-Path -LiteralPath $manPath
    $errHint = if (Test-Path -LiteralPath $errPath) { " hook-errors.log EXISTS -- read it before concluding anything about cause." } else { "" }

    if (-not $hasLog -and -not $hasMan) {
        # The hint rides here too. Without it, a dispatch whose FIRST hook errored
        # -- no log, no manifest, an error log sitting right beside them -- read "no log and no
        # manifest on disk", indistinguishable from a dispatch that never ran.
        return [pscustomobject]@{ state = 'ABSENT'; reason = "no log and no manifest on disk.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = (Test-Path -LiteralPath $errPath) }
    }
    if (-not $hasMan) {
        return [pscustomobject]@{ state = 'PARTIAL'
                                  reason = "log present, manifest absent -- finalization did not complete. Cause is NOT determined from disk state.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = $true }
    }
    $man = $null
    try { $man = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json }
    catch {
        return [pscustomobject]@{ state = 'PARTIAL'
                                  reason = "manifest present but unparsable as JSON. Cause is NOT determined from disk state.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = $hasLog }
    }
    $finalizedAt = Get-EntryField $man 'finalized_at' $null
    if (-not $finalizedAt) {
        return [pscustomobject]@{ state = 'PARTIAL'
                                  reason = "manifest present without finalized_at. Cause is NOT determined from disk state.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = $hasLog }
    }
    # CURE D10: the bare hash comparison is replaced by an EXTENSION VERDICT.
    # Pre-cure, any mismatch derived TAMPERED, which collapsed "grew by append" and "existing
    # bytes changed" into one state and misdiagnosed every multi-turn session as tampered
    # (E5-iv). The verdict distinguishes them; every undecidable case still lands TAMPERED.
    $ext = Test-EvidenceLogExtension -Manifest $man -LogPath $logPath
    if ($ext.verdict -eq 'grew') {
        return [pscustomobject]@{ state = 'GREW'
                                  reason = "manifest sealed $($ext.sealed_bytes) byte(s); log on disk is $($ext.actual_bytes) byte(s) and is a VERIFIED append-extension of the sealed prefix. Not tampering: a newer finalize is pending at the next Stop.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = $true }
    }
    if ($ext.verdict -eq 'truncated') {
        return [pscustomobject]@{ state = 'TAMPERED'
                                  reason = "log is SHORTER than the sealed prefix: manifest sealed $($ext.sealed_bytes) byte(s), log on disk is $($ext.actual_bytes) byte(s) -- the sealed record cannot be re-derived.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = $true }
    }
    if ($ext.verdict -ne 'intact') {
        # 'mutated' and 'undecidable' -- the sealed bytes cannot be re-derived.
        return [pscustomobject]@{ state = 'TAMPERED'
                                  reason = "log_sha256 mismatch and the sealed prefix does not re-derive: manifest recorded $($ext.recorded_sha256), sealed-prefix hash is $($ext.prefix_sha256). The log's existing sealed bytes changed -- growth by append derives GREW, never TAMPERED.$errHint"
                                  log_path = $logPath; manifest_path = $manPath
                                  consumable = $false; forensics = $true }
    }
    # The error hint rides on EVERY branch, FINALIZED included. Previously it was
    # appended only in the PARTIAL branches, so an error log on a finalized dispatch was
    # invisible to the state machine -- a validator measured exactly that.
    return [pscustomobject]@{ state = 'FINALIZED'
                              reason = "finalized_at present and log_sha256 matches the log on disk.$errHint"
                              log_path = $logPath; manifest_path = $manPath
                              consumable = $true; forensics = $true }
}

# --- stream-identity findings (cure D11) ------------------------------------------------------
# Pure identity checks over a manifest's entries against the stream store -- no re-hashing, so
# cheap enough to run at finalize. Two members, each per design SS4.5 law 4:
#   duplicate-path : two entries declaring one stream path. Legal nowhere after D11; it is
#                    the pre-cure signature of a destroyed payload (entries 13/14 of
#                    one session, entries 3/4 of another).
#   count-mismatch : entries declaring streams/ paths versus *.json files actually present in
#                    streams/. The pre-cure instances read entry_count 15 over 14 files, and
#                    33 over 32, and nothing reported either.
# _precompact transcript paths are not stream paths and are excluded on both sides. Entries may
# arrive as parsed manifest objects (PSCustomObject) or as the finalizer's in-memory ordered
# dictionaries; both shapes are read. A _denied entry (cure D8) carries a null path --
# nothing executed, so nothing was allocated -- and is excluded here by the same null-path
# guard that excludes nothing-to-check entries.
function Get-EvidenceStreamIdentityFindings {
    param($Entries, [string]$StreamDir)
    $findings = New-Object System.Collections.Generic.List[object]
    $counts = @{}
    $streamEntries = 0
    foreach ($e in @($Entries)) {
        $rel = ''
        if ($e -is [System.Collections.IDictionary]) {
            if ($e.Contains('path') -and $null -ne $e['path']) { $rel = [string]$e['path'] }
        } else {
            $rel = [string](Get-EntryField $e 'path' '')
        }
        if (-not $rel) { continue }
        $k = ($rel -replace '\\', '/')
        if ($k -notlike 'streams/*') { continue }
        $streamEntries++
        if ($counts.ContainsKey($k)) { $counts[$k] = $counts[$k] + 1 } else { $counts[$k] = 1 }
    }
    foreach ($k in @($counts.Keys | Sort-Object)) {
        if ($counts[$k] -gt 1) {
            [void]$findings.Add([pscustomobject]@{ kind = 'duplicate-path'; path = $k
                problem = ("{0} entries declare '{1}' -- one entry, one file is the rule; a shared name means a payload was overwritten or shared" -f $counts[$k], $k) })
        }
    }
    $fileCount = 0
    if ($StreamDir -and (Test-Path -LiteralPath $StreamDir)) {
        $fileCount = @(Get-ChildItem -LiteralPath $StreamDir -File -Filter '*.json').Count
    }
    if ($streamEntries -ne $fileCount) {
        [void]$findings.Add([pscustomobject]@{ kind = 'count-mismatch'; path = 'streams/'
            problem = ("{0} entries declare stream paths but {1} stream file(s) exist on disk -- identity divergence" -f $streamEntries, $fileCount) })
    }
    return $findings.ToArray()
}

# --- stream-body integrity (cure N-b, partial; identity members added by D11) -----------------
# The manifest's per-entry stdout_sha256/stderr_sha256 are computed over the FULL streams, so a
# stream body can be re-derived and compared. Get-EvidenceState does NOT call this: state is a
# cheap header check, stream verification is O(bytes). It is exposed so the runner and
# `mission verify` (A3) can call it, and so an operator can call it by hand.
#
# D11 ADDITIONS: the two identity members (duplicate-path, count-mismatch) are merged into the
# mismatch list, so one call decides both "the bytes are right" and "the namespace is sound".
# -Dir points the check at an explicit evidence directory (the committed plane, or a fixture)
# instead of the runtime dir derived from -Root/-DispatchId -- historical detection in place on
# old-form residue is the D11 cure's stated property and needs exactly this.
#
# HONEST SCOPE: this DETECTS stream tampering when someone runs it. The finalize-time
# divergence check (evidence-stop-finalize.ps1) runs only the cheap identity members; nothing
# in A1 runs THIS function automatically. Until A3 wires it into the dispatch gate, a mutated
# stream body with an untouched log.jsonl still reads FINALIZED from Get-EvidenceState alone.
#
# NB-2 CURED HERE (A-566 -- the arc's FIRST sealed-hash move). The loop below
# DISCRIMINATES ENTRY VARIANT BEFORE IT TESTS EXISTENCE. Pre-cure the order was inverted, so a
# _precompact entry whose transcript capture honestly failed -- captured:false, a null
# transcript_sha256, and a `path` the schema requires on that variant -- reached the existence
# test, found no file, and was reported as 'stream file missing': an evidence gap the manifest
# ALREADY DISCLOSES, read as an integrity violation. The registered "one-line fix" (hoist the
# stdout_sha256 fetch above the existence test) is REFUSED AS INSUFFICIENT and the register is
# corrected on the record (design SS4.5 law 9): _precompact entries carry NO stdout_sha256 at
# all, so a bare hoist skips captured:true entries too -- trading a false positive for a
# COVERAGE HOLE, in a function whose whole purpose is coverage (spec:457-477).
# TWO SHAPE RULES, both load-bearing. Capture gaps ride `capture_gaps`, their own collection on
# both return paths; and `ok` stays governed by `mismatches` ALONE, because a caller that reads
# only `ok` must not re-commit the very conflation this cure ends.
function Test-EvidenceStreamIntegrity {
    param([string]$Root, [string]$DispatchId, [string]$Dir)
    $rt = if ($Dir) { $Dir } else { Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId }
    $manPath = Join-Path $rt 'manifest.json'
    if (-not (Test-Path -LiteralPath $manPath)) {
        return [pscustomobject]@{ checked = 0; mismatches = @(); capture_gaps = @(); ok = $false; reason = 'no manifest' }
    }
    $man = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json
    $mismatch = @()
    $gaps     = @()
    $checked  = 0
    foreach ($e in @(Get-EntryField $man 'entries' @())) {
        $rel = Get-EntryField $e 'path' $null
        if (-not $rel) { continue }
        # POSITIVE DISCRIMINATION, on the marker the entry carries -- never on a missing
        # stdout_sha256. Absence-based discrimination is the ambiguity that produced the
        # fall-through further down, and re-using it here would rebuild the defect one branch
        # higher. The schema makes `tool` a const on this variant and forbids it on the
        # tool-call variant, so the test cannot collide (evidence-manifest.schema.json:43,58).
        if ([string](Get-EntryField $e 'tool' '') -eq '_precompact') {
            $snap = Join-Path $rt ($rel -replace '/', '\')
            if (-not [bool](Get-EntryField $e 'captured' $false)) {
                # CAPTURE GAP -- its own subject with its own outcome, and NEVER a stream-integrity
                # mismatch (spec:445-449). NOT silently dropped either: a transcript that was
                # supposed to exist and does not is a real evidence gap, and the manifest's own
                # `captured` boolean exists precisely so a false there is not read as an absent
                # event. No existence test is run: there is nothing to find, and looking for it
                # is what produced the false positive.
                $gaps += [pscustomobject]@{ path = $rel; problem = 'transcript not captured (captured is not true) -- a disclosed evidence gap, reported on its own subject and never as a stream-integrity mismatch' }
                continue
            }
            # captured:true -- the HONEST capture. Existence IS tested: that is the coverage the
            # bare hoist would have removed. AND transcript_sha256 is compared against the
            # snapshot on disk -- a comparison NO CODE IN THE SEALED SET performed before this
            # delta (spec:474-477). `checked` is deliberately NOT incremented: it counts stream
            # bodies re-derived, which a transcript snapshot is not, and leaving it alone keeps
            # every pre-existing fixture's figure unmoved.
            if (-not (Test-Path -LiteralPath $snap)) {
                $mismatch += [pscustomobject]@{ path = $rel; problem = 'transcript snapshot missing while the entry records captured: true' }
                continue
            }
            $expTr = Get-EntryField $e 'transcript_sha256' $null
            if (-not $expTr) {
                $mismatch += [pscustomobject]@{ path = $rel; problem = 'entry records captured: true but carries no transcript_sha256 -- the snapshot has nothing to be compared against' }
                continue
            }
            $actTr = Get-Sha256OfFile -Path $snap
            if ($actTr -ne $expTr) {
                $mismatch += [pscustomobject]@{ path = $rel; problem = "transcript_sha256 mismatch: manifest $expTr, snapshot $actTr" }
            }
            continue
        }
        $full = Join-Path $rt ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full)) {
            $mismatch += [pscustomobject]@{ path = $rel; problem = 'stream file missing' }
            continue
        }
        $expOut = Get-EntryField $e 'stdout_sha256' $null
        if (-not $expOut) { continue }        # no recorded stdout hash: nothing to re-derive
        $body = $null
        try { $body = [System.IO.File]::ReadAllText($full) | ConvertFrom-Json } catch { }
        if ($null -eq $body) {
            $mismatch += [pscustomobject]@{ path = $rel; problem = 'stream body unparsable' }
            continue
        }
        $checked++
        $actOut = Get-Sha256OfString ([string](Get-EntryField $body 'stdout' ''))
        $actErr = Get-Sha256OfString ([string](Get-EntryField $body 'stderr' ''))
        if ($actOut -ne $expOut) {
            $mismatch += [pscustomobject]@{ path = $rel; problem = "stdout_sha256 mismatch: manifest $expOut, stream $actOut" }
        }
        $expErr = Get-EntryField $e 'stderr_sha256' $null
        if ($expErr -and $actErr -ne $expErr) {
            $mismatch += [pscustomobject]@{ path = $rel; problem = "stderr_sha256 mismatch: manifest $expErr, stream $actErr" }
        }
    }
    # D11: the identity members ride on every integrity run.
    foreach ($f in @(Get-EvidenceStreamIdentityFindings -Entries @(Get-EntryField $man 'entries' @()) -StreamDir (Join-Path $rt 'streams'))) {
        $mismatch += [pscustomobject]@{ path = $f.path; problem = "[$($f.kind)] $($f.problem)" }
    }
    return [pscustomobject]@{ checked = $checked; mismatches = $mismatch
                              capture_gaps = $gaps
                              ok = ($mismatch.Count -eq 0)
                              reason = $(if ($mismatch.Count -eq 0) { 'all checked stream bodies re-derive to their recorded hashes' } else { "$($mismatch.Count) mismatch(es)" }) }
}

# --- PLANE PARITY -- detector for residual (b) --------------------------------------------------
# The committed plane must hold what the runtime manifest says was published. Residual (b) is an
# ABSENCE -- a copy that silently did not happen -- and an absence is found by comparison, not by
# re-hashing a file nobody wrote. Anchor re-hash reports OK in exactly this case; a validator
# measured that.
#
# A3 NOTE: this is deliberately shaped as pre-work for `mission verify`. The dispatch gate needs
# precisely this comparison before it consumes a report, so it lives in the library rather than
# inside the Stop hook.
#
# SCOPE OF THE CLAIM -- stated narrowly on purpose, because this program's recurring defect is
# a detector claiming more than its evidence shows.
#
# WHAT IS DEMONSTRATED, by three checks:
#   N12  -- residual (b) itself. A FILE is planted at the committed dispatch-directory path, so
#           both publish phases genuinely throw, both errors are recorded, the reconcile pass
#           genuinely fires, and ITS re-copy genuinely dies inside the empty catch. `reconciled`
#           in the manifest is the witness that the path ran. The anchor agrees (blind); this
#           function reports the committed plane incomplete.
#   N12c -- a silent mispublish. A DIRECTORY is planted at the manifest path; the copy SUCCEEDS
#           into it, so the canonical path is empty, nothing is recorded, and reconcile never
#           fires. The anchor is blind for a different reason; this function still catches it.
#   N12b -- the positive control: a cleanly published dispatch reports OK.
#
# THE DEMONSTRATED CLASS is therefore: A COMMITTED ARTIFACT THE RUNTIME MANIFEST SAYS WAS
# PUBLISHED, WHICH IS ABSENT FROM ITS CANONICAL PATH. Nothing broader is claimed.
#
# THE ARMS ARE NOT UNIFORM, and saying otherwise was a defect an earlier revision carried:
#   manifest arm     -- existence + hash against the runtime manifest      (exercised by N12/N12c)
#   log arm          -- existence + hash against log_sha256                (implemented, not exercised)
#   hook-errors arm  -- existence + hash against hook_errors_sha256        (implemented, not exercised)
#   stream-body arm  -- EXISTENCE ONLY. It compares no hash. A committed stream body that is
#                       present but corrupt passes this function. The hash-bearing check for
#                       stream bodies is Test-EvidenceStreamIntegrity, which re-derives
#                       stdout_sha256/stderr_sha256 from the body and IS exercised (N6/N7).
#
# WHAT IS NOT CLAIMED:
#   - This is not "plane integrity" in general. It compares the committed plane against the
#     RUNTIME MANIFEST'S OWN ASSERTIONS. A runtime manifest that lies about what it published is
#     outside this function entirely -- log_sha256, the per-entry stream hashes, and the
#     TAMPERED state are what address that.
#   - Nothing here runs automatically. The runner or an operator calls it; until A3 wires it
#     into the dispatch gate, an incomplete committed plane goes unnoticed unless someone looks.
# D10 NOTE: supersession does not change this function's semantics. It compares the
# committed plane against the CURRENT runtime manifest, which is as true after a supersession
# as before one; retained manifest.superseded-<k>.json files are additive artifacts beside
# the comparison, checked by the A7 instrument.
function Test-EvidencePlaneParity {
    param([string]$Root, [string]$DispatchId)

    $rt        = Get-EvidenceRuntimeDir   -Root $Root -DispatchId $DispatchId
    $committed = Get-EvidenceCommittedDir -Root $Root -DispatchId $DispatchId
    $manPath   = Join-Path $rt 'manifest.json'

    $problems = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path -LiteralPath $manPath -PathType Leaf)) {
        return [pscustomobject]@{ ok = $false; checked = 0; problems = @('no runtime manifest -- nothing was published')
                                  reason = 'runtime manifest absent' }
    }
    $man = $null
    try { $man = [System.IO.File]::ReadAllText($manPath) | ConvertFrom-Json } catch { }
    if ($null -eq $man) {
        return [pscustomobject]@{ ok = $false; checked = 0; problems = @('runtime manifest unparsable')
                                  reason = 'runtime manifest unparsable' }
    }

    $checked = 0
    # helper: a committed artifact must exist AS A FILE and match an expected hash when given.
    function Test-One {
        param([string]$Rel, [string]$Expect, [string]$Label)
        $p = Join-Path $committed $Rel
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return "$Label MISSING from the committed plane ($Rel)" }
        if ($Expect) {
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant()
            if ($actual -ne $Expect) { return "$Label MISMATCH ($Rel): committed $actual, expected $Expect" }
        }
        return $null
    }

    # 1. the manifest itself -- byte-identical to the runtime copy
    $checked++
    $r = Test-One -Rel 'manifest.json' -Expect (Get-Sha256OfFile -Path $manPath) -Label 'manifest.json'
    if ($r) { [void]$problems.Add($r) }

    # 2. the append-only log -- against the anchor the manifest records
    $checked++
    $r = Test-One -Rel 'log.jsonl' -Expect ([string](Get-EntryField $man 'log_sha256' '')) -Label 'log.jsonl'
    if ($r) { [void]$problems.Add($r) }

    # 3. the error trail, when the manifest says one exists
    if ((Get-EntryField $man 'hook_errors_present' $false)) {
        $checked++
        $r = Test-One -Rel 'hook-errors.log' -Expect ([string](Get-EntryField $man 'hook_errors_sha256' '')) -Label 'hook-errors.log'
        if ($r) { [void]$problems.Add($r) }
    }

    # 4. stream bodies, when the manifest says they were committed
    if ((Get-EntryField $man 'streams_committed' $false)) {
        foreach ($e in @(Get-EntryField $man 'entries' @())) {
            $rel = Get-EntryField $e 'path' $null
            if (-not $rel) { continue }
            $checked++
            $r = Test-One -Rel ($rel -replace '/', '\') -Expect $null -Label 'stream body'
            if ($r) { [void]$problems.Add($r) }
        }
    }

    return [pscustomobject]@{
        ok       = ($problems.Count -eq 0)
        checked  = $checked
        problems = $problems.ToArray()
        reason   = $(if ($problems.Count -eq 0) { 'committed plane holds everything the runtime manifest says was published' }
                     else { "committed plane INCOMPLETE: $($problems.Count) problem(s)" })
    }
}

# --- hook stdin ---------------------------------------------------------------------------
# Three ways stdin can fail to be a usable payload, and all three must be DISTINGUISHABLE from
# a valid one -- otherwise a fail-closed consumer cannot tell "nothing to check" from "checked,
# nothing found". PS 5.1's ConvertFrom-Json returns $null for whitespace-only input WITHOUT
# throwing, so the try/catch alone is not enough: that case fell through as a null payload and
# the guard allowed it. Caught by the cured N2 (empty-payload case).
function Read-HookStdin {
    $raw = [Console]::In.ReadToEnd()
    if ($null -eq $raw -or $raw.Trim() -eq '') { return [pscustomobject]@{ _empty = $true } }
    try {
        $obj = $raw | ConvertFrom-Json
        if ($null -eq $obj) { return [pscustomobject]@{ _unparsable = $true; _raw = $raw } }
        return $obj
    }
    catch { return [pscustomobject]@{ _unparsable = $true; _raw = $raw } }
}

function Get-HookField {
    param($Obj, [string]$Name, $Default = $null)
    return (Get-EntryField $Obj $Name $Default)
}

function Get-UtcStampZ { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture) }

# --- hook error trail (cure B5) ---------------------------------------------------------------
# The B5 defect was invisible for THREE independent reasons, and all three are closed here:
#   1. hooks wrote errors to a GLOBAL .mission-runtime/evidence/hook-errors.log
#   2. Get-EvidenceState read a PER-DISPATCH one, so it never saw them
#   3. the finalizer copied manifest/log/streams/transcripts to the committed plane but not the
#      error log, so the committed artifact carried no trace at all
#
# WHAT HOLDS. Twice this enumeration claimed completeness and twice a validator found a member
# it had missed. Per the derived-claims rule, it is now stated as POSITIVE PROPERTIES plus a
# CLASS statement for the residual -- because an exhaustive list nobody can verify exhaustive is
# the same defect as an audited whitelist.
#
# PROPERTIES (each driven by a check in the suite):
#   - Get-EvidenceState surfaces the error log in every state branch: ABSENT, the PARTIAL
#     variants, FINALIZED, GREW, TAMPERED                                  (N11, N8, N9, N5)
#   - the finalizer computes hook_errors_present AFTER its fallible work, and reconciles when
#     the recorded hash differs from the file's current hash -- covering an error that appeared,
#     an error that grew, and no error at all                                  (N9)
#   - hook_errors_sha256 re-derives from the on-disk log                       (N9, asserted by
#     equality against a live re-hash, not by shape)
#
# TWO RESIDUALS, WITH DIFFERENT DETECTORS. An earlier revision put both under one class and
# named one detector for both; a validator showed the detector cannot fire for the second,
# because that member writes nothing by construction. They are separated here.
#
# RESIDUAL (a) -- RECORDED BUT UNREFLECTED.
#   Class: any failure occurring after the manifest's hash fields are computed AND recorded in
#   hook-errors.log. Known member: an error thrown after the reconcile pass returns.
#   DETECTOR: re-hash hook-errors.log and compare to hook_errors_sha256, exactly as log_sha256
#   is compared for the log. Works for every member of this class by definition -- the class is
#   defined by having been recorded.
#   D10 NOTE: this residual is now also SELF-HEALING at the next Stop -- every Stop, no-op
#   included, reconciles the trail flags by the same hash comparison -- but between Stops the
#   detector above remains the only way to see it, so the residual stays registered.
#
# RESIDUAL (b) -- UNRECORDED PUBLISH FAILURE.
#   The reconcile pass's own committed-plane re-copy (evidence-stop-finalize.ps1) is wrapped in
#   an EMPTY CATCH, and the empty catch STAYS: recording there would append to hook-errors.log
#   and invalidate the hash just written into the manifest, trading a silent failure for a
#   guaranteed-wrong anchor. So this member writes NOTHING, and detector (a) provably cannot
#   fire for it -- the anchor matches while the committed plane is incomplete.
#   DETECTOR: PLANE COMPARISON -- Test-EvidencePlaneParity above. The committed plane must hold
#   what the runtime manifest says was published. This is the only detector that works here,
#   because the evidence of the failure is an ABSENCE, and absences are found by comparison,
#   never by re-hashing something that was never written.
#
# There is no single detection story covering both, and no claim here that there is.
#
# WRITERS of the error log: every hook, via Write-EvidenceHookError, when a dispatch id is
# resolvable. Two exceptions, both labelled where they occur: the UNATTRIBUTED fallback below
# (when the dispatch directory is unreachable), and residual (b) (which writes nothing at all).
function Get-EvidenceHookErrorPath {
    param([string]$Root, [string]$DispatchId)
    Join-Path (Get-EvidenceRuntimeDir -Root $Root -DispatchId $DispatchId) 'hook-errors.log'
}

function Write-EvidenceHookError {
    param([string]$Hook, [string]$Message, [string]$SessionId = '', [string]$DispatchId = '')
    try {
        $root = Get-EvidenceRepoRoot
        if (-not $DispatchId) { $DispatchId = Get-EvidenceDispatchId -SessionId $SessionId }
        $p = Get-EvidenceHookErrorPath -Root $root -DispatchId $DispatchId
        $dir = Split-Path -Parent $p
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -LiteralPath $p -Value "$(Get-UtcStampZ) ${Hook}: $Message"
    }
    catch {
        # Last resort only: if even the dispatch directory is unreachable, a global log beats
        # losing the error entirely -- but it is marked UNATTRIBUTED so no reader mistakes it
        # for a per-dispatch record that a state check would have seen.
        try {
            $root2 = Get-EvidenceRepoRoot
            $g = Join-Path $root2 '.mission-runtime\evidence'
            if (-not (Test-Path -LiteralPath $g)) { New-Item -ItemType Directory -Path $g -Force | Out-Null }
            Add-Content -LiteralPath (Join-Path $g 'hook-errors-UNATTRIBUTED.log') `
                -Value "$(Get-UtcStampZ) ${Hook}: $Message (per-dispatch log unreachable: $($_.Exception.Message))"
        } catch { }
    }
}

# =============================================================================================
# FAILURE AND DENIAL CAPTURE (cure D8)
# =============================================================================================
# THE DEFECT THIS CURES (E5-ii / E5-iii). PostToolUse fires only on successful, permitted
# calls: a failed call and a guard-denied call each produced no entry, no hook error, and no
# seq gap -- seq is allocated only when the hook fires, and the hook was never invoked
# (established by controlled experiment; re-derived live at the cure's draft:
# four real calls absent from a contiguous, gapless, error-free log). What the guard refused
# existed nowhere in the evidence plane.
#
# THE CURE, PER MEMBER:
#   E5-iii  THE GUARD RECORDS ITS OWN DENIALS at deny time, via Write-EvidenceDeniedRecord
#           below, called from every deny path of evidence-guard-pretooluse.ps1. Denials occur
#           ONLY where the guard fires, so this record is complete for the member BY
#           CONSTRUCTION, with no matcher change. Recording is OBSERVATION added to the
#           tripwire charter: it changes what the guard OBSERVES, never what it PREVENTS, and
#           the tripwire-not-boundary ruling stands unamended. The recorder fails toward
#           denial-without-record, never toward allow -- the guard wraps the call and denies
#           regardless.
#   E5-ii   STOP-TIME RECONCILIATION against the transcript the Stop payload names --
#           Get-EvidenceTranscriptCallSummary + Get-EvidenceCallCompleteness below, consumed
#           by evidence-stop-finalize.ps1, which writes a call_completeness block into every
#           manifest it seals. 'complete' is asserted ONLY when reconciliation ran with zero
#           unmatched calls; every undecidable path degrades to 'unreconciled' -- never a
#           fabricated 'complete', never a fabricated gap.

# Append one '_denied' entry to the dispatch's append-only log. The command derivation mirrors
# the PostToolUse hook's three branches so a denial record anchors the same way a tool-call
# entry does. NO stream body, NO seq, and NO exit_code: nothing executed, so there is no
# payload to allocate a name for, and an exit_code on a call that never ran would resurrect
# the E5-i constant-null confusion. The null path excludes the entry from every stream
# identity and integrity check by the existing null-path guards.
function Write-EvidenceDeniedRecord {
    param([AllowNull()][string]$SessionId, [AllowNull()][string]$ToolName, $ToolInput,
          [AllowNull()][string]$Reason)
    $command = $null
    if ($null -ne $ToolInput) {
        if ($ToolInput -is [string]) { $command = $ToolInput }
        elseif ($ToolInput.PSObject.Properties.Name -contains 'command')   { $command = [string]$ToolInput.command }
        elseif ($ToolInput.PSObject.Properties.Name -contains 'file_path') { $command = "$ToolName $($ToolInput.file_path)" }
        elseif ($ToolInput.PSObject.Properties.Name -contains 'pattern')   { $command = "$ToolName $($ToolInput.pattern)" }
        else { $command = ($ToolInput | ConvertTo-Json -Compress -Depth 8) }
    }
    $root       = Get-EvidenceRepoRoot
    $dispatchId = Get-EvidenceDispatchId -SessionId $SessionId
    $rt         = Get-EvidenceRuntimeDir -Root $root -DispatchId $dispatchId
    Add-EvidenceLogLine -LogPath (Join-Path $rt 'log.jsonl') -Entry ([ordered]@{
        ts          = Get-UtcStampZ
        session_id  = $SessionId
        dispatch_id = $dispatchId
        tool        = '_denied'
        denied_tool = $ToolName
        command     = $command
        reason      = $Reason
        path        = $null
    })
}

# Read the transcript the Stop payload names and classify every non-sidechain tool call by its
# result: succeeded, failed (is_error without the guard signature), or denied (is_error whose
# content carries the guard's own preamble). RECORD SHAPES DERIVED FROM THE LIVE HARNESS at
# the cure's draft, not assumed (design SS4.5 law 10): an assistant record carries
# message.content[] blocks of type 'tool_use' with id + name; a result record carries
# message.content[] blocks of type 'tool_result' with tool_use_id, an is_error flag that is
# PRESENT on errors and normally ABSENT on successes (absent means success), and content that
# is a string or an array of text parts. isSidechain rides on every record; sidechain records
# are excluded. Anything outside the derived shape counts as undecidable rather than being
# guessed at; the caller degrades to 'unreconciled'.
#
# CONTENT HYGIENE (operator ruling): this function returns COUNTS AND HASHES
# ONLY. No transcript text, no command text, and nothing from the Stop payload's
# last_assistant_message ever leaves it -- an evidence store that embeds assistant prose is a
# different artifact than the one this program is building.
function Get-EvidenceTranscriptCallSummary {
    param([string]$TranscriptPath, [AllowNull()][string]$SessionId = '')
    $s = [ordered]@{
        readable = $false; transcript_sha256 = $null; unparsable_lines = 0
        tool_use_total = 0; resolved = 0; succeeded = 0; failed = 0; denied = 0
        unresolved = 0; undecidable = 0
    }
    if (-not $TranscriptPath -or -not (Test-Path -LiteralPath $TranscriptPath)) {
        return [pscustomobject]$s
    }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($TranscriptPath)
        $s.transcript_sha256 = Get-Sha256OfBytes -Bytes $bytes
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $uses    = @{}
        $results = @{}
        foreach ($line in ($text -split "`n")) {
            if (-not $line.Trim()) { continue }
            $rec = $null
            try { $rec = $line | ConvertFrom-Json } catch { $s.unparsable_lines++; continue }
            if ($null -eq $rec) { $s.unparsable_lines++; continue }
            if ([bool](Get-EntryField $rec 'isSidechain' $false)) { continue }
            if ($SessionId) {
                $rid = [string](Get-EntryField $rec 'sessionId' '')
                if ($rid -and $rid -ne $SessionId) { continue }
            }
            $msg = Get-EntryField $rec 'message' $null
            if ($null -eq $msg) { continue }
            $content = Get-EntryField $msg 'content' $null
            if ($null -eq $content) { continue }
            foreach ($blk in @($content)) {
                if ($null -eq $blk -or $blk -is [string]) { continue }
                $btype = [string](Get-EntryField $blk 'type' '')
                if ($btype -eq 'tool_use') {
                    $id = [string](Get-EntryField $blk 'id' '')
                    if ($id) { $uses[$id] = $true } else { $s.undecidable++ }
                }
                elseif ($btype -eq 'tool_result') {
                    $id = [string](Get-EntryField $blk 'tool_use_id' '')
                    if (-not $id) { $s.undecidable++; continue }
                    $isErr = [bool](Get-EntryField $blk 'is_error' $false)
                    if (-not $isErr) { $results[$id] = 'succeeded'; continue }
                    $body = Get-EntryField $blk 'content' $null
                    $bodyText = ''
                    if ($body -is [string]) { $bodyText = $body }
                    elseif ($null -ne $body) {
                        foreach ($part in @($body)) {
                            $t = Get-EntryField $part 'text' $null
                            if ($t -is [string]) { $bodyText += $t }
                        }
                    }
                    if ($bodyText -like '*DENIED by evidence-guard*') { $results[$id] = 'denied' }
                    else { $results[$id] = 'failed' }
                }
            }
        }
        foreach ($id in @($results.Keys)) {
            if (-not $uses.ContainsKey($id)) { $s.undecidable++ }
        }
        $s.tool_use_total = $uses.Count
        foreach ($id in @($uses.Keys)) {
            if ($results.ContainsKey($id)) {
                $s.resolved++
                switch ($results[$id]) {
                    'succeeded' { $s.succeeded++ }
                    'failed'    { $s.failed++ }
                    'denied'    { $s.denied++ }
                }
            } else { $s.unresolved++ }
        }
        $s.readable = $true
    }
    catch {
        # Structural failure reading or decoding the file: report unreadable; the caller
        # degrades to 'unreconciled'. Never a guess in either direction.
        $s.readable = $false
    }
    return [pscustomobject]$s
}

# Derive the manifest's call_completeness block from a transcript summary and the parsed log.
# STATUS SEMANTICS (ratified): 'complete' if and only if reconciliation ran and
# ZERO calls are unmatched -- failed and denied calls are DISCLOSED BESIDE the status, never
# hidden behind it; 'incomplete' when the accounting positively fails (a call the transcript
# resolved is missing from the record, or the two denial recorders disagree in either
# direction); 'unreconciled' when the verdict cannot be derived (transcript absent or
# unreadable, undecidable shapes, unresolved calls, unparsable lines). A positive finding
# outranks uncertainty: unmatched > 0 reads 'incomplete' even when undecidable records also
# exist. SILENCE IS PROHIBITED: the finalizer writes this block into every manifest it seals.
function Get-EvidenceCallCompleteness {
    param($Summary, $LogEntries, [bool]$TranscriptPathPresent)
    $logged = 0; $deniedRecords = 0
    foreach ($e in @($LogEntries)) {
        if ((Get-EntryField $e '_unparsable' $false)) { continue }
        $t = [string](Get-EntryField $e 'tool' '')
        if ($t -eq '_denied') { $deniedRecords++ }
        elseif ($t -ne '_precompact') { $logged++ }
    }
    $basis = $(if ($TranscriptPathPresent) { 'payload-transcript-path' } else { 'none' })
    if ($null -eq $Summary -or -not $Summary.readable) {
        return [pscustomobject][ordered]@{
            status            = 'unreconciled'
            basis             = $basis
            transcript_sha256 = $(if ($null -ne $Summary) { $Summary.transcript_sha256 } else { $null })
            transcript_calls  = $null
            logged_entries    = $logged
            failed_seen       = $null
            denied_seen       = $null
            denied_records    = $deniedRecords
            unmatched         = $null
            unresolved_calls  = $null
            reason            = $(if ($TranscriptPathPresent) { 'transcript absent or unreadable at reconcile time' }
                                  else { 'no transcript_path in the Stop payload' })
        }
    }
    $unmatched = [Math]::Abs($Summary.succeeded - $logged) + [Math]::Abs($Summary.denied - $deniedRecords)
    $status = 'complete'
    $reason = 'every resolved call is accounted for; failed and denied calls are disclosed beside this status, not hidden behind it'
    if ($unmatched -gt 0) {
        $status = 'incomplete'
        $reason = "accounting failed: transcript resolved $($Summary.succeeded) succeeded vs $logged logged entries; $($Summary.denied) denied in transcript vs $deniedRecords guard denial records"
    }
    elseif (($Summary.undecidable -gt 0) -or ($Summary.unresolved -gt 0) -or ($Summary.unparsable_lines -gt 0)) {
        $status = 'unreconciled'
        $reason = "verdict underivable: $($Summary.unresolved) unresolved call(s), $($Summary.undecidable) undecidable record(s), $($Summary.unparsable_lines) unparsable line(s)"
    }
    return [pscustomobject][ordered]@{
        status            = $status
        basis             = $basis
        transcript_sha256 = $Summary.transcript_sha256
        transcript_calls  = $Summary.tool_use_total
        logged_entries    = $logged
        failed_seen       = $Summary.failed
        denied_seen       = $Summary.denied
        denied_records    = $deniedRecords
        unmatched         = $unmatched
        unresolved_calls  = $Summary.unresolved
        reason            = $reason
    }
}

# =============================================================================================
# EVIDENCE-PATH DETECTION -- design SS4.1 layer (c)
# =============================================================================================
# READ docs/framework/evidence-write-path-threat-notes.md SS3.2/SS3.3 before trusting any of
# this. Self-protection is layer (c) enforced BY the component it protects. It is circular by
# construction: it raises cost, it is not a boundary.
#
# TWO TIERS, because one tier cannot serve both jobs (cure B6 + NB-5):
#
#   PROTECTED  -- writes are denied WHEN THE GUARD CAN SEE THEM. Not "never": three validators
#                 found three different ways past this component, and a fourth class probably
#                 exists. The evidence store and the executable machinery.
#                 `tools/framework/hooks`, the installer, and the test tree are machinery: the
#                 installer writes settings.json and the test is the acceptance instrument, so
#                 an agent that edits either controls what "verified" means.
#
#   PARENT     -- denied only for DESTRUCTIVE or RELOCATING operations. A blanket ban on
#                 `.mission` would deny `git add .mission/ledger/entries.jsonl` and amendment
#                 placement -- ordinary mission ceremony that is not evidence at all -- and a
#                 guard that blocks the workflow it protects gets switched off. So the parents
#                 are guarded against `rm -rf .mission`, not against writing inside them.
$script:EvidenceProtectedPaths = @(
    '.mission-runtime/evidence',
    '.mission/evidence',
    'tools/framework/hooks',
    'tools/framework/install-evidence-hooks.ps1',
    'tools/framework/tests',
    '.claude/settings.json'
)
$script:EvidenceParentPaths = @(
    '.mission-runtime',
    '.mission',
    'tools/framework',
    '.claude'
)

# The ceremony path design SS4.1 mandates: "copies the manifest + selected evidence files into
# .mission/evidence/<dispatch_id>/ FOR COMMIT AT THE NEXT CEREMONY BOUNDARY." Staging and
# committing that tree is the design's own workflow and must not be denied (cure NB-5).
$script:EvidenceCeremonyPaths = @('.mission/evidence')

# Verb classification.
#
# =============================================================================================
# NO ALLOW-SIDE VERB SEMANTICS FOR BASH. THE LIST IS GONE.
# =============================================================================================
# There was a read-only verb list here. It is deleted, along with its git-subcommand companion
# and the read exemption they fed. The list was maintained against a criterion -- "a verb
# qualifies ONLY IF it cannot modify the filesystem without a shell metacharacter" -- and the
# criterion was audited, twice, and was wrong both times:
#
#   attempt 4  `sort -o <path>`                     writes, no metacharacter
#   attempt 5  `file -C -m <path>`                  writes, no metacharacter
#   attempt 5  `git blame --output=<path> <file>`   TRUNCATES the named file, no metacharacter,
#                                                   guard said "plain read"
#              `git diff|log|show|shortlog --output=<path>`  same family
#
# Each audit was performed honestly and each concluded the list was clean. That is the tell: the
# defect is not in any particular verb, it is in maintaining a whitelist of "things that only
# read" against a surface (every flag of every tool on the host) nobody can enumerate. So the
# GENERATOR is removed rather than narrowed. A guard that classifies commands by verb will
# eventually classify one wrong; a guard that does not classify cannot.
#
# OPERATOR ERRATUM, recorded verbatim in substance: the attempt-5 write path was
# admitted by the read-verb exemption that existed because of the operator's B1 clarification,
# "the guard never denies a plain read". That ruling is REVERSED for Bash -- the guard owes
# plain reads nothing in a shell. Read access to evidence is preserved where it is structurally
# safe: the file tools.
#
# CONSEQUENCE, stated plainly: a Bash command naming protected territory DENIES, reads included.
# `cat .mission/evidence/d/manifest.json` now denies. Read evidence with the Read tool; Bash
# gets no benefit of the doubt.
#
# PRECISION, because the looser version of this sentence was measured false.
# TWO verb classes survive, and exactly one of them can produce an allow:
#   destructive -- DENY-side only. Being wrong about it costs a false refusal, never a false permit.
#   staging     -- gates the SOLE Bash allow-side exemption (the SS4.1 ceremony), and is
#                  constrained to targets under .mission/evidence. So "no allow depends on a Bash
#                  verb" is NOT true; "the only allow that depends on a Bash verb is the one
#                  disclosed exemption" is.
# And the "sole exemption" claim is scoped to BASH. The file-tool read path (Read/Grep/Glob) is a
# second structural allow, disclosed in Get-EvidenceGuardDecision and in threat-notes SS3.2.2.

# Shell metacharacters. Their presence means the guard cannot reason about what the command
# actually does -- redirection, substitution, backgrounding and globbing all change the effect
# without changing the words the guard reads.
$script:ShellMetaPattern = '[><|&;$`(){}*?]'
$script:DestructiveVerbs = @(
    'rm','rmdir','del','erase','rd','unlink','shred','truncate','mv','move','ren','rename',
    'Remove-Item','Move-Item','Rename-Item','Clear-Content','Clear-Item'
)
$script:DestructiveGitSubs = @('clean','rm','checkout','restore','reset')
$script:StagingGitSubs     = @('add','commit')
$script:FileToolNames      = @('Write','Edit','MultiEdit','NotebookEdit')
# WHERE THE PROCESS IS STANDING, for the duration of one hook invocation. Initialised HERE and not
# only assigned inside Get-EvidenceGuardDecision: an uninitialised $script: variable read as a
# parameter default THROWS, so any caller reaching a path predicate by another route -- another
# hook, a test, a future entry point -- died instead of judging. Empty means "unknown", which
# reproduces the previous behaviour exactly: command-text forms only, nothing widened, nothing hidden.
# (LAM-INSTALL SS5.1, ported verbatim from the next-generation library; this sealed guard receives no
# cwd, so the value stays '' here and the delta assigns it after dot-sourcing.)
$script:EvidenceCwd = ''

# Canonicalize before matching (cure B3). The pre-cure version normalized separators only and
# then substring-matched, so `.mission-runtime/./evidence/...`, `//`, and `zz/../evidence/...`
# all reached the same file while reading as different strings.
#
# NOTE: collapsing `//` is lossy for URL-shaped text (https://host becomes https:/host). That
# is acceptable here -- this function exists ONLY to decide whether a protected path is being
# named, and no protected pattern contains a scheme.
function ConvertTo-CanonicalPathText {
    param([AllowNull()][string]$Text)
    if (-not $Text) { return '' }
    $t = $Text.Replace('\', '/')
    while ($t -match '//')    { $t = $t -replace '//', '/' }
    while ($t -match '/\./')  { $t = $t -replace '/\./', '/' }
    $t = $t -replace '(?<=^|[\s;|&,=<>()"''`])\./', ''
    return $t
}

# Resolve `.` and `..` segments within a single path-shaped token.
function Resolve-DotSegments {
    param([AllowNull()][string]$Token)
    if (-not $Token) { return '' }
    $t = $Token.Replace('\', '/')
    $rooted = $t.StartsWith('/')
    $stack = New-Object System.Collections.Generic.List[string]
    foreach ($p in $t.Split('/')) {
        if ($p -eq '' -or $p -eq '.') { continue }
        if ($p -eq '..') { if ($stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }; continue }
        [void]$stack.Add($p)
    }
    $joined = ($stack -join '/')
    if ($rooted) { return "/$joined" }
    return $joined
}

# A pattern hit must end at a path boundary, so `.mission` does not match `.missionfoo`.
# CASE-INSENSITIVE (LAM-INSTALL SS5.3): Windows filesystems are case-insensitive, so an
# upper-cased spelling names the same real file. One option on one call; it can only ADD denials.
function Test-PathHit {
    param([AllowNull()][string]$Text, [string]$Pattern)
    if (-not $Text) { return $false }
    $rx = [regex]::Escape($Pattern) + '(?=$|[/\s;,:|&)\]}"''`]|\\)'
    return [regex]::IsMatch($Text, $rx, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

# Returns every pattern from $Patterns that $Text names, checking the canonicalized whole text
# AND each path-shaped token with dot segments resolved, so a bypass has to survive both.
# Returns a string[] -- ALWAYS, including empty. A `return ,$hits` on an empty @() yields a
# one-element array whose single element is the empty array, so callers saw Count=1 and a hit
# of ''. That produced spurious denials of ordinary work (the ledger append, amendment
# placement, plain doc writes) with the reason "targets ''". A List[string].ToArray() has no
# such edge.
function Get-EvidencePathHits {
    param([AllowNull()][string]$Text, [string[]]$Patterns)
    $hits = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $hits.ToArray() }
    $canon = ConvertTo-CanonicalPathText -Text $Text
    $forms = New-Object System.Collections.Generic.List[string]
    $forms.Add($canon)
    foreach ($tok in ($canon -split '[\s;|&,=<>()"''`]+')) {
        if (-not $tok) { continue }
        $r = Resolve-DotSegments -Token $tok
        if ($r) { $forms.Add($r) }
    }
    foreach ($p in $Patterns) {
        foreach ($f in $forms) {
            if (Test-PathHit -Text $f -Pattern $p) { [void]$hits.Add($p); break }
        }
    }
    return $hits.ToArray()
}

# Back-compat single-pattern probe over the protected tier.
function Test-EvidencePathTouched {
    param([AllowNull()][string]$Text)
    $h = @(Get-EvidencePathHits -Text $Text -Patterns $script:EvidenceProtectedPaths)
    if ($h.Count -gt 0) { return $h[0] }
    return $null
}

# =============================================================================================
# LAM-INSTALL SS5.1 / SS5.2 / SS5.5 -- PORTED VERBATIM from tools/evidence-hooks-next/hooks/lib/
# evidence-common.ps1 (the page names that file as the authority for every excerpt it prints; K-4
# compares the page's blocks against it as code). The eight functions below are byte-for-byte the
# next-generation definitions, docblocks included -- their prose therefore speaks from the delta's
# point of view ("this build may not write the sealed library", "offered to A1"); the CODE is what
# is installed here. SS5.1's note names three dependencies for Get-EvidencePathForms; the current
# authority needs five (Test-EvidenceRootedPath, ConvertTo-EvidenceWin32ComponentForm,
# ConvertTo-EvidenceLongNameForm, Resolve-EvidenceGlobForms, and $script:EvidenceCwd), so all are
# ported -- under Set-StrictMode a missing one would throw and fail every call closed (SS1.2).
# After SS2's registration swap the next-generation library redefines every one of these names and
# they are shadowed; they are live only if the registrations are ever pointed back at this file.
# =============================================================================================
function Test-EvidenceRootedPath {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    return [bool]($Path -match '^([A-Za-z]:)?/')
}

function ConvertTo-EvidenceWin32ComponentForm {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($part in ($Path -split '/')) {
        # `.` and `..` are DOT SEGMENTS, not decorated names. Stripping their trailing dots would
        # empty them and destroy the path, so they pass through untouched.
        if ($part -eq '.' -or $part -eq '..') { [void]$out.Add($part); continue }
        $t = $part
        while ($t.Length -gt 0 -and ($t.EndsWith('.') -or $t.EndsWith(' '))) { $t = $t.Substring(0, $t.Length - 1) }
        [void]$out.Add($t)
    }
    $joined = ($out -join '/')
    if ($joined -eq $Path) { return $null }          # nothing was decorated; add nothing
    if (-not $joined.Trim('/')) { return $null }     # never emit an empty or all-slash form
    return $joined
}

function ConvertTo-EvidenceLongNameForm {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    # CHEAP GATE FIRST. An alias always carries `~<digit>` in the aliased component, so a path
    # without one cannot be a short form and costs no filesystem call at all. This keeps the
    # ordinary case -- every path that is not an alias -- string-only.
    if ($Path -notmatch '~[0-9]') { return $null }
    $parts = @($Path -split '/')
    $out = New-Object System.Collections.Generic.List[string]
    $changed = $false
    foreach ($p in $parts) {
        $long = $p
        $prefix = ($out -join '/')
        if ($p -match '~[0-9]' -and $prefix -and (Test-EvidenceRootedPath -Path $prefix)) {
            try {
                $di = New-Object System.IO.DirectoryInfo $prefix
                if ($di.Exists) {
                    # A LITERAL PATTERN, NOT A WILDCARD: `~` has no special meaning to the matcher,
                    # and Win32 matches a search pattern against BOTH the long and the short name --
                    # which is the whole mechanism this uses to invert the alias.
                    $hits = @($di.GetFileSystemInfos($p))
                    if ($hits.Count -eq 1 -and $hits[0].Name -ne $p) { $long = $hits[0].Name; $changed = $true }
                }
            } catch { }
        }
        [void]$out.Add($long)
    }
    if (-not $changed) { return $null }
    $joined = ($out -join '/')
    if ($joined -eq $Path) { return $null }
    return $joined
}

function Resolve-EvidenceGlobForms {
    <#
      A GLOB DENOTES A PATH WITHOUT SPELLING IT (operator ruling A, V-1 round 20).

      `New-Item -ItemType Junction -Path l -Target .mis*\evidence` was ALLOWED by the guard, the
      junction was created, and writes through it landed inside `.mission`. Both tiers were defeated
      by ONE input: the glob is what stops the protected path being detected, and the metacharacter
      tier fires only when one IS detected. The guard's own denial text says it refuses when it
      "cannot determine what ... globbing ... will actually do" -- globbing was the one case where it
      claimed something instead.

      SO THE GLOB IS EXPANDED AGAINST THE FILESYSTEM AND EVERY EXPANSION IS OFFERED AS A FORM. This
      is the 8.3-alias mechanism exactly: resolve against the volume, ADD the resolved spelling, never
      substitute. It adds denials only. A bare `*` is never refused on its own -- it expands to
      whatever is there, and if nothing there is protected, nothing is added.

      BOUNDED, and the bounds are stated: a relative glob resolves only against a KNOWN cwd, a rooted
      glob only when drive-qualified, and at most 64 expansions are offered. Where it cannot resolve
      it adds nothing -- strictly weaker than a string transform, which is the same honest note the
      alias form carries.
    #>
    param([AllowNull()][string]$Token, [AllowNull()][string]$CwdCanon)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Token -or $Token -notmatch '[*?]') { return $out.ToArray() }
    $probe = $Token
    if ($CwdCanon -and -not (Test-EvidenceRootedPath -Path $Token)) { $probe = "$CwdCanon/$Token" }
    if ($probe -notmatch '^[A-Za-z]:/') { return $out.ToArray() }
    $native = $probe -replace '/', '\'
    # THE LONGEST EXISTING PREFIX, WITH THE TAIL RE-APPENDED. The first version resolved the whole
    # token and so offered nothing for a NEW leaf under a glob-denoted directory -- which is exactly
    # the minting route: `cp x .mis*/dispatches/D-FORGED.superseded.yaml` was ALLOWED because the
    # marker did not exist yet. WP-2's R-12b caught it on its first run. So trailing components are
    # peeled off until something resolves, and each hit is offered with the peeled tail restored.
    $head = $native; $tail = ''; $hits = @()
    for ($i = 0; $i -lt 8; $i++) {
        try { $hits = @(Resolve-Path -Path $head -ErrorAction Stop | Select-Object -First 64) } catch { $hits = @() }
        if ($hits.Count -gt 0) { break }
        $cut = $head.LastIndexOf('\')
        if ($cut -lt 3) { break }
        $tail = $head.Substring($cut) + $tail
        $head = $head.Substring(0, $cut)
        # Once no glob remains in the head, the glob was in the tail and matched nothing: a NEW
        # name with a wildcard in it denotes no existing protected path, so there is nothing to add.
        if ($head -notmatch '[*?]') { $hits = @(); break }
    }
    foreach ($h in $hits) {
        $c = ConvertTo-CanonicalPathText -Text (([string]$h.Path) + $tail)
        if ($c) { [void]$out.Add($c) }
    }
    return $out.ToArray()
}

function Get-EvidencePathForms {
    <#
      THE PATH-SHAPED FORMS OF A STRING: the canonicalised whole text, plus every whitespace- or
      operator-separated TOKEN with its dot segments resolved.

      WHY THIS EXISTS, and it is a defect repaired rather than a convenience. The two predicates
      below used to run a `(^|/)`-anchored regex over the WHOLE COMMAND STRING. A path preceded by a
      SPACE has neither start-of-string nor a `/` before it, so

          cp seed.yaml .mission/gates/push-forged.yaml

      matched NOTHING and the guard returned ALLOW. An independent validator drove the whole chain
      from there: write a gate face, copy it in, `mission-gate.ps1 list` reads it back as a valid
      open build-authorization gate, and `git push` then answers "push authorized". AN AGENT MINTED
      ITS OWN AUTHORIZATION AND PUBLISHED ON IT -- the exact act T-3 exists to forbid, and the
      compensating control that BOTH the zero-paste attestation and Ruling A2 cite by name.

      A `(^|/)` anchor is correct WITHIN A TOKEN and wrong across a command. A1's own protected-path
      matcher never had this bug because it tokenises first (Get-EvidencePathHits) -- which is why
      `.mission/evidence` in a command has always denied correctly. These predicates bypassed that
      machinery and reinvented the matching. The cure is to stop reinventing it.

      DISCLOSED DUPLICATION, REGISTERED RATHER THAN HIDDEN: the token split and dot resolution below
      mirror the form construction inside A1's `Get-EvidencePathHits`, because A1 does not export a
      token function and its bytes are sealed against this build. That is one predicate living in
      two places, which is the law this build keeps restating -- so it is named here, and the fix
      (export the form builder from A1 so both callers share it) belongs to whoever next opens the
      sealed set.
    #>
    param([AllowNull()][string]$Text, [AllowNull()][string]$Cwd = $script:EvidenceCwd)
    $forms = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $forms.ToArray() }
    $canon = ConvertTo-CanonicalPathText -Text $Text
    [void]$forms.Add($canon)
    $cwdCanon = if ($Cwd) { (ConvertTo-CanonicalPathText -Text $Cwd).TrimEnd('/') } else { '' }
    foreach ($tok in ($canon -split '[\s;|&,=<>()"''`]+')) {
        if (-not $tok) { continue }
        $r = Resolve-DotSegments -Token $tok
        if ($r) {
            [void]$forms.Add($r)
            # THE SHAPE THE FILESYSTEM WILL ACTUALLY OPEN, offered alongside the literal token.
            $w32 = ConvertTo-EvidenceWin32ComponentForm -Path $r
            if ($w32) { [void]$forms.Add($w32) }
            # AND THE 8.3 ALIAS RESOLVED (V-1 round 9, WP-4), by the same add-never-substitute rule.
            $lng = ConvertTo-EvidenceLongNameForm -Path $r
            if ($lng) { [void]$forms.Add($lng) }
            # AND EVERY GLOB EXPANSION (operator ruling A), by the same rule again. This is
            # the form that turns `.mis*/evidence` into `.mission/evidence` for BOTH routes, because
            # both build their candidates here.
            foreach ($g in @(Resolve-EvidenceGlobForms -Token $r -CwdCanon $cwdCanon)) { [void]$forms.Add($g) }
        }
        # A RELATIVE PATH MEANS SOMETHING ONLY RELATIVE TO SOMEWHERE (V-1 round 5, WP-4 residual).
        #
        # The guard read the COMMAND TEXT and nothing else, so it never knew where the process was
        # standing. Driven by an independent reader: `cd .mission`, then `cd gates`, then
        # `echo x > y.yaml` -- three calls, ALLOWED at every step, no protected path in any single
        # command, and no denial recorded. The Bash tool's working directory persists between calls,
        # so the sequence lands a file in the gates directory that T-3 exists to make unreachable.
        # That qualifies the agent-unmintability claim which the zero-paste attestation and Ruling
        # A2 both cite BY NAME as their compensating control.
        #
        # So each relative token is ALSO offered in its cwd-joined form. This can only ADD denials:
        # every form the guard saw before is still produced, and the extra one is what the command
        # actually names. The guard is unchanged -- a tripwire, not a boundary; a shell can still
        # compute a path the guard cannot see, and this closes the spelling that needed no
        # computation at all.
        if ($cwdCanon -and -not (Test-EvidenceRootedPath -Path $r)) {
            $joined = Resolve-DotSegments -Token "$cwdCanon/$r"
            if ($joined) {
                [void]$forms.Add($joined)
                $jw32 = ConvertTo-EvidenceWin32ComponentForm -Path $joined
                if ($jw32) { [void]$forms.Add($jw32) }
                # THE CWD-JOINED FORM IS WHERE THE ALIAS USUALLY RESOLVES, because a bare
                # `MISSIO~2/gates/x.yaml` has no rooted prefix of its own to enumerate. Joining it to
                # the cwd first is what makes the expansion possible at all for a relative spelling.
                $jlng = ConvertTo-EvidenceLongNameForm -Path $joined
                if ($jlng) { [void]$forms.Add($jlng) }
            }
        }
    }
    return $forms.ToArray()
}

function Test-EvidenceSupersessionMarkerPath {
    <#
      LAM-ACCEPT R-1. A `*.superseded.yaml` marker retires a prior dispatch, and an
      agent placed one here with a plain `cp` before anything stopped it. The pattern is therefore
      protected territory for agent WRITES.

      SCOPED TO THE MARKER SUFFIX, NOT TO THE DIRECTORY, and the narrowness is required rather than
      cautious: `.mission/dispatches/` also holds `<id>.handoff.yaml`, which is the worker's ENTIRE
      output obligation and which K-3 names as one of exactly two closed exceptions. A rule written
      against the directory would deny the handoff and no dispatch could ever complete.

      THIS IS DEFENCE IN DEPTH, NOT THE LOAD-BEARING CONTROL, and saying so matters. Under Ruling
      A2-revised a marker is honoured only against an unrevoked `supersession` GATE binding its
      re-derived sha256, and gates are agent-unmintable (T-3). So a marker an agent wrote already
      achieves nothing. This deny stops the artifact from being created at all, which is cheaper to
      reason about than an artifact that exists and is inert -- but nobody should read it as the
      thing that makes supersession safe. The guard is unchanged: a tripwire, not a boundary.
    #>
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $false }
    # TOKENISE FIRST, THEN ANCHOR WITHIN THE TOKEN. The previous form ran the anchored regex over
    # the whole command string and dropped `$` to compensate; that was treating the symptom. A
    # relative destination still slipped past, because `(^|/)` cannot match after a space -- and my
    # own R-12 member passed anyway, because its fixture used an ABSOLUTE path. I tested the one
    # shape that happened to work and generalised from it, which is the very fixture lesson committed
    # by the author who recorded it. Anchored at BOTH ends now, per token, so a marker is recognised and a
    # sibling handoff in the same directory is not.
    foreach ($f in @(Get-EvidencePathForms -Text $Path)) {
        # THE SAME SCOPE THE RUNNER SCANS, and they drifted because each was written separately
        # (found by driving, round 7 wait). R-22 made the runner's scan RECURSIVE over `.mission`
        # and `.mission-runtime`; this rule stayed on `.mission/dispatches/` alone, so FOUR
        # locations the runner honours as a refusal were agent-writable -- and `.mission-runtime/`
        # was reachable even by a dispatched worker, whose plane rule covers `.mission/` only.
        #
        # No privilege is gained: a planted marker cannot ratify itself. But it halts every
        # subsequent dispatch, and R-1's whole point is that markers are OPERATOR-placed. This rule
        # exists because an agent placed one with a plain `cp`.
        #
        # Widening can only ADD denials. The operator hand-places markers outside the session, where
        # the guard does not apply, and the runner never writes one.
        if ($f -match '(^|/)\.mission(-runtime)?/.*\.superseded\.yaml$') { return $true }
    }
    return $false
}

function Test-EvidenceWorkerPlanePath {
    <#
      LAM-ACCEPT K-3 as amended. THE WORKER'S MISSION-PLANE
      RESTRICTION, expressed here because it CANNOT BE EXPRESSED IN THE PERMISSION GRAMMAR.

      K-3 asks for "no `.mission/**` writes except exactly two closed members". Claude Code
      evaluates deny before allow, specificity does not change the order, and a deny rule cannot
      carry allowlist exceptions -- so `Edit(.mission/**)` in deny shadowed both allow entries and
      the number of exceptions that obtained was ZERO. Confirmed by driving the real CLI against a
      byte-identical copy of worker.json with a passing control (V-1 round 2, WP-5), and it was not
      a paper defect: the runner passes that file as --settings for every dispatched worker, so
      R-3's required handoff was unwritable by the role obliged to produce it.

      TRUE IFF the text names a `.mission/` path that is NOT one of the two closed members.

      TOKENISE FIRST, ANCHOR WITHIN THE TOKEN -- the T-3 cure, reused rather than reinvented. A
      `(^|/)`-anchored regex over a whole command string cannot match after a space, which is how
      `cp seed.yaml .mission/gates/x.yaml` once returned ALLOW. Every predicate in this file that
      reinvented the matching had that bug; the one that delegated never did.

      `.mission-runtime/` DOES NOT MATCH, by construction: `\.mission/` requires a slash
      immediately after `mission`, and `.mission-runtime` carries a hyphen there.
    #>
    param([AllowNull()][string]$Path, [AllowNull()][string]$DispatchId)
    if (-not $Path) { return $false }
    # THE EXCEPTION IS "ITS OWN HANDOFF", AND THE FIRST IMPLEMENTATION MADE IT "ANY HANDOFF"
    # (V-1 round 3, WP-5). K-3 names `.mission/dispatches/<dispatch_id>.handoff.yaml`; the pattern
    # below shipped as `[^/]*\.handoff\.yaml`, a wildcard over EVERY dispatch id -- so a dispatched
    # worker could overwrite a PEER dispatch's handoff, by file tool and by shell, allowed and
    # unlogged. The dispatching id was in scope the whole time, in the very predicate that gates
    # this rule. Worse, the deny message quoted the narrow `<id>.handoff.yaml` form while the code
    # enforced the wide one: the artifact's own face claimed a closure the code did not have, which
    # is the overclaim this build's laws exist to forbid, committed by the fix for the last one.
    # Falling back to the wildcard when no id is known would re-open it, so an unknown id closes
    # the exception entirely -- fail closed.
    $ownHandoff = if ($DispatchId) {
        '(^|/)\.mission/dispatches/' + [regex]::Escape($DispatchId) + '\.handoff\.yaml$'
    } else { $null }
    foreach ($f in @(Get-EvidencePathForms -Text $Path)) {
        # JUDGE TOKENS, NOT THE WHOLE COMMAND TEXT (V-1 round 8, found by reordering the offered
        # tokens). Form #1 is the entire canonicalised text. Once the cwd augmentation appends an
        # ABSOLUTE plane path, that whole-text form matches the plane pattern -- and the two
        # exceptions below are `$`-anchored, so they can only be satisfied when the command happens
        # to END with the excepted path. Measured: `cp h.yaml <own handoff>` was allowed and
        # `cp <own handoff> backup.yaml` was DENIED, for the same act written the other way round.
        #
        # A worker's own handoff is one of K-3's two closed exceptions; denying it means no dispatch
        # can complete. The exception must not depend on where in the line the path appears.
        #
        # Nothing is lost by skipping it: every path in the command is also offered as its own
        # token form, with its cwd-joined absolute alongside. The whole-text form can only ever
        # restate what the tokens already say -- and it restates it in a shape the anchors misread.
        if ($f -match '\s') { continue }
        if ($f -notmatch '(^|/)\.mission/') { continue }
        # CLOSED MEMBER 1 -- the worker's own evidence session.
        # DISCLOSED: this exception is unreachable in practice and that is CORRECT, not a defect.
        # A1's sealed protected set denies `.mission/evidence` to every role by both routes, and
        # this build may not modify it. The exception is therefore a PERMISSION-LAYER one that the
        # guard layer overrides -- which costs nothing, because a worker's evidence session is
        # written by the HOOKS, harness-side, never by the worker's tool calls. It is named here so
        # the closed set reads the same in both places rather than silently differing.
        if ($f -match '(^|/)\.mission/evidence/session-[^/]+/') { continue }
        # CLOSED MEMBER 2 -- the worker's OWN handoff, scoped to the dispatching id.
        if ($ownHandoff -and ($f -match $ownHandoff)) { continue }
        return $true
    }
    return $false
}

function Test-EvidenceDispatchedWorker {
    <#
      Is THIS session a dispatched worker? The runner sets LAM_DISPATCH before spawning
      `claude -p` (mission-dispatch.ps1), so the hook child inherits it and an agent cannot set it
      for its own hook process from inside a tool call.

      WHY THE WORKER RULE IS SCOPED AND T-3 IS NOT. There is no role for which minting one's own
      authorization is legitimate, so T-3 is role-blind by design and stays that way. Writing the
      mission plane is different: `git add .mission/ledger/entries.jsonl` and amendment placement
      are ORDINARY CEREMONY, and A1's own doctrine warns in as many words that a blanket ban on
      `.mission` "would deny ... ordinary mission ceremony that is not evidence at all -- and a
      guard that blocks the workflow it protects gets switched off". So the rule fires only where
      K-3 scopes it.

      LAM_DISPATCH is already the contract-named compensating control for telling machinery from a
      human (the S-5 dispatch route); this is the same marker doing the same job one layer
      down, not a new trust assumption.
    #>
    return [bool]$env:LAM_DISPATCH
}

# --- command classification -------------------------------------------------------------------
function Split-CommandSegments {
    param([AllowNull()][string]$Command)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Command) { return $out.ToArray() }
    foreach ($s in ($Command -split '(?:&&|\|\||;|\||\r?\n)')) {
        $t = $s.Trim()
        if ($t) { $out.Add($t) }
    }
    return $out.ToArray()
}

# 'destructive' | 'staging' | 'other'
# No 'readonly' class exists any more. Both surviving classes are safe to be wrong
# about in the direction they push: 'destructive' only ever adds a refusal, and 'staging' gates
# the single disclosed exemption, which is itself constrained to the ceremony path.
function Get-SegmentVerbClass {
    param([AllowNull()][string]$Segment)
    if (-not $Segment) { return 'other' }
    $toks = @($Segment -split '\s+' | Where-Object { $_ })
    if ($toks.Count -eq 0) { return 'other' }
    $v = $toks[0].Trim('"', "'", '&', '(')
    if ($v -eq 'sudo' -and $toks.Count -gt 1) { $v = $toks[1] }
    if ($v -eq 'git') {
        $sub = ''
        for ($i = 1; $i -lt $toks.Count; $i++) { if ($toks[$i] -notmatch '^-') { $sub = $toks[$i]; break } }
        if ($script:DestructiveGitSubs -contains $sub) { return 'destructive' }
        if ($script:StagingGitSubs     -contains $sub) { return 'staging' }
        return 'other'
    }
    if ($script:DestructiveVerbs -contains $v) { return 'destructive' }
    return 'other'
}

# A destructive command can be repo-wide WITHOUT naming anything we protect. `git clean -xfd`
# is the sharpest case: the entire .mission-runtime/ evidence plane is untracked, so a bare
# `git clean` erases every pre-commit record while naming no protected path at all. Found by
# the deny-case sweep -- the path-matching branch let it straight through.
function Test-RepoWideDestructive {
    param([AllowNull()][string]$Segment)
    if (-not $Segment) { return $false }
    $toks = @($Segment -split '\s+' | Where-Object { $_ })
    if ($toks.Count -eq 0) { return $false }
    $v = $toks[0].Trim('"', "'", '&', '(')
    if ($v -eq 'sudo' -and $toks.Count -gt 1) { $v = $toks[1]; $toks = $toks[1..($toks.Count - 1)] }

    # `git clean` removes untracked files -- which is what runtime evidence IS.
    if ($v -eq 'git') {
        for ($i = 1; $i -lt $toks.Count; $i++) {
            if ($toks[$i] -notmatch '^-') { return ($toks[$i] -eq 'clean') }
        }
        return $false
    }
    if ($script:DestructiveVerbs -notcontains $v) { return $false }

    # A destructive verb whose only targets are the cwd, the parent, or a bare wildcard.
    $targets = @()
    for ($i = 1; $i -lt $toks.Count; $i++) {
        if ($toks[$i] -match '^-') { continue }
        $targets += $toks[$i].Trim('"', "'")
    }
    if ($targets.Count -eq 0) { return $true }
    $wide = @('.', './', '..', '../', '*', './*', '/', '~', '~/')
    return (@($targets | Where-Object { $wide -notcontains $_ }).Count -eq 0)
}

# --- the guard decision (lives here so it is testable without spawning the hook) ---------------
# Returns @{ decision = 'allow'|'deny'; reason = '<text>' }.
function Get-EvidenceGuardDecision {
    param([string]$ToolName, $ToolInput)

    # THE READ PATH, and the SECOND STRUCTURAL ALLOW, disclosed.
    # These tools cannot write, so they are allowed before any path inspection. `WebFetch` and
    # `WebSearch` were removed: they are not repository reads and had no business on a list whose
    # justification is "structurally cannot write to the evidence plane".
    $readOnlyTools = @('Read', 'Grep', 'Glob', 'NotebookRead')
    if ($readOnlyTools -contains $ToolName) {
        return @{ decision = 'allow'; reason = 'file-tool read path: this tool cannot write, so evidence reads are not restricted' }
    }

    # File tools: inspect PATH FIELDS ONLY. Scanning `content` would deny writing any document
    # that merely mentions an evidence path -- including these threat notes (cure NB-5). A file
    # whose CONTENT is a script that later writes evidence remains a disclosed miss.
    if ($script:FileToolNames -contains $ToolName) {
        $paths = @()
        if ($null -ne $ToolInput -and $ToolInput -isnot [string]) {
            foreach ($n in @('file_path','path','notebook_path','filePath')) {
                $v = Get-EntryField $ToolInput $n $null
                if ($v -is [string] -and $v) { $paths += $v }
            }
        } elseif ($ToolInput -is [string]) { $paths += $ToolInput }
        foreach ($p in $paths) {
            $h = @(Get-EvidencePathHits -Text $p -Patterns $script:EvidenceProtectedPaths)
            if ($h.Count -gt 0) {
                return @{ decision = 'deny'; reason = "tool '$ToolName' targets the protected path '$($h[0])'" }
            }
            # LAM-INSTALL SS5.1 -- R-1: the supersession marker pattern (write-tool reach).
            if (Test-EvidenceSupersessionMarkerPath -Path $p) {
                return @{ decision = 'deny'
                          reason = "tool '$ToolName' targets the supersession marker '$p'. A *.superseded.yaml marker retires a prior dispatch, and an agent placed one here with a plain copy before anything stopped it. Markers are operator-placed and operator-ratified: the runner honours one only against an unrevoked supersession gate binding its re-derived sha256. The worker's own handoff in this same directory is unaffected -- the rule is scoped to the marker suffix, not to the directory" }
            }
            # LAM-INSTALL SS5.2 -- K-3 as amended: the dispatched worker's mission plane (write-tool reach).
            if ((Test-EvidenceDispatchedWorker) -and (Test-EvidenceWorkerPlanePath -Path $p -DispatchId $env:LAM_DISPATCH)) {
                return @{ decision = 'deny'
                          reason = "tool '$ToolName' targets '$p' under the mission plane, and this session is dispatched worker '$env:LAM_DISPATCH'. K-3 gives a worker exactly TWO closed exceptions under .mission/ -- its own evidence session (.mission/evidence/session-*/) and its own handoff (.mission/dispatches/<id>.handoff.yaml) -- and this is neither. The permission layer cannot express this rule: deny is evaluated before allow and a deny rule cannot carry allowlist exceptions, so a blanket deny there made BOTH exceptions inert instead. This is a tripwire, not a boundary: the denial is recorded, which is what a worker cannot get past silently" }
            }
        }
        return @{ decision = 'allow'; reason = 'no protected path in the target path' }
    }

    # Command tools and anything unrecognised: scan every string plus the raw serialisation, so
    # an unanticipated shape cannot slip a path past the scan.
    $command = $null
    $blobs = @()
    if ($null -ne $ToolInput) {
        if ($ToolInput -is [string]) { $command = $ToolInput; $blobs += $ToolInput }
        else {
            $command = Get-EntryField $ToolInput 'command' $null
            foreach ($prop in $ToolInput.PSObject.Properties) {
                if ($prop.Value -is [string]) { $blobs += $prop.Value }
            }
            $blobs += ($ToolInput | ConvertTo-Json -Compress -Depth 8)
        }
    }

    if ($command) {
        $segments = @(Split-CommandSegments -Command $command)
        $classes  = @($segments | ForEach-Object { Get-SegmentVerbClass -Segment $_ })

        $hasMeta = ($command -match $script:ShellMetaPattern) -or ($command -match "`n")
        $protAll   = @(Get-EvidencePathHits -Text $command -Patterns $script:EvidenceProtectedPaths)
        $parentAll = @(Get-EvidencePathHits -Text $command -Patterns $script:EvidenceParentPaths)
        $touchesProtected = (($protAll.Count -gt 0) -or ($parentAll.Count -gt 0))

        # B1 -- THE METACHARACTER GATE, evaluated FIRST and before any exemption.
        # A metacharacter means the guard cannot reason about the command's effect. Where one is
        # present AND protected territory is named, the guard claims nothing and refuses.
        # This is the root cure for BF1: `printf x > <protected path>`, `cat $(rm -rf ...)`,
        # `cat ... & rm -rf ...` and backtick substitution all name protected territory
        # literally, and all of them die here rather than reaching an exemption.
        # SCOPE, deliberate: a metacharacter command naming NO protected path is ALLOWED.
        # Blanket-denying every command with a pipe, `$` or parentheses would deny
        # `git commit -m "close(M-110)"` and most ordinary pipelines -- the noise direction that
        # gets guards switched off.
        if ($hasMeta -and $touchesProtected) {
            $what = if ($protAll.Count -gt 0) { $protAll[0] } else { $parentAll[0] }
            return @{ decision = 'deny'
                      reason = "command contains a shell metacharacter AND references protected territory ('$what'). The guard cannot determine what redirection, substitution, globbing or backgrounding will actually do, so it claims nothing and refuses. Run it outside the session if it is legitimate." }
        }

        # LAM-INSTALL SS5.1 -- the SHELL reach of the marker rule, and it is the one that actually
        # mattered: the marker this build had to retro-ratify was placed by a plain `cp`, not by a
        # file tool. A rule that guarded only the write tools would have missed the exact way it happened.
        if (Test-EvidenceSupersessionMarkerPath -Path $command) {
            return @{ decision = 'deny'
                      reason = "the command names a *.superseded.yaml supersession marker. Markers retire a prior dispatch and are operator-placed; the one this build had to retro-ratify was created by a plain copy, which is why the rule covers commands and not only the write tools" }
        }
        # LAM-INSTALL SS5.2 -- the SHELL reach of the worker-plane rule, gated on the runner's marker.
        if ((Test-EvidenceDispatchedWorker) -and (Test-EvidenceWorkerPlanePath -Path $command -DispatchId $env:LAM_DISPATCH)) {
            return @{ decision = 'deny'
                      reason = "the command names a mission-plane path outside the worker's two closed exceptions, and this session is dispatched worker '$env:LAM_DISPATCH'. A worker writes its own evidence session and its own handoff; the rest of .mission/ belongs to the orchestrator and to ceremony. Scoped to a dispatched worker on purpose -- a role-blind rule here would refuse git add of the mission ledger and amendment placement, which is ordinary ceremony this guard exists to protect" }
        }

        # The read exemption that used to sit here is DELETED. A Bash command naming
        # protected territory now denies whether or not it looks like a read, because "looks
        # like a read" is exactly the judgement that admitted `git blame --output=<path>`.

        $ceremonyExempt = $false
        for ($i = 0; $i -lt $segments.Count; $i++) {
            $seg = $segments[$i]; $cls = $classes[$i]
            $prot   = @(Get-EvidencePathHits -Text $seg -Patterns $script:EvidenceProtectedPaths)
            $parent = @(Get-EvidencePathHits -Text $seg -Patterns $script:EvidenceParentPaths)

            if ($cls -eq 'destructive' -and ($prot.Count -gt 0 -or $parent.Count -gt 0)) {
                $what = if ($prot.Count -gt 0) { $prot[0] } else { $parent[0] }
                return @{ decision = 'deny'
                          reason = "destructive or relocating command targets '$what'. Runtime evidence is destroyable from inside with no marker; the trust boundary is the ceremony commit, so this is refused before it can erase the pre-commit record." }
            }
            if ($cls -eq 'destructive' -and (Test-RepoWideDestructive -Segment $seg)) {
                return @{ decision = 'deny'
                          reason = "repo-wide destructive command ('$seg') names no protected path but its scope includes the whole worktree. Runtime evidence is UNTRACKED, so `git clean` and bare recursive deletes erase the entire pre-commit record while naming nothing." }
            }
            if ($prot.Count -eq 0) { continue }

            if ($cls -eq 'staging' -and -not $hasMeta) {
                # THE SOLE SURVIVING ALLOW-SIDE EXEMPTION. Design SS4.1's own
                # ceremony: "copies ... into .mission/evidence/<dispatch_id>/ FOR COMMIT AT THE
                # NEXT CEREMONY BOUNDARY." Staging anything else protected -- a hook script, the
                # installer, the test -- is not exempt. Gated on -not $hasMeta: the metacharacter
                # rule binds every exemption.
                #
                # This is the ONLY member of its class and nothing joins it without an amendment.
                # Its residual is named rather than argued away: a staging command can manipulate
                # the git index in ways this check does not model. That residual is caught one
                # layer up, by the committed-plane hash chain -- what is committed is hashed, and
                # a manifest whose log_sha256 does not re-derive reads TAMPERED.
                $nonCeremony = @($prot | Where-Object { $script:EvidenceCeremonyPaths -notcontains $_ })
                if ($nonCeremony.Count -eq 0) { $ceremonyExempt = $true; continue }
                return @{ decision = 'deny'; reason = "git staging targets the protected path '$($nonCeremony[0])', which is machinery, not the SS4.1 evidence ceremony path" }
            }
            return @{ decision = 'deny'; reason = "command references the protected path '$($prot[0])'" }
        }
        if ($ceremonyExempt) {
            # Finding 8 (attempt 5): the old reason said "no protected path referenced" when a
            # protected path WAS referenced and exempted. Say which happened.
            return @{ decision = 'allow'; reason = 'ceremony exemption: git staging under .mission/evidence (design SS4.1) -- the single allow-side exemption that survives' }
        }
        return @{ decision = 'allow'; reason = 'no protected path referenced by any command segment' }
    }

    foreach ($b in $blobs) {
        $h = @(Get-EvidencePathHits -Text $b -Patterns $script:EvidenceProtectedPaths)
        if ($h.Count -gt 0) {
            return @{ decision = 'deny'; reason = "tool '$ToolName' references the protected path '$($h[0])'" }
        }
    }
    return @{ decision = 'allow'; reason = 'no protected path referenced' }
}
