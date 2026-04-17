#!/usr/bin/env bash
set -euo pipefail

TARGET_SURFACE_RELATIVE_PATH="${1:-}"

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

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    helper_fail "Failed to resolve script directory."
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

validate_surface_content() {
  local target_path="$1"
  local status=0

  set +e
  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function is_unfilled(v) {
  v = trim(v)
  return (v == "" || toupper(v) == "[UNFILLED]")
}
function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}
BEGIN {
  has_errors = 0
  in_meta = 0
  in_scope = 0
  current_layer = ""
  current_surface = ""

  saw_title = 0
  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
  saw_section_4 = 0
  saw_3_8 = 0

  required_meta["repo_name"] = 1
  required_meta["service_name"] = 1
  required_meta["project_type_code"] = 1
  required_meta["project_classes"] = 1
  required_meta["feature_id"] = 1
  required_meta["feature_title"] = 1
  required_meta["analyzed_repo_paths"] = 1
  required_meta["source_inputs_used"] = 1
  required_meta["last_updated"] = 1

  required_scope["feature_summary"] = 1
  required_scope["in_scope_feature_delta"] = 1
  required_scope["out_of_scope_notes"] = 1

  expected_layers["3.1 UI Composition Layer"] = 1
  expected_layers["3.2 Component Layer"] = 1
  expected_layers["3.3 State / Data Layer"] = 1
  expected_layers["3.4 API Integration Layer"] = 1
  expected_layers["3.5 UX Behavior Layer"] = 1
  expected_layers["3.6 Platform / Runtime Layer"] = 1
  expected_layers["3.7 Test Layer"] = 1

  expected_surfaces["4.1 UI Composition Surface"] = 1
  expected_surfaces["4.2 Component Surface"] = 1
  expected_surfaces["4.3 State / Data Surface"] = 1
  expected_surfaces["4.4 API Integration Surface"] = 1
  expected_surfaces["4.5 UX Behavior Surface"] = 1
  expected_surfaces["4.6 Platform / Runtime Surface"] = 1
  expected_surfaces["4.7 Test Surface"] = 1
  expected_surfaces["4.8 Unexpected Frontend / Mobile Surface"] = 1
}
{
  line = trim($0)

  if (toupper($0) ~ /\[UNFILLED\]/) {
    fail_quality("artifact still contains [UNFILLED] placeholders")
  }

  if (line == "# Project Surface Structure + Responsibility Map (Frontend / Mobile)") {
    saw_title = 1
  }

  if (line == "## 1. Document Meta") {
    saw_section_1 = 1
    in_meta = 1
    in_scope = 0
    current_layer = ""
    current_surface = ""
    next
  }
  if (line == "## 2. Feature Scope") {
    saw_section_2 = 1
    in_meta = 0
    in_scope = 1
    current_layer = ""
    current_surface = ""
    next
  }
  if (line == "## 3. Key Parts of Repo and Their Responsibilities") {
    saw_section_3 = 1
    in_meta = 0
    in_scope = 0
    current_layer = ""
    current_surface = ""
    next
  }
  if (line == "## 4. Frontend / Mobile Surfaces Touched With Current Feature") {
    saw_section_4 = 1
    in_meta = 0
    in_scope = 0
    current_layer = ""
    current_surface = ""
    next
  }

  if (line ~ /^### 3\.[0-9]+ /) {
    current_layer = substr(line, 5)
    current_surface = ""
    if (current_layer == "3.8 Another Layer(s)") {
      saw_3_8 = 1
    } else {
      seen_layer[current_layer] = 1
    }
    next
  }

  if (line ~ /^### 4\.[0-9]+ /) {
    current_surface = substr(line, 5)
    current_layer = ""
    seen_surface[current_surface] = 1
    next
  }

  if (current_layer != "" && line ~ /^-[[:space:]]+/) {
    content = line
    sub(/^-[[:space:]]+/, "", content)
    colon_idx = index(content, ":")
    if (colon_idx > 0) {
      key = trim(substr(content, 1, colon_idx - 1))
      value = trim(substr(content, colon_idx + 1))
      if (current_layer != "3.8 Another Layer(s)") {
        layer_value[current_layer, key] = value
      }
    }
    next
  }

  if (current_surface != "" && line ~ /^-[[:space:]]+/) {
    content = line
    sub(/^-[[:space:]]+/, "", content)
    colon_idx = index(content, ":")
    if (colon_idx > 0) {
      key = trim(substr(content, 1, colon_idx - 1))
      value = trim(substr(content, colon_idx + 1))
      surface_value[current_surface, key] = value
    }
    next
  }

  if (in_meta && line ~ /^-[[:space:]]+/) {
    content = line
    sub(/^-[[:space:]]+/, "", content)
    colon_idx = index(content, ":")
    if (colon_idx > 0) {
      key = trim(substr(content, 1, colon_idx - 1))
      value = trim(substr(content, colon_idx + 1))
      meta_value[key] = value
    }
    next
  }

  if (in_scope && line ~ /^-[[:space:]]+/) {
    content = line
    sub(/^-[[:space:]]+/, "", content)
    colon_idx = index(content, ":")
    if (colon_idx > 0) {
      key = trim(substr(content, 1, colon_idx - 1))
      value = trim(substr(content, colon_idx + 1))
      scope_value[key] = value
    }
    next
  }

}
END {
  if (!saw_title) fail_quality("unexpected title for frontend/mobile surface map")
  if (!saw_section_1) fail_quality("missing section ## 1. Document Meta")
  if (!saw_section_2) fail_quality("missing section ## 2. Feature Scope")
  if (!saw_section_3) fail_quality("missing section ## 3. Key Parts of Repo and Their Responsibilities")
  if (!saw_section_4) fail_quality("missing section ## 4. Frontend / Mobile Surfaces Touched With Current Feature")

  for (key in required_meta) {
    if (!(key in meta_value) || is_unfilled(meta_value[key])) {
      fail_quality("missing or empty meta field: " key)
    }
  }

  lower_classes = tolower(meta_value["project_classes"])
  if (lower_classes !~ /frontend/ && lower_classes !~ /mobile/) {
    fail_quality("project_classes must include frontend or mobile")
  }
  if (meta_value["project_type_code"] != "A" && meta_value["project_type_code"] != "B" && meta_value["project_type_code"] != "C") {
    fail_quality("project_type_code must be A, B, or C")
  }
  if (meta_value["last_updated"] !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
    fail_quality("last_updated must be YYYY-MM-DD")
  }

  for (key in required_scope) {
    if (!(key in scope_value) || is_unfilled(scope_value[key])) {
      fail_quality("missing or empty feature scope field: " key)
    }
  }

  for (layer in expected_layers) {
    if (!(layer in seen_layer)) {
      fail_quality("missing layer subsection: " layer)
      continue
    }
    if (is_unfilled(layer_value[layer, "responsibility_summary"])) {
      fail_quality("missing responsibility_summary in " layer)
    }
    if (is_unfilled(layer_value[layer, "main_repo_paths"])) {
      fail_quality("missing main_repo_paths in " layer)
    }
    if (is_unfilled(layer_value[layer, "key_components"])) {
      fail_quality("missing key_components in " layer)
    }
    if (is_unfilled(layer_value[layer, "transport_layer"])) {
      fail_quality("missing or blank transport_layer in " layer)
    }
    if (is_unfilled(layer_value[layer, "user_reachable_surface"])) {
      fail_quality("missing or blank user_reachable_surface in " layer)
    }
  }

  if (!saw_3_8) {
    fail_quality("missing subsection: 3.8 Another Layer(s)")
  }

  touched_surface_count = 0
  for (surface in expected_surfaces) {
    if (!(surface in seen_surface)) {
      fail_quality("missing surface subsection: " surface)
      continue
    }
    if (is_unfilled(surface_value[surface, "surface_summary"])) {
      fail_quality("missing surface_summary in " surface)
    }
    if (is_unfilled(surface_value[surface, "applicability"])) {
      fail_quality("missing applicability in " surface)
    }
    if (is_unfilled(surface_value[surface, "repo_paths"])) {
      fail_quality("missing repo_paths in " surface)
    }
    if (is_unfilled(surface_value[surface, "why_feature_touches_it"])) {
      fail_quality("missing why_feature_touches_it in " surface)
    }
    if (is_unfilled(surface_value[surface, "expected_changes"])) {
      fail_quality("missing expected_changes in " surface)
    }
    if (is_unfilled(surface_value[surface, "evidence"])) {
      fail_quality("missing evidence in " surface)
    }
    if (is_unfilled(surface_value[surface, "transport_layer"])) {
      fail_quality("missing or blank transport_layer in " surface)
    }
    if (is_unfilled(surface_value[surface, "user_reachable_surface"])) {
      fail_quality("missing or blank user_reachable_surface in " surface)
    }
    if (surface_value[surface, "applicability"] == "applicable") {
      touched_surface_count++
    }
  }

  if (touched_surface_count < 1) {
    fail_quality("at least one frontend/mobile surface should be marked applicable")
  }

  if (has_errors) {
    exit 1
  }
  print "quality gate passed: frontend/mobile repo surface map is complete enough"
}
' "$target_path"
  status=$?
  set -e

  case "$status" in
    0) return 0 ;;
    1) return "$EXIT_CONTENT_FAILURE" ;;
    *) helper_fail "Validation runtime failure for $target_path (awk exit $status)." ;;
  esac
}

main() {
  require_command git
  require_command awk
  require_command grep

  if [[ -z "$TARGET_SURFACE_RELATIVE_PATH" ]]; then
    helper_fail "Missing target artifact path argument. Usage: <surface-map-path>"
  fi

  local workspace_root=""
  workspace_root="$(resolve_workspace_root)"

  local surface_path=""
  surface_path="$(resolve_target_path "$workspace_root" "$TARGET_SURFACE_RELATIVE_PATH")"

  if [[ ! -f "$surface_path" ]]; then
    helper_fail "Target frontend/mobile surface map artifact not found: $surface_path"
  fi

  if ! grep -q '[^[:space:]]' "$surface_path"; then
    echo "quality gate failed: target frontend/mobile surface map artifact is empty: $surface_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  validate_surface_content "$surface_path"
}

main "$@"
