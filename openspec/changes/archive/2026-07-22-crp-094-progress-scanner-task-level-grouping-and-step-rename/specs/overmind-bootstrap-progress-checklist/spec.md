## MODIFIED Requirements

### Requirement: Scanner output SHALL be deterministic and model-friendly
The scanner SHALL generate `overmind/step_state.md` with one checklist line per step in declared order using `[x]` for complete and `[ ]` for incomplete states. The rendered checklist SHALL include visible section headings that group project-phase steps separately from feature-phase steps.

#### Scenario: Checklist uses stable ordered rendering
- **WHEN** scanner runs multiple times with unchanged repository state
- **THEN** `overmind/step_state.md` content SHALL be byte-identical across runs

#### Scenario: Checklist line format is canonical
- **WHEN** any step is rendered
- **THEN** each step line SHALL use exactly one checkbox marker (`[x]` or `[ ]`) and include step number and step name

#### Scenario: Project and feature phases are rendered as explicit sections
- **WHEN** the scanner renders checklist state from a definition that includes project-phase and feature-phase steps
- **THEN** steps with `phase_name: "init"` SHALL appear under `---- PROJECT LEVEL TASKS ----`
- **AND** steps with `phase_name: "feature"` SHALL appear under `--- FEATURE LEVEL TASKS <name-of-feature> ---`

#### Scenario: Feature heading uses active feature title when available
- **WHEN** the active feature root contains `feature_br_summary.md` with populated `feature_title` in `## 1. Document Meta`
- **THEN** the feature-phase section heading SHALL include that `feature_title`

#### Scenario: Feature heading falls back deterministically when title is unavailable
- **WHEN** the scanner cannot resolve a populated `feature_title` from the active feature root
- **THEN** the feature-phase section heading SHALL still be rendered using a deterministic fallback label

