## 1. Dual-source runtime binding

- [x] 1.1 Update `packages/asdlc-coordinator/src/context/ears-review.ts` to require `user_br_input.md` alongside `feature_br_summary.md` and `requirements_ears.md`, emit distinct authoritative-summary and raw-backstop bindings, and return exit `2` with a named diagnostic when either source is missing
- [x] 1.2 Introduce a dedicated step `5.1` source guard in `packages/asdlc-coordinator/src/sequencing/step-catalog.ts` that protects both `feature_br_summary.md` and `user_br_input.md`; do not add `user_br_input.md` to the shared `brSummaryGuard`, and keep step `5` protecting only `feature_br_summary.md`
- [x] 1.3 Update the EARS-review recipe in `packages/asdlc-coordinator/src/runner/prompt-builder.ts` so its runtime bindings name both read-only business sources and leave semantic precedence rules in the skill

## 2. EARS-review semantic contract and ledger

- [x] 2.1 Update `packages/installer/_data/skills/overmind-ears-review/SKILL.md` to read both sources, keep clarified `feature_br_summary.md` decisions authoritative, perform a raw-to-summary and raw-to-EARS narrowing sweep, and require every narrowing to become a material finding without automatically overwriting clarified decisions
- [x] 2.2 Define narrowing in the skill using actionable examples, including an `ACTIVE` qualifier that weakens a status-independent duplicate-account prohibition, and require raw, summary, and affected-EARS citations in that finding
- [x] 2.3 Update the packaged review template and golden example to add `source_user_br_input` metadata and `source_user_br_input_reference` per finding, using `none` for findings unrelated to raw drift and demonstrating the `ACTIVE`-qualifier regression in the golden example
- [x] 2.4 Update `packages/asdlc-coordinator/src/validate/ears-review.ts` so missing or unfilled dual-source metadata and finding-reference fields produce recoverable exit `1` diagnostics while existing finding-state behavior remains intact

## 3. Future design and operational documentation

- [x] 3.1 Amend `design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` so embedded verification uses the BR summary as clarified-decision authority and raw input as an independent mandatory narrowing backstop
- [x] 3.2 Update the EARS-review contract descriptions in `overmind/README.md` and `README.md` with the dual-source input contract, keeping durable operational guidance concise

## 4. Regression and deployability tests

- [x] 4.1 Extend EARS-review context and session-prompt tests for both emitted source bindings, missing `user_br_input.md`, missing `feature_br_summary.md`, absolute feature paths, the unchanged gate command, and the unchanged allowed-write list
- [x] 4.2 Extend EARS-review validator tests for required `source_user_br_input` metadata and `source_user_br_input_reference`, including `none` for a non-raw finding and concrete dual citations for a raw-narrowing finding
- [x] 4.3 Add step-catalog and executor coverage proving step `5.1` uses its separate dual-source guard and rejects mutation or deletion of either source on every agent exit path, while step `5` retains the unchanged summary-only guard
- [x] 4.4 Extend installer tests to prove fresh Codex and Claude skill installations contain the updated dual-source skill, template, and golden-example contract without introducing a new CLI command or flag
- [x] 4.5 Add a temporary-workspace smoke fixture where raw input forbids duplicates for the same user and account type while the summary or EARS adds `ACTIVE`, and verify the installed skill contract and golden example require a finding that cites all three locations

## 5. Verification

- [x] 5.1 Run `npm run test --workspace asdlc-coordinator`, `npm run test --workspace overmind-installer`, `npm test`, and `npm run verify` from the repository root and fix regressions
