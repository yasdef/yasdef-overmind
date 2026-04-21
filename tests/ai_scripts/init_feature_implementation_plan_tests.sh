#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_implementation_plan.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/implementation_plan_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/implementation_plan_TEMPLATE.md"
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

assert_file_not_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
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

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_implementation_plan.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/implementation_plan_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/implementation_plan_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/implementation_plan_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_implementation_plan.sh"

  cat >"$repo_dir/asdlc/.helper/check_implementation_plan_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_implementation_plan_quality.sh"

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
repository_implementation_plan | codex | gpt-5.4 | --config | model_reasoning_effort='high'
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
    - mobile
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
**User Story:** As an operator, I want consistent projections, so that reads remain correct.

**Acceptance Criteria (EARS):**
- WHEN order state changes, THE System SHALL rebuild projections deterministically.

**Verification:** Projection rebuild tests.
OUT

  cat >"$repo_dir/asdlc/$feature_path/feature_contract_delta.md" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- delta_needed: true

## 4. Track Handoff Signals
- backend_handoff: introduce shared order projection changes before client work
- frontend_mobile_handoff: consume additive fields after backend projection changes land
OUT

  cat >"$repo_dir/asdlc/$feature_path/technical_requirements.md" <<'OUT'
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
- feature_summary: complete projection-backed order create and query flow
- included_behavior: backend projection rebuild plus frontend/mobile projection field consumption
- excluded_behavior: unrelated order editing flows

## 3. Repository Evidence
### Repository: backend
- class: backend
- evidence_scope: projection persistence and query api
- primary_paths: src/main/java/com/example/order
- key_findings: projection persistence exists but query controller error contract is incomplete
- constraints: backend remains source of truth for projection payload shape
- open_gaps: query DTO and error mapping work remain

### Repository: frontend
- class: frontend
- evidence_scope: order create screen and api adapter
- primary_paths: src/order
- key_findings: client state does not yet consume projection-backed status fields
- constraints: frontend follows backend response fields
- open_gaps: mapper and UI state updates remain

### Repository: mobile
- class: mobile
- evidence_scope: mobile order screen and api adapter
- primary_paths: mobile/order
- key_findings: mobile view model does not yet consume projection-backed status fields
- constraints: mobile follows backend response fields
- open_gaps: mapper and state updates remain

## 4. Requirement Coverage and Gaps
### Requirement: REQ-4
- requirement_summary: create orders
- current_state: backend creation exists; clients need projection-backed status support
- gap_status: partially_implemented
- repo_impact: multiple
- evidence: create flow exists end-to-end with partial projection support
- gap_to_close: finish client contract mapping and UI handling

### Requirement: REQ-6
- requirement_summary: query orders
- current_state: backend read path is only partially wired
- gap_status: partially_implemented
- repo_impact: backend
- evidence: projection persistence exists but query endpoint remains incomplete
- gap_to_close: complete read service, controller mapping, and tests

### Requirement: REQ-7
- requirement_summary: rebuild projections deterministically
- current_state: backend rebuild path already exists
- gap_status: fully_implemented
- repo_impact: backend
- evidence: rebuild service and tests already present
- gap_to_close: no remaining gap

## 5. Impacted Components
### Component: backend projection persistence
- repo: backend
- component_kind: persistence
- relevant_paths: src/main/java/com/example/order/projection
- requirement_refs: REQ-6, REQ-7
- current_state: persistence and rebuild path already implemented
- required_behavior: keep projection persistence as the backend source for query and client consumers
- gap_to_close: no remaining gap
- dependency_notes: frontend and mobile depend on this persisted shape
- evidence: repository and rebuild integration tests already cover the persistence slice

### Component: backend order query controller
- repo: backend
- component_kind: controller
- relevant_paths: src/main/java/com/example/order/api/OrderQueryController.java
- requirement_refs: REQ-6
- current_state: query read path is incomplete
- required_behavior: expose projection-backed query endpoint with stable dto and error mapping
- gap_to_close: add controller dto mapping, read service wiring, and tests
- dependency_notes: client work should follow stable query payload completion
- evidence: controller exists with partial read-path wiring only

### Component: frontend order projection client
- repo: frontend
- component_kind: api_client
- relevant_paths: src/order/api/orders.ts
- requirement_refs: REQ-4, REQ-6
- current_state: frontend client does not map projection-backed status fields
- required_behavior: consume backend projection fields in adapter and screen state
- gap_to_close: add adapter mapping, screen state updates, and tests
- dependency_notes: depends on backend projection persistence contract from existing backend slice
- evidence: current adapter ignores projection-backed fields

### Component: mobile order projection client
- repo: mobile
- component_kind: api_client
- relevant_paths: mobile/order/api/orders.ts
- requirement_refs: REQ-4, REQ-6
- current_state: mobile client does not map projection-backed status fields
- required_behavior: consume backend projection fields in mapper and view model
- gap_to_close: add mapper, state updates, and tests
- dependency_notes: depends on backend projection persistence contract from existing backend slice
- evidence: current mobile mapper ignores projection-backed fields

## 6. Cross-Repo Constraints and Planning Signals
- constraint_1: backend projection payload remains the source of truth for client consumers
- prep_1: represent existing backend persistence work in the plan before pending client work

## 7. Known Risks / Uncertainties
- risk_1: frontend and mobile may have diverged local assumptions about status field naming
OUT

  cat >"$repo_dir/asdlc/$feature_path/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 1. Document Meta
- feature_id: ORD-42
- last_updated: 2026-04-12

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
OUT

  cat >"$repo_dir/asdlc/$feature_path/implementation_slices.md" <<'OUT'
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
### Slice 1: Backend query read-path completion [REQ-6]
- repo: backend
- status: planned
- objective: Complete backend query read-path behavior.
- first_increment: Query endpoint returns stable projection fields.
- prerequisites: none
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Plan and discuss the slice
- [ ] Complete read service + controller mapping for query path
- [ ] Add query integration tests for stable projection responses
- [ ] Review slice readiness

### Slice 2: Frontend projection client alignment [REQ-4] [REQ-6]
- repo: frontend
- status: planned
- objective: Align frontend projection mapping with backend payload.
- first_increment: Frontend renders projection-backed status.
- prerequisites: Slice 1 backend payload stability
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Plan and discuss the slice
- [ ] Update frontend adapter mapping for projection fields
- [ ] Add client tests for projection-backed state handling
- [ ] Review slice readiness
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_IMPLEMENTATION_PLAN_FILE:-projects/p1/feature-a/implementation_plan.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'DOC'
# Implementation Plan - Golden Example

### Step 1.1 Order projection persistence foundation [REQ-6] [REQ-7]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence
#### Preserved Surface: none
- [x] Plan and discuss the step
- [x] Add projection table changeSet and repository mappings
- [x] Implement projection rebuild service path and integration coverage
- [x] Review step implementation

### Step 1.2 Frontend operator entry surface alignment [REQ-4] [REQ-6]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
#### Preserved Surface: Admin sign-in screen
- [ ] Plan and discuss the step
- [ ] Deliver admin sign-in screen route and entry form surface
- [ ] Update order API client mapping for projection fields used after sign-in
- [ ] Add component and adapter tests for projection field handling
- [ ] Review step implementation

### Step 1.3 Mobile order projection client alignment [REQ-4] [REQ-6]
#### Repo: mobile
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-4, comp/mobile-order-projection-client
#### Preserved Surface: Operator account search screen
- [ ] Plan and discuss the step
- [ ] Update mobile order API mapper for projection fields added by backend
- [ ] Update mobile order screen state and rendering for projection-backed status
- [ ] Add mobile view-model and screen tests for projection field handling
- [ ] Review step implementation
DOC
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_implementation_plan.sh" "$repo_dir/feature_implementation_plan.sh"
  chmod +x "$repo_dir/feature_implementation_plan.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_implementation_plan.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_technical_requirements_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-technical-requirements"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/technical_requirements.md"
}

test_fails_when_implementation_slices_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-implementation-slices"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/implementation_slices.md"
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_plan.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'repository_implementation_plan' entry"
}

test_generates_plan_and_builds_expected_prompt() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/repo-success-capture"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local requirements_before=""
  local technical_requirements_before=""
  local delta_before=""
  local implementation_slices_before=""
  requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  technical_requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  delta_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"
  implementation_slices_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md")"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_implementation_plan.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/implementation_plan.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan.md"
  local generated_plan=""
  generated_plan="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_plan.md")"
  assert_contains "$generated_plan" "### Step 1.1 Order projection persistence foundation [REQ-6] [REQ-7]"
  assert_contains "$generated_plan" "### Step 1.2 Frontend operator entry surface alignment [REQ-4] [REQ-6]"
  assert_contains "$generated_plan" "### Step 1.3 Mobile order projection client alignment [REQ-4] [REQ-6]"
  assert_contains "$generated_plan" "#### Evidence: gap/TECH_REQ-6, comp/backend-projection-persistence"
  assert_contains "$generated_plan" "#### Evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client"
  assert_contains "$generated_plan" "#### Evidence: gap/TECH_REQ-4, comp/mobile-order-projection-client"
  assert_contains "$generated_plan" "#### Preserved Surface: none"
  assert_contains "$generated_plan" "#### Preserved Surface: Admin sign-in screen"
  assert_contains "$generated_plan" "#### Preserved Surface: Operator account search screen"
  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$technical_requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  assert_equal "$delta_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"
  assert_equal "$implementation_slices_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md")"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/implementation_plan_rule.md"
  assert_contains "$codex_prompt" "Keep this prompt concise: detailed planning and formatting rules are owned by .rules/implementation_plan_rule.md."
  assert_contains "$codex_prompt" "Target artifact: projects/p1/feature-a/implementation_plan.md"
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/implementation_slices.md as the authoritative execution-slice discovery input from Step 8.1."
  assert_contains "$codex_prompt" "Then use projects/p1/feature-a/technical_requirements.md as the authoritative current-state and gap artifact to validate completeness."
  assert_contains "$codex_prompt" "Then use projects/p1/feature-a/feature_contract_delta.md to identify shared-contract, rollout, compatibility, or cross-track prerequisite work that must be planned before repo-specific implementation steps."
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/requirements_ears.md as the authoritative source of behavioral scope and valid \`REQ-*\` / \`NFR-*\` ids."
  assert_contains "$codex_prompt" "Draft the implementation plan in projects/p1/feature-a/implementation_plan.md before running any quality gate command."
  assert_contains "$codex_prompt" "Use this quality gate command before finalizing: .helper/check_implementation_plan_quality.sh projects/p1/feature-a/implementation_plan.md"
  assert_contains "$codex_prompt" "If you need to understand the gate, read .helper/check_implementation_plan_quality.sh as a file; only execute .helper/check_implementation_plan_quality.sh projects/p1/feature-a/implementation_plan.md against a concrete draft artifact."
  assert_contains "$codex_prompt" "Do not add \`#### Assigned:\` lines by default"
  assert_contains "$codex_prompt" "Implementation slices source: projects/p1/feature-a/implementation_slices.md"
  assert_contains "$codex_prompt" "Technical requirements source: projects/p1/feature-a/technical_requirements.md"
  assert_contains "$codex_prompt" "check_implementation_plan_quality.sh projects/p1/feature-a/implementation_plan.md"
  assert_not_contains "$codex_prompt" "Key Parts of Repo and Their Responsibilities"
  assert_not_contains "$codex_prompt" "project_surface_struct_resp_map_backend.md"
  assert_not_contains "$codex_prompt" "project_surface_struct_resp_map_frontend.md"
  assert_not_contains "$codex_prompt" "project_surface_struct_resp_map_mobile.md"

  local committed_files=""
  committed_files="$(cd "$repo_dir/asdlc" && git show --pretty='' --name-only HEAD)"
  assert_contains "$committed_files" "projects/p1/feature-a/implementation_plan.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/requirements_ears.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/technical_requirements.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/feature_contract_delta.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/implementation_slices.md"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_technical_requirements_is_missing
test_fails_when_implementation_slices_is_missing
test_fails_when_model_phase_missing
test_generates_plan_and_builds_expected_prompt
