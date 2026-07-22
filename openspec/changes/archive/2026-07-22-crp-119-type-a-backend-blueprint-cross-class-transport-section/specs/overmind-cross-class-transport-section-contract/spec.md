## ADDED Requirements

### Requirement: Backend blueprint defines §5 cross-class transport/contract approach

The backend project stack blueprint template SHALL define a required §5 section titled "Cross-Class Transport/Contract Approach" carrying three fields: `transport_protocol`, `schema_format`, and `user_approved`.

#### Scenario: §5 section is present in backend template

- **WHEN** the backend stack blueprint template is read
- **THEN** §5 "Cross-Class Transport/Contract Approach" exists with `transport_protocol`, `schema_format`, and `user_approved` fields

#### Scenario: §5 includes inline reference example

- **WHEN** the backend template is read
- **THEN** the §5 section includes an inline reference example showing both a populated shape and a placeholdered shape

### Requirement: §5 supports populated and placeholdered shapes

The §5 section SHALL support exactly two valid shapes: fully populated with concrete values for both `transport_protocol` and `schema_format` paired with `user_approved: true`, or fully placeholdered with the literal sentinel `<to be defined during first feature implementation plan>` for both fields paired with `user_approved: false`.

#### Scenario: Populated shape is valid

- **WHEN** §5 carries concrete values for both `transport_protocol` and `schema_format` and `user_approved: true`
- **THEN** the shape is valid

#### Scenario: Placeholdered shape is valid

- **WHEN** §5 carries the literal placeholder for both `transport_protocol` and `schema_format` and `user_approved: false`
- **THEN** the shape is valid

### Requirement: §5 placeholder is a distinct sentinel

The §5 placeholder SHALL be the literal string `<to be defined during first feature implementation plan>`, distinct from Step `7`'s `<to be defined during implementation>` sentinel so the two obligations remain separately trackable.

#### Scenario: Placeholder text differs from Step `7` sentinel

- **WHEN** the §5 placeholder is compared with Step `7`'s `<to be defined during implementation>` sentinel
- **THEN** the two strings are not identical

### Requirement: Backend is the sole holder of §5

The frontend and mobile project stack blueprint templates SHALL NOT carry §5 cross-class transport/contract approach content.

#### Scenario: Frontend template has no §5

- **WHEN** the frontend stack blueprint template is read
- **THEN** no §5 "Cross-Class Transport/Contract Approach" section exists

#### Scenario: Mobile template has no §5

- **WHEN** the mobile stack blueprint template is read
- **THEN** no §5 "Cross-Class Transport/Contract Approach" section exists

### Requirement: Multi-backend projects carry §5 independently per blueprint

When a project type `A` has multiple active backend classes, every active backend blueprint SHALL carry its own §5 section. The contract SHALL NOT mandate that values match across multiple backends.

#### Scenario: Each active backend blueprint has its own §5

- **WHEN** a type `A` project has more than one active backend blueprint
- **THEN** each active backend blueprint independently carries a valid §5 section

### Requirement: Step 1.1 finished-only-if condition enforces §5 state when an in-project peer exists

`init_progress_definition_TEMPLATE.yaml` SHALL include, for project type `A`, a Step `1.1` finished-only-if condition stating that every active backend blueprint has a §5 section that is either fully populated and `user_approved: true`, or fully placeholdered — but only when the project has at least one in-project cross-class peer for the backend (another active backend, or an active frontend, or an active mobile class).

#### Scenario: §5 fully populated and approved satisfies the condition

- **WHEN** every active backend blueprint has §5 with concrete values and `user_approved: true`
- **THEN** the Step `1.1` condition is satisfied

#### Scenario: §5 fully placeholdered satisfies the condition

- **WHEN** every active backend blueprint has §5 with the placeholder for both fields and `user_approved: false`
- **THEN** the Step `1.1` condition is satisfied

#### Scenario: No active backend produces no §5 anywhere

- **WHEN** a type `A` project has no active backend class
- **THEN** the Step `1.1` condition does not require §5 in any blueprint

#### Scenario: Lone backend with no peer produces no §5

- **WHEN** a type `A` project has exactly one active backend class and no other active class
- **THEN** the Step `1.1` condition does not require §5 in the backend blueprint
