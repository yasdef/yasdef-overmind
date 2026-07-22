## ADDED Requirements

### Requirement: Project creation is a deterministic TypeScript primitive

Creating an ASDLC project SHALL be performed by a typed coordinator module (`packages/asdlc-coordinator/src/capture/project.ts`) invoked through `overmind project create`, not by shell. The repository SHALL NOT contain `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` or `overmind/scripts/common_libs/project_setup_common.sh`. Clock, UUID, operator interaction, temporary-file creation (the temp-fixture seam used for atomic metadata/definition writes), and git SHALL be supplied through injected ports so creation is deterministic under test.

#### Scenario: Create a project via the CLI verb

- **WHEN** an operator runs `overmind project create` inside an ASDLC workspace and answers the name, class, repo-path, and type prompts
- **THEN** a new `projects/<normalized-name>-<uuid>/` folder is created containing an `init_progress_definition.yaml` seeded from the template, a project record is appended to `asdlc_metadata.yaml`, the project folder is initialized as a git repository with an initial commit, and the created folder and metadata paths are reported

#### Scenario: Creation is interactive with no create-specific options

- **WHEN** an operator runs `overmind project create`
- **THEN** every input (name, type, classes, repo paths) is gathered through interactive prompts, no create-specific flags are required or accepted, and an unknown argument produces a usage error with a non-success exit

#### Scenario: Temp-fixture and git seams are injectable for tests

- **WHEN** the creation primitive is exercised under test with injected temporary-file and git ports
- **THEN** atomic metadata/definition writes and the project `git init`/commit run through those ports without touching real system temp storage or a real repository

#### Scenario: Shell creator is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` and `overmind/scripts/common_libs/project_setup_common.sh` do not exist, and no packaged staging references them

### Requirement: Project name is normalized to a canonical slug

Project creation SHALL require a non-empty project name and normalize it to a lowercase slug by lowercasing, replacing every run of non-alphanumeric characters with a single underscore, and trimming leading/trailing underscores. A name that is empty or normalizes to an empty string (no letter or digit) SHALL be rejected. The original operator-entered name SHALL be preserved as the human-readable `name` in the metadata record while the normalized slug drives the folder name.

#### Scenario: Name is slugified for the folder

- **WHEN** the operator enters `My New Project!`
- **THEN** the project folder is named `my_new_project-<uuid>` and the metadata record's `name` retains the original `My New Project!`

#### Scenario: Empty or symbol-only name is rejected

- **WHEN** the operator enters a blank name or one containing no letters or digits
- **THEN** creation fails with a clear error and no project folder, definition, metadata record, or commit is written

### Requirement: Project type, classes, and repo paths are captured

Project creation SHALL require a project type selection resolved to `A`, `B`, or `C` (each mapped to its label: `A` New project, `B` Existing project with partial context, `C` Existing project with code-first context). It SHALL require at least one project class selected from `backend`, `frontend`, `mobile`, `infrastructure`, recorded in that canonical order regardless of selection order and without duplicates. For each selected class the operator SHALL declare it ready-with-path or deferred; a ready path SHALL be validated as an existing non-empty directory and resolved to a canonical absolute path before being recorded, and an invalid path SHALL be re-prompted rather than written.

#### Scenario: Classes recorded in canonical order

- **WHEN** the operator selects `frontend` then `backend`
- **THEN** the definition `meta_info.project_classes` lists `backend` before `frontend`

#### Scenario: Deferred class carries no path

- **WHEN** the operator marks `mobile` as "I'll add it later"
- **THEN** the definition records `mobile` with `state: "deferred"` and an empty `path`

#### Scenario: Invalid ready repo path is re-prompted

- **WHEN** the operator declares a class ready and enters a path that is empty, does not exist, is not a directory, or is an empty directory
- **THEN** the path is rejected, the operator is re-prompted, and no invalid path is recorded

#### Scenario: Unsupported project type is rejected

- **WHEN** the operator enters a type selection that does not resolve to `A`, `B`, or `C`
- **THEN** the selection is rejected and re-prompted, and no project is created

### Requirement: Project definition is seeded from the template with a meta_info block

Project creation SHALL copy `.templates/init_progress_definition_TEMPLATE.yaml` into the new project's `init_progress_definition.yaml` and inject a `meta_info` block above the template's `steps:` block. The `meta_info` block SHALL carry the `project_id` (the folder name), the ordered `project_classes`, the `project_type_code` and `project_type_label`, and a `class_repo_paths` mapping of each class to its `state` and `path`. All quoted scalar values SHALL be YAML-escaped, and the template's `steps:` block and all unrelated template content SHALL be preserved.

#### Scenario: meta_info precedes the template steps

- **WHEN** a project is created from the template
- **THEN** the resulting `init_progress_definition.yaml` begins with a `meta_info:` block containing `project_id`, `project_classes`, `project_type_code`, `project_type_label`, and `class_repo_paths`, followed by the unmodified template `steps:` block

#### Scenario: Special characters are escaped

- **WHEN** a recorded value contains a double quote or backslash
- **THEN** the value is written escaped inside its double-quoted YAML scalar and the file remains valid

### Requirement: Project record is appended to ASDLC metadata

Project creation SHALL append a project record to `asdlc_metadata.yaml` after asserting the file's shape (a top-level `meta:` key and a top-level `projects:` key that is the final top-level section), normalizing terminal blank lines before the append. The appended record SHALL carry the `project` id (folder name), the original `name`, the `internal_folder` (folder name), and a `created_at` UTC timestamp, with quoted values escaped. All existing metadata content other than trailing blank lines SHALL be byte-preserved (terminal blank-line normalization is the sole permitted change to prior content). A malformed metadata file SHALL fail with a clear error and no mutation.

#### Scenario: Record appended under projects

- **WHEN** a project is created against a well-formed `asdlc_metadata.yaml`
- **THEN** a `- project: <folder>` record with `name`, `internal_folder`, and `created_at` is appended under `projects:`, and all prior non-trailing-blank content is byte-preserved

#### Scenario: Malformed metadata fails without mutation

- **WHEN** `asdlc_metadata.yaml` is missing its `meta:` or final `projects:` section
- **THEN** creation fails with a shape error and `asdlc_metadata.yaml` is left unchanged

### Requirement: New project folder is git-initialized with an identity fallback and initial commit

Project creation SHALL initialize the new project folder as a git repository, ensure a git identity — using the local fallback identity (`Overmind ASDLC` / `overmind-asdlc@local.invalid`) only when `user.name` or `user.email` is not already configured — stage the seeded `init_progress_definition.yaml`, and create the initial commit `Initialize ASDLC project workspace`. Git operations SHALL run through an injected port so creation is deterministic under test, and the project git scope SHALL stay distinct from the runtime-root and class-repository scopes. Creation SHALL fail if the target folder already exists.

#### Scenario: Fresh project gets an initial commit

- **WHEN** a project is created and no git `user.name`/`user.email` is configured
- **THEN** the project folder is `git init`-ed, the fallback identity is applied, the definition is staged, and an initial `Initialize ASDLC project workspace` commit is created

#### Scenario: Configured identity is preserved

- **WHEN** a git `user.name` and `user.email` are already configured for the project folder
- **THEN** the initial commit is created without overwriting the configured identity

#### Scenario: Existing folder aborts creation

- **WHEN** the computed `projects/<slug>-<uuid>/` folder already exists
- **THEN** creation fails with a clear error and no folder, definition, metadata record, or commit is written

### Requirement: Creation returns a typed result the CLI renders without scraping

The creation primitive SHALL return a typed result carrying its diagnostics and the set of changed paths, and the CLI SHALL render its output and exit code from that result rather than parsing printed text. On success the result SHALL report the created project folder/definition and `asdlc_metadata.yaml` as changed paths; on validation failure (empty name, unsupported type, malformed metadata, existing folder, or git failure) it SHALL carry a diagnostic and report no partial success.

#### Scenario: Successful creation reports changed paths

- **WHEN** a project is created
- **THEN** the returned result reports the new project folder/definition and `asdlc_metadata.yaml` among its changed paths, and the CLI renders the "Created ASDLC project folder" and "Updated ASDLC metadata" messages from that result

#### Scenario: Validation failure carries a diagnostic

- **WHEN** creation fails on name/type validation, malformed metadata, an existing folder, or a git error
- **THEN** the returned result carries a diagnostic describing the failure and the CLI renders a non-success exit from it
