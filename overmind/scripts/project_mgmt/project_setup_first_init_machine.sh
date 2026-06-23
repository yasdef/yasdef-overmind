#!/usr/bin/env bash
set -euo pipefail

ADD_NEW_PROJECT_SCRIPT="overmind/scripts/project_mgmt/project_setup_add_new_project.sh"
UPDATE_PROJECT_SCRIPT="overmind/scripts/project_mgmt/project_setup_update_project.sh"
INIT_PROGRESS_SCANNER_SCRIPT="overmind/scripts/project_mgmt/init_progress_scanner.sh"
INIT_PROJECT_STACK_BLUEPRINTS_SCRIPT="overmind/scripts/init_project_stack_blueprints.sh"
INIT_COMMON_CONTRACT_DEFINITION_SCRIPT="overmind/scripts/init_common_contract_definition.sh"
PROJECT_CONTRACT_RECONCILIATION_SCRIPT="overmind/scripts/project_mgmt/project_contract_reconciliation.sh"
FEATURE_BR_SCAFFOLD_SCRIPT="overmind/scripts/feature_br_scaffold.sh"
PROJECT_ADD_FEATURE_E2E_SCRIPT="overmind/scripts/project_mgmt/project_add_feature_e2e.sh"
REGISTER_WORKER_SCRIPT="overmind/scripts/project_mgmt/project_register_worker.sh"
FEATURE_ASSIGN_WORKERS_SCRIPT="overmind/scripts/feature_assing_workers.sh"
TEMPLATE_SOURCE_FILE="overmind/templates/init_progress_definition_TEMPLATE.yaml"
RULES_SOURCE_DIR="overmind/rules"
TEMPLATES_SOURCE_DIR="overmind/templates"
GOLDEN_EXAMPLES_SOURCE_DIR="overmind/golden_examples"
HELPER_SCRIPTS_SOURCE_DIR="overmind/scripts/helper"
SETUP_SOURCE_DIR="overmind/setup"
COMMON_LIBS_SOURCE_DIR="overmind/scripts/common_libs"
OVERMIND_CLI_BUNDLE_SOURCE_FILE="packages/asdlc-coordinator/dist/overmind.js"
SKILL_NAMES=(
  "overmind-task-to-br"
  "overmind-repo-br-scan"
  "overmind-br-clarification"
  "overmind-requirements-ears"
  "overmind-ears-review"
  "overmind-contract-delta"
  "overmind-surface-map"
  "overmind-surface-map-enrich"
  "overmind-technical-requirements"
  "overmind-implementation-slices"
  "overmind-prerequisite-gaps"
  "overmind-implementation-plan"
  "overmind-plan-semantic-review"
)
SKILL_SOURCE_BASE_DIR="packages/installer/_data/skills"
SKILL_RUNNER_DIRS=(
  ".codex"
  ".claude"
)
# Skills whose source directory intentionally has no assets/ subdirectory.
ASSETLESS_SKILL_NAMES=(
  "overmind-surface-map-enrich"
)
LOCAL_TEMPLATE_DIR_NAME=".templates"
LOCAL_STAGED_RULES_DIR_NAME=".rules"
LOCAL_STAGED_TEMPLATES_DIR_NAME=".templates"
LOCAL_STAGED_GOLDEN_EXAMPLES_DIR_NAME=".golden_examples"
LOCAL_STAGED_HELPER_DIR_NAME=".helper"
LOCAL_STAGED_SETUP_DIR_NAME=".setup"
LOCAL_STAGED_OVERMIND_DIR_NAME=".overmind"
LOCAL_STAGED_OVERMIND_CLI_FILE_NAME="overmind.js"
LOCAL_STAGED_COMMAND_LIBS_DIR_NAME="common_libs"
LOCAL_TEMPLATE_FILE_NAME="init_progress_definition_TEMPLATE.yaml"
METADATA_FILE_NAME="asdlc_metadata.yaml"
QUICKRUN_FILE_NAME="quickrun.md"
WORKSPACE_MODE="bootstrap"

STAGED_RULE_FILES=(
  "common_contract_definition_rule.md"
  "project_stack_blueprint_rule.md"
"task_to_br_rule.md"
  "project_contract_reconciliation_rule.md"
)
STAGED_TEMPLATE_FILES=(
  "common_contract_definition_TEMPLATE.md"
  "feature_br_summary_TEMPLATE.md"
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
STAGED_SETUP_FILES_PRESERVE_IF_EXISTS=(
  "external_sources.yaml"
  "models.md"
)
STAGED_COMMAND_LIB_FILES=(
  "class_repo_paths.sh"
  "check_implementation_plan_readiness.sh"
  "list_committed_sibling_features.sh"
  "persist_class_repo_attach.sh"
  "project_setup_common.sh"
  "sync_repo_to_default_branch.sh"
)
OBSOLETE_STAGED_COMMAND_FILES=(
  "feature_technical_requirements.sh"
  "feature_implementation_slices.sh"
  "feature_prerequisite_gaps.sh"
  "feature_implementation_plan.sh"
  "feature_implementation_plan_semantic_review.sh"
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

ensure_skill_source_exists() {
  local repo_root="$1"
  local skill_name=""
  local source_dir=""
  local assetless=""
  local is_assetless=""

  for skill_name in "${SKILL_NAMES[@]}"; do
    source_dir="$repo_root/$SKILL_SOURCE_BASE_DIR/$skill_name"
    [[ -d "$source_dir" ]] || die "Required packaged skill source not found: $SKILL_SOURCE_BASE_DIR/$skill_name. Run npm install and npm run build from the repository root before ASDLC setup/update."
    [[ -f "$source_dir/SKILL.md" ]] || die "Required packaged skill file not found: $SKILL_SOURCE_BASE_DIR/$skill_name/SKILL.md"
    is_assetless="no"
    for assetless in "${ASSETLESS_SKILL_NAMES[@]}"; do
      [[ "$skill_name" == "$assetless" ]] && is_assetless="yes" && break
    done
    [[ "$is_assetless" == "yes" ]] || [[ -d "$source_dir/assets" ]] || die "Required packaged skill assets not found: $SKILL_SOURCE_BASE_DIR/$skill_name/assets"
  done
}

ensure_support_asset_sources_exist() {
  local repo_root="$1"

  ensure_template_source_exists "$repo_root"
  [[ -f "$repo_root/$OVERMIND_CLI_BUNDLE_SOURCE_FILE" ]] || die "Required Overmind CLI bundle not found: $OVERMIND_CLI_BUNDLE_SOURCE_FILE. Run npm install and npm run build from the repository root before ASDLC setup/update."
  ensure_skill_source_exists "$repo_root"
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

stage_setup_assets() {
  local repo_root="$1"
  local asdlc_root="$2"
  local overwrite_existing="$3"
  local announce_added="$4"
  local source_dir="$repo_root/$SETUP_SOURCE_DIR"
  local target_dir="$asdlc_root/$LOCAL_STAGED_SETUP_DIR_NAME"
  local source_file_name=""
  local source_path=""
  local target_path=""
  local existing_path=""
  local existing_name=""
  local existed_before="no"

  if ! mkdir -p "$target_dir"; then
    die "Failed to create ASDLC support assets directory under: $target_dir"
  fi

  for source_file_name in "${STAGED_SETUP_FILES_PRESERVE_IF_EXISTS[@]}"; do
    source_path="$source_dir/$source_file_name"
    [[ -f "$source_path" ]] || die "Required support asset not found: $SETUP_SOURCE_DIR/$source_file_name"

    target_path="$target_dir/$source_file_name"
    existed_before="no"
    if [[ -f "$target_path" ]]; then
      existed_before="yes"
    fi

    if [[ -f "$target_path" ]]; then
      continue
    fi

    if ! cp "$source_path" "$target_path"; then
      die "Failed to stage support asset file: $SETUP_SOURCE_DIR/$source_file_name"
    fi

    if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
      log_update_mode_added_file "$target_path"
    fi
  done

  while IFS= read -r existing_path; do
    existing_name="$(basename "$existing_path")"
    if ! array_contains "$existing_name" "${STAGED_SETUP_FILES[@]}"; then
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
  stage_setup_assets "$repo_root" "$asdlc_root" "$overwrite_existing" "$announce_added"
}

stage_overmind_cli() {
  local repo_root="$1"
  local asdlc_root="$2"
  local overwrite_existing="$3"
  local announce_added="$4"
  local source_path="$repo_root/$OVERMIND_CLI_BUNDLE_SOURCE_FILE"
  local target_dir="$asdlc_root/$LOCAL_STAGED_OVERMIND_DIR_NAME"
  local target_path="$target_dir/$LOCAL_STAGED_OVERMIND_CLI_FILE_NAME"
  local existed_before="no"

  [[ -f "$source_path" ]] || die "Required Overmind CLI bundle not found: $OVERMIND_CLI_BUNDLE_SOURCE_FILE. Run npm install and npm run build from the repository root before ASDLC setup/update."

  if [[ -f "$target_path" ]]; then
    existed_before="yes"
  fi

  if [[ "$overwrite_existing" != "yes" && -f "$target_path" ]]; then
    return 0
  fi

  if ! mkdir -p "$target_dir"; then
    die "Failed to create staged Overmind CLI directory: $target_dir"
  fi

  if ! cp "$source_path" "$target_path"; then
    die "Failed to stage Overmind CLI bundle to: $target_path"
  fi

  if ! chmod +x "$target_path"; then
    die "Failed to set executable permission on staged Overmind CLI bundle: $target_path"
  fi

  if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
    log_update_mode_added_file "$target_path"
  fi
}

stage_runner_skills() {
  local repo_root="$1"
  local asdlc_root="$2"
  local announce_added="$3"
  local skill_name=""
  local source_dir=""
  local runner_dir=""
  local target_parent=""
  local target_dir=""
  local existed_before=""

  for skill_name in "${SKILL_NAMES[@]}"; do
    source_dir="$repo_root/$SKILL_SOURCE_BASE_DIR/$skill_name"
    [[ -d "$source_dir" ]] || die "Required packaged skill source not found: $SKILL_SOURCE_BASE_DIR/$skill_name. Run npm install and npm run build from the repository root before ASDLC setup/update."

    for runner_dir in "${SKILL_RUNNER_DIRS[@]}"; do
      target_parent="$asdlc_root/$runner_dir/skills"
      target_dir="$target_parent/$skill_name"
      existed_before="no"
      if [[ -d "$target_dir" ]]; then
        existed_before="yes"
      fi

      if ! mkdir -p "$target_parent"; then
        die "Failed to create runner skills directory: $target_parent"
      fi

      # Treat the installed skill as package-owned payload: refresh from canonical
      # source so missing or stale runner skill folders are repaired in update mode.
      if [[ -e "$target_dir" ]]; then
        rm -rf "$target_dir" || die "Failed to remove stale staged skill folder: $target_dir"
      fi

      if ! cp -R "$source_dir" "$target_dir"; then
        die "Failed to stage runner skill to: $target_dir"
      fi

      if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
        log_update_mode_added_file "$target_dir"
      fi
    done
  done
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

stage_command_libs() {
  local repo_root="$1"
  local asdlc_root="$2"
  local overwrite_existing="$3"
  local announce_added="$4"
  local source_dir="$repo_root/$COMMON_LIBS_SOURCE_DIR"
  local target_dir="$asdlc_root/$LOCAL_STAGED_COMMAND_LIBS_DIR_NAME"
  local source_file_name=""
  local source_path=""
  local target_path=""
  local existed_before=""

  if ! mkdir -p "$target_dir"; then
    die "Failed to create command libs directory: $target_dir"
  fi

  for source_file_name in "${STAGED_COMMAND_LIB_FILES[@]}"; do
    source_path="$source_dir/$source_file_name"
    target_path="$target_dir/$source_file_name"
    existed_before="no"

    [[ -f "$source_path" ]] || die "Required command lib not found: $COMMON_LIBS_SOURCE_DIR/$source_file_name"

    if [[ -f "$target_path" ]]; then
      existed_before="yes"
    fi

    if [[ "$overwrite_existing" != "yes" && -f "$target_path" ]]; then
      continue
    fi

    if ! cp "$source_path" "$target_path"; then
      die "Failed to stage command lib: $COMMON_LIBS_SOURCE_DIR/$source_file_name"
    fi

    if ! chmod +x "$target_path"; then
      die "Failed to set executable permission on staged command lib: $target_path"
    fi

    if [[ "$announce_added" == "yes" && "$existed_before" == "no" ]]; then
      log_update_mode_added_file "$target_path"
    fi
  done
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

  local obsolete_name=""
  for obsolete_name in "${OBSOLETE_STAGED_COMMAND_FILES[@]}"; do
    if [[ -e "$asdlc_root/.commands/$obsolete_name" ]]; then
      rm -f "$asdlc_root/.commands/$obsolete_name" || die "Failed to remove obsolete staged command: $asdlc_root/.commands/$obsolete_name"
    fi
  done

  stage_command_libs "$repo_root" "$asdlc_root" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$ADD_NEW_PROJECT_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$UPDATE_PROJECT_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_PROGRESS_SCANNER_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_PROJECT_STACK_BLUEPRINTS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$INIT_COMMON_CONTRACT_DEFINITION_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$PROJECT_CONTRACT_RECONCILIATION_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$REGISTER_WORKER_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_BR_SCAFFOLD_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$PROJECT_ADD_FEATURE_E2E_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
  stage_command_script "$repo_root" "$FEATURE_ASSIGN_WORKERS_SCRIPT" "$asdlc_root" "$projects_dir" "$overwrite_existing" "$announce_added"
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
- Task-to-BR gates run through the staged CLI at \`.overmind/overmind.js\`.
- The \`overmind-task-to-br\`, \`overmind-repo-br-scan\`, \`overmind-br-clarification\`, \`overmind-requirements-ears\`, \`overmind-ears-review\`, \`overmind-contract-delta\`, \`overmind-surface-map\`, \`overmind-surface-map-enrich\`, \`overmind-technical-requirements\`, \`overmind-implementation-slices\`, \`overmind-prerequisite-gaps\`, \`overmind-implementation-plan\`, and \`overmind-plan-semantic-review\` skills are staged for supported runners at \`.codex/skills/\` and \`.claude/skills/\`.
- Successful scanner runs persist \`projects/<project-id>/step_state_<feature-folder>.md\`; stdout remains the canonical machine-consumable output.

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
.commands/project_add_feature_e2e.sh
\`\`\`
\`\`\`bash
.commands/project_add_feature_e2e.sh --path projects/<project-id>
\`\`\`
If \`--path\` is omitted, the script auto-selects the only project under \`projects/\` or prompts you to choose one when multiple projects exist.
This run discovers unfinished feature folders for the project first and, when any exist, asks whether to start a new feature or continue one of the unfinished features.
During phase 4.1, the orchestrator starts a Codex repo-br-scan session (when a class repo is ready) followed by a task-to-BR session using the installed skills; when \`user_br_input.md\` is missing, Codex asks for a local story file or Jira ticket. During phase 4.2, the orchestrator starts the BR-clarification skill and then runs the deterministic readiness check. During phase 5, the orchestrator starts the requirements-EARS skill. During optional phase 5.1, the orchestrator starts the EARS-review skill. During phase 6, it syncs ready repositories and starts the contract-delta skill.
The last selected feature path is cached in:
\`projects/<project-id>/.project_add_feature_e2e_state.env\`
as a convenience only; discovery plus scanner status remains the source of truth for project-level feature selection.
Resume examples:
\`\`\`bash
.commands/project_add_feature_e2e.sh --resume 4.2
.commands/project_add_feature_e2e.sh --path projects/<project-id>
.commands/project_add_feature_e2e.sh --path projects/<project-id> --resume 8.2
\`\`\`
2. Manual fallback - create feature BR scaffold:
\`\`\`bash
.commands/feature_br_scaffold.sh --path projects/<project-id>
\`\`\`
3. During phase 4.1, the orchestrator runs the repo-br-scan skill (when a class repo is ready) to enrich \`## 13. Existing-System Context\`, then runs the task-to-BR skill.
4. Continue the clarification loop for unresolved BR questions through the installed \`overmind-br-clarification\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context br-clarification projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate br-clarification projects/<project-id>/<feature-folder>
\`\`\`
5. Check whether the BR is ready for EARS generation:
\`\`\`bash
node .overmind/overmind.js readiness br-clarification projects/<project-id>/<feature-folder>
\`\`\`
6. Generate EARS requirements through the installed \`overmind-requirements-ears\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context requirements-ears projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate requirements-ears projects/<project-id>/<feature-folder>
\`\`\`
7. Optionally run extra EARS review through the installed \`overmind-ears-review\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context ears-review projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate ears-review projects/<project-id>/<feature-folder>
\`\`\`

## 3. Continue Toward Implementation

1. Create the feature contract delta through the installed \`overmind-contract-delta\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context contract-delta projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate contract-delta projects/<project-id>/<feature-folder>
\`\`\`
2. Analyze repository surface and execution context per class through the installed \`overmind-surface-map\` skill. The skill assembles context with:
\`\`\`bash
node .overmind/overmind.js context surface-map projects/<project-id>/<feature-folder> --class <backend|frontend|mobile>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate surface-map projects/<project-id>/<feature-folder> --class <backend|frontend|mobile>
\`\`\`
3. Optionally enrich unresolved surface-map placeholders from configured knowledge-base MCP sources (Step 7.1) through the installed \`overmind-surface-map-enrich\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context surface-map-enrich projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate surface-map projects/<project-id>/<feature-folder> --class <backend|frontend|mobile>
\`\`\`
4. Create feature technical requirements through the installed \`overmind-technical-requirements\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context technical-requirements projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate technical-requirements projects/<project-id>/<feature-folder>
\`\`\`
5. Create implementation slices through the installed \`overmind-implementation-slices\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context implementation-slices projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate implementation-slices projects/<project-id>/<feature-folder>
\`\`\`
6. Create prerequisite gaps through the installed \`overmind-prerequisite-gaps\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context prerequisite-gaps projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate prerequisite-gaps projects/<project-id>/<feature-folder>
\`\`\`
7. Create the shared implementation plan through the installed \`overmind-implementation-plan\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context implementation-plan projects/<project-id>/<feature-folder>
\`\`\`
and validates with:
\`\`\`bash
node .overmind/overmind.js gate implementation-plan projects/<project-id>/<feature-folder>
\`\`\`
8. Optionally run implementation-plan semantic review (Step 8.4) through the installed \`overmind-plan-semantic-review\` skill. The skill uses:
\`\`\`bash
node .overmind/overmind.js context plan-semantic-review projects/<project-id>/<feature-folder>
\`\`\`
and validates the review ledger with:
\`\`\`bash
node .overmind/overmind.js gate plan-semantic-review projects/<project-id>/<feature-folder>
\`\`\`
9. Assign workers to implementation-plan steps:
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
The persisted checklist file is written to:
\`projects/<project-id>/step_state_<feature-folder>.md\`
EOF
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
    stage_overmind_cli "$repo_root" "$asdlc_root" "yes" "yes"
    stage_runner_skills "$repo_root" "$asdlc_root" "yes"
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
  stage_overmind_cli "$repo_root" "$asdlc_root" "yes" "no"
  stage_runner_skills "$repo_root" "$asdlc_root" "no"
  write_quickrun_guide "$asdlc_root"
  echo "ASDLC workspace bootstrap completed: $asdlc_root"
}

main "$@"
