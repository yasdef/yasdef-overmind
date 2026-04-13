# Project Surface Structure + Responsibility Map (Frontend / Mobile)

## 1. Document Meta
- repo_name: order-portal
- service_name: order-management-ui
- project_type_code: B
- project_classes: frontend, mobile
- feature_id: FEAT-220
- feature_title: Checkout risk evaluation
- analyzed_repo_paths: /workspace/repos/order-portal, /workspace/repos/order-mobile
- source_inputs_used: requirements_ears.md, feature_contract_delta.md, init_progress_definition.yaml, repository code evidence
- last_updated: 2026-04-08

## 2. Feature Scope
- feature_summary: This feature adds score-aware checkout rendering on web and mobile while remaining compatible with staged backend rollout.
- in_scope_feature_delta: Render additive risk score data, map new response fields, and preserve stable client behavior when mixed backend versions exist.
- out_of_scope_notes: No design-system rewrite, no routing overhaul, no unrelated client platform refactor.

## 3. Key Parts of Repo and Their Responsibilities

### 3.1 UI Composition Layer
- responsibility_summary: Owns pages, screens, routes, and layout-level feature composition that determines where and how the user sees the feature in the product flow.
- main_repo_paths: /workspace/repos/order-portal/src/features/checkout, /workspace/repos/order-mobile/src/ui/checkout
- key_components: CheckoutSummary, CheckoutRiskScreen, checkout route-level screens

### 3.2 Component Layer
- responsibility_summary: Owns reusable and feature-specific UI components that render concrete pieces of the experience such as badges, cards, and display variants.
- main_repo_paths: /workspace/repos/order-portal/src/components, /workspace/repos/order-mobile/src/ui/components
- key_components: RiskBadge, summary cards, feature-specific display components

### 3.3 State / Data Layer
- responsibility_summary: Owns client state storage and transformation, including hooks, stores, selectors, query cache, and view-model state used by the feature.
- main_repo_paths: /workspace/repos/order-portal/src/features/checkout/state, /workspace/repos/order-mobile/src/viewmodels
- key_components: useCheckoutRisk, CheckoutRiskViewModel, feature state holders

### 3.4 API Integration Layer
- responsibility_summary: Owns API clients, adapters, and mappers that translate backend contracts into client-side models usable by screens and components.
- main_repo_paths: /workspace/repos/order-portal/src/integration, /workspace/repos/order-mobile/src/network
- key_components: checkoutRiskAdapter, CheckoutRiskMapper, response mappers

### 3.5 UX Behavior Layer
- responsibility_summary: Owns behavior of the feature in motion, including loading states, degraded paths, empty states, error handling, and navigation flow behavior.
- main_repo_paths: /workspace/repos/order-portal/src/features/checkout, /workspace/repos/order-mobile/src/navigation
- key_components: checkoutRiskFlow, CheckoutFlowCoordinator, fallback behavior helpers

### 3.6 Platform / Runtime Layer
- responsibility_summary: Owns cross-cutting client runtime concerns such as feature flags, analytics hooks, i18n, accessibility support, and app-level platform wiring.
- main_repo_paths: /workspace/repos/order-portal/src/platform, /workspace/repos/order-mobile/src/platform
- key_components: feature-flag hooks, analytics wiring, runtime configuration helpers

### 3.7 Test Layer
- responsibility_summary: Owns verification of client behavior across rendering, state, adapters, and runtime compatibility for web and mobile.
- main_repo_paths: /workspace/repos/order-portal/src, /workspace/repos/order-mobile/src/test
- key_components: CheckoutSummary.test.tsx, CheckoutRiskViewModelTest.kt, adapter and UI tests

### 3.8 Another Layer(s)
> add as much new layers as needed based on same pattern and follow number convention

## 4. Frontend / Mobile Surfaces Touched With Current Feature

### 4.1 UI Composition Surface
- surface_summary: Pages, screens, routes, layout-level composition, and top-level feature rendering.
- applicability: applicable
- repo_paths: /workspace/repos/order-portal/src/features/checkout/CheckoutSummary.tsx, /workspace/repos/order-mobile/src/ui/checkout/CheckoutRiskScreen.kt
- why_feature_touches_it: Checkout screens must show additive risk score information.
- expected_changes: Update top-level checkout presentation on web and mobile.
- evidence: Current checkout UI shows only binary risk outcome.

### 4.2 Component Surface
- surface_summary: Shared or feature-specific UI components, props, display variants, and view pieces.
- applicability: applicable
- repo_paths: /workspace/repos/order-portal/src/components/risk/RiskBadge.tsx, /workspace/repos/order-mobile/src/ui/components/RiskBadge.kt
- why_feature_touches_it: Existing risk display components need score-aware variants and content.
- expected_changes: Update risk badge and related presentation components.
- evidence: Current component set supports safe or unsafe display only.

### 4.3 State / Data Surface
- surface_summary: Client state, stores, hooks, selectors, query cache, view-model state.
- applicability: applicable
- repo_paths: /workspace/repos/order-portal/src/features/checkout/state/useCheckoutRisk.ts, /workspace/repos/order-mobile/src/viewmodels/CheckoutRiskViewModel.kt
- why_feature_touches_it: Client state must hold additive score fields and fallback behavior.
- expected_changes: Extend state model and view-model logic for score-aware data.
- evidence: Existing state layer does not carry score or signal id information.

### 4.4 API Integration Surface
- surface_summary: API clients, adapters, request builders, response mappers, client-side contract mapping.
- applicability: applicable
- repo_paths: /workspace/repos/order-portal/src/integration/checkoutRiskAdapter.ts, /workspace/repos/order-mobile/src/network/CheckoutRiskMapper.kt
- why_feature_touches_it: New backend response fields must be mapped into client models.
- expected_changes: Update adapters and response mappers for additive fields.
- evidence: Current adapter layer ignores risk score and signal id fields.

### 4.5 UX Behavior Surface
- surface_summary: Navigation flow, loading states, empty states, error states, optimistic or degraded behavior.
- applicability: applicable
- repo_paths: /workspace/repos/order-portal/src/features/checkout/checkoutRiskFlow.ts, /workspace/repos/order-mobile/src/navigation/CheckoutFlowCoordinator.kt
- why_feature_touches_it: The feature must remain stable when new fields are missing during staged rollout.
- expected_changes: Add degraded-display and fallback handling for mixed payload versions.
- evidence: Current flow assumes binary payloads and has no score-specific fallback path.

### 4.6 Platform / Runtime Surface
- surface_summary: Feature flags, env config, analytics hooks, i18n, accessibility hooks, platform wiring.
- applicability: not_applicable
- repo_paths: none
- why_feature_touches_it: No platform-level client wiring change was found for this feature slice.
- expected_changes: No change.
- evidence: Repository scan showed the feature can be implemented within existing client platform wiring.

### 4.7 Test Surface
- surface_summary: Component, integration, end-to-end, snapshot, and other verification assets for touched client areas.
- applicability: applicable
- repo_paths: /workspace/repos/order-portal/src/features/checkout/__tests__/CheckoutSummary.test.tsx, /workspace/repos/order-mobile/src/test/CheckoutRiskViewModelTest.kt
- why_feature_touches_it: Rendering, mapping, and fallback behavior all need verification.
- expected_changes: Extend component, adapter, and state tests for additive risk score behavior.
- evidence: Current test coverage verifies binary risk display only.

### 4.8 Unexpected Frontend / Mobile Surface
- surface_summary: Any real client-side surface that does not fit the standard categories above.
- applicability: not_applicable
- repo_paths: none
- why_feature_touches_it: No unexpected client-side surface was discovered for this feature.
- expected_changes: No change.
- evidence: Standard client surfaces were sufficient to explain the observed impact.
