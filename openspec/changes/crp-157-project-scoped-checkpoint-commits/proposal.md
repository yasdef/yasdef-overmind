## Why

Feature-flow checkpoint commits target the ASDLC runtime root (`orchestrator/run-feature-flow.ts` passes `deps.workspaceRoot` to `checkpoint`), a scope inherited from the shell era when the whole ASDLC directory was one git repository. The operator has confirmed the per-project-repo model as the intended end state: each `projects/<project>` is its own git repository (created by `overmind project create`), and the ASDLC runtime root is not a repository. Under that model every checkpoint degrades to a `notWorktree` notice, so feature artifacts are never checkpointed — and even a git-inited runtime root could not capture them, because nested project repositories are git boundaries that `git add -A` at the root does not cross.

## What Changes

- Feature-flow checkpoint commits run against the **project repository root** (`deps.projectRoot`) instead of the runtime root, at the same preserved boundaries (before steps 5.1, 7.1, 8.4; after 8.4 success/clean decline). This is the same repository scope project create, project init, and project reconcile commits already use.
- `RepoGitAdapter` and the typed `CheckpointResult` degradation are unchanged: a non-git project still yields a `notWorktree` notice and the run continues.
- `checkpoint-commits` and `feature-orchestrator` tests assert the project-root scope (and that runtime-root paths are never the checkpoint target).
- No CLI changes, no new flags, no behavior change at the checkpoint boundaries themselves.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `checkpoint-commits`: the checkpoint target moves from the runtime root to the project repository root; the "preserve the shell's runtime-root `git add -A` scope" wording is superseded. The adapter requirement (explicit-root git, typed degradation) is unchanged in behavior; its scenarios are reworded from "runtime root" to the supplied repository root.

## Impact

- `packages/asdlc-coordinator/src/orchestrator/run-feature-flow.ts` — checkpoint call sites receive `deps.projectRoot`.
- `packages/asdlc-coordinator/test/checkpoint-commits.test.ts`, `packages/asdlc-coordinator/test/feature-orchestrator.test.ts` — scope assertions updated.
- No installer, skill, or docs surface changes; generated guidance does not mention checkpoint scope.
