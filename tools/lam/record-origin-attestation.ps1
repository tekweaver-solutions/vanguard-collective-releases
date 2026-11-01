#Requires -Version 5.1
<#
.SYNOPSIS
  THE ORIGIN-ATTESTATION ANCHOR -- one artifact holding the three post-push readings of the
  origin tip, each with its own provenance. (Operator ruling.)

.DESCRIPTION
  WHAT THIS EXISTS FOR. After a gated push the seat writes a PUSH ANNOTATION on the ledger. The
  two most recent of them carry, in prose, the
  same three-part record:
  

      (i)   git ls-remote origin refs/heads/main            -- THE SEAT'S OWN, re-derived here
      (ii)  gh api repos/<owner>/<repo>/commits/<branch>    -- THE OPERATOR'S, attested
      (iii) the operator's browser at the commit URL        -- THE OPERATOR'S

  and the later of them states the law the whole design turns on:

      "THE STANDING IS THREE INDEPENDENT READINGS AND THE SEAT HOLDS ONE OF THEM. It does not
       claim the other two; it records them as attested, which is the difference between a
       confirmation and a citation of one."

  THE DEFECT THIS CURES. That record exists ONLY as English inside a JSONL `content` string.
  Nothing is a field, so nothing is machine-readable, nothing is re-derivable by a later reader,
  and no consumer can ask the record what reading (i) was. This tool makes the three readings
  FIELDS OF ONE ARTIFACT that the annotation cites by path and sha256.

  WHAT IT DOES NOT CURE, STATED SO NOBODY OVER-READS IT. mission-verify's ORIGIN-ATTESTATION arm
  engages only on a non-null, non-blank `runner_anchors.origin_tip` (mission-verify.ps1:1417).
  schemas SS5 declares that member OPTIONAL (:462, :481) since an earlier revision, which
  discharged that schema half; the runner writes it. THIS ARTIFACT IS
  NOT THAT FIELD and is not offered as one: the runner's anchor block and verify's admission
  library are not this tool's to write, and filling that member from here would be a runner
  anchor wearing a tool's clothes.

  THE PROVENANCE DISTINCTION IS THE POINT, NOT A DECORATION.
    * Reading (i) is TAKEN BY THIS TOOL, on this host, against the origin URL DECLARED ON THE PUSH
      GATE -- never `remote.origin.url`. An operator ruling declares .git/config
      an unprotectable control surface and requires every CONSUMER to read the gate's declared
      `origin_url`; round 12 drove the consequence of not doing so, where a repointed remote made
      a detector report PASS while the real origin held an unauthorized commit.
    * Reading (ii) is taken here ONLY when the operator asks for it (-WithGhApi), and is recorded
      as THIS HOST'S reading when it is; when the operator supplies their own (-GhReading /
      -GhReadingBy) it is recorded as THEIRS. The tool reaches no network unless asked.
    * Reading (iii) IS NEVER AUTHORED HERE. There is no code path on which a browser attestation
      appears that the operator did not pass in -BrowserAttestation. With none supplied the field
      is written as a visibly empty slot whose text says it was not attested. A tool that could
      infer a browser reading from an agreeing ls-remote would be manufacturing the one leg it
      exists to keep honest, and would turn a three-reading standing into a one-reading standing
      wearing three names.

  WHERE THE ARTIFACT GOES, AND WHY NOT THE OTHER TWO PLACES.
    NOT `.mission/gates/`. A gate is an AUTHORIZATION and this mints none; gates are hard-denied to
    every agent role (LAM-ACCEPT T-3) precisely so that an authorization cannot be self-issued, and
    putting a record into that directory would either fail or quietly borrow a gate's standing.
    NOT `.mission/evidence/`. That plane is written by harness-side hooks (design SS4.1):
    an agent-writable evidence store launders testimony as evidence. This artifact IS testimony --
    a tool's reading plus the operator's attested ones -- and says so on its face.
    DEFAULT: the RUNTIME PLANE, `<MissionRoot>\.mission-runtime\origin-attestations\`. ADR-003
    gives that plane a different durability contract and .gitignore keeps it out of history; the
    annotation cites the artifact BY PATH AND SHA256, which is the same citation form the close-time
    instrument transcripts use. `-OutputPath` is a parameter so the
    operator, not this tool, decides where a given arc's anchor lives.

  FAIL CLOSED, AND A CRASH IS NOT A REFUSAL (mission-gate.ps1's own finding, E112/E105). Every
  foreseeable bad input is answered with a named refusal and a decided exit code, never with a
  stack trace that is fail-closed by accident.

  EXIT CODES
    0  the artifact was written
    2  REFUSED on input: the push gate is absent, is not a push gate, declares no origin_url,
       declares no remote_ref, declares no authorized_tip_sha, or the output already exists
    3  REFUSED on divergence: the declared origin's tip is NOT the gate's authorized_tip_sha
       (BOTH figures are printed)
    4  REFUSED on silence: the declared origin could not be asked, or answered with no ref line.
       Silence is not consent, and `git ls-remote` conflates unreachable with absent.
    9  unhandled -- reported as such, never presented as a refusal

.EXAMPLE
  # Reading (i) only; the browser slot stays visibly empty.
  .\record-origin-attestation.ps1 -PushGateId <gate-id> -MissionRoot .

.EXAMPLE
  # All three, with the operator's own two supplied verbatim.
  .\record-origin-attestation.ps1 -PushGateId <gate-id> -MissionRoot . `
      -GhReading <tip-sha> -GhReadingBy 'the operator, at the terminal' `
      -BrowserAttestation 'origin/main = <tip-sha>, seen at /commit/<tip-sha>' `
      -BrowserAttestedBy '<user>' -BrowserAttestedAt '2026-09-11T12:06Z'
#>
[CmdletBinding()]
param(
    # The push gate's id as `mission-gate approve -Kind push -Id <id>` recorded it. Resolved to
    # <MissionRoot>\.mission\gates\push-<id>.yaml. Use -PushGatePath to name a gate directly.
    [string]$PushGateId,
    [string]$PushGatePath,

    [string]$MissionRoot = '.',

    # Where the anchor is written. Defaults to the runtime plane; see the header for why.
    [string]$OutputPath,

    # READING (ii). -WithGhApi takes it HERE (network, this host, this tool's reading).
    # -GhReading/-GhReadingBy record the OPERATOR'S OWN reading without reaching anything.
    [switch]$WithGhApi,
    [string]$GhReading,
    [string]$GhReadingBy,

    # READING (iii). THE ONLY DOOR IT HAS. Nothing else in this file writes the browser slot.
    [string]$BrowserAttestation,
    [string]$BrowserAttestedBy,
    [string]$BrowserAttestedAt,

    # Overwrite an existing anchor. Off by default: silently replacing a record of what origin
    # held is how a superseded reading comes back wearing the current one's name.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Output "record-origin-attestation: UNHANDLED ERROR -- $($_.Exception.Message)"
    Write-Output "  stack: $(($_.ScriptStackTrace -split "`r?`n") -join ' | ')"
    Write-Output "  This is NOT a refusal. Nothing about origin is claimed or denied by this exit."
    exit 9
}

function Write-Refusal {
    param([string]$Headline, [string[]]$Lines, [int]$Code)
    Write-Output "record-origin-attestation: $Headline"
    foreach ($l in $Lines) { Write-Output "  $l" }
    exit $Code
}

# ---------------------------------------------------------------------------------------------
# YAML, the flat `key: value` dialect the gate artifacts are written in (mission-gate.ps1 SS approve).
# A hand parser rather than a module, for the reason mission-verify gives of itself: this tool must
# run on a stock PowerShell 5.1 with nothing installed.
# ---------------------------------------------------------------------------------------------
function Read-FlatYaml {
    param([Parameter(Mandatory = $true)][string]$Path)
    $map = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            $k = $Matches[1]
            $v = $Matches[2].Trim()
            if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
            elseif ($v.Length -ge 2 -and $v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1, $v.Length - 2) }
            if (-not $map.ContainsKey($k)) { $map[$k] = $v }
        }
    }
    return $map
}

function Get-Field {
    param($Map, [string]$Name)
    if ($null -eq $Map) { return $null }
    if (-not $Map.ContainsKey($Name)) { return $null }
    $v = [string]$Map[$Name]
    if ([string]::IsNullOrWhiteSpace($v)) { return $null }
    return $v.Trim()
}

# YAML scalar emission. Prose carries colons and dashes, so every value this tool writes is
# double-quoted and internal double quotes become single ones -- no value of any field can end a
# string early and silently reshape the artifact.
function Y {
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { $Value = '' }
    $s = $Value -replace '"', "'"
    $s = $s -replace "`r", ' ' -replace "`n", ' '
    return '"' + $s + '"'
}

function Get-Sha256OfFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    # Guarded, because a file another process holds open is a refusal and not a crash
    # (mission-gate.ps1, V-1 round 19, a WP-4 finding). The share mode admits a holder's write handle.
    $stream = $null
    try {
        $stream = New-Object System.IO.FileStream(
            $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
            ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    catch { return $null }
    finally { if ($stream) { $stream.Dispose() } }
}

# =============================================================================================
# 1. THE MISSION ROOT AND THE GATE
# =============================================================================================
if (-not (Test-Path -LiteralPath $MissionRoot -PathType Container)) {
    Write-Refusal -Headline "REFUSING -- mission root not found: $MissionRoot" -Code 2 -Lines @(
        'The gate is resolved under this root and the runtime plane is written under it.')
}
$MissionRoot = (Resolve-Path -LiteralPath $MissionRoot).Path

if ([string]::IsNullOrWhiteSpace($PushGatePath)) {
    if ([string]::IsNullOrWhiteSpace($PushGateId)) {
        Write-Refusal -Headline 'REFUSING -- no push gate named.' -Code 2 -Lines @(
            'Pass -PushGateId <id> (resolved under the mission root) or -PushGatePath <file>.',
            'This tool anchors a reading TO AN AUTHORIZATION; with no gate there is nothing to anchor to.')
    }
    $gateDirSegment = [System.IO.Path]::Combine('.mission', 'gates')
    $PushGatePath = [System.IO.Path]::Combine($MissionRoot, $gateDirSegment, ('push-' + $PushGateId.Trim() + '.yaml'))
}

if (-not (Test-Path -LiteralPath $PushGatePath -PathType Leaf)) {
    Write-Refusal -Headline 'REFUSING -- the named push gate is ABSENT.' -Code 2 -Lines @(
        "looked for: $PushGatePath",
        'An origin reading with no authorization beside it records what origin holds and NOTHING',
        'about whether it was allowed to hold it. That is the class amendment 20 and spec:402-405',
        'keep apart, so the anchor is not written at all.')
}
$PushGatePath = (Resolve-Path -LiteralPath $PushGatePath).Path

$gate = $null
try { $gate = Read-FlatYaml -Path $PushGatePath }
catch {
    Write-Refusal -Headline 'REFUSING -- the push gate could not be read.' -Code 2 -Lines @(
        "path: $PushGatePath", "reason: $($_.Exception.Message)")
}

$gateSha = Get-Sha256OfFile -Path $PushGatePath
if (-not $gateSha) {
    Write-Refusal -Headline 'REFUSING -- the push gate could not be hashed.' -Code 2 -Lines @(
        "path: $PushGatePath",
        'The anchor cites the gate BY HASH; an uncitable gate is not anchored to.')
}

$gateKind = Get-Field -Map $gate -Name 'kind'
# A GATE KIND IS CASE-SIGNIFICANT (an operator ruling). `-ne` FOLDED, so an artifact whose face
# read `kind: PUSH` was anchored to as a push gate here.
#
# THIS SITE APPLIES THE RULE LOCALLY, AND THAT IS A DISCLOSED EXCEPTION RATHER THAN AN OVERSIGHT.
# Every other consumer resolves through tools/lam/lam-gate-class.ps1's Resolve-LamGateKind. This
# tool cannot: it dot-sources NOTHING, and tools/tests/cli/test_origin_attestation_anchor.py copies
# THIS FILE ALONE into a scratch tools/lam/ with no library beside it -- `shutil.copy2(_TOOL_SRC,
# self.tool)`, and nothing else is copied. An unconditional dot-source would take that whole module
# down at load time, and a conditional one with a refuse-at-the-call guard would turn every case in
# it into a refusal: verbatim the WP-1 H-3/H-16 lesson, reproduced in the file it was written about.
# So what is duplicated here is a `-cne`, not a vocabulary; the map and the sentence still live in
# one place, and this site states no kind the map does not.
if ($gateKind -cne 'push') {
    $kindNote = if ($gateKind -eq 'push') {
        'That kind is the same letters in a different case, and a GATE KIND IS CASE-SIGNIFICANT (an operator ruling).'
    } else {
        'Only a push gate declares an origin URL, a remote ref and an authorized tip.'
    }
    Write-Refusal -Headline 'REFUSING -- that artifact is not a PUSH gate.' -Code 2 -Lines @(
        "path: $PushGatePath", "kind: $(if ($gateKind) { $gateKind } else { '(absent)' })",
        $kindNote,
        'Nothing else carries the triple this anchor compares against (amendment 20).')
}

$authorizedTip = Get-Field -Map $gate -Name 'authorized_tip_sha'
if (-not $authorizedTip) {
    Write-Refusal -Headline 'REFUSING -- the push gate declares no authorized_tip_sha.' -Code 2 -Lines @(
        "path: $PushGatePath",
        'There is no figure to compare the remote reading against, and an anchor that records a',
        'reading with nothing to compare it to reads as a confirmation while confirming nothing.')
}

$originUrl = Get-Field -Map $gate -Name 'origin_url'
if (-not $originUrl) {
    Write-Refusal -Headline 'REFUSING -- the push gate declares NO origin_url.' -Code 2 -Lines @(
        "path: $PushGatePath",
        'Amendment 20: a consumer reads the origin URL FROM THE GATE and never from',
        'remote.origin.url -- .git/config is an unprotectable control surface, and round 12 drove a',
        'detector reading the attacker''s own configuration and calling it evidence.',
        'This tool will not fall back to the git config to get a reading. It refuses instead.')
}

$remoteRef = Get-Field -Map $gate -Name 'remote_ref'
if (-not $remoteRef) {
    Write-Refusal -Headline 'REFUSING -- the push gate declares no remote_ref.' -Code 2 -Lines @(
        "path: $PushGatePath",
        'The ref is the other third of the declared triple. Guessing refs/heads/main would be this',
        'tool inventing the question it then answers.')
}

# =============================================================================================
# 2. READING (i) -- THIS TOOL'S OWN, AGAINST THE DECLARED ORIGIN
# =============================================================================================
$lsCommand = "git ls-remote $originUrl $remoteRef"
$lsRaw = ''
$lsCode = 0
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $lsRaw = (& git ls-remote $originUrl $remoteRef 2>&1 | Out-String)
    $lsCode = $LASTEXITCODE
}
catch {
    $lsRaw = "$($_.Exception.Message)"
    $lsCode = -1
}
finally { $ErrorActionPreference = $prevEap }

$lsSha = $null
foreach ($line in ($lsRaw -split "`r?`n")) {
    if ($line -match '^([0-9a-fA-F]{40})\s+(\S+)$') {
        if ($Matches[2] -eq $remoteRef) { $lsSha = $Matches[1].ToLowerInvariant(); break }
    }
}

if ($null -eq $lsSha) {
    # SILENCE IS NOT CONSENT, and `git ls-remote` conflates "could not reach" with "the ref is not
    # there" (the same conflation mission-verify records at spec:73-76, 385-387). The exit code is
    # load-bearing and is printed; the anchor is NOT written on a reading nobody took.
    Write-Refusal -Headline 'REFUSING -- the DECLARED origin gave no reading for that ref.' -Code 4 -Lines @(
        "command    : $lsCommand",
        "exit_code  : $lsCode",
        "raw output : $(($lsRaw -split "`r?`n" | Where-Object { $_ -ne '' }) -join ' | ')",
        'Unreachable and absent are not separated by this command, so neither is claimed. No anchor',
        'is written: an artifact recording a reading that was never taken is worse than no artifact.')
}

if ($lsSha -ne $authorizedTip.ToLowerInvariant()) {
    Write-Refusal -Headline 'REFUSING -- the DECLARED origin does NOT hold the authorized tip.' -Code 3 -Lines @(
        "gate authorized_tip_sha : $authorizedTip",
        "origin ls-remote reading: $lsSha",
        "origin_url (from the gate, never from git config): $originUrl",
        "remote_ref              : $remoteRef",
        'BOTH figures are printed and neither is preferred. This tool does not decide which of them',
        'is right; it refuses to write an anchor asserting an agreement that is not there.')
}

# =============================================================================================
# 3. READING (ii) -- THE OPERATOR'S, OR THIS HOST'S WHEN ASKED FOR. NEVER BY DEFAULT.
# =============================================================================================
$ghReadingValue = 'NOT TAKEN -- no gh api reading. This tool reaches no network unless -WithGhApi is passed, and none was supplied with -GhReading.'
$ghTakenBy      = '(none)'
$ghProvenance   = 'NOT TAKEN. The absence is recorded as an absence. Pass -WithGhApi to have this tool take the reading on this host, or -GhReading/-GhReadingBy to record the operator''s own.'
$ghCommand      = '(none)'

if (-not [string]::IsNullOrWhiteSpace($GhReading)) {
    # THE OPERATOR'S OWN, RECORDED AS THEIRS. The tool does not check it against anything and does
    # not re-take it: a reading recorded as attested is a citation, and re-deriving it here would
    # quietly turn the operator's leg into this host's.
    $ghReadingValue = $GhReading.Trim()
    $ghTakenBy = if ([string]::IsNullOrWhiteSpace($GhReadingBy)) { 'THE OPERATOR (no name supplied with -GhReadingBy)' } else { 'THE OPERATOR: ' + $GhReadingBy.Trim() }
    $ghProvenance = 'ATTESTED, NOT TAKEN HERE. Supplied verbatim by the operator and recorded as the operator''s reading. This tool did not contact the repository host for it and does not claim it as its own.'
    $ghCommand = 'gh api repos/<owner>/<repo>/commits/<branch>  -- run by the operator, not by this tool'
}
elseif ($WithGhApi) {
    $parts = $null
    $u = $originUrl
    if ($u -match '^https?://(?<host>[^/:@]+)(?::\d+)?/(?<owner>[^/]+)/(?<repo>.+?)(?:\.git)?/?$') {
        $parts = [pscustomobject]@{ HostName = $Matches['host']; Owner = $Matches['owner']; Repo = $Matches['repo'] }
    }
    elseif ($u -match '^(?:ssh://)?[^@/]+@(?<host>[^:/]+)[:/](?<owner>[^/]+)/(?<repo>.+?)(?:\.git)?/?$') {
        $parts = [pscustomobject]@{ HostName = $Matches['host']; Owner = $Matches['owner']; Repo = $Matches['repo'] }
    }
    if ($null -eq $parts) {
        $ghReadingValue = 'NOT TAKEN -- -WithGhApi was passed but the gate''s declared origin_url is not a host/owner/repo URL, so no API endpoint could be composed from it.'
        $ghProvenance   = 'NOT TAKEN, and the reason is recorded rather than the field being dropped. A composed endpoint that guessed at the owner would be asking a different repository.'
    }
    else {
        $branch = $remoteRef -replace '^refs/heads/', ''
        $ghCommand = "gh api --hostname $($parts.HostName) repos/$($parts.Owner)/$($parts.Repo)/commits/$branch --jq .sha"
        $ghRaw = ''
        $ghCode = 0
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $ghRaw = (& gh api --hostname $parts.HostName ("repos/$($parts.Owner)/$($parts.Repo)/commits/$branch") --jq .sha 2>&1 | Out-String)
            $ghCode = $LASTEXITCODE
        }
        catch { $ghRaw = "$($_.Exception.Message)"; $ghCode = -1 }
        finally { $ErrorActionPreference = $prevEap }

        $ghSha = $null
        foreach ($line in ($ghRaw -split "`r?`n")) {
            if ($line.Trim() -match '^([0-9a-fA-F]{40})$') { $ghSha = $Matches[1].ToLowerInvariant(); break }
        }
        if ($ghSha) {
            $ghReadingValue = $ghSha
            $ghTakenBy = "THIS TOOL, on host $env:COMPUTERNAME as $env:USERNAME"
            $ghProvenance = 'TAKEN HERE, ON THIS HOST, AND THEREFORE NOT INDEPENDENT OF READING (i). Both ran with this machine''s PATH, network path and credential store, so they share a failure mode; this is the middle rung and not the rung above it. It does NOT stand in for the operator''s own gh reading.'
        }
        else {
            $ghReadingValue = "NOT TAKEN -- gh answered with no sha (exit $ghCode)."
            $ghProvenance   = 'SILENCE, RECORDED AS SILENCE. A channel that could not answer is not a channel that agreed.'
        }
    }
}

# =============================================================================================
# 4. READING (iii) -- THE OPERATOR'S BROWSER. THIS IS THE ONLY PLACE IT CAN COME FROM.
# =============================================================================================
# THE ONE INVARIANT THIS TOOL EXISTS TO HOLD. `$BrowserAttestation` is the sole source of the
# browser slot. It is not defaulted from $lsSha, not defaulted from $ghReadingValue, not defaulted
# from $authorizedTip, and there is no branch below on which any of those can reach it. Two
# channels agreeing is still two channels; writing a third leg because the first two agree is
# manufacturing the very reading the standing keeps separate.
$BROWSER_NOT_ATTESTED = 'NOT ATTESTED -- no operator browser attestation was supplied to this tool, and this tool cannot take one.'

$browserReading  = $BROWSER_NOT_ATTESTED
$browserBy       = '(none)'
$browserAt       = '(none)'
$browserProv     = 'THE OPERATOR''S OR NOBODY''S. This slot is filled only from -BrowserAttestation, verbatim. This tool has no browser, takes no browser reading, and infers none from any other field: an agreeing ls-remote and an agreeing gh reading leave this slot exactly as it is.'

if (-not [string]::IsNullOrWhiteSpace($BrowserAttestation)) {
    $browserReading = $BrowserAttestation.Trim()
    $browserBy = if ([string]::IsNullOrWhiteSpace($BrowserAttestedBy)) { 'THE OPERATOR (no name supplied with -BrowserAttestedBy)' } else { 'THE OPERATOR: ' + $BrowserAttestedBy.Trim() }
    $browserAt = if ([string]::IsNullOrWhiteSpace($BrowserAttestedAt)) { '(not supplied)' } else { $BrowserAttestedAt.Trim() }
    $browserProv = 'ATTESTED BY THE OPERATOR AND RECORDED VERBATIM. This tool did not take it, did not check it, and does not claim it. It is a citation of the operator''s reading, which is a different thing from a confirmation.'
}

# =============================================================================================
# 5. THE ARTIFACT
# =============================================================================================
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $idForName = if (-not [string]::IsNullOrWhiteSpace($PushGateId)) { $PushGateId.Trim() } else { [System.IO.Path]::GetFileNameWithoutExtension($PushGatePath) }
    $runtimeSegment = [System.IO.Path]::Combine('.mission-runtime', 'origin-attestations')
    $OutputPath = [System.IO.Path]::Combine($MissionRoot, $runtimeSegment, ('origin-attestation-' + $idForName + '.yaml'))
}
$outDir = [System.IO.Path]::GetDirectoryName($OutputPath)
if ($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    Write-Refusal -Headline 'REFUSING -- an anchor already exists at that path.' -Code 2 -Lines @(
        "path: $OutputPath",
        'Overwriting a record of what origin held at a moment is how a superseded reading comes back',
        'wearing the current one''s name. Pass -Force if replacing it is what you mean.')
}

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
$nl = [Environment]::NewLine
$sb = New-Object System.Text.StringBuilder
function A { param([string]$s) [void]$sb.Append($s); [void]$sb.Append($nl) }

A '# ORIGIN-ATTESTATION ANCHOR.'
A '# ONE artifact holding the post-push readings of the origin tip AS FIELDS, each with its own'
A '# provenance, so that the push annotation can CITE it by path and sha256 instead of restating'
A '# three readings in prose that no consumer can parse.'
A '#'
A '# THE STANDING IS THREE INDEPENDENT READINGS AND THE SEAT HOLDS ONE OF THEM.'
A '# This artifact holds reading (i) as its own; it CITES readings (ii) and (iii) where the operator'
A '# supplied them and records their absence plainly where they did not.'
A '#'
A '# THIS IS NOT A GATE: it authorizes nothing and is not written under .mission/gates.'
A '# THIS IS NOT EVIDENCE-PLANE MATERIAL: the evidence plane is written by harness-side hooks, and'
A '# an agent-writable evidence store launders testimony as evidence (design SS4.1). This'
A '# artifact is TESTIMONY -- a tool reading plus attested operator readings -- and says so here.'
A '# THIS IS NOT runner_anchors.origin_tip: schemas SS5 :462 declares that member optional, and'
A '# the runner writes it, not this tool (mission-verify.ps1:1417).'
A ''
A 'artifact_kind: origin-attestation-anchor'
A 'artifact_version: 1'
A ("recorded_at: " + (Y $now))
A ("recorded_by_tool: " + (Y 'tools/lam/record-origin-attestation.ps1'))
A ("recorded_on_host: " + (Y ("$env:COMPUTERNAME")))
A ("recorded_by_user: " + (Y ("$env:USERNAME")))
A ''
A 'push_gate:'
A ("  path: " + (Y $PushGatePath))
A ("  sha256: " + (Y $gateSha))
A ("  id: " + (Y (Get-Field -Map $gate -Name 'id')))
A ("  push_id: " + (Y (Get-Field -Map $gate -Name 'push_id')))
A ("  authorized_tip_sha: " + (Y $authorizedTip))
A ("  origin_url: " + (Y $originUrl))
A ("  remote_ref: " + (Y $remoteRef))
A ("  consumed_at: " + (Y (Get-Field -Map $gate -Name 'consumed_at')))
A ("  consumed_origin_before: " + (Y (Get-Field -Map $gate -Name 'consumed_origin_before')))
A ("  origin_url_source: " + (Y 'THE GATE''S DECLARED FIELD. Amendment 20: consumers read THIS url and never remote.origin.url. No git config was read by this tool.'))
A ''
A 'readings:'
A ''
A '  # (i) -- THE SEAT''S OWN'
A '  ls_remote:'
A ("    reading: " + (Y $lsSha))
A ("    ref: " + (Y $remoteRef))
A ("    command: " + (Y $lsCommand))
A ("    exit_code: " + (Y ([string]$lsCode)))
A ("    taken_by: " + (Y ("THIS TOOL, on host $env:COMPUTERNAME as $env:USERNAME, at $now")))
A ("    provenance: " + (Y 'TAKEN HERE. This is the ONE reading of the three that this artifact holds as its own. It was taken against the origin URL DECLARED ON THE PUSH GATE (amendment 20), never against remote.origin.url, so a repointed remote does not move it. It ran on this host, with this host''s network path and credential store, and therefore shares a failure mode with anything else taken here: this is the middle rung, not origin-side proof.'))
A ("    agrees_with_authorized_tip: " + (Y 'true -- asserted before this artifact was written; a disagreement refuses and writes nothing (exit 3, both figures printed).'))
A ''
A '  # (ii) -- THE OPERATOR''S, unless -WithGhApi was passed'
A '  gh_api:'
A ("    reading: " + (Y $ghReadingValue))
A ("    command: " + (Y $ghCommand))
A ("    taken_by: " + (Y $ghTakenBy))
A ("    provenance: " + (Y $ghProvenance))
A ''
A '  # (iii) -- THE OPERATOR''S, ALWAYS AND ONLY'
A '  browser:'
A ("    reading: " + (Y $browserReading))
A ("    attested_by: " + (Y $browserBy))
A ("    attested_at: " + (Y $browserAt))
A ("    provenance: " + (Y $browserProv))
A ''
A 'comparison:'
A ("  authorized_tip_sha: " + (Y $authorizedTip))
A ("  ls_remote_reading: " + (Y $lsSha))
A ("  equal: " + (Y 'true'))
A ("  scope: " + (Y 'THIS ARM DETECTS AGREEMENT, NOT AUTHORIZATION. That the declared origin holds the authorized tip says the push landed where the gate said it could; it says nothing about who pushed or whether the gate itself was well-founded (spec:402-405).'))
A ''
A 'standing:'
A ("  law: " + (Y 'THE STANDING IS THREE INDEPENDENT READINGS AND THE SEAT HOLDS ONE OF THEM. It does not claim the other two; it records them as attested, which is the difference between a confirmation and a citation of one.'))
A ("  held_here: " + (Y 'reading (i), git ls-remote against the gate''s declared origin'))
A ("  never_authored_here: " + (Y 'reading (iii), the operator''s browser. There is no input to this tool that causes a browser attestation to be recorded which the operator did not pass in -BrowserAttestation.'))

$text = $sb.ToString()
try {
    # ASCII, deliberately: a BOM-less .ps1 and its artifacts are read in the ANSI codepage by
    # PowerShell 5.1, and a non-ASCII byte here becomes a pattern-matching hazard for a checker.
    [System.IO.File]::WriteAllText($OutputPath, $text, (New-Object System.Text.UTF8Encoding($false)))
}
catch {
    Write-Refusal -Headline 'REFUSING -- the anchor could not be written.' -Code 2 -Lines @(
        "path: $OutputPath", "reason: $($_.Exception.Message)")
}

$outSha = Get-Sha256OfFile -Path $OutputPath
Write-Output "record-origin-attestation: WROTE the origin-attestation anchor."
Write-Output "  path   : $OutputPath"
Write-Output "  sha256 : $outSha"
Write-Output "  gate   : $PushGatePath ($gateSha)"
Write-Output "  (i)   ls-remote  : $lsSha   -- THIS TOOL'S, against the gate's declared origin"
Write-Output "  (ii)  gh api     : $ghReadingValue"
Write-Output "  (iii) browser    : $browserReading"
Write-Output "  CITE THIS ARTIFACT BY PATH AND SHA256 IN THE PUSH ANNOTATION. It is not a gate and it"
Write-Output "  is not evidence-plane material; it is one tool's reading beside the operator's attested ones."
exit 0
