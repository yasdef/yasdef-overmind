## ADDED Requirements

### Requirement: Required missing operator-facing surfaces SHALL be preserved through planning phases
When upstream requirement evidence shows that a required `user_reachable_surface` is missing, the planning pipeline SHALL preserve that missing surface as explicit delivery work through Step `8.1` slice generation and Step `8.3` implementation-plan generation until the surface is delivered.

#### Scenario: Missing login surface stays explicit from slices to plan
- **WHEN** `requirements_ears.md` requires an operator sign-in surface
- **AND** prerequisite analysis shows that the required login page or route is missing
- **THEN** Step `8.1` SHALL include at least one feature-delivery slice for that login surface
- **AND** Step `8.3` SHALL include at least one implementation-plan step that still delivers that login surface

#### Scenario: Supporting work may accompany but not replace the surface
- **WHEN** a required missing operator-facing surface also needs auth, API, state, contract, or coordination work
- **THEN** the planning pipeline MAY add those supporting work items
- **AND** it SHALL still preserve explicit delivery work for the operator-facing surface itself

#### Scenario: Already-present surface is not re-scheduled
- **WHEN** prerequisite analysis shows that the required operator-facing surface is already `present_in_repo`
- **THEN** the preservation rule SHALL treat that surface as already satisfied
- **AND** it SHALL NOT fabricate a new delivery slice or plan step solely to restate the existing surface

### Requirement: Preservation scope SHALL stay limited to required operator-facing surfaces
The preservation rule SHALL operate only on operator-facing surfaces that are required by upstream requirement meaning and proven missing by prerequisite analysis. It SHALL NOT fabricate user-facing work for transport-only gaps, internal execution gaps, or unrelated navigation choices.

#### Scenario: Internal gap does not trigger preserved user-facing work
- **WHEN** an upstream gap concerns only an internal repository, service, state transition, or transport-layer helper
- **AND** no required missing operator-facing surface is identified
- **THEN** the preservation rule SHALL NOT require a user-facing slice or plan step for that gap

#### Scenario: Navigation affordance remains out of scope
- **WHEN** a required missing operator-facing surface is preserved through slices and plan
- **THEN** the preservation rule SHALL require explicit delivery of that surface
- **AND** it SHALL NOT, by itself, require separate inbound navigation-affordance work unless upstream requirements independently demand it

#### Scenario: Framework-specific route names are not required
- **WHEN** the same required operator-facing behavior could be delivered as a page, screen, shell, route, or equivalent entry surface in different frameworks
- **THEN** the preservation rule SHALL rely on upstream requirement meaning and prerequisite evidence
- **AND** it SHALL NOT depend on one hardcoded route name or one UI framework vocabulary
