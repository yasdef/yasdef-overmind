> **Dependencies:** CRP-166 must be implemented; the completion boundary sits behind its run-once terminal gate chain helper and must not be reachable when that chain fails.

## 1. Completion label and notices

- [x] 1.1 Replace `CHECKPOINT_LABELS.after84` in `packages/asdlc-coordinator/src/git/index.ts` with a feature-completion label, leaving `before51`, `before71`, and `before84` unchanged
- [x] 1.2 Add the declined and closed-input notice wording alongside `renderCheckpointNotice(...)`, keeping every existing obstacle notice unchanged

## 2. Feature-flow completion boundary

- [x] 2.1 Extend the run-once terminal helper in `packages/asdlc-coordinator/src/orchestrator/run-feature-flow.ts` into an asynchronous completion helper that runs the gate chain and, on a passing chain, the commit boundary
- [x] 2.2 Route all four successful terminal paths through the helper: accepted step `8.4`, declined step `8.4`, no-remaining-required-step, and catalog end
- [x] 2.3 Keep the helper run-once per invocation so an accepted step `8.4` followed by the catalog-end fall-through prompts exactly once
- [x] 2.4 Skip the prompt and emit the existing nothing-to-commit notice when the project worktree is clean
- [x] 2.5 Prompt with `defaultValue: true`, commit on acceptance, and emit the created commit message
- [x] 2.6 Treat a decline and `InteractionClosedError` as no commit with their own notices, without converting either into a stopped or failed outcome
- [x] 2.7 Return the terminal path's outcome and exit code unchanged for every answer and every commit result

## 3. Tests

- [x] 3.1 Add feature-flow tests proving each of the four successful terminal paths reaches the boundary exactly once, including the accepted-`8.4`-then-catalog-end double path
- [x] 3.2 Add tests for accept, decline, and closed input, asserting commit invocation, notice text, and unchanged outcome and exit code
- [x] 3.3 Add tests proving a clean worktree emits the nothing-to-commit notice without prompting
- [x] 3.4 Add tests proving `unavailable`, `notWorktree`, `addFailed`, and `commitFailed` results are notices that preserve the outcome
- [x] 3.5 Add tests proving a failing terminal gate chain returns its failed outcome with no prompt and no commit, and that phase failures, operator stops, refused pending work, and startup errors never reach the boundary
- [x] 3.6 Update existing after-`8.4` checkpoint assertions in `packages/asdlc-coordinator/test/feature-orchestrator.test.ts` and `packages/asdlc-coordinator/test/terminal-gate-chain.test.ts` to the prompted boundary and its label

## 4. New feature refused on uncommitted work

- [x] 4.1 Add a whole-worktree cleanliness probe to `packages/asdlc-coordinator/src/capture/scaffold-feature.ts`, after the existing pending-checkpoint gate and before the feature id and title are collected
- [x] 4.2 Refuse a dirty worktree with the blocking paths, both ways out, and the retry command; refuse an undeterminable worktree with the existing inspection wording
- [x] 4.3 Add scaffold tests for the dirty refusal, the path cap, the clean pass-through, and the unverifiable probe

## 5. Operator guidance

- [x] 5.1 Describe the end-of-feature commit prompt in the technical-planning section of `overmind/README.md`, between terminal validation and the `implementation_plan.md` review checkpoint, naming what a decline leaves behind
- [x] 5.2 Correct the decline wording in `overmind/README.md` and describe the clean-worktree precondition on starting a new feature
- [x] 5.3 Run `npm test`, `npm run verify`, `npm run test --workspace overmind-installer`, and `npm run test --workspace asdlc-coordinator`
