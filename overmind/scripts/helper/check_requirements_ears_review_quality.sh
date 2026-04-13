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
function normalize_state(v) {
  v = tolower(normalize(v))
  gsub(/[[:space:]]+/, " ", v)
  return v
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
  } else if (section_name == "3") {
    if (finding_count > 0) {
      finding_fields[finding_count "|" key] = value
    } else if (key == "no_findings") {
      no_findings = tolower(value)
      saw_no_findings = 1
    }
  }
  return 1
}
BEGIN {
  has_errors = 0
  has_unfilled = 0
  section = ""
  finding_count = 0
  no_findings = "false"
  saw_no_findings = 0
  escalated_count = 0

  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) {
    has_unfilled = 1
  }
}
/^##[[:space:]]+/ {
  heading = trim($0)
  section = ""

  if (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/) {
    section = "1"
    saw_section_1 = 1
  } else if (heading ~ /^##[[:space:]]+2\.[[:space:]]+Review[[:space:]]+Guidance[[:space:]]*$/) {
    section = "2"
    saw_section_2 = 1
  } else if (heading ~ /^##[[:space:]]+3\.[[:space:]]+Findings[[:space:]]+Ledger[[:space:]]*$/) {
    section = "3"
    saw_section_3 = 1
  }
  next
}
/^###[[:space:]]+Finding[[:space:]]+[0-9]+[[:space:]]+[-:]/ {
  if (section == "3") {
    finding_count++
    finding_title[finding_count] = normalize($0)
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
  if (!saw_section_2) fail_quality("missing section: ## 2. Review Guidance")
  if (!saw_section_3) fail_quality("missing section: ## 3. Findings Ledger")

  required_meta[1] = "feature_id"
  required_meta[2] = "feature_title"
  required_meta[3] = "source_user_br_input"
  required_meta[4] = "source_requirements_ears"
  required_meta[5] = "review_status"
  required_meta[6] = "last_updated"
  for (i = 1; i <= 6; i++) {
    key = required_meta[i]
    if (!(key in meta) || is_unfilled(meta[key])) {
      fail_quality("missing or unfilled meta key: " key)
    }
  }

  review_status = tolower(meta["review_status"])
  if (review_status != "in_progress" && review_status != "complete") {
    fail_quality("review_status must be in_progress or complete")
  }

  if (finding_count == 0) {
    if (saw_no_findings == 0 || no_findings != "true") {
      fail_quality("findings ledger must declare - no_findings: true when no Finding blocks exist")
    }
    if (review_status != "complete") {
      fail_quality("review_status must be complete when no_findings is true")
    }
  }

  if (finding_count > 0 && no_findings == "true") {
    fail_quality("no_findings must not be true when Finding blocks are present")
  }

  for (f = 1; f <= finding_count; f++) {
    required_finding_field[1] = "severity"
    required_finding_field[2] = "state"
    required_finding_field[3] = "source_feature_story_reference"
    required_finding_field[4] = "related_requirement_targets"
    required_finding_field[5] = "gap_summary"
    required_finding_field[6] = "recommendation"
    required_finding_field[7] = "suggested_ears_change"
    required_finding_field[8] = "user_prompt"
    required_finding_field[9] = "user_response"
    required_finding_field[10] = "resolution_notes"

    for (k = 1; k <= 10; k++) {
      key = required_finding_field[k]
      composite = f "|" key
      if (!(composite in finding_fields) || is_unfilled(finding_fields[composite])) {
        fail_quality("finding block " f " missing or unfilled key: " key)
      }
    }

    severity = normalize(finding_fields[f "|severity"])
    if (severity != "High" && severity != "Medium" && severity != "Low") {
      fail_quality("finding block " f " has invalid severity: " severity)
    }

    state = normalize_state(finding_fields[f "|state"])
    if (state != "escalated" && state != "added to ears" && state != "rejected" && state != "postponed") {
      fail_quality("finding block " f " has invalid state: " finding_fields[f "|state"])
    }
    if (state == "escalated") {
      escalated_count++
    }
  }

  if (review_status == "complete" && escalated_count > 0) {
    fail_quality("review_status is complete but escalated findings remain")
  }

  if (review_status == "in_progress" && finding_count > 0 && escalated_count == 0) {
    fail_quality("review_status is in_progress but no escalated findings remain")
  }

  if (has_errors) {
    exit 1
  }

  print "quality gate passed: requirements ears review structure is complete"
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
    helper_fail "Missing target requirements ears review path argument."
  fi

  local workspace_root=""
  workspace_root="$(resolve_workspace_root)"

  local target_path=""
  target_path="$(resolve_target_path "$workspace_root" "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target requirements ears review artifact not found: $target_path"
  fi

  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target requirements ears review artifact is empty: $target_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  if ! validate_content "$target_path"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
