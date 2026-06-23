# Feature Contract Delta - Golden Example

This example is synthetic and project-agnostic.

## 1. Document Meta
- feature_id: FEAT-RESET-001
- feature_title: Self-service password reset
- project_type_code: B
- source_requirements_ears: projects/payments_api/feature-a/requirements_ears.md
- source_common_contract_definition: projects/payments_api/common_contract_definition.md
- delta_needed: true
- last_updated: 2026-04-07

## 2. Delta Summary
- baseline_reference: common contract baseline v2026-04-05
- feature_intent: Introduce password reset token request/confirm contract surfaces for this feature.
- impacted_tracks: backend, frontend
- no_delta_reason: none

## 3. Contract Delta Items
### Delta 1: password-reset-token-flow
- delta_kind: add
- related_baseline_contract: auth-account-http-api
- change_scope: add reset-request and reset-confirm endpoint definitions to shared OpenAPI
- compatibility_impact: additive only, existing login and registration surfaces remain unchanged
- verification_expectation: API contract tests for both endpoints plus event payload assertions

## 4. Track Handoff Signals
- backend_handoff: implement endpoints, token issuance/validation logic, and audit event emission
- frontend_mobile_handoff: implement request/confirm UI flow and map deterministic error payloads

## 5. Cross-Class Transport/Contract Approach Mirror
### Backend: payments-api
- transport_protocol: REST
- schema_format: OpenAPI 3.1

### Backend: ledger-service
- transport_protocol: <to be defined during first feature implementation plan>
- schema_format: <to be defined during first feature implementation plan>
