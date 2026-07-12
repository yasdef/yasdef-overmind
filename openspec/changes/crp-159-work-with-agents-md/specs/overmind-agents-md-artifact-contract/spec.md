## ADDED Requirements

### Requirement: The agent guidelines artifact is one per-class project-root file with a recognition header

Each active class of a type `A` project SHALL have exactly one agent guidelines artifact at the project root, named `project_agents_md_claude_md_<class>.md` where `<class>` is `backend`, `frontend`, or `mobile`. The artifact SHALL open with a `## 1. Document Meta` section carrying `artifact_kind` with the literal value `project_agents_md_claude_md`, `class` matching the filename class, `project`, `source_blueprint` naming that class's `project_stack_blueprint_<class>.md`, and `last_updated` in `YYYY-MM-DD` format. The artifact is a handoff document from which a downstream coding agent authors the repository's `AGENTS.md` and `CLAUDE.md`.

#### Scenario: One artifact per active class

- **WHEN** a type `A` project has active `backend` and `frontend` classes
- **THEN** the project root holds `project_agents_md_claude_md_backend.md` and `project_agents_md_claude_md_frontend.md`

#### Scenario: Recognition header identifies the artifact

- **WHEN** an agent reads a completed agent guidelines artifact
- **THEN** `## 1. Document Meta` declares `artifact_kind: project_agents_md_claude_md`, the class, the project, the source blueprint, and `last_updated` in `YYYY-MM-DD` format

### Requirement: Structural sections are derived from the approved stack blueprint

The artifact SHALL carry `## Stack Baseline`, `## Target Project Shape`, and `## Layer Responsibilities`, each derived from that class's approved `project_stack_blueprint_<class>.md`. `## Stack Baseline` SHALL restate the blueprint's `## 2. Stack Choices`. `## Target Project Shape` SHALL restate the `folder_paths` of the blueprint's `## 3. Layer Bindings`. `## Layer Responsibilities` SHALL carry one block per blueprint layer, restating that layer's `archetypes` and `user_reachable_pattern`. These sections SHALL NOT contradict the source blueprint.

#### Scenario: Stack baseline mirrors the blueprint stack choices

- **WHEN** the backend blueprint records `framework: spring-boot` and `rdbms: postgresql`
- **THEN** `## Stack Baseline` records the same framework and datastore choices

#### Scenario: Layer responsibilities cover every blueprint layer

- **WHEN** the frontend blueprint declares its standard layer bindings
- **THEN** `## Layer Responsibilities` carries one block per declared layer, each restating that layer's archetypes and user-reachable pattern

### Requirement: Engineering guidance sections are required for every class

The artifact SHALL carry `## Mission`, `## Non-Negotiable Engineering Rules`, `## Coding Standards`, `## Testing Standard`, `## Linting and Quality Gates`, `## Definition of Done`, and `## Decision Guidance for Agents`. `## Mission` SHALL order code quality, maintainability, and testability ahead of delivery speed. `## Testing Standard` SHALL state a recommended coverage floor. `## Linting and Quality Gates` SHALL name the checks the project enforces locally and in CI.

#### Scenario: Every required engineering section is present

- **WHEN** a completed agent guidelines artifact is inspected
- **THEN** Mission, Non-Negotiable Engineering Rules, Coding Standards, Testing Standard, Linting and Quality Gates, Definition of Done, and Decision Guidance for Agents are all present

#### Scenario: Mission states the quality ordering

- **WHEN** `## Mission` is read
- **THEN** it ranks code quality, maintainability, and testability ahead of delivery speed

#### Scenario: Testing standard carries a coverage floor

- **WHEN** `## Testing Standard` is read
- **THEN** it states a recommended coverage floor

### Requirement: Frontend and mobile artifacts may carry operator-authored delivery sections

A `frontend` or `mobile` artifact MAY carry `## Accessibility (a11y)`, `## Internationalization (i18n)`, `## UI Automation IDs`, and `## Applied Visual Style Contract`. These sections carry operator-supplied project decisions such as accessibility baselines, translation workflow, automation-identifier conventions, and the applied visual direction. They are optional and their absence SHALL NOT block the artifact.

#### Scenario: Optional sections are accepted in a frontend artifact

- **WHEN** the operator supplies an applied visual style contract and UI automation identifier conventions for the frontend class
- **THEN** the artifact carries `## Applied Visual Style Contract` and `## UI Automation IDs`

#### Scenario: Absent optional sections do not block the artifact

- **WHEN** a frontend artifact carries no accessibility, internationalization, UI automation, or visual style section
- **THEN** the artifact is still complete

### Requirement: The artifact carries durable guidance only

The artifact SHALL carry durable per-class engineering guidance. It SHALL NOT carry workflow state, proposal metadata, knowledge-base source attribution, approval history, conversation transcript, feature-specific work, implementation slices, or API contract schema governance. Shared contract definitions remain owned by `common_contract_definition.md`.

#### Scenario: Proposal and approval history stay out of the artifact

- **WHEN** the operator approves a proposed stack guidance set after a knowledge-base lookup and a follow-up override
- **THEN** the written artifact records neither the lookup, the override history, nor the approval exchange

#### Scenario: Feature work stays out of the artifact

- **WHEN** a completed artifact is inspected
- **THEN** it carries no feature-specific work, implementation slices, or API contract schema governance
