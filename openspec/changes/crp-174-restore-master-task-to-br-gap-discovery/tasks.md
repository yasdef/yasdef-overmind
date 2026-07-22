## 1. Restore Master-Style Task-to-BR Discovery

- [x] 1.1 Rewrite the inlined operational rule in `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` so step 4.1 externalizes every relevant unresolved or low-confidence business detail as one targeted `rised=false` question instead of silently inferring an answer.
- [x] 1.2 Remove CRP-172's dedicated Source-Obligation Review, behavioral-materiality taxonomy, question-suppression clauses, and closed ambiguity-scan policy from the skill without adding a replacement decision framework.
- [x] 1.3 Preserve the existing capture/context commands, raw-source binding, allowed writes, source references, Jira persistence, linked-artifact extraction, missing-data lifecycle, ledger syntax, terminal-state rules, and gate exit-code handling while simplifying the discovery rule.
- [x] 1.4 Keep step 4.2 unchanged as the consumer of pending `rised_item_N` entries and confirm the restored Task-to-BR contract creates no new phase, artifact, state, command, or CLI option.

## 2. Return the Validator to Deterministic Structure

- [x] 2.1 Remove the closed ambiguity-trigger constants, generated-BR token scan, field-grouping logic, and ambiguity-trigger diagnostics from `packages/asdlc-coordinator/src/validate/task-to-br.ts` while preserving all structural, source-binding, ledger, answer-pointer, and terminal-state validation.
- [x] 2.2 Update `packages/asdlc-coordinator/test/task-to-br-validator.test.ts` so configured words such as `simple` do not independently fail the gate and the surviving structural and ledger failures remain covered.
- [x] 2.3 Run the focused Task-to-BR and BR-clarification validator suites to confirm gate exit codes and the step 4.2 consumer contract remain stable after lexical enforcement is removed.

## 3. Align Examples and Installed Contracts

- [x] 3.1 Align `packages/installer/_data/skills/overmind-task-to-br/assets/feature_br_summary_GOLDEN_EXAMPLE.md` and `packages/installer/_data/skills/overmind-task-to-br/assets/missing_br_data_GOLDEN_EXAMPLE.md` to illustrate several useful active business-gap questions without embedding normative policy, an exact question count, or exclusion-focused commentary.
- [x] 3.2 Update `packages/installer/test/semantic-preservation-contract.test.ts` to assert the restored active-discovery rule and the preserved modern contracts named in task 1.3, and remove assertions for CRP-172's Source-Obligation Review and lexical-backstop policy.
- [x] 3.3 Update fresh-install assertions in `packages/installer/test/init.test.ts` so installed Codex and Claude Task-to-BR skills contain the restored contract and no closed lexical policy.
- [x] 3.4 Confirm the structural templates remain unchanged and the golden example remains illustrative rather than a source of operational rules.

## 4. Verify the Scoped Restoration

- [x] 4.1 Run `npm run test --workspace asdlc-coordinator` and `npm run test --workspace overmind-installer`.
- [x] 4.2 Run repository-level `npm test` and `npm run verify`.
- [x] 4.3 Review the final diff to confirm it changes only Task-to-BR discovery, its validator, examples, and related tests; step 4.2, EARS generation, step 5.1, templates, README files, and workflow sequencing remain unchanged.
