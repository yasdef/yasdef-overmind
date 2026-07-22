## ADDED Requirements

### Requirement: Update mode SHALL ensure required staged command scripts exist
When update mode is entered, the first-init-machine script SHALL ensure `asdlc/.commands/` contains the full staged command set required for local ASDLC project management:
- `project_setup_add_new_project.sh`
- `project_setup_update_project.sh`
- `init_progress_scanner.sh`
- `init_common_contract_definition.sh`

#### Scenario: Missing staged commands are restored
- **WHEN** update mode is entered
- **AND** one or more required staged command scripts are absent from `asdlc/.commands/`
- **THEN** the script SHALL create `asdlc/.commands/` if it is missing
- **AND** SHALL copy each absent required command script into `asdlc/.commands/`

### Requirement: Repaired staged commands SHALL preserve default ASDLC projects path wiring
Any command script restored during update mode SHALL be configured with the same default projects directory as fresh bootstrap output: `<selected_parent>/asdlc/projects`.

#### Scenario: Restored staged command uses asdlc projects as default
- **WHEN** the script backfills a missing staged command during update mode
- **THEN** the restored file SHALL contain default path configuration targeting `<selected_parent>/asdlc/projects`
- **AND** running the restored command without explicit override SHALL resolve project operations against that path

### Requirement: Update mode SHALL not overwrite already present staged command scripts
If a required staged command script already exists in `asdlc/.commands/`, update mode SHALL keep the existing file unchanged.

#### Scenario: Existing staged command is preserved
- **WHEN** update mode is entered
- **AND** `asdlc/.commands/project_setup_add_new_project.sh` already exists
- **THEN** the script SHALL not replace or rewrite that file
- **AND** SHALL only restore other required staged command scripts that are absent
