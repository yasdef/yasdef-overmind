#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_implementation_slices_quality.sh"
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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_implementation_slices_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_implementation_slices_quality.sh"

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

write_project_definition() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/projects/p1"
  cat >"$repo_dir/projects/p1/init_progress_definition.yaml" <<'OUT'
meta_info:
  project_id: "p1"
  project_classes:
    - backend
    - frontend
    - mobile
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
steps: []
OUT
}

write_requirements() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  cat >"$repo_dir/projects/p1/feature-a/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 4
- WHEN order is created, THE System SHALL persist it.

### Requirement 6
- WHEN order is queried, THE System SHALL return projection data.

### NFR 1
- WHEN order queries run under normal load, THE System SHALL stay within the agreed latency budget.
OUT
}

write_technical_requirements() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/technical_requirements.md" <<'OUT'
# Technical Requirements

## 4. Requirement Coverage and Gaps
### Requirement: REQ-4
- gap_status: partially_implemented
- gap_to_close: complete client mapping

### Requirement: REQ-6
- gap_status: partially_implemented
- gap_to_close: complete backend query mapping

### Requirement: NFR-1
- gap_status: unclear
- gap_to_close: confirm and add latency-focused verification for the query path

## 5. Impacted Components
### Component: backend order query controller
- repo: backend
- gap_to_close: complete mapping and tests

### Component: frontend order projection client
- repo: frontend
- gap_to_close: complete adapter mapping and tests
OUT
}

write_feature_contract_delta() {
  local repo_dir="$1"
  cat >"$repo_dir/projects/p1/feature-a/feature_contract_delta.md" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- delta_needed: true
OUT
}

write_valid_slices() {
  local repo_dir="$1"
  cp "$GOLDEN_SRC" "$repo_dir/projects/p1/feature-a/implementation_slices.md"
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_implementation_slices_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

setup_valid_fixture() {
  local repo_dir="$1"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_project_definition "$repo_dir"
  write_requirements "$repo_dir"
  write_technical_requirements "$repo_dir"
  write_feature_contract_delta "$repo_dir"
  write_valid_slices "$repo_dir"
}

test_passes_with_valid_slices_artifact() {
  local repo_dir="$TMP_ROOT/repo-pass"
  setup_valid_fixture "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_technical_requirements_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-technical"
  setup_valid_fixture "$repo_dir"
  rm -f "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Required sibling artifact not found for quality check: projects/p1/feature-a/technical_requirements.md"
}

test_fails_when_ordering_scope_is_invalid() {
  local repo_dir="$TMP_ROOT/repo-invalid-ordering"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/ordering_scope: local_prerequisites_only/ordering_scope: full_global_order/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "ordering_scope must be local_prerequisites_only"
}

test_fails_when_slice_repo_is_not_active() {
  local repo_dir="$TMP_ROOT/repo-invalid-repo"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- repo: mobile/- repo: infrastructure/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "uses repo outside active project classes"
}

test_fails_when_slice_contains_lifecycle_boilerplate_bullet() {
  local repo_dir="$TMP_ROOT/repo-boilerplate-bullet"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- \[ \] Implement read service \+ repository wiring for projection-backed query/- [ ] Plan and discuss the slice/' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "contains forbidden lifecycle boilerplate bullet: Plan and discuss the slice"
}

test_fails_when_no_planned_slice_exists() {
  local repo_dir="$TMP_ROOT/repo-no-planned"
  setup_valid_fixture "$repo_dir"
  perl -0pi -e 's/- status: planned/- status: existing/g' "$repo_dir/projects/p1/feature-a/implementation_slices.md"

  local result=""
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/implementation_slices.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "must contain at least one planned slice"
}

test_passes_with_valid_slices_artifact
test_fails_when_technical_requirements_is_missing
test_fails_when_ordering_scope_is_invalid
test_fails_when_slice_repo_is_not_active
test_fails_when_slice_contains_lifecycle_boilerplate_bullet
test_fails_when_no_planned_slice_exists

echo "All implementation slices quality helper tests passed."
