## ADDED Requirements

### Requirement: Step 7.1 is optional and non-blocking
Step `7.1` SHALL be optional. Step `8` SHALL be allowed to proceed when Step `7` is complete, regardless of whether Step `7.1` has run, found no placeholders, found no configured knowledge-base MCP source, could not reach MCP, found no useful guidance, or had proposed replacements rejected.

#### Scenario: Step 8 proceeds when Step 7.1 is skipped
- **WHEN** Step `7` surface maps are complete and Step `7.1` has not run
- **THEN** the progress scanner does not block required Step `8` on Step `7.1`

#### Scenario: Step 8 proceeds after enrichment no-op
- **WHEN** Step `7.1` runs and finds no placeholders or no useful MCP guidance
- **THEN** Step `8` remains eligible to run after Step `7`

#### Scenario: Step 8 proceeds after rejected enrichment
- **WHEN** Step `7.1` proposes replacements and the user rejects them
- **THEN** placeholders remain valid and Step `8` remains eligible to run

### Requirement: Step 7.1 has no required completion artifact
Step `7.1` SHALL NOT require a new per-class enrichment status artifact, audit artifact, or marker file for workflow progress. Its only durable output SHALL be optional in-place updates to existing surface-map files.

#### Scenario: No audit artifact required
- **WHEN** Step `7.1` completes without editing any surface map
- **THEN** no new enrichment audit or status file is required for the workflow to continue

#### Scenario: Surface map remains the downstream input
- **WHEN** Step `7.1` applies confirmed replacements
- **THEN** downstream steps continue to read the updated `project_surface_struct_resp_map_<class>.md` file

### Requirement: Step 7.1 preserves placeholder validity
The literal `<to be defined during implementation>` SHALL remain valid in Step `7` surface maps when Step `7.1` is skipped, unavailable, inconclusive, or declined. Step `7.1` SHALL NOT convert unresolved placeholders into errors solely because enrichment was not applied.

#### Scenario: Placeholder remains valid without MCP
- **WHEN** no configured knowledge-base MCP source is available
- **THEN** Step `7.1` leaves placeholders unchanged
- **AND** those placeholders remain valid surface-map output for later planning

#### Scenario: Placeholder remains valid after MCP failure
- **WHEN** a configured knowledge-base MCP source is unreachable
- **THEN** Step `7.1` leaves placeholders unchanged
- **AND** the workflow can continue to Step `8`
