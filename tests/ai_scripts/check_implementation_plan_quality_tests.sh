#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_implementation_plan_quality.sh"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_implementation_plan_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_implementation_plan_quality.sh"
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
    - mobile
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

### Requirement 4 — Order creation
**User Story:** As a user, I want to create an order, so that work can start.

**Acceptance Criteria (EARS):**
- WHEN a user creates an order, THE System SHALL persist the order.

**Verification:** API and persistence tests.

### Requirement 6 — Order query
**User Story:** As a user, I want to query orders, so that I can see them.

**Acceptance Criteria (EARS):**
- WHEN a user queries orders, THE System SHALL return the matching order projection.

**Verification:** Query endpoint tests.

### Requirement 7 — Projection consistency
**User Story:** As an operator, I want order projections to stay consistent, so that reads remain correct.

**Acceptance Criteria (EARS):**
- WHEN order state changes, THE System SHALL rebuild projections deterministically.

**Verification:** Projection rebuild tests.

### NFR 1 — Query latency
**Goal:** Projection-backed order queries stay within the expected latency budget.

**Acceptance Criteria (EARS):**
- WHEN a user queries orders under normal operating conditions, THE System SHALL respond within the agreed latency budget.

**Verification:** Latency-focused verification.
OUT
}

write_technical_requirements() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/technical_requirements.md" <<'OUT'
# Technical Requirements

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- source_surface_map_artifacts: upstream-only
- analyzed_repo_classes: backend, frontend, mobile
- last_updated: 2026-04-10
- confidence_level: medium

## 2. Feature Scope and Inputs
- feature_summary: complete projection-backed order flow
- included_behavior: backend query completion plus frontend/mobile projection consumers
- excluded_behavior: unrelated order editing

## 3. Repository Evidence
### Repository: backend
- class: backend
- evidence_scope: backend query and projection persistence
- primary_paths: src/backend/order
- key_findings: backend projection persistence exists, query path remains incomplete
- constraints: backend response shape stays canonical
- open_gaps: query controller wiring and tests remain

### Repository: frontend
- class: frontend
- evidence_scope: frontend order client
- primary_paths: src/frontend/order
- key_findings: frontend client ignores projection status fields
- constraints: frontend follows backend payload
- open_gaps: adapter and UI state updates remain

### Repository: mobile
- class: mobile
- evidence_scope: mobile order client
- primary_paths: src/mobile/order
- key_findings: mobile client ignores projection status fields
- constraints: mobile follows backend payload
- open_gaps: mapper and view-model updates remain

## 4. Requirement Coverage and Gaps
### Requirement: REQ-4
- requirement_summary: create orders
- current_state: clients need projection-backed status support
- gap_status: partially_implemented
- repo_impact: multiple
- evidence: backend create flow exists; clients lag
- gap_to_close: finish client mapping and state handling

### Requirement: REQ-6
- requirement_summary: query orders
- current_state: backend read path remains incomplete
- gap_status: partially_implemented
- repo_impact: backend
- evidence: partial query wiring only
- gap_to_close: finish read service, controller mapping, and tests

### Requirement: REQ-7
- requirement_summary: rebuild projections
- current_state: backend rebuild exists
- gap_status: fully_implemented
- repo_impact: backend
- evidence: rebuild coverage is present
- gap_to_close: no remaining gap

### Requirement: NFR-1
- requirement_summary: query latency budget
- current_state: backend query flow exists but feature-specific latency verification is incomplete
- gap_status: unclear
- repo_impact: backend
- evidence: query path behavior is covered functionally, but latency verification is not yet recorded for this feature
- gap_to_close: add latency-focused verification for projection-backed order queries

## 5. Impacted Components
### Component: backend projection persistence
- repo: backend
- component_kind: persistence
- relevant_paths: src/backend/order/projection
- requirement_refs: REQ-6, REQ-7
- current_state: persistence slice already implemented
- required_behavior: keep persisted projection shape stable for consumers
- gap_to_close: no remaining gap
- dependency_notes: client work depends on this existing shape
- evidence: existing projection repository and tests

### Component: frontend order projection client
- repo: frontend
- component_kind: api_client
- relevant_paths: src/frontend/order/orders.ts
- requirement_refs: REQ-4, REQ-6
- current_state: frontend mapper is incomplete
- required_behavior: map projection-backed status fields
- gap_to_close: adapter, UI state, and tests
- dependency_notes: depends on backend projection persistence
- evidence: adapter ignores projection fields

### Component: mobile order projection client
- repo: mobile
- component_kind: api_client
- relevant_paths: src/mobile/order/orders.ts
- requirement_refs: REQ-4, REQ-6
- current_state: mobile mapper is incomplete
- required_behavior: map projection-backed status fields
- gap_to_close: mapper, view model, and tests
- dependency_notes: depends on backend projection persistence
- evidence: mobile mapper ignores projection fields

## 6. Cross-Repo Constraints and Planning Signals
- constraint_1: backend projection payload remains canonical
- prep_1: represent existing backend foundation before client follow-up work

## 7. Known Risks / Uncertainties
- risk_1: frontend and mobile may use different local names for projection status
OUT
}

write_valid_plan() {
  local repo_dir="$1"
  cp "$GOLDEN_SRC" "$repo_dir/projects/p1/feature-a/implementation_plan.md"
}

write_prerequisite_gaps() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 1. Document Meta
- feature_id: ORD-42
- last_updated: 2026-04-10

## 2. Prerequisite Trace

### Requirement: REQ-4
- requirement_summary: Order creation
- prerequisites: none

### Requirement: REQ-6
- requirement_summary: Query orders
- prerequisites: none

### Requirement: REQ-7
- requirement_summary: Rebuild projections
- prerequisites: none

### Requirement: NFR-1
- requirement_summary: Query latency
- prerequisites: none
OUT
}

write_required_operator_surface_prerequisite_gaps() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-4
- requirement_summary: Order creation
- prerequisites: see entries below

#### Prerequisite: Operator login page
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator login page
- evidence: Slice slice-10 delivers login surface.
- slice_ref: slice-10

### Requirement: REQ-6
- requirement_summary: Query orders
- prerequisites: see entries below

#### Prerequisite: Protected operator workspace shell
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Protected operator workspace shell
- evidence: Slice slice-11 delivers workspace shell.
- slice_ref: slice-11

### Requirement: REQ-7
- requirement_summary: Rebuild projections
- prerequisites: see entries below

#### Prerequisite: Admin entry route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin entry route
- evidence: Slice slice-12 delivers admin route.
- slice_ref: slice-12

### Requirement: NFR-1
- requirement_summary: Query latency
- prerequisites: see entries below

#### Prerequisite: Operator account lookup page
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator account lookup page
- evidence: Slice slice-13 delivers lookup surface.
- slice_ref: slice-13
OUT
}

write_surface_preserving_plan_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 1.1 Backend query foundation [REQ-6] [REQ-7]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence, slice/slice-11
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Finalize backend query payload readiness for operator workspace consumers
- [ ] Add backend verification updates for projection-backed query and rebuild stability
- [ ] Review step implementation

### Step 1.2 Operator sign-in surface delivery [REQ-4]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, slice/slice-10
#### Preserved Surface: Admin sign-in screen
- [ ] Plan and discuss the step
- [ ] Deliver admin sign-in screen route and entry form surface
- [ ] Add sign-in surface checks for successful operator entry
- [ ] Review step implementation

### Step 1.3 Protected shell and admin route delivery [REQ-6]
#### Repo: frontend
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, slice/slice-11, slice/slice-12
#### Preserved Surface: Admin workspace shell route
- [ ] Plan and discuss the step
- [ ] Deliver protected admin workspace shell and admin portal route entry
- [ ] Add shell and route entry checks for authenticated access
- [ ] Review step implementation

### Step 1.4 Operator lookup surface delivery [REQ-4] [NFR-1]
#### Repo: mobile
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-4, gap/TECH_REQ-NFR-1, comp/mobile-order-projection-client, slice/slice-13
#### Preserved Surface: Operator account search screen
- [ ] Plan and discuss the step
- [ ] Deliver operator account lookup screen with projection-backed query state
- [ ] Add lookup-surface checks and latency-focused verification
- [ ] Review step implementation
OUT
}

write_required_operator_tool_prerequisite_gaps() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-6
- requirement_summary: Query orders
- prerequisites: see entries below

#### Prerequisite: Order query CLI command
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator order query CLI command
- evidence: Slice slice-20 delivers the order query admin terminal command.
- slice_ref: slice-20

### Requirement: REQ-4
- requirement_summary: Order creation
- prerequisites: none

### Requirement: REQ-7
- requirement_summary: Rebuild projections
- prerequisites: none

### Requirement: NFR-1
- requirement_summary: Query latency
- prerequisites: none
OUT
}

write_operator_tool_plan_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 1.1 Backend query foundation [REQ-6] [REQ-7]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Finalize backend query payload readiness for downstream consumers
- [ ] Add backend verification updates for projection-backed query and rebuild stability
- [ ] Review step implementation

### Step 1.2 Order query command delivery [REQ-6] [NFR-1]
#### Repo: backend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-6, gap/TECH_REQ-NFR-1, slice/slice-20
#### Preserved Surface: Order query admin tool command
- [ ] Plan and discuss the step
- [ ] Deliver the order query admin tool command and argument parsing for operator terminal workflows
- [ ] Add command-focused verification and latency checks for order query invocation and output
- [ ] Review step implementation

### Step 1.3 Frontend order projection client alignment [REQ-4] [REQ-6]
#### Repo: frontend
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
#### Preserved Surface: Protected operator workspace shell
- [ ] Plan and discuss the step
- [ ] Update order API client mapping for projection fields added by backend
- [ ] Update order creation screen state and rendering for projection-backed status
- [ ] Add component and adapter tests for projection field handling
- [ ] Review step implementation

### Step 1.4 Mobile order projection client alignment [REQ-4] [REQ-6]
#### Repo: mobile
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, comp/mobile-order-projection-client
#### Preserved Surface: Operator order lookup screen
- [ ] Plan and discuss the step
- [ ] Update mobile order API mapper for projection fields added by backend
- [ ] Update mobile order screen state and rendering for projection-backed status
- [ ] Add mobile view-model and screen tests for projection field handling
- [ ] Review step implementation
OUT
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_implementation_plan_quality.sh "$target_arg" 2>&1)"
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
  write_technical_requirements "$repo_dir"
  write_prerequisite_gaps "$repo_dir"
  write_valid_plan "$repo_dir"
}

test_passes_with_valid_shared_plan() {
  local repo_dir="$TMP_ROOT/repo-pass"
  setup_valid_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_technical_requirements_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-technical-requirements"
  setup_valid_fixture "$repo_dir"
  rm -f "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Required sibling artifact not found for quality check:"
  assert_contains "$out" "projects/p1/feature-a/technical_requirements.md"
}

test_fails_when_repo_header_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-repo"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/#### Repo: backend\n//' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "missing #### Repo"
}

test_fails_when_dependency_points_to_later_step() {
  local repo_dir="$TMP_ROOT/repo-late-dependency"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/#### Depends on: 1\.1/#### Depends on: 1.4/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "depends on unknown or later step 1.4"
}

test_accepts_cross_feature_dependency_reference() {
  local repo_dir="$TMP_ROOT/repo-cross-feature-dependency"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/#### Depends on: 1\.1/#### Depends on: 0003_customer_accounts\/3.2/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_cross_feature_dependency_uses_dot_folder() {
  local repo_dir="$TMP_ROOT/repo-cross-feature-dot-dependency"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/#### Depends on: 1\.1/#### Depends on: ..\/3.2/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "invalid cross-feature dependency ../3.2"
}

test_fails_when_requirement_reference_is_unknown() {
  local repo_dir="$TMP_ROOT/repo-unknown-req"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/\[REQ-6\]/[REQ-99]/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" 'step heading "### Step 1.1 Order projection persistence foundation [REQ-99] [REQ-7]" references unknown requirement id REQ-99'
}

test_fails_when_step_heading_has_no_requirement_links() {
  local repo_dir="$TMP_ROOT/repo-missing-heading-links"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/### Step 1\.2 Order query endpoint read-path completion \[REQ-6\] \[NFR-1\]/### Step 1.2 Order query endpoint read-path completion/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" 'step heading "### Step 1.2 Order query endpoint read-path completion" must reference at least one REQ-* or NFR-* id'
}

test_fails_when_requirement_has_no_related_step() {
  local repo_dir="$TMP_ROOT/repo-uncovered-requirement"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/\[REQ-6\] \[REQ-7\]/[REQ-6]/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "requirement id REQ-7 is not covered by any implementation step heading"
}

test_fails_when_evidence_line_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-evidence-line"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/\n#### Evidence: gap\/TECH_REQ-6, gap\/TECH_REQ-NFR-1\n/\n/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "step 1.2 is missing #### Evidence"
}

test_fails_when_evidence_token_is_unknown() {
  local repo_dir="$TMP_ROOT/repo-unknown-evidence-token"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/#### Evidence: gap\/TECH_REQ-6, gap\/TECH_REQ-NFR-1/#### Evidence: gap\/TECH_REQ-99, gap\/TECH_REQ-NFR-1/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "step 1.2 references unknown evidence token gap/TECH_REQ-99"
}

test_fails_when_unresolved_requirement_evidence_is_uncovered() {
  local repo_dir="$TMP_ROOT/repo-uncovered-unresolved-requirement"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/gap\/TECH_REQ-6/gap\/TECH_REQ-4/g' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "unresolved requirement evidence token gap/TECH_REQ-6 is not covered by any implementation step"
}

test_fails_when_unresolved_component_evidence_is_uncovered() {
  local repo_dir="$TMP_ROOT/repo-uncovered-unresolved-component"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/#### Evidence: gap\/TECH_REQ-4, comp\/mobile-order-projection-client\n/#### Evidence: gap\/TECH_REQ-4\n/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "unresolved component evidence token comp/mobile-order-projection-client is not covered by any implementation step"
}

test_fails_when_applicable_repo_has_no_steps() {
  local repo_dir="$TMP_ROOT/repo-missing-mobile"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/\n### Step 1\.4[\s\S]*$//s' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "repo mobile has impacted components in technical requirements but no plan step is allocated to it"
}

test_fails_when_prerequisite_gaps_is_absent() {
  local repo_dir="$TMP_ROOT/repo-missing-prerequisite-gaps"
  setup_valid_fixture "$repo_dir"
  rm -f "$repo_dir/projects/p1/feature-a/prerequisite_gaps.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"

  assert_equal "2" "$status"
}

test_passes_when_slice_token_accepted_as_valid_evidence() {
  local repo_dir="$TMP_ROOT/repo-slice-token-pass"
  setup_valid_fixture "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-4
- requirement_summary: Order creation
- prerequisites: see entries below

#### Prerequisite: Order creation UI route
- status: scheduled_in_slices
- evidence: Slice slice-3 adds /orders/create page
- slice_ref: slice-3

### Requirement: REQ-6
- requirement_summary: Query orders
- prerequisites: none

### Requirement: REQ-7
- requirement_summary: Rebuild projections
- prerequisites: none

### Requirement: NFR-1
- requirement_summary: Query latency
- prerequisites: none
OUT

  perl -0pi -e 's/(#### Evidence: gap\/TECH_REQ-4, comp\/frontend-order-projection-client)/$1, slice\/slice-3/' \
    "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_scheduled_slice_ref_not_covered_by_plan_evidence() {
  local repo_dir="$TMP_ROOT/repo-slice-ref-uncovered"
  setup_valid_fixture "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-4
- requirement_summary: Order creation
- prerequisites: see entries below

#### Prerequisite: Order creation UI route
- status: scheduled_in_slices
- evidence: Slice slice-3 adds /orders/create page
- slice_ref: slice-3

### Requirement: REQ-6
- requirement_summary: Query orders
- prerequisites: none

### Requirement: REQ-7
- requirement_summary: Rebuild projections
- prerequisites: none

### Requirement: NFR-1
- requirement_summary: Query latency
- prerequisites: none
OUT

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "slice-3"
  assert_contains "$out" "not covered by any plan step evidence token"
}

test_fails_when_slice_token_has_malformed_format() {
  local repo_dir="$TMP_ROOT/repo-malformed-slice-token"
  setup_valid_fixture "$repo_dir"

  perl -0pi -e 's/(#### Evidence: gap\/TECH_REQ-4, comp\/frontend-order-projection-client)/$1, slice\/-bad-start/' \
    "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "invalid evidence token format"
}

test_fails_when_required_login_surface_is_missing_from_plan() {
  local repo_dir="$TMP_ROOT/repo-plan-missing-login-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"
  perl -0pi -e 's/#### Preserved Surface: Admin sign-in screen/#### Preserved Surface: none/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Operator login page"
}

test_fails_when_required_protected_shell_is_missing_from_plan() {
  local repo_dir="$TMP_ROOT/repo-plan-missing-shell-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"
  perl -0pi -e 's/#### Preserved Surface: Admin workspace shell route/#### Preserved Surface: none/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Protected operator workspace shell"
}

test_fails_when_required_admin_entry_route_is_missing_from_plan() {
  local repo_dir="$TMP_ROOT/repo-plan-missing-admin-route-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"
  perl -0pi -e 's/slice\/slice-12//' "$repo_dir/projects/p1/feature-a/implementation_plan.md"
  perl -0pi -e 's/#### Preserved Surface: Admin workspace shell route/#### Preserved Surface: Protected operator workspace shell/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Admin entry route"
}

test_fails_when_required_lookup_surface_is_missing_from_plan() {
  local repo_dir="$TMP_ROOT/repo-plan-missing-lookup-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"
  perl -0pi -e 's/#### Preserved Surface: Operator account search screen/#### Preserved Surface: none/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Operator account lookup page"
}

test_fails_when_surface_step_is_supporting_only() {
  local repo_dir="$TMP_ROOT/repo-plan-supporting-only-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"
  perl -0pi -e 's/### Step 1\.2 Operator sign-in surface delivery \[REQ-4\]/### Step 1.2 Auth scaffolding alignment [REQ-4]/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"
  perl -0pi -e 's/Deliver admin sign-in screen route and entry form surface/Add auth middleware token and API contract alignment only/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"
  perl -0pi -e 's/Add sign-in surface checks for successful operator entry/Add auth-state and contract checks only/' "$repo_dir/projects/p1/feature-a/implementation_plan.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "supporting-only work"
}

test_passes_with_equivalent_surface_wording() {
  local repo_dir="$TMP_ROOT/repo-plan-equivalent-surface-wording"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_equivalent_operator_tool_wording() {
  local repo_dir="$TMP_ROOT/repo-plan-equivalent-operator-tool-wording"
  setup_valid_fixture "$repo_dir"
  write_required_operator_tool_prerequisite_gaps "$repo_dir"
  write_operator_tool_plan_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

write_coordination_plan_fixture_pass() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 1.1 Contract coordination [REQ-4]
#### Repo: backend
#### Coordination: true
#### Depends on: none
#### Evidence: gap/TECH_REQ-4, comp/backend-projection-persistence
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Coordinate the shared order payload contract document with consumer repo owners
- [ ] Confirm consumer repo owners acknowledge the frozen contract before downstream steps start
- [ ] Review step implementation

### Step 1.2 Backend query foundation [REQ-6] [REQ-7]
#### Repo: backend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Finalize backend query payload readiness for consumers
- [ ] Add backend query and rebuild verification
- [ ] Review step implementation

### Step 1.3 Operator sign-in surface delivery [REQ-4]
#### Repo: frontend
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, slice/slice-10
#### Preserved Surface: Admin sign-in screen
- [ ] Plan and discuss the step
- [ ] Deliver admin sign-in screen route and entry form
- [ ] Add sign-in surface checks for operator entry
- [ ] Review step implementation

### Step 1.4 Protected shell and admin route delivery [REQ-6]
#### Repo: frontend
#### Depends on: 1.3
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, slice/slice-11, slice/slice-12
#### Preserved Surface: Admin workspace shell route
- [ ] Plan and discuss the step
- [ ] Deliver protected admin workspace shell and admin portal route
- [ ] Add shell and route entry checks for authenticated access
- [ ] Review step implementation

### Step 1.5 Operator lookup surface delivery [REQ-4] [NFR-1]
#### Repo: mobile
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, gap/TECH_REQ-NFR-1, comp/mobile-order-projection-client, slice/slice-13
#### Preserved Surface: Operator account search screen
- [ ] Plan and discuss the step
- [ ] Deliver operator account lookup screen with projection-backed query state
- [ ] Add lookup surface checks and latency-focused verification
- [ ] Review step implementation
OUT
}

write_coordination_plan_fixture_fail() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 1.1 Contract coordination sign-in alignment [REQ-4]
#### Repo: frontend
#### Coordination: true
#### Depends on: none
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, slice/slice-10
#### Preserved Surface: Admin sign-in screen
- [ ] Plan and discuss the step
- [ ] Coordinate sign-in surface contract requirements with auth and consumer repo owners
- [ ] Confirm contract document is accepted before downstream steps start
- [ ] Review step implementation

### Step 1.2 Backend query foundation [REQ-6] [REQ-7]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Finalize backend query payload readiness for consumers
- [ ] Add backend query and rebuild verification
- [ ] Review step implementation

### Step 1.3 Protected shell and admin route delivery [REQ-6]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client, slice/slice-11, slice/slice-12
#### Preserved Surface: Admin workspace shell route
- [ ] Plan and discuss the step
- [ ] Deliver protected admin workspace shell and admin portal route
- [ ] Add shell and route entry checks for authenticated access
- [ ] Review step implementation

### Step 1.4 Operator lookup surface delivery [REQ-4] [NFR-1]
#### Repo: mobile
#### Depends on: 1.2
#### Evidence: gap/TECH_REQ-4, gap/TECH_REQ-NFR-1, comp/mobile-order-projection-client, slice/slice-13
#### Preserved Surface: Operator account search screen
- [ ] Plan and discuss the step
- [ ] Deliver operator account lookup screen with projection-backed query state
- [ ] Add lookup surface checks and latency-focused verification
- [ ] Review step implementation
OUT
}

test_passes_with_coordination_step_beside_preserved_surface_step() {
  local repo_dir="$TMP_ROOT/repo-plan-coordination-step-pass"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_coordination_plan_fixture_pass "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_coordination_step_is_sole_surface_coverage() {
  local repo_dir="$TMP_ROOT/repo-plan-coordination-sole-coverage"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_coordination_plan_fixture_fail "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "no non-coordination plan step coverage"
}

test_passes_with_no_coordination_step() {
  local repo_dir="$TMP_ROOT/repo-plan-no-coordination-step"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_plan_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_plan.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_valid_shared_plan
test_fails_when_technical_requirements_is_missing
test_fails_when_repo_header_is_missing
test_fails_when_dependency_points_to_later_step
test_accepts_cross_feature_dependency_reference
test_fails_when_cross_feature_dependency_uses_dot_folder
test_fails_when_requirement_reference_is_unknown
test_fails_when_step_heading_has_no_requirement_links
test_fails_when_requirement_has_no_related_step
test_fails_when_evidence_line_is_missing
test_fails_when_evidence_token_is_unknown
test_fails_when_unresolved_requirement_evidence_is_uncovered
test_fails_when_unresolved_component_evidence_is_uncovered
test_fails_when_applicable_repo_has_no_steps
test_fails_when_prerequisite_gaps_is_absent
test_passes_when_slice_token_accepted_as_valid_evidence
test_fails_when_scheduled_slice_ref_not_covered_by_plan_evidence
test_fails_when_slice_token_has_malformed_format
test_fails_when_required_login_surface_is_missing_from_plan
test_fails_when_required_protected_shell_is_missing_from_plan
test_fails_when_required_admin_entry_route_is_missing_from_plan
test_fails_when_required_lookup_surface_is_missing_from_plan
test_fails_when_surface_step_is_supporting_only
test_passes_with_equivalent_surface_wording
test_passes_with_equivalent_operator_tool_wording
test_passes_with_coordination_step_beside_preserved_surface_step
test_fails_when_coordination_step_is_sole_surface_coverage
test_passes_with_no_coordination_step

echo "All implementation plan quality tests passed."
