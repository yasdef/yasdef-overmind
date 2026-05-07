#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_feature_technical_requirements_quality.sh"

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

assert_equal() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

setup_repo_with_helper() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/overmind/scripts/helper"
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_feature_technical_requirements_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_feature_technical_requirements_quality.sh"
  echo "seed" >"$repo_dir/README.md"
}

write_project_definition() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/projects/p1"
  cat >"$repo_dir/projects/p1/init_progress_definition.yaml" <<'OUT'
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

write_requirements() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  cat >"$repo_dir/projects/p1/feature-a/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 — Create order
**User Story:** As a user, I want to create an order, so that it can be processed.

**Acceptance Criteria (EARS):**
- WHEN a user creates an order, THE System SHALL persist the order.

**Verification:** API tests.

## Non-Functional Requirements

### NFR 1 — Core latency
**User Story:** As a user, I want the response to stay quick, so that the flow remains usable.

**Acceptance Criteria (EARS):**
- WHERE the system is under normal load, THE System SHALL respond within the target latency budget.

**Verification:** Performance evidence.
OUT
}

write_surface_maps() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/project_surface_struct_resp_map_backend.md" <<'OUT'
# Backend Surface Map

## 4. Backend Surfaces Touched With Current Feature
### 4.1 API Surface
- applicability: applicable
OUT

  cat >"$repo_dir/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md" <<'OUT'
# Frontend Surface Map

## 4. Frontend / Mobile Surfaces Touched With Current Feature
### 4.1 API Integration Surface
- applicability: applicable
OUT
}

write_valid_technical_requirements() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/technical_requirements.md" <<'OUT'
# Technical Requirements

## 1. Document Meta
- feature_id: AA-1
- feature_title: create-order
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md, projects/p1/feature-a/project_surface_struct_resp_map_frontend.md
- analyzed_repo_classes: backend, frontend
- last_updated: 2026-04-10
- confidence_level: medium

## 2. Feature Scope and Inputs
- feature_summary: This feature adds order creation across backend and frontend while preserving the current API boundary.
- included_behavior: Order creation, validation, and user-facing client consumption are in scope.
- excluded_behavior: Mobile and unrelated admin flows stay out of scope.

## 3. Repository Evidence
### Repository: backend
- class: backend
- evidence_scope: Reviewed backend controller, service, persistence, and tests used for order creation.
- primary_paths: src/main/java/com/example/api, src/main/java/com/example/service, src/test/java/com/example
- key_findings: Backend create-order flow is partially implemented and still needs stronger validation/error coverage.
- constraints: Keep backend-owned request and response fields stable for clients.
- open_gaps: Validation and persistence failure semantics are not fully covered.

### Repository: frontend
- class: frontend
- evidence_scope: Reviewed frontend API client and page modules used for order creation.
- primary_paths: src/api, src/pages
- key_findings: Frontend has a draft client path but is not fully aligned with backend validation semantics.
- constraints: Frontend must consume backend-owned field names and safe error messages.
- open_gaps: Final error mapping and request-shape alignment remain incomplete.

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- requirement_summary: Users can create orders successfully.
- transport_layer: OrderController, OrderService, OrderRepository
- user_reachable_surface: POST /api/v1/orders
- gap_status: partially_implemented
- repo_impact: multiple
- evidence: Current repo evidence shows create-order flow code exists in both repos but needs alignment.
- gap_to_close: Complete backend validation and finalize frontend client mapping for the create-order flow.

### Requirement: NFR-1
- requirement_summary: Core latency remains within the target budget.
- transport_layer: none
- user_reachable_surface: none
- gap_status: unclear
- repo_impact: backend
- evidence: Current inputs focus on functional behavior and do not provide latency evidence for the new flow.
- gap_to_close: Confirm whether dedicated performance verification is required for this feature.

## 5. Impacted Components
### Component: OrderController
- repo: backend
- component_kind: controller
- relevant_paths: src/main/java/com/example/api/OrderController.java
- requirement_refs: REQ-1
- current_state: Create-order endpoint exists but validation/error semantics are incomplete.
- required_behavior: Persist valid order requests and reject invalid requests consistently.
- gap_to_close: Add final validation/error handling and corresponding tests.
- dependency_notes: Backend error semantics should stabilize before downstream frontend assertions are finalized.
- evidence: Backend surface map and repository evidence both point to this endpoint as in scope.

### Component: src/api/orders.ts
- repo: frontend
- component_kind: api_client
- relevant_paths: src/api/orders.ts, src/pages/CreateOrderPage.tsx
- requirement_refs: REQ-1, NFR-1
- current_state: Client request wiring exists but backend-aligned validation/error handling is incomplete.
- required_behavior: Submit backend-compatible requests and surface safe validation feedback to users.
- gap_to_close: Align request/response mapping with backend contract and extend client tests.
- dependency_notes: Frontend client updates depend on backend request/error shape stabilization.
- evidence: Frontend surface map identifies api integration as applicable and repo evidence confirms the partial client path.

## 6. Cross-Repo Constraints and Planning Signals
### Planning Signal: signal_1
- signal_id: signal_1
- signal_type: cross_repo_contract_lock
- owner_repo: backend
- consumer_repos: frontend
- required_artifact: feature_contract_delta.md
- must_precede: implementation_slices.md, implementation_plan.md
- output_requirements: Lock backend request/error fields before frontend finalizes client mapping.
- source_evidence: REQ-1, comp/ordercontroller, comp/src-api-orders-ts

## 7. Known Risks / Uncertainties
- risk_1: Backend/frontend drift may reappear if client aliases are preserved instead of adopting backend field names.
OUT
}

replace_section6_with_empty_marker() {
  local target_file="$1"
  perl -0pi -e 's@\n## 6\. Cross-Repo Constraints and Planning Signals.*?\n## 7\. Known Risks / Uncertainties@\n## 6. Cross-Repo Constraints and Planning Signals\n- planning_signals: none\n\n## 7. Known Risks / Uncertainties@s' "$target_file"
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_feature_technical_requirements_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

setup_valid_fixture() {
  local repo_dir="$1"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_project_definition "$repo_dir"
  write_requirements "$repo_dir"
  write_surface_maps "$repo_dir"
  write_valid_technical_requirements "$repo_dir"
}

test_passes_with_valid_feature_technical_requirements() {
  local repo_dir="$TMP_ROOT/repo-pass"
  setup_valid_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_target_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Target feature technical requirements artifact not found"
}

test_fails_when_target_is_empty() {
  local repo_dir="$TMP_ROOT/repo-empty-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  : >"$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "target feature technical requirements artifact is empty"
}

test_fails_when_requirement_block_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-requirement"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/\n### Requirement: NFR-1.*?\n## 5\./\n## 5\./s' "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "section 4 is missing requirement block for NFR-1"
}

test_fails_when_applicable_repo_has_no_component_block() {
  local repo_dir="$TMP_ROOT/repo-missing-frontend-component"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/\n### Component: src\/api\/orders\.ts.*$//s' "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "repo frontend has applicable touched surfaces but no impacted component block is allocated to it"
}

test_fails_when_requirement_missing_transport_layer() {
  local repo_dir="$TMP_ROOT/repo-missing-transport-layer"
  setup_valid_fixture "$repo_dir"
  sed -i.bak 's/- transport_layer: OrderController, OrderService, OrderRepository//' \
    "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "REQ-1"
  assert_contains "$out" "transport_layer"
}

test_fails_when_requirement_missing_user_reachable_surface() {
  local repo_dir="$TMP_ROOT/repo-missing-user-reachable"
  setup_valid_fixture "$repo_dir"
  sed -i.bak 's/- user_reachable_surface: POST \/api\/v1\/orders//' \
    "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "REQ-1"
  assert_contains "$out" "user_reachable_surface"
}

test_fails_when_requirement_uses_conflated_current_state() {
  local repo_dir="$TMP_ROOT/repo-conflated-current-state"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- transport_layer: OrderController, OrderService, OrderRepository\n- user_reachable_surface: POST \/api\/v1\/orders/- current_state: Backend and frontend both contain partial order-create paths./g' \
    "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "conflated current_state"
}

test_passes_when_user_reachable_surface_is_none() {
  local repo_dir="$TMP_ROOT/repo-none-user-reachable"
  setup_valid_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_empty_marker_for_multi_repo_feature() {
  local repo_dir="$TMP_ROOT/repo-empty-marker"
  setup_valid_fixture "$repo_dir"
  replace_section6_with_empty_marker "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_with_unsupported_signal_type() {
  local repo_dir="$TMP_ROOT/repo-unsupported-signal-type"
  setup_valid_fixture "$repo_dir"
  sed -i.bak 's/signal_type: cross_repo_contract_lock/signal_type: cross_repo_dependency_hint/' \
    "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "unsupported signal_type"
}

test_fails_with_duplicate_signal_id() {
  local repo_dir="$TMP_ROOT/repo-duplicate-signal-id"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's@\n## 7\. Known Risks / Uncertainties@\n### Planning Signal: signal_2\n- signal_id: signal_1\n- signal_type: cross_repo_contract_lock\n- owner_repo: backend\n- consumer_repos: frontend\n- required_artifact: feature_contract_delta.md\n- must_precede: implementation_plan.md\n- output_requirements: Keep backend request/error fields canonical.\n- source_evidence: REQ-1, comp/ordercontroller\n\n## 7. Known Risks / Uncertainties@s' "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "duplicate planning signal id"
}

test_fails_with_unresolved_source_evidence() {
  local repo_dir="$TMP_ROOT/repo-unresolved-signal-evidence"
  setup_valid_fixture "$repo_dir"
  sed -i.bak 's/source_evidence: REQ-1, comp\/ordercontroller, comp\/src-api-orders-ts/source_evidence: REQ-1, comp\/missing-component/' \
    "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "unknown source_evidence token"
}

test_fails_with_invalid_repo_ownership() {
  local repo_dir="$TMP_ROOT/repo-invalid-signal-repo"
  setup_valid_fixture "$repo_dir"
  sed -i.bak 's/owner_repo: backend/owner_repo: ops/' \
    "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "owner_repo"
  assert_contains "$out" "outside active project classes"
}

test_fails_with_legacy_section6_entries() {
  local repo_dir="$TMP_ROOT/repo-legacy-section6"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's@\n## 6\. Cross-Repo Constraints and Planning Signals.*?\n## 7\. Known Risks / Uncertainties@\n## 6. Cross-Repo Constraints and Planning Signals\n- constraint_1: Backend remains canonical.\n- prep_1: Finalize backend first.\n\n## 7. Known Risks / Uncertainties@s' "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/technical_requirements.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "retired loose-entry format"
}

test_passes_with_valid_feature_technical_requirements
test_fails_when_target_missing
test_fails_when_target_is_empty
test_fails_when_requirement_block_is_missing
test_fails_when_applicable_repo_has_no_component_block
test_fails_when_requirement_missing_transport_layer
test_fails_when_requirement_missing_user_reachable_surface
test_fails_when_requirement_uses_conflated_current_state
test_passes_when_user_reachable_surface_is_none
test_passes_with_empty_marker_for_multi_repo_feature
test_fails_with_unsupported_signal_type
test_fails_with_duplicate_signal_id
test_fails_with_unresolved_source_evidence
test_fails_with_invalid_repo_ownership
test_fails_with_legacy_section6_entries
