## MODIFIED Requirements

### Requirement: Coordinator planning artifacts are owned under overmind
The project SHALL treat `overmind/implementation_slices.md`, `overmind/implementation_plan.md`, and `overmind/reqirements_ears.md` as canonical coordinator artifacts, and coordinator workflows MUST resolve these files from `/overmind` paths first. Step `8.1` SHALL own generation of `implementation_slices.md`, and Step `8.2` SHALL consume that artifact to generate the final ordered `implementation_plan.md`.

#### Scenario: Step 8.1 writes canonical slices artifact
- **WHEN** the Step `8.1` slice-planning phase completes
- **THEN** it writes `implementation_slices.md` to the canonical `/overmind` planning path

#### Scenario: Step 8.2 resolves canonical planning inputs
- **WHEN** Step `8.2` prepares prompts or validates required planning inputs
- **THEN** it reads `implementation_slices.md`, `implementation_plan.md`, and `reqirements_ears.md` from `/overmind` canonical paths

#### Scenario: Legacy ai path is still present during migration
- **WHEN** legacy copies exist under `/ai`
- **THEN** `/overmind` paths remain the source of truth for coordinator behavior

### Requirement: Coordinator templates and golden examples are hosted under overmind
The project SHALL host templates and golden examples for coordinator-owned planning artifacts under `overmind/templates` and `overmind/golden_examples`, including Step `8.1` slice-planning assets and Step `8.2` ordered-plan assembly assets.

#### Scenario: Template lookup for implementation slices
- **WHEN** a script or contributor needs the implementation slices template or example
- **THEN** the resolved path is under `/overmind/templates` or `/overmind/golden_examples`

#### Scenario: Template lookup for implementation plan ordering assets
- **WHEN** a script or contributor needs the implementation plan ordering template or example
- **THEN** the resolved path is under `/overmind/templates` or `/overmind/golden_examples`

#### Scenario: Template lookup for requirements EARS
- **WHEN** a script or contributor needs the requirements EARS template or example
- **THEN** the resolved path is under `/overmind/templates` or `/overmind/golden_examples`
