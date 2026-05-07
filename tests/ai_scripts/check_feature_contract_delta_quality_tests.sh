#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_feature_contract_delta_quality.sh"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_feature_contract_delta_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_feature_contract_delta_quality.sh"
  echo "seed" >"$repo_dir/README.md"
}

write_valid_delta_needed_true() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- feature_id: FEAT-1
- feature_title: Delta-enabled feature
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- delta_needed: true
- last_updated: 2026-04-07

## 2. Delta Summary
- baseline_reference: baseline v1
- feature_intent: Add feature-specific contract fields.
- impacted_tracks: backend, frontend
- no_delta_reason: none

## 3. Contract Delta Items
### Delta 1: add-field-x
- delta_kind: add
- related_baseline_contract: customer-profile
- change_scope: add optional field x in profile response
- compatibility_impact: additive only
- verification_expectation: contract tests for field x

## 4. Track Handoff Signals
- backend_handoff: implement field x in response serializer
- frontend_mobile_handoff: consume field x when present
OUT
}

write_valid_delta_needed_false() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- feature_id: FEAT-2
- feature_title: No-delta feature
- project_type_code: C
- source_requirements_ears: projects/p1/feature-b/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- delta_needed: false
- last_updated: 2026-04-07

## 2. Delta Summary
- baseline_reference: baseline v1
- feature_intent: Feature uses existing stable contracts only.
- impacted_tracks: backend, frontend
- no_delta_reason: Existing baseline already covers feature interactions.

## 3. Contract Delta Items
- no_contract_delta_required: true

## 4. Track Handoff Signals
- backend_handoff: no shared contract work needed, proceed with existing baseline
- frontend_mobile_handoff: no shared contract work needed, proceed with existing baseline
OUT
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_feature_contract_delta_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

test_passes_with_valid_delta_needed_true() {
  local repo_dir="$TMP_ROOT/repo-pass-delta-true"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_delta_needed_true "$repo_dir/feature_contract_delta.md"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_explicit_no_delta() {
  local repo_dir="$TMP_ROOT/repo-pass-no-delta"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_delta_needed_false "$repo_dir/feature_contract_delta.md"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_with_helper_error_when_target_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Target feature contract delta artifact not found"
}

test_fails_with_content_error_when_target_empty() {
  local repo_dir="$TMP_ROOT/repo-empty-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  : >"$repo_dir/feature_contract_delta.md"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "target feature contract delta artifact is empty"
}

test_fails_when_delta_needed_true_but_no_delta_blocks() {
  local repo_dir="$TMP_ROOT/repo-delta-true-without-block"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_delta_needed_false "$repo_dir/feature_contract_delta.md"
  perl -0pi -e 's/delta_needed: false/delta_needed: true/g; s/no_contract_delta_required: true/no_contract_delta_required: false/g' "$repo_dir/feature_contract_delta.md"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "delta_needed is true but no Delta blocks were found in section 3"
}

test_fails_when_delta_needed_false_without_explicit_marker() {
  local repo_dir="$TMP_ROOT/repo-no-delta-without-marker"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_delta_needed_false "$repo_dir/feature_contract_delta.md"
  perl -0pi -e 's/no_contract_delta_required: true/no_contract_delta_required: false/g' "$repo_dir/feature_contract_delta.md"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "delta_needed is false but section 3 does not declare - no_contract_delta_required: true"
}

test_fails_when_unfilled_placeholders_exist() {
  local repo_dir="$TMP_ROOT/repo-unfilled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_delta_needed_true "$repo_dir/feature_contract_delta.md"
  perl -0pi -e 's/- verification_expectation: .*/- verification_expectation: [UNFILLED]/g' "$repo_dir/feature_contract_delta.md"

  local result=""
  result="$(run_helper "$repo_dir" "feature_contract_delta.md")"
  local status=""
  status="$(printf '%s\n' "$result" | head -n1)"
  local out=""
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "artifact still contains [UNFILLED] placeholders"
}

test_passes_with_valid_delta_needed_true
test_passes_with_explicit_no_delta
test_fails_with_helper_error_when_target_missing
test_fails_with_content_error_when_target_empty
test_fails_when_delta_needed_true_but_no_delta_blocks
test_fails_when_delta_needed_false_without_explicit_marker
test_fails_when_unfilled_placeholders_exist

echo "All feature contract delta quality helper tests passed."
