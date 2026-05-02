## Context

For project type `A` projects with multiple active classes, the cross-class transport/contract approach (REST + OpenAPI, gRPC + protobuf, GraphQL SDL, Thrift IDL, tRPC, etc.) is a stable project-level decision. Without anchoring it at init, the decision surfaces late as `<to be defined during implementation>` placeholders during Step `7` instead of as a planned project-level fact, weakening every downstream step that deltas against `common_contract_definition.md`.

CRP-119 defines the artifact-contract slice of Gap 8: a §5 "Cross-Class Transport/Contract Approach" section in the backend stack blueprint, its placeholder sentinel, and its quality-helper rules. The MCP/inference derivation flow, user-approval conversation, and downstream mirroring into `common_contract_definition.md` and `feature_contract_delta.md` are owned by CRP-120.

## Goals / Non-Goals

**Goals:**

- Add §5 to the backend stack blueprint template only, with three fields: `transport_protocol`, `schema_format`, `user_approved`.
- Define a literal placeholder sentinel `<to be defined during first feature implementation plan>`, distinct from Step `7`'s `<to be defined during implementation>` so the two obligations remain separately trackable.
- Forbid §5 in the frontend and mobile blueprint templates; backend is the sole holder.
- Extend `check_project_stack_blueprint_quality.sh` with structural §5 rules: required-on-BE, forbidden-on-FE/Mobile, all fields populated, both protocol and schema in matching states, `user_approved: true` invalid when either field is the placeholder.
- Provide an inline reference example in the backend template showing both populated and placeholdered shapes.
- Add a Step `1.1` finished-only-if condition stating that every active backend blueprint has a §5 section either fully populated and `user_approved: true`, or fully placeholdered.

**Non-Goals:**

- The MCP/inference derivation flow that proposes concrete §5 values (CRP-120).
- The user-approval conversation that writes `user_approved: true` (CRP-120).
- The Step `2` mirror into `common_contract_definition.md` (CRP-120).
- The Step `6` mirror into `feature_contract_delta.md` (CRP-120).
- Any per-endpoint contract content. §5 carries protocol and schema format only; per-endpoint contract shape stays in `common_contract_definition.md` and `feature_contract_delta.md`.

## Decisions

### Decision 1: Backend is the sole holder of §5

§5 lives on every active backend blueprint and is forbidden on frontend and mobile blueprints. Consumers do not duplicate the section.

Alternatives considered: putting §5 on frontend/mobile too (rejected — duplicates project-level state and creates write-conflict risk between classes); putting §5 in a separate project-level artifact (rejected — multi-backend projects need one §5 per backend, and the backend blueprint is already the natural per-backend anchor).

### Decision 2: Multi-backend projects carry §5 independently per blueprint

When a project has multiple active backend classes (e.g., two backend services sharing a Thrift contract), every active backend blueprint carries §5 independently. The quality helper does not enforce that values match across multiple backends — that's a project-level concern handled by CRP-120's Step `2` mirror, which records per-backend ownership in `common_contract_definition.md`.

### Decision 3: Placeholder is a distinct sentinel from Step `7`'s

The §5 placeholder is the literal `<to be defined during first feature implementation plan>`. It must not collide with Step `7`'s `<to be defined during implementation>` so the two obligations remain separately trackable in artifacts and tooling.

### Decision 4: `transport_protocol` and `schema_format` must be in matching states

The quality helper rejects the mixed case where one field is concrete and the other is the placeholder. Either the project has decided the cross-class transport/contract approach (both concrete) or it has not (both placeholder); there is no honest in-between.

### Decision 5: `user_approved: true` invalid when either field is the placeholder

A placeholder is by definition not a user-approved decision. The quality helper rejects `user_approved: true` paired with a placeholder, eliminating one class of bookkeeping drift where the flow forgot to clear the approval flag while reverting to placeholder.

### Decision 6: Step `1.1` enforces §5 state but does not derive values

The Step `1.1` condition added by this CRP only states that §5 must be present in valid form (fully populated + approved, or fully placeholdered). The actual derivation — MCP query, stack inference, approval conversation — lands in CRP-120.

### Decision 7: §5 is required only when an in-project cross-class peer exists

§5 captures cross-class wire format. It has no anchor when the project has no in-project peer for the backend to coordinate with. Concretely, §5 is a no-op in two cases:

- the project has no active backend class (only frontend and/or mobile);
- the project has exactly one active backend class and no other active class.

§5 is required on every active backend blueprint in every other case: backend + frontend, backend + mobile, backend + frontend + mobile, or two-or-more active backends sharing a contract.

This keeps the trigger one-line: "§5 applies when the backend has at least one in-project peer." The lone-backend exemption avoids forcing a placeholder onto a project where no future feature will ever resolve it.

## Risks / Trade-offs

- **Risk: §5 grows into per-endpoint contract content** → Mitigation: rule explicitly limits §5 to protocol and schema format; per-endpoint contract shape stays in `common_contract_definition.md` and `feature_contract_delta.md`.
- **Risk: confused with Step `7` placeholder** → Mitigation: distinct sentinel string makes the two obligations independently grep-able and trackable.
- **Risk: helper rejects valid evolving state** → Mitigation: only the two extreme states are valid (both concrete + approved, or both placeholder + not approved); intermediate transitions are owned by the CRP-120 derivation flow, which writes both fields atomically.
- **Risk: multi-backend projects drift on §5** → Mitigation: independent §5 per backend is intentional; Step `2` mirror in CRP-120 records per-backend ownership, making divergence visible without forcing project-wide convergence.
- **Risk: helper changes break CRP-114 callers** → Mitigation: §5 rules are additive — projects without an active backend class produce no §5; FE/Mobile templates remain unchanged in content.

## Migration Plan

No runtime migration. This change extends the backend blueprint template, the blueprint rule, and the quality helper; it adds one Step `1.1` condition. Type `B` and type `C` flows are unchanged because they do not author project stack blueprints. Type `A` projects whose blueprints predate this CRP will fail the helper until §5 is added; CRP-120 supplies the derivation flow that writes §5 (concrete or placeholder), so the upgrade path is "land CRP-119 and CRP-120 together."

## Open Questions

- None blocking. Field ordering inside §5 (`transport_protocol` then `schema_format` then `user_approved`) is conventional and follows the placeholder-vs-concrete pairing logic.
