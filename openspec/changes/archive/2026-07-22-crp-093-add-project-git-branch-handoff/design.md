## Context

`project_setup_add_new_project.sh` currently mutates the staged ASDLC workspace in place: it appends a record to `asdlc_metadata.yaml`, creates a project folder, seeds `init_progress_definition.yaml`, and exits on whatever branch happens to be checked out in the ASDLC repo. The requested behavior adds git workflow ownership to that command so each new-project run is isolated on its own branch, ends with a local commit, and gives the operator a clear merge-back instruction for `main`.

This change is constrained to shell-only implementation and must remain non-destructive. The script runs from `<asdlc>/.commands/project_setup_add_new_project.sh`, so all git operations must target the ASDLC workspace repository rooted at `<asdlc>`, not the source repository that staged the command.

## Goals / Non-Goals

**Goals:**
- Create and switch to a dedicated git branch before the script writes any ASDLC files for a new project.
- Ensure the add-project commit is isolated to the ASDLC workspace repo and captures only the paths created or modified by this flow.
- End a successful run with the dedicated branch still checked out and a deterministic handoff presentation for merging back to `main` that is easy to notice in terminal output.
- Prevent accidental inclusion of unrelated work by failing fast when git preconditions are not safe for automated branching and commit.

**Non-Goals:**
- Push the branch to a remote or open pull requests.
- Change the first-machine bootstrap command beyond what tests need to establish a `main` branch in fixture repos.
- Add CLI flags, custom commit-message options, or non-interactive branch overrides.
- Auto-merge the branch back into `main`.

## Decisions

1. Perform all branch and commit operations in the ASDLC workspace repo rooted at `<asdlc>`.
Rationale: the staged command mutates ASDLC-local files, so the branch/commit boundary must live with those artifacts rather than the source repository that originally copied the scripts.
Alternative considered: creating branches in the source repo. Rejected because the source repo does not receive the actual add-project file changes.

2. Derive the branch name from the final project id as `add-project/<project_id>`.
Rationale: the project id is already unique and stable for the run (`<normalized-name>-<epoch_milliseconds>`), so reusing it keeps the branch name predictable and directly traceable to the created project folder and metadata record.
Alternative considered: a generic timestamp-only branch. Rejected because it is harder to associate with the created project.

3. Collect and validate user inputs first, then create the branch immediately before the first filesystem mutation.
Rationale: this still satisfies “branch before any changes” while avoiding abandoned branches when the operator exits during input collection or path validation.
Alternative considered: branching before any prompt. Rejected because it creates empty workflow branches for incomplete interactive sessions.

4. Require safe git preconditions before creating the branch: git repository context, existing local branch `main`, and a clean index/worktree.
Rationale: the script will create an automatic commit; if unrelated changes are already present, checkout and commit behavior becomes ambiguous and can accidentally capture work outside this flow. Requiring `main` also makes the final merge instruction deterministic.
Alternative considered: auto-detecting whichever branch is currently checked out as the merge target. Rejected because the requested handoff explicitly targets `main`, and dynamic targets make the final instruction less predictable.

5. Stage and commit only the add-project paths: `asdlc_metadata.yaml` and the new `projects/<project_id>/` folder.
Rationale: path-scoped staging keeps the generated commit narrow even if ignored or untracked files exist elsewhere in the ASDLC repo.
Alternative considered: `git add -- .`. Rejected because it can sweep in unrelated files.

6. Print a visually emphasized completion block that includes the checked-out branch and the exact merge command for `main` on its own differentiated line.
Rationale: the handoff is part of the user-facing contract, not incidental logging. If it blends into regular completion output, operators can miss the next required action.
Alternative considered: a single plain prose line. Rejected because the user explicitly wants the reminder highlighted and the git command distinguished from surrounding text.

## Risks / Trade-offs

- [Risk] Requiring branch `main` may fail in environments where `git init` still defaults to another primary branch.
  Mitigation: update test fixtures to rename the initialized ASDLC repo branch to `main`, and document `main` as the canonical base branch for this flow.

- [Risk] Automatic branch creation can leave an extra branch behind if a later write or commit step fails.
  Mitigation: fail fast on git prerequisites before mutation, keep branch naming deterministic, and avoid destructive cleanup so recovery remains manual and explicit.

- [Risk] Automatic commit behavior can fail when git identity is missing in the ASDLC repo.
  Mitigation: treat commit failure as a surfaced error with the created branch left intact so the operator can inspect and complete the commit manually.

## Migration Plan

1. Extend `project_setup_add_new_project.sh` with ASDLC-root git helpers for branch existence checks, cleanliness validation, branch creation, scoped staging, and commit.
2. Insert the branch-creation step after input collection and before project folder creation or metadata writes.
3. Add deterministic completion output that renders a visible handoff block, states the current branch, and prints `git checkout main && git merge <branch_name>` on a separately emphasized line.
4. Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` to cover branch creation, clean-worktree enforcement, scoped commit creation, and highlighted final handoff output.
5. Update `overmind/README.md` to describe the new branch/commit/handoff behavior of the add-project command, including the emphasized merge instruction.

Rollback strategy: remove the add-project git workflow helpers and return the command to direct in-place metadata/project creation on the current branch.

## Open Questions

- None.
