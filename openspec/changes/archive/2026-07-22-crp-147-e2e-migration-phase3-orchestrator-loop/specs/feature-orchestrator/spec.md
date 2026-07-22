## ADDED Requirements

### Requirement: `overmind run` resolves the feature workflow context

The system SHALL provide `overmind run [--path <project>] [--resume <step>]` as the feature-flow entrypoint. It SHALL resolve and validate the staged workspace and selected project through `workspace/`; with no path, zero projects SHALL fail, one project SHALL auto-select with a notice, and multiple projects SHALL use `InteractionPort` with a clean operator-finish path.

#### Scenario: One project is selected automatically
- **WHEN** `overmind run` starts in a valid workspace containing exactly one project
- **THEN** it selects that project, prints the selection notice, and continues without a project menu

#### Scenario: Operator finishes from project selection
- **WHEN** multiple projects exist and the operator chooses the finish option
- **THEN** the run stops before feature work and the CLI exits zero

#### Scenario: Explicit project path is invalid
- **WHEN** `--path` resolves outside the workspace or lacks `init_progress_definition.yaml`
- **THEN** the CLI renders an actionable diagnostic and exits non-zero without starting feature work

### Requirement: Project-level pending work refuses feature execution

Before feature selection, the system SHALL inspect project-scope initialization and each class repo's attach/reconciliation state. Pending initialization, a non-ready class repo, or a ready but unreconciled class SHALL refuse feature execution with actionable guidance naming the relevant surviving staged legacy script until Slice 4 replaces that guidance with `overmind project reconcile`. The feature flow SHALL detect this work only; it SHALL NOT execute attach, reconciliation, or reconciliation commits.

During the Slice 3-to-4 transition, a ready class SHALL count as reconciled if `class_repo_paths.<class>.contract_reconciled` is true or the corresponding legacy `.contract_reconciled_<class>` marker exists. TypeScript code SHALL NOT create legacy markers.

#### Scenario: Project initialization is pending
- **WHEN** the next project-scope step is incomplete
- **THEN** the run exits non-zero before feature selection with step-specific initialization guidance

#### Scenario: Class repo attachment is pending
- **WHEN** any configured class repo state is not ready
- **THEN** the run refuses before feature selection and names the staged legacy attach flow that can resolve it

#### Scenario: Ready class is not reconciled
- **WHEN** a ready class has neither `contract_reconciled: true` nor its transitional legacy marker
- **THEN** the run refuses before feature selection with legacy reconciliation guidance

#### Scenario: Legacy reconciliation marker temporarily unblocks the run
- **WHEN** a ready class has its legacy reconciliation marker but no definition field because Slice 4 has not run
- **THEN** Slice 3 does not report reconciliation pending for that class

### Requirement: New-versus-continue and resume constraints preserve operator semantics

The system SHALL discover unfinished feature folders from typed `ProgressReport` values and route all choices through `InteractionPort`. If unfinished features exist it SHALL offer start-new or continue, then list unfinished features with next-step information. A resume other than step 3 SHALL reject start-new; resume step 3 SHALL reject continue; a non-step-3 resume with no unfinished or valid cached context SHALL fail with guidance; and resume 8.4 SHALL reopen a valid completed cached feature when no unfinished feature exists.

#### Scenario: Continue selects an unfinished feature
- **WHEN** unfinished features exist and the operator selects continue and a listed feature
- **THEN** that feature becomes the execution target and is persisted in the feature-state cache

#### Scenario: Non-scaffold resume cannot start new
- **WHEN** the operator chooses start-new while `--resume` resolves to a step other than 3
- **THEN** the system explains the conflict and asks for a valid choice without scaffolding

#### Scenario: Scaffold resume cannot continue
- **WHEN** the operator chooses continue while `--resume 3` is active
- **THEN** the system explains the conflict and asks for a valid choice

#### Scenario: Semantic review reopens completed cached feature
- **WHEN** no unfinished feature exists, `--resume 8.4` is supplied, and the cache identifies a valid completed feature
- **THEN** the run targets that feature and starts at 8.4

### Requirement: Feature phases execute through catalog and generic executor

The orchestrator SHALL derive phase order, labels, optional flags, aliases, per-class metadata, and actions from `STEP_CATALOG`; derive default progress from `sequencing.nextStep()`; and invoke `executeStep` for catalog actions. It SHALL NOT branch on model skill names, duplicate session launch logic, parse `overmind status` output, or invoke the `overmind gate` CLI verb. Catalog step 3 is the feature-creating scaffold owned by the new-feature path; a continued feature whose typed next step is 3 (its `feature_br_summary.md` is absent) SHALL be refused with guidance to start a new feature rather than executed or skipped to step 4.1.

#### Scenario: Default run starts at typed next step
- **WHEN** no resume override is supplied for an existing scaffolded feature
- **THEN** the first executed step is the precise catalog step returned by `nextStep()` (step 4.1 or later)

#### Scenario: Continuing a feature without its scaffold is refused
- **WHEN** a continued feature's typed next step is 3 because its `feature_br_summary.md` is absent
- **THEN** the run refuses with guidance to start a new feature and executes neither step 3 nor step 4.1

#### Scenario: Explicit resume overrides feature next step
- **WHEN** a supported numeric step or catalog alias is supplied with `--resume`
- **THEN** the run starts at the resolved catalog step after context validation

#### Scenario: Composite action failure stops the phase
- **WHEN** any action in a multi-action step returns a failed `StepResult`
- **THEN** later actions and phases do not run and the outcome identifies that step for resume

#### Scenario: Repo scan runs only with a ready class repo
- **WHEN** step 4.1 executes and at least one `class_repo_paths` entry has `state: ready`
- **THEN** the `repo-br-scan` action runs before `task-to-br`

#### Scenario: Repo scan is skipped when no class repo is ready
- **WHEN** step 4.1 executes and no `class_repo_paths` entry has `state: ready`
- **THEN** the orchestrator prints the skip notice, does not launch `repo-br-scan`, and still executes `task-to-br`

### Requirement: Operator decisions and optional-step semantics are preserved

Required and optional phase decisions SHALL use `InteractionPort` with existing prompt meaning. Declining a required phase or losing the input stream SHALL stop cleanly. Declining an optional phase SHALL skip it and continue when a later required phase exists; if no required phase remains, the run SHALL finish cleanly.

#### Scenario: Required phase is declined
- **WHEN** the operator declines a required phase confirmation
- **THEN** no action for that phase runs and the CLI exits zero as stopped by operator

#### Scenario: Optional phase is declined before required work
- **WHEN** the operator declines an optional phase and a later required phase exists
- **THEN** the optional phase is skipped and execution continues to the later required phase

#### Scenario: Final optional phase is declined
- **WHEN** the operator declines step 8.4 and no required phase remains
- **THEN** the run reports completion and exits zero

### Requirement: Phase 7 uses typed per-class progress

For a per-class catalog step, the orchestrator SHALL use `ProgressReport` class detail to present analyze-one, refresh, and move-forward decisions. Each selected class SHALL execute as a separate generic-executor call with a single-class binding. Moving forward with pending classes SHALL identify those classes.

#### Scenario: Analyze pending classes incrementally
- **WHEN** the operator selects a pending class for step 7 and execution succeeds
- **THEN** progress is refreshed and the completed class is no longer offered as pending

#### Scenario: Move forward with pending classes
- **WHEN** the operator chooses move-forward while classes remain pending
- **THEN** the loop exits and reports the remaining class names before later phases continue

#### Scenario: No pending class hides analyze choice
- **WHEN** all active classes have completed step 7
- **THEN** the interaction does not offer an analyze-pending-class option

### Requirement: Typed outcomes map to CLI exit and restart guidance

Core flow control SHALL use the `PhaseOutcome` union rather than numeric return codes. The CLI SHALL render stopped/finished outcomes with exit zero and failed outcomes with exit one. Every execution failure SHALL include the exact rerun form `overmind run --path <project> --resume <step>` and preserve actionable diagnostics from the failed action.

#### Scenario: Required action fails
- **WHEN** an executor action fails at a catalog step
- **THEN** the CLI exits one, renders its diagnostics, and prints the exact `overmind run --path <project> --resume <step>` command

#### Scenario: Operator stops cleanly
- **WHEN** a typed outcome is `stoppedByOperator`
- **THEN** the CLI exits zero and does not print failure restart guidance

### Requirement: Runner configuration is validated at run startup

Before executing feature actions, the `overmind run` CLI SHALL load and validate `.setup/models.md` through the typed runner-config loader and resolve the model phases required by the planned catalog execution. Missing files, malformed or skipped rows for a required phase, and unregistered commands SHALL produce actionable `Diagnostic` values naming `.setup/models.md`, the affected phase, and the expected row shape. Startup configuration failure SHALL exit non-zero without scaffolding, launching an agent, or creating a checkpoint.

#### Scenario: Malformed models table refuses the run
- **WHEN** `overmind run` requires a catalog session whose `.setup/models.md` row is malformed and cannot resolve to `{ command, model, args[] }`
- **THEN** the CLI exits non-zero at startup, renders the runner-config diagnostic naming the affected phase and expected row shape, and performs no feature action

#### Scenario: Unregistered runner command refuses the run
- **WHEN** a required model phase resolves to a command without a registered `AgentRunner` adapter
- **THEN** the CLI exits non-zero at startup with an actionable `.setup/models.md` diagnostic and launches no agent

### Requirement: Shell orchestrator cutover is complete

After parity is proven, the system SHALL delete `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `tests/ai_scripts/project_add_feature_e2e_tests.sh`, and their staging references. `QUICKRUN.md` and `overmind/README.md` SHALL name `overmind run` as the feature entrypoint and explain that project-level work remains a separate legacy flow until Slice 4. Deployed runtime workspace files SHALL not be patched directly.

#### Scenario: Replaced shell entrypoint is absent
- **WHEN** the Slice 3 change is complete
- **THEN** source/staging/docs contain no active feature-workflow invocation of `project_add_feature_e2e.sh`

#### Scenario: Ported parity suite covers the shell inventory
- **WHEN** the TypeScript orchestrator tests are mapped against the former shell test functions and responsibility-map rows 1-17 and 21-23
- **THEN** every behavior is owned by a tested TypeScript module, covered by a retained Slice 1/2 test, or explicitly retired by `design_docs/e2e_orchestrator_migration/03_target_architecture.md ## Decisions`
