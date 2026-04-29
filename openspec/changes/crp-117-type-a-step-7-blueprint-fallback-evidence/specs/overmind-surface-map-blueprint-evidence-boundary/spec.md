## ADDED Requirements

### Requirement: Blueprint evidence is Step 7 only for type A
Step `7` SHALL treat `project_stack_blueprint_<class>.md` as a read-only planned structural evidence source only for project type `A`. Step `7` SHALL NOT use stack blueprints as evidence for project types `B` or `C`.

#### Scenario: Type B ignores stack blueprint files
- **WHEN** Step `7` runs for a type `B` project and a stack blueprint file happens to exist
- **THEN** Step `7` follows the existing repository-backed type `B` behavior
- **AND** the prompt does not bind the stack blueprint as evidence

#### Scenario: Type C ignores stack blueprint files
- **WHEN** Step `7` runs for a type `C` project and a stack blueprint file happens to exist
- **THEN** Step `7` follows the existing repository-backed type `C` behavior
- **AND** the prompt does not bind the stack blueprint as evidence

### Requirement: Step 7 labels blueprint citations as planned structural evidence
When Step `7` uses a stack blueprint for type `A`, the prompt and rule SHALL label blueprint-derived citations as planned structural evidence. They SHALL NOT describe blueprint-derived values as repository-proven code evidence.

#### Scenario: Prompt distinguishes planned evidence
- **WHEN** Step `7` builds a type `A` prompt using `project_stack_blueprint_backend.md`
- **THEN** the prompt states that blueprint values are planned structural evidence
- **AND** it preserves repository evidence as stronger evidence when present

#### Scenario: Rule prevents repository-proof wording for blueprint values
- **WHEN** the Step `7` rule describes type `A` blueprint fallback
- **THEN** it forbids presenting blueprint-only paths, components, or user-reachable patterns as already existing repository code

### Requirement: Downstream planning steps consume surface maps instead of blueprints
Steps `8`, `8.1`, `8.2`, and `8.3` SHALL continue to consume the generated `project_surface_struct_resp_map_<class>.md` artifacts. They SHALL NOT read `project_stack_blueprint_<class>.md` directly as a substitute for Step `7`.

#### Scenario: Step 8 receives generated surface maps
- **WHEN** Step `8` runs after type `A` Step `7`
- **THEN** Step `8` uses the applicable `project_surface_struct_resp_map_<class>.md` artifacts as its execution-context inputs
- **AND** Step `8` does not require direct stack blueprint inputs

#### Scenario: Slice and plan steps stay surface-map based
- **WHEN** Steps `8.1`, `8.2`, and `8.3` run for a feature with type `A` surface maps
- **THEN** those steps use `technical_requirements.md`, `implementation_slices.md`, `prerequisite_gaps.md`, and surface-map-derived evidence according to their existing contracts
- **AND** they do not bypass Step `7` by reading stack blueprints directly

### Requirement: Init progress wording reflects repo, blueprint, and placeholder evidence
The init progress definition and related workflow documentation SHALL describe Step `7` type `A` completion in terms of repo evidence when available, blueprint fallback evidence when repo evidence is absent, and `<to be defined during implementation>` placeholders when neither evidence source resolves a row.

#### Scenario: Step 7 conditions name blueprint fallback
- **WHEN** `init_progress_definition_TEMPLATE.yaml` is inspected
- **THEN** Step `7` completion conditions describe type `A` blueprint fallback evidence for active backend, frontend, and mobile classes

#### Scenario: Sequence diagram does not mention obsolete MCP-only Step 7
- **WHEN** `init_progress_definition_sequence_diagram.md` is inspected
- **THEN** the Step `7` type `A` lane no longer presents MCP as the only source for surface-map generation
