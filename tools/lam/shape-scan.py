#!/usr/bin/env python3
"""
SHAPE SCAN -- a lint for the defect shapes this build actually shipped. NOT A GATE.

Ratified as a tracked tool by operator ruling C (V-1 round 20, the completion ruling): run it as a
pre-commit aid; read every hit; expect most to be fine. Its value is that it puts the shapes in front
of a reader in the place where the eye has already stopped looking. A hit is a place to look, never
a verdict, and a clean run is not an all-clear.

EVERY SHAPE BELOW WAS EXTRACTED FROM A DEFECT THAT SHIPPED IN THIS BUILD, with the round that found
it. It is not a generic lint list.

  S1  A GUARD CLAUSE THAT SKIPS THE CHECK (round 14).
      `if ($expected -and ($a -cne $expected))` -- when $expected is null the comparison is SKIPPED,
      not failed. Shipped in the cure for the substituted-decider defect and driven to installed:true
      over an allow-everything script.

  S2  CASE-FOLDING COMPARISON ON A CASE-SIGNIFICANT VALUE (round 13).
      PowerShell's -eq/-ne fold case. Shipped twice in one function: a gate declaring .../o.git
      authorised .../O.git, and refs/heads/main authorised refs/heads/MAIN.

  S3  FIRST-OF-A-CLASS (rounds 2, 12, 14).
      `$authorized[0]`, "the first 40-hex", "the first status-shaped line". Three separate defects,
      each publishing or authorising something the code had already enumerated and then discarded.

  S4  A FIELD WRITTEN AND NEVER READ (round 12).
      `remote_sha_before`, `written_at` -- a persisted field is a claim about a check that happens.
      Cross-file: every snake_case key assigned in the scanned set and read nowhere in it.

  S6  ARRAY-TO-STRING COERCION (round 1, WP-6 S-4).
      `"$o"` where $o is git's output ARRAY joins with $OFS -- a space. S-4 parsed zero refs on every
      multi-line remote and reported the absence as compliance.

  S7  A PATH RESOLVED AGAINST THE WRONG CONTEXT (rounds 6, 8, 15; the most repeated shape).
      `git ls-remote <url>` with no `-C`; `Test-Path` in a checker resolving against the checker's cwd
      while git resolves the same string against the repository; `WriteAllText('.git/hooks/...')`
      resolving against the .NET process directory. The question of every path: WHO resolves it, and
      is it the same one who will use it?

  S5 is DOCUMENTED AND NOT SCANNED, stated so nobody infers coverage: a keyed map whose keys fold
  case (`@{}` holding git refs, round 13). No mechanical pattern distinguishes such a hashtable from
  an ordinary one, so it is a reading, not a scan. Six shapes are scanned.

  S5 SHIPPED A SECOND TIME AND WAS FOUND BY READING, WHICH IS THE POINT OF SAYING IT IS UNSCANNED
  (V-1 round 2, a review finding; cured under an operator ruling). `lam-gate-class.ps1`'s
  `$script:LamGateClassByKind` is an `[ordered]@{}` -- an OrderedDictionary, whose `.Contains()`
  FOLDS CASE -- so `approve -Kind PUSH` was classified and minted, and eleven consumers inherited
  that answer. THE CURE WAS NOT A SCAN AND COULD NOT HAVE BEEN: the map gained a named ordinal
  predicate, `Resolve-LamGateKind`, so the rule became something a caller can ASK rather than
  something a comparer silently decides. What the scanner gained instead is `kind` in the S2
  vocabulary below, which catches the CONSUMERS of such a map -- the folding `-eq`/`-ne` on a
  kind-shaped value -- even though it still cannot see the map itself.

USAGE
  python tools/lam/shape-scan.py            scan the default target set (delivered machinery)
  python tools/lam/shape-scan.py PATH...    scan the given .ps1 files instead

Exit code is always 0. A lint that fails a commit becomes a gate, and a gate whose every hit needs a
human reading is a gate that gets bypassed; the ruling says lint, and this stays one.
"""
import io, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_TARGETS = [
    os.path.join("tools", "evidence-hooks-next", "hooks", "lib", "evidence-common.ps1"),
    os.path.join("tools", "evidence-hooks-next", "hooks", "evidence-pre-push.ps1"),
    os.path.join("tools", "evidence-hooks-next", "hooks", "check-prepush-installed.ps1"),
    os.path.join("tools", "evidence-hooks-next", "hooks", "evidence-post-tool-use.ps1"),
    os.path.join("tools", "lam", "mission-goal-check.ps1"),
    os.path.join("tools", "lam", "mission-gate.ps1"),
    os.path.join("tools", "lam", "mission-dispatch.ps1"),
    os.path.join("tools", "lam", "lam-gate-class.ps1"),
]

# Values whose case is SIGNIFICANT in this domain: refs, urls, paths -- and GATE KINDS, added by
# an operator ruling after V-1 round 2's review finding. Shas are hex and fold safely.
#
# `kind` MATCHES MORE THAN GATE KINDS, AND THAT IS MEASURED RATHER THAN HIDDEN. Four runs over the
# default target set, which separate the vocabulary change from the cure that came with it:
#   old vocabulary / pre-cure sources  70 hits
#   NEW vocabulary / pre-cure sources  91 hits   (+21: the vocabulary's whole effect)
#   old vocabulary / cured sources     70 hits   (the cure adds NO hit the old vocabulary can see)
#   NEW vocabulary / cured sources     88 hits   (+18 net)
# OF THE 21: FOUR are the defect this ruling cures -- mission-gate.ps1's revoke, settle-scope,
# settle and reapprove comparisons, which are `-cne` now and no longer hit, which is why the net is
# 18 and not 21. ELEVEN more are mission-gate.ps1's `$Kind -eq '<canonical literal>'` mint branches:
# in-domain, and harmless today only because :1580 refuses a non-canonical kind before any of them
# is reached -- exactly the kind of place this lint exists to put in front of a reader. The
# remaining SIX are out of domain: `$armKind -eq 'transcript'` (evidence-common.ps1, x2) and
# `$roleKind -eq 'validator'` (mission-dispatch.ps1, x4). The cure itself then adds ONE more, the
# deliberate folding `-eq` inside Get-LamGateKindRefusalReason's caller at mission-gate.ps1, which
# DIAGNOSES a near miss after the ordinal decision has already been taken and says so in place.
# A NARROWER SPELLING WAS CONSIDERED AND NOT SHIPPED: requiring a canonical GATE-KIND LITERAL on the
# line, or a bare `$Kind`, would drop exactly those six and keep everything else. It is not shipped
# because this file's own contract is that "a hit is a place to look, never a verdict", and six
# readings is not a flood -- but the narrower rule is recorded here so the trade is a decision
# rather than an omission.
CASEY = re.compile(r"\$\w*(ref|url|origin|path|name|kind)\w*", re.I)


def scan(path):
    hits = []
    lines = io.open(path, "r", encoding="utf-8", newline="").read().split("\n")
    for i, ln in enumerate(lines, 1):
        code = ln.split("#", 1)[0]          # comments in this codebase are long and full of examples
        if not code.strip():
            continue

        # S1: a comparison guarded by the truthiness of one of its own operands.
        m = re.search(r"if\s*\(\s*\$(\w+)\s+-and\s*\(.*-c?(ne|eq)\s", code)
        if m and m.group(1).lower() not in ("true", "false"):
            hits.append((i, "S1", "comparison guarded by its own operand -- null SKIPS the check", ln.strip()))

        # S2: case-folding -eq/-ne on a ref/url/path-shaped variable.
        if re.search(r"\s-(ne|eq)\s", code) and CASEY.search(code):
            if not re.search(r"\s-c(ne|eq)\s", code):
                hits.append((i, "S2", "-ne/-eq FOLD CASE; this compares a ref/url/path", ln.strip()))

        # S3: indexing [0] out of a plural-looking collection.
        m = re.search(r"\$(\w*(?:s|List|Lines|Refs|Entries))\[0\]", code)
        if m:
            hits.append((i, "S3", "first-of-a-class: [0] out of a collection", ln.strip()))

        # S7: a path test or write with no root in sight; git invoked with no -C.
        if re.search(r"(Test-Path|WriteAllText|ReadAllBytes|ReadAllText)\s*\(?\s*-?L?i?t?e?r?a?l?P?a?t?h?\s*\$?\w*(points|declared|url|target|dest)\w*", code, re.I):
            if "-Root" not in code and "GetFullPath" not in code and "Join-Path" not in code:
                hits.append((i, "S7", "path used without a stated root -- WHO resolves it?", ln.strip()))
        if re.search(r"&\s*git\s+(ls-remote|rev-parse|show)", code) and "-C " not in code:
            hits.append((i, "S7", "git invoked with no -C: resolves against the CALLER's cwd", ln.strip()))

        # S6: array interpolated into a string.
        for m in re.finditer(r'"\$\(?\$?(\w+)\)?"', code):
            if re.search(r"(lines|out|refs|entries|args|results)$", m.group(1), re.I):
                hits.append((i, "S6", 'array-to-string: "$arr" joins with $OFS (a space)', ln.strip()))
    return hits


def unread_fields(targets):
    """S4, cross-file: a snake_case key assigned in a hashtable literal and never read in the set."""
    assigned, read = {}, set()
    for p in targets:
        if not os.path.exists(p):
            continue
        text = io.open(p, "r", encoding="utf-8", newline="").read()
        body = "\n".join(l.split("#", 1)[0] for l in text.split("\n"))
        for m in re.finditer(r"^\s*(\w+)\s*=\s*[^=]", body, re.M):
            assigned.setdefault(m.group(1), []).append(os.path.relpath(p, ROOT))
        for m in re.finditer(r"\.(\w+)\b", body):
            read.add(m.group(1))
        for m in re.finditer(r"-Field\s+'(\w+)'", body):
            read.add(m.group(1))
        for m in re.finditer(r"\^(\w+):", body):
            read.add(m.group(1))
    return {k: v for k, v in assigned.items() if "_" in k and k not in read}


def main(argv):
    targets = [os.path.abspath(a) for a in argv] if argv else [os.path.join(ROOT, t) for t in DEFAULT_TARGETS]
    total = 0
    for p in targets:
        if not os.path.exists(p):
            print("  (absent) %s" % os.path.relpath(p, ROOT)); continue
        hits = scan(p)
        if hits:
            print("\n=== %s ===" % os.path.relpath(p, ROOT))
            for i, code, why, ln in hits:
                print("  %-4s line %-5d %s" % (code, i, why))
                print("        %s" % ln[:150])
                total += 1
    print("\n=== S4: snake_case keys ASSIGNED but never read anywhere in the scanned set ===")
    uf = unread_fields(targets)
    if uf:
        for k, where in sorted(uf.items()):
            print("  %-28s assigned in %s" % (k, ", ".join(sorted(set(where)))))
            total += 1
    else:
        print("  (none)")
    print("\n%d shape hit(s). EVERY ONE NEEDS READING -- this is a place to look, not a verdict." % total)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
