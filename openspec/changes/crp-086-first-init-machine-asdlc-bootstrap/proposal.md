## Why

`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` is currently a placeholder, so there is no first-time machine bootstrap for ASDLC workspace structure and no standardized local command staging for create/update project flows. This blocks consistent onboarding and repeatable local usage.

## What Changes

- Implement `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` as an interactive machine-bootstrap script.
- Prompt user for the directory where ASDLC workspace should be placed.
- Validate provided path (non-empty, valid/creatable target, writable location) before continuing.
- Create `<selected_dir>/asdlc` and fail fast with a meaningful non-zero error if this ASDLC directory already exists.
- Create simple metadata YAML scaffold under ASDLC root for future values, including keys for:
  - project name
  - project artefacts subfolder (must be inside `asdlc`)
  - project unique id
- Create ASDLC project root folder `asdlc/projects` as canonical default workspace for project artefacts.
- Copy these scripts into `asdlc/.commands`:
  - `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh`
- Adjust copied command scripts to use `asdlc/projects` as their default working folder for project operations.
- Create `asdlc/quickrun.md` documenting fast local execution of the two staged commands (`create project`, `update project`).
- Add/update tests for first-init-machine bootstrap flow, fail-fast behavior when `asdlc` already exists, command copy/staging, default-path wiring, and quickrun generation.

## Capabilities

### New Capabilities

- `overmind-asdlc-machine-home-bootstrap`: First-init-machine flow SHALL create and validate ASDLC workspace root, metadata scaffold, project default folder, staged command copies, and quick-run guidance.
- `overmind-asdlc-local-command-staging`: First-init-machine flow SHALL prepare local `.commands` scripts for create/update project operations with default project folder set to `asdlc/projects`.

### Modified Capabilities

- None.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` (copy-time default path behavior in staged version)
  - `overmind/scripts/project_mgmt/project_setup_update_project.sh` (copy-time default path behavior in staged version)
- Affected generated filesystem layout (runtime output):
  - `<selected_dir>/asdlc/`
  - `<selected_dir>/asdlc/projects/`
  - `<selected_dir>/asdlc/.commands/`
  - `<selected_dir>/asdlc/quickrun.md`
  - metadata YAML scaffold under `<selected_dir>/asdlc/`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh` (or split first-init-specific suite if introduced)
- Affected docs:
  - `overmind/README.md` for first-init-machine usage and local staged command flow
- No new CLI flags/options are introduced.
