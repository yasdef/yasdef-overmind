#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_requirements_ears_quality.sh"

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
  mkdir -p "$repo_dir/overmind/scripts/helper" "$repo_dir/overmind/product"
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_requirements_ears_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_requirements_ears_quality.sh"

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

write_valid_ears() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - Create task
**User Story:** As a user, I want to create a task, so that work can be tracked.

**Acceptance Criteria (EARS):**
- WHEN a create-task request is submitted, THE System SHALL create a task record.

**Verification:** API test for create-task success.

### Requirement 2 - Reject invalid create request
**User Story:** As a client developer, I want deterministic validation failures, so that I can handle bad requests.

**Acceptance Criteria (EARS):**
- IF a create-task request is missing a title, THEN THE System SHALL reject the request with a validation error.

**Verification:** API test for create-task validation failure.

## Non-Functional Requirements

### NFR 1 - Query latency
**User Story:** As a user, I want fast queries, so that UI response remains smooth.

**Acceptance Criteria (EARS):**
- THE System SHALL return task-list responses within 300 ms at p95.

**Verification:** Performance test report for p95 latency.
OUT
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_requirements_ears_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

test_passes_with_valid_content() {
  local repo_dir="$TMP_ROOT/repo-pass"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_ears "$repo_dir/overmind/product/requirements_ears.md"

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_with_helper_error_when_target_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Target EARS requirements not found"
}

test_fails_with_helper_error_when_target_argument_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-target-arg"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_requirements_ears_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "2" "$status"
  assert_contains "$out" "Missing target requirements path argument."
}

test_fails_with_content_error_when_target_empty() {
  local repo_dir="$TMP_ROOT/repo-empty-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  : >"$repo_dir/overmind/product/requirements_ears.md"

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "target EARS requirements is empty"
}

test_fails_when_required_field_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-field"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/overmind/product/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - Missing user story
**Acceptance Criteria (EARS):**
- WHEN a request is submitted, THE System SHALL process it.

**Verification:** API test for request processing.
OUT

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "missing User Story"
}

test_fails_when_requirement_numbering_is_duplicated() {
  local repo_dir="$TMP_ROOT/repo-duplicate-number"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/overmind/product/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - First
**User Story:** As a user, I want first behavior, so that flow starts.

**Acceptance Criteria (EARS):**
- WHEN first event occurs, THE System SHALL perform first behavior.

**Verification:** First behavior test.

### Requirement 1 - Duplicate
**User Story:** As a user, I want duplicate behavior, so that numbering collision is visible.

**Acceptance Criteria (EARS):**
- WHEN second event occurs, THE System SHALL perform second behavior.

**Verification:** Second behavior test.
OUT

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "duplicate Requirement numbering"
}

test_passes_with_valid_content
test_fails_with_helper_error_when_target_missing
test_fails_with_helper_error_when_target_argument_missing
test_fails_with_content_error_when_target_empty
test_fails_when_required_field_missing
test_fails_when_requirement_numbering_is_duplicated

echo "All requirements EARS quality helper tests passed."
