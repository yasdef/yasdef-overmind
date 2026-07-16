## 1. Restore Focused Semantic Question Discovery

- [ ] 1.1 Rewrite the inlined operational rules in `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` so step 4.1 performs one focused source-obligation review and externalizes every material unresolved business decision through the existing `[UNFILLED]` plus `rised=false` ledger contract.
- [ ] 1.2 Define question materiality and consolidation in the same skill by observable acceptance impact, including the rules for source-answered facts, descriptive bounded wording, technical choices, and one ledger item per independent decision.
- [ ] 1.3 Remove or consolidate only duplicated semantic-completeness and ambiguity-gate prose from the Task-to-BR skill while preserving capture, runtime-path, ledger, source-reference, linked-artifact, readiness, and final-gate contracts.
- [ ] 1.4 Keep `packages/asdlc-coordinator/src/validate/task-to-br.ts` and step 4.2 behavior unchanged, with the current generated-BR lexical check documented only as a deterministic backstop.

## 2. Update Examples and Contract Coverage

- [ ] 2.1 Update the existing Task-to-BR golden examples to show a material acceptance-affecting ambiguity becoming one targeted question and a descriptive but fully bounded phrase producing no redundant question.
- [ ] 2.2 Extend `packages/installer/test/semantic-preservation-contract.test.ts` to assert the focused source-obligation review, materiality/consolidation rules, and bounded lexical-backstop role without encoding exact model wording; also assert that the existing capture, runtime-path, ledger-syntax, source-reference, linked-artifact, readiness, and final-gate clauses named in task 1.3 remain present after the rewrite.
- [ ] 2.3 Update installer propagation assertions so fresh Claude and Codex skill installations contain the revised Task-to-BR contract and introduce no new command, flag, artifact, or phase.
- [ ] 2.4 Run the existing Task-to-BR validator and ledger contract tests to prove the TypeScript gate, artifact format, exit codes, and step 4.2 consumer contract remain intact.

## 3. Verify Repository Behavior

- [ ] 3.1 Run `npm run test --workspace overmind-installer` and `npm run test --workspace asdlc-coordinator`.
- [ ] 3.2 Run repository-level `npm test` and `npm run verify`.

## 4. Prove Behavioral Recovery

- [ ] 4.1 Install the candidate packaged skill into three clean runtime workspaces and run step 4.1 independently on the identical measured UMSS source with the configured model settings; evaluate only step 4.1 outputs, without depending on CRP-173 or step 5.1.
- [ ] 4.2 Verify every run asks about valid Telegram-data criteria, the outcome when new-identity creation encounters an inconsistent pre-existing OFFCHAIN_POINTS account without a corresponding identity, and the under-specified frontend error response.
- [ ] 4.3 Apply the behavioral-impact materiality rule to every additional question, including whether user counts include identities without an ACTIVE OFFCHAIN_POINTS account; do not fail or pass a run merely because master did or did not ask it.
- [ ] 4.4 Record the three-run batch in the task completion notes; if any required decision is missed, fail the entire batch, correct the skill or example for the missed obligation, rerun contract verification, and execute one fresh three-run batch instead of adding favorable samples.
- [ ] 4.5 If any run in the replacement batch still misses a required decision, leave this CRP behaviorally incomplete and return to the owner for explicit disposition before changing acceptance or running another batch.
