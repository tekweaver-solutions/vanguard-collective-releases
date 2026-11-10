#Requires -Version 5.1
<#
.SYNOPSIS
  The falsifiers of install.ps1 and release.ps1, one case per run.

.DESCRIPTION
  Cases a-g are the earlier seats' falsifiers of 0.1.0 and 0.1.1 (a-e and g, and f, the Mark-of-the-Web
  check), carried into the tree and restated for lock format 2; gu, u-u9 and v hold the upgrade, the path guard,
  the read bound, the planned counts and the release notes in the ZIP; k1-k4 the install from a clone at its
  release tag. A case judges -Repo, a checkout: its install.ps1, release.ps1, INSTALL.md, README.md, VERSION and
  provenance/manifest.jsonl.

  THE REPOSITORY IS READ, NEVER WRITTEN. Every filesystem fixture is built under %TEMP%\<Tag>\<case> and is
  removed when the case ends (-Keep leaves it). A case that needs the release ZIP clones -Repo at its HEAD into
  that folder and runs release.ps1 in the clone, so no case touches -Repo's dist\. The static fixtures are in
  fixtures\ beside this script.

  THE INSTALLER UNDER TEST IS -Repo's HEAD, FROM A TAGGED CLONE. install.ps1 accepts a git checkout only at its
  release tag with nothing changed, and -Repo's HEAD is not at one. So every case first clones -Repo
  (New-TaggedClone: --no-hardlinks, core.autocrlf=false, no tags fetched), checks HEAD out detached at -Repo's HEAD
  commit and makes the lightweight tag v<VERSION> in the CLONE only -- -Repo gets no tag -- and $installer is the
  clone's install.ps1: every install "from the checkout" is from that clone, and a synthetic source copies it. An
  uncommitted edit in -Repo is therefore not judged: commit it first (the transcript notes a difference). Keep %TEMP% short: case u6 builds a target path of 260 characters on purpose,
  and every other case stays far below it.

  THE EOL RULE IS RE-IMPLEMENTED HERE (FoldSha, EolOf, CrlfSha: an ISO-8859-1 round trip and String.Replace),
  independently of install.ps1, so a check never grades the installer with its own function -- except case
  g's unit probes, which lift Get-JudgedForm out of the installer on purpose.

  THE RELEASE (UI-1 S4): release.ps1 builds the dashboard (npm ci --offline, npm run build) and reads its notices with
  pip-licenses, so a case that builds the ZIP (d, e, f, g, u7, u10, k1, k4) needs -LicensePython, the interpreter of an
  environment holding pip-licenses, and reads the pinned Python set's licences in -ServicePython's environment (by
  default -Repo's tools\.venv). The ZIP is HEAD's files less the dashboard's private source and the service's tests, plus
  ui/dist/**, THIRD-PARTY-NOTICES and RELEASE; its manifest names the generated members, so an install from it holds
  more files than one from a clone of the development repository: e, f and g read the expanded release's own set.
  THE PYTHON SET: every install a case runs is the files and the lock only (Run adds -SkipPythonSet); case py measures
  the step with no network. Run every case with a scratch VANGUARD_HOME: a fresh install mints a host-id there.

  A transcript is written to <Out>\falsifier-<case>.txt. Exit 0 iff every check passes.
    a   a fresh install from the tagged clone into an empty folder: every file written; lock format 2, source_kind
        clone, source_tag v<VERSION>, source_commit HEAD; -Verify 0; INSTALL.md's counts;
        the acceptance wrapper, the instruments' pinned base fixtures and the smoke-mission builder with its
        sources among the installed files; no smoke fixture anywhere
    b   an installed MOVE file edited: a same-version run writes nothing and names it; b2 a host TEMPLATE kept
        by a fresh install; b3 a MOVE file present with no lock REFUSED, planned counts, nothing written
    c   a same-version run over (a): already installed; the tree and the lock byte-identical
    d   release.ps1 twice in a clone: the ZIP, MEMBERS.sha256 and SHA256SUMS byte-equal across the two; the
        members every path git ls-tree -r --full-tree HEAD lists but the dashboard's private source and the service's
        tests, + ui/dist/** + THIRD-PARTY-NOTICES + RELEASE, the notes, the acceptance wrapper and the pinned base
        fixtures among them, no ui/ source, .ts/.tsx/.map or node_modules among them; the ZIP's manifest HEAD's header
        and released rows byte for byte, then a generated MOVE row per generated member; THIRD-PARTY-NOTICES naming every
        pinned Python package and the two OFL-1.1 font packages, no local path; MEMBERS.sha256 one line per member, each
        the member's sha256; SHA256SUMS the ZIP's line, then MEMBERS.sha256's
    e   expand the ZIP (every member taken from HEAD its blob, every other RELEASE, the manifest or generated), install
        -ReleaseZip -- the counts INSTALL.md and README.md state held to it -- mission init; the target committed as a git repository, and the
        installed spec-accept takes the draft v001 init wrote -- refusing a non-draft v001, a second version
        and -ProposalVersion v002 first, and a second acceptance after; mission smoke MET; a re-run is
        already installed. init's root .gitignore: the target had none, init created it -- a comment line
        and /.claude/settings.local.json, /.claude/worktrees/ and /.mission-runtime/ (RELEASE-4 S1 F-P7a, the
        runtime plane; .mission-runtime/ already in the file counts as that rule), LF -- and, committed, git check-ignore
        --no-index reads both ignored and .claude/settings.json not (WP-1 H-26's reading); a refused second
        init leaves it byte for byte; e3 init over a project's own .gitignore: lacking a rule, the bytes
        there kept as a prefix and only the missing rules appended after one comment line in the file's
        line ending (CRLF with no final line break; LF); holding both, left byte for byte; read-only and
        lacking a rule, a folder, or unreadable (held open with no sharing): exit 1, no .mission, the file
        untouched; read-only holding both: exit 0
    f   a marked install.ps1 is refused under RemoteSigned, runs under Bypass, and installs unmarked files
    g   the CRLF host (core.autocrlf true, and .git/info/attributes giving conversion back to every path the installed
        root .gitattributes would keep from it, as a project's own rules may): g1 fresh install, all already-identical, and the pinned base fixtures at
        their manifest bytes there and in a clone; g2 -Verify; g3 checkout and -Verify; g4 one byte appended, named;
        g5 a BINARY and g6 a MIXED probe; g7 the host flipped to LF and back
    gu  the CRLF variant of u: the same counts as the LF one
    ga  the installed root .gitattributes, written on a fresh install only: a fresh install into a
        core.autocrlf=true repository tracking nothing, then git add -A, 0 warnings and the checkout at the
        manifest's bytes; an upgrade of a project that has a .gitattributes of its own keeps it byte for byte;
        of one that has none, and a later upgrade after it, does not write it (the line, not-written=1, the
        not-written lock row, -Verify and a same-version run passing over it); nor does a first install into a
        repository with a tracked file of its own, or below a repository's top that tracks one there
    gh  the zero-host-data gate, tools/lam/gate-host-data.ps1 (UI-1 S4 P-7), an installer-owned MOVE file, over scratch trees,
        a synthetic host repository and a synthetic pattern word: a clean tree HARD 0 (the framework's own commit id no hit;
        a bare HALT number and a fixture id SOFT, listed); one pattern word planted in a doc HARD 1 (H1, path:line); a
        host-only commit id in a provenance row H3 and H5; the host's owner/repository H2 and H1; a pinned base the
        framework never recorded, in an expanded ZIP, H4; -Root and -Zip together, the hit in the ZIP scope; a report
        inside the scope and a missing pattern file exit 2; no -HostRepo, H3 not evaluated
    py  the Python set (UI-1 S4 P-5) with no network: -WhatIf with no interpreter exit 4, NOT INSTALLED, the vanguard
        command, the host-id to be minted, the ignore rule mission init's, nothing written; the install itself exit 4, every
        file and the lock written, the pip command named, -Verify 0; a tools\.venv with no interpreter left untouched;
        -SkipPythonSet exit 0; this host's CPython 3.14 named: the venv made with it and the hash-checked pip install
        planned; a mission with the feed folder: the registry row planned, mission.ps1 register named for the ignore rule
    u   upgrade over a 0.1.1-locked target (the real host's header) to a synthetic 0.1.2; a hard-linked file
    u2  a downgrade refused: planned counts, nothing written; versions ordered as numbers (0.9.0 < 0.10.0)
        both ways; a pre-release lock and a pre-release VERSION refused
    u3  a 0.1.0 lock (no eol_rule, raw sha256s): read exactly -- the CRLF file 0.1.0 wrote now LF, an LF one
        now CRLF -- then migrated to format 2 by an upgrade; an edit under it named and refused
    u4  a locally modified MOVE file refuses the whole upgrade; no line says written= but planned:; a MOVE
        file the old lock does not list, and one it records as the host's own, refused too
    u5  a same-version run over a real host's format-1 lock leaves it byte-identical
    u6  the path guard: '..', absolute, under-the-lock, device, colon and trailing-dot destinations, a
        junction, the read bound, 260 characters, a file where a folder goes, a drive root, an 8.3 short name
        for .mission -- each refused before anything is written -- and -Verify through the same guard
    u7  the ZIP release.ps1 builds carries the release notes and the member count INSTALL.md states: the tagged
        commit's released files + ui/dist's + THIRD-PARTY-NOTICES + RELEASE, and the installed count its manifest's
    u8  a format-2 upgrade: a retired path left in place, a drifted template kept, an absent host-config
        written, a path whose case changed upgraded
    u9  a move that fails part-way (a file held open): whole files only, the old lock; the same run again
        completes it; no staging folder left
    u10 an upgrade from a REAL 0.2.0 install (the tag cloned, its own installer run) to the REAL release: the ZIP
        release.ps1 builds at HEAD, expanded, its own installer run with -ReleaseZip, at a VERSION above the tag's:
        done: is the planned: line tools/provenance/upgrade-diff.py predicts; the legacy HALT census absent --
        installed, the framework's empty file, host-config -- and written first by the release's exporter from the
        project's own 0.2.0 evaluator -- kept byte for byte, one written fewer and one kept more than predicted; the
        root .gitattributes not written; the retired set the prediction's, each path left in place byte for byte and
        dropped from the lock -- the acceptance record 0.2.0 installed among them, named by nothing -Verify says;
        -Verify's line holds the not-written row. It runs the prediction tool with python -I from PATH, as the
        Python tests use it: a missing interpreter fails the case, it never passes it
    v   a class that changes between releases, over a format-2 lock an upgrade wrote (host-config rows kept):
        made MOVE and changed, a file left as shipped is upgraded (A), one edited since is refused
        edited-since-install (B), one the host had made its own is refused host-instance (C); made MOVE with
        its bytes unchanged, already-identical; and a MOVE made HOST-CONFIG, kept and not rewritten (D)
    k1  a clone at its tag installs into a fresh git-init project: exit 0; the lock source_kind clone, source_tag
        v<VERSION>, source_commit and framework_repo_tip the clone's HEAD; -Verify 0; and the lock a ZIP install's
        (built from the same HEAD, -ReleaseZip, into a second fresh project) less the generated members the ZIP alone
        carries -- every file line of the clone's the ZIP lock's line, byte for byte, the ZIP's other lines the generated
        members installed -- and its header the ZIP's but for source_kind, source_tag, source_commit, zip_sha256,
        manifest_sha256, installer_owned, installed_at and upgraded_at; the ZIP install's -Verify 0
    k2  a clone off its tag -- the tag absent, then the tag on another commit -- is REFUSED, exit 1, the reason
        named; -WhatIf too; the target untouched; and -Verify, which never reads the source, runs from it
    k3  a clone at its tag with a local change -- a tracked file modified, then an untracked file -- is REFUSED,
        exit 1, the reason named, the target untouched; a file .gitignore ignores does not count
    k4  a source holding .git is a clone and nothing else: a clone at its tag with an installer-owned file edited is
        REFUSED for its local changes, with no SOURCE FAULT line; a RELEASE that .git/info/exclude ignores is REFUSED;
        a tag of another case alone (V<VERSION>), loose and then packed, is REFUSED as absent; an expanded release
        given a .git file naming nowhere, and a clean tagged clone with no git on PATH, are REFUSED as unconfirmed,
        never installed as a release; each with the target untouched. The tagged clone reached through a junction is
        the clone; the expanded ZIP committed and tagged as a repository of its own installs as a clone whose
        source_commit is its own HEAD and whose framework_repo_tip is RELEASE's
    h4  the session-id class (RELEASE-4 S2 F-H4): tools/lam/scan-session-ids.ps1 with a synthetic id file outside the tree
        -- the tagged clone's tests/** read 0, its file count > 0; one id planted into a scratch fixture copy reads 1
        by path and line; an id file inside -Root refused; (RELEASE-4 S3 F-X4) a -Under folder that does not stand refused
        by name (exit 2), and -Under passed through -File as one comma-joined string read as its folders
    h5  the kept-file notice (RELEASE-4 S2 F-H5): a fresh install over the project's own .claude/settings.json (the
        release's less SubagentStop), -WhatIf and the install, and an upgrade over a 0.1.1 lock whose settings.json and
        model-routing.yaml are the project's own: one NOTICE kept line per kept file that differs (fold-crlf-text) from the
        release's, naming where the release's version is (a file holding the manifest's bytes), none for another; for
        settings.json the one missing registration, SubagentStop, and the release file's own block (judged here as a
        substring of that file and as JSON equal to its member); every kept file byte for byte as before
    h6  the clean-environment install proof (RELEASE-4 S2 F-H6) is a script: tests/install/clean-install-proof.ps1 run
        over the ZIP release.ps1 builds at HEAD, -Through build, in a scratch root: every step PASS, PROOF ENV PASS, the
        registration under the scratch root's VANGUARD_HOME, the project's origin the scratch bare origin, nothing
        else made; a non-empty scratch root refused (exit 2); -EngineDown read against the engine as it stands (up:
        exit 3, nothing made; down: it proceeds). The acceptance step itself is S4's to run, with both arms
    h7  PowerShell 7 and the Mark of the Web (RELEASE-4 S2 F-H7; UI-2 S1c A-11, register row 522): a marked ZIP expanded
        under each shell, its member's streams printed; the tagged clone's install.ps1 and one installer-owned member given
        a Zone.Identifier stream, then -WhatIf and the install under Windows PowerShell 5.1 and under pwsh: each names the 2
        marked files once with the fix, the install says after the write that 0 written files carry the stream, no target
        file carries one (read here), and the two shells' dispositions and counts are equal; INSTALL.md names PowerShell 7,
        Zone.Identifier, Expand-Archive and the MARK OF THE WEB lines. No pwsh on PATH: the pwsh half SKIPPED BY NAME
    h11 the release tree's eol pin (RELEASE-4 S2 F-H11, carried; UI-2 S1c A-14, register row 520): a fresh install from
        the tagged clone; every framework.lock row recorded lf or crlf names a release file and an installed file with
        exactly those line endings; planted, one lf member rewritten with CR LF: -Verify reads no difference (fold basis),
        and the pin names exactly that member
    d524 the kept set in the docs (UI-2 S1c, register row 524): INSTALL.md section 6 and the 1.2.0 notes' item 3.2 say
        the kept set is .claude/settings.json and any other file the installer reports kept, never "only" settings.json
    p7  the install path under PowerShell 7 (UI-2 S1c A-12, register row 522): the same inputs driven once under 5.1 and
        once under pwsh -- -WhatIf, the install, -Verify, mission init, smoke, register and the installed smoke builder --
        each step's exit code and count line equal across the shells. No pwsh on PATH: SKIPPED BY NAME
    h8  the installer warns on a git-ignored member (RELEASE-4 S2 F-H8): a git project whose .gitignore holds dist/, *.cmd
        and a negated rule -- -WhatIf and the install, one WARNING per member *.cmd hides naming .gitignore:2 and the rule,
        none other, the files written; a git project with no rules, none; (RELEASE-4 S3 F-X3) a git project whose *.cmd rule
        is negated for the installed tools/ui/vanguard.cmd: git check-ignore -v reports the negated rule, the install no WARNING
    h10 the legacy census header names the evaluator on the fold rule (RELEASE-4 S2 F-H10): the exporter over the v0.2.0
        evaluator LF, CRLF and with a line appended -- LF and CRLF byte-equal, the header the fold digest and the basis,
        the changed one different
    h14 no permission-rule form the CLI rejects (RELEASE-4 S2 F-H14): the five settings templates hold no Write(path),
        MultiEdit(path) or NotebookEdit(path) form; claude -p once in a project the tagged clone installed, stderr to a
        file, no "Permission ... rule ... matches no known tool / is not matched" line (no claude on PATH: SKIP by name);
        (RELEASE-4 S3 F-X6) its exit code recorded, and 0
    h16 the verify spec's section 10 anchor table equals disk (RELEASE-4 S2 F-H16): tools/lam/verify-spec-anchors.ps1 over the
        tagged clone exit 0; over a scratch copy with the fc9dc67 expanded-schemas.md row put back, exit 1 naming it
    h18 the smoke builder leaves the caller's environment untouched (RELEASE-4 S2 F-H18): the tagged clone's builder run
        IN this process into a scratch root -- exit 0; Env: identical before and after; nothing beside the smoke root
        but it and its origin, no isolation folder left; every fixture commit the Smoke Builder identity; WP-6 ZP names
        the builder session
    l1  one licence (RELEASE-4 S3 F-L1; row 495 (1), the operator ruling of 2026-11-06): -Repo's LICENSE byte for byte the
        owner-approved text (sha256 pinned here; LF, no BOM); README's Licence section two sentences -- free to use under LICENSE,
        commercial and client work included, the Framework itself not redistributed; support for paying customers by
        contact; no tracked file names the superseded licence as current but the historical release notes, the provenance
        manifest's reasons, LICENSE's own last line (the supersession) and the 1.2.0 notes' one supersession line (by file and
        exact text; operator ruling 2026-11-06)
    l6  the model sentence (RELEASE-4 S3 F-L6; roadmap decision 1 as ruled 2026-11-06): README's first paragraph, QUICKSTART's
        head and INSTALL.md's head each say free to use under LICENSE, commercial and client work included, the Framework
        itself not redistributed or resold, support by subscription for paying customers (support@tekweaver.ca); none of
        the three describes the superseded evaluation-only grant
    l2  the public repository named (RELEASE-4 S3 F-L2; row 495 (3)): INSTALL.md and QUICKSTART each name
        https://github.com/tekweaver-solutions/vanguard-collective-releases, its Releases page, the fixed-name and versioned
        assets, SHA256SUMS, MEMBERS.sha256 and the gh release download form; no placeholder for the repository's URL
    l3  the annotated-tag warning (RELEASE-4 S3 F-L3; row 495 (3)): INSTALL.md's clone section says the release tag is
        annotated, git ls-remote lists the tag object, git clone --branch warns '... is not a commit!', gives the form
        git rev-parse v<VERSION>^{commit} (no typed version) and names source_commit
    l4  README's ownership and contributions (RELEASE-4 S3 F-L4; row 495 (3)): a section of that name -- owned and
        maintained by tekWeaver Solutions Inc.; no external contributions; issues turned off on the public repository;
        support for paying customers by contact
    l5  an upgraded project's 0.x smoke mission (RELEASE-4 S3 F-L5; row 495 (3)): INSTALL.md section 6 says it is renamed
        aside (lam-smoke.old, lam-smoke-origin.git.old) and a current one built by tools\lam\build-smoke-mission.ps1, the
        acceptance wrapper then reading the new one
    l8  the ADR namespace collision in docs/framework (RELEASE-4 S3 F-L8; row 495 (13)): the v2.4 DELTA states the citation
        convention (LM2-ADR-0NN; bare ADR-0NN the on-disk tools/mission-cli/config file; the adr-040 collision) before its
        first citation and cites every decision explicitly; no file under docs/framework cites ADR-036..ADR-040 bare, nor
        ADR-045 bare outside v2.3 (the schema WP-7 U-17 pins by sha256 listed, not cured)
    enc every tracked *.md and LICENSE is UTF-8 without a BOM, with no mojibake sequence and no whitespace-only line
        (RELEASE-4 S3 F-ENC); expanded-schemas-base.md, whose bytes two documents cite by sha256 prefix, listed, not cured
    rg1 the host registry row after an upgrade (UI-2 S1 A-5; register row 526): an upgrade rewrites the target's row's
        framework_version to the version it installs, every other registry byte kept, and -WhatIf announces it; a
        target not yet registered is not registered by it; a read-only registry leaves the row and exits non-zero
        naming the registry
    kv1 -Verify over a kept file the project made byte-equal to its upstream (UI-2 S1 A-8; register row 518): 'kept,
        now equal to upstream', 0 differences, exit 0, the lock unchanged; one byte changed: CHANGED 'kept, differs
        from upstream', exit 3
    kv2 the step after the NOTICE block is added (UI-2 S1 A-9; row 518): INSTALL.md section 6 and the 1.3.0 notes name
        -Verify and 'kept, now equal to upstream'
#>
param(
    [Parameter(Mandatory)][ValidateSet('a', 'b', 'c', 'd', 'e', 'f', 'g', 'gu', 'ga', 'gh', 'py', 'u', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'v', 'k1', 'k2', 'k3', 'k4', 'h4', 'h5', 'h6', 'h7', 'h8', 'h10', 'h14', 'h16', 'h18', 'l1', 'l6', 'l2', 'l3', 'l4', 'l5', 'l8', 'enc', 'rg1', 'kv1', 'kv2', 'p7', 'h11', 'd524')][string]$Case,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Out,
    [string]$Tag = 'vc-r1',
    [switch]$Keep,
    [string]$LicensePython,
    [string]$ServicePython
)
$ErrorActionPreference = 'Stop'
$log = New-Object System.Collections.Generic.List[string]
$verdicts = New-Object System.Collections.Generic.List[string]
$L1 = [System.Text.Encoding]::GetEncoding(28591)
$NoBom = New-Object System.Text.UTF8Encoding($false)
function L { param([string]$t) $log.Add($t); [Console]::Out.WriteLine($t) }
function Check { param([string]$Name, [bool]$Ok) $s = $(if ($Ok) { 'PASS' } else { 'FAIL' }); $verdicts.Add("$s  $Name"); L "CHECK $s  $Name" }
function Sha { param([byte[]]$B) ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($B))).Replace('-', '').ToLowerInvariant() }
function FileSha { param([string]$P) Sha ([System.IO.File]::ReadAllBytes($P)) }
function IsBinary { param([byte[]]$B) return ([System.Array]::IndexOf($B, [byte]0) -ge 0) }
function FoldSha { param([byte[]]$B) if (IsBinary $B) { return Sha $B }; return Sha ($L1.GetBytes($L1.GetString($B).Replace("`r`n", "`n"))) }
function CrlfSha { param([byte[]]$B) return Sha ($L1.GetBytes($L1.GetString($B).Replace("`r`n", "`n").Replace("`n", "`r`n"))) }
function EolOf { param([byte[]]$B)
    if (IsBinary $B) { return 'binary' }
    $s = $L1.GetString($B); $pairs = ($s.Length - $s.Replace("`r`n", '').Length) / 2; $lfs = $s.Length - $s.Replace("`n", '').Length
    if ($pairs -eq 0) { return 'lf' }; if ($lfs -gt $pairs) { return 'mixed' }; return 'crlf'
}
$script:SkipCapable = @{}
function Run { param([string]$Script, [string[]]$A)
    # THE PYTHON SET (install.ps1's header) reaches PyPI: every install a case runs is the files and the lock only
    # (-SkipPythonSet, added where the installer has it and the case names none of -Verify, -SkipPythonSet, -Python);
    # case py measures the step itself, with no network.
    if ((Split-Path -Leaf $Script) -eq 'install.ps1') {
        if (-not $script:SkipCapable.ContainsKey($Script)) { $script:SkipCapable[$Script] = ([System.IO.File]::ReadAllText($Script) -match '\[switch\]\$SkipPythonSet') }
        if ($script:SkipCapable[$Script] -and -not (@($A) | Where-Object { $_ -in '-Verify', '-SkipPythonSet', '-Python' })) { $A = @($A) + @('-SkipPythonSet') }
    }
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Script @A 2>&1); $c = $LASTEXITCODE } finally { $ErrorActionPreference = $p }
    return [pscustomobject]@{ code = $c; out = @($o | ForEach-Object { "$_" }) }
}
function RunGit { param([string]$Dir, [string[]]$A)
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = @(& git -C $Dir @A 2>&1); $c = $LASTEXITCODE } finally { $ErrorActionPreference = $p }
    return [pscustomobject]@{ code = $c; out = @($o | ForEach-Object { "$_" }) }
}
function Entries { param([string]$Dir, $List)
    # Every entry under Dir, never through a reparse point: a junction is listed, not entered.
    foreach ($e in [System.IO.Directory]::GetFileSystemEntries($Dir)) {
        $a = [System.IO.File]::GetAttributes($e)
        if (($a -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { $List.Add([pscustomobject]@{ path = $e; kind = 'reparse' }) }
        elseif (($a -band [System.IO.FileAttributes]::Directory) -ne 0) { $List.Add([pscustomobject]@{ path = $e; kind = 'dir' }); Entries $e $List }
        else { $List.Add([pscustomobject]@{ path = $e; kind = 'file' }) }
    }
}
function Remove-Tree { param([string]$P)
    if (-not (Test-Path -LiteralPath $P)) { return }
    $all = New-Object System.Collections.Generic.List[object]; Entries $P $all
    foreach ($e in @($all | Where-Object { $_.kind -eq 'reparse' })) {
        if ([System.IO.Directory]::Exists($e.path)) { [System.IO.Directory]::Delete($e.path, $false) } else { [System.IO.File]::Delete($e.path) }
    }
    Remove-Item -LiteralPath $P -Recurse -Force
}
function Fresh { param([string]$P) Remove-Tree $P; return $P }
function TreeHashes { param([string]$Root)
    $d = New-Object 'System.Collections.Generic.SortedDictionary[string,string]' ([System.StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $Root) {
        $all = New-Object System.Collections.Generic.List[object]; Entries $Root $all
        foreach ($e in $all) {
            $rel = $e.path.Substring($Root.Length + 1).Replace('\', '/')
            if ($rel -eq '.git' -or $rel -like '.git/*') { continue }
            if ($e.kind -eq 'file') { $d[$rel] = FileSha $e.path } elseif ($e.kind -eq 'reparse') { $d[$rel] = 'reparse-point' }
        }
    }
    $agg = Sha ([System.Text.Encoding]::UTF8.GetBytes((($d.GetEnumerator() | ForEach-Object { $_.Key + "`t" + $_.Value }) -join "`n")))
    return [pscustomobject]@{ map = $d; count = $d.Count; aggregate = $agg }
}
function DiffTrees { param($A, $B)
    $out = @()
    foreach ($k in $A.map.Keys) { if (-not $B.map.ContainsKey($k)) { $out += "gone $k" } elseif ($A.map[$k] -ne $B.map[$k]) { $out += "changed $k" } }
    foreach ($k in $B.map.Keys) { if (-not $A.map.ContainsKey($k)) { $out += "new $k" } }
    return , $out
}
function OwnedSet { param([string]$ManifestPath)
    $s = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([System.StringComparer]::Ordinal)
    $ls = [System.IO.File]::ReadAllLines($ManifestPath)
    for ($i = 1; $i -lt $ls.Count; $i++) { if (-not $ls[$i]) { continue }; $r = $ls[$i] | ConvertFrom-Json
        if ($r.source -eq 'host' -and @('MOVE', 'TEMPLATE', 'HOST-CONFIG') -contains $r.class -and $null -ne $r.destination) { $s[$r.destination] = $r } }
    return $s
}
# A lock's JSON read with every stamp kept the string it is (HALT-U2FW4-03): PowerShell 7's ConvertFrom-Json types an ISO
# date string as DateTime, so a stamp compared as text failed there; Windows PowerShell 5.1 already keeps strings.
function ConvertFrom-JsonText { param([Parameter(ValueFromPipeline = $true)][string]$Text) process { if ($PSVersionTable.PSVersion.Major -ge 7) { $Text | ConvertFrom-Json -DateKind String } else { $Text | ConvertFrom-Json } } }
function ReadLock { param([string]$Target)
    $raw = [System.IO.File]::ReadAllBytes((Join-Path $Target 'framework.lock'))
    $ls = @($NoBom.GetString($raw).Split([char]10) | Where-Object { $_ })
    return [pscustomobject]@{ raw = $raw; sha = (Sha $raw); header = ($ls[0] | ConvertFrom-JsonText); rows = @($ls | Select-Object -Skip 1 | ForEach-Object { $_ | ConvertFrom-JsonText }); lines = $ls }
}
function TextUnset { param([string]$Dir, [string[]]$Paths)
    # The paths git reads as -text in the checkout Dir (git check-attr text: unset): no line-ending conversion reaches them.
    $s = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $g = RunGit $Dir (@('-c', 'core.quotePath=true', 'check-attr', 'text', '--') + @($Paths))
    foreach ($l in $g.out) { if ($l -match '^(.+): text: unset$') { [void]$s.Add($Matches[1]) } }
    return , $s
}
function Names { param($O) return (@($O.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') }
function EolCensus { param($Rows) $h = [ordered]@{ lf = 0; crlf = 0; mixed = 0; binary = 0; other = 0 }; foreach ($r in $Rows) { if ($h.Contains([string]$r.eol)) { $h[[string]$r.eol]++ } else { $h['other']++ } }; return $h }
function CensusText { param($H) return (@($H.Keys | ForEach-Object { "$_=$($H[$_])" }) -join ' ') }
function Dispositions { param($Rows) $h = @{}; foreach ($r in $Rows) { $h[[string]$r.disposition] = 1 + [int]$h[[string]$r.disposition] }; return $h }
function Has { param($Out, [string]$Exact) return (@($Out | Where-Object { $_ -ceq $Exact }).Count -eq 1) }
function Count { param($Out, [string]$Pattern) return @($Out | Where-Object { $_ -match $Pattern }).Count }
function Stray { param($Out) return @($Out | Where-Object { $_ -match 'written=' -and $_ -notmatch '^install\.ps1: planned: ' }) }
function Same { param($A, $B) return ((@($A) -join "`n") -ceq (@($B) -join "`n")) }
function Sorted { param($A) $x = [string[]]@($A); [Array]::Sort($x, [StringComparer]::Ordinal); return , $x }
function Bytes { param([string]$S) return , ([byte[]]$L1.GetBytes($S)) }
function WriteBytes { param([string]$P, [byte[]]$B) $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $P); [System.IO.File]::WriteAllBytes($P, $B) }
function BlobId { param([byte[]]$B)
    $s1 = [Security.Cryptography.SHA1]::Create(); $pre = [System.Text.Encoding]::ASCII.GetBytes("blob $($B.Length)" + [char]0)
    $null = $s1.TransformBlock($pre, 0, $pre.Length, $null, 0); $null = $s1.TransformFinalBlock($B, 0, $B.Length)
    return ([BitConverter]::ToString($s1.Hash)).Replace('-', '').ToLowerInvariant()
}
function LiftJudge { param([string]$Installer)
    $tok = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Installer, [ref]$tok, [ref]$errs)
    $lines = @()
    foreach ($n in @('Get-Sha256Hex', 'Get-JudgedForm')) {
        $f = @($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true))[0]
        . ([scriptblock]::Create($f.Extent.Text.Replace("function $n", "function global:$n")))
        $lines += "$n install.ps1:$($f.Extent.StartLineNumber)-$($f.Extent.EndLineNumber)"
    }
    return ($lines -join '; ')
}
function DocText { param([string]$P) return ([System.IO.File]::ReadAllText($P) -replace "\r?\n[ \t]*", ' ') }
function DocInt { param([string]$Text, [string]$Pattern, [int]$Group = 1)
    $m = [regex]::Match($Text, $Pattern)
    if (-not $m.Success) { return -1 }
    $v = $m.Groups[$Group].Value
    $words = @{ one = 1; two = 2; three = 3; four = 4; five = 5; six = 6; seven = 7; eight = 8; nine = 9; ten = 10; eleven = 11; twelve = 12; seventeen = 17 }
    if ($words.ContainsKey($v.ToLowerInvariant())) { return $words[$v.ToLowerInvariant()] }
    return [int]$v
}
function Inspect-Zip { param([string]$Zip)
    # The ZIP's end record, central directory and every local header, read here byte by byte.
    $b = [System.IO.File]::ReadAllBytes($Zip)
    $U16 = { param([int]$o) [int]$b[$o] -bor ([int]$b[$o + 1] -shl 8) }
    $U32 = { param([int]$o) [uint32]([uint32]$b[$o] -bor ([uint32]$b[$o + 1] -shl 8) -bor ([uint32]$b[$o + 2] -shl 16) -bor ([uint32]$b[$o + 3] -shl 24)) }
    $eocd = -1
    for ($i = $b.Length - 22; $i -ge [Math]::Max(0, $b.Length - 65557); $i--) { if ($b[$i] -eq 0x50 -and $b[$i + 1] -eq 0x4b -and $b[$i + 2] -eq 0x05 -and $b[$i + 3] -eq 0x06) { $eocd = $i; break } }
    if ($eocd -lt 0) { throw "no end-of-central-directory record in $Zip" }
    $count = & $U16 ($eocd + 10); $o = [int](& $U32 ($eocd + 16)); $e = @()
    for ($k = 0; $k -lt $count; $k++) {
        if ((& $U32 $o) -ne 0x02014b50) { throw "central header $k missing at $o" }
        $nl = & $U16 ($o + 28); $xl = & $U16 ($o + 30); $cl = & $U16 ($o + 32); $lo = [int](& $U32 ($o + 42))
        if ((& $U32 $lo) -ne 0x04034b50) { throw "local header $k missing at $lo" }
        $e += [pscustomobject]@{ name = [System.Text.Encoding]::UTF8.GetString($b, $o + 46, $nl); time = (& $U16 ($o + 12)); date = (& $U16 ($o + 14)); ltime = (& $U16 ($lo + 10)); ldate = (& $U16 ($lo + 12))
            xl = $xl; lxl = (& $U16 ($lo + 28)); cl = $cl; int = (& $U16 ($o + 36)); ext = (& $U32 ($o + 38)) }
        $o += 46 + $nl + $xl + $cl
    }
    $names = [string[]]@($e | ForEach-Object { $_.name })
    return [pscustomobject]@{ count = $count; names = $names; sorted = (Same $names (Sorted $names)); backslash = @($names | Where-Object { $_.Contains('\') }).Count
        dirs = @($names | Where-Object { $_.EndsWith('/') }).Count; badTime = @($e | Where-Object { $_.date -ne 0x21 -or $_.time -ne 0 -or $_.ldate -ne 0x21 -or $_.ltime -ne 0 }).Count
        attrs = @($e | Where-Object { $_.int -ne 0 -or $_.ext -ne 0 }).Count; extras = @($e | Where-Object { $_.xl -ne 0 -or $_.lxl -ne 0 }).Count; comments = @($e | Where-Object { $_.cl -ne 0 }).Count }
}
function New-Clone { param([string]$Dest, [string]$Rev = $head)
    # -Repo at its HEAD (or -Rev), its objects copied (no hard link into -Repo's object store).
    $g = RunGit (Split-Path -Parent $Dest) @('clone', '-q', '--no-hardlinks', '--no-checkout', $Repo, $Dest)
    if ($g.code -ne 0) { throw "git clone exited $($g.code): $($g.out -join ' | ')" }
    $g = RunGit $Dest @('checkout', '-q', '--detach', $Rev)
    if ($g.code -ne 0) { throw "git checkout exited $($g.code): $($g.out -join ' | ')" }
    return $Dest
}
function New-TaggedClone { param([string]$Dest, [string]$Rev = $head, [switch]$NoTag)
    # THE INSTALLER UNDER TEST (header): -Repo cloned with its objects copied, core.autocrlf false and no tag fetched,
    # HEAD detached at -Rev (-Repo's HEAD), and the lightweight tag v<the clone's VERSION> made at it IN THE CLONE ONLY
    # (-NoTag: none). Returns the clone, its HEAD, its VERSION and the tag's name.
    $g = RunGit (Split-Path -Parent $Dest) @('clone', '-q', '--no-hardlinks', '--no-tags', '--no-checkout', '-c', 'core.autocrlf=false', $Repo, $Dest)
    if ($g.code -ne 0) { throw "git clone exited $($g.code): $($g.out -join ' | ')" }
    $g = RunGit $Dest @('checkout', '-q', '--detach', $Rev)
    if ($g.code -ne 0) { throw "git checkout exited $($g.code): $($g.out -join ' | ')" }
    $at = ((RunGit $Dest @('rev-parse', 'HEAD')).out -join '').Trim()
    $v = ([System.IO.File]::ReadAllText((Join-Path $Dest 'VERSION'))).Trim()
    if (-not $NoTag) {
        $g = RunGit $Dest @('tag', "v$v", $at)
        if ($g.code -ne 0) { throw "git tag v$v exited $($g.code): $($g.out -join ' | ')" }
    }
    return [pscustomobject]@{ root = $Dest; head = $at; version = $v; tag = "v$v"; installer = (Join-Path $Dest 'install.ps1') }
}
function SourceUnchanged { param($Clone)
    # The clone as New-TaggedClone left it: git status --porcelain empty.
    $s = RunGit $Clone.root @('status', '--porcelain')
    return (($s.code -eq 0) -and (@($s.out | Where-Object { $_ }).Count -eq 0))
}
function Build-Zip { param([string]$Clone)
    # release.ps1 reads its notices with pip-licenses from -LicensePython (a scratch environment) over -ServicePython's
    # environment (by default -Repo's tools\.venv, which a clone has not got).
    if (-not $LicensePython) { throw 'a case that builds the release ZIP needs -LicensePython, the interpreter of an environment holding pip-licenses' }
    $svc = if ($ServicePython) { $ServicePython } else { Join-Path $Repo 'tools\.venv\Scripts\python.exe' }
    $r = Run (Join-Path $Clone 'release.ps1') @('-LicensePython', $LicensePython, '-ServicePython', $svc)
    L "release.ps1 in the clone: exit $($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    if ($r.code -ne 0) { throw 'release.ps1 refused in the clone' }
    $v = ([System.IO.File]::ReadAllText((Join-Path $Clone 'VERSION'))).Trim()
    return [pscustomobject]@{ zip = (Join-Path $Clone "dist\vanguard-collective-v$v.zip"); name = "vanguard-collective-v$v.zip"; sums = (Join-Path $Clone 'dist\SHA256SUMS'); members = (Join-Path $Clone 'dist\MEMBERS.sha256'); version = $v; out = $r.out }
}
function Test-NotReleased { param([string]$P)
    # THE MEMBERS RULE (release.ps1's header), restated here: the dashboard's private source and the service's tests stay
    # in the development repository -- any ui/ path but ui/dist/, tools/ui/tests/, a .ts/.tsx/.map file, a node_modules path.
    return ($P.StartsWith('ui/') -and -not $P.StartsWith('ui/dist/')) -or $P.StartsWith('tools/ui/tests/') -or ($P -match '\.(ts|tsx|map)$') -or ($P -match '(^|/)node_modules(/|$)')
}
function Use-ReleaseSet { param([string]$X)
    # The installer-owned set of an expanded release -- its own manifest's, ui/dist and THIRD-PARTY-NOTICES among them --
    # made the set every check below reads ($owned, $N, $srcFold, $srcEol, $crlfSources, $templateHost).
    $script:owned = OwnedSet (Join-Path $X 'provenance\manifest.jsonl')
    $script:N = $script:owned.Count
    $script:srcFold = @{}; $script:srcEol = @{}
    foreach ($k in $script:owned.Keys) { $b = [System.IO.File]::ReadAllBytes((Join-Path $X ($k -replace '/', '\'))); $script:srcFold[$k] = FoldSha $b; $script:srcEol[$k] = EolOf $b }
    $script:crlfSources = @($script:owned.Keys | Where-Object { $script:srcEol[$_] -notin 'lf', 'binary' })
    $script:templateHost = @($script:owned.Keys | Where-Object { $script:owned[$_].class -ne 'MOVE' }).Count
    L "the release's installer-owned set (its own manifest): $($script:N), binary $(@($script:srcEol.Values | Where-Object { $_ -eq 'binary' }).Count)"
}
function Copy-Owned { param([string]$From, [string]$To, $Set)
    $null = New-Item -ItemType Directory -Force -Path $To
    foreach ($k in $Set.Keys) { WriteBytes (Join-Path $To ($k -replace '/', '\')) ([System.IO.File]::ReadAllBytes((Join-Path $From ($k -replace '/', '\')))) }
}
function Write-Lock1 { param([string]$Target, [string]$Header, $Paths, [switch]$Raw)
    # A lock_format 1 lock over the target as it stands: 0.1.1's rows (judged sha256, eol) or, with -Raw, 0.1.0's
    # (raw sha256, no eol), computed here.
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($Header)
    foreach ($p in (Sorted $Paths)) {
        $b = [System.IO.File]::ReadAllBytes((Join-Path $Target ($p -replace '/', '\')))
        if ($Raw) { $lines.Add('{"path":"' + $p + '","sha256":"' + (Sha $b) + '","disposition":"installed"}') }
        else { $lines.Add('{"path":"' + $p + '","sha256":"' + (FoldSha $b) + '","disposition":"installed","eol":"' + (EolOf $b) + '"}') }
    }
    [System.IO.File]::WriteAllText((Join-Path $Target 'framework.lock'), (($lines -join "`n") + "`n"), $NoBom)
}
function Header { param([string]$Name, [string]$Version)
    $h = ([System.IO.File]::ReadAllText((Join-Path $Fix $Name))).TrimEnd("`r", "`n")
    if ($Version) { $h = [regex]::Replace($h, '"version":"[^"]*"', ('"version":"' + $Version + '"')) }
    return $h
}
function Staging { param([string]$T) if (-not (Test-Path -LiteralPath $T)) { return 0 }; return @([System.IO.Directory]::GetDirectories($T, '.framework-staging-*')).Count }
function New-Source { param([string]$Dir, [string]$Version, [string]$From, $Set, $Changes, $New, [string[]]$Remove, [string]$Installer, $Rename)
    # A synthetic expanded release: the installer under test, a VERSION, a RELEASE, and a manifest of the
    # installer-owned rows only, built from another source's files with the changes, the new file and the
    # removals named.
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'provenance')
    Copy-Item -LiteralPath $Installer -Destination (Join-Path $Dir 'install.ps1')
    [System.IO.File]::WriteAllText((Join-Path $Dir 'VERSION'), "$Version`n", $NoBom)
    $append = @{}; foreach ($c in @($Changes)) { if ($c) { $append[$c.path] = $c.append } }
    $man = New-Object System.Collections.Generic.List[string]
    $man.Add('{"manifest":"provenance","note":"a synthetic release source built by tests/install/falsify.ps1"}')
    $rows = @()
    foreach ($k in $Set.Keys) {
        if (@($Remove) -contains $k) { continue }
        $b = [System.IO.File]::ReadAllBytes((Join-Path $From ($k -replace '/', '\')))
        $dest = $k
        if ($Rename -and $k -ceq $Rename.from) { $dest = $Rename.to; $b = [byte[]]($b + (Bytes $Rename.append)) }
        elseif ($append.ContainsKey($k)) { $b = [byte[]]($b + (Bytes $append[$k])) }
        WriteBytes (Join-Path $Dir ($dest -replace '/', '\')) $b
        $rows += , @($dest, $Set[$k].class, (Sha $b), $b.Length)
    }
    if ($New) { $b = Bytes $New.content; WriteBytes (Join-Path $Dir ($New.path -replace '/', '\')) $b; $rows += , @($New.path, $New.class, (Sha $b), $b.Length) }
    foreach ($r in $rows) { $man.Add('{"source":"host","path":"' + $r[0] + '","class":"' + $r[1] + '","sha256":"' + $r[2] + '","bytes":' + $r[3] + ',"destination":"' + $r[0] + '"}') }
    $mp = Join-Path $Dir 'provenance\manifest.jsonl'
    [System.IO.File]::WriteAllText($mp, (($man -join "`n") + "`n"), $NoBom)
    [System.IO.File]::WriteAllText((Join-Path $Dir 'RELEASE'), "name: vanguard-collective`nversion: $Version`nframework_repo_tip: $head`nmanifest_sha256: $(FileSha $mp)`n", $NoBom)
    $set = OwnedSet $mp
    $fold = @{}; foreach ($k in $set.Keys) { $fold[$k] = FoldSha ([System.IO.File]::ReadAllBytes((Join-Path $Dir ($k -replace '/', '\')))) }
    return [pscustomobject]@{ root = $Dir; installer = (Join-Path $Dir 'install.ps1'); owned = $set; fold = $fold; manifest = $mp }
}
function Expect { param($Src, [string[]]$Changed, [int]$New)
    $move = @($Src.owned.Values | Where-Object { $_.class -eq 'MOVE' }).Count
    $kept = @($Src.owned.Values | Where-Object { $_.class -ne 'MOVE' }).Count
    return [pscustomobject]@{ move = $move; identical = $move - $Changed.Count - $New; upgraded = $Changed.Count; installed = $New; kept = $kept; written = $Changed.Count + $New }
}
function Check-Upgraded { param([string]$Label, [string]$T, $Src, $Exp, [string]$From, [string[]]$Changed, [string]$NewPath, [string]$InstalledAt)
    # The lock an upgrade wrote, against the release source and the target's own bytes, computed here.
    $lk = ReadLock $T
    L "$Label lock header: $($lk.lines[0])"
    $h = $lk.header
    Check "$Label lock header: lock_format 2, eol_rule, version $($Exp.version), previous_version $From, upgraded_at a stamp, installed_at carried over ($InstalledAt), source_kind release, source_tag and source_commit null, manifest_sha256 = the release's, installer_owned $($Src.owned.Count)" (
        ($h.lock_format -eq 2) -and ($h.eol_rule -ceq 'fold-crlf-text') -and ($h.version -ceq $Exp.version) -and ($h.previous_version -ceq $From) -and ($h.upgraded_at -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$') -and
        ($h.installed_at -ceq $InstalledAt) -and ($h.source_kind -ceq 'release') -and ($null -eq $h.source_tag) -and ($null -eq $h.source_commit) -and ($h.manifest_sha256 -eq (FileSha $Src.manifest)) -and ($h.installer_owned -eq $Src.owned.Count))
    Check "$Label the header's columns, in order" ((Names $h) -ceq $HeaderColumns)
    Check "$Label one row per installer-owned path of the release, in ordinal order ($($Src.owned.Count))" (Same @($lk.rows | ForEach-Object { $_.path }) @($Src.owned.Keys))
    $c = Dispositions $lk.rows
    L "$Label lock dispositions: $(@($c.Keys | Sort-Object | ForEach-Object { "$_=$($c[$_])" }) -join ' ')"
    $up = Sorted @($lk.rows | Where-Object { $_.disposition -ceq "upgraded-from $From" } | ForEach-Object { $_.path })
    $ins = @($lk.rows | Where-Object { $_.disposition -ceq 'installed' } | ForEach-Object { $_.path })
    $kept = Sorted @($lk.rows | Where-Object { $_.disposition -ceq 'kept' } | ForEach-Object { $_.path })
    $tk = Sorted @($Src.owned.Keys | Where-Object { $Src.owned[$_].class -ne 'MOVE' })
    Check "$Label already-identical = MOVE $($Exp.move) - K $($Exp.upgraded) - new $($Exp.installed) = $($Exp.identical)" ([int]$c['already-identical'] -eq $Exp.identical)
    Check "$Label upgraded-from $From = K = $($Exp.upgraded), exactly the changed paths" (([int]$c["upgraded-from $From"] -eq $Exp.upgraded) -and (Same $up (Sorted $Changed)))
    Check "$Label installed = $($Exp.installed)$(if ($NewPath) { ", exactly $NewPath" })" (([int]$c['installed'] -eq $Exp.installed) -and ((-not $NewPath) -or (Same $ins @($NewPath))))
    Check "$Label kept = every template and host-config row ($($Exp.kept))" (([int]$c['kept'] -eq $Exp.kept) -and (Same $kept $tk))
    Check "$Label no other disposition: the four sum to the rows" (([int]$c['already-identical'] + [int]$c["upgraded-from $From"] + [int]$c['installed'] + [int]$c['kept']) -eq $lk.rows.Count)
    $kindOf = @{ 'MOVE' = 'move'; 'TEMPLATE' = 'template'; 'HOST-CONFIG' = 'host-config' }
    $badKind = @($lk.rows | Where-Object { $_.kind -cne $kindOf[$Src.owned[$_.path].class] })
    $badCols = @($lk.rows | Where-Object { (Names $_) -cne $(if ($_.kind -eq 'move') { 'path,sha256,disposition,eol,kind' } else { 'path,sha256,disposition,eol,kind,upstream_sha256' }) })
    $badUp = @($lk.rows | Where-Object { $_.kind -ne 'move' -and $_.upstream_sha256 -ne $Src.fold[$_.path] })
    Check "$Label every row's kind is its class in the release; columns path,sha256,disposition,eol,kind[,upstream_sha256]; upstream_sha256 = sha256(fold(the release's file))" (($badKind.Count -eq 0) -and ($badCols.Count -eq 0) -and ($badUp.Count -eq 0))
    $badDisk = @($lk.rows | Where-Object { $fp = Join-Path $T ($_.path -replace '/', '\'); if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { $true } else { $b = [System.IO.File]::ReadAllBytes($fp); ($_.sha256 -ne (FoldSha $b)) -or ($_.eol -cne (EolOf $b)) } })
    Check "$Label every row's sha256 and eol are the target file's, judged here" ($badDisk.Count -eq 0)
    $badBytes = @(@($Changed) + @($NewPath) | Where-Object { $_ } | Where-Object { $fp = Join-Path $T ($_ -replace '/', '\'); (-not (Test-Path -LiteralPath $fp -PathType Leaf)) -or ((FileSha $fp) -ne (FileSha (Join-Path $Src.root ($_ -replace '/', '\')))) })
    Check "$Label every upgraded or installed file holds the release's bytes, raw" ($badBytes.Count -eq 0)
    return $lk
}

# ------------------------------------------------------------------------------------------------
$Repo = (Resolve-Path -LiteralPath $Repo).ProviderPath.TrimEnd('\')
$Fix = Join-Path $PSScriptRoot 'fixtures'
$U = [System.IO.File]::ReadAllText((Join-Path $Fix 'upgrade.json')) | ConvertFrom-Json
$null = New-Item -ItemType Directory -Force -Path $Out
$Work = Join-Path $env:TEMP "$Tag\$Case"
Remove-Tree $Work
$null = New-Item -ItemType Directory -Force -Path $Work
$head = ((RunGit $Repo @('rev-parse', 'HEAD')).out -join '').Trim()
# -Repo's tags, read before any case runs: k1-k2 hold that no tag was made there.
$repoTags = ((RunGit $Repo @('tag', '-l')).out) -join ','
$Version =([System.IO.File]::ReadAllText((Join-Path $Repo 'VERSION'))).Trim()
L "falsifier ($Case)  $([DateTime]::UtcNow.ToString('o'))"
L "repository $Repo at $head, VERSION $Version; this script sha256 $(FileSha $PSCommandPath); work $Work"
# THE INSTALLER UNDER TEST (header): the tagged clone's. No target is ever placed under it.
$Tagged = New-TaggedClone -Dest (Join-Path $Work 'tagged-clone')
$installer = $Tagged.installer
L "tagged clone $($Tagged.root) at $($Tagged.head), VERSION $($Tagged.version), local tag $($Tagged.tag)"
L "install.ps1 sha256 $(FileSha $installer)  release.ps1 sha256 $(FileSha (Join-Path $Repo 'release.ps1'))  INSTALL.md sha256 $(FileSha (Join-Path $Repo 'INSTALL.md'))"
if ((FileSha $installer) -ne (FileSha (Join-Path $Repo 'install.ps1'))) { L "NOTE: -Repo's working install.ps1 differs from HEAD's; HEAD's, the tagged clone's, is the one judged" }
$owned = OwnedSet (Join-Path $Repo 'provenance\manifest.jsonl')
$N = $owned.Count
L "manifest-derived installer-owned set: $N"
$srcFold = @{}; $srcEol = @{}
foreach ($k in $owned.Keys) { $b = [System.IO.File]::ReadAllBytes((Join-Path $Repo ($k -replace '/', '\'))); $srcFold[$k] = FoldSha $b; $srcEol[$k] = EolOf $b }
$crlfSources = @($owned.Keys | Where-Object { $srcEol[$_] -notin 'lf', 'binary' })
L "source files whose own bytes are not lf (by this script's EolOf): $(if ($crlfSources.Count) { ($crlfSources | ForEach-Object { "$_ ($($srcEol[$_]))" }) -join ', ' } else { 'none' })"
$mv = 'docs/framework/LAM-INSTALL.md'
$changedPaths = [string[]]@($U.changed | ForEach-Object { $_.path })
$templateHost = @($owned.Keys | Where-Object { $owned[$_].class -ne 'MOVE' }).Count
# The CRLF host's own attributes (cases g and gu): every path as core.autocrlf says, but the pinned fixtures.
$gInfoAttributes = "* !text`ntests/lam/fixtures/** -text`n"
# The lock header's columns, in order, as this installer writes them: the source fields after source_kind.
$HeaderColumns = 'lock,lock_format,eol_rule,version,previous_version,framework_repo_tip,source_kind,source_tag,source_commit,manifest_sha256,zip_sha256,installer_owned,installed_at,upgraded_at'

function CheckLockAgainstSource { param($Lk, [string]$Label)
    $bad = @($Lk.rows | Where-Object { $_.disposition -eq 'installed' -and $_.sha256 -ne $srcFold[$_.path] })
    Check "${Label}: every installed row's sha256 = sha256(fold(source)) (computed here)" ($bad.Count -eq 0)
    $raw = @($Lk.rows | Where-Object { $_.sha256 -ne $owned[$_.path].sha256 } | ForEach-Object { $_.path })
    Check "${Label}: the rows whose sha256 differs from the manifest's raw one are exactly the sources that are not lf ($($crlfSources -join ', '))" ((@($raw) -join ',') -ceq (@($crlfSources) -join ','))
}
function CheckRows2 { param($Lk, [string]$Label, [string]$Disposition)
    $kindOf = @{ 'MOVE' = 'move'; 'TEMPLATE' = 'template'; 'HOST-CONFIG' = 'host-config' }
    $bad = @($Lk.rows | Where-Object {
        ($_.disposition -cne $Disposition) -or ($_.kind -cne $kindOf[$owned[$_.path].class]) -or
        ((Names $_) -cne $(if ($_.kind -eq 'move') { 'path,sha256,disposition,eol,kind' } else { 'path,sha256,disposition,eol,kind,upstream_sha256' })) -or
        ($_.kind -ne 'move' -and $_.upstream_sha256 -ne $srcFold[$_.path]) })
    Check "${Label}: every row reads disposition $Disposition and kind = its class; columns path,sha256,disposition,eol,kind and upstream_sha256 = sha256(fold(source)) on the $templateHost template and host-config rows" ($bad.Count -eq 0)
}

try {
switch ($Case) {
'gh' {
    # THE ZERO-HOST-DATA GATE (UI-1 S4 P-7, F2), the tagged clone's tools\lam\gate-host-data.ps1, over a scratch tree, a
    # synthetic host repository and a synthetic pattern word -- no host word of any real project is written here.
    $gate = Join-Path $Tagged.root 'tools\lam\gate-host-data.ps1'
    Check 'the tagged clone carries tools/lam/gate-host-data.ps1, an installer-owned MOVE file' ((Test-Path -LiteralPath $gate -PathType Leaf) -and $owned.ContainsKey('tools/lam/gate-host-data.ps1') -and ($owned['tools/lam/gate-host-data.ps1'].class -ceq 'MOVE'))
    $word = 'qzhostword'
    $pf = Join-Path $Work 'patterns.txt'
    [System.IO.File]::WriteAllText($pf, "# a synthetic HARD pattern file`n$word`n", $NoBom)
    $hr = Join-Path $Work 'qzhostrepo'
    $null = New-Item -ItemType Directory -Path $hr
    $null = RunGit $hr @('init', '-q'); $null = RunGit $hr @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $hr @('config', 'user.email', 'falsifier-fixture@localhost')
    $null = RunGit $hr @('remote', 'add', 'origin', 'https://example.invalid/qzowner/qzhostrepo.git')
    WriteBytes (Join-Path $hr 'host.txt') (Bytes "a file only the synthetic host holds`n")
    $null = RunGit $hr @('add', '-A'); $null = RunGit $hr @('commit', '-q', '-m', 'the synthetic host')
    $hostId = ((RunGit $hr @('rev-parse', 'HEAD')).out -join '').Trim().Substring(0, 12)
    $fwId = $Tagged.head.Substring(0, 12)
    function New-GhTree { param([string]$Name)
        # A clean scratch tree: a document, a provenance line, an instrument line with a fixture id and a bare HALT number.
        $d = Join-Path $Work $Name
        Remove-Tree $d
        WriteBytes (Join-Path $d 'docs\guide.md') (Bytes "# A guide`n`nThe framework's own commit $fwId is cited here.`n")
        WriteBytes (Join-Path $d 'provenance\rows.jsonl') (Bytes "{`"path`":`"docs/guide.md`",`"reason`":`"authored`"}`n")
        WriteBytes (Join-Path $d 'tests\lam\member.ps1') (Bytes "# HALT-12 is a sample; fixture id 5e1fb11d0b5e`n")
        return $d
    }
    function Invoke-Gh { param([string]$Label, [string[]]$A)
        $rep = Join-Path $Work ("gh-$Label.txt")
        $r = Run $gate (@($A) + @('-PatternFile', $pf, '-HostRepo', $hr, '-FrameworkRepo', $Tagged.root, '-Report', $rep))
        L "($Label) gate exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        $txt = if (Test-Path -LiteralPath $rep) { [System.IO.File]::ReadAllText($rep) } else { '' }
        $hardN = if ($txt -match '(?m)^HARD (\d+)$') { [int]$Matches[1] } else { -1 }
        return [pscustomobject]@{ code = $r.code; out = $r.out; report = $txt; hard = $hardN }
    }
    $clean = New-GhTree 'ghclean'
    $g0 = Invoke-Gh 'clean' @('-Root', $clean)
    Check '(clean) exit 0, HARD 0; the framework''s own commit id is no hit; the bare HALT number and the fixture id are SOFT, listed' (
        ($g0.code -eq 0) -and ($g0.hard -eq 0) -and ($g0.report -match '\[B3-TESTS\] ROOT:tests/lam/member\.ps1:1  HALT-12') -and ($g0.report -match '\[FIXTURE-ID\] ROOT:tests/lam/member\.ps1:1  5e1fb11d0b5e') -and ($g0.report -notmatch [regex]::Escape($fwId)))
    Check '(clean) the report names its pattern file by sha256 and count, never by its words' (($g0.report -match "pattern file: .+ \(1 literal\(s\), sha256 $(FileSha $pf)\)") -and ($g0.report -notmatch $word))
    $p1 = New-GhTree 'ghword'
    WriteBytes (Join-Path $p1 'docs\guide.md') (Bytes "# A guide`n`nThe framework's own commit $fwId is cited here.`nWritten for $word.`n")
    $g1 = Invoke-Gh 'word' @('-Root', $p1)
    Check '(one host word planted in a doc) exit 1, HARD 1: H1 at docs/guide.md:4' (($g1.code -eq 1) -and ($g1.hard -eq 1) -and ($g1.report -match "\[H1 host-name\] ROOT:docs/guide\.md:4  $word"))
    $p2 = New-GhTree 'ghid'
    WriteBytes (Join-Path $p2 'provenance\rows.jsonl') (Bytes "{`"path`":`"docs/guide.md`",`"reason`":`"from host commit $hostId`"}`n")
    $g2 = Invoke-Gh 'id' @('-Root', $p2)
    Check '(a host-only commit id planted in a provenance row) exit 1: H3 and H5 at provenance/rows.jsonl:1, nothing else' (($g2.code -eq 1) -and ($g2.hard -eq 2) -and
        ($g2.report -match "\[H3 host-id:commit\] ROOT:provenance/rows\.jsonl:1  $hostId") -and ($g2.report -match "\[H5 provenance-cites-host\] ROOT:provenance/rows\.jsonl:1  $hostId"))
    $p3 = New-GhTree 'ghpath'
    WriteBytes (Join-Path $p3 'docs\guide.md') (Bytes "# A guide`n`nSee qzowner/qzhostrepo for the source.`n")
    $g3 = Invoke-Gh 'path' @('-Root', $p3)
    Check '(the host''s origin owner/repository planted) exit 1: H2 host-repo-name at docs/guide.md:3, with the derived names (H1)' (($g3.code -eq 1) -and ($g3.report -match '\[H2 host-path:host-repo-name\] ROOT:docs/guide\.md:3  qzowner/qzhostrepo') -and ($g3.report -match '\[H1 host-name\] ROOT:docs/guide\.md:3  qzowner'))
    $p4 = New-GhTree 'ghbase'
    WriteBytes (Join-Path $p4 'tests\lam\fixtures\base-0000aaaa\tools\x.ps1.base') (Bytes "# bytes the framework never recorded at tools/x.ps1`n")
    $g4 = Invoke-Gh 'base' @('-Zip', $p4)
    Check '(a pinned base whose bytes the framework never recorded, in an expanded ZIP) exit 1: H4 at ZIP:tests/lam/fixtures/base-0000aaaa/tools/x.ps1.base' (($g4.code -eq 1) -and ($g4.hard -eq 1) -and ($g4.report -match '\[H4 pinned-host-copy\] ZIP:tests/lam/fixtures/base-0000aaaa/tools/x\.ps1\.base:0'))
    $g5 = Invoke-Gh 'both' @('-Root', $clean, '-Zip', $p1)
    Check '(-Root clean and -Zip with the word) exit 1, HARD 1, the hit named in the ZIP scope' (($g5.code -eq 1) -and ($g5.hard -eq 1) -and ($g5.report -match "\[H1 host-name\] ZIP:docs/guide\.md:4  $word"))
    $r = Run $gate @('-Root', $clean, '-PatternFile', $pf, '-Report', (Join-Path $clean 'inside.txt'))
    Check '(a report inside the scope) exit 2, nothing written there' (($r.code -eq 2) -and -not (Test-Path -LiteralPath (Join-Path $clean 'inside.txt')))
    $r = Run $gate @('-Root', $clean, '-PatternFile', (Join-Path $Work 'no-such-file.txt'))
    Check '(no pattern file) exit 2' ($r.code -eq 2)
    $gN = Run $gate @('-Root', $clean, '-PatternFile', $pf, '-FrameworkRepo', $Tagged.root, '-Report', (Join-Path $Work 'gh-nohost.txt'))
    Check '(no -HostRepo) exit 0; the report says H3 was not evaluated' (($gN.code -eq 0) -and ([System.IO.File]::ReadAllText((Join-Path $Work 'gh-nohost.txt')) -match 'H3: NOT EVALUATED \(no -HostRepo\)'))
}
'py' {
    # THE PYTHON SET (install.ps1's header) and -WhatIf's readings of what it does not write, with NO NETWORK: every run
    # here names -Python (an interpreter that does not exist, or this host's CPython 3.14 under -WhatIf alone) or
    # -SkipPythonSet, so pip never reaches PyPI. A scratch VANGUARD_HOME for the host registration.
    $vgPrev = $env:VANGUARD_HOME
    $vh = Join-Path $Work 'vghome'
    $env:VANGUARD_HOME = $vh
    try {
        $bogus = Join-Path $Work 'no-python\python.exe'
        $pins = [regex]::Matches([System.IO.File]::ReadAllText((Join-Path $Repo 'tools\ui\requirements.txt')), '(?m)^[A-Za-z0-9][A-Za-z0-9._-]*==\S+').Count
        $t = Join-Path $Work 't'
        $w = Run $installer @('-Target', $t, '-WhatIf', '-Python', $bogus)
        L "(-WhatIf, no interpreter) exit=$($w.code)"; $w.out | Where-Object { $_ -match 'planned|WhatIf' } | ForEach-Object { L "  | $_" }
        Check "(-WhatIf, -Python naming no interpreter) exit 4, the real run's; planned python set NOT INSTALLED naming -Python; the vanguard command tools\ui\vanguard.cmd (install); a host-id to be minted in the scratch home, no registry row (no mission); the ignore rule mission init's; nothing written" (
            ($w.code -eq 4) -and ((Count $w.out ('^install\.ps1: planned python set: NOT INSTALLED -- no CPython 3\.14 win-amd64 interpreter to make tools\\\.venv with \(-Python ' + [regex]::Escape($bogus) + ': does not run\)')) -eq 1) -and
            ((Count $w.out '^install\.ps1: planned vanguard command: tools\\ui\\vanguard\.cmd \(install\) -- ') -eq 1) -and
            (Has $w.out "install.ps1: planned host registration: a host-id would be minted in $vh; no registry row (the target carries no mission yet: mission init adds it)") -and
            ((Count $w.out '^install\.ps1: planned telemetry ignore rule: no mission yet: mission init writes the rule /\.mission-runtime/ into the target''s \.gitignore$') -eq 1) -and (Has $w.out 'install.ps1: WhatIf: nothing was written.') -and
            (-not (Test-Path -LiteralPath $t)) -and (-not (Test-Path -LiteralPath (Join-Path $vh 'host-id'))))
        $r = Run $installer @('-Target', $t, '-Python', $bogus)
        L "(install, no interpreter) exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
        Check "(an install, -Python naming no interpreter) exit 4: done: written=$N, framework.lock written, one PYTHON SET NOT INSTALLED line naming the pip command to run, no tools\.venv made" (
            ($r.code -eq 4) -and (Has $r.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0") -and (Test-Path -LiteralPath (Join-Path $t 'framework.lock')) -and
            ((Count $r.out '^install\.ps1: PYTHON SET NOT INSTALLED: .+ -m pip install --require-hashes --only-binary :all: -r .+tools\\ui\\requirements\.txt$') -eq 1) -and (-not (Test-Path -LiteralPath (Join-Path $t 'tools\.venv'))))
        $v = Run $installer @('-Target', $t, '-Verify')
        Check '(after it) -Verify exit 0, 0 difference(s): every file stands' (($v.code -eq 0) -and ((Count $v.out "^install\.ps1: verify: $N file\(s\) listed, 0 difference\(s\); ") -eq 1))
        $hid = if (Test-Path -LiteralPath (Join-Path $vh 'host-id')) { ([System.IO.File]::ReadAllText((Join-Path $vh 'host-id'))).Trim() } else { '' }
        $t2 = Join-Path $Work 't2'
        $null = New-Item -ItemType Directory -Path (Join-Path $t2 'tools\.venv')
        $w2 = Run $installer @('-Target', $t2, '-WhatIf', '-Python', $bogus)
        Check "(a tools\.venv with no Scripts\python.exe) -WhatIf exit 4, NOT INSTALLED: it stands without an interpreter and is left untouched; the host-id the install minted ($hid) read as kept" (
            ($w2.code -eq 4) -and ((Count $w2.out '^install\.ps1: planned python set: NOT INSTALLED -- tools\\\.venv stands in the target without Scripts\\python\.exe; it is left untouched') -eq 1) -and
            ($hid -match '^[0-9a-f-]{36}$') -and ((Count $w2.out ('^install\.ps1: planned host registration: host-id ' + [regex]::Escape($hid) + ' in ' + [regex]::Escape($vh) + ', kept; ')) -eq 1))
        $t3 = Join-Path $Work 't3'
        $r3 = Run $installer @('-Target', $t3, '-SkipPythonSet')
        Check "(-SkipPythonSet) exit 0, done: written=$N, the line 'python set: skipped (-SkipPythonSet)', no tools\.venv" (($r3.code -eq 0) -and (Has $r3.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0") -and
            ((Count $r3.out '^install\.ps1: python set: skipped \(-SkipPythonSet\)') -eq 1) -and (-not (Test-Path -LiteralPath (Join-Path $t3 'tools\.venv'))))
        # A CPython 3.14 on this host, named with -Python, under -WhatIf: the plan makes tools\.venv with it and names pip's
        # hash-checked install of the pinned set. Nothing runs pip.
        $py = $null
        foreach ($c in @(@('py', '-3.14'), @('python'))) {
            if (-not (Get-Command $c[0] -ErrorAction SilentlyContinue)) { continue }
            $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try { $o = @(& $c[0] @($c | Select-Object -Skip 1) -I -c 'import sys,sysconfig;print(sys.implementation.name,sys.version_info[0],sys.version_info[1],sysconfig.get_platform(),sys.executable)' 2>$null) } finally { $ErrorActionPreference = $p }
            $f = @(([string]($o | Select-Object -Last 1)).Trim() -split ' ', 5)
            if ($f.Count -eq 5 -and $f[0] -eq 'cpython' -and $f[1] -eq '3' -and $f[2] -eq '14' -and $f[3] -eq 'win-amd64') { $py = $f[4]; break }
        }
        L "a CPython 3.14 win-amd64 on this host: $(if ($py) { $py } else { 'NONE' })"
        $t4 = Join-Path $Work 't4'
        $w4 = if ($py) { Run $installer @('-Target', $t4, '-WhatIf', '-Python', $py) } else { $null }
        Check "(this host's CPython 3.14, -WhatIf) exit 0; planned python set: tools\.venv made by -Python, then pip install --require-hashes --only-binary :all: -r tools\ui\requirements.txt ($pins pinned package(s), from PyPI); nothing written" (
            ($null -ne $w4) -and ($w4.code -eq 0) -and ((Count $w4.out ('^install\.ps1: planned python set: tools\\\.venv made by -Python: ' + [regex]::Escape($py) + ' \(CPython 3\.14\.\d+, win-amd64\); then pip install --require-hashes --only-binary :all: -r tools\\ui\\requirements\.txt \(' + $pins + ' pinned package\(s\), from PyPI\)$')) -eq 1) -and
            (-not (Test-Path -LiteralPath $t4)))
        # The registry row and the ignore rule over a target that carries a mission and the feed folder.
        $t5 = Join-Path $Work 't5'
        WriteBytes (Join-Path $t5 '.mission\mission.yaml') (Bytes "id: m-falsifier`nstate: Created`n")
        $null = New-Item -ItemType Directory -Path (Join-Path $t5 '.mission-runtime\telemetry')
        $w5 = Run $installer @('-Target', $t5, '-WhatIf', '-SkipPythonSet')
        Check '(a mission with the feed folder) -WhatIf: a row for the target (mission m-falsifier) to be added to projects.yaml; the .gitignore does not ignore the feed, and mission.ps1 register adds the rule; the python set skipped' (
            ($w5.code -eq 0) -and ((Count $w5.out ('^install\.ps1: planned host registration: .+; a row for the target \(mission m-falsifier\) would be added to ' + [regex]::Escape((Join-Path $vh 'projects.yaml')) + '$')) -eq 1) -and
            ((Count $w5.out '^install\.ps1: planned telemetry ignore rule: the target''s \.gitignore does not ignore /\.mission-runtime/; install\.ps1 writes no \.gitignore -- mission\.ps1 register -Target .+ adds the rule$') -eq 1) -and
            ((Count $w5.out '^install\.ps1: planned python set: skipped \(-SkipPythonSet\)') -eq 1))
        WriteBytes (Join-Path $t5 '.gitignore') (Bytes ".mission-runtime/`n")
        $null = [System.IO.Directory]::Delete((Join-Path $t5 '.mission-runtime\telemetry'))
        $w6 = Run $installer @('-Target', $t5, '-WhatIf', '-SkipPythonSet')
        Check '(the same mission, no feed folder, a .gitignore with .mission-runtime/) -WhatIf: no registry row, mission.ps1 register named; the ignore rule already held' (
            ($w6.code -eq 0) -and ((Count $w6.out '^install\.ps1: planned host registration: .+; no registry row: the target''s mission m-falsifier is not registered for the mission-event feed') -eq 1) -and
            ((Count $w6.out '^install\.ps1: planned telemetry ignore rule: the target''s \.gitignore already ignores /\.mission-runtime/ \(or the feed''s folder within it\)$') -eq 1))
        Check 'no -WhatIf wrote a registry' (-not (Test-Path -LiteralPath (Join-Path $vh 'projects.yaml')))
    } finally { $env:VANGUARD_HOME = $vgPrev }
}
'a' {
    $t = Join-Path $Work 't'
    $null = New-Item -ItemType Directory -Path $t
    Check 'the target exists and is empty before the install' (@(Get-ChildItem -LiteralPath $t -Force).Count -eq 0)
    $r = Run $installer @('-Target', $t)
    L "install exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check 'install exit code 0' ($r.code -eq 0)
    $done = "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0"
    Check "the counts line reads $done" (Has $r.out $done)
    Check 'no planned: line, and written= only on the done: line' (((Count $r.out '^install\.ps1: planned:') -eq 0) -and ((Count $r.out 'written=') -eq 1))
    Check 'the mode line says fresh install' (Has $r.out 'install.ps1: fresh install: no framework.lock in the target')
    Check "$N per-file lines say install" ((Count $r.out '^install\.ps1:   install ') -eq $N)
    # F-H15 (RELEASE-4 S2): THE CUSTOMER REGISTRATION PATH. A fresh install from HEAD's source writes the TEMPLATE
    # .claude/settings.json with the manifest's bytes, and that file registers SubagentStop (matcher *, the next-gen
    # evidence-subagent-stop.ps1). Read before the lock, so a refused install reads this line FAIL, not an exception.
    $setRel = '.claude/settings.json'
    $setT = Join-Path $t '.claude\settings.json'
    $setHas = Test-Path -LiteralPath $setT -PathType Leaf
    $ssReg = @()
    if ($setHas) {
        $sj = [System.IO.File]::ReadAllText($setT) | ConvertFrom-Json
        if ($sj.hooks -and (@($sj.hooks.PSObject.Properties | ForEach-Object { $_.Name }) -contains 'SubagentStop')) {
            foreach ($g in @($sj.hooks.SubagentStop)) { foreach ($hk in @($g.hooks)) { if (([string]$g.matcher -ceq '*') -and ([string]$hk.type -ceq 'command') -and ([string]$hk.command).Contains('$CLAUDE_PROJECT_DIR/tools/evidence-hooks-next/hooks/evidence-subagent-stop.ps1')) { $ssReg += $hk } } }
        }
    }
    L "(F-H15) installed $setRel present $setHas; SubagentStop registrations naming evidence-subagent-stop.ps1: $($ssReg.Count)"
    Check "(F-H15) the fresh install wrote $setRel (the TEMPLATE, the manifest's bytes) and it registers SubagentStop once, matcher *, the next-gen evidence-subagent-stop.ps1" (
        $setHas -and $owned.ContainsKey($setRel) -and ($owned[$setRel].class -ceq 'TEMPLATE') -and ((FileSha $setT) -eq $owned[$setRel].sha256) -and ($ssReg.Count -eq 1))
    $classes = @('MOVE', 'TEMPLATE', 'HOST-CONFIG') | ForEach-Object { $c = $_; @($owned.Values | Where-Object { $_.class -eq $c }).Count }
    $mline = @($r.out | Where-Object { $_ -match '^install\.ps1: manifest sha256 ' })[0]
    Check "the manifest line names installer-owned $N (MOVE $($classes[0]), TEMPLATE $($classes[1]), HOST-CONFIG $($classes[2])) and framework.lock absent" ($mline -cmatch ("; installer-owned $N \(MOVE $($classes[0]), TEMPLATE $($classes[1]), HOST-CONFIG $($classes[2])\); framework\.lock absent$"))
    $lk = ReadLock $t
    L "lock header: $($lk.lines[0])"
    $h = $lk.header
    Check "lock header: lock_format 2, eol_rule fold-crlf-text, version $Version, previous_version null, upgraded_at null, source_kind clone, source_tag $($Tagged.tag), source_commit = framework_repo_tip = HEAD, zip_sha256 null, installer_owned $N, installed_at a UTC stamp" (
        ($h.lock_format -eq 2) -and ($h.eol_rule -ceq 'fold-crlf-text') -and ($h.version -ceq $Version) -and ($null -eq $h.previous_version) -and ($null -eq $h.upgraded_at) -and ($h.source_kind -ceq 'clone') -and
        ($h.source_tag -ceq $Tagged.tag) -and ($h.source_commit -ceq $head) -and
        ($h.framework_repo_tip -ceq $head) -and ($null -eq $h.zip_sha256) -and ($h.installer_owned -eq $N) -and ($h.installed_at -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$'))
    Check "the header's columns, in order" ((Names $h) -ceq $HeaderColumns)
    Check 'lock header manifest_sha256 = the source manifest sha256' ($h.manifest_sha256 -eq (FileSha (Join-Path $Repo 'provenance\manifest.jsonl')))
    Check "the lock is 1 header + $N lines" (($lk.lines.Count -eq $N + 1) -and ($lk.rows.Count -eq $N))
    $lockPaths = [string[]]@($lk.rows | ForEach-Object { $_.path })
    Check 'the lock lists them in ordinal path order, and its paths are the manifest-derived set' (Same $lockPaths @($owned.Keys))
    CheckRows2 $lk '(a)' 'installed'
    CheckLockAgainstSource $lk '(a)'
    $ec = EolCensus $lk.rows
    L "lock eol census: $(CensusText $ec)"
    Check "every row's eol is what its file's bytes show (computed here)" ((@($lk.rows | Where-Object { $_.eol -cne $srcEol[$_.path] }).Count -eq 0))
    $tree = TreeHashes $t
    Check "the target holds exactly $($N + 1) files: the $N and framework.lock" ($tree.count -eq $N + 1 -and $tree.map.ContainsKey('framework.lock'))
    Check 'no staging folder is left in the target (the write is staged, then moved)' ((Staging $t) -eq 0)
    Check 'every installed file hashes RAW to its manifest line (writes are the source bytes)' ((@($owned.Keys | Where-Object { $tree.map[$_] -ne $owned[$_].sha256 }).Count) -eq 0)
    $wrapper = 'tools/lam/instrument-acceptance.ps1'
    Check "the acceptance wrapper $wrapper is installer-owned: the manifest classes it MOVE, the install wrote its bytes, the lock lists it as move" (
        $owned.ContainsKey($wrapper) -and ($owned[$wrapper].class -ceq 'MOVE') -and $tree.map.ContainsKey($wrapper) -and ($tree.map[$wrapper] -eq $owned[$wrapper].sha256) -and
        (@($lk.rows | Where-Object { ($_.path -ceq $wrapper) -and ($_.kind -ceq 'move') }).Count -eq 1))
    # THE BASE FIXTURES ARE INSTALLED: every file the manifest names under tests/lam/fixtures/base-<label>/ or
    # tests/lam/fixtures/legacy-census-halts/ -- the pinned bases the instruments read first -- is installer-owned: source host,
    # class MOVE, destination its own path, its bytes written, one move row in the lock. Seat-halt is not.
    $allRecs = @([System.IO.File]::ReadAllLines((Join-Path $Repo 'provenance\manifest.jsonl')) | Select-Object -Skip 1 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
    $baseFx = @($allRecs | Where-Object { [string]$_.destination -match '^tests/lam/fixtures/(base-[0-9a-f]{8}(-s[0-9]{2})?|legacy-census-halts)/' })
    $badFx = New-Object System.Collections.Generic.List[string]
    foreach ($fx in $baseFx) {
        $fxRows = @($lk.rows | Where-Object { ($_.path -ceq $fx.path) -and ($_.kind -ceq 'move') }).Count
        if (-not (($fx.source -ceq 'host') -and ($fx.class -ceq 'MOVE') -and ($fx.destination -ceq $fx.path) -and $owned.ContainsKey($fx.path) -and
                  $tree.map.ContainsKey($fx.path) -and ($tree.map[$fx.path] -eq $fx.sha256) -and ($fxRows -eq 1))) { $badFx.Add($fx.path) }
    }
    L "base and legacy-census fixtures: $($baseFx.Count); not installed as MOVE: $($badFx.Count)$(if ($badFx.Count) { ' -- ' + (@($badFx | Select-Object -First 3) -join ', ') })"
    Check "the $($baseFx.Count) base and legacy-census fixtures are installer-owned: source host, class MOVE, destination their own path, installed with their bytes, a move row each in the lock" (($baseFx.Count -gt 0) -and ($badFx.Count -eq 0))
    # THE SMOKE-MISSION BUILDER AND ITS SOURCES ARE INSTALLED: the builder and every file the manifest names under
    # tools/lam/smoke-mission/ is installer-owned, as the base fixtures are. There is no smoke fixture: no record names a
    # destination under tests/lam/fixtures/lam-smoke/, and nothing was installed there.
    $smokeSrc = @($allRecs | Where-Object { ([string]$_.destination -ceq 'tools/lam/build-smoke-mission.ps1') -or ([string]$_.destination -match '^tools/lam/smoke-mission/') })
    $badSrc = New-Object System.Collections.Generic.List[string]
    foreach ($sx in $smokeSrc) {
        $sxRows = @($lk.rows | Where-Object { ($_.path -ceq $sx.path) -and ($_.kind -ceq 'move') }).Count
        if (-not (($sx.source -ceq 'host') -and ($sx.class -ceq 'MOVE') -and ($sx.destination -ceq $sx.path) -and $owned.ContainsKey($sx.path) -and
                  $tree.map.ContainsKey($sx.path) -and ($tree.map[$sx.path] -eq $sx.sha256) -and ($sxRows -eq 1))) { $badSrc.Add($sx.path) }
    }
    L "smoke-mission builder and sources: $($smokeSrc.Count); not installed as MOVE: $($badSrc.Count)$(if ($badSrc.Count) { ' -- ' + (@($badSrc | Select-Object -First 3) -join ', ') })"
    Check "the smoke-mission builder and its $($smokeSrc.Count - 1) source files are installer-owned: source host, class MOVE, destination their own path, installed with their bytes, a move row each in the lock" (
        ($smokeSrc.Count -gt 1) -and ($badSrc.Count -eq 0) -and (@($smokeSrc | Where-Object { $_.destination -ceq 'tools/lam/build-smoke-mission.ps1' }).Count -eq 1) -and
        (@($lk.rows | Where-Object { ($_.path -ceq 'tools/lam/build-smoke-mission.ps1') -and ($_.kind -ceq 'move') }).Count -eq 1))
    $smokeFx = @($allRecs | Where-Object { [string]$_.destination -match '^tests/lam/fixtures/lam-smoke/' })
    # The AUTHORED fixtures -- the seat-halt files and the base recipe synthetic-bases.json -- are tracked, not shipped.
    $seatFx = @($allRecs | Where-Object { [string]$_.destination -match '^tests/lam/fixtures/(seat-halt/|synthetic-bases\.json$)' })
    Check "no record names a smoke fixture ($($smokeFx.Count)) and nothing stands under tests/lam/fixtures/lam-smoke/ in the target; the $($seatFx.Count) seat-halt and base-recipe files are not installer-owned, and none was installed" (
        ($smokeFx.Count -eq 0) -and (@($tree.map.Keys | Where-Object { $_ -match '^tests/lam/fixtures/lam-smoke/' }).Count -eq 0) -and ($seatFx.Count -gt 1) -and
        (@($seatFx | Where-Object { [string]$_.class -cne 'AUTHORED' }).Count -eq 0) -and
        (@($seatFx | Where-Object { $owned.ContainsKey([string]$_.destination) -or $tree.map.ContainsKey([string]$_.destination) }).Count -eq 0))
    Check 'no .mission or .mission-runtime was created' (-not (Test-Path -LiteralPath (Join-Path $t '.mission')) -and -not (Test-Path -LiteralPath (Join-Path $t '.mission-runtime')))
    $v = Run $installer @('-Target', $t, '-Verify')
    L "verify exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    $vline = "install.ps1: verify: $N file(s) listed, 0 difference(s); eol lf=$($ec.lf) crlf=$($ec.crlf) mixed=$($ec.mixed) binary=$($ec.binary)."
    Check "-Verify exit 0, it says it read lock_format 2, and its last line reads: $vline" (($v.code -eq 0) -and (Has $v.out 'install.ps1: verify: read lock_format 2') -and (Has $v.out $vline))
    Check '-Verify wrote nothing (whole-tree hash unchanged)' ((TreeHashes $t).aggregate -eq $tree.aggregate)
    # The counts INSTALL.md and README.md state are the release's -- an install from the ZIP, ui/dist and the notices
    # among its files -- and case e holds them to one; the longest installed path is a path of this set.
    $im = DocText (Join-Path $Repo 'INSTALL.md')
    $longest = (@($owned.Keys | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum
    $dl = DocInt $im 'the longest installed path is (\d+) characters'
    Check "INSTALL.md: the longest installed path is $dl characters = $longest, measured" ($dl -eq $longest)
}
'b' {
    $t = Join-Path $Work 't'
    $r = Run $installer @('-Target', $t)
    Check 'a fresh install for (b): exit 0' ($r.code -eq 0)
    $h0 = TreeHashes $t
    Check "the edited file is class MOVE ($mv)" ($owned[$mv].class -eq 'MOVE')
    $ep = Join-Path $t ($mv -replace '/', '\')
    $fs = [System.IO.File]::Open($ep, [System.IO.FileMode]::Append); try { $x = [System.Text.Encoding]::ASCII.GetBytes("local edit`n"); $fs.Write($x, 0, $x.Length) } finally { $fs.Dispose() }
    $h1 = TreeHashes $t
    $d01 = DiffTrees $h0 $h1
    Check 'the edit changed exactly that one file' (($d01.Count -eq 1) -and ($d01[0] -eq "changed $mv"))
    $r = Run $installer @('-Target', $t)
    L "a same-version run after the edit: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check 'exit code 3: already installed at this version, and a file differs' ($r.code -eq 3)
    Check "it names $mv CHANGED, and nothing else" (((Count $r.out ('CHANGED\s+' + [regex]::Escape($mv) + '\s')) -eq 1) -and ((Count $r.out '^install\.ps1:\s+(CHANGED|MISSING|REFUSED)\s') -eq 1))
    Check 'it says already installed, and that nothing was written' (((Count $r.out '^install\.ps1: already installed: framework\.lock says ') -eq 1) -and ((Count $r.out 'Nothing was written; framework\.lock is untouched\.$') -eq 1))
    Check 'no line carries written=' ((Count $r.out 'written=') -eq 0)
    $h2 = TreeHashes $t
    Check 'NOTHING was written (whole tree equal before and after, lock included)' (((DiffTrees $h1 $h2).Count -eq 0) -and ($h1.aggregate -eq $h2.aggregate))
    $w = Run $installer @('-Target', $t, '-WhatIf')
    Check '-WhatIf over the edited target also exits 3 and writes nothing' (($w.code -eq 3) -and ((TreeHashes $t).aggregate -eq $h2.aggregate))
    $v = Run $installer @('-Target', $t, '-Verify')
    L "verify: exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    Check '-Verify reports exactly the edited file, exit 3' (($v.code -eq 3) -and ((Count $v.out ('CHANGED\s+' + [regex]::Escape($mv))) -eq 1) -and ((Count $v.out ' 1 difference\(s\); eol ') -eq 1))

    L '--- b2: a TEMPLATE file the host has before the first install is kept, not refused'
    $t2 = Join-Path $Work 't2'
    $tpl = 'model-routing.yaml'
    Check "$tpl is class TEMPLATE" ($owned[$tpl].class -eq 'TEMPLATE')
    $hostBytes = [byte[]]([System.IO.File]::ReadAllBytes((Join-Path $Repo $tpl)) + (Bytes "# host edit`n"))
    WriteBytes (Join-Path $t2 $tpl) $hostBytes
    $r = Run $installer @('-Target', $t2)
    L "install: exit=$($r.code)"; $r.out | Where-Object { $_ -match '   keep |done:|planned:' } | ForEach-Object { L "  | $_" }
    Check "install exit 0, done: written=$($N - 1) already-identical=0 kept=1 retired=0 refused=0" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=$($N - 1) already-identical=0 kept=1 retired=0 refused=0"))
    Check 'the host file stands' ((FileSha (Join-Path $t2 $tpl)) -eq (Sha $hostBytes))
    $lk = ReadLock $t2
    $row = @($lk.rows | Where-Object { $_.path -eq $tpl })[0]
    Check "the lock row: the host file's judged sha256, disposition kept, eol lf, kind template, upstream_sha256 the framework's" (($row.sha256 -eq (FoldSha $hostBytes)) -and ($row.disposition -ceq 'kept') -and ($row.eol -ceq 'lf') -and ($row.kind -ceq 'template') -and ($row.upstream_sha256 -eq $srcFold[$tpl]))
    $tpl2 = '.worktreeinclude'
    Check "$tpl2 is class TEMPLATE" ($owned[$tpl2].class -eq 'TEMPLATE')
    $tp2 = Join-Path $t2 $tpl2
    $fs = [System.IO.File]::Open($tp2, [System.IO.FileMode]::Append); try { $x = [System.Text.Encoding]::ASCII.GetBytes("# host edit after the install`n"); $fs.Write($x, 0, $x.Length) } finally { $fs.Dispose() }
    $edited = FileSha $tp2; $h2a = TreeHashes $t2
    $r = Run $installer @('-Target', $t2)
    L "a TEMPLATE edited after the install, a same-version run: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'CHANGED|MISSING|REFUSED|already installed' } | ForEach-Object { L "  | $_" }
    Check "the same-version run names $tpl2 CHANGED and nothing else, exit 3, writes nothing, and the host's edit stands" (($r.code -eq 3) -and ((Count $r.out ('CHANGED\s+' + [regex]::Escape($tpl2) + '\s')) -eq 1) -and ((Count $r.out '^install\.ps1:\s+(CHANGED|MISSING|REFUSED)\s') -eq 1) -and ((FileSha $tp2) -eq $edited) -and ((TreeHashes $t2).aggregate -eq $h2a.aggregate))

    L '--- b3: a MOVE file already present and different, with no framework.lock, is REFUSED not-installed-by-framework'
    $t3 = Join-Path $Work 't3'
    $own3 = 'tools/lam/mission-gate.ps1'
    WriteBytes (Join-Path $t3 ($own3 -replace '/', '\')) (Bytes "# a project's own file at a framework path`n")
    $h3a = TreeHashes $t3
    $r = Run $installer @('-Target', $t3)
    L "install: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | ForEach-Object { L "  | $_" }
    Check "exit 2, $own3 REFUSED not-installed-by-framework, the only refusal" (($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape($own3) + '\s+-- not-installed-by-framework')) -eq 1) -and ((Count $r.out '^install\.ps1: REFUSED \S') -eq 1))
    Check "planned: written=$($N - 1) already-identical=0 kept=0 retired=0 refused=1, and no other line carries written=" ((Has $r.out "install.ps1: planned: written=$($N - 1) already-identical=0 kept=0 retired=0 refused=1") -and ((Stray $r.out).Count -eq 0))
    Check 'nothing was written: the folder still holds only that one file' (((TreeHashes $t3).aggregate -eq $h3a.aggregate) -and ((TreeHashes $t3).count -eq 1))
}
'c' {
    $t = Join-Path $Work 't'
    $r = Run $installer @('-Target', $t)
    Check 'a fresh install for (c): exit 0' ($r.code -eq 0)
    $before = TreeHashes $t
    $lock0 = ReadLock $t
    $r = Run $installer @('-Target', $t)
    L "the same-version run: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check 'exit code 0' ($r.code -eq 0)
    Check 'it says already installed, verifies 0 differences, and writes nothing' ((Has $r.out "install.ps1: already installed: $Version in $t; nothing was written, and framework.lock is untouched.") -and ((Count $r.out "^install\.ps1: verify: $N file\(s\) listed, 0 difference\(s\); ") -eq 1))
    Check 'no line carries written=' ((Count $r.out 'written=') -eq 0)
    $after = TreeHashes $t
    Check 'the whole tree is unchanged, framework.lock included' (((DiffTrees $before $after).Count -eq 0) -and ($before.aggregate -eq $after.aggregate))
    Check 'framework.lock is byte-identical (installed_at did not move)' ((ReadLock $t).sha -eq $lock0.sha)
}
'd' {
    $clone = New-Clone (Join-Path $Work 'clone')
    $cOwned = OwnedSet (Join-Path $clone 'provenance\manifest.jsonl')
    $dist = Join-Path $clone 'dist'
    $shas = @(); $msums = @(); $ssums = @(); $z = $null
    foreach ($run in 1, 2) {
        Remove-Tree $dist
        Check "run ${run}: dist\ absent before the build" (-not (Test-Path -LiteralPath $dist))
        $z = Build-Zip $clone
        $shas += FileSha $z.zip
        $msums += FileSha $z.members
        $ssums += FileSha $z.sums
        $sums = [System.IO.File]::ReadAllText($z.sums)
        L "build $run SHA256SUMS: $($sums.TrimEnd() -replace "`n", ' | ')"
        Check "build ${run}: SHA256SUMS is two lines, LF: this ZIP's sha256 and name, then MEMBERS.sha256's" ($sums -ceq ($shas[-1] + "  $($z.name)" + "`n" + $msums[-1] + '  MEMBERS.sha256' + "`n"))
        Check "build ${run}: dist\ holds exactly $($z.name), MEMBERS.sha256 and SHA256SUMS" ((@(Get-ChildItem -LiteralPath $dist -Force | ForEach-Object { $_.Name } | Sort-Object) -join ',') -ceq ((@('SHA256SUMS', 'MEMBERS.sha256', $z.name) | Sort-Object) -join ','))
    }
    L "build 1: zip $($shas[0]) MEMBERS.sha256 $($msums[0]) SHA256SUMS $($ssums[0]); build 2: zip $($shas[1]) MEMBERS.sha256 $($msums[1]) SHA256SUMS $($ssums[1])"
    Check 'THE TWO BUILDS ARE EQUAL: the ZIP, MEMBERS.sha256 and SHA256SUMS, byte for byte' (($shas[0] -eq $shas[1]) -and ($msums[0] -eq $msums[1]) -and ($ssums[0] -eq $ssums[1]))
    $trackedAll = Sorted @((RunGit $clone @('-c', 'core.quotePath=false', 'ls-tree', '-r', '--full-tree', '--name-only', 'HEAD')).out | Where-Object { $_ })
    $fromHead = Sorted @($trackedAll | Where-Object { -not (Test-NotReleased $_) })
    $zi = Inspect-Zip $z.zip
    $gen = Sorted @($zi.names | Where-Object { $_.StartsWith('ui/dist/') -or $_ -ceq 'THIRD-PARTY-NOTICES' })
    L "zip: $($zi.count) entries; HEAD tracks $($trackedAll.Count), $($fromHead.Count) of them released; generated $($gen.Count); sorted $($zi.sorted); backslash $($zi.backslash); directories $($zi.dirs); timestamps not the epoch $($zi.badTime); attributes $($zi.attrs); extra fields $($zi.extras); comments $($zi.comments)"
    Check "the ZIP holds $($fromHead.Count + $gen.Count + 1) entries = HEAD's $($fromHead.Count) released paths + $($gen.Count) generated (ui/dist/**, THIRD-PARTY-NOTICES) + RELEASE, sorted, epoch timestamps, no attributes, no extra fields, no backslash, no directory entry, no comment" (
        ($zi.count -eq $fromHead.Count + $gen.Count + 1) -and $zi.sorted -and ($zi.backslash + $zi.dirs + $zi.badTime + $zi.attrs + $zi.extras + $zi.comments -eq 0))
    $notes = "docs/RELEASE-NOTES-v$($z.version).md"
    $expect = @($fromHead) + @($gen) + @('RELEASE')
    Check "the entry list equals HEAD's tracked paths less the dashboard's private source and the service's tests, + ui/dist/** + THIRD-PARTY-NOTICES + RELEASE, in ordinal order; the installer-owned set ($($cOwned.Count)) is among them" ((Same $zi.names (Sorted $expect)) -and (@($cOwned.Keys | Where-Object { $zi.names -cnotcontains $_ }).Count -eq 0))
    $leak = @($zi.names | Where-Object { Test-NotReleased $_ })
    Check "no member is private source or a service test: no ui/ path but ui/dist/, no tools/ui/tests/, no .ts/.tsx/.map, no node_modules ($($leak.Count))" (($leak.Count -eq 0) -and (@($gen | Where-Object { $_.StartsWith('ui/dist/') }).Count -gt 0) -and ($gen -ccontains 'THIRD-PARTY-NOTICES'))
    # The ZIP's manifest: HEAD's header and released rows, byte for byte and in order, then one generated MOVE row per generated member.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zr = [System.IO.Compression.ZipFile]::OpenRead($z.zip)
    try {
        $ms = New-Object System.IO.MemoryStream; $es = $zr.GetEntry('provenance/manifest.jsonl').Open(); try { $es.CopyTo($ms) } finally { $es.Dispose() }; $zmText = $NoBom.GetString($ms.ToArray())
        $ms = New-Object System.IO.MemoryStream; $es = $zr.GetEntry('THIRD-PARTY-NOTICES').Open(); try { $es.CopyTo($ms) } finally { $es.Dispose() }; $tpn = $NoBom.GetString($ms.ToArray())
    } finally { $zr.Dispose() }
    $hmLines = @([System.IO.File]::ReadAllText((Join-Path $clone 'provenance\manifest.jsonl')).Split([char]10) | Where-Object { $_ })
    $keptH = @($hmLines[0]) + @($hmLines | Select-Object -Skip 1 | Where-Object { -not (Test-NotReleased ([string](($_ | ConvertFrom-Json).destination))) })
    $zmLines = @($zmText.Split([char]10) | Where-Object { $_ })
    $zmGen = @($zmLines | Select-Object -Skip $keptH.Count | ForEach-Object { $_ | ConvertFrom-Json })
    $genBad = @($zmGen | Where-Object { ($_.source -cne 'host') -or ($_.class -cne 'MOVE') -or ((@($_.flags) -join ',') -cne 'generated') -or ($_.destination -cne $_.path) -or ($gen -cnotcontains [string]$_.destination) })
    Check "the ZIP's manifest is HEAD's -- its header and its $($keptH.Count - 1) released rows, byte for byte, in order -- then one row per generated member ($($zmGen.Count) = $($gen.Count)), each source host, class MOVE, flags generated" (
        (Same @($zmLines | Select-Object -First $keptH.Count) $keptH) -and ($zmGen.Count -eq $gen.Count) -and ($genBad.Count -eq 0) -and $zmText.EndsWith("`n"))
    $pins = @([regex]::Matches([System.IO.File]::ReadAllText((Join-Path $clone 'tools\ui\requirements.txt')), '(?m)^([A-Za-z0-9][A-Za-z0-9._-]*)==(\S+)') | ForEach-Object { "$($_.Groups[1].Value.ToLowerInvariant().Replace('_', '-')) $($_.Groups[2].Value)" })
    $pinMissing = @($pins | Where-Object { $tpn -notmatch ("(?m)^" + [regex]::Escape($_) + "$") })
    Check "THIRD-PARTY-NOTICES: LF, names every package tools/ui/requirements.txt pins ($($pins.Count), $($pinMissing.Count) missing) and the two OFL-1.1 font packages, and no local path" (
        (-not $tpn.Contains("`r")) -and ($pins.Count -gt 0) -and ($pinMissing.Count -eq 0) -and ([regex]::Matches($tpn, '(?m)^Licence: OFL-1\.1$').Count -eq 2) -and ($tpn -notmatch '[A-Za-z]:\\'))
    # MEMBERS.sha256 against the archive itself, each member's bytes read out of the ZIP and hashed here.
    $mText = $NoBom.GetString([System.IO.File]::ReadAllBytes($z.members))
    $mLines = @($mText.Split([char]10) | Select-Object -SkipLast 1)
    $mOk = $mText.EndsWith("`n") -and (-not $mText.Contains("`r")) -and ([System.IO.File]::ReadAllBytes($z.members)[0] -ne 0xEF)
    $mPaths = @($mLines | ForEach-Object { if ($_ -cmatch '^[0-9a-f]{64}  (.+)$') { $Matches[1] } else { '<malformed>' } })
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $za = [System.IO.Compression.ZipFile]::OpenRead($z.zip)
    $mBad = New-Object System.Collections.Generic.List[string]
    try {
        foreach ($ml in $mLines) {
            if ($ml -cnotmatch '^([0-9a-f]{64})  (.+)$') { $mBad.Add("malformed: $ml"); continue }
            $want = $Matches[1]; $mp = $Matches[2]
            $en = $za.GetEntry($mp)
            if ($null -eq $en) { $mBad.Add("not a member: $mp"); continue }
            $ms = New-Object System.IO.MemoryStream; $es = $en.Open(); try { $es.CopyTo($ms) } finally { $es.Dispose() }
            if ((Sha $ms.ToArray()) -ne $want) { $mBad.Add("sha256 differs: $mp") }
        }
    } finally { $za.Dispose() }
    L "MEMBERS.sha256: $($mLines.Count) line(s); faults $($mBad.Count)$(if ($mBad.Count) { ' -- ' + (@($mBad | Select-Object -First 3) -join '; ') })"
    Check "MEMBERS.sha256: LF, a final LF, no byte-order mark; one '<sha256>  <path>' line per member ($($zi.count)), in the ZIP's ordinal order, listing exactly the members; each sha256 the member's, hashed here" (
        $mOk -and ($mLines.Count -eq $zi.count) -and (Same $mPaths $zi.names) -and ($mBad.Count -eq 0))
    $tracked = (RunGit $clone @('ls-files', '--error-unmatch', '--', $notes)).code -eq 0
    Check "$notes is tracked at HEAD and IS a member of the ZIP" ($tracked -and ($zi.names -ccontains $notes))
    Check 'the acceptance wrapper tools/lam/instrument-acceptance.ps1 is a member of the ZIP, as an installer-owned file' ($cOwned.ContainsKey('tools/lam/instrument-acceptance.ps1') -and ($zi.names -ccontains 'tools/lam/instrument-acceptance.ps1'))
    $dRecs = @([System.IO.File]::ReadAllLines((Join-Path $clone 'provenance\manifest.jsonl')) | Select-Object -Skip 1 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { [string]$_.destination -match '^tests/lam/fixtures/(base-[0-9a-f]{8}(-s[0-9]{2})?|legacy-census-halts)/' })
    $dFx = @($cOwned.Keys | Where-Object { $_ -match '^tests/lam/fixtures/(base-[0-9a-f]{8}(-s[0-9]{2})?|legacy-census-halts)/' })
    $dMissing = @($dRecs | Where-Object { $zi.names -cnotcontains [string]$_.destination })
    # The seat-halt files and the base recipe are tracked, so they are members now -- as files the framework repository
    # keeps, never as installer-owned ones; no smoke fixture is tracked, so none is a member.
    $dKept = @($zi.names | Where-Object { $_ -match '^tests/lam/fixtures/(seat-halt/|synthetic-bases\.json$)' })
    Check "the $($dRecs.Count) base and legacy-census fixtures are members of the ZIP, as installer-owned files ($($dFx.Count) installer-owned, $($dMissing.Count) absent); no smoke-fixture file is; the $($dKept.Count) seat-halt and base-recipe files are, none installer-owned" (
        ($dRecs.Count -gt 0) -and ($dFx.Count -eq $dRecs.Count) -and ($dMissing.Count -eq 0) -and (@($zi.names | Where-Object { $_ -match '^tests/lam/fixtures/lam-smoke/' }).Count -eq 0) -and
        ($dKept.Count -gt 1) -and (@($dKept | Where-Object { $cOwned.ContainsKey($_) }).Count -eq 0))
}
'k1' {
    # A CLONE AT ITS TAG installs, and its lock is the ZIP install's but for where it came from.
    $tag = $Tagged.tag
    $t1 = Join-Path $Work 'p1'
    $null = New-Item -ItemType Directory -Path $t1
    Check 'git init in the first fresh project' ((RunGit $t1 @('init', '-q')).code -eq 0)
    $r = Run $installer @('-Target', $t1)
    L "install from the tagged clone: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0"
    $srcPat = '^install\.ps1: source .+ \(clone at tag ' + [regex]::Escape($tag) + ', commit ' + $Tagged.head + ', version ' + [regex]::Escape($Tagged.version) + '\)$'
    Check "exit 0, $done; the source line names the tag $tag and the commit $($Tagged.head)" (($r.code -eq 0) -and (Has $r.out $done) -and ((Count $r.out $srcPat) -eq 1))
    $lk1 = ReadLock $t1; $h1 = $lk1.header
    L "clone install lock header: $($lk1.lines[0])"
    Check "lock header: source_kind clone, source_tag $tag, source_commit = the clone's HEAD = framework_repo_tip ($($Tagged.head)), zip_sha256 null, version $($Tagged.version); the columns in order" (
        ($h1.source_kind -ceq 'clone') -and ($h1.source_tag -ceq $tag) -and ($h1.source_commit -ceq $Tagged.head) -and ($h1.framework_repo_tip -ceq $Tagged.head) -and ($null -eq $h1.zip_sha256) -and
        ($h1.version -ceq $Tagged.version) -and ((Names $h1) -ceq $HeaderColumns) -and ($lk1.rows.Count -eq $N))
    $v = Run $installer @('-Target', $t1, '-Verify')
    L "verify (clone install): exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    Check '-Verify of the clone install: exit 0, 0 difference(s)' (($v.code -eq 0) -and ((Count $v.out "^install\.ps1: verify: $N file\(s\) listed, 0 difference\(s\); ") -eq 1))
    Check 'the tagged clone is as it was: git status --porcelain empty' (SourceUnchanged $Tagged)
    L '--- the ZIP from the same HEAD, installed into a second fresh project'
    $rc = New-Clone (Join-Path $Work 'rel')
    $z = Build-Zip $rc
    $zsha = FileSha $z.zip
    $x = Join-Path $Work 'x'
    Expand-Archive -LiteralPath $z.zip -DestinationPath $x
    $t2 = Join-Path $Work 'p2'
    $null = New-Item -ItemType Directory -Path $t2
    Check 'git init in the second fresh project' ((RunGit $t2 @('init', '-q')).code -eq 0)
    # THE ZIP CARRIES MORE: the generated members (ui/dist/**, THIRD-PARTY-NOTICES) its own manifest names and a clone
    # of the development repository has not got. A clone of the PUBLIC repository is the expanded ZIP (k4).
    $zOwned = OwnedSet (Join-Path $x 'provenance\manifest.jsonl')
    $genOwned = Sorted @($zOwned.Keys | Where-Object { -not $owned.ContainsKey($_) })
    $NZ = $zOwned.Count
    $doneZ = "install.ps1: done: written=$NZ already-identical=0 kept=0 retired=0 refused=0"
    Check "the ZIP's installer-owned set is the clone's $N and the $($genOwned.Count) generated members, every one under ui/dist/ or THIRD-PARTY-NOTICES" (
        (@($owned.Keys | Where-Object { -not $zOwned.ContainsKey($_) }).Count -eq 0) -and ($genOwned.Count -gt 1) -and (@($genOwned | Where-Object { -not ($_.StartsWith('ui/dist/') -or $_ -ceq 'THIRD-PARTY-NOTICES') }).Count -eq 0))
    $r2 = Run (Join-Path $x 'install.ps1') @('-Target', $t2, '-ReleaseZip', $z.zip)
    L "install from the expanded ZIP: exit=$($r2.code)"; $r2.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    Check "the ZIP install: exit 0, $doneZ" (($r2.code -eq 0) -and (Has $r2.out $doneZ))
    $lk2 = ReadLock $t2; $h2 = $lk2.header
    L "ZIP install lock header: $($lk2.lines[0])"
    Check "the ZIP install's header: source_kind release, source_tag null, source_commit null, zip_sha256 the ZIP's ($zsha), framework_repo_tip HEAD, manifest_sha256 the ZIP's manifest's, installer_owned $NZ; the columns in order" (
        ($h2.source_kind -ceq 'release') -and ($null -eq $h2.source_tag) -and ($null -eq $h2.source_commit) -and ($h2.zip_sha256 -ceq $zsha) -and ($h2.framework_repo_tip -ceq $Tagged.head) -and ((Names $h2) -ceq $HeaderColumns) -and
        ($h2.manifest_sha256 -ceq (FileSha (Join-Path $x 'provenance\manifest.jsonl'))) -and ($h2.installer_owned -eq $NZ))
    $l1 = @($lk1.lines | Select-Object -Skip 1)
    $l2 = @($lk2.lines | Select-Object -Skip 1)
    $l2Shared = @($l2 | Where-Object { $p = ($_ | ConvertFrom-Json).path; $owned.ContainsKey($p) })
    $l2Gen = @($l2 | Where-Object { $p = ($_ | ConvertFrom-Json).path; -not $owned.ContainsKey($p) })
    Check "every file line of the clone's lock is the ZIP lock's line for that path, byte for byte and in order ($($l1.Count) and $($l2Shared.Count)); the ZIP lock's other $($l2Gen.Count) lines are the generated members, installed" (
        (Same $l1 $l2Shared) -and ($l1.Count -eq $N) -and ($l2Gen.Count -eq $genOwned.Count) -and (@($l2Gen | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { ($_.disposition -cne 'installed') -or ($_.kind -cne 'move') -or ($genOwned -cnotcontains $_.path) }).Count -eq 0))
    $skip = @('source_kind', 'source_tag', 'source_commit', 'zip_sha256', 'installed_at', 'upgraded_at', 'manifest_sha256', 'installer_owned')
    $hDiff = @(@($h1.PSObject.Properties | ForEach-Object { $_.Name }) | Where-Object { $skip -cnotcontains $_ } | Where-Object { (ConvertTo-Json -Compress $h1.$_) -cne (ConvertTo-Json -Compress $h2.$_) })
    Check "the two headers: the same columns in order, and every field but $($skip -join ', ') equal$(if ($hDiff.Count) { ' -- differ: ' + ($hDiff -join ', ') })" (((Names $h1) -ceq (Names $h2)) -and ($hDiff.Count -eq 0))
    $v2 = Run (Join-Path $x 'install.ps1') @('-Target', $t2, '-Verify')
    L "verify (ZIP install): exit=$($v2.code)"; $v2.out | ForEach-Object { L "  | $_" }
    Check '-Verify of the ZIP install: exit 0, 0 difference(s)' (($v2.code -eq 0) -and ((Count $v2.out "^install\.ps1: verify: $NZ file\(s\) listed, 0 difference\(s\); ") -eq 1))
    $x1 = Run (Join-Path $x 'install.ps1') @('-Target', $t1, '-Verify'); $x2 = Run $installer @('-Target', $t2, '-Verify')
    Check '-Verify never reads the source: the expanded ZIP''s installer verifies the clone install, and the clone''s the ZIP install, each exit 0' (($x1.code -eq 0) -and ($x2.code -eq 0))
    Check "-Repo's tags are as they were (the tag $tag was made in the clone only)" ((((RunGit $Repo @('tag', '-l')).out) -join ',') -ceq $repoTags)
}
'k2' {
    # A CLONE OFF ITS TAG is REFUSED, before anything is judged or written.
    $tag = $Tagged.tag
    $c = New-TaggedClone -Dest (Join-Path $Work 'k2-clone') -NoTag
    function OffTag { param([string]$Where) return ('^' + [regex]::Escape("install.ps1: REFUSED: the source checkout is not at tag $tag (HEAD $($c.head); tag $tag $Where) -- install from a clone at the release tag, or from the release ZIP")) }
    Check "the clone carries no tag ($(((RunGit $c.root @('tag', '-l')).out) -join ','))" (@((RunGit $c.root @('tag', '-l')).out | Where-Object { $_ }).Count -eq 0)
    $tA = Join-Path $Work 'pA'
    WriteBytes (Join-Path $tA 'keep.txt') (Bytes "a project's own file`n")
    $hA = TreeHashes $tA
    $tN = Join-Path $Work 'pN'
    foreach ($leg in @(@{ name = 'the tag absent'; where = 'absent' }, @{ name = 'the tag on another commit'; where = 'other' })) {
        $where = $leg.where
        if ($where -eq 'other') {
            $prev = ((RunGit $c.root @('rev-parse', 'HEAD~1')).out -join '').Trim()
            Check "the tag $tag made in the clone at HEAD~1, $prev" ((RunGit $c.root @('tag', $tag, $prev)).code -eq 0)
            $where = "at $prev"
        }
        $r = Run $c.installer @('-Target', $tA)
        L "($($leg.name)) install: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        Check "($($leg.name)) exit 1, and the one line: install.ps1: REFUSED: the source checkout is not at tag $tag (HEAD ...; tag $tag $where) -- ..." (($r.code -eq 1) -and ((Count $r.out (OffTag $where)) -eq 1) -and ((Count $r.out '^install\.ps1: REFUSED:') -eq 1))
        Check "($($leg.name)) nothing judged and nothing written: no per-file line, no counts, the target as it was, no framework.lock" (((Count $r.out '^install\.ps1:   ') -eq 0) -and ((Count $r.out 'written=') -eq 0) -and ((TreeHashes $tA).aggregate -eq $hA.aggregate) -and -not (Test-Path -LiteralPath (Join-Path $tA 'framework.lock')))
        $w = Run $c.installer @('-Target', $tN, '-WhatIf')
        Check "($($leg.name)) -WhatIf, into a folder that does not exist: refused the same, exit 1, and the folder not created" (($w.code -eq 1) -and ((Count $w.out (OffTag $where)) -eq 1) -and -not (Test-Path -LiteralPath $tN))
    }
    $tV = Join-Path $Work 'pV'
    $r = Run $installer @('-Target', $tV)
    $v = Run $c.installer @('-Target', $tV, '-Verify')
    L "-Verify from the clone off its tag, over a project the tagged clone installed: exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    Check '-Verify never reads the source: the off-tag clone verifies a project the tagged clone installed, exit 0, 0 difference(s)' (($r.code -eq 0) -and ($v.code -eq 0) -and ((Count $v.out "^install\.ps1: verify: $N file\(s\) listed, 0 difference\(s\); ") -eq 1))
    Check "-Repo's tags are as they were" ((((RunGit $Repo @('tag', '-l')).out) -join ',') -ceq $repoTags)
}
'k3' {
    # A CLONE AT ITS TAG WITH A LOCAL CHANGE is REFUSED; an ignored file is not a change.
    $c = New-TaggedClone -Dest (Join-Path $Work 'k3-clone')
    $dirty = '^' + [regex]::Escape('install.ps1: REFUSED: the source checkout has local changes (git status --porcelain is not empty) -- install from a clean clone at the release tag')
    # A tracked file the installer neither installs nor reads; an installer-owned file changed is k4's first leg, refused
    # the same way, since the clone's state is asked before any source file is held to the manifest.
    $tracked = @((RunGit $c.root @('ls-files')).out | Where-Object { $_ })
    $edit = 'README.md'
    if (($tracked -cnotcontains $edit) -or $owned.ContainsKey($edit)) { $edit = @($tracked | Where-Object { -not $owned.ContainsKey($_) -and @('VERSION', 'install.ps1', 'provenance/manifest.jsonl') -cnotcontains $_ })[0] }
    $ep = Join-Path $c.root ($edit -replace '/', '\')
    $tA = Join-Path $Work 'pA'
    WriteBytes (Join-Path $tA 'keep.txt') (Bytes "a project's own file`n")
    $hA = TreeHashes $tA
    $tN = Join-Path $Work 'pN'
    foreach ($leg in @('modified', 'untracked')) {
        $probe = 'k3-untracked.txt'
        if ($leg -eq 'modified') { $before = [System.IO.File]::ReadAllBytes($ep); WriteBytes $ep ([byte[]]($before + (Bytes "a local change`n"))); $named = $edit }
        else { WriteBytes (Join-Path $c.root $probe) (Bytes "an untracked file`n"); $named = $probe }
        Check "($leg) the clone's git status --porcelain names $named" ((Count (RunGit $c.root @('status', '--porcelain')).out ([regex]::Escape($named))) -eq 1)
        foreach ($t in @($tA, $tN)) {
            $r = Run $c.installer @('-Target', $t)
            L "($leg) install into $t`: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
            Check "($leg, into $(if ($t -eq $tN) { 'a folder that does not exist' } else { 'a folder with a file of its own' })) exit 1, a LOCAL CHANGE line naming $named, and the one line: install.ps1: REFUSED: the source checkout has local changes (git status --porcelain is not empty) -- ..." (
                ($r.code -eq 1) -and ((Count $r.out $dirty) -eq 1) -and ((Count $r.out '^install\.ps1: REFUSED:') -eq 1) -and ((Count $r.out ('^install\.ps1:   LOCAL CHANGE  .*' + [regex]::Escape($named) + '$')) -eq 1))
        }
        Check "($leg) nothing judged and nothing written: the target as it was, no framework.lock; the folder that did not exist not created" (((TreeHashes $tA).aggregate -eq $hA.aggregate) -and -not (Test-Path -LiteralPath (Join-Path $tA 'framework.lock')) -and -not (Test-Path -LiteralPath $tN))
        if ($leg -eq 'modified') { $null = RunGit $c.root @('checkout', '--', $edit) } else { [System.IO.File]::Delete((Join-Path $c.root $probe)) }
        Check "($leg) undone: git status --porcelain empty again" (SourceUnchanged $c)
    }
    L '--- an ignored file is not a local change'
    $ig = 'dist/k3-ignored.txt'
    WriteBytes (Join-Path $c.root ($ig -replace '/', '\')) (Bytes "a file .gitignore ignores`n")
    Check "$ig is ignored (git check-ignore), and git status --porcelain stays empty" (((RunGit $c.root @('check-ignore', '-q', '--', $ig)).code -eq 0) -and (SourceUnchanged $c))
    $tI = Join-Path $Work 'pI'
    $r = Run $c.installer @('-Target', $tI)
    L "install with only an ignored file beside the tree: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|done:|^install\.ps1: source ' } | ForEach-Object { L "  | $_" }
    Check "exit 0, done: written=$N; the lock source_kind clone at $($c.tag)" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0") -and ((ReadLock $tI).header.source_kind -ceq 'clone') -and ((ReadLock $tI).header.source_tag -ceq $c.tag))
}
'k4' {
    # A SOURCE HOLDING .git IS A CLONE AND NOTHING ELSE: held to its tag and its status before any file of it is read,
    # and never taken for an expanded release when git cannot answer for it.
    $tag = $Tagged.tag
    $tA = Join-Path $Work 'pA'
    WriteBytes (Join-Path $tA 'keep.txt') (Bytes "a project's own file`n")
    $hA = TreeHashes $tA
    $tN = Join-Path $Work 'pN'
    function Untouched { return (((TreeHashes $tA).aggregate -eq $hA.aggregate) -and -not (Test-Path -LiteralPath (Join-Path $tA 'framework.lock')) -and -not (Test-Path -LiteralPath $tN)) }
    $oneRefusal = '^install\.ps1: REFUSED:'
    $unconf = '^' + [regex]::Escape('install.ps1: REFUSED: the source holds .git but git cannot confirm it is a clean checkout at the release tag (')

    L '--- (owned) a clone at its tag with an installer-owned file edited'
    $c = New-TaggedClone -Dest (Join-Path $Work 'k4-clone')
    $dirty = '^' + [regex]::Escape('install.ps1: REFUSED: the source checkout has local changes (git status --porcelain is not empty) -- install from a clean clone at the release tag')
    $edit = $mv
    if (-not $owned.ContainsKey($edit) -or $owned[$edit].class -ne 'MOVE') { $edit = @($owned.Keys | Where-Object { $owned[$_].class -eq 'MOVE' -and @('install.ps1', 'VERSION') -cnotcontains $_ })[0] }
    $ep = Join-Path $c.root ($edit -replace '/', '\')
    WriteBytes $ep ([byte[]]([System.IO.File]::ReadAllBytes($ep) + (Bytes "a local change`n")))
    Check "(owned) $edit is an installer-owned MOVE file, and the clone's git status --porcelain names it" (($owned[$edit].class -eq 'MOVE') -and ((Count (RunGit $c.root @('status', '--porcelain')).out ([regex]::Escape($edit))) -eq 1))
    foreach ($t in @($tA, $tN)) {
        $r = Run $c.installer @('-Target', $t)
        L "(owned) install into $t`: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        Check "(owned, into $(if ($t -eq $tN) { 'a folder that does not exist' } else { 'a folder with a file of its own' })) exit 1, a LOCAL CHANGE line naming $edit, the one line: install.ps1: REFUSED: the source checkout has local changes ... -- and no SOURCE FAULT or MANIFEST line: the clone is refused before its files are held to the manifest" (
            ($r.code -eq 1) -and ((Count $r.out $dirty) -eq 1) -and ((Count $r.out $oneRefusal) -eq 1) -and ((Count $r.out ('^install\.ps1:   LOCAL CHANGE  .*' + [regex]::Escape($edit) + '$')) -eq 1) -and
            ((Count $r.out 'SOURCE FAULT|MANIFEST FAULT|NOT THE MANIFEST') -eq 0))
    }
    Check '(owned) nothing judged and nothing written: the target as it was, no framework.lock; the folder that did not exist not created' (Untouched)
    $null = RunGit $c.root @('checkout', '--', $edit)
    Check '(owned) undone: git status --porcelain empty again' (SourceUnchanged $c)

    L '--- (ignored RELEASE) a well-formed RELEASE that .git/info/exclude ignores, in a clean clone at its tag'
    $excl = Join-Path $c.root '.git\info\exclude'
    $exBefore = $null
    if (Test-Path -LiteralPath $excl -PathType Leaf) { $exBefore = [System.IO.File]::ReadAllBytes($excl) }
    $exText = ''
    if ($null -ne $exBefore) { $exText = $L1.GetString($exBefore) }
    WriteBytes $excl (Bytes ($exText + "`nRELEASE`n"))
    $relFake = 'f' * 40
    [System.IO.File]::WriteAllText((Join-Path $c.root 'RELEASE'), "name: vanguard-collective`nversion: $($c.version)`nframework_repo_tip: $relFake`nmanifest_sha256: $(FileSha (Join-Path $c.root 'provenance\manifest.jsonl'))`n", $NoBom)
    Check '(ignored RELEASE) git check-ignore names RELEASE, git status --porcelain stays empty, and HEAD tracks no RELEASE' (
        ((RunGit $c.root @('check-ignore', '-q', '--', 'RELEASE')).code -eq 0) -and (SourceUnchanged $c) -and ((RunGit $c.root @('cat-file', '-e', 'HEAD:RELEASE')).code -ne 0))
    $relRefused = '^' + [regex]::Escape('install.ps1: REFUSED: the source checkout holds a RELEASE file that HEAD does not track (git ignores it, so git status does not list it)')
    $r = Run $c.installer @('-Target', $tA)
    L "(ignored RELEASE) install: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check '(ignored RELEASE) exit 1, the one line: install.ps1: REFUSED: the source checkout holds a RELEASE file that HEAD does not track ...; nothing judged or written' (
        ($r.code -eq 1) -and ((Count $r.out $relRefused) -eq 1) -and ((Count $r.out $oneRefusal) -eq 1) -and ((Count $r.out '^install\.ps1:   ') -eq 0) -and (Untouched))
    $w = Run $c.installer @('-Target', $tN, '-WhatIf')
    Check '(ignored RELEASE) -WhatIf, into a folder that does not exist: refused the same, exit 1, and the folder not created' (($w.code -eq 1) -and ((Count $w.out $relRefused) -eq 1) -and -not (Test-Path -LiteralPath $tN))
    [System.IO.File]::Delete((Join-Path $c.root 'RELEASE'))
    if ($null -eq $exBefore) { [System.IO.File]::Delete($excl) } else { [System.IO.File]::WriteAllBytes($excl, $exBefore) }
    Check '(ignored RELEASE) undone: no RELEASE, git status --porcelain empty' ((-not (Test-Path -LiteralPath (Join-Path $c.root 'RELEASE'))) -and (SourceUnchanged $c))

    L '--- (tag case) a clone whose only tag is V<VERSION>, of another case'
    $cc = New-TaggedClone -Dest (Join-Path $Work 'k4-case') -NoTag
    $upper = 'V' + $cc.version
    Check "(tag case) the clone carries no tag, then the one tag $upper at HEAD" ((@((RunGit $cc.root @('tag', '-l')).out | Where-Object { $_ }).Count -eq 0) -and ((RunGit $cc.root @('tag', $upper, $cc.head)).code -eq 0))
    $caseRefused = '^' + [regex]::Escape("install.ps1: REFUSED: the source checkout is not at tag $tag (HEAD $($cc.head); tag $tag absent; $upper differs from it in case) -- install from a clone at the release tag, or from the release ZIP")
    foreach ($form in @('loose', 'packed')) {
        if ($form -eq 'packed') { Check '(tag case) git pack-refs --all' ((RunGit $cc.root @('pack-refs', '--all')).code -eq 0) }
        $r = Run $cc.installer @('-Target', $tA)
        L "(tag case, $form ref) install: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        Check "(tag case, $form ref) exit 1, the one line: install.ps1: REFUSED: the source checkout is not at tag $tag (HEAD ...; tag $tag absent; $upper differs from it in case) -- ...; nothing written" (
            ($r.code -eq 1) -and ((Count $r.out $caseRefused) -eq 1) -and ((Count $r.out $oneRefusal) -eq 1) -and (Untouched))
    }

    L '--- (no git) a clean clone at its tag, run with no git on PATH'
    $savedPath = $env:PATH
    $noGit = $false
    try {
        $env:PATH = (@($savedPath.Split(';') | Where-Object { $d = $_.TrimEnd('\'); $_ -and -not (@('git.exe', 'git.cmd', 'git.bat', 'git.com') | Where-Object { [System.IO.File]::Exists($d + '\' + $_) }) }) -join ';')
        $noGit = ($null -eq (Get-Command git -CommandType Application -ErrorAction SilentlyContinue))
        $r = Run $installer @('-Target', $tA)
    } finally { $env:PATH = $savedPath }
    L "(no git) install: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check "(no git) git is not on PATH for the run ($noGit); exit 1, the one line: install.ps1: REFUSED: the source holds .git but git cannot confirm ... (git could not be started ...); no source line; nothing written" (
        $noGit -and ($r.code -eq 1) -and ((Count $r.out ($unconf + [regex]::Escape('git could not be started'))) -eq 1) -and ((Count $r.out $oneRefusal) -eq 1) -and
        ((Count $r.out '^install\.ps1: source ') -eq 0) -and (Untouched))

    L '--- (junction) the tagged clone reached through a junction is the clone'
    $jn = Join-Path $Work 'jn'
    $null = New-Item -ItemType Junction -Path $jn -Target $Tagged.root
    $tJ = Join-Path $Work 'pJ'
    $r = Run (Join-Path $jn 'install.ps1') @('-Target', $tJ, '-WhatIf')
    L "(junction) -WhatIf: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    Check "(junction) -WhatIf through the junction: exit 0, no REFUSED line, the source line names the clone at tag $tag, commit $($Tagged.head)" (
        ($r.code -eq 0) -and ((Count $r.out $oneRefusal) -eq 0) -and ((Count $r.out ('^install\.ps1: source .+ \(clone at tag ' + [regex]::Escape($tag) + ', commit ' + $Tagged.head + ', ')) -eq 1))
    [System.IO.Directory]::Delete($jn, $false)

    L '--- (unusable .git) an expanded release given a .git file that names no repository'
    $rc = New-Clone (Join-Path $Work 'rel')
    $z = Build-Zip $rc
    $x = Join-Path $Work 'x'
    Expand-Archive -LiteralPath $z.zip -DestinationPath $x
    $xi = Join-Path $x 'install.ps1'
    $w = Run $xi @('-Target', (Join-Path $Work 'pW'), '-WhatIf')
    Check '(unusable .git) control: with no .git the expansion is an expanded release, -WhatIf exit 0 and its source line says release' (
        ($w.code -eq 0) -and ((Count $w.out '^install\.ps1: source .+ \(release at [0-9a-f]{40}, version ') -eq 1))
    [System.IO.File]::WriteAllText((Join-Path $x '.git'), "gitdir: $(Join-Path $Work 'no-such-repository\.git')`n", $NoBom)
    foreach ($t in @($tA, $tN)) {
        $r = Run $xi @('-Target', $t)
        L "(unusable .git) install into $t`: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        Check "(unusable .git, into $(if ($t -eq $tN) { 'a folder that does not exist' } else { 'a folder with a file of its own' })) exit 1, the one line: install.ps1: REFUSED: the source holds .git but git cannot confirm ... (git rev-parse exited ...); no source line: never installed as a release" (
            ($r.code -eq 1) -and ((Count $r.out ($unconf + [regex]::Escape('git rev-parse exited '))) -eq 1) -and ((Count $r.out $oneRefusal) -eq 1) -and ((Count $r.out '^install\.ps1: source ') -eq 0))
    }
    Check '(unusable .git) nothing written: the target as it was, no framework.lock; the folder that did not exist not created' (Untouched)
    [System.IO.File]::Delete((Join-Path $x '.git'))

    L '--- (tracked RELEASE) the expanded ZIP committed as a repository of its own and tagged'
    $xr = Join-Path $Work 'xr'
    Expand-Archive -LiteralPath $z.zip -DestinationPath $xr
    $null = RunGit $xr @('init', '-q'); $null = RunGit $xr @('config', 'core.autocrlf', 'false'); $null = RunGit $xr @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $xr @('config', 'user.email', 'falsifier-fixture@localhost')
    $null = RunGit $xr @('add', '-A', '-f')
    Check '(tracked RELEASE) git commit, git tag, RELEASE tracked at HEAD, git status --porcelain empty' (
        ((RunGit $xr @('commit', '-q', '-m', 'the expanded release')).code -eq 0) -and ((RunGit $xr @('tag', $tag)).code -eq 0) -and ((RunGit $xr @('cat-file', '-e', 'HEAD:RELEASE')).code -eq 0) -and
        ((@((RunGit $xr @('status', '--porcelain')).out | Where-Object { $_ })).Count -eq 0))
    $xrHead = ((RunGit $xr @('rev-parse', 'HEAD')).out -join '').Trim()
    $tR = Join-Path $Work 'pR'
    $r = Run (Join-Path $xr 'install.ps1') @('-Target', $tR)
    L "(tracked RELEASE) install: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    $hR = $null
    if (Test-Path -LiteralPath (Join-Path $tR 'framework.lock')) { $hR = (ReadLock $tR).header; L "(tracked RELEASE) lock header: $((ReadLock $tR).lines[0])" }
    Check "(tracked RELEASE) exit 0; the lock source_kind clone, source_tag $tag, source_commit the repository's own HEAD ($xrHead), framework_repo_tip RELEASE's ($head), the two different" (
        ($r.code -eq 0) -and ($null -ne $hR) -and ($hR.source_kind -ceq 'clone') -and ($hR.source_tag -ceq $tag) -and ($hR.source_commit -ceq $xrHead) -and ($hR.framework_repo_tip -ceq $head) -and ($xrHead -cne $head))
    Check "-Repo's tags are as they were" ((((RunGit $Repo @('tag', '-l')).out) -join ',') -ceq $repoTags)
}
{ $_ -in 'e', 'f', 'g', 'u7' } {
    $clone = New-Clone (Join-Path $Work 'clone')
    $z = Build-Zip $clone
    $cOwned = OwnedSet (Join-Path $clone 'provenance\manifest.jsonl')
    # The members (case d holds them to the rule): HEAD's released paths, the generated ones and RELEASE.
    $releasedHead = @((RunGit $clone @('-c', 'core.quotePath=false', 'ls-tree', '-r', '--full-tree', '--name-only', 'HEAD')).out | Where-Object { $_ -and -not (Test-NotReleased $_) }).Count
    $memberCount = (Inspect-Zip $z.zip).count
    $zsha = FileSha $z.zip
    L "zip $($z.zip) sha256 $zsha; members $memberCount ($releasedHead of HEAD's paths, the generated ones and RELEASE)"
    $x = Join-Path $Work 'x'
    if ($Case -ne 'u7') { Expand-Archive -LiteralPath $z.zip -DestinationPath $x; Use-ReleaseSet $x }
}
}

switch ($Case) {
'e' {
    $sums = [System.IO.File]::ReadAllText($z.sums)
    Check 'the ZIP matches its SHA256SUMS (the first line, the ZIP''s)' ($sums.StartsWith($zsha + "  $($z.name)" + "`n", [System.StringComparison]::Ordinal))
    $xt = TreeHashes $x
    Check "the expansion holds $memberCount files, the ZIP's entries ($releasedHead of HEAD's paths, the generated ones and RELEASE)" ($xt.count -eq $memberCount)
    $rel = [System.IO.File]::ReadAllText((Join-Path $x 'RELEASE'))
    L "RELEASE:`n$rel"
    Check "RELEASE names version $($z.version), this HEAD and the sha256 of the ZIP's manifest" (($rel -match "(?m)^version: $([regex]::Escape($z.version))$") -and ($rel -match "framework_repo_tip: $head") -and ($rel -match ('manifest_sha256: ' + (FileSha (Join-Path $x 'provenance\manifest.jsonl')))))
    $blobAt = @{}; foreach ($ent in ((RunGit $clone @('ls-tree', '-r', '--full-tree', 'HEAD')).out)) { if ($ent -match '^\d{6} blob ([0-9a-f]{40})\t(.+)$') { $blobAt[$Matches[2]] = $Matches[1] } }
    $fromHeadX = @($xt.map.Keys | Where-Object { $blobAt.ContainsKey($_) -and $_ -ne 'provenance/manifest.jsonl' })
    $badBlob = @($fromHeadX | Where-Object { (BlobId ([System.IO.File]::ReadAllBytes((Join-Path $x ($_ -replace '/', '\'))))) -ne $blobAt[$_] })
    $notHead = @($xt.map.Keys | Where-Object { -not $blobAt.ContainsKey($_) -and $_ -cne 'RELEASE' -and -not ($_.StartsWith('ui/dist/') -or $_ -ceq 'THIRD-PARTY-NOTICES') })
    Check "every expanded member taken from HEAD ($($fromHeadX.Count)) equals its blob, by git blob id computed here; every other is RELEASE, the manifest or generated ($($notHead.Count) else)" (($badBlob.Count -eq 0) -and ($notHead.Count -eq 0) -and ($fromHeadX.Count -eq $releasedHead - 1))
    $t = Join-Path $Work 't'
    $r = Run (Join-Path $x 'install.ps1') @('-Target', $t, '-ReleaseZip', $z.zip)
    L "install from the expanded ZIP: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0"
    Check "install exit 0, done: written=$N" (($r.code -eq 0) -and (Has $r.out $done))
    $lk = ReadLock $t
    L "lock header: $($lk.lines[0])"
    Check "lock: lock_format 2, source_kind release, framework_repo_tip = HEAD, zip_sha256 = the ZIP, eol_rule, $N rows" (($lk.header.lock_format -eq 2) -and ($lk.header.source_kind -eq 'release') -and ($lk.header.framework_repo_tip -eq $head) -and ($lk.header.zip_sha256 -eq $zsha) -and ($lk.header.eol_rule -ceq 'fold-crlf-text') -and ($lk.rows.Count -eq $N))
    CheckRows2 $lk '(e)' 'installed'
    CheckLockAgainstSource $lk '(e)'
    L '--- the counts INSTALL.md and README.md state, against this install from the ZIP'
    $ve = Run (Join-Path $x 'install.ps1') @('-Target', $t, '-Verify')
    $ec = EolCensus $lk.rows
    $vline = "install.ps1: verify: $N file(s) listed, 0 difference(s); eol lf=$($ec.lf) crlf=$($ec.crlf) mixed=$($ec.mixed) binary=$($ec.binary)."
    Check "-Verify exit 0, its last line: $vline" (($ve.code -eq 0) -and (Has $ve.out $vline))
    $im = DocText (Join-Path $Repo 'INSTALL.md'); $rm = DocText (Join-Path $Repo 'README.md')
    $classes = @(@('MOVE', 'TEMPLATE', 'HOST-CONFIG') | ForEach-Object { $c = $_; @($owned.Values | Where-Object { $_.class -eq $c }).Count })
    $mline = @($r.out | Where-Object { $_ -match '^install\.ps1: manifest sha256 ' }) -join ''
    $longest = (@($owned.Keys | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum
    Check "INSTALL.md: the longest installed path is $(DocInt $im 'the longest installed path is (\d+) characters') characters = $longest, measured over the release's set" ((DocInt $im 'the longest installed path is (\d+) characters') -eq $longest)
    $m = [regex]::Match($im, 'installer-owned (\d+) \(MOVE (\d+), TEMPLATE (\d+), HOST-CONFIG (\d+)\); framework\.lock absent')
    Check "INSTALL.md's expected output: installer-owned $($m.Groups[1].Value) (MOVE $($m.Groups[2].Value), TEMPLATE $($m.Groups[3].Value), HOST-CONFIG $($m.Groups[4].Value)) = the installer's own line" ($m.Success -and ($mline -cmatch [regex]::Escape($m.Value)))
    $dd = [regex]::Match($im, 'done: written=\d+ already-identical=\d+ kept=\d+ retired=\d+ refused=\d+')
    Check "INSTALL.md's expected output: '$($dd.Value)' = this install's counts line" ($dd.Success -and ($done -ceq ('install.ps1: ' + $dd.Value)))
    $wl = [regex]::Match($im, 'framework\.lock written: (\d+) line\(s\) for (\d+) file\(s\)')
    Check "INSTALL.md: framework.lock written: $($wl.Groups[1].Value) line(s) for $($wl.Groups[2].Value) file(s) = this install's lock ($($lk.lines.Count) for $N)" ($wl.Success -and ([int]$wl.Groups[1].Value -eq $lk.lines.Count) -and ([int]$wl.Groups[2].Value -eq $N) -and ((Count $r.out ('^install\.ps1: ' + [regex]::Escape($wl.Value) + ', sha256 [0-9a-f]{64}$')) -eq 1))
    $vm = [regex]::Match($im, 'verify: \d+ file\(s\) listed, 0 difference\(s\); eol lf=\d+ crlf=\d+ mixed=\d+ binary=\d+\.')
    Check "INSTALL.md: '$($vm.Value)' = this -Verify's last line" ($vm.Success -and ($vline -ceq ('install.ps1: ' + $vm.Value)))
    $tw = DocInt $im '(\w+) TEMPLATE and (\w+) HOST-CONFIG lines' 1; $hw = DocInt $im '(\w+) TEMPLATE and (\w+) HOST-CONFIG lines' 2
    Check "INSTALL.md: the $tw TEMPLATE and $hw HOST-CONFIG lines = the manifest's $($classes[1]) and $($classes[2])" (($tw -eq $classes[1]) -and ($hw -eq $classes[2]))
    $ll = DocInt $im '(\d+) lines for the (\d+)' 1; $lf2 = DocInt $im '(\d+) lines for the (\d+)' 2
    Check "INSTALL.md: $ll lines for the $lf2 = this install's lock" (($ll -eq $lk.lines.Count) -and ($lf2 -eq $N))
    $rn = DocInt $rm '\((\d+) files in the release'
    Check "README.md: ($rn files in the release ...) = the release's installer-owned set, $N" ($rn -eq $N)
    # THE ROOT .gitignore init makes ignore Claude Code's per-checkout files (mission.ps1's header): the target has none.
    $giT = Join-Path $t '.gitignore'
    $giBefore = Test-Path -LiteralPath $giT
    function GiIgnored { param([string]$Dir)
        # WP-1 H-26's reading, git check-ignore -q --no-index (0 ignored, 1 not): the two per-checkout paths
        # ignored, and .claude/settings.json, the tracked registration, not.
        return (((RunGit $Dir @('check-ignore', '-q', '--no-index', '.claude/settings.local.json')).code -eq 0) -and
            ((RunGit $Dir @('check-ignore', '-q', '--no-index', '.claude/worktrees/x')).code -eq 0) -and
            ((RunGit $Dir @('check-ignore', '-q', '--no-index', '.claude/settings.json')).code -eq 1))
    }
    $r = Run (Join-Path $x 'mission.ps1') @('init', '-Target', $t)
    L "mission init: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check 'mission init exit 0' ($r.code -eq 0)
    $giLines = @($r.out | Where-Object { $_ -match '^mission\.ps1:   \.gitignore ' })
    $giS = if (Test-Path -LiteralPath $giT -PathType Leaf) { $L1.GetString([System.IO.File]::ReadAllBytes($giT)) } else { '' }
    $giRows = @($giS.TrimEnd("`n").Split([char]10))
    Check 'the target had no .gitignore; init CREATED it, its one .gitignore line saying so: a "# " comment line, then /.claude/settings.local.json, /.claude/worktrees/ and /.mission-runtime/ (RELEASE-4 S1 F-P7a), LF, no BOM, nothing else' (
        (-not $giBefore) -and ($giLines.Count -eq 1) -and ($giLines[0] -cmatch '^mission\.ps1:   \.gitignore created: it ignores /\.claude/settings\.local\.json and /\.claude/worktrees/ and /\.mission-runtime/ \(') -and
        $giS.EndsWith("`n") -and (-not $giS.Contains("`r")) -and (-not $giS.StartsWith([string][char]0xEF)) -and ($giRows.Count -eq 4) -and $giRows[0].StartsWith('# ') -and
        ($giRows[1] -ceq '/.claude/settings.local.json') -and ($giRows[2] -ceq '/.claude/worktrees/') -and ($giRows[3] -ceq '/.mission-runtime/'))
    $curBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($t, '.mission', 'spec', 'current.txt'))
    Check 'spec/current.txt is the token v001 (4 bytes) and spec/v001.yaml exists' (([System.Text.Encoding]::ASCII.GetString($curBytes) -ceq 'v001') -and (Test-Path -LiteralPath ([System.IO.Path]::Combine($t, '.mission', 'spec', 'v001.yaml')) -PathType Leaf))
    # THE FIRST DRAFT ACCEPTED. spec-accept runs at the project root of a git repository with a clean tree, so the
    # target is made one and committed whole. Each refusal runs over a committed variant: REFUSED, exit 1, its reason
    # named, HEAD and the .mission tree unchanged and the tree clean; the variant is then reset away.
    L '--- e2 the installed spec-accept over the draft v001: three refusals, the acceptance, a second acceptance refused'
    $null = RunGit $t @('init', '-q'); $null = RunGit $t @('config', 'core.autocrlf', 'false')
    $null = RunGit $t @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $t @('config', 'user.email', 'falsifier-fixture@localhost')
    $null = RunGit $t @('add', '-A'); $g = RunGit $t @('commit', '-q', '-m', 'the installed framework and the initialised mission')
    function HeadOf { return ((RunGit $t @('rev-parse', 'HEAD')).out -join '').Trim() }
    function CleanAt { return ((RunGit $t @('status', '--porcelain')).code -eq 0) -and (@((RunGit $t @('status', '--porcelain')).out).Count -eq 0) }
    function SpecAccept { param([string[]]$A)
        # -NonInteractive: a mandatory parameter left out is refused at once, never prompted for.
        Push-Location -LiteralPath $t
        $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = @(& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $t 'tools\mission-spec-accept.ps1') @A 2>&1); $c = $LASTEXITCODE }
        finally { $ErrorActionPreference = $p; Pop-Location }
        $s = [pscustomobject]@{ code = $c; out = @($o | ForEach-Object { "$_" }) }
        L "  spec-accept $($A -join ' '): exit=$($s.code)"; $s.out | Where-Object { $_ -match '\[(PASS|FAIL)\]|ABORTED|accepted from draft|commit' } | ForEach-Object { L "    | $_" }
        return $s
    }
    $h0 = HeadOf
    $spec0 = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($t, '.mission', 'spec', 'v001.yaml'))
    $mission0 = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($t, '.mission', 'mission.yaml'))
    Check 'the target is a git repository: the installed framework and the initialised mission committed, the tree clean' (($g.code -eq 0) -and ($h0 -match '^[0-9a-f]{40}$') -and (CleanAt))
    Check 'init''s .gitignore is committed at HEAD, and under it git check-ignore --no-index reads .claude/settings.local.json and .claude/worktrees/x ignored and .claude/settings.json not (WP-1 H-26''s reading)' (
        ((@((RunGit $t @('ls-tree', '--name-only', 'HEAD', '--', '.gitignore')).out) -join '') -ceq '.gitignore') -and (GiIgnored $t))
    $variants = @(
        @('a non-draft v001 (its state: line reads review)', @('-ProposalVersion', 'v001', '-Confirm'), "spec/v001.yaml is not a draft: its state: line reads 'review'",
          { WriteBytes ([System.IO.Path]::Combine($t, '.mission', 'spec', 'v001.yaml')) (Bytes ($L1.GetString($spec0).Replace("`nstate: draft`n", "`nstate: review`n"))) }),
        @('a second version beside v001 (spec/v002.yaml)', @('-ProposalVersion', 'v001', '-Confirm'), 'spec/ must hold exactly one version file, v001.yaml; it holds 2',
          { WriteBytes ([System.IO.Path]::Combine($t, '.mission', 'spec', 'v002.yaml')) $spec0 }),
        @('-ProposalVersion v002, a version that is not the first (the Phase 5 path, given its three attestations)', @('-ProposalVersion', 'v002', '-Confirm', '-ArchitectureValidated', '-RunbookValidated'), 'ACCEPTANCE ABORTED: Spec proposal for v002 does not exist.',
          $null))
    foreach ($v in $variants) {
        if ($v[3]) { & $v[3]; $null = RunGit $t @('add', '-A'); $null = RunGit $t @('commit', '-q', '-m', "fixture: $($v[0])") }
        $hv = HeadOf; $mv = TreeHashes ([System.IO.Path]::Combine($t, '.mission'))
        $s = SpecAccept $v[1]
        Check "spec-accept REFUSES $($v[0]): exit 1, the reason named, HEAD and the .mission tree unchanged, the tree clean" (
            ($s.code -eq 1) -and ((Count $s.out ([regex]::Escape($v[2]))) -ge 1) -and ((HeadOf) -eq $hv) -and ((TreeHashes ([System.IO.Path]::Combine($t, '.mission'))).aggregate -eq $mv.aggregate) -and (CleanAt))
        $null = RunGit $t @('reset', '-q', '--hard', $h0)
    }
    $m1 = TreeHashes ([System.IO.Path]::Combine($t, '.mission'))
    $s = SpecAccept @('-ProposalVersion', 'v001', '-Confirm')
    $h1 = HeadOf
    $parent = ((RunGit $t @('rev-parse', 'HEAD~1')).out -join '').Trim()
    $names = @((RunGit $t @('diff', '--name-only', $h0, $h1)).out)
    Check 'spec-accept -ProposalVersion v001 -Confirm ACCEPTS the draft: exit 0, ONE commit on the pre-acceptance HEAD, naming exactly spec/v001.yaml, mission.yaml and the ledger, the tree clean' (
        ($s.code -eq 0) -and ($h1 -ne $h0) -and ($parent -eq $h0) -and (Same (Sorted $names) (Sorted @('.mission/ledger/entries.jsonl', '.mission/mission.yaml', '.mission/spec/v001.yaml'))) -and (CleanAt))
    $spec1 = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($t, '.mission', 'spec', 'v001.yaml'))
    $mission1 = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($t, '.mission', 'mission.yaml'))
    Check 'spec/v001.yaml is its draft bytes with the one state: line draft -> accepted and no other byte changed; no previous_version or created_from_amendment line; amendments/ still empty' (
        ((Count @($L1.GetString($spec0) -split "`n") '^state: draft$') -eq 1) -and ((Sha $spec1) -eq (Sha (Bytes ($L1.GetString($spec0).Replace("`nstate: draft`n", "`nstate: accepted`n"))))) -and
        ((Count @($L1.GetString($spec1) -split "`n") '^(previous_version|created_from_amendment):') -eq 0) -and (@([System.IO.Directory]::GetFileSystemEntries([System.IO.Path]::Combine($t, '.mission', 'amendments'))).Count -eq 0))
    Check 'mission.yaml is its bytes with current_spec_version null -> 1 and no other byte changed: state still Created' (
        ((Sha $mission1) -eq (Sha (Bytes ($L1.GetString($mission0).Replace("`ncurrent_spec_version: null`n", "`ncurrent_spec_version: 1`n"))))) -and ((Count @($L1.GetString($mission1) -split "`n") '^state: Created$') -eq 1) -and ((Sha $mission1) -ne (Sha $mission0)))
    $led = @([System.IO.File]::ReadAllLines([System.IO.Path]::Combine($t, '.mission', 'ledger', 'entries.jsonl')) | Where-Object { $_ })
    $ent = if ($led.Count -eq 1) { $led[0] | ConvertFrom-Json } else { $null }
    Check 'the ledger holds ONE entry, the acceptance: a decision of the mission, its scope_ref spec/v001.yaml' (($null -ne $ent) -and ($ent.type -eq 'decision') -and ($ent.scope -eq 'mission') -and ($ent.scope_ref -eq '.mission/spec/v001.yaml') -and ([string]$ent.id).StartsWith('ledger-decision-spec-accept-v001'))
    $m2 = TreeHashes ([System.IO.Path]::Combine($t, '.mission'))
    Check 'nothing else under .mission moved: the acceptance changed exactly those three files' (Same (Sorted (DiffTrees $m1 $m2)) (Sorted @('changed ledger/entries.jsonl', 'changed mission.yaml', 'changed spec/v001.yaml')))
    $s = SpecAccept @('-ProposalVersion', 'v001', '-Confirm')
    Check 'a second spec-accept -ProposalVersion v001 -Confirm REFUSES: exit 1, v001 no longer a draft, HEAD and the .mission tree unchanged' (
        ($s.code -eq 1) -and ((Count $s.out "spec/v001\.yaml is not a draft: its state: line reads 'accepted'") -ge 1) -and ((HeadOf) -eq $h1) -and ((TreeHashes ([System.IO.Path]::Combine($t, '.mission'))).aggregate -eq $m2.aggregate) -and (CleanAt))
    $r = Run (Join-Path $x 'mission.ps1') @('smoke', '-Target', $t)
    L "mission smoke: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    $oks = @($r.out | Where-Object { $_ -like '  `[ok  `]*' }).Count
    Check "mission smoke: SMOKE-MISSION -> MET, $oks ok rows, exit 0" (($r.code -eq 0) -and (Has $r.out 'mission-goal-check: SMOKE-MISSION -> MET') -and (Has $r.out 'mission.ps1: smoke: MET'))
    $ow = DocInt (DocText (Join-Path $Repo 'INSTALL.md')) '-- (\w+) `\[ok  \]` lines in all'
    Check "INSTALL.md's $ow [ok  ] lines = this smoke's $oks" (($ow -eq $oks) -and ($oks -gt 0))
    $m0 = TreeHashes ([System.IO.Path]::Combine($t, '.mission'))
    $gi0 = FileSha $giT
    $r = Run (Join-Path $x 'mission.ps1') @('init', '-Target', $t)
    Check 'a second mission init refuses (exit 2) and writes nothing: the .mission tree and .gitignore byte for byte, no .gitignore line' (
        ($r.code -eq 2) -and ((TreeHashes ([System.IO.Path]::Combine($t, '.mission'))).aggregate -eq $m0.aggregate) -and ((FileSha $giT) -eq $gi0) -and ((Count $r.out '^mission\.ps1:   \.gitignore ') -eq 0))
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $t, '-Verify')
    Check 'after init and smoke, -Verify still reads 0 differences (the mission plane is outside the lock)' (($v.code -eq 0) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
    $lock0 = ReadLock $t
    $r = Run (Join-Path $x 'install.ps1') @('-Target', $t, '-ReleaseZip', $z.zip)
    Check 'a re-run over the initialised mission: exit 0, already installed, framework.lock byte-identical' (($r.code -eq 0) -and ((Count $r.out '^install\.ps1: already installed: .* nothing was written, and framework\.lock is untouched\.$') -eq 1) -and ((ReadLock $t).sha -eq $lock0.sha))
    # e3 init needs only a folder: each fixture is a git-init folder holding a .gitignore of the project's own, read
    # here as ISO-8859-1 (a byte per char), so the bytes there must survive as a prefix and the tail is matched exactly.
    L '--- e3 mission init over a project''s own root .gitignore: only the missing rules appended, in its line ending; a file holding both left byte for byte'
    $giFix = @(
        @('crlf-one-held', [byte[]](Bytes "build/`r`n.claude/settings.local.json  `r`n*.log"), '^mission\.ps1:   \.gitignore appended 2 rule\(s\): /\.claude/worktrees/ and /\.mission-runtime/ \(',
          '\A\r\n# [^\r\n]+\r\n/\.claude/worktrees/\r\n/\.mission-runtime/\r\n\z', 'CRLF with no final line break, holding .claude/settings.local.json unanchored with trailing spaces'),
        @('lf-none-held', [byte[]](Bytes "dist/`n"), '^mission\.ps1:   \.gitignore appended 3 rule\(s\): /\.claude/settings\.local\.json and /\.claude/worktrees/ and /\.mission-runtime/ \(',
          '\A# [^\r\n]+\n/\.claude/settings\.local\.json\n/\.claude/worktrees/\n/\.mission-runtime/\n\z', 'LF with a final line break, holding no rule'),
        # RELEASE-4 S1 F-P7a: the runtime plane's rule counts as held where the project already ignores it unanchored.
        @('bom-both-held', [byte[]](@([byte]0xEF, [byte]0xBB, [byte]0xBF) + (Bytes "# the project's own rules`n/.claude/worktrees/`n.claude/settings.local.json`n.mission-runtime/`n")),
          '^mission\.ps1:   \.gitignore unchanged: it already ignores /\.claude/settings\.local\.json and /\.claude/worktrees/ and /\.mission-runtime/$', $null, 'UTF-8 with a BOM, holding every rule, reordered, one unanchored, the runtime plane''s as .mission-runtime/')
    )
    foreach ($gf in $giFix) {
        $gd = Join-Path $Work ('e3-' + $gf[0])
        $null = New-Item -ItemType Directory -Force -Path $gd
        $null = RunGit $gd @('init', '-q')
        $giOld = [byte[]]$gf[1]
        [System.IO.File]::WriteAllBytes((Join-Path $gd '.gitignore'), $giOld)
        $r = Run (Join-Path $x 'mission.ps1') @('init', '-Target', $gd)
        L "(e3 $($gf[0])) mission init: exit=$($r.code)"; $r.out | Where-Object { $_ -match '\.gitignore' } | ForEach-Object { L "  | $_" }
        $giOldS = $L1.GetString($giOld)
        $giNewS = $L1.GetString([System.IO.File]::ReadAllBytes((Join-Path $gd '.gitignore')))
        $giLines = @($r.out | Where-Object { $_ -match '^mission\.ps1:   \.gitignore ' })
        if ($null -eq $gf[3]) {
            $giBytesOk = ($giNewS -ceq $giOldS); $giSaid = 'the file byte for byte'
        } else {
            $giBytesOk = $giNewS.StartsWith($giOldS, [System.StringComparison]::Ordinal) -and ($giNewS.Substring($giOldS.Length) -cmatch $gf[3])
            $giSaid = 'the bytes there kept as a prefix, then only the missing rule(s) after one comment line, in the file''s line ending'
        }
        Check "(e3) init over a .gitignore $($gf[4]): exit 0, one .gitignore line ($(if ($null -eq $gf[3]) { 'unchanged' } else { 'appended' })), $giSaid; git check-ignore --no-index then reads both paths ignored and .claude/settings.json not" (
            ($r.code -eq 0) -and ($giLines.Count -eq 1) -and ($giLines[0] -cmatch $gf[2]) -and $giBytesOk -and (GiIgnored $gd))
    }
    # e3 THE .gitignore DECISION COMES BEFORE THE FIRST WRITE: a read-only .gitignore that lacks a rule, a .gitignore
    # that is a folder, and one that cannot be read each make the target unusable -- exit 1, its reason on one line, no
    # .mission, the file untouched.
    # A read-only .gitignore that already holds both rules needs no append and is no obstacle (exit 0, unchanged).
    L '--- e3 mission init over a .gitignore it cannot append to, that is a folder, or that it cannot read: exit 1, nothing written'
    $giRo = @(
        @('ro-lacking', [byte[]](Bytes "dist/`n"), 1, '^mission\.ps1: .*\\\.gitignore cannot be appended to \(.*\) -- init cannot make it ignore Claude Code''s per-checkout files\. Nothing was written\.$', 'read-only, lacking both rules'),
        @('ro-both-held', [byte[]](Bytes "/.claude/settings.local.json`n/.claude/worktrees/`n/.mission-runtime/`n"), 0, '^mission\.ps1:   \.gitignore unchanged: it already ignores /\.claude/settings\.local\.json and /\.claude/worktrees/ and /\.mission-runtime/$', 'read-only, already holding every rule')
    )
    foreach ($gf in $giRo) {
        $gd = Join-Path $Work ('e3-' + $gf[0])
        $null = New-Item -ItemType Directory -Force -Path $gd
        $null = RunGit $gd @('init', '-q')
        $giFile = Join-Path $gd '.gitignore'
        [System.IO.File]::WriteAllBytes($giFile, [byte[]]$gf[1])
        (Get-Item -LiteralPath $giFile).IsReadOnly = $true
        try { $r = Run (Join-Path $x 'mission.ps1') @('init', '-Target', $gd) }
        finally { (Get-Item -LiteralPath $giFile).IsReadOnly = $false }
        L "(e3 $($gf[0])) mission init: exit=$($r.code)"; $r.out | Where-Object { $_ -match '\.gitignore' } | ForEach-Object { L "  | $_" }
        $giSame = ($L1.GetString([System.IO.File]::ReadAllBytes($giFile)) -ceq $L1.GetString([byte[]]$gf[1]))
        $giLines = @($r.out | Where-Object { $_ -match '\.gitignore ' })
        $missionThere = Test-Path -LiteralPath (Join-Path $gd '.mission')
        Check "(e3) init over a .gitignore $($gf[4]): exit $($gf[2]), one .gitignore line naming why, the file byte for byte, .mission $(if ($gf[2] -eq 0) { 'written' } else { 'NOT written' })" (
            ($r.code -eq $gf[2]) -and ($giLines.Count -eq 1) -and ($giLines[0] -cmatch $gf[3]) -and $giSame -and ($missionThere -eq ($gf[2] -eq 0)))
    }
    $gd = Join-Path $Work 'e3-gi-folder'
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $gd '.gitignore')
    $null = RunGit $gd @('init', '-q')
    $r = Run (Join-Path $x 'mission.ps1') @('init', '-Target', $gd)
    L "(e3 gi-folder) mission init: exit=$($r.code)"; $r.out | Where-Object { $_ -match '\.gitignore' } | ForEach-Object { L "  | $_" }
    Check '(e3) init over a .gitignore that is a FOLDER: exit 1, its one line naming it a folder, no .mission written' (
        ($r.code -eq 1) -and ((Count $r.out '\\\.gitignore is a folder, not a file -- init cannot make it ignore Claude Code''s per-checkout files\. Nothing was written\.$') -eq 1) -and
        (-not (Test-Path -LiteralPath (Join-Path $gd '.mission'))))
    # e3 A .gitignore that CANNOT BE READ: this process holds it open with no sharing while init runs, so init's read
    # fails -- exit 1, its reason on one line, no .mission written, the file byte for byte once released.
    $gd = Join-Path $Work 'e3-gi-unreadable'
    $null = New-Item -ItemType Directory -Force -Path $gd
    $null = RunGit $gd @('init', '-q')
    $giFile = Join-Path $gd '.gitignore'
    $giHeld = [byte[]](Bytes "dist/`n")
    [System.IO.File]::WriteAllBytes($giFile, $giHeld)
    $giLock = [System.IO.File]::Open($giFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try { $r = Run (Join-Path $x 'mission.ps1') @('init', '-Target', $gd) }
    finally { $giLock.Dispose() }
    L "(e3 gi-unreadable) mission init: exit=$($r.code)"; $r.out | Where-Object { $_ -match '\.gitignore' } | ForEach-Object { L "  | $_" }
    $giSame = ($L1.GetString([System.IO.File]::ReadAllBytes($giFile)) -ceq $L1.GetString($giHeld))
    $giLines = @($r.out | Where-Object { $_ -match '\.gitignore ' })
    Check '(e3) init over a .gitignore that CANNOT BE READ (held open, no sharing): exit 1, its one line naming it unreadable, the file byte for byte, no .mission written' (
        ($r.code -eq 1) -and ($giLines.Count -eq 1) -and ($giLines[0] -cmatch '^mission\.ps1: .*\\\.gitignore cannot be read \(.*\) -- init cannot make it ignore Claude Code''s per-checkout files\. Nothing was written\.$') -and
        $giSame -and (-not (Test-Path -LiteralPath (Join-Path $gd '.mission'))))
}
'f' {
    function Run-Child { param([string[]]$ArgList, [switch]$Bypass)
        $saved = $env:PSExecutionPolicyPreference
        Remove-Item Env:PSExecutionPolicyPreference -ErrorAction SilentlyContinue
        $a = @('-NoProfile'); if ($Bypass) { $a += @('-ExecutionPolicy', 'Bypass') }; $a += $ArgList
        $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = @(& powershell @a 2>&1); $c = $LASTEXITCODE }
        finally { $ErrorActionPreference = $p; if ($null -ne $saved) { $env:PSExecutionPolicyPreference = $saved } }
        return [pscustomobject]@{ code = $c; out = @($o | ForEach-Object { "$_" }) }
    }
    function Marked { param([string]$Root)
        $all = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force)
        $m = @($all | Where-Object { @(Get-Item -LiteralPath $_.FullName -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -eq 'Zone.Identifier' }).Count -gt 0 })
        return [pscustomobject]@{ marked = $m.Count; all = $all.Count }
    }
    $pol = Run-Child @('-Command', 'Get-ExecutionPolicy')
    L "host policy, child with no -ExecutionPolicy and no inherited process scope: $($pol.out -join ' | ')"
    Check 'the host policy is RemoteSigned' (($pol.out -join '').Trim() -eq 'RemoteSigned')
    foreach ($f in @(Get-ChildItem -LiteralPath $x -Recurse -File -Force)) { Set-Content -LiteralPath $f.FullName -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" }
    $mk = Marked $x
    L "expanded with Expand-Archive, then every file marked as the Explorer engine marks it: $($mk.marked) of $($mk.all)"
    Check "all $memberCount expanded files carry the mark" ($mk.marked -eq $memberCount -and $mk.all -eq $memberCount)
    $tgt = Join-Path $Work 't'
    $r = Run-Child @('-File', (Join-Path $x 'install.ps1'), '-Target', $tgt)
    L "marked install.ps1, host policy: exit=$($r.code)"; $r.out | Select-Object -First 4 | ForEach-Object { L "  | $_" }
    Check 'REFUSED under RemoteSigned: "not digitally signed", non-zero exit, no target created' (($r.code -ne 0) -and ((Count $r.out 'is not digitally signed') -ge 1) -and -not (Test-Path -LiteralPath $tgt))
    $r = Run-Child @('-File', (Join-Path $x 'install.ps1'), '-Target', $tgt) -Bypass
    L "marked install.ps1, -ExecutionPolicy Bypass: exit=$($r.code)"; $r.out | Where-Object { $_ -cmatch '^install\.ps1: (MARK OF THE WEB: |done:|installed \d+\.\d+\.\d+ |REFUSED)' } | ForEach-Object { L "  | $_" }
    Check "RUNS under Bypass: exit 0, done: written=$N, and it reports the marked tree (MARK OF THE WEB)" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0") -and ((Count $r.out '^install\.ps1: MARK OF THE WEB: this tree carries a Zone\.Identifier stream on \d+ file\(s\)') -eq 1))
    $mt = Marked $tgt
    Check "installed files carry no mark ($($mt.marked) of $($mt.all))" ($mt.marked -eq 0)
    $r = Run-Child @('-File', (Join-Path $x 'mission.ps1'), 'init', '-Target', $tgt)
    Check 'marked mission.ps1 is refused the same way under RemoteSigned' (($r.code -ne 0) -and ((Count $r.out 'is not digitally signed') -ge 1))
    $r = Run-Child @('-File', (Join-Path $x 'mission.ps1'), 'init', '-Target', $tgt) -Bypass
    Check 'and runs under Bypass (exit 0)' ($r.code -eq 0)
    $r = Run-Child @('-File', [System.IO.Path]::Combine($tgt, 'tools', 'lam', 'mission-goal-check.ps1'), '-Goal', 'SMOKE-MISSION', '-MissionRoot', $tgt)
    L "an INSTALLED script under the host policy: exit=$($r.code) first line: $(@($r.out)[0])"
    Check 'an installed script runs under RemoteSigned and reads MET' (($r.code -eq 0) -and (@($r.out)[0] -ceq 'mission-goal-check: SMOKE-MISSION -> MET'))
}
'g' {
    $xOwned = OwnedSet (Join-Path $x 'provenance\manifest.jsonl')
    $H = Join-Path $Work 'h'
    $null = New-Item -ItemType Directory -Path $H
    L '--- g1 the fixture: git init; core.autocrlf true; no .gitattributes of the host''s own; the installer-owned files from the expanded ZIP; add, commit; rm --cached; reset --hard'
    Check 'git init' ((RunGit $H @('init', '-q')).code -eq 0)
    $null = RunGit $H @('config', 'core.autocrlf', 'true'); $null = RunGit $H @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $H @('config', 'user.email', 'falsifier-fixture@localhost')
    # The installed root .gitattributes (* -text) would leave this host nothing to convert. Its own
    # attributes file, which outranks every tracked one, gives conversion back to each path but the pinned fixtures',
    # as a project's own rules may: so the CRLF host this case measures stands, at every release alike.
    WriteBytes (Join-Path $H '.git\info\attributes') (Bytes $gInfoAttributes)
    foreach ($k in $xOwned.Keys) { WriteBytes (Join-Path $H ($k -replace '/', '\')) ([System.IO.File]::ReadAllBytes((Join-Path $x ($k -replace '/', '\')))) }
    $gaFound = @(Get-ChildItem -LiteralPath $H -Recurse -Force -File -Filter '.gitattributes' | Where-Object { $_.FullName -notlike "$H\.git\*" } | ForEach-Object { $_.FullName.Substring($H.Length + 1).Replace('\', '/') })
    Check "no .gitattributes in the fixture but what the installer-owned set carries ($(if ($gaFound.Count) { $gaFound -join ', ' } else { 'none' })), and none configured" ((@($gaFound | Where-Object { -not $xOwned.ContainsKey($_) }).Count -eq 0) -and ((RunGit $H @('config', '--get-all', 'core.attributesfile')).out.Count -eq 0))
    $null = RunGit $H @('add', '-A')
    Check 'git commit' ((RunGit $H @('commit', '-q', '-m', 'the CRLF fixture: the installer-owned files')).code -eq 0)
    Check 'git rm -r -q --cached .' ((RunGit $H @('rm', '-r', '-q', '--cached', '.')).code -eq 0)
    Check 'git reset --hard' ((RunGit $H @('reset', '--hard', '-q')).code -eq 0)
    $eolLines = (RunGit $H @('ls-files', '--eol')).out
    $wcrlf = @($eolLines | Where-Object { $_ -match '\sw/crlf\s' }).Count
    $diskEol = @{}; foreach ($k in $owned.Keys) { $diskEol[$k] = EolOf ([System.IO.File]::ReadAllBytes((Join-Path $H ($k -replace '/', '\')))) }
    $withEnd = @($owned.Keys | Where-Object { $diskEol[$_] -notin 'lf', 'binary' }).Count
    $unset = TextUnset $H @($owned.Keys)
    # A binary file (the dashboard's fonts) is never converted, whatever its attributes: git reads it as binary.
    $convertible = @($owned.Keys | Where-Object { -not $unset.Contains($_) -and $srcEol[$_] -ne 'binary' })
    L "  git ls-files --eol: $($eolLines.Count) tracked, $wcrlf w/crlf; disk eol census: $(@($diskEol.Values | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '); git reads $($unset.Count) as -text"
    Check "git ls-files --eol: $N tracked, $wcrlf w/crlf = every file with a line end ($withEnd); every file git converts ($($convertible.Count)) crlf on disk, but the one with no line end" (($eolLines.Count -eq $N) -and ($wcrlf -eq $withEnd) -and ($withEnd -ge $convertible.Count - 1) -and
        (@($convertible | Where-Object { $diskEol[$_] -ne 'crlf' }).Count -le 1) -and (@($diskEol.Keys | Where-Object { $diskEol[$_] -notin 'crlf', 'lf' -and -not ($diskEol[$_] -eq 'binary' -and $srcEol[$_] -eq 'binary') }).Count -eq 0))
    # THE PINNED BASES ON A CRLF HOST. The instruments hold every file under tests/lam/fixtures/base-<label>/ and
    # legacy-census-halts/ to the sha256 of its exact bytes, read from disk: they must stand at their manifest bytes in this
    # checkout and in a clone of it, whatever core.autocrlf says.
    $fxKeys = @($owned.Keys | Where-Object { $_ -match '^tests/lam/fixtures/(base-[0-9a-f]{8}(-s[0-9]{2})?|legacy-census-halts)/' })
    $fxBad = @($fxKeys | Where-Object { (FileSha (Join-Path $H ($_ -replace '/', '\'))) -ne $owned[$_].sha256 })
    $H2 = Join-Path $Work 'h2'
    $cl = RunGit $Work @('clone', '-q', '-c', 'core.autocrlf=true', $H, $H2)
    $fxBad2 = @($fxKeys | Where-Object { $fp = Join-Path $H2 ($_ -replace '/', '\'); (-not (Test-Path -LiteralPath $fp -PathType Leaf)) -or ((FileSha $fp) -ne $owned[$_].sha256) })
    L "  the pinned bases: $($fxKeys.Count); not at their manifest bytes after the checkout: $($fxBad.Count), in the clone: $($fxBad2.Count)$(if ($fxBad.Count) { ' -- ' + (@($fxBad | Select-Object -First 2) -join ', ') })"
    Check "the $($fxKeys.Count) pinned bases under tests/lam/fixtures/ stand at their manifest bytes -- the sha256 the instruments pin -- after the CRLF checkout and in a clone of it" (($fxKeys.Count -gt 0) -and ($fxBad.Count -eq 0) -and ($cl.code -eq 0) -and ($fxBad2.Count -eq 0))
    $disk = TreeHashes $H
    Check 'every file folds to its source (the content is the framework''s)' ((@($owned.Keys | Where-Object { (FoldSha ([System.IO.File]::ReadAllBytes((Join-Path $H ($_ -replace '/', '\'))))) -ne $srcFold[$_] }).Count) -eq 0)
    Check 'git status --porcelain is empty before the install' ((RunGit $H @('status', '--porcelain')).out.Count -eq 0)
    $r = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-ReleaseZip', $z.zip)
    L "(g1) install exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   already-identical ' } | ForEach-Object { L "  | $_" }
    Check "(g1) exit 0, done: written=0 already-identical=$N kept=0 retired=0 refused=0" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=0 already-identical=$N kept=0 retired=0 refused=0"))
    Check "(g1) the lock was written ($($N + 1) lines for $N files)" ((Count $r.out "^install\.ps1: framework\.lock written: $($N + 1) line\(s\) for $N file\(s\), sha256 [0-9a-f]{64}$") -eq 1)
    $lk = ReadLock $H
    $ec = EolCensus $lk.rows
    L "(g1) lock header: $($lk.lines[0]); eol census $(CensusText $ec)"
    Check "(g1) lock header: lock_format 2, eol_rule, source_kind release, zip_sha256 = the ZIP, version $($z.version); $N rows" (($lk.header.lock_format -eq 2) -and ($lk.header.eol_rule -ceq 'fold-crlf-text') -and ($lk.header.source_kind -eq 'release') -and ($lk.header.zip_sha256 -eq $zsha) -and ($lk.header.version -ceq $z.version) -and ($lk.rows.Count -eq $N))
    CheckRows2 $lk '(g1)' 'already-identical'
    Check "(g1) every row's eol is what the host file shows (computed here): crlf=$withEnd" ((@($lk.rows | Where-Object { $_.eol -cne $diskEol[$_.path] }).Count -eq 0) -and ($ec.crlf -eq $withEnd))
    CheckLockAgainstSource $lk '(g1)'
    $after = TreeHashes $H
    $d = DiffTrees $disk $after
    Check '(g1) the install wrote only framework.lock: no host file was rewritten for its line endings' (($d.Count -eq 1) -and ($d[0] -eq 'new framework.lock'))
    $st = (RunGit $H @('status', '--porcelain')).out
    Check '(g1) git status --porcelain shows only framework.lock, untracked' (($st.Count -eq 1) -and ($st[0] -ceq '?? framework.lock'))
    $vline = "install.ps1: verify: $N file(s) listed, 0 difference(s); eol lf=$($ec.lf) crlf=$($ec.crlf) mixed=$($ec.mixed) binary=$($ec.binary)."
    $nBin = @($srcEol.Values | Where-Object { $_ -eq 'binary' }).Count
    $t0 = TreeHashes $H
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-Verify')
    L "(g2) verify exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    Check "(g2) -Verify exit 0: $vline" (($v.code -eq 0) -and (Has $v.out $vline))
    Check '(g2) -Verify wrote nothing' ((TreeHashes $H).aggregate -eq $t0.aggregate)
    Check '(g3) git checkout -- . exit 0' ((RunGit $H @('checkout', '--', '.')).code -eq 0)
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-Verify')
    Check '(g3) -Verify after the checkout: exit 0, 0 difference(s)' (($v.code -eq 0) -and (Has $v.out $vline))
    $st = (RunGit $H @('status', '--porcelain')).out
    Check '(g3) git status --porcelain still shows only framework.lock, untracked' (($st.Count -eq 1) -and ($st[0] -ceq '?? framework.lock'))
    $ep = Join-Path $H ($mv -replace '/', '\')
    $before = [System.IO.File]::ReadAllBytes($ep)
    $h0 = TreeHashes $H
    $fs = [System.IO.File]::Open($ep, [System.IO.FileMode]::Append); try { $fs.WriteByte(0x78) } finally { $fs.Dispose() }
    $h1 = TreeHashes $H
    Check '(g4) one byte (0x78) appended: exactly that file changed' (((DiffTrees $h0 $h1).Count -eq 1) -and ((Get-Item -LiteralPath $ep).Length -eq $before.Length + 1))
    $r = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-ReleaseZip', $z.zip)
    L "(g4) the same-version run: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'CHANGED|already installed|verify: \d' } | ForEach-Object { L "  | $_" }
    Check "(g4) exit 3, $mv named CHANGED and nothing else, nothing written (framework.lock included)" (($r.code -eq 3) -and ((Count $r.out ('CHANGED\s+' + [regex]::Escape($mv) + '\s')) -eq 1) -and ((Count $r.out '^install\.ps1:\s+(CHANGED|MISSING|REFUSED)\s') -eq 1) -and ((TreeHashes $H).aggregate -eq $h1.aggregate))
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-Verify')
    Check '(g4) -Verify names exactly that file CHANGED, exit 3' (($v.code -eq 3) -and ((Count $v.out ('CHANGED\s+' + [regex]::Escape($mv))) -eq 1) -and ((Count $v.out ' 1 difference\(s\); eol ') -eq 1))
    $g = RunGit $H @('checkout', '--', $mv)
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-Verify')
    Check '(g4) restored with git checkout -- <file>: the bytes are back, -Verify 0 difference(s)' (($g.code -eq 0) -and ((Sha ([System.IO.File]::ReadAllBytes($ep))) -eq (Sha $before)) -and ($v.code -eq 0))

    L "--- g5/g6 unit level: Get-JudgedForm lifted out of $x\install.ps1: $(LiftJudge (Join-Path $x 'install.ps1'))"
    $S = Join-Path $Work 'probe-src'
    $null = New-Item -ItemType Directory -Path (Join-Path $S 'provenance')
    Copy-Item -LiteralPath (Join-Path $x 'install.ps1') -Destination $S
    Copy-Item -LiteralPath (Join-Path $x 'VERSION') -Destination $S
    $binSrc = Bytes "a`0`nb"; $txtSrc = Bytes "a`nb`n"
    WriteBytes (Join-Path $S 'probe.bin') $binSrc; WriteBytes (Join-Path $S 'probe.txt') $txtSrc
    $man = '{"manifest":"provenance","note":"a synthetic probe source"}' + "`n" +
        '{"source":"host","path":"probe.bin","class":"MOVE","sha256":"' + (Sha $binSrc) + '","bytes":' + $binSrc.Length + ',"destination":"probe.bin"}' + "`n" +
        '{"source":"host","path":"probe.txt","class":"MOVE","sha256":"' + (Sha $txtSrc) + '","bytes":' + $txtSrc.Length + ',"destination":"probe.txt"}' + "`n"
    [System.IO.File]::WriteAllText((Join-Path $S 'provenance\manifest.jsonl'), $man, $NoBom)
    [System.IO.File]::WriteAllText((Join-Path $S 'RELEASE'), "name: vanguard-collective`nversion: $($z.version)`nframework_repo_tip: $head`nmanifest_sha256: $(FileSha (Join-Path $S 'provenance\manifest.jsonl'))`n", $NoBom)
    function Probe { param([string]$Name, [hashtable]$Files)
        $t = Join-Path $Work "probe-$Name"
        $null = New-Item -ItemType Directory -Path $t
        foreach ($k in $Files.Keys) { WriteBytes (Join-Path $t $k) $Files[$k] }
        $h0 = TreeHashes $t
        $r = Run (Join-Path $S 'install.ps1') @('-Target', $t)
        L "  [$Name] -> exit $($r.code)"; $r.out | Where-Object { $_ -match '^install\.ps1:   |done:|planned:' } | ForEach-Object { L "    | $_" }
        $lk = $null; if (Test-Path -LiteralPath (Join-Path $t 'framework.lock')) { $lk = ReadLock $t }
        return [pscustomobject]@{ r = $r; lock = $lk; unchanged = ((TreeHashes $t).aggregate -eq $h0.aggregate); t = $t }
    }
    $one = 'install.ps1: done: written=1 already-identical=1 kept=0 retired=0 refused=0'
    $b1 = Get-JudgedForm -Bytes (Bytes "a`0`r`nb"); $b2 = Get-JudgedForm -Bytes $binSrc
    Check '(g5) unit: a BINARY file with a CRLF and the same file with that CRLF made LF are judged DIFFERENT, each eol binary, each by its raw sha256' (($b1.sha256 -ne $b2.sha256) -and ($b1.eol -eq 'binary') -and ($b2.eol -eq 'binary') -and ($b1.sha256 -eq (Sha (Bytes "a`0`r`nb"))) -and ($b2.sha256 -eq (Sha $binSrc)))
    $p = Probe 'crlf-binary' @{ 'probe.bin' = (Bytes "a`0`r`nb") }
    Check '(g5) e2e: the BINARY file with its LF made CRLF is REFUSED not-installed-by-framework, exit 2, planned counts, nothing written' (($p.r.code -eq 2) -and ((Count $p.r.out 'REFUSED\s+probe\.bin\s+-- not-installed-by-framework') -eq 1) -and (Has $p.r.out 'install.ps1: planned: written=1 already-identical=0 kept=0 retired=0 refused=1') -and $p.unchanged -and ($null -eq $p.lock))
    $p = Probe 'same-binary' @{ 'probe.bin' = $binSrc }
    Check '(g5) e2e control: the BINARY file byte-identical is already-identical, its lock row eol binary at its raw sha256' (($p.r.code -eq 0) -and (Has $p.r.out $one) -and (@($p.lock.rows | Where-Object { $_.path -eq 'probe.bin' -and $_.eol -eq 'binary' -and $_.sha256 -eq (Sha $binSrc) -and $_.disposition -ceq 'already-identical' }).Count -eq 1))
    $p = Probe 'crlf-text' @{ 'probe.txt' = (Bytes "a`r`nb`r`n") }
    Check '(g5) e2e control: the same change in a TEXT file (LF made CRLF) is already-identical, eol crlf' (($p.r.code -eq 0) -and (Has $p.r.out $one) -and (@($p.lock.rows | Where-Object { $_.path -eq 'probe.txt' -and $_.eol -eq 'crlf' -and $_.sha256 -eq (Sha $txtSrc) }).Count -eq 1))
    $m1 = Get-JudgedForm -Bytes (Bytes "a`r`nb`n"); $m2 = Get-JudgedForm -Bytes $txtSrc; $m3 = Get-JudgedForm -Bytes (Bytes "a`r`nb`n`r")
    Check '(g6) unit: the MIXED file (one CRLF, one lone LF) folds to its LF form, judged EQUAL, eol mixed' (($m1.sha256 -eq $m2.sha256) -and ($m1.eol -eq 'mixed') -and ($m2.eol -eq 'lf') -and ($m1.sha256 -eq (Sha $txtSrc)))
    Check '(g6) unit: a MIXED file whose fold is NOT the LF form (a trailing lone CR) is judged DIFFERENT, eol mixed' (($m3.sha256 -ne $m2.sha256) -and ($m3.eol -eq 'mixed'))
    $p = Probe 'mixed' @{ 'probe.txt' = (Bytes "a`r`nb`n") }
    Check '(g6) e2e: the MIXED file is already-identical, its lock row eol mixed at the folded sha256, and it was not rewritten' (($p.r.code -eq 0) -and (Has $p.r.out $one) -and (@($p.lock.rows | Where-Object { $_.path -eq 'probe.txt' -and $_.eol -eq 'mixed' -and $_.sha256 -eq (Sha $txtSrc) }).Count -eq 1) -and ((Sha ([System.IO.File]::ReadAllBytes((Join-Path $p.t 'probe.txt')))) -eq (Sha (Bytes "a`r`nb`n"))))
    $p = Probe 'mixed-lone-cr' @{ 'probe.txt' = (Bytes "a`r`nb`n`r") }
    Check '(g6) e2e: the MIXED file whose fold differs is REFUSED not-installed-by-framework, exit 2, nothing written' (($p.r.code -eq 2) -and ((Count $p.r.out 'REFUSED\s+probe\.txt\s+-- not-installed-by-framework') -eq 1) -and $p.unchanged)

    L '--- g7: the host flipped to LF (core.autocrlf false; rm --cached; reset --hard), then back to CRLF'
    $lock0 = ReadLock $H
    $null = RunGit $H @('config', 'core.autocrlf', 'false'); $null = RunGit $H @('rm', '-r', '-q', '--cached', '.'); $null = RunGit $H @('reset', '--hard', '-q')
    L "(g7) after the flip, disk eol census: $(@($owned.Keys | ForEach-Object { EolOf ([System.IO.File]::ReadAllBytes((Join-Path $H ($_ -replace '/', '\')))) } | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ')"
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-Verify')
    Check '(g7) -Verify with the CRLF-time lock over the LF tree: 0 difference(s) (the eol counts stay the lock''s)' (($v.code -eq 0) -and (Has $v.out $vline))
    $r = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-ReleaseZip', $z.zip)
    Check '(g7) a same-version run over the LF tree: exit 0, already installed, framework.lock byte-identical' (($r.code -eq 0) -and ((Count $r.out '^install\.ps1: already installed: ') -ge 1) -and ((ReadLock $H).sha -eq $lock0.sha))
    [System.IO.File]::Delete((Join-Path $H 'framework.lock'))
    $r = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-ReleaseZip', $z.zip)
    $lkLf = ReadLock $H
    Check "(g7) with the lock removed, a fresh install over the LF tree: exit 0, done: written=0 already-identical=$N, and an LF-time lock: eol lf=$($N - $nBin) binary=$nBin" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=0 already-identical=$N kept=0 retired=0 refused=0") -and ((EolCensus $lkLf.rows).lf -eq $N - $nBin) -and ((EolCensus $lkLf.rows).binary -eq $nBin))
    Check '(g7) the LF-time lock''s path, sha256 and disposition columns are the CRLF-time lock''s: only eol moved' ((@($lkLf.rows | ForEach-Object { "$($_.path)|$($_.sha256)|$($_.disposition)" }) -join "`n") -ceq (@($lock0.rows | ForEach-Object { "$($_.path)|$($_.sha256)|$($_.disposition)" }) -join "`n"))
    $null = RunGit $H @('config', 'core.autocrlf', 'true'); $null = RunGit $H @('rm', '-r', '-q', '--cached', '.'); $null = RunGit $H @('reset', '--hard', '-q')
    $v = Run (Join-Path $x 'install.ps1') @('-Target', $H, '-Verify')
    Check "(g7) flipped back to CRLF: -Verify with the LF-time lock reads 0 difference(s), eol lf=$($N - $nBin) binary=$nBin" (($v.code -eq 0) -and (Has $v.out "install.ps1: verify: $N file(s) listed, 0 difference(s); eol lf=$($N - $nBin) crlf=0 mixed=0 binary=$nBin."))
}
'u7' {
    $zi = Inspect-Zip $z.zip
    $notes = "docs/RELEASE-NOTES-v$($z.version).md"
    L "zip: $($zi.count) entries"
    Check "the ZIP carries the release notes $notes" ($zi.names -ccontains $notes)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $za = [System.IO.Compression.ZipFile]::OpenRead($z.zip)
    try { $ms = New-Object System.IO.MemoryStream; $es = $za.GetEntry($notes).Open(); try { $es.CopyTo($ms) } finally { $es.Dispose() }; $nb = $ms.ToArray() } catch { $nb = [byte[]]@() } finally { $za.Dispose() }
    $blob = ((RunGit $clone @('rev-parse', "HEAD:$notes")).out -join '').Trim()
    Check "the member is the file as tracked: its git blob id, computed here, is HEAD's ($blob)" ((BlobId $nb) -eq $blob)
    $za = [System.IO.Compression.ZipFile]::OpenRead($z.zip)
    try { $ms = New-Object System.IO.MemoryStream; $es = $za.GetEntry('provenance/manifest.jsonl').Open(); try { $es.CopyTo($ms) } finally { $es.Dispose() }; $zmPath = Join-Path $Work 'zip-manifest.jsonl'; [System.IO.File]::WriteAllBytes($zmPath, $ms.ToArray()) } finally { $za.Dispose() }
    $zOwned = OwnedSet $zmPath
    $distN = @($zi.names | Where-Object { $_.StartsWith('ui/dist/') }).Count
    $im = DocText (Join-Path $Repo 'INSTALL.md')
    $dn = DocInt $im 'The archive holds (\d+) files'
    $dc = DocInt $im 'the (\d+) files of the commit the release tag names'
    $dd = DocInt $im 'the (\d+) files of the dashboard''s build output'
    $di = DocInt $im 'The (\d+) files the framework installs are among them'
    L "INSTALL.md section 4: the archive holds $dn files; the commit's $dc + ui/dist $dd + THIRD-PARTY-NOTICES + RELEASE; the $di installed among them"
    Check "INSTALL.md section 4's member count, $dn, is the ZIP's entry count, $($zi.count)" ($dn -eq $zi.count)
    Check "INSTALL.md section 4's commit count, $dc, is HEAD's released paths (its tracked paths less the dashboard's private source and the service's tests), $releasedHead" ($dc -eq $releasedHead)
    Check "INSTALL.md section 4's build-output count, $dd, is the ZIP's ui/dist/ entries, $distN, and the formula $dc + $dd + THIRD-PARTY-NOTICES + RELEASE is the ZIP's entry count" (($dd -eq $distN) -and ($dc + $dd + 2 -eq $zi.count))
    Check "INSTALL.md section 4's installed count, $di, is the installer-owned set the ZIP's manifest defines, $($zOwned.Count)" ($di -eq $zOwned.Count)
    $sums = [System.IO.File]::ReadAllText($z.sums)
    Check 'SHA256SUMS keeps its form: <64 hex>, two spaces, the ZIP name, LF; then <64 hex>, two spaces, MEMBERS.sha256, LF' ($sums -cmatch ('^[0-9a-f]{64}  ' + [regex]::Escape($z.name) + "`n[0-9a-f]{64}  MEMBERS\.sha256`n$"))
}
'gu' {
    $H = Join-Path $Work 'h'
    $null = New-Item -ItemType Directory -Path $H
    $null = RunGit $H @('init', '-q'); $null = RunGit $H @('config', 'core.autocrlf', 'true'); $null = RunGit $H @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $H @('config', 'user.email', 'falsifier-fixture@localhost')
    WriteBytes (Join-Path $H '.git\info\attributes') (Bytes $gInfoAttributes)
    Copy-Owned $Repo $H $owned
    $null = RunGit $H @('add', '-A'); $null = RunGit $H @('commit', '-q', '-m', 'the CRLF fixture'); $null = RunGit $H @('rm', '-r', '-q', '--cached', '.'); $null = RunGit $H @('reset', '--hard', '-q')
    $diskEol = @($owned.Keys | ForEach-Object { EolOf ([System.IO.File]::ReadAllBytes((Join-Path $H ($_ -replace '/', '\')))) })
    $crlf = @($diskEol | Where-Object { $_ -eq 'crlf' }).Count
    L "the CRLF host: disk eol census $(@($diskEol | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ')"
    $guUnset = TextUnset $H @($owned.Keys)
    $guKept = @($guUnset | Where-Object { (FileSha (Join-Path $H ($_ -replace '/', '\'))) -ne $owned[$_].sha256 })
    Check "the host is checked out CRLF: every file git converts with a line end is crlf ($crlf of $N; $($guUnset.Count) read as -text, each at its manifest bytes)" (($crlf -ge $N - $guUnset.Count - 1) -and
        (@($diskEol | Where-Object { $_ -notin 'crlf', 'lf' }).Count -eq 0) -and ($guKept.Count -eq 0))
    Write-Lock1 -Target $H -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
    $lk0 = ReadLock $H
    Check "the format-1 lock: the real host's 0.1.1 header, verbatim, and $N rows at eol crlf=$crlf" (($lk0.lines[0] -ceq (Header 'lock-header-0.1.1.json')) -and ((EolCensus $lk0.rows).crlf -eq $crlf))
    $src = New-Source -Dir (Join-Path $Work 'src') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $exp = Expect $src $changedPaths 1; $exp | Add-Member -NotePropertyName version -NotePropertyValue $U.release
    $before = TreeHashes $H
    $r = Run $src.installer @('-Target', $H)
    L "upgrade over the CRLF host: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   already-identical ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=$($exp.written) already-identical=$($exp.identical) kept=$($exp.kept) retired=0 refused=0"
    Check "exit 0, and the same counts as the LF one: $done" (($r.code -eq 0) -and (Has $r.out $done))
    $null = Check-Upgraded '(gu)' $H $src $exp $U.from $changedPaths $U.new.path '2026-10-24T14:29:53.967Z'
    $d = DiffTrees $before (TreeHashes $H)
    Check "only the $($exp.upgraded) changed files, the new one and framework.lock moved (no file rewritten for its line endings)" (Same (Sorted $d) (Sorted (@($changedPaths | ForEach-Object { "changed $_" }) + @("new $($U.new.path)", 'changed framework.lock'))))
    $v = Run $src.installer @('-Target', $H, '-Verify')
    Check '-Verify after the upgrade: exit 0, 0 difference(s)' (($v.code -eq 0) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
}
'ga' {
    # THE ROOT .gitattributes IS INSTALLED. The framework's own (* -text and its two family lines), a
    # TEMPLATE, written by a fresh install only, into a folder that holds no file a git repository tracks;
    # kept by an upgrade where the project has one; NOT written by an upgrade where it has none, nor by a first install
    # into a repository with files of its own -- one line says so and why, the counts carry not-written=1, and the lock a
    # not-written row (sha256 and eol null) that -Verify and a same-version run pass over.
    $ga = '.gitattributes'
    $policy = "a framework install does not change a project's line-ending policy for the project's own files"
    $nwUpgrade = "install.ps1:   not-written        .gitattributes  -- not written: an upgrade adds no root .gitattributes where the project has none, since $policy"
    $nwTracked = "install.ps1:   not-written        .gitattributes  -- not written: the target holds files its git repository tracks, and $policy"
    function Check-NotWrittenRow { param([string]$Label, [string]$T, $Want)
        # The lock's row for the root .gitattributes, not-written: the columns of a template's, sha256 and eol null.
        $lkx = $null; if (Test-Path -LiteralPath (Join-Path $T 'framework.lock')) { $lkx = ReadLock $T }
        $rx = @(); if ($lkx) { $rx = @($lkx.rows | Where-Object { $_.path -ceq $ga }) }
        Check "$Label $ga is absent; its lock row is not-written: columns path,sha256,disposition,eol,kind,upstream_sha256, sha256 null, eol null, kind template, upstream_sha256 = sha256(fold(the release's)); the lock 1 + $($Want.count) lines" (
            (-not (Test-Path -LiteralPath (Join-Path $T $ga))) -and ($rx.Count -eq 1) -and ((Names $rx[0]) -ceq 'path,sha256,disposition,eol,kind,upstream_sha256') -and
            ($null -eq $rx[0].sha256) -and ($rx[0].disposition -ceq 'not-written') -and ($null -eq $rx[0].eol) -and ($rx[0].kind -ceq 'template') -and
            ($rx[0].upstream_sha256 -eq $Want.upstream) -and ($lkx.lines.Count -eq ($Want.count + 1)))
        return $lkx
    }
    function Check-NotWrittenVerify { param([string]$Label, [string]$T, [string]$Installer, [int]$Listed)
        $vx = Run $Installer @('-Target', $T, '-Verify')
        L "$Label -Verify: exit=$($vx.code) -- $(@($vx.out | Where-Object { $_ -match '^install\.ps1: verify: \d+ file' }) -join ' | ')"
        Check "$Label -Verify: exit 0, '$Listed file(s) listed, 1 not written, 0 difference(s)', nothing MISSING, CHANGED or REFUSED" (
            ($vx.code -eq 0) -and ((Count $vx.out "^install\.ps1: verify: $Listed file\(s\) listed, 1 not written, 0 difference\(s\); eol ") -eq 1) -and
            ((Count $vx.out '^install\.ps1:\s+(MISSING|CHANGED|REFUSED)\s') -eq 0))
        $lb = (ReadLock $T).raw
        $sx = Run $Installer @('-Target', $T)
        Check "$Label a same-version run: exit 0, already installed, framework.lock byte-identical" (($sx.code -eq 0) -and ((Count $sx.out '^install\.ps1: already installed: ') -ge 1) -and ((Sha (ReadLock $T).raw) -eq (Sha $lb)))
    }
    Check "the installer-owned set carries the root $ga, class TEMPLATE" ($owned.ContainsKey($ga) -and ($owned[$ga].class -ceq 'TEMPLATE'))
    L '--- (ga1) a fresh install into a git repository on a core.autocrlf=true host, then git add -A'
    $t = Join-Path $Work 't'
    $null = New-Item -ItemType Directory -Path $t
    $null = RunGit $t @('init', '-q'); $null = RunGit $t @('config', 'core.autocrlf', 'true'); $null = RunGit $t @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $t @('config', 'user.email', 'falsifier-fixture@localhost')
    Check '(ga1) the repository reads core.autocrlf true, no attributes file is configured, and it holds nothing but .git' (
        ((((RunGit $t @('config', '--get', 'core.autocrlf')).out) -join '').Trim() -ceq 'true') -and ((RunGit $t @('config', '--get-all', 'core.attributesfile')).out.Count -eq 0) -and
        (@(Get-ChildItem -LiteralPath $t -Force | Where-Object { $_.Name -ne '.git' }).Count -eq 0))
    $r = Run $installer @('-Target', $t)
    L "(ga1) install exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    Check "(ga1) exit 0, done: written=$N already-identical=0 kept=0 retired=0 refused=0" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0"))
    Check '(ga1) a repository holding nothing tracked: no line says not-written, and no count carries not-written=' ((Count $r.out 'not-written') -eq 0)
    $gp = Join-Path $t $ga
    $lk = $null; if (Test-Path -LiteralPath (Join-Path $t 'framework.lock')) { $lk = ReadLock $t }
    $gaRow = @(); if ($lk) { $gaRow = @($lk.rows | Where-Object { $_.path -ceq $ga }) }
    Check "(ga1) $ga written with the framework's bytes; its lock row kind template, disposition installed, upstream_sha256 = sha256(fold(source))" (
        (Test-Path -LiteralPath $gp -PathType Leaf) -and $owned.ContainsKey($ga) -and ((FileSha $gp) -eq $owned[$ga].sha256) -and ($gaRow.Count -eq 1) -and
        ($gaRow[0].kind -ceq 'template') -and ($gaRow[0].disposition -ceq 'installed') -and ($gaRow[0].upstream_sha256 -eq $srcFold[$ga]))
    $add = RunGit $t @('add', '-A')
    $warn = @($add.out | Where-Object { $_ -match '^warning: ' })
    L "(ga1) git add -A: exit $($add.code), $($add.out.Count) line(s) of output, $($warn.Count) warning(s)$(if ($warn.Count) { ' -- the first: ' + $warn[0] })"
    Check '(ga1) git add -A on the core.autocrlf=true host: exit 0 and 0 warnings' (($add.code -eq 0) -and ($warn.Count -eq 0))
    $null = RunGit $t @('commit', '-q', '-m', 'the installed framework'); $null = RunGit $t @('rm', '-r', '-q', '--cached', '.'); $null = RunGit $t @('reset', '--hard', '-q')
    $notAt = @($owned.Keys | Where-Object { $fp = Join-Path $t ($_ -replace '/', '\'); (-not (Test-Path -LiteralPath $fp -PathType Leaf)) -or ((FileSha $fp) -ne $owned[$_].sha256) })
    L "(ga1) after a commit and a fresh checkout on that host: $($notAt.Count) installed file(s) not at their manifest bytes$(if ($notAt.Count) { ' -- ' + (@($notAt | Select-Object -First 3) -join ', ') })"
    Check "(ga1) after a commit and a fresh checkout on that host, all $N installed files stand at their manifest bytes, raw" ($notAt.Count -eq 0)
    $v = Run $installer @('-Target', $t, '-Verify')
    Check '(ga1) -Verify over the checkout: exit 0, 0 difference(s)' (($v.code -eq 0) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
    # An earlier release's project: every installer-owned file of this release but the root .gitattributes, under the
    # real host's 0.1.1 lock, upgraded to a synthetic release built from this tree.
    $prior = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([System.StringComparer]::Ordinal)
    foreach ($k in $owned.Keys) { if ($k -cne $ga) { $prior[$k] = $owned[$k] } }
    $move = @($owned.Values | Where-Object { $_.class -eq 'MOVE' }).Count
    $other = @($owned.Values | Where-Object { $_.class -ne 'MOVE' }).Count
    foreach ($leg in @(@{ name = 'ga2'; own = $true }, @{ name = 'ga3'; own = $false })) {
        $nm = $leg.name
        L "--- ($nm) an upgrade of a project an earlier release installed, $(if ($leg.own) { 'with a .gitattributes of its own' } else { 'with no .gitattributes' })"
        $t2 = Join-Path $Work $nm
        Copy-Owned $Repo $t2 $prior
        $ownBytes = Bytes "# the project's own rules`n*.sh text eol=lf`n"
        if ($leg.own) { WriteBytes (Join-Path $t2 $ga) $ownBytes }
        Write-Lock1 -Target $t2 -Header (Header 'lock-header-0.1.1.json') -Paths @($prior.Keys)
        $src = New-Source -Dir (Join-Path $Work "src-$nm") -Version $U.release -From $Repo -Set $owned -Installer $installer
        $before = TreeHashes $t2
        $r = Run $src.installer @('-Target', $t2)
        L "($nm) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
        $kept = $(if ($leg.own) { $other } else { $other - 1 })
        $done = $(if ($leg.own) { "install.ps1: done: written=0 already-identical=$move kept=$kept retired=0 refused=0" } else { "install.ps1: done: written=0 already-identical=$move kept=$kept not-written=1 retired=0 refused=0" })
        Check "($nm) exit 0, $done" (($r.code -eq 0) -and (Has $r.out $done))
        $lk2 = $null; if (Test-Path -LiteralPath (Join-Path $t2 'framework.lock')) { $lk2 = ReadLock $t2 }
        $row = @(); if ($lk2) { $row = @($lk2.rows | Where-Object { $_.path -ceq $ga }) }
        $gp2 = Join-Path $t2 $ga
        if ($leg.own) {
            Check "($nm) the project's own $ga is kept byte for byte; its lock row kind template, disposition kept, sha256 = sha256(fold(the project's)), upstream_sha256 = sha256(fold(the release's))" (
                ((Test-Path -LiteralPath $gp2 -PathType Leaf) -and ((FileSha $gp2) -eq (Sha $ownBytes))) -and ($row.Count -eq 1) -and ($row[0].kind -ceq 'template') -and
                ($row[0].disposition -ceq 'kept') -and ($row[0].sha256 -eq (FoldSha $ownBytes)) -and $src.owned.ContainsKey($ga) -and ($row[0].upstream_sha256 -eq $src.fold[$ga]))
            Check "($nm) no line says not-written" ((Count $r.out 'not-written') -eq 0)
        } else {
            Check "($nm) the one line, exactly: $nwUpgrade" ((Has $r.out $nwUpgrade) -and ((Count $r.out 'not-written') -eq 2))
            $null = Check-NotWrittenRow "($nm)" $t2 @{ count = $src.owned.Count; upstream = $src.fold[$ga] }
        }
        $d = DiffTrees $before (TreeHashes $t2)
        Check "($nm) the upgrade moved only framework.lock" (Same (Sorted $d) @('changed framework.lock'))
        if (-not $leg.own) {
            Check-NotWrittenVerify "($nm)" $t2 $src.installer $src.owned.Count
            L "--- (ga3b) a later upgrade over the not-written row: it is read, and the root $ga is not written again"
            $src3 = New-Source -Dir (Join-Path $Work 'src-ga3b') -Version $U.next.release -From $Repo -Set $owned -Installer $installer
            $r3 = Run $src3.installer @('-Target', $t2)
            L "(ga3b) upgrade: exit=$($r3.code)"; $r3.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
            Check "(ga3b) exit 0, done: written=0 already-identical=$move kept=$kept not-written=1 retired=0 refused=0, the same line" (
                ($r3.code -eq 0) -and (Has $r3.out "install.ps1: done: written=0 already-identical=$move kept=$kept not-written=1 retired=0 refused=0") -and (Has $r3.out $nwUpgrade))
            $lk3 = Check-NotWrittenRow '(ga3b)' $t2 @{ count = $src3.owned.Count; upstream = $src3.fold[$ga] }
            Check "(ga3b) the lock reads version $($U.next.release), previous_version $($U.release)" ($lk3 -and ($lk3.header.version -ceq $U.next.release) -and ($lk3.header.previous_version -ceq $U.release))
        }
    }
    L '--- (ga4) a first install into a core.autocrlf=true repository that tracks a file of its own'
    $t4 = Join-Path $Work 'ga4'
    $null = New-Item -ItemType Directory -Path $t4
    $null = RunGit $t4 @('init', '-q'); $null = RunGit $t4 @('config', 'core.autocrlf', 'true'); $null = RunGit $t4 @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $t4 @('config', 'user.email', 'falsifier-fixture@localhost')
    WriteBytes (Join-Path $t4 'app\own.txt') (Bytes "the project's own file`nits second line`n")
    $null = RunGit $t4 @('add', '-A'); $null = RunGit $t4 @('commit', '-q', '-m', 'the project')
    $attrBefore = ((RunGit $t4 @('check-attr', 'text', '--', 'app/own.txt')).out -join '').Trim()
    Check "(ga4) the repository tracks exactly app/own.txt, and git reads its text attribute unspecified ($attrBefore)" (
        (Same (RunGit $t4 @('ls-files')).out @('app/own.txt')) -and ($attrBefore -ceq 'app/own.txt: text: unspecified'))
    $r4 = Run $installer @('-Target', $t4)
    L "(ga4) install exit=$($r4.code)"; $r4.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    Check "(ga4) exit 0, done: written=$($N - 1) already-identical=0 kept=0 not-written=1 retired=0 refused=0" (($r4.code -eq 0) -and (Has $r4.out "install.ps1: done: written=$($N - 1) already-identical=0 kept=0 not-written=1 retired=0 refused=0"))
    Check "(ga4) the one line, exactly: $nwTracked" ((Has $r4.out $nwTracked) -and ((Count $r4.out 'not-written') -eq 2))
    $null = Check-NotWrittenRow '(ga4)' $t4 @{ count = $N; upstream = $srcFold[$ga] }
    $attrAfter = ((RunGit $t4 @('check-attr', 'text', '--', 'app/own.txt')).out -join '').Trim()
    Check "(ga4) the project's line-ending policy for its own file is unchanged: git still reads it unspecified ($attrAfter)" ($attrAfter -ceq $attrBefore)
    Check-NotWrittenVerify '(ga4)' $t4 $installer $N
    L '--- (ga5) a target below a repository''s top: one where the repository tracks a file, one where it tracks none'
    $r5 = Join-Path $Work 'ga5'
    $null = New-Item -ItemType Directory -Path $r5
    $null = RunGit $r5 @('init', '-q'); $null = RunGit $r5 @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $r5 @('config', 'user.email', 'falsifier-fixture@localhost')
    WriteBytes (Join-Path $r5 'sub\own.txt') (Bytes "a tracked file below the top`n")
    $null = RunGit $r5 @('add', '-A'); $null = RunGit $r5 @('commit', '-q', '-m', 'the project')
    $sub = Join-Path $r5 'sub'; $empty = Join-Path $r5 'empty'
    $null = New-Item -ItemType Directory -Path $empty
    $r5s = Run $installer @('-Target', $sub)
    Check "(ga5) into sub\ (no .git of its own; the repository above tracks sub/own.txt): exit 0, not-written=1, the tracked line, $ga absent" (
        ($r5s.code -eq 0) -and (Has $r5s.out "install.ps1: done: written=$($N - 1) already-identical=0 kept=0 not-written=1 retired=0 refused=0") -and (Has $r5s.out $nwTracked) -and
        (-not (Test-Path -LiteralPath (Join-Path $sub $ga))))
    $r5e = Run $installer @('-Target', $empty)
    Check "(ga5) into empty\ (the same repository tracks nothing there): exit 0, done: written=$N, no not-written line, $ga written with the framework's bytes" (
        ($r5e.code -eq 0) -and (Has $r5e.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0") -and ((Count $r5e.out 'not-written') -eq 0) -and
        (Test-Path -LiteralPath (Join-Path $empty $ga) -PathType Leaf) -and ((FileSha (Join-Path $empty $ga)) -eq $owned[$ga].sha256))
}
'u' {
    $t = Join-Path $Work 't'
    Copy-Owned $Repo $t $owned
    Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
    $lk0 = ReadLock $t
    Check "the format-1 lock: the real host's 0.1.1 header, verbatim, and $N rows" (($lk0.lines[0] -ceq (Header 'lock-header-0.1.1.json')) -and ($lk0.rows.Count -eq $N))
    $src = New-Source -Dir (Join-Path $Work 'src') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $exp = Expect $src $changedPaths 1; $exp | Add-Member -NotePropertyName version -NotePropertyValue $U.release
    L "the synthetic $($U.release): $($src.owned.Count) installer-owned (MOVE $($exp.move)); K = $($exp.upgraded) changed ($($changedPaths -join ', ')); new $($U.new.path)"
    $v = Run $src.installer @('-Target', $t, '-Verify')
    L "-Verify over the 0.1.1 lock: exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    Check '-Verify reads the format-1 lock and says so: exit 0, 0 difference(s)' (($v.code -eq 0) -and (Has $v.out 'install.ps1: verify: read lock_format 1') -and ((Count $v.out " $N file\(s\) listed, 0 difference\(s\); eol ") -eq 1))
    $hp = Join-Path $t ($U.hardlinked -replace '/', '\'); $twin = Join-Path $Work 'twin.bin'
    Copy-Item -LiteralPath $hp -Destination $twin; [System.IO.File]::Delete($hp); $null = New-Item -ItemType HardLink -Path $hp -Target $twin
    $twinSha = FileSha $twin
    Check "$($U.hardlinked), a path the release changes, is now a hard link to a file outside the target, holding the bytes the lock recorded" (((Get-Item -LiteralPath $hp).LinkType -eq 'HardLink') -and ((FileSha $hp) -eq $twinSha) -and ($twinSha -eq $owned[$U.hardlinked].sha256))
    $before = TreeHashes $t
    $planned = "install.ps1: planned: written=$($exp.written) already-identical=$($exp.identical) kept=$($exp.kept) retired=0 refused=0"
    $w = Run $src.installer @('-Target', $t, '-WhatIf')
    L "-WhatIf: exit=$($w.code)"; $w.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    Check "-WhatIf: exit 0, $planned, nothing written" (($w.code -eq 0) -and (Has $w.out $planned) -and (Has $w.out 'install.ps1: WhatIf: nothing was written.') -and ((TreeHashes $t).aggregate -eq $before.aggregate) -and ((Stray $w.out).Count -eq 0))
    $r = Run $src.installer @('-Target', $t)
    L "upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=$($exp.written) already-identical=$($exp.identical) kept=$($exp.kept) retired=0 refused=0"
    Check "exit 0, the mode line, $done, and the closing line" (($r.code -eq 0) -and (Has $r.out "install.ps1: upgrade: framework.lock says $($U.from), and this release is $($U.release)") -and (Has $r.out $done) -and (Has $r.out "install.ps1: upgraded $($U.from) to $($U.release) in $t."))
    Check "$($exp.upgraded) per-file lines say upgrade and 1 says install" (((Count $r.out '^install\.ps1:   upgrade ') -eq $exp.upgraded) -and ((Count $r.out '^install\.ps1:   install ') -eq 1))
    $null = Check-Upgraded '(u)' $t $src $exp $U.from $changedPaths $U.new.path '2026-10-24T14:29:53.967Z'
    $d = DiffTrees $before (TreeHashes $t)
    Check "the upgrade moved only the $($exp.upgraded) changed files, the new one and framework.lock" (Same (Sorted $d) (Sorted (@($changedPaths | ForEach-Object { "changed $_" }) + @("new $($U.new.path)", 'changed framework.lock'))))
    Check "$($U.hardlinked) was upgraded as a new file: the target holds the release's bytes, and the hard-linked twin outside still holds the old ones" (((FileSha $hp) -eq (FileSha (Join-Path $src.root ($U.hardlinked -replace '/', '\')))) -and ((FileSha $twin) -eq $twinSha))
    Check 'no staging folder is left in the target' ((Staging $t) -eq 0)
    $v = Run $src.installer @('-Target', $t, '-Verify')
    L "-Verify after: exit=$($v.code)"; $v.out | Where-Object { $_ -match 'verify: (read|\d)' } | ForEach-Object { L "  | $_" }
    Check "-Verify reads lock_format 2, upgraded from $($U.from): exit 0, 0 difference(s)" (($v.code -eq 0) -and ((Count $v.out "^install\.ps1: verify: read lock_format 2, upgraded from $([regex]::Escape($U.from)) at ") -eq 1) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
    $lock1 = ReadLock $t
    $r = Run $src.installer @('-Target', $t)
    Check "a second run of $($U.release): exit 0, already installed, framework.lock byte-identical" (($r.code -eq 0) -and ((Count $r.out '^install\.ps1: already installed: ') -ge 1) -and ((ReadLock $t).sha -eq $lock1.sha))
}
'u2' {
    L '--- (A) a format-1 lock at the downgrade version over files identical to the release'
    $t = Join-Path $Work 't'
    Copy-Owned $Repo $t $owned
    Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json' $U.downgrade_lock) -Paths @($owned.Keys)
    $same = New-Source -Dir (Join-Path $Work 'src-same') -Version $U.release -From $Repo -Set $owned -Installer $installer
    $before = TreeHashes $t
    foreach ($wi in @($false, $true)) {
        $argv = @('-Target', $t); if ($wi) { $argv += '-WhatIf' }
        $r = Run $same.installer $argv
        L "(A) $($U.release) over a $($U.downgrade_lock) lock$(if ($wi) { ' -WhatIf' }): exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        Check "(A)$(if ($wi) { ' -WhatIf:' }) REFUSED downgrade, exit non-zero (2), planned: written=0 already-identical=0 kept=0 retired=0 refused=$($same.owned.Count), no other written=" (
            ($r.code -eq 2) -and ((Count $r.out ("^install\.ps1: REFUSED: downgrade -- framework\.lock says " + [regex]::Escape($U.downgrade_lock) + ", newer than this release, " + [regex]::Escape($U.release))) -eq 1) -and
            (Has $r.out "install.ps1: planned: written=0 already-identical=0 kept=0 retired=0 refused=$($same.owned.Count)") -and ((Stray $r.out).Count -eq 0))
        $after = TreeHashes $t
        Check "(A)$(if ($wi) { ' -WhatIf:' }) the target is hash-identical before and after, framework.lock included" (((DiffTrees $before $after).Count -eq 0) -and ($before.aggregate -eq $after.aggregate))
    }
    L '--- (B) a format-2 lock at the downgrade version, and a release that changes files'
    $t2 = Join-Path $Work 't2'
    Copy-Owned $Repo $t2 $owned
    $kindOf = @{ 'MOVE' = 'move'; 'TEMPLATE' = 'template'; 'HOST-CONFIG' = 'host-config' }
    $lines = @('{"lock":"vanguard-collective/framework.lock","lock_format":2,"eol_rule":"fold-crlf-text","version":"' + $U.downgrade_lock + '","previous_version":"0.2.0","framework_repo_tip":"' + $head + '","source_kind":"release","manifest_sha256":"' + (FileSha (Join-Path $Repo 'provenance\manifest.jsonl')) + '","zip_sha256":null,"installer_owned":' + $N + ',"installed_at":"2026-01-01T00:00:00.000Z","upgraded_at":"2026-06-01T00:00:00.000Z"}')
    foreach ($k in $owned.Keys) {
        $b = [System.IO.File]::ReadAllBytes((Join-Path $t2 ($k -replace '/', '\'))); $kd = $kindOf[$owned[$k].class]
        $lines += '{"path":"' + $k + '","sha256":"' + (FoldSha $b) + '","disposition":"already-identical","eol":"' + (EolOf $b) + '","kind":"' + $kd + '"' + $(if ($kd -ne 'move') { ',"upstream_sha256":"' + (FoldSha $b) + '"' }) + '}'
    }
    [System.IO.File]::WriteAllText((Join-Path $t2 'framework.lock'), (($lines -join "`n") + "`n"), $NoBom)
    $src = New-Source -Dir (Join-Path $Work 'src') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $before = TreeHashes $t2
    $r = Run $src.installer @('-Target', $t2)
    L "(B) exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check "(B) REFUSED downgrade, exit 2, planned counts, no other written=, the target hash-identical" (($r.code -eq 2) -and ((Count $r.out '^install\.ps1: REFUSED: downgrade -- ') -eq 1) -and ((Count $r.out '^install\.ps1: planned: written=0 ') -eq 1) -and ((Stray $r.out).Count -eq 0) -and ((TreeHashes $t2).aggregate -eq $before.aggregate))
    Check "(B) the new file of $($U.release) was not created" (-not (Test-Path -LiteralPath (Join-Path $t2 ($U.new.path -replace '/', '\'))))
    $V = $U.versions
    $move = @($owned.Values | Where-Object { $_.class -eq 'MOVE' }).Count; $tkCount = $N - $move
    L "--- (C) versions are numbers, not strings: a lock at $($V.high) against a release $($V.low) is a downgrade (as strings it would be an upgrade)"
    $t3 = Join-Path $Work 't3'; Copy-Owned $Repo $t3 $owned
    Write-Lock1 -Target $t3 -Header (Header 'lock-header-0.1.1.json' $V.high) -Paths @($owned.Keys)
    $sLow = New-Source -Dir (Join-Path $Work 'src-low') -Version $V.low -From $Repo -Set $owned -Installer $installer
    $before = TreeHashes $t3
    $r = Run $sLow.installer @('-Target', $t3)
    L "(C) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:|upgrade:' } | ForEach-Object { L "  | $_" }
    Check "(C) $($V.low) over a $($V.high) lock: REFUSED downgrade, exit 2, nothing written" (($r.code -eq 2) -and ((Count $r.out ('^install\.ps1: REFUSED: downgrade -- framework\.lock says ' + [regex]::Escape($V.high) + ', newer than this release, ' + [regex]::Escape($V.low))) -eq 1) -and ((TreeHashes $t3).aggregate -eq $before.aggregate))
    L "--- (D) and a lock at $($V.low) against a release $($V.high) is an upgrade"
    $t4 = Join-Path $Work 't4'; Copy-Owned $Repo $t4 $owned
    Write-Lock1 -Target $t4 -Header (Header 'lock-header-0.1.1.json' $V.low) -Paths @($owned.Keys)
    $sHigh = New-Source -Dir (Join-Path $Work 'src-high') -Version $V.high -From $Repo -Set $owned -Installer $installer
    $r = Run $sHigh.installer @('-Target', $t4)
    L "(D) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:|upgrade:' } | ForEach-Object { L "  | $_" }
    $lk = $null; if (Test-Path -LiteralPath (Join-Path $t4 'framework.lock')) { $lk = ReadLock $t4 }
    Check "(D) $($V.high) over a $($V.low) lock: an upgrade, exit 0, done: written=0 already-identical=$move kept=$tkCount retired=0 refused=0, the lock at $($V.high) naming $($V.low)" (($r.code -eq 0) -and
        (Has $r.out "install.ps1: upgrade: framework.lock says $($V.low), and this release is $($V.high)") -and (Has $r.out "install.ps1: done: written=0 already-identical=$move kept=$tkCount retired=0 refused=0") -and
        ($null -ne $lk) -and ($lk.header.version -ceq $V.high) -and ($lk.header.previous_version -ceq $V.low))
    L "--- (E) a pre-release version in the lock ($($V.prerelease_lock)) is refused"
    $t5 = Join-Path $Work 't5'; Copy-Owned $Repo $t5 $owned
    Write-Lock1 -Target $t5 -Header (Header 'lock-header-0.1.1.json' $V.prerelease_lock) -Paths @($owned.Keys)
    $before = TreeHashes $t5
    $r = Run $same.installer @('-Target', $t5)
    L "(E) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:' } | ForEach-Object { L "  | $_" }
    Check "(E) exit 2, the lock refused as unreadable for its version, planned counts, nothing written" (($r.code -eq 2) -and ((Count $r.out ("^install\.ps1: REFUSED: framework\.lock exists and cannot be read \(.*names version '" + [regex]::Escape($V.prerelease_lock) + "', which is not major\.minor\.patch\)")) -eq 1) -and ((Count $r.out '^install\.ps1: planned: ') -eq 1) -and ((Stray $r.out).Count -eq 0) -and ((TreeHashes $t5).aggregate -eq $before.aggregate))
    L "--- (F) a pre-release VERSION in the release ($($V.prerelease_release)) is refused"
    $sPre = New-Source -Dir (Join-Path $Work 'src-pre') -Version $V.prerelease_release -From $Repo -Set $owned -Installer $installer
    $t6 = Join-Path $Work 't6'
    $r = Run $sPre.installer @('-Target', $t6)
    L "(F) exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check "(F) exit 1, VERSION is not a version, and no target was created" (($r.code -eq 1) -and ((Count $r.out ("^install\.ps1: VERSION is not a version .*'" + [regex]::Escape($V.prerelease_release) + "'$")) -eq 1) -and -not (Test-Path -LiteralPath $t6))
}
'u3' {
    $t = Join-Path $Work 't'
    Copy-Owned $Repo $t $owned
    Check 'the target holds the bytes 0.1.0 wrote: every file raw-equal to its manifest line' ((@($owned.Keys | Where-Object { (FileSha (Join-Path $t ($_ -replace '/', '\'))) -ne $owned[$_].sha256 }).Count) -eq 0)
    Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.0.json') -Paths @($owned.Keys) -Raw
    $lk0 = ReadLock $t
    Check "the 0.1.0 lock: its real header, verbatim (no eol_rule), and $N rows of raw sha256s with no eol" (($lk0.lines[0] -ceq (Header 'lock-header-0.1.0.json')) -and ($null -eq $lk0.header.PSObject.Properties['eol_rule']) -and ((@($lk0.rows | Where-Object { $null -ne $_.PSObject.Properties['eol'] -or $_.sha256 -ne $owned[$_.path].sha256 }).Count) -eq 0))
    $cw = $U.crlf_written
    $cp = Join-Path $t ($cw -replace '/', '\')
    $cb = [System.IO.File]::ReadAllBytes($cp)
    [System.IO.File]::WriteAllBytes($cp, $L1.GetBytes($L1.GetString($cb).Replace("`r`n", "`n")))
    $lb = [System.IO.File]::ReadAllBytes($cp)
    $row = @($lk0.rows | Where-Object { $_.path -eq $cw })[0]
    L "$cw : 0.1.0 wrote it $(EolOf $cb) (row $($row.sha256)); now rendered $(EolOf $lb), raw $(Sha $lb), folded $(FoldSha $lb), CRLF form $(CrlfSha $lb)"
    Check "$cw was written CRLF by 0.1.0 and now stands LF: its raw and folded sha256 are not its row, its CRLF form (computed here) is" (((EolOf $cb) -eq 'crlf') -and ((EolOf $lb) -eq 'lf') -and ((Sha $lb) -ne $row.sha256) -and ((FoldSha $lb) -ne $row.sha256) -and ((CrlfSha $lb) -eq $row.sha256))
    $fw = $U.lf_now_crlf
    $fp = Join-Path $t ($fw -replace '/', '\')
    $fb0 = [System.IO.File]::ReadAllBytes($fp)
    [System.IO.File]::WriteAllBytes($fp, $L1.GetBytes($L1.GetString($fb0).Replace("`n", "`r`n")))
    $fb1 = [System.IO.File]::ReadAllBytes($fp)
    $frow = @($lk0.rows | Where-Object { $_.path -eq $fw })[0]
    Check "$fw was written LF by 0.1.0 and now stands CRLF: its raw sha256 is not its row, its folded one is (the fold leaves no CR LF pair)" (((EolOf $fb0) -eq 'lf') -and ((EolOf $fb1) -eq 'crlf') -and ((Sha $fb1) -ne $frow.sha256) -and ((FoldSha $fb1) -eq $frow.sha256))
    $v = Run $installer @('-Target', $t, '-Verify')
    L "-Verify over the 0.1.0 lock: exit=$($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    Check "-Verify reads the 0.1.0 lock exactly: exit 0, 0 difference(s), it says it read lock_format 1 with no eol_rule, eol not recorded" (($v.code -eq 0) -and ((Count $v.out '^install\.ps1: verify: read lock_format 1, no eol_rule') -eq 1) -and (Has $v.out "install.ps1: verify: $N file(s) listed, 0 difference(s); eol not recorded (a lock with no eol_rule)."))
    $src = New-Source -Dir (Join-Path $Work 'src') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $exp = Expect $src $changedPaths 1; $exp | Add-Member -NotePropertyName version -NotePropertyValue $U.release
    $before = TreeHashes $t
    $r = Run $src.installer @('-Target', $t)
    L "upgrade over the 0.1.0 lock: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=$($exp.written) already-identical=$($exp.identical) kept=$($exp.kept) retired=0 refused=0"
    Check "the upgrade succeeds: exit 0, $done" (($r.code -eq 0) -and (Has $r.out "install.ps1: upgrade: framework.lock says $($U.from_0_1_0), and this release is $($U.release)") -and (Has $r.out $done))
    $null = Check-Upgraded '(u3)' $t $src $exp $U.from_0_1_0 $changedPaths $U.new.path '2026-10-24T12:48:06.769Z'
    Check "$cw, held to its 0.1.0 row by its CRLF form, and $fw, held by its folded form, were upgraded (not refused as edited)" (((Count $r.out ('^install\.ps1:   upgrade\s+' + [regex]::Escape($cw) + '$')) -eq 1) -and ((Count $r.out ('^install\.ps1:   upgrade\s+' + [regex]::Escape($fw) + '$')) -eq 1))
    $v = Run $src.installer @('-Target', $t, '-Verify')
    Check '-Verify after: lock_format 2, exit 0, 0 difference(s)' (($v.code -eq 0) -and ((Count $v.out '^install\.ps1: verify: read lock_format 2') -eq 1) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
    L "--- (B) an edit under a 0.1.0 lock: $($U.unlisted) given one more line"
    $t2 = Join-Path $Work 't2'; Copy-Owned $Repo $t2 $owned
    Write-Lock1 -Target $t2 -Header (Header 'lock-header-0.1.0.json') -Paths @($owned.Keys) -Raw
    $ep = Join-Path $t2 ($U.unlisted -replace '/', '\')
    $fs = [System.IO.File]::Open($ep, [System.IO.FileMode]::Append); try { $x = [System.Text.Encoding]::ASCII.GetBytes("local edit`n"); $fs.Write($x, 0, $x.Length) } finally { $fs.Dispose() }
    $v = Run $installer @('-Target', $t2, '-Verify')
    Check "(B) -Verify over the 0.1.0 lock names $($U.unlisted) CHANGED and nothing else, exit 3" (($v.code -eq 3) -and ((Count $v.out ('CHANGED\s+' + [regex]::Escape($U.unlisted) + '\s')) -eq 1) -and ((Count $v.out ' 1 difference\(s\); eol not recorded') -eq 1))
    $before = TreeHashes $t2
    $r = Run $src.installer @('-Target', $t2)
    L "(B) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | ForEach-Object { L "  | $_" }
    Check "(B) the upgrade is refused as a whole, $($U.unlisted) edited-since-install, nothing written" (($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape($U.unlisted) + '\s+-- edited-since-install')) -eq 1) -and ((Count $r.out '^install\.ps1: REFUSED \S') -eq 1) -and ((Stray $r.out).Count -eq 0) -and ((TreeHashes $t2).aggregate -eq $before.aggregate))
    L "--- (C) $cw double-converted under a 0.1.0 lock (every CR LF made CR CR LF)"
    $t3 = Join-Path $Work 't3'; Copy-Owned $Repo $t3 $owned
    Write-Lock1 -Target $t3 -Header (Header 'lock-header-0.1.0.json') -Paths @($owned.Keys) -Raw
    $hp = Join-Path $t3 ($cw -replace '/', '\')
    [System.IO.File]::WriteAllBytes($hp, $L1.GetBytes($L1.GetString([System.IO.File]::ReadAllBytes($hp)).Replace("`r`n", "`r`r`n")))
    $v = Run $installer @('-Target', $t3, '-Verify')
    Check "(C) -Verify names $cw CHANGED, exit 3: none of its three forms is the row's bytes (its fold keeps a CR LF pair)" (($v.code -eq 3) -and ((Count $v.out ('CHANGED\s+' + [regex]::Escape($cw) + '\s')) -eq 1) -and ((Count $v.out ' 1 difference\(s\); eol not recorded') -eq 1))
}
'u4' {
    $src = New-Source -Dir (Join-Path $Work 'src') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $exp = Expect $src $changedPaths 1
    foreach ($sub in @(@{ name = 'A'; path = $U.edited_changed; written = $exp.written - 1; identical = $exp.identical }, @{ name = 'B'; path = $U.edited_unchanged; written = $exp.written; identical = $exp.identical - 1 })) {
        L "--- ($($sub.name)) a local edit to $($sub.path) ($(if ($changedPaths -contains $sub.path) { 'a path the release changes' } else { 'a path the release leaves alone' }))"
        $t = Join-Path $Work "t$($sub.name)"
        Copy-Owned $Repo $t $owned
        Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
        $ep = Join-Path $t ($sub.path -replace '/', '\')
        $fs = [System.IO.File]::Open($ep, [System.IO.FileMode]::Append); try { $x = [System.Text.Encoding]::ASCII.GetBytes("local edit`n"); $fs.Write($x, 0, $x.Length) } finally { $fs.Dispose() }
        $before = TreeHashes $t
        $r = Run $src.installer @('-Target', $t)
        L "($($sub.name)) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
        Check "($($sub.name)) exit 2, $($sub.path) REFUSED edited-since-install, the only refused path, the whole upgrade refused" (($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape($sub.path) + '\s+-- edited-since-install')) -eq 1) -and ((Count $r.out '^install\.ps1: REFUSED \S') -eq 1) -and ((Count $r.out "is refused as a whole\. Nothing was written -- no file and no lock\.$") -eq 1))
        $planned = "install.ps1: planned: written=$($sub.written) already-identical=$($sub.identical) kept=$($exp.kept) retired=0 refused=1"
        Check "($($sub.name)) $planned, and no line carries written= but that one (no done:)" ((Has $r.out $planned) -and ((Stray $r.out).Count -eq 0) -and ((Count $r.out '^install\.ps1: done:') -eq 0))
        $after = TreeHashes $t
        Check "($($sub.name)) nothing was written: the target hash-identical, framework.lock included; the new file absent; the changed files still the old bytes" (
            ((DiffTrees $before $after).Count -eq 0) -and ($before.aggregate -eq $after.aggregate) -and -not (Test-Path -LiteralPath (Join-Path $t ($U.new.path -replace '/', '\'))) -and
            ((@($changedPaths | Where-Object { $_ -ne $sub.path -and (FileSha (Join-Path $t ($_ -replace '/', '\'))) -ne $owned[$_].sha256 }).Count) -eq 0))
    }
    foreach ($sub in @(@{ name = 'C'; what = 'the old lock does not list it'; why = 'not-installed-by-framework' }, @{ name = 'D'; what = 'the old lock records it as the host''s own (host-instance-kept)'; why = 'host-instance' })) {
        L "--- ($($sub.name)) $($U.unlisted), unedited, a path the release changes: $($sub.what)"
        $t = Join-Path $Work "t$($sub.name)"
        Copy-Owned $Repo $t $owned
        Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
        $lp = Join-Path $t 'framework.lock'
        $ll = @([System.IO.File]::ReadAllText($lp).Split([char]10) | Where-Object { $_ })
        $mark = '{"path":"' + $U.unlisted + '",'
        if ($sub.name -eq 'C') { $ll = @($ll | Where-Object { -not $_.StartsWith($mark) }) }
        else { $ll = @($ll | ForEach-Object { if ($_.StartsWith($mark)) { $_.Replace('"disposition":"installed"', '"disposition":"host-instance-kept"') } else { $_ } }) }
        [System.IO.File]::WriteAllText($lp, (($ll -join "`n") + "`n"), $NoBom)
        $before = TreeHashes $t
        $r = Run $src.installer @('-Target', $t)
        L "($($sub.name)) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | ForEach-Object { L "  | $_" }
        $planned = "install.ps1: planned: written=$($exp.written - 1) already-identical=$($exp.identical) kept=$($exp.kept) retired=0 refused=1"
        Check "($($sub.name)) exit 2, $($U.unlisted) REFUSED $($sub.why), the only refusal; $planned; nothing written" (($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape($U.unlisted) + '\s+-- ' + $sub.why + ':')) -eq 1) -and
            ((Count $r.out '^install\.ps1: REFUSED \S') -eq 1) -and (Has $r.out $planned) -and ((Stray $r.out).Count -eq 0) -and ((TreeHashes $t).aggregate -eq $before.aggregate))
    }
}
'u5' {
    $t = Join-Path $Work 't'
    Copy-Owned $Repo $t $owned
    $hdr = Header 'lock-header-0.1.1.json' $Version
    Write-Lock1 -Target $t -Header $hdr -Paths @($owned.Keys)
    L "the format-1 lock header (the real host's, version set to this checkout's $Version): $hdr"
    $before = TreeHashes $t
    $lock0 = ReadLock $t
    $r = Run $installer @('-Target', $t)
    L "the same-version run: exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check 'exit 0, already installed, -Verify 0 differences inside it, nothing written' (($r.code -eq 0) -and ((Count $r.out '^install\.ps1: already installed: framework\.lock says ') -eq 1) -and ((Count $r.out " $N file\(s\) listed, 0 difference\(s\); eol ") -eq 1) -and (Has $r.out "install.ps1: already installed: $Version in $t; nothing was written, and framework.lock is untouched."))
    Check 'no line carries written=' ((Count $r.out 'written=') -eq 0)
    Check 'framework.lock is byte-identical before and after (still lock_format 1)' (((ReadLock $t).sha -eq $lock0.sha) -and ((ReadLock $t).header.lock_format -eq 1))
    Check 'the whole target is hash-identical' ((TreeHashes $t).aggregate -eq $before.aggregate)
}
'u6' {
    $G = $U.guard
    L '--- (i) a manifest carrying a .. destination and an absolute one'
    $S = Join-Path $Work 'src'
    $out6 = Join-Path $Work 'outside'
    $abs = Join-Path $out6 'abs.txt'
    $null = New-Item -ItemType Directory -Path (Join-Path $S 'provenance')
    Copy-Item -LiteralPath $installer -Destination (Join-Path $S 'install.ps1')
    [System.IO.File]::WriteAllText((Join-Path $S 'VERSION'), "$($U.release)`n", $NoBom)
    WriteBytes (Join-Path $S 'probe.txt') (Bytes "a file the path guard admits`n")
    $man = ([System.IO.File]::ReadAllText((Join-Path $Fix 'guard.manifest.jsonl'))).Replace('@ABS@', $abs.Replace('\', '\\'))
    [System.IO.File]::WriteAllText((Join-Path $S 'provenance\manifest.jsonl'), $man, $NoBom)
    [System.IO.File]::WriteAllText((Join-Path $S 'RELEASE'), "name: vanguard-collective`nversion: $($U.release)`nframework_repo_tip: $head`nmanifest_sha256: $(FileSha (Join-Path $S 'provenance\manifest.jsonl'))`n", $NoBom)
    $t = Join-Path $Work 't'
    $r = Run (Join-Path $S 'install.ps1') @('-Target', $t)
    L "(i) exit=$($r.code)"; $r.out | ForEach-Object { L "  | $_" }
    Check "(i) exit 2; '$($G.escape)' REFUSED for its '..' segment; $abs REFUSED as absolute or drive-qualified" (
        ($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape($G.escape) + "\s+-- path guard: a '\.\.' segment")) -eq 1) -and
        ((Count $r.out ('REFUSED\s+' + [regex]::Escape($abs) + '\s+-- path guard: a (drive-qualified|absolute) path')) -eq 1))
    Check "(i) framework.lock/x.txt REFUSED as under the lock's name; CON/x.txt as a device name; x/a:b.txt for its colon; x/trailing. for its trailing dot" (
        ((Count $r.out 'REFUSED\s+framework\.lock/x\.txt\s+-- path guard: it is the lock, or lies under its name$') -eq 1) -and ((Count $r.out "REFUSED\s+CON/x\.txt\s+-- path guard: 'CON' is a Windows device name$") -eq 1) -and
        ((Count $r.out "REFUSED\s+x/a:b\.txt\s+-- path guard: a character Windows does not allow in a name, in 'a:b\.txt'$") -eq 1) -and ((Count $r.out "REFUSED\s+x/trailing\.\s+-- path guard: 'trailing\.' ends in a dot or a space") -eq 1))
    Check '(i) the six are the only refusals: planned: written=1 already-identical=0 kept=0 retired=0 refused=6, and no other written=' (((Count $r.out '^install\.ps1: REFUSED \S') -eq 6) -and (Has $r.out 'install.ps1: planned: written=1 already-identical=0 kept=0 retired=0 refused=6') -and ((Stray $r.out).Count -eq 0))
    Check '(i) nothing written: no target folder, no escape.txt beside it, nothing at the absolute path' ((-not (Test-Path -LiteralPath $t)) -and (-not (Test-Path -LiteralPath (Join-Path $Work 'escape.txt'))) -and (-not (Test-Path -LiteralPath $abs)))

    L "--- (ii) a junction at $($G.junction)\ inside the target, to a folder outside it"
    $tj = Join-Path $Work 'tj'; $else = Join-Path $Work 'elsewhere'
    $null = New-Item -ItemType Directory -Path $tj; $null = New-Item -ItemType Directory -Path $else
    $null = New-Item -ItemType Junction -Path (Join-Path $tj $G.junction) -Target $else
    $under = @($owned.Keys | Where-Object { $_.StartsWith($G.junction + '/') }).Count
    $r = Run $installer @('-Target', $tj)
    L "(ii) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | Select-Object -First 6 | ForEach-Object { L "  | $_" }
    Check "(ii) exit 2; each of the $under paths under $($G.junction)/ REFUSED for the reparse point, a junction, and no other" (($r.code -eq 2) -and ((Count $r.out ('^install\.ps1:   REFUSED\s+' + [regex]::Escape($G.junction) + '/\S+\s+-- path guard: a reparse point stands at .*: a junction$')) -eq $under) -and ((Count $r.out '^install\.ps1: REFUSED \S') -eq $under))
    $docsUnder = $under
    Check "(ii) planned: written=$($N - $under) ... refused=$under, and no other written=" ((Has $r.out "install.ps1: planned: written=$($N - $under) already-identical=0 kept=0 retired=0 refused=$under") -and ((Stray $r.out).Count -eq 0))
    Check '(ii) nothing written: the folder outside is still empty, and the target holds only the junction' ((@([System.IO.Directory]::GetFileSystemEntries($else)).Count -eq 0) -and (@([System.IO.Directory]::GetFileSystemEntries($tj)).Count -eq 1))

    L "--- (iii) the read bound: $($G.bound_exact) at exactly $($G.read_bound) bytes, $($G.bound_over) at one byte more"
    $tb = Join-Path $Work 'tb'
    foreach ($pair in @(@($G.bound_exact, $G.read_bound), @($G.bound_over, ($G.read_bound + 1)))) {
        $p = Join-Path $tb ($pair[0] -replace '/', '\'); $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)
        $fs = [System.IO.File]::Create($p); try { $fs.SetLength([long]$pair[1]) } finally { $fs.Dispose() }
    }
    L "(iii) on disk: $($G.bound_exact) $((Get-Item -LiteralPath (Join-Path $tb ($G.bound_exact -replace '/', '\'))).Length) bytes, $($G.bound_over) $((Get-Item -LiteralPath (Join-Path $tb ($G.bound_over -replace '/', '\'))).Length) bytes"
    $before = TreeHashes $tb
    $r = Run $installer @('-Target', $tb)
    L "(iii) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | ForEach-Object { L "  | $_" }
    Check "(iii) exit 2; $($G.bound_over) REFUSED 'exceeds read bound'; $($G.bound_exact) judged (REFUSED not-installed-by-framework), not bounded" (($r.code -eq 2) -and
        ((Count $r.out ('REFUSED\s+' + [regex]::Escape($G.bound_over) + '\s+-- path guard: exceeds read bound: ' + ($G.read_bound + 1) + ' bytes')) -eq 1) -and
        ((Count $r.out ('REFUSED\s+' + [regex]::Escape($G.bound_exact) + '\s+-- not-installed-by-framework')) -eq 1) -and ((Count $r.out '^install\.ps1: REFUSED \S') -eq 2))
    Check "(iii) planned: written=$($N - 2) ... refused=2; nothing written" ((Has $r.out "install.ps1: planned: written=$($N - 2) already-identical=0 kept=0 retired=0 refused=2") -and ((Stray $r.out).Count -eq 0) -and ((TreeHashes $tb).aggregate -eq $before.aggregate))
    Remove-Tree $tb
    $im = DocText (Join-Path $Repo 'INSTALL.md')
    $mib = DocInt $im 'larger than (\d+) MiB \((\d+) bytes\)' 1; $byt = DocInt $im 'larger than (\d+) MiB \((\d+) bytes\)' 2
    Check "INSTALL.md: larger than $mib MiB ($byt bytes) = the bound this case found: $($G.read_bound) admitted to judgement, one byte more refused" (($byt -eq $G.read_bound) -and ($mib * 1048576 -eq $G.read_bound))

    L "--- (iv) the path limit: a target whose longest installed path reaches $($G.path_limit) characters, and one that stops at $($G.path_limit - 1)"
    $longest = (@($owned.Keys | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum
    $lp = @($owned.Keys | Where-Object { $_.Length -eq $longest })[0]
    $base = Join-Path $Work 'len'
    $null = New-Item -ItemType Directory -Path $base
    foreach ($full in @($G.path_limit, ($G.path_limit - 1))) {
        $rootLen = $full - 1 - $longest
        $tl = $base + '\' + ('p' * ($rootLen - $base.Length - 1))
        $r = Run $installer @('-Target', $tl)
        L "(iv) target $($tl.Length) characters -> the longest path $($tl.Length + 1 + $longest): exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | ForEach-Object { L "  | $_" }
        if ($full -eq $G.path_limit) {
            Check "(iv) at $full characters: exit 2, $lp REFUSED naming $full characters, planned counts, nothing written" (($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape($lp) + "\s+-- path guard: $full characters in full")) -eq 1) -and ((Count $r.out '^install\.ps1: planned: ') -eq 1) -and ((Stray $r.out).Count -eq 0) -and -not (Test-Path -LiteralPath $tl))
        } else {
            Check "(iv) at $full characters: exit 0, done: written=$N, and the longest file stands at $full characters" (($r.code -eq 0) -and (Has $r.out "install.ps1: done: written=$N already-identical=0 kept=0 retired=0 refused=0") -and (Test-Path -LiteralPath (Join-Path $tl ($lp -replace '/', '\'))) -and ((Join-Path $tl ($lp -replace '/', '\')).Length -eq $full))
            Remove-Tree $tl
        }
    }
    $lim = DocInt $im 'refuses a target that would reach (\d+)'
    $lim5 = DocInt $im 'a full path of (\d+) characters or more is refused'
    Check "INSTALL.md: install.ps1 refuses a target that would reach $lim, and (section 5) a full path of $lim5 characters or more, = the limit this case found" (($lim -eq $G.path_limit) -and ($lim5 -eq $G.path_limit))

    L '--- (v) a file where a folder goes: a FILE named tools in the target'
    $tf = Join-Path $Work 'tf'
    WriteBytes (Join-Path $tf 'tools') (Bytes "not a folder`n")
    $under = @($owned.Keys | Where-Object { $_.StartsWith('tools/') }).Count
    $before = TreeHashes $tf
    $r = Run $installer @('-Target', $tf)
    L "(v) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:|FAILED' } | Select-Object -First 4 | ForEach-Object { L "  | $_" }
    Check "(v) exit 2; each of the $under paths under tools/ REFUSED (a file stands where the folder goes); planned counts; nothing written" (($r.code -eq 2) -and ((Count $r.out '^install\.ps1:   REFUSED\s+tools/\S+\s+-- path guard: a file stands where the folder ') -eq $under) -and ((Count $r.out '^install\.ps1: planned: ') -eq 1) -and ((Stray $r.out).Count -eq 0) -and ((TreeHashes $tf).aggregate -eq $before.aggregate))

    L "--- (vi) a drive root as the target (subst), the installer's process standing in a folder below it, a junction at $($G.junction)\"
    $letter = @('Z', 'Y', 'X', 'W', 'V', 'U', 'T', 'S', 'R', 'Q') | Where-Object { -not (Test-Path -LiteralPath "$($_):\") } | Select-Object -First 1
    if (-not $letter) { Check '(vi) a free drive letter for subst' $false } else {
        $dr = Join-Path $Work 'drive'; $null = New-Item -ItemType Directory -Path (Join-Path $dr 'sub')
        $else2 = Join-Path $Work 'elsewhere2'; $null = New-Item -ItemType Directory -Path $else2
        $null = New-Item -ItemType Junction -Path (Join-Path $dr $G.junction) -Target $else2
        $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $null = & subst "$($letter):" $dr 2>&1; $ErrorActionPreference = $p
        try {
            Check "(vi) $($letter): is $dr" (Test-Path -LiteralPath "$($letter):\sub")
            Push-Location -LiteralPath "$($letter):\sub"; $cwd = [Environment]::CurrentDirectory; [Environment]::CurrentDirectory = "$($letter):\sub"
            try { $r = Run $installer @('-Target', "$($letter):\") } finally { [Environment]::CurrentDirectory = $cwd; Pop-Location }
            L "(vi) $($letter):\ from $($letter):\sub: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | Select-Object -First 4 | ForEach-Object { L "  | $_" }
            Check "(vi) exit 2; each of the $docsUnder paths under $($G.junction)/ REFUSED for the junction at $($letter):\$($G.junction), not judged under the process's folder $($letter):\sub" (($r.code -eq 2) -and
                ((Count $r.out ('^install\.ps1:   REFUSED\s+' + [regex]::Escape($G.junction) + '/\S+\s+-- path guard: a reparse point stands at ' + [regex]::Escape("$($letter):\$($G.junction)") + ': a junction$')) -eq $docsUnder) -and ((Count $r.out '^install\.ps1: REFUSED \S') -eq $docsUnder))
            Check '(vi) nothing written: the folder the junction points to is empty, and the drive root holds only sub and the junction' ((@([System.IO.Directory]::GetFileSystemEntries($else2)).Count -eq 0) -and (@([System.IO.Directory]::GetFileSystemEntries($dr)).Count -eq 2))
        } finally { $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $null = & subst "$($letter):" /d 2>&1; $ErrorActionPreference = $p }
        Check "(vi) the subst drive $($letter): is removed" (-not (Test-Path -LiteralPath "$($letter):\"))
    }

    L '--- (vii) another name for a folder: the 8.3 short name of the target''s .mission'
    $ta = Join-Path $Work 'ta'; $tm = [System.IO.Path]::Combine($ta, '.mission'); $null = New-Item -ItemType Directory -Path $tm
    $short = ''; try { $short = (New-Object -ComObject Scripting.FileSystemObject).GetFolder($tm).ShortName } catch { }
    L "(vii) the 8.3 name of $tm on this volume: '$short'"
    if (-not $short -or $short -eq '.mission') { L '(vii) this volume makes no 8.3 names, so there is no other name to refuse: not measured here'; Check '(vii) 8.3 names are made on this volume (needed to measure the alias)' $false } else {
        $S7 = Join-Path $Work 'src7'
        $null = New-Item -ItemType Directory -Path (Join-Path $S7 'provenance')
        Copy-Item -LiteralPath $installer -Destination (Join-Path $S7 'install.ps1')
        [System.IO.File]::WriteAllText((Join-Path $S7 'VERSION'), "$($U.release)`n", $NoBom)
        $pb = Bytes "a file the path guard admits`n"; $mb = Bytes "a release file aimed at .mission by its 8.3 name`n"
        WriteBytes (Join-Path $S7 'probe.txt') $pb; WriteBytes ([System.IO.Path]::Combine($S7, $short, 'mission.yaml')) $mb
        $man = '{"manifest":"provenance","note":"the 8.3 alias probe"}' + "`n" +
            '{"source":"host","path":"probe.txt","class":"MOVE","sha256":"' + (Sha $pb) + '","bytes":' + $pb.Length + ',"destination":"probe.txt"}' + "`n" +
            '{"source":"host","path":"m","class":"MOVE","sha256":"' + (Sha $mb) + '","bytes":' + $mb.Length + ',"destination":"' + $short + '/mission.yaml"}' + "`n"
        [System.IO.File]::WriteAllText((Join-Path $S7 'provenance\manifest.jsonl'), $man, $NoBom)
        [System.IO.File]::WriteAllText((Join-Path $S7 'RELEASE'), "name: vanguard-collective`nversion: $($U.release)`nframework_repo_tip: $head`nmanifest_sha256: $(FileSha (Join-Path $S7 'provenance\manifest.jsonl'))`n", $NoBom)
        $r = Run (Join-Path $S7 'install.ps1') @('-Target', $ta)
        L "(vii) exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|planned:|done:' } | ForEach-Object { L "  | $_" }
        Check "(vii) exit 2; $short/mission.yaml REFUSED: '$short' is another name for .mission; planned counts" (($r.code -eq 2) -and ((Count $r.out ('REFUSED\s+' + [regex]::Escape("$short/mission.yaml") + "\s+-- path guard: '" + [regex]::Escape($short) + "' is another name \(an 8\.3 short name\) for \.mission in ")) -eq 1) -and ((Count $r.out '^install\.ps1: planned: ') -eq 1))
        Check '(vii) nothing written: .mission is still empty, and the target holds only it' ((@([System.IO.Directory]::GetFileSystemEntries($tm)).Count -eq 0) -and (@([System.IO.Directory]::GetFileSystemEntries($ta)).Count -eq 1))
    }

    L "--- (viii) -Verify through the same guard: $($G.junction)\ made a junction to its own files moved outside, and $($G.verify_bound) grown past the read bound"
    $tv = Join-Path $Work 'tv'
    $r = Run $installer @('-Target', $tv)
    Check '(viii) a fresh install: exit 0' ($r.code -eq 0)
    $moved = Join-Path $Work 'docs-moved'
    Move-Item -LiteralPath (Join-Path $tv $G.junction) -Destination $moved
    $null = New-Item -ItemType Junction -Path (Join-Path $tv $G.junction) -Target $moved
    $fs = [System.IO.File]::Open((Join-Path $tv ($G.verify_bound -replace '/', '\')), [System.IO.FileMode]::Open); try { $fs.SetLength([long]($G.read_bound + 1)) } finally { $fs.Dispose() }
    $v = Run $installer @('-Target', $tv, '-Verify')
    L "(viii) -Verify: exit=$($v.code)"; $v.out | Where-Object { $_ -match 'REFUSED|CHANGED|MISSING|verify: \d' } | Select-Object -First 3 | ForEach-Object { L "  | $_" }; $v.out | Where-Object { $_ -match 'verify: \d' } | ForEach-Object { L "  | $_" }
    Check "(viii) -Verify exit 3: each of the $docsUnder paths under $($G.junction)/ REFUSED for the junction (not read through it), $($G.verify_bound) REFUSED 'exceeds read bound', nothing else" (($v.code -eq 3) -and
        ((Count $v.out ('^install\.ps1:   REFUSED  ' + [regex]::Escape($G.junction) + '/\S+  -- path guard: a reparse point stands at .*: a junction$')) -eq $docsUnder) -and
        ((Count $v.out ('^install\.ps1:   REFUSED  ' + [regex]::Escape($G.verify_bound) + '  -- path guard: exceeds read bound: ')) -eq 1) -and ((Count $v.out '^install\.ps1:   (REFUSED|CHANGED|MISSING)  ') -eq $docsUnder + 1) -and
        ((Count $v.out " $N file\(s\) listed, $($docsUnder + 1) difference\(s\); eol ") -eq 1))
}
'u8' {
    $t = Join-Path $Work 't'
    Copy-Owned $Repo $t $owned
    Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
    $s2 = New-Source -Dir (Join-Path $Work 'src2') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $r = Run $s2.installer @('-Target', $t)
    Check "the upgrade to $($U.release) first: exit 0" ($r.code -eq 0)
    if ($r.code -ne 0) { throw "the upgrade to $($U.release) did not succeed, and the rest of (u8) stands on it" }
    $nx = $U.next
    $ht = Join-Path $t ($nx.host_template.path -replace '/', '\')
    $hostBytes = [byte[]]([System.IO.File]::ReadAllBytes($ht) + (Bytes $nx.host_template.append)); [System.IO.File]::WriteAllBytes($ht, $hostBytes)
    $hc = Join-Path $t ($nx.host_config_absent -replace '/', '\'); [System.IO.File]::Delete($hc)
    $retiredBytes = FileSha (Join-Path $t ($nx.retired -replace '/', '\'))
    $upBefore = FileSha (Join-Path $t ($nx.upstream_template.path -replace '/', '\'))
    L "the host edits $($nx.host_template.path) and deletes $($nx.host_config_absent); the synthetic $($nx.release) retires $($nx.retired) and changes $($nx.upstream_template.path) upstream"
    $cr = $nx.case_renamed
    L "and it changes $($cr.from) and names it $($cr.to): the same file to Windows, in another case"
    $s3 = New-Source -Dir (Join-Path $Work 'src3') -Version $nx.release -From $s2.root -Set $s2.owned -Changes @($nx.upstream_template) -Remove @($nx.retired) -Installer $installer -Rename $cr
    $move3 = @($s3.owned.Values | Where-Object { $_.class -eq 'MOVE' }).Count
    $kept3 = @($s3.owned.Values | Where-Object { $_.class -ne 'MOVE' }).Count - 1
    $before = TreeHashes $t
    $r = Run $s3.installer @('-Target', $t)
    L "upgrade $($U.release) -> $($nx.release): exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   already-identical ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=2 already-identical=$($move3 - 1) kept=$kept3 retired=1 refused=0"
    Check "exit 0, $done, the retired path listed as left in place" (($r.code -eq 0) -and (Has $r.out $done) -and ((Count $r.out ('^install\.ps1:   retire\s+' + [regex]::Escape($nx.retired) + '\s+-- in framework\.lock, not in this release: left in place, dropped from the lock$')) -eq 1))
    $lk = ReadLock $t
    L "lock header: $($lk.lines[0])"
    Check "the lock: lock_format 2 read and rewritten, version $($nx.release), previous_version $($U.release), installed_at still the first install's (2026-10-24T14:29:53.967Z)" (($lk.header.lock_format -eq 2) -and ($lk.header.version -ceq $nx.release) -and ($lk.header.previous_version -ceq $U.release) -and ($lk.header.installed_at -ceq '2026-10-24T14:29:53.967Z'))
    Check "the retired path: dropped from the lock, left on disk byte-identical" ((@($lk.rows | Where-Object { $_.path -eq $nx.retired }).Count -eq 0) -and ((FileSha (Join-Path $t ($nx.retired -replace '/', '\'))) -eq $retiredBytes))
    $rt = @($lk.rows | Where-Object { $_.path -eq $nx.host_template.path })[0]
    Check "the host's drifted template $($nx.host_template.path): kept, sha256 = the host file's, upstream_sha256 = the release's, the two differ" (($rt.disposition -ceq 'kept') -and ($rt.sha256 -eq (FoldSha $hostBytes)) -and ($rt.upstream_sha256 -eq $s3.fold[$nx.host_template.path]) -and ($rt.sha256 -ne $rt.upstream_sha256))
    $ru = @($lk.rows | Where-Object { $_.path -eq $nx.upstream_template.path })[0]
    Check "the template changed upstream, $($nx.upstream_template.path): kept and NOT rewritten, its upstream_sha256 the new release's, so the drift reads in the lock" (($ru.disposition -ceq 'kept') -and ((FileSha (Join-Path $t ($nx.upstream_template.path -replace '/', '\'))) -eq $upBefore) -and ($ru.upstream_sha256 -eq $s3.fold[$nx.upstream_template.path]) -and ($ru.sha256 -ne $ru.upstream_sha256))
    $rh = @($lk.rows | Where-Object { $_.path -eq $nx.host_config_absent })[0]
    Check "the absent host-config $($nx.host_config_absent): installed, kind host-config, the release's bytes on disk" (($rh.disposition -ceq 'installed') -and ($rh.kind -ceq 'host-config') -and ($rh.upstream_sha256 -eq $rh.sha256) -and ((FileSha $hc) -eq (FileSha (Join-Path $s3.root ($nx.host_config_absent -replace '/', '\')))))
    $rc = @($lk.rows | Where-Object { $_.path -ceq $cr.to })[0]
    $onDisk = @([System.IO.Directory]::GetFiles([System.IO.Path]::GetDirectoryName((Join-Path $t ($cr.to -replace '/', '\'))), [System.IO.Path]::GetFileName($cr.to)) | ForEach-Object { [System.IO.Path]::GetFileName($_) })
    Check "the path whose case changed, $($cr.to): upgraded-from $($U.release), not refused and not retired; on disk under its new name with the release's bytes" (($null -ne $rc) -and ($rc.disposition -ceq "upgraded-from $($U.release)") -and
        (@($lk.rows | Where-Object { $_.path -ceq $cr.from }).Count -eq 0) -and ((Count $r.out ('^install\.ps1:   retire\s+' + [regex]::Escape($cr.from))) -eq 0) -and
        ((@($onDisk) -join ',') -ceq [System.IO.Path]::GetFileName($cr.to)) -and ((FileSha (Join-Path $t ($cr.to -replace '/', '\'))) -eq (FileSha (Join-Path $s3.root ($cr.to -replace '/', '\')))))
    $d = DiffTrees $before (TreeHashes $t)
    Check 'the upgrade moved only the host-config it installed, the renamed file and framework.lock' (Same (Sorted $d) (Sorted @("new $($nx.host_config_absent)", "gone $($cr.from)", "new $($cr.to)", 'changed framework.lock')))
    Check 'no staging folder is left in the target' ((Staging $t) -eq 0)
    $v = Run $s3.installer @('-Target', $t, '-Verify')
    Check "-Verify: exit 0, 0 difference(s), upgraded from $($U.release)" (($v.code -eq 0) -and ((Count $v.out "^install\.ps1: verify: read lock_format 2, upgraded from $([regex]::Escape($U.release)) at ") -eq 1) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
}
'u9' {
    $t = Join-Path $Work 't'
    Copy-Owned $Repo $t $owned
    Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
    $src = New-Source -Dir (Join-Path $Work 'src') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    $exp = Expect $src $changedPaths 1
    $writes = Sorted (@($changedPaths) + @($U.new.path))
    Check "$($U.held) is the last of the $($writes.Count) files the upgrade writes, in the order it writes them" ($writes[-1] -ceq $U.held)
    $lock0 = ReadLock $t
    $hp = Join-Path $t ($U.held -replace '/', '\')
    $held0 = FileSha $hp
    L "--- $($U.held) held open (read, shared for reading only): it can be read, and not deleted"
    $fh = [System.IO.File]::Open($hp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try { $r = Run $src.installer @('-Target', $t) } finally { $fh.Dispose() }
    L "the upgrade with the file held: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    $before = $writes.Count - 1
    Check "exit 1, MOVE FAILED at $($U.held), $before file(s) moved into place before it, no done: line" (($r.code -eq 1) -and ((Count $r.out ('^install\.ps1: MOVE FAILED at ' + [regex]::Escape($U.held) + ': .* ' + $before + ' file\(s\) were moved into place before it, each whole, and framework\.lock was not rewritten\.')) -eq 1) -and ((Count $r.out '^install\.ps1: done:') -eq 0))
    $whole = @($writes | Where-Object { $_ -cne $U.held } | Where-Object { (FileSha (Join-Path $t ($_ -replace '/', '\'))) -ne (FileSha (Join-Path $src.root ($_ -replace '/', '\'))) })
    Check "the $before files before it hold the release's bytes, whole; $($U.held) its old bytes; framework.lock byte-identical; no staging folder left" (($whole.Count -eq 0) -and ((FileSha $hp) -eq $held0) -and ((ReadLock $t).sha -eq $lock0.sha) -and ((Staging $t) -eq 0))
    $r = Run $src.installer @('-Target', $t)
    L "the same upgrade again, the file let go: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=1 already-identical=$($exp.identical + $before) kept=$($exp.kept) retired=0 refused=0"
    Check "it completes: exit 0, $done" (($r.code -eq 0) -and (Has $r.out $done))
    $lk = ReadLock $t
    $c = Dispositions $lk.rows
    Check "the lock: version $($U.release), previous_version $($U.from); upgraded-from $($U.from) = 1 ($($U.held)), already-identical = $($exp.identical + $before), kept = $($exp.kept)" (($lk.header.version -ceq $U.release) -and ($lk.header.previous_version -ceq $U.from) -and
        ([int]$c["upgraded-from $($U.from)"] -eq 1) -and (@($lk.rows | Where-Object { $_.disposition -ceq "upgraded-from $($U.from)" })[0].path -ceq $U.held) -and ([int]$c['already-identical'] -eq $exp.identical + $before) -and ([int]$c['kept'] -eq $exp.kept))
    Check "every file the release writes now holds its bytes, and no staging folder is left" (((@($writes | Where-Object { (FileSha (Join-Path $t ($_ -replace '/', '\'))) -ne (FileSha (Join-Path $src.root ($_ -replace '/', '\'))) }).Count) -eq 0) -and ((Staging $t) -eq 0))

    L '--- (B) framework.lock held open (read, shared for reading only): every file moves, the lock cannot be replaced'
    $t2 = Join-Path $Work 't2'
    Copy-Owned $Repo $t2 $owned
    Write-Lock1 -Target $t2 -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
    $lp = Join-Path $t2 'framework.lock'
    $lockB = ReadLock $t2
    $fh = [System.IO.File]::Open($lp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try { $r = Run $src.installer @('-Target', $t2) } finally { $fh.Dispose() }
    L "(B) the upgrade with the lock held: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    Check "(B) exit 1: framework.lock could not be put in place, every file ($($writes.Count)) is in place, and the target's lock is as it was; no done: line" (($r.code -eq 1) -and ((Count $r.out ('^install\.ps1: framework\.lock could not be put in place: .* Every file to write \(' + $writes.Count + '\) is in place, and the target''s lock is as it was before this run\.')) -eq 1) -and ((Count $r.out '^install\.ps1: done:') -eq 0))
    Check "(B) the old lock stands byte-identical; every file the release writes holds its bytes; no staging folder is left" (([System.IO.File]::Exists($lp)) -and ((ReadLock $t2).sha -eq $lockB.sha) -and ((@($writes | Where-Object { (FileSha (Join-Path $t2 ($_ -replace '/', '\'))) -ne (FileSha (Join-Path $src.root ($_ -replace '/', '\'))) }).Count) -eq 0) -and ((Staging $t2) -eq 0))
    $r = Run $src.installer @('-Target', $t2)
    L "(B) the same upgrade again, the lock let go: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'done:|planned:|REFUSED' } | ForEach-Object { L "  | $_" }
    Check "(B) it completes: exit 0, done: written=0 already-identical=$($exp.identical + $writes.Count) kept=$($exp.kept) retired=0 refused=0, the lock at $($U.release) naming $($U.from)" (($r.code -eq 0) -and
        (Has $r.out "install.ps1: done: written=0 already-identical=$($exp.identical + $writes.Count) kept=$($exp.kept) retired=0 refused=0") -and ((ReadLock $t2).header.version -ceq $U.release) -and ((ReadLock $t2).header.previous_version -ceq $U.from))
}
'u10' {
    # AN UPGRADE FROM A REAL 0.2.0 INSTALL TO THE REAL RELEASE. The tag is
    # cloned from -Repo and its own installer installs 0.2.0. The release is the ZIP release.ps1 builds in a clone of
    # -Repo at HEAD, expanded, its own install.ps1 run with -ReleaseZip, as INSTALL.md has a customer do -- at the
    # checkout's VERSION, which must read above the tag's (where it does not, there is no upgrade to measure and the
    # legs are not run). THE PREDICTION: the release clone's tools/provenance/upgrade-diff.py over the tag's manifest and
    # the release's prints the planned counts of an upgrade over a fresh 0.2.0 install; leg A prints them as done:.
    # THE LEGACY HALT CENSUS (S3b item 3): (A) the census file absent, as 0.2.0 leaves every project -- installed, the
    # framework's empty census, a host-config row -- and the exporter installed; (B) the release's exporter run first
    # against the project's own 0.2.0 evaluator -- the census written with that evaluator's members, then kept by the
    # upgrade byte for byte, so done: reads one written fewer and one kept more than the prediction.
    $C = $U.census; $Rt = $U.retire
    $census = $C.path; $exporter = $C.exporter
    function RunPy { param([string[]]$A)
        $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = @(& python -I @A 2>&1); $c = $LASTEXITCODE } finally { $ErrorActionPreference = $p }
        return [pscustomobject]@{ code = $c; out = @($o | ForEach-Object { "$_" }) }
    }
    function Above { param([string]$V, [string]$Than)
        # major.minor.patch compared part by part, as numbers, as install.ps1 compares them.
        $a = @($V.Split('.') | ForEach-Object { [long]$_ }); $b = @($Than.Split('.') | ForEach-Object { [long]$_ })
        for ($i = 0; $i -lt 3; $i++) { if ($a[$i] -ne $b[$i]) { return ($a[$i] -gt $b[$i]) } }
        return $false
    }
    Check "the installer-owned set carries $census (HOST-CONFIG) and $exporter (MOVE)" ($owned.ContainsKey($census) -and ($owned[$census].class -ceq 'HOST-CONFIG') -and $owned.ContainsKey($exporter) -and ($owned[$exporter].class -ceq 'MOVE'))
    $clone = New-Clone -Dest (Join-Path $Work 'v020') -Rev $C.tag
    $tagSet = OwnedSet (Join-Path $clone 'provenance\manifest.jsonl')
    $tagVersion = ([System.IO.File]::ReadAllText((Join-Path $clone 'VERSION'))).Trim()
    Check "the clone at $($C.tag) reads VERSION $($C.lock), and its installer-owned set ($($tagSet.Count)) holds neither $census nor $exporter" (($tagVersion -ceq $C.lock) -and -not $tagSet.ContainsKey($census) -and -not $tagSet.ContainsKey($exporter))
    $isAbove = ($Version -cmatch '^\d+\.\d+\.\d+$') -and (Above $Version $C.lock)
    Check "the checkout's VERSION, $Version, reads above the tag's, $($C.lock): the release upgrades a 0.2.0 project" $isAbove
    if (-not $isAbove) { L "VERSION $Version is not above $($C.lock): there is no upgrade to measure, and the legs are not run"; break }
    $rc = New-Clone -Dest (Join-Path $Work 'rel')
    $z = Build-Zip $rc
    $zsha = FileSha $z.zip
    $xr = Join-Path $Work 'x'
    Expand-Archive -LiteralPath $z.zip -DestinationPath $xr
    $relOwned = OwnedSet (Join-Path $xr 'provenance\manifest.jsonl')
    $relInstaller = Join-Path $xr 'install.ps1'
    L "the release: $($z.zip) sha256 $zsha, version $($z.version), expanded to $xr"
    $relGen = @($relOwned.Keys | Where-Object { -not $owned.ContainsKey($_) })
    Check "the release is $($z.version) = VERSION; its manifest's installer-owned set is the checkout's ($($owned.Count)) and the $($relGen.Count) generated members (ui/dist/**, THIRD-PARTY-NOTICES), and the expansion holds each of them" (($z.version -ceq $Version) -and
        (@($owned.Keys | Where-Object { -not $relOwned.ContainsKey($_) }).Count -eq 0) -and ($relGen.Count -gt 1) -and (@($relGen | Where-Object { -not ($_.StartsWith('ui/dist/') -or $_ -ceq 'THIRD-PARTY-NOTICES') }).Count -eq 0) -and
        (@($relOwned.Keys | Where-Object { -not (Test-Path -LiteralPath (Join-Path $xr ($_ -replace '/', '\')) -PathType Leaf) }).Count -eq 0))
    $shippedFold = FoldSha ([System.IO.File]::ReadAllBytes((Join-Path $xr ($census -replace '/', '\'))))
    # THE PREDICTION, by the release clone's own tool, over the manifest the tag carries and HEAD's in the release clone
    # (the tool holds each to its revision; the ZIP's manifest is HEAD's less the excluded rows and plus the generated
    # members, which no 0.2.0 project holds: each of those is an install, added to the prediction's written=).
    $predOut = Join-Path $Work 'prediction.md'
    $pr = RunPy @((Join-Path $rc 'tools\provenance\upgrade-diff.py'), (Join-Path $clone 'provenance\manifest.jsonl'), (Join-Path $rc 'provenance\manifest.jsonl'),
        '--old-version', $C.lock, '--new-version', $Version, '--repo', $rc, '--old-rev', $C.tag, '--new-rev', 'HEAD', '--out', $predOut)
    L "upgrade-diff.py $($C.lock) -> $($Version): exit=$($pr.code)"; $pr.out | ForEach-Object { L "  | $_" }
    $pt = ''; if (Test-Path -LiteralPath $predOut -PathType Leaf) { $pt = [System.IO.File]::ReadAllText($predOut) }
    $pm = [regex]::Match($pt, '(?m)^planned: written=(\d+) already-identical=(\d+) kept=(\d+)( not-written=(\d+))? retired=(\d+) refused=0$')
    $predRetired = Sorted @([regex]::Matches($pt, '(?m)^\| `([^`]+)` \| [^|]+ \| -- \| retired \|$') | ForEach-Object { $_.Groups[1].Value })
    Check "the prediction: exit 0, one planned: line, refused=0" (($pr.code -eq 0) -and $pm.Success -and ([regex]::Matches($pt, '(?m)^planned: ').Count -eq 1))
    $predA = ''; $predB = ''
    if ($pm.Success) {
        L "the prediction: $($pm.Value); retired $($predRetired.Count)"
        $nw = ''; if ($pm.Groups[4].Success) { $nw = $pm.Groups[4].Value }
        $predA = "install.ps1: done: written=$([int]$pm.Groups[1].Value + $relGen.Count) already-identical=$($pm.Groups[2].Value) kept=$($pm.Groups[3].Value)$nw retired=$($pm.Groups[6].Value) refused=0"
        $predB = "install.ps1: done: written=$([int]$pm.Groups[1].Value + $relGen.Count - 1) already-identical=$($pm.Groups[2].Value) kept=$([int]$pm.Groups[3].Value + 1)$nw retired=$($pm.Groups[6].Value) refused=0"
    }
    $done = @{}
    foreach ($leg in @(@{ name = 'A'; export = $false }, @{ name = 'B'; export = $true })) {
        $nm = $leg.name
        $t = Join-Path $Work "t$nm"
        $r0 = Run (Join-Path $clone 'install.ps1') @('-Target', $t)
        $lk0 = $null; if (Test-Path -LiteralPath (Join-Path $t 'framework.lock')) { $lk0 = ReadLock $t }
        Check "($nm) the tag's own installer installs $($C.lock): exit 0, the lock at $($C.lock), one row per installer-owned file of the tag ($($tagSet.Count))" (($r0.code -eq 0) -and $lk0 -and ($lk0.header.version -ceq $C.lock) -and (@($lk0.rows).Count -eq $tagSet.Count))
        $cp = Join-Path $t ($census -replace '/', '\')
        Check "($nm) the 0.2.0 project holds no $census" (-not (Test-Path -LiteralPath $cp))
        if ($leg.export) {
            $x = Run (Join-Path $xr ($exporter -replace '/', '\')) @('-From', (Join-Path $t 'tools\lam\mission-goal-check.ps1'))
            L "($nm) the exporter, from the expanded release, against the project's own 0.2.0 evaluator: exit=$($x.code)"; $x.out | ForEach-Object { L "  | $_" }
            $members = @(); if (Test-Path -LiteralPath $cp) { $members = @([System.IO.File]::ReadAllLines($cp) | Where-Object { $_ -and -not $_.StartsWith('#') }) }
            $canon = (@($members) | ForEach-Object { $_ + "`n" }) -join ''
            Check "($nm) exit 0; $census written beside the project's evaluator: $($C.count) member lines, census_sha256 $($C.census_sha256)" (($x.code -eq 0) -and ($members.Count -eq $C.count) -and
                ((Sha ([System.Text.Encoding]::ASCII.GetBytes($canon))) -eq $C.census_sha256))
        }
        $before = $null; if (Test-Path -LiteralPath $cp) { $before = [System.IO.File]::ReadAllBytes($cp) }
        $ap = Join-Path $t ($Rt.path -replace '/', '\')
        $apBefore = ''; if (Test-Path -LiteralPath $ap -PathType Leaf) { $apBefore = FileSha $ap }
        Check "($nm) the 0.2.0 project holds $($Rt.path) as 0.2.0 installed it (sha256 $($Rt.sha256.Substring(0, 8)), $($Rt.bytes) bytes), its lock row installed" (
            ($apBefore -eq $Rt.sha256) -and ((Get-Item -LiteralPath $ap).Length -eq $Rt.bytes) -and (@($lk0.rows | Where-Object { ($_.path -ceq $Rt.path) -and ($_.disposition -ceq 'installed') }).Count -eq 1))
        $inRelease = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($k in $relOwned.Keys) { [void]$inRelease.Add($k) }
        $wantRetired = Sorted @($lk0.rows | ForEach-Object { [string]$_.path } | Where-Object { -not $inRelease.Contains($_) })
        $retBefore = @{}; foreach ($p in $wantRetired) { $fp = Join-Path $t ($p -replace '/', '\'); if (Test-Path -LiteralPath $fp -PathType Leaf) { $retBefore[$p] = FileSha $fp } }
        $ga = Join-Path $t '.gitattributes'
        Check "($nm) the 0.2.0 project holds no root .gitattributes (0.2.0 installed none)" (-not (Test-Path -LiteralPath $ga))
        $r = Run $relInstaller @('-Target', $t, '-ReleaseZip', $z.zip)
        L "($nm) upgrade $($C.lock) -> $($z.version): exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|retire|not-written|done:|planned:|legacy-halt-census|export-legacy|^install\.ps1: (source|upgrade|framework\.lock written|upgraded)' } | ForEach-Object { L "  | $_" }
        $dl = @($r.out | Where-Object { $_ -match '^install\.ps1: done: written=\d+ already-identical=\d+ kept=\d+( not-written=\d+)? retired=\d+ refused=0$' })
        Check "($nm) exit 0, one done: line, refused=0" (($r.code -eq 0) -and ($dl.Count -eq 1))
        if ($dl.Count -eq 1) { $null = $dl[0] -match 'written=(\d+) already-identical=\d+ kept=(\d+)'; $done[$nm] = @([int]$Matches[1], [int]$Matches[2]) }
        if (-not $leg.export) {
            Check "($nm) THE PREDICTION HOLDS: done: is the prediction's planned: line -- '$predA'" ($predA -and (Has $r.out $predA))
        } else {
            Check "($nm) THE PREDICTION, THE CENSUS KEPT: done: is the prediction's planned: line with one written fewer and one kept more -- '$predB'" ($predB -and (Has $r.out $predB))
        }
        $lk = $null; if (Test-Path -LiteralPath (Join-Path $t 'framework.lock')) { $lk = ReadLock $t }
        $crow = @(); $xrow = @(); if ($lk) { $crow = @($lk.rows | Where-Object { $_.path -ceq $census }); $xrow = @($lk.rows | Where-Object { $_.path -ceq $exporter }) }
        Check "($nm) the lock at $($z.version), previous_version $($C.lock), zip_sha256 the release ZIP's; $exporter installed, kind move" ($lk -and ($lk.header.version -ceq $z.version) -and ($lk.header.previous_version -ceq $C.lock) -and ($lk.header.zip_sha256 -eq $zsha) -and ($xrow.Count -eq 1) -and ($xrow[0].disposition -ceq 'installed') -and ($xrow[0].kind -ceq 'move'))
        $grow = @(); if ($lk) { $grow = @($lk.rows | Where-Object { $_.path -ceq '.gitattributes' }) }
        Check "($nm) the root .gitattributes not written: its not-written line once, not-written=1 in done:, the file absent, its lock row not-written with sha256 and eol null, kind template" (
            ((Count $r.out '^install\.ps1:   not-written\s+\.gitattributes  -- not written: an upgrade adds no root \.gitattributes where the project has none') -eq 1) -and
            ($dl.Count -eq 1) -and ($dl[0] -match ' not-written=1 ') -and (-not (Test-Path -LiteralPath $ga)) -and ($grow.Count -eq 1) -and ($grow[0].disposition -ceq 'not-written') -and
            ($null -eq $grow[0].sha256) -and ($null -eq $grow[0].eol) -and ($grow[0].kind -ceq 'template'))
        if (-not $leg.export) {
            Check "($nm) $census installed: the framework's empty census byte for byte; its row kind host-config, disposition installed, sha256 = upstream_sha256 = sha256(fold(the release's))" (
                (Test-Path -LiteralPath $cp -PathType Leaf) -and ((FileSha $cp) -eq (FileSha (Join-Path $xr ($census -replace '/', '\')))) -and ($crow.Count -eq 1) -and
                ($crow[0].kind -ceq 'host-config') -and ($crow[0].disposition -ceq 'installed') -and ($crow[0].sha256 -eq $shippedFold) -and ($crow[0].upstream_sha256 -eq $shippedFold))
        } else {
            Check "($nm) $census kept byte for byte, the exporter's; its row kind host-config, disposition kept, sha256 = sha256(fold(the export)), upstream_sha256 = sha256(fold(the release's))" (
                ($null -ne $before) -and (Test-Path -LiteralPath $cp -PathType Leaf) -and ((FileSha $cp) -eq (Sha $before)) -and ($crow.Count -eq 1) -and ($crow[0].kind -ceq 'host-config') -and
                ($crow[0].disposition -ceq 'kept') -and ($crow[0].sha256 -eq (FoldSha $before)) -and ($crow[0].upstream_sha256 -eq $shippedFold))
        }
        # THE RETIRED ACCEPTANCE RECORD (item 4): in the 0.2.0 lock, not in this release's set -- retired: left in place
        # byte for byte, dropped from the lock, and nothing -Verify says names it. The retired set is computed here.
        $retireLine = '^install\.ps1:   retire\s+' + [regex]::Escape($Rt.path) + '  -- in framework\.lock, not in this release: left in place, dropped from the lock$'
        $retiredN = -1; if ($dl.Count -eq 1 -and $dl[0] -match ' retired=(\d+) ') { $retiredN = [int]$Matches[1] }
        Check "($nm) $($Rt.path) is among the paths the 0.2.0 lock lists and this release does not ($($wantRetired.Count): the computed retired set), done: says retired=$($wantRetired.Count), and its retire line is printed once" (
            ($wantRetired -ccontains $Rt.path) -and ($retiredN -eq $wantRetired.Count) -and ((Count $r.out $retireLine) -eq 1) -and
            ((Count $r.out '^install\.ps1:   retire\s') -eq $wantRetired.Count))
        Check "($nm) after the upgrade $($Rt.path) stands byte for byte as 0.2.0 installed it, and framework.lock no longer lists it" (
            (Test-Path -LiteralPath $ap -PathType Leaf) -and ((FileSha $ap) -eq $apBefore) -and $lk -and (@($lk.rows | Where-Object { $_.path -ceq $Rt.path }).Count -eq 0))
        $retGone = @($wantRetired | Where-Object { -not $retBefore.ContainsKey($_) -or -not (Test-Path -LiteralPath (Join-Path $t ($_ -replace '/', '\')) -PathType Leaf) -or ((FileSha (Join-Path $t ($_ -replace '/', '\'))) -ne $retBefore[$_]) })
        $retListed = @($wantRetired | Where-Object { $p = $_; $lk -and @($lk.rows | Where-Object { $_.path -ceq $p }).Count -gt 0 })
        Check "($nm) the retired set is the prediction's ($($predRetired.Count) paths), each named by one retire line, each standing after the upgrade byte for byte as 0.2.0 installed it, none in the lock" (
            ($predRetired.Count -gt 0) -and (Same $wantRetired $predRetired) -and ($retGone.Count -eq 0) -and ($retListed.Count -eq 0) -and
            (@($wantRetired | Where-Object { (Count $r.out ('^install\.ps1:   retire\s+' + [regex]::Escape($_) + '  -- ')) -ne 1 }).Count -eq 0))
        $v = Run $relInstaller @('-Target', $t, '-Verify')
        L "($nm) -Verify: exit=$($v.code) -- $(@($v.out | Where-Object { $_ -match 'verify: \d+ file' }) -join ' | ')"
        Check "($nm) -Verify after the upgrade: exit 0, 0 difference(s)" (($v.code -eq 0) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))
        Check "($nm) -Verify reads the not-written row: 'verify: $($relOwned.Count) file(s) listed, 1 not written, 0 difference(s); eol ...'" ((Count $v.out ('^install\.ps1: verify: ' + $relOwned.Count + ' file\(s\) listed, 1 not written, 0 difference\(s\); eol lf=\d+ crlf=\d+ mixed=\d+ binary=\d+\.$')) -eq 1)
        Check "($nm) -Verify says nothing of $($Rt.path)" ((Count $v.out ([regex]::Escape($Rt.path))) -eq 0)
    }
    Check '(B) against (A): one file written fewer and one kept more -- the census, kept' ($done.ContainsKey('A') -and $done.ContainsKey('B') -and ($done['B'][0] -eq $done['A'][0] - 1) -and ($done['B'][1] -eq $done['A'][1] + 1))
}
'v' {
    $kc = $U.kind_change
    $p1 = $kc.unedited; $p2 = $kc.edited; $pair = @($p1, $p2)
    Check "$p1 and $p2 are class HOST-CONFIG, $($kc.reverse) class MOVE, in the checkout" (($owned[$p1].class -eq 'HOST-CONFIG') -and ($owned[$p2].class -eq 'HOST-CONFIG') -and ($owned[$kc.reverse].class -eq 'MOVE'))
    $s2 = New-Source -Dir (Join-Path $Work 'src2') -Version $U.release -From $Repo -Set $owned -Changes $U.changed -New $U.new -Installer $installer
    function Reclassed { param($Set, [string[]]$Paths, [string]$Class)
        # The set with the named paths given another class: New-Source writes each manifest row's class from it.
        $s = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([System.StringComparer]::Ordinal)
        foreach ($k in $Set.Keys) { if (@($Paths) -ccontains $k) { $s[$k] = [pscustomobject]@{ class = $Class } } else { $s[$k] = $Set[$k] } }
        return $s
    }
    function New-Upgraded { param([string]$Name, [string]$EditBefore)
        # A target the installer itself upgraded from 0.1.1 to the first synthetic release: a format-2 lock whose
        # template and host-config rows say kept, as an upgrade writes them. -EditBefore names a file the host edits
        # before that upgrade, so its kept row records the host's own bytes and not the release's.
        $t = Join-Path $Work "t$Name"
        Copy-Owned $Repo $t $owned
        Write-Lock1 -Target $t -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
        if ($EditBefore) { $f = Join-Path $t ($EditBefore -replace '/', '\'); [System.IO.File]::WriteAllBytes($f, [byte[]]([System.IO.File]::ReadAllBytes($f) + (Bytes $kc.host_append))) }
        $r = Run $s2.installer @('-Target', $t)
        Check "($Name) the upgrade to $($U.release) first: exit 0" ($r.code -eq 0)
        if ($r.code -ne 0) { throw "($Name) the upgrade to $($U.release) did not succeed, and the rest of (v) stands on it" }
        return $t
    }
    function Row { param([string]$T, [string]$P) return @((ReadLock $T).rows | Where-Object { $_.path -ceq $P })[0] }
    function Says { param($Out, [string]$Disposition, [string]$P, [string]$Why) return ((Count $Out ('^install\.ps1:   ' + $Disposition + '\s+' + [regex]::Escape($P) + $(if ($Why) { '\s+-- ' + $Why } else { '$' }))) -eq 1) }
    function Changing { param([string[]]$Paths) return @($Paths | ForEach-Object { [pscustomobject]@{ path = $_; append = $kc.append } }) }
    function Tally { param($Src) return [pscustomobject]@{ move = @($Src.owned.Values | Where-Object { $_.class -eq 'MOVE' }).Count; kept = @($Src.owned.Values | Where-Object { $_.class -ne 'MOVE' }).Count } }
    # One release for (A), (B) and (C): it classes the pair MOVE and changes both.
    $sA = New-Source -Dir (Join-Path $Work 'srcA') -Version $kc.release -From $s2.root -Set (Reclassed $s2.owned $pair 'MOVE') -Changes (Changing $pair) -Installer $installer
    $nA = Tally $sA

    L "--- (A) $($kc.release) classes $p1 and $p2 MOVE and changes both; the target holds each as $($U.release) shipped it"
    $tA = New-Upgraded 'A'
    $rows0 = @($pair | ForEach-Object { Row $tA $_ })
    Check "(A) the old lock, as the upgrade to $($U.release) wrote it: lock_format 2; each of the two kind host-config, disposition kept, sha256 = upstream_sha256" (((ReadLock $tA).header.lock_format -eq 2) -and
        (@($rows0 | Where-Object { ($_.kind -ceq 'host-config') -and ($_.disposition -ceq 'kept') -and ($_.sha256 -eq $_.upstream_sha256) }).Count -eq 2))
    $r = Run $sA.installer @('-Target', $tA)
    L "(A) upgrade $($U.release) -> $($kc.release): exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=2 already-identical=$($nA.move - 2) kept=$($nA.kept) retired=0 refused=0"
    Check "(A) exit 0, $done; each of the two listed upgrade" (($r.code -eq 0) -and (Has $r.out $done) -and (Says $r.out 'upgrade' $p1) -and (Says $r.out 'upgrade' $p2))
    $rowsA = @($pair | ForEach-Object { Row $tA $_ })
    Check "(A) the new lock at $($kc.release): each of the two kind move, disposition upgraded-from $($U.release), columns path,sha256,disposition,eol,kind (no upstream_sha256), sha256 = sha256(fold(the file)) computed here" (
        ((ReadLock $tA).header.version -ceq $kc.release) -and
        (@($rowsA | Where-Object { ($_.kind -ceq 'move') -and ($_.disposition -ceq "upgraded-from $($U.release)") -and ((Names $_) -ceq 'path,sha256,disposition,eol,kind') -and ($_.sha256 -eq (FoldSha ([System.IO.File]::ReadAllBytes((Join-Path $tA ($_.path -replace '/', '\')))))) }).Count -eq 2))
    Check "(A) each of the two holds $($kc.release)'s bytes, raw; no staging folder is left" ((@($pair | Where-Object { (FileSha (Join-Path $tA ($_ -replace '/', '\'))) -ne (FileSha (Join-Path $sA.root ($_ -replace '/', '\'))) }).Count -eq 0) -and ((Staging $tA) -eq 0))
    $v = Run $sA.installer @('-Target', $tA, '-Verify')
    Check '(A) -Verify after: exit 0, 0 difference(s)' (($v.code -eq 0) -and ((Count $v.out ' 0 difference\(s\); eol ') -eq 1))

    L "--- (B) the same release; the host edited $p2 after the upgrade to $($U.release), and $p1 is as shipped"
    $tB = New-Upgraded 'B'
    $eb = Join-Path $tB ($p2 -replace '/', '\')
    $hostB = [byte[]]([System.IO.File]::ReadAllBytes($eb) + (Bytes $kc.host_append)); [System.IO.File]::WriteAllBytes($eb, $hostB)
    $rowB = Row $tB $p2
    Check "(B) $p2's old row: kept, sha256 = upstream_sha256 (as shipped when the lock was written), and the file now differs from it" (($rowB.disposition -ceq 'kept') -and ($rowB.sha256 -eq $rowB.upstream_sha256) -and ((FoldSha $hostB) -ne $rowB.sha256))
    $before = TreeHashes $tB
    $r = Run $sA.installer @('-Target', $tB)
    L "(B) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|upgrade |planned:|done:' } | ForEach-Object { L "  | $_" }
    $planned = "install.ps1: planned: written=1 already-identical=$($nA.move - 2) kept=$($nA.kept) retired=0 refused=1"
    Check "(B) exit 2; $p2 REFUSED edited-since-install, the only refusal; $p1 would upgrade; $planned; the whole upgrade refused; no other written=" (($r.code -eq 2) -and
        (Says $r.out 'REFUSED' $p2 'edited-since-install: framework\.lock recorded ') -and ((Count $r.out '^install\.ps1:   REFUSED ') -eq 1) -and (Says $r.out 'upgrade' $p1) -and (Has $r.out $planned) -and
        ((Count $r.out 'is refused as a whole\. Nothing was written -- no file and no lock\.$') -eq 1) -and ((Stray $r.out).Count -eq 0))
    Check "(B) nothing was written: the target hash-identical, framework.lock included; the host's edit stands" (((DiffTrees $before (TreeHashes $tB)).Count -eq 0) -and ((FileSha $eb) -eq (Sha $hostB)))

    L "--- (C) the same release; the host edited $p2 BEFORE the upgrade to $($U.release), so its kept row records the host's own bytes"
    $tC = New-Upgraded 'C' -EditBefore $p2
    $rowC = Row $tC $p2
    Check "(C) $p2's old row: kept, sha256 = the host's file, other than upstream_sha256" (($rowC.disposition -ceq 'kept') -and ($rowC.sha256 -ne $rowC.upstream_sha256) -and ($rowC.sha256 -eq (FoldSha ([System.IO.File]::ReadAllBytes((Join-Path $tC ($p2 -replace '/', '\')))))))
    $before = TreeHashes $tC
    $r = Run $sA.installer @('-Target', $tC)
    L "(C) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -match 'REFUSED|upgrade |planned:|done:' } | ForEach-Object { L "  | $_" }
    Check "(C) exit 2; $p2 REFUSED host-instance (the lock records it as the host's own, kept), the only refusal; $p1 would upgrade; $planned; nothing written" (($r.code -eq 2) -and
        (Says $r.out 'REFUSED' $p2 'host-instance: framework\.lock records it as the host''s own \(kept\)') -and ((Count $r.out '^install\.ps1:   REFUSED ') -eq 1) -and (Says $r.out 'upgrade' $p1) -and
        (Has $r.out $planned) -and ((Stray $r.out).Count -eq 0) -and ((DiffTrees $before (TreeHashes $tC)).Count -eq 0))

    L "--- (D) another $($kc.release): $p1 and $p2 MOVE with their bytes unchanged, and $($kc.reverse), MOVE until now, HOST-CONFIG and changed"
    $tD = New-Upgraded 'D'
    $rp = Join-Path $tD ($kc.reverse -replace '/', '\')
    $revBefore = FileSha $rp
    $rowR0 = Row $tD $kc.reverse
    $sD = New-Source -Dir (Join-Path $Work 'srcD') -Version $kc.release -From $s2.root -Set (Reclassed (Reclassed $s2.owned $pair 'MOVE') @($kc.reverse) 'HOST-CONFIG') -Changes (Changing @($kc.reverse)) -Installer $installer
    $nD = Tally $sD
    $r = Run $sD.installer @('-Target', $tD)
    L "(D) upgrade: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep) ' } | ForEach-Object { L "  | $_" }
    $done = "install.ps1: done: written=0 already-identical=$($nD.move) kept=$($nD.kept) retired=0 refused=0"
    Check "(D) exit 0, $done; the pair already-identical; $($kc.reverse) keep" (($r.code -eq 0) -and (Has $r.out $done) -and (Says $r.out 'already-identical' $p1) -and (Says $r.out 'already-identical' $p2) -and (Says $r.out 'keep' $kc.reverse))
    $rowsD = @($pair | ForEach-Object { Row $tD $_ })
    Check "(D) the pair's new rows: kind move, disposition already-identical, columns path,sha256,disposition,eol,kind" ((@($rowsD | Where-Object { ($_.kind -ceq 'move') -and ($_.disposition -ceq 'already-identical') -and ((Names $_) -ceq 'path,sha256,disposition,eol,kind') }).Count -eq 2))
    $rd = Row $tD $kc.reverse
    Check "(D) $($kc.reverse): its old row kind move; its new row kind host-config, kept, sha256 = the file's, upstream_sha256 = $($kc.release)'s, the two differ; the file not rewritten" (
        ($rowR0.kind -ceq 'move') -and ($rd.kind -ceq 'host-config') -and ($rd.disposition -ceq 'kept') -and ($rd.sha256 -eq (FoldSha ([System.IO.File]::ReadAllBytes($rp)))) -and
        ($rd.upstream_sha256 -eq $sD.fold[$kc.reverse]) -and ($rd.sha256 -ne $rd.upstream_sha256) -and ((FileSha $rp) -eq $revBefore))
    Check 'no staging folder is left in any target' ((@($tA, $tB, $tC, $tD) | Where-Object { (Staging $_) -ne 0 }).Count -eq 0)
}
'h4' {
    # F-H4 (RELEASE-4 S2; row 495 (2)): THE SESSION-ID CLASS. tools/lam/scan-session-ids.ps1 over the tagged clone's
    # tests/** and tools/lam/fixtures/** with an id file OUTSIDE the tree: a synthetic id file the case writes (two made-up
    # GUIDs) reads 0 over the clone; the same id planted into a scratch copy of one fixture reads 1, by path and line;
    # an id file inside -Root is refused. The host's own record is never in the repository: the seat's reading of it
    # (row-faces.jsonl) is the S2 report's, not this case's.
    $tool = Join-Path $Tagged.root 'tools\lam\scan-session-ids.ps1'
    $idf = Join-Path $Work 'ids.txt'
    # assembled at run time: this file lies under tests/**, which the tool reads, so no whole GUID stands in its text
    $fakeA = '0f0e0d0c' + '-0b0a-4909-8807-060504030201'; $fakeB = '11112222' + '-3333-4444-8555-666677778888'
    [System.IO.File]::WriteAllText($idf, "synthetic host record`n$fakeA`n$fakeB`n")
    $r = Run $tool @('-Root', $Tagged.root, '-IdFile', $idf)
    L "(h4) clean: exit $($r.code); $((@($r.out) | Select-Object -Last 1) -join '')"
    Check '(h4) the tagged clone''s tests/** (the default -Under, which holds tests/lam/fixtures/**) holds none of the id file''s session ids: exit 0, 0 hit(s)' (($r.code -eq 0) -and ((Count $r.out '^scan-session-ids: 0 hit\(s\) of 2 host id\(s\)') -eq 1))
    # F-X4 (RELEASE-4 S3; S2 validator X-4): NO VACUOUS PASS. The clean reading read files (its count > 0); a -Under folder
    # that does not stand is REFUSED by name (exit 2), never skipped; and -Under given through -File as one comma-joined
    # string (tests,tests/lam/fixtures) is read as its folders, files counted.
    $fc = [regex]::Match((@($r.out) -join "`n"), '\((\d+) file\(s\)\)')
    $nf = if ($fc.Success) { [int]$fc.Groups[1].Value } else { 0 }
    Check "(h4) the clean reading read the tagged clone's files: $nf file(s) (> 0)" ($nf -gt 0)
    $rm = Run $tool @('-Root', $Tagged.root, '-IdFile', $idf, '-Under', 'tests,no-such-folder')
    L "(h4) -Under naming a folder that does not stand: exit $($rm.code); $((@($rm.out) | Select-Object -Last 1) -join '')"
    Check '(h4) a -Under folder that does not stand is refused by name: exit 2, the line naming no-such-folder' (($rm.code -eq 2) -and ((Count $rm.out '^scan-session-ids: -Under folder does not stand: no-such-folder ') -eq 1))
    $rj = Run $tool @('-Root', $Tagged.root, '-IdFile', $idf, '-Under', 'tests,tests/lam/fixtures')
    $fj = [regex]::Match((@($rj.out) -join "`n"), 'under tests, tests/lam/fixtures \((\d+) file\(s\)\)')
    L "(h4) -Under 'tests,tests/lam/fixtures' as one -File argument: exit $($rj.code); $((@($rj.out) | Select-Object -Last 1) -join '')"
    Check '(h4) -Under given through -File as one comma-joined string reads both folders: exit 0, files > 0' (($rj.code -eq 0) -and $fj.Success -and ([int]$fj.Groups[1].Value -gt 0))
    $cp = Join-Path $Work 'copy'; $null = New-Item -ItemType Directory -Force -Path (Join-Path $cp 'tests\lam\fixtures\ui')
    $fx = Join-Path $cp 'tests\lam\fixtures\ui\p.jsonl'
    [System.IO.File]::WriteAllText($fx, ([System.IO.File]::ReadAllText((Join-Path $Tagged.root 'tests\lam\fixtures\ui\p.jsonl')) + '{"session_id":"' + $fakeA + '"}' + "`n"))
    $r2 = Run $tool @('-Root', $cp, '-IdFile', $idf)
    Check '(h4) one host id planted into a scratch copy of a fixture reads 1 hit, by path and line, exit 1' (($r2.code -eq 1) -and ((Count $r2.out '^scan-session-ids: SESSION-ID tests/lam/fixtures/ui/p\.jsonl:\d+ 0f0e0d0c\.\.\.$') -eq 1))
    $inside = Join-Path $cp 'ids.txt'; [System.IO.File]::WriteAllText($inside, $fakeA)
    $r3 = Run $tool @('-Root', $cp, '-IdFile', $inside)
    Check '(h4) an id file inside -Root is refused, exit 2' ($r3.code -eq 2)
}
'h5' {
    # F-H5 (RELEASE-4 S2; row 495 (7)): THE KEPT-FILE NOTICE. The installer never edits a kept file (ruling: a protected
    # customer file is the operator's); it says, per kept file that differs (fold-crlf-text, the lock's basis) from this
    # release's version, that it kept it and where the release's version is, and for .claude/settings.json names each
    # registration the release's version carries that the project's lacks, with the block read from the release's file.
    # The expected block is judged here independently: a substring of the release file (LF-folded), and, wrapped in {},
    # JSON whose member equals the release file's parsed member.
    $setRel = '.claude/settings.json'
    $relSet = Join-Path $Tagged.root '.claude\settings.json'
    $relText = ([System.IO.File]::ReadAllText($relSet)) -replace "`r`n", "`n"
    $relObj = $relText | ConvertFrom-Json
    function Own-Settings { param([string]$Dest)
        # the project's own copy: the release's file less its SubagentStop registration (a 1.1.0-era project's shape)
        $o = [System.IO.File]::ReadAllText($relSet) | ConvertFrom-Json
        $null = $o.hooks.PSObject.Properties.Remove('SubagentStop')
        $null = [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Dest))
        [System.IO.File]::WriteAllText($Dest, ($o | ConvertTo-Json -Depth 20), $NoBom)
    }
    function Judge-Notices { param($Out, [string]$Label, [string[]]$Expect)
        $heads = @($Out | Where-Object { $_ -match '^install\.ps1: NOTICE kept (\S+) -- kept: ' })
        $named = Sorted @($heads | ForEach-Object { if ($_ -match '^install\.ps1: NOTICE kept (\S+) -- kept: ') { $Matches[1] } })
        $atOk = $true
        foreach ($h in $heads) {
            if ($h -notmatch '^install\.ps1: NOTICE kept (\S+) -- kept: .*which is at (.+)$') { $atOk = $false; continue }
            $p = $Matches[1]; $at = $Matches[2]
            if (-not (Test-Path -LiteralPath $at -PathType Leaf) -or ((FileSha $at) -ne $owned[$p].sha256)) { $atOk = $false }
        }
        L "($Label) notice lines: $($heads.Count); files named: $($named -join ', '); expected: $((Sorted $Expect) -join ', ')"
        Check "($Label) one NOTICE kept line per kept file that differs from the release's version, and none for another: $((Sorted $Expect) -join ', ')" (Same $named (Sorted $Expect))
        Check "($Label) each notice names where the release's version is: an existing file holding the manifest's bytes" ($atOk -and $heads.Count -gt 0)
        $reg = @($Out | Where-Object { $_ -match '^install\.ps1: NOTICE kept \.claude/settings\.json -- this release registers (\S+) ' })
        $block = @($Out | Where-Object { $_.StartsWith('install.ps1: NOTICE   | ') } | ForEach-Object { $_.Substring('install.ps1: NOTICE   | '.Length) }) -join "`n"
        $blockOk = $false
        if ($block) {
            try { $bo = ('{' + $block + '}') | ConvertFrom-Json; $blockOk = ((($bo.SubagentStop | ConvertTo-Json -Depth 20 -Compress)) -ceq (($relObj.hooks.SubagentStop | ConvertTo-Json -Depth 20 -Compress))) -and $relText.Contains($block) } catch { $blockOk = $false }
        }
        L "($Label) registration lines: $($reg.Count) ($(@($reg | ForEach-Object { if ($_ -match 'registers (\S+) ') { $Matches[1] } }) -join ', ')); block lines: $(@($Out | Where-Object { $_.StartsWith('install.ps1: NOTICE   | ') }).Count); block the release file's own and its SubagentStop: $blockOk"
        Check "($Label) for $setRel the notice names SubagentStop, the one registration the project's copy lacks, and prints the release file's own SubagentStop block" (($reg.Count -eq 1) -and ($reg[0] -match 'registers SubagentStop ') -and $blockOk)
    }
    # (h5a) A FRESH INSTALL into a folder holding the project's own .claude/settings.json: kept, named, the block printed.
    $t = Join-Path $Work 'fresh'
    Own-Settings (Join-Path $t '.claude\settings.json')
    $ownSha = FileSha (Join-Path $t '.claude\settings.json')
    $w = Run $installer @('-Target', $t, '-WhatIf')
    L "(h5a) -WhatIf exit=$($w.code)"; $w.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    Check '(h5a) -WhatIf: exit 0, nothing written (the project''s file as it was, no framework.lock)' (($w.code -eq 0) -and ((FileSha (Join-Path $t '.claude\settings.json')) -eq $ownSha) -and -not (Test-Path -LiteralPath (Join-Path $t 'framework.lock')))
    Judge-Notices $w.out 'h5a -WhatIf' @($setRel)
    $r = Run $installer @('-Target', $t)
    L "(h5a) install exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   install ' } | ForEach-Object { L "  | $_" }
    Check "(h5a) install: exit 0, $setRel kept, and the installer did not edit it (byte for byte the project's)" (($r.code -eq 0) -and ((Count $r.out ('^install\.ps1:   keep\s+' + [regex]::Escape($setRel) + '$')) -eq 1) -and ((FileSha (Join-Path $t '.claude\settings.json')) -eq $ownSha))
    Judge-Notices $r.out 'h5a install' @($setRel)
    # (h5b) AN UPGRADE over a 0.1.1-locked project whose own .claude/settings.json lacks SubagentStop and whose
    # model-routing.yaml carries a line of its own; every other kept file is the release's (so it is named by none).
    $u = Join-Path $Work 'up'
    Copy-Owned $Repo $u $owned
    Own-Settings (Join-Path $u '.claude\settings.json')
    $mr = Join-Path $u 'model-routing.yaml'
    [System.IO.File]::WriteAllBytes($mr, [byte[]]([System.IO.File]::ReadAllBytes($mr) + [System.Text.Encoding]::ASCII.GetBytes("# the project's own line`n")))
    Write-Lock1 -Target $u -Header (Header 'lock-header-0.1.1.json') -Paths @($owned.Keys)
    $keptPaths = @($owned.Keys | Where-Object { $owned[$_].class -ne 'MOVE' })
    $keptBefore = @{}; foreach ($p in $keptPaths) { $keptBefore[$p] = FileSha (Join-Path $u ($p -replace '/', '\')) }
    $w = Run $installer @('-Target', $u, '-WhatIf')
    L "(h5b) upgrade -WhatIf exit=$($w.code)"; $w.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep|upgrade) ' } | ForEach-Object { L "  | $_" }
    Check '(h5b) upgrade -WhatIf: exit 0' ($w.code -eq 0)
    Judge-Notices $w.out 'h5b upgrade -WhatIf' @($setRel, 'model-routing.yaml')
    $r = Run $installer @('-Target', $u)
    L "(h5b) upgrade exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^install\.ps1:   (already-identical|keep|upgrade) ' } | ForEach-Object { L "  | $_" }
    Check '(h5b) upgrade: exit 0' ($r.code -eq 0)
    Judge-Notices $r.out 'h5b upgrade' @($setRel, 'model-routing.yaml')
    $edited = @($keptPaths | Where-Object { (FileSha (Join-Path $u ($_ -replace '/', '\'))) -ne $keptBefore[$_] })
    Check "(h5b) the installer edited none of the $($keptPaths.Count) kept files (each byte for byte as before the upgrade)" ($edited.Count -eq 0)
}
'h6' {
    # F-H6 (RELEASE-4 S2; row 495 (11)): THE CLEAN-ENVIRONMENT INSTALL PROOF IS A SCRIPT, tests/install/clean-install-proof.ps1,
    # -Repo's own. The ZIP release.ps1 builds in a clone at HEAD; the script run over it -Through build (every step but the
    # acceptance run, which S4 makes with both arms), in a scratch root here; then its refusals.
    $proof = Join-Path $Repo 'tests\install\clean-install-proof.ps1'
    Check 'tests/install/clean-install-proof.ps1 stands in -Repo' (Test-Path -LiteralPath $proof -PathType Leaf)
    if (-not (Test-Path -LiteralPath $proof -PathType Leaf)) { throw 'no proof script, and the rest of (h6) stands on it' }
    $clone = New-Clone (Join-Path $Work 'clone')
    $z = Build-Zip $clone
    $sr = Join-Path $Work 'p'
    $envBefore = (@(Get-ChildItem Env: | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Value }) -join "`n")
    $r = Run $proof @('-Zip', $z.zip, '-ScratchRoot', $sr, '-RunKey', 'h6-member', '-Through', 'build')
    L "(h6) proof -Through build: exit=$($r.code)"; $r.out | Where-Object { $_ -notmatch '^  \| install\.ps1:   ' } | ForEach-Object { L "  | $_" }
    $stepLines = @($r.out | Where-Object { $_ -match '^PROOF (release|project|install|init|smoke|register|build) (PASS|FAIL) -- ' })
    $passes = @($stepLines | Where-Object { $_ -match ' PASS -- ' })
    Check '(h6) exit 0; PROOF release, project, install, init, smoke, register and build each PASS; PROOF ENV PASS; PROOF RESULT 8 step(s), 0 failed' (
        ($r.code -eq 0) -and ($stepLines.Count -eq 7) -and ($passes.Count -eq 7) -and ((Count $r.out '^PROOF ENV PASS -- ') -eq 1) -and (Has $r.out 'PROOF RESULT: 8 step(s), 0 failed (through build)'))
    $vhRows = @(Get-ChildItem -LiteralPath (Join-Path $sr 'vanguard-home') -Recurse -File -ErrorAction SilentlyContinue)
    $outside = @(Get-ChildItem -LiteralPath $Work -Force | Where-Object { @('clone', 'p', 'p3', 'tagged-clone') -notcontains $_.Name } | ForEach-Object { $_.Name })
    Check "(h6) the registration is under the scratch root's VANGUARD_HOME ($($vhRows.Count) file(s)); the project's origin is the scratch root's bare origin; nothing beside the scratch root in this case's folder ($($outside -join ', '))" (
        ($vhRows.Count -gt 0) -and (((RunGit (Join-Path $sr 'project') @('remote', 'get-url', 'origin')).out -join '').Trim() -eq (Join-Path $sr 'origin.git')) -and ($outside.Count -eq 0))
    Check '(h6) this process''s environment unchanged by the run' (((@(Get-ChildItem Env: | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Value }) -join "`n")) -ceq $envBefore)
    $r2 = Run $proof @('-Zip', $z.zip, '-ScratchRoot', $sr, '-RunKey', 'h6-member', '-Through', 'install')
    Check '(h6) a scratch root that is not empty is REFUSED, exit 2' (($r2.code -eq 2) -and ((Count $r2.out '^PROOF REFUSED: -ScratchRoot .* is not empty$') -eq 1))
    $eng = @($r.out | Where-Object { $_ -match '^PROOF ENGINE read: .* -> engine (UP|DOWN)$' })
    $up = ($eng.Count -eq 1) -and ($eng[0] -match 'engine UP$')
    $r3 = Run $proof @('-Zip', $z.zip, '-ScratchRoot', (Join-Path $Work 'p3'), '-RunKey', 'h6-member', '-Through', 'release', '-EngineDown')
    L "(h6) the engine read: $($eng -join ''); -EngineDown exit=$($r3.code)"
    Check "(h6) -EngineDown reads the engine and, the engine $(if ($up) { 'UP: refuses, exit 3, nothing made' } else { 'DOWN: proceeds, exit 0' })" ($(if ($up) { ($r3.code -eq 3) -and -not (Test-Path -LiteralPath (Join-Path $Work 'p3\release')) } else { $r3.code -eq 0 }))
}
'h7' {
    # F-H7 (RELEASE-4 S2; row 495 (9)), measured and cured at UI-2 S1c (contract A-11, register row 522): POWERSHELL 7 AND
    # THE MARK OF THE WEB. (1) What each shell's Expand-Archive does with a ZIP carrying a Zone.Identifier stream: printed,
    # not asserted (it is the shell's behaviour; measured 2026-11-08: neither 5.1's Archive 1.0.1 nor 7.6.9's 1.2.6 carries
    # it to the members). (2) The GREEN rule, under Windows PowerShell 5.1 and under pwsh alike: the tagged clone's
    # install.ps1 and one installer-owned member given a Zone.Identifier stream (ZoneId=3, as Explorer's Extract All
    # leaves); -WhatIf and the install each name the 2 marked files once; the install says after the write that 0 written
    # files carry the stream; read here, no file in the target carries one; both shells' dispositions and counts are
    # equal. (3) INSTALL.md section 3 names PowerShell 7, Zone.Identifier and the measurement. No pwsh on PATH: the 5.1
    # half runs and the pwsh half SKIPS BY NAME (a skip, never a pass).
    $pw = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shells = @([pscustomobject]@{ n = 'ps51'; exe = $ps51 })
    if ($pw) { $shells += [pscustomobject]@{ n = 'pwsh'; exe = $pw.Source } }
    else { L 'CHECK SKIP  (h7) the pwsh half: no PowerShell 7 host here (pwsh is not on PATH) -- the 5.1 half is measured, the pwsh half is not' }
    function RunH7 { param([string]$Exe, [string]$Script, [string[]]$A)
        $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = @(& $Exe -NoProfile -ExecutionPolicy Bypass -File $Script @A 2>&1); $c = $LASTEXITCODE } finally { $ErrorActionPreference = $p }
        return [pscustomobject]@{ code = $c; out = @($o | ForEach-Object { "$_" }) }
    }
    function MarkedIn { param([string]$Root) @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { @(Get-Item -LiteralPath $_.FullName -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -eq 'Zone.Identifier' }).Count -gt 0 }).Count }
    $zi = "[ZoneTransfer]`r`nZoneId=3"
    # (1) Expand-Archive, per shell
    $d = Join-Path $Work 'motw'; $null = New-Item -ItemType Directory -Force -Path (Join-Path $d 'in')
    [System.IO.File]::WriteAllText((Join-Path $d 'in\a.txt'), "a`n"); $z = Join-Path $d 'src.zip'
    Compress-Archive -Path (Join-Path $d 'in\*') -DestinationPath $z; Set-Content -LiteralPath $z -Stream Zone.Identifier -Value $zi
    $probe = Join-Path $d 'probe.ps1'
    [System.IO.File]::WriteAllText($probe, "param([string]`$Z, [string]`$X)`n`$ErrorActionPreference = 'Stop'`n'PS ' + `$PSVersionTable.PSVersion + ', Archive ' + (Get-Command Expand-Archive).Version`n'zip streams: ' + ((Get-Item -LiteralPath `$Z -Stream * | ForEach-Object Stream) -join ',')`nExpand-Archive -LiteralPath `$Z -DestinationPath `$X`n'expanded member streams: ' + ((Get-Item -LiteralPath (Join-Path `$X 'a.txt') -Stream * | ForEach-Object Stream) -join ',')`n")
    foreach ($s in $shells) {
        $r = RunH7 $s.exe $probe @('-Z', $z, '-X', (Join-Path $d "x-$($s.n)"))
        L "(h7) Expand-Archive of a marked ZIP under $($s.n): exit $($r.code)"; $r.out | ForEach-Object { L "  | $_" }
        Check "(h7) the Expand-Archive measurement ran under $($s.n) (exit 0; what it does with the stream is printed above)" ($r.code -eq 0)
    }
    # (2) the installer over a marked source
    $member = @($owned.Keys | Where-Object { $owned[$_].class -eq 'MOVE' } | Sort-Object)[0]
    foreach ($m in @('install.ps1', $member)) { Set-Content -LiteralPath (Join-Path $Tagged.root ($m -replace '/', '\')) -Stream Zone.Identifier -Value $zi }
    L "(h7) marked in the tagged clone: install.ps1 and $member (Zone.Identifier ZoneId=3); git status there: $(((RunGit $Tagged.root @('status', '--porcelain')).out -join ' ').Trim())"
    $faces = @{}
    foreach ($s in $shells) {
        $t = Join-Path $Work "t-$($s.n)"; $null = New-Item -ItemType Directory -Force -Path $t
        $prevVh = $env:VANGUARD_HOME; $env:VANGUARD_HOME = Join-Path $Work "vh-$($s.n)"
        try {
            $w = RunH7 $s.exe $installer @('-Target', $t, '-WhatIf', '-SkipPythonSet')
            $wWrote = @(Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue).Count
            $r = RunH7 $s.exe $installer @('-Target', $t, '-SkipPythonSet')
        } finally { if ($null -eq $prevVh) { Remove-Item Env:VANGUARD_HOME -ErrorAction SilentlyContinue } else { $env:VANGUARD_HOME = $prevVh } }
        $pre = '^install\.ps1: MARK OF THE WEB: this tree carries a Zone\.Identifier stream on 2 file\(s\) \(install\.ps1, ' + [regex]::Escape($member) + '\)\. .*Unblock-File.*INSTALL\.md section 3'
        $post = '^install\.ps1: MARK OF THE WEB: \d+ file\(s\) written; carrying a Zone\.Identifier stream after the write: 0 \(removed from \d+\)\.$'
        L "(h7) under $($s.n): -WhatIf exit $($w.code), install exit $($r.code)"
        @($r.out | Where-Object { $_ -match 'MARK OF THE WEB|done: ' }) | ForEach-Object { L "  | $_" }
        $inT = MarkedIn $t
        Check "(h7) under $($s.n): -WhatIf names the 2 marked files once, with the fix, and writes nothing" (($w.code -eq 0) -and ((Count $w.out $pre) -eq 1) -and ($wWrote -eq 0))
        Check "(h7) under $($s.n): the install exits 0, names the 2 marked files once, and says after the write that 0 written files carry the stream" (($r.code -eq 0) -and ((Count $r.out $pre) -eq 1) -and ((Count $r.out $post) -eq 1))
        Check "(h7) under $($s.n): read here, no file in the target carries a Zone.Identifier stream ($inT)" ($inT -eq 0)
        $faces[$s.n] = @($r.out | Where-Object { $_ -match '^install\.ps1:   \S' -or $_ -match '^install\.ps1: (done|MARK OF THE WEB): ' })
    }
    if ($pw) { Check "(h7) the install's dispositions, its MARK OF THE WEB lines and its counts are the same under 5.1 and pwsh ($($faces['ps51'].Count) / $($faces['pwsh'].Count) lines)" (Same $faces['ps51'] $faces['pwsh']) }
    # (3) the docs
    $im3 = DocText (Join-Path $Repo 'INSTALL.md')
    Check '(h7) INSTALL.md names PowerShell 7, Zone.Identifier, Expand-Archive and the installer''s MARK OF THE WEB lines' ($im3.Contains('PowerShell 7') -and $im3.Contains('Zone.Identifier') -and $im3.Contains('Expand-Archive') -and $im3.Contains('MARK OF THE WEB'))
}
'd524' {
    # UI-2 S1c register row 524 (RELEASE-4 retrospective section 5): INSTALL.md section 6 and the 1.2.0 notes' item 3.2 said
    # only .claude/settings.json differs among the kept files -- true of an unedited install only. Both now say the kept set
    # is .claude/settings.json and any other file the installer reports kept, and neither says "only".
    foreach ($doc in @('INSTALL.md', 'docs/RELEASE-NOTES-v1.2.0.md')) {
        $txt = DocText (Join-Path $Repo ($doc -replace '/', '\'))
        if ($doc -ceq 'INSTALL.md') { $m = [regex]::Match($txt, '## 6\. .*?(?=## 7\. )'); $txt = if ($m.Success) { $m.Value } else { '' } }
        $only = [regex]::Matches($txt, 'only `?\.claude/settings\.json`? differs').Count
        $set = $txt.Contains('The kept set is `.claude/settings.json` and any other file the installer reports kept')
        L "(d524) $doc$(if ($doc -ceq 'INSTALL.md') { ' section 6' }): 'only ... settings.json differs' $only time(s); names the kept set as settings.json and any other file reported kept: $set"
        Check "(d524) $doc says the kept set is .claude/settings.json and any other file the installer reports kept, and never 'only .claude/settings.json differs'" (($only -eq 0) -and $set)
    }
}
'h11' {
    # F-H11 (RELEASE-4 S2, carried), as UI-2 S1c A-14 restates it (register row 520): THE RELEASE TREE'S EOL PIN, held by a
    # member that reads the lock and the files. -Verify judges on the fold-crlf-text basis, so a member whose line endings
    # drift reads no difference there; this member holds every framework.lock row whose eol is lf or crlf to (a) the
    # release source file's own line endings (the tagged clone, the tree the lock recorded) and (b) the installed file's.
    # Planted: one lf member rewritten with CR LF in the target -- -Verify still reads 0 differences, and the member names it.
    function EolPinMisses { param($Lk, [string]$Target)
        $miss = @()
        foreach ($r in @($Lk.rows | Where-Object { @('lf', 'crlf') -contains [string]$_.eol })) {
            $rel = $r.path -replace '/', '\'
            $se = EolOf ([System.IO.File]::ReadAllBytes((Join-Path $Tagged.root $rel)))
            $tp = Join-Path $Target $rel
            $te = if (Test-Path -LiteralPath $tp -PathType Leaf) { EolOf ([System.IO.File]::ReadAllBytes($tp)) } else { '(absent)' }
            if (($se -cne $r.eol) -or ($te -cne $r.eol)) { $miss += "$($r.path) lock=$($r.eol) release=$se target=$te" }
        }
        return , $miss
    }
    $t = Join-Path $Work 't'; $null = New-Item -ItemType Directory -Force -Path $t
    $ri = Run $installer @('-Target', $t)
    Check '(h11) a fresh install from the tagged clone, exit 0' ($ri.code -eq 0)
    $lk = ReadLock $t
    $pinned = @($lk.rows | Where-Object { @('lf', 'crlf') -contains [string]$_.eol })
    $c = EolCensus $lk.rows
    $m0 = EolPinMisses $lk $t
    L "(h11) lock rows $($lk.rows.Count): $(CensusText $c); rows the pin holds (lf or crlf): $($pinned.Count); misses $($m0.Count)"
    $m0 | Select-Object -First 5 | ForEach-Object { L "  | $_" }
    Check "(h11) every framework.lock row recorded lf or crlf ($($pinned.Count), crlf $($c['crlf'])) names a release file and an installed file with exactly those line endings" (($pinned.Count -gt 0) -and ($m0.Count -eq 0))
    # PLANTED: one lf member rewritten with CR LF in the target
    $victim = @($pinned | Where-Object { $_.eol -ceq 'lf' } | Sort-Object path)[0].path
    $vp = Join-Path $t ($victim -replace '/', '\')
    WriteBytes $vp (Bytes ($L1.GetString([System.IO.File]::ReadAllBytes($vp)).Replace("`r`n", "`n").Replace("`n", "`r`n")))
    $v = Run $installer @('-Target', $t, '-Verify')
    $m1 = EolPinMisses $lk $t
    L "(h11) PLANTED $victim rewritten with CR LF: -Verify exit $($v.code), $(@($v.out | Where-Object { $_ -match 'verify: \d+ file' }) -join ''); the pin's misses $($m1.Count)"
    $m1 | ForEach-Object { L "  | $_" }
    Check "(h11) PLANTED: -Verify reads the drift as no difference (the fold basis; exit 0), and the eol pin names exactly $victim" (($v.code -eq 0) -and ($m1.Count -eq 1) -and ($m1[0] -like "$victim lock=lf release=lf target=crlf"))
}
'p7' {
    # UI-2 S1c A-12 (register row 522): THE INSTALL PATH UNDER POWERSHELL 7. The same inputs -- the tagged clone, a fresh
    # git project with a bare origin and one empty commit pushed, its own VANGUARD_HOME -- driven once with every step a
    # child of Windows PowerShell 5.1 and once of pwsh: install.ps1 -WhatIf, the install, -Verify, mission.ps1 init (then
    # committed and pushed), smoke and register, and the installed tools\lam\build-smoke-mission.ps1. Each step's exit
    # code and its count line (paths made neutral) are equal across the shells. No pwsh on PATH: SKIPPED BY NAME.
    $pw = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pw) { L 'CHECK SKIP  (p7) no PowerShell 7 host here (pwsh is not on PATH): the install path under pwsh is not measured' }
    else {
        $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $mis = Join-Path $Tagged.root 'mission.ps1'
        $id = @('-c', 'user.name=p7', '-c', 'user.email=p7@example.invalid', '-c', 'core.autocrlf=false')
        $read = @{}
        foreach ($s in @([pscustomobject]@{ n = 'ps51'; exe = $ps51 }, [pscustomobject]@{ n = 'pwsh'; exe = $pw.Source })) {
            $sr = Join-Path $Work "p7-$($s.n)"; $o = Join-Path $sr 'origin.git'; $t = Join-Path $sr 'project'
            $null = New-Item -ItemType Directory -Force -Path $sr
            $null = RunGit $sr @('init', '-q', '--bare', '-b', 'main', $o); $null = RunGit $sr @('clone', '-q', $o, $t)
            $null = RunGit $t ($id + @('commit', '-q', '--allow-empty', '-m', 'empty')); $null = RunGit $t @('push', '-q', 'origin', 'main')
            $prevVh = $env:VANGUARD_HOME; $env:VANGUARD_HOME = Join-Path $sr 'vh'
            $steps = [ordered]@{}
            function P7 { param([string]$Name, [string]$Script, [string[]]$A, [string]$Key)
                $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
                try { $x = @(& $s.exe -NoProfile -ExecutionPolicy Bypass -File $Script @A 2>&1 | ForEach-Object { "$_" }); $c = $LASTEXITCODE } finally { $ErrorActionPreference = $p }
                $k = @($x | Where-Object { $_ -match $Key } | ForEach-Object { $_.Replace($sr, '<scratch>') })
                $steps[$Name] = "exit $c | $($k -join ' / ')"
                L "(p7) $($s.n) $Name : exit $c$(if ($k.Count) { ' | ' + ($k -join ' / ') })"
                if ($c -ne 0) { @($x | Select-Object -Last 4) | ForEach-Object { L "    | $_" } }
            }
            try {
                P7 'whatif'  $installer @('-Target', $t, '-SkipPythonSet', '-WhatIf') '^install\.ps1: planned: '
                P7 'install' $installer @('-Target', $t, '-SkipPythonSet') '^install\.ps1: done: '
                P7 'verify'  $installer @('-Target', $t, '-Verify') '^install\.ps1: verify: \d+ file'
                P7 'init'    $mis @('init', '-Target', $t) '^mission\.ps1: initialised an empty mission'
                $null = RunGit $t @('add', '-A'); $null = RunGit $t ($id + @('commit', '-q', '-m', 'init')); $null = RunGit $t @('push', '-q', 'origin', 'main')
                P7 'smoke'    $mis @('smoke', '-Target', $t) '^mission\.ps1: smoke: '
                P7 'register' $mis @('register', '-Target', $t) '^mission\.ps1: registered on this host'
                P7 'build'    (Join-Path $t 'tools\lam\build-smoke-mission.ps1') @('-SmokeRoot', (Join-Path $sr 'lam-smoke')) '^EXIT: '
            } finally { if ($null -eq $prevVh) { Remove-Item Env:VANGUARD_HOME -ErrorAction SilentlyContinue } else { $env:VANGUARD_HOME = $prevVh } }
            $read[$s.n] = $steps
        }
        foreach ($k in $read['ps51'].Keys) {
            # the mission id and the host id are minted per run: compared by shape
            $a = $read['ps51'][$k] -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '<uuid>'
            $b = $read['pwsh'][$k] -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '<uuid>'
            Check "(p7) $k reads the same under 5.1 and pwsh, exit 0: $a" (($a -ceq $b) -and ($a -like 'exit 0 |*'))
        }
    }
}
'h14' {
    # F-H14 (RELEASE-4 S2; S1 F7, amendment-1 note): NO PERMISSION-RULE FORM THE CLI REJECTS, IN ANY INSTALLED SETTINGS FILE.
    # (1) the settings templates of the tagged clone are scanned for Write(path)/MultiEdit(path)/NotebookEdit(path) rule
    # forms (expect 0; every file rule is written as Edit, tools/lam/settings/validator.json says so); (2) claude -p runs
    # ONCE in a project the tagged clone installed, with this session's markers cleared for it and its stderr to a file,
    # and no stderr line reads "Permission ... rule ... matches no known tool / is not matched". No claude on PATH: SKIP.
    $tpl = @('.claude/settings.json', 'tools/lam/settings/orchestrator.json', 'tools/lam/settings/validator.json', 'tools/lam/settings/worker.json', 'tools/lam/smoke-mission/dot-claude/settings.local.json')
    $forms = @()
    foreach ($p in $tpl) {
        $fp = Join-Path $Tagged.root ($p -replace '/', '\')
        if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { $forms += "$p (absent)"; continue }
        # the RULES only -- the strings of permissions.allow, .deny and .ask; prose elsewhere in a file may name a form
        $sj = [System.IO.File]::ReadAllText($fp) | ConvertFrom-Json
        $perm = if ($sj.PSObject.Properties['permissions']) { $sj.permissions } else { $null }
        foreach ($k in @('allow', 'deny', 'ask')) {
            if ($null -eq $perm -or $null -eq $perm.PSObject.Properties[$k]) { continue }
            foreach ($rule in @($perm.$k)) { if ([string]$rule -match '^\s*(Write|MultiEdit|NotebookEdit)\(') { $forms += "$p permissions.$k $rule" } }
        }
    }
    L "(h14) rule forms the CLI rejects, in $($tpl.Count) settings templates: $($forms.Count)$(if ($forms.Count) { ' -- ' + ($forms -join '; ') })"
    Check "(h14) no Write(path), MultiEdit(path) or NotebookEdit(path) rule form in the $($tpl.Count) settings templates" ($forms.Count -eq 0)
    $cl = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cl) { L 'CHECK SKIP  (h14) claude is not on PATH: the CLI''s own reading of the installed settings is not measured here' }
    else {
        $t = Join-Path $Work 'p'; $null = New-Item -ItemType Directory -Force -Path $t; $null = RunGit $t @('init', '-q')
        $ri = Run $installer @('-Target', $t)
        Check '(h14) the project for the CLI: a fresh install, exit 0' ($ri.code -eq 0)
        $eo = Join-Path $Work 'claude-stderr.txt'; $so = Join-Path $Work 'claude-stdout.txt'
        $cv = @(Get-ChildItem Env: | Where-Object { $_.Name -eq 'CLAUDECODE' -or $_.Name -like 'CLAUDE_CODE_*' -or $_.Name -eq 'CLAUDE_PROJECT_DIR' } | ForEach-Object { [pscustomobject]@{ n = $_.Name; v = $_.Value } })
        foreach ($x in $cv) { [Environment]::SetEnvironmentVariable($x.n, $null) }
        $pr = $null
        try {
            $pr = Start-Process -FilePath $cl.Source -ArgumentList @('-p', '"Reply with the single word OK."', '--max-turns', '1') -WorkingDirectory $t -NoNewWindow -PassThru -RedirectStandardError $eo -RedirectStandardOutput $so
            $null = $pr.Handle   # F-X6: holding the handle keeps ExitCode readable after the exit (Start-Process -PassThru drops it)
            if (-not $pr.WaitForExit(300000)) { try { $pr.Kill() } catch { } }
        } finally { foreach ($x in $cv) { [Environment]::SetEnvironmentVariable($x.n, $x.v) } }
        $errLines = @(if (Test-Path -LiteralPath $eo) { [System.IO.File]::ReadAllLines($eo) })
        $bad = @($errLines | Where-Object { $_ -match 'Permission .* rule .* (matches no known tool|is not matched)' })
        L "(h14) claude -p in the installed project: exit $(if ($pr -and $pr.HasExited) { $pr.ExitCode } else { '(killed at 300 s)' }); stderr lines $($errLines.Count); stdout $(if (Test-Path -LiteralPath $so) { ([System.IO.File]::ReadAllText($so)).Trim().Length } else { 0 }) chars"
        foreach ($l in @($errLines | Select-Object -First 8)) { L "  stderr | $l" }
        Check "(h14) claude -p ran once in the installed project (its stderr captured) and no stderr line names a permission rule the CLI rejects ($($bad.Count))" (($null -ne $pr) -and $pr.HasExited -and (Test-Path -LiteralPath $eo) -and ($bad.Count -eq 0))
        # F-X6 (RELEASE-4 S3; S2 validator X-6): the CLI's exit code is recorded, and is 0
        $cx = if ($pr -and $pr.HasExited) { $pr.ExitCode } else { $null }
        L "(h14) claude -p exit code recorded: '$cx'"
        Check "(h14) claude -p's exit code is recorded and is 0 ('$cx')" (($null -ne $cx) -and ("$cx" -ne '') -and ($cx -eq 0))
    }
}
'h8' {
    # F-H8 (RELEASE-4 S2; row 505 (d); UI-1 S5-R1): THE INSTALLER WARNS ON A GIT-IGNORED MEMBER. A git project whose own
    # .gitignore holds dist/, *.cmd and a negated rule (its global excludes pointed at an empty file, so only its own rules
    # speak): -WhatIf and the install print one WARNING per installed member the rules hide -- here every member *.cmd
    # matches -- naming .gitignore, the line and the rule; none for another member; the file still written. A git project
    # with no rules: no warning.
    $mkRepo = { param([string]$Dir, [string]$Ignore)
        $null = New-Item -ItemType Directory -Force -Path $Dir
        $null = RunGit $Dir @('init', '-q'); $null = RunGit $Dir @('config', 'core.autocrlf', 'false')
        $null = RunGit $Dir @('config', 'user.name', 'falsifier-fixture'); $null = RunGit $Dir @('config', 'user.email', 'falsifier-fixture@localhost')
        $ex = Join-Path $Dir '.git\empty-excludes'; [System.IO.File]::WriteAllText($ex, '')
        $null = RunGit $Dir @('config', 'core.excludesFile', $ex)
        [System.IO.File]::WriteAllText((Join-Path $Dir 'README.md'), "h8`n")
        if ($Ignore) { [System.IO.File]::WriteAllText((Join-Path $Dir '.gitignore'), $Ignore) }
        $null = RunGit $Dir @('add', '-A'); $null = RunGit $Dir @('commit', '-q', '-m', 'the project before the install')
    }
    $t = Join-Path $Work 'ig'
    & $mkRepo $t "dist/`n*.cmd`n!tools/ui/never-installed.cmd`n"
    $expect = Sorted @($owned.Keys | Where-Object { $_ -like '*.cmd' })
    $warnRx = '^install\.ps1: WARNING ignored (\S+) -- the target''s git ignore rules hide it: \.gitignore:2: \*\.cmd \(git check-ignore -v\); '
    foreach ($leg in @(@('-WhatIf', @('-Target', $t, '-WhatIf')), @('install', @('-Target', $t)))) {
        $r = Run $installer $leg[1]
        $all = @($r.out | Where-Object { $_ -match '^install\.ps1: WARNING ignored ' })
        $named = Sorted @($r.out | Where-Object { $_ -match $warnRx } | ForEach-Object { if ($_ -match $warnRx) { $Matches[1] } })
        L "(h8 $($leg[0])) exit $($r.code); WARNING lines $($all.Count); named $($named -join ', '); expected $($expect -join ', ')"
        Check "(h8 $($leg[0])) exit 0; one WARNING per member the rule *.cmd hides ($($expect.Count)), naming .gitignore:2 and the rule; no other WARNING" (
            ($r.code -eq 0) -and ($expect.Count -gt 0) -and (Same $named $expect) -and ($all.Count -eq $expect.Count))
    }
    Check '(h8) the hidden members are written all the same (each at its manifest bytes)' ((@($expect | Where-Object { (FileSha (Join-Path $t ($_ -replace '/', '\'))) -ne $owned[$_].sha256 }).Count -eq 0))
    $t2 = Join-Path $Work 'noig'
    & $mkRepo $t2 ''
    $r2 = Run $installer @('-Target', $t2, '-WhatIf')
    Check '(h8) a git project with no ignore rules: -WhatIf exit 0 and no WARNING line' (($r2.code -eq 0) -and ((Count $r2.out '^install\.ps1: WARNING ignored ') -eq 0))
    # F-X3 (RELEASE-4 S3; S2 validator X-3): THE NEGATED RULE NAMES AN INSTALLED MEMBER. *.cmd, then !tools/ui/vanguard.cmd (the
    # one installed *.cmd): git check-ignore -v reports the member against the NEGATED rule -- a match that hides nothing --
    # so the installer's '!' filter is what keeps it from a WARNING; the install writes the member and warns of nothing.
    $t3 = Join-Path $Work 'neg'
    & $mkRepo $t3 "dist/`n*.cmd`n!tools/ui/vanguard.cmd`n"
    $r3 = Run $installer @('-Target', $t3)
    $ci = RunGit $t3 @('check-ignore', '-v', '--', 'tools/ui/vanguard.cmd')
    $negLine = @($ci.out | Where-Object { $_ -match '^\.gitignore:3:!tools/ui/vanguard\.cmd\ttools/ui/vanguard\.cmd$' })
    L "(h8 negated) install exit $($r3.code); WARNING lines $(Count $r3.out '^install\.ps1: WARNING ignored '); git check-ignore -v tools/ui/vanguard.cmd: $((@($ci.out) -join ' | '))"
    Check '(h8 negated) *.cmd re-included by !tools/ui/vanguard.cmd, an installed member: git check-ignore -v reports the negated rule for it, and the install (exit 0) prints no WARNING and writes it' (
        ($r3.code -eq 0) -and ($negLine.Count -eq 1) -and ((Count $r3.out '^install\.ps1: WARNING ignored ') -eq 0) -and ((FileSha (Join-Path $t3 'tools\ui\vanguard.cmd')) -eq $owned['tools/ui/vanguard.cmd'].sha256))
}
'h10' {
    # F-H10 (RELEASE-4 S2; row 495 (10)): THE CENSUS HEADER's EVALUATOR DIGEST BY THE FOLD RULE. The tagged clone's
    # exporter run over the v0.2.0 evaluator (upgrade.json's census tag, cloned) as it stands (LF), over a CRLF copy of it,
    # and over a copy with one line appended: the LF and CRLF censuses are byte-equal and their header names the
    # fold-crlf-text digest (computed here) and the basis; the changed evaluator's header differs.
    $C = $U.census
    $exp = Join-Path $Tagged.root ($C.exporter -replace '/', '\')
    $old = New-Clone -Dest (Join-Path $Work 'v020') -Rev $C.tag
    $ev = [System.IO.File]::ReadAllBytes((Join-Path $old 'tools\lam\mission-goal-check.ps1'))
    $lfB = $L1.GetBytes($L1.GetString($ev).Replace("`r`n", "`n")); $crB = $L1.GetBytes($L1.GetString($lfB).Replace("`n", "`r`n"))
    $chB = [byte[]]($lfB + [System.Text.Encoding]::ASCII.GetBytes("# one line more`n"))
    $outs = @{}
    foreach ($arm in @(@('lf', $lfB), @('crlf', $crB), @('changed', $chB))) {
        $d = Join-Path $Work ('h10-' + $arm[0]); $null = New-Item -ItemType Directory -Force -Path $d
        $src = Join-Path $d 'mission-goal-check.ps1'; [System.IO.File]::WriteAllBytes($src, [byte[]]$arm[1])
        $to = Join-Path $d 'legacy-halt-census.txt'
        $x = Run $exp @('-From', $src, '-To', $to)
        L "(h10 $($arm[0])) exporter exit $($x.code): $((@($x.out) | Select-Object -Last 1) -join '')"
        $outs[$arm[0]] = if (Test-Path -LiteralPath $to) { [System.IO.File]::ReadAllBytes($to) } else { $null }
    }
    $hdr = { param($b) if ($null -eq $b) { return '' }; return (@($L1.GetString($b).Split([char]10) | Where-Object { $_ -match '^# mission-goal-check\.ps1 of sha256 ' }) -join '') }
    $want = FoldSha $lfB
    $hLf = & $hdr $outs['lf']; $hCr = & $hdr $outs['crlf']; $hCh = & $hdr $outs['changed']
    L "(h10) header lines: lf '$hLf'; crlf '$hCr'; changed '$hCh'; the fold digest computed here $want"
    Check '(h10) the LF and the CRLF checkout of one evaluator write byte-equal censuses' (($null -ne $outs['lf']) -and ($null -ne $outs['crlf']) -and ((Sha $outs['lf']) -eq (Sha $outs['crlf'])))
    Check "(h10) the header carries the evaluator's fold-crlf-text digest ($want) and names the basis" ($hLf.Contains($want) -and $hLf.Contains('fold-crlf-text'))
    Check '(h10) a changed evaluator writes a different header' ($hCh -and ($hCh -cne $hLf))
}
'h16' {
    # F-H16 (RELEASE-4 S2; S1b F-e): THE VERIFY SPEC's SECTION 10 ANCHOR TABLE EQUALS DISK. tools/lam/verify-spec-anchors.ps1
    # (AUTHORED: the framework repository's own, not installed -- so its member is here, not in an installed instrument)
    # over the tagged clone: exit 0, every row equal (sha256 on fold-crlf-text, bytes raw); over a scratch copy of the
    # clone's spec and the files it names with one row put back stale (the expanded-schemas.md row 83960a9e/79452 it read
    # at fc9dc67): exit 1, that row named DIFFERS.
    $tool = Join-Path $Tagged.root 'tools\lam\verify-spec-anchors.ps1'
    $r = Run $tool @('-Root', $Tagged.root)
    L "(h16) over the tagged clone: exit $($r.code); $((@($r.out) | Select-Object -Last 1) -join '')"
    Check '(h16) every row of the verify spec''s section 10 anchor table equals the file it names: exit 0, 0 differ' (($r.code -eq 0) -and ((Count $r.out '^verify-spec-anchors: \d+ row\(s\), 0 differ$') -eq 1))
    $cp = Join-Path $Work 'stale'
    $spec = 'docs\framework\mission-verify-spec.md'
    $rows = @([regex]::Matches([System.IO.File]::ReadAllText((Join-Path $Tagged.root $spec)), '(?m)^[0-9a-f]{8}[ \t]+\d+[ \t]+(\S+)[ \t]*\r?$') | ForEach-Object { $_.Groups[1].Value })
    foreach ($p in @($rows + @($spec -replace '\\', '/'))) { WriteBytes (Join-Path $cp ($p -replace '/', '\')) ([System.IO.File]::ReadAllBytes((Join-Path $Tagged.root ($p -replace '/', '\')))) }
    $sp = Join-Path $cp $spec
    $st = [System.IO.File]::ReadAllText($sp)
    $st2 = [regex]::Replace($st, '(?m)^[0-9a-f]{8}([ \t]+)\d+([ \t]+docs/framework/expanded-schemas\.md)', ('83960a9e${1}79452${2}'))
    [System.IO.File]::WriteAllText($sp, $st2)
    $r2 = Run $tool @('-Root', $cp)
    Check '(h16) one row put back stale (the fc9dc67 expanded-schemas.md row) reads exit 1, that row DIFFERS' (($st2 -cne $st) -and ($r2.code -eq 1) -and ((Count $r2.out '^verify-spec-anchors: anchor DIFFERS docs/framework/expanded-schemas\.md ') -eq 1))
}
'h18' {
    # F-H18 (RELEASE-4 S2, found 2026-11-06): THE SMOKE BUILDER LEAVES THE CALLER'S ENVIRONMENT UNTOUCHED. The tagged clone's
    # tools/lam/build-smoke-mission.ps1 is run IN THIS PROCESS (&), as an operator runs it in a terminal, so anything it
    # sets in its own process is set here: this process's Env: before and after must be identical; nothing named
    # <root>.no-global-gitconfig stands beside the smoke root and no isolation folder is left in the temp folder; the
    # fixture's commits still carry the Smoke Builder identity; WP-6 ZP's exclusion table still names the builder session.
    $builder = Join-Path $Tagged.root 'tools\lam\build-smoke-mission.ps1'
    $sp = Join-Path $Work 'sm'; $null = New-Item -ItemType Directory -Force -Path $sp
    $sr = Join-Path $sp 'lam-smoke'
    $snap = { (@(Get-ChildItem Env: | Sort-Object Name | ForEach-Object { $_.Name + '=' + $_.Value }) -join "`n") }
    $isoGlob = { @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Directory -Filter 'lam-smoke-iso-*' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) }
    $envBefore = & $snap; $isoBefore = & $isoGlob
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $bo = @(& $builder -SmokeRoot $sr *>&1 | ForEach-Object { "$_" }); $bc = $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
    $envAfter = & $snap; $isoAfter = & $isoGlob
    L "(h18) the builder in this process: exit $bc; last lines: $((@($bo) | Select-Object -Last 3) -join ' | ')"
    Check '(h18) the builder, run in this process, builds the smoke mission: exit 0 and the root a git repository' (($bc -eq 0) -and (Test-Path -LiteralPath (Join-Path $sr '.git')))
    $bl = @($envBefore -split "`n"); $al = @($envAfter -split "`n")
    $added = @($al | Where-Object { $bl -cnotcontains $_ }); $gone = @($bl | Where-Object { $al -cnotcontains $_ })
    L "(h18) Env: lines changed by the build: $($added.Count) added or altered, $($gone.Count) removed or altered$(if ($added.Count) { ' -- e.g. ' + ((@($added) | Select-Object -First 4 | ForEach-Object { ($_ -split '=')[0] }) -join ', ') })"
    Check "(h18) this process's environment is identical before and after the build (Env: compared whole)" ($envAfter -ceq $envBefore)
    $beside = Join-Path $sp 'lam-smoke.no-global-gitconfig'
    $isoLeft = @($isoAfter | Where-Object { $isoBefore -notcontains $_ })
    Check "(h18) nothing beside the smoke root ($(@(Get-ChildItem -LiteralPath $sp -Force | ForEach-Object { $_.Name }) -join ', ')): no lam-smoke.no-global-gitconfig, and no isolation folder left in the temp folder ($($isoLeft.Count))" (
        -not (Test-Path -LiteralPath $beside) -and ($isoLeft.Count -eq 0) -and (@(Get-ChildItem -LiteralPath $sp -Force | Where-Object { @('lam-smoke', 'lam-smoke-origin.git') -notcontains $_.Name }).Count -eq 0))
    $ids = @((RunGit $sr @('log', '--format=%an <%ae>|%cn <%ce>')).out | Select-Object -Unique)
    Check "(h18) every fixture commit carries the Smoke Builder identity, author and committer ($($ids -join '; '))" (($ids.Count -eq 1) -and ($ids[0] -cmatch '^Smoke Builder <[^>]+>\|Smoke Builder <[^>]+>$'))
    $bt = [System.IO.File]::ReadAllText($builder)
    $bs = [regex]::Match($bt, '(?m)^\$builderSession\s*=\s*''([0-9a-f-]{36})''')
    $zp = [System.IO.File]::ReadAllText((Join-Path $Tagged.root 'tests\lam\instrument-WP-6.ps1'))
    Check "(h18) WP-6 ZP's exclusion table still names the builder session ($(if ($bs.Success) { $bs.Groups[1].Value } else { 'none read' }))" ($bs.Success -and $zp.Contains($bs.Groups[1].Value))
}
'l1' {
    # F-L1 (RELEASE-4 S3; row 495 (1); the operator ruling of 2026-11-06): ONE LICENCE, free use with paid support. -Repo's
    # working files are read (as h7 reads INSTALL.md). LICENSE is byte for byte the owner-approved text, whose sha256 the
    # contract's SHA256SUMS states (pinned here); README's Licence section is two sentences; no tracked file names the
    # superseded licence as current, but the historical release notes (never rewritten), the provenance manifest's
    # reasons (a record of each file's history) and LICENSE's own last line, which names what it supersedes.
    $licWant = '5ff7017e99da68eb451b1f04b4568c47ca2ff8cca6552a021e25ef5492899204'
    $lb = [System.IO.File]::ReadAllBytes((Join-Path $Repo 'LICENSE'))
    $lbom = ($lb.Length -ge 3 -and $lb[0] -eq 0xEF -and $lb[1] -eq 0xBB -and $lb[2] -eq 0xBF)
    L "(l1) LICENSE: $($lb.Length) bytes, sha256 $(Sha $lb), eol $(EolOf $lb), BOM $lbom"
    Check "(l1) LICENSE is byte for byte the owner-approved licence text (sha256 $licWant), LF, no BOM" (((Sha $lb) -eq $licWant) -and ((EolOf $lb) -eq 'lf') -and -not $lbom)
    $rt = [System.IO.File]::ReadAllText((Join-Path $Repo 'README.md'))
    $sec = [regex]::Match($rt, '(?ms)^## Licence[ \t]*\r?\n(.*?)(?=^## |\z)')
    $body = if ($sec.Success) { ($sec.Groups[1].Value -replace '\s+', ' ').Trim() } else { '' }
    $sn = @([regex]::Split($body, '(?<=\.)\s+(?=[A-Z])') | Where-Object { $_ })
    L "(l1) README's Licence section, $($sn.Count) sentence(s): $body"
    $one = ($sn.Count -ge 1) -and $sn[0].Contains('free to use') -and $sn[0].Contains('[LICENSE](LICENSE)') -and $sn[0].Contains('commercial') -and $sn[0].Contains('client') -and $sn[0].Contains('redistribut')
    $two = ($sn.Count -ge 2) -and $sn[1].Contains('support') -and $sn[1].Contains('paying customers') -and $sn[1].Contains('support@tekweaver.ca')
    Check "(l1) README's Licence section is two sentences: free to use under LICENSE, commercial and client work included, the Framework itself not redistributed; support for paying customers by contact" (($sn.Count -eq 2) -and $one -and $two)
    # the superseded licence's name, assembled here so that this file does not name it
    $old = [regex]('(?i)' + 'evaluation' + '\s+licen[cs]e')
    $hist = @('docs/RELEASE-NOTES-v0.3.0.md', 'docs/RELEASE-NOTES-v1.0.0.md', 'docs/RELEASE-NOTES-v1.1.0.md', 'provenance/manifest.jsonl')
    $tracked = @((RunGit $Repo @('-c', 'core.quotePath=false', 'ls-files')).out | Where-Object { $_ })
    $hits = New-Object System.Collections.Generic.List[string]; $seen = 0
    foreach ($p in $tracked) {
        $fp = Join-Path $Repo ($p -replace '/', '\')
        if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { continue }
        $b = [System.IO.File]::ReadAllBytes($fp); if (IsBinary $b) { continue }; $seen++
        $ls = $NoBom.GetString($b).Split([char]10)
        for ($i = 0; $i -lt $ls.Count; $i++) {
            if (-not $old.IsMatch($ls[$i])) { continue }
            if ($hist -contains $p) { continue }
            if ($p -ceq 'LICENSE' -and $i -eq ($ls.Count - 2) -and $ls[$i].StartsWith('Version ') -and $ls[$i].Contains('supersedes')) { continue }
            # the 1.2.0 notes' one supersession line (operator ruling 2026-11-06), by file and exact text, assembled like $old
            if ($p -ceq 'docs/RELEASE-NOTES-v1.2.0.md' -and $ls[$i] -ceq ('  Framework itself is not redistributed; support for paying customers -- supersedes the ' + 'Evaluation' + ' Licence of 1.0.0')) { continue }
            $hits.Add("${p}:$($i + 1)")
        }
    }
    L "(l1) the superseded licence named in $($tracked.Count) tracked file(s) ($seen text): $($hits.Count) line(s) outside the historical notes, the manifest's reasons and LICENSE's last line$(if ($hits.Count) { ' -- ' + ($hits -join ', ') })"
    Check "(l1) no tracked file names the superseded licence as current (outside $($hist -join ', '), LICENSE's supersession line and the 1.2.0 notes' supersession line): 0 line(s)" ($hits.Count -eq 0)
}
'l6' {
    # F-L6 (RELEASE-4 S3; roadmap decision 1, as the operator ruled it 2026-11-06): THE MODEL, SAID WHERE A READER STARTS.
    # README's first paragraph (the lines after the title up to the first blank line), QUICKSTART's head and INSTALL.md's
    # head (the text before the first '## ') each carry, in their own words: free to use under LICENSE, commercial and client
    # work included; the Framework itself not redistributed or resold; support by subscription for paying customers, by
    # support@tekweaver.ca. None of the three describes the superseded evaluation-only grant (its phrase assembled here).
    $evalPhrase = 'licensed for ' + 'evaluation'
    $docs = [ordered]@{ 'README.md' = 'first paragraph'; 'docs/QUICKSTART.md' = 'head'; 'INSTALL.md' = 'head' }
    foreach ($p in $docs.Keys) {
        $t = ([System.IO.File]::ReadAllText((Join-Path $Repo ($p -replace '/', '\')))) -replace "`r`n", "`n"
        $head = if ($docs[$p] -eq 'first paragraph') { ([regex]::Match($t, '(?s)\A#[^\n]*\n\n(.*?)\n\n')).Groups[1].Value } else { ([regex]::Match($t, '(?s)\A(.*?)\n## ')).Groups[1].Value }
        $h = ($head -replace '\s+', ' ')
        $need = @('free to use', 'LICENSE', 'commercial', 'client', 'redistribut', 'resold', 'subscription', 'paying customers', 'support@tekweaver.ca')
        $miss = @($need | Where-Object { -not $h.Contains($_) })
        $evalAt = @(([regex]::Matches($t, [regex]::Escape($evalPhrase))) | ForEach-Object { $_.Index }).Count
        L "(l6) $p, its $($docs[$p]) ($($h.Length) chars): missing $($miss.Count)$(if ($miss.Count) { ' -- ' + ($miss -join ', ') }); '$evalPhrase' in the file: $evalAt"
        Check "(l6) $p's $($docs[$p]) says the model -- $($need -join ', ') -- and the file never says '$evalPhrase'" (($h.Length -gt 0) -and ($miss.Count -eq 0) -and ($evalAt -eq 0))
    }
}
'l2' {
    # F-L2 (RELEASE-4 S3; row 495 (3)): THE PUBLIC REPOSITORY NAMED WHERE THE SOURCE IS FETCHED. INSTALL.md and QUICKSTART
    # (-Repo's working files) each name the public repository's URL, its Releases page, the four assets -- the fixed-name
    # vanguard-collective.zip, the versioned vanguard-collective-v<VERSION>.zip, SHA256SUMS, MEMBERS.sha256 -- and the
    # gh release download form against that repository; and no placeholder stands where the source should be named.
    $url = 'https://github.com/tekweaver-solutions/vanguard-collective-releases'
    foreach ($p in @('INSTALL.md', 'docs/QUICKSTART.md')) {
        $t = DocText (Join-Path $Repo ($p -replace '/', '\'))
        $need = [ordered]@{ 'the URL' = $url; 'the Releases page' = ($url + '/releases'); 'the fixed-name asset' = 'vanguard-collective.zip'
                            'the versioned asset' = 'vanguard-collective-v<VERSION>.zip'; 'SHA256SUMS' = 'SHA256SUMS'; 'MEMBERS.sha256' = 'MEMBERS.sha256'
                            'the gh form' = ('gh release download v<VERSION> --repo tekweaver-solutions/vanguard-collective-releases') }
        $miss = @($need.Keys | Where-Object { -not $t.Contains($need[$_]) })
        $urlN = ([regex]::Matches($t, [regex]::Escape($url))).Count
        $ph = @([regex]::Matches($t, '(?i)<[^<>]*\brepository\b[^<>]*\bURL\b[^<>]*>') | ForEach-Object { $_.Value })
        L "(l2) ${p}: the URL $urlN time(s); missing $($miss.Count)$(if ($miss.Count) { ' -- ' + ($miss -join ', ') }); placeholder token(s) $($ph.Count)$(if ($ph.Count) { ' -- ' + ($ph -join ', ') })"
        Check "(l2) $p names $url (1+), its Releases page, the fixed-name and versioned assets, SHA256SUMS, MEMBERS.sha256 and the gh release download form; no placeholder for the repository's URL (0)" (($urlN -ge 1) -and ($miss.Count -eq 0) -and ($ph.Count -eq 0))
    }
}
'l3' {
    # F-L3 (RELEASE-4 S3; row 495 (3)): THE ANNOTATED-TAG WARNING. INSTALL.md's clone section (from its heading to the next
    # heading) says the release tag is annotated, that git ls-remote lists the tag object and not the commit, that git clone
    # --branch warns '... is not a commit!', gives the form git rev-parse v<VERSION>^{commit} (the version never typed), and
    # names the id the installer records, source_commit.
    $t = ([System.IO.File]::ReadAllText((Join-Path $Repo 'INSTALL.md'))) -replace "`r`n", "`n"
    $sec = ([regex]::Match($t, '(?ms)^### Install from a clone of the public repository\n(.*?)(?=^#{2,3} )')).Groups[1].Value
    $s = $sec -replace '\s+', ' '
    $need = [ordered]@{ 'annotated' = 'annotated'; 'ls-remote' = 'git ls-remote'; 'the tag object' = 'tag object'; 'the warning' = 'is not a commit!'
                        'the form' = 'git rev-parse v<VERSION>^{commit}'; 'the lock field' = 'source_commit' }
    $miss = @($need.Keys | Where-Object { -not $s.Contains($need[$_]) })
    $typed = @([regex]::Matches($s, 'git rev-parse v\d+\.\d+\.\d+') | ForEach-Object { $_.Value })
    L "(l3) INSTALL.md's clone section, $($s.Length) chars: missing $($miss.Count)$(if ($miss.Count) { ' -- ' + ($miss -join ', ') }); a typed version in the rev-parse form: $($typed.Count)"
    Check "(l3) INSTALL.md's clone section: the tag is annotated, ls-remote lists the tag object, clone --branch warns 'is not a commit!', the form git rev-parse v<VERSION>^{commit}, source_commit named; no typed version" (($s.Length -gt 0) -and ($miss.Count -eq 0) -and ($typed.Count -eq 0))
}
'l4' {
    # F-L4 (RELEASE-4 S3; row 495 (3)): README's OWNERSHIP AND CONTRIBUTIONS. A section of that name: owned and maintained by
    # tekWeaver Solutions Inc.; no external contributions; issues off on the public repository; support for paying customers
    # by contact.
    $t = ([System.IO.File]::ReadAllText((Join-Path $Repo 'README.md'))) -replace "`r`n", "`n"
    $sec = [regex]::Match($t, '(?ms)^## Ownership and contributions[ \t]*\n(.*?)(?=^## |\z)')
    $s = ($sec.Groups[1].Value -replace '\s+', ' ')
    $need = @('owned and maintained by tekWeaver Solutions Inc.', 'no external contributions', 'issues', 'turned off', 'https://github.com/tekweaver-solutions/vanguard-collective-releases', 'paying customers', 'support@tekweaver.ca')
    $miss = @($need | Where-Object { -not $s.Contains($_) })
    L "(l4) README's 'Ownership and contributions': $(if ($sec.Success) { 'present' } else { 'ABSENT' }); missing $($miss.Count)$(if ($miss.Count) { ' -- ' + ($miss -join ' | ') })"
    Check "(l4) README carries 'Ownership and contributions': owned and maintained by tekWeaver Solutions Inc., no external contributions, issues turned off on the public repository, support for paying customers by contact" ($sec.Success -and ($miss.Count -eq 0))
}
'l5' {
    # F-L5 (RELEASE-4 S3; row 495 (3)): AN UPGRADED PROJECT's 0.x SMOKE MISSION. INSTALL.md's section 6 says the smoke mission
    # 0.x built beside the project is renamed aside -- lam-smoke.old, lam-smoke-origin.git.old -- and a current one built
    # beside the project by the installed builder, the acceptance wrapper then reading the new one.
    $t = ([System.IO.File]::ReadAllText((Join-Path $Repo 'INSTALL.md'))) -replace "`r`n", "`n"
    $sec = ([regex]::Match($t, '(?ms)^## 6\. Upgrade a project an earlier release installed\n(.*?)(?=^## )')).Groups[1].Value
    $s = $sec -replace '\s+', ' '
    $need = @('0.x', 'lam-smoke.old', 'lam-smoke-origin.git.old', 'tools\lam\build-smoke-mission.ps1', 'instrument-acceptance.ps1')
    $miss = @($need | Where-Object { -not $s.Contains($_) })
    L "(l5) INSTALL.md section 6, $($s.Length) chars: missing $($miss.Count)$(if ($miss.Count) { ' -- ' + ($miss -join ', ') })"
    Check "(l5) INSTALL.md section 6 says what an upgrade does with a 0.x smoke mission: renamed aside to lam-smoke.old and lam-smoke-origin.git.old, a current one built by tools\lam\build-smoke-mission.ps1, read by the acceptance wrapper" (($s.Length -gt 0) -and ($miss.Count -eq 0))
}
'l8' {
    # F-L8 (RELEASE-4 S3; row 495 (13)): THE ADR NAMESPACE COLLISION, IN docs/framework ONLY. The local-modes family mints
    # its decisions as ADR-0NN and has artifacts cite them as LM2-ADR-0NN; a bare ADR-0NN is the on-disk file
    # tools/mission-cli/config/adr-0NN-*.md (v2.2 and v2.3, 'Naming'). The v2.4 DELTA minted ADR-036..ADR-040 bare, and the
    # on-disk series holds an adr-040 of its own: the collision. Held here: (1) the DELTA states the convention where it
    # first uses the namespaces (before its first citation), naming LM2-ADR-0NN, the on-disk folder and the adr-040
    # collision; (2) the DELTA holds no bare ADR-0NN citation; (3) no file under docs/framework cites ADR-036..ADR-040 bare
    # (the DELTA's five, the collision's series), nor ADR-045 bare outside the family documents that mint it in their own
    # namespace (v2.3). UI-2 S1c (register row 523): mission-event.schema.json's ADR-045 is qualified (LM2-ADR-045) and WP-7
    # U-17 re-pinned, so no file is listed aside any more; and a dispatch's "## AUTHORITY" section, which quotes its sources
    # as they read, is read apart -- a bare citation there is a quotation, and the file says beside it which decision it is.
    $fw = @((RunGit $Repo @('-c', 'core.quotePath=false', 'ls-files', '--', 'docs/framework')).out | Where-Object { $_ })
    $bare = '(?<![-A-Za-z0-9])ADR-0(\d\d)(?![0-9])'
    $delta = 'docs/framework/vanguard-collective-local-modes-v2.4-DELTA.md'
    $dt = ([System.IO.File]::ReadAllText((Join-Path $Repo ($delta -replace '/', '\')))) -replace "`r`n", "`n"
    $conv = [regex]::Match($dt, '(?s)\*\*Naming\.\*\*(.*?)\n\n')
    $firstCite = [regex]::Match($dt, '(?<![A-Za-z0-9])(LM2-)?ADR-0\d\d')
    $cv = ($conv.Groups[1].Value -replace '\s+', ' ')
    $convOk = $conv.Success -and $firstCite.Success -and ($conv.Index -lt $firstCite.Index) -and $cv.Contains('LM2-ADR-0NN') -and $cv.Contains('tools/mission-cli/config') -and $cv.Contains('adr-040')
    L "(l8) the DELTA's convention paragraph: $(if ($conv.Success) { 'at char ' + $conv.Index } else { 'ABSENT' }); its first citation at char $($firstCite.Index); names LM2-ADR-0NN, tools/mission-cli/config and adr-040: $convOk"
    Check "(l8) the v2.4 DELTA states the citation convention (LM2-ADR-0NN; bare ADR-0NN is the on-disk tools/mission-cli/config file; the adr-040 collision) before its first citation" $convOk
    $dBare = @([regex]::Matches($dt, $bare) | ForEach-Object { $_.Value })
    L "(l8) bare ADR-0NN citations in the DELTA: $($dBare.Count)$(if ($dBare.Count) { ' -- ' + (($dBare | Group-Object | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', ') })"
    Check "(l8) the v2.4 DELTA cites every decision explicitly: 0 bare ADR-0NN" ($dBare.Count -eq 0)
    $mint = @('docs/framework/vanguard-collective-local-modes-v2.3.md')
    $pinned = @()
    # A "## AUTHORITY" section, from its heading to the next "## " heading, read apart (row 523): its lines are blanked here.
    function NoAuthority { param([string]$Text)
        $out = New-Object System.Collections.Generic.List[string]; $in = $false
        foreach ($ln in $Text.Split([char]10)) {
            if ($ln -match '^## ') { $in = ($ln -match '^## AUTHORITY\b') }
            if ($in) { $out.Add('') } else { $out.Add($ln) }
        }
        return ($out -join "`n")
    }
    $hits = New-Object System.Collections.Generic.List[string]; $known = New-Object System.Collections.Generic.List[string]
    foreach ($p in $fw) {
        $fp = Join-Path $Repo ($p -replace '/', '\'); if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { continue }
        $b = [System.IO.File]::ReadAllBytes($fp); if (IsBinary $b) { continue }
        $ls = (NoAuthority $NoBom.GetString($b)).Split([char]10)
        for ($i = 0; $i -lt $ls.Count; $i++) {
            foreach ($m in [regex]::Matches($ls[$i], $bare)) {
                $n = [int]$m.Groups[1].Value
                $series = ($n -ge 36 -and $n -le 40)
                $dash = ($n -eq 45) -and ($mint -notcontains $p)
                if (-not ($series -or $dash)) { continue }
                if ($pinned -contains $p) { $known.Add("${p}:$($i + 1) $($m.Value)"); continue }
                $hits.Add("${p}:$($i + 1) $($m.Value)")
            }
        }
    }
    L "(l8) bare ADR-036..ADR-040 anywhere, and bare ADR-045 outside v2.3, under docs/framework ($($fw.Count) file(s)): $($hits.Count)$(if ($hits.Count) { ' -- ' + ($hits -join '; ') }); KNOWN, not cured (bytes pinned by WP-7 U-17): $($known -join '; ')"
    Check "(l8) docs/framework cites the DELTA's five and ADR-045 explicitly: 0 bare ADR-036..ADR-040 and 0 bare ADR-045 outside v2.3, the schema included" (($hits.Count -eq 0) -and ($known.Count -eq 0))
    # (RELEASE-4 S3 validator round 1, claim 6) THE COUNT THE FACE ALLOWS, outside the family documents that mint the namespace
    # (v2.1, v2.2, v2.3): the bare ADR-0NN citations under docs/framework are EXACTLY a pinned list -- per file, the ordered sequence of
    # numbers (validator round 2: a count ceiling let a swapped or a dropped citation through). The design brief, the user guide and the
    # DELTA hold none. The KNOWN files: expanded-schemas.md, expanded-schemas-project.md and evidence-manifest.schema.json cite on-disk
    # decisions under their own convention (bare = the tools/mission-cli/config file: adr-032, adr-023, adr-012, adr-003) -- correct,
    # nothing to cure. UI-2 S1c (register row 523) cured the rest: mission-event.schema.json's 045 now LM2-ADR-045 (U-17 re-pinned),
    # v35-08-FINDINGS-delta-pass.md's four (22 33 23 35) now LM2-, and build-dispatch-mission-verify.md's 22 is a quotation inside its
    # "## AUTHORITY" section, read apart, with LM2-ADR-022 named beside it. Any other bare citation outside an AUTHORITY section, one
    # more, one fewer or one changed, FAILS.
    $family = @('docs/framework/vanguard-collective-local-modes-v2.1.md', 'docs/framework/vanguard-collective-local-modes-v2.2.md', 'docs/framework/vanguard-collective-local-modes-v2.3.md')
    $known = @{ 'docs/framework/expanded-schemas.md' = '32 32 23 32 32 32 32 23 32 32 12 32 32 32 32'
                'docs/framework/expanded-schemas-project.md' = '32 32 23 32 32 32 32 23 32 32 12 32 32 32 32'
                'docs/framework/evidence-manifest.schema.json' = '03' }
    $per = @{}
    foreach ($p in $fw) {
        if ($family -contains $p) { continue }
        $fp = Join-Path $Repo ($p -replace '/', '\'); if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) { continue }
        $b = [System.IO.File]::ReadAllBytes($fp); if (IsBinary $b) { continue }
        $sq = (@([regex]::Matches((NoAuthority $NoBom.GetString($b)), $bare) | ForEach-Object { $_.Groups[1].Value })) -join ' '; if ($sq) { $per[$p] = $sq }
    }
    $off = @(@($per.Keys) + @($known.Keys) | Select-Object -Unique | Where-Object { [string]$per[$_] -cne [string]$known[$_] } | ForEach-Object { "$_ is '$($per[$_])', pinned '$($known[$_])'" })
    L "(l8) bare ADR-0NN outside v2.1-v2.3, per file (ordered numbers): $((@($per.Keys | Sort-Object | ForEach-Object { "$_ [$($per[$_])]" })) -join '; '); off the pinned list: $($off.Count)$(if ($off.Count) { ' -- ' + ($off -join '; ') })"
    Check "(l8) outside the family documents and AUTHORITY sections the bare ADR-0NN citations are exactly the pinned list, per file and in order (the three files citing on-disk decisions under their own convention, and nothing else); none in the design brief, the user guide, the DELTA, the schema or the delta pass" ($off.Count -eq 0)
}
'enc' {
    # F-ENC (RELEASE-4 S3): EVERY TRACKED MARKDOWN FILE AND LICENSE IS UTF-8 WITHOUT A BOM, WITH NO MOJIBAKE AND NO
    # WHITESPACE-ONLY LINE. -Repo's working files: each read as strict UTF-8 (an invalid sequence is a FAIL), no EF BB BF,
    # none of the sequences a UTF-8 text read as Windows-1252 leaves (C3 82 C2 A7 for a section sign, C3 A2 E2 82 AC for the
    # dashes and quotes, C3 83 C2 A9 for e-acute: built from code points here), and no line holding only spaces or tabs
    # (its line ending aside). UI-2 S1c (register row 523) cured the one file listed aside before, expanded-schemas-base.md
    # (125 whitespace-only lines emptied, its two sha256-prefix citations re-derived to 3fe8439a): no file is exempt now.
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    $moj = @(([string][char]0xC2 + [char]0xA7), ([string][char]0xE2 + [char]0x20AC), ([string][char]0xC3 + [char]0xA9))
    $cited = @()
    $files = @((RunGit $Repo @('-c', 'core.quotePath=false', 'ls-files')).out | Where-Object { $_ -and ($_ -match '\.md$' -or $_ -ceq 'LICENSE') })
    $bad = New-Object System.Collections.Generic.List[string]; $known = 0
    foreach ($p in $files) {
        $b = [System.IO.File]::ReadAllBytes((Join-Path $Repo ($p -replace '/', '\')))
        if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $bad.Add("$p BOM") }
        $t = $null; try { $t = $strict.GetString($b) } catch { $bad.Add("$p not UTF-8"); continue }
        $ls = $t.Split([char]10)
        for ($i = 0; $i -lt $ls.Count; $i++) {
            $l = $ls[$i].TrimEnd([char]13)
            foreach ($m in $moj) { if ($l.Contains($m)) { $bad.Add("${p}:$($i + 1) mojibake") } }
            if ($l.Length -gt 0 -and $l -match '^[ \t]+$') { if ($cited -contains $p) { $known++ } else { $bad.Add("${p}:$($i + 1) whitespace-only") } }
        }
    }
    $byFile = @($bad | ForEach-Object { ($_ -split '[: ]')[0] } | Group-Object | ForEach-Object { "$($_.Name) $($_.Count)" })
    L "(enc) $($files.Count) tracked *.md and LICENSE: $($bad.Count) finding(s)$(if ($bad.Count) { ' -- by file: ' + ($byFile -join ', ') + '; first: ' + ((@($bad) | Select-Object -First 5) -join '; ') }); KNOWN, not cured: $($cited -join ', ') $known whitespace-only line(s) (its bytes cited by sha256 prefix)"
    Check "(enc) every tracked *.md and LICENSE: UTF-8, no BOM, no mojibake sequence, no whitespace-only line ($($files.Count) file(s); the cited base document aside, listed)" ($bad.Count -eq 0)
}
'rg1' {
    # UI-2 S1 A-5 (register row 526): an upgrade rewrites the target's registry row's framework_version to the version it
    # installs -- that value only, every other byte of the registry kept -- and -WhatIf announces it; a target not yet
    # registered is not registered by the upgrade; a registry the installer cannot write leaves the row as it was, and the
    # installer exits non-zero naming the registry. Two synthetic releases built from this checkout's set and HEAD's
    # installer (1.2.1, then 1.2.2); a scratch VANGUARD_HOME, saved and put back.
    $vgPrev = $env:VANGUARD_HOME
    $vh = Join-Path $Work 'vghome'; $env:VANGUARD_HOME = $vh
    try {
        $srcA = New-Source -Dir (Join-Path $Work 'src-a') -Version '1.2.1' -From $Repo -Set $owned -Installer $installer
        $srcB = New-Source -Dir (Join-Path $Work 'src-b') -Version '1.2.2' -From $Repo -Set $owned -Installer $installer
        $mkT = { param([string]$Name, [bool]$Feed)
            $t = Join-Path $Work $Name
            WriteBytes (Join-Path $t '.mission\mission.yaml') (Bytes "id: m-$Name`n")
            if ($Feed) { $null = New-Item -ItemType Directory -Force -Path (Join-Path $t '.mission-runtime\telemetry') }
            return $t }
        $reg = Join-Path $vh 'projects.yaml'
        $rowOf = { param([string]$T)
            if (-not (Test-Path -LiteralPath $reg)) { return $null }
            $txt = [System.IO.File]::ReadAllText($reg)
            $full = [System.IO.Path]::GetFullPath($T).TrimEnd('\')
            foreach ($blk in ([regex]::Split($txt, '(?m)^(?=- )'))) {
                $m = [regex]::Match($blk, "(?m)^\s*(?:-\s+)?checkout_path:\s*'((?:[^']|'')*)'\s*\r?$")
                if ($m.Success -and [string]::Equals(($m.Groups[1].Value -replace "''", "'").TrimEnd('\'), $full, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $v = [regex]::Match($blk, "(?m)^\s+framework_version:[ \t]*'?([^'\r\n]*)'?\s*\r?$")
                    return [pscustomobject]@{ block = $blk; version = $(if ($v.Success) { $v.Groups[1].Value } else { $null }) } }
            }
            return $null }
        # (1) a registered target at 1.2.1, then the upgrade to 1.2.2
        $t = & $mkT 'rg1-t' $true
        $r = Run $srcA.installer @('-Target', $t)
        $row0 = & $rowOf $t
        L "(rg1) fresh install of 1.2.1: exit $($r.code); its registry row framework_version '$(if ($row0) { $row0.version })'"
        Check "(rg1) a fresh 1.2.1 install into a target carrying a mission and the feed's folder registers it at '1.2.1'" (($r.code -eq 0) -and $row0 -and ($row0.version -ceq '1.2.1'))
        # a second row, another checkout's, which the upgrade must not touch
        $other = "- host_id: 00000000-0000-4000-8000-0000000000aa`n  checkout_path: 'C:\work\another-checkout'`n  mission_id: 'm-other'`n  registered_at: '2026-11-01T00:00:00.000Z'`n  framework_version: '1.1.0'`n"
        [System.IO.File]::AppendAllText($reg, $other, $NoBom)
        $reg0 = [System.IO.File]::ReadAllBytes($reg)
        $w = Run $srcB.installer @('-Target', $t, '-WhatIf')
        $wl = @($w.out | Where-Object { $_ -match '^install\.ps1: planned host registration: ' })
        L "(rg1) -WhatIf of the upgrade to 1.2.2: exit $($w.code); $(if ($wl.Count) { $wl[0] } else { '(no planned host registration line)' })"
        $wantW = "the target's row in $reg would be rewritten: framework_version '1.2.1' -> '1.2.2' (its other fields kept)"
        Check "(rg1) -WhatIf announces the registry rewrite as a planned act ('$wantW') and writes no registry byte" (($w.code -eq 0) -and ($wl.Count -eq 1) -and $wl[0].EndsWith($wantW) -and ((Sha ([System.IO.File]::ReadAllBytes($reg))) -ceq (Sha $reg0)))
        $u = Run $srcB.installer @('-Target', $t)
        $ul = @($u.out | Where-Object { $_ -match '^install\.ps1: host registration: ' })
        L "(rg1) the upgrade to 1.2.2: exit $($u.code); $(if ($ul.Count) { $ul[0] } else { '(no host registration line)' })"
        $row1 = & $rowOf $t
        $reg1 = [System.IO.File]::ReadAllBytes($reg)
        $expect = $NoBom.GetString($reg0).Replace(($row0.block), ($row0.block -replace "(?m)^(\s+framework_version:[ \t]*)'1\.2\.1'", "`${1}'1.2.2'"))
        Check "(rg1) after the upgrade the row reads framework_version '1.2.2' (the lock's version), and the host registration line says the rewrite" (($u.code -eq 0) -and $row1 -and ($row1.version -ceq '1.2.2') -and ($ul.Count -eq 1) -and $ul[0].Contains("framework_version '1.2.1' rewritten to '1.2.2'"))
        Check "(rg1) every other byte of the registry is kept: the file equals its prior bytes with that one value changed (the other checkout's row included)" ((Sha $reg1) -ceq (Sha ($NoBom.GetBytes($expect))))
        $lk = ReadLock $t
        Check "(rg1) the lock reads version 1.2.2, the row's version" ($lk.header.version -ceq $row1.version)
        # (2) a target not yet registered (a mission, no feed folder): the upgrade registers nothing
        $t2 = & $mkT 'rg1-u' $false
        $null = Run $srcA.installer @('-Target', $t2)
        $before2 = Sha ([System.IO.File]::ReadAllBytes($reg))
        $u2 = Run $srcB.installer @('-Target', $t2)
        Check "(rg1) a target not yet registered is not registered by the upgrade: no row for it, the registry's bytes unchanged" (($u2.code -eq 0) -and ($null -eq (& $rowOf $t2)) -and ((Sha ([System.IO.File]::ReadAllBytes($reg))) -ceq $before2))
        # (3) PLANTED: the registry read-only -- the row stays, the installer exits non-zero naming the registry
        $t3 = & $mkT 'rg1-ro' $true
        $null = Run $srcA.installer @('-Target', $t3)
        $ro0 = [System.IO.File]::ReadAllBytes($reg)
        (Get-Item -LiteralPath $reg).IsReadOnly = $true
        try { $u3 = Run $srcB.installer @('-Target', $t3) } finally { (Get-Item -LiteralPath $reg).IsReadOnly = $false }
        $named = @($u3.out | Where-Object { $_.Contains($reg) -and $_ -match 'NOT (updated|rewritten)' })
        L "(rg1) the upgrade with the registry read-only: exit $($u3.code); $(if ($named.Count) { $named[0] } else { '(no line naming the registry)' })"
        Check "(rg1) PLANTED read-only registry: the row is unchanged ('1.2.1'), the registry's bytes unchanged, and the installer exits non-zero naming $reg" (
            ($u3.code -ne 0) -and ($named.Count -ge 1) -and ((& $rowOf $t3).version -ceq '1.2.1') -and ((Sha ([System.IO.File]::ReadAllBytes($reg))) -ceq (Sha $ro0)))
    } finally { $env:VANGUARD_HOME = $vgPrev }
}
'kv1' {
    # UI-2 S1 A-8 (register row 518): -Verify over a KEPT file the project later made byte-equal to its upstream. HEAD's
    # installer installs into a target that already holds its own .claude/settings.json, which a fresh install keeps (the
    # lock row: sha256 the project's bytes, disposition kept, upstream_sha256 the release's). The project then copies the
    # release's file over its own -- the NOTICE block added -- and -Verify must say 'kept, now equal to upstream', count
    # no difference and exit 0, the lock unchanged; with one byte changed, 'kept, differs from upstream' and exit 3.
    $t = Join-Path $Work 't'
    $set = '.claude/settings.json'
    WriteBytes (Join-Path $t ($set -replace '/', '\')) (Bytes "{`n  `"hooks`": {}`n}`n")
    $r = Run $installer @('-Target', $t)
    $lk0 = ReadLock $t
    $row0 = @($lk0.rows | Where-Object { $_.path -ceq $set })
    Check "(kv1) a fresh install over the project's own $set keeps it: exit 0, its lock row kept, sha256 the project's, upstream_sha256 the release's" (
        ($r.code -eq 0) -and ($row0.Count -eq 1) -and ($row0[0].disposition -ceq 'kept') -and ($row0[0].sha256 -ceq (FoldSha ([System.IO.File]::ReadAllBytes((Join-Path $t ($set -replace '/', '\')))))) -and ($row0[0].upstream_sha256 -ceq $srcFold[$set]))
    # the project makes its copy the release's file
    WriteBytes (Join-Path $t ($set -replace '/', '\')) ([System.IO.File]::ReadAllBytes((Join-Path $Tagged.root ($set -replace '/', '\'))))
    $lockBefore = FileSha (Join-Path $t 'framework.lock')
    $v = Run $installer @('-Target', $t, '-Verify')
    L "(kv1) -Verify over the kept file now equal to upstream: exit $($v.code)"; $v.out | ForEach-Object { L "  | $_" }
    $kl = @($v.out | Where-Object { $_ -match ('^install\.ps1:   KEPT\s+' + [regex]::Escape($set) + '  -- kept, now equal to upstream') })
    Check "(kv1) -Verify reports $set 'kept, now equal to upstream', counts 0 differences and exits 0" (($v.code -eq 0) -and ($kl.Count -eq 1) -and ((Count $v.out ('^install\.ps1: verify: \d+ file\(s\) listed, 0 difference\(s\); ')) -eq 1) -and ((Count $v.out '^install\.ps1:   CHANGED ') -eq 0))
    Check "(kv1) -Verify is a read: the lock's bytes, its row for $set included, unchanged" ((FileSha (Join-Path $t 'framework.lock')) -ceq $lockBefore)
    # PLANTED: one byte of the kept file changed -- neither its lock bytes nor upstream
    $b = [System.IO.File]::ReadAllBytes((Join-Path $t ($set -replace '/', '\'))); $b[1] = [byte](($b[1] -bxor 0x20)); WriteBytes (Join-Path $t ($set -replace '/', '\')) $b
    $v2 = Run $installer @('-Target', $t, '-Verify')
    L "(kv1) -Verify with one byte of it changed: exit $($v2.code)"; $v2.out | Where-Object { $_ -match 'CHANGED|KEPT|verify: \d' } | ForEach-Object { L "  | $_" }
    Check "(kv1) PLANTED one byte changed: CHANGED $set -- 'kept, differs from upstream', 1 difference, exit 3" (($v2.code -eq 3) -and ((Count $v2.out ('^install\.ps1:   CHANGED\s+' + [regex]::Escape($set) + '  lock=\S+ now=\S+  -- kept, differs from upstream')) -eq 1) -and ((Count $v2.out ('^install\.ps1: verify: \d+ file\(s\) listed, 1 difference\(s\); ')) -eq 1))
}
'kv2' {
    # UI-2 S1 A-9 (register row 518): INSTALL.md's Upgrading section (section 6) and the 1.3.0 release notes name the step
    # after the NOTICE block is added: run -Verify, and expect 'kept, now equal to upstream' for the file.
    foreach ($doc in @('INSTALL.md', 'docs/RELEASE-NOTES-v1.3.0.md')) {
        $p = Join-Path $Repo ($doc -replace '/', '\')
        $txt = if (Test-Path -LiteralPath $p -PathType Leaf) { [System.IO.File]::ReadAllText($p) } else { '' }
        if ($doc -ceq 'INSTALL.md') {
            $m = [regex]::Match($txt, '(?ms)^## 6\. .*?(?=^## 7\. )'); $txt = if ($m.Success) { $m.Value } else { '' }
        }
        $hasStep = $txt.Contains('-Verify') -and $txt.Contains('kept, now equal to upstream') -and $txt.Contains('NOTICE')
        L "(kv2) $doc$(if ($doc -ceq 'INSTALL.md') { ' section 6' }): $(if ($txt) { "$($txt.Length) chars" } else { 'absent' }); names -Verify, the NOTICE block and 'kept, now equal to upstream': $hasStep"
        Check "(kv2) $doc names the step after the NOTICE block is added: run -Verify, expect 'kept, now equal to upstream'" $hasStep
    }
}
}
} catch {
    Check "the case ran to its end without an exception: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" $false
} finally {
    if (-not $Keep) { try { Remove-Tree $Work } catch { L "WARNING: the work folder could not be removed: $($_.Exception.Message)" } }
}
$fails = @($verdicts | Where-Object { $_ -like 'FAIL*' }).Count
L "RESULT ($Case): $($verdicts.Count) check(s), $fails failed$(if (-not $Keep) { "; $Work removed: $(-not (Test-Path -LiteralPath $Work))" })"
$tx = Join-Path $Out "falsifier-$Case.txt"
[System.IO.File]::WriteAllText($tx, (($log -join "`n") + "`n"), $NoBom)
L "transcript $tx sha256 $(FileSha $tx)"
if ($fails -gt 0) { exit 1 }
exit 0
