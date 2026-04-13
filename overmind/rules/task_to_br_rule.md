Task-to-BR decomposition contract for runtime BR artifacts

## Scope
- Stage goal: decompose an incoming task or story artifact into structured business requirements before repo scan.
- This rule fully defines business-context gate checking and missing-data processing via `<MISSING_DATA_ARTIFACT>`.

## Hard Constraints
1. Update only:
   - `<TARGET_BR_ARTIFACT>`
   - `<MISSING_DATA_ARTIFACT>`
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
     into `missing_br_data.md` ledger with deterministic `rised_item_N` markers.
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
- If `missing_br_data.md` contains unresolved `rised_item_N` entries, `## 7. Loop Decision -> unresolved_after_stop` is filled.
- FR/BR lines are concrete and input-traceable; generic/buzzword-only placeholders are not accepted.
- Every populated value is business-readable and traceable to user input.
