## ADDED Requirements

### Requirement: Context command emits no-op signal when nothing to enrich
When `overmind context surface-map-enrich <feature-path>` runs and either no surface-map files in the feature contain the literal `<to be defined during implementation>`, or no eligible knowledge-base source names are configured in `.setup/external_sources.yaml`, the command SHALL exit `0` and emit a context block that includes `no_op: true` with a human-readable reason. The model SHALL read the `no_op` field first and finish the session immediately without querying any MCP source or modifying any file.

#### Scenario: No surface maps with placeholder present
- **WHEN** `overmind context surface-map-enrich <feature-path>` runs and none of `project_surface_struct_resp_map_backend.md`, `project_surface_struct_resp_map_frontend.md`, `project_surface_struct_resp_map_mobile.md` contain the placeholder literal
- **THEN** the command exits `0` and the emitted text contains `no_op: true` and a reason indicating no placeholders were found

#### Scenario: No eligible knowledge-base sources configured
- **WHEN** `overmind context surface-map-enrich <feature-path>` runs and surface maps with placeholders exist, but `.setup/external_sources.yaml` contains no source whose `name` field contains `knowledge`, `kb`, or equivalent (case-insensitive)
- **THEN** the command exits `0` and the emitted text contains `no_op: true` and a reason indicating no eligible KB sources are configured

### Requirement: Context command emits full enrichment context when enrichment is possible
When surface maps with the placeholder literal exist and at least one eligible KB source name is configured, `overmind context surface-map-enrich <feature-path>` SHALL exit `0` and emit a context block that includes: workspace root, feature root, the list of surface-map file paths that contain placeholders with their class, the gate command for each class, and the list of eligible KB source names.

#### Scenario: Backend surface map with placeholder and KB source configured
- **WHEN** `project_surface_struct_resp_map_backend.md` contains `<to be defined during implementation>` and `.setup/external_sources.yaml` lists at least one source whose name contains `kb`
- **THEN** the command exits `0`, the context text lists the backend surface map path and class, the gate command `node .overmind/overmind.js gate surface-map <feature-path> --class backend`, and the eligible KB source name(s)

#### Scenario: Multiple classes with placeholders
- **WHEN** both a backend and a frontend surface map contain the placeholder literal
- **THEN** the context text lists both map paths, their respective classes, and both per-class gate commands

### Requirement: Context command fails on missing required runtime inputs
When `.setup/external_sources.yaml` does not exist and surface maps with placeholders are present, or when the feature path does not resolve inside the workspace, `overmind context surface-map-enrich <feature-path>` SHALL exit `2` with an actionable error message.

#### Scenario: Missing external_sources.yaml when surface maps have placeholders
- **WHEN** surface maps with the placeholder literal exist but `.setup/external_sources.yaml` is absent
- **THEN** the command exits `2` and the error message names the missing file

#### Scenario: Feature path outside workspace
- **WHEN** `<feature-path>` does not resolve under `projects/<project-id>/<feature-folder>` within the workspace
- **THEN** the command exits `2` with an error describing the path constraint

### Requirement: Skill enriches placeholder fields using KB MCP source with user confirmation
The `overmind-surface-map-enrich` skill SHALL instruct the model to: (1) run `overmind context surface-map-enrich` and check the `no_op` field first; (2) if not a no-op, verify each eligible KB source is reachable; (3) for each surface map with placeholders, query the first reachable source for candidate values and present a confirmation summary to the operator; (4) apply only operator-confirmed replacements; (5) after confirmed edits to a map, run the per-class gate command and repair if exit `1`; (6) after a passing gate, write `was_enriched_with_mcp: true` in the Document Meta section of that map.

#### Scenario: Operator confirms replacement
- **WHEN** the model presents a replacement candidate and the operator confirms
- **THEN** the model applies the replacement, runs the per-class gate, and upon gate exit `0` sets `was_enriched_with_mcp: true` in the map's Document Meta

#### Scenario: Operator declines replacement
- **WHEN** the model presents a replacement candidate and the operator declines
- **THEN** the model leaves the placeholder unchanged and does not set `was_enriched_with_mcp: true`

#### Scenario: No KB source reachable
- **WHEN** no configured KB source is reachable during the skill session
- **THEN** the model reports enrichment is unavailable and ends the session without modifying any file

#### Scenario: No-op detected from context
- **WHEN** the context block contains `no_op: true`
- **THEN** the model reports the reason and ends the session immediately without querying any MCP source

### Requirement: Skill uses existing surface-map gate, not a new gate
The `overmind-surface-map-enrich` skill SHALL reference only `node .overmind/overmind.js gate surface-map <feature-path> --class <klass>` for quality validation. No separate `gate surface-map-enrich` command SHALL exist.

#### Scenario: Gate command format in SKILL.md
- **WHEN** the SKILL.md is installed and read by a model
- **THEN** the gate command section references `gate surface-map` with a `--class` argument, not a `gate surface-map-enrich` command

### Requirement: Skill is installed to all supported runner targets by the installer
`installProject` in `packages/installer/src/init.ts` SHALL include `overmind-surface-map-enrich` in `PACKAGED_SKILLS` and install it to `.codex/skills/overmind-surface-map-enrich/` and `.claude/skills/overmind-surface-map-enrich/` using the same canonical-source validation and write pattern applied to all other skills.

#### Scenario: Fresh install includes the new skill
- **WHEN** `installProject` runs on a clean project root
- **THEN** both `.codex/skills/overmind-surface-map-enrich/SKILL.md` and `.claude/skills/overmind-surface-map-enrich/SKILL.md` exist after install

#### Scenario: Skill payload missing blocks install
- **WHEN** `packages/installer/_data/skills/overmind-surface-map-enrich/SKILL.md` is absent from the package
- **THEN** `installProject` throws before writing any runner target

### Requirement: E2e runner invokes skill for phase 7.1 and enforces read-only-input guards
`project_add_feature_e2e.sh` phase `7.1` SHALL launch the `overmind-surface-map-enrich` skill via Codex using `run_surface_map_enrich_skill`, snapshot `external_sources.yaml` and `init_progress_definition.yaml` before the session, and assert they are byte-unchanged afterward. The shell e2e SHALL NOT run the quality gate itself.

#### Scenario: Phase 7.1 starts the skill
- **WHEN** the e2e runner reaches phase `7.1`
- **THEN** a Codex session is started with a prompt that names the `overmind-surface-map-enrich` skill and includes the exact `context surface-map-enrich` and `gate surface-map` commands

#### Scenario: Read-only input mutation fails the phase
- **WHEN** the Codex stub modifies `external_sources.yaml` during the phase 7.1 session
- **THEN** the e2e runner detects the mutation via `cmp` and fails the phase with an actionable error

### Requirement: Legacy bash artifacts are deleted after skill parity is established
`feature_surface_map_mcp_placeholder_enrichment.sh`, `feature_surface_map_mcp_placeholder_enrichment_rule.md`, and `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh` SHALL be deleted. All references to these files in setup staging arrays, test listings, README, and docs SHALL be removed in the same change.

#### Scenario: Old script removed from staging
- **WHEN** the migration change is complete
- **THEN** `project_setup_first_init_machine.sh` contains no reference to `feature_surface_map_mcp_placeholder_enrichment.sh` or `feature_surface_map_mcp_placeholder_enrichment_rule.md`

#### Scenario: Old shell test removed from test listing
- **WHEN** the migration change is complete
- **THEN** `CLAUDE.md` and any test runner docs do not list `feature_surface_map_mcp_placeholder_enrichment_tests.sh`
