## ADDED Requirements

### Requirement: Common-contract-definition init script SHALL require explicit ASDLC project-folder targeting
`overmind/scripts/init_common_contract_definition.sh` SHALL accept `--path <project-folder>`, SHALL run only when the selected path resolves to a specific ASDLC project folder under `asdlc/projects/`, and SHALL be invoked from staged command path `asdlc/.commands/init_common_contract_definition.sh`.

#### Scenario: Valid ASDLC project path is accepted
- **WHEN** the user runs `/asdlc/.commands/init_common_contract_definition.sh --path /asdlc/projects/<project-id>`
- **THEN** the script SHALL continue using that project folder as the runtime root

#### Scenario: Repo-path invocation is rejected
- **WHEN** the user runs `overmind/scripts/init_common_contract_definition.sh` from repository layout
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print exact message `init asdlc repo first, run this script only from asldc/.commands`

#### Scenario: Missing path argument is rejected
- **WHEN** the user runs the script without `--path`
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an actionable error explaining that a project folder path is required

#### Scenario: Path outside ASDLC projects is rejected
- **WHEN** the user provides a path that does not resolve under `asdlc/projects/`
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an actionable validation error

#### Scenario: ASDLC projects parent path is rejected
- **WHEN** the user provides `--path /asdlc/projects`
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print a validation error explaining that a specific project folder is required

#### Scenario: ASDLC project subfolder path is rejected
- **WHEN** the user provides `--path /asdlc/projects/<project-id>/<subfolder>`
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print a validation error explaining that only `asdlc/projects/<project-id>` is accepted

### Requirement: Common-contract-definition init script SHALL load repository inputs from project metadata
The script SHALL read `<project-folder>/init_progress_definition.yaml` and SHALL use `meta_info.class_repo_paths` as the authoritative set of repository paths to analyze for common contracts.

#### Scenario: Repo paths are loaded from project definition
- **WHEN** the selected project folder contains valid `init_progress_definition.yaml` metadata
- **THEN** the script SHALL read repository paths from `meta_info.class_repo_paths`
- **AND** SHALL use those paths as model input context

#### Scenario: Missing or unusable repo path metadata blocks execution
- **WHEN** `init_progress_definition.yaml` is missing, invalid, or contains no usable repository paths
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an actionable error explaining that repository paths are required for common-contract analysis

#### Scenario: Project root missing init progress definition is rejected
- **WHEN** selected `asdlc/projects/<project-id>` does not contain `init_progress_definition.yaml` at project root
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an actionable error that the required project definition file is missing

### Requirement: Common-contract-definition init script SHALL generate project-scoped output through staged model phase configuration
The script SHALL load phase configuration for `common_contract_definition` from staged `asdlc/.setup/models.md` (sourced from repository `overmind/setup/models.md`), invoke Codex using that configuration, and write the resulting artifact to `<project-folder>/common_contract_definition.md`.

#### Scenario: Common contract definition is generated in project folder
- **WHEN** the selected project folder and repository-path metadata are valid
- **THEN** the script SHALL invoke the configured `common_contract_definition` model phase
- **AND** SHALL write `common_contract_definition.md` inside the selected project folder

#### Scenario: Output remains scoped to selected project folder
- **WHEN** the script completes successfully
- **THEN** it SHALL write the generated artifact only to `<project-folder>/common_contract_definition.md`
- **AND** SHALL not write the artifact to repository-level `overmind/product`

### Requirement: Common-contract-definition init script SHALL commit generated artifact on the currently checked out branch
After successfully generating `<project-folder>/common_contract_definition.md`, the script SHALL create a local git commit in the ASDLC runtime repository on whichever branch is currently checked out, without requiring a specific branch name.

#### Scenario: Successful run commits common-contract-definition artifact on active branch
- **WHEN** the script finishes successfully while ASDLC runtime repository is on branch `<current_branch>`
- **THEN** it SHALL create a local commit on `<current_branch>`
- **AND** that commit SHALL include `<project-folder>/common_contract_definition.md`
