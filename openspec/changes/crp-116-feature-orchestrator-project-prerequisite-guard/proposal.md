## Why

`project_add_feature_e2e.sh` relies on `init_progress_scanner.sh` for workflow state, but scanner results for project-level unfinished steps currently surface as a generic unmapped-step error. This makes type A Step `1.1` gaps and Step `2` gaps harder to diagnose when the feature orchestrator is started too early.

## What Changes

- Keep `init_progress_scanner.sh` as the source of truth for completion and next-step selection.
- Update `project_add_feature_e2e.sh` so scanner results earlier than its first supported feature step fail with a meaningful prerequisite message.
- Do not change scanner path semantics; scanner still receives a feature-level path.
- Do not add a project-level pre-scaffold scanner mode in this change.
- Preserve existing Step `3` and later feature orchestration behavior when scanner returns a supported step.

## Capabilities

### New Capabilities

- `overmind-feature-orchestrator-project-prerequisite-guard`: The feature orchestrator SHALL detect scanner-reported steps earlier than its first supported feature step and stop with clear project-prerequisite guidance instead of a generic unmapped-step error.

### Modified Capabilities

- None.

## Impact

- Affected script:
  - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
- Affected tests:
  - `tests/ai_scripts/project_add_feature_e2e_tests.sh`
- No changes expected to:
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
  - staged command manifests
  - existing step script CLIs
