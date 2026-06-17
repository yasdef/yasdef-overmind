Task-to-BR decomposition contract for runtime BR artifacts

## Scope
- Stage goal: decompose an incoming task or story artifact into structured business requirements before repo scan.
- This rule fully defines business-context gate checking and missing-data processing via `<MISSING_DATA_ARTIFACT>`.

## Hard Constraints
1. Update only:
   - `<TARGET_BR_ARTIFACT>`
   - `<MISSING_DATA_ARTIFACT>`
   - `<CAPTURED_USER_INPUT_ARTIFACT>` only when the source is Jira and the fetched story text must be persisted into the captured input record
2. Preserve BR section order, headings, keys, and one-line FR/BR item structure.
3. Do not add, remove, or rename BR sections/keys.
4. Do not fill `## 13. Existing-System Context` at this stage.
5. Use only captured user input and current BR content; do not invent facts.
6. Keep unresolved BR values as `[UNFILLED]`.
7. Ensure `## 1. Document Meta` includes:
   - `source_type` containing `User input`
   - `last_updated` in `YYYY-MM-DD`
8. `missing_br_data.md` is the unresolved-question ledger; keep question-state tracking there.
9. Keep `feature_br_summary.md` as the source of truth for business content.
10. This stage identifies unresolved gaps and prepares follow-up questions only; answer-handling lifecycle is governed by `<USER_BR_CLARIFICATION_RULE_FILE>`.
11. Do not silently assume missing details: every unresolved or low-confidence business detail MUST be externalized as `rised_item_N` (`rised=false`) in `<MISSING_DATA_ARTIFACT>`.
12. Ambiguity triggers (for example: "fast", "better", "simple", "as needed", "TBD", "etc.") MUST be converted into explicit follow-up business questions and tracked as unresolved ledger items.
13. Do not write generic placeholder FR/BR content. If a requirement/rule is not specific and traceable to user input, keep it `[UNFILLED]` and track the gap in `<MISSING_DATA_ARTIFACT>`.
14. If the source is Jira, persist the fetched story/request text into `<CAPTURED_USER_INPUT_ARTIFACT>` before finishing so downstream phases retain the actual source narrative.
15. Always create or refresh `<MISSING_DATA_ARTIFACT>`, even when no unresolved business gaps are found.

## Gate Command
Run from repository root after each extraction round:
- `<USER_INPUT_GATE_HELPER_COMMAND>`

Exit codes:
- `0`: gate pass (done)
- `1`: gate fail (continue loop)
- `2`: helper/script failure (stop and report error)

## Missing-Data Externalization (Mandatory)
1. Run gate helper.
2. If exit `0`: finish.
3. If exit `1`:
   - Create/refresh `<MISSING_DATA_ARTIFACT>` using:
    - `<MISSING_DATA_TEMPLATE_FILE>`
    - `<MISSING_DATA_GOLDEN_EXAMPLE_FILE>`
   - Record unresolved items from helper output, plus any ambiguity-triggered gaps found during extraction.
   - Move unresolved non-`rised` values from:
     - `## 14. Assumptions -> ### Needs validation -> assumptions_needing_validation`
     - `## 15. Open Questions`
     - `### 5.3 Open scope boundaries -> unclear_scope_points`
     into `missing_br_data.md` ledger with deterministic `rised_item_N` markers and `rised=false`.
   - For every newly created `rised_item_N`, set `rised=false` (not yet discussed with user).
   - Set moved source BR values in `<TARGET_BR_ARTIFACT>` to `[UNFILLED]`.
   - Set `## 7. Loop Decision -> unresolved_after_stop` to a concise summary of unresolved business gaps.
4. If exit `2`: stop and report error.
5. Stop only when:
   - gate passes, or
   - user provides no new usable business input.
6. If stopping without pass:
   - keep unresolved items clearly marked in `missing_br_data.md`
   - set `unresolved_after_stop` to a concise unresolved summary.
7. If no unresolved gaps remain:
   - keep `## 2. Missing Business Fields` as `- none`
   - keep `## 3. Unresolved Items Ledger (Rised)` empty
   - keep `## 6. Latest User Answers -> answers` as `[UNFILLED]`
   - set `## 7. Loop Decision -> unresolved_after_stop` to `none`

## Deterministic Ledger Markers
- Unresolved entries:
  - `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<text>`
- Numbering rules:
  - deterministic and gap-free
  - `N` starts at `1`

## Question Scope
- Ask only business-domain follow-up questions.
- Do not ask technical implementation, architecture, framework, deployment, or code-structure questions.

## Runtime Path Bindings
- The caller provides runtime path bindings (feature root and resolved artifact paths) in prompt context.
- Treat those runtime bindings as authoritative for this invocation.
- Do not replace runtime bindings with fixed `overmind/product/...` assumptions.

## Quality Criteria
- `### 2.1 Original request summary -> short summary` is filled.
- `### 3.1 Business goal -> primary_business_goal` is filled.
- `## 6. Functional Requirements` has at least one meaningful one-line FR (`- FR-N: ...`).
- `## 7. Business Rules and Decision Logic` has at least one meaningful one-line BR (`- BR-N: ...`).
- `### Needs validation -> assumptions_needing_validation` has no unresolved non-`rised` value.
- `## 15. Open Questions` has no unresolved non-`rised` value.
- `### 5.3 Open scope boundaries -> unclear_scope_points` has no unresolved non-`rised` value.
- If `missing_br_data.md` contains unresolved `rised_item_N` entries, each entry has `rised=false` or `rised=true`, and `## 7. Loop Decision -> unresolved_after_stop` is filled.
- `missing_br_data.md` exists for every completed task-to-BR run.
- FR/BR lines are concrete and input-traceable; generic/buzzword-only placeholders are not accepted.
- Every populated value is business-readable and traceable to user input.

## Linked Artifact Extraction (Jira Source Only)

1. This rule applies only when `## 1. Document Meta -> source_type` contains `jira:<ticket>` (i.e. the input source is a Jira MCP fetch). Skip this rule entirely for file-path sources.
2. After extracting business content, inspect the Jira MCP story response for linked non-text artifacts: attached images, PDFs, linked Confluence pages, referenced API specs, data schemas, design mocks, and any other non-text items surfaced by the MCP response.
3. Populate `## 16. Linked Artifacts` in `<TARGET_BR_ARTIFACT>` with one entry per discovered artifact, using the LAR-NNN sequential ID scheme (LAR-001, LAR-002, …) scoped to this document.
4. Always emit `## 16. Linked Artifacts` in the output, even when the list is empty. Do not omit the section.
5. Each entry must capture exactly these four fields:
   - `id`: LAR-NNN sequential identifier (LAR-001, LAR-002, …), document-local and gap-free.
   - `title`: human-readable artifact name as found in the Jira/Confluence metadata.
   - `type`: one value from the closed vocabulary below.
   - `locator`: URL or path to the artifact as returned by the MCP response.
6. Use only the following closed type vocabulary for the `type` field:
   - `data_schema` — structured data schema or data model document
   - `diagram` — architecture, flow, sequence, or entity-relationship diagram
   - `api_spec` — API specification or contract (OpenAPI, AsyncAPI, Protobuf, etc.)
   - `design_mock` — UI design mockup or wireframe
   - `document` — general document, Confluence page, or unclassified text artifact
   - `image` — image file not covered by another type
   - `pdf` — PDF file
   - `other` — any artifact that does not match the above types
7. Do not download or interpret artifact content; record only metadata (id, title, type, locator/URL).
8. If the MCP response does not surface linked items as structured data (only plain text with no link metadata), emit `## 16. Linked Artifacts` with an empty list. This is correct behavior, not a failure.
