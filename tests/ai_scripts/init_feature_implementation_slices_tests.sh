#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_implementation_slices.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/implementation_slices_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/implementation_slices_TEMPLATE.md"
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

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_implementation_slices.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/implementation_slices_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/implementation_slices_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/implementation_slices_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_implementation_slices.sh"

  cat >"$repo_dir/asdlc/.helper/check_implementation_slices_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_implementation_slices_quality.sh"

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
repository_implementation_slices | codex | gpt-5.4 | --config | model_reasoning_effort='high'
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

### Requirement 4 — Order creation
**Acceptance Criteria (EARS):**
- WHEN a user creates an order, THE System SHALL persist the order.

### Requirement 6 — Order query
**Acceptance Criteria (EARS):**
- WHEN a user queries orders, THE System SHALL return the matching order projection.
OUT

  cat >"$repo_dir/asdlc/$feature_path/feature_contract_delta.md" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- delta_needed: true

## 4. Track Handoff Signals
- backend_handoff: stabilize query payload before client updates
- frontend_mobile_handoff: consume backend projection fields after payload stabilization
OUT

  cat >"$repo_dir/asdlc/$feature_path/technical_requirements.md" <<'OUT'
# Technical Requirements

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B

## 4. Requirement Coverage and Gaps
### Requirement: REQ-4
- gap_status: partially_implemented
- gap_to_close: complete client projection field mapping and tests

### Requirement: REQ-6
- gap_status: partially_implemented
- gap_to_close: complete backend query read service and controller mapping

## 5. Impacted Components
### Component: backend order query controller
- repo: backend
- gap_to_close: finish controller mapping and tests

### Component: frontend order projection client
- repo: frontend
- gap_to_close: finish adapter mapping and tests
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_backend.md" <<'OUT'
# Backend Surface Map
- path: src/backend/order/query
OUT

  cat >"$repo_dir/asdlc/$feature_path/project_surface_struct_resp_map_frontend.md" <<'OUT'
# Frontend Surface Map
- path: src/frontend/order/api
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_IMPLEMENTATION_SLICES_FILE:-projects/p1/feature-a/implementation_slices.md}"
project_type_code="${TEST_PROJECT_TYPE_CODE:-B}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'DOC'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: PROJECT_TYPE_CODE_PLACEHOLDER
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_feature_contract_delta: projects/p1/feature-a/feature_contract_delta.md
- source_surface_map_artifacts: projects/p1/feature-a/project_surface_struct_resp_map_backend.md, projects/p1/feature-a/project_surface_struct_resp_map_frontend.md
- analyzed_repo_classes: backend, frontend
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
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Complete read service + controller mapping for query path
- [ ] Add DTO mapping and error-response alignment for query path
- [ ] Add query integration tests for stable projection responses

### Slice 2: Frontend operator entry surface alignment [REQ-4] [REQ-6]
- repo: frontend
- status: planned
- objective: Deliver admin sign-in screen and align projection mapping for operator flow entry.
- first_increment: Frontend sign-in screen renders and then shows projection-backed status after entry.
- prerequisites: Slice 1 backend payload stability
- preserved_operator_surface: Admin sign-in screen
- evidence: gap/TECH_REQ-4, comp/frontend-order-projection-client
- [ ] Deliver admin sign-in screen route and entry form surface
- [ ] Update frontend adapter/state mapping for projection-backed status after sign-in
- [ ] Add client tests for projection-backed state handling

## 4. Handoff To Ordered Plan
- ordering_intent: Backend slice first, frontend slice second.
- unresolved_ordering_questions: none
- unresolved_traceability_questions: confirm NFR mapping depth in next phase.
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_slices.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_implementation_slices.sh" "$repo_dir/feature_implementation_slices.sh"
  chmod +x "$repo_dir/feature_implementation_slices.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_implementation_slices.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_required_surface_map_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-surface"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_slices.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/project_surface_struct_resp_map_frontend.md"
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_implementation_slices.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'repository_implementation_slices' entry"
}

test_generates_slices_and_builds_expected_prompt() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/repo-success-capture"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local requirements_before=""
  local technical_before=""
  local delta_before=""
  requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  technical_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  delta_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_implementation_slices.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/implementation_slices.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md"
  local generated_slices=""
  generated_slices="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md")"
  assert_contains "$generated_slices" "- preserved_operator_surface: none"
  assert_contains "$generated_slices" "- preserved_operator_surface: Admin sign-in screen"
  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$technical_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  assert_equal "$delta_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md")"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/implementation_slices_rule.md"
  assert_contains "$codex_prompt" "Run Step 8.1 implementation slice planning for this feature."
  assert_contains "$codex_prompt" "Draft the slice artifact in projects/p1/feature-a/implementation_slices.md before running any quality gate command."
  assert_contains "$codex_prompt" "If you need to understand the gate, read .helper/check_implementation_slices_quality.sh as a file; only execute .helper/check_implementation_slices_quality.sh projects/p1/feature-a/implementation_slices.md against a concrete draft artifact."
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/technical_requirements.md as the canonical source of current-state evidence"
  assert_contains "$codex_prompt" "Do not force full cross-repo total ordering in this phase."
  assert_contains "$codex_prompt" "Use this quality gate command before finalizing: .helper/check_implementation_slices_quality.sh projects/p1/feature-a/implementation_slices.md"
  assert_contains "$codex_prompt" "Target artifact: projects/p1/feature-a/implementation_slices.md"
  assert_contains "$codex_prompt" "Applicable surface maps:"
  assert_contains "$codex_prompt" "projects/p1/feature-a/project_surface_struct_resp_map_backend.md"
  assert_not_contains "$codex_prompt" "Update only: projects/p1/feature-a/implementation_plan.md"

  local committed_files=""
  committed_files="$(cd "$repo_dir/asdlc" && git show --pretty='' --name-only HEAD)"
  assert_contains "$committed_files" "projects/p1/feature-a/implementation_slices.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/requirements_ears.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/technical_requirements.md"
  assert_not_contains "$committed_files" "projects/p1/feature-a/feature_contract_delta.md"
}

test_type_a_generates_implementation_slices() {
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

  sed -i.bak 's/- project_type_code: B/- project_type_code: A/' "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md.bak"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_PROJECT_TYPE_CODE="A" \
      .commands/feature_implementation_slices.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/implementation_slices.md"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md")" "- project_type_code: A"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Project type code: A"
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/technical_requirements.md as the canonical source of current-state evidence"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_required_surface_map_is_missing
test_fails_when_model_phase_missing
test_generates_slices_and_builds_expected_prompt
test_type_a_generates_implementation_slices

echo "All implementation slices initializer tests passed."
