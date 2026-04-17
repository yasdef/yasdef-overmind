# Technical Requirements

## 1. Document Meta
- feature_id: AA-1
- feature_title: manage-tel-usr-id
- project_type_code: B
- source_requirements_ears: projects/umss_spg-1775826843000/manage_tel_usr_id-1775827430/requirements_ears.md
- source_common_contract_definition: projects/umss_spg-1775826843000/common_contract_definition.md
- source_surface_map_artifacts: projects/umss_spg-1775826843000/manage_tel_usr_id-1775827430/project_surface_struct_resp_map_backend.md, projects/umss_spg-1775826843000/manage_tel_usr_id-1775827430/project_surface_struct_resp_map_frontend.md
- analyzed_repo_classes: backend, frontend
- last_updated: 2026-04-10
- confidence_level: medium

## 2. Feature Scope and Inputs
- feature_summary: This feature standardizes failure outcomes for the trusted internal Telegram identity and account flow while preserving the current happy-path DTOs and service-token auth boundaries.
- included_behavior: Identify-or-register, account create, account resolve, duplicate-account handling, unauthorized rejection, invalid-input rejection, and missing-account retrieval are all in scope for this feature slice.
- excluded_behavior: Admin authentication, audit-log read APIs, and unrelated platform/runtime concerns stay out of scope unless they are already required to preserve the feature contract.

## 3. Repository Evidence
### Repository: backend
- class: backend
- evidence_scope: Reviewed controllers, DTOs, exception handling, service flows, security filter-chain wiring, persistence constraints, and integration tests named by the feature surface map.
- primary_paths: src/main/java/com/teleforecaster/umss/api, src/main/java/com/teleforecaster/umss/service, src/main/java/com/teleforecaster/umss/security, src/test/java/com/teleforecaster/umss
- key_findings: Happy-path identity and account flows already exist, duplicate-account prevention is backed by persistence uniqueness, and the main remaining work is to make failure semantics deterministic and fully covered by tests.
- constraints: Keep existing success DTOs and service-token auth boundaries aligned with the shared baseline in common_contract_definition.md.
- open_gaps: Concurrent duplicate-account coverage and one explicit feature-level error contract across all three service-token endpoints are still incomplete.

### Repository: frontend
- class: frontend
- evidence_scope: Reviewed API client modules, error normalization helpers, and proposal-level account client surfaces referenced by the feature surface map.
- primary_paths: src/api/client.ts, src/api/errors.ts, src/api/identities.ts, openspec/changes
- key_findings: Controlled error mapping already exists, the identity client is drifted against backend request/response shapes, and account-create/account-resolve clients are only partially represented.
- constraints: Frontend must adopt backend-owned field names and error semantics instead of preserving proposal-only aliases.
- open_gaps: Account clients and deterministic duplicate/not-found handling are not yet fully implemented against backend-owned shapes.

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- requirement_summary: Trusted internal callers can submit Telegram user data and receive a usable identity result.
- transport_layer: Backend identify-or-register controller/service flow exists; frontend has a partial identity client path in src/api/identities.ts
- user_reachable_surface: POST /api/v1/telegram/identify
- gap_status: partially_implemented
- repo_impact: multiple
- evidence: Backend controller/service flow exists and the common contract baseline marks the identity contract as drifted between repos.
- gap_to_close: Reconcile the identity client contract with backend-owned request/response fields and preserve deterministic error handling while keeping the happy path working.

### Requirement: REQ-7
- requirement_summary: Concurrent duplicate account-create requests keep the first success and reject later duplicates predictably.
- transport_layer: Backend uniqueness constraint on account type per Telegram user; AccountService.createAccount() handles conflict path
- user_reachable_surface: POST /api/v1/accounts
- gap_status: partially_implemented
- repo_impact: backend
- evidence: Persistence uniqueness exists on account type per Telegram user and the feature contract delta requires explicit first-success-later-duplicate verification.
- gap_to_close: Add explicit concurrency-oriented controller/service coverage and ensure duplicate-account failures map through one standardized error contract.

### Requirement: NFR-1
- requirement_summary: The core flow responds within the expected latency budget.
- transport_layer: Existing runtime structure handles current flows within observed latency; no explicit performance instrumentation for the updated failure-path
- user_reachable_surface: none
- gap_status: unclear
- repo_impact: backend
- evidence: Current inputs focus on contract/error semantics rather than measurable latency coverage for the updated flow.
- gap_to_close: Confirm whether additional performance verification is required after the failure-contract changes are stabilized.

## 5. Impacted Components
### Component: GlobalExceptionHandler
- repo: backend
- component_kind: security
- relevant_paths: src/main/java/com/teleforecaster/umss/exception/GlobalExceptionHandler.java
- requirement_refs: REQ-1, REQ-7
- current_state: Generic validation/conflict/not-found mappings exist but they do not yet represent one feature-level contract across identify-or-register, account-create, and account-resolve.
- required_behavior: Provide deterministic invalid-input, unauthorized, duplicate-account, and not-found outcomes without breaking existing success payloads.
- gap_to_close: Align exception-to-response handling with the feature contract delta and extend tests that assert the shared error shape.
- dependency_notes: Backend controller and security-path verification should converge on the same error contract before downstream frontend client work is finalized.
- evidence: Backend surface map and feature contract delta both point to shared failure semantics as the primary change area.

### Component: AccountControllerIntegrationTest
- repo: backend
- component_kind: test
- relevant_paths: src/test/java/com/teleforecaster/umss/api/AccountControllerIntegrationTest.java, src/test/java/com/teleforecaster/umss/AccountServiceIntegrationTest.java
- requirement_refs: REQ-7
- current_state: Happy-path create/resolve behavior and normal duplicate failure coverage exist, but explicit concurrent duplicate verification is still missing.
- required_behavior: Cover first-success-later-duplicate behavior and stable conflict responses under concurrent create requests.
- gap_to_close: Add persistence-backed concurrency coverage and keep assertions aligned with the shared feature-level error contract.
- dependency_notes: This test work depends on finalizing the canonical backend error contract for duplicate-account outcomes.
- evidence: Feature contract delta explicitly requires concurrency verification and the backend test surface highlights the missing coverage.

### Component: src/api/identities.ts
- repo: frontend
- component_kind: api_client
- relevant_paths: src/api/identities.ts, src/api/errors.ts
- requirement_refs: REQ-1
- current_state: The identity client exists but its request/response assumptions do not yet match the backend-owned contract captured in the common baseline.
- required_behavior: Consume backend-owned request fields, success payload shape, and deterministic failure semantics without leaking raw backend error text.
- gap_to_close: Reconcile client mapping with the backend baseline and extend error normalization for duplicate/not-found cases shared with the account clients.
- dependency_notes: Frontend contract reconciliation should follow backend error-contract stabilization so the same semantics are consumed on all feature endpoints.
- evidence: Common contract definition records current drift on the identity contract and the frontend surface map points to apiRequest/error handling as the ownership boundary.

## 6. Cross-Repo Constraints and Planning Signals
- constraint_1: Backend remains the source of truth for synchronous identity/account request and response fields; frontend must consume backend field names rather than preserve proposal-only aliases.
- prep_1: Stabilize and test one backend failure contract for invalid-input, unauthorized, duplicate-account, and not-found outcomes before finalizing downstream frontend client updates.

## 7. Known Risks / Uncertainties
- risk_1: The identity contract drift between backend runtime behavior and frontend client expectations may require explicit coordination before a shared implementation plan can be sliced cleanly.
