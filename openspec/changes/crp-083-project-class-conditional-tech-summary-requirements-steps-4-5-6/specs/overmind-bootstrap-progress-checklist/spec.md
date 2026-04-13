## MODIFIED Requirements

### Requirement: Bootstrap checklist definition SHALL be data-driven in YAML
The system SHALL define repo-level metadata under top-level key `meta_info` and ordered bootstrap steps under `steps` in `overmind/init_progress_definition.yaml`. Each step SHALL continue to define required artifacts under `finished_only_if_artefacts_present` (strict AND semantics for applicable entries), MAY declare artifact groups under `finished_only_if_artefact_groups`, and MAY declare per-entry conditional guards under `required_if` that reference `meta_info.project_classes`.

#### Scenario: Scanner reads ordered step contract from YAML
- **WHEN** `overmind/scripts/init_progress_scanner.sh` runs
- **THEN** it SHALL evaluate checklist steps in YAML order using `step_number` and `step_name`

#### Scenario: Top-level repo metadata does not interfere with step parsing
- **WHEN** `overmind/init_progress_definition.yaml` contains a top-level `meta_info` mapping before `steps`
- **THEN** the scanner SHALL ignore `meta_info` for checklist ordering/parsing
- **AND** SHALL continue parsing step definitions from `steps`

#### Scenario: Step completion includes required artifact list and optional group constraints
- **WHEN** a step defines entries in `finished_only_if_artefacts_present` and one or more `finished_only_if_artefact_groups`
- **THEN** the scanner SHALL require all applicable required artifacts
- **AND** SHALL require every declared artifact group to satisfy its configured mode

#### Scenario: Conditional artifact entry is required when condition matches
- **WHEN** an artifact entry under `finished_only_if_artefacts_present` declares `required_if.meta_info.project_classes.any_of` and at least one configured class is present
- **THEN** that artifact entry SHALL be evaluated as mandatory for step completion

#### Scenario: Conditional artifact entry is ignored when condition does not match
- **WHEN** an artifact entry under `finished_only_if_artefacts_present` declares `required_if.meta_info.project_classes.any_of` and none of the configured classes are present
- **THEN** that artifact entry SHALL be treated as non-mandatory for step completion

#### Scenario: Unguarded artifact entry remains mandatory
- **WHEN** an artifact entry omits `required_if`
- **THEN** that artifact entry SHALL remain mandatory under existing required-artifact semantics

#### Scenario: Group entries may reuse artifact fields
- **WHEN** a group entry defines `file` with optional `special_folder` and optional `check_key_value`
- **THEN** scanner artifact matching for that entry SHALL use the same path and key/value rules as base required artifacts
