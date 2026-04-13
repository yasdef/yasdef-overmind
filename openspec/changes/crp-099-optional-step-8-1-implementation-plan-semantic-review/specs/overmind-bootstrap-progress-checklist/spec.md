## ADDED Requirements

### Requirement: Progress checklist SHALL support optional feature Step 8.1 semantic review
The bootstrap definition and scanner contract SHALL support an optional Step `8.1` after implementation-plan generation for semantic review of `implementation_plan.md`.

#### Scenario: Optional Step 8.1 is rendered without blocking completion
- **WHEN** Step `8` is complete, Step `8.1` is declared with `optional: true`, and `implementation_plan_semantic_review.md` is missing
- **THEN** the scanner SHALL render Step `8.1` as incomplete
- **AND** SHALL continue to render later required steps, if any, without treating Step `8.1` as a blocking prerequisite

#### Scenario: Optional Step 8.1 is complete when semantic review artifact is ready
- **WHEN** Step `8.1` is declared with `optional: true` and `implementation_plan_semantic_review.md` exists at the selected feature root with the configured completion metadata
- **THEN** the scanner SHALL render Step `8.1` as complete
