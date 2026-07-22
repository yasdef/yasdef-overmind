## ADDED Requirements

### Requirement: Every successful end of feature work reaches one commit boundary

The feature flow SHALL reach exactly one feature-completion commit boundary on every path that reports feature work as successfully finished, and SHALL reach it at most once per invocation.

#### Scenario: Optional plan semantic review is accepted

- **WHEN** step `8.4` completes and its post-session checks pass
- **THEN** the completion boundary runs once after the terminal gate chain passes
- **AND** the catalog-end fall-through in the same invocation does not run it again

#### Scenario: Optional plan semantic review is declined

- **WHEN** the operator declines step `8.4` and no required phase remains
- **THEN** the completion boundary runs before the finished outcome is returned

#### Scenario: Feature scanning reports no remaining required step

- **WHEN** the run resolves a feature whose scanner reports no remaining required step before the catalog loop starts
- **THEN** the completion boundary runs before the finished outcome is returned

#### Scenario: Catalog loop reaches its end

- **WHEN** the catalog loop completes without a prior completion boundary in the same invocation
- **THEN** the completion boundary runs before the completed outcome is returned

### Requirement: The completion boundary asks the operator before committing

The completion boundary SHALL commit the project worktree only after operator confirmation, SHALL default the confirmation to accept, and SHALL report its result on every answer.

#### Scenario: Operator accepts

- **WHEN** the project worktree has changes and the operator accepts the commit prompt
- **THEN** the project worktree is staged and committed with the feature-completion label
- **AND** the created commit message is reported

#### Scenario: Operator declines

- **WHEN** the operator declines the commit prompt
- **THEN** no commit is created
- **AND** a notice states that completed feature work was left uncommitted

#### Scenario: Operator input stream is closed

- **WHEN** the input stream closes while the commit prompt is open
- **THEN** the answer is treated as a decline with its own notice
- **AND** the run is not reported as stopped by the operator

#### Scenario: Nothing to commit

- **WHEN** the project worktree is clean at the completion boundary
- **THEN** the operator is not prompted
- **AND** the existing nothing-to-commit notice is emitted

### Requirement: The completion boundary never changes the run outcome

The completion boundary SHALL preserve the flow outcome and exit code produced by the terminal path that reached it, whatever the operator answers and whatever the commit result.

#### Scenario: Commit obstacle is a notice

- **WHEN** git is unavailable, the project root is not a worktree, or staging or committing exits non-zero
- **THEN** the obstacle is emitted as a notice
- **AND** the flow returns the same outcome and exit code it would have returned on a successful commit

#### Scenario: Declined commit preserves a finished feature

- **WHEN** the operator declines the commit prompt on a finished terminal path
- **THEN** the flow still returns the finished outcome and its terminal message

### Requirement: Blocked and unsuccessful runs reach no commit boundary

The feature flow SHALL run the completion boundary only after the terminal gate chain passes, and SHALL NOT run it on any path that does not report feature work as successfully finished.

#### Scenario: Terminal gate chain fails

- **WHEN** the terminal gate chain returns a non-zero aggregate exit
- **THEN** the failed outcome and its repair step are returned unchanged
- **AND** the operator is not prompted and no commit is created

#### Scenario: Run ends without completing feature work

- **WHEN** the run ends through a phase failure, an operator stop, refused pending project work, or a startup error
- **THEN** the completion boundary does not run

### Requirement: Mid-run checkpoints are unchanged

The silent best-effort checkpoints before steps `5.1`, `7.1`, and `8.4` SHALL keep their current labels, triggers, and non-blocking notice behavior.

#### Scenario: Pre-step checkpoints still run silently

- **WHEN** the catalog loop reaches step `5.1`, `7.1`, or `8.4`
- **THEN** the existing checkpoint runs before the step without prompting the operator

### Requirement: A new feature may not start on uncommitted work

Feature scaffolding SHALL refuse to create a new feature while the project worktree holds uncommitted changes, and SHALL refuse before collecting the feature id and title.

#### Scenario: The project worktree has uncommitted changes

- **WHEN** a new feature is requested and the project worktree is dirty
- **THEN** scaffolding refuses without creating a feature folder or prompting for id and title
- **AND** the refusal names the uncommitted paths, that they must be committed or discarded, and the command to retry

#### Scenario: The worktree state cannot be determined

- **WHEN** the worktree probe reports anything other than a clean or dirty worktree
- **THEN** scaffolding refuses rather than treating the worktree as clean

#### Scenario: Continuing an existing feature is unaffected

- **WHEN** a run continues or resumes an existing feature on a dirty project worktree
- **THEN** the run proceeds, because that uncommitted work belongs to the feature being continued
