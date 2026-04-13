#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_task_to_br_quality.sh"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_task_to_br_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_task_to_br_quality.sh"

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

write_complete_summary() {
  local repo_dir="$1"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 14. Assumptions
### Needs validation
- assumptions_needing_validation: [UNFILLED]

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT
}

test_helper_passes_when_required_fields_fr_and_br_exist() {
  local repo_dir="$TMP_ROOT/repo-helper-pass"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_complete_summary "$repo_dir"

  local out
  out="$(
    cd "$repo_dir" &&
    overmind/scripts/helper/check_task_to_br_quality.sh
  )"

  assert_contains "$out" "business-context gate passed"
}

test_helper_fails_with_exit_code_1_when_required_business_goal_is_missing() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-business-goal"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: [UNFILLED]

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: ### 3.1 Business goal -> primary_business_goal is unfilled"
}

test_helper_fails_with_exit_code_1_when_no_populated_fr_exists() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-fr"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: [UNFILLED]

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: ## 6. Functional Requirements -> at least one meaningful one-line FR item (\`- FR-N: ...\`) is required"
}

test_helper_fails_with_exit_code_1_when_no_populated_br_exists() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-br"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: [UNFILLED]

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: ## 7. Business Rules and Decision Logic -> at least one meaningful one-line BR item (\`- BR-N: ...\`) is required"
}

test_helper_fails_when_open_questions_have_non_rised_values() {
  local repo_dir="$TMP_ROOT/repo-helper-non-rised-open-questions"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: Is legal approval required for cross-region invoice routing?

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: ## 15. Open Questions -> non-rised unresolved items must be moved to missing_br_data.md and marked rised"
}

test_helper_fails_when_assumptions_needing_validation_have_non_rised_value() {
  local repo_dir="$TMP_ROOT/repo-helper-non-rised-assumptions"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 14. Assumptions
### Needs validation
- assumptions_needing_validation: Whether regional tax routing needs legal signoff.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: [UNFILLED]

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: ### Needs validation -> non-rised assumptions_needing_validation must be moved to missing_br_data.md and marked rised"
}

test_helper_fails_when_unclear_scope_points_have_non_rised_value() {
  local repo_dir="$TMP_ROOT/repo-helper-non-rised-scope"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: Should pilot include partner-managed queues?

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: [UNFILLED]

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: ### 5.3 Open scope boundaries -> non-rised unclear_scope_points must be moved to missing_br_data.md and marked rised"
}

test_helper_passes_when_rised_markers_are_present() {
  local repo_dir="$TMP_ROOT/repo-helper-rised"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  cat >"$repo_dir/overmind/product/feature_br_summary.md" <<'OUT'
# Feature Business Requirements Summary

## 1. Document Meta
- source_type: User input
- last_updated: 2026-03-20

## 2. Source Request Snapshot
### 2.1 Original request summary
- short summary: Product owners need invoice approval turnaround visibility.

## 3. Feature Intent
### 3.1 Business goal
- primary_business_goal: Reduce billing approval cycle time.

## 14. Assumptions
### Needs validation
- assumptions_needing_validation: rised=true; unresolved_item=Whether regional tax routing needs legal signoff.

## 5. Scope Definition
### 5.3 Open scope boundaries
- unclear_scope_points: rised=true; unresolved_item=Should pilot include partner-managed queues?

## 6. Functional Requirements
- FR-1: System captures required invoice approval fields from product owner.

## 7. Business Rules and Decision Logic
- BR-1: Approval requests above threshold require compliance review before release.

## 15. Open Questions
### Critical questions
- critical_questions: rised=true; unresolved_item=Is legal approval required for cross-region invoice routing?

### Non-critical questions
- non_critical_questions: [UNFILLED]
OUT

  local out
  out="$(
    cd "$repo_dir" &&
    overmind/scripts/helper/check_task_to_br_quality.sh
  )"

  assert_contains "$out" "business-context gate passed"
}

test_helper_fails_when_missing_data_has_rised_items_and_answers_unfilled() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-data-answers-unfilled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_complete_summary "$repo_dir"
  cat >"$repo_dir/overmind/product/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required for cross-region invoice routing?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Waiting for user response.
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: missing_br_data.md -> unresolved rised items exist but ## 6. Latest User Answers -> answers is [UNFILLED]"
}

test_helper_fails_when_missing_data_has_rised_items_and_unresolved_after_stop_unfilled() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-data-unresolved-after-stop-unfilled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_complete_summary "$repo_dir"
  cat >"$repo_dir/overmind/product/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required for cross-region invoice routing?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: [UNFILLED]
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: missing_br_data.md -> unresolved rised items exist but ## 7. Loop Decision -> unresolved_after_stop is [UNFILLED]"
}

test_helper_fails_when_missing_data_has_non_rised_items() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-data-non-rised-items"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_complete_summary "$repo_dir"
  cat >"$repo_dir/overmind/product/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Is legal approval required for cross-region invoice routing?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: Pending legal policy clarification from business owner.
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "1" "$status"
  assert_contains "$out" "business-context gate failed"
  assert_contains "$out" "missing: missing_br_data.md -> unresolved ledger contains non-rised items; continue questioning until every rised_item_N is rised=true"
}

test_helper_passes_when_missing_data_rised_items_have_loop_fields_filled() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-data-loop-fields-filled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_complete_summary "$repo_dir"
  cat >"$repo_dir/overmind/product/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required for cross-region invoice routing?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: Pending legal policy clarification from business owner.
OUT

  local out
  out="$(
    cd "$repo_dir" &&
    overmind/scripts/helper/check_task_to_br_quality.sh
  )"

  assert_contains "$out" "business-context gate passed"
}

test_helper_passes_when_missing_data_has_multiple_answer_pointers() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-data-multiple-answers"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_complete_summary "$repo_dir"
  cat >"$repo_dir/overmind/product/missing_br_data.md" <<'OUT'
# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is legal approval required for cross-region invoice routing?
- rised_item_2: source=### 5.3 Open scope boundaries -> unclear_scope_points; rised=true; unresolved_item=Should pilot include partner-managed approval queues?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.
- answers: This was recorded in ## 5. Scope and Boundaries - unclear_scope_points.

## 7. Loop Decision
- unresolved_after_stop: Pending legal policy clarification from business owner.
OUT

  local out
  out="$(
    cd "$repo_dir" &&
    overmind/scripts/helper/check_task_to_br_quality.sh
  )"

  assert_contains "$out" "business-context gate passed"
}

test_helper_returns_exit_code_2_for_missing_target_file() {
  local repo_dir="$TMP_ROOT/repo-helper-missing-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_task_to_br_quality.sh 2>&1)"
  status=$?
  set -e

  assert_equal "2" "$status"
  assert_contains "$out" "ERROR: Target BR summary not found:"
}

test_helper_passes_when_required_fields_fr_and_br_exist
test_helper_fails_with_exit_code_1_when_required_business_goal_is_missing
test_helper_fails_with_exit_code_1_when_no_populated_fr_exists
test_helper_fails_with_exit_code_1_when_no_populated_br_exists
test_helper_fails_when_open_questions_have_non_rised_values
test_helper_fails_when_assumptions_needing_validation_have_non_rised_value
test_helper_fails_when_unclear_scope_points_have_non_rised_value
test_helper_passes_when_rised_markers_are_present
test_helper_fails_when_missing_data_has_rised_items_and_answers_unfilled
test_helper_fails_when_missing_data_has_rised_items_and_unresolved_after_stop_unfilled
test_helper_fails_when_missing_data_has_non_rised_items
test_helper_passes_when_missing_data_rised_items_have_loop_fields_filled
test_helper_passes_when_missing_data_has_multiple_answer_pointers
test_helper_returns_exit_code_2_for_missing_target_file

echo "All user-input BR business-context gate helper tests passed."
