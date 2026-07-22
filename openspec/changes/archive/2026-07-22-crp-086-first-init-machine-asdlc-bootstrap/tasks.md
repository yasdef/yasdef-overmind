## 1. Implement first-machine ASDLC bootstrap flow

- [x] 1.1 Replace placeholder logic in `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` with interactive bootstrap flow.
- [x] 1.2 Prompt for ASDLC parent directory and validate non-empty, creatable/resolvable, and writable path before mutations.
- [x] 1.3 Implement fail-fast behavior when target `asdlc` folder already exists with meaningful non-zero error.
- [x] 1.4 Create bootstrap structure: `asdlc/`, `asdlc/projects/`, and `asdlc/.commands/`.

## 2. Create metadata scaffold and local staged command setup

- [x] 2.1 Create metadata YAML scaffold under `asdlc` root with keys for project name, artefacts subfolder (inside asdlc), and project unique id.
- [x] 2.2 Copy `project_setup_add_new_project.sh` and `project_setup_update_project.sh` into `asdlc/.commands`.
- [x] 2.3 Ensure staged command copies default to `asdlc/projects` as project work folder.
- [x] 2.4 Preserve executable permissions for staged command scripts.

## 3. Add local quick-run documentation

- [x] 3.1 Generate `asdlc/quickrun.md` during bootstrap.
- [x] 3.2 Document fast execution for staged create-project and update-project commands.

## 4. Update docs and tests

- [x] 4.1 Update `overmind/README.md` with first-machine bootstrap behavior and generated ASDLC layout.
- [x] 4.2 Extend script tests to cover successful bootstrap, existing-`asdlc` fail-fast, and path validation failures.
- [x] 4.3 Add assertions for command-copy presence, default-path configuration to `asdlc/projects`, and `quickrun.md` generation.

## 5. Validate change readiness

- [x] 5.1 Run targeted test suite(s) from repository root for project management setup scripts.
- [x] 5.2 Run `openspec status --change crp-086-first-init-machine-asdlc-bootstrap` to confirm artifacts remain apply-ready after updates.
