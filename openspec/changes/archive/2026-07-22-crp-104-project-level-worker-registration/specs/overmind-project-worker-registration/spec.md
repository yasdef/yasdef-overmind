## ADDED Requirements

### Requirement: Register-worker command is restricted to project-level path scope
`project_register_worker.sh` SHALL require `--path <asdlc/projects/<project-id>>` and SHALL fail fast when the provided path does not resolve to a valid ASDLC project directory.

#### Scenario: Missing path argument is rejected
- **WHEN** `project_register_worker.sh` runs without `--path`
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an error describing the required project-level `--path` argument

#### Scenario: Non-project path is rejected
- **WHEN** `project_register_worker.sh --path <path>` runs and `<path>` is not a directory under ASDLC `projects/` for one project root
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an error explaining that a project folder path is required

### Requirement: Register-worker command requires exactly one supported worker class
The registration flow SHALL interactively require the operator to choose exactly one worker class and SHALL accept only `backend`, `frontend`, `mobile`, or `infrastructure`.

#### Scenario: Valid class selection is accepted
- **WHEN** the operator selects one supported class during `project_register_worker.sh` execution
- **THEN** the script SHALL use that single normalized class value for the new worker record

#### Scenario: Invalid class selection is retried
- **WHEN** the operator enters an unsupported, empty, or ambiguous class selection
- **THEN** the script SHALL print validation guidance
- **AND** SHALL continue prompting until exactly one supported class is chosen

### Requirement: Successful registration appends a new active worker entry
After a valid class selection, the system SHALL generate a new UUID, record the registration date, append a new worker entry with `active` status into `<project-path>/workers.yaml`, and complete without mutating existing worker entries.

#### Scenario: New worker is registered successfully
- **WHEN** `project_register_worker.sh --path <asdlc/projects/<project-id>>` completes successfully
- **THEN** the script SHALL append exactly one new worker entry to `<project-path>/workers.yaml`
- **AND** the entry SHALL store a generated UUID unique within that file
- **AND** the entry SHALL store the selected worker class
- **AND** the entry SHALL store `status: active`
- **AND** the entry SHALL store the registration date for that run

### Requirement: Successful registration prints the developer handoff message
On successful worker registration, the script SHALL end by printing `new worker registered with uuid: <uuid> - copy and pass this unique id to developer so he'll register worker on he's side`.

#### Scenario: Success output includes generated uuid
- **WHEN** `project_register_worker.sh --path <asdlc/projects/<project-id>>` completes successfully
- **THEN** the final success output SHALL match `new worker registered with uuid: <uuid> - copy and pass this unique id to developer so he'll register worker on he's side`
- **AND** `<uuid>` SHALL be the same UUID persisted in the new worker record

### Requirement: Regression coverage validates project worker registration flow
Shell test coverage under `tests/ai_scripts/` SHALL verify project-path validation, file scaffolding, additive registration behavior, interactive class validation, and final success output for the register-worker flow.

#### Scenario: Project worker registration tests pass
- **WHEN** the project worker registration shell test suite is run from repository root
- **THEN** it SHALL pass and confirm the project-path, registry-file, interactive-class, append-only, and success-message contracts
