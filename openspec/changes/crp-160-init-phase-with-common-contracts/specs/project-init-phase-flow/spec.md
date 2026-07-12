## ADDED Requirements

### Requirement: One eligibility result controls step 1.1 dispatch and ownership

The system SHALL resolve applicable step `1.1` stack classes once and SHALL use that same class list for model-session dispatch, step `1.1` checkpoint paths, initial-baseline paths, and feature-scaffold checkpoint classification. Under the current metadata schema, the resolver SHALL return active `backend`, `frontend`, and `mobile` classes only when `project_type_code` is `A`; it SHALL return an empty list for project types `B` and `C`. New phase-flow and Git APIs SHALL consume the resolved class list without independently branching on `project_type_code`.

#### Scenario: Type A has applicable stack classes

- **WHEN** project metadata has `project_type_code: A` and active backend and frontend classes
- **THEN** the same backend/frontend class list controls step `1.1` dispatch and every initial-baseline path calculation

#### Scenario: Type B or C contains surface classes

- **WHEN** project metadata has project type `B` or `C` and lists backend, frontend, or mobile classes
- **THEN** step `1.1` dispatch and step `1.1` checkpoint ownership both receive an empty applicable stack-class list

### Requirement: Step 1.1 completes at a committed phase boundary

For a type `A` project with step `1.1` pending, `overmind project init` SHALL run every applicable stack-blueprint and agent-guidelines class session through the generic executor. After those sessions return successfully, the system SHALL verify the declared outputs and commit the applicable step `1.1` paths in the project repository before offering to start step `2`. Inspection, staging, commit, and post-commit verification SHALL be restricted to the supplied step `1.1` paths. The continuation decision SHALL NOT be offered and step `2` SHALL NOT start when that scoped checkpoint fails. Paths outside the supplied checkpoint SHALL be left untouched and SHALL NOT make the checkpoint fail.

#### Scenario: Step 1.1 reaches the continuation boundary

- **WHEN** every applicable step `1.1` class session completes successfully and the supplied step `1.1` paths pass their checkpoint
- **THEN** the system commits the stack baseline, reports `Stack baseline committed.`, and offers the step `2` continuation decision

#### Scenario: Step 1.1 checkpoint fails

- **WHEN** inspection, validation, staging, commit, or post-commit verification fails for a supplied step `1.1` path
- **THEN** the command exits with a diagnostic and does not offer the continuation decision or dispatch step `2`

#### Scenario: Unrelated path is dirty during step 1.1

- **WHEN** every supplied step `1.1` path passes its checkpoint and a path outside that set is dirty
- **THEN** the unrelated path is not staged or committed, the step `1.1` checkpoint succeeds, and the continuation decision is offered

### Requirement: Operator controls the step 1.1 to step 2 transition

After checkpointing step `1.1` in the current invocation, the project-init flow SHALL call `InteractionPort.confirm` with message exactly `Continue with common contract definition?` and `defaultValue: true`. The TTY adapter SHALL render `Continue with common contract definition? [Y/n]`. A yes answer SHALL run the project-init state resolver again and SHALL start step `2` only when the fresh state selects step `2`. A no answer or closed input stream SHALL return a successful paused outcome with step `2` pending and the exact command needed to resume.

#### Scenario: Operator continues in the same invocation

- **WHEN** the operator answers yes or submits an empty answer after the step `1.1` checkpoint
- **THEN** the system reports `Continuing with common contract definition...` and starts the step `2` common-contract session

#### Scenario: Operator pauses after step 1.1

- **WHEN** the operator answers no at the continuation decision
- **THEN** the command exits successfully, reports that initialization is paused after step `1.1`, leaves step `2` pending, and prints the exact `project init` resume command

#### Scenario: Continuation input closes

- **WHEN** the operator input stream closes at the continuation decision
- **THEN** the command returns the same clean paused outcome and does not start step `2`

#### Scenario: Fresh state is already complete

- **WHEN** the operator answers yes and the fresh state has no pending init phase or checkpoint
- **THEN** the command returns exit code `0`, reports `Project initialization is already complete; common contract definition was not started.`, and does not dispatch step `2`

#### Scenario: Fresh state selects a different phase

- **WHEN** the operator answers yes and the fresh state selects a pending phase other than step `2` or cannot be evaluated
- **THEN** the command returns exit code `1`, reports `Project initialization state changed after the continuation decision; no phase was started.`, prints the exact `project init` resume command, and does not dispatch step `2`

### Requirement: Confirmation defaults render one canonical suffix

`ConfirmRequest` SHALL support `defaultValue?: boolean`. The TTY adapter SHALL render `[Y/n]` and accept a blank answer as yes for `true`, SHALL render `[y/N]` and accept a blank answer as no for `false`, and SHALL render `[y/n]` and require an explicit yes or no answer when the field is absent. Callers SHALL pass messages without an embedded answer suffix. The class-membership commit request SHALL use message `Commit class membership change?` with `defaultValue: false`; the reconciliation commit request SHALL use message `Commit reconciliation results?` with `defaultValue: false`.

#### Scenario: Confirmation defaults to no

- **WHEN** class membership or reconciliation requests commit confirmation
- **THEN** the TTY displays the applicable message with one `[y/N]` suffix and a blank answer declines the commit

#### Scenario: Confirmation has no default

- **WHEN** another caller submits a confirmation request without `defaultValue`
- **THEN** the TTY adapter renders one `[y/n]` suffix and requires an explicit yes or no answer

### Requirement: Pending step 2 starts directly on command entry

When a `project init` invocation begins with step `2` as the next safe pending init phase, the system SHALL start common contract definition directly without asking the step `1.1` continuation question. Type `B` and `C` projects and type `A` projects for which step `1.1` is already finalized SHALL follow this behavior.

#### Scenario: Type A resumes after declining continuation

- **WHEN** the operator previously paused after the finalized step `1.1` checkpoint and runs `project init` again
- **THEN** the system starts step `2` directly without repeating step `1.1` or asking the continuation question

#### Scenario: Type B or C starts project init

- **WHEN** a type `B` or `C` project has step `2` pending
- **THEN** the system skips step `1.1` and starts common contract definition directly

### Requirement: Shared project-definition paths have lifecycle-scoped ownership

The system SHALL define the initial-baseline paths as `init_progress_definition.yaml`, `common_contract_definition.md`, and each applicable class's step `1.1` stack and agent-guidelines artifacts. It SHALL separately define the shared project-definition paths as `init_progress_definition.yaml` and `common_contract_definition.md`, matching `OWNED_RECONCILIATION_FILES`. Git checkpoint inspection SHALL report whether each supplied path has a committed version in `HEAD` and whether it has staged, unstaged, or untracked changes. `commitOwnedPaths` SHALL stage, commit, and verify only its supplied paths; `dirtyAfterCommit` SHALL contain only supplied paths that remain dirty.

Before `common_contract_definition.md` has a committed version in `HEAD`, existing uncommitted current-step outputs SHALL be treated as an interrupted init checkpoint requiring manual operator resolution. `project init` SHALL list the pending files and instruct the operator to commit them manually when correct or roll them back/remove them when incorrect, then rerun `project init`. After a committed common contract exists in `HEAD`, new changes to either shared path SHALL belong to project reconciliation and SHALL NOT make initialization incomplete or cause `project init` to redispatch a common-contract session. Changes outside the supplied transaction paths SHALL NOT change checkpoint ownership.

#### Scenario: Common contract exists without its initial checkpoint

- **WHEN** the initial common contract is not committed and `common_contract_definition.md` exists with pending checkpoint state
- **THEN** `project init` stops before model dispatch or commit, lists the pending initialization files, and prints manual commit-or-rollback guidance with the `project init` rerun command

#### Scenario: YAML metadata cannot be repaired automatically

- **WHEN** `init_progress_definition.yaml` is missing or fails metadata parsing
- **THEN** `project init` returns the metadata startup diagnostic and does not enter an undispatchable step `1` branch

#### Scenario: Reconciliation changes shared paths after initialization

- **WHEN** a committed common contract exists and reconciliation leaves either shared path modified after the operator declines its commit
- **THEN** initialization remains complete and the pending checkpoint owner is `project reconcile`

#### Scenario: Post-init hand edit changes a shared path

- **WHEN** a committed common contract exists and an operator stages or modifies either shared path outside a running command
- **THEN** the pending boundary is classified as project reconciliation rather than project initialization

### Requirement: Init re-entry requires manual resolution for existing uncommitted outputs

When artifact progress points past an interrupted init checkpoint and the current phase outputs already exist but are not committed, `project init` SHALL leave those existing files untouched. It SHALL stop with a manual checkpoint-required outcome that lists the pending files. The operator guidance SHALL say that correct files should be committed manually before rerunning `project init`, and incorrect files should be rolled back or removed before rerunning `project init`.

#### Scenario: Existing step 1.1 artifacts await manual checkpoint

- **WHEN** every applicable stack and agent-guidelines artifact exists, their checkpoint is pending, and the initial common contract has no committed version
- **THEN** `project init` stops before model dispatch or commit and lists the pending step `1.1` artifact paths

#### Scenario: Incorrect existing init artifact

- **WHEN** an operator determines that an existing uncommitted init artifact is incorrect
- **THEN** the documented action is to roll back or remove the file and rerun `project init`

#### Scenario: Correct existing init artifact

- **WHEN** an operator determines that an existing uncommitted init artifact is correct
- **THEN** the documented action is to commit the listed files manually and rerun `project init`

#### Scenario: Post-baseline shared edit

- **WHEN** `common_contract_definition.md` has a committed version in `HEAD` and a shared project-definition path is dirty
- **THEN** `project init` does not report an init manual checkpoint and allows project reconciliation to own the pending shared change

### Requirement: Reconciliation resumes its declined shared-file checkpoint

When a committed initial common contract exists and only shared project-definition paths are dirty, `project reconcile` SHALL inspect and validate that shared transaction before its normal clean-worktree precondition and before returning no pending work. A valid pending transaction SHALL request confirmation with message `Commit reconciliation results?` and `defaultValue: false`. A declined confirmation SHALL leave the files uncommitted and return the existing successful stopped outcome. An accepted confirmation SHALL commit the shared paths and continue any remaining attachment or reconciliation work in the same invocation. Invalid shared state SHALL produce reconciliation diagnostics and SHALL NOT be committed. Dirty paths outside the shared set SHALL retain the normal clean-worktree refusal.

#### Scenario: Completed reconciliation commit was declined

- **WHEN** reconciliation previously updated the common contract and set every covered `contract_reconciled` flag but the operator declined the commit
- **THEN** the next `project reconcile` invocation validates and offers that shared transaction for commit even though no class remains unreconciled

#### Scenario: Class-membership commit was declined

- **WHEN** class membership changed `init_progress_definition.yaml` after initialization and the operator declined its commit
- **THEN** `project reconcile` offers the pending shared transaction for commit and, after acceptance, continues the remaining class binding or reconciliation flow

### Requirement: Project initialization completes at the final repository baseline

After the common-contract session returns, the system SHALL validate the initial-baseline artifacts, commit changed initial-baseline paths, and report initialization complete only when every required baseline artifact has a committed version in `HEAD` and no initial-baseline transaction change remains. The completed repository baseline SHALL include committed versions of `init_progress_definition.yaml`, `common_contract_definition.md`, and every applicable type `A` stack-blueprint and agent-guidelines artifact across the step `1.1` and step `2` commits. The final commit SHALL contain only initial-baseline paths that changed after the step `1.1` checkpoint.

#### Scenario: Step 2 completes successfully

- **WHEN** the common-contract session returns with a gate-passing artifact, the final commit succeeds, and all initial-baseline paths have committed versions with no pending initial-baseline change
- **THEN** the system reports the initialization baseline committed and project initialization complete

#### Scenario: Step 1.1 paths are already committed

- **WHEN** step `2` changes only `common_contract_definition.md`
- **THEN** the final commit contains the changed common-contract path while the completed repository baseline also includes the earlier committed step `1.1` artifacts

#### Scenario: Final checkpoint has no changes

- **WHEN** common-contract and metadata validation pass, every required initial-baseline path already has a committed version, and no initial-baseline change is pending
- **THEN** the no-changes branch succeeds and reports that the initialization baseline is already committed

#### Scenario: Final validation or checkpoint fails

- **WHEN** common-contract or metadata validation fails, an initial-baseline commit fails, or a required initial-baseline path has no committed version
- **THEN** the command exits with a diagnostic and does not report project initialization complete

#### Scenario: Unrelated path is dirty during the final checkpoint

- **WHEN** every supplied initial-baseline path passes validation and its scoped checkpoint while a path outside the initial baseline is dirty
- **THEN** the unrelated path is not staged or committed and project initialization completes successfully

### Requirement: Common-contract success hands control back for finalization

The packaged common-contract skill and its source rule SHALL end a successful session with wording that asks the operator to press `Ctrl-C` so Overmind can finalize project initialization. Stack-blueprint and agent-guidelines completion strings SHALL remain unchanged.

#### Scenario: Common-contract model gate passes

- **WHEN** the common-contract session passes its model-owned gate
- **THEN** its final response asks the operator to press `Ctrl-C` so Overmind can finalize project initialization and does not refer to starting a next phase

### Requirement: Feature scaffolding requires no pending project checkpoint

Every `scaffoldFeature` entry path SHALL receive a `ProjectGitPort` and SHALL classify pending project work before requesting feature input or writing a feature directory. `ProjectGitPort` SHALL be threaded through `ScaffoldFeatureDeps`, `StepExecutorDeps`, default executor dependencies, direct CLI wiring, the step `3` write action, and test doubles. The classifier SHALL combine canonical project-init progress, committed-baseline evidence, applicable step `1.1` paths, reconciliation metadata, and path-scoped Git state. It SHALL report post-baseline shared-file changes as a reconciliation checkpoint before considering pre-baseline manual init checkpoint state. The refusal diagnostic SHALL name the actual pending boundary and exact `project init` or `project reconcile` command. Unrelated dirty project paths SHALL NOT block feature scaffolding.

#### Scenario: Feature scaffold is requested while step 2 is pending

- **WHEN** the operator paused after step `1.1` and invokes `scaffold feature`
- **THEN** the system refuses before requesting feature ID or title, creates no feature directory, and directs the operator to run `project init`

#### Scenario: Feature scaffold is requested with an interrupted init-only checkpoint

- **WHEN** artifact progress has moved past step `1.1` but an applicable stack or agent-guidelines path has no finalized checkpoint
- **THEN** the system refuses before interaction or filesystem writes and directs the operator to run `project init`

#### Scenario: Feature scaffold is requested after a declined reconciliation commit

- **WHEN** the initial common contract is committed and a shared project-definition path contains a pending reconciliation change
- **THEN** the system refuses before interaction or filesystem writes and directs the operator to run `project reconcile`

#### Scenario: Unrelated feature work is dirty

- **WHEN** no project-init or reconciliation checkpoint remains pending and an unrelated feature path is dirty
- **THEN** the system collects feature input and creates the feature scaffold using the existing behavior

### Requirement: First-time guidance presents one coherent initialization command

Generated and repository quickrun guidance SHALL list `project init` once in the first-time happy path, describe that type `A` step `1.1` can continue into common contract definition after the rendered `[Y/n]` decision, and state that a declined continuation resumes at step `2` on the next `project init` invocation.

#### Scenario: Fresh workspace quickrun is generated

- **WHEN** the installer generates `quickrun.md`
- **THEN** the first-time happy path contains one `project init` command followed by feature scaffolding and contains no instruction to repeat `project init` until common contract definition completes
