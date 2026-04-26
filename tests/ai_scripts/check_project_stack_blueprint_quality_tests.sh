#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_project_stack_blueprint_quality.sh"
GOLDEN_BE_SRC="$SOURCE_ROOT/overmind/golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md"
GOLDEN_FE_SRC="$SOURCE_ROOT/overmind/golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md"
GOLDEN_MOBILE_SRC="$SOURCE_ROOT/overmind/golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_project_stack_blueprint_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_project_stack_blueprint_quality.sh"

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

copy_golden() {
  local class_name="$1"
  local target_path="$2"
  case "$class_name" in
  backend) cp "$GOLDEN_BE_SRC" "$target_path" ;;
  frontend) cp "$GOLDEN_FE_SRC" "$target_path" ;;
  mobile) cp "$GOLDEN_MOBILE_SRC" "$target_path" ;;
  *) echo "unsupported class: $class_name" >&2; exit 1 ;;
  esac
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_project_stack_blueprint_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

assert_helper_status() {
  local result="$1"
  local expected_status="$2"
  local expected_output="$3"
  local status=""
  local out=""

  status="$(printf '%s\n' "$result" | head -n1)"
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "$expected_status" "$status"
  assert_contains "$out" "$expected_output"
}

test_passes_with_valid_backend_blueprint() {
  local repo_dir="$TMP_ROOT/repo-valid-backend"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "0" "quality gate passed"
}

test_passes_with_valid_frontend_blueprint() {
  local repo_dir="$TMP_ROOT/repo-valid-frontend"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_frontend.md")" "0" "quality gate passed"
}

test_passes_with_valid_mobile_blueprint() {
  local repo_dir="$TMP_ROOT/repo-valid-mobile"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden mobile "$repo_dir/project_stack_blueprint_mobile.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_mobile.md")" "0" "quality gate passed"
}

test_fails_with_helper_error_when_argument_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  local out=""
  local status=0
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_project_stack_blueprint_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "2" "$status"
  assert_contains "$out" "Missing target project stack blueprint path argument"
}

test_fails_with_helper_error_when_target_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "2" "Target project stack blueprint artifact not found"
}

test_fails_when_meta_field_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-meta"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  perl -0pi -e 's/^- group_id: .*\n//m' "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "missing or unfilled meta key: group_id"
}

test_fails_when_stack_choice_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-stack-choice"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  perl -0pi -e 's/^- rdbms: .*\n//m' "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "missing or unfilled stack choice: rdbms"
}

test_fails_when_layer_block_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-layer"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  perl -0pi -e 's/### 3\.4 API Integration/### 3.4 API Bridge/m' "$repo_dir/project_stack_blueprint_frontend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_frontend.md")" "1" "missing layer block: 3.4 API Integration"
}

test_fails_when_layer_key_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-layer-key"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden mobile "$repo_dir/project_stack_blueprint_mobile.md"
  perl -0pi -e 's/^- archetypes: ComposeScreen, SwiftUIView, NavigationGraph\n//m' "$repo_dir/project_stack_blueprint_mobile.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_mobile.md")" "1" "missing or unfilled layer key for 3.1 UI Composition: archetypes"
}

test_fails_when_last_updated_date_shape_is_invalid() {
  local repo_dir="$TMP_ROOT/repo-invalid-date"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  perl -0pi -e 's/^- last_updated: .*/- last_updated: today/m' "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "last_updated must use YYYY-MM-DD format"
}

test_fails_when_unfilled_placeholder_remains() {
  local repo_dir="$TMP_ROOT/repo-unfilled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  perl -0pi -e 's/Java 21/[UNFILLED]/' "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "artifact still contains [UNFILLED] placeholders"
}

test_passes_with_valid_backend_blueprint
test_passes_with_valid_frontend_blueprint
test_passes_with_valid_mobile_blueprint
test_fails_with_helper_error_when_argument_missing
test_fails_with_helper_error_when_target_missing
test_fails_when_meta_field_missing
test_fails_when_stack_choice_missing
test_fails_when_layer_block_missing
test_fails_when_layer_key_missing
test_fails_when_last_updated_date_shape_is_invalid
test_fails_when_unfilled_placeholder_remains

echo "All project stack blueprint quality helper tests passed."
