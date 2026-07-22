## ADDED Requirements

### Requirement: Prerequisite derivation from EARS journeys
The system SHALL derive a deterministic list of named externally-invocable prerequisites for each EARS requirement by walking the user-reachable journey implied by that requirement's WHEN/THEN conditions.

#### Scenario: Prerequisites identified for a protected-route requirement
- **WHEN** a EARS requirement targets a protected page or route
- **THEN** the prerequisite trace SHALL list the sign-in or authentication entry point as a named prerequisite for that requirement

#### Scenario: Prerequisites identified for an admin-action requirement
- **WHEN** a EARS requirement describes an action reachable only after an operator navigates to an admin surface
- **THEN** the prerequisite trace SHALL list the admin surface entry point as a named prerequisite

#### Scenario: No prerequisites when requirement is self-contained
- **WHEN** a EARS requirement has no externally-invocable entry-point dependency outside of itself
- **THEN** the prerequisite trace SHALL record the requirement with an empty prerequisites list rather than fabricating entries

### Requirement: User-reachable presence detection
The system SHALL determine whether a named prerequisite is `present_in_repo` exclusively by checking the `user_reachable_surface` subfield in `technical_requirements.md`; transport-layer presence alone SHALL NOT satisfy the check.

#### Scenario: Transport-only entry does not satisfy presence
- **WHEN** `technical_requirements.md` records a component with a non-empty `transport_layer` subfield but a `none` or empty `user_reachable_surface` subfield
- **THEN** any prerequisite depending on that component SHALL be marked `present_in_repo: false` and SHALL NOT be recorded as `present_in_repo`

#### Scenario: User-reachable entry satisfies presence
- **WHEN** `technical_requirements.md` records a component with a non-empty `user_reachable_surface` subfield that matches the named prerequisite
- **THEN** that prerequisite SHALL be marked `status: present_in_repo` with the matching surface path as `evidence`

#### Scenario: Presence evidence value is required
- **WHEN** a prerequisite is assigned `status: present_in_repo`
- **THEN** the `evidence` field SHALL contain a non-empty path or identifier sourced from `user_reachable_surface`

### Requirement: Scope limited to externally-invocable prerequisites
The prerequisite trace SHALL only record prerequisites requiring a new externally-invocable surface per the CRP-108 class taxonomy: frontend navigable routes, pages, or screens; backend HTTP endpoints, CLI commands, scheduled jobs, or admin tools; mobile screens or deep links. Prerequisites that require only new internal functions, services, or repositories SHALL NOT appear in `prerequisite_gaps.md` and SHALL remain covered by CRP-098 `gap/TECH_REQ-*` and `comp/*` evidence tokens.

#### Scenario: Backend scheduled-job prerequisite is traced
- **WHEN** a backend EARS requirement references a daily reconciliation run
- **AND** no scheduled-job identifier appears in any `user_reachable_surface` entry
- **THEN** the prerequisite SHALL be recorded in `prerequisite_gaps.md` with `status: unmet`

#### Scenario: Backend HTTP endpoint prerequisite is traced
- **WHEN** a backend EARS requirement references a specific HTTP method+path (for example `POST /api/v2/orders`)
- **AND** that method+path is not present in `user_reachable_surface`
- **THEN** the prerequisite SHALL be recorded with `status: unmet`

#### Scenario: Internal service call is out of scope
- **WHEN** a requirement depends only on calling an internal service or repository with no externally-invocable surface change
- **THEN** that dependency SHALL NOT appear in `prerequisite_gaps.md` and SHALL remain covered by a `gap/TECH_REQ-*` or `comp/*` evidence token in the implementation plan

### Requirement: Literal surface references are traced
Every literal URL path, HTTP method+path pair, CLI command token, and scheduled-job identifier appearing in `requirements_ears.md` SHALL appear as either a prerequisite entry in `prerequisite_gaps.md` or as a `user_reachable_surface` entry in `technical_requirements.md`. `check_prerequisite_gaps_quality.sh` SHALL extract these literals and fail when any is missing from both sources.

#### Scenario: Missing literal fails the gate
- **WHEN** `requirements_ears.md` mentions the literal `/admin/login`
- **AND** `/admin/login` appears in neither `prerequisite_gaps.md` prerequisite entries nor any `user_reachable_surface` subfield in `technical_requirements.md`
- **THEN** `check_prerequisite_gaps_quality.sh` SHALL exit non-zero and SHALL name the missing literal and its source requirement

#### Scenario: Literal covered by user_reachable_surface passes
- **WHEN** a literal URL path in `requirements_ears.md` is present in at least one `user_reachable_surface` entry in `technical_requirements.md`
- **THEN** the literal-extraction check SHALL pass for that literal without requiring a matching entry in `prerequisite_gaps.md`

### Requirement: Unmet prerequisite gate
The system SHALL fail the prerequisite gap check when any entry in `prerequisite_gaps.md` carries `status: unmet`, and SHALL pass only when every prerequisite is either `present_in_repo` or `scheduled_in_slices`.

#### Scenario: Gate fails with one unmet prerequisite
- **WHEN** `prerequisite_gaps.md` contains at least one prerequisite with `status: unmet`
- **THEN** `check_prerequisite_gaps_quality.sh` SHALL exit with a non-zero status and SHALL print a quality gate failure message identifying the affected requirement and prerequisite name

#### Scenario: Gate passes when all prerequisites are resolved
- **WHEN** every prerequisite in `prerequisite_gaps.md` is either `present_in_repo` or `scheduled_in_slices`
- **THEN** `check_prerequisite_gaps_quality.sh` SHALL exit with status 0 and SHALL print `quality gate passed`

#### Scenario: Scheduled prerequisite requires a slice reference
- **WHEN** a prerequisite is assigned `status: scheduled_in_slices`
- **THEN** the `slice_ref` field SHALL contain a non-empty identifier that exactly matches a slice identifier used in `implementation_slices.md`
- **AND** the identifier SHALL be referenceable in plan steps as the evidence token `slice/<slice_ref>`
- **AND** the quality helper SHALL reject an empty or absent `slice_ref` or a `slice_ref` that does not resolve to an existing slice in `implementation_slices.md`
