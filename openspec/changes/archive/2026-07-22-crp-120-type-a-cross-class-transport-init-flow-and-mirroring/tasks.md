## 1. Shared Trigger Predicate

- [x] 1.1 Factor a single helper predicate (e.g., shell function `__cross_class_peer_exists`) that returns true when the project has at least one in-project cross-class peer for the backend (another active backend, an active frontend, or an active mobile class)
- [x] 1.2 Use the same predicate from Step `1.1` derivation, Step `2` mirror, and Step `6` mirror so the trigger is evaluated consistently
- [x] 1.3 Confirm the predicate is a no-op for project types `B` and `C`

## 2. Step `1.1` §5 Derivation Flow (reuses existing MCP/approval harness)

- [x] 2.1 Extend `overmind/scripts/init_project_stack_blueprints.sh` to invoke §5 derivation per active backend blueprint when the trigger predicate is true, reusing the existing MCP-query / user-approval harness already used for §2 stack choices, §3 layer bindings, and §4 baseline tokens
- [x] 2.2 Reuse the existing `stack_knowledge_base` MCP-query path: read `.setup/external_sources.yaml` for a `type: stack_knowledge_base` entry and query it for a transport/schema proposal first; do not introduce a parallel MCP-query mechanism
- [x] 2.3 Add the §5-specific stack-inference fallback (NEW): when no reachable `stack_knowledge_base` source yields a confident proposal, derive a transport/schema proposal from the approved §2 stack choices on the same blueprint (e.g., Spring Boot → REST + OpenAPI 3.1; gRPC service framework → gRPC + protobuf)
- [x] 2.4 Reuse the existing user-approval flow: present any confident proposal (MCP or stack-inference) through the same approval mechanism used for §2/§3/§4, recording proposal source and approval state in command output as today
- [x] 2.5 Add the §5-specific placeholder write path (NEW): when neither source yields a confident proposal, or the user declines a confident proposal, write `<to be defined during first feature implementation plan>` for both `transport_protocol` and `schema_format` with `user_approved: false`, without prompting for approval; do not retry the declined source
- [x] 2.6 Confirm: never auto-fill concrete §5 values without explicit user approval through the existing approval flow
- [x] 2.7 Extend `overmind/rules/project_stack_blueprint_rule.md` with the §5 derivation/approval narrative (MCP → §5-specific stack inference → placeholder, approval required for concrete writes only, decline falls through to placeholder)
- [x] 2.8 Confirm the structural §5 contract from CRP-119 is unchanged

## 3. Step `2` `common_contract_definition.md` Mirror

- [x] 3.1 Update `overmind/templates/common_contract_definition_TEMPLATE.md` with a per-backend §5 mirror section, used only when §5 applies for type `A`
- [x] 3.2 Update `overmind/scripts/init_common_contract_definition.sh` to write per-backend §5 mirror entries verbatim from each active backend blueprint when the trigger predicate is true
- [x] 3.3 Label each entry with the owning backend's identity (`service_name` or `repo_name` from blueprint §1) when more than one active backend exists
- [x] 3.4 Carry concrete values verbatim and the placeholder verbatim; do not collapse, normalize, or reject mismatched values across backends
- [x] 3.5 Confirm placeholder carry-through does not block Step `2`
- [x] 3.6 Confirm Step `2` writes no §5 mirror entries when the trigger predicate is false (lone backend, or no active backend) or for project types `B`/`C`

## 4. Step `6` `feature_contract_delta.md` Mirror

- [x] 4.1 Extend `overmind/templates/feature_contract_delta_TEMPLATE.md` with two per-backend fields, `transport_protocol` and `schema_format`, each accepting a concrete value or the literal placeholder
- [x] 4.2 Include inline reference shapes for both the populated and placeholdered cases
- [x] 4.3 Update `overmind/scripts/feature_contract_delta.sh` to mirror the current per-backend `transport_protocol` and `schema_format` from `common_contract_definition.md` into `feature_contract_delta.md` when the trigger predicate is true
- [x] 4.4 Permit the feature to record concrete `transport_protocol` and `schema_format` values directly in delta when it defines or refines them, regardless of whether `common_contract_definition.md` carries the placeholder or different concrete values
- [x] 4.5 Confirm Step `6` introduces no resolution state machine, required block, terminal-state check, or quality-helper enforcement for §5
- [x] 4.6 Confirm Step `6` writes no §5 fields when the trigger predicate is false (lone backend, or no active backend) or for project types `B`/`C`

## 5. Init Progress Conditions

- [x] 5.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` with type `A` Step `2` conditions: when §5 applies, `common_contract_definition.md` reflects each active backend blueprint's §5 verbatim; placeholder carry-through does not block Step `2`; per-backend ownership is recorded for multi-backend projects
- [x] 5.2 Update `init_progress_definition_TEMPLATE.yaml` with type `A` Step `6` conditions: when §5 applies, `feature_contract_delta.md` mirrors the current `transport_protocol` and `schema_format` per backend from `common_contract_definition.md`; the feature may record concrete values directly when it defines or refines them; no enforcement check
- [x] 5.3 Confirm Step `2` and Step `6` conditions are no-ops for type `A` projects with no in-project cross-class peer (lone backend, or no active backend) and for project types `B`/`C`

## 6. Tests

- [x] 6.1 Update `tests/ai_scripts/init_project_stack_blueprints_tests.sh`: type `A` BE+FE with confident MCP proposal writes §5 populated and `user_approved: true`
- [x] 6.2 Type `A` BE+FE with no MCP but confident stack inference writes §5 populated and `user_approved: true` via inference
- [x] 6.3 Type `A` BE+FE with neither confident: §5 placeholdered with `user_approved: false`, no approval prompt
- [x] 6.4 Type `A` user-decline path: confident proposal declined falls through to placeholder pair without retry
- [x] 6.5 Type `A` lone backend (one BE, no other class): §5 derivation flow is a no-op, blueprint carries no §5
- [x] 6.6 Type `A` no active backend: §5 derivation flow is a no-op, no §5 anywhere
- [x] 6.7 Type `A` multi-backend-only: every active backend blueprint independently runs the §5 derivation flow
- [x] 6.8 Type `B` and type `C`: Step `1.1` §5 derivation flow is a no-op
- [x] 6.9 Update `tests/ai_scripts/init_common_contract_definition_tests.sh`: type `A` BE+FE concrete §5 mirrors verbatim into `common_contract_definition.md`
- [x] 6.10 Type `A` BE+FE placeholdered §5 mirrors verbatim and Step `2` completes successfully
- [x] 6.11 Type `A` multi-backend with mismatched concrete values: both entries appear, each labelled by backend identity
- [x] 6.12 Type `A` lone backend: Step `2` writes no §5 mirror entries
- [x] 6.13 Type `A` no active backend: Step `2` writes no §5 mirror entries
- [x] 6.14 Type `B` and type `C`: Step `2` is unchanged, no §5 mirror entries
- [x] 6.15 Update `tests/ai_scripts/init_feature_contract_delta_tests.sh`: type `A` feature mirrors current concrete §5 values per backend by default
- [x] 6.16 Type `A` feature mirrors placeholder by default when `common_contract_definition.md` carries the placeholder
- [x] 6.17 Type `A` feature defines concrete values directly: delta records the feature's concrete values regardless of `common_contract_definition.md` state
- [x] 6.18 Type `A` subsequent feature continues to mirror placeholder when project default still placeholdered
- [x] 6.19 Type `A` lone backend and no active backend: delta carries no §5 fields
- [x] 6.20 Type `B` and type `C`: Step `6` is unchanged, delta carries no §5 fields

## 7. Verification

- [x] 7.1 Run `bash tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- [x] 7.2 Run `bash tests/ai_scripts/init_common_contract_definition_tests.sh`
- [x] 7.3 Run `bash tests/ai_scripts/init_feature_contract_delta_tests.sh`
- [x] 7.4 Confirm CRP-120 does not change CRP-119's §5 structural contract or quality-helper rules
- [x] 7.5 Confirm CRP-120 does not introduce a Step `6` enforcement check, resolution state machine, or required block for §5
