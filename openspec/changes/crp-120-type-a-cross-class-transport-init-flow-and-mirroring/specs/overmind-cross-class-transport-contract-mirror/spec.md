## ADDED Requirements

### Requirement: Step `2` mirrors §5 verbatim per backend when an in-project peer exists

For project type `A`, when at least one in-project cross-class peer exists for the backend, Step `2` SHALL reflect each active backend blueprint's §5 verbatim into `common_contract_definition.md`. Each per-backend mirror SHALL preserve `transport_protocol`, `schema_format`, and the populated-or-placeholdered shape exactly as written in the source blueprint.

#### Scenario: Concrete §5 mirrored verbatim

- **WHEN** an active backend blueprint has §5 with concrete values
- **THEN** `common_contract_definition.md` carries those concrete values for that backend

#### Scenario: Placeholdered §5 mirrored verbatim

- **WHEN** an active backend blueprint has §5 with the placeholder pair
- **THEN** `common_contract_definition.md` carries the placeholder for that backend

### Requirement: `common_contract_definition.md` records per-backend ownership for multi-backend projects

When a type `A` project has more than one active backend class, `common_contract_definition.md` SHALL label which backend owns which transport/schema entry (e.g., by `service_name` or `repo_name` from blueprint §1).

#### Scenario: Two backends produce two labelled entries

- **WHEN** a type `A` project has two active backend blueprints with §5 in scope
- **THEN** `common_contract_definition.md` carries two §5 mirror entries, each labelled with its backend identity

#### Scenario: Mismatched values across backends are visible

- **WHEN** two active backend blueprints have different concrete §5 values
- **THEN** the mirror records both entries verbatim and SHALL NOT collapse, normalize, or reject them

### Requirement: Placeholder carry-through does not block Step `2`

Step `2` SHALL complete successfully when one or more active backend blueprints carry the §5 placeholder pair.

#### Scenario: All backends placeholdered passes Step `2`

- **WHEN** every active backend blueprint has §5 with the placeholder pair
- **THEN** Step `2` completes successfully

#### Scenario: Mixed populated and placeholdered passes Step `2`

- **WHEN** some active backend blueprints carry concrete §5 values and others carry the placeholder
- **THEN** Step `2` completes successfully

### Requirement: `common_contract_definition_TEMPLATE.md` provides the mirror location

`overmind/templates/common_contract_definition_TEMPLATE.md` SHALL provide a structural location for the per-backend §5 mirror, used only when §5 applies for a type `A` project.

#### Scenario: Template carries the per-backend §5 mirror section

- **WHEN** the template is read
- **THEN** a per-backend §5 mirror section exists with placeholders for `transport_protocol` and `schema_format` per backend

### Requirement: Step `2` mirror is a no-op when §5 does not apply

When a type `A` project has no in-project cross-class peer for the backend (no active backend, or exactly one active backend with no other active class), Step `2` SHALL NOT write any §5 mirror entries to `common_contract_definition.md`.

#### Scenario: Lone backend produces no §5 mirror

- **WHEN** a type `A` project has exactly one active backend and no other active class
- **THEN** `common_contract_definition.md` carries no §5 mirror entries

#### Scenario: No active backend produces no §5 mirror

- **WHEN** a type `A` project has no active backend class
- **THEN** `common_contract_definition.md` carries no §5 mirror entries

### Requirement: Type `B` and type `C` Step `2` flows are unchanged

The §5 mirror SHALL NOT alter Step `2` behavior for project types `B` and `C`.

#### Scenario: Type `B` Step `2` is unchanged

- **WHEN** a project is type `B`
- **THEN** Step `2` does not write any §5 mirror entries to `common_contract_definition.md`

#### Scenario: Type `C` Step `2` is unchanged

- **WHEN** a project is type `C`
- **THEN** Step `2` does not write any §5 mirror entries to `common_contract_definition.md`
