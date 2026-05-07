#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_common_contract_definition_quality.sh"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_common_contract_definition_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_common_contract_definition_quality.sh"
  echo "seed" >"$repo_dir/README.md"
}

setup_staged_workspace_with_helper() {
  local asdlc_root="$1"
  mkdir -p "$asdlc_root/.helper"
  cp "$HELPER_SRC" "$asdlc_root/.helper/check_common_contract_definition_quality.sh"
  chmod +x "$asdlc_root/.helper/check_common_contract_definition_quality.sh"
  cat >"$asdlc_root/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "staged helper test"
projects:
OUT
}

write_valid_common_contract_definition() {
  local target_path="$1"
  cat >"$target_path" <<'OUT'
# Common Contract Definition

## 1. Document Meta
- project_id: payments_api-1743800100123
- project_path: /tmp/asdlc/projects/payments_api-1743800100123
- source_repo_count: 2
- source_repositories: backend, frontend
- last_updated: 2026-04-04
- confidence_level: high

## 2. Source Repository Evidence
### Repository: backend
- class: backend
- repo_path: /tmp/repos/backend
- contract_evidence_summary: Reviewed backend API and event contracts.
- key_surfaces_reviewed: payments REST API, payment-created event.
- notes: Backend defines canonical status payload.

### Repository: frontend
- class: frontend
- repo_path: /tmp/repos/frontend
- contract_evidence_summary: Reviewed frontend API client contracts and mappings.
- key_surfaces_reviewed: API client status mapping, validation error handling.
- notes: Frontend depends on backend response schema stability.

## 3. Common Contract Baseline
### Contract: payment-status-domain
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: backend
- consumer_repositories: frontend
- contract_surface: GET /api/v1/payments/{id}
- contract_status: aligned
- source_of_truth: backend domain + API payload
- canonical_shape: response:{payment_id,status}; status->one_of{created,authorized,captured,failed,cancelled}
- shared_types: PaymentStatus, PaymentId
- trust_boundary: internal
- compatibility_rule: additive fields allowed; semantic status change is breaking
- planning_implication: add contract tests
- notes: none

## 4. Reconciliation Decisions
- decision_1: backend API payload is canonical for synchronous status representation.
- decision_2: event schema ownership stays with backend publisher.

## 5. Known Risks / Uncertainties
- uncertainty_1: legacy webhook ownership between teams remains unclear.
- uncertainty_2: schema-breaking governance process needs formalization.

## 6. Common Planning Signals
- prep_1: reconcile frontend status mapping with backend enum.
- prep_2: add shared contract tests for payment status and error payloads.
OUT
}

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_common_contract_definition_quality.sh "$target_arg" 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

test_passes_with_valid_artifact() {
  local repo_dir="$TMP_ROOT/repo-pass"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
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
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "2" "$status"
  assert_contains "$out" "Target common contract definition artifact not found"
}

test_fails_with_content_error_when_target_empty() {
  local repo_dir="$TMP_ROOT/repo-empty-target"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  : >"$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "target common contract definition artifact is empty"
}

test_fails_when_source_repo_count_mismatches_repository_blocks() {
  local repo_dir="$TMP_ROOT/repo-count-mismatch"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- source_repo_count: 2$/- source_repo_count: 1/' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "source_repo_count must match number of repository blocks in section 2"
}

test_fails_when_uncertainty_1_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-uncertainty-1"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' '/^- uncertainty_1:/d' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "key uncertainty_1 is required and must be explicit"
}

test_fails_when_section_5_contains_unfilled_placeholders() {
  local repo_dir="$TMP_ROOT/repo-section-5-unfilled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- uncertainty_1: .*$/- uncertainty_1: [UNFILLED]/' "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- uncertainty_2: .*$/- uncertainty_2: [UNFILLED]/' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "artifact still contains [UNFILLED] placeholders"
}

test_passes_when_uncertainty_uses_none_or_not_observed() {
  local repo_dir="$TMP_ROOT/repo-explicit-none"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- uncertainty_1: .*$/- uncertainty_1: none/' "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- uncertainty_2: .*$/- uncertainty_2: not_observed/' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_unfilled_placeholders_remain() {
  local repo_dir="$TMP_ROOT/repo-unfilled"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- confidence_level: high$/- confidence_level: [UNFILLED]/' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "artifact still contains [UNFILLED] placeholders"
}

test_fails_when_section_6_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-section-6"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' '/^## 6\. Common Planning Signals$/,$d' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "missing section ## 6. Common Planning Signals"
}

test_fails_when_contract_status_is_invalid() {
  local repo_dir="$TMP_ROOT/repo-invalid-contract-status"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- contract_status: aligned$/- contract_status: ambiguous/' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "has invalid contract_status"
}

test_fails_when_contract_kind_is_invalid() {
  local repo_dir="$TMP_ROOT/repo-invalid-contract-kind"
  mkdir -p "$repo_dir"
  setup_repo_with_helper "$repo_dir"
  write_valid_common_contract_definition "$repo_dir/common_contract_definition.md"
  sed -i '' 's/^- contract_kind: http_api$/- contract_kind: websocket/' "$repo_dir/common_contract_definition.md"

  local result
  result="$(run_helper "$repo_dir" "$repo_dir/common_contract_definition.md")"
  local status="$(printf '%s\n' "$result" | head -n1)"
  local out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "has invalid contract_kind"
}

test_staged_helper_runs_without_git_repository() {
  local asdlc_root="$TMP_ROOT/asdlc-staged-helper"
  mkdir -p "$asdlc_root"
  setup_staged_workspace_with_helper "$asdlc_root"
  write_valid_common_contract_definition "$asdlc_root/common_contract_definition.md"

  local out=""
  local status=0
  set +e
  out="$(cd "$TMP_ROOT" && "$asdlc_root/.helper/check_common_contract_definition_quality.sh" "$asdlc_root/common_contract_definition.md" 2>&1)"
  status=$?
  set -e

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_valid_artifact
test_fails_with_helper_error_when_target_missing
test_fails_with_content_error_when_target_empty
test_fails_when_source_repo_count_mismatches_repository_blocks
test_fails_when_uncertainty_1_is_missing
test_fails_when_section_5_contains_unfilled_placeholders
test_passes_when_uncertainty_uses_none_or_not_observed
test_fails_when_unfilled_placeholders_remain
test_fails_when_section_6_is_missing
test_fails_when_contract_status_is_invalid
test_fails_when_contract_kind_is_invalid
test_staged_helper_runs_without_git_repository

echo "All common contract definition quality helper tests passed."
