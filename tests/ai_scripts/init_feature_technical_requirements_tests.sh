#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_technical_requirements.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/technical_requirements_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/technical_requirements_TEMPLATE.md"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md"

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
    echo "Assertion failed: expected output to NOT contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
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

assert_nonzero_status() {
  local status="$1"
  if [[ "$status" -eq 0 ]]; then
    echo "Assertion failed: expected non-zero status" >&2
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

setup_workspace_layout() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.templates" \
    "$repo_dir/asdlc/.golden_examples" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_technical_requirements.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/technical_requirements_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/technical_requirements_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/technical_requirements_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_technical_requirements.sh"

  cat >"$repo_dir/asdlc/.helper/check_feature_technical_requirements_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_feature_technical_requirements_quality.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT
}

setup_models_file() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
feature_technical_requirements | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
}

seed_project_definition() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
steps: []
OUT
}

seed_feature_sources() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  mkdir -p "$repo_dir/asdlc/$feature_path"

  cat >"$repo_dir/asdlc/$feature_path/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 — Create order
**User Story:** As a user, I want to create an order, so that work can start.

**Acceptance Criteria (EARS):**
- WHEN a user creates an order, THE System SHALL persist the order.

**Verification:** API and persistence tests.
OUT

  cat >"$repo_dir/asdlc/projects/p1/common_contract_definition.md" <<'OUT'
# Common Contract Definition

## 1. Document Meta
- project_id: p1
- project_path: /tmp/asdlc/projects/p1
- source_repo_count: 2
- source_repositories: backend, frontend
- last_updated: 2026-04-10
- confidence_level: medium

## 2. Source Repository Evidence
### Repository: backend
- class: backend
- repo_path: /tmp/backend
- contract_evidence_summary: Backend is the source of truth for synchronous order contracts.
- key_surfaces_reviewed: POST /api/v1/orders
- notes: Keep success DTO fields stable.

### Repository: frontend
- class: frontend
- repo_path: /tmp/frontend
- contract_evidence_summary: Frontend consumes backend order-creation responses.
- key_surfaces_reviewed: src/api/orders.ts
- notes: Client must align to backend field names.

## 3. Common Contract Baseline
### Contract: order-create
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: backend
- consumer_repositories: frontend
- contract_surface: POST /api/v1/orders
- contract_status: drifted
- source_of_truth: backend order create controller
- canonical_shape: request:{name}; response:{id,status}
- shared_types: OrderId, OrderStatus
- trust_boundary: internal
- compatibility_rule: additive fields allowed; removing required fields is breaking
- planning_implication: contract delta likely required before downstream client lock
- notes: Frontend follows backend response shape.

## 4. Reconciliation Decisions
- decision_1: Backend request and response payloads remain canonical for the order-create flow.

## 5. Known Risks / Uncertainties
- uncertainty_1: None currently identified for this fixture.

## 6. Common Planning Signals
- prep_1: Keep backend and frontend client payload mapping aligned.
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_backend.md" <<'OUT'
# Project Surface Structure + Responsibility Map (Backend)

## 3. Key Parts of Repo and Their Responsibilities
### 3.1 API Layer
- responsibility_summary: backend api

## 4. Backend Surfaces Touched With Current Feature
### 4.1 API Surface
- applicability: applicable
- repo_paths: /tmp/backend/src/main/java/com/example/api/OrderController.java
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_frontend.md" <<'OUT'
# Project Surface Structure + Responsibility Map (Frontend)

## 3. Key Parts of Repo and Their Responsibilities
### 3.1 UI Layer
- responsibility_summary: frontend ui

## 4. Frontend / Mobile Surfaces Touched With Current Feature
### 4.1 API Integration Surface
- applicability: applicable
- repo_paths: /tmp/frontend/src/api/orders.ts
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_TECHNICAL_REQUIREMENTS_FILE:-projects/p1/feature-a/technical_requirements.md}"
project_type_code="${TEST_PROJECT_TYPE_CODE:-B}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'DOC'
# Technical Requirements

## 1. Document Meta
- feature_id: AA-1
- feature_title: create-order
- project_type_code: PROJECT_TYPE_CODE_PLACEHOLDER
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md, projects/p1/feature-a/project_surface_struct_resp_map_frontend.md
- analyzed_repo_classes: backend, frontend
- last_updated: 2026-04-10
- confidence_level: medium

## 2. Feature Scope and Inputs
- feature_summary: Order creation is partially implemented and requires final backend/frontend alignment.
- included_behavior: Create-order request handling and frontend client consumption are in scope.
- excluded_behavior: Mobile and unrelated admin flows are out of scope.

## 3. Repository Evidence
### Repository: backend
- class: backend
- evidence_scope: Reviewed order controller and service flow.
- primary_paths: /tmp/backend/src/main/java/com/example/api/OrderController.java
- key_findings: Backend create-order behavior exists but needs stronger validation coverage.
- constraints: Backend remains canonical for request and response fields.
- open_gaps: Validation semantics need to be finalized.

### Repository: frontend
- class: frontend
- evidence_scope: Reviewed frontend order client.
- primary_paths: /tmp/frontend/src/api/orders.ts
- key_findings: Frontend order client exists but still depends on backend contract stabilization.
- constraints: Frontend must adopt backend-owned field names.
- open_gaps: Final request/error mapping remains incomplete.

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- requirement_summary: Users can create orders successfully.
- current_state: Backend and frontend both contain partial order-create paths.
- gap_status: partially_implemented
- repo_impact: multiple
- evidence: Repo evidence shows partial create-order code in both repos.
- gap_to_close: Finalize backend validation and align frontend client mapping to the canonical contract.

## 5. Impacted Components
### Component: OrderController
- repo: backend
- component_kind: controller
- relevant_paths: /tmp/backend/src/main/java/com/example/api/OrderController.java
- requirement_refs: REQ-1
- current_state: Create-order endpoint exists but validation handling is incomplete.
- required_behavior: Accept valid requests and reject invalid ones consistently.
- gap_to_close: Add final validation/error behavior and tests.
- dependency_notes: Backend contract must stabilize before final frontend assertions.
- evidence: Backend surface map identifies the controller as applicable.

### Component: src/api/orders.ts
- repo: frontend
- component_kind: api_client
- relevant_paths: /tmp/frontend/src/api/orders.ts
- requirement_refs: REQ-1
- current_state: Client request path exists but backend-aligned mapping is incomplete.
- required_behavior: Submit canonical backend request fields and surface safe errors.
- gap_to_close: Finalize client request/response mapping and tests.
- dependency_notes: Frontend update depends on backend request/error stabilization.
- evidence: Frontend surface map identifies api integration as applicable.

## 6. Cross-Repo Constraints and Planning Signals
- planning_signals: none

## 7. Known Risks / Uncertainties
- risk_1: Backend/frontend drift may recur if frontend preserves proposal-only aliases.
DOC
sed -i.bak "s/PROJECT_TYPE_CODE_PLACEHOLDER/$project_type_code/g" "$target_file"
rm -f "$target_file.bak"
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_git_workspace() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  seed_project_definition "$repo_dir"
  seed_feature_sources "$repo_dir"

  (
    cd "$repo_dir/asdlc"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "seed" >README.md
    git add .
    git commit -qm "seed"
  )
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_technical_requirements.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_technical_requirements.sh" "$repo_dir/feature_technical_requirements.sh"
  chmod +x "$repo_dir/feature_technical_requirements.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_technical_requirements.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_required_common_contract_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-common-contract"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/common_contract_definition.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_technical_requirements.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/common_contract_definition.md"
}

test_fails_when_model_phase_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-model"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
feature_contract_delta | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_technical_requirements.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'feature_technical_requirements' entry"
}

test_generates_technical_requirements_and_builds_expected_prompt() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/repo-success-capture"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local requirements_before=""
  local common_contract_before=""
  local backend_before=""
  local frontend_before=""
  requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  common_contract_before="$(cat "$repo_dir/asdlc/projects/p1/common_contract_definition.md")"
  backend_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_backend.md")"
  frontend_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md")"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_technical_requirements.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/technical_requirements.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")" "- planning_signals: none"
  assert_not_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")" "- constraint_1:"
  assert_not_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")" "- prep_1:"
  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$common_contract_before" "$(cat "$repo_dir/asdlc/projects/p1/common_contract_definition.md")"
  assert_equal "$backend_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_backend.md")"
  assert_equal "$frontend_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md")"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/technical_requirements_rule.md"
  assert_contains "$codex_prompt" "Target artifact: projects/p1/feature-a/technical_requirements.md"
  assert_contains "$codex_prompt" "Use projects/p1/common_contract_definition.md as the stable shared-contract baseline"
  assert_contains "$codex_prompt" "Use the applicable surface maps as the starting index and primary source for feature-scoped repository/class context."
  assert_contains "$codex_prompt" "Inspect other available evidence only where needed to confirm current behavior or gaps"
  assert_contains "$codex_prompt" "Produce one shared \`technical_requirements.md\` artifact"
  assert_contains "$codex_prompt" "project_surface_struct_resp_map_backend.md"
  assert_contains "$codex_prompt" "project_surface_struct_resp_map_frontend.md"
  assert_contains "$codex_prompt" "check_feature_technical_requirements_quality.sh projects/p1/feature-a/technical_requirements.md"

  local committed_files=""
  committed_files="$(cd "$repo_dir/asdlc" && git show --pretty='' --name-only HEAD)"
  assert_contains "$committed_files" "projects/p1/feature-a/technical_requirements.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/requirements_ears.md"
  assert_not_contains "$committed_files" "projects/p1/common_contract_definition.md"
}

test_type_a_generates_technical_requirements_from_surface_map_first_prompting() {
  local repo_dir="$TMP_ROOT/repo-type-a-success"
  local capture_dir="$TMP_ROOT/repo-type-a-capture"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
  project_type_code: "A"
  project_type_label: "New project"
steps: []
OUT

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_PROJECT_TYPE_CODE="A" \
      .commands/feature_technical_requirements.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/technical_requirements.md"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")" "- project_type_code: A"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Project type code: A"
  assert_contains "$codex_prompt" "Use the applicable surface maps as the starting index and primary source for feature-scoped repository/class context."
  assert_contains "$codex_prompt" "Inspect other available evidence only where needed to confirm current behavior or gaps"
  assert_contains "$codex_prompt" "Do not present non-code, planned, or derived evidence as already implemented code."
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_required_common_contract_is_missing
test_fails_when_model_phase_missing
test_generates_technical_requirements_and_builds_expected_prompt
test_type_a_generates_technical_requirements_from_surface_map_first_prompting
