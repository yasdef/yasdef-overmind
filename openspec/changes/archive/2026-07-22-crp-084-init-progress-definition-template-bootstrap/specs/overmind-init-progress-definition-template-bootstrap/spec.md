## ADDED Requirements

### Requirement: Progress definition SHALL be templated for bootstrap materialization
The repository SHALL define the canonical init progress contract in a template artifact under `overmind/templates/`, and that template SHALL include both top-level `meta_info` defaults and ordered `steps` definitions required by scanner and init scripts.

#### Scenario: Template contains canonical progress contract
- **WHEN** the template file is inspected for bootstrap source content
- **THEN** it SHALL contain `meta_info.project_classes`, `meta_info.project_type_code`, and `meta_info.project_type_label` defaults
- **AND** SHALL contain the ordered `steps` contract consumed by `overmind/scripts/init_progress_scanner.sh`

### Requirement: Repo initializer SHALL materialize runtime progress definition from template when missing
`overmind/scripts/init_asdlc_in_this_repo.sh` SHALL create `overmind/init_progress_definition.yaml` from the canonical template if the runtime file does not exist.

#### Scenario: Missing runtime definition is created from template
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` runs and `overmind/init_progress_definition.yaml` is absent
- **THEN** the script SHALL create `overmind/init_progress_definition.yaml` from the canonical template before metadata persistence continues

#### Scenario: Existing runtime definition triggers fail-fast regeneration guidance
- **WHEN** `overmind/scripts/init_asdlc_in_this_repo.sh` runs and `overmind/init_progress_definition.yaml` already exists
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print exactly `init_progress_definition.yaml already exists, remove it completely if you need re-generate it`

### Requirement: Template-based materialization SHALL preserve deterministic metadata persistence
After materializing from template, `overmind/scripts/init_asdlc_in_this_repo.sh` SHALL persist user-selected metadata into `meta_info` deterministically.

#### Scenario: Materialized file receives user metadata
- **WHEN** the runtime progress definition is first created from template and user selections are provided
- **THEN** `meta_info.project_type_code` SHALL be persisted
- **AND** `meta_info.project_type_label` SHALL be persisted
- **AND** `meta_info.project_classes` SHALL be persisted as normalized canonical values

#### Scenario: First-run generation writes metadata deterministically
- **WHEN** initializer generates `overmind/init_progress_definition.yaml` from template and persists user selections
- **THEN** resulting `meta_info` output in `overmind/init_progress_definition.yaml` SHALL be deterministic for those inputs
