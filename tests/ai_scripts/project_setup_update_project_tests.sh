#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPTION_1_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
OPTION_2_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
OPTION_3_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_update_project.sh"
COMMON_LIBS_SRC="$SOURCE_ROOT/overmind/scripts/common_libs"
OVERMIND_CLI_BUNDLE_REL_PATH="packages/asdlc-coordinator/dist/overmind.js"
SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-task-to-br"
SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$SKILL_SOURCE_REL_PATH"
REPO_BR_SCAN_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-repo-br-scan"
REPO_BR_SCAN_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$REPO_BR_SCAN_SKILL_SOURCE_REL_PATH"
BR_CLARIFICATION_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-br-clarification"
BR_CLARIFICATION_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$BR_CLARIFICATION_SKILL_SOURCE_REL_PATH"
REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-requirements-ears"
REQUIREMENTS_EARS_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH"
EARS_REVIEW_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-ears-review"
EARS_REVIEW_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$EARS_REVIEW_SKILL_SOURCE_REL_PATH"
CONTRACT_DELTA_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-contract-delta"
CONTRACT_DELTA_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$CONTRACT_DELTA_SKILL_SOURCE_REL_PATH"
SURFACE_MAP_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-surface-map"
SURFACE_MAP_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$SURFACE_MAP_SKILL_SOURCE_REL_PATH"
SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-surface-map-enrich"
SURFACE_MAP_ENRICH_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH"
TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-technical-requirements"
TECHNICAL_REQUIREMENTS_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH"
IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-implementation-slices"
IMPLEMENTATION_SLICES_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH"
PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-prerequisite-gaps"
PREREQUISITE_GAPS_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH"
IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-implementation-plan"
IMPLEMENTATION_PLAN_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH"
PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-plan-semantic-review"
PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH"
CONTRACT_RECONCILIATION_SKILL_SOURCE_REL_PATH="packages/installer/_data/skills/overmind-contract-reconciliation"
CONTRACT_RECONCILIATION_SKILL_SOURCE_DIR_SRC="$SOURCE_ROOT/$CONTRACT_RECONCILIATION_SKILL_SOURCE_REL_PATH"

TMP_ROOT="$(mktemp -d)"
TMP_ROOT="$(cd "$TMP_ROOT" && pwd -P)"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_zero_status() {
  local status="$1"
  if [[ "$status" -ne 0 ]]; then
    echo "Assertion failed: expected exit status 0, got $status" >&2
    exit 1
  fi
}

assert_nonzero_status() {
  local status="$1"
  if [[ "$status" -eq 0 ]]; then
    echo "Assertion failed: expected non-zero exit status" >&2
    exit 1
  fi
}

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
    echo "Assertion failed: expected output NOT to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
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
  if [[ -e "$path" ]]; then
    echo "Assertion failed: expected file to be absent: $path" >&2
    exit 1
  fi
}

assert_file_content_equal() {
  local actual_path="$1"
  local expected_content="$2"
  local actual_content=""
  actual_content="$(cat "$actual_path")"
  if [[ "$actual_content" != "$expected_content" ]]; then
    echo "Assertion failed: file content mismatch: $actual_path" >&2
    echo "Expected:" >&2
    echo "$expected_content" >&2
    echo "Actual:" >&2
    echo "$actual_content" >&2
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

setup_repo_layout() {
  local repo_dir="$1"
  mkdir -p \
    "$repo_dir/overmind/scripts/project_mgmt" \
    "$repo_dir/overmind/scripts" \
    "$repo_dir/overmind/scripts/common_libs"
  cp "$OPTION_1_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
  cp "$OPTION_2_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
  cp "$OPTION_3_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh"
  cp "$COMMON_LIBS_SRC/project_setup_common.sh" "$repo_dir/overmind/scripts/common_libs/project_setup_common.sh"
  cp "$COMMON_LIBS_SRC/class_repo_paths.sh" "$repo_dir/overmind/scripts/common_libs/class_repo_paths.sh"
  cp "$COMMON_LIBS_SRC/check_implementation_plan_readiness.sh" "$repo_dir/overmind/scripts/common_libs/check_implementation_plan_readiness.sh"
  cp "$SOURCE_ROOT/overmind/scripts/init_project_stack_blueprints.sh" "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh"
  cp "$SOURCE_ROOT/overmind/scripts/project_mgmt/project_register_worker.sh" "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh"
  cp "$SOURCE_ROOT/overmind/scripts/init_common_contract_definition.sh" "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  cp "$SOURCE_ROOT/overmind/scripts/feature_assing_workers.sh" "$repo_dir/overmind/scripts/feature_assing_workers.sh"
  cp -R "$SOURCE_ROOT/overmind/rules" "$repo_dir/overmind/rules"
  cp -R "$SOURCE_ROOT/overmind/templates" "$repo_dir/overmind/templates"
  cp -R "$SOURCE_ROOT/overmind/golden_examples" "$repo_dir/overmind/golden_examples"
  cp -R "$SOURCE_ROOT/overmind/scripts/helper" "$repo_dir/overmind/scripts/helper"
  cp -R "$SOURCE_ROOT/overmind/setup" "$repo_dir/overmind/setup"
  mkdir -p "$repo_dir/packages/asdlc-coordinator/dist"
  cat >"$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH" <<'OUT'
#!/usr/bin/env node
// Test stub: record each invocation's argv next to the staged CLI so the update
// flow's delegation to `project reconcile` can be asserted without a real session.
const fs = require("fs");
const path = require("path");
fs.appendFileSync(
  path.join(__dirname, "..", ".overmind-invocations.log"),
  process.argv.slice(2).join(" ") + "\n"
);
OUT
  chmod +x "$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH"
  mkdir -p "$repo_dir/$(dirname "$SKILL_SOURCE_REL_PATH")"
  cp -R "$SKILL_SOURCE_DIR_SRC" "$repo_dir/$SKILL_SOURCE_REL_PATH"
  cp -R "$REPO_BR_SCAN_SKILL_SOURCE_DIR_SRC" "$repo_dir/$REPO_BR_SCAN_SKILL_SOURCE_REL_PATH"
  cp -R "$BR_CLARIFICATION_SKILL_SOURCE_DIR_SRC" "$repo_dir/$BR_CLARIFICATION_SKILL_SOURCE_REL_PATH"
  cp -R "$REQUIREMENTS_EARS_SKILL_SOURCE_DIR_SRC" "$repo_dir/$REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH"
  cp -R "$EARS_REVIEW_SKILL_SOURCE_DIR_SRC" "$repo_dir/$EARS_REVIEW_SKILL_SOURCE_REL_PATH"
  cp -R "$CONTRACT_DELTA_SKILL_SOURCE_DIR_SRC" "$repo_dir/$CONTRACT_DELTA_SKILL_SOURCE_REL_PATH"
  cp -R "$SURFACE_MAP_SKILL_SOURCE_DIR_SRC" "$repo_dir/$SURFACE_MAP_SKILL_SOURCE_REL_PATH"
  cp -R "$SURFACE_MAP_ENRICH_SKILL_SOURCE_DIR_SRC" "$repo_dir/$SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH"
  cp -R "$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_DIR_SRC" "$repo_dir/$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH"
  cp -R "$IMPLEMENTATION_SLICES_SKILL_SOURCE_DIR_SRC" "$repo_dir/$IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH"
  cp -R "$PREREQUISITE_GAPS_SKILL_SOURCE_DIR_SRC" "$repo_dir/$PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH"
  cp -R "$IMPLEMENTATION_PLAN_SKILL_SOURCE_DIR_SRC" "$repo_dir/$IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH"
  cp -R "$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_DIR_SRC" "$repo_dir/$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH"
  cp -R "$CONTRACT_RECONCILIATION_SKILL_SOURCE_DIR_SRC" "$repo_dir/$CONTRACT_RECONCILIATION_SKILL_SOURCE_REL_PATH"
  chmod +x \
    "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh" \
    "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh" \
    "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh" \
    "$repo_dir/overmind/scripts/init_common_contract_definition.sh" \
    "$repo_dir/overmind/scripts/feature_assing_workers.sh"
  find "$repo_dir/overmind/scripts/helper" -maxdepth 1 -type f -exec chmod +x {} +
}

setup_git_repo_with_identity() {
  local repo_dir="$1"
  setup_repo_layout "$repo_dir"
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

bootstrap_asdlc_workspace() {
  local repo_dir="$1"
  local bootstrap_parent="$2"
  local asdlc_root="$bootstrap_parent/asdlc"
  (
    cd "$repo_dir"
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh >/dev/null
  )
  printf '%s' "$asdlc_root"
}

write_project_definition() {
  local def_path="$1"
  local project_id="$2"
  local type_code="$3"
  local type_label="$4"
  shift 4
  local c="" s="" p=""

  {
    echo "meta_info:"
    echo "  project_id: \"$project_id\""
    echo "  project_classes:"
    for pair in "$@"; do
      IFS='|' read -r c s p <<<"$pair"
      echo "    - $c"
    done
    echo "  project_type_code: \"$type_code\""
    echo "  project_type_label: \"$type_label\""
    echo "  class_repo_paths:"
    for pair in "$@"; do
      IFS='|' read -r c s p <<<"$pair"
      echo "    $c:"
      echo "      state: \"$s\""
      echo "      path: \"$p\""
    done
    echo ""
    echo "steps:"
    echo "  - step_name: \"Step 1\""
    echo "    status: \"pending\""
  } >"$def_path"
}

create_test_project() {
  local asdlc_root="$1"
  local project_id="$2"
  local type_code="$3"
  local type_label="$4"
  shift 4

  local project_dir="$asdlc_root/projects/$project_id"
  mkdir -p "$project_dir"
  write_project_definition "$project_dir/init_progress_definition.yaml" "$project_id" "$type_code" "$type_label" "$@"
}

INVOCATION_LOG_NAME=".overmind-invocations.log"

test_update_project_quits_at_project_prompt() {
  local repo_dir="$TMP_ROOT/repo-update-quit-project"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-quit-project"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local status=0
  set +e
  printf 'q\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  assert_file_content_equal "$def_path" "$before"
  assert_file_not_exists "$asdlc_root/$INVOCATION_LOG_NAME"
}

test_update_project_notice_and_decline_aborts_without_delegation() {
  local repo_dir="$TMP_ROOT/repo-update-decline"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-decline"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "A" "New project" "backend|deferred|"

  local def_path="$asdlc_root/projects/proj-001/init_progress_definition.yaml"
  local before=""
  before="$(cat "$def_path")"

  local out=""
  local status=0
  set +e
  out="$(printf '1\nn\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>&1)"
  status=$?
  set -e

  assert_zero_status "$status"
  assert_contains "$out" "full project reconciliation flow"
  assert_contains "$out" "Aborted: no changes made to project 'proj-001'."
  assert_file_content_equal "$def_path" "$before"
  assert_file_not_exists "$asdlc_root/$INVOCATION_LOG_NAME"
}

test_update_project_accept_delegates_to_project_reconcile() {
  local repo_dir="$TMP_ROOT/repo-update-delegate"
  local bootstrap_parent="$TMP_ROOT/asdlc-update-delegate"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  create_test_project "$asdlc_root" "proj-001" "B" "Existing project with partial context" \
    "backend|deferred|"

  local status=0
  set +e
  printf '1\ny\n' | "$asdlc_root/.commands/project_setup_update_project.sh" 2>/dev/null
  status=$?
  set -e

  assert_zero_status "$status"
  local log_path="$asdlc_root/$INVOCATION_LOG_NAME"
  assert_file_exists "$log_path"
  assert_contains "$(cat "$log_path")" "project reconcile --path $asdlc_root/projects/proj-001"
}

test_update_project_quits_at_project_prompt
test_update_project_notice_and_decline_aborts_without_delegation
test_update_project_accept_delegates_to_project_reconcile

echo "All project_setup_update_project helper tests passed."
