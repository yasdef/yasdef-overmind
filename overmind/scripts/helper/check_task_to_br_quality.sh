#!/usr/bin/env bash
set -euo pipefail

TARGET_RELATIVE_PATH="${1:-overmind/product/feature_br_summary.md}"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

resolve_target_path() {
  local target_input="$1"

  [[ -n "$target_input" ]] || die "Missing target artifact path."

  if [[ "$target_input" = /* ]]; then
    printf '%s\n' "$target_input"
    return 0
  fi

  printf '%s/%s\n' "$PWD" "$target_input"
}

main() {
  local target_path=""
  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"
  if [[ ! -f "$target_path" ]]; then
    die "Target BR summary not found: $target_path"
  fi

  local missing_data_path=""
  missing_data_path="$(dirname "$target_path")/missing_br_data.md"
  if [[ ! -f "$missing_data_path" ]]; then
    missing_data_path=""
  fi

  awk -v missing_data_path="$missing_data_path" '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function strip_quotes(v) {
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return v
}
function normalize(v) {
  return strip_quotes(trim(v))
}
function is_unfilled(v, u) {
  u = toupper(v)
  return (v == "" || u == "[UNFILLED]")
}
function add_missing(v) {
  missing_count++
  missing[missing_count] = v
}
BEGIN {
  in_meta = 0
  in_original_summary = 0
  in_business_goal = 0
  in_needs_validation = 0
  in_functional_requirements = 0
  in_business_rules = 0
  in_open_questions = 0
  in_open_scope_boundaries = 0
  saw_meta = 0
  saw_original_summary = 0
  saw_business_goal = 0
  source_type_found = 0
  source_type_value = ""
  last_updated_found = 0
  last_updated_value = ""
  original_summary_filled = 0
  business_goal_filled = 0
  complete_fr_count = 0
  complete_br_count = 0
  non_rised_assumptions_needing_validation_found = 0
  non_rised_open_questions_found = 0
  non_rised_scope_points_found = 0
  md_has_rised_items = 0
  md_has_non_rised_items = 0
  md_in_unresolved_ledger = 0
  md_in_latest_answers = 0
  md_in_loop_decision = 0
  md_answers_found = 0
  md_answers_value = ""
  md_unresolved_after_stop_found = 0
  md_unresolved_after_stop_value = ""
  missing_count = 0
}
/^###[[:space:]]+/ {
  heading = trim($0)
  in_original_summary = (heading ~ /^###[[:space:]]+2\.1[[:space:]]+Original[[:space:]]+request[[:space:]]+summary[[:space:]]*$/)
  in_business_goal = (heading ~ /^###[[:space:]]+3\.1[[:space:]]+Business[[:space:]]+goal[[:space:]]*$/)
  in_needs_validation = (heading ~ /^###[[:space:]]+Needs[[:space:]]+validation[[:space:]]*$/)
  in_open_scope_boundaries = (heading ~ /^###[[:space:]]+5\.3[[:space:]]+Open[[:space:]]+scope[[:space:]]+boundaries[[:space:]]*$/)
  in_meta = 0
  if (in_original_summary) {
    saw_original_summary = 1
  }
  if (in_business_goal) {
    saw_business_goal = 1
  }
  next
}
/^##[[:space:]]+/ {
  heading = trim($0)
  in_meta = (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/)
  in_functional_requirements = (heading ~ /^##[[:space:]]+6\.[[:space:]]+Functional[[:space:]]+Requirements[[:space:]]*$/)
  in_business_rules = (heading ~ /^##[[:space:]]+7\.[[:space:]]+Business[[:space:]]+Rules[[:space:]]+and[[:space:]]+Decision[[:space:]]+Logic[[:space:]]*$/)
  in_open_questions = (heading ~ /^##[[:space:]]+15\.[[:space:]]+Open[[:space:]]+Questions[[:space:]]*$/)
  in_open_scope_boundaries = 0
  in_original_summary = 0
  in_business_goal = 0
  in_needs_validation = 0
  if (in_meta) {
    saw_meta = 1
  }
  next
}
{
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*/, "", line)
  colon_index = index(line, ":")
  if (colon_index <= 0) {
    next
  }

  key = trim(substr(line, 1, colon_index - 1))
  value = normalize(substr(line, colon_index + 1))
  if (key == "") {
    next
  }

  if (in_meta) {
    if (key == "source_type") {
      source_type_found = 1
      source_type_value = value
    }
    if (key == "last_updated") {
      last_updated_found = 1
      last_updated_value = value
    }
  }

  if (in_original_summary && key == "short summary" && !is_unfilled(value)) {
    original_summary_filled = 1
  }

  if (in_business_goal && key == "primary_business_goal" && !is_unfilled(value)) {
    business_goal_filled = 1
  }

  if (in_needs_validation && key == "assumptions_needing_validation" && !is_unfilled(value)) {
    normalized_assumption_value = tolower(value)
    if (normalized_assumption_value !~ /rised/) {
      non_rised_assumptions_needing_validation_found = 1
    }
  }

  if (in_functional_requirements && key ~ /^FR-[0-9]+$/ && !is_unfilled(value)) {
    complete_fr_count++
  }

  if (in_business_rules && key ~ /^BR-[0-9]+$/ && !is_unfilled(value)) {
    complete_br_count++
  }

  if (in_open_questions && !is_unfilled(value)) {
    normalized_value = tolower(value)
    if (normalized_value !~ /rised/) {
      non_rised_open_questions_found = 1
    }
  }

  if (in_open_scope_boundaries && key == "unclear_scope_points" && !is_unfilled(value)) {
    normalized_scope_value = tolower(value)
    if (normalized_scope_value !~ /rised/) {
      non_rised_scope_points_found = 1
    }
  }
}
END {
  if (missing_data_path != "") {
    while ((getline md_line < missing_data_path) > 0) {
      md_trimmed = trim(md_line)

      if (md_trimmed ~ /^##[[:space:]]+/) {
        md_in_unresolved_ledger = (md_trimmed ~ /^##[[:space:]]+3\.[[:space:]]+Unresolved[[:space:]]+Items[[:space:]]+Ledger[[:space:]]+\(Rised\)[[:space:]]*$/)
        md_in_latest_answers = (md_trimmed ~ /^##[[:space:]]+6\.[[:space:]]+Latest[[:space:]]+User[[:space:]]+Answers[[:space:]]*$/)
        md_in_loop_decision = (md_trimmed ~ /^##[[:space:]]+7\.[[:space:]]+Loop[[:space:]]+Decision[[:space:]]*$/)
        continue
      }

      if (md_in_unresolved_ledger && md_line ~ /^[[:space:]]*-[[:space:]]*rised_item_[0-9]+:[[:space:]]*/) {
        md_has_rised_items = 1
        md_lowered = tolower(md_line)
        if (md_lowered ~ /rised[[:space:]]*=[[:space:]]*false/ || md_lowered ~ /rised:[[:space:]]*false/) {
          md_has_non_rised_items = 1
        } else if (md_lowered !~ /rised[[:space:]]*=[[:space:]]*true/ && md_lowered !~ /rised:[[:space:]]*true/) {
          md_has_non_rised_items = 1
        }
      }

      md_key_line = md_line
      sub(/^[[:space:]]*-[[:space:]]*/, "", md_key_line)
      md_colon_index = index(md_key_line, ":")
      if (md_colon_index <= 0) {
        continue
      }

      md_key = trim(substr(md_key_line, 1, md_colon_index - 1))
      md_value = normalize(substr(md_key_line, md_colon_index + 1))
      if (md_key == "") {
        continue
      }

      if (md_in_latest_answers && md_key == "answers") {
        md_answers_found = 1
        md_answers_value = md_value
      }

      if (md_in_loop_decision && md_key == "unresolved_after_stop") {
        md_unresolved_after_stop_found = 1
        md_unresolved_after_stop_value = md_value
      }
    }
    close(missing_data_path)
  }

  if (!saw_meta) {
    add_missing("section ## 1. Document Meta is missing")
  } else {
    if (!source_type_found || is_unfilled(source_type_value)) {
      add_missing("## 1. Document Meta -> source_type is unfilled")
    } else {
      source_type_normalized = tolower(source_type_value)
      gsub(/[-_]+/, " ", source_type_normalized)
      if (source_type_normalized !~ /user[[:space:]]*input/) {
        add_missing("## 1. Document Meta -> source_type must include User input")
      }
    }

    if (!last_updated_found || is_unfilled(last_updated_value)) {
      add_missing("## 1. Document Meta -> last_updated is unfilled")
    } else if (last_updated_value !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
      add_missing("## 1. Document Meta -> last_updated must be YYYY-MM-DD")
    }
  }

  if (!saw_original_summary || !original_summary_filled) {
    add_missing("### 2.1 Original request summary -> short summary is unfilled")
  }

  if (!saw_business_goal || !business_goal_filled) {
    add_missing("### 3.1 Business goal -> primary_business_goal is unfilled")
  }

  if (complete_fr_count < 1) {
    add_missing("## 6. Functional Requirements -> at least one meaningful one-line FR item (`- FR-N: ...`) is required")
  }

  if (complete_br_count < 1) {
    add_missing("## 7. Business Rules and Decision Logic -> at least one meaningful one-line BR item (`- BR-N: ...`) is required")
  }

  if (non_rised_open_questions_found) {
    add_missing("## 15. Open Questions -> non-rised unresolved items must be moved to missing_br_data.md and marked rised")
  }

  if (non_rised_assumptions_needing_validation_found) {
    add_missing("### Needs validation -> non-rised assumptions_needing_validation must be moved to missing_br_data.md and marked rised")
  }

  if (non_rised_scope_points_found) {
    add_missing("### 5.3 Open scope boundaries -> non-rised unclear_scope_points must be moved to missing_br_data.md and marked rised")
  }

  if (md_has_rised_items) {
    if (md_has_non_rised_items) {
      add_missing("missing_br_data.md -> unresolved ledger contains non-rised items; continue questioning until every rised_item_N is rised=true")
    }
    if (!md_answers_found || is_unfilled(md_answers_value)) {
      add_missing("missing_br_data.md -> unresolved rised items exist but ## 6. Latest User Answers -> answers is [UNFILLED]")
    }
    if (!md_unresolved_after_stop_found || is_unfilled(md_unresolved_after_stop_value)) {
      add_missing("missing_br_data.md -> unresolved rised items exist but ## 7. Loop Decision -> unresolved_after_stop is [UNFILLED]")
    }
  }

  if (missing_count > 0) {
    print "business-context gate failed"
    for (i = 1; i <= missing_count; i++) {
      print "missing: " missing[i]
    }
    exit 1
  }

  print "business-context gate passed"
}
  ' "$target_path"
}

main "$@"
