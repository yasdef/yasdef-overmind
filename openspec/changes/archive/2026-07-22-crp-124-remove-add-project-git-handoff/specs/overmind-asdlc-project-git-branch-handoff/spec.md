## REMOVED Requirements

### Requirement: Add-project flow SHALL create a dedicated branch before mutating ASDLC state
**Reason**: add-project no longer owns git branch lifecycle in the staged ASDLC workspace.
**Migration**: Run add-project directly in the staged ASDLC workspace. If branch isolation is still desired, create and manage branches manually outside the command.

### Requirement: Add-project flow SHALL fail fast when git prerequisites for auto-commit are unsafe
**Reason**: add-project no longer performs automated git operations, so `main`-branch and clean-worktree gating is no longer part of the contract.
**Migration**: No workflow migration is required for add-project itself. Dirty worktrees and non-git staged workspaces remain valid inputs.

### Requirement: Add-project flow SHALL commit generated project changes on the dedicated branch
**Reason**: add-project no longer creates commits as part of project creation.
**Migration**: If operators want generated project scaffolding tracked in git, they must stage and commit it manually using their own repository workflow.

### Requirement: Add-project flow SHALL print a highlighted main-branch handoff reminder
**Reason**: the command no longer creates a branch or merge target, so merge-back instructions are no longer meaningful output.
**Migration**: No migration is required. Any branch/merge guidance now belongs to operator-managed workflow outside Overmind.

## ADDED Requirements

### Requirement: Add-project flow SHALL create project scaffolding without git prerequisites
`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` SHALL create the new project folder, seed `init_progress_definition.yaml`, and append the project record into `asdlc_metadata.yaml` without requiring the staged ASDLC workspace to be a git repository.

#### Scenario: Add-project succeeds without .git metadata
- **WHEN** the staged ASDLC workspace does not contain a `.git` directory
- **THEN** add-project SHALL still create `projects/<project_id>/`
- **AND** SHALL still write `projects/<project_id>/init_progress_definition.yaml`
- **AND** SHALL still append the new record to `asdlc_metadata.yaml`

#### Scenario: Add-project succeeds with dirty ASDLC worktree state
- **WHEN** the staged ASDLC workspace is inside a git repository whose tracked or untracked files already differ from HEAD
- **THEN** add-project SHALL still create the new project artifacts
- **AND** SHALL not fail on clean-worktree or base-branch prerequisites

### Requirement: Add-project flow SHALL leave ambient git state untouched
When the staged ASDLC workspace is inside a git repository, add-project SHALL NOT create or checkout a helper branch, SHALL NOT create a commit, and SHALL NOT print merge-handoff instructions.

#### Scenario: Existing branch and HEAD remain unchanged
- **WHEN** add-project succeeds inside a git-backed staged ASDLC workspace
- **THEN** the currently checked out branch name SHALL remain the same before and after execution
- **AND** the repository `HEAD` commit SHALL remain the same before and after execution
- **AND** no `add-project/*` branch SHALL be created by the command

#### Scenario: Success output is limited to created paths
- **WHEN** add-project completes successfully
- **THEN** the command SHALL print the created project-folder path
- **AND** SHALL print the updated metadata path
- **AND** SHALL NOT print an `ADD-PROJECT HANDOFF` block or merge-back command
