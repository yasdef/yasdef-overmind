## ADDED Requirements

### Requirement: Stack blueprint quality helper validates one artifact
Overmind SHALL provide `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` to validate a single project stack blueprint artifact passed as a path argument. The helper SHALL return stable exit codes: `0` for valid content, `1` for recoverable content issues, and `2` for helper/runtime failures.

#### Scenario: Valid blueprint exits successfully
- **WHEN** the helper validates a structurally complete blueprint
- **THEN** it exits with code `0`

#### Scenario: Missing target path is helper failure
- **WHEN** the helper is invoked without a target blueprint path
- **THEN** it exits with code `2` and reports the missing argument

#### Scenario: Invalid blueprint exits with content failure
- **WHEN** the helper validates a blueprint with missing required fields
- **THEN** it exits with code `1` and reports quality-gate failures

### Requirement: Quality helper rejects unfilled or empty required content
The quality helper SHALL reject stack blueprints that contain `[UNFILLED]`, blank required metadata, blank required stack categories, blank required layer fields, or blank baseline inventory.

#### Scenario: Placeholder remains in blueprint
- **WHEN** a blueprint still contains `[UNFILLED]`
- **THEN** the helper exits with code `1`

#### Scenario: Required meta field is blank
- **WHEN** a blueprint omits or blanks `repo_name`
- **THEN** the helper exits with code `1`

#### Scenario: Required stack choice is blank
- **WHEN** a blueprint omits or blanks a required stack choice category
- **THEN** the helper exits with code `1`

### Requirement: Quality helper validates date-shaped metadata
The quality helper SHALL validate that `last_updated` is present in `YYYY-MM-DD` format.

#### Scenario: Valid last updated date passes
- **WHEN** a blueprint contains `last_updated: 2026-04-26`
- **THEN** the helper accepts the metadata date shape

#### Scenario: Invalid last updated date fails
- **WHEN** a blueprint contains `last_updated: today`
- **THEN** the helper exits with code `1`

### Requirement: Quality helper validates class-specific layer blocks
The quality helper SHALL read the blueprint class from `## 1. Meta` and validate that `## 3. Layer Bindings` contains every required layer block for that class. Missing required layer blocks SHALL fail validation.

#### Scenario: Backend missing persistence layer fails
- **WHEN** a backend blueprint omits the persistence layer block
- **THEN** the helper exits with code `1`

#### Scenario: Frontend missing UI composition layer fails
- **WHEN** a frontend blueprint omits the UI composition layer block
- **THEN** the helper exits with code `1`

#### Scenario: Mobile missing native device layer fails
- **WHEN** a mobile blueprint omits the mobile native/device layer block
- **THEN** the helper exits with code `1`

### Requirement: Quality helper validates required layer fields
Every required layer block SHALL contain non-empty `folder_paths`, `archetypes`, and `user_reachable_pattern` fields. A field with no applicable value SHALL use literal `none`.

#### Scenario: Missing folder paths fails
- **WHEN** a required layer block omits `folder_paths`
- **THEN** the helper exits with code `1`

#### Scenario: Missing archetypes fails
- **WHEN** a required layer block omits `archetypes`
- **THEN** the helper exits with code `1`

#### Scenario: Non-user-reachable layer uses none
- **WHEN** a service or internal layer has `user_reachable_pattern: none`
- **THEN** the helper accepts the field as populated

### Requirement: Quality helper validates baseline token shape
The quality helper SHALL accept baseline user-reachable inventory entries only when they are concrete operator-invocable tokens or literal `none`. The helper SHALL reject prose descriptions.

#### Scenario: HTTP endpoint token passes
- **WHEN** a backend blueprint inventory contains `POST /api/v1/auth/login`
- **THEN** the helper accepts the inventory entry

#### Scenario: Route token passes
- **WHEN** a frontend blueprint inventory contains `/login`
- **THEN** the helper accepts the inventory entry

#### Scenario: Mobile deep link token passes
- **WHEN** a mobile blueprint inventory contains `app://login`
- **THEN** the helper accepts the inventory entry

#### Scenario: Literal none passes
- **WHEN** a blueprint inventory contains only `none`
- **THEN** the helper accepts the inventory

#### Scenario: Prose inventory fails
- **WHEN** a blueprint inventory contains `the admin login page`
- **THEN** the helper exits with code `1`

### Requirement: Quality helper validates artifact class values
The quality helper SHALL accept only `backend`, `frontend`, or `mobile` as blueprint class values. Any other class value SHALL fail validation.

#### Scenario: Supported class passes class check
- **WHEN** a blueprint declares `class: frontend`
- **THEN** the helper applies frontend validation rules

#### Scenario: Unsupported class fails class check
- **WHEN** a blueprint declares `class: desktop`
- **THEN** the helper exits with code `1`

### Requirement: Quality tests cover success and failure paths
The test suite SHALL include coverage for valid backend/frontend/mobile blueprints, missing required metadata, missing required layer blocks, invalid baseline user-reachable tokens, and valid `none` baseline inventory.

#### Scenario: Valid class examples are covered
- **WHEN** `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh` runs
- **THEN** it verifies valid backend, frontend, and mobile blueprints pass

#### Scenario: Invalid field cases are covered
- **WHEN** `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh` runs
- **THEN** it verifies missing metadata, missing layers, and invalid inventory tokens fail
