#!/usr/bin/env python3
"""THE COMMIT-LEDGER COMPOSER.

WHAT THIS FILE WRITES, AND WHY ONE TRACKED WRITER. The commit ledger,
.mission-runtime/lam/commit-ledger.jsonl, is the provenance record Test-LamAdvanceAdmission reads
(tools/lam/lam-verify-admission.ps1): an advance is admitted only where every commit in its range stands on that
ledger as a line whose `event` is "commit" and whose `sha` is the commit's full id. BEFORE THIS FILE no tracked tool
wrote a line of it. Each recording seat composed its lines with a session scratch script, and the file came to hold
more than one shape in more than one serialization. This file is the one tracked writer, in the form of the
spawn-ledger composer beside it, and it shares no code with that file: each composer runs alone from a tree that holds
it and nothing else, and neither can change what the other does without changing its own stamp.

WHAT THE CALLER SUPPLIES, AND WHAT IT DOES NOT. The commit's id, and the three fields git does not hold: `by` (who made
the commit), `attested_by` (who records it) and `note`. Nothing else. The time is the commit's own, read from git; the
subject is the commit's own, read from git. No caller supplies a time.

SUBCOMMANDS
  append --sha HEX40 --line-file PATH [--ledger PATH] [--repo TAG]
      Read ONE JSON object from the line file (UTF-8; one leading byte-order mark is accepted) holding exactly `by`,
      `attested_by` and `note`, each a non-empty string; read the commit from git; and append ONE compact ASCII line
      ending in LF. A refusal comes BEFORE a byte is written: one line at column 0, "REFUSED: <reasons> -- nothing
      was appended to <ledger>", exit 2. On success one line, "APPENDED line <n> to <ledger>: <the line>", exit 0,
      where <n> is one more than the number of lines the ledger held when it was read.
      --ledger defaults to the commit ledger of the checkout this file sits in, <top>/.mission-runtime/lam/
      commit-ledger.jsonl, so a recording seat's command line names no runtime path. --repo defaults to the
      directory name of the PRIMARY checkout -- the parent of the directory `git rev-parse --git-common-dir`
      names -- which is the same word from the primary checkout and from every linked worktree of it.
  stamp
      Print the `composed_by` value this copy stamps, after the same provenance test append makes; exit 0 or 2.

THE LINE. Ten keys, in this order: `event` ("commit"), `repo`, `sha` (the full 40-hex id), `ts`, `by`,
`attested_by`, `subject`, `note`, `backfilled` (false) and `composed_by`. `ts` is the commit's own COMMITTER time,
read from the commit object and written as that same instant in UTC, YYYY-MM-DDTHH:MM:SSZ. `subject` is the commit
message's first paragraph -- leading blank lines passed over, each line's trailing whitespace dropped, the lines
joined by one space -- as git's own subject is. No second time key is written: a
commit-ledger line holds one time, and it is the commit's.

`backfilled`. false says this composer wrote the line from git, by the commit's id, in a checkout
that holds the commit. true stands on legacy lines that were added after the fact, and some legacy lines carry no
such key at all. NOTHING under tools/ or tests/ reads the key: Test-LamAdvanceAdmission reads `event`, `sha` and --
only under a declared external ledger -- `repo`, and admits a line with `backfilled` and a line without alike. This
composer writes false on every line and reads the key on none.

THE REFUSALS, each before a byte is written:
  * the sha is not 40 lowercase hex, or names no commit in this repository;
  * the commit is not in HEAD's history (git merge-base --is-ancestor <sha> HEAD): a line is composed in a checkout
    that holds the commit it names;
  * a commit line with that sha already stands on the ledger. The scan reads every line leniently -- a note line, a
    line with or without `backfilled`, a compact line and a spaced one are read alike, and a line that is not JSON
    is passed over -- and compares the FULL sha: a legacy line carrying a shorter spelling is another value and
    does not make a full sha "already ledgered", as it never made one admitted. It reads key names, `event` and
    `sha` ignoring case and passes a leading byte-order mark, as the ledger's one reader, PowerShell, does; a line
    only that reader's JSON parser can read is passed over;
  * there is no ledger file (this composer appends to an existing file and creates none: whether a mission holds its
    own commit ledger is itself read by the admission), or its last byte is not LF;
  * the line file supplies a key this composer owns (`event`, `repo`, `sha`, `ts`, `subject`, `backfilled`,
    `composed_by`), any other key that is not one of its three, or lacks one of the three, or gives one a value
    that is not a non-empty string or that holds an unpaired surrogate; or --repo is empty, space-padded or holds
    an unpaired surrogate;
  * THE TIME FORM, over the caller's three fields and a --repo the caller supplies: a token that opens like a
    stamp -- four digits, two, two, the letter T, two digits and a colon -- is a full RFC 3339 UTC stamp,
    YYYY-MM-DDTHH:MM:SS with 0 to 9 fractional digits and Z or +00:00, naming a real instant; and a clock-only
    time, HH:MM:SS and Z with no date, is refused. `subject` is NOT held to it: it is git's bytes, and a commit
    whose message carries a malformed time must still be ledgerable. Nor is the default `repo`, the primary
    checkout's directory name, which no caller types;
  * this copy is not <top>/tools/lam/commit_ledger.py of its repository, or its blob is not admitted (below).

THE ADMITTED BLOBS, AND THE STAMP. As the spawn-ledger composer's: the admitted blobs are every blob this path has had
at a commit `git rev-list --full-history` lists for it from HEAD and, where it exists, from the branch `main`; the
stamp is git's blob id of this file's bytes with every CR LF collapsed to LF, cut to 8, written as
"tools/lam/commit_ledger.py@<8 hex>". An edited, uncommitted or copied composer stamps nothing. `composed_by` is a
declaration this file writes, not an attestation: nothing stops a seat from writing a line by hand with a copied
stamp, and nothing audits this ledger's lines for one.

THE MISSION-EVENT FEED (UI-1 S1, LM2-ADR-045, expanded-schemas SS14: ledger_row's emitter is "commit-ledger / ledger
verbs"). After an append, ONE ledger_row line -- entry (the line's number), row (null: a commit line has no register
row), type ("commit") -- is said by the feed's ONE writer, Write-MissionEvent, through tools/lam/emit-mission-event.ps1
run as a subprocess with the fields as arguments. This file never writes the feed itself: a second emitter would be a
second writer with a second lock. Only where the checkout holds a mission (.mission/mission.yaml), the entry point
sits beside this file, and the ledger is the checkout's own; the subprocess is silent and bounded, its outcome is not
read, and nothing about it changes this composer's output or exit code -- a failed append is recorded by the
PowerShell side in the evidence plane's hook-errors.log.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

COMPOSER_PATH = "tools/lam/commit_ledger.py"
LEDGER_PARTS = (".mission-runtime", "lam", "commit-ledger.jsonl")
CALLER_KEYS = ("by", "attested_by", "note")
OWNED_KEYS = ("event", "repo", "sha", "ts", "subject", "backfilled", "composed_by")
SHA1_RX = re.compile(r"\A[0-9a-f]{40}\Z")
COMMITTER_RX = re.compile(rb"\Acommitter .*> ([0-9]{1,12}) [+-][0-9]{4}[ \t\r]*\Z")
# The time form: what opens like a stamp, the one form a stamp is written in, the run a malformed one is shown by,
# and a clock-only time.
TIME_OPEN_RX = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:")
TIME_FULL_RX = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})"
                          r"(?:\.([0-9]{1,9}))?(?:Z|\+00:00)")
TIME_RUN_RX = re.compile(r"[0-9A-Za-z:.+-]*")
CLOCK_ONLY_RX = re.compile(r"(?<![0-9])(?<![0-9][:.])[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z(?![0-9A-Za-z])")
TIME_FORM = "YYYY-MM-DDTHH:MM:SS with 0 to 9 fractional digits and Z or +00:00"
# git reads these from the environment: the first seven would answer for another repository, the rest would inject
# configuration into the calls below.
GIT_REDIRECTS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_OBJECT_DIRECTORY",
                 "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT")


class Refused(Exception):
    def __init__(self, reasons, where=None):
        Exception.__init__(self, "; ".join(reasons))
        self.reasons = list(reasons)
        self.where = where


def emit(text):
    """One line on stdout, ASCII whatever the console's code page: anything else is backslash-escaped."""
    sys.stdout.write(text.encode("ascii", "backslashreplace").decode("ascii") + "\n")
    sys.stdout.flush()


def show(value):
    """A value as a reason names it: repr for text, JSON's own token for everything else, ASCII either way."""
    if isinstance(value, str):
        return ascii(value)
    try:
        text = json.dumps(value, ensure_ascii=True, allow_nan=True)
    except RecursionError:
        return "<a value nested too deep to show>"
    except (TypeError, ValueError):
        text = ascii(value)
    return text if len(text) <= 80 else text[:80] + "..."


def _unique_pairs(pairs):
    seen = set()
    for key, _ in pairs:
        if key in seen:
            raise ValueError("the key " + ascii(key) + " occurs more than once")
        seen.add(key)
    return dict(pairs)


def parse_line(text):
    """One JSON object, strictly. Returns (object, None) or (None, reason)."""
    try:
        obj = json.loads(text, object_pairs_hook=_unique_pairs)
    except (ValueError, RecursionError) as exc:
        first = (str(exc).splitlines() or [""])[0][:200]
        return None, "the line file is not one JSON object (" + first + ")"
    if not isinstance(obj, dict):
        return None, "the line file is JSON but not an object (a " + type(obj).__name__ + ")"
    return obj, None


def has_lone_surrogate(text):
    """A code point in D800-DFFF: json.loads joins a valid escaped pair into one code point beyond U+FFFF, so any
    surrogate left in a decoded string is unpaired."""
    return any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def time_instant(match):
    """The instant a full stamp names, or None where its fields name none (a 30th of February, an hour 25)."""
    year, month, day, hour, minute, second = (int(match.group(index)) for index in range(1, 7))
    micro = int(((match.group(7) or "") + "000000")[:6])
    try:
        return datetime.datetime(year, month, day, hour, minute, second, micro, tzinfo=datetime.timezone.utc)
    except ValueError:
        return None


def time_faults(text):
    """The time form over ONE string: each token that opens like a stamp and is not one, and each clock-only time."""
    faults = []
    plain = []
    at = 0
    for opened in TIME_OPEN_RX.finditer(text):
        if opened.start() < at:
            continue
        full = TIME_FULL_RX.match(text, opened.start())
        if full is not None and re.match(r"[0-9A-Za-z]", text[full.end():full.end() + 1]):
            full = None
        if full is None:
            token = TIME_RUN_RX.match(text, opened.start()).group(0)
            faults.append("holds " + ascii(token[:48]) + ", which opens like a stamp and is not a full RFC 3339 UTC "
                          "stamp (" + TIME_FORM + ")")
            end = opened.start() + len(token)
        elif time_instant(full) is None:
            faults.append("holds " + ascii(full.group(0)) + ", a stamp that names no real instant")
            end = full.end()
        else:
            end = full.end()
        plain.append(text[at:opened.start()] + " " * (end - opened.start()))
        at = end
    plain.append(text[at:])
    for clock in CLOCK_ONLY_RX.finditer("".join(plain)):
        faults.append("holds the clock-only time " + ascii(clock.group(0)) + ", which carries no date")
    return faults


def git(directory, args, stdin=None):
    """(exit code, stdout BYTES, stderr text) of one git call in a directory, the redirecting variables removed."""
    env = dict(os.environ)
    for name in list(env):
        if name in GIT_REDIRECTS or name.startswith("GIT_CONFIG_KEY_") or name.startswith("GIT_CONFIG_VALUE_"):
            env.pop(name, None)
    try:
        proc = subprocess.run(["git", "-C", directory] + list(args), input=stdin, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, env=env)
    except OSError as exc:
        return 127, b"", str(exc)
    return proc.returncode, proc.stdout, proc.stderr.decode("utf-8", "replace")


def blob_id(data):
    lf = data.replace(b"\r\n", b"\n")
    return hashlib.sha1(b"blob " + str(len(lf)).encode("ascii") + b"\0" + lf).hexdigest()


def repository():
    """(top, reasons): the repository this file sits in, and whether this file is its tools/lam/commit_ledger.py."""
    here = os.path.dirname(os.path.realpath(__file__))
    code, out, _ = git(here, ["rev-parse", "--show-toplevel"])
    shown = out.decode("utf-8", "replace").strip()
    if code != 0 or not shown:
        return None, ["this composer is not inside a git repository (git rev-parse --show-toplevel: exit " +
                      str(code) + ")"]
    top = os.path.realpath(shown)
    expect = os.path.normcase(os.path.realpath(os.path.join(top, *COMPOSER_PATH.split("/"))))
    if os.path.normcase(os.path.realpath(__file__)) != expect:
        return top, ["this copy is not " + COMPOSER_PATH + " of the repository at " + top]
    return top, []


def admitted_blobs(top):
    """(blobs, reasons): every blob COMPOSER_PATH has had at a commit rev-list names from HEAD and main."""
    starts = ["HEAD"]
    code, _, _ = git(top, ["rev-parse", "--verify", "--quiet", "refs/heads/main"])
    if code == 0:
        starts.append("refs/heads/main")
    code, out, _ = git(top, ["rev-list", "--full-history"] + starts + ["--", COMPOSER_PATH])
    if code != 0:
        return set(), ["git rev-list of " + COMPOSER_PATH + " in " + top + " failed (exit " + str(code) + ")"]
    commits = [c for c in out.decode("ascii", "replace").split() if SHA1_RX.match(c)]
    blobs = set()
    if commits:
        query = "".join(c + ":" + COMPOSER_PATH + "\n" for c in commits).encode("ascii")
        code, out, _ = git(top, ["cat-file", "--batch-check=%(objectname) %(objecttype)"], stdin=query)
        if code != 0:
            return set(), ["git cat-file in " + top + " failed (exit " + str(code) + ")"]
        for line in out.decode("ascii", "replace").splitlines():
            fields = line.split()
            if len(fields) == 2 and fields[1] == "blob" and SHA1_RX.match(fields[0]):
                blobs.add(fields[0])
    return blobs, []


def provenance():
    """(top, own blob id, reasons). Non-empty reasons: this copy may not stamp a line."""
    top, why = repository()
    if why:
        return top, None, why
    with open(os.path.realpath(__file__), "rb") as handle:
        own = blob_id(handle.read())
    blobs, why = admitted_blobs(top)
    if why:
        return top, own, why
    if own not in blobs:
        return top, own, ["this composer's bytes (blob " + own[:8] + ") are not an admitted version of " +
                          COMPOSER_PATH + " (committed in the history of HEAD or main): an edited, uncommitted or "
                          "copied composer stamps nothing"]
    return top, own, []


def primary_name(top):
    """The directory name of the PRIMARY checkout: the parent of the common git dir. None where it has none."""
    code, out, _ = git(top, ["rev-parse", "--git-common-dir"])
    common = out.decode("utf-8", "replace").strip()
    if code != 0 or not common:
        return None
    if not os.path.isabs(common):
        common = os.path.join(top, common)
    return os.path.basename(os.path.dirname(os.path.realpath(common))) or None


def commit_facts(top, sha):
    """(ts, subject, reasons) of one commit of the repository at top, read from the commit object itself -- its
    committer time as the same instant in UTC, its message's first paragraph on one line."""
    code, out, _ = git(top, ["cat-file", "-t", sha])
    kind = out.decode("ascii", "replace").strip()
    if code != 0 or kind != "commit":
        return None, None, ["sha " + sha + " names no commit in the repository at " + top +
                            (" (it names a " + kind + ")" if code == 0 and kind else "")]
    why = []
    code, _, _ = git(top, ["merge-base", "--is-ancestor", sha, "HEAD"])
    if code == 1:
        why.append("the commit " + sha + " is not in HEAD's history in " + top + ": a line is composed in a checkout "
                   "that holds the commit it names")
    elif code != 0:
        why.append("git merge-base --is-ancestor " + sha + " HEAD failed in " + top + " (exit " + str(code) + ")")
    code, raw, _ = git(top, ["cat-file", "commit", sha])
    if code != 0:
        return None, None, why + ["git cat-file commit " + sha + " failed in " + top + " (exit " + str(code) + ")"]
    head, _, message = raw.partition(b"\n\n")
    seconds = None
    encoding = "utf-8"
    for line in head.split(b"\n"):
        found = COMMITTER_RX.match(line)
        if found is not None:
            seconds = int(found.group(1))
        elif line.startswith(b"encoding "):
            encoding = line[len(b"encoding "):].decode("ascii", "replace").strip() or "utf-8"
    ts = None
    if seconds is not None:
        try:
            ts = (datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc) +
                  datetime.timedelta(seconds=seconds)).strftime("%Y-%m-%dT%H:%M:%SZ")
        except (OverflowError, ValueError):
            ts = None
    if ts is None:
        why.append("the commit " + sha + " carries no committer time that can be read")
    try:
        text = message.decode(encoding, "replace")
    except Exception:
        # Whatever the codec the header names raises: `undefined` and `idna` raise UnicodeError, a name Python does
        # not know LookupError. The message is then read as UTF-8, and the commit is ledgered, not traced.
        text = message.decode("utf-8", "replace")
    # As git's own subject: leading blank lines passed over, then every line up to the first blank one, each with
    # its trailing whitespace dropped and its leading whitespace kept, joined by one space.
    blank = " \t\r\n\v\f"
    lines = text.split("\n")
    while lines and lines[0].strip(blank) == "":
        lines.pop(0)
    first = []
    for line in lines:
        if line.strip(blank) == "":
            break
        first.append(line.rstrip(blank))
    subject = " ".join(first)
    return ts, subject, why


def lines_naming(raw, sha):
    """The 1-based numbers of a ledger's commit lines that carry this sha, read leniently: every shape is read, a
    line that is not JSON is passed over, and a shorter spelling of a sha is another value. The ledger's one reader
    is PowerShell, which reads key names, `event` and `sha` ignoring case and passes a leading byte-order mark; so
    does this scan. A line only that reader's JSON parser can read -- a single-quoted one -- is passed over here."""
    found = []
    for number, part in enumerate(raw.split(b"\n"), 1):
        if number == 1 and part.startswith(b"\xef\xbb\xbf"):
            part = part[3:]
        try:
            obj = json.loads(part.decode("utf-8"))
        except (ValueError, UnicodeDecodeError, RecursionError):
            continue
        if not isinstance(obj, dict):
            continue
        folded = {str(key).lower(): value for key, value in obj.items()}
        event, named = folded.get("event"), folded.get("sha")
        if isinstance(event, str) and event.lower() == "commit" and isinstance(named, str) and named.lower() == sha:
            found.append(number)
    return found


def caller_fields(obj):
    """The reasons the line file's object is not exactly by, attested_by and note, each a non-empty string in form."""
    why = []
    for key in obj:
        if key == "ts":
            why.append("ts is supplied by the caller: the time is the commit's own, read from git, and no caller "
                       "supplies one")
        elif key in OWNED_KEYS:
            why.append(key + " is supplied by the caller: only " + COMPOSER_PATH + " writes it")
        elif key not in CALLER_KEYS:
            why.append("the line file carries the key " + ascii(key) + ", which is not by, attested_by or note")
    for key in CALLER_KEYS:
        if key not in obj:
            why.append("the line file carries no " + key)
            continue
        value = obj[key]
        if not (isinstance(value, str) and value.strip() != ""):
            why.append(key + " " + show(value) + " is not a non-empty string")
            continue
        if has_lone_surrogate(value):
            why.append(key + " holds a string with an unpaired surrogate")
        for fault in time_faults(value):
            why.append(key + " " + fault)
    return why


def append_record(sha, obj, ledger, repo):
    """Compose and append ONE commit line. Returns (ledger, line number, line). Raises Refused before any write."""
    why = caller_fields(obj)
    top, own, prov = provenance()
    if ledger is None and top is not None:
        ledger = os.path.join(top, *LEDGER_PARTS)
    shown = ledger if ledger is not None else "(no ledger: the checkout is not known)"
    raw = None
    if ledger is not None:
        if not os.path.isfile(ledger):
            why.append("no ledger file at " + ledger + " (the composer appends to an existing file and creates none)")
        else:
            try:
                with open(ledger, "rb") as handle:
                    raw = handle.read()
            except OSError as exc:
                why.append("the ledger at " + ledger + " cannot be read (" + exc.__class__.__name__ + ")")
            if raw and not raw.endswith(b"\n"):
                why.append("the ledger's last byte is not LF, so an appended line would join the line before it")
    ts = subject = None
    if not SHA1_RX.match(sha):
        why.append("sha " + ascii(sha) + " is not a full 40-hex commit id in lowercase")
    elif top is not None:
        ts, subject, facts = commit_facts(top, sha)
        why.extend(facts)
        if raw:
            standing = lines_naming(raw, sha)
            if standing:
                why.append("a commit line for " + sha + " already stands on the ledger, at line " +
                           ", ".join(str(n) for n in standing))
    if repo is None and top is not None:
        repo = primary_name(top)
        if repo is None:
            why.append("the primary checkout's directory name could not be derived (git rev-parse "
                       "--git-common-dir); name the tag with --repo")
    elif repo is not None:
        if repo.strip() == "" or repo != repo.strip():
            why.append("--repo " + ascii(repo) + " is empty or carries a space at either end")
        if has_lone_surrogate(repo):
            why.append("--repo holds a string with an unpaired surrogate")
        for fault in time_faults(repo):
            why.append("--repo " + fault)
    why.extend(prov)
    if why:
        raise Refused(why, shown)
    record = {"event": "commit", "repo": repo, "sha": sha, "ts": ts, "by": obj["by"],
              "attested_by": obj["attested_by"], "subject": subject, "note": obj["note"], "backfilled": False,
              "composed_by": COMPOSER_PATH + "@" + own[:8]}
    try:
        line = json.dumps(record, ensure_ascii=True, separators=(",", ":"), allow_nan=False)
    except (TypeError, ValueError) as exc:
        raise Refused(["the line cannot be written as JSON (" + str(exc)[:120] + ")"], shown)
    count = (raw or b"").count(b"\n") + 1
    try:
        with open(ledger, "ab") as handle:
            handle.write((line + "\n").encode("ascii"))
    except OSError as exc:
        raise Refused(["the ledger at " + ledger + " cannot be written (" + exc.__class__.__name__ + ")"], shown)
    return ledger, count, line


def offer_ledger_row(ledger, entry):
    """ledger_row, said by the feed's one writer (the docstring's THE MISSION-EVENT FEED). Never raises, prints nothing."""
    try:
        top, _ = repository()
        if top is None or not os.path.isfile(os.path.join(top, ".mission", "mission.yaml")):
            return
        entry_point = os.path.join(top, "tools", "lam", "emit-mission-event.ps1")
        if not os.path.isfile(entry_point):
            return
        source = os.path.realpath(ledger)
        if os.path.normcase(os.path.commonpath([source, top])) != os.path.normcase(top):
            return
        shell = shutil.which("powershell") or shutil.which("pwsh")
        if shell is None:
            return
        env = dict(os.environ)
        for name in list(env):
            if name in GIT_REDIRECTS or name.startswith("GIT_CONFIG_KEY_") or name.startswith("GIT_CONFIG_VALUE_"):
                env.pop(name, None)
        subprocess.run([shell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", entry_point,
                        "-Root", top, "-Kind", "ledger_row", "-SourcePath", source, "-Hook", "commit-ledger",
                        "int:entry=" + str(entry), "null:row", "str:type=commit"],
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, timeout=120)
    except Exception:
        return


def run_append(args):
    named = args.ledger if args.ledger is not None else "the checkout's commit ledger"
    try:
        raw = open(args.line_file, "rb").read()
    except OSError as exc:
        emit("REFUSED: the line file cannot be read (" + exc.__class__.__name__ + ") -- nothing was appended to " +
             named)
        return 2
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        emit("REFUSED: the line file is not UTF-8 -- nothing was appended to " + named)
        return 2
    obj, bad = parse_line(text)
    if bad:
        emit("REFUSED: " + bad + " -- nothing was appended to " + named)
        return 2
    try:
        ledger, count, line = append_record(args.sha, obj, args.ledger, args.repo)
    except Refused as exc:
        emit("REFUSED: " + "; ".join(exc.reasons) + " -- nothing was appended to " + (exc.where or named))
        return 2
    emit("APPENDED line " + str(count) + " to " + ledger + ": " + line)
    offer_ledger_row(ledger, count)
    return 0


def run_stamp(_args):
    _, own, why = provenance()
    if why:
        emit("REFUSED: " + "; ".join(why))
        return 2
    emit("composed_by: " + COMPOSER_PATH + "@" + own[:8])
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="commit_ledger.py",
                                     description="Compose commit-ledger lines from git, by the commit's id.")
    sub = parser.add_subparsers(dest="command")
    p_append = sub.add_parser("append", help="read ONE commit from git and append its line")
    p_append.add_argument("--sha", required=True, help="the commit's full 40-hex id")
    p_append.add_argument("--line-file", required=True,
                          help="a UTF-8 file holding ONE JSON object: by, attested_by, note")
    p_append.add_argument("--ledger", default=None,
                          help="the ledger (default: this checkout's .mission-runtime/lam/commit-ledger.jsonl)")
    p_append.add_argument("--repo", default=None,
                          help="the repo tag (default: the primary checkout's directory name)")
    sub.add_parser("stamp", help="print the composed_by value this copy stamps")
    args = parser.parse_args(argv)
    if args.command == "append":
        return run_append(args)
    if args.command == "stamp":
        return run_stamp(args)
    parser.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
