## ADDED Requirements

### Requirement: Step 7 rule requires the transport vs user-reachable split in generated surface maps
`feature_repo_surface_and_exec_context_rule.md` and the generator script `feature_repo_surface_and_exec_context.sh` SHALL require every Section 3 layer block and every Section 4 surface block in generated `project_surface_struct_resp_map_*.md` artifacts to carry explicit `transport_layer` and `user_reachable_surface` subfields. Emitting a single conflated `current_state` line SHALL NOT be permitted.

#### Scenario: Generator emits both subfields per block
- **WHEN** `feature_repo_surface_and_exec_context.sh` is run for a feature
- **THEN** every block in the output surface map SHALL contain a `transport_layer:` line and a `user_reachable_surface:` line

#### Scenario: Rule file defines class-specific user-reachable taxonomy
- **WHEN** `feature_repo_surface_and_exec_context_rule.md` is read
- **THEN** it SHALL define what counts as user-reachable for each active project class (frontend: routes/pages/screens; backend: HTTP endpoints, CLI commands, scheduled jobs, admin tools; mobile: screens/deep links)

#### Scenario: Rule file states user_reachable_surface is downstream ground truth
- **WHEN** `feature_repo_surface_and_exec_context_rule.md` is read
- **THEN** it SHALL state that `user_reachable_surface` is the contract consumed by CRP-109's prerequisite trace and that each entry must be a concrete navigable token, not prose

### Requirement: Quality helper rejects surface maps missing the split
`check_feature_repo_surface_and_exec_context_be_quality.sh` and `check_feature_repo_surface_and_exec_context_fe_quality.sh` SHALL fail when any Section 3 or Section 4 block in the surface map is missing one of the two subfields, has both subfields blank, or uses a single conflated `current_state` line.

#### Scenario: Helper fails on missing transport_layer subfield
- **WHEN** a surface map block is missing `transport_layer:` entirely
- **THEN** the quality helper SHALL exit non-zero and SHALL name the block and missing subfield

#### Scenario: Helper fails on missing user_reachable_surface subfield
- **WHEN** a surface map block is missing `user_reachable_surface:` entirely
- **THEN** the quality helper SHALL exit non-zero and SHALL name the block and missing subfield

#### Scenario: Helper passes when all blocks have both subfields
- **WHEN** every Section 3 and Section 4 block in a surface map has non-blank `transport_layer:` and `user_reachable_surface:` values (including `none`)
- **THEN** the quality helper SHALL pass the split-related checks and SHALL NOT emit a split-related failure
