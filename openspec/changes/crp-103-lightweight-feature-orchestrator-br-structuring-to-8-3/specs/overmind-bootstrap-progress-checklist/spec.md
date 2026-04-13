## MODIFIED Requirements

### Requirement: Scanner SHALL append canonical next-step line
`overmind/step_state.md` SHALL end with `next step: <number> (<name>)` for the first incomplete non-optional step after the last contiguous completed required steps, or `next step: none` when all required steps are complete.

#### Scenario: Incomplete required steps remain
- **WHEN** at least one required step is incomplete
- **THEN** the final line SHALL name the next sequential incomplete required step as `next step: <number> (<name>)`

#### Scenario: All required steps complete
- **WHEN** all required steps are complete
- **THEN** the final line SHALL be exactly `next step: none`

#### Scenario: Incomplete optional step does not replace next required step
- **WHEN** an optional step is incomplete and a later required step is the next required unfinished checkpoint
- **THEN** scanner SHALL keep reporting that next required unfinished checkpoint on the final `next step` line
- **AND** SHALL NOT report the optional step as the canonical `next step`

#### Scenario: Split Step 4.1 completion advances canonical next step to 4.2
- **WHEN** the workflow defines required Step `4.1` and Step `4.2`, Step `4.1` is complete, and Step `4.2` is incomplete
- **THEN** scanner SHALL render `next step: 4.2 (...)`
- **AND** SHALL not skip directly to later steps while Step `4.2` remains unfinished

#### Scenario: Scaffold-complete feature starts scanner progression at 4.1
- **WHEN** scaffold initialization for a new feature is complete and Step `4.1` is the first unfinished required checkpoint for that feature path
- **THEN** scanner SHALL render `next step: 4.1 (...)`
- **AND** SHALL provide deterministic resume input for orchestrator continuation after scaffold
