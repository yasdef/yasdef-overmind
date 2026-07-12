## 1. Document Meta

- artifact_kind: project_agents_md_claude_md
- class: mobile
- project: checkout-platform
- source_blueprint: project_stack_blueprint_mobile.md
- last_updated: 2026-07-13

## Stack Baseline

- platforms: iOS and Android
- android_ui: Jetpack Compose
- ios_ui: SwiftUI
- navigation: typed navigation graph per platform
- state: unidirectional view-model state
- http: generated API client behind repository interfaces
- auth_client: platform secure-token storage with OIDC session handling
- local_storage: SQLDelight for structured local data and secure storage for secrets
- device_integration: permission-gated camera, push, and file access adapters
- distribution: TestFlight and Play internal testing before store release
- test_stack: unit tests, snapshot tests where approved, platform UI smoke tests

## Target Project Shape

- folder_paths: `shared/domain`, `shared/data`, `androidApp/ui`, `androidApp/navigation`, `iosApp/Views`, `iosApp/Navigation`, `testing`

## Layer Responsibilities

### 3.1 UI Composition

- archetypes: screens, navigation hosts, app shells
- user_reachable_pattern: user flows start from screen-level composition and route through typed navigation

### 3.2 Component

- archetypes: composables, SwiftUI views, reusable controls
- user_reachable_pattern: components render explicit state and send typed user intents upward

### 3.3 State / Data

- archetypes: view models, reducers, repositories, cache policies
- user_reachable_pattern: screens observe immutable state and never call transport directly

### 3.4 API Integration

- archetypes: API clients, DTO mappers, auth interceptors
- user_reachable_pattern: network behavior is isolated behind repositories and mapped to domain results

### 3.5 UX Behavior

- archetypes: validation, offline states, retry flows, permission prompts
- user_reachable_pattern: user-facing behavior handles slow network, no network, denial, and retry explicitly

### 3.6 Platform / Runtime

- archetypes: app lifecycle hooks, configuration, logging, crash reporting
- user_reachable_pattern: runtime services initialize at app start and are injected into feature boundaries

### 3.7 Native / Device Integration

- archetypes: camera, push notifications, file picker, biometric auth adapters
- user_reachable_pattern: platform features are wrapped behind permission-aware interfaces

### 3.8 Local Storage / Offline / Sync

- archetypes: local database, sync queues, conflict policies
- user_reachable_pattern: cached data and pending writes are visible through state and tested with deterministic clocks

### 3.9 Test

- archetypes: view-model tests, repository tests, UI smoke tests, fixture factories
- user_reachable_pattern: tests exercise user-observable state and platform adapter boundaries

## Mission

Build mobile applications where code quality, maintainability, and testability are prioritized ahead of delivery speed. User experience must remain reliable across lifecycle changes, poor networks, denied permissions, and platform differences.

## Non-Negotiable Engineering Rules

- Keep screens, view state, domain logic, transport, storage, and platform adapters separated.
- Do not store secrets outside approved secure storage.
- Do not introduce device permissions without a user-facing rationale and denial behavior.
- Offline, retry, loading, and error states are part of the feature contract.
- Platform-specific behavior must be isolated and tested at the boundary.

## Coding Standards

- Model UI state as immutable values with explicit user intents.
- Keep repositories responsible for transport/storage coordination and DTO mapping.
- Use deterministic clocks and dispatchers in tests.
- Avoid hidden global state and platform singletons in feature logic.
- Keep shared code free from platform UI dependencies.

## Accessibility (a11y)

- Preserve platform accessibility labels, focus order, dynamic type behavior, and touch target sizing.
- Screen reader text must describe action and state, not implementation labels.
- Color cannot be the only carrier of status or validation meaning.

## Internationalization (i18n)

- User-visible strings must use platform localization resources.
- Dates, numbers, currencies, and pluralization must use locale-aware APIs.
- Avoid building localized sentences by concatenating fragments.

## UI Automation IDs

- Use stable accessibility identifiers or test tags for durable screens and primary controls.
- Keep identifiers semantic and independent of layout or styling.
- Do not use generated view hierarchy positions as test selectors.

## Applied Visual Style Contract

- Follow approved platform design tokens and component conventions.
- Respect native interaction patterns where platform expectations diverge.
- Keep dense operational screens scannable without hiding critical state behind gestures only.

## Testing Standard

- coverage_floor: recommend at least 75% statement coverage for changed shared and feature logic, with critical view-model and repository paths covered regardless of aggregate percentage.
- Unit tests cover reducers/view models, domain policies, repositories, and error mapping.
- UI smoke tests cover primary user journeys and permission or network failure states.
- Storage and sync tests use deterministic fixtures and clocks.

## Linting and Quality Gates

- local_checks: platform unit tests, static analysis, formatting, targeted UI smoke tests
- ci_checks: Android build/test, iOS build/test where available, static analysis, artifact packaging
- A change is not ready while platform build, unit tests, or configured static checks fail.

## Definition of Done

- User-facing states cover loading, success, empty, error, offline, and denied-permission behavior.
- Shared/domain logic is testable without platform UI runtime.
- Platform adapters have explicit failure mapping and observability.
- UI text, accessibility labels, and automation identifiers are stable.
- No unrelated refactors or formatting churn are included.

## Decision Guidance for Agents

- Prefer platform-native interaction patterns while keeping shared business logic consistent.
- Ask before changing storage, sync, permission, or release policy.
- Use bounded fallback aligned with the approved stack when guidance is missing, then obtain operator approval.
- Preserve existing gate-passing artifacts unless the operator explicitly approves a revision.
