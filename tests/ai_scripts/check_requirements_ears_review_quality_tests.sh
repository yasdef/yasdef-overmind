#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_requirements_ears_review_quality.sh"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_requirements_ears_review_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_requirements_ears_review_quality.sh"
  echo "seed" >"$repo_dir/README.md"
}

write_valid_review() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
# Requirements EARS Extra Review

## 1. Document Meta
- feature_id: FEAT-REVIEW-001
- feature_title: Payments access review
- source_user_br_input: overmind/product/user_br_input.md
- source_requirements_ears: overmind/product/requirements_ears.md
- review_status: complete
- last_updated: 2026-04-11

## 2. Review Guidance
- completion_rule: Set review_status complete only when every finding is terminal.
- pending_state: escalated
- allowed_severity: High, Medium, Low
- user_question_format: Here is the finding: <finding summary>. I would recommend: <recommended change>. Should I add recommended changes? Please answer yes/no or provide your answer.

## 3. Findings Ledger
### Finding 1 - Close missing ACTIVE guard
- severity: Medium
- state: added to ears
- source_feature_story_reference: user_br_input.md -> access guard notes
- related_requirement_targets: Requirement 8, Requirement 10
- gap_summary: ACTIVE was missing after authentication.
- recommendation: Add explicit ACTIVE post-auth guard.
- suggested_ears_change: Update the affected requirements and add a new guard requirement if needed.
- user_prompt: Here is the finding: ACTIVE was missing after authentication. I would recommend: add explicit ACTIVE post-auth guard behavior in requirements_ears.md. Should I add recommended changes? Please answer yes/no or provide your answer.
- user_response: yes
- resolution_notes: Added ACTIVE guard wording to the affected requirements.
OUT
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_requirements_ears_review_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

test_passes_with_valid_content() {
  local repo_dir="$TMP_ROOT/repo-pass"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_review "$repo_dir/overmind/product/requirements_ears_review.md"

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears_review.md")"
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
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears_review.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Target requirements ears review artifact not found"
}

test_fails_with_helper_error_when_target_argument_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_requirements_ears_review_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "2" "$status"
  assert_contains "$out" "Missing target requirements ears review path argument."
}

test_fails_when_state_is_invalid() {
  local repo_dir="$TMP_ROOT/repo-invalid-state"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_review "$repo_dir/overmind/product/requirements_ears_review.md"
  perl -0pi -e 's/- state: added to ears/- state: pending/g' "$repo_dir/overmind/product/requirements_ears_review.md"

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears_review.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "invalid state"
}

test_fails_when_complete_review_still_has_escalated_finding() {
  local repo_dir="$TMP_ROOT/repo-escalated-complete"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_review "$repo_dir/overmind/product/requirements_ears_review.md"
  perl -0pi -e 's/- state: added to ears/- state: escalated/g' "$repo_dir/overmind/product/requirements_ears_review.md"

  local result
  result="$(run_helper "$repo_dir" "overmind/product/requirements_ears_review.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "review_status is complete but escalated findings remain"
}

test_passes_with_valid_content
test_fails_with_helper_error_when_target_missing
test_fails_with_helper_error_when_target_argument_missing
test_fails_when_state_is_invalid
test_fails_when_complete_review_still_has_escalated_finding

echo "All requirements EARS review quality helper tests passed."
