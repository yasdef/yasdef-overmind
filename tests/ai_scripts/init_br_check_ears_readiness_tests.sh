#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_check_ears_readiness.sh"

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
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/projects/p1/feature-a"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_br_check_ears_readiness.sh"
  chmod +x "$repo_dir/asdlc/.commands/feature_br_check_ears_readiness.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT
}

seed_feature_br_summary() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  local project_type_code="${3:-B}"
  mkdir -p "$repo_dir/asdlc/$feature_path"
  cat >"$repo_dir/asdlc/$feature_path/feature_br_summary.md" <<EOF
# Feature Business Requirements Summary

## 1. Document Meta
- feature_id: FTR-42
- project_type_code: $project_type_code
- source_type: User input
- last_updated: 2026-03-21
- ready_to_ears: false
EOF
}

seed_optional_artifacts() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  mkdir -p "$repo_dir/asdlc/$feature_path"

  cat >"$repo_dir/asdlc/$feature_path/missing_br_data.md" <<'OUT'
# Missing BR Data
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Need SLA confirmation
OUT

  cat >"$repo_dir/asdlc/$feature_path/user_br_input.md" <<'OUT'
# User Business Input
- feature_id: FTR-42
- feature_title: Approval improvements
OUT
}

write_helper_stubs() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.helper/check_task_to_br_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "user" >>"$capture_dir/helper_calls.log"
  echo "user:$1" >>"$capture_dir/helper_args.log"
fi

if [[ "${TEST_USER_HELPER_FAIL:-0}" == "1" ]]; then
  echo "business-context gate failed in user-input helper"
  exit 1
fi

echo "business-context gate passed"
OUT

  cat >"$repo_dir/asdlc/.helper/check_business_context_filled_from_repo.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "repo" >>"$capture_dir/helper_calls.log"
  echo "repo:$1" >>"$capture_dir/helper_args.log"
fi

if [[ "${TEST_REPO_HELPER_FAIL:-0}" == "1" ]]; then
  echo "quality gate failed in repo helper"
  exit 1
fi

echo "quality gate passed"
OUT

  chmod +x "$repo_dir/asdlc/.helper/check_task_to_br_quality.sh"
  chmod +x "$repo_dir/asdlc/.helper/check_business_context_filled_from_repo.sh"
}

setup_git_workspace() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  seed_feature_br_summary "$repo_dir"
  write_helper_stubs "$repo_dir"
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_br_check_ears_readiness.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_br_check_ears_readiness.sh" "$repo_dir/feature_br_check_ears_readiness.sh"
  chmod +x "$repo_dir/feature_br_check_ears_readiness.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_br_check_ears_readiness.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_user_input_helper_fails_and_does_not_run_repo_helper() {
  local repo_dir="$TMP_ROOT/repo-user-helper-fail"
  local capture_dir="$TMP_ROOT/capture-user-helper-fail"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && TEST_CAPTURE_DIR="$capture_dir" TEST_USER_HELPER_FAIL=1 .commands/feature_br_check_ears_readiness.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "User-input business-context check failed."
  assert_equal "user" "$(cat "$capture_dir/helper_calls.log")"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- ready_to_ears: false"
}

test_fails_when_repo_helper_fails_after_user_helper_passes() {
  local repo_dir="$TMP_ROOT/repo-repo-helper-fail"
  local capture_dir="$TMP_ROOT/capture-repo-helper-fail"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && TEST_CAPTURE_DIR="$capture_dir" TEST_REPO_HELPER_FAIL=1 .commands/feature_br_check_ears_readiness.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Repository business-context check failed."
  assert_equal $'user\nrepo' "$(cat "$capture_dir/helper_calls.log")"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- ready_to_ears: false"
}

test_type_a_skips_repo_helper_and_still_marks_ready() {
  local repo_dir="$TMP_ROOT/repo-type-a-success"
  local capture_dir="$TMP_ROOT/capture-type-a-success"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_workspace_layout "$repo_dir"
  seed_feature_br_summary "$repo_dir" "projects/p1/feature-a" "A"
  seed_optional_artifacts "$repo_dir"
  write_helper_stubs "$repo_dir"
  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    TEST_CAPTURE_DIR="$capture_dir" TEST_REPO_HELPER_FAIL=1 .commands/feature_br_check_ears_readiness.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Skipping repository business-context readiness gate for type A project."
  assert_contains "$out" "EARS readiness check passed."
  assert_equal "user" "$(cat "$capture_dir/helper_calls.log")"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- ready_to_ears: true"
}

test_success_updates_ready_to_ears_and_commits_feature_artifacts() {
  local repo_dir="$TMP_ROOT/repo-success"
  local capture_dir="$TMP_ROOT/capture-success"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  seed_optional_artifacts "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    TEST_CAPTURE_DIR="$capture_dir" .commands/feature_br_check_ears_readiness.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "EARS readiness check passed."
  assert_equal $'user\nrepo' "$(cat "$capture_dir/helper_calls.log")"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/missing_br_data.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- ready_to_ears: true"

  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/missing_br_data.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/user_br_input.md"
}

test_success_supports_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-success-absolute-feature-path"
  local capture_dir="$TMP_ROOT/capture-success-absolute-feature-path"
  local feature_path="projects/p1/custom-folder"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  seed_feature_br_summary "$repo_dir" "$feature_path"
  seed_optional_artifacts "$repo_dir" "$feature_path"

  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    TEST_CAPTURE_DIR="$capture_dir" .commands/feature_br_check_ears_readiness.sh --feature_path "$absolute_feature_path"
  )"

  assert_contains "$out" "EARS readiness check passed."
  assert_contains "$(cat "$repo_dir/asdlc/$feature_path/feature_br_summary.md")" "- ready_to_ears: true"
  assert_contains "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")" "- ready_to_ears: false"
  assert_contains "$(cat "$capture_dir/helper_args.log")" "$absolute_feature_path/feature_br_summary.md"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_user_input_helper_fails_and_does_not_run_repo_helper
test_fails_when_repo_helper_fails_after_user_helper_passes
test_type_a_skips_repo_helper_and_still_marks_ready
test_success_updates_ready_to_ears_and_commits_feature_artifacts
test_success_supports_absolute_feature_path

echo "All EARS readiness initializer tests passed."
