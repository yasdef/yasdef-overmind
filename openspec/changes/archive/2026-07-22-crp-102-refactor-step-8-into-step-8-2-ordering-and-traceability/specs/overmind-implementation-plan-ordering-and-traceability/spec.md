## ADDED Requirements

### Requirement: Step 8.2 SHALL assemble the final implementation plan from Step 8.1 slices
The workflow SHALL execute a dedicated Step `8.2` phase that consumes `implementation_slices.md` from Step `8.1` together with `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md` to produce the final shared `implementation_plan.md`.

#### Scenario: Step 8.2 fails when required Step 8.1 slice input is missing
- **WHEN** Step `8.2` starts and `implementation_slices.md` is absent
- **THEN** the phase SHALL exit non-zero
- **AND** SHALL report `implementation_slices.md` as a missing required input

#### Scenario: Step 8.2 produces implementation plan from complete planning input set
- **WHEN** all required Step `8.2` inputs are present
- **THEN** Step `8.2` SHALL generate `implementation_plan.md`
- **AND** the generated plan SHALL be derived from the Step `8.1` slice structure

### Requirement: Step 8.2 SHALL preserve Step 8.1 slices by default
Step `8.2` SHALL preserve Step `8.1` slice boundaries by default and SHALL only transform slices by one of the following explicit actions: reorder, split overloaded slices, add prerequisite slices, or merge slices that satisfy merge eligibility rules.

#### Scenario: No transformation preconditions met
- **WHEN** Step `8.1` slices are already dependency-feasible and not overloaded
- **THEN** Step `8.2` SHALL preserve the original slice boundaries in `implementation_plan.md`

#### Scenario: Merge is rejected when only reducing step count
- **WHEN** a candidate merge is justified only by step-count reduction, requirement-grouping convenience, or component-traceability convenience
- **THEN** Step `8.2` SHALL keep slices separate
- **AND** SHALL NOT collapse scaffold-heavy frontend slices into broad buckets without a hard dependency

#### Scenario: Allowed transformation records rationale
- **WHEN** Step `8.2` applies reorder, split, prerequisite insertion, or an eligible merge
- **THEN** the final plan SHALL include a rationale that explains the transformation and dependency reasoning

### Requirement: Step 8.2 SHALL enforce dependency-aware ordering and valid parallelism
Step `8.2` SHALL order work so shared contracts and prerequisites occur first and SHALL schedule backend and frontend slices in parallel when no hard dependency blocks concurrent execution. Dependency edges SHALL be explicit and SHALL only be added when justified by contract, state, schema, or prerequisite constraints.

#### Scenario: Shared prerequisite is ordered before dependent slices
- **WHEN** multiple slices depend on one shared contract or prerequisite change
- **THEN** Step `8.2` SHALL place that prerequisite slice before all dependent slices

#### Scenario: Independent backend and frontend slices are parallelized
- **WHEN** backend and frontend slices have no hard dependency edge between them
- **THEN** Step `8.2` SHALL place them in the same parallel execution stage

#### Scenario: Explicit dependency edge includes concrete justification
- **WHEN** Step `8.2` serializes one slice after another
- **THEN** the plan SHALL include the concrete dependency reason
- **AND** the reason SHALL map to contract, state, schema, or prerequisite evidence

### Requirement: Step 8.2 SHALL restore full final-plan traceability
Step `8.2` SHALL produce a final `implementation_plan.md` that includes repository ownership, complete `REQ-*` / `NFR-*` requirement coverage, and technical-evidence coverage, with validation performed by the implementation-plan quality gate after ordered-plan assembly.

#### Scenario: Final plan contains complete requirements coverage
- **WHEN** Step `8.2` completes plan generation
- **THEN** every in-scope `REQ-*` and `NFR-*` identifier SHALL be covered by at least one plan step

#### Scenario: Quality gate validates post-ordering traceability contract
- **WHEN** the implementation-plan quality helper runs after Step `8.2`
- **THEN** it SHALL validate ordered-plan correctness and traceability completeness for the final plan output
