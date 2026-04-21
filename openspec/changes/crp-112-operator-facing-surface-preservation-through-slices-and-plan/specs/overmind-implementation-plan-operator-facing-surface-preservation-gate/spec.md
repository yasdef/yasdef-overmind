## ADDED Requirements

### Requirement: Implementation-plan quality gate SHALL require preserved operator-facing surface coverage
`check_implementation_plan_quality.sh` SHALL fail when upstream artifacts identify a required missing operator-facing surface and `implementation_plan.md` does not preserve that surface in at least one implementation step.

#### Scenario: Missing admin entry route absent from plan fails the gate
- **WHEN** upstream prerequisite evidence identifies a required missing admin entry route
- **AND** `implementation_plan.md` contains no implementation step that delivers that route or equivalent operator entry surface
- **THEN** `check_implementation_plan_quality.sh` SHALL exit non-zero
- **AND** SHALL report the uncovered preserved surface deterministically

#### Scenario: Explicit plan step for operator-facing lookup page passes
- **WHEN** upstream prerequisite evidence identifies a required missing operator-facing lookup page
- **AND** `implementation_plan.md` contains an implementation step that explicitly delivers that page
- **THEN** the operator-facing surface preservation portion of the plan quality gate SHALL pass for that surface

### Requirement: Supporting-only plan steps SHALL NOT satisfy preserved surface coverage
The implementation-plan quality gate SHALL reject coverage claims that reference only supporting API, auth, contract, state, or coordination work when the required operator-facing surface itself is not delivered by any plan step.

#### Scenario: API and auth steps do not satisfy missing login page
- **WHEN** a required missing login page exists upstream
- **AND** `implementation_plan.md` contains steps for auth middleware, token handling, backend login endpoint wiring, or shared contract updates
- **AND** no implementation step explicitly delivers the login page
- **THEN** `check_implementation_plan_quality.sh` SHALL fail the preserved-surface check

#### Scenario: Contract-first plan does not satisfy missing protected shell
- **WHEN** a required missing protected shell exists upstream
- **AND** the plan schedules contract, schema, or state scaffolding without any explicit protected-shell delivery step
- **THEN** the plan quality gate SHALL treat the protected shell as uncovered

### Requirement: Implementation-plan preservation check SHALL remain evidence-driven
The implementation-plan quality gate SHALL evaluate preserved operator-facing surface coverage from upstream evidence and prerequisite-gap meaning rather than from a brittle hardcoded route-name list or a framework-specific surface vocabulary.

#### Scenario: Equivalent operator surface wording is accepted in plan
- **WHEN** upstream evidence requires an operator-facing workspace shell
- **AND** the plan uses equivalent step wording such as admin workspace container or protected operator shell
- **THEN** the plan quality gate SHALL accept that step as coverage if it clearly delivers the same operator-facing surface

#### Scenario: No required operator-facing surface means no preservation failure
- **WHEN** upstream artifacts contain no required missing operator-facing surface for a requirement
- **THEN** `check_implementation_plan_quality.sh` SHALL NOT fail solely because the plan lacks a user-facing delivery step for that requirement
