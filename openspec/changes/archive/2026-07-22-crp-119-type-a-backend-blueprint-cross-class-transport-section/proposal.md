## Why

For project type `A` projects with multiple active classes, the pipeline never explicitly captures how those classes communicate (REST + OpenAPI, GraphQL, gRPC, Thrift, tRPC, etc.). The cross-class transport/contract approach is a stable project-level decision, not a feature-scoped one — it belongs at init time and should be either stated up front (when MCP guidance or stack inference is confident) or carried as a visible placeholder until a feature defines it.

This CRP covers the artifact-contract slice of Gap 8: it adds a §5 "Cross-Class Transport/Contract Approach" section to the backend stack blueprint only, defines its schema and the placeholder sentinel, and extends the blueprint quality helper to enforce its structural rules. The MCP/inference derivation flow, user-approval interaction, and downstream mirroring into `common_contract_definition.md` and `feature_contract_delta.md` land in the second Gap 8 CRP.

## What Changes

- Extend `project_stack_blueprint_be_TEMPLATE.md` with a new required section `§5 Cross-Class Transport/Contract Approach` carrying `transport_protocol`, `schema_format`, and `user_approved` fields.
- Include an inline reference example in the BE template showing both a populated shape and a placeholdered shape.
- Do not modify the frontend or mobile blueprint templates. Presence of §5 in either is invalid.
- Update `project_stack_blueprint_rule.md` to define §5 semantics: backend is the sole holder; multi-backend projects carry §5 independently per blueprint; the rule is a no-op when the project has no in-project cross-class peer (no active backend, or exactly one active backend with no other active class); the literal placeholder is `<to be defined during first feature implementation plan>` (distinct from step 7's `<to be defined during implementation>` so the two obligations remain separately trackable).
- Extend `check_project_stack_blueprint_quality.sh` to validate §5 structurally: section present in every backend blueprint, absent from frontend and mobile blueprints, all §5 fields present and non-empty, `transport_protocol` and `schema_format` are either both concrete values or both the literal placeholder (mixed states invalid), `user_approved: true` invalid when either field is the literal placeholder.
- Add a step 1.1 condition to `init_progress_definition_TEMPLATE.yaml` so every active backend blueprint has a §5 section that is either fully populated and `user_approved: true`, or fully placeholdered.
- Add focused tests covering: §5 presence required on BE blueprints when an in-project peer exists, §5 absence required on FE/Mobile blueprints, mixed concrete-vs-placeholder rejected, `user_approved: true` with any placeholder field rejected, multi-backend projects carry §5 independently per BE blueprint, no-active-backend and lone-backend projects produce no §5 anywhere, and type `B`/`C` blueprint quality remains unaffected.

## Capabilities

### New Capabilities

- `overmind-cross-class-transport-section-contract`: Overmind SHALL define a §5 "Cross-Class Transport/Contract Approach" section in the backend project stack blueprint, owned solely by backend, carrying `transport_protocol`, `schema_format`, and `user_approved` fields, and supporting both populated and placeholdered shapes.
- `overmind-cross-class-transport-section-quality-gate`: Overmind SHALL validate the §5 section structurally — required on backend blueprints, forbidden on frontend and mobile blueprints, all fields populated, both protocol and schema in matching states (both concrete or both placeholder), and `user_approved: true` only when neither field is the placeholder.

### Modified Capabilities

(none — no existing archived specs)

## Impact

- `overmind/templates/project_stack_blueprint_be_TEMPLATE.md`
- `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md` (no §5 — enforcement only, no content change)
- `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md` (no §5 — enforcement only, no content change)
- `overmind/rules/project_stack_blueprint_rule.md`
- `overmind/scripts/helper/check_project_stack_blueprint_quality.sh`
- `overmind/templates/init_progress_definition_TEMPLATE.yaml` (step 1.1 condition addition)
- `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
