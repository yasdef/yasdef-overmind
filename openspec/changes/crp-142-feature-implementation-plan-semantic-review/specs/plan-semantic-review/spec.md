## ADDED Requirements

### Requirement: Gate command validates review-ledger structure

`overmind gate plan-semantic-review <feature-path>` SHALL derive the target `implementation_plan_semantic_review.md` from the feature directory and verify that it contains the required sections `## 1. Document Meta`, `## 2. Review Guidance`, and `## 3. Findings Ledger`; that all eight meta keys — `feature_id`, `feature_title`, `source_implementation_plan`, `source_project_definition`, `source_requirements_ears`, `source_technical_requirements`, `review_status`, `last_updated` — are present and filled (not `[UNFILLED]` and not a placeholder token); that `review_status` is `in_progress` or `complete`; and that the artifact contains no `[UNFILLED]` placeholder anywhere. A missing section, a missing/unfilled meta key, an invalid `review_status`, or an `[UNFILLED]` placeholder SHALL cause exit `1` naming the defect.

#### Scenario: Valid review ledger passes
- **WHEN** the review artifact has all three sections, all eight filled meta keys, `review_status: complete`, and `- no_findings: true` with no Finding blocks
- **THEN** the gate exits `0`

#### Scenario: Missing required section
- **WHEN** the review artifact omits `## 3. Findings Ledger`
- **THEN** the gate exits `1` naming the missing section

#### Scenario: Unfilled meta key
- **WHEN** `last_updated` is still `[UNFILLED]`
- **THEN** the gate exits `1` naming the missing or unfilled meta key

#### Scenario: Invalid review_status
- **WHEN** `review_status` is `draft`
- **THEN** the gate exits `1` indicating `review_status` must be `in_progress` or `complete`

#### Scenario: Unfilled placeholder present
- **WHEN** the artifact still contains an `[UNFILLED]` placeholder anywhere
- **THEN** the gate exits `1` indicating the artifact still contains placeholders

### Requirement: Gate command validates findings-ledger consistency

The gate SHALL enforce consistency between the presence of `### Finding N` blocks and the `- no_findings:` declaration: when no Finding blocks exist, the ledger SHALL declare `- no_findings: true` and `review_status` SHALL be `complete`; when at least one Finding block exists, `no_findings` SHALL NOT be `true`. A violation SHALL cause exit `1`.

#### Scenario: No findings without the no_findings declaration
- **WHEN** the ledger has no Finding blocks and does not declare `- no_findings: true`
- **THEN** the gate exits `1` indicating the ledger must declare `no_findings: true` when no Finding blocks exist

#### Scenario: No findings but review not complete
- **WHEN** the ledger declares `- no_findings: true` but `review_status` is `in_progress`
- **THEN** the gate exits `1` indicating `review_status` must be `complete` when `no_findings` is true

#### Scenario: no_findings true while Finding blocks present
- **WHEN** at least one `### Finding N` block exists and the ledger declares `- no_findings: true`
- **THEN** the gate exits `1` indicating `no_findings` must not be true when Finding blocks are present

### Requirement: Gate command validates each finding block

For each `### Finding N` block the gate SHALL require all twelve fields — `severity`, `finding_type`, `state`, `target_steps`, `related_requirements`, `related_evidence`, `summary`, `rationale`, `recommendation`, `user_selection`, `plan_patch_summary`, `resolution_notes` — present and filled; `severity ∈ {High, Medium, Low}`; `finding_type ∈ {step_scope_overlap, technical_gap_mix, dependency_ordering, requirement_grouping, delivered_surface_consumption_unclear, repo_scaffold_readiness_unclear}`; and `state ∈ {added, applied, rejected, postponed}`. A `delivered_surface_consumption_unclear` or `repo_scaffold_readiness_unclear` finding in a terminal state (`applied`/`rejected`/`postponed`) SHALL have non-empty `resolution_notes`. A `delivered_surface_consumption_unclear` finding SHALL reference at least one `REQ-*` or `NFR-*` id in `related_requirements`. Any violation SHALL cause exit `1` naming the finding block and defect.

#### Scenario: Finding missing a required field
- **WHEN** a finding block omits or leaves unfilled its `rationale`
- **THEN** the gate exits `1` naming the finding block and the missing field

#### Scenario: Invalid severity
- **WHEN** a finding has `severity: Critical`
- **THEN** the gate exits `1` naming the finding block and its invalid severity

#### Scenario: Invalid finding_type
- **WHEN** a finding has `finding_type: style_nit`
- **THEN** the gate exits `1` naming the finding block and its invalid finding_type

#### Scenario: Invalid state
- **WHEN** a finding has `state: deferred`
- **THEN** the gate exits `1` naming the finding block and its invalid state

#### Scenario: Terminal product-fit finding without resolution notes
- **WHEN** a `delivered_surface_consumption_unclear` finding has `state: applied` and empty `resolution_notes`
- **THEN** the gate exits `1` indicating the terminal finding requires non-empty resolution notes

#### Scenario: delivered_surface_consumption_unclear without a requirement reference
- **WHEN** a `delivered_surface_consumption_unclear` finding's `related_requirements` contains no `REQ-*` or `NFR-*` id
- **THEN** the gate exits `1` indicating it must reference at least one requirement id

### Requirement: Gate command enforces completion consistency

When `review_status` is `complete` and at least one Finding block exists, every finding SHALL be in a terminal state (`applied`/`rejected`/`postponed`); a non-terminal (`added`) finding under a `complete` review SHALL cause exit `1`.

#### Scenario: Complete review with a non-terminal finding
- **WHEN** `review_status: complete` and one finding is still `state: added`
- **THEN** the gate exits `1` indicating the review is complete but non-terminal findings remain

### Requirement: Gate command fails on missing or empty runtime inputs

`overmind gate plan-semantic-review <feature-path>` SHALL exit `2` with an actionable error when the feature-path argument is missing or when the target `implementation_plan_semantic_review.md` is absent from the feature directory. An empty or whitespace-only target artifact SHALL exit `1` (content failure), not `2`.

#### Scenario: Missing feature path argument
- **WHEN** the gate is invoked without a feature-path argument
- **THEN** it exits `2` with a usage error

#### Scenario: Absent target artifact
- **WHEN** `implementation_plan_semantic_review.md` does not exist in the feature directory
- **THEN** the gate exits `2` naming the missing target artifact

#### Scenario: Empty target artifact
- **WHEN** `implementation_plan_semantic_review.md` exists but is zero-byte or contains only whitespace
- **THEN** the gate exits `1` indicating the artifact is empty

### Requirement: Context command emits full plan-semantic-review context block

`overmind context plan-semantic-review <feature-path>` SHALL resolve the feature path inside `projects/<project-id>/<feature-folder>`, read active project classes from `init_progress_definition.yaml`, accept only `backend`, `frontend`, `mobile`, and `infrastructure`, and skip `infrastructure` when deriving supported repo classes. It SHALL NOT require at least one supported repo class (legacy 8.4 parity): when no supported repo class is derivable it emits active repo classes as `none` with an empty applicable-surface-map manifest. It SHALL fail resolution with exit `2` only for an unrecognized project class. It SHALL emit one context block containing: workspace root, feature root, project root, active repo classes, the two mutable target artifact paths (`<feature-path>/implementation_plan.md` and `<feature-path>/implementation_plan_semantic_review.md`), the read-only manifest emitted as stable one-per-line `- read_only_input: <path>` entries (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, and the applicable surface map for each active repo class) so the e2e launcher snapshots exactly this manifest, asset references (skill-relative template and golden example paths), and both gate commands — `node .overmind/overmind.js gate plan-semantic-review <feature-path>` (the review-ledger gate, run after every write or repair of the review ledger) and `node .overmind/overmind.js gate implementation-plan <feature-path>` (the plan gate, run after every write or repair of the plan).

#### Scenario: Two mutable targets in context output
- **WHEN** the context command runs for a valid feature
- **THEN** the emitted text lists both `implementation_plan.md` and `implementation_plan_semantic_review.md` as mutable targets

#### Scenario: Read-only manifest lists inputs and applicable surface maps
- **WHEN** the context command runs for a feature with active classes `backend` and `frontend`
- **THEN** the read-only manifest emits `- read_only_input:` lines for `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, `project_surface_struct_resp_map_backend.md`, and `project_surface_struct_resp_map_frontend.md`

#### Scenario: Both gate commands in context output
- **WHEN** the context command runs
- **THEN** the emitted text contains `node .overmind/overmind.js gate plan-semantic-review` and `node .overmind/overmind.js gate implementation-plan`, each followed by the feature path

#### Scenario: Infrastructure class is silently skipped
- **WHEN** active classes include `infrastructure` alongside `backend`
- **THEN** the context block derives `backend` as an active repo class and emits no error for `infrastructure`

#### Scenario: Unsupported project class fails resolution
- **WHEN** active classes include an unrecognized class such as `desktop`
- **THEN** the context command exits `2` naming the unsupported class

#### Scenario: Zero supported repo classes is allowed
- **WHEN** the only active project class is `infrastructure` (no `backend`/`frontend`/`mobile`)
- **THEN** the context command exits `0`, emits active repo classes as `none`, and lists no applicable surface maps in the read-only manifest

### Requirement: Context command fails on missing required inputs

If `init_progress_definition.yaml` (parent project directory), `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, or `implementation_plan.md` (feature directory) is absent, or if the applicable surface map for an active repo class is absent, `overmind context plan-semantic-review <feature-path>` SHALL exit `2` with an actionable error naming the missing file or the active class whose surface map is missing.

#### Scenario: Missing prerequisite_gaps.md
- **WHEN** `prerequisite_gaps.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Missing implementation_plan.md
- **WHEN** `implementation_plan.md` does not exist in the feature directory
- **THEN** the context command exits `2` naming the missing file

#### Scenario: Missing surface map for an active repo class
- **WHEN** `backend` is an active repo class but `project_surface_struct_resp_map_backend.md` is absent
- **THEN** the context command exits `2` naming the active class whose surface map is missing

#### Scenario: Feature path outside workspace
- **WHEN** the feature path does not resolve under `projects/<project-id>/<feature>/` within the workspace
- **THEN** the context command exits `2` describing the path constraint

### Requirement: Skill SKILL.md instructs model to run gates and preserve read-only inputs

The `overmind-plan-semantic-review` SKILL.md SHALL instruct the model to: (1) run `overmind context plan-semantic-review <feature-path>` to obtain runtime bindings; (2) create or update `implementation_plan_semantic_review.md` with numbered findings using the bound template and golden example, or declare `no_findings: true` when none; (3) if findings exist, present a concise numbered summary and ask exactly `Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)` exactly once for the current ledger decision round, without issuing the same question again while awaiting an answer; it may ask again only when the answer is incomplete/ambiguous or gate-driven repair materially changes the findings, then update both artifacts and set each finding to a terminal state (`applied`/`rejected`/`postponed`) or keep `added` only where the operator answer is incomplete; (4) write only `implementation_plan.md` and `implementation_plan_semantic_review.md` and never modify a read-only input; (5) run `overmind gate plan-semantic-review <feature-path>` after every write or repair of `implementation_plan_semantic_review.md` — including the initial findings ledger written before pausing for operator input — and run `overmind gate implementation-plan <feature-path>` after every write or repair of `implementation_plan.md`; (6) on gate exit `1`, read the output, repair the artifact, and rerun the gate; (7) on gate exit `2`, stop and report the blocker; (8) on a clean pass, end with the literal SKILL-owned success line, or the literal SKILL-owned failure line when completion is not feasible (both final-response lines live only in `SKILL.md`, not in any orchestrator/e2e prompt). It SHALL preserve the rule constraints: the six allowed `finding_type`s, the four allowed finding `state`s, the four-step operator-reachability heuristic for `delivered_surface_consumption_unclear`, the in-flight sibling-overlap `step_scope_overlap` rule, the `repo_scaffold_readiness_unclear` rule, the minimal-plan-patch guidance, the "do not invent navigation requirements" rule, and the requirement that terminal `delivered_surface_consumption_unclear`/`repo_scaffold_readiness_unclear` findings carry non-empty `resolution_notes`.

#### Scenario: Operator question is emitted once per decision round
- **WHEN** the initial findings ledger passes its gate and the model presents the numbered finding summary
- **THEN** it asks the exact operator question once and waits for the answer, without interpreting the User Interaction Rules section as a second ask action

#### Scenario: Two-gate discipline in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it instructs the model to run `gate plan-semantic-review` after every write or repair of the review ledger — including the initial ledger written before operator input — and to run `gate implementation-plan` after every write or repair of the plan

#### Scenario: Review gate runs on the initial ledger before operator input
- **WHEN** the model writes the first `implementation_plan_semantic_review.md` (findings recorded, `review_status: in_progress`) before asking the operator which findings to apply
- **THEN** SKILL.md instructs the model to run `gate plan-semantic-review` on that initial ledger, not to defer gating until after the operator answers

#### Scenario: Success line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal success line `Implementation plan semantic review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`

#### Scenario: Infeasibility line in SKILL.md
- **WHEN** the SKILL.md is read
- **THEN** it contains the literal infeasibility line `implementation plan semantic review cannot be completed with current plan/requirements/technical inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`

#### Scenario: Gate loop on exit 1
- **WHEN** a gate exits `1` after a write
- **THEN** SKILL.md instructs the model to repair the artifact and rerun the gate, not to stop
