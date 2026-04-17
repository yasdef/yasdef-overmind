# Project Surface Structure + Responsibility Map (Backend)

## 1. Document Meta
- repo_name: order-service
- service_name: order-management-api
- project_type_code: B
- project_classes: backend
- feature_id: FEAT-220
- feature_title: Checkout risk evaluation
- analyzed_repo_paths: /workspace/repos/order-service
- source_inputs_used: requirements_ears.md, feature_contract_delta.md, init_progress_definition.yaml, repository code evidence
- last_updated: 2026-04-08

## 2. Feature Scope
- feature_summary: This feature adds score-based checkout risk output and related persistence while keeping rollout safe.
- in_scope_feature_delta: Extend backend flow to calculate, persist, and expose additive risk score information for checkout.
- out_of_scope_notes: No auth redesign, no unrelated schema cleanup, no global exception or observability framework rewrite.

## 3. Key Parts of Repo and Their Responsibilities

### 3.1 API Layer
- responsibility_summary: Owns the external HTTP contract of the service, including controllers, request validation, response DTOs, and any API-shape changes exposed to clients.
- main_repo_paths: /workspace/repos/order-service/src/main/java/com/acme/api, /workspace/repos/order-service/src/main/java/com/acme/api/dto
- key_components: CheckoutRiskController, CheckoutRiskResponse, shared API request and response DTOs
- transport_layer: CheckoutRiskController, CheckoutRiskResponse DTO, shared request/response DTOs
- user_reachable_surface: POST /api/v1/checkout/risk-evaluation

### 3.2 Application / Service Layer
- responsibility_summary: Owns orchestration of backend use cases, coordinates domain logic with persistence or integrations, and defines the main execution flow of the service.
- main_repo_paths: /workspace/repos/order-service/src/main/java/com/acme/service
- key_components: CheckoutRiskService, orchestration services, flow coordinators
- transport_layer: CheckoutRiskService, orchestration services, flow coordinators
- user_reachable_surface: none

### 3.3 Domain Layer
- responsibility_summary: Owns business rules, policy logic, core entities, and value objects that define what the system means rather than how it is exposed or stored.
- main_repo_paths: /workspace/repos/order-service/src/main/java/com/acme/domain
- key_components: CheckoutRiskDecision, policy objects, domain value types
- transport_layer: CheckoutRiskDecision, policy objects, domain value types
- user_reachable_surface: none

### 3.4 Persistence / Data Layer
- responsibility_summary: Owns how service data is stored and retrieved, including repositories, mappings, SQL, and schema evolution.
- main_repo_paths: /workspace/repos/order-service/src/main/java/com/acme/persistence, /workspace/repos/order-service/src/main/resources/db/migration
- key_components: CheckoutRiskSignalRepository, persistence mappings, SQL migrations
- transport_layer: CheckoutRiskSignalRepository, persistence mappings, SQL migrations
- user_reachable_surface: none

### 3.5 Integration Layer
- responsibility_summary: Owns boundaries to external systems such as provider clients, queues, and adapter code used to communicate outside this service.
- main_repo_paths: /workspace/repos/order-service/src/main/java/com/acme/integration
- key_components: provider clients, outbound adapters, message handlers
- transport_layer: provider clients, outbound adapters, message handlers
- user_reachable_surface: none

### 3.6 Runtime / Ops Layer
- responsibility_summary: Owns runtime behavior controls such as config, feature flags, dependency wiring, logging, metrics, tracing, and rollout-related operational hooks.
- main_repo_paths: /workspace/repos/order-service/src/main/resources, /workspace/repos/order-service/src/main/java/com/acme/observability
- key_components: application.yaml, CheckoutRiskMetrics, logging and metrics helpers
- transport_layer: application.yaml, CheckoutRiskMetrics, logging and metrics helpers
- user_reachable_surface: none

### 3.7 Test Layer
- responsibility_summary: Owns verification of service behavior across API, application, domain, persistence, and other touched backend areas.
- main_repo_paths: /workspace/repos/order-service/src/test/java/com/acme
- key_components: CheckoutRiskControllerIT, CheckoutRiskServiceTest, repository and integration tests
- transport_layer: CheckoutRiskControllerIT, CheckoutRiskServiceTest, repository and integration tests
- user_reachable_surface: none

### 3.8 Another Layer(s)
> add as much new layers as needed based on same pattern and follow number convention

## 4. Backend Surfaces Touched With Current Feature

### 4.1 API Surface
- surface_summary: HTTP endpoints, controllers, request or response DTOs, API schema.
- applicability: applicable
- repo_paths: /workspace/repos/order-service/src/main/java/com/acme/api/CheckoutRiskController.java, /workspace/repos/order-service/src/main/java/com/acme/api/dto/CheckoutRiskResponse.java
- why_feature_touches_it: The feature changes the HTTP response by adding risk score and risk signal fields.
- expected_changes: Update controller response assembly and response DTO shape.
- evidence: Current controller and DTO expose only binary allow or deny risk output.
- transport_layer: CheckoutRiskController.evaluateRisk(), CheckoutRiskResponse DTO
- user_reachable_surface: POST /api/v1/checkout/risk-evaluation

### 4.2 Application / Service Surface
- surface_summary: Use-case orchestration, services, command handlers, business flow coordination.
- applicability: applicable
- repo_paths: /workspace/repos/order-service/src/main/java/com/acme/service/CheckoutRiskService.java
- why_feature_touches_it: The service layer must orchestrate scoring, persistence, and response data assembly.
- expected_changes: Update checkout risk orchestration and add score-aware flow handling.
- evidence: Current service stops at binary evaluation and does not assemble additive score payloads.
- transport_layer: ReconciliationService.run(), CheckoutRiskService.evaluate()
- user_reachable_surface: none

### 4.3 Domain Surface
- surface_summary: Domain models, business rules, value objects, state transitions, policy logic.
- applicability: applicable
- repo_paths: /workspace/repos/order-service/src/main/java/com/acme/domain/risk/CheckoutRiskDecision.java
- why_feature_touches_it: The domain model must represent score-aware decision details instead of only binary state.
- expected_changes: Extend decision model and related policy logic for score-aware output.
- evidence: Current domain object does not carry score or signal reference information.
- transport_layer: CheckoutRiskDecision, risk policy objects, domain value types
- user_reachable_surface: none

### 4.4 Persistence / Data Surface
- surface_summary: Repositories, DAOs, ORM mappings, SQL queries, migrations, indexes.
- applicability: applicable
- repo_paths: /workspace/repos/order-service/src/main/resources/db/migration/V145__checkout_risk_signal.sql, /workspace/repos/order-service/src/main/java/com/acme/persistence/CheckoutRiskSignalRepository.java
- why_feature_touches_it: The feature must persist risk signals referenced by the response contract.
- expected_changes: Add migration and repository support for risk signal write path.
- evidence: Feature contract delta requires signal persistence but the repo has no matching write path today.
- transport_layer: CheckoutRiskSignalRepository.save(), V145__checkout_risk_signal.sql
- user_reachable_surface: none

### 4.5 Integration Surface
- surface_summary: External clients, event producers or consumers, queue handlers, adapter boundaries.
- applicability: not_applicable
- repo_paths: none
- why_feature_touches_it: The feature uses existing internal logic and does not add or change an external integration.
- expected_changes: No change.
- evidence: Repository scan did not show any required external adapter or event contract change for this feature slice.
- transport_layer: none
- user_reachable_surface: none

### 4.6 Runtime / Ops Surface
- surface_summary: Config, feature flags, DI wiring, logging, metrics, tracing, jobs, rollout controls.
- applicability: applicable
- repo_paths: /workspace/repos/order-service/src/main/resources/application.yaml, /workspace/repos/order-service/src/main/java/com/acme/observability/CheckoutRiskMetrics.java
- why_feature_touches_it: The change needs safe rollout and production visibility for score-driven behavior.
- expected_changes: Add rollout flag wiring, metrics, and structured logs for score outcomes.
- evidence: Existing repo patterns already use config and metrics hooks for feature rollout and monitoring.
- transport_layer: CheckoutRiskMetrics.record(), feature-flag config in application.yaml
- user_reachable_surface: none

### 4.7 Test Surface
- surface_summary: Unit, integration, contract, and other verification assets for touched backend areas.
- applicability: applicable
- repo_paths: /workspace/repos/order-service/src/test/java/com/acme/api/CheckoutRiskControllerIT.java, /workspace/repos/order-service/src/test/java/com/acme/service/CheckoutRiskServiceTest.java
- why_feature_touches_it: The feature changes response contract, orchestration logic, and persistence behavior.
- expected_changes: Extend integration and unit coverage for additive score behavior.
- evidence: Existing tests verify binary outcomes only and do not cover score-aware payloads.
- transport_layer: CheckoutRiskControllerIT, CheckoutRiskServiceTest, repository and integration tests
- user_reachable_surface: none

### 4.8 Unexpected Backend Surface
- surface_summary: Any real backend surface that does not fit the standard categories above.
- applicability: not_applicable
- repo_paths: none
- why_feature_touches_it: No unexpected backend surface was discovered for this feature.
- expected_changes: No change.
- evidence: Standard backend surfaces were sufficient to explain the observed impact.
- transport_layer: none
- user_reachable_surface: none
