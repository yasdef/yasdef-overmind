## ADDED Requirements

### Requirement: Project setup supports optional stack guidance sources
Project setup SHALL support optional per-class stack guidance source metadata for project type `A`. The metadata SHALL be optional and SHALL NOT be required for project setup completion.

#### Scenario: Startup records backend guidance source
- **WHEN** the user provides a backend stack guidance source during type `A` project setup
- **THEN** project metadata records that source for the backend class

#### Scenario: Startup records frontend guidance source
- **WHEN** the user provides a frontend stack guidance source during type `A` project setup
- **THEN** project metadata records that source for the frontend class

#### Scenario: Startup records mobile guidance source
- **WHEN** the user provides a mobile stack guidance source during type `A` project setup
- **THEN** project metadata records that source for the mobile class

#### Scenario: Startup proceeds without guidance source
- **WHEN** the user provides no stack guidance source during type `A` project setup
- **THEN** project setup still completes and leaves guidance metadata absent for that class

### Requirement: Guidance metadata is class-scoped
Stack guidance source metadata SHALL be scoped by project class so different active classes can use different sources or no source.

#### Scenario: Mixed guidance availability
- **WHEN** a type `A` project has backend and frontend active, and only backend has a configured guidance source
- **THEN** backend metadata records the source and frontend metadata remains absent

### Requirement: Guidance metadata does not make MCP mandatory
The absence of stack guidance source metadata, or the unavailability of a configured source, SHALL NOT block type `A` projects from proceeding to the Step `1.1` fallback proposal path.

#### Scenario: Missing metadata triggers fallback path
- **WHEN** Step `1.1` runs for a class with no stack guidance source metadata
- **THEN** the authoring flow uses bounded fallback proposals

#### Scenario: Unavailable source triggers fallback path
- **WHEN** Step `1.1` runs for a class with configured guidance metadata but the source is unavailable
- **THEN** the authoring flow reports the unavailable source and uses bounded fallback proposals

### Requirement: Guidance metadata is not stored in blueprint templates
Stack guidance source metadata SHALL NOT be part of the CRP-114 blueprint template contract. Any proposal-source tracking SHALL belong to the Step `1.1` authoring flow.

#### Scenario: Template remains structure-only
- **WHEN** stack guidance metadata is recorded during project setup
- **THEN** CRP-114 blueprint templates remain unchanged and do not gain proposal-source fields
