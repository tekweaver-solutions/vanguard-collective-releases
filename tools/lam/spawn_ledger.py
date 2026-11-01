#!/usr/bin/env python3
"""THE SPAWN-LEDGER COMPOSER, AND THE FORWARD-ONLY AUDIT OF THE LINES AFTER THE CUTOFF.

THE RULE THIS FILE HOLDS. A spawn-ledger `round` is an integer, and a label lives in `round_label`. That is
enforced forward-only, by an audit of every line after a cutoff: the label-shaped lines at or before it are
legacy, admitted through the readers' older round_number fallback, and every line after it is checked.
The composer stamps every line it writes with `composed_by`, naming this file and its blob sha8,
and the forward-only audit requires that field on every line after the cutoff. The stamp and the
audit are this file's alone.

WHY A COMPOSER AT ALL. Before this file no tracked tool wrote a line of .mission-runtime/lam/spawn-ledger.jsonl:
the runner, tools/lam/mission-dispatch.ps1, did not name that file. Every spawn, complete and note line was
composed by the orchestrator seat's own session scratch scripts, and one arc's wrote `round` as a label.
SINCE A LATER REVISION the runner calls `append` itself for the two refusals it decides --
a login probe that did not answer OK, and a validator result it would not place -- each ONE note at the moment of
the act (rule (13) gives that note its form). The complete line stays the seat's ceremony's: it pairs the seq the
seat's spawn line took and carries facts the runner does not hold (rule (12) binds its placement fields to disk).
SINCE A LATER REVISION the runner writes a third note the same way -- a validator session that exited
leaving no result, NO-RESULT-AT-SESSION-END-<CODE> -- and the ceremony's complete line for that spawn carries the same
token in `refusal`, and the runner's sentence in `reason`, beside its null result (rule (14) gives that line its form).
SINCE A LATER REVISION four rules are append's ALONE, (15) to (18) below. They hold the
caller's object at the moment of the act: a null result names its refusal, every time written is written to one form,
the line's own `ts` is this composer's clock, and a complete line that names its anchors carries the runner's model
argument beside the validator's own report. The audit applies none of them: it judges history, and history holds lines
these rules would refuse.

SUBCOMMANDS
  append --ledger PATH --line-file PATH [--mission-root PATH]
      Read ONE JSON object from the line file (UTF-8; one leading byte-order mark is accepted), CHECK it against
      the ledger, stamp `composed_by` -- and, on a complete line that names its anchors, the model keys of rule
      (18) before it -- and append it as ONE compact ASCII line ending in LF. --mission-root names the root a
      RELATIVE anchors_path is read against; without it that root is the ledger's own, where the ledger sits at
      <root>/.mission-runtime/lam/. A refusal comes
      BEFORE a byte is written: one line at column 0, "REFUSED: <reasons> -- nothing was appended to <ledger>",
      exit 2. On success one line, "APPENDED line <n> to <ledger>: <the line>", exit 0, where <n> is one more
      than the number of lines the ledger held when it was read.
  audit --ledger PATH --after N --prefix-sha256 HEX
      Lines 1..N are LEGACY: admitted without the check, their bytes pinned by HEX (the sha256 of the first N
      LF-terminated lines); each one whose `round` is present and is not an integer from 1 to 2147483647 (a boolean
      included), and each one that is not JSON, is NAMED on a LEGACY line.
      Every line after N must pass the CHECK and carry a `composed_by` naming an admitted version of this file.
      The last line is "RESULT PASS ..." or "RESULT FAIL ..."; exit 0 PASS, 1 FAIL, 2 when the audit cannot run.
  stamp
      Print the `composed_by` value this copy stamps, after the same provenance test append makes; exit 0 or 2.

THE CHECK -- ONE definition, applied by append to the caller's object, again to the composed line before it is
written, and by audit to every line after N. Rules (1) and (2) exist because the close-milestone gate reads every
line with Windows PowerShell 5.1's ConvertFrom-Json, and ONE line it cannot parse makes the gate refuse the whole
ledger; the limits in (2) are the ones measured on that parser, with margin:
  (1) the line is ONE JSON object: no key twice, no NaN or Infinity, no number that reads as infinite;
  (2) at every depth: no empty key; no two keys of one object equal ignoring case; no key named psobject,
      psbase, psadapted, psextended or pstypenames in any case; no key __type in any case (PowerShell's reader
      takes the exact `__type` as a type name: it throws on an object or array value, drops the key over a string
      or a number and keeps it over null -- the other cases are refused as margin); no string, key or value, that
      holds an unpaired surrogate (PowerShell's reader replaces each with U+FFFD, so two keys can collide or merge
      and a value is rewritten); at most 32 containers deep, the line's own object counted; every integer inside
      the signed 64-bit range, every other number finite and at most 1e308 in magnitude;
  (3) every top-level key is written in a-z, 0-9 and _ only -- so PowerShell, which reads names ignoring case,
      and Python, which does not, name the same fields (`Round` would be `round` to the gate and absent to the
      transcription tool);
  (4) `event` is "spawn", "complete" or "note" -- the three events the ledger carries;
  (5) a spawn or complete line carries `seq`, a JSON integer from 1 to 2147483647, and no earlier line of the
      same event carries that seq -- both readers pair one spawn line with one complete line by seq;
  (6) `round`, where present, is a JSON integer from 1 to 2147483647. A label, a numeral in a string, a float such
      as 1.0, true, false and null are refused. 2147483647 is the largest value the gate's [int] holds;
  (7) a complete line that carries `validates` carries a `round` -- the gate refuses such a line without one;
  (8) `round_label`, where present, is a non-empty string standing beside an integer `round`;
  (9) `round_number` is absent: the integer lives in `round`; round_number is the legacy carrier the older
      fallback reads, and a line carrying both could say two different things;
  (10) append: the caller supplies no `composed_by`, which only this file stamps. audit: `composed_by` reads
      "tools/lam/spawn_ledger.py@" and 8 lowercase hex digits that begin an ADMITTED blob.
  (11) audit only: the line is byte for byte the form append writes for the object it parses to -- compact, ASCII,
      its keys in their order -- and carries no CR byte. Both readers split lines on CR as well as LF (the gate's
      ReadAllLines, the tool's text-mode read), so a CR between members is one line here and two broken lines to
      them; any other variation is a line the composer did not write.
  (12) THE PLACED COPY. A complete line that carries any of result_source_sha256,
      result_source_path and result_dest_path declares that the runner placed a validator's result, and carries all
      three and result_sha256: both hashes 64 lowercase hex and EQUAL -- result_sha256 keeps its name and its meaning,
      the sha256 of the file the goal evaluator finds at tests/lam, which is the COPY (Test-LamLedgerBound in
      tools/lam/lam-verify-admission.ps1 binds a file through that field and no other); result_source_sha256 is the
      source's, beside it -- and both paths non-empty strings. append ALSO re-derives, at the moment of the act, the
      file at result_dest_path: an absolute path naming a file whose sha256 is result_sha256, or the line is refused
      (absent, or holding other bytes). audit applies the line's own half only: it reads a ledger later, when a copy
      may since have been archived, so it does not re-read the destination. A complete line with none of the three
      fields is not checked by this rule.
  (13) THE RUNNER'S REFUSAL NOTE. A note that carries `refusal` carries a refusal token
      of A-Z and 0-9 in hyphen-joined parts, a non-empty string dispatch_id, a JSON integer runner_exit and a
      non-empty string reason.
  (14) THE REFUSAL ON A COMPLETE LINE. A complete line that carries `refusal` is the complete line
      of a spawn that produced no result, NAMED: it carries rule (13)'s refusal token, non-empty string dispatch_id,
      JSON integer runner_exit and non-empty string reason, and it BINDS NO RESULT -- result_sha256 is absent or JSON
      null (the empty string is neither), and none of rule (12)'s three placement fields is present. No field is added
      to the ledger by this rule, and result_sha256 keeps its name and its meaning: the two readers that set aside a
      complete line binding no result set this one aside. append and audit both apply it. A
      complete line with no `refusal` is not checked by this rule; rule (15) is what holds the bare null-result line.
THE FOUR RULES THAT ARE APPEND'S ALONE. Each is applied to the caller's object at the
moment of the act and to nothing else: not to the composed line's re-check, and not by audit, which reads PASS over a
line these rules would refuse exactly as it did before them.
  (15) THE NULL RESULT NAMES ITS REFUSAL. A complete line whose result_sha256 is present and JSON
      null carries `refusal`, which rule (14) then holds to its form, or it is refused: the bare null-result line is
      no longer appended. A complete line with no result_sha256 key is not checked by this rule. The token is held
      to rule (13)'s form and to nothing more. For a spawn the runner refused before spawning, the family is
      REFUSED-BEFORE-SPAWN-<CODE>: <CODE> the runner's own refusal code where it names one, and VERIFY-GATE-EXIT-2
      for its ADR-022 verify gate, which names none.
  (16) THE TIME FORM. At every depth, in every string and in every key: a token that opens like a
      stamp -- four digits, two, two, the letter T, two digits and a colon -- is a full RFC 3339 UTC stamp,
      YYYY-MM-DDTHH:MM:SS with 0 to 9 fractional digits and Z or +00:00, naming a real instant, with no letter or
      digit following it; and a clock-only time, HH:MM:SS with or without a fraction and then Z, standing outside
      such a stamp, is refused as carrying no date. A time is found by the shape of the value, never by the name of
      its key, and the refusal names the path (census_bracket, gate_stamp_anchors.consumed_at, runner_lines[3]). A
      file-name spelling whose clock is written with dashes (...T21-22-20.566Z) opens no stamp and is not read.
  (17) THE LINE'S OWN `ts`. Where the caller's object carries a top-level `ts`, it is a full stamp in rule (16)'s
      form, the whole value, standing within 120 seconds of this composer's clock at the write; otherwise it is
      refused as not the clock at the write. A line with no `ts` is appended as before: this composer writes none.
  (18) THE MODEL KEYS. The caller supplies none of runner_model, validator_model_reported and
      model_note: only this file stamps them, before composed_by. A complete line NAMES ITS ANCHORS when
      anchors_path or anchors_sha256 is present and not JSON null; it then carries both -- a non-empty string, and
      64 lowercase hex -- and append re-reads that file at the moment of the act, an absolute path or a relative
      one read against the mission root, requires its sha256 equal, and stamps `runner_model` with its one column-0
      `model_id:` value, the model argument the runner gave the session. A file absent, holding other bytes or
      carrying no such line refuses the line. Where the line also declares a placement (rule (12)), append reads
      the placed copy's column-0 `validator_identity:` scalar and stamps `validator_model_reported`: the runner's
      model where the scalar holds it as a whole token, else the token after the word "model" -- bare, or inside
      quotes, backticks or brackets -- else JSON null; and
      it stamps `model_note`, one sentence, only where the report differs from the runner's model or names none.
      A complete line that names no anchors -- a spawn refused before spawning has none -- carries none of the three.
Nothing else in a line is checked.

THE ADMITTED BLOBS, AND THE STAMP. The admitted blobs are every blob tools/lam/spawn_ledger.py has had at a commit
`git rev-list --full-history` lists for that path from HEAD and, where it exists, from the branch `main`, in the
repository `git rev-parse --show-toplevel` names for this file's own directory. The stamp is git's blob id of
this file's bytes with every CR LF collapsed to LF (git's blob basis for a text file under core.autocrlf), cut
to 8. append and stamp refuse when this file is not <top>/tools/lam/spawn_ledger.py of that repository, or when
its blob is not admitted: an edited, uncommitted or copied composer stamps nothing. The reference is pinned to
HEAD and main so that an audit run from a tree that carries main reads the lines main's composer wrote.

WHAT THE STAMP IS NOT. `composed_by` is a declaration this file writes, not an attestation: nothing stops a seat
from copying a real stamp into a line it wrote by hand, and such a line passes the stamp test. What the audit
establishes is narrower: every line after the cutoff passes the CHECK, whoever wrote it, and carries a stamp
naming an admitted version of this file. Every admitted blob stays admitted; there is no revocation.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
import re
import subprocess
import sys

COMPOSER_PATH = "tools/lam/spawn_ledger.py"
EVENTS = ("spawn", "complete", "note")
ROUND_MAX = 2147483647
SEQ_MAX = 2147483647
INT64_MIN = -9223372036854775808
INT64_MAX = 9223372036854775807
FLOAT_MAX = 1e308
DEPTH_MAX = 32
PS_RESERVED = ("psobject", "psbase", "psadapted", "psextended", "pstypenames")
PS_TYPE_KEY = "__type"
TOP_KEY_RX = re.compile(r"\A[a-z0-9_]+\Z")
STAMP_RX = re.compile(r"\Atools/lam/spawn_ledger\.py@([0-9a-f]{8})\Z")
SHA1_RX = re.compile(r"\A[0-9a-f]{40}\Z")
SHA256_RX = re.compile(r"\A[0-9a-f]{64}\Z")
# Rule (12): the fields that declare a placement, and the one that binds it.
PLACEMENT_FIELDS = ("result_source_sha256", "result_source_path", "result_dest_path")
PLACEMENT_SET = ("result_sha256",) + PLACEMENT_FIELDS
# Rule (13): a refusal token, e.g. LOGIN-PROBE-NOT-OK or RESULT-PLACEMENT-DESTINATION-PRESENT.
REFUSAL_RX = re.compile(r"\A[A-Z0-9]+(?:-[A-Z0-9]+)*\Z")
# Rule (16): what opens like a stamp, the one form a stamp is written in, the run a malformed one is shown by, and a
# clock-only time.
TIME_OPEN_RX = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:")
TIME_FULL_RX = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})"
                          r"(?:\.([0-9]{1,9}))?(?:Z|\+00:00)")
TIME_RUN_RX = re.compile(r"[0-9A-Za-z:.+-]*")
CLOCK_ONLY_RX = re.compile(r"(?<![0-9])(?<![0-9][:.])[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z(?![0-9A-Za-z])")
TIME_FORM = "YYYY-MM-DDTHH:MM:SS with 0 to 9 fractional digits and Z or +00:00"
# Rule (17): how far the line's own ts may stand from this composer's clock at the write.
TS_WINDOW_SECONDS = 120
# Rule (18): the keys only this file stamps beside composed_by, and how the two files they are read from are read.
MODEL_KEYS = ("runner_model", "validator_model_reported", "model_note")
MODEL_ID_RX = re.compile(r"(?m)^model_id:(.*)$")
IDENTITY_RX = re.compile(r"\Avalidator_identity:(.*)\Z")
# A model id is a run of these characters. MODEL_AFTER_RX reads the word "model", then at least one blank, colon or
# equals sign, then at most two opening quote, backtick or bracket characters, and the token after them: so
# `model "x"` and `model [x]` name x, and the apostrophe of "the model's" opens nothing.
MODEL_CHARS = r"A-Za-z0-9._\[\]:/@-"
MODEL_AFTER_RX = re.compile(r"(?i)(?<![A-Za-z0-9_-])model(?![A-Za-z0-9_-])[\s:=]+[\"'`(\[{<]{0,2}"
                            r"([A-Za-z0-9][" + MODEL_CHARS + r"]*)")
# git reads these from the environment: the first seven would answer for another repository, the rest would inject
# configuration into the calls below.
GIT_REDIRECTS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_OBJECT_DIRECTORY",
                 "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE", "GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT")


class Refused(Exception):
    def __init__(self, reasons):
        Exception.__init__(self, "; ".join(reasons))
        self.reasons = list(reasons)


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


def _refuse_constant(token):
    raise ValueError("NaN or Infinity is not JSON (" + token + ")")


def _finite_float(token):
    value = float(token)
    if math.isinf(value) or math.isnan(value):
        raise ValueError("the number " + token[:40] + " reads as infinite")
    return value


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
        obj = json.loads(text, object_pairs_hook=_unique_pairs, parse_constant=_refuse_constant,
                         parse_float=_finite_float)
    except (ValueError, RecursionError) as exc:
        first = (str(exc).splitlines() or [""])[0][:200]
        return None, "the line is not one JSON object (" + first + ")"
    if not isinstance(obj, dict):
        return None, "the line is JSON but not an object (a " + type(obj).__name__ + ")"
    return obj, None


def has_lone_surrogate(text):
    """A code point in D800-DFFF: json.loads joins a valid escaped pair into one code point beyond U+FFFF, so any
    surrogate left in a decoded string is unpaired."""
    return any(0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def parser_safety(value, why, where="the line", depth=1):
    """Rule (2): what Windows PowerShell 5.1's ConvertFrom-Json rejects or drops, found anywhere in the value.
    depth counts CONTAINERS: the line's own object is 1, and a scalar adds nothing."""
    if isinstance(value, (dict, list)) and depth > DEPTH_MAX:
        why.append(where + " nests deeper than " + str(DEPTH_MAX))
        return
    if isinstance(value, dict):
        folded = {}
        for key, item in value.items():
            if key == "":
                why.append(where + " carries an empty key")
            low = key.casefold()
            if low in folded:
                why.append(where + " carries the keys " + ascii(folded[low]) + " and " + ascii(key) +
                           ", equal ignoring case")
            folded[low] = key
            if low in PS_RESERVED:
                why.append(where + " carries the key " + ascii(key) + ", a name PowerShell reserves")
            if low == PS_TYPE_KEY:
                why.append(where + " carries the key " + ascii(key) + ", which PowerShell's JSON reader takes as a "
                           "type name (it throws on an object or array value and drops the key over a string or a "
                           "number)")
            if has_lone_surrogate(key):
                why.append(where + " carries the key " + ascii(key) + ", which holds an unpaired surrogate that "
                           "PowerShell's JSON reader replaces with U+FFFD")
            parser_safety(item, why, "the value of " + ascii(key), depth + 1)
    elif isinstance(value, list):
        for item in value:
            parser_safety(item, why, where, depth + 1)
    elif isinstance(value, str):
        if has_lone_surrogate(value):
            why.append(where + " holds a string with an unpaired surrogate, which PowerShell's JSON reader replaces "
                       "with U+FFFD")
    elif isinstance(value, bool) or value is None:
        return
    elif isinstance(value, int):
        if value < INT64_MIN or value > INT64_MAX:
            why.append(where + " carries the integer " + show(value) + ", outside the signed 64-bit range")
    elif isinstance(value, float):
        if math.isinf(value) or math.isnan(value) or abs(value) > FLOAT_MAX:
            why.append(where + " carries the number " + show(value) + ", beyond 1e308")


def written_form(obj):
    """The one form append writes: compact, ASCII, the keys in their order."""
    return json.dumps(obj, ensure_ascii=True, separators=(",", ":"), allow_nan=False)


def is_round(value):
    return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= ROUND_MAX


def is_seq(value):
    return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= SEQ_MAX


def placement_line(obj):
    """Rule (12), the line's own half, applied by append and by audit: every field of the set present, both hashes
    64 lowercase hex and EQUAL, both paths non-empty strings."""
    why = []
    for field in PLACEMENT_SET:
        if field not in obj:
            why.append("a complete line declaring a placement carries no " + field)
    for field in ("result_sha256", "result_source_sha256"):
        if field in obj and not (isinstance(obj[field], str) and SHA256_RX.match(obj[field])):
            why.append(field + " " + show(obj[field]) + " is not 64 lowercase hex")
    for field in ("result_source_path", "result_dest_path"):
        if field in obj and not (isinstance(obj[field], str) and obj[field] != ""):
            why.append(field + " " + show(obj[field]) + " is not a non-empty string")
    if not why and obj["result_sha256"] != obj["result_source_sha256"]:
        why.append("result_sha256 " + obj["result_sha256"] + " and result_source_sha256 " + obj["result_source_sha256"] +
                   " differ: the copy the line binds is not the source")
    return why


def placement_on_disk(obj):
    """Rule (12), append's half, taken at the moment of the act: the copy the line binds is the file at
    result_dest_path, now. Called only when the line's own half holds."""
    dest = obj["result_dest_path"]
    if not os.path.isabs(dest):
        return ["result_dest_path " + ascii(dest) + " is not an absolute path, so the copy it names cannot be found"]
    if not os.path.isfile(dest):
        return ["no file at result_dest_path " + ascii(dest) + " -- the placed copy is absent"]
    try:
        with open(dest, "rb") as handle:
            found = hashlib.sha256(handle.read()).hexdigest()
    except OSError as exc:
        return ["the file at result_dest_path " + ascii(dest) + " cannot be read (" + exc.__class__.__name__ + ")"]
    if found != obj["result_sha256"]:
        return ["the file at result_dest_path " + ascii(dest) + " hashes to " + found + ", not result_sha256 " +
                obj["result_sha256"]]
    return []


def refusal_note(obj):
    """Rule (13): the form of the note the runner writes for a refusal it decides."""
    why = []
    token = obj["refusal"]
    if not (isinstance(token, str) and REFUSAL_RX.match(token)):
        why.append("a refusal note's refusal " + show(token) + " is not a token of A-Z and 0-9 in hyphen-joined parts")
    for field in ("dispatch_id", "reason"):
        if field not in obj:
            why.append("a refusal note carries no " + field)
        elif not (isinstance(obj[field], str) and obj[field].strip() != ""):
            why.append("a refusal note's " + field + " " + show(obj[field]) + " is not a non-empty string")
    if "runner_exit" not in obj:
        why.append("a refusal note carries no runner_exit")
    elif not (isinstance(obj["runner_exit"], int) and not isinstance(obj["runner_exit"], bool)):
        why.append("a refusal note's runner_exit " + show(obj["runner_exit"]) + " is not a JSON integer")
    return why


def refusal_complete(obj):
    """Rule (14): a complete line that names a refusal carries rule (13)'s fields and binds no result."""
    why = []
    token = obj["refusal"]
    if not (isinstance(token, str) and REFUSAL_RX.match(token)):
        why.append("a complete line's refusal " + show(token) + " is not a token of A-Z and 0-9 in hyphen-joined parts")
    for field in ("dispatch_id", "reason"):
        if field not in obj:
            why.append("a complete line naming a refusal carries no " + field)
        elif not (isinstance(obj[field], str) and obj[field].strip() != ""):
            why.append("a complete line naming a refusal carries a " + field + " " + show(obj[field]) +
                       " that is not a non-empty string")
    if "runner_exit" not in obj:
        why.append("a complete line naming a refusal carries no runner_exit")
    elif not (isinstance(obj["runner_exit"], int) and not isinstance(obj["runner_exit"], bool)):
        why.append("a complete line naming a refusal carries a runner_exit " + show(obj["runner_exit"]) +
                   " that is not a JSON integer")
    if obj.get("result_sha256") is not None:
        why.append("a complete line naming a refusal carries result_sha256 " + show(obj["result_sha256"]) +
                   ": a line that names a refusal binds no result")
    for field in PLACEMENT_FIELDS:
        if field in obj:
            why.append("a complete line naming a refusal carries " + field +
                       ": a line that names a refusal declares no placement")
    return why


def null_result_named(obj):
    """Rule (15), append's alone: a complete line whose result_sha256 is JSON null names its refusal."""
    if (obj.get("event") == "complete" and "result_sha256" in obj and obj["result_sha256"] is None
            and "refusal" not in obj):
        return ["a complete line whose result_sha256 is JSON null carries no refusal: a line that binds no result "
                "names the refusal that left it so, in rule (14)'s form"]
    return []


def time_instant(match):
    """The instant a full stamp names, or None where its fields name none (a 30th of February, an hour 25)."""
    year, month, day, hour, minute, second = (int(match.group(index)) for index in range(1, 7))
    micro = int(((match.group(7) or "") + "000000")[:6])
    try:
        return datetime.datetime(year, month, day, hour, minute, second, micro, tzinfo=datetime.timezone.utc)
    except ValueError:
        return None


def time_faults(text):
    """Rule (16) over ONE string: each token that opens like a stamp and is not one, and each clock-only time."""
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


def time_form(value, why, path="", depth=1):
    """Rule (16), append's alone: every string and every key of the caller's object, at every depth rule (2) admits."""
    if isinstance(value, (dict, list)) and depth > DEPTH_MAX:
        return
    if isinstance(value, dict):
        for key, item in value.items():
            for fault in time_faults(key):
                why.append("the key " + ascii(key) + (" of " + path if path else "") + " " + fault)
            time_form(item, why, path + "." + key if path else key, depth + 1)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            time_form(item, why, path + "[" + str(index) + "]", depth + 1)
    elif isinstance(value, str):
        for fault in time_faults(value):
            why.append((path or "the line") + " " + fault)


def own_clock(obj, now):
    """Rule (17), append's alone: the line's own ts, where it carries one, is this composer's clock at the write."""
    if "ts" not in obj:
        return []
    ts = obj["ts"]
    full = TIME_FULL_RX.fullmatch(ts) if isinstance(ts, str) else None
    instant = time_instant(full) if full is not None else None
    if instant is None:
        return ["ts " + show(ts) + " is not the clock at the write: it is not a full RFC 3339 UTC stamp (" +
                TIME_FORM + ")"]
    apart = abs((instant - now).total_seconds())
    if apart > TS_WINDOW_SECONDS:
        return ["ts " + show(ts) + " is not the clock at the write: it stands " + str(int(apart)) + " s from this "
                "composer's clock, " + now.strftime("%Y-%m-%dT%H:%M:%SZ") + ", and " + str(TS_WINDOW_SECONDS) +
                " s is the most admitted"]
    return []


def mission_root_of(ledger):
    """The mission root of a ledger that sits at <root>/.mission-runtime/lam/<file>, or None."""
    lam = os.path.dirname(os.path.abspath(ledger))
    runtime = os.path.dirname(lam)
    if (os.path.normcase(os.path.basename(lam)) == "lam"
            and os.path.normcase(os.path.basename(runtime)) == ".mission-runtime"):
        return os.path.dirname(runtime)
    return None


def unquoted(text):
    """One YAML scalar on one line, its single or double quotes removed."""
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] == "'":
        return text[1:-1].replace("''", "'")
    if len(text) >= 2 and text[0] == text[-1] == '"':
        return text[1:-1]
    return text


def anchors_model(obj, ledger, mission_root):
    """Rule (18): (the anchors' model_id, reasons) for a complete line that names its anchors, taken at the moment
    of the act; (None, []) for a line that names none."""
    path = obj.get("anchors_path")
    sha = obj.get("anchors_sha256")
    if path is None and sha is None:
        return None, []
    why = []
    if path is None:
        why.append("a complete line naming its anchors carries no anchors_path beside its anchors_sha256")
    elif not (isinstance(path, str) and path.strip() != ""):
        why.append("a complete line naming its anchors carries an anchors_path " + show(path) +
                   " that is not a non-empty string")
    if sha is None:
        why.append("a complete line naming its anchors carries no anchors_sha256 beside its anchors_path")
    elif not (isinstance(sha, str) and SHA256_RX.match(sha)):
        why.append("a complete line naming its anchors carries an anchors_sha256 " + show(sha) +
                   " that is not 64 lowercase hex")
    if why:
        return None, why
    full = path
    if not os.path.isabs(path):
        root = mission_root or mission_root_of(ledger)
        if not root:
            return None, ["anchors_path " + ascii(path) + " is relative and the ledger does not sit at "
                          "<root>/.mission-runtime/lam, so the anchors it names cannot be found (name the root "
                          "with --mission-root)"]
        full = os.path.join(root, *[part for part in re.split(r"[\\/]+", path) if part])
    if not os.path.isfile(full):
        return None, ["no file at anchors_path " + ascii(full) + " -- the anchors the line names are absent"]
    try:
        with open(full, "rb") as handle:
            data = handle.read()
    except OSError as exc:
        return None, ["the file at anchors_path " + ascii(full) + " cannot be read (" + exc.__class__.__name__ + ")"]
    found = hashlib.sha256(data).hexdigest()
    if found != sha:
        return None, ["the file at anchors_path " + ascii(full) + " hashes to " + found + ", not anchors_sha256 " +
                      sha]
    ids = [value for value in (unquoted(raw) for raw in MODEL_ID_RX.findall(data.decode("utf-8-sig", "replace")))
           if value != ""]
    if len(ids) != 1:
        return None, ["the anchors at " + ascii(full) + " carry " + str(len(ids)) + " column-0 model_id line(s) "
                      "holding a value, and exactly one is read: the runner's model argument cannot be taken from "
                      "them"]
    return ids[0], []


def identity_scalar(text):
    """The column-0 validator_identity scalar of a result file, or None where the file carries none. Read by a stated
    SUBSET of YAML, not by a YAML parser: a single-quoted, double-quoted, plain or block scalar, its continuation
    lines folded with one space; the first such key is the one read."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        opened = IDENTITY_RX.match(line)
        if opened is None:
            continue
        head = opened.group(1).strip()
        tail = []
        for more in lines[index + 1:]:
            if more.strip() != "" and more[:1] not in (" ", "\t"):
                break
            tail.append(more.strip())
        folded = [part for part in tail if part != ""]
        if head[:1] in ("'", '"'):
            quote = head[0]
            body = " ".join([head[1:]] + folded)
            out = []
            at = 0
            while at < len(body):
                if quote == "'" and body[at:at + 2] == "''":
                    out.append("'")
                    at += 2
                    continue
                if quote == '"' and body[at] == "\\" and at + 1 < len(body):
                    out.append(body[at + 1])
                    at += 2
                    continue
                if body[at] == quote:
                    break
                out.append(body[at])
                at += 1
            value = "".join(out)
        elif head[:1] in ("|", ">"):
            value = " ".join(folded)
        else:
            value = " ".join([re.sub(r"\s+#.*\Z", "", head)] + folded)
        value = value.strip()
        return None if value in ("", "~", "null", "Null", "NULL") else value
    return None


def reported_model(identity, runner_model):
    """Rule (18): the model a validator_identity scalar reports -- the runner's where it stands there as a whole
    token, else the token after the word "model" -- bare, or inside quotes, backticks or brackets -- else None."""
    text = identity or ""
    # WHOLE: nothing directly beside the id could make it part of a longer one -- no letter, digit, `.`, `_` or `-`
    # before it; no letter, digit, `_`, `-` or `[` after it; and no `.`, `:`, `/` or `@` after it that a letter or a
    # digit follows. So `x: prose`, `prefix:x` and `[x]` hold x whole, and `x-5`, `x.5`, `x[1m]` and `x:tag` do not.
    whole = re.search(r"(?<![A-Za-z0-9._-])" + re.escape(runner_model) +
                      r"(?![A-Za-z0-9_\[-]|[.:/@][A-Za-z0-9])", text)
    if whole is not None:
        return runner_model
    named = MODEL_AFTER_RX.search(text)
    if named is None:
        return None
    token = named.group(1).rstrip(".:")
    # A bracket that closes one opened BEFORE the token is not the token's: `model [x]` names x, `x[1m]` keeps its own.
    while token.endswith("]") and token.count("]") > token.count("["):
        token = token[:-1].rstrip(".:")
    return token or None


def model_keys(obj, ledger, mission_root, placed):
    """Rule (18), append's alone: (the keys this file stamps before composed_by, reasons). `placed` says the line
    declares a placement and rule (12) found its copy on disk."""
    if obj.get("event") != "complete":
        return {}, []
    runner_model, why = anchors_model(obj, ledger, mission_root)
    if why or runner_model is None:
        return {}, why
    stamps = {"runner_model": runner_model}
    if placed:
        try:
            with open(obj["result_dest_path"], "rb") as handle:
                data = handle.read()
        except OSError as exc:
            return {}, ["the placed copy at result_dest_path cannot be read for its validator_identity (" +
                        exc.__class__.__name__ + ")"]
        if hashlib.sha256(data).hexdigest() != obj["result_sha256"]:
            return {}, ["the placed copy at result_dest_path changed between its two reads: the bytes its "
                        "validator_identity would be read from are not result_sha256"]
        text = data.decode("utf-8-sig", "replace")
        identity = identity_scalar(text)
        reported = reported_model(identity, runner_model)
        stamps["validator_model_reported"] = reported
        if identity is None:
            stamps["model_note"] = ("NO MODEL REPORTED: the runner's argument was " + runner_model +
                                    "; the placed result carries no validator_identity")
        elif reported is None:
            stamps["model_note"] = ("NO MODEL REPORTED: the runner's argument was " + runner_model +
                                    "; the result's validator_identity names no model")
        elif reported != runner_model:
            stamps["model_note"] = ("MODEL DIFFERENCE: the runner's argument was " + runner_model +
                                    "; the result's validator_identity reports " + reported)
    return stamps, []


def check(obj, mode, admitted=frozenset(), seen=None):
    """THE CHECK. mode is 'append' (the caller's object) or 'audit' (a line). seen maps 'spawn' and 'complete' to
    the seqs earlier lines carry. Returns the reasons, [] if none."""
    why = []
    seen = seen or {}
    parser_safety(obj, why)
    for key in obj:
        if not TOP_KEY_RX.match(key):
            why.append("the top-level key " + ascii(key) + " is not written in a-z, 0-9 and _ only")
    event = obj.get("event")
    if "event" not in obj:
        why.append("no event")
    elif event not in EVENTS:
        why.append("event " + show(event) + " is not spawn, complete or note")
    if event in ("spawn", "complete"):
        if "seq" not in obj:
            why.append("a " + event + " line with no seq")
        elif not is_seq(obj["seq"]):
            why.append("seq " + show(obj["seq"]) + " is not a JSON integer from 1 to " + str(SEQ_MAX))
        elif obj["seq"] in seen.get(event, ()):
            why.append("seq " + str(obj["seq"]) + " already has a " + event + " line on the ledger")
    if "round" in obj:
        rnd = obj["round"]
        if isinstance(rnd, int) and not isinstance(rnd, bool):
            if not is_round(rnd):
                why.append("round " + show(rnd) + " is outside 1.." + str(ROUND_MAX))
        else:
            why.append("round " + show(rnd) + " is not a JSON integer (a label goes in round_label)")
    elif event == "complete" and "validates" in obj:
        why.append("a complete line that carries validates carries no round")
    if "round_label" in obj:
        label = obj["round_label"]
        if not isinstance(label, str) or label == "":
            why.append("round_label " + show(label) + " is not a non-empty string")
        if not is_round(obj.get("round")):
            why.append("round_label " + show(label) + " does not stand beside an integer round")
    if "round_number" in obj:
        why.append("round_number " + show(obj["round_number"]) + " is present: the integer lives in round, and "
                   "round_number is the legacy carrier amendment 50's fallback reads")
    if event == "complete" and any(field in obj for field in PLACEMENT_FIELDS):
        why.extend(placement_line(obj))
    if event == "note" and "refusal" in obj:
        why.extend(refusal_note(obj))
    if event == "complete" and "refusal" in obj:
        why.extend(refusal_complete(obj))

    if mode == "append":
        if "composed_by" in obj:
            why.append("composed_by is supplied by the caller: only " + COMPOSER_PATH + " stamps it")
        for key in MODEL_KEYS:
            if key in obj:
                why.append(key + " is supplied by the caller: only " + COMPOSER_PATH + " stamps it")
    else:
        stamp = obj.get("composed_by")
        if "composed_by" not in obj:
            why.append("no composed_by: this line was not written by " + COMPOSER_PATH)
        else:
            m = STAMP_RX.match(stamp) if isinstance(stamp, str) else None
            if m is None:
                why.append("composed_by " + show(stamp) + " does not read " + COMPOSER_PATH + "@<8 hex>")
            elif not any(blob.startswith(m.group(1)) for blob in admitted):
                why.append("composed_by names blob " + m.group(1) + ", which is not an admitted blob of " +
                           COMPOSER_PATH)
    return why


def git(directory, args, stdin=None):
    env = dict(os.environ)
    for name in list(env):
        if name in GIT_REDIRECTS or name.startswith("GIT_CONFIG_KEY_") or name.startswith("GIT_CONFIG_VALUE_"):
            env.pop(name, None)
    try:
        proc = subprocess.run(["git", "-C", directory] + list(args), input=stdin, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, env=env)
    except OSError as exc:
        return 127, "", str(exc)
    return proc.returncode, proc.stdout.decode("utf-8", "replace"), proc.stderr.decode("utf-8", "replace")


def blob_id(data):
    lf = data.replace(b"\r\n", b"\n")
    return hashlib.sha1(b"blob " + str(len(lf)).encode("ascii") + b"\0" + lf).hexdigest()


def repository():
    """(top, reasons): the repository this file sits in, and whether this file is its tools/lam/spawn_ledger.py."""
    here = os.path.dirname(os.path.realpath(__file__))
    code, out, _ = git(here, ["rev-parse", "--show-toplevel"])
    if code != 0 or not out.strip():
        return None, ["this composer is not inside a git repository (git rev-parse --show-toplevel: exit " +
                      str(code) + ")"]
    top = os.path.realpath(out.strip())
    expect = os.path.normcase(os.path.realpath(os.path.join(top, *COMPOSER_PATH.split("/"))))
    if os.path.normcase(os.path.realpath(__file__)) != expect:
        return top, ["this copy is not " + COMPOSER_PATH + " of the repository at " + top]
    return top, []


def admitted_blobs(top):
    """(blobs, refs read, reasons): every blob COMPOSER_PATH has had at a commit rev-list names from HEAD and main."""
    starts = ["HEAD"]
    code, _, _ = git(top, ["rev-parse", "--verify", "--quiet", "refs/heads/main"])
    if code == 0:
        starts.append("refs/heads/main")
    code, out, _ = git(top, ["rev-list", "--full-history"] + starts + ["--", COMPOSER_PATH])
    if code != 0:
        return set(), starts, ["git rev-list of " + COMPOSER_PATH + " in " + top + " failed (exit " + str(code) + ")"]
    commits = [c for c in out.split() if SHA1_RX.match(c)]
    blobs = set()
    if commits:
        query = "".join(c + ":" + COMPOSER_PATH + "\n" for c in commits).encode("ascii")
        code, out, _ = git(top, ["cat-file", "--batch-check=%(objectname) %(objecttype)"], stdin=query)
        if code != 0:
            return set(), starts, ["git cat-file in " + top + " failed (exit " + str(code) + ")"]
        for line in out.splitlines():
            fields = line.split()
            if len(fields) == 2 and fields[1] == "blob" and SHA1_RX.match(fields[0]):
                blobs.add(fields[0])
    return blobs, starts, []


def provenance():
    """(own blob id, admitted blobs, reasons). Non-empty reasons: this copy may not stamp a line."""
    top, why = repository()
    if why:
        return None, set(), why
    with open(os.path.realpath(__file__), "rb") as handle:
        own = blob_id(handle.read())
    blobs, _, why = admitted_blobs(top)
    if why:
        return own, blobs, why
    if own not in blobs:
        return own, blobs, ["this composer's bytes (blob " + own[:8] + ") are not an admitted version of " +
                            COMPOSER_PATH + " (committed in the history of HEAD or main): an edited, uncommitted "
                            "or copied composer stamps nothing"]
    return own, blobs, []


def seqs_on(raw):
    """The seqs the spawn and complete lines of a ledger's bytes carry, read leniently (legacy lines included)."""
    seen = {"spawn": set(), "complete": set()}
    for part in raw.split(b"\n"):
        try:
            obj = json.loads(part.decode("utf-8"))
        except (ValueError, UnicodeDecodeError, RecursionError):
            continue
        if isinstance(obj, dict) and obj.get("event") in seen and is_seq(obj.get("seq")):
            seen[obj["event"]].add(obj["seq"])
    return seen


def append_record(ledger, obj, mission_root=None):
    """Check, stamp and append ONE object. Returns (line number, line). Raises Refused before any write."""
    raw = None
    why = []
    if not os.path.isfile(ledger):
        why.append("no ledger file at " + ledger + " (the composer appends to an existing file and creates none)")
    else:
        with open(ledger, "rb") as handle:
            raw = handle.read()
        if raw and not raw.endswith(b"\n"):
            why.append("the ledger's last byte is not LF, so an appended line would join the line before it")
    seen = seqs_on(raw) if raw else {}
    why = check(obj, "append", seen=seen) + why
    placed = False
    if obj.get("event") == "complete" and any(field in obj for field in PLACEMENT_FIELDS) and not placement_line(obj):
        on_disk = placement_on_disk(obj)
        why.extend(on_disk)
        placed = not on_disk
    # Rules (15) to (18): append's alone, over the caller's object, at the moment of the act.
    why.extend(null_result_named(obj))
    time_form(obj, why)
    why.extend(own_clock(obj, datetime.datetime.now(datetime.timezone.utc)))
    stamps, unread = model_keys(obj, ledger, mission_root, placed)
    why.extend(unread)
    own, blobs, prov = provenance()
    why.extend(prov)
    if why:
        raise Refused(why)
    stamped = dict(obj)
    stamped.update(stamps)
    stamped["composed_by"] = COMPOSER_PATH + "@" + own[:8]
    try:
        line = written_form(stamped)
    except (TypeError, ValueError) as exc:
        raise Refused(["the line cannot be written as JSON (" + str(exc)[:120] + ")"])
    again, bad = parse_line(line)
    post = [bad] if bad else check(again, "audit", blobs, seen)
    if post:
        raise Refused(["the composed line would fail the audit: " + "; ".join(post)])
    count = (raw or b"").count(b"\n") + 1
    with open(ledger, "ab") as handle:
        handle.write((line + "\n").encode("ascii"))
    return count, line


def run_append(args):
    try:
        raw = open(args.line_file, "rb").read()
    except OSError as exc:
        emit("REFUSED: the line file cannot be read (" + exc.__class__.__name__ + ") -- nothing was appended to " +
             args.ledger)
        return 2
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        emit("REFUSED: the line file is not UTF-8 -- nothing was appended to " + args.ledger)
        return 2
    obj, bad = parse_line(text)
    if bad:
        emit("REFUSED: " + bad + " -- nothing was appended to " + args.ledger)
        return 2
    try:
        count, line = append_record(args.ledger, obj, args.mission_root)
    except Refused as exc:
        emit("REFUSED: " + "; ".join(exc.reasons) + " -- nothing was appended to " + args.ledger)
        return 2
    emit("APPENDED line " + str(count) + " to " + args.ledger + ": " + line)
    return 0


def run_stamp(_args):
    own, _, why = provenance()
    if why:
        emit("REFUSED: " + "; ".join(why))
        return 2
    emit("composed_by: " + COMPOSER_PATH + "@" + own[:8])
    return 0


def run_audit(args):
    if args.after < 0:
        emit("AUDIT CANNOT RUN: --after must be 0 or more, not " + str(args.after))
        return 2
    pinned = args.prefix_sha256.lower()
    if not SHA256_RX.match(pinned):
        emit("AUDIT CANNOT RUN: --prefix-sha256 is not 64 hex digits")
        return 2
    try:
        raw = open(args.ledger, "rb").read()
    except OSError as exc:
        emit("AUDIT CANNOT RUN: the ledger cannot be read at " + args.ledger + " (" + exc.__class__.__name__ + ")")
        return 2
    parts = raw.split(b"\n")
    terminated = raw.endswith(b"\n") or raw == b""
    parts = parts[:-1]
    if not terminated:
        parts.append(raw.rsplit(b"\n", 1)[-1])
    total = len(parts)
    whole_lines = total if terminated else total - 1
    after = args.after
    emit("AUDIT ledger=" + args.ledger + " lines=" + str(total) + " bytes=" + str(len(raw)) + " sha256=" +
         hashlib.sha256(raw).hexdigest() + " cutoff=" + str(after))
    failures = 0
    if after > whole_lines:
        failures += 1
        emit("PREFIX FAIL: the ledger holds " + str(whole_lines) + " LF-terminated line(s), fewer than the cutoff " +
             str(after) + " -- lines at or before the cutoff are gone or were never written")
    else:
        prefix = b"".join(parts[i] + b"\n" for i in range(after))
        got = hashlib.sha256(prefix).hexdigest()
        same = got == pinned
        if not same:
            failures += 1
        emit("PREFIX lines 1-" + str(after) + " sha256=" + got + " pinned=" + pinned + " " +
             ("EQUAL" if same else "DIFFERS -- a line at or before the cutoff was changed, removed or inserted"))
    legacy = []
    seen = {"spawn": set(), "complete": set()}
    for i in range(min(after, total)):
        try:
            obj = json.loads(parts[i].decode("utf-8"))
        except (ValueError, UnicodeDecodeError, RecursionError):
            legacy.append("LEGACY line " + str(i + 1) + ": not a JSON line")
            continue
        if not isinstance(obj, dict):
            continue
        if obj.get("event") in seen and is_seq(obj.get("seq")):
            seen[obj["event"]].add(obj["seq"])
        if "round" in obj and not is_round(obj["round"]):
            legacy.append("LEGACY line " + str(i + 1) + ": event=" + show(obj.get("event")) + " seq=" +
                          show(obj.get("seq")) + " round=" + show(obj["round"]) + " round_number=" +
                          (show(obj["round_number"]) if "round_number" in obj else "absent"))
    emit("LEGACY lines 1-" + str(min(after, total)) + ": " + str(min(after, total)) + " line(s) admitted without the "
         "check (forward-only); " + str(len(legacy)) + " of them named below")
    for text in legacy:
        emit(text)
    checked = max(0, total - after)
    blobs = frozenset()
    if checked:
        top, why = repository()
        starts = []
        if not why:
            found, starts, why = admitted_blobs(top)
            blobs = frozenset(found)
        if why:
            emit("AUDIT CANNOT RUN: " + "; ".join(why))
            return 2
        emit("AFTER lines " + str(after + 1) + "-" + str(total) + ": " + str(checked) + " line(s) checked against " +
             str(len(blobs)) + " admitted blob(s) of " + COMPOSER_PATH + " (from " + " and ".join(starts) + ")")
    else:
        emit("AFTER none: 0 line(s) after line " + str(after))
    for i in range(after, total):
        why = []
        obj = None
        if i == total - 1 and not terminated:
            why.append("the line is not terminated by LF")
        try:
            text = parts[i].decode("utf-8")
        except UnicodeDecodeError:
            text = None
            why.append("the line is not UTF-8")
        if text is not None:
            if text.strip() == "":
                why.append("an empty line")
            else:
                obj, bad = parse_line(text)
                if bad:
                    why.append(bad)
                else:
                    why.extend(check(obj, "audit", blobs, seen))
                    # rule (11): the composer's own form, byte for byte, and no CR.
                    if "\r" in text:
                        why.append("the line carries a CR byte, which both readers take as a line break")
                    elif text != written_form(obj):
                        why.append("the line is not in the form the composer writes (compact, ASCII, keys in order)")
        if obj is not None and obj.get("event") in seen and is_seq(obj.get("seq")):
            seen[obj["event"]].add(obj["seq"])
        if why:
            failures += 1
            emit("VIOLATION line " + str(i + 1) + ": " + "; ".join(why))
    verdict = "PASS" if failures == 0 else "FAIL"
    emit("RESULT " + verdict + " after_cutoff=" + str(checked) + " violations=" + str(failures) +
         " legacy_named=" + str(len(legacy)))
    return 0 if failures == 0 else 1


def main(argv):
    parser = argparse.ArgumentParser(prog="spawn_ledger.py",
                                     description="Compose spawn-ledger lines, and audit the lines after a cutoff.")
    sub = parser.add_subparsers(dest="command")
    p_append = sub.add_parser("append", help="check, stamp and append ONE line")
    p_append.add_argument("--ledger", required=True)
    p_append.add_argument("--line-file", required=True, help="a UTF-8 file holding ONE JSON object")
    p_append.add_argument("--mission-root", default=None,
                          help="the mission root a relative anchors_path is read against (default: the ledger's own)")
    p_audit = sub.add_parser("audit", help="the forward-only audit of every line after the cutoff")
    p_audit.add_argument("--ledger", required=True)
    p_audit.add_argument("--after", required=True, type=int, help="the cutoff: the last legacy line number")
    p_audit.add_argument("--prefix-sha256", required=True, help="sha256 of the first N LF-terminated lines")
    sub.add_parser("stamp", help="print the composed_by value this copy stamps")
    args = parser.parse_args(argv)
    if args.command == "append":
        return run_append(args)
    if args.command == "audit":
        return run_audit(args)
    if args.command == "stamp":
        return run_stamp(args)
    parser.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
