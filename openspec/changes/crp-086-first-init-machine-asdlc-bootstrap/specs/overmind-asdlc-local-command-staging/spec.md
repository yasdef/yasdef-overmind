## ADDED Requirements

### Requirement: First-init-machine script SHALL stage create/update project commands locally
`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` SHALL copy these source scripts into `<selected_dir>/asdlc/.commands`:
- `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
- `overmind/scripts/project_mgmt/project_setup_update_project.sh`

#### Scenario: Command scripts are copied into .commands
- **WHEN** ASDLC bootstrap succeeds
- **THEN** `asdlc/.commands/project_setup_add_new_project.sh` SHALL exist
- **AND** `asdlc/.commands/project_setup_update_project.sh` SHALL exist

### Requirement: Staged command scripts SHALL default to ASDLC projects directory
Staged command copies SHALL be configured to use `<selected_dir>/asdlc/projects` as default folder for project operations.

#### Scenario: Staged scripts point to asdlc/projects by default
- **WHEN** staged scripts are generated
- **THEN** each staged script SHALL contain default path configuration targeting `asdlc/projects`
- **AND** script execution without explicit override SHALL resolve to that default location

### Requirement: First-init-machine script SHALL generate quick-run usage guide
The bootstrap flow SHALL create `<selected_dir>/asdlc/quickrun.md` describing fast execution of staged create-project and update-project commands.

#### Scenario: quickrun.md includes both command entrypoints
- **WHEN** bootstrap completes
- **THEN** `asdlc/quickrun.md` SHALL exist
- **AND** SHALL document create-project command usage
- **AND** SHALL document update-project command usage
