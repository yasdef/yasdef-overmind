#!/usr/bin/env bash
set -euo pipefail

ASDLC_PROJECTS_DIR_NAME="projects"
PROJECT_DEFINITION_FILE_NAME="init_progress_definition.yaml"

source "$(dirname "$0")/../common_libs/project_setup_common.sh"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Classic y/N confirmation; default No on empty, non-yes, or closed input (EOF).
prompt_yes_no() {
  local prompt_message="$1"
  local answer=""
  printf '%s ' "$prompt_message" >&2
  if ! read -r answer; then
    return 1
  fi
  case "$answer" in
  y | Y | yes | YES) return 0 ;;
  *) return 1 ;;
  esac
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

main() {
  require_command awk
  require_command find
  require_command node

  local script_dir=""
  local asdlc_root=""
  local projects_root=""
  local projects_list=""
  local project_id=""
  local definition_path=""
  local project_dir=""
  local overmind_cli=""

  script_dir="$(resolve_script_dir)"
  asdlc_root="$(resolve_asdlc_root_from_staged_path "$script_dir")"
  projects_root="$asdlc_root/$ASDLC_PROJECTS_DIR_NAME"

  [[ -d "$projects_root" ]] || die "Required directory not found: $projects_root"

  overmind_cli="$asdlc_root/.overmind/overmind.js"
  [[ -f "$overmind_cli" ]] || die "Bundled overmind CLI not found: $overmind_cli"

  projects_list="$(discover_projects "$projects_root")"

  prompt_project_selection "$projects_list"
  project_id="$_SELECTED_PROJECT_ID"
  definition_path="$_SELECTED_DEFINITION_PATH"
  project_dir="$(dirname "$definition_path")"

  # Deferred-class attachment now runs through the TypeScript `overmind project
  # reconcile` flow, which also performs a one-time contract reconciliation — this
  # is not just a repo attach. Make that explicit and confirm before delegating.
  echo "Updating class repositories runs the full project reconciliation flow, not just a repo attach." >&2
  echo "'overmind project reconcile' will:" >&2
  echo "  - prompt for each deferred class repository to attach," >&2
  echo "  - run a one-time contract reconciliation session over newly ready classes, and" >&2
  echo "  - offer to commit the reconciliation results." >&2
  if ! prompt_yes_no "Proceed with attach + full reconciliation for project '$project_id'? [y/N]"; then
    echo "Aborted: no changes made to project '$project_id'." >&2
    exit 0
  fi

  # The wrapper's sole responsibility is to hand off to the TypeScript flow. Project-level
  # type (project_type_code) is legacy and is intentionally not manipulated here, so the
  # reconcile flow's clean-worktree/commit unit is not violated by a later definition edit.
  node "$overmind_cli" project reconcile --path "$project_dir"
}

main "$@"
