## ADDED Requirements

### Requirement: `overmind run` is the single feature-creation entrypoint

The system SHALL create a new feature under a project only through the `overmind run` feature-selection flow. When the operator selects "Start a new feature", the system SHALL dispatch catalog step `3` through the deterministic action registry, persist the created feature as the project's selected feature, and continue into the feature phase loop.

#### Scenario: Operator starts a new feature through `run`

- **WHEN** the operator invokes `overmind run --path <project>` and selects "Start a new feature"
- **THEN** the system confirms step `3`, collects the feature ID and title, creates `<project>/<normalized-title>-<timestamp>/feature_br_summary.md` from the BR summary template, records the created feature as the project's selected feature, and proceeds to the next required step in the phase loop

#### Scenario: Operator continues an existing feature through `run`

- **WHEN** the operator invokes `overmind run --path <project>` and selects "Continue an existing unfinished feature"
- **THEN** the system selects that feature without creating a feature directory and resumes at the next required step

### Requirement: The standalone `scaffold` CLI verb is not part of the CLI surface

The `overmind` CLI SHALL NOT expose a `scaffold` command. The CLI usage text SHALL NOT advertise `scaffold`, and an invocation naming it SHALL be rejected as an unknown command with a non-zero exit code.

#### Scenario: Removed verb is invoked

- **WHEN** the operator invokes `overmind scaffold feature --path <project>`
- **THEN** the system rejects the invocation as an unknown command, writes the usage text listing the supported commands, creates no feature directory, and exits with a non-zero code

#### Scenario: Usage text omits the removed verb

- **WHEN** the system renders the top-level CLI usage text
- **THEN** the text does not name `scaffold`, and it names `run` among the supported commands

### Requirement: The feature-scaffold primitive remains the step `3` action

The system SHALL retain the `scaffoldFeature()` capture primitive as catalog step `3`'s deterministic action, dispatched through the executor's action registry and returning the created feature path as a typed result. Removal of the CLI verb SHALL NOT change the primitive's inputs, its step `3` registry dispatch, its rendered feature output, or its typed result. The pending-checkpoint classification SHALL inspect the applicable step `1.1` stack and agent-guidelines paths together with the shared project-definition files, so a step `1.1` artifact without a finalized checkpoint refuses feature creation per the interrupted init-only checkpoint scenario below.

#### Scenario: Step `3` dispatches the primitive through the registry

- **WHEN** the orchestrator executes catalog step `3` for a project
- **THEN** it dispatches the registered `scaffold-feature` action through the generic executor and adopts the feature path from the action's typed result rather than parsing stdout

#### Scenario: Primitive is importable by an in-process consumer

- **WHEN** a consumer in the workspace imports `scaffoldFeature()` from the coordinator package and supplies the feature ID and title as arguments together with the required ports
- **THEN** the primitive creates the feature without requiring an interactive terminal and returns the created feature path as a typed result

### Requirement: Pending init or reconciliation checkpoints block feature creation at the `run` step `3` boundary

WHERE a project has a pending init or reconciliation checkpoint, the system SHALL refuse feature creation at the step `3` boundary reached through `overmind run`, before requesting the feature ID or title and before any filesystem write, and SHALL name the exact `project init` or `project reconcile` command that owns the pending boundary.

#### Scenario: New feature is started while step `2` is pending

- **WHEN** the operator paused after step `1.1` and selects "Start a new feature" under `overmind run`
- **THEN** the system refuses before requesting the feature ID or title, creates no feature directory, and directs the operator to run `project init`

#### Scenario: New feature is started with an interrupted init-only checkpoint

- **WHEN** artifact progress has moved past step `1.1` but an applicable stack or agent-guidelines path has no finalized checkpoint, and the operator selects "Start a new feature" under `overmind run`
- **THEN** the system refuses before interaction or filesystem writes and directs the operator to run `project init`

#### Scenario: New feature is started after a declined reconciliation commit

- **WHEN** the initial common contract is committed, a shared project-definition path contains a pending reconciliation change, and the operator selects "Start a new feature" under `overmind run`
- **THEN** the system refuses before interaction or filesystem writes and directs the operator to run `project reconcile`

### Requirement: Operator guidance documents one feature-creation entrypoint

Generated and durable operator documentation SHALL present `overmind run` as the only way to create a feature, and SHALL NOT instruct the operator to run a feature-scaffold command before `run`.

#### Scenario: Generated quickrun first-time happy path

- **WHEN** the installer generates `quickrun.md` for a workspace
- **THEN** the first-time happy path proceeds from `project init` to `run` with no intervening feature-scaffold command, and neither the happy path nor the Feature Commands section names `scaffold feature`

#### Scenario: Operator follows the generated happy path

- **WHEN** the operator follows the generated first-time happy path in order
- **THEN** the sequence creates exactly one feature, and no step creates a feature directory that a later step leaves unused

### Requirement: The extension consumes the coordinator primitive for feature creation

The VS Code extension design SHALL create features by importing the `scaffoldFeature()` coordinator primitive in process, not by executing a CLI verb. The extension's shipped-verb allow-list SHALL contain only the read-only `overmind status` and the terminal-hosted `overmind run`.

#### Scenario: Extension Create Feature action

- **WHEN** the extension design specifies the Create Feature action
- **THEN** it invokes the `scaffoldFeature()` primitive with the form's feature ID and title and consumes the returned typed feature path, and it does not execute a `scaffold` CLI verb

#### Scenario: Extension verb allow-list

- **WHEN** the extension design enumerates the shipped verbs it may execute
- **THEN** the allow-list names `overmind status` and `overmind run` and does not name `overmind scaffold feature`
