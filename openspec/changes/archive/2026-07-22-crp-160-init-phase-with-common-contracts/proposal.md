## Why

`overmind project init` currently executes only the next pending init step, so a type `A` project returns after step `1.1` and starts common contract definition only when the operator runs the same command again. The generated happy path exposes that internal dispatch detail, and it permits feature scaffolding while step `2` is still pending, which can dirty the project repository before the initialization baseline is finalized.

## What Changes

- Treat steps `1.1` and `2` as separate interactive phases within one project-init flow. After all step `1.1` sessions return, Overmind validates the phase outputs and commits the stack baseline before offering to start step `2`.
- Prompt `Continue with common contract definition? [Y/n]` only when the current invocation has just completed and checkpointed step `1.1`. `y` starts step `2` in the same invocation; `n` exits successfully with initialization explicitly paused and step `2` pending.
- When a later `project init` invocation starts with step `2` already pending, start common contract definition directly. Type `B` and `C` projects continue to skip step `1.1` and start step `2` directly.
- Reword the common-contract session success handoff so `Ctrl-C` returns control to Overmind to finalize initialization, rather than referring to a nonexistent next phase. Coordinator messages report checkpoint results after Git operations succeed.
- On interrupted init re-entry where the current phase outputs already exist but are not committed, stop with manual checkpoint instructions. The operator either commits the listed files manually and reruns `project init`, or rolls back/removes them and reruns `project init`; the coordinator leaves existing uncommitted init artifacts untouched.
- Distinguish initial-baseline ownership from later project-management ownership for `init_progress_definition.yaml` and `common_contract_definition.md`. Before the initial common contract has a committed version, existing uncommitted current-step outputs are a manual init checkpoint stop. After that boundary, uncommitted changes to either shared file belong to `project reconcile`, including a previously declined reconciliation commit.
- Make step `1.1` and step `2` Git operations strictly transaction-scoped: inspect, stage, commit, and verify only the supplied checkpoint paths. Pre-existing or newly observed unrelated paths are left untouched and do not fail either init checkpoint.
- Block `scaffold feature` before prompting for feature input or writing a feature directory whenever project init or reconciliation has a pending checkpoint. Unrelated project-repository changes do not affect this gate. The diagnostic names the actual owner and exact `project init` or `project reconcile` command needed to continue.
- Add yes/no defaults to the interaction contract, and migrate the existing class-membership and reconciliation commit prompts to default-no requests without embedded suffixes.
- Update the init sequence sources, packaged common-contract success message, generated `quickrun.md`, durable documentation, and tests so the first-time happy path contains one `project init` command and explains the optional phase-continuation decision.

## Capabilities

### New Capabilities

- `project-init-phase-flow`: project-init phase checkpointing, the explicit step `1.1` to step `2` continuation decision, direct step-`2` resume behavior, manual interrupted-init checkpoint guidance, shared init/reconciliation transaction ownership, common-contract finalization handoff, pending-boundary feature-scaffold gating, and first-time operator guidance.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated project-init capability; this change records the behavior as a new capability. -->

## Impact

- `packages/asdlc-coordinator/src/cli/run.ts` and focused project-init flow code: step `1.1` checkpoint, continuation prompt, same-invocation step `2` dispatch, paused outcome, and final initialization checkpoint.
- Shared project-init eligibility and checkpoint helpers: one bounded `project_type_code` adapter supplies step `1.1` dispatch and ownership; one lifecycle classifier distinguishes initial-baseline paths, init-only stack paths, and post-init reconciliation-owned shared paths.
- `packages/asdlc-coordinator/src/capture/scaffold-feature.ts`, `ScaffoldFeatureDeps`, `StepExecutorDeps`, `defaultStepExecutorDeps`, the step-`3` write action, CLI adapter wiring, and test doubles: inject `ProjectGitPort` and enforce the owner-aware pending-checkpoint gate before feature input and filesystem writes.
- `packages/asdlc-coordinator/src/git/`: inspect whether a supplied owned-path set has a committed version in `HEAD` and whether it has staged, unstaged, or untracked changes; make `commitOwnedPaths` post-commit verification path-scoped so unrelated paths cannot produce `dirtyAfterCommit`.
- `packages/asdlc-coordinator/src/orchestrator/run-project-reconciliation-flow.ts`, `packages/asdlc-coordinator/src/capture/project-class.ts`, and `packages/asdlc-coordinator/src/interaction/`: resume a declined shared-file checkpoint and render default-no commit prompts once rather than with duplicate suffixes.
- `packages/asdlc-coordinator/test/cli-project-init.test.ts`, reconciliation/scaffold tests, executor tests, and interaction/git test doubles: continue, pause, manual interrupted-init checkpoint stops, ownership classification, checkpoint failure, project-type applicability, dependency wiring, path-scoped readiness, and no-write gating scenarios.
- `packages/installer/_data/skills/overmind-common-contract/` and `overmind/rules/common_contract_definition_rule.md`: the final `Ctrl-C` handoff returns control so Overmind can finalize project initialization.
- `overmind/init_progress_definition_sequence_diagram.md` and both source/runtime copies of `init_progress_definition_TEMPLATE.yaml`: synchronized phase boundary, checkpoint, continuation, and completion conditions.
- `packages/installer/src/init.ts`, installer tests, `overmind/README.md`, and repository quickrun guidance: one-command first-time init path with an explicit optional pause between phases.
