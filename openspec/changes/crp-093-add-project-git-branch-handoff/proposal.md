## Why

`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` currently writes ASDLC metadata and project workspace changes directly into whatever branch the operator is on. That makes add-project runs easy to mix into unrelated work and leaves no guided handoff for bringing the generated changes back to `main`.

## What Changes

- Update `project_setup_add_new_project.sh` to create and switch to a dedicated git branch before it performs any ASDLC file or folder mutations for a new project.
- Require the add-project flow to keep all generated metadata and project workspace changes on that dedicated branch instead of writing them on the caller's current branch.
- After the script finishes creating the new project artifacts, create a local commit on the dedicated branch that captures the add-project changes.
- Print a completion handoff message that is visually highlighted so it is hard to miss, tells the operator which branch is currently checked out, and presents the merge-back command for `main` distinctly from the surrounding explanatory text.
- Keep the flow non-destructive: do not reset existing branches or introduce new CLI flags/options.

## Capabilities

### New Capabilities
- `overmind-asdlc-project-git-branch-handoff`: Add-project flow SHALL create a dedicated branch before mutating ASDLC state, commit the resulting changes on that branch when setup succeeds, and print a visually emphasized final handoff that includes the active branch name plus a separately presented `git checkout main && git merge <branch_name>` command.

### Modified Capabilities
- None.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `overmind/README.md`
- Affected systems:
  - Local git branch state and commit history for repositories where add-project runs
- No new CLI flags/options are introduced.
