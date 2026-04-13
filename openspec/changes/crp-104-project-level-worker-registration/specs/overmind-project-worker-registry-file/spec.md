## ADDED Requirements

### Requirement: Project worker registry file is scaffolded at project scope
The system SHALL create `<project-path>/workers.yaml` only when the file is missing during project-level worker registration, and SHALL preserve the existing file when it already exists.

#### Scenario: Missing workers file is created on first registration
- **WHEN** `project_register_worker.sh --path <asdlc/projects/<project-id>>` runs successfully and `<project-path>/workers.yaml` does not exist
- **THEN** the script SHALL create `<project-path>/workers.yaml`
- **AND** the created file SHALL include the selected project's `project_id`
- **AND** the created file SHALL include a top-level `workers` collection before the new worker entry is persisted

#### Scenario: Existing workers file is preserved and extended
- **WHEN** `project_register_worker.sh --path <asdlc/projects/<project-id>>` runs successfully and `<project-path>/workers.yaml` already exists
- **THEN** the script SHALL preserve existing worker entries already stored in the file
- **AND** SHALL append exactly one new worker record for the current registration
- **AND** SHALL NOT overwrite `project_id` with a different value

### Requirement: Project worker registry stores canonical project metadata and normalized worker records
`<project-path>/workers.yaml` SHALL use a top-level `project_id` sourced from `<project-path>/init_progress_definition.yaml` `meta_info.project_id` and SHALL store each worker record with `uuid`, `class`, `status`, and `registered_at` fields.

#### Scenario: Canonical project metadata is copied into workers file
- **WHEN** project worker registration runs for a project whose `init_progress_definition.yaml` contains `meta_info.project_id`
- **THEN** `<project-path>/workers.yaml` SHALL store that same value in top-level `project_id`

#### Scenario: Worker record fields are normalized on write
- **WHEN** a new worker registration succeeds
- **THEN** the appended worker record SHALL contain a non-empty `uuid`
- **AND** SHALL contain exactly one `class` value equal to `backend`, `frontend`, `mobile`, or `infrastructure`
- **AND** SHALL contain `status: active`
- **AND** SHALL contain non-empty `registered_at`

### Requirement: Registration fails fast when canonical project metadata is unavailable
The system SHALL exit non-zero with a meaningful error when project-level worker registration cannot resolve canonical `project_id` metadata from `<project-path>/init_progress_definition.yaml`.

#### Scenario: Project definition is missing
- **WHEN** `project_register_worker.sh --path <asdlc/projects/<project-id>>` runs and `<project-path>/init_progress_definition.yaml` does not exist
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an error explaining that project definition metadata is required

#### Scenario: Project id metadata is missing
- **WHEN** `project_register_worker.sh --path <asdlc/projects/<project-id>>` runs and `init_progress_definition.yaml` exists but `meta_info.project_id` is missing or empty
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an error explaining that canonical `project_id` metadata is required
