## Why

Planning work reaches the operator as files in the project worktree, and the run commits them only at four fixed boundaries: before step `5.1`, before step `7.1`, before step `8.4`, and after step `8.4`. Only the last of those is a completion boundary, and it is reached solely when the catalog loop actually executes step `8.4`. A run that ends because feature scanning reports no remaining required step — the ordinary shape of a resumed run whose optional review was already decided — finishes successfully and commits nothing, leaving `implementation_slices.md`, `prerequisite_gaps.md`, `implementation_plan.md`, and `implementation_plan_semantic_review.md` uncommitted with no operator-visible notice that they are. The commit that does happen is silent and unconditional, so the operator neither authorizes it nor learns it occurred at the one moment the feature is finished and its plan leaves Overmind.

## What Changes

- Add one feature-completion commit boundary reached from every successful terminal path: an accepted step `8.4`, a declined step `8.4`, a scanner-reports-nothing-remaining ending, and the end of the catalog loop.
- Prompt the operator to commit at that boundary and commit only on acceptance, replacing the silent after-`8.4` checkpoint.
- Emit the boundary result on every path: committed, declined and left uncommitted, nothing to commit, or a commit obstacle.
- Keep the boundary behind the CRP-166 terminal gate chain, and leave failed, refused, and operator-stopped runs uncommitted as they are today.
- Preserve the outcome and exit code of the run regardless of the operator's answer or the commit result.
- Keep the three pre-step checkpoints before `5.1`, `7.1`, and `8.4` unchanged.
- Refuse to scaffold a new feature while the project worktree has uncommitted changes, so declined work is never swept into the next feature's commits.

## Capabilities

### New Capabilities

- `feature-completion-commit-prompt`: the single end-of-feature commit boundary, its terminal-path coverage, its operator prompt, and its non-blocking result reporting.

## Impact

- `packages/asdlc-coordinator/src/orchestrator/run-feature-flow.ts`: route all successful terminal paths through one completion helper that runs the gate chain, then the commit boundary, then the terminal message.
- `packages/asdlc-coordinator/src/git/index.ts`: replace the `after84` checkpoint label with a feature-completion label and render the declined and closed-input notices.
- `packages/asdlc-coordinator/src/capture/scaffold-feature.ts`: extend the existing pre-scaffold gate with a whole-worktree cleanliness check that refuses a new feature before prompting for its id and title.
- `packages/asdlc-coordinator/test/feature-orchestrator.test.ts` and terminal-chain tests: cover each terminal path, both operator answers, closed input, a clean worktree, and commit obstacles.
- `overmind/README.md`: describe the end-of-feature commit prompt in the technical-planning phase section alongside terminal validation.
- No artifact schema, skill payload, validator rule, CLI flag, or new runtime asset changes.
