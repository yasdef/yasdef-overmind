## ADDED Requirements

### Requirement: Implementation steps SHALL carry step-level technical-evidence links
Shared implementation plans SHALL include a `#### Evidence:` line on every implementation step, using deterministic tokens derived from `technical_requirements.md`.

#### Scenario: Step includes evidence line
- **WHEN** `implementation_plan.md` contains an implementation step
- **THEN** that step SHALL include one `#### Evidence:` metadata line
- **AND** the value SHALL contain one-or-more comma-separated technical-evidence tokens

### Requirement: Evidence tokens SHALL reference deterministic technical-requirements entries
The `#### Evidence:` line SHALL allow only canonical token forms derived from `technical_requirements.md`:
- `gap/TECH_REQ-<n>` for unresolved `### Requirement: REQ-<n>` entries
- `comp/<component-slug>` for unresolved impacted-component entries

#### Scenario: Requirement-gap evidence token is allowed
- **WHEN** a plan step cites unresolved requirement-gap evidence from `technical_requirements.md`
- **THEN** its `#### Evidence:` line SHALL allow a token in the form `gap/TECH_REQ-<n>`

#### Scenario: Impacted-component evidence token is allowed
- **WHEN** a plan step cites unresolved component evidence from `technical_requirements.md`
- **THEN** its `#### Evidence:` line SHALL allow a token in the form `comp/<component-slug>`

### Requirement: Step justification SHALL require both behavioral and technical grounding
The implementation-plan quality helper SHALL fail when a plan step is not justified by both:
- functional-requirement links on the step heading from `requirements_ears.md`, and
- valid step-level technical-evidence links from `technical_requirements.md`.

#### Scenario: Step missing evidence line fails justification
- **WHEN** an implementation step has valid `REQ-*` or `NFR-*` heading links but omits `#### Evidence:`
- **THEN** the implementation-plan quality helper SHALL fail
- **AND** it SHALL identify the unsupported step deterministically

#### Scenario: Step references unknown evidence token
- **WHEN** an implementation step includes a `#### Evidence:` token that does not resolve to a known requirement-gap or impacted-component entry in `technical_requirements.md`
- **THEN** the implementation-plan quality helper SHALL fail
- **AND** it SHALL identify the invalid token deterministically
