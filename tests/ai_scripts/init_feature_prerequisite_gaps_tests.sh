#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_prerequisite_gaps.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/prerequisite_gaps_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/prerequisite_gaps_TEMPLATE.md"
GOLDEN_SRC="$SOURCE_ROOT/overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md"

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

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_prerequisite_gaps.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/prerequisite_gaps_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/prerequisite_gaps_TEMPLATE.md"
  cp "$GOLDEN_SRC" "$repo_dir/asdlc/.golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md"
  chmod +x "$repo_dir/asdlc/.commands/feature_prerequisite_gaps.sh"

  cat >"$repo_dir/asdlc/.helper/check_prerequisite_gaps_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  printf '%s\n' "$@" >"$capture_dir/helper_args.txt"
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_prerequisite_gaps_quality.sh"

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
prerequisite_gap_trace | codex | gpt-5.4 | --config | model_reasoning_effort='high'
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

### Requirement 4 - Admin login
**Acceptance Criteria (EARS):**
- WHEN an operator visits /admin/login, THE System SHALL allow authentication.

### Requirement 6 - Order query
**Acceptance Criteria (EARS):**
- WHEN an operator calls POST /api/v1/orders/query, THE System SHALL return order projection results.
OUT

  cat >"$repo_dir/asdlc/$feature_path/technical_requirements.md" <<'OUT'
# Technical Requirements

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B

## 4. Requirement Coverage and Gaps
### Requirement: REQ-4
- transport_layer: AuthController.login()
- user_reachable_surface: none
- gap_status: missing

### Requirement: REQ-6
- transport_layer: OrderQueryController.query()
- user_reachable_surface: POST /api/v1/orders/query
- gap_status: partially_implemented
OUT

  cat >"$repo_dir/asdlc/$feature_path/implementation_slices.md" <<'OUT'
# Implementation Slices

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: B

## 3. Slice Candidates
### Slice 1: Backend query read-path completion [REQ-6]
- repo: backend
- status: planned
- objective: Complete backend query read-path behavior.
- first_increment: Query endpoint returns stable projection fields.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-query-controller
- [ ] Complete query path
- [ ] Add query tests

### Slice 2: Frontend admin login surface [REQ-4]
- repo: frontend
- status: planned
- objective: Deliver admin login route.
- first_increment: Operators can authenticate from /admin/login.
- prerequisites: none
- preserved_operator_surface: Admin login page
- evidence: gap/TECH_REQ-4, comp/frontend-admin-login
- [ ] Add /admin/login route and screen
- [ ] Add login interaction tests
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_PREREQUISITE_GAPS_FILE:-projects/p1/feature-a/prerequisite_gaps.md}"
project_type_code="${TEST_PROJECT_TYPE_CODE:-B}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'DOC'
# Prerequisite Gaps

## 1. Document Meta
- feature_id: ORD-42
- feature_title: order-projection-refresh
- project_type_code: PROJECT_TYPE_CODE_PLACEHOLDER
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_implementation_slices: projects/p1/feature-a/implementation_slices.md
- last_updated: 2026-05-03

## 2. Prerequisite Trace
### Requirement: REQ-4
- requirement_summary: Operator authentication surface
- prerequisites: see entries below

#### Prerequisite: Admin login page
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Admin login page
- evidence: Slice 2 adds /admin/login route and screen
- slice_ref: slice-2

### Requirement: REQ-6
- requirement_summary: Operator query entrypoint
- prerequisites: see entries below

#### Prerequisite: Order query endpoint
- status: present_in_repo
- surface_kind: present_user_reachable_surface
- surface_identity: none
- evidence: POST /api/v1/orders/query
- slice_ref: none
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
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_prerequisite_gaps.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_prerequisite_gaps.sh" "$repo_dir/feature_prerequisite_gaps.sh"
  chmod +x "$repo_dir/feature_prerequisite_gaps.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_prerequisite_gaps.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
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
  out="$(cd "$repo_dir/asdlc" && .commands/feature_prerequisite_gaps.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'prerequisite_gap_trace' entry"
}

test_generates_prerequisite_gaps_and_builds_expected_prompt() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/repo-success-capture"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local requirements_before=""
  local technical_before=""
  local slices_before=""
  requirements_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  technical_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  slices_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md")"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_prerequisite_gaps.sh --feature_path "projects/p1/feature-a"
  )"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/prerequisite_gaps.md"
  assert_equal "$requirements_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$technical_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/technical_requirements.md")"
  assert_equal "$slices_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md")"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/prerequisite_gaps_rule.md"
  assert_contains "$codex_prompt" "Run Step 8.2 prerequisite gap trace for this feature."
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/technical_requirements.md user_reachable_surface subfields as the ground truth for present_in_repo status."
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/implementation_slices.md as the ground truth for scheduled_in_slices status."
  assert_contains "$codex_prompt" "Use this quality gate command before finalizing: .helper/check_prerequisite_gaps_quality.sh projects/p1/feature-a/prerequisite_gaps.md projects/p1/feature-a/requirements_ears.md projects/p1/feature-a/technical_requirements.md"
  assert_contains "$codex_prompt" "Target artifact: projects/p1/feature-a/prerequisite_gaps.md"
  assert_not_contains "$codex_prompt" "implementation_plan.md"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/prerequisite_gaps.md"
}

test_type_a_generates_prerequisite_gaps() {
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
  sed -i.bak 's/- project_type_code: B/- project_type_code: A/' "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/implementation_slices.md.bak"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_PROJECT_TYPE_CODE="A" \
      .commands/feature_prerequisite_gaps.sh --feature_path "projects/p1/feature-a"
  )"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/prerequisite_gaps.md"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/prerequisite_gaps.md")" "- project_type_code: A"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Project type code: A"
  assert_contains "$codex_prompt" "Use projects/p1/feature-a/technical_requirements.md user_reachable_surface subfields as the ground truth for present_in_repo status."
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_model_phase_missing
test_generates_prerequisite_gaps_and_builds_expected_prompt
test_type_a_generates_prerequisite_gaps

echo "All prerequisite gap initializer tests passed."
