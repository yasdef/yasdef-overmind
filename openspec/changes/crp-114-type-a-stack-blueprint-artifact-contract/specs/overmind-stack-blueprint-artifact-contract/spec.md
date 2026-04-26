## ADDED Requirements

### Requirement: Per-class stack-family blueprint templates
Overmind SHALL provide minimal stack-family blueprint templates for backend, frontend, and mobile project classes at `overmind/templates/project_stack_blueprint_be_TEMPLATE.md`, `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md`, and `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md`.

#### Scenario: Templates exist for all supported classes
- **WHEN** the stack-family blueprint contract is installed
- **THEN** backend, frontend, and mobile blueprint template files exist under `overmind/templates/`

#### Scenario: Templates are class-specific
- **WHEN** a practitioner opens a stack-family blueprint template
- **THEN** the template identifies the target class and contains only stack-family fields applicable to that class

### Requirement: Templates define minimal early-init structure only
Stack-family blueprint templates SHALL define section layout, required headings, required field names, and placeholders/comments only. Templates SHALL NOT contain concrete repo paths, package roots, folder paths, archetypes, path strategies, constraints, baseline user-reachable surfaces, workflow state, approval state, source metadata, or behavioral rules.

#### Scenario: Template does not ask for unknowable project structure
- **WHEN** a practitioner opens a stack-family blueprint template
- **THEN** the template does not require planned repo paths, folder paths, layer bindings, archetypes, or baseline user-reachable tokens

#### Scenario: Template does not encode workflow state
- **WHEN** a practitioner opens a stack-family blueprint template
- **THEN** the template does not include proposal source, approval status, or other authoring-flow state fields

#### Scenario: Template does not define behavior rules
- **WHEN** a practitioner opens a stack-family blueprint template
- **THEN** behavioral constraints are not embedded in the template and remain owned by `project_stack_blueprint_rule.md`

### Requirement: Blueprint sections are fixed
Each stack-family blueprint template SHALL define exactly two required top-level sections: `## 1. Meta` and `## 2. Approved Stack Family`.

#### Scenario: Required sections are present
- **WHEN** a stack-family blueprint is authored from a template
- **THEN** it contains both required top-level sections in order

#### Scenario: Structural evidence sections are not introduced
- **WHEN** a stack-family blueprint records an early-init stack choice
- **THEN** it does not add layer bindings, baseline user-reachable inventory, feature work, implementation slices, implementation-plan tasks, or API contract schema governance sections

### Requirement: Meta section captures class identity
The blueprint meta section SHALL include class and last updated date. Valid class values are `backend`, `frontend`, and `mobile`.

#### Scenario: Backend meta identifies class
- **WHEN** a backend stack-family blueprint is authored
- **THEN** `## 1. Meta` contains `class: backend` and `last_updated`

#### Scenario: Frontend meta identifies class
- **WHEN** a frontend stack-family blueprint is authored
- **THEN** `## 1. Meta` contains `class: frontend` and `last_updated`

#### Scenario: Mobile meta identifies class
- **WHEN** a mobile stack-family blueprint is authored
- **THEN** `## 1. Meta` contains `class: mobile` and `last_updated`

#### Scenario: Last updated is date shaped
- **WHEN** a blueprint is authored or revised
- **THEN** `last_updated` is recorded in `YYYY-MM-DD` format

### Requirement: Approved stack family records one high-level choice
The approved stack-family section SHALL capture exactly the high-level stack family approved for the class. It SHALL NOT require detailed stack categories, repository layout, path conventions, baseline routes/screens/jobs, or implementation details.

#### Scenario: Backend stack family is recorded
- **WHEN** a backend stack-family blueprint is complete
- **THEN** `## 2. Approved Stack Family` contains a populated backend stack-family choice such as `java-spring-boot` or `nodejs`

#### Scenario: Frontend stack family is recorded
- **WHEN** a frontend stack-family blueprint is complete
- **THEN** `## 2. Approved Stack Family` contains a populated frontend stack-family choice such as `react` or `angular`

#### Scenario: Mobile stack family is recorded
- **WHEN** a mobile stack-family blueprint is complete
- **THEN** `## 2. Approved Stack Family` contains a populated mobile stack-family choice such as `native-android-ios` or `flutter`

### Requirement: Blueprint rule keeps artifacts at early-init precision
The stack blueprint rule SHALL state that stack-family blueprints describe only the approved high-level stack family for one active class. The rule SHALL forbid path strategies, layer bindings, baseline surfaces, implementation slices, implementation-plan tasks, and API contract schemas in blueprint content.

#### Scenario: Baseline route is excluded
- **WHEN** a future project needs a login route, health endpoint, screen, job, or command
- **THEN** that user-reachable surface is not recorded in this early-init stack-family blueprint

#### Scenario: Contract schemas remain outside the blueprint
- **WHEN** a project needs shared request or response schemas
- **THEN** those schemas remain owned by `common_contract_definition.md`, not the stack-family blueprint

### Requirement: Golden examples demonstrate valid minimal blueprint shape
Overmind SHALL provide golden examples for backend, frontend, and mobile stack-family blueprints that demonstrate the valid two-section structure, required metadata, and approved stack-family choice.

#### Scenario: Backend golden example demonstrates backend contract
- **WHEN** a practitioner reviews the backend stack-family blueprint golden example
- **THEN** the example shows a complete valid backend stack-family blueprint

#### Scenario: Frontend golden example demonstrates frontend contract
- **WHEN** a practitioner reviews the frontend stack-family blueprint golden example
- **THEN** the example shows a complete valid frontend stack-family blueprint

#### Scenario: Mobile golden example demonstrates mobile contract
- **WHEN** a practitioner reviews the mobile stack-family blueprint golden example
- **THEN** the example shows a complete valid mobile stack-family blueprint
