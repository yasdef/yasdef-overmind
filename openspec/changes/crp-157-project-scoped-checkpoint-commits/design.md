## Context

`orchestrator/run-feature-flow.ts` requests best-effort checkpoint commits at preserved boundaries (before 5.1, 7.1, 8.4; after 8.4) via `deps.checkpoint.checkpoint(deps.workspaceRoot, label)` — the ASDLC runtime root. That scope is shell heritage: the old `commit_feature_progress` ran `git add -A` when the whole ASDLC directory was one repository. The current architecture (unit B, `crp-152-project-lifecycle`) makes each `projects/<project>` its own git repository with `overmind project create` performing git init and the initial commit, and the operator has confirmed (2026-07-11) that the runtime root is intentionally **not** a repository.

Consequences of the current scope under that model: every checkpoint returns the typed `notWorktree` result, so feature artifacts — which live inside the project repository — are never checkpointed. Git-initing the runtime root would not fix it either: nested repositories are git boundaries, so a runtime-root `git add -A` cannot stage anything inside `projects/<project>`.

## Goals / Non-Goals

**Goals:**

- Checkpoint commits land in the project repository — the repo that actually contains the feature artifacts and already receives project create/init/reconcile commits.
- Preserve every other checkpoint property: boundaries, labels, best-effort typed degradation, never stopping the run.

**Non-Goals:**

- No change to `RepoGitAdapter` or `CheckpointResult`; `notWorktree` notice wording is corrected to describe the supplied repository root.
- No change to which steps have checkpoint boundaries.
- No change to project-level or class-repository git scopes (architecture invariant 4 in `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md ## Architecture invariants` keeps the scopes distinct — this change corrects which scope the feature flow uses, it does not merge scopes).
- No CLI flags, no docs surface changes.

## Decisions

1. **Pass `deps.projectRoot` at the two call sites; change nothing else.** The orchestrator already carries the project root; the adapter is root-agnostic by design. Alternative — adding a dedicated `checkpointRoot` dep — rejected: it reintroduces a degree of freedom the model has no use for and invites the runtime-root mistake back.
2. **Non-git projects keep working via the existing typed degradation.** `notWorktree` was designed as a first-class outcome; a project created without git (or with git unavailable) renders a notice at each boundary and the run proceeds. No new configuration or detection is added.
3. **Tests assert the scope positively and negatively.** The checkpoint/orchestrator tests assert the root received by the injected git runner is the project root and never the workspace root — locking the correction in as contract, since both roots are plausible-looking and the regression would be silent (typed degradation hides it).

## Risks / Trade-offs

- [Checkpoint commits now add untracked feature artifacts to project history that previously went uncommitted] → That is the point; `git add -A` at the project root matches the shell's staging breadth within the corrected scope.
- [An operator with a legacy single-repo ASDLC directory loses runtime-root checkpoints] → No such deployment exists (nothing was ever installed); the fresh-install lens from `06_sh_remove_plan.md` applies.
- [Silent regression risk if a future change reverts the root] → Mitigated by the negative test assertion (never the workspace root).

## Open Questions

None — the per-project-repo end state was operator-confirmed on 2026-07-11.
