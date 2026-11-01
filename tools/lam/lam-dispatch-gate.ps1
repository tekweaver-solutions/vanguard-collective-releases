#Requires -Version 5.1
<#
.SYNOPSIS
  A DISPATCH GATE IS STAMPED BY THE RUNNER AT SPAWN. The decision and the stamp, in one place.
  (Operator ruling (i): "Dispatch gates are stamped by the runner at spawn (candidate
  C5)".)

.DESCRIPTION
  WHAT A DISPATCH GATE AUTHORIZES. One ROUND: the manifest the gate binds by sha256 names the
  dispatch ids of the round in `spawn_order` and the sha256 of each dispatch artifact in `artifacts`.
  Each named id spawns ONCE under the gate, before the gate's `expires_at`, and only while the
  sha256 the caller presents for its artifact -- the runner presents the one it records as
  dispatch_sha256 -- is the sha256 the manifest's row names.

  WHAT THE RUNNER WRITES ONTO THE GATE. At the FIRST spawn under a gate it replaces the minted
  `consumed_at: null` sentinel line IN PLACE with the stamp and appends, after the gate's last line:
      consumed_basis: spawn by the runner under this gate
      consumed_manifest_sha256: <sha256 of the manifest this spawn was authorized by>
      consumed_spawns:
        - {seq: 1, dispatch_id: <id>}
  No other byte already on the gate changes. Every LATER spawn under the same gate appends exactly
  ONE line and changes no byte already there:
        - {seq: <n>, dispatch_id: <id>}
  Appended lines take the body's own line ending: CRLF onto a CRLF body, LF onto an LF body.

  REFUSED BEFORE THE SPAWN, WITH THE GATE BYTE-UNCHANGED. Every refusal carries a code, and the
  runner prints it as DISPATCH-GATE-<CODE>:
      BAD-ID             the -DispatchGate value is not a gate id (\A[A-Za-z0-9][A-Za-z0-9._-]*\z,
                         matched ordinally)
      ABSENT             no .mission/gates/dispatch-<id>.yaml
      UNREADABLE         a shared gate reader is not loaded; or the gate could not be read (held
                         open by a writer through the bounded wait below, or another read fault);
                         or its bytes are not UTF-8
      NOT-DISPATCH       the artifact's own face does not declare the canonical kind `dispatch`
      ID-MISMATCH        the artifact's own column-0 `id:` is not exactly the -DispatchGate value
      REVOKED            the gate carries a revoked_at that is set (not the literal null)
      EXPIRY-UNREADABLE  the gate carries no single expires_at in the mint's format
      EXPIRED            this spawn is at or after expires_at -- EVERY spawn, not only the first
      UNBOUND            binds / binds_sha256 missing or repeated, a binds_sha256 that is not 64
                         hex, or a binds naming no readable file
      MANIFEST-MOVED     the bound file's sha256 is not binds_sha256
      MANIFEST-MALFORMED the bound manifest is not UTF-8, or its spawn_order is absent, repeated,
                         empty, not a one-line flow list or a block list, names a non-id, names one
                         id twice, or carries a line inside the block that is not an item
      FOREIGN-BLOCK      the gate carries consume fields in a shape Read-LamDispatchConsumeBlock
                         does not accept (its docblock lists what it checks)
      OTHER-MANIFEST     the gate was consumed under a different manifest's sha256
      BEYOND-COUNT       the gate already lists as many spawns as the manifest names
      UNNAMED            the manifest's spawn_order does not name this dispatch id
      RESPAWN            this dispatch id is already listed under the gate
      ARTIFACT-SHA       the manifest carries no single artifacts row for this id, or the row's
                         sha256 is not the presented one
      HELD               (stamp only) the gate stayed open in another process, reader or writer,
                         through the bounded wait for the exclusive open
      UNWRITABLE         (stamp only) the exclusive open failed for a reason other than a sharing
                         violation
  The decision takes BAD-ID to ARTIFACT-SHA in the order listed and reports the first that fires,
  with one addition ahead of ABSENT: a shared gate reader that is not loaded refuses UNREADABLE.
  The stamp refuses BAD-ID, ABSENT, then HELD or UNWRITABLE, then UNREADABLE before it takes the
  decision at all.

  THE BOUNDED WAIT. A sharing violation on a read or on the exclusive open is retried
  $script:LamDispatchGateOpenAttempts times, $script:LamDispatchGateOpenPauseMs ms apart; any other
  failure is not retried.

  FIRST STAMP WINS, AGAINST THE RUNNER ITSELF. Invoke-LamDispatchGateStamp opens the gate with
  FileShare.None, reads it through that handle, DECIDES AGAIN over those bytes, and writes through
  the same handle. A second runner that reaches the gate while the first holds it writes nothing to
  the gate -- it is refused UNREADABLE if the hold outlasts the wait at its early read, HELD if it
  outlasts the wait at its stamp; one that arrives after reads the first's block and appends its
  own line or is refused.

  WHAT THIS FILE DOES NOT DO. It does not take the gate lock on behalf of any other writer:
  mission-gate.ps1's revoke reads and rewrites a gate without it, and its reapprove moves the prior
  gate to a .revoked-N name and writes a fresh one at the gate's path without it.

  ONE RETURN SHAPE. Get-LamDispatchGateDecision and Invoke-LamDispatchGateStamp return the same
  property set, refusal or not, so a caller under Set-StrictMode never reads a property a branch
  forgot.

  AN INSTRUMENT SEAM. Invoke-LamDispatchGateStamp takes -BeforeExclusiveOpen, a scriptblock run
  immediately before the exclusive open, so an instrument can put another writer's stamp between
  the call and the open. The runner does not pass it.

  DEPENDENCIES. Dot-source tools/lam/lam-gate-class.ps1 FIRST: this file calls Get-LamGateClassForText,
  Resolve-LamGateKind, Test-LamGateFieldSet and Get-LamGateScalarField and restates none of them.
  It does not dot-source that file itself; with a reader missing, the decision refuses UNREADABLE
  naming it.
#>

$script:LamDispatchGateBasis       = 'spawn by the runner under this gate'
$script:LamDispatchGateIdPattern   = '\A[A-Za-z0-9][A-Za-z0-9._-]*\z'
$script:LamDispatchGateTimeFormat  = 'yyyy-MM-ddTHH:mm:ss.fffZ'
$script:LamDispatchGateTimePattern = '\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z\z'
$script:LamDispatchGateOpenAttempts = 25
$script:LamDispatchGateOpenPauseMs  = 200
# The four keys THIS runner writes, and the three a push settle writes that this runner never
# does. Any of them on a gate whose consumed_at is still the sentinel is a partial block; one of
# the three on a dispatch gate is a block this runner did not write.
$script:LamDispatchConsumeKeys = @('consumed_at', 'consumed_basis', 'consumed_manifest_sha256', 'consumed_spawns')
$script:LamPushConsumeKeys     = @('consumed_origin_tip', 'consumed_ref', 'consumed_origin_before')

function Test-LamDispatchId {
    # ONE id predicate, ordinal, anchored at both ends: `-match` folds case (U+212A KELVIN SIGN
    # matches [K]) and `$` matches before a trailing LF, and both reached a path or a gate line.
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $false }
    return [regex]::IsMatch($Text, $script:LamDispatchGateIdPattern)
}

function Get-LamDispatchGatePath {
    param([Parameter(Mandatory = $true)][string]$MissionRoot, [Parameter(Mandatory = $true)][string]$GateId)
    return (Join-Path $MissionRoot ('.mission\gates\dispatch-' + $GateId + '.yaml'))
}

function Get-LamDispatchGateEol {
    # The body's own line ending: CRLF onto a CRLF body (every gate the mint writes), LF onto an LF
    # body. A body with neither gets CRLF, the mint's.
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return "`r`n" }
    if ($Text.Contains("`r`n")) { return "`r`n" }
    if ($Text.Contains("`n")) { return "`n" }
    return "`r`n"
}

function New-LamDispatchGateResult {
    # THE ONE RETURN SHAPE. $Code empty means admitted.
    param([string]$Code = '', [string]$Reason = '', [string]$GateId = '', [string]$GatePath = '')
    return [pscustomobject]@{
        ok = (-not $Code); code = $Code; reason = $Reason; gate_id = $GateId; gate_path = $GatePath
        manifest_path = ''; manifest_sha256 = ''; spawn_order = @(); count = 0; consumed = $false
        spawns = @(); next_seq = 0; first = $false; expires_at = ''; consumed_at = ''
        spawn_seq = 0; sha_before = ''; sha_after = ''; bytes_before = 0; bytes_after = 0
    }
}

function Get-LamDispatchSha256Hex {
    param([byte[]]$Bytes)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $h.Dispose() }
}

function Get-LamDispatchInnerException {
    # PowerShell wraps an exception a .NET method throws in a MethodInvocationException.
    param($Exception)
    $ex = $Exception
    while (($null -ne $ex) -and ($ex -is [System.Management.Automation.MethodInvocationException]) -and ($null -ne $ex.InnerException)) { $ex = $ex.InnerException }
    return $ex
}

function Test-LamDispatchSharingViolation {
    # ERROR_SHARING_VIOLATION (0x80070020) and ERROR_LOCK_VIOLATION (0x80070021) only.
    param($Exception)
    $ex = Get-LamDispatchInnerException -Exception $Exception
    return (($ex -is [System.IO.IOException]) -and (@(-2147024864, -2147024863) -contains [int]$ex.HResult))
}

function ConvertFrom-LamDispatchGateBytes {
    # ONE DECODE for the early read and the stamp: a UTF-8 byte-order mark is stripped, and the rest
    # must be strict UTF-8. A UTF-16 file is not text here, at either read.
    param([byte[]]$Bytes)
    $bomLen = 0
    if (($Bytes.Length -ge 3) -and ($Bytes[0] -eq 0xEF) -and ($Bytes[1] -eq 0xBB) -and ($Bytes[2] -eq 0xBF)) { $bomLen = 3 }
    try {
        $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($Bytes, $bomLen, $Bytes.Length - $bomLen)
        return [pscustomobject]@{ ok = $true; text = $text; bom_len = $bomLen; reason = '' }
    } catch {
        return [pscustomobject]@{ ok = $false; text = ''; bom_len = $bomLen; reason = 'the bytes are not UTF-8 text' }
    }
}

function Read-LamDispatchGateFile {
    # A plain read of the gate's bytes, with the bounded wait on a sharing violation.
    param([Parameter(Mandatory = $true)][string]$Path)
    $last = ''
    for ($i = 1; $i -le $script:LamDispatchGateOpenAttempts; $i++) {
        try {
            $b = [System.IO.File]::ReadAllBytes($Path)
            return [pscustomobject]@{ ok = $true; bytes = $b; reason = '' }
        } catch {
            $last = [string](Get-LamDispatchInnerException -Exception $_.Exception).Message
            if (-not (Test-LamDispatchSharingViolation -Exception $_.Exception)) { break }
            if ($i -lt $script:LamDispatchGateOpenAttempts) { Start-Sleep -Milliseconds $script:LamDispatchGateOpenPauseMs }
        }
    }
    return [pscustomobject]@{ ok = $false; bytes = $null; reason = $last }
}

function Read-LamDispatchManifestSpawnOrder {
    <#
      The manifest's `spawn_order`: ONE column-0 key, whose value is either a one-line flow list of
      bare ids (`spawn_order: [a, b]`, the form most manifests on this mission use) or a block list
      (`spawn_order:` then `- <id>` items at column 0 or indented, ending at the next column-0 key).
      A second key, a flow list that does not close on its line, a line inside the block that is not
      an item, a comment or a blank, an item that is not an id, a repeated id, or an empty list
      refuses: this reader does not guess which ids were meant.
    #>
    param([AllowNull()][string]$Text)
    $bad = { param($Why) [pscustomobject]@{ ok = $false; ids = @(); reason = $Why } }
    if (-not $Text) { return (& $bad 'the manifest is empty') }
    $lines = $Text -split "`r?`n"
    $keyAt = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '^spawn_order:') { $keyAt += $i }
    }
    if ($keyAt.Count -eq 0) { return (& $bad 'the manifest carries no column-0 spawn_order key') }
    if ($keyAt.Count -gt 1) { return (& $bad ('the manifest carries ' + $keyAt.Count + ' column-0 spawn_order keys, so which one it declares is AMBIGUOUS and this reader does not pick one')) }
    $raw = New-Object System.Collections.Generic.List[string]
    $keyLine = $lines[$keyAt[0]]
    $flow = [regex]::Match($keyLine, '\Aspawn_order:[ \t]*\[(.*)\][ \t]*\z')
    if ($flow.Success) {
        foreach ($part in ($flow.Groups[1].Value -split ',')) { [void]$raw.Add($part.Trim()) }
    } elseif ($keyLine -cmatch '\Aspawn_order:[ \t]*\z') {
        for ($j = $keyAt[0] + 1; $j -lt $lines.Count; $j++) {
            $l = $lines[$j]
            if ($l -cmatch '\A[ \t]*\z') { continue }
            if ($l -cmatch '\A[ \t]*#') { continue }
            $item = [regex]::Match($l, '\A[ \t]*-[ \t]+(.+?)[ \t]*\z')
            if ($item.Success) { [void]$raw.Add($item.Groups[1].Value); continue }
            if ($l -cmatch '\A[A-Za-z_][A-Za-z0-9_]*:') { break }
            return (& $bad ("line " + ($j + 1) + " inside spawn_order is neither an item, a comment, a blank nor the next column-0 key"))
        }
    } else {
        return (& $bad 'spawn_order is neither a one-line flow list [a, b] nor a block list; this reader reads those two forms only')
    }
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($v0 in $raw) {
        $v = $v0
        if (($v.Length -ge 2) -and ((($v.StartsWith("'")) -and ($v.EndsWith("'"))) -or (($v.StartsWith('"')) -and ($v.EndsWith('"'))))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        if (-not (Test-LamDispatchId -Text $v)) { return (& $bad ("spawn_order item '" + $v + "' is not a dispatch id")) }
        if ($ids.Contains($v)) { return (& $bad ("spawn_order names '" + $v + "' twice; one id spawns once per gate, so the list is malformed")) }
        [void]$ids.Add($v)
    }
    if ($ids.Count -eq 0) { return (& $bad 'spawn_order names no dispatch id') }
    return [pscustomobject]@{ ok = $true; ids = @($ids.ToArray()); reason = '' }
}

function Read-LamDispatchManifestArtifactSha {
    <#
      The sha256 the manifest's `artifacts:` block records for ONE dispatch id. An item is a
      `- path: ...` line and the indented lines under it; the item for <id> is the one whose path
      ends in `<id>.yaml` (either separator). Exactly one such item, carrying exactly one 64-hex
      sha256, or this refuses.
    #>
    param([AllowNull()][string]$Text, [Parameter(Mandatory = $true)][string]$Id)
    $bad = { param($Why) [pscustomobject]@{ ok = $false; sha256 = ''; path = ''; reason = $Why } }
    if (-not $Text) { return (& $bad 'the manifest is empty') }
    $lines = $Text -split "`r?`n"
    $keyAt = @()
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -cmatch '\Aartifacts:[ \t]*\z') { $keyAt += $i } }
    if ($keyAt.Count -ne 1) { return (& $bad ('the manifest carries ' + $keyAt.Count + ' column-0 artifacts block key(s); one is required')) }
    $items = New-Object System.Collections.Generic.List[object]
    $cur = $null
    for ($j = $keyAt[0] + 1; $j -lt $lines.Count; $j++) {
        $l = $lines[$j]
        if ($l -cmatch '\A[ \t]*\z') { continue }
        if ($l -cmatch '\A[ \t]*#') { continue }
        $pm = [regex]::Match($l, '\A[ \t]*-[ \t]+path:[ \t]*(\S+)[ \t]*\z')
        if ($pm.Success) {
            $cur = [pscustomobject]@{ path = $pm.Groups[1].Value; shas = (New-Object System.Collections.Generic.List[string]) }
            [void]$items.Add($cur)
            continue
        }
        if ($l -cmatch '\A\S') { break }
        $sm = [regex]::Match($l, '\A[ \t]+sha256:[ \t]*(\S+)[ \t]*\z')
        if (($null -ne $cur) -and $sm.Success) { [void]$cur.shas.Add($sm.Groups[1].Value) }
    }
    $mine = @($items | Where-Object { [regex]::IsMatch(([string]$_.path -replace '\\', '/'), ('(\A|/)' + [regex]::Escape($Id) + '\.yaml\z')) })
    if ($mine.Count -eq 0) { return (& $bad ("the manifest's artifacts block carries no row for '" + $Id + ".yaml', so the bytes this gate authorized for it are not named")) }
    if ($mine.Count -gt 1) { return (& $bad ("the manifest's artifacts block carries " + $mine.Count + " rows for '" + $Id + ".yaml'; this reader does not pick one")) }
    $row = $mine[0]
    if ($row.shas.Count -ne 1) { return (& $bad ("the artifacts row for '" + $Id + "' carries " + $row.shas.Count + " sha256 lines; one is required")) }
    $sha = [string]$row.shas[0]
    if (-not [regex]::IsMatch($sha, '\A[0-9a-fA-F]{64}\z')) { return (& $bad ("the artifacts row for '" + $Id + "' carries sha256 '" + $sha + "', which is not 64 hex")) }
    return [pscustomobject]@{ ok = $true; sha256 = $sha.ToLowerInvariant(); path = [string]$row.path; reason = '' }
}

function Read-LamDispatchConsumeBlock {
    <#
      WHAT CONSUME STATE A DISPATCH GATE CARRIES, read from its text.
        fresh    : consumed_at is the sentinel (or absent), at most one consumed_at key, and none of
                   the other six consume keys present
        consumed : consumed_at is set, and ALL of these hold --
                     one column-0 consumed_at key, its value in the stamp format yyyy-MM-ddTHH:mm:ss.fffZ;
                     none of the three push-settle keys;
                     one consumed_basis line carrying exactly this runner's words;
                     one consumed_manifest_sha256 whose value is 64 hex;
                     one consumed_spawns key with nothing after it on its line;
                     the four keys' lines in the order consumed_at, consumed_basis,
                     consumed_manifest_sha256, consumed_spawns;
                     after consumed_spawns, ONLY lines `  - {seq: <n>, dispatch_id: <id>}` with n
                     running 1..N as written (no leading zero) and <id> a dispatch id, N >= 1, and
                     at most the one empty string a final line ending leaves.
      Anything else refuses. `consumed_at` being set is Test-LamGateFieldSet's answer, the shared
      predicate, so the `(?!null\b)` every minted gate depends on is not restated here.
    #>
    param([AllowNull()][string]$Text)
    $foreign = { param($Why) [pscustomobject]@{ ok = $false; consumed = $false; reason = $Why; manifest_sha256 = ''; spawns = @(); consumed_at = '' } }
    if ($null -eq $Text) { $Text = '' }
    $atKeys = ([regex]::Matches($Text, '(?m)^consumed_at:')).Count
    if ($atKeys -gt 1) { return (& $foreign ('the gate carries ' + $atKeys + ' column-0 consumed_at keys')) }
    $consumed = Test-LamGateFieldSet -Text $Text -Field 'consumed_at'
    $present = New-Object System.Collections.Generic.List[string]
    foreach ($k in @($script:LamDispatchConsumeKeys + $script:LamPushConsumeKeys)) {
        if ($k -ceq 'consumed_at') { continue }
        if ([regex]::IsMatch($Text, ('(?m)^' + [regex]::Escape($k) + ':'))) { [void]$present.Add($k) }
    }
    if (-not $consumed) {
        if ($present.Count -gt 0) {
            return (& $foreign ("consumed_at is still the sentinel while the gate already carries " + ($present.ToArray() -join ', ') + " -- part of a consume block with no stamp, and first stamp wins binds the GATE"))
        }
        return [pscustomobject]@{ ok = $true; consumed = $false; reason = ''; manifest_sha256 = ''; spawns = @(); consumed_at = '' }
    }
    foreach ($pk in $script:LamPushConsumeKeys) {
        if ($present.Contains($pk)) { return (& $foreign ("the gate carries " + $pk + ", a push settle's field, which this runner never writes")) }
    }
    $lines = $Text -split "`r?`n"
    $atIdx = -1; $basisIdx = @(); $msIdx = @(); $spIdx = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '\Aconsumed_at:') { $atIdx = $i }
        if ($lines[$i] -cmatch '\Aconsumed_basis:') { $basisIdx += $i }
        if ($lines[$i] -cmatch '\Aconsumed_manifest_sha256:') { $msIdx += $i }
        if ($lines[$i] -cmatch '\Aconsumed_spawns:') { $spIdx += $i }
    }
    $atM = [regex]::Match($lines[$atIdx], '\Aconsumed_at:[ \t]*(\S*)[ \t]*\z')
    $atVal = if ($atM.Success) { $atM.Groups[1].Value } else { '' }
    if (-not [regex]::IsMatch($atVal, $script:LamDispatchGateTimePattern)) {
        return (& $foreign ("consumed_at reads '" + $atVal + "', not a stamp in the format " + $script:LamDispatchGateTimeFormat))
    }
    if ($basisIdx.Count -ne 1) { return (& $foreign ('consumed_at is set and the gate carries ' + $basisIdx.Count + ' consumed_basis lines, not one')) }
    $bm = [regex]::Match($lines[$basisIdx[0]], '\Aconsumed_basis:[ \t]*(.*?)[ \t]*\z')
    if ((-not $bm.Success) -or ($bm.Groups[1].Value -cne $script:LamDispatchGateBasis)) {
        return (& $foreign ("consumed_basis does not read this runner's words '" + $script:LamDispatchGateBasis + "'"))
    }
    if ($msIdx.Count -ne 1) { return (& $foreign ('consumed_at is set and the gate carries ' + $msIdx.Count + ' consumed_manifest_sha256 lines, not one')) }
    $mm = [regex]::Match($lines[$msIdx[0]], '\Aconsumed_manifest_sha256:[ \t]*([0-9a-fA-F]{64})[ \t]*\z')
    if (-not $mm.Success) { return (& $foreign 'consumed_manifest_sha256 is not 64 hex') }
    if ($spIdx.Count -ne 1) { return (& $foreign ('consumed_at is set and the gate carries ' + $spIdx.Count + ' consumed_spawns keys, not one')) }
    if ($lines[$spIdx[0]] -cnotmatch '\Aconsumed_spawns:[ \t]*\z') { return (& $foreign 'consumed_spawns is not the block list this runner writes') }
    if (-not (($atIdx -lt $basisIdx[0]) -and ($basisIdx[0] -lt $msIdx[0]) -and ($msIdx[0] -lt $spIdx[0]))) {
        return (& $foreign 'the consume keys are not in the order this runner writes them: consumed_at, consumed_basis, consumed_manifest_sha256, consumed_spawns')
    }
    $spawns = New-Object System.Collections.Generic.List[object]
    $last = $lines.Count - 1
    for ($j = $spIdx[0] + 1; $j -le $last; $j++) {
        $l = $lines[$j]
        if ($l -eq '') {
            if ($j -eq $last) { break }
            return (& $foreign ('an empty line sits inside consumed_spawns at line ' + ($j + 1) + '; only the final line ending may follow the last spawn line'))
        }
        $sm = [regex]::Match($l, '\A  - \{seq: ([1-9][0-9]{0,8}), dispatch_id: ([A-Za-z0-9][A-Za-z0-9._-]*)\}\z')
        if (-not $sm.Success) {
            return (& $foreign ("line " + ($j + 1) + " after consumed_spawns is not a spawn line this runner writes, and the list must be the gate's last block"))
        }
        $want = [string]($spawns.Count + 1)
        if ($sm.Groups[1].Value -cne $want) { return (& $foreign ('consumed_spawns lists seq ' + $sm.Groups[1].Value + ' where ' + $want + ' is next')) }
        [void]$spawns.Add([pscustomobject]@{ seq = ($spawns.Count + 1); id = $sm.Groups[2].Value })
    }
    if ($spawns.Count -eq 0) { return (& $foreign 'consumed_at is set and consumed_spawns lists no spawn') }
    return [pscustomobject]@{ ok = $true; consumed = $true; reason = ''; manifest_sha256 = $mm.Groups[1].Value.ToLowerInvariant()
                              spawns = @($spawns.ToArray()); consumed_at = $atVal }
}

function Get-LamDispatchGateDecision {
    <#
      MAY <DispatchId> SPAWN UNDER dispatch-<GateId>.yaml NOW? Read-only. -GateText is the gate's
      text as the caller read it (the stamp passes the text it holds under its lock); when it is not
      given the gate is read here, with the bounded wait, and decoded exactly as the stamp decodes.
      -DispatchSha256 is the sha256 the caller vouches for as the artifact's bytes; when it is not
      given the artifact file is hashed here.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$MissionRoot,
        [AllowEmptyString()][string]$GateId,
        [Parameter(Mandatory = $true)][string]$DispatchId,
        [Parameter(Mandatory = $true)][string]$DispatchPath,
        # UNTYPED ON PURPOSE: a [string] parameter turns $null into '', and '' is a text this reader
        # would then classify -- an empty gate with no kind -- instead of reading the file.
        $GateText = $null,
        [AllowEmptyString()][string]$DispatchSha256 = '',
        [datetime]$NowUtc = [datetime]::MinValue
    )
    if ($NowUtc -eq [datetime]::MinValue) { $NowUtc = [datetime]::UtcNow }
    if (-not (Test-LamDispatchId -Text $GateId)) {
        return (New-LamDispatchGateResult -Code 'BAD-ID' -GateId $GateId -Reason ("-DispatchGate '" + $GateId + "' is not a gate id (" + $script:LamDispatchGateIdPattern + ", ordinal), so no gate path is composed from it"))
    }
    foreach ($needed in @('Get-LamGateClassForText', 'Resolve-LamGateKind', 'Test-LamGateFieldSet', 'Get-LamGateScalarField')) {
        if (-not (Get-Command -Name $needed -CommandType Function -ErrorAction SilentlyContinue)) {
            return (New-LamDispatchGateResult -Code 'UNREADABLE' -GateId $GateId -Reason ("the shared gate reader " + $needed + " (tools/lam/lam-gate-class.ps1) is not loaded, so this gate cannot be read by the one definition"))
        }
    }
    $gatePath = Get-LamDispatchGatePath -MissionRoot $MissionRoot -GateId $GateId
    if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf)) {
        return (New-LamDispatchGateResult -Code 'ABSENT' -GateId $GateId -GatePath $gatePath -Reason ("no dispatch gate at " + $gatePath))
    }
    $t = $GateText
    if ($null -eq $t) {
        $rd = Read-LamDispatchGateFile -Path $gatePath
        if (-not $rd.ok) { return (New-LamDispatchGateResult -Code 'UNREADABLE' -GateId $GateId -GatePath $gatePath -Reason ("the gate could not be read (" + $rd.reason + ")")) }
        $dec = ConvertFrom-LamDispatchGateBytes -Bytes $rd.bytes
        if (-not $dec.ok) { return (New-LamDispatchGateResult -Code 'UNREADABLE' -GateId $GateId -GatePath $gatePath -Reason ('the gate is not UTF-8 text')) }
        $t = $dec.text
    }
    $t = [string]$t
    $refuse = { param($Code, $Why) New-LamDispatchGateResult -Code $Code -GateId $GateId -GatePath $gatePath -Reason $Why }

    $kindRead = [string](Get-LamGateClassForText -Text $t -Path $gatePath).kind
    if ((Resolve-LamGateKind -Kind $kindRead) -cne 'dispatch') {
        return (& $refuse 'NOT-DISPATCH' ("the artifact declares kind '" + $kindRead + "', not the canonical 'dispatch'; the artifact is the authority on its own kind"))
    }
    $idRead = Get-LamGateScalarField -Text $t -Field 'id'
    if ((-not $idRead.ok) -or ($idRead.count -ne 1) -or ([string]$idRead.value -cne $GateId)) {
        return (& $refuse 'ID-MISMATCH' ("the artifact's own column-0 id is '" + [string]$idRead.value + "' (" + $idRead.count + " id line(s)), not '" + $GateId + "'; a file named for one gate that declares another is not that gate"))
    }
    if (Test-LamGateFieldSet -Text $t -Field 'revoked_at') {
        return (& $refuse 'REVOKED' 'the gate is REVOKED, so it authorizes nothing')
    }
    $exp = Get-LamGateScalarField -Text $t -Field 'expires_at'
    $expAt = [datetime]::MinValue
    $expOk = $false
    if ($exp.ok -and ($exp.count -eq 1)) {
        try {
            $expAt = [datetime]::ParseExact([string]$exp.value, $script:LamDispatchGateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture,
                ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
            $expOk = $true
        } catch { $expOk = $false }
    }
    if (-not $expOk) {
        return (& $refuse 'EXPIRY-UNREADABLE' ("the gate carries no single expires_at in the mint's format " + $script:LamDispatchGateTimeFormat + ", so whether this spawn is inside its window cannot be decided"))
    }
    if ($NowUtc -ge $expAt) {
        return (& $refuse 'EXPIRED' ("the gate expired at " + $exp.value + " and this spawn is at " + $NowUtc.ToString($script:LamDispatchGateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture) + "; expiry binds EVERY spawn under a dispatch gate"))
    }
    $binds = Get-LamGateScalarField -Text $t -Field 'binds'
    $bindsSha = Get-LamGateScalarField -Text $t -Field 'binds_sha256'
    if ((-not $binds.ok) -or ($binds.count -ne 1) -or (-not $bindsSha.ok) -or ($bindsSha.count -ne 1) -or (-not [regex]::IsMatch([string]$bindsSha.value, '\A[0-9a-fA-F]{64}\z'))) {
        return (& $refuse 'UNBOUND' 'the gate does not carry exactly one binds and exactly one binds_sha256 of 64 hex, so no manifest is bound')
    }
    $bindsText = [string]$binds.value
    $manifestPath = ''
    try {
        if (($bindsText -match '^[A-Za-z]:[\\/]') -or ($bindsText -match '^[\\/][\\/]')) { $manifestPath = [System.IO.Path]::GetFullPath($bindsText) }
        else { $manifestPath = [System.IO.Path]::GetFullPath((Join-Path $MissionRoot $bindsText)) }
    } catch { $manifestPath = '' }
    if ((-not $manifestPath) -or (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf))) {
        return (& $refuse 'UNBOUND' ("the gate binds '" + $bindsText + "', which names no readable file"))
    }
    $mBytes = $null
    try { $mBytes = [System.IO.File]::ReadAllBytes($manifestPath) }
    catch { return (& $refuse 'UNBOUND' ("the bound manifest " + $manifestPath + " could not be read (" + [string](Get-LamDispatchInnerException -Exception $_.Exception).Message + ")")) }
    $mSha = Get-LamDispatchSha256Hex -Bytes $mBytes
    if ($mSha -cne ([string]$bindsSha.value).ToLowerInvariant()) {
        return (& $refuse 'MANIFEST-MOVED' ("the bound manifest's sha256 is " + $mSha + " and the gate authorized " + ([string]$bindsSha.value).ToLowerInvariant() + "; these are not the bytes the gate was minted over"))
    }
    $mDec = ConvertFrom-LamDispatchGateBytes -Bytes $mBytes
    if (-not $mDec.ok) { return (& $refuse 'MANIFEST-MALFORMED' 'the bound manifest is not UTF-8 text') }
    $mText = $mDec.text
    $order = Read-LamDispatchManifestSpawnOrder -Text $mText
    if (-not $order.ok) { return (& $refuse 'MANIFEST-MALFORMED' $order.reason) }
    $block = Read-LamDispatchConsumeBlock -Text $t
    if (-not $block.ok) { return (& $refuse 'FOREIGN-BLOCK' $block.reason) }
    if ($block.consumed -and ($block.manifest_sha256 -cne $mSha)) {
        return (& $refuse 'OTHER-MANIFEST' ("the gate was consumed under manifest sha256 " + $block.manifest_sha256 + " and this spawn presents " + $mSha))
    }
    $ids = @($order.ids)
    $spawns = @($block.spawns)
    if ($spawns.Count -ge $ids.Count) {
        return (& $refuse 'BEYOND-COUNT' ("the gate already lists " + $spawns.Count + " spawn(s) and the manifest names " + $ids.Count + "; the round is complete"))
    }
    if (@($ids | Where-Object { $_ -ceq $DispatchId }).Count -ne 1) {
        return (& $refuse 'UNNAMED' ("the bound manifest's spawn_order does not name '" + $DispatchId + "' (it names: " + ($ids -join ', ') + ")"))
    }
    $prior = @($spawns | Where-Object { $_.id -ceq $DispatchId })
    if ($prior.Count -gt 0) {
        return (& $refuse 'RESPAWN' ("'" + $DispatchId + "' already spawned under this gate at seq " + $prior[0].seq + "; one id spawns once per gate, and a retry is a new dispatch id under a new manifest and gate"))
    }
    $row = Read-LamDispatchManifestArtifactSha -Text $mText -Id $DispatchId
    if (-not $row.ok) { return (& $refuse 'ARTIFACT-SHA' $row.reason) }
    $aSha = ''
    if ($DispatchSha256) {
        if (-not [regex]::IsMatch($DispatchSha256, '\A[0-9a-fA-F]{64}\z')) { return (& $refuse 'ARTIFACT-SHA' ("the presented artifact sha256 '" + $DispatchSha256 + "' is not 64 hex")) }
        $aSha = $DispatchSha256.ToLowerInvariant()
    } else {
        try { $aSha = Get-LamDispatchSha256Hex -Bytes ([System.IO.File]::ReadAllBytes($DispatchPath)) }
        catch { return (& $refuse 'ARTIFACT-SHA' ("the dispatch artifact " + $DispatchPath + " could not be read (" + [string](Get-LamDispatchInnerException -Exception $_.Exception).Message + ")")) }
    }
    if ($aSha -cne $row.sha256) {
        return (& $refuse 'ARTIFACT-SHA' ("the dispatch artifact's sha256 is " + $aSha + " and the bound manifest's artifacts row for it names " + $row.sha256 + "; these are not the bytes the gate authorized"))
    }
    $ok = New-LamDispatchGateResult -GateId $GateId -GatePath $gatePath
    $ok.manifest_path = $manifestPath
    $ok.manifest_sha256 = $mSha
    $ok.spawn_order = @($ids)
    $ok.count = $ids.Count
    $ok.consumed = [bool]$block.consumed
    $ok.spawns = @($spawns)
    $ok.next_seq = $spawns.Count + 1
    $ok.first = (-not $block.consumed)
    $ok.expires_at = [string]$exp.value
    $ok.consumed_at = [string]$block.consumed_at
    return $ok
}

function Invoke-LamDispatchGateStamp {
    <#
      THE WRITE. Opens the gate FileShare.None (with the bounded wait on a sharing violation), reads
      it through that handle, decides over THOSE bytes, and writes through the same handle only when
      the decision admits. The result carries spawn_seq, consumed_at (the value on the gate after the
      write), sha_before / sha_after and bytes_before / bytes_after. Only the bytes from the first
      difference onward are written; a later spawn's write is a pure append, and that is asserted
      before it is made.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$MissionRoot,
        [AllowEmptyString()][string]$GateId,
        [Parameter(Mandatory = $true)][string]$DispatchId,
        [Parameter(Mandatory = $true)][string]$DispatchPath,
        [AllowEmptyString()][string]$DispatchSha256 = '',
        [datetime]$NowUtc = [datetime]::MinValue,
        [scriptblock]$BeforeExclusiveOpen = $null
    )
    if (-not (Test-LamDispatchId -Text $GateId)) {
        return (New-LamDispatchGateResult -Code 'BAD-ID' -GateId $GateId -Reason ("-DispatchGate '" + $GateId + "' is not a gate id"))
    }
    $gatePath = Get-LamDispatchGatePath -MissionRoot $MissionRoot -GateId $GateId
    if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf)) {
        return (New-LamDispatchGateResult -Code 'ABSENT' -GateId $GateId -GatePath $gatePath -Reason ("no dispatch gate at " + $gatePath))
    }
    if ($null -ne $BeforeExclusiveOpen) { & $BeforeExclusiveOpen }
    $fs = $null
    $openFault = ''
    $shared = $false
    for ($i = 1; $i -le $script:LamDispatchGateOpenAttempts; $i++) {
        try {
            $fs = [System.IO.File]::Open($gatePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            break
        } catch {
            $openFault = [string](Get-LamDispatchInnerException -Exception $_.Exception).Message
            $shared = Test-LamDispatchSharingViolation -Exception $_.Exception
            if (-not $shared) { break }
            if ($i -lt $script:LamDispatchGateOpenAttempts) { Start-Sleep -Milliseconds $script:LamDispatchGateOpenPauseMs }
        }
    }
    if ($null -eq $fs) {
        if ($shared) {
            return (New-LamDispatchGateResult -Code 'HELD' -GateId $GateId -GatePath $gatePath -Reason ("another process kept the gate open, as a reader or a writer, through " + $script:LamDispatchGateOpenAttempts + " attempts " + $script:LamDispatchGateOpenPauseMs + " ms apart (" + $openFault + "); nothing was written"))
        }
        return (New-LamDispatchGateResult -Code 'UNWRITABLE' -GateId $GateId -GatePath $gatePath -Reason ("the gate could not be opened for exclusive write (" + $openFault + "); nothing was written"))
    }
    try {
        if ($NowUtc -eq [datetime]::MinValue) { $NowUtc = [datetime]::UtcNow }
        $len = [int]$fs.Length
        $old = New-Object byte[] $len
        $got = 0
        while ($got -lt $len) {
            $n = $fs.Read($old, $got, $len - $got)
            if ($n -le 0) { break }
            $got += $n
        }
        if ($got -ne $len) {
            return (New-LamDispatchGateResult -Code 'UNREADABLE' -GateId $GateId -GatePath $gatePath -Reason ('read ' + $got + ' of ' + $len + ' bytes through the exclusive handle'))
        }
        $dec = ConvertFrom-LamDispatchGateBytes -Bytes $old
        if (-not $dec.ok) { return (New-LamDispatchGateResult -Code 'UNREADABLE' -GateId $GateId -GatePath $gatePath -Reason 'the gate is not UTF-8 text') }
        $text = $dec.text
        $bomLen = $dec.bom_len

        $d = Get-LamDispatchGateDecision -MissionRoot $MissionRoot -GateId $GateId -DispatchId $DispatchId -DispatchPath $DispatchPath -GateText $text -DispatchSha256 $DispatchSha256 -NowUtc $NowUtc
        if (-not $d.ok) { return $d }

        $eol = Get-LamDispatchGateEol -Text $text
        $stamp = $NowUtc.ToString($script:LamDispatchGateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture)
        $consumedAt = ''
        $body = $text
        if ($d.first) {
            # consumed_at FIRST: the minted sentinel line is replaced where it stands, bounded to its
            # line so a CRLF line keeps its CR; no other existing byte is touched. The rest of the
            # block is appended after the gate's last line.
            if ([regex]::IsMatch($body, '(?m)^consumed_at:')) {
                $body = [regex]::Replace($body, '(?m)^consumed_at:[^\r\n]*', ('consumed_at: ' + $stamp))
            } else {
                if (($body.Length -gt 0) -and (-not $body.EndsWith("`n"))) { $body = $body + $eol }
                $body = $body + 'consumed_at: ' + $stamp + $eol
            }
            if (($body.Length -gt 0) -and (-not $body.EndsWith("`n"))) { $body = $body + $eol }
            $body = $body + 'consumed_basis: ' + $script:LamDispatchGateBasis + $eol +
                    'consumed_manifest_sha256: ' + $d.manifest_sha256 + $eol +
                    'consumed_spawns:' + $eol +
                    '  - {seq: 1, dispatch_id: ' + $DispatchId + '}' + $eol
            $consumedAt = $stamp
        } else {
            if (-not $body.EndsWith("`n")) { $body = $body + $eol }
            $body = $body + '  - {seq: ' + $d.next_seq + ', dispatch_id: ' + $DispatchId + '}' + $eol
            $consumedAt = $d.consumed_at
        }
        $bodyBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($body)
        $new = New-Object byte[] ($bomLen + $bodyBytes.Length)
        if ($bomLen -gt 0) { [System.Array]::Copy($old, 0, $new, 0, $bomLen) }
        [System.Array]::Copy($bodyBytes, 0, $new, $bomLen, $bodyBytes.Length)
        $prefix = 0
        $lim = [Math]::Min($old.Length, $new.Length)
        while (($prefix -lt $lim) -and ($old[$prefix] -eq $new[$prefix])) { $prefix++ }
        if ((-not $d.first) -and ($prefix -ne $old.Length)) {
            return (New-LamDispatchGateResult -Code 'FOREIGN-BLOCK' -GateId $GateId -GatePath $gatePath -Reason 'a later spawn only appends, and the composed bytes do not begin with the gate as it stands; nothing was written')
        }
        $fs.Position = $prefix
        $fs.Write($new, $prefix, $new.Length - $prefix)
        if ($new.Length -lt $old.Length) { $fs.SetLength($new.Length) }
        $fs.Flush($true)
        $d.spawn_seq = $d.next_seq
        $d.consumed_at = $consumedAt
        $d.sha_before = Get-LamDispatchSha256Hex -Bytes $old
        $d.sha_after = Get-LamDispatchSha256Hex -Bytes $new
        $d.bytes_before = $old.Length
        $d.bytes_after = $new.Length
        return $d
    } finally {
        $fs.Dispose()
    }
}
