## ADDED Requirements

### Requirement: Repo ASDLC initializer SHALL persist canonical repo metadata
The repository SHALL persist canonical project metadata in `overmind/init_progress_definition.yaml` under top-level key `meta_info`, including `project_classes`, `project_type_code`, and `project_type_label`.

#### Scenario: Initializer writes normalized repo metadata
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` completes with valid user selections
- **THEN** `overmind/init_progress_definition.yaml` SHALL contain `meta_info.project_type_code`
- **AND** SHALL contain `meta_info.project_type_label`
- **AND** SHALL contain `meta_info.project_classes` as a YAML list

#### Scenario: Re-running initializer with the same selections is deterministic
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` runs multiple times with the same project type and project-class selections
- **THEN** the persisted `meta_info` block SHALL be byte-identical across runs

### Requirement: Repo ASDLC initializer SHALL capture project type and one-or-more project classes interactively
`overmind/scripts/init_asdlc_in_this_repo.sh` SHALL request project type using the same strict `choose: 1/2/3` chooser semantics already used by BR scaffold flow, SHALL map those selections to canonical `project_type_code` and `project_type_label`, and SHALL require one or more project-class selections normalized to `backend`, `frontend`, and `mobile`.

#### Scenario: Valid project type and multiple project classes are persisted
- **WHEN** a user selects valid project type `A`, `B`, or `C` through the chooser and selects more than one supported project class
- **THEN** the initializer SHALL persist the mapped project type code and label
- **AND** SHALL persist every selected project class in normalized canonical form

#### Scenario: Invalid project-class selection is rejected
- **WHEN** project-class input contains unsupported values or resolves to an empty selection
- **THEN** the initializer SHALL display validation guidance
- **AND** SHALL continue prompting until at least one valid project class is provided

### Requirement: Repo metadata consumers SHALL reuse canonical repo project type
`overmind/scripts/init_br_scaffold.sh`, `overmind/scripts/init_repo_structure_summary.sh`, `overmind/scripts/init_project_tech_summary_be.sh`, and `overmind/scripts/init_contracts_inventory.sh` SHALL read canonical project type from `meta_info` in `overmind/init_progress_definition.yaml` and SHALL NOT request project type interactively.

#### Scenario: Canonical project type is reused by downstream initializers
- **WHEN** `meta_info.project_type_code` is present and valid in `overmind/init_progress_definition.yaml`
- **THEN** each downstream initializer SHALL use that value for its project-type-dependent behavior
- **AND** SHALL continue without showing a project-type prompt

### Requirement: Repo metadata consumers SHALL fail fast when canonical metadata is unavailable
If `meta_info.project_type_code` is missing, empty, or invalid, repo metadata consumer scripts SHALL exit non-zero with a meaningful error that directs the user to run `overmind/scripts/init_asdlc_in_this_repo.sh`.

#### Scenario: Missing repo project type metadata blocks downstream scripts
- **WHEN** a downstream initializer runs and `meta_info.project_type_code` is absent or invalid
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print a fail-fast message that instructs the user to run `overmind/scripts/init_asdlc_in_this_repo.sh`
