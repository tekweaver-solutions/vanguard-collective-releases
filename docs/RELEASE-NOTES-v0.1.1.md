# Vanguard Collective 0.1.1 -- release notes

0.1.1 supersedes 0.1.0. It makes one change, in `install.ps1`: how a file already in the target is
judged against the framework's copy. Everything else is as the 0.1.0 notes describe it,
[docs/RELEASE-NOTES-v0.1.0.md](RELEASE-NOTES-v0.1.0.md): the framework files, `mission.ps1`, the
release ZIP and its 247 members, the standalone reading, and what RELEASE-1 adds. The 239 files the
installer places are byte for byte those of 0.1.0.

## Why

0.1.0 compared a target file's raw bytes with the framework's. Over a project that git had checked
out with `core.autocrlf=true`, whose text files stand on disk with CRLF line endings, it refused
nearly every file as not installed by the framework, although each differed only in its line
endings.

## The rule

1. A file is text if it contains no 0x00 byte; otherwise it is binary.
2. To fold a text file is to replace every CR LF pair with LF. A lone CR and a lone LF are left as
   they are. A binary file is never folded.
3. A file in the target is identical to the framework's copy when the sha256 of the two folded
   files is the same; for a binary file, when the raw sha256 is. The release's own files are still
   held to `provenance/manifest.jsonl` byte for byte.
4. What is written is unchanged: the framework's bytes. A file found identical is left as it is;
   its line endings are not rewritten.
5. Each line of `framework.lock` gains `eol`, the line endings the file showed when it was judged:
   `lf`, `crlf`, `mixed` (both CRLF and lone LF) or `binary`. Its sha256 is taken after folding. The
   header gains `"eol_rule":"fold-crlf-text"`; the lock still has one line per file, 240 in all.
6. `install.ps1 -Verify` judges by the same rule. Its last line also counts the lock's rows by
   `eol`.

Refusals, exit codes and the dispositions line are those of 0.1.0. A `framework.lock` written by
0.1.0 has no `eol_rule`, and its sha256s are of raw bytes. 0.1.1 still reads it: a file matches its
line raw, or after folding when no CR LF pair is left, which is exact for every file 0.1.0 wrote
without CRLF. Installing 0.1.1 over it rewrites it by the rule.
