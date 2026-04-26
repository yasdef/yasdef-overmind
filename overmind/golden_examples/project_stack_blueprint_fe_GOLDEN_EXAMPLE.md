# Project Stack Blueprint - Frontend

## 1. Meta
- class: frontend
- repo_name: payments-frontend
- service_name: payments-admin
- planned_repo_path: /planned/repos/payments-frontend (planned)
- group_id_or_package_root: src
- last_updated: 2026-04-26

## 2. Stack Choices
- framework: React 18 + Vite
- router: react-router v6
- state: React Query + Zustand
- http: fetch wrapper in src/api/client.ts
- styling: CSS modules + design tokens
- auth_client: admin JWT in sessionStorage
- env_validation: zod-based env parser at src/config/env.ts
- deployment: static bundle behind CDN
- test: Vitest + React Testing Library + Playwright

## 3. Layer Bindings

### 3.1 UI Composition
- folder_paths: src/routes, src/pages, src/layouts, src/app
- archetypes: RouterDefinition, RootLayout, PageComponent
- user_reachable_pattern: /<route>

### 3.2 Component
- folder_paths: src/components, src/styles
- archetypes: SharedComponent, DesignTokenModule, FeatureComponent
- user_reachable_pattern: none

### 3.3 State / Data
- folder_paths: src/hooks, src/state
- archetypes: ReactQueryHook, Zustand store, selector
- user_reachable_pattern: none

### 3.4 API Integration
- folder_paths: src/api
- archetypes: ApiClient, TypedClientFn, RequestMapper, ResponseMapper, ApiError
- user_reachable_pattern: none

### 3.5 UX Behavior
- folder_paths: src/pages, src/components
- archetypes: LoadingState, EmptyState, ErrorBoundary, RouteErrorPage, DisplayMessageMapper
- user_reachable_pattern: none

### 3.6 Platform / Runtime
- folder_paths: src/main.tsx, src/config, vite.config.ts
- archetypes: Bootstrap, EnvParser, BuildConfig
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src, test
- archetypes: UnitTest, ComponentTest, ContractTest, E2ETest
- user_reachable_pattern: none

