## ADDED Requirements

### Requirement: Quality helper validates §5 presence by class

`check_project_stack_blueprint_quality.sh` SHALL require §5 "Cross-Class Transport/Contract Approach" in every backend blueprint when the project has at least one in-project cross-class peer (another active backend, an active frontend, or an active mobile class), and SHALL reject §5 when present in any frontend or mobile blueprint, using stable exit codes: `0` success, `1` recoverable artifact quality issue, `2` helper/runtime failure. When the project has no such peer, the helper SHALL NOT require §5 in the backend blueprint.

#### Scenario: Backend blueprint missing §5 fails when a peer class exists

- **WHEN** a backend blueprint omits the §5 section and the project has at least one other active class
- **THEN** the helper exits `1`

#### Scenario: Lone backend without §5 passes

- **WHEN** a backend blueprint omits the §5 section and the project has exactly one active backend class with no other active class
- **THEN** the helper does not exit `1` for missing §5

#### Scenario: Frontend blueprint with §5 fails

- **WHEN** a frontend blueprint includes a §5 section
- **THEN** the helper exits `1`

#### Scenario: Mobile blueprint with §5 fails

- **WHEN** a mobile blueprint includes a §5 section
- **THEN** the helper exits `1`

### Requirement: Quality helper validates §5 fields are populated

The helper SHALL require all three §5 fields (`transport_protocol`, `schema_format`, `user_approved`) to be present and non-empty in every backend blueprint.

#### Scenario: Missing §5 field fails

- **WHEN** any of `transport_protocol`, `schema_format`, or `user_approved` is missing or blank
- **THEN** the helper exits `1`

### Requirement: Quality helper rejects mixed §5 protocol/schema state

The helper SHALL require `transport_protocol` and `schema_format` to be in matching states: either both concrete values, or both the literal placeholder `<to be defined during first feature implementation plan>`. Mixed states SHALL be rejected.

#### Scenario: Concrete protocol with placeholdered schema fails

- **WHEN** `transport_protocol` is a concrete value and `schema_format` is the placeholder
- **THEN** the helper exits `1`

#### Scenario: Placeholdered protocol with concrete schema fails

- **WHEN** `transport_protocol` is the placeholder and `schema_format` is a concrete value
- **THEN** the helper exits `1`

#### Scenario: Both concrete passes the state-pairing rule

- **WHEN** both `transport_protocol` and `schema_format` carry concrete values
- **THEN** the helper does not exit `1` for the state-pairing rule

#### Scenario: Both placeholder passes the state-pairing rule

- **WHEN** both `transport_protocol` and `schema_format` carry the placeholder
- **THEN** the helper does not exit `1` for the state-pairing rule

### Requirement: Quality helper rejects user_approved=true paired with placeholder

The helper SHALL reject `user_approved: true` when either `transport_protocol` or `schema_format` carries the placeholder.

#### Scenario: user_approved=true with placeholder fields fails

- **WHEN** `user_approved` is `true` and either `transport_protocol` or `schema_format` is the placeholder
- **THEN** the helper exits `1`

#### Scenario: user_approved=false with placeholder fields passes the approval rule

- **WHEN** `user_approved` is `false` and both fields carry the placeholder
- **THEN** the helper does not exit `1` for the approval-pairing rule

#### Scenario: user_approved=true with concrete fields passes the approval rule

- **WHEN** `user_approved` is `true` and both fields carry concrete values
- **THEN** the helper does not exit `1` for the approval-pairing rule

### Requirement: Quality helper remains deterministic

The §5 quality rules SHALL perform deterministic structural validation only and SHALL NOT make product, architecture taste, or MCP availability judgments.

#### Scenario: Runtime failure is separate

- **WHEN** the target argument is missing or the target file does not exist
- **THEN** the helper exits `2`

#### Scenario: No in-project cross-class peer means no §5 enforcement

- **WHEN** a project has no active backend class, or has exactly one active backend class with no other active class
- **THEN** the §5 rules do not require §5 and SHALL NOT cause a §5 failure for its absence
