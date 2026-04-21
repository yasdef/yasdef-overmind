#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_implementation_slices_quality.sh"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/implementation_slices_GOLDEN_EXAMPLE.md"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_implementation_slices_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_implementation_slices_quality.sh"

  (
    cd "$repo_dir"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "seed" >README.md
    git add README.md overmind
    git commit -qm "seed"
  )
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

### Requirement 4
- WHEN order is created, THE System SHALL persist it.

### Requirement 6
- WHEN order is queried, THE System SHALL return projection data.

### NFR 1
- WHEN order queries run under normal load, THE System SHALL stay within the agreed latency budget.
OUT
}

write_technical_requirements() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/technical_requirements.md" <<'OUT'
# Technical Requirements

## 4. Requirement Coverage and Gaps
### Requirement: REQ-4
- gap_status: partially_implemented
- gap_to_close: complete client mapping

### Requirement: REQ-6
- gap_status: partially_implemented
- gap_to_close: complete backend query mapping

### Requirement: NFR-1
- gap_status: unclear
- gap_to_close: confirm and add latency-focused verification for the query path

## 5. Impacted Components
### Component: backend order query controller
- repo: backend
- gap_to_close: complete mapping and tests

### Component: frontend order projection client
- repo: frontend
- gap_to_close: complete adapter mapping and tests
OUT
}

write_feature_contract_delta() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/feature_contract_delta.md" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- delta_needed: true
OUT
}

write_required_operator_surface_prerequisite_gaps() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-10
- requirement_summary: Operator sign-in must exist.
- prerequisites: see entries below

#### Prerequisite: Operator sign-in page
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator login page
- evidence: Slice slice-1 delivers login entry.
- slice_ref: slice-1

### Requirement: REQ-11
- requirement_summary: Operator shell must exist.
- prerequisites: see entries below

#### Prerequisite: Protected operator shell
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Protected operator workspace shell
- evidence: Slice slice-2 delivers workspace shell.
- slice_ref: slice-2

### Requirement: REQ-12
- requirement_summary: Operator admin route must exist.
- prerequisites: see entries below

#### Prerequisite: Admin entry route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin entry route
- evidence: Slice slice-3 delivers admin route.
- slice_ref: slice-3

### Requirement: REQ-13
- requirement_summary: Operator lookup must exist.
- prerequisites: see entries below

#### Prerequisite: Operator account lookup page
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator account lookup page
- evidence: Slice slice-4 delivers lookup page.
- slice_ref: slice-4
OUT
}

write_surface_preserving_slices_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_slices.md" <<'OUT'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_feature_contract_delta: projects/p1/feature-a/feature_contract_delta.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md, projects/p1/feature-a/project_surface_struct_resp_map_frontend.md, projects/p1/feature-a/project_surface_struct_resp_map_mobile.md
- analyzed_repo_classes: backend, frontend, mobile
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: 2026-04-12
- confidence_level: medium

## 2. Slice Planning Guardrails
- objective: Discover executable slices before ordered implementation-plan synthesis.

## 3. Slice Candidates
### Slice 1: Admin sign-in surface delivery
- repo: frontend
- status: planned
- objective: Deliver operator authentication entry UI surface.
- first_increment: Operator can open admin sign-in screen and submit credentials.
- prerequisites: none
- preserved_operator_surface: Admin sign-in screen
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Deliver admin sign-in screen route and entry form
- [ ] Wire frontend session handoff after successful sign-in

### Slice 2: Protected workspace shell delivery
- repo: frontend
- status: planned
- objective: Deliver the protected operator workspace container shell.
- first_increment: Operator can reach the protected workspace container after authentication.
- prerequisites: Slice 1 sign-in surface
- preserved_operator_surface: Admin workspace container
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Deliver protected workspace shell route and container composition
- [ ] Add shell-focused smoke coverage for authenticated access

### Slice 3: Admin entry route delivery
- repo: frontend
- status: planned
- objective: Deliver operator entry path for admin workflow start.
- first_increment: Operator can open the admin portal path that hosts protected workflow entry.
- prerequisites: Slice 2 workspace shell
- preserved_operator_surface: Admin portal path
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Deliver admin entry route wiring for workflow start
- [ ] Add route-level checks for authenticated entry

### Slice 4: Operator lookup delivery
- repo: frontend
- status: planned
- objective: Deliver account lookup operator screen for workflow search behavior.
- first_increment: Operator can query accounts from lookup screen and view projection-backed status.
- prerequisites: Slice 3 admin route
- preserved_operator_surface: Operator account search screen
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Deliver lookup page UI and query action controls
- [ ] Add lookup-surface checks for search and result rendering

## 4. Handoff To Ordered Plan
- ordering_intent: Surface delivery slices proceed sign-in to shell to entry route to lookup.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: none
OUT
}

write_required_operator_tool_prerequisite_gaps() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-20
- requirement_summary: Operators need a reconciliation command.
- prerequisites: see entries below

#### Prerequisite: Reconciliation command
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator reconciliation CLI command
- evidence: Slice slice-20 delivers the reconciliation admin terminal command.
- slice_ref: slice-20
OUT
}

write_operator_tool_slices_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_slices.md" <<'OUT'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_feature_contract_delta: projects/p1/feature-a/feature_contract_delta.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md, projects/p1/feature-a/project_surface_struct_resp_map_frontend.md, projects/p1/feature-a/project_surface_struct_resp_map_mobile.md
- analyzed_repo_classes: backend, frontend, mobile
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: 2026-04-12
- confidence_level: medium

## 2. Slice Planning Guardrails
- objective: Discover executable slices before ordered implementation-plan synthesis.

## 3. Slice Candidates
### Slice 1: Reconciliation command delivery
- repo: backend
- status: planned
- objective: Deliver operator reconciliation command for terminal-driven admin workflows.
- first_increment: Operator can run the reconciliation admin tool command successfully.
- prerequisites: none
- preserved_operator_surface: Reconciliation admin tool command
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Deliver reconciliation admin CLI command and argument parsing
- [ ] Add command-focused verification for operator terminal workflow

## 4. Handoff To Ordered Plan
- ordering_intent: Reconciliation command delivery can proceed independently.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: none
OUT
}

write_valid_slices() {
  local repo_dir="$1"
  cp "$GOLDEN_SRC" "$repo_dir/projects/p1/feature-a/implementation_slices.md"
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_implementation_slices_quality.sh "$target_arg" 2>&1)"
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
  write_feature_contract_delta "$repo_dir"
  write_valid_slices "$repo_dir"
}

test_passes_with_valid_slices_artifact() {
  local repo_dir="$TMP_ROOT/repo-pass"
  setup_valid_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_technical_requirements_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-technical"
  setup_valid_fixture "$repo_dir"
  rm -f "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Required sibling artifact not found for quality check: projects/p1/feature-a/technical_requirements.md"
}

test_fails_when_ordering_scope_is_invalid() {
  local repo_dir="$TMP_ROOT/repo-invalid-ordering"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/ordering_scope: local_prerequisites_only/ordering_scope: full_global_order/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "ordering_scope must be local_prerequisites_only"
}

test_fails_when_slice_repo_is_not_active() {
  local repo_dir="$TMP_ROOT/repo-invalid-repo"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- repo: mobile/- repo: infrastructure/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "uses repo outside active project classes"
}

test_fails_when_slice_contains_lifecycle_boilerplate_bullet() {
  local repo_dir="$TMP_ROOT/repo-boilerplate-bullet"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- \[ \] Implement read service \+ repository wiring for projection-backed query/- [ ] Plan and discuss the slice/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "contains forbidden lifecycle boilerplate bullet: Plan and discuss the slice"
}

test_fails_when_no_planned_slice_exists() {
  local repo_dir="$TMP_ROOT/repo-no-planned"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- status: planned/- status: existing/g' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "must contain at least one planned slice"
}

test_fails_when_required_login_surface_is_missing_from_slices() {
  local repo_dir="$TMP_ROOT/repo-missing-login-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_slices_fixture "$repo_dir"
  perl -0pi -e 's/- preserved_operator_surface: Admin sign-in screen/- preserved_operator_surface: none/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Operator login page"
}

test_fails_when_required_protected_shell_is_missing_from_slices() {
  local repo_dir="$TMP_ROOT/repo-missing-shell-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_slices_fixture "$repo_dir"
  perl -0pi -e 's/- preserved_operator_surface: Admin workspace container/- preserved_operator_surface: none/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Protected operator workspace shell"
}

test_fails_when_required_admin_entry_route_is_missing_from_slices() {
  local repo_dir="$TMP_ROOT/repo-missing-admin-route-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_slices_fixture "$repo_dir"
  perl -0pi -e 's/- preserved_operator_surface: Admin portal path/- preserved_operator_surface: none/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Admin entry route"
}

test_fails_when_required_lookup_surface_is_missing_from_slices() {
  local repo_dir="$TMP_ROOT/repo-missing-lookup-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_slices_fixture "$repo_dir"
  perl -0pi -e 's/- preserved_operator_surface: Operator account search screen/- preserved_operator_surface: none/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "Operator account lookup page"
}

test_fails_when_surface_is_marked_but_slice_is_supporting_only() {
  local repo_dir="$TMP_ROOT/repo-supporting-only-surface"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_slices_fixture "$repo_dir"
  perl -0pi -e 's/### Slice 1: Admin sign-in surface delivery/### Slice 1: Supporting auth scaffolding/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"
  perl -0pi -e 's/Deliver operator authentication entry UI surface\./Add auth middleware and token refresh plumbing only./' "$repo_dir/projects/p1/feature-a/implementation_slices.md"
  perl -0pi -e 's/Operator can open admin sign-in screen and submit credentials\./Session refresh token wiring is complete for auth middleware./' "$repo_dir/projects/p1/feature-a/implementation_slices.md"
  perl -0pi -e 's/Deliver admin sign-in screen route and entry form/Add auth middleware and token refresh state wiring/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"
  perl -0pi -e 's/Wire frontend session handoff after successful sign-in/Add API auth adapter contract alignment only/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "supporting-only scaffolding work"
}

test_passes_with_equivalent_operator_surface_wording() {
  local repo_dir="$TMP_ROOT/repo-equivalent-surface-wording"
  setup_valid_fixture "$repo_dir"
  write_required_operator_surface_prerequisite_gaps "$repo_dir"
  write_surface_preserving_slices_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_equivalent_operator_tool_wording() {
  local repo_dir="$TMP_ROOT/repo-equivalent-tool-wording"
  setup_valid_fixture "$repo_dir"
  write_required_operator_tool_prerequisite_gaps "$repo_dir"
  write_operator_tool_slices_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

write_coordination_slice_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_slices.md" <<'OUT'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_feature_contract_delta: projects/p1/feature-a/feature_contract_delta.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md
- analyzed_repo_classes: backend, frontend
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: 2026-04-20
- confidence_level: medium

## 2. Slice Planning Guardrails
- objective: Discover executable slices before ordered implementation-plan synthesis.

## 3. Slice Candidates
### Slice 1: Cross-repo contract freeze
- repo: backend
- status: planned
- kind: coordination
- signal_ref: signal-contract-lock-1
- objective: Freeze the shared order payload contract before parallel downstream implementation begins.
- first_increment: Contract document is reviewed and frozen for consumer repo alignment.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-4, comp/backend-order-query-controller
- [ ] Draft shared order payload contract document and circulate for review
- [ ] Confirm all consumer repo owners acknowledge the frozen contract

### Slice 2: Backend order query completion
- repo: backend
- status: planned
- objective: Complete backend order query controller wiring and tests.
- first_increment: Backend order query endpoint returns projection-backed results.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Implement read service and repository wiring for projection-backed query
- [ ] Add controller mapping and integration tests for the query endpoint

## 4. Handoff To Ordered Plan
- ordering_intent: Coordination slice first, then backend query completion in parallel with frontend.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: none
OUT
}

write_coordination_slice_missing_signal_ref_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_slices.md" <<'OUT'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_feature_contract_delta: projects/p1/feature-a/feature_contract_delta.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md
- analyzed_repo_classes: backend, frontend
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: 2026-04-20
- confidence_level: medium

## 2. Slice Planning Guardrails
- objective: Discover executable slices before ordered implementation-plan synthesis.

## 3. Slice Candidates
### Slice 1: Cross-repo contract freeze
- repo: backend
- status: planned
- kind: coordination
- objective: Freeze the shared order payload contract before parallel downstream implementation begins.
- first_increment: Contract document is reviewed and frozen for consumer repo alignment.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-4, comp/backend-order-query-controller
- [ ] Draft shared order payload contract document and circulate for review
- [ ] Confirm all consumer repo owners acknowledge the frozen contract

### Slice 2: Backend order query completion
- repo: backend
- status: planned
- objective: Complete backend order query controller wiring and tests.
- first_increment: Backend order query endpoint returns projection-backed results.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Implement read service and repository wiring for projection-backed query
- [ ] Add controller mapping and integration tests for the query endpoint

## 4. Handoff To Ordered Plan
- ordering_intent: Coordination slice first, then backend query completion.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: none
OUT
}

write_no_coordination_slice_fixture() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/implementation_slices.md" <<'OUT'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_feature_contract_delta: projects/p1/feature-a/feature_contract_delta.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md
- analyzed_repo_classes: backend, frontend
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: 2026-04-20
- confidence_level: medium

## 2. Slice Planning Guardrails
- objective: Discover executable slices before ordered implementation-plan synthesis.

## 3. Slice Candidates
### Slice 1: Backend order query completion
- repo: backend
- status: planned
- objective: Complete backend order query controller wiring and tests.
- first_increment: Backend order query endpoint returns projection-backed results.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Implement read service and repository wiring for projection-backed query
- [ ] Add controller mapping and integration tests for the query endpoint

### Slice 2: Frontend order projection client
- repo: frontend
- status: planned
- objective: Map projection-backed order status fields in the frontend client.
- first_increment: Frontend order list reflects projection-backed status without page reload.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Update frontend API adapter to map projection status fields from backend payload
- [ ] Update order list UI state and rendering for projection-backed status display

## 4. Handoff To Ordered Plan
- ordering_intent: Backend query and frontend client slices can proceed independently.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: none
OUT
}

test_passes_with_valid_coordination_slice() {
  local repo_dir="$TMP_ROOT/repo-coordination-slice-pass"
  setup_valid_fixture "$repo_dir"
  write_coordination_slice_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_coordination_slice_missing_signal_ref() {
  local repo_dir="$TMP_ROOT/repo-coordination-missing-signal-ref"
  setup_valid_fixture "$repo_dir"
  write_coordination_slice_missing_signal_ref_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "kind: coordination but signal_ref is missing or empty"
}

test_passes_with_no_coordination_slice() {
  local repo_dir="$TMP_ROOT/repo-no-coordination-slice"
  setup_valid_fixture "$repo_dir"
  write_no_coordination_slice_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_valid_slices_artifact
test_fails_when_technical_requirements_is_missing
test_fails_when_ordering_scope_is_invalid
test_fails_when_slice_repo_is_not_active
test_fails_when_slice_contains_lifecycle_boilerplate_bullet
test_fails_when_no_planned_slice_exists
test_fails_when_required_login_surface_is_missing_from_slices
test_fails_when_required_protected_shell_is_missing_from_slices
test_fails_when_required_admin_entry_route_is_missing_from_slices
test_fails_when_required_lookup_surface_is_missing_from_slices
test_fails_when_surface_is_marked_but_slice_is_supporting_only
test_passes_with_equivalent_operator_surface_wording
test_passes_with_equivalent_operator_tool_wording
test_passes_with_valid_coordination_slice
test_fails_when_coordination_slice_missing_signal_ref
test_passes_with_no_coordination_slice

echo "All implementation slices quality helper tests passed."
