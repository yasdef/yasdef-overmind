#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-}"

EXIT_CONTENT_FAILURE=1
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

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    helper_fail "Failed to resolve script directory."
  fi

  parent_dir="$(dirname "$script_dir")"
  if [[ "$(basename "$script_dir")" == ".helper" && -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    printf '%s\n' "$parent_dir"
    return 0
  fi

  if ! git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null; then
    helper_fail "Not a git repository at script path: $script_dir"
  fi
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

validate_content() {
  local target_path="$1"
  local status=0

  set +e
  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function normalize(v) {
  v = trim(v)
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return trim(v)
}
function is_unfilled(v) {
  return (trim(v) == "" || toupper(trim(v)) == "[UNFILLED]")
}
function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}
function parse_kv(line, key, value, colon_index) {
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  colon_index = index(line, ":")
  if (colon_index <= 0) {
    return 0
  }
  key = normalize(substr(line, 1, colon_index - 1))
  value = normalize(substr(line, colon_index + 1))
  if (section == "1") meta[key] = value
  else if (section == "2") stack[key] = value
  else if (section == "3" && current_layer != "") layer[current_layer SUBSEP key] = value
  return 1
}
function require_key(map_name, key, label) {
  if (map_name == "meta") {
    if (!(key in meta) || is_unfilled(meta[key])) fail_quality("missing or unfilled " label ": " key)
  } else if (map_name == "stack") {
    if (!(key in stack) || is_unfilled(stack[key])) fail_quality("missing or unfilled " label ": " key)
  }
}
function require_layer_key(layer_name, key) {
  if (!((layer_name SUBSEP key) in layer) || is_unfilled(layer[layer_name SUBSEP key])) {
    fail_quality("missing or unfilled layer key for " layer_name ": " key)
  }
}
function add_required_layer(layer_name) {
  required_layers[layer_name] = 1
}
BEGIN {
  has_errors = 0
  has_unfilled = 0
  section = ""
  current_layer = ""
  section_count = 0
  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) has_unfilled = 1
}
/^##[[:space:]]+/ {
  heading = trim($0)
  section = ""
  current_layer = ""
  section_count++
  if (heading ~ /^##[[:space:]]+1\.[[:space:]]+Meta[[:space:]]*$/) {
    section = "1"; saw_section_1 = 1
  } else if (heading ~ /^##[[:space:]]+2\.[[:space:]]+Stack[[:space:]]+Choices[[:space:]]*$/) {
    section = "2"; saw_section_2 = 1
  } else if (heading ~ /^##[[:space:]]+3\.[[:space:]]+Layer[[:space:]]+Bindings[[:space:]]*$/) {
    section = "3"; saw_section_3 = 1
  } else {
    fail_quality("unexpected top-level section: " heading)
  }
  next
}
/^###[[:space:]]+/ {
  if (section != "3") next
  current_layer = trim($0)
  sub(/^###[[:space:]]+/, "", current_layer)
  seen_layers[current_layer] = 1
  next
}
{
  if (section == "") next
  parse_kv($0)
}
END {
  if (has_unfilled) fail_quality("artifact still contains [UNFILLED] placeholders")
  if (!saw_section_1) fail_quality("missing section: ## 1. Meta")
  if (!saw_section_2) fail_quality("missing section: ## 2. Stack Choices")
  if (!saw_section_3) fail_quality("missing section: ## 3. Layer Bindings")
  if (section_count != 3) fail_quality("expected exactly three top-level sections")

  require_key("meta", "class", "meta key")
  require_key("meta", "repo_name", "meta key")
  require_key("meta", "service_name", "meta key")
  require_key("meta", "planned_repo_path", "meta key")
  require_key("meta", "last_updated", "meta key")
  if (("last_updated" in meta) && !is_unfilled(meta["last_updated"]) && meta["last_updated"] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
    fail_quality("last_updated must use YYYY-MM-DD format")
  }

  class = meta["class"]
  if (class != "backend" && class != "frontend" && class != "mobile") {
    fail_quality("unsupported class value: " class " (allowed: backend, frontend, mobile)")
  }

  if (class == "backend") {
    require_key("meta", "group_id", "meta key")
    split("language framework build rdbms migrations async_messaging http_clients auth logging metrics tracing health deployment test_stack", required_stack, " ")
    add_required_layer("3.1 API"); add_required_layer("3.2 Service"); add_required_layer("3.3 Domain")
    add_required_layer("3.4 Persistence"); add_required_layer("3.5 Integration"); add_required_layer("3.6 Runtime / Ops"); add_required_layer("3.7 Test")
  } else if (class == "frontend") {
    require_key("meta", "group_id_or_package_root", "meta key")
    split("framework router state http styling auth_client env_validation deployment test", required_stack, " ")
    add_required_layer("3.1 UI Composition"); add_required_layer("3.2 Component"); add_required_layer("3.3 State / Data")
    add_required_layer("3.4 API Integration"); add_required_layer("3.5 UX Behavior"); add_required_layer("3.6 Platform / Runtime"); add_required_layer("3.7 Test")
  } else if (class == "mobile") {
    require_key("meta", "group_id_or_package_root", "meta key")
    split("platforms android_ui ios_ui navigation state http auth_client local_storage device_integration distribution test_stack", required_stack, " ")
    add_required_layer("3.1 UI Composition"); add_required_layer("3.2 Component"); add_required_layer("3.3 State / Data")
    add_required_layer("3.4 API Integration"); add_required_layer("3.5 UX Behavior"); add_required_layer("3.6 Platform / Runtime")
    add_required_layer("3.7 Native / Device Integration"); add_required_layer("3.8 Local Storage / Offline / Sync"); add_required_layer("3.9 Test")
  }

  for (idx in required_stack) {
    require_key("stack", required_stack[idx], "stack choice")
  }
  for (layer_name in required_layers) {
    if (!(layer_name in seen_layers)) fail_quality("missing layer block: " layer_name)
    require_layer_key(layer_name, "folder_paths")
    require_layer_key(layer_name, "archetypes")
    require_layer_key(layer_name, "user_reachable_pattern")
  }
  if (class == "backend" && ("3.5 Integration" in seen_layers)) {
    require_layer_key("3.5 Integration", "topics_convention")
  }
  for (layer_name in seen_layers) {
    if (!(layer_name in required_layers)) fail_quality("unexpected layer block: " layer_name)
  }

  if (has_errors) exit 1
  print "quality gate passed: project stack blueprint structure is complete"
}
' "$target_path"
  status=$?
  set -e

  case "$status" in
  0)
    return 0
    ;;
  1)
    return "$EXIT_CONTENT_FAILURE"
    ;;
  *)
    helper_fail "Validation runtime failure for $target_path (awk exit $status)."
    ;;
  esac
}

main() {
  require_command git
  require_command awk
  require_command grep

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Missing target project stack blueprint path argument."
  fi

  local workspace_root=""
  workspace_root="$(resolve_workspace_root)"

  local target_path=""
  target_path="$(resolve_target_path "$workspace_root" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target project stack blueprint artifact not found: $target_path"
  fi

  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target project stack blueprint artifact is empty: $target_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  if ! validate_content "$target_path"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
