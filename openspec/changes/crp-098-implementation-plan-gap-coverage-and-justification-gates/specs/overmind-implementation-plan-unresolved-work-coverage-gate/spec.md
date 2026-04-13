## ADDED Requirements

### Requirement: Unresolved technical-requirements work SHALL be covered by implementation steps
The implementation-plan quality helper SHALL fail when unresolved feature work recorded in `technical_requirements.md` is not represented by at least one implementation step in `implementation_plan.md`.

#### Scenario: Unresolved requirement gap is uncovered
- **WHEN** `technical_requirements.md` contains a `### Requirement:` block with remaining feature work
- **AND** no implementation step references that unresolved requirement through step-scoped technical evidence
- **THEN** the implementation-plan quality helper SHALL fail
- **AND** it SHALL report the uncovered requirement identifier deterministically

#### Scenario: Unresolved impacted component is uncovered
- **WHEN** `technical_requirements.md` contains a `### Component:` block with remaining feature work
- **AND** no implementation step references that unresolved component through step-scoped technical evidence
- **THEN** the implementation-plan quality helper SHALL fail
- **AND** it SHALL report the uncovered component identifier deterministically

### Requirement: Fully implemented technical items SHALL remain outside mandatory coverage
The helper SHALL exclude already completed requirement-gap and component entries from the mandatory unresolved-work coverage set unless the plan deliberately includes them as prerequisite-state context.

#### Scenario: Fully implemented requirement does not force a new step
- **WHEN** a `technical_requirements.md` requirement block indicates no remaining gap
- **THEN** the helper SHALL not require that requirement to appear in the mandatory unresolved-work coverage set

#### Scenario: Fully implemented component does not force a new step
- **WHEN** a `technical_requirements.md` component block indicates no remaining gap
- **THEN** the helper SHALL not require that component to appear in the mandatory unresolved-work coverage set
