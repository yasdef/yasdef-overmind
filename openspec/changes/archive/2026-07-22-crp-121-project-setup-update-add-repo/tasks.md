## 1. Extract the four shared helpers into `overmind/scripts/common_libs/`

- [x] 1.1 Create `overmind/scripts/common_libs/project_setup_common.sh` containing exactly four helpers — `validate_repo_path`, `resolve_repo_path`, `project_type_label_for_code`, `escape_yaml_double_quoted_value` — with their current bodies copied verbatim from `project_setup_add_new_project.sh`. No `set -euo pipefail` (the sourcing scripts own that), no signature changes, no extra helpers.
- [x] 1.2 In `project_setup_add_new_project.sh`, delete the four extracted function definitions and add a single `source "$(dirname "$0")/../common_libs/project_setup_common.sh"` line near the top (after `set -euo pipefail` / global constants, before any function that calls them). No other edits to that file.
- [x] 1.3 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` to confirm add-new behavior is unchanged.

## 2. Implement the update script

- [x] 2.1 Rewrite `overmind/scripts/project_mgmt/project_setup_update_project.sh` to source `overmind/scripts/common_libs/project_setup_common.sh`, parse args (none — interactive only), and call a new `main` function.
- [x] 2.2 Implement `discover_projects` that scans `projects/*/init_progress_definition.yaml`, extracts `project_id` and `project_type_code` from each, and returns a newline-delimited list of `<project_id>|<project_type_code>|<definition_path>`.
- [x] 2.3 Implement `prompt_project_selection` that prints the numbered list, accepts a 1-based index, accepts `q`/`Q` (exit 0), and re-prompts on invalid input; returns the selected `<definition_path>` and `<project_id>`.
- [x] 2.4 Implement `read_deferred_classes` that parses the chosen YAML's `class_repo_paths:` block and returns class names whose entry has `state: "deferred"`. Honor the same indentation contract assumed by `assert_metadata_shape` and `inject_project_bootstrap_into_definition`.
- [x] 2.5 Implement `prompt_class_selection`: numbered list of deferred classes, `q` exits 0, "no deferred classes" message + exit 0 when the list is empty.
- [x] 2.6 Implement `prompt_repo_path_with_quit` mirroring `prompt_repo_path_for_class` but checking `q`/`Q` BEFORE `validate_repo_path`; on validation failure re-prompt; on success return the resolved absolute path.
- [x] 2.7 Implement `assert_class_entry_is_deferred` that fails fast with a clear error if the chosen class entry does not match the expected `state: "deferred"` shape.
- [x] 2.8 Implement `flip_class_to_ready` that performs the targeted in-place edit (state and path lines for the chosen class only) using a temp file + `mv`, preserving the rest of the file byte-for-byte.
- [x] 2.9 Implement `is_all_classes_ready` and `read_project_type_code` that re-read the file after the attach and decide whether to show the reclassification prompt.
- [x] 2.10 Implement `prompt_reclassification` (options 1=B, 2=C, 3/empty/`q`=keep) and, on B or C, `update_project_type_code_and_label` writing both lines in a single temp-file + `mv` transaction.
- [x] 2.11 On successful B/C reclassification, print the stale-type-A-artifacts informational message to stderr.
- [x] 2.12 Wire `main` to: discover → prompt project → prompt class → prompt path → assert shape → flip class to ready → conditional reclassification → exit 0.

## 3. Tests

- [x] 3.1 Create `tests/ai_scripts/project_setup_update_project_tests.sh` with the standard helper scaffolding used by the existing `project_setup_*_tests.sh` suites (temp dir, fake `projects/<id>/init_progress_definition.yaml` fixtures generated via `project_setup_add_new_project.sh` or by direct file write).
- [x] 3.2 Test: quit at project prompt exits 0 and leaves the YAML byte-identical.
- [x] 3.3 Test: quit at class prompt exits 0 and leaves the YAML byte-identical.
- [x] 3.4 Test: quit at path prompt exits 0 and leaves the YAML byte-identical.
- [x] 3.5 Test: empty / non-existent / non-directory / empty-directory paths each re-prompt without exiting and without mutating the file; a subsequent valid path on the same run completes successfully.
- [x] 3.6 Test: only `deferred` classes appear in the class prompt; a project with all classes already `ready` skips straight to the reclassification flow (or to "nothing to add" when not type A).
- [x] 3.7 Test: successful attach flips exactly two lines (`state` + `path`) for the chosen class; every other line in the file is unchanged (verify via `diff` against the pre-attach snapshot scoped to the unchanged regions).
- [x] 3.8 Test: shape-mismatch (manually corrupted entry) aborts non-zero and leaves the file untouched.
- [x] 3.9 Test: type-A project, last `deferred` class becomes `ready` → reclassification prompt is shown; selecting `1` writes `project_type_code: "B"` and the matching label; selecting `2` writes `"C"`; selecting `3`, empty, or `q` keeps `"A"`.
- [x] 3.10 Test: type-A project, attach succeeds but at least one other class is still `deferred` → no reclassification prompt is shown.
- [x] 3.11 Test: type-B or type-C project, even when all classes are `ready` after the attach → no reclassification prompt is shown.
- [x] 3.12 Test: stale-artifacts warning is emitted on successful B/C reclassification and suppressed when the operator declines.

## 4. Docs and registration

- [x] 4.1 Update `overmind/README.md` where it documents project-setup option 3 to reflect the implemented behavior (replace any "not implemented" wording).
- [x] 4.2 Append `bash tests/ai_scripts/project_setup_update_project_tests.sh` to the test command list in `CLAUDE.md`.

## 5. Validation

- [x] 5.1 Run `bash tests/ai_scripts/project_setup_update_project_tests.sh` and confirm a green run.
- [x] 5.2 Run `openspec validate crp-121-project-setup-update-add-repo` to confirm the change still validates after any spec touch-ups discovered during implementation.
