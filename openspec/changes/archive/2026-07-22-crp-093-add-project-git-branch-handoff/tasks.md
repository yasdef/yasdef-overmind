## 1. Add git precondition and branch helpers to add-project flow

- [x] 1.1 Update `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` to resolve the ASDLC git repository root and fail fast when git prerequisites are missing.
- [x] 1.2 Require local branch `main` and a clean ASDLC worktree/index before the script creates an add-project branch.
- [x] 1.3 Generate deterministic branch name `add-project/<project_id>` and create/switch to it before the first metadata or project-folder mutation.

## 2. Commit successful add-project mutations on the dedicated branch

- [x] 2.1 Keep project id generation available before filesystem writes so branch naming and project folder naming stay aligned.
- [x] 2.2 Stage only `asdlc_metadata.yaml` and `projects/<project_id>/` after successful project creation and create the add-project commit on the dedicated branch.
- [x] 2.3 Print the final reminder `you're in branch <branch_name> now, dont forget to commit changes to main branch with git checkout main && git merge <branch_name>` on successful completion only.
- [x] 2.4 Update the final handoff output so the reminder is visually highlighted and the `git checkout main && git merge <branch_name>` command is rendered on a distinct emphasized line.

## 3. Extend automated coverage for branch and commit behavior

- [x] 3.1 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` fixtures/helpers so ASDLC workspace repos used in add-project tests have local branch `main`.
- [x] 3.2 Add success-path tests for branch creation before mutation, scoped commit creation, and final handoff output.
- [x] 3.3 Add failure-path tests for missing `main`, dirty worktree, and existing branch collision without destructive branch reuse.
- [x] 3.4 Extend success-path tests to assert the highlighted reminder block and separately rendered merge command.

## 4. Document the new add-project git workflow

- [x] 4.1 Update `overmind/README.md` to describe branch creation, automatic commit on success, and the merge-back reminder to `main`.
- [x] 4.2 Ensure the documentation keeps the command scoped to staged ASDLC workspace execution and does not introduce new CLI flags/options.
- [x] 4.3 Document that the final merge instruction is intentionally highlighted and the git command is visually separated from explanatory text.

## 5. Validate change readiness

- [x] 5.1 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` from the repository root.
- [x] 5.2 Run `openspec status --change crp-093-add-project-git-branch-handoff` to confirm all artifacts are complete and apply-ready.
