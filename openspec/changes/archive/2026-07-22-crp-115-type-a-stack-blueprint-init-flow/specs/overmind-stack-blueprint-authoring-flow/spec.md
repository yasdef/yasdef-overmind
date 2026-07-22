## ADDED Requirements

### Requirement: Authoring command processes active classes
The stack-family blueprint authoring command SHALL read `init_progress_definition.yaml`, identify `project_type_code` and active `project_classes`, process each active class independently for project type `A`, and no-op for project types `B` and `C`.

#### Scenario: Type A backend and frontend are processed independently
- **WHEN** a type `A` project has backend and frontend active
- **THEN** the authoring command processes backend and frontend separately

#### Scenario: Type B no-ops
- **WHEN** the authoring command runs for project type `B`
- **THEN** it exits without requiring or writing stack blueprints

#### Scenario: Type C no-ops
- **WHEN** the authoring command runs for project type `C`
- **THEN** it exits without requiring or writing stack blueprints

### Requirement: Authoring flow uses configured guidance when available
For each active type `A` class, the authoring flow SHALL check configured stack guidance source metadata before proposing stack choices. When guidance is available, it SHALL extract stack choices, layer conventions, component archetypes, and baseline user-reachable tokens from that source for user review.

#### Scenario: Configured guidance source is used
- **WHEN** a backend stack guidance source is configured and available
- **THEN** the authoring flow presents backend stack-family options grounded in that source

#### Scenario: Source usage is visible to user
- **WHEN** configured guidance is used for a class
- **THEN** the authoring flow tells the user which source informed the proposal

### Requirement: Authoring flow falls back to bounded stack-family proposals
When no guidance source is configured or the configured source is unavailable, the authoring flow SHALL present bounded high-level fallback stack-family proposals for user discussion and approval.

#### Scenario: Backend fallback menu is presented
- **WHEN** no backend guidance source is available
- **THEN** the authoring flow presents Java/Spring Boot as the default backend proposal and Node.js as the main alternative

#### Scenario: Frontend fallback menu is presented
- **WHEN** no frontend guidance source is available
- **THEN** the authoring flow presents React as the default frontend proposal and Angular as the main alternative

#### Scenario: Mobile fallback menu is presented
- **WHEN** no mobile guidance source is available
- **THEN** the authoring flow presents native Android Kotlin and iOS Swift as the default mobile proposal and Flutter/Dart as the main alternative

### Requirement: Authoring flow requires user approval before final write
The authoring flow SHALL NOT write final `project_stack_blueprint_<class>.md` artifacts until the user explicitly approves one complete Gap 5 blueprint for that class or provides an override.

#### Scenario: No final write before approval
- **WHEN** the user has not approved a complete Gap 5 blueprint for a class
- **THEN** the authoring flow does not write the final stack blueprint for that class

#### Scenario: Final write after approval
- **WHEN** the user approves a complete Gap 5 blueprint for a class
- **THEN** the authoring flow writes `project_stack_blueprint_<class>.md`

#### Scenario: User override is accepted before approval
- **WHEN** the user rejects a proposed blueprint and provides an override
- **THEN** the authoring flow revises the proposed blueprint before asking for final approval

### Requirement: Authoring flow writes Gap 5 stack blueprint artifacts
Final blueprints written by the authoring flow SHALL conform to the CRP-114 Gap 5 stack blueprint artifact contract and SHALL pass `check_project_stack_blueprint_quality.sh`.

#### Scenario: Valid final blueprint passes quality helper
- **WHEN** the authoring flow writes a final blueprint
- **THEN** it runs the CRP-114 quality helper and the helper exits successfully

#### Scenario: Invalid generated blueprint is not accepted
- **WHEN** a generated final blueprint fails the CRP-114 quality helper
- **THEN** the authoring flow reports the failure and does not mark Step `1.1` complete

#### Scenario: Feature-specific details are excluded
- **WHEN** the authoring flow writes a final blueprint
- **THEN** it includes stable planned repo identity, folder paths, package roots, layer bindings, archetypes, and baseline tokens, but not feature-specific work or API contract schema governance

### Requirement: Authoring flow can revise existing blueprints
The authoring flow SHALL support updating an existing type `A` stack-family blueprint when the approved stack family changes. Revisions SHALL use the same user-approval and CRP-114 quality-validation path as initial blueprint creation.

#### Scenario: Existing blueprint revised after stack-family change
- **WHEN** an approved stack family changes after project init
- **THEN** the authoring flow can revise the affected class blueprint after user approval

#### Scenario: Revised blueprint passes quality
- **WHEN** the authoring flow writes a revised blueprint
- **THEN** it runs the quality helper before the revision is accepted

### Requirement: Approval tracking stays outside template contract
Proposal-source and approval tracking SHALL be handled by the Step `1.1` authoring flow and SHALL NOT require adding proposal-source or approval-status fields to CRP-114 blueprint templates.

#### Scenario: Approval does not alter template fields
- **WHEN** the user approves a blueprint proposal
- **THEN** the final blueprint remains shaped by the CRP-114 artifact contract without workflow-state fields
