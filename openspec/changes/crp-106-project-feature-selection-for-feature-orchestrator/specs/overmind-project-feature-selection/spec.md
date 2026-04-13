## ADDED Requirements

### Requirement: Project feature orchestrator SHALL discover resumable feature folders from project state
`overmind/scripts/project_mgmt/project_add_feature_e2e.sh` SHALL inspect the selected project folder for existing feature-folder candidates before deciding whether to scaffold a new feature or continue an existing one. The orchestrator SHALL classify each candidate by invoking the progress scanner for that feature path and reading the canonical final `next step` line.

#### Scenario: Direct child feature folders are evaluated for continuation
- **WHEN** the operator runs `project_add_feature_e2e.sh --path <project-folder-path>` and the project contains one or more direct child feature directories
- **THEN** the orchestrator SHALL evaluate those feature directories as continuation candidates before starting Step `3` scaffold

#### Scenario: Scanner-invalid or missing feature directories are ignored
- **WHEN** a project child directory cannot be validated as a feature-level target for `init_progress_scanner.sh --path <feature-path>`
- **THEN** the orchestrator SHALL exclude that directory from the continuation candidate set

#### Scenario: Stale saved feature path does not create a continuation candidate
- **WHEN** `.project_add_feature_e2e_state.env` points to a feature path that no longer exists or is no longer scanner-valid
- **THEN** the orchestrator SHALL ignore that cached path for project feature selection

### Requirement: Project feature orchestrator SHALL ask the operator to choose new or continue when unfinished features exist
If one or more unfinished feature folders exist under the selected project, `project_add_feature_e2e.sh` SHALL ask the operator whether to start a new feature or continue an existing unfinished feature before any feature-step execution begins.

#### Scenario: Unfinished features trigger project-level choice
- **WHEN** project feature discovery finds at least one feature whose scanner result ends with `next step: <number> (<name>)`
- **THEN** the orchestrator SHALL prompt the operator to choose between starting a new feature and continuing an existing unfinished feature

#### Scenario: No unfinished features skips continue choice
- **WHEN** project feature discovery finds no unfinished features
- **THEN** the orchestrator SHALL NOT offer continue selection
- **AND** it SHALL proceed with new-feature scaffold flow

### Requirement: Continue selection SHALL list only unfinished features with scanner-reported status
When the operator chooses to continue existing work, the orchestrator SHALL list only unfinished features for that project. Each listed feature SHALL include the feature path and the scanner-reported `next step` status used for resume classification.

#### Scenario: Continue list excludes completed features
- **WHEN** a discovered feature scanner result ends with `next step: none`
- **THEN** that feature SHALL NOT appear in the continue-selection list

#### Scenario: Continue list shows resumable next-step context
- **WHEN** a discovered feature scanner result ends with `next step: <number> (<name>)`
- **THEN** the continue-selection list SHALL show that feature together with the same `next step: <number> (<name>)` status

#### Scenario: Continue list ordering is deterministic
- **WHEN** multiple unfinished features exist under the same project
- **THEN** the orchestrator SHALL render the continue-selection list in deterministic order

### Requirement: Selected project feature SHALL become the active orchestration target
After project-level selection is complete, the selected feature SHALL become the active `FEATURE_PATH` for scanner-driven resume and downstream feature-step execution. The orchestrator MAY persist the selected feature path into `.project_add_feature_e2e_state.env` as a last-selected cache, but that cache SHALL NOT override future discovery or explicit operator selection.

#### Scenario: Continue selection activates chosen unfinished feature
- **WHEN** the operator selects one unfinished feature from the continue list
- **THEN** the orchestrator SHALL use that feature path as the active target for scanner-driven resume and all downstream `--feature_path` script invocations

#### Scenario: New-feature selection activates scaffold result
- **WHEN** the operator chooses to start a new feature
- **THEN** the orchestrator SHALL run Step `3` scaffold and SHALL use the scaffold-produced feature path as the active target for the remainder of the run

#### Scenario: Last-selected cache updates after explicit selection
- **WHEN** the operator chooses either continue or new-feature flow and an active feature path is resolved
- **THEN** the orchestrator SHALL update `.project_add_feature_e2e_state.env` to that resolved feature path only as a convenience cache
- **AND** future runs SHALL still perform project feature discovery before using it
