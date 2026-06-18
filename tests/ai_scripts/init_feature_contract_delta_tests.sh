#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$SOURCE_ROOT/overmind/scripts/feature_contract_delta.sh"
RULE_SRC="$SOURCE_ROOT/overmind/rules/feature_contract_delta_rule.md"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/feature_contract_delta_TEMPLATE.md"
GOLDEN_EXAMPLE_SRC="$SOURCE_ROOT/overmind/golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
PEER_TRIGGER_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/helper/check_cross_class_peer_trigger.sh"
CLASS_REPO_PATHS_LIB_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/class_repo_paths.sh"
SIBLING_FEATURE_LISTER_SRC="$SOURCE_ROOT/overmind/scripts/common_libs/list_committed_sibling_features.sh"

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
    echo "Assertion failed: expected output to NOT contain: $needle" >&2
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

assert_file_not_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

setup_workspace_layout() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/asdlc/.commands" \
    "$repo_dir/asdlc/.rules" \
    "$repo_dir/asdlc/.helper" \
    "$repo_dir/asdlc/.templates" \
    "$repo_dir/asdlc/.golden_examples" \
    "$repo_dir/asdlc/.setup" \
    "$repo_dir/asdlc/common_libs" \
    "$repo_dir/asdlc/projects/p1/feature-a" \
    "$repo_dir/repositories/backend" \
    "$repo_dir/repositories/frontend"

  cp "$SCRIPT_SRC" "$repo_dir/asdlc/.commands/feature_contract_delta.sh"
  cp "$RULE_SRC" "$repo_dir/asdlc/.rules/feature_contract_delta_rule.md"
  cp "$TEMPLATE_SRC" "$repo_dir/asdlc/.templates/feature_contract_delta_TEMPLATE.md"
  cp "$GOLDEN_EXAMPLE_SRC" "$repo_dir/asdlc/.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
  cp "$PEER_TRIGGER_HELPER_SRC" "$repo_dir/asdlc/.helper/check_cross_class_peer_trigger.sh"
  cp "$CLASS_REPO_PATHS_LIB_SRC" "$repo_dir/asdlc/common_libs/class_repo_paths.sh"
  cp "$SIBLING_FEATURE_LISTER_SRC" "$repo_dir/asdlc/common_libs/list_committed_sibling_features.sh"
  cat >"$repo_dir/asdlc/common_libs/sync_repo_to_default_branch.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail
exit 0
OUT
  chmod +x \
    "$repo_dir/asdlc/.commands/feature_contract_delta.sh" \
    "$repo_dir/asdlc/.helper/check_cross_class_peer_trigger.sh" \
    "$repo_dir/asdlc/common_libs/list_committed_sibling_features.sh" \
    "$repo_dir/asdlc/common_libs/sync_repo_to_default_branch.sh"

  cat >"$repo_dir/asdlc/asdlc_metadata.yaml" <<'OUT'
meta:
  description: "test"
projects:
OUT
}

setup_models_file() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
feature_contract_delta | codex | gpt-5.4 | --config | model_reasoning_effort='high'
OUT
}

write_quality_gate_stub() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/.helper/check_feature_contract_delta_quality.sh" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:-}"
if [[ -n "$capture_dir" ]]; then
  echo "$1" >"$capture_dir/helper_arg.txt"
fi

if [[ "${TEST_QUALITY_HELPER_FAIL:-0}" == "1" ]]; then
  echo "feature contract delta quality gate failed in helper"
  exit 1
fi

echo "quality gate passed"
OUT
  chmod +x "$repo_dir/asdlc/.helper/check_feature_contract_delta_quality.sh"
}

seed_common_contract_definition() {
  local repo_dir="$1"
  local project_path="${2:-projects/p1}"
  mkdir -p "$repo_dir/asdlc/$project_path"
  cat >"$repo_dir/asdlc/$project_path/common_contract_definition.md" <<'OUT'
# Common Contract Definition

## 1. Document Meta
- project_id: p1
OUT
}

seed_project_definition() {
  local repo_dir="$1"
  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_type_code: "A"
  project_type_label: "New project"
  class_repo_paths:
    backend:
      state: "ready"
      path: "$repo_dir/repositories/backend"
    frontend:
      state: "deferred"
      path: "$repo_dir/repositories/frontend"

steps: []
EOF_DEF
}

seed_feature_sources() {
  local repo_dir="$1"
  local feature_path="${2:-projects/p1/feature-a}"
  local project_type_code="${3:-B}"
  mkdir -p "$repo_dir/asdlc/$feature_path"

  cat >"$repo_dir/asdlc/$feature_path/feature_br_summary.md" <<EOF_BR
# Feature Business Requirements Summary

## 1. Document Meta
- feature_id: FEAT-DELTA-001
- feature_title: Feature contract delta test
- project_type_code: $project_type_code
- source_type: Repo scan
- last_updated: 2026-04-07
- ready_to_ears: true
EOF_BR

  cat >"$repo_dir/asdlc/$feature_path/requirements_ears.md" <<'OUT'
# Requirements (EARS)

## Requirements

### Requirement 1 - Contract change
**User Story:** As a product owner, I want explicit contract updates, so that tracks can implement consistently.

**Acceptance Criteria (EARS):**
- WHEN feature contract delta phase runs, THE System SHALL derive shared contract changes from EARS and baseline contracts.

**Verification:** Integration test validates generated feature_contract_delta.md.
OUT
}

seed_sibling_contract_delta() {
  local repo_dir="$1"
  local sibling_folder="$2"
  mkdir -p "$repo_dir/asdlc/projects/p1/$sibling_folder"
  cat >"$repo_dir/asdlc/projects/p1/$sibling_folder/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 2.1
- [ ] Add sibling contract support
OUT
  cat >"$repo_dir/asdlc/projects/p1/$sibling_folder/feature_contract_delta.md" <<'OUT'
# Feature Contract Delta

## 1. Document Meta
- feature_id: FEAT-SIBLING-001
- delta_needed: true

## 2. Delta Summary
- impacted_tracks: backend, frontend
OUT
}

seed_sibling_implementation_plan_only() {
  local repo_dir="$1"
  local sibling_folder="$2"
  mkdir -p "$repo_dir/asdlc/projects/p1/$sibling_folder"
  cat >"$repo_dir/asdlc/projects/p1/$sibling_folder/implementation_plan.md" <<'OUT'
# Implementation Plan

### Step 2.1
- [ ] Add sibling work without contract delta
OUT
}

setup_codex_stub() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/bin"
  cat >"$repo_dir/bin/codex" <<'OUT'
#!/usr/bin/env bash
set -euo pipefail

capture_dir="${TEST_CAPTURE_DIR:?TEST_CAPTURE_DIR must be set}"
target_file="${TARGET_FEATURE_CONTRACT_DELTA_FILE:-projects/p1/feature-a/feature_contract_delta.md}"

printf '%s\n' "$@" >"$capture_dir/codex_args.txt"
printf '%s' "${!#}" >"$capture_dir/codex_prompt.txt"

mkdir -p "$(dirname "$target_file")"
cat >"$target_file" <<'DOC'
# Feature Contract Delta

## 1. Document Meta
- feature_id: FEAT-DELTA-001
- feature_title: Feature contract delta test
- project_type_code: B
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- delta_needed: true
- last_updated: 2026-04-07

## 2. Delta Summary
- baseline_reference: baseline v1
- feature_intent: Add feature-level contract field for this flow.
- impacted_tracks: backend, frontend
- no_delta_reason: none

## 3. Contract Delta Items
### Delta 1: add-feature-flag
- delta_kind: add
- related_baseline_contract: account-profile
- change_scope: add optional feature flag in response
- request_delta: none
- response_delta: add feature_flag field
- event_delta: none
- compatibility_impact: additive only
- verification_expectation: contract tests for feature_flag
- notes: none

## 4. Track Handoff Signals
- backend_handoff: add feature_flag in API response payload
- frontend_mobile_handoff: consume feature_flag in UI behavior

## 5. Known Risks / Open Questions
- risk_1: none
- question_1: none
DOC
OUT
  chmod +x "$repo_dir/bin/codex"
}

setup_git_workspace() {
  local repo_dir="$1"
  setup_workspace_layout "$repo_dir"
  setup_models_file "$repo_dir"
  write_quality_gate_stub "$repo_dir"
  seed_project_definition "$repo_dir"
  seed_common_contract_definition "$repo_dir"
  seed_feature_sources "$repo_dir"
}

test_requires_feature_path_argument() {
  local repo_dir="$TMP_ROOT/repo-missing-arg"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Missing required argument: --feature_path <feature-folder-path>."
}

test_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-staged-required"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"

  cp "$repo_dir/asdlc/.commands/feature_contract_delta.sh" "$repo_dir/feature_contract_delta.sh"
  chmod +x "$repo_dir/feature_contract_delta.sh"

  local status=0
  local out=""
  set +e
  out="$($repo_dir/feature_contract_delta.sh --feature_path "$repo_dir/asdlc/projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_fails_when_requirements_ears_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-ears"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/feature-a/requirements_ears.md"
}

test_fails_when_common_contract_definition_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-common-contract"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/projects/p1/common_contract_definition.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: projects/p1/common_contract_definition.md"
}

test_fails_when_contract_delta_template_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-contract-delta-template"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/.templates/feature_contract_delta_TEMPLATE.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .templates/feature_contract_delta_TEMPLATE.md"
}

test_fails_when_contract_delta_golden_example_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-contract-delta-golden"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
}

test_fails_when_model_phase_missing() {
  local repo_dir="$TMP_ROOT/repo-missing-model-phase"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  cat >"$repo_dir/asdlc/.setup/models.md" <<'OUT'
# Phase | Command | Model | Extra Arg 1 (optional) | Extra Arg 2 (optional) | ...
br_to_ears | codex | gpt-5.4
OUT

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid or missing 'feature_contract_delta' entry"
}

test_does_not_run_quality_helper_directly() {
  local repo_dir="$TMP_ROOT/repo-quality-helper-not-direct"
  local capture_dir="$TMP_ROOT/capture-quality-helper-not-direct"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TEST_QUALITY_HELPER_FAIL=1 .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_contract_delta.md"
  assert_file_not_exists "$capture_dir/helper_arg.txt"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "quality gate command"
  assert_contains "$codex_prompt" "check_feature_contract_delta_quality.sh projects/p1/feature-a/feature_contract_delta.md"
}

test_runs_codex_and_commits_only_target_output() {
  local repo_dir="$TMP_ROOT/repo-success-default"
  local capture_dir="$TMP_ROOT/capture-success-default"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  local br_before=""
  local ears_before=""
  local common_before=""
  br_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  ears_before="$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  common_before="$(cat "$repo_dir/asdlc/projects/p1/common_contract_definition.md")"
  echo "local-change" >>"$repo_dir/asdlc/README.md"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_contract_delta.md"
  assert_file_exists "$capture_dir/codex_args.txt"
  assert_file_exists "$capture_dir/codex_prompt.txt"
  assert_file_not_exists "$capture_dir/helper_arg.txt"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md"

  local codex_args=""
  codex_args="$(cat "$capture_dir/codex_args.txt")"
  assert_contains "$codex_args" "-m"
  assert_contains "$codex_args" "gpt-5.4"
  assert_contains "$codex_args" "--config"
  assert_contains "$codex_args" "model_reasoning_effort='high'"

  local codex_prompt=""
  local backend_repo_resolved=""
  local frontend_repo_resolved=""
  backend_repo_resolved="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  frontend_repo_resolved="$(cd "$repo_dir/repositories/frontend" && pwd -P)"
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" ".rules/feature_contract_delta_rule.md"
  assert_contains "$codex_prompt" "Requirements EARS source: projects/p1/feature-a/requirements_ears.md"
  assert_contains "$codex_prompt" "Common contract baseline source: projects/p1/common_contract_definition.md"
  assert_contains "$codex_prompt" "Target artifact: projects/p1/feature-a/feature_contract_delta.md"
  assert_contains "$codex_prompt" "Repositories to scan (meta_info.class_repo_paths with state=ready):"
  assert_contains "$codex_prompt" "- backend: $backend_repo_resolved"
  assert_not_contains "$codex_prompt" "- frontend: $frontend_repo_resolved"
  assert_not_contains "$codex_prompt" "Project type code:"

  assert_equal "$br_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/feature_br_summary.md")"
  assert_equal "$ears_before" "$(cat "$repo_dir/asdlc/projects/p1/feature-a/requirements_ears.md")"
  assert_equal "$common_before" "$(cat "$repo_dir/asdlc/projects/p1/common_contract_definition.md")"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md"
}

test_no_ready_classes_still_writes_contract_delta() {
  local repo_dir="$TMP_ROOT/repo-no-ready"
  local capture_dir="$TMP_ROOT/capture-no-ready"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  cat >"$repo_dir/asdlc/projects/p1/init_progress_definition.yaml" <<EOF_DEF
meta_info:
  project_type_code: "C"
  project_type_label: "Existing project with code-first context"
  class_repo_paths:
    backend:
      state: "deferred"
      path: "$repo_dir/repositories/backend"
    frontend:
      state: "deferred"
      path: "$repo_dir/repositories/frontend"

steps: []
EOF_DEF

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a"
  )"

  assert_contains "$out" "Updated projects/p1/feature-a/feature_contract_delta.md"
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md"

  local prompt=""
  local backend_repo_resolved=""
  local frontend_repo_resolved=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  backend_repo_resolved="$(cd "$repo_dir/repositories/backend" && pwd -P)"
  frontend_repo_resolved="$(cd "$repo_dir/repositories/frontend" && pwd -P)"
  assert_contains "$prompt" "Repositories to scan (meta_info.class_repo_paths with state=ready):"
  assert_contains "$prompt" "- none"
  assert_not_contains "$prompt" "- backend: $backend_repo_resolved"
  assert_not_contains "$prompt" "- frontend: $frontend_repo_resolved"
  assert_not_contains "$prompt" "Project type code:"
}

test_skips_empty_commit_when_output_is_unchanged() {
  local repo_dir="$TMP_ROOT/repo-empty-commit-skip"
  local capture_dir="$TMP_ROOT/capture-empty-commit-skip"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" >/dev/null
  )
  (
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" >/dev/null
  )
  assert_file_exists "$repo_dir/asdlc/projects/p1/feature-a/feature_contract_delta.md"
}

test_supports_absolute_feature_path() {
  local repo_dir="$TMP_ROOT/repo-success-absolute-feature-path"
  local capture_dir="$TMP_ROOT/capture-success-absolute-feature-path"
  local feature_path="projects/p1/custom-folder"
  local absolute_feature_path=""
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"
  seed_feature_sources "$repo_dir" "$feature_path" "B"
  absolute_feature_path="$repo_dir/asdlc/$feature_path"

  local out=""
  out="$(
    cd "$repo_dir/asdlc" &&
    PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" TARGET_FEATURE_CONTRACT_DELTA_FILE="$feature_path/feature_contract_delta.md" \
      .commands/feature_contract_delta.sh --feature_path "$absolute_feature_path"
  )"

  assert_contains "$out" "Updated $feature_path/feature_contract_delta.md"
  assert_file_exists "$repo_dir/asdlc/$feature_path/feature_contract_delta.md"

  local codex_prompt=""
  codex_prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$codex_prompt" "Feature root: $feature_path"
  assert_contains "$codex_prompt" "Target artifact: $feature_path/feature_contract_delta.md"
  assert_not_contains "$codex_prompt" "Target artifact: projects/p1/feature-a/feature_contract_delta.md"
}

test_prompt_binds_cross_class_peer_trigger_helper() {
  local repo_dir="$TMP_ROOT/repo-peer-trigger-bound"
  local capture_dir="$TMP_ROOT/capture-peer-trigger-bound"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  setup_codex_stub "$repo_dir"

  cd "$repo_dir/asdlc" && PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
    .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" >/dev/null

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" "Cross-class peer trigger helper command: .helper/check_cross_class_peer_trigger.sh projects/p1/init_progress_definition.yaml"
  assert_not_contains "$prompt" "§5 Cross-Class Transport/Contract Approach mirror applies"
  assert_not_contains "$prompt" "§5 Cross-Class Transport/Contract Approach mirror does not apply"
  assert_contains "$prompt" "- Pending sibling contract deltas:"
  assert_contains "$prompt" "- none"
}

test_binds_pending_sibling_contract_delta_sources() {
  local repo_dir="$TMP_ROOT/repo-pending-contract-delta"
  local capture_dir="$TMP_ROOT/capture-pending-contract-delta"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  seed_sibling_contract_delta "$repo_dir" "feature-z"
  setup_codex_stub "$repo_dir"

  cd "$repo_dir/asdlc" && PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
    .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" >/dev/null

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" "projects/p1/feature-z/feature_contract_delta.md"
  assert_contains "$prompt" "Pending contract delta source: feature-z/feature_contract_delta.md"
  assert_contains "$prompt" "Pending contract delta source labels are relative to projects/p1; open the matching read-only input at projects/p1/<folder>/feature_contract_delta.md."
}

test_excludes_sibling_plan_without_contract_delta() {
  local repo_dir="$TMP_ROOT/repo-sibling-without-contract-delta"
  local capture_dir="$TMP_ROOT/capture-sibling-without-contract-delta"
  mkdir -p "$repo_dir" "$capture_dir"
  setup_git_workspace "$repo_dir"
  seed_sibling_implementation_plan_only "$repo_dir" "feature-no-delta"
  setup_codex_stub "$repo_dir"

  cd "$repo_dir/asdlc" && PATH="$repo_dir/bin:$PATH" TEST_CAPTURE_DIR="$capture_dir" \
    .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" >/dev/null

  local prompt=""
  prompt="$(cat "$capture_dir/codex_prompt.txt")"
  assert_contains "$prompt" "- Pending sibling contract deltas:"
  assert_contains "$prompt" "- none"
  assert_not_contains "$prompt" "Pending contract delta source: feature-no-delta/feature_contract_delta.md"
  assert_not_contains "$prompt" "projects/p1/feature-no-delta/feature_contract_delta.md"
}

test_missing_cross_class_peer_trigger_helper_fails_fast() {
  local repo_dir="$TMP_ROOT/repo-missing-peer-trigger-helper"
  mkdir -p "$repo_dir"
  setup_git_workspace "$repo_dir"
  rm -f "$repo_dir/asdlc/.helper/check_cross_class_peer_trigger.sh"

  local status=0
  local out=""
  set +e
  out="$(cd "$repo_dir/asdlc" && .commands/feature_contract_delta.sh --feature_path "projects/p1/feature-a" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: .helper/check_cross_class_peer_trigger.sh"
}

test_requires_feature_path_argument
test_requires_staged_command_location
test_fails_when_requirements_ears_missing
test_fails_when_common_contract_definition_missing
test_fails_when_contract_delta_template_missing
test_fails_when_contract_delta_golden_example_missing
test_fails_when_model_phase_missing
test_does_not_run_quality_helper_directly
test_runs_codex_and_commits_only_target_output
test_no_ready_classes_still_writes_contract_delta
test_skips_empty_commit_when_output_is_unchanged
test_supports_absolute_feature_path
test_prompt_binds_cross_class_peer_trigger_helper
test_binds_pending_sibling_contract_delta_sources
test_excludes_sibling_plan_without_contract_delta
test_missing_cross_class_peer_trigger_helper_fails_fast

echo "All feature contract delta initializer tests passed."
