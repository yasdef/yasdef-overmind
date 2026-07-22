## Why

`init_progress_scanner.sh` currently writes one project-root `step_state.md` even though each scan is run for one selected feature path. Once a project has multiple feature folders, that single filename becomes a last-scan cache that can silently overwrite another feature's status and misrepresent project progress.

## What Changes

- Change scanner persistence from one shared project-root `step_state.md` to one project-root file per selected feature: `step_state_<feature-folder>.md`.
- Keep scanner invocation feature-scoped through `--path <path/to/feature>` and derive the persisted filename from the selected feature folder passed to that command.
- Keep checklist rendering semantics unchanged for one scan: project-level tasks plus the selected feature's task section and one canonical final `next step` line.
- Keep stdout output byte-identical to the persisted file content for the selected feature context.
- Update any orchestrator, docs, and tests that currently assume one shared `step_state.md` filename at project root.
- **BREAKING**: any consumer that reads or watches `<project>/step_state.md` as the persisted scanner artifact will need to resolve the selected feature-specific filename instead.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `overmind-bootstrap-progress-checklist`: change the persisted scanner artifact contract from one shared project-root `step_state.md` to feature-specific project-root `step_state_<feature-folder>.md` while preserving selected-feature checklist content and stdout parity

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
  - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
- Affected tests:
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/project_add_feature_e2e_tests.sh`
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `README.md`
- Affected runtime artifacts:
  - `projects/<project-id>/step_state.md` replaced by `projects/<project-id>/step_state_<feature-folder>.md`
