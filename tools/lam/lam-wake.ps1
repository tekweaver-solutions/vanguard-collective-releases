#Requires -Version 5.1
<#
.SYNOPSIS
  lam-wake -- the operator-run starter that wakes a seat in the worktree the operator prepared
  (operator ruling "wake: embed the brief").

.DESCRIPTION
  THE CLI HAS NO LIVE-INJECTION (batch-4-proposals.md item 2, measured on CLI 2.1.258): a running
  session refuses --resume, --fork-session copies from disk, and the harness's live-inject tools are
  unreachable from a headless runner. So the wake is an OPERATOR act, and this script makes the
  lawful path one command instead of a copy-paste. Run it from the main checkout:

      powershell -NoProfile -ExecutionPolicy Bypass -File tools\lam\lam-wake.ps1

  WHAT IT DOES, IN ORDER. Every assertion runs BEFORE anything is written; a refusal is exit 2 with
  a named reason and writes nothing.
    (0) THE AUTHENTICATION MODE, only when VANGUARD_AUTH_MODE is set: tools\lam\lam-auth-mode.ps1
        decides it from the credentials the environment carries, before anything else, refusing AUTH-MODE-<CODE>;
        and once the argv and the brief are known, before the one write, it holds them, the worktree's settings and
        root files the CLI loads to the mode (LAM-INSTALL.md section 7c); admitted, it prints nothing. Unset: not loaded.
    (1) THE CLI'S KIND. `claude` must resolve -- by PowerShell's own precedence, the one command a
        bare `claude` would run -- to an APPLICATION whose file is a .exe. A .cmd, .bat or .ps1
        shim, a function or an alias is refused CLAUDE-NOT-EXE. Nothing is invoked to find out.
    (2) THE ARTIFACT. The newest *.wake.json under <MissionRoot>\.mission-runtime\lam\wake, by
        ORDINAL file-name sort (never by timestamp). It must parse as one JSON object carrying the
        non-empty strings head_sha, batch, seat_name, model, effort, worktree_path (absolute) and
        brief_source; and each value that reaches the argv must be what its slot holds (THE ARGV
        DECISION, below), or it is refused ARTIFACT-FIELD-UNSAFE naming the field.
    (3) THE BRIEF. brief_source is resolved against MissionRoot and must stay inside it; its BYTES
        from offset 0 up to the first byte of the first line matching ^## 10\. are the brief. The
        bytes are never decoded, re-encoded or newline-normalised.
    (4) THE WORKTREE. worktree_path must be a drive-qualified path on a drive that is not a network
        drive (WORKTREE-NOT-LOCAL; the resolved MissionRoot likewise, MISSION-ROOT-NOT-LOCAL), must
        exist as a directory, and its CANONICAL FINAL PATH must be neither MissionRoot's
        (WORKTREE-IS-MISSION-ROOT) nor inside that of <MissionRoot>\.mission or
        <MissionRoot>\.mission-runtime (WORKTREE-IN-MISSION-PLANE) -- THE ALIAS DECISION, below. It
        must be no longer than the band measured GREEN (see Get-LamWakeBand), must be
        the top level of its git repository, and its HEAD must equal head_sha -- the operator
        prepared it at the declared base.
    (5) THE CLI'S FLAGS. `claude --help` must list -n/--name, --model and --effort, and effort must
        be one of the values that help lists for --effort (or, when it lists none, match
        ^[a-z]{1,16}$ -- the starter prints which rule applied). The argv is exactly
            -n <seat_name> --model <model> --effort <effort> "You are the <seat_name> seat; read ./.wake-brief.md and begin."
        -- no -w (the operator cut the worktree), no -p (the seat is interactive), nothing else.
    (6) THE LAUNCH. Whatever already stands at <worktree_path>\.wake-brief.md is examined first, without
        following reparse points: a reparse point, or a file carrying more than one hard link, is refused
        BRIEF-TARGET-UNSAFE, because writing it would write somewhere else as well (THE TARGET DECISION,
        below). Then the brief's bytes are written there. Then the shell is pushed into <worktree_path>
        with -ErrorAction Stop, and the directory it actually reached is compared with the worktree by
        canonical final path; a push that fails, or a location that is not the worktree, is refused
        LAUNCH-LOCATION-FAILED and NOTHING IS LAUNCHED (THE LAUNCH LOCATION DECISION, below). Only then
        & <the resolved claude.exe> @argv; Pop-Location; and the script exits with claude's exit code.

  THE ARGV DECISION (a review finding). The design note documents the launch as
      Set-Location <worktree>; & claude -n <name> --model <m> --effort <e> "<prompt>"
  (batch-4-proposals.md item 2, ruled "as proposed"), and that argv is what an APPLICATION receives.
  The reviewer measured what a shim does to it: with a claude.cmd first on PATH and the seat_name
  x&echo.INJECTED>rv-pwn.txt&rem, cmd.exe re-parsed the command line, the stub received only
  "-n x" instead of seven tokens, and cmd.exe created rv-pwn.txt -- and the wake artifact is written
  on an agent-writable plane. A shim that re-parses the argv delivers something other than the
  documented argv, so the starter launches ONLY a resolved .exe (step 1). And because each argv slot
  is documented as a value of one kind, each field that reaches the argv is restricted to what that
  slot can hold, refused otherwise:
      seat_name  ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$
      model      ^[A-Za-z0-9][A-Za-z0-9._:\[\]-]{0,99}$
      effort     one of the values the installed CLI's --help lists for --effort; when it lists
                 none, ^[a-z]{1,16}$ (CLI 2.1.258 lists: low, medium, high, xhigh, max)
      head_sha   ^[0-9a-f]{40}$
  (matched case-sensitively, with $ taken as the end of the string -- \z -- because PowerShell's
  own $ also matches before a final newline). The prompt is composed only from the validated
  seat_name. Neither half is a repair: a value outside its slot is refused, never escaped.

  THE ALIAS DECISION (a re-review defect). The design note launches claude "in the
  operator-prepared worktree", the length band is the one an earlier revision measured over
  drive-qualified local worktree roots, and the refusals above say the worktree is not the mission
  root and not inside .mission or .mission-runtime. A comparison of path STRINGS did not hold that:
  measured, a worktree_path of \\localhost\C$\<root>\.mission-runtime\seat-wt or
  \\localhost\C$\<root>\.mission\seat-wt (and the same through \\127.0.0.1), a repository at head_sha,
  and \\localhost\C$\<root> for a mission root that is itself a repository at head_sha, each exited 0,
  wrote .wake-brief.md there and launched claude there -- GetFullPath leaves a UNC path as it is, and
  git answers --show-toplevel in the same form. So:
    - worktree_path and the resolved mission root must be drive-qualified (^[A-Za-z]:\\) on a drive
      whose System.IO.DriveInfo.DriveType is not Network; a UNC, \\?\ or \\.\ form or a
      network-mapped drive letter (measured: a letter mapped to \\localhost\C$ reports Network) is
      refused by name before anything is written; and
    - the mission-root and plane comparisons use CANONICAL FINAL PATHS for the worktree, the mission
      root and both plane directories: each existing directory is opened with CreateFile
      (FILE_FLAG_BACKUP_SEMANTICS, share read|write|delete) and named by GetFinalPathNameByHandle
      (VOLUME_NAME_DOS); the \\?\ prefix is removed, case is folded, and the paths are compared with a
      trailing separator. A plane where NOTHING STANDS cannot contain the worktree and is not
      canonicalised -- and whether anything stands there is decided by an open of its own, not by
      [System.IO.Directory]::Exists (THE PLANE-ABSENCE DECISION, below). Any failure to canonicalise
      -- an open or a naming that fails, or a final path that is not drive-qualified -- is refused
      PATH-NOT-CANONICAL (fail closed).
  WHAT THE CANONICAL COMPARISON COVERS, MEASURED (2026-09-15): a SUBST drive letter aliasing the
  mission root (its final path is the directory's own); a junction (its final path is its target); an
  8.3 short name (GetFullPath already expands it, and its final path is the long one). WHAT IT DOES
  NOT: it examines directories, and the write opens a FILE -- so the target of the write is examined
  separately, on its own terms (THE TARGET DECISION, below). Not measured, and not claimed: a volume
  mounted at a folder path (mounting one needs administrative rights, which the measuring session did
  not hold) and symbolic links (creating one was refused "Administrator privilege required").

  THE PLANE-ABSENCE DECISION (a final review defect). The plane loop used to skip a
  plane whenever [System.IO.Directory]::Exists said false, and Exists says false for more than absence.
  MEASURED 2026-09-15: with ListDirectory denied to the running user on the mission root and
  ReadAttributes denied on <MissionRoot>\.mission-runtime, and the worktree a real repository at
  head_sha INSIDE that plane, Exists answered false, the plane was therefore never compared, and the
  starter exited 0, wrote .wake-brief.md inside the plane and launched -- against the documented refusal
  WORKTREE-IN-MISSION-PLANE and against this header's own claim that a failure to canonicalise fails
  closed. So a plane counts as absent ONLY when opening its name -- FILE_READ_ATTRIBUTES, share
  read|write|delete, FILE_FLAG_BACKUP_SEMANTICS and FILE_FLAG_OPEN_REPARSE_POINT -- fails with
  ERROR_FILE_NOT_FOUND (2) or ERROR_PATH_NOT_FOUND (3). Any other failure, ERROR_ACCESS_DENIED (5)
  included, is refused PATH-NOT-CANONICAL. Not following reparse points keeps the other direction
  honest: a plane that is a junction to nothing STANDS at its name, so it is canonicalised -- and
  refused when that fails -- instead of being read as an absent plane.

  THE TARGET DECISION (final review, the hard-link finding). MEASURED 2026-09-15: a
  .wake-brief.md planted in an ADMITTED worktree as a HARD LINK to a file inside
  <MissionRoot>\.mission-runtime was written THROUGH, and the plane file's bytes changed -- so "the only
  write is .wake-brief.md inside the worktree" did not hold, because the canonical comparison examines
  directories while the write opens a file. So before the write, whatever stands at the target is opened
  without following reparse points and named by GetFileInformationByHandle: a reparse point
  (FILE_ATTRIBUTE_REPARSE_POINT) or more than one hard link (nNumberOfLinks > 1) is refused
  BRIEF-TARGET-UNSAFE, and so is any other failure to examine it. Nothing standing there is the ordinary
  case and the write creates the file; a DIRECTORY standing there is left to the write, which fails
  BRIEF-WRITE-FAILED as before.

  THE LAUNCH LOCATION DECISION (a final review defect). The design note launches
  claude IN the operator-prepared worktree. The launch used to push there with a bare Push-Location under
  ErrorActionPreference Continue, so a push that failed printed an error and the script carried straight
  on. MEASURED 2026-09-15, in library mode, with the worktree renamed away after the brief was written:
  the push failed and the stub was launched anyway, with its current directory the CALLER's -- the
  mission root; the same shape was measured against a worktree the push could not enter for want of
  access. So the push is -ErrorAction Stop inside a try, and the directory it actually reached is then
  compared with the worktree by canonical final path; a push that fails, a location that cannot be
  canonicalised, or a location that is not the worktree is refused LAUNCH-LOCATION-FAILED and NOTHING IS
  LAUNCHED. The brief has been written by then, and the refusal says so.

  THE RESIDUAL THIS DOES NOT CLOSE: A DIRECTORY SWAPPED BETWEEN THE CHECK AND THE WRITE. The plane
  comparison and the write are separate opens, so a worktree that passes Assert-LamWakeWorktree and is
  then replaced is written wherever its name then leads. MEASURED 2026-09-15 in library mode: with the
  admitted worktree renamed away after Assert-LamWakeWorktree returned and a junction into
  <MissionRoot>\.mission-runtime put at its name, the write landed in the plane. It is RECORDED, NOT
  FIXED, and it is recorded under the note's own residual: the wake's safety rests on a human being the
  only one at the keyboard, and anything that can swap a directory under the starter mid-run already has
  the machine. Closing it would mean holding one handle from the check to the write and writing through
  that handle, which is a larger change than this starter's job.

  WHAT IT WRITES, AND WHAT IT NEVER DOES. Its only write INTO THE MISSION ROOT OR THE WORKTREE is
  <worktree_path>\.wake-brief.md. That file lies under MissionRoot whenever the worktree does -- the
  CLI-owned <MissionRoot>\.claude\worktrees\<id> placement is a legitimate seat placement and is
  admitted -- but a worktree inside <MissionRoot>\.mission or <MissionRoot>\.mission-runtime, the planes
  the starter must not write, is refused (step 4); the runtime plane is read, never written. Elsewhere
  it writes one thing more, and it is not its own: Add-Type compiles the interop type on first use
  through the CLR's CodeDom, which puts temporary compiler files under %TEMP% and removes them again.
  It never creates, removes or merges a worktree, never pushes, and starts no session other than the one
  in step 6.

  LIBRARY MODE. Dot-sourced (`. tools\lam\lam-wake.ps1`) it defines its functions and runs nothing,
  so an instrument can assert the argv composition and the brief slicing directly. Detection is
  $MyInvocation.InvocationName -eq '.'. Refusals inside the functions are thrown as a message of the
  form LAMWAKE-REFUSED|<CODE>|<text>.

  .wake-brief.md IS A SNAPSHOT. It is the brief as it stood at launch, it is not tracked, and it is
  the operator's to ignore and clean; a later edition of STATUS.md does not reach a seat already
  running.
#>
[CmdletBinding()]
param(
    [string]$MissionRoot = '.'
)

# =================================================================================================
# THE LENGTH BAND ("THE MEASURED BAND")
# =================================================================================================
# The largest worktree root measured GREEN is 136 (WP-2 arm G, candidate 2 cured, where
# the uncured arm F was red at the same root). Its cured ceiling (141) and its fidelity bound (138)
# are COMPUTED, NOT RUN. Git's own linked-worktree ceiling is a 216-character path ("'$GIT_DIR' too
# big"), which no core.longpaths setting moves. The starter refuses above the MEASURED figure, not
# above a computed one.
function Get-LamWakeBand {
    return [pscustomobject]@{ MaxGreen = 136; FidelityBound = 138; CuredCeiling = 141; GitCeiling = 216 }
}

function New-LamWakeRefusal {
    param([string]$Code, [string]$Text)
    return ('LAMWAKE-REFUSED|' + $Code + '|' + $Text)
}

function Write-LamWakeLine {
    param([string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-LamWakeRefusalLines {
    # One refusal, printed the one way: the code in brackets, then the closing line that says what the
    # refusal leaves behind. A message that is not a LAMWAKE-REFUSED is INTERNAL-ERROR.
    param([string]$Message, [string]$Closing)
    if ($Message.StartsWith('LAMWAKE-REFUSED|')) {
        $parts = $Message.Split([char[]]@([char]'|'), 3)
        Write-LamWakeLine ('lam-wake: REFUSED [' + $parts[1] + '] ' + $parts[2])
    } else {
        Write-LamWakeLine ('lam-wake: REFUSED [INTERNAL-ERROR] ' + $Message)
    }
    Write-LamWakeLine $Closing
}

function Get-LamWakeSha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function ConvertTo-LamWakeFullPath {
    # Only ever called on a path already known to be absolute: .NET resolves a relative path against
    # the PROCESS directory, which Set-Location does not move.
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath(($Path -replace '/', '\'))
    if ($full.Length -gt 3) { $full = $full.TrimEnd('\') }
    return $full
}

function Test-LamWakeAbsolutePath {
    # A drive-qualified path (C:\x or C:/x) or a UNC path. "C:x" and "\x" are rooted but not
    # absolute, and are refused. A UNC path passes THIS test and is refused afterwards by name
    # (Get-LamWakeNotLocalReason; THE ALIAS DECISION, in the header).
    param([string]$Path)
    $p = ($Path -replace '/', '\')
    return (($p -match '^[A-Za-z]:\\') -or ($p -match '^\\\\[^\\]+\\[^\\]+'))
}

function Get-LamWakeNotLocalReason {
    # THE ALIAS DECISION (header). '' when the path is drive-qualified (X:\ or X:/) on a drive whose
    # System.IO.DriveInfo.DriveType is not Network; otherwise why not, as the refusal prints it.
    param([string]$Path)
    $p = ($Path -replace '/', '\')
    if ($p -notmatch '^[A-Za-z]:\\') { return 'is not a drive-qualified path (a UNC, \\?\ or \\.\ form is refused)' }
    $letter = $p.Substring(0, 1)
    $type = ''
    try { $type = [string](New-Object System.IO.DriveInfo -ArgumentList $letter).DriveType }
    catch { return ('is on drive ' + $letter + ':, whose type could not be read') }
    if ($type -eq 'Network') { return ('is on ' + $letter + ':, a network drive') }
    return ''
}

function Initialize-LamWakeNative {
    # The ONE interop type the starter uses, compiled on first use and never again. Compiling is itself a
    # write, though not one of the starter's targets: Add-Type goes through the CLR's CodeDom, which puts
    # temporary compiler files under %TEMP% and removes them again (WHAT IT WRITES, in the header).
    if ('LamWakeNative' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
public static class LamWakeNative {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandleW(SafeFileHandle hFile, StringBuilder lpszFilePath, uint cchFilePath, uint dwFlags);
    [StructLayout(LayoutKind.Sequential)]
    private struct BY_HANDLE_FILE_INFORMATION {
        public uint FileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
        public uint VolumeSerialNumber;
        public uint FileSizeHigh;
        public uint FileSizeLow;
        public uint NumberOfLinks;
        public uint FileIndexHigh;
        public uint FileIndexLow;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle hFile, out BY_HANDLE_FILE_INFORMATION lpFileInformation);
    private const uint FILE_READ_ATTRIBUTES = 0x80;
    private const uint FILE_SHARE_READ_WRITE_DELETE = 0x7;
    private const uint OPEN_EXISTING = 3;
    private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
    private const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
    private const uint VOLUME_NAME_DOS = 0x0;
    // The canonical final path of whatever this name resolves to, reparse points FOLLOWED.
    public static string GetFinalPath(string path) {
        using (SafeFileHandle h = CreateFileW(path, FILE_READ_ATTRIBUTES, FILE_SHARE_READ_WRITE_DELETE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, IntPtr.Zero)) {
            if (h.IsInvalid) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            uint capacity = 512;
            for (int attempt = 0; attempt < 3; attempt++) {
                StringBuilder buffer = new StringBuilder((int)capacity);
                uint length = GetFinalPathNameByHandleW(h, buffer, capacity, VOLUME_NAME_DOS);
                if (length == 0) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
                if (length < capacity) { return buffer.ToString(0, (int)length); }
                capacity = length + 1;
            }
            throw new Win32Exception(122);
        }
    }
    // 0 when something stands at this name, otherwise the Win32 error the open failed with. Reparse
    // points are NOT followed, so a link whose target is gone still counts as standing there.
    public static int OpenStatus(string path) {
        using (SafeFileHandle h = CreateFileW(path, FILE_READ_ATTRIBUTES, FILE_SHARE_READ_WRITE_DELETE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, IntPtr.Zero)) {
            if (h.IsInvalid) { return Marshal.GetLastWin32Error(); }
            return 0;
        }
    }
    // { number of hard links, attributes } of what stands at this name, reparse points NOT followed.
    public static long[] GetLinkInfo(string path) {
        using (SafeFileHandle h = CreateFileW(path, FILE_READ_ATTRIBUTES, FILE_SHARE_READ_WRITE_DELETE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, IntPtr.Zero)) {
            if (h.IsInvalid) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            BY_HANDLE_FILE_INFORMATION info;
            if (!GetFileInformationByHandle(h, out info)) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            return new long[] { (long)info.NumberOfLinks, (long)info.FileAttributes };
        }
    }
}
'@
}

function Get-LamWakeWin32Code {
    # The Win32 error behind a caught exception: PowerShell wraps an interop throw, so the INNERMOST
    # exception is the one carrying NativeErrorCode. code is -1 when it is not a Win32 error at all.
    param($Record)
    $e = $Record.Exception
    while ($null -ne $e.InnerException) { $e = $e.InnerException }
    $code = -1
    if ($e -is [System.ComponentModel.Win32Exception]) { $code = [int]$e.NativeErrorCode }
    return [pscustomobject]@{ code = $code; message = $e.Message }
}

function Get-LamWakeCanonicalPath {
    # THE ALIAS DECISION (header). The canonical final path of an EXISTING directory, or the refusal
    # PATH-NOT-CANONICAL (fail closed). Returns { final; key }: final is GetFinalPathNameByHandle's
    # answer with its \\?\ prefix removed; key is final case-folded with exactly one trailing separator,
    # the form every comparison uses. $Role names the path in the refusal.
    param([string]$Path, [string]$Role)
    Initialize-LamWakeNative
    $final = ''
    $why = ''
    try {
        $nativeType = 'LamWakeNative' -as [type]
        $final = [string]$nativeType::GetFinalPath($Path)
    } catch {
        $why = (Get-LamWakeWin32Code -Record $_).message
    }
    if (-not $why) {
        if ($final.StartsWith('\\?\')) { $final = $final.Substring(4) }
        if ($final -notmatch '^[A-Za-z]:\\') { $why = 'its final path ' + $final + ' is not drive-qualified' }
    }
    if ($why) {
        throw (New-LamWakeRefusal 'PATH-NOT-CANONICAL' ('the canonical final path of ' + $Role + ' ' + $Path + ' could not be established (' + $why + '); a path that cannot be canonicalised cannot be shown to lie outside .mission and .mission-runtime, so it is refused'))
    }
    return [pscustomobject]@{ final = $final; key = ($final.TrimEnd('\').ToUpperInvariant() + '\') }
}

function Test-LamWakeNamePresent {
    # DOES ANYTHING STAND AT THIS NAME (a final review defect)? The name is opened
    # WITHOUT following reparse points, and the answer is $false ONLY when that open fails with
    # ERROR_FILE_NOT_FOUND (2) or ERROR_PATH_NOT_FOUND (3) -- nothing is there, so it can hold nothing.
    # ANY OTHER FAILURE IS REFUSED PATH-NOT-CANONICAL (fail closed).
    #   Why not [System.IO.Directory]::Exists, which the plane loop used to ask: it answers false for
    #   reasons other than absence. MEASURED 2026-09-15, with ListDirectory denied to the running user on
    #   the mission root and ReadAttributes denied on <root>\.mission-runtime: Exists answered false for a
    #   plane that was there and held the worktree, the plane was therefore never compared, and the
    #   starter exited 0, wrote .wake-brief.md INSIDE the plane and launched -- against the documented
    #   refusal WORKTREE-IN-MISSION-PLANE and against the header's fail-closed claim. Under the same
    #   fixture this open fails with ERROR_ACCESS_DENIED (5) and the plane is refused.
    #   Not following reparse points is what keeps the other direction honest: a junction whose target is
    #   gone STANDS at the name (this open succeeds), so it is canonicalised -- and refused
    #   PATH-NOT-CANONICAL when that fails -- instead of being read as an absent plane.
    param([string]$Path, [string]$Role)
    Initialize-LamWakeNative
    $status = -1
    $why = ''
    try {
        $nativeType = 'LamWakeNative' -as [type]
        $status = [int]$nativeType::OpenStatus($Path)
    } catch {
        $w = Get-LamWakeWin32Code -Record $_
        $status = $w.code
        $why = $w.message
    }
    if ($status -eq 0) { return $true }
    if ($status -eq 2 -or $status -eq 3) { return $false }
    if (-not $why) { $why = 'Win32 error ' + $status }
    throw (New-LamWakeRefusal 'PATH-NOT-CANONICAL' ('the canonical final path of ' + $Role + ' ' + $Path + ' could not be established (it could not be opened: ' + $why + '); a path that cannot be canonicalised cannot be shown to lie outside .mission and .mission-runtime, so it is refused -- only an open that fails with not-found (Win32 2 or 3) is read as nothing standing there'))
}

function Assert-LamWakeBriefTarget {
    # THE ONE WRITE'S TARGET (final review, the hard-link finding). The canonical
    # comparison examines DIRECTORIES; the write opens a FILE. MEASURED 2026-09-15: a .wake-brief.md
    # planted in an ADMITTED worktree as a HARD LINK to a file inside <root>\.mission-runtime was written
    # THROUGH, and the plane file's bytes changed -- so the claim that the only write is .wake-brief.md
    # inside the worktree did not hold. So whatever already stands at the target is opened WITHOUT
    # following reparse points and refused BRIEF-TARGET-UNSAFE when it is a reparse point or carries more
    # than one hard link. Nothing standing there (Win32 2 or 3) is the ordinary case: the write creates
    # the file. A directory standing there is left to the write, which fails BRIEF-WRITE-FAILED. Any
    # other failure to examine it is refused as well (fail closed).
    param([string]$Target)
    Initialize-LamWakeNative
    $info = $null
    $status = 0
    $why = ''
    try {
        $nativeType = 'LamWakeNative' -as [type]
        $info = $nativeType::GetLinkInfo($Target)
    } catch {
        $w = Get-LamWakeWin32Code -Record $_
        $status = $w.code
        $why = $w.message
    }
    if ($null -eq $info) {
        if ($status -eq 2 -or $status -eq 3) { return }
        throw (New-LamWakeRefusal 'BRIEF-TARGET-UNSAFE' ('what stands at ' + $Target + ' could not be examined (' + $why + '), so the starter cannot show that writing the brief writes that file and nothing else; refused'))
    }
    $links = [long]$info[0]
    $attrs = [long]$info[1]
    if (($attrs -band 0x400) -ne 0) {
        throw (New-LamWakeRefusal 'BRIEF-TARGET-UNSAFE' ($Target + ' is a reparse point; the brief is written to the file itself and never through a link, because a link can name a file on a plane the starter must not write. Remove it and run the starter again.'))
    }
    if ($links -gt 1) {
        throw (New-LamWakeRefusal 'BRIEF-TARGET-UNSAFE' ($Target + ' carries ' + $links + ' hard links, so writing it would write every other name for the same file -- measured, a .wake-brief.md planted as a hard link to a file inside .mission-runtime was written through. Remove it and run the starter again.'))
    }
}

function Resolve-LamWakeMissionRoot {
    param([string]$MissionRoot)
    if (-not $MissionRoot -or -not (Test-Path -LiteralPath $MissionRoot -PathType Container)) {
        throw (New-LamWakeRefusal 'MISSION-ROOT-ABSENT' ("-MissionRoot '" + $MissionRoot + "' is not a directory"))
    }
    $resolved = (Resolve-Path -LiteralPath $MissionRoot).ProviderPath
    $notLocal = Get-LamWakeNotLocalReason -Path $resolved
    if ($notLocal) {
        throw (New-LamWakeRefusal 'MISSION-ROOT-NOT-LOCAL' ('the mission root ' + $resolved + ' ' + $notLocal + '; run the starter against the mission root by its path on a local drive letter'))
    }
    return (ConvertTo-LamWakeFullPath -Path $resolved)
}

# =================================================================================================
# (1) THE CLI'S KIND -- a .exe application, or nothing
# =================================================================================================
function Resolve-LamWakeClaude {
    # The one command a bare `claude` would run, by PowerShell's own precedence (alias, function,
    # cmdlet, then the first match on PATH in PATHEXT order): Get-Command with neither -CommandType
    # nor -All names exactly that command. It must be an Application whose file is a .exe; anything
    # else re-parses the argv (THE ARGV DECISION, in the header) and is refused. Nothing is invoked.
    $cmd = @()
    try { $cmd = @(Get-Command -Name 'claude' -ErrorAction SilentlyContinue) } catch { $cmd = @() }
    if ($cmd.Count -eq 0) { throw (New-LamWakeRefusal 'CLAUDE-ABSENT' 'claude does not resolve to any command on PATH') }
    $found = $cmd[0]
    $isApp = ($found.CommandType -eq [System.Management.Automation.CommandTypes]::Application)
    $where = [string]$found.Name
    if ($found.Source) { $where = [string]$found.Source }
    $ext = ''
    if ($isApp) { $ext = [System.IO.Path]::GetExtension([string]$found.Source) }
    if (-not $isApp -or -not [string]::Equals($ext, '.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (New-LamWakeRefusal 'CLAUDE-NOT-EXE' ('claude resolves to the ' + [string]$found.CommandType + ' ' + $where + '; the starter launches only a .exe application, because a .cmd, .bat or .ps1 shim, a function or an alias re-parses the argv and delivers something other than the documented one. Put the directory holding claude.exe first on PATH.'))
    }
    return [string]$found.Source
}

# =================================================================================================
# (2) THE ARTIFACT
# =================================================================================================
function Get-LamWakeArtifactName {
    # The newest artifact's FILE NAME by ordinal sort, or a refusal. Only names ending .wake.json count.
    param([string]$WakeDir)
    if (-not (Test-Path -LiteralPath $WakeDir -PathType Container)) {
        throw (New-LamWakeRefusal 'WAKE-DIR-ABSENT' ('no wake directory at ' + $WakeDir))
    }
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($f in [System.IO.Directory]::GetFiles($WakeDir)) {
        $n = [System.IO.Path]::GetFileName($f)
        if ($n.EndsWith('.wake.json', [System.StringComparison]::OrdinalIgnoreCase)) { [void]$names.Add($n) }
    }
    if ($names.Count -eq 0) {
        throw (New-LamWakeRefusal 'WAKE-DIR-EMPTY' ('no *.wake.json artifact in ' + $WakeDir))
    }
    $arr = $names.ToArray()
    [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
    return $arr[$arr.Length - 1]
}

function Assert-LamWakeSlot {
    # One argv slot (THE ARGV DECISION, in the header). $Pattern is matched case-sensitively and ends
    # in \z, not $: PowerShell's $ also matches before a final newline. $Shown is the pattern as the
    # refusal prints it. The value itself is never echoed -- it came from an agent-writable plane.
    param([string]$ArtifactName, [string]$Field, [string]$Value, [string]$Pattern, [string]$Shown, [string]$Holds)
    if (-not ($Value -cmatch $Pattern)) {
        throw (New-LamWakeRefusal 'ARTIFACT-FIELD-UNSAFE' ($ArtifactName + ': ' + $Field + ' is not ' + $Holds + ' (' + $Shown + '); refused, never escaped or repaired'))
    }
}

function Get-LamWakeArtifact {
    param([string]$Root)
    $wakeDir = Join-Path $Root '.mission-runtime\lam\wake'
    $name = Get-LamWakeArtifactName -WakeDir $wakeDir
    $path = Join-Path $wakeDir $name
    $obj = $null
    $parseError = ''
    try {
        $text = [System.IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding($false)))
        $obj = $text | ConvertFrom-Json
    } catch { $parseError = $_.Exception.Message }
    if ($parseError) {
        throw (New-LamWakeRefusal 'ARTIFACT-UNPARSABLE' ($name + ' does not parse as JSON: ' + $parseError))
    }
    if ($null -eq $obj -or $obj -isnot [System.Management.Automation.PSCustomObject]) {
        throw (New-LamWakeRefusal 'ARTIFACT-UNPARSABLE' ($name + ' is not a single JSON object'))
    }
    $fields = @('head_sha', 'batch', 'seat_name', 'model', 'effort', 'worktree_path', 'brief_source')
    $values = @{}
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($field in $fields) {
        $prop = @($obj.PSObject.Properties | Where-Object { $_.Name -ceq $field })
        if ($prop.Count -ne 1 -or $prop[0].Value -isnot [string] -or -not ([string]$prop[0].Value).Trim()) {
            [void]$missing.Add($field)
        } else {
            $values[$field] = [string]$prop[0].Value
        }
    }
    if ($missing.Count -gt 0) {
        throw (New-LamWakeRefusal 'ARTIFACT-FIELD-MISSING' ($name + ' lacks a non-empty string for: ' + ($missing -join ', ')))
    }
    # THE VALUES THAT REACH THE ARGV, EACH RESTRICTED TO WHAT ITS SLOT HOLDS (review
    # finding). effort is restricted too, but only once the installed CLI's --help has been read
    # (Assert-LamWakeEffort, step 5), because its allowed values are that help's to name.
    Assert-LamWakeSlot -ArtifactName $name -Field 'head_sha' -Value $values['head_sha'] `
        -Pattern '^[0-9a-f]{40}\z' -Shown '^[0-9a-f]{40}$' -Holds 'a full commit id in 40 lowercase hex digits'
    Assert-LamWakeSlot -ArtifactName $name -Field 'seat_name' -Value $values['seat_name'] `
        -Pattern '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z' -Shown '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' -Holds 'a name the -n slot can hold'
    Assert-LamWakeSlot -ArtifactName $name -Field 'model' -Value $values['model'] `
        -Pattern '^[A-Za-z0-9][A-Za-z0-9._:\[\]-]{0,99}\z' -Shown '^[A-Za-z0-9][A-Za-z0-9._:\[\]-]{0,99}$' -Holds 'a model id the --model slot can hold'
    if (-not (Test-LamWakeAbsolutePath -Path $values['worktree_path'])) {
        throw (New-LamWakeRefusal 'WORKTREE-NOT-ABSOLUTE' ($name + ': worktree_path is not an absolute path: ' + $values['worktree_path']))
    }
    return [pscustomobject]@{
        name          = $name
        path          = $path
        head_sha      = $values['head_sha']
        batch         = $values['batch']
        seat_name     = $values['seat_name']
        model         = $values['model']
        effort        = $values['effort']
        worktree_path = $values['worktree_path']
        brief_source  = $values['brief_source']
    }
}

# =================================================================================================
# (3) THE BRIEF -- BYTES, NEVER TEXT
# =================================================================================================
function Resolve-LamWakeBriefSource {
    param([string]$Root, [string]$BriefSource)
    $full = ''
    try { $full = ConvertTo-LamWakeFullPath -Path ([System.IO.Path]::Combine($Root, ($BriefSource -replace '/', '\'))) }
    catch { $full = '' }
    $prefix = $Root.TrimEnd('\') + '\'
    if (-not $full -or -not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (New-LamWakeRefusal 'BRIEF-SOURCE-ESCAPES' ("brief_source '" + $BriefSource + "' does not resolve inside the mission root " + $Root))
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw (New-LamWakeRefusal 'BRIEF-SOURCE-ABSENT' ('brief_source resolves to ' + $full + ', which is not a file'))
    }
    return $full
}

function Find-LamWakeMarkerOffset {
    # The offset of the first byte of the first LINE that begins with the six bytes "## 10." -- the
    # regex ^## 10\. applied line by line, where a line begins at offset 0 or after an LF byte.
    # Returns -1 when there is no such line.
    param([byte[]]$Bytes)
    $marker = [byte[]](35, 35, 32, 49, 48, 46)
    $n = $Bytes.Length
    $lineStart = 0
    while ($lineStart -le ($n - $marker.Length)) {
        $hit = $true
        for ($k = 0; $k -lt $marker.Length; $k++) {
            if ($Bytes[$lineStart + $k] -ne $marker[$k]) { $hit = $false; break }
        }
        if ($hit) { return $lineStart }
        $nl = [System.Array]::IndexOf($Bytes, [byte]10, $lineStart)
        if ($nl -lt 0) { break }
        $lineStart = $nl + 1
    }
    return -1
}

function Get-LamWakeBriefSlice {
    # The brief: bytes 0 .. (marker offset - 1), as a byte[] (assign the result; do not wrap the call
    # in @(), which would re-wrap the array).
    param([byte[]]$Bytes)
    $offset = Find-LamWakeMarkerOffset -Bytes $Bytes
    if ($offset -lt 0) {
        throw (New-LamWakeRefusal 'BRIEF-MARKER-ABSENT' 'no line matching ^## 10\. in the brief source')
    }
    if ($offset -eq 0) {
        throw (New-LamWakeRefusal 'BRIEF-EMPTY' 'the brief source begins with its ## 10. line, so the brief would be empty')
    }
    $slice = New-Object byte[] $offset
    [System.Array]::Copy($Bytes, 0, $slice, 0, $offset)
    return , $slice
}

# =================================================================================================
# (4) THE WORKTREE
# =================================================================================================
function Resolve-LamWakeGit {
    $cmd = $null
    try { $cmd = @(Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue) } catch { $cmd = @() }
    if ($cmd.Count -eq 0) { throw (New-LamWakeRefusal 'GIT-ABSENT' 'git is not an application on PATH') }
    return $cmd[0].Source
}

function Invoke-LamWakeGit {
    # stdout lines and exit code. Continue around the native call (under Stop a stderr line is fatal),
    # and GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR are cleared for the call so an inherited value
    # cannot answer for a different repository than the one -C names.
    param([string]$GitPath, [string]$Dir, [string[]]$GitArgs)
    $saved = @{}
    foreach ($v in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR')) {
        $saved[$v] = [Environment]::GetEnvironmentVariable($v, 'Process')
        [Environment]::SetEnvironmentVariable($v, $null, 'Process')
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $GitPath -C $Dir @GitArgs 2>$null
        $code = $LASTEXITCODE
        $lines = @(@($out) | ForEach-Object { "$_" })
        return [pscustomobject]@{ exit = $code; text = (($lines -join "`n").Trim()) }
    } finally {
        $ErrorActionPreference = $prevEap
        foreach ($v in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR')) {
            [Environment]::SetEnvironmentVariable($v, $saved[$v], 'Process')
        }
    }
}

function Assert-LamWakeWorktree {
    # Returns the worktree's normalised full path, or throws a refusal. The order is cheapest first,
    # and git is asked nothing about a path already refused on its face.
    param([string]$WorktreePath, [string]$HeadSha, [string]$Root)
    # UNREACHABLE FROM THE MAIN FLOW: Invoke-LamWakePrepare calls this only after Get-LamWakeArtifact
    # has refused a worktree_path that is not absolute (the first WORKTREE-NOT-ABSOLUTE site), with
    # the same value. This second site stays for library mode, where this function is called alone.
    if (-not (Test-LamWakeAbsolutePath -Path $WorktreePath)) {
        throw (New-LamWakeRefusal 'WORKTREE-NOT-ABSOLUTE' ('worktree_path is not an absolute path: ' + $WorktreePath))
    }
    $notLocal = Get-LamWakeNotLocalReason -Path $WorktreePath
    if ($notLocal) {
        throw (New-LamWakeRefusal 'WORKTREE-NOT-LOCAL' ('worktree_path ' + $WorktreePath + ' ' + $notLocal + '; the seat is launched in a worktree on a local drive, named by its drive letter'))
    }
    $full = ConvertTo-LamWakeFullPath -Path $WorktreePath
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw (New-LamWakeRefusal 'WORKTREE-ABSENT' ('worktree_path does not exist as a directory: ' + $full))
    }
    # THE PLANES THE STARTER MUST NOT WRITE (a review finding; a re-review defect).
    # A worktree elsewhere under the mission root -- the CLI-owned .claude\worktrees\<id> placement --
    # is admitted, and .wake-brief.md is then written under the mission root; a worktree that IS the
    # mission root, or lies inside .mission or .mission-runtime, is refused. Every side of each
    # comparison is a CANONICAL FINAL PATH (THE ALIAS DECISION, in the header, which also says what
    # this covers and what it does not).
    $wtCanon = Get-LamWakeCanonicalPath -Path $full -Role 'worktree_path'
    $rootCanon = Get-LamWakeCanonicalPath -Path $Root -Role 'the mission root'
    if ([string]::Equals($wtCanon.key, $rootCanon.key, [System.StringComparison]::Ordinal)) {
        throw (New-LamWakeRefusal 'WORKTREE-IS-MISSION-ROOT' ('worktree_path ' + $full + ' is the mission root itself (canonically ' + $wtCanon.final + '); a seat opens in the worktree the operator prepared, never at the repository of record'))
    }
    foreach ($plane in @('.mission', '.mission-runtime')) {
        $planeFull = $Root.TrimEnd('\') + '\' + $plane
        # A plane is skipped ONLY when nothing stands at its name (Test-LamWakeNamePresent, which is
        # fail-closed where [System.IO.Directory]::Exists was not -- a final review defect).
        if (-not (Test-LamWakeNamePresent -Path $planeFull -Role $plane)) { continue }
        $planeCanon = Get-LamWakeCanonicalPath -Path $planeFull -Role $plane
        if ($wtCanon.key.StartsWith($planeCanon.key, [System.StringComparison]::Ordinal)) {
            throw (New-LamWakeRefusal 'WORKTREE-IN-MISSION-PLANE' ('worktree_path ' + $full + ' (canonically ' + $wtCanon.final + ') lies inside ' + $planeFull + ', a plane the starter must not write .wake-brief.md into (canonically ' + $planeCanon.final + '); prepare the seat''s worktree outside .mission and .mission-runtime'))
        }
    }
    $band = Get-LamWakeBand
    if ($full.Length -gt $band.MaxGreen) {
        throw (New-LamWakeRefusal 'WORKTREE-TOO-LONG' ('worktree_path is ' + $full.Length + ' characters; the largest worktree root measured GREEN is ' + $band.MaxGreen + ' (LAM-ACCEPT amendment 42, WP-2 arm G). Computed, not run: a fidelity bound of about ' + $band.FidelityBound + ' and a cured ceiling of about ' + $band.CuredCeiling + '; git itself refuses a linked-worktree path of ' + $band.GitCeiling + ' characters or more. Prepare the worktree at a shorter path.'))
    }
    $git = Resolve-LamWakeGit
    $top = Invoke-LamWakeGit -GitPath $git -Dir $full -GitArgs @('rev-parse', '--show-toplevel')
    if ($top.exit -ne 0 -or -not $top.text) {
        throw (New-LamWakeRefusal 'WORKTREE-NOT-A-REPOSITORY' ('git rev-parse --show-toplevel failed in ' + $full + ' (exit ' + $top.exit + ')'))
    }
    $topFull = ''
    try { $topFull = ConvertTo-LamWakeFullPath -Path $top.text } catch { $topFull = $top.text }
    if (-not [string]::Equals($topFull, $full, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (New-LamWakeRefusal 'WORKTREE-NOT-TOPLEVEL' ('git names ' + $topFull + ' as the top level, not worktree_path ' + $full))
    }
    $head = Invoke-LamWakeGit -GitPath $git -Dir $full -GitArgs @('rev-parse', '--verify', 'HEAD')
    $headText = $head.text.ToLowerInvariant()
    if ($head.exit -ne 0 -or -not [string]::Equals($headText, $HeadSha.Trim().ToLowerInvariant(), [System.StringComparison]::Ordinal)) {
        throw (New-LamWakeRefusal 'WORKTREE-HEAD-MISMATCH' ('the worktree HEAD is ' + $(if ($head.exit -eq 0) { $headText } else { '(unreadable)' }) + ', the artifact declares head_sha ' + $HeadSha))
    }
    return $full
}

# =================================================================================================
# (5) THE CLI'S FLAGS, THE EFFORT SLOT AND THE ARGV
# =================================================================================================
function Test-LamWakeHelpText {
    # The flags the argv needs that the help text does NOT list, as a string[] (empty when all three
    # are there). Assign the result before counting it.
    param([string]$Text)
    $missing = New-Object System.Collections.Generic.List[string]
    if ($Text -notmatch '(?m)^[ \t]*-n,[ \t]+--name\b') { [void]$missing.Add('-n/--name') }
    if ($Text -notmatch '(?m)^[ \t]*--model\b') { [void]$missing.Add('--model') }
    if ($Text -notmatch '(?m)^[ \t]*--effort\b') { [void]$missing.Add('--effort') }
    return , ($missing.ToArray())
}

function Get-LamWakeEffortValues {
    # The values the help text lists for --effort, as a string[] (empty when it lists none). The
    # --effort option line and its continuation lines (indented five or more columns; an option line
    # is indented less) are joined, and the values are the first parenthesised list of two or more
    # comma-separated bare tokens in that text. CLI 2.1.258 prints, on the line under --effort,
    # "(low, medium, high, xhigh, max)". Assign the result before counting it.
    param([string]$Text)
    $desc = New-Object System.Text.StringBuilder
    $inEffort = $false
    foreach ($line in ($Text -split "`r?`n")) {
        if (-not $inEffort) {
            if ($line -match '^[ \t]*--effort\b(.*)$') { $inEffort = $true; [void]$desc.Append($Matches[1]) }
            continue
        }
        if ($line -notmatch '^[ \t]{5,}\S') { break }
        [void]$desc.Append(' ').Append($line.Trim())
    }
    $values = New-Object System.Collections.Generic.List[string]
    $m = [regex]::Match($desc.ToString(), '\(\s*([A-Za-z0-9][A-Za-z0-9._-]{0,31}(?:\s*,\s*[A-Za-z0-9][A-Za-z0-9._-]{0,31})+)\s*\)')
    if ($m.Success) {
        foreach ($v in ($m.Groups[1].Value -split ',')) { [void]$values.Add($v.Trim()) }
    }
    return , ($values.ToArray())
}

function Assert-LamWakeClaudeFlags {
    # Reads `claude --help` and nothing else: no session is started to find out. Returns the help
    # text, for the effort slot.
    param([string]$ClaudePath)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $ClaudePath --help 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
    $text = (@($out) | ForEach-Object { "$_" }) -join "`n"
    if ($code -ne 0) {
        throw (New-LamWakeRefusal 'CLAUDE-HELP-FAILED' ('claude --help exited ' + $code))
    }
    $missing = Test-LamWakeHelpText -Text $text
    if (@($missing).Count -gt 0) {
        throw (New-LamWakeRefusal 'CLAUDE-FLAG-ABSENT' ('the installed CLI''s --help does not list: ' + (@($missing) -join ', ')))
    }
    return $text
}

function Assert-LamWakeEffort {
    # The effort slot (THE ARGV DECISION, in the header). Returns the rule that applied, as printed.
    param([string]$ArtifactName, [string]$Effort, [string]$HelpText)
    $allowed = Get-LamWakeEffortValues -Text $HelpText
    $ok = $false
    $rule = ''
    $failText = ''
    if (@($allowed).Count -gt 0) {
        foreach ($a in @($allowed)) { if ($Effort -ceq $a) { $ok = $true } }
        $rule = 'effort must be one of the values the installed CLI''s --help lists for --effort (' + (@($allowed) -join ', ') + ')'
        $failText = 'effort is not one of the values the installed CLI''s --help lists for --effort (' + (@($allowed) -join ', ') + ')'
    } else {
        $ok = ($Effort -cmatch '^[a-z]{1,16}\z')
        $rule = 'effort must match ^[a-z]{1,16}$ (the installed CLI''s --help lists no values for --effort)'
        $failText = 'effort does not match ^[a-z]{1,16}$ (the installed CLI''s --help lists no values for --effort)'
    }
    if (-not $ok) {
        throw (New-LamWakeRefusal 'ARTIFACT-FIELD-UNSAFE' ($ArtifactName + ': ' + $failText + '; refused, never escaped or repaired'))
    }
    return $rule
}

function New-LamWakeArgv {
    # EXACTLY seven tokens, as a string[]: no -w (the operator cut the worktree), no -p (the seat is
    # interactive), nothing else. The prompt is composed from the validated seat_name alone. Assign
    # the result; do not wrap the call in @().
    param([string]$SeatName, [string]$Model, [string]$Effort)
    $argv = New-Object string[] 7
    $argv[0] = '-n'
    $argv[1] = $SeatName
    $argv[2] = '--model'
    $argv[3] = $Model
    $argv[4] = '--effort'
    $argv[5] = $Effort
    $argv[6] = 'You are the ' + $SeatName + ' seat; read ./.wake-brief.md and begin.'
    return , $argv
}

# =================================================================================================
# MAIN
# =================================================================================================
function Invoke-LamWakePrepare {
    # Steps (1)-(5) and the one write. Returns { exit; plan }: exit 2 with the refusal printed, or
    # exit 0 with the plan the launch uses. It does NOT launch: a native command run inside a function
    # whose output is assigned has its stdout captured into a pipe, and an interactive seat must own
    # the console. The launch is the script's top level, below.
    param([string]$MissionRoot = '.')
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $plan = $null
    $authDecision = $null
    try {
        # THE AUTHENTICATION MODE, FIRST: before the CLI is looked up or asked for its --help. Unset,
        # nothing is loaded and the seat inherits this console's environment as it always has. Set, the library decides
        # from which credentials the environment carries, by presence only; in key mode the argv, the brief, the
        # worktree's .claude settings and its root files the CLI loads are scanned before the brief is written, below.
        if (-not [string]::IsNullOrEmpty($env:VANGUARD_AUTH_MODE)) {
            $authLib = Join-Path $PSScriptRoot 'lam-auth-mode.ps1'
            if (-not (Test-Path -LiteralPath $authLib -PathType Leaf)) { throw (New-LamWakeRefusal 'AUTH-MODE-UNREADABLE' ('VANGUARD_AUTH_MODE is set and ' + $authLib + ' is not on disk, so the mode cannot be decided')) }
            . $authLib
            $authDecision = Get-LamAuthMode
            if (-not $authDecision.ok) { throw (New-LamWakeRefusal $authDecision.code $authDecision.reason) }
        }
        $root = Resolve-LamWakeMissionRoot -MissionRoot $MissionRoot
        $claude = Resolve-LamWakeClaude
        $art = Get-LamWakeArtifact -Root $root
        $source = Resolve-LamWakeBriefSource -Root $root -BriefSource $art.brief_source
        $sourceBytes = [System.IO.File]::ReadAllBytes($source)
        $brief = Get-LamWakeBriefSlice -Bytes $sourceBytes
        $worktree = Assert-LamWakeWorktree -WorktreePath $art.worktree_path -HeadSha $art.head_sha -Root $root
        $helpText = Assert-LamWakeClaudeFlags -ClaudePath $claude
        $effortRule = Assert-LamWakeEffort -ArtifactName $art.name -Effort $art.effort -HelpText $helpText
        $argv = New-LamWakeArgv -SeatName $art.seat_name -Model $art.model -Effort $art.effort
        if ($null -ne $authDecision) {
            $authSettings = @((Join-Path $worktree '.claude\settings.json'), (Join-Path $worktree '.claude\settings.local.json'))
            if ($authDecision.mode -ceq 'api-key') {
                $authBrief = [System.Text.Encoding]::GetEncoding(28591).GetString($brief)
                $authDecision = Test-LamAuthSpawnInputs -Arguments $argv -Texts @{ ('brief (from ' + $source + ', to be written as the worktree''s .wake-brief.md)') = $authBrief } -Files (@($authSettings) + @(Get-LamAuthSessionFiles -Root $worktree)) -SettingsFiles $authSettings
            } else {
                $authDecision = Test-LamAuthSpawnInputs -Mode 'subscription' -SettingsFiles $authSettings
            }
            if (-not $authDecision.ok) { throw (New-LamWakeRefusal $authDecision.code $authDecision.reason) }
        }
        # EVERY ASSERTION HAS PASSED. The one write -- and what already stands at its name is examined
        # first, so the brief cannot be written THROUGH a link into a plane (final review, hard link).
        $target = Join-Path $worktree '.wake-brief.md'
        Assert-LamWakeBriefTarget -Target $target
        $writeError = ''
        try { [System.IO.File]::WriteAllBytes($target, $brief) } catch { $writeError = $_.Exception.Message }
        if ($writeError) { throw (New-LamWakeRefusal 'BRIEF-WRITE-FAILED' ('could not write ' + $target + ': ' + $writeError)) }
        $plan = [pscustomobject]@{ root = $root; art = $art; source = $source; brief = $brief; worktree = $worktree; claude = $claude; effortRule = $effortRule; argv = $argv; target = $target }
    } catch {
        Write-LamWakeRefusalLines -Message "$($_.Exception.Message)" -Closing 'lam-wake: nothing was written and no session was started.'
        return [pscustomobject]@{ exit = 2; plan = $null }
    } finally { $ErrorActionPreference = $prevEap }

    Write-LamWakeLine ('lam-wake: mission root  ' + $plan.root)
    Write-LamWakeLine ('lam-wake: artifact      ' + $plan.art.name + '  (batch ' + $plan.art.batch + ')')
    Write-LamWakeLine ('lam-wake: worktree      ' + $plan.worktree + '  (' + $plan.worktree.Length + ' chars, HEAD ' + $plan.art.head_sha + ')')
    Write-LamWakeLine ('lam-wake: brief         ' + $plan.target + '  ' + $plan.brief.Length + ' bytes, sha256 ' + (Get-LamWakeSha256Hex -Bytes $plan.brief) + '  (from ' + $plan.source + ')')
    Write-LamWakeLine ('lam-wake: claude        ' + $plan.claude)
    Write-LamWakeLine ('lam-wake: effort rule   ' + $plan.effortRule)
    # An admitted authentication mode prints nothing: the plan is the plan the seat has without the variable.
    for ($i = 0; $i -lt $plan.argv.Length; $i++) { Write-LamWakeLine ('lam-wake: argv[' + $i + ']       ' + $plan.argv[$i]) }
    return [pscustomobject]@{ exit = 0; plan = $plan }
}

# =================================================================================================
# (6) THE LAUNCH
# =================================================================================================
function Enter-LamWakeWorktree {
    # THE LAUNCH'S LOCATION (a final review defect). The design note launches claude IN
    # the operator-prepared worktree, so the shell must BE there before the CLI is called. It used to be
    # pushed there by a bare Push-Location under ErrorActionPreference Continue: a failure printed and the
    # script carried on, and claude ran in the CALLER's directory. MEASURED 2026-09-15, in library mode,
    # with the worktree renamed away after the brief was written: the push failed and the stub was
    # launched anyway, with its current directory the mission root -- and the same shape was measured with
    # a worktree the push could not enter for want of access.
    # So: the push is -ErrorAction Stop inside a try, and then the location the launch would actually run
    # in is compared with the worktree BY CANONICAL FINAL PATH. Anything else -- a push that fails, a
    # location that cannot be canonicalised, a location that is not the worktree -- is refused
    # LAUNCH-LOCATION-FAILED and NOTHING IS LAUNCHED. On refusal the location stack is left as it was
    # found; on admission the caller owns the Pop-Location. Push-Location is not scoped to this function:
    # PowerShell's location and its default stack belong to the runspace, so the caller is moved too.
    param([string]$Worktree)
    $entered = $false
    $why = ''
    try {
        Push-Location -LiteralPath $Worktree -ErrorAction Stop
        $entered = $true
        $here = (Get-Location).ProviderPath
        $hereCanon = Get-LamWakeCanonicalPath -Path $here -Role 'the directory the launch would run in'
        $wantCanon = Get-LamWakeCanonicalPath -Path $Worktree -Role 'worktree_path'
        if (-not [string]::Equals($hereCanon.key, $wantCanon.key, [System.StringComparison]::Ordinal)) {
            $why = 'the shell stands at ' + $here + ' (canonically ' + $hereCanon.final + '), not at the worktree ' + $Worktree + ' (canonically ' + $wantCanon.final + ')'
        }
    } catch {
        $m = "$($_.Exception.Message)"
        if ($m.StartsWith('LAMWAKE-REFUSED|')) { $m = $m.Split([char[]]@([char]'|'), 3)[2] }
        $why = $m
    }
    if ($why) {
        if ($entered) { Pop-Location }
        throw (New-LamWakeRefusal 'LAUNCH-LOCATION-FAILED' ('the seat is launched IN the worktree the operator prepared, and the starter could not put the shell there: ' + $why + '. Nothing was launched; .wake-brief.md has already been written and is yours to remove.'))
    }
    return $true
}

# Runs only when this file is INVOKED, never when it is dot-sourced (library mode).
if ($MyInvocation.InvocationName -ne '.') {
    $wakePrep = Invoke-LamWakePrepare -MissionRoot $MissionRoot
    if ($wakePrep.exit -ne 0) { exit $wakePrep.exit }
    $wakePlan = $wakePrep.plan
    $wakeArgv = $wakePlan.argv
    $wakeCode = 1
    $wakeEnterError = ''
    try { $null = Enter-LamWakeWorktree -Worktree $wakePlan.worktree }
    catch { $wakeEnterError = "$($_.Exception.Message)" }
    if ($wakeEnterError) {
        Write-LamWakeRefusalLines -Message $wakeEnterError -Closing 'lam-wake: no session was started.'
        exit 2
    }
    # Continue around the native call: under Stop a line on its stderr is fatal. The call is a bare
    # statement, never assigned or piped, so the seat inherits this console.
    $ErrorActionPreference = 'Continue'
    try {
        & $wakePlan.claude @wakeArgv
        $wakeCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($null -eq $wakeCode) { $wakeCode = 1 }
    exit $wakeCode
}
