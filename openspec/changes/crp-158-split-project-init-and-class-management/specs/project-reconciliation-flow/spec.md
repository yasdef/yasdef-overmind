## MODIFIED Requirements

### Requirement: Commit interaction is scoped and conservative

When a verified git-backed reconciliation unit has owned changes, the flow SHALL ask `Commit reconciliation results? [y/N]` through `InteractionPort`. Confirmation SHALL stage and commit exactly the two owned paths using message `Update project reconciliation state`, then verify a clean project worktree. Any other response SHALL leave the verified owned changes uncommitted and return a stopped-by-operator success outcome. No-change and non-git flows SHALL skip the prompt.

#### Scenario: Operator confirms commit

- **WHEN** the operator answers yes to a verified changed unit
- **THEN** exactly `init_progress_definition.yaml` and `common_contract_definition.md` are committed with message `Update project reconciliation state` and the project worktree is verified clean

#### Scenario: Operator declines commit

- **WHEN** the operator answers no or closes input
- **THEN** the owned changes remain uncommitted, the command reports that choice, and no feature flow starts

#### Scenario: Commit operation fails

- **WHEN** staging, committing, or post-commit status verification fails
- **THEN** the CLI exits non-zero with an actionable project-root git diagnostic and does not claim reconciliation completion
