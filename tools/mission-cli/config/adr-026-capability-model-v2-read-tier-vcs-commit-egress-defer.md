# ADR-026 — Capability Model v2: read-tier, worktree-commit, and egress-deferral

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** a post-run capability review, after the first write-capable dispatch surfaced that `worktree.write` grants file writes but not commits, that `shell.exec.*` capabilities are gateway-ALLOWed while their containment layer (C2) is unbuilt, and that benign read commands (`wc`, `find`) are denied because Bash is an all-or-nothing capability surface.
>
> **Empirical grounding:** a live-run report's findings that the worker reached for `wc -l` / `find` and was denied at the capability gate, and that the worker could not `git commit` and filed an honest zero-commit handoff; the C1/test.run bounds work (the gate predicates, the channel bounds, the hook composition, the combined `..`+symlink bypass fix); the recurring finding that the runner leaves the committed task-brief untracked.

---

## Decision

The capability model gains two new worker-grantable tags and one grant-level prohibition. All three build on the existing `command_allowlist.py` machinery (charset gate + program-membership + per-program path-position bounding) rather than introducing new enforcement surface. The model **extends** the implicit capability model defined in `mcp_capability_map.py` / `policy.py` / `command_allowlist.py`; it supersedes no prior ADR.

### Decision 1 — `shell.read`: a read-only shell tier

Add `shell.read` to `_NATIVE_MAP`, covering `Bash`. The name follows the existing `shell.exec.*` dotted-namespace pattern; the scope object is the shell, the qualifier is the access level.

A Bash call authorized by `shell.read` routes through `is_command_in_allowlist` with a **read-program allowlist** (a second `CommandAllowlist` instance, sibling to `TEST_RUN_ALLOWLIST`). Initial `programs` set: `{cat, head, tail, wc, ls, grep}`. This is the closed-by-default set; growing it is an operator amendment (same authorization shape as ADR-015 MCP-tool amendments, per `command_allowlist.py:8-10`).

**Inclusion criterion (load-bearing — applies to Decisions 1 and 2):** a program (or subcommand) is grantable **only if it is safe under every argument the charset gate permits.** The charset gate already excludes `>`, `<`, `|`, `&`, `;`, `$`, backtick, `*`, `?`, `~`, `\`, `#`, quotes, and newlines — so a read program cannot redirect, pipe, chain, substitute, or glob-expand. A program qualifies for `shell.read` only if, with those characters already impossible, no permitted argument string makes it mutate state or egress.

`find` is **excluded** from the initial `shell.read` set despite being a canonical read tool. The precise threat: the charset gate already blocks `find . -exec rm {} \;` (both `;` and `\` are outside the charset) and the `-exec ... +` form (`+` is outside the charset), so `-exec` is not the residual risk. The residual risk is the side-effecting primaries that use only charset-permitted characters — chiefly `find . -delete` (letters, spaces, `.`, `-` all pass), and similar allowed-charset primaries that mutate or emit. `find` therefore fails the inclusion criterion: its safety depends on its arguments, and the `argv[0]`-granular allowlist cannot distinguish a read traversal from `-delete`. `find` becomes grantable only when argument-level checking exists. (This is the same argument-granularity limit that excludes `git branch` in Decision 2.)

### Decision 2 — `worktree.commit`: local git, subcommand-bounded

Add `worktree.commit` to `_NATIVE_MAP`, covering `Bash`. The name parallels the existing `worktree.write` (same scope object — the assigned worktree) and encodes the option-1 ruling that **committing is part of writing**: a worker that produces versioned artifacts must be able to version them, because the framework's §2 premise is that agents communicate through versioned artifacts. A worker that can write files but not commit them has not produced a versioned artifact; it has produced a draft the operator must version on its behalf — which reintroduces a per-deliverable human touchpoint the framework exists to remove (§14 criterion 1).

A Bash call authorized by `worktree.commit` routes through `is_command_in_allowlist` with a **git-subcommand allowlist**. This requires extending `CommandAllowlist` with a new dimension:

```
program_subcommands: dict[str, frozenset[str]]
```

When `argv[0]` is a program with a `program_subcommands` entry, `argv[1]` is parsed as the subcommand and checked for membership in the program's allowed-subcommand set. A program with a `program_subcommands` entry but an `argv[1]` not in the set is DENIED at a new sentinel `framework.bounds.cmd.subcommand`.

Initial git subcommand set (the `worktree.commit` allowlist):

```
git: {status, log, diff, show, rev-parse, rev-list, add, commit}
```

Every subcommand in this set is safe under every argument the charset gate permits — they read, stage, or record, and none deletes refs, rewrites history, changes branches, or reaches the network. Explicitly **excluded**, each for a stated reason:

- `push, fetch, pull, clone, remote` — **egress.** Reach the network; outside the worktree-path-bounding's representational scope entirely (a remote is not a path). These are the git instances of the egress concern Decision 3 addresses.
- `reset, clean, checkout, switch, restore, stash, rebase, merge, cherry-pick, gc, prune` — **destructive or history-rewriting.** Can discard the worktree's uncommitted deliverables or rewrite committed history. A worker that commits does not need to destroy; destruction stays an operator capability.
- `config` — **persistent configuration.** Could set `core.hooksPath`, credential helpers, or remotes; a standing-configuration change outside the per-dispatch contract.
- `branch` — **excluded under the inclusion criterion**, not because branch-create is unsafe but because the `argv[1]`-granular allowlist cannot distinguish `git branch foo` (create, benign) from `git branch -d foo` (delete, destructive). Like `find`, `branch` becomes grantable when argument-level checking exists. Until then, the worker operates on the mission branch the worktree was created on and does not manage branches.

### Decision 3 — `shell.exec.*` is ungrantable to workers until C2 (egress-deferral)

`shell.exec.sandboxed` and `shell.exec.unsandboxed` remain defined in the capability map but are **prohibited from any worker `tool_scope`** until the C2 sandbox/egress-containment layer is built.

The reason is a present, concrete gap, not a precaution. In `is_command_in_allowlist`, a Bash call authorized by `shell.exec.*` (or `package.install.allowlisted`) **returns ALLOW immediately** — the function gates only `test.run`. The module docstring and `mcp_capability_map.py:24-31` (concern C2) state that `shell.exec.*` containment is enforced by "the actual sandbox flag at subprocess construction" in the runner. That layer is **not built** (capability-model current-state read, §"aspirational-vs-enforced semantics… the C2 sandbox-flag layer isn't built"). Therefore a worker granted `shell.exec.unsandboxed` today can invoke `curl`, `git push`, `pip install <anything>`, or any other egress, and the gateway will ALLOW it with no sandbox to contain it. For a system targeting multi-day unattended runs, an ungated egress surface is the highest-severity gap in the model.

C2-deferral closes the gap at the **grant level** rather than the command level: workers' legitimate needs are served without arbitrary exec — file reads via `shell.read`, test execution via the closed `test.run` allowlist, local commits via `worktree.commit` — so `shell.exec.*` need not be granted at all. Decision D of the companion ADR-027 (dispatch write-time validation) **enforces** this prohibition: a dispatch whose `tool_scope` contains `shell.exec.sandboxed` or `shell.exec.unsandboxed` is rejected at dispatch-construction with a reason naming the C2 gap.

**Escape condition (so the limitation is bounded, not permanent-by-inertia):** the first mission that genuinely requires arbitrary shell execution (an arbitrary build script, a package manager invocation, tooling not expressible in the read/test/git tiers) is the trigger to prioritize building C2. C2 is named as a separate future ADR with its own scope (a real subprocess-sandboxing implementation with network egress control); it is not folded into this ADR.

### Decision 4 — harness-internal tools mapped to a `framework.*` allow

`TodoWrite` and `ToolSearch` (and the harness's `Task`/`Cron`/`Monitor` surface where applicable) are Claude Code's own machinery, not worker-requestable capabilities. They currently fall through to the `(unmapped)` DENY branch in `policy.py`, which is correct fail-closed behavior but blocks the harness's own operation. Map them to a framework-internal allow so they are permitted without a worker grant, following the existing `framework.*` sentinel convention (`HANDOFF_EXEMPTION_CAPABILITY`, the seven `framework.bounds.*` tags). The unmapped-tool DENY default is preserved for genuinely unknown tools; only the named harness-internal tools are added.

### Note on Decision E (deny-attribution) — handled separately

The misleading single `capability_tag` on a multi-candidate DENY (`Gateway.check` returns `sorted(candidates)[0]`, so a denied Bash `wc` reports needing `package.install.allowlisted`) is fixed as a **standalone change**, not in this ADR, because it is a contained correctness fix to deny-reason composition that is correct regardless of this redesign. The fix makes the `capability_tag` non-misleading on multi-candidate denials (the reason string already lists all candidates). Recorded as its own ledger entry.

---

## Why this is forced by the framework's principles

- **§2 — agents communicate through versioned artifacts.** A worker that cannot commit cannot produce a versioned artifact; `worktree.commit` is what makes `worktree.write` actually satisfy the principle rather than half-satisfy it.
- **§14 criterion 1 — multi-day runs with intervention only at defined touchpoints.** An ungated egress surface (`shell.exec.*` without C2) cannot be left grantable during unattended runs; deferral is what keeps the autonomy horizon safe.
- **Least privilege (ADR-016's structural-enforcement ethos).** `shell.read` lets a worker read via shell without the arbitrary-execution grant — the read/exec split is least privilege applied to the shell surface.
- **The inclusion criterion mirrors ADR-020's verify-at-the-seam discipline:** authorize only what is safe under all permitted inputs, rather than authorizing broadly and hoping inputs stay benign.

## Operational integration

- `mcp_capability_map.py :: _NATIVE_MAP` — add `shell.read` and `worktree.commit`, both → `frozenset({"Bash"})`. Add harness-internal tool mappings (Decision 4).
- `command_allowlist.py` — add `program_subcommands: dict[str, frozenset[str]]` to `CommandAllowlist`; add two new module-level constants (`SHELL_READ_ALLOWLIST`, `WORKTREE_COMMIT_ALLOWLIST`) with the sets above. Contents are operator-ratified per the ADR-015 amendment shape; unlike `TEST_RUN_ALLOWLIST` (deliberately empty), these ship with the initial sets named here because the ADR ratifies them.
- `policy.py :: is_command_in_allowlist` — generalize from `test.run`-only to a capability→allowlist dispatch (`test.run` → `TEST_RUN_ALLOWLIST`, `shell.read` → `SHELL_READ_ALLOWLIST`, `worktree.commit` → `WORKTREE_COMMIT_ALLOWLIST`); add the `argv[1]` subcommand check for programs with a `program_subcommands` entry; add the `framework.bounds.cmd.subcommand` sentinel (a CLOSED addition to the framework namespace, since new bounds-gate verdict types require operator ruling).
- `policy.py` — the `shell.exec.*` grant prohibition is enforced in ADR-027's dispatch-construction validator, not here (the gateway stays pure-decision; it does not know dispatch-construction context).

## Invariants preserved

- **The gateway does not inspect tool arguments for capability resolution.** `Gateway.check` stays pure capability→tool matching. The argument-level checks (charset, program, subcommand, path-position) live in `is_command_in_allowlist`, the second wall the hook runs after `Gateway.check` ALLOWs — exactly as the existing `test.run` path works. No new inspection is added to `Gateway.check`.
- **Closed-by-default.** The new allowlists ship with explicit finite sets; anything not named denies. `shell.exec.*` denies by grant-prohibition.
- **C1 path-bounding unchanged.** The component-walk containment (`commonpath`, not `startswith`; `_resolve_symlink_safe` for the `..`+symlink bypass) is reused verbatim by the subcommand path-position checks; it is not modified.
- **The exact-case program-membership divergence is preserved** (program allowlisting uses case-sensitive match while path containment uses normcase — the Windows case-spoof guard); the new git/read allowlists inherit it.

## Consequences for implementation

1. `CommandAllowlist` gains `program_subcommands`; existing `TEST_RUN_ALLOWLIST` gets `program_subcommands={}` (unaffected).
2. Two new allowlist constants with ratified initial contents.
3. `is_command_in_allowlist` capability→allowlist dispatch + subcommand check + new sentinel.
4. `_NATIVE_MAP` gains `shell.read`, `worktree.commit`, harness-internal mappings.
5. ADR-027's dispatch validator enforces the `shell.exec.*` prohibition and the vocabulary check.
6. Regression probes: `shell.read` allows `wc`/`cat`/denies `find`; `worktree.commit` allows `git commit`/`git status`/denies `git push`/`git reset`/`git branch`; `shell.exec.*` in a dispatch `tool_scope` rejected at construction.

## Doc-update targets

- Canonical as this standalone file per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step. (The earlier doc-stopgap concern is resolved by ADR-033.)
- Update brief §6.2 (Tool Gateway) capability-allowlist description to name the read/test/commit tiers and the `shell.exec.*`-pending-C2 prohibition.
- The C2 sandbox/egress layer is a named future ADR (unnumbered until drafted).

---

## Alternatives considered

- **Broaden `worktree.write` to include git (no new tag).** Rejected: `worktree.write` is path-bounded file writing; git commit is a different operation (it reads index state, writes refs) and bundling them would make a single tag mean two enforcement shapes. A distinct tag keeps each capability's enforcement legible.
- **One `git` capability, all subcommands (no subcommand dimension).** Rejected: makes `git push` grantable wherever `git commit` is — the egress hole. The subcommand dimension is the minimum needed to make local-commit safe.
- **Build C2 now (C-build).** Rejected for this ADR: a real subprocess-sandboxing-with-egress-control layer is a large implementation, separable from the capability-vocabulary redesign. Deferring at the grant level closes the gap immediately with no new enforcement code; C-build is scheduled deliberately when a mission needs arbitrary exec.
- **Classify `shell.read` programs by a read-only flag rather than an allowlist.** Rejected: "read-only" is not a property the gateway can compute from a program name; the allowlist + charset-gate + inclusion-criterion is the enforceable approximation.
- **Admit `find`/`branch` with argument-level checks now.** Rejected as scope creep: argument-level checking is a real addition to the security-critical path and is not needed for file-production workloads; the inclusion criterion cleanly defers them.

---

## Tradeoff accepted

- **Workers cannot run arbitrary shell until C2.** No arbitrary build scripts, package installs, or non-allowlisted tooling. For file-production missions (e.g. schema + fixtures + rationale) this is no constraint. For a mission needing a build step, the operator runs that step or C2 is prioritized (the named escape condition). The cost is real and bounded; the benefit is no ungated egress during unattended runs.
- **Two maintained allowlist surfaces** (read-program set, git-subcommand set) plus the existing test.run set. Mitigated by closed-by-default (a missing entry denies, it does not open) and by the inclusion criterion making membership a mechanical safety judgment rather than a case-by-case one.
- **`find` and `branch` are useful and excluded.** A worker cannot `find` files via shell (it can `ls`/`grep`, and Glob/Grep tools cover discovery) or create branches (it works on the mission branch). The exclusion is honest about the `argv[1]`-granular machinery's limit rather than admitting a half-bounded program.
- **The subcommand dimension adds a parse step to the security-critical path.** `argv[1]` extraction after `shlex.split`. Mitigated by reusing the existing shlex parse (no new parser) and by the subcommand check being a frozenset membership test (the same shape as program-membership).
