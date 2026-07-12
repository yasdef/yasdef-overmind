## 1. Scope the context pre-call

- [x] 1.1 In `packages/asdlc-coordinator/src/runner/execute-step.ts`, compute in `executeSessionAction` whether the action needs context: `const needsContext = action.readOnlyGuards.some((guard) => guard.mode === "fromContext") || deps.classListContext?.[action.skillName] !== undefined;`.
- [x] 1.2 Guard the context-building block (the `deps.context` / `deps.classListContext` invocation and its non-zero-exit failure return) so it runs only when `needsContext` is true.
- [x] 1.3 When `needsContext` is false, skip the builder and snapshot read-only guards against an empty from-context input list, so `resolveContextReadOnlyInputs` / `snapshotReadOnlyGuards` receive no context-derived paths. Leave the true-branch path (build → fail-on-nonzero → resolve → validate → snapshot) unchanged.
- [x] 1.4 Confirm no other step in `executeSessionAction` (runIf, requiresSync, model/phase resolution, `buildSessionPrompt`, guard validation, session launch) is reordered or altered, and that the `Action` / `ReadOnlyGuard` types are not changed.

## 2. Tests

- [x] 2.1 Add an executor test: a session action with no `fromContext` guard does not invoke `deps.context` (spy/stub) and still launches, even when that builder would return a non-zero exit.
- [x] 2.2 Add an executor test: a session action with a `fromContext` guard whose context builder exits non-zero fails the step with that exit code and diagnostic and launches no session.
- [x] 2.3 Add an orchestrator-level test: a freshly scaffolded feature (only `feature_br_summary.md` present) reaching step `4.1` launches the `task-to-br` session instead of failing on a missing `user_br_input.md`.

## 3. Verify

- [x] 3.1 Run `npm test`, `npm run verify`, and `npm run test --workspace asdlc-coordinator` from the repository root; confirm the pre-existing task-to-br, sequencing, and executor suites still pass.
- [x] 3.2 Drive the flow end to end in a scratch workspace: scaffold a feature through `overmind run`, then `overmind run --path projects/<id> --resume 4.1` launches the task-to-br session and prompts for a source rather than aborting on a missing `user_br_input.md`.
