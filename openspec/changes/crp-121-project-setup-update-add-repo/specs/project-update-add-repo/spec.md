## ADDED Requirements

### Requirement: Interactive project selection from existing project definitions

The script SHALL list every project that has a
`projects/<project_id>/init_progress_definition.yaml` and prompt the operator
to pick one by number. Each option MUST display the `project_id` and the
current `meta_info.project_type_code`. The prompt MUST accept a quit token
(`q`, case-insensitive) that exits with code 0 and makes no file mutation.
Invalid input MUST re-prompt without exiting.

#### Scenario: Operator picks an existing project by index
- **WHEN** the operator runs `project_setup_update_project.sh` and at least one project definition exists
- **THEN** the script prints a numbered list of project ids with their `project_type_code`
- **AND** entering a valid index advances to class selection for that project

#### Scenario: Operator quits at the project prompt
- **WHEN** the operator enters `q` (or `Q`) at the project prompt
- **THEN** the script exits with code 0
- **AND** no `init_progress_definition.yaml` is modified

#### Scenario: No projects exist
- **WHEN** there are no `projects/*/init_progress_definition.yaml` files
- **THEN** the script prints a clear "no projects found" message
- **AND** exits with code 0 without prompting further

### Requirement: Class selection only offers deferred classes

After a project is selected, the script SHALL parse that project's
`init_progress_definition.yaml` and offer ONLY classes whose entry under
`meta_info.class_repo_paths` has `state: "deferred"`. The prompt MUST accept a
quit token (`q`) that exits with code 0 and no mutation. If no class is
`deferred`, the script SHALL print a clear "nothing to add" message and exit
with code 0 without prompting further.

#### Scenario: Only deferred classes are listed
- **WHEN** a project has classes `backend` (state `deferred`) and `frontend` (state `ready`)
- **THEN** the class prompt lists `backend` only
- **AND** `frontend` is not selectable

#### Scenario: All classes already ready
- **WHEN** every class under `class_repo_paths` already has `state: "ready"`
- **THEN** the script prints "nothing to add" and exits with code 0
- **AND** does not prompt the operator for a class or path

#### Scenario: Operator quits at the class prompt
- **WHEN** the operator enters `q` at the class prompt
- **THEN** the script exits with code 0
- **AND** the project definition file is unchanged

### Requirement: Repo path entry reuses new-project validation

The path prompt SHALL apply the same validation rules used by
`project_setup_add_new_project.sh`: reject empty input, reject paths that do
not exist, reject paths that are not directories, reject empty directories,
and resolve the accepted path to an absolute path before persisting. On
validation failure the script MUST re-prompt rather than exit. The prompt
MUST accept a quit token (`q`) checked BEFORE path validation, so an operator
can leave without entering a real path.

#### Scenario: Empty input is rejected
- **WHEN** the operator presses Enter without typing anything at the path prompt
- **THEN** the script prints the empty-path error
- **AND** re-prompts for a path

#### Scenario: Non-existent path is rejected
- **WHEN** the operator enters a path that does not exist on disk
- **THEN** the script prints the does-not-exist error
- **AND** re-prompts for a path

#### Scenario: Non-directory path is rejected
- **WHEN** the operator enters a path that exists but is a regular file
- **THEN** the script prints the not-a-directory error
- **AND** re-prompts for a path

#### Scenario: Empty directory is rejected
- **WHEN** the operator enters a path to an empty directory
- **THEN** the script prints the must-be-non-empty error
- **AND** re-prompts for a path

#### Scenario: Operator quits at the path prompt
- **WHEN** the operator enters `q` at the path prompt
- **THEN** the script exits with code 0
- **AND** the project definition file is unchanged

#### Scenario: Valid path is resolved to an absolute path
- **WHEN** the operator enters a relative path to a non-empty existing directory
- **THEN** the script resolves it to an absolute path before persisting

### Requirement: Class repo state transitions deferred to ready in place

On successful path entry, the script SHALL update the chosen class entry in
`projects/<project_id>/init_progress_definition.yaml`:
`state` MUST change from `"deferred"` to `"ready"`, and `path` MUST be set to
the resolved absolute path (with the same YAML escaping used by the new-project
flow). All other content in the file (other classes, `steps:` block, comments,
formatting) MUST be preserved byte-for-byte except for those two lines. If
the chosen class's existing entry does not match the expected
`state: "deferred"` shape, the script MUST abort with a clear error and make
no mutation.

#### Scenario: Successful attach updates exactly two lines
- **WHEN** the operator successfully attaches a path to a deferred class
- **THEN** that class's `state` line becomes `state: "ready"`
- **AND** that class's `path` line becomes `path: "<resolved absolute path>"`
- **AND** every other class entry is unchanged
- **AND** the `steps:` block is unchanged

#### Scenario: Path with characters requiring YAML escaping
- **WHEN** the resolved path contains a double-quote or backslash
- **THEN** the persisted `path:` line escapes those characters the same way the new-project flow does

#### Scenario: Unexpected file shape aborts cleanly
- **WHEN** the chosen class entry does not contain `state: "deferred"` in the expected shape
- **THEN** the script prints a shape-mismatch error
- **AND** exits non-zero
- **AND** the project definition file is unchanged

### Requirement: Type-A reclassification prompt fires only when all classes are ready

The script SHALL prompt the operator to reclassify the project to type B or
C, or to keep type A and finish, when (and only when) AFTER a successful
attach the project's `meta_info.project_type_code` equals `"A"` and every
class entry under `class_repo_paths` has `state: "ready"`. The "all ready"
check MUST read the file as it stands after the attach write, not the
pre-attach in-memory state. Quit (`q`) at this prompt SHALL behave the same
as "keep type A and finish".

#### Scenario: All-ready type-A project triggers prompt
- **WHEN** the attach completes and the resulting file has `project_type_code: "A"` and every class state is `ready`
- **THEN** the script prompts with options `1. B`, `2. C`, `3. Keep type A and finish`

#### Scenario: Type-A but not all classes ready
- **WHEN** after the attach at least one class still has `state: "deferred"`
- **THEN** the script does not show the reclassification prompt
- **AND** exits with code 0

#### Scenario: Project already type B or C
- **WHEN** the project's `project_type_code` is `B` or `C` after the attach
- **THEN** the script does not show the reclassification prompt
- **AND** exits with code 0

#### Scenario: Operator declines reclassification
- **WHEN** the prompt is shown and the operator picks `3` or enters `q` or empty input
- **THEN** the project's `project_type_code` and `project_type_label` are unchanged
- **AND** the script exits with code 0

### Requirement: Reclassification updates both code and label atomically

The script SHALL update BOTH `meta_info.project_type_code` and
`meta_info.project_type_label` in the project's `init_progress_definition.yaml`
in the same write whenever the operator picks B or C at the reclassification
prompt. The label MUST come from the same `code → label` mapping used by
`project_setup_add_new_project.sh` (A: "New project", B: "Existing project
with partial context", C: "Existing project with code-first context"). All
other content in the file (including the freshly written `class_repo_paths`
entry) MUST be preserved.

#### Scenario: Reclassify to B
- **WHEN** the operator picks `1` at the reclassification prompt
- **THEN** `project_type_code` becomes `"B"` and `project_type_label` becomes `"Existing project with partial context"`
- **AND** the `class_repo_paths` block written by the attach step is unchanged
- **AND** the script exits with code 0

#### Scenario: Reclassify to C
- **WHEN** the operator picks `2` at the reclassification prompt
- **THEN** `project_type_code` becomes `"C"` and `project_type_label` becomes `"Existing project with code-first context"`
- **AND** the script exits with code 0

#### Scenario: Invalid input re-prompts
- **WHEN** the operator enters a value other than `1`, `2`, `3`, `q`, or empty
- **THEN** the script re-prompts without mutating the file

### Requirement: Operator-visible warning about stale type-A artifacts after reclassification

When the script reclassifies a project from `A` to `B` or `C`, it SHALL print
an informational message stating that previously generated type-A artifacts
(stack blueprints, contract documents, surface maps) under the project tree
are not removed or rewritten by this script and may need to be regenerated
manually. The message SHALL NOT be printed when the operator declines the
reclassification.

#### Scenario: Warning printed on successful reclassification
- **WHEN** the script reclassifies the project from A to B or C
- **THEN** an informational message about stale type-A artifacts is printed to stderr before exit
- **AND** the script exits with code 0

#### Scenario: Warning suppressed when operator declines
- **WHEN** the operator picks "Keep type A and finish" at the reclassification prompt
- **THEN** no stale-artifact warning is printed
