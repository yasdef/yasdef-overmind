## 1. Restore Focused Semantic Question Discovery

- [x] 1.1 Rewrite the inlined operational rules in `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` so step 4.1 performs one focused source-obligation review and externalizes every material unresolved business decision through the existing `[UNFILLED]` plus `rised=false` ledger contract.
- [x] 1.2 Define question materiality and consolidation in the same skill by observable acceptance impact, including the rules for source-answered facts, descriptive bounded wording, technical choices, and one ledger item per independent decision.
- [x] 1.3 Remove or consolidate only duplicated semantic-completeness and ambiguity-gate prose from the Task-to-BR skill while preserving capture, runtime-path, ledger, source-reference, linked-artifact, readiness, and final-gate contracts.
- [x] 1.4 Keep `packages/asdlc-coordinator/src/validate/task-to-br.ts` and step 4.2 behavior unchanged, with the current generated-BR lexical check documented only as a deterministic backstop.

## 2. Update Examples and Contract Coverage

- [x] 2.1 Update the existing Task-to-BR golden examples to show a material acceptance-affecting ambiguity becoming one targeted question and a descriptive but fully bounded phrase producing no redundant question.
- [x] 2.2 Extend `packages/installer/test/semantic-preservation-contract.test.ts` to assert the focused source-obligation review, materiality/consolidation rules, and bounded lexical-backstop role without encoding exact model wording; also assert that the existing capture, runtime-path, ledger-syntax, source-reference, linked-artifact, readiness, and final-gate clauses named in task 1.3 remain present after the rewrite.
- [x] 2.3 Update installer propagation assertions so fresh Claude and Codex skill installations contain the revised Task-to-BR contract and introduce no new command, flag, artifact, or phase.
- [x] 2.4 Run the existing Task-to-BR validator and ledger contract tests to prove the TypeScript gate, artifact format, exit codes, and step 4.2 consumer contract remain intact.

## 3. Verify Repository Behavior

- [x] 3.1 Run `npm run test --workspace overmind-installer` and `npm run test --workspace asdlc-coordinator`.
- [x] 3.2 Run repository-level `npm test` and `npm run verify`.
