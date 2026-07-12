## ADDED Requirements

### Requirement: Reconcile captures class policy before a repository path

For each deferred class it prompts, `overmind project reconcile` SHALL first ask for the class policy: `A` (the repository will be generated), `B` (existing repository, partial context), or `C` (existing repository, code-first). Policy `A` SHALL record `policy: "A"` with `state: "deferred"` and an empty path, and SHALL NOT ask for a repository path. Policy `B` or `C` SHALL ask for a repository path under the existing validation and single-retry rules; a valid path SHALL record the selected policy with `state: "ready"` and the canonical absolute path, and a blank path SHALL record the selected policy while the class stays deferred with an empty path. Blank input or closed input at the policy prompt SHALL leave the class record unchanged. Reconcile SHALL be the only writer of class policy, repository path, and `ready` state.

#### Scenario: Policy A keeps the class deferred without a path prompt

- **WHEN** the operator answers `A` for a deferred `frontend` class
- **THEN** `frontend` records `policy: "A"` with `state: "deferred"` and an empty path, and no repository path is requested

#### Scenario: Policy C binds an existing repository

- **WHEN** the operator answers `C` for a deferred `backend` class and supplies a valid non-empty directory
- **THEN** `backend` records `policy: "C"`, `state: "ready"`, and the canonical absolute repository path

#### Scenario: Selected policy is recorded, not hardcoded

- **WHEN** the operator answers `B` and supplies a valid repository path
- **THEN** the class records `policy: "B"` rather than `policy: "C"`

#### Scenario: Deferred class stays prompted on later runs

- **WHEN** a class remains deferred after a reconcile run
- **THEN** the next `overmind project reconcile` run prompts that class again

## MODIFIED Requirements

### Requirement: Reconcile absorbs project selection and reconciliation-intent guidance

`overmind project reconcile` SHALL retain the existing project-selection behavior (explicit `--path`, single-project auto-selection, or interactive selection with a finish option) and SHALL, before running the reconciliation session on the interactive path, present reconciliation-intent guidance — stating that this runs repository binding for deferred classes, one-time contract reconciliation, and an optional commit, and that `overmind project add-class` is the command for adding a class or resetting an existing one — and confirm before proceeding. Declining the confirmation, or closing input (EOF), SHALL abort cleanly with no changes and a success exit. The project-level `project_type_code` SHALL NOT be modified by reconcile or by `overmind project add-class`.

#### Scenario: Guidance and confirmation precede reconciliation

- **WHEN** the operator selects a project interactively
- **THEN** the guidance names `overmind project add-class` as the class-membership command and the operator is asked to confirm before the reconciliation session runs

#### Scenario: Declining aborts cleanly

- **WHEN** the operator declines the reconciliation confirmation or closes input at the prompt
- **THEN** no changes are made to the project and the command exits successfully

#### Scenario: project_type_code left untouched

- **WHEN** a project is reconciled or a class is added or reset
- **THEN** the project's `project_type_code` is not modified, keeping the reconcile clean-worktree/commit unit intact

## REMOVED Requirements

### Requirement: Project update is the reconcile flow only

**Reason**: `overmind project add-class` becomes a second project-update verb for class membership, so reconcile is no longer the single update path.

**Migration**: Use `overmind project add-class` to add a class or reset an existing one, and `overmind project reconcile` to bind repositories and reconcile contracts.
