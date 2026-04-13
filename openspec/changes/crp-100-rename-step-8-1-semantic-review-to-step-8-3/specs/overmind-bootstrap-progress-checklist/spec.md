## MODIFIED Requirements

### Requirement: Bootstrap checklist definition SHALL be data-driven in YAML
The system SHALL define ordered bootstrap steps in `overmind/init_progress_definition.yaml`. Each step SHALL continue to declare always-required evidence artifacts under `finished_only_if_artefacts_present` (strict AND semantics), and MAY additionally declare artifact groups under `finished_only_if_artefact_groups`. Artifact entries in both structures MAY include `check_key_value` with `key`, `equals`, and `section`. When an implementation-plan semantic-review feature phase is present, it SHALL be represented as optional Step `8.3` in the ordered step contract.

#### Scenario: Scanner reads ordered step contract from YAML
- **WHEN** `overmind/scripts/init_progress_scanner.sh` runs
- **THEN** it SHALL evaluate steps in YAML order using `step_number` and `step_name`

#### Scenario: Step completion includes required artifact list and optional group constraints
- **WHEN** a step defines entries in `finished_only_if_artefacts_present` and one or more `finished_only_if_artefact_groups`
- **THEN** the scanner SHALL require all listed required artifacts
- **AND** SHALL require every declared group to satisfy its configured mode

#### Scenario: Group entries may reuse artifact fields
- **WHEN** a group entry defines `file` with optional `special_folder` and optional `check_key_value`
- **THEN** scanner artifact matching for that entry SHALL use the same path and key/value rules as base required artifacts

#### Scenario: Optional semantic review step uses Step 8.3 numbering
- **WHEN** implementation-plan semantic review is included in the feature progress definition
- **THEN** it SHALL be declared as optional Step `8.3`
- **AND** scanner-rendered checklist output SHALL use `8.3` for that semantic-review phase
