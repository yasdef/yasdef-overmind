## ADDED Requirements

### Requirement: Quality helper validates Gap 5 structure
`check_project_stack_blueprint_quality.sh` SHALL validate structural completeness for backend, frontend, and mobile project stack blueprints using stable exit codes: `0` success, `1` recoverable artifact quality issue, and `2` helper/runtime failure.

#### Scenario: Valid backend blueprint passes
- **WHEN** a backend blueprint includes complete Meta, Stack Choices, and Layer Bindings sections
- **THEN** the helper exits `0`

#### Scenario: Valid frontend blueprint passes
- **WHEN** a frontend blueprint includes complete Meta, Stack Choices, and Layer Bindings sections
- **THEN** the helper exits `0`

#### Scenario: Valid mobile blueprint passes
- **WHEN** a mobile blueprint includes complete Meta, Stack Choices, and Layer Bindings sections
- **THEN** the helper exits `0`

### Requirement: Quality helper validates metadata fields
The helper SHALL require class, repo identity, planned repo path, package/root metadata, and `last_updated` in `YYYY-MM-DD` format.

#### Scenario: Missing package root fails
- **WHEN** a required package/root metadata field is missing
- **THEN** the helper exits `1`

#### Scenario: Invalid date fails
- **WHEN** `last_updated` is not in `YYYY-MM-DD` format
- **THEN** the helper exits `1`

### Requirement: Quality helper validates stack choices
The helper SHALL require every class-specific Stack Choices field to be present and populated.

#### Scenario: Missing stack choice fails
- **WHEN** a required stack choice is missing or blank
- **THEN** the helper exits `1`

### Requirement: Quality helper validates layer bindings
The helper SHALL require every class-specific layer block and SHALL require `folder_paths`, `archetypes`, and `user_reachable_pattern` in each block.

#### Scenario: Missing layer fails
- **WHEN** a required layer block is missing
- **THEN** the helper exits `1`

#### Scenario: Missing layer field fails
- **WHEN** a required layer binding field is missing or blank
- **THEN** the helper exits `1`

### Requirement: Quality helper remains deterministic
The helper SHALL perform deterministic structural validation only and SHALL NOT make product, architecture taste, or MCP availability judgments.

#### Scenario: Runtime failure is separate
- **WHEN** the target argument is missing or the target file does not exist
- **THEN** the helper exits `2`
