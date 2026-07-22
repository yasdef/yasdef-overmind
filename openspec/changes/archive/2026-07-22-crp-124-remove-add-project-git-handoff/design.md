## Context

`crp-093-add-project-git-branch-handoff` introduced a contract where `project_setup_add_new_project.sh` manages git state in the staged ASDLC workspace: it requires a local `main` branch, rejects dirty worktrees, creates `add-project/<project_id>`, commits the generated files, and prints a merge-back reminder. The implementation has now been simplified so add-project works in place and does not own git workflow.

This follow-up change needs to record that reversal without rewriting the older change artifacts. The implementation is already aligned with the simpler behavior, so the new change should express the delta from the prior branch-handoff contract to the current in-place contract.

## Goals / Non-Goals

**Goals:**
- Define add-project as a filesystem-only staged ASDLC command with no git preconditions or git side effects.
- Preserve the older `crp-093` artifacts as historical records and capture the behavior change in a new additive change set.
- Keep add-project success semantics narrow and deterministic: project folder created, template seeded, metadata appended, and completion output limited to created paths.
- Align tests and docs with the non-git behavior.

**Non-Goals:**
- Introduce a replacement git automation flow elsewhere in Overmind.
- Change first-machine bootstrap behavior beyond what existing tests already exercise.
- Add new CLI flags or a new optional git mode.

## Decisions

1. Keep add-project git-agnostic.
Rationale: project creation should not own branch strategy, commit timing, or merge flow. Those decisions vary by operator and repository context.
Alternative considered: keep git automation behind a flag. Rejected because the user asked to remove the functionality completely, not hide it behind an option.

2. Model the reversal as a new OpenSpec delta against the prior capability instead of editing old change artifacts.
Rationale: the old artifacts remain the source record of what `crp-093` proposed. `crp-124` documents the subsequent reversal cleanly and keeps spec history additive.
Alternative considered: overwrite `crp-093` with a superseded note. Rejected because it erases the historical contract rather than tracking the later change.

3. Treat non-git execution and dirty-worktree execution as valid add-project cases.
Rationale: once git side effects are removed, there is no remaining reason to block those environments.
Alternative considered: keep git-repository validation for consistency with other scripts. Rejected because it would preserve a constraint that no longer protects any owned behavior.

4. Verify that add-project leaves ambient git state untouched when git is present.
Rationale: the removal is not complete if the command still changes branch state, HEAD, or creates helper branches implicitly.
Alternative considered: test only non-git success. Rejected because it would miss accidental remaining git side effects.

## Risks / Trade-offs

- [Risk] Operators who relied on the old branch-handoff automation may now need to manage git manually.
  Mitigation: update README wording so the command no longer implies automatic branch creation or merge instructions.

- [Risk] OpenSpec history can look contradictory if the old change is read without the new delta.
  Mitigation: make `crp-124` explicitly reference the prior branch-handoff contract and describe this change as its removal.

- [Risk] Test fixtures could keep stale branch-specific assertions and silently misdocument behavior.
  Mitigation: replace branch/commit expectations with assertions covering untouched HEAD/branch state, non-git success, and dirty-worktree success.

## Migration Plan

1. Restore `crp-093` artifacts unchanged as historical records.
2. Add `crp-124` proposal, design, spec delta, and tasks that remove the branch-handoff contract.
3. Keep the current implementation, tests, and README aligned with the in-place add-project behavior.
4. Validate the new change with `openspec status --change crp-124-remove-add-project-git-handoff`.

Rollback strategy: revert the implementation/docs/tests back to the `crp-093` git-handoff behavior and archive or supersede `crp-124`.

## Open Questions

- None.
