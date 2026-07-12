## ADDED Requirements

### Requirement: The agent guidelines quality gate is a deterministic TypeScript validator

The agent guidelines quality gate SHALL be a deterministic TypeScript validator (`packages/asdlc-coordinator/src/validate/agents-md.ts`) exposed as `overmind gate agents-md <path>` and registered in the `overmind gate` registry. It SHALL validate the single target file named on the command line, with stable exit-code semantics: `0` when the target passes, `1` when required content is missing or invalid, rendering each problem, and `2` when validation cannot run.

#### Scenario: Passing artifact exits zero

- **WHEN** `overmind gate agents-md projects/<project>/project_agents_md_claude_md_backend.md` runs against a compliant artifact
- **THEN** the gate prints its pass message and exits `0`

#### Scenario: Missing content exits one with details

- **WHEN** the target artifact is missing a required section
- **THEN** the gate reports each missing item and exits `1`

#### Scenario: Unrunnable validation exits two

- **WHEN** the target path is absent, is a directory, or no path argument is given
- **THEN** the gate writes an error and exits `2`

### Requirement: The gate validates the recognition header

The gate SHALL require a `## 1. Document Meta` section carrying `artifact_kind` with the literal value `project_agents_md_claude_md`, `class` with one of `backend`, `frontend`, or `mobile`, `project`, `source_blueprint`, and `last_updated` matching `YYYY-MM-DD`. An unsupported `class` value SHALL fail the gate.

#### Scenario: Missing meta key fails

- **WHEN** the artifact omits `source_blueprint` from `## 1. Document Meta`
- **THEN** the gate reports the missing meta key and exits `1`

#### Scenario: Malformed last_updated fails

- **WHEN** `last_updated` is not in `YYYY-MM-DD` format
- **THEN** the gate reports the format problem and exits `1`

#### Scenario: Unsupported class value fails

- **WHEN** `class` carries a value outside `backend`, `frontend`, and `mobile`
- **THEN** the gate reports the unsupported class value and exits `1`

### Requirement: The gate enforces the required section set for the artifact's class

The gate SHALL require `## Stack Baseline`, `## Target Project Shape`, `## Layer Responsibilities`, `## Mission`, `## Non-Negotiable Engineering Rules`, `## Coding Standards`, `## Testing Standard`, `## Linting and Quality Gates`, `## Definition of Done`, and `## Decision Guidance for Agents`. For `frontend` and `mobile` it SHALL accept `## Accessibility (a11y)`, `## Internationalization (i18n)`, `## UI Automation IDs`, and `## Applied Visual Style Contract` as optional sections. It SHALL fail a `backend` artifact that carries any of those four sections, and SHALL fail any artifact carrying an unrecognized top-level section. An empty artifact SHALL fail, and any remaining `[UNFILLED]` placeholder SHALL fail.

#### Scenario: Required section missing fails

- **WHEN** the artifact omits `## Definition of Done`
- **THEN** the gate reports the missing section and exits `1`

#### Scenario: Optional sections pass on a frontend artifact

- **WHEN** a frontend artifact carries every required section plus `## Accessibility (a11y)` and `## Applied Visual Style Contract`
- **THEN** the gate exits `0`

#### Scenario: Class-specific section is rejected on a backend artifact

- **WHEN** a backend artifact carries `## Applied Visual Style Contract`
- **THEN** the gate reports the forbidden section and exits `1`

#### Scenario: Unfilled placeholder fails

- **WHEN** the artifact still carries an `[UNFILLED]` placeholder
- **THEN** the gate reports the placeholder and exits `1`

#### Scenario: Unrecognized top-level section fails

- **WHEN** the artifact carries a top-level section outside the required and optional sets
- **THEN** the gate reports the unexpected section and exits `1`
