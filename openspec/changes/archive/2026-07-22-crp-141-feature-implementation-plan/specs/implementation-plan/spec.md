## ADDED Requirements

### Requirement: Gate command validates step block structure

`overmind gate implementation-plan <feature-path>` SHALL verify that every `### Step <major>.<minor> <title>` block in `implementation_plan.md` has: strictly-increasing unique `<major>.<minor>` step ids; at least one valid `[REQ-*]`/`[NFR-*]` heading reference drawn from `requirements_ears.md`; exactly one `#### Repo:` whose value is in the active project classes and ∈ {`backend`, `frontend`, `mobile`}; exactly one `#### Depends on:`; exactly one `#### Evidence:`; exactly one `#### Preserved Surface:`; at least three checklist bullets whose first bullet is `Plan and discuss the step` and which include a `Review step implementation` bullet. A duplicated field, an out-of-order or duplicate step id, a missing/unknown heading requirement id, a repo outside the active classes or not in {backend,frontend,mobile}, a missing required field, or a bullet-count/plan-bullet/review-bullet violation SHALL cause exit `1` naming the step and requirement. The duplicate-`#### Evidence:` rejection is a documented strengthening: legacy tolerated an empty `#### Evidence:` line followed by a filled one (its duplicate check keyed on a non-empty prior value); this gate rejects any second non-empty `#### Evidence:` declaration uniformly, while a single empty `#### Evidence:` value still fails as missing evidence exactly as before.

#### Scenario: Valid step block
- **WHEN** a step has a valid `[REQ-*]` heading ref, a single `#### Repo: backend` in the active classes, `#### Depends on:`, `#### Evidence:`, `#### Preserved Surface:`, and three bullets starting with `Plan and discuss the step` and ending with `Review step implementation`
- **THEN** no structural error is emitted for that step

#### Scenario: Step id out of order
- **WHEN** a step id `1.2` is followed by `1.1`
- **THEN** the gate exits `1` indicating step ids must be strictly increasing

#### Scenario: Missing repo owner
- **WHEN** a step has no `#### Repo:` line
- **THEN** the gate exits `1` naming the step as missing `#### Repo`

#### Scenario: Repo outside active classes
- **WHEN** a step declares `#### Repo: mobile` but `mobile` is not an active project class
- **THEN** the gate exits `1` indicating the repo is outside the active project classes

#### Scenario: Heading references unknown requirement id
- **WHEN** a step heading references `[REQ-99]` that does not exist in `requirements_ears.md`
- **THEN** the gate exits `1` naming the unknown requirement id

#### Scenario: Too few checklist bullets
- **WHEN** a step has only two checklist bullets
- **THEN** the gate exits `1` indicating the step must contain at least three checklist bullets

#### Scenario: Duplicate non-empty Evidence declaration
- **WHEN** a step declares `#### Evidence: gap/TECH_REQ-6` and then a second `#### Evidence: comp/backend-x`
- **THEN** the gate exits `1` indicating the step declares `#### Evidence` more than once

#### Scenario: Requirement ids are harvested only from headings
- **WHEN** `requirements_ears.md` mentions `REQ-9` only in a requirement's body text (not on any `###` heading line)
- **THEN** `REQ-9` is not treated as a valid or required requirement id, so a plan step heading is neither required to cover it nor permitted to reference it as known

### Requirement: Gate command validates dependency edges

For each `#### Depends on:` value other than `none`, the gate SHALL validate every comma-separated entry: a same-feature entry (no `/`) SHALL reference an earlier known step id in the plan; a cross-feature entry (containing `/`) SHALL match `<feature-folder>/<step-id>` where the step-id is a dotted numeric id and the folder is not `.`/`..`; empty entries and duplicate dependency edges on the same step SHALL be rejected. A violation SHALL cause exit `1` naming the step and dependency.

#### Scenario: Same-feature dependency on earlier step
- **WHEN** step `1.2` has `#### Depends on: 1.1` and `1.1` appears earlier
- **THEN** no dependency error is emitted

#### Scenario: Dependency on unknown or later step
- **WHEN** step `1.2` has `#### Depends on: 1.9` and `1.9` is not an earlier known step
- **THEN** the gate exits `1` indicating the step depends on an unknown or later step

#### Scenario: Valid cross-feature dependency
- **WHEN** a step has `#### Depends on: 0003_customer_accounts/3.2`
- **THEN** no dependency error is emitted for that entry

#### Scenario: Invalid cross-feature dependency
- **WHEN** a step has `#### Depends on: bad/x.y`
- **THEN** the gate exits `1` naming the invalid cross-feature dependency

### Requirement: Gate command validates evidence tokens

The gate SHALL validate every comma-separated token in each `#### Evidence:` line. A `gap/TECH_REQ-<n>` or `gap/TECH_REQ-NFR-<n>` token SHALL exist in the requirement-evidence catalog derived from `technical_requirements.md`; a `comp/<slug>` token SHALL exist in the component-evidence catalog; a `slice/<ref>` token (matching `slice/[A-Za-z0-9][A-Za-z0-9_.-]*`) is accepted without catalog lookup. Empty tokens, duplicate tokens on the same step, tokens with an invalid format, and unknown `gap/`/`comp/` tokens SHALL cause exit `1`. A step whose evidence has no valid technical evidence token SHALL cause exit `1`.

#### Scenario: Valid requirement evidence token
- **WHEN** a step has `#### Evidence: gap/TECH_REQ-6` and `gap/TECH_REQ-6` exists in the catalog
- **THEN** no evidence error is emitted for that token

#### Scenario: Unknown component evidence token
- **WHEN** a step has `#### Evidence: comp/nonexistent-component` not in the catalog
- **THEN** the gate exits `1` naming the unknown evidence token

#### Scenario: Invalid evidence token format
- **WHEN** a step has `#### Evidence: TECH_REQ_6`
- **THEN** the gate exits `1` naming the invalid evidence token format

#### Scenario: Slice evidence token accepted
- **WHEN** a step has `#### Evidence: slice/slice-1`
- **THEN** no evidence-format error is emitted for that token

### Requirement: Gate command validates preserved surfaces

For each `#### Preserved Surface:` value other than `none`, the gate SHALL require the value to read as an operator-facing surface (login/shell/route/lookup/page/workspace/form/command/job/endpoint/tool/link canonical semantics) and SHALL reject a step whose heading+bullets describe supporting-only work (auth/token/api/contract/schema/state/coordination/middleware/service/repository/adapter/dto/mapper/payload with no surface term). A `#### Coordination: true` marker MAY appear on a step; a coordination step SHALL NOT be the only coverage for a required missing operator-facing surface. A non-operator-facing preserved surface or a supporting-only step marking a preserved surface SHALL cause exit `1`.

#### Scenario: Operator-facing preserved surface
- **WHEN** a step has `#### Preserved Surface: Operator order lookup screen` and its bullets describe screen/state work
- **THEN** no preserved-surface error is emitted

#### Scenario: Non-operator-facing preserved surface
- **WHEN** a step has `#### Preserved Surface: token refresh middleware`
- **THEN** the gate exits `1` indicating a non-operator-facing preserved surface value

#### Scenario: Supporting-only work marks a preserved surface
- **WHEN** a step marks a preserved surface but its heading and bullets describe only auth/contract/service work
- **THEN** the gate exits `1` indicating the step marks a preserved surface but describes supporting-only work

### Requirement: Gate command enforces whole-plan coverage

At end of parse, the gate SHALL verify: the artifact contains no `[UNFILLED]` placeholder; at least one step exists; every repo with unresolved impacted components in `technical_requirements.md` has at least one plan step; every valid `REQ-*`/`NFR-*` id from `requirements_ears.md` is covered by at least one step heading; every unresolved requirement-evidence token and every unresolved component-evidence token from `technical_requirements.md` is covered by at least one step `#### Evidence:` token; every `scheduled_in_slices` `slice_ref` from `prerequisite_gaps.md` is covered by a `slice/<ref>` evidence token; and every required missing operator-facing surface from `prerequisite_gaps.md` is preserved by at least one non-coordination plan step (matched by canonical surface). Scheduled `slice_ref` extraction SHALL evaluate the complete `#### Prerequisite:` block, so the coverage obligation is independent of whether `slice_ref` appears before or after `status`. Any uncovered item SHALL cause exit `1` naming it.

#### Scenario: Unresolved evidence token uncovered
- **WHEN** an unresolved `gap/TECH_REQ-4` token from `technical_requirements.md` appears in no step evidence
- **THEN** the gate exits `1` indicating the unresolved requirement evidence token is not covered

#### Scenario: Requirement id uncovered
- **WHEN** `REQ-7` from `requirements_ears.md` appears in no step heading
- **THEN** the gate exits `1` indicating the requirement id is not covered by any step heading

#### Scenario: Required repo has no step
- **WHEN** `frontend` has unresolved impacted components but no plan step is allocated to it
- **THEN** the gate exits `1` indicating the repo has impacted components but no allocated step

#### Scenario: Scheduled slice_ref uncovered
- **WHEN** a `scheduled_in_slices` prerequisite has `slice_ref: slice-2` and no step has `#### Evidence: slice/slice-2`
- **THEN** the gate exits `1` naming the uncovered scheduled slice_ref

#### Scenario: Scheduled slice_ref precedes status
- **WHEN** a prerequisite block lists a filled `slice_ref` before `status: scheduled_in_slices`
- **THEN** the gate treats the slice ref as scheduled and requires its `slice/<ref>` evidence token

#### Scenario: Required surface preserved only by a coordination step
- **WHEN** a required missing operator-facing surface is preserved only by a step marked `#### Coordination: true`
- **THEN** the gate exits `1` indicating the surface has no non-coordination plan step coverage

#### Scenario: Required surface not preserved at all
- **WHEN** a required missing operator-facing surface from `prerequisite_gaps.md` matches no step's `#### Preserved Surface:`
- **THEN** the gate exits `1` indicating the required surface is not preserved by any step

#### Scenario: Unfilled placeholder present
- **WHEN** the plan still contains an `[UNFILLED]` placeholder
- **THEN** the gate exits `1` indicating the artifact still contains placeholders

### Requirement: Gate command fails on missing runtime inputs

`overmind gate implementation-plan <feature-path>` SHALL exit `2` with an actionable error when the target artifact path argument is missing, when the target `implementation_plan.md` is absent, or when a required sibling — `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md` (feature directory), or `init_progress_definition.yaml` (parent project directory) — is absent. An empty or whitespace-only target artifact is a content failure and SHALL exit `1`, not `2`. (The legacy helper's `[[ ! -s ]]` check rejected only zero-byte files; this gate strengthens it to reject whitespace-only content as well, consistent with the implementation-slices and prerequisite-gaps gates.)

#### Scenario: Missing target path argument
- **WHEN** the gate is invoked without a target artifact path
- **THEN** it exits `2` with a usage error

#### Scenario: Absent target artifact
- **WHEN** `implementation_plan.md` does not exist in the feature directory
- **THEN** the gate exits `2` naming the missing target artifact

#### Scenario: Empty target artifact
- **WHEN** `implementation_plan.md` exists but is zero-byte or contains only whitespace
- **THEN** the gate exits `1` indicating the artifact is empty

#### Scenario: Missing required sibling artifact
- **WHEN** `prerequisite_gaps.md` is absent from the feature directory
- **THEN** the gate exits `2` naming the missing sibling artifact

### Requirement: Context command emits full implementation-plan context block

`overmind context implementation-plan <feature-path>` SHALL resolve the feature path inside `projects/<project-id>/<feature-folder>`, read active project classes from `init_progress_definition.yaml`, accept only `backend`, `frontend`, `mobile`, and `infrastructure`, skip `infrastructure` when deriving supported repo classes, require at least one supported repo class, and fail resolution with exit `2` for any unsupported class or when no supported repo class is derivable. It SHALL emit one context block containing: workspace root, feature root, project root, active repo classes, target artifact path (`<feature-path>/implementation_plan.md`), read-only manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`), asset references (skill-relative template and golden example paths), and the exact gate command `node .overmind/overmind.js gate implementation-plan <feature-path>`.

#### Scenario: Infrastructure class is silently skipped
- **WHEN** active classes include `infrastructure` alongside `backend`
- **THEN** the context block derives `backend` as an active repo class and emits no error for `infrastructure`

#### Scenario: Unsupported project class fails resolution
- **WHEN** active classes include an unrecognized class such as `desktop`
- **THEN** the context command exits `2` naming the unsupported class

#### Scenario: Read-only manifest lists all six inputs
- **WHEN** the context command runs for a valid feature
- **THEN** the read-only manifest lists `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, and `prerequisite_gaps.md`

#### Scenario: Gate command in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains `node .overmind/overmind.js gate implementation-plan` followed by the feature path

#### Scenario: Workspace root in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains the absolute workspace root path and the feature-relative target artifact path

### Requirement: Context command fails on missing required inputs

If `init_progress_definition.yaml` (parent project directory), `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, or `prerequisite_gaps.md` (feature directory) is absent, `overmind context implementation-plan <feature-path>` SHALL exit `2` with an actionable error naming the missing file.

#### Scenario: Missing prerequisite_gaps.md
- **WHEN** `prerequisite_gaps.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Missing implementation_slices.md
- **WHEN** `implementation_slices.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Feature path outside workspace
- **WHEN** the feature path does not resolve under `projects/<project-id>/<feature>/` within the workspace
- **THEN** the context command exits `2` describing the path constraint

### Requirement: Skill SKILL.md instructs model to run gate after every write

The `overmind-implementation-plan` SKILL.md SHALL instruct the model to: (1) run `overmind context implementation-plan <feature-path>` to obtain runtime bindings; (2) draft `implementation_plan.md` using the bound template and golden example; (3) write only `implementation_plan.md` and no other files; (4) run `overmind gate implementation-plan <feature-path>` after every write or repair; (5) on gate exit `1`, read the output, repair the artifact, and rerun the gate; (6) on gate exit `2`, stop and report the blocker to the operator; (7) on gate exit `0`, end with the prompt-provided success line. It SHALL preserve the derivation constraints from the rule: build one shared ordered cross-repo plan with exactly one `#### Repo:` owner per step, start from `implementation_slices.md` for executable decomposition, use `technical_requirements.md` as the canonical evidence/repo-ownership source, use `feature_contract_delta.md` to order shared-contract prerequisites before dependent repo-specific work, reuse `REQ-*`/`NFR-*` ids from `requirements_ears.md` (no plan-only id namespace), emit `slice/<slice_ref>` evidence for each `scheduled_in_slices` prerequisite from `prerequisite_gaps.md`, keep required missing operator-facing surfaces explicit via `#### Preserved Surface:` in a non-coordination step, omit `#### Assigned:` by default, and not modify any read-only input.

#### Scenario: Gate loop on exit 1
- **WHEN** the gate exits `1` after the first write
- **THEN** SKILL.md instructs the model to repair the artifact and rerun the gate, not to stop

#### Scenario: Success line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal success line `Repository implementation plan phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`

#### Scenario: Infeasibility line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal infeasibility line `repository implementation plan gate cannot pass with current requirements/technical-requirements/contract/slice inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`
