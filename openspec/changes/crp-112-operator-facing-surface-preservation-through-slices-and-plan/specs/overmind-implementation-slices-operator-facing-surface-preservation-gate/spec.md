## ADDED Requirements

### Requirement: Implementation-slices quality gate SHALL require preserved operator-facing surface coverage
`check_implementation_slices_quality.sh` SHALL fail when upstream artifacts identify a required missing operator-facing surface and `implementation_slices.md` does not preserve that surface in at least one feature-delivery slice.

#### Scenario: Missing login surface absent from slices fails the gate
- **WHEN** upstream prerequisite evidence identifies a required missing login surface
- **AND** `implementation_slices.md` contains no slice that delivers the login route, page, screen, or equivalent sign-in surface
- **THEN** `check_implementation_slices_quality.sh` SHALL exit non-zero
- **AND** SHALL report the missing preserved surface deterministically

#### Scenario: Protected shell preserved by explicit feature-delivery slice passes
- **WHEN** upstream prerequisite evidence identifies a required missing protected shell
- **AND** `implementation_slices.md` contains a slice that explicitly delivers that shell
- **THEN** the operator-facing surface preservation portion of the slices quality gate SHALL pass for that surface

### Requirement: Supporting-only slices SHALL NOT satisfy preserved surface coverage
The implementation-slices quality gate SHALL reject coverage claims that reference only supporting scaffolding work when the required missing operator-facing surface itself is not scheduled.

#### Scenario: Auth scaffolding alone does not satisfy missing login surface
- **WHEN** a required missing login surface exists upstream
- **AND** `implementation_slices.md` contains slices for token refresh, auth middleware, API clients, or contract updates only
- **AND** no slice explicitly delivers the login surface itself
- **THEN** `check_implementation_slices_quality.sh` SHALL fail the preserved-surface check

#### Scenario: Coordination slice alone does not satisfy missing operator page
- **WHEN** a required missing operator-facing lookup page exists upstream
- **AND** `implementation_slices.md` contains only a coordination or contract-lock slice related to that feature
- **THEN** the slices quality gate SHALL treat the required page as uncovered

### Requirement: Implementation-slices preservation check SHALL remain evidence-driven
The implementation-slices quality gate SHALL evaluate preserved operator-facing surface coverage from upstream requirement evidence and prerequisite-gap meaning rather than from a brittle hardcoded route-name list.

#### Scenario: Equivalent surface wording is accepted
- **WHEN** upstream evidence describes a required operator-facing admin lookup surface
- **AND** `implementation_slices.md` preserves that work as an explicit slice using equivalent page or screen wording rather than one exact literal route string
- **THEN** the slices quality gate SHALL accept that slice as coverage for the required surface

#### Scenario: No required operator-facing surface means no preservation failure
- **WHEN** upstream artifacts contain no required missing operator-facing surface for a requirement
- **THEN** `check_implementation_slices_quality.sh` SHALL NOT fail solely because no user-facing slice appears for that requirement
