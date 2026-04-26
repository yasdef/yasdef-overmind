# Project Stack Blueprint - Mobile

## 1. Meta
- class: mobile
- repo_name: payments-mobile
- service_name: payments-app
- planned_repo_path: /planned/repos/payments-mobile (planned)
- group_id_or_package_root: app
- last_updated: 2026-04-26

## 2. Stack Choices
- platforms: Android Kotlin + iOS Swift
- android_ui: Jetpack Compose
- ios_ui: SwiftUI
- navigation: Jetpack Navigation + SwiftUI NavigationStack
- state: ViewModel + Kotlin Flow, Swift Observation
- http: Ktor client + URLSession wrapper
- auth_client: secure token storage via Android Keystore and iOS Keychain
- local_storage: Room + SwiftData
- device_integration: permissions, deep links, push notifications
- distribution: Play Console + App Store Connect
- test_stack: JUnit, XCTest, Compose UI tests, XCUITest

## 3. Layer Bindings

### 3.1 UI Composition
- folder_paths: app/src/main/java/<package>/ui, ios/App/UI
- archetypes: ComposeScreen, SwiftUIView, NavigationGraph
- user_reachable_pattern: screen:<name>

### 3.2 Component
- folder_paths: app/src/main/java/<package>/ui/components, ios/App/Components
- archetypes: SharedComposable, SwiftUIViewComponent, DesignTokenModule
- user_reachable_pattern: none

### 3.3 State / Data
- folder_paths: app/src/main/java/<package>/state, ios/App/State
- archetypes: ViewModel, StateFlow, ObservableModel
- user_reachable_pattern: none

### 3.4 API Integration
- folder_paths: app/src/main/java/<package>/api, ios/App/API
- archetypes: ApiClient, RequestMapper, ResponseMapper, ApiError
- user_reachable_pattern: none

### 3.5 UX Behavior
- folder_paths: app/src/main/java/<package>/ui, ios/App/UI
- archetypes: LoadingState, EmptyState, ErrorPresenter, PermissionPrompt
- user_reachable_pattern: none

### 3.6 Platform / Runtime
- folder_paths: app/src/main/java/<package>/config, ios/App/Config
- archetypes: EnvConfig, AppBootstrap, FeatureFlagProvider
- user_reachable_pattern: none

### 3.7 Native / Device Integration
- folder_paths: app/src/main/java/<package>/device, ios/App/Device
- archetypes: PermissionHandler, PushRegistration, DeepLinkHandler, BiometricAdapter
- user_reachable_pattern: deeplink:<scheme>/<path>

### 3.8 Local Storage / Offline / Sync
- folder_paths: app/src/main/java/<package>/storage, ios/App/Storage
- archetypes: LocalDatabase, SyncQueue, OfflineCache
- user_reachable_pattern: none

### 3.9 Test
- folder_paths: app/src/test, app/src/androidTest, ios/AppTests, ios/AppUITests
- archetypes: UnitTest, UITest, ContractTest
- user_reachable_pattern: none

