#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LISTER_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/list_committed_sibling_features.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains_line() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fxq "$needle" <<<"$haystack"; then
    echo "Assertion failed: expected output to contain line: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_not_contains_line() {
  local haystack="$1"
  local needle="$2"
  if grep -Fxq "$needle" <<<"$haystack"; then
    echo "Assertion failed: expected output to not contain line: $needle" >&2
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

write_plan() {
  local plan_path="$1"
  local checklist="$2"
  cat >"$plan_path" <<EOF
# Implementation Plan

### Step 1.1 Backend work [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
$checklist
EOF
}

make_project_features() {
  local project_dir="$1"
  mkdir -p \
    "$project_dir/0001-current" \
    "$project_dir/0002-zero-implemented" \
    "$project_dir/0003-half-implemented" \
    "$project_dir/0004-fully-checked" \
    "$project_dir/0005-no-plan"

  write_plan "$project_dir/0001-current/implementation_plan.md" "- [ ] Current feature step"
  write_plan "$project_dir/0002-zero-implemented/implementation_plan.md" "- [ ] Planned but not started"
  write_plan "$project_dir/0003-half-implemented/implementation_plan.md" "- [x] First checklist item
- [ ] Second checklist item"
  write_plan "$project_dir/0004-fully-checked/implementation_plan.md" "- [x] Fully complete"
}

test_lists_sibling_folders_with_any_plan_and_excludes_self() {
  local project_dir="$TMP_ROOT/asdlc/projects/p1"
  make_project_features "$project_dir"

  local out=""
  out="$("$LISTER_SRC" --feature_path "$project_dir/0001-current")"

  assert_contains_line "$out" "0002-zero-implemented"
  assert_contains_line "$out" "0003-half-implemented"
  assert_contains_line "$out" "0004-fully-checked"
  assert_not_contains_line "$out" "0001-current"
  assert_not_contains_line "$out" "0005-no-plan"
  echo "PASS: sibling folders with any implementation_plan.md are listed"
}

test_empty_output_exits_zero_when_no_siblings_qualify() {
  local project_dir="$TMP_ROOT/asdlc/projects/p2"
  mkdir -p "$project_dir/current" "$project_dir/without-plan"
  write_plan "$project_dir/current/implementation_plan.md" "- [ ] Current feature step"

  local status=0
  local out=""
  set +e
  out="$("$LISTER_SRC" --feature_path "$project_dir/current")"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_equal "" "$out"
  echo "PASS: no qualifying siblings returns empty output and exits 0"
}

test_missing_feature_path_argument_is_rejected() {
  local status=0
  local out=""
  set +e
  out="$("$LISTER_SRC" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  if [[ "$out" != *"Missing required argument: --feature_path"* ]]; then
    echo "Assertion failed: expected missing argument error" >&2
    echo "$out" >&2
    exit 1
  fi
  echo "PASS: missing --feature_path argument is rejected"
}

test_lists_sibling_folders_with_any_plan_and_excludes_self
test_empty_output_exits_zero_when_no_siblings_qualify
test_missing_feature_path_argument_is_rejected

echo "All list_committed_sibling_features tests passed."
