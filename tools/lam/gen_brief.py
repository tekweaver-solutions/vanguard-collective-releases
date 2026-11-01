#!/usr/bin/env python3
"""THE HANDOFF-BRIEF GENERATOR.

BATCH-5 WP-O. A seat that hands an
arc over writes a brief, and until this file each seat wrote a generator of its own for it: a template, a script
that derived every figure of the state table and the keep-table, and the HANDOFF head's arm line. This file is that
generator, tracked. It imports no sibling: the clock and the one read below are written here and again, byte for
byte, in seat.py, and the one thing it takes from seat.py -- the census of the arc's stops -- it takes by RUNNING
seat.py from beside this file, never by rebuilding it.

THE PROSE FILE IS THE SEAT's PAGE. Its sections and its words are the seat's, the sentences of a table's rows among
them; where a figure or a table belongs it holds a token, {NAME} -- a capital letter, then capitals, digits and
underscores. THIS FILE SUPPLIES EVERY FIGURE AND EVERY BLOCK, each re-derived in the run that writes it, and derives
ONLY the tokens the prose names: a minimal brief asks git for a handful of answers and the network for none. THE
CLOCK IS TAKEN ONCE, when the run begins to derive: every stamp of the run is that one value, and the brief is
created after its figures. An unknown token, a figure that cannot be derived, a token left unfilled: REFUSED,
nothing written -- and a figure whose value is not there (a key the ledger's last line lacks, a JSON null, a key of
mission.yaml with nothing, or only a comment, on its line) is one that cannot be derived: no word is written in its
place. A VALUE THAT HOLDS A TOKEN's FORM, {NAME}, IS REFUSED: what fills the text next would read it as a token.
In a scalar figure a `|` is written `/` and a line break ` / `, so a figure cannot break the row it stands in.
Every file is read by the one short read below; one that another process holds past the five tries is REFUSED by
name, never counted as absent or as empty.

THE FIGURES, by source:
  git (reads only, optional locks off)   HEAD HEAD8 ORIGIN ORIGIN8 AHEAD STATUS TRACKED_TREE; LSREMOTE (a NETWORK
      read, made only where named); WORKTREES_N WORKTREES; UNTRACKED_DISPATCHES UNTRACKED_AMENDMENTS
  the three ledgers   ML ML_LAST ML_LAST_AT; CL CL_LAST8 CL_LAST_BY; SL SL_LAST_SEQ SL_LAST_EVENT SL_LAST_DISPATCH
      SL_LAST_BY; NFR NFR_LINE (the newest of the last eleven entries that states `next free row`; NFR_LINE is
      THE FILE's OWN LINE NUMBER of that entry, an empty line counted as the line it is; ML, CL and SL count the
      ENTRIES, and an empty line is none -- the skeleton words them `lines`, the seats' own word, and they are
      the file's lines where it holds no empty one)
  the mission and its spec   STATE COMPLETED SPEC SPEC_TXT CURSOR RUNG LAST_FEATURE LAST_FEATURE_STATUS
      LAST_MILESTONE LAST_MILESTONE_STATUS ROSTER ASSERTIONS (`none` where the last milestone binds none)
  the mirror and the derived file   MIRROR_BYTES MIRROR_SHA MIRROR_LF_SHA FLOOR XFAIL_IDS DERIVED_BYTES DERIVED_SHA
  the goal and the Stop hook   GOAL GOAL_BYTES GOAL_SHA GOAL_LF_SHA GOAL_DETECTORS HOOK_COUNT (how many times the
      settings file holds `-Goal <goal>`, BY THOSE LETTERS as the tracked file spells its hook lines -- a line
      spelled `-goal` is not counted -- the goal matched to its end) HOOK_BYTES HOOK_SHA
  operator-acts.log   LOG (the lines that hold an act: an empty line is none) ACTS_FROM TALLY TALLY_N
      TALLY_HALT_RULING TALLY_AMENDMENT_MATERIAL TALLY_DISPATCH TALLY_PUSH TALLY_RECLOSE -- counted from the line
      --acts-from names, THE FILE's OWN LINE NUMBER: THE ONE FIGURE THE CALLER SUPPLIES (the arc's first act is on
      no disk this tool reads), printed as ACTS_FROM so the cell shows its base
  the runtime plane   ADM; HALTS_RAISED HALTS_NAMES HALTS_ANSWERED HALTS_OPEN (the files HALT-<ARC>-*.md, the arc
      matched TO THE DASH after it and WITHOUT REGARD TO LETTER CASE, as the evaluator's scan of HALT-* is; a HALT
      is answered here where its ruling gate's FILE exists: no stamp of any gate is read); COPIES
  THE ARC IN SMALL LETTERS: the scratch copies ({COPIES}), the census's close folders and the copy line's
      destination are looked for under the arc's name IN SMALL LETTERS and a dash -- `arc-x-1-` for ARC-X-1, as
      the seats name them. A folder named in capitals is not met, and nothing says so: {NCOPIES} reads 0.
      TO THE DASH, AND NO FURTHER: an arc id may itself hold a dash, so an arc whose own name goes on after that
      dash -- ARC-X-1-B beside ARC-X-1 -- is taken with it, its HALT files, scratch copies and close folders among
      this arc's; the name alone cannot part them.
  the instrument captures   CAPTURE_NAME CAPTURE_BYTES CAPTURE_SHA CAPTURE_HEAD8 CAPTURE_TALLY (the goal's LIVE
      capture, by one short read, only where named: the ONE file `<goal>.*.stdout.txt` there that is no kept copy
      -- the goal matched TO THE DOT after it, and a goal id may itself hold a dot, so where this goal has no
      capture and a goal G.x has one, that one is taken; two are REFUSED); KEPT_CAPTURES (every kept copy in
      instrument-runs)
  the scratchpad   SCRATCH ROWS ROWS_BYTES EXCLUDED_FILES WHOLE
  the census (seat.py census --machine)   NCOPIES STOPS SAVED -- a finding of the census (a kept capture absent,
      differing or not opened: that stop is then out of the sum) is PRINTED by every verb as `CENSUS FINDING: ...`
      and does not move this tool's exit: the figures are the census's own, and the line is their caveat; and a
      copy the census met again and counted once -- ONE verdict's bytes are one stop, so {NCOPIES} counts distinct
      verdicts -- is PRINTED as `CENSUS: THE SAME VERDICT AGAIN, counted once: ...`
  the clock and the seam   FIRST (the stamp in the file --seated names: the seating copy's) CLOCK CLOCKMS OWN
  the command line   ARC SEAT SESSION CTX BRIEF_REL; COMPOSED_BY (this file's blob id as it stands: a
      declaration, tested by nothing -- an uncommitted copy stamps too)
THE BLOCKS: {KEEP_TABLE} the rows `| name | bytes | sha256 |` of every file under --scratch, walked recursively,
each --exclude folder left out, a nested name with a backslash, sorted by the lowercased name -- an --exclude is the
bare name of ONE top-level folder of --scratch and one that names none is REFUSED, as a walk of no file is, and as
a HIDDEN file or folder is (the operator's copy line does not carry one, and the counts would be untrue of his
copy); {COPY_LINE} and {COMPARE_LINE} the operator's two lines, an apostrophe in the scratchpad's path doubled as
his shell reads it; {STOPS_TABLE} the census's rows as seat.py renders them;
{SEAM_BASES} the one line `SEAM BASES first <stamp> end <stamp>` the successor's `seat.py head` reads its spans
from -- WHERE THE PROSE NAMES THE TOKEN, the brief holds exactly one line in that form, and it is the line this
run composed, byte for byte, or the compose is REFUSED: the token inside a sentence alone, the token twice, a
character glued to it, a second line in the form beside it. (The token named once more INSIDE a sentence, beside
the line that stands alone, composes: the successor counts whole lines, and reads the one. A prose that does NOT
name the token is not asked: a line it TYPES in that form stands as typed, and the successor reads or refuses it.)
DECLARED TOKENS (--declare FILE), the seat's own figures, one a line: `NAME = sha256 <path>`, `NAME = bytes <path>`,
`NAME = name-of-one <glob>`, `NAME = key <key> of <path>`, `NAME = absent <path>` (True or False). A path is one
FROM --root and is read under it: an absolute path, or one that leaves the root, is REFUSED. One holding * or ?
must name exactly one file -- and that file is held to the root too, by the path the system opens, so a part of the
pattern that a junction answers does not lead a read outside it; * AND ? ARE THE ONLY WILDCARDS: a [ or a ] is a
letter of a name, in the root's own path and in the declared path alike, and a name that begins with a dot is
answered only by a part of the pattern that begins with one -- and `absent` takes one exact path. Every line is held to the form; its file is looked
for and read only where a text of the run names its token.

SUBCOMMANDS
  compose --root R --arc ARC --seat N --prose FILE --ctx PCT|unknown [--goal G] [--scratch DIR [--exclude NAME]...]
          [--session ID] [--seated FILE] [--acts-from LINE] [--declare FILE] [--minimal]
          [--head-prose FILE --head-out FILE]
      (a flag in brackets is asked for only where the prose names a figure that needs it, and its absence is then
      REFUSED by the flag's name)
      Writes R/.mission-runtime/lam/HANDOFF-<ARC>-seat-<N>.md by exclusive create -- ASCII, LF only, no byte-order
      mark, one final LF -- reads it back, and prints THE ARM LINE, in the evaluator's own form where --ctx is a number:
      `HANDOFF AT <ctx>% <sha256 LF/blob>; <sha256 working> .mission-runtime/lam/HANDOFF-<ARC>-seat-<N>.md`.
      --ctx unknown -- the meter not read -- is taken as well, and the line SAYS so in its ctx slot, `HANDOFF AT
      unknown% ...`: a form the evaluator does not admit and `seat.py head --place-handoff` refuses, so a brief
      composed so composes no head file (--head-prose with it is REFUSED, before a byte is written).
      After the fill the operator's own row pattern is run over every line of EVERY brief, as his line runs it
      (without regard to letter case): the lines it finds must be the keep-table's rows, in order, once for each
      {KEEP_TABLE} placed, and no others -- none at all where no table is placed; a {COMPARE_LINE} with no
      {KEEP_TABLE} is REFUSED. --minimal is a GUARD, not a form: with it a {STOPS_TABLE} or a second {KEEP_TABLE} in
      the prose is REFUSED; without it a table placed twice composes, and the KEEP-TABLE line SAYS it is placed
      twice and what the operator's compare line will then count. With --head-prose the seat's second line -- ONE
      line -- is filled from the same figures, {CLOCKMS}, {SEAM_FROM_FIRST} and {SEAM_FROM_END} left standing for
      `seat.py head` to fill at the STATUS write, and the two lines are written by exclusive create to --head-out:
      one token for a name, not beginning HALT- once its dots are dropped, directly inside one folder of
      R/.mission-runtime/lam/close -- that folder itself, not a junction that leads elsewhere. A head prose, and
      no other text, may name {BRIEF_BYTES}, {BRIEF_SHA} and {BRIEF_LF_SHA}: the brief's own length and its working
      and LF/blob digests, as read back; none of the three can be declared.
  arm     the same flags, over a brief that already stands: the arm line, and the head file where asked. --prose
      is among them: taken and NOT READ, so that compose's own command line can be given to arm as it stands.
  facts   the same flags: every token the prose names, with its value, writing nothing.
  skeleton [--minimal] [--out FILE]
      A starting prose file of the full form or the minimal one: the token lines, no prose. It is written as
      BYTES, LF only -- to FILE by exclusive create, or to stdout, where a redirect that keeps bytes (cmd, Git Bash)
      saves a file compose takes as it is. Windows PowerShell's `>` re-encodes what a tool prints: there, --out.
      FILE is the seat's own, OUTSIDE the mission's planes: a path with a part named .mission, .mission-runtime or
      .claude -- AS SPELLED, OR AS THE SYSTEM OPENS IT, a short (8.3) name or a junction followed -- is REFUSED, as
      is a name that begins HALT- once its dots are dropped.
  stamp   Prints `composed_by: tools/lam/gen_brief.py@<8 hex>`.

REFUSALS are one column-0 line, "REFUSED: <reasons> -- nothing was written", exit 2, before a byte is written. ONE
THING IS SAID OTHERWISE: once compose's brief stands, a step that fails -- its re-read, or the head file's create --
is printed as what it is, naming the brief as standing and `arm` as the way to the head file, exit 3.
No flag carries a time. It never writes STATUS.md, the admissions record, a verdict copy, a ledger, a gate, a goal
file, or anything under --scratch, and it REFUSES an output path there -- there by the path the system opens, a
short name or a junction followed: the walk must stay true after the write.
"""
import argparse
import datetime
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time

COMPOSER_PATH = "tools/lam/gen_brief.py"
LAM_PARTS = (".mission-runtime", "lam")
TOKEN_RX = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._-]*\Z")
NAME_RX = re.compile(r"\{([A-Z][A-Z0-9_]*)\}")
STAMP_RX = re.compile(r"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z\Z")
ROW_PATTERN = r"^\| (\S.*?) \| (\d+) \| ([0-9a-f]{64}) \|$"
# The guard runs the pattern AS THE OPERATOR's LINE RUNS IT: Select-String matches without regard to letter case.
KEEP_ROW_RX = re.compile(ROW_PATTERN, re.IGNORECASE)
KEPT_NAME_RX = re.compile(r"\A(?P<stem>.+)\.(?P<sha8>[0-9a-f]{8})\.stdout\.txt\Z")
DECLARE_RX = re.compile(r"\A([A-Z][A-Z0-9_]*) = (sha256|bytes|name-of-one|absent|key (\S+) of) (.+)\Z")
SEAM_BASES_RX = re.compile(r"\ASEAM BASES first ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z) end "
                           r"([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z)\Z")
SEAM_FORM_RX = re.compile(r"\ASEAM BASES first (\S+) end (\S+)\Z")   # the form `seat.py head` counts a line by
ACT_CLASSES = ("halt-ruling", "amendment-material", "dispatch", "push", "reclose")
STANDING_TOKENS = ("CLOCKMS", "SEAM_FROM_FIRST", "SEAM_FROM_END")
BRIEF_TOKENS = ("BRIEF_BYTES", "BRIEF_SHA", "BRIEF_LF_SHA")
BLOCK_TOKENS = ("KEEP_TABLE", "STOPS_TABLE", "COPY_LINE", "COMPARE_LINE", "SEAM_BASES")
GIT_REDIRECTS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_OBJECT_DIRECTORY",
                 "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT")
HELD = ("could not be opened in five tries 200 ms apart (PermissionError: another process holds it without sharing, or "
        "it is not a file this process may open); it is not read as absent")


class Refused(Exception):
    """A refusal: its reasons, and the tail its one line ends on -- "nothing was written" unless the verb says other."""

    def __init__(self, reasons, tail=None):
        Exception.__init__(self, "; ".join(reasons))
        self.reasons = list(reasons)
        self.tail = tail


def emit(text):
    """One line on stdout, ASCII whatever the console's code page: anything else is backslash-escaped."""
    sys.stdout.write(text.encode("ascii", "backslashreplace").decode("ascii") + "\n")
    sys.stdout.flush()


def clock_now():
    """The clock at the call, UTC, YYYY-MM-DDTHH:MM:SS.mmmZ: the form of the evaluator's evaluated_at."""
    now = datetime.datetime.now(datetime.timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (now.microsecond // 1000)


def read_whole(path):
    """Every byte of one file by ONE short open: read to the end, close. An open another process refuses is tried
    five times 200 ms apart and then raised; no handle outlives the call."""
    last = None
    for attempt in range(5):
        if attempt:
            time.sleep(0.2)
        try:
            with open(path, "rb") as handle:
                return handle.read()
        except PermissionError as exc:
            last = exc
    raise last


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_named(path, what):
    """The bytes of a file that must stand, by the one read: its absence, a folder in its place and an open that is
    refused past the five tries are each REFUSED by name -- the last never read as absent."""
    if os.path.isdir(path):
        raise Refused(["a folder stands at " + path + " where the " + what + " is looked for"])
    try:
        return read_whole(path)
    except FileNotFoundError:
        raise Refused(["no " + what + " at " + path])
    except PermissionError:
        raise Refused(["the " + what + " at " + path + " " + HELD])
    except (OSError, ValueError) as exc:
        raise Refused(["the " + what + " at " + ascii(path) + " cannot be read (" + exc.__class__.__name__ + ")"])


def halt_named(name):
    """True where the evaluator's HALT scan would list a file of this name. The scan is by NAME, without regard to
    case; and on a volume that keeps 8.3 names it matches the SHORT name too, which the file system builds from the
    long one with its dots and blanks removed -- so `HA.LT-x.txt` is listed as `HALT-X~1.TXT`."""
    return re.sub(r"[ .]", "", name).upper().startswith("HALT-")


def create_whole(path, data, what):
    """ONE whole file by exclusive create. Where the write does not finish, what this call created is removed, or
    named as standing; a file already there is never written over."""
    try:
        handle = open(path, "xb")
    except FileExistsError:
        raise Refused(["a file already stands at " + path + ": " + what + " is never written over"])
    except (OSError, ValueError) as exc:
        raise Refused([what + " could not be created at " + ascii(path) + " (" + exc.__class__.__name__ + ")"])
    try:
        with handle:
            handle.write(data)
    except OSError as exc:
        try:
            os.remove(path)
            tail = "what this run created there was removed"
        except OSError:
            tail = "AND THE HALF FILE COULD NOT BE REMOVED: " + path + " STANDS"
        raise Refused([what + " could not be written whole at " + path + " (" + exc.__class__.__name__ + ")"], tail=tail)


def stamp_ms(stamp):
    """Milliseconds since the epoch of a stamp in the clock's form, or None where it is not one."""
    if not STAMP_RX.match(stamp):
        return None
    try:
        whole = datetime.datetime.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    except ValueError:
        return None
    return int(whole.timestamp()) * 1000 + int(stamp[20:23])


def span_text(from_ms, to_ms):
    """A span between two stamps AS PRINTED, in the seats' form: `2 min 29.795 s (149.795 s)`."""
    milli = to_ms - from_ms
    minutes = milli // 60000
    rest = milli - minutes * 60000
    return "%d min %d.%03d s (%d.%03d s)" % (minutes, rest // 1000, rest % 1000, milli // 1000, milli % 1000)


def lf_blob_sha256(data):
    """The evaluator's LF/blob digest (Get-PlacementLfBlobSha256): bytes git's own text test calls binary -- a NUL,
    a lone CR, more non-printable than printable >> 7 -- or bytes with no CR LF pair hash AS THEY ARE; otherwise
    every CR LF is folded to LF and the rest is hashed."""
    nul = lone_cr = crlf = printable = non_printable = 0
    index, count = 0, len(data)
    while index < count:
        byte = data[index]
        if byte == 13:
            if index + 1 < count and data[index + 1] == 10:
                crlf += 1
                index += 2
            else:
                lone_cr += 1
                index += 1
            continue
        index += 1
        if byte == 10:
            continue
        if byte == 127:
            non_printable += 1
        elif byte < 32:
            if byte in (8, 9, 27, 12):
                printable += 1
            else:
                if byte == 0:
                    nul += 1
                non_printable += 1
        else:
            printable += 1
    if count >= 1 and data[count - 1] == 26:
        non_printable -= 1
    binary = lone_cr > 0 or nul > 0 or (printable >> 7) < non_printable
    if binary or crlf == 0:
        return sha256(data)
    return sha256(data.replace(b"\r\n", b"\n"))


def blob_id(data):
    lf = data.replace(b"\r\n", b"\n")
    return hashlib.sha1(b"blob " + str(len(lf)).encode("ascii") + b"\0" + lf).hexdigest()


def text_of(data):
    """A file's text: UTF-16 where it opens on that mark, else UTF-8 with a leading mark set aside."""
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16", "replace")
    return data.decode("utf-8-sig", "replace")


def there(obj, key):
    """The value of a key AS TEXT where the object holds one; None where the key is absent or its value is JSON's
    null -- a figure that is not there is not derived, and is never written as the word `None`."""
    value = obj.get(key)
    return None if value is None else str(value)


def json_lines(data, what, numbers=None):
    """Every non-blank line of a JSON-lines file, parsed; a line that is not one JSON object is REFUSED by number.
    `numbers`, where a list is given, takes THE FILE's OWN LINE NUMBER of each line kept: an empty line is a line."""
    out = []
    for number, line in enumerate(data.split(b"\n"), start=1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line.decode("utf-8", "replace"))
        except ValueError:
            raise Refused(["line %d of %s is not JSON" % (number, what)])
        if not isinstance(obj, dict):
            raise Refused(["line %d of %s is JSON but not an object" % (number, what)])
        out.append(obj)
        if numbers is not None:
            numbers.append(number)
    return out


class Figures(object):
    """Every figure this file can derive, each group derived ONCE and only when a token of it is named."""

    def __init__(self, args, clock):
        self.args = args
        self.root = os.path.abspath(args.root)
        self.clock = clock
        self.cache = {}
        self.sources = {}
        self.notes = []
        self.keep_rows = []
        self.guarded = False
        self.placed = 0
        self.groups = [
            (("HEAD", "HEAD8", "ORIGIN", "ORIGIN8", "AHEAD", "STATUS", "TRACKED_TREE"), self.git_head,
             "git rev-parse HEAD, rev-parse origin/main, rev-list --count origin/main..HEAD, status --short --branch --untracked-files=no"),
            (("LSREMOTE",), self.git_remote, "git ls-remote origin refs/heads/main (a network read)"),
            (("WORKTREES_N", "WORKTREES"), self.git_worktrees, "git worktree list --porcelain"),
            (("UNTRACKED_DISPATCHES", "UNTRACKED_AMENDMENTS"), self.git_untracked,
             "git status --short -- .mission/dispatches, -- .mission/amendments"),
            (("ML", "ML_LAST", "ML_LAST_AT", "NFR", "NFR_LINE"), self.mission_ledger, ".mission/ledger/entries.jsonl"),
            (("CL", "CL_LAST8", "CL_LAST_BY"), self.commit_ledger, ".mission-runtime/lam/commit-ledger.jsonl"),
            (("SL", "SL_LAST_SEQ", "SL_LAST_EVENT", "SL_LAST_DISPATCH", "SL_LAST_BY"), self.spawn_ledger,
             ".mission-runtime/lam/spawn-ledger.jsonl"),
            (("STATE", "COMPLETED", "SPEC", "CURSOR", "RUNG"), self.mission, ".mission/mission.yaml"),
            (("SPEC_TXT", "LAST_FEATURE", "LAST_FEATURE_STATUS", "LAST_MILESTONE", "LAST_MILESTONE_STATUS", "ROSTER",
              "ASSERTIONS"), self.spec, ".mission/spec/current.txt, the spec it names, the roster's assertion files"),
            (("MIRROR_BYTES", "MIRROR_SHA", "MIRROR_LF_SHA", "FLOOR", "XFAIL_IDS"), self.mirror,
             ".mission/green-gate/product.json"),
            (("DERIVED_BYTES", "DERIVED_SHA"), self.derived, "tools/mission-cli/config/expected-failures.yaml"),
            (("GOAL", "GOAL_BYTES", "GOAL_SHA", "GOAL_LF_SHA", "GOAL_DETECTORS"), self.goal, "the goal file of --goal"),
            (("HOOK_COUNT", "HOOK_BYTES", "HOOK_SHA"), self.hook, ".claude/settings.local.json"),
            (("LOG", "ACTS_FROM", "TALLY", "TALLY_N", "TALLY_HALT_RULING", "TALLY_AMENDMENT_MATERIAL", "TALLY_DISPATCH",
              "TALLY_PUSH", "TALLY_RECLOSE"), self.acts, ".mission-runtime/operator-acts.log from the line --acts-from names"),
            (("ADM",), self.admissions, ".mission-runtime/lam/handoff-admissions.jsonl"),
            (("HALTS_RAISED", "HALTS_NAMES", "HALTS_ANSWERED", "HALTS_OPEN"), self.halts,
             ".mission-runtime/halts/HALT-<ARC>-*.md and whether each one's ruling gate file exists"),
            (("COPIES",), self.copies, ".mission-runtime/scratch-copies/<arc>-*"),
            (("CAPTURE_NAME", "CAPTURE_BYTES", "CAPTURE_SHA", "CAPTURE_HEAD8", "CAPTURE_TALLY"), self.capture,
             "the goal's LIVE capture under .mission-runtime/lam/instrument-runs (one short read)"),
            (("KEPT_CAPTURES",), self.kept, "every kept copy under .mission-runtime/lam/instrument-runs"),
            (("SCRATCH", "ROWS", "ROWS_BYTES", "EXCLUDED_FILES", "WHOLE", "KEEP_TABLE", "COPY_LINE", "COMPARE_LINE"),
             self.scratch, "the walk of --scratch"),
            (("NCOPIES", "STOPS", "SAVED", "STOPS_TABLE"), self.census, "seat.py census --machine, run from beside this file"),
            (("FIRST", "OWN", "SEAM_BASES"), self.seam, "the file --seated names, and the clock at the write"),
            (("CLOCK", "CLOCKMS"), self.clocks, "the clock at the write"),
            (("ARC", "SEAT", "SESSION", "CTX", "BRIEF_REL"), self.command, "the command line"),
            (("COMPOSED_BY",), self.composed, "this file's bytes, as they stand"),
        ]
        self.owner = {}
        for names, maker, source in self.groups:
            for name in names:
                self.owner[name] = (names, maker, source)

    # ---- the readers -------------------------------------------------------------------------------------------
    def path(self, *parts):
        return os.path.join(self.root, *parts)

    def file(self, what, *parts):
        return read_named(self.path(*parts), what)

    def git(self, *args):
        env = dict(os.environ)
        for name in list(env):
            if name in GIT_REDIRECTS or name.startswith("GIT_CONFIG_KEY_") or name.startswith("GIT_CONFIG_VALUE_"):
                env.pop(name, None)
        try:
            proc = subprocess.run(["git", "--no-optional-locks", "-C", self.root] + list(args), stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, env=env)
        except OSError as exc:
            raise Refused(["git could not be started (" + exc.__class__.__name__ + ")"])
        if proc.returncode != 0:
            raise Refused(["git " + " ".join(args) + " in " + self.root + " exited %d (%s)" % (
                proc.returncode, (proc.stderr.decode("utf-8", "replace").strip().splitlines() or [""])[0][:160])])
        return proc.stdout.decode("utf-8", "replace").strip()

    # ---- the groups --------------------------------------------------------------------------------------------
    def git_head(self):
        head = self.git("rev-parse", "HEAD")
        origin = self.git("rev-parse", "origin/main")
        status = self.git("status", "--short", "--branch", "--untracked-files=no")
        return {"HEAD": head, "HEAD8": head[:8], "ORIGIN": origin, "ORIGIN8": origin[:8],
                "AHEAD": self.git("rev-list", "--count", "origin/main..HEAD"), "STATUS": status,
                "TRACKED_TREE": "clean" if "\n" not in status else "NOT clean"}

    def git_remote(self):
        return {"LSREMOTE": self.git("ls-remote", "origin", "refs/heads/main").replace("\t", " ")}

    def git_worktrees(self):
        trees = []
        for block in self.git("worktree", "list", "--porcelain").replace("\r\n", "\n").split("\n\n"):
            where = re.search(r"(?m)^worktree (.+)$", block)
            head = re.search(r"(?m)^HEAD ([0-9a-f]{40})$", block)
            if where and head:
                trees.append("%s at %s" % (re.split(r"[\\/]", where.group(1).rstrip("\\/"))[-1], head.group(1)[:8]))
        return {"WORKTREES_N": str(len(trees)), "WORKTREES": ", ".join(trees)}

    def git_untracked(self):
        return {"UNTRACKED_DISPATCHES": self.git("status", "--short", "--", ".mission/dispatches") or "none",
                "UNTRACKED_AMENDMENTS": self.git("status", "--short", "--", ".mission/amendments") or "none"}

    def mission_ledger(self):
        numbers = []
        lines = json_lines(self.file("mission ledger", ".mission", "ledger", "entries.jsonl"), "the mission ledger", numbers)
        if not lines:
            raise Refused(["the mission ledger holds no line"])
        found = None
        for index in range(len(lines) - 1, max(len(lines) - 12, -1), -1):
            said = re.findall(r"(?i)next free row[^0-9]{0,40}(\d+)", str(lines[index].get("content", "")))
            if said:
                # {NFR_LINE} IS THE FILE's OWN LINE NUMBER of that entry, an empty line counted as the line it is;
                # {ML} is the count of the ENTRIES, and an empty line is none.
                found = (said[-1], str(numbers[index]))
                break
        if found is None:
            self.notes.append("none of the mission ledger's last eleven entries states `next free row`")
        return {"ML": str(len(lines)), "ML_LAST": there(lines[-1], "id"), "ML_LAST_AT": there(lines[-1], "created_at"),
                "NFR": found[0] if found else None, "NFR_LINE": found[1] if found else None}

    def commit_ledger(self):
        lines = json_lines(self.file("commit ledger", *(LAM_PARTS + ("commit-ledger.jsonl",))), "the commit ledger")
        if not lines:
            raise Refused(["the commit ledger holds no line"])
        sha = there(lines[-1], "sha")
        return {"CL": str(len(lines)), "CL_LAST8": None if sha is None else sha[:8], "CL_LAST_BY": there(lines[-1], "composed_by")}

    def spawn_ledger(self):
        lines = json_lines(self.file("spawn ledger", *(LAM_PARTS + ("spawn-ledger.jsonl",))), "the spawn ledger")
        if not lines:
            raise Refused(["the spawn ledger holds no line"])
        last = lines[-1]
        return {"SL": str(len(lines)), "SL_LAST_SEQ": there(last, "seq"), "SL_LAST_EVENT": there(last, "event"),
                "SL_LAST_DISPATCH": there(last, "dispatch_id"), "SL_LAST_BY": there(last, "composed_by")}

    def mission(self):
        text = text_of(self.file("mission file", ".mission", "mission.yaml"))

        def key(name):
            # The value is looked for ON THE KEY's OWN LINE: a key with none (YAML's null) is not the next line's,
            # and a line that holds only a comment after the colon holds no value either.
            found = re.search(r"(?m)^%s:[ \t]*([^\s#]\S*)" % re.escape(name), text)
            return found.group(1) if found else None
        return {"STATE": key("state"), "COMPLETED": key("completed_at"), "SPEC": key("current_spec_version"),
                "CURSOR": key("current_milestone"), "RUNG": key("ladder_rung")}

    def spec(self):
        current = text_of(self.file("spec pointer", ".mission", "spec", "current.txt")).strip()
        if not TOKEN_RX.match(current):
            raise Refused([".mission/spec/current.txt reads " + ascii(current) + ", which is not one token"])
        spec = text_of(self.file("spec", ".mission", "spec", current + ".yaml"))
        features = re.findall(r"(?m)^  - id: (F-\d+)\b", spec)
        milestones = re.findall(r"(?m)^  - id: (M-\d+)\b", spec)
        if not features or not milestones or "\nmilestones:" not in spec:
            raise Refused(["the spec " + current + " does not hold features, milestones and a `milestones:` line"])
        m_block = spec[spec.rindex("  - id: " + milestones[-1]):]
        f_block = spec[spec.rindex("  - id: " + features[-1]):spec.index("\nmilestones:")]
        f_status = re.search(r"(?m)^    status: (\S+)", f_block)
        m_status = re.search(r"(?m)^    status: (\S+)", m_block)
        roster = re.search(r"contract_assertion_ids: \[([^\]]*)\]", m_block)
        ids = [one.strip() for one in (roster.group(1).split(",") if roster else []) if one.strip()]
        hashed = []
        for one in ids:
            if not TOKEN_RX.match(one):
                raise Refused(["the roster names " + ascii(one) + ", which is not one token"])
            hashed.append("%s `%s`" % (one, sha256(self.file("assertion " + one, ".mission", "contract", "assertions", one + ".yaml"))))
        return {"SPEC_TXT": current, "LAST_FEATURE": features[-1], "LAST_FEATURE_STATUS": f_status.group(1) if f_status else None,
                "LAST_MILESTONE": milestones[-1], "LAST_MILESTONE_STATUS": m_status.group(1) if m_status else None,
                # A roster that binds no assertion is a value -- `none` -- and not a figure that could not be derived.
                "ROSTER": roster.group(1) if roster else None,
                "ASSERTIONS": ("; ".join(hashed) if hashed else "none") if roster else None}

    def mirror(self):
        data = self.file("mirror", ".mission", "green-gate", "product.json")
        try:
            obj = json.loads(data.decode("utf-8-sig"))
        except ValueError:
            raise Refused([".mission/green-gate/product.json is not JSON"])
        if not isinstance(obj, dict):
            raise Refused([".mission/green-gate/product.json is JSON but not an object"])
        return {"MIRROR_BYTES": str(len(data)), "MIRROR_SHA": sha256(data), "MIRROR_LF_SHA": lf_blob_sha256(data),
                "FLOOR": there(obj, "stored_floor"), "XFAIL_IDS": there(obj, "expected_failure_test_ids")}

    def derived(self):
        data = self.file("derived file", "tools", "mission-cli", "config", "expected-failures.yaml")
        return {"DERIVED_BYTES": str(len(data)), "DERIVED_SHA": sha256(data)}

    def goal_id(self):
        if self.args.goal is None:
            raise Refused(["a figure of the goal is named and --goal is not given"])
        if not TOKEN_RX.match(self.args.goal):
            raise Refused(["--goal " + ascii(self.args.goal) + " is not one token [A-Za-z0-9][A-Za-z0-9._-]*"])
        return self.args.goal

    def goal(self):
        goal = self.goal_id()
        places = [self.path(".mission", "goals", goal + ".yaml"), self.path(*(LAM_PARTS + ("goals", goal + ".yaml")))]
        standing = [place for place in places if os.path.isfile(place)]
        if not standing:
            raise Refused(["no goal file of " + goal + " at " + places[0] + " or at " + places[1]])
        data = read_named(standing[0], "goal file")
        return {"GOAL": goal, "GOAL_BYTES": str(len(data)), "GOAL_SHA": sha256(data), "GOAL_LF_SHA": lf_blob_sha256(data),
                "GOAL_DETECTORS": str(len(re.findall(rb"(?m)^\s*- type:", data)))}

    def hook(self):
        goal = self.goal_id()
        data = self.file("settings file", ".claude", "settings.local.json")
        # The goal is matched TO ITS END: `-Goal G1` is not counted in `-Goal G10` or `-Goal G1x`.
        named = re.findall("-Goal " + re.escape(goal) + r"(?![A-Za-z0-9._-])", data.decode("latin-1"))
        return {"HOOK_COUNT": str(len(named)), "HOOK_BYTES": str(len(data)), "HOOK_SHA": sha256(data)}

    def acts(self):
        if self.args.acts_from is None:
            raise Refused(["the prose names the tally of the operator's acts and --acts-from is not given: the line "
                           "the arc's acts begin at is the caller's figure"])
        if not re.match(r"\A[1-9][0-9]*\Z", self.args.acts_from):
            raise Refused(["--acts-from " + ascii(self.args.acts_from) + " is not a line number from 1"])
        first = int(self.args.acts_from)
        # --acts-from IS THE FILE's OWN LINE NUMBER, an empty line counted as the line it is; LOG is the count of
        # the lines that hold an act, so an empty line is not one of them.
        every = text_of(self.file("acts log", ".mission-runtime", "operator-acts.log")).replace("\r\n", "\n").split("\n")
        if every and every[-1] == "":
            every.pop()
        if first > len(every):
            raise Refused(["--acts-from %d is beyond the acts log's %d line(s)" % (first, len(every))])
        lines = [line for line in every if line.strip()]
        counts = dict((one, 0) for one in ACT_CLASSES)
        for line in every[first - 1:]:
            gate = re.search(r"gate=(\S+)", line)
            if not gate or "tool_exit=0" not in line:
                continue
            for one in ACT_CLASSES:
                if gate.group(1).startswith(one + "-"):
                    counts[one] += 1
        out = {"LOG": str(len(lines)), "ACTS_FROM": str(first), "TALLY": "/".join(str(counts[one]) for one in ACT_CLASSES),
               "TALLY_N": str(sum(counts.values()))}
        for one in ACT_CLASSES:
            out["TALLY_" + one.upper().replace("-", "_")] = str(counts[one])
        return out

    def admissions(self):
        target = self.path(*(LAM_PARTS + ("handoff-admissions.jsonl",)))
        if not os.path.lexists(target):
            return {"ADM": "0"}
        # The evaluator holds this file with NO SHARING for an instant at each probe and at the append: an open
        # that meets it is tried five times and then REFUSED by name. It is never counted as no line.
        return {"ADM": str(len([line for line in read_named(target, "admissions record").split(b"\n") if line.strip()]))}

    def arc_id(self):
        if not self.args.arc or not TOKEN_RX.match(self.args.arc):
            raise Refused(["--arc " + ascii(self.args.arc) + " is not one token [A-Za-z0-9][A-Za-z0-9._-]*"])
        return self.args.arc

    def halts(self):
        arc = self.arc_id()
        folder = self.path(".mission-runtime", "halts")
        # The arc is matched TO THE DASH after it -- the HALTs of ARC-X-1 are not those of ARC-X-10 -- and no further
        # (an arc named ARC-X-1-B is taken with it); and WITHOUT REGARD TO LETTER CASE, as the evaluator's scan of
        # HALT-* is: a HALT of the arc named in small letters is an open HALT to that scan, and is one here.
        opens = ("HALT-" + arc + "-").upper()
        names = sorted((name for name in (os.listdir(folder) if os.path.isdir(folder) else [])
                        if name.upper().startswith(opens) and name.upper().endswith(".MD")), key=lambda name: name.lower())
        answered = [name for name in names if os.path.exists(self.path(".mission", "gates", "halt-ruling-" + name[:-3] + ".yaml"))]
        return {"HALTS_RAISED": str(len(names)), "HALTS_NAMES": ", ".join(names) if names else "none",
                "HALTS_ANSWERED": str(len(answered)), "HALTS_OPEN": str(len(names) - len(answered))}

    def copies(self):
        prefix = self.arc_id().lower() + "-"
        folder = self.path(".mission-runtime", "scratch-copies")
        held = []
        for name in sorted(os.listdir(folder) if os.path.isdir(folder) else []):
            if name.startswith(prefix) and os.path.isdir(os.path.join(folder, name)):
                held.append("`%s` (%d files)" % (name, sum(len(files) for _, _, files in os.walk(os.path.join(folder, name)))))
        return {"COPIES": ", ".join(held) if held else "none"}

    def runs(self):
        folder = self.path(*(LAM_PARTS + ("instrument-runs",)))
        return folder, sorted(name for name in (os.listdir(folder) if os.path.isdir(folder) else [])
                              if os.path.isfile(os.path.join(folder, name)))

    def capture(self):
        goal = self.goal_id()
        folder, names = self.runs()
        live = [name for name in names if name.startswith(goal + ".") and name.endswith(".stdout.txt")
                and not KEPT_NAME_RX.match(name)]
        if len(live) != 1:
            raise Refused(["%d live capture(s) of %s stand under %s, not one%s" % (
                len(live), goal, folder, (": " + ", ".join(live)) if live else "")])
        data = self.file("live capture", *(LAM_PARTS + ("instrument-runs", live[0])))
        text = text_of(data)
        head = re.search(r"(?m)^head: (\S+)", text)
        tally = [line.strip() for line in text.splitlines() if line.strip().startswith("TALLY")]
        return {"CAPTURE_NAME": live[0], "CAPTURE_BYTES": str(len(data)), "CAPTURE_SHA": sha256(data),
                "CAPTURE_HEAD8": head.group(1)[:8] if head else None, "CAPTURE_TALLY": tally[0] if tally else None}

    def kept(self):
        folder, names = self.runs()
        held = ["`%s` sha256 `%s`" % (name, sha256(read_named(os.path.join(folder, name), "kept capture")))
                for name in names if KEPT_NAME_RX.match(name)]
        return {"KEPT_CAPTURES": "; ".join(held) if held else "none"}

    def scratch(self):
        if not self.args.scratch:
            raise Refused(["a figure of the scratchpad is named and --scratch is not given"])
        top = os.path.abspath(self.args.scratch)
        if not os.path.isdir(top):
            raise Refused(["no scratch folder at " + top + " (--scratch)"])

        def stop(exc):
            raise Refused(["the scratch folder " + str(exc.filename or top) + " cannot be listed (" + exc.__class__.__name__ + ")"])
        try:
            tops = {name.lower() for name in os.listdir(top) if os.path.isdir(os.path.join(top, name))}
        except OSError as exc:
            stop(exc)
        # An --exclude that names no top-level folder would leave nothing out, and the predecessor's whole copy
        # would become rows of this seat's table without a word: it is REFUSED.
        stray = [given for given in (self.args.exclude or []) if given.lower() not in tops]
        if stray:
            raise Refused(["--exclude " + ", ".join(ascii(given) for given in stray) + " is not the bare name of a "
                           "top-level folder of --scratch " + top + ": nothing would be left out"])
        excluded = [name.lower() for name in (self.args.exclude or [])]
        rows, total, left_out = [], 0, 0

        def seen(path):
            # THE OPERATOR's COPY LINE IS Copy-Item AND Get-ChildItem WITH NO -Force: a hidden file or folder is not
            # carried by it and not counted by it, so a walk that took one would write counts his copy cannot meet.
            if hidden(path):
                raise Refused(["the scratch entry " + ascii(os.path.relpath(path, top)) + " is HIDDEN: the operator's copy line "
                               "does not carry a hidden file or folder, and the brief's counts would be untrue of his copy"])
        for folder, folders, files in os.walk(top, onerror=stop):
            if os.path.abspath(folder) == top:
                for inner in list(folders):
                    if inner.lower() in excluded:
                        folders.remove(inner)
                        seen(os.path.join(folder, inner))
                        for deep, deeper, inside_files in os.walk(os.path.join(folder, inner), onerror=stop):
                            for one in deeper + inside_files:
                                seen(os.path.join(deep, one))
                            left_out += len(inside_files)
            for inner in folders:
                seen(os.path.join(folder, inner))
            for name in files:
                full = os.path.join(folder, name)
                seen(full)
                shown = os.path.relpath(full, top)
                if shown[:1] == " " or shown[-1:] == " " or any(ord(char) < 32 or ord(char) > 126 for char in shown) or " | " in shown:
                    raise Refused(["the scratch file " + ascii(shown) + " has a name a keep-table row cannot carry (a "
                                   "leading or trailing blank, a control character, a byte above 126, or ` | `)"])
                data = read_named(full, "scratch file")
                rows.append((shown, len(data), sha256(data)))
                total += len(data)
        if not rows:
            raise Refused(["the walk of --scratch " + top + " finds no file" + (" outside the folders left out" if excluded else "") +
                           ": a keep-table of no row is a brief `seat.py keep` refuses"])
        rows.sort(key=lambda row: row[0].lower())
        self.keep_rows = ["| %s | %d | %s |" % row for row in rows]
        arc, seat = self.arc_id().lower(), self.seat_id()
        copy_to = ".mission-runtime\\scratch-copies\\%s-seat%s" % (arc, seat)
        brief = ".mission-runtime\\lam\\HANDOFF-%s-seat-%s.md" % (self.arc_id(), seat)
        # The scratchpad's path stands between single quotes in his line: an apostrophe in it is doubled, as his
        # shell reads one.
        copy_line = ("Copy-Item -LiteralPath '%s' -Destination %s -Recurse -ErrorAction Stop; (Get-ChildItem -LiteralPath %s "
                     "-Recurse -File | Measure-Object).Count" % (top.replace("'", "''"), copy_to, copy_to))
        compare_line = ("$b='%s'; $d='%s'; $rows=@(Select-String -LiteralPath $b -Pattern '%s' | ForEach-Object { $_.Matches[0] }); "
                        "$bad=0; foreach($m in $rows){ $p=Join-Path $d $m.Groups[1].Value; if(-not (Test-Path -LiteralPath $p) "
                        "-or (Get-Item -LiteralPath $p).Length -ne [int64]$m.Groups[2].Value -or (Get-FileHash -Algorithm SHA256 "
                        "-LiteralPath $p).Hash.ToLower() -cne $m.Groups[3].Value){ $bad++; \"MISMATCH $($m.Groups[1].Value)\" } }; "
                        "\"$($rows.Count - $bad) of $($rows.Count), $bad mismatches\"" % (brief, copy_to, ROW_PATTERN))
        return {"SCRATCH": top, "ROWS": str(len(rows)), "ROWS_BYTES": str(total), "EXCLUDED_FILES": str(left_out),
                "WHOLE": str(len(rows) + left_out), "KEEP_TABLE": "\n".join(self.keep_rows), "COPY_LINE": copy_line,
                "COMPARE_LINE": compare_line}

    def census(self):
        tool = os.path.join(os.path.dirname(os.path.abspath(__file__)), "seat.py")
        if not os.path.isfile(tool):
            raise Refused(["the prose names the census and no seat.py stands beside this file (" + tool + ")"])
        try:
            proc = subprocess.run([sys.executable, tool, "census", "--root", self.root, "--prefix", self.arc_id().lower() + "-",
                                   "--machine"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except OSError as exc:
            raise Refused(["seat.py census could not be started (" + exc.__class__.__name__ + ")"])
        said = proc.stdout.decode("utf-8", "replace").strip()
        if proc.returncode not in (0, 1):
            raise Refused(["seat.py census exited %d (%s)" % (proc.returncode, (said.splitlines() or [""])[0][:200])])
        try:
            result = json.loads(said)
        except ValueError:
            raise Refused(["seat.py census --machine did not print one JSON object"])
        if not isinstance(result, dict) or any(key not in result for key in ("copies", "line", "sum_line", "rows")):
            raise Refused(["seat.py census --machine printed JSON that is not the census's object"])
        for finding in result.get("findings", []):
            self.notes.append("CENSUS FINDING: " + finding)
        # {NCOPIES} is the census's count, in which ONE verdict's bytes are counted once: a copy met again is SAID.
        for name in result.get("same_again", []):
            self.notes.append("CENSUS: THE SAME VERDICT AGAIN, counted once: " + name)
        return {"NCOPIES": str(result["copies"]), "STOPS": result["line"], "SAVED": result["sum_line"],
                "STOPS_TABLE": "\n".join(result["rows"])}

    def seam(self):
        if not self.args.seated:
            raise Refused(["the prose names a seam figure and --seated is not given: the first base is the stamp "
                           "`seat.py copy` wrote beside this turn's seating copy"])
        said = read_named(self.args.seated, "file --seated names").decode("ascii", "replace").strip()
        first, now = stamp_ms(said), stamp_ms(self.clock)
        if first is None:
            raise Refused(["the file --seated names does not hold ONE stamp YYYY-MM-DDTHH:MM:SS.mmmZ (" + ascii(said[:60]) + ")"])
        if first > now:
            raise Refused(["the stamp in the file --seated names, " + said + ", is later than the clock at the write, " + self.clock])
        return {"FIRST": said, "OWN": span_text(first, now), "SEAM_BASES": "SEAM BASES first " + said + " end " + self.clock}

    def clocks(self):
        return {"CLOCK": self.clock[:19] + "Z", "CLOCKMS": self.clock}

    def seat_id(self):
        if not self.args.seat or not re.match(r"\A[1-9][0-9]*\Z", self.args.seat):
            raise Refused(["--seat " + ascii(self.args.seat) + " is not a number from 1"])
        return self.args.seat

    def command(self):
        if self.args.session is not None and not TOKEN_RX.match(self.args.session):
            raise Refused(["--session " + ascii(self.args.session) + " is not one token"])
        return {"ARC": self.arc_id(), "SEAT": self.seat_id(), "SESSION": self.args.session, "CTX": ctx_of(self.args),
                "BRIEF_REL": ".mission-runtime/lam/HANDOFF-%s-seat-%s.md" % (self.arc_id(), self.seat_id())}

    def composed(self):
        return {"COMPOSED_BY": COMPOSER_PATH + "@" + blob_id(read_named(os.path.abspath(__file__), "tool's own file"))[:8]}

    # ---- the lookup --------------------------------------------------------------------------------------------
    def value(self, name):
        """The value of one built-in token; REFUSED where it is not one or cannot be derived."""
        if name not in self.owner:
            raise Refused(["{" + name + "} is not a token this tool fills and is not declared"])
        names, maker, source = self.owner[name]
        if name not in self.cache:
            made = maker()
            for one in names:
                self.cache[one] = made.get(one)
                self.sources[one] = source
        if self.cache[name] is None:
            if name == "SESSION":
                raise Refused(["{SESSION} is named and --session is not given"])
            raise Refused(["{" + name + "} could not be derived from " + source])
        return self.cache[name]


def ctx_of(args):
    if args.ctx is None:
        raise Refused(["--ctx is not given: the arm line carries the operator's meter reading"])
    if args.ctx == "unknown":
        # THE METER NOT READ: taken as the word itself, and the arm line says so in its ctx slot. No head pattern admits
        # that line (the evaluator's and seat.py's take 0 to 100), and prepare refuses a head file composed with it.
        return args.ctx
    if not re.match(r"\A(?:0|[1-9][0-9]?|100)\Z", args.ctx):
        raise Refused(["--ctx " + ascii(args.ctx) + " is not a whole number from 0 to 100"])
    return args.ctx


def read_declared(figures, path, wanted):
    """The seat's own figures, {NAME: (value, source)}. EVERY line is held to the form, and a name is declared once;
    a figure is DERIVED -- its file looked for and read, under --root and nowhere else -- only where a text of this
    run names it (`wanted`), so a line no text names costs the run nothing and can refuse nothing but its form."""
    lines = read_named(path, "declare file").decode("utf-8", "replace").replace("\r\n", "\n").split("\n")
    out, seen = {}, set()
    for number, line in enumerate(lines, start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        found = DECLARE_RX.match(line.strip())
        if not found:
            raise Refused(["line %d of the declare file is not `NAME = sha256|bytes|name-of-one|absent <path>` or `NAME = "
                           "key <key> of <path>`" % number])
        name, kind, key, where = found.group(1), found.group(2), found.group(3), found.group(4).strip()
        if name in figures.owner or name in STANDING_TOKENS or name in BRIEF_TOKENS or name in seen:
            raise Refused(["line %d of the declare file declares {%s}, which %s" % (
                number, name, "is declared twice" if name in seen else "this tool fills itself")])
        seen.add(name)
        local = where.replace("/", "\\")
        full = os.path.abspath(figures.path(local))
        if os.path.isabs(local) or os.path.splitdrive(local)[0] or not inside(full, figures.root):
            raise Refused(["line %d of the declare file: %s is not a path under --root (a declared figure is read under "
                           "the mission root, by a path from it)" % (number, where)])
        if kind == "absent" and ("*" in where or "?" in where):
            raise Refused(["line %d of the declare file: `absent` takes ONE exact path, and %s holds * or ? (a name with "
                           "either cannot stand, so it would read True whatever stands there)" % (number, where)])
        if name not in wanted:
            continue
        if kind == "absent":
            out[name] = (str(not os.path.lexists(full)), "absent " + where)
            continue
        if "*" in where or "?" in where or kind == "name-of-one":
            # THE WILDCARDS ARE * AND ? ALONE, AND THE DECLARED PATH's OWN. A [ or a ] is a letter of a name, in the
            # root's own path and in the declared path alike: read as a pattern's class, the brackets of a folder
            # named figs[1] found the file that stands there to be none -- and found the file of a folder figs1.
            base = os.path.abspath(figures.root)
            pattern = os.path.join(glob.escape(base), os.path.relpath(full, base).replace("[", "[[]"))
            hits = sorted(hit for hit in glob.glob(pattern) if os.path.isfile(hit))
            if len(hits) != 1:
                raise Refused(["line %d of the declare file: %d file(s) match %s, not one" % (number, len(hits), where)])
            full = hits[0]
            # THE FILE A WILDCARD ANSWERS is asked what the pattern was asked: a part of the pattern that a junction
            # or a link answers leads where it leads, and a figure is read under the root alone.
            if not inside(full, figures.root):
                raise Refused(["line %d of the declare file: %s names %s, which is not a path under --root by the path the "
                               "system opens (a declared figure is read under the mission root)" % (number, where, real(full))])
        elif not os.path.isfile(full):
            raise Refused(["line %d of the declare file: no file at %s" % (number, full)])
        if kind == "name-of-one":
            out[name] = (os.path.basename(full), "name-of-one " + where)
            continue
        data = read_named(full, "file line %d of the declare file names" % number)
        if kind == "sha256":
            out[name] = (sha256(data), "sha256 " + where)
        elif kind == "bytes":
            out[name] = (str(len(data)), "bytes " + where)
        else:
            said = re.search(r"(?m)^%s:[ \t]*(.*?)[ \t\r]*$" % re.escape(key), text_of(data))
            if not said or not said.group(1):
                raise Refused(["line %d of the declare file: %s holds no column-0 `%s:` with a value" % (number, where, key)])
            out[name] = (said.group(1), "key " + key + " of " + where)
    return out


def scalar(value):
    return value.replace("\r\n", "\n").replace("\n", " / ").replace("|", "/")


def fill(text, figures, declared, standing=()):
    """The text with every token filled. A token in `standing` is left as it is; an unknown one is REFUSED."""
    def one(found):
        name = found.group(1)
        if name in standing:
            return found.group(0)
        if name in declared:
            value = scalar(declared[name][0])
        else:
            value = figures.value(name)
            value = value if name in BLOCK_TOKENS else scalar(value)
        # A VALUE THAT HOLDS A TOKEN's FORM IS NOT WRITTEN: whatever fills this text next -- this tool, or `seat.py
        # head` over a head file -- would read it as a token, the seat's own {CLOCKMS} among them.
        held = NAME_RX.search(value)
        if held:
            raise Refused(["the value of {" + name + "} holds " + held.group(0) + ": a figure that carries a token's form "
                           "would be read as a token by what fills this text next"])
        return value
    return NAME_RX.sub(one, text)


def text_faults(text, what):
    """Why a filled text may not be written: it must be ASCII, LF only, with exactly one final LF."""
    faults = []
    odd = sorted({ord(char) for char in text if ord(char) > 126 or (ord(char) < 32 and char != "\n")})
    if odd:
        faults.append(what + " holds a CR, a TAB, a control character or a byte above 126 once filled (code point(s) " +
                      ", ".join(str(one) for one in odd) + ")")
    if not text.endswith("\n") or text.endswith("\n\n"):
        faults.append(what + " does not end in exactly one LF once filled")
    return faults


def read_prose(path, what):
    data = read_named(path, what)
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        raise Refused(["the " + what + " at " + path + " is not UTF-8"])


def real(path):
    """The path THE SYSTEM WOULD OPEN, not the one spelled: links and junctions followed, and a short (8.3) name of
    a part that stands replaced by its long one; a part that does not stand yet is kept, under its resolved parent."""
    return os.path.realpath(os.path.abspath(path))


def hidden(path):
    """True where the system marks the file or folder hidden (Windows' attribute); False where it keeps no mark."""
    try:
        return bool(getattr(os.stat(path), "st_file_attributes", 0) & 2)
    except OSError:
        return False


def inside(path, folder):
    """True where path is the folder or lies under it -- BY THE PATHS THE SYSTEM OPENS: a path spelled by a short
    name, or through a junction, is where it leads."""
    path, folder = os.path.normcase(real(path)), os.path.normcase(real(folder))
    return path == folder or path.startswith(folder.rstrip("\\/") + os.sep)


def prepare(args, standing_brief):
    """Everything derived and checked BEFORE a byte is written: (figures, brief path, brief text or None, head text
    or None, head path or None)."""
    clock = clock_now()
    figures = Figures(args, clock)
    root = figures.root
    if not os.path.isdir(root):
        raise Refused(["no mission root at " + root])
    arc, seat = figures.arc_id(), figures.seat_id()
    ctx_of(args)
    lam = figures.path(*LAM_PARTS)
    brief_path = os.path.join(lam, "HANDOFF-%s-seat-%s.md" % (arc, seat))
    if not os.path.isdir(lam):
        raise Refused(["no runtime folder at " + lam])
    head_text = head_path = None
    if bool(args.head_prose) != bool(args.head_out):
        raise Refused(["--head-prose and --head-out are given together or not at all"])
    if args.head_prose and ctx_of(args) == "unknown":
        raise Refused(["--ctx unknown composes no head file: line 1 of a head file is the arm line, and `seat.py head "
                       "--place-handoff` places only one whose ctx is a whole number from 0 to 100"])
    prose = second = brief_text = None
    wanted = set()
    if not standing_brief:
        if os.path.lexists(brief_path):
            raise Refused(["a brief already stands at " + brief_path + ": a brief is never written over"])
        if args.scratch and inside(brief_path, args.scratch):
            raise Refused(["the brief's path " + brief_path + " lies inside --scratch " + os.path.abspath(args.scratch) +
                           ": nothing is written under the scratch folder, whose walk must stay true after the write"])
        prose = read_prose(args.prose, "prose file")
        wanted.update(NAME_RX.findall(prose))
    if args.head_prose:
        head_path = os.path.abspath(args.head_out)
        close = os.path.join(lam, "close")
        parent = os.path.dirname(head_path)
        leaf = os.path.basename(head_path)
        if os.path.normcase(os.path.dirname(parent)) != os.path.normcase(close) or not os.path.isdir(parent):
            raise Refused(["--head-out " + head_path + " does not lie directly inside one standing folder of " + close])
        if os.path.normcase(os.path.dirname(real(parent))) != os.path.normcase(real(close)):
            # As spelled it lies there; by the path the system opens -- that folder is a junction or a link -- it
            # leads elsewhere, and the head file would be written there.
            raise Refused(["--head-out " + head_path + " lies inside a folder of " + close + " that leads elsewhere (" +
                           real(parent) + "): the head file is written inside a close folder itself"])
        if not TOKEN_RX.match(leaf):
            raise Refused(["--head-out is named " + ascii(leaf) + ", which is not one token [A-Za-z0-9][A-Za-z0-9._-]*"])
        if halt_named(leaf):
            raise Refused(["--head-out is named " + leaf + ", which begins HALT- once its dots are dropped, in any letter case: a file whose "
                           "name -- or whose 8.3 name -- begins HALT- under .mission-runtime/lam reads as an OPEN HALT "
                           "to the evaluator's scan, which is by name"])
        if os.path.lexists(head_path):
            raise Refused(["a file already stands at " + head_path])
        if args.scratch and inside(head_path, args.scratch):
            raise Refused(["--head-out lies inside --scratch"])
        second = read_prose(args.head_prose, "head prose")
        wanted.update(NAME_RX.findall(second))
    declared = read_declared(figures, args.declare, wanted) if args.declare else {}
    if prose is not None:
        names = NAME_RX.findall(prose)
        if args.minimal:
            barred = []
            if "STOPS_TABLE" in names:
                barred.append("{STOPS_TABLE}")
            if names.count("KEEP_TABLE") > 1:
                barred.append("a second {KEEP_TABLE}")
            if barred:
                raise Refused(["--minimal is given and the prose holds " + " and ".join(barred) +
                               ": a minimal brief carries one keep-table and no stops table"])
        placed = names.count("KEEP_TABLE")
        if "COMPARE_LINE" in names and not placed:
            raise Refused(["the prose names {COMPARE_LINE} and places no {KEEP_TABLE}: the compare line reads the brief's "
                           "own keep rows, and it would find none"])
        brief_text = fill(prose, figures, declared)
        faults = text_faults(brief_text, "the prose")
        left = sorted(set(NAME_RX.findall(brief_text)))
        if left:
            faults.append("the filled brief still holds " + ", ".join("{" + one + "}" for one in left))
        # THE GUARD RUNS OVER EVERY BRIEF, table or none: the lines the operator's row pattern finds are the walk's
        # rows, in order, once for each {KEEP_TABLE} placed -- and where none is placed, no line at all. It and the
        # seam line's test read WHOLE LINES, so they are made over a text that is already clean: a prose refused
        # for a CR is refused for the CR, and not also for the lines the CR hides from a whole-line pattern.
        figures.guarded = placed > 0
        figures.placed = placed
        if not faults:
            found = [line for line in brief_text.split("\n") if KEEP_ROW_RX.match(line)]
            if found != figures.keep_rows * placed:
                faults.append("the operator's row pattern finds %d line(s) in the filled brief and the walk has %d row(s) "
                              "placed %d time(s): another table of the prose reads as keep rows, or a row does not read as one"
                              % (len(found), len(figures.keep_rows), placed))
            if "SEAM_BASES" in names:
                # THE LINE WHOLE is the line this run composed, byte for byte: a character glued to the token -- a
                # full stop after it -- would stand in the second stamp's place, and the successor's `seat.py head`
                # would refuse the brief.
                # AND IT IS THE ONLY LINE IN THE FORM THE SUCCESSOR COUNTS: `seat.py head` counts every line `SEAM BASES
                # first <text> end <text>` and refuses two, so a second such line beside the composed one -- the token
                # again with a character glued to it, or a line the seat typed -- is refused here.
                composed = figures.value("SEAM_BASES")
                lines_of_brief = brief_text.split("\n")
                whole = [line for line in lines_of_brief if line == composed and SEAM_BASES_RX.match(line)]
                formed = [line for line in lines_of_brief if SEAM_FORM_RX.match(line)]
                count = len(whole) if len(whole) != 1 else len(formed)
                if count != 1:
                    faults.append("the prose names {SEAM_BASES} and the filled brief holds %d line(s) that are the SEAM BASES "
                                  "line whole, not one: the token stands alone on its line, once -- the successor's `seat.py "
                                  "head` reads its spans from that one line" % count)
        if faults:
            raise Refused(faults)
    if second is not None:
        head_text = fill(second, figures, declared, standing=STANDING_TOKENS + BRIEF_TOKENS)
        faults = text_faults(head_text, "the head prose")
        first_line = head_text.split("\n")[0]
        if first_line.startswith("HANDOFF") or first_line.startswith("AWAITING"):
            faults.append("the head prose's first line begins HANDOFF or AWAITING: line 1 of the head is the arm line, which "
                          "this tool writes")
        if head_text.count("\n") != 1 or first_line == "":
            faults.append("the head prose is %d line(s) once filled%s, not ONE: the head file is two lines -- the arm line, "
                          "which this tool writes, and the seat's second line"
                          % (head_text.count("\n"), ", an empty one among them" if "\n\n" in "\n" + head_text else ""))
        if faults:
            raise Refused(faults)
    return figures, brief_path, brief_text, head_text, head_path


def arm_line(ctx, data, arc, seat):
    return "HANDOFF AT %s%% %s; %s .mission-runtime/lam/HANDOFF-%s-seat-%s.md" % (ctx, lf_blob_sha256(data), sha256(data), arc, seat)


def write_head(head_path, head_text, line, data):
    filled = (head_text.replace("{BRIEF_BYTES}", str(len(data))).replace("{BRIEF_SHA}", sha256(data))
              .replace("{BRIEF_LF_SHA}", lf_blob_sha256(data)))
    create_whole(head_path, (line + "\n" + filled).encode("ascii"), "the head file")
    emit("HEAD FILE %s: %d line(s), the arm line first; %s left standing for `seat.py head --place-handoff` to fill" % (
        head_path, 1 + filled.count("\n"), ", ".join("{" + one + "}" for one in STANDING_TOKENS if "{" + one + "}" in filled) or "no clock token"))


def run_compose(args):
    figures, brief_path, brief_text, head_text, head_path = prepare(args, standing_brief=False)
    data = brief_text.encode("ascii")
    create_whole(brief_path, data, "a brief")
    # FROM HERE THE BRIEF STANDS, and nothing below is said as a refusal: a step that fails is said as what it is,
    # with the brief named as standing, exit 3.
    try:
        back = read_whole(brief_path)
    except OSError as exc:
        emit("WROTE %s: %d B, sha256 %s; re-read: NOT READ (%s) -- THE BRIEF STANDS, unproved; `gen_brief.py arm` with "
             "the same flags reads it again and prints its arm line" % (brief_path, len(data), sha256(data), exc.__class__.__name__))
        return 3
    emit("WROTE %s: %d B, %d lines, ASCII, LF only, no byte-order mark; sha256 %s; re-read: %s" % (
        brief_path, len(back), back.count(b"\n"), sha256(back), "EQUAL" if back == data else "NOT EQUAL"))
    if figures.guarded and figures.placed > 1:
        # Allowed without --minimal, and SAID: the operator's compare line reads every keep row of the brief, so a
        # table placed twice is counted twice by him, where {ROWS} is the walk's own count.
        emit("KEEP-TABLE %d row(s), PLACED %d TIMES; the operator's row pattern over the brief finds those rows, in order, "
             "each time, and no others -- his compare line will count %d rows where {ROWS} reads %d"
             % (len(figures.keep_rows), figures.placed, len(figures.keep_rows) * figures.placed, len(figures.keep_rows)))
    elif figures.guarded:
        emit("KEEP-TABLE %d row(s); the operator's row pattern over the brief finds those rows, in order, and no others"
             % len(figures.keep_rows))
    for note in figures.notes:
        emit(note)
    line = arm_line(ctx_of(args), back, figures.arc_id(), figures.seat_id())
    emit(line)
    if head_path:
        try:
            write_head(head_path, head_text, line, back)
        except Refused as exc:
            emit("THE HEAD FILE WAS NOT WRITTEN (" + "; ".join(exc.reasons) + (" -- " + exc.tail if exc.tail else "") +
                 "): THE BRIEF STANDS at " + brief_path + ", and `gen_brief.py arm` with the same flags writes the head file")
            return 3
    return 0 if back == data else 3


def run_arm(args):
    figures, brief_path, _, head_text, head_path = prepare(args, standing_brief=True)
    if not os.path.lexists(brief_path):
        raise Refused(["no brief stands at " + brief_path])
    data = read_named(brief_path, "brief")
    emit("READ %s: %d B, sha256 %s" % (brief_path, len(data), sha256(data)))
    for note in figures.notes:
        emit(note)
    line = arm_line(ctx_of(args), data, figures.arc_id(), figures.seat_id())
    emit(line)
    if head_path:
        write_head(head_path, head_text, line, data)
    return 0


def run_facts(args):
    figures = Figures(args, clock_now())
    prose = read_prose(args.prose, "prose file")
    declared = read_declared(figures, args.declare, set(NAME_RX.findall(prose))) if args.declare else {}
    names = []
    for found in NAME_RX.findall(prose):
        if found not in names:
            names.append(found)
    for name in names:
        if name in declared:
            emit("%s = %s  [declared: %s]" % (name, scalar(declared[name][0]), declared[name][1]))
            continue
        value = figures.value(name)
        if name in BLOCK_TOKENS and "\n" in value:
            value = "%d line(s), the first: %s" % (value.count("\n") + 1, value.split("\n")[0])
        emit("%s = %s  [%s]" % (name, value if name in BLOCK_TOKENS else scalar(value), figures.sources[name]))
    for note in figures.notes:
        emit(note)
    emit("FACTS: %d token(s) named; nothing was written" % len(names))
    return 0


SKELETON_HEAD = """# HANDOFF -- {ARC}, ORCHESTRATOR SEAT {SEAT}

Written {CLOCKMS} by seat {SEAT} of {ARC} (ctx {CTX}%, the operator's meter: testimony); composed by {COMPOSED_BY}.

## THE STATE (each cell derived at this write)

| | |
|---|---|
| HEAD | `{HEAD}`, ahead **{AHEAD}** of origin/main `{ORIGIN}`; `git status --short --branch --untracked-files=no`: `{STATUS}` |
| ledgers | mission **{ML}** lines (last id `{ML_LAST}`); commit ledger **{CL}** lines, last sha `{CL_LAST8}`; spawn ledger **{SL}** lines |
| register | NEXT FREE ROW **{NFR}** (the ledger's last statement, line {NFR_LINE}) |
| mission | state **{STATE}**; completed_at {COMPLETED} |
| operator-acts.log | {LOG} lines; the arc's acts from line {ACTS_FROM}: **{TALLY} = {TALLY_N}** |
| handoff-admissions.jsonl | {ADM} lines |
"""
SKELETON_FULL_ROWS = """| the remote | `git ls-remote origin refs/heads/main`: `{LSREMOTE}`; the tracked tree {TRACKED_TREE} |
| the ledgers' last lines | mission created_at {ML_LAST_AT}; commit ledger `{CL_LAST_BY}`; spawn ledger seq **{SL_LAST_SEQ}** ({SL_LAST_EVENT}, {SL_LAST_DISPATCH}), `{SL_LAST_BY}` |
| the spec | current_spec_version **{SPEC}** (`spec/current.txt` reads {SPEC_TXT}); the cursor {CURSOR}; ladder_rung {RUNG}; last feature **{LAST_FEATURE}** ({LAST_FEATURE_STATUS}), last milestone **{LAST_MILESTONE}** ({LAST_MILESTONE_STATUS}), roster [{ROSTER}] |
| assertions bound | {ASSERTIONS} |
| the mirror and the derived file | product.json {MIRROR_BYTES} B sha256 `{MIRROR_SHA}`, LF/blob `{MIRROR_LF_SHA}`; stored_floor **{FLOOR}**; expected_failure_test_ids {XFAIL_IDS}; expected-failures.yaml {DERIVED_BYTES} B sha256 `{DERIVED_SHA}` |
| the last root capture | `{CAPTURE_NAME}`, {CAPTURE_BYTES} B, sha256 `{CAPTURE_SHA}`, head {CAPTURE_HEAD8}: `{CAPTURE_TALLY}`. KEPT COPIES ON DISK: {KEPT_CAPTURES} |
| goal and Stop hook | goal {GOAL}: {GOAL_BYTES} B sha256 `{GOAL_SHA}`, {GOAL_DETECTORS} detectors; settings.local.json names it {HOOK_COUNT} time(s), {HOOK_BYTES} B, sha256 `{HOOK_SHA}` |
| the acts by class | halt-ruling {TALLY_HALT_RULING}, amendment-material {TALLY_AMENDMENT_MATERIAL}, dispatch {TALLY_DISPATCH}, push {TALLY_PUSH}, reclose {TALLY_RECLOSE} |
| HALTs | raised {HALTS_RAISED} ({HALTS_NAMES}), answered {HALTS_ANSWERED}, open {HALTS_OPEN} |
| worktrees | {WORKTREES_N}: {WORKTREES} |
| untracked | under .mission/dispatches: `{UNTRACKED_DISPATCHES}`; under .mission/amendments: `{UNTRACKED_AMENDMENTS}` |

## THE STOPS BY COLUMN ({NCOPIES} verdict copies)

| evaluated_at | goal | verdict | column | what | copy (folder under close/ : name, bytes, sha256) | kept capture where REUSED |
|---|---|---|---|---|---|---|
{STOPS_TABLE}
"""
SKELETON_TAIL = """
{STOPS}
{SAVED}

## THE SCRATCH COPIES AND THE KEEP-TABLE

THE OPERATOR HOLDS: {COPIES}. THIS SEAT's SCRATCHPAD: `{SCRATCH}` (session `{SESSION}`). THE TABLE IS EVERY FILE OF IT BUT THE FOLDERS LEFT OUT ({EXCLUDED_FILES} files): **{ROWS} rows**, {ROWS_BYTES} bytes; THE WHOLE COPY HOLDS {WHOLE} FILES.

THE COPY LINE:

    {COPY_LINE}

EXPECTED: {WHOLE}.

THE COMPARE LINE:

    {COMPARE_LINE}

EXPECTED: `{ROWS} of {ROWS}, 0 mismatches`.

| name | bytes | sha256 |
|---|---|---|
{KEEP_TABLE}

## THE SEAM

The brief was begun at {FIRST} and written at {CLOCKMS} -- {OWN}. The brief: `{BRIEF_REL}`.
{SEAM_BASES}
"""


def run_skeleton(args):
    """THE BYTES, LF only -- a text-mode stdout would end every line CR LF here, and compose refuses a CR. A shell
    that re-encodes what a tool prints (Windows PowerShell's `>` stores UTF-16) is passed by with --out."""
    data = (SKELETON_HEAD + ("" if args.minimal else SKELETON_FULL_ROWS) + SKELETON_TAIL).encode("ascii")
    if args.out is not None:
        path = os.path.abspath(args.out)
        # A skeleton is a prose file of the seat's own. It is written OUTSIDE the mission's planes, so no name it
        # is given -- STATUS.md, a ledger's, a verdict's -- can be the file of that name a plane holds. THE PATH IS
        # HELD AS SPELLED AND AS THE SYSTEM OPENS IT: a plane reached by its short (8.3) name, or through a junction
        # that leads into one, is that plane.
        opened = real(path)
        for one in ([path] if os.path.normcase(opened) == os.path.normcase(path) else [path, opened]):
            if any(part.lower() in (".mission", ".mission-runtime", ".claude") for part in re.split(r"[\\/]", one)):
                raise Refused(["--out " + path + " lies under a mission plane (a folder named .mission, .mission-runtime or "
                               ".claude" + ("" if one == path else "; by the path the system opens, " + opened) +
                               "): a skeleton is the seat's own prose file and is written outside them"])
        if halt_named(os.path.basename(path)):
            raise Refused(["--out is named " + os.path.basename(path) + ", which begins HALT- once its dots are dropped: "
                           "this tool writes no file the evaluator's HALT scan would list"])
        create_whole(path, data, "a skeleton")
        emit("WROTE %s: %d B, %d lines, ASCII, LF only, no byte-order mark; sha256 %s" % (
            path, len(data), data.count(b"\n"), sha256(data)))
        return 0
    sys.stdout.flush()
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()
    return 0


def run_stamp(_args):
    emit("composed_by: " + COMPOSER_PATH + "@" + blob_id(read_named(os.path.abspath(__file__), "tool's own file"))[:8])
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="gen_brief.py", description="The handoff-brief generator: the seat's prose "
                                     "with every figure and table re-derived at the write, and the HANDOFF head's arm line.")
    sub = parser.add_subparsers(dest="command")
    shared = argparse.ArgumentParser(add_help=False)
    shared.add_argument("--root", required=True, help="the mission root")
    shared.add_argument("--arc", required=True, help="the arc's id, e.g. ARC-X-1")
    shared.add_argument("--seat", required=True, help="the seat's number")
    shared.add_argument("--goal", default=None, help="the goal id")
    shared.add_argument("--scratch", default=None, help="the seat's scratchpad, walked for the keep-table")
    shared.add_argument("--exclude", action="append", default=None, help="a top-level folder of the scratchpad left out")
    shared.add_argument("--ctx", default=None, help="the operator's meter reading, 0 to 100, or unknown where it cannot be read: testimony")
    shared.add_argument("--session", default=None, help="the seat's session id, where the prose names {SESSION}")
    shared.add_argument("--seated", default=None, help="the <copy>.seated file `seat.py copy` wrote this turn")
    shared.add_argument("--acts-from", default=None, help="the line of operator-acts.log the arc's acts begin at")
    shared.add_argument("--declare", default=None, help="the seat's own figures, one `NAME = kind path` a line")
    shared.add_argument("--minimal", action="store_true", help="refuse a stops table and a second keep-table")
    shared.add_argument("--head-prose", default=None, help="the seat's second head line, with tokens")
    shared.add_argument("--head-out", default=None, help="where the two head lines are written, inside one close folder")
    p_compose = sub.add_parser("compose", parents=[shared], help="write the brief and print the arm line")
    p_compose.add_argument("--prose", required=True, help="the seat's page: its words, with {NAME} tokens")
    p_arm = sub.add_parser("arm", parents=[shared], help="the arm line of a brief that already stands")
    p_arm.add_argument("--prose", help="TAKEN AND NOT READ: so that compose's own flags can be given to arm as they stand")
    p_facts = sub.add_parser("facts", parents=[shared], help="print every token the prose names; write nothing")
    p_facts.add_argument("--prose", required=True, help="the seat's page")
    p_skeleton = sub.add_parser("skeleton", help="print a starting prose file: the token lines, no prose")
    p_skeleton.add_argument("--minimal", action="store_true", help="the minimal form")
    p_skeleton.add_argument("--out", default=None, help="write the bytes to this file (exclusive create) and not to stdout")
    sub.add_parser("stamp", help="print the composed_by value of this copy")
    args = parser.parse_args(argv)
    runs = {"compose": run_compose, "arm": run_arm, "facts": run_facts, "skeleton": run_skeleton, "stamp": run_stamp}
    if args.command not in runs:
        parser.print_usage(sys.stderr)
        return 2
    try:
        return runs[args.command](args)
    except Refused as exc:
        emit("REFUSED: " + "; ".join(exc.reasons) + " -- " + (exc.tail or "nothing was written"))
        return 2
    except OSError as exc:
        # Every write of this file is one guarded create, so what reaches here was met at a read or a listing: it
        # is said as a refusal, by name, and never as a traceback under the exit of a finding.
        emit("REFUSED: " + exc.__class__.__name__ + " at " + str(exc.filename or "a path the system does not name") +
             " -- this run stopped there, and wrote nothing after it")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
