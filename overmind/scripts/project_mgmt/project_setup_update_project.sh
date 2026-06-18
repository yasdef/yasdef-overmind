#!/usr/bin/env bash
set -euo pipefail

ASDLC_PROJECTS_DIR_NAME="projects"
PROJECT_DEFINITION_FILE_NAME="init_progress_definition.yaml"
PERSIST_CLASS_REPO_ATTACH_SCRIPT="$(dirname "$0")/../common_libs/persist_class_repo_attach.sh"

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
    die "Run this command from ASDLC staged path: <asdlc>/.commands/project_setup_update_project.sh"
  fi

  if ! asdlc_root="$(cd "$script_dir/.." && pwd)"; then
    die "Failed to resolve ASDLC root from staged command path: $script_dir"
  fi

  printf '%s' "$asdlc_root"
}

discover_projects() {
  local projects_root="$1"
  local yaml_file=""
  local entry=""
  local result=""

  while IFS= read -r yaml_file; do
    [[ -z "$yaml_file" ]] && continue
    entry="$(awk '
      /^  project_id:/ {
        line = $0
        sub(/^[[:space:]]*project_id:[[:space:]]*"/, "", line)
        sub(/"[[:space:]]*$/, "", line)
        project_id = line
      }
      /^  project_type_code:/ {
        line = $0
        sub(/^[[:space:]]*project_type_code:[[:space:]]*"/, "", line)
        sub(/"[[:space:]]*$/, "", line)
        type_code = line
      }
      END {
        if (project_id != "") printf "%s|%s|%s\n", project_id, type_code, FILENAME
      }
    ' "$yaml_file" 2>/dev/null || true)"
    if [[ -n "$entry" ]]; then
      result="${result}${result:+$'\n'}${entry}"
    fi
  done < <(find "$projects_root" -maxdepth 2 -mindepth 2 -name "$PROJECT_DEFINITION_FILE_NAME" 2>/dev/null | sort)

  printf '%s' "$result"
}

_SELECTED_PROJECT_ID=""
_SELECTED_DEFINITION_PATH=""

prompt_project_selection() {
  local projects_list="$1"
  local entries=()
  local entry=""
  local project_id=""
  local type_code=""
  local def_path=""
  local selection=""
  local index=1

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    entries+=("$entry")
  done <<<"$projects_list"

  if [[ "${#entries[@]}" -eq 0 ]]; then
    echo "No projects found." >&2
    exit 0
  fi

  while true; do
    echo "Select project to update:" >&2
    index=1
    for entry in "${entries[@]}"; do
      IFS='|' read -r project_id type_code def_path <<<"$entry"
      echo "$index. $project_id (type $type_code)" >&2
      ((index++)) || true
    done
    echo "q. Quit" >&2

    if ! read -r selection; then
      die "Failed to read project selection."
    fi

    case "$selection" in
    q|Q)
      exit 0
      ;;
    *)
      if [[ "$selection" =~ ^[0-9]+$ ]] && \
         [[ "$selection" -ge 1 ]] && \
         [[ "$selection" -le "${#entries[@]}" ]]; then
        entry="${entries[$((selection - 1))]}"
        IFS='|' read -r project_id type_code def_path <<<"$entry"
        _SELECTED_PROJECT_ID="$project_id"
        _SELECTED_DEFINITION_PATH="$def_path"
        return 0
      fi
      echo "Invalid selection. Enter a number between 1 and ${#entries[@]}, or q to quit." >&2
      ;;
    esac
  done
}

read_deferred_classes() {
  local definition_path="$1"
  awk '
    BEGIN { in_block = 0; current_class = "" }
    /^  class_repo_paths:[[:space:]]*$/ { in_block = 1; next }
    in_block && /^[^ ]/ { in_block = 0; current_class = "" }
    in_block && /^    [a-z][a-zA-Z_]*:[[:space:]]*$/ {
      line = $0
      sub(/^    /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      current_class = line
    }
    in_block && /^      state: "deferred"/ {
      if (current_class != "") print current_class
    }
  ' "$definition_path"
}

_SELECTED_CLASS=""

prompt_class_selection() {
  local deferred_classes="$1"
  local classes=()
  local class_name=""
  local selection=""

  while IFS= read -r class_name; do
    [[ -z "$class_name" ]] && continue
    classes+=("$class_name")
  done <<<"$deferred_classes"

  if [[ "${#classes[@]}" -eq 0 ]]; then
    echo "No deferred classes found. Nothing to add." >&2
    exit 0
  fi

  while true; do
    echo "Select class to add repo for:" >&2
    local i=1
    for class_name in "${classes[@]}"; do
      echo "$i. $class_name" >&2
      ((i++)) || true
    done
    echo "q. Quit" >&2

    if ! read -r selection; then
      die "Failed to read class selection."
    fi

    case "$selection" in
    q|Q)
      exit 0
      ;;
    *)
      if [[ "$selection" =~ ^[0-9]+$ ]] && \
         [[ "$selection" -ge 1 ]] && \
         [[ "$selection" -le "${#classes[@]}" ]]; then
        _SELECTED_CLASS="${classes[$((selection - 1))]}"
        return 0
      fi
      echo "Invalid selection. Enter a number between 1 and ${#classes[@]}, or q to quit." >&2
      ;;
    esac
  done
}

_RESOLVED_REPO_PATH=""

prompt_repo_path_with_quit() {
  local class_name="$1"
  local repo_path=""
  local resolved_repo_path=""

  while true; do
    echo "Enter repo path for $class_name (or q to quit):" >&2
    if ! read -r repo_path; then
      die "Failed to read repo path for $class_name."
    fi

    case "$repo_path" in
    q|Q)
      exit 0
      ;;
    esac

    if ! validate_repo_path "$repo_path"; then
      continue
    fi

    if [[ ! -e "$repo_path/.git" ]]; then
      echo "Repo path must contain .git: $repo_path" >&2
      continue
    fi

    if ! resolved_repo_path="$(resolve_repo_path "$repo_path")"; then
      echo "Failed to resolve repo path: $repo_path" >&2
      continue
    fi

    _RESOLVED_REPO_PATH="$resolved_repo_path"
    return 0
  done
}

assert_class_entry_is_deferred() {
  local definition_path="$1"
  local class_name="$2"

  local check_result=""
  check_result="$(awk -v target="$class_name" '
    BEGIN { in_block = 0; in_target = 0; found_class = 0; found_deferred = 0 }
    /^  class_repo_paths:[[:space:]]*$/ { in_block = 1; next }
    in_block && /^[^ ]/ { in_block = 0; in_target = 0 }
    in_block && /^    [a-z][a-zA-Z_]*:[[:space:]]*$/ {
      line = $0
      sub(/^    /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      in_target = (line == target) ? 1 : 0
      if (in_target) found_class = 1
    }
    in_target && /^      state: "deferred"/ { found_deferred = 1 }
    END {
      if (found_class && found_deferred) print "ok"
      else if (!found_class) print "not_found"
      else print "not_deferred"
    }
  ' "$definition_path")"

  case "$check_result" in
  "ok")
    return 0
    ;;
  "not_found")
    die "Class '$class_name' not found in class_repo_paths: $definition_path"
    ;;
  "not_deferred")
    die "Class '$class_name' does not have state 'deferred' — shape mismatch: $definition_path"
    ;;
  *)
    die "Unexpected assertion result for class '$class_name': $check_result"
    ;;
  esac
}

is_all_classes_ready() {
  local definition_path="$1"
  local deferred_count=""

  deferred_count="$(awk '
    BEGIN { in_block = 0; count = 0 }
    /^  class_repo_paths:[[:space:]]*$/ { in_block = 1; next }
    in_block && /^[^ ]/ { in_block = 0 }
    in_block && /^      state: "deferred"/ { count++ }
    END { print count }
  ' "$definition_path")"

  [[ "$deferred_count" -eq 0 ]]
}

read_project_type_code() {
  local definition_path="$1"
  awk '
    /^  project_type_code:/ {
      line = $0
      sub(/^[[:space:]]*project_type_code:[[:space:]]*"/, "", line)
      sub(/"[[:space:]]*$/, "", line)
      print line; exit
    }
  ' "$definition_path"
}

_RECLASSIFICATION_CODE=""

prompt_reclassification() {
  local current_type="$1"
  local current_label=""
  local selection=""

  if ! current_label="$(project_type_label_for_code "$current_type")"; then
    current_label="$current_type"
  fi

  echo "All class repos are now ready. Project type is currently $current_type ($current_label)." >&2

  while true; do
    echo "Reclassify?" >&2
    echo "1. B - Existing project with partial context" >&2
    echo "2. C - Existing project with code-first context" >&2
    echo "3. Keep type $current_type and finish" >&2

    if ! read -r selection; then
      die "Failed to read reclassification selection."
    fi

    case "$selection" in
    1)
      _RECLASSIFICATION_CODE="B"
      return 0
      ;;
    2)
      _RECLASSIFICATION_CODE="C"
      return 0
      ;;
    3|q|Q|"")
      _RECLASSIFICATION_CODE="$current_type"
      return 0
      ;;
    *)
      echo "Invalid selection. Enter 1, 2, 3, or q to keep type $current_type." >&2
      ;;
    esac
  done
}

update_project_type_code_and_label() {
  local definition_path="$1"
  local new_type_code="$2"
  local new_type_label="$3"
  local escaped_type_code=""
  local escaped_type_label=""
  local tmp_file=""

  escaped_type_code="$(escape_yaml_double_quoted_value "$new_type_code")"
  escaped_type_label="$(escape_yaml_double_quoted_value "$new_type_label")"

  if ! tmp_file="$(mktemp)"; then
    die "Failed to create temporary file for type update."
  fi

  if ! awk -v new_code="$escaped_type_code" -v new_label="$escaped_type_label" '
    /^  project_type_code: / {
      print "  project_type_code: \"" new_code "\""
      next
    }
    /^  project_type_label: / {
      print "  project_type_label: \"" new_label "\""
      next
    }
    { print }
  ' "$definition_path" >"$tmp_file"; then
    rm -f "$tmp_file"
    die "Failed to process type code update: $definition_path"
  fi

  if ! mv "$tmp_file" "$definition_path"; then
    rm -f "$tmp_file"
    die "Failed to write updated type code: $definition_path"
  fi
}

main() {
  require_command awk
  require_command mktemp
  require_command find

  local script_dir=""
  local asdlc_root=""
  local projects_root=""
  local projects_list=""
  local project_id=""
  local definition_path=""
  local deferred_classes=""
  local type_code=""
  local new_type_label=""

  script_dir="$(resolve_script_dir)"
  asdlc_root="$(resolve_asdlc_root_from_staged_path "$script_dir")"
  projects_root="$asdlc_root/$ASDLC_PROJECTS_DIR_NAME"

  [[ -d "$projects_root" ]] || die "Required directory not found: $projects_root"

  projects_list="$(discover_projects "$projects_root")"

  prompt_project_selection "$projects_list"
  project_id="$_SELECTED_PROJECT_ID"
  definition_path="$_SELECTED_DEFINITION_PATH"

  deferred_classes="$(read_deferred_classes "$definition_path")"

  prompt_class_selection "$deferred_classes"
  local chosen_class="$_SELECTED_CLASS"

  prompt_repo_path_with_quit "$chosen_class"
  local resolved_repo_path="$_RESOLVED_REPO_PATH"

  assert_class_entry_is_deferred "$definition_path" "$chosen_class"
  [[ -x "$PERSIST_CLASS_REPO_ATTACH_SCRIPT" ]] || die "Required command lib not found or not executable: $PERSIST_CLASS_REPO_ATTACH_SCRIPT"
  "$PERSIST_CLASS_REPO_ATTACH_SCRIPT" "$(dirname "$definition_path")" "$chosen_class" "$resolved_repo_path" >/dev/null

  echo "Repo path for class '$chosen_class' in project '$project_id' updated to: $resolved_repo_path" >&2

  type_code="$(read_project_type_code "$definition_path")"

  if [[ "$type_code" == "A" ]] && is_all_classes_ready "$definition_path"; then
    prompt_reclassification "$type_code"
    local new_type_code="$_RECLASSIFICATION_CODE"
    if [[ "$new_type_code" != "$type_code" ]]; then
      if ! new_type_label="$(project_type_label_for_code "$new_type_code")"; then
        die "Unsupported project type code: $new_type_code"
      fi
      update_project_type_code_and_label "$definition_path" "$new_type_code" "$new_type_label"
      echo "Project reclassified to type $new_type_code ($new_type_label)." >&2
      echo "Note: existing type-A artifacts (stack blueprints, contract documents, surface maps) under the project tree are not removed by this script and may need to be regenerated." >&2
    fi
  fi
}

main "$@"
