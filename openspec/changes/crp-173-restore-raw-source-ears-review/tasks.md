## 1. Restore Dual-Fidelity EARS Review

- [ ] 1.1 Rewrite the inlined operational rules in `packages/installer/_data/skills/overmind-ears-review/SKILL.md` so the existing step 5.1 session performs raw capture-fidelity review before clarified-BR translation-fidelity review.
- [ ] 1.2 Replace `Mandatory Raw-Input Narrowing Sweep` with one compact raw-fidelity taxonomy covering lost obligations, removed or added guards, unsupported broadening or narrowing, actor or state changes, contradictions, and invented behavior.
- [ ] 1.3 Preserve explicit clarified decisions as current authority only when an answered `rised=true` item in `missing_br_data.md` maps through its `source=` locator to the resolved answer in `feature_br_summary.md`; require other raw/BR discrepancies to become operator findings instead of being silently ignored or overwritten.
- [ ] 1.4 Require concrete raw provenance for raw-drift findings, permit `source_user_br_input_reference: none` only for BR-only translation findings, and require both semantic comparisons before `no_findings: true`.
- [ ] 1.5 Update `packages/asdlc-coordinator/src/context/ears-review.ts` to require and emit the read-only `missing_br_data.md` path, inline the parsed captured story from `user_br_input.md`, and inline the clarification ledger under distinct context headings using the existing Task-to-BR context pattern.
- [ ] 1.6 Keep the current review ledger, operator loop, validator, mutable-artifact set, gate exit codes, commands, model session, and step boundaries unchanged.

## 2. Update Examples and Contract Coverage

- [ ] 2.1 Revise the existing EARS-review golden example to demonstrate removed-guard or unsupported-broadening recovery with raw, BR, and EARS evidence, plus a BR-only translation finding that truthfully uses `source_user_br_input_reference: none`.
- [ ] 2.2 Update installer contract tests that currently assert `Mandatory Raw-Input Narrowing Sweep` so they assert the ordered dual-fidelity contract and complete raw-drift taxonomy instead.
- [ ] 2.3 Extend installer propagation assertions so fresh Claude and Codex skill installations contain the revised EARS-review contract and introduce no new command, flag, artifact, model session, or phase.
- [ ] 2.4 Extend EARS-review context tests to prove raw-story and clarification-ledger contents are inlined, all source paths remain bound, a missing clarification ledger returns exit code 2, and the allowed-write surface remains unchanged.
- [ ] 2.5 Run existing EARS-review validator, review-session, and post-session-gate tests to prove ledger structure, `no_findings` syntax, source guards, exit codes, and interaction behavior remain intact.
- [ ] 2.6 Review the existing EARS-review description in `overmind/README.md` and update its current sentence only if needed to accurately describe raw capture fidelity plus clarified-BR translation fidelity; do not add phase-specific mechanics or a change log.

## 3. Verify Repository Behavior

- [ ] 3.1 Run `npm run test --workspace overmind-installer` and `npm run test --workspace asdlc-coordinator`.
- [ ] 3.2 Run repository-level `npm test` and `npm run verify`.

## 4. Prove Behavioral Recovery

- [ ] 4.1 Before CRP-172 can change the measured BR baseline, freeze copies of the current v3 `user_br_input.md`, `feature_br_summary.md`, `missing_br_data.md`, and `requirements_ears.md`; document that the current EARS file is the pre-review state because the original `no_findings: true` review applied no edits.
- [ ] 4.2 Install the candidate packaged skill into three clean runtime workspaces and run one step-5.1 acceptance batch independently over the frozen v3 inputs with the configured model settings.
- [ ] 4.3 Verify every run reports the removed OFFCHAIN_POINTS account-resolution precondition as raw capture drift with concrete raw provenance and does not report an actor mismatch solely because the mandated EARS form uses `THE User Management Service System` for administration-website display behavior.
- [ ] 4.4 Record the three-run batch in the task completion notes; if any run misses the required raw-drift finding, fail the entire batch, correct the skill, context, or example for the missed comparison, rerun contract verification, and execute one fresh three-run batch instead of adding favorable samples.
- [ ] 4.5 If any run in the replacement batch still misses the required finding, leave this CRP behaviorally incomplete and return to the owner for explicit disposition before changing acceptance or running another batch.
