---
name: overmind-br-clarification
description: Use when resolving unresolved business-only BR clarification items tracked in missing_br_data.md and updating feature_br_summary.md before EARS readiness.
---

# Overmind BR Clarification

Use this skill to resolve a feature folder's unresolved business requirements clarification items before EARS generation.

## Required Invocation

Run these commands from the installed project root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context br-clarification <feature-path>
```

2. Read the emitted context block and update only:
- `<feature-path>/feature_br_summary.md`
- `<feature-path>/missing_br_data.md`

3. Validate after every answer round:

```bash
node .overmind/overmind.js gate br-clarification <feature-path>
```

Handle gate exit codes exactly:
- `0`: gate passed; every tracked `rised_item_N` is `rised=true`; finish.
- `1`: recoverable clarification state remains; read each `missing: ...` line, continue the clarification loop, repair artifacts, and rerun the gate. If the gate reports that a ledger item must include `rised=false` or `rised=true`, add `rised=false` to the affected `rised_item_N` entry, rerun the gate, and continue clarification from the unresolved item.
- `2`: runtime or validation failure; stop, report that validation cannot complete, and wait for operator instructions.

After every gate run, show the gate command output to the operator before summarizing the result or taking the next action. Do not replace the gate output with a sentence such as "the final gate passed." The operator must see the verification progress lines, including `rule 1: task-to-br base business-context validation ... PASS`, `rule 2: missing_br_data unresolved BR clarification ledger ... PASS`, and `rule 3: BR clarification is complete for EARS readiness ... PASS` when the gate passes.

The model owns the context/question/write/gate/repair loop. The deterministic readiness transition runs later through `node .overmind/overmind.js readiness br-clarification <feature-path>` and is not part of this skill loop.

When the gate passes, end your final response with this exact last line:

```text
User BR clarification phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Sequential Clarification Protocol

1. At the start of each round, read `## 3. Unresolved Items Ledger (Rised)` in `missing_br_data.md` and show a numbered preview list of every currently unresolved business question before asking any question. The preview list must include each `rised_item_N` id and its unresolved question text. A count alone is not enough. Do not ask the first question until after this full list is shown.
2. If no unresolved questions exist, ask no questions. Run `node .overmind/overmind.js gate br-clarification <feature-path>`; if it exits `0`, finish with the required final response line. If it exits `1` or `2`, follow the gate exit-code handling above.
3. Briefly explain the process: questions will be asked one at a time; the operator may answer or reply `skip for now` to defer a question.
4. Ask only the first unresolved question and wait for the reply before asking the next question.
5. When the operator answers, write the business answer to `feature_br_summary.md` in every field the item's `source=` locator list names, set the matching `rised_item_N` entry to `rised=true`, and add one pointer-only `- answers:` destination line per field written in `## 6. Latest User Answers`. An item may only become `rised=true` once each field it names carries the answered wording: a partially applied answer leaves the remaining fields stale while the task-to-BR gate treats every named field as settled. When that answer was the last `rised=false` item, also set `## 7. Loop Decision -> unresolved_after_stop` to exactly `none`, and leave `## 1. Gate Status -> gate_result` unchanged.
6. When the operator replies `skip for now` or otherwise declines to answer, leave that item `rised=false`, write no answer content for it, and move to the next question in the same pass.
7. After each pass, run `node .overmind/overmind.js gate br-clarification <feature-path>`.
8. If the gate exits `1`, do not declare completion, do not emit the final response line, and do not advance to the next phase. Start a new round and re-offer deferred questions until every tracked item is answered and the gate exits `0`.
9. If the session ends while any item remains `rised=false`, the phase is incomplete; do not run readiness or claim the next phase may start.

## Assets

Asset paths are relative to this loaded skill directory. Do not resolve them through a hardcoded agent install path such as `.codex/skills/...` or `.claude/skills/...`; use the copy exposed by the current supported CLI.

- `assets/feature_br_summary_TEMPLATE.md`
- `assets/feature_br_summary_GOLDEN_EXAMPLE.md`

## Inlined User BR Clarification Rule

### Scope

- Stage goal: resolve unresolved business-only gaps tracked in `missing_br_data.md`.
- This rule is isolated and self-sufficient for user BR clarification behavior.

### Hard Constraints

1. Update only:
   - `feature_br_summary.md` (business answers source of truth)
   - `missing_br_data.md` (question-state ledger)
2. Ask only business-domain follow-up questions.
3. Do not ask technical implementation, architecture, framework, deployment, or code-structure questions.
4. Keep `missing_br_data.md` as a question-state ledger.
5. Use one deterministic tracking flag:
   - `rised=false` means not yet discussed with user.
   - `rised=true` means item has been discussed with user.
6. Keep `feature_br_summary.md` as the source of truth for business content.
7. Keep `## 6. Latest User Answers` pointer-only; use it only for destination traceability entries.
8. Do not duplicate answer narrative text in `missing_br_data.md`; keep only `rised` state and destination-pointer entries.
9. Preserve BR section order, headings, keys, and one-line FR/BR item structure.
10. Treat user-provided links as business input only when they answer or materially clarify the currently discussed business question.
11. If a user-provided link does not answer the current business question, do not use its content and do not preserve the link.
12. If a user-provided link contains relevant content plus unrelated extra material, write only the question-relevant business content into `feature_br_summary.md`.
13. Apply the recording rules in `## User-Provided Link Preservation` only to links that satisfy constraints 10-12.

### Quality-Gate Loop

1. Read unresolved ledger items in `missing_br_data.md` and treat items as unresolved while they are not `rised=true`.
2. Ask targeted business-only follow-up questions mapped to unresolved ledger items.
3. Treat direct text answers and relevant user-provided links as equivalent forms of business input for the current clarification round.
4. Use information from a user-provided link only when that link answers or materially clarifies the currently discussed unresolved item.
5. If a user-provided link does not answer the current unresolved item, ignore that link for both BR content and linked-artifact preservation.
6. If a user-provided link contains more information than needed, write only the business content that answers the current question to `feature_br_summary.md`.
7. Write actual answer content only to `feature_br_summary.md`.
8. After an item is actually discussed with user and its answer is written to `feature_br_summary.md` in every field the item's `source=` locator list names, update the matching `rised_item_N` entry to `rised=true`.
9. Record answer destinations in `missing_br_data.md` using one deterministic pointer entry per destination field written:
   - `- answers: This was recorded in ## <section-number>. <section-title> - <field/item-id>.`
10. When that update leaves every tracked `rised_item_N` at `rised=true`, set `## 7. Loop Decision -> unresolved_after_stop` to exactly `none` in the same write, before rerunning the gate.
11. Rerun `node .overmind/overmind.js gate br-clarification <feature-path>`.
12. If the gate exits `1`, continue the loop and do not declare completion.
13. Stop only when the gate exits `0` and all tracked `rised_item_N` entries are `rised=true`.
14. Do not stop early while any tracked `rised_item_N` remains `rised=false`.

### Ledger Terminal State

- The ledger is terminal when `## 3. Unresolved Items Ledger (Rised)` is empty, or when every `rised_item_N` is `rised=true`.
- In either terminal state, `## 7. Loop Decision -> unresolved_after_stop` must be exactly `none`; write it as part of recording the final answer, before the next gate run.
- While at least one `rised_item_N` is `rised=false`, keep `unresolved_after_stop` as a filled concise unresolved summary.
- `## 1. Gate Status -> gate_result` is historical evidence of the gate round that produced the ledger: preserve every pre-existing `gate_result` line and value exactly. A historical `gate_result: failed` is never itself a reason for the gate to fail, and does not need rewriting to reach exit `0`.

### Deterministic Ledger Markers

- Unresolved entries:
  - `- rised_item_N: source=<section> -> <field>; rised=false; unresolved_item=<text>`
- Discussed/raised entries:
  - `- rised_item_N: source=<section> -> <field>; rised=true; unresolved_item=<text>`
- One question may cover several BR fields that restate the same fact. Such an item names them all in the same `source=` list, comma-separated, and the list is authoritative for where the answer must land:
  - `- rised_item_N: source=<section> -> <field>, <section> -> <field>; rised=true; unresolved_item=<text>`
- Preserve the `source=` locator list exactly when updating an item; never drop a field from it.
- Numbering rules:
  - deterministic and gap-free
  - `N` starts at `1`

### Latest User Answers Traceability

- Section shape:
  - `## 6. Latest User Answers` may contain one or more repeated `- answers:` lines.
  - Use one `- answers:` line per destination field written. An item whose `source=` locator list names several fields therefore produces one line per named field.
- Canonical format:
  - `- answers: This was recorded in ## <section-number>. <section-title> - <field/item-id>.`
- Interpretation:
  - Each `- answers:` line stores destination traceability only.
  - It must not include answer narrative text.
- `field/item-id` examples:
  - one-line BR/FR items: `BR-6`, `FR-3`
  - named fields: `critical_questions`, `unclear_scope_points`, `assumptions_needing_validation`

### User-Provided Link Preservation

- For each qualifying URL that is actually used as business input for the current clarification round, append one entry to `## 16. Linked Artifacts` in `feature_br_summary.md`.
- Reuse the existing linked-artifact schema exactly:
  - `id`: next gap-free `LAR-NNN` identifier continuing any entries already present in the document
  - `title`: human-readable title derived from the linked page metadata when available, otherwise from the URL path
  - `type`: one value from the closed vocabulary `data_schema | diagram | api_spec | design_mock | document | image | pdf | other`
  - `locator`: the exact user-provided URL
- If a URL already exists as a `locator` in `## 16. Linked Artifacts`, do not add a duplicate entry.
- When the artifact type is ambiguous, use `document`.
- If a user reply contains no qualifying HTTP(S) URLs, leave `## 16. Linked Artifacts` unchanged for that round.

### Runtime Path Bindings

- Runtime path bindings come from the `context br-clarification` output and any orchestrator prompt for the current invocation.
- Treat those runtime bindings as authoritative for the feature root, resolved artifact paths, asset paths, and gate command.
- Do not replace runtime bindings with fixed `overmind/product/...` assumptions.
- Use the emitted feature path and artifact paths exactly when reading, writing, and running the gate.
