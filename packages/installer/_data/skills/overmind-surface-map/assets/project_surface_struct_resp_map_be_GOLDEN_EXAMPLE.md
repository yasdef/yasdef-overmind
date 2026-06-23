# Project Surface Structure + Responsibility Map (Backend)

## 1. Document Meta
- repo_name: payment-service
- service_name: payment-processing-api
- project_type_code: A
- project_classes: backend
- feature_id: FEAT-101
- feature_title: Payment processing checkout
- analyzed_repo_paths: /workspace/repos/payment-service (partial), src/api/ (planned, project_stack_blueprint_backend.md §3.1)
- source_inputs_used: requirements_ears.md, feature_contract_delta.md, init_progress_definition.yaml, repository code evidence, project_stack_blueprint_backend.md planned structural evidence
- last_updated: 2026-05-01

## 2. Feature Scope
- feature_summary: This feature adds payment processing checkout for a new project. Repository evidence covers the API layer; stack blueprint provides planned structure for service, domain, and persistence layers; surfaces unknown to both sources carry explicit placeholders.
- in_scope_feature_delta: Expose payment checkout endpoint, orchestrate payment service logic, and persist payment records.
- out_of_scope_notes: No auth redesign, no unrelated schema cleanup.

## 3. Key Parts of Repo and Their Responsibilities

### 3.1 API Layer
- responsibility_summary: Owns the external HTTP contract of the service, including controllers, request validation, and response DTOs exposed to clients.
- main_repo_paths: /workspace/repos/payment-service/src/api
- key_components: PaymentController, PaymentResponse
- transport_layer: PaymentController, PaymentResponse DTO
- user_reachable_surface: POST /api/v1/payments/checkout

### 3.2 Application / Service Layer
- responsibility_summary: Owns orchestration of backend use cases, coordinates domain logic with persistence, and defines the main execution flow.
- main_repo_paths: src/service/ (planned, project_stack_blueprint_backend.md §3.2)
- key_components: PaymentService (planned, project_stack_blueprint_backend.md §3.2)
- transport_layer: PaymentService (planned, project_stack_blueprint_backend.md §3.2)
- user_reachable_surface: none

### 3.3 Domain Layer
- responsibility_summary: Owns business rules, policy logic, core entities, and value objects.
- main_repo_paths: src/domain/ (planned, project_stack_blueprint_backend.md §3.3)
- key_components: PaymentDecision (planned, project_stack_blueprint_backend.md §3.3)
- transport_layer: PaymentDecision (planned, project_stack_blueprint_backend.md §3.3)
- user_reachable_surface: none

### 3.4 Persistence / Data Layer
- responsibility_summary: Owns how service data is stored and retrieved, including repositories, mappings, and schema evolution.
- main_repo_paths: src/persistence/ (planned, project_stack_blueprint_backend.md §3.4)
- key_components: PaymentRepository (planned, project_stack_blueprint_backend.md §3.4)
- transport_layer: PaymentRepository (planned, project_stack_blueprint_backend.md §3.4)
- user_reachable_surface: none

### 3.5 Test Layer
- responsibility_summary: Owns verification of service behavior across API, application, domain, and persistence areas.
- main_repo_paths: /workspace/repos/payment-service/src/test/java/com/acme
- key_components: PaymentControllerIT
- transport_layer: PaymentControllerIT
- user_reachable_surface: none

> Integration and runtime/ops layers are absent from both repository evidence and blueprint §3 for this feature; they are omitted.

## 4. Backend Surfaces Touched With Current Feature

### 4.1 API Surface
- surface_summary: HTTP endpoints, controllers, request or response DTOs, API schema.
- applicability: applicable
- repo_paths: /workspace/repos/payment-service/src/api/PaymentController.java
- why_feature_touches_it: The feature adds the payment checkout HTTP endpoint.
- expected_changes: Add controller method and response DTO for checkout flow.
- evidence: /workspace/repos/payment-service/src/api/PaymentController.java; feature_contract_delta.md DELTA-1
- transport_layer: PaymentController.processCheckout()
- user_reachable_surface: POST /api/v1/payments/checkout

### 4.2 Application / Service Surface
- surface_summary: Use-case orchestration, services, command handlers, business flow coordination.
- applicability: applicable
- repo_paths: src/service/PaymentService.java (planned, project_stack_blueprint_backend.md §3.2)
- why_feature_touches_it: The service layer must orchestrate payment validation and response assembly.
- expected_changes: Add PaymentService with checkout orchestration logic.
- evidence: project_stack_blueprint_backend.md §3.2; feature_contract_delta.md DELTA-1
- transport_layer: PaymentService.processCheckout() (planned, project_stack_blueprint_backend.md §3.2)
- user_reachable_surface: none

### 4.3 Domain Surface
- surface_summary: Domain models, business rules, value objects, state transitions, policy logic.
- applicability: applicable
- repo_paths: src/domain/PaymentDecision.java (planned, project_stack_blueprint_backend.md §3.3)
- why_feature_touches_it: The domain model must represent payment decision state.
- expected_changes: Add PaymentDecision domain object.
- evidence: project_stack_blueprint_backend.md §3.3; feature_contract_delta.md DELTA-2
- transport_layer: PaymentDecision (planned, project_stack_blueprint_backend.md §3.3)
- user_reachable_surface: none

### 4.4 Persistence / Data Surface
- surface_summary: Repositories, DAOs, ORM mappings, SQL queries, migrations, indexes.
- applicability: applicable
- repo_paths: <to be defined during implementation>
- why_feature_touches_it: Feature contract delta requires payment record persistence.
- expected_changes: Add migration and repository for payment write path.
- evidence: feature_contract_delta.md DELTA-3
- transport_layer: <to be defined during implementation>
- user_reachable_surface: none

### 4.5 Integration Surface
- surface_summary: External clients, event producers or consumers, queue handlers, adapter boundaries.
- applicability: not_applicable
- repo_paths: none
- why_feature_touches_it: The feature uses internal logic only; no external integration is required.
- expected_changes: No change.
- evidence: feature_contract_delta.md DELTA-1
- transport_layer: none
- user_reachable_surface: none

### 4.6 Test Surface
- surface_summary: Unit, integration, contract, and other verification assets for touched backend areas.
- applicability: applicable
- repo_paths: /workspace/repos/payment-service/src/test/java/com/acme/api/PaymentControllerIT.java
- why_feature_touches_it: The feature adds an endpoint and orchestration logic that need verification.
- expected_changes: Add integration and unit test coverage for checkout flow.
- evidence: /workspace/repos/payment-service/src/test/java/com/acme/api/PaymentControllerIT.java; feature_contract_delta.md DELTA-1
- transport_layer: PaymentControllerIT
- user_reachable_surface: none

### 4.7 Unexpected Backend Surface
- surface_summary: Any real backend surface that does not fit the standard categories above.
- applicability: not_applicable
- repo_paths: none
- why_feature_touches_it: No unexpected backend surface was discovered for this feature.
- expected_changes: No change.
- evidence: feature_contract_delta.md DELTA-1
- transport_layer: none
- user_reachable_surface: none
