#!/usr/bin/env bash
set -euo pipefail

ADD_NEW_PROJECT_SCRIPT="overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
UPDATE_PROJECT_SCRIPT="overmind/scripts/project_mgmt/project_setup_update_project.sh"
INIT_PROGRESS_SCANNER_SCRIPT="overmind/scripts/project_mgmt/init_progress_scanner.sh"
INIT_PROJECT_STACK_BLUEPRINTS_SCRIPT="overmind/scripts/init_project_stack_blueprints.sh"
INIT_COMMON_CONTRACT_DEFINITION_SCRIPT="overmind/scripts/init_common_contract_definition.sh"
FEATURE_BR_SCAFFOLD_SCRIPT="overmind/scripts/feature_br_scaffold.sh"
PROJECT_ADD_FEATURE_E2E_SCRIPT="overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
REGISTER_WORKER_SCRIPT="overmind/scripts/project_mgmt/project_register_worker.sh"
INIT_SCAN_REPO_FOR_BR_SCRIPT="overmind/scripts/feature_scan_repo_for_br.sh"
INIT_TASK_TO_BR_SCRIPT="overmind/scripts/feature_task_to_br.sh"
INIT_USER_BR_CLARIFICATION_SCRIPT="overmind/scripts/feature_user_br_clarification.sh"
INIT_BR_CHECK_EARS_READINESS_SCRIPT="overmind/scripts/feature_br_check_ears_readiness.sh"
INIT_BR_TO_EARS_SCRIPT="overmind/scripts/feature_br_to_ears.sh"
FEATURE_REQUIREMENTS_EARS_REVIEW_SCRIPT="overmind/scripts/feature_requirements_ears_review.sh"
INIT_FEATURE_CONTRACT_DELTA_SCRIPT="overmind/scripts/feature_contract_delta.sh"
INIT_REPO_SURFACE_EXECUTION_CONTEXT_SCRIPT="overmind/scripts/feature_repo_surface_and_exec_context.sh"
FEATURE_SURFACE_MAP_MCP_PLACEHOLDER_ENRICHMENT_SCRIPT="overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh"
FEATURE_TECHNICAL_REQUIREMENTS_SCRIPT="overmind/scripts/feature_technical_requirements.sh"
FEATURE_IMPLEMENTATION_SLICES_SCRIPT="overmind/scripts/feature_implementation_slices.sh"
FEATURE_PREREQUISITE_GAPS_SCRIPT="overmind/scripts/feature_prerequisite_gaps.sh"
FEATURE_IMPLEMENTATION_PLAN_SCRIPT="overmind/scripts/feature_implementation_plan.sh"
FEATURE_IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_SCRIPT="overmind/scripts/feature_implementation_plan_semantic_review.sh"
FEATURE_ASSIGN_WORKERS_SCRIPT="overmind/scripts/feature_assing_workers.sh"
TEMPLATE_SOURCE_FILE="overmind/templates/init_progress_definition_TEMPLATE.yaml"
RULES_SOURCE_DIR="overmind/rules"
TEMPLATES_SOURCE_DIR="overmind/templates"
GOLDEN_EXAMPLES_SOURCE_DIR="overmind/golden_examples"
HELPER_SCRIPTS_SOURCE_DIR="overmind/scripts/helper"
SETUP_SOURCE_DIR="overmind/setup"
LOCAL_TEMPLATE_DIR_NAME=".templates"
LOCAL_STAGED_RULES_DIR_NAME=".rules"
LOCAL_STAGED_TEMPLATES_DIR_NAME=".templates"
LOCAL_STAGED_GOLDEN_EXAMPLES_DIR_NAME=".golden_examples"
LOCAL_STAGED_HELPER_DIR_NAME=".helper"
LOCAL_STAGED_SETUP_DIR_NAME=".setup"
LOCAL_TEMPLATE_FILE_NAME="init_progress_definition_TEMPLATE.yaml"
METADATA_FILE_NAME="asdlc_metadata.yaml"
QUICKRUN_FILE_NAME="quickrun.md"
WORKSPACE_MODE="bootstrap"
OBSOLETE_STAGED_COMMAND_FILES=(
  "init_repo_surface_and_execution_context.sh"
  "init_repo_surface_and_execution_context_be.sh"
  "init_repo_surface_and_execution_context_fe.sh"
  "feature_repo_surface_and_exec_context_be.sh"
  "feature_repo_surface_and_exec_context_fe.sh"
)
STAGED_RULE_FILES=(
  "br_to_ears.md"
  "common_contract_definition_rule.md"
  "feature_contract_delta_rule.md"
  "implementation_slices_rule.md"
  "implementation_plan_rule.md"
  "implementation_plan_semantic_review_rule.md"
  "project_stack_blueprint_rule.md"
  "requirements_ears_review_rule.md"
  "repo_br_scan_rule.md"
  "feature_repo_surface_and_exec_context_rule.md"
  "feature_surface_map_mcp_placeholder_enrichment_rule.md"
  "task_to_br_rule.md"
  "technical_requirements_rule.md"
  "user_br_clarification_rule.md"
  "prerequisite_gaps_rule.md"
)
STAGED_TEMPLATE_FILES=(
  "common_contract_definition_TEMPLATE.md"
  "feature_br_summary_TEMPLATE.md"
  "feature_contract_delta_TEMPLATE.md"
  "implementation_slices_TEMPLATE.md"
  "implementation_plan_TEMPLATE.md"
  "implementation_plan_semantic_review_TEMPLATE.md"
  "missing_br_data_TEMPLATE.md"
  "project_stack_blueprint_be_TEMPLATE.md"
  "project_stack_blueprint_fe_TEMPLATE.md"
  "project_stack_blueprint_mobile_TEMPLATE.md"
  "project_surface_struct_resp_map_be_TEMPLATE.md"
  "project_surface_struct_resp_map_fe_TEMPLATE.md"
  "requirements_ears_review_TEMPLATE.md"
  "reqirements_ears_TEMPLATE.md"
  "technical_requirements_TEMPLATE.md"
  "prerequisite_gaps_TEMPLATE.md"
)
STAGED_GOLDEN_EXAMPLE_FILES=(
  "common_contract_definition_GOLDEN_EXAMPLE.md"
  "feature_br_summary_GOLDEN_EXAMPLE.md"
  "feature_contract_delta_GOLDEN_EXAMPLE.md"
  "implementation_slices_GOLDEN_EXAMPLE.md"
  "implementation_plan_GOLDEN_EXAMPLE.md"
  "implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
  "missing_br_data_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_be_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_fe_GOLDEN_EXAMPLE.md"
  "project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
  "project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md"
  "project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  "requirements_ears_review_GOLDEN_EXAMPLE.md"
  "reqirements_ears_GOLDEN_EXAMPLE.md"
  "technical_requirements_GOLDEN_EXAMPLE.md"
  "prerequisite_gaps_GOLDEN_EXAMPLE.md"
)
STAGED_HELPER_FILES=(
  "check_business_context_filled_from_repo.sh"
  "check_common_contract_definition_quality.sh"
  "check_feature_contract_delta_quality.sh"
  "check_feature_technical_requirements_quality.sh"
  "check_implementation_slices_quality.sh"
  "check_prerequisite_gaps_quality.sh"
  "check_implementation_plan_quality.sh"
  "check_implementation_plan_semantic_review_quality.sh"
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

die() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARNING: $*" >&2
}

log_update_mode_added_file() {
  local target_path="$1"
  echo "Update mode added file: $target_path"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "Required command not found: $command_name"
  fi
}

array_contains() {
  local needle="$1"
  shift
  local value=""

  for value in "$@"; do
    if [[ "$value" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_repo_root() {
  local script_dir=""
  local root=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    die "Failed to resolve script directory."
  fi

  if ! root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    die "Not a git repository at script path: $script_dir"
  fi
  printf '%s' "$root"
}

prompt_parent_directory() {
  local selected_path=""
  echo "Enter ASDLC parent directory path (asdlc/ will be created inside):" >&2
  read -r selected_path
  printf '%s' "$selected_path"
}

normalize_and_validate_parent_path() {
  local input_path="$1"
  local resolved_path=""
  local probe_file=""

  if [[ -z "${input_path//[[:space:]]/}" ]]; then
    die "ASDLC parent directory path cannot be empty."
  fi

  case "$input_path" in
  "~")
    input_path="$HOME"
    ;;
  "~/"*)
    input_path="$HOME/${input_path#~/}"
    ;;
  esac

  if [[ -e "$input_path" && ! -d "$input_path" ]]; then
    die "ASDLC parent path exists and is not a directory: $input_path"
  fi

  if ! mkdir -p "$input_path"; then
    die "Failed to create or access ASDLC parent directory: $input_path"
  fi

  if ! resolved_path="$(cd "$input_path" && pwd)"; then
    die "Failed to resolve ASDLC parent directory: $input_path"
  fi

  probe_file="$resolved_path/.asdlc_write_test.$$"
  if ! : >"$probe_file" 2>/dev/null; then
    die "ASDLC parent directory is not writable: $resolved_path"
  fi
  rm -f "$probe_file"

  printf '%s' "$resolved_path"
}

resolve_workspace_mode() {
  local asdlc_root="$1"
  local metadata_path="$asdlc_root/$METADATA_FILE_NAME"

  WORKSPACE_MODE="bootstrap"

  if [[ ! -e "$asdlc_root" ]]; then
    return 0
  fi

  if [[ ! -d "$asdlc_root" ]]; then
    die "ASDLC root path exists and is not a directory: $asdlc_root"
  fi

  if [[ -f "$metadata_path" ]]; then
    echo "asdlc folder already exists, switch to update mode"
    WORKSPACE_MODE="update"
    return 0
  fi

  die "ASDLC folder exists but required metadata is missing: $metadata_path"
}

create_bootstrap_directories() {
  local asdlc_root="$1"
  if ! mkdir -p "$asdlc_root/projects" "$asdlc_root/.commands" "$asdlc_root/$LOCAL_TEMPLATE_DIR_NAME"; then
    die "Failed to create ASDLC workspace directories under: $asdlc_root"
  fi
}

write_metadata_scaffold() {
  local asdlc_root="$1"
  local metadata_path="$asdlc_root/$METADATA_FILE_NAME"

  cat >"$metadata_path" <<'EOF'
meta:
  description: "this repo is for asdlc projects management"
projects:
EOF
}

ensure_template_source_exists() {
  local repo_root="$1"
  [[ -f "$repo_root/$TEMPLATE_SOURCE_FILE" ]] || die "Required file not found: $TEMPLATE_SOURCE_FILE"
}

ensure_source_directory_exists() {
  local repo_root="$1"
  local source_rel_dir="$2"

  [[ -d "$repo_root/$source_rel_dir" ]] || die "Required directory not found: $source_rel_dir"
}

ensure_support_asset_sources_exist() {
  local repo_root="$1"

  ensure_template_source_exists "$repo_root"
  ensure_source_directory_exists "$repo_root" "$RULES_SOURCE_DIR"
  ensure_source_directory_exists "$repo_root" "$TEMPLATES_SOURCE_DIR"
  ensure_source_directory_exists "$repo_root" "$GOLDEN_EXAMPLES_SOURCE_DIR"
  ensure_source_directory_exists "$repo_root" "$HELPER_SCRIPTS_SOURCE_DIR"
  ensure_source_directory_exists "$repo_root" "$SETUP_SOURCE_DIR"
}

stage_template_file() {
  local repo_root="$1"
  local asdlc_root="$2"
  local announce_added="$3"
  local source_path="$repo_root/$TEMPLATE_SOURCE_FILE"
  local target_path="$asdlc_root/$LOCAL_TEMPLATE_DIR_NAME/$LOCAL_TEMPLATE_FILE_NAME"
  local existed_before="no"

  if [[ -f "$target_path" ]]; then
    existed_before="yes"
  fi

  if ! mkdir -p "$asdlc_root/$LOCAL_TEMPLATE_DIR_NAME"; then
    die "Failed to create ASDLC template directory under: $asdlc_root"
  fi

  if ! cp "$source_path" "$target_path"; then
    die "Failed to stage ASDLC template file to: $target_path"
  fi

  if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
    log_update_mode_added_file "$target_path"
  fi
}

stage_support_asset_files() {
  local repo_root="$1"
  local source_rel_dir="$2"
  local asdlc_root="$3"
  local target_dir_name="$4"
  local overwrite_existing="$5"
  local set_executable="$6"
  local announce_added="$7"
  shift 7
  local source_dir="$repo_root/$source_rel_dir"
  local target_dir="$asdlc_root/$target_dir_name"
  local source_file_name=""
  local source_path=""
  local target_path=""
  local existing_path=""
  local existing_name=""
  local existed_before="no"
  local configured_count="$#"

  if [[ "$configured_count" -eq 0 ]]; then
    die "No staged support asset files configured for: $source_rel_dir"
  fi

  if ! mkdir -p "$target_dir"; then
    die "Failed to create ASDLC support assets directory under: $target_dir"
  fi

  for source_file_name in "$@"; do
    source_path="$source_dir/$source_file_name"
    [[ -f "$source_path" ]] || die "Required support asset not found: $source_rel_dir/$source_file_name"

    target_path="$target_dir/$source_file_name"
    existed_before="no"
    if [[ -f "$target_path" ]]; then
      existed_before="yes"
    fi

    if [[ "$overwrite_existing" != "yes" && -f "$target_path" ]]; then
      continue
    fi

    if ! cp "$source_path" "$target_path"; then
      die "Failed to stage support asset file: $source_rel_dir/$(basename "$source_path")"
    fi

    if [[ "$set_executable" == "yes" ]]; then
      if ! chmod +x "$target_path"; then
        die "Failed to set executable permission on staged support asset: $target_path"
      fi
    fi

    if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
      log_update_mode_added_file "$target_path"
    fi
  done

  while IFS= read -r existing_path; do
    existing_name="$(basename "$existing_path")"
    if ! array_contains "$existing_name" "$@"; then
      if ! rm -f "$existing_path"; then
        die "Failed to remove unmanaged staged support asset: $existing_path"
      fi
    fi
  done < <(find "$target_dir" -maxdepth 1 -type f | sort)
}

stage_support_assets() {
  local repo_root="$1"
  local asdlc_root="$2"
  local overwrite_existing="$3"
  local announce_added="$4"

  stage_support_asset_files "$repo_root" "$RULES_SOURCE_DIR" "$asdlc_root" "$LOCAL_STAGED_RULES_DIR_NAME" "$overwrite_existing" "no" "$announce_added" "${STAGED_RULE_FILES[@]}"
  stage_support_asset_files "$repo_root" "$TEMPLATES_SOURCE_DIR" "$asdlc_root" "$LOCAL_STAGED_TEMPLATES_DIR_NAME" "$overwrite_existing" "no" "$announce_added" "${STAGED_TEMPLATE_FILES[@]}"
  stage_support_asset_files "$repo_root" "$GOLDEN_EXAMPLES_SOURCE_DIR" "$asdlc_root" "$LOCAL_STAGED_GOLDEN_EXAMPLES_DIR_NAME" "$overwrite_existing" "no" "$announce_added" "${STAGED_GOLDEN_EXAMPLE_FILES[@]}"
  stage_support_asset_files "$repo_root" "$HELPER_SCRIPTS_SOURCE_DIR" "$asdlc_root" "$LOCAL_STAGED_HELPER_DIR_NAME" "$overwrite_existing" "yes" "$announce_added" "${STAGED_HELPER_FILES[@]}"
  stage_support_asset_files "$repo_root" "$SETUP_SOURCE_DIR" "$asdlc_root" "$LOCAL_STAGED_SETUP_DIR_NAME" "$overwrite_existing" "no" "$announce_added" "${STAGED_SETUP_FILES[@]}"
}

inject_default_projects_path_config() {
  local script_path="$1"
  local projects_dir="$2"
  local tmp_file=""

  if grep -q '^ASDLC_PROJECTS_DIR_DEFAULT=' "$script_path"; then
    return 0
  fi

  if ! tmp_file="$(mktemp)"; then
    die "Failed to create temporary file for staged command rewrite."
  fi

  if ! awk -v default_projects_dir="$projects_dir" '
BEGIN {
  inserted = 0
}
{
  print $0
  if (inserted == 0 && $0 == "set -euo pipefail") {
    print ""
    print "ASDLC_PROJECTS_DIR_DEFAULT=\"" default_projects_dir "\""
    print "ASDLC_PROJECTS_DIR=\"${ASDLC_PROJECTS_DIR:-$ASDLC_PROJECTS_DIR_DEFAULT}\""
    print "export ASDLC_PROJECTS_DIR"
    inserted = 1
  }
}
END {
  if (inserted == 0) {
    print ""
    print "ASDLC_PROJECTS_DIR_DEFAULT=\"" default_projects_dir "\""
    print "ASDLC_PROJECTS_DIR=\"${ASDLC_PROJECTS_DIR:-$ASDLC_PROJECTS_DIR_DEFAULT}\""
    print "export ASDLC_PROJECTS_DIR"
  }
}
' "$script_path" >"$tmp_file"; then
    rm -f "$tmp_file"
    die "Failed to set default ASDLC projects path in staged command: $script_path"
  fi

  if ! mv "$tmp_file" "$script_path"; then
    rm -f "$tmp_file"
    die "Failed to write staged command with default ASDLC projects path: $script_path"
  fi
}

stage_command_script() {
  local repo_root="$1"
  local source_rel_path="$2"
  local asdlc_root="$3"
  local projects_dir="$4"
  local overwrite_existing="$5"
  local announce_added="$6"
  local source_path="$repo_root/$source_rel_path"
  local target_path="$asdlc_root/.commands/$(basename "$source_rel_path")"
  local existed_before="no"

  [[ -f "$source_path" ]] || die "Required source script not found: $source_rel_path"

  if [[ -f "$target_path" ]]; then
    existed_before="yes"
  fi

  if [[ "$overwrite_existing" != "yes" && -f "$target_path" ]]; then
    return 0
  fi

  if ! cp "$source_path" "$target_path"; then
    die "Failed to stage command script: $source_rel_path"
  fi

  inject_default_projects_path_config "$target_path" "$projects_dir"

  if ! chmod +x "$target_path"; then
    die "Failed to set executable permission on staged command: $target_path"
  fi

  if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
    log_update_mode_added_file "$target_path"
  fi
}

stage_commands() {
  local repo_root="$1"
  local asdlc_root="$2"
  local overwrite_existing="$3"
  local announce_added="$4"
  local projects_dir="$asdlc_root/projects"

  if ! mkdir -p "$asdlc_root/.commands"; then
    die "Failed to create ASDLC commands directory under: $asdlc_root"
  fi

  stage_command_script "$repo_root" "$ADD_NEW_PROJECT_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$UPDATE_PROJECT_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_PROGRESS_SCANNER_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_PROJECT_STACK_BLUEPRINTS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_COMMON_CONTRACT_DEFINITION_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$REGISTER_WORKER_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_BR_SCAFFOLD_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$PROJECT_ADD_FEATURE_E2E_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_SCAN_REPO_FOR_BR_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_TASK_TO_BR_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_USER_BR_CLARIFICATION_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_BR_CHECK_EARS_READINESS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_BR_TO_EARS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_REQUIREMENTS_EARS_REVIEW_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_FEATURE_CONTRACT_DELTA_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_REPO_SURFACE_EXECUTION_CONTEXT_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_SURFACE_MAP_MCP_PLACEHOLDER_ENRICHMENT_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_TECHNICAL_REQUIREMENTS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_IMPLEMENTATION_SLICES_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_PREREQUISITE_GAPS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_IMPLEMENTATION_PLAN_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_ASSIGN_WORKERS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
}

remove_obsolete_staged_commands() {
  local asdlc_root="$1"
  local obsolete_name=""
  local obsolete_path=""

  for obsolete_name in "${OBSOLETE_STAGED_COMMAND_FILES[@]}"; do
    obsolete_path="$asdlc_root/.commands/$obsolete_name"
    if [[ -e "$obsolete_path" && ! -f "$obsolete_path" ]]; then
      die "Obsolete staged command path exists and is not a regular file: $obsolete_path"
    fi
    if [[ -f "$obsolete_path" ]]; then
      rm -f "$obsolete_path" || die "Failed to remove obsolete staged command: $obsolete_path"
    fi
  done
}

write_quickrun_guide() {
  local asdlc_root="$1"
  local quickrun_path="$asdlc_root/$QUICKRUN_FILE_NAME"

  cat >"$quickrun_path" <<EOF
# ASDLC Quick Run

This ASDLC workspace was initialized at:
\`$asdlc_root\`

Run all commands from:
\`$asdlc_root\`

Path conventions:
- Project path example: \`projects/<project-id>\`
- Feature path example: \`projects/<project-id>/<feature-folder>\`
- \`init_progress_scanner.sh\` expects a feature path, not a project path.

## 1. Create Or Update Project

1. Create a new project scaffold:
\`\`\`bash
.commands/project_setup_add_new_project.sh
\`\`\`
2. If the project already exists and you need to refresh staged ASDLC assets:
\`\`\`bash
.commands/project_setup_update_project.sh
\`\`\`
3. Generate the common contract definition for the project. For type A projects, approve stack-family blueprints first:
\`\`\`bash
.commands/init_project_stack_blueprints.sh --path projects/<project-id>
\`\`\`
\`\`\`bash
.commands/init_common_contract_definition.sh --path projects/<project-id>
\`\`\`
4. Register one active worker for the project and pass the generated UUID to the developer:
\`\`\`bash
.commands/project_register_worker.sh --path projects/<project-id>
\`\`\`
Worker records are stored in:
\`projects/<project-id>/workers.yaml\`

## 2. Create EARS Requirements

1. Preferred: run feature steps 3..8.3 with the lightweight orchestrator:
\`\`\`bash
.commands/project_add_feature_e2e.sh --path projects/<project-id>
\`\`\`
This run discovers unfinished feature folders for the project first and, when any exist, asks whether to start a new feature or continue one of the unfinished features.
The last selected feature path is cached in:
\`projects/<project-id>/.project_add_feature_e2e_state.env\`
as a convenience only; discovery plus scanner status remains the source of truth for project-level feature selection.
Resume examples:
\`\`\`bash
.commands/project_add_feature_e2e.sh --path projects/<project-id>
.commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 4.2
.commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 8.2
\`\`\`
2. Manual fallback - create feature BR scaffold:
\`\`\`bash
.commands/feature_br_scaffold.sh --path projects/<project-id>
\`\`\`
3. If this feature belongs to an existing repository, enrich the BR from repo scan:
\`\`\`bash
.commands/feature_scan_repo_for_br.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
4. Apply task or user input to the feature BR:
\`\`\`bash
.commands/feature_task_to_br.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
5. Continue the clarification loop for unresolved BR questions:
\`\`\`bash
.commands/feature_user_br_clarification.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
6. Check whether the BR is ready for EARS generation:
\`\`\`bash
.commands/feature_br_check_ears_readiness.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
7. Generate EARS requirements:
\`\`\`bash
.commands/feature_br_to_ears.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
8. Optionally run extra EARS review against the source feature story:
\`\`\`bash
.commands/feature_requirements_ears_review.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`

## 3. Continue Toward Implementation

1. Create the feature contract delta:
\`\`\`bash
.commands/feature_contract_delta.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
2. Analyze repository surface and execution context:
\`\`\`bash
.commands/feature_repo_surface_and_exec_context.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
3. Create feature technical requirements:
\`\`\`bash
.commands/feature_technical_requirements.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
4. Create implementation slices (Step 8.1):
\`\`\`bash
.commands/feature_implementation_slices.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
5. Create the shared implementation plan (Step 8.2):
\`\`\`bash
.commands/feature_implementation_plan.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
6. Optionally run implementation-plan semantic review (Step 8.3):
\`\`\`bash
.commands/feature_implementation_plan_semantic_review.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
7. Assign workers to implementation-plan steps:
\`\`\`bash
.commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>
\`\`\`
This command writes \`#### Assigned:\` for every plan step with a class-matched worker UUID or \`ERROR: no active worker available for class <class>\`.

## 4. Check Current Feature Progress

1. Scan current feature progress:
\`\`\`bash
.commands/init_progress_scanner.sh --path projects/<project-id>/<feature-folder>
\`\`\`
Careful: provide a feature path here, not a project path.
EOF
}

initialize_git_repo_and_commit_bootstrap_if_possible() {
  local repo_root="$1"
  local asdlc_root="$2"
  local repo_user_name=""
  local repo_user_email=""

  if ! git -C "$asdlc_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git -C "$asdlc_root" init -q >/dev/null 2>&1; then
      warn "Failed to initialize git repository under: $asdlc_root"
      return 0
    fi
  fi

  if ! git -C "$asdlc_root" config --get user.name >/dev/null 2>&1; then
    if repo_user_name="$(git -C "$repo_root" config --get user.name 2>/dev/null)" && [[ -n "$repo_user_name" ]]; then
      git -C "$asdlc_root" config user.name "$repo_user_name" >/dev/null 2>&1 || true
    fi
  fi
  if ! git -C "$asdlc_root" config --get user.email >/dev/null 2>&1; then
    if repo_user_email="$(git -C "$repo_root" config --get user.email 2>/dev/null)" && [[ -n "$repo_user_email" ]]; then
      git -C "$asdlc_root" config user.email "$repo_user_email" >/dev/null 2>&1 || true
    fi
  fi

  if ! git -C "$asdlc_root" add -- . >/dev/null 2>&1; then
    warn "Failed to stage ASDLC bootstrap artifacts for commit: $asdlc_root"
    return 0
  fi

  if git -C "$asdlc_root" diff --cached --quiet; then
    warn "No ASDLC bootstrap artifacts to commit under: $asdlc_root"
    return 0
  fi

  if ! git -C "$asdlc_root" commit -m "Initialize ASDLC workspace bootstrap" >/dev/null 2>&1; then
    warn "Failed to commit ASDLC bootstrap artifacts under: $asdlc_root"
  fi
}

main() {
  require_command git
  require_command awk
  require_command mktemp

  local repo_root=""
  local selected_parent=""
  local validated_parent=""
  local asdlc_root=""
  local workspace_mode=""

  repo_root="$(resolve_repo_root)"
  selected_parent="$(prompt_parent_directory)"
  validated_parent="$(normalize_and_validate_parent_path "$selected_parent")"
  asdlc_root="$validated_parent/asdlc"
  resolve_workspace_mode "$asdlc_root"
  workspace_mode="$WORKSPACE_MODE"
  ensure_support_asset_sources_exist "$repo_root"

  if [[ "$workspace_mode" == "update" ]]; then
    stage_commands "$repo_root" "$asdlc_root" "no" "yes"
    remove_obsolete_staged_commands "$asdlc_root"
    stage_support_assets "$repo_root" "$asdlc_root" "yes" "yes"
    stage_template_file "$repo_root" "$asdlc_root" "yes"
    write_quickrun_guide "$asdlc_root"
    echo "ASDLC workspace update completed: $asdlc_root"
    return 0
  fi

  create_bootstrap_directories "$asdlc_root"
  write_metadata_scaffold "$asdlc_root"
  stage_support_assets "$repo_root" "$asdlc_root" "yes" "no"
  stage_template_file "$repo_root" "$asdlc_root" "no"
  stage_commands "$repo_root" "$asdlc_root" "yes" "no"
  remove_obsolete_staged_commands "$asdlc_root"
  write_quickrun_guide "$asdlc_root"
  initialize_git_repo_and_commit_bootstrap_if_possible "$repo_root" "$asdlc_root"

  echo "ASDLC workspace bootstrap completed: $asdlc_root"
}

main "$@"
