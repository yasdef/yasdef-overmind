## ADDED Requirements

### Requirement: `feature_contract_delta_TEMPLATE.md` carries per-backend §5 fields

`overmind/templates/feature_contract_delta_TEMPLATE.md` SHALL include two per-backend fields, `transport_protocol` and `schema_format`, each accepting a concrete value or the literal placeholder `<to be defined during first feature implementation plan>`.

#### Scenario: Template includes per-backend §5 fields

- **WHEN** the feature contract delta template is read
- **THEN** it carries `transport_protocol` and `schema_format` fields per backend, with example shapes for both concrete values and the placeholder

### Requirement: Step `6` mirrors current §5 from `common_contract_definition.md` per backend when §5 applies

For project type `A`, when at least one in-project cross-class peer exists for the backend, Step `6` SHALL mirror the current per-backend `transport_protocol` and `schema_format` from `common_contract_definition.md` into `feature_contract_delta.md`.

#### Scenario: Concrete contract values mirror into delta

- **WHEN** `common_contract_definition.md` carries concrete §5 values for a backend and the feature does not redefine them
- **THEN** `feature_contract_delta.md` carries the same concrete values for that backend

#### Scenario: Placeholder mirrors into delta

- **WHEN** `common_contract_definition.md` carries the placeholder for a backend and the feature does not redefine it
- **THEN** `feature_contract_delta.md` carries the placeholder for that backend

### Requirement: Feature may record concrete §5 values directly

When a feature defines or refines `transport_protocol` and `schema_format`, `feature_contract_delta.md` SHALL record the concrete values directly, regardless of whether `common_contract_definition.md` carries the placeholder or different concrete values for that backend.

#### Scenario: Feature defines concrete values over a placeholder

- **WHEN** `common_contract_definition.md` carries the placeholder for a backend and the feature defines `transport_protocol` and `schema_format`
- **THEN** `feature_contract_delta.md` records the feature's concrete values for that backend

#### Scenario: Feature refines concrete values

- **WHEN** `common_contract_definition.md` carries concrete §5 values for a backend and the feature refines them
- **THEN** `feature_contract_delta.md` records the refined concrete values for that backend

#### Scenario: Subsequent features may continue to mirror

- **WHEN** an earlier feature recorded concrete values in its delta and `common_contract_definition.md` still carries the placeholder
- **THEN** subsequent features may carry the placeholder by mirror or record their own concrete values directly

### Requirement: No Step `6` enforcement check for §5

Step `6` SHALL NOT introduce a resolution state machine, required block, terminal-state check, or quality-helper enforcement for §5. The two per-backend fields either carry concrete values or carry the placeholder; nothing else.

#### Scenario: No quality helper rejects a placeholder delta

- **WHEN** `feature_contract_delta.md` carries the placeholder for one or more backends
- **THEN** Step `6` does not fail on §5 grounds

#### Scenario: No state machine tracks resolution

- **WHEN** the system inspects `feature_contract_delta.md`
- **THEN** it finds only the two per-backend fields with no associated resolution state, status, or required block

### Requirement: Step `6` mirror is a no-op when §5 does not apply

When a type `A` project has no in-project cross-class peer for the backend, Step `6` SHALL NOT mirror or require §5 fields in `feature_contract_delta.md`.

#### Scenario: Lone backend produces no delta §5

- **WHEN** a type `A` project has exactly one active backend and no other active class
- **THEN** `feature_contract_delta.md` carries no §5 fields

#### Scenario: No active backend produces no delta §5

- **WHEN** a type `A` project has no active backend class
- **THEN** `feature_contract_delta.md` carries no §5 fields

### Requirement: Type `B` and type `C` Step `6` flows are unchanged

The §5 delta mirror SHALL NOT alter Step `6` behavior for project types `B` and `C`.

#### Scenario: Type `B` Step `6` is unchanged

- **WHEN** a project is type `B`
- **THEN** Step `6` does not write or require §5 fields in `feature_contract_delta.md`

#### Scenario: Type `C` Step `6` is unchanged

- **WHEN** a project is type `C`
- **THEN** Step `6` does not write or require §5 fields in `feature_contract_delta.md`
