## ADDED Requirements

### Requirement: Implementation steps SHALL carry canonical step-level FR links
Shared implementation plans SHALL place one-or-more functional-requirement links on every `### Step ...` heading using the authoritative `REQ-*` / `NFR-*` ids from `requirements_ears.md`.

#### Scenario: Step heading includes requirement coverage links
- **WHEN** `implementation_plan.md` contains an implementation step
- **THEN** that step heading SHALL include at least one `REQ-*` or `NFR-*` id
- **AND** each referenced id SHALL exist in `requirements_ears.md`

### Requirement: Functional requirements SHALL be fully covered by implementation steps
The implementation-plan quality contract SHALL enforce two-way coverage between `requirements_ears.md` and `implementation_plan.md`: every step SHALL be backed by at least one functional requirement, and every functional requirement SHALL have at least one related step.

#### Scenario: Requirement without related step fails coverage
- **WHEN** a `REQ-*` or `NFR-*` id exists in `requirements_ears.md` but is not referenced by any step heading in `implementation_plan.md`
- **THEN** the implementation-plan quality helper SHALL fail
- **AND** it SHALL report the uncovered requirement id deterministically

#### Scenario: One requirement may span multiple steps
- **WHEN** a requirement needs implementation work across multiple repos or prerequisite slices
- **THEN** multiple implementation steps MAY reference the same requirement id
- **AND** that shared coverage SHALL satisfy the requirement-to-step traceability contract

#### Scenario: One step may cover multiple requirements
- **WHEN** a single implementation step truthfully closes behavior for multiple functional requirements
- **THEN** that step heading MAY reference multiple `REQ-*` or `NFR-*` ids
- **AND** each referenced id SHALL count toward requirement coverage
