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

resolve_target_path() {
  local target_input="$1"

  [[ -n "$target_input" ]] || helper_fail "Missing target project stack blueprint path argument."

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$target_input"
}

detect_peer_presence() {
  local target_path="$1"
  local target_dir=""
  local target_basename=""
  local backend_count=0
  local frontend_count=0
  local mobile_count=0
  local sibling=""

  target_dir="$(dirname "$target_path")"
  target_basename="$(basename "$target_path")"

  shopt -s nullglob
  for sibling in "$target_dir"/project_stack_blueprint_*.md; do
    case "$(basename "$sibling")" in
    project_stack_blueprint_backend.md) backend_count=$((backend_count + 1)) ;;
    project_stack_blueprint_frontend.md) frontend_count=$((frontend_count + 1)) ;;
    project_stack_blueprint_mobile.md) mobile_count=$((mobile_count + 1)) ;;
    esac
  done
  shopt -u nullglob

  case "$target_basename" in
  project_stack_blueprint_backend.md)
    if (( frontend_count > 0 || mobile_count > 0 || backend_count > 1 )); then
      printf '1\n'
    else
      printf '0\n'
    fi
    ;;
  *)
    printf '0\n'
    ;;
  esac
}

validate_content() {
  local target_path="$1"
  local peer_exists=""
  local status=0

  peer_exists="$(detect_peer_presence "$target_path")"

  set +e
  awk -v peer_exists="$peer_exists" '
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
  else if (section == "5") cross_class[key] = value
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
  saw_section_5 = 0
  in_comment = 0
  cross_class_placeholder = "<to be defined during first feature implementation plan>"
}
{
  line_text = $0
  if (in_comment) {
    if (line_text ~ /-->/) in_comment = 0
    next
  }
  if (line_text ~ /<!--/) {
    if (line_text !~ /-->/) in_comment = 1
    next
  }
  if (toupper(line_text) ~ /\[UNFILLED\]/) has_unfilled = 1
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
  } else if (heading ~ /^##[[:space:]]+5\.[[:space:]]+Cross-Class[[:space:]]+Transport\/Contract[[:space:]]+Approach[[:space:]]*$/) {
    section = "5"; saw_section_5 = 1
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
  expected_sections = 3 + (saw_section_5 ? 1 : 0)
  if (section_count != expected_sections) fail_quality("unexpected number of top-level sections")

  require_key("meta", "class", "meta key")
  require_key("meta", "repo_name", "meta key")
  require_key("meta", "service_name", "meta key")
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

  if (class == "backend") {
    if (peer_exists == "1") {
      if (!saw_section_5) fail_quality("missing section: ## 5. Cross-Class Transport/Contract Approach (required when in-project cross-class peer exists)")
    }
    if (saw_section_5) {
      if (!("transport_protocol" in cross_class) || cross_class["transport_protocol"] == "") fail_quality("missing or empty §5 field: transport_protocol")
      if (!("schema_format" in cross_class) || cross_class["schema_format"] == "") fail_quality("missing or empty §5 field: schema_format")
      if (!("user_approved" in cross_class) || cross_class["user_approved"] == "") fail_quality("missing or empty §5 field: user_approved")

      transport_is_placeholder = (cross_class["transport_protocol"] == cross_class_placeholder)
      schema_is_placeholder = (cross_class["schema_format"] == cross_class_placeholder)
      if (transport_is_placeholder != schema_is_placeholder) {
        fail_quality("§5 mixed state: transport_protocol and schema_format must both be concrete or both be the literal placeholder")
      }
      if (cross_class["user_approved"] == "true" && (transport_is_placeholder || schema_is_placeholder)) {
        fail_quality("§5 user_approved=true is invalid when transport_protocol or schema_format carries the placeholder")
      }
      if (cross_class["user_approved"] != "true" && cross_class["user_approved"] != "false") {
        fail_quality("§5 user_approved must be 'true' or 'false' (got: " cross_class["user_approved"] ")")
      }
    }
  } else if (saw_section_5) {
    fail_quality("§5 Cross-Class Transport/Contract Approach is forbidden in " class " blueprint (backend is the sole holder)")
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
  require_command awk
  require_command grep

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Missing target project stack blueprint path argument."
  fi

  local target_path=""
  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

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
