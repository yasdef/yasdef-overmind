## Why

ASDLC project progress currently depends on `overmind/scripts/init_progress_scanner.sh` in the source repository layout, not on staged commands inside an initialized `/asdlc` workspace. This makes project-specific progress checks inconsistent for machine-local ASDLC usage, especially when status must be evaluated from a specific `/asdlc/projects/<project>/init_progress_definition.yaml`.

## What Changes

- Move progress scanner ownership from `overmind/scripts/init_progress_scanner.sh` to `overmind/scripts/project_mgmt/init_progress_scanner.sh`.
- Update first-machine ASDLC initialization to stage this scanner into `/asdlc/.commands/` alongside other project-management helpers.
- Add scanner invocation support that accepts a target project path under `/asdlc/projects/` and evaluates progress from that project’s `init_progress_definition.yaml`.
- Ensure scanner output represents the selected project’s current step state (not repository-global metadata).
- **BREAKING**: direct invocation path `overmind/scripts/init_progress_scanner.sh` is replaced by the project-management location/staged command flow.
- Add/update tests for script relocation, `.commands` staging, project-path validation, and per-project progress state rendering.

## Capabilities

### New Capabilities

- `overmind-asdlc-project-progress-command-staging`: ASDLC first-init flow SHALL stage the progress scanner command into `/asdlc/.commands/` for local project management operations.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: Scanner requirements SHALL support project-scoped evaluation using a provided `/asdlc/projects/<project>` path and that project’s `init_progress_definition.yaml`.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  - `overmind/scripts/init_progress_scanner.sh` (source relocation and/or compatibility handling)
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh` (new canonical location)
- Affected staged command output:
  - `/asdlc/.commands/init_progress_scanner.sh`
- Affected ASDLC runtime inputs:
  - `/asdlc/projects/<project>/init_progress_definition.yaml`
- Affected tests:
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected documentation:
  - `overmind/README.md` (scanner location and usage in initialized ASDLC workspaces)
