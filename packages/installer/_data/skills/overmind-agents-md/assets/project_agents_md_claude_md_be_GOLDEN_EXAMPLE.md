## 1. Document Meta

- artifact_kind: project_agents_md_claude_md
- class: backend
- project: checkout-platform
- source_blueprint: project_stack_blueprint_backend.md
- last_updated: 2026-07-13

## Stack Baseline

- language: Java 21
- framework: Spring Boot 3
- build: Maven wrapper
- rdbms: PostgreSQL
- migrations: Flyway
- async_messaging: Kafka
- http_clients: Spring WebClient
- auth: OAuth2 resource server with JWT validation
- logging: structured JSON logs
- metrics: Micrometer
- tracing: OpenTelemetry
- health: Spring Boot Actuator health and readiness probes
- deployment: container image for Kubernetes
- test_stack: JUnit 5, AssertJ, Testcontainers, WireMock

## Target Project Shape

- folder_paths: `src/main/java/com/example/checkout/api`, `service`, `domain`, `persistence`, `integration`, `config`, `src/test`

## Layer Responsibilities

### 3.1 API

- archetypes: REST controllers, request/response DTOs, exception mappers
- user_reachable_pattern: inbound HTTP requests enter through controllers and are translated before service calls

### 3.2 Service

- archetypes: application services, transaction boundaries, orchestration policies
- user_reachable_pattern: use cases coordinate domain decisions and integrations without leaking transport types

### 3.3 Domain

- archetypes: aggregates, value objects, domain services, policy objects
- user_reachable_pattern: business decisions are made by domain types with deterministic tests

### 3.4 Persistence

- archetypes: repositories, entities, migrations, query adapters
- user_reachable_pattern: persistence adapters translate between domain models and storage models

### 3.5 Integration

- archetypes: Kafka producers/consumers, HTTP clients, external DTO mappers
- user_reachable_pattern: external systems are isolated behind ports with timeout and retry policy

### 3.6 Runtime / Ops

- archetypes: configuration, observability, security, health, deployment descriptors
- user_reachable_pattern: runtime behavior is explicit, observable, and environment-configured

### 3.7 Test

- archetypes: unit fixtures, integration tests, contract tests, containerized dependency tests
- user_reachable_pattern: tests verify public behavior and persistence/integration boundaries

## Mission

Build backend services where code quality, maintainability, and testability take priority over delivery speed. The service must keep business rules isolated from frameworks, make runtime behavior observable, and protect contract compatibility.

## Non-Negotiable Engineering Rules

- Keep transport, application, domain, persistence, and integration concerns separated.
- Do not let controllers, entities, or external DTOs become the domain model.
- Do not bypass migrations for schema changes.
- Every external call must have explicit timeout, error mapping, and observability.
- Security, validation, and idempotency decisions must be visible in code and tests.

## Coding Standards

- Use constructor injection and immutable value objects where practical.
- Keep transactions at service boundaries and avoid hidden database writes in mappers.
- Validate incoming requests at the API edge and translate errors consistently.
- Keep domain methods deterministic and free from framework dependencies.
- Prefer narrow ports over broad service locators or generic utility layers.

## Testing Standard

- coverage_floor: recommend at least 80% statement coverage for changed backend code, with domain, service, and integration edge cases covered regardless of aggregate percentage.
- Unit tests cover domain policies and service orchestration.
- Integration tests cover repositories, migrations, security-sensitive endpoints, and messaging adapters.
- Contract tests cover externally visible API or message shapes when they change.

## Linting and Quality Gates

- local_checks: `./mvnw test`, targeted integration tests, formatter/linter where configured
- ci_checks: compile, unit tests, integration tests, static analysis, image build where configured
- A change is not ready while enforced tests fail, migrations are unverified, or runtime config is undocumented.

## Definition of Done

- The change preserves layer boundaries and public contract compatibility.
- Database and messaging changes are migration-backed and test-backed.
- Logs, metrics, tracing, and health implications are handled for new runtime paths.
- Tests cover successful behavior, failure behavior, and boundary translation.
- No unrelated refactors or formatting churn are included.

## Decision Guidance for Agents

- If the blueprint conflicts with existing committed code, preserve existing behavior and ask before restructuring.
- Prefer explicit domain names over generic `manager`, `helper`, or `util` abstractions.
- Add dependencies only when they fit the approved stack and reduce real operational or code complexity.
- Escalate contract, schema, or security ambiguity instead of inventing durable policy.
