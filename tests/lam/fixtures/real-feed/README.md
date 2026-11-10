# The real-feed fixture

Three mission-event feeds: the two below, and the 1.2.0 slice (its own section). Two mission-event feeds (expanded-schemas SS14) cut from a real installed 1.1.0 upgrade, made neutral by shape-preserving
rules so that no host data is left in them:

- `wt-ui-1.events.jsonl` -- 155 lines, a worktree checkout's feed: 138 tool_call, 5 session_stop, 4 dispatch_finalized,
  3 session_start, 2 compact, 1 mission_snapshot, 1 verify_result, 1 tip_observed.
- `root.events.jsonl` -- 2 lines, the primary checkout's feed: 1 mission_snapshot, 1 session_stop.

They are RED material for the 1.1.0 dashboard patch: the mission_snapshot carries the spec words `done` (123 milestones)
and `withdrawn` (1) that the 1.1.0 writer passed through; the session whose session_start is at seq 38 of the worktree
feed has no session_stop; the dispatch_finalized lines carry `partial: true` beside `manifest_state: FINALIZED`. The
fixture is never edited to make a falsifier pass: a cure is proved by the cured code reading these bytes unchanged, or by
a line a test plants in its own copy.

## How the lines were derived (rules 1-5, applied in this order)

1. KEEP VERBATIM: `schema_version`, `seq`, `ts`, `kind`; every enum and status word (`done` and `withdrawn` included);
   every count and boolean; every field name; the line order; the `[HARD-n]` tokens the scrub left (already neutral).
   Each line is re-serialised in the emitter's own JSON form (compact, non-ASCII literal, `'` `<` `>` `&` written as
   `\u00xx`); every line of the sources re-serialises to its own bytes in that form before any value is changed.
2. IDS: every 40-hex string becomes the first 40 hex of sha256(K + id); a 7-to-12-hex token that is a prefix of
   such an id becomes the same-length prefix of its new id (none was found); every GUID becomes a GUID made of the
   first 32 hex of sha256(K + guid), grouped 8-4-4-4-12, wherever it stands (inside `dispatch_id` and `source_path`
   too). Every 64-hex digest (`sha256`, `transcript_sha256`) becomes sha256(K + digest) -- the files those digests
   name are not in the fixture. Equal inputs give equal outputs, so one session, one commit and one mission stay one.
   A short hex token that is no prefix of a mapped id is kept (here: `mission verify`'s random run id). K is the
   secret key of the 1.2.0 slice's rule (its section below), held outside this repository; the two feeds were
   re-derived under it from the same sources by these same rules (UI-2 S1, register row 529), so every byte outside
   the replaced ids is unchanged. The map is not part of this repository.
3. PATHS: an absolute Windows path is rewritten to `C:\work\project\` plus its tail, the root cut being the drive and
   the leading run of segments each of which is a `[HARD-n]` token or a user-profile segment (`Users`, `AppData`,
   `Local`, `LocalLow`, `Roaming`, `Temp`, `Documents`, `Desktop`, `Downloads`). Example:
   `C:\Users\[HARD-1]\AppData\Local\Temp\example\notes.md` becomes `C:\work\project\example\notes.md`.
4. FREE TEXT: every milestone title becomes `Milestone <id> title` (the only prose field the sources carry); ids such
   as `M-123`, `A-001`, `F-001` and `D-V-A-615` are structural and kept.
5. HASHES: the mission_snapshot's `snapshot_sha256` is recomputed last, by the writer's own rule
   (tools/lam/mission-telemetry.ps1: ConvertTo-MissionCanonicalJson over the payload without `snapshot_sha256`, every
   milestone's `started_ts` and `done_ts` null, hashed by Get-Sha256OfString). The schema defines no other per-line hash.

## The 1.2.0 slice (UI-2 S1, section B of its contract)

- `rec-q-1.2.0.events.jsonl` -- 199 lines, a primary checkout's 1.2.0 feed (seq 302-500 contiguous, file lines 302-500 of
  that checkout's `.mission-runtime/telemetry/events.jsonl` as the operator's record reads them, ledger 1767): 191
  tool_call, 7 session_stop, 1 dispatch_finalized; no session_start in the window. The six Agent calls are at seq 302-307;
  the seven session_stop lines (seq 413, 428, 433, 438, 451, 455, 499) all stamp ONE session id, and the dispatch_finalized
  (seq 414) names `session-<that id>`. Each of the six stops after seq 414 follows a `SubagentHandback` tool_call by under
  a second; seq 413 and 414 are 39 ms apart.

It is RED material for register row 500 (the shipped SubagentStop hook stamps the parent session's id): the session reads
stopped at seq 413 while its lines run on to seq 500, and its dispatch reads finalized at seq 414. WP-7 U-31 reads its
shape, U-32 its HARD scan, U-33 the defect's shape. The fixture is never edited to make a member pass.

How its lines were derived (the S1 contract's scrub rule, RELEASE-3 Q9 and RELEASE-4 ruling A): every HARD class to zero,
each value replaced by a stable synthetic OF THE SAME SHAPE (the same length and character class), so that equal inputs
give equal outputs and every identity relation of the source survives. The lines are edited as text, so the emitter's own
JSON form stands unchanged outside the replaced spans.

1. KEEP VERBATIM: `schema_version`, `seq`, `ts` (so the relative spacing is the source's), `kind`, every payload key and
   its order, every enum and status word, every count and boolean, `tool` names, the line order.
2. IDS: every GUID (`mission_id`, `host_id`, every session id, inside `dispatch_id` and `source_path` too) becomes a GUID
   made of the first 32 hex of sha256(K + guid), grouped 8-4-4-4-12; every 40-hex id (`commit`) becomes the first 40 hex
   of sha256(K + id); every 64-hex digest (`sha256`) becomes sha256(K + digest). An id that stands inside a path is mapped
   by the same rule, once.
3. PATHS (the `paths` of a tool_call): each segment is kept when it is a drive (`C:`) or one of `.mission-runtime`,
   `.mission`, `.claude`, `evidence`, `telemetry`, `tools`, `tests`, `docs`, `ui`, `src`; otherwise every letter becomes a
   letter and every digit a digit (lower stays lower, upper stays upper), drawn from sha256(K + "path:" + the segment +
   ":" + n), and every other character -- separators, `.`, `-`, `_` -- is kept; a known file extension is kept. The same
   segment becomes the same synthetic everywhere, so a path's length and shape are the source's.

K is a SECRET key (random, 256 bits), held outside this repository and recorded nowhere in it: with a published key the
rule would be the map itself, and a guessed host value could be confirmed against the slice with one hash (UI-2 S1
validator round 1). The map is not part of this repository either. The derivation was checked before the slice landed: no source id and no
source path fragment of five characters or more is left, every non-HARD value and every key equals the source's, and the
equality pattern of every HARD field (mission, host, commit, digest, session, dispatch, source path) is the source's.

## The gate reading

`tools/lam/gate-host-data.ps1 -Root tests/lam/fixtures/real-feed -PatternFile <the operator's HARD pattern file>`
reads HARD 0 over this folder; a scan of these files for every 40-hex id the sources carried reads 0.
