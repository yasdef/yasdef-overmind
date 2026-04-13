## Why

`project_add_feature_e2e.sh` currently remembers only one active `feature_path` per project in `.project_add_feature_e2e_state.env`. That works for the first feature in a project, but it becomes ambiguous once the same project has multiple feature folders and the operator wants to resume one of them or start another without manually deleting or rewriting state.

## What Changes

- Update the project-level feature orchestrator startup flow so it discovers feature folders under the selected project instead of relying only on the saved state file.
- Add an initial operator decision at project scope:
  - start a new feature;
  - continue an existing unfinished feature.
- When continuing, list only unfinished features for that project and show each feature's current scanner-reported next step.
- When starting a new feature, run scaffold as today and set the newly created feature as the active run target.
- Keep `.project_add_feature_e2e_state.env`, if retained, as a convenience cache for the most recently selected feature rather than the sole source of truth for project feature selection.
- Ensure resume behavior remains deterministic after a feature is selected, including `--resume <step>` handling against the selected feature.
- Document the new same-project multi-feature behavior and add regression coverage for discovery, selection, and isolation between feature runs.

## Capabilities

### New Capabilities
- `overmind-project-feature-selection`: Project-scoped feature orchestration can discover feature folders, distinguish unfinished versus completed features from scanner status, and let the operator choose between continuing unfinished work and starting a new feature.

### Modified Capabilities
- `overmind-bootstrap-progress-checklist`: Scanner output becomes the canonical status source for project-level unfinished-feature listing and operator selection messaging.

## Impact

- Affected code:
  - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
- Affected docs:
  - `overmind/README.md`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
- Affected tests:
  - `tests/ai_scripts/project_add_feature_e2e_tests.sh`
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
- Affected runtime state:
  - `projects/<project-id>/.project_add_feature_e2e_state.env`
- Operator impact:
  - running the feature orchestrator against a project with multiple feature folders no longer silently resumes the last saved feature
  - same-project multi-feature work becomes explicit and safer
