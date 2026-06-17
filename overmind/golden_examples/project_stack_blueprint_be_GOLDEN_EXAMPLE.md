# Project Stack Blueprint - Backend

## 1. Meta
- class: backend
- repo_name: payments-backend
- service_name: payments-api
- group_id: com.acme.payments
- last_updated: 2026-04-26

## 2. Stack Choices
- language: Java 21
- framework: Spring Boot 3.2 (Web, Security, Data JPA, Actuator)
- build: Gradle
- rdbms: Postgres 16
- migrations: Liquibase
- async_messaging: Kafka 3
- http_clients: Spring RestClient
- auth: JWT with Spring Security filter chain
- logging: Logback JSON to stdout
- metrics: Micrometer to Prometheus at /actuator/prometheus
- tracing: OpenTelemetry SDK to OTLP
- health: /actuator/health
- deployment: Docker to Kubernetes
- test_stack: JUnit 5, Testcontainers, REST Assured

## 3. Layer Bindings

### 3.1 API
- folder_paths: src/main/java/{group}/api, src/main/java/{group}/api/dto
- archetypes: Controller, RequestDto, ResponseDto, ControllerAdvice
- user_reachable_pattern: METHOD /api/v{n}/<resource>

### 3.2 Service
- folder_paths: src/main/java/{group}/service
- archetypes: ApplicationService, UseCase, Orchestrator
- user_reachable_pattern: none

### 3.3 Domain
- folder_paths: src/main/java/{group}/domain
- archetypes: Entity, ValueObject, Enum, DomainPolicy, DomainEvent
- user_reachable_pattern: none

### 3.4 Persistence
- folder_paths: src/main/java/{group}/repository, src/main/resources/db/changelog
- archetypes: JpaRepository, JPA Entity mapping, Liquibase changeset
- user_reachable_pattern: none

### 3.5 Integration
- folder_paths: src/main/java/{group}/integration
- archetypes: KafkaListener, KafkaProducer, VendorClient
- topics_convention: <bounded-context>.<event-name>.v<n>
- user_reachable_pattern: none

### 3.6 Runtime / Ops
- folder_paths: src/main/java/{group}/security, src/main/java/{group}/config, src/main/resources
- archetypes: SecurityConfig, JwtAuthenticationFilter, application.yaml, MetricsConfig, Dockerfile
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src/test/java/{group}
- archetypes: UnitTest, IntegrationTest, ContractTest, SecurityFilterTest
- user_reachable_pattern: none

## 5. Cross-Class Transport/Contract Approach
- transport_protocol: REST
- schema_format: OpenAPI 3.1
- user_approved: true
