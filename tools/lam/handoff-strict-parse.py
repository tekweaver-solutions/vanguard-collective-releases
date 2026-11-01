#!/usr/bin/env python3
"""
HANDOFF STRICT PARSE -- hand one handoff artifact to a REAL YAML parser and report what it said.
Invoked by tools/lam/mission-dispatch.ps1; it is not a gate and has no opinion
about the handoff's schema.

WHY THIS EXISTS AS A SEPARATE PROGRAM. The runner is PowerShell 5.1, which ships no YAML parser,
and the runner's own Read-FlatYaml is a deliberate sub-YAML reader: it takes everything after the
FIRST colon as the value, so a plain scalar carrying ': ' satisfies it while a parser that
implements YAML refuses the same file with "mapping values are not allowed here". A build
handoff in exactly that state passes the runner's own reader, and
every downstream reader using a real parser is locked out of it. The cure is that the
runner's validator refuse what a YAML parser refuses -- so the runner has to ASK one.

THE PROTOCOL IS A SENTINEL LINE, NOT AN EXIT CODE. This program always exits 0 and always prints
exactly one line. The runner keys on the sentinel and treats the absence of one -- no python, a
python that cannot start, a deleted copy of this file -- as UNAVAILABLE rather than as a verdict.
That distinction is the whole reason the exit code is not the channel: a missing interpreter and a
malformed handoff must never look the same to the caller.

    ROW155-PARSE-OK
    ROW155-PARSE-ERR<TAB><problem, whitespace-collapsed><TAB><line><TAB><column>
    ROW155-PARSE-UNAVAILABLE<TAB><why no verdict could be reached>

Line and column are 1-BASED (PyYAML marks are 0-based) and are 0 when the exception carries no
mark. The bytes are handed to the parser UNDECODED so that the encoding, the BOM and any invalid
UTF-8 are the parser's problem exactly as they would be for any other reader of the artifact.
"""
import sys


def one_line(value):
    """Collapse to a single line: the sentinel is TAB-delimited and the runner reads it by line."""
    return " ".join(str(value).split())


def emit(text):
    sys.stdout.write(text + "\n")


def main(argv):
    if len(argv) != 2:
        emit("ROW155-PARSE-UNAVAILABLE\texactly one argument is required (the handoff path); got %d"
             % max(0, len(argv) - 1))
        return 0
    path = argv[1]

    try:
        import yaml
    except Exception as exc:  # ImportError, and anything a broken install raises on import
        emit("ROW155-PARSE-UNAVAILABLE\tPyYAML is not importable by %s: %s"
             % (one_line(sys.executable), one_line(exc)))
        return 0

    try:
        with open(path, "rb") as handle:
            raw = handle.read()
    except Exception as exc:
        emit("ROW155-PARSE-UNAVAILABLE\tthe handoff at %s could not be read: %s"
             % (one_line(path), one_line(exc)))
        return 0

    try:
        yaml.safe_load(raw)
    except Exception as exc:
        mark = getattr(exc, "problem_mark", None)
        line = mark.line + 1 if mark is not None else 0
        column = mark.column + 1 if mark is not None else 0
        problem = getattr(exc, "problem", None)
        if not problem:
            problem = "%s: %s" % (type(exc).__name__, exc)
        emit("ROW155-PARSE-ERR\t%s\t%d\t%d" % (one_line(problem), line, column))
        return 0

    emit("ROW155-PARSE-OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
