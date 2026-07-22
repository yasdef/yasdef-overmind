## ADDED Requirements

### Requirement: Scaffold primitive creates a feature summary from project metadata

`capture/scaffold-feature.ts` SHALL validate a project path within the workspace, locate its ancestor `init_progress_definition.yaml`, load a supported `project_type_code` and matching label through the typed parser, and render `.templates/feature_br_summary_TEMPLATE.md` to a new feature folder. It SHALL replace feature id/title/project type placeholders and set `ready_to_ears` to false.

#### Scenario: Valid scaffold creates summary
- **WHEN** a valid project, non-empty feature id/title, template, definition, and clock value are supplied
- **THEN** the primitive creates the feature folder and `feature_br_summary.md` with all required values populated

#### Scenario: Required input is missing
- **WHEN** the template, definition, supported project metadata, feature id, or feature title is unavailable
- **THEN** no partial feature summary is accepted and the typed result contains an actionable diagnostic

### Requirement: Feature folder naming preserves deterministic shell semantics

The scaffold SHALL lowercase the feature title, replace non-alphanumeric runs with underscores, trim/collapse underscores, require at least one alphanumeric character, and append an injected Unix timestamp as `<normalized-title>-<timestamp>`. It SHALL fail if the target path already exists.

#### Scenario: Title is normalized
- **WHEN** the title is `  Add OAuth / Login! ` and the timestamp is `1234`
- **THEN** the folder basename is `add_oauth_login-1234`

#### Scenario: Title has no alphanumeric content
- **WHEN** normalization produces an empty name
- **THEN** the primitive returns a validation diagnostic and creates no feature folder

#### Scenario: Target collision is detected
- **WHEN** the computed feature folder already exists
- **THEN** the primitive returns a collision diagnostic and does not overwrite it

### Requirement: Scaffold input and result are typed

The primitive SHALL obtain missing feature id/title values through `InteractionPort` with the existing required-input retry semantics and SHALL return the canonical created feature path and output path as typed fields. Callers SHALL consume those fields rather than scrape human-readable output.

#### Scenario: Empty interactive value is retried
- **WHEN** an interactive feature id or title response is blank after trimming
- **THEN** the primitive reports that input cannot be empty and asks again

#### Scenario: Created path is returned directly
- **WHEN** scaffold creation succeeds
- **THEN** the result contains the created feature and summary paths independently of any stdout text

### Requirement: Scaffold is available through CLI and step 3

The system SHALL add `overmind scaffold feature --path <project>` as a thin CLI adapter over the primitive and register `scaffold-feature` in the deterministic action registry used by `executeStep`. Step 3 SHALL execute through that registry and persist the typed created path in feature state.

#### Scenario: Standalone scaffold uses the shared primitive
- **WHEN** `overmind scaffold feature --path <project>` runs successfully
- **THEN** it creates the same artifacts and prints the created/updated paths for the operator

#### Scenario: Catalog step 3 dispatches the primitive
- **WHEN** `executeStep` processes step 3's `write` action
- **THEN** the registered scaffold primitive runs and returns its typed result without a step-id branch in the executor

### Requirement: Shell scaffold cutover is complete

After TypeScript parity tests cover `tests/ai_scripts/init_br_scaffold_tests.sh`, the system SHALL delete `overmind/scripts/feature_br_scaffold.sh` and that shell test, remove scaffold staging references, and update operator documentation to `overmind scaffold feature` where standalone scaffolding is described.

#### Scenario: Replaced scaffold assets are absent
- **WHEN** the Slice 3 change is complete
- **THEN** the source script, shell test, and staging entry no longer exist and root verification uses the TypeScript scaffold tests
