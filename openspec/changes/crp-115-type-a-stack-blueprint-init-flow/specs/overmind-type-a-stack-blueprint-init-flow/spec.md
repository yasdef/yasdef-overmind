## ADDED Requirements

### Requirement: Type A init includes stack blueprint step
Overmind SHALL add project-init Step `1.1` for project type `A` after Step `1` records project type/classes and before Step `2` creates `common_contract_definition.md`.

#### Scenario: Step 1.1 is present for type A
- **WHEN** init progress is generated for a project with `project_type_code: A`
- **THEN** Step `1.1` exists after Step `1` and before Step `2`

#### Scenario: Step 1.1 is not required for type B or C
- **WHEN** init progress is generated for a project with `project_type_code: B` or `project_type_code: C`
- **THEN** Step `1.1` does not block progress to Step `2`

### Requirement: Type A requires one blueprint per active class
For project type `A`, Step `1.1` SHALL require exactly one final `project_stack_blueprint_<class>.md` artifact at the project root for each active class in `project_classes`.

#### Scenario: Backend active requires backend blueprint
- **WHEN** a type `A` project has `backend` in `project_classes`
- **THEN** Step `1.1` requires `project_stack_blueprint_backend.md`

#### Scenario: Frontend active requires frontend blueprint
- **WHEN** a type `A` project has `frontend` in `project_classes`
- **THEN** Step `1.1` requires `project_stack_blueprint_frontend.md`

#### Scenario: Mobile active requires mobile blueprint
- **WHEN** a type `A` project has `mobile` in `project_classes`
- **THEN** Step `1.1` requires `project_stack_blueprint_mobile.md`

### Requirement: Step 1.1 runs quality validation
Step `1.1` SHALL run the CRP-114 stack blueprint quality helper for every required active-class blueprint before the step is considered complete.

#### Scenario: Valid required blueprints complete step
- **WHEN** every required active-class blueprint exists and passes `check_project_stack_blueprint_quality.sh`
- **THEN** Step `1.1` can be marked complete

#### Scenario: Invalid required blueprint blocks step
- **WHEN** a required active-class blueprint exists but fails `check_project_stack_blueprint_quality.sh`
- **THEN** Step `1.1` remains incomplete

#### Scenario: Missing required blueprint blocks step
- **WHEN** a required active-class blueprint is missing
- **THEN** Step `1.1` remains incomplete

### Requirement: Type B and C behavior remains unchanged
Project types `B` and `C` SHALL continue to rely on repository scan evidence and SHALL NOT require project stack blueprints to proceed through init.

#### Scenario: Type B proceeds without blueprints
- **WHEN** a type `B` project has active classes and no stack blueprints
- **THEN** init progress does not fail due to missing stack blueprints

#### Scenario: Type C proceeds without blueprints
- **WHEN** a type `C` project has active classes and no stack blueprints
- **THEN** init progress does not fail due to missing stack blueprints
