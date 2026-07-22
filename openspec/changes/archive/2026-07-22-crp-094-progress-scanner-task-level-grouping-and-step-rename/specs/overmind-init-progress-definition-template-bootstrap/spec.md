## MODIFIED Requirements

### Requirement: Progress definition SHALL be templated for bootstrap materialization
The repository SHALL define the canonical init progress contract in a template artifact under `overmind/templates/`, and that template SHALL include both top-level `meta_info` defaults and ordered `steps` definitions required by scanner and init scripts. The template step definitions SHALL preserve explicit phase metadata and SHALL use the canonical project-scoped Step 2 label.

#### Scenario: Template contains canonical progress contract
- **WHEN** the template file is inspected for bootstrap source content
- **THEN** it SHALL contain `meta_info.project_classes`, `meta_info.project_type_code`, and `meta_info.project_type_label` defaults
- **AND** SHALL contain the ordered `steps` contract consumed by `overmind/scripts/init_progress_scanner.sh`

#### Scenario: Template preserves project versus feature phase metadata
- **WHEN** the canonical progress-definition template is inspected
- **THEN** Step 1 and Step 2 SHALL remain marked as project/init-phase steps
- **AND** Steps 3 through 7 SHALL remain marked as feature-phase steps for scanner grouping

#### Scenario: Template uses the revised Step 2 label
- **WHEN** the canonical progress-definition template is inspected
- **THEN** Step 2 SHALL be named `Create Cross-Repository Contract Definition For This Project`

