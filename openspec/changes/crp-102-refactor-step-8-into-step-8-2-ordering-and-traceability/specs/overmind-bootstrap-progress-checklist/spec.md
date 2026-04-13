## MODIFIED Requirements

### Requirement: Bootstrap checklist definition SHALL be data-driven in YAML
The system SHALL define ordered bootstrap and feature steps in `overmind/init_progress_definition.yaml`. Each step SHALL continue to declare always-required evidence artifacts under `finished_only_if_artefacts_present` (strict AND semantics), and MAY additionally declare artifact groups under `finished_only_if_artefact_groups`. Artifact entries in both structures MAY include `check_key_value` with `key`, `equals`, and `section`. When implementation planning phases are configured, the contract SHALL represent required Step `8.1` slice planning followed by required Step `8.2` ordered-plan assembly and traceability.

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

#### Scenario: Required Step 8.2 follows required Step 8.1 in checklist order
- **WHEN** implementation slice planning and final implementation-plan assembly are both enabled
- **THEN** the progress definition SHALL declare Step `8.1` as required before Step `8.2`
- **AND** scanner-rendered checklist output SHALL preserve that order
