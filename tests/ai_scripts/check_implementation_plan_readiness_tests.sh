#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/check_implementation_plan_readiness.sh"

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

make_feature_dir() {
  local name="$1"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

test_parseable_plan_exits_zero() {
  local feature_dir=""
  feature_dir="$(make_feature_dir "parseable")"

  cat >"$feature_dir/implementation_plan.md" <<'EOF'
# Implementation Plan

### Step 1.1 Backend work [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
- [ ] Implement backend work

### Step 1.2 Frontend work [REQ-2]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-2
- [ ] Implement frontend work
EOF

  local status=0
  set +e
  "$HELPER_SRC" --feature_path "$feature_dir" 2>&1
  status=$?
  set -e
  assert_zero_status "$status"
  echo "PASS: parseable plan exits 0"
}

test_missing_plan_file_exits_nonzero() {
  local feature_dir=""
  feature_dir="$(make_feature_dir "no-plan")"

  local status=0
  local out=""
  set +e
  out="$("$HELPER_SRC" --feature_path "$feature_dir" 2>&1)"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: required file not found"
  echo "PASS: missing plan file exits non-zero"
}

test_missing_repo_metadata_exits_nonzero() {
  local feature_dir=""
  feature_dir="$(make_feature_dir "missing-repo")"

  cat >"$feature_dir/implementation_plan.md" <<'EOF'
# Implementation Plan

### Step 1.1 Backend work [REQ-1]
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
- [ ] Missing repo metadata
EOF

  local status=0
  local out=""
  set +e
  out="$("$HELPER_SRC" --feature_path "$feature_dir" 2>&1)"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: step 1 is missing #### Repo: metadata"
  echo "PASS: missing #### Repo: exits non-zero"
}

test_no_step_blocks_exits_nonzero() {
  local feature_dir=""
  feature_dir="$(make_feature_dir "no-steps")"

  cat >"$feature_dir/implementation_plan.md" <<'EOF'
# Implementation Plan

No steps here, just prose.
EOF

  local status=0
  local out=""
  set +e
  out="$("$HELPER_SRC" --feature_path "$feature_dir" 2>&1)"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: expected at least one ### Step block"
  echo "PASS: no ### Step blocks exits non-zero"
}

test_unsupported_repo_class_exits_nonzero() {
  local feature_dir=""
  feature_dir="$(make_feature_dir "bad-class")"

  cat >"$feature_dir/implementation_plan.md" <<'EOF'
# Implementation Plan

### Step 1.1 Some work [REQ-1]
#### Repo: database
#### Evidence: gap/TECH_REQ-1
- [ ] Do something
EOF

  local status=0
  local out=""
  set +e
  out="$("$HELPER_SRC" --feature_path "$feature_dir" 2>&1)"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: step 1 has unsupported repo class"
  echo "PASS: unsupported repo class exits non-zero"
}

test_duplicate_repo_in_step_exits_nonzero() {
  local feature_dir=""
  feature_dir="$(make_feature_dir "dup-repo")"

  cat >"$feature_dir/implementation_plan.md" <<'EOF'
# Implementation Plan

### Step 1.1 Some work [REQ-1]
#### Repo: backend
#### Repo: frontend
#### Evidence: gap/TECH_REQ-1
- [ ] Do something
EOF

  local status=0
  local out=""
  set +e
  out="$("$HELPER_SRC" --feature_path "$feature_dir" 2>&1)"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: step 1 declares #### Repo: more than once"
  echo "PASS: duplicate #### Repo: in step exits non-zero"
}

test_missing_feature_path_argument_is_rejected() {
  local status=0
  local out=""
  set +e
  out="$("$HELPER_SRC" 2>&1)"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path"
  echo "PASS: missing --feature_path argument is rejected"
}

test_parseable_plan_exits_zero
test_missing_plan_file_exits_nonzero
test_missing_repo_metadata_exits_nonzero
test_no_step_blocks_exits_nonzero
test_unsupported_repo_class_exits_nonzero
test_duplicate_repo_in_step_exits_nonzero
test_missing_feature_path_argument_is_rejected

echo "All check_implementation_plan_readiness tests passed."
