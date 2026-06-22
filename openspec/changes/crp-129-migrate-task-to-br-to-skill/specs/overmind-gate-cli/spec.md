## ADDED Requirements

### Requirement: Gate invocation contract

The `asdlc-coordinator` package SHALL provide an `overmind-gate` CLI invoked as `overmind-gate <step> <path>`, where `<step>` selects a registered validator and `<path>` is the target artifact (absolute, or relative to the workspace root). The CLI SHALL dispatch to the validator registered for `<step>`.

#### Scenario: Dispatch to a registered validator

- **WHEN** `overmind-gate task-to-br <feature-path>` is run and a validator is registered for `task-to-br`
- **THEN** the `task-to-br` validator runs against the artifacts at `<feature-path>` and the CLI exits with that validator's status

### Requirement: Exit-code protocol

The gate SHALL use a stable exit-code protocol: `0` when the artifact is valid, `1` when the artifact has a recoverable content problem the model should fix and rerun, and `2` for runtime/usage failures where validation cannot be performed (missing arguments, missing target, unknown step).

#### Scenario: Valid artifact passes

- **WHEN** the validator finds no problems
- **THEN** the CLI prints a short pass message and exits `0`

#### Scenario: Recoverable content problem

- **WHEN** the validator finds structural/content problems in the artifact
- **THEN** the CLI prints each problem as an actionable line and exits `1`

#### Scenario: Usage or runtime failure

- **WHEN** the target path is missing, the step is unknown, or a required argument is absent
- **THEN** the CLI prints a clear error explaining why validation cannot run and exits `2`

### Requirement: Actionable failure messages

On exit `1`, the gate SHALL print one line per problem describing exactly what is wrong so a model can repair the artifact without guessing. On exit `2`, the gate SHALL print a single error stating why validation could not be performed.

#### Scenario: Each failure is individually reported

- **WHEN** an artifact has multiple structural problems
- **THEN** the gate prints a separate actionable line for each problem rather than a single generic failure
