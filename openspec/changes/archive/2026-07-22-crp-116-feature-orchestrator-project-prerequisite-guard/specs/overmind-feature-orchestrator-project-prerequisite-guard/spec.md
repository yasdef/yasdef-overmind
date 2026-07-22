## ADDED Requirements

### Requirement: Feature orchestrator blocks earlier scanner steps with prerequisite guidance

The feature orchestrator SHALL inspect the parsed scanner `next step` result before mapping it to a feature phase. When the scanner reports a valid dotted numeric step id earlier than the orchestrator's first supported feature step `3`, the orchestrator SHALL stop with a nonzero exit and a message that identifies the scanner-reported step as an incomplete project prerequisite.

#### Scenario: Type A stack blueprint step blocks feature orchestration
- **WHEN** `project_add_feature_e2e.sh` receives scanner output `next step: 1.1 (Define Project Stack Blueprints For Active Classes)`
- **THEN** it exits nonzero before running any Step `4` or later feature scripts
- **AND** the output includes that project init is incomplete at step `1.1`
- **AND** the output includes `.commands/init_project_stack_blueprints.sh --path projects/<project-id>` guidance using the current project path

#### Scenario: Common contract step blocks feature orchestration
- **WHEN** `project_add_feature_e2e.sh` receives scanner output `next step: 2 (Create Cross-Repository Contract Definition For This Project)`
- **THEN** it exits nonzero before running any Step `4` or later feature scripts
- **AND** the output includes that project init is incomplete at step `2`
- **AND** the output includes `.commands/init_common_contract_definition.sh --path projects/<project-id>` guidance using the current project path

#### Scenario: Future earlier project step blocks with generic guidance
- **WHEN** `project_add_feature_e2e.sh` receives scanner output for a valid dotted numeric step earlier than `3` that does not have a known command hint
- **THEN** it exits nonzero before attempting feature phase mapping
- **AND** the output tells the operator to complete the scanner-reported project step before rerunning `project_add_feature_e2e.sh`

### Requirement: Feature orchestrator preserves supported scanner step routing

The feature orchestrator SHALL preserve existing routing behavior when scanner reports `none` or a step id greater than or equal to `3`. The project-prerequisite guard MUST NOT change scanner invocation, feature-path persistence, resume override parsing, or downstream feature script command arguments.

#### Scenario: Step 3 or later continues through existing phase mapping
- **WHEN** `project_add_feature_e2e.sh` receives scanner output `next step: 3 (Initialize and Enrich Business Requirements Structuring)` or any currently supported later step
- **THEN** it uses the existing scanner-step-to-phase mapping behavior
- **AND** it does not print the project-prerequisite failure message

#### Scenario: Scanner reports no remaining work
- **WHEN** `project_add_feature_e2e.sh` receives scanner output `next step: none`
- **THEN** it preserves the existing successful completion behavior
- **AND** it does not print the project-prerequisite failure message

#### Scenario: Unknown non-earlier scanner step keeps unmapped error behavior
- **WHEN** `project_add_feature_e2e.sh` receives scanner output for a step that is not earlier than `3` and cannot be mapped to a supported phase
- **THEN** it preserves the existing unmapped scanner-step error behavior
