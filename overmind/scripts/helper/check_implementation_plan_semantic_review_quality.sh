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
  v = normalize(v)
  return (v == "" || toupper(v) == "[UNFILLED]" || v == "<decision and final outcome>")
}
function normalize_state(v) {
  v = tolower(normalize(v))
  gsub(/[[:space:]]+/, " ", v)
  return v
}
function normalize_bool(v) {
  v = tolower(normalize(v))
  gsub(/[[:space:]]+/, "", v)
  return v
}
function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}
function parse_kv(line, section_name, key, value, colon_index, composite_key) {
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
      composite_key = finding_count "|" key
      finding_fields[composite_key] = value
    } else if (key == "no_findings") {
      no_findings = normalize_bool(value)
      saw_no_findings = 1
    }
  }
  return 1
}
BEGIN {
  has_errors = 0
  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
  finding_count = 0
  saw_no_findings = 0
  no_findings = "false"
  section = ""
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
  }
  next
}
{
  if (section != "") {
    parse_kv($0, section)
  }
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
  required_meta[3] = "source_implementation_plan"
  required_meta[4] = "source_project_definition"
  required_meta[5] = "source_requirements_ears"
  required_meta[6] = "source_technical_requirements"
  required_meta[7] = "review_status"
  required_meta[8] = "last_updated"
  for (i = 1; i <= 8; i++) {
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

  terminal_count = 0
  for (f = 1; f <= finding_count; f++) {
    required_finding_field[1] = "severity"
    required_finding_field[2] = "finding_type"
    required_finding_field[3] = "state"
    required_finding_field[4] = "target_steps"
    required_finding_field[5] = "related_requirements"
    required_finding_field[6] = "related_evidence"
    required_finding_field[7] = "summary"
    required_finding_field[8] = "rationale"
    required_finding_field[9] = "recommendation"
    required_finding_field[10] = "user_selection"
    required_finding_field[11] = "plan_patch_summary"
    required_finding_field[12] = "resolution_notes"
    for (k = 1; k <= 12; k++) {
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

    finding_type = normalize(finding_fields[f "|finding_type"])
    if (finding_type != "step_scope_overlap" &&
        finding_type != "technical_gap_mix" &&
        finding_type != "dependency_ordering" &&
        finding_type != "requirement_grouping" &&
        finding_type != "delivered_surface_consumption_unclear" &&
        finding_type != "repo_scaffold_readiness_unclear") {
      fail_quality("finding block " f " has invalid finding_type: " finding_type)
    }

    state = normalize_state(finding_fields[f "|state"])
    if (state != "added" && state != "applied" && state != "rejected" && state != "postponed") {
      fail_quality("finding block " f " has invalid state: " finding_fields[f "|state"])
    }
    if (state != "added") {
      terminal_count++
    }

    if (finding_type == "delivered_surface_consumption_unclear" &&
        (state == "applied" || state == "rejected" || state == "postponed") &&
        is_unfilled(finding_fields[f "|resolution_notes"])) {
      fail_quality("finding block " f " (delivered_surface_consumption_unclear) has terminal state with empty resolution_notes")
    }

    if (finding_type == "repo_scaffold_readiness_unclear" &&
        (state == "applied" || state == "rejected" || state == "postponed") &&
        is_unfilled(finding_fields[f "|resolution_notes"])) {
      fail_quality("finding block " f " (repo_scaffold_readiness_unclear) has terminal state with empty resolution_notes")
    }

    if (finding_type == "delivered_surface_consumption_unclear" &&
        finding_fields[f "|related_requirements"] !~ /(REQ|NFR)-[0-9]+/) {
      fail_quality("finding block " f " (delivered_surface_consumption_unclear) must reference at least one REQ-* or NFR-* id in related_requirements")
    }
  }

  if (review_status == "complete" && finding_count > 0 && terminal_count != finding_count) {
    fail_quality("review_status is complete but non-terminal findings remain")
  }

  if (has_errors) {
    exit 1
  }

  print "quality gate passed: implementation plan semantic review structure is complete enough"
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
    helper_fail "Missing target implementation plan semantic review path argument."
  fi

  local target_path=""
  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target implementation plan semantic review artifact not found: $target_path"
  fi

  if ! grep -q '[^[:space:]]' "$target_path"; then
    echo "quality gate failed: target implementation plan semantic review artifact is empty: $target_path"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  if ! validate_content "$target_path"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
