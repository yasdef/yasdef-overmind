## MODIFIED Requirements

### Requirement: Repo ASDLC initializer SHALL persist canonical repo metadata
The repository SHALL persist canonical project metadata in `overmind/init_progress_definition.yaml` under top-level key `meta_info`, including `project_classes`, `project_type_code`, and `project_type_label`. If `overmind/init_progress_definition.yaml` is missing, `overmind/scripts/init_asdlc_in_this_repo.sh` SHALL first materialize it from the canonical template before writing `meta_info`.

#### Scenario: Initializer writes normalized repo metadata
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` completes with valid user selections
- **THEN** `overmind/init_progress_definition.yaml` SHALL contain `meta_info.project_type_code`
- **AND** SHALL contain `meta_info.project_type_label`
- **AND** SHALL contain `meta_info.project_classes` as a YAML list

#### Scenario: Missing runtime progress definition is bootstrapped before metadata write
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` runs and `overmind/init_progress_definition.yaml` does not exist
- **THEN** it SHALL create `overmind/init_progress_definition.yaml` from the canonical template
- **AND** SHALL persist selected `meta_info` values into the newly created file in the same run

#### Scenario: Existing runtime definition fails fast with canonical message
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` runs and `overmind/init_progress_definition.yaml` already exists
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print exactly `init_progress_definition.yaml already exists, remove it completely if you need re-generate it`
