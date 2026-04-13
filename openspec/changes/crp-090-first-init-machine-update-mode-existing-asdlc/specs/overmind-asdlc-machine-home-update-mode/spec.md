## ADDED Requirements

### Requirement: First-init-machine script SHALL switch to update mode for initialized ASDLC homes
`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` SHALL recognize update mode when the user-selected parent already contains both `asdlc/` and `asdlc/asdlc_metadata.yaml`.

#### Scenario: Existing ASDLC home with metadata triggers update mode
- **WHEN** the user provides a parent path where `asdlc/` already exists
- **AND** `asdlc/asdlc_metadata.yaml` exists
- **THEN** the script SHALL print `asdlc folder already exists, switch to update mode`
- **AND** SHALL continue without deleting or recreating the existing ASDLC root

### Requirement: First-init-machine script SHALL keep fail-fast behavior for ambiguous existing ASDLC roots
The script SHALL reject an existing `asdlc/` directory when `asdlc/asdlc_metadata.yaml` is absent because the workspace cannot be safely identified as initialized ASDLC state.

#### Scenario: Existing ASDLC folder without metadata is rejected
- **WHEN** the user provides a parent path where `asdlc/` already exists
- **AND** `asdlc/asdlc_metadata.yaml` does not exist
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print a meaningful error explaining that the existing ASDLC folder is missing required metadata

### Requirement: Update mode SHALL preserve existing ASDLC workspace content
When update mode is entered, the script SHALL leave existing metadata, project folders, templates, and already present staged commands in place unless repair of an absent required command is needed.

#### Scenario: Existing metadata is preserved during update mode
- **WHEN** update mode is entered for an initialized ASDLC home
- **THEN** the script SHALL not overwrite `asdlc/asdlc_metadata.yaml`
- **AND** SHALL not remove existing files under `asdlc/projects` or `asdlc/templates`
