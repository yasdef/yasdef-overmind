## MODIFIED Requirements

### Requirement: Progress scanner SHALL support invocation-scoped product-root override
`overmind/scripts/project_mgmt/init_progress_scanner.sh` SHALL require `--path <feature-folder>` targeting a specific feature folder under `asdlc/projects/<project-id>`, SHALL infer the owning project root from that feature path, and SHALL use the selected feature folder as the active feature root while continuing to evaluate project-scoped checklist state from the inferred project root.

#### Scenario: Scanner requires explicit feature path
- **WHEN** `init_progress_scanner.sh` runs without `--path`
- **THEN** it SHALL exit non-zero
- **AND** it SHALL print an error describing the required `--path <path/to/feature>` argument

#### Scenario: Scanner rejects project-root input when feature folder is required
- **WHEN** `--path` resolves to an ASDLC project folder that contains `init_progress_definition.yaml` but does not select a feature subfolder
- **THEN** the scanner SHALL exit non-zero
- **AND** it SHALL report that `--path` must point to a feature-level folder inside the project

#### Scenario: Scanner rejects feature path outside ASDLC projects tree
- **WHEN** `--path` resolves outside `asdlc/projects/<project-id>`
- **THEN** the scanner SHALL exit non-zero
- **AND** it SHALL report that the selected feature path must belong to one ASDLC project

#### Scenario: Scanner infers project root from feature path and renders mixed-scope status
- **WHEN** `--path` points to a feature folder inside `asdlc/projects/<project-id>` and the project contains both project-scoped and feature-scoped checklist artifacts
- **THEN** the scanner SHALL read `<project>/init_progress_definition.yaml`
- **AND** it SHALL write `<project>/step_state.md`
- **AND** it SHALL evaluate project-level checklist artifacts from `<project>`
- **AND** it SHALL evaluate logical product-root checklist artifacts from the selected feature folder

### Requirement: Bootstrap Step 3 SHALL use overmind EARS artifact path
The bootstrap definition for Step 3 (`Convert Business Requirements Structuring to EARS`) SHALL require `requirements_ears_feature.md` using logical product-root checklist resolution so completion is evaluated inside the feature folder selected by scanner `--path`.

#### Scenario: Step 3 marked complete when selected feature folder contains EARS artifact and prefix is complete
- **WHEN** Steps 1 and 2 are complete, scanner runs with `--path <asdlc/projects/<project-id>/<feature-folder>>`, and `<feature-folder>/requirements_ears_feature.md` exists
- **THEN** Step 3 SHALL be rendered as `[x]`

#### Scenario: Step 3 remains incomplete when selected feature folder lacks EARS artifact
- **WHEN** Steps 1 and 2 are complete, scanner runs with `--path <asdlc/projects/<project-id>/<feature-folder>>`, and `requirements_ears_feature.md` does not exist in the selected feature folder
- **THEN** Step 3 SHALL be rendered as `[ ]`

#### Scenario: Step 3 does not use artifacts from a different feature folder
- **WHEN** Steps 1 and 2 are complete, scanner runs with `--path <asdlc/projects/<project-id>/feature-1>`, and `requirements_ears_feature.md` exists only under `<project>/feature-2`
- **THEN** Step 3 SHALL be rendered as `[ ]`
