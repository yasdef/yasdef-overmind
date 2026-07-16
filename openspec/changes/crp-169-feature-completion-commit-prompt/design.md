## Context

`runFeatureFlow(...)` has four successful terminal paths:

| Path | Trigger | Today's commit behavior |
| --- | --- | --- |
| 1 | `nextStep(evaluate(...))` returns nothing before the loop starts | none |
| 2 | Step `8.4` completes or is declined inside the loop | silent `after84` checkpoint |
| 3 | A phase returns `finished` | inherits path 2 when the phase is `8.4` |
| 4 | The catalog loop reaches its end | inherits path 2 when step `8.4` ran |

Paths 1 and 4 can therefore report a finished feature while the project worktree still holds every planning artifact the run produced. Path 1 is the ordinary resumed-run shape: step `8.4` is optional, so once its decision is recorded, artifact-presence scanning reports no remaining required step and the flow returns `finished` immediately.

CRP-166 already centralized the gate-chain half of this problem: `enforceTerminalChain()` is a run-once helper every successful path calls before reporting completion. The commit boundary belongs immediately behind it, in the same helper, for the same reason — completion behavior stated once rather than repeated per return branch.

`RepoGitAdapter.checkpoint(root, label)` stages and commits the whole supplied root and degrades every obstacle (git absent, not a worktree, clean tree, `add` or `commit` non-zero) to a typed result that never throws. `capture/project-class.ts` already establishes the confirmed-commit shape this change reuses: `interaction.confirm(...)` with an explicit default, `InteractionClosedError` treated as a decline, and a notice naming what was left uncommitted.

## Goals / Non-Goals

**Goals:**

- Guarantee that every successful end of feature work reaches exactly one commit boundary, whichever terminal path produced it.
- Make the commit an operator decision with a visible result rather than a silent side effect.
- Keep the boundary strictly non-blocking: neither the answer nor the commit result changes the flow outcome or exit code.
- Preserve the CRP-166 invariant that a failing terminal gate chain reports no completion and creates no commit.

**Non-Goals:**

- Per-phase commit prompts, an operator-supplied commit message, staging scoped to the feature folder, or any push/branch behavior.
- Changing the pre-`5.1`, pre-`7.1`, and pre-`8.4` checkpoints, which remain silent best-effort protection against losing work mid-run.
- Committing on failed, refused-pending-work, startup-error, or operator-stopped runs.
- Recording the commit decision in any artifact or ledger.

## Decisions

### D1: One completion boundary behind the existing run-once terminal helper

Extend the CRP-166 completion path into a single asynchronous helper that every successful terminal path awaits. It runs the terminal gate chain, and on a passing chain runs the commit boundary. Like the chain it wraps, it is run-once per invocation: step `8.4` completing inside the loop and the subsequent catalog-end fall-through are one completion, so the operator is prompted once.

The chain result keeps its current precedence. A non-zero chain returns the failed outcome unchanged and never reaches the prompt, matching the existing rule that a blocked feature creates no post-review checkpoint.

Alternative considered: prompt at each of the four return branches. Rejected because the double-completion shape of paths 2 and 4 would prompt twice, and completion behavior would again be stated in four places.

Alternative considered: keep the silent checkpoint and add the prompt only to the uncovered paths 1 and 4. Rejected because the operator-visible behavior at one boundary would then depend on which internal path produced it.

### D2: Prompt with an accept default and treat closed input as a decline

The boundary asks `Commit completed feature work?` with default `true`, since an operator who has reached plan completion normally wants the plan recorded. A decline emits that the work was left uncommitted and returns the same outcome. `InteractionClosedError` is caught and treated as a decline with its own notice, matching `capture/project-class.ts`; it is not re-raised as an operator stop, because the feature is already complete and there is nothing left to stop.

Alternative considered: default `false`, matching the class-membership prompt. Rejected because that prompt guards a project-definition mutation the operator may not have intended, while this one records work the operator explicitly drove to completion.

Alternative considered: treat a decline as a failed run so the artifacts cannot be lost silently. Rejected because declining to commit is a legitimate operator choice — the artifacts remain on disk and the next run offers the same boundary.

### D3: Skip the prompt when there is nothing to commit

A clean project worktree emits the existing `nothing to commit` notice without prompting. The prompt appears only when the boundary would actually create a commit, so a resumed run that ends with no new artifacts does not ask a question with no effect.

Alternative considered: always prompt for symmetry. Rejected because a prompt whose only outcome is a no-op trains operators to answer without reading.

### D4: Keep every commit obstacle a notice

Git being absent, the project root not being a worktree, and a non-zero `add` or `commit` all keep their current typed results and notice wording, and none of them changes the flow outcome. The boundary reports; it does not gate. This preserves the checkpoint contract inherited from the shell orchestrator, where losing a commit is never worse than losing the run.

Alternative considered: fail the run on `commitFailed`. Rejected because the planning work is complete and on disk; failing would misreport a finished feature as blocked.

### D5: Retire the `after84` label in favor of a completion label

`CHECKPOINT_LABELS.after84` described a step boundary that no longer describes where the commit happens. It is replaced by a feature-completion label so the commit message and every notice name the boundary the operator actually reached. The three pre-step labels are unchanged.

### D6: A new feature may not start on uncommitted work

A decline is only harmful once the artifacts it left behind can be attributed to something else. That happens at exactly one place: starting a *new* feature, whose mid-run checkpoints stage the whole project root and therefore commit the previous feature's work under this feature's label. Within one feature the uncommitted work is that feature's own, so a checkpoint committing it is correct.

The precondition therefore lands on scaffolding, not on the checkpoints: `scaffoldFeature(...)` already refuses when a project init or reconciliation checkpoint is pending, and it gains a whole-worktree cleanliness probe alongside. A dirty worktree refuses before the feature id and title are asked for, naming the blocking paths and both ways out — commit them or discard them. Continuing or resuming an existing feature is untouched.

The existing gate runs first, so a dirty *project baseline* still reports the more actionable `project init` or `project reconcile` guidance rather than this generic refusal. An unverifiable worktree is never read as clean; it blocks with the same inspection wording the baseline gate already uses.

Alternative considered: gate the mid-run checkpoints on a clean start instead. Rejected because it makes every checkpoint's behavior depend on run-entry state that the operator cannot see, and it still leaves the declined artifacts to be committed later under an unrelated feature.

Alternative considered: re-offer the declined commit at the start of the next run. Rejected because ordinary feature selection never reopens a completed feature, so the offer would appear at an unrelated moment, detached from the work it describes.

### D7: Document the boundary where terminal validation is already documented

`overmind/README.md` describes terminal validation and the `implementation_plan.md` review checkpoint in its technical-planning section. The commit prompt is the operator-visible step between them and is described there, in the same voice, without restating checkpoint mechanics that belong to the flow implementation.

## Risks / Trade-offs

- [An operator scripting a non-interactive run now meets a prompt at completion] → Closed input is a decline that preserves the outcome and exit code, so a piped run finishes exactly as before, minus the commit.
- [The commit stages the whole project root, including unrelated operator edits] → Unchanged from today's checkpoint behavior; the prompt makes it more visible rather than less, and scoped staging is out of scope.
- [A declined commit leaves work uncommitted with no later reminder] → The notice names the state explicitly, and the next attempt to start a new feature refuses until the worktree is resolved (D6), so the decline surfaces at the moment it would otherwise cause harm.
- [Refusing a new feature blocks an operator who deliberately keeps unrelated edits in the project worktree] → The refusal names the paths and both ways out, and continuing or resuming an existing feature is unaffected.
- [Prompt fatigue at the end of every run] → The boundary is once per run and is skipped entirely on a clean worktree.

## Migration Plan

1. Add the completion label and the declined/closed-input notice rendering.
2. Extend the run-once terminal helper into the completion helper and route all four successful paths through it.
3. Add feature-flow tests for each path, both answers, closed input, clean worktree, and commit obstacles.
4. Update `overmind/README.md`.
5. Run the coordinator, installer, and verification suites.

Rollback restores the silent after-`8.4` checkpoint and removes the prompt; the terminal gate chain is untouched.

## Open Questions

- None blocking.
