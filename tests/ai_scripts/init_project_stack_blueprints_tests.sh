#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/init_project_stack_blueprints.sh"
BLUEPRINT_RULE_SRC="$SOURCE_ROOT/overmind/rules/project_stack_blueprint_rule.md"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_project_stack_blueprint_quality.sh"
MODEL_SRC="$SOURCE_ROOT/overmind/setup/models.md"
EXTERNAL_SOURCES_SRC="$SOURCE_ROOT/overmind/setup/external_sources.yaml"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Assertion failed: expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "Assertion failed: expected output to not contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_nonzero_status() {
  local status="$1"
  if [[ "$status" -eq 0 ]]; then
    echo "Assertion failed: expected non-zero status" >&2
    exit 1
  fi
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Assertion failed: expected file to exist: $path" >&2
    exit 1
  fi
}

assert_file_not_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

setup_staged_workspace() {
  local asdlc_root="$1"
  mkdir -p "$asdlc_root/.commands" "$asdlc_root/.rules" "$asdlc_root/.templates" "$asdlc_root/.golden_examples" "$asdlc_root/.setup" "$asdlc_root/.helper" "$asdlc_root/projects"
  cp "$SCRIPT_SRC" "$asdlc_root/.commands/init_project_stack_blueprints.sh"
  cp "$BLUEPRINT_RULE_SRC" "$asdlc_root/.rules/project_stack_blueprint_rule.md"
  cp "$HELPER_SRC" "$asdlc_root/.helper/check_project_stack_blueprint_quality.sh"
  cp "$MODEL_SRC" "$asdlc_root/.setup/models.md"
  cp "$EXTERNAL_SOURCES_SRC" "$asdlc_root/.setup/external_sources.yaml"
  cp "$SOURCE_ROOT/overmind/templates/project_stack_blueprint_be_TEMPLATE.md" "$asdlc_root/.templates/project_stack_blueprint_be_TEMPLATE.md"
  cp "$SOURCE_ROOT/overmind/templates/project_stack_blueprint_fe_TEMPLATE.md" "$asdlc_root/.templates/project_stack_blueprint_fe_TEMPLATE.md"
  cp "$SOURCE_ROOT/overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md" "$asdlc_root/.templates/project_stack_blueprint_mobile_TEMPLATE.md"
  cp "$SOURCE_ROOT/overmind/golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md" "$asdlc_root/.golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md"
  cp "$SOURCE_ROOT/overmind/golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md" "$asdlc_root/.golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md"
  cp "$SOURCE_ROOT/overmind/golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md" "$asdlc_root/.golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
  chmod +x "$asdlc_root/.commands/init_project_stack_blueprints.sh" "$asdlc_root/.helper/check_project_stack_blueprint_quality.sh"

  cat >"$asdlc_root/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "staged command test"
projects:
OUT

  (
    cd "$asdlc_root"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    git add .
    git commit -qm "seed staged workspace"
  )
}

write_project_definition() {
  local project_dir="$1"
  local project_type_code="$2"

  mkdir -p "$project_dir"
  cat >"$project_dir/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_id: "sample-project"
  project_classes:
    - backend
    - frontend
  project_type_code: "$project_type_code"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
    frontend:
      state: "deferred"
      path: ""

steps: []
EOF_DEF
  git -C "$(cd "$project_dir/../.." && pwd)" add "projects/$(basename "$project_dir")/init_progress_definition.yaml"
  git -C "$(cd "$project_dir/../.." && pwd)" commit -qm "seed project"
}

setup_codex_stub() {
  local asdlc_root="$1"
  local mode="$2"
  mkdir -p "$asdlc_root/bin"
  cat >"$asdlc_root/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
mode="${TEST_CODEX_MODE:?TEST_CODEX_MODE must be set}"
prompt="${!#}"
printf '%s' "$prompt" >"$capture_dir/codex_prompt.txt"

case "$mode" in
no-write)
  exit 0
  ;;
invalid)
  target="${TARGET_BACKEND_BLUEPRINT:?TARGET_BACKEND_BLUEPRINT must be set}"
  cat >"$target" <<'DOC'
# Project Stack Blueprint - Backend

## 1. Meta
- class: backend
- last_updated: [UNFILLED]

## 2. Approved Stack Family
- stack_family: [UNFILLED]
DOC
  ;;
valid)
  backend_target="${TARGET_BACKEND_BLUEPRINT:?TARGET_BACKEND_BLUEPRINT must be set}"
  frontend_target="${TARGET_FRONTEND_BLUEPRINT:?TARGET_FRONTEND_BLUEPRINT must be set}"
  cat >"$backend_target" <<'DOC'
# Project Stack Blueprint - Backend

## 1. Meta
- class: backend
- repo_name: sample-backend
- service_name: sample-api
- planned_repo_path: /planned/sample-backend (planned)
- group_id: com.example.sample
- last_updated: 2026-04-26

## 2. Stack Choices
- language: Java 21
- framework: Spring Boot 3.2
- build: Gradle
- rdbms: Postgres 16
- migrations: Liquibase
- async_messaging: none
- http_clients: Spring RestClient
- auth: JWT with Spring Security
- logging: Logback JSON
- metrics: Micrometer
- tracing: OpenTelemetry
- health: /actuator/health
- deployment: Docker
- test_stack: JUnit 5, Testcontainers

## 3. Layer Bindings

### 3.1 API
- folder_paths: src/main/java/{group}/api
- archetypes: Controller, RequestDto, ResponseDto
- user_reachable_pattern: METHOD /api/v{n}/<resource>

### 3.2 Service
- folder_paths: src/main/java/{group}/service
- archetypes: ApplicationService
- user_reachable_pattern: none

### 3.3 Domain
- folder_paths: src/main/java/{group}/domain
- archetypes: Entity, ValueObject
- user_reachable_pattern: none

### 3.4 Persistence
- folder_paths: src/main/java/{group}/repository
- archetypes: JpaRepository
- user_reachable_pattern: none

### 3.5 Integration
- folder_paths: src/main/java/{group}/integration
- archetypes: VendorClient
- topics_convention: none
- user_reachable_pattern: none

### 3.6 Runtime / Ops
- folder_paths: src/main/java/{group}/config
- archetypes: SecurityConfig, application.yaml
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src/test/java/{group}
- archetypes: UnitTest, IntegrationTest
- user_reachable_pattern: none
DOC
  cat >"$frontend_target" <<'DOC'
# Project Stack Blueprint - Frontend

## 1. Meta
- class: frontend
- repo_name: sample-frontend
- service_name: sample-web
- planned_repo_path: /planned/sample-frontend (planned)
- group_id_or_package_root: src
- last_updated: 2026-04-26

## 2. Stack Choices
- framework: React 18 + Vite
- router: react-router v6
- state: React Query
- http: fetch wrapper in src/api/client.ts
- styling: CSS modules
- auth_client: JWT in sessionStorage
- env_validation: zod
- deployment: static bundle
- test: Vitest + Playwright

## 3. Layer Bindings

### 3.1 UI Composition
- folder_paths: src/routes, src/pages
- archetypes: RouterDefinition, PageComponent
- user_reachable_pattern: /<route>

### 3.2 Component
- folder_paths: src/components
- archetypes: SharedComponent
- user_reachable_pattern: none

### 3.3 State / Data
- folder_paths: src/hooks, src/state
- archetypes: ReactQueryHook
- user_reachable_pattern: none

### 3.4 API Integration
- folder_paths: src/api
- archetypes: ApiClient
- user_reachable_pattern: none

### 3.5 UX Behavior
- folder_paths: src/pages, src/components
- archetypes: LoadingState, ErrorBoundary
- user_reachable_pattern: none

### 3.6 Platform / Runtime
- folder_paths: src/main.tsx, src/config
- archetypes: Bootstrap, EnvParser
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src, test
- archetypes: UnitTest, E2ETest
- user_reachable_pattern: none
DOC
  ;;
revision)
  backend_target="${TARGET_BACKEND_BLUEPRINT:?TARGET_BACKEND_BLUEPRINT must be set}"
  frontend_target="${TARGET_FRONTEND_BLUEPRINT:?TARGET_FRONTEND_BLUEPRINT must be set}"
  cat >"$backend_target" <<'DOC'
# Project Stack Blueprint - Backend

## 1. Meta
- class: backend
- repo_name: sample-backend
- service_name: sample-api
- planned_repo_path: /planned/sample-backend (planned)
- group_id: com.example.sample
- last_updated: 2026-04-26

## 2. Stack Choices
- language: Node.js 22
- framework: NestJS
- build: pnpm
- rdbms: Postgres 16
- migrations: Prisma Migrate
- async_messaging: none
- http_clients: fetch
- auth: JWT middleware
- logging: pino
- metrics: prom-client
- tracing: OpenTelemetry
- health: /health
- deployment: Docker
- test_stack: Jest, Testcontainers

## 3. Layer Bindings

### 3.1 API
- folder_paths: src/api
- archetypes: Controller, RequestDto, ResponseDto
- user_reachable_pattern: METHOD /api/v{n}/<resource>

### 3.2 Service
- folder_paths: src/service
- archetypes: Service
- user_reachable_pattern: none

### 3.3 Domain
- folder_paths: src/domain
- archetypes: Entity, ValueObject
- user_reachable_pattern: none

### 3.4 Persistence
- folder_paths: src/repository, prisma
- archetypes: Repository, Prisma model
- user_reachable_pattern: none

### 3.5 Integration
- folder_paths: src/integration
- archetypes: VendorClient
- topics_convention: none
- user_reachable_pattern: none

### 3.6 Runtime / Ops
- folder_paths: src/config
- archetypes: ConfigModule, Dockerfile
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: test
- archetypes: UnitTest, E2ETest
- user_reachable_pattern: none
DOC
  cat >"$frontend_target" <<'DOC'
# Project Stack Blueprint - Frontend

## 1. Meta
- class: frontend
- repo_name: sample-frontend
- service_name: sample-web
- planned_repo_path: /planned/sample-frontend (planned)
- group_id_or_package_root: src
- last_updated: 2026-04-26

## 2. Stack Choices
- framework: Angular
- router: Angular Router
- state: NgRx
- http: Angular HttpClient
- styling: SCSS design tokens
- auth_client: JWT in sessionStorage
- env_validation: typed environment config
- deployment: static bundle
- test: Jasmine + Playwright

## 3. Layer Bindings

### 3.1 UI Composition
- folder_paths: src/app/routes, src/app/pages
- archetypes: RouteConfig, PageComponent
- user_reachable_pattern: /<route>

### 3.2 Component
- folder_paths: src/app/components
- archetypes: SharedComponent
- user_reachable_pattern: none

### 3.3 State / Data
- folder_paths: src/app/state
- archetypes: Store, Selector
- user_reachable_pattern: none

### 3.4 API Integration
- folder_paths: src/app/api
- archetypes: ApiService
- user_reachable_pattern: none

### 3.5 UX Behavior
- folder_paths: src/app/pages, src/app/components
- archetypes: LoadingState, ErrorPresenter
- user_reachable_pattern: none

### 3.6 Platform / Runtime
- folder_paths: src/main.ts, src/environments
- archetypes: Bootstrap, EnvConfig
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src, e2e
- archetypes: UnitTest, E2ETest
- user_reachable_pattern: none
DOC
  ;;
*)
  echo "unknown TEST_CODEX_MODE: $mode" >&2
  exit 2
  ;;
esac
OUT
  chmod +x "$asdlc_root/bin/codex"
  TEST_CODEX_MODE="$mode"
}

test_noops_for_type_b_and_c() {
  local asdlc_root="$TMP_ROOT/asdlc-noop"
  local project_b="$asdlc_root/projects/type-b"
  local project_c="$asdlc_root/projects/type-c"
  setup_staged_workspace "$asdlc_root"
  write_project_definition "$project_b" "B"
  write_project_definition "$project_c" "C"

  local out_b=""
  local out_c=""
  out_b="$("$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_b")"
  out_c="$("$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_c")"

  assert_contains "$out_b" "Project type B does not require stack blueprints; Step 1.1 no-op."
  assert_contains "$out_c" "Project type C does not require stack blueprints; Step 1.1 no-op."
  assert_file_not_exists "$project_b/project_stack_blueprint_backend.md"
  assert_file_not_exists "$project_c/project_stack_blueprint_backend.md"
}

test_prompt_includes_external_sources_context() {
  local asdlc_root="$TMP_ROOT/asdlc-prompt"
  local project_dir="$asdlc_root/projects/sample-project"
  local capture_dir="$TMP_ROOT/capture-prompt"
  mkdir -p "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  write_project_definition "$project_dir" "A"
  setup_codex_stub "$asdlc_root" "valid"

  TEST_CAPTURE_DIR="$capture_dir" TEST_CODEX_MODE="valid" PATH="$asdlc_root/bin:$PATH" \
    TARGET_BACKEND_BLUEPRINT="$project_dir/project_stack_blueprint_backend.md" \
    TARGET_FRONTEND_BLUEPRINT="$project_dir/project_stack_blueprint_frontend.md" \
    "$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_dir" >/dev/null

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" "external_sources.yaml (present)"
  assert_contains "$prompt" "project_stack_blueprint_rule.md"
  assert_contains "$prompt" "Project stack blueprint phase is finished"
}

test_missing_external_sources_file_fails_fast() {
  local asdlc_root="$TMP_ROOT/asdlc-missing-external-sources"
  local project_dir="$asdlc_root/projects/sample-project"
  setup_staged_workspace "$asdlc_root"
  write_project_definition "$project_dir" "A"
  rm -f "$asdlc_root/.setup/external_sources.yaml"

  local status=0
  local out=""
  set +e
  out="$("$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_dir" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .setup/external_sources.yaml"
}

test_no_final_write_before_approval_keeps_blueprint_missing() {
  local asdlc_root="$TMP_ROOT/asdlc-no-write"
  local project_dir="$asdlc_root/projects/sample-project"
  local capture_dir="$TMP_ROOT/capture-no-write"
  mkdir -p "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  write_project_definition "$project_dir" "A"
  setup_codex_stub "$asdlc_root" "no-write"

  local status=0
  local out=""
  set +e
  out="$(
    TEST_CAPTURE_DIR="$capture_dir" TEST_CODEX_MODE="no-write" PATH="$asdlc_root/bin:$PATH" \
      "$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_dir" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_file_not_exists "$project_dir/project_stack_blueprint_backend.md"
}

test_revision_uses_same_validation_and_commits() {
  local asdlc_root="$TMP_ROOT/asdlc-revision"
  local project_dir="$asdlc_root/projects/sample-project"
  local capture_dir="$TMP_ROOT/capture-revision"
  mkdir -p "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  write_project_definition "$project_dir" "A"
  setup_codex_stub "$asdlc_root" "valid"

  TEST_CAPTURE_DIR="$capture_dir" TEST_CODEX_MODE="valid" PATH="$asdlc_root/bin:$PATH" \
    TARGET_BACKEND_BLUEPRINT="$project_dir/project_stack_blueprint_backend.md" \
    TARGET_FRONTEND_BLUEPRINT="$project_dir/project_stack_blueprint_frontend.md" \
    "$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_dir" >/dev/null

  setup_codex_stub "$asdlc_root" "revision"
  TEST_CAPTURE_DIR="$capture_dir" TEST_CODEX_MODE="revision" PATH="$asdlc_root/bin:$PATH" \
    TARGET_BACKEND_BLUEPRINT="$project_dir/project_stack_blueprint_backend.md" \
    TARGET_FRONTEND_BLUEPRINT="$project_dir/project_stack_blueprint_frontend.md" \
    "$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_dir" >/dev/null

  local backend_content=""
  backend_content="$(cat "$project_dir/project_stack_blueprint_backend.md")"
  assert_contains "$backend_content" "language: Node.js 22"
  assert_equal "Update project stack blueprints for sample-project" "$(git -C "$asdlc_root" log -1 --pretty=%s)"
}

test_final_blueprint_contains_gap5_structure_without_authoring_state() {
  local asdlc_root="$TMP_ROOT/asdlc-prohibited"
  local project_dir="$asdlc_root/projects/sample-project"
  local capture_dir="$TMP_ROOT/capture-prohibited"
  mkdir -p "$capture_dir"
  setup_staged_workspace "$asdlc_root"
  write_project_definition "$project_dir" "A"
  setup_codex_stub "$asdlc_root" "valid"

  TEST_CAPTURE_DIR="$capture_dir" TEST_CODEX_MODE="valid" PATH="$asdlc_root/bin:$PATH" \
    TARGET_BACKEND_BLUEPRINT="$project_dir/project_stack_blueprint_backend.md" \
    TARGET_FRONTEND_BLUEPRINT="$project_dir/project_stack_blueprint_frontend.md" \
    "$asdlc_root/.commands/init_project_stack_blueprints.sh" --path "$project_dir" >/dev/null

  local blueprint_content=""
  blueprint_content="$(cat "$project_dir/project_stack_blueprint_backend.md")"
  assert_contains "$blueprint_content" "## 2. Stack Choices"
  assert_contains "$blueprint_content" "## 3. Layer Bindings"
  assert_contains "$blueprint_content" "- folder_paths:"
  assert_contains "$blueprint_content" "- archetypes:"
  assert_not_contains "$blueprint_content" "approval"
  assert_not_contains "$blueprint_content" "proposal"
}

test_noops_for_type_b_and_c
test_prompt_includes_external_sources_context
test_missing_external_sources_file_fails_fast
test_no_final_write_before_approval_keeps_blueprint_missing
test_revision_uses_same_validation_and_commits
test_final_blueprint_contains_gap5_structure_without_authoring_state

echo "All project stack blueprint initializer tests passed."
