## ADDED Requirements

### Requirement: Dependency-graph helper SHALL generate a deterministic implementation-plan report
The repository SHALL provide `overmind/scripts/helper/render_implementation_plan_dependency_graph.sh` that reads `implementation_plan.md` step metadata and generates a deterministic human-readable dependency report.

#### Scenario: Valid implementation plan produces report artifact
- **WHEN** the helper is run against a valid `implementation_plan.md`
- **THEN** it SHALL create `implementation_plan_dependency_graph.md` next to the target plan
- **AND** the report SHALL include the total step count, total dependency edge count, and an explicit acyclic-status line

### Requirement: Dependency report SHALL include direct-dependency listing and Mermaid visualization
The generated dependency report SHALL make step ordering human-reviewable without requiring the reader to inspect raw `#### Depends on:` lines.

#### Scenario: Report includes direct dependencies
- **WHEN** the helper generates the report for a plan with one-or-more dependency edges
- **THEN** the report SHALL list every step id with its direct dependencies or `none`

#### Scenario: Report includes Mermaid graph
- **WHEN** the helper generates the report
- **THEN** the report SHALL include a Mermaid `graph TD` block
- **AND** every dependency edge in the plan SHALL be represented in that Mermaid block

### Requirement: Helper SHALL reject cyclic or graph-invalid dependency metadata
The helper SHALL fail deterministically when the dependency graph cannot be represented as a valid DAG for report generation.

#### Scenario: Dependency cycle is detected
- **WHEN** the target plan contains a dependency cycle
- **THEN** the helper SHALL exit with code `1`
- **AND** SHALL print a concrete failure message naming the cycle or the blocked step ids
- **AND** SHALL not leave a misleading success report artifact behind

#### Scenario: Graph metadata is malformed
- **WHEN** the target plan omits required step/dependency metadata needed for graph construction or references an unknown dependency id
- **THEN** the helper SHALL exit with code `1`
- **AND** SHALL print a concrete validation failure reason

### Requirement: Helper SHALL use deterministic runtime exit semantics
The helper SHALL use exit code `0` for successful report generation, `1` for content or graph-quality failure, and `2` for helper/runtime failure.

#### Scenario: Helper completes successfully
- **WHEN** report generation and graph validation both succeed
- **THEN** the helper SHALL exit with code `0`

#### Scenario: Helper runtime failure occurs
- **WHEN** helper execution cannot complete because required commands are unavailable or file operations fail
- **THEN** the helper SHALL exit with code `2`

### Requirement: Staged helper SHALL resolve feature-local target paths without repository git-root dependency
The staged helper copied into ASDLC workspaces SHALL work from `asdlc/.helper/` against invocation-selected implementation-plan paths.

#### Scenario: Staged helper runs from ASDLC workspace
- **WHEN** `asdlc/.helper/render_implementation_plan_dependency_graph.sh` is invoked for a feature-local `implementation_plan.md`
- **THEN** it SHALL resolve the target path relative to ASDLC root
- **AND** SHALL write `implementation_plan_dependency_graph.md` beside that feature-local plan

### Requirement: Script tests SHALL cover report generation and graph failures
The repository SHALL include script tests under `tests/ai_scripts/` for report generation, Mermaid output, cyclic dependency failure, malformed dependency failure, and staged-helper availability.

#### Scenario: Dependency-graph helper tests run from repository root
- **WHEN** the dependency-graph helper test suite is executed from repository root
- **THEN** it SHALL verify successful report generation and deterministic failure behavior for graph-invalid plans
