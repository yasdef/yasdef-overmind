## Context

`feature_task_to_br.sh` (CRP-122) can now fetch a Jira story via MCP. Jira stories routinely carry linked non-text artifacts — data schemas, API specs, design mocks, Confluence pages, PDFs — that the model currently reads during the MCP fetch but has no place to record. The `feature_br_summary_TEMPLATE.md` ends at section 15; `br_to_ears.md` has no concept of linked artifacts. This change is entirely in rule files, template files, and golden examples — no shell logic changes.

## Goals / Non-Goals

**Goals:**
- Add `## 16. Linked Artifacts` to `feature_br_summary_TEMPLATE.md` with structured LAR-NNN entries.
- Extend `task_to_br_rule.md` so the model populates section 16 when the source is `jira:<ticket>`.
- Extend `br_to_ears.md` so the EARS conversion copies section 16 into a document-level registry and links each artifact to relevant `### Requirement` blocks via `#### Linked Artifacts`.
- Provide golden examples for both `feature_br_summary_GOLDEN_EXAMPLE.md` and `reqirements_ears_GOLDEN_EXAMPLE.md`.
- Add test cases for both scripts.

**Non-Goals:**
- Fetching or downloading artifact content — only metadata (id, title, type, locator/URL) is recorded.
- Validating that locators are reachable.
- Changing `feature_task_to_br.sh` shell code in any way.
- Supporting linked artifacts sourced from non-Jira inputs (file path source).
- Global (cross-feature) uniqueness of LAR IDs.

## Decisions

### LAR-NNN ID scheme (document-local)
IDs are sequential integers scoped to the `feature_br_summary.md` document: `LAR-001`, `LAR-002`, … Rationale: document-local IDs are stable across re-runs with unchanged input, require no registry, and are sufficient for the cross-reference use case within a single feature's artifact set. An alternative of content-hashed IDs was rejected as unnecessary complexity.

### Artifact type taxonomy (closed, extensible via `other`)
Supported types: `data_schema`, `diagram`, `api_spec`, `design_mock`, `document`, `image`, `pdf`, `other`. A closed list enables consistent filtering and golden-example coverage; `other` provides an escape hatch. Free-form strings were rejected because they prevent meaningful quality-gate checks.

### Model judges artifact-to-requirement association
The EARS rule instructs the model to use semantic judgment to associate each LAR to one or more requirements. There is no deterministic keyword matching. Rationale: the variety of artifact types and requirement phrasing makes deterministic mapping impractical; model judgment is consistent with how other inference-based associations work in `br_to_ears.md`. Risk: association quality depends on model reasoning — mitigated by requiring at least one LAR association per non-registry requirement when artifacts exist.

### Section 16 always present in BR template, registry section conditional in EARS
Section 16 is always emitted in `feature_br_summary.md` (possibly with an empty list) to make its presence structurally predictable for downstream quality checks. The `## Linked Artifacts` registry in `requirements_ears.md` is omitted entirely when section 16 is empty, to avoid cluttering short EARS documents.

### `#### Linked Artifacts` subsection optional per requirement
If the model determines no artifact is relevant to a particular requirement, the `#### Linked Artifacts` subsection is omitted for that block. Forcing a mandatory subsection on every requirement would generate noise and false associations.

## Risks / Trade-offs

- **Jira MCP may not surface linked items as structured data** → The rule instructs the model to extract linked items from whatever representation the MCP returns (structured links, inline Confluence URLs, attachments metadata). If the MCP returns only plain text without links, section 16 will be empty; this is correct behavior, not a failure.
- **Model association accuracy** → Incorrect LAR-to-requirement links add noise but do not break downstream artifacts. Quality can be improved iteratively by refining the EARS rule wording.
- **Non-Jira source path** → Section 16 will always be empty for file-path source runs. Template and quality gates must not require section 16 to be populated.
