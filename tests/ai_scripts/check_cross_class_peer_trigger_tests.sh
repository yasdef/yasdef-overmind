#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_cross_class_peer_trigger.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="${3:-assertion}"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed ($label): expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_status() {
  local expected="$1"
  local actual="$2"
  local label="${3:-status}"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed ($label): expected status $expected, got $actual" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Assertion failed: expected output to contain: $needle" >&2
    echo "Actual: $haystack" >&2
    exit 1
  fi
}

write_definition() {
  local target="$1"
  local project_type_code="$2"
  shift 2
  local classes=("$@")
  {
    echo "meta_info:"
    echo "  project_id: \"sample\""
    echo "  project_classes:"
    local class=""
    for class in "${classes[@]}"; do
      echo "    - $class"
    done
    echo "  project_type_code: \"$project_type_code\""
    echo "  project_type_label: \"Generated\""
    echo "  class_repo_paths: {}"
    echo
    echo "steps: []"
  } >"$target"
}

write_definition_inline_classes() {
  local target="$1"
  local project_type_code="$2"
  local inline="$3"
  cat >"$target" <<EOF_DEF
meta_info:
  project_id: "sample"
  project_classes: [$inline]
  project_type_code: "$project_type_code"
  project_type_label: "Generated"
  class_repo_paths: {}

steps: []
EOF_DEF
}

run_helper() {
  local target="$1"
  "$HELPER_SRC" "$target"
}

test_type_a_backend_frontend_active() {
  local def="$TMP_ROOT/def-a-be-fe.yaml"
  write_definition "$def" "A" "backend" "frontend"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: active" "$out" "A be+fe"
}

test_type_a_backend_mobile_active() {
  local def="$TMP_ROOT/def-a-be-mobile.yaml"
  write_definition "$def" "A" "backend" "mobile"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: active" "$out" "A be+mobile"
}

test_type_a_inline_classes_active() {
  local def="$TMP_ROOT/def-a-inline.yaml"
  write_definition_inline_classes "$def" "A" "backend, frontend"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: active" "$out" "A inline be+fe"
}

test_type_a_lone_backend_inactive() {
  local def="$TMP_ROOT/def-a-lone-backend.yaml"
  write_definition "$def" "A" "backend"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: inactive" "$out" "A lone backend"
}

test_type_a_no_active_backend_inactive() {
  local def="$TMP_ROOT/def-a-no-backend.yaml"
  write_definition "$def" "A" "frontend"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: inactive" "$out" "A frontend-only"
}

test_type_a_no_classes_inactive() {
  local def="$TMP_ROOT/def-a-no-classes.yaml"
  write_definition_inline_classes "$def" "A" ""
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: inactive" "$out" "A no classes"
}

test_type_b_inactive() {
  local def="$TMP_ROOT/def-b.yaml"
  write_definition "$def" "B" "backend" "frontend"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: inactive" "$out" "B be+fe"
}

test_type_c_inactive() {
  local def="$TMP_ROOT/def-c.yaml"
  write_definition "$def" "C" "backend" "frontend"
  local out
  out="$(run_helper "$def")"
  assert_equal "cross_class_peer_trigger: inactive" "$out" "C be+fe"
}

test_missing_argument_fails() {
  local out
  local status=0
  set +e
  out="$("$HELPER_SRC" 2>&1)"
  status=$?
  set -e
  assert_status 2 "$status" "missing argument"
  assert_contains "$out" "Missing init_progress_definition.yaml path argument."
}

test_missing_target_file_fails() {
  local missing="$TMP_ROOT/does-not-exist.yaml"
  local out
  local status=0
  set +e
  out="$("$HELPER_SRC" "$missing" 2>&1)"
  status=$?
  set -e
  assert_status 2 "$status" "missing file"
  assert_contains "$out" "Target init progress definition not found"
}

test_type_a_backend_frontend_active
test_type_a_backend_mobile_active
test_type_a_inline_classes_active
test_type_a_lone_backend_inactive
test_type_a_no_active_backend_inactive
test_type_a_no_classes_inactive
test_type_b_inactive
test_type_c_inactive
test_missing_argument_fails
test_missing_target_file_fails

echo "All cross-class peer trigger helper tests passed."
