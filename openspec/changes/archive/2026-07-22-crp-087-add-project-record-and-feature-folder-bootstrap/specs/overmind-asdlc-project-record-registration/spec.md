## ADDED Requirements

### Requirement: Add-project flow SHALL register a new project entry in ASDLC metadata
`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` SHALL append one new record under top-level `projects` in `asdlc/asdlc_metadata.yaml` for every successful add-project execution.

Each new record SHALL contain:
- `project: <project_id>`
- `name:`
- `internal_folder:`
- `created_at:`

#### Scenario: Project record is appended with required fields
- **WHEN** add-project execution succeeds
- **THEN** `asdlc_metadata.yaml` SHALL contain one additional `projects` entry
- **AND** the new entry SHALL include `project`, `name`, `internal_folder`, and `created_at` keys

### Requirement: Add-project flow SHALL use a single project id across metadata and filesystem identity
The project id generated for `project` SHALL be reused as the workspace folder name.

#### Scenario: Metadata project id matches workspace folder name
- **WHEN** add-project creates a project record and workspace folder
- **THEN** `projects[].project` SHALL equal the created workspace folder name

### Requirement: Add-project flow SHALL timestamp project creation
The add-project flow SHALL populate `created_at` with a non-empty creation timestamp for the new project record.

#### Scenario: created_at is populated for new record
- **WHEN** add-project appends a new project record
- **THEN** `created_at` SHALL be present and non-empty for that record
