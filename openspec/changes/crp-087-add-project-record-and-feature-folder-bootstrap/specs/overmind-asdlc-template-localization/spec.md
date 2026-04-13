## ADDED Requirements

### Requirement: First-init-machine bootstrap SHALL localize project definition template into ASDLC workspace
`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` SHALL create `asdlc/templates` and copy `init_progress_definition_TEMPLATE.yaml` into `asdlc/templates/init_progress_definition_TEMPLATE.yaml` during successful bootstrap.

#### Scenario: Local template is staged during bootstrap
- **WHEN** first-machine bootstrap completes successfully
- **THEN** `asdlc/templates/init_progress_definition_TEMPLATE.yaml` SHALL exist
- **AND** it SHALL be readable for subsequent add-project execution

### Requirement: Template localization SHALL preserve source template content
The localized template SHALL be a direct copy of the canonical template content used for project initialization.

#### Scenario: Localized template matches canonical template
- **WHEN** template localization runs in bootstrap
- **THEN** `asdlc/templates/init_progress_definition_TEMPLATE.yaml` SHALL match canonical template content at copy time

### Requirement: Bootstrap SHALL fail fast if canonical template source is missing
Machine bootstrap SHALL not complete silently when canonical `init_progress_definition_TEMPLATE.yaml` source cannot be found.

#### Scenario: Missing canonical template blocks bootstrap
- **WHEN** bootstrap cannot find source template file
- **THEN** bootstrap SHALL exit non-zero
- **AND** SHALL report the missing source template path
