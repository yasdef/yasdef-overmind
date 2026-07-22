## ADDED Requirements

### Requirement: Step 7 supports type A surface-map generation with blueprint always required
For project type `A`, Step `7` SHALL require an approved `project_stack_blueprint_<class>.md` at the project root for each active backend, frontend, or mobile class before model invocation. Step `7` SHALL fail with a hard error naming the missing blueprint if it is absent. When `class_repo_paths[<class>].path` also resolves to a scannable directory, Step `7` SHALL additionally bind that repo path as repository evidence.

#### Scenario: Type A backend surface map uses approved backend blueprint only
- **WHEN** a type `A` project has backend active, no ready backend repo path, and `project_stack_blueprint_backend.md` exists
- **THEN** Step `7` invokes the model to create `project_surface_struct_resp_map_backend.md`
- **AND** the prompt binds `project_stack_blueprint_backend.md` as planned structural evidence

#### Scenario: Type A frontend surface map uses approved frontend blueprint only
- **WHEN** a type `A` project has frontend active, no ready frontend repo path, and `project_stack_blueprint_frontend.md` exists
- **THEN** Step `7` invokes the model to create `project_surface_struct_resp_map_frontend.md`
- **AND** the prompt binds `project_stack_blueprint_frontend.md` as planned structural evidence

#### Scenario: Type A mobile surface map uses approved mobile blueprint only
- **WHEN** a type `A` project has mobile active, no ready mobile repo path, and `project_stack_blueprint_mobile.md` exists
- **THEN** Step `7` invokes the model to create `project_surface_struct_resp_map_mobile.md`
- **AND** the prompt binds `project_stack_blueprint_mobile.md` as planned structural evidence

#### Scenario: Type A Step 7 blocks when blueprint is missing
- **WHEN** a type `A` project has an active class and the matching `project_stack_blueprint_<class>.md` is absent from the project root
- **THEN** Step `7` fails before model invocation with a blocking message that names the missing blueprint file
- **AND** this failure applies regardless of whether a ready repo path exists

### Requirement: Step 7 binds both repo and blueprint for type A when repo is scannable
For project type `A`, when `class_repo_paths[<class>].path` resolves to a scannable directory, Step `7` SHALL bind both the repo path and the approved stack blueprint in the prompt. Repo evidence SHALL win per field in the model output. Blueprint values SHALL NOT replace repo evidence for the same field. One source per field; no mixing within a single §4 block.

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

### Requirement: Type A surface-map uses per-field resolution with §3 omission and §4 placeholder
For project type `A`, the generated surface map SHALL apply the following rules per artifact section:

- **§3 layer blocks**: enumerate only layers materialized in the repo or anticipated in the blueprint. Layers absent from both sources SHALL be omitted from §3. The model SHALL NOT create a §3 entry with placeholder values.
- **§4 `repo_paths`**: resolve as repo path → blueprint `folder_paths` tagged `(planned)` → literal `<to be defined during implementation>`.
- **§4 `transport_layer`**: resolve as repo-observed archetype → blueprint archetype → literal `<to be defined during implementation>`.
- **§4 `evidence`**: resolve as real repo path → blueprint section id → delta item id alone; always combined with `feature_contract_delta.md <item id>`. Prose-only evidence is invalid.
- **§4 `user_reachable_surface`**: union of contract delta tokens, repo-scanned tokens, and blueprint tokens that apply. No placeholder used here.
- The model SHALL NOT invent concrete paths, archetypes, or tokens absent from both repo and blueprint evidence.

#### Scenario: §3 layer is omitted when absent from both sources
- **WHEN** neither the repo nor the blueprint describes a layer
- **THEN** Step `7` produces no §3 block for that layer
- **AND** the model does not create a §3 entry with placeholder values

#### Scenario: §4 field uses repo path when available
- **WHEN** repository evidence identifies a concrete path or archetype for a §4 surface block field
- **THEN** the generated field uses that repo value; the blueprint value for the same field is not used

#### Scenario: §4 field uses blueprint value when repo evidence is absent
- **WHEN** no repository evidence resolves a §4 `repo_paths` or `transport_layer` field and the blueprint identifies a folder path or archetype for that surface
- **THEN** the generated field uses that blueprint value tagged `(planned)`

#### Scenario: §4 field uses placeholder when both sources are absent
- **WHEN** neither repository evidence nor blueprint evidence identifies a concrete value for a §4 `repo_paths` or `transport_layer` field
- **THEN** the generated field carries the literal `<to be defined during implementation>`

### Requirement: Type A surface-map output remains feature-scoped
For project type `A`, Step `7` SHALL combine `requirements_ears.md`, `feature_contract_delta.md`, `init_progress_definition.yaml`, and the selected structural evidence source to produce a feature-scoped surface map. The surface map SHALL NOT copy the full stack blueprint as a generic inventory unrelated to the feature.

#### Scenario: Blueprint layer not touched by feature remains not applicable
- **WHEN** a type `A` blueprint defines a layer but the feature requirements and contract delta do not touch that layer
- **THEN** Step `7` marks the related surface as `not_applicable` or limits the row to required template context rather than treating every blueprint layer as feature impact

#### Scenario: Feature contract delta drives touched surfaces
- **WHEN** `feature_contract_delta.md` describes an API response change for a type `A` backend feature
- **THEN** the generated backend surface map marks the API-related surface as applicable using repo-first or blueprint fallback evidence
