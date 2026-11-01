#Requires -Version 5.1
# =================================================================================================
# lam-auth-mode.ps1 -- THE AUTHENTICATION MODE A SPAWN OF THE CLAUDE CODE CLI RUNS UNDER
# =================================================================================================
# ONE ENVIRONMENT VARIABLE SELECTS IT, VANGUARD_AUTH_MODE, and its absence is the default:
#   unset or empty  nothing is checked and nothing changes. The runner and the wake starter do not load this file,
#                   and the CLI they start authenticates by Claude Code's own precedence: with the Claude subscription
#                   it is signed in with only when no credential is in the environment -- an ANTHROPIC_API_KEY, a bearer
#                   token (ANTHROPIC_AUTH_TOKEN, CLAUDE_CODE_OAUTH_TOKEN) or a cloud-provider selector
#                   (CLAUDE_CODE_USE_BEDROCK, _VERTEX, _FOUNDRY) left in the shell is used instead. Only the
#                   first-generation worker-runner removes ANTHROPIC_API_KEY (tools/worker-runner/env_scrub.py). Set
#                   subscription to have such a credential refused.
#   api-key         the CLI bills the Anthropic API key in ANTHROPIC_API_KEY, the provider's own variable, which print
#                   mode uses whenever it is present. The key travels in the child's ENVIRONMENT only: the caller passes
#                   its environment to the child as it always has, and this file refuses a key-shaped value in an
#                   argument of the spawn or in a file the spawn hands the CLI.
#   subscription    the subscription, claimed out loud: a key, a bearer token or a cloud-provider selector beside it is
#                   refused, since print mode would use that instead (the subscription's own CLAUDE_CODE_OAUTH_TOKEN
#                   excepted).
# Anything else is refused. The variable is never sniffed for: a credential in the environment with VANGUARD_AUTH_MODE
# unset changes nothing this framework does. The reason texts below that say to unset the variable "for the Claude
# subscription" mean the default above, which is the subscription only when no credential is in the environment.
#
# CONTENT-BLIND. A credential variable is read for one thing, whether it is set and not empty; its value is never
# printed, logged, compared, captured or hashed. A key-shaped value is found by its shape alone -- 'sk-ant-' and 20 or
# more of [A-Za-z0-9_-] -- and a refusal names an argument by its index and a file by its path and line, never what
# matched. Even the selector's own value is not echoed when it is refused.
#
# A DECISION is { ok; selected; mode; code; reason }. The codes:
#   AUTH-MODE-UNKNOWN          VANGUARD_AUTH_MODE is neither api-key nor subscription
#   AUTH-MODE-KEY-ABSENT       api-key, and ANTHROPIC_API_KEY is not set or is empty
#   AUTH-MODE-BOTH-CLAIMED     api-key beside another credential the CLI would use instead of the key or beside it; or
#                              subscription beside a key, a token or a selector print mode would use instead of it --
#                              in the environment, or (subscription) in a settings file the session loads
#   AUTH-MODE-KEY-IN-ARGUMENT  key mode: an argument of the spawn carries a key-shaped value
#   AUTH-MODE-KEY-IN-FILE      key mode: a file the spawn hands the CLI, or one the CLI loads at the root of the tree it
#                              runs in (Get-LamAuthSessionFiles and Get-LamAuthSettingsFiles on disk; for a tree not yet
#                              cut, Get-LamAuthCommittedFiles reads them as the commit it is cut at holds them, in any
#                              letter case), carries one, or a settings file names a credential setting (apiKeyHelper,
#                              or one of the variables above in its env block)
# The runner adds one of its own, AUTH-MODE-UNREADABLE: the variable is set and this file is not loaded, or the files
# the commit its tree is cut at holds cannot be read (Get-LamAuthCommittedFiles throws), so the mode cannot be decided.
# A reason names what was refused and why, never what its caller did or did not start: each caller says that.
# Nothing is printed for a mode that is admitted -- in either mode a run prints what it prints without the variable.
# Loaded by tools/lam/mission-dispatch.ps1 and tools/lam/lam-wake.ps1, each only when VANGUARD_AUTH_MODE is set. Where
# the key goes once it is in the environment: to every child the caller starts, as every other variable of the shell
# does -- the CLI among them, and whatever else the caller runs (the runner's verify gate and the suite it runs) --
# and the CLI hands it on to the tools and hooks it starts. This file puts it in no argument, file or record.

$script:LamAuthModeVariable = 'VANGUARD_AUTH_MODE'
$script:LamAuthKeyVariable = 'ANTHROPIC_API_KEY'
$script:LamAuthKeyShape = 'sk-ant-[A-Za-z0-9_-]{20,}'
# Beside a key: a bearer token and a cloud-provider selector are used BEFORE ANTHROPIC_API_KEY, and the OAuth token is a
# subscription's. Beside the subscription: each of these is used before it in print mode.
$script:LamAuthBesideKey = @('ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')
$script:LamAuthBesideSubscription = @('ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')
$script:LamAuthSettingNames = @('apiKeyHelper', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')
# Under subscription a settings file may name the subscription's own OAuth token; every other credential setting is one
# print mode would use instead of the subscription.
$script:LamAuthSubscriptionSettingNames = @('apiKeyHelper', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')
# The files the CLI reads by itself at the root of the tree it runs in when a session starts: its memory files and its
# project MCP configuration (the .claude settings are held as settings files besides). A parent folder's and the user's
# own are outside what a spawn hands the CLI, and are not examined.
$script:LamAuthSessionFileNames = @('CLAUDE.md', 'CLAUDE.local.md', '.claude\CLAUDE.md', '.mcp.json')
# The project settings the CLI loads from that root.
$script:LamAuthSettingsFileNames = @('.claude\settings.json', '.claude\settings.local.json')

function Test-LamAuthVariableSet {
    # Set and not empty, in this process's environment -- the one a child inherits. Nothing else is asked of it.
    param([string]$Name)
    return (-not [string]::IsNullOrEmpty([System.Environment]::GetEnvironmentVariable($Name, 'Process')))
}

function New-LamAuthDecision {
    param([bool]$Ok, [string]$Mode, [string]$Code, [string]$Reason)
    return [pscustomobject]@{ ok = $Ok; selected = $true; mode = $Mode; code = $Code; reason = $Reason }
}

function Get-LamAuthMode {
    # The mode VANGUARD_AUTH_MODE selects, held against the credentials the environment carries, by presence only.
    $selector = [System.Environment]::GetEnvironmentVariable($script:LamAuthModeVariable, 'Process')
    if ([string]::IsNullOrEmpty($selector)) {
        return [pscustomobject]@{ ok = $true; selected = $false; mode = ''; code = ''; reason = 'VANGUARD_AUTH_MODE is not set: the CLI authenticates as Claude Code is signed in' }
    }
    if ($selector -ceq 'api-key') {
        if (-not (Test-LamAuthVariableSet $script:LamAuthKeyVariable)) {
            return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-KEY-ABSENT' ('VANGUARD_AUTH_MODE is api-key and ANTHROPIC_API_KEY is not set or is empty. Set ANTHROPIC_API_KEY in the environment of the shell that runs this -- never in a file or an argument -- or unset VANGUARD_AUTH_MODE for the Claude subscription.')
        }
        $beside = @($script:LamAuthBesideKey | Where-Object { Test-LamAuthVariableSet $_ })
        if ($beside.Count -gt 0) {
            return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-BOTH-CLAIMED' ('VANGUARD_AUTH_MODE is api-key and ' + ($beside -join ', ') + ' is set too: the CLI would use that instead of the key, or beside it. Unset it for key mode.')
        }
        return New-LamAuthDecision $true 'api-key' '' 'ANTHROPIC_API_KEY is set (its value is never read here) and no other credential is; the CLI is handed it in its environment and nowhere else'
    }
    if ($selector -ceq 'subscription') {
        $beside = @($script:LamAuthBesideSubscription | Where-Object { Test-LamAuthVariableSet $_ })
        if ($beside.Count -gt 0) {
            return New-LamAuthDecision $false 'subscription' 'AUTH-MODE-BOTH-CLAIMED' ('VANGUARD_AUTH_MODE is subscription and ' + ($beside -join ', ') + ' is set: in print mode the CLI uses that instead of the subscription. Unset it, or set VANGUARD_AUTH_MODE to api-key.')
        }
        return New-LamAuthDecision $true 'subscription' '' 'no API key, bearer token or cloud-provider selector is set; the CLI authenticates with the Claude subscription it is signed in with'
    }
    return New-LamAuthDecision $false '' 'AUTH-MODE-UNKNOWN' 'VANGUARD_AUTH_MODE is set to a value that is neither api-key nor subscription (the value is not shown). Set one of the two, or unset it for the Claude subscription.'
}

function Get-LamAuthShapeLine {
    # The 1-based line of a text on which the first key-shaped value stands; 0 where none does. The match is not kept.
    param([string]$Text)
    $m = [regex]::Match($Text, $script:LamAuthKeyShape)
    if (-not $m.Success) { return 0 }
    return 1 + ($Text.Substring(0, $m.Index).Length - $Text.Substring(0, $m.Index).Replace("`n", '').Length)
}

function Get-LamAuthFileText {
    # A file's bytes, its NUL bytes dropped, read one character a byte (ISO 8859-1): an ASCII shape shows through UTF-8,
    # ANSI and UTF-16 alike.
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return [System.Text.Encoding]::GetEncoding(28591).GetString([byte[]]@($bytes -ne 0))
}

function Get-LamAuthSessionFiles {
    # The session files of the tree rooted at -Root, by path; whether each exists is the scan's to see.
    param([string]$Root)
    return @($script:LamAuthSessionFileNames | ForEach-Object { Join-Path $Root $_ })
}

function Get-LamAuthSettingsFiles {
    # The .claude settings of the tree rooted at -Root, by path; whether each exists is the scan's to see.
    param([string]$Root)
    return @($script:LamAuthSettingsFileNames | ForEach-Object { Join-Path $Root $_ })
}

function Invoke-LamAuthGit {
    # git -C <Repo> <Arguments>, its output read as bytes (never decoded by the console): { exit; bytes }. A git that
    # cannot be started throws.
    param([string]$Repo, [string]$Arguments)
    $r = $Repo
    if ($r.EndsWith('\')) { $r += '\' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = '-C "' + $r + '" ' + $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $err = $proc.StandardError.ReadToEndAsync()
    $ms = New-Object System.IO.MemoryStream
    $proc.StandardOutput.BaseStream.CopyTo($ms)
    $proc.WaitForExit()
    [void]$err.Result
    return [pscustomobject]@{ exit = $proc.ExitCode; bytes = $ms.ToArray() }
}

function Get-LamAuthTreeEntries {
    # The entries of one tree of the repository at -Repo -- a commit's root, or a tree by its object id -- listed once,
    # with no pathspec: { mode; type; oid; name }, each name as the tree holds it. A tree git cannot list throws, as a git
    # that cannot be started does: the caller cannot then say what the tree carries.
    param([string]$Repo, [string]$Tree)
    $listed = Invoke-LamAuthGit -Repo $Repo -Arguments ('ls-tree -z --full-tree "' + $Tree + '"')
    if ($listed.exit -ne 0) { throw ('git cannot list the tree ' + $Tree) }
    $entries = @()
    foreach ($record in ([System.Text.Encoding]::UTF8.GetString($listed.bytes)).Split([char]0)) {
        if (-not $record) { continue }
        $tab = $record.IndexOf([char]9)
        $meta = @()
        if ($tab -gt 0) { $meta = @($record.Substring(0, $tab).Split(' ')) }
        if ($meta.Count -ne 3) { throw ('git listed the tree ' + $Tree + ' in a form this file does not read') }
        $entries += [pscustomobject]@{ mode = $meta[0]; type = $meta[1]; oid = $meta[2]; name = $record.Substring($tab + 1) }
    }
    return $entries
}

function Add-LamAuthCommittedText {
    # Every entry of -In ({ entry; prefix }) whose name is -Leaf but for letter case -- ordinal-ignore-case, ASCII, the
    # letter case a case-insensitive checkout folds onto these names -- and which is a file, read by its object id into
    # -Into under '<path as the commit spells it> as commit <Short> holds it'. A folder or a submodule there is no file
    # the CLI reads, and is passed over. A blob git cannot read throws. -Into's keys ignore letter case, so a second
    # spelling of one path carries its object id.
    param([object[]]$In, [string]$Leaf, [System.Collections.IDictionary]$Into, [string]$Repo, [string]$Rev, [string]$Short)
    foreach ($x in @($In)) {
        $e = $x.entry
        if (-not [string]::Equals($e.name, $Leaf, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($e.type -cne 'blob') { continue }
        $path = $x.prefix + $e.name
        $blob = Invoke-LamAuthGit -Repo $Repo -Arguments ('cat-file blob ' + $e.oid)
        if ($blob.exit -ne 0) { throw ('commit ' + $Rev + ' names ' + $path + ' and git cannot read it') }
        $key = $path + ' as commit ' + $Short + ' holds it'
        if ($Into.Contains($key)) { $key += ' (object ' + $e.oid.Substring(0, 12) + ')' }
        $Into[$key] = [System.Text.Encoding]::GetEncoding(28591).GetString([byte[]]@($blob.bytes -ne 0))
    }
}

function Get-LamAuthCommittedFiles {
    # The session files and the .claude settings as commit -Rev of the repository at -Repo holds them: what a tree cut
    # there carries at its root before anything is placed into it, in any letter case, as a case-insensitive checkout
    # gives them to the CLI. The commit's root is listed once, and so is every root folder whose name is
    # .claude but for letter case; every file whose name is a session or settings file's but for letter case is read --
    # a folder or a submodule at such a name is no file. { texts; settings }, each an ordered map of '<path> as commit
    # <sha12> holds it' to the file's text, in Test-LamAuthSpawnInputs' -Texts and -SettingsTexts form. Under -Mode
    # subscription the memory files and .mcp.json are not read: the scan holds the settings only. A file the commit does
    # not hold is left out; a tree git cannot list, or a file it cannot read, throws. Nothing is written.
    param([string]$Repo, [string]$Rev, [ValidateSet('api-key', 'subscription')][string]$Mode = 'api-key')
    $short = if ($Rev.Length -gt 12) { $Rev.Substring(0, 12) } else { $Rev }
    $root = @(Get-LamAuthTreeEntries -Repo $Repo -Tree $Rev | ForEach-Object { [pscustomobject]@{ entry = $_; prefix = '' } })
    $dot = @()
    foreach ($x in $root) {
        if (($x.entry.type -ceq 'tree') -and [string]::Equals($x.entry.name, '.claude', [System.StringComparison]::OrdinalIgnoreCase)) {
            $dot += @(Get-LamAuthTreeEntries -Repo $Repo -Tree $x.entry.oid | ForEach-Object { [pscustomobject]@{ entry = $_; prefix = $x.entry.name + '/' } })
        }
    }
    $texts = [ordered]@{}
    if ($Mode -ceq 'api-key') {
        foreach ($n in $script:LamAuthSessionFileNames) {
            if ($n.StartsWith('.claude\')) { Add-LamAuthCommittedText -In $dot -Leaf $n.Substring(8) -Into $texts -Repo $Repo -Rev $Rev -Short $short }
            else { Add-LamAuthCommittedText -In $root -Leaf $n -Into $texts -Repo $Repo -Rev $Rev -Short $short }
        }
    }
    $settings = [ordered]@{}
    foreach ($n in $script:LamAuthSettingsFileNames) {
        Add-LamAuthCommittedText -In $dot -Leaf $n.Substring(8) -Into $settings -Repo $Repo -Rev $Rev -Short $short
    }
    return [pscustomobject]@{ texts = $texts; settings = $settings }
}

function Test-LamAuthSpawnInputs {
    # -Mode api-key (the default): no argument of the spawn and no file it hands the CLI carries a key-shaped value, and
    # no settings file names a credential setting. -Mode subscription: only the settings files are read, and a credential
    # setting or a key-shaped value in one is the subscription claimed beside another credential (the subscription's own
    # OAuth token excepted). -Arguments the argv; -Texts @{ <what it is> = <text> } for what is not a file on disk (a
    # prompt piped on stdin, a file as a commit holds it); -Files the files handed over and those the CLI loads at its
    # root; -SettingsFiles those that are settings JSON; -SettingsTexts settings JSON that is not a file on disk, in -Texts'
    # form. A file that is not there is skipped: the CLI reads nothing from it.
    param([string[]]$Arguments = @(), [System.Collections.IDictionary]$Texts = @{}, [string[]]$Files = @(), [string[]]$SettingsFiles = @(),
          [System.Collections.IDictionary]$SettingsTexts = @{}, [ValidateSet('api-key', 'subscription')][string]$Mode = 'api-key')
    $settingsRead = @()
    foreach ($f in @($SettingsFiles)) {
        if ((-not $f) -or (-not (Test-Path -LiteralPath $f -PathType Leaf))) { continue }
        $settingsRead += [pscustomobject]@{ what = $f; text = (Get-LamAuthFileText -Path $f) }
    }
    foreach ($what in @($SettingsTexts.Keys)) { $settingsRead += [pscustomobject]@{ what = [string]$what; text = [string]$SettingsTexts[$what] } }
    if ($Mode -ceq 'subscription') {
        foreach ($s in $settingsRead) {
            $named = @($script:LamAuthSubscriptionSettingNames | Where-Object { $s.text.Contains('"' + $_ + '"') })
            if (($named.Count -gt 0) -or [regex]::IsMatch($s.text, $script:LamAuthKeyShape)) {
                return New-LamAuthDecision $false 'subscription' 'AUTH-MODE-BOTH-CLAIMED' ($s.what + ' ' + $(if ($named.Count) { 'names the credential setting ' + $named[0] } else { 'carries a key-shaped value (not shown)' }) + ', and the session loads that settings file: with VANGUARD_AUTH_MODE=subscription the CLI would use it instead of the subscription. Remove it, or set VANGUARD_AUTH_MODE to api-key.')
            }
        }
        return New-LamAuthDecision $true 'subscription' '' 'no API key, bearer token or cloud-provider selector is set, and no settings file the session loads names a credential setting; the CLI authenticates with the Claude subscription it is signed in with'
    }
    for ($i = 0; $i -lt @($Arguments).Count; $i++) {
        if ([regex]::IsMatch([string]$Arguments[$i], $script:LamAuthKeyShape)) {
            return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-KEY-IN-ARGUMENT' ('argument ' + $i + ' of the spawn carries a key-shaped value (not shown). In key mode the key travels in the environment only.')
        }
    }
    foreach ($what in @($Texts.Keys)) {
        $line = Get-LamAuthShapeLine -Text ([string]$Texts[$what])
        if ($line -gt 0) {
            return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-KEY-IN-FILE' ('the ' + $what + ' carries a key-shaped value at its line ' + $line + ' (not shown). In key mode the key travels in the environment only.')
        }
    }
    foreach ($f in @($Files)) {
        if ((-not $f) -or (-not (Test-Path -LiteralPath $f -PathType Leaf))) { continue }
        $line = Get-LamAuthShapeLine -Text (Get-LamAuthFileText -Path $f)
        if ($line -gt 0) {
            return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-KEY-IN-FILE' ($f + ' carries a key-shaped value at its line ' + $line + ' (not shown), and the CLI would read that file. In key mode the key travels in the environment only.')
        }
    }
    foreach ($s in $settingsRead) {
        $line = Get-LamAuthShapeLine -Text $s.text
        if ($line -gt 0) {
            return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-KEY-IN-FILE' ($s.what + ' carries a key-shaped value at its line ' + $line + ' (not shown), and the CLI would load that settings file. In key mode the key travels in the environment only.')
        }
        foreach ($name in $script:LamAuthSettingNames) {
            if ($s.text.Contains('"' + $name + '"')) {
                return New-LamAuthDecision $false 'api-key' 'AUTH-MODE-KEY-IN-FILE' ($s.what + ' names the credential setting ' + $name + ', and the CLI would load that settings file. In key mode the key travels in the environment only.')
            }
        }
    }
    return New-LamAuthDecision $true 'api-key' '' 'no argument of the spawn and no file it hands the CLI carries a key-shaped value or names a credential setting'
}
