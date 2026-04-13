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

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

extract_meta_project_classes() {
  local definition_path="$1"

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
BEGIN {
  in_meta = 0
  in_classes = 0
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
  if (in_meta == 0) {
    next
  }

  if ($0 ~ /^[[:space:]]{2}project_classes:[[:space:]]*\[[^]]*\][[:space:]]*$/) {
    line = $0
    sub(/^[[:space:]]{2}project_classes:[[:space:]]*\[/, "", line)
    sub(/\][[:space:]]*$/, "", line)
    line = trim(line)
    if (line == "") {
      exit 0
    }
    count = split(line, parts, ",")
    for (i = 1; i <= count; i++) {
      value = strip_quotes(parts[i])
      if (value != "") {
        print value
      }
    }
    exit 0
  }

  if ($0 ~ /^[[:space:]]{2}project_classes:[[:space:]]*$/) {
    in_classes = 1
    next
  }

  if (in_classes == 1) {
    if ($0 ~ /^[[:space:]]{4}-[[:space:]]*/) {
      line = $0
      sub(/^[[:space:]]{4}-[[:space:]]*/, "", line)
      line = strip_quotes(line)
      if (line != "") {
        print line
      }
      next
    }
    in_classes = 0
  }
}
' "$definition_path"
}

append_csv_value() {
  local csv_name="$1"
  local value="$2"
  local current_csv=""

  [[ -n "$value" ]] || return 0

  current_csv="${!csv_name}"
  if [[ -n "$current_csv" ]]; then
    printf -v "$csv_name" '%s,%s' "$current_csv" "$value"
  else
    printf -v "$csv_name" '%s' "$value"
  fi
}

validate_content() {
  local target_path="$1"
  local active_classes_csv="$2"
  local status=0

  set +e
  awk -v active_classes_csv="$active_classes_csv" '
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
function register_csv(csv, target, parts, i, token, count) {
  count = split(csv, parts, /,/)
  for (i = 1; i <= count; i++) {
    token = trim(parts[i])
    if (token != "") {
      target[token] = 1
    }
  }
}
function parse_kv(line, section_name, key, value, colon_index) {
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  colon_index = index(line, ":")
  if (colon_index <= 0) {
    return 0
  }
  key = normalize(substr(line, 1, colon_index - 1))
  value = normalize(substr(line, colon_index + 1))

  if (section_name == "1") {
    meta[key] = value
  } else if (section_name == "3" && current_slice > 0) {
    slice_fields[current_slice "|" key] = value
  } else if (section_name == "4") {
    handoff[key] = value
  }
  return 1
}
function finalize_slice(evidence_line, tokens, token, i, token_count) {
  if (current_slice == 0) {
    return
  }

  required_slice_fields[1] = "repo"
  required_slice_fields[2] = "status"
  required_slice_fields[3] = "objective"
  required_slice_fields[4] = "first_increment"
  required_slice_fields[5] = "prerequisites"
  required_slice_fields[6] = "evidence"

  for (i = 1; i <= 6; i++) {
    key = required_slice_fields[i]
    composite = current_slice "|" key
    if (!(composite in slice_fields) || is_unfilled(slice_fields[composite])) {
      fail_quality("slice " current_slice " missing or unfilled key: " key)
    }
  }

  repo = tolower(slice_fields[current_slice "|repo"])
  if (!(repo in active_classes)) {
    fail_quality("slice " current_slice " uses repo outside active project classes: " repo)
  }
  if (repo != "backend" && repo != "frontend" && repo != "mobile") {
    fail_quality("slice " current_slice " has invalid repo value: " repo)
  }

  status_value = tolower(slice_fields[current_slice "|status"])
  if (status_value != "existing" && status_value != "planned") {
    fail_quality("slice " current_slice " has invalid status: " slice_fields[current_slice "|status"])
  }
  if (status_value == "planned") {
    planned_count++
  }

  evidence_line = slice_fields[current_slice "|evidence"]
  token_count = split(evidence_line, tokens, /,/)
  valid_token_count = 0
  for (i = 1; i <= token_count; i++) {
    token = trim(tokens[i])
    if (token == "") {
      fail_quality("slice " current_slice " has empty evidence token entry")
      continue
    }
    if (token ~ /^gap\/TECH_REQ-([0-9]+|NFR-[0-9]+)$/ || token ~ /^comp\/[a-z0-9]+(-[a-z0-9]+)*$/) {
      valid_token_count++
      continue
    }
    fail_quality("slice " current_slice " has invalid evidence token: " token)
  }
  if (valid_token_count == 0) {
    fail_quality("slice " current_slice " must include at least one valid evidence token")
  }

  if (slice_bullet_count[current_slice] < 2) {
    fail_quality("slice " current_slice " must include at least 2 concrete checklist bullets")
  }
}
BEGIN {
  has_errors = 0
  has_unfilled = 0
  section = ""
  current_slice = 0
  slice_total = 0
  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
  saw_section_4 = 0
  planned_count = 0

  register_csv(active_classes_csv, active_classes)
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) {
    has_unfilled = 1
  }
}
/^##[[:space:]]+/ {
  heading = trim($0)

  if (section == "3") {
    finalize_slice()
    current_slice = 0
  }

  section = ""
  if (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/) {
    section = "1"
    saw_section_1 = 1
  } else if (heading ~ /^##[[:space:]]+2\.[[:space:]]+Slice[[:space:]]+Planning[[:space:]]+Guardrails[[:space:]]*$/) {
    section = "2"
    saw_section_2 = 1
  } else if (heading ~ /^##[[:space:]]+3\.[[:space:]]+Slice[[:space:]]+Candidates[[:space:]]*$/) {
    section = "3"
    saw_section_3 = 1
  } else if (heading ~ /^##[[:space:]]+4\.[[:space:]]+Handoff[[:space:]]+To[[:space:]]+Ordered[[:space:]]+Plan[[:space:]]*$/) {
    section = "4"
    saw_section_4 = 1
  }
  next
}
/^###[[:space:]]+Slice[[:space:]]+[0-9]+:/ {
  if (section == "3") {
    finalize_slice()
    slice_total++
    current_slice = slice_total
    slice_heading[current_slice] = normalize($0)
    slice_bullet_count[current_slice] = 0
  }
  next
}
/^- \[[ xX]\][[:space:]]+/ {
  if (section == "3" && current_slice > 0) {
    slice_bullet_count[current_slice]++
    bullet_text = $0
    sub(/^- \[[ xX]\][[:space:]]+/, "", bullet_text)
    bullet_text = trim(bullet_text)
    if (bullet_text == "Plan and discuss the slice" || bullet_text == "Review slice readiness") {
      fail_quality("slice " current_slice " contains forbidden lifecycle boilerplate bullet: " bullet_text)
    }
  }
  next
}
{
  if (section == "") {
    next
  }
  parse_kv($0, section)
}
END {
  if (section == "3") {
    finalize_slice()
  }

  if (has_unfilled) {
    fail_quality("artifact still contains [UNFILLED] placeholders")
  }

  if (!saw_section_1) fail_quality("missing section: ## 1. Document Meta")
  if (!saw_section_2) fail_quality("missing section: ## 2. Slice Planning Guardrails")
  if (!saw_section_3) fail_quality("missing section: ## 3. Slice Candidates")
  if (!saw_section_4) fail_quality("missing section: ## 4. Handoff To Ordered Plan")

  required_meta[1] = "feature_id"
  required_meta[2] = "feature_title"
  required_meta[3] = "project_type_code"
  required_meta[4] = "source_requirements_ears"
  required_meta[5] = "source_technical_requirements"
  required_meta[6] = "source_feature_contract_delta"
  required_meta[7] = "source_surface_map_artifacts"
  required_meta[8] = "analyzed_repo_classes"
  required_meta[9] = "ordering_scope"
  required_meta[10] = "traceability_scope"
  required_meta[11] = "last_updated"
  required_meta[12] = "confidence_level"

  for (i = 1; i <= 12; i++) {
    key = required_meta[i]
    if (!(key in meta) || is_unfilled(meta[key])) {
      fail_quality("missing or unfilled meta key: " key)
    }
  }

  if (tolower(meta["ordering_scope"]) != "local_prerequisites_only") {
    fail_quality("ordering_scope must be local_prerequisites_only")
  }
  if (tolower(meta["traceability_scope"]) != "slice_level_only") {
    fail_quality("traceability_scope must be slice_level_only")
  }

  if (slice_total < 1) {
    fail_quality("slice candidates section must contain at least one Slice block")
  }
  if (planned_count < 1) {
    fail_quality("slice candidates must contain at least one planned slice")
  }

  required_handoff[1] = "ordering_intent"
  required_handoff[2] = "unresolved_ordering_questions"
  required_handoff[3] = "unresolved_traceability_questions"
  for (i = 1; i <= 3; i++) {
    key = required_handoff[i]
    if (!(key in handoff) || is_unfilled(handoff[key])) {
      fail_quality("missing or unfilled handoff key: " key)
    }
  }

  if (has_errors) {
    exit 1
  }

  print "quality gate passed: implementation slices structure is complete"
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
  require_command sed

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Usage: $(basename "$0") <implementation-slices-path>"
  fi

  local workspace_root=""
  local target_path=""
  local target_dir=""
  local project_dir=""
  local requirements_path=""
  local technical_requirements_path=""
  local feature_contract_delta_path=""
  local definition_path=""
  local parsed_classes=""
  local class_name=""
  local normalized_class=""
  local active_classes_csv=""

  workspace_root="$(resolve_workspace_root)"
  target_path="$(resolve_target_path "$workspace_root" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target implementation slices artifact not found: $TARGET_RELATIVE_PATH"
  fi
  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target implementation slices artifact is empty: $TARGET_RELATIVE_PATH"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  target_dir="$(cd "$(dirname "$target_path")" && pwd -P)"
  project_dir="$(cd "$target_dir/.." && pwd -P)"
  requirements_path="$target_dir/requirements_ears.md"
  technical_requirements_path="$target_dir/technical_requirements.md"
  feature_contract_delta_path="$target_dir/feature_contract_delta.md"
  definition_path="$project_dir/init_progress_definition.yaml"

  if [[ ! -f "$requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: ${requirements_path#$workspace_root/}"
  fi
  if [[ ! -f "$technical_requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: ${technical_requirements_path#$workspace_root/}"
  fi
  if [[ ! -f "$feature_contract_delta_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: ${feature_contract_delta_path#$workspace_root/}"
  fi
  if [[ ! -f "$definition_path" ]]; then
    helper_fail "Required project definition not found for quality check: ${definition_path#$workspace_root/}"
  fi

  if ! parsed_classes="$(extract_meta_project_classes "$definition_path" 2>/dev/null)"; then
    helper_fail "Failed to read active project classes from ${definition_path#$workspace_root/}"
  fi

  while IFS= read -r class_name; do
    class_name="$(trim_value "$class_name")"
    [[ -n "$class_name" ]] || continue
    normalized_class="$(printf '%s' "$class_name" | tr '[:upper:]' '[:lower:]')"
    case "$normalized_class" in
      backend | frontend | mobile)
        append_csv_value active_classes_csv "$normalized_class"
        ;;
    esac
  done <<<"$parsed_classes"

  if [[ -z "$active_classes_csv" ]]; then
    helper_fail "No supported repo classes found in ${definition_path#$workspace_root/}"
  fi

  if ! validate_content "$target_path" "$active_classes_csv"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
