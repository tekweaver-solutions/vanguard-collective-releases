#Requires -Version 5.1
<#
    mission verify -- INCREMENT 3: + THE MANIFEST AND PLANE-PARITY ARMS.

    Built to docs/framework/mission-verify-spec.md, SEALED BYTES AS-IS (A3), with ONE
    ruled exception named below. REOPEN #43 / M-113 seam S1, under its rulings and
    its amendment.

    WHAT THIS INCREMENT IS
      Increments 1 and 2 -- the CLI entry point and its sealed invocation surface (spec:95-98),
      the closed six-outcome vocabulary and the mechanical gate rule (spec:53-63), the three-value
      exit contract (spec:194-198), refusal semantics (spec:184-190), the divergence report
      (spec:137-180), the ANCHOR arm (spec:220-261) and the ORIGIN-ATTESTATION arm (spec:371-416)
      -- plus TWO new arms: MANIFEST (spec:263-311) and PLANE-PARITY (spec:312-370), and the
      section 5 ordering rule a registered finding's resolution binds verify to (spec:435-449).

      ALL FOUR ARMS ARE NOW BUILT. Every row of the spec:115-126 derivation command set is
      implemented, so `arms_not_run` now carries only arms that RAN AND FOUND NOTHING TO COMPARE.
      "Did not run" and "ran and had no subject" are different facts about a run and stay apart.

    THE ONE RULED EXCEPTION -- AND IT IS THE ONLY DEPARTURE FROM THE SEALED BYTES.
      `Get-EvidenceState` returns FIVE states; spec:269 declares a four-member vocabulary and
      spec:309 maps four. The fifth, `GREW`, was minted by cure D10 AFTER A3 was
      sealed, so the sealed bytes carry NO clause for it -- and building spec:309 literally would
      route the ordinary between-turns state of a live multi-turn dispatch to `TAMPERED` ->
      `DIVERGED`, which is the E5-iv misdiagnosis spec:68-71 itself forecloses. The amendment supplies
      the missing clause: GREW emits MOVED, TAMPERED -> DIVERGED stands exactly as spec:309 writes
      it, every undecidable case still lands TAMPERED, and the arm reports the DERIVED state with
      its verbatim reason string so a reader sees GREW and not merely MOVED. The mapping lives in
      ONE table, $script:ManifestStateOutcome, with the ratified clause labelled in place.

    THE SEALED LIBRARY IS CONSUMED AND NEVER EDITED. The three detectors arms 4.2 and 4.3 are
      specified over live inside sealed anchor EC27AB3A / 80479 b, worktree-class -- the 189f811b / 46870 b figure is SUPERSEDED and 65865a0f / 76413 b is RETIRED. This file imports them, calls them, and
      modifies none of them -- and does not RE-IMPLEMENT them either, because a re-implementation
      is an edit wearing a different hat: it forks the detector the spec names and the fork drifts
      silently. Where the sealed code carries a known defect this increment must not fix -- a registered finding's
      ordering false positive -- the rule is obeyed at the CONSUMER (SS 8e) and the sealed bytes
      are left alone. Editing Test-EvidenceStreamIntegrity is A-566's territory and needs its own
      amendment plus the operator-placement route.

    THE ORIGIN ARM'S RECORDED SIDE HAS ONE DECLARED HOME, AND IT IS OPTIONAL.
      spec:373 compares "every claim an artifact makes about origin". Since LAM-ACCEPT amendment
      42 schemas SS5's
      RunnerAnchors sub-schema (:456-462) declares SEVEN members, and :462 declares `origin_tip`
      as string or null, NOT required: null is the absence of an origin claim, not an assertion
      that origin lacks the ref. schemas SS13's `authorized_tip_sha` is a PUSH AUTHORIZATION, which
      spec:402-405 says in terms this arm does not stand in for; and the claim spec 6.2 exists for
      ("origin remains behind") is PROSE, which is lint and never gates (spec:85-87). verify
      therefore reads that ONE NAMED HOME, `runner_anchors.origin_tip`, and where an artifact
      carries no non-null, non-blank value there the arm DOES NOT ENGAGE and says so in
      `arms_not_run`. Reporting that absence or null as ABSENT would invent a requirement the
      schema declines to impose -- schemas SS5 :481 says neither is a missing anchor -- the mirror
      image of the allow-side stretch spec:78-83 forbids. The runner's reason keys beside it,
      origin_tip_ref / origin_tip_exit_code / origin_tip_note, are column-0 keys outside
      runner_anchors: :462 describes them, NO schema declares them, and verify does not read them.

    WHEN THE ARM ENGAGES, BOTH CHANNELS ALWAYS RUN. spec:378 -- "Both are run; both are recorded
    with their raw output." Neither channel is ever skipped for being unavailable: a channel that
    cannot answer is UNREACHABLE and refuses (spec:406-407), because silence is not consent.

    ENCODING. Pure ASCII, deliberately, for the reason the spec gives of itself at spec:16-20:
    a BOM-less .ps1 is parsed by PowerShell 5.1 in the ANSI codepage, so any non-ASCII byte here
    becomes a pattern-matching hazard for a checker. Removing the characters removes the class.

    STDERR. This script writes NOTHING to stderr. Under PowerShell 5.1 a native process's stderr
    is promoted to a terminating NativeCommandError in a caller running under 'Stop', which would
    make an honest refusal indistinguishable from a crash at the call site. All output is stdout;
    the exit code is the machine-readable channel.

    REPO ROOT RESOLUTION, stated rather than left to discover. The sealed invocation carries no
    --repo-root flag. The root is resolved by walking up from the current working directory for
    `.mission/mission.yaml`, then, failing that, by walking up from this script's own directory.
    That rule is what lets a mutated copy of this file, placed outside the repository for
    planted-breakage acceptance drives, still derive against the real repository when it is run
    from the repository root.

    THE PLANE ROOT, AND A DISCLOSED DEPARTURE FROM spec:122-124's LITERAL `-Root <repo>`.
    Arms 4.2 and 4.3 READ the evidence plane. spec:122-124 write the detector invocations as
    `-Root <repo>`, i.e. the repository root, and that is exactly what this file passes WHEN
    `--evidence-root` IS ABSENT. When `--evidence-root` IS supplied it becomes the plane root for
    those reads as well as for this run's own self-capture write.

    WHY, DERIVED RATHER THAN PREFERRED. `--evidence-root` is the flag that names where THIS RUN's
    evidence plane lives (spec:97, "the remaining flags are plumbing"). Without it governing the
    reads there is no hermetic way to drive these two arms at all: every acceptance drive would
    have to point the sealed detectors at the real store, and A-563:52-56 forbids greening the
    self-capture leg from inside a session while design SS4.1 makes the runtime plane destroyable
    from inside with no marker. A flag that redirects where evidence is written but not where it
    is read would name two different planes in one run, which is the incoherence, not the cure.
    STATED AS A DEPARTURE rather than folded in silently: the sealed bytes say `<repo>`, this
    build says `<repo>` by default and `--evidence-root` when given, and the difference is
    reported at the increment's checkpoint for an individual ruling. Every derivation record
    prints the ROOT IT ACTUALLY USED, so no reader has to infer which plane was read.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# =====================================================================================
# SS 1.  THE CLOSED VOCABULARY AND THE GATE RULE  (spec:48-87)
# =====================================================================================

# The vocabulary is closed. Membership is checked, not assumed (spec:50).
$script:Outcomes = @('MATCHED', 'DIVERGED', 'MOVED', 'UNREACHABLE', 'ABSENT', 'NOT_APPLICABLE')

# spec:62-63 -- "a dispatch proceeds only when every arm reports MATCHED or NOT_APPLICABLE.
# Every other outcome refuses."  This is the PROCEED set, and the gate is computed from it.
# It is NOT computed as "no DIVERGED": that formulation passes an UNREACHABLE or ABSENT run and
# is the false-PASS class design SS4.5 law 5 exists for (spec:64-66).
$script:ProceedOutcomes = @('MATCHED', 'NOT_APPLICABLE')

# spec:78-83 -- NOT_APPLICABLE is an allow-side exemption with EXACTLY ONE admissible member in
# this document: the `suite` block on read-only and micro-ceremony dispatches. Any further member
# requires an amendment naming it. The rule is enforced structurally, in New-ArmEntry, so that
# admitting a second member is a code change and not an oversight.
$script:SoleNotApplicableSubject = 'suite'

# =====================================================================================
# SS 2.  THE DERIVATION COMMAND SET  (spec:115-126) -- DATA, NOT CODE
# =====================================================================================
#
# The ten rows of the spec:115-126 table, transcribed as data. This table is the ADMITTED SET.
#
# THE EXCLUSION IS DERIVED FROM THIS SET, NEVER HAND-LISTED (spec:128-130; A-564:25-27).
# `git rev-parse origin/<branch>` is excluded because it is not a member -- not because a
# denylist names it. Every derivation this program performs is issued through Invoke-Derivation,
# which resolves its command from this table by subject and refuses any subject not in it. A
# detector added to the table later inherits the discipline without a new amendment; a detector
# absent from the table has no code path that can issue it.

$script:DerivationCommandSet = @(
    [pscustomobject]@{ Subject = 'head'             ; Arm = 'ANCHOR'             ; SpecLine = 117; Kind = 'process'; Command = 'git rev-parse HEAD'                                                        ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'tree'             ; Arm = 'ANCHOR'             ; SpecLine = 118; Kind = 'process'; Command = 'git status --porcelain=v1'                                                 ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'origin_git'       ; Arm = 'ORIGIN-ATTESTATION' ; SpecLine = 119; Kind = 'process'; Command = 'git ls-remote origin refs/heads/<branch>'                                   ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'origin_api'       ; Arm = 'ORIGIN-ATTESTATION' ; SpecLine = 120; Kind = 'http'   ; Command = 'the repository host ref endpoint for heads/<branch>'                         ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'suite'            ; Arm = 'ANCHOR'             ; SpecLine = 121; Kind = 'process'; Command = '<the canonical suite command from mission config>'                          ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'evidence_state'   ; Arm = 'MANIFEST'           ; SpecLine = 122; Kind = 'library'; Command = 'Get-EvidenceState -Root <repo> -DispatchId <id>'                             ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'plane_parity'     ; Arm = 'PLANE-PARITY'       ; SpecLine = 123; Kind = 'library'; Command = 'Test-EvidencePlaneParity -Root <repo> -DispatchId <id>'                      ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'stream_integrity' ; Arm = 'PLANE-PARITY'       ; SpecLine = 124; Kind = 'library'; Command = 'Test-EvidenceStreamIntegrity -Root <repo> -DispatchId <id>'                  ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'manifest_hash'    ; Arm = 'ANCHOR'             ; SpecLine = 125; Kind = 'inproc' ; Command = 'sha256 over the manifest file'                                              ; Implemented = $true  }
    [pscustomobject]@{ Subject = 'schema_validity'  ; Arm = 'MANIFEST'           ; SpecLine = 126; Kind = 'inproc' ; Command = 'the manifest validated against docs/framework/evidence-manifest.schema.json'; Implemented = $true  }
)

# THE `library` KIND, AND WHY IT IS NOT `inproc`. Both are in-process calls and both report a null
# exit_code for the same reason (SS 4 and a review finding). They are kept apart because a `library` row's
# detector is a function SEALED INSIDE ANCHOR EC27AB3A / 80479 b, worktree-class -- the 189f811b / 46870 b figure is SUPERSEDED and 65865a0f / 76413 b is RETIRED -- that this file may call and may not touch,
# while an `inproc` row's detector is this file's own code. The distinction is what makes the
# consume/edit line inspectable from the table rather than remembered, and it is what decides
# whether a raw derivation is a scalar (inproc) or the callee's whole returned verdict object
# (library), which spec:109-113 requires be recorded verbatim.

function Get-DerivationCommandSet {
    <# The admitted set, as data. Callers read THIS; nothing maintains a parallel list. #>
    return $script:DerivationCommandSet
}

function Get-AdmittedSubject {
    param([Parameter(Mandatory = $true)][string]$Subject)
    $row = @(Get-DerivationCommandSet | Where-Object { $_.Subject -eq $Subject })
    if ($row.Count -ne 1) {
        # Not an admitted subject. There is no code path that issues a command for it.
        throw "INTERNAL: subject '$Subject' is not a member of the spec:115-126 derivation command set."
    }
    return $row[0]
}

function Test-DerivationExclusionDerived {
    <#
        The A-564:46-49 shape, applied to what this increment can already violate: every command
        that reached `derivations` traces back to a member of the admitted set. The check reads
        the ADMITTED SET; it never pattern-matches a forbidden string.
        Returns the list of issued commands that are NOT traceable to the admitted set (empty is
        the passing state).
    #>
    param([Parameter(Mandatory = $true)]$Derivations)
    $admitted = @(Get-DerivationCommandSet | ForEach-Object { $_.Subject })
    $orphans = @()
    foreach ($d in $Derivations) {
        if ($admitted -notcontains $d.__subject) { $orphans += $d.command }
    }
    # Comma-wrapped: PowerShell unrolls a bare empty array on return, and the passing state of
    # this check IS the empty array. A caller that received $null here would be unable to tell
    # "nothing outside the admitted set" from "the check did not run" -- the same INCOMPLETE-vs-
    # CLEAN confusion spec:64-66 forbids in the gate.
    return , $orphans
}

function Expand-AdmittedCommandText {
    <#
        THE SINGLE PLACE A COMMAND STRING IS COMPOSED, FOR EVERY KIND IN THE TABLE.

        The text is built from the admitted row's OWN `Command` BYTES by substituting the named
        <tokens>; a token the template does not carry, or a token the caller failed to supply, is
        an INTERNAL error rather than a quietly half-substituted string. Extracted from
        Get-AdmittedProcessInvocation when the `library` rows arrived, because two copies of this
        rule would be two things to keep in agreement -- and the property A-564:46-49 asks for is
        that the set of commands verify CAN compose is exactly the set of rows, which a second
        copy could drift away from.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [hashtable]$Tokens
    )
    $row = Get-AdmittedSubject -Subject $Subject
    $text = $row.Command
    if ($Tokens) {
        foreach ($k in $Tokens.Keys) {
            $needle = '<' + $k + '>'
            if ($text.IndexOf($needle) -lt 0) {
                throw "INTERNAL: token '$needle' does not appear in the admitted command for subject '$Subject'."
            }
            $text = $text.Replace($needle, [string]$Tokens[$k])
        }
    }
    if ($text -match '<[A-Za-z_]+>') {
        throw "INTERNAL: the admitted command for subject '$Subject' still carries an unsubstituted token."
    }
    return $text
}

function Get-AdmittedProcessInvocation {
    <#
        THE EXCLUSION MECHANISM, and the reason no denylist exists anywhere in this file
        (A-564:46-49, spec:128-130).

        Every process command line this program issues is BUILT FROM THE ADMITTED SET'S OWN
        `Command` BYTES, by substituting the named <tokens> and splitting. No caller hand-writes
        an argument vector, so the set of commands verify CAN issue is exactly the set of rows in
        the spec:115-126 table -- by construction, not by inspection.

        `git rev-parse origin/<branch>` is therefore unissuable because it is NOT A ROW. Nothing
        here names it, tests for it, or filters it out; there is simply no code path that can
        produce it. A detector added to the table later inherits the discipline with no amendment,
        which is the property A-564 asks for and which a hand-maintained forbidden-string list
        cannot have -- such a list is a second thing to keep correct, and it FAILS the assertion
        (A-564:62) precisely because it can drift from the table it is supposed to mirror.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [hashtable]$Tokens
    )
    $row = Get-AdmittedSubject -Subject $Subject
    if ($row.Kind -ne 'process') {
        throw "INTERNAL: subject '$Subject' is not a process-kind row of the spec:115-126 set; no argument vector can be built from it."
    }
    $text = Expand-AdmittedCommandText -Subject $Subject -Tokens $Tokens
    $parts = @($text -split '\s+' | Where-Object { $_ -ne '' })
    if ($parts.Count -lt 1) { throw "INTERNAL: the admitted command for subject '$Subject' is empty." }
    $rest = @()
    if ($parts.Count -gt 1) { $rest = @($parts[1..($parts.Count - 1)]) }
    return [pscustomobject]@{ FilePath = $parts[0]; ArgumentList = $rest }
}

function Test-CommandIsAdmittedInstance {
    <#
        The exclusion made structural in the PRODUCT, not only in the probe that grades it.
        A command line is admissible only if it is an INSTANCE of its subject's own template in
        the spec:115-126 table -- the template with its <tokens> filled in and nothing else. A
        caller that hand-assembled an argument vector cannot slip it past this, because the test
        is against the table's bytes rather than against a list of things not to do.

        WHY A TEMPLATE MATCH RATHER THAN A FORBIDDEN-STRING LIST. A denylist can only refuse what
        it already names. `git rev-parse origin/<branch>` and
        `git for-each-ref refs/remotes/origin/<branch>` read the SAME local remote-tracking cache
        and are the same defect, but a list naming the first says nothing about the second. The
        template match refuses both without naming either, and refuses the next one too.

        `http` rows are exempt because their table entry is a DESCRIPTION of an endpoint rather
        than a command line -- there is no template to be an instance of. That channel's argument
        vector is instead constrained at its single composition point, Get-OriginApiInvocation.
        The asymmetry is stated rather than hidden: it is the weaker of the two guarantees.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$CommandText
    )
    $row = Get-AdmittedSubject -Subject $Subject
    if ($row.Kind -ne 'process') { return $true }
    $pattern = '^' + ([regex]::Escape($row.Command) -replace '<[A-Za-z_]+>', '\S+') + '$'
    return ($CommandText -match $pattern)
}

# =====================================================================================
# SS 3.  ANCHOR SCOPING BY DISPATCH KIND  (schemas SS5 :458, :479; spec:251-253)
# =====================================================================================
#
# schemas SS5 RunnerAnchors: `suite` is "Required for build-, rework- and close-class dispatches;
# absent for read-only and micro-ceremony dispatches." head_sha, porcelain and the manifest fields
# are universal. Absence is MEANINGFUL and must not be read as a missing anchor.
#
# THE TABLE HAS NO mainline ROW, DELIBERATELY. Since an amendment to LAM-ACCEPT the
# LAM runner writes the CLASS, bare, as the top-level kind -- `dispatch_kind: build` for a mainline,
# fanout or build dispatch -- with `dispatch_kind_token: '<declared word>'` beside it at column 0
# (tools/lam/mission-dispatch.ps1:3532-3533). This reader never reads dispatch_kind_token. The change is
# FORWARD-ONLY: the 14 committed anchors files recording `dispatch_kind: mainline` were not
# rewritten, so a verify against one of them refuses (ANCHOR / dispatch_kind ABSENT, Recorded
# mainline) unless --dispatch-kind is given; the runner's gate passes the class
# (mission-dispatch.ps1:1859). When --dispatch-kind is given it is used, and the kind recorded in the
# artifact is NOT compared with it (Invoke-MissionVerify, the dispatch-kind resolution).

$script:DispatchKindScoping = @(
    [pscustomobject]@{ Kind = 'build'          ; SuiteRequired = $true  }
    [pscustomobject]@{ Kind = 'rework'         ; SuiteRequired = $true  }
    [pscustomobject]@{ Kind = 'close'          ; SuiteRequired = $true  }
    [pscustomobject]@{ Kind = 'read-only'      ; SuiteRequired = $false }
    [pscustomobject]@{ Kind = 'micro-ceremony' ; SuiteRequired = $false }
)

function Get-DispatchKindScoping {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Kind)
    $row = @($script:DispatchKindScoping | Where-Object { $_.Kind -eq $Kind })
    if ($row.Count -ne 1) { return $null }   # unknown kind: verify refuses rather than guessing
    return $row[0]
}

# =====================================================================================
# SS 4.  CHILD PROCESSES AND THE DERIVATION RECORD  (spec:109-113, 158-164)
# =====================================================================================
#
# spec:109-113 -- "Verify prints the command it ran and the raw output it derived from, for every
# derivation... A derivation that appears in a verdict without its command and its raw output
# beside it is not admissible in a verify report."
#
# exit_code is populated HONESTLY, from this process's own children, via
# System.Diagnostics.Process. It is never defaulted to 0 and never left null for a command that
# actually ran. The hook-captured carrier's permanent null is a different carrier's residual and
# is DISCLOSED in the report's basis rather than silently inherited here.

$script:Derivations = New-Object System.Collections.ArrayList

# THE TWO ROOTS THIS RUN USES, resolved once in Invoke-MissionVerify and printed on EVERY derivation
# record (the DEV-1 REFINEMENT, ratified 2026-08-16). Initialised here because StrictMode 2.0 makes
# an unset variable a fault, and a derivation issued before resolution must say so rather than throw:
# '<unresolved>' is a value a reader can see, where a crash would be a fact only the stack trace holds.
$script:ReadPlaneRoot = '<unresolved>'
$script:WriteEvidenceRoot = '<unresolved>'

# =====================================================================================
# TWO NULLS THAT MUST NOT BE CONFLATED (a review finding, and the disclosure that matters here)
# =====================================================================================
#
# E5-i's `exit_code: null` in the hook-captured carrier is a CAPTURE GAP: the harness never
# supplied the field (v2.3:285), so a call that DID exit has no exit code on the record.
# THIS file's `exit_code: null` is a CATEGORY FACT: the detector is not a process, so there is no
# exit code to have. Reporting them with the same bare null and no reason would merge a gap with
# a non-applicability -- exactly the undisclosed-residual class a review finding registers -- so EVERY null
# emitted here carries its own reason string in its own field beside it, and the carrier's null is
# disclosed separately in basis.disclosed_residuals.
#
# THIS CORRECTS INCREMENT 1's RECORD SHAPE, AND THE CORRECTION IS DISCLOSED RATHER THAN SLIPPED IN.
# Increment 1 recorded `exit_code: 0` for the one in-process row it implemented (manifest_hash),
# and 1 when that row threw. Under the review's finding both are fabricated fields: no process ran, so neither
# figure was ever observed. The rule is applied at the MECHANISM rather than at the new rows only,
# because two adjacent derivation records using the same field with two different meanings is the
# same defect this comment exists to prevent, committed in the other direction. No outcome changes
# -- no arm reads exit_code for an in-process subject -- and the change is reported at the
# increment's checkpoint.
$script:ExitNullInProc = 'null BY CATEGORY, NOT BY CAPTURE GAP. This derivation is an IN-PROCESS FUNCTION CALL: no child process was started, so no process exit code exists to report and a 0 here would be a fabricated field (a review finding). The result is carried instead by the detector''s OWN returned verdict fields, recorded verbatim as this record''s raw output. THIS IS NOT THE E5-i NULL: the hook-captured carrier records a PERMANENT null for exit_code because the harness never supplied the field (v2.3:285), which is a capture gap; this one is a non-applicability, and merging the two would hide a gap behind a category fact.'
$script:ExitNullInProcThrew = 'null BY CATEGORY, NOT BY CAPTURE GAP, AND THE CALL FAULTED. This derivation is an IN-PROCESS FUNCTION CALL, so no process exit code exists to report (a review finding) -- and reporting a 1 to mean failure would invent a process that never ran. The failure is recorded as the exception message in this record''s stderr, which is where it can be read rather than inferred from a number. THIS IS NOT THE E5-i NULL (v2.3:285); see the non-faulting reason for that distinction.'

function Invoke-ChildProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.Arguments = ($ArgumentList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $code = $p.ExitCode
    $p.Dispose()
    return [pscustomobject]@{ StdOut = $stdout; StdErr = $stderr; ExitCode = $code }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try { return (($sha.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') }) -join '') }
        finally { $fs.Dispose() }
    } finally { $sha.Dispose() }
}

# =====================================================================================
# SS 4b.  THE CREDENTIAL LAW  (spec:391-393; A-564:34-37, :55-57)
# =====================================================================================
#
# spec:391-393 -- "Credentials are never displayed. The API channel authenticates through the
# tool's own credential store; NO SECRET BYTES APPEAR IN ANY ARTIFACT, EVIDENCE FILE, REPORT, OR
# COMMAND LINE VERIFY PRINTS. Where a credential must be identified at all, it is identified by
# hash prefix."
#
# STRUCTURAL vs DISCIPLINARY, kept apart honestly. On a host whose GitHub credentials are routed
# to a helper, the token is never an argv value BY CONSTRUCTION -- git spawns the helper and the
# credential crosses on the helper protocol's stdio, so it is not on any command line verify
# composes. The command-line clause is satisfied by the shape of the mechanism, not by this
# code's care, and this file does not claim credit for it. What DOES bind by discipline is the
# capture path: raw stdout and stderr are recorded verbatim by spec:109-113, and an error path is
# where a URL or an auth hint can surface. So every captured stream passes through Protect-Stream
# before it is recorded, hashed, or printed -- there is no route around it.

$script:UserInfoPattern = 'https?://[^/@\s]*:[^/@\s]*@'
$script:CredentialEnvNames = @('GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN')
$script:ForbiddenApiFlags = @('-i', '--include')

function Test-UrlUserInfo {
    <# A URL carrying userinfo is a token in a remote URL: a FINDING, never a formatting problem. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return $false }
    return ($Text -match $script:UserInfoPattern)
}

function Protect-Stream {
    <#
        Redact first, then decide. The returned text is what may be recorded; UserInfoFound is
        what makes the caller HALT. Redaction happens BEFORE the hash is taken, so no artifact
        anywhere -- report, evidence file, or console -- carries the original bytes, and the
        recorded sha256 is the sha of what was actually written rather than of a secret.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $found = Test-UrlUserInfo -Text $Text
    $clean = $Text
    if ($found) { $clean = [regex]::Replace($Text, $script:UserInfoPattern, 'https://<redacted>@') }
    return [pscustomobject]@{ Text = $clean; UserInfoFound = $found }
}

function Assert-NoUserInfo {
    <#
        R4's HALT. Implemented on the spec:198 did-not-complete path: verify stops and NO REPORT
        CLAIMING A VERDICT is written or printed. The message names the finding and the place it
        was seen; it carries no bytes from the offending string, because a HALT that prints the
        credential to explain itself defeats the rule it is enforcing.
    #>
    param([Parameter(Mandatory = $true)][string]$Where)
    throw "HALT (credential): a URL carrying userinfo was observed in $Where. A token in a remote URL is a finding, not a formatting problem (spec:391-393). No verdict is emitted and no bytes of the offending value are reproduced here."
}

function Get-CredentialEnvDisclosure {
    <#
        R2. Where the PRESENCE of an env credential must be recorded at all, it is recorded as the
        NAME plus sha256(value) truncated to its first 8 hex -- the recorded hash-prefix
        convention. Never the value. Never a prefix OF the value. Never its length: a length is a
        search-space reduction, which is why it is excluded here rather than merely discouraged.
    #>
    $out = @()
    foreach ($n in $script:CredentialEnvNames) {
        $v = [Environment]::GetEnvironmentVariable($n)
        if (-not [string]::IsNullOrEmpty($v)) {
            $out += ("$n present; identified by hash prefix " + (Get-Sha256Hex -Text $v).Substring(0, 8))
        }
    }
    return , $out
}

function Invoke-Derivation {
    <#
        The ONLY route by which this program issues a derivation. Resolves the command from the
        admitted set by subject; a subject outside that set throws before anything runs. Records
        command, exit_code, stdout_sha256, stderr_sha256 and VERBATIM stdout (spec:158-164),
        every stream having passed the credential scan first.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string[]]$ProcessArgs,
        [string]$ProcessFile,
        [string]$InProcCommandText,
        [scriptblock]$InProcAction
    )
    $row = Get-AdmittedSubject -Subject $Subject
    if (-not $row.Implemented) {
        throw "INTERNAL: subject '$Subject' (arm $($row.Arm)) is declared but NOT implemented in this increment; no derivation may be issued for it."
    }

    # 'http' executes as a child process too -- the host's ref endpoint is reached through the
    # tool named at spec:378 ("`gh api` or equivalent"). The Kind stays distinct in the table
    # because the spec's row for it is a DESCRIPTION of an endpoint, not a command line, and
    # pretending otherwise would let Get-AdmittedProcessInvocation split prose into an argv.
    $inprocValue = $null
    $exitReason = $null
    if ($row.Kind -eq 'process' -or $row.Kind -eq 'http') {
        $r = Invoke-ChildProcess -FilePath $ProcessFile -ArgumentList $ProcessArgs -WorkingDirectory $RepoRoot
        $commandText = (@($ProcessFile) + $ProcessArgs) -join ' '
        $stdout = $r.StdOut
        $stderr = $r.StdErr
        $exit = $r.ExitCode
    }
    else {
        # 'inproc' and 'library' -- an IN-PROCESS FUNCTION CALL. See the two-nulls note above:
        # exit_code is null with its own reason, never a fabricated 0 and never a fabricated 1.
        $commandText = $InProcCommandText
        $stderr = ''
        $exit = $null
        $exitReason = $script:ExitNullInProc
        try {
            $inprocValue = & $InProcAction
            # A `library` row's detector returns a VERDICT OBJECT, and spec:109-113 requires the
            # raw output it derived from. Serialising the whole object -- rather than stringifying
            # it, which yields a type name -- is what makes the record auditable.
            if ($row.Kind -eq 'library') { $stdout = ConvertTo-RawDerivation -Value $inprocValue }
            else { $stdout = [string]$inprocValue }
        }
        catch {
            $inprocValue = $null
            $stdout = ''
            $stderr = [string]$_.Exception.Message
            $exitReason = $script:ExitNullInProcThrew
        }
    }

    # R5 -- THE ERROR PATH IS THE REAL RISK AND IS SCANNED, NOT TRUSTED. A failed HTTPS fetch or
    # a `gh api` 401 can echo a URL or an auth hint, so stdout, stderr AND the composed command
    # all pass the scan before anything is hashed, recorded or printed. There is no branch that
    # records an unscanned stream.
    if (-not (Test-CommandIsAdmittedInstance -Subject $Subject -CommandText $commandText)) {
        throw "MALFORMED: the command issued for subject '$Subject' is not an instance of that subject's template in the spec:115-126 derivation command set. Every command line this program issues is built from that table; a hand-assembled argument vector is refused here rather than recorded."
    }

    $pcmd = Protect-Stream -Text $commandText
    $pout = Protect-Stream -Text $stdout
    $perr = Protect-Stream -Text $stderr
    if ($pcmd.UserInfoFound) { Assert-NoUserInfo -Where "the composed command line for subject '$Subject'" }
    if ($pout.UserInfoFound) { Assert-NoUserInfo -Where "the stdout of subject '$Subject'" }
    if ($perr.UserInfoFound) { Assert-NoUserInfo -Where "the stderr of subject '$Subject'" }
    $commandText = $pcmd.Text
    $stdout = $pout.Text
    $stderr = $perr.Text

    $rec = [ordered]@{}
    $rec['command'] = $commandText
    # BOTH ROOTS, ON EVERY RECORD (the DEV-1 REFINEMENT). They are RUN-LEVEL facts, not per-derivation
    # attribution: a `process` row consults neither, and the disclosure beside them says so. They ride
    # every record anyway because the question a reader brings to a derivation is "which plane was this
    # decided against", and a root printed only where it happened to be used is a root the reader must
    # go looking for -- the same reasoning spec:288-289 gives for hook_errors_present.
    $rec['read_plane_root'] = $script:ReadPlaneRoot
    $rec['write_evidence_root'] = $script:WriteEvidenceRoot
    $rec['exit_code'] = $exit
    # The reason rides IMMEDIATELY beside the null it explains. A reason kept anywhere else is a
    # reason a reader scanning the derivations block will not meet.
    if ($null -eq $exit) { $rec['exit_code_null_reason'] = $exitReason }
    $rec['stdout_sha256'] = (Get-Sha256Hex -Text $stdout)
    $rec['stderr_sha256'] = (Get-Sha256Hex -Text $stderr)
    $rec['stdout'] = @{ __block__ = $stdout }
    # Provenance for the derived exclusion check. Stripped before emission.
    $rec['__subject'] = $Subject
    [void]$script:Derivations.Add($rec)
    return [pscustomobject]@{ StdOut = $stdout; StdErr = $stderr; ExitCode = $exit; Command = $commandText; Value = $inprocValue }
}

function ConvertTo-RawDerivation {
    <#
        A sealed detector's returned verdict object, serialised verbatim as this run's raw
        derivation (spec:109-113, SS 10 of the increment-3 dispatch). Depth 12 covers the deepest
        shape any of the three returns -- a mismatch list of flat objects -- with room to spare,
        and a shape that exceeded it would be visibly truncated in the record rather than silently
        flattened.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value | ConvertTo-Json -Depth 12)
}

# =====================================================================================
# SS 5.  BASIS  (spec:144-148, 630-634)
# =====================================================================================
#
# spec:632-634 -- "A basis is: which tree (worktree, index, or commit), at which HEAD, with
# untracked files included or excluded, and under which hash class... All of it, or the figure is
# not comparable."  A-563 FAILS a basis that is DEFAULTED rather than derived, so every member
# below is derived from something: `tree` and `untracked_included` from the admitted tree
# command's own flags; `head` from the admitted head derivation; `hash_class` from erratum E4's
# two stated conditions, read off disk.

function Get-BasisTreeMembers {
    <# Derived from the admitted `tree` command string, not asserted. #>
    $cmd = (Get-AdmittedSubject -Subject 'tree').Command
    if ($cmd -match '--cached|--staged') { $tree = 'index' } else { $tree = 'worktree' }
    if ($cmd -match '-uno|--untracked-files=no') { $untracked = $false } else { $untracked = $true }
    return [pscustomobject]@{ Tree = $tree; UntrackedIncluded = $untracked }
}

function Get-HashClass {
    <#
        Erratum E4 (spec:238-244): "core.autocrlf is true in this repository and no .gitattributes
        rule covers .mission/** or docs/framework/**, so a fresh clone smudges LF to CRLF on
        checkout and the sha changes."  Both conditions are READ, not assumed. Read as files
        rather than through `git config`, because `git config` is not a member of the spec:115-126
        admitted set and this program issues no command outside it.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $autocrlf = $null
    $gitConfig = Join-Path $RepoRoot '.git\config'
    if (Test-Path -LiteralPath $gitConfig) {
        foreach ($line in [System.IO.File]::ReadAllLines($gitConfig)) {
            if ($line -match '^\s*autocrlf\s*=\s*(\S+)') { $autocrlf = $Matches[1].Trim().ToLowerInvariant() }
        }
    }
    # The families erratum E4 names by name (spec:239-240). Coverage is tested PER FAMILY, not
    # "does the file contain any -text rule at all": this repository's .gitattributes carries
    # -text rules for src/** fixture trees, and a coarse check would read those as covering the
    # paths this arm hashes and mislabel a worktree anchor as clone-stable. A misdeclared hash
    # class HAS NO DETECTOR (spec:721), so the label is the only guard there is and it is derived
    # narrowly on purpose.
    $families = @('.mission/', 'docs/framework/')
    $attrs = Join-Path $RepoRoot '.gitattributes'
    $covered = @{}
    foreach ($f in $families) { $covered[$f] = $false }
    if (Test-Path -LiteralPath $attrs) {
        foreach ($line in [System.IO.File]::ReadAllLines($attrs)) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $parts = $t -split '\s+', 2
            if ($parts.Count -lt 2) { continue }
            $pattern = $parts[0].TrimStart('/')
            $attrText = $parts[1]
            if ($attrText -notmatch '(^|\s)(-text|binary)(\s|$)') { continue }
            foreach ($f in $families) { if ($pattern.StartsWith($f)) { $covered[$f] = $true } }
        }
    }
    $allCovered = $true
    foreach ($f in $families) { if (-not $covered[$f]) { $allCovered = $false } }

    if (($autocrlf -eq 'true' -or $autocrlf -eq 'input') -and -not $allCovered) { return 'worktree' }
    if ($allCovered) { return 'clone-stable' }
    return 'worktree'
}

function Get-BasisMovedState {
    <#
        WHICH BASIS MEMBERS PARTICIPATE, in one place because TWO arms now ask the question and
        two copies of this rule would be two things to keep in agreement.
        `tree`, `untracked_included` and `hash_class` govern HOW the recorded figures were
        derived; if any differs, the comparison cannot decide and the outcome is MOVED -- spec:57
        exactly ("The basis differs, so the comparison cannot decide"). `basis.head` is NOT in
        this test: HEAD is the anchor point, and head movement is precisely what `head_sha`
        compares, so folding it in would launder the finding the gate exists for.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$RecordedBasis, [Parameter(Mandatory = $true)]$Basis)
    $movedMembers = @()
    if ($null -ne $RecordedBasis) {
        foreach ($m in @('tree', 'untracked_included', 'hash_class')) {
            $rv = Get-AnchorMember -Anchors $RecordedBasis -Name $m
            if ($null -ne $rv -and [string]$rv -ne [string]$Basis[$m]) { $movedMembers += $m }
        }
    }
    return [pscustomobject]@{
        Moved = ($movedMembers.Count -gt 0)
        Note  = ("basis differs on: " + ($movedMembers -join ', '))
    }
}

# =====================================================================================
# SS 6.  ARM ENTRIES -- THE SHAPE RULES ENFORCED BY SHAPE  (spec:171-180)
# =====================================================================================

$script:Arms = New-Object System.Collections.ArrayList

function New-ArmEntry {
    <#
        spec:173-174 -- "Every arm entry carries its detector and its residual. An arm entry
        without both is malformed and verify fails rather than emitting it."  That is an exit-2
        condition: verify itself failed, and no verdict exists.
        spec:175-176 -- recorded and derived are BOTH present on EVERY entry, including MATCHED.
        spec:78-83  -- NOT_APPLICABLE has exactly one admissible member; anything else is refused
                       here rather than emitted.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Arm,
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$Outcome,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()]$Recorded,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()]$Derived,
        [Parameter(Mandatory = $true)][string]$Detector,
        [Parameter(Mandatory = $true)][string]$Residual
    )
    if ($script:Outcomes -notcontains $Outcome) {
        throw "MALFORMED: outcome '$Outcome' is outside the closed six-member vocabulary (spec:53-60)."
    }
    if ([string]::IsNullOrWhiteSpace($Detector)) {
        throw "MALFORMED: arm entry $Arm/$Subject carries no detector (spec:173-174)."
    }
    if ([string]::IsNullOrWhiteSpace($Residual)) {
        throw "MALFORMED: arm entry $Arm/$Subject carries no residual (spec:173-174)."
    }
    if ($Outcome -eq 'NOT_APPLICABLE' -and $Subject -ne $script:SoleNotApplicableSubject) {
        throw "MALFORMED: NOT_APPLICABLE emitted for subject '$Subject'. The sole admissible member is '$($script:SoleNotApplicableSubject)' (spec:78-83, 251-253); any further member requires an amendment naming it."
    }
    $entry = [ordered]@{
        arm      = $Arm
        subject  = $Subject
        outcome  = $Outcome
        recorded = $Recorded
        derived  = $Derived
        detector = $Detector
        residual = $Residual
    }
    [void]$script:Arms.Add($entry)
    return $entry
}

function Get-Gate {
    <#
        spec:62-63, literally: PASS only when EVERY arm reports MATCHED or NOT_APPLICABLE.
        refused_by names <arm>/<subject>, never the arm alone (spec:177-178).
    #>
    param([Parameter(Mandatory = $true)]$ArmEntries)
    $refusedBy = @()
    foreach ($e in $ArmEntries) {
        if ($script:ProceedOutcomes -notcontains $e.outcome) { $refusedBy += "$($e.arm)/$($e.subject)" }
    }
    if ($refusedBy.Count -eq 0) { $gate = 'PASS' } else { $gate = 'REFUSE' }
    return [pscustomobject]@{ Gate = $gate; RefusedBy = $refusedBy }
}

# =====================================================================================
# SS 7.  A RESTRICTED YAML READER AND WRITER
# =====================================================================================
#
# REACH, STATED. The reader accepts the block-YAML subset the schemas SS5 / SS6 shapes actually
# use: nested maps by indentation, block sequences of scalars, block sequences of maps, and
# quoted or bare scalars. It does NOT accept flow collections, anchors, aliases, multi-document
# streams or block scalars. Outside that subset it throws, and a throw here is an unreadable
# --against artifact -- which spec:185-186 makes a refusal, not a silent partial parse.
# JSON input is handled natively by ConvertFrom-Json and needs none of this.

function ConvertFrom-RestrictedYaml {
    param([Parameter(Mandatory = $true)][string[]]$Lines)

    $script:__yamlLines = @()
    foreach ($raw in $Lines) {
        $noTab = $raw -replace "`t", '    '
        $trimmed = $noTab.TrimEnd()
        if ($trimmed.Trim() -eq '' -or $trimmed.Trim().StartsWith('#')) { continue }
        if ($trimmed.Trim() -eq '---') { continue }
        $indent = ($noTab.Length - $noTab.TrimStart().Length)
        $script:__yamlLines += [pscustomobject]@{ Indent = $indent; Text = $trimmed.Trim() }
    }
    $script:__yamlPos = 0
    return (Read-YamlBlock -Indent 0)
}

function ConvertFrom-YamlScalar {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $t = $Text.Trim()
    if ($t -eq '' -or $t -eq '~' -or $t -eq 'null') { return $null }
    if ($t -eq '[]') { return @() }
    if ($t -eq '{}') { return @{} }
    if ($t -eq 'true') { return $true }
    if ($t -eq 'false') { return $false }
    if ($t.Length -ge 2 -and $t.StartsWith('"') -and $t.EndsWith('"')) { return $t.Substring(1, $t.Length - 2) }
    if ($t.Length -ge 2 -and $t.StartsWith("'") -and $t.EndsWith("'")) { return ($t.Substring(1, $t.Length - 2) -replace "''", "'") }
    $n = 0
    if ([int]::TryParse($t, [ref]$n)) { return $n }
    return $t
}

function Read-YamlBlock {
    param([Parameter(Mandatory = $true)][int]$Indent)

    if ($script:__yamlPos -ge $script:__yamlLines.Count) { return $null }
    if ($script:__yamlLines[$script:__yamlPos].Text.StartsWith('- ') -or $script:__yamlLines[$script:__yamlPos].Text -eq '-') {
        return (Read-YamlSequence -Indent $Indent)
    }
    return (Read-YamlMapping -Indent $Indent)
}

function Read-YamlMapping {
    param([Parameter(Mandatory = $true)][int]$Indent)
    $map = [ordered]@{}
    while ($script:__yamlPos -lt $script:__yamlLines.Count) {
        $line = $script:__yamlLines[$script:__yamlPos]
        if ($line.Indent -lt $Indent) { break }
        if ($line.Indent -gt $Indent) { throw "UNREADABLE --against: unexpected indent at '$($line.Text)'." }
        if ($line.Text.StartsWith('- ')) { break }
        $idx = $line.Text.IndexOf(':')
        if ($idx -lt 0) { throw "UNREADABLE --against: '$($line.Text)' is outside the accepted block-YAML subset." }
        $key = $line.Text.Substring(0, $idx).Trim()
        $rest = $line.Text.Substring($idx + 1).Trim()
        $script:__yamlPos++
        if ($rest -ne '') {
            $map[$key] = (ConvertFrom-YamlScalar -Text $rest)
        }
        else {
            if ($script:__yamlPos -lt $script:__yamlLines.Count -and $script:__yamlLines[$script:__yamlPos].Indent -gt $Indent) {
                $map[$key] = (Read-YamlBlock -Indent $script:__yamlLines[$script:__yamlPos].Indent)
            }
            elseif ($script:__yamlPos -lt $script:__yamlLines.Count -and
                    $script:__yamlLines[$script:__yamlPos].Indent -eq $Indent -and
                    $script:__yamlLines[$script:__yamlPos].Text.StartsWith('- ')) {
                $map[$key] = (Read-YamlSequence -Indent $Indent)
            }
            else { $map[$key] = $null }
        }
    }
    return $map
}

function Read-YamlSequence {
    param([Parameter(Mandatory = $true)][int]$Indent)
    $seq = @()
    while ($script:__yamlPos -lt $script:__yamlLines.Count) {
        $line = $script:__yamlLines[$script:__yamlPos]
        if ($line.Indent -ne $Indent -or -not $line.Text.StartsWith('- ')) { break }
        $item = $line.Text.Substring(2).Trim()
        $script:__yamlPos++
        if ($item -match '^[A-Za-z0-9_.\-]+\s*:') {
            # A sequence of maps: re-feed the first key at the item's own indent.
            $inner = [ordered]@{}
            $idx = $item.IndexOf(':')
            $k = $item.Substring(0, $idx).Trim()
            $v = $item.Substring($idx + 1).Trim()
            if ($v -ne '') { $inner[$k] = (ConvertFrom-YamlScalar -Text $v) } else { $inner[$k] = $null }
            $childIndent = $Indent + 2
            while ($script:__yamlPos -lt $script:__yamlLines.Count -and $script:__yamlLines[$script:__yamlPos].Indent -ge $childIndent) {
                $sub = Read-YamlMapping -Indent $script:__yamlLines[$script:__yamlPos].Indent
                foreach ($sk in $sub.Keys) { $inner[$sk] = $sub[$sk] }
            }
            $seq += , $inner
        }
        else { $seq += (ConvertFrom-YamlScalar -Text $item) }
    }
    return , $seq
}

function Format-YamlScalar {
    param([AllowNull()][AllowEmptyString()]$Value)
    if ($null -eq $Value) { return '~' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [int] -or $Value -is [long]) { return [string]$Value }
    $s = [string]$Value
    if ($s -eq '') { return "''" }
    # A numeric-looking STRING is quoted, so a reader does not silently read verify_version: "1"
    # back as an integer. Type drift across a round trip would make a report compare unequal to
    # itself.
    if ($s -match '^-?[0-9]+$') { return "'" + $s + "'" }
    if ($s -match '^[A-Za-z0-9_][A-Za-z0-9_. /=\-]*$' -and $s -notmatch '^(true|false|null|~)$') { return $s }
    return "'" + ($s -replace "'", "''") + "'"
}

function Write-YamlNode {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)][int]$Ind,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Out
    )
    $pad = ' ' * $Ind
    foreach ($k in $Node.Keys) {
        $v = $Node[$k]
        if ($v -is [System.Collections.IDictionary] -and $v.Contains('__block__')) {
            [void]$Out.Add("${pad}${k}: |")
            $body = [string]$v['__block__']
            if ($body -eq '') { [void]$Out.Add((' ' * ($Ind + 2))) }
            else {
                # A YAML literal block re-adds a newline per line, so the empty element that a
                # trailing newline produces when splitting would emit ONE EXTRA newline and the
                # round-tripped bytes would not be the bytes the command actually wrote. spec:604-605
                # asks for the output, not a near-copy of it.
                $blines = @($body -split "`r?`n")
                if ($blines.Count -gt 1 -and $blines[$blines.Count - 1] -eq '') { $blines = $blines[0..($blines.Count - 2)] }
                foreach ($bl in $blines) { [void]$Out.Add((' ' * ($Ind + 2)) + $bl) }
            }
        }
        elseif ($v -is [System.Collections.IDictionary]) {
            if ($v.Count -eq 0) { [void]$Out.Add("${pad}${k}: {}") }
            else { [void]$Out.Add("${pad}${k}:"); Write-YamlNode -Node $v -Ind ($Ind + 2) -Out $Out }
        }
        elseif ($v -isnot [string] -and $v -is [System.Collections.IEnumerable]) {
            $items = @($v)
            if ($items.Count -eq 0) { [void]$Out.Add("${pad}${k}: []") }
            else {
                [void]$Out.Add("${pad}${k}:")
                foreach ($item in $items) {
                    if ($item -is [System.Collections.IDictionary]) {
                        $first = $true
                        $sub = New-Object System.Collections.ArrayList
                        Write-YamlNode -Node $item -Ind ($Ind + 4) -Out $sub
                        foreach ($sl in $sub) {
                            if ($first) { [void]$Out.Add((' ' * ($Ind + 2)) + '- ' + $sl.Substring($Ind + 4)); $first = $false }
                            else { [void]$Out.Add($sl) }
                        }
                    }
                    else { [void]$Out.Add((' ' * ($Ind + 2)) + '- ' + (Format-YamlScalar -Value $item)) }
                }
            }
        }
        else { [void]$Out.Add("${pad}${k}: " + (Format-YamlScalar -Value $v)) }
    }
}

function ConvertTo-VerifyYaml {
    param([Parameter(Mandatory = $true)]$Report)
    $out = New-Object System.Collections.ArrayList
    Write-YamlNode -Node $Report -Ind 0 -Out $out
    return (($out -join "`n") + "`n")
}

function ConvertTo-VerifyJson {
    param([Parameter(Mandatory = $true)]$Report)
    $clone = Convert-BlockScalars -Node $Report
    return ($clone | ConvertTo-Json -Depth 24)
}

function Convert-BlockScalars {
    <# JSON has no literal block scalar; unwrap the marker so verbatim stdout survives as a string. #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Node)
    if ($Node -is [System.Collections.IDictionary]) {
        if ($Node.Contains('__block__')) { return [string]$Node['__block__'] }
        $o = [ordered]@{}
        foreach ($k in $Node.Keys) { $o[$k] = (Convert-BlockScalars -Node $Node[$k]) }
        return $o
    }
    if ($Node -isnot [string] -and $Node -is [System.Collections.IEnumerable]) {
        $a = @()
        foreach ($i in @($Node)) { $a += , (Convert-BlockScalars -Node $i) }
        return , $a
    }
    return $Node
}

function Write-TextFileUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

# =====================================================================================
# SS 8.  THE ANCHOR ARM  (spec:220-261)
# =====================================================================================

function Invoke-AnchorArm {
    param(
        [Parameter(Mandatory = $true)]$Anchors,
        [Parameter(Mandatory = $true)]$Basis,
        [Parameter(Mandatory = $true)][AllowNull()]$RecordedBasis,
        [Parameter(Mandatory = $true)]$Scoping,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    # ---- Basis comparison, and the MOVED mechanism (spec:57, 238-244, 636-638) --------------
    #
    # WHICH BASIS MEMBERS PARTICIPATE, and why, stated rather than left to a reader.
    # `tree`, `untracked_included` and `hash_class` govern HOW the recorded figures were derived.
    # If any of them differs, the comparison cannot decide and the arm reports MOVED for every
    # subject -- spec:57 exactly ("The basis differs, so the comparison cannot decide"), and
    # spec:637 ("MOVED -- the basis differs, so re-derive or re-run at the anchor").
    # `basis.head` is NOT in that test. HEAD is the anchor point, and head movement is precisely
    # what `head_sha` compares; folding it into MOVED would launder the finding the gate exists
    # for. It remains a mandatory, complete member of the emitted basis block (spec:179-180).
    $mv = Get-BasisMovedState -RecordedBasis $RecordedBasis -Basis $Basis
    $basisMoved = $mv.Moved
    $movedNote = $mv.Note

    # ---- head_sha ---------------------------------------------------------------------------
    # The `head` derivation ran ONCE, when the basis was constructed, and its command and raw
    # output are already in the derivations block. Re-issuing it here would put the same command
    # in the record twice and invite a reader to think two independent observations agreed.
    $derivedHead = [string]$Basis['head']
    $recordedHead = Get-AnchorMember -Anchors $Anchors -Name 'head_sha'
    if ($null -eq $recordedHead) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'head_sha' -Outcome 'ABSENT' -Recorded $null -Derived $derivedHead `
            -Detector 'git rev-parse HEAD' `
            -Residual 'head_sha is a universal anchor (schemas SS5): its absence is a missing anchor, never a scoped one.' | Out-Null
    }
    elseif ($basisMoved) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'head_sha' -Outcome 'MOVED' -Recorded $recordedHead -Derived $derivedHead `
            -Detector 'git rev-parse HEAD' -Residual $movedNote | Out-Null
    }
    else {
        $o = 'DIVERGED'; if ([string]$recordedHead -eq $derivedHead) { $o = 'MATCHED' }
        New-ArmEntry -Arm 'ANCHOR' -Subject 'head_sha' -Outcome $o -Recorded $recordedHead -Derived $derivedHead `
            -Detector 'git rev-parse HEAD' `
            -Residual 'Confirms which commit HEAD names. It does not attest that origin holds it, and it says nothing about the working tree.' | Out-Null
    }

    # ---- porcelain --------------------------------------------------------------------------
    # spec:228-230: compared as an ORDERED LIST OF VERBATIM LINES; an empty list means a clean
    # tree and never means the field was skipped (schemas SS5 :457).
    $treeInv = Get-AdmittedProcessInvocation -Subject 'tree'
    $d = Invoke-Derivation -Subject 'tree' -RepoRoot $RepoRoot -ProcessFile $treeInv.FilePath -ProcessArgs $treeInv.ArgumentList
    $derivedPorcelain = @()
    foreach ($l in ($d.StdOut -split "`r?`n")) { if ($l -ne '') { $derivedPorcelain += $l } }
    $recordedPorcelain = Get-AnchorMember -Anchors $Anchors -Name 'porcelain'
    $porcResidual = 'Exact and therefore noisy by construction: standing untracked residue moves it. The arm acquires no ignore-list -- an ignore-list here would be an allow-side exemption over the exact field that reports unexpected mutation (spec:254-257).'
    if ($null -eq $recordedPorcelain -and -not (Test-AnchorMemberPresent -Anchors $Anchors -Name 'porcelain')) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'porcelain' -Outcome 'ABSENT' -Recorded $null -Derived ($derivedPorcelain -join '; ') `
            -Detector 'git status --porcelain=v1' -Residual $porcResidual | Out-Null
    }
    elseif ($basisMoved) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'porcelain' -Outcome 'MOVED' -Recorded ((@($recordedPorcelain)) -join '; ') -Derived ($derivedPorcelain -join '; ') `
            -Detector 'git status --porcelain=v1' -Residual $movedNote | Out-Null
    }
    else {
        $rp = @($recordedPorcelain) | Where-Object { $null -ne $_ }
        $o = 'DIVERGED'
        if ((($rp -join "`n")) -eq (($derivedPorcelain -join "`n"))) { $o = 'MATCHED' }
        New-ArmEntry -Arm 'ANCHOR' -Subject 'porcelain' -Outcome $o -Recorded ($rp -join '; ') -Derived ($derivedPorcelain -join '; ') `
            -Detector 'git status --porcelain=v1' -Residual $porcResidual | Out-Null
    }

    # ---- the suite block, member by member (spec:224-225) ------------------------------------
    Invoke-AnchorSuiteMembers -Anchors $Anchors -Scoping $Scoping -RepoRoot $RepoRoot -BasisMoved $basisMoved -MovedNote $movedNote

    # ---- evidence_manifest -------------------------------------------------------------------
    $recordedManifest = Get-AnchorMember -Anchors $Anchors -Name 'evidence_manifest'
    $manifestFull = $null
    if ($null -ne $recordedManifest) {
        $manifestFull = $recordedManifest
        if (-not [System.IO.Path]::IsPathRooted($manifestFull)) { $manifestFull = Join-Path $RepoRoot $manifestFull }
    }
    $manifestExists = ($null -ne $manifestFull -and (Test-Path -LiteralPath $manifestFull -PathType Leaf))
    $manResidual = 'Confirms the recorded manifest path resolves to a file. It does not confirm the manifest belongs to the dispatch, and it reads no stream body -- those are the MANIFEST and PLANE-PARITY arms (spec 4.2, 4.3), not built in this increment.'
    if ($null -eq $recordedManifest) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest' -Outcome 'ABSENT' -Recorded $null -Derived $null `
            -Detector 'path resolution against the repository root' -Residual $manResidual | Out-Null
    }
    elseif (-not $manifestExists) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest' -Outcome 'ABSENT' -Recorded $recordedManifest -Derived $null `
            -Detector 'path resolution against the repository root' -Residual $manResidual | Out-Null
    }
    else {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest' -Outcome 'MATCHED' -Recorded $recordedManifest -Derived $recordedManifest `
            -Detector 'path resolution against the repository root' -Residual $manResidual | Out-Null
    }

    # ---- evidence_manifest_sha256 -------------------------------------------------------------
    $recordedSha = Get-AnchorMember -Anchors $Anchors -Name 'evidence_manifest_sha256'
    $shaResidual = 'Erratum E4: this is a WORKTREE anchor, not a clone-stable one. A verify run in a fresh clone diverges LEGITIMATELY, which is why basis.hash_class is carried and a differing class reports MOVED. A MISDECLARED hash class has no detector here (spec:238-244, 719).'
    if ($null -eq $recordedSha) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest_sha256' -Outcome 'ABSENT' -Recorded $null -Derived $null `
            -Detector 'sha256 over the manifest file' -Residual $shaResidual | Out-Null
    }
    elseif (-not $manifestExists) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest_sha256' -Outcome 'ABSENT' -Recorded $recordedSha -Derived $null `
            -Detector 'sha256 over the manifest file' -Residual $shaResidual | Out-Null
    }
    else {
        $mf = $manifestFull
        $d = Invoke-Derivation -Subject 'manifest_hash' -RepoRoot $RepoRoot `
            -InProcCommandText ("sha256 over the manifest file: " + $recordedManifest) `
            -InProcAction { Get-FileSha256Hex -Path $mf }
        $derivedSha = $d.StdOut.Trim()
        if ($basisMoved) {
            New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest_sha256' -Outcome 'MOVED' -Recorded $recordedSha -Derived $derivedSha `
                -Detector 'sha256 over the manifest file' -Residual $movedNote | Out-Null
        }
        else {
            $o = 'DIVERGED'; if ([string]$recordedSha -eq $derivedSha) { $o = 'MATCHED' }
            New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_manifest_sha256' -Outcome $o -Recorded $recordedSha -Derived $derivedSha `
                -Detector 'sha256 over the manifest file' -Residual $shaResidual | Out-Null
        }
    }

    # ---- testimony_conflict --------------------------------------------------------------------
    # spec:232-235 -- the DECIDABILITY rule: the flag fires only when a MODEL-POPULATED STRUCTURED
    # FIELD contradicts a runner anchor, never on prose. The model has no anchor fields to
    # populate; a handoff in which it supplied them is invalid rather than merely suspect, and
    # that invalidity is this arm's FINDING, not a lint.
    $recordedTC = Get-AnchorMember -Anchors $Anchors -Name 'testimony_conflict'
    $derivedTC = $false
    $tcResidual = 'Decidable only over STRUCTURED fields (schemas SS5 constraints; design SS12.2); prose contradictions are lint and never gate. The artifact carries no provenance metadata distinguishing a runner-written anchor from a model-written one, so the who-wrote-it question is undecidable from the artifact alone -- that residual has no detector here.'
    if ($null -eq $recordedTC) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'testimony_conflict' -Outcome 'ABSENT' -Recorded $null -Derived $derivedTC `
            -Detector 'the schemas SS5 decidability rule over structured fields' -Residual $tcResidual | Out-Null
    }
    elseif ($basisMoved) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'testimony_conflict' -Outcome 'MOVED' -Recorded $recordedTC -Derived $derivedTC `
            -Detector 'the schemas SS5 decidability rule over structured fields' -Residual $movedNote | Out-Null
    }
    else {
        $o = 'DIVERGED'; if ([bool]$recordedTC -eq $derivedTC) { $o = 'MATCHED' }
        New-ArmEntry -Arm 'ANCHOR' -Subject 'testimony_conflict' -Outcome $o -Recorded ([bool]$recordedTC) -Derived $derivedTC `
            -Detector 'the schemas SS5 decidability rule over structured fields' -Residual $tcResidual | Out-Null
    }
}

function Test-AnchorMemberPresent {
    param([Parameter(Mandatory = $true)]$Anchors, [Parameter(Mandatory = $true)][string]$Name)
    if ($Anchors -is [System.Collections.IDictionary]) { return $Anchors.Contains($Name) }
    return ($null -ne ($Anchors.PSObject.Properties | Where-Object { $_.Name -eq $Name }))
}

function Get-AnchorMember {
    param([Parameter(Mandatory = $true)]$Anchors, [Parameter(Mandatory = $true)][string]$Name)
    if (-not (Test-AnchorMemberPresent -Anchors $Anchors -Name $Name)) { return $null }
    if ($Anchors -is [System.Collections.IDictionary]) { return $Anchors[$Name] }
    return $Anchors.$Name
}

function Get-CanonicalSuiteCommand {
    <#
        spec:121 names "the canonical suite command from mission config" as the detector for the
        suite block. This repository's mission config declares no such command. Returned as $null;
        the caller reports the dependent members ABSENT and refuses, which is spec:59's ABSENT
        semantics exactly -- the subject the check requires does not exist. It is NOT stretched to
        NOT_APPLICABLE: nothing in the anchor-scoping rule scopes it away on a suite-requiring
        dispatch kind (spec:78-83, 245-250).
        SURFACED, NOT CURED: this is an undisclosed data-source residual of spec:121, reported at
        the increment's checkpoint for an individual ruling. No fallback command is invented here.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $missionYaml = Join-Path $RepoRoot '.mission\mission.yaml'
    if (-not (Test-Path -LiteralPath $missionYaml)) { return $null }
    foreach ($line in [System.IO.File]::ReadAllLines($missionYaml)) {
        if ($line -match '^\s*(suite_command|canonical_suite_command|test_command)\s*:\s*(.+)$') {
            return $Matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

function Invoke-AnchorSuiteMembers {
    param(
        [Parameter(Mandatory = $true)]$Anchors,
        [Parameter(Mandatory = $true)]$Scoping,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][bool]$BasisMoved,
        [Parameter(Mandatory = $true)][string]$MovedNote
    )
    $suite = Get-AnchorMember -Anchors $Anchors -Name 'suite'
    $suitePresent = (Test-AnchorMemberPresent -Anchors $Anchors -Name 'suite') -and ($null -ne $suite)

    if (-not $suitePresent) {
        if (-not $Scoping.SuiteRequired) {
            # spec:251-253 -- the SOLE NOT_APPLICABLE member. The absence is declared correct by
            # the schemas SS5 anchor-scoping constraint for this dispatch kind.
            New-ArmEntry -Arm 'ANCHOR' -Subject 'suite' -Outcome 'NOT_APPLICABLE' -Recorded $null -Derived $null `
                -Detector 'the schemas SS5 anchor-scoping constraint, read by dispatch kind' `
                -Residual 'An allow-side exemption, disclosed as one (design SS4.5 law 2). It is scoped by dispatch kind and by nothing else; the SAME absence on a suite-requiring kind is ABSENT and refuses.' | Out-Null
        }
        else {
            New-ArmEntry -Arm 'ANCHOR' -Subject 'suite' -Outcome 'ABSENT' -Recorded $null -Derived $null `
                -Detector 'the schemas SS5 anchor-scoping constraint, read by dispatch kind' `
                -Residual 'The suite block is REQUIRED for build-, rework- and close-class dispatches (schemas SS5 :458). Its absence here is a missing anchor, not a scoped one, and stretching NOT_APPLICABLE to cover it is the failure mode design SS4.5 law 2 names.' | Out-Null
        }
        return
    }

    # The block is present. Compare it MEMBER BY MEMBER (spec:224-225).
    $canonical = Get-CanonicalSuiteCommand -RepoRoot $RepoRoot
    $recordedCommand = Get-AnchorMember -Anchors $suite -Name 'command'
    $cmdResidual = 'The detector is spec:121''s "canonical suite command from mission config". This repository''s mission config declares none, so the derived side of this comparison has no data source and the member is ABSENT -- reported, never treated as satisfied and never scoped away.'
    if ($null -eq $canonical) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.command' -Outcome 'ABSENT' -Recorded $recordedCommand -Derived $null `
            -Detector 'the canonical suite command from mission config' -Residual $cmdResidual | Out-Null
    }
    elseif ($BasisMoved) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.command' -Outcome 'MOVED' -Recorded $recordedCommand -Derived $canonical `
            -Detector 'the canonical suite command from mission config' -Residual $MovedNote | Out-Null
    }
    else {
        $o = 'DIVERGED'; if ([string]$recordedCommand -eq [string]$canonical) { $o = 'MATCHED' }
        New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.command' -Outcome $o -Recorded $recordedCommand -Derived $canonical `
            -Detector 'the canonical suite command from mission config' -Residual $cmdResidual | Out-Null
    }

    # passed / failed / skipped: derivable only by RUNNING the canonical command. With no
    # canonical command there is no derived side, so each member is ABSENT on its own line.
    foreach ($m in @('passed', 'failed', 'skipped')) {
        $rec = Get-AnchorMember -Anchors $suite -Name $m
        if ($null -eq $canonical) {
            New-ArmEntry -Arm 'ANCHOR' -Subject "suite.$m" -Outcome 'ABSENT' -Recorded $rec -Derived $null `
                -Detector 'the canonical suite command from mission config, executed and its tally read' `
                -Residual 'No canonical suite command is declared in mission config, so this tally has no derived side. Reported ABSENT rather than assumed equal.' | Out-Null
        }
        else {
            New-ArmEntry -Arm 'ANCHOR' -Subject "suite.$m" -Outcome 'ABSENT' -Recorded $rec -Derived $null `
                -Detector 'the canonical suite command from mission config, executed and its tally read' `
                -Residual 'Suite EXECUTION is not implemented in increment 1; the tally has no derived side here and is reported ABSENT rather than assumed equal. This is an increment boundary, disclosed, not a scoped absence.' | Out-Null
        }
    }

    # expected_failures_matched -- A-565 member 1 / spec:245-250. Its data source is the DECLARED
    # HOME and nothing else (review findings): tools/mission-cli/config/expected-failures.yaml.
    $recEF = Get-AnchorMember -Anchors $suite -Name 'expected_failures_matched'
    $efHome = 'tools/mission-cli/config/expected-failures.yaml'
    $efPath = Join-Path $RepoRoot 'tools\mission-cli\config\expected-failures.yaml'
    $efResidual = "Declared home: $efHome (design SS12.2, schemas SS5 :471). Where it is absent the member is ABSENT and REFUSES rather than being silently treated as satisfied, and it is NOT reported NOT_APPLICABLE -- nothing in the anchor-scoping rule scopes it away, and stretching an allow-side exemption to cover a MISSING FILE is the failure mode design SS4.5 law 2 names (spec:245-250)."
    if (-not (Test-Path -LiteralPath $efPath -PathType Leaf)) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome 'ABSENT' -Recorded $recEF -Derived $null `
            -Detector "the expected-failure manifest at $efHome" -Residual $efResidual | Out-Null
    }
    elseif ($BasisMoved) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome 'MOVED' -Recorded $recEF -Derived $null `
            -Detector "the expected-failure manifest at $efHome" -Residual $MovedNote | Out-Null
    }
    else {
        # PRESENT: the member performs a real comparison. The manifest's own content is mission
        # truth (schemas SS5 :481); comparing a recorded claim against it is the real comparison
        # the absence currently prevents.
        $declared = @()
        foreach ($line in [System.IO.File]::ReadAllLines($efPath)) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $declared += $t
        }
        $derivedEF = ($declared.Count -gt 0)
        $o = 'DIVERGED'; if ([bool]$recEF -eq $derivedEF) { $o = 'MATCHED' }
        New-ArmEntry -Arm 'ANCHOR' -Subject 'suite.expected_failures_matched' -Outcome $o -Recorded $recEF -Derived $derivedEF `
            -Detector "the expected-failure manifest at $efHome" `
            -Residual "Compares the recorded claim against the declared home's content. The manifest's CONTENT is mission truth (schemas SS5 :481); this arm does not judge whether the declared expectations are themselves correct." | Out-Null
    }
}

# =====================================================================================
# SS 8b.  THE ORIGIN-ATTESTATION ARM  (spec:371-416)
# =====================================================================================
#
# THE TWO DISAGREEMENT CASES ARE KEPT APART BY SUBJECT, AND ONLY BY SUBJECT.
# spec:414-416 requires that "channels disagreeing with each other" and "channels agreeing with
# each other and disagreeing with the claim" stay DISTINGUISHABLE IN refused_by rather than
# merged, and refused_by names <arm>/<subject> (spec:177-178). Two findings that must stay apart
# therefore need two subjects.
#
# They cannot be told apart by WHICH channel entries refuse. "Channels disagree and neither
# matches the claim" refuses both channel entries; "channels agree and both differ from the
# claim" also refuses both channel entries. A reader comparing refused_by membership would see
# the same list twice. The comparison entry's subject is the only thing that carries the
# distinction, which is why it is a lookup and not a formatted string.
$script:OriginClaimSubject   = 'origin_tip'
$script:OriginChannelSubject = 'origin_tip.channels'

function Get-CurrentBranch {
    <#
        Resolved from --branch, else by READING .git/HEAD AS A FILE. `git branch` and
        `git rev-parse --abbrev-ref HEAD` are not members of the spec:115-126 admitted set, and
        this program issues no command outside it -- the same rule Get-HashClass follows for
        `git config`. A detached HEAD yields $null: there is no branch to ask origin about, and
        inventing one would be asking a question the artifact never posed.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$Flag
    )
    if (-not [string]::IsNullOrWhiteSpace($Flag)) { return $Flag.Trim() }
    $headFile = Join-Path $RepoRoot '.git\HEAD'
    if (-not (Test-Path -LiteralPath $headFile)) { return $null }
    $t = ([System.IO.File]::ReadAllText($headFile)).Trim()
    if ($t -match '^ref:\s*refs/heads/(.+)$') { return $Matches[1].Trim() }
    return $null
}

function Get-OriginRemoteUrl {
    <# Read as a file, for the same reason as above: `git remote -v` is not an admitted row. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $cfg = Join-Path $RepoRoot '.git\config'
    if (-not (Test-Path -LiteralPath $cfg)) { return $null }
    $inOrigin = $false
    foreach ($line in [System.IO.File]::ReadAllLines($cfg)) {
        $t = $line.Trim()
        if ($t -match '^\[remote\s+"([^"]+)"\]') { $inOrigin = ($Matches[1] -eq 'origin'); continue }
        if ($t.StartsWith('[')) { $inOrigin = $false; continue }
        if ($inOrigin -and $t -match '^url\s*=\s*(.+)$') { return $Matches[1].Trim() }
    }
    return $null
}

function Get-OriginEndpointParts {
    <# Host, owner and repository, for composing the host's ref endpoint. #>
    param([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    $u = $Url.Trim()
    if ($u -match '^https?://(?<host>[^/:@]+)(?::\d+)?/(?<owner>[^/]+)/(?<repo>.+?)(?:\.git)?/?$') {
        return [pscustomobject]@{ HostName = $Matches['host']; Owner = $Matches['owner']; Repo = $Matches['repo'] }
    }
    if ($u -match '^(?:ssh://)?[^@/]+@(?<host>[^:/]+)[:/](?<owner>[^/]+)/(?<repo>.+?)(?:\.git)?/?$') {
        return [pscustomobject]@{ HostName = $Matches['host']; Owner = $Matches['owner']; Repo = $Matches['repo'] }
    }
    return $null
}

function Get-OriginApiInvocation {
    <#
        R3 ENFORCED STRUCTURALLY, NOT REMEMBERED. `-i` / `--include` would return response
        HEADERS, which can carry auth-adjacent material; this arm needs the ref payload. The
        composed vector is checked against the forbidden set before it is returned, so adding the
        flag anywhere makes verify fail rather than quietly widening what gets captured.
        Admission is still decided by the spec:115-126 table -- Get-AdmittedSubject throws for a
        subject that is not a row -- but the concrete invocation is composed here because the
        table's row for this subject is a DESCRIPTION of an endpoint, not a command line.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Branch
    )
    [void](Get-AdmittedSubject -Subject 'origin_api')
    $argv = @('api', '--hostname', $HostName, "repos/$Owner/$Repo/git/ref/heads/$Branch")
    foreach ($a in $argv) {
        if ($script:ForbiddenApiFlags -contains $a) {
            throw "MALFORMED: the API channel invocation carries '$a'. Response headers may carry auth-adjacent material; this arm needs the ref payload, not the headers."
        }
    }
    return [pscustomobject]@{ FilePath = 'gh'; ArgumentList = $argv }
}

function Get-OriginClaim {
    <#
        THE RECORDED SIDE: ONE DECLARED, OPTIONAL HOME.
        See the file header. One named home is read: runner_anchors.origin_tip, declared optional
        (string or null) by schemas SS5 :462 since an amendment to LAM-ACCEPT. It
        is read from the runner-anchor block rather than from the artifact's prose because an
        origin claim needs exactly the provenance the rest of that block has -- written by the
        runner from evidence, never by the model (schemas SS5 :478) -- and because prose
        contradictions are lint and never gate (spec:85-87). $null means the artifact makes NO
        origin claim -- the member is absent, a bare null, or blank -- which is not a missing
        anchor: schemas SS5 :481 says neither its absence nor its null is one.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Anchors)
    if ($null -eq $Anchors) { return $null }
    if (-not (Test-AnchorMemberPresent -Anchors $Anchors -Name 'origin_tip')) { return $null }
    $v = Get-AnchorMember -Anchors $Anchors -Name 'origin_tip'
    if ($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)) { return $null }
    return ([string]$v).Trim()
}

function Get-LsRemoteSha {
    <# The ref line for THIS branch, or $null. An empty answer is not a sha and never becomes one. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$StdOut, [Parameter(Mandatory = $true)][string]$Branch)
    foreach ($line in ($StdOut -split "`r?`n")) {
        if ($line -match ('^([0-9a-fA-F]{40})\s+' + [regex]::Escape("refs/heads/$Branch") + '\s*$')) { return $Matches[1].ToLowerInvariant() }
    }
    return $null
}

function Get-ApiRefSha {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$StdOut)
    if ([string]::IsNullOrWhiteSpace($StdOut)) { return $null }
    try { $o = ConvertFrom-Json -InputObject $StdOut } catch { return $null }
    if ($null -eq $o) { return $null }
    if (-not ($o.PSObject.Properties | Where-Object { $_.Name -eq 'object' })) { return $null }
    $obj = $o.object
    if ($null -eq $obj) { return $null }
    if (-not ($obj.PSObject.Properties | Where-Object { $_.Name -eq 'sha' })) { return $null }
    $s = [string]$obj.sha
    if ($s -match '^[0-9a-fA-F]{40}$') { return $s.ToLowerInvariant() }
    return $null
}

function Get-HttpStatusFromStream {
    <#
        The status is read from the tool's OWN error text, which this arm captures anyway under
        spec:109-113. It is NOT obtained by adding `-i`/`--include`, which R3 forbids -- reading
        what the channel already emitted costs nothing and widens no capture surface.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $m = [regex]::Match($Text, '\(HTTP (\d{3})\)')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $null
}

function Test-StructuralViolation {
    <#
        The failures this program must never absorb into an outcome. Each of these prefixes is
        raised only where the program has been asked to do something it may not do -- issue a
        command outside the spec:115-126 set, emit a malformed arm entry, or record a stream
        carrying a credential. They are the spec:198 did-not-complete path, and no channel-level
        handler may convert one into a verdict about origin.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message)
    foreach ($p in @('HALT (credential)', 'MALFORMED:', 'INTERNAL:')) {
        if ($Message.StartsWith($p)) { return $true }
    }
    return $false
}

function New-ChannelState {
    param([Parameter(Mandatory = $true)][string]$Status, [AllowNull()][string]$Sha, [Parameter(Mandatory = $true)][string]$Why)
    return [pscustomobject]@{ Status = $Status; Sha = $Sha; Why = $Why }
}

function Invoke-OriginArm {
    <#
        Returns an object saying whether the arm ENGAGED. Engagement is decided by whether the
        artifact makes an origin claim; once engaged, BOTH channels always run and neither is
        ever skipped for being unavailable (spec:378, A-564:62-63).
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Anchors,
        [Parameter(Mandatory = $true)][bool]$BasisMoved,
        [Parameter(Mandatory = $true)][string]$MovedNote,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$BranchFlag
    )

    $claim = Get-OriginClaim -Anchors $Anchors
    if ($null -eq $claim) {
        return [pscustomobject]@{
            Engaged = $false
            Reason  = 'the artifact carries no runner_anchors.origin_tip value -- the member is absent, a bare null, or blank -- so it makes no claim about origin and there is nothing for this arm to compare (spec:373). schemas SS5 declares origin_tip OPTIONAL (:462, string or null; LAM-ACCEPT amendment 42) and :481 says neither its absence nor its null is a missing anchor, so it is NOT reported ABSENT.'
        }
    }

    # ---- the ceiling, stated in the arm's own words (A-564:37-43, :57-58; spec:507-517) --------
    # OPEN-1 as ruled: the residual states the CLASS in the spec's own terms. The concrete host
    # configuration that puts this run in that class is recorded in basis.disclosed_residuals,
    # where host facts belong and where they can go stale without weakening the arm's statement.
    $ceiling = 'MIDDLE RUNG, and this arm does not possess the rung above it. Both channels ran on the SESSION''S OWN HOST, with its PATH, its network path and its CREDENTIAL STORE, so they do not have independent failure modes: a compromised or merely misconfigured host defeats the git channel and the API channel AT ONCE, which is exactly the shared failure mode same-host channels cannot rule out (spec:507-513). This raises "the model said so" to "the harness recorded what ran here"; it does NOT make the observer independent of the observed. Presenting it as origin-side proof would be the overclaim class this program exists to stop (spec:515-517). Operator browser confirmation of the origin tip remains standing law and remains the final layer (spec:394-396). This arm detects DIVERGENCE, NOT AUTHORIZATION: that origin holds a commit says nothing about whether the push was authorized (spec:402-405).'
    $exitLoad = ' exit_code is LOAD-BEARING here rather than metadata: `git ls-remote` conflates unreachable with absent (spec:73-76, 385-387), and the ONLY thing separating them is a non-zero exit with no ref line. A defaulted or null exit_code would not be a metadata gap -- it would REMOVE the detector.'

    $branch = Get-CurrentBranch -RepoRoot $RepoRoot -Flag $BranchFlag

    # ---- both channels, each invoked EXACTLY ONCE ---------------------------------------------
    # There is no retry anywhere in this function. spec:386-387 -- verify "does not retry into a
    # verdict" -- is a property of the shape: a channel is asked once, and its answer or its
    # silence is what gets reported.
    if ($null -eq $branch) {
        $gitState = New-ChannelState -Status 'SILENT' -Sha $null -Why 'no branch could be resolved (--branch absent and HEAD is not on a branch), so no ref could be asked for'
        $apiState = New-ChannelState -Status 'SILENT' -Sha $null -Why 'no branch could be resolved (--branch absent and HEAD is not on a branch), so no endpoint could be composed'
        $branchLabel = '<unresolved>'
    }
    else {
        $branchLabel = $branch

        # --- channel 1: the git protocol ---
        try {
            $inv = Get-AdmittedProcessInvocation -Subject 'origin_git' -Tokens @{ branch = $branch }
            $r = Invoke-Derivation -Subject 'origin_git' -RepoRoot $RepoRoot -ProcessFile $inv.FilePath -ProcessArgs $inv.ArgumentList
            if ($r.ExitCode -ne 0) {
                $gitState = New-ChannelState -Status 'SILENT' -Sha $null -Why "git ls-remote exited $($r.ExitCode) without answering"
            }
            else {
                $s = Get-LsRemoteSha -StdOut $r.StdOut -Branch $branch
                if ($null -eq $s) { $gitState = New-ChannelState -Status 'NO_REF' -Sha $null -Why 'git ls-remote answered (exit 0) and origin carries no such ref' }
                else { $gitState = New-ChannelState -Status 'ANSWERED' -Sha $s -Why 'git ls-remote returned the ref line' }
            }
        }
        catch {
            # A STRUCTURAL VIOLATION IS NOT A CHANNEL PROBLEM AND MUST NOT BE LAUNDERED INTO ONE.
            # UNREACHABLE means "a channel the check requires could not be contacted" (spec:58).
            # A program that tried to issue a command outside the admitted set, or that saw a
            # credential where none may appear, has not failed to reach origin -- it has done
            # something it may not do, and that is the did-not-complete path (spec:198). Catching
            # it here would turn the exclusion into a soft refusal that reads like a network blip.
            if (Test-StructuralViolation -Message ([string]$_.Exception.Message)) { throw }
            $gitState = New-ChannelState -Status 'SILENT' -Sha $null -Why "the git channel could not be invoked: $($_.Exception.Message)"
        }

        # --- channel 2: the host's ref endpoint. NEVER SKIPPED. ---
        # A-564:62-63 FAILS an API channel that is SKIPPED when unavailable rather than reported
        # UNREACHABLE -- the silence-as-consent shape spec:406-407 names. Every path below that
        # cannot produce an answer produces SILENT, and SILENT becomes UNREACHABLE. None of them
        # returns early and none of them omits the entry.
        $originUrl = Get-OriginRemoteUrl -RepoRoot $RepoRoot
        if ($null -ne $originUrl -and (Test-UrlUserInfo -Text $originUrl)) {
            Assert-NoUserInfo -Where 'the configured origin remote URL'
        }
        $parts = Get-OriginEndpointParts -Url $originUrl
        if ($null -eq $parts) {
            $apiState = New-ChannelState -Status 'SILENT' -Sha $null -Why 'no origin remote URL could be resolved into host/owner/repository, so the host ref endpoint could not be composed'
        }
        else {
            try {
                $apiInv = Get-OriginApiInvocation -HostName $parts.HostName -Owner $parts.Owner -Repo $parts.Repo -Branch $branch
                $ra = Invoke-Derivation -Subject 'origin_api' -RepoRoot $RepoRoot -ProcessFile $apiInv.FilePath -ProcessArgs $apiInv.ArgumentList
                $sa = Get-ApiRefSha -StdOut $ra.StdOut
                if ($ra.ExitCode -eq 0 -and $null -ne $sa) {
                    $apiState = New-ChannelState -Status 'ANSWERED' -Sha $sa -Why 'the host ref endpoint returned the ref object'
                }
                else {
                    $status = Get-HttpStatusFromStream -Text $ra.StdErr
                    if ($null -eq $status) { $status = Get-HttpStatusFromStream -Text $ra.StdOut }
                    if ($status -eq 404) {
                        $apiState = New-ChannelState -Status 'NO_REF' -Sha $null -Why 'the host answered 404: the ref is not present on origin'
                    }
                    else {
                        # CONSERVATIVE ON PURPOSE. An unparseable failure is UNREACHABLE, never
                        # ABSENT: claiming the ref is absent on the strength of a failure we could
                        # not read would be the conflation spec:73-76 forbids, in the direction
                        # that reads as a finding about origin rather than about the channel.
                        $w = 'the host ref endpoint did not answer'
                        if ($null -ne $status) { $w = "the host ref endpoint failed with HTTP $status" }
                        $apiState = New-ChannelState -Status 'SILENT' -Sha $null -Why $w
                    }
                }
            }
            catch {
                # Same rule as the git channel above, for the same reason.
                if (Test-StructuralViolation -Message ([string]$_.Exception.Message)) { throw }
                $apiState = New-ChannelState -Status 'SILENT' -Sha $null -Why "the API channel could not be invoked: $($_.Exception.Message)"
            }
        }
    }

    # ---- per-channel entries (spec:412-413) ----------------------------------------------------
    $gitDetector = "git ls-remote origin refs/heads/$branchLabel"
    $apiDetector = "the repository host's ref endpoint for heads/$branchLabel"
    New-OriginChannelEntry -Subject 'origin_git' -State $gitState -Claim $claim -Detector $gitDetector -Ceiling ($ceiling + $exitLoad) -BasisMoved $BasisMoved -MovedNote $MovedNote
    New-OriginChannelEntry -Subject 'origin_api' -State $apiState -Claim $claim -Detector $apiDetector -Ceiling ($ceiling + $exitLoad) -BasisMoved $BasisMoved -MovedNote $MovedNote

    # ---- the comparison against the artifact's claim (spec:413-416) ----------------------------
    # ORDER IS THE SEMANTICS. A silent channel short-circuits to UNREACHABLE BEFORE any surviving
    # channel's sha is consulted -- that is what "no retry produces a verdict" means here: the
    # arm never falls back to the channel that did answer and calls the result agreement.
    $subject = $script:OriginClaimSubject
    $derivedText = $null
    if ($gitState.Status -eq 'SILENT' -or $apiState.Status -eq 'SILENT') {
        $outcome = 'UNREACHABLE'
        $why = "git: $($gitState.Why); api: $($apiState.Why)"
        $residual = "A channel that fails to answer is UNREACHABLE, not ABSENT and not DIVERGED, and it refuses; SILENCE IS NOT CONSENT (spec:385-387, 406-407). The surviving channel's answer was NOT promoted into a verdict and no retry was made. $why $ceiling$exitLoad"
    }
    elseif ($gitState.Status -eq 'NO_REF' -or $apiState.Status -eq 'NO_REF') {
        $outcome = 'ABSENT'
        $residual = "A channel answered that origin carries no such ref. That is ABSENT -- the subject the check requires does not exist -- and it is kept distinct from UNREACHABLE, which is the distinction this arm is load-bearing on (spec:73-76). $ceiling$exitLoad"
    }
    elseif ($gitState.Sha -ne $apiState.Sha) {
        # CASE 1: the channels disagree WITH EACH OTHER.
        $subject = $script:OriginChannelSubject
        $outcome = 'DIVERGED'
        $derivedText = "git=$($gitState.Sha) api=$($apiState.Sha)"
        $residual = "THE CHANNELS DISAGREE WITH EACH OTHER. Verify refuses and escalates with both raw outputs, and does NOT pick a winner: choosing between channels selected for independence destroys the property the second channel exists for (spec:388-390). This is reported on its own subject so it stays distinguishable in refused_by from channels that agree with each other and disagree with the claim (spec:414-416). $ceiling$exitLoad"
    }
    elseif ($BasisMoved) {
        $outcome = 'MOVED'
        $derivedText = $gitState.Sha
        $residual = $MovedNote
    }
    elseif ($gitState.Sha -eq $claim) {
        $outcome = 'MATCHED'
        $derivedText = $gitState.Sha
        $residual = "Both channels answered, agree with each other and agree with the claim. $ceiling$exitLoad"
    }
    else {
        # CASE 2: the channels AGREE with each other and disagree with the CLAIM.
        $outcome = 'DIVERGED'
        $derivedText = $gitState.Sha
        $residual = "THE CHANNELS AGREE WITH EACH OTHER AND DISAGREE WITH THE ARTIFACT'S CLAIM -- the stale-claim case this arm exists for (spec:519-538). Reported on the claim subject, distinct from the channel-disagreement subject, so refused_by keeps the two cases apart rather than merging them (spec:414-416). $ceiling$exitLoad"
    }

    New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject $subject -Outcome $outcome -Recorded $claim -Derived $derivedText `
        -Detector "$gitDetector + $apiDetector" -Residual $residual | Out-Null

    return [pscustomobject]@{ Engaged = $true; Reason = $null }
}

function New-OriginChannelEntry {
    <# spec:412 -- one entry per channel, each carrying the raw ref line it received. #>
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$Claim,
        [Parameter(Mandatory = $true)][string]$Detector,
        [Parameter(Mandatory = $true)][string]$Ceiling,
        [Parameter(Mandatory = $true)][bool]$BasisMoved,
        [Parameter(Mandatory = $true)][string]$MovedNote
    )
    if ($State.Status -eq 'SILENT') {
        New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject $Subject -Outcome 'UNREACHABLE' -Recorded $Claim -Derived $null `
            -Detector $Detector -Residual ("This channel did not answer: $($State.Why). UNREACHABLE, never ABSENT and never DIVERGED; it refuses and is not retried into a verdict (spec:385-387). It was NOT skipped for being unavailable -- being reported rather than skipped is the whole of A-564:62-63. $Ceiling") | Out-Null
        return
    }
    if ($State.Status -eq 'NO_REF') {
        New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject $Subject -Outcome 'ABSENT' -Recorded $Claim -Derived $null `
            -Detector $Detector -Residual ("This channel answered, and origin carries no such ref: $($State.Why). ABSENT, kept distinct from UNREACHABLE (spec:73-76). $Ceiling") | Out-Null
        return
    }
    if ($BasisMoved) {
        New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject $Subject -Outcome 'MOVED' -Recorded $Claim -Derived $State.Sha `
            -Detector $Detector -Residual $MovedNote | Out-Null
        return
    }
    $o = 'DIVERGED'; if ($State.Sha -eq $Claim) { $o = 'MATCHED' }
    New-ArmEntry -Arm 'ORIGIN-ATTESTATION' -Subject $Subject -Outcome $o -Recorded $Claim -Derived $State.Sha `
        -Detector $Detector -Residual ("This channel answered: $($State.Why). $Ceiling") | Out-Null
}

# =====================================================================================
# SS 8c.  THE SCHEMA VALIDATOR  (spec:126, 269-270; schemas SS12 NORMATIVE)
# =====================================================================================
#
# WHY THIS EXISTS AT ALL, AND WHY IT IS HAND-WRITTEN. spec:275-279 makes schema validation a check
# verify OWES, independent of state derivation: "a log line that is valid JSON but carries none of
# the declared fields yields a manifest that FAILS SCHEMA VALIDATION WHILE STILL DERIVING
# FINALIZED. An implementation that runs only the state derivation and reports the artifact good
# has reintroduced the defect the resolution recorded." That is a registered finding, and it is the shape A-565's
# second member is about. PowerShell 5.1 ships no `Test-Json` (it arrives in PowerShell 6) and this
# program takes no dependency it cannot read, so the validator is here, in the open.
#
# REACH, STATED RATHER THAN IMPLIED -- this is a SUBSET validator, not a draft-07 implementation.
# It implements exactly the keywords docs/framework/evidence-manifest.schema.json uses:
#   type (single or list), const, enum, pattern, minLength, minimum,
#   required, properties, additionalProperties:false, items, allOf, not, oneOf.
# It does NOT implement $ref, $defs, dependencies, if/then/else, anyOf, propertyNames, format,
# maxLength, maximum, uniqueItems, or numeric multipleOf. THE CONSEQUENCE IS DISCLOSED AND IS THE
# HONEST DIRECTION TO WORRY ABOUT: a future schema revision using an unimplemented keyword would
# have that keyword SILENTLY IGNORED, which fails OPEN. It is not cured here -- curing it means
# either a real draft-07 engine or a dependency -- and it is carried as a stated residual on every
# entry this validator decides.
#
# FIRST FAILING POINTER, MADE DETERMINISTIC. spec:307 asks for "the schema-validation verdict with
# its FIRST failing pointer", so "first" must not depend on hashtable enumeration order. Keywords
# are evaluated in the fixed order written below, `properties` in the schema's own declaration
# order, and `items` in array index order. The pointer is RFC 6901.

function Test-JsonMember {
    <# PRESENT, as distinct from non-null. The library's Get-EntryField deliberately collapses the
       two (it returns a default for a null value); a validator that collapsed them could not tell
       `required` from "present and null", so it gets its own probe rather than reusing that one. #>
    param([AllowNull()]$Object, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $Object) { return $false }
    if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
    if ($null -eq $Object.PSObject) { return $false }
    return (@($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }).Count -gt 0)
}

function Get-JsonMember {
    <#
        ARRAY-PRESERVING BY CONSTRUCTION, and this is not a style point -- it was a live defect
        caught by this increment's own first drive. PowerShell UNROLLS an array returned from a
        function: a one-element `entries` came back as the bare entry and an empty `entries` came
        back as $null, so the validator read "requires array, instance is object" against a
        perfectly good manifest and the registered finding's drive failed for the wrong reason. The comma wrap
        returns a one-element array whose single element IS the array, which unrolling then
        restores. Scalars are returned as themselves so the caller's type test still sees a scalar.
    #>
    param([AllowNull()]$Object, [Parameter(Mandatory = $true)][string]$Name)
    if (-not (Test-JsonMember -Object $Object -Name $Name)) { return $null }
    $v = $null
    if ($Object -is [System.Collections.IDictionary]) { $v = $Object[$Name] }
    else { $v = $Object.$Name }
    if ($null -ne $v -and $v -is [System.Array]) { return , $v }
    return $v
}

function Test-JsonType {
    param([AllowNull()]$Value, [Parameter(Mandatory = $true)][string]$Type)
    if ($Type -eq 'null')    { return ($null -eq $Value) }
    if ($Type -eq 'boolean') { return ($Value -is [bool]) }
    if ($Type -eq 'string')  { return ($Value -is [string]) }
    if ($Type -eq 'integer') { return (($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [int16]) -or ($Value -is [byte])) }
    if ($Type -eq 'number')  { return (($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [decimal]) -or ($Value -is [single])) }
    if ($Type -eq 'array')   { return (($null -ne $Value) -and ($Value -is [System.Array])) }
    if ($Type -eq 'object') {
        if ($null -eq $Value) { return $false }
        if ($Value -is [System.Collections.IDictionary]) { return $true }
        if (($Value -is [string]) -or ($Value -is [System.Array]) -or ($Value -is [ValueType])) { return $false }
        return ($Value.PSObject.TypeNames -contains 'System.Management.Automation.PSCustomObject')
    }
    return $false
}

function Get-JsonTypeName {
    param([AllowNull()]$Value)
    foreach ($t in @('null', 'boolean', 'string', 'integer', 'number', 'array', 'object')) {
        if (Test-JsonType -Value $Value -Type $t) { return $t }
    }
    return 'unknown'
}

function ConvertTo-JsonPointerToken {
    <# RFC 6901 escaping: `~` becomes `~0` and `/` becomes `~1`, in that order. #>
    param([Parameter(Mandatory = $true)][string]$Name)
    return (($Name -replace '~', '~0') -replace '/', '~1')
}

function New-SchemaFailure {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Pointer, [Parameter(Mandatory = $true)][string]$Message)
    $p = $Pointer
    if ([string]::IsNullOrEmpty($p)) { $p = '' }
    return [pscustomobject]@{ pointer = $p; message = $Message }
}

function Test-JsonSchemaInstance {
    <# $null when the instance validates; otherwise the FIRST failure, with its RFC 6901 pointer. #>
    param([AllowNull()]$Instance, [Parameter(Mandatory = $true)]$Schema, [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Pointer)

    # THE ASSIGN-THEN-NORMALISE IDIOM, USED AT EVERY LIST-VALUED READ BELOW, AND IT IS NOT STYLE.
    # `@(Get-JsonMember ...)` LOOKS right and is WRONG. Get-JsonMember comma-wraps an array so that
    # ASSIGNMENT preserves it; @() around the CALL then collects that wrap as a single item and
    # yields a one-element list whose element is the whole array. This increment's own first drive
    # battery caught that exact shape, so every list read here assigns first and normalises second.
    if (Test-JsonMember -Object $Schema -Name 'type') {
        $typeRaw = Get-JsonMember -Object $Schema -Name 'type'
        $types = @($typeRaw)
        $typeOk = $false
        foreach ($t in $types) { if (Test-JsonType -Value $Instance -Type ([string]$t)) { $typeOk = $true; break } }
        if (-not $typeOk) {
            return (New-SchemaFailure $Pointer ("type mismatch: schema requires " + (($types | ForEach-Object { [string]$_ }) -join ' or ') + ", instance is " + (Get-JsonTypeName $Instance)))
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'const') {
        $c = Get-JsonMember -Object $Schema -Name 'const'
        if ([string]$Instance -ne [string]$c) {
            return (New-SchemaFailure $Pointer ("const mismatch: schema requires '" + [string]$c + "', instance is '" + [string]$Instance + "'"))
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'enum') {
        $enumRaw = Get-JsonMember -Object $Schema -Name 'enum'
        $vals = @($enumRaw)
        $hit = $false
        foreach ($v in $vals) { if ([string]$Instance -eq [string]$v) { $hit = $true; break } }
        if (-not $hit) {
            return (New-SchemaFailure $Pointer ("enum mismatch: schema admits [" + (($vals | ForEach-Object { [string]$_ }) -join ', ') + "], instance is '" + [string]$Instance + "'"))
        }
    }

    if ((Test-JsonMember -Object $Schema -Name 'pattern') -and ($Instance -is [string])) {
        $pat = [string](Get-JsonMember -Object $Schema -Name 'pattern')
        if ($Instance -notmatch $pat) {
            return (New-SchemaFailure $Pointer ("pattern mismatch: instance does not match " + $pat))
        }
    }

    if ((Test-JsonMember -Object $Schema -Name 'minLength') -and ($Instance -is [string])) {
        $ml = [int](Get-JsonMember -Object $Schema -Name 'minLength')
        if ($Instance.Length -lt $ml) {
            return (New-SchemaFailure $Pointer ("minLength: schema requires at least $ml character(s), instance has " + $Instance.Length))
        }
    }

    if ((Test-JsonMember -Object $Schema -Name 'minimum') -and (Test-JsonType -Value $Instance -Type 'number')) {
        $mn = Get-JsonMember -Object $Schema -Name 'minimum'
        if ([double]$Instance -lt [double]$mn) {
            return (New-SchemaFailure $Pointer ("minimum: schema requires at least " + [string]$mn + ", instance is " + [string]$Instance))
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'required') {
        $requiredRaw = Get-JsonMember -Object $Schema -Name 'required'
        foreach ($r in @($requiredRaw)) {
            $rn = [string]$r
            if (-not (Test-JsonMember -Object $Instance -Name $rn)) {
                return (New-SchemaFailure ($Pointer + '/' + (ConvertTo-JsonPointerToken $rn)) 'required property is missing')
            }
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'properties') {
        $props = Get-JsonMember -Object $Schema -Name 'properties'
        foreach ($p in @($props.PSObject.Properties)) {
            if (Test-JsonMember -Object $Instance -Name $p.Name) {
                $sub = Test-JsonSchemaInstance -Instance (Get-JsonMember -Object $Instance -Name $p.Name) -Schema $p.Value -Pointer ($Pointer + '/' + (ConvertTo-JsonPointerToken $p.Name))
                if ($null -ne $sub) { return $sub }
            }
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'additionalProperties') {
        $ap = Get-JsonMember -Object $Schema -Name 'additionalProperties'
        if (($ap -is [bool]) -and (-not $ap) -and (Test-JsonType -Value $Instance -Type 'object')) {
            $declared = @()
            if (Test-JsonMember -Object $Schema -Name 'properties') {
                $declared = @((Get-JsonMember -Object $Schema -Name 'properties').PSObject.Properties | ForEach-Object { $_.Name })
            }
            foreach ($ip in @($Instance.PSObject.Properties)) {
                if ($declared -notcontains $ip.Name) {
                    return (New-SchemaFailure ($Pointer + '/' + (ConvertTo-JsonPointerToken $ip.Name)) 'additional property is not permitted (additionalProperties is false)')
                }
            }
        }
    }

    if ((Test-JsonMember -Object $Schema -Name 'items') -and (Test-JsonType -Value $Instance -Type 'array')) {
        $isch = Get-JsonMember -Object $Schema -Name 'items'
        $arr = @($Instance)
        for ($i = 0; $i -lt $arr.Count; $i++) {
            $sub = Test-JsonSchemaInstance -Instance $arr[$i] -Schema $isch -Pointer ($Pointer + '/' + $i)
            if ($null -ne $sub) { return $sub }
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'allOf') {
        $allOfRaw = Get-JsonMember -Object $Schema -Name 'allOf'
        foreach ($s in @($allOfRaw)) {
            $sub = Test-JsonSchemaInstance -Instance $Instance -Schema $s -Pointer $Pointer
            if ($null -ne $sub) { return $sub }
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'not') {
        $sub = Test-JsonSchemaInstance -Instance $Instance -Schema (Get-JsonMember -Object $Schema -Name 'not') -Pointer $Pointer
        if ($null -eq $sub) {
            return (New-SchemaFailure $Pointer 'instance matches a subschema the schema forbids (not)')
        }
    }

    if (Test-JsonMember -Object $Schema -Name 'oneOf') {
        $oneOfRaw = Get-JsonMember -Object $Schema -Name 'oneOf'
        $branches = @($oneOfRaw)
        $matchedCount = 0
        $why = @()
        for ($i = 0; $i -lt $branches.Count; $i++) {
            $sub = Test-JsonSchemaInstance -Instance $Instance -Schema $branches[$i] -Pointer $Pointer
            if ($null -eq $sub) { $matchedCount++ }
            else {
                $title = "branch $i"
                if (Test-JsonMember -Object $branches[$i] -Name 'title') { $title = [string](Get-JsonMember -Object $branches[$i] -Name 'title') }
                $why += ('{' + $title + '} ' + $sub.pointer + ' -- ' + $sub.message)
            }
        }
        if ($matchedCount -eq 0) {
            # EVERY branch reason is carried, not just one. A oneOf failure whose report names a
            # single arbitrary branch tells a reader nothing about why the other shapes were
            # rejected, and the declared-variant set is exactly what the reader needs to see.
            return (New-SchemaFailure $Pointer ('matches NONE of the ' + $branches.Count + ' declared variants: ' + ($why -join ' | ')))
        }
        if ($matchedCount -gt 1) {
            return (New-SchemaFailure $Pointer ("matches $matchedCount of the " + $branches.Count + ' declared variants; oneOf admits exactly one'))
        }
    }

    return $null
}

function Get-ManifestSchemaPath {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    return (Join-Path $RepoRoot 'docs\framework\evidence-manifest.schema.json')
}

function Test-ManifestAgainstSchema {
    <#
        The spec:126 row, executed. Returns a verdict object; it never throws for a bad manifest,
        because an invalid manifest is a FINDING and not a crash. It DOES report an unreadable
        SCHEMA as its own distinct verdict -- the normative document being missing is a fact about
        this checkout, not a fact about the manifest, and reporting the manifest invalid on that
        basis would be a finding manufactured out of a missing file.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$SchemaPath
    )
    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        return [pscustomobject]@{ verdict = 'SCHEMA_UNREADABLE'; pointer = $null
                                  detail = "the normative schema is not on disk at '$SchemaPath'" }
    }
    $schema = $null
    try { $schema = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($SchemaPath)) }
    catch {
        return [pscustomobject]@{ verdict = 'SCHEMA_UNREADABLE'; pointer = $null
                                  detail = "the normative schema at '$SchemaPath' is not parsable as JSON: $($_.Exception.Message)" }
    }
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        return [pscustomobject]@{ verdict = 'NO_MANIFEST'; pointer = $null
                                  detail = "no manifest on disk at '$ManifestPath'" }
    }
    $doc = $null
    try { $doc = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($ManifestPath)) }
    catch {
        # An unparsable manifest FAILS validation -- it is not schema-valid by any reading -- and
        # the pointer is the document root, which is where the failure is.
        return [pscustomobject]@{ verdict = 'INVALID'; pointer = ''
                                  detail = "the manifest is not parsable as JSON: $($_.Exception.Message)" }
    }
    $fail = Test-JsonSchemaInstance -Instance $doc -Schema $schema -Pointer ''
    if ($null -eq $fail) {
        return [pscustomobject]@{ verdict = 'VALID'; pointer = $null; detail = 'validates against every keyword this validator implements' }
    }
    $ptr = $fail.pointer
    if ([string]::IsNullOrEmpty($ptr)) { $ptr = '' }
    return [pscustomobject]@{ verdict = 'INVALID'; pointer = $ptr; detail = $fail.message }
}

# =====================================================================================
# SS 8d.  THE MANIFEST ARM  (spec:263-311, and the ruled GREW clause)
# =====================================================================================
#
# TWO SUBJECTS, AND THE REASON IS THE REGISTERED FINDING ITSELF. spec:275-279 makes state derivation and schema
# validation two checks NEITHER OF WHICH SUBSUMES THE OTHER. refused_by names <arm>/<subject>
# (spec:177-178), so two findings that must stay apart need two subjects -- exactly the reasoning
# the ORIGIN arm's two disagreement cases already run on. Merged into one subject, a manifest that
# is schema-invalid while deriving FINALIZED would be indistinguishable in refused_by from a
# manifest that is TAMPERED, and the registered finding's whole point is that those are different facts.
#
# spec:309 READS "FINALIZED plus schema-valid is MATCHED", AND THAT IS WHAT THIS BUILDS: the gate
# proceeds only when EVERY arm entry is MATCHED or NOT_APPLICABLE (spec:62-63), so FINALIZED on one
# subject and schema-valid on the other is the only combination that proceeds. What two subjects
# buy over one is that the reader is told WHICH axis failed.

# THE OUTCOME MAPPING, AS DATA, WITH THE RATIFIED CLAUSE LABELLED IN PLACE.
# Four rows are spec:309-310 verbatim. The fifth is the ruled clause and says so on its own line, so that a
# reader auditing this file against the sealed spec finds the departure marked rather than having
# to notice its absence from :309.
$script:ManifestStateOutcome = @{
    'FINALIZED' = 'MATCHED'    # spec:309 -- and paired with the schema subject, per the note above.
    'PARTIAL'   = 'DIVERGED'   # spec:309.
    'TAMPERED'  = 'DIVERGED'   # spec:309, and post-D10 it means what the word says: the growth case left it.
    'ABSENT'    = 'ABSENT'     # spec:310 -- "a manifest at a path that holds nothing is ABSENT".
    'GREW'      = 'MOVED'      # THE RULED CLAUSE. NOT IN spec:309: GREW postdates the A3 seal.
}

$script:ManifestCompletenessResidual = 'RESIDUAL -- MANIFEST COMPLETENESS IS NOT CALL COMPLETENESS. A finalized, schema-valid, parity-clean manifest attests the calls that SUCCEEDED AND WERE PERMITTED, and nothing about those that failed. Per v2.3 SS 4.6 E5-ii, a failed call produces NO ENTRY, NO HOOK ERROR, AND NO `seq` GAP, so its absence is undetectable from the manifest alone. Guard DENIALS are a different case and are recorded since cure D8 -- complete by construction for calls the guard''s matcher reaches, and silent for those it does not. THIS ARM REPORTS WHAT THE PLANE CONTAINS; IT DOES NOT REPORT WHAT THE PLANE NEVER SAW, and a consumer must not read a clean verdict here as evidence that every call is accounted for.'

$script:SeqResidual = 'seq IS AN ORDERING HINT AND NEVER A KEY (spec:299-300), and this arm reads no seq value at all: a gap is NOT proof of a dropped capture, because the counter counts every log line while only tool-call lines carry seq, so a _precompact line consumes a number without recording one and a session that compacted as its last act leaves no gap at all (spec:294-298). The manifest carries no seq in any case (spec:290-293), so verify reading only the manifest cannot detect a dropped entry by sequence gap, and entry_count does not help -- it is derived from the same entries.'

$script:SchemaReachResidual = 'VALIDATOR REACH, STATED: this is a SUBSET validator over the keywords the normative schema actually uses (type, const, enum, pattern, minLength, minimum, required, properties, additionalProperties, items, allOf, not, oneOf) and not a general draft-07 engine -- PowerShell 5.1 ships no Test-Json and this program takes no dependency it cannot read. A future schema revision using an unimplemented keyword would have that keyword SILENTLY IGNORED, which FAILS OPEN. Registered, not cured here.'

function Get-DispatchIdFromManifestPath {
    <#
        The dispatch id is DERIVED from the anchor the artifact already carries rather than taken
        from a flag the sealed invocation surface does not have (spec:95-98). Both planes lay a
        dispatch out as <plane>/evidence/<dispatch-id>/manifest.json, so the id is the manifest's
        parent directory name. $null where no id can be derived, which the caller reports rather
        than guessing around.
    #>
    param([AllowNull()][AllowEmptyString()][string]$ManifestPath)
    if ([string]::IsNullOrWhiteSpace($ManifestPath)) { return $null }
    $parent = Split-Path -Parent $ManifestPath
    if ([string]::IsNullOrWhiteSpace($parent)) { return $null }
    $leaf = Split-Path -Leaf $parent
    if ([string]::IsNullOrWhiteSpace($leaf)) { return $null }
    return $leaf
}

function Invoke-ManifestArm {
    <#
        Returns whether the arm ENGAGED, and -- when it did -- the derived state, so the
        PLANE-PARITY arm can obey the section 5 ordering rule without re-deriving it.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Anchors,
        [Parameter(Mandatory = $true)][string]$PlaneRoot,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][bool]$BasisMoved,
        [Parameter(Mandatory = $true)][string]$MovedNote
    )

    $recordedManifest = $null
    if ($null -ne $Anchors) { $recordedManifest = Get-AnchorMember -Anchors $Anchors -Name 'evidence_manifest' }
    if ($null -eq $recordedManifest -or [string]::IsNullOrWhiteSpace([string]$recordedManifest)) {
        return [pscustomobject]@{
            Engaged = $false; State = $null; DispatchId = $null
            Reason  = 'the artifact carries no runner_anchors.evidence_manifest, so no dispatch can be identified and there is no manifest for this arm to compare (spec:265). The ABSENCE IS ALREADY A FINDING and is already refusing on the ANCHOR arm''s evidence_manifest subject, where schemas SS5 declares it a universal anchor; reporting it a second time here would double-count one missing anchor as two.'
        }
    }
    $recordedManifest = [string]$recordedManifest

    if (-not $script:EvidenceLib['loaded']) {
        # THE IMPORT IS A PREMISE, AND ITS FAILURE REFUSES RATHER THAN VANISHING. An arm that
        # quietly disappears when its detector cannot be loaded is the false-PASS class
        # spec:64-66 forbids -- INCOMPLETE presented as CLEAN.
        $why = "the sealed detector library could not be imported, so spec:268's detector could not be run: $($script:EvidenceLib['error'])"
        foreach ($s in @('evidence_state', 'schema_validity')) {
            New-ArmEntry -Arm 'MANIFEST' -Subject $s -Outcome 'ABSENT' -Recorded $recordedManifest -Derived $null `
                -Detector 'Get-EvidenceState (tools/framework/hooks/lib/evidence-common.ps1), plus validation against the normative manifest schema' `
                -Residual "$why This is reported and refuses; it is not a verdict about the manifest. $($script:ManifestCompletenessResidual)" | Out-Null
        }
        return [pscustomobject]@{ Engaged = $true; State = $null; DispatchId = $null; Reason = $null }
    }

    $dispatchId = Get-DispatchIdFromManifestPath -ManifestPath $recordedManifest
    if ($null -eq $dispatchId) {
        foreach ($s in @('evidence_state', 'schema_validity')) {
            New-ArmEntry -Arm 'MANIFEST' -Subject $s -Outcome 'ABSENT' -Recorded $recordedManifest -Derived $null `
                -Detector 'the dispatch id, derived from the recorded evidence_manifest path' `
                -Residual "No dispatch id could be derived from the recorded manifest path, and the spec:122-124 detectors take one. The id is NOT invented and no default is substituted: a detector pointed at a guessed dispatch would compare a different dispatch's plane and report the answer as this one's. $($script:ManifestCompletenessResidual)" | Out-Null
        }
        return [pscustomobject]@{ Engaged = $true; State = $null; DispatchId = $null; Reason = $null }
    }

    # ---- axis 1: the derived state (spec:268, :122) ------------------------------------------
    $cmdText = Expand-AdmittedCommandText -Subject 'evidence_state' -Tokens @{ repo = $PlaneRoot; id = $dispatchId }
    $d = Invoke-Derivation -Subject 'evidence_state' -RepoRoot $RepoRoot `
        -InProcCommandText $cmdText `
        -InProcAction { Get-EvidenceState -Root $PlaneRoot -DispatchId $dispatchId }
    $st = $d.Value
    if ($null -eq $st) {
        throw "MALFORMED: the spec:268 detector returned nothing for dispatch '$dispatchId'. Verify does not manufacture a state on a detector that did not answer."
    }
    $state = [string]$st.state
    if (-not $script:ManifestStateOutcome.ContainsKey($state)) {
        # A SIXTH STATE IS AN EVENT, NOT A DEFAULT. The mapping is spec:309 plus the ruled
        # clause; a state outside both has no ratified outcome, and picking one here would be
        # this file legislating. spec:198's did-not-complete path is the honest answer.
        throw "MALFORMED: the spec:268 detector returned state '$state', which is outside the five this build maps (spec:309 plus the ruled GREW clause). A sixth state needs its own amendment; verify does not choose an outcome for it."
    }
    $stateOutcome = $script:ManifestStateOutcome[$state]

    $resolvedManifest = [string]$st.manifest_path
    $hookErrors = $null
    $entryCount = $null
    if (Test-Path -LiteralPath $resolvedManifest -PathType Leaf) {
        try {
            $mdoc = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($resolvedManifest))
            if (Test-JsonMember -Object $mdoc -Name 'hook_errors_present') { $hookErrors = Get-JsonMember -Object $mdoc -Name 'hook_errors_present' }
            if (Test-JsonMember -Object $mdoc -Name 'entry_count') { $entryCount = Get-JsonMember -Object $mdoc -Name 'entry_count' }
        }
        catch { }
    }
    # spec:307-308's FOUR EMISSIONS ride EVERY entry of this arm, not only the refusing ones:
    # "a consumer that never sees the flag cannot weigh it" (spec:288-289). Where the manifest is
    # unreadable the flag reads `unknown` rather than `false` -- a default false here would be an
    # assertion that no hook errored, on no evidence.
    $flags = 'hook_errors_present=' + $(if ($null -eq $hookErrors) { 'unknown' } else { ([string]$hookErrors).ToLowerInvariant() }) +
             '; entry_count=' + $(if ($null -eq $entryCount) { 'unknown' } else { [string]$entryCount })

    $pathNote = ''
    if ($resolvedManifest -ne $recordedManifest) {
        $pathNote = " PATHS DIFFER, DISCLOSED RATHER THAN RECONCILED: the artifact records '$recordedManifest' and the spec:122 detector derived '$resolvedManifest' from the plane root and the dispatch id. The anchor IDENTIFIES the dispatch; the detector DERIVES the plane, which is the form spec:122-124 write it in. The recorded copy's own bytes are what the ANCHOR arm's evidence_manifest_sha256 subject compares."
    }
    $errFlagNote = ''
    if ($hookErrors -is [bool] -and $hookErrors) {
        $errFlagNote = ' hook_errors_present IS TRUE ON THIS MANIFEST: entry_count MAY UNDERCOUNT REALITY and this manifest must not be consumed as complete merely because it is finalized (spec:286-289). Read hook-errors.log in the same directory.'
    }

    $stateResidual = "STATE IS A HEADER CHECK. Get-EvidenceState reads finalized_at and re-hashes log.jsonl; IT DOES NOT READ STREAM BODIES, so a mutated stream body with an untouched log still derives FINALIZED from state alone -- which is why arm 4.3 exists and why threat notes R3 records this as detected-not-prevented (spec:282-285). A HOOK THAT WAS NEVER INSTALLED IS UNDETECTABLE FROM INSIDE (threat notes R5, R10): a session whose hooks never fired sees ABSENT and refuses, which is correct, but verify cannot distinguish 'hooks absent' from 'dispatch never ran' beyond this reason string and the hook-errors.log hint (spec:301-305). $($script:SeqResidual)$errFlagNote$pathNote $($script:ManifestCompletenessResidual)"

    if ($state -eq 'GREW') {
        # THE RULED CLAUSE D, IMPLEMENTED HERE AND NOT LEFT TO THE reason FIELD ALONE: the residual
        # names the derived state and the ratified mapping in its own words, so a reader meeting
        # MOVED is told what moved and why it is not a disagreement.
        $stateResidual = "DERIVED STATE `GREW`, MAPPED TO MOVED BY AM-449 -- NOT BY spec:309, WHICH PREDATES THIS STATE. The log is a VERIFIED APPEND-EXTENSION of the sealed prefix: the manifest sealed a prefix and the session continued, so the recorded basis is SUPERSEDED, NOT CONTRADICTED (spec:57), and spec:637 prescribes re-deriving at the anchor -- which is what cure D10's own reason string calls a newer finalize pending at the next Stop. It REFUSES: GREW carries consumable = false and the gate proceeds only on MATCHED or NOT_APPLICABLE (spec:62-63). It is NOT DIVERGED, because spec:68-71 states that folding this into DIVERGED makes ordinary progress read as an integrity event and the gate is switched off within a week -- the E5-iv harm the sealed document itself predicts. THE DISCRIMINATOR IS PREFIX RE-DERIVATION, NOT LENGTH, and every undecidable case still lands TAMPERED (cure D10). $($script:SeqResidual)$errFlagNote$pathNote $($script:ManifestCompletenessResidual)"
    }

    # THE VERBATIM reason STRING IS THE DERIVED VALUE, not a paraphrase of it (spec:307).
    $derivedState = "state=$state; reason=$([string]$st.reason); consumable=$([string]$st.consumable); $flags"
    if ($BasisMoved -and $stateOutcome -eq 'MATCHED') {
        New-ArmEntry -Arm 'MANIFEST' -Subject 'evidence_state' -Outcome 'MOVED' -Recorded $recordedManifest -Derived $derivedState `
            -Detector $cmdText -Residual "$MovedNote $stateResidual" | Out-Null
    }
    else {
        New-ArmEntry -Arm 'MANIFEST' -Subject 'evidence_state' -Outcome $stateOutcome -Recorded $recordedManifest -Derived $derivedState `
            -Detector $cmdText -Residual $stateResidual | Out-Null
    }

    # ---- axis 2: schema validity (spec:126, 269-270, 275-279) --------------------------------
    # RUN UNCONDITIONALLY, INCLUDING WHEN THE STATE ALREADY REFUSES. Skipping it on a refusing
    # state would make the state check subsume this one exactly when the manifest is most
    # suspect, which is the subsumption spec:275-279 forbids.
    $schemaPath = Get-ManifestSchemaPath -RepoRoot $RepoRoot
    $schemaCmd = 'the manifest validated against docs/framework/evidence-manifest.schema.json: ' + $resolvedManifest
    $ds = Invoke-Derivation -Subject 'schema_validity' -RepoRoot $RepoRoot `
        -InProcCommandText $schemaCmd `
        -InProcAction { Test-ManifestAgainstSchema -ManifestPath $resolvedManifest -SchemaPath $schemaPath }
    $sv = $ds.Value

    $schemaResidual = "schemas SS12 declares this schema NORMATIVE for this artifact (spec:270). NEITHER CHECK SUBSUMES THE OTHER (spec:275-279): a log line that is valid JSON but carries none of the declared fields yields a manifest that FAILS SCHEMA VALIDATION WHILE STILL DERIVING FINALIZED, and an implementation running only the state derivation and reporting the artifact good has reintroduced the defect the resolution recorded. That is why this subject is reported separately and why it runs even when the state subject has already refused. $($script:SchemaReachResidual)$errFlagNote $($script:ManifestCompletenessResidual)"

    if ($null -eq $sv) {
        New-ArmEntry -Arm 'MANIFEST' -Subject 'schema_validity' -Outcome 'ABSENT' -Recorded $recordedManifest -Derived $null `
            -Detector $schemaCmd -Residual "The validator did not answer: $($ds.StdErr) $schemaResidual" | Out-Null
    }
    elseif ($sv.verdict -eq 'SCHEMA_UNREADABLE') {
        New-ArmEntry -Arm 'MANIFEST' -Subject 'schema_validity' -Outcome 'ABSENT' -Recorded $recordedManifest -Derived ("schema=UNREADABLE; " + [string]$sv.detail + '; ' + $flags) `
            -Detector $schemaCmd `
            -Residual "THE NORMATIVE DOCUMENT ITSELF IS UNREADABLE, WHICH IS A FACT ABOUT THIS CHECKOUT AND NOT ABOUT THE MANIFEST. Reported ABSENT and refusing; it is NOT reported DIVERGED, because calling a manifest invalid on the strength of a missing schema would manufacture a finding out of a missing file. $schemaResidual" | Out-Null
    }
    elseif ($sv.verdict -eq 'NO_MANIFEST') {
        New-ArmEntry -Arm 'MANIFEST' -Subject 'schema_validity' -Outcome 'ABSENT' -Recorded $recordedManifest -Derived ("schema=NOT_RUN; " + [string]$sv.detail + '; ' + $flags) `
            -Detector $schemaCmd `
            -Residual "There is no manifest at the derived path to validate, so this axis has no subject -- spec:310's ABSENT, on its own subject rather than folded into the state axis. $schemaResidual" | Out-Null
    }
    elseif ($sv.verdict -eq 'VALID') {
        $o = 'MATCHED'
        if ($BasisMoved) { $o = 'MOVED' }
        $res = $schemaResidual
        if ($BasisMoved) { $res = "$MovedNote $schemaResidual" }
        New-ArmEntry -Arm 'MANIFEST' -Subject 'schema_validity' -Outcome $o -Recorded $recordedManifest -Derived ("schema=VALID; first_failing_pointer=<none>; " + $flags) `
            -Detector $schemaCmd -Residual $res | Out-Null
    }
    else {
        $ptr = [string]$sv.pointer
        if ([string]::IsNullOrEmpty($ptr)) { $ptr = '<document root>' }
        New-ArmEntry -Arm 'MANIFEST' -Subject 'schema_validity' -Outcome 'DIVERGED' -Recorded $recordedManifest -Derived ("schema=INVALID; first_failing_pointer=" + $ptr + '; detail=' + [string]$sv.detail + '; ' + $flags) `
            -Detector $schemaCmd -Residual $schemaResidual | Out-Null
    }

    return [pscustomobject]@{ Engaged = $true; State = $st; DispatchId = $dispatchId; Reason = $null }
}

# =====================================================================================
# SS 8e.  THE PLANE-PARITY ARM  (spec:312-370), UNDER THE SECTION 5 ORDER (spec:435-449)
# =====================================================================================
#
# THREE SUBJECTS, BECAUSE spec:364-366 NAMES THREE. The committed-plane subject, the stream-body
# subject, and -- per section 5 -- the capture-gap subject. Reporting parity alone as "the plane
# is intact" is precisely the class claim design SS4.5 law 4 forbids (spec:341-342).
#
# THE ORDERING RULE IS OBEYED AT THE CONSUMER AND NOT PATCHED AT THE SOURCE, AND THE SEAM IS STATED.
# spec:437 binds verify to "discriminate entry variant BEFORE it tests existence". The sealed
# Test-EvidenceStreamIntegrity does the opposite -- its existence test precedes the variant
# discrimination, so a _precompact entry whose transcript capture HONESTLY FAILED (captured:false,
# a null transcript_sha256, and a path the schema requires) is reported as `stream file missing`,
# an integrity violation manufactured from a disclosed evidence gap. That function lives inside
# sealed anchor EC27AB3A / 80479 b, worktree-class -- the 189f811b / 46870 b figure is SUPERSEDED and 65865a0f / 76413 b is RETIRED -- and A-566 owns its repair (spec:451-455: "A3 does not touch
# evidence-common.ps1... the delta below is registered as an A4-dispatch build item").
#
# SO VERIFY DOES THE DISCRIMINATION ITSELF, ON ITS OWN SIDE OF THE CALL: it reads the manifest's
# entries, identifies the capture-gap set, and PARTITIONS the sealed function's returned mismatch
# list against it. NOTHING IS DROPPED. The sealed function's FULL verbatim mismatch list is carried
# on the stream subject exactly as spec:365 requires; the reclassified members are named on the
# capture-gap subject; and the stream subject's OUTCOME is decided on the members that are actually
# stream-integrity findings. A reader can reconstruct the sealed function's own `ok` from what is
# printed, so the seam is auditable rather than asserted.

$script:TranscriptResidual = 'transcript_sha256 IS COMPARED BY NOTHING (spec:354-360). The PreCompact hook writes it, the Stop hook projects it into the manifest, the A1 negative suite asserts its presence -- and NO CODE PATH IN THE SEALED SET RE-DERIVES IT FROM THE TRANSCRIPT FILE. The parity check reaches transcripts by EXISTENCE ONLY, and only when streams_committed is true, so A COMMITTED TRANSCRIPT''S CONTENTS ARE UNVERIFIED BY ANY ARM IN THIS DOCUMENT. Closing it is a change to sealed A1 code and is REGISTERED, not done here.'

$script:TrustBoundaryResidual = 'THE TRUST BOUNDARY IS THE CEREMONY COMMIT AND NO ARM MOVES IT (spec:345-350). Pre-commit runtime evidence is provisional and destroyable from inside the session with no marker -- a validator proved it end to end, producing a clean, consumable, self-consistent manifest whose log_sha256 matched after the record had been erased and repopulated. Post-commit evidence is git-protected, and detection of its destruction belongs to the git, origin and operator layers. Verify inherits this boundary and reports against it; it does not raise it.'

function Get-CaptureGapPaths {
    <#
        The section 5 discrimination, performed by VERIFY rather than by the sealed function.
        A _precompact entry with captured:false is a CAPTURE GAP (spec:445-449). Returns the set of
        declared paths belonging to those entries -- comma-wrapped so the empty case stays an array
        and "no capture gaps" can never be read as "the check did not run".
    #>
    param([AllowNull()]$ManifestDoc)
    $out = @()
    if ($null -eq $ManifestDoc) { return , $out }
    if (-not (Test-JsonMember -Object $ManifestDoc -Name 'entries')) { return , $out }
    $entriesRaw = Get-JsonMember -Object $ManifestDoc -Name 'entries'
    foreach ($e in @($entriesRaw)) {
        if (-not (Test-JsonMember -Object $e -Name 'tool')) { continue }
        if ([string](Get-JsonMember -Object $e -Name 'tool') -ne '_precompact') { continue }
        if (-not (Test-JsonMember -Object $e -Name 'captured')) { continue }
        $cap = Get-JsonMember -Object $e -Name 'captured'
        if ($cap -is [bool] -and $cap) { continue }
        $p = $null
        if (Test-JsonMember -Object $e -Name 'path') { $p = Get-JsonMember -Object $e -Name 'path' }
        if ($null -eq $p) { continue }
        $out += ([string]$p)
    }
    return , $out
}

function Invoke-PlaneParityArm {
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Anchors,
        [Parameter(Mandatory = $true)][string]$PlaneRoot,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][AllowNull()]$ManifestResult,
        [Parameter(Mandatory = $true)][bool]$BasisMoved,
        [Parameter(Mandatory = $true)][string]$MovedNote
    )

    $subjects = @('plane_parity', 'stream_integrity', 'capture_gap')

    if ($null -eq $ManifestResult -or -not $ManifestResult.Engaged) {
        return [pscustomobject]@{ Engaged = $false
            Reason = 'the MANIFEST arm identified no dispatch, so there is no plane for this arm to compare. Section 5 orders manifest state FIRST (spec:440-442); with no dispatch identified there is nothing for the ordering to run over, and the missing anchor is already refusing on the ANCHOR arm.' }
    }
    if ($null -eq $ManifestResult.State -or $null -eq $ManifestResult.DispatchId) {
        foreach ($s in $subjects) {
            New-ArmEntry -Arm 'PLANE-PARITY' -Subject $s -Outcome 'ABSENT' -Recorded $null -Derived $null `
                -Detector 'Test-EvidencePlaneParity and Test-EvidenceStreamIntegrity (tools/framework/hooks/lib/evidence-common.ps1)' `
                -Residual "The MANIFEST arm could not derive a state, so section 5's first step never completed and these subjects are UNREADABLE rather than failing (spec:440-442). Reported ABSENT and refusing; NOT DIVERGED, because a subject that could not be read is not a subject that disagreed. $($script:TrustBoundaryResidual)" | Out-Null
        }
        return [pscustomobject]@{ Engaged = $true; Reason = $null }
    }

    $dispatchId = [string]$ManifestResult.DispatchId
    $state = [string]$ManifestResult.State.state

    # ---- SECTION 5, STEP 1: MANIFEST STATE FIRST (spec:440-442) -------------------------------
    if ($state -ne 'FINALIZED') {
        foreach ($s in $subjects) {
            New-ArmEntry -Arm 'PLANE-PARITY' -Subject $s -Outcome 'ABSENT' -Recorded $ManifestResult.State.manifest_path -Derived "not read: manifest state is $state" `
                -Detector 'the section 5 ordering rule, evaluated before any plane detector was run' `
                -Residual "SECTION 5, STEP 1 (spec:440-442): 'A manifest that is not FINALIZED makes the remaining subjects UNREADABLE RATHER THAN FAILING; verify does not report stream mismatches against a manifest it has already refused.' The derived state is $state, so NO PLANE DETECTOR WAS RUN and nothing here is a finding about the plane. Reported ABSENT -- the subject this comparison requires, a finalized manifest to compare against, does not exist -- and it REFUSES. Reporting DIVERGED instead would be exactly the manufactured integrity violation spec:351-353 warns the wrong order produces. $($script:TrustBoundaryResidual)" | Out-Null
        }
        return [pscustomobject]@{ Engaged = $true; Reason = $null }
    }

    # ---- SECTION 5, STEP 2: PLANE PARITY, ON THE COMMITTED PLANE (spec:443) -------------------
    $parityCmd = Expand-AdmittedCommandText -Subject 'plane_parity' -Tokens @{ repo = $PlaneRoot; id = $dispatchId }
    $dp = Invoke-Derivation -Subject 'plane_parity' -RepoRoot $RepoRoot `
        -InProcCommandText $parityCmd `
        -InProcAction { Test-EvidencePlaneParity -Root $PlaneRoot -DispatchId $dispatchId }
    $pv = $dp.Value

    $parityResidual = "THE DEMONSTRATED CLASS IS NARROW AND THIS ARM RESTATES IT NARROWLY (spec:323-327): what Test-EvidencePlaneParity demonstrates is A COMMITTED ARTIFACT THE RUNTIME MANIFEST SAYS WAS PUBLISHED, WHICH IS ABSENT FROM ITS CANONICAL PATH. NOTHING BROADER. It is not plane integrity in general -- it compares the committed plane against the RUNTIME MANIFEST'S OWN ASSERTIONS, and a runtime manifest that lies about what it published is outside it entirely. ITS OWN ARMS ARE NOT UNIFORM AND VERIFY INHERITS THE ASYMMETRY RATHER THAN GLOSSING IT (spec:329-340): the manifest, log.jsonl and hook-errors.log are compared by EXISTENCE AND HASH, but STREAM BODIES BY EXISTENCE ONLY -- NO HASH IS COMPARED -- so A COMMITTED STREAM BODY THAT IS PRESENT BUT CORRUPT PASSES THIS CHECK. The hash-bearing check for stream bodies is the stream_integrity subject beside this one, reported separately because reporting parity alone as 'the plane is intact' is the class claim law 4 forbids (spec:341-342). $($script:TranscriptResidual) $($script:TrustBoundaryResidual)"

    if ($null -eq $pv) {
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'plane_parity' -Outcome 'ABSENT' -Recorded $ManifestResult.State.manifest_path -Derived $null `
            -Detector $parityCmd -Residual "The parity detector did not answer: $($dp.StdErr) $parityResidual" | Out-Null
    }
    else {
        $problems = @($pv.problems)
        $parityDerived = 'checked=' + [string]$pv.checked + '; problems=' + $(if ($problems.Count -eq 0) { '<none>' } else { ($problems -join ' | ') }) + '; reason=' + [string]$pv.reason
        # spec:367-369 -- "A runtime manifest that is absent or unparsable is ABSENT, NOT a parity
        # failure -- the parity function itself distinguishes these and verify does not flatten
        # them." The distinction is read from the function's OWN reason field rather than
        # re-derived here, so the two cannot drift apart.
        if (([string]$pv.reason -eq 'runtime manifest absent') -or ([string]$pv.reason -eq 'runtime manifest unparsable')) {
            New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'plane_parity' -Outcome 'ABSENT' -Recorded $ManifestResult.State.manifest_path -Derived $parityDerived `
                -Detector $parityCmd `
                -Residual "spec:367-369: an absent or unparsable RUNTIME manifest is ABSENT, NOT A PARITY FAILURE. The parity function distinguishes these itself and verify reads its distinction rather than flattening the two into one verdict. $parityResidual" | Out-Null
        }
        elseif ($problems.Count -gt 0) {
            New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'plane_parity' -Outcome 'DIVERGED' -Recorded $ManifestResult.State.manifest_path -Derived $parityDerived `
                -Detector $parityCmd -Residual "ANY PROBLEM IS DIVERGED (spec:367). The verbatim problems list is carried in the derived value above. $parityResidual" | Out-Null
        }
        else {
            $o = 'MATCHED'; $res = $parityResidual
            if ($BasisMoved) { $o = 'MOVED'; $res = "$MovedNote $parityResidual" }
            New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'plane_parity' -Outcome $o -Recorded $ManifestResult.State.manifest_path -Derived $parityDerived `
                -Detector $parityCmd -Residual $res | Out-Null
        }
    }

    # ---- SECTION 5, STEPS 3 AND 4: VARIANT DISCRIMINATION, THEN STREAM INTEGRITY --------------
    # THE DISCRIMINATION HAPPENS FIRST, which is the whole of spec:437.
    $runtimeManifestPath = [string]$ManifestResult.State.manifest_path
    $mdoc = $null
    try { $mdoc = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($runtimeManifestPath)) } catch { $mdoc = $null }
    # Assign first, normalise second -- the same idiom the validator's list reads use, and for the
    # same reason: `@(Get-CaptureGapPaths ...)` returns a ONE-element list holding the empty array,
    # so a plane with NO capture gaps would report one. The first battery caught precisely that.
    $gapPathsRaw = Get-CaptureGapPaths -ManifestDoc $mdoc
    $gapPaths = @($gapPathsRaw)

    $streamCmd = Expand-AdmittedCommandText -Subject 'stream_integrity' -Tokens @{ repo = $PlaneRoot; id = $dispatchId }
    $dsi = Invoke-Derivation -Subject 'stream_integrity' -RepoRoot $RepoRoot `
        -InProcCommandText $streamCmd `
        -InProcAction { Test-EvidenceStreamIntegrity -Root $PlaneRoot -DispatchId $dispatchId }
    $iv = $dsi.Value

    $allMismatches = @()
    $streamMismatches = @()
    $reclassified = @()
    $streamChecked = 0
    $streamReason = ''
    if ($null -ne $iv) {
        $streamChecked = $iv.checked
        $streamReason = [string]$iv.reason
        foreach ($m in @($iv.mismatches)) {
            $line = [string]$m.path + ' -- ' + [string]$m.problem
            $allMismatches += $line
            if ($gapPaths -contains ([string]$m.path)) { $reclassified += $line }
            else { $streamMismatches += $line }
        }
    }

    $streamResidual = "STREAM INTEGRITY RUNS LAST AND OVER TOOL-CALL ENTRIES ONLY (spec:444). THE SEALED DETECTOR'S FULL VERBATIM MISMATCH LIST IS CARRIED ABOVE, NOTHING DROPPED (spec:365); what verify does on its own side of the call is DISCRIMINATE THE ENTRY VARIANT BEFORE THE EXISTENCE TEST (spec:437), because the sealed function does it in the other order and therefore reports a _precompact entry whose capture HONESTLY FAILED as `stream file missing` -- an integrity violation manufactured out of an already-disclosed evidence gap (spec:425-433, 351-353). Those members are reported on the capture_gap subject instead of here, and are named there rather than discarded. THE SEALED BYTES ARE NOT EDITED: repairing Test-EvidenceStreamIntegrity moves sealed anchor 189f811b and is A-566's, needing its own amendment and the operator-placement route; spec:451-455 registers the delta and states that A3 does not touch that file. $($script:TranscriptResidual) $($script:TrustBoundaryResidual)"

    $streamDerived = 'checked=' + [string]$streamChecked +
        '; mismatches_verbatim=' + $(if ($allMismatches.Count -eq 0) { '<none>' } else { ($allMismatches -join ' | ') }) +
        '; reclassified_as_capture_gap=' + $(if ($reclassified.Count -eq 0) { '<none>' } else { ($reclassified -join ' | ') }) +
        '; reason=' + $streamReason

    if ($null -eq $iv) {
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'stream_integrity' -Outcome 'ABSENT' -Recorded $runtimeManifestPath -Derived $null `
            -Detector $streamCmd -Residual "The stream-integrity detector did not answer: $($dsi.StdErr) $streamResidual" | Out-Null
    }
    elseif ($streamReason -eq 'no manifest') {
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'stream_integrity' -Outcome 'ABSENT' -Recorded $runtimeManifestPath -Derived $streamDerived `
            -Detector $streamCmd -Residual "There is no manifest for the detector to read, so this subject has no subject. ABSENT, and it refuses. $streamResidual" | Out-Null
    }
    elseif ($streamMismatches.Count -gt 0) {
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'stream_integrity' -Outcome 'DIVERGED' -Recorded $runtimeManifestPath -Derived $streamDerived `
            -Detector $streamCmd -Residual "ANY PROBLEM IS DIVERGED (spec:367). $streamResidual" | Out-Null
    }
    else {
        $o = 'MATCHED'; $res = $streamResidual
        if ($BasisMoved) { $o = 'MOVED'; $res = "$MovedNote $streamResidual" }
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'stream_integrity' -Outcome $o -Recorded $runtimeManifestPath -Derived $streamDerived `
            -Detector $streamCmd -Residual $res | Out-Null
    }

    # ---- SECTION 5, STEP 4: THE CAPTURE-GAP SUBJECT (spec:445-449, 366) -----------------------
    $gapDerived = 'capture_gap_entries=' + $gapPaths.Count +
        '; paths=' + $(if ($gapPaths.Count -eq 0) { '<none>' } else { ($gapPaths -join ' | ') }) +
        '; reclassified_from_stream_integrity=' + $(if ($reclassified.Count -eq 0) { '<none>' } else { ($reclassified -join ' | ') })
    $gapResidual = "spec:445-449: 'A _precompact entry with captured:false is a CAPTURE GAP. It is emitted as its own subject with its own outcome and NEVER as a stream-integrity mismatch. It is NOT SILENTLY DROPPED EITHER: a transcript that was supposed to exist and does not IS A REAL EVIDENCE GAP, and the manifest's own captured boolean exists as a separate field precisely so that a false there is not read as an absent event.' This subject is the both-directions rule made visible: the gap does not masquerade as tampering, and it does not disappear. DERIVED FROM THE MANIFEST'S OWN DECLARED ENTRIES, so a gap the manifest never declared is not visible here either -- which is the E5-ii direction and is the manifest-completeness residual below. $($script:ManifestCompletenessResidual)"
    if ($gapPaths.Count -gt 0) {
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'capture_gap' -Outcome 'ABSENT' -Recorded $runtimeManifestPath -Derived $gapDerived `
            -Detector 'entry-variant discrimination over the runtime manifest declared entries, performed by verify before the existence test (spec:437)' `
            -Residual "THE PLANE DECLARES $($gapPaths.Count) CAPTURE GAP(S): a transcript snapshot the manifest says was attempted and records as NOT captured. The subject the check requires does not exist, so ABSENT, and it REFUSES. $gapResidual" | Out-Null
    }
    else {
        $o = 'MATCHED'; $res = $gapResidual
        if ($BasisMoved) { $o = 'MOVED'; $res = "$MovedNote $gapResidual" }
        New-ArmEntry -Arm 'PLANE-PARITY' -Subject 'capture_gap' -Outcome $o -Recorded $runtimeManifestPath -Derived $gapDerived `
            -Detector 'entry-variant discrimination over the runtime manifest declared entries, performed by verify before the existence test (spec:437)' `
            -Residual "The manifest declares no _precompact entry with captured:false. $res" | Out-Null
    }

    return [pscustomobject]@{ Engaged = $true; Reason = $null }
}

# =====================================================================================
# SS 9.  MAIN
# =====================================================================================

function Resolve-RepoRoot {
    $candidates = @()
    $candidates += (Get-Location).Path
    if ($PSScriptRoot) { $candidates += $PSScriptRoot }
    foreach ($start in $candidates) {
        $dir = $start
        while ($dir) {
            if (Test-Path -LiteralPath (Join-Path $dir '.mission\mission.yaml')) { return $dir }
            $parent = Split-Path -Parent $dir
            if ($parent -eq $dir) { break }
            $dir = $parent
        }
    }
    return $null
}

function Write-Std {
    <#
        Stdout goes to the console handle DIRECTLY, never through the PowerShell pipeline.
        Invoke-MissionVerify returns the exit code as its value; anything it also emitted to the
        pipeline would be captured by the caller's assignment and the report would vanish while
        the exit code silently became an array. Two channels, kept apart on purpose.
        Nothing is ever written to stderr -- see the header note.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    [Console]::Out.WriteLine($Text)
}

function Write-Usage {
    Write-Std 'mission verify --against <report-path> [--dispatch-kind <kind>] [--branch <name>]'
    Write-Std '               [--evidence-root <path>] [--plane-root <path>] [--library-path <path>]'
    Write-Std '               [--format yaml|json] [--out <path>]'
}

function Read-AgainstArtifact {
    param([Parameter(Mandatory = $true)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $trimmed = $text.TrimStart()
    if ($trimmed.StartsWith('{')) { return (ConvertFrom-Json -InputObject $text) }
    return (ConvertFrom-RestrictedYaml -Lines ([System.IO.File]::ReadAllLines($Path)))
}

function Invoke-MissionVerify {
    param([string[]]$Argv)

    # ---- argument parsing, against the SEALED invocation surface (spec:95-98) ----------------
    # 'plane-root' and 'library-path' are the DEV-1 REFINEMENT (operator-ratified 2026-08-16). Both
    # are declared here so the parser admits them; 'library-path' is CONSUMED AT SCRIPT SCOPE, before
    # this function runs, because the detector import precedes argv parsing.
    $opt = @{ against = $null; 'dispatch-kind' = $null; branch = $null; 'evidence-root' = $null; 'plane-root' = $null; 'library-path' = $null; format = 'yaml'; out = $null }
    $i = 0
    while ($i -lt $Argv.Count) {
        $a = $Argv[$i]
        if (-not $a.StartsWith('--')) { Write-Std "verify: unrecognized argument '$a'"; Write-Usage; return 2 }
        $name = $a.Substring(2)
        if (-not $opt.ContainsKey($name)) { Write-Std "verify: unknown flag '--$name'"; Write-Usage; return 2 }
        if ($i + 1 -ge $Argv.Count) { Write-Std "verify: flag '--$name' requires a value"; Write-Usage; return 2 }
        $opt[$name] = $Argv[$i + 1]
        $i += 2
    }
    if ([string]::IsNullOrWhiteSpace($opt['against'])) { Write-Std 'verify: --against is required'; Write-Usage; return 2 }
    if ($opt['format'] -notin @('yaml', 'json')) { Write-Std "verify: --format must be yaml or json, got '$($opt['format'])'"; return 2 }

    $repoRoot = Resolve-RepoRoot
    if ($null -eq $repoRoot) { Write-Std 'verify: could not resolve a repository root (no .mission/mission.yaml above the working directory or this script)'; return 2 }

    # ---- THE PLANE ROOT (see the header note) -------------------------------------------------
    # The root the spec:122-124 detectors are given. spec writes `<repo>`, and that is what this
    # is when --evidence-root is absent. When the flag IS supplied it names where THIS RUN's
    # evidence plane lives, and the arms that READ that plane follow it -- otherwise one run would
    # name two different planes, and no acceptance drive of arms 4.2/4.3 could be hermetic.
    # DISCLOSED in basis.disclosed_residuals and printed in every derivation's own command text.
    $planeRoot = $opt['evidence-root']
    $planeRootDerivedFrom = '--evidence-root'
    if ([string]::IsNullOrWhiteSpace($planeRoot)) { $planeRoot = $repoRoot; $planeRootDerivedFrom = 'the repository root (--evidence-root absent), which is spec:122-124 literally' }
    # --plane-root (DEV-1 REFINEMENT, ratified 2026-08-16). THE READ PLANE AND THE WRITE ROOT ARE NOW
    # SEPARABLE. Before this, one flag named both, so a drive that pointed --evidence-root at a
    # write-failing path to exercise the spec:187-188 refusal ALSO made the spec:122-124 detectors
    # derive ABSENT -- the two could not be driven apart, and the acceptance members that need them
    # apart were unreachable. DEFAULT IS UNCHANGED BEHAVIOUR: absent, the read plane is still exactly
    # what --evidence-root (or, absent that, the repository root) already made it.
    if (-not [string]::IsNullOrWhiteSpace($opt['plane-root'])) {
        $planeRoot = $opt['plane-root']
        $planeRootDerivedFrom = '--plane-root, which OVERRIDES the read plane only and leaves the write root where --evidence-root put it'
    }
    # ONE SOURCE OF TRUTH FOR THE WRITE ROOT, resolved here rather than at the write site, so the
    # root every derivation record PRINTS is provably the root the self-capture write later USES.
    # Two independent resolutions could drift, and the record would then attest a root the run
    # did not write to.
    $writeEvidenceRoot = $opt['evidence-root']
    if ([string]::IsNullOrWhiteSpace($writeEvidenceRoot)) { $writeEvidenceRoot = (Join-Path $repoRoot '.mission\evidence') }
    $script:ReadPlaneRoot = $planeRoot
    $script:WriteEvidenceRoot = $writeEvidenceRoot

    # ---- exit-2 territory: verify itself unable to complete (spec:198) ------------------------
    # An unreadable --against artifact is spec:185-186 REFUSAL territory and is handled below as
    # a refusal with a complete report. What is exit 2 is verify being unable to EMIT a verdict.
    $verifyId = 'verify-' + ([guid]::NewGuid().ToString('n').Substring(0, 12))
    $invokedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)

    $basisTree = Get-BasisTreeMembers
    $hashClass = Get-HashClass -RepoRoot $repoRoot

    $headInv = Get-AdmittedProcessInvocation -Subject 'head'
    $headProbe = Invoke-Derivation -Subject 'head' -RepoRoot $repoRoot -ProcessFile $headInv.FilePath -ProcessArgs $headInv.ArgumentList
    if ($headProbe.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($headProbe.StdOut)) {
        $unresolvableHead = $true
        $basisHead = $null
    }
    else {
        $unresolvableHead = $false
        $basisHead = $headProbe.StdOut.Trim()
    }

    # ---- the concrete same-host configuration, DERIVED, recorded where host facts belong -------
    # The ORIGIN arm's residual states the CLASS in the spec's own terms. The instance -- which
    # host, reached how -- is a fact about this machine, so it is recorded in the basis, where it
    # can go stale without weakening what the residual says. Everything here is read from the
    # repository's own config as a FILE; no command outside the spec:115-126 set is issued to
    # obtain it, and nothing about the credential itself is read, named or hashed.
    $originUrlForBasis = Get-OriginRemoteUrl -RepoRoot $repoRoot
    if ($null -ne $originUrlForBasis -and (Test-UrlUserInfo -Text $originUrlForBasis)) {
        Assert-NoUserInfo -Where 'the configured origin remote URL'
    }
    $originPartsForBasis = Get-OriginEndpointParts -Url $originUrlForBasis
    $sharedPathNote = 'SAME-HOST CHANNEL CONFIGURATION: not characterised on this run -- no origin remote URL resolved from the repository config.'
    if ($null -ne $originPartsForBasis) {
        $originScheme = 'unknown'
        if ($originUrlForBasis -match '^([A-Za-z][A-Za-z0-9+.-]*)://') { $originScheme = $Matches[1].ToLowerInvariant() }
        $sharedPathNote = "SAME-HOST CHANNEL CONFIGURATION, this run: the git channel reaches origin over $originScheme at host '$($originPartsForBasis.HostName)', and the API channel reaches the ref endpoint at the SAME host '$($originPartsForBasis.HostName)'. Both therefore resolve credentials through this host's credential path for that host -- ONE store, ONE failure mode. This is the concrete instance of the class the ORIGIN arm's residual states (spec:507-513); the class is stated there, the host fact is recorded here."
    }

    $disclosed = @(
        'exit_code in the derivations block below is this process own child-process exit code and is honest. It is NOT the hook-captured carrier value: that carrier records a permanent null for exit_code, and a reader comparing this report against hook-captured evidence must not read the two as the same field.'
        'TWO NULLS, AND THEY ARE NOT THE SAME NULL. Where exit_code is null in the derivations block, the detector was an IN-PROCESS FUNCTION CALL and no process exit code exists -- a CATEGORY FACT, carrying its own exit_code_null_reason field beside it. The hook-captured carrier E5-i null is a CAPTURE GAP: the harness never supplied the field (v2.3:285) for calls that did exit. Reporting both with the same bare null would merge a gap with a non-applicability, which is the undisclosed-residual class a review finding registers. Every null here says which it is.'
        'exit_code CORRECTION, DISCLOSED: increment 1 recorded 0 for its one in-process derivation (manifest_hash) and 1 when that derivation threw. Both were fabricated fields under a review finding -- no process ran -- and increment 3 applies the null-with-a-reason rule at the mechanism, so every in-process row reports alike. No outcome changes; no arm reads exit_code for an in-process subject.'
        'Increment 3 builds ALL FOUR arms: ANCHOR, ORIGIN-ATTESTATION, MANIFEST and PLANE-PARITY. Every row of the spec:115-126 command set is implemented. Entries in arms_not_run are therefore arms that RAN AND FOUND NO SUBJECT, never arms that were skipped, and each says which.'
        "PLANE ROOT for the spec:122-124 detectors: '$planeRoot', derived from $planeRootDerivedFrom. spec:122-124 write these invocations as -Root <repo>; where --evidence-root is supplied this build passes it instead, so that the plane a run WRITES and the plane it READS are the same one BY DEFAULT. STATED AS A DEPARTURE from the sealed bytes rather than folded in silently, and reported for an individual ruling."
        "THE TWO ROOTS OF THIS RUN, AND WHETHER THEY ARE ONE. Read plane root (spec:122-124 detectors): '$planeRoot'. Write evidence root (this run's self-capture, spec:569-582): '$writeEvidenceRoot'. THEY ARE $(if ($planeRoot -eq $writeEvidenceRoot) { 'THE SAME ROOT on this run' } else { 'DIFFERENT ROOTS on this run, because --plane-root was supplied' }). Both are printed on EVERY derivation record as read_plane_root and write_evidence_root. THEY ARE RUN-LEVEL FACTS, NOT PER-DERIVATION ATTRIBUTION: a process-kind derivation (the git rows) consults NEITHER root, and a reader must not read their presence on such a record as a claim that the derivation used them. Separability is the DEV-1 REFINEMENT, ratified 2026-08-16: before it one flag named both, so a run could not exercise the spec:187-188 write-failure refusal while still reading a plane, and the acceptance members needing that combination were unreachable."
        "SEALED DETECTOR LIBRARY, WHERE IT CAME FROM: $(if ($script:EvidenceLib['path']) { "'" + $script:EvidenceLib['path'] + "'" } else { 'NOT LOADED -- ' + [string]$script:EvidenceLib['error'] }). Resolution route: $(if ($__libExplicitGiven) { '--library-path, supplied explicitly; the two-candidate search was NOT run and is never a fallback' } else { 'the two-candidate search (working directory repository root, then this script own directory) -- --library-path absent' }). The flag changes WHERE THE PATH COMES FROM and never what is loaded: the named file is dot-sourced exactly as a found path would be."
        'MANIFEST COMPLETENESS IS NOT CALL COMPLETENESS. A finalized, schema-valid, parity-clean manifest attests the calls that SUCCEEDED AND WERE PERMITTED, and nothing about those that failed: per v2.3 SS 4.6 E5-ii a failed call produces NO ENTRY, NO HOOK ERROR, AND NO seq GAP, so its absence is undetectable from the manifest alone. Guard DENIALS are a different case and are recorded since cure D8 -- complete by construction for calls the guard matcher reaches, silent for those it does not. These arms report what the plane CONTAINS; they do not report what the plane NEVER SAW.'
        $sharedPathNote
    )
    foreach ($c in (Get-CredentialEnvDisclosure)) { $disclosed += $c }

    $basis = [ordered]@{
        head               = $basisHead
        tree               = $basisTree.Tree
        untracked_included = $basisTree.UntrackedIncluded
        hash_class         = $hashClass
        # IMPLEMENTED rather than deferred. The disclosure rides the basis
        # so that a reader weighing this report's derivations sees the carrier's limit beside
        # them instead of inferring it.
        disclosed_residuals = $disclosed
    }

    $againstPath = $opt['against']
    $againstSha = $null
    $anchors = $null
    $recordedBasis = $null
    $recordedKind = $null
    $loadError = $null

    if (-not (Test-Path -LiteralPath $againstPath -PathType Leaf)) {
        $loadError = "the --against artifact does not exist at '$againstPath'"
    }
    else {
        $againstSha = Get-FileSha256Hex -Path $againstPath
        try {
            $doc = Read-AgainstArtifact -Path $againstPath
            $anchors = Get-AnchorMember -Anchors $doc -Name 'runner_anchors'
            $recordedBasis = Get-AnchorMember -Anchors $doc -Name 'basis'
            $recordedKind = Get-AnchorMember -Anchors $doc -Name 'dispatch_kind'
            if ($null -eq $anchors) { $loadError = 'the --against artifact carries no runner_anchors block' }
        }
        catch { $loadError = "the --against artifact is unreadable: $($_.Exception.Message)" }
    }

    # ---- dispatch kind: verify refuses rather than guessing (spec:100-102, 186) ---------------
    $kind = $opt['dispatch-kind']
    if ([string]::IsNullOrWhiteSpace($kind)) { $kind = $recordedKind }
    $scoping = $null
    if (-not [string]::IsNullOrWhiteSpace($kind)) { $scoping = Get-DispatchKindScoping -Kind ([string]$kind) }

    # ---- the arms ------------------------------------------------------------------------------
    # $null means the ORIGIN arm was never REACHED (verify refused earlier); $false Engaged means
    # it was reached and had nothing to compare. The report distinguishes those in arms_not_run,
    # because "did not run" and "ran and found no claim" are different facts about a run.
    $originResult = $null
    $manifestResult = $null
    $parityResult = $null
    if ($null -ne $loadError) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'against_artifact' -Outcome 'ABSENT' -Recorded $againstPath -Derived $null `
            -Detector 'read and parse of the --against artifact' `
            -Residual "Verify refuses when it cannot construct its own basis (spec:185-186). Reason: $loadError" | Out-Null
    }
    elseif ($unresolvableHead) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'head_sha' -Outcome 'ABSENT' -Recorded (Get-AnchorMember -Anchors $anchors -Name 'head_sha') -Derived $null `
            -Detector 'git rev-parse HEAD' `
            -Residual 'HEAD is unresolvable here, so no basis can be constructed and no comparison is admissible (spec:185-186).' | Out-Null
    }
    elseif ($null -eq $scoping) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'dispatch_kind' -Outcome 'ABSENT' -Recorded $kind -Derived $null `
            -Detector 'the schemas SS5 anchor-scoping table, resolved from --dispatch-kind or from the kind recorded in the artifact' `
            -Residual 'Verify refuses rather than guessing when neither supplies a kind it can scope (spec:100-102). Without scoping, the correctness of an absent suite block is undecidable.' | Out-Null
    }
    else {
        Invoke-AnchorArm -Anchors $anchors -Basis $basis -RecordedBasis $recordedBasis -Scoping $scoping -RepoRoot $repoRoot
        $mv = Get-BasisMovedState -RecordedBasis $recordedBasis -Basis $basis
        $originResult = Invoke-OriginArm -Anchors $anchors -BasisMoved $mv.Moved -MovedNote $mv.Note `
            -RepoRoot $repoRoot -BranchFlag ([string]$opt['branch'])
        # SECTION 5's ORDER IS BETWEEN THESE TWO AND IS OBEYED HERE, IN THE CALL ORDER ITSELF:
        # manifest state first (spec:440-442), then plane parity (spec:443), then stream integrity
        # last and over tool-call entries only (spec:444), with the capture-gap subject emitted in
        # its own category (spec:445-449). The last two live inside Invoke-PlaneParityArm, which
        # receives the manifest result rather than re-deriving it -- two derivations of the same
        # state could disagree, and the ordering rule would then depend on which one was read.
        $manifestResult = Invoke-ManifestArm -Anchors $anchors -PlaneRoot $planeRoot -RepoRoot $repoRoot `
            -BasisMoved $mv.Moved -MovedNote $mv.Note
        $parityResult = Invoke-PlaneParityArm -Anchors $anchors -PlaneRoot $planeRoot -RepoRoot $repoRoot `
            -ManifestResult $manifestResult -BasisMoved $mv.Moved -MovedNote $mv.Note
    }

    # ---- the derived exclusion check (spec:128-130) --------------------------------------------
    $orphans = Test-DerivationExclusionDerived -Derivations $script:Derivations
    if ($orphans.Count -gt 0) {
        throw ("MALFORMED: derivations not traceable to the spec:115-126 admitted set: " + ($orphans -join ' | '))
    }

    # ---- gate ------------------------------------------------------------------------------------
    $g = Get-Gate -ArmEntries $script:Arms

    # ---- report -----------------------------------------------------------------------------------
    $emitDerivations = @()
    foreach ($d in $script:Derivations) {
        $c = [ordered]@{}
        foreach ($k in $d.Keys) { if ($k -ne '__subject') { $c[$k] = $d[$k] } }
        $emitDerivations += , $c
    }

    $armsNotRun = @()
    # THE LOOP STAYS THOUGH ITS SET IS NOW EMPTY. It is the MECHANISM by which an unimplemented row
    # discloses itself, and deleting it because today's table has no such row would mean the next
    # increment to add one inherits silence instead of the disclosure. An unrun arm silently absent
    # from the findings is the false-PASS class spec:611-612 names.
    foreach ($row in (Get-DerivationCommandSet | Where-Object { -not $_.Implemented })) {
        $armsNotRun += [ordered]@{
            arm     = $row.Arm
            subject = $row.Subject
            reason  = "not built in increment 3; declared detector: $($row.Command) (spec:$($row.SpecLine))"
        }
    }
    # The MANIFEST and PLANE-PARITY arms are BUILT, so they never appear above. When they run and
    # find no subject, the reason is disclosed here by name -- the same rule the ORIGIN arm follows
    # below, and for the same reason: an arm that ran and compared nothing is indistinguishable
    # from a clean pass unless it says so (spec:64-66).
    if ($null -eq $manifestResult) {
        $armsNotRun += [ordered]@{ arm = 'MANIFEST'; subject = 'evidence_state'
            reason = 'NOT REACHED: verify refused before the arms ran (see the refusing entry in arms). No evidence plane was read and nothing here is a verdict about the manifest.' }
    }
    elseif (-not $manifestResult.Engaged) {
        $armsNotRun += [ordered]@{ arm = 'MANIFEST'; subject = 'evidence_state'; reason = "DID NOT ENGAGE: $($manifestResult.Reason)" }
    }
    if ($null -eq $parityResult) {
        $armsNotRun += [ordered]@{ arm = 'PLANE-PARITY'; subject = 'plane_parity'
            reason = 'NOT REACHED: verify refused before the arms ran (see the refusing entry in arms). No plane detector was run and nothing here is a verdict about the plane.' }
    }
    elseif (-not $parityResult.Engaged) {
        $armsNotRun += [ordered]@{ arm = 'PLANE-PARITY'; subject = 'plane_parity'; reason = "DID NOT ENGAGE: $($parityResult.Reason)" }
    }
    # The ORIGIN arm is BUILT, so it never appears above. When it does not produce entries, the
    # reason is disclosed here by name. An arm that is built, ran, and compared nothing is
    # indistinguishable from a clean pass unless it says so -- the false-PASS class spec:611-612
    # names, and the INCOMPLETE-vs-CLEAN distinction spec:64-66 requires.
    if ($null -eq $originResult) {
        $armsNotRun += [ordered]@{
            arm     = 'ORIGIN-ATTESTATION'
            subject = $script:OriginClaimSubject
            reason  = 'NOT REACHED: verify refused before the arms ran (see the refusing entry in arms). No origin channel was contacted and nothing here is a verdict about origin.'
        }
    }
    elseif (-not $originResult.Engaged) {
        $armsNotRun += [ordered]@{
            arm     = 'ORIGIN-ATTESTATION'
            subject = $script:OriginClaimSubject
            reason  = "DID NOT ENGAGE: $($originResult.Reason)"
        }
    }

    $report = [ordered]@{
        verify_version = '1'
        verify_id      = $verifyId
        invoked_at     = $invokedAt
        against        = [ordered]@{ path = $againstPath; sha256 = $againstSha }
        basis          = $basis
        dispatch_kind  = $kind
        arms           = @($script:Arms)
        arms_not_run   = $armsNotRun
        derivations    = $emitDerivations
        lint           = @()
        gate           = $g.Gate
        refused_by     = $g.RefusedBy
    }

    if ($opt['format'] -eq 'json') { $text = ConvertTo-VerifyJson -Report $report }
    else { $text = ConvertTo-VerifyYaml -Report $report }

    # ---- evidence self-capture (spec:569-582) ------------------------------------------------------
    # spec:187-188 / :581-582 -- verify REFUSES when its own evidence write path fails. That is a
    # refusal (a successful run with a REFUSE gate and a complete report), never a crash.
    #
    # DEFAULT ROOT, stated: when --evidence-root is not supplied the declared home is
    # .mission/evidence (schemas SS5 :459). Increment 1 never drives that default -- the real-store
    # self-capture leg is DEFERRED per A-563:52-56, which forbids greening it by writing the
    # evidence plane from inside a session.
    # Resolved ONCE, above, beside the read plane root -- see the note there. This is the same value
    # every derivation record printed as write_evidence_root.
    $evidenceRoot = $script:WriteEvidenceRoot
    $evidenceWriteFailed = $null
    try {
        $evDir = Join-Path $evidenceRoot $verifyId
        Write-TextFileUtf8NoBom -Path (Join-Path $evDir 'verify-report.yaml') -Text (ConvertTo-VerifyYaml -Report $report)
    }
    catch { $evidenceWriteFailed = $_.Exception.Message }

    if ($null -ne $evidenceWriteFailed) {
        New-ArmEntry -Arm 'ANCHOR' -Subject 'evidence_self_capture' -Outcome 'ABSENT' -Recorded $evidenceRoot -Derived $null `
            -Detector 'write of this run derivation to the evidence root' `
            -Residual "A gate that cannot record what it did is a gate whose output is prose (spec:187-188, 581-582). Reason: $evidenceWriteFailed" | Out-Null
        $g = Get-Gate -ArmEntries $script:Arms
        $report['arms'] = @($script:Arms)
        $report['gate'] = $g.Gate
        $report['refused_by'] = $g.RefusedBy
        if ($opt['format'] -eq 'json') { $text = ConvertTo-VerifyJson -Report $report }
        else { $text = ConvertTo-VerifyYaml -Report $report }
    }

    # ---- emit ---------------------------------------------------------------------------------------
    # A failure to EMIT is exit 2: verify did not complete and no verdict exists (spec:198).
    if ($opt['out']) {
        try { Write-TextFileUtf8NoBom -Path $opt['out'] -Text $text }
        catch {
            Write-Std "verify: could not write the report to '$($opt['out'])': $($_.Exception.Message)"
            Write-Std 'verify: no verdict exists.'
            return 2
        }
    }
    Write-Std $text

    if ($g.Gate -eq 'PASS') { return 0 }
    return 1
}

# =====================================================================================
# SS 10.  THE SEALED LIBRARY IMPORT  (spec:268, 318-321)
# =====================================================================================
#
# IMPORTED, NEVER EDITED, NEVER RE-IMPLEMENTED. The three detectors arms 4.2 and 4.3 are specified
# over live inside sealed anchor EC27AB3A / 80479 b, worktree-class -- the 189f811b / 46870 b figure is SUPERSEDED and 65865a0f / 76413 b is RETIRED -- at tools/framework/hooks/lib/evidence-common.ps1. This
# block is the ONLY place this file names that path, and it names it as an IMPORT PATH: nothing
# here writes it, stages it or hashes it.
#
# IT RUNS HERE, AFTER EVERY FUNCTION DEFINITION AND BEFORE THE ENTRY POINT, for a reason worth
# stating: a dot-source inside a function would scope the imported functions to that function and
# they would vanish on return, so the import has to be at script scope -- and it needs
# Resolve-RepoRoot, which is defined above.
#
# STRICT MODE IS RESTORED IMMEDIATELY AFTERWARDS, AND THAT IS NOT HOUSEKEEPING. The library sets
# `Set-StrictMode -Version Latest` at its line 21. Latest throws on a reference to a non-existent
# property; this file and its two shipped increments were written under 2.0, where such a reference
# yields $null, and the ANCHOR arm's optional-anchor handling depends on that. Letting the
# library's mode leak into this file would change how already-accepted code behaves, which a mere
# import has no business doing. $ErrorActionPreference is re-asserted for the same reason.
$script:EvidenceLib = @{ path = $null; loaded = $false; error = $null }

function Get-EvidenceLibraryPath {
    <#
        Resolved from the repository root first, then relative to this script's own directory, so
        the CLI finds its detectors both when run in place and when a copy is run from elsewhere
        with the repository root resolvable from the working directory. $null when neither
        resolves, which every caller reports as a refusing ABSENT rather than a silent skip.
    #>
    param([AllowNull()][string]$RepoRoot)
    $candidates = @()
    if ($RepoRoot) { $candidates += (Join-Path $RepoRoot 'tools\framework\hooks\lib\evidence-common.ps1') }
    if ($PSScriptRoot) { $candidates += (Join-Path $PSScriptRoot 'framework\hooks\lib\evidence-common.ps1') }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }
    return $null
}

# --library-path (the DEV-1 REFINEMENT, ratified 2026-08-16). READ FROM $args HERE, AT SCRIPT SCOPE,
# because the import runs before Invoke-MissionVerify parses argv -- a flag consumed only in the
# parser would arrive after the decision it governs. WHY THE FLAG EXISTS: Get-EvidenceLibraryPath
# resolves from the WORKING DIRECTORY's repository root first and falls back only to this script's
# own directory, so a COPY of this CLI run from a constructed scratch repository resolves neither and
# every MANIFEST entry comes back ABSENT. The acceptance members that must drive a mutated copy from
# a scratch working directory were unreachable for that reason alone.
#
# ABSENT: the two-candidate search below runs UNCHANGED. PRESENT: the named path is the ONLY
# candidate and is dot-sourced exactly as a found path would be. A missing or unloadable value takes
# the existing EvidenceLib-not-loaded path and THE SEARCH IS NEVER RUN AS A FALLBACK -- a run that
# named a library and silently loaded a different one would report a verdict about detectors it did
# not use, which is the substitution the explicitness exists to prevent.
$__libExplicitGiven = $false
$__libExplicit = $null
for ($__i = 0; $__i -lt ($args.Count - 1); $__i++) {
    if ([string]$args[$__i] -eq '--library-path') {
        $__libExplicitGiven = $true
        $__libExplicit = [string]$args[$__i + 1]
        break
    }
}
$__libRepoRoot = Resolve-RepoRoot
if ($__libExplicitGiven) {
    if ([string]::IsNullOrWhiteSpace($__libExplicit) -or -not (Test-Path -LiteralPath $__libExplicit -PathType Leaf)) {
        $__libPath = $null
        $script:EvidenceLib['error'] = "--library-path named '$__libExplicit' and no file exists there. The two-candidate search is NOT run as a fallback: a run that named a library and silently loaded another would attest detectors it never used."
    }
    else { $__libPath = $__libExplicit }
}
else {
    $__libPath = Get-EvidenceLibraryPath -RepoRoot $__libRepoRoot
    if ($null -eq $__libPath) {
        $script:EvidenceLib['error'] = 'the sealed detector library was not found at tools/framework/hooks/lib/evidence-common.ps1, relative either to the resolved repository root or to this script.'
    }
}
if ($null -ne $__libPath) {
    $script:EvidenceLib['path'] = $__libPath
    try {
        . $__libPath
        $script:EvidenceLib['loaded'] = $true
    }
    catch {
        $script:EvidenceLib['error'] = "the sealed detector library at '$__libPath' could not be imported: $($_.Exception.Message)"
    }
    Set-StrictMode -Version 2.0
    $ErrorActionPreference = 'Stop'
}

# -------------------------------------------------------------------------------------------------
try {
    $code = Invoke-MissionVerify -Argv @($args)
    exit $code
}
catch {
    # spec:198 -- verify itself failed, and NO VERDICT EXISTS. Nothing claiming a verdict is
    # written or printed on this path.
    Write-Std "verify: did not complete -- $($_.Exception.Message)"
    exit 2
}
