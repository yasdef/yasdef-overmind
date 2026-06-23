## ADDED Requirements

### Requirement: Gate command validates all seven required sections
`overmind gate technical-requirements <feature-path>` SHALL verify that `technical_requirements.md` in the feature directory contains exactly the headings `## 1. Document Meta`, `## 2. Feature Scope and Inputs`, `## 3. Repository Evidence`, `## 4. Requirement Coverage and Gaps`, `## 5. Impacted Components`, `## 6. Cross-Repo Constraints and Planning Signals`, and `## 7. Known Risks / Uncertainties`. A missing section SHALL cause exit `1` with a message naming the missing section.

#### Scenario: All seven sections present
- **WHEN** `technical_requirements.md` contains all seven `##` section headings in any order
- **THEN** the gate proceeds without a missing-section error

#### Scenario: A section heading is absent
- **WHEN** `technical_requirements.md` is missing `## 4. Requirement Coverage and Gaps`
- **THEN** the gate exits `1` with an error message identifying the missing section

### Requirement: Gate command validates section 1 scalar keys
The gate SHALL verify that section `## 1. Document Meta` contains all nine required scalar keys: `feature_id`, `feature_title`, `project_type_code`, `source_requirements_ears`, `source_common_contract_definition`, `source_surface_map_artifacts`, `analyzed_repo_classes`, `last_updated`, `confidence_level`. Each key SHALL be present and non-empty (not blank or `[UNFILLED]`). A missing or unfilled key SHALL cause exit `1` with a message naming the key.

#### Scenario: All section-1 keys filled
- **WHEN** all nine scalar keys are present and non-empty in section 1
- **THEN** no section-1 error is emitted

#### Scenario: A section-1 key is unfilled
- **WHEN** `feature_id` is set to `[UNFILLED]` in section 1
- **THEN** the gate exits `1` with an error message naming `feature_id`

### Requirement: Gate command validates section 2 scalar keys
The gate SHALL verify that section `## 2. Feature Scope and Inputs` contains `feature_summary`, `included_behavior`, and `excluded_behavior` as non-empty scalar keys. A missing or unfilled key SHALL cause exit `1` with a message naming the key.

#### Scenario: All section-2 keys filled
- **WHEN** all three scalar keys are present and non-empty in section 2
- **THEN** no section-2 error is emitted

#### Scenario: A section-2 key is missing
- **WHEN** `excluded_behavior` is absent from section 2
- **THEN** the gate exits `1` with an error message naming `excluded_behavior`

### Requirement: Gate command requires one repository evidence block per applicable surface-map class
The gate SHALL read `init_progress_definition.yaml` from the parent project directory to derive active project classes, then restrict to surface-map classes only (`backend`, `frontend`, `mobile`; `infrastructure` and any other non-surface-map class are skipped). It SHALL verify that section 3 contains at least one `### Repository:` block whose `class` key matches each surface-map class. A surface-map class with no evidence block SHALL cause exit `1` with a message naming the class. The gate SHALL NOT require a `### Repository:` block for `infrastructure` or any class outside the surface-map set.

#### Scenario: All surface-map classes have a repository block
- **WHEN** active classes are `backend` and `frontend` and section 3 contains a `### Repository:` block with `class: backend` and one with `class: frontend`
- **THEN** no section-3 repo coverage error is emitted

#### Scenario: An active surface-map class is missing a repository block
- **WHEN** active classes include `mobile` but section 3 has no block with `class: mobile`
- **THEN** the gate exits `1` naming the missing class

#### Scenario: Infrastructure class is skipped without error
- **WHEN** active classes include `infrastructure` alongside `backend`
- **THEN** the gate does not require a `### Repository:` block for `infrastructure` and emits no error for its absence

#### Scenario: Missing init_progress_definition.yaml causes runtime failure
- **WHEN** `init_progress_definition.yaml` is absent from the parent project directory
- **THEN** the gate exits `2` with an error naming the missing file

### Requirement: Gate command validates repository block required fields
Each `### Repository:` block in section 3 SHALL contain non-empty values for `class`, `evidence_scope`, `primary_paths`, `key_findings`, `constraints`, and `open_gaps`. A missing or unfilled field SHALL cause exit `1` naming the block and field.

#### Scenario: All repository block fields filled
- **WHEN** a `### Repository:` block has all six fields non-empty
- **THEN** no block-level field error is emitted for that block

#### Scenario: A repository block field is unfilled
- **WHEN** a `### Repository: Backend Service` block has `primary_paths` empty
- **THEN** the gate exits `1` naming `Backend Service` and `primary_paths`

### Requirement: Gate command requires one requirement block per REQ-*/NFR-* in requirements_ears.md
The gate SHALL read `requirements_ears.md` from the feature directory to derive valid `REQ-*` and `NFR-*` identifiers, and SHALL verify that section 4 contains one `### Requirement:` block for each such identifier. A missing block SHALL cause exit `1` naming the missing requirement ID. An unknown requirement ID used in a block (not present in `requirements_ears.md`) SHALL also cause exit `1`.

#### Scenario: All requirement IDs covered
- **WHEN** `requirements_ears.md` defines REQ-1 and NFR-1 and section 4 has a block for each
- **THEN** no requirement coverage error is emitted

#### Scenario: A requirement ID is missing from section 4
- **WHEN** `requirements_ears.md` defines REQ-3 but section 4 has no `### Requirement: REQ-3` block
- **THEN** the gate exits `1` naming `REQ-3`

#### Scenario: Missing requirements_ears.md causes runtime failure
- **WHEN** `requirements_ears.md` is absent from the feature directory
- **THEN** the gate exits `2` with an error naming the missing file

### Requirement: Gate command validates requirement block transport/surface split
Each `### Requirement:` block in section 4 SHALL use `transport_layer` and `user_reachable_surface` as separate subfields. A block that uses a single `current_state:` prose line SHALL cause exit `1`. Either subfield absent or unfilled SHALL also cause exit `1`.

#### Scenario: Correct transport/surface split
- **WHEN** a requirement block has both `transport_layer` and `user_reachable_surface` filled and no `current_state` key
- **THEN** no split error is emitted for that block

#### Scenario: Conflated current_state line used
- **WHEN** a requirement block has `current_state: some prose` instead of the split fields
- **THEN** the gate exits `1` indicating the conflated line is invalid

#### Scenario: transport_layer subfield missing
- **WHEN** a requirement block has `user_reachable_surface` filled but no `transport_layer`
- **THEN** the gate exits `1` naming the missing `transport_layer` subfield

### Requirement: Gate command validates requirement block other required fields
Each `### Requirement:` block SHALL contain non-empty values for `requirement_summary`, `gap_status`, `repo_impact`, `evidence`, and `gap_to_close`. `gap_status` SHALL be one of `fully_implemented`, `partially_implemented`, `not_implemented`, `unclear`. `repo_impact` SHALL be one of the active class names or `multiple`. A missing, unfilled, or invalid field SHALL cause exit `1`.

#### Scenario: Valid gap_status value
- **WHEN** `gap_status: partially_implemented` is used
- **THEN** no `gap_status` error is emitted

#### Scenario: Invalid gap_status value
- **WHEN** `gap_status: unknown` is used
- **THEN** the gate exits `1` naming the invalid `gap_status` value

#### Scenario: repo_impact outside active classes
- **WHEN** `repo_impact: infrastructure` is used but `infrastructure` is not an active class
- **THEN** the gate exits `1` naming the invalid `repo_impact` value

### Requirement: Gate command requires at least one component block with valid fields
Section 5 SHALL contain at least one `### Component:` block. For each repo that has surface entries marked `applicability: applicable` in its surface map, the gate SHALL verify at least one component block has its `repo` field set to that class. Each component block SHALL contain non-empty `repo`, `component_kind`, `relevant_paths`, `requirement_refs`, `current_state`, `required_behavior`, `gap_to_close`, `dependency_notes`, and `evidence`. `component_kind` SHALL be one of the fourteen allowed values. `requirement_refs` SHALL reference at least one valid `REQ-*` or `NFR-*` ID.

#### Scenario: Valid component block
- **WHEN** a `### Component: AuthService` block has all nine fields filled with a valid `component_kind` and a valid `requirement_refs`
- **THEN** no component error is emitted

#### Scenario: Invalid component_kind
- **WHEN** `component_kind: handler` is used (not in the allowed list)
- **THEN** the gate exits `1` naming the invalid `component_kind`

#### Scenario: requirement_refs references unknown ID
- **WHEN** `requirement_refs: REQ-99` is used and REQ-99 is not in `requirements_ears.md`
- **THEN** the gate exits `1` naming the unknown requirement ID

#### Scenario: Repo with applicable surface has no component
- **WHEN** `project_surface_struct_resp_map_backend.md` has at least one entry with `applicability: applicable` but no component block has `repo: backend`
- **THEN** the gate exits `1` naming the missing repo

### Requirement: Gate command validates section 6 planning signal or empty marker
Section 6 SHALL contain either one or more `### Planning Signal:` blocks with required fields, or the exact empty marker line `- planning_signals: none`. Mixing both, using the legacy `constraint_*`/`prep_*` format, or providing neither SHALL cause exit `1`. Each planning signal block SHALL contain `signal_id`, `signal_type`, `owner_repo`, `consumer_repos`, `required_artifact`, `must_precede`, `output_requirements`, and `source_evidence`. `signal_type` SHALL be `cross_repo_contract_lock`. `owner_repo` and every `consumer_repos` entry SHALL be active classes. `source_evidence` tokens SHALL be valid `REQ-*`, `NFR-*`, or `comp/<slug>` references.

#### Scenario: Empty marker used
- **WHEN** section 6 contains exactly `- planning_signals: none` and no signal blocks
- **THEN** no section-6 error is emitted

#### Scenario: Valid planning signal block
- **WHEN** a `### Planning Signal: PS-1` block has all required fields, `signal_type: cross_repo_contract_lock`, active-class owner/consumer, and valid source_evidence
- **THEN** no signal-block error is emitted

#### Scenario: Legacy constraint entry used
- **WHEN** section 6 contains a `- constraint_1: ...` entry
- **THEN** the gate exits `1` indicating the retired format

#### Scenario: Signal block with invalid signal_type
- **WHEN** a planning signal has `signal_type: optional_coordination`
- **THEN** the gate exits `1` naming the unsupported signal type

### Requirement: Gate command requires at least one risk entry in section 7
Section 7 SHALL contain at least one non-empty `- risk_N: ...` entry. An empty section 7 or a section with no filled risk entries SHALL cause exit `1`.

#### Scenario: Section 7 has a risk entry
- **WHEN** section 7 contains `- risk_1: Some known risk description`
- **THEN** no section-7 error is emitted

#### Scenario: Section 7 has no risk entries
- **WHEN** section 7 is present but contains no `risk_N` entries
- **THEN** the gate exits `1` indicating section 7 must have at least one explicit risk

### Requirement: Gate command rejects artifacts with UNFILLED placeholders
If the target artifact contains any line matching `[UNFILLED]` (case-insensitive), the gate SHALL exit `1` with a message indicating unfilled placeholders remain.

#### Scenario: Artifact contains UNFILLED placeholder
- **WHEN** any line in `technical_requirements.md` contains `[UNFILLED]`
- **THEN** the gate exits `1` indicating unfilled placeholders

### Requirement: Context command emits full multi-class context block
`overmind context technical-requirements <feature-path>` SHALL resolve the feature path inside `projects/<project-id>/<feature-folder>`, read active project classes from `init_progress_definition.yaml`, accept only `backend`, `frontend`, `mobile`, and `infrastructure`, skip `infrastructure` when resolving surface maps, and exit `2` with an actionable error naming any unsupported class. It SHALL resolve each surface-map class's surface map file (`project_surface_struct_resp_map_<class>.md`) and emit one context block containing: workspace root, feature root, project root, target artifact path (`<feature-path>/technical_requirements.md`), read-only manifest (one entry per input: `init_progress_definition.yaml`, `requirements_ears.md`, `common_contract_definition.md`, each applicable surface map), the list of surface-map classes and their surface map paths, asset references (skill-relative template and golden example paths), and the exact gate command `node .overmind/overmind.js gate technical-requirements <feature-path>`.

#### Scenario: Two active classes resolved
- **WHEN** active classes are `backend` and `frontend` and both surface maps exist
- **THEN** the context block lists both surface map file paths in the read-only manifest and the binding block

#### Scenario: Infrastructure class is silently skipped
- **WHEN** active classes include `infrastructure` alongside `backend`
- **THEN** the context block does not reference any `project_surface_struct_resp_map_infrastructure.md` path and emits no error

#### Scenario: Unsupported project class is rejected
- **WHEN** active classes include `backend` and unsupported class `bakend`
- **THEN** the context command exits `2` with an actionable error naming `bakend`

#### Scenario: Workspace root in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains the absolute workspace root path and the feature-relative target artifact path

#### Scenario: Gate command in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains `node .overmind/overmind.js gate technical-requirements` followed by the feature path

### Requirement: Context command fails on missing required inputs
If `init_progress_definition.yaml`, `requirements_ears.md`, `common_contract_definition.md`, or any surface-map class's (`backend`/`frontend`/`mobile`) surface map file is absent, `overmind context technical-requirements <feature-path>` SHALL exit `2` with an actionable error naming the missing file. `infrastructure` class does not require a surface map and its absence SHALL NOT cause an error.

#### Scenario: Missing requirements_ears.md
- **WHEN** `requirements_ears.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Missing surface map for active class
- **WHEN** active classes include `frontend` but `project_surface_struct_resp_map_frontend.md` is absent
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Feature path outside workspace
- **WHEN** the feature path does not resolve under `projects/<project-id>/<feature>/` within the workspace
- **THEN** the context command exits `2` describing the path constraint

### Requirement: Skill SKILL.md instructs model to run gate after every write
The `overmind-technical-requirements` SKILL.md SHALL instruct the model to: (1) run `overmind context technical-requirements <feature-path>` to obtain runtime bindings; (2) draft `technical_requirements.md` using the bound template and golden example; (3) write only `technical_requirements.md` and no other files; (4) run `overmind gate technical-requirements <feature-path>` after every write or repair; (5) on gate exit `1`, read the output, repair the artifact, and rerun the gate; (6) on gate exit `2`, stop and report the blocker to the operator; (7) on gate exit `0`, end with the prompt-provided success line.

#### Scenario: Gate loop on exit 1
- **WHEN** the gate exits `1` after the first write
- **THEN** SKILL.md instructs the model to repair the artifact and rerun the gate, not to stop

#### Scenario: Success line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal success line `Feature technical requirements phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`

#### Scenario: Infeasibility line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal infeasibility line `feature technical requirements gate cannot pass with current requirements/common-contract/surface-map inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`

### Requirement: Skill is installed to all supported runner targets by the installer
`installProject` in `packages/installer/src/init.ts` SHALL include `overmind-technical-requirements` in `PACKAGED_SKILLS` and install it to `.codex/skills/overmind-technical-requirements/` and `.claude/skills/overmind-technical-requirements/` using the same canonical-source validation and write pattern applied to all other skills.

#### Scenario: Fresh install includes the new skill
- **WHEN** `installProject` runs on a clean project root
- **THEN** both `.codex/skills/overmind-technical-requirements/SKILL.md` and `.claude/skills/overmind-technical-requirements/SKILL.md` exist after install

#### Scenario: Skill payload missing blocks install
- **WHEN** `packages/installer/_data/skills/overmind-technical-requirements/SKILL.md` is absent from the package
- **THEN** `installProject` throws before writing any runner target

### Requirement: E2e runner invokes skill for phase 8 with read-only guards and output assertion
`project_add_feature_e2e.sh` phase 8 SHALL launch the `overmind-technical-requirements` skill via Codex using `run_technical_requirements_skill`, snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `common_contract_definition.md`, and all applicable surface map files before the session, `cmp`-assert each byte-unchanged after the session on every exit path, and assert `technical_requirements.md` was produced. The shell e2e SHALL NOT run the quality gate itself.

#### Scenario: Phase 8 starts the skill
- **WHEN** the e2e runner reaches phase 8
- **THEN** a Codex session is started with a prompt that names the `overmind-technical-requirements` skill and includes the exact `context technical-requirements` and `gate technical-requirements` commands

#### Scenario: Read-only input mutation fails the phase
- **WHEN** the model modifies `requirements_ears.md` during the phase-8 session
- **THEN** the `cmp` post-session check detects drift and the phase fails with an actionable error

#### Scenario: Output file not produced
- **WHEN** the Codex session exits but `technical_requirements.md` is not present in the feature directory
- **THEN** the e2e runner fails the phase with an error naming the missing file
