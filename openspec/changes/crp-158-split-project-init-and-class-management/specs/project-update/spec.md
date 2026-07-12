## ADDED Requirements

### Requirement: Project class mutation and contract reconciliation have separate commands

Updating class membership, class policy, repository state, or repository path SHALL be performed only by `overmind project add-class-and-repo`. Reconciling contracts for ready unreconciled classes SHALL be performed by `overmind project reconcile`. Neither command SHALL change the legacy project-level `project_type_code` or `project_type_label`.

#### Scenario: Deferred class is made ready through class management

- **WHEN** an operator wants to attach a repository to a deferred class
- **THEN** the operator runs `overmind project add-class-and-repo`, selects the existing class, proposes its policy and ready path, and confirms the replacement

#### Scenario: Reconcile does not mutate class attachment

- **WHEN** `overmind project reconcile` encounters a deferred class
- **THEN** it leaves that class unchanged and considers only ready classes whose contract reconciliation is pending

### Requirement: Reconcile selects a project and explains reconciliation-only intent

`overmind project reconcile` SHALL retain project selection through explicit existing `--path`, single-project auto-selection, or interactive selection with a finish option. Before an interactively selected reconciliation session, it SHALL explain that class/repository changes use `overmind project add-class-and-repo` and that reconcile processes ready unreconciled classes and may offer to commit reconciliation results. Declining or closed input SHALL abort cleanly with no changes and a success exit.

#### Scenario: Guidance distinguishes class management from reconciliation

- **WHEN** the operator selects a project interactively for reconciliation
- **THEN** the guidance names `overmind project add-class-and-repo` as the class/repository mutation command and asks for confirmation before reconciliation begins

#### Scenario: Reconcile with only deferred classes is a no-op

- **WHEN** the selected project has no ready class awaiting contract reconciliation
- **THEN** reconcile reports no pending reconciliation work and exits successfully without asking for a repository path

#### Scenario: Declining reconciliation aborts cleanly

- **WHEN** the operator declines reconciliation confirmation or closes input at that prompt
- **THEN** no project file is changed and the command exits successfully

## REMOVED Requirements

### Requirement: Project update is the reconcile flow only

**Reason**: Project update now has two explicit owners: class/repository metadata changes and ready-class contract reconciliation.

**Migration**: Use `overmind project add-class-and-repo` for class or repository changes and `overmind project reconcile` after ready classes need contract reconciliation.

### Requirement: Reconcile absorbs project selection and reconciliation-intent guidance

**Reason**: The former guidance describes attach plus reconciliation, while attachment moves to the dedicated class-management command.

**Migration**: Reconcile retains project selection and confirmation under the new reconciliation-only requirement; use class management before reconcile when metadata must change.
