#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ASSIGN_SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_assing_workers.sh"
READINESS_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/check_implementation_plan_readiness.sh"

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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "Assertion failed: expected output to not contain: $needle" >&2
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

count_occurrences() {
  local haystack="$1"
  local needle="$2"
  awk -v needle="$needle" '
BEGIN { count = 0 }
{
  line = $0
  while (index(line, needle) > 0) {
    count++
    line = substr(line, index(line, needle) + length(needle))
  }
}
END { print count }
' <<<"$haystack"
}

assignment_for_step() {
  local plan_path="$1"
  local step_id="$2"
  awk -v step_id="$step_id" '
BEGIN {
  target_prefix = "### Step " step_id " "
  in_target = 0
}
$0 ~ /^### Step[[:space:]]+/ {
  if (index($0, target_prefix) == 1) {
    in_target = 1
    next
  }
  in_target = 0
}
in_target == 1 && $0 ~ /^#### Assigned:[[:space:]]*/ {
  value = $0
  sub(/^#### Assigned:[[:space:]]*/, "", value)
  print value
  exit
}
' "$plan_path"
}

setup_workspace() {
  local asdlc_root="$1"

  mkdir -p "$asdlc_root/.commands" "$asdlc_root/common_libs" "$asdlc_root/projects"
  cat >"$asdlc_root/asdlc_metadata.yaml" <<'EOF'
meta:
  description: "test workspace"
projects:
EOF

  cp "$ASSIGN_SCRIPT_SRC" "$asdlc_root/.commands/feature_assing_workers.sh"
  chmod +x "$asdlc_root/.commands/feature_assing_workers.sh"
  cp "$READINESS_HELPER_SRC" "$asdlc_root/common_libs/check_implementation_plan_readiness.sh"
  chmod +x "$asdlc_root/common_libs/check_implementation_plan_readiness.sh"
}

create_project_and_feature() {
  local asdlc_root="$1"
  local project_id="$2"
  local feature_id="$3"
  local project_dir="$asdlc_root/projects/$project_id"
  local feature_dir="$project_dir/$feature_id"

  mkdir -p "$feature_dir"
  cat >"$project_dir/init_progress_definition.yaml" <<EOF
meta_info:
  project_id: "$project_id"
steps: []
EOF

  cat >"$feature_dir/feature_br_summary.md" <<'EOF'
# BR
EOF

  printf '%s' "$feature_dir"
}

write_plan_three_steps() {
  local plan_path="$1"
  cat >"$plan_path" <<'EOF'
# Implementation Plan

### Step 1.1 Backend work [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
#### Assigned: old-backend-value
- [ ] Plan and discuss the step
- [ ] Implement backend work
- [ ] Review step implementation

### Step 1.2 Frontend work [REQ-2]
#### Repo: frontend
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-2
- [ ] Plan and discuss the step
- [ ] Implement frontend work
- [ ] Review step implementation

### Step 1.3 Mobile work [REQ-3]
#### Repo: mobile
#### Depends on: 1.1
#### Evidence: gap/TECH_REQ-3
- [ ] Plan and discuss the step
- [ ] Implement mobile work
- [ ] Review step implementation
EOF
}

write_backend_worker_registry() {
  local workers_path="$1"
  cat >"$workers_path" <<'EOF'
project_id: "p1"
workers:
  - uuid: "11111111-1111-1111-1111-111111111111"
    class: "backend"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
EOF
}

write_backend_plan_with_dependency() {
  local plan_path="$1"
  local dependency="$2"
  cat >"$plan_path" <<EOF
# Implementation Plan

### Step 1.1 Backend work [REQ-1]
#### Repo: backend
#### Depends on: $dependency
#### Evidence: gap/TECH_REQ-1
- [ ] Plan and discuss the step
- [ ] Implement backend work
- [ ] Review step implementation
EOF
}

write_sibling_plan_step() {
  local plan_path="$1"
  local checklist_state="$2"
  cat >"$plan_path" <<EOF
# Implementation Plan

### Step 2.1 Sibling prerequisite [REQ-2]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-2
- [x] Plan and discuss the step
- [$checklist_state] Implement sibling prerequisite
- [x] Review step implementation
EOF
}

write_sibling_plan_step_with_uppercase_checks() {
  local plan_path="$1"
  cat >"$plan_path" <<'EOF'
# Implementation Plan

### Step 2.1 Sibling prerequisite [REQ-2]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-2
- [X] Plan and discuss the step
- [X] Implement sibling prerequisite
- [X] Review step implementation
EOF
}

test_missing_feature_path_argument_is_rejected() {
  local asdlc_root="$TMP_ROOT/asdlc-missing-arg"
  setup_workspace "$asdlc_root"

  local status=0
  local out=""
  set +e
  out="$("$asdlc_root/.commands/feature_assing_workers.sh" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <asdlc/projects/<project-id>/<feature-folder>>."
}

test_invalid_or_missing_feature_path_is_rejected() {
  local asdlc_root="$TMP_ROOT/asdlc-invalid-feature-path"
  setup_workspace "$asdlc_root"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/missing-feature" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Feature path directory not found: projects/p1/missing-feature"
}

test_missing_or_malformed_implementation_plan_is_rejected() {
  local asdlc_root="$TMP_ROOT/asdlc-plan-readiness"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local status=0
  local out=""

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"

  set +e
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: required file not found: projects/p1/feature-a/implementation_plan.md"

  cat >"$feature_dir/implementation_plan.md" <<'EOF'
# Implementation Plan

### Step 1.1 Broken plan [REQ-1]
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
- [ ] Missing repo metadata
EOF
  cat >"$asdlc_root/projects/p1/workers.yaml" <<'EOF'
project_id: "p1"
workers: []
EOF

  set +e
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: step 1 is missing #### Repo: metadata"
}

test_missing_or_malformed_worker_registry_is_rejected() {
  local asdlc_root="$TMP_ROOT/asdlc-workers-readiness"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local status=0
  local out=""

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  write_plan_three_steps "$feature_dir/implementation_plan.md"

  set +e
  out="$(
    cd "$asdlc_root" &&
    printf '1\n' | .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Worker registry is required for assignment: projects/p1/workers.yaml"

  cat >"$asdlc_root/projects/p1/workers.yaml" <<'EOF'
project_id: "p1"
items:
  - bad: true
EOF
  set +e
  out="$(
    cd "$asdlc_root" &&
    printf '1\n' | .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Worker registry is malformed: expected top-level 'workers:' collection"

  cat >"$asdlc_root/projects/p1/workers.yaml" <<'EOF'
workers:
  - uuid: "abc"
    class: "backend"
    status: "active"
EOF
  set +e
  out="$(
    cd "$asdlc_root" &&
    printf '1\n' | .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Worker registry is malformed: expected top-level project_id"

  cat >"$asdlc_root/projects/p1/workers.yaml" <<'EOF'
project_id: "p1"
workers:
  - uuid: "11111111-1111-1111-1111-111111111111"
    class: "backend"
EOF
  set +e
  out="$(
    cd "$asdlc_root" &&
    printf '1\n' | .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_contains "$out" "Worker registry is malformed: each worker entry must include uuid, class, and status"
}

test_assignments_are_class_strict_and_error_lines_are_written_for_unstaffed_class() {
  local asdlc_root="$TMP_ROOT/asdlc-class-assignment"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local plan_path=""
  local out=""
  local status=0
  local backend_assignment=""
  local frontend_assignment=""
  local mobile_assignment=""
  local assigned_count=""
  local invalid_retry_count=""

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  plan_path="$feature_dir/implementation_plan.md"
  write_plan_three_steps "$plan_path"

  cat >"$asdlc_root/projects/p1/workers.yaml" <<'EOF'
project_id: "p1"
workers:
  - uuid: "11111111-1111-1111-1111-111111111111"
    class: "backend"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
  - uuid: "22222222-2222-2222-2222-222222222222"
    class: "frontend"
    status: "postponed"
    registered_at: "2026-01-01T00:00:00Z"
  - uuid: "33333333-3333-3333-3333-333333333333"
    class: "mobile"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
  - uuid: "44444444-4444-4444-4444-444444444444"
    class: "mobile"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
  - uuid: "55555555-5555-5555-5555-555555555555"
    class: "infrastructure"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
EOF

  set +e
  out="$(
    cd "$asdlc_root" &&
    printf 'wrong\n2\n' | .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "ERROR: no active worker available for class frontend"
  assert_contains "$out" "ERROR: assignment completed with class availability issues"
  invalid_retry_count="$(count_occurrences "$out" "Invalid selection. Enter one list number or one worker UUID from the list.")"
  assert_equal "1" "$invalid_retry_count"

  backend_assignment="$(assignment_for_step "$plan_path" "1.1")"
  frontend_assignment="$(assignment_for_step "$plan_path" "1.2")"
  mobile_assignment="$(assignment_for_step "$plan_path" "1.3")"
  assigned_count="$(grep -c '^#### Assigned:' "$plan_path")"

  assert_equal "11111111-1111-1111-1111-111111111111" "$backend_assignment"
  assert_equal "ERROR: no active worker available for class frontend" "$frontend_assignment"
  assert_equal "44444444-4444-4444-4444-444444444444" "$mobile_assignment"
  assert_equal "3" "$assigned_count"
  assert_contains "$(cat "$plan_path")" "- [ ] Implement backend work"
  assert_contains "$(cat "$plan_path")" "- [ ] Implement frontend work"
  assert_contains "$(cat "$plan_path")" "- [ ] Implement mobile work"
  assert_not_contains "$(cat "$plan_path")" "old-backend-value"
}

test_multi_worker_selection_retries_and_succeeds() {
  local asdlc_root="$TMP_ROOT/asdlc-multi-worker-selection"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local plan_path=""
  local out=""
  local status=0
  local retry_count=""

  feature_dir="$(create_project_and_feature "$asdlc_root" "p2" "feature-b")"
  plan_path="$feature_dir/implementation_plan.md"
  cat >"$plan_path" <<'EOF'
# Implementation Plan

### Step 1.1 Backend work [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
- [ ] Implement backend work
EOF

  cat >"$asdlc_root/projects/p2/workers.yaml" <<'EOF'
project_id: "p2"
workers:
  - uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    class: "backend"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
  - uuid: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    class: "backend"
    status: "active"
    registered_at: "2026-01-01T00:00:00Z"
EOF

  out="$(
    cd "$asdlc_root" &&
    printf '9\nbbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb\n' | .commands/feature_assing_workers.sh --feature_path "projects/p2/feature-b" 2>&1
  )"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success but command failed:" >&2
    echo "$out" >&2
    exit 1
  fi

  retry_count="$(count_occurrences "$out" "Invalid selection. Enter one list number or one worker UUID from the list.")"
  assert_equal "1" "$retry_count"
  assert_contains "$out" "Updated projects/p2/feature-b/implementation_plan.md with worker assignments."
  assert_contains "$out" "Class backend -> bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
  assert_equal "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" "$(assignment_for_step "$plan_path" "1.1")"
}

test_incomplete_cross_feature_dependency_writes_hold() {
  local asdlc_root="$TMP_ROOT/asdlc-cross-feature-hold"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local sibling_dir=""
  local plan_path=""
  local out=""
  local status=0

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  sibling_dir="$asdlc_root/projects/p1/feature-z"
  mkdir -p "$sibling_dir"
  plan_path="$feature_dir/implementation_plan.md"
  write_backend_plan_with_dependency "$plan_path" "feature-z/2.1"
  write_sibling_plan_step "$sibling_dir/implementation_plan.md" " "
  write_backend_worker_registry "$asdlc_root/projects/p1/workers.yaml"

  set +e
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "ERROR: assignment completed with class availability issues or dependency holds"
  assert_equal "hold: depends on feature-z/2.1" "$(assignment_for_step "$plan_path" "1.1")"
}

test_dot_cross_feature_dependency_is_rejected() {
  local asdlc_root="$TMP_ROOT/asdlc-cross-feature-dot"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local plan_path=""
  local out=""
  local status=0

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  plan_path="$feature_dir/implementation_plan.md"
  write_backend_plan_with_dependency "$plan_path" "../2.1"
  write_backend_worker_registry "$asdlc_root/projects/p1/workers.yaml"

  set +e
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Implementation plan is not ready: step 1.1 has malformed cross-feature dependency ../2.1"
}

test_completed_cross_feature_dependency_assigns_worker() {
  local asdlc_root="$TMP_ROOT/asdlc-cross-feature-complete"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local sibling_dir=""
  local plan_path=""
  local out=""
  local status=0

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  sibling_dir="$asdlc_root/projects/p1/feature-z"
  mkdir -p "$sibling_dir"
  plan_path="$feature_dir/implementation_plan.md"
  write_backend_plan_with_dependency "$plan_path" "feature-z/2.1"
  write_sibling_plan_step "$sibling_dir/implementation_plan.md" "x"
  write_backend_worker_registry "$asdlc_root/projects/p1/workers.yaml"

  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success but command failed:" >&2
    echo "$out" >&2
    exit 1
  fi

  assert_contains "$out" "Updated projects/p1/feature-a/implementation_plan.md with worker assignments."
  assert_equal "11111111-1111-1111-1111-111111111111" "$(assignment_for_step "$plan_path" "1.1")"
}

test_uppercase_completed_cross_feature_dependency_assigns_worker() {
  local asdlc_root="$TMP_ROOT/asdlc-cross-feature-uppercase-complete"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local sibling_dir=""
  local plan_path=""
  local out=""
  local status=0

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  sibling_dir="$asdlc_root/projects/p1/feature-z"
  mkdir -p "$sibling_dir"
  plan_path="$feature_dir/implementation_plan.md"
  write_backend_plan_with_dependency "$plan_path" "feature-z/2.1"
  write_sibling_plan_step_with_uppercase_checks "$sibling_dir/implementation_plan.md"
  write_backend_worker_registry "$asdlc_root/projects/p1/workers.yaml"

  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success with uppercase checked boxes but command failed:" >&2
    echo "$out" >&2
    exit 1
  fi

  assert_equal "11111111-1111-1111-1111-111111111111" "$(assignment_for_step "$plan_path" "1.1")"
}

test_rerun_flips_cross_feature_hold_to_assignment_after_dependency_completes() {
  local asdlc_root="$TMP_ROOT/asdlc-cross-feature-rerun"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local sibling_dir=""
  local plan_path=""
  local out=""
  local status=0

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  sibling_dir="$asdlc_root/projects/p1/feature-z"
  mkdir -p "$sibling_dir"
  plan_path="$feature_dir/implementation_plan.md"
  write_backend_plan_with_dependency "$plan_path" "feature-z/2.1"
  write_sibling_plan_step "$sibling_dir/implementation_plan.md" " "
  write_backend_worker_registry "$asdlc_root/projects/p1/workers.yaml"

  set +e
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  set -e
  assert_nonzero_status "$status"
  assert_equal "hold: depends on feature-z/2.1" "$(assignment_for_step "$plan_path" "1.1")"

  write_sibling_plan_step "$sibling_dir/implementation_plan.md" "x"
  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "Expected rerun success but command failed:" >&2
    echo "$out" >&2
    exit 1
  fi

  assert_equal "11111111-1111-1111-1111-111111111111" "$(assignment_for_step "$plan_path" "1.1")"
  assert_not_contains "$(cat "$plan_path")" "hold: depends on feature-z/2.1"
}

test_zero_sibling_plans_adds_no_cross_feature_holds() {
  local asdlc_root="$TMP_ROOT/asdlc-zero-sibling"
  setup_workspace "$asdlc_root"
  local feature_dir=""
  local plan_path=""
  local out=""
  local status=0

  feature_dir="$(create_project_and_feature "$asdlc_root" "p1" "feature-a")"
  plan_path="$feature_dir/implementation_plan.md"
  write_backend_plan_with_dependency "$plan_path" "none"
  write_backend_worker_registry "$asdlc_root/projects/p1/workers.yaml"

  out="$(
    cd "$asdlc_root" &&
    .commands/feature_assing_workers.sh --feature_path "projects/p1/feature-a" 2>&1
  )"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "Expected success with zero sibling plans but command failed:" >&2
    echo "$out" >&2
    exit 1
  fi

  assert_equal "11111111-1111-1111-1111-111111111111" "$(assignment_for_step "$plan_path" "1.1")"
  assert_not_contains "$(cat "$plan_path")" "hold: depends on"
}

test_missing_feature_path_argument_is_rejected
test_invalid_or_missing_feature_path_is_rejected
test_missing_or_malformed_implementation_plan_is_rejected
test_missing_or_malformed_worker_registry_is_rejected
test_assignments_are_class_strict_and_error_lines_are_written_for_unstaffed_class
test_multi_worker_selection_retries_and_succeeds
test_incomplete_cross_feature_dependency_writes_hold
test_dot_cross_feature_dependency_is_rejected
test_completed_cross_feature_dependency_assigns_worker
test_uppercase_completed_cross_feature_dependency_assigns_worker
test_rerun_flips_cross_feature_hold_to_assignment_after_dependency_completes
test_zero_sibling_plans_adds_no_cross_feature_holds

echo "All feature_assing_workers tests passed."
