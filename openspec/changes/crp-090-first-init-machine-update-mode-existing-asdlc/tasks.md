## 1. Add update-mode detection for initialized ASDLC homes

- [x] 1.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to detect existing `asdlc/` plus `asdlc_metadata.yaml` and switch into update mode.
- [x] 1.2 Print the required informational message when update mode is entered and preserve fail-fast behavior for existing `asdlc/` roots that do not contain metadata.
- [x] 1.3 Ensure update mode does not rewrite existing metadata, templates, or project content.

## 2. Repair missing staged commands in `.commands`

- [x] 2.1 Ensure update mode creates `asdlc/.commands/` when it is missing.
- [x] 2.2 Backfill any absent required staged command scripts: `project_setup_add_new_project.sh`, `project_setup_update_project.sh`, `init_progress_scanner.sh`, and `init_common_contract_definition.sh`.
- [x] 2.3 Reuse staged-command rewrite logic so restored scripts default to `<selected_parent>/asdlc/projects` without overwriting already present command files.

## 3. Update tests and documentation

- [x] 3.1 Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` to cover update-mode detection, informational messaging, missing-command restoration, and preservation of existing staged command files.
- [x] 3.2 Add or update a test for the failure path where `asdlc/` exists without `asdlc_metadata.yaml`.
- [x] 3.3 Update `overmind/README.md` to describe the first-init-machine update mode and `.commands` repair behavior.

## 4. Validate change readiness

- [x] 4.1 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` from the repository root.
- [x] 4.2 Run `openspec status --change crp-090-first-init-machine-update-mode-existing-asdlc` and confirm the change is apply-ready.
