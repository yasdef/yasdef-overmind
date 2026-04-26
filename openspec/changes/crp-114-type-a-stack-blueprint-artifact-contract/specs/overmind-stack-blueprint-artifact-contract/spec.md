## ADDED Requirements

### Requirement: Per-class stack blueprint templates
Overmind SHALL provide stack blueprint templates for backend, frontend, and mobile project classes at `overmind/templates/project_stack_blueprint_be_TEMPLATE.md`, `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md`, and `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md`.

#### Scenario: Templates exist for all supported classes
- **WHEN** the project stack blueprint contract is installed
- **THEN** backend, frontend, and mobile blueprint template files exist under `overmind/templates/`

#### Scenario: Templates are class-specific
- **WHEN** a practitioner opens a stack blueprint template
- **THEN** the template identifies the target class and contains only sections applicable to that class taxonomy

### Requirement: Templates define structure only
Stack blueprint templates SHALL define section layout, required headings, required field names, and placeholders/comments only. Templates SHALL NOT contain project-specific values, default stack choices, workflow state, approval state, or behavioral rules.

#### Scenario: Template contains placeholders not project values
- **WHEN** a practitioner opens a stack blueprint template
- **THEN** project-specific fields such as repo name, service name, planned repo path, package/root, stack choices, and baseline tokens are placeholders rather than concrete project values

#### Scenario: Template does not encode workflow state
- **WHEN** a practitioner opens a stack blueprint template
- **THEN** the template does not include proposal source, approval status, or other authoring-flow state fields

#### Scenario: Template does not define behavior rules
- **WHEN** a practitioner opens a stack blueprint template
- **THEN** behavioral constraints are not embedded in the template and remain owned by `project_stack_blueprint_rule.md`

### Requirement: Blueprint sections are fixed
Each stack blueprint template SHALL define exactly four required top-level sections: `## 1. Meta`, `## 2. Stack Choices`, `## 3. Layer Bindings`, and `## 4. Baseline User-Reachable Inventory`.

#### Scenario: Required sections are present
- **WHEN** a stack blueprint is authored from a template
- **THEN** it contains all four required top-level sections in order

#### Scenario: Parallel behavioral sections are not introduced
- **WHEN** a stack blueprint describes structural conventions
- **THEN** it does not add feature work, implementation slices, implementation-plan tasks, or API contract schema governance sections

### Requirement: Meta section captures durable artifact identity
The blueprint meta section SHALL include class, repo name, service name, planned repo path, class package/root metadata, and last updated date. Backend blueprints SHALL include a backend package root field such as `group_id`; frontend and mobile blueprints SHALL include a package/root field such as `group_id_or_package_root`.

#### Scenario: Backend meta identifies package root
- **WHEN** a backend blueprint is authored
- **THEN** `## 1. Meta` contains `class: backend`, repo/service identity, planned repo path, `group_id`, and last updated date

#### Scenario: Frontend meta identifies source root
- **WHEN** a frontend blueprint is authored
- **THEN** `## 1. Meta` contains `class: frontend`, repo/service identity, planned repo path, `group_id_or_package_root`, and last updated date

#### Scenario: Mobile meta identifies source root
- **WHEN** a mobile blueprint is authored
- **THEN** `## 1. Meta` contains `class: mobile`, repo/service identity, planned repo path, `group_id_or_package_root`, and last updated date

#### Scenario: Planned repo path is not treated as scanned evidence
- **WHEN** a type `A` blueprint records `planned_repo_path`
- **THEN** the value identifies the intended repository location without implying that a repository was scanned

#### Scenario: Last updated is date shaped
- **WHEN** a blueprint is authored or revised
- **THEN** `last_updated` is recorded in `YYYY-MM-DD` format

### Requirement: Stack choices describe stable project conventions
The stack choices section SHALL capture stable class-level stack choices needed by later planning phases, including runtime/framework, build or packaging tool, data or state approach, integration approach, HTTP client approach, auth model, observability where applicable, health endpoint where applicable, deployment target, and test stack. A category with no applicable technology SHALL use literal `none` rather than prose omission.

#### Scenario: Backend stack choices are populated
- **WHEN** a backend blueprint is complete
- **THEN** `## 2. Stack Choices` contains populated backend stack categories such as language/runtime, framework, build tool, datastore, migrations, messaging, HTTP clients, auth, observability, health endpoint, deployment, and test stack

#### Scenario: Frontend stack choices are populated
- **WHEN** a frontend blueprint is complete
- **THEN** `## 2. Stack Choices` contains populated frontend stack categories such as framework, router, state/data, HTTP client, styling, auth client, environment validation, deployment, and test stack

#### Scenario: Mobile stack choices are populated
- **WHEN** a mobile blueprint is complete
- **THEN** `## 2. Stack Choices` contains populated mobile stack categories such as framework, navigation, state/data, HTTP client, auth client, device integration approach, distribution target, and test stack

### Requirement: Layer bindings match the surface-map taxonomy
The layer bindings section SHALL contain one block for every standard layer expected by the matching per-class surface-map template. Each layer block SHALL include `folder_paths`, `archetypes`, and `user_reachable_pattern`, using literal `none` when a layer has no operator-reachable pattern.

#### Scenario: Backend layer bindings match backend surface map
- **WHEN** a backend blueprint is complete
- **THEN** `## 3. Layer Bindings` contains backend API, service, domain, persistence, integration, runtime/ops, and test layer blocks

#### Scenario: Frontend layer bindings match frontend surface map
- **WHEN** a frontend blueprint is complete
- **THEN** `## 3. Layer Bindings` contains UI composition, component, state/data, API integration, UX behavior, platform/runtime, and test layer blocks

#### Scenario: Mobile layer bindings include mobile-specific surfaces
- **WHEN** a mobile blueprint is complete
- **THEN** `## 3. Layer Bindings` contains the shared frontend/mobile layer blocks and mobile-specific native/device and local/offline/sync layer blocks

### Requirement: Baseline user-reachable inventory is token-based
The baseline user-reachable inventory SHALL contain concrete operator-invocable tokens or literal `none`. Valid tokens include route paths, HTTP method plus path, CLI command names, scheduled job identifiers, mobile screen names, or deep links. Prose descriptions SHALL NOT be used.

#### Scenario: Inventory with existing baseline tokens
- **WHEN** a project has planned baseline operator-reachable entries
- **THEN** `## 4. Baseline User-Reachable Inventory` lists each entry as a concrete token

#### Scenario: Inventory with no baseline tokens
- **WHEN** a project has no planned baseline operator-reachable entries
- **THEN** `## 4. Baseline User-Reachable Inventory` contains literal `none`

#### Scenario: Prose inventory is invalid by contract
- **WHEN** a blueprint attempts to list `the admin login page` as a baseline inventory entry
- **THEN** the entry violates the stack blueprint artifact contract

### Requirement: Blueprint rule keeps artifacts structural
The stack blueprint rule SHALL state that blueprints describe stable project-level structural conventions only. The rule SHALL forbid feature-specific surfaces, implementation slices, implementation-plan tasks, and API contract schemas in blueprint content.

#### Scenario: Feature-specific route is excluded
- **WHEN** a future feature introduces a new route or endpoint
- **THEN** that feature-specific surface is not added to the baseline blueprint inventory by this contract

#### Scenario: Contract schemas remain outside the blueprint
- **WHEN** a project needs shared request or response schemas
- **THEN** those schemas remain owned by `common_contract_definition.md`, not the stack blueprint

### Requirement: Blueprint rule keeps artifacts concise and current
The stack blueprint rule SHALL state that blueprints remain concise project-level structural references and SHALL be updated when stable stack conventions change. The rule SHALL require `last_updated` to reflect the latest structural blueprint revision.

#### Scenario: Blueprint stays concise
- **WHEN** a blueprint is authored
- **THEN** it contains stack choices, layer bindings, and baseline user-reachable inventory without expanding into detailed implementation planning

#### Scenario: Stack change updates blueprint
- **WHEN** a stable stack convention changes, such as adding Kafka after project init
- **THEN** the blueprint is updated and `last_updated` reflects the revision

### Requirement: Golden examples demonstrate valid blueprint shape
Overmind SHALL provide golden examples for backend, frontend, and mobile stack blueprints that demonstrate the valid four-section structure, class-appropriate stack choices, layer bindings, required metadata, and token-based baseline inventory.

#### Scenario: Backend golden example demonstrates backend contract
- **WHEN** a practitioner reviews the backend stack blueprint golden example
- **THEN** the example shows a complete valid backend blueprint

#### Scenario: Frontend golden example demonstrates frontend contract
- **WHEN** a practitioner reviews the frontend stack blueprint golden example
- **THEN** the example shows a complete valid frontend blueprint

#### Scenario: Mobile golden example demonstrates mobile contract
- **WHEN** a practitioner reviews the mobile stack blueprint golden example
- **THEN** the example shows a complete valid mobile blueprint
