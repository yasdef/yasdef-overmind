## 1. Localize ASDLC template during machine bootstrap

- [x] 1.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to create `asdlc/templates` as part of bootstrap directory structure.
- [x] 1.2 Copy canonical `init_progress_definition_TEMPLATE.yaml` into `asdlc/templates/init_progress_definition_TEMPLATE.yaml` during successful bootstrap.
- [x] 1.3 Add fail-fast error path when canonical template source is missing.

## 2. Extend add-project flow for project record registration

- [x] 2.1 Update `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` to resolve ASDLC-local paths from staged command location.
- [x] 2.2 Prompt for project name, normalize it for filesystem-safe folder naming, and validate non-empty result.
- [x] 2.3 Generate one project id and created timestamp; append a new entry to `asdlc/asdlc_metadata.yaml` under top-level `projects` using schema keys `project`, `name`, `internal_folder`, `created_at`.
- [x] 2.4 Ensure appended metadata record reuses the same project id used for project workspace folder naming.

## 3. Create project workspace and seed initial definition file

- [x] 3.1 Create `asdlc/projects/<project-id>` for each successful add-project operation.
- [x] 3.2 Copy `asdlc/templates/init_progress_definition_TEMPLATE.yaml` into `<project-folder>/init_progress_definition.yaml`.
- [x] 3.3 Implement fail-fast behavior when local ASDLC template is missing to avoid partial project creation.

## 4. Update tests and validate change readiness

- [x] 4.1 Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` with coverage for template localization in first-machine bootstrap.
- [x] 4.2 Extend tests for add-project metadata append, project-id reuse across metadata/folder, and project folder seed file generation.
- [x] 4.3 Add negative-path tests for missing local template and invalid/empty project name normalization.
- [x] 4.4 Run targeted script test suite(s) from repository root.
- [x] 4.5 Run `openspec status --change crp-087-add-project-record-and-feature-folder-bootstrap` to confirm artifacts are complete and apply-ready.
