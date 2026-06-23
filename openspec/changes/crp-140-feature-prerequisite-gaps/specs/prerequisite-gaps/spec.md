## ADDED Requirements

### Requirement: Gate command validates each prerequisite's surface_kind
`overmind gate prerequisite-gaps <feature-path>` SHALL verify that every `#### Prerequisite:` block in `prerequisite_gaps.md` has a non-empty `surface_kind` whose value is one of `required_missing_user_reachable_surface`, `present_user_reachable_surface`, or `transport_or_internal_execution_gap`. A `transport_or_internal_execution_gap` value SHALL be rejected as an emitted prerequisite entry. A missing, unfilled, or otherwise invalid `surface_kind`, or a `transport_or_internal_execution_gap` entry, SHALL cause exit `1` naming the prerequisite and requirement.

#### Scenario: Valid surface_kind
- **WHEN** a prerequisite has `surface_kind: present_user_reachable_surface`
- **THEN** no surface_kind error is emitted for that prerequisite

#### Scenario: Missing surface_kind
- **WHEN** a prerequisite has `surface_kind: [UNFILLED]`
- **THEN** the gate exits `1` indicating the prerequisite is missing `surface_kind`

#### Scenario: transport_or_internal_execution_gap emitted as an entry
- **WHEN** a prerequisite has `surface_kind: transport_or_internal_execution_gap`
- **THEN** the gate exits `1` indicating transport/internal gaps must stay out of prerequisite entries

### Requirement: Gate command validates each prerequisite's status
The gate SHALL verify that every prerequisite has a non-empty `status` whose value is `present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`, or `unmet`. Any `unmet` prerequisite SHALL cause exit `1`. A `present_in_repo` prerequisite SHALL have non-empty `evidence`. A `scheduled_in_slices` prerequisite SHALL have non-empty `evidence` and a non-empty, non-`none` `slice_ref`. A `scheduled_in_feature <feature-folder>/<step-id>` prerequisite SHALL have non-empty `evidence` and SHALL use `slice_ref: none`. A missing, unfilled, or invalid `status`, or an unmet entry, or a status-specific evidence/slice_ref violation, SHALL cause exit `1` naming the prerequisite and requirement.

#### Scenario: Unmet prerequisite fails
- **WHEN** a prerequisite has `status: unmet`
- **THEN** the gate exits `1` indicating the requirement has an unmet prerequisite that must be resolved by adding a slice to `implementation_slices.md`

#### Scenario: present_in_repo missing evidence
- **WHEN** a prerequisite has `status: present_in_repo` and an unfilled `evidence`
- **THEN** the gate exits `1` naming the prerequisite as missing evidence

#### Scenario: scheduled_in_slices missing slice_ref
- **WHEN** a prerequisite has `status: scheduled_in_slices` and `slice_ref: none`
- **THEN** the gate exits `1` indicating the prerequisite is missing `slice_ref`

#### Scenario: scheduled_in_feature must use slice_ref none
- **WHEN** a prerequisite has `status: scheduled_in_feature feature-x/8.3` and a non-`none` `slice_ref`
- **THEN** the gate exits `1` indicating the prerequisite must use `slice_ref: none`

#### Scenario: Invalid status value
- **WHEN** a prerequisite has `status: done`
- **THEN** the gate exits `1` naming the invalid status

### Requirement: Gate command validates surface_identity against surface_kind and status
For `surface_kind: required_missing_user_reachable_surface`, the gate SHALL require `status` ∈ {`unmet`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`} and a filled, non-`none` `surface_identity` that reads as an operator-facing surface (route/page/screen/shell/login/workspace/portal/console/view/lookup/dashboard/form/command/cli/job/endpoint/tool/http-verb/deep-link semantics). For `surface_kind: present_user_reachable_surface`, the gate SHALL require `status: present_in_repo` and `surface_identity: none`. A violation of either rule SHALL cause exit `1` naming the prerequisite.

#### Scenario: Required missing surface has operator-facing identity
- **WHEN** a prerequisite has `surface_kind: required_missing_user_reachable_surface`, `status: scheduled_in_slices`, and `surface_identity: Operator login page`
- **THEN** no surface_identity error is emitted for that prerequisite

#### Scenario: Required missing surface with non-operator-facing identity
- **WHEN** a prerequisite has `surface_kind: required_missing_user_reachable_surface` and `surface_identity: token refresh middleware`
- **THEN** the gate exits `1` indicating a non-operator-facing surface_identity

#### Scenario: Required missing surface with wrong status
- **WHEN** a prerequisite has `surface_kind: required_missing_user_reachable_surface` and `status: present_in_repo`
- **THEN** the gate exits `1` indicating the status must be unmet/scheduled_in_slices/scheduled_in_feature

#### Scenario: Present surface must use surface_identity none
- **WHEN** a prerequisite has `surface_kind: present_user_reachable_surface` and a non-`none` `surface_identity`
- **THEN** the gate exits `1` indicating the prerequisite must use `surface_identity: none`

### Requirement: Gate command cross-checks EARS literals against prerequisites and surfaces
When `requirements_ears.md` and `technical_requirements.md` are present, the gate SHALL extract each externally-invocable literal from `requirements_ears.md` (HTTP-verb paths such as `POST /api/v1/orders`, backtick-wrapped `/paths`, and bare `/path` tokens longer than two characters) and SHALL verify each literal appears in some prerequisite entry (`evidence` or `slice_ref`) in `prerequisite_gaps.md` or in a `user_reachable_surface` value in `technical_requirements.md`. A literal absent from both SHALL cause exit `1` naming the literal.

#### Scenario: Literal covered by a prerequisite entry
- **WHEN** the literal `/api/v1/orders` from `requirements_ears.md` appears in a prerequisite's evidence
- **THEN** no cross-check error is emitted for that literal

#### Scenario: Literal covered only by a user_reachable_surface
- **WHEN** the literal `/checkout/summary` is absent from all prerequisite entries but appears in a `user_reachable_surface` in `technical_requirements.md`
- **THEN** no cross-check error is emitted for that literal

#### Scenario: Literal uncovered
- **WHEN** a literal from `requirements_ears.md` appears in neither the prerequisite entries nor any `user_reachable_surface`
- **THEN** the gate exits `1` naming the uncovered literal

### Requirement: Gate command validates slice_ref format for scheduled_in_slices
For each prerequisite with `status: scheduled_in_slices` and a filled `slice_ref`, the gate SHALL verify the `slice_ref` matches `[A-Za-z0-9][A-Za-z0-9_.-]*`. A malformed `slice_ref` SHALL cause exit `1` naming the prerequisite and the value. The format check SHALL NOT be applied to prerequisites whose status is not `scheduled_in_slices`.

#### Scenario: Valid slice_ref format
- **WHEN** a `scheduled_in_slices` prerequisite has `slice_ref: slice-1`
- **THEN** no slice_ref-format error is emitted for that prerequisite

#### Scenario: Malformed slice_ref
- **WHEN** a `scheduled_in_slices` prerequisite has `slice_ref: slice 1!`
- **THEN** the gate exits `1` indicating the `slice_ref` does not match the required format

### Requirement: Gate command fails on missing runtime inputs
`overmind gate prerequisite-gaps <feature-path>` SHALL exit `2` with an actionable error when the target artifact path argument is missing, when the target `prerequisite_gaps.md` is absent, or when a required sibling — `requirements_ears.md` or `technical_requirements.md` (feature directory) — is absent. An empty or whitespace-only target artifact is a content failure and SHALL exit `1`, not `2`. (The legacy helper's `[[ ! -s ]]` check rejected only zero-byte files; this gate strengthens it to reject whitespace-only content as well, consistent with the implementation-slices gate.)

#### Scenario: Missing target path argument
- **WHEN** the gate is invoked without a target artifact path
- **THEN** it exits `2` with a usage error

#### Scenario: Absent target artifact
- **WHEN** `prerequisite_gaps.md` does not exist in the feature directory
- **THEN** the gate exits `2` naming the missing target artifact

#### Scenario: Empty target artifact
- **WHEN** `prerequisite_gaps.md` exists but is zero-byte or contains only whitespace
- **THEN** the gate exits `1` indicating the artifact is empty

#### Scenario: Missing required sibling artifact
- **WHEN** `technical_requirements.md` is absent from the feature directory
- **THEN** the gate exits `2` naming the missing sibling artifact

### Requirement: Context command emits full prerequisite-gap context block
`overmind context prerequisite-gaps <feature-path>` SHALL resolve the feature path inside `projects/<project-id>/<feature-folder>`, read active project classes from `init_progress_definition.yaml`, accept only `backend`, `frontend`, `mobile`, and `infrastructure`, skip `infrastructure` when deriving supported repo classes, require at least one supported repo class, and fail resolution with exit `2` for any unsupported class or when no supported repo class is derivable. It SHALL discover committed sibling features that contain `implementation_plan.md` and emit one context block containing: workspace root, feature root, project root, active repo classes, target artifact path (`<feature-path>/prerequisite_gaps.md`), read-only manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, and each sibling `implementation_plan.md`), asset references (skill-relative template and golden example paths), and the exact gate command `node .overmind/overmind.js gate prerequisite-gaps <feature-path>`. Sibling `implementation_plan.md` sources SHALL be listed as read-only inputs whenever present so the model is instructed not to modify them; their absence SHALL NOT cause an error.

#### Scenario: Sibling in-flight plan is listed read-only
- **WHEN** a committed sibling feature contains `implementation_plan.md`
- **THEN** the read-only manifest includes that sibling's `implementation_plan.md` as a do-not-modify input

#### Scenario: No sibling in-flight plans present
- **WHEN** no committed sibling feature contains `implementation_plan.md`
- **THEN** the read-only manifest omits sibling plans and the context command does not fail

#### Scenario: Infrastructure class is silently skipped
- **WHEN** active classes include `infrastructure` alongside `backend`
- **THEN** the context block derives `backend` as an active repo class and emits no error for `infrastructure`

#### Scenario: Gate command in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains `node .overmind/overmind.js gate prerequisite-gaps` followed by the feature path

#### Scenario: Workspace root in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains the absolute workspace root path and the feature-relative target artifact path

### Requirement: Context command fails on missing required inputs
If `init_progress_definition.yaml` (parent project directory), `requirements_ears.md`, `technical_requirements.md`, or `implementation_slices.md` (feature directory) is absent, `overmind context prerequisite-gaps <feature-path>` SHALL exit `2` with an actionable error naming the missing file.

#### Scenario: Missing technical_requirements.md
- **WHEN** `technical_requirements.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Missing implementation_slices.md
- **WHEN** `implementation_slices.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Feature path outside workspace
- **WHEN** the feature path does not resolve under `projects/<project-id>/<feature>/` within the workspace
- **THEN** the context command exits `2` describing the path constraint

### Requirement: Sync command syncs only ready supported repos before the session
`overmind sync prerequisite-gaps <feature-path>` SHALL resolve the feature path and its project's `init_progress_definition.yaml`, collect ready repo paths **restricted to classes `backend`, `frontend`, and `mobile`**, and sync each to its default branch. It SHALL NOT sync a repo of any other class (for example `infrastructure`) even when that class is ready, and a ready unsupported-class repo SHALL NOT cause an error — including one whose configured path does not exist — matching the legacy filter that was applied before the ready/path-existence checks. It SHALL exit `0` when all synced repos complete cleanly, and exit `2` with actionable messages when a supported repo cannot be synced (wrong branch or dirty tree) or when the project definition is missing. The model-invoked `context` and `gate` commands SHALL NOT perform repo writes.

#### Scenario: Ready supported repos synced
- **WHEN** the project has ready backend and frontend repos on their default branches with clean trees
- **THEN** `overmind sync prerequisite-gaps` syncs both and exits `0`

#### Scenario: Ready infrastructure repo is not synced
- **WHEN** the project has a ready `infrastructure` repo alongside a ready backend repo
- **THEN** `overmind sync prerequisite-gaps` syncs only the backend repo, does not sync or error on the `infrastructure` repo, and exits `0`

#### Scenario: Blocked repo precondition
- **WHEN** a ready supported repo is on the wrong branch or has a dirty tree
- **THEN** `overmind sync prerequisite-gaps` exits `2` with a message naming the blocked repo

#### Scenario: Missing project definition
- **WHEN** `init_progress_definition.yaml` is absent from the parent project directory
- **THEN** `overmind sync prerequisite-gaps` exits `2` naming the missing project definition

### Requirement: Skill SKILL.md instructs model to run gate after every write
The `overmind-prerequisite-gaps` SKILL.md SHALL instruct the model to: (1) run `overmind context prerequisite-gaps <feature-path>` to obtain runtime bindings; (2) draft `prerequisite_gaps.md` using the bound template and golden example; (3) write only `prerequisite_gaps.md` and no other files; (4) run `overmind gate prerequisite-gaps <feature-path>` after every write or repair; (5) on gate exit `1`, read the output, repair the artifact, and rerun the gate; (6) on gate exit `2`, stop and report the blocker to the operator; (7) on gate exit `0`, end with the prompt-provided success line. It SHALL preserve the derivation constraints from the rule: derive externally-invocable prerequisites per EARS requirement using the class taxonomy (frontend routes/pages/screens, backend endpoints/CLI/jobs/admin tools, mobile screens/deep links), use `user_reachable_surface` in `technical_requirements.md` as ground truth for `present_in_repo`, use `implementation_slices.md` for `scheduled_in_slices`, use sibling plans for `scheduled_in_feature <feature-folder>/<step-id>`, keep transport/internal gaps out of prerequisite entries, and resolve every `unmet` prerequisite before the gate can pass.

#### Scenario: Gate loop on exit 1
- **WHEN** the gate exits `1` after the first write
- **THEN** SKILL.md instructs the model to repair the artifact and rerun the gate, not to stop

#### Scenario: Success line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal success line `Prerequisite gap trace phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`

#### Scenario: Infeasibility line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal infeasibility line `prerequisite gap trace gate cannot pass with current requirements/technical-requirements/slices inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`
