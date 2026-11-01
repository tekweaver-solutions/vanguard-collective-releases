# ADR-012 — Pinned-pull prompt registry with manifest

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-012-pinned-pull-prompt-registry.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** *Supersedes ADR-009.* `prompts/` is populated at `mission init` time by pulling a tagged version from a registry (default: a framework-maintained git repo). The pulled files are real files, not symlinks, committed to the user's monorepo. A `prompts/manifest.yaml` records the registry source, the pulled version, and per-file SHAs. Updates happen via explicit `mission prompts update [--to <version>]`. Forking happens via `mission prompts fork <name>`, which removes the manifest entry for that prompt and leaves the file editable.

```yaml
# prompts/manifest.yaml — committed to the monorepo
registry: https://github.com/anthropic/mission-prompts
version: v1.4.2
pinned:
  worker-coding-v17.md:        sha256:abc123...
  validator-narrow-v04.md:     sha256:def456...
  orchestrator-thinking-v02.md: sha256:ghi789...
forked: []   # populated when user runs `mission prompts fork ...`
```

**Alternatives considered.**

- *Vendor copies, no registry.* Rejected — prompt rot, eval loop fragments instantly.
- *Symlink to a global registry* (the original ADR-009). Rejected — Windows symlink handling is awkward, and a single global symlink loses per-mission version pinning, which breaks reproducibility (Section 14.3).
- *Git submodule.* Workable but submodules are confusing for many users; updating is a separate ceremony.
- *Package manager (npm/pip).* Overengineered; markdown files don't fit package manifests well.

**Tradeoff accepted.** The framework now has to maintain a registry-pull mechanism. Worth it because the manifest preserves three things that matter: (a) reproducibility — another laptop cloning the repo gets identical prompts; (b) update auditability — `mission prompts update` is an explicit, traceable action; (c) eval-loop integrity — `prompt_version` in `TraceEvent` correlates back to a real, version-pinned source.

**Forking remains visible.** A forked prompt is a manifest gap, not a hidden override. This makes "this user ran v17 modified" inspectable in code review.
