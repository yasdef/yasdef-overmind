#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-}"

EXIT_HELPER_FAILURE=2

helper_fail() {
  echo "ERROR: $*" >&2
  exit "$EXIT_HELPER_FAILURE"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    helper_fail "Required command not found: $command_name"
  fi
}

resolve_workspace_root() {
  local script_dir=""
  local parent_dir=""
  local root=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    helper_fail "Failed to resolve script directory."
  fi

  parent_dir="$(dirname "$script_dir")"
  if [[ "$(basename "$script_dir")" == ".helper" && -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    printf '%s\n' "$parent_dir"
    return 0
  fi

  if ! root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    helper_fail "Not a git repository at script path: $script_dir"
  fi
  printf '%s\n' "$root"
}

resolve_target_path() {
  local workspace_root="$1"
  local target_input="$2"

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$workspace_root" "$target_input"
}

evaluate_trigger() {
  local target_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function strip_quotes(v) {
  v = trim(v)
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return trim(v)
}
function record_class(value) {
  if (value == "") return
  if (value == "backend") {
    has_backend = 1
    backend_count++
  } else if (value == "frontend" || value == "mobile") {
    has_other_class = 1
  }
}
BEGIN {
  in_meta = 0
  in_classes = 0
  project_type_code = ""
  has_backend = 0
  backend_count = 0
  has_other_class = 0
}
/^meta_info:[[:space:]]*$/ {
  in_meta = 1
  next
}
/^steps:[[:space:]]*$/ {
  if (in_meta == 1) {
    exit 0
  }
}
{
  if (in_meta == 0) next
  if ($0 ~ /^[[:space:]]{2}project_type_code:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]{2}project_type_code:[[:space:]]*/, "", line)
    project_type_code = strip_quotes(line)
    in_classes = 0
    next
  }
  if ($0 ~ /^[[:space:]]{2}project_classes:[[:space:]]*\[[^]]*\][[:space:]]*$/) {
    line = $0
    sub(/^[[:space:]]{2}project_classes:[[:space:]]*\[/, "", line)
    sub(/\][[:space:]]*$/, "", line)
    count = split(line, parts, ",")
    for (i = 1; i <= count; i++) {
      record_class(strip_quotes(parts[i]))
    }
    in_classes = 0
    next
  }
  if ($0 ~ /^[[:space:]]{2}project_classes:[[:space:]]*$/) {
    in_classes = 1
    next
  }
  if (in_classes == 1) {
    if ($0 ~ /^[[:space:]]{4}-[[:space:]]*/) {
      line = $0
      sub(/^[[:space:]]{4}-[[:space:]]*/, "", line)
      record_class(strip_quotes(line))
      next
    }
    in_classes = 0
  }
}
END {
  active = 0
  if (project_type_code == "A" && has_backend == 1) {
    if (has_other_class == 1 || backend_count > 1) {
      active = 1
    }
  }
  if (active == 1) {
    print "cross_class_peer_trigger: active"
  } else {
    print "cross_class_peer_trigger: inactive"
  }
}
' "$target_path"
}

main() {
  require_command awk

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Missing init_progress_definition.yaml path argument."
  fi

  local workspace_root=""
  workspace_root="$(resolve_workspace_root)"

  local target_path=""
  target_path="$(resolve_target_path "$workspace_root" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target init progress definition not found: $target_path"
  fi

  evaluate_trigger "$target_path"
}

main "$@"
