## ADDED Requirements

### Requirement: InteractionPort abstracts operator decision points

The system SHALL define an `InteractionPort` in `interaction/` that abstracts every operator decision point as typed request messages: at minimum `confirm(message) → boolean` (y/n), `select(message, options) → choice`, and `input(message) → string` (`02_responsibility_translation_map.md` row 14; decision 1 in `03_target_architecture.md ## Decisions`). The port SHALL be the single seam through which the orchestrator (Slice 3) and the VS Code extension (Slice 5) reach the operator, so the CLI's TTY prompts and the extension's webview forms are two adapters over the same port. Decision semantics SHALL be preserved 1:1 with the shell; auto-advance profiles are explicitly out of scope for this slice.

#### Scenario: Confirm/select/input requests are typed

- **WHEN** a caller issues a `confirm`, `select`, or `input` request through the port
- **THEN** each is a typed request whose result type is a boolean, a chosen option, or an input string respectively — independent of any concrete adapter

### Requirement: TTY adapter preserves today's prompt wording and semantics

The system SHALL provide a TTY adapter implementing `InteractionPort` over stdin/stdout that preserves the wording and semantics of today's `read -r` prompts (`02_responsibility_translation_map.md` row 14). The adapter SHALL ship in this slice even though no Slice 2 module consumes it, so the runner-result and interaction shapes co-evolve rather than being retrofitted when the orchestrator loop lands (`04_migration_plan.md ## Slice 2`).

#### Scenario: TTY confirm reads a y/n answer with preserved semantics

- **WHEN** the TTY adapter handles a `confirm` request
- **THEN** it prompts on the terminal and resolves to a boolean using the same y/n semantics the shell prompts used

#### Scenario: Port is defined but not yet wired into a loop

- **WHEN** this slice is complete
- **THEN** the `InteractionPort` types and TTY adapter exist and are unit-covered, and no Slice 2 module wires them into an orchestrator loop (that consumption is Slice 3)
