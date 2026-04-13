## MODIFIED Requirements

### Requirement: Scanner SHALL mirror rendered checklist output to stdout
For every successful scan run that renders checklist state, the scanner SHALL emit the same rendered checklist payload to terminal stdout while continuing to persist that payload to `overmind/step_state.md`. The stdout payload SHALL remain machine-consumable for project-level feature selection, including exactly one canonical final `next step` line for the selected feature context.

#### Scenario: Terminal output mirrors persisted checklist exactly
- **WHEN** `overmind/scripts/init_progress_scanner.sh` completes checklist rendering
- **THEN** stdout SHALL contain the full checklist payload
- **AND** the emitted stdout checklist payload SHALL be byte-identical to the content written to `overmind/step_state.md`

#### Scenario: Mirrored output includes canonical next-step line
- **WHEN** the scanner renders checklist state
- **THEN** stdout SHALL include the same final `next step` line that is persisted in `overmind/step_state.md`

#### Scenario: Project-level feature selection can classify one selected feature from stdout alone
- **WHEN** a project-level orchestrator runs the scanner for one selected feature folder
- **THEN** stdout SHALL contain exactly one final canonical status line for that scan
- **AND** that line SHALL be either `next step: none` or `next step: <number> (<name>)`
