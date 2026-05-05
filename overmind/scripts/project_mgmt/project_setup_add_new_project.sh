#!/usr/bin/env bash
set -euo pipefail

ASDLC_METADATA_FILE_NAME="asdlc_metadata.yaml"
ASDLC_PROJECTS_DIR_NAME="projects"
ASDLC_TEMPLATES_DIR_NAME=".templates"
ASDLC_PROJECT_TEMPLATE_FILE_NAME="init_progress_definition_TEMPLATE.yaml"
PROJECT_DEFINITION_FILE_NAME="init_progress_definition.yaml"
PROJECT_CLASS_OPTIONS=(
  "backend"
  "frontend"
  "mobile"
  "infrastructure"
)

source "$(dirname "$0")/../common_libs/project_setup_common.sh"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "Required command not found: $command_name"
  fi
}

resolve_script_dir() {
  local script_dir=""
  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    die "Failed to resolve script directory."
  fi
  printf '%s' "$script_dir"
}

resolve_asdlc_root_from_staged_path() {
  local script_dir="$1"
  local asdlc_root=""

  if [[ "$(basename "$script_dir")" != ".commands" ]]; then
    die "Run this command from ASDLC staged path: <asdlc>/.commands/project_setup_add_new_project.sh"
  fi

  if ! asdlc_root="$(cd "$script_dir/.." && pwd)"; then
    die "Failed to resolve ASDLC root from staged command path: $script_dir"
  fi

  printf '%s' "$asdlc_root"
}

prompt_feature_name() {
  local feature_name=""
  echo "Define project name:" >&2
  read -r feature_name
  printf '%s' "$feature_name"
}

normalize_feature_name() {
  local raw_name="$1"
  printf '%s' "$raw_name" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g'
}

generate_project_uuid() {
  local epoch_ms=""
  epoch_ms="$(date +%s%3N 2>/dev/null || true)"
  if [[ ! "$epoch_ms" =~ ^[0-9]{13}$ ]]; then
    epoch_ms="$(date +%s)000"
  fi
  printf '%s' "$epoch_ms"
}

generate_created_at_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

prompt_project_type_code() {
  local selection=""

  while true; do
    echo "Select project type (mandatory):" >&2
    echo "1. A - New project" >&2
    echo "2. B - Existing project with partial context" >&2
    echo "3. C - Existing project with code-first context" >&2

    if ! read -r selection; then
      die "Failed to read project type selection."
    fi

    case "$selection" in
    1|A|a)
      printf 'A'
      return 0
      ;;
    2|B|b)
      printf 'B'
      return 0
      ;;
    3|C|c)
      printf 'C'
      return 0
      ;;
    *)
      echo "Invalid selection. Enter 1, 2, or 3." >&2
      ;;
    esac
  done
}

is_class_selected() {
  local selected_classes="$1"
  local candidate_class="$2"
  local class_name=""

  while IFS= read -r class_name; do
    [[ -z "$class_name" ]] && continue
    if [[ "$class_name" == "$candidate_class" ]]; then
      return 0
    fi
  done <<<"$selected_classes"

  return 1
}

ordered_selected_classes() {
  local selected_classes="$1"
  local class_name=""

  for class_name in "${PROJECT_CLASS_OPTIONS[@]}"; do
    if is_class_selected "$selected_classes" "$class_name"; then
      printf '%s\n' "$class_name"
    fi
  done
}

join_selected_classes() {
  local selected_classes="$1"
  local ordered_classes=""
  local class_name=""
  local joined=""

  ordered_classes="$(ordered_selected_classes "$selected_classes")"
  while IFS= read -r class_name; do
    [[ -z "$class_name" ]] && continue
    if [[ -n "$joined" ]]; then
      joined="$joined, "
    fi
    joined="$joined$class_name"
  done <<<"$ordered_classes"

  printf '%s' "$joined"
}

prompt_project_classes() {
  local selected_classes=""
  local selected_class=""
  local selection=""
  local class_summary=""

  while true; do
    echo "Select project class to add:" >&2
    if ! is_class_selected "$selected_classes" "backend"; then
      echo "1. backend" >&2
    fi
    if ! is_class_selected "$selected_classes" "frontend"; then
      echo "2. frontend" >&2
    fi
    if ! is_class_selected "$selected_classes" "mobile"; then
      echo "3. mobile" >&2
    fi
    if ! is_class_selected "$selected_classes" "infrastructure"; then
      echo "4. infrastructure" >&2
    fi
    echo "5. all done, nothing else to add" >&2

    if ! read -r selection; then
      die "Failed to read project class selection."
    fi

    case "$selection" in
    1)
      if is_class_selected "$selected_classes" "backend"; then
        echo "Invalid selection. Enter one of displayed options." >&2
        continue
      fi
      selected_class="backend"
      ;;
    2)
      if is_class_selected "$selected_classes" "frontend"; then
        echo "Invalid selection. Enter one of displayed options." >&2
        continue
      fi
      selected_class="frontend"
      ;;
    3)
      if is_class_selected "$selected_classes" "mobile"; then
        echo "Invalid selection. Enter one of displayed options." >&2
        continue
      fi
      selected_class="mobile"
      ;;
    4)
      if is_class_selected "$selected_classes" "infrastructure"; then
        echo "Invalid selection. Enter one of displayed options." >&2
        continue
      fi
      selected_class="infrastructure"
      ;;
    5)
      if [[ -z "$selected_classes" ]]; then
        echo "Select at least one project class before finishing." >&2
        continue
      fi
      break
      ;;
    *)
      echo "Invalid selection. Enter one of displayed options." >&2
      continue
      ;;
    esac

    selected_classes="${selected_classes}${selected_classes:+$'\n'}$selected_class"
    class_summary="$(join_selected_classes "$selected_classes")"
    echo "Already added classes: $class_summary" >&2
  done

  printf '%s' "$selected_classes"
}

prompt_repo_path_for_class() {
  local project_class="$1"
  local repo_path=""
  local resolved_repo_path=""

  while true; do
    echo "Enter repo path for $project_class:" >&2
    if ! read -r repo_path; then
      die "Failed to read repo path for $project_class."
    fi

    if ! validate_repo_path "$repo_path"; then
      continue
    fi

    if ! resolved_repo_path="$(resolve_repo_path "$repo_path")"; then
      echo "Failed to resolve repo path: $repo_path" >&2
      continue
    fi

    printf '%s' "$resolved_repo_path"
    return 0
  done
}

collect_repo_path_states() {
  local selected_classes="$1"
  local ordered_classes=""
  local class_name=""
  local readiness=""
  local repo_path=""
  local repo_path_states=""

  ordered_classes="$(ordered_selected_classes "$selected_classes")"
  for class_name in $ordered_classes; do
    [[ -z "$class_name" ]] && continue

    while true; do
      echo "we need to add repo path in your system for $class_name" >&2
      echo "1. yes, ready to add" >&2
      echo "2. no, I'll add it later" >&2

      if ! read -r readiness; then
        die "Failed to read repo path readiness selection for $class_name."
      fi

      case "$readiness" in
      1)
        repo_path="$(prompt_repo_path_for_class "$class_name")"
        repo_path_states="${repo_path_states}${repo_path_states:+$'\n'}${class_name}|ready|${repo_path}"
        break
        ;;
      2)
        repo_path_states="${repo_path_states}${repo_path_states:+$'\n'}${class_name}|deferred|"
        echo "Marked $class_name repo path as deferred." >&2
        break
        ;;
      *)
        echo "Invalid selection. Enter 1 or 2." >&2
        ;;
      esac
    done
  done

  printf '%s' "$repo_path_states"
}

assert_metadata_shape() {
  local metadata_path="$1"

  grep -q '^meta:[[:space:]]*$' "$metadata_path" || die "Invalid ASDLC metadata: missing top-level key 'meta'."
  grep -q '^projects:[[:space:]]*$' "$metadata_path" || die "Invalid ASDLC metadata: missing top-level key 'projects'."
  if ! awk '
/^[^[:space:]#][^:]*:[[:space:]]*$/ {
  key = $0
  sub(/:[[:space:]]*$/, "", key)
  last_top_key = key
}
END {
  exit(last_top_key == "projects" ? 0 : 1)
}
' "$metadata_path"; then
    die "Invalid ASDLC metadata: top-level key 'projects' must be the final section."
  fi
}

append_project_record() {
  local metadata_path="$1"
  local project_id="$2"
  local feature_name="$3"
  local internal_folder="$4"
  local created_at="$5"
  local escaped_feature_name=""
  local escaped_internal_folder=""
  local escaped_created_at=""
  local tmp_file=""

  escaped_feature_name="$(escape_yaml_double_quoted_value "$feature_name")"
  escaped_internal_folder="$(escape_yaml_double_quoted_value "$internal_folder")"
  escaped_created_at="$(escape_yaml_double_quoted_value "$created_at")"

  if ! tmp_file="$(mktemp)"; then
    die "Failed to create temporary file for metadata update."
  fi

  if ! cat "$metadata_path" >"$tmp_file"; then
    rm -f "$tmp_file"
    die "Failed to copy ASDLC metadata for update: $metadata_path"
  fi

  if [[ -s "$tmp_file" ]]; then
    local normalized_tmp_file=""
    if ! normalized_tmp_file="$(mktemp)"; then
      rm -f "$tmp_file"
      die "Failed to create temporary file for metadata normalization."
    fi
    if ! awk '
{
  lines[NR] = $0
}
END {
  last = NR
  while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
    last--
  }
  for (i = 1; i <= last; i++) {
    print lines[i]
  }
}
' "$tmp_file" >"$normalized_tmp_file"; then
      rm -f "$tmp_file" "$normalized_tmp_file"
      die "Failed to normalize ASDLC metadata before append: $metadata_path"
    fi
    mv "$normalized_tmp_file" "$tmp_file"
  fi

  cat >>"$tmp_file" <<EOF
  - project: $project_id
    name: "$escaped_feature_name"
    internal_folder: "$escaped_internal_folder"
    created_at: "$escaped_created_at"
EOF

  if ! mv "$tmp_file" "$metadata_path"; then
    rm -f "$tmp_file"
    die "Failed to write ASDLC metadata: $metadata_path"
  fi
}

extract_repo_state_by_class() {
  local repo_path_states="$1"
  local class_name="$2"
  local parsed_class=""
  local parsed_state=""
  local parsed_path=""

  while IFS='|' read -r parsed_class parsed_state parsed_path; do
    [[ -z "$parsed_class" ]] && continue
    if [[ "$parsed_class" == "$class_name" ]]; then
      printf '%s' "$parsed_state"
      return 0
    fi
  done <<<"$repo_path_states"

  printf 'deferred'
}

extract_repo_path_by_class() {
  local repo_path_states="$1"
  local class_name="$2"
  local parsed_class=""
  local parsed_state=""
  local parsed_path=""

  while IFS='|' read -r parsed_class parsed_state parsed_path; do
    [[ -z "$parsed_class" ]] && continue
    if [[ "$parsed_class" == "$class_name" ]]; then
      printf '%s' "$parsed_path"
      return 0
    fi
  done <<<"$repo_path_states"

  printf ''
}

inject_project_bootstrap_into_definition() {
  local definition_path="$1"
  local project_id="$2"
  local project_classes="$3"
  local repo_path_states="$4"
  local project_type_code="$5"
  local project_type_label="$6"
  local escaped_project_id=""
  local escaped_project_type_code=""
  local escaped_project_type_label=""
  local ordered_classes=""
  local class_name=""
  local repo_state=""
  local repo_path=""
  local escaped_repo_path=""
  local steps_block=""
  local tmp_file=""

  escaped_project_id="$(escape_yaml_double_quoted_value "$project_id")"
  escaped_project_type_code="$(escape_yaml_double_quoted_value "$project_type_code")"
  escaped_project_type_label="$(escape_yaml_double_quoted_value "$project_type_label")"

  if ! steps_block="$(awk '
BEGIN {
  in_steps = 0
}
/^steps:[[:space:]]*$/ {
  in_steps = 1
}
{
  if (in_steps == 1) {
    print
  }
}
' "$definition_path")"; then
    die "Failed to read steps block from project definition: $definition_path"
  fi

  if [[ -z "$steps_block" ]]; then
    die "Invalid project definition template: missing top-level steps block in $definition_path"
  fi

  if ! tmp_file="$(mktemp)"; then
    die "Failed to create temporary file for project definition update."
  fi

  ordered_classes="$(ordered_selected_classes "$project_classes")"
  if [[ -z "$ordered_classes" ]]; then
    rm -f "$tmp_file"
    die "At least one project class is required to seed project definition."
  fi

  {
    echo "meta_info:"
    echo "  project_id: \"$escaped_project_id\""
    echo "  project_classes:"
    while IFS= read -r class_name; do
      [[ -z "$class_name" ]] && continue
      echo "    - $class_name"
    done <<<"$ordered_classes"
    echo "  project_type_code: \"$escaped_project_type_code\""
    echo "  project_type_label: \"$escaped_project_type_label\""
    echo "  class_repo_paths:"
    while IFS= read -r class_name; do
      [[ -z "$class_name" ]] && continue
      repo_state="$(extract_repo_state_by_class "$repo_path_states" "$class_name")"
      repo_path="$(extract_repo_path_by_class "$repo_path_states" "$class_name")"
      escaped_repo_path="$(escape_yaml_double_quoted_value "$repo_path")"
      echo "    $class_name:"
      echo "      state: \"$repo_state\""
      echo "      path: \"$escaped_repo_path\""
    done <<<"$ordered_classes"
    echo ""
    printf '%s\n' "$steps_block"
  } >"$tmp_file" || {
    rm -f "$tmp_file"
    die "Failed to write project definition metadata payload: $definition_path"
  }

  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    die "Failed to generate project definition metadata payload: $definition_path"
  fi

  if ! mv "$tmp_file" "$definition_path"; then
    rm -f "$tmp_file"
    die "Failed to write project definition metadata: $definition_path"
  fi
}

main() {
  require_command sed
  require_command tr
  require_command mktemp
  require_command date
  require_command awk
  require_command ls

  local script_dir=""
  local asdlc_root=""
  local metadata_path=""
  local template_path=""
  local projects_root=""
  local feature_name_raw=""
  local feature_name_normalized=""
  local project_uuid=""
  local created_at=""
  local project_folder_name=""
  local project_folder_path=""
  local project_definition_path=""
  local project_classes=""
  local repo_path_states=""
  local project_type_code=""
  local project_type_label=""

  script_dir="$(resolve_script_dir)"
  asdlc_root="$(resolve_asdlc_root_from_staged_path "$script_dir")"
  metadata_path="$asdlc_root/$ASDLC_METADATA_FILE_NAME"
  template_path="$asdlc_root/$ASDLC_TEMPLATES_DIR_NAME/$ASDLC_PROJECT_TEMPLATE_FILE_NAME"
  projects_root="$asdlc_root/$ASDLC_PROJECTS_DIR_NAME"

  [[ -f "$metadata_path" ]] || die "Required file not found: $metadata_path"
  [[ -f "$template_path" ]] || die "Required file not found: $template_path"
  [[ -d "$projects_root" ]] || die "Required directory not found: $projects_root"
  assert_metadata_shape "$metadata_path"

  feature_name_raw="$(prompt_feature_name)"
  if [[ -z "${feature_name_raw//[[:space:]]/}" ]]; then
    die "Project name cannot be empty."
  fi

  feature_name_normalized="$(normalize_feature_name "$feature_name_raw")"
  if [[ -z "$feature_name_normalized" ]]; then
    die "Project name must contain at least one letter or digit."
  fi

  project_classes="$(prompt_project_classes)"
  repo_path_states="$(collect_repo_path_states "$project_classes")"
  project_type_code="$(prompt_project_type_code)"
  if ! project_type_label="$(project_type_label_for_code "$project_type_code")"; then
    die "Unsupported project type code selected: $project_type_code"
  fi

  project_uuid="$(generate_project_uuid)"
  created_at="$(generate_created_at_utc)"
  project_folder_name="${feature_name_normalized}-${project_uuid}"
  project_folder_path="$projects_root/$project_folder_name"
  project_definition_path="$project_folder_path/$PROJECT_DEFINITION_FILE_NAME"

  if [[ -e "$project_folder_path" ]]; then
    die "Project folder already exists: $project_folder_path"
  fi

  if ! mkdir -p "$project_folder_path"; then
    die "Failed to create project folder: $project_folder_path"
  fi

  if ! cp "$template_path" "$project_definition_path"; then
    die "Failed to seed project definition from template: $template_path"
  fi

  if ! inject_project_bootstrap_into_definition "$project_definition_path" "$project_folder_name" "$project_classes" "$repo_path_states" "$project_type_code" "$project_type_label"; then
    die "Failed to write project classes and repo paths into project definition."
  fi

  if ! append_project_record "$metadata_path" "$project_folder_name" "$feature_name_raw" "$project_folder_name" "$created_at"; then
    die "Failed to append project record to ASDLC metadata."
  fi

  echo "Created ASDLC project folder: $project_folder_path"
  echo "Updated ASDLC metadata: $metadata_path"
}

main "$@"
