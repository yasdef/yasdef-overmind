## ADDED Requirements

### Requirement: Step 7 supports type A surface-map generation from blueprint fallback evidence
For project type `A`, Step `7` SHALL produce the applicable `project_surface_struct_resp_map_<class>.md` artifact for an active backend, frontend, or mobile class when either a ready class repository path or an approved `project_stack_blueprint_<class>.md` exists. If no ready class repository path is available, Step `7` SHALL require the active-class stack blueprint before model invocation.

#### Scenario: Type A backend surface map uses approved backend blueprint
- **WHEN** a type `A` project has backend active, no ready backend repo path, and `project_stack_blueprint_backend.md` exists
- **THEN** Step `7` can invoke the model to create `project_surface_struct_resp_map_backend.md`
- **AND** the prompt identifies `project_stack_blueprint_backend.md` as planned structural evidence

#### Scenario: Type A frontend surface map uses approved frontend blueprint
- **WHEN** a type `A` project has frontend active, no ready frontend repo path, and `project_stack_blueprint_frontend.md` exists
- **THEN** Step `7` can invoke the model to create `project_surface_struct_resp_map_frontend.md`
- **AND** the prompt identifies `project_stack_blueprint_frontend.md` as planned structural evidence

#### Scenario: Type A mobile surface map uses approved mobile blueprint
- **WHEN** a type `A` project has mobile active, no ready mobile repo path, and `project_stack_blueprint_mobile.md` exists
- **THEN** Step `7` can invoke the model to create `project_surface_struct_resp_map_mobile.md`
- **AND** the prompt identifies `project_stack_blueprint_mobile.md` as planned structural evidence

#### Scenario: Type A Step 7 blocks without repo or blueprint evidence
- **WHEN** a type `A` project has an active class with no ready class repository path and the matching `project_stack_blueprint_<class>.md` is missing
- **THEN** Step `7` fails before model invocation with a blocking message that names the missing blueprint

### Requirement: Step 7 prefers repo evidence over blueprint evidence for type A
For project type `A`, Step `7` SHALL use ready scannable repository evidence as the strongest evidence source for each surface-map row or field. When a ready scannable repository path exists for the target class, Step `7` MAY also bind the matching approved stack blueprint as planned fallback evidence for rows or fields that repository evidence does not resolve. Blueprint values SHALL NOT replace repository evidence for the same row or field.

#### Scenario: Type A repo evidence wins for materialized repo
- **WHEN** a type `A` project has a target class with `class_repo_paths.<class>.state` equal to `ready` and the configured path resolves to a directory
- **THEN** Step `7` uses the repository scan path for that target class
- **AND** Step `7` does not use stack blueprint values for rows or fields already resolved by repository evidence

#### Scenario: Type A partial repo uses blueprint for unresolved rows
- **WHEN** a type `A` project has a target class with a ready scannable repository path and an approved matching stack blueprint
- **AND** a feature touches one surface that repository evidence resolves and another surface that only the blueprint describes
- **THEN** the generated surface map uses repository evidence for the materialized surface
- **AND** it may use planned blueprint evidence for the unmaterialized surface

#### Scenario: Type A mixed project selects evidence per class
- **WHEN** a type `A` project has backend with a ready repo path and frontend without a ready repo path but with an approved frontend blueprint
- **THEN** a backend Step `7` run uses backend repo evidence
- **AND** a frontend Step `7` run uses frontend blueprint evidence

### Requirement: Type A surface-map rows use deterministic fallback values
For project type `A`, every relevant Section `3` layer block and Section `4` touched surface block in a generated surface map SHALL resolve structural fields from repo evidence when available, otherwise from blueprint evidence when available, otherwise from the literal `<to be defined during implementation>`. The model SHALL NOT invent concrete paths, components, transport entries, or user-reachable tokens that are absent from both repo and blueprint evidence.

#### Scenario: Row uses repo evidence first
- **WHEN** repository evidence identifies a concrete path, component, transport entry, or user-reachable token for a surface-map row
- **THEN** the generated row uses that repo evidence instead of a blueprint fallback for the same field

#### Scenario: Row uses blueprint evidence when repo evidence is absent
- **WHEN** no repository evidence is available for a type `A` row or field and the approved blueprint identifies a layer folder, archetype, or user-reachable pattern for that row or field
- **THEN** the generated row may cite that blueprint value as planned structural evidence

#### Scenario: Row uses placeholder when evidence is absent
- **WHEN** neither repository evidence nor blueprint evidence identifies a concrete value required by a row
- **THEN** the generated row uses the literal `<to be defined during implementation>` for that unresolved field

### Requirement: Type A surface-map output remains feature-scoped
For project type `A`, Step `7` SHALL combine `requirements_ears.md`, `feature_contract_delta.md`, `init_progress_definition.yaml`, and the selected structural evidence source to produce a feature-scoped surface map. The surface map SHALL NOT copy the full stack blueprint as a generic inventory unrelated to the feature.

#### Scenario: Blueprint layer not touched by feature remains not applicable
- **WHEN** a type `A` blueprint defines a layer but the feature requirements and contract delta do not touch that layer
- **THEN** Step `7` marks the related surface as `not_applicable` or limits the row to required template context rather than treating every blueprint layer as feature impact

#### Scenario: Feature contract delta drives touched surfaces
- **WHEN** `feature_contract_delta.md` describes an API response change for a type `A` backend feature
- **THEN** the generated backend surface map marks the API-related surface as applicable using repo-first or blueprint fallback evidence
