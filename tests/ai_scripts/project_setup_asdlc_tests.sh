#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPTION_1_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
OPTION_2_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
OPTION_3_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_setup_update_project.sh"
OPTION_4_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/init_progress_scanner.sh"
INIT_PROJECT_STACK_BLUEPRINTS_SRC="$SOURCE_ROOT/overmind/scripts/init_project_stack_blueprints.sh"
OPTION_5_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/init_common_contract_definition.sh"
REGISTER_WORKER_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_register_worker.sh"
OPTION_6_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_scaffold.sh"
PROJECT_ADD_FEATURE_E2E_SRC="$SOURCE_ROOT/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
OPTION_7_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_scan_repo_for_br.sh"
OPTION_8_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_task_to_br.sh"
OPTION_9_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_user_br_clarification.sh"
OPTION_10_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_check_ears_readiness.sh"
OPTION_11_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_br_to_ears.sh"
OPTION_12_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_requirements_ears_review.sh"
OPTION_13_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_contract_delta.sh"
OPTION_14_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_repo_surface_and_exec_context.sh"
FEATURE_SURFACE_MAP_MCP_PLACEHOLDER_ENRICHMENT_SRC="$SOURCE_ROOT/overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh"
OPTION_15_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_technical_requirements.sh"
FEATURE_IMPLEMENTATION_SLICES_SRC="$SOURCE_ROOT/overmind/scripts/feature_implementation_slices.sh"
FEATURE_PREREQUISITE_GAPS_SRC="$SOURCE_ROOT/overmind/scripts/feature_prerequisite_gaps.sh"
OPTION_16_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_implementation_plan.sh"
OPTION_17_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_implementation_plan_semantic_review.sh"
OPTION_18_HELPER_SRC="$SOURCE_ROOT/overmind/scripts/feature_assing_workers.sh"
TEMPLATE_SRC="$SOURCE_ROOT/overmind/templates/init_progress_definition_TEMPLATE.yaml"
RULES_DIR_SRC="$SOURCE_ROOT/overmind/rules"
TEMPLATES_DIR_SRC="$SOURCE_ROOT/overmind/templates"
GOLDEN_EXAMPLES_DIR_SRC="$SOURCE_ROOT/overmind/golden_examples"
HELPER_DIR_SRC="$SOURCE_ROOT/overmind/scripts/helper"
SETUP_DIR_SRC="$SOURCE_ROOT/overmind/setup"
STAGED_RULE_FILES=(
  "br_to_ears.md"
  "common_contract_definition_rule.md"
  "feature_contract_delta_rule.md"
  "implementation_slices_rule.md"
  "implementation_plan_rule.md"
  "implementation_plan_semantic_review_rule.md"
  "prerequisite_gaps_rule.md"
  "project_stack_blueprint_rule.md"
  "requirements_ears_review_rule.md"
  "repo_br_scan_rule.md"
  "feature_repo_surface_and_exec_context_rule.md"
  "feature_surface_map_mcp_placeholder_enrichment_rule.md"
  "task_to_br_rule.md"
  "technical_requirements_rule.md"
  "user_br_clarification_rule.md"
)
STAGED_TEMPLATE_FILES=(
  "common_contract_definition_TEMPLATE.md"
  "feature_br_summary_TEMPLATE.md"
  "feature_contract_delta_TEMPLATE.md"
  "implementation_slices_TEMPLATE.md"
  "implementation_plan_TEMPLATE.md"
  "implementation_plan_semantic_review_TEMPLATE.md"
  "init_progress_definition_TEMPLATE.yaml"
  "missing_br_data_TEMPLATE.md"
  "prerequisite_gaps_TEMPLATE.md"
  "project_stack_blueprint_be_TEMPLATE.md"
  "project_stack_blueprint_fe_TEMPLATE.md"
  "project_stack_blueprint_mobile_TEMPLATE.md"
  "project_surface_struct_resp_map_be_TEMPLATE.md"
  "project_surface_struct_resp_map_fe_TEMPLATE.md"
  "requirements_ears_review_TEMPLATE.md"
  "reqirements_ears_TEMPLATE.md"
  "technical_requirements_TEMPLATE.md"
)
STAGED_GOLDEN_EXAMPLE_FILES=(
  "common_contract_definition_GOLDEN_EXAMPLE.md"
  "feature_br_summary_GOLDEN_EXAMPLE.md"
  "feature_contract_delta_GOLDEN_EXAMPLE.md"
  "implementation_slices_GOLDEN_EXAMPLE.md"
  "implementation_plan_GOLDEN_EXAMPLE.md"
  "implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
  "missing_br_data_GOLDEN_EXAMPLE.md"
  "prerequisite_gaps_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_be_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_fe_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
  "project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  "project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  "requirements_ears_review_GOLDEN_EXAMPLE.md"
  "reqirements_ears_GOLDEN_EXAMPLE.md"
  "technical_requirements_GOLDEN_EXAMPLE.md"
)
STAGED_HELPER_FILES=(
  "check_business_context_filled_from_repo.sh"
  "check_common_contract_definition_quality.sh"
  "check_feature_contract_delta_quality.sh"
  "check_feature_technical_requirements_quality.sh"
  "check_implementation_slices_quality.sh"
  "check_implementation_plan_quality.sh"
  "check_implementation_plan_semantic_review_quality.sh"
  "check_prerequisite_gaps_quality.sh"
  "check_project_stack_blueprint_quality.sh"
  "check_feature_repo_surface_and_exec_context_be_quality.sh"
  "check_feature_repo_surface_and_exec_context_fe_quality.sh"
  "check_requirements_ears_review_quality.sh"
  "check_requirements_ears_quality.sh"
  "check_task_to_br_quality.sh"
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

assert_feature_requirements_and_plan_commands_use_staged_runtime_assets() {
  local asdlc_root="$1"
  local technical_requirements_cmd_path="$asdlc_root/.commands/feature_technical_requirements.sh"
  local mcp_placeholder_enrichment_cmd_path="$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  local implementation_slices_cmd_path="$asdlc_root/.commands/feature_implementation_slices.sh"
  local prerequisite_gaps_cmd_path="$asdlc_root/.commands/feature_prerequisite_gaps.sh"
  local implementation_plan_cmd_path="$asdlc_root/.commands/feature_implementation_plan.sh"
  local implementation_plan_semantic_review_cmd_path="$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  local assign_workers_cmd_path="$asdlc_root/.commands/feature_assing_workers.sh"

  assert_contains "$(cat "$technical_requirements_cmd_path")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$technical_requirements_cmd_path")" 'RULE_FILE=".rules/technical_requirements_rule.md"'
  assert_contains "$(cat "$technical_requirements_cmd_path")" 'TECHNICAL_REQUIREMENTS_TEMPLATE_FILE=".templates/technical_requirements_TEMPLATE.md"'
  assert_contains "$(cat "$technical_requirements_cmd_path")" 'TECHNICAL_REQUIREMENTS_GOLDEN_EXAMPLE_FILE=".golden_examples/technical_requirements_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$technical_requirements_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_feature_technical_requirements_quality.sh"'

  assert_contains "$(cat "$mcp_placeholder_enrichment_cmd_path")" 'EXTERNAL_SOURCES_FILE=".setup/external_sources.yaml"'
  assert_contains "$(cat "$mcp_placeholder_enrichment_cmd_path")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$mcp_placeholder_enrichment_cmd_path")" 'RULE_FILE=".rules/feature_surface_map_mcp_placeholder_enrichment_rule.md"'
  assert_contains "$(cat "$mcp_placeholder_enrichment_cmd_path")" 'BACKEND_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"'
  assert_contains "$(cat "$mcp_placeholder_enrichment_cmd_path")" 'FRONTEND_MOBILE_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"'

  assert_contains "$(cat "$implementation_slices_cmd_path")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$implementation_slices_cmd_path")" 'RULE_FILE=".rules/implementation_slices_rule.md"'
  assert_contains "$(cat "$implementation_slices_cmd_path")" 'IMPLEMENTATION_SLICES_TEMPLATE_FILE=".templates/implementation_slices_TEMPLATE.md"'
  assert_contains "$(cat "$implementation_slices_cmd_path")" 'IMPLEMENTATION_SLICES_GOLDEN_EXAMPLE_FILE=".golden_examples/implementation_slices_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$implementation_slices_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_implementation_slices_quality.sh"'

  assert_contains "$(cat "$prerequisite_gaps_cmd_path")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$prerequisite_gaps_cmd_path")" 'RULE_FILE=".rules/prerequisite_gaps_rule.md"'
  assert_contains "$(cat "$prerequisite_gaps_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_prerequisite_gaps_quality.sh"'

  assert_contains "$(cat "$implementation_plan_cmd_path")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$implementation_plan_cmd_path")" 'RULE_FILE=".rules/implementation_plan_rule.md"'
  assert_contains "$(cat "$implementation_plan_cmd_path")" 'IMPLEMENTATION_PLAN_TEMPLATE_FILE=".templates/implementation_plan_TEMPLATE.md"'
  assert_contains "$(cat "$implementation_plan_cmd_path")" 'IMPLEMENTATION_PLAN_GOLDEN_EXAMPLE_FILE=".golden_examples/implementation_plan_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$implementation_plan_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_implementation_plan_quality.sh"'

  assert_contains "$(cat "$implementation_plan_semantic_review_cmd_path")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$implementation_plan_semantic_review_cmd_path")" 'RULE_FILE=".rules/implementation_plan_semantic_review_rule.md"'
  assert_contains "$(cat "$implementation_plan_semantic_review_cmd_path")" 'REVIEW_TEMPLATE_FILE=".templates/implementation_plan_semantic_review_TEMPLATE.md"'
  assert_contains "$(cat "$implementation_plan_semantic_review_cmd_path")" 'REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$implementation_plan_semantic_review_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_implementation_plan_semantic_review_quality.sh"'

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
  mkdir -p "$repo_dir/overmind/scripts/project_mgmt" "$repo_dir/overmind/scripts"
  cp "$OPTION_1_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
  cp "$OPTION_2_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
  cp "$OPTION_3_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh"
  cp "$OPTION_4_HELPER_SRC" "$repo_dir/overmind/scripts/project_mgmt/init_progress_scanner.sh"
  cp "$INIT_PROJECT_STACK_BLUEPRINTS_SRC" "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh"
  cp "$PROJECT_ADD_FEATURE_E2E_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
  cp "$REGISTER_WORKER_SRC" "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh"
  cp "$OPTION_5_HELPER_SRC" "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  cp "$OPTION_6_HELPER_SRC" "$repo_dir/overmind/scripts/feature_br_scaffold.sh"
  cp "$OPTION_7_HELPER_SRC" "$repo_dir/overmind/scripts/feature_scan_repo_for_br.sh"
  cp "$OPTION_8_HELPER_SRC" "$repo_dir/overmind/scripts/feature_task_to_br.sh"
  cp "$OPTION_9_HELPER_SRC" "$repo_dir/overmind/scripts/feature_user_br_clarification.sh"
  cp "$OPTION_10_HELPER_SRC" "$repo_dir/overmind/scripts/feature_br_check_ears_readiness.sh"
  cp "$OPTION_11_HELPER_SRC" "$repo_dir/overmind/scripts/feature_br_to_ears.sh"
  cp "$OPTION_12_HELPER_SRC" "$repo_dir/overmind/scripts/feature_requirements_ears_review.sh"
  cp "$OPTION_13_HELPER_SRC" "$repo_dir/overmind/scripts/feature_contract_delta.sh"
  cp "$OPTION_14_HELPER_SRC" "$repo_dir/overmind/scripts/feature_repo_surface_and_exec_context.sh"
  cp "$FEATURE_SURFACE_MAP_MCP_PLACEHOLDER_ENRICHMENT_SRC" "$repo_dir/overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh"
  cp "$OPTION_15_HELPER_SRC" "$repo_dir/overmind/scripts/feature_technical_requirements.sh"
  cp "$FEATURE_IMPLEMENTATION_SLICES_SRC" "$repo_dir/overmind/scripts/feature_implementation_slices.sh"
  cp "$FEATURE_PREREQUISITE_GAPS_SRC" "$repo_dir/overmind/scripts/feature_prerequisite_gaps.sh"
  cp "$OPTION_16_HELPER_SRC" "$repo_dir/overmind/scripts/feature_implementation_plan.sh"
  cp "$OPTION_17_HELPER_SRC" "$repo_dir/overmind/scripts/feature_implementation_plan_semantic_review.sh"
  cp "$OPTION_18_HELPER_SRC" "$repo_dir/overmind/scripts/feature_assing_workers.sh"
  cp -R "$RULES_DIR_SRC" "$repo_dir/overmind/rules"
  cp -R "$TEMPLATES_DIR_SRC" "$repo_dir/overmind/templates"
  cp -R "$GOLDEN_EXAMPLES_DIR_SRC" "$repo_dir/overmind/golden_examples"
  cp -R "$HELPER_DIR_SRC" "$repo_dir/overmind/scripts/helper"
  cp -R "$SETUP_DIR_SRC" "$repo_dir/overmind/setup"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_setup_first_init_machine.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_setup_update_project.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/init_progress_scanner.sh"
  chmod +x "$repo_dir/overmind/scripts/init_project_stack_blueprints.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
  chmod +x "$repo_dir/overmind/scripts/project_mgmt/project_register_worker.sh"
  chmod +x "$repo_dir/overmind/scripts/init_common_contract_definition.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_br_scaffold.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_scan_repo_for_br.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_task_to_br.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_user_br_clarification.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_br_check_ears_readiness.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_br_to_ears.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_requirements_ears_review.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_contract_delta.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_repo_surface_and_exec_context.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_technical_requirements.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_implementation_slices.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_prerequisite_gaps.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_implementation_plan.sh"
  chmod +x "$repo_dir/overmind/scripts/feature_implementation_plan_semantic_review.sh"
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
  ensure_repo_has_local_main_branch "$asdlc_root"
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
  assert_dir_exists "$asdlc_root/.git"
  assert_file_exists "$asdlc_root/asdlc_metadata.yaml"
  assert_file_exists "$asdlc_root/quickrun.md"
  assert_file_exists "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_file_exists "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_exists "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_exists "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_exists "$asdlc_root/.commands/init_project_stack_blueprints.sh"
  assert_file_exists "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_exists "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_exists "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_exists "$asdlc_root/.commands/feature_scan_repo_for_br.sh"
  assert_file_exists "$asdlc_root/.commands/feature_task_to_br.sh"
  assert_file_exists "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_to_ears.sh"
  assert_file_exists "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_file_exists "$asdlc_root/.commands/feature_contract_delta.sh"
  assert_file_exists "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_exists "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_exists "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_exists "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_exists "$asdlc_root/.commands/feature_implementation_plan.sh"
  assert_file_exists "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_file_exists "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_executable "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_executable "$asdlc_root/.commands/init_project_stack_blueprints.sh"
  assert_file_executable "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_executable "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_executable "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_executable "$asdlc_root/.commands/feature_scan_repo_for_br.sh"
  assert_file_executable "$asdlc_root/.commands/feature_task_to_br.sh"
  assert_file_executable "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_to_ears.sh"
  assert_file_executable "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_file_executable "$asdlc_root/.commands/feature_contract_delta.sh"
  assert_file_executable "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_executable "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_executable "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_executable "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_executable "$asdlc_root/.commands/feature_implementation_plan.sh"
  assert_file_executable "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_file_executable "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_contains "$(cat "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh")" 'RULE_FILE=".rules/feature_surface_map_mcp_placeholder_enrichment_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh")" 'MODELS_FILE=".setup/models.md"'
  assert_contains "$(cat "$asdlc_root/.setup/models.md")" 'feature_surface_map_mcp_placeholder_enrichment'
  assert_file_content_equal \
    "$repo_dir/overmind/templates/init_progress_definition_TEMPLATE.yaml" \
    "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_equal "true" "$(git -C "$asdlc_root" rev-parse --is-inside-work-tree)"
  assert_equal "Initialize ASDLC workspace bootstrap" "$(git -C "$asdlc_root" log -1 --pretty=%s)"

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
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id>"
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 4.2"
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 8.2"
  assert_contains "$quickrun" '.project_add_feature_e2e_state.env'
  assert_contains "$quickrun" "discovers unfinished feature folders for the project first"
  assert_contains "$quickrun" "asks whether to start a new feature or continue one of the unfinished features"
  assert_contains "$quickrun" "as a convenience only; discovery plus scanner status remains the source of truth"
  assert_contains "$quickrun" ".commands/project_register_worker.sh --path projects/<project-id>"
  assert_contains "$quickrun" ".commands/init_project_stack_blueprints.sh --path projects/<project-id>"
  assert_contains "$quickrun" "projects/<project-id>/workers.yaml"
  assert_contains "$quickrun" ".commands/feature_br_scaffold.sh --path projects/<project-id>"
  assert_contains "$quickrun" ".commands/feature_scan_repo_for_br.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_task_to_br.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_user_br_clarification.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_br_check_ears_readiness.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_br_to_ears.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_requirements_ears_review.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_contract_delta.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_repo_surface_and_exec_context.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Optionally enrich unresolved surface-map placeholders from configured knowledge-base MCP sources (Step 7.1):"
  assert_contains "$quickrun" ".commands/feature_surface_map_mcp_placeholder_enrichment.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_technical_requirements.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_implementation_slices.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_implementation_plan.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Optionally run implementation-plan semantic review (Step 8.3):"
  assert_contains "$quickrun" ".commands/feature_implementation_plan_semantic_review.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" 'This command writes `#### Assigned:` for every plan step with a class-matched worker UUID or `ERROR: no active worker available for class <class>`.'
  assert_contains "$quickrun" ".commands/init_progress_scanner.sh --path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Careful: provide a feature path here, not a project path."
  assert_contains "$metadata" "meta:"
  assert_contains "$metadata" "projects:"
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_scaffold.sh")" 'TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_scan_repo_for_br.sh")" 'RULE_FILE=".rules/repo_br_scan_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_task_to_br.sh")" 'HELPER_SCRIPT=".helper/check_task_to_br_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_user_br_clarification.sh")" 'RULE_FILE=".rules/user_br_clarification_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_check_ears_readiness.sh")" 'REPO_HELPER=".helper/check_business_context_filled_from_repo.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_to_ears.sh")" 'QUALITY_GATE_HELPER=".helper/check_requirements_ears_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'RULE_FILE=".rules/requirements_ears_review_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'REVIEW_TEMPLATE_FILE=".templates/requirements_ears_review_TEMPLATE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'QUALITY_GATE_HELPER=".helper/check_requirements_ears_review_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'RULE_FILE=".rules/feature_contract_delta_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'FEATURE_CONTRACT_TEMPLATE_FILE=".templates/feature_contract_delta_TEMPLATE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE=".golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'QUALITY_GATE_HELPER=".helper/check_feature_contract_delta_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh")" 'RULE_FILE=".rules/feature_repo_surface_and_exec_context_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh")" 'BACKEND_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh")" 'FRONTEND_MOBILE_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"'
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
  local register_worker_cmd_path="$asdlc_root/.commands/project_register_worker.sh"
  local feature_br_cmd_path="$asdlc_root/.commands/feature_br_scaffold.sh"
  local scan_repo_cmd_path="$asdlc_root/.commands/feature_scan_repo_for_br.sh"
  local task_to_br_cmd_path="$asdlc_root/.commands/feature_task_to_br.sh"
  local user_br_clarification_cmd_path="$asdlc_root/.commands/feature_user_br_clarification.sh"
  local br_check_ears_readiness_cmd_path="$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  local br_to_ears_cmd_path="$asdlc_root/.commands/feature_br_to_ears.sh"
  local feature_requirements_ears_review_cmd_path="$asdlc_root/.commands/feature_requirements_ears_review.sh"
  local feature_contract_delta_cmd_path="$asdlc_root/.commands/feature_contract_delta.sh"
  local repo_surface_context_cmd_path="$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  local mcp_placeholder_enrichment_cmd_path="$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  local feature_technical_requirements_cmd_path="$asdlc_root/.commands/feature_technical_requirements.sh"
  local feature_implementation_slices_cmd_path="$asdlc_root/.commands/feature_implementation_slices.sh"
  local repository_implementation_plan_cmd_path="$asdlc_root/.commands/feature_implementation_plan.sh"
  local implementation_plan_semantic_review_cmd_path="$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  local assign_workers_cmd_path="$asdlc_root/.commands/feature_assing_workers.sh"
  local stale_rule_path="$asdlc_root/.rules/repo_br_scan_rule.md"
  local stale_legacy_template_path="$asdlc_root/templates/init_progress_definition_TEMPLATE.yaml"
  local stale_golden_example_path="$asdlc_root/.golden_examples/step_state_GOLDEN_EXAMPLE.md"
  local stale_helper_path="$asdlc_root/.helper/check_task_to_br_quality.sh"
  local stale_setup_models_path="$asdlc_root/.setup/models.md"
  local sentinel_project_dir="$asdlc_root/projects/preserved-project"
  local sentinel_project_file="$sentinel_project_dir/keep.txt"

  mkdir -p "$sentinel_project_dir"
  echo "keep" >"$sentinel_project_file"
  printf '\n# local customization marker\n' >>"$add_cmd_path"
  echo "stale rule" >"$stale_rule_path"
  mkdir -p "$(dirname "$stale_legacy_template_path")"
  echo "stale legacy template" >"$stale_legacy_template_path"
  echo "stale visible template" >"$template_path"
  echo "stale golden example" >"$stale_golden_example_path"
  echo "stale helper" >"$stale_helper_path"
  chmod -x "$stale_helper_path"
  echo "stale setup" >"$stale_setup_models_path"

  local metadata_before=""
  local add_cmd_before=""
  metadata_before="$(cat "$metadata_path")"
  add_cmd_before="$(cat "$add_cmd_path")"

  rm -f \
    "$update_cmd_path" \
    "$scanner_cmd_path" \
    "$stack_blueprints_cmd_path" \
    "$feature_orchestrator_cmd_path" \
    "$common_contract_cmd_path" \
    "$register_worker_cmd_path" \
    "$feature_br_cmd_path" \
    "$scan_repo_cmd_path" \
    "$task_to_br_cmd_path" \
    "$user_br_clarification_cmd_path" \
    "$br_check_ears_readiness_cmd_path" \
    "$br_to_ears_cmd_path" \
    "$feature_requirements_ears_review_cmd_path" \
    "$feature_contract_delta_cmd_path" \
    "$repo_surface_context_cmd_path" \
    "$mcp_placeholder_enrichment_cmd_path" \
    "$feature_technical_requirements_cmd_path" \
    "$feature_implementation_slices_cmd_path" \
    "$repository_implementation_plan_cmd_path" \
    "$implementation_plan_semantic_review_cmd_path" \
    "$assign_workers_cmd_path"

  local out=""
  out="$(
    cd "$repo_dir" &&
    printf '%s\n' "$bootstrap_parent" | overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
  )"

  assert_contains "$out" "asdlc folder already exists, switch to update mode"
  assert_contains "$out" "Update mode added file: $update_cmd_path"
  assert_contains "$out" "Update mode added file: $scanner_cmd_path"
  assert_contains "$out" "Update mode added file: $stack_blueprints_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_orchestrator_cmd_path"
  assert_contains "$out" "Update mode added file: $common_contract_cmd_path"
  assert_contains "$out" "Update mode added file: $register_worker_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_br_cmd_path"
  assert_contains "$out" "Update mode added file: $scan_repo_cmd_path"
  assert_contains "$out" "Update mode added file: $task_to_br_cmd_path"
  assert_contains "$out" "Update mode added file: $user_br_clarification_cmd_path"
  assert_contains "$out" "Update mode added file: $br_check_ears_readiness_cmd_path"
  assert_contains "$out" "Update mode added file: $br_to_ears_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_requirements_ears_review_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_contract_delta_cmd_path"
  assert_contains "$out" "Update mode added file: $repo_surface_context_cmd_path"
  assert_contains "$out" "Update mode added file: $mcp_placeholder_enrichment_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_technical_requirements_cmd_path"
  assert_contains "$out" "Update mode added file: $feature_implementation_slices_cmd_path"
  assert_contains "$out" "Update mode added file: $repository_implementation_plan_cmd_path"
  assert_contains "$out" "Update mode added file: $implementation_plan_semantic_review_cmd_path"
  assert_contains "$out" "Update mode added file: $assign_workers_cmd_path"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_file_exists "$add_cmd_path"
  assert_file_exists "$update_cmd_path"
  assert_file_exists "$scanner_cmd_path"
  assert_file_exists "$stack_blueprints_cmd_path"
  assert_file_exists "$feature_orchestrator_cmd_path"
  assert_file_exists "$common_contract_cmd_path"
  assert_file_exists "$register_worker_cmd_path"
  assert_file_exists "$feature_br_cmd_path"
  assert_file_exists "$scan_repo_cmd_path"
  assert_file_exists "$task_to_br_cmd_path"
  assert_file_exists "$user_br_clarification_cmd_path"
  assert_file_exists "$br_check_ears_readiness_cmd_path"
  assert_file_exists "$br_to_ears_cmd_path"
  assert_file_exists "$feature_requirements_ears_review_cmd_path"
  assert_file_exists "$feature_contract_delta_cmd_path"
  assert_file_exists "$repo_surface_context_cmd_path"
  assert_file_exists "$mcp_placeholder_enrichment_cmd_path"
  assert_file_exists "$feature_technical_requirements_cmd_path"
  assert_file_exists "$feature_implementation_slices_cmd_path"
  assert_file_exists "$repository_implementation_plan_cmd_path"
  assert_file_exists "$implementation_plan_semantic_review_cmd_path"
  assert_file_exists "$assign_workers_cmd_path"
  assert_file_executable "$update_cmd_path"
  assert_file_executable "$scanner_cmd_path"
  assert_file_executable "$stack_blueprints_cmd_path"
  assert_file_executable "$feature_orchestrator_cmd_path"
  assert_file_executable "$common_contract_cmd_path"
  assert_file_executable "$register_worker_cmd_path"
  assert_file_executable "$feature_br_cmd_path"
  assert_file_executable "$scan_repo_cmd_path"
  assert_file_executable "$task_to_br_cmd_path"
  assert_file_executable "$user_br_clarification_cmd_path"
  assert_file_executable "$br_check_ears_readiness_cmd_path"
  assert_file_executable "$br_to_ears_cmd_path"
  assert_file_executable "$feature_requirements_ears_review_cmd_path"
  assert_file_executable "$feature_contract_delta_cmd_path"
  assert_file_executable "$repo_surface_context_cmd_path"
  assert_file_executable "$mcp_placeholder_enrichment_cmd_path"
  assert_file_executable "$feature_technical_requirements_cmd_path"
  assert_file_executable "$feature_implementation_slices_cmd_path"
  assert_file_executable "$repository_implementation_plan_cmd_path"
  assert_file_executable "$implementation_plan_semantic_review_cmd_path"
  assert_file_executable "$assign_workers_cmd_path"
  assert_equal "$metadata_before" "$(cat "$metadata_path")"
  assert_equal "$add_cmd_before" "$(cat "$add_cmd_path")"
  assert_file_exists "$sentinel_project_file"
  assert_contains "$(cat "$update_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$scanner_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$register_worker_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$assign_workers_cmd_path")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$feature_br_cmd_path")" 'TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"'
  assert_contains "$(cat "$scan_repo_cmd_path")" 'RULE_FILE=".rules/repo_br_scan_rule.md"'
  assert_contains "$(cat "$task_to_br_cmd_path")" 'HELPER_SCRIPT=".helper/check_task_to_br_quality.sh"'
  assert_contains "$(cat "$user_br_clarification_cmd_path")" 'RULE_FILE=".rules/user_br_clarification_rule.md"'
  assert_contains "$(cat "$br_check_ears_readiness_cmd_path")" 'REPO_HELPER=".helper/check_business_context_filled_from_repo.sh"'
  assert_contains "$(cat "$br_to_ears_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_requirements_ears_quality.sh"'
  assert_contains "$(cat "$feature_requirements_ears_review_cmd_path")" 'RULE_FILE=".rules/requirements_ears_review_rule.md"'
  assert_contains "$(cat "$feature_requirements_ears_review_cmd_path")" 'REVIEW_TEMPLATE_FILE=".templates/requirements_ears_review_TEMPLATE.md"'
  assert_contains "$(cat "$feature_requirements_ears_review_cmd_path")" 'REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$feature_requirements_ears_review_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_requirements_ears_review_quality.sh"'
  assert_contains "$(cat "$feature_contract_delta_cmd_path")" 'RULE_FILE=".rules/feature_contract_delta_rule.md"'
  assert_contains "$(cat "$feature_contract_delta_cmd_path")" 'FEATURE_CONTRACT_TEMPLATE_FILE=".templates/feature_contract_delta_TEMPLATE.md"'
  assert_contains "$(cat "$feature_contract_delta_cmd_path")" 'FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE=".golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$feature_contract_delta_cmd_path")" 'QUALITY_GATE_HELPER=".helper/check_feature_contract_delta_quality.sh"'
  assert_contains "$(cat "$repo_surface_context_cmd_path")" 'RULE_FILE=".rules/feature_repo_surface_and_exec_context_rule.md"'
  assert_contains "$(cat "$repo_surface_context_cmd_path")" 'BACKEND_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"'
  assert_contains "$(cat "$repo_surface_context_cmd_path")" 'FRONTEND_MOBILE_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"'
  assert_feature_requirements_and_plan_commands_use_staged_runtime_assets "$asdlc_root"
  assert_file_not_exists "$stale_golden_example_path"
  assert_support_assets_match_repo_sources "$repo_dir" "$asdlc_root"
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
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id>"
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 4.2"
  assert_contains "$quickrun" ".commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 8.2"
  assert_contains "$quickrun" "discovers unfinished feature folders for the project first"
  assert_contains "$quickrun" "asks whether to start a new feature or continue one of the unfinished features"
  assert_contains "$quickrun" ".commands/project_register_worker.sh --path projects/<project-id>"
  assert_contains "$quickrun" "projects/<project-id>/workers.yaml"
  assert_contains "$quickrun" ".commands/feature_requirements_ears_review.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Optionally enrich unresolved surface-map placeholders from configured knowledge-base MCP sources (Step 7.1):"
  assert_contains "$quickrun" ".commands/feature_surface_map_mcp_placeholder_enrichment.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_technical_requirements.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_implementation_slices.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_implementation_plan.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" "Optionally run implementation-plan semantic review (Step 8.3):"
  assert_contains "$quickrun" ".commands/feature_implementation_plan_semantic_review.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" ".commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>"
  assert_contains "$quickrun" 'This command writes `#### Assigned:` for every plan step with a class-matched worker UUID or `ERROR: no active worker available for class <class>`.'
  assert_contains "$quickrun" ".commands/feature_repo_surface_and_exec_context.sh --feature_path projects/<project-id>/<feature-folder>"
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
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_register_worker.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_br_scaffold.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_scan_repo_for_br.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_task_to_br.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_br_to_ears.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_contract_delta.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_technical_requirements.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_implementation_slices.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_implementation_plan.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.commands/feature_assing_workers.sh"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_dir_exists "$asdlc_root/.commands"
  assert_file_exists "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_exists "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_exists "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_exists "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_exists "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_exists "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_exists "$asdlc_root/.commands/feature_scan_repo_for_br.sh"
  assert_file_exists "$asdlc_root/.commands/feature_task_to_br.sh"
  assert_file_exists "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_exists "$asdlc_root/.commands/feature_br_to_ears.sh"
  assert_file_exists "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_file_exists "$asdlc_root/.commands/feature_contract_delta.sh"
  assert_file_exists "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_exists "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_exists "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_exists "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_exists "$asdlc_root/.commands/feature_implementation_plan.sh"
  assert_file_exists "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_file_exists "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_add_new_project.sh"
  assert_file_executable "$asdlc_root/.commands/project_setup_update_project.sh"
  assert_file_executable "$asdlc_root/.commands/init_progress_scanner.sh"
  assert_file_executable "$asdlc_root/.commands/init_common_contract_definition.sh"
  assert_file_executable "$asdlc_root/.commands/project_register_worker.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_scaffold.sh"
  assert_file_executable "$asdlc_root/.commands/project_add_feature_e2e.sh"
  assert_file_executable "$asdlc_root/.commands/feature_scan_repo_for_br.sh"
  assert_file_executable "$asdlc_root/.commands/feature_task_to_br.sh"
  assert_file_executable "$asdlc_root/.commands/feature_user_br_clarification.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_check_ears_readiness.sh"
  assert_file_executable "$asdlc_root/.commands/feature_br_to_ears.sh"
  assert_file_executable "$asdlc_root/.commands/feature_requirements_ears_review.sh"
  assert_file_executable "$asdlc_root/.commands/feature_contract_delta.sh"
  assert_file_executable "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh"
  assert_file_executable "$asdlc_root/.commands/feature_surface_map_mcp_placeholder_enrichment.sh"
  assert_file_executable "$asdlc_root/.commands/feature_technical_requirements.sh"
  assert_file_executable "$asdlc_root/.commands/feature_implementation_slices.sh"
  assert_file_executable "$asdlc_root/.commands/feature_implementation_plan.sh"
  assert_file_executable "$asdlc_root/.commands/feature_implementation_plan_semantic_review.sh"
  assert_file_executable "$asdlc_root/.commands/feature_assing_workers.sh"
  assert_contains "$(cat "$asdlc_root/.commands/project_setup_add_new_project.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/project_setup_update_project.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/init_progress_scanner.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/init_common_contract_definition.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/project_register_worker.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/feature_assing_workers.sh")" "ASDLC_PROJECTS_DIR_DEFAULT=\"$asdlc_root/projects\""
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_scaffold.sh")" 'TEMPLATE_FILE=".templates/feature_br_summary_TEMPLATE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_scan_repo_for_br.sh")" 'RULE_FILE=".rules/repo_br_scan_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_task_to_br.sh")" 'HELPER_SCRIPT=".helper/check_task_to_br_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_user_br_clarification.sh")" 'RULE_FILE=".rules/user_br_clarification_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_check_ears_readiness.sh")" 'REPO_HELPER=".helper/check_business_context_filled_from_repo.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_br_to_ears.sh")" 'QUALITY_GATE_HELPER=".helper/check_requirements_ears_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'RULE_FILE=".rules/requirements_ears_review_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'REVIEW_TEMPLATE_FILE=".templates/requirements_ears_review_TEMPLATE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'REVIEW_GOLDEN_EXAMPLE_FILE=".golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_requirements_ears_review.sh")" 'QUALITY_GATE_HELPER=".helper/check_requirements_ears_review_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'RULE_FILE=".rules/feature_contract_delta_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'FEATURE_CONTRACT_TEMPLATE_FILE=".templates/feature_contract_delta_TEMPLATE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'FEATURE_CONTRACT_GOLDEN_EXAMPLE_FILE=".golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_contract_delta.sh")" 'QUALITY_GATE_HELPER=".helper/check_feature_contract_delta_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh")" 'RULE_FILE=".rules/feature_repo_surface_and_exec_context_rule.md"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh")" 'BACKEND_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_be_quality.sh"'
  assert_contains "$(cat "$asdlc_root/.commands/feature_repo_surface_and_exec_context.sh")" 'FRONTEND_MOBILE_QUALITY_GATE_HELPER=".helper/check_feature_repo_surface_and_exec_context_fe_quality.sh"'
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
  assert_contains "$out" "Update mode added file: $asdlc_root/.rules/br_to_ears.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.templates/common_contract_definition_TEMPLATE.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.helper/check_task_to_br_quality.sh"
  assert_contains "$out" "Update mode added file: $asdlc_root/.setup/models.md"
  assert_contains "$out" "Update mode added file: $asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_contains "$out" "ASDLC workspace update completed: $asdlc_root"
  assert_support_assets_match_repo_sources "$repo_dir" "$asdlc_root"
  assert_file_exists "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
  assert_file_content_equal \
    "$repo_dir/overmind/templates/init_progress_definition_TEMPLATE.yaml" \
    "$asdlc_root/.templates/init_progress_definition_TEMPLATE.yaml"
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
  local main_head_before=""
  local backend_repo="$TMP_ROOT/backend-repo"
  mkdir -p "$backend_repo"
  echo "backend" >"$backend_repo/README.md"
  echo "scratch only content" >"$asdlc_root/scratch-only.txt"
  (
    cd "$asdlc_root"
    git checkout -q -b "scratch-pre-add" main
    git add scratch-only.txt
    git commit -qm "scratch branch only commit"
  )
  main_head_before="$(git -C "$asdlc_root" rev-parse main)"

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
  local add_branch_name=""
  local committed_paths=""
  local head_tree_paths=""

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
  add_branch_name="add-project/$internal_folder"

  assert_matches "$project_id" '^payments_api-[0-9]{13}$'
  assert_equal "$project_id" "$internal_folder"
  assert_contains "$metadata_content" $'projects:\n  - project: '
  assert_matches "$created_at" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  assert_not_contains "$project_block" "project_classes:"
  assert_not_contains "$project_block" "class_repo_paths:"
  assert_contains "$out" "ADD-PROJECT HANDOFF"
  assert_contains "$out" "you're in branch $add_branch_name now, dont forget to commit changes to main branch with"
  assert_contains "$out" ">>> git checkout main && git merge $add_branch_name"
  assert_git_branch_exists "$asdlc_root" "$add_branch_name"
  assert_equal "$add_branch_name" "$(git -C "$asdlc_root" rev-parse --abbrev-ref HEAD)"
  assert_equal "$main_head_before" "$(git -C "$asdlc_root" rev-parse main)"
  assert_equal "$main_head_before" "$(git -C "$asdlc_root" rev-parse HEAD^)"
  assert_equal "Add ASDLC project $internal_folder" "$(git -C "$asdlc_root" log -1 --pretty=%s)"
  committed_paths="$(git -C "$asdlc_root" show --pretty='' --name-only HEAD)"
  assert_contains "$committed_paths" "asdlc_metadata.yaml"
  assert_contains "$committed_paths" "projects/$internal_folder/init_progress_definition.yaml"
  assert_equal "2" "$(printf '%s\n' "$committed_paths" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
  head_tree_paths="$(git -C "$asdlc_root" ls-tree -r --name-only HEAD)"
  assert_not_contains "$head_tree_paths" "scratch-only.txt"

  project_dir="$asdlc_root/projects/$internal_folder"
  assert_dir_exists "$project_dir"
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
}

test_add_new_project_fails_when_main_branch_missing() {
  local repo_dir="$TMP_ROOT/repo-add-project-main-missing"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-main-missing"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  git -C "$asdlc_root" branch -m main trunk
  git -C "$asdlc_root" checkout -q trunk

  local shim_dir="$TMP_ROOT/date-shim-main-missing"
  create_fixed_date_shim "$shim_dir" "1700000000000" "2026-01-02T03:04:05Z"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Branchless\n1\n5\n2\n2\n' | PATH="$shim_dir:$PATH" "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Git prerequisite failed: local branch 'main' is required in ASDLC repo:"
  assert_equal "0" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
  assert_equal "trunk" "$(git -C "$asdlc_root" rev-parse --abbrev-ref HEAD)"
  assert_equal "0" "$(git -C "$asdlc_root" branch --list 'add-project/*' | wc -l | tr -d ' ')"
}

test_add_new_project_fails_when_worktree_is_dirty() {
  local repo_dir="$TMP_ROOT/repo-add-project-dirty-worktree"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-dirty-worktree"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"
  echo "# dirty" >>"$asdlc_root/asdlc_metadata.yaml"

  local shim_dir="$TMP_ROOT/date-shim-dirty-worktree"
  create_fixed_date_shim "$shim_dir" "1700000001000" "2026-01-02T03:04:06Z"

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Dirty Workspace\n1\n5\n2\n2\n' | PATH="$shim_dir:$PATH" "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Git prerequisite failed: ASDLC git worktree/index must be clean before add-project."
  assert_equal "0" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
  assert_equal "main" "$(git -C "$asdlc_root" rev-parse --abbrev-ref HEAD)"
  assert_equal "0" "$(git -C "$asdlc_root" branch --list 'add-project/*' | wc -l | tr -d ' ')"
}

test_add_new_project_fails_when_branch_name_already_exists() {
  local repo_dir="$TMP_ROOT/repo-add-project-branch-collision"
  mkdir -p "$repo_dir"
  setup_git_repo_with_identity "$repo_dir"

  local bootstrap_parent="$TMP_ROOT/asdlc-home-add-branch-collision"
  local asdlc_root=""
  asdlc_root="$(bootstrap_asdlc_workspace "$repo_dir" "$bootstrap_parent")"

  local fixed_epoch_ms="1700000002000"
  local fixed_created_at="2026-01-02T03:04:07Z"
  local shim_dir="$TMP_ROOT/date-shim-branch-collision"
  local expected_project_id="collision_project-$fixed_epoch_ms"
  local expected_branch_name="add-project/$expected_project_id"
  local existing_branch_head_before=""
  create_fixed_date_shim "$shim_dir" "$fixed_epoch_ms" "$fixed_created_at"

  git -C "$asdlc_root" checkout -q -b "$expected_branch_name" main
  existing_branch_head_before="$(git -C "$asdlc_root" rev-parse "$expected_branch_name")"
  git -C "$asdlc_root" checkout -q main

  local status=0
  local out=""
  set +e
  out="$(
    cd "$TMP_ROOT" &&
    printf 'Collision Project\n1\n5\n2\n2\n' | PATH="$shim_dir:$PATH" "$asdlc_root/.commands/project_setup_add_new_project.sh" 2>&1
  )"
  status=$?
  set -e

  assert_nonzero_status "$status"
  assert_contains "$out" "Git prerequisite failed: branch already exists: $expected_branch_name"
  assert_equal "0" "$(count_project_records "$asdlc_root/asdlc_metadata.yaml")"
  assert_equal "main" "$(git -C "$asdlc_root" rev-parse --abbrev-ref HEAD)"
  assert_git_branch_exists "$asdlc_root" "$expected_branch_name"
  assert_equal "$existing_branch_head_before" "$(git -C "$asdlc_root" rev-parse "$expected_branch_name")"
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
  state_path="$project_dir/step_state.md"

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

test_update_project_script_remains_placeholder() {
  local repo_dir="$TMP_ROOT/repo-update-project-placeholder"
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
  assert_contains "$out" "Option 3 (update project) is not implemented yet."
}

test_first_init_machine_bootstraps_asdlc_workspace_with_local_template
test_first_init_machine_fails_when_template_source_missing
test_first_init_machine_update_mode_repairs_missing_commands_without_overwriting_existing_files
test_first_init_machine_update_mode_refreshes_quickrun_guide
test_first_init_machine_update_mode_recreates_commands_directory_when_missing
test_first_init_machine_update_mode_recreates_support_asset_directories_when_missing
test_first_init_machine_fails_when_asdlc_exists_without_metadata
test_add_new_project_creates_record_workspace_and_class_repo_metadata_from_staged_command
test_add_new_project_fails_when_main_branch_missing
test_add_new_project_fails_when_worktree_is_dirty
test_add_new_project_fails_when_branch_name_already_exists
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
test_update_project_script_remains_placeholder

echo "All project_setup_asdlc helper tests passed."
