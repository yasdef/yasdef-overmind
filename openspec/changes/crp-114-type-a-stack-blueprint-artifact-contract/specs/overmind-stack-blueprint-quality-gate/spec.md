## ADDED Requirements

### Requirement: Stack blueprint quality helper validates one artifact
Overmind SHALL provide `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` to validate a single stack-family blueprint artifact passed as a path argument. The helper SHALL return stable exit codes: `0` for valid content, `1` for recoverable content issues, and `2` for helper/runtime failures.

#### Scenario: Valid blueprint exits successfully
- **WHEN** the helper validates a structurally complete stack-family blueprint
- **THEN** it exits with code `0`

#### Scenario: Missing target path is helper failure
- **WHEN** the helper is invoked without a target blueprint path
- **THEN** it exits with code `2` and reports the missing argument

#### Scenario: Invalid blueprint exits with content failure
- **WHEN** the helper validates a blueprint with missing required fields
- **THEN** it exits with code `1` and reports quality-gate failures

### Requirement: Quality helper rejects unfilled or empty required content
The quality helper SHALL reject stack-family blueprints that contain `[UNFILLED]`, blank required metadata, or blank approved stack-family choice.

#### Scenario: Placeholder remains in blueprint
- **WHEN** a blueprint still contains `[UNFILLED]`
- **THEN** the helper exits with code `1`

#### Scenario: Required class field is blank
- **WHEN** a blueprint omits or blanks `class`
- **THEN** the helper exits with code `1`

#### Scenario: Stack family choice is blank
- **WHEN** a blueprint omits or blanks `stack_family`
- **THEN** the helper exits with code `1`

### Requirement: Quality helper validates date-shaped metadata
The quality helper SHALL validate that `last_updated` is present in `YYYY-MM-DD` format.

#### Scenario: Valid last updated date passes
- **WHEN** a blueprint contains `last_updated: 2026-04-26`
- **THEN** the helper accepts the metadata date shape

#### Scenario: Invalid last updated date fails
- **WHEN** a blueprint contains `last_updated: today`
- **THEN** the helper exits with code `1`

### Requirement: Quality helper validates artifact class values
The quality helper SHALL accept only `backend`, `frontend`, or `mobile` as blueprint class values. Any other class value SHALL fail validation.

#### Scenario: Supported class passes class check
- **WHEN** a blueprint declares `class: frontend`
- **THEN** the helper applies minimal frontend validation rules

#### Scenario: Unsupported class fails class check
- **WHEN** a blueprint declares `class: desktop`
- **THEN** the helper exits with code `1`

### Requirement: Quality helper does not require structural evidence fields
The quality helper SHALL NOT require concrete repo paths, package roots, folder paths, layer blocks, archetypes, path strategies, constraints, baseline user-reachable inventory, or token-shaped surfaces.

#### Scenario: Valid minimal blueprint omits structural evidence
- **WHEN** a blueprint contains class, last updated date, and stack family only
- **THEN** the helper accepts the artifact without asking for layer bindings or baseline tokens

#### Scenario: Baseline inventory is not required
- **WHEN** a blueprint has no baseline user-reachable inventory section
- **THEN** the helper does not fail for missing inventory

### Requirement: Quality tests cover success and failure paths
The test suite SHALL include coverage for valid backend/frontend/mobile stack-family blueprints, missing required metadata, unsupported class values, invalid date shape, missing stack-family choice, and absence of removed structural fields.

#### Scenario: Valid class examples are covered
- **WHEN** `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh` runs
- **THEN** it verifies valid backend, frontend, and mobile stack-family blueprints pass

#### Scenario: Invalid field cases are covered
- **WHEN** `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh` runs
- **THEN** it verifies missing metadata, unsupported class, invalid date, and missing stack-family choice fail
