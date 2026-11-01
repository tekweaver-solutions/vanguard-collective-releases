# ADR-018 — Sandbox base image distributed via GHCR with semver

> **Status:** Accepted — operator-ratified framework doctrine. Rests at "Accepted" per ADR-033 (the S1 resting-status rule); the standalone `adr-018-sandbox-base-image-ghcr.md` under `tools/mission-cli/config/` is the canonical copy. **Extracted from `local-orchestrator-mode.md` §3 per ADR-033 (standalone-canonical); previously folded-only.** Content moved verbatim — the decision is unchanged.

---

**Decision.** The worker sandbox base image is published to GitHub Container Registry (GHCR) at `ghcr.io/anthropic/claude-mission-sandbox:vX.Y.Z`, semver-tagged, with explicit version pinning in the user's `docker/compose.yaml` (never `:latest`). Per-monorepo extension is supported via `docker/sandbox.Dockerfile`.

**Image contents.**

- **Browsers and automation:** Playwright with Chromium, Firefox, and WebKit pre-installed (heavy install — pre-built saves 5–10 minutes per `mission infra up`).
- **Language toolchains:** Node 20+, Python 3.12+, modern git.
- **CLIs:** `gh` (GitHub CLI), `claude` (Claude Code CLI), `ollama` client, `jq`, `curl`, `bash`.
- **Worker harness:** the framework's worker-runner scripts that parse `claude -p` output into trace events, validate handoffs, etc.

**Update protocol.**

- `mission infra up` pulls the image once per laptop; cached locally for subsequent missions.
- `mission infra update` pulls a newer tag. Explicit, never automatic.
- Per-monorepo extension: `docker/sandbox.Dockerfile` is a stub that `FROM`s the base. Users extend it (e.g., to add Rust toolchain, or a database client) and the framework builds a derived image tagged `mission-<id>-sandbox:local`. The base SHA is recorded in the mission's `Mission.yaml` for reproducibility.

**Cadence.** Tied to: (a) Playwright browser version drift, (b) Claude Code CLI updates, (c) language LTS bumps. Practical rhythm: a new tag every 4–8 weeks.

**Alternatives considered.**

- *Docker Hub.* Workable but GHCR is free for public images, integrates with GitHub Actions for image build automation, and aligns with the "GitHub for source control" decision.
- *No reference image; users build their own from scratch.* Rejected — Playwright install is slow and error-prone; reproducibility suffers; first-run setup time becomes punishing.
- *Per-language base images (separate Node/Python/etc. images).* Rejected for v1 — most missions use multiple languages anyway, and one fat image with everything is simpler than a matrix. Revisit if image size becomes a real constraint.

**Tradeoff accepted.** Single fat base image is large (likely 2–4 GB pre-build). Worth it for first-run experience and reproducibility. Per-monorepo extension via `Dockerfile` keeps the customization story open.
