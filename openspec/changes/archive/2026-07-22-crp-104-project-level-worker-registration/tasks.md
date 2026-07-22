## 1. Add the project-level register-worker command

- [x] 1.1 Add `overmind/scripts/project_mgmt/project_register_worker.sh` with required `--path <asdlc/projects/<project-id>>` parsing and fail-fast validation for missing or invalid project paths.
- [x] 1.2 Load canonical `project_id` from `<project-path>/init_progress_definition.yaml`, fail clearly when project metadata is missing, and create `<project-path>/workers.yaml` scaffold only when absent.
- [x] 1.3 Implement the interactive one-class chooser restricted to `backend`, `frontend`, `mobile`, and `infrastructure`, with deterministic retry behavior for invalid input.
- [x] 1.4 Generate a UUID and registration timestamp, append one new worker entry with `status: active`, preserve existing file content, and print the required final handoff message with the generated UUID.

## 2. Stage and document the new command

- [x] 2.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so bootstrap and update flows stage `project_register_worker.sh` into `<asdlc>/.commands/`.
- [x] 2.2 Update staged usage guidance and `overmind/README.md` to document `project_register_worker.sh --path <asdlc/projects/<project-id>>`, `workers.yaml`, and the worker metadata fields.

## 3. Add regression coverage

- [x] 3.1 Add a shell test suite under `tests/ai_scripts/` covering missing `--path`, invalid project path, missing project metadata, first-run `workers.yaml` creation, and repeated registration append behavior.
- [x] 3.2 Add shell tests covering invalid class retry behavior, allowed class normalization, persisted `active` status and registration date, and the exact final success message.
- [x] 3.3 Update existing staging/bootstrap tests as needed to verify `project_register_worker.sh` is copied into ASDLC workspaces and documented in staged command guidance.

## 4. Validate OpenSpec readiness

- [x] 4.1 Run the relevant `tests/ai_scripts/` suites from repository root after implementation.
- [x] 4.2 Run `openspec status --change crp-104-project-level-worker-registration` and confirm the change remains apply-ready.
