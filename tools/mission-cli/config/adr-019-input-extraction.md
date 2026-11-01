# ADR-019 — Input extraction via Docling for binary formats

> **Status:** Accepted — operator-ruled framework doctrine. This standalone file is the canonical copy of the decision per ADR-033 (standalone-canonical); there is no fold-into-`local-orchestrator-mode.md` step.
>
> **Drafted during:** a project bootstrap, after extracting a client `.docx` input revealed Docling's quality and reusability as a framework-wide standard rather than a one-off.

---

## Decision

Binary input formats — `.docx`, `.pdf`, `.xlsx`, `.pptx`, and images (`.png`, `.jpg`, `.jpeg`, `.tiff`, `.bmp`) — are opaque to LLM-based designers and workers. Before any such file can drive design or execution, it must be **extracted to structure-preserving markdown** that the agent can read.

This framework adopts **Docling** (`pip install docling`, requires Python 3.10+) as the standard tool for that extraction. The extracted markdown is a **sibling artifact** alongside the original binary in `.mission/inputs/<category>/`; the binary remains the immutable source of truth per ADR-008. Both files appear in `INDEX.md` with provenance recorded on the derived one.

Invocation shape (one-shot, design-time):

```powershell
docling <source.docx> --to md --output <dest-dir>
```

Future binary imports are integrated into `tools/mission-inputs-import.ps1` via an opt-in `-ExtractBinary` switch (see "Operational integration" below).

## Alternatives considered

- **Pandoc.** Long-standing, fast, broadly available. The killer weakness for this framework is **table fidelity** — Pandoc's DOCX-to-MD pipeline degrades complex tables (the kind found in pricing schedules and spreadsheets-turned-documents) into HTML fragments or flattens them, which the designer then has to mentally reconstruct. Doesn't handle PDFs or images. Kept as a documented fallback specifically for DOCX cases if Docling ever regresses on a real document we care about.
- **`python-docx`.** Programmatic API, no LLM tax, single-format. Useful for surgical reads of `.docx` internals but produces no markdown by itself; we'd have to write the layout logic ourselves. Single-format also fails the multi-format constraint that drove this decision in the first place.
- **LlamaParse / cloud-hosted document parsers.** Often the best raw quality on complex PDFs, but **sends documents to a remote service**, which fails the local-execution constraint a mission handling confidential client materials carries (NDA-bound or client-confidential materials). Disqualifying for v1.
- **Manual extraction** (open the doc in Word, copy/paste, hand-fix tables). Acceptable as an emergency fallback for a single ill-behaved document, but unscalable across several input documents per mission and pathologically lossy on complex tables.
- **No extraction; tell the designer to read past binary files.** Was the position before this ADR. The cost is that any binary referenced by the inputs is effectively invisible to the designer; the contract cannot reflect its content, and the eval loop has no signal on whether the binary was read correctly. Not viable.

## Tradeoff accepted

- **Slower than Pandoc** per document (Docling's layout-detection model adds tens of seconds even on small DOCX; PDFs add more). Acceptable: this is a design-time step run once per binary, not a runtime hot path.
- **Smaller ecosystem.** Docling is younger than Pandoc and has a thinner long-tail of edge-case handling. We accept this in exchange for the table-structure and multi-format wins; if a specific document defeats Docling, the operator falls back to Pandoc (DOCX) or LlamaParse (PDF, only if NDA permits remote processing) on a per-document basis. We do **not** silently change the standard; a fallback is logged in the ledger.
- **First-run cost.** The first Docling invocation on a fresh laptop downloads layout-detection model weights, on the order of hundreds of MB. Documented in the operator runbook and in the import script's notice.
- **Output stylistic quirks.** Docling tends to render DOCX headings as `**bold**` rather than `#`-prefixed markdown headings. The designer (an LLM) parses this without difficulty, but downstream tooling that expects `#`-style headings (e.g., a TOC generator) may need a postprocessor. Worth noting; not blocking.

## Why this is forced

- **Force 3 from `local-orchestrator-mode.md`** (the human is the orchestrator, working in local tools): the operator drops a `.docx` or `.pdf` into inputs without thinking about format conversion. The framework absorbs the conversion at the import seam; the operator never has to know what `pandoc` is.
- **Inputs are immutable post-design-start** (ADR-008): we cannot in-place rewrite the `.docx` into `.md`. We can only add a sibling. The sibling-artifact pattern is the only one consistent with input immutability.
- **NDA / client-confidentiality** in most client engagements: local-only execution is non-negotiable for the extractor, which rules out the cloud-parser alternatives.

## Operational integration

`tools/mission-inputs-import.ps1` is extended with an opt-in `-ExtractBinary` switch:

- **Without the flag:** binary files are copied as-is into `.mission/inputs/<category>/` and indexed; the script prints a one-paragraph notice telling the operator how to extract them.
- **With the flag:** after the copy + index step, Docling is invoked against the imported binary; the resulting `.md` is placed in the same category directory and a second `INDEX.md` row records it with provenance (`derived from <relpath>` instead of an external source path).

**Why opt-in rather than automatic.** The first Docling run downloads model weights silently; on a flaky network this can wedge the import flow for minutes. Making it opt-in puts the cost in front of the operator the first time, and lets them know what's about to happen. After the first run, subsequent extractions are fast and the flag becomes a routine addition.

**Why a flag rather than a prompt.** Two reasons. First, this agent's PowerShell tool harness is non-interactive — runtime `Read-Host` prompts would hang. Second, declarative flags are easier to script and reproduce; an explicit `-ExtractBinary` invocation is recoverable from a shell history, an `Read-Host y/n` answer is not.

## Future: the Docling MCP server

Docling also ships as an **MCP server** (`docling-mcp` on PyPI / GitHub). That is a different routing from this ADR: an MCP server would let a *runtime* agent (worker, validator) parse a document inside its own context as part of its work — for example, the QA validator inspecting a PDF that the worker produced, or a worker reading a customer-supplied API spec mid-task.

This ADR scopes only the **design-time, one-shot** use: extracting binary input materials so the designer can read them. The MCP server, when wired, would be a separate entry in `tools/mission-cli/config/mcp-tools.yaml` with `purpose: "Runtime document parsing"`, distinct from the design-time extraction here. Decided this way to keep the two concerns separable: the CLI use is reproducible, version-pinned by `pip`, and runs before the contract is frozen; the MCP use, if and when we add it, is governed by ADR-015's mcp-tools mechanism and runs inside the worker sandbox.

## Canonical status

Per ADR-033 (standalone-canonical), this standalone file is the canonical copy of the decision; there is no "fold into `local-orchestrator-mode.md`" promotion step. It is a strong default for any Local Orchestrator Mode mission that touches binary inputs.

## Invariance check

- **Schemas unchanged.** `expanded-schemas.md` Section 7 (Memory Ledger Entry) is the schema we used to record the Docling adoption; no new fields, no new types. The binary and its extracted sibling are both ordinary files in `.mission/inputs/`; no new artifact category needed.
- **ADR-008 preserved.** Inputs immutable; extraction adds a sibling rather than mutating the binary.
- **ADR-015 preserved.** MCP tool list is unaffected by this CLI-mode extraction. If the Docling MCP server gets wired later, that's an ADR-015-governed addition, not a rewrite of this ADR.
- **Section 14.6 portability preserved.** A mission migrated to Hosted Autonomous Mode carries its `.mission/inputs/` directory verbatim, including extracted markdown siblings; the hosted environment can install Docling identically (or substitute Pandoc / a cloud parser per its own constraints) without touching the artifact store.
