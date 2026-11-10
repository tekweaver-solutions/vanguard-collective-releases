# Vanguard Collective

Vanguard Collective is a framework for running a software mission with Claude Code agents under an
evidence discipline. A mission is a committed record under `.mission/` -- its spec, contract,
dispatches, handoffs, validator results, ledger and gates. Workers are dispatched into worktrees of
their own, independent validators judge what they hand back, and a human operator holds the gates
that admit a dispatch or a publication. The Local Autonomous Mode (LAM) toolchain drives this on a
single Windows workstation: a runner dispatches workers, a goal evaluator decides from disk whether
a session may stop, and a gate tool records the operator's acts. The Framework is free to use under
[LICENSE](LICENSE), including for commercial and client work; the Framework itself may not be
redistributed or resold. Support is by subscription, for paying customers: support@tekweaver.ca.

What the framework says about a session is meant to be checkable on disk rather than taken from a
transcript. Hooks registered in `.claude/settings.json` keep an evidence plane that agents cannot
write: a PreToolUse guard refuses agent writes to it, a PostToolUse hook captures every tool call,
and a Stop hook seals a manifest. A pre-push decider refuses a publication no gate authorizes, and
acceptance instruments exercise the machinery by running it. Version 1.0.0 was the first public
release: the framework in a repository of its own, with an installer that installs from the release ZIP
or from a clone of the public repository at its release tag and upgrades a project in place, and agents
that authenticate with a Claude subscription or an Anthropic API key. Version 1.1.0 adds the dashboard, `vanguard ui`: a
read-only, local view of every project registered on the machine, fed by the mission-event feed the
hooks and lifecycle commands now append. Version 1.2.0 was the licence release. The current release is 1.3.0, in
which the dashboard reads what a mission proved, round by round, and how long it took, and a session's end is written by
a SessionEnd hook; its notes are [docs/RELEASE-NOTES-v1.3.0.md](docs/RELEASE-NOTES-v1.3.0.md), known limits first.

New to the framework? Start with [docs/QUICKSTART.md](docs/QUICKSTART.md), then read the operator's
guide, [docs/framework/vanguard-collective-user-guide.md](docs/framework/vanguard-collective-user-guide.md).

## Layout

| path | what it holds |
|---|---|
| `tools/lam/` | the LAM toolchain: the runner (`mission-dispatch.ps1`), the goal evaluator and Stop hook (`mission-goal-check.ps1`), the gate tool and the operator console (`mission-gate.ps1`, `lam-console.ps1`), the instrument-run helper, the role settings templates under `settings/`, and the smoke-mission builder (`build-smoke-mission.ps1`) with its sources under `smoke-mission/` |
| `tools/evidence-hooks-next/` | the evidence hooks: the PreToolUse guard, PostToolUse capture, the Stop finalizer, PreCompact, SubagentStop, SessionEnd, the runner's dispatch-end writer and the pre-push decider |
| `tools/mission-cli/` | mission configuration: the ADR registry, model routing, expected failures, the MCP tool selection |
| `docs/framework/` | the design documents, the operator's install procedure (`LAM-INSTALL.md`) and the schemas -- the first host's acceptance record, `LAM-ACCEPT.md`, is not a framework document and is not shipped |
| `tools/ui/` | the dashboard's service, `vanguard ui` (FastAPI and uvicorn, its pinned set in `requirements.txt`, the command `vanguard.cmd`) |
| `ui/dist/` | the dashboard's built files, which the service serves; the release carries them, built from a private source it does not |
| `tests/lam/` | the acceptance instruments `instrument-WP-1.ps1` ... `instrument-WP-7.ps1` (WP-7: the mission-event feed, the service and the dashboard), and the pinned bases they read under `fixtures/base-700e19e5/`, `fixtures/base-700e19e5-sNN/` (built by the recipe `fixtures/synthetic-bases.json`, which this repository keeps and does not install) and `fixtures/legacy-census-halts/`; the smoke mission they read is built after install, beside the project, by `tools/lam/build-smoke-mission.ps1` |
| `.claude/settings.json` | the hook registrations Claude Code reads |

Beside these, `tools/framework/` holds the first-generation hooks the next generation delegates to,
and `tools/mission-*.ps1` are the mission lifecycle commands. What is installed into a project is
exactly the set the release's `provenance/manifest.jsonl` defines (385 files in the release, `ui/dist/`
and `THIRD-PARTY-NOTICES` among them); `provenance/` and this repository's own files are not installed.

## Prerequisites

- Windows, with Windows PowerShell 5.1
- Python 3; for the dashboard, CPython 3.14 for 64-bit Windows, whose wheels the install's hash-checked
  `pip` takes from PyPI (the network during the install; [INSTALL.md](INSTALL.md) section 5). Node is
  never needed.
- git
- Claude Code Desktop
- Docker Desktop, only for a product whose test suite needs it

Claude Code authenticates the framework's agents one of two ways: with the Claude subscription it is
signed in with -- the default, nothing to set, as long as no credential is left in the shell: with
`VANGUARD_AUTH_MODE` unset the framework checks nothing, and an `ANTHROPIC_API_KEY`, a bearer token
(`ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`) or a cloud-provider selector (`CLAUDE_CODE_USE_BEDROCK`,
`_VERTEX`, `_FOUNDRY`) there is used by Claude Code's print mode instead, by its own precedence (only the
first-generation worker-runner removes the key); `VANGUARD_AUTH_MODE=subscription` refuses each of them but
the subscription's own `CLAUDE_CODE_OAUTH_TOKEN` -- or with an Anthropic API key, `ANTHROPIC_API_KEY` set in
your own terminal beside `VANGUARD_AUTH_MODE=api-key`. The key travels in the environment only: the
framework puts it in no file or argument, and refuses one it finds there
([INSTALL.md](INSTALL.md) section 9).

A release ZIP your browser downloaded carries the Mark of the Web: run `Unblock-File` on it before you
expand it; one fetched with `gh release download`, or with Windows PowerShell 5.1's `Invoke-WebRequest`,
carries none and needs no `Unblock-File`. Expanded by Explorer, every file keeps the mark and a
`RemoteSigned` policy refuses `install.ps1` ([INSTALL.md](INSTALL.md) step 3). Line endings do not
matter: `install.ps1` compares a text file after folding every CR LF to LF, the rule
[INSTALL.md](INSTALL.md) section 5 states.

Install from, and into, folders OneDrive does not sync. The placeholders OneDrive keeps for its files
are reparse points, and `install.ps1` refuses every reparse point it meets below the folder it installs
into -- so an upgrade, a same-version run or `-Verify` there is refused once OneDrive has left a
placeholder below the folder -- but it does not judge that folder itself: a first install into an empty
synced folder is not refused
([INSTALL.md](INSTALL.md) section 5, the path guard).

## The two commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Target <folder>
```

copies the framework into `<folder>`, byte for byte, and writes `<folder>\framework.lock`. Over a
folder an earlier release installed, it upgrades it. It never overwrites a framework file somebody
changed, and never touches `.mission/` or `.mission-runtime/`. `-WhatIf` shows what it would do;
`-Verify` re-checks an installed folder against its lock.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 init -Target <folder>
powershell -NoProfile -ExecutionPolicy Bypass -File .\mission.ps1 smoke -Target <folder>
```

`init` creates an empty mission in `<folder>` and registers it for the dashboard; `smoke` runs the
installed goal evaluator over it and exits 0 when the verdict is MET. [INSTALL.md](INSTALL.md) walks
through all three from the release ZIP, with the output to expect. Then

```powershell
<folder>\tools\ui\vanguard.cmd ui
```

starts the dashboard on `http://127.0.0.1:8765/`, read-only and local to this machine.

## Ownership and contributions

Vanguard Collective is owned and maintained by tekWeaver Solutions Inc. It takes no external contributions: the
public repository, https://github.com/tekweaver-solutions/vanguard-collective-releases, publishes the releases
only, with its issues turned off. Support is for paying customers, by contact: support@tekweaver.ca.

## Licence

The Framework is free to use under [LICENSE](LICENSE), including for commercial and client work; the Framework itself
may not be redistributed. Support is offered to paying customers by contact: support@tekweaver.ca.
