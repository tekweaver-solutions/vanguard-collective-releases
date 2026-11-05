#Requires -Version 5.1

# THE BLANK LINE BELOW IS LOAD-BEARING AND ITS ABSENCE MADE THIS ENTIRE HELP BLOCK INVISIBLE
# (driven). The file read `#Requires -Version 5.1` on line 1 and `<#` on line 2,
# and PowerShell 5.1's comment-based-help parser attached NOTHING to the script: `mission-gate.ps1
# -?` printed one auto-generated syntax line, and `Get-Help mission-gate.ps1 -Full` printed the
# same -- no SYNOPSIS, no DESCRIPTION, no PARAMETER text -- for the whole life of this file. The
# block below was never wrong; it was unreachable, which is the worse failure, because a reader
# maintaining it had every reason to believe operators were seeing it.
#
# MEASURED, ON SEVEN VARIANTS OF ONE FILE, because the rule is not the one you would guess: the
# help block must be preceded by a BLANK LINE, and ANY `#` comment line immediately above `<#`
# suppresses it just as `#Requires` does -- the parser takes the contiguous comment run as the
# help candidate, finds no keywords in it, and gives up without a word. `#Requires` + blank + `<#`
# renders; `#Requires` + comment + `<#` does not; `#Requires` + comment + blank + `<#` renders.
# THAT IS WHY THERE IS AN EMPTY LINE BETWEEN THIS PARAGRAPH AND THE BLOCK. Do not close it up.

<#
.SYNOPSIS
  Gate artifacts -- the physical form of a human touchpoint. (LAM-ACCEPT WP-4 T-1)

.DESCRIPTION
  Design SS10.5 / ADR-033. Publishing to origin is an operator-gated irreversible in every local
  topology. In Local Orchestrator Mode the paste of the push dispatch IS the authorization act. In
  Local Autonomous Mode no paste exists, so the authorization becomes an ARTIFACT: created by the
  human, hash-bound to one exact tip, consumed once, retained for audit.

  THIS TOOL IS RUN BY THE HUMAN, NOT BY AN AGENT, AND THIS FILE IS NOW THE FIRST LAYER THAT SAYS SO
  Every gate-MUTATING verb -- approve, reapprove, revoke -- REFUSES, exits 3 and
  writes nothing when the session it is running in is not an operator's. Four conditions, each tested
  and NAMED SEPARATELY in the refusal: LAM_DISPATCH is set (the runner's dispatched-worker marker);
  the harness session environment is present (CLAUDECODE, CLAUDE_CODE_SESSION_ID,
  CLAUDE_CODE_ENTRYPOINT); the session is not interactive; or the invocation looks like a hook's.
  The refusal happens BEFORE the gates directory is created and before any byte is written or moved.
  `list` is untouched -- it reads, and mutates nothing -- and so is `-?`, which PowerShell's
  parameter binder answers before this script body runs at all.

  AND NOW THE CONSOLE'S VERIFIED PATH IS REQUIRED AS WELL -- BOTH, ALWAYS (the
  lead's ruling on a review finding). A gate-mutating verb is admitted IF AND ONLY IF none of the four
  session conditions above fires AND it is invoked through tools\lam\lam-console.ps1's verified path:
  the console composes these exact bytes (`-ComposeOnly`), previews them, collects a SECURE-DESKTOP
  credential, and then mints a per-invocation token in PROCESS MEMORY and calls this tool IN PROCESS
  with it (`-ConsoleToken`). The token is 32 CSPRNG bytes as hex, single-use, short-lived, bound to
  this verb/kind/id, the `-ComposedAt` timestamp and the previewed act digest, and it is NEVER written
  to disk, printed, put in an environment variable or on a command line -- a Start-Process child has a
  different AppDomain and cannot see it. NEITHER HALF ADMITS ON ITS OWN, and every condition that
  fires is reported: running this tool directly refuses naming CONSOLE-VERIFIED-PATH (beside any
  session condition that also fired), and a VALID token presented in a session where a condition
  fires is refused naming that condition (and the token is spent). The console is meant to run in the
  operator's own terminal, where the four conditions do not fire. An earlier draft of this rule let a
  valid token admit the mint even when a condition fired; that weakened the tool relative to its base
  (a console dot-sourced inside an agent session minted there) and is withdrawn. The scrubbed-console
  shape that once minted from an agent session with no token (WP-4's T-25 residual) is refused, for
  want of a token. What this buys and what it does NOT: the authorizing secret (the credential) never
  reaches this agent's surface, because the secure desktop is isolated (measured); but an agent can
  still freely COMPOSE (which authorizes nothing), the tools are tracked files an agent can edit, and
  the in-process registry and the console's injected provider are reachable to any code running in
  process in a console where the four conditions do not fire -- which an agent can start, by building
  a scrubbed console process tree. Those are residuals the design registers rather than hides.
  STAGE 2 -- the gate directory ACL'd to a gate-owner principal the operator's own user cannot write
  -- is DOCUMENTED in LAM-INSTALL as the operator's own setup, and is not built here.

  AND THIS TOOL WRITES NO ATTESTATION LINE -- READ THE GATES DIRECTORY, NOT THE LOG (a session
  validator, DRIVEN). The .mission-runtime\operator-acts.log line is appended by
  lam-console.ps1 and by nothing else; nothing in this file appends to it. So that log records
  CONSOLE ACTS, NOT MINTS: a mint that does not run through the console -- in-process code in a
  console where the four conditions do not fire, the residual named just above -- leaves a real gate
  in .mission\gates and NO line at all, and the validator measured the log absent after exactly such
  a mint. It is therefore NOT an independent second record of a mint and must not be read as one:
  the gates directory is what says which gates exist, and an absent line means EITHER the console
  could not write it OR the mint never came through the console. THE CANDIDATE CURE -- moving the
  attestation write into this tool, so every mint attests whatever called it -- IS A DESIGN CHANGE
  NOBODY HAS RULED ON. It is named here for the operator, not taken.

  THE SENTENCE THAT USED TO STAND HERE WAS FALSE, AND IT IS RECORDED RATHER THAN QUIETLY DELETED.
  It read: "the guard enforces that from the other side: `.mission/gates/**` is hard-denied to every
  agent role (T-3)". Measured against the sources and driven, three ways:

    * `.mission/gates` IS NOT A PROTECTED PATH, so "hard-denied" names a tier that does not cover it.
      `$script:EvidenceProtectedPaths` -- in the sealed library (tools/framework/hooks/lib/
      evidence-common.ps1:1057-1064) and in the next-generation one alike -- holds
      `.mission-runtime/evidence`, `.mission/evidence`, `tools/framework/hooks`,
      `tools/framework/install-evidence-hooks.ps1`, `tools/framework/tests` and
      `.claude/settings.json`, and nothing else. `.mission` reaches only the PARENT tier, which
      denies relocation, deletion and metacharacter commands -- not an ordinary write inside.
      What actually covers the gates directory is TWO OTHER ROUTES: a bespoke TEXT-MATCH predicate
      (`Test-EvidenceGatePath`, which asks A1's matcher about the literal string `.mission/gates`),
      and a permission-layer `Edit(.mission/gates/**)` deny that is present in
      tools/lam/settings/orchestrator.json and tools/lam/settings/worker.json, ABSENT from
      validator.json, and which validator.json's own residual records as NOT binding the shell.
      LAM-ACCEPT.md:777-790 reaches the same reading independently.

    * A HOOK IS A TRIPWIRE, NOT A BOUNDARY, and it exists only inside a harness session.
      Outside one -- an operator terminal, a CI runner, any process the harness did not spawn --
      there is no guard on the other side to enforce anything.

    * AND THE TOOL ITSELF REFUSED NOTHING, WHICH IS THE HALF THAT MATTERED. Driven before this
      change, from a child process with LAM_DISPATCH set, CLAUDECODE set and stdin redirected:
      `approve`, `revoke` and `reapprove` each exited 0, wrote real artifacts into a real gates
      directory, and the real `list` read them back as `open governance`. The artifact an agent had
      just minted carried, as its own third line, "Agents cannot write under .mission/gates/**".

  TWO LAYERS NOW, BOTH NAMED, IN ORDER. FIRST: this file's refusal, which holds wherever the tool
  runs, because it is in the tool. SECOND: `Test-EvidenceGateToolMutation` in
  tools/evidence-hooks-next/hooks/lib/evidence-common.ps1, the guard tripwire
  that denies any command invoking this tool with a verb other than `list`. That tripwire is
  untouched by this change and remains the second layer; its own header already named the layer that
  was missing -- "the durable fix lives on the other side, in an operator/TTY assertion INSIDE
  mission-gate.ps1, which has none today". This is that assertion.

  THE HONEST BOUND, CARRIED RATHER THAN ARGUED AWAY (design SS4.5 law 4). THE CONDITIONS
  DESCRIBE A SESSION, AND A SESSION CAN SPAWN A PROCESS THAT IS IN A DIFFERENT ONE. A process
  started with a fresh console and the harness variables removed from its own environment satisfies
  all four conditions, and an agent can start one: WP-4's T-25 builds exactly such a launcher, in
  the open, because that is how it drives its positive control. SO THIS IS A REFUSAL, NOT A PROOF
  OF HUMANITY. What it buys is that the ratified invocation no longer mints by accident, that the
  refusal travels with the tool instead of living only in a hook, and that a bypass now costs a
  deliberately constructed process tree rather than one ordinary command. That residual belongs in
  the register beside the guard tripwire's, not in a sentence claiming the hole is closed -- which is the
  mistake the paragraph above records.

  KINDS: push | amendment-material | witness-attested | dispatch | supersession | completion-acceptance |
         reclose | halt-ruling.
  COMMANDS: approve, reapprove, list, revoke.

  halt-ruling IS THE OPERATOR'S ANSWER TO ONE HALT. Its -Id MUST be the HALT
  file's BaseName, MUST match ^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$ (the HALT- prefix in any case), and
  its -Binds MUST name that HALT file (a leaf beginning HALT-), or approve and reapprove refuse
  (exit 2, nothing written). The artifact is .mission\gates\halt-ruling-<HALT
  BaseName>.yaml; it records halt_id and the operator's -Ruling words, is permanent until revoked, and
  binds the HALT's bytes: the goal evaluator reads the HALT ANSWERED only while it binds them exactly.

  ============================================================================================
  THE PARAMETER SURFACE OF EVERY VERB. THIS BLOCK IS THE AUTHORITY.
  ============================================================================================
  The SYNTAX line Get-Help generates above is FLAT -- -Kind, -Id, -Binds, -TipSha, -OriginUrl,
  -RemoteRef, -ExpiresMinutes, -Reason and -MissionRoot all sit at the top level regardless of
  verb -- so it cannot tell an operator which parameter belongs to which verb, which are
  mandatory, or which are simply ignored. It says every parameter is available to every verb,
  and that is false of all four.

  PARAMETER SETS ARE THE NATIVE MECHANISM AND THEY WERE TRIED AND REJECTED, MEASURED, NOT ASSUMED.
  Declaring approve/reapprove/revoke/list as four sets over this param block makes Get-Help render
  one SYNTAX line per set -- but it BREAKS the ratified convention, which is not negotiable.
  Driven on a probe shaped exactly like this file: `revoke -Kind K -Id I` exits 1 with
  "Parameter set cannot be resolved using the specified named parameters"
  (FullyQualifiedErrorId AmbiguousParameterSet), because -Kind and -Id belong to both the approve
  and the revoke set and nothing in that invocation disambiguates them. Position 0 carries the verb,
  but a ValidateSet value is not a set discriminator: PowerShell resolves sets from parameter NAMES,
  never from an argument's value. And even when they resolve, the rendered SYNTAX lines are
  `[-Command] <string> [-Kind ...]` three times over -- not one of them says which verb it is for.
  So the mechanism costs every existing call site and does not answer the question either.
  What follows is therefore written by hand, and the WP-4 instrument asserts it against the real
  `-?` output rather than against this source text.

  ALL THREE MUTATING VERBS ALSO TAKE THE CONSOLE-VERIFIED-PATH PARAMETERS, which
  are not per-verb and are not typed by an operator: -ComposeOnly (compose, write nothing),
  -ComposedAt (deterministic timestamp), -ConsoleToken (the in-process token), -ConsoleCredential
  (the provider label). lam-console.ps1 supplies them; a mutating verb run without a valid token, or
  in a session where any of the four conditions fires, is refused. See the .PARAMETER entries above
  for each.

    VERB approve     mint ONE gate at <kind>-<id>.yaml. Refuses if any file is already there.
      mandatory : -Kind -Id -Binds
      optional  : -MissionRoot -ExpiresMinutes -Ruling ; -TipSha -OriginUrl -RemoteRef (push kind only)
      ignored   : -Reason

    VERB reapprove   RE-MINT over the same id in ONE act: revoke the prior, rename it to
                     <kind>-<id>.revoked-N.yaml at the next free N, then approve. Refuses if the
                     prior is CONSUMED, if there is no prior, or if -Binds names a different file.
      mandatory : -Kind -Id -Binds
      optional  : -MissionRoot -ExpiresMinutes -Reason -Ruling ; -TipSha -OriginUrl -RemoteRef (push kind only)
      ignored   : (none)

    VERB revoke      withdraw ONE gate by APPENDING revoked_at / revoked_by / revoked_reason.
                     Never rewrites what was authorized; never renames the file.
      mandatory : -Kind -Id
      optional  : -MissionRoot -Reason
      ignored   : -Binds -TipSha -OriginUrl -RemoteRef -ExpiresMinutes -Ruling

    VERB settle      RECORD THE USE of ONE push, amendment-material or reclose gate, by OBSERVATION.
                     push: the gate's OWN declared origin_url holding authorized_tip_sha at
                     remote_ref; then stamp consumed_at and APPEND consumed_origin_tip, consumed_ref,
                     consumed_origin_before and consumed_basis. amendment-material: the newest
                     commit on HEAD's history holding the bound file at binds_sha256 (as checked
                     out or as stored). reclose: the commit mission-reclose composes for this
                     re-closure number, touching mission.yaml and the ledger, at which mission.yaml
                     reads state Complete. For these two, stamp consumed_at and APPEND
                     consumed_commit, consumed_ref and consumed_basis. Refuses if no use is
                     observed (the authorization is NOT spent), if the gate is already consumed
                     (first stamp wins) or if it is revoked. expires_at does NOT bind it: a settle
                     is a record of use, not an authorization. Every other kind is refused.
      mandatory : -Kind -Id
      optional  : -MissionRoot
      ignored   : -Binds -TipSha -OriginUrl -RemoteRef -ExpiresMinutes -Reason -Ruling

    VERB list        print every gate artifact with its state and derived class.
      mandatory : (none)
      optional  : -MissionRoot
      ignored   : -Kind -Id -Binds -TipSha -OriginUrl -RemoteRef -ExpiresMinutes -Reason -Ruling

    -ExpiresMinutes is IGNORED for the four recorded-ruling kinds (supersession, completion-acceptance,
    reclose, halt-ruling); -Ruling is IGNORED for every kind but halt-ruling.

  WHAT approve RECORDS, and why each field is there:
    binds / binds_sha256   the artifact this authorization is ABOUT, by hash -- so an approval
                           cannot be silently re-pointed at different content
    authorized_tip_sha     for push gates: the exact commit authorized to become origin's tip
    halt_id / ruling       for halt-ruling gates: the HALT this answers (its BaseName) and the
                           operator's own words, or the recorded absence of them
    single_use: true       stated on the artifact; its one use is recorded by the push hook or by settle
    authorized_by          the invoking host user name -- who, on this machine, said yes
    created_at/expires_at  an authorization is not open-ended

  WHAT approve DELIBERATELY DOES NOT DO: it does not push, does not consume, and does not verify
  origin. A use is recorded afterwards -- by the push hook, which witnesses a push, or by settle at
  the operator's console; operator browser confirmation of the origin tip remains standing law
  regardless of what this artifact says.

.PARAMETER Command
  approve | reapprove | revoke | settle | list. Positional 0. See THE PARAMETER SURFACE above for
  which other parameters each verb reads and which it ignores.

.PARAMETER Kind
  The gate kind. Used by approve, reapprove and revoke; IGNORED by list. On revoke and reapprove
  the ARTIFACT's own `kind:` field is the authority and a mismatch is refused -- a file NAMED for
  one kind is not a gate of that kind. For halt-ruling, approve and reapprove also refuse (exit 2,
  nothing written) unless -Id matches ^HALT-[A-Za-z0-9][A-Za-z0-9._-]*$ (prefix in any case), -Id
  equals the -Binds leaf's BaseName, and that leaf begins HALT-.

.PARAMETER Id
  The gate id. Used by approve, reapprove and revoke; IGNORED by list.

.PARAMETER Binds
  The ONE file this authorization is about, hashed into binds_sha256. Mandatory for approve and
  reapprove; IGNORED by revoke and list. Resolved against -MissionRoot, never against the shell's
  directory. On reapprove it must name THE SAME FILE the prior gate binds; its CONTENT is free to
  differ, and usually does -- that is what a re-mint is for.

.PARAMETER Reason
  Why a gate is being withdrawn. Used by revoke and reapprove; IGNORED by approve and list.
  OPTIONAL by decision, not by omission -- see the note at the parameter itself. When it is absent
  the artifact records the absence explicitly rather than saying nothing.

.PARAMETER Ruling
  The operator's ruling words for a halt-ruling gate. Used by approve and
  reapprove for -Kind halt-ruling only; IGNORED for every other kind and by revoke and list. Recorded
  on ONE line as ruling: "...", newlines collapsed and quotes and backslashes escaped the way
  revoked_reason is. OPTIONAL: when it is absent the artifact records the absence explicitly. It is
  part of the composed bytes, so the console previews it and the act digest covers it.

.PARAMETER MissionRoot
  The mission root every mission-scoped path resolves against. Used by all four verbs.

.PARAMETER TipSha
  The exact commit a push gate authorizes. Used by approve and reapprove, and only for -Kind push
  (derived from HEAD when omitted); IGNORED by every other kind and by revoke and list.

.PARAMETER OriginUrl
  The origin URL a push gate DECLARES. Used by approve and reapprove for -Kind push
  only; IGNORED otherwise.

.PARAMETER RemoteRef
  The remote ref a push gate DECLARES. Used by approve and reapprove for -Kind push only; IGNORED
  otherwise.

.PARAMETER ExpiresMinutes
  Lifetime of an expiring gate. Used by approve and reapprove; IGNORED by revoke and list, and
  IGNORED for the four recorded-ruling kinds (supersession, completion-acceptance, reclose,
  halt-ruling), which are permanent until revoked and carry no expires_at at all.

.PARAMETER ComposeOnly
  THE CONSOLE-VERIFIED PATH. Runs every refusal and composition step for a
  mutating verb and WRITES NOTHING, emitting machine-readable LAMCOMPOSE lines: each planned write
  (base64 name, byte length, base64 bytes), the resolved binds path and sha256, and one act digest
  over the ordered writes. It needs no token and does not run the four session conditions -- composing
  is not authorizing. lam-console.ps1 calls this to build its preview.

.PARAMETER ComposedAt
  A UTC round-trip timestamp (yyyy-MM-ddTHH:mm:ss.fffZ) that replaces every Get-Date in the composed
  bytes (created_at, expires_at, revoked_at), so the digest the console previews and the digest this
  tool re-derives at mint are byte-identical. Supplied by the console; the live time when omitted.
  VALIDATED, NOT MERELY EQUALITY-CHECKED: whenever it is supplied, for every verb, it must be EXACTLY
  that form -- 24 characters, no whitespace, no control character -- and parse as a UTC instant with
  the invariant culture, or the tool refuses (exit 2, COMPOSED-AT-MALFORMED, nothing written). For
  approve, reapprove and revoke, in compose and in mint alike, it must also lie within 10 minutes of
  the current UTC time in either direction, or the tool refuses (exit 2, COMPOSED-AT-OUT-OF-WINDOW,
  nothing written).

.PARAMETER ConsoleToken
  The per-invocation token lam-console.ps1 minted in process memory after the credential succeeded.
  A mutating verb REFUSES without a valid one -- and a valid one does not admit on its own either: if
  any of the four session conditions fires the verb is refused all the same, naming the condition,
  and the token is spent. Validated against a process-memory registry the
  console populated (single-use, short-lived, verb/kind/id/-ComposedAt/act-digest all matched); never
  written to disk, printed, put in an environment variable or on a command line. Operators never pass
  it by hand -- they run the console.

.PARAMETER ConsoleCredential
  THE LABEL THE MINTING CALLER DECLARED, and no more than that: secure-desktop-credui or
  injected-seam. Written onto the artifact as operator_credential and part of the composed bytes, so
  the act digest covers the declared label. IT IS NOT EVIDENCE OF HOW THE MINT WAS AUTHORIZED
  (a session validator, DRIVEN): in-process code in a console where the four session
  conditions do not fire declares either value, and a validator minted -- through lam-console.ps1's
  own files with the credential provider replaced, and again with that provider skipped entirely --
  artifacts whose face read secure-desktop-credui. Read it as a convenience for telling a scratch
  fixture's gate from an operator's act. This tool does require the label to match the one registered
  with the -ConsoleToken, and the console requires its provider to report the same one, but both are
  consistency checks over values the same in-process caller supplied.

.EXAMPLE
  tools\lam\lam-console.ps1 approve -Kind amendment-material -Id am-<n> -Binds .mission\amendments\AM-<n>.yaml -MissionRoot .

.EXAMPLE
  tools\lam\lam-console.ps1 reapprove -Kind amendment-material -Id am-<n> -Binds .mission\amendments\AM-<n>.yaml -Reason "v2 restates the counts" -MissionRoot .

.EXAMPLE
  tools\lam\lam-console.ps1 revoke -Kind dispatch -Id v-a-581-r1 -Reason "round 1 superseded" -MissionRoot .

.EXAMPLE
  tools\lam\mission-gate.ps1 list

.EXAMPLE
  tools\lam\lam-console.ps1 approve -Kind halt-ruling -Id HALT-<name> -Binds .mission-runtime\halts\HALT-<name>.md -Ruling "..." -MissionRoot .
#>
[CmdletBinding()]
param(
    # `reapprove`. ONE verb for what was THREE operator acts plus a manual file
    # rename: revoke the prior, move it to <kind>-<id>.revoked-N.yaml at the next free N, approve
    # over the same binds. The record contains ELEVEN revoked artifacts across SEVEN gate ids, so
    # this dance has been performed by hand eleven times -- and the evidence that it is unguarded is
    # on disk: dispatch-v-r-s3-r1.revoked-1.yaml carries NO revoked_at at all. It was renamed out of
    # the way and never revoked, because the rename is the operator's act and nothing checks that
    # the revoke half happened. `reapprove` is the ONLY place in this tool that renames a gate.
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('approve','reapprove','list','revoke','settle')]
    [string]$Command,

    # `supersession`: ratifies ONE *.superseded.yaml marker by
    # binding its sha256. The runner honours a marker's skip ONLY against a matching gate of this
    # kind. The provenance source has to be an artifact an agent CANNOT mint -- because a registry
    # the agent writes would reintroduce, one layer up, exactly the hole that ratifying markers is
    # meant to close.
    #
    # WHAT MAKES IT UNMINTABLE IS RESTATED HERE BECAUSE THE OLD SENTENCE NAMED THE WRONG MECHANISM
    # It read "T-3 hard-denies every agent role from writing under the gates
    # directory", and `.mission/gates` is in no `$EvidenceProtectedPaths` list -- see the
    # .DESCRIPTION block above for what was measured. The unmintability now rests FIRST on this
    # tool's own refusal (the human-only check below, which runs before any verb mutates anything)
    # and SECOND on the guard's mint tripwire `Test-EvidenceGateToolMutation`,
    # which is a tripwire and not a boundary and is only present inside a harness session.
    # `completion-acceptance`: accepts ONE package's verdict on the
    # strength of its registered residuals, by binding the residual manifest's sha256. Governance
    # class; permanent until revoked, because an acceptance is a recorded ruling and not a capability.
    # `reclose`: authorizes ONE Reworking ->
    # Complete transition (ADR-029) by binding the re-closure's LEDGER CONTENT FILE by sha256 -- the
    # file mission-reclose.ps1 is passed as -LedgerContentFile and appends verbatim to the ledger.
    # It exists because the two re-closures that have been gated so far (reclose-44, reclose-45) had
    # to borrow `completion-acceptance`, whose own lifecycle text is false of them in two places at
    # once: it asserts a REFUTED package (a reclose's package is MET) and it asserts the artifact
    # binds docs/framework/LAM-RESIDUALS.md, which neither of them does. Governance class, permanent
    # until revoked, for the same reason a supersession is.
    # `halt-ruling` (batch 4 item 3, operator ruling): ANSWERS ONE HALT by binding
    # that HALT file's bytes by sha256. The goal evaluator reads a HALT as ANSWERED only while a live
    # gate of this kind binds its CURRENT bytes -- the seat's own `**Status:**` line answers nothing
    # any more, because the HALT file is agent-writable and one Edit used to flip the verdict. Its id
    # IS the HALT file's BaseName, enforced below, so each HALT has exactly one canonical gate path.
    # Governance class, permanent until revoked, for the same reason a supersession is.
    [ValidateSet('push','amendment-material','witness-attested','dispatch','supersession','completion-acceptance','reclose','halt-ruling')]
    [string]$Kind,

    [string]$Id,
    [string]$Binds,
    [string]$MissionRoot = '.',
    [string]$TipSha,

    # A PUSH GATE BINDS A TRIPLE, NOT A SHA.
    #
    # `.git/config` is ruled an UNPROTECTABLE control surface. Ordinary work writes it
    # (`git remote add`, `git config user.email`, the runner's own worktrees), so guarding it would
    # refuse the workflow it protects -- and since a hook is a tripwire, not a boundary, a tripwire there would record
    # rather than prevent. Round 12 drove the consequence: repointing `remote.origin.url` at a decoy
    # bare repo made S-4 report PASS while the real origin held an unauthorized commit. The detector
    # was reading the attacker's own configuration and calling it evidence.
    #
    # So the operator DECLARES the origin at approval time, on the artifact, and every consumer reads
    # it FROM THE GATE. A later `remote.origin.url` edit then changes nothing: detection asks the
    # DECLARED origin what it holds. This is the compensating control for a surface that cannot be
    # guarded, which is a different thing from pretending the surface is safe.
    [string]$OriginUrl,
    [string]$RemoteRef,

    # -Reason. A revocation recorded revoked_at and revoked_by and NOTHING about
    # WHY -- so the eleven revoked artifacts on disk say who withdrew an authorization and when, and
    # a reader reconstructing why has only the surrounding ledger prose, if anyone wrote any.
    #
    # IT IS OPTIONAL, AND THAT IS A DECISION WITH A PRICE, STATED. Making it mandatory would refuse
    # the ratified convention `mission-gate.ps1 revoke -Kind X -Id Y`, which the record uses, which
    # this build's own instrument drives, and which the row's cure is forbidden to break. It would
    # also put the tool's ONE refusal in the operator's way at the moment they are trying to WITHDRAW
    # a capability -- the one direction where a governance tool must never be the obstacle, because
    # the fail-closed move is to let the withdrawal through.
    #
    # SO THE ABSENCE IS RECORDED INSTEAD OF LEFT BLANK. Every revocation this tool writes carries a
    # `revoked_reason:` line; without -Reason it reads, verbatim,
    #     (NO REASON GIVEN -- -Reason was not supplied)
    # which an audit reader can tell apart from an artifact written before the field existed. A field
    # that is simply absent is indistinguishable from one that was never offered, and those are two
    # different facts about the operator.
    [string]$Reason,

    # -Ruling. THE OPERATOR'S WORDS RIDE ON THE GATE, AND THAT IS A DECISION.
    # Once a halt-ruling gate binds a HALT's bytes, nobody may write the ruling INTO the HALT (that
    # re-opens it), and the seat's citation sidecar is non-authoritative by design. So the only
    # operator-minted, byte-previewed, digest-covered place the ruling itself can live is this
    # artifact. Used for -Kind halt-ruling only and ignored for every other kind, so no other kind's
    # bytes change. OPTIONAL, like -Reason, and for the same reason: its absence is RECORDED --
    #     ruling: "(NO RULING TEXT GIVEN -- -Ruling was not supplied)"
    # -- rather than left as a missing line a reader cannot tell apart from an artifact that predates
    # the field.
    [string]$Ruling,

    [int]$ExpiresMinutes = 60,

    # THE CONSOLE-VERIFIED PATH (batch 4 item 1). A gate-mutating verb no longer
    # mints on its own: it mints ONLY through lam-console.ps1, which composes the exact bytes, previews
    # them, collects a SECURE-DESKTOP credential, and then mints a per-invocation token in process
    # memory and calls this tool IN PROCESS with it. These four parameters are the surface of that
    # path; an operator never types the last two by hand.
    #
    # -ComposeOnly runs every refusal and composition step and WRITES NOTHING, emitting the exact
    # bytes of every planned write, the resolved binds path and sha256, and one act digest. It needs
    # no token and does not run the four operator conditions -- composing is not authorizing.
    [switch]$ComposeOnly,

    # -ComposedAt makes composition DETERMINISTIC: a UTC round-trip timestamp
    # (yyyy-MM-ddTHH:mm:ss.fffZ) that replaces every Get-Date in the composed bytes (created_at,
    # expires_at, revoked_at), so the digest the console previews and the digest this tool re-derives
    # at mint are computed over identical bytes. It is validated below (exact form, and a 10-minute
    # window for the mutating verbs) before anything else reads it.
    [string]$ComposedAt,

    # -ConsoleToken is the per-invocation token lam-console.ps1 minted after the credential succeeded.
    # It is validated against a process-memory registry the console populated ([AppDomain] SetData),
    # which a Start-Process child does NOT share -- so it is un-forgeable from a child process and is
    # never written to disk, printed, put in an environment variable or on a command line.
    [string]$ConsoleToken,

    # -ConsoleCredential records, on the minted artifact, THE LABEL THE MINTING CALLER DECLARED --
    # secure-desktop-credui or injected-seam -- and it is part of the composed bytes, so the digest
    # covers the declared label. It is NOT evidence of how the mint was authorized: in-process code
    # in a console where the four session conditions do not fire declares either value (register row
    # 179, session validator, DRIVEN -- a mint with the console's credential provider replaced, and
    # one with that provider skipped entirely, both wrote secure-desktop-credui onto the artifact).
    [string]$ConsoleCredential
)

$ErrorActionPreference = 'Stop'

# GATE CLASSIFICATION. The kind -> class map lives
# in exactly one file and is dot-sourced by both consumers -- this tool, which WRITES the class,
# and the WP-6 zero-paste member, which READS it. A predicate two consumers share must live in one
# place: this build already lost a run to a regex that existed twice and disagreed with itself.
$gateClassLib = Join-Path $PSScriptRoot 'lam-gate-class.ps1'
if (-not (Test-Path -LiteralPath $gateClassLib)) {
    Write-Output "mission-gate: the gate-class map is not on disk at $gateClassLib -- refusing to write a gate whose class would be silently absent."
    exit 2
}
. $gateClassLib

# UI-1 S1 (ADR-045): THE MISSION-EVENT FEED. After a gate write lands, one line read off the artifact
# itself -- gate_minted (approve/reapprove), gate_consumed (settle), gate_expired (list, once per gate) --
# plus halt_resolved ANSWERED when a halt-ruling answers its HALT. Through tools\lam\mission-telemetry.ps1,
# skipped when that file is absent; it writes nothing to this tool's output and can fail nothing.
# No -Kind: no gate line, the snapshot alone -- revoke, which SS14 gives no kind of its own, but which changes
# the derived state when it revokes a halt-ruling gate (its HALT is open again).
function Send-LamGateTelemetry {
    param([string]$Kind = '', [string]$GatePath = '', [string]$HaltKind = '', [string]$HaltPath = '', [string]$Resolution = '', [switch]$Snapshot)
    try {
        $tm = Join-Path $PSScriptRoot 'mission-telemetry.ps1'
        if (-not (Test-Path -LiteralPath $tm -PathType Leaf)) { return }
        . $tm
        $evts = @()
        if ($Kind -and $GatePath) { $evts += @{ Kind = $Kind; GatePath = $GatePath } }
        if ($HaltKind -and $HaltPath) { $evts += @{ Kind = $HaltKind; HaltPath = $HaltPath; Resolution = $Resolution } }
        Invoke-MissionTelemetry -Root $MissionRoot -Events $evts -Snapshot:$Snapshot -Verb 'mission-gate'
    } catch { }
}

trap {
    Write-Output "mission-gate: UNHANDLED ERROR -- $($_.Exception.Message)"
    Write-Output "  stack: $(($_.ScriptStackTrace -split "`r?`n") -join ' | ')"
    exit 9
}

if (-not (Test-Path -LiteralPath $MissionRoot -PathType Container)) {
    Write-Output "mission-gate: mission root not found: $MissionRoot"
    exit 2
}
$MissionRoot = (Resolve-Path -LiteralPath $MissionRoot).Path
$gatesDir = Join-Path $MissionRoot '.mission\gates'

function Get-GatePath {
    param([string]$K, [string]$I)
    Join-Path $gatesDir "$K-$I.yaml"
}

# ONE SPELLING OF THE REVOCATION STAMP, used by `revoke` and by `reapprove`. Restating it would be
# the fourth instance of this file's oldest defect class -- lam-gate-class.ps1's header records
# three predicates that existed twice and whose copies disagreed, each time in the permissive
# direction. The reason text an absent -Reason produces is the tool's DOCUMENTED decision and is
# asserted by the instrument against this exact string.
$script:LamNoReasonText = '(NO REASON GIVEN -- -Reason was not supplied)'
# THE HALT-RULING COUNTERPART: the recorded absence of -Ruling, asserted verbatim
# by WP-4 T-27.
$script:LamNoRulingText = '(NO RULING TEXT GIVEN -- -Ruling was not supplied)'
# THE ORIGIN-OBSERVATION COUNTERPARTS (operator ruling (i)), asserted verbatim by WP-4
# T-31 and read by the settle verb. A push mint records WHAT THE DECLARED ORIGIN HELD, and there are
# THREE outcomes, so there are THREE distinct records: a 40-hex sha, or one of these two.
#
# THEY ARE SEPARATE CONSTANTS ON PURPOSE. "We asked and the ref was not there" and "we could not ask
# at all" are different facts about the world, and one shared "unknown" would let a consumer read an
# unreachable origin as an empty one -- the conflation this toolchain refuses everywhere else. A
# MISSING LINE would be a third and worse thing, indistinguishable from an artifact minted before the
# field existed, which is the same argument that put $script:LamNoReasonText above.
$script:LamOriginTipRefAbsentText  = '(REF NOT PRESENT AT ORIGIN AT MINT -- the declared origin answered and holds no such ref)'
$script:LamOriginTipUnobservedText = '(ORIGIN NOT OBSERVED AT MINT -- the declared origin could not be asked; this is NOT a claim that the ref is absent)'
# THE HALT-RULING -Id PATTERN (a review's finding), asserted by WP-4 T-27. The prefix is
# case-insensitive to agree with the scan; the rest is the exact class.
$script:LamHaltRulingIdPattern = '\A(?i:HALT-)[A-Za-z0-9][A-Za-z0-9._-]*\z'
function ConvertTo-LamOneLineYamlQuoted {
    # ONE LINE, AND YAML-SAFE -- the discipline Get-RevocationStamp applies to revoked_reason, applied
    # to the ruling text: line breaks collapsed to a space, trimmed, then backslash and double quote
    # escaped for a YAML double-quoted scalar. Returns the text WITHOUT the surrounding quotes.
    # ONE STEP STRICTER THAN revoked_reason, deliberately: a LONE carriage return and every other C0
    # control byte but tab (and DEL) become a space too -- YAML reads a lone CR as a line break, and a
    # raw control byte is not a legal character in a double-quoted scalar at all.
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $one = (([string]$Text -replace '[\r\n]+', ' ') -replace '[\x00-\x08\x0B-\x1F\x7F]', ' ').Trim()
    return $one.Replace('\', '\\').Replace('"', '\"')
}
function Get-RevocationStamp {
    # -At makes the timestamp DETERMINISTIC for compose/mint: when the console
    # supplies -ComposedAt, the revoked_at written here is that exact value, so the bytes the console
    # previewed and the bytes minted are identical. When absent the live UTC time is used, as before.
    param([AllowNull()][string]$Why, [string]$At)
    $r = if ($Why) { $Why } else { $script:LamNoReasonText }
    # ONE LINE, AND YAML-SAFE. A reason carrying a newline would split the mapping and a reason
    # carrying a quote or a backslash would end the scalar early -- on an artifact whose whole value
    # is that a consumer can parse it. Collapsed and escaped here rather than trusted.
    $r = ($r -replace '\r?\n', ' ').Trim()
    $r = $r.Replace('\', '\\').Replace('"', '\"')
    $ts = if ($At) { $At } else { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture) }
    return "revoked_at: $ts`nrevoked_by: $env:USERNAME`nrevoked_reason: `"$r`"`n"
}

# =================================================================================================
# THE CONSOLE-VERIFIED PATH. The contract with tools/lam/lam-console.ps1 is these
# two constants and the entry shape, stated in both files character for character. The registry lives
# in [AppDomain]::CurrentDomain, which a Start-Process child does NOT share -- measured -- so a token
# is un-forgeable from a child process and need never touch disk, an env var or a command line.
# =================================================================================================
$script:LamConsoleTokenRegistryKey = 'LamConsoleTokenRegistry'
$script:LamConsoleCredentialSet    = @('secure-desktop-credui', 'injected-seam')

function Get-LamActDigest {
    # THE CANONICAL FRAMING, DOCUMENTED: for each planned write, in order, append UTF8 of
    # (name + LF + decimal-byte-length + LF) and then the raw write bytes; sha256 the whole. The
    # console previews this digest; this tool re-derives it from the bytes it is about to write and
    # requires equality before the mint proceeds. Both sides compute it here, from the same ordered
    # writes, so a byte that differs anywhere moves the digest.
    param($Writes)
    $ms = New-Object System.IO.MemoryStream
    try {
        foreach ($w in @($Writes)) {
            $hdr = [System.Text.Encoding]::UTF8.GetBytes($w.name + "`n" + $w.bytes.Length + "`n")
            $ms.Write($hdr, 0, $hdr.Length)
            $ms.Write($w.bytes, 0, $w.bytes.Length)
        }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($ms.ToArray()))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $ms.Dispose() }
}

function Test-LamConsoleTokenBasics {
    # The token's IDENTITY checks (existence, not spent, not expired, verb/kind/id/ComposedAt match).
    # The DIGEST check is deferred to Assert-LamConsoleTokenDigest, which runs once the exact bytes
    # exist. Returns @{ ok; reason }.
    # THE BOUNDARY THESE CHECKS DRAW IS THE PROCESS, NOT THE CONSOLE (a session
    # validator, DRIVEN). The registry is [AppDomain]::CurrentDomain data, so a child process cannot
    # see an entry or forge one -- but any code running in THIS process can write one: the validator
    # did, with SetData and a hand-written token and no console code at all, and minted. The refusals
    # below are unchanged in what they refuse; only what they CLAIM is corrected.
    param([string]$Verb, [string]$K, [string]$I, [string]$At, [string]$Token, [string]$Credential)
    if (-not $Token) {
        return @{ ok = $false; reason = 'no -ConsoleToken was supplied. A gate-mutating verb mints ONLY with a token in the in-process registry -- lam-console.ps1 registers one after it collects a secure-desktop credential, and any other code running in this process can register one too (a session validator, DRIVEN); running this tool directly, or from a child process, no longer mints.' }
    }
    $reg = [AppDomain]::CurrentDomain.GetData($script:LamConsoleTokenRegistryKey)
    if (-not ($reg -is [hashtable]) -or -not $reg.ContainsKey($Token)) {
        return @{ ok = $false; reason = 'the -ConsoleToken is not in the in-process registry. Only code running IN THIS PROCESS can carry it -- console or not: the registry is [AppDomain]::CurrentDomain data, so a child process (powershell -File) has a different AppDomain and cannot see it, while any in-process code can register an entry without the console (DRIVEN by a session validator with SetData and a hand-written token).' }
    }
    $e = $reg[$Token]
    if ($e.used) { return @{ ok = $false; reason = 'the -ConsoleToken was already spent (single use).' } }
    if ((Get-Date).ToUniversalTime() -gt $e.expiresUtc) { return @{ ok = $false; reason = 'the -ConsoleToken has expired (short lifetime from credential success).' } }
    if ($e.verb -ne $Verb) { return @{ ok = $false; reason = "the token authorizes verb '$($e.verb)', not '$Verb'." } }
    # A GATE KIND IS CASE-SIGNIFICANT (an operator ruling). `-ne` FOLDED here, so a token minted
    # for `push` authorized an invocation naming `PUSH`. It is ORDINAL now -- and deliberately NOT
    # routed through Resolve-LamGateKind: `-Kind` is not Mandatory, so `$K` is legitimately EMPTY
    # for an invocation that omits it, and a resolver-based refusal here would replace the per-verb
    # refusal that names the MISSING PARAMETER with one about an unrecognised kind. The property
    # this line owns is that the token and the invocation name the SAME STRING; whether that string
    # is a gate kind is :1580's question, and that one asks the shared reader.
    if ("$($e.kind)" -cne "$K") {
        $kindCaseNote = if ("$($e.kind)" -eq "$K") { ' -- the same letters in a different case, and a gate kind is CASE-SIGNIFICANT' } else { '' }
        return @{ ok = $false; reason = "the token authorizes kind '$($e.kind)', not '$K'$kindCaseNote." }
    }
    if ("$($e.id)" -ne "$I")   { return @{ ok = $false; reason = "the token authorizes id '$($e.id)', not '$I'." } }
    if ("$($e.composedAt)" -ne "$At") { return @{ ok = $false; reason = 'the token -ComposedAt does not match this invocation.' } }
    if ($Credential -and ("$($e.credential)" -ne "$Credential")) { return @{ ok = $false; reason = "the token credential label '$($e.credential)' does not match -ConsoleCredential '$Credential'." } }
    return @{ ok = $true; reason = 'ok' }
}

function Assert-LamConsoleTokenDigest {
    # The DIGEST check, at the write checkpoint. Marks the entry used BEFORE the first write. Returns
    # @{ ok; reason }.
    param([string]$Token, [string]$Digest)
    $reg = [AppDomain]::CurrentDomain.GetData($script:LamConsoleTokenRegistryKey)
    if (-not ($reg -is [hashtable]) -or -not ($Token -and $reg.ContainsKey($Token))) {
        return @{ ok = $false; reason = 'the -ConsoleToken vanished from the registry before the write.' }
    }
    $e = $reg[$Token]
    if ($e.used) { return @{ ok = $false; reason = 'the -ConsoleToken was already spent (single use).' } }
    if ("$($e.actDigest)" -ne "$Digest") {
        return @{ ok = $false; reason = "act digest mismatch: the token previewed $($e.actDigest) but this tool is about to write $Digest." }
    }
    $e.used = $true
    return @{ ok = $true; reason = 'ok' }
}

function Invoke-LamGateComposeOrRefuse {
    # THE WRITE CHECKPOINT, shared by revoke and approve/reapprove. In -ComposeOnly it emits the
    # machine-readable preview lines and exits 0 without writing. Otherwise it validates the console
    # token's act digest, marks it used, and returns so the caller may write. On a digest failure it
    # refuses exactly like the top-level refusal -- exit 3, nothing written, CONSOLE-VERIFIED-PATH
    # named. $ComposeOnly and $ConsoleToken are read from the script's parameters.
    param([string]$Verb, $Writes, [string]$BindsPath, [string]$BindsSha, [string]$ActDigest)
    if ($ComposeOnly) {
        if ($BindsPath) { Write-Output ("LAMCOMPOSE binds_path " + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($BindsPath))) }
        if ($BindsSha)  { Write-Output ("LAMCOMPOSE binds_sha256 " + $BindsSha) }
        foreach ($w in @($Writes)) {
            Write-Output ("LAMCOMPOSE write " + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($w.name)) + " " + $w.bytes.Length + " " + [Convert]::ToBase64String($w.bytes))
        }
        Write-Output ("LAMCOMPOSE act_digest " + $ActDigest)
        exit 0
    }
    $dg = Assert-LamConsoleTokenDigest -Token $ConsoleToken -Digest $ActDigest
    if (-not $dg.ok) {
        Write-Output "mission-gate: REFUSED -- '$Verb' reached the write with a console token that does not authorize these exact bytes."
        Write-Output "  A gate artifact IS the human touchpoint, minted only through the console's verified path."
        Write-Output "  NOTHING WAS WRITTEN: no gates directory was created, no artifact minted, renamed or appended."
        Write-Output "  CONDITIONS THAT FIRED (1):"
        Write-Output "    - CONSOLE-VERIFIED-PATH -- $($dg.reason)"
        # LEGIBILITY FOR THE ONE NEW REFUSAL THIS BUILD CREATES (operator ruling (i)). A
        # push gate's composed bytes now carry origin_tip_at_mint, and compose and mint each observe
        # the declared origin INDEPENDENTLY -- the ruling says the MINT records it, so the value is not
        # carried across as a parameter and is not cached. An origin that MOVES between the operator
        # reading the preview and confirming it therefore makes the two byte streams differ and lands
        # exactly here. That is correct and fail-closed: an authorization previewed against one origin
        # state and minted against another is precisely what this digest exists to catch. But it is a
        # NEW way for a push mint to refuse, and an operator must be able to tell it from a tamper, so
        # the refusal points at the field rather than leaving them to guess. CONSOLE OUTPUT ONLY --
        # this writes no bytes into any artifact, and no other kind's refusal text moves.
        # SCOPED TO THE MINTING VERBS, NOT TO THE KIND ALONE. This checkpoint also serves
        # `revoke`, which re-reads no origin and cannot produce the race below -- so a revoke of
        # a PUSH gate would have been told to go and look at a field whose re-reading had nothing
        # to do with its refusal. Pointing an operator at work that changes nothing is the
        # round-14 defect this refusal family was rewritten to cure, and it is not reintroduced.
        if (($Kind -eq 'push') -and (@('approve','reapprove') -contains $Verb)) {
            Write-Output "  THIS IS A PUSH GATE: CHECK origin_tip_at_mint IN THE PREVIEW ABOVE BEFORE SUSPECTING TAMPERING."
            Write-Output "  That field is read from the declared origin TWICE -- once to compose the preview, once to mint --"
            Write-Output "  so an origin that MOVED between the two makes these bytes differ and produces exactly this refusal."
            Write-Output "  Re-run the act to authorize against what origin holds NOW; a repeat over a still origin is not this."
        }
        exit 3
    }
}

# =================================================================================================
# T-3, TRUE BY CONSTRUCTION. THE FIRST LAYER; THE GUARD TRIPWIRE IS THE SECOND.
# =================================================================================================
# The .DESCRIPTION above records what was false and what was measured. This is the code that makes
# the sentence true: every gate-MUTATING verb refuses when the session is not an operator's, and it
# refuses BEFORE the gates directory is created and before any byte is written, renamed or appended.
#
# ALLOWLIST THE READ VERB, NEVER BLACKLIST THE MUTATORS -- the same shape the guard's own mint-tripwire
# block argues for, and for the same reason: `[ValidateSet('approve','reapprove','list','revoke')]`
# at the top of this file is exactly the kind of list that grows, and a blacklist of today's three
# mutators would admit tomorrow's fourth in silence. `list` is named; everything else is gated.
#
# NO OVERRIDE IS PROVIDED, AND THAT IS DELIBERATE. Any environment variable an operator could set to
# bypass this is a variable an agent can set more cheaply than it can satisfy the conditions -- the
# bypass would be strictly easier than the thing bypassed, which is the definition of a hole. An
# operator who needs to mint runs the tool from their own terminal, which is the act the whole
# control exists to require. The cost is stated rather than argued away: a legitimate operator on a
# genuinely non-interactive channel (an unattended CI job, a piped-stdin shell, a remote session
# with no console) is refused and has to re-run from a console. That is the fail-closed direction.
#
# WHAT EACH PREDICATE WAS MEASURED TO DO, because two of the obvious ones cannot tell the cases
# apart and shipping one that cannot would be this build's own overclaim:
#   [Environment]::UserInteractive   True in BOTH an operator console AND an agent-launched child.
#                                    IT DOES NOT DISTINGUISH THEM. It is still consulted, because a
#                                    False is conclusive (a service or a window-station-less host),
#                                    but it is never the only thing asked.
#   [Console]::IsInputRedirected     False in an operator console; True in a child whose stdin the
#                                    parent redirected. THIS IS THE ONE THAT DISTINGUISHES, driven
#                                    both ways.
#   [Console]::KeyAvailable          Returns in a console; THROWS where there is no console input
#                                    buffer. Corroborates the same underlying fact by a second
#                                    route, which is why both are asked rather than one.
# settle IS A MUTATING VERB (operator ruling (i)) AND JOINS THIS LIST, NOT ONLY
# THE ValidateSet. This list is what subjects a verb to the four session conditions and to the
# -ComposedAt window; a verb added to the ValidateSet alone would be a mutator that no session
# check ever reaches -- precisely the silence the allowlist comment above warns about.
$script:LamGateMutatingVerbs = @('approve','reapprove','revoke','settle')

# THE HARNESS SESSION MARKERS, DERIVED FROM SOURCES AND FROM A LIVE SESSION, NOT GUESSED.
# CLAUDECODE / CLAUDE_CODE_SESSION_ID / CLAUDE_CODE_ENTRYPOINT were read out of the environment of
# a child process the harness actually spawned. CLAUDE_PROJECT_DIR is handled separately, under the
# hook condition, because that is where it belongs: the installed hook commands in
# .claude/settings.json are written in terms of it and the guard library reads it as the hook-side
# repo root (tools/framework/hooks/lib/evidence-common.ps1:37-38), while an ordinary agent-spawned
# shell does not carry it -- measured absent.
$script:LamHarnessSessionVars = @('CLAUDECODE','CLAUDE_CODE_SESSION_ID','CLAUDE_CODE_ENTRYPOINT')

function Test-LamHookAncestry {
    <#
      IS THIS PROCESS, OR AN ANCESTOR OF IT, A HOOK SCRIPT?

      A `.ps1` sitting DIRECTLY inside a `hooks` directory, which is the shape every installed entry
      point has (tools/evidence-hooks-next/hooks/evidence-guard-pretooluse.ps1 and its siblings).
      Narrowed to a direct child on purpose: `hooks/lib/evidence-common.ps1` is a library, not an
      entry point, and matching it would refuse an operator whose shell merely dot-sourced one.

      THE CURRENT PROCESS IS SCANNED TOO, NOT ONLY ITS ANCESTORS. A hook that invoked this tool with
      the call operator would run it IN ITS OWN PROCESS -- no child is created, so an ancestors-only
      walk would see nothing at all.

      FAILS OPEN ONLY INTO THE OTHER THREE CONDITIONS, NEVER INTO AN ALLOW. If the CIM query is
      unavailable this returns no reason, and the harness, dispatch and interactivity conditions are
      untouched -- they are what actually catch every case this build has driven.
    #>
    $hookPattern = '(?i)[\\/]hooks[\\/][^\\/]+\.ps1'
    try {
        $procId = $PID
        for ($depth = 0; $depth -lt 6; $depth++) {
            if (-not $procId -or $procId -le 0) { break }
            $proc = Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = " + $procId) -ErrorAction Stop
            if (-not $proc) { break }
            $cmdLine = [string]$proc.CommandLine
            if ($cmdLine -and ($cmdLine -match $hookPattern)) {
                return ("a " + $(if ($depth -eq 0) { 'process' } else { 'parent process' }) +
                        " in this invocation's chain is a hook entry point: " + $proc.Name +
                        " (pid " + $procId + ")")
            }
            $procId = [int]$proc.ParentProcessId
        }
    } catch {
        return $null
    }
    return $null
}

function Get-LamNonOperatorConditions {
    <#
      EVERY CONDITION THAT FIRED, NOT THE FIRST ONE. Returning on the first match would make the
      refusal text depend on evaluation order, and the instrument has to be able to drive each
      condition SEPARATELY and read its own name back out of the message.
    #>
    $found = New-Object System.Collections.Generic.List[string]

    # (i) THE RUNNER'S DISPATCHED-WORKER MARKER.
    if ($env:LAM_DISPATCH) {
        [void]$found.Add("LAM_DISPATCH -- this process carries the runner's dispatched-worker marker (LAM_DISPATCH='$env:LAM_DISPATCH'). A dispatched worker is an agent by construction.")
    }

    # (ii) THE HARNESS'S SESSION ENVIRONMENT.
    $harnessHits = @()
    foreach ($varName in $script:LamHarnessSessionVars) {
        $varValue = [Environment]::GetEnvironmentVariable($varName)
        if ($varValue) { $harnessHits += $varName }
    }
    if ($harnessHits.Count -gt 0) {
        [void]$found.Add("HARNESS-SESSION -- the agent harness's session environment is present in this process (" + ($harnessHits -join ', ') + "). Every process the harness spawns inherits these, so a gate minted here would be minted by the session, not by a person.")
    }

    # (iii) THE SESSION IS NOT INTERACTIVE.
    $interactiveNotes = @()
    if (-not [Environment]::UserInteractive) {
        $interactiveNotes += '[Environment]::UserInteractive is False'
    }
    $inputRedirected = $true
    try { $inputRedirected = [Console]::IsInputRedirected } catch { $inputRedirected = $true }
    if ($inputRedirected) { $interactiveNotes += '[Console]::IsInputRedirected is True (stdin is a pipe or a file, not a console)' }
    $consoleInputUsable = $true
    try { $null = [Console]::KeyAvailable } catch { $consoleInputUsable = $false }
    if (-not $consoleInputUsable) { $interactiveNotes += '[Console]::KeyAvailable throws (there is no console input buffer)' }
    if ($interactiveNotes.Count -gt 0) {
        [void]$found.Add("NOT-INTERACTIVE -- no operator is at this console: " + ($interactiveNotes -join '; ') + ". A gate is a human touchpoint, so a session nobody is sitting at cannot make one.")
    }

    # (iv) INVOKED FROM A HOOK.
    $hookNotes = @()
    if ($env:CLAUDE_PROJECT_DIR) {
        $hookNotes += "CLAUDE_PROJECT_DIR is set ('$env:CLAUDE_PROJECT_DIR') -- the harness defines it for hook commands and the guard library reads it as the hook-side repo root"
    }
    $ancestry = Test-LamHookAncestry
    if ($ancestry) { $hookNotes += $ancestry }
    if ($hookNotes.Count -gt 0) {
        [void]$found.Add("HOOK-INVOCATION -- this looks like a hook's invocation: " + ($hookNotes -join '; ') + ". A hook runs on the harness's behalf, so it is not the human either. STATED BOUND: CLAUDE_PROJECT_DIR is also set by tools/lam/mission-dispatch.ps1 for a dispatched worker, so this condition is a SUPERSET of 'from a hook' -- which refuses more, never less.")
    }

    $result = $found.ToArray()
    return , $result
}

# =================================================================================================
# -ComposedAt IS VALIDATED BEFORE ANYTHING READS IT (a review finding).
# =================================================================================================
# It was only ever EQUALITY-checked -- the token's copy against this invocation's -- and then written
# verbatim into revoked_at, or handed to ParseExact for created_at. So a value carrying a newline
# split the revocation's YAML mapping on revoke (the one verb that does not parse it), and made
# approve die in the trap with exit 9; and a value hours or years away from now was accepted as the
# instant an authorization was created, which moves expires_at with it.
#
# THE RULE, FOR EVERY VERB WHENEVER IT IS SUPPLIED: the exact form yyyy-MM-ddTHH:mm:ss.fffZ, anchored
# at both ends with \A and \z (a bare $ in .NET also matches BEFORE a final newline, which is the very
# character this exists to refuse), ASCII digits only ([0-9], because \d matches every Unicode
# digit), and then ParseExact with the invariant culture as a UTC instant, so an impossible date such
# as month 13 is refused too. FOR approve, reapprove AND revoke, in compose AND in mint: the instant
# must lie within 10 minutes of the current UTC time in either direction. A refusal is exit 2 with a
# named reason, and it happens here -- before the verified-path gate, before any directory is created
# and before any byte is written -- so it writes nothing whichever mode it arrives in.
$script:LamComposedAtWindowMinutes = 10
if ($PSBoundParameters.ContainsKey('ComposedAt')) {
    $composedAtShown = (@($ComposedAt.ToCharArray() | Select-Object -First 64 | ForEach-Object {
        $cc = [int][char]$_
        if ($cc -ge 0x20 -and $cc -le 0x7E -and $cc -ne 0x3C) { [string]$_ } elseif ($cc -le 0xFF) { '<0x{0:X2}>' -f $cc } else { '<U+{0:X4}>' -f $cc }
    }) -join '')
    $composedAtParsed = $null
    if ([regex]::IsMatch($ComposedAt, '\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z\z')) {
        try {
            $composedAtParsed = [datetime]::ParseExact($ComposedAt, 'yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture,
                ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        } catch { $composedAtParsed = $null }
    }
    if ($null -eq $composedAtParsed) {
        Write-Output "mission-gate: REFUSED -- -ComposedAt is not a UTC timestamp of the exact form yyyy-MM-ddTHH:mm:ss.fffZ."
        Write-Output "  CONDITION THAT FIRED:"
        Write-Output "    - COMPOSED-AT-MALFORMED -- received $($ComposedAt.Length) character(s): '$composedAtShown' (every byte outside printable ASCII shown as <0xNN>)."
        Write-Output "  The value is written into created_at / expires_at / revoked_at, so it must be exactly 24 characters"
        Write-Output "  with no whitespace and no control character. NOTHING WAS WRITTEN."
        exit 2
    }
    # (Spelled through a variable, not as `if ($script:LamGateMutatingVerbs -contains $Command)`, so the
    # admission block below stays the ONE place that spelling opens -- WP-4's T-25 revert cuts that
    # block by matching it, and a second occurrence here would make the cut start in the wrong block.)
    $composedAtIsMutating = ($script:LamGateMutatingVerbs -contains $Command)
    if ($composedAtIsMutating) {
        $composedAtNow = (Get-Date).ToUniversalTime()
        $composedAtSkew = [Math]::Abs(($composedAtNow - $composedAtParsed).TotalMinutes)
        if ($composedAtSkew -gt $script:LamComposedAtWindowMinutes) {
            Write-Output "mission-gate: REFUSED -- -ComposedAt lies more than $($script:LamComposedAtWindowMinutes) minutes from the current UTC time."
            Write-Output "  CONDITION THAT FIRED:"
            Write-Output ("    - COMPOSED-AT-OUT-OF-WINDOW -- -ComposedAt {0}, now {1}, {2:N1} minutes apart (limit {3} in either direction)." -f `
                $ComposedAt, $composedAtNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture), $composedAtSkew, $script:LamComposedAtWindowMinutes)
            Write-Output "  An authorization's created_at is the instant it was composed; a value far from now would back- or"
            Write-Output "  forward-date the gate and move its expiry with it. Re-run the console. NOTHING WAS WRITTEN."
            exit 2
        }
    }
}

if ($script:LamGateMutatingVerbs -contains $Command) {
    # THE ADMISSION RULE (as ruled on a review finding): a gate-mutating verb is
    # admitted IF AND ONLY IF none of the four session conditions fires AND the console's verified
    # path holds. BOTH, ALWAYS. Every condition that fires is reported, so an operator sees every
    # reason at once. -ComposeOnly is the one exception -- it authorizes nothing, so it needs no token
    # and does not run the four session conditions.
    #
    # WHY NEITHER HALF ADMITS ALONE. The four conditions without the token were defeated by a scrubbed
    # console (WP-4's T-25 residual). The token without the conditions -- an earlier draft --
    # let a console dot-sourced INSIDE an agent session, with its provider replaced, mint there: a
    # shape the base tool refused, so the draft weakened the tool. The console runs in the operator's
    # own terminal, where the conditions do not fire; requiring both costs that operator nothing.
    if (-not $ComposeOnly) {
        $consoleCheck = Test-LamConsoleTokenBasics -Verb $Command -K $Kind -I $Id -At $ComposedAt -Token $ConsoleToken -Credential $ConsoleCredential
        $nonOperator = Get-LamNonOperatorConditions
        $nonOperator = @($nonOperator)
        $fired = @()
        if (-not $consoleCheck.ok) { $fired += "CONSOLE-VERIFIED-PATH -- $($consoleCheck.reason)" }
        $fired += $nonOperator
        if ($fired.Count -gt 0) {
            # A VALID TOKEN PRESENTED TO A REFUSED ACT IS SPENT. Single use means one presentation, not
            # one success: otherwise the same in-process token could be retried after the refusing
            # condition was cleared from this process's environment.
            if ($consoleCheck.ok) {
                $spendReg = [AppDomain]::CurrentDomain.GetData($script:LamConsoleTokenRegistryKey)
                if (($spendReg -is [hashtable]) -and $spendReg.ContainsKey($ConsoleToken)) { $spendReg[$ConsoleToken].used = $true }
            }
            Write-Output "mission-gate: REFUSED -- '$Command' is a GATE-MUTATING verb, admitted only through the console's verified path AND only where no session condition fires."
            Write-Output "  A gate artifact IS the human touchpoint (design v2.3 SS10.5 / ADR-033, LAM-ACCEPT T-3)."
            Write-Output "  It is minted ONLY through lam-console.ps1 -- which previews the exact bytes and collects a"
            Write-Output "  SECURE-DESKTOP credential before it mints the in-process token this tool requires -- run in an"
            Write-Output "  operator's own terminal, where none of this tool's four session conditions fires. Both are"
            Write-Output "  required; neither admits on its own. (This banner names no condition tag: only the list below does.)"
            Write-Output "  NOTHING WAS WRITTEN: no gates directory was created, no artifact minted, renamed or appended."
            Write-Output "  CONDITIONS THAT FIRED ($($fired.Count)):"
            foreach ($condition in $fired) { Write-Output "    - $condition" }
            if ($consoleCheck.ok) {
                Write-Output "  The console token itself was VALID and has now been SPENT: the refusal above is the session's, not the token's."
            }
            Write-Output "  'list' is unaffected and so is '-?'. To mint, re-mint or revoke, run tools\lam\lam-console.ps1"
            Write-Output "  yourself from your own terminal. There is no override flag, environment variable or file that"
            Write-Output "  selects a bypass: the token lives only in process memory after a credential succeeds."
            Write-Output "  SECOND LAYER, UNCHANGED: Test-EvidenceGateToolMutation in the evidence guard"
            Write-Output "  denies a harness-side command that invokes this tool with any verb but 'list'."
            exit 3
        }
    }
}

# THE CONSOLE-CREDENTIAL LABEL IS VALIDATED AND DEFAULTED. It is written onto the
# artifact and is part of the composed bytes, so it must be one of the known providers or refused.
if ($ConsoleCredential -and ($script:LamConsoleCredentialSet -notcontains $ConsoleCredential)) {
    Write-Output "mission-gate: REFUSED -- -ConsoleCredential '$ConsoleCredential' is not a known provider ($($script:LamConsoleCredentialSet -join ', '))."
    exit 2
}
$script:LamCredentialLabel = if ($ConsoleCredential) { $ConsoleCredential } else { 'secure-desktop-credui' }
# THE COMPOSED-AT VALUE that every Get-Date in the composed bytes is pinned to. When the console
# supplies one, use it verbatim; otherwise the live UTC time, which is what a direct compose sees.
$script:LamComposedAtStr = if ($ComposedAt) { $ComposedAt } else { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture) }

switch ($Command) {

    'list' {
        if (-not (Test-Path -LiteralPath $gatesDir)) {
            Write-Output "mission-gate: no gates directory at $gatesDir"
            exit 0
        }
        $any = $false
        foreach ($f in @(Get-ChildItem -LiteralPath $gatesDir -File -Filter '*.yaml' -ErrorAction SilentlyContinue)) {
            $any = $true
            $t = [System.IO.File]::ReadAllText($f.FullName)
            # open / REVOKED / CONSUMED comes from the ONE shared predicate. It used to live here
            # AND in mission-goal-check's gate_present detector, and the two copies disagreed: this
            # one carried the load-bearing (?!null), that one did not, so that one reported every
            # fresh gate as consumed and could never pass. One definition, every consumer.
            $state = (Get-LamGateState -Path $f.FullName).state
            # UI-1 S1 (ADR-045): AN OPEN GATE PAST ITS expires_at HAS EXPIRED, and `list` is the verb that
            # observes it -- no code ever writes an expiry; expires_at binds the pre-push decider at read time.
            # gate_expired is said once per gate (the emitter keeps a marker), however often `list` runs. The
            # listed state is unchanged: this tool's states are the shared predicate's, and expiry is not one.
            if ($state -eq 'open') {
                $expRead = Get-LamGateScalarField -Text $t -Field 'expires_at'
                $expAt = [DateTime]::MinValue
                if ($expRead.ok -and $expRead.value -and [DateTime]::TryParse([string]$expRead.value, [System.Globalization.CultureInfo]::InvariantCulture,
                        ([System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal), [ref]$expAt) -and
                        ($expAt -lt [DateTime]::UtcNow)) {
                    Send-LamGateTelemetry -Kind 'gate_expired' -GatePath $f.FullName
                }
            }
            # ONE SCALAR READER, AND IT COUNTS (round 3, a review finding). This line was one of FOUR
            # copies of a first-match regex that never asked how many keys there were, so a gate
            # declaring TWO `authorized_tip_sha` values listed the first and said nothing about the
            # second. `list` is the operator's window onto the gates directory: printing one of two
            # authorized shas as though it were THE authorized sha is the worst place for this to be
            # silent. It refuses nothing -- listing is a read -- and prints the ambiguity instead.
            $tipRead = Get-LamGateScalarField -Text $t -Field 'authorized_tip_sha'
            $tip = if (-not $tipRead.ok) { "AMBIGUOUS(x$($tipRead.count))" } elseif ($tipRead.value) { [string]$tipRead.value } else { '-' }
            # Class is DERIVED at read time (ruling ZP), so gates written before the field existed
            # list correctly without anybody editing an audit artifact after the fact.
            $cls = (Get-LamGateClassForArtifact -Path $f.FullName).class
            Write-Output ("{0,-34} {1,-9} {2,-20} tip={3}" -f $f.BaseName, $state, $cls, $tip)
        }
        if (-not $any) { Write-Output "mission-gate: no gate artifacts in $gatesDir" }
        exit 0
    }

    'revoke' {
        if (-not $Kind -or -not $Id) { Write-Output 'mission-gate: revoke needs -Kind and -Id'; exit 2 }
        $p = Get-GatePath -K $Kind -I $Id
        if (-not (Test-Path -LiteralPath $p)) { Write-Output "mission-gate: no gate at $p"; exit 2 }
        $t = [System.IO.File]::ReadAllText($p)
        # THE ARTIFACT IS THE AUTHORITY ON ITS OWN KIND, AND REVOKE ADDRESSES BY FILENAME.
        # `revoke -Kind dispatch -Id X` opened whatever sat at `dispatch-X.yaml` and revoked it. If
        # that file declares `kind: push`, the operator has just revoked a PUSH authorization while
        # the tool reports "revoked dispatch-X" -- they believe one capability is withdrawn and a
        # different one actually is. Both halves are wrong: the gate they meant to close stays open,
        # and the record says something that did not happen.
        #
        # `approve` cannot hit this (it WRITES the kind and refuses to overwrite an existing gate),
        # which is why enumerating the class mattered rather than fixing "gates" in general: this
        # sub-command is the only member here, and it is the destructive one.
        $declared = (Get-LamGateClassForArtifact -Path $p).kind
        # THE ONE CASE RULE (an operator ruling): BOTH sides through the shared reader, ORDINALLY,
        # and either failing to resolve is itself a refusal. `-ne` FOLDED, so `revoke -Kind PUSH`
        # against a `kind: push` artifact -- and the reverse -- passed a check whose entire job is
        # that the ARTIFACT is the authority on its own kind. The `$declared -and` guard is kept
        # rather than tidied: an artifact with NO kind takes the different, better refusal below.
        $declaredCanon = Resolve-LamGateKind -Kind $declared
        $kindCanon = Resolve-LamGateKind -Kind $Kind
        if ($declared -and ((-not $declaredCanon) -or (-not $kindCanon) -or ($declaredCanon -cne $kindCanon))) {
            # TWO PLAIN STATEMENTS, NOT AN if-EXPRESSION SPANNING LINES. PS 5.1 parses `}` newline
            # `elseif` correctly, but this file is edited by hand under time pressure and a broken
            # continuation has already cost this build a round; nothing here needs the cleverness.
            $caseNote = ''
            if (-not $declaredCanon) { $caseNote = ' ' + (Get-LamGateKindRefusalReason -Kind $declared) + '.' }
            if (($caseNote -ceq '') -and (-not $kindCanon)) { $caseNote = ' ' + (Get-LamGateKindRefusalReason -Kind $Kind) + '.' }
            Write-Output "mission-gate: REFUSED -- the artifact at $p declares 'kind: $declared', not '$Kind'.$caseNote A file NAMED for a kind is not a gate of that kind, and revoking it under the wrong name would withdraw a capability you did not mean to touch while recording one you did. Revoke it as '$declared', or fix the filename."
            exit 2
        }
        if (-not $declared) {
            Write-Output "mission-gate: REFUSED -- the artifact at $p declares no kind at all, so there is nothing to check '$Kind' against. A gate whose own face does not say what it is cannot be revoked by name."
            exit 2
        }
        # THE SHARED PREDICATE, NOT A THIRD COPY OF IT. This line restated revocation as
        # `^revoked_at:\s*\S` -- WITHOUT the `(?!null)` that `Get-LamGateState` carries and that
        # `list` two blocks above already relies on. A gate carrying the literal `revoked_at: null`
        # -- which every hand-written gate does, because LAM-INSTALL's snippets and the runner's own
        # supersession lookup both treat that as the normal UNREVOKED state -- read as ALREADY
        # REVOKED here. Revoke then reported success and exited 0 having changed nothing.
        #
        # That is the operator's only withdrawal mechanism silently failing, and for a `supersession`
        # gate it is the ONLY one there is: the runner deliberately does not consult expiry, so a
        # ratification that cannot be revoked cannot be taken back at all.
        #
        # THIRD INSTANCE OF ONE DEFECT. `consumed_at` had exactly this shape twice -- once in
        # `gate_present`, once here -- and both times the fix was to stop restating the predicate.
        # Caught by the CONTROL row of a member written for a different fix, which is the only
        # reason it was found: the refusal half passed, and a member without its control would have
        # reported green.
        if ((Get-LamGateState -Path $p).revoked) { Write-Output "mission-gate: $Kind-$Id is already revoked"; exit 0 }
        # Revocation APPENDS. The record of what was authorized is never rewritten away -- a gate
        # is an audit artifact first and a permission second. -Reason joins the appended block
        # and does not disturb one byte above it.
        $resultText = $t.TrimEnd() + "`n" + (Get-RevocationStamp -Why $Reason -At $script:LamComposedAtStr)
        $resultBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($resultText)
        # COMPOSE-OR-TOKEN CHECKPOINT. The one planned write is the whole resulting
        # file. Under -ComposeOnly this emits the preview and exits 0; otherwise it validates the
        # console token's act digest against these exact bytes and marks it used before the write.
        $revokeWrites = @([pscustomobject]@{ name = "$Kind-$Id.yaml"; bytes = $resultBytes })
        $revokeDigest = Get-LamActDigest -Writes $revokeWrites
        Invoke-LamGateComposeOrRefuse -Verb $Command -Writes $revokeWrites -BindsPath '' -BindsSha '' -ActDigest $revokeDigest
        [System.IO.File]::WriteAllBytes($p, $resultBytes)
        # UI-1 S1 (ADR-045): a revocation can move the derived state (a revoked halt-ruling reopens its HALT), so
        # revoke offers the snapshot -- one snapshot line when snapshot_sha256 moved, none when it did not.
        Send-LamGateTelemetry -Snapshot
        Write-Output "mission-gate: revoked $Kind-$Id"
        if ($Reason) {
            Write-Output "  reason   : $Reason"
        } else {
            Write-Output "  reason   : $script:LamNoReasonText"
            Write-Output "  NOTE: -Reason is optional and its absence is now RECORDED on the artifact rather than left blank."
        }
        Write-Output "  NOTE: revoke does not rename the file. To re-mint over this id in one act, use 'reapprove'."
        exit 0
    }


    # =============================================================================================
    # SETTLE -- THE ACTOR THAT PERFORMS A GATED ACT STAMPS ITS GATE
    # (operator ruling (i)). THE FOURTH MUTATING VERB.
    # =============================================================================================
    # THE DEFECT IT ANSWERS. A push gate is stamped by the session that PERFORMS the push, and a
    # TERMINAL push has no such session. One arc's close gate was read four times across the arc's
    # close -- by a hook-bearing session that was present and active throughout the window -- and read
    # `consumed_at: null` every time, with no consume block ever written. At S0 the stamp arrived
    # inside the window and was read "early, not wrong". Here it is STRUCTURALLY ABSENT: there was
    # no actor left to write it.
    #
    # WHY THE CONSOLE. The ruling's answer is that the actor which performs a gated act stamps its
    # gate, and the operator's console is the operator's stamping instrument. So settle is a CONSOLE
    # ACT and takes the console's whole verified path -- compose, the byte-exact preview, the
    # operator's confirmation, the in-process token, and one attestation line -- exactly as approve
    # does. It is in $script:LamGateMutatingVerbs, so the four session conditions refuse it from an
    # agent session, a hook or a dispatched worker, and -ComposedAt is validated for it.
    #
    # WHAT IT IS NOT: AN AUTHORIZATION. A settle asserts nothing about whether an act was permitted.
    # It records that the use of what this gate authorized was OBSERVED -- for a push gate, the
    # DECLARED origin holding the authorized sha; for an amendment-material or reclose gate, the
    # commit that used it. The authorization was the mint; this is the record of its use, and the
    # two are deliberately different acts by different instruments at different times.
    'settle' {
        if (-not $Kind -or -not $Id) { Write-Output 'mission-gate: settle needs -Kind and -Id'; exit 2 }
        # THREE KINDS, WHICH IS THE RULINGS' SCOPE AND NOT A SIMPLIFICATION (BATCH-6
        # WP-P (b)). Settling means observing a use: a DECLARED
        # origin holding an authorized sha at a declared ref for `push`, which alone carries that
        # triple; the commit holding the bound amendment for `amendment-material`; the re-closure
        # commit for `reclose`. Every other kind is refused: ruling (i) routes dispatch gates to the
        # runner at spawn (candidate C5); a halt-ruling's null consumed_at is its designed state
        # (standing 68); completion-acceptance and supersession are recorded rulings, not spent; and a
        # verb that silently accepted another kind would have to invent what settling it means.
        # THE ONE CASE RULE (an operator ruling). `-ne` FOLDS, so `settle -Kind PUSH` passed this
        # scope test and reached the settle body under a spelling no canonical kind carries. The
        # kind text is resolved to the map's canonical key ORDINALLY and THAT is compared, so $Kind is
        # exactly 'push', 'amendment-material' or 'reclose' everywhere below, including in
        # Get-GatePath's filename -- which stays true only while every test of the kind below is ordinal.
        $kindCanon = Resolve-LamGateKind -Kind $Kind
        if (($kindCanon -cne 'push') -and ($kindCanon -cne 'amendment-material') -and ($kindCanon -cne 'reclose')) {
            Write-Output "mission-gate: REFUSED -- settle is defined for -Kind push, amendment-material and reclose only, and this call names '$Kind'."
            if (-not $kindCanon) { Write-Output "  $(Get-LamGateKindRefusalReason -Kind $Kind)." }
            Write-Output "  Settling records an OBSERVED use: push observes the DECLARED origin holding authorized_tip_sha at"
            Write-Output "  remote_ref (amendment 20); amendment-material and reclose observe the commit that used them."
            Write-Output "  Operator ruling (i) routes dispatch gates to the runner at spawn; halt-ruling, completion-acceptance,"
            Write-Output "  supersession and witness-attested are not settled here. NOTHING WAS WRITTEN."
            exit 2
        }
        $p = Get-GatePath -K $Kind -I $Id
        if (-not (Test-Path -LiteralPath $p)) { Write-Output "mission-gate: no gate at $p"; exit 2 }
        $t = [System.IO.File]::ReadAllText($p)

        # THE ARTIFACT IS THE AUTHORITY ON ITS OWN KIND. Revoke carries this refusal and records why:
        # a file NAMED for a kind is not a gate of that kind, and addressing one by filename lets an
        # operator act on a capability they did not mean to touch while the record says otherwise.
        # Settle is the other destructive-by-record verb -- it spends an authorization permanently --
        # so it takes the same refusal rather than restating the lesson.
        $declared = (Get-LamGateClassForArtifact -Path $p).kind
        if (-not $declared) {
            Write-Output "mission-gate: REFUSED -- the artifact at $p declares no kind at all, so there is nothing to check '$Kind' against. A gate whose own face does not say what it is cannot be settled by name."
            exit 2
        }
        # THE ONE CASE RULE (an operator ruling). `-ne` FOLDED, so an artifact whose face reads
        # `kind: PUSH` was settled by `-Kind push` and took a FULL 497-byte consume block, byte for
        # byte the size of the canonical row. $kindCanon was resolved by the scope test above and is one
        # of its three kinds; the artifact's own text is resolved here, and a kind that resolves to nothing is
        # refused naming the case -- the sentence lam-gate-class.ps1 composes for every consumer.
        $declaredCanon = Resolve-LamGateKind -Kind $declared
        if (-not $declaredCanon) {
            Write-Output "mission-gate: REFUSED -- the artifact at $p declares 'kind: $declared', which is not a gate kind: $(Get-LamGateKindRefusalReason -Kind $declared). Settling it would stamp a publication onto an artifact whose own face names nothing this tool can classify."
            exit 2
        }
        if ($declaredCanon -cne $kindCanon) {
            Write-Output "mission-gate: REFUSED -- the artifact at $p declares 'kind: $declared', not '$Kind'. Settling it under the wrong name would record a publication against an artifact that authorizes something else."
            exit 2
        }

        # THE SHARED STATE PREDICATE, NOT A FIFTH COPY OF IT. `(?!null)` is load-bearing: every gate
        # this tool mints carries the literal `consumed_at: null`, and a naive `consumed_at:\s*\S`
        # reads a FRESH gate as consumed. That predicate has been restated and got wrong FOUR times in
        # this repository -- in gate_present, in revoke, in the decider's gate scan, and once more --
        # and every cure was to stop restating it. Get-LamGateState is the one definition.
        $gstate = Get-LamGateState -Path $p

        # FIRST STAMP WINS (ruling (i)). The in-session PostToolUse settle stays, and whichever lands
        # first is the record; the second refuses rather than appending a second consume block. An
        # audit artifact carrying two consumed_at values has traded a missing record for an ambiguous
        # one, which is strictly worse.
        # THE GUARD IS ON THE GATE, NOT ON ONE FIELD (round 3, a review finding, driven at zero mutation).
        # It tested `$gstate.consumed` -- which is `consumed_at` and nothing else -- while a settle
        # appends FIVE fields. A gate carrying the four appended ones with `consumed_at` still reading
        # the literal sentinel `null` passed this guard, and `settle -ComposeOnly` composed a SECOND
        # consume block under ONE `consumed_at`: counts of 1 and 2-2-2-2, which is verbatim the
        # "missing record traded for an ambiguous one" the text below names.
        #
        # WHERE SUCH A GATE COMES FROM, SINCE NEITHER WRITER PRODUCES IT. In both writers `consumed_at`
        # is fixed BEFORE the other four are appended, and the mint writes `consumed_at: null` as the
        # artifact's LAST line -- so the precondition is not reachable through this tool. It IS reachable
        # otherwise: `.mission/gates` is in no protected-path list, and the admission's own refusal text
        # instructs an operator to hand-ANNOTATE a gate artifact AT COLUMN 0 (by ruling). An
        # interrupted hook-side settle leaves the same shape from the other direction.
        #
        # AND THE OPERATOR IS TOLD WHICH FIELDS ARE THERE. "Already consumed" said to someone holding a
        # gate whose `consumed_at` reads `null` sends them looking for a stamp that is not there; the two
        # wordings below are one refusal with two honest faces, and the first-stamp-wins sentence that
        # T-32 and the ruling both name is kept VERBATIM for the gate that really is consumed.
        if ($gstate.consume_block_any) {
            if ($gstate.consumed) {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id is ALREADY CONSUMED, and first stamp wins (operator ruling (i))."
            } else {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id ALREADY CARRIES PART OF A CONSUME BLOCK, and first stamp wins (operator ruling (i)) binds the GATE, not one field."
                Write-Output "  Its consumed_at still reads the literal null, so this gate is NOT 'already consumed' and this refusal"
                Write-Output "  does not say that it is. Something appended part of a consume block to it without stamping consumed_at."
            }
            Write-Output "  consume-block fields already present: $($gstate.consume_block_joined)"
            Write-Output "  A gate records ONE use. The in-session PostToolUse settle and this verb both stamp, and whichever"
            Write-Output "  reached the artifact first is the record; a second stamp would append a second consume block to"
            Write-Output "  an audit artifact and make it ambiguous. NOTHING WAS WRITTEN."
            exit 2
        }
        if ($gstate.revoked) {
            Write-Output "mission-gate: REFUSED -- $Kind-$Id is REVOKED, so it authorizes nothing and there is no authorization to record the use of."
            Write-Output "  NOTHING WAS WRITTEN."
            exit 2
        }
        # TWO THINGS DELIBERATELY NOT TESTED HERE, NAMED SO NEITHER LOOKS LIKE AN OVERSIGHT:
        #   expires_at          -- ruling (i) is explicit: "expires_at binds the pre-push decider
        #                          (authorization), not the settle (record of use)". An expired gate
        #                          settles, and the ruling's own named FIRST EXERCISE is exactly such
        #                          a gate. Refusing here would make the record of a publication
        #                          depend on how long the operator took to write it down.
        #   witness_expired_at  -- the decider's DISQUALIFICATION, meaning it could not confirm a
        #                          publication before its witness aged out. This verb confirms by
        #                          asking origin directly, so it answers the very question that was
        #                          unknown. The ruling's condition list is CLOSED at three, and adding
        #                          a fourth refusal is not this tool's to invent; it is recorded as a
        #                          question for the operator rather than taken.

        # THE PUSH BRANCH IS TODAY'S BODY, MOVED UNDER ITS OWN TEST AND OTHERWISE UNTOUCHED (BATCH-6
        # WP-P (b)). Every line below down to its closing brace is the push settle as it stood
        # in the base, indented once more; WP-4 T-58 runs that base -- the installed synthetic base base-700e19e5-s04,
        # pinned by sha256 -- in a twin fixture over the same minted gate with the same -ComposedAt and requires the same
        # bytes, digest and stdout.
        if ($kindCanon -ceq 'push') {
            # THE DECLARED TRIPLE, READ FROM THE ARTIFACT AND FROM NOWHERE ELSE.
            # ONE SCALAR READER, AND IT COUNTS (round 3, a review finding). Driven at the old tip: a gate
            # carrying TWO column-0 `authorized_tip_sha` keys composed a FULL consume block off the
            # first when the origin's own sha was written first, and refused IN THE OTHER KEY ORDER for
            # a reason with nothing to do with the ambiguity -- "the DECLARED origin does not hold this
            # gate's authorized sha". One artifact, two orders, two different wrong answers, and an
            # operator reading the second refusal would go and look at origin.
            #
            # IT REFUSES HERE, ABOVE THE ORIGIN OBSERVATION, SO BOTH ORDERS GET THE SAME REASON. A
            # settle stamps a publication against ONE authorized sha; an artifact declaring two does not
            # say which, and this reader does not pick one.
            $tipRead = Get-LamGateScalarField -Text $t -Field 'authorized_tip_sha'
            if (-not $tipRead.ok) {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id is AMBIGUOUS on its own face: $($tipRead.reason)."
                Write-Output "  Settling records that the DECLARED origin was observed holding THE authorized sha. An artifact"
                Write-Output "  naming two does not say which one that is, and stamping the first would write a publication"
                Write-Output "  record against a value chosen by key order. NOTHING WAS WRITTEN."
                exit 2
            }
            $gateTip = [string]$tipRead.value
            $gateUrl = if ($t -match '(?m)^origin_url:[ \t]*(\S+)')         { $Matches[1] } else { '' }
            $gateRef = if ($t -match '(?m)^remote_ref:[ \t]*(\S+)')         { $Matches[1] } else { '' }
            if ((-not $gateTip) -or (-not $gateUrl) -or (-not $gateRef)) {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id does not declare the full triple (authorized_tip_sha / origin_url / remote_ref), so there is no origin to ask and no sha to ask about."
                Write-Output "  A gate predating amendment 20 cannot be settled: the observation this verb records is defined"
                Write-Output "  against a DECLARED origin, and falling back to remote.origin.url is exactly what amendment 20"
                Write-Output "  forbids. NOTHING WAS WRITTEN."
                exit 2
            }

            # OBSERVE THE DECLARED ORIGIN. Never the remote NAME `origin`, never remote.origin.url: round
            # 12 repointed remote.origin.url at a decoy and made a detector report PASS while the real
            # origin held an unauthorized commit, and the gate's declared triple is the compensating
            # control for a surface that cannot be guarded.
            #
            # $LASTEXITCODE IS CHECKED. Both this file and lam-verify-admission.ps1 carry recorded
            # fail-open bugs from omitting exactly this -- a failing git produced no output, the result
            # read EMPTY, and the check reported success. $ErrorActionPreference is saved and restored
            # around the call: under 'Stop' a native exe writing to stderr is a fatal NativeCommandError,
            # `2>$null` does not help, and an unreachable origin writes to stderr by definition.
            $lsOut = ''
            $lsCode = -1
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $lsOut = & git -C $MissionRoot ls-remote $gateUrl $gateRef 2>&1
                $lsCode = $LASTEXITCODE
            } finally { $ErrorActionPreference = $prevEap }

            # AN ORIGIN THAT CANNOT BE ASKED REFUSES, AND THAT IS THE OPPOSITE OF THE MINT'S CHOICE, ON
            # PURPOSE. The mint RECORDS what it saw and mints anyway, because a human is authorizing an
            # act and the observation is evidence about the world. A settle ASSERTS a publication was
            # observed -- so an origin nobody could ask cannot produce that assertion. Writing
            # consumed_basis over an unreachable origin would be a positive claim, in an audit artifact,
            # about a publication nobody witnessed.
            if ($lsCode -ne 0) {
                Write-Output "mission-gate: REFUSED -- the DECLARED origin could not be asked what it holds (git ls-remote exited $lsCode)."
                Write-Output "  url : $gateUrl"
                Write-Output "  ref : $gateRef"
                Write-Output "  A settle asserts that origin was OBSERVED holding the authorized sha. An origin that could not"
                Write-Output "  be reached supports no such assertion, so this refuses rather than recording one. NOTHING WAS"
                Write-Output "  WRITTEN, and the gate remains exactly as it was."
                exit 2
            }
            # EXACT REF MATCH, ORDINAL. ls-remote takes a PATTERN, not a name, and git refs are
            # case-sensitive identifiers while PowerShell's default comparison is not -- so a ref
            # differing only in case is a DIFFERENT ref and must not satisfy this.
            $observed = ''
            foreach ($lsLine in @($lsOut)) {
                $lsMatch = [regex]::Match(("$lsLine"), '\A([0-9a-fA-F]{40})\s+(\S+)\s*\z')
                if ($lsMatch.Success -and ($lsMatch.Groups[2].Value -ceq $gateRef)) {
                    $observed = $lsMatch.Groups[1].Value.ToLowerInvariant()
                    break
                }
            }
            if ($observed -cne $gateTip.ToLowerInvariant()) {
                Write-Output "mission-gate: REFUSED -- the DECLARED origin does not hold this gate's authorized sha, so there is no publication to record."
                Write-Output "  url        : $gateUrl"
                Write-Output "  ref        : $gateRef"
                Write-Output "  authorized : $gateTip"
                Write-Output "  observed   : $(if ($observed) { $observed } else { '(origin answered and carries no such ref)' })"
                Write-Output "  The authorization is NOT spent: it still authorizes exactly the publication it names, and can be"
                Write-Output "  settled once that publication has landed. NOTHING WAS WRITTEN."
                exit 2
            }

            # WHAT ORIGIN HELD AT MINT, OR THE RULING'S OWN LITERAL. Gates minted before origin_tip_at_mint
            # existed carry no such field, and ruling (i) words their case exactly: "earlier gates settle
            # with consumed_origin_before 'not observed at mint'."
            #
            # THIS IS A THIRD SPELLING OF "UNKNOWN" IN THIS FIELD AND THAT IS DELIBERATE, NOT DRIFT. The
            # PostToolUse settle writes `(none)` here, meaning the pre-push witness recorded no
            # remote_sha_before. This literal means the GATE carries no origin_tip_at_mint. They are
            # different facts about different artifacts and a reader must be able to tell them apart;
            # collapsing them into one word is the conflation this toolchain refuses everywhere else.
            # A gate whose origin_tip_at_mint is itself one of the mint's two recorded-absence literals is
            # carried through VERBATIM rather than re-spelled: the mint already said precisely what it saw,
            # and restating it here would lose which of the two it was.
            $before = if ($t -match '(?m)^origin_tip_at_mint:[ \t]*(.*?)[ \t]*\r?$') { $Matches[1] } else { 'not observed at mint' }
            if (-not $before) { $before = 'not observed at mint' }

            # THE STAMP IS $script:LamComposedAtStr, NOT A FRESH Get-Date, AND THIS IS LOAD-BEARING.
            # Compose and mint are two separate invocations of this tool and the act digest is computed
            # over both. A wall-clock timestamp differs between them, the digests disagree, and EVERY
            # settle would refuse with an act digest mismatch. Get-RevocationStamp solved this the same
            # way for revoke and its comment says so.
            $stamp = $script:LamComposedAtStr

            # THE SENTINEL IS REPLACED IN PLACE, NOT APPENDED BESIDE. Every minted gate carries
            # `consumed_at: null`; appending would leave TWO consumed_at keys in an audit artifact. The
            # replacement is bounded to [^\r\n] so a CRLF artifact keeps its CRLF -- `.*$` in .NET
            # multiline consumes the CR and would silently convert that one line to LF.
            $body = $t
            if ($body -match '(?m)^consumed_at:') {
                $body = [regex]::Replace($body, '(?m)^consumed_at:[^\r\n]*', "consumed_at: $stamp")
            } else {
                $body = $body.TrimEnd() + "`r`nconsumed_at: $stamp"
            }
            # CRLF THROUGHOUT THE APPENDED BLOCK, which is a deliberate one-character divergence from
            # Get-RevocationStamp and from the hook's settle: both append bare LF onto a body this tool
            # wrote as CRLF, leaving an UNTRACKED stamped gate with mixed endings (the tracked ones look
            # uniform only because git normalised them on commit). An audit artifact should not have two
            # kinds of line ending, and settle's own writes are the part this verb owns. The other two
            # sites are NOT changed here -- that is a separate cure on files this member does not own,
            # and it is disclosed rather than taken.
            $body = $body.TrimEnd() + "`r`nconsumed_origin_tip: $observed" +
                                      "`r`nconsumed_ref: $gateRef" +
                                      "`r`nconsumed_origin_before: $before" +
                                      "`r`nconsumed_basis: post-push witness by console: the DECLARED origin observed holding the authorized sha`r`n"
            $settleBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($body)

            # THE COMPOSE-OR-TOKEN CHECKPOINT, exactly as revoke uses it: under -ComposeOnly this emits
            # the preview and exits 0 without writing; otherwise it validates the console token's act
            # digest against these exact bytes and marks the token used BEFORE the write.
            $settleWrites = @([pscustomobject]@{ name = "$Kind-$Id.yaml"; bytes = $settleBytes })
            $settleDigest = Get-LamActDigest -Writes $settleWrites
            Invoke-LamGateComposeOrRefuse -Verb $Command -Writes $settleWrites -BindsPath '' -BindsSha '' -ActDigest $settleDigest
            [System.IO.File]::WriteAllBytes($p, $settleBytes)
            Send-LamGateTelemetry -Kind 'gate_consumed' -GatePath $p -Snapshot
            Write-Output "mission-gate: settled $Kind-$Id"
            Write-Output "  consumed_at            : $stamp"
            Write-Output "  consumed_origin_tip    : $observed"
            Write-Output "  consumed_ref           : $gateRef"
            Write-Output "  consumed_origin_before : $before"
            Write-Output "  NOTE: this records that the DECLARED origin was OBSERVED holding the authorized sha. It is a"
            Write-Output "  RECORD OF USE, not an authorization, and it says nothing about who performed the push."
            exit 0
        }

        # AMENDMENT-MATERIAL AND RECLOSE: THE COMMIT THAT USED THE GATE, OBSERVED (BATCH-6 WP-P (b);
        # the operator's rulings).
        # NO NEW PARAMETER: THE COMMIT IS OBSERVED, NOT PASSED. A settle parameter would have to enter WP-4's
        # launcher block, which WP-3's C-5a binds byte for byte (S4); and a record of use is an observation in
        # any case, as the push settle's is.
        #   amendment-material -- the newest commit on HEAD's history touching the gate's binds path whose bytes
        #       for it hash to binds_sha256: the bytes as checked out, or as stored. EITHER DIGEST COUNTS, for the
        #       reason the placement arm's ruling (1) of 2026-09-24 gives: this tool hashes the WORKING COPY at the
        #       mint, and a file written LF under core.autocrlf=true checks out as CR LF -- its checked-out bytes
        #       are then not the minted digest while its stored bytes are. Both are the committed content, and
        #       bytes other than the bound ones match neither. Refused when no commit holds them (the amendment
        #       not committed: the authorization is NOT spent) and when no holding commit descends from all the
        #       others (the log is read in --topo-order, so the first listed is that one wherever one exists).
        #   reclose -- the commit whose subject is mission-reclose.ps1's own (its :260) naming this gate's id,
        #       touching .mission/mission.yaml and .mission/ledger/entries.jsonl, at which mission.yaml reads
        #       `state: Complete`; refused when there is none and when there is more than one. So the stamp can
        #       never precede the transition it records (S2): before that commit exists there is nothing to see.
        # THE RECORD (Q4): consumed_at replaced in place, exactly as above; then consumed_commit, consumed_ref
        # (the ref HEAD names) and a consumed_basis of plain words. EVERY VALUE IS IN THE PLACEMENT ARM'S LINE
        # SHAPE (S7, mission-goal-check.ps1:1690-:1697) and is checked against it before anything is composed: no
        # ': ', no TAB, no CR or LF, no leading blank or indicator, no trailing ':'. $script:LamConsumeBlockFields
        # is NOT widened (S6): the first-stamp guard above sees consumed_at, consumed_ref and consumed_basis, and a
        # LONE hand-written consumed_commit is invisible to it -- the residual, stated.
        function Invoke-SettleGit {
            # One git call in the mission root. Its stdout is kept as BYTES -- a blob is not text -- and its
            # exit code is read from the process itself, never inferred from empty output.
            param([string[]]$GitArgs)
            $sgQuoted = foreach ($sgA in @(@('-C', $MissionRoot) + $GitArgs)) {
                if (($sgA.Length -gt 0) -and ($sgA -notmatch '[\s"]')) { $sgA } else { '"' + (($sgA -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"' }
            }
            $sgPsi = New-Object System.Diagnostics.ProcessStartInfo
            $sgPsi.FileName = 'git'
            $sgPsi.Arguments = (@($sgQuoted) -join ' ')
            $sgPsi.UseShellExecute = $false
            $sgPsi.RedirectStandardOutput = $true
            $sgPsi.RedirectStandardError = $true
            $sgPsi.CreateNoWindow = $true
            $sgP = [System.Diagnostics.Process]::Start($sgPsi)
            $sgErr = $sgP.StandardError.ReadToEndAsync()
            $sgMs = New-Object System.IO.MemoryStream
            $sgP.StandardOutput.BaseStream.CopyTo($sgMs)
            $sgP.WaitForExit()
            return [pscustomobject]@{ code = $sgP.ExitCode; bytes = $sgMs.ToArray(); err = ([string]$sgErr.Result).Trim() }
        }
        function Get-SettleText { param($R) return (New-Object System.Text.UTF8Encoding($false)).GetString([byte[]]$R.bytes) }
        function Get-SettleSha {
            param([byte[]]$B)
            $shH = [System.Security.Cryptography.SHA256]::Create()
            try { return ([System.BitConverter]::ToString($shH.ComputeHash($B)) -replace '-', '').ToLowerInvariant() } finally { $shH.Dispose() }
        }
        $stamp = $script:LamComposedAtStr
        $headRef = Invoke-SettleGit @('symbolic-ref', '-q', 'HEAD')
        $obsRef = (Get-SettleText $headRef).Trim()
        if (($headRef.code -ne 0) -or (-not $obsRef)) { $obsRef = 'HEAD' }
        $obsCommit = ''
        $obsBasis = ''
        $obsWhat = ''
        if ($kindCanon -ceq 'amendment-material') {
            $bindsMs = @([regex]::Matches($t, '(?m)^binds:[ \t]*(.*?)[ \t]*\r?$'))
            $shaRead = Get-LamGateScalarField -Text $t -Field 'binds_sha256'
            $bindsVal = if ($bindsMs.Count -eq 1) { [string]$bindsMs[0].Groups[1].Value } else { '' }
            $bindSha = ([string]$shaRead.value).ToLowerInvariant()
            if (($bindsMs.Count -ne 1) -or (-not $bindsVal) -or (-not $shaRead.ok) -or ($bindSha -notmatch '\A[0-9a-f]{64}\z')) {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id does not declare exactly one binds path and one 64-hex binds_sha256 on its own face ($($bindsMs.Count) binds key(s); $(if ($shaRead.ok) { 'binds_sha256 ' + $bindSha } else { $shaRead.reason }))."
                Write-Output "  Settling records the commit holding THE bound file at THE bound digest, and an artifact that does"
                Write-Output "  not name one of each does not say which. NOTHING WAS WRITTEN."
                exit 2
            }
            $bindRel = ''
            try {
                $bindFull = [System.IO.Path]::GetFullPath($(if ([System.IO.Path]::IsPathRooted($bindsVal)) { $bindsVal } else { [System.IO.Path]::Combine($MissionRoot, $bindsVal) }))
                $rootFull = [System.IO.Path]::GetFullPath($MissionRoot).TrimEnd('\') + '\'
                if ($bindFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { $bindRel = $bindFull.Substring($rootFull.Length).Replace('\', '/') }
            } catch { $bindRel = '' }
            if (-not $bindRel) {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id binds '$bindsVal', which does not resolve to a file under the mission root $MissionRoot."
                Write-Output "  The observation reads that path in this repository's history, and a path outside it has none here."
                Write-Output "  NOTHING WAS WRITTEN."
                exit 2
            }
            $logR = Invoke-SettleGit @('--literal-pathspecs', 'log', '--full-history', '--topo-order', '--format=%H', 'HEAD', '--', $bindRel)
            if ($logR.code -ne 0) {
                Write-Output "mission-gate: REFUSED -- HEAD's history could not be read in $MissionRoot (git log exited $($logR.code)): $($logR.err)"
                Write-Output "  A settle records a commit it OBSERVED; a history that cannot be read supports no such record."
                Write-Output "  NOTHING WAS WRITTEN."
                exit 2
            }
            $cands = @(@((Get-SettleText $logR) -split "`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '\A[0-9a-f]{40}\z' })
            $holding = New-Object System.Collections.Generic.List[string]
            foreach ($cand in $cands) {
                $cf = Invoke-SettleGit @('cat-file', '--filters', ($cand + ':./' + $bindRel))
                if (($cf.code -eq 0) -and ((Get-SettleSha $cf.bytes) -ceq $bindSha)) { $holding.Add($cand); continue }
                $cb = Invoke-SettleGit @('cat-file', 'blob', ($cand + ':./' + $bindRel))
                if (($cb.code -eq 0) -and ((Get-SettleSha $cb.bytes) -ceq $bindSha)) { $holding.Add($cand) }
            }
            if ($holding.Count -eq 0) {
                Write-Output "mission-gate: REFUSED -- no commit on HEAD's history holds $bindRel at this gate's binds_sha256, so there is no use to record."
                Write-Output "  binds        : $bindsVal"
                Write-Output "  binds_sha256 : $bindSha"
                Write-Output "  commits read : $($cands.Count) touching that path, none holding those bytes (checked out or as stored)"
                Write-Output "  The authorization is NOT spent: commit the amendment it binds, then settle. NOTHING WAS WRITTEN."
                exit 2
            }
            $newest = $holding[0]
            for ($hi = 1; $hi -lt $holding.Count; $hi++) {
                $anc = Invoke-SettleGit @('merge-base', '--is-ancestor', $holding[$hi], $newest)
                if ($anc.code -ne 0) {
                    Write-Output "mission-gate: REFUSED -- $Kind-$Id is AMBIGUOUS in history: commits $newest and $($holding[$hi]) both hold $bindRel at its binds_sha256 and neither stands above the other."
                    Write-Output "  Which of them is the newest is then a choice, and this reader does not make it. NOTHING WAS WRITTEN."
                    exit 2
                }
            }
            $obsCommit = $newest
            $obsBasis = 'record of use by console -- the newest commit on HEAD holding the bound file at binds_sha256'
            $obsWhat = "that the newest commit on HEAD's history holding $bindRel at its binds_sha256 was OBSERVED"
        } else {
            $subject = "reclose: Reworking -> Complete (ADR-029) -- RE-CLOSURE #$Id"
            $logR = Invoke-SettleGit @('--literal-pathspecs', 'log', '--full-history', '--format=%H%x09%s', 'HEAD', '--', '.mission/mission.yaml')
            if ($logR.code -ne 0) {
                Write-Output "mission-gate: REFUSED -- HEAD's history could not be read in $MissionRoot (git log exited $($logR.code)): $($logR.err)"
                Write-Output "  A settle records a commit it OBSERVED; a history that cannot be read supports no such record."
                Write-Output "  NOTHING WAS WRITTEN."
                exit 2
            }
            $found = New-Object System.Collections.Generic.List[string]
            foreach ($logLine in @((Get-SettleText $logR) -split "`n")) {
                if (($logLine.Length -lt 42) -or ($logLine[40] -ne [char]9)) { continue }
                $cand = $logLine.Substring(0, 40)
                if ($logLine.Substring(41).TrimEnd() -cne $subject) { continue }
                $dt = Invoke-SettleGit @('diff-tree', '--root', '--no-commit-id', '--name-only', '-r', '--relative', $cand)
                if ($dt.code -ne 0) { continue }
                $touched = @(@((Get-SettleText $dt) -split "`n") | ForEach-Object { $_.Trim() })
                if (($touched -cnotcontains '.mission/mission.yaml') -or ($touched -cnotcontains '.mission/ledger/entries.jsonl')) { continue }
                $mt = Invoke-SettleGit @('cat-file', 'blob', ($cand + ':./.mission/mission.yaml'))
                if (($mt.code -eq 0) -and ((Get-SettleText $mt) -match '(?m)^state:[ \t]*Complete[ \t]*\r?$')) { $found.Add($cand) }
            }
            if ($found.Count -eq 0) {
                Write-Output "mission-gate: REFUSED -- no commit on HEAD's history is the re-closure $Kind-$Id authorized, so there is no use to record."
                Write-Output "  looked for : the subject '$subject', touching .mission/mission.yaml and"
                Write-Output "               .mission/ledger/entries.jsonl, at which .mission/mission.yaml reads state Complete"
                Write-Output "  A re-closure gate is settled AFTER mission-reclose has committed the transition it authorized, and"
                Write-Output "  the stamp never precedes it. NOTHING WAS WRITTEN."
                exit 2
            }
            if ($found.Count -gt 1) {
                Write-Output "mission-gate: REFUSED -- $Kind-$Id is AMBIGUOUS in history: $($found.Count) commits are that re-closure ($($found -join ', '))."
                Write-Output "  A gate authorizes ONE transition, and this reader does not pick which of them it was. NOTHING WAS WRITTEN."
                exit 2
            }
            $obsCommit = $found[0]
            $obsBasis = 'record of use by console -- the re-closure commit on HEAD, at which mission.yaml reads state Complete'
            $obsWhat = "that the re-closure commit on HEAD's history, at which .mission/mission.yaml reads state Complete, was OBSERVED"
        }
        foreach ($shapeVal in @($stamp, $obsCommit, $obsRef, $obsBasis)) {
            $sv = [string]$shapeVal
            if ((-not $sv) -or $sv.Contains(': ') -or $sv.Contains("`t") -or $sv.Contains("`r") -or $sv.Contains("`n") -or $sv.EndsWith(':') -or
                ($sv -match '\A\s') -or ('{[]}&*!|>%@`?,"''-#'.IndexOf($sv[0]) -ge 0)) {
                Write-Output "mission-gate: REFUSED -- a value this settle would write is not in the placement arm's line shape: '$sv'."
                Write-Output "  Every value settle writes must hold no ': ', no TAB and no line break, and start with no blank or"
                Write-Output "  indicator, or the evaluator would read the gate as other than live. NOTHING WAS WRITTEN."
                exit 2
            }
        }
        $body = $t
        if ($body -match '(?m)^consumed_at:') {
            $body = [regex]::Replace($body, '(?m)^consumed_at:[^\r\n]*', "consumed_at: $stamp")
        } else {
            $body = $body.TrimEnd() + "`r`nconsumed_at: $stamp"
        }
        $body = $body.TrimEnd() + "`r`nconsumed_commit: $obsCommit" +
                                  "`r`nconsumed_ref: $obsRef" +
                                  "`r`nconsumed_basis: $obsBasis`r`n"
        $settleBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($body)
        $settleWrites = @([pscustomobject]@{ name = "$Kind-$Id.yaml"; bytes = $settleBytes })
        $settleDigest = Get-LamActDigest -Writes $settleWrites
        Invoke-LamGateComposeOrRefuse -Verb $Command -Writes $settleWrites -BindsPath '' -BindsSha '' -ActDigest $settleDigest
        [System.IO.File]::WriteAllBytes($p, $settleBytes)
        Send-LamGateTelemetry -Kind 'gate_consumed' -GatePath $p -Snapshot
        Write-Output "mission-gate: settled $Kind-$Id"
        Write-Output "  consumed_at     : $stamp"
        Write-Output "  consumed_commit : $obsCommit"
        Write-Output "  consumed_ref    : $obsRef"
        Write-Output "  consumed_basis  : $obsBasis"
        Write-Output "  NOTE: this records $obsWhat."
        Write-Output "  It is a RECORD OF USE, not an authorization."
        if ($kindCanon -ceq 'reclose') {
            Write-Output "  A stamped reclose gate authorizes no further transition (mission-reclose refuses it); a new"
            Write-Output "  re-closure has its own number and its own gate."
        }
        exit 0
    }
    # APPROVE AND REAPPROVE SHARE ONE PATH, DELIBERATELY. A re-mint that ran a
    # SECOND copy of the mint logic would be a gate written by machinery no member of this build
    # drives -- and every refusal approve carries (the wildcard -Binds, the drive-relative path, the
    # directory, the locked file, the unmapped kind, the push gate with no declared origin) would
    # have to be restated to hold for it. They are not restated: reapprove is approve, with a prior.
    { @('approve','reapprove') -contains $_ } {
        $isReapprove = ($Command -eq 'reapprove')
        $verb = $Command
        if (-not $Kind -or -not $Id) { Write-Output "mission-gate: $verb needs -Kind and -Id"; exit 2 }
        if (-not $Binds) { Write-Output "mission-gate: $verb needs -Binds <path> -- an authorization that binds nothing authorizes everything"; exit 2 }
        # A GATE IS A STATEMENT ABOUT A MISSION, NOT ABOUT A SHELL (V-1 round 14, orchestrator,
        # driven while building the round's falsification harness). Both the existence check and
        # the hash below resolved `-Binds` against the PROCESS CWD, while every other mission-scoped
        # path in this build resolves against `-MissionRoot`.
        #
        # The refusal is the harmless half. The harmful half is silent: with the operator's shell
        # standing in a directory that happens to hold a file of that name, this check PASSES and
        # `binds_sha256` is computed over a DIFFERENT FILE THAN THE GATE NAMES -- and that field is
        # what mission-dispatch compares, on an artifact ruled immutable. An authorization
        # for the wrong bytes, unamendable by construction.
        #
        # S7, instance EIGHT. mission-goal-check's `file_exists` detector carries this same cure with
        # a comment dated V-1 round 3 -- "Every other detector is mission-scoped; this one silently
        # answered about whatever directory the evaluator happened to be launched from". The class
        # was named eleven rounds ago and the MINT path was never enumerated against it, which is
        # an unenumerated path in the plainest form the build has produced.
        # "ROOTED" IS NOT "FULLY QUALIFIED", AND THE DIFFERENCE MINTED A GATE FOR THE WRONG FILE
        # (V-1 round 15, a WP-4 finding, driven). `[IO.Path]::IsPathRooted` returns True for `C:e.txt` --
        # the current directory OF DRIVE C -- and for `\dir\file.txt`, the current DRIVE's root.
        # Both are relative to per-process state, so both skipped the mission-root join: with the
        # shell in one directory and -MissionRoot in another, `-Binds C:e.txt` minted successfully
        # and bound the SHELL-side file, recording `binds_resolved: C:e.txt` -- a string that
        # identifies no determinate file. On an artifact ruled immutable.
        #
        # RESTATED FROM `Test-EvidencePathIsFullyQualified` IN THE HOOKS LIBRARY, WHICH IS THE
        # AUTHORITY. This tool is on the other plane -- it dot-sources lam-gate-class.ps1 only -- and
        # dot-sourcing the guard library into an operator CLI to share one predicate would drag
        # Set-StrictMode and the whole guard surface with it. The duplication is therefore
        # deliberate and is marked, rather than left for a later reader to discover the way the
        # origin read and the gate-state predicate were.
        # THE INPUT IS VALIDATED BEFORE ANY PATH CALL TOUCHES IT (V-1 round 16, a WP-4 finding, driven).
        # Catching around the join was not enough: `*` and `?` reached the join and were caught, but
        # `<` and `|` still exited 9, because an EARLIER path call throws on them first. Chasing
        # which call throws is the wrong shape -- the question is whether this string can name ONE
        # FILE AT ALL, and that is answerable before anything tries to resolve it.
        #
        # A gate binds one file BY HASH, so a wildcard cannot be bound even in principle: it names a
        # set. Checking first means every unusable shape produces the SAME refusal rather than
        # whichever exception the first path call happens to raise -- which is the difference
        # between a refusal and a crash, and the reason this finding existed at all.
        $badChars = @([IO.Path]::GetInvalidPathChars()) + @([char]'*', [char]'?')
        $offending = @($badChars | Where-Object { $Binds.IndexOf($_) -ge 0 } | Sort-Object -Unique)
        if ($offending.Count -gt 0) {
            $shown = (@($offending | ForEach-Object {
                $code = [int][char]$_
                if ($code -lt 32) { 'chr(' + $code + ')' } else { "'" + $_ + "'" }
            }) -join ', ')
            Write-Output "mission-gate: REFUSING -- -Binds '$Binds' cannot name a single file."
            Write-Output "  Offending character(s): $shown"
            Write-Output '  A gate binds ONE file by hash. A wildcard names a set, and the rest are not legal in a'
            Write-Output '  Windows path at all. Pass a single mission-relative or fully qualified path.'
            exit 2
        }
        # =========================================================================================
        # A HALT RULING NAMES ITS HALT TWICE, AND THE TWO MUST AGREE.
        # =========================================================================================
        # The goal evaluator looks for the ruling on a HALT at ONE path, derived from the HALT file's
        # own name: .mission\gates\halt-ruling-<HALT BaseName>.yaml, and it requires the artifact's
        # halt_id to be that BaseName. A gate minted under any other id would sit where no reader
        # looks -- an operator act that answers nothing, silently. So the id is not free here: it IS
        # the bound file's BaseName, and the bound file must be a HALT (a leaf beginning HALT-, the
        # name the scan enumerates). Checked here, BEFORE any path is resolved and before anything is
        # composed, so a refusal writes nothing in every mode.
        #
        # THE PREFIX IS MATCHED CASE-INSENSITIVELY AND THE ID CASE-SENSITIVELY, and each for the same
        # reason: to agree with the reader. The scan's -Filter 'HALT-*' is case-insensitive, so a HALT
        # named in lower case IS scanned and must be rulable; Test-HaltRuled compares halt_id with -ceq,
        # so an id differing only in case would mint a gate that never answers.
        $haltRulingBase = ''
        if ($Kind -eq 'halt-ruling') {
            $haltRulingLeaf = @($Binds -split '[\\/]')[-1]
            $haltRulingBase = [IO.Path]::GetFileNameWithoutExtension([string]$haltRulingLeaf)
            if ((-not $haltRulingLeaf) -or (-not $haltRulingLeaf.StartsWith('HALT-', [System.StringComparison]::OrdinalIgnoreCase))) {
                Write-Output "mission-gate: REFUSED -- a halt-ruling gate must bind a HALT file, and -Binds '$Binds' does not name one."
                Write-Output "  its leaf name is '$haltRulingLeaf'; a HALT file's name begins HALT- (the name the goal evaluator scans)."
                Write-Output '  A halt ruling answers ONE HALT by binding that HALT file''s bytes. NOTHING WAS WRITTEN.'
                exit 2
            }
            # THE ID IS A HALT NAME THE READER CAN READ BACK (a review's finding, driven). Any
            # BaseName used to be accepted, so -Id "HALT-A B" over "HALT-A B.md" minted a gate recording
            # `halt_id: HALT-A B` that the evaluator's reader of that day could not match -- an operator
            # ruling that silently answered nothing. The id must match the pattern below, whose
            # characters are exactly those a halt_id line carries unambiguously. The HALT- PREFIX is
            # matched case-insensitively for the reason the leaf check above gives (the scan's
            # -Filter 'HALT-*' is case-insensitive, so a scanned lower-case HALT file must stay rulable); every
            # character after it is held to the class exactly. Every one of the 89 live HALT names at the
            # legacy census matches it. Checked BEFORE the BaseName comparison, so a whitespace id is
            # refused naming the pattern even when it equals the BaseName.
            if (-not [regex]::IsMatch([string]$Id, $script:LamHaltRulingIdPattern)) {
                Write-Output "mission-gate: REFUSED -- a halt-ruling gate's -Id must match ^HALT-[A-Za-z0-9][A-Za-z0-9._-]*`$ (the HALT- prefix in any case)."
                Write-Output "  -Id    : '$Id'"
                Write-Output '  A halt_id outside that pattern -- a space, a tab, a quote, a colon -- is a ruling the goal evaluator'
                Write-Output '  might not read back as the HALT it names. Rename the HALT file to a name that matches, then rule on it.'
                Write-Output '  NOTHING WAS WRITTEN.'
                exit 2
            }
            if ($Id -cne $haltRulingBase) {
                Write-Output "mission-gate: REFUSED -- a halt-ruling gate's -Id must be the bound HALT file's BaseName."
                Write-Output "  -Id    : $Id"
                Write-Output "  -Binds : $Binds  (BaseName '$haltRulingBase')"
                Write-Output "  The goal evaluator reads the ruling on a HALT at .mission\gates\halt-ruling-<HALT BaseName>.yaml and"
                Write-Output '  requires halt_id to equal that BaseName, so a gate under any other id would answer nothing.'
                Write-Output "  Re-run with -Id $haltRulingBase. NOTHING WAS WRITTEN."
                exit 2
            }
        }
        $bindsResolved = $Binds
        $fullyQualified = [bool]([regex]::IsMatch($Binds, '^[A-Za-z]:[\\/]') -or [regex]::IsMatch($Binds, '^[\\/][\\/]'))
        # A DRIVE-RELATIVE PATH IS REFUSED, NOT REPAIRED. `C:e.txt` is the current directory OF
        # DRIVE C and `\dir\f` is the current DRIVE's root -- both per-process state, so no root
        # this tool holds resolves them to a determinate file. The first draft of this cure joined
        # them against -MissionRoot anyway, which builds an invalid path and made GetFullPath THROW:
        # fail-closed by accident, as an unhandled exception rather than a refusal, which tells the
        # operator nothing and reads as a broken tool rather than a rejected input.
        if ((-not $fullyQualified) -and [IO.Path]::IsPathRooted($Binds)) {
            Write-Output "mission-gate: REFUSING -- -Binds '$Binds' is DRIVE-RELATIVE, not a determinate file."
            Write-Output '  A path of the form C:name, or one beginning with a single separator, is anchored to'
            Write-Output '  per-process state, so which file it names depends on the shell that ran this command.'
            Write-Output '  Pass a mission-relative path, or a fully qualified one.'
            exit 2
        }
        if (-not $fullyQualified) {
            # AND THE JOIN IS GUARDED, BECAUSE THE rc-9 CLASS WAS NOT CLOSED -- ONLY ITS
            # DRIVE-RELATIVE INSTANCE (V-1 round 16, a WP-4 finding, driven). The refusal above removes one
            # input family from this call; every other non-rooted -Binds still reaches it, and
            # GetFullPath throws on a path containing characters Windows forbids. The script trap
            # then converts that into UNHANDLED ERROR plus a stack trace and exit 9.
            #
            # `-Binds 'notes*.md'` and `-Binds 'who?.txt'` both did exactly that -- and a WILDCARD is
            # the first thing an operator reaches for. Fail-closed, so the harm is diagnostic only,
            # but it is precisely the outcome the commit that introduced the refusal named
            # unacceptable: "it crashed" and "it refused" are different outcomes and only one of them
            # tells the operator anything. That commit's own SCOPE paragraph covered IsPathRooted and
            # not this.
            try {
                $bindsResolved = [IO.Path]::GetFullPath((Join-Path $MissionRoot $Binds))
            } catch {
                Write-Output "mission-gate: REFUSING -- -Binds '$Binds' is not a usable path: $($_.Exception.Message)"
                Write-Output "  A gate binds ONE file by hash. Wildcards and characters Windows forbids in a path"
                Write-Output "  cannot name one file, so there is nothing to bind. Pass a single mission-relative or"
                Write-Output "  fully qualified path."
                exit 2
            }
        }
        if (-not (Test-Path -LiteralPath $bindsResolved)) {
            Write-Output "mission-gate: the bound artifact is not on disk: $Binds"
            Write-Output "  resolved against -MissionRoot '$MissionRoot' to: $bindsResolved"
            Write-Output "  (relative -Binds is mission-scoped, NOT relative to your shell's directory)"
            Write-Output "  -MissionRoot is the RESOLUTION BASE, not a boundary: '..\\outside.txt' resolves and mints."
            Write-Output "  What a gate binds is recorded by sha256, so a file outside the mission is bound honestly;"
            Write-Output "  containment is not claimed here and no consumer infers it (V-1 round 17, a WP-4 finding)."
            exit 2
        }
        # AND IS IT A FILE? `Test-Path` IS TRUE OF DIRECTORIES (V-1 round 17, a WP-4 finding,
        # driven). `-Binds sub`, `-Binds .` and `-Binds sub\` all reached `Get-FileHash` below,
        # which returns nothing for a directory, so `.Hash.ToLowerInvariant()` threw and the tool
        # exited 9 with a stack trace.
        #
        # Fail-closed, and still wrong: a CRASH is not a refusal. It tells the
        # operator nothing about what to fix, it is indistinguishable from the tool being broken,
        # and exit 9 is fail-closed BY ACCIDENT rather than by decision.
        #
        # THE ROUND-16 CURE ANSWERED A NARROWER QUESTION THAN ITS OWN RATIONALE CLAIMED. It validated
        # the input for wildcards and characters Windows forbids, under the heading "can this string
        # name ONE FILE at all" -- which a directory path passes at the character level and fails in
        # fact. Same question, one layer down: the string is a legal path, and the path is not a file.
        if (-not (Test-Path -LiteralPath $bindsResolved -PathType Leaf)) {
            Write-Output "mission-gate: REFUSING -- -Binds '$Binds' names a DIRECTORY, not a file."
            Write-Output "  resolved against -MissionRoot '$MissionRoot' to: $bindsResolved"
            Write-Output "  A gate binds ONE artifact and records its sha256; a directory has none."
            exit 2
        }

        # THE GATES DIRECTORY IS CREATED ONLY AT THE MUTATING REGION, NOT HERE.
        # -ComposeOnly must create nothing, and a refused mint must leave no gates directory, so the
        # New-Item moved down to just past the compose-or-token checkpoint. Everything between here and
        # there is read-only and works whether or not the directory exists.
        $p = Get-GatePath -K $Kind -I $Id
        $priorExists = Test-Path -LiteralPath $p

        # =========================================================================================
        # THE PRIOR. EVERY REFUSAL BELONGING TO THE RE-MINT IS DECIDED HERE, AND
        # HERE IS BEFORE ANY MUTATION. Nothing on disk moves until the whole artifact has been built.
        # =========================================================================================
        $priorText  = $null
        $priorState = $null
        if (-not $isReapprove) {
            if ($priorExists) {
                Write-Output "mission-gate: a gate already exists at $p. Revoke it before re-approving -- overwriting an authorization silently is how a consumed one comes back to life."
                Write-Output "  To re-mint over this id in ONE act -- revoke, rename to .revoked-N, approve -- run 'reapprove' with the same arguments."
                exit 2
            }
        } else {
            # (1) A RE-MINT IS NOT A FIRST MINT. Without a prior there is nothing to supersede, and
            #     silently behaving like `approve` would make the verb a synonym an operator could
            #     reach for by habit -- which is how a first authorization gets minted by a command
            #     whose name says something already existed.
            if (-not $priorExists) {
                Write-Output "mission-gate: REFUSED -- reapprove found no gate at $p."
                Write-Output "  reapprove RE-MINTS over an existing authorization: it revokes the prior, renames it to"
                Write-Output "  $Kind-$Id.revoked-N.yaml and approves in its place. There is no prior here, so there is"
                Write-Output "  nothing to revoke and nothing to rename. Use 'approve' to mint the first gate for this id."
                exit 2
            }
            $priorText = [System.IO.File]::ReadAllText($p)
            # THE PRIOR'S RAW BYTES, READ ONCE, BESIDE ITS TEXT (a review finding). ReadAllText
            # strips a UTF-8 byte-order mark; an already-revoked prior is MOVED as-is, BOM and all, so the
            # write the console previews for its .revoked-N name must be these bytes, not a re-encoding of
            # the text -- or the previewed sha256 names bytes that never land on disk.
            $priorRawBytes = [System.IO.File]::ReadAllBytes($p)
            # (2) THE ARTIFACT IS THE AUTHORITY ON ITS OWN KIND -- revoke's rule, and reapprove
            #     revokes, so it inherits the rule rather than restating a weaker one. A file NAMED
            #     for one kind that declares another would otherwise be revoked-and-renamed under a
            #     name the operator did not mean to touch, and re-minted as something it never was.
            $priorKind = (Get-LamGateClassForArtifact -Path $p).kind
            if (-not $priorKind) {
                Write-Output "mission-gate: REFUSED -- the artifact at $p declares no kind at all, so there is nothing to check '$Kind' against. A gate whose own face does not say what it is cannot be re-minted by name."
                exit 2
            }
            # THE ONE CASE RULE (an operator ruling): both sides through the shared reader,
            #     ORDINALLY. `-ne` FOLDED, and reapprove REVOKES the prior before it mints -- so a
            #     fold here withdraws one capability and issues another under a spelling that is not
            #     a kind at all.
            $priorCanon = Resolve-LamGateKind -Kind $priorKind
            $kindCanon = Resolve-LamGateKind -Kind $Kind
            if ((-not $priorCanon) -or (-not $kindCanon) -or ($priorCanon -cne $kindCanon)) {
                $caseNote = ''
                if (-not $priorCanon) { $caseNote = ' ' + (Get-LamGateKindRefusalReason -Kind $priorKind) + '.' }
                if (($caseNote -ceq '') -and (-not $kindCanon)) { $caseNote = ' ' + (Get-LamGateKindRefusalReason -Kind $Kind) + '.' }
                Write-Output "mission-gate: REFUSED -- the artifact at $p declares 'kind: $priorKind', not '$Kind'.$caseNote reapprove REVOKES the prior, so it would withdraw a capability you did not mean to touch and mint a different one in its place. Re-mint it as '$priorKind', or fix the filename."
                exit 2
            }
            # (3) THE CENTRAL REFUSAL. A CONSUMED AUTHORIZATION WAS SPENT.
            #     approve's own refusal already names the hazard -- "overwriting an authorization
            #     silently is how a consumed one comes back to life" -- and a verb that renames the
            #     prior out of the way and mints over it is EXACTLY that overwrite, performed
            #     politely. The consumption record would still exist under a .revoked-N name, so
            #     nothing would be lost from the audit trail; what would be lost is the guarantee,
            #     because a fresh unconsumed gate would stand at the canonical path that a spent one
            #     occupied, and every consumer reads the canonical path. single_use enforced by the
            #     hook means nothing if the operator can re-mint past it with one command.
            #     Withdrawing a spent authorization is `revoke`; issuing a NEW capability after one
            #     was used is a NEW id, and the operator states that intent by typing it.
            $priorState = Get-LamGateState -Path $p
            if ($priorState.consumed) {
                Write-Output "mission-gate: REFUSED -- the gate at $p is CONSUMED."
                Write-Output "  A consumed authorization was SPENT. Re-minting over it would resurrect a capability that"
                Write-Output "  has already been used: the prior would move to a .revoked-N name and a FRESH, unconsumed"
                Write-Output "  gate would stand at the canonical path every consumer reads. That is the hazard approve's"
                Write-Output "  own refusal names -- overwriting an authorization silently is how a consumed one comes"
                Write-Output "  back to life -- performed politely instead of silently, which does not make it safe."
                Write-Output "  If the capability is genuinely needed again, that is a NEW authorization: mint a new id."
                exit 2
            }
            # (4) WHAT "THE SAME BINDS" MEANS, DECIDED AND DISCLOSED.
            #     -Binds is MANDATORY on reapprove and must name THE SAME FILE the prior binds. Its
            #     CONTENT is deliberately free to differ, and normally does: that is the whole reason
            #     re-mints exist. The record settles it -- an amendment's v2 re-minted
            #     its amendment-material gate over the SAME path
            #     (the amendment's own file under .mission\amendments) while binds_sha256 moved
            #     to a new digest, because the amendment had been restated in place. A
            #     verb that required the digest to match would have refused the only re-mint the
            #     record documents field by field. Every one of the seven re-minted ids on disk shows
            #     the same shape: identical `binds:` across the live gate and its .revoked-N siblings.
            #     THE PATH IS HELD BECAUSE THE ALTERNATIVE IS A SILENT RE-POINT, which is precisely
            #     what binds_sha256 exists to prevent ("an approval cannot be silently re-pointed at
            #     different content"). A re-mint that also changed WHICH file is bound is not a
            #     re-mint of this authorization; it is a different authorization wearing its id, and
            #     the operator can still perform it with the three-act manual form, which this verb
            #     does not remove.
            $priorBinds = ''
            if ($priorText -match '(?m)^binds:[ \t]*(.+?)[ \t]*\r?$') { $priorBinds = $Matches[1] }
            $priorBindsResolved = ''
            if ($priorText -match '(?m)^binds_resolved:[ \t]*(.+?)[ \t]*\r?$') { $priorBindsResolved = $Matches[1] }
            $priorBindsSha = ''
            if ($priorText -match '(?m)^binds_sha256:[ \t]*(\S+)') { $priorBindsSha = $Matches[1] }
            # Normalized for separator and case only -- Windows path equality, not string equality.
            # `.mission/dispatches/X.yaml` and `.mission\dispatches\X.yaml` are the same file and an
            # operator types both; a refusal over a slash would be a refusal about nothing.
            $normPrior = ($priorBinds -replace '/', '\').Trim().TrimEnd('\').ToLowerInvariant()
            $normGiven = ($Binds      -replace '/', '\').Trim().TrimEnd('\').ToLowerInvariant()
            $sameBinds = ($normPrior -ne '') -and ($normPrior -eq $normGiven)
            if ((-not $sameBinds) -and $priorBindsResolved) {
                # The operator may spell it fully qualified where the prior recorded a relative path,
                # or the reverse. Both resolve to one absolute file, and that is the real comparison.
                $sameBinds = (($priorBindsResolved -replace '/', '\').Trim().TrimEnd('\').ToLowerInvariant() -eq
                              ($bindsResolved      -replace '/', '\').Trim().TrimEnd('\').ToLowerInvariant())
            }
            if (-not $sameBinds) {
                Write-Output "mission-gate: REFUSED -- reapprove must bind THE SAME FILE the prior gate binds."
                Write-Output "  prior binds : $priorBinds"
                Write-Output "  you passed  : $Binds"
                Write-Output "  A re-mint exists because the bound file's BYTES changed -- its content is free to differ"
                Write-Output "  and normally does. Which FILE is bound is not: re-pointing an id at different content is"
                Write-Output "  exactly what binds_sha256 exists to prevent. If you mean a different file, that is a"
                Write-Output "  different authorization: mint a new id, or perform the revoke / rename / approve by hand."
                exit 2
            }
        }

        # A FILE ANOTHER PROCESS HOLDS OPEN IS A REFUSAL, NOT A CRASH (V-1 round 19, a WP-4 finding, driven).
        # This line was `Get-FileHash` with no guard, so a locked artifact surfaced as
        # "UNHANDLED ERROR" and exit 9 -- fail-closed BY ACCIDENT rather than by decision, which is
        # this script's own phrase about a different defect forty lines up.
        #
        # AND THE SHARE MODE IS THE OTHER HALF. Share modes are checked in BOTH directions: the
        # reader's requested access must be allowed by the holder's share mode, and the reader's own
        # share mode must allow the access the holder already has. Get-FileHash asks for
        # FileShare::Read, which does not admit a holder's WRITE handle -- so the ordinary "a log is
        # being appended to" case failed too. Driven: holder with FileAccess::ReadWrite and
        # FileShare::Read gave exit 9 under Get-FileHash and mints through the stream below. The
        # finding predicted that case already worked; it did not.
        #
        # THE DIGEST IS UNCHANGED. `binds_sha256` is recorded in live gate artifacts, so a different
        # digest here would silently invalidate every existing binding. Asserted byte-equal to
        # Get-FileHash's output on an ordinary file.
        $bindsSha = $null
        try {
            $bindsStream = New-Object System.IO.FileStream(
                $bindsResolved,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            try {
                $bindsHasher = [System.Security.Cryptography.SHA256]::Create()
                try {
                    $bindsSha = ([BitConverter]::ToString($bindsHasher.ComputeHash($bindsStream))).Replace('-', '').ToLowerInvariant()
                } finally { $bindsHasher.Dispose() }
            } finally { $bindsStream.Dispose() }
        } catch {
            Write-Output "mission-gate: REFUSING -- -Binds '$Binds' names a file that cannot be READ right now."
            Write-Output "  resolved against -MissionRoot '$MissionRoot' to: $bindsResolved"
            Write-Output "  $($_.Exception.Message)"
            Write-Output "  A gate records the sha256 of what it binds; a digest that could not be computed is not one."
            Write-Output "  Most often another process holds the file with no sharing -- close it and approve again."
            exit 2
        }

        # For a push gate the tip is mandatory: an authorization not bound to a specific commit is
        # a standing capability, which is the thing ADR-033 exists to abolish.
        #
        # THE SOURCE-SIDE CURE, AND IT IS THE MOST VALUABLE HALF OF A REVIEW FINDING (round 3). `[string]$TipSha`
        # had NO validation of any kind -- no [ValidatePattern], no 40-hex test anywhere on this path --
        # and lam-console.ps1 passes it straight through. The composer below does
        # `$sb.AppendLine("authorized_tip_sha: $tip")`, so a value CARRYING A LINE BREAK composes TWO
        # column-0 keys. Driven at the old tip: `-TipSha "<40 hex>`r`nauthorized_tip_sha: <another 40 hex>"`
        # with -ComposeOnly exited 0 and planned an artifact with two authorized_tip_sha keys. That is not
        # only an ambiguity-discipline gap: an unvalidated -TipSha injects arbitrary LINES into a gate
        # artifact's composed bytes, and a gate artifact is this build's one human touchpoint.
        #
        # IT BELONGS HERE, AT THE MINT, AND NOT ONLY IN THE READERS. The readers' cure (the finding's other half)
        # makes an existing two-key artifact REFUSE, which is necessary because `.mission/gates` is
        # hand-annotatable by ruling and those artifacts already exist. It cannot stop one being
        # CREATED. This is the only writer of `authorized_tip_sha` in the toolchain, so this is the only
        # place the shape can be made unreachable rather than merely unusable.
        #
        # IT IS UNCONDITIONAL ON KIND, because the composer writes the field `if ($tip)` for ANY kind, not
        # only push. It fires only when a value was SUPPLIED: the HEAD fallback below derives a sha from
        # git and cannot produce anything else.
        if ($TipSha -and ($TipSha -cnotmatch '^[0-9a-fA-F]{40}$')) {
            Write-Output "mission-gate: REFUSED -- -TipSha is not a 40-character hexadecimal commit sha, so it is not a tip."
            Write-Output ('  supplied length : ' + $TipSha.Length + ' characters')
            Write-Output ('  carries a line break : ' + [bool]($TipSha -match '[\r\n]'))
            Write-Output ('  it must match ^[0-9a-fA-F]{40}$ exactly.')
            Write-Output "  authorized_tip_sha is composed by appending this value to a line of the artifact. A value carrying"
            Write-Output "  a line break composes TWO column-0 keys -- an artifact that declares two authorizations and says"
            Write-Output "  which by key order -- and any other value composes a key no consumer can ever match. NOTHING WAS"
            Write-Output "  WRITTEN: no gates directory was created and no artifact was minted."
            exit 2
        }
        # THE CANONICAL FORM IS FIXED HERE, AT THE ONLY WRITER OF authorized_tip_sha IN THE
        # TOOLCHAIN (round 3, the third decider-vs-admission divergence). The validation above
        # accepts ^[0-9a-fA-F]{40}$ -- deliberately, both cases -- so an operator could mint
        # `authorized_tip_sha: <UPPERCASE>`; and at the old tip the installed pre-push decider
        # compared that CASE-INSENSITIVELY (evidence-common.ps1, `-ne`) while the admission
        # compared it ORDINALLY (lam-verify-admission.ps1, `-cne`), so such a gate AUTHORIZED the
        # push and was REFUSED by the admission. Both readers now normalise; this is the other half
        # of that one rule, and it is the half that makes the divergent shape UNREACHABLE rather
        # than merely harmless -- the same source-versus-reader split a review finding turned on.
        #
        # NORMALISE, DO NOT REFUSE, and that is a decision rather than a default. A refusal would
        # reject a value that names exactly the right commit, on a ground -- hex case -- that
        # carries no meaning: `git rev-parse` below and `git ls-remote` at the two settle sites all
        # emit lowercase, and both of those sites already .ToLowerInvariant() what they capture. A
        # gate KIND went the other way under the operator's case ruling because a kind is drawn from a CLOSED
        # VOCABULARY, where two spellings are two tokens; two spellings of a sha are one commit.
        #
        # UNCONDITIONAL ON KIND, exactly as the validation above is, because the composer writes
        # the field `if ($tip)` for ANY kind and not only for push.
        #
        # THE [string] CAST IS BELT-AND-BRACES, AND WHAT IT DOES AND DOES NOT BUY WAS MEASURED
        # RATHER THAN ASSUMED, BECAUSE THE FOLKLORE IS WRONG IN THE DANGEROUS DIRECTION. An
        # unsupplied [string] parameter under PS 5.1 is the EMPTY STRING, not $null -- driven
        # under StrictMode before this line was written ($null -eq $TipSha reads False, the type
        # is System.String, and the bare method call returns ''). So the cast changes NOTHING
        # today, and `approve -Kind push` with no -TipSha still reaches the HEAD fallback below
        # rather than dying on a method call. It is kept so that an [AllowNull()] added later, or
        # a $null passed explicitly by a caller, cannot quietly turn this line into a crash on the
        # one path an operator takes when they let the tool derive the tip.
        $tip = ([string]$TipSha).ToLowerInvariant()
        if ($Kind -eq 'push') {
            if (-not $tip) {
                $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
                try {
                    $s = & git -C $MissionRoot rev-parse HEAD 2>&1
                    # NORMALISED HERE TOO, so the rule is the assignment's and not the caller's.
                    # git already answers lowercase, so this changes no observed value; it means a
                    # reader of this file does not have to know that to know the invariant holds.
                    if ($LASTEXITCODE -eq 0) { $tip = ("$s").Trim().ToLowerInvariant() }
                } finally { $ErrorActionPreference = $prev }
            }
            if (-not $tip) {
                Write-Output 'mission-gate: a push gate needs -TipSha, and HEAD could not be derived. Refusing to authorize an unspecified tip.'
                exit 2
            }
        }

        # CLASSIFY BEFORE WRITING, AND REFUSE RATHER THAN DEFAULT. A kind the map does not carry
        # would otherwise be written with an empty or guessed class, and a counting consumer would
        # then either drop it silently or invent a meaning for it. A new kind is a decision, not a
        # fall-through: add it to the map deliberately.
        $gateClass = Get-LamGateClassForKind -Kind $Kind
        if ($gateClass -eq 'unknown') {
            # THIS IS THE SOURCE-SIDE CURE (an operator ruling), AND IT IS WHY THE RULE BELONGS IN
            # THE READER. Get-LamGateClassForKind now resolves ORDINALLY, so `-Kind PUSH` classifies
            # 'unknown' HERE and NOTHING IS WRITTEN. It used to classify build-authorization through
            # the map's case-folding `.Contains()` and mint a literal `kind: PUSH` artifact at the
            # filename `PUSH-<id>.yaml`: `[ValidateSet]` validates case-insensitively and does NOT
            # normalise, and nothing in this file assigns to $Kind or lowercases it, so the spelling
            # the operator typed reached the artifact's own face and every consumer after it.
            Write-Output "mission-gate: kind '$Kind' is not in the gate-class map ($gateClassLib). Refusing to write an unclassified gate -- the zero-paste attestation counts by class, and an unclassified gate would be counted by nobody."
            Write-Output "  $(Get-LamGateKindRefusalReason -Kind $Kind)."
            exit 2
        }

        # THE TIMESTAMP IS PINNED TO -ComposedAt when the console supplies one, so
        # the bytes the console previewed and the bytes minted are identical. Parsed round-trip and
        # reformatted, which reproduces the same string; the live UTC time when none was supplied.
        $now = if ($ComposedAt) {
            [datetime]::ParseExact($ComposedAt, 'yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture,
                ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        } else { (Get-Date).ToUniversalTime() }
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# Gate artifact -- created by a human, consumed once, retained for audit.")
        [void]$sb.AppendLine("# design v2.3 SS10.5 / SS12.4, ADR-033, expanded-schemas SS13.")
        # THE LINE BELOW USED TO READ "Agents cannot write under .mission/gates/** -- the guard
        # hard-denies it (LAM-ACCEPT T-3)", AND AN AGENT MINTED ARTIFACTS CARRYING IT (driven).
        # It is in scope for this change precisely because it is the SAME false
        # claim as the one in .DESCRIPTION, stamped onto every artifact this tool has ever written
        # -- an audit artifact whose own face asserted a control that had not held when it was
        # created. A gate is read by people reconstructing what authorized what; a false sentence
        # there is worse than in a header, because the header is read by maintainers and this is
        # read as evidence. What replaces it says only what this tool actually does.
        [void]$sb.AppendLine("# Minting is refused unless BOTH hold: this tool is invoked through lam-console.ps1's")
        [void]$sb.AppendLine("# VERIFIED PATH -- the console previews these exact bytes, collects a SECURE-DESKTOP credential, and mints")
        [void]$sb.AppendLine("# an in-process token this tool checks before it writes -- AND none of the four session conditions")
        [void]$sb.AppendLine("# (LAM_DISPATCH, the harness environment, non-interactivity, hook invocation) fires. The guard's mint")
        [void]$sb.AppendLine("# tripwire is a further layer. The operator_credential line below is the LABEL THE MINTING")
        [void]$sb.AppendLine("# CALLER DECLARED -- a record, not evidence of how this mint was authorized: in-process code declares either value.")
        [void]$sb.AppendLine("kind: $Kind")
        # WHAT CLASS OF HUMAN ACT THIS IS, written adjacent to the kind
        # it derives from so the two are never read apart. `build-authorization` (push, dispatch) is
        # a human authorizing an irreversible effect; `governance` (supersession, amendment-material,
        # witness-attested, completion-acceptance, reclose, halt-ruling) is a human ruling on the record. The
        # zero-paste attestation counts the first class only and enumerates the second on its face.
        [void]$sb.AppendLine("gate_class: $gateClass")
        [void]$sb.AppendLine("id: $Id")
        [void]$sb.AppendLine("push_id: $Kind-$Id")
        [void]$sb.AppendLine("binds: $Binds")
        # ADDED, NOT SUBSTITUTED. `binds` keeps recording the value exactly as the operator gave it:
        # consumers compare `binds_sha256` (mission-dispatch.ps1:458) and a ruling freezes existing
        # fields as immutable history. What was missing was any way to tell WHICH file of that name
        # was hashed, so the resolved path is recorded beside it rather than in place of it.
        #
        # THIS FIELD IS A RECORD, NOT AN INPUT TO ANY CHECK, and it says so because an independent
        # reader counted its readers and found none (V-1 round 15, a WP-4 finding). The defect class is a field that
        # implies a check which does not happen; this one implies no check. It states which file was
        # hashed, in the same category as `authorized_by`, `host` and `created_at` -- none of which
        # has a code reader either, and none of which is a defect. Consumers deliberately RE-DERIVE
        # the path rather than trust the artifact's own word about itself (instrument-WP-6's S-4 (b)
        # says so at its own call site), and that is the right instinct on an audit artifact. What
        # was missing was the field declaring which of the two it is.
        # SINGLE-QUOTED: in PowerShell a backslash escapes nothing, so \" inside a double-quoted
        # string ENDS it. This line was authored that way and produced 8 parse errors -- caught by
        # the parse check before it shipped, which is the only reason it is a footnote and not a
        # round-16 finding. The text is static, so it needs no interpolation.
        [void]$sb.AppendLine('binds_resolved_note: "RECORD, not an input: the absolute path this mint actually hashed. Consumers re-derive rather than trust it."')
        [void]$sb.AppendLine("binds_resolved: $bindsResolved")
        [void]$sb.AppendLine("binds_sha256: $bindsSha")
        # A supersession gate names the dispatch it RETIRES, explicitly. `id` alone would carry it
        # by convention, and a convention is not a field a consumer can check.
        if ($Kind -eq 'supersession') { [void]$sb.AppendLine("retires_dispatch: $Id") }
        # A HALT RULING NAMES THE HALT IT ANSWERS AS A FIELD, NOT ONLY BY CONVENTION:
        # the evaluator requires halt_id to equal the HALT's BaseName, so a real gate copied to another
        # HALT's canonical path answers nothing. And the operator's words ride here -- see -Ruling.
        if ($Kind -eq 'halt-ruling') {
            [void]$sb.AppendLine("halt_id: $haltRulingBase")
            $rulingWords = if ($Ruling) { ConvertTo-LamOneLineYamlQuoted -Text $Ruling } else { '' }
            if (-not $rulingWords) { $rulingWords = $script:LamNoRulingText }
            [void]$sb.AppendLine("ruling: `"$rulingWords`"")
        }
        if ($tip) { [void]$sb.AppendLine("authorized_tip_sha: $tip") }
        # THE OTHER TWO THIRDS OF THE TRIPLE. Read from the repository ONCE, here, at the moment a
        # human approves -- and then never read from configuration again by anybody.
        if ($Kind -eq 'push') {
            $declaredUrl = $OriginUrl
            if (-not $declaredUrl) {
                $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
                try {
                    # THE PUSH URL, NOT THE FETCH URL (V-1 round 14, a WP-4 finding). `get-url` without
                    # `--push` returns `remote.origin.url`; git PUSHES to `remote.origin.pushurl`
                    # when that is set. The gate then declared a URL git would never contact, so the
                    # decider's comparison against the real remote failed and the origin leg asked a
                    # remote that could never hold the sha -- an authorization incapable of
                    # authorizing anything, minted silently. `--push` falls back to `url` when no
                    # pushurl is set, so the ordinary case is unchanged.
                    #
                    # Reading config HERE is what the push-gate amendment permits, and only here: this is the
                    # moment a human approves, and the value is DECLARED into the artifact. What the
                    # amendment forbids is a CONSUMER re-reading config later, which none now does.
                    $u = & git -C $MissionRoot remote get-url --push origin 2>&1
                    if ($LASTEXITCODE -eq 0) { $declaredUrl = ("$u").Trim() }
                } finally { $ErrorActionPreference = $prevEap }
            }
            $declaredRef = $RemoteRef
            if (-not $declaredRef) {
                $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
                try {
                    $b = & git -C $MissionRoot rev-parse --abbrev-ref HEAD 2>&1
                    if ($LASTEXITCODE -eq 0 -and ("$b").Trim() -and ("$b").Trim() -ne 'HEAD') {
                        $declaredRef = 'refs/heads/' + ("$b").Trim()
                    }
                } finally { $ErrorActionPreference = $prevEap }
            }
            # A PUSH GATE THAT DECLARES NO ORIGIN CANNOT BE CHECKED, so it is not written. Refusing
            # to mint is the fail-closed direction: an artifact that looks like an authorization but
            # cannot support the guarantee is worse than no artifact, because it reads as one.
            if (-not $declaredUrl) {
                Write-Output "mission-gate: REFUSING to mint a push gate with no declared origin URL."
                Write-Output "  Amendment 20 binds a push gate to (origin URL, ref, sha). The URL could not be derived"
                Write-Output "  from '$MissionRoot' and none was supplied. Pass -OriginUrl explicitly."
                exit 2
            }
            if (-not $declaredRef) {
                Write-Output "mission-gate: REFUSING to mint a push gate with no declared remote ref."
                Write-Output "  Pass -RemoteRef explicitly (for example refs/heads/main)."
                exit 2
            }
            # THE TIP THE DECLARED ORIGIN HELD AT THIS MOMENT (operator ruling (i)):
            # "The mint records origin_tip_at_mint; earlier gates settle with consumed_origin_before
            # 'not observed at mint'."
            #
            # ASKED OF THE GATE'S OWN DECLARED URL -- never the remote NAME `origin`, never
            # remote.origin.url. That is the entire point of the gate's declared triple: round 12
            # repointed remote.origin.url at a decoy bare repo and made S-4 report PASS while the real
            # origin held an unauthorized commit. A field that re-read configuration here would
            # reintroduce that same hole one field further on. $declaredUrl and $declaredRef are
            # settled above and both push refusals have already run, so this reads what the artifact
            # is about to declare, not what the repository happens to be configured with.
            #
            # A FAILURE TO OBSERVE DOES NOT REFUSE THE MINT, AND THAT IS A DECISION, STATED. A human is
            # approving a publication; this observation is a RECORD of the world, not a precondition on
            # the act. Refusing here would put an unreachable remote between an operator and their own
            # authorization, and would make the gate's availability depend on the very origin the gate
            # exists to constrain. So all three outcomes mint, and the artifact says which one happened.
            #
            # $LASTEXITCODE IS CHECKED, AND THAT IS NOT DECORATION. This file and
            # lam-verify-admission.ps1 both carry recorded fail-open bugs from exactly this omission --
            # an unchecked git return code that FAILED OPEN, toward admission, on the one condition
            # whose job is to notice drift. Unchecked here, git's error text would be read as output,
            # no sha would be found in it, and the artifact would quietly record REF-NOT-PRESENT for an
            # origin nobody ever reached. $ErrorActionPreference is saved and restored around the call
            # exactly as the -OriginUrl fallback above does it: under 'Stop' a native exe writing to
            # stderr is a fatal NativeCommandError and 2>$null does not help, and the unreachable case
            # writes to stderr by definition.
            # THE UNOBSERVED RECORD IS THE STARTING VALUE, so every path that does not positively
            # establish something else lands on the honest one. $lsCode is seeded NON-ZERO for the same
            # reason: a git that fails to launch must not inherit a stale zero from an earlier command
            # and be read as an origin that answered.
            $originTip = $script:LamOriginTipUnobservedText
            $lsOut  = ''
            $lsCode = -1
            $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try {
                $lsOut = & git -C $MissionRoot ls-remote $declaredUrl $declaredRef 2>&1
                $lsCode = $LASTEXITCODE
                if ($lsCode -eq 0) {
                    # ORIGIN ANSWERED. From here the only open question is whether it holds the ref, so
                    # the default becomes the ABSENT record rather than the UNOBSERVED one. An empty
                    # answer from a reachable origin is a real observation and is recorded as one.
                    #
                    # ls-remote takes its argument as a PATTERN, not a name, so the match is made exact
                    # here: a line answers when its ref name IS $declaredRef. The record uses fully
                    # qualified refs throughout -- the -RemoteRef fallback above builds
                    # refs/heads/<branch> -- so that is the ordinary path. A declared ref that is not
                    # fully qualified still resolves, but only when git returned EXACTLY ONE line: one
                    # line is determinate, several with no exact name are not, and for those the
                    # artifact says origin holds no ref of that name, which is true.
                    $originTip = $script:LamOriginTipRefAbsentText
                    $lsRows = New-Object System.Collections.Generic.List[object]
                    foreach ($lsLine in @($lsOut)) {
                        $lsMatch = [regex]::Match(("$lsLine"), '\A([0-9a-fA-F]{40})\s+(\S+)\s*\z')
                        if ($lsMatch.Success) { $lsRows.Add($lsMatch) }
                    }
                    $lsExact = @($lsRows | Where-Object { $_.Groups[2].Value -ceq $declaredRef })
                    if ($lsExact.Count -eq 1) { $originTip = $lsExact[0].Groups[1].Value.ToLowerInvariant() }
                    elseif ($lsRows.Count -eq 1) { $originTip = $lsRows[0].Groups[1].Value.ToLowerInvariant() }
                }
            } finally { $ErrorActionPreference = $prevEap }
            [void]$sb.AppendLine("origin_url: $declaredUrl")
            [void]$sb.AppendLine("remote_ref: $declaredRef")
            [void]$sb.AppendLine("origin_binding_note: `"Amendment 20: consumers read THIS url, never remote.origin.url. A repointed remote does not move the authorization.`"")
            # PART OF THE COMPOSED BYTES, so the console's PREVIEW shows this beside everything else
            # the operator is about to authorize, and the act digest covers it. A value the human
            # never saw is not part of what the human approved.
            [void]$sb.AppendLine("origin_tip_at_mint: $originTip")
            [void]$sb.AppendLine("origin_tip_note: `"RECORD, not an input: nothing in this tool reads this value. It is what ls-remote reported for remote_ref, asked of the url above and never of remote.origin.url, at the instant these bytes were composed; its one consumer is the settle verb, which reads it as consumed_origin_before. Compose and mint observe origin independently, so if origin moved between the preview and the confirm these bytes differ and the mint refuses with an act digest mismatch -- that refusal is the digest working, not a tamper.`"")
        }
        [void]$sb.AppendLine("authorized_by: $env:USERNAME")
        [void]$sb.AppendLine("host: $env:COMPUTERNAME")
        # THE CREDENTIAL LABEL THE MINTING CALLER DECLARED. NOT a record of how
        # this mint was authorized, and it must not be read as one: a session validator DROVE three
        # routes that mint with no credential step at all -- in-process code in a console where the
        # four session conditions do not fire -- and each artifact carried whatever label had been
        # declared, secure-desktop-credui included. What the field is good for is telling a scratch
        # fixture's gate from an operator's act. Part of the composed bytes, so the act digest covers
        # the declared label and the preview is byte-exact.
        [void]$sb.AppendLine("operator_credential: $script:LamCredentialLabel")
        [void]$sb.AppendLine("created_at: $($now.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture))")
        # LIFECYCLE IS PER-KIND, and conflating them was a defect. A `push` gate MUST expire and MUST
        # be single-use: a standing publish capability is the thing ADR-033 exists to abolish. A
        # `supersession` gate is not a capability at all -- it is a RECORDED RULING, a historical
        # fact consulted afresh by every later dispatch. It does not get "used up", and it does not
        # stop being true after an hour. Given expiry it would have to be re-ratified hourly forever,
        # and given single_use the first dispatch to read it would spend it.
        # WITHDRAWAL IS STILL AVAILABLE, and is the right mechanism for a ruling: `revoke`.
        if ($Kind -eq 'supersession') {
            [void]$sb.AppendLine("permanence: until-revoked")
            [void]$sb.AppendLine("lifecycle_note: `"A ratified supersession is a recorded ruling, not a capability. It neither expires nor is consumed; revoke it to withdraw it.`"")
        } elseif ($Kind -eq 'completion-acceptance') {
            # THE SAME LIFECYCLE AS A SUPERSESSION, FOR THE SAME REASON. The goal
            # evaluator consults this gate on every Stop; single-use would spend it on the first
            # evaluation and expiry would un-accept the package an hour later. It binds ONE file by
            # hash, so editing that file voids it without anyone revoking anything.
            #
            # THE NOTE STOPPED ASSERTING TWO THINGS IT COULD NOT KNOW (operator
            # ruling). It said, on EVERY artifact of this kind:
            #   (i)  "a REFUTED package's registered residuals" -- the verdict of the package. This
            #        writer never sees a verdict. It sees -Kind, -Id and -Binds. The kind was used
            #        twice over a MET package (reclose-44, reclose-45), so the assertion was false on
            #        two of the three artifacts that exist.
            #   (ii) "it binds docs/framework/LAM-RESIDUALS.md by sha256" -- a LITERAL PATH, written
            #        onto an artifact whose `binds` field four lines above it may say something else
            #        entirely. reclose-44 and -45 bind a file under .mission-runtime/lam/close/ and
            #        say LAM-RESIDUALS.md on their own face. An audit artifact naming a file it does
            #        not bind is the misleading-face shape one layer out: the face implies a check on a file no
            #        consumer ever looks at.
            # The cure is to the WRITER. The three artifacts already on disk are IMMUTABLE audit
            # records (by ruling) and are NOT edited here; they are addressed in prose, in the ledger
            # entry that records this row, and by `reclose` existing so the borrowing stops.
            #
            # WHAT THE NOTE MAY SAY IS BOUNDED BY WHAT THIS WRITER KNOWS. It knows the kind, it knows
            # the lifecycle it is about to write, and it knows that `binds`/`binds_sha256` sit on the
            # same artifact. So it says THAT, and points at the field rather than restating a path.
            [void]$sb.AppendLine("permanence: until-revoked")
            [void]$sb.AppendLine("lifecycle_note: `"A completion acceptance is a recorded ruling accepting ONE package on the strength of its registered residuals. It neither expires nor is consumed; it binds by sha256 exactly the file named in this artifact's own binds field, so editing that file voids it. Revoke it to withdraw it.`"")
        } elseif ($Kind -eq 'reclose') {
            # THE SEVENTH KIND. A re-closure gate is a recorded ruling, not a
            # capability: mission-reclose.ps1 consults it before every Reworking -> Complete, and
            # single_use would spend it on a run that then refused for an unrelated reason while
            # expiry would un-authorize a re-closure the operator had already ruled on.
            #
            # WHAT IT BINDS IS NOT A GUESS. reclose-44 and reclose-45 -- the two artifacts that
            # actually exist for this act -- both bind the re-closure's ledger content file, the file
            # mission-reclose.ps1 receives as -LedgerContentFile and appends to the ledger verbatim.
            # That is the right thing to bind, because it is the only artifact of a re-closure that
            # carries the operator's own words, and the consumer RE-DERIVES its sha256 at run time
            # rather than trusting this record. The note therefore names it, and the name is true of
            # every reclose gate the tool will write, because the consumer refuses any other file.
            [void]$sb.AppendLine("permanence: until-revoked")
            # THE NOTE RESTATED (with the presence clause the operator ruled in at
            # Q2 of 2026-10-16): settle may now record the use of a reclose gate, after the re-closure it
            # authorized has been committed. The absence of that stamp refuses nothing; its presence spends the
            # gate, and mission-reclose refuses a stamped gate. T-18's two phrases are kept, and so is the one
            # double-quoted line its reader takes.
            [void]$sb.AppendLine("lifecycle_note: `"A reclose gate is a recorded ruling authorizing ONE Reworking -> Complete transition (ADR-029). It neither expires; its use may be recorded by settle; the absence of the stamp refuses nothing, and the presence of the stamp authorizes no further transition, which mission-reclose refuses; it binds by sha256 the re-closure's ledger content file named in this artifact's own binds field, and mission-reclose re-derives that digest and refuses unless it matches, so editing that file voids it. Revoke it to withdraw it.`"")
        } elseif ($Kind -eq 'halt-ruling') {
            # THE EIGHTH KIND. A halt ruling is a recorded ruling, not a capability:
            # the goal evaluator consults it on every Stop, so single_use would spend it on the first
            # evaluation and expiry would re-open an answered HALT an hour later. What it binds is the
            # HALT file itself, and the note says what the evaluator does with that: Test-HaltRuled
            # re-derives the HALT's sha256 on every run and reads the HALT OPEN unless it matches.
            [void]$sb.AppendLine("permanence: until-revoked")
            [void]$sb.AppendLine("lifecycle_note: `"A halt ruling is a recorded ruling ANSWERING ONE HALT. It binds by sha256 exactly the HALT file named in this artifact's own binds field; any edit to that HALT voids it and the HALT reads OPEN again until the operator reapproves. It neither expires nor is consumed. Revoke it to withdraw it.`"")
        } else {
            [void]$sb.AppendLine("expires_at: $($now.AddMinutes($ExpiresMinutes).ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture))")
            [void]$sb.AppendLine("single_use: true")
        }
        [void]$sb.AppendLine("consumed_at: null")

        # =========================================================================================
        # PRECOMPUTE THE ORDERED WRITES, NO MUTATION YET. The exact bytes of every
        # file the mint would write are built here so the compose-or-token checkpoint below can emit
        # them (compose) or digest them (mint). The reapprove next-free-N scan is READ-ONLY and moved
        # up from the mutating region for the same reason.
        # =========================================================================================
        $newArtifactBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($sb.ToString())
        $writes = New-Object System.Collections.Generic.List[object]
        $revPath = $null
        $revokedBytes = $null
        if ($isReapprove) {
            # THE NEXT FREE N IS max(existing) + 1, NOT THE LOWEST GAP, AND THAT IS A DECISION.
            # Filling a gap would put a NEWER revocation at an OLDER number and silently reorder the
            # register: a reader walking .revoked-1, -2, -3 expects chronology, and one dispatch gate
            # has three of them. A hand-made hole stays a hole, visibly.
            $revBase = "$Kind-$Id"
            $maxN = 0
            $revRe = '^' + [regex]::Escape($revBase) + '\.revoked-(\d+)\.yaml$'
            foreach ($f in @(Get-ChildItem -LiteralPath $gatesDir -Filter "$revBase.revoked-*.yaml" -ErrorAction SilentlyContinue)) {
                if ($f.Name -match $revRe) {
                    $n = [int]$Matches[1]
                    if ($n -gt $maxN) { $maxN = $n }
                }
            }
            $nextN = $maxN + 1
            $revPath = Join-Path $gatesDir "$revBase.revoked-$nextN.yaml"
            # AND THE CHOSEN NAME IS CHECKED, not merely computed. A DIRECTORY at that name, or a
            # file the pattern above did not match, would make the move throw or -- worse -- land the
            # artifact inside it. Walk forward until the name is genuinely free.
            while (Test-Path -LiteralPath $revPath) {
                $nextN++
                $revPath = Join-Path $gatesDir "$revBase.revoked-$nextN.yaml"
            }
            # THE PRIOR'S RESTING BYTES: its OWN bytes with a revocation block appended, unless it was
            # already revoked, in which case it moves unchanged (double-stamping would record two acts).
            # The stamp is pinned to -ComposedAt so compose and mint agree byte for byte.
            # THE UNCHANGED MOVE IS DIGESTED FROM THE PRIOR'S RAW BYTES (found in review): Move-Item carries the
            # file byte for byte, including a UTF-8 BOM that ReadAllText would have dropped. The stamped
            # branch below is WRITTEN with WriteAllBytes from exactly the bytes it digests, so it needs no
            # such care.
            if ($priorState.revoked) {
                $revokedBytes = $priorRawBytes
            } else {
                $revokedBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($priorText.TrimEnd() + "`n" + (Get-RevocationStamp -Why $Reason -At $script:LamComposedAtStr))
            }
            $writes.Add([pscustomobject]@{ name = (Split-Path -Leaf $revPath); bytes = $revokedBytes })
        }
        $writes.Add([pscustomobject]@{ name = "$Kind-$Id.yaml"; bytes = $newArtifactBytes })

        # COMPOSE-OR-TOKEN CHECKPOINT. Under -ComposeOnly this emits the preview lines and exits 0;
        # otherwise it validates the console token's act digest against these exact ordered writes and
        # marks the token used, before anything on disk moves.
        $approveDigest = Get-LamActDigest -Writes @($writes.ToArray())
        Invoke-LamGateComposeOrRefuse -Verb $Command -Writes @($writes.ToArray()) -BindsPath $bindsResolved -BindsSha $bindsSha -ActDigest $approveDigest

        # =========================================================================================
        # THE ONLY MUTATING REGION. EVERYTHING ABOVE CAN REFUSE AND
        # NOTHING ABOVE HAS TOUCHED THE DISK. The gates directory is created HERE, past the checkpoint,
        # so -ComposeOnly and a refused mint leave no directory behind.
        #
        # ATOMIC IN THE FAIL-CLOSED DIRECTION. The failure that must not happen is the one the manual
        # dance produces every time it is interrupted: the prior revoked and renamed, and NOTHING at
        # the canonical path -- an id with no authorization and an operator who has to reconstruct
        # which half ran. So the ordering is refuse-then-mutate, and the mutation is wrapped: if any
        # of the three steps throws, the prior is put back at its original name with its ORIGINAL
        # BYTES and the command refuses. The restore is the second line; the ordering is the first.
        # =========================================================================================
        if (-not (Test-Path -LiteralPath $gatesDir)) { New-Item -ItemType Directory -Path $gatesDir -Force | Out-Null }
        if ($isReapprove) {
            # THE ROLLBACK RESTORES AND COMPARES BYTES, NOT TEXT (a re-review finding). The prior's
            # bytes were captured with ReadAllBytes above ($priorRawBytes), before anything on disk moved.
            # The rollback used to compare ReadAllText against the prior's text and rewrite it with a
            # BOM-less WriteAllText -- ReadAllText strips a UTF-8 byte-order mark -- so a prior saved WITH a
            # BOM whose re-mint failed after its stamp landed came back WITHOUT the BOM while this tool
            # printed "original bytes". Both restore blocks below call this one function, which reads the
            # file's bytes, rewrites them from $priorRawBytes only when they differ, and reports RESTORED
            # only when a fresh ReadAllBytes is byte-for-byte equal to them.
            function Test-LamReapproveBytesEqual {
                param([byte[]]$Left, [byte[]]$Right)
                if ($null -eq $Left -or $null -eq $Right) { return $false }
                if ($Left.Length -ne $Right.Length) { return $false }
                return [System.Linq.Enumerable]::SequenceEqual([byte[]]$Left, [byte[]]$Right)
            }
            function Restore-LamReapprovePriorBytes {
                param([string]$Path, [byte[]]$Bytes)
                if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
                $onDisk = [System.IO.File]::ReadAllBytes($Path)
                if (-not (Test-LamReapproveBytesEqual -Left $onDisk -Right $Bytes)) {
                    [System.IO.File]::WriteAllBytes($Path, $Bytes)
                }
                $onDisk = [System.IO.File]::ReadAllBytes($Path)
                return (Test-LamReapproveBytesEqual -Left $onDisk -Right $Bytes)
            }
            $moved = $false
            try {
                Move-Item -LiteralPath $p -Destination $revPath -ErrorAction Stop
                $moved = $true
                # STAMP THE REVOCATION AT THE ARTIFACT'S RESTING NAME, and only if it is not already
                # revoked: an operator who ran `revoke` by hand and stopped before the rename is
                # finishing that dance here, and double-stamping would put two revoked_at lines on
                # one audit artifact. The bytes were precomputed above; here they are only written.
                if (-not $priorState.revoked) {
                    [System.IO.File]::WriteAllBytes($revPath, $revokedBytes)
                }
            } catch {
                $restored = $false
                $restoreNote = ''
                try {
                    if ($moved -and (Test-Path -LiteralPath $revPath) -and (-not (Test-Path -LiteralPath $p))) {
                        Move-Item -LiteralPath $revPath -Destination $p -ErrorAction Stop
                    }
                    # BYTE-EXACT, not merely back. If the stamp landed (or truncated the file) before the
                    # failure, the prior would otherwise return revoked, or empty, for an act that did not
                    # happen -- and compared as text, a BOM would be lost while RESTORED was printed.
                    $restored = Restore-LamReapprovePriorBytes -Path $p -Bytes $priorRawBytes
                } catch { $restoreNote = $_.Exception.Message }
                Write-Output "mission-gate: REFUSED -- reapprove could not set the prior aside, and NOTHING was minted."
                Write-Output "  prior    : $p"
                Write-Output "  target   : $revPath"
                Write-Output "  $($_.Exception.Message)"
                if ($restored) {
                    Write-Output "  RESTORED : the prior stands at its original name with its original bytes; no new gate was written."
                } else {
                    Write-Output "  NOT FULLY RESTORED -- inspect both names by hand before doing anything else. $restoreNote"
                }
                exit 2
            }
        }

        try {
            [System.IO.File]::WriteAllBytes($p, $newArtifactBytes)
        } catch {
            if ($isReapprove) {
                $restored = $false
                try {
                    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
                    if (Test-Path -LiteralPath $revPath) { Move-Item -LiteralPath $revPath -Destination $p -ErrorAction Stop }
                    # The same byte restore as the block above: the stamped bytes that came back from the
                    # .revoked-N name are rewritten to the prior's captured bytes, a BOM included.
                    $restored = Restore-LamReapprovePriorBytes -Path $p -Bytes $priorRawBytes
                } catch { }
                Write-Output "mission-gate: REFUSED -- the new gate could not be written, and the re-mint was rolled back."
                Write-Output "  $($_.Exception.Message)"
                if ($restored) {
                    Write-Output "  RESTORED : the prior stands at its original name with its original bytes."
                } else {
                    Write-Output "  NOT FULLY RESTORED -- inspect $p and $revPath by hand before doing anything else."
                }
                exit 2
            }
            Write-Output "mission-gate: REFUSING -- the gate artifact could not be written to $p."
            Write-Output "  $($_.Exception.Message)"
            exit 2
        }

        # UI-1 S1: the mint has landed -- gate_minted; a halt-ruling ANSWERS the HALT it binds.
        if ($Kind -eq 'halt-ruling') {
            $haltBound = if ([System.IO.Path]::IsPathRooted($Binds)) { $Binds } else { Join-Path $MissionRoot $Binds }
            Send-LamGateTelemetry -Kind 'gate_minted' -GatePath $p -HaltKind 'halt_resolved' -HaltPath $haltBound -Resolution 'ANSWERED' -Snapshot
        } else {
            Send-LamGateTelemetry -Kind 'gate_minted' -GatePath $p -Snapshot
        }

        if ($isReapprove) {
            Write-Output "mission-gate: REAPPROVED $Kind-$Id -- one act: revoke, rename, approve"
            Write-Output "  prior    : $revPath"
            if ($priorState.revoked) {
                Write-Output "  NOTE: the prior was ALREADY revoked before this run; its existing revoked_at stands and was not re-stamped."
            } else {
                Write-Output "  reason   : $(if ($Reason) { $Reason } else { $script:LamNoReasonText })"
            }
            if ($priorBindsSha -and ($priorBindsSha -eq $bindsSha)) {
                Write-Output "  bytes    : UNCHANGED -- the bound file hashes the same as it did for the prior ($bindsSha)."
                Write-Output "             That is lawful and is not an error, but a re-mint over identical bytes re-issues"
                Write-Output "             an authorization nothing about the subject required. Check that you meant it."
            } elseif ($priorBindsSha) {
                Write-Output "  bytes    : MOVED -- $priorBindsSha -> $bindsSha (the same file, new content: what a re-mint is for)."
            }
        } else {
            Write-Output "mission-gate: approved $Kind-$Id"
        }
        Write-Output "  artifact : $p"
        Write-Output "  binds    : $Binds ($bindsSha)"
        if ($tip) { Write-Output "  tip      : $tip" }
        if ($Kind -eq 'push') {
            Write-Output "  origin   : $declaredUrl"
            Write-Output "  ref      : $declaredRef"
        }
        Write-Output "  by       : $env:USERNAME on $env:COMPUTERNAME"
        Write-Output "  NOTE: operator browser confirmation of the origin tip after a push remains standing law."
        exit 0
    }
}
