## ADDED Requirements

### Requirement: Project update is the reconcile flow only

Updating an existing ASDLC project SHALL be performed solely by `overmind project reconcile`; the repository SHALL NOT contain `overmind/scripts/project_mgmt/project_setup_update_project.sh` or its shell test suite, and no packaged staging SHALL reference them. There SHALL be no separate `project update` verb or shell wrapper; the reconcile flow is the single update path.

#### Scenario: Reconcile is the update entry point

- **WHEN** an operator wants to attach deferred class repositories and reconcile contracts for a project
- **THEN** they run `overmind project reconcile` (optionally with `--path <project>`), and no shell update wrapper is involved

#### Scenario: Shell update wrapper is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/project_mgmt/project_setup_update_project.sh` and `tests/ai_scripts/project_setup_update_project_tests.sh` do not exist, and no packaged staging references them

### Requirement: Reconcile absorbs project selection and reconciliation-intent guidance

`overmind project reconcile` SHALL retain the existing project-selection behavior (explicit `--path`, single-project auto-selection, or interactive selection with a finish option) and SHALL, before running the reconciliation session on the interactive path, present the reconciliation-intent guidance previously shown by the shell wrapper — stating that this runs the full attach + one-time contract reconciliation + optional commit, not just a repo attach — and confirm before proceeding. Declining the confirmation, or closing input (EOF), SHALL abort cleanly with no changes and a success exit. The legacy project-level `project_type_code` SHALL NOT be modified by reconcile.

#### Scenario: Guidance and confirmation precede reconciliation

- **WHEN** the operator selects a project interactively
- **THEN** the reconciliation-intent guidance is shown and the operator is asked to confirm before the reconciliation session runs

#### Scenario: Declining aborts cleanly

- **WHEN** the operator declines the reconciliation confirmation or closes input at the prompt
- **THEN** no changes are made to the project and the command exits successfully

#### Scenario: project_type_code left untouched

- **WHEN** a project is reconciled
- **THEN** the reconcile flow does not modify the project's legacy `project_type_code`, keeping its clean-worktree/commit unit intact
