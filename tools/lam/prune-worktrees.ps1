<#
.SYNOPSIS
    prune-worktrees.ps1 -- the operator's prune of linked worktrees and their branches, in four modes, one per run:
    -List, -Copy, -Verify [-DryRun], -Remove (BATCH-6 WP-P (a)).

.DESCRIPTION
    THE ACT IS THE OPERATOR's. The tool removes nothing that is not confirmed tree by tree. Its forms are the record's:
    the listing is s4_prune_listing.py's (seat 4), line for line;
    the copy, the digest check and the removal are the acts of that close's prune.block.md (BLOCK 1 with its CHECK 1 and
    CHECK 2, BLOCK 2).

    -List -Out <file> -Trees <tree>[,<tree>...] -Tip <commit> [-Set <name>]
        Writes the listing by exclusive create (an existing file is refused); LF line ends; UTF-8 without a BOM:
          line 1     the title (prefixed "<Set> -- " when -Set is given);
          per tree, in -Trees order --
          == <name> | <path> | branch <branch> | HEAD <sha40> | merge-base --is-ancestor HEAD <tip8> exit <rc> | branch
             tip == the tree's HEAD: <True|False> | files walked <n>                                     (one line)
             SESSION sidecar session_id <s> spawned_at <t> model <m>
                 from <MissionRoot>\.mission-runtime\evidence\session-<disp>\OWNER, <disp> = the name less "wt-"
             SESSION spawn-ledger complete seq <n> <the line's session keys as a Python dict repr>
                 one per "complete" line of <MissionRoot>\.mission-runtime\lam\spawn-ledger.jsonl naming <disp>
             SESSION handoff <disp>.handoff.yaml from_worker <w>        the tree's OWN handoff, UNTRACKED (ruling Q5)
             SESSION handoff <disp>.handoff.yaml: tracked in the tree, not read
             SESSION handoff <disp>.handoff.yaml: none in the tree
             CITED <file> <field> -> <path>
                 every .mission\dispatches\*.anchors.yaml evidence_manifest / worktree_path and every
                 .mission-runtime\lam\wake\*.wake.json worktree_path of the mission root that names a path INTO the tree
             [<XY>] <rel> | <bytes> B | sha256 <hex>        or        [<XY>] <rel> | NOT A FILE
                 every entry of `git status --porcelain -z --untracked-files=all --ignored`, in git's order
          last line  TOTAL: <n> tree(s), <n> entries
        To stdout, as each tree finishes, and never into the -Out file:
          ELAPSED <name> <t> s: ancestry <a> s, walk <w> s, session <s> s, status <g> s, digests <d> s over <n> entries
             one Stopwatch per tree, seconds to three decimals, invariant culture: ancestry the merge-base and branch
             tip reads, walk the file count, session the SESSION and CITED lines, status the one git status, digests
             the entry rows
        then, after the write, one summary line per tree and the LISTING line.

    -Copy -Set <name> -Trees <tree>[,<tree>...]
        Creates <MissionRoot>\.mission-runtime\scratch-copies\<name> (an existing folder is refused) and robocopies each
        tree into it (/E /COPY:DAT /DCOPY:T /R:1 /W:1 /XJ /NFL /NDL /NP), printing "robocopy <tree> exit <n>"; 8 or
        above is a failure and STOPS the run.

    -Verify -Listing <file> -Set <name>        or        -Verify -Listing <file> -DryRun
        CHECK 1 (not under -DryRun): per listed tree "<tree> <source files> = <copy files> <True|False>". CHECK 2:
        every listed digest against the copy -- or, with -DryRun, against the SOURCE trees, copying nothing -- between
        "STARTED <clock>" and "ENDED <clock> ELAPSED <s> s": "listed <n>; missing <m>; mismatched <k>".

    -Remove -Trees <tree>[,<tree>...] -ConfirmRemove <tree>@<HEAD8>[@<citing file>...][,...]
        Every tree needs its own confirmation, bound to its HEAD, so a tree that moved is refused; a tree a record
        cites (the CITED lines) also needs every citing file named after its HEAD (ruling Q6). Any refusal refuses the
        whole run before any act. Then, per tree in -Trees order: `git worktree remove --force` and "remove <tree> exit
        <n>"; `git branch -d` and "branch -d <branch> exit <n>" -- a refusal is a FINDING, the branch is left and the
        loop stops there. Then one `git worktree prune`, `git --no-pager worktree list`, and the porcelain read again:
        ANY prunable registration left is a FINDING. The tool never forces a branch delete.

    EXIT CODES: 0 done; 2 refused before any act; 3 verify found a file missing or mismatched, or a count unequal (a
    STOP: remove nothing); 4 a FINDING after the removal began (a `git branch -d` or `git worktree remove` refusal, or a
    prunable registration left); 8 a robocopy failure.

    WHAT IT WRITES: the -Out file and the -Copy folder, nothing else -- no other folder under scratch-copies or close,
    no ledger, no tracked file. -Remove's acts are git's.

    WHERE THE LISTING DEPARTS FROM s4's, EACH BY DESIGN: porcelain is read with -z, so a path git would quote prints as
    itself and a rename prints its new path; git status runs with --no-optional-locks, so listing writes no index;
    the handoff line reads only the tree's own UNTRACKED handoff (ruling Q5); a detached tree prints "branch
    (detached)"; a folder that is a reparse point is not walked (robocopy /XJ skips junctions too); the CITED lines
    are new (ruling Q6).

    Lists given to -Trees and -ConfirmRemove are also split at commas, so a `powershell -File` caller can pass them.
    Dot-sourced, the script defines its functions and runs nothing.

.EXAMPLE
    & .\tools\lam\prune-worktrees.ps1 -MissionRoot . -List -Out .mission-runtime\lam\close\x\prune-listing.txt `
        -Trees ..\<project>-worktrees\wt-D-X,..\<project>-worktrees\wt-D-Y -Tip <tip8>
.EXAMPLE
    & .\tools\lam\prune-worktrees.ps1 -MissionRoot . -Remove -Trees ..\<project>-worktrees\wt-D-X `
        -ConfirmRemove wt-D-X@<HEAD8>
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$MissionRoot,
    [string]$Set,
    [string[]]$Trees,
    [string]$Tip,
    [switch]$List,
    [string]$Out,
    [switch]$Copy,
    [switch]$Verify,
    [string]$Listing,
    [switch]$DryRun,
    [switch]$Remove,
    [string[]]$ConfirmRemove
)

$script:PwUtf8 = New-Object System.Text.UTF8Encoding($false)
$script:PwSha = $null
$script:PwGit = $null
$script:PwActed = $false
$script:PwBound = @{}
$script:PwWatch = $null
$script:PwLaps = $null

# ------------------------------------------------------------------------------------------------ output, refusal --
function Write-PwLine {
    param([AllowEmptyString()][string]$Text)
    Write-Host $Text
}

function Format-PwClock {
    param([DateTime]$At)
    return $At.ToString('yyyy-MM-ddTHH:mm:ss.fff', [System.Globalization.CultureInfo]::InvariantCulture) + 'Z'
}

function Format-PwSeconds {
    param([TimeSpan]$Span)
    return $Span.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Add-PwLap {
    # -List's per-tree clock: the tree's Stopwatch read at the end of a phase.
    if ($script:PwWatch) { $script:PwLaps.Add($script:PwWatch.Elapsed) }
}

function Write-PwElapsed {
    # -List's per-tree line, to stdout only -- never into $lines, so never into the -Out file -- as the tree finishes.
    # Five laps: ancestry, walk, session (the SESSION and CITED lines), status (taken inside Get-PwEntryRows), digests.
    param([string]$Name, [int]$Entries)
    $script:PwWatch.Stop()
    $l = $script:PwLaps
    Write-PwLine ('ELAPSED ' + $Name + ' ' + (Format-PwSeconds $l[4]) + ' s: ancestry ' + (Format-PwSeconds $l[0]) +
                  ' s, walk ' + (Format-PwSeconds ($l[1] - $l[0])) +
                  ' s, session ' + (Format-PwSeconds ($l[2] - $l[1])) +
                  ' s, status ' + (Format-PwSeconds ($l[3] - $l[2])) +
                  ' s, digests ' + (Format-PwSeconds ($l[4] - $l[3])) + ' s over ' + $Entries + ' entries')
}

function Get-PwShaHex {
    param([byte[]]$Bytes)
    if (-not $script:PwSha) { $script:PwSha = [System.Security.Cryptography.SHA256]::Create() }
    return ([System.BitConverter]::ToString($script:PwSha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant()
}

# ------------------------------------------------------------------------------------------------ native commands --
function ConvertTo-PwArgument {
    # One argument quoted for CreateProcess (the rules CommandLineToArgvW reads back).
    param([AllowEmptyString()][string]$Value)
    if (($Value.Length -gt 0) -and ($Value -notmatch '[\s"]')) { return $Value }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $slashes = 0
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -ceq [char]92) { $slashes++; continue }
        if ($ch -ceq [char]34) {
            [void]$sb.Append([char]92, (2 * $slashes) + 1)
            [void]$sb.Append([char]34)
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) { [void]$sb.Append([char]92, $slashes); $slashes = 0 }
        [void]$sb.Append($ch)
    }
    if ($slashes -gt 0) { [void]$sb.Append([char]92, 2 * $slashes) }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Invoke-PwNative {
    # Runs a program, its output read as UTF-8 (git's -z output is UTF-8 bytes), both streams kept.
    param([string]$File, [string[]]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = (@($Arguments | ForEach-Object { ConvertTo-PwArgument $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = $script:PwUtf8
    $psi.StandardErrorEncoding = $script:PwUtf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $errTask = $p.StandardError.ReadToEndAsync()
    $stdout = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $stdout; Err = $errTask.Result }
}

function Invoke-PwGit {
    param([string[]]$Arguments)
    if (-not $script:PwGit) {
        $cmd = @(Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue)
        if ($cmd.Count -eq 0) { throw 'REFUSE: git is not on PATH' }
        $script:PwGit = $cmd[0].Source
    }
    return (Invoke-PwNative -File $script:PwGit -Arguments $Arguments)
}

function Write-PwNativeOutput {
    param($Result)
    foreach ($s in @($Result.Out, $Result.Err)) {
        if (-not $s) { continue }
        foreach ($l in ($s -split "\r?\n")) { if ($l.Trim().Length -gt 0) { Write-PwLine $l.TrimEnd() } }
    }
}

# --------------------------------------------------------------------------------------------------------- paths --
function Get-PwFullPath {
    param([string]$Path, [string]$Base)
    if (-not $Path) { return $null }
    $p = $Path.Trim() -replace '/', '\'
    try {
        if (-not [System.IO.Path]::IsPathRooted($p)) {
            if (-not $Base) { $Base = (Get-Location -PSProvider FileSystem).ProviderPath }
            $p = [System.IO.Path]::Combine($Base, $p)
        }
        $full = [System.IO.Path]::GetFullPath($p)
    } catch { return $null }
    if ($full.Length -gt 3) { $full = $full.TrimEnd('\') }
    return $full
}

function Test-PwSamePath {
    param([string]$A, [string]$B)
    if ((-not $A) -or (-not $B)) { return $false }
    return [string]::Equals($A, $B, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-PwInside {
    # True when PATH is the tree itself or lies under it.
    param([string]$Path, [string]$Tree)
    if ((-not $Path) -or (-not $Tree)) { return $false }
    return ([string]::Equals($Path, $Tree, [System.StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith($Tree + '\', [System.StringComparison]::OrdinalIgnoreCase))
}

function Split-PwList {
    param([string[]]$Values)
    foreach ($v in @($Values)) {
        if ($null -eq $v) { continue }
        foreach ($part in $v.Split(',')) { $t = $part.Trim(); if ($t) { $t } }
    }
}

# ----------------------------------------------------------------------------------------------------- porcelain --
function ConvertFrom-PwPorcelain {
    # `git worktree list --porcelain -z`: NUL-terminated fields, an empty field between entries. The first entry is
    # the main worktree. Prunable is git's reason text (possibly empty) when the registration is prunable, else $null.
    param([AllowEmptyString()][string]$Text)
    $entries = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($field in $Text.Split([char]0)) {
        if ($field.Length -eq 0) { $cur = $null; continue }
        $sp = $field.IndexOf(' ')
        if ($sp -lt 0) { $key = $field; $value = '' } else { $key = $field.Substring(0, $sp); $value = $field.Substring($sp + 1) }
        if ($key -ceq 'worktree') {
            $cur = [pscustomobject]@{ Path = $value; Head = ''; Branch = $null; Detached = $false; Bare = $false
                                      Locked = $null; Prunable = $null }
            $entries.Add($cur)
            continue
        }
        if ($null -eq $cur) { continue }
        if ($key -ceq 'HEAD') { $cur.Head = $value }
        elseif ($key -ceq 'branch') { $cur.Branch = $value }
        elseif ($key -ceq 'detached') { $cur.Detached = $true }
        elseif ($key -ceq 'bare') { $cur.Bare = $true }
        elseif ($key -ceq 'locked') { $cur.Locked = $value }
        elseif ($key -ceq 'prunable') { $cur.Prunable = $value }
    }
    $entries.ToArray()
}

function Resolve-PwTrees {
    # Each -Trees path must be a linked worktree git names (never the primary checkout): its entry, full path, name,
    # dispatch (the name less "wt-", s4 :45) and branch.
    param([string]$Root, [object[]]$Worktrees, [string[]]$Given)
    $names = @(Split-PwList $Given)
    if ($names.Count -eq 0) { throw 'REFUSE: -Trees names no tree' }
    $picked = New-Object System.Collections.Generic.List[object]
    foreach ($g in $names) {
        $full = Get-PwFullPath $g
        if (Test-PwSamePath $full $Root) { throw ('REFUSE: ' + $g + ' is the primary checkout, not a linked worktree') }
        $hit = $null
        for ($i = 1; $i -lt $Worktrees.Count; $i++) {
            if (Test-PwSamePath (Get-PwFullPath $Worktrees[$i].Path) $full) { $hit = $Worktrees[$i]; break }
        }
        if (-not $hit) { throw ('REFUSE: ' + $g + ' is not a linked worktree of ' + $Root + ' (git worktree list --porcelain)') }
        $name = [System.IO.Path]::GetFileName(($hit.Path -replace '/', '\').TrimEnd('\'))
        foreach ($q in $picked) {
            if ([object]::ReferenceEquals($q.Entry, $hit)) { throw ('REFUSE: ' + $g + ' is named twice') }
            if ([string]::Equals($q.Name, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw ('REFUSE: two trees share the name ' + $name)
            }
        }
        $disp = $name
        if ($name.StartsWith('wt-', [System.StringComparison]::Ordinal)) { $disp = $name.Substring(3) }
        $branch = $null
        if ($hit.Branch) { $branch = $hit.Branch -replace '^refs/heads/', '' }
        $picked.Add([pscustomobject]@{ Entry = $hit; Full = (Get-PwFullPath $hit.Path); Name = $name; Disp = $disp
                                       Branch = $branch })
    }
    $picked.ToArray()
}

# ------------------------------------------------------------------------------------------- the listing, parsed --
function Read-PwListing {
    # The record's listing, any of its three forms (s4's v2, an earlier arc's, BATCH-4's legacy): a tree header
    # "== <name> | <path> | ..." and entry rows "   [XY] <rel> | <n> B | sha256 <hex>" (the row common to all three).
    # Entries are @(tree, code, rel, bytes, sha); NotAFile counts "   [XY] <rel> | NOT A FILE" rows.
    param([string]$Path)
    $header = New-Object System.Text.RegularExpressions.Regex('^== (\S+) \| (.+?) \| ')
    $entry = New-Object System.Text.RegularExpressions.Regex('^   \[(..)\] (.+) \| (\d+) B \| sha256 ([0-9a-f]{64})$')
    $naf = New-Object System.Text.RegularExpressions.Regex('^   \[(..)\] (.+) \| NOT A FILE$')
    $trees = New-Object System.Collections.Generic.List[object]
    $entries = New-Object System.Collections.Generic.List[object]
    $notAFile = 0
    $tree = $null
    foreach ($l in [System.IO.File]::ReadLines($Path, $script:PwUtf8)) {
        if ($l.StartsWith('   [', [System.StringComparison]::Ordinal)) {
            $m = $entry.Match($l)
            if ($m.Success) {
                $g = $m.Groups
                $entries.Add(@($tree, $g[1].Value, $g[2].Value, [int64]$g[3].Value, $g[4].Value))
            } elseif ($naf.IsMatch($l)) { $notAFile++ }
            continue
        }
        if ($l.StartsWith('== ', [System.StringComparison]::Ordinal)) {
            $m = $header.Match($l)
            if ($m.Success) {
                $tree = [pscustomobject]@{ Name = $m.Groups[1].Value; Path = $m.Groups[2].Value }
                $trees.Add($tree)
            }
        }
    }
    return [pscustomobject]@{ Trees = $trees; Entries = $entries; NotAFile = $notAFile }
}

# ------------------------------------------------------------------------------------------------ files, digests --
function Get-PwDigest {
    param([string]$File)
    if (-not $script:PwSha) { $script:PwSha = [System.Security.Cryptography.SHA256]::Create() }
    $fs = [System.IO.File]::Open($File, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
                                 [System.IO.FileShare]'ReadWrite, Delete')
    try {
        $len = $fs.Length
        $hash = $script:PwSha.ComputeHash($fs)
    } finally { $fs.Dispose() }
    return [pscustomobject]@{ Bytes = [int64]$len; Sha = ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant() }
}

function Measure-PwFiles {
    # The files under a folder, hidden ones included, as os.walk counts them (s4 :64); a folder that is a reparse
    # point is not entered. An unreadable folder counts nothing, as os.walk's default does.
    param([string]$Root)
    if ((-not $Root) -or (-not [System.IO.Directory]::Exists($Root))) { return 0 }
    $n = 0
    $stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
    $stack.Push((New-Object System.IO.DirectoryInfo($Root)))
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        try { $items = $d.GetFileSystemInfos() } catch { continue }
        foreach ($it in $items) {
            if ($it -is [System.IO.DirectoryInfo]) {
                if (($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { $stack.Push($it) }
            } else { $n++ }
        }
    }
    return $n
}

function Get-PwEntryRows {
    # s4 :62-:78, porcelain read with -z: "   [XY] <rel> | <bytes> B | sha256 <hex>", or "| NOT A FILE".
    param([string]$TreeFull)
    $st = Invoke-PwGit @('-C', $TreeFull, '--no-optional-locks', 'status', '--porcelain', '-z',
                         '--untracked-files=all', '--ignored')
    if ($st.Code -ne 0) { throw ('REFUSE: git status failed in ' + $TreeFull + ': ' + $st.Err.Trim()) }
    Add-PwLap
    $recs = $st.Out.Split([char]0)
    $i = 0
    while ($i -lt $recs.Length) {
        $rec = $recs[$i]
        $i++
        if ($rec.Length -lt 4) { continue }
        $code = $rec.Substring(0, 2)
        $rel = $rec.Substring(3)
        if (($code[0] -ceq 'R') -or ($code[0] -ceq 'C')) { $i++ }      # a rename's source path is its own field
        $row = $null
        try {
            $fp = [System.IO.Path]::Combine($TreeFull, ($rel -replace '/', '\'))
            if ([System.IO.File]::Exists($fp)) {
                $d = Get-PwDigest $fp
                $row = '   [' + $code + '] ' + $rel + ' | ' + $d.Bytes + ' B | sha256 ' + $d.Sha
            }
        } catch { $row = $null }
        if (-not $row) { $row = '   [' + $code + '] ' + $rel + ' | NOT A FILE' }
        $row
    }
}

# --------------------------------------------------------------------------------------- Python's repr, for s4 :54 --
function Test-PwPrintable {
    # str.isprintable for one code point: every category but Other (Cc Cf Cs Co Cn) and Separator (Zl Zp Zs) but space.
    param([string]$S, [int]$Index, [int]$CodePoint)
    if ($CodePoint -eq 32) { return $true }
    if (($CodePoint -lt 32) -or ($CodePoint -eq 127)) { return $false }
    $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($S, $Index)
    $no = @([System.Globalization.UnicodeCategory]::Control, [System.Globalization.UnicodeCategory]::Format,
            [System.Globalization.UnicodeCategory]::Surrogate, [System.Globalization.UnicodeCategory]::PrivateUse,
            [System.Globalization.UnicodeCategory]::OtherNotAssigned, [System.Globalization.UnicodeCategory]::LineSeparator,
            [System.Globalization.UnicodeCategory]::ParagraphSeparator, [System.Globalization.UnicodeCategory]::SpaceSeparator)
    return ($no -notcontains $cat)
}

function Format-PwPyStr {
    # repr(str): single quotes unless the text holds a single quote and no double quote.
    param([AllowEmptyString()][string]$S)
    $q = [char]39
    if ($S.Contains([string][char]39) -and (-not $S.Contains([string][char]34))) { $q = [char]34 }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($q)
    $i = 0
    while ($i -lt $S.Length) {
        $c = $S[$i]
        $cp = [int]$c
        $width = 1
        if ([char]::IsHighSurrogate($c) -and ($i + 1 -lt $S.Length) -and [char]::IsLowSurrogate($S[$i + 1])) {
            $cp = [char]::ConvertToUtf32($c, $S[$i + 1])
            $width = 2
        }
        if ($c -ceq [char]92) { [void]$sb.Append('\\') }
        elseif ($c -ceq $q) { [void]$sb.Append([char]92); [void]$sb.Append($q) }
        elseif ($cp -eq 9) { [void]$sb.Append('\t') }
        elseif ($cp -eq 10) { [void]$sb.Append('\n') }
        elseif ($cp -eq 13) { [void]$sb.Append('\r') }
        elseif (-not (Test-PwPrintable $S $i $cp)) {
            if ($cp -lt 0x100) { [void]$sb.Append('\x' + $cp.ToString('x2')) }
            elseif ($cp -lt 0x10000) { [void]$sb.Append('\u' + $cp.ToString('x4')) }
            else { [void]$sb.Append('\U' + $cp.ToString('x8')) }
        } else { [void]$sb.Append($S.Substring($i, $width)) }
        $i += $width
    }
    [void]$sb.Append($q)
    return $sb.ToString()
}

function Test-PwNumber {
    param($V)
    return (($V -is [int]) -or ($V -is [long]) -or ($V -is [int16]) -or ($V -is [byte]) -or ($V -is [sbyte]) -or
            ($V -is [uint16]) -or ($V -is [uint32]) -or ($V -is [uint64]) -or ($V -is [double]) -or ($V -is [single]) -or
            ($V -is [decimal]))
}

function Format-PwPyRepr {
    param($V)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($null -eq $V) { return 'None' }
    if ($V -is [bool]) { if ($V) { return 'True' } else { return 'False' } }
    if ($V -is [string]) { return (Format-PwPyStr $V) }
    if (($V -is [double]) -or ($V -is [single]) -or ($V -is [decimal])) {
        $d = [double]$V
        if (($d -eq [math]::Floor($d)) -and ([math]::Abs($d) -lt 1e16)) { return ($d.ToString('0', $inv) + '.0') }
        return $d.ToString('R', $inv).Replace('E', 'e')
    }
    if (Test-PwNumber $V) { return ([System.Convert]::ToString($V, $inv)) }
    if ($V -is [System.Management.Automation.PSCustomObject]) {
        $parts = @(foreach ($p in $V.PSObject.Properties) { (Format-PwPyStr $p.Name) + ': ' + (Format-PwPyRepr $p.Value) })
        return ('{' + ($parts -join ', ') + '}')
    }
    if ($V -is [System.Collections.IDictionary]) {
        $parts = @(foreach ($k in $V.Keys) { (Format-PwPyRepr $k) + ': ' + (Format-PwPyRepr $V[$k]) })
        return ('{' + ($parts -join ', ') + '}')
    }
    if ($V -is [System.Collections.IEnumerable]) {
        $parts = @(foreach ($x in $V) { Format-PwPyRepr $x })
        return ('[' + ($parts -join ', ') + ']')
    }
    return (Format-PwPyStr ([string]$V))
}

function Format-PwPyS {
    # Python's "%s": a str as itself, None as None, anything else as its repr.
    param($V)
    if ($V -is [string]) { return $V }
    return (Format-PwPyRepr $V)
}

function Test-PwTruthy {
    param($V)
    if ($null -eq $V) { return $false }
    if ($V -is [bool]) { return $V }
    if ($V -is [string]) { return ($V.Length -gt 0) }
    if (Test-PwNumber $V) { return ($V -ne 0) }
    if ($V -is [System.Management.Automation.PSCustomObject]) { return (@($V.PSObject.Properties).Count -gt 0) }
    if ($V -is [System.Collections.ICollection]) { return ($V.Count -gt 0) }
    return $true
}

# --------------------------------------------------------------------------------------------- SESSION and CITED --
function Read-PwLedger {
    param([string]$Root)
    $p = [System.IO.Path]::Combine($Root, '.mission-runtime', 'lam', 'spawn-ledger.jsonl')
    if (-not [System.IO.File]::Exists($p)) { return ,@() }
    return ,([System.IO.File]::ReadAllLines($p, $script:PwUtf8))
}

function Get-PwSessionLines {
    # Ruling Q5: v2's three sources, in s4's order (:47-:61).
    param([string]$Root, $Tree, [string[]]$Ledger)
    $disp = $Tree.Disp
    $owner = [System.IO.Path]::Combine($Root, '.mission-runtime', 'evidence', ('session-' + $disp), 'OWNER')
    if ([System.IO.File]::Exists($owner)) {
        $text = ([System.IO.File]::ReadAllText($owner, $script:PwUtf8)).Replace("`r`n", "`n").Replace("`r", "`n")
        $o = New-Object 'System.Collections.Generic.Dictionary[string,string]'
        foreach ($m in [regex]::Matches($text, '(?m)^(\w+): (.*)$')) { $o[$m.Groups[1].Value] = $m.Groups[2].Value }
        $get = { param($k) if ($o.ContainsKey($k)) { $o[$k] } else { 'None' } }
        'sidecar session_id ' + (& $get 'session_id') + ' spawned_at ' + (& $get 'spawned_at') + ' model ' + (& $get 'model')
    }
    $n = 0
    foreach ($l in $Ledger) {
        $n++
        if ((-not $l.Contains($disp)) -or ($l.Trim().Length -eq 0)) { continue }
        try { $rec = ConvertFrom-Json -InputObject $l -ErrorAction Stop }
        catch { throw ('REFUSE: the spawn ledger''s line ' + $n + ' names ' + $disp + ' and is not JSON: ' + $_.Exception.Message) }
        if ($rec -isnot [System.Management.Automation.PSCustomObject]) { continue }
        if (([string]$rec.event -cne 'complete') -or ([string]$rec.dispatch_id -cne $disp)) { continue }
        $keys = New-Object System.Collections.Generic.List[string]
        foreach ($p in $rec.PSObject.Properties) {
            if ($p.Name.ToLowerInvariant().Contains('session') -and (Test-PwTruthy $p.Value)) {
                $keys.Add((Format-PwPyStr $p.Name) + ': ' + (Format-PwPyRepr $p.Value))
            }
        }
        $dict = '(no session key)'
        if ($keys.Count -gt 0) { $dict = '{' + ($keys -join ', ') + '}' }
        $seqP = $rec.PSObject.Properties['seq']
        $seq = 'None'
        if ($null -ne $seqP) { $seq = Format-PwPyS $seqP.Value }
        'spawn-ledger complete seq ' + $seq + ' ' + $dict
    }
    $ownRel = '.mission/dispatches/' + $disp + '.handoff.yaml'
    $own = [System.IO.Path]::Combine($Tree.Full, '.mission', 'dispatches', ($disp + '.handoff.yaml'))
    if (-not [System.IO.File]::Exists($own)) {
        'handoff ' + $disp + '.handoff.yaml: none in the tree'
    } else {
        $lf = Invoke-PwGit @('--literal-pathspecs', '-C', $Tree.Full, 'ls-files', '--error-unmatch', '--', $ownRel)
        if ($lf.Code -eq 0) {
            'handoff ' + $disp + '.handoff.yaml: tracked in the tree, not read'
        } elseif ($lf.Code -eq 1) {
            $text = ([System.IO.File]::ReadAllText($own, $script:PwUtf8)).Replace("`r`n", "`n").Replace("`r", "`n")
            $m = [regex]::Match($text, '(?m)^from_worker:\s*(.+)$')
            $w = '(none)'
            if ($m.Success) { $w = $m.Groups[1].Value.Trim() }
            'handoff ' + $disp + '.handoff.yaml from_worker ' + $w
        } else {
            throw ('REFUSE: git ls-files could not say whether ' + $ownRel + ' is tracked in ' + $Tree.Name + ': ' + $lf.Err.Trim())
        }
    }
}

function Remove-PwQuotes {
    param([AllowEmptyString()][string]$V)
    if (($V.Length -ge 2) -and ((($V[0] -ceq '"') -and ($V[$V.Length - 1] -ceq '"')) -or
                                (($V[0] -ceq "'") -and ($V[$V.Length - 1] -ceq "'")))) {
        return $V.Substring(1, $V.Length - 2)
    }
    return $V
}

function Add-PwCitation {
    param($Found, [string]$Root, [string]$File, [string]$Field, [string]$Value)
    if ((-not $Value) -or ($Value -ceq 'null') -or ($Value -ceq '~')) { return }
    $Found.Add([pscustomobject]@{ File = $File; Field = $Field; Value = $Value; Full = (Get-PwFullPath $Value $Root) })
}

function Get-PwCitations {
    # Every record of the mission root that names a path: the anchors files' evidence_manifest and worktree_path, the
    # wake artifacts' worktree_path (found at grounding). Files in ordinal order, lines in file order.
    param([string]$Root)
    $found = New-Object System.Collections.Generic.List[object]
    $dd = [System.IO.Path]::Combine($Root, '.mission', 'dispatches')
    if ([System.IO.Directory]::Exists($dd)) {
        $files = [string[]]@([System.IO.Directory]::GetFiles($dd) |
                             Where-Object { $_.EndsWith('.anchors.yaml', [System.StringComparison]::OrdinalIgnoreCase) })
        [Array]::Sort($files, [System.StringComparer]::Ordinal)
        foreach ($f in $files) {
            $rel = '.mission/dispatches/' + [System.IO.Path]::GetFileName($f)
            foreach ($line in [System.IO.File]::ReadAllLines($f, $script:PwUtf8)) {
                $m = [regex]::Match($line, '^\s*(evidence_manifest|worktree_path):\s*(.*?)\s*$')
                if ($m.Success) {
                    Add-PwCitation -Found $found -Root $Root -File $rel -Field $m.Groups[1].Value -Value (Remove-PwQuotes $m.Groups[2].Value)
                }
            }
        }
    }
    $wd = [System.IO.Path]::Combine($Root, '.mission-runtime', 'lam', 'wake')
    if ([System.IO.Directory]::Exists($wd)) {
        $files = [string[]]@([System.IO.Directory]::GetFiles($wd) |
                             Where-Object { $_.EndsWith('.wake.json', [System.StringComparison]::OrdinalIgnoreCase) })
        [Array]::Sort($files, [System.StringComparer]::Ordinal)
        foreach ($f in $files) {
            $rel = '.mission-runtime/lam/wake/' + [System.IO.Path]::GetFileName($f)
            $text = [System.IO.File]::ReadAllText($f, $script:PwUtf8)
            foreach ($m in [regex]::Matches($text, '"worktree_path"\s*:\s*"((?:[^"\\]|\\.)*)"')) {
                $v = $m.Groups[1].Value
                try { $v = [regex]::Unescape($v) } catch { }
                Add-PwCitation -Found $found -Root $Root -File $rel -Field 'worktree_path' -Value $v
            }
        }
    }
    $found.ToArray()
}

function Select-PwCitations {
    param([object[]]$Citations, [string]$TreeFull)
    foreach ($c in @($Citations)) { if (Test-PwInside $c.Full $TreeFull) { $c } }
}

# ------------------------------------------------------------------------------------------------------- the modes --
function Get-PwSetFolder {
    param([string]$Root)
    if (-not $Set) { throw 'REFUSE: -Set <name> is required (one folder under .mission-runtime\scratch-copies\)' }
    if (($Set -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') -or $Set.Contains('..')) { throw ('REFUSE: -Set must be one plain folder name: ' + $Set) }
    return [System.IO.Path]::Combine($Root, '.mission-runtime', 'scratch-copies', $Set)
}

function Invoke-PwList {
    param([string]$Root, [object[]]$Worktrees)
    if (-not $Out) { throw 'REFUSE: -List needs -Out <file>' }
    if (-not $Tip) { throw 'REFUSE: -List needs -Tip <commit> (the ancestry target)' }
    if ($Set -and (($Set -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') -or $Set.Contains('..'))) { throw ('REFUSE: -Set must be one plain name: ' + $Set) }
    $picked = @(Resolve-PwTrees -Root $Root -Worktrees $Worktrees -Given $Trees)
    $outFull = Get-PwFullPath $Out
    if (-not $outFull) { throw ('REFUSE: -Out is not a path: ' + $Out) }
    if ([System.IO.File]::Exists($outFull) -or [System.IO.Directory]::Exists($outFull)) { throw ('REFUSE: the out file exists (exclusive create): ' + $outFull) }
    $parent = [System.IO.Path]::GetDirectoryName($outFull)
    if (-not [System.IO.Directory]::Exists($parent)) { throw ('REFUSE: the out file''s folder does not exist: ' + $parent) }
    foreach ($t in $picked) { if (Test-PwInside $outFull $t.Full) { throw ('REFUSE: the out file lies inside a listed tree: ' + $t.Name) } }
    $tipR = Invoke-PwGit @('-C', $Root, 'rev-parse', '--verify', '--quiet', ($Tip + '^{commit}'))
    $tip40 = $tipR.Out.Trim()
    if (($tipR.Code -ne 0) -or ($tip40 -notmatch '^[0-9a-f]{40}$')) { throw ('REFUSE: -Tip does not resolve to a commit: ' + $Tip) }
    $rootHead = (Invoke-PwGit @('-C', $Root, 'rev-parse', 'HEAD')).Out.Trim()
    $prefix = ''
    if ($Set) { $prefix = $Set + ' -- ' }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($prefix + 'THE PRUNE LISTING: every dirty path of the named linked worktrees BY FILE (git status --porcelain ' +
               '--untracked-files=all --ignored), with status code, bytes and sha256. Written by tools/lam/prune-worktrees.ps1 ' +
               'at HEAD ' + $rootHead + ', ' + (Format-PwClock ([DateTime]::UtcNow)) + '; ancestry against the tip ' + $tip40 + '.')
    $ledger = Read-PwLedger -Root $Root
    $cites = @(Get-PwCitations -Root $Root)
    $total = 0
    $summary = New-Object System.Collections.Generic.List[string]
    foreach ($t in $picked) {
        $script:PwWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:PwLaps = New-Object 'System.Collections.Generic.List[TimeSpan]'
        $e = $t.Entry
        $rc = (Invoke-PwGit @('-C', $Root, 'merge-base', '--is-ancestor', $e.Head, $tip40)).Code
        $tipEq = $false
        if ($t.Branch) {
            $bt = Invoke-PwGit @('-C', $Root, 'rev-parse', ('refs/heads/' + $t.Branch))
            $tipEq = ($bt.Code -eq 0) -and ($bt.Out.Trim() -ceq $e.Head)
        }
        Add-PwLap
        $walked = Measure-PwFiles $t.Full
        Add-PwLap
        $branchText = '(detached)'
        if ($t.Branch) { $branchText = $t.Branch }
        $lines.Add('== ' + $t.Name + ' | ' + $e.Path + ' | branch ' + $branchText + ' | HEAD ' + $e.Head +
                   ' | merge-base --is-ancestor HEAD ' + $tip40.Substring(0, 8) + ' exit ' + $rc +
                   ' | branch tip == the tree''s HEAD: ' + $tipEq + ' | files walked ' + $walked)
        foreach ($s in @(Get-PwSessionLines -Root $Root -Tree $t -Ledger $ledger)) { $lines.Add('   SESSION ' + $s) }
        foreach ($c in @(Select-PwCitations -Citations $cites -TreeFull $t.Full)) {
            $lines.Add('   CITED ' + $c.File + ' ' + $c.Field + ' -> ' + $c.Value)
        }
        Add-PwLap
        $rows = @(Get-PwEntryRows -TreeFull $t.Full)
        foreach ($r in $rows) { $lines.Add($r) }
        $total += $rows.Count
        Add-PwLap
        Write-PwElapsed -Name $t.Name -Entries $rows.Count
        $summary.Add($t.Name + ' ' + $branchText + ' HEAD ' + $e.Head.Substring(0, [math]::Min(8, $e.Head.Length)) +
                     ' ancestor-exit ' + $rc + ' entries ' + $rows.Count + ' walked ' + $walked)
    }
    $lines.Add('TOTAL: ' + $picked.Count + ' tree(s), ' + $total + ' entries')
    $bytes = $script:PwUtf8.GetBytes(($lines -join "`n") + "`n")
    try {
        $fs = [System.IO.File]::Open($outFull, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    } catch { throw ('REFUSE: the out file could not be created (exclusive create): ' + $outFull + ': ' + $_.Exception.Message) }
    try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
    foreach ($s in $summary) { Write-PwLine $s }
    Write-PwLine ('LISTING ' + $outFull + ': ' + $lines.Count + ' lines, ' + $bytes.Length + ' B, sha256 ' + (Get-PwShaHex $bytes) +
                  ', ' + $total + ' entries')
    return 0
}

function Invoke-PwCopy {
    param([string]$Root, [object[]]$Worktrees)
    $dest = Get-PwSetFolder -Root $Root
    $picked = @(Resolve-PwTrees -Root $Root -Worktrees $Worktrees -Given $Trees)
    if ([System.IO.Directory]::Exists($dest) -or [System.IO.File]::Exists($dest)) { throw ('REFUSE: the copy folder exists: ' + $dest) }
    $robo = @(Get-Command -Name 'robocopy' -CommandType Application -ErrorAction SilentlyContinue)
    if ($robo.Count -eq 0) { throw 'REFUSE: robocopy is not on PATH' }
    try { New-Item -ItemType Directory -Path $dest -ErrorAction Stop | Out-Null }
    catch { throw ('REFUSE: the copy folder could not be created: ' + $_.Exception.Message) }
    $script:PwActed = $true
    foreach ($t in $picked) {
        $r = Invoke-PwNative -File $robo[0].Source -Arguments @($t.Full, [System.IO.Path]::Combine($dest, $t.Name),
                                                              '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/XJ', '/NFL', '/NDL', '/NP')
        Write-PwNativeOutput $r
        Write-PwLine ('robocopy ' + $t.Name + ' exit ' + $r.Code)
        if ($r.Code -ge 8) {
            Write-PwLine ('STOP: robocopy ' + $t.Name + ' exit ' + $r.Code + ' -- 8 or above is a failure; the trees after it are not copied')
            return 8
        }
    }
    Write-PwLine ('COPIED ' + $picked.Count + ' tree(s) into ' + $dest)
    return 0
}

function Invoke-PwVerify {
    param([string]$Root)
    if (-not $Listing) { throw 'REFUSE: -Verify needs -Listing <file>' }
    $lp = Get-PwFullPath $Listing
    if ((-not $lp) -or (-not [System.IO.File]::Exists($lp))) { throw ('REFUSE: the listing is not a file: ' + $Listing) }
    $dest = $null
    if ($DryRun) {
        if ($Set) { throw 'REFUSE: -DryRun reads the SOURCE trees; -Set is not taken with it' }
    } else {
        $dest = Get-PwSetFolder -Root $Root
        if (-not [System.IO.Directory]::Exists($dest)) { throw ('REFUSE: no copy at ' + $dest + ' (-Copy first, or -DryRun against the source trees)') }
    }
    $parsed = Read-PwListing -Path $lp
    if ($parsed.Trees.Count -eq 0) { throw ('REFUSE: the listing names no tree: ' + $lp) }
    $stop = $false
    $base = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    foreach ($t in $parsed.Trees) {
        $src = Get-PwFullPath $t.Path
        if ($DryRun) { $base[$t.Name] = $src; continue }
        $copyDir = [System.IO.Path]::Combine($dest, $t.Name)
        $base[$t.Name] = $copyDir
        $s = Measure-PwFiles $src
        $c = Measure-PwFiles $copyDir
        Write-PwLine ($t.Name + ' ' + $s + ' = ' + $c + ' ' + ($s -eq $c))
        if ($s -ne $c) { $stop = $true }
    }
    $started = [DateTime]::UtcNow
    Write-PwLine ('STARTED ' + (Format-PwClock $started))
    $n = 0
    $miss = 0
    $bad = 0
    foreach ($e in $parsed.Entries) {
        $n++
        $tn = ''
        if ($null -ne $e[0]) { $tn = $e[0].Name }
        $p = $null
        if ($tn -and $base.ContainsKey($tn) -and $base[$tn]) {
            try { $p = [System.IO.Path]::Combine($base[$tn], ($e[2] -replace '/', '\')) } catch { $p = $null }
        }
        if ((-not $p) -or (-not [System.IO.File]::Exists($p))) { $miss++; Write-PwLine ('MISSING ' + $tn + ' ' + $e[2]); continue }
        $ok = $false
        try { $d = Get-PwDigest $p; $ok = ($d.Bytes -eq $e[3]) -and ($d.Sha -ceq $e[4]) } catch { $ok = $false }
        if (-not $ok) { $bad++; Write-PwLine ('MISMATCH ' + $tn + ' ' + $p) }
    }
    Write-PwLine ('listed ' + $n + '; missing ' + $miss + '; mismatched ' + $bad)
    $ended = [DateTime]::UtcNow
    Write-PwLine ('ENDED ' + (Format-PwClock $ended) + ' ELAPSED ' + [math]::Round(($ended - $started).TotalSeconds, 3) + ' s')
    if ($miss -or $bad) { $stop = $true }
    if ($stop) {
        $what = 'the copy'
        if ($DryRun) { $what = 'the source trees' }
        Write-PwLine ('STOP: ' + $what + ' do not hold the listing -- remove nothing')
        return 3
    }
    return 0
}

function Invoke-PwRemove {
    param([string]$Root, [object[]]$Worktrees)
    $picked = @(Resolve-PwTrees -Root $Root -Worktrees $Worktrees -Given $Trees)
    $given = @(Split-PwList $ConfirmRemove)
    if ($given.Count -eq 0) {
        throw 'REFUSE: -Remove needs -ConfirmRemove <tree>@<HEAD8>[@<citing file>...] for every tree; nothing is removed without it'
    }
    $confirm = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($c in $given) {
        $parts = $c.Split('@')
        if (($parts.Count -lt 2) -or (-not $parts[0]) -or ($parts[1] -notmatch '^[0-9a-fA-F]{8}$')) {
            throw ('REFUSE: a confirmation is not <tree>@<HEAD8>[@<citing file>...]: ' + $c)
        }
        if ($confirm.ContainsKey($parts[0])) { throw ('REFUSE: ' + $parts[0] + ' is confirmed twice') }
        $cited = @()
        if ($parts.Count -gt 2) { $cited = @($parts[2..($parts.Count - 1)] | ForEach-Object { $_.Trim() -replace '\\', '/' }) }
        $confirm[$parts[0]] = [pscustomobject]@{ Head8 = $parts[1].ToLowerInvariant(); Cited = $cited }
    }
    $names = @($picked | ForEach-Object { $_.Name })
    foreach ($k in @($confirm.Keys)) { if ($names -notcontains $k) { throw ('REFUSE: a confirmation names ' + $k + ', which -Trees does not') } }
    $cites = @(Get-PwCitations -Root $Root)
    $why = New-Object System.Collections.Generic.List[string]
    foreach ($t in $picked) {
        if (-not $confirm.ContainsKey($t.Name)) { $why.Add($t.Name + ': no -ConfirmRemove entry'); continue }
        $c = $confirm[$t.Name]
        $h8 = $t.Entry.Head.Substring(0, [math]::Min(8, $t.Entry.Head.Length)).ToLowerInvariant()
        if ($c.Head8 -cne $h8) { $why.Add($t.Name + ': confirmed at HEAD ' + $c.Head8 + ' but its HEAD is ' + $h8 + ' -- the tree moved') }
        if ($null -ne $t.Entry.Locked) { $why.Add($t.Name + ': git holds it locked (' + $t.Entry.Locked + ')') }
        $mine = @(Select-PwCitations -Citations $cites -TreeFull $t.Full)
        $files = New-Object System.Collections.Generic.List[string]
        foreach ($m in $mine) { if (-not $files.Contains($m.File)) { $files.Add($m.File) } }
        $missing = @($files | Where-Object { $c.Cited -notcontains $_ })
        $stale = @($c.Cited | Where-Object { $files -notcontains $_ })
        if ($missing.Count -or $stale.Count) {
            if ($missing.Count) { $why.Add($t.Name + ': CITED -- its confirmation must name every citing file after the HEAD (ruling Q6); not named: ' + ($missing -join ', ')) }
            if ($stale.Count) { $why.Add($t.Name + ': its confirmation names a file that cites nothing in it: ' + ($stale -join ', ')) }
            foreach ($m in $mine) { $why.Add('   CITED ' + $m.File + ' ' + $m.Field + ' -> ' + $m.Value) }
        }
    }
    if ($why.Count -gt 0) {
        foreach ($w in $why) { Write-PwLine $w }
        throw ('REFUSE: the confirmations do not hold (above); no tree is removed')
    }
    $script:PwActed = $true
    $finding = $false
    foreach ($t in $picked) {
        $r = Invoke-PwGit @('-C', $Root, 'worktree', 'remove', '--force', $t.Entry.Path)
        Write-PwNativeOutput $r
        Write-PwLine ('remove ' + $t.Name + ' exit ' + $r.Code)
        if ($r.Code -ne 0) {
            Write-PwLine ('FINDING: git worktree remove refused ' + $t.Name + ' (exit ' + $r.Code + '); the loop stops here')
            $finding = $true
            break
        }
        if (-not $t.Branch) { Write-PwLine ('branch -d ' + $t.Name + ': a detached HEAD, no branch to delete'); continue }
        $b = Invoke-PwGit @('-C', $Root, 'branch', '-d', $t.Branch)
        Write-PwNativeOutput $b
        Write-PwLine ('branch -d ' + $t.Branch + ' exit ' + $b.Code)
        if ($b.Code -ne 0) {
            Write-PwLine ('FINDING: git branch -d ' + $t.Branch + ' refused (exit ' + $b.Code + '); the branch is left and the loop stops here')
            $finding = $true
            break
        }
    }
    $pr = Invoke-PwGit @('-C', $Root, 'worktree', 'prune')
    Write-PwNativeOutput $pr
    Write-PwLine ('worktree prune exit ' + $pr.Code)
    if ($pr.Code -ne 0) { Write-PwLine 'FINDING: git worktree prune failed'; $finding = $true }
    Write-PwNativeOutput (Invoke-PwGit @('-C', $Root, '--no-pager', 'worktree', 'list'))
    $after = Invoke-PwGit @('-C', $Root, 'worktree', 'list', '--porcelain', '-z')
    if ($after.Code -ne 0) { Write-PwLine 'FINDING: git worktree list failed after the prune'; $finding = $true }
    foreach ($e in @(ConvertFrom-PwPorcelain -Text $after.Out)) {
        if ($null -ne $e.Prunable) {
            Write-PwLine ('FINDING: a prunable registration is left: ' + $e.Path + ' (' + $e.Prunable + ')')
            $finding = $true
        }
    }
    if ($finding) { return 4 }
    return 0
}

function Invoke-PwMode {
    if ([Console]::IsOutputRedirected) { try { [Console]::OutputEncoding = $script:PwUtf8 } catch { } }
    $modes = @()
    if ($List) { $modes += 'List' }
    if ($Copy) { $modes += 'Copy' }
    if ($Verify) { $modes += 'Verify' }
    if ($Remove) { $modes += 'Remove' }
    if ($modes.Count -ne 1) {
        $given = 'none'
        if ($modes.Count) { $given = '-' + ($modes -join ', -') }
        throw ('REFUSE: exactly one mode is taken -- -List, -Copy, -Verify or -Remove; given ' + $given)
    }
    $mode = $modes[0]
    $allowed = @{
        'List'   = @('MissionRoot', 'List', 'Out', 'Trees', 'Tip', 'Set')
        'Copy'   = @('MissionRoot', 'Copy', 'Set', 'Trees')
        'Verify' = @('MissionRoot', 'Verify', 'Listing', 'Set', 'DryRun')
        'Remove' = @('MissionRoot', 'Remove', 'Trees', 'ConfirmRemove')
    }
    $common = @([System.Management.Automation.PSCmdlet]::CommonParameters)
    $extra = @(@($script:PwBound.Keys) | Where-Object { ($allowed[$mode] -notcontains $_) -and ($common -notcontains $_) })
    if ($extra.Count) { throw ('REFUSE: -' + ($extra -join ', -') + ' is not taken by -' + $mode) }
    if (-not $MissionRoot) { throw 'REFUSE: -MissionRoot <the primary checkout> is required' }
    $root = Get-PwFullPath $MissionRoot
    if ((-not $root) -or (-not [System.IO.Directory]::Exists($root))) { throw ('REFUSE: the mission root is not a folder: ' + $MissionRoot) }
    $wl = Invoke-PwGit @('-C', $root, 'worktree', 'list', '--porcelain', '-z')
    if ($wl.Code -ne 0) { throw ('REFUSE: git worktree list failed in ' + $root + ': ' + $wl.Err.Trim()) }
    $wt = @(ConvertFrom-PwPorcelain -Text $wl.Out)
    if (($wt.Count -eq 0) -or (-not (Test-PwSamePath (Get-PwFullPath $wt[0].Path) $root))) {
        $named = 'none'
        if ($wt.Count) { $named = $wt[0].Path }
        throw ('REFUSE: -MissionRoot must be the primary checkout (git names ' + $named + ')')
    }
    if ($mode -ceq 'List') { return (Invoke-PwList -Root $root -Worktrees $wt) }
    if ($mode -ceq 'Copy') { return (Invoke-PwCopy -Root $root -Worktrees $wt) }
    if ($mode -ceq 'Verify') { return (Invoke-PwVerify -Root $root) }
    return (Invoke-PwRemove -Root $root -Worktrees $wt)
}

function Invoke-PwMain {
    try {
        return (Invoke-PwMode)
    } catch {
        $msg = [string]$_.Exception.Message
        if ($msg.StartsWith('REFUSE: ', [System.StringComparison]::Ordinal)) {
            Write-PwLine ('REFUSED: ' + $msg.Substring(8) + ' -- nothing was done.')
            return 2
        }
        Write-PwLine ('ERROR: ' + $msg)
        if ($Remove -and $script:PwActed) { return 4 }
        if ($Copy -and $script:PwActed) { return 8 }
        if ($Verify) { return 3 }
        return 2
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $script:PwBound = $PSBoundParameters
    $rc = @(Invoke-PwMain)
    exit ([int]$rc[$rc.Count - 1])
}
