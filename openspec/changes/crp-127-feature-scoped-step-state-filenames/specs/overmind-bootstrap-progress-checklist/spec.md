## MODIFIED Requirements

### Requirement: Progress scanner SHALL support invocation-scoped product-root override
`overmind/scripts/project_mgmt/init_progress_scanner.sh` SHALL require `--path <feature-folder>` targeting a specific feature folder under `asdlc/projects/<project-id>`, SHALL infer the owning project root from that feature path, and SHALL use the selected feature folder as the active feature root while continuing to evaluate project-scoped checklist state from the inferred project root. For a successful scan, it SHALL persist the rendered checklist to `<project>/step_state_<feature-folder>.md`, where `<feature-folder>` is the basename of the selected feature folder, while continuing to evaluate logical product-root checklist artifacts from that selected feature folder.

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

#### Scenario: Scanner infers project root from feature path and persists feature-specific state
- **WHEN** `--path` points to a feature folder inside `asdlc/projects/<project-id>` and the project contains both project-scoped and feature-scoped checklist artifacts
- **THEN** the scanner SHALL read `<project>/init_progress_definition.yaml`
- **AND** it SHALL write `<project>/step_state_<feature-folder>.md`
- **AND** it SHALL NOT require or write a shared `<project>/step_state.md` for that scan
- **AND** it SHALL evaluate project-level checklist artifacts from `<project>`
- **AND** it SHALL evaluate logical product-root checklist artifacts from the selected feature folder

### Requirement: Scanner SHALL mirror rendered checklist output to stdout
For every successful scan run that renders checklist state, the scanner SHALL emit the same rendered checklist payload to terminal stdout while continuing to persist that payload to `<project>/step_state_<feature-folder>.md`. The stdout payload SHALL remain machine-consumable for project-level feature selection, including exactly one canonical final `next step` line for the selected feature context.

#### Scenario: Terminal output mirrors persisted checklist exactly
- **WHEN** `overmind/scripts/init_progress_scanner.sh` completes checklist rendering for one selected feature folder
- **THEN** stdout SHALL contain the full checklist payload
- **AND** the emitted stdout checklist payload SHALL be byte-identical to the content written to `<project>/step_state_<feature-folder>.md`

#### Scenario: Mirrored output includes canonical next-step line
- **WHEN** the scanner renders checklist state
- **THEN** stdout SHALL include the same final `next step` line that is persisted in `<project>/step_state_<feature-folder>.md`

#### Scenario: Project-level feature selection can classify one selected feature from stdout alone
- **WHEN** a project-level orchestrator runs the scanner for one selected feature folder
- **THEN** stdout SHALL contain exactly one final canonical status line for that scan
- **AND** that line SHALL be either `next step: none` or `next step: <number> (<name>)`

### Requirement: Scanner SHALL append canonical next-step line
`<project>/step_state_<feature-folder>.md` SHALL end with `next step: <number> (<name>)` for the first incomplete non-optional step after the last contiguous completed required steps, or `next step: none` when all required steps are complete.

#### Scenario: Incomplete required steps remain
- **WHEN** at least one required step is incomplete
- **THEN** the final line SHALL name the next sequential incomplete required step as `next step: <number> (<name>)`

#### Scenario: All required steps complete
- **WHEN** all required steps are complete
- **THEN** the final line SHALL be exactly `next step: none`

#### Scenario: Incomplete optional step does not replace next required step
- **WHEN** an optional step is incomplete and a later required step is the next required unfinished checkpoint
- **THEN** scanner SHALL keep reporting that next required unfinished checkpoint on the final `next step` line
- **AND** SHALL NOT report the optional step as the canonical `next step`

#### Scenario: Feature-specific state files do not overwrite each other
- **WHEN** the scanner runs once for `<project>/feature-alpha` and once for `<project>/feature-beta`
- **THEN** the project root SHALL contain both `step_state_feature-alpha.md` and `step_state_feature-beta.md`
- **AND** each file SHALL retain the checklist payload for its own selected feature context
