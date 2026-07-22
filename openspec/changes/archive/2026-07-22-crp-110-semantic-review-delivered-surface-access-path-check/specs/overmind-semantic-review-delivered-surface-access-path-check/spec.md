## ADDED Requirements

### Requirement: Semantic review SHALL evaluate newly delivered user-reachable surfaces for inbound access-path clarity
The semantic review workflow SHALL inspect each newly delivered `user_reachable_surface` referenced by `implementation_plan.md` and determine whether an operator-visible inbound affordance already exists in the applicable surface map or is newly added by a sibling plan step. When neither condition is true, the review SHALL record a `delivered_surface_consumption_unclear` finding that raises the operator question of whether the surface is intentionally isolated or missing inbound access work, instead of assuming the delivered surface is adequately reachable.

#### Scenario: Delivered route without inbound affordance raises a finding
- **WHEN** an implementation step delivers a new route, page, screen, CLI command, or public endpoint
- **AND** the applicable surface map shows no existing inbound affordance for that surface
- **AND** no sibling implementation step adds an inbound affordance
- **THEN** the semantic review SHALL record a `delivered_surface_consumption_unclear` finding naming the delivered surface and the affected implementation step
- **AND** SHALL frame the finding as an operator reachability question rather than silently accepting the plan

#### Scenario: Sibling inbound-affordance step prevents the finding
- **WHEN** an implementation step delivers a new user-reachable surface
- **AND** another implementation step in the same plan explicitly adds the inbound affordance that makes the surface reachable to an operator
- **THEN** the semantic review SHALL treat the delivered surface as reachability-covered
- **AND** SHALL NOT emit `delivered_surface_consumption_unclear` solely for that surface

#### Scenario: Intentional isolation may reject the finding with rationale
- **WHEN** a newly delivered user-reachable surface has no existing or newly planned inbound affordance
- **AND** product or operator review confirms the surface is intentionally isolated by design
- **THEN** the semantic review MAY resolve the `delivered_surface_consumption_unclear` finding as rejected
- **AND** the review artifact SHALL record the rationale in `resolution_notes`
