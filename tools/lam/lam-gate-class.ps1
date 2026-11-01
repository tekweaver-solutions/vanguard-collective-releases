#Requires -Version 5.1
<#
.SYNOPSIS
  GATE CLASSIFICATION -- the single definition of what KIND of human act a gate artifact records.
  (Settled by an operator ruling.)

.DESCRIPTION
  THE PROBLEM THIS EXISTS TO SETTLE. The zero-paste attestation asserts "exactly one operator act
  across S-1..S-5, and it is the push gate", and it counts GATE ARTIFACTS as its proxy because a
  gate is the one thing an agent provably cannot mint (T-3 hard-denies every agent role from
  writing under the mission gates directory). Ruling A2 then required supersession markers to be
  ratified by operator-placed gates, and two of those now exist. The proxy therefore read 3 where
  the attestation says 1 -- and NEITHER side was wrong.

  THE RULING. A supersession ratification is a GOVERNANCE act: a human adjudicating a HALT, ruling
  on a record that already exists. A push is a BUILD-AUTHORIZATION act: a human authorizing an
  irreversible effect on the world. The attestation is about the second kind and always was. So
  gates are classified, the attestation counts build-authorization acts only, and the governance
  acts are EXCLUDED BY DECLARED CLASS AND ENUMERATED ON THE ATTESTATION'S OWN FACE -- never
  silently dropped, which would be the same defect one layer down.

  WHY THE MAP LIVES HERE AND NOWHERE ELSE. Two consumers share this predicate: `mission-gate.ps1`
  WRITES the class onto every gate it creates, and the WP-6 instrument READS it to count. This
  build has already been bitten once by a predicate that existed twice and whose copies disagreed
  inside a single run (the `halt_absent` regex, ruling D). One file, one map, both consumers.

  READ-TIME CLASSIFICATION IS THE PRIMARY PATH, DELIBERATELY. Gate artifacts already on disk carry
  no `gate_class` field, and they are agent-unwritable by construction -- so backfilling one would
  need an operator migration over artifacts whose whole value is that nobody edits them after the
  fact. `kind` is already on every gate and is what the class is derived FROM, so a reader derives
  the class rather than requiring it. The written field is a convenience and a cross-check, not
  the source of truth.

  NOTHING IS EVER SILENTLY EXCLUDED. A kind this map does not know classifies as `unknown`, and a
  gate whose written `gate_class` disagrees with its kind classifies as `conflict`. Both are
  FAILURES for a counting consumer, never quiet omissions -- a classifier that dropped what it did
  not recognise would let a new gate kind slip past the attestation unmentioned.
#>

# THE MAP. Keys are the closed kind vocabulary of mission-gate.ps1's -Kind ValidateSet.
#   build-authorization : the human authorizes an irreversible effect the build is about to have.
#   governance          : the human rules on the record -- adjudicating, ratifying, attesting.
$script:LamGateClassByKind = [ordered]@{
    'push'               = 'build-authorization'   # publishes to origin; the archetypal irreversible
    'dispatch'           = 'build-authorization'   # authorizes a dispatch to run
    'supersession'       = 'governance'            # ratifies a marker; a recorded ruling (Ruling A2)
    'amendment-material' = 'governance'            # adjudicates contract material
    'witness-attested'   = 'governance'            # attests to a record
    # THE SIXTH KIND (the operator's stopping rule). An operator accepting a
    # REFUTED package on the strength of its registered residuals is ruling on a record, not
    # authorizing an effect: governance, excluded from the zero-paste count by class and enumerated
    # on the attestation's face like the other three.
    'completion-acceptance' = 'governance'         # accepts a package with registered residuals
    # THE SEVENTH KIND (an operator ruling). A re-closure gate
    # authorizes ONE Reworking -> Complete transition (ADR-029) by binding the re-closure's LEDGER
    # CONTENT FILE by sha256. It is governance for the same reason the two above are: the operator
    # is ruling on a record -- the mission's own completion chain -- not authorizing an irreversible
    # effect on the world. The push that later carries the reclose commit has its own push gate, and
    # that one is the build-authorization act.
    #
    # WHY IT IS ITS OWN KIND RATHER THAN MORE completion-acceptance. reclose-44 and reclose-45 were
    # minted as `completion-acceptance` because no better kind existed, and the ledger entry that
    # gated the first of them said so on its face -- "the operator chose the kind, and the stretch is
    # named rather than smoothed". The stretch was real in two directions at once: the kind's own
    # lifecycle text asserts a REFUTED package (a reclose's package is MET) and asserts it binds
    # docs/framework/LAM-RESIDUALS.md (a reclose binds a ledger content file under
    # .mission-runtime). A kind whose text is false of most of its instances cannot be read by any
    # consumer, which is why no consumer read it: mission-reclose.ps1 read NO gate at all.
    'reclose'            = 'governance'            # authorizes ONE Reworking -> Complete (ADR-029)
    # THE EIGHTH KIND (batch 4 item 3, operator ruling). A halt-ruling gate is the
    # operator's recorded answer to ONE HALT: it binds that HALT file's bytes by sha256 and names it
    # in `halt_id`, and the goal evaluator's Test-HaltRuled reads a HALT as ANSWERED only against a
    # live one. It is governance for the reason every kind above it is -- the operator is ruling on a
    # record, the HALT, not authorizing an effect on the world -- so it is excluded from the
    # zero-paste count by class and enumerated on the attestation's face like the others.
    #
    # WHY IT IS ITS OWN KIND. Before it, a HALT was answered by a `**Status:** ANSWERED` line the seat
    # wrote into the HALT file itself, and that file is agent-writable on every layer: one Edit flipped
    # the goal verdict. Borrowing an existing kind would repeat reclose's lesson above -- a kind whose
    # own lifecycle text is false of its instances cannot be read by any consumer.
    'halt-ruling'        = 'governance'            # answers ONE HALT by binding its bytes
}

function Get-LamGateClassMap {
    <# The map itself, for a consumer that wants to print or enumerate it. #>
    return $script:LamGateClassByKind
}

function Resolve-LamGateKind {
    <#
    .SYNOPSIS
      kind text -> the map's CANONICAL key, ORDINALLY, or '' when it is not one of them.
      THE ONE CASE RULE: A GATE KIND IS CASE-SIGNIFICANT, and this is the only place that says so.

    .DESCRIPTION
      THE RULING THAT SETTLED IT, VERBATIM (operator, round 3, answering V-1 on a review finding): "One
      case rule, applied by the shared reader and nowhere else: a non-canonical kind is REFUSED by
      the admission, by settle and by the decider alike."

      WHY THE RULE HAD NOWHERE TO LIVE UNTIL NOW, WHICH IS THE ACTUAL ROOT. THE MAP ABOVE IS AN
      `[ordered]@{}` -- a System.Collections.Specialized.OrderedDictionary -- AND ITS `.Contains()`
      FOLDS CASE. Driven: `Get-LamGateClassForKind -Kind 'PUSH'` returned a real class, and so did
      'Push', 'pUsH' and 'DISPATCH'; an ordinal-comparer OrderedDictionary, built as a control,
      answered False for 'PUSH'. So this file -- the one place the kind vocabulary is defined -- HAD
      NO CASE OPINION AT ALL, and there was nothing for a caller to ask. `Get-LamGateClassForKind`
      could not serve as that predicate either, because it answers with a CLASS and
      `build-authorization` cannot tell `push` from `dispatch`: a consumer that delegated to it
      would lose the ability to distinguish two kinds it must distinguish. That ABSENCE, and not any
      one caller's carelessness, is why the rule was restated at FOURTEEN sites --
      (**ERRATUM, ROUND 4: this read ELEVEN while the list below it names FOURTEEN.** Counted:
      thirteen locators plus the next-gen decider. It is the fifteen-site census MINUS this
      file's own map lookup, which is the ROOT rather than a restatement of it. Prose carrying
      a figure its own list contradicts is the shape a review finding named, committed here in
      the very docblock that cures the defect that finding was about. Round-3 validator, a review finding.) --
      lam-verify-admission.ps1:608, mission-gate.ps1:582/951/1029/1050/1449/1580,
      mission-goal-check.ps1:444/2088/2191, mission-dispatch.ps1:1559,
      record-origin-attestation.ps1:235, mission-reclose.ps1:133 and the next-gen decider -- and why
      the copies disagreed with each other, some ordinal and some folding.

      THE CASE TRAVELS; ONLY THE LOOKUP EVER LOST IT. `Get-LamGateClassForArtifact` captures the
      kind VERBATIM (`^kind:[ \t]*(\S+)`), so an artifact's own spelling reaches every consumer
      intact. That is what made the defect reachable rather than theoretical: `mission-gate approve
      -Kind PUSH` classified build-authorization through the folding lookup and minted a literal
      `kind: PUSH` artifact at the filename `PUSH-<id>.yaml` -- `[ValidateSet]` validates
      case-insensitively and does NOT normalise, and nothing in that file assigns to $Kind -- and
      `settle -Kind push` then agreed with that same artifact, because its own comparison folded too.
      One artifact, two spellings, and the toolchain agreed with both.

      THE DIRECTION CHECK, MEASURED OVER THE GATES THAT ACTUALLY EXIST. All 81 gate artifacts in the
      repository of record's `.mission/gates` were read with both a folding and an ordinal reader:
      `amendment-material`=20, `completion-acceptance`=4, `dispatch`=32, `halt-ruling`=14, `push`=10,
      `witness-attested`=1; every one carries exactly ONE column-0 `kind:` line; NOT ok under the old
      reader 0; would classify `unknown` under this one 0; classification diverges 0; non-lowercase
      kinds 0. THIS CURE CHANGES THE MEANING OF NO GATE THAT EXISTS. It changes what a gate that does
      not yet exist is allowed to be, which is the only place a rule like this can act.

      ORDINAL BY `-ceq`, NOT BY A COMPARER SWAPPED INTO THE MAP. Rebuilding the map as an
      ordinal-comparer dictionary would hide the rule in a CONSTRUCTOR, where no reader of this file
      would see it and no consumer could ask about it -- the same invisibility that let the folding
      `.Contains()` stand for as long as it did. A named predicate can be called, and being callable
      is the whole point of moving the rule here.
    #>
    param([AllowNull()][string]$Kind)
    if (-not $Kind) { return '' }
    $k = $Kind.Trim()
    if (-not $k) { return '' }
    foreach ($key in @($script:LamGateClassByKind.Keys)) {
        if (([string]$key) -ceq $k) { return [string]$key }
    }
    return ''
}

function Get-LamGateKindRefusalReason {
    <#
    .SYNOPSIS
      WHY this kind text is not a gate kind, in ONE sentence -- said here so no consumer restates it.

    .DESCRIPTION
      NAMING THE CASE IS NOT COSMETIC. An operator who mistyped the case and an operator holding a
      genuinely unknown kind need DIFFERENT actions, and a bare "not in the gate-class map" tells
      them apart for neither. So when a CASE-FOLDED match exists this names both spellings and states
      the rule; when none does, it stays the sentence this file has produced since it was written --
      which is why that text survives as this one's PREFIX rather than being replaced.

      THE FOLDING COMPARISON BELOW IS DELIBERATE AND IS NOT A SECOND OPINION. It runs only after
      Resolve-LamGateKind has already refused, and it exists to DIAGNOSE the near miss, never to
      accept it. The acceptance decision is taken ordinally, once, above.
    #>
    param([AllowNull()][string]$Kind)
    if (-not $Kind) { return 'no kind was given, so there is nothing to look up' }
    $k = $Kind.Trim()
    if (-not $k) { return 'no kind was given, so there is nothing to look up' }
    if (Resolve-LamGateKind -Kind $k) { return "kind '$k' is the canonical spelling and is in the gate-class map" }
    $folded = ''
    foreach ($key in @($script:LamGateClassByKind.Keys)) {
        if (([string]$key) -eq $k) { $folded = [string]$key; break }
    }
    if ($folded) {
        return "kind '$k' is not in the gate-class map -- the map carries '$folded', and a gate kind is CASE-SIGNIFICANT"
    }
    return "kind '$k' is not in the gate-class map"
}

function Get-LamGateClassForKind {
    <#
    .SYNOPSIS
      kind -> class. Returns 'unknown' for a kind the map does not carry -- never a default.

    .DESCRIPTION
      IT RESOLVES THROUGH Resolve-LamGateKind, so the case rule is APPLIED here without being
      RESTATED here. This function used to ask `$script:LamGateClassByKind.Contains($k)` directly,
      and that call FOLDS CASE: it is the single expression a review finding is about, and every other
      site in the toolchain inherited its answer.
    #>
    param([string]$Kind)
    if (-not $Kind) { return 'unknown' }
    $canon = Resolve-LamGateKind -Kind $Kind
    if (-not $canon) { return 'unknown' }
    return [string]$script:LamGateClassByKind[$canon]
}

function Test-LamGateFieldSet {
    <#
      IS A GATE FIELD SET? ONE SPELLING, AND IT IS THE HOOK LIBRARY'S -- CHARACTER FOR CHARACTER.

      V-1 round 17, a WP-4 finding, driven. This file restated the library's test three times with
      `(?m)^\s*<field>:\s*(?!null)\S` while `Test-EvidenceGateFieldSet` uses
      `(?m)^<field>:[ \t]*(?!null\b)\S`, and the difference is not cosmetic:

        * `^\s*` accepts an INDENTED field. The library's `^` does not. So a gate carrying an
          indented `revoked_at` was reported REVOKED by `mission-gate list` while the DECIDER read it
          as not revoked and AUTHORIZED THE PUSH -- divergence in the permissive direction, which is
          the one that matters. The library's reading is the correct one: a YAML mapping's top-level
          key sits at column 0, an indented key belongs to some nested mapping, and
          `mission-gate revoke` writes at column 0 -- so no real revocation changes meaning here.
        * `\s*` after the colon spans NEWLINES under `(?m)`, so `revoked_at:` followed by a line
          break and any non-space content matched. `[ \t]*` cannot leave the line.
        * `(?!null)` also rejects `nullified`; `(?!null\b)` admits it. Smallest of the three and
          still a difference between two things called one definition.

      THE HEADER OF THIS FILE HAS CLAIMED "ONE DEFINITION, FOR EVERY CONSUMER" SINCE IT WAS WRITTEN,
      and the file was created to end a predicate that existed twice and disagreed. It then grew a
      second copy of the very thing. Naming a single definition does not make it single.

      THE DUPLICATION IS DELIBERATE AND IS NOT AN ACCIDENT OF LAZINESS: `tools/lam` must not
      dot-source the hooks library, which redefines A1 functions by design and would pull those
      redefinitions into every consumer of this file. E113 sets the price of a disclosed duplication
      -- a TEST that detects the drift -- and instrument-WP-4's T-14 pays it by driving both readers
      over the same texts, including the indented shape, and requiring identical answers.
    #>
    param([AllowNull()][string]$Text, [Parameter(Mandatory = $true)][string]$Field)
    if (-not $Text) { return $false }
    return [bool]([regex]::IsMatch($Text, '(?m)^' + [regex]::Escape($Field) + ':[ \t]*(?!null\b)\S'))
}

# THE CONSUME BLOCK -- FIVE FIELDS, ONE NAME FOR THEM, IN THE PLACE THE STATE PREDICATE LIVES.
#
# WHAT WAS WRONG, AND IT WAS WRONG IN TWO FILES AT ONCE (round 3, a review finding). Settling a push gate
# appends FIVE fields: `consumed_at` and then `consumed_origin_tip`, `consumed_ref`,
# `consumed_origin_before`, `consumed_basis`. Both guards that exist to stop a SECOND consume block
# -- mission-gate.ps1's settle and Complete-EvidencePushGate's write loop -- tested ONE of those
# five. A gate carrying the four appended fields with `consumed_at` still reading the literal
# sentinel `null` therefore passed BOTH guards, and settling it composed a second consume block
# under one `consumed_at`: verbatim "a missing record traded for an ambiguous one", which is the
# harm the hook-side comment names and was written to prevent.
#
# THE GUARD BELONGS TO THE GATE, NOT TO A FIELD. That sentence is already on disk in
# evidence-common.ps1 -- "refusing the gate whole makes it true by construction" -- written about
# the OLD guard while the SHIPPED one carried the identical gap. Naming a property does not make it
# hold; the list below is what makes it checkable, and it is a list precisely so that a SIXTH field
# is added in one place rather than remembered at two guards.
# A DISPATCH GATE'S CONSUME BLOCK IS NOT THIS LIST. The runner's stamp writes consumed_at,
# consumed_basis, consumed_manifest_sha256 and consumed_spawns; those keys and the reader that
# checks their shape are in tools/lam/lam-dispatch-gate.ps1. This list stays the push settle's five,
# so Get-LamGateState's consume_block_joined names only these five on any gate.
$script:LamConsumeBlockFields = @(
    'consumed_at',
    'consumed_origin_tip',
    'consumed_ref',
    'consumed_origin_before',
    'consumed_basis'
)

function Get-LamGateConsumeBlock {
    <#
    .SYNOPSIS
      WHICH of the five consume-block fields are SET on this gate text. ONE definition.

    .DESCRIPTION
      IT RETURNS AN OBJECT, NOT AN ARRAY, AND THAT IS DELIBERATE. A PowerShell function returning a
      bare array is unrolled by assignment when it has one element and double-wrapped by `@(...)`
      when the author defends against that -- so a guard's ARITY would depend on how its caller
      spelled the call. Every accessor in this file answers with a scalar object for that reason.

      `any` IS THE GUARD'S QUESTION AND `joined` IS THE OPERATOR'S ANSWER. A refusal that said only
      "already consumed" to someone holding a gate whose `consumed_at` reads `null` would send them
      looking for a stamp that is not there, so the fields that ARE present are named.

      THE FIELD TEST IS Test-LamGateFieldSet AND IS NOT RESTATED HERE. `(?!null\b)` is load-bearing:
      every gate this toolchain mints carries `consumed_at: null`, so a naive test reads a FRESH
      gate as carrying a consume block and would refuse every settle there is.

      THIS IS A DISCLOSED DUPLICATION ACROSS THE TREE BOUNDARY, like Test-LamGateFieldSet above it:
      evidence-common.ps1 carries Get-EvidenceGateConsumeBlock, character for character, because
      LAM-INSTALL section 2 installs that tree ALONE into a repository that need not contain
      tools/lam. E113 prices that at a drift-detecting TEST, and WP-4's T-35 pays it by driving both
      readers over the same texts and failing on any disagreement.
    #>
    param([AllowNull()][string]$Text)
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($f in $script:LamConsumeBlockFields) {
        if (Test-LamGateFieldSet -Text $Text -Field ([string]$f)) { [void]$found.Add([string]$f) }
    }
    $arr = $found.ToArray()
    return [pscustomobject]@{ any = ($found.Count -gt 0); count = $found.Count
                              fields = @($arr); joined = ($arr -join ', ') }
}

function Get-LamGateScalarField {
    <#
    .SYNOPSIS
      ONE column-0 scalar field off a gate artifact -- and it COUNTS the keys before it answers.

    .DESCRIPTION
      WHAT WAS WRONG (round 3, a review finding). The regex literal
      `'(?m)^authorized_tip_sha:[ \t]*(\S+)'` appeared at FOUR sites -- mission-gate.ps1's `list` and
      `settle`, lam-verify-admission.ps1's admission and the next-gen decider -- and every one of
      them took the FIRST match and never asked how many there were. Driven: a gate carrying TWO
      column-0 `authorized_tip_sha` keys is ADMITTED on the first and the second is never seen;
      `list` prints the first; and `settle` composes a full consume block off the first in one key
      order while refusing, IN THE OTHER ORDER, for a reason that has nothing to do with the
      ambiguity ("the DECLARED origin does not hold this gate's authorized sha").

      THE DISCIPLINE ALREADY EXISTS IN THIS TOOLCHAIN AND WAS APPLIED UNEVENLY.
      `Get-LamOriginRemoteRefFromDetector` refuses an ambiguous detector BY NAME, lists its members
      and says "this reader does not pick one". Same class of malformed input, opposite treatment.
      So this reader borrows that sentence rather than composing a fifth opinion.

      ZERO KEYS IS NOT AN ERROR HERE. Every existing caller already has its own, better refusal for
      a gate that declares nothing -- the gate tool's "does not declare the full triple", the
      admission's refusal of a gate older than the origin fields. Making absence a refusal here would replace those
      sentences with a worse one, so absence answers `ok` with an empty value and the caller keeps
      its own words.

      COLUMN 0 ONLY, VIA `(?m)^`. A YAML mapping's top-level keys sit at column 0; an indented key
      belongs to some nested mapping and is NOT a second declaration. Every reader in this toolchain
      is anchored there and this one must not widen past them, or a nested key would start refusing
      artifacts every other reader accepts.

      THE PATTERN IS THE FOUR SITES' OWN, CHARACTER FOR CHARACTER, so a single-key artifact reads
      exactly as it read before: `(\S+)` with no end anchor, which is what makes this a CONVERSION
      of four call sites rather than a behaviour change hidden inside one.
    #>
    param([AllowNull()][string]$Text, [Parameter(Mandatory = $true)][string]$Field)
    $none = [pscustomobject]@{ ok = $true; value = ''; count = 0; field = $Field; values = @(); reason = '' }
    if (-not $Text) { return $none }
    $ms = @([regex]::Matches($Text, '(?m)^' + [regex]::Escape($Field) + ':[ \t]*(\S+)'))
    if ($ms.Count -eq 0) { return $none }
    $vals = New-Object System.Collections.Generic.List[string]
    foreach ($m in $ms) { [void]$vals.Add([string]$m.Groups[1].Value) }
    $varr = $vals.ToArray()
    if ($ms.Count -eq 1) {
        return [pscustomobject]@{ ok = $true; value = ([string]$varr[0]); count = 1; field = $Field
                                  values = @($varr); reason = '' }
    }
    return [pscustomobject]@{ ok = $false; value = ''; count = $ms.Count; field = $Field; values = @($varr)
        reason = ("the artifact carries " + $ms.Count + " column-0 '" + $Field + "' keys (values: " +
                  ($varr -join ', ') + "), so which one it declares is AMBIGUOUS and this reader does not pick one") }
}

function Get-LamGateState {
    <#
    .SYNOPSIS
      Is this gate open, revoked, or consumed? ONE definition, for every consumer.

    .DESCRIPTION
      `(?!null)` IS LOAD-BEARING AND ITS ABSENCE IS A SILENT KILL. A gate written by
      mission-gate.ps1 always carries the literal line `consumed_at: null`, and `null` is itself
      `\S` -- so the naive test `consumed_at:\s*\S` matches a FRESH gate and reports it consumed.

      THIS PREDICATE EXISTED TWICE AND THE COPIES DISAGREED. mission-gate.ps1's `list` carried the
      `(?!null)` form with a comment explaining exactly why; mission-goal-check.ps1's `gate_present`
      detector carried the naive one. Driven: on a fresh gate the first says CONSUMED=False and the
      second says unconsumed=False -- so `gate_present` could NEVER report a live gate as present
      and unconsumed. It was DEAD ON ARRIVAL, in the same class as the per-mission porcelain
      parameter no caller supplied and the ledger field no ledger line carried.

      IT HID BEHIND A FIXTURE. A hand-rolled test gate that simply OMITS `consumed_at` takes the
      other branch and passes, so a detector exercised against a fixture the real writer would
      never produce looked correct. An instrument for this must drive a gate that
      mission-gate.ps1 actually wrote.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ path = $Path; exists = $false; revoked = $false; consumed = $false; state = 'ABSENT'
            consume_block_any = $false; consume_block_fields = @(); consume_block_joined = '' }
    }
    $t = [System.IO.File]::ReadAllText($Path)
    $revoked  = Test-LamGateFieldSet -Text $t -Field 'revoked_at'
    $consumed = Test-LamGateFieldSet -Text $t -Field 'consumed_at'
    # THE FOURTH STATE, WHICH LIVED IN ONE FILE (V-1 round 14; a WP-1 finding and a WP-4 finding, independently).
    # An earlier revision added `witness_expired_at` as a DISQUALIFICATION and only the decider's own
    # reader ever learned it -- so `mission-gate list` and every goal check reported such a gate as
    # `open` while the decider refused the push. Isolated with a one-field control: with the two
    # `witness_expired` lines present the push is refused naming the disqualification; with them
    # removed the identical push succeeds. An operator reading `open` and being denied has nowhere
    # to look.
    #
    # THIS FILE EXISTS BECAUSE OF EXACTLY THIS. It was created to end a predicate that "existed
    # twice and the copies disagreed" -- and then a new state was added to one copy. Naming a single
    # definition does not make it single; the doctrine has to be applied again each time the state
    # grows, which is the part that keeps being skipped.
    $disqualified = Test-LamGateFieldSet -Text $t -Field 'witness_expired_at'
    # THE CONSUME BLOCK, ADDED AND NEVER SUBSTITUTED (round 3, a review finding). `consumed` keeps its
    # exact meaning -- `consumed_at` is set -- because mission-dispatch, mission-goal-check,
    # mission-reclose, mission-gate's list/revoke/reapprove and instrument-WP-6 all read it and none
    # of them is asking this new question. What is added is the question the SETTLE guard needed and
    # could not ask: is ANY part of a consume block already on this artifact.
    $consumeBlock = Get-LamGateConsumeBlock -Text $t
    # CONSUMED outranks REVOKED in the reported state: a gate that was actually spent says so, and
    # a later revocation does not erase that it was used. DISQUALIFIED ranks below both -- it says
    # the outcome is UNKNOWN, and a gate known to be spent or revoked is not unknown.
    $state = if ($consumed) { 'CONSUMED' } elseif ($revoked) { 'REVOKED' } elseif ($disqualified) { 'DISQUALIFIED' } else { 'open' }
    return [pscustomobject]@{ path = $Path; exists = $true; revoked = $revoked; consumed = $consumed; disqualified = $disqualified; state = $state
        consume_block_any = $consumeBlock.any; consume_block_fields = @($consumeBlock.fields)
        consume_block_joined = $consumeBlock.joined }
}

function Get-LamGateClassForArtifact {
    <#
    .SYNOPSIS
      Classify one gate artifact ON DISK, by kind lookup, cross-checked against any written class.
    .OUTPUTS
      pscustomobject: path, name, kind, declared_class, derived_class, class, ok, reason
      `class` is 'build-authorization' | 'governance' | 'unknown' | 'conflict'.
      `ok` is $true only for the two real classes; a counting consumer FAILS on the other two.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            path = $Path; name = (Split-Path -Leaf $Path); kind = ''
            declared_class = ''; derived_class = 'unknown'; class = 'unknown'; ok = $false
            reason = 'gate artifact not on disk'
        }
    }
    $t = [System.IO.File]::ReadAllText($Path)
    return (Get-LamGateClassForText -Text $t -Path $Path)
}

function Get-LamGateClassForText {
    <#
    .SYNOPSIS
      Classify one gate artifact's TEXT -- the body of Get-LamGateClassForArtifact, which reads the
      file and asks this. Same regexes, same outputs.
    .DESCRIPTION
      A caller that holds the file open for exclusive write cannot let a second reader open it, so it
      reads the bytes through its own handle and asks here. Its callers are the dispatch-gate
      decision in tools/lam/lam-dispatch-gate.ps1 -- over the text of its plain early read, and
      over the text the stamp holds under its exclusive handle -- which ask the one kind reader
      rather than restating its regex.
    #>
    param([AllowNull()][string]$Text, [string]$Path = '')
    $t = if ($null -eq $Text) { '' } else { $Text }
    $leaf = if ($Path) { Split-Path -Leaf $Path } else { '' }

    # CAPTURE EACH MATCH IMMEDIATELY. $Matches is global and every later -match overwrites it;
    # reading it after the second regex is how this build lost a runner to an index-into-null.
    $kind = ''
    if ($t -match '(?m)^kind:[ \t]*(\S+)[ \t]*\r?$') { $kind = $Matches[1] }
    $declared = ''
    if ($t -match '(?m)^gate_class:[ \t]*(\S+)[ \t]*\r?$') { $declared = $Matches[1] }

    $derived = Get-LamGateClassForKind -Kind $kind

    if ($derived -eq 'unknown') {
        return [pscustomobject]@{
            path = $Path; name = $leaf; kind = $kind
            declared_class = $declared; derived_class = $derived; class = 'unknown'; ok = $false
            reason = if ($kind) { Get-LamGateKindRefusalReason -Kind $kind } else { 'gate artifact carries no kind: field' }
        }
    }
    if ($declared -and ($declared -ne $derived)) {
        return [pscustomobject]@{
            path = $Path; name = $leaf; kind = $kind
            declared_class = $declared; derived_class = $derived; class = 'conflict'; ok = $false
            reason = "the artifact declares gate_class '$declared' but kind '$kind' derives '$derived'"
        }
    }
    return [pscustomobject]@{
        path = $Path; name = $leaf; kind = $kind
        declared_class = $declared; derived_class = $derived; class = $derived; ok = $true
        reason = if ($declared) { 'kind lookup, cross-checked against the written gate_class' } else { 'kind lookup at read time (artifact predates the written field)' }
    }
}
