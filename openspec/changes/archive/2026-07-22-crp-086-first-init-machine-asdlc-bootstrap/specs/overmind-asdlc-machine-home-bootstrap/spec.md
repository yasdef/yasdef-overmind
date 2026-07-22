## ADDED Requirements

### Requirement: First-init-machine script SHALL collect and validate ASDLC home location
`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` SHALL prompt the user for the parent directory where the ASDLC workspace will be created and SHALL validate that the provided path is non-empty, resolvable/creatable, and writable before creating bootstrap artifacts.

#### Scenario: Valid target path is accepted
- **WHEN** the user provides a valid writable directory path
- **THEN** the script SHALL continue bootstrap flow using that path as ASDLC workspace parent

#### Scenario: Invalid target path is rejected
- **WHEN** the user provides an empty, non-creatable, or non-writable path
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an actionable validation error message

### Requirement: First-init-machine script SHALL fail fast when ASDLC workspace already exists
The script SHALL target `<selected_dir>/asdlc` as workspace root and SHALL fail fast if this directory already exists.

#### Scenario: Existing ASDLC root blocks bootstrap
- **WHEN** `<selected_dir>/asdlc` already exists
- **THEN** the script SHALL exit non-zero without modifying existing ASDLC files
- **AND** SHALL print a meaningful message explaining that ASDLC is already initialized

### Requirement: First-init-machine script SHALL create canonical ASDLC bootstrap structure
On successful bootstrap, the script SHALL create:
- `<selected_dir>/asdlc/`
- `<selected_dir>/asdlc/projects/`
- `<selected_dir>/asdlc/.commands/`

#### Scenario: Bootstrap directory structure is created
- **WHEN** validation succeeds and ASDLC root is absent
- **THEN** the script SHALL create `asdlc`, `asdlc/projects`, and `asdlc/.commands`

### Requirement: First-init-machine script SHALL create metadata YAML scaffold
The script SHALL create a simple YAML metadata file under ASDLC root with placeholders for:
- project name
- project artefacts subfolder
- project unique id
The project artefacts subfolder field SHALL document/encode that this path must be inside `asdlc`.

#### Scenario: Metadata scaffold includes required keys
- **WHEN** bootstrap completes successfully
- **THEN** metadata YAML SHALL exist under ASDLC root
- **AND** SHALL contain keys for project name, project artefacts subfolder, and project unique id
- **AND** SHALL express the constraint that artefacts subfolder is inside `asdlc`
