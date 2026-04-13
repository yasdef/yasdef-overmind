## ADDED Requirements

### Requirement: Feature pipeline SHALL expose semantic review as optional Step 8.3
The feature pipeline SHALL define implementation-plan semantic review as optional Step `8.3`, positioned after Step `8.2` ordered shared-plan generation.

#### Scenario: Sequence definition places semantic review at Step 8.3
- **WHEN** the init-progress sequence is rendered for feature planning phases
- **THEN** semantic review SHALL be represented as optional Step `8.3`
- **AND** SHALL be placed after Step `8.2`

#### Scenario: Semantic review remains optional at Step 8.3
- **WHEN** Step `8.3` semantic review is not executed for a feature
- **THEN** required feature pipeline progress SHALL remain non-blocked by missing Step `8.3` output

### Requirement: Step 8.3 SHALL reuse existing semantic review input/output contract
Step `8.3` semantic review SHALL keep the existing semantic-review command contract and artifact contract while updating phase numbering references.

#### Scenario: Step 8.3 semantic review consumes existing planning artifacts
- **WHEN** the semantic-review phase executes at Step `8.3`
- **THEN** it SHALL read `implementation_plan.md`, `requirements_ears.md`, and `technical_requirements.md`
- **AND** SHALL write `implementation_plan_semantic_review.md` under the selected feature root

#### Scenario: Step 8.3 keeps existing staged command contract
- **WHEN** ASDLC staged commands are generated
- **THEN** the semantic-review command SHALL remain available as `.commands/feature_implementation_plan_semantic_review.sh`
- **AND** workflow docs SHALL refer to that command as the optional Step `8.3` phase
