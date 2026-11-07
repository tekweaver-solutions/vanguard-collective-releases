# The real-feed fixture

Two mission-event feeds (expanded-schemas SS14) cut from a real installed 1.1.0 upgrade, made neutral by shape-preserving
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
2. IDS: every 40-hex string becomes the first 40 hex of sha256("release-4-neutral:" + id); a 7-to-12-hex token that
   is a prefix of such an id becomes the same-length prefix of its new id (none was found); every GUID becomes a GUID
   made of the first 32 hex of sha256("release-4-neutral:" + guid), grouped 8-4-4-4-12, wherever it stands (inside
   `dispatch_id` and `source_path` too). Every 64-hex digest (`sha256`, `transcript_sha256`) becomes
   sha256("release-4-neutral:" + digest) -- the files those digests name are not in the fixture. Equal inputs give equal
   outputs, so one session, one commit and one mission stay one. A short hex token that is no prefix of a mapped id is
   kept (here: `mission verify`'s random run id). The map is not part of this repository.
3. PATHS: an absolute Windows path is rewritten to `C:\work\project\` plus its tail, the root cut being the drive and
   the leading run of segments each of which is a `[HARD-n]` token or a user-profile segment (`Users`, `AppData`,
   `Local`, `LocalLow`, `Roaming`, `Temp`, `Documents`, `Desktop`, `Downloads`). Example:
   `C:\Users\[HARD-1]\AppData\Local\Temp\example\notes.md` becomes `C:\work\project\example\notes.md`.
4. FREE TEXT: every milestone title becomes `Milestone <id> title` (the only prose field the sources carry); ids such
   as `M-123`, `A-001`, `F-001` and `D-V-A-615` are structural and kept.
5. HASHES: the mission_snapshot's `snapshot_sha256` is recomputed last, by the writer's own rule
   (tools/lam/mission-telemetry.ps1: ConvertTo-MissionCanonicalJson over the payload without `snapshot_sha256`, every
   milestone's `started_ts` and `done_ts` null, hashed by Get-Sha256OfString). The schema defines no other per-line hash.

## The gate reading

`tools/lam/gate-host-data.ps1 -Root tests/lam/fixtures/real-feed -PatternFile <the operator's HARD pattern file>`
reads HARD 0 over this folder; a scan of these files for every 40-hex id the sources carried reads 0.
