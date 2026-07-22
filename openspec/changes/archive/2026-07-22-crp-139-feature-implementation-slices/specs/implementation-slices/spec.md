## ADDED Requirements

### Requirement: Gate command validates all four required sections
`overmind gate implementation-slices <feature-path>` SHALL verify that `implementation_slices.md` in the feature directory contains the headings `## 1. Document Meta`, `## 2. Slice Planning Guardrails`, `## 3. Slice Candidates`, and `## 4. Handoff To Ordered Plan`. A missing section SHALL cause exit `1` with a message naming the missing section.

#### Scenario: All four sections present
- **WHEN** `implementation_slices.md` contains all four `##` section headings
- **THEN** the gate proceeds without a missing-section error

#### Scenario: A section heading is absent
- **WHEN** `implementation_slices.md` is missing `## 3. Slice Candidates`
- **THEN** the gate exits `1` with an error message identifying the missing section

### Requirement: Gate command validates section 1 meta keys and scope literals
The gate SHALL verify that section `## 1. Document Meta` contains all twelve required keys, each present and non-empty (not blank or `[UNFILLED]`): `feature_id`, `feature_title`, `project_type_code`, `source_requirements_ears`, `source_technical_requirements`, `source_feature_contract_delta`, `source_surface_map_artifacts`, `analyzed_repo_classes`, `ordering_scope`, `traceability_scope`, `last_updated`, `confidence_level`. It SHALL additionally verify that `ordering_scope` is exactly `local_prerequisites_only` and `traceability_scope` is exactly `slice_level_only`. A missing/unfilled key or a wrong scope literal SHALL cause exit `1` with a message naming the key.

#### Scenario: All meta keys filled and scopes correct
- **WHEN** all twelve keys are present and non-empty, `ordering_scope: local_prerequisites_only`, and `traceability_scope: slice_level_only`
- **THEN** no section-1 error is emitted

#### Scenario: A meta key is unfilled
- **WHEN** `feature_id` is set to `[UNFILLED]` in section 1
- **THEN** the gate exits `1` with an error message naming `feature_id`

#### Scenario: Wrong ordering_scope literal
- **WHEN** `ordering_scope: global` is used
- **THEN** the gate exits `1` indicating `ordering_scope` must be `local_prerequisites_only`

### Requirement: Gate command requires at least one slice and at least one planned slice
Section 3 SHALL contain at least one `### Slice N:` block, and at least one slice SHALL have `status: planned`. Zero slices, or slices with no `planned` status, SHALL cause exit `1`.

#### Scenario: One planned slice present
- **WHEN** section 3 has a `### Slice 1:` block with `status: planned`
- **THEN** no slice-count or planned-slice error is emitted

#### Scenario: No planned slice present
- **WHEN** section 3 has only slices with `status: existing`
- **THEN** the gate exits `1` indicating at least one planned slice is required

### Requirement: Gate command validates each slice's required fields
Each `### Slice N:` block SHALL contain non-empty values for `repo`, `status`, `objective`, `first_increment`, `prerequisites`, `preserved_operator_surface`, and `evidence`. `repo` SHALL be one of the active project classes and one of `backend`, `frontend`, `mobile`. `status` SHALL be `existing` or `planned`. A missing, unfilled, or invalid field SHALL cause exit `1` naming the slice and field.

#### Scenario: All slice fields valid
- **WHEN** a slice block has all seven fields filled, `repo: backend` (backend active), and `status: planned`
- **THEN** no slice-field error is emitted for that block

#### Scenario: A slice field is unfilled
- **WHEN** slice 2 has an empty `first_increment`
- **THEN** the gate exits `1` naming slice 2 and `first_increment`

#### Scenario: repo outside active classes
- **WHEN** a slice uses `repo: mobile` but `mobile` is not an active project class
- **THEN** the gate exits `1` naming the slice's out-of-scope repo

#### Scenario: invalid status value
- **WHEN** a slice uses `status: done`
- **THEN** the gate exits `1` naming the invalid status

### Requirement: Gate command validates slice evidence tokens
Each slice's `evidence` field SHALL contain at least one valid evidence token. A valid token matches `gap/TECH_REQ-<n>`, `gap/TECH_REQ-NFR-<n>`, or `comp/<slug>` (lowercase slug segments). An empty token entry or a token not matching these grammars SHALL cause exit `1`; a slice with zero valid tokens SHALL cause exit `1`.

#### Scenario: Valid evidence tokens
- **WHEN** a slice has `evidence: gap/TECH_REQ-6, comp/backend-order-service`
- **THEN** no evidence-token error is emitted for that slice

#### Scenario: Invalid evidence token
- **WHEN** a slice has `evidence: TECH_REQ-6`
- **THEN** the gate exits `1` naming the invalid evidence token

#### Scenario: No valid evidence token
- **WHEN** a slice's `evidence` contains only unrecognized tokens
- **THEN** the gate exits `1` indicating the slice must include at least one valid evidence token

### Requirement: Gate command requires at least two checklist bullets per slice
Each `### Slice N:` block SHALL contain at least two checklist bullets matching the form `- [ ] ` / `- [x] ` (a checkbox followed by at least one space), counted exactly as the legacy helper counts them — the check is a bullet count and does not inspect bullet content for concreteness beyond the separate `[UNFILLED]` rejection. A slice with fewer than two such checklist bullets SHALL cause exit `1` with the message that the slice must include at least two concrete checklist bullets.

#### Scenario: Two checklist bullets present
- **WHEN** a slice has two `- [ ]` checklist bullets
- **THEN** no checklist-count error is emitted for that slice

#### Scenario: Fewer than two checklist bullets
- **WHEN** a slice has only one `- [ ]` bullet
- **THEN** the gate exits `1` indicating the slice must include at least two concrete checklist bullets

### Requirement: Gate command rejects forbidden lifecycle boilerplate bullets
The gate SHALL reject any checklist bullet whose text is exactly `Plan and discuss the slice` or `Review slice readiness`. Presence of either SHALL cause exit `1` naming the slice and the forbidden bullet.

#### Scenario: Forbidden lifecycle bullet present
- **WHEN** a slice contains `- [ ] Plan and discuss the slice`
- **THEN** the gate exits `1` naming the forbidden lifecycle boilerplate bullet

### Requirement: Gate command validates coordination slice signal_ref
A slice with `kind: coordination` SHALL contain a non-empty `signal_ref` field. A coordination slice with a missing, empty, or `[UNFILLED]` `signal_ref` SHALL cause exit `1`. A slice without `kind: coordination` SHALL NOT be required to have a `signal_ref`, and absence of any coordination slice SHALL NOT cause an error.

#### Scenario: Coordination slice with signal_ref
- **WHEN** a slice has `kind: coordination` and `signal_ref: signal-contract-lock-1`
- **THEN** no coordination error is emitted for that slice

#### Scenario: Coordination slice missing signal_ref
- **WHEN** a slice has `kind: coordination` but no non-empty `signal_ref`
- **THEN** the gate exits `1` indicating the coordination slice must carry a `signal_ref`

#### Scenario: No coordination slice present
- **WHEN** no slice declares `kind: coordination`
- **THEN** the gate emits no coordination-related error

### Requirement: Gate command validates preserved operator-facing surface
For each slice whose `preserved_operator_surface` is not `none`, the gate SHALL verify the value uses operator-facing surface terms (page/route/shell/login/form/command/job/endpoint/lookup/workspace/tool/link semantics after synonym normalization) and SHALL reject slices that mark a preserved surface while describing supporting-only scaffolding work (auth/token/api/contract/schema/state/coordination/middleware/adapter without any surface term). Either failure SHALL cause exit `1` naming the slice.

#### Scenario: Valid preserved operator surface
- **WHEN** a slice has `preserved_operator_surface: Admin refunds page` and slice text describes delivering that page
- **THEN** no preserved-surface error is emitted for that slice

#### Scenario: preserved_operator_surface is not operator-facing
- **WHEN** a slice has `preserved_operator_surface: token refresh middleware`
- **THEN** the gate exits `1` indicating the preserved surface is not operator-facing

#### Scenario: Supporting-only work marks a preserved surface
- **WHEN** a slice marks a non-`none` `preserved_operator_surface` but its objective/first_increment/checklist describe only auth/adapter/state scaffolding with no surface term
- **THEN** the gate exits `1` indicating the slice describes supporting-only scaffolding work

### Requirement: Gate command enforces required missing operator-facing surfaces when prerequisite_gaps.md exists
When `prerequisite_gaps.md` is present in the feature directory, the gate SHALL extract each required missing operator-facing surface (a `#### Prerequisite:` block whose `status` is `scheduled_in_slices` or `unmet`, whose `surface_kind` is `required_missing_user_reachable_surface`, and whose `surface_identity` is filled) and SHALL verify that each such surface is semantically covered by some slice's non-`none` `preserved_operator_surface` using synonym-tolerant matching. An uncovered required surface SHALL cause exit `1` naming the surface. When `prerequisite_gaps.md` is absent, this cross-check SHALL be skipped and its absence SHALL NOT cause a failure.

#### Scenario: prerequisite_gaps.md absent
- **WHEN** `prerequisite_gaps.md` does not exist in the feature directory
- **THEN** the gate does not perform the required-surface cross-check and does not fail for its absence

#### Scenario: Required surface covered by a slice
- **WHEN** `prerequisite_gaps.md` lists a required missing surface `Admin refunds page` and a slice's `preserved_operator_surface` semantically matches it
- **THEN** no required-surface coverage error is emitted

#### Scenario: Required surface not covered
- **WHEN** `prerequisite_gaps.md` lists a required missing surface that no slice's `preserved_operator_surface` matches
- **THEN** the gate exits `1` naming the uncovered required surface

### Requirement: Gate command validates section 4 handoff keys
Section `## 4. Handoff To Ordered Plan` SHALL contain non-empty values for `ordering_intent`, `unresolved_ordering_questions`, and `unresolved_traceability_questions`. A missing or unfilled key SHALL cause exit `1` naming the key.

#### Scenario: All handoff keys filled
- **WHEN** all three handoff keys are present and non-empty
- **THEN** no section-4 error is emitted

#### Scenario: A handoff key is missing
- **WHEN** `unresolved_traceability_questions` is absent from section 4
- **THEN** the gate exits `1` naming `unresolved_traceability_questions`

### Requirement: Gate command rejects structured UNFILLED placeholder values
If a recognized meta, slice, or handoff field value; slice title; or checklist bullet consists of a bracketed placeholder containing `UNFILLED` (case-insensitive), the gate SHALL exit `1` with a message indicating unfilled placeholder values remain. The gate SHALL allow `[UNFILLED]` when it is embedded in otherwise substantive prose, such as a checklist bullet describing removal of upstream placeholder markers.

#### Scenario: Structured value is an UNFILLED placeholder
- **WHEN** a recognized field value is `[UNFILLED]`, a slice title is `[UNFILLED title]`, or a checklist bullet is `[UNFILLED concrete implementation slice]`
- **THEN** the gate exits `1` indicating unfilled placeholder values

#### Scenario: Checklist prose references the placeholder convention
- **WHEN** a checklist bullet is `Replace [UNFILLED] markers left by upstream`
- **THEN** the gate does not emit an unfilled-placeholder error

### Requirement: Gate command fails on missing runtime inputs
`overmind gate implementation-slices <feature-path>` SHALL exit `2` with an actionable error when the target artifact path argument is missing, when the target artifact is absent, or when any required sibling — `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md` (feature directory), or `init_progress_definition.yaml` (parent project directory) — is absent, or when no supported active repo class can be derived from `init_progress_definition.yaml`. An empty (whitespace-only) target artifact is a content failure and SHALL exit `1`, matching the legacy helper, not `2`.

#### Scenario: Missing target path argument
- **WHEN** the gate is invoked without a target artifact path
- **THEN** it exits `2` with a usage error

#### Scenario: Absent target artifact
- **WHEN** `implementation_slices.md` does not exist in the feature directory
- **THEN** the gate exits `2` naming the missing target artifact

#### Scenario: Empty target artifact
- **WHEN** `implementation_slices.md` exists but contains only whitespace
- **THEN** the gate exits `1` indicating the artifact is empty

#### Scenario: Missing required sibling artifact
- **WHEN** `technical_requirements.md` is absent from the feature directory
- **THEN** the gate exits `2` naming the missing sibling artifact

#### Scenario: Missing project definition
- **WHEN** `init_progress_definition.yaml` is absent from the parent project directory
- **THEN** the gate exits `2` naming the missing project definition

### Requirement: Context command emits full multi-class slice context block
`overmind context implementation-slices <feature-path>` SHALL resolve the feature path inside `projects/<project-id>/<feature-folder>`, read active project classes from `init_progress_definition.yaml`, accept only `backend`, `frontend`, `mobile`, and `infrastructure`, skip `infrastructure` when resolving surface maps, and fail resolution with exit `2` for any unsupported class. It SHALL resolve each surface-map class's surface map file (`project_surface_struct_resp_map_<class>.md`) and emit one context block containing: workspace root, feature root, project root, active repo classes, target artifact path (`<feature-path>/implementation_slices.md`), read-only manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, each applicable surface map, and — when it is already present in the feature directory — `prerequisite_gaps.md`), asset references (skill-relative template and golden example paths), and the exact gate command `node .overmind/overmind.js gate implementation-slices <feature-path>`. It SHALL require at least one supported surface-map class. Because `prerequisite_gaps.md` is consumed by the gate's required-surface cross-check, it SHALL be listed as a read-only input whenever present so the model is instructed not to modify it; its absence SHALL NOT cause an error.

#### Scenario: Two active classes resolved
- **WHEN** active classes are `backend` and `frontend` and both surface maps exist
- **THEN** the context block lists both surface map file paths plus the three feature sibling artifacts in the read-only manifest

#### Scenario: Infrastructure class is silently skipped
- **WHEN** active classes include `infrastructure` alongside `backend`
- **THEN** the context block does not reference any `project_surface_struct_resp_map_infrastructure.md` path and emits no error

#### Scenario: prerequisite_gaps.md present is listed read-only
- **WHEN** `prerequisite_gaps.md` already exists in the feature directory
- **THEN** the read-only manifest includes `prerequisite_gaps.md` as a do-not-modify input

#### Scenario: prerequisite_gaps.md absent is omitted without error
- **WHEN** `prerequisite_gaps.md` does not exist in the feature directory
- **THEN** the read-only manifest omits it and the context command does not fail

#### Scenario: Gate command in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains `node .overmind/overmind.js gate implementation-slices` followed by the feature path

#### Scenario: Workspace root in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains the absolute workspace root path and the feature-relative target artifact path

### Requirement: Context command fails on missing required inputs
If `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, or any surface-map class's (`backend`/`frontend`/`mobile`) surface map file is absent, `overmind context implementation-slices <feature-path>` SHALL exit `2` with an actionable error naming the missing file. `infrastructure` class does not require a surface map and its absence SHALL NOT cause an error.

#### Scenario: Missing technical_requirements.md
- **WHEN** `technical_requirements.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Missing surface map for active class
- **WHEN** active classes include `frontend` but `project_surface_struct_resp_map_frontend.md` is absent
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Feature path outside workspace
- **WHEN** the feature path does not resolve under `projects/<project-id>/<feature>/` within the workspace
- **THEN** the context command exits `2` describing the path constraint

### Requirement: Skill SKILL.md instructs model to run gate after every write
The `overmind-implementation-slices` SKILL.md SHALL instruct the model to: (1) run `overmind context implementation-slices <feature-path>` to obtain runtime bindings; (2) draft `implementation_slices.md` using the bound template and golden example; (3) write only `implementation_slices.md` and no other files; (4) run `overmind gate implementation-slices <feature-path>` after every write or repair; (5) on gate exit `1`, read the output, repair the artifact, and rerun the gate; (6) on gate exit `2`, stop and report the blocker to the operator; (7) on gate exit `0`, end with the prompt-provided success line. It SHALL preserve the slice-planning constraints from the rule: thin executable slices, first usable increment framing, minimal local prerequisites only, no forced full cross-repo ordering, no forced full REQ/NFR traceability, and explicit preservation of required missing operator-facing surfaces via feature-delivery slices.

#### Scenario: Gate loop on exit 1
- **WHEN** the gate exits `1` after the first write
- **THEN** SKILL.md instructs the model to repair the artifact and rerun the gate, not to stop

#### Scenario: Success line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal success line `Implementation slice planning phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`

#### Scenario: Infeasibility line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal infeasibility line `implementation slice planning gate cannot pass with current requirements/technical/contract/surface-map inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`
