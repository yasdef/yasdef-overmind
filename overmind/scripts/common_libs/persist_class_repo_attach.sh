#!/usr/bin/env bash
set -euo pipefail

PROJECT_DEFINITION_FILE_NAME="init_progress_definition.yaml"

source "$(dirname "$0")/project_setup_common.sh"
source "$(dirname "$0")/class_repo_paths.sh"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

print_usage() {
  cat >&2 <<'USAGE'
Usage: persist_class_repo_attach.sh <project-path> <class> <repo-path>
USAGE
}

resolve_project_path() {
  local project_path="$1"
  local resolved_path=""

  [[ -d "$project_path" ]] || die "Project path directory not found: $project_path"
  if ! resolved_path="$(cd "$project_path" && pwd -P)"; then
    die "Failed to resolve project path: $project_path"
  fi
  [[ -f "$resolved_path/$PROJECT_DEFINITION_FILE_NAME" ]] || die "Project path must contain $PROJECT_DEFINITION_FILE_NAME: $project_path"
  printf '%s' "$resolved_path"
}

resolve_git_repo_path() {
  local repo_path="$1"
  local resolved_path=""

  if [[ -z "${repo_path//[[:space:]]/}" ]]; then
    die "Repo path cannot be empty."
  fi
  [[ -d "$repo_path" ]] || die "Repo path is not a directory: $repo_path"
  [[ -e "$repo_path/.git" ]] || die "Repo path must contain .git: $repo_path"
  if ! resolved_path="$(cd "$repo_path" && pwd -P)"; then
    die "Failed to resolve repo path: $repo_path"
  fi
  printf '%s' "$resolved_path"
}

persist_class_attach() {
  local definition_path="$1"
  local class_name="$2"
  local resolved_repo_path="$3"
  local escaped_path=""
  local tmp_file=""
  local awk_rc=0

  escaped_path="$(escape_yaml_double_quoted_value "$resolved_repo_path")"

  if ! tmp_file="$(mktemp)"; then
    die "Failed to create temporary file for definition update."
  fi

  set +e
  awk -v target_class="$class_name" -v escaped_path="$escaped_path" '
    BEGIN {
      in_class_repo_paths = 0
      in_target_class = 0
      found_class = 0
    }
    /^  class_repo_paths:[[:space:]]*$/ {
      in_class_repo_paths = 1
      print
      next
    }
    in_class_repo_paths && /^[^ ]/ {
      in_class_repo_paths = 0
      in_target_class = 0
      print
      next
    }
    in_class_repo_paths && /^    [a-z][a-zA-Z_]*:[[:space:]]*$/ {
      line = $0
      sub(/^    /, "", line)
      sub(/:[[:space:]]*$/, "", line)
      in_target_class = (line == target_class) ? 1 : 0
      print
      if (in_target_class) {
        found_class = 1
        print "      state: \"ready\""
        print "      path: \"" escaped_path "\""
        print "      policy: \"C\""
      }
      next
    }
    in_target_class && /^      (state|path|policy): / {
      next
    }
    { print }
    END {
      if (!found_class) {
        exit 3
      }
    }
  ' "$definition_path" >"$tmp_file"
  awk_rc=$?
  set -e

  if [[ "$awk_rc" -eq 3 ]]; then
    rm -f "$tmp_file"
    die "Class '$class_name' not found in class_repo_paths: $definition_path"
  fi
  if [[ "$awk_rc" -ne 0 ]]; then
    rm -f "$tmp_file"
    die "Failed to process definition update for class '$class_name': $definition_path"
  fi

  if ! mv "$tmp_file" "$definition_path"; then
    rm -f "$tmp_file"
    die "Failed to write updated definition: $definition_path"
  fi
}

main() {
  if [[ "$#" -ne 3 ]]; then
    print_usage
    exit 2
  fi

  local project_path="$1"
  local class_name="$2"
  local repo_path="$3"
  local resolved_project_path=""
  local resolved_repo_path=""

  resolved_project_path="$(resolve_project_path "$project_path")"
  resolved_repo_path="$(resolve_git_repo_path "$repo_path")"

  persist_class_attach "$resolved_project_path/$PROJECT_DEFINITION_FILE_NAME" "$class_name" "$resolved_repo_path"
  class_repo_paths_validate_coherence "$resolved_project_path/$PROJECT_DEFINITION_FILE_NAME" "$class_name"
  printf '%s\n' "$resolved_repo_path"
}

main "$@"
