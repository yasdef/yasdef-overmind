## 1. Remove add-project git orchestration

- [x] 1.1 Delete git-specific constants, helper functions, and `git` command prerequisites from `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`.
- [x] 1.2 Remove `main`-branch checks, clean-worktree checks, helper-branch creation, scoped auto-commit, and merge-handoff output from the add-project success path.

## 2. Rebaseline add-project automated coverage

- [x] 2.1 Replace branch/commit-oriented assertions in `tests/ai_scripts/project_setup_asdlc_tests.sh` with checks that branch name and HEAD remain unchanged when add-project runs inside git.
- [x] 2.2 Add coverage showing add-project succeeds without `.git` metadata and succeeds when the ASDLC worktree is already dirty.
- [x] 2.3 Remove failure-path coverage that only applied to the old branch-handoff contract (`main` missing, dirty worktree blocked, branch collision blocked).

## 3. Update docs and change history

- [x] 3.1 Update `README.md` so add-project is described as in-place project scaffolding rather than a branch/commit workflow.
- [x] 3.2 Restore `crp-093-add-project-git-branch-handoff` unchanged and record the reversal in `crp-124-remove-add-project-git-handoff`.
- [x] 3.3 Validate the new change set with `openspec status --change crp-124-remove-add-project-git-handoff`.
