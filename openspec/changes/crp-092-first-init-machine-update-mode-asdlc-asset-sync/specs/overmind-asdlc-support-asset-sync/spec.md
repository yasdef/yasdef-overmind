## ADDED Requirements

### Requirement: Update mode SHALL refresh staged ASDLC support assets from repository sources
When update mode is entered for an initialized ASDLC home, `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` SHALL ensure `asdlc/.rules/`, `asdlc/.templates/`, `asdlc/.golden_examples/`, `asdlc/.helper/`, and `asdlc/.setup/` exist and SHALL refresh their managed files from the current repository sources, while excluding `overmind/golden_examples/step_state_GOLDEN_EXAMPLE.md` from staged `.golden_examples`.

#### Scenario: Missing support-asset directories are created and populated
- **WHEN** update mode is entered
- **AND** one or more staged support-asset directories are absent
- **THEN** the script SHALL create each missing target directory
- **AND** SHALL copy the current repository-owned files for that asset group into the new target directory, except `overmind/golden_examples/step_state_GOLDEN_EXAMPLE.md`

#### Scenario: Existing staged support asset is refreshed to current repo content
- **WHEN** update mode is entered
- **AND** a same-named staged file already exists under `asdlc/.rules/`, `asdlc/.templates/`, `asdlc/.golden_examples/`, `asdlc/.helper/`, or `asdlc/.setup/`
- **THEN** the script SHALL replace that staged file with the current content from the mapped repository source

#### Scenario: Excluded staged golden example is removed during update sync
- **WHEN** update mode synchronizes staged support assets
- **AND** `asdlc/.golden_examples/step_state_GOLDEN_EXAMPLE.md` exists from an older staging run
- **THEN** the script SHALL remove `asdlc/.golden_examples/step_state_GOLDEN_EXAMPLE.md`

### Requirement: Update mode SHALL keep compatibility template and helper permissions aligned
Support-asset synchronization during update mode SHALL also refresh `asdlc/templates/init_progress_definition_TEMPLATE.yaml` from the canonical template source and SHALL preserve executable permissions on staged helper scripts.

#### Scenario: Compatibility template is refreshed during update mode
- **WHEN** update mode synchronizes support assets
- **THEN** `asdlc/templates/init_progress_definition_TEMPLATE.yaml` SHALL match `overmind/templates/init_progress_definition_TEMPLATE.yaml`

#### Scenario: Refreshed helper script remains executable
- **WHEN** update mode refreshes a file under `asdlc/.helper/`
- **THEN** the refreshed staged file SHALL have executable permissions

### Requirement: Update mode SHALL limit refresh scope to managed support assets
While synchronizing staged support assets, update mode SHALL not rewrite ASDLC metadata, project workspaces, or already present staged command scripts beyond the existing missing-command repair behavior.

#### Scenario: Unrelated ASDLC workspace content is preserved during support-asset sync
- **WHEN** update mode synchronizes staged support assets
- **THEN** the script SHALL not overwrite `asdlc/asdlc_metadata.yaml`
- **AND** SHALL not remove or rewrite files under `asdlc/projects/`
- **AND** SHALL not replace an already present file under `asdlc/.commands/`
