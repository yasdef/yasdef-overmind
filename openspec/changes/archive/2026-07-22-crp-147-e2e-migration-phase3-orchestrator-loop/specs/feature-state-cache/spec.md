## ADDED Requirements

### Requirement: Feature state uses a project-local JSON cache

The system SHALL store the selected feature as one workspace-relative `featurePath` in `<project>/.overmind_feature_state.json`. It SHALL write the cache after successful existing-feature selection and after successful scaffold creation. It SHALL ignore the legacy `.project_add_feature_e2e_state.env` rather than migrate it.

#### Scenario: Selected unfinished feature is persisted
- **WHEN** the operator selects an existing unfinished feature
- **THEN** the JSON cache is atomically updated with that feature's canonical workspace-relative path

#### Scenario: Scaffold result is persisted without parsing output
- **WHEN** step 3 successfully creates a feature
- **THEN** the typed scaffold result's feature path is written to the JSON cache without reading stdout

#### Scenario: Legacy state is ignored
- **WHEN** only `.project_add_feature_e2e_state.env` exists
- **THEN** the run performs normal feature selection and writes new JSON state after a target is chosen

### Requirement: Cached paths are contained and stale-safe

On read, the system SHALL validate JSON shape and require the cached path to resolve to an existing directory inside the workspace and under the selected project. Missing, malformed, escaping, or no-longer-existing values SHALL be reported as stale and ignored without throwing or deleting unrelated data.

#### Scenario: Valid cache is loaded
- **WHEN** the cache contains a canonical path to an existing feature under the selected project
- **THEN** the loader returns that feature as valid cached context

#### Scenario: Missing feature path is stale
- **WHEN** the cached feature directory no longer exists
- **THEN** the loader returns stale state with an actionable notice and feature selection continues

#### Scenario: Escaping path is rejected
- **WHEN** the cached path resolves outside the selected project or workspace
- **THEN** it is treated as stale and is never used as an execution target

#### Scenario: Malformed JSON does not crash the run
- **WHEN** the cache file cannot be parsed
- **THEN** the loader returns a diagnostic/stale result and the orchestrator continues to feature selection
