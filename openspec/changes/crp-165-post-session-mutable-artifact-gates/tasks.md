> **Dependency:** CRP-163 must be implemented or merged first. CRP-165 is implemented on top of CRP-163's dedicated step `5.1` dual-source read-only guard; standalone implementation must not substitute the current shared `brSummaryGuard` or omit the coexistence coverage.

## 1. Mutable-surface contract, catalog wiring, and shared gate registry

- [x] 1.1 Add an exported typed review-session contract for ordered `{ artifact, gate }` entries, extend the session action type and `session(...)` catalog helper with optional `postSessionGates`, and make the EARS-review and plan-semantic-review context builders render their mutable targets and `## Allowed Write Surface` entries from the applicable shared contract
- [x] 1.2 Define `requirements_ears.md` → `requirements-ears` and `requirements_ears_review.md` → `ears-review` for step `5.1`, and `implementation_plan.md` → `implementation-plan` and `implementation_plan_semantic_review.md` → `plan-semantic-review` for step `8.4`; attach those exact shared entries to the catalog actions while preserving CRP-163's dedicated step `5.1` read-only guard and the current required outputs
- [x] 1.3 Extract the non-class CLI gate mapping into one exported typed validator registry with feature-path, runtime-root, and optional-progress invocation inputs; update standalone CLI dispatch to use it while preserving the `br-clarification` progress sink, syntax, and behavior; and inject the same registry through `StepExecutorDeps` for post-session execution

## 2. Post-session executor enforcement

- [x] 2.1 Update `packages/asdlc-coordinator/src/runner/execute-step.ts` so an agent exit `0` triggers every declared post-session gate against `bindings.featurePath` and `bindings.runtimeRoot` after existing guard/output checks and before action success, while skipped or non-zero agent sessions and actions without a gate set preserve current behavior
- [x] 2.2 Aggregate the full ordered gate set without fail-fast; emit artifact-and-gate-specific diagnostics containing recoverable problems or runtime errors for every non-zero result
- [x] 2.3 Return action exit `1` when one or more gates are recoverably invalid and no exit-`2` condition exists; return exit `2` when a gate cannot run, a declared gate is unregistered, or another post-session integrity check fails, while retaining all collected diagnostics
- [x] 2.4 Keep coordinator repair and automatic retry out of the executor/orchestrator; propagate exit `1` and `2` unchanged through the existing failed-action result so the failed review action is not completed or checkpointed in that run. Repair is operator-driven (rerun/resume the review); persisting a failed optional review across runs is a non-goal.

## 3. Canonical workflow and operational documentation

- [x] 3.1 Update `overmind/init_progress_definition_sequence_diagram.md` at `(optional) requirement_ears extra review` and `(optional) implementation plan semantic review` to show the normative artifact gate and ledger gate as post-session completion checks
- [x] 3.2 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` `step_number: 5.1` and `step_number: 8.4` completion conditions so both mutable artifacts must pass their owning post-session gates
- [x] 3.3 Document the coordinator backstop and repair-by-rerun behavior concisely in `overmind/README.md` and the existing review-runtime description in `README.md`, keeping model-owned in-session loops distinct from coordinator-owned final verification

## 4. Coordinator and regression tests

- [x] 4.1 Add contract tests proving the EARS-review and plan-semantic-review context builders and their catalog actions consume the same exported typed mutable sets with exactly the two specified artifact-to-gate mappings, and that CRP-163's step `5.1` read-only guard coexists with the mutable gate set
- [x] 4.2 Extend executor tests for stable gate order, all-pass success, first-gate failure with later-gate execution, multiple diagnostics, exit-`1` recovery, exit-`2` precedence, an unregistered gate, no configured set, and a non-zero agent exit that does not invoke gates
- [x] 4.3 Add an EARS-review regression fixture where a valid completed review ledger accompanies invalid `WHEN ..., THEN THE ... SHALL ...` bullets in `requirements_ears.md`; prove `ears-review` still runs, `requirements-ears` fails, and step `5.1` is rejected with the EARS artifact/gate diagnostic
- [x] 4.4 Add the symmetric plan-semantic-review fixture where the review ledger passes but `implementation_plan.md` fails, proving step `8.4` is rejected after both gates run
- [x] 4.5 Extend feature-orchestrator tests to prove post-session action exit `1` and exit `2` propagate unchanged into the flow result, neither reaches the review checkpoint/advance path, exit `1` does not automatically re-dispatch the action or agent, and an operator-driven later run with the full mutable set passing follows the existing checkpoint path
- [x] 4.6 Add registry parity tests proving standalone CLI and executor dispatch use the same validator and preserve current gate exit classifications

## 5. Bundled runtime deployability

- [x] 5.1 Extend installer fresh/update coverage to prove the newly built coordinator bundle is copied or refreshed at `.overmind/overmind.js` without adding a runtime command, CLI flag, or skill asset; leave behavioral enforcement proof to the installed-workspace smoke flow in task 5.2
- [x] 5.2 Run a temporary installed-workspace smoke flow with stubbed model execution where a review ledger passes and its normative artifact fails, and verify the installed coordinator rejects completion before checkpointing

## 6. Verification

- [x] 6.1 Run `npm run test --workspace asdlc-coordinator`, `npm run test --workspace overmind-installer`, `npm test`, and `npm run verify` from the repository root and fix regressions
