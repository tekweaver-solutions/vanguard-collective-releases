# Feedback memo — bootstrap-instructions improvements from a design-refinement stall

**Author:** claude-code (operator hat)
**Basis:** ADR-020 and ADR-021.
**Audience:** the framework maintainer responsible for the next revision of `bootstrap-instructions-for-claude-code.md`.
**Status:** A *memo*, not edits. Nothing in `bootstrap-instructions-for-claude-code.md` is being changed here. This document records what the next revision should incorporate, grounded in ADR-020 and ADR-021.

---

## What happened

A long-running Phase 4 (design refinement) of a bootstrap can stall silently: the spinner runs and the token counter looks alive, but no files are written. Filesystem timestamps reveal such a stall, and an incremental-commit checklist makes recovery cheap. The bootstrap document as it stands does not teach the operator how to detect such a stall, and does not require the design-refinement agent to commit incrementally. The three additions below close those gaps.

---

## Addition 1 — new "Stall diagnostics for the operator" subsection

**Placement.** After the existing rule *"Stop at the explicit checkpoint markers"* in the "Read this section before doing anything else" section. The rationale: checkpoints are precisely where the operator is supposed to pause and confirm, which is also where the risk of an agent stall-without-progress is highest (the operator is waiting, the agent is supposed to be working, and the failure mode is silent).

**Proposed text:**

> **Stall diagnostics for the operator.** Long-running agent operations can fail silently — the spinner keeps running and the token counter doesn't visibly stall, but no work lands on disk. If you suspect the agent is stuck rather than slow:
>
> 1. Check the in-UI token counter. If frozen for more than 5 minutes, that is a signal but not proof.
> 2. Check the spinner animation. If it has stopped animating, the UI itself is frozen.
> 3. *Most reliable:* open a separate shell, `cd` into the mission directory, and run:
>    - `git status` (look for changes you'd expect from the in-flight phase)
>    - `git log --oneline -5` (look for commits you'd expect)
>    - `ls -lat .mission/spec/proposals/` (or whichever directory the agent is supposed to be writing into) — check the most recent mtime
>
>    If no files in the relevant directory have been written or modified in the last 15+ minutes, the agent is stalled, not slow. Filesystem timestamps are the ground truth; the UI is not.
>
> When you confirm a stall: interrupt, capture what's on disk (it's the recovery starting point), and start a fresh session pointed at the same repo. The next session will pick up from committed artifacts per ADR-008's fresh-instance-per-iteration rule.

This subsection should reference ADR-020 / ADR-021 for the grounding.

---

## Addition 2 — Phase 4 protocol update: explicit incremental-commit checklist

**Placement.** The "Phase 4: Design refinement loop (if needed)" section, expanding step 3 ("Run it. Then act as the designer again, producing v002 (or vNNN). Same artifacts as Phase 3 step 3, but in `proposals/` with the incremented version number.")

**Proposed text** (replaces the current step 3 wording):

> 3. **Run the refinement script. Then act as the designer again, producing vNNN incrementally with commits at every artifact boundary.** Atomic generation of a full refinement (spec + 30+ assertions + design notes + operator review) in a single turn risks a silent multi-hour stall (per ADR-021). The required pattern is:
>
>    1. Plan the artifact set as a checklist (in the conversation, or in a transient `.mission-runtime/refinement-plan-NNN.md`).
>    2. **Draft `vNNN.yaml` → `git add` + `git commit`.** Commit message: `Design phase vNNN -- spec drafted`.
>    3. **Refine surviving prior-version assertions in place → `git add` + `git commit`.** Commit message: `Refine vN-1 contract assertions for vNNN milestone restructure`.
>    4. **Delete retired prior-version assertions → `git add` + `git commit`.** Commit message: `Retire vN-1 ... contract assertions [reason]`.
>    5. **Draft new assertions in batches of ~5-10 → `git add` + `git commit` per batch.** Commit message: `Add vNNN contract assertions for [scope additions]`.
>    6. **Reshape config artifacts** (e.g., `mcp-tools.yaml` per any Q-resolution) → `git add` + `git commit`.
>    7. **Write `design-notes-NNN.md` and `operator-review-NNN.md` → `git add` + `git commit`.** Commit message: `Add vNNN design notes and operator review`.
>    8. **`git log --oneline` review** before declaring Checkpoint 5 reached.
>
>    The exact step ordering can vary (some refinements may not retire assertions, or may not have a config reshape), but the **incremental-commit-per-artifact-boundary discipline is required, not optional**.
>
>    Why this matters: see ADR-021. Beyond stall avoidance, incremental commits make recovery from any kind of failure (your laptop crashes, you have to stop and restart, you discover a mistake) work artifact-by-artifact rather than from scratch.

---

## Addition 3 — Phase 4 protocol update: post-commit git-status verification

**Placement.** Same Phase 4 section, as a new step 4 (current step 4 becomes step 5).

**Proposed text** (new step):

> 4. **After every commit, run `git status` and verify the expected file is no longer in the untracked or unstaged list.** If it still appears modified or untracked, the commit failed silently (the most likely cause is a path mismatch in the `git add` command, but stalled-agent self-reports are also a possibility — see ADR-020). Do NOT proceed to the next artifact on the assumption the commit succeeded. Retry the `git add` + `git commit` with explicit paths; if it fails again, stop and surface the issue to the operator.
>
> This is a *protocol-level* equivalent of the runner-level filesystem verification ADR-020 prescribes for execution-phase workers. The bootstrap agent (Claude Code itself) does not run under the framework's worker-runner, so the structural enforcement is not available; the protocol is the next-best defense.

This should also be applied analogously to Phase 1, Phase 2, Phase 3, and Phase 5 wherever those phases ask the agent to commit. The Phase 4 version is the most consequential because Phase 4 has the largest commit volume.

---

## What this memo intentionally does NOT propose

- **No edits to `expanded-schemas.md`.** Per Section 9 of `local-orchestrator-mode.md`, schema changes require their own ADR; ADR-020 and ADR-021 do not require schema changes (`Handoff.commits[]` and `Handoff.commands_run[]` already exist and ADR-020 makes their use stricter).
- **No edits to `local-orchestrator-mode.md` itself yet.** The two new ADRs sit in `tools/mission-cli/config/` as drafts, paralleling ADR-019. When the framework maintainer folds them into the canonical ADR list (Section 3 of the design summary), the bootstrap document can reference them by ADR number directly. Until then, the bootstrap document can reference them by relative path or just by the rule they encode.
- **No revision to the auto-commit cadence of `mission-design-refine.ps1`.** The script (correctly) does not auto-commit; commits are the agent's responsibility per the incremental-commit pattern. Auto-commit by the script would couple the script to the agent's turn-by-turn behavior in a way that limits flexibility.
- **No proposal for a new "stall recovery" script or `mission resume` subcommand.** Recovery from a stalled session is naturally handled by the existing artifact-mediated batch-job design (ADR-008): a fresh designer reads the most recent committed artifacts and continues. Adding a separate recovery command would duplicate logic. If the framework later finds that recovery is sufficiently common to warrant tooling, it should be a thin wrapper around `mission-design-refine.ps1` that runs against the most recent committed state.

---

## Why all of this lands in a feedback memo, not as direct edits

`bootstrap-instructions-for-claude-code.md` lives in the parent project directory (`C:\work\`), not in this mission's repo. It is a framework-level document maintained outside the mission. Edits to it should be deliberate, reviewed framework-level changes, not byproducts of one mission's bootstrap. This memo is the right shape: the mission captures what it learned; the framework maintainer decides what to fold in.

If the framework maintainer also wants the bootstrap document to live under version control alongside the framework's ADRs (which would be a small but real improvement), that is a separate decision — flag for a future ADR.
