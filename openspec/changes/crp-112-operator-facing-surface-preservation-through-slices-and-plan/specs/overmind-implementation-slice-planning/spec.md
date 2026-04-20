## ADDED Requirements

### Requirement: Step 8.1 SHALL preserve required missing operator-facing surfaces as explicit delivery slices
Step `8.1` SHALL preserve every required missing operator-facing surface identified by upstream prerequisite evidence in at least one explicit feature-delivery slice within `implementation_slices.md`.

#### Scenario: Missing login surface becomes a feature-delivery slice
- **WHEN** upstream prerequisite evidence identifies a required missing login surface
- **THEN** Step `8.1` SHALL create or retain at least one slice that explicitly delivers that login route, page, screen, or equivalent sign-in surface

#### Scenario: Missing protected shell remains explicit during slice decomposition
- **WHEN** Step `8.1` splits work for a required protected shell into thinner executable slices
- **THEN** at least one resulting slice SHALL still explicitly deliver the protected shell itself

### Requirement: Step 8.1 SHALL NOT replace preserved operator-facing surfaces with supporting-only slices
Step `8.1` MAY add supporting auth, API, state, contract, or coordination slices around a required missing operator-facing surface, but it SHALL NOT treat those supporting slices as fulfilling the surface-delivery obligation on their own.

#### Scenario: Auth and API slices do not replace login surface slice
- **WHEN** a missing login surface requires backend auth work and frontend API wiring
- **THEN** Step `8.1` MAY emit separate supporting slices for those concerns
- **AND** it SHALL still preserve an explicit login-surface delivery slice

#### Scenario: Coordination slice does not replace operator page slice
- **WHEN** Step `8.1` emits a coordination or contract-related slice for a feature
- **AND** a required missing operator-facing page also exists upstream
- **THEN** the coordination slice SHALL NOT count as the preserved delivery slice for that page

### Requirement: Step 8.1 preservation SHALL remain requirement-driven
Step `8.1` SHALL preserve operator-facing surfaces only when upstream requirement meaning and prerequisite evidence require them, and SHALL avoid fabricating extra user-facing work or forcing separate navigation-affordance work from this rule alone.

#### Scenario: No fabricated user-facing slice when surface is not required
- **WHEN** upstream artifacts contain no required missing operator-facing surface
- **THEN** Step `8.1` SHALL NOT invent a user-facing delivery slice solely because related transport or internal gaps exist

#### Scenario: Navigation affordance not forced by preservation rule alone
- **WHEN** Step `8.1` preserves a required missing operator-facing surface as a delivery slice
- **THEN** it SHALL not be required by this rule alone to emit a separate inbound navigation-affordance slice unless upstream requirements independently call for it
