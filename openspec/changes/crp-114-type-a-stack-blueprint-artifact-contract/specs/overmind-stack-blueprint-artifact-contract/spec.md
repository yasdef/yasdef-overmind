## ADDED Requirements

### Requirement: Templates define Gap 5 project stack blueprints
Overmind SHALL provide project stack blueprint templates for backend, frontend, and mobile project classes at `overmind/templates/project_stack_blueprint_be_TEMPLATE.md`, `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md`, and `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md`. Templates SHALL define structure only.

#### Scenario: Backend template exists
- **WHEN** the Overmind templates are staged
- **THEN** `project_stack_blueprint_be_TEMPLATE.md` is available for backend type `A` projects

#### Scenario: Frontend template exists
- **WHEN** the Overmind templates are staged
- **THEN** `project_stack_blueprint_fe_TEMPLATE.md` is available for frontend type `A` projects

#### Scenario: Mobile template exists
- **WHEN** the Overmind templates are staged
- **THEN** `project_stack_blueprint_mobile_TEMPLATE.md` is available for mobile type `A` projects

### Requirement: Blueprint templates use three required sections
Each project stack blueprint template SHALL define exactly three required top-level sections: `## 1. Meta`, `## 2. Stack Choices`, and `## 3. Layer Bindings`.

#### Scenario: Three-section shape is present
- **WHEN** a template is inspected
- **THEN** the template contains the three required Gap 5 sections
- **AND** it does not contain workflow-state, proposal-source, or approval-state fields

### Requirement: Blueprint meta captures planned project identity
Section `## 1. Meta` SHALL include `class`, `repo_name`, `service_name`, `planned_repo_path`, a class-appropriate package/root field, and `last_updated`.

#### Scenario: Backend meta uses group id
- **WHEN** the backend template is inspected
- **THEN** Section 1 includes `group_id`

#### Scenario: Frontend and mobile meta use package root
- **WHEN** frontend or mobile templates are inspected
- **THEN** Section 1 includes `group_id_or_package_root`

### Requirement: Blueprint stack choices are class-specific
Section `## 2. Stack Choices` SHALL include class-specific runtime/framework, data, observability, deployment, and test stack fields sufficient for Gap 5 blueprint authoring.

#### Scenario: Backend stack choices are present
- **WHEN** the backend template is inspected
- **THEN** Section 2 includes backend stack categories such as language, framework, datastore, messaging, observability, deployment, and test stack

#### Scenario: Frontend stack choices are present
- **WHEN** the frontend template is inspected
- **THEN** Section 2 includes frontend stack categories such as framework, router, state, API integration, deployment, and test stack

#### Scenario: Mobile stack choices are present
- **WHEN** the mobile template is inspected
- **THEN** Section 2 includes mobile stack categories such as platforms, UI, navigation, state, API, local storage, distribution, and test stack

### Requirement: Blueprint layer bindings match surface-map layers
Section `## 3. Layer Bindings` SHALL include one block per standard surface-map layer for the class. Each layer block SHALL include `folder_paths`, `archetypes`, and `user_reachable_pattern`; backend Integration SHALL also include `topics_convention`.

#### Scenario: Backend layer bindings are complete
- **WHEN** the backend template is inspected
- **THEN** Section 3 includes backend layers 3.1 through 3.7

#### Scenario: Frontend layer bindings are complete
- **WHEN** the frontend template is inspected
- **THEN** Section 3 includes frontend layers 3.1 through 3.7

#### Scenario: Mobile layer bindings are complete
- **WHEN** the mobile template is inspected
- **THEN** Section 3 includes mobile layers 3.1 through 3.9

### Requirement: Rule keeps blueprint in Gap 5 lane
The project stack blueprint rule SHALL allow stable stack choices, layer conventions, and component archetypes, and SHALL forbid workflow state, proposal-source metadata, approval-state metadata, feature-specific implementation work, implementation slices, implementation-plan tasks, and API contract schema governance.

#### Scenario: Contract governance remains elsewhere
- **WHEN** shared request/response definitions are needed
- **THEN** they remain owned by `common_contract_definition.md`, not by the stack blueprint
