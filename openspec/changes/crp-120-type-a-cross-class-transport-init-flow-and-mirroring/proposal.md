## Why

Once the backend stack blueprint carries a §5 "Cross-Class Transport/Contract Approach" section (companion CRP), type `A` init still needs a concrete derivation flow that fills §5 from MCP guidance or stack inference (with explicit user approval), or carries the placeholder when neither source is confident. The decision must then be visible in `common_contract_definition.md` and `feature_contract_delta.md` so the cross-class transport/contract approach is anchored at project init when derivable, and otherwise carried as a tracked placeholder until a feature defines it.

This CRP covers the integration slice of Gap 8: it wires the §5 derivation flow into Step `1.1`, mirrors §5 verbatim into Step `2` (`common_contract_definition.md`), and mirrors §5 into Step `6` (`feature_contract_delta.md`) where each feature may either carry the placeholder forward or record concrete values directly. There is no resolution state machine, no required block, and no enforcement check at Step `6` — only mirroring.

## What Changes

- Apply every change in this CRP only when the project has at least one in-project cross-class peer for the backend (another active backend, an active frontend, or an active mobile class). Projects with no active backend, or exactly one active backend and no other active class, are a no-op for the §5 derivation, mirror, and delta flow.
- Extend the existing Step `1.1` MCP-query / user-approval harness (already used to author §2 stack choices, §3 layer bindings, and §4 baseline tokens via `.setup/external_sources.yaml` `stack_knowledge_base`) so that, for every active backend blueprint when §5 applies:
  - first attempt MCP-backed derivation by querying the configured `stack_knowledge_base` source via the existing harness;
  - otherwise attempt §5-specific inference from the approved §2 stack choices (e.g., Spring Boot → REST + OpenAPI 3.1, gRPC framework → gRPC + protobuf);
  - when either source yields a confident proposal, present it for user approval through the existing approval flow and write `transport_protocol` + `schema_format` with `user_approved: true`;
  - when neither source yields a confident proposal, or the user declines a confident proposal, write the literal placeholder for both fields with `user_approved: false`; placeholder writes do not require approval;
  - never auto-fill concrete §5 values without explicit user approval.
- Update `project_stack_blueprint_rule.md` with the derivation/approval narrative for §5 (MCP → stack inference → placeholder), keeping the structural §5 contract (defined in the companion CRP) unchanged.
- Add Step `2` conditions, type `A` only and only when §5 applies, to `init_progress_definition_TEMPLATE.yaml`:
  - `common_contract_definition.md` reflects each active backend blueprint's §5 verbatim (concrete values or placeholder);
  - placeholder carry-through does not block Step `2`;
  - `common_contract_definition.md` records which backend owns which contract approach when multiple backends are active.
- Update `common_contract_definition_TEMPLATE.md` to provide a per-backend mirror of §5 values, so Step `2` has a structural location for the verbatim mirror.
- Extend `feature_contract_delta_TEMPLATE.md` with two simple per-backend fields, `transport_protocol` and `schema_format`, each accepting a concrete value or the literal `<to be defined during first feature implementation plan>` placeholder.
- Add Step `6` conditions, type `A` only and only when §5 applies, to `init_progress_definition_TEMPLATE.yaml`: `feature_contract_delta.md` mirrors the current `transport_protocol` and `schema_format` per backend from `common_contract_definition.md`. When the feature defines or refines those values, `feature_contract_delta.md` records the concrete values directly; the placeholder otherwise carries forward. No required block, no terminal-state machine, no enforcement check.
- Add tests covering: type `A` BE+FE with confident MCP proposal (§5 populated, `user_approved: true`); type `A` BE+FE with no MCP but confident stack inference (same outcome via inference); type `A` BE+FE with neither (placeholdered §5, Steps `1.1`/`2`/`6` all pass, delta mirrors placeholder); type `A` feature defines values (delta records concrete values directly, subsequent features may mirror placeholder or record their own concrete values); type `A` multi-backend-only (each active backend §5 carried independently through Step `2` and Step `6`); type `A` lone backend with no other active class (derivation/mirror/delta flow is a no-op, no §5 anywhere); type `A` no active backend (no §5 anywhere); type `B` and `C` flows unchanged.

## Capabilities

### New Capabilities

- `overmind-cross-class-transport-derivation-flow`: When the project has at least one in-project cross-class peer for the backend, Step `1.1` SHALL derive backend §5 values by reusing the existing MCP-query / user-approval harness — querying the configured `stack_knowledge_base` MCP source from `.setup/external_sources.yaml` first, otherwise inferring from approved §2 stack choices — present any confident proposal for user approval, and write the literal placeholder when no source is confident or the user declines, never auto-filling concrete values without approval. The flow SHALL be a no-op when no such peer exists.
- `overmind-cross-class-transport-contract-mirror`: When §5 applies, Step `2` SHALL reflect each active backend blueprint's §5 verbatim into `common_contract_definition.md` (concrete values or placeholder), labeling per-backend ownership when multiple backends are active, and SHALL NOT block on placeholder carry-through. The mirror SHALL be a no-op when no in-project cross-class peer exists.
- `overmind-cross-class-transport-feature-delta-mirror`: When §5 applies, Step `6` SHALL mirror the current per-backend `transport_protocol` and `schema_format` from `common_contract_definition.md` into `feature_contract_delta.md` (concrete values or placeholder), permit the feature to record concrete values directly when it defines or refines them, and SHALL NOT introduce a resolution state machine or enforcement check. The mirror SHALL be a no-op when no in-project cross-class peer exists.

### Modified Capabilities

(none — no existing archived specs)

## Impact

- Depends on `crp-119-type-a-backend-blueprint-cross-class-transport-section`.
- `overmind/scripts/init_project_stack_blueprints.sh`
- `overmind/rules/project_stack_blueprint_rule.md`
- `overmind/templates/common_contract_definition_TEMPLATE.md`
- `overmind/templates/feature_contract_delta_TEMPLATE.md`
- `overmind/templates/init_progress_definition_TEMPLATE.yaml`
- `overmind/scripts/init_common_contract_definition.sh` (mirror wiring)
- `overmind/scripts/feature_contract_delta.sh` (mirror wiring)
- `tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- `tests/ai_scripts/init_common_contract_definition_tests.sh`
- `tests/ai_scripts/init_feature_contract_delta_tests.sh`
