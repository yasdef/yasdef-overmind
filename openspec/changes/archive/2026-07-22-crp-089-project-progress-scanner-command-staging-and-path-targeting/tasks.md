## 1. Relocate scanner script ownership to project management

- [x] 1.1 Move scanner implementation from `overmind/scripts/init_progress_scanner.sh` to `overmind/scripts/project_mgmt/init_progress_scanner.sh`.
- [x] 1.2 Update internal script constants and path resolution to support project-scoped definition lookup from `<project-path>/init_progress_definition.yaml`.
- [x] 1.3 Update scanner callers/documentation to use only canonical scanner ownership under `overmind/scripts/project_mgmt/`.

## 2. Add project-path-targeted scanner execution contract

- [x] 2.1 Implement argument parsing for scanner project path input and normalize/validate target path under `/asdlc/projects/`.
- [x] 2.2 Add fail-fast error behavior for invalid project path and missing `init_progress_definition.yaml`.
- [x] 2.3 Ensure rendered scanner output reflects progress state for the selected project only.

## 3. Stage scanner command during ASDLC first-init bootstrap

- [x] 3.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to include scanner script in staged commands copied to `/asdlc/.commands/`.
- [x] 3.2 Ensure staged scanner script is executable after staging.
- [x] 3.3 Update generated quick-run documentation to include scanner command usage with `/asdlc/projects/<project-id>` path input.

## 4. Extend automated tests for relocation, staging, and project-scoped scanning

- [x] 4.1 Update `tests/ai_scripts/init_progress_scanner_tests.sh` to target new canonical scanner path and project-path invocation behavior.
- [x] 4.2 Add scanner tests for path validation (outside `/asdlc/projects/` and missing project definition).
- [x] 4.3 Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` to assert scanner command is staged in `/asdlc/.commands/` and runnable with a project path.

## 5. Update docs and validate artifact readiness

- [x] 5.1 Update `overmind/README.md` usage guidance for scanner relocation and project-path-based scanning from staged ASDLC commands.
- [x] 5.2 Run relevant script test suites from repository root (`init_progress_scanner_tests.sh`, `project_setup_asdlc_tests.sh`).
- [x] 5.3 Run `openspec status --change crp-089-project-progress-scanner-command-staging-and-path-targeting` and confirm all artifacts are complete/apply-ready.
