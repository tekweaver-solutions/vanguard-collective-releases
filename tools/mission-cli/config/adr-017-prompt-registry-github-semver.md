# ADR-017 — Prompt registry hosted on GitHub with semver

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-017-prompt-registry-github-semver.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** *Resolves the registry hosting question deferred from ADR-012.* The prompt registry is a single GitHub repository (`github.com/anthropic/claude-mission-prompts` or the framework maintainer's equivalent). Releases are tagged with semver. The framework's CLI uses standard git operations to clone at a tag.

**Update protocol.**

- `mission init` clones the latest stable release into `prompts/`, writes `prompts/manifest.yaml` with the tag and per-file SHAs.
- `mission prompts update [--to vX.Y.Z]` pulls a specific or latest release. Manifest is rewritten.
- **Breaking changes use MAJOR version bumps.** `mission prompts update` refuses to cross a MAJOR boundary without `--confirm-breaking`. This puts the prompt-version risk in front of the human.
- Release notes for each tag list breaking changes, additive prompts, and any prompts marked deprecated.

**Cadence.** Event-driven, not time-driven. New Anthropic model release → registry maintainer revalidates prompts against the new model → tags a new release. No nightly or weekly rhythm.

**Why a separate repo, not part of the framework repo.** Prompts version on a different cadence than framework code. Coupling them forces lockstep releases that don't match how either evolves.

**Alternatives considered.**

- *Anthropic-hosted only.* Workable, but having it in a public GitHub repo lets the community contribute prompt improvements and lets users fork the entire registry if they need a long-running variant.
- *Multiple registries (Anthropic + community).* Workable but multiplies the trust surface; defer.
- *Distribute prompts via npm/pip package.* Rejected — markdown files don't fit package manifests well, and semver via git tags is the same primitive with less ceremony.

**Tradeoff accepted.** GitHub is now a soft dependency for the prompt registry path. Users without GitHub access (rare in this user's scope) would have to mirror the repo. Acceptable for v1.
