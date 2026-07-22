## ADDED Requirements

### Requirement: Semantic review command SHALL produce a durable implementation-plan review artifact
The workflow SHALL provide a staged feature command that reviews `implementation_plan.md` semantically and writes `implementation_plan_semantic_review.md` under the selected feature root.

#### Scenario: Semantic review artifact is created for a valid feature path
- **WHEN** the staged semantic-review command runs against a valid feature root after Step `8`
- **THEN** it SHALL read `implementation_plan.md`, `requirements_ears.md`, and `technical_requirements.md`
- **AND** it SHALL write `implementation_plan_semantic_review.md` beside those feature artifacts

### Requirement: Semantic review SHALL focus on step-level cohesion and split quality
The semantic review SHALL evaluate implementation-plan steps for semantic cohesion and split quality rather than for basic structural validity alone.

#### Scenario: Review flags one step spanning unrelated requirements
- **WHEN** one implementation step groups unrelated behavior that should be split into separate work
- **THEN** the review artifact SHALL record a finding naming the affected step and the recommended split

#### Scenario: Review flags one step spanning separate technical gaps
- **WHEN** one implementation step combines multiple unrelated technical-requirements gaps without a real shared slice
- **THEN** the review artifact SHALL record a finding naming the affected step and the recommended restructuring

#### Scenario: Review accepts semantically coherent plan
- **WHEN** the implementation plan is semantically cohesive and no material split or ordering findings are discovered
- **THEN** the review artifact SHALL record `no_findings: true`
- **AND** SHALL set review completion metadata that indicates the semantic pass finished successfully

### Requirement: Semantic review artifact SHALL be helper-validated
The repository SHALL include a quality helper for `implementation_plan_semantic_review.md` so the staged command can prove the output artifact is structurally complete before the phase finishes.

#### Scenario: Review artifact passes helper validation
- **WHEN** the semantic-review artifact contains valid document metadata and either `no_findings: true` or one-or-more complete findings
- **THEN** the semantic-review quality helper SHALL exit successfully
