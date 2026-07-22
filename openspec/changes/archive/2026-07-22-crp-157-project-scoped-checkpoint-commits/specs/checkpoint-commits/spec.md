## MODIFIED Requirements

### Requirement: Git operations are scoped by explicit repository root

The system SHALL provide a git adapter whose operations always receive an explicit repository root and never depend on ambient working directory. It SHALL represent unavailable git, non-worktree, clean worktree, add failure, commit failure, and committed states as typed results.

#### Scenario: Supplied root is not a git worktree
- **WHEN** a checkpoint is requested for a supplied repository root that is not a git worktree
- **THEN** the adapter returns a non-worktree result without throwing

#### Scenario: Git command targets explicit root
- **WHEN** the adapter stages or commits checkpoint changes
- **THEN** every git invocation targets the supplied repository root regardless of process cwd

### Requirement: Feature checkpoints are best effort at preserved boundaries

The feature orchestrator SHALL request checkpoints against the **project repository root** — the same repository scope as project create, project init, and project reconcile commits — immediately before steps 5.1, 7.1, and 8.4 and immediately after step 8.4 when it succeeds or is cleanly declined. Checkpoints SHALL stage all project-repository changes (`git add -A` at the project root) and use descriptive boundary labels. The runtime root SHALL NOT be a checkpoint target. A clean tree, missing git, non-worktree, stage failure, or commit failure SHALL produce a notice and SHALL NOT stop or fail the feature run.

#### Scenario: Dirty project repository is committed before 5.1
- **WHEN** execution reaches step 5.1 with changes in the project repository
- **THEN** a best-effort checkpoint stages all project-repository changes and commits with the before-5.1 boundary label before the phase decision/execution

#### Scenario: Clean project repository before 7.1 continues
- **WHEN** execution reaches step 7.1 and the project-repository worktree is clean
- **THEN** the orchestrator prints a checkpoint notice and continues to step 7.1

#### Scenario: Step 8.4 has two checkpoint boundaries
- **WHEN** execution reaches step 8.4 and the operator either completes it or declines it cleanly
- **THEN** the orchestrator requests a project-repository checkpoint before the decision and another after the completed/declined boundary

#### Scenario: Checkpoint command fails
- **WHEN** staging or committing a checkpoint returns non-zero
- **THEN** the failure is rendered as a notice and phase execution continues

#### Scenario: Non-git project degrades to a notice
- **WHEN** the project folder is not a git worktree (the runtime root's git state is irrelevant)
- **THEN** every checkpoint boundary renders a non-worktree notice and the feature run proceeds unchanged

#### Scenario: Checkpoints never target the runtime root
- **WHEN** any feature-flow checkpoint runs
- **THEN** the git root it receives is the project repository root, not the ASDLC runtime root
