## ADDED Requirements

### Requirement: Project setup entrypoint SHALL present a fixed startup plan menu
`overmind/scripts/project_mgmt/project_setup_asdlc.sh` SHALL start by prompting exactly `what's the plan, boss?` and SHALL present exactly these numbered options:
1. `first init asdlc on this machine`
2. `add new project`
3. `update project`

#### Scenario: Dispatcher prompt and options are shown before execution
- **WHEN** the user runs `overmind/scripts/project_mgmt/project_setup_asdlc.sh`
- **THEN** the script SHALL print `what's the plan, boss?`
- **AND** SHALL print options `1. first init asdlc on this machine`, `2. add new project`, and `3. update project`
- **AND** SHALL wait for a numeric selection before invoking any helper flow

### Requirement: Project setup entrypoint SHALL dispatch to exactly one helper by user selection
The dispatcher SHALL route option `1` to helper script #1, option `2` to helper script #2, and option `3` to helper script #3. The dispatcher SHALL execute only the selected helper and SHALL exit with that helper's exit status.

#### Scenario: Option 2 runs add-new-project helper flow
- **WHEN** the user selects option `2`
- **THEN** `overmind/scripts/project_mgmt/project_setup_asdlc.sh` SHALL invoke helper script #2 for add-new-project
- **AND** SHALL not invoke helper #1 or helper #3 in the same run

#### Scenario: Option 1 and option 3 route to their dedicated helpers
- **WHEN** the user selects option `1` or option `3`
- **THEN** the dispatcher SHALL invoke the matching helper script for the selected option
- **AND** SHALL not execute any non-selected helper script

### Requirement: Project setup entrypoint SHALL fail fast on invalid selection
If the user provides an unsupported selection, the dispatcher SHALL exit non-zero and SHALL show actionable guidance indicating valid options are `1`, `2`, and `3`.

#### Scenario: Unsupported menu selection is rejected
- **WHEN** the user enters a value outside `1`, `2`, `3`
- **THEN** the script SHALL print an invalid-selection message with valid options
- **AND** SHALL exit with a non-zero status
