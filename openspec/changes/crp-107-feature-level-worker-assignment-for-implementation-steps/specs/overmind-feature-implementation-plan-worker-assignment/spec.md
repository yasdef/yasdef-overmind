## ADDED Requirements

### Requirement: Feature assignment command is restricted to feature-level path scope
`feature_assing_workers.sh` SHALL require `--feature_path <asdlc/projects/<project-id>/<feature-folder>>` and SHALL fail fast when the provided path does not resolve to a valid ASDLC feature directory.

#### Scenario: Missing feature_path argument is rejected
- **WHEN** `feature_assing_workers.sh` runs without `--feature_path`
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an error describing the required feature-level `--feature_path` argument

#### Scenario: Non-feature path is rejected
- **WHEN** `feature_assing_workers.sh --feature_path <path>` runs and `<path>` is not a valid ASDLC feature directory
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print an error explaining that a feature folder path is required

### Requirement: Assignment runs only when implementation plan is ready
The command SHALL run only when `<feature-path>/implementation_plan.md` exists and contains parseable implementation steps with `### Step ...` and `#### Repo:` ownership metadata.

#### Scenario: Missing implementation plan blocks assignment
- **WHEN** `feature_assing_workers.sh --feature_path <feature-path>` runs and `<feature-path>/implementation_plan.md` does not exist
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print a meaningful readiness error explaining that implementation plan generation must be completed first

#### Scenario: Malformed implementation plan blocks assignment
- **WHEN** assignment runs and `implementation_plan.md` exists but does not contain parseable step ownership structure
- **THEN** the script SHALL exit non-zero
- **AND** SHALL print a meaningful readiness error explaining the expected step format

### Requirement: Worker eligibility is resolved strictly by class
For each repo class referenced by `#### Repo:` in the plan, eligible workers SHALL be resolved only from `<project-path>/workers.yaml` entries with exact matching `class` and `status: active`.

#### Scenario: Non-matching classes are excluded
- **WHEN** a plan step uses `#### Repo: backend` and workers exist in other classes only
- **THEN** those workers SHALL NOT be considered eligible for backend assignment

#### Scenario: Non-active workers are excluded
- **WHEN** workers of the matching class exist with statuses other than `active`
- **THEN** those workers SHALL NOT be considered eligible for assignment

### Requirement: Multi-worker class assignment requires exactly one operator selection
If more than one eligible worker exists for a plan class, the command SHALL prompt the operator to choose exactly one worker UUID for that class before assignment proceeds.

#### Scenario: Single eligible worker is auto-selected
- **WHEN** exactly one eligible active worker exists for a class present in the plan
- **THEN** the script SHALL assign that worker UUID to all steps owned by that class without interactive choice

#### Scenario: Multiple eligible workers trigger class-level selection
- **WHEN** more than one eligible active worker exists for a class present in the plan
- **THEN** the script SHALL present only those worker UUID options
- **AND** SHALL require exactly one selection before continuing

#### Scenario: Invalid class selection is retried
- **WHEN** the operator enters an unsupported, empty, or ambiguous selection during class worker choice
- **THEN** the script SHALL print selection guidance
- **AND** SHALL continue prompting until exactly one valid worker UUID is selected

### Requirement: Assignment result writes deterministic Assigned values for all plan steps
After one run, every implementation step in `implementation_plan.md` SHALL contain `#### Assigned:` with either the selected class worker UUID or a deterministic class-scoped error message when no eligible worker exists.

#### Scenario: All classes staffed writes UUID assignments
- **WHEN** each class referenced by plan steps has at least one eligible active worker and required selections are completed
- **THEN** every step SHALL include `#### Assigned: <worker-uuid>` matching its repo class assignment decision

#### Scenario: Unstaffed class writes assignment error message
- **WHEN** a class referenced by plan steps has zero eligible active workers
- **THEN** each step for that class SHALL include `#### Assigned: ERROR: no active worker available for class <class>`
- **AND** the command SHALL print a meaningful class-scoped error message in output

#### Scenario: Existing assignment lines are normalized in-place
- **WHEN** `implementation_plan.md` already contains `#### Assigned:` lines from earlier runs
- **THEN** the command SHALL update them in place to the current deterministic result
- **AND** SHALL preserve step order, headings, dependencies, evidence lines, and checklist bullet content

### Requirement: Regression coverage validates feature-level worker assignment behavior
Shell test coverage under `tests/ai_scripts/` SHALL validate readiness gates, strict class matching, multi-worker selection flow, no-worker error propagation, and final `#### Assigned:` output completeness.

#### Scenario: Feature worker-assignment tests pass
- **WHEN** the feature-level worker-assignment shell test suite is run from repository root
- **THEN** it SHALL pass and confirm path validation, readiness gating, class-strict matching, selection behavior, and deterministic per-step assignment output
