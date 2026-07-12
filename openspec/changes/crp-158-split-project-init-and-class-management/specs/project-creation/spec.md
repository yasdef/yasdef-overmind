## MODIFIED Requirements

### Requirement: Project creation is a deterministic TypeScript primitive

Creating an ASDLC project SHALL be performed by a typed coordinator module (`packages/asdlc-coordinator/src/capture/project.ts`) invoked through `overmind project create`, not by shell. Clock, UUID, operator interaction, temporary-file creation (the temp-fixture seam used for atomic metadata/definition writes), and git SHALL be supplied through injected ports so creation is deterministic under test.

#### Scenario: Create a project via the CLI verb

- **WHEN** an operator runs `overmind project create` inside an ASDLC workspace and answers the project name, project type, and class prompts
- **THEN** a new `projects/<normalized-name>-<uuid>/` folder is created containing an `init_progress_definition.yaml` seeded from the template, a project record is appended to `asdlc_metadata.yaml`, the project folder is initialized as a git repository with an initial commit, and the created folder and metadata paths are reported

#### Scenario: Creation is interactive with no create-specific options

- **WHEN** an operator runs `overmind project create`
- **THEN** the project name, project type, and class selection are gathered through interactive prompts, no create-specific flags are required or accepted, and an unknown argument produces a usage error with a non-success exit

#### Scenario: Temp-fixture and git seams are injectable for tests

- **WHEN** the creation primitive is exercised under test with injected temporary-file and git ports
- **THEN** atomic metadata/definition writes and the project `git init`/commit run through those ports without touching real system temp storage or a real repository

### Requirement: Project definition is seeded from the template with a meta_info block

Project creation SHALL copy `.templates/init_progress_definition_TEMPLATE.yaml` into the new project's `init_progress_definition.yaml` and inject a `meta_info` block above the template's `steps:` block. The `meta_info` block SHALL carry the `project_id` (the folder name), the ordered `project_classes`, the `project_type_code` and `project_type_label`, and a `class_repo_paths` mapping of each selected class to its `state`, `path`, and `policy`. All quoted scalar values SHALL be YAML-escaped, and the template's `steps:` block and all unrelated template content SHALL be preserved.

#### Scenario: meta_info precedes the template steps

- **WHEN** a project is created from the template
- **THEN** the resulting `init_progress_definition.yaml` begins with a `meta_info:` block containing `project_id`, `project_classes`, `project_type_code`, `project_type_label`, and `class_repo_paths`, followed by the unmodified template `steps:` block

#### Scenario: Special characters are escaped

- **WHEN** a recorded value contains a double quote or backslash
- **THEN** the value is written escaped inside its double-quoted YAML scalar and the file remains valid

## ADDED Requirements

### Requirement: Project creation captures project type and class membership only

Project creation SHALL require a project type selection resolved to `A`, `B`, or `C` (mapped respectively to `New project`, `Existing project with partial context`, `Existing project with code-first context`). It SHALL let the operator select any number of project classes — including none — from `backend`, `frontend`, `mobile`, and `infrastructure`, recorded in canonical order without duplicates. Each selected class SHALL be written as `state: "deferred"`, `path: ""`, and `policy: "A"`. Creation SHALL NOT request or validate a repository path, and SHALL report that `overmind project reconcile` binds repositories.

#### Scenario: Selected classes are deferred with no repository

- **WHEN** the operator selects `frontend` and `backend`
- **THEN** `project_classes` lists `backend` before `frontend`, both classes record `state: "deferred"`, an empty `path`, and `policy: "A"`, no repository path is requested, and the operator is directed to `overmind project reconcile`

#### Scenario: A project may be created with no classes

- **WHEN** the operator selects no project class
- **THEN** creation succeeds with empty `project_classes` and `class_repo_paths` collections

#### Scenario: Unsupported project type is rejected

- **WHEN** the operator enters a type selection that does not resolve to `A`, `B`, or `C`
- **THEN** the selection is rejected and re-prompted, and no project is created

## REMOVED Requirements

### Requirement: Project type, classes, and repo paths are captured

**Reason**: Repository capture moves out of creation entirely; `overmind project reconcile` remains the sole writer of class policy, repository path, and `ready` state, and creation now records only project type and class membership.

**Migration**: Select classes at creation and run `overmind project reconcile` to bind their repositories; use `overmind project add-class` for a class that was not selected at creation.
