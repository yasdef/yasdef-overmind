## ADDED Requirements

### Requirement: Single pure prompt builder over a session action

The system SHALL provide **one** pure prompt builder in `runner/` that produces a model-session prompt from a `StepDefinition` session `Action` plus runtime bindings, replacing the 13 hand-written `build_*_prompt` heredocs in `project_add_feature_e2e.sh` (`02_responsibility_translation_map.md` row 7). The builder SHALL be a pure function of its inputs (no filesystem or process side effects) and SHALL derive per-phase differences from the session action's declared data (`skillName`, `modelPhase`, `requiresSync`) and the supplied bindings (runtime root, feature path, overmind CLI path, resolved artifact paths, and — for per-class steps — the target class), not from per-step code branches.

#### Scenario: Prompt assembled from session action and bindings

- **WHEN** the builder is invoked for the `contract-delta` session action with runtime bindings for a feature
- **THEN** it returns a prompt string that references the `overmind-contract-delta` skill, lists the runtime bindings, and includes the exact `node <cli> context contract-delta <feature>` and `node <cli> gate contract-delta <feature>` command lines — with no per-step branch in the builder

### Requirement: Prompt content parity with the 13 heredocs

The builder's output SHALL preserve the content contract of the shell heredocs: for each of the 13 pipeline session phases it SHALL emit (a) the skill reference line naming the correct `overmind-<skill>` skill, (b) the `Runtime bindings:` block with the runtime root, feature path, target artifact path(s), overmind CLI path, and target class where applicable, and (c) the `Required flow:` block containing the **exact** `node <cli> capture|context|sync|gate <skill> <feature> [--class <class>]` command lines that phase used. The builder SHALL NOT emit skill-owned final-response lines (the model owns them), exactly as the heredocs did not.

#### Scenario: Per-class step includes the class binding and class-scoped gate command

- **WHEN** the builder runs for the `surface-map` session action with a target class binding
- **THEN** the prompt names the target class in its bindings and emits the class-scoped `node <cli> gate surface-map <feature> --class <class>` command line

#### Scenario: No skill-owned final-response lines are emitted

- **WHEN** any pipeline phase prompt is built
- **THEN** the output contains only the skill reference, runtime bindings, and required-flow command lines — and contains no final-response / output-format lines that the skill body owns

#### Scenario: Parity asserted across all 13 phases

- **WHEN** the parity test enumerates the 13 pipeline session phases
- **THEN** for each phase the built prompt matches the corresponding heredoc on skill name, runtime-binding lines, and the exact CLI command lines, and omits final-response lines
