# lam-smoke

A smoke mission BUILT by `tools/lam/build-smoke-mission.ps1` from the framework's shipped sources
(`tools/lam/smoke-mission/`). It exists so the acceptance instruments (WP-6 above all, WP-2 R-35a
and R-49, WP-3 C-2c) have a live mission to read: a git repository, its bare origin
`lam-smoke-origin.git` in the same parent folder, and the residue of one dispatch run, D-1 to D-3.

NO CLI WORKER, RUNNER, VALIDATOR OR OPERATOR MADE IT. The builder performed every act itself, in
order, with the framework's own tools: git for the commits, worktrees and the push; the evidence
hooks, driven with the payloads a session would send, for the evidence sessions, the denial record
and the prompt registers; `tools/lam/mission-gate.ps1 -ComposeOnly` for the gates; this mission's
`tools/mission-ceremony-record.ps1` for the ceremony. WP-6 S-1b is the one member that spawns a real
worker, at reading time, in a clone of this repository.

WHERE THE BUILDER IS NAMED, AND WHERE A RECORD'S SHAPE IS A TOOL'S. Named on the record itself: every
dispatch, handoff, anchors file, validator result, supersession marker and the isolation probe (each
says the builder wrote it, or did the work it records); each evidence session's OWNER file
(`runner_id: build-smoke-mission.ps1`, `model: none`) and the first line of its runner stream; the
calls in its log and stream, whose outputs say `build-smoke-mission.ps1 wrote ...`; the ledger's
ceremony entry (`author: build-smoke-mission.ps1`); every gate's first line (`BUILT, NOT MINTED`, and
`operator_credential: injected-seam` -- no operator confirmed it, and its `authorized_by` is a neutral
name, not a person); the root register's one operator-kind line, disclosed in
`.mission-runtime/disclosures/builder-diagnostic-prompt.md`. In a tool's own fixed shape, and named
only here: each worktree register's `kind=worker dispatch=<id>` line, which the prompt hook writes
whenever a dispatch marker is set -- the builder set it, and no prompt was submitted; the commit
dates, fixed at 2026-01-01 so the pushed history is the same on every machine, while the evidence,
the gates and the ledger carry the real time the builder ran; and `.git/hooks/pre-push`, which names
the decider of the checkout the builder ran from by its absolute path, as the pre-push checker
requires.

## Layout

| Path | Purpose |
|---|---|
| `.mission/` | Committed mission truth: spec, contract, goal, dispatches, handoffs, anchors, validator results, ledger. |
| `.mission/gates/` | Untracked, admitted: the two supersession ratifications and the one push gate (revoked). |
| `.mission/evidence/` | Untracked, admitted: the finalised sessions the stop finaliser published. |
| `.mission-runtime/` | Gitignored: the evidence sessions, the prompt register, the builder's disclosure. |
| `.claude/worktrees/` | Untracked, admitted: one worktree per dispatch, each with its own prompt register. |
| `tools/` | The ceremony wrapper, and the framework files it runs, copied in at build time. |
| `src/`, `tests/` | The product the dispatches built: a greeting file, a counter script and its test. |
