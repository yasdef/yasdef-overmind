## MODIFIED Requirements

### Requirement: Step 8.3 SHALL preserve Step 8.1 slices by default
Step `8.3` SHALL preserve Step `8.1` slice boundaries by default and SHALL only transform slices by one of the following explicit actions: reorder, split overloaded slices, add prerequisite slices, or merge slices that satisfy merge eligibility rules. When a Step `8.1` slice preserves a required missing operator-facing surface, Step `8.3` SHALL keep that surface as explicit delivery work in the final implementation plan and SHALL NOT replace it with supporting-only scaffolding steps.

#### Scenario: No transformation preconditions met
- **WHEN** Step `8.1` slices are already dependency-feasible and not overloaded
- **THEN** Step `8.3` SHALL preserve the original slice boundaries in `implementation_plan.md`

#### Scenario: Required operator-facing surface remains explicit after planning
- **WHEN** Step `8.1` contains a slice that explicitly delivers a required missing operator-facing surface
- **THEN** Step `8.3` SHALL retain at least one implementation-plan step that still explicitly delivers that operator-facing surface

#### Scenario: Supporting scaffolding does not replace preserved surface delivery
- **WHEN** a required missing operator-facing surface also has supporting auth, API, contract, coordination, or state work
- **AND** Step `8.3` transforms the surrounding slice structure
- **THEN** the final plan SHALL still include explicit delivery work for the operator-facing surface itself
- **AND** the supporting-only work SHALL NOT be treated as fulfilling the surface-delivery obligation

#### Scenario: Merge is rejected when only reducing step count
- **WHEN** a candidate merge is justified only by step-count reduction, requirement-grouping convenience, or component-traceability convenience
- **THEN** Step `8.3` SHALL keep slices separate
- **AND** SHALL NOT collapse scaffold-heavy frontend slices into broad buckets without a hard dependency

#### Scenario: Allowed transformation records rationale
- **WHEN** Step `8.3` applies reorder, split, prerequisite insertion, or an eligible merge
- **THEN** the final plan SHALL include a rationale that explains the transformation and dependency reasoning
