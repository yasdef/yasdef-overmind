## ADDED Requirements

### Requirement: Feature pipeline SHALL stage optional Step 8.1 semantic review command
The repository SHALL stage `feature_implementation_plan_semantic_review.sh` into ASDLC workspaces as the canonical command for optional Step `8.1`.

#### Scenario: First-init staging includes Step 8.1 command
- **WHEN** first-machine ASDLC bootstrap stages feature commands
- **THEN** it SHALL include `asdlc/.commands/feature_implementation_plan_semantic_review.sh`
- **AND** it SHALL also stage the rule, template, golden example, helper, and model configuration assets required by that command

#### Scenario: Step 8.1 command uses feature-path runtime contract
- **WHEN** the staged Step `8.1` command runs
- **THEN** it SHALL require `--feature_path <asdlc/projects/<project-id>/<feature-folder>>`
- **AND** it SHALL operate against the selected feature root using staged `.rules`, `.templates`, `.golden_examples`, `.helper`, and `.setup` assets

### Requirement: Step 8.1 phase SHALL follow Step 8 inputs and outputs
Optional Step `8.1` SHALL run only after implementation-plan generation and SHALL use the generated planning artifacts as its review inputs.

#### Scenario: Step 8.1 reads Step 8 outputs
- **WHEN** optional semantic review is executed for a feature
- **THEN** it SHALL require `implementation_plan.md`, `requirements_ears.md`, and `technical_requirements.md`
- **AND** it SHALL treat `implementation_plan_semantic_review.md` as the output artifact for that phase
