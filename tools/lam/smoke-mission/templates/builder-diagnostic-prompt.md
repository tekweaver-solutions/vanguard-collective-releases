# Disclosure: the builder-diagnostic prompt-register line

The mission root's prompt register (`.mission-runtime/operator-prompts.log`) carries ONE
`kind=operator` line, session `{{SESSION}}`, prompt_bytes {{BYTES}}.

WHO WROTE IT. `tools/lam/build-smoke-mission.ps1`, while building this mission. It drove the
framework's UserPromptSubmit hook (`tools/lam/record-operator-prompt.ps1`) once with no dispatch
marker set, from its own session, so that the register carries one operator-kind line and the
zero-paste attestation's exclusion path has a real line to classify. No human typed it.

WHAT IT WAS. The one-line prompt `{{PROMPT}}`, submitted with this mission root as the project
directory. The same session id is the builder's own session in the evidence plane, where its one
other act -- a push attempted before any push gate existed -- is recorded as a denial.

HOW IT IS CLASSIFIED. `builder-diagnostic`. The WP-6 instrument's exclusion table names this session
and this file; a line is excluded from the human count only while this disclosure resolves, and an
exclusion whose disclosure does not resolve is rejected and the line counts.
