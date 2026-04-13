## Why

`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` currently fails whenever `<selected_parent>/asdlc` already exists. That blocks a valid maintenance case where the user points the script at an existing ASDLC home that already has `asdlc_metadata.yaml` and only needs missing staged commands restored.

## What Changes

- Change `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so it detects update mode when the user-selected parent already contains `asdlc/` and `asdlc/asdlc_metadata.yaml`.
- Print this informational message when update mode is triggered: `asdlc folder already exists, switch to update mode`.
- In update mode, keep the existing ASDLC workspace in place instead of failing fast.
- Verify that `<selected_parent>/asdlc/.commands/` contains every staged shell script the first-init flow is responsible for.
- Backfill any missing staged shell scripts into `.commands`:
  - `project_setup_add_new_project.sh`
  - `project_setup_update_project.sh`
  - `init_progress_scanner.sh`
  - `init_common_contract_definition.sh`
- Preserve the current staged-command defaults so newly added scripts still target `<selected_parent>/asdlc/projects`.
- Leave existing metadata and already-present staged commands untouched unless they are absent.
- Update docs and script tests to cover update-mode detection, informational messaging, and missing-command restoration.

## Capabilities

### New Capabilities

- `overmind-asdlc-machine-home-update-mode`: First-init-machine flow can recognize an already initialized ASDLC home and continue in update mode instead of exiting.
- `overmind-asdlc-command-staging-repair`: First-init-machine flow can audit `.commands` and restore any missing staged shell scripts required for local ASDLC project management.

### Modified Capabilities

- None.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - staged outputs under `<selected_parent>/asdlc/.commands/`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `overmind/README.md`
- No new CLI flags/options are introduced.
