## ADDED Requirements

### Requirement: Scheduled prerequisite coverage check in implementation plan
`check_implementation_plan_quality.sh` SHALL fail when `prerequisite_gaps.md` exists at the feature path and any prerequisite marked `status: scheduled_in_slices` is not covered by at least one step in `implementation_plan.md`. Coverage SHALL be declared via the evidence token `slice/<slice_ref>` in a step's `#### Evidence:` line, alongside the existing `gap/TECH_REQ-*` and `comp/*` evidence-token families.

#### Scenario: Plan step declares slice coverage via slice evidence token
- **WHEN** a plan step's `#### Evidence:` line contains the token `slice/<slice-id>` where `<slice-id>` matches the regex `[A-Za-z0-9][A-Za-z0-9_.-]*`
- **THEN** `check_implementation_plan_quality.sh` SHALL treat `<slice-id>` as covered by that step

#### Scenario: Uncovered scheduled prerequisite fails the gate
- **WHEN** `prerequisite_gaps.md` contains a prerequisite with `status: scheduled_in_slices` and `slice_ref: S-3`
- **AND** no step in `implementation_plan.md` contains the token `slice/S-3` in its `#### Evidence:` line
- **THEN** `check_implementation_plan_quality.sh` SHALL exit with a non-zero status and SHALL print a quality gate failure identifying the uncovered prerequisite and its `slice_ref`

#### Scenario: All scheduled prerequisites covered passes the gate
- **WHEN** every prerequisite in `prerequisite_gaps.md` with `status: scheduled_in_slices` has its `slice_ref` declared as a `slice/<slice_ref>` evidence token in at least one implementation step
- **THEN** the prerequisite coverage portion of the gate SHALL pass and SHALL NOT produce a prerequisite-related failure

#### Scenario: slice/<id> is a recognized evidence-token format
- **WHEN** a plan step's `#### Evidence:` line contains a `slice/<id>` token
- **THEN** the evidence-token validator SHALL accept it as a valid token format and SHALL NOT report "invalid evidence token format" for that token, consistent with how `gap/TECH_REQ-*` and `comp/*` tokens are accepted

#### Scenario: Present-in-repo prerequisites are not checked
- **WHEN** a prerequisite has `status: present_in_repo`
- **THEN** `check_implementation_plan_quality.sh` SHALL NOT require an implementation step for that prerequisite, since it is already satisfied by the repo

#### Scenario: Gate skipped when prerequisite_gaps.md is absent
- **WHEN** `prerequisite_gaps.md` does not exist at the feature path
- **THEN** `check_implementation_plan_quality.sh` SHALL emit a helper failure indicating that the required sibling artifact is missing, consistent with how other missing sibling artifacts are handled

#### Scenario: Coverage check is additive to existing plan quality rules
- **WHEN** `check_implementation_plan_quality.sh` runs with a valid `prerequisite_gaps.md` present
- **THEN** all existing quality checks (evidence tokens, step ordering, repo allocation, requirement coverage) SHALL still execute and the prerequisite coverage check SHALL run as an additional check, not a replacement
