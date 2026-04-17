## ADDED Requirements

### Requirement: current_state records transport and user-reachable as separate subfields
Each `### Requirement:` block in `technical_requirements.md` SHALL record `current_state` using two explicit subfields: `transport_layer` and `user_reachable_surface`. A single conflated `current_state:` prose line SHALL NOT be used.

#### Scenario: Valid current_state with both subfields
- **WHEN** a technical requirement block describes a capability where both transport code and a user-reachable surface exist
- **THEN** the `current_state` section SHALL contain a `transport_layer:` line and a `user_reachable_surface:` line, each with a concrete value

#### Scenario: Valid current_state transport-only
- **WHEN** only transport-layer code exists for a requirement's current state
- **THEN** the block SHALL record `transport_layer:` with the code reference and `user_reachable_surface: none`

#### Scenario: Conflated prose current_state is rejected
- **WHEN** a `current_state:` field contains a single free-text line mixing transport and reachability information
- **THEN** `check_technical_requirements_quality.sh` SHALL exit non-zero and SHALL identify the requirement block and the missing subfield structure

### Requirement: none marker is required when a current_state subfield is empty
When one side of the `current_state` split is absent for a given requirement, the writer SHALL use the literal value `none` rather than leaving the subfield blank or omitting it entirely.

#### Scenario: Blank subfield is rejected
- **WHEN** a requirement block has `transport_layer:` with an empty value
- **THEN** the quality helper SHALL fail with an error identifying the blank subfield and the requirement name

#### Scenario: Omitted subfield is rejected
- **WHEN** a requirement block has only one of the two `current_state` subfields present
- **THEN** the quality helper SHALL fail and SHALL name the missing subfield

#### Scenario: none value is accepted
- **WHEN** `user_reachable_surface: none` appears in a requirement block's current_state
- **THEN** the quality helper SHALL accept it as valid and SHALL NOT treat it as a blank or missing subfield

### Requirement: current_state split applies uniformly across all requirement types
The `transport_layer` / `user_reachable_surface` split SHALL apply to every `### Requirement:` block in `technical_requirements.md` regardless of whether the requirement is functional (REQ-*) or non-functional (NFR-*).

#### Scenario: NFR block also requires the split
- **WHEN** a `### Requirement: NFR-*` block is present in `technical_requirements.md`
- **THEN** its `current_state` SHALL contain both `transport_layer:` and `user_reachable_surface:` subfields, with `none` used for whichever side is not applicable

#### Scenario: All requirements pass with split present
- **WHEN** every requirement block in `technical_requirements.md` carries both subfields with non-blank values or `none`
- **THEN** `check_technical_requirements_quality.sh` SHALL exit 0 for the split-related checks
