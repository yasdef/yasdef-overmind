# Common Contract Definition

## 1. Document Meta
- project_id: payments_api-1743800100123
- project_path: /Users/example/asdlc/projects/payments_api-1743800100123
- source_repo_count: 2
- source_repositories: backend, frontend
- last_updated: 2026-04-04
- confidence_level: high

## 2. Source Repository Evidence
### Repository: backend
- class: backend
- repo_path: /Users/example/repos/payments-api
- contract_evidence_summary: Reviewed HTTP APIs, domain events, and outbound integration adapters that define backend-owned contract behavior.
- key_surfaces_reviewed: POST /api/v1/payments, GET /api/v1/payments/{id}, payment-created topic, reconciliation scheduler, PSP adapter.
- notes: Backend contracts are versioned at API path level and additive for event schema evolution.

### Repository: frontend
- class: frontend
- repo_path: /Users/example/repos/payments-web
- contract_evidence_summary: Reviewed API client modules, request/response DTO mappings, and webhook/deep-link handlers that depend on backend contract guarantees.
- key_surfaces_reviewed: payments API client, checkout status polling contract, payment-status event mapping, session-expiry handling.
- notes: Frontend integration relies on stable response fields for status transitions and validation errors.

## 3. Common Contract Baseline
### Contract: payment-lifecycle-status-model
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: backend
- consumer_repositories: frontend
- contract_surface: GET /api/v1/payments/{id} + status in create/read responses
- contract_status: aligned
- source_of_truth: backend domain model + API error/status payload contract
- canonical_shape: response.status -> one_of{created,authorized,captured,failed,cancelled}; transitions: created->authorized|failed, authorized->captured|failed|cancelled
- shared_types: PaymentStatus enum, PaymentId
- trust_boundary: internal
- compatibility_rule: Additive response metadata allowed; status semantic changes are breaking and require new API version.
- planning_implication: add contract tests
- notes: Frontend may cache labels, but status semantics remain backend-defined.

### Contract: idempotent-payment-create-request
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: backend
- consumer_repositories: frontend
- contract_surface: POST /api/v1/payments
- contract_status: aligned
- source_of_truth: backend payment create endpoint contract
- canonical_shape: request:{idempotency_key, amount, currency, method}; response:{payment_id, operation_id, status}
- shared_types: IdempotencyKey, CurrencyCode, PaymentStatus
- trust_boundary: service_to_service
- compatibility_rule: Additive optional request/response fields allowed; removing required fields is breaking.
- planning_implication: add client module
- notes: Frontend retries must preserve idempotency-key lifetime.

### Contract: payment-created-event-schema
- contract_kind: event
- interaction_mode: async
- producer_repositories: backend
- consumer_repositories: frontend, analytics
- contract_surface: topic payment.created.v1
- contract_status: drifted
- source_of_truth: backend event publisher schema
- canonical_shape: payload:{event_id, payment_id, status, occurred_at}; key: payment_id
- shared_types: PaymentId, PaymentStatus
- trust_boundary: service_to_service
- compatibility_rule: Additive payload fields allowed; renaming/removing fields or changing semantics is breaking.
- planning_implication: reconcile consumer drift
- notes: Frontend mapper still expects legacy field `state`.

## 4. Reconciliation Decisions
- decision_1: Backend API contract is the canonical source for synchronous request/response fields; frontend mirrors but does not redefine these fields.
- decision_2: Event naming and status semantics remain shared; backend owns schema publication and frontend/mobile consume published schemas as downstream contracts.

## 5. Known Risks / Uncertainties
- uncertainty_1: Legacy webhook payload contracts still need explicit ownership mapping between backend integration and platform operations teams.
- uncertainty_2: A formal cross-repository approval process for schema-breaking event changes is not yet documented.

## 6. Common Planning Signals
- prep_1: Reconcile `payment.created` consumer mappings (`state` -> `status`) before feature-level implementation planning.
- prep_2: Introduce shared contract tests for payment status transitions and create-payment idempotency response fields.

## 7. Cross-Class Transport/Contract Approach Mirror
### Backend: payments-api
- transport_protocol: REST
- schema_format: OpenAPI 3.1
- user_approved: true

### Backend: ledger-service
- transport_protocol: <to be defined during first feature implementation plan>
- schema_format: <to be defined during first feature implementation plan>
- user_approved: false
