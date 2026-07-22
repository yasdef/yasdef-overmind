## 1. Orchestrator change

- [x] 1.1 In `packages/asdlc-coordinator/src/orchestrator/run-feature-flow.ts`, pass `deps.projectRoot` instead of `deps.workspaceRoot` at both checkpoint call sites (before-step and after-8.4 boundaries).
- [x] 1.2 Confirm no other feature-flow git usage targets the runtime root (search the orchestrator for the checkpoint dep; project/class scopes stay untouched).

## 2. Tests

- [x] 2.1 Update `packages/asdlc-coordinator/test/checkpoint-commits.test.ts`: the injected git runner asserts the received root is the project root at every boundary (before 5.1, before 7.1, before/after 8.4).
- [x] 2.2 Add the negative assertion: the checkpoint root is never the workspace/runtime root.
- [x] 2.3 Add/adjust the non-git-project scenario: project folder not a worktree → each boundary renders a `notWorktree` notice and the run proceeds (runtime root git state irrelevant to the outcome).
- [x] 2.4 Update `packages/asdlc-coordinator/test/feature-orchestrator.test.ts` fixtures/assertions that encode the old runtime-root checkpoint scope.

## 3. Verification

- [x] 3.1 Run `npm run test --workspace asdlc-coordinator`, then `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`, `npm test`.
- [x] 3.2 Run `npm run verify` and `git diff --check`.
- [x] 3.3 Assert `packages/asdlc-coordinator/package.json` still has `"dependencies": {}`.
- [x] 3.4 Run strict OpenSpec validation for this change (`openspec validate crp-157-project-scoped-checkpoint-commits --strict`).

## 4. Review fixes

- [x] 4.1 Correct the `notWorktree` checkpoint notice to name the supplied repository root instead of the runtime root, and lock the wording with tests.
- [x] 4.2 Keep `checkpoint-commits.test.ts` focused on `RepoGitAdapter` and move non-worktree feature-flow notice coverage to `feature-orchestrator.test.ts`.
- [x] 4.3 Replace redundant runtime-root negative assertions with a checkpoint test double guard that fails when a forbidden root is passed.
