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
  echo "seed" >"$repo_dir/README.md"
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

CROSS_CLASS_PLACEHOLDER='<to be defined during first feature implementation plan>'

strip_section_5() {
  local target_path="$1"
  perl -0pi -e 's/\n## 5\. Cross-Class Transport\/Contract Approach\n(?:[^\n]*\n)+//s' "$target_path"
}

append_section_5() {
  local target_path="$1"
  local transport="$2"
  local schema="$3"
  local approved="$4"
  strip_section_5 "$target_path"
  cat >>"$target_path" <<EOF

## 5. Cross-Class Transport/Contract Approach
- transport_protocol: $transport
- schema_format: $schema
- user_approved: $approved
EOF
}

append_section_5_populated() {
  append_section_5 "$1" "REST" "OpenAPI 3.1" "true"
}

append_section_5_placeholdered() {
  append_section_5 "$1" "$CROSS_CLASS_PLACEHOLDER" "$CROSS_CLASS_PLACEHOLDER" "false"
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

test_passes_with_section_5_populated_when_peer_exists() {
  local repo_dir="$TMP_ROOT/repo-s5-populated"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  append_section_5_populated "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "0" "quality gate passed"
}

test_passes_with_section_5_placeholdered_when_peer_exists() {
  local repo_dir="$TMP_ROOT/repo-s5-placeholdered"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  append_section_5_placeholdered "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "0" "quality gate passed"
}

test_fails_when_section_5_missing_with_peer() {
  local repo_dir="$TMP_ROOT/repo-s5-missing"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  strip_section_5 "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "missing section: ## 5. Cross-Class Transport/Contract Approach"
}

test_fails_when_frontend_carries_section_5() {
  local repo_dir="$TMP_ROOT/repo-fe-with-s5"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  append_section_5_populated "$repo_dir/project_stack_blueprint_frontend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_frontend.md")" "1" "forbidden in frontend blueprint"
}

test_fails_when_mobile_carries_section_5() {
  local repo_dir="$TMP_ROOT/repo-mobile-with-s5"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden mobile "$repo_dir/project_stack_blueprint_mobile.md"
  append_section_5_populated "$repo_dir/project_stack_blueprint_mobile.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_mobile.md")" "1" "forbidden in mobile blueprint"
}

test_fails_when_section_5_concrete_protocol_with_placeholder_schema() {
  local repo_dir="$TMP_ROOT/repo-s5-mixed-1"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  append_section_5 "$repo_dir/project_stack_blueprint_backend.md" "REST" "$CROSS_CLASS_PLACEHOLDER" "false"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "§5 mixed state"
}

test_fails_when_section_5_placeholder_protocol_with_concrete_schema() {
  local repo_dir="$TMP_ROOT/repo-s5-mixed-2"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  append_section_5 "$repo_dir/project_stack_blueprint_backend.md" "$CROSS_CLASS_PLACEHOLDER" "OpenAPI 3.1" "false"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "§5 mixed state"
}

test_fails_when_section_5_user_approved_true_with_placeholder() {
  local repo_dir="$TMP_ROOT/repo-s5-bad-approval"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  append_section_5 "$repo_dir/project_stack_blueprint_backend.md" "$CROSS_CLASS_PLACEHOLDER" "$CROSS_CLASS_PLACEHOLDER" "true"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "1" "user_approved=true is invalid when transport_protocol or schema_format carries the placeholder"
}

test_passes_with_backend_and_two_peers() {
  local repo_dir="$TMP_ROOT/repo-be-fe-mobile"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  copy_golden mobile "$repo_dir/project_stack_blueprint_mobile.md"
  append_section_5_populated "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "0" "quality gate passed"
  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_frontend.md")" "0" "quality gate passed"
  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_mobile.md")" "0" "quality gate passed"
}

test_passes_when_no_active_backend() {
  local repo_dir="$TMP_ROOT/repo-no-backend"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  # FE + Mobile only; no §5 anywhere
  copy_golden frontend "$repo_dir/project_stack_blueprint_frontend.md"
  copy_golden mobile "$repo_dir/project_stack_blueprint_mobile.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_frontend.md")" "0" "quality gate passed"
  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_mobile.md")" "0" "quality gate passed"
}

test_passes_with_lone_backend_no_other_class() {
  local repo_dir="$TMP_ROOT/repo-lone-backend"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  # Only backend, no peer → §5 not required
  copy_golden backend "$repo_dir/project_stack_blueprint_backend.md"

  assert_helper_status "$(run_helper "$repo_dir" "project_stack_blueprint_backend.md")" "0" "quality gate passed"
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
test_passes_with_section_5_populated_when_peer_exists
test_passes_with_section_5_placeholdered_when_peer_exists
test_fails_when_section_5_missing_with_peer
test_fails_when_frontend_carries_section_5
test_fails_when_mobile_carries_section_5
test_fails_when_section_5_concrete_protocol_with_placeholder_schema
test_fails_when_section_5_placeholder_protocol_with_concrete_schema
test_fails_when_section_5_user_approved_true_with_placeholder
test_passes_with_backend_and_two_peers
test_passes_when_no_active_backend
test_passes_with_lone_backend_no_other_class

echo "All project stack blueprint quality helper tests passed."
