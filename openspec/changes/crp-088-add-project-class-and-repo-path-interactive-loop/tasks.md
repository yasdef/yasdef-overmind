## 1. Implement project class selection loop in add-project flow

- [x] 1.1 Update `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` to prompt class options `1..5` and continue until user selects `5`.
- [x] 1.2 Map numeric selections to canonical class values (`backend`, `frontend`, `mobile`, `infrastructure`) and reject invalid selections with retry prompt.
- [x] 1.3 Remove already selected classes from subsequent prompt options and print running summary of already added classes after each accepted add.

## 2. Implement per-class repo path readiness and capture loop

- [x] 2.1 After class selection, iterate selected classes and ask readiness question (`1 ready`, `2 later`) for each class.
- [x] 2.2 For readiness `1`, prompt repo path and validate path exists, is a directory, and is non-empty; re-prompt on validation failure.
- [x] 2.3 For readiness `2`, persist deferred state for that class without path.

## 3. Extend project definition metadata persistence schema

- [x] 3.1 Extend project-definition write logic in `project_setup_add_new_project.sh` to persist `meta_info.project_classes` for each created project.
- [x] 3.2 Persist class-scoped repo path capture state (path or deferred) under `meta_info.class_repo_paths`.
- [x] 3.3 Ensure `asdlc/asdlc_metadata.yaml` project records remain minimal while generated project definition metadata remains stable and deterministic.

## 4. Update tests and documentation

- [x] 4.1 Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` for class selection loop completion, shrinking menu behavior, and running summary behavior.
- [x] 4.2 Add tests for per-class readiness flow including valid path capture, deferred choice, and invalid path retry.
- [x] 4.3 Update `overmind/README.md` to document new add-project class/path interactive onboarding.

## 5. Validate change readiness

- [x] 5.1 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` from repository root.
- [x] 5.2 Run `openspec status --change crp-088-add-project-class-and-repo-path-interactive-loop` to confirm artifacts are complete and apply-ready.
