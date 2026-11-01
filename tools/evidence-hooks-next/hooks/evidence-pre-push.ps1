#Requires -Version 5.1
<#
.SYNOPSIS
  THE DECIDER. LAM-ACCEPT T-2 as amended by amendment 19.

.DESCRIPTION
  WHY THIS LAYER EXISTS, AND WHY IT IS NOT ANOTHER TEXT MATCHER.

  T-2 used to say a push "is hook-blocked unless" a gate authorizes it, and the PreToolUse guard was
  asked to keep that promise by reading command TEXT. Three consecutive V-1 rounds refuted it, each
  on a spelling the previous cure could not reach and each driven to a real publication of an ungated
  origin:

      round 9   $VAR, ANSI-C $'\x70ush', quoted GIT_DIR, pushd
      round 10  brace expansion, backslash-newline, git ALIASES, Set-Location/sl/Push-Location
      round 11  g\it push, gi\t push, $G push, ${G} push, xargs git,
                PowerShell & (Get-Command git).Source push

  Round 10's inversion closed the SUBCOMMAND question, because "given this is git, is the subcommand
  a push" has an enumerable answer. Round 11 refuted the EXECUTABLE question, which does not: a
  variable, a substitution, a pipe into xargs, a call operator over a resolved path, a wrapper, a
  renamed binary. There is no finite set to invert against.

  GIT ALREADY KNOWS THE ANSWER. By the time this hook runs, every expansion has happened and git
  hands us, on stdin, the real local ref, the real sha it is about to publish, the real remote ref,
  and what the remote currently holds -- one line per ref:

      <local ref> SP <local sha> SP <remote ref> SP <remote sha> LF

  So spelling is irrelevant here. `$G push`, `xargs git`, an alias, a wrapper script: all of them
  arrive at this hook as the same four fields. This is the strongest LOCAL layer -- NOT a boundary,
  and no longer described as one (LAM-ACCEPT T-2, amendment 20 retracted that wording). It is skipped
  by `git push --no-verify`, by `core.hooksPath` pointed elsewhere, and by any publication that does
  not take git's ref-push path. What it does is refuse what it CAN see, at the point where spelling
  has stopped mattering, and
  the tripwire keeps doing the job it can actually do -- refusing what it can read, and
  recording every attempt.

  FAIL-CLOSED IN EVERY DIRECTION IT CANNOT ANSWER. If the repository root cannot be resolved, if a
  ref is being DELETED (no sha exists for a gate to bind), or if any single ref in a multi-ref push
  lacks an authorization, the whole push is refused. Git aborts on a non-zero exit, so a refusal here
  stops the publication rather than annotating it afterwards.

  IT ALSO WITNESSES, WHICH IS WHAT MAKES CONSUMPTION HONEST. After allowing, it writes an in-flight
  record naming the gate, the authorized sha, the remote and what the remote held BEFORE. Consumption
  then requires that record AND the remote observed at the authorized sha -- so a command that
  published nothing can never spend a gate. `git lfs env` used to do exactly that.

.NOTES
  Installed as `.git/hooks/pre-push` via a fixed one-line wrapper whose sha256 the runner and
  WP-4 both verify. Do not put logic in the wrapper; it lives here, where it is a tracked file.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$RemoteName,
    [Parameter(Position = 1)][string]$RemoteUrl
)

$ErrorActionPreference = 'Stop'
$ZERO = '0000000000000000000000000000000000000000'

function Deny {
    param([string]$Message)
    # Git shows the hook's stderr to the user verbatim, so the refusal explains itself at the point
    # of refusal rather than in a log nobody reads.
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("PUSH REFUSED by the LAM pre-push decider (LAM-ACCEPT T-2, amendment 19).")
    [Console]::Error.WriteLine($Message)
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("A publication is authorized by a `push` gate an operator creates, bound to the exact")
    [Console]::Error.WriteLine("sha being published. Mint one with:  tools/lam/mission-gate.ps1 approve -Kind push -Id <id>")
    [Console]::Error.WriteLine("  -Binds <artifact> -MissionRoot <repo> -TipSha <sha>")
    exit 1
}

try {
    . (Join-Path $PSScriptRoot 'lib\evidence-common.ps1')
} catch {
    Deny "the guard library could not be loaded ($($_.Exception.Message)), so no authorization could be checked. Refusing rather than guessing."
}

# WHERE ARE WE? Git runs a hook with the working directory at the top level of the repository being
# pushed, but that is not relied on blindly -- it is asked and refused if unanswerable.
$root = $null
try {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $s = & git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -eq 0) { $root = ("$s").Trim() }
    } finally { $ErrorActionPreference = $prev }
} catch { $root = $null }
if (-not $root) { Deny "the repository root could not be resolved, so no gate directory could be read." }

# EVERY REF IN THE PUSH IS CHECKED, NOT THE FIRST. `git push --all`, or a refspec naming two
# branches, arrives as several lines; authorizing one and publishing the rest is the same
# one-of-a-class defect this build has recorded repeatedly.
$lines = @()
try {
    $stdin = [Console]::In.ReadToEnd()
    foreach ($l in ($stdin -split "`n")) { if ($l.Trim()) { $lines += $l.Trim() } }
} catch { $lines = @() }

if ($lines.Count -eq 0) {
    # NOTHING ON STDIN MEANS NOTHING IS BEING PUBLISHED, AND REFUSING IT WAS A1'S DOCTRINE IN
    # REVERSE (V-1 round 14, a WP-4 finding). This branch read empty stdin as "unknown" and denied. But
    # git writes one line per ref it is about to update, and computes that set itself: zero lines is
    # git stating that no ref will move. Driven: an "Everything up-to-date" push was refused here
    # while the control `--no-verify` returned 0 and "Everything up-to-date" -- so the tripwire's
    # only effect on that command was to teach the operator to bypass it. A guard that blocks the
    # workflow it protects gets switched off; that is A1's own doctrine and the reason the
    # 19 over-refused subcommands were restored.
    #
    # THE FAIL-CLOSED DIRECTION IS UNCHANGED, because nothing is being authorized here: no ref lines
    # means no publication to authorize, so no gate is spent and NO IN-FLIGHT WITNESS IS WRITTEN.
    # A deletion push is not this case -- git supplies a line carrying the zero sha for it.
    exit 0
}

$authorized = @()
foreach ($line in $lines) {
    $parts = @($line -split '\s+')
    if ($parts.Count -lt 4) { Deny "a ref line from git could not be parsed: '$line'." }
    $localRef = $parts[0]; $localSha = $parts[1]; $remoteRef = $parts[2]; $remoteSha = $parts[3]

    if ($localSha -eq $ZERO) {
        # A DELETION HAS NO SHA FOR A GATE TO BIND, and deleting a published ref is an irreversible
        # remote effect just as publishing one is. It is refused rather than waved through on the
        # grounds that it is "not a push of anything".
        Deny "this push DELETES the remote ref '$remoteRef', which no gate can bind (a deletion has no sha). Deleting a published ref is an irreversible remote effect and is refused here."
    }

    # THE TRIPLE, NOT THE SHA (amendment 20). git hands this hook the remote URL as argv[1], which is
    # what the user actually asked to publish to; the GATE declares which origin it authorizes. Both
    # are compared, and `.git/config` is consulted by neither.
    #
    # AND AN EMPTY URL IS REFUSED RATHER THAN PASSED THROUGH. `Get-EvidencePushGateForSha` treats an
    # empty -OriginUrl as "no origin to check" and skips that leg -- which is correct for the
    # PreToolUse tripwire, whose whole limitation is that it cannot know a URL, and wrong here. Driven:
    # with both parameters empty the gate authorises on the SHA ALONE, which is the pre-amendment-20
    # behaviour, at the one place the ruling says the decision is made. Nobody can choose to send an
    # empty URL -- git supplies it -- but "safe because the input is usually well-formed" is not the
    # property the amendment asked for.
    if (-not $RemoteUrl) {
        Deny "git supplied no remote URL for '$RemoteName', so the origin this push would reach cannot be compared against the one the gate declares. Refusing rather than falling back to authorising on the sha alone."
    }
    $v = Get-EvidencePushGateForSha -Root $root -Sha $localSha -OriginUrl $RemoteUrl -RemoteRef $remoteRef
    if (-not $v.ok) {
        Deny ("publishing '$localRef' ($localSha) to '$remoteRef' on '$RemoteName' ($RemoteUrl) is not authorized." + "`n" + $v.reason)
    }
    $authorized += [pscustomobject]@{
        gate_path = $v.path; authorized_sha = $localSha; remote_ref = $remoteRef
        remote_sha_before = $remoteSha; declared_origin = $v.origin_url
    }
}

# WITNESS WHAT WAS ALLOWED. Written only after every ref passed, so the record cannot exist for a
# publication that was refused, and cannot exist at all for a command that publishes nothing.
try {
    # EVERY REF, NOT `$authorized[0]`. The loop above already refuses the WHOLE push if any single
    # ref is unauthorized -- a non-zero exit here aborts the entire publication, which is what makes
    # "refused whole" true rather than aspirational. What was missing was the other half: witnessing
    # each ref that WAS authorized, so each gate can be settled afterwards.
    $declared = @($authorized | ForEach-Object { $_.declared_origin } | Sort-Object -Unique)
    $null = Write-EvidencePushInFlight -Root $root -Remote $RemoteName -RemoteUrl $declared[0] -Entries $authorized
} catch {
    # A publication we cannot witness is one whose gate cannot honestly be spent afterwards. The
    # push is still ALLOWED -- it is authorized, and refusing it here would punish the operator for
    # a bookkeeping failure -- but the inability to record it is made loud.
    [Console]::Error.WriteLine("LAM pre-push: the push is AUTHORIZED but the in-flight record could not be written ($($_.Exception.Message)).")
    [Console]::Error.WriteLine("The gate will NOT be consumed automatically; consume or revoke it by hand, or it can authorize a second publication.")
}

exit 0
