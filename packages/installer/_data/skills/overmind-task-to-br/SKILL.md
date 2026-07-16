---
name: overmind-task-to-br
description: Use when converting captured task, story, or Jira business input into Overmind feature_br_summary.md and missing_br_data.md artifacts for the task-to-BR step.
---

# Overmind Task To BR

Use this skill to update a feature folder's business requirements artifacts from captured task/story input.

## Required Invocation

Run these commands from the installed project root:

1. Ensure captured source input exists. If `<feature-path>/user_br_input.md` is missing, ask the operator for exactly one source and run one capture command:

```bash
node .overmind/overmind.js capture task-to-br <feature-path> --source-file <path-to-story.md-or.txt>
```

```bash
node .overmind/overmind.js capture task-to-br <feature-path> --jira <ticket>
```

The source file must be inside the feature folder. Jira capture records the ticket marker; the context step below instructs you how to fetch and persist the Jira story text. The capture command is the deterministic backend primitive for future VS Code UI capture; do not hand-write `user_br_input.md` unless the CLI is unavailable and the user explicitly asks for manual recovery.

2. Assemble deterministic context:

```bash
node .overmind/overmind.js context task-to-br <feature-path>
```

3. Read the emitted context block and update only:
- `<feature-path>/feature_br_summary.md`
- `<feature-path>/missing_br_data.md`
- `<feature-path>/user_br_input.md` only when the source is Jira and fetched story text must be persisted

4. Validate after every write or repair:

```bash
node .overmind/overmind.js gate task-to-br <feature-path>
```

Handle gate exit codes exactly:
- `0`: gate passed; finish.
- `1`: recoverable content issue; read each `missing: ...` line, repair the artifacts, and rerun the gate.
- `2`: runtime or validation failure; stop, report that validation cannot complete, and wait for user instructions.

The model owns the capture/context/generate/gate/repair loop. Do not rely on a separate shell orchestrator to run this step.

When the gate passes, end your final response with this exact last line:

```text
Task-to-BR phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Assets

Asset paths are relative to this loaded skill directory. Do not resolve them through a hardcoded agent install path such as `.claude/skills/...`; use the copy exposed by the current supported CLI.

- `assets/feature_br_summary_TEMPLATE.md`
- `assets/feature_br_summary_GOLDEN_EXAMPLE.md`
- `assets/missing_br_data_TEMPLATE.md`
- `assets/missing_br_data_GOLDEN_EXAMPLE.md`

## Inlined Task-to-BR Rule

### Scope

- Stage goal: decompose an incoming task or story artifact into structured business requirements for BR clarification and EARS readiness.
- This rule fully defines business-context gate checking and missing-data processing via `missing_br_data.md`.

### Hard Constraints

1. Update only:
   - `feature_br_summary.md`
   - `missing_br_data.md`
   - `user_br_input.md` only when the source is Jira and the fetched story text must be persisted into the captured input record
2. Preserve BR section order, headings, keys, and one-line FR/BR item structure.
3. Do not add, remove, or rename BR sections/keys.
4. Fill business sections as much as possible from captured source input, but do not fill, edit, or overwrite `## 13. Existing-System Context` at this stage; preserve any repo-scan content already present.
5. Use only captured user input and current BR content; do not invent facts.
6. Keep unresolved BR values as `[UNFILLED]`.
7. Ensure `## 1. Document Meta` includes:
   - `source_type` containing `User input`
   - `last_updated` in `YYYY-MM-DD`
   - `source_refs` containing every reference listed in the context block's `## Required Source References -> required_source_refs`
8. `missing_br_data.md` is the unresolved-question ledger; keep question-state tracking there.
9. Keep `feature_br_summary.md` as the source of truth for business content.
10. This stage identifies unresolved gaps and prepares follow-up questions only; answer-handling lifecycle is governed by the downstream `overmind-br-clarification` skill.
11. Do not silently assume missing details: every unresolved or low-confidence business detail MUST be externalized as `rised_item_N` (`rised=false`) in `missing_br_data.md`.
12. Ambiguity externalization applies to every populated business field listed in `### Ambiguity Scan Scope`: wording that stays unresolved and materially affects acceptance or verification MUST be converted into an explicit follow-up business question and tracked as an unresolved ledger item.
13. Every explicit source prohibition (for example `no X`, `does not introduce X`, an Out of Scope entry, or a negative Definition of Done statement) MUST be recorded in `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`. The same statement MAY additionally be recorded in another relevant field such as `### 12.4 Operational and rollout -> config_expectations`; that additional placement alone does not satisfy this constraint.
14. Do not write generic placeholder FR/BR content. If a requirement/rule is not specific and traceable to user input, keep it `[UNFILLED]` and track the gap in `missing_br_data.md`.
15. If the source is Jira, persist the fetched story/request text into `user_br_input.md` before finishing so downstream phases retain the actual source narrative.
16. Always create or refresh `missing_br_data.md`, even when no unresolved business gaps are found.

### Missing-Data Externalization

1. Run the gate.
2. If exit `0`, finish.
3. If exit `1`:
   - Create or refresh `missing_br_data.md` using the bundled missing-data template and golden example.
   - Record unresolved items from gate output, plus any ambiguity-triggered gaps found during extraction.
   - Move unresolved non-`rised` values from:
     - `## 14. Assumptions -> ### Needs validation -> assumptions_needing_validation`
     - `## 15. Open Questions`
     - `### 5.3 Open scope boundaries -> unclear_scope_points`
     - every other field in `### Ambiguity Scan Scope` whose populated value stays unresolved or ambiguous
     into `missing_br_data.md` ledger with deterministic `rised_item_N` markers and `rised=false`.
   - For every newly created `rised_item_N`, set `rised=false`.
   - Set moved source BR values in `feature_br_summary.md` to `[UNFILLED]`.
   - Set `## 7. Loop Decision -> unresolved_after_stop` to a concise summary of unresolved business gaps.
4. If exit `2`, stop and report error.
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

### Ledger Terminal State

- The ledger is terminal when `## 3. Unresolved Items Ledger (Rised)` is empty, or when every `rised_item_N` is `rised=true`.
- In either terminal state, set `## 7. Loop Decision -> unresolved_after_stop` to exactly `none`.
- While at least one `rised_item_N` is `rised=false`, keep `unresolved_after_stop` as a filled concise unresolved summary.
- `## 1. Gate Status -> gate_result` is historical evidence of the gate round that produced the ledger: preserve every pre-existing `gate_result` line and value exactly when updating the ledger.

### Deterministic Ledger Markers

- Unresolved entries:
  - `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<text>`
- When one question covers several fields that restate the same fact, name them all in the same `source=` list, comma-separated:
  - `- rised_item_N: source=<section> -> <field>, <section> -> <field>; rised=false; unresolved_item=<text>`
- Numbering rules:
  - deterministic and gap-free
  - `N` starts at `1`

### Ambiguity Scan Scope

- Scanned business fields:
  - `## 2. Source Request Snapshot`, excluding `### 2.2 Raw source references`
  - `## 3. Feature Intent` through `## 12. Non-Functional Requirements`
  - `## 14. Assumptions`
  - `## 15. Open Questions`
- Closed ambiguity triggers enforced by the gate, matched case-insensitively as a whole word or phrase: `fast`, `better`, `simple`, `as needed`, `TBD`, `etc.`.
- Unresolved trigger lifecycle:
  1. add `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<business question>` to `missing_br_data.md`
  2. set that BR field in `feature_br_summary.md` to `[UNFILLED]`
  3. let the downstream `overmind-br-clarification` skill obtain the answer
- One question per fact: a BR often restates the same fact as a constraint, a functional requirement, and a business rule. Raise one ledger item for that question and name every affected field in its `source=` locator list, rather than one item per field.
- Confirmed wording: when the user explicitly confirms the original wording, answer that ledger item with `rised=true`. The populated values may stay in exactly the fields the item names. A field the item does not name stays unconfirmed, because the same trigger word can carry a different question elsewhere in the document.
- The semantic rule reaches further than the closed trigger list: any populated wording in the scanned fields that stays unresolved and materially affects acceptance or verification is externalized the same way.

### Question Scope

- Ask only business-domain follow-up questions.
- Do not ask technical implementation, architecture, framework, deployment, or code-structure questions.

### Runtime Path Bindings

- Runtime path bindings come from the `context task-to-br` output and any orchestrator prompt for the current invocation.
- Treat those runtime bindings as authoritative for the feature root, resolved artifact paths, asset paths, and gate command.
- Do not replace runtime bindings with fixed `overmind/product/...` assumptions.
- Use the emitted feature path and artifact paths exactly when reading, writing, and running the gate.

### Captured Source Binding

1. The context block's `## Required Source References -> required_source_refs` lists every captured source that must appear in `feature_br_summary.md` `## 1. Document Meta -> source_refs`: the feature's `user_br_input.md` capture record followed by the `epic_story_source_file` locator it recorded (a workspace-relative story path, or `jira:<ticket>`).
2. Write the references into `source_refs` as exact semicolon-delimited elements, copied verbatim from the context block.
3. Use the canonical order for newly written values: the `user_br_input.md` capture record first, then the original story source.
4. When `source_refs` already holds other populated references, merge the required references into the existing value and keep the additional ones; do not replace the field wholesale.
5. Replace an `[UNFILLED]` placeholder rather than appending around it: the finished field contains only real source references.
6. Example: `- source_refs: projects/auth-platform/self-service-password-reset/user_br_input.md; jira:JIRA-AUTH-241`

### Quality Criteria

- `## 1. Document Meta -> source_refs` contains every required captured-source reference exactly as emitted in context.
- `### 2.1 Original request summary -> short summary` is filled.
- `### 3.1 Business goal -> primary_business_goal` is filled.
- `## 6. Functional Requirements` has at least one meaningful one-line FR (`- FR-N: ...`).
- `## 7. Business Rules and Decision Logic` has at least one meaningful one-line BR (`- BR-N: ...`).
- `### Needs validation -> assumptions_needing_validation` has no unresolved non-`rised` value.
- `## 15. Open Questions` has no unresolved non-`rised` value.
- `### 5.3 Open scope boundaries -> unclear_scope_points` has no unresolved non-`rised` value.
- Every populated field in `### Ambiguity Scan Scope` is free of unconfirmed ambiguity triggers; a retained trigger has an answered `rised=true` ledger item whose `source=` locator list names that field.
- Every explicit source prohibition appears in `### 2.3 Explicitly stated in source -> stated_constraints` or `### 5.2 Out of scope -> out_of_scope_items`.
- If `missing_br_data.md` contains unresolved `rised_item_N` entries, each entry has `rised=false` or `rised=true`, and `## 7. Loop Decision -> unresolved_after_stop` is filled.
- If `missing_br_data.md` has an empty ledger or every `rised_item_N` is `rised=true`, `## 7. Loop Decision -> unresolved_after_stop` is exactly `none`.
- `missing_br_data.md` exists for every completed task-to-BR run.
- FR/BR lines are concrete and input-traceable; generic/buzzword-only placeholders are not accepted.
- Every populated value is business-readable and traceable to user input.

### Linked Artifact Extraction For Jira Sources

1. This rule applies only when `## 1. Document Meta -> source_type` contains `jira:<ticket>`.
2. After extracting business content, inspect the Jira MCP story response for linked non-text artifacts surfaced by the MCP response.
3. Populate `## 16. Linked Artifacts` in `feature_br_summary.md` with one entry per discovered artifact, using `LAR-NNN` sequential IDs.
4. Always emit `## 16. Linked Artifacts`, even when the list is empty.
5. Each entry must capture `id`, `title`, `type`, and `locator`.
6. Use only these `type` values: `data_schema`, `diagram`, `api_spec`, `design_mock`, `document`, `image`, `pdf`, `other`.
7. Do not download or interpret artifact content; record only metadata.
8. If the MCP response does not surface linked items as structured data, emit `## 16. Linked Artifacts` with an empty list.
