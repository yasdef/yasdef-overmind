## ADDED Requirements

### Requirement: Reconcile binds deferred existing-repository classes

For each deferred class, `overmind project reconcile` SHALL ask for a class policy. Invalid policy input SHALL allow one retry; a second invalid policy input SHALL leave the class unchanged and skip repository path collection for that run. Selecting or keeping policy `A` SHALL leave the class deferred with an empty path and SHALL NOT request a repository path. Blank policy input on a class already carrying policy `B` or `C` SHALL keep that existing policy and continue to repository path collection. Selecting policy `B` (existing repository, partial context) or `C` (existing repository, code-first) SHALL record that policy before repository path collection, then ask for a repository path under the existing validation and single-retry rules. A valid path SHALL preserve the selected policy and record `state: "ready"` with the canonical absolute path. A blank path, closed input, or failed path validation SHALL leave the class deferred with an empty path and the selected policy. Reconcile SHALL be the only writer of repository path and `ready` state.

#### Scenario: Policy A can stay deferred without a path prompt

- **WHEN** `frontend` is deferred with `policy: "A"`
- **THEN** `overmind project reconcile` lets the operator keep `frontend` as policy `A` without prompting for a repository path

#### Scenario: Policy C binds an existing repository

- **WHEN** `backend` is deferred with `policy: "A"` and the operator selects `policy: "C"` with a valid non-empty directory
- **THEN** `backend` records `policy: "C"`, `state: "ready"`, and the canonical absolute repository path

#### Scenario: Selected policy is recorded, not hardcoded

- **WHEN** `backend` is deferred with `policy: "B"` and the operator supplies a valid repository path
- **THEN** the class records `policy: "B"` rather than `policy: "C"`

#### Scenario: Blank policy keeps existing B or C binding intent

- **WHEN** `backend` is deferred with `policy: "B"` and the operator leaves the policy prompt blank
- **THEN** `overmind project reconcile` keeps policy `B` and asks for the repository path

#### Scenario: Deferred existing-repo class stays prompted on later runs

- **WHEN** a policy `B` or `C` class remains deferred after a reconcile run
- **THEN** the next `overmind project reconcile` run prompts that class again

#### Scenario: Invalid policy input has one retry

- **WHEN** the operator enters an invalid policy twice for a deferred class
- **THEN** the class record remains unchanged and no repository path is requested for that class

#### Scenario: Selected policy survives failed path binding

- **WHEN** a deferred class selects policy `B` or `C` and repository path binding does not complete because input closes or validation fails
- **THEN** the class remains deferred with an empty path and records the selected policy

### Requirement: Feature runs distinguish repo binding from contract reconciliation

`overmind run` SHALL allow feature work when a class is deferred with `policy: "A"`, because this means no existing repository is bound yet. It SHALL block deferred classes with `policy: "B"` or `policy: "C"` using repo-binding guidance. It SHALL separately block ready classes whose `contract_reconciled` is not true using contract-reconciliation guidance.

#### Scenario: Deferred policy A does not block feature work

- **WHEN** a project class is deferred with `policy: "A"`
- **THEN** `overmind run` does not refuse feature selection because of that class

#### Scenario: Deferred policy B or C blocks repo binding

- **WHEN** a project class is deferred with `policy: "B"` or `policy: "C"`
- **THEN** `overmind run` refuses before feature selection with guidance to bind the deferred repo path through `overmind project reconcile`

#### Scenario: Malformed not-ready class rows block with incomplete-binding guidance

- **WHEN** a project class is not ready and carries no `policy: "A"` decision
- **THEN** `overmind run` refuses before feature selection with guidance to resolve the class repo binding through `overmind project reconcile`

#### Scenario: Ready unreconciled class blocks contract reconciliation

- **WHEN** a project class is ready and `contract_reconciled` is not true
- **THEN** `overmind run` refuses before feature selection with guidance to reconcile the common contract through `overmind project reconcile`

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
