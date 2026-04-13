## MODIFIED Requirements

### Requirement: Bootstrap checklist definition SHALL be data-driven in YAML
The system SHALL define repo-level metadata under top-level key `meta_info` and ordered bootstrap steps under `steps` in `overmind/init_progress_definition.yaml`. The runtime YAML SHALL be consumable by scanner regardless of whether it was pre-existing or materialized from canonical template during ASDLC initialization. Each step SHALL continue to declare always-required evidence artifacts under `finished_only_if_artefacts_present` (strict AND semantics), and MAY additionally declare artifact groups under `finished_only_if_artefact_groups`. Artifact entries in both structures MAY include `check_key_value` with `key`, `equals`, and `section`.

#### Scenario: Scanner reads ordered step contract from generated runtime YAML
- **WHEN** `overmind/scripts/init_progress_scanner.sh` runs after `overmind/init_progress_definition.yaml` was created from template bootstrap
- **THEN** it SHALL evaluate checklist steps in YAML order using `step_number` and `step_name`

#### Scenario: Top-level repo metadata does not interfere with step parsing
- **WHEN** `overmind/init_progress_definition.yaml` contains a top-level `meta_info` mapping before `steps`
- **THEN** the scanner SHALL ignore `meta_info` for checklist evaluation
- **AND** SHALL continue parsing step definitions from `steps`

#### Scenario: Step completion includes required artifact list and optional group constraints
- **WHEN** a step defines entries in `finished_only_if_artefacts_present` and one or more `finished_only_if_artefact_groups`
- **THEN** the scanner SHALL require all listed required artifacts
- **AND** SHALL require every declared group to satisfy its configured mode

#### Scenario: Group entries may reuse artifact fields
- **WHEN** a group entry defines `file` with optional `special_folder` and optional `check_key_value`
- **THEN** scanner artifact matching for that entry SHALL use the same path and key/value rules as base required artifacts
