## ADDED Requirements

### Requirement: Step 8 rule requires the transport vs user-reachable split in current_state
`technical_requirements_rule.md` and the generator script `feature_technical_requirements.sh` SHALL require every `### Requirement:` block in generated `technical_requirements.md` to carry `current_state` with explicit `transport_layer` and `user_reachable_surface` subfields. Emitting a single conflated `current_state:` line SHALL NOT be permitted.

#### Scenario: Generator emits both current_state subfields per requirement
- **WHEN** `feature_technical_requirements.sh` is run for a feature
- **THEN** every `### Requirement:` block in the output `technical_requirements.md` SHALL contain a `transport_layer:` subfield and a `user_reachable_surface:` subfield under `current_state`

#### Scenario: Rule file mandates none as the explicit empty marker
- **WHEN** `technical_requirements_rule.md` is read
- **THEN** it SHALL state that when one side of the split is absent the writer SHALL use `none` as the literal value, and that a blank or omitted subfield is invalid

#### Scenario: Rule rejects restating transport coverage as user-reachable
- **WHEN** `technical_requirements_rule.md` is read
- **THEN** it SHALL explicitly forbid listing an internal service, repository, or helper in `user_reachable_surface` and SHALL state that transport-layer presence never implies user-reachable presence

### Requirement: Quality helper rejects technical_requirements.md missing the split
`check_technical_requirements_quality.sh` SHALL fail when any `### Requirement:` block is missing one of the two `current_state` subfields, has either subfield blank, or uses a single conflated `current_state:` prose line.

#### Scenario: Helper fails on missing transport_layer in current_state
- **WHEN** a requirement block's `current_state` section is missing the `transport_layer:` subfield
- **THEN** `check_technical_requirements_quality.sh` SHALL exit non-zero and SHALL name the requirement and missing subfield

#### Scenario: Helper fails on missing user_reachable_surface in current_state
- **WHEN** a requirement block's `current_state` section is missing the `user_reachable_surface:` subfield
- **THEN** `check_technical_requirements_quality.sh` SHALL exit non-zero and SHALL name the requirement and missing subfield

#### Scenario: Helper passes when all requirements carry both subfields
- **WHEN** every `### Requirement:` block in `technical_requirements.md` has non-blank `transport_layer:` and `user_reachable_surface:` values (including `none`)
- **THEN** `check_technical_requirements_quality.sh` SHALL pass the split-related checks

#### Scenario: Helper applies to both functional and non-functional requirements
- **WHEN** `technical_requirements.md` contains NFR blocks in addition to REQ blocks
- **THEN** `check_technical_requirements_quality.sh` SHALL enforce the split on all block types equally
