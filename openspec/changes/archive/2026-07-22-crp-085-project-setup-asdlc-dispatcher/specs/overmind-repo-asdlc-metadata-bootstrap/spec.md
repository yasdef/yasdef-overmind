## MODIFIED Requirements

### Requirement: Repo ASDLC initializer SHALL persist canonical repo metadata
The repository SHALL persist canonical project metadata in `overmind/init_progress_definition.yaml` under top-level key `meta_info`, including `project_classes`, `project_type_code`, and `project_type_label`. This behavior SHALL be executed by the helper flow mapped to dispatcher option `2` (`add new project`), not directly by `overmind/scripts/project_mgmt/project_setup_asdlc.sh`.

#### Scenario: Add-new-project helper writes normalized repo metadata
- **WHEN** the user selects option `2` in `overmind/scripts/project_mgmt/project_setup_asdlc.sh` and completes valid inputs
- **THEN** `overmind/init_progress_definition.yaml` SHALL contain `meta_info.project_type_code`
- **AND** SHALL contain `meta_info.project_type_label`
- **AND** SHALL contain `meta_info.project_classes` as a YAML list

#### Scenario: Re-running add-new-project helper with same answers is deterministic
- **WHEN** the option `2` helper flow runs multiple times with identical project type and project-class selections
- **THEN** the persisted `meta_info` block SHALL be byte-identical across runs

### Requirement: Repo ASDLC initializer SHALL capture project type and one-or-more project classes interactively
The helper flow mapped to dispatcher option `2` (`add new project`) SHALL request project type with strict chooser semantics `choose: 1/2/3`, SHALL map selections to canonical `project_type_code` and `project_type_label`, and SHALL require one or more project-class selections normalized to `backend`, `frontend`, and `mobile`.

#### Scenario: Valid project type and multiple project classes are persisted through option 2
- **WHEN** a user selects valid project type `A`, `B`, or `C` and selects more than one supported project class within the option `2` helper flow
- **THEN** the helper SHALL persist the mapped project type code and label
- **AND** SHALL persist each selected class in normalized canonical form

#### Scenario: Invalid project-class selection is rejected through option 2
- **WHEN** project-class input contains unsupported values or resolves to an empty selection in the option `2` helper flow
- **THEN** the helper SHALL display validation guidance
- **AND** SHALL continue prompting until at least one valid class is provided
