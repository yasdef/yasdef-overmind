project_type_label_for_code() {
  case "$1" in
  A)
    printf '%s' "New project"
    ;;
  B)
    printf '%s' "Existing project with partial context"
    ;;
  C)
    printf '%s' "Existing project with code-first context"
    ;;
  *)
    return 1
    ;;
  esac
}

escape_yaml_double_quoted_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

validate_repo_path() {
  local path_value="$1"

  if [[ -z "${path_value//[[:space:]]/}" ]]; then
    echo "Repo path cannot be empty." >&2
    return 1
  fi

  if [[ ! -e "$path_value" ]]; then
    echo "Repo path does not exist: $path_value" >&2
    return 1
  fi

  if [[ ! -d "$path_value" ]]; then
    echo "Repo path is not a directory: $path_value" >&2
    return 1
  fi

  if [[ -z "$(ls -A "$path_value" 2>/dev/null)" ]]; then
    echo "Repo path must point to a non-empty directory: $path_value" >&2
    return 1
  fi

  return 0
}

resolve_repo_path() {
  local path_value="$1"
  local resolved_path=""

  if ! resolved_path="$(cd "$path_value" && pwd)"; then
    return 1
  fi
  printf '%s' "$resolved_path"
}
