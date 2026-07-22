## ADDED Requirements

### Requirement: Git operations are scoped by explicit repository root

The system SHALL provide a git adapter whose operations always receive an explicit repository root and never depend on ambient working directory. It SHALL represent unavailable git, non-worktree, clean worktree, add failure, commit failure, and committed states as typed results.

#### Scenario: Runtime root is not a git worktree
- **WHEN** a checkpoint is requested for a runtime root that is not a git worktree
- **THEN** the adapter returns a non-worktree result without throwing

#### Scenario: Git command targets explicit root
- **WHEN** the adapter stages or commits checkpoint changes
- **THEN** every git invocation targets the supplied runtime root regardless of process cwd

### Requirement: Feature checkpoints are best effort at preserved boundaries

The feature orchestrator SHALL request runtime-root checkpoints immediately before steps 5.1, 7.1, and 8.4 and immediately after step 8.4 when it succeeds or is cleanly declined. Checkpoints SHALL preserve the shell's `git add -A` scope and use descriptive boundary labels. A clean tree, missing git, non-worktree, stage failure, or commit failure SHALL produce a notice and SHALL NOT stop or fail the feature run.

#### Scenario: Dirty workspace is committed before 5.1
- **WHEN** execution reaches step 5.1 with runtime-root changes
- **THEN** a best-effort checkpoint stages all changes and commits with the before-5.1 boundary label before the phase decision/execution

#### Scenario: Clean workspace before 7.1 continues
- **WHEN** execution reaches step 7.1 and the runtime-root worktree is clean
- **THEN** the orchestrator prints a checkpoint notice and continues to step 7.1

#### Scenario: Step 8.4 has two checkpoint boundaries
- **WHEN** execution reaches step 8.4 and the operator either completes it or declines it cleanly
- **THEN** the orchestrator requests a checkpoint before the decision and another after the completed/declined boundary

#### Scenario: Checkpoint command fails
- **WHEN** staging or committing a checkpoint returns non-zero
- **THEN** the failure is rendered as a notice and phase execution continues
