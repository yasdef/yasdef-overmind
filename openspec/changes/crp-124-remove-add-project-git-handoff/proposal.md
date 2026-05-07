## Why

`project_setup_add_new_project.sh` currently contains ASDLC-local git orchestration that creates branches, enforces `main`, auto-commits generated files, and prints a merge-back handoff. That behavior is no longer wanted; the command should only create project scaffolding and leave any git workflow to the operator.

## What Changes

- Remove add-project git prerequisites from `project_setup_add_new_project.sh`, including git-repository validation, `main`-branch enforcement, clean-worktree enforcement, deterministic `add-project/<project_id>` branch creation, scoped auto-commit, and merge-back handoff output.
- Keep add-project focused on staged ASDLC filesystem mutations only: create the project folder, seed `init_progress_definition.yaml`, and append the project record to `asdlc_metadata.yaml`.
- Update shell coverage so add-project succeeds without `.git`, succeeds with dirty worktree state, and leaves surrounding git branch/HEAD state untouched when run inside a git repo.
- Update operator-facing docs to remove branch/merge guidance and describe the in-place add-project behavior.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `overmind-asdlc-project-git-branch-handoff`: remove the branch/commit/handoff contract and replace it with in-place, non-git add-project behavior

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `README.md`
- Affected systems:
  - ASDLC add-project workflow behavior and local git side effects during project creation
