#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASS_REPO_PATHS_LIB_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/class_repo_paths.sh"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# shellcheck source=/dev/null
source "$CLASS_REPO_PATHS_LIB_SRC"

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

assert_zero_status() {
  local status="$1"
  if [[ "$status" -ne 0 ]]; then
    echo "Assertion failed: expected zero status, got $status" >&2
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

setup_git_repo() {
  local repo_path="$1"
  mkdir -p "$repo_path"
  git -C "$repo_path" init >/dev/null 2>&1
}

write_definition() {
  local definition_path="$1"
  local class_entries="$2"

  cat >"$definition_path" <<EOF_DEF
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
  project_type_code: "B"
  class_repo_paths:
$class_entries

steps: []
EOF_DEF
}

run_validator() {
  local definition_path="$1"
  local target_class="${2:-}"
  local out=""
  local status=0

  set +e
  if [[ -n "$target_class" ]]; then
    out="$(class_repo_paths_validate_coherence "$definition_path" "$target_class" 2>&1)"
  else
    out="$(class_repo_paths_validate_coherence "$definition_path" 2>&1)"
  fi
  status=$?
  set -e

  VALIDATOR_STATUS="$status"
  VALIDATOR_OUTPUT="$out"
}

test_ready_valid_git_repo_passes() {
  local repo_path="$TMP_ROOT/ready-valid-repo"
  local definition_path="$TMP_ROOT/ready-valid.yaml"
  setup_git_repo "$repo_path"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"$repo_path\""

  run_validator "$definition_path"

  assert_zero_status "$VALIDATOR_STATUS"
}

test_ready_empty_path_fails() {
  local definition_path="$TMP_ROOT/ready-empty-path.yaml"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"\""

  run_validator "$definition_path"

  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'backend'"
  assert_contains "$VALIDATOR_OUTPUT" "state ready requires non-empty path"
}

test_ready_path_not_directory_fails() {
  local definition_path="$TMP_ROOT/ready-path-not-directory.yaml"
  local missing_path="$TMP_ROOT/missing-repo"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"$missing_path\""

  run_validator "$definition_path"

  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'backend'"
  assert_contains "$VALIDATOR_OUTPUT" "path is not an existing directory"
}

test_ready_directory_without_git_fails() {
  local definition_path="$TMP_ROOT/ready-no-git.yaml"
  local repo_path="$TMP_ROOT/ready-no-git"
  mkdir -p "$repo_path"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"$repo_path\""

  run_validator "$definition_path"

  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'backend'"
  assert_contains "$VALIDATOR_OUTPUT" "path does not contain .git"
}

test_deferred_no_path_passes() {
  local definition_path="$TMP_ROOT/deferred-no-path.yaml"
  write_definition "$definition_path" "    frontend:
      state: \"deferred\""

  run_validator "$definition_path"

  assert_zero_status "$VALIDATOR_STATUS"
}

test_deferred_non_empty_path_fails() {
  local definition_path="$TMP_ROOT/deferred-with-path.yaml"
  write_definition "$definition_path" "    frontend:
      state: \"deferred\"
      path: \"$TMP_ROOT/future-repo\""

  run_validator "$definition_path"

  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'frontend'"
  assert_contains "$VALIDATOR_OUTPUT" "state deferred requires empty or absent path"
}

test_unknown_state_fails() {
  local definition_path="$TMP_ROOT/unknown-state.yaml"
  write_definition "$definition_path" "    backend:
      state: \"attached\""

  run_validator "$definition_path"

  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'backend'"
  assert_contains "$VALIDATOR_OUTPUT" "state must be ready or deferred"
}

test_policy_x_fails() {
  local repo_path="$TMP_ROOT/policy-x-repo"
  local definition_path="$TMP_ROOT/policy-x.yaml"
  setup_git_repo "$repo_path"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"$repo_path\"
      policy: \"X\""

  run_validator "$definition_path"

  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'backend'"
  assert_contains "$VALIDATOR_OUTPUT" "policy must be B or C"
}

test_policy_c_passes() {
  local repo_path="$TMP_ROOT/policy-c-repo"
  local definition_path="$TMP_ROOT/policy-c.yaml"
  setup_git_repo "$repo_path"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"$repo_path\"
      policy: \"C\""

  run_validator "$definition_path"

  assert_zero_status "$VALIDATOR_STATUS"
}

test_scoped_single_class_validates_only_named_class() {
  local repo_path="$TMP_ROOT/scoped-valid-repo"
  local definition_path="$TMP_ROOT/scoped.yaml"
  setup_git_repo "$repo_path"
  write_definition "$definition_path" "    backend:
      state: \"ready\"
      path: \"$repo_path\"
    frontend:
      state: \"deferred\"
      path: \"$TMP_ROOT/future-frontend\""

  run_validator "$definition_path" "backend"
  assert_zero_status "$VALIDATOR_STATUS"

  run_validator "$definition_path"
  assert_nonzero_status "$VALIDATOR_STATUS"
  assert_contains "$VALIDATOR_OUTPUT" "class 'frontend'"
}

test_ready_valid_git_repo_passes
test_ready_empty_path_fails
test_ready_path_not_directory_fails
test_ready_directory_without_git_fails
test_deferred_no_path_passes
test_deferred_non_empty_path_fails
test_unknown_state_fails
test_policy_x_fails
test_policy_c_passes
test_scoped_single_class_validates_only_named_class

echo "All class_repo_paths coherence tests passed."
