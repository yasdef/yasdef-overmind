## ADDED Requirements

### Requirement: Add-project flow SHALL create a dedicated branch before mutating ASDLC state
`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` SHALL create and switch to a new local branch named `add-project/<project_id>` before it writes `asdlc_metadata.yaml` or creates `projects/<project_id>/`.

#### Scenario: Successful run branches before file creation
- **WHEN** the operator completes add-project input collection for a new project and git preconditions are satisfied
- **THEN** the script SHALL create and checkout branch `add-project/<project_id>` before appending the project record or creating the project folder

#### Scenario: Generated branch name collision fails safely
- **WHEN** branch `add-project/<project_id>` already exists in the ASDLC repository
- **THEN** the script SHALL exit non-zero
- **AND** SHALL not reset, reuse, or overwrite that existing branch

### Requirement: Add-project flow SHALL fail fast when git prerequisites for auto-commit are unsafe
Before creating the dedicated branch, the add-project flow SHALL verify that the ASDLC root is a git repository, local branch `main` exists, and the working tree plus index are clean.

#### Scenario: Main branch is unavailable
- **WHEN** the operator runs add-project in an ASDLC repository that does not have local branch `main`
- **THEN** the script SHALL exit non-zero with an explicit git prerequisite error
- **AND** SHALL not create `add-project/<project_id>`

#### Scenario: Working tree is dirty
- **WHEN** tracked or staged changes already exist in the ASDLC repository before add-project creates its branch
- **THEN** the script SHALL exit non-zero with an explicit clean-worktree requirement error
- **AND** SHALL not create `add-project/<project_id>`

### Requirement: Add-project flow SHALL commit generated project changes on the dedicated branch
After successfully creating the new project record and workspace, the add-project flow SHALL create a local commit on branch `add-project/<project_id>` that stages only `asdlc_metadata.yaml` and `projects/<project_id>/`.

#### Scenario: Successful run creates scoped commit
- **WHEN** add-project completes metadata update and project workspace bootstrap successfully
- **THEN** the script SHALL create a local commit on `add-project/<project_id>`
- **AND** SHALL leave the ASDLC repository checked out on `add-project/<project_id>`
- **AND** that commit SHALL include the `asdlc_metadata.yaml` change and the new `projects/<project_id>/` contents

#### Scenario: Failed project creation does not produce a success commit
- **WHEN** add-project fails before all project artifacts are created successfully
- **THEN** the script SHALL not print a success handoff message
- **AND** SHALL not report that the add-project commit was completed

### Requirement: Add-project flow SHALL print a highlighted main-branch handoff reminder
On successful completion, the add-project flow SHALL render a visually emphasized handoff block. That block SHALL include the reminder text `you're in branch <branch_name> now, dont forget to commit changes to main branch with` and SHALL present `git checkout main && git merge <branch_name>` on its own differentiated line where `<branch_name>` is the checked-out add-project branch.

#### Scenario: Success output includes highlighted reminder and separated command
- **WHEN** add-project finishes successfully on branch `add-project/<project_id>`
- **THEN** the script SHALL print a visually emphasized handoff reminder containing `you're in branch add-project/<project_id> now, dont forget to commit changes to main branch with`
- **AND** SHALL present `git checkout main && git merge add-project/<project_id>` on its own differentiated output line
