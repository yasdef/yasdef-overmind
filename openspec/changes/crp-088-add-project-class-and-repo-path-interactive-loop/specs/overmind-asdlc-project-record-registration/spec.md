## MODIFIED Requirements

### Requirement: Add-project flow SHALL register a new project entry in ASDLC metadata
`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` SHALL append one new record under top-level `projects` in `asdlc/asdlc_metadata.yaml` for every successful add-project execution.

Each new record SHALL contain:
- `project: <project_id>`
- `name:`
- `internal_folder:`
- `created_at:`

#### Scenario: Project record is appended with minimal fields
- **WHEN** add-project execution succeeds
- **THEN** `asdlc_metadata.yaml` SHALL contain one additional `projects` entry
- **AND** the new entry SHALL include `project`, `name`, `internal_folder`, and `created_at`
- **AND** class selection and repo-path onboarding data SHALL NOT be persisted in `asdlc_metadata.yaml`

### Requirement: Add-project flow SHALL persist class onboarding state in project definition metadata
After project creation, the seeded `projects/<project_id>/init_progress_definition.yaml` SHALL contain onboarding outputs under `meta_info`.

Persisted fields SHALL include:
- `meta_info.project_id` equal to project folder name
- `meta_info.project_classes` list with selected values from `backend`, `frontend`, `mobile`, `infrastructure`
- `meta_info.class_repo_paths` map for selected classes with `state` (`ready` or `deferred`) and `path`

#### Scenario: Project definition contains class and path onboarding output
- **WHEN** add-project execution succeeds after class/path prompts
- **THEN** `projects/<project_id>/init_progress_definition.yaml` SHALL persist selected classes under `meta_info.project_classes`
- **AND** SHALL persist per-class state/path under `meta_info.class_repo_paths`

### Requirement: Add-project flow SHALL use a single project id across metadata and filesystem identity
The generated project id SHALL be reused as both `projects[].project` and workspace folder name under `asdlc/projects`.

#### Scenario: Metadata and project-definition project id match workspace folder name
- **WHEN** add-project creates a project record and workspace folder
- **THEN** `projects[].project` SHALL equal `projects[].internal_folder`
- **AND** both SHALL match the created project folder name
- **AND** `meta_info.project_id` in the seeded project definition SHALL match the same folder name

### Requirement: Add-project flow SHALL timestamp project creation
The add-project flow SHALL populate `created_at` with a non-empty creation timestamp for the new project record.

#### Scenario: created_at is populated for new record
- **WHEN** add-project appends a new project record
- **THEN** `created_at` SHALL be present and non-empty for that record
