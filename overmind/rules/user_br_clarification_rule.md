User BR clarification contract for runtime artifacts

## Scope
- Stage goal: resolve unresolved business-only gaps tracked in `<MISSING_DATA_ARTIFACT>`.
- This rule is used by the runtime user-BR clarification command.
- This rule is isolated and self-sufficient for user BR clarification behavior.

## Hard Constraints
1. Update only:
   - `<TARGET_BR_ARTIFACT>` (business answers source of truth)
   - `<MISSING_DATA_ARTIFACT>` (question-state ledger)
2. Ask only business-domain follow-up questions.
3. Do not ask technical implementation, architecture, framework, deployment, or code-structure questions.
4. Keep `missing_br_data.md` as a question-state ledger.
5. Use one deterministic tracking flag:
   - `rised=false` means not yet discussed with user.
   - `rised=true` means item has been discussed with user.
6. Keep `<TARGET_BR_ARTIFACT>` as the source of truth for business content.
7. Keep `## 6. Latest User Answers` pointer-only; use it only for destination traceability entries.
8. Do not duplicate answer narrative text in `missing_br_data.md`; keep only `rised` state and destination-pointer entries.
9. Preserve BR section order, headings, keys, and one-line FR/BR item structure.

## Gate Command
Run from repository root after each answer round:
- `<USER_INPUT_GATE_HELPER_COMMAND>`

Exit codes:
- `0`: gate pass with all tracked `rised_item_N` entries resolved (`rised=true`)
- `1`: unresolved loop state remains (continue loop)
- `2`: helper/script failure (stop and report error)

## Quality-Gate Loop (Mandatory)
1. Read unresolved ledger items in `missing_br_data.md` and treat items as unresolved while `rised=false`.
2. Ask targeted business-only follow-up questions mapped to unresolved ledger items.
3. Write actual answer content only to `feature_br_summary.md`.
4. After an item is actually discussed with user and its answer is written to `feature_br_summary.md`, update the matching `rised_item_N` entry to `rised=true`.
5. Record answer destinations in `missing_br_data.md` using one deterministic pointer entry per discussed item:
   - `- answers: This was recorded in <section marker> - <field/item id>.`
6. Rerun gate helper.
7. If helper exit `1`, continue the loop and do not declare completion.
8. Stop only when helper exits `0` and all tracked `rised_item_N` entries are `rised=true`.
9. Do not stop early while any tracked `rised_item_N` remains `rised=false`.

## Deterministic Ledger Markers
- Unresolved entries:
  - `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<text>`
- Discussed/raised entries:
  - `- rised_item_N: source=<section> -> <field>; rised=true; unresolved_item=<text>`
- Numbering rules:
  - deterministic and gap-free
  - `N` starts at `1`

## Latest User Answers Traceability
- Section shape:
  - `## 6. Latest User Answers` may contain one or more repeated `- answers:` lines.
  - Use one `- answers:` line per discussed item.
- Canonical format:
  - `- answers: This was recorded in ## <section-number>. <section-title> - <field/item-id>.`
- Interpretation:
  - Each `- answers:` line stores destination traceability only.
  - It must not include answer narrative text.
- `field/item-id` examples:
  - one-line BR/FR items: `BR-6`, `FR-3`
  - named fields: `critical_questions`, `unclear_scope_points`, `assumptions_needing_validation`

## Runtime Path Bindings
- The caller provides runtime path bindings (feature root and resolved artifact paths) in prompt context.
- Treat those runtime bindings as authoritative for this invocation.
- Do not replace runtime bindings with fixed `overmind/product/...` assumptions.
