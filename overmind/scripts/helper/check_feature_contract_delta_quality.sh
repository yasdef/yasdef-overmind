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

  [[ -n "$target_input" ]] || helper_fail "Missing target artifact path."

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$target_input"
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
  } else if (section_name == "4") {
    handoff[key] = value
  } else if (section_name == "3") {
    if (key == "no_contract_delta_required") {
      no_contract_delta_required = tolower(value)
    } else if (current_delta_index > 0) {
      delta_fields[current_delta_index "|" key] = value
    }
  }
  return 1
}
BEGIN {
  has_errors = 0
  has_unfilled = 0
  section = ""
  current_delta_index = 0
  delta_count = 0
  no_contract_delta_required = ""

  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
  saw_section_4 = 0
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) {
    has_unfilled = 1
  }
}
/^##[[:space:]]+/ {
  heading = trim($0)
  section = ""
  current_delta_index = 0

  if (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/) {
    section = "1"
    saw_section_1 = 1
  } else if (heading ~ /^##[[:space:]]+2\.[[:space:]]+Delta[[:space:]]+Summary[[:space:]]*$/) {
    section = "2"
    saw_section_2 = 1
  } else if (heading ~ /^##[[:space:]]+3\.[[:space:]]+Contract[[:space:]]+Delta[[:space:]]+Items[[:space:]]*$/) {
    section = "3"
    saw_section_3 = 1
  } else if (heading ~ /^##[[:space:]]+4\.[[:space:]]+Track[[:space:]]+Handoff[[:space:]]+Signals[[:space:]]*$/) {
    section = "4"
    saw_section_4 = 1
  }
  next
}
/^###[[:space:]]+Delta[[:space:]]+[0-9]+:[[:space:]]*/ {
  if (section == "3") {
    delta_count++
    current_delta_index = delta_count
    delta_title[current_delta_index] = normalize($0)
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
  if (has_unfilled) {
    fail_quality("artifact still contains [UNFILLED] placeholders")
  }

  if (!saw_section_1) fail_quality("missing section: ## 1. Document Meta")
  if (!saw_section_2) fail_quality("missing section: ## 2. Delta Summary")
  if (!saw_section_3) fail_quality("missing section: ## 3. Contract Delta Items")
  if (!saw_section_4) fail_quality("missing section: ## 4. Track Handoff Signals")

  required_meta[1] = "feature_id"
  required_meta[2] = "feature_title"
  required_meta[3] = "project_type_code"
  required_meta[4] = "source_requirements_ears"
  required_meta[5] = "source_common_contract_definition"
  required_meta[6] = "delta_needed"
  required_meta[7] = "last_updated"
  for (i = 1; i <= 7; i++) {
    key = required_meta[i]
    if (!(key in meta) || is_unfilled(meta[key])) {
      fail_quality("missing or unfilled meta key: " key)
    }
  }

  delta_needed = tolower(meta["delta_needed"])
  if (delta_needed != "true" && delta_needed != "false") {
    fail_quality("delta_needed must be true or false")
  }

  if (delta_needed == "true") {
    if (delta_count < 1) {
      fail_quality("delta_needed is true but no Delta blocks were found in section 3")
    }
    if (no_contract_delta_required == "true") {
      fail_quality("no_contract_delta_required must not be true when delta_needed is true")
    }
    required_delta_field[1] = "delta_kind"
    required_delta_field[2] = "related_baseline_contract"
    required_delta_field[3] = "change_scope"
    required_delta_field[4] = "compatibility_impact"
    required_delta_field[5] = "verification_expectation"
    for (d = 1; d <= delta_count; d++) {
      for (k = 1; k <= 5; k++) {
        key = required_delta_field[k]
        composite = d "|" key
        if (!(composite in delta_fields) || is_unfilled(delta_fields[composite])) {
          fail_quality("delta block " d " missing or unfilled key: " key)
        }
      }
    }
  }

  if (delta_needed == "false") {
    if (no_contract_delta_required != "true") {
      fail_quality("delta_needed is false but section 3 does not declare - no_contract_delta_required: true")
    }
    if (delta_count > 0) {
      fail_quality("delta_needed is false but Delta blocks are still present")
    }
  }

  if (!("backend_handoff" in handoff) || is_unfilled(handoff["backend_handoff"])) {
    fail_quality("missing or unfilled handoff key: backend_handoff")
  }
  if (!("frontend_mobile_handoff" in handoff) || is_unfilled(handoff["frontend_mobile_handoff"])) {
    fail_quality("missing or unfilled handoff key: frontend_mobile_handoff")
  }

  if (has_errors) {
    exit 1
  }

  print "quality gate passed: feature contract delta structure is complete"
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
    helper_fail "Missing target feature contract delta path argument."
  fi

  local target_path=""
  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target feature contract delta artifact not found: $target_path"
  fi

  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target feature contract delta artifact is empty: $target_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  if ! validate_content "$target_path"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi

  exit 0
}

main "$@"
