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

extract_required_missing_surfaces() {
  local prerequisite_gaps_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function is_unfilled(v) {
  v = trim(v)
  if (v == "" || v == "[UNFILLED]" || tolower(v) == "none") return 1
  return 0
}
BEGIN {
  in_prereq = 0
  current_status = ""
  current_surface_kind = ""
  current_surface_identity = ""
}
function flush_prereq() {
  if (!in_prereq) return
  if ((current_status == "scheduled_in_slices" || current_status == "unmet") && current_surface_kind == "required_missing_user_reachable_surface" && !is_unfilled(current_surface_identity)) {
    print current_surface_identity
  }
  current_status = ""
  current_surface_kind = ""
  current_surface_identity = ""
  in_prereq = 0
}
/^#### Prerequisite:/ {
  flush_prereq()
  in_prereq = 1
  next
}
/^### Requirement:/ {
  flush_prereq()
  next
}
/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/, "", line)
  current_status = trim(line)
  next
}
/^[[:space:]]*-[[:space:]]*surface_kind:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*surface_kind:[[:space:]]*/, "", line)
  current_surface_kind = trim(line)
  next
}
/^[[:space:]]*-[[:space:]]*surface_identity:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0
  sub(/^[[:space:]]*-[[:space:]]*surface_identity:[[:space:]]*/, "", line)
  current_surface_identity = trim(line)
  next
}
END {
  flush_prereq()
}
' "$prerequisite_gaps_path" | sort -u
}

validate_content() {
  local target_path="$1"
  local active_classes_csv="$2"
  local required_surfaces_csv="${3:-}"
  local status=0

  set +e
  awk -v active_classes_csv="$active_classes_csv" -v required_surfaces_csv="$required_surfaces_csv" '
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
function canonical_surface(v) {
  v = tolower(trim(v))
  gsub(/sign[[:space:]-]*in|log[[:space:]-]*in|authenticate|authentication/, "login", v)
  gsub(/screen|view/, "page", v)
  gsub(/path|url|entry[[:space:]]*point|entry/, "route", v)
  gsub(/portal|console|dashboard/, "route", v)
  gsub(/container/, "shell", v)
  gsub(/search|find/, "lookup", v)
  gsub(/cli[[:space:]]+tool|admin[[:space:]]+tool|tooling[[:space:]]+command|tool[[:space:]]+command/, "command", v)
  gsub(/cli/, "command", v)
  gsub(/scheduled[[:space:]]+task|cron[[:space:]]+job/, "job", v)
  gsub(/rest[[:space:]]+endpoint|api[[:space:]]+endpoint|http[[:space:]]+endpoint/, "endpoint", v)
  gsub(/\b(post|get|put|patch|delete)[[:space:]]+\/[^[:space:]]+/, "endpoint", v)
  gsub(/[^a-z0-9]+/, " ", v)
  gsub(/[[:space:]]+/, " ", v)
  return trim(v)
}
function has_surface_terms(v) {
  v = canonical_surface(v)
  return (v ~ /(login|shell|route|lookup|page|workspace|form|command|job|endpoint|tool|link)/)
}
function looks_supporting_only(v) {
  v = tolower(v)
  has_support = (v ~ /(auth|token|api|contract|schema|state|coordination|middleware|service|repository|adapter|dto|mapper|payload)/)
  has_surface = (v ~ /(login|sign[ -]?in|route|page|screen|shell|workspace|entry|lookup|search|dashboard|portal|console|form|command|cli|job|endpoint|tool|http|deep link|deeplink)/)
  return (has_support && !has_surface)
}
function is_weak_content_token(token) {
  return (token ~ /^(operator|admin|user|protected|authenticated|workflow|surface|account)$/)
}
function surface_matches(required, candidate, req_tokens, cand_tokens, token, i, req_count, cand_count, shared_specific, required_specific, shared_content, required_content) {
  required = canonical_surface(required)
  candidate = canonical_surface(candidate)
  if (required == "" || candidate == "") return 0
  if (required == candidate || index(candidate, required) > 0 || index(required, candidate) > 0) return 1

  req_count = split(required, req_tokens, /[[:space:]]+/)
  cand_count = split(candidate, cand_tokens, /[[:space:]]+/)
  shared_specific = 0
  required_specific = 0

  delete cand_index
  for (i = 1; i <= cand_count; i++) {
    token = trim(cand_tokens[i])
    if (token != "") cand_index[token] = 1
  }
  for (i = 1; i <= req_count; i++) {
    token = trim(req_tokens[i])
    if (token == "") continue
    if (token ~ /^(login|shell|route|lookup|command|job|endpoint|tool)$/) {
      required_specific++
      if (token in cand_index) shared_specific++
      continue
    }
    if (token ~ /^(page|form|link)$/ || is_weak_content_token(token)) continue
    required_content++
    if (token in cand_index) shared_content++
  }
  if (required_specific > 0) {
    if (required_content > 0) return (shared_specific > 0 && shared_content > 0)
    return (shared_specific > 0)
  }

  if (shared_content >= 2) return 1
  return 0
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
function finalize_slice(evidence_line, tokens, token, i, token_count, kind_key, kind_value, signal_ref_key, signal_ref_value) {
  if (current_slice == 0) {
    return
  }

  required_slice_fields[1] = "repo"
  required_slice_fields[2] = "status"
  required_slice_fields[3] = "objective"
  required_slice_fields[4] = "first_increment"
  required_slice_fields[5] = "prerequisites"
  required_slice_fields[6] = "preserved_operator_surface"
  required_slice_fields[7] = "evidence"

  for (i = 1; i <= 7; i++) {
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

  kind_key = current_slice "|kind"
  if (kind_key in slice_fields) {
    kind_value = tolower(normalize(slice_fields[kind_key]))
    if (kind_value == "coordination") {
      signal_ref_key = current_slice "|signal_ref"
      if (!(signal_ref_key in slice_fields) || trim(slice_fields[signal_ref_key]) == "" || toupper(trim(slice_fields[signal_ref_key])) == "[UNFILLED]") {
        fail_quality("slice " current_slice " has kind: coordination but signal_ref is missing or empty")
      }
    }
  }

  if (slice_bullet_count[current_slice] < 2) {
    fail_quality("slice " current_slice " must include at least 2 concrete checklist bullets")
  }

  preserved_surface = trim(slice_fields[current_slice "|preserved_operator_surface"])
  if (tolower(preserved_surface) != "none") {
    if (!has_surface_terms(preserved_surface)) {
      fail_quality("slice " current_slice " preserved_operator_surface is not operator-facing: " preserved_surface)
    }

    coverage_text = tolower(slice_heading[current_slice] " " slice_fields[current_slice "|objective"] " " slice_fields[current_slice "|first_increment"] " " slice_text[current_slice])
    if (looks_supporting_only(coverage_text)) {
      fail_quality("slice " current_slice " marks preserved_operator_surface but describes supporting-only scaffolding work")
    }

    covered_surface_count++
    covered_surfaces[covered_surface_count] = preserved_surface
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
  required_surface_count = 0
  covered_surface_count = 0

  register_csv(active_classes_csv, active_classes)
  if (trim(required_surfaces_csv) != "") {
    required_surface_count = split(required_surfaces_csv, required_surface_values, /,/)
  }
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
    slice_text[current_slice] = tolower(normalize($0))
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
    if (bullet_text != "") {
      slice_text[current_slice] = slice_text[current_slice] " " tolower(bullet_text)
    }
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

  if (required_surface_count > 0) {
    for (i = 1; i <= required_surface_count; i++) {
      required_surface = trim(required_surface_values[i])
      if (required_surface == "") continue
      matched = 0
      for (j = 1; j <= covered_surface_count; j++) {
        if (surface_matches(required_surface, covered_surfaces[j])) {
          matched = 1
          break
        }
      }
      if (!matched) {
        fail_quality("required missing operator-facing surface is not preserved by any slice: " required_surface)
      }
    }
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
  require_command awk
  require_command grep
  require_command sed

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Usage: $(basename "$0") <implementation-slices-path>"
  fi

  local target_path=""
  local target_dir=""
  local project_dir=""
  local requirements_path=""
  local technical_requirements_path=""
  local feature_contract_delta_path=""
  local definition_path=""
  local prerequisite_gaps_path=""
  local parsed_classes=""
  local required_surfaces_csv=""
  local parsed_required_surfaces=""
  local class_name=""
  local normalized_class=""
  local active_classes_csv=""

  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

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
  prerequisite_gaps_path="$target_dir/prerequisite_gaps.md"
  definition_path="$project_dir/init_progress_definition.yaml"

  if [[ ! -f "$requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: $requirements_path"
  fi
  if [[ ! -f "$technical_requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: $technical_requirements_path"
  fi
  if [[ ! -f "$feature_contract_delta_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: $feature_contract_delta_path"
  fi
  if [[ ! -f "$definition_path" ]]; then
    helper_fail "Required project definition not found for quality check: $definition_path"
  fi

  if ! parsed_classes="$(extract_meta_project_classes "$definition_path" 2>/dev/null)"; then
    helper_fail "Failed to read active project classes from $definition_path"
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
    helper_fail "No supported repo classes found in $definition_path"
  fi

  if [[ -f "$prerequisite_gaps_path" ]]; then
    if ! parsed_required_surfaces="$(extract_required_missing_surfaces "$prerequisite_gaps_path" 2>/dev/null)"; then
      helper_fail "Failed to read required missing operator-facing surfaces from $prerequisite_gaps_path"
    fi
    while IFS= read -r class_name; do
      class_name="$(trim_value "$class_name")"
      [[ -n "$class_name" ]] || continue
      append_csv_value required_surfaces_csv "$class_name"
    done <<<"$parsed_required_surfaces"
  fi

  if ! validate_content "$target_path" "$active_classes_csv" "$required_surfaces_csv"; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
