## ADDED Requirements

### Requirement: Add-project flow SHALL create a project workspace folder under asdlc/projects
`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` SHALL create one new workspace directory under `asdlc/projects` per successful run.

The folder name SHALL follow `<normalized-project-name>-<epoch_milliseconds>` and SHALL equal the generated project id written to metadata.

#### Scenario: Project workspace is created with project-id-linked folder name
- **WHEN** user provides a valid project name and add-project succeeds
- **THEN** one folder SHALL be created under `asdlc/projects`
- **AND** its name SHALL include normalized project name plus the generated epoch-millisecond suffix

### Requirement: Add-project flow SHALL seed init_progress_definition.yaml in the new project folder
The add-project flow SHALL copy `asdlc/templates/init_progress_definition_TEMPLATE.yaml` into the new project folder as `init_progress_definition.yaml`.

#### Scenario: Project definition is seeded from local template
- **WHEN** add-project creates a new project workspace
- **THEN** `<project-folder>/init_progress_definition.yaml` SHALL exist
- **AND** its initial content SHALL be copied from `asdlc/templates/init_progress_definition_TEMPLATE.yaml`

### Requirement: Add-project flow SHALL fail fast when local ASDLC template is unavailable
The add-project flow SHALL require `asdlc/templates/init_progress_definition_TEMPLATE.yaml` and SHALL not create partial project artifacts if that template is missing.

#### Scenario: Missing template aborts project creation
- **WHEN** `asdlc/templates/init_progress_definition_TEMPLATE.yaml` does not exist
- **THEN** add-project SHALL exit non-zero
- **AND** SHALL print an actionable error indicating missing template path
