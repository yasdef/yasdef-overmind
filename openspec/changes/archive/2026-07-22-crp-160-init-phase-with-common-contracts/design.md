## Context

`runProjectInit` currently evaluates progress once, executes exactly one selected init step, and returns. For a type `A` project this means one invocation runs step `1.1`, leaves its generated stack-blueprint and agent-guidelines artifacts uncommitted, and a second invocation starts step `2`. The generated quickrun documents the repeated invocation rather than presenting common contract definition as part of first-time initialization.

The phase sessions are interactive Codex processes. A model runs its gate, prints its phase-completion message, and remains active until the operator presses `Ctrl-C`. Only then does control return to the TypeScript coordinator. Therefore the coordinator can validate and commit a phase checkpoint only after `Ctrl-C`; model success text cannot claim that a commit has already happened.

The coordinator already has the required seams: `ProgressReport` and `nextStep` for canonical progress, the generic executor for steps `1.1` and `2`, `InteractionPort` for operator decisions, and `ProjectGitPort` for explicit-root inspection and owned-path commits. `scaffoldFeature` currently checks project metadata but does not check project-init progress before collecting feature input and creating a directory.

## Goals / Non-Goals

**Goals:**

- Keep steps `1.1` and `2` as distinct interactive phases with a `Ctrl-C` return boundary.
- Commit and verify the step `1.1` stack baseline before the coordinator offers to start step `2`.
- Let the operator continue into step `2` in the same invocation or pause cleanly and resume step `2` with a later invocation.
- Validate and checkpoint only the paths owned by the current init or reconciliation transaction, without confusing later shared-file edits with incomplete initialization or using global worktree cleanliness as initialization state.
- Stop clearly on interrupted outputs that already exist but are not committed, leaving the operator to manually commit correct files or roll back incorrect files before rerunning.
- Keep the first-time happy path to one documented `project init` command while accurately explaining the optional pause.

**Non-Goals:**

- Removing the interactive model process or its `Ctrl-C` return behavior.
- Merging step `1.1` and step `2` into one model session.
- Persisting the operator's `y`/`n` answer or adding a new workflow marker artifact.
- Starting feature scaffolding automatically after project initialization.
- Changing feature-flow checkpoint boundaries or adding CLI flags.

## Decisions

### 1. A typed project-init flow owns one optional phase transition

Move phase policy out of the argument-parsing portion of `runProjectInit` into a focused, testable project-init flow. The CLI resolves the workspace/project, interaction, executor, and Git dependencies; the flow resolves the pending phase and checkpoint owner at invocation start and dispatches through the existing generic executor when model work is required.

When the invocation starts at step `1.1`, the flow runs every applicable per-class action, establishes the step `1.1` checkpoint, and asks whether to continue. A negative answer returns a typed `paused` outcome. A positive answer runs the state resolver again. When that fresh state selects step `2`, the flow prints `Continuing with common contract definition...` and dispatches it. When initialization is already complete, the flow returns success and prints `Project initialization is already complete; common contract definition was not started.` When the state regresses to another pending phase or cannot be evaluated, the flow returns exit code `1`, prints `Project initialization state changed after the continuation decision; no phase was started.`, and prints the exact `project init` resume command. No non-step-`2` branch silently returns or dispatches stale work.

When the invocation starts at step `2`, the explicit command invocation is sufficient intent and step `2` starts directly without the transition prompt.

This is a bounded transition rather than a generic loop: one invocation may cross only the agreed step `1.1` to step `2` boundary. The alternative, repeatedly executing every pending init step, would hide future phase boundaries and remove the operator decision that motivated this change.

### 2. One helper resolves step 1.1 eligibility and checkpoint paths

Add one project-init metadata helper that returns the applicable stack classes. While `project_type_code` remains in the data model, that helper returns active `backend`/`frontend`/`mobile` classes only for type `A`; it returns an empty list for types `B` and `C`. Step `1.1` dispatch, step `1.1` checkpoint ownership, the initial baseline, and scaffold checkpoint classification all consume this one result.

This keeps the legacy type-code dependency behind one adapter instead of repeating the current split where dispatch sees all surface classes but commit ownership checks type `A` separately. When per-repository classification replaces `project_type_code`, only the helper's eligibility implementation changes; the phase flow and Git APIs remain class-list based.

The helper exposes separate sets rather than one permanently init-owned set:

- The step `1.1` checkpoint contains the applicable class's `project_stack_blueprint_<class>.md` and `project_agents_md_claude_md_<class>.md` paths.
- The initial baseline contains `init_progress_definition.yaml`, `common_contract_definition.md`, and the applicable step `1.1` paths.
- The shared project-definition set contains `init_progress_definition.yaml` and `common_contract_definition.md`, matching `OWNED_RECONCILIATION_FILES`.

These names describe transaction ownership. They do not imply that shared files remain owned by initialization forever.

### 3. Shared-path ownership changes after the initial baseline

Extend `ProjectGitPort` with a path-scoped inspection operation that reports, for each supplied path, whether a committed version exists in `HEAD` and whether the worktree/index contains a staged, unstaged, or untracked change. Unrelated project paths are excluded from that result. Align `commitOwnedPaths` with its name: after staging and committing only the supplied paths, it verifies only those paths with a pathspec-scoped status operation. `dirtyAfterCommit` can report only supplied paths that remain dirty; unrelated paths neither change the result nor get staged.

The committed initial common contract is the lifecycle boundary for the two shared files. Before `common_contract_definition.md` has a committed version in `HEAD`, existing uncommitted current-step outputs are an interrupted-init checkpoint. `project init` reports the exact files, tells the operator to commit them manually when correct, or roll them back/remove them when incorrect, and prints the same `project init --path <project>` command to rerun. The coordinator leaves those files untouched on re-entry. Missing or malformed metadata still produces the existing startup diagnostic before any phase work.

After a committed common contract exists in `HEAD`, staged or unstaged changes to either shared path are project-management/reconciliation work, regardless of whether they came from class membership, successful contract reconciliation, or a hand edit. They never make the historical initialization baseline incomplete and never cause `project init` to redispatch the common-contract session. This lifecycle rule is deterministic without a new marker file.

`runProjectReconciliationFlow` checks for a pending shared-file checkpoint before its ordinary clean-worktree precondition and before its no-pending-work return. When only reconciliation-owned shared paths are dirty, it validates the metadata and reconciliation contract, then calls `interaction.confirm({ message: "Commit reconciliation results?", defaultValue: false })`. Declining leaves the files unchanged and returns the existing successful stopped outcome. Accepting commits the shared transaction and then continues any remaining attachment/reconciliation work in the same invocation. Invalid shared state is not committed and produces reconciliation diagnostics. Dirty paths outside the shared set retain the existing clean-baseline refusal.

This handles both supported decline paths: an uncommitted class-membership change can be checkpointed before reconciliation continues, and a completed reconciliation whose commit was declined can be committed on the next `project reconcile` invocation even though its `contract_reconciled` flags already say no model work remains.

### 4. Init re-entry stops for manual checkpoint resolution

After all step `1.1` sessions return successfully, the flow validates and commits exactly the step `1.1` checkpoint paths with `Finalize project stack baseline`. The continuation prompt is rendered only after path-scoped inspection reports every step `1.1` path committed and clean. The flow does not enumerate, stage, or reject paths outside that checkpoint.

Step `2` retains `Finalize project initialization baseline` as the final checkpoint. Its owned-path argument may list the complete initial baseline, but the Git commit contains only initial-baseline paths that changed since the step `1.1` commit, normally `common_contract_definition.md`. Its post-commit verification is restricted to those initial-baseline paths. The phrase "initialization baseline" means the repository state after the checkpoint: all required baseline artifacts have committed versions across the step `1.1` and step `2` commits. It does not mean every baseline path appears in the final commit diff or that the whole project worktree is clean.

The existing no-changes branch remains a success path only after common-contract and metadata validation prove that every initial-baseline artifact has a committed version in `HEAD` and no initial-baseline checkpoint change remains. It reports that the initialization baseline is already committed. A missing committed baseline path before the lifecycle boundary is an unfinalized init checkpoint, not a no-op success.

At command entry, artifact progress can point past an interrupted init phase whose output is present but not checkpointed. When `common_contract_definition.md` has no committed version in `HEAD` and the current-step outputs already exist with pending checkpoint state, `project init` stops before model dispatch and before any commit. It lists the pending files and instructs the operator to commit them manually if correct, then rerun `project init`, or roll them back/remove them if incorrect, then rerun `project init`. Artifact presence alone never authorizes a coordinator commit.

This keeps re-entry deterministic without adding a second validation/repair path. The model owns artifact generation in the normal phase run. The operator owns deciding whether interrupted files are correct enough to commit.

The current project-root-wide containment and post-commit cleanliness checks are part of the observed defect: they discover unrelated paths only after interactive model work and make those paths block a transaction that does not own them. Path-scoped checkpoints commit the stack outputs before step `2` while leaving unrelated work untouched.

### 5. Confirmation defaults are explicit and suffixes are rendered once

Extend `ConfirmRequest` with `defaultValue?: boolean`. The TTY adapter renders `[Y/n]` for `true`, `[y/N]` for `false`, and `[y/n]` when no default is supplied. A blank answer selects an explicit default and remains invalid when no default exists.

The project-init flow calls `interaction.confirm({ message: "Continue with common contract definition?", defaultValue: true })`. Migrate the existing class-membership and reconciliation commit requests to messages `Commit class membership change?` and `Commit reconciliation results?` with `defaultValue: false`; the adapter renders their existing intended `[y/N]` suffix once. Other requests without a default retain mandatory `[y/n]` behavior.

`yes` prints `Continuing with common contract definition...` and dispatches step `2`. `no` returns success with a message that initialization is paused after step `1.1`, common contract definition remains pending, and the exact resume command. A closed input stream at this boundary is treated as the same clean pause; it never starts step `2` implicitly.

### 6. Feature scaffolding receives Git explicitly and reports the actual owner

Add `projectGit: ProjectGitPort` to `ScaffoldFeatureDeps` and `StepExecutorDeps`. The default executor dependencies supply `RepoGitProjectAdapter`; CLI adapter overrides flow into direct `scaffold feature`, `project init`, and the executor dependencies used by `overmind run`. The step `3` write action passes `deps.projectGit` into `scaffoldFeature`. Unit tests use explicit test doubles for the new port.

Place the pending-boundary check in `scaffoldFeature`, after resolving the project but before requesting feature ID/title or creating a directory. This protects both the direct CLI and generic executor entry paths. The classifier uses canonical progress, committed-baseline evidence, applicable stack paths, reconciliation metadata, and the path-scoped Git result in this order:

1. Post-baseline changes to `OWNED_RECONCILIATION_FILES` are a reconciliation checkpoint and point to `project reconcile`, even when all `contract_reconciled` flags are already true.
2. A pending init step, a missing initial committed baseline, or an interrupted stack checkpoint is an init boundary and points to `project init`.
3. Existing deferred/unreconciled class metadata remains an attach/reconcile boundary and points to `project reconcile`.

Dirty paths outside those transaction sets do not affect scaffold readiness, so a later feature can be scaffolded while unrelated existing feature work is dirty.

The refusal diagnostic names the pending boundary and exact owner command. No interaction request and no filesystem write occurs. A project with no pending init or reconciliation checkpoint preserves existing scaffold behavior.

The alternative of documenting command order only cannot prevent the observed dirty feature directory when an operator assumes the first successful `project init` return means initialization is complete.

### 7. Only the misleading common-contract handoff changes

Keep the existing stack-blueprint and agents-md completion strings; both already say the class session is finished and that the orchestrator can continue project init. Change only the common-contract success string from `press Ctrl-C so orchestrator can start the next phase` to `press Ctrl-C so Overmind can finalize project initialization`. After validation and checkpoint handling, coordinator output reports whether the baseline was committed, was already committed, or failed.

The source common-contract rule and packaged skill text remain synchronized where the repository asserts exact completion wording. This limits message churn to the string that currently implies another model phase after the last init phase.

### 8. Source and installed-runtime guidance move together

Update `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` together, then mirror the runtime template into `packages/installer/_data/templates/`. Update the packaged common-contract skill under `packages/installer/_data/skills/`, generated quickrun text in `packages/installer/src/init.ts`, `QUICKRUN.md`, root `README.md`, and `overmind/README.md`. Installer tests assert the common-contract wording, unchanged class-session wording, runtime-template parity, and a first-time happy path containing one `project init` invocation with the continuation decision described in prose.

## Risks / Trade-offs

- [The operator interrupts after a model writes an artifact but before its checkpoint] -> Re-entry stops with the pending filenames and manual commit/rollback instructions; the coordinator leaves existing interrupted outputs untouched.
- [A step `1.1` checkpoint fails after lengthy interactive work] -> The flow reports the Git failure and does not prompt for or dispatch step `2`; generated artifacts remain available for repair and re-entry.
- [A shared file is modified after initialization] -> A committed common contract establishes post-init ownership; the change is routed to `project reconcile` and cannot reopen project init.
- [A declined reconciliation commit leaves flags already true] -> Reconciliation checks its dirty owned unit before the no-pending return, so the next invocation can validate and commit it without another model session.
- [Default support changes existing prompts] -> Only the two existing default-no commit prompts are migrated; requests without a default retain mandatory `[y/n]` behavior.
- [Progress says step `2` is pending while Git says step `1.1` is dirty] -> Init-only checkpoint state takes precedence, but valid artifacts are checkpointed without redispatch.
- [A model session or operator leaves an unrelated path dirty] -> Init checkpoints neither stage nor reject it; generic-executor required-output and declared read-only guards continue to enforce the phase's explicit artifact contracts.
- [Scaffold gating duplicates the feature orchestrator's pending-work check] -> The primitive-level check is intentional defense at the write boundary; the orchestrator check remains useful earlier guidance.
- [Source and installed skill/template text drift] -> Installer parity and exact-message tests cover the packaged runtime payload in addition to coordinator tests.

## Migration Plan

1. Add the shared eligibility/path helpers, `HEAD`-aware path-scoped Git inspection, typed project-init flow outcomes, and explicit confirmation defaults.
2. Add the step `1.1` checkpoint, interrupted-init manual checkpoint stop, explicit continuation/pause transition, and final initial-baseline checkpoint.
3. Add the shared-path ownership classifier and reconciliation checkpoint resume before the existing clean-baseline/no-pending decisions.
4. Thread `ProjectGitPort` through scaffold/executor dependencies and enforce owner-aware feature-scaffold gating.
5. Update the common-contract completion message, init sequence sources, runtime payload mirrors, quickrun, and durable docs.
6. Run coordinator, installer, full verification, formatting, and strict OpenSpec validation.

No persisted data migration is required. Existing projects are evaluated from their artifacts and project-repository checkpoint state. Rollback restores one-step-per-invocation dispatch and the prior guidance; project artifacts and commits remain valid.

## Open Questions

None.
