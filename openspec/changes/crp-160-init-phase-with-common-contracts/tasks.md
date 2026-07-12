## 1. Shared Eligibility, Git, And Interaction Contracts

- [x] 1.1 Add one project-init helper that resolves applicable step `1.1` stack classes and derives separate step `1.1`, initial-baseline, and shared project-definition path sets; use the resolved class list everywhere so dispatch and checkpoint ownership cannot branch independently on `project_type_code`.
- [x] 1.2 Extend `ProjectGitPort` and `RepoGitProjectAdapter` with path-scoped inspection that reports whether each supplied path has a committed version in `HEAD` plus staged/unstaged/untracked changes; make `commitOwnedPaths` post-commit status and `dirtyAfterCommit` path-scoped to the supplied set, and add adapter/test-double coverage proving unrelated paths are ignored and never staged.
- [x] 1.3 Extend `ConfirmRequest` and the TTY interaction adapter with `defaultValue?: boolean`; test `[Y/n]`/blank-yes, `[y/N]`/blank-no, and mandatory `[y/n]` behavior with exactly one rendered suffix.
- [x] 1.4 Migrate class-membership and reconciliation commit confirmations to suffix-free messages with `defaultValue: false`, and update their interaction assertions.
- [x] 1.5 Add a focused typed project-init flow module that receives resolved project/runtime paths, `InteractionPort`, `ProjectGitPort`, progress evaluation, validators, and step-execution dependencies; keep `runProjectInit` responsible for CLI parsing, dependency wiring, and outcome rendering.
- [x] 1.6 Define typed flow outcomes for completed initialization, paused after step `1.1`, no pending init work, changed-after-confirmation, and failed startup/phase/checkpoint operations, with deterministic CLI exit-code mapping.

## 2. Phase Checkpoints And Gate-First Re-entry

- [x] 2.1 Implement the normal step `1.1` checkpoint using the shared applicable-class/path result, commit message `Finalize project stack baseline`, and path-scoped inspection/staging/commit/post-commit verification before offering continuation; do not enumerate or reject unrelated project paths.
- [x] 2.2 Implement checkpoint-aware command entry that detects existing uncommitted current-step init artifacts before model dispatch and stops with manual commit-or-rollback guidance while leaving those files untouched.
- [x] 2.3 Preserve startup diagnostics for missing or malformed `init_progress_definition.yaml` without dispatching step `1`, and treat pre-baseline existing uncommitted current-step outputs as manual checkpoint work.
- [x] 2.4 Preserve common-contract TypeScript validation and implement the final `Finalize project initialization baseline` checkpoint so the completed baseline means committed repository state across both init commits; commit only changed initial-baseline paths and verify every required path exists in `HEAD` afterward.
- [x] 2.5 Pin the final no-changes branch as success only when common-contract and metadata validation pass, every required initial-baseline path exists in `HEAD`, and no init checkpoint change remains; render an already-committed message.
- [x] 2.6 Add coordinator tests for shared eligibility (including type `B`/`C` projects that list surface classes), exact step `1.1` commit paths/message, scoped Git inspection/stage/commit failures, unrelated pre-existing and session-time dirty paths, and prevention of step `2` dispatch before a finalized stack checkpoint.
- [x] 2.7 Add re-entry tests proving existing uncommitted step `1.1` and step `2` artifacts stop with manual guidance, invoke no model, and are never committed by presence alone.
- [x] 2.8 Add tests distinguishing the final commit diff from repository baseline state and covering changed-common-contract, post-baseline shared-path ownership, already-committed no-change, and successful final checkpoint with unrelated dirty project paths.

## 3. Explicit Step 2 Continuation

- [x] 3.1 After a successful step `1.1` checkpoint, print `Stack baseline committed.` and call `interaction.confirm` with message exactly `Continue with common contract definition?` and `defaultValue: true`; separately assert the TTY-rendered prompt is `Continue with common contract definition? [Y/n]`.
- [x] 3.2 On yes, run the fresh project-init state resolver; when it selects step `2`, print `Continuing with common contract definition...` and dispatch the existing common-contract action in the same invocation.
- [x] 3.3 On no or `InteractionClosedError`, return a successful paused outcome that states step `2` remains pending and prints the exact `project init --path <project>` resume command.
- [x] 3.4 When the fresh state is already complete, return exit `0` with `Project initialization is already complete; common contract definition was not started.`; when it selects another phase or cannot be evaluated, return exit `1` with `Project initialization state changed after the continuation decision; no phase was started.` and the exact resume command.
- [x] 3.5 When command entry already selects step `2`, dispatch it directly without the continuation prompt; preserve direct step `2` behavior for type `B`/`C` and type `A` projects with a finalized step `1.1` checkpoint.
- [x] 3.6 Extend project-init flow/CLI tests for default yes, explicit yes, explicit no, closed input, same-invocation transition, second-invocation resume, both fresh-state divergence outcomes, and exact interaction request versus terminal-rendered prompt strings.

## 4. Shared-Path Reconciliation Boundary

- [x] 4.1 Add one lifecycle classifier that treats existing pre-baseline current-step outputs as manual init checkpoint work until `common_contract_definition.md` exists in `HEAD` and treats shared-path changes as project-management/reconciliation work afterward; apply it before scaffold diagnostics.
- [x] 4.2 Update `runProjectReconciliationFlow` to inspect a post-baseline dirty shared unit before the global clean-worktree precondition and before the no-pending-work return; validate metadata and the reconciliation contract before offering a commit.
- [x] 4.3 For a valid pending shared unit, call `interaction.confirm` with message `Commit reconciliation results?` and `defaultValue: false`; decline with the existing successful stopped outcome, or commit and continue remaining attach/reconcile work in the same invocation after acceptance.
- [x] 4.4 Preserve the global clean-worktree refusal for changes outside `OWNED_RECONCILIATION_FILES`, and return reconciliation diagnostics without commit when pending shared metadata or contract validation fails.
- [x] 4.5 Add reconciliation and class-membership tests for a declined completed-reconciliation commit, a declined add-class commit, accepted checkpoint followed by remaining reconciliation, repeated decline, invalid shared state, unrelated dirty paths, and no extra model session when only the verified commit is pending.

## 5. Feature Scaffold Dependency Wiring And Gate

- [x] 5.1 Add required `projectGit: ProjectGitPort` dependencies to `ScaffoldFeatureDeps` and `StepExecutorDeps`.
- [x] 5.2 Supply `RepoGitProjectAdapter` from `defaultStepExecutorDeps`, pass `deps.projectGit` through the generic executor's step `3` write action, and thread CLI `projectGit` overrides through direct `scaffold feature`, project-init, and `overmind run` executor construction.
- [x] 5.3 Update every scaffold/executor test fixture and test double for the required Git port, with assertions that both direct CLI and generic step `3` paths use the injected port.
- [x] 5.4 In `scaffoldFeature`, classify project checkpoint ownership after project resolution and before feature input; direct pending init/stack work to `project init` and post-baseline shared-file, attach, or unreconciled work to `project reconcile`.
- [x] 5.5 Add scaffold primitive and CLI tests proving pending step `1.1`, pending step `2`, interrupted stack checkpoints, and declined reconciliation/add-class commits request no input and create no directory with the correct owner command, while unrelated dirty feature paths do not block a new scaffold.

## 6. Common-Contract Handoff And Init Sources

- [x] 6.1 Update only the packaged `overmind-common-contract` final response and `overmind/rules/common_contract_definition_rule.md` to ask the operator to press `Ctrl-C` so Overmind can finalize project initialization; leave stack-blueprint and agents-md completion strings unchanged.
- [x] 6.2 Update `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` together with the finalized step `1.1` boundary, `[Y/n]` continuation branch, manual interrupted-init checkpoint guidance, paused/resumed step `2` path, and lifecycle-scoped final repository-baseline condition.
- [x] 6.3 Mirror the updated init progress template into `packages/installer/_data/templates/init_progress_definition_TEMPLATE.yaml` and extend installer parity tests for the synchronized source/runtime definition.

## 7. Operator Guidance And Installed Runtime

- [x] 7.1 Update generated `quickrun.md` in `packages/installer/src/init.ts` so `## First-Time Happy Path` lists `project init` once, removes the repeat instruction, and explains yes-continuation and no-then-resume behavior.
- [x] 7.2 Update `QUICKRUN.md`, root `README.md`, and `overmind/README.md` with the same phase-boundary semantics, rendered continuation prompt, pause outcome, owner-aware scaffold diagnostics, and reconciliation checkpoint resume.
- [x] 7.3 Extend installer tests to assert the revised common-contract completion message, unchanged stack-blueprint/agents-md messages, one-command first-time happy path, continuation guidance, runtime-template parity, and absence of the old repeat/next-phase wording.

## 8. Verification

- [x] 8.1 Run `npm run test --workspace asdlc-coordinator` and `npm run test --workspace overmind-installer`.
- [x] 8.2 Run `npm test`, `npm run verify`, `npm run format:check`, and `git diff --check` from the repository root.
- [x] 8.3 Run strict OpenSpec validation for `crp-160-init-phase-with-common-contracts` and inspect the generated first-time `quickrun.md` from a temporary installed workspace.
