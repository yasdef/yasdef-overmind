## ADDED Requirements

### Requirement: Worker assignment is a deterministic TypeScript primitive

Assigning workers to an implementation plan SHALL be performed by a typed coordinator module (`packages/asdlc-coordinator/src/workers/assignment.ts`) invoked through `overmind worker assign --feature-path <feature>`, not by shell. The repository SHALL NOT contain `overmind/scripts/feature_assing_workers.sh`. Operator interaction SHALL be supplied through an injected port so assignment is deterministic under test.

#### Scenario: Assign workers via the CLI verb

- **WHEN** an operator runs `overmind worker assign --feature-path <projects/<project-id>/<feature-folder>>` for a ready plan with one active worker per required class
- **THEN** each `### Step` block receives a `#### Assigned:` line naming the resolved worker UUID for its `#### Repo:` class, and the feature's `implementation_plan.md` is rewritten in place

#### Scenario: Shell assigner is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/feature_assing_workers.sh` and its shell test suite do not exist, and no packaged staging references it

### Requirement: Assignment resolves one active worker per plan repo class

Assignment SHALL read the distinct repo classes declared by the plan's `#### Repo:` lines (`backend`, `frontend`, `mobile`) and, for each, select exactly one `status: active` worker of that class from the project's `workers.yaml`. A single candidate SHALL be auto-selected; multiple candidates SHALL be presented for the operator to choose exactly one by list number or UUID. The worker registry `project_id` and `workers:` shape SHALL be validated before selection.

#### Scenario: Single active worker is auto-selected

- **WHEN** exactly one active worker exists for a plan's repo class
- **THEN** that worker's UUID is chosen for the class without prompting

#### Scenario: Multiple active workers require one selection

- **WHEN** more than one active worker exists for a plan's repo class
- **THEN** the operator is prompted to choose exactly one by list number or UUID, and only that worker is assigned to the class

### Requirement: Missing workers and dependency holds are marked, not silently skipped

When no active worker exists for a required class, or a step's cross-feature dependency is not yet complete, assignment SHALL write an explicit marker into the affected `#### Assigned:` line (a missing-worker error marker, or a `hold: depends on <feature>/<step>` marker) and SHALL complete with a non-success exit while still rewriting the plan. Cross-feature dependency completion SHALL be evaluated against the sibling feature's `implementation_plan.md` (dependency step present with at least one checklist item, all checked).

#### Scenario: No active worker for a required class

- **WHEN** a plan requires a class for which no active worker exists
- **THEN** the class assignment is marked as a no-active-worker error and the command exits with a non-success status reporting the class availability issue

#### Scenario: Incomplete cross-feature dependency holds the step

- **WHEN** a step declares a `#### Depends on:` cross-feature step whose sibling plan step is not fully checked
- **THEN** that step's `#### Assigned:` line is written as `hold: depends on <feature>/<step>` and the command exits with a non-success status

### Requirement: Assignment-time plan-shape validation

Before assignment, and exposed as a reusable validator (`packages/asdlc-coordinator/src/validate/worker-assignment.ts`) distinct from the full implementation-plan quality gate, the plan SHALL be checked for assignment readiness: it MUST contain at least one `### Step` block, and every step MUST declare exactly one `#### Repo:` with a supported class (`backend`, `frontend`, `mobile`). A plan that fails this shape check SHALL be rejected before any rewrite. The repository SHALL NOT contain `overmind/scripts/common_libs/check_implementation_plan_readiness.sh`.

#### Scenario: Plan with no steps is rejected

- **WHEN** the target plan contains no `### Step` block
- **THEN** assignment fails with a not-ready error and the plan is not rewritten

#### Scenario: Step missing or duplicating repo metadata is rejected

- **WHEN** a step has no `#### Repo:` line, declares it more than once, or names an unsupported class
- **THEN** assignment fails with a not-ready error identifying the step, and the plan is not rewritten

### Requirement: Assignment returns a typed result the CLI renders without scraping

The assignment primitive SHALL return a typed result carrying its diagnostics, the resolved per-class assignments (including missing-worker and hold markers), and the set of changed paths, and the CLI SHALL render its output and exit code from that result rather than parsing printed text. When the plan is rewritten the result SHALL report `implementation_plan.md` as a changed path; when a plan-shape check fails before rewrite it SHALL report no changed paths. Missing-worker and dependency-hold conditions SHALL surface as result diagnostics that drive the non-success exit.

#### Scenario: Successful assignment reports changed path and resolutions

- **WHEN** assignment rewrites the plan
- **THEN** the returned result reports `implementation_plan.md` among its changed paths, carries the resolved per-class worker assignments, and the CLI renders a success exit from it

#### Scenario: Not-ready plan fails before rewrite with no changed paths

- **WHEN** the assignment-time plan-shape check fails
- **THEN** the returned result carries a not-ready diagnostic, reports no changed paths, and the CLI renders a non-success exit from it

#### Scenario: Markers and holds drive the exit from the result

- **WHEN** a class has no active worker or a step is on a dependency hold
- **THEN** the returned result carries the corresponding diagnostic alongside the rewritten `implementation_plan.md` changed path, and the CLI renders the non-success exit from that result

### Requirement: Assignment rewrites only assignment lines and preserves content

Rewriting the plan SHALL insert or replace only `#### Assigned:` lines, placing each after the step's evidence/metadata block, and SHALL preserve all other plan content and line structure. Re-running assignment SHALL replace prior `#### Assigned:` lines rather than duplicating them.

#### Scenario: Unrelated plan content is preserved

- **WHEN** a plan with narrative, checklists, and metadata is assigned
- **THEN** only `#### Assigned:` lines change and every other line is byte-preserved

#### Scenario: Re-assignment replaces prior assignment lines

- **WHEN** assignment runs on a plan that already contains `#### Assigned:` lines
- **THEN** the prior lines are replaced with the newly resolved values and no duplicate `#### Assigned:` lines remain
