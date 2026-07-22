## ADDED Requirements

### Requirement: First-init-machine flow SHALL stage repo-owned support assets into local ASDLC directories
`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` SHALL maintain these staging mappings for regular files owned by the repository:
- `overmind/rules/` -> `asdlc/.rules/`
- `overmind/templates/` -> `asdlc/.templates/`
- `overmind/golden_examples/` -> `asdlc/.golden_examples/` (excluding `step_state_GOLDEN_EXAMPLE.md`, which remains repo-only)
- `overmind/scripts/helper/` -> `asdlc/.helper/`
- `overmind/setup/` -> `asdlc/.setup/`

#### Scenario: Bootstrap creates staged support-asset directories and copies
- **WHEN** first-machine bootstrap completes successfully
- **THEN** `asdlc/.rules/`, `asdlc/.templates/`, `asdlc/.golden_examples/`, `asdlc/.helper/`, and `asdlc/.setup/` SHALL exist
- **AND** each regular file directly under the mapped source directories SHALL have a same-named staged copy in the corresponding ASDLC target directory except `overmind/golden_examples/step_state_GOLDEN_EXAMPLE.md`

### Requirement: Staged helper scripts SHALL remain executable in the local ASDLC workspace
Helper scripts copied from `overmind/scripts/helper/` into `asdlc/.helper/` SHALL preserve executable permissions so the staged workspace contains runnable shell helpers.

#### Scenario: Staged helper script is executable
- **WHEN** a helper shell script is copied into `asdlc/.helper/`
- **THEN** the staged file SHALL have executable permissions

### Requirement: First-init-machine flow SHALL preserve the existing visible template compatibility path
The flow SHALL continue to maintain `asdlc/templates/init_progress_definition_TEMPLATE.yaml` as a compatibility copy for current project-bootstrap behavior, even when the full template set is staged under `asdlc/.templates/`.

#### Scenario: Visible compatibility template remains available
- **WHEN** support-asset staging runs during bootstrap
- **THEN** `asdlc/templates/init_progress_definition_TEMPLATE.yaml` SHALL exist
- **AND** it SHALL match `overmind/templates/init_progress_definition_TEMPLATE.yaml`
