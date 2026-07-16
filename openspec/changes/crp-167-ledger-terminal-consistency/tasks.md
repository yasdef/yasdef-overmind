> **Implementation dependency:** CRP-164 (`crp-164-task-to-br-source-ref-binding`) must be implemented first. Extend its shared task-to-BR parsing and validator path; do not replace or bypass its source-reference checks.

## 1. Shared ledger parsing and task-to-BR gate

- [x] 1.1 Extend the CRP-164-aligned `MissingBrData` type and `readMissingBrData` parser to expose the trimmed `## 7. Loop Decision -> unresolved_after_stop` value while retaining the existing item-state data and any-answer boolean
- [x] 1.2 Update `packages/asdlc-coordinator/src/validate/task-to-br.ts` so an empty ledger or a non-empty all-`rised=true` ledger requires the exact literal `unresolved_after_stop: none`, returning recoverable exit `1` with the full `missing_br_data.md -> ## 7. Loop Decision -> unresolved_after_stop` diagnostic for stale, missing, empty, or unfilled terminal values
- [x] 1.3 Keep pending ledgers on the existing filled-summary path, keep all existing missing-artifact/runtime exit classifications, and make terminal validation independent of `## 1. Gate Status -> gate_result`
- [x] 1.4 Verify `validateBrClarification` continues to compose `validateTaskToBr` so a stale all-answered terminal summary is propagated as base-gate exit `1` before BR clarification can report completion

## 2. Durable and packaged model contracts

- [x] 2.1 Update `overmind/rules/task_to_br_rule.md` to require `## 7. Loop Decision -> unresolved_after_stop: none` for both an empty ledger and an all-`rised=true` ledger, and to preserve every pre-existing `## 1. Gate Status -> gate_result` value when the ledger is updated
- [x] 2.2 Mirror the terminal-summary and historical-`gate_result` preservation clauses in `packages/installer/_data/skills/overmind-task-to-br/SKILL.md`
- [x] 2.3 Update `packages/installer/_data/skills/overmind-br-clarification/SKILL.md` so recording the final answer also sets `## 7. Loop Decision -> unresolved_after_stop` to `none` before the next gate run and leaves every pre-existing `gate_result` value unchanged

## 3. Canonical flow and runtime documentation

- [x] 3.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` step `Clarify BR and check EARS readiness` completion conditions to require `missing_br_data.md` `## 7. Loop Decision -> unresolved_after_stop: none` after every tracked item is `rised=true`, while preserving historical `## 1. Gate Status -> gate_result`
- [x] 3.2 Update `overmind/init_progress_definition_sequence_diagram.md` block `Phase: feature` and loop `Until ready_to_ears` with the matching terminal-ledger completion note
- [x] 3.3 Add concise operator guidance under `overmind/README.md ## Task-to-BR and BR Clarification Ledger State`, distinguishing the current `unresolved_after_stop` summary from historical `gate_result` evidence and documenting the recoverable repair

## 4. Regression, bundle, and deployability coverage

- [x] 4.1 Add focused parser tests for trimmed `unresolved_after_stop` extraction across `none`, pending text, `[UNFILLED]`, empty, and absent values
- [x] 4.2 Extend task-to-BR validator tests for empty-ledger `none`, empty-ledger stale/unfilled failure, all-`rised=true` `none`, all-`rised=true` stale-text failure, and a mixed/pending ledger that retains its filled summary
- [x] 4.3 Add a task-to-BR regression fixture with `gate_result: failed`, all items `rised=true`, answer traceability populated, and `unresolved_after_stop: none`; assert exit `0` and byte-identical ledger content before and after the read-only gate call
- [x] 4.4 Update BR-clarification validator and CLI progress tests so an all-`rised=true` stale summary fails through rule 1, while the same ledger with `none` reaches all three passing progress lines
- [x] 4.5 Extend source-contract tests to require the same terminal-summary rule in `overmind/rules/task_to_br_rule.md` and both packaged skills, including the final-answer update and historical-`gate_result` preservation instructions
- [x] 4.6 Rebuild the coordinator through its canonical build command and verify `packages/asdlc-coordinator/dist/overmind.js` carries the terminal check with the same exit `1` diagnostic as the source validator
- [x] 4.7 Extend installer fresh- and update-mode tests to prove both `.codex/skills/` and `.claude/skills/` receive the updated task-to-BR and BR-clarification contracts, and that the installed coordinator bundle rejects the stale terminal fixture

## 5. Verification

- [x] 5.1 Run `npm run test --workspace asdlc-coordinator` and `npm run test --workspace overmind-installer` from the repository root and fix regressions
- [x] 5.2 Run `npm test` and `npm run verify` from the repository root and fix regressions
