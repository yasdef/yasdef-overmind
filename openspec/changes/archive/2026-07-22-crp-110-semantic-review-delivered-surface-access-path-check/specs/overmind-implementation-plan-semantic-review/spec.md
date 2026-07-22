## MODIFIED Requirements

### Requirement: Semantic review command SHALL produce a durable implementation-plan review artifact
The workflow SHALL provide a staged feature command that reviews `implementation_plan.md` semantically and writes `implementation_plan_semantic_review.md` under the selected feature root. The command SHALL read `requirements_ears.md` and `technical_requirements.md` and, when present for the active project classes and planning flow, SHALL also read `prerequisite_gaps.md` plus the applicable frontend, backend, and mobile surface-map artifacts so semantic findings can be grounded in inbound-reachability evidence.

#### Scenario: Semantic review artifact is created for a valid feature path
- **WHEN** the staged semantic-review command runs against a valid feature root after Step `8.3`
- **THEN** it SHALL read `implementation_plan.md`, `requirements_ears.md`, and `technical_requirements.md`
- **AND** it SHALL write `implementation_plan_semantic_review.md` beside those feature artifacts

#### Scenario: Semantic review consumes prerequisite gap output when present
- **WHEN** the selected feature root contains `prerequisite_gaps.md`
- **THEN** the staged semantic-review command SHALL include `prerequisite_gaps.md` in the review context before generating `implementation_plan_semantic_review.md`

#### Scenario: Semantic review consumes repo-class surface maps when present
- **WHEN** the selected feature root contains one or more active repo-class surface-map artifacts
- **THEN** the staged semantic-review command SHALL include the applicable surface-map artifacts in the review context before generating `implementation_plan_semantic_review.md`

### Requirement: Semantic review SHALL focus on step-level cohesion and split quality
The semantic review SHALL evaluate implementation-plan steps for semantic cohesion, split quality, and delivered-surface access-path clarity rather than for basic structural validity alone.

#### Scenario: Review flags one step spanning unrelated requirements
- **WHEN** one implementation step groups unrelated behavior that should be split into separate work
- **THEN** the review artifact SHALL record a finding naming the affected step and the recommended split

#### Scenario: Review flags one step spanning separate technical gaps
- **WHEN** one implementation step combines multiple unrelated technical-requirements gaps without a real shared slice
- **THEN** the review artifact SHALL record a finding naming the affected step and the recommended restructuring

#### Scenario: Review flags a delivered surface with unclear operator reachability
- **WHEN** one implementation step delivers a new user-reachable surface
- **AND** the applicable surface map shows no inbound affordance for that surface
- **AND** no sibling implementation step adds an inbound affordance
- **THEN** the review artifact SHALL record a `delivered_surface_consumption_unclear` finding naming the affected step and delivered surface
- **AND** SHALL present the finding as an operator reachability question that requires product-fit judgment

#### Scenario: Review does not flag a delivered surface when inbound access is covered
- **WHEN** a newly delivered user-reachable surface already has an existing inbound affordance or gains one through a sibling implementation step
- **THEN** the semantic review SHALL NOT emit `delivered_surface_consumption_unclear` solely for that surface

#### Scenario: Review accepts semantically coherent plan
- **WHEN** the implementation plan is semantically cohesive and no material split, ordering, or delivered-surface reachability findings are discovered
- **THEN** the review artifact SHALL record `no_findings: true`
- **AND** SHALL set review completion metadata that indicates the semantic pass finished successfully

### Requirement: Semantic review artifact SHALL be helper-validated
The repository SHALL include a quality helper for `implementation_plan_semantic_review.md` so the staged command can prove the output artifact is structurally complete before the phase finishes. The helper SHALL reject any terminal `delivered_surface_consumption_unclear` finding whose `resolution_notes` field is empty.

#### Scenario: Review artifact passes helper validation
- **WHEN** the semantic-review artifact contains valid document metadata and either `no_findings: true` or one-or-more complete findings
- **AND** every terminal `delivered_surface_consumption_unclear` finding includes non-empty `resolution_notes`
- **THEN** the semantic-review quality helper SHALL exit successfully

#### Scenario: Delivered-surface finding without resolution notes fails helper validation
- **WHEN** `implementation_plan_semantic_review.md` contains a terminal `delivered_surface_consumption_unclear` finding with empty `resolution_notes`
- **THEN** the semantic-review quality helper SHALL exit with a non-zero status
- **AND** SHALL print a validation failure identifying the finding type and missing `resolution_notes`
