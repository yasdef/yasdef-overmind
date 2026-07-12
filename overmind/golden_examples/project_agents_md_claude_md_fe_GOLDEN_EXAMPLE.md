## 1. Document Meta

- artifact_kind: project_agents_md_claude_md
- class: frontend
- project: checkout-platform
- source_blueprint: project_stack_blueprint_frontend.md
- last_updated: 2026-07-13

## Stack Baseline

- framework: Angular 20 with standalone components
- router: Angular Router with route-level lazy loading
- state: NgRx signal store for shared state, component signals for local state
- http: Angular HttpClient with typed adapters and interceptors
- styling: SCSS modules plus design-token CSS custom properties
- auth_client: OAuth2/OIDC browser client with refresh handled by the auth boundary
- env_validation: typed environment schema checked during bootstrap
- deployment: static SPA bundle behind CDN with immutable hashed assets
- test: Vitest for units, Angular Testing Library for components, Playwright for flows

## Target Project Shape

- folder_paths: `src/app/routes`, `src/app/features`, `src/app/shared/ui`, `src/app/shared/data-access`, `src/app/core`, `src/testing`

## Layer Responsibilities

### 3.1 UI Composition

- archetypes: route components, page containers, layout shells
- user_reachable_pattern: all user-visible flows enter through route-owned composition components

### 3.2 Component

- archetypes: presentational components, form controls, table/list widgets
- user_reachable_pattern: reusable UI receives typed inputs and emits explicit events

### 3.3 State / Data

- archetypes: signal stores, selectors, query facades
- user_reachable_pattern: pages read state through facades and never call transport code directly

### 3.4 API Integration

- archetypes: typed API clients, DTO mappers, interceptors
- user_reachable_pattern: feature data access owns request/response translation

### 3.5 UX Behavior

- archetypes: validators, guards, optimistic update policies, empty/error states
- user_reachable_pattern: visible behavior is encoded in testable components and route guards

### 3.6 Platform / Runtime

- archetypes: bootstrap providers, config loader, telemetry hooks
- user_reachable_pattern: runtime services are initialized once and consumed through injected ports

### 3.7 Test

- archetypes: component harnesses, fixture builders, Playwright page objects
- user_reachable_pattern: tests exercise public UI behavior, not private implementation details

## Mission

Build a frontend that favors code quality, maintainability, and testability ahead of delivery speed. Every feature should be understandable from its route boundary, typed through its data-access layer, and covered at the level where regressions would be observed by users.

## Non-Negotiable Engineering Rules

- Keep route composition, state, API integration, and presentational components in separate layers.
- Do not put HTTP calls in components.
- Do not suppress TypeScript, lint, accessibility, or test failures to finish faster.
- Treat loading, empty, error, and permission-denied states as part of the feature.
- Keep design-token usage centralized; do not introduce one-off color or spacing systems.

## Coding Standards

- Use strict TypeScript and typed public APIs for every shared component, store, and service.
- Prefer signals and explicit inputs/outputs over implicit shared mutable state.
- Keep components small enough to test without rendering unrelated feature surfaces.
- Map DTOs at the data-access boundary before they reach UI state.
- Keep copy, labels, and aria text stable enough for localization and automated tests.

## Accessibility (a11y)

- Meet WCAG 2.2 AA for keyboard operation, visible focus, semantic structure, form labeling, color contrast, and error announcement.
- Every interactive component must be reachable and operable by keyboard.
- Automated checks are required, but manual keyboard review remains part of done.

## Internationalization (i18n)

- User-visible strings live behind the project translation mechanism.
- Avoid concatenated translatable fragments.
- Locale-sensitive dates, numbers, and currencies must use framework localization utilities.

## UI Automation IDs

- Use stable `data-testid` values only for durable user-facing controls and regions.
- Prefer role/name locators in Playwright when they are stable.
- Do not couple tests to CSS classes or generated framework internals.

## Applied Visual Style Contract

- Use the approved design tokens for color, spacing, typography, focus, elevation, and state.
- Maintain restrained enterprise density: compact controls, clear hierarchy, and predictable scan paths.
- Avoid decorative layouts that reduce task clarity in operational screens.

## Testing Standard

- coverage_floor: recommend at least 80% statement coverage for changed frontend code, with critical state and data-access paths covered regardless of aggregate percentage.
- Component tests cover inputs, outputs, accessible labels, validation, and visible state transitions.
- Playwright covers the core happy path and at least one failure path for each user-critical workflow.
- API adapters are tested with representative success and error DTOs.

## Linting and Quality Gates

- local_checks: `npm test`, `npm run lint`, `npm run typecheck`, targeted `npx playwright test`
- ci_checks: install, typecheck, lint, unit/component tests, Playwright smoke, build
- The branch is not ready while any enforced check fails or is skipped without an approved documented reason.

## Definition of Done

- The feature has typed state, typed API integration, and accessible UI states for success and failure.
- Required tests pass locally and cover the meaningful regression surface.
- User-visible text is localization-ready.
- Visual changes follow the approved token and component contract.
- No unrelated refactors or formatting churn are included.

## Decision Guidance for Agents

- When the blueprint and existing repo disagree, preserve existing working code and ask before changing structure.
- Prefer the smallest component/state split that keeps behavior testable.
- Add an abstraction only when at least two call sites or a clear boundary need it.
- If a design decision is absent, use bounded fallback aligned with the stack and request operator approval before writing durable guidance.
