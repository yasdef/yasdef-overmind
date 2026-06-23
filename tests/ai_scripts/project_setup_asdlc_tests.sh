#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPTION_1_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
OPTION_2_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
OPTION_3_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_update_project.sh"
COMMON_LIBS_SRC="$SOURCE_ROOT/overmind/scripts/common_libs"
OPTION_4_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/init_progress_scanner.sh"
INIT_PROJECT_STACK_BLUEPRINTS_SRC="$SOURCE_ROOT/overmind/scripts/init_project_stack_blueprints.sh"
OPTION_5_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/init_common_contract_definition.sh"
PROJECT_CONTRACT_RECONCILIATION_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
REGISTER_WORKER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_register_worker.sh"
OPTION_6_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_scaffold.sh"
PROJECT_ADD_FEATURE_E2E_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
OPTION_18_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_assing_workers.sh"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/init_progress_definition_TEMPLATE.yaml"
RULES_DIR_SRC="$SOURCE_ROOT/overmind/rules"
TEMPLATES_DIR_SRC="$SOURCE_ROOT/overmind/templates"
GOLDEN_EXAMPLES_DIR_SRC="$SOURCE_ROOT/overmind/golden_examples"
HELPER_DIR_SRC="$SOURCE_ROOT/overmind/scripts/helper"
SETUP_DIR_SRC="$SOURCE_ROOT/overmind/setup"
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
SKILL_RUNNER_DIRS=(
  ".codex"
  ".claude"
)
STAGED_RULE_FILES=(
  "common_contract_definition_rule.md"
  "project_stack_blueprint_rule.md"
  "task_to_br_rule.md"
  "project_contract_reconciliation_rule.md"
)
STAGED_TEMPLATE_FILES=(
  "common_contract_definition_TEMPLATE.md"
  "feature_br_summary_TEMPLATE.md"
  "init_progress_definition_TEMPLATE.yaml"
  "missing_br_data_TEMPLATE.md"
  "project_stack_blueprint_be_TEMPLATE.md"
  "project_stack_blueprint_fe_TEMPLATE.md"
  "project_stack_blueprint_mobile_TEMPLATE.md"
  "requirements_ears_review_TEMPLATE.md"
  "reqirements_ears_TEMPLATE.md"
)
STAGED_GOLDEN_EXAMPLE_FILES=(
  "common_contract_definition_GOLDEN_EXAMPLE.md"
  "feature_br_summary_GOLDEN_EXAMPLE.md"
  "missing_br_data_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_be_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_fe_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
  "requirements_ears_review_GOLDEN_EXAMPLE.md"
  "reqirements_ears_GOLDEN_EXAMPLE.md"
)
STAGED_HELPER_FILES=(
  "check_common_contract_definition_quality.sh"
  "check_cross_class_peer_trigger.sh"
  "check_project_stack_blueprint_quality.sh"
)
STAGED_SETUP_FILES=(
  "external_sources.yaml"
  "models.md"
)

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

assert_matches() {
  local value="$1"
  local regex="$2"
  if [[ ! "$value" =~ $regex ]]; then
    echo "Assertion failed: expected '$value' to match regex '$regex'" >&2
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
  if [[ -e "$path" ]]; then
    echo "Assertion failed: expected file to not exist: $path" >&2
    exit 1
  fi
}

assert_dir_exists() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "Assertion failed: expected directory to exist: $path" >&2
    exit 1
  fi
}

assert_file_executable() {
  local path="$1"
  if [[ ! -x "$path" ]]; then
    echo "Assertion failed: expected executable file: $path" >&2
    exit 1
  fi
}

assert_file_content_equal() {
  local path_a="$1"
  local path_b="$2"
  if ! cmp -s "$path_a" "$path_b"; then
    echo "Assertion failed: expected files to have equal content:" >&2
    echo "  $path_a" >&2
    echo "  $path_b" >&2
    exit 1
  fi
}

assert_git_branch_exists() {
  local repo_path="$1"
  local branch_name="$2"
  if ! git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch_name"; then
    echo "Assertion failed: expected git branch to exist: $branch_name" >&2
    exit 1
  fi
}

assert_git_repo_initialized() {
  local repo_path="$1"
  local inside_work_tree=""
  inside_work_tree="$(git -C "$repo_path" rev-parse --is-inside-work-tree 2>/dev/null || true)"
  if [[ "$inside_work_tree" != "true" ]]; then
    echo "Assertion failed: expected git repository at: $repo_path" >&2
    exit 1
  fi
}

assert_git_head_subject() {
  local repo_path="$1"
  local expected_subject="$2"
  local actual_subject=""
  actual_subject="$(git -C "$repo_path" log -1 --pretty=%s)"
  if [[ "$actual_subject" != "$expected_subject" ]]; then
    echo "Assertion failed: expected git HEAD subject '$expected_subject', got '$actual_subject'" >&2
    exit 1
  fi
}

list_regular_file_names_maxdepth_one() {
  local path="$1"
  find "$path" -maxdepth 1 -type f -exec basename {} \; | sort
}

assert_directory_contains_exact_files() {
  local path="$1"
  shift
  local expected_list=""
  local actual_list=""

  expected_list="$(printf '%s\n' "$@" | sort)"
  actual_list="$(list_regular_file_names_maxdepth_one "$path")"
  if [[ "$expected_list" != "$actual_list" ]]; then
    echo "Assertion failed: staged files mismatch for directory: $path" >&2
    echo "Expected:" >&2
    echo "$expected_list" >&2
    echo "Actual:" >&2
    echo "$actual_list" >&2
    exit 1
  fi
}

assert_support_assets_match_repo_sources() {
  local repo_dir="$1"
  local asdlc_root="$2"

  assert_dir_exists "$asdlc_root/.rules"
  assert_dir_exists "$asdlc_root/.templates"
  assert_dir_exists "$asdlc_root/.golden_examples"
  assert_dir_exists "$asdlc_root/.helper"
  assert_dir_exists "$asdlc_root/.setup"
  assert_directory_contains_exact_files "$asdlc_root/.rules" "${STAGED_RULE_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.templates" "${STAGED_TEMPLATE_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.golden_examples" "${STAGED_GOLDEN_EXAMPLE_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.helper" "${STAGED_HELPER_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.setup" "${STAGED_SETUP_FILES[@]}"

  local file_name=""
  for file_name in "${STAGED_RULE_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/rules/$file_name" "$asdlc_root/.rules/$file_name"
  done
  for file_name in "${STAGED_TEMPLATE_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/templates/$file_name" "$asdlc_root/.templates/$file_name"
  done
  for file_name in "${STAGED_GOLDEN_EXAMPLE_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/golden_examples/$file_name" "$asdlc_root/.golden_examples/$file_name"
  done
  for file_name in "${STAGED_HELPER_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/scripts/helper/$file_name" "$asdlc_root/.helper/$file_name"
    assert_file_executable "$asdlc_root/.helper/$file_name"
  done
  for file_name in "${STAGED_SETUP_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/setup/$file_name" "$asdlc_root/.setup/$file_name"
  done

  assert_file_not_exists "$asdlc_root/.rules/contracts_inventory_be_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/technical_requirements_structuring_be_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/step_state_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_project_tech_summary_be_quality.sh"
}

assert_support_assets_except_setup_match_repo_sources() {
  local repo_dir="$1"
  local asdlc_root="$2"

  assert_dir_exists "$asdlc_root/.rules"
  assert_dir_exists "$asdlc_root/.templates"
  assert_dir_exists "$asdlc_root/.golden_examples"
  assert_dir_exists "$asdlc_root/.helper"
  assert_dir_exists "$asdlc_root/.setup"
  assert_directory_contains_exact_files "$asdlc_root/.rules" "${STAGED_RULE_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.templates" "${STAGED_TEMPLATE_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.golden_examples" "${STAGED_GOLDEN_EXAMPLE_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.helper" "${STAGED_HELPER_FILES[@]}"
  assert_directory_contains_exact_files "$asdlc_root/.setup" "${STAGED_SETUP_FILES[@]}"

  local file_name=""
  for file_name in "${STAGED_RULE_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/rules/$file_name" "$asdlc_root/.rules/$file_name"
  done
  for file_name in "${STAGED_TEMPLATE_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/templates/$file_name" "$asdlc_root/.templates/$file_name"
  done
  for file_name in "${STAGED_GOLDEN_EXAMPLE_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/golden_examples/$file_name" "$asdlc_root/.golden_examples/$file_name"
  done
  for file_name in "${STAGED_HELPER_FILES[@]}"; do
    assert_file_content_equal "$repo_dir/overmind/scripts/helper/$file_name" "$asdlc_root/.helper/$file_name"
    assert_file_executable "$asdlc_root/.helper/$file_name"
  done

  assert_file_not_exists "$asdlc_root/.rules/contracts_inventory_be_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/technical_requirements_structuring_be_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/step_state_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_project_tech_summary_be_quality.sh"
}

assert_staged_overmind_cli_matches_repo_source() {
  local repo_dir="$1"
  local asdlc_root="$2"
  local staged_cli_path="$asdlc_root/.overmind/overmind.js"

  assert_dir_exists "$asdlc_root/.overmind"
  assert_file_exists "$staged_cli_path"
  assert_file_executable "$staged_cli_path"
  assert_file_content_equal "$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH" "$staged_cli_path"
}

assert_runner_skills_installed() {
  local repo_dir="$1"
  local asdlc_root="$2"
  local runner_dir=""
  local skill_dir=""

  for runner_dir in "${SKILL_RUNNER_DIRS[@]}"; do
    skill_dir="$asdlc_root/$runner_dir/skills/overmind-task-to-br"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/feature_br_summary_TEMPLATE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-repo-br-scan"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$REPO_BR_SCAN_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-br-clarification"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$BR_CLARIFICATION_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/feature_br_summary_TEMPLATE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-requirements-ears"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$REQUIREMENTS_EARS_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/reqirements_ears_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/reqirements_ears_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-ears-review"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$EARS_REVIEW_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/requirements_ears_review_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/requirements_ears_review_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-contract-delta"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$CONTRACT_DELTA_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/feature_contract_delta_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/feature_contract_delta_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-surface-map"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$SURFACE_MAP_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/project_surface_struct_resp_map_be_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/project_surface_struct_resp_map_fe_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
    assert_file_exists "$skill_dir/assets/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-surface-map-enrich"
    assert_dir_exists "$skill_dir"
    assert_file_not_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$SURFACE_MAP_ENRICH_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-technical-requirements"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$TECHNICAL_REQUIREMENTS_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/technical_requirements_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/technical_requirements_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-implementation-slices"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal \
      "$repo_dir/$IMPLEMENTATION_SLICES_SKILL_SOURCE_REL_PATH/SKILL.md" \
      "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/implementation_slices_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/implementation_slices_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-prerequisite-gaps"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal "$repo_dir/$PREREQUISITE_GAPS_SKILL_SOURCE_REL_PATH/SKILL.md" "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/prerequisite_gaps_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/prerequisite_gaps_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-implementation-plan"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal "$repo_dir/$IMPLEMENTATION_PLAN_SKILL_SOURCE_REL_PATH/SKILL.md" "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/implementation_plan_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/implementation_plan_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"

    skill_dir="$asdlc_root/$runner_dir/skills/overmind-plan-semantic-review"
    assert_dir_exists "$skill_dir"
    assert_dir_exists "$skill_dir/assets"
    assert_file_exists "$skill_dir/SKILL.md"
    assert_file_content_equal "$repo_dir/$PLAN_SEMANTIC_REVIEW_SKILL_SOURCE_REL_PATH/SKILL.md" "$skill_dir/SKILL.md"
    assert_file_exists "$skill_dir/assets/implementation_plan_semantic_review_TEMPLATE.md"
    assert_file_exists "$skill_dir/assets/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
    assert_file_not_exists "$skill_dir/overmind.js"
  done

  assert_file_not_exists "$asdlc_root/.templates/feature_contract_delta_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_not_exists "$asdlc_root/.rules/feature_repo_surface_and_exec_context_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/project_surface_struct_resp_map_be_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.templates/project_surface_struct_resp_map_fe_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
  assert_file_not_exists "$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_not_exists "$asdlc_root/.rules/technical_requirements_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/technical_requirements_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/technical_requirements_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_feature_technical_requirements_quality.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_not_exists "$asdlc_root/.rules/implementation_slices_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/implementation_slices_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/implementation_slices_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_implementation_slices_quality.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_prerequisite_gaps.sh"
  assert_file_not_exists "$asdlc_root/.rules/prerequisite_gaps_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/prerequisite_gaps_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_prerequisite_gaps_quality.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_implementation_plan.sh"
  assert_file_not_exists "$asdlc_root/.rules/implementation_plan_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/implementation_plan_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/implementation_plan_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_implementation_plan_quality.sh"
  assert_file_exists "$asdlc_root/common_libs/list_committed_sibling_features.sh"
  assert_file_exists "$asdlc_root/.helper/check_cross_class_peer_trigger.sh"
}

assert_feature_requirements_and_plan_commands_use_staged_runtime_assets() {
  local asdlc_root="$1"
  local assign_workers_cmd_path="$asdlc_root/.commands/feature_assing_workers.sh"

  assert_contains "$(cat "$assign_workers_cmd_path")" 'Missing required argument: --feature_path <asdlc/projects/<project-id>/<feature-folder>>.'
  assert_contains "$(cat "$assign_workers_cmd_path")" 'ERROR: no active worker available for class'
}

count_project_records() {
  local metadata_path="$1"
  grep -c '^  - project: ' "$metadata_path" || true
}

extract_last_project_uuid() {
  local metadata_path="$1"
  awk '/^  - project: /{uuid=$3} END{print uuid}' "$metadata_path"
}

extract_last_internal_folder() {
  local metadata_path="$1"
  awk -F': ' '/^    internal_folder: /{folder=$2} END{gsub(/"/, "", folder); print folder}' "$metadata_path"
}

extract_last_created_at() {
  local metadata_path="$1"
  awk -F': ' '/^    created_at: /{created_at=$2} END{gsub(/"/, "", created_at); print created_at}' "$metadata_path"
}

extract_last_project_block() {
  local metadata_path="$1"
  awk '
/^  - project: / {
  block = $0 ORS
  in_block = 1
  next
}
in_block == 1 {
  block = block $0 ORS
}
END {
  printf "%s", block
}
' "$metadata_path"
}

extract_project_id_from_definition() {
  local definition_path="$1"
  awk -F': ' '/^  project_id: /{project_id=$2; gsub(/"/, "", project_id); print project_id; exit}' "$definition_path"
}

ensure_repo_has_local_main_branch() {
  local repo_dir="$1"
  local current_branch=""

  current_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"
  if ! git -C "$repo_dir" show-ref --verify --quiet refs/heads/main; then
    git -C "$repo_dir" branch -m "$current_branch" main
  fi
  git -C "$repo_dir" checkout -q main
}

create_fixed_date_shim() {
  local shim_dir="$1"
  local fixed_epoch_ms="$2"
  local fixed_created_at="$3"
  local fixed_epoch_seconds=""
  fixed_epoch_seconds="${fixed_epoch_ms%000}"

  mkdir -p "$shim_dir"
  cat >"$shim_dir/date" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if [[ "\${1-}" == "+%s%3N" ]]; then
  printf '%s\n' "$fixed_epoch_ms"
  exit 0
fi

if [[ "\${1-}" == "+%s" ]]; then
  printf '%s\n' "$fixed_epoch_seconds"
  exit 0
fi

if [[ "\${1-}" == "-u" && "\${2-}" == "+%Y-%m-%dT%H:%M:%SZ" ]]; then
  printf '%s\n' "$fixed_created_at"
  exit 0
fi

exec /bin/date "\$@"
EOF
  chmod +x "$shim_dir/date"
}

setup_repo_layout() {
  local repo_dir="$1"
  mkdir -p "$repo_dir/overmind/scripts/project_mgmt" "$repo_dir/overmind/scripts" "$repo_dir/overmind/scripts/common_libs"
  cp "$OPTION_1_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
  cp "$OPTION_2_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
  cp "$OPTION_3_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh"
  cp "$COMMON_LIBS_SRC/project_setup_common.sh" "$repo_dir/overmind/scripts/common_libs/project_setup_common.sh"
  cp "$COMMON_LIBS_SRC/class_repo_paths.sh" "$repo_dir/overmind/scripts/common_libs/class_repo_paths.sh"
  cp "$COMMON_LIBS_SRC/check_implementation_plan_readiness.sh" "$repo_dir/overmind/scripts/common_libs/check_implementation_plan_readiness.sh"
  cp "$COMMON_LIBS_SRC/list_committed_sibling_features.sh" "$repo_dir/overmind/scripts/common_libs/list_committed_sibling_features.sh"
  cp "$COMMON_LIBS_SRC/persist_class_repo_attach.sh" "$repo_dir/overmind/scripts/common_libs/persist_class_repo_attach.sh"
  cp "$COMMON_LIBS_SRC/sync_repo_to_default_branch.sh" "$repo_dir/overmind/scripts/common_libs/sync_repo_to_default_branch.sh"
  cp "$OPTION_4_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/init_progress_scanner.sh"
  cp "$INIT_PROJECT_STACK_BLUEPRINTS_SRC" "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh"
  cp "$PROJECT_ADD_FEATURE_E2E_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
  cp "$REGISTER_WORKER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh"
  cp "$OPTION_5_HELPER_SRC" "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  cp "$PROJECT_CONTRACT_RECONCILIATION_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
  cp "$OPTION_6_HELPER_SRC" "$repo_dir/overmind/scripts/feature_br_scaffold.sh"
  cp "$OPTION_18_HELPER_SRC" "$repo_dir/overmind/scripts/feature_assing_workers.sh"
  cp -R "$RULES_DIR_SRC" "$repo_dir/overmind/rules"
  cp -R "$TEMPLATES_DIR_SRC" "$repo_dir/overmind/templates"
  cp -R "$GOLDEN_EXAMPLES_DIR_SRC" "$repo_dir/overmind/golden_examples"
  cp -R "$HELPER_DIR_SRC" "$repo_dir/overmind/scripts/helper"
  cp -R "$SETUP_DIR_SRC" "$repo_dir/overmind/setup"
  mkdir -p "$repo_dir/packages/asdlc-coordinator/dist"
  cat >"$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH" <<'OUT'
#!/usr/bin/env node
console.log("stub overmind");
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
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/init_progress_scanner.sh"
  chmod +x "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh"
  chmod +x "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_br_scaffold.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_assing_workers.sh"
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

test_first_init_machine_bootstraps_asdlc_workspace_with_local_template() {
  local repo_dir="$TMP_ROOT/repo-first-init-success"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-success"
  local asdlc_root="$bootstrap_parent/asdlc"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "ASDLC workspace bootstrap completed: $asdlc_root"
  assert_dir_exists "$asdlc_root"
  assert_dir_exists "$asdlc_root/projects"
  assert_dir_exists "$asdlc_root/.commands"
  assert_dir_exists "$asdlc_root/.rules"
  assert_dir_exists "$asdlc_root/.templates"
  assert_dir_exists "$asdlc_root/.golden_examples"
  assert_dir_exists "$asdlc_root/.helper"
  assert_dir_exists "$asdlc_root/.setup"
  assert_staged_overmind_cli_matches_repo_source "$repo_dir" "$asdlc_root"
  assert_runner_skills_installed "$repo_dir" "$asdlc_root"
  assert_dir_exists "$asdlc_root/common_libs"
  assert_file_exists "$asdlc_root/common_libs/project_setup_common.sh"
  assert_file_exists "$asdlc_root/common_libs/class_repo_paths.sh"
  assert_file_exists "$asdlc_root/common_libs/check_implementation_plan_readiness.sh"
  assert_file_exists "$asdlc_root/common_libs/list_committed_sibling_features.sh"
  assert_file_exists "$asdlc_root/common_libs/persist_class_repo_attach.sh"
  assert_file_exists "$asdlc_root/common_libs/sync_repo_to_default_branch.sh"
  assert_file_executable "$asdlc_root/common_libs/class_repo_paths.sh"
  assert_file_executable "$asdlc_root/common_libs/check_implementation_plan_readiness.sh"
  assert_file_executable "$asdlc_root/common_libs/list_committed_sibling_features.sh"
  assert_file_executable "$asdlc_root/common_libs/persist_class_repo_attach.sh"
  assert_file_executable "$asdlc_root/common_libs/sync_repo_to_default_branch.sh"
  assert_file_exists "$asdlc_root/asdlc_metadata.yaml"
  assert_file_exists "$asdlc_root/quickrun.md"
  assert_file_exists "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_file_exists "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_exists "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_exists "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_exists "$asdlc_root/.commands/init_project_stack_blueprints.sh"
  assert_file_exists "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_exists "$asdlc_root/.commands/project_contract_reconciliation.sh"
  assert_file_exists "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_exists "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_br_to_ears.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_contract_delta.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_file_exists "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_executable "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_executable "$asdlc_root/.commands/init_project_stack_blueprints.sh"
  assert_file_executable "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_executable "$asdlc_root/.commands/project_contract_reconciliation.sh"
  assert_file_executable "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_executable "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_executable "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_file_content_equal \
    "$repo_dir/overmind/templates/init_progress_definition_TEMPLATE.yaml" \
    "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"

  local add_cmd=""
  local scanner_cmd=""
  local quickrun=""
  local metadata=""
  add_cmd="$(cat "$asdlc_root/.commands/project_setup_add_new_project.sh")"
  scanner_cmd="$(cat "$asdlc_root/.commands/init_progress_scanner.sh")"
  quickrun="$(cat "$asdlc_root/quickrun.md")"
  metadata="$(cat "$asdlc_root/asdlc_metadata.yaml")"
  assert_contains "$add_cmd" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$scanner_cmd" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$quickrun" "## 2. Create EARS Requirements"
  assert_contains "$quickrun" 'Project path example: `projects/<project-id>`'
  assert_contains "$quickrun" 'Feature path example: `projects/<project-id>/<feature-folder>`'
  assert_contains "$quickrun" 'Task-to-BR gates run through the staged CLI at `.overmind/overmind.js`.'
  assert_contains "$quickrun" '`overmind-plan-semantic-review` skills are staged for supported runners'
  assert_contains "$quickrun" 'Successful scanner runs persist `projects/<project-id>/step_state_<feature-folder>.md`; stdout remains the canonical machine-consumable output.'
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh"
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id>"
  assert_contains "$quickrun" 'During phase 4.1, the orchestrator starts a Codex repo-br-scan session (when a class repo is ready) followed by a task-to-BR session using the installed skills; when `user_br_input.md` is missing, Codex asks for a local story file or Jira ticket. During phase 4.2, the orchestrator starts the BR-clarification skill and then runs the deterministic readiness check. During phase 5, the orchestrator starts the requirements-EARS skill. During optional phase 5.1, the orchestrator starts the EARS-review skill. During phase 6, it syncs ready repositories and starts the contract-delta skill.'
  assert_contains "$quickrun" '.commands/project_add_feature_e2e.sh --resume 4.2'
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 8.2"
  assert_contains "$quickrun" '.project_add_feature_e2e_state.env'
  assert_contains "$quickrun" 'If `--path` is omitted, the script auto-selects the only project under `projects/`'
  assert_contains "$quickrun" "discovers unfinished feature folders for the project first"
  assert_contains "$quickrun" "asks whether to start a new feature or continue one of the unfinished features"
  assert_contains "$quickrun" "as a convenience only; discovery plus scanner status remains the source of truth"
  assert_contains "$quickrun" ".commands/project_register_worker.sh --path projects/<project-id>"
  assert_contains "$quickrun" ".commands/init_project_stack_blueprints.sh --path projects/<project-id>"
  assert_contains "$quickrun" "projects/<project-id>/workers.yaml"
  assert_contains "$quickrun" ".commands/feature_br_scaffold.sh --path projects/<project-id>"
  assert_contains "$quickrun" "node .overmind/overmind.js context br-clarification projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate br-clarification projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js readiness br-clarification projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context requirements-ears projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate requirements-ears projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context ears-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate ears-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context contract-delta projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate contract-delta projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context surface-map projects/<project-id>/<feature-folder> --class <backend|frontend|mobile>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate surface-map projects/<project-id>/<feature-folder> --class <backend|frontend|mobile>"
  assert_contains "$quickrun" "Optionally enrich unresolved surface-map placeholders from configured knowledge-base MCP sources (Step 7.1)"
  assert_contains "$quickrun" "node .overmind/overmind.js context surface-map-enrich projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context technical-requirements projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate technical-requirements projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context implementation-slices projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate implementation-slices projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context prerequisite-gaps projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate prerequisite-gaps projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context implementation-plan projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate implementation-plan projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Optionally run implementation-plan semantic review (Step 8.4) through the installed"
  assert_contains "$quickrun" "node .overmind/overmind.js context plan-semantic-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate plan-semantic-review projects/<project-id>/<feature-folder>"
  assert_file_not_exists "$asdlc_root/.rules/implementation_plan_semantic_review_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/implementation_plan_semantic_review_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_implementation_plan_semantic_review_quality.sh"
  assert_contains "$quickrun" ".commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" 'This command writes `#### Assigned:` for every plan step with a class-matched worker UUID or `ERROR: no active worker available for class <class>`.'
  assert_contains "$quickrun" ".commands/init_progress_scanner.sh --path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Careful: provide a feature path here, not a project path."
  assert_contains "$quickrun" 'projects/<project-id>/step_state_<feature-folder>.md'
  assert_contains "$metadata" "meta:"
  assert_contains "$metadata" "projects:"
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_scaffold.sh")" 'TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"'
  assert_file_not_exists "$asdlc_root/.rules/user_br_clarification_rule.md"
  assert_file_not_exists "$asdlc_root/.rules/br_to_ears.md"
  assert_file_not_exists "$asdlc_root/.rules/requirements_ears_review_rule.md"
  assert_file_not_exists "$asdlc_root/.helper/check_user_br_clarification_quality.sh"
  assert_file_not_exists "$asdlc_root/.helper/check_requirements_ears_quality.sh"
  assert_file_not_exists "$asdlc_root/.helper/check_requirements_ears_review_quality.sh"
  assert_file_not_exists "$asdlc_root/.rules/feature_contract_delta_rule.md"
  assert_file_not_exists "$asdlc_root/.helper/check_feature_contract_delta_quality.sh"
  assert_feature_requirements_and_plan_commands_use_staged_runtime_assets "$asdlc_root"
  assert_support_assets_match_repo_sources "$repo_dir" "$asdlc_root"
}

test_first_init_machine_fails_when_template_source_missing() {
  local repo_dir="$TMP_ROOT/repo-first-init-missing-template"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  rm -f "$repo_dir/overmind/templates/init_progress_definition_TEMPLATE.yaml"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-missing-template"
  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: overmind/templates/init_progress_definition_TEMPLATE.yaml"
  if [[ -e "$bootstrap_parent/asdlc" ]]; then
    echo "Assertion failed: asdlc workspace should not be created when template source is missing" >&2
    exit 1
  fi
}

test_first_init_machine_fails_when_overmind_cli_bundle_source_missing() {
  local repo_dir="$TMP_ROOT/repo-first-init-missing-overmind-cli-bundle"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  rm -f "$repo_dir/$OVERMIND_CLI_BUNDLE_REL_PATH"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-missing-overmind-cli-bundle"
  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required Overmind CLI bundle not found: $OVERMIND_CLI_BUNDLE_REL_PATH"
  assert_contains "$out" "Run npm install and npm run build from the repository root before ASDLC setup/update."
  if [[ -e "$bootstrap_parent/asdlc" ]]; then
    echo "Assertion failed: asdlc workspace should not be created when Overmind CLI bundle is missing" >&2
    exit 1
  fi
}

test_first_init_machine_update_mode_repairs_missing_commands_without_overwriting_existing_files() {
  local repo_dir="$TMP_ROOT/repo-first-init-update-mode-repair"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-update-mode-repair"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local metadata_path="$asdlc_root/asdlc_metadata.yaml"
  local template_path="$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  local add_cmd_path="$asdlc_root/.commands/project_setup_add_new_project.sh"
  local update_cmd_path="$asdlc_root/.commands/project_setup_update_project.sh"
  local scanner_cmd_path="$asdlc_root/.commands/init_progress_scanner.sh"
  local stack_blueprints_cmd_path="$asdlc_root/.commands/init_project_stack_blueprints.sh"
  local feature_orchestrator_cmd_path="$asdlc_root/.commands/project_add_feature_e2e.sh"
  local common_contract_cmd_path="$asdlc_root/.commands/init_common_contract_definition.sh"
  local contract_reconciliation_cmd_path="$asdlc_root/.commands/project_contract_reconciliation.sh"
  local register_worker_cmd_path="$asdlc_root/.commands/project_register_worker.sh"
  local feature_br_cmd_path="$asdlc_root/.commands/feature_br_scaffold.sh"
  local feature_contract_delta_rule_path="$asdlc_root/.rules/feature_contract_delta_rule.md"
  local feature_contract_delta_helper_path="$asdlc_root/.helper/check_feature_contract_delta_quality.sh"
  local feature_contract_delta_flat_template_path="$asdlc_root/.templates/feature_contract_delta_TEMPLATE.md"
  local feature_contract_delta_flat_golden_path="$asdlc_root/.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
  local repo_surface_context_rule_path="$asdlc_root/.rules/feature_repo_surface_and_exec_context_rule.md"
  local stale_mcp_enrichment_rule_path="$asdlc_root/.rules/feature_surface_map_mcp_placeholder_enrichment_rule.md"
  local repo_surface_be_flat_template_path="$asdlc_root/.templates/project_surface_struct_resp_map_be_TEMPLATE.md"
  local repo_surface_fe_flat_template_path="$asdlc_root/.templates/project_surface_struct_resp_map_fe_TEMPLATE.md"
  local repo_surface_be_flat_golden_path="$asdlc_root/.golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  local repo_surface_fe_flat_golden_path="$asdlc_root/.golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  local repo_surface_be_helper_path="$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_be_quality.sh"
  local repo_surface_fe_helper_path="$asdlc_root/.helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"
  local feature_technical_requirements_cmd_path="$asdlc_root/.commands/feature_technical_requirements.sh"
  local feature_implementation_slices_cmd_path="$asdlc_root/.commands/feature_implementation_slices.sh"
  local implementation_slices_rule_path="$asdlc_root/.rules/implementation_slices_rule.md"
  local implementation_slices_template_path="$asdlc_root/.templates/implementation_slices_TEMPLATE.md"
  local implementation_slices_golden_path="$asdlc_root/.golden_examples/implementation_slices_GOLDEN_EXAMPLE.md"
  local implementation_slices_helper_path="$asdlc_root/.helper/check_implementation_slices_quality.sh"
  local prerequisite_gaps_cmd_path="$asdlc_root/.commands/feature_prerequisite_gaps.sh"
  local prerequisite_gaps_rule_path="$asdlc_root/.rules/prerequisite_gaps_rule.md"
  local prerequisite_gaps_template_path="$asdlc_root/.templates/prerequisite_gaps_TEMPLATE.md"
  local prerequisite_gaps_golden_path="$asdlc_root/.golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md"
  local prerequisite_gaps_helper_path="$asdlc_root/.helper/check_prerequisite_gaps_quality.sh"
  local implementation_plan_cmd_path="$asdlc_root/.commands/feature_implementation_plan.sh"
  local implementation_plan_semantic_review_cmd_path="$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  local assign_workers_cmd_path="$asdlc_root/.commands/feature_assing_workers.sh"
  local overmind_cli_path="$asdlc_root/.overmind/overmind.js"
  local common_lib_path="$asdlc_root/common_libs/project_setup_common.sh"
  local class_repo_paths_lib_path="$asdlc_root/common_libs/class_repo_paths.sh"
  local readiness_lib_path="$asdlc_root/common_libs/check_implementation_plan_readiness.sh"
  local sibling_lister_lib_path="$asdlc_root/common_libs/list_committed_sibling_features.sh"
  local attach_lib_path="$asdlc_root/common_libs/persist_class_repo_attach.sh"
  local sync_repo_lib_path="$asdlc_root/common_libs/sync_repo_to_default_branch.sh"
  local stale_rule_path="$asdlc_root/.rules/repo_br_scan_rule.md"
  local stale_br_to_ears_rule_path="$asdlc_root/.rules/br_to_ears.md"
  local stale_requirements_ears_helper_path="$asdlc_root/.helper/check_requirements_ears_quality.sh"
  local stale_requirements_ears_review_rule_path="$asdlc_root/.rules/requirements_ears_review_rule.md"
  local stale_requirements_ears_review_helper_path="$asdlc_root/.helper/check_requirements_ears_review_quality.sh"
  local stale_legacy_template_path="$asdlc_root/templates/init_progress_definition_TEMPLATE.yaml"
  local stale_golden_example_path="$asdlc_root/.golden_examples/step_state_GOLDEN_EXAMPLE.md"
  local stale_helper_path="$asdlc_root/.helper/obsolete_helper.sh"
  local stale_setup_models_path="$asdlc_root/.setup/models.md"
  local sentinel_project_dir="$asdlc_root/projects/preserved-project"
  local sentinel_project_file="$sentinel_project_dir/keep.txt"

  mkdir -p "$sentinel_project_dir"
  echo "keep" >"$sentinel_project_file"
  printf '\n# local customization marker\n' >>"$add_cmd_path"
  echo "stale rule" >"$stale_rule_path"
  echo "stale rule" >"$stale_br_to_ears_rule_path"
  echo "stale rule" >"$stale_requirements_ears_review_rule_path"
  echo "stale helper" >"$stale_requirements_ears_helper_path"
  echo "stale helper" >"$stale_requirements_ears_review_helper_path"
  echo "stale rule" >"$feature_contract_delta_rule_path"
  echo "stale helper" >"$feature_contract_delta_helper_path"
  echo "stale template" >"$feature_contract_delta_flat_template_path"
  echo "stale golden example" >"$feature_contract_delta_flat_golden_path"
  echo "stale rule" >"$repo_surface_context_rule_path"
  echo "stale rule" >"$stale_mcp_enrichment_rule_path"
  echo "stale template" >"$repo_surface_be_flat_template_path"
  echo "stale template" >"$repo_surface_fe_flat_template_path"
  echo "stale golden example" >"$repo_surface_be_flat_golden_path"
  echo "stale golden example" >"$repo_surface_fe_flat_golden_path"
  echo "stale helper" >"$repo_surface_be_helper_path"
  echo "stale helper" >"$repo_surface_fe_helper_path"
  echo "stale command" >"$feature_technical_requirements_cmd_path"
  echo "stale rule" >"$asdlc_root/.rules/technical_requirements_rule.md"
  echo "stale template" >"$asdlc_root/.templates/technical_requirements_TEMPLATE.md"
  echo "stale golden" >"$asdlc_root/.golden_examples/technical_requirements_GOLDEN_EXAMPLE.md"
  echo "stale helper" >"$asdlc_root/.helper/check_feature_technical_requirements_quality.sh"
  echo "stale command" >"$feature_implementation_slices_cmd_path"
  echo "stale rule" >"$implementation_slices_rule_path"
  echo "stale template" >"$implementation_slices_template_path"
  echo "stale golden" >"$implementation_slices_golden_path"
  echo "stale helper" >"$implementation_slices_helper_path"
  echo "stale command" >"$prerequisite_gaps_cmd_path"
  echo "stale rule" >"$prerequisite_gaps_rule_path"
  echo "stale template" >"$prerequisite_gaps_template_path"
  echo "stale golden" >"$prerequisite_gaps_golden_path"
  echo "stale helper" >"$prerequisite_gaps_helper_path"
  echo "stale command" >"$implementation_plan_cmd_path"
  echo "stale command" >"$implementation_plan_semantic_review_cmd_path"
  mkdir -p "$(dirname "$stale_legacy_template_path")"
  echo "stale legacy template" >"$stale_legacy_template_path"
  echo "stale visible template" >"$template_path"
  echo "stale golden example" >"$stale_golden_example_path"
  echo "stale helper" >"$stale_helper_path"
  chmod -x "$stale_helper_path"
  echo "stale setup" >"$stale_setup_models_path"

  local metadata_before=""
  local add_cmd_before=""
  local setup_models_before=""
  metadata_before="$(cat "$metadata_path")"
  add_cmd_before="$(cat "$add_cmd_path")"
  setup_models_before="$(cat "$stale_setup_models_path")"

  rm -f "$common_lib_path"
  rm -f "$overmind_cli_path"

  rm -f \
    "$update_cmd_path" \
    "$scanner_cmd_path" \
    "$stack_blueprints_cmd_path" \
    "$feature_orchestrator_cmd_path" \
    "$common_contract_cmd_path" \
    "$contract_reconciliation_cmd_path" \
    "$register_worker_cmd_path" \
    "$feature_br_cmd_path" \
    "$assign_workers_cmd_path"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "Update mode added file: $common_lib_path"
  assert_contains "$out" "Update mode added file: $update_cmd_path"
  assert_contains "$out" "Update mode added file: $scanner_cmd_path"
  assert_contains "$out" "Update mode added file: $stack_blueprints_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_orchestrator_cmd_path"
  assert_contains "$out" "Update mode added file: $common_contract_cmd_path"
  assert_contains "$out" "Update mode added file: $contract_reconciliation_cmd_path"
  assert_contains "$out" "Update mode added file: $register_worker_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_br_cmd_path"
  assert_contains "$out" "Update mode added file: $assign_workers_cmd_path"
  assert_contains "$out" "Update mode added file: $overmind_cli_path"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_staged_overmind_cli_matches_repo_source "$repo_dir" "$asdlc_root"
  assert_file_exists "$common_lib_path"
  assert_file_exists "$class_repo_paths_lib_path"
  assert_file_exists "$readiness_lib_path"
  assert_file_exists "$sibling_lister_lib_path"
  assert_file_exists "$attach_lib_path"
  assert_file_exists "$sync_repo_lib_path"
  assert_file_executable "$class_repo_paths_lib_path"
  assert_file_executable "$readiness_lib_path"
  assert_file_executable "$sibling_lister_lib_path"
  assert_file_executable "$attach_lib_path"
  assert_file_executable "$sync_repo_lib_path"
  assert_file_exists "$add_cmd_path"
  assert_file_exists "$update_cmd_path"
  assert_file_exists "$scanner_cmd_path"
  assert_file_exists "$stack_blueprints_cmd_path"
  assert_file_exists "$feature_orchestrator_cmd_path"
  assert_file_exists "$common_contract_cmd_path"
  assert_file_exists "$contract_reconciliation_cmd_path"
  assert_file_exists "$register_worker_cmd_path"
  assert_file_exists "$feature_br_cmd_path"
  assert_file_not_exists "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_not_exists "$feature_contract_delta_rule_path"
  assert_file_not_exists "$feature_contract_delta_helper_path"
  assert_file_not_exists "$feature_contract_delta_flat_template_path"
  assert_file_not_exists "$feature_contract_delta_flat_golden_path"
  assert_file_not_exists "$repo_surface_context_rule_path"
  assert_file_not_exists "$stale_mcp_enrichment_rule_path"
  assert_file_not_exists "$repo_surface_be_flat_template_path"
  assert_file_not_exists "$repo_surface_fe_flat_template_path"
  assert_file_not_exists "$repo_surface_be_flat_golden_path"
  assert_file_not_exists "$repo_surface_fe_flat_golden_path"
  assert_file_not_exists "$repo_surface_be_helper_path"
  assert_file_not_exists "$repo_surface_fe_helper_path"
  assert_file_not_exists "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_not_exists "$feature_technical_requirements_cmd_path"
  assert_file_not_exists "$asdlc_root/.rules/technical_requirements_rule.md"
  assert_file_not_exists "$asdlc_root/.templates/technical_requirements_TEMPLATE.md"
  assert_file_not_exists "$asdlc_root/.golden_examples/technical_requirements_GOLDEN_EXAMPLE.md"
  assert_file_not_exists "$asdlc_root/.helper/check_feature_technical_requirements_quality.sh"
  assert_file_not_exists "$feature_implementation_slices_cmd_path"
  assert_file_not_exists "$implementation_slices_rule_path"
  assert_file_not_exists "$implementation_slices_template_path"
  assert_file_not_exists "$implementation_slices_golden_path"
  assert_file_not_exists "$implementation_slices_helper_path"
  assert_file_not_exists "$prerequisite_gaps_cmd_path"
  assert_file_not_exists "$prerequisite_gaps_rule_path"
  assert_file_not_exists "$prerequisite_gaps_template_path"
  assert_file_not_exists "$prerequisite_gaps_golden_path"
  assert_file_not_exists "$prerequisite_gaps_helper_path"
  assert_file_not_exists "$implementation_plan_cmd_path"
  assert_file_not_exists "$implementation_plan_semantic_review_cmd_path"
  assert_file_exists "$assign_workers_cmd_path"
  assert_file_executable "$update_cmd_path"
  assert_file_executable "$scanner_cmd_path"
  assert_file_executable "$stack_blueprints_cmd_path"
  assert_file_executable "$feature_orchestrator_cmd_path"
  assert_file_executable "$common_contract_cmd_path"
  assert_file_executable "$contract_reconciliation_cmd_path"
  assert_file_executable "$register_worker_cmd_path"
  assert_file_executable "$feature_br_cmd_path"
  assert_file_executable "$assign_workers_cmd_path"
  assert_equal "$metadata_before" "$(cat "$metadata_path")"
  assert_equal "$add_cmd_before" "$(cat "$add_cmd_path")"
  assert_file_exists "$sentinel_project_file"
  assert_contains "$(cat "$update_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$scanner_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$register_worker_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$assign_workers_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$feature_br_cmd_path")" 'TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"'
  assert_file_not_exists "$stale_br_to_ears_rule_path"
  assert_file_not_exists "$stale_requirements_ears_helper_path"
  assert_file_not_exists "$stale_requirements_ears_review_rule_path"
  assert_file_not_exists "$stale_requirements_ears_review_helper_path"
  assert_feature_requirements_and_plan_commands_use_staged_runtime_assets "$asdlc_root"
  assert_file_not_exists "$stale_golden_example_path"
  assert_support_assets_except_setup_match_repo_sources "$repo_dir" "$asdlc_root"
  assert_equal "$setup_models_before" "$(cat "$stale_setup_models_path")"
  assert_file_content_equal \
    "$repo_dir/overmind/templates/init_progress_definition_TEMPLATE.yaml" \
    "$template_path"
}

test_first_init_machine_update_mode_refreshes_quickrun_guide() {
  local repo_dir="$TMP_ROOT/repo-first-init-update-mode-quickrun-refresh"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-update-mode-quickrun-refresh"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local quickrun_path="$asdlc_root/quickrun.md"
  cat >"$quickrun_path" <<'OUT'
# ASDLC Quick Run

legacy quickrun content
OUT

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"

  local quickrun=""
  quickrun="$(cat "$quickrun_path")"
  assert_not_contains "$quickrun" "legacy quickrun content"
  assert_contains "$quickrun" "## 3. Continue Toward Implementation"
  assert_contains "$quickrun" '`overmind-plan-semantic-review` skills are staged for supported runners'
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh"
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id>"
  assert_contains "$quickrun" 'During phase 4.1, the orchestrator starts a Codex repo-br-scan session (when a class repo is ready) followed by a task-to-BR session using the installed skills; when `user_br_input.md` is missing, Codex asks for a local story file or Jira ticket. During phase 4.2, the orchestrator starts the BR-clarification skill and then runs the deterministic readiness check. During phase 5, the orchestrator starts the requirements-EARS skill. During optional phase 5.1, the orchestrator starts the EARS-review skill. During phase 6, it syncs ready repositories and starts the contract-delta skill.'
  assert_contains "$quickrun" '.commands/project_add_feature_e2e.sh --resume 4.2'
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 8.2"
  assert_contains "$quickrun" 'If `--path` is omitted, the script auto-selects the only project under `projects/`'
  assert_contains "$quickrun" "discovers unfinished feature folders for the project first"
  assert_contains "$quickrun" "asks whether to start a new feature or continue one of the unfinished features"
  assert_contains "$quickrun" ".commands/project_register_worker.sh --path projects/<project-id>"
  assert_contains "$quickrun" "projects/<project-id>/workers.yaml"
  assert_contains "$quickrun" "node .overmind/overmind.js context requirements-ears projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate requirements-ears projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context ears-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate ears-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Optionally enrich unresolved surface-map placeholders from configured knowledge-base MCP sources (Step 7.1)"
  assert_contains "$quickrun" "node .overmind/overmind.js context surface-map-enrich projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context technical-requirements projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate technical-requirements projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context implementation-slices projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate implementation-slices projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context prerequisite-gaps projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate prerequisite-gaps projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context implementation-plan projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate implementation-plan projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js context plan-semantic-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "node .overmind/overmind.js gate plan-semantic-review projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" 'This command writes `#### Assigned:` for every plan step with a class-matched worker UUID or `ERROR: no active worker available for class <class>`.'
  assert_contains "$quickrun" "node .overmind/overmind.js gate surface-map projects/<project-id>/<feature-folder> --class <backend|frontend|mobile>"
  assert_contains "$quickrun" 'step_state_<feature-folder>.md'
}

test_first_init_machine_update_mode_preserves_existing_external_sources_yaml() {
  local repo_dir="$TMP_ROOT/repo-first-init-update-mode-preserve-external-sources"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-update-mode-preserve-external-sources"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local external_sources_path="$asdlc_root/.setup/external_sources.yaml"
  cat >"$external_sources_path" <<'OUT'
sources:
  - name: runtime-kb
    type: stack_knowledge_base
    description: Runtime-owned MCP source
OUT
  local external_sources_before=""
  external_sources_before="$(cat "$external_sources_path")"
  local models_path="$asdlc_root/.setup/models.md"
  cat >"$models_path" <<'OUT'
feature_contract_delta | codex | custom-model
OUT
  local models_before=""
  models_before="$(cat "$models_path")"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_equal "$external_sources_before" "$(cat "$external_sources_path")"
  assert_equal "$models_before" "$(cat "$models_path")"
}

test_first_init_machine_update_mode_recreates_commands_directory_when_missing() {
  local repo_dir="$TMP_ROOT/repo-first-init-update-mode-recreate-commands"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-update-mode-recreate-commands"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  rm -rf "$asdlc_root/.commands"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_setup_update_project.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/init_progress_scanner.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/init_common_contract_definition.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_contract_reconciliation.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_register_worker.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_br_scaffold.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_assing_workers.sh"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_dir_exists "$asdlc_root/.commands"
  assert_file_exists "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_exists "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_exists "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_exists "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_exists "$asdlc_root/.commands/project_contract_reconciliation.sh"
  assert_file_exists "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_exists "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_br_to_ears.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_contract_delta.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_not_exists "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_file_exists "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_executable "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_executable "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_executable "$asdlc_root/.commands/project_contract_reconciliation.sh"
  assert_file_executable "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_executable "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_executable "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_contains "$(cat "$asdlc_root/.commands/project_setup_add_new_project.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/project_setup_update_project.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/init_progress_scanner.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/init_common_contract_definition.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/project_register_worker.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/feature_assing_workers.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_scaffold.sh")" 'TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"'
  assert_feature_requirements_and_plan_commands_use_staged_runtime_assets "$asdlc_root"
}

test_first_init_machine_update_mode_recreates_support_asset_directories_when_missing() {
  local repo_dir="$TMP_ROOT/repo-first-init-update-mode-recreate-support-assets"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-update-mode-recreate-support-assets"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  rm -rf \
    "$asdlc_root/.rules" \
    "$asdlc_root/.templates" \
    "$asdlc_root/.golden_examples" \
    "$asdlc_root/.helper" \
    "$asdlc_root/.setup"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "Update mode added file: $asdlc_root/.templates/common_contract_definition_TEMPLATE.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.setup/models.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_support_assets_match_repo_sources "$repo_dir" "$asdlc_root"
  assert_file_exists "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_file_content_equal \
    "$repo_dir/overmind/templates/init_progress_definition_TEMPLATE.yaml" \
    "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
}

test_first_init_machine_update_mode_repairs_missing_runner_skill_folder() {
  local repo_dir="$TMP_ROOT/repo-first-init-update-mode-repair-runner-skill"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-update-mode-repair-runner-skill"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  assert_runner_skills_installed "$repo_dir" "$asdlc_root"

  local codex_skill_dir="$asdlc_root/.codex/skills/overmind-task-to-br"
  local overmind_cli_path="$asdlc_root/.overmind/overmind.js"

  # Remove one supported runner skill folder; keep the shared CLI in place.
  rm -rf "$codex_skill_dir"
  assert_file_exists "$overmind_cli_path"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "Update mode added file: $codex_skill_dir"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_runner_skills_installed "$repo_dir" "$asdlc_root"
  assert_staged_overmind_cli_matches_repo_source "$repo_dir" "$asdlc_root"
}

test_first_init_machine_fails_when_skill_source_missing() {
  local repo_dir="$TMP_ROOT/repo-first-init-missing-skill-source"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"
  rm -rf "$repo_dir/$SKILL_SOURCE_REL_PATH"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-missing-skill-source"
  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required packaged skill source not found: $SKILL_SOURCE_REL_PATH"
  if [[ -e "$bootstrap_parent/asdlc" ]]; then
    echo "Assertion failed: asdlc workspace should not be created when packaged skill source is missing" >&2
    exit 1
  fi
}

test_first_init_machine_fails_when_asdlc_exists_without_metadata() {
  local repo_dir="$TMP_ROOT/repo-first-init-existing-asdlc-missing-metadata"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-existing-missing-metadata"
  local asdlc_root="$bootstrap_parent/asdlc"
  mkdir -p "$asdlc_root"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "ASDLC folder exists but required metadata is missing: $asdlc_root/asdlc_metadata.yaml"
  if [[ -e "$asdlc_root/.commands" ]]; then
    echo "Assertion failed: .commands should not be created when metadata is missing" >&2
    exit 1
  fi
  if [[ -e "$asdlc_root/.rules" || -e "$asdlc_root/.templates" || -e "$asdlc_root/.golden_examples" || -e "$asdlc_root/.helper" || -e "$asdlc_root/.setup" ]]; then
    echo "Assertion failed: support-asset directories should not be created when metadata is missing" >&2
    exit 1
  fi
}

test_add_new_project_creates_record_workspace_and_class_repo_metadata_from_staged_command() {
  local repo_dir="$TMP_ROOT/repo-add-project-success"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-success"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"
  local backend_repo="$TMP_ROOT/backend-repo"
  mkdir -p "$backend_repo"
  echo "backend" >"$backend_repo/README.md"
  local caller_dir="$TMP_ROOT/caller-dir"
  mkdir -p "$caller_dir"

  local out=""
  out="$(
    cd "$caller_dir" &&
    printf 'Payments API\n1\n2\n5\n1\n%s\n2\n2\n' "$backend_repo" | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"

  local metadata_path="$asdlc_root/asdlc_metadata.yaml"
  local project_id=""
  local internal_folder=""
  local created_at=""
  local project_dir=""
  local definition_project_id=""
  local metadata_content=""
  local definition_content=""
  local project_block=""

  assert_contains "$out" "Created ASDLC project folder: $asdlc_root/projects/"
  assert_contains "$out" "Updated ASDLC metadata: $metadata_path"
  assert_contains "$out" "Already added classes: backend"
  assert_contains "$out" $'Select project class to add:\n2. frontend\n3. mobile\n4. infrastructure\n5. all done, nothing else to add'
  assert_contains "$out" "Already added classes: backend, frontend"
  assert_contains "$out" "Marked frontend repo path as deferred."
  assert_contains "$out" "Select project type (mandatory):"
  assert_equal "1" "$(count_project_records "$metadata_path")"

  project_id="$(extract_last_project_uuid "$metadata_path")"
  internal_folder="$(extract_last_internal_folder "$metadata_path")"
  created_at="$(extract_last_created_at "$metadata_path")"
  metadata_content="$(cat "$metadata_path")"
  project_block="$(extract_last_project_block "$metadata_path")"

  assert_matches "$project_id" '^payments_api-[0-9]{13}$'
  assert_equal "$project_id" "$internal_folder"
  assert_contains "$metadata_content" $'projects:\n  - project: '
  assert_matches "$created_at" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  assert_not_contains "$project_block" "project_classes:"
  assert_not_contains "$project_block" "class_repo_paths:"
  assert_not_contains "$out" "ADD-PROJECT HANDOFF"

  project_dir="$asdlc_root/projects/$internal_folder"
  assert_dir_exists "$project_dir"
  assert_git_repo_initialized "$project_dir"
  assert_file_exists "$project_dir/.git/config"
  assert_file_exists "$project_dir/init_progress_definition.yaml"
  definition_content="$(cat "$project_dir/init_progress_definition.yaml")"
  assert_contains "$definition_content" 'project_id: "'"$internal_folder"'"'
  assert_contains "$definition_content" $'  project_classes:\n    - backend\n    - frontend'
  assert_contains "$definition_content" 'project_type_code: "B"'
  assert_contains "$definition_content" 'project_type_label: "Existing project with partial context"'
  assert_not_contains "$definition_content" '  repo_paths:'
  assert_contains "$definition_content" '  class_repo_paths:'
  assert_contains "$definition_content" $'    backend:\n      state: "ready"\n      path: "'"$backend_repo"'"'
  assert_contains "$definition_content" $'    frontend:\n      state: "deferred"\n      path: ""'
  definition_project_id="$(extract_project_id_from_definition "$project_dir/init_progress_definition.yaml")"
  assert_equal "$internal_folder" "$definition_project_id"
  assert_git_head_subject "$project_dir" "Initialize ASDLC project workspace"
  assert_equal "init_progress_definition.yaml" "$(git -C "$project_dir" ls-files)"
}

test_add_new_project_does_not_require_git_repository() {
  local repo_dir="$TMP_ROOT/repo-add-project-no-git"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-no-git"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"
  local project_id=""
  local project_dir=""
  local out=""
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Branchless\n1\n5\n2\n2\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"

  assert_contains "$out" "Created ASDLC project folder: $asdlc_root/projects/"
  assert_equal "1" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
  project_id="$(extract_last_project_uuid "$asdlc_root/asdlc_metadata.yaml")"
  project_dir="$asdlc_root/projects/$project_id"
  assert_dir_exists "$project_dir"
  assert_git_repo_initialized "$project_dir"
  assert_git_head_subject "$project_dir" "Initialize ASDLC project workspace"
}

test_add_new_project_allows_dirty_worktree() {
  local repo_dir="$TMP_ROOT/repo-add-project-dirty-worktree"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-dirty-worktree"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"
  echo "# dirty" >>"$asdlc_root/asdlc_metadata.yaml"

  local out=""
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Dirty Workspace\n1\n5\n2\n2\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  assert_contains "$out" "Created ASDLC project folder: $asdlc_root/projects/"
  assert_equal "1" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
}

test_staged_scanner_reads_selected_feature_path() {
  local repo_dir="$TMP_ROOT/repo-staged-scanner-feature-path"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-staged-scanner-feature-path"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local add_out=""
  add_out="$(
    cd "$TMP_ROOT" &&
    printf 'Scanner Demo\n1\n5\n2\n2\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  assert_contains "$add_out" "Created ASDLC project folder: $asdlc_root/projects/"

  local project_id=""
  local project_dir=""
  local feature_dir=""
  local state_path=""
  project_id="$(extract_last_project_uuid "$asdlc_root/asdlc_metadata.yaml")"
  project_dir="$asdlc_root/projects/$project_id"
  feature_dir="$project_dir/feature-scan"
  mkdir -p "$feature_dir"
  state_path="$project_dir/step_state_feature-scan.md"

  cat >"$project_dir/init_progress_definition.yaml" <<'EOF'
meta_info:
  project_classes:
    - backend

steps:
  - step_number: 1
    phase_name: "init"
    step_name: "Project-level marker"
    finished_only_if_artefacts_present:
      - file: "ready_project.md"
  - step_number: 2
    phase_name: "feature"
    step_name: "Feature-level marker"
    finished_only_if_artefacts_present:
      - file: "ready_feature.md"
        special_folder: "/overmind/product"
EOF

  local first_scan=""
  first_scan="$(
    cd "$TMP_ROOT" &&
    "$asdlc_root/.commands/init_progress_scanner.sh" --path "$feature_dir"
  )"
  assert_contains "$first_scan" "---- PROJECT LEVEL TASKS ----"
  assert_contains "$first_scan" "- [ ] 1 Project-level marker"
  assert_contains "$first_scan" "- [ ] 2 Feature-level marker"
  assert_contains "$first_scan" "next step: 1 (Project-level marker)"
  assert_file_exists "$state_path"

  echo "ready" >"$project_dir/ready_project.md"
  echo "ready" >"$feature_dir/ready_feature.md"
  local second_scan=""
  second_scan="$(
    cd "$TMP_ROOT" &&
    "$asdlc_root/.commands/init_progress_scanner.sh" --path "$feature_dir"
  )"
  assert_contains "$second_scan" "---- PROJECT LEVEL TASKS ----"
  assert_contains "$second_scan" "- [x] 1 Project-level marker"
  assert_contains "$second_scan" "- [x] 2 Feature-level marker"
  assert_contains "$second_scan" "next step: none"
  assert_file_exists "$state_path"
}

test_add_new_project_retries_invalid_repo_path_until_valid() {
  local repo_dir="$TMP_ROOT/repo-add-project-path-retry"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-path-retry"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local missing_repo="$TMP_ROOT/missing-repo"
  local non_dir_path="$TMP_ROOT/non-dir-repo.txt"
  local empty_repo="$TMP_ROOT/empty-repo"
  local valid_repo="$TMP_ROOT/valid-mobile-repo"
  echo "not a dir" >"$non_dir_path"
  mkdir -p "$empty_repo" "$valid_repo"
  echo "mobile" >"$valid_repo/README.md"

  local out=""
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Search UX\n3\n5\n1\n%s\n%s\n%s\n%s\n2\n' "$missing_repo" "$non_dir_path" "$empty_repo" "$valid_repo" | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"

  local metadata_path="$asdlc_root/asdlc_metadata.yaml"
  local project_id=""
  local definition_path=""
  local definition_content=""

  assert_contains "$out" "Repo path does not exist: $missing_repo"
  assert_contains "$out" "Repo path is not a directory: $non_dir_path"
  assert_contains "$out" "Repo path must point to a non-empty directory: $empty_repo"
  project_id="$(extract_last_project_uuid "$metadata_path")"
  definition_path="$asdlc_root/projects/$project_id/init_progress_definition.yaml"
  definition_content="$(cat "$definition_path")"
  assert_contains "$definition_content" $'  project_classes:\n    - mobile'
  assert_not_contains "$definition_content" '  repo_paths:'
  assert_contains "$definition_content" $'    mobile:\n      state: "ready"\n      path: "'"$valid_repo"'"'
}

test_add_new_project_requires_at_least_one_project_class_before_done() {
  local repo_dir="$TMP_ROOT/repo-add-project-empty-classes"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-empty-classes"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local out=""
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Infra Setup\n5\n4\n5\n2\n2\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"

  local metadata_path="$asdlc_root/asdlc_metadata.yaml"
  local project_id=""
  local definition_path=""
  local definition_content=""

  assert_contains "$out" "Select at least one project class before finishing."
  project_id="$(extract_last_project_uuid "$metadata_path")"
  definition_path="$asdlc_root/projects/$project_id/init_progress_definition.yaml"
  definition_content="$(cat "$definition_path")"
  assert_contains "$definition_content" $'  project_classes:\n    - infrastructure'
  assert_not_contains "$definition_content" '  repo_paths:'
  assert_contains "$definition_content" $'    infrastructure:\n      state: "deferred"\n      path: ""'
}

test_add_new_project_class_menu_shrinks_until_only_done_option_remains() {
  local repo_dir="$TMP_ROOT/repo-add-project-menu-shrinks"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-menu-shrinks"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local out=""
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Core Project\n1\n2\n3\n4\n5\n2\n2\n2\n2\n2\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"

  local metadata_path="$asdlc_root/asdlc_metadata.yaml"
  local project_id=""
  local definition_path=""
  local definition_content=""

  assert_contains "$out" $'Select project class to add:\n5. all done, nothing else to add'

  project_id="$(extract_last_project_uuid "$metadata_path")"
  definition_path="$asdlc_root/projects/$project_id/init_progress_definition.yaml"
  definition_content="$(cat "$definition_path")"

  assert_contains "$definition_content" $'  project_classes:\n    - backend\n    - frontend\n    - mobile\n    - infrastructure'
  assert_not_contains "$definition_content" '  repo_paths:'
}

test_add_new_project_fails_when_local_template_missing_without_mutation() {
  local repo_dir="$TMP_ROOT/repo-add-project-missing-template"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-missing-template"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local metadata_path="$asdlc_root/asdlc_metadata.yaml"
  local template_path="$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  local records_before=""
  local records_after=""
  records_before="$(count_project_records "$metadata_path")"

  rm -f "$template_path"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Search UX\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Required file not found: $template_path"

  records_after="$(count_project_records "$metadata_path")"
  assert_equal "$records_before" "$records_after"

  local project_dir_count=""
  project_dir_count="$(find "$asdlc_root/projects" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  assert_equal "0" "$project_dir_count"
}

test_add_new_project_rejects_empty_feature_name() {
  local repo_dir="$TMP_ROOT/repo-add-project-empty-feature"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-empty-feature"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    printf '\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project name cannot be empty."
  assert_equal "0" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
}

test_add_new_project_rejects_feature_name_without_alnum() {
  local repo_dir="$TMP_ROOT/repo-add-project-invalid-feature"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-invalid-feature"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    printf '!!!\n' | "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Project name must contain at least one letter or digit."
  assert_equal "0" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
}

test_add_new_project_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-add-project-staged-required"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir" &&
    printf 'Billing\n' | overmind/scripts/project_mgmt/project_setup_add_new_project.sh 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_add_new_project_rejects_metadata_with_top_level_sections_after_projects() {
  local repo_dir="$TMP_ROOT/repo-add-project-invalid-metadata-shape"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-invalid-metadata-shape"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  cat >>"$asdlc_root/asdlc_metadata.yaml" <<'EOF'
notes:
  owner: "qa"
EOF

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Invalid ASDLC metadata: top-level key 'projects' must be the final section."
  assert_equal "0" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
}

test_staged_br_structuring_commands_require_staged_location() {
  local repo_dir="$TMP_ROOT/repo-staged-br-command-guard"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-staged-br-command-guard"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local copied_script="$TMP_ROOT/feature_br_scaffold-nonstaged.sh"
  cp "$asdlc_root/.commands/feature_br_scaffold.sh" "$copied_script"
  chmod +x "$copied_script"

  local status=0
  local out=""
  set +e
  out="$("$copied_script" --path "$TMP_ROOT/some-feature-path" 2>&1)"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path: <asdlc>/.commands/"
}

test_update_project_requires_staged_command_location() {
  local repo_dir="$TMP_ROOT/repo-update-project-staged-guard"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$repo_dir" &&
    overmind/scripts/project_mgmt/project_setup_update_project.sh 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Run this command from ASDLC staged path"
}

test_first_init_machine_bootstraps_asdlc_workspace_with_local_template
test_first_init_machine_fails_when_template_source_missing
test_first_init_machine_fails_when_overmind_cli_bundle_source_missing
test_first_init_machine_update_mode_repairs_missing_commands_without_overwriting_existing_files
test_first_init_machine_update_mode_refreshes_quickrun_guide
test_first_init_machine_update_mode_preserves_existing_external_sources_yaml
test_first_init_machine_update_mode_recreates_commands_directory_when_missing
test_first_init_machine_update_mode_recreates_support_asset_directories_when_missing
test_first_init_machine_update_mode_repairs_missing_runner_skill_folder
test_first_init_machine_fails_when_skill_source_missing
test_first_init_machine_fails_when_asdlc_exists_without_metadata
test_add_new_project_creates_record_workspace_and_class_repo_metadata_from_staged_command
test_add_new_project_does_not_require_git_repository
test_add_new_project_allows_dirty_worktree
test_staged_scanner_reads_selected_feature_path
test_add_new_project_retries_invalid_repo_path_until_valid
test_add_new_project_class_menu_shrinks_until_only_done_option_remains
test_add_new_project_requires_at_least_one_project_class_before_done
test_add_new_project_fails_when_local_template_missing_without_mutation
test_add_new_project_rejects_empty_feature_name
test_add_new_project_rejects_feature_name_without_alnum
test_add_new_project_requires_staged_command_location
test_add_new_project_rejects_metadata_with_top_level_sections_after_projects
test_staged_br_structuring_commands_require_staged_location
test_update_project_requires_staged_command_location

echo "All project_setup_asdlc helper tests passed."
