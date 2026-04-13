## ADDED Requirements

### Requirement: Feature orchestrator SHALL start from project path and initialize feature scaffold
The workflow SHALL provide `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` that requires `--path <project-folder-path>` and begins at Step `3` by running `overmind/scripts/feature_br_scaffold.sh --path <project-folder-path>` when no saved feature context exists for the run.

#### Scenario: Run fails when project path is missing
- **WHEN** the operator runs `project_add_feature_e2e.sh` without `--path`
- **THEN** the orchestrator SHALL exit non-zero
- **AND** SHALL emit a deterministic missing-argument error for `--path <project-folder-path>`

#### Scenario: First run initializes scaffold before feature-only scripts
- **WHEN** no saved feature context exists and orchestrator starts with valid `--path`
- **THEN** it SHALL run Step `3` (`feature_br_scaffold.sh --path <project-folder-path>`) before any `--feature_path` scripts are invoked

### Requirement: Orchestrator SHALL capture and persist scaffold-created feature path
After scaffold initialization, orchestrator SHALL capture the created feature path from deterministic scaffold output and persist it as orchestrator state for downstream execution and resume runs.

#### Scenario: Scaffold output yields saved feature path
- **WHEN** `feature_br_scaffold.sh` outputs `Created feature folder: <feature_path>`
- **THEN** orchestrator SHALL store that `<feature_path>` as the active feature context for the run

#### Scenario: Resume run reuses persisted feature path
- **WHEN** orchestrator is started later for the same project path and saved feature context exists
- **THEN** it SHALL reuse the saved `feature_path` without re-running scaffold unless explicitly reset by operator intent

### Requirement: Orchestrator SHALL execute downstream scripts with saved feature path
All feature-phase scripts after scaffold SHALL be invoked using the saved `--feature_path` value.

#### Scenario: Step 4.1 and 4.2 scripts receive saved feature path
- **WHEN** orchestrator executes Step `4.1` and Step `4.2`
- **THEN** it SHALL call `feature_scan_repo_for_br.sh`, `feature_task_to_br.sh`, `feature_user_br_clarification.sh`, and `feature_br_check_ears_readiness.sh` with `--feature_path <saved-feature-path>`

#### Scenario: Downstream EARS and planning scripts receive saved feature path
- **WHEN** orchestrator executes phases after BR structuring
- **THEN** it SHALL invoke all downstream feature scripts through Step `8.3` with `--feature_path <saved-feature-path>`

### Requirement: Feature orchestrator SHALL enforce explicit bounded step map and Step 4 split
The orchestrator phase map SHALL begin at Step `3` scaffold initialization and continue only through optional Step `8.3`. Step `4` SHALL be explicitly split as:
- Step `3`: `feature_br_scaffold.sh --path <project-folder-path>`.
- Step `4.1`: `feature_scan_repo_for_br.sh` then `feature_task_to_br.sh`.
- Step `4.2`: `feature_user_br_clarification.sh` then `feature_br_check_ears_readiness.sh`.

#### Scenario: Orchestrator does not execute scripts outside bounded range
- **WHEN** `project_add_feature_e2e.sh` runs with valid arguments
- **THEN** it SHALL execute only configured scripts from Step `3` through Step `8.3`
- **AND** SHALL NOT invoke non-feature/project setup scripts outside that range

#### Scenario: Split Step 4.1 and Step 4.2 script mapping is deterministic
- **WHEN** orchestrator resolves its configured phase map
- **THEN** Step `4.1` SHALL run `feature_scan_repo_for_br.sh` before `feature_task_to_br.sh`
- **AND** Step `4.2` SHALL run `feature_user_br_clarification.sh` before `feature_br_check_ears_readiness.sh`

### Requirement: Orchestrator SHALL run progress scanner with resolved feature path and show current status
Once `feature_path` is resolved, `project_add_feature_e2e.sh` SHALL invoke `overmind/scripts/project_mgmt/init_progress_scanner.sh --path <feature_path>` before selecting execution start and SHALL show the rendered checklist status to the operator.

#### Scenario: Scanner is called before resumed or continued execution
- **WHEN** orchestrator has a resolved active `feature_path`
- **THEN** it SHALL run `init_progress_scanner.sh --path <feature_path>` before phase prompts begin

#### Scenario: Scanner output is visible before execution prompts
- **WHEN** scanner invocation succeeds
- **THEN** the orchestrator SHALL display current checklist status including the canonical `next step` line before prompting phase execution

### Requirement: Orchestrator SHALL support default resume and explicit step override
By default, `project_add_feature_e2e.sh` SHALL resume from the first unfinished required step resolved from scanner state for the active `feature_path`. When `--resume <step>` is provided, orchestrator SHALL start from that explicit step anchor instead.

#### Scenario: Default resume starts at first unfinished required step
- **WHEN** active feature has completed earlier required steps and scanner reports a later required next step
- **THEN** orchestrator SHALL begin from that reported required step

#### Scenario: Explicit resume overrides scanner-derived start
- **WHEN** operator passes `--resume <step>` and the step is valid in orchestrator phase map
- **THEN** orchestrator SHALL start from the requested step instead of scanner-derived next step

#### Scenario: Explicit resume fails for unknown step
- **WHEN** operator passes `--resume <step>` that does not map to any orchestrated step
- **THEN** orchestrator SHALL exit non-zero with a deterministic unsupported-step error

### Requirement: Orchestrator SHALL gate each script with interactive confirmation
Before running each script command in the orchestrated flow, `project_add_feature_e2e.sh` SHALL ask for explicit user confirmation.

#### Scenario: Confirmed script is executed
- **WHEN** operator confirms execution for a prompted script
- **THEN** orchestrator SHALL execute that script with resolved run context

#### Scenario: Confirmation prompt repeats on invalid answer
- **WHEN** operator provides non-yes/no confirmation input
- **THEN** orchestrator SHALL keep prompting with deterministic validation guidance until a valid response is provided

### Requirement: Decline handling SHALL depend on step optionality
If the operator declines execution at a confirmation prompt, orchestrator behavior SHALL depend on step optionality.

#### Scenario: Decline on required step stops run
- **WHEN** a declined script belongs to a required step
- **THEN** orchestrator SHALL stop immediately and emit a deterministic terminal stop reason

#### Scenario: Decline on optional step skips to next required step
- **WHEN** a declined script belongs to an optional step and a later required step exists
- **THEN** orchestrator SHALL skip the optional step and continue from the next required step

#### Scenario: Decline on trailing optional step ends successfully
- **WHEN** a declined script belongs to an optional step and no later required steps remain
- **THEN** orchestrator SHALL finish the run successfully without further script prompts

### Requirement: Multi-script phases SHALL run one-by-one with deterministic pre-run messages
For any step represented by multiple scripts, orchestrator SHALL run scripts in declared order and SHALL print deterministic pre-run context identifying phase and script position before confirmation.

#### Scenario: Multi-script phase executes in configured order
- **WHEN** a step maps to multiple scripts
- **THEN** orchestrator SHALL execute script `1..N` sequentially in configured order

#### Scenario: Pre-run message identifies phase and script index
- **WHEN** orchestrator is about to prompt for a script inside a multi-script phase
- **THEN** it SHALL display a message including phase id, script path, and `current/total` script position
