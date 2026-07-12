## MODIFIED Requirements

### Requirement: Project creation is a deterministic TypeScript primitive

Creating an ASDLC project SHALL be performed by a typed coordinator module (`packages/asdlc-coordinator/src/capture/project.ts`) invoked through `overmind project create`, not by shell. The base creation primitive SHALL capture project identity and project-level type and SHALL create a valid classless project before any optional class-management subprocess begins. Clock, UUID, operator interaction, temporary-file creation (the temp-fixture seam used for atomic metadata/definition writes), and git SHALL be supplied through injected ports so creation is deterministic under test.

#### Scenario: Create a base project via the CLI verb

- **WHEN** an operator runs `overmind project create` inside an ASDLC workspace and answers the project name and project type prompts
- **THEN** a new `projects/<normalized-name>-<uuid>/` folder is created containing an `init_progress_definition.yaml` seeded from the template with empty class collections, a project record is appended to `asdlc_metadata.yaml`, the project folder is initialized as a git repository with an initial commit, and the created folder and metadata paths are reported

#### Scenario: Creation is interactive with no create-specific options

- **WHEN** an operator runs `overmind project create`
- **THEN** project name, project type, and the optional class-management handoff are gathered through interactive prompts, no create-specific flags are required or accepted, and an unknown argument produces a usage error with a non-success exit

#### Scenario: Temp-fixture and git seams are injectable for tests

- **WHEN** the base creation primitive is exercised under test with injected temporary-file and git ports
- **THEN** atomic metadata/definition writes and the project `git init`/commit run through those ports without touching real system temp storage or a real repository

#### Scenario: Shell creator is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` and `overmind/scripts/common_libs/project_setup_common.sh` do not exist, and no packaged staging references them

### Requirement: Project definition is seeded from the template with a meta_info block

Project creation SHALL copy `.templates/init_progress_definition_TEMPLATE.yaml` into the new project's `init_progress_definition.yaml` and inject a `meta_info` block above the template's `steps:` block. The base `meta_info` block SHALL carry the `project_id` (the folder name), `project_type_code`, and `project_type_label`, plus `project_classes: []` and `class_repo_paths: {}`. All quoted scalar values SHALL be YAML-escaped, and the template's `steps:` block and all unrelated template content SHALL be preserved. Optional class management SHALL mutate the two class collections only after base creation succeeds.

#### Scenario: Classless meta_info precedes template steps

- **WHEN** a base project is created from the template
- **THEN** the resulting definition contains project identity/type, empty project classes, and an empty class-repository map above the unmodified template `steps:` block

#### Scenario: Special characters are escaped

- **WHEN** a recorded base-project value contains a double quote or backslash
- **THEN** the value is written escaped inside its double-quoted YAML scalar and the file remains valid

## ADDED Requirements

### Requirement: Project creation captures project type before optional class management

Project creation SHALL require a project-level type selection resolved to `A`, `B`, or `C`, mapped respectively to `New project`, `Existing project with partial context`, or `Existing project with code-first context`. After the base project and initial commit succeed, the CLI SHALL ask whether to add project classes. No SHALL finish successfully with the class collections empty. Yes SHALL invoke the shared class-management subprocess against the new project without repeating project selection. Closed input at this handoff SHALL behave as no and SHALL NOT roll back the created project.

#### Scenario: Operator creates an empty project

- **WHEN** the operator supplies a valid name and project type and declines class management
- **THEN** project creation succeeds with the selected project type and no project classes or class repository records

#### Scenario: Operator continues into class management

- **WHEN** base creation succeeds and the operator accepts the class-management handoff
- **THEN** the class add-or-finish loop starts against the newly created project

#### Scenario: Unsupported project type is re-prompted

- **WHEN** the operator enters a project type that does not resolve to `A`, `B`, or `C`
- **THEN** the selection is rejected and re-prompted before the project is created

## REMOVED Requirements

### Requirement: Project type, classes, and repo paths are captured

**Reason**: Mandatory creation-time class and repository capture is replaced by base project creation followed by optional reusable class management.

**Migration**: Use the optional post-create handoff or run `overmind project add-class-and-repo` later to create or replace class policy/state/path records.
