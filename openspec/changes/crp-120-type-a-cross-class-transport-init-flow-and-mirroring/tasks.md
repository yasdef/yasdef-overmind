## 1. Shared Trigger Predicate

- [ ] 1.1 Factor a single helper predicate (e.g., shell function `__cross_class_peer_exists`) that returns true when the project has at least one in-project cross-class peer for the backend (another active backend, an active frontend, or an active mobile class)
- [ ] 1.2 Use the same predicate from Step `1.1` derivation, Step `2` mirror, and Step `6` mirror so the trigger is evaluated consistently
- [ ] 1.3 Confirm the predicate is a no-op for project types `B` and `C`

## 2. Step `1.1` §5 Derivation Flow

- [ ] 2.1 Extend `overmind/scripts/init_project_stack_blueprints.sh` to invoke §5 derivation per active backend blueprint when the trigger predicate is true
- [ ] 2.2 Implement source order: query configured `stack_guidance_sources[backend]` MCP first; if absent, unreachable, or non-confident, infer from approved §2 stack choices; if neither is confident, write the placeholder pair
- [ ] 2.3 Present any confident proposal (MCP or stack inference) for explicit user approval before writing concrete `transport_protocol`, `schema_format`, and `user_approved: true`
- [ ] 2.4 Treat user decline as a fall-through to the placeholder pair without retrying the same source
- [ ] 2.5 Write the placeholder pair (`<to be defined during first feature implementation plan>` for both fields, `user_approved: false`) without prompting for approval
- [ ] 2.6 Update `overmind/rules/project_stack_blueprint_rule.md` with the §5 derivation/approval narrative (MCP → stack inference → placeholder, approval required for concrete writes only)
- [ ] 2.7 Confirm the structural §5 contract from CRP-119 is unchanged

## 3. Step `2` `common_contract_definition.md` Mirror

- [ ] 3.1 Update `overmind/templates/common_contract_definition_TEMPLATE.md` with a per-backend §5 mirror section, used only when §5 applies for type `A`
- [ ] 3.2 Update `overmind/scripts/init_common_contract_definition.sh` to write per-backend §5 mirror entries verbatim from each active backend blueprint when the trigger predicate is true
- [ ] 3.3 Label each entry with the owning backend's identity (`service_name` or `repo_name` from blueprint §1) when more than one active backend exists
- [ ] 3.4 Carry concrete values verbatim and the placeholder verbatim; do not collapse, normalize, or reject mismatched values across backends
- [ ] 3.5 Confirm placeholder carry-through does not block Step `2`
- [ ] 3.6 Confirm Step `2` writes no §5 mirror entries when the trigger predicate is false (lone backend, or no active backend) or for project types `B`/`C`

## 4. Step `6` `feature_contract_delta.md` Mirror

- [ ] 4.1 Extend `overmind/templates/feature_contract_delta_TEMPLATE.md` with two per-backend fields, `transport_protocol` and `schema_format`, each accepting a concrete value or the literal placeholder
- [ ] 4.2 Include inline reference shapes for both the populated and placeholdered cases
- [ ] 4.3 Update `overmind/scripts/feature_contract_delta.sh` to mirror the current per-backend `transport_protocol` and `schema_format` from `common_contract_definition.md` into `feature_contract_delta.md` when the trigger predicate is true
- [ ] 4.4 Permit the feature to record concrete `transport_protocol` and `schema_format` values directly in delta when it defines or refines them, regardless of whether `common_contract_definition.md` carries the placeholder or different concrete values
- [ ] 4.5 Confirm Step `6` introduces no resolution state machine, required block, terminal-state check, or quality-helper enforcement for §5
- [ ] 4.6 Confirm Step `6` writes no §5 fields when the trigger predicate is false (lone backend, or no active backend) or for project types `B`/`C`

## 5. Init Progress Conditions

- [ ] 5.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` with type `A` Step `2` conditions: when §5 applies, `common_contract_definition.md` reflects each active backend blueprint's §5 verbatim; placeholder carry-through does not block Step `2`; per-backend ownership is recorded for multi-backend projects
- [ ] 5.2 Update `init_progress_definition_TEMPLATE.yaml` with type `A` Step `6` conditions: when §5 applies, `feature_contract_delta.md` mirrors the current `transport_protocol` and `schema_format` per backend from `common_contract_definition.md`; the feature may record concrete values directly when it defines or refines them; no enforcement check
- [ ] 5.3 Confirm Step `2` and Step `6` conditions are no-ops for type `A` projects with no in-project cross-class peer (lone backend, or no active backend) and for project types `B`/`C`

## 6. Tests

- [ ] 6.1 Update `tests/ai_scripts/init_project_stack_blueprints_tests.sh`: type `A` BE+FE with confident MCP proposal writes §5 populated and `user_approved: true`
- [ ] 6.2 Type `A` BE+FE with no MCP but confident stack inference writes §5 populated and `user_approved: true` via inference
- [ ] 6.3 Type `A` BE+FE with neither confident: §5 placeholdered with `user_approved: false`, no approval prompt
- [ ] 6.4 Type `A` user-decline path: confident proposal declined falls through to placeholder pair without retry
- [ ] 6.5 Type `A` lone backend (one BE, no other class): §5 derivation flow is a no-op, blueprint carries no §5
- [ ] 6.6 Type `A` no active backend: §5 derivation flow is a no-op, no §5 anywhere
- [ ] 6.7 Type `A` multi-backend-only: every active backend blueprint independently runs the §5 derivation flow
- [ ] 6.8 Type `B` and type `C`: Step `1.1` §5 derivation flow is a no-op
- [ ] 6.9 Update `tests/ai_scripts/init_common_contract_definition_tests.sh`: type `A` BE+FE concrete §5 mirrors verbatim into `common_contract_definition.md`
- [ ] 6.10 Type `A` BE+FE placeholdered §5 mirrors verbatim and Step `2` completes successfully
- [ ] 6.11 Type `A` multi-backend with mismatched concrete values: both entries appear, each labelled by backend identity
- [ ] 6.12 Type `A` lone backend: Step `2` writes no §5 mirror entries
- [ ] 6.13 Type `A` no active backend: Step `2` writes no §5 mirror entries
- [ ] 6.14 Type `B` and type `C`: Step `2` is unchanged, no §5 mirror entries
- [ ] 6.15 Update `tests/ai_scripts/init_feature_contract_delta_tests.sh`: type `A` feature mirrors current concrete §5 values per backend by default
- [ ] 6.16 Type `A` feature mirrors placeholder by default when `common_contract_definition.md` carries the placeholder
- [ ] 6.17 Type `A` feature defines concrete values directly: delta records the feature's concrete values regardless of `common_contract_definition.md` state
- [ ] 6.18 Type `A` subsequent feature continues to mirror placeholder when project default still placeholdered
- [ ] 6.19 Type `A` lone backend and no active backend: delta carries no §5 fields
- [ ] 6.20 Type `B` and type `C`: Step `6` is unchanged, delta carries no §5 fields

## 7. Verification

- [ ] 7.1 Run `bash tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- [ ] 7.2 Run `bash tests/ai_scripts/init_common_contract_definition_tests.sh`
- [ ] 7.3 Run `bash tests/ai_scripts/init_feature_contract_delta_tests.sh`
- [ ] 7.4 Confirm CRP-120 does not change CRP-119's §5 structural contract or quality-helper rules
- [ ] 7.5 Confirm CRP-120 does not introduce a Step `6` enforcement check, resolution state machine, or required block for §5
