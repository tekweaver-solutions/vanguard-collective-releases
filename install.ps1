#Requires -Version 5.1
<#
.SYNOPSIS
  Install the framework's installer-owned files into a target folder, byte for byte, or upgrade a folder an
  earlier release installed.

.DESCRIPTION
  THE SOURCE is the tree this script sits in, one of two kinds, and framework.lock records which:
    release  a folder expanded from the release ZIP, with no .git: it holds RELEASE, whose version must be
             VERSION's, whose manifest_sha256 must be the manifest's, and whose framework_repo_tip (40 hex) is
             recorded.
    clone    any folder holding .git (a folder or a file), ACCEPTED ONLY when git, run there, confirms that
             (0) the folder is the top level of its work tree (git rev-parse --is-inside-work-tree true and
             --show-prefix empty, so a junction or subst path to the checkout is the checkout), (1) HEAD is
             exactly the commit the tag v<VERSION> names (VERSION read from HEAD; refs/tags/v<VERSION> listed
             by git for-each-ref under that exact name, case and all, its object peeled to a commit equal to
             git rev-parse HEAD), (2) git status --porcelain prints nothing (an untracked file counts; an
             ignored one does not), and (3) a RELEASE file there is a blob HEAD tracks. Anything else -- git
             not on PATH, a .git git cannot open, a folder safe.directory does not trust, the tag absent or of
             another case, the tag on another commit, a local change, an ignored RELEASE -- is REFUSED before
             the manifest or any source file is read, exit 1, the reason on one line beginning
             'install.ps1: REFUSED:'. A folder holding .git is never taken for an expanded release.
             framework_repo_tip is HEAD; or, when HEAD tracks a RELEASE (a clone of a public tree may), that
             file held as an expanded release's is, and its framework_repo_tip. -ReleaseZip names an
             archive, and is refused with a checkout (exit 1).
  git runs in the source with its redirecting variables cleared (GIT_DIR and the rest, below), so it answers
  for this folder's repository. THE SET is derived from the source's provenance/manifest.jsonl and
  is never listed here: every line whose source is host, whose class is MOVE, TEMPLATE or
  HOST-CONFIG, and whose destination is not null. Nothing else is installed -- not the AUTHORED
  files, not provenance/, and never a smoke mission (tools/lam/build-smoke-mission.ps1 builds one
  beside the project after install).

  EVERY SOURCE FILE IS HELD TO THE MANIFEST before anything is decided (in a clone, after the clone's
  checks above): a file whose bytes do not hash to its manifest line refuses the install (exit 1). In a
  clone, the working copy of the manifest must also be HEAD's, so framework_repo_tip names the tree
  that was installed.

  EOL. A file is TEXT if it holds no 0x00 byte, else BINARY. fold() turns every CR LF pair into LF and
  leaves a lone CR or LF alone; BINARY is never folded. A target file is identical to the source's when
  sha256(fold(target)) = sha256(fold(source)), raw sha256s for BINARY -- Get-JudgedForm, for install,
  upgrade, lock and -Verify alike. The source is held to the manifest raw; no file is rewritten for line
  endings.

  THE PATH GUARD. Get-PathRefusal judges every path inside the target before it is read or written: each
  installer-owned destination, by the install, and each path framework.lock lists, by -Verify. Refused: an
  empty, absolute or drive-qualified path; a '..', empty or '.' segment; a backslash; a character Windows
  does not allow in a name (':' among them, so no alternate data stream); a segment ending in a dot or a
  space; a device name; a path in a mission plane, or the lock itself or a path under its name. Then,
  resolved under the root (a drive root too): a path outside it; a full path of 260 characters or more, or
  a folder of 248 or more; at any component below the root that exists, another name for it (an 8.3 short
  name, which could alias .mission or the lock) or a reparse point of any kind -- a symlink, a junction, or
  a cloud-file placeholder such as OneDrive's; a file where a folder goes; and a file larger than 64 MiB,
  for the reason 'exceeds read bound': every target file is read whole. The target root itself is the
  operator's choice and is not judged. A refusal names the path and the reason.

  THE MODE, by framework.lock's version against VERSION, each major.minor.patch compared as three numbers
  (a pre-release tag, or anything else that does not parse, is refused):
    no framework.lock              -> FRESH install
    the lock older than VERSION    -> UPGRADE
    the lock at VERSION            -> ALREADY INSTALLED: the target is verified against its lock, as -Verify
                                      does, and nothing is written (exit 0, or 3 when a file differs)
    the lock newer than VERSION    -> REFUSED downgrade: nothing is judged, nothing is written

  FRESH, decided for every file BEFORE anything is written:
    absent from the target                        -> install (the source bytes, copied, never re-encoded)
      but the root .gitattributes, the target       -> not-written (THE ROOT .gitattributes, below)
      holding tracked files or git unable to say
    present and identical, as EOL judges it       -> already-identical (not rewritten)
    present, different, class TEMPLATE            -> keep (the host's own instance stands)
    present, different, class MOVE or HOST-CONFIG -> REFUSED not-installed-by-framework

  UPGRADE, decided for every file BEFORE anything is written; the old lock's rows held as Get-HeldSha256 says:
    class TEMPLATE or HOST-CONFIG, present        -> keep (never rewritten; the lock carries this release's
                                                     sha256 beside the file's own, so drift can be read)
    class TEMPLATE or HOST-CONFIG, absent         -> install; the root .gitattributes -> not-written
    class MOVE, absent                            -> install
    class MOVE, identical to this release's       -> already-identical
    class MOVE, identical to the old lock's row,  -> upgrade (this release's bytes, as a new file in place
      and the row says the framework put it there    of the old release's); a kept row says so when its
                                                     sha256 is its upstream_sha256: a template or host-config
                                                     file left as that release shipped it, MOVE in this one
    class MOVE, anything else                     -> REFUSED edited-since-install, not-installed-by-framework
                                                     or host-instance
    in the old lock, not in this release          -> retire (left in place, dropped from the lock)

  THE ROOT .gitattributes is the one TEMPLATE a FRESH install alone writes, and only where the target
  holds no file a git repository tracks: no .git at the target or at any folder above it, or `git ls-files` run there
  (git's redirecting variables cleared) listing nothing; a git that cannot answer counts as tracked. Anywhere else --
  an upgrade, a first install into a repository with files of its own -- an absent one is not-written: its line says
  so and why (a framework install does not change a project's line-ending policy for the project's own files), the
  counts carry not-written=N after kept=, and the lock a not-written row. Where one exists it is kept, as any TEMPLATE.

  ONE REFUSAL REFUSES THE RUN: every refused path is named with its reason, the counts are printed as
  "planned: ...", the exit code is 2, and nothing is written -- no file and no lock. A silent overwrite of a
  file the framework did not put there, or of one somebody edited after it did, is the failure this
  installer exists not to commit. A run that writes prints its counts as "done: ...".

  THE WRITE IS STAGED. Every file to write, and then framework.lock, is first written whole into a staging
  folder at the target root (.framework-staging-<random>) and re-hashed there; only then is each moved into
  place -- an upgraded file's old copy deleted first, so a hard link to it elsewhere keeps its own bytes --
  and the lock last, by File.Replace (never deleted first). A failure while staging changes nothing in the
  target. A failure while moving, the lock's included, leaves whole files only and the lock the target had
  before the run, and the same run again completes it: a file already in place is judged already-identical.
  The staging folder is removed either way, unless the old lock is in it and could not be put back.

  NEVER TOUCHED: the target's .mission/ and .mission-runtime/. No installer-owned destination may
  lie under either (the guard), and the only other write is framework.lock at the target root. Outside the
  target, a run that writes also registers the host (UI-1 S1, ADR-045): <home>/host-id, minted once, and,
  when the target already carries a mission, its row in <home>/projects.yaml (home = $env:VANGUARD_HOME,
  else ~/.vanguard). The telemetry folder inside the target is mission init's to make, not this script's.

  framework.lock -- JSON lines, LF, UTF-8 without BOM, rewritten whole by every run that writes; lock_format 2.
  Line 1 is the header: lock, lock_format, eol_rule, version, previous_version (null on a fresh install),
  framework_repo_tip, source_kind (clone | release), source_tag (a clone's tag, v<VERSION>; null for a
  release), source_commit (a clone's HEAD, 40 hex; null for a release), manifest_sha256, zip_sha256,
  installer_owned, installed_at (an upgrade carries the old lock's over) and upgraded_at (null on a fresh
  install). A lock an earlier installer wrote -- source_kind git-checkout or release, and no source_tag or
  source_commit -- reads, upgrades and verifies as before: no header field but lock, lock_format, eol_rule,
  version, previous_version, upgraded_at and installed_at is read, and a field absent reads as null. Then one
  line per installer-owned file, sorted by path: path; sha256, the file as it stands in the target after
  this run, judged as EOL says; disposition -- installed (written onto an absent path), already-identical,
  upgraded-from <the old lock's version> or kept, or not-written (the root .gitattributes, its sha256 and eol
  null: no file was written); eol, what the file showed when judged: lf, crlf, mixed
  (CR LF and a lone LF) or binary; kind, move, template or host-config; and on a template or host-config
  line upstream_sha256, this release's file judged as EOL says. READ: lock_format 1 and 2. A format-1 lock
  with eol_rule (0.1.1's) recorded judged sha256s; one without (0.1.0's) recorded raw ones, and a file is
  held to such a row exactly (Get-HeldSha256).

  zip_sha256 IS NOT READ FROM RELEASE, because it cannot be there: RELEASE is a member of the ZIP,
  and a file inside an archive cannot carry the archive's own digest (the manifest's own line is
  null for the same reason). Pass -ReleaseZip with the archive the tree was expanded from and the
  installer hashes it, after checking that its RELEASE member is this tree's RELEASE byte for byte.
  Without it zip_sha256 is null.

  THE PYTHON SET (UI-1 S4, ruling F4). A run that writes -- a fresh install or an upgrade -- then installs the
  dashboard service's pinned Python set into the target's tools\.venv, after the lock is in place:
      <tools\.venv's python> -m pip install --require-hashes --only-binary :all: -r <target>\tools\ui\requirements.txt
  from PyPI (the network, as the venv always needed). tools\.venv is the target's own when it holds
  Scripts\python.exe and that interpreter is CPython 3.14 for win-amd64 -- the platform the hashes pin; any
  other interpreter there is left untouched and the step fails. With no tools\.venv the step makes one, with
  -Python when given, else the py launcher's 3.14 (py -3.14), else python on PATH, each held to CPython 3.14
  win-amd64. Every file and the lock stand whatever the step does: when it fails (no such interpreter, pip
  refusing a hash, no network) the reason and the command to run are printed and the exit code is 4. A run
  that writes nothing (-WhatIf, -Verify, a target already at this version) installs nothing; -WhatIf says what
  the step would do. -SkipPythonSet leaves tools\.venv as it stands (`vanguard ui` needs the set).
  THE vanguard COMMAND is tools\ui\vanguard.cmd, installed with the files: `<target>\tools\ui\vanguard.cmd ui`
  starts the dashboard with tools\.venv's interpreter (INSTALL.md section 7).
  -WhatIf also says, writing nothing: the host registration below (host-id, the registry row) and the
  mission-event feed's ignore rule (/.mission-runtime/ in the target's .gitignore), which this script
  never writes -- mission init writes it, and mission.ps1 register for a mission made before the feed.

  MARK OF THE WEB. This script copies bytes; it never runs, dot-sources or imports a file from the
  source tree. A file it writes is a new file and carries no Zone.Identifier stream, whatever the
  source carried. It does NOT Unblock-File its own tree: a marked install.ps1 is refused by a
  RemoteSigned policy before its first line runs, so an unblock inside it could only ever run where
  it was not needed, and stripping streams from the operator's download is the operator's act. It
  REPORTS a marked tree instead (install.ps1 or mission.ps1 carrying a Zone.Identifier stream).
  INSTALL.md records what was measured and which step is the operator's.

.PARAMETER Target
  The folder to install into. Created, with any folder above it that is missing, if it does not exist.
.PARAMETER ReleaseZip
  The release ZIP this tree was expanded from; hashed into framework.lock's zip_sha256.
.PARAMETER WhatIf
  Decide and print every disposition and the planned counts; write nothing. The exit code is the real run's.
.PARAMETER Verify
  Re-judge every file framework.lock lists in the target (EOL above; each path through the guard first);
  print each difference; write nothing. Reads lock_format 1 and 2, and says which it read. A not-written row
  names no file the framework wrote, and is passed over and counted.
.PARAMETER Python
  The CPython 3.14 (win-amd64) interpreter THE PYTHON SET makes tools\.venv with, where the target has none.
.PARAMETER SkipPythonSet
  Install the files and the lock only; tools\.venv is left as it stands.

.NOTES
  EXIT: 0 done, or already installed and verified (or nothing to report); 2 refused, nothing written;
  3 -Verify, or a run over a target already at this version, found differences; 1 the source or the
  target could not be used -- a clone off its release tag, or with local changes, or one git cannot
  confirm, among them; 4 the files and the lock are installed, and the Python set is not (THE PYTHON SET).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [string]$ReleaseZip,
    [switch]$WhatIf,
    [switch]$Verify,
    [string]$Python,
    [switch]$SkipPythonSet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$script:OwnedClasses = @('MOVE', 'TEMPLATE', 'HOST-CONFIG')
$script:Kinds        = @{ 'MOVE' = 'move'; 'TEMPLATE' = 'template'; 'HOST-CONFIG' = 'host-config' }
$script:LockName     = 'framework.lock'
$script:LockId       = 'vanguard-collective/framework.lock'
$script:EolRule      = 'fold-crlf-text'
$script:EolValues    = @('lf', 'crlf', 'mixed', 'binary')
$script:ReadBound    = 67108864
$script:PathLimit    = 260
$script:FolderLimit  = 248
$script:NameChars    = [char[]]@([System.IO.Path]::GetInvalidFileNameChars() | Where-Object { $_ -ne [char]'\' -and $_ -ne [char]'/' })
$script:VersionForm  = '^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\z'
$script:ShaForm      = '^[0-9a-f]{64}\z'
$script:RootAttributes = '.gitattributes'
$script:LinePolicy   = "a framework install does not change a project's line-ending policy for the project's own files"
# git reads these from the environment and would answer for another repository, or with injected configuration
# (tools/provenance/upgrade-diff.py's list, tools/lam/commit_ledger.py's).
$script:GitRedirects = @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY',
    'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_NAMESPACE', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG_COUNT')

function Say { param([string]$Text) [Console]::Out.WriteLine('install.ps1: ' + $Text) }

function Stop-Install {
    param([int]$Code, [string]$Text)
    Say $Text
    exit $Code
}

function Get-Field {
    param($Object, [string]$Name)
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { $d = $h.ComputeHash($Bytes) } finally { $h.Dispose() }
    return ([System.BitConverter]::ToString($d)).Replace('-', '').ToLowerInvariant()
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    $h = [System.Security.Cryptography.SHA256]::Create()
    $s = [System.IO.File]::OpenRead($Path)
    try { $d = $h.ComputeHash($s) } finally { $s.Dispose(); $h.Dispose() }
    return ([System.BitConverter]::ToString($d)).Replace('-', '').ToLowerInvariant()
}

function Get-JudgedForm {
    # THE EOL RULE (header), the one place it is applied: to a source file and to a target file, by the
    # install and by -Verify alike. Returns the sha256 a file is judged by and the eol it showed: binary
    # (a 0x00 byte; never folded), crlf (CR LF pairs, no lone LF), mixed (CR LF pairs and a lone LF),
    # lf (no CR LF pair; a file with no line end too). One pass, left to right: CR CR LF -> CR LF, so
    # pair_left says a CR LF pair is still there after the fold.
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    if ([System.Array]::IndexOf($Bytes, [byte]0) -ge 0) { return [pscustomobject]@{ sha256 = (Get-Sha256Hex -Bytes $Bytes); eol = 'binary'; pair_left = $false } }
    $folded = New-Object System.IO.MemoryStream
    $from = 0; $pairs = 0
    $i = [System.Array]::IndexOf($Bytes, [byte]13)
    while ($i -ge 0 -and $i + 1 -lt $Bytes.Length) {
        if ($Bytes[$i + 1] -eq 10) { $folded.Write($Bytes, $from, $i - $from); $from = $i + 1; $pairs++ }
        $i = [System.Array]::IndexOf($Bytes, [byte]13, $i + 1)
    }
    if ($pairs -eq 0) { return [pscustomobject]@{ sha256 = (Get-Sha256Hex -Bytes $Bytes); eol = 'lf'; pair_left = $false } }
    $folded.Write($Bytes, $from, $Bytes.Length - $from)
    $fb = $folded.ToArray()
    $left = $false
    $i = [System.Array]::IndexOf($fb, [byte]13)
    while (-not $left -and $i -ge 0 -and $i + 1 -lt $fb.Length) { $left = ($fb[$i + 1] -eq 10); $i = [System.Array]::IndexOf($fb, [byte]13, $i + 1) }
    $lf = 0
    $i = [System.Array]::IndexOf($Bytes, [byte]10)
    while ($i -ge 0) { $lf++; $i = [System.Array]::IndexOf($Bytes, [byte]10, $i + 1) }
    return [pscustomobject]@{ sha256 = (Get-Sha256Hex -Bytes $fb); eol = $(if ($lf -gt $pairs) { 'mixed' } else { 'crlf' }); pair_left = $left }
}

function Get-CrlfSha256 {
    # The sha256 of a TEXT file's CRLF form: every LF no CR precedes made CR LF, every other byte left alone.
    # It is the CRLF form of fold(bytes) -- fold() drops exactly the CR before each LF, and the CRLF form puts
    # one back before every LF -- so two files that fold alike have one CRLF form, and a file that had CR LF
    # at every line end IS its CRLF form, byte for byte.
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $out = New-Object System.IO.MemoryStream
    $from = 0
    $i = [System.Array]::IndexOf($Bytes, [byte]10)
    while ($i -ge 0) {
        if ($i -eq 0 -or $Bytes[$i - 1] -ne 13) { $out.Write($Bytes, $from, $i - $from); $out.WriteByte(13); $from = $i }
        $i = [System.Array]::IndexOf($Bytes, [byte]10, $i + 1)
    }
    $out.Write($Bytes, $from, $Bytes.Length - $from)
    return (Get-Sha256Hex -Bytes $out.ToArray())
}

function Get-HeldSha256 {
    # The sha256 a target file is held to its framework.lock row by. A lock with eol_rule recorded judged
    # sha256s: the judged one. A lock without (0.1.0's) recorded the raw sha256 of the bytes 0.1.0 wrote, so
    # a file is held to that row exactly when EOL finds it identical to those bytes, by whichever form shows
    # it: raw (the bytes written); folded, when the judged sha256 equals the row and no CR LF pair is left
    # after the fold (the bytes written held no pair, so fold() left them as they were); or its CRLF form
    # (Get-CrlfSha256), when the bytes written had CR LF at every line end. Only bytes holding both CR LF and
    # a lone LF are beyond all three, and no file 0.1.0 installed held both.
    param([Parameter(Mandatory = $true)]$Lock, [Parameter(Mandatory = $true)]$Judged, [byte[]]$Bytes, [string]$Recorded)
    if ($Lock.folded) { return $Judged.sha256 }
    $raw = Get-Sha256Hex -Bytes $Bytes
    if ($raw -eq $Recorded -or $Judged.eol -eq 'binary') { return $raw }
    if ($Judged.sha256 -eq $Recorded -and -not $Judged.pair_left) { return $Judged.sha256 }
    if ((Get-CrlfSha256 -Bytes $Bytes) -eq $Recorded) { return $Recorded }
    return $raw
}

function ConvertTo-JsonText {
    # One JSON string literal, escaped by hand: PowerShell 5.1's ConvertTo-Json rewrites ' < > & as
    # \u escapes, and the lock is compared byte for byte across installs. The parameter is UNTYPED on
    # purpose: a [string] parameter turns $null into '', and zip_sha256 must read null, not "".
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return 'null' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in ([string]$Value).ToCharArray()) {
        if ($ch -eq [char]'"') { [void]$sb.Append('\"') }
        elseif ($ch -eq [char]'\') { [void]$sb.Append('\\') }
        elseif ([int]$ch -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Get-FullPath {
    # Resolved against PowerShell's location, not the process directory: .NET resolves a relative
    # path against the latter, which Set-Location does not move (docs/framework/LAM-INSTALL.md SS5.4).
    param([Parameter(Mandatory = $true)][string]$Path)
    $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/')
}

function Test-SamePath {
    param([string]$A, [string]$B)
    return [string]::Equals(($A -replace '/', '\').TrimEnd('\'), ($B -replace '/', '\').TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-Git {
    # PS 5.1: under ErrorActionPreference 'Stop' a native command's stderr is fatal, so the
    # preference is relaxed around the one call and restored.
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = @(); $code = -1
    try {
        $out = @(& git -C $Root @GitArgs 2>$null)
        $code = $LASTEXITCODE
    } catch { $out = @(); $code = -1 }
    finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ ok = ($code -eq 0); code = $code; out = ((@($out) | ForEach-Object { [string]$_ }) -join "`n").Trim() }
}

function Invoke-GitIsolated {
    # Invoke-Git with git's redirecting variables cleared for the one call and restored after it, so git answers
    # for the repository Root lies in: for the target (Get-TrackedState) and for the source (THE SOURCE).
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string[]]$GitArgs)
    $saved = @{}
    foreach ($v in $script:GitRedirects) { $saved[$v] = [System.Environment]::GetEnvironmentVariable($v, 'Process'); [System.Environment]::SetEnvironmentVariable($v, $null, 'Process') }
    try { return (Invoke-Git -Root $Root -GitArgs $GitArgs) }
    finally { foreach ($v in $script:GitRedirects) { [System.Environment]::SetEnvironmentVariable($v, $saved[$v], 'Process') } }
}

function Get-TrackedState {
    # THE ROOT .gitattributes (header): whether the target folder holds a file a git repository tracks. { state; code }:
    # 'none' -- the folder does not exist, no .git (a folder or a file) stands at it or at any folder above it, or git
    # lists no tracked file at it or below it; 'tracked'; 'unknown' -- git exited other than 0 (code) or could not be
    # started. git runs once, at the folder, with its redirecting variables cleared, so it answers for the repository the
    # folder lies in.
    param([Parameter(Mandatory = $true)][string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return [pscustomobject]@{ state = 'none'; code = 0 } }
    $at = $Root
    if ($at -match '^[A-Za-z]:$') { $at += '\' }
    $dir = New-Object System.IO.DirectoryInfo $at
    $repo = $false
    while ($null -ne $dir -and -not $repo) {
        $repo = Test-Path -LiteralPath (Join-Path $dir.FullName '.git')
        $dir = $dir.Parent
    }
    if (-not $repo) { return [pscustomobject]@{ state = 'none'; code = 0 } }
    $g = Invoke-GitIsolated -Root $at -GitArgs @('ls-files')
    if (-not $g.ok) { return [pscustomobject]@{ state = 'unknown'; code = $g.code } }
    if ($g.out) { return [pscustomobject]@{ state = 'tracked'; code = 0 } }
    return [pscustomobject]@{ state = 'none'; code = 0 }
}

function Read-JsonLines {
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = $script:Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($Path))
    if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { throw "$Path begins with a byte-order mark" }
    $rows = New-Object System.Collections.Generic.List[object]
    $n = 0
    foreach ($line in $text.Split([char]10)) {
        $n++
        $l = $line.TrimEnd([char]13)
        if ($l.Length -eq 0) { continue }
        try { $rows.Add(($l | ConvertFrom-Json)) } catch { throw "$Path line $n is not JSON: $($_.Exception.Message)" }
    }
    return , $rows.ToArray()
}

function ConvertTo-Version {
    # major.minor.patch as three numbers, or $null: no pre-release or build tag, no leading zero, at most
    # nine digits a part.
    param([AllowNull()]$Text)
    if ($Text -isnot [string]) { return $null }
    if (-not ($Text -match $script:VersionForm)) { return $null }
    return , ([int[]]@([int]$Matches[1], [int]$Matches[2], [int]$Matches[3]))
}

function ConvertTo-Stamp {
    # A lock's time stamp as the installer wrote it, or $null: PowerShell 5.1 reads the stamp as a string,
    # PowerShell 7 as a DateTime.
    param([AllowNull()]$Value)
    if ($Value -is [string]) { return $Value }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture) }
    return $null
}

function Compare-Version {
    param([Parameter(Mandatory = $true)][int[]]$A, [Parameter(Mandatory = $true)][int[]]$B)
    for ($k = 0; $k -lt 3; $k++) { if ($A[$k] -ne $B[$k]) { return [Math]::Sign($A[$k] - $B[$k]) } }
    return 0
}

function Get-PathRefusal {
    # THE PATH GUARD (header), the one place a path inside the target is judged fit to read or write: by the
    # install, for every installer-owned destination before any file is read or written, and by -Verify, for
    # every path framework.lock lists before it is read. Without -Root it judges the path's shape alone (also
    # for each path a lock lists, as Read-Lock reads it); with -Root, also the path resolved under Root.
    # Returns the reason, or '' when the path may be used.
    param([AllowNull()][string]$Rel, [string]$Root)
    if (-not $Rel) { return 'an empty path' }
    if ($Rel -match '^[\\/]') { return 'an absolute path' }
    if ($Rel -match '^[A-Za-z]:') { return 'a drive-qualified path' }
    if (@($Rel -split '[\\/]') -contains '..') { return "a '..' segment, which climbs out of the folder" }
    if ($Rel.Contains('\')) { return 'a backslash (a destination is a forward-slash path)' }
    foreach ($seg in $Rel.Split('/')) {
        if ($seg -eq '' -or $seg -eq '.') { return "an empty or '.' segment" }
        if ($seg.IndexOfAny($script:NameChars) -ge 0) { return "a character Windows does not allow in a name, in '$seg'" }
        if ($seg.EndsWith('.') -or $seg.EndsWith(' ')) { return "'$seg' ends in a dot or a space, which Windows drops" }
        if ($seg -match '^(?i)(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)') { return "'$seg' is a Windows device name" }
    }
    if ($Rel -match '^(?i)\.mission(-runtime)?(/|$)') { return 'it lies in a mission plane' }
    if ([string]::Equals($Rel.Split('/')[0], $script:LockName, [System.StringComparison]::OrdinalIgnoreCase)) { return 'it is the lock, or lies under its name' }
    if (-not $Root) { return '' }
    # Get-FullPath leaves a drive root as 'C:', and Combine('C:', 'x') is 'C:x', relative to the process's
    # folder on that drive: the base always ends in a separator.
    $base = $Root.TrimEnd('\') + '\'
    $full = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($base, ($Rel -replace '/', '\')))
    if (-not $full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) { return "it resolves outside $base" }
    if ($full.Length -ge $script:PathLimit) { return "$($full.Length) characters in full, and Windows allows $($script:PathLimit - 1)" }
    $dir = [System.IO.Path]::GetDirectoryName($full)
    if ($dir.Length -ge $script:FolderLimit) { return "its folder is $($dir.Length) characters, and Windows allows a folder $($script:FolderLimit - 1)" }
    $segs = $Rel.Split('/')
    $walk = $base
    for ($k = 0; $k -lt $segs.Count; $k++) {
        $parent = $walk
        $walk = [System.IO.Path]::Combine($walk, $segs[$k])
        if (-not ([System.IO.File]::Exists($walk) -or [System.IO.Directory]::Exists($walk))) { break }
        # The name on disk must be the name asked for (case aside): an 8.3 short name such as MISSIO~1 opens
        # .mission, and FRAMEW~1.LOC opens framework.lock, past every string test above.
        try { $found = @([System.IO.Directory]::GetFileSystemEntries($parent, $segs[$k])); $attr = [System.IO.File]::GetAttributes($walk) }
        catch { return "$walk cannot be examined: $($_.Exception.Message)" }
        if ($found.Count -ne 1 -or -not [string]::Equals([System.IO.Path]::GetFileName($found[0]), $segs[$k], [System.StringComparison]::OrdinalIgnoreCase)) {
            return "'$($segs[$k])' is another name (an 8.3 short name) for $(@($found | ForEach-Object { [System.IO.Path]::GetFileName($_) }) -join ', ') in $parent"
        }
        if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            $what = 'a reparse point of another kind (a cloud-file placeholder, such as OneDrive''s, is one)'
            try { $lt = (Get-Item -LiteralPath $walk -Force -ErrorAction Stop).LinkType; if ($lt -eq 'Junction') { $what = 'a junction' } elseif ($lt -eq 'SymbolicLink') { $what = 'a symbolic link' } } catch { }
            return "a reparse point stands at ${walk}: $what"
        }
        $isDir = (($attr -band [System.IO.FileAttributes]::Directory) -ne 0)
        if ($k -lt $segs.Count - 1 -and -not $isDir) { return "a file stands where the folder $walk goes" }
        if ($k -eq $segs.Count - 1 -and -not $isDir) {
            $len = (New-Object System.IO.FileInfo($walk)).Length
            if ($len -gt $script:ReadBound) { return "exceeds read bound: $len bytes, and a target file is read whole, $($script:ReadBound) bytes (64 MiB) at most" }
        }
    }
    return ''
}

function Test-MarkOfTheWeb {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { return (@(Get-Item -LiteralPath $Path -Stream * -ErrorAction Stop | Where-Object { $_.Stream -eq 'Zone.Identifier' }).Count -gt 0) }
    catch { return $false }
}

function Invoke-Program {
    # A native program run to its end, its stdout and stderr merged as lines; PS 5.1's 'Stop' relaxed around the
    # one call, as Invoke-Git does.
    param([Parameter(Mandatory = $true)][string]$Exe, [string[]]$ArgList)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = @(); $code = -1
    try { $out = @(& $Exe @ArgList 2>&1 | ForEach-Object { [string]$_ }); $code = $LASTEXITCODE }
    catch { $out = @($_.Exception.Message); $code = -1 }
    finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ code = $code; out = $out }
}

function Get-PythonIdentity {
    # THE PYTHON SET (header): an interpreter's implementation, version, platform and executable, and whether it is
    # CPython 3.14 for win-amd64; $null when it does not run. -Pre goes before the script (py's -3.14).
    param([Parameter(Mandatory = $true)][string]$Exe, [string[]]$Pre)
    $r = Invoke-Program -Exe $Exe -ArgList (@($Pre) + @('-I', '-c', 'import sys,sysconfig;print(sys.implementation.name,''%d.%d.%d''%sys.version_info[:3],sysconfig.get_platform(),sys.executable)'))
    if ($r.code -ne 0 -or $r.out.Count -lt 1) { return $null }
    $f = @($r.out[-1].Trim() -split ' ', 4)
    if ($f.Count -lt 4) { return $null }
    return [pscustomobject]@{ impl = $f[0]; version = $f[1]; platform = $f[2]; exe = $f[3]; fits = ($f[0] -ceq 'cpython' -and $f[1] -match '^3\.14\.\d+$' -and $f[2] -ceq 'win-amd64') }
}

function Get-PythonSetPlan {
    # THE PYTHON SET (header), decided and written nothing: { action = into | create | fail; exe; base; why; text }.
    param([Parameter(Mandatory = $true)][string]$TargetRoot)
    $venv = Join-Path $TargetRoot 'tools\.venv'
    $vpy = Join-Path $venv 'Scripts\python.exe'
    $guard = Get-PathRefusal -Rel 'tools/.venv/Scripts/python.exe' -Root $TargetRoot
    if ($guard) { return [pscustomobject]@{ action = 'fail'; exe = $vpy; base = $null; why = "the path guard refuses tools\.venv: $guard" } }
    if (Test-Path -LiteralPath $vpy -PathType Leaf) {
        $id = Get-PythonIdentity -Exe $vpy
        if ($id -and $id.fits) { return [pscustomobject]@{ action = 'into'; exe = $vpy; base = $null; why = "the target's tools\.venv (CPython $($id.version), $($id.platform))" } }
        return [pscustomobject]@{ action = 'fail'; exe = $vpy; base = $null; why = "the target's tools\.venv is $(if ($id) { "$($id.impl) $($id.version) $($id.platform)" } else { 'an interpreter that does not run' }), not CPython 3.14 win-amd64; it is left untouched" }
    }
    if (Test-Path -LiteralPath $venv) { return [pscustomobject]@{ action = 'fail'; exe = $vpy; base = $null; why = "tools\.venv stands in the target without Scripts\python.exe; it is left untouched" } }
    $tried = New-Object System.Collections.Generic.List[string]
    $cands = @()
    if ($Python) { $cands += , @('-Python', $Python, @()) }
    else {
        if (Get-Command 'py' -ErrorAction SilentlyContinue) { $cands += , @('py -3.14', 'py', @('-3.14')) }
        if (Get-Command 'python' -ErrorAction SilentlyContinue) { $cands += , @('python on PATH', 'python', @()) }
    }
    foreach ($c in $cands) {
        $id = Get-PythonIdentity -Exe $c[1] -Pre $c[2]
        if ($id -and $id.fits) { return [pscustomobject]@{ action = 'create'; exe = $vpy; base = $id.exe; why = "tools\.venv made by $($c[0]): $($id.exe) (CPython $($id.version), $($id.platform))" } }
        $tried.Add("$(if ($c[0] -eq '-Python') { '-Python ' + $c[1] } else { $c[0] }): $(if ($id) { "$($id.impl) $($id.version) $($id.platform)" } else { 'does not run' })")
    }
    return [pscustomobject]@{ action = 'fail'; exe = $vpy; base = $null; why = "no CPython 3.14 win-amd64 interpreter to make tools\.venv with ($(if ($tried.Count) { $tried -join '; ' } else { 'neither py nor python is on PATH' })); name one with -Python" }
}

function Install-PythonSet {
    # THE PYTHON SET (header), after the lock: the venv made where the plan says, then pip with --require-hashes over the
    # installed requirements.txt. Returns '' when the set is installed, else the reason.
    param([Parameter(Mandatory = $true)]$Plan, [Parameter(Mandatory = $true)][string]$TargetRoot)
    if ($Plan.action -eq 'fail') { return $Plan.why }
    if ($Plan.action -eq 'create') {
        $r = Invoke-Program -Exe $Plan.base -ArgList @('-m', 'venv', (Join-Path $TargetRoot 'tools\.venv'))
        if ($r.code -ne 0) { return "$($Plan.base) -m venv exited $($r.code): $((@($r.out) | Select-Object -Last 3) -join ' | ')" }
    }
    $r = Invoke-Program -Exe $Plan.exe -ArgList @('-m', 'pip', 'install', '--require-hashes', '--only-binary', ':all:', '--disable-pip-version-check', '--no-input', '-r', (Join-Path $TargetRoot 'tools\ui\requirements.txt'))
    foreach ($l in @($r.out | Where-Object { $_ -match '^(Successfully installed|ERROR|WARNING)' })) { Say "  pip | $l" }
    $already = @($r.out | Where-Object { $_ -match '^Requirement already satisfied' }).Count
    if ($already -gt 0) { Say "  pip | $already requirement(s) already satisfied" }
    if ($r.code -ne 0) { return "pip exited $($r.code): $((@($r.out) | Select-Object -Last 3) -join ' | ')" }
    return ''
}

function Get-RegistrationPlan {
    # -WhatIf's reading of THE HOST REGISTRATION at the end of this script and of the feed's ignore rule: the same
    # decisions, read only, written nothing. Returns two lines.
    param([Parameter(Mandatory = $true)][string]$TargetRoot)
    $vgHome = if ($env:VANGUARD_HOME) { $env:VANGUARD_HOME } else { Join-Path $env:USERPROFILE '.vanguard' }
    $idPath = Join-Path $vgHome 'host-id'
    $idText = if ([System.IO.File]::Exists($idPath)) { "host-id $(([System.IO.File]::ReadAllText($idPath)).Trim()) in $vgHome, kept" } else { "a host-id would be minted in $vgHome" }
    $mission = $null
    $mf = Join-Path $TargetRoot '.mission\mission.yaml'
    if ([System.IO.File]::Exists($mf)) {
        $mm = [regex]::Matches([System.IO.File]::ReadAllText($mf), '(?m)^id:[ \t]*([^\s#]+)')
        if ($mm.Count -eq 1 -and $mm[0].Groups[1].Value -ne 'null') { $mission = $mm[0].Groups[1].Value.Trim('"', "'") }
    }
    $feed = [System.IO.Directory]::Exists((Join-Path $TargetRoot '.mission-runtime\telemetry'))
    if (-not $mission) { $rowText = 'no registry row (the target carries no mission yet: mission init adds it)' }
    elseif (-not $feed) { $rowText = "no registry row: the target's mission $mission is not registered for the mission-event feed (no .mission-runtime/telemetry/) -- mission.ps1 register -Target $TargetRoot makes the folder, the row and the ignore rule" }
    else {
        $reg = Join-Path $vgHome 'projects.yaml'
        $known = $false
        if ([System.IO.File]::Exists($reg)) {
            foreach ($row in [regex]::Matches([System.IO.File]::ReadAllText($reg), "(?m)^\s*(?:-\s+)?checkout_path:\s*'((?:[^']|'')*)'\s*\r?$")) {
                if ([string]::Equals((($row.Groups[1].Value -replace "''", "'").TrimEnd('\', '/')), ([System.IO.Path]::GetFullPath($TargetRoot).TrimEnd('\', '/')), [System.StringComparison]::OrdinalIgnoreCase)) { $known = $true }
            }
        }
        $rowText = if ($known) { "the target already has its row in $reg" } else { "a row for the target (mission $mission) would be added to $reg" }
    }
    $gi = Join-Path $TargetRoot '.gitignore'
    $held = $false
    if ([System.IO.File]::Exists($gi)) {
        $giLines = @(($script:Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($gi)).TrimStart([char]0xFEFF) -split "`n") | ForEach-Object { $_.TrimEnd(' ', "`r") })
        $held = (@(@('/.mission-runtime/telemetry/', '.mission-runtime/telemetry/', '/.mission-runtime/', '.mission-runtime/') | Where-Object { $giLines -ccontains $_ }).Count -gt 0)
    }
    # RELEASE-4 S2 F-H12 (S1 F2): the rule named is the runtime plane's, /.mission-runtime/, which mission init and register
    # write (S1 F-P7a); a project's older /.mission-runtime/telemetry/ rule is still read as holding the feed's folder.
    $giText = if ($held) { "the target's .gitignore already ignores /.mission-runtime/ (or the feed's folder within it)" }
        elseif ($mission) { "the target's .gitignore does not ignore /.mission-runtime/; install.ps1 writes no .gitignore -- mission.ps1 register -Target $TargetRoot adds the rule" }
        else { "no mission yet: mission init writes the rule /.mission-runtime/ into the target's .gitignore" }
    return @("planned host registration: $idText; $rowText", "planned telemetry ignore rule: $giText")
}

function Get-JsonMemberText {
    # THE EXACT TEXT of one member of a JSON object as the file carries it -- from its quoted key (the first at or after
    # -From that a ':' follows) to the end of its value, an array or an object matched bracket by bracket outside
    # strings. '' when there is none. Read from the file, never re-serialised, so what it prints is the file's own.
    param([string]$Text, [string]$Name, [int]$From = 0)
    $key = '"' + $Name + '"'
    $k = $Text.IndexOf($key, $From, [System.StringComparison]::Ordinal)
    $i = -1
    while ($k -ge 0) {
        $i = $k + $key.Length
        while ($i -lt $Text.Length -and [char]::IsWhiteSpace($Text[$i])) { $i++ }
        if ($i -lt $Text.Length -and $Text[$i] -eq [char]':') { break }
        $k = $Text.IndexOf($key, $k + 1, [System.StringComparison]::Ordinal)
    }
    if ($k -lt 0) { return '' }
    $i++
    while ($i -lt $Text.Length -and [char]::IsWhiteSpace($Text[$i])) { $i++ }
    if ($i -ge $Text.Length -or ($Text[$i] -ne [char]'[' -and $Text[$i] -ne [char]'{')) { return '' }
    $depth = 0; $inString = $false
    for ($j = $i; $j -lt $Text.Length; $j++) {
        $c = $Text[$j]
        if ($inString) { if ($c -eq [char]'\') { $j++ } elseif ($c -eq [char]'"') { $inString = $false }; continue }
        if ($c -eq [char]'"') { $inString = $true }
        elseif ($c -eq [char]'[' -or $c -eq [char]'{') { $depth++ }
        elseif ($c -eq [char]']' -or $c -eq [char]'}') { $depth--; if ($depth -eq 0) { return $Text.Substring($k, $j - $k + 1) } }
    }
    return ''
}

function Get-SettingsRegistrationGap {
    # THE HOOK REGISTRATIONS a release's settings file carries that a project's own copy lacks (RELEASE-4 S2 F-H5): one
    # entry per event of the release's "hooks" with a command the project registers under no hook of that event --
    # @{ event; present (the project has the event at all); commands; block (the release file's own text for the event) }.
    param([string]$ReleaseText, [string]$ProjectText)
    try { $rel = $ReleaseText | ConvertFrom-Json } catch { return @{ ok = $false; why = "this release's file does not parse as JSON"; events = @() } }
    try { $prj = $ProjectText | ConvertFrom-Json } catch { return @{ ok = $false; why = "the project's file does not parse as JSON, so its registrations cannot be compared"; events = @() } }
    $relHooks = Get-Field $rel 'hooks'
    $prjHooks = $null; if ($prj -is [System.Management.Automation.PSCustomObject]) { $prjHooks = Get-Field $prj 'hooks' }
    $gap = @()
    if ($relHooks -isnot [System.Management.Automation.PSCustomObject]) { return @{ ok = $true; why = ''; events = @() } }
    $hooksAt = [Math]::Max(0, $ReleaseText.IndexOf('"hooks"', [System.StringComparison]::Ordinal))
    foreach ($ev in @($relHooks.PSObject.Properties | ForEach-Object { $_.Name })) {
        $have = @(); $present = $false
        if ($prjHooks -is [System.Management.Automation.PSCustomObject] -and $null -ne $prjHooks.PSObject.Properties[$ev]) {
            $present = $true
            foreach ($g in @($prjHooks.PSObject.Properties[$ev].Value)) { foreach ($h in @(Get-Field $g 'hooks')) { if ($null -ne $h) { $have += [string](Get-Field $h 'command') } } }
        }
        $missing = @()
        foreach ($g in @($relHooks.PSObject.Properties[$ev].Value)) { foreach ($h in @(Get-Field $g 'hooks')) { if ($null -ne $h -and $have -cnotcontains [string](Get-Field $h 'command')) { $missing += [string](Get-Field $h 'command') } } }
        if ($missing.Count) { $gap += @{ event = $ev; present = $present; commands = $missing; block = (Get-JsonMemberText -Text $ReleaseText -Name $ev -From $hooksAt) } }
    }
    return @{ ok = $true; why = ''; events = $gap }
}

function Read-Lock {
    # framework.lock, read whole: lock_format 1 (0.1.0's, no eol_rule and no eol; 0.1.1's, eol_rule and an eol
    # column) or 2 (this installer's: kind, and upstream_sha256 beside a template or host-config row). Its
    # version must parse, and every path it lists must pass the guard's shape test.
    param([Parameter(Mandatory = $true)][string]$TargetRoot)
    $path = Join-Path $TargetRoot $script:LockName
    if (-not ([System.IO.File]::Exists($path) -or [System.IO.Directory]::Exists($path))) { return $null }
    $attr = [System.IO.File]::GetAttributes($path)
    if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "$path is a reparse point (a symlink, a junction or a cloud-file placeholder)" }
    if (($attr -band [System.IO.FileAttributes]::Directory) -ne 0) { throw "$path is a folder" }
    $len = (New-Object System.IO.FileInfo($path)).Length
    if ($len -gt $script:ReadBound) { throw "$path exceeds read bound: $len bytes, $($script:ReadBound) at most" }
    $rows = Read-JsonLines -Path $path
    if ($rows.Count -lt 1) { throw "$path is empty" }
    $head = $rows[0]
    # An integer, 1 or 2: PowerShell 5.1 reads it as an Int32, PowerShell 7 as an Int64.
    $lf = Get-Field $head 'lock_format'
    $format = 0
    if (($lf -is [int] -or $lf -is [long]) -and ($lf -eq 1 -or $lf -eq 2)) { $format = [int]$lf }
    if ((Get-Field $head 'lock') -ne $script:LockId -or $format -eq 0) {
        throw "$path does not begin with a lock_format 1 or 2 header"
    }
    # No eol_rule key: written by 0.1.0, which recorded raw sha256s and no eol. Any other value but the rule's
    # own name, compared ordinally, leaves the lock unreadable. Format 2 always names it.
    $rule = $null
    $ruleProp = $head.PSObject.Properties['eol_rule']
    if ($null -ne $ruleProp) {
        $rule = $ruleProp.Value
        if ($rule -isnot [string] -or $rule -cne $script:EolRule) { throw "$path names eol_rule '$rule', which this installer does not judge by" }
    } elseif ($format -eq 2) { throw "$path is lock_format 2 and names no eol_rule" }
    $version = Get-Field $head 'version'
    $parts = ConvertTo-Version $version
    if ($null -eq $parts) { throw "$path names version '$version', which is not major.minor.patch" }
    if ($format -eq 2) {
        $prev = Get-Field $head 'previous_version'
        if ($null -ne $prev -and $null -eq (ConvertTo-Version $prev)) { throw "$path names previous_version '$prev', which is not major.minor.patch" }
        $at = Get-Field $head 'upgraded_at'
        if ($null -ne $at -and $null -eq (ConvertTo-Stamp $at)) { throw "$path names an upgraded_at that is not a time stamp" }
    }
    # Keyed without regard to case, as Windows names files: one path listed twice in two cases is one file,
    # and a release that changes a path's case still finds its row.
    $files = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    for ($i = 1; $i -lt $rows.Count; $i++) {
        $r = $rows[$i]
        $p = Get-Field $r 'path'; $s = Get-Field $r 'sha256'; $d = Get-Field $r 'disposition'
        $e = Get-Field $r 'eol'; $k = Get-Field $r 'kind'; $u = Get-Field $r 'upstream_sha256'
        # A not-written row (format 2, the root .gitattributes) names no file: its sha256 and eol are present and null.
        $nw = ($format -eq 2) -and ($d -ceq 'not-written')
        $bad = ($p -isnot [string]) -or ($d -isnot [string]) -or ((-not $nw) -and (($s -isnot [string]) -or ($s -cnotmatch $script:ShaForm)))
        if (-not $bad -and $format -eq 1) {
            $bad = (@('installed', 'host-instance-kept') -cnotcontains $d) -or (($null -ne $rule) -and (($e -isnot [string]) -or ($script:EolValues -cnotcontains $e)))
        } elseif (-not $bad -and $nw) {
            $bad = ($null -eq $r.PSObject.Properties['sha256']) -or ($null -ne $s) -or ($null -eq $r.PSObject.Properties['eol']) -or ($null -ne $e) -or
                ($k -cne 'template') -or ($u -isnot [string]) -or ($u -cnotmatch $script:ShaForm)
        } elseif (-not $bad) {
            $up = $d -cmatch '^upgraded-from (\S+)\z'
            $bad = ($up -and $null -eq (ConvertTo-Version $Matches[1])) -or (-not $up -and @('installed', 'already-identical', 'kept') -cnotcontains $d) -or
                ($e -isnot [string]) -or ($script:EolValues -cnotcontains $e) -or (@($script:Kinds.Values) -cnotcontains $k) -or
                ($k -ceq 'move' -and $null -ne $r.PSObject.Properties['upstream_sha256']) -or ($k -cne 'move' -and (($u -isnot [string]) -or ($u -cnotmatch $script:ShaForm)))
        }
        if ($bad) {
            throw "$path line $($i + 1) is not a {path, sha256, disposition$(if ($null -ne $rule) { ', eol' })$(if ($format -eq 2) { ', kind[, upstream_sha256]' })} entry of lock_format $format"
        }
        $why = Get-PathRefusal -Rel $p
        if ($why) { throw "$path line $($i + 1) lists '$p', which the path guard refuses: $why" }
        if ($files.ContainsKey($p)) { throw "$path lists $p twice" }
        $files[$p] = [pscustomobject]@{ sha256 = $s; disposition = $d; eol = $(if ($null -ne $rule) { [string]$e } else { '' }); kind = $(if ($format -eq 2) { [string]$k } else { '' })
            upstream = $(if ($format -eq 2 -and $k -cne 'move') { [string]$u } else { '' }) }
    }
    return [pscustomobject]@{ path = $path; header = $head; format = $format; files = $files; folded = ($null -ne $rule); version = $version; parts = $parts }
}

function Invoke-Verify {
    # The target against its own lock: for -Verify, and for a run over a target already at this version.
    # Every listed path passes the guard before it is read. Prints each difference; returns their number.
    param([Parameter(Mandatory = $true)]$Lock, [Parameter(Mandatory = $true)][string]$TargetRoot)
    Say ("verify: lock version {0}, framework_repo_tip {1}, installed_at {2}" -f $Lock.version, (Get-Field $Lock.header 'framework_repo_tip'), (ConvertTo-Stamp (Get-Field $Lock.header 'installed_at')))
    $read = "verify: read lock_format $($Lock.format)"
    if (-not $Lock.folded) { $read += ', no eol_rule (0.1.0''s: raw sha256s)' }
    elseif ($Lock.format -eq 2 -and $null -ne (Get-Field $Lock.header 'previous_version')) { $read += (', upgraded from {0} at {1}' -f (Get-Field $Lock.header 'previous_version'), (ConvertTo-Stamp (Get-Field $Lock.header 'upgraded_at'))) }
    Say $read
    $diff = 0
    $notWritten = 0
    $eolCount = [ordered]@{}
    foreach ($k in $script:EolValues) { $eolCount[$k] = 0 }
    $lockKeys = [string[]]@($Lock.files.Keys)
    [System.Array]::Sort($lockKeys, [System.StringComparer]::Ordinal)
    foreach ($p in $lockKeys) {
        $e = $Lock.files[$p]
        # The framework wrote nothing there; a file the project put there since is the project's.
        if ($e.disposition -ceq 'not-written') { $notWritten++; continue }
        if ($e.eol) { $eolCount[$e.eol]++ }
        $why = Get-PathRefusal -Rel $p -Root $TargetRoot
        if ($why) { $diff++; Say "  REFUSED  $p  -- path guard: $why"; continue }
        $full = Join-Path $TargetRoot ($p -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { $diff++; Say "  MISSING  $p"; continue }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $now = Get-HeldSha256 -Lock $Lock -Judged (Get-JudgedForm -Bytes $bytes) -Bytes $bytes -Recorded $e.sha256
        if ($now -ne $e.sha256) { $diff++; Say "  CHANGED  $p  lock=$($e.sha256) now=$now" }
    }
    $eolText = (@($script:EolValues | ForEach-Object { "$_=$($eolCount[$_])" }) -join ' ')
    if (-not $Lock.folded) { $eolText = 'not recorded (a lock with no eol_rule)' }
    Say "verify: $($Lock.files.Count) file(s) listed$(if ($notWritten -gt 0) { ", $notWritten not written" }), $diff difference(s); eol $eolText."
    return $diff
}

# ------------------------------------------------------------------------------------------------
# THE TARGET
# ------------------------------------------------------------------------------------------------
if ($WhatIf -and $Verify) { Stop-Install 1 'choose one of -WhatIf and -Verify.' }

$sourceRoot = Get-FullPath $PSScriptRoot
$targetRoot = Get-FullPath $Target
if (Test-Path -LiteralPath $targetRoot -PathType Leaf) { Stop-Install 1 "the target is a file, not a folder: $targetRoot" }
if ((Test-SamePath $targetRoot $sourceRoot) -or $targetRoot.StartsWith($sourceRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-Install 1 "the target is the source tree or lies inside it: $targetRoot"
}

# ------------------------------------------------------------------------------------------------
# -Verify: the target against its own lock. Nothing in the source is consulted.
# ------------------------------------------------------------------------------------------------
if ($Verify) {
    $lock = $null
    try { $lock = Read-Lock -TargetRoot $targetRoot } catch { Stop-Install 1 "framework.lock cannot be read: $($_.Exception.Message)" }
    if ($null -eq $lock) { Stop-Install 1 "no framework.lock at $targetRoot -- nothing was installed there, so there is nothing to verify." }
    Say "verify: target $targetRoot"
    $diff = Invoke-Verify -Lock $lock -TargetRoot $targetRoot
    if ($diff -gt 0) { exit 3 }
    exit 0
}

# ------------------------------------------------------------------------------------------------
# THE SOURCE'S KIND (header), decided first. A folder holding .git is a clone and nothing else: git must confirm
# it is the top level of a checkout at its release tag with no local change, before the manifest or any source
# file is read. A git that cannot answer refuses it; it never falls through to the expanded-release branch.
# ------------------------------------------------------------------------------------------------
$sourceKind = ''
$tip = ''
$zipSha = $null
$sourceTag = $null
$sourceCommit = $null
$cloneVersion = $null
$releaseTracked = $false
$relPath = Join-Path $sourceRoot 'RELEASE'

function Stop-Unconfirmed {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Stop-Install 1 "REFUSED: the source holds .git but git cannot confirm it is a clean checkout at the release tag ($Reason) -- install from a clone git can read there (git on PATH, the folder trusted by safe.directory), or from the release ZIP. Nothing was written."
}

if (Test-Path -LiteralPath (Join-Path $sourceRoot '.git')) {
    $sourceKind = 'clone'
    if ($ReleaseZip) { Stop-Install 1 'REFUSED: -ReleaseZip names an archive, but the source is a git checkout, not an expanded release. Nothing was written.' }
    # (0) This folder is the top level of its work tree, asked of git itself rather than compared as a path string,
    # so a junction, a subst drive or an 8.3 name for the checkout is the checkout, and a .git git does not take
    # for a repository (an empty folder, a .git file naming nothing) is never passed over for one above it.
    $gitWhere = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('rev-parse', '--is-inside-work-tree', '--show-prefix')
    if ($gitWhere.code -eq -1) { Stop-Unconfirmed 'git could not be started: it is not on PATH, or not runnable' }
    if (-not $gitWhere.ok) { Stop-Unconfirmed "git rev-parse exited $($gitWhere.code): a .git git cannot open, or a folder safe.directory does not trust" }
    $whereLines = @($gitWhere.out.Split([char]10) | ForEach-Object { $_.Trim() })
    if ($whereLines[0] -cne 'true') { Stop-Unconfirmed 'git says the folder is not inside a work tree' }
    if ($whereLines.Count -gt 1 -and $whereLines[1]) { Stop-Unconfirmed "git answers for a work tree whose top level lies above the folder, prefix '$($whereLines[1])'" }
    $headAsk = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('rev-parse', '--verify', '--quiet', 'HEAD^{commit}')
    if (-not $headAsk.ok -or $headAsk.out -notmatch '^[0-9a-f]{40}$') { Stop-Unconfirmed 'no readable HEAD' }
    $sourceCommit = $headAsk.out
    # VERSION as HEAD holds it, so the tag is named before the working tree is trusted for anything.
    $vAsk = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('cat-file', 'blob', 'HEAD:VERSION')
    if (-not $vAsk.ok) { Stop-Unconfirmed 'HEAD carries no VERSION' }
    $cloneVersion = $vAsk.out.Trim()
    if ($null -eq (ConvertTo-Version $cloneVersion)) { Stop-Install 1 "REFUSED: HEAD's VERSION is not a version (major.minor.patch, no pre-release tag): '$cloneVersion'. Nothing was written." }
    # (1) HEAD is the commit the release tag names. The ref is found under its exact name, case and all (a loose ref
    # of another case resolves on a case-blind file system), and its object is peeled to its commit, so a
    # lightweight and an annotated tag alike are accepted.
    $sourceTag = 'v' + $cloneVersion
    $wantRef = 'refs/tags/' + $sourceTag
    $refs = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('for-each-ref', '--format=%(refname)%09%(objectname)', 'refs/tags/')
    if (-not $refs.ok) { Stop-Unconfirmed "git for-each-ref exited $($refs.code)" }
    $tagObject = $null
    $otherCase = New-Object System.Collections.Generic.List[string]
    foreach ($refLine in $refs.out.Split([char]10)) {
        $cols = $refLine.Trim().Split([char]9)
        if ($cols.Count -ne 2) { continue }
        if ($cols[0] -ceq $wantRef) { $tagObject = $cols[1] }
        elseif ([string]::Equals($cols[0], $wantRef, [System.StringComparison]::OrdinalIgnoreCase)) { $otherCase.Add($cols[0].Substring(10)) }
    }
    $tagAt = $null
    if ($null -ne $tagObject -and $tagObject -match '^[0-9a-f]{40}$') {
        $peeled = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('rev-parse', '--verify', '--quiet', ($tagObject + '^{commit}'))
        if ($peeled.ok -and $peeled.out -match '^[0-9a-f]{40}$') { $tagAt = $peeled.out }
    }
    if ($tagAt -ne $sourceCommit) {
        $tagWhere = 'absent'
        if ($null -ne $tagAt) { $tagWhere = "at $tagAt" }
        elseif ($otherCase.Count -gt 0) { $tagWhere = "absent; $($otherCase -join ', ') differs from it in case" }
        Stop-Install 1 "REFUSED: the source checkout is not at tag $sourceTag (HEAD $sourceCommit; tag $sourceTag $tagWhere) -- install from a clone at the release tag, or from the release ZIP. Nothing was written."
    }
    # (2) No local change: git status --porcelain prints nothing. An untracked file is listed, an ignored one is
    # not. --no-optional-locks: the source's index is not rewritten by the asking.
    $status = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('--no-optional-locks', 'status', '--porcelain', '--untracked-files=normal')
    if (-not $status.ok) {
        Stop-Install 1 "REFUSED: git status could not be read in the source checkout (git exited $($status.code)), so its local changes cannot be ruled out -- install from a clean clone at the release tag. Nothing was written."
    }
    if ($status.out) {
        $changed = @($status.out.Split([char]10))
        foreach ($chg in @($changed | Select-Object -First 10)) { Say "  LOCAL CHANGE  $chg" }
        if ($changed.Count -gt 10) { Say "  ... and $($changed.Count - 10) more" }
        Stop-Install 1 'REFUSED: the source checkout has local changes (git status --porcelain is not empty) -- install from a clean clone at the release tag. Nothing was written.'
    }
    # (3) A RELEASE file is read in a clone only when HEAD tracks it: an ignored one (.git/info/exclude, a global
    # excludes file) is invisible to git status, and would otherwise name the lock's framework_repo_tip.
    if (Test-Path -LiteralPath $relPath -PathType Leaf) {
        $relType = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('cat-file', '-t', 'HEAD:RELEASE')
        if (-not $relType.ok -or $relType.out -cne 'blob') {
            Stop-Install 1 'REFUSED: the source checkout holds a RELEASE file that HEAD does not track (git ignores it, so git status does not list it) -- remove it, or install from a clean clone at the release tag. Nothing was written.'
        }
        $releaseTracked = $true
    }
    $mHead = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('rev-parse', 'HEAD:provenance/manifest.jsonl')
    $mWork = Invoke-GitIsolated -Root $sourceRoot -GitArgs @('hash-object', '--', 'provenance/manifest.jsonl')
    if (-not $mHead.ok -or -not $mWork.ok -or $mHead.out -ne $mWork.out) {
        Stop-Install 1 "REFUSED: the checkout's provenance/manifest.jsonl is not HEAD's ($($mWork.out) against $($mHead.out)) -- commit or restore it, so the lock names the tree it installed. Nothing was written."
    }
}

# ------------------------------------------------------------------------------------------------
# THE SOURCE: the manifest, the installer-owned set, every file held to its line, the identity.
# ------------------------------------------------------------------------------------------------
$manifestPath = Join-Path $sourceRoot 'provenance\manifest.jsonl'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { Stop-Install 1 "no provenance/manifest.jsonl in the source tree $sourceRoot" }
$manifestSha = Get-FileSha256Hex -Path $manifestPath
$rows = $null
try { $rows = Read-JsonLines -Path $manifestPath } catch { Stop-Install 1 "the manifest cannot be read: $($_.Exception.Message)" }
if ($rows.Count -lt 2 -or (Get-Field $rows[0] 'manifest') -ne 'provenance') { Stop-Install 1 'the manifest does not begin with its provenance header.' }

# A destination the guard refuses by its shape is carried to the decision as REFUSED, and its file is read
# neither in the source nor in the target.
$owned = New-Object System.Collections.Generic.List[object]
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$faults = New-Object System.Collections.Generic.List[string]
for ($i = 1; $i -lt $rows.Count; $i++) {
    $r = $rows[$i]
    if ((Get-Field $r 'source') -ne 'host') { continue }
    if ($script:OwnedClasses -notcontains [string](Get-Field $r 'class')) { continue }
    $dest = Get-Field $r 'destination'
    if ($null -eq $dest) { continue }
    if (-not $seen.Add([string]$dest)) { $faults.Add("manifest line $($i + 1): destination '$dest' appears twice"); continue }
    $sha = [string](Get-Field $r 'sha256')
    if ($sha -cnotmatch $script:ShaForm) { $faults.Add("manifest line $($i + 1): '$dest' carries no sha256"); continue }
    $class = [string](Get-Field $r 'class')
    $owned.Add([pscustomobject]@{ path = [string]$dest; class = $class; kind = $script:Kinds[$class]; sha256 = $sha; bytes = [long](Get-Field $r 'bytes'); judged = ''; refused = (Get-PathRefusal -Rel ([string]$dest)) })
}
if ($faults.Count -gt 0) { foreach ($f in $faults) { Say "  MANIFEST FAULT  $f" }; Stop-Install 1 "the manifest cannot define the installer-owned set ($($faults.Count) fault(s))." }
if ($owned.Count -eq 0) { Stop-Install 1 'the manifest defines no installer-owned file.' }
# ORDINAL, never Sort-Object: a culture-aware order could differ between two hosts, and the lock is
# compared byte for byte across installs. The keys alone are sorted and the rows looked up by them:
# Array.Sort(keys, items) binds PowerShell's generic overload, which sorts a converted COPY of the items
# and leaves them in the manifest's order.
$byPath = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
foreach ($o in $owned) { $byPath[$o.path] = $o }
$ownedKeys = [string[]]@($byPath.Keys)
[System.Array]::Sort($ownedKeys, [System.StringComparer]::Ordinal)
$ownedSorted = @($ownedKeys | ForEach-Object { $byPath[$_] })
$classCount = @{}
foreach ($c in $script:OwnedClasses) { $classCount[$c] = @($ownedSorted | Where-Object { $_.class -eq $c }).Count }

foreach ($o in $ownedSorted) {
    if ($o.refused) { continue }
    $why = Get-PathRefusal -Rel $o.path -Root $sourceRoot
    if ($why) { $faults.Add("THE PATH GUARD REFUSES IT IN THE SOURCE  $($o.path)  -- $why"); continue }
    $sp = Join-Path $sourceRoot ($o.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $sp -PathType Leaf)) { $faults.Add("ABSENT FROM THE SOURCE  $($o.path)"); continue }
    $sb = [System.IO.File]::ReadAllBytes($sp)
    $len = $sb.Length
    $have = Get-Sha256Hex -Bytes $sb
    if ($have -ne $o.sha256 -or $len -ne $o.bytes) { $faults.Add("NOT THE MANIFEST'S BYTES  $($o.path)  manifest=$($o.sha256)/$($o.bytes) source=$have/$len"); continue }
    $o.judged = (Get-JudgedForm -Bytes $sb).sha256
}
if ($faults.Count -gt 0) { foreach ($f in $faults) { Say "  SOURCE FAULT  $f" }; Stop-Install 1 "the source tree does not carry the manifest's bytes ($($faults.Count) file(s)); nothing was written." }

$versionPath = Join-Path $sourceRoot 'VERSION'
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { Stop-Install 1 'no VERSION in the source tree.' }
$version = ($script:Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($versionPath))).Trim()
$versionParts = ConvertTo-Version $version
if ($null -eq $versionParts) { Stop-Install 1 "VERSION is not a version (major.minor.patch, no pre-release tag): '$version'" }

function Read-ReleaseFile {
    # RELEASE, held to this tree: its version must be VERSION's, its manifest_sha256 the manifest's, and its
    # framework_repo_tip 40 hex. Returns the tip and the file's bytes; a fault stops the install (exit 1).
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $rel = @{}
    foreach ($line in ($script:Utf8NoBom.GetString($bytes)).Split([char]10)) {
        if ($line -match '^([a-z_0-9]+): (.*)$') { $rel[$Matches[1]] = $Matches[2].TrimEnd([char]13) }
    }
    if (-not $rel.ContainsKey('version') -or $rel['version'] -ne $version) { Stop-Install 1 "RELEASE names version '$($rel['version'])' and VERSION says '$version'." }
    if (-not $rel.ContainsKey('framework_repo_tip') -or $rel['framework_repo_tip'] -notmatch '^[0-9a-f]{40}$') { Stop-Install 1 'RELEASE carries no framework_repo_tip.' }
    if (-not $rel.ContainsKey('manifest_sha256') -or $rel['manifest_sha256'] -ne $manifestSha) {
        Stop-Install 1 "RELEASE names manifest_sha256 '$($rel['manifest_sha256'])' and this tree's manifest hashes to $manifestSha."
    }
    return [pscustomobject]@{ tip = [string]$rel['framework_repo_tip']; bytes = $bytes }
}

# THE SOURCE'S KIND (header): a clone, already held to its tag and its status above, or an expanded release.
if ($sourceKind -eq 'clone') {
    # The working VERSION is HEAD's: git status said nothing changed. Asked again, so the tag the gate named is
    # the version this run installs.
    if ($version -cne $cloneVersion) {
        Stop-Install 1 "REFUSED: the source checkout's VERSION reads '$version' and HEAD's '$cloneVersion' -- install from a clean clone at the release tag. Nothing was written."
    }
    # A clone of a public tree may track RELEASE: held as an expanded release's is, and its tip recorded.
    $tip = $sourceCommit
    if ($releaseTracked) { $tip = (Read-ReleaseFile -Path $relPath).tip }
} else {
    if (-not (Test-Path -LiteralPath $relPath -PathType Leaf)) {
        Stop-Install 1 "the source is neither a git checkout nor an expanded release (no RELEASE file): $sourceRoot"
    }
    $sourceKind = 'release'
    $relFile = Read-ReleaseFile -Path $relPath
    $relBytes = $relFile.bytes
    $tip = $relFile.tip
    if ($ReleaseZip) {
        $zipFull = Get-FullPath $ReleaseZip
        if (-not (Test-Path -LiteralPath $zipFull -PathType Leaf)) { Stop-Install 1 "-ReleaseZip: no file at $zipFull" }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFull)
        try {
            $entry = $zip.GetEntry('RELEASE')
            if ($null -eq $entry) { Stop-Install 1 "-ReleaseZip: $zipFull has no RELEASE member." }
            $ms = New-Object System.IO.MemoryStream
            $es = $entry.Open()
            try { $es.CopyTo($ms) } finally { $es.Dispose() }
            if ((Get-Sha256Hex -Bytes $ms.ToArray()) -ne (Get-Sha256Hex -Bytes $relBytes)) { Stop-Install 1 "-ReleaseZip: the archive's RELEASE is not this tree's RELEASE." }
        } finally { $zip.Dispose() }
        $zipSha = Get-FileSha256Hex -Path $zipFull
    }
}

# ------------------------------------------------------------------------------------------------
# THE MODE: framework.lock's version against VERSION.
# ------------------------------------------------------------------------------------------------
$lock = $null
if (Test-Path -LiteralPath $targetRoot -PathType Container) {
    try { $lock = Read-Lock -TargetRoot $targetRoot } catch {
        Say ("planned: written=0 already-identical=0 kept=0 retired=0 refused={0}" -f $ownedSorted.Count)
        Stop-Install 2 "REFUSED: framework.lock exists and cannot be read ($($_.Exception.Message)), so no file can be judged edited or not. Nothing was written."
    }
}
$mode = 'fresh'
if ($null -ne $lock) {
    $cmp = Compare-Version -A $lock.parts -B $versionParts
    if ($cmp -lt 0) { $mode = 'upgrade' } elseif ($cmp -eq 0) { $mode = 'installed' } else { $mode = 'downgrade' }
}

if ($sourceKind -eq 'clone') {
    $tipNote = ''
    if ($tip -ne $sourceCommit) { $tipNote = "; its RELEASE names framework_repo_tip $tip" }
    Say "source $sourceRoot (clone at tag $sourceTag, commit $sourceCommit$tipNote, version $version)"
} else { Say "source $sourceRoot ($sourceKind at $tip, version $version)" }
$marked = @(@('install.ps1', 'mission.ps1') | Where-Object { Test-MarkOfTheWeb -Path (Join-Path $sourceRoot $_) })
if ($marked.Count -gt 0) {
    Say ("NOTE: this tree carries the Mark of the Web -- a Zone.Identifier stream on {0}. Every file written below is written fresh and carries none. Run mission.ps1 from this tree with -ExecutionPolicy Bypass, or Unblock-File the ZIP before expanding it (INSTALL.md)." -f ($marked -join ' and '))
}
Say "target $targetRoot$(if ($WhatIf) { ' -- WhatIf: nothing will be written' })"
Say ("manifest sha256 {0}; installer-owned {1} (MOVE {2}, TEMPLATE {3}, HOST-CONFIG {4}); framework.lock {5}" -f $manifestSha, $ownedSorted.Count, $classCount['MOVE'], $classCount['TEMPLATE'], $classCount['HOST-CONFIG'], $(if ($null -eq $lock) { 'absent' } else { "present (lock_format $($lock.format), version $($lock.version), $($lock.files.Count) file(s))" }))

switch ($mode) {
    'fresh'   { Say 'fresh install: no framework.lock in the target' }
    'upgrade' { Say "upgrade: framework.lock says $($lock.version), and this release is $version" }
    'installed' {
        Say "already installed: framework.lock says $version, this release's version; the target is verified against it, and nothing is written"
        if ((Get-Field $lock.header 'manifest_sha256') -ne $manifestSha) {
            Say "NOTE: framework.lock names manifest_sha256 $(Get-Field $lock.header 'manifest_sha256') and this source's manifest hashes to $manifestSha; one version is one release, so nothing in this source is compared."
        }
        $diff = Invoke-Verify -Lock $lock -TargetRoot $targetRoot
        if ($diff -gt 0) { Stop-Install 3 "already installed at $version, and $diff file(s) differ from framework.lock (above). Nothing was written; framework.lock is untouched." }
        Say "already installed: $version in $targetRoot; nothing was written, and framework.lock is untouched."
        exit 0
    }
    'downgrade' {
        Say ("planned: written=0 already-identical=0 kept=0 retired=0 refused={0}" -f $ownedSorted.Count)
        Stop-Install 2 "REFUSED: downgrade -- framework.lock says $($lock.version), newer than this release, $version; a release never replaces a newer one. Nothing was judged and nothing was written."
    }
}

# ------------------------------------------------------------------------------------------------
# THE PLAN, for every file, before anything is written.
# ------------------------------------------------------------------------------------------------
$plan = New-Object System.Collections.Generic.List[object]
$trackedState = $null
foreach ($o in $ownedSorted) {
    $d = [pscustomobject]@{ path = $o.path; class = $o.class; kind = $o.kind; source_sha256 = $o.sha256; judged = $o.judged; target_sha256 = ''; eol = ''; disposition = ''; why = ''; staged = '' }
    $plan.Add($d)
    $why = $o.refused
    if (-not $why) { $why = Get-PathRefusal -Rel $o.path -Root $targetRoot }
    if ($why) { $d.disposition = 'REFUSED'; $d.why = "path guard: $why"; continue }
    $tp = Join-Path $targetRoot ($o.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $tp)) {
        $d.disposition = 'install'
        if ($o.class -eq 'TEMPLATE' -and $o.path -ceq $script:RootAttributes) {
            if ($mode -eq 'upgrade') { $d.why = "an upgrade adds no root .gitattributes where the project has none, since $($script:LinePolicy)" }
            else {
                if ($null -eq $trackedState) { $trackedState = Get-TrackedState -Root $targetRoot }
                if ($trackedState.state -eq 'tracked') { $d.why = "the target holds files its git repository tracks, and $($script:LinePolicy)" }
                elseif ($trackedState.state -eq 'unknown') { $d.why = "git could not say whether the target holds files its repository tracks (git exited $($trackedState.code)), and $($script:LinePolicy)" }
            }
            if ($d.why) { $d.disposition = 'not-written'; $d.why = 'not written: ' + $d.why }
        }
        continue
    }
    if (-not (Test-Path -LiteralPath $tp -PathType Leaf)) { $d.disposition = 'REFUSED'; $d.why = 'a directory stands where the file goes'; continue }
    $tb = [System.IO.File]::ReadAllBytes($tp)
    $j = Get-JudgedForm -Bytes $tb
    $d.target_sha256 = $j.sha256; $d.eol = $j.eol
    if ($mode -eq 'upgrade' -and $o.class -ne 'MOVE') {
        $d.disposition = 'keep'
    } elseif ($d.target_sha256 -eq $o.judged) {
        $d.disposition = 'already-identical'
    } elseif ($mode -eq 'fresh') {
        if ($o.class -eq 'TEMPLATE') { $d.disposition = 'keep' }
        else { $d.disposition = 'REFUSED'; $d.why = 'not-installed-by-framework: present and different, and there is no framework.lock' }
    } else {
        $d.disposition = 'REFUSED'
        $entry = $null
        if ($lock.files.ContainsKey($o.path)) { $entry = $lock.files[$o.path] }
        # A CLASS THAT BECAME MOVE. A template or host-config row an upgrade recorded as kept, whose sha256 was then
        # that release's own (its upstream_sha256), is a file the framework put there and the host had left as
        # shipped: under this release's class it is held as an installed row is -- upgraded if unedited since,
        # refused as edited if not. A kept row whose sha256 was not its upstream's is the host's own instance.
        $keptAsShipped = ($null -ne $entry) -and ($entry.disposition -ceq 'kept') -and $entry.upstream -and ($entry.sha256 -ceq $entry.upstream)
        if ($null -eq $entry) {
            $d.why = 'not-installed-by-framework: present and different, and framework.lock does not list it'
        } elseif (($entry.disposition -cnotmatch '^(installed|already-identical|upgraded-from .+)$') -and -not $keptAsShipped) {
            $d.why = "host-instance: framework.lock records it as the host's own ($($entry.disposition)), and this release carries other bytes"
        } else {
            $held = Get-HeldSha256 -Lock $lock -Judged $j -Bytes $tb -Recorded $entry.sha256
            if ($held -eq $entry.sha256) { $d.disposition = 'upgrade' }
            else { $d.why = "edited-since-install: framework.lock recorded $($entry.sha256), the file now hashes to $held, and this release carries $($o.judged); the upgrade would overwrite a local edit" }
        }
    }
}
$retired = @()
if ($mode -eq 'upgrade') {
    $inRelease = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($o in $ownedSorted) { $null = $inRelease.Add($o.path) }
    $gone = [string[]]@($lock.files.Keys | Where-Object { -not $inRelease.Contains($_) })
    [System.Array]::Sort($gone, [System.StringComparer]::Ordinal)
    $retired = @($gone)
}

foreach ($d in $plan) {
    if ($d.why) { Say ("  {0,-18} {1}  -- {2}" -f $d.disposition, $d.path, $d.why) }
    else { Say ("  {0,-18} {1}" -f $d.disposition, $d.path) }
}
foreach ($p in $retired) { Say ("  {0,-18} {1}  -- in framework.lock, not in this release: left in place, dropped from the lock" -f 'retire', $p) }
# THE IGNORED-MEMBER WARNING (RELEASE-4 S2 F-H8; row 505 (d)). A member this run installs, upgrades or finds in place
# that the target's own git ignore rules would hide (a dist/ rule hiding ui/dist, say) is written all the same, and git
# then never sees it: one line per such member, naming the rule and where it stands, as git check-ignore -v reads it
# in the target (a tracked file is never reported by git, and a negated rule's match is no hiding). Nothing is printed
# for a target that is no git work tree, or whose rules hide nothing of the framework's.
$giMembers = @($plan | Where-Object { @('install', 'upgrade', 'already-identical') -contains $_.disposition } | ForEach-Object { $_.path })
if ($giMembers.Count -and [System.IO.Directory]::Exists($targetRoot)) {
    $giTree = Invoke-GitIsolated -Root $targetRoot -GitArgs @('rev-parse', '--is-inside-work-tree')
    if ($giTree.ok -and $giTree.out -eq 'true') {
        for ($gb = 0; $gb -lt $giMembers.Count; $gb += 100) {
            $giBatch = @($giMembers[$gb..([Math]::Min($gb + 99, $giMembers.Count - 1))])
            $giHits = Invoke-GitIsolated -Root $targetRoot -GitArgs (@('check-ignore', '-v', '--') + $giBatch)
            foreach ($gl in @($giHits.out -split "`n" | Where-Object { $_ })) {
                if ($gl -notmatch '^(.*):(\d+):(.*)\t(.+)$') { continue }
                if ($Matches[3].StartsWith('!')) { continue }
                Say ("WARNING ignored {0} -- the target's git ignore rules hide it: {1}:{2}: {3} (git check-ignore -v); it is installed, and git will not see it while that rule matches it" -f $Matches[4], $Matches[1], $Matches[2], $Matches[3])
            }
        }
    }
}
# THE KEPT-FILE NOTICE (RELEASE-4 S2 F-H5; INSTALL.md section 6). A kept file is the project's own: the installer never
# edits it (ruling: a protected customer file is the operator's -- a notice, not a merge). For every kept file whose
# bytes differ, on the lock's basis (fold-crlf-text), from this release's version, one line says so and where this
# release's version stands; for .claude/settings.json it also names each registration this release's version carries
# that the project's lacks, with the block to add, read from this release's file.
foreach ($d in @($plan | Where-Object { $_.disposition -eq 'keep' -and $_.target_sha256 -and $_.target_sha256 -ne $_.judged })) {
    $relFile = Join-Path $sourceRoot ($d.path -replace '/', '\')
    Say ("NOTICE kept {0} -- kept: the project's own copy is not changed, and it differs from this release's version (fold-crlf-text basis), which is at {1}" -f $d.path, $relFile)
    if ($d.path -ceq '.claude/settings.json') {
        $gapText = [System.IO.File]::ReadAllText($relFile)
        $gap = Get-SettingsRegistrationGap -ReleaseText $gapText -ProjectText ([System.IO.File]::ReadAllText((Join-Path $targetRoot '.claude\settings.json')))
        if (-not $gap.ok) { Say ("NOTICE kept .claude/settings.json -- {0}; compare it with {1} by hand" -f $gap.why, $relFile) }
        foreach ($g in @($gap.events)) {
            $how = if ($g.present) { "the project registers $($g.event) without it: add the entries of this block to the project's own `"$($g.event)`" array" } else { "the project registers no $($g.event): add this block to the project's `"hooks`" object" }
            Say ("NOTICE kept .claude/settings.json -- this release registers {0} ({1}); {2}:" -f $g.event, ($g.commands -join '; '), $how)
            foreach ($bl in ($g.block -replace "`r`n", "`n").Split([char]10)) { Say ("NOTICE   | {0}" -f $bl) }
        }
    }
}
$refusedCount = @($plan | Where-Object { $_.disposition -eq 'REFUSED' }).Count
$notWrittenCount = @($plan | Where-Object { $_.disposition -eq 'not-written' }).Count
$countText = "written={0} already-identical={1} kept={2}{5} retired={3} refused={4}" -f @($plan | Where-Object { $_.disposition -eq 'install' -or $_.disposition -eq 'upgrade' }).Count,
    @($plan | Where-Object { $_.disposition -eq 'already-identical' }).Count, @($plan | Where-Object { $_.disposition -eq 'keep' }).Count, $retired.Count, $refusedCount,
    $(if ($notWrittenCount -gt 0) { " not-written=$notWrittenCount" } else { '' })
if ($refusedCount -gt 0 -or $WhatIf) { Say "planned: $countText" }

if ($refusedCount -gt 0) {
    foreach ($d in @($plan | Where-Object { $_.disposition -eq 'REFUSED' })) { Say "REFUSED $($d.path)" }
    $whole = ''
    if ($mode -eq 'upgrade') { $whole = ", so the upgrade from $($lock.version) to $version is refused as a whole" }
    Stop-Install 2 "REFUSED: $refusedCount file(s) above$whole. Nothing was written -- no file and no lock$(if ($WhatIf) { ' (WhatIf)' })."
}
# THE PYTHON SET (header): the source pins it in tools/ui/requirements.txt, an installer-owned file.
$pinCount = 0
$reqSource = Join-Path $sourceRoot 'tools\ui\requirements.txt'
if ($byPath.ContainsKey('tools/ui/requirements.txt') -and (Test-Path -LiteralPath $reqSource -PathType Leaf)) {
    $pinCount = [regex]::Matches([System.IO.File]::ReadAllText($reqSource), '(?m)^[A-Za-z0-9][A-Za-z0-9._-]*==\S+').Count
}
if ($WhatIf) {
    $pyPlan = $null
    if ($SkipPythonSet) { Say 'planned python set: skipped (-SkipPythonSet); tools\.venv is left as it stands' }
    elseif ($pinCount -eq 0) { Say 'planned python set: none (this release pins no Python set)' }
    else {
        $pyPlan = Get-PythonSetPlan -TargetRoot $targetRoot
        if ($pyPlan.action -eq 'fail') { Say "planned python set: NOT INSTALLED -- $($pyPlan.why); the files and framework.lock would be written and the run would exit 4" }
        else { Say "planned python set: $($pyPlan.why); then pip install --require-hashes --only-binary :all: -r tools\ui\requirements.txt ($pinCount pinned package(s), from PyPI)" }
    }
    $vc = @($plan | Where-Object { $_.path -ceq 'tools/ui/vanguard.cmd' })
    if ($vc.Count) { Say "planned vanguard command: tools\ui\vanguard.cmd ($($vc[0].disposition)) -- $targetRoot\tools\ui\vanguard.cmd ui starts the dashboard" }
    foreach ($l in (Get-RegistrationPlan -TargetRoot $targetRoot)) { Say $l }
    Say 'WhatIf: nothing was written.'
    if ($null -ne $pyPlan -and $pyPlan.action -eq 'fail') { exit 4 }
    exit 0
}

# ------------------------------------------------------------------------------------------------
# THE WRITE, staged (header): every file to install or upgrade, then the lock, written whole into a staging
# folder and re-hashed there; then each moved into place, the lock last; the staging folder removed.
# ------------------------------------------------------------------------------------------------
$now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
$installedAt = $now; $previous = $null; $upgradedAt = $null
if ($mode -eq 'upgrade') {
    $previous = [string]$lock.version
    $upgradedAt = $now
    $carried = ConvertTo-Stamp (Get-Field $lock.header 'installed_at')
    if ($carried) { $installedAt = $carried }
}
if (-not (Test-Path -LiteralPath $targetRoot)) { $null = [System.IO.Directory]::CreateDirectory($targetRoot) }
$toWrite = @($plan | Where-Object { $_.disposition -eq 'install' -or $_.disposition -eq 'upgrade' })
$stage = Join-Path $targetRoot ('.framework-staging-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$lockPath = Join-Path $targetRoot $script:LockName
$stagedLock = Join-Path $stage $script:LockName
$lockLines = New-Object System.Collections.Generic.List[string]
try {
    $null = [System.IO.Directory]::CreateDirectory($stage)
    $n = 0
    foreach ($d in $toWrite) {
        $n++
        $d.staged = Join-Path $stage ('{0:d5}' -f $n)
        [System.IO.File]::WriteAllBytes($d.staged, [System.IO.File]::ReadAllBytes((Join-Path $sourceRoot ($d.path -replace '/', '\'))))
        $lb = [System.IO.File]::ReadAllBytes($d.staged)
        if ((Get-Sha256Hex -Bytes $lb) -ne $d.source_sha256) { throw "the staged copy of $($d.path) is not the source's bytes" }
        $j = Get-JudgedForm -Bytes $lb
        $d.target_sha256 = $j.sha256; $d.eol = $j.eol
    }
    $lockLines.Add('{"lock":' + (ConvertTo-JsonText $script:LockId) + ',"lock_format":2,"eol_rule":' + (ConvertTo-JsonText $script:EolRule) + ',"version":' + (ConvertTo-JsonText $version) +
        ',"previous_version":' + (ConvertTo-JsonText $previous) + ',"framework_repo_tip":' + (ConvertTo-JsonText $tip) + ',"source_kind":' + (ConvertTo-JsonText $sourceKind) +
        ',"source_tag":' + (ConvertTo-JsonText $sourceTag) + ',"source_commit":' + (ConvertTo-JsonText $sourceCommit) +
        ',"manifest_sha256":' + (ConvertTo-JsonText $manifestSha) + ',"zip_sha256":' + (ConvertTo-JsonText $zipSha) +
        ',"installer_owned":' + $plan.Count + ',"installed_at":' + (ConvertTo-JsonText $installedAt) + ',"upgraded_at":' + (ConvertTo-JsonText $upgradedAt) + '}')
    foreach ($d in $plan) {
        $steady = switch ($d.disposition) { 'install' { 'installed' } 'upgrade' { "upgraded-from $previous" } 'keep' { 'kept' } 'already-identical' { 'already-identical' } 'not-written' { 'not-written' }
            default { throw "the plan's disposition '$($d.disposition)' for $($d.path) has no lock row" } }
        $rowSha = $d.target_sha256; $rowEol = $d.eol
        if ($d.disposition -eq 'not-written') { $rowSha = $null; $rowEol = $null }
        $line = '{"path":' + (ConvertTo-JsonText $d.path) + ',"sha256":' + (ConvertTo-JsonText $rowSha) + ',"disposition":' + (ConvertTo-JsonText $steady) + ',"eol":' + (ConvertTo-JsonText $rowEol) + ',"kind":' + (ConvertTo-JsonText $d.kind)
        if ($d.kind -ne 'move') { $line += ',"upstream_sha256":' + (ConvertTo-JsonText $d.judged) }
        $lockLines.Add($line + '}')
    }
    [System.IO.File]::WriteAllText($stagedLock, (($lockLines -join "`n") + "`n"), $script:Utf8NoBom)
} catch {
    $why = $_.Exception.Message
    try { if ([System.IO.Directory]::Exists($stage)) { [System.IO.Directory]::Delete($stage, $true) } } catch { }
    Stop-Install 1 "WRITE FAILED while staging: $why. No file in the target was changed, and framework.lock was not written."
}
$moved = 0
foreach ($d in $toWrite) {
    $tp = Join-Path $targetRoot ($d.path -replace '/', '\')
    try {
        $null = [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($tp))
        # An upgraded file's old copy is deleted, never written through: a hard link to it elsewhere (no reparse
        # point, so the guard cannot see one) keeps its own bytes.
        if ($d.disposition -eq 'upgrade') { [System.IO.File]::Delete($tp) }
        [System.IO.File]::Move($d.staged, $tp)
    } catch {
        $why = $_.Exception.Message
        try { [System.IO.Directory]::Delete($stage, $true) } catch { }
        Stop-Install 1 "MOVE FAILED at $($d.path): $why. $moved file(s) were moved into place before it, each whole, and framework.lock was not rewritten. Run the same release again once the cause is gone: a file already in place is judged already-identical."
    }
    $moved++
}
# The lock by File.Replace, never by delete-then-move: on every failure ReplaceFile reports, the old lock is
# still in place or is put back. It goes to a backup name in the staging folder, where a failure can leave it.
$backup = Join-Path $stage ($script:LockName + '.previous')
try {
    if ([System.IO.File]::Exists($lockPath)) { [System.IO.File]::Replace($stagedLock, $lockPath, $backup) }
    else { [System.IO.File]::Move($stagedLock, $lockPath) }
} catch {
    $why = $_.Exception.Message
    try { if (-not [System.IO.File]::Exists($lockPath) -and [System.IO.File]::Exists($backup)) { [System.IO.File]::Move($backup, $lockPath) } } catch { }
    if ([System.IO.File]::Exists($backup) -and -not [System.IO.File]::Exists($lockPath)) {
        Stop-Install 1 "framework.lock could not be put in place, and the old lock could not be put back: $why. Every file to write ($moved) is in place; the old lock is $backup -- move it back to $lockPath, then run the same release again."
    }
    try { [System.IO.Directory]::Delete($stage, $true) } catch { }
    Stop-Install 1 "framework.lock could not be put in place: $why. Every file to write ($moved) is in place, and the target's lock is as it was before this run. Run the same release again once the cause is gone: each file is judged already-identical, and the lock is written."
}
try { [System.IO.Directory]::Delete($stage, $true) } catch { Say "NOTE: the staging folder $stage could not be removed: $($_.Exception.Message)" }
# UI-1 S1 (ADR-045): THE HOST REGISTRATION, OUTSIDE THE TARGET, after the lock is in place. <home>/host-id is
# minted once (a UUID; home = $env:VANGUARD_HOME, else ~/.vanguard) and, when the target already carries a
# mission, one row is appended to <home>/projects.yaml unless the target has one -- the same act mission init
# performs (tools\lam\mission-telemetry.ps1, Register-MissionCheckout), written out here because this script
# never runs a file from the source tree. Nothing is written into the target, and nothing in the install
# depends on it: a registration that cannot complete is said, and the install still stands.
try {
    $vgHome = if ($env:VANGUARD_HOME) { $env:VANGUARD_HOME } else { Join-Path $env:USERPROFILE '.vanguard' }
    if (-not [System.IO.Directory]::Exists($vgHome)) { $null = [System.IO.Directory]::CreateDirectory($vgHome) }
    $vgUtf8 = New-Object System.Text.UTF8Encoding($false)
    $vgIdPath = Join-Path $vgHome 'host-id'
    if (-not [System.IO.File]::Exists($vgIdPath)) {
        try {
            $vgFs = [System.IO.File]::Open($vgIdPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $vgB = $vgUtf8.GetBytes([guid]::NewGuid().ToString('D').ToLowerInvariant() + "`n"); $vgFs.Write($vgB, 0, $vgB.Length) } finally { $vgFs.Dispose() }
        } catch [System.IO.IOException] { if (-not [System.IO.File]::Exists($vgIdPath)) { throw } }
    }
    $vgHostId = ([System.IO.File]::ReadAllText($vgIdPath)).Trim()
    $vgMission = $null
    $vgMf = Join-Path $targetRoot '.mission\mission.yaml'
    if ([System.IO.File]::Exists($vgMf)) {
        $vgM = [regex]::Matches([System.IO.File]::ReadAllText($vgMf), '(?m)^id:[ \t]*([^\s#]+)')
        if ($vgM.Count -eq 1 -and $vgM[0].Groups[1].Value -ne 'null') { $vgMission = $vgM[0].Groups[1].Value.Trim('"', "'") }
    }
    $vgNote = "host-id $vgHostId in $vgHome; no registry row (the target carries no mission yet: mission init adds it)"
    # A ROW ONLY WHERE THE FEED FOLDER ALREADY IS. This script may not make .mission-runtime/telemetry/ (it never
    # touches the target's runtime plane), and a registered checkout without that folder fails one append per
    # call. A mission that predates the feed is pointed at mission.ps1 register, which makes the folder, the row
    # and the ignore rule together.
    if ($vgMission -and -not [System.IO.Directory]::Exists((Join-Path $targetRoot '.mission-runtime\telemetry'))) {
        $vgNote = "host-id $vgHostId in $vgHome; the target's mission is not registered for the mission-event feed -- run mission.ps1 register -Target $targetRoot to start it"
        $vgMission = $null
    }
    if ($vgMission) {
        $vgReg = Join-Path $vgHome 'projects.yaml'
        $vgPath = [System.IO.Path]::GetFullPath($targetRoot).TrimEnd('\', '/')
        $vgKnown = $false
        if ([System.IO.File]::Exists($vgReg)) {
            foreach ($vgRow in [regex]::Matches([System.IO.File]::ReadAllText($vgReg), "(?m)^\s*(?:-\s+)?checkout_path:\s*'((?:[^']|'')*)'\s*\r?$")) {
                if ([string]::Equals((($vgRow.Groups[1].Value -replace "''", "'").TrimEnd('\', '/')), $vgPath, [System.StringComparison]::OrdinalIgnoreCase)) { $vgKnown = $true }
            }
        }
        if ($vgKnown) { $vgNote = "host-id $vgHostId; the target already has its row in $vgReg" }
        else {
            $vgText = ''
            if (-not [System.IO.File]::Exists($vgReg)) { $vgText = "# Vanguard host registry -- one row per registered checkout, appended by install.ps1 and mission init`n# (ADR-045). Read by ``vanguard ui``. Rows are never pruned: a row whose path is gone is shown as stale.`n" }
            $vgText += "- host_id: $vgHostId`n  checkout_path: '" + ($vgPath -replace "'", "''") + "'`n  mission_id: '" + ($vgMission -replace "'", "''") + "'`n" +
                       "  registered_at: '" + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture) + "'`n  framework_version: '$version'`n"
            $vgBytes = $vgUtf8.GetBytes($vgText)
            $vgFs = [System.IO.File]::Open($vgReg, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            try { $vgFs.Write($vgBytes, 0, $vgBytes.Length) } finally { $vgFs.Dispose() }
            $vgNote = "host-id $vgHostId; a row for the target added to $vgReg"
        }
    }
    Say "host registration: $vgNote"
} catch { Say "NOTE: the host registration did not complete ($($_.Exception.Message)); the install is complete and nothing in it depends on it." }
# THE PYTHON SET (header), after the lock: every file stands whatever it does.
$pySetWhy = ''
if ($SkipPythonSet) { Say 'python set: skipped (-SkipPythonSet); tools\.venv is as it stood, and vanguard ui needs the set' }
elseif ($pinCount -gt 0) {
    $pyPlan = Get-PythonSetPlan -TargetRoot $targetRoot
    if ($pyPlan.action -ne 'fail') { Say "python set: $($pyPlan.why)" }
    $pySetWhy = Install-PythonSet -Plan $pyPlan -TargetRoot $targetRoot
    if ($pySetWhy) {
        Say "PYTHON SET NOT INSTALLED: $pySetWhy. The files and framework.lock are installed; vanguard ui needs the set: make $targetRoot\tools\.venv with CPython 3.14 (win-amd64) and run $targetRoot\tools\.venv\Scripts\python.exe -m pip install --require-hashes --only-binary :all: -r $targetRoot\tools\ui\requirements.txt"
    } else { Say "python set: $pinCount pinned package(s) in tools\.venv, installed with --require-hashes" }
}
Say "done: $countText"
Say ("framework.lock written: {0} line(s) for {1} file(s), sha256 {2}" -f $lockLines.Count, $plan.Count, (Get-FileSha256Hex -Path $lockPath))
if ($mode -eq 'upgrade') { Say "upgraded $previous to $version in $targetRoot." }
else { Say "installed $version into $targetRoot." }
if ($pySetWhy) { exit 4 }
exit 0
