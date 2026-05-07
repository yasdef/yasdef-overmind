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

extract_requirement_refs() {
  local requirements_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
/^###[[:space:]]+Requirement[[:space:]]+[0-9]+/ {
  line = $0
  sub(/^###[[:space:]]+Requirement[[:space:]]+/, "", line)
  split(line, parts, /[^0-9]/)
  if (parts[1] ~ /^[0-9]+$/) {
    print "REQ-" parts[1]
  }
  next
}
/^###[[:space:]]+NFR[[:space:]]+[0-9]+/ {
  line = $0
  sub(/^###[[:space:]]+NFR[[:space:]]+/, "", line)
  split(line, parts, /[^0-9]/)
  if (parts[1] ~ /^[0-9]+$/) {
    print "NFR-" parts[1]
  }
}
' "$requirements_path"
}

surface_has_applicable_entries() {
  local surface_path="$1"
  grep -Eq '^[[:space:]]*-[[:space:]]*applicability:[[:space:]]*applicable[[:space:]]*$' "$surface_path"
}

validate_content() {
  local target_path="$1"
  local active_classes_csv="$2"
  local requirement_refs_csv="$3"
  local required_repo_csv="$4"

  set +e
  awk \
    -v active_classes_csv="$active_classes_csv" \
    -v requirement_refs_csv="$requirement_refs_csv" \
    -v required_repo_csv="$required_repo_csv" '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function lower_trim(v) {
  return tolower(trim(v))
}
function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}
function is_unfilled(v, normalized) {
  normalized = toupper(trim(v))
  return (trim(v) == "" || normalized == "[UNFILLED]")
}
function register_csv(csv, target, items, item, i) {
  split(csv, items, /,/)
  for (i in items) {
    item = trim(items[i])
    if (item != "") {
      target[item] = 1
    }
  }
}
function parse_heading_value(line) {
  line = trim(line)
  sub(/^###[[:space:]]+[^:]+:[[:space:]]*/, "", line)
  return trim(line)
}
function scalar_value(line) {
  value = line
  sub(/^[[:space:]]*-[[:space:]]*[A-Za-z0-9_.-]+:[[:space:]]*/, "", value)
  return trim(value)
}
function slugify_component(name, slug) {
  slug = tolower(trim(name))
  gsub(/[^a-z0-9]+/, "-", slug)
  gsub(/^-+/, "", slug)
  gsub(/-+$/, "", slug)
  return slug
}
function validate_signal_consumer_repos(raw_value, signal_id,    list, i, repo_name, count) {
  split(raw_value, list, /,/)
  count = 0
  for (i in list) {
    repo_name = lower_trim(list[i])
    if (repo_name == "") {
      continue
    }
    count++
    if (!(repo_name in active_classes)) {
      fail_quality("planning signal " signal_id " references repo outside active project classes in consumer_repos: " repo_name)
    }
  }
  if (count < 1) {
    fail_quality("planning signal " signal_id " must reference at least one repo in consumer_repos")
  }
}
function validate_signal_source_evidence(raw_value, signal_id,    list, i, token, count, slug) {
  split(raw_value, list, /,/)
  count = 0
  for (i in list) {
    token = trim(list[i])
    if (token == "") {
      continue
    }
    count++
    if (token ~ /^REQ-[0-9]+$/ || token ~ /^NFR-[0-9]+$/) {
      if (!(token in valid_refs)) {
        fail_quality("planning signal " signal_id " references unknown source_evidence token " token)
      }
      continue
    }
    if (token ~ /^comp\/[a-z0-9][a-z0-9-]*$/) {
      slug = token
      sub(/^comp\//, "", slug)
      if (!(slug in component_slug_seen)) {
        fail_quality("planning signal " signal_id " references unknown source_evidence token " token)
      }
      continue
    }
    fail_quality("planning signal " signal_id " has invalid source_evidence token " token)
  }
  if (count < 1) {
    fail_quality("planning signal " signal_id " must include at least one source_evidence token")
  }
}
function validate_signal_block(    normalized_type, normalized_owner) {
  if (!in_signal_block) {
    return
  }
  if (is_unfilled(current_signal_heading)) fail_quality("planning signal block heading is empty in section 6")
  if (is_unfilled(current_signal_id)) fail_quality("planning signal " current_signal_heading " has unfilled key signal_id")
  if (is_unfilled(current_signal_type)) fail_quality("planning signal " current_signal_heading " has unfilled key signal_type")
  normalized_type = lower_trim(current_signal_type)
  if (normalized_type != "cross_repo_contract_lock") {
    fail_quality("planning signal " current_signal_id " uses unsupported signal_type: " current_signal_type)
  }
  if (is_unfilled(current_signal_owner_repo)) fail_quality("planning signal " current_signal_id " has unfilled key owner_repo")
  normalized_owner = lower_trim(current_signal_owner_repo)
  if (!(normalized_owner in active_classes)) {
    fail_quality("planning signal " current_signal_id " uses repo outside active project classes in owner_repo: " current_signal_owner_repo)
  }
  if (is_unfilled(current_signal_consumer_repos)) fail_quality("planning signal " current_signal_id " has unfilled key consumer_repos")
  if (is_unfilled(current_signal_required_artifact)) fail_quality("planning signal " current_signal_id " has unfilled key required_artifact")
  if (is_unfilled(current_signal_must_precede)) fail_quality("planning signal " current_signal_id " has unfilled key must_precede")
  if (is_unfilled(current_signal_output_requirements)) fail_quality("planning signal " current_signal_id " has unfilled key output_requirements")
  if (is_unfilled(current_signal_source_evidence)) fail_quality("planning signal " current_signal_id " has unfilled key source_evidence")
  if (current_signal_id in signal_id_seen) {
    fail_quality("duplicate planning signal id in section 6: " current_signal_id)
  } else {
    signal_id_seen[current_signal_id] = 1
  }
  validate_signal_consumer_repos(current_signal_consumer_repos, current_signal_id)
  validate_signal_source_evidence(current_signal_source_evidence, current_signal_id)
  signal_block_count++
  in_signal_block = 0
}
function validate_repo_block() {
  if (!in_repo_block) {
    return
  }
  if (is_unfilled(current_repo_name)) fail_quality("repository block heading is empty in section 3")
  if (is_unfilled(current_repo_class)) fail_quality("repository " current_repo_name " has unfilled key class")
  if (!(current_repo_class in active_classes)) fail_quality("repository " current_repo_name " uses repo outside active project classes: " current_repo_class)
  if (is_unfilled(current_repo_scope)) fail_quality("repository " current_repo_name " has unfilled key evidence_scope")
  if (is_unfilled(current_repo_paths)) fail_quality("repository " current_repo_name " has unfilled key primary_paths")
  if (is_unfilled(current_repo_findings)) fail_quality("repository " current_repo_name " has unfilled key key_findings")
  if (is_unfilled(current_repo_constraints)) fail_quality("repository " current_repo_name " has unfilled key constraints")
  if (is_unfilled(current_repo_gaps)) fail_quality("repository " current_repo_name " has unfilled key open_gaps")
  repo_block_count++
  repo_seen[current_repo_class]++
  in_repo_block = 0
}
function validate_requirement_block(    normalized_gap, normalized_repo_impact) {
  if (!in_requirement_block) {
    return
  }
  if (is_unfilled(current_requirement_ref)) fail_quality("requirement block heading is empty in section 4")
  if (!(current_requirement_ref in valid_refs)) fail_quality("requirement block references unknown requirement id " current_requirement_ref)
  if (current_requirement_ref in requirement_seen) fail_quality("duplicate requirement block for " current_requirement_ref)
  if (is_unfilled(current_requirement_summary)) fail_quality("requirement " current_requirement_ref " has unfilled key requirement_summary")
  if (!is_unfilled(current_requirement_state)) fail_quality("requirement " current_requirement_ref " uses conflated current_state: line — use transport_layer and user_reachable_surface subfields instead")
  if (is_unfilled(current_requirement_transport_layer)) fail_quality("requirement " current_requirement_ref " is missing transport_layer subfield")
  if (is_unfilled(current_requirement_user_reachable)) fail_quality("requirement " current_requirement_ref " is missing user_reachable_surface subfield")
  if (is_unfilled(current_requirement_gap_status)) fail_quality("requirement " current_requirement_ref " has unfilled key gap_status")
  if (is_unfilled(current_requirement_repo_impact)) fail_quality("requirement " current_requirement_ref " has unfilled key repo_impact")
  if (is_unfilled(current_requirement_evidence)) fail_quality("requirement " current_requirement_ref " has unfilled key evidence")
  if (is_unfilled(current_requirement_gap)) fail_quality("requirement " current_requirement_ref " has unfilled key gap_to_close")

  normalized_gap = lower_trim(current_requirement_gap_status)
  if (normalized_gap != "fully_implemented" && normalized_gap != "partially_implemented" && normalized_gap != "not_implemented" && normalized_gap != "unclear") {
    fail_quality("requirement " current_requirement_ref " has invalid gap_status: " current_requirement_gap_status)
  }

  normalized_repo_impact = lower_trim(current_requirement_repo_impact)
  if (normalized_repo_impact != "multiple") {
    if (!(normalized_repo_impact in active_classes)) {
      fail_quality("requirement " current_requirement_ref " has invalid repo_impact: " current_requirement_repo_impact)
    }
  }

  requirement_seen[current_requirement_ref] = 1
  requirement_block_count++
  in_requirement_block = 0
}
function validate_component_requirement_refs(raw_value, repo_name, component_name,    temp, ref_count, ref) {
  temp = raw_value
  ref_count = 0
  while (match(temp, /(REQ|NFR)-[0-9]+/)) {
    ref = substr(temp, RSTART, RLENGTH)
    ref_count++
    if (!(ref in valid_refs)) {
      fail_quality("component " component_name " in repo " repo_name " references unknown requirement id " ref)
    }
    temp = substr(temp, RSTART + RLENGTH)
  }
  if (ref_count == 0) {
    fail_quality("component " component_name " in repo " repo_name " must reference at least one REQ-* or NFR-* id")
  }
}
function validate_component_block(    normalized_repo, normalized_kind, component_slug) {
  if (!in_component_block) {
    return
  }
  if (is_unfilled(current_component_name)) fail_quality("component block heading is empty in section 5")
  if (is_unfilled(current_component_repo)) fail_quality("component " current_component_name " has unfilled key repo")
  normalized_repo = lower_trim(current_component_repo)
  if (!(normalized_repo in active_classes)) fail_quality("component " current_component_name " uses repo outside active project classes: " current_component_repo)
  if (is_unfilled(current_component_kind)) fail_quality("component " current_component_name " has unfilled key component_kind")
  normalized_kind = lower_trim(current_component_kind)
  if (normalized_kind != "controller" && normalized_kind != "service" && normalized_kind != "dto" && normalized_kind != "mapper" && normalized_kind != "domain" && normalized_kind != "persistence" && normalized_kind != "migration" && normalized_kind != "security" && normalized_kind != "config" && normalized_kind != "test" && normalized_kind != "ui" && normalized_kind != "state" && normalized_kind != "api_client" && normalized_kind != "other") {
    fail_quality("component " current_component_name " has invalid component_kind: " current_component_kind)
  }
  if (is_unfilled(current_component_paths)) fail_quality("component " current_component_name " has unfilled key relevant_paths")
  if (is_unfilled(current_component_refs)) fail_quality("component " current_component_name " has unfilled key requirement_refs")
  if (is_unfilled(current_component_state)) fail_quality("component " current_component_name " has unfilled key current_state")
  if (is_unfilled(current_component_required)) fail_quality("component " current_component_name " has unfilled key required_behavior")
  if (is_unfilled(current_component_gap)) fail_quality("component " current_component_name " has unfilled key gap_to_close")
  if (is_unfilled(current_component_dependency)) fail_quality("component " current_component_name " has unfilled key dependency_notes")
  if (is_unfilled(current_component_evidence)) fail_quality("component " current_component_name " has unfilled key evidence")
  validate_component_requirement_refs(current_component_refs, normalized_repo, current_component_name)
  component_slug = slugify_component(current_component_name)
  if (component_slug != "") {
    component_slug_seen[component_slug] = 1
  }
  component_seen[normalized_repo]++
  component_block_count++
  in_component_block = 0
}
BEGIN {
  has_errors = 0
  has_unfilled = 0
  section = ""

  register_csv(active_classes_csv, active_classes)
  register_csv(requirement_refs_csv, valid_refs)
  register_csv(required_repo_csv, repos_requiring_components)

  saw_section_1 = 0
  saw_section_2 = 0
  saw_section_3 = 0
  saw_section_4 = 0
  saw_section_5 = 0
  saw_section_6 = 0
  saw_section_7 = 0

  feature_id = ""
  feature_title = ""
  project_type_code = ""
  source_requirements_ears = ""
  source_common_contract_definition = ""
  source_surface_map_artifacts = ""
  analyzed_repo_classes = ""
  last_updated = ""
  confidence_level = ""

  feature_summary = ""
  included_behavior = ""
  excluded_behavior = ""

  in_repo_block = 0
  in_requirement_block = 0
  in_component_block = 0
  in_signal_block = 0
  repo_block_count = 0
  requirement_block_count = 0
  component_block_count = 0
  signal_block_count = 0
  empty_marker_count = 0
  legacy_section6_count = 0
  section6_entry_count = 0
  risk_count = 0
  current_requirement_transport_layer = ""
  current_requirement_user_reachable = ""
  current_requirement_state = ""
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) {
    has_unfilled = 1
  }
}
/^##[[:space:]]+/ {
  validate_repo_block()
  validate_requirement_block()
  validate_component_block()
  validate_signal_block()

  heading = trim($0)
  section = ""
  if (heading ~ /^##[[:space:]]+1\.[[:space:]]+Document[[:space:]]+Meta[[:space:]]*$/) {
    section = "1"
    saw_section_1 = 1
  } else if (heading ~ /^##[[:space:]]+2\.[[:space:]]+Feature[[:space:]]+Scope[[:space:]]+and[[:space:]]+Inputs[[:space:]]*$/) {
    section = "2"
    saw_section_2 = 1
  } else if (heading ~ /^##[[:space:]]+3\.[[:space:]]+Repository[[:space:]]+Evidence[[:space:]]*$/) {
    section = "3"
    saw_section_3 = 1
  } else if (heading ~ /^##[[:space:]]+4\.[[:space:]]+Requirement[[:space:]]+Coverage[[:space:]]+and[[:space:]]+Gaps[[:space:]]*$/) {
    section = "4"
    saw_section_4 = 1
  } else if (heading ~ /^##[[:space:]]+5\.[[:space:]]+Impacted[[:space:]]+Components[[:space:]]*$/) {
    section = "5"
    saw_section_5 = 1
  } else if (heading ~ /^##[[:space:]]+6\.[[:space:]]+Cross-Repo[[:space:]]+Constraints[[:space:]]+and[[:space:]]+Planning[[:space:]]+Signals[[:space:]]*$/) {
    section = "6"
    saw_section_6 = 1
  } else if (heading ~ /^##[[:space:]]+7\.[[:space:]]+Known[[:space:]]+Risks[[:space:]]*\/[[:space:]]*Uncertainties[[:space:]]*$/) {
    section = "7"
    saw_section_7 = 1
  }
  next
}
/^### Repository:[[:space:]]+/ {
  validate_repo_block()
  validate_requirement_block()
  validate_component_block()
  validate_signal_block()
  in_repo_block = 1
  current_repo_name = parse_heading_value($0)
  current_repo_class = ""
  current_repo_scope = ""
  current_repo_paths = ""
  current_repo_findings = ""
  current_repo_constraints = ""
  current_repo_gaps = ""
  next
}
/^### Requirement:[[:space:]]+/ {
  validate_repo_block()
  validate_requirement_block()
  validate_component_block()
  validate_signal_block()
  in_requirement_block = 1
  current_requirement_ref = parse_heading_value($0)
  current_requirement_summary = ""
  current_requirement_state = ""
  current_requirement_transport_layer = ""
  current_requirement_user_reachable = ""
  current_requirement_gap_status = ""
  current_requirement_repo_impact = ""
  current_requirement_evidence = ""
  current_requirement_gap = ""
  next
}
/^### Component:[[:space:]]+/ {
  validate_repo_block()
  validate_requirement_block()
  validate_component_block()
  validate_signal_block()
  in_component_block = 1
  current_component_name = parse_heading_value($0)
  current_component_repo = ""
  current_component_kind = ""
  current_component_paths = ""
  current_component_refs = ""
  current_component_state = ""
  current_component_required = ""
  current_component_gap = ""
  current_component_dependency = ""
  current_component_evidence = ""
  next
}
/^### Planning Signal:[[:space:]]+/ {
  validate_repo_block()
  validate_requirement_block()
  validate_component_block()
  validate_signal_block()
  if (section != "6") {
    fail_quality("planning signal block is only allowed in section 6")
  }
  section6_entry_count++
  in_signal_block = 1
  current_signal_heading = parse_heading_value($0)
  current_signal_id = ""
  current_signal_type = ""
  current_signal_owner_repo = ""
  current_signal_consumer_repos = ""
  current_signal_required_artifact = ""
  current_signal_must_precede = ""
  current_signal_output_requirements = ""
  current_signal_source_evidence = ""
  next
}
/^[[:space:]]*-[[:space:]]*[A-Za-z0-9_.-]+:[[:space:]]*/ {
  line = $0
  key = trim(line)
  sub(/^[[:space:]]*-[[:space:]]*/, "", key)
  sub(/:.*/, "", key)
  value = scalar_value(line)

  if (section == "1") {
    if (key == "feature_id") feature_id = value
    else if (key == "feature_title") feature_title = value
    else if (key == "project_type_code") project_type_code = value
    else if (key == "source_requirements_ears") source_requirements_ears = value
    else if (key == "source_common_contract_definition") source_common_contract_definition = value
    else if (key == "source_surface_map_artifacts") source_surface_map_artifacts = value
    else if (key == "analyzed_repo_classes") analyzed_repo_classes = value
    else if (key == "last_updated") last_updated = value
    else if (key == "confidence_level") confidence_level = value
  } else if (section == "2") {
    if (key == "feature_summary") feature_summary = value
    else if (key == "included_behavior") included_behavior = value
    else if (key == "excluded_behavior") excluded_behavior = value
  } else if (in_repo_block) {
    if (key == "class") current_repo_class = lower_trim(value)
    else if (key == "evidence_scope") current_repo_scope = value
    else if (key == "primary_paths") current_repo_paths = value
    else if (key == "key_findings") current_repo_findings = value
    else if (key == "constraints") current_repo_constraints = value
    else if (key == "open_gaps") current_repo_gaps = value
  } else if (in_requirement_block) {
    if (key == "requirement_summary") current_requirement_summary = value
    else if (key == "current_state") current_requirement_state = value
    else if (key == "transport_layer") current_requirement_transport_layer = value
    else if (key == "user_reachable_surface") current_requirement_user_reachable = value
    else if (key == "gap_status") current_requirement_gap_status = value
    else if (key == "repo_impact") current_requirement_repo_impact = value
    else if (key == "evidence") current_requirement_evidence = value
    else if (key == "gap_to_close") current_requirement_gap = value
  } else if (in_component_block) {
    if (key == "repo") current_component_repo = value
    else if (key == "component_kind") current_component_kind = value
    else if (key == "relevant_paths") current_component_paths = value
    else if (key == "requirement_refs") current_component_refs = value
    else if (key == "current_state") current_component_state = value
    else if (key == "required_behavior") current_component_required = value
    else if (key == "gap_to_close") current_component_gap = value
    else if (key == "dependency_notes") current_component_dependency = value
    else if (key == "evidence") current_component_evidence = value
  } else if (section == "6") {
    section6_entry_count++
    if (in_signal_block) {
      if (key == "signal_id") current_signal_id = value
      else if (key == "signal_type") current_signal_type = value
      else if (key == "owner_repo") current_signal_owner_repo = value
      else if (key == "consumer_repos") current_signal_consumer_repos = value
      else if (key == "required_artifact") current_signal_required_artifact = value
      else if (key == "must_precede") current_signal_must_precede = value
      else if (key == "output_requirements") current_signal_output_requirements = value
      else if (key == "source_evidence") current_signal_source_evidence = value
      else fail_quality("unsupported key in planning signal block: " key)
    } else if (key == "planning_signals") {
      if (value != "none") {
        fail_quality("section 6 empty marker must be exactly: - planning_signals: none")
      }
      empty_marker_count++
    } else if (key ~ /^constraint_[0-9]+$/ || key ~ /^prep_[0-9]+$/) {
      legacy_section6_count++
    } else {
      fail_quality("unsupported section 6 entry: " key)
    }
  } else if (section == "7") {
    if (key ~ /^risk_[0-9]+$/ && !is_unfilled(value)) risk_count++
  }
  next
}
END {
  validate_repo_block()
  validate_requirement_block()
  validate_component_block()
  validate_signal_block()

  if (has_unfilled) fail_quality("artifact still contains [UNFILLED] placeholders")
  if (!saw_section_1) fail_quality("missing section 1. Document Meta")
  if (!saw_section_2) fail_quality("missing section 2. Feature Scope and Inputs")
  if (!saw_section_3) fail_quality("missing section 3. Repository Evidence")
  if (!saw_section_4) fail_quality("missing section 4. Requirement Coverage and Gaps")
  if (!saw_section_5) fail_quality("missing section 5. Impacted Components")
  if (!saw_section_6) fail_quality("missing section 6. Cross-Repo Constraints and Planning Signals")
  if (!saw_section_7) fail_quality("missing section 7. Known Risks / Uncertainties")

  if (is_unfilled(feature_id)) fail_quality("section 1 key feature_id is required")
  if (is_unfilled(feature_title)) fail_quality("section 1 key feature_title is required")
  if (is_unfilled(project_type_code)) fail_quality("section 1 key project_type_code is required")
  if (is_unfilled(source_requirements_ears)) fail_quality("section 1 key source_requirements_ears is required")
  if (is_unfilled(source_common_contract_definition)) fail_quality("section 1 key source_common_contract_definition is required")
  if (is_unfilled(source_surface_map_artifacts)) fail_quality("section 1 key source_surface_map_artifacts is required")
  if (is_unfilled(analyzed_repo_classes)) fail_quality("section 1 key analyzed_repo_classes is required")
  if (is_unfilled(last_updated)) fail_quality("section 1 key last_updated is required")
  if (is_unfilled(confidence_level)) fail_quality("section 1 key confidence_level is required")

  if (is_unfilled(feature_summary)) fail_quality("section 2 key feature_summary is required")
  if (is_unfilled(included_behavior)) fail_quality("section 2 key included_behavior is required")
  if (is_unfilled(excluded_behavior)) fail_quality("section 2 key excluded_behavior is required")

  if (repo_block_count < 1) fail_quality("section 3 must contain at least one repository block")
  if (requirement_block_count < 1) fail_quality("section 4 must contain at least one requirement block")
  if (component_block_count < 1) fail_quality("section 5 must contain at least one component block")
  if (legacy_section6_count > 0) fail_quality("section 6 uses retired loose-entry format (constraint_* / prep_*); use typed planning-signal blocks or - planning_signals: none")
  if (empty_marker_count > 1) fail_quality("section 6 empty marker appears more than once")
  if (empty_marker_count > 0 && signal_block_count > 0) fail_quality("section 6 cannot mix typed planning-signal blocks with - planning_signals: none")
  if (section6_entry_count < 1) fail_quality("section 6 must contain typed planning-signal entries or the empty marker line")
  if (empty_marker_count < 1 && signal_block_count < 1) fail_quality("section 6 must contain at least one typed planning-signal block or - planning_signals: none")
  if (risk_count < 1) fail_quality("section 7 must contain at least one explicit risk_N entry")

  for (repo_name in active_classes) {
    if (!(repo_name in repo_seen) || repo_seen[repo_name] < 1) {
      fail_quality("active repo class " repo_name " must have a repository evidence block in section 3")
    }
  }
  for (req_ref in valid_refs) {
    if (!(req_ref in requirement_seen)) {
      fail_quality("section 4 is missing requirement block for " req_ref)
    }
  }
  for (repo_name in repos_requiring_components) {
    if (!(repo_name in component_seen) || component_seen[repo_name] < 1) {
      fail_quality("repo " repo_name " has applicable touched surfaces but no impacted component block is allocated to it")
    }
  }

  if (has_errors) {
    exit 1
  }
  print "quality gate passed: feature technical requirements structure is complete"
}
' "$target_path"
  local status=$?
  set -e

  return "$status"
}

main() {
  require_command awk
  require_command sed
  require_command grep

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Usage: $(basename "$0") <technical-requirements-path>"
  fi

  local target_path=""
  local target_dir=""
  local project_dir=""
  local requirements_path=""
  local definition_path=""
  local active_classes_csv=""
  local requirement_refs_csv=""
  local required_repo_csv=""
  local parsed_classes=""
  local parsed_refs=""
  local class_name=""
  local normalized_class=""
  local surface_path=""
  local status=0
  local repo_name=""

  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target feature technical requirements artifact not found: $TARGET_RELATIVE_PATH"
  fi
  if [[ ! -s "$target_path" ]]; then
    echo "target feature technical requirements artifact is empty: $TARGET_RELATIVE_PATH"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  target_dir="$(cd "$(dirname "$target_path")" && pwd -P)"
  project_dir="$(cd "$target_dir/.." && pwd -P)"
  requirements_path="$target_dir/requirements_ears.md"
  definition_path="$project_dir/init_progress_definition.yaml"

  if [[ ! -f "$requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: $requirements_path"
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
        if [[ -n "$active_classes_csv" ]]; then
          active_classes_csv+=","
        fi
        active_classes_csv+="$normalized_class"
        ;;
    esac
  done <<<"$parsed_classes"

  if [[ -z "$active_classes_csv" ]]; then
    helper_fail "No supported repo classes found in $definition_path"
  fi

  if ! parsed_refs="$(extract_requirement_refs "$requirements_path" 2>/dev/null)"; then
    helper_fail "Failed to read requirement ids from $requirements_path"
  fi
  while IFS= read -r class_name; do
    class_name="$(trim_value "$class_name")"
    [[ -n "$class_name" ]] || continue
    if [[ -n "$requirement_refs_csv" ]]; then
      requirement_refs_csv+=","
    fi
    requirement_refs_csv+="$class_name"
  done <<<"$parsed_refs"

  if [[ -z "$requirement_refs_csv" ]]; then
    helper_fail "No requirement ids found in $requirements_path"
  fi

  IFS=',' read -r -a active_classes_array <<<"$active_classes_csv"
  for repo_name in "${active_classes_array[@]}"; do
    case "$repo_name" in
      backend)
        surface_path="$target_dir/project_surface_struct_resp_map_backend.md"
        ;;
      frontend)
        surface_path="$target_dir/project_surface_struct_resp_map_frontend.md"
        ;;
      mobile)
        surface_path="$target_dir/project_surface_struct_resp_map_mobile.md"
        ;;
      *)
        continue
        ;;
    esac

    if [[ ! -f "$surface_path" ]]; then
      helper_fail "Required surface-map artifact not found for active repo '$repo_name': $surface_path"
    fi

    if surface_has_applicable_entries "$surface_path"; then
      if [[ -n "$required_repo_csv" ]]; then
        required_repo_csv+=","
      fi
      required_repo_csv+="$repo_name"
    fi
  done

  validate_content "$target_path" "$active_classes_csv" "$requirement_refs_csv" "$required_repo_csv"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
