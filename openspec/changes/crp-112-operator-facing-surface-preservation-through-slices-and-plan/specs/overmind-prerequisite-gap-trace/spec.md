## ADDED Requirements

### Requirement: Required missing operator-facing prerequisites SHALL remain identifiable for downstream preservation
`prerequisite_gaps.md` SHALL preserve a stable, named representation of each prerequisite that corresponds to a required missing `user_reachable_surface`, keeping those prerequisites distinguishable from transport-only or internal execution gaps so later planning phases can preserve the operator-facing surface deterministically.

#### Scenario: Missing login surface remains identifiable after prerequisite tracing
- **WHEN** `requirements_ears.md` requires an operator login surface
- **AND** the prerequisite trace determines that the login surface is missing
- **THEN** `prerequisite_gaps.md` SHALL record that prerequisite in a form that keeps the required operator-facing surface identifiable to downstream slice and plan generation

#### Scenario: Internal execution gap is not marked as preserved operator-facing surface
- **WHEN** a requirement also has unresolved internal execution work such as repository, state, service, or transport-only changes
- **THEN** `prerequisite_gaps.md` SHALL keep those concerns distinguishable from required missing operator-facing surfaces
- **AND** downstream preservation logic SHALL be able to avoid treating them as user-facing delivery work

#### Scenario: Scheduled prerequisite keeps stable surface identity
- **WHEN** a required missing operator-facing prerequisite moves from `status: unmet` to `status: scheduled_in_slices`
- **THEN** `prerequisite_gaps.md` SHALL retain the same named surface identity while adding the scheduling reference needed by downstream planning
