## Why

The e2e feature orchestrator runs long multi-phase pipelines without preserving intermediate state in git. This means optional phases (5.1, 7.1, 8.4) can alter artifacts with no recovery point if the user needs to revert or inspect state before/after those phases ran.

## What Changes

- Add a `commit_feature_progress` helper to `project_add_feature_e2e.sh` that stages all changes in the ASDLC workspace and creates a labeled git commit.
- Call the helper before phase 5.1 (before Optional EARS Review).
- Call the helper before phase 7.1 (before Optional MCP Placeholder Enrichment).
- Call the helper before phase 8.4 (before Optional Implementation Plan Semantic Review).
- Call the helper after phase 8.4 completes (after Optional Semantic Review).
- Skip the commit silently when there is nothing to commit or when the workspace is not a git repository.

## Capabilities

### New Capabilities

- `e2e-orchestrator-checkpoint-commits`: Git checkpoint commits inserted at defined phase boundaries in the feature orchestrator so intermediate pipeline state is preserved in version history.

### Modified Capabilities

## Impact

- `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: new helper function + four call sites in the main phase loop.
- No changes to individual feature scripts, tests, or docs.
