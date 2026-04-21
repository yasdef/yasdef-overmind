#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_prerequisite_gaps_quality.sh"

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
  cp "$HELPER_SRC" "$repo_dir/overmind/scripts/helper/check_prerequisite_gaps_quality.sh"
  chmod +x "$repo_dir/overmind/scripts/helper/check_prerequisite_gaps_quality.sh"

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

run_helper() {
  local repo_dir="$1"
  local target_arg="$2"
  local ears_arg="${3:-}"
  local tech_req_arg="${4:-}"
  local out=""
  local status=0

  set +e
  out="$(cd "$repo_dir" && overmind/scripts/helper/check_prerequisite_gaps_quality.sh "$target_arg" $ears_arg $tech_req_arg 2>&1)"
  status=$?
  set -e

  printf '%s\n%s\n' "$status" "$out"
}

write_valid_prerequisite_gaps() {
  local path="$1"
  cat >"$path" <<'OUT'
# Prerequisite Gaps

## 1. Document Meta
- feature_id: AA-1
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_technical_requirements: projects/p1/feature-a/technical_requirements.md
- source_implementation_slices: projects/p1/feature-a/implementation_slices.md
- last_updated: 2026-04-12

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Trusted internal callers can submit Telegram user data and receive a usable identity result.
- prerequisites: see entries below

#### Prerequisite: Telegram identity endpoint
- status: present_in_repo
- surface_kind: present_user_reachable_surface
- surface_identity: none
- evidence: POST /api/v1/telegram/identify
- slice_ref: none

#### Prerequisite: Frontend registration route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator Telegram registration page
- evidence: Slice slice-3 adds /telegram/register page
- slice_ref: slice-3

### Requirement: NFR-1
- requirement_summary: Core latency budget
- prerequisites: none
OUT
}

write_requirements_ears() {
  local path="$1"
  cat >"$path" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 — Identity
**Acceptance Criteria (EARS):**
- WHEN a caller submits data to POST /api/v1/telegram/identify, THE System SHALL return an identity result.

OUT
}

write_technical_requirements() {
  local path="$1"
  cat >"$path" <<'OUT'
# Technical Requirements

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- requirement_summary: Telegram identity
- transport_layer: IdentityController.identify()
- user_reachable_surface: POST /api/v1/telegram/identify
- gap_status: partially_implemented
- repo_impact: backend

OUT
}

test_passes_with_all_resolved() {
  local repo_dir="$TMP_ROOT/repo-pass"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  local gaps_path="$repo_dir/projects/p1/feature-a/prerequisite_gaps.md"
  write_valid_prerequisite_gaps "$gaps_path"

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_entry_has_unmet_status() {
  local repo_dir="$TMP_ROOT/repo-unmet"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-2
- requirement_summary: Account creation
- prerequisites: see entries below

#### Prerequisite: Account creation endpoint
- status: unmet
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator account creation page
- evidence:
- slice_ref: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "unmet prerequisite"
  assert_contains "$out" "REQ-2"
  assert_contains "$out" "Account creation endpoint"
}

test_fails_when_present_in_repo_missing_evidence() {
  local repo_dir="$TMP_ROOT/repo-no-evidence"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Identity
- prerequisites: see entries below

#### Prerequisite: Telegram endpoint
- status: present_in_repo
- surface_kind: present_user_reachable_surface
- surface_identity: none
- evidence:
- slice_ref: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "missing evidence"
  assert_contains "$out" "present_in_repo"
}

test_fails_when_scheduled_in_slices_missing_slice_ref() {
  local repo_dir="$TMP_ROOT/repo-no-slice-ref"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Identity
- prerequisites: see entries below

#### Prerequisite: Frontend route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator Telegram registration route
- evidence: Slice slice-3 adds /telegram/register
- slice_ref: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "missing slice_ref"
  assert_contains "$out" "scheduled_in_slices"
}

test_fails_when_slice_ref_has_invalid_format() {
  local repo_dir="$TMP_ROOT/repo-bad-slice-ref"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Identity
- prerequisites: see entries below

#### Prerequisite: Frontend route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator Telegram registration route
- evidence: Slice adds /telegram/register
- slice_ref: -bad-start
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "does not match required format"
}

test_passes_when_required_missing_surface_identity_is_stable_after_scheduling() {
  local repo_dir="$TMP_ROOT/repo-stable-surface-identity"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-5
- requirement_summary: Operator sign-in is required before protected workflow access.
- prerequisites: see entries below

#### Prerequisite: Operator sign-in entry route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator sign-in page
- evidence: Slice slice-2 schedules the same Operator sign-in page that was previously tracked as unmet in earlier prerequisite-gaps runs.
- slice_ref: slice-2
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_required_missing_surface_identity_is_missing_after_scheduling() {
  local repo_dir="$TMP_ROOT/repo-missing-surface-identity"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-5
- requirement_summary: Operator sign-in is required before protected workflow access.
- prerequisites: see entries below

#### Prerequisite: Operator sign-in entry route
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: none
- evidence: Slice slice-2 adds /admin/login.
- slice_ref: slice-2
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "missing surface_identity"
}

test_fails_when_transport_or_internal_gap_is_classified_as_preserved_surface() {
  local repo_dir="$TMP_ROOT/repo-transport-gap-classified"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-8
- requirement_summary: Internal projection rebuild state transitions remain deterministic.
- prerequisites: see entries below

#### Prerequisite: Projection rebuild repository synchronization
- status: present_in_repo
- surface_kind: transport_or_internal_execution_gap
- surface_identity: none
- evidence: Internal repository transition path exists.
- slice_ref: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "transport_or_internal_execution_gap"
}

test_passes_when_required_missing_cli_command_surface_identity_is_used() {
  local repo_dir="$TMP_ROOT/repo-cli-surface-identity"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-9
- requirement_summary: Operators can run a reconciliation command from the admin terminal.
- prerequisites: see entries below

#### Prerequisite: Reconciliation CLI command
- status: scheduled_in_slices
- surface_kind: required_missing_user_reachable_surface
- surface_identity: Operator reconciliation CLI command
- evidence: Slice slice-7 schedules the reconciliation admin terminal command.
- slice_ref: slice-7
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_fails_when_input_file_is_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-input"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"

  assert_equal "2" "$status"
}

test_fails_when_literal_url_absent_from_both_sources() {
  local repo_dir="$TMP_ROOT/repo-missing-literal"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  cat >"$repo_dir/projects/p1/feature-a/requirements_ears.md" <<'OUT'
# Requirements (EARS)

### Requirement 1
**Acceptance Criteria (EARS):**
- WHEN a caller hits POST /api/v1/orders, THE System SHALL persist the order.
OUT

  cat >"$repo_dir/projects/p1/feature-a/technical_requirements.md" <<'OUT'
# Technical Requirements

## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- transport_layer: OrderService.create()
- user_reachable_surface: none
OUT

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Order creation
- prerequisites: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md" "projects/p1/feature-a/requirements_ears.md" "projects/p1/feature-a/technical_requirements.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "1" "$status"
  assert_contains "$out" "POST /api/v1/orders"
  assert_contains "$out" "absent from both"
}

test_fails_when_backend_scheduled_job_absent_from_both_sources() {
  local repo_dir="$TMP_ROOT/repo-missing-job"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  write_requirements_ears "$repo_dir/projects/p1/feature-a/requirements_ears.md"
  write_technical_requirements "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Identity
- prerequisites: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md" "projects/p1/feature-a/requirements_ears.md" "projects/p1/feature-a/technical_requirements.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_when_url_present_in_prerequisite_gaps() {
  local repo_dir="$TMP_ROOT/repo-url-in-gaps"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  write_requirements_ears "$repo_dir/projects/p1/feature-a/requirements_ears.md"
  write_technical_requirements "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  local gaps_path="$repo_dir/projects/p1/feature-a/prerequisite_gaps.md"
  write_valid_prerequisite_gaps "$gaps_path"

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md" "projects/p1/feature-a/requirements_ears.md" "projects/p1/feature-a/technical_requirements.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_when_url_present_in_user_reachable_surface() {
  local repo_dir="$TMP_ROOT/repo-url-in-surface"
  mkdir -p "$repo_dir/projects/p1/feature-a"
  setup_repo_with_helper "$repo_dir"

  write_requirements_ears "$repo_dir/projects/p1/feature-a/requirements_ears.md"
  write_technical_requirements "$repo_dir/projects/p1/feature-a/technical_requirements.md"

  cat >"$repo_dir/projects/p1/feature-a/prerequisite_gaps.md" <<'OUT'
# Prerequisite Gaps

## 2. Prerequisite Trace

### Requirement: REQ-1
- requirement_summary: Identity
- prerequisites: see entries below

#### Prerequisite: Identity endpoint
- status: present_in_repo
- surface_kind: present_user_reachable_surface
- surface_identity: none
- evidence: POST /api/v1/telegram/identify
- slice_ref: none

### Requirement: NFR-1
- requirement_summary: Latency
- prerequisites: none
OUT

  local result
  result="$(run_helper "$repo_dir" "projects/p1/feature-a/prerequisite_gaps.md" "projects/p1/feature-a/requirements_ears.md" "projects/p1/feature-a/technical_requirements.md")"
  local status
  status="$(printf '%s\n' "$result" | head -n1)"
  local out
  out="$(printf '%s\n' "$result" | tail -n +2)"

  assert_equal "0" "$status"
  assert_contains "$out" "quality gate passed"
}

test_passes_with_all_resolved
test_fails_when_entry_has_unmet_status
test_fails_when_present_in_repo_missing_evidence
test_fails_when_scheduled_in_slices_missing_slice_ref
test_fails_when_slice_ref_has_invalid_format
test_passes_when_required_missing_surface_identity_is_stable_after_scheduling
test_fails_when_required_missing_surface_identity_is_missing_after_scheduling
test_fails_when_transport_or_internal_gap_is_classified_as_preserved_surface
test_passes_when_required_missing_cli_command_surface_identity_is_used
test_fails_when_input_file_is_missing
test_fails_when_literal_url_absent_from_both_sources
test_fails_when_backend_scheduled_job_absent_from_both_sources
test_passes_when_url_present_in_prerequisite_gaps
test_passes_when_url_present_in_user_reachable_surface

echo "All prerequisite gaps quality tests passed."
