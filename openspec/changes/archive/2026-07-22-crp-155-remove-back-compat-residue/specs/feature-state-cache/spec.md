## ADDED Requirements

### Requirement: Feature-state cache recognizes only the JSON cache file

The feature-state reader SHALL treat `.overmind_feature_state.json` as the sole
per-project feature-state cache. It SHALL NOT export or reference any named legacy
state format. A project directory that contains only non-cache files (including a
`.project_add_feature_e2e_state.env` file left by unrelated tooling) SHALL be reported
as having no cache, because the cache file is absent — not because a legacy format is
specially recognized and ignored.

#### Scenario: Only the JSON cache file counts as a cache

- **WHEN** `readFeatureState` runs against a project directory that has no
  `.overmind_feature_state.json`
- **THEN** the result state is `missing` with no diagnostics, regardless of any other
  files present in the directory

#### Scenario: No legacy state constant is exported

- **WHEN** the `asdlc-coordinator` state module surface is inspected
- **THEN** no `LEGACY_FEATURE_STATE_FILE_NAME` export exists, and `FEATURE_STATE_FILE_NAME`
  (`.overmind_feature_state.json`) is the only feature-state filename constant
