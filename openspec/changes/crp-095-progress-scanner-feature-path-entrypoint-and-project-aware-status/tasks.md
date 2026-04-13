## 1. Replace scanner CLI contract

- [x] 1.1 Update `overmind/scripts/project_mgmt/init_progress_scanner.sh` to remove positional project-path parsing and scanner-local `--feature_path` support.
- [x] 1.2 Add required `--path <path/to/feature>` parsing with clear fail-fast errors for missing values and unknown arguments.
- [x] 1.3 Validate that `--path` resolves to a feature-level folder under `asdlc/projects/<project-id>` and reject project-root-only or out-of-tree paths.

## 2. Infer project root and keep mixed-scope evaluation

- [x] 2.1 Implement project-root inference from the selected feature folder by locating the owning project folder that contains `init_progress_definition.yaml`.
- [x] 2.2 Keep project-scoped checklist artifacts, definition loading, and `step_state.md` writes anchored at the inferred project root.
- [x] 2.3 Remap logical product-root checklist targets and feature-heading metadata lookup to the selected feature folder for the current invocation.
- [x] 2.4 Ensure Step 3 and other feature-scoped checks use only the selected feature folder and do not read artifacts from sibling feature folders.

## 3. Update staged usage documentation

- [x] 3.1 Update quickrun output in `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so scanner examples use `--path <path/to/feature>`.
- [x] 3.2 Update `overmind/README.md` to describe feature-folder `--path` usage, project inference, and the combined project-level plus feature-level checklist behavior.
- [x] 3.3 Remove or rewrite scanner-specific references that still describe optional `--feature_path` behavior.

## 4. Extend automated coverage

- [x] 4.1 Update `tests/ai_scripts/init_progress_scanner_tests.sh` for the new `--path` contract and remove coverage tied to positional project path or scanner `--feature_path`.
- [x] 4.2 Add scanner tests for missing `--path`, project-root rejection, out-of-tree rejection, and project-root inference from a selected feature folder.
- [x] 4.3 Add scanner tests proving project-level artifacts are still evaluated from project root while feature-level artifacts resolve from the selected feature folder only.
- [x] 4.4 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` assertions so staged scanner usage matches the new feature-level `--path` entrypoint.

## 5. Validate change readiness

- [x] 5.1 Run `bash tests/ai_scripts/init_progress_scanner_tests.sh` from the repository root.
- [x] 5.2 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` from the repository root.
- [x] 5.3 Run `openspec status --change crp-095-progress-scanner-feature-path-entrypoint-and-project-aware-status` and confirm the change is apply-ready.
