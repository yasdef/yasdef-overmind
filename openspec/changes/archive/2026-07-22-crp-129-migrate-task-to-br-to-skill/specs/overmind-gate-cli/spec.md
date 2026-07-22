## ADDED Requirements

### Requirement: CLI invocation contract

The `asdlc-coordinator` package SHALL provide a single `overmind` CLI with three subcommands. `overmind capture <step> <feature_path>` selects a registered capture writer for `<step>` and writes the step-owned input capture artifact. `overmind context <step> <feature_path>` selects a registered context builder for `<step>` and assembles that step's dynamic context for `<feature_path>`. `overmind gate <step> <path>` selects a registered validator for `<step>` and validates the target artifact at `<path>` (absolute, or relative to the workspace root).

#### Scenario: Capture dispatches to a registered writer

- **WHEN** `overmind capture task-to-br <feature-path> --source-file <path>` or `--jira <ticket>` is run and a capture writer is registered for `task-to-br`
- **THEN** the `task-to-br` capture writer creates `<feature-path>/user_br_input.md` and exits `0`
- **AND** Jira capture records a `jira:<ticket>` source marker for the later context/skill MCP fetch instead of fetching Jira content inside the capture command
- **AND** invalid capture arguments print an error and exit non-zero

#### Scenario: Gate dispatches to a registered validator

- **WHEN** `overmind gate task-to-br <feature-path>` is run and a validator is registered for `task-to-br`
- **THEN** the `task-to-br` validator runs against the artifacts at `<feature-path>` and the CLI exits with that validator's status

#### Scenario: Context dispatches to a registered builder

- **WHEN** `overmind context task-to-br <feature-path>` is run and a context builder is registered for `task-to-br`
- **THEN** the builder prints the assembled context block to stdout and exits `0`; an unknown step or missing path prints an error and exits non-zero

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
