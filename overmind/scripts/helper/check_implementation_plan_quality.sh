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
/^###[[:space:]]+/ {
  line = $0

  if (line ~ /^###[[:space:]]+Requirement[[:space:]]+[0-9]+/) {
    tmp = line
    sub(/^###[[:space:]]+Requirement[[:space:]]+/, "", tmp)
    split(tmp, parts, /[^0-9]/)
    if (parts[1] ~ /^[0-9]+$/) {
      ref = "REQ-" parts[1]
      if (!(ref in seen)) {
        seen[ref] = 1
        print ref
      }
    }
  }

  if (line ~ /^###[[:space:]]+NFR[[:space:]]+[0-9]+/) {
    tmp = line
    sub(/^###[[:space:]]+NFR[[:space:]]+/, "", tmp)
    split(tmp, parts, /[^0-9]/)
    if (parts[1] ~ /^[0-9]+$/) {
      ref = "NFR-" parts[1]
      if (!(ref in seen)) {
        seen[ref] = 1
        print ref
      }
    }
  }

  tmp = line
  while (match(tmp, /(REQ|NFR)-[0-9]+/)) {
    ref = substr(tmp, RSTART, RLENGTH)
    if (!(ref in seen)) {
      seen[ref] = 1
      print ref
    }
    tmp = substr(tmp, RSTART + RLENGTH)
  }
}
' "$requirements_path"
}

extract_technical_evidence_catalog() {
  local technical_requirements_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function slugify(value, normalized, out, i, ch, prev_dash) {
  normalized = tolower(trim(value))
  out = ""
  prev_dash = 0
  for (i = 1; i <= length(normalized); i++) {
    ch = substr(normalized, i, 1)
    if (ch ~ /[a-z0-9]/) {
      out = out ch
      prev_dash = 0
    } else if (out != "" && !prev_dash) {
      out = out "-"
      prev_dash = 1
    }
  }
  sub(/-+$/, "", out)
  return out
}
function is_no_remaining_gap(value, normalized) {
  normalized = tolower(trim(value))
  return (normalized == "no remaining gap" || normalized == "none" || normalized == "n/a")
}
function requirement_to_gap_token(requirement_id, suffix) {
  suffix = requirement_id
  sub(/^REQ-/, "", suffix)
  return "gap/TECH_REQ-" suffix
}
function flush_requirement(token) {
  if (current_requirement == "") {
    return
  }
  token = requirement_to_gap_token(current_requirement)
  if (!(token in seen_req_all)) {
    print "req_all|" token
    seen_req_all[token] = 1
  }
  if (!requirement_resolved && !(token in seen_req_unresolved)) {
    print "req_unresolved|" token
    seen_req_unresolved[token] = 1
  }
  current_requirement = ""
  requirement_resolved = 0
}
function flush_component(token) {
  if (current_component == "") {
    return
  }
  token = "comp/" current_component
  if (!(token in seen_comp_all)) {
    print "comp_all|" token
    seen_comp_all[token] = 1
  }
  if (!component_resolved) {
    if (!(token in seen_comp_unresolved)) {
      print "comp_unresolved|" token
      seen_comp_unresolved[token] = 1
    }
    if (component_repo != "" && !(component_repo in seen_repo_unresolved)) {
      print "repo_unresolved|" component_repo
      seen_repo_unresolved[component_repo] = 1
    }
  }
  current_component = ""
  component_repo = ""
  component_resolved = 0
}
BEGIN {
  section = ""
  current_requirement = ""
  requirement_resolved = 0
  current_component = ""
  component_repo = ""
  component_resolved = 0
}
{
  if ($0 ~ /^## 4\.[[:space:]]+Requirement Coverage and Gaps[[:space:]]*$/) {
    if (section == "requirements") {
      flush_requirement()
    } else if (section == "components") {
      flush_component()
    }
    section = "requirements"
    next
  }

  if ($0 ~ /^## 5\.[[:space:]]+Impacted Components[[:space:]]*$/) {
    if (section == "requirements") {
      flush_requirement()
    } else if (section == "components") {
      flush_component()
    }
    section = "components"
    next
  }

  if ($0 ~ /^## [0-9]+\./) {
    if (section == "requirements") {
      flush_requirement()
    } else if (section == "components") {
      flush_component()
    }
    section = ""
    next
  }

  if (section == "requirements") {
    if ($0 ~ /^### Requirement:[[:space:]]*(REQ|NFR)-[0-9]+/) {
      flush_requirement()
      line = $0
      sub(/^### Requirement:[[:space:]]*/, "", line)
      split(line, parts, /[^A-Za-z0-9-]/)
      current_requirement = trim(parts[1])
      requirement_resolved = 0
      next
    }

    if (current_requirement != "") {
      if ($0 ~ /^- gap_status:[[:space:]]*/) {
        line = $0
        sub(/^- gap_status:[[:space:]]*/, "", line)
        status = tolower(trim(line))
        if (status == "fully_implemented" || status == "fully implemented") {
          requirement_resolved = 1
        }
        next
      }

      if ($0 ~ /^- gap_to_close:[[:space:]]*/) {
        line = $0
        sub(/^- gap_to_close:[[:space:]]*/, "", line)
        if (is_no_remaining_gap(line)) {
          requirement_resolved = 1
        }
        next
      }
    }

    next
  }

  if (section == "components") {
    if ($0 ~ /^### Component:[[:space:]]*/) {
      flush_component()
      line = $0
      sub(/^### Component:[[:space:]]*/, "", line)
      current_component = slugify(line)
      component_repo = ""
      component_resolved = 0
      next
    }

    if (current_component != "") {
      if ($0 ~ /^- repo:[[:space:]]*/) {
        line = $0
        sub(/^- repo:[[:space:]]*/, "", line)
        component_repo = tolower(trim(line))
        next
      }

      if ($0 ~ /^- gap_to_close:[[:space:]]*/) {
        line = $0
        sub(/^- gap_to_close:[[:space:]]*/, "", line)
        if (is_no_remaining_gap(line)) {
          component_resolved = 1
        }
        next
      }
    }

    next
  }
}
END {
  if (section == "requirements") {
    flush_requirement()
  } else if (section == "components") {
    flush_component()
  }
}
' "$technical_requirements_path"
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
  local requirement_refs_csv="$3"
  local required_repo_csv="$4"
  local valid_req_evidence_csv="$5"
  local valid_comp_evidence_csv="$6"
  local unresolved_req_evidence_csv="$7"
  local unresolved_comp_evidence_csv="$8"
  local scheduled_slice_refs_csv="${9:-}"
  local required_surfaces_csv="${10:-}"

  set +e
  awk \
    -v active_classes_csv="$active_classes_csv" \
    -v requirement_refs_csv="$requirement_refs_csv" \
    -v required_repo_csv="$required_repo_csv" \
    -v valid_req_evidence_csv="$valid_req_evidence_csv" \
    -v valid_comp_evidence_csv="$valid_comp_evidence_csv" \
    -v unresolved_req_evidence_csv="$unresolved_req_evidence_csv" \
    -v unresolved_comp_evidence_csv="$unresolved_comp_evidence_csv" \
    -v scheduled_slice_refs_csv="$scheduled_slice_refs_csv" \
    -v required_surfaces_csv="$required_surfaces_csv" '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function lower_trim(v) {
  return tolower(trim(v))
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
function fail_quality(message) {
  print "quality gate failed: " message
  has_errors = 1
}
function register_csv(csv, target, items, item, i) {
  item_count = split(csv, items, /,/)
  for (i = 1; i <= item_count; i++) {
    item = trim(items[i])
    if (item != "") {
      target[item] = 1
    }
  }
}
function parse_step_id_from_heading(line, rest, parts) {
  rest = line
  sub(/^###[[:space:]]+Step[[:space:]]+/, "", rest)
  split(rest, parts, /[[:space:]]+/)
  return parts[1]
}
function parse_csv_order(csv, order_arr, seen_arr, count_name, items, item, i) {
  count = split(csv, items, /,/)
  for (i = 1; i <= count; i++) {
    item = trim(items[i])
    if (item != "" && !(item in seen_arr)) {
      seen_arr[item] = 1
      order_arr[++count_name] = item
    }
  }
  return count_name
}
function validate_previous_step(    depends_value, dep_parts, dep_count, dep, ref_key, evidence_parts, evidence_count, token, has_nonempty_evidence_token, valid_evidence_token_count, token_ref_key, coverage_text) {
  if (current_step == "") {
    return
  }
  if (current_repo == "") {
    fail_quality("step " current_step " is missing #### Repo")
  }
  if (current_depends == "") {
    fail_quality("step " current_step " is missing #### Depends on")
  }
  if (current_evidence == "") {
    fail_quality("step " current_step " is missing #### Evidence")
  }
  if (current_preserved_surface == "") {
    fail_quality("step " current_step " is missing #### Preserved Surface")
  }
  if (current_bullet_count < 3) {
    fail_quality("step " current_step " must contain at least 3 checklist bullets")
  }
  if (!current_has_plan_bullet) {
    fail_quality("step " current_step " must include first bullet: Plan and discuss the step")
  }
  if (!current_has_review_bullet) {
    fail_quality("step " current_step " must include last bullet: Review step implementation")
  }

  if (current_preserved_surface != "" && tolower(trim(current_preserved_surface)) != "none") {
    if (!has_surface_terms(current_preserved_surface)) {
      fail_quality("step " current_step " has non-operator-facing preserved surface value: " current_preserved_surface)
    }
    coverage_text = tolower(current_heading_text " " current_bullets_text)
    if (looks_supporting_only(coverage_text)) {
      fail_quality("step " current_step " marks preserved surface but describes supporting-only work")
    }
    preserved_surface_count++
    preserved_surfaces[preserved_surface_count] = current_preserved_surface
    preserved_surface_is_coordination[preserved_surface_count] = current_is_coordination
  }

  depends_value = trim(current_depends)
  if (tolower(depends_value) != "none") {
    dep_count = split(depends_value, dep_parts, /,/)
    for (i = 1; i <= dep_count; i++) {
      dep = trim(dep_parts[i])
      if (dep == "") {
        fail_quality("step " current_step " has empty dependency entry")
        continue
      }
      if (index(dep, "/") > 0) {
        if (dep !~ /^[A-Za-z0-9._-]+\/[0-9]+(\.[0-9]+)*$/) {
          fail_quality("step " current_step " has invalid cross-feature dependency " dep)
          continue
        }
        slash_index = index(dep, "/")
        feature_folder = substr(dep, 1, slash_index - 1)
        if (feature_folder == "." || feature_folder == "..") {
          fail_quality("step " current_step " has invalid cross-feature dependency " dep)
          continue
        }
        ref_key = current_step SUBSEP dep
        if (ref_key in seen_dependency_refs) {
          fail_quality("step " current_step " repeats dependency " dep)
          continue
        }
        seen_dependency_refs[ref_key] = 1
        continue
      }
      if (!(dep in seen_steps)) {
        fail_quality("step " current_step " depends on unknown or later step " dep)
        continue
      }
      ref_key = current_step SUBSEP dep
      if (ref_key in seen_dependency_refs) {
        fail_quality("step " current_step " repeats dependency " dep)
        continue
      }
      seen_dependency_refs[ref_key] = 1
    }
  }

  if (current_evidence != "") {
    evidence_count = split(current_evidence, evidence_parts, /,/)
    has_nonempty_evidence_token = 0
    valid_evidence_token_count = 0

    delete seen_step_evidence_tokens
    for (i = 1; i <= evidence_count; i++) {
      token = trim(evidence_parts[i])
      if (token == "") {
        fail_quality("step " current_step " has empty evidence token entry")
        continue
      }

      has_nonempty_evidence_token = 1
      token_ref_key = current_step SUBSEP token
      if (token_ref_key in seen_step_evidence_tokens) {
        fail_quality("step " current_step " repeats evidence token " token)
        continue
      }
      seen_step_evidence_tokens[token_ref_key] = 1

      if (token ~ /^gap\/TECH_REQ-([0-9]+|NFR-[0-9]+)$/) {
        if (!(token in valid_req_evidence_tokens)) {
          fail_quality("step " current_step " references unknown evidence token " token)
          continue
        }
        covered_evidence_tokens[token] = 1
        valid_evidence_token_count++
        continue
      }

      if (token ~ /^comp\/[a-z0-9]+(-[a-z0-9]+)*$/) {
        if (!(token in valid_comp_evidence_tokens)) {
          fail_quality("step " current_step " references unknown evidence token " token)
          continue
        }
        covered_evidence_tokens[token] = 1
        valid_evidence_token_count++
        continue
      }

      if (token ~ /^slice\/[A-Za-z0-9][A-Za-z0-9_.-]*$/) {
        covered_evidence_tokens[token] = 1
        valid_evidence_token_count++
        continue
      }

      fail_quality("step " current_step " has invalid evidence token format: " token)
    }

    if (!has_nonempty_evidence_token) {
      fail_quality("step " current_step " has empty #### Evidence value")
    } else if (valid_evidence_token_count < 1) {
      fail_quality("step " current_step " is not supported by any valid technical evidence token")
    }
  }
}
BEGIN {
  has_errors = 0
  saw_any_step = 0
  has_unfilled = 0
  current_step = ""
  current_repo = ""
  current_depends = ""
  current_evidence = ""
  current_bullet_count = 0
  current_has_plan_bullet = 0
  current_has_review_bullet = 0
  current_preserved_surface = ""
  current_is_coordination = 0
  current_heading_text = ""
  current_bullets_text = ""
  last_major = -1
  last_minor = -1
  valid_ref_order_count = 0
  required_repo_order_count = 0
  unresolved_req_order_count = 0
  unresolved_comp_order_count = 0
  required_surface_order_count = 0
  preserved_surface_count = 0

  register_csv(active_classes_csv, active_classes)
  register_csv(requirement_refs_csv, valid_refs)
  register_csv(required_repo_csv, repos_requiring_steps)
  register_csv(valid_req_evidence_csv, valid_req_evidence_tokens)
  register_csv(valid_comp_evidence_csv, valid_comp_evidence_tokens)
  register_csv(unresolved_req_evidence_csv, unresolved_req_evidence_tokens)
  register_csv(unresolved_comp_evidence_csv, unresolved_comp_evidence_tokens)

  valid_ref_order_count = parse_csv_order(requirement_refs_csv, valid_ref_order, seen_valid_ref_order, valid_ref_order_count)
  required_repo_order_count = parse_csv_order(required_repo_csv, required_repo_order, seen_required_repo_order, required_repo_order_count)
  unresolved_req_order_count = parse_csv_order(unresolved_req_evidence_csv, unresolved_req_order, seen_unresolved_req_order, unresolved_req_order_count)
  unresolved_comp_order_count = parse_csv_order(unresolved_comp_evidence_csv, unresolved_comp_order, seen_unresolved_comp_order, unresolved_comp_order_count)
  scheduled_slice_refs_order_count = parse_csv_order(scheduled_slice_refs_csv, scheduled_slice_refs_order, seen_scheduled_slice_refs_order, scheduled_slice_refs_order_count)
  required_surface_order_count = parse_csv_order(required_surfaces_csv, required_surface_order, seen_required_surface_order, required_surface_order_count)
}
{
  if (toupper($0) ~ /\[UNFILLED\]/) {
    has_unfilled = 1
  }
}
/^### Step[[:space:]]+[0-9]+\.[0-9]+[[:space:]]+/ {
  validate_previous_step()

  heading = $0
  step_id = parse_step_id_from_heading(heading)
  split(step_id, step_parts, /\./)
  major = step_parts[1] + 0
  minor = step_parts[2] + 0
  if (last_major > major || (last_major == major && last_minor >= minor)) {
    fail_quality("step ids must be in strictly increasing order; found out-of-order step " step_id)
  }
  last_major = major
  last_minor = minor

  if (step_id in seen_steps) {
    fail_quality("duplicate step id: " step_id)
  }
  seen_steps[step_id] = 1
  saw_any_step = 1
  current_step = step_id
  current_repo = ""
  current_depends = ""
  current_evidence = ""
  current_bullet_count = 0
  current_has_plan_bullet = 0
  current_has_review_bullet = 0
  current_preserved_surface = ""
  current_is_coordination = 0
  current_heading_text = heading
  current_bullets_text = ""

  ref_count = 0
  temp = heading
  while (match(temp, /\[(REQ|NFR)-[0-9]+\]/)) {
    ref = substr(temp, RSTART + 1, RLENGTH - 2)
    ref_count++
    if (!(ref in valid_refs)) {
      fail_quality("step heading \"" heading "\" references unknown requirement id " ref)
    } else {
      covered_refs[ref] = 1
    }
    temp = substr(temp, RSTART + RLENGTH)
  }
  if (ref_count == 0) {
    fail_quality("step heading \"" heading "\" must reference at least one REQ-* or NFR-* id")
  }
  next
}
/^#### Repo:[[:space:]]*/ {
  if (current_step == "") {
    fail_quality("#### Repo appears before any step heading")
    next
  }
  if (current_repo != "") {
    fail_quality("step " current_step " declares #### Repo more than once")
    next
  }
  repo_value = lower_trim($0)
  sub(/^#### repo:[[:space:]]*/, "", repo_value)
  if (!(repo_value in active_classes)) {
    fail_quality("step " current_step " uses repo outside active project classes: " repo_value)
  }
  if (repo_value != "backend" && repo_value != "frontend" && repo_value != "mobile") {
    fail_quality("step " current_step " has invalid repo value: " repo_value)
  }
  current_repo = repo_value
  repo_steps[repo_value]++
  next
}
/^#### Depends on:[[:space:]]*/ {
  if (current_step == "") {
    fail_quality("#### Depends on appears before any step heading")
    next
  }
  if (current_depends != "") {
    fail_quality("step " current_step " declares #### Depends on more than once")
    next
  }
  depends_value = $0
  sub(/^#### Depends on:[[:space:]]*/, "", depends_value)
  depends_value = trim(depends_value)
  if (depends_value == "") {
    fail_quality("step " current_step " has empty #### Depends on value")
  }
  current_depends = depends_value
  next
}
/^#### Evidence:[[:space:]]*/ {
  if (current_step == "") {
    fail_quality("#### Evidence appears before any step heading")
    next
  }
  if (current_evidence != "") {
    fail_quality("step " current_step " declares #### Evidence more than once")
    next
  }
  evidence_value = $0
  sub(/^#### Evidence:[[:space:]]*/, "", evidence_value)
  current_evidence = trim(evidence_value)
  next
}
/^#### Preserved Surface:[[:space:]]*/ {
  if (current_step == "") {
    fail_quality("#### Preserved Surface appears before any step heading")
    next
  }
  if (current_preserved_surface != "") {
    fail_quality("step " current_step " declares #### Preserved Surface more than once")
    next
  }
  preserved_surface_value = $0
  sub(/^#### Preserved Surface:[[:space:]]*/, "", preserved_surface_value)
  current_preserved_surface = trim(preserved_surface_value)
  if (current_preserved_surface == "") {
    fail_quality("step " current_step " has empty #### Preserved Surface value")
  }
  next
}
/^#### Coordination:[[:space:]]*/ {
  if (current_step != "") {
    coord_value = $0
    sub(/^#### Coordination:[[:space:]]*/, "", coord_value)
    if (tolower(trim(coord_value)) == "true") {
      current_is_coordination = 1
    }
  }
  next
}
/^#### Assigned:[[:space:]]*/ {
  if (current_step == "") {
    fail_quality("#### Assigned appears before any step heading")
  }
  next
}
/^- \[[ xX]\][[:space:]]+/ {
  if (current_step == "") {
    fail_quality("checklist bullet appears before any step heading")
    next
  }
  current_bullet_count++
  bullet_text = $0
  sub(/^- \[[ xX]\][[:space:]]+/, "", bullet_text)
  bullet_text = trim(bullet_text)
  if (bullet_text != "") {
    current_bullets_text = current_bullets_text " " tolower(bullet_text)
  }
  if (current_bullet_count == 1 && bullet_text == "Plan and discuss the step") {
    current_has_plan_bullet = 1
  }
  if (bullet_text == "Review step implementation") {
    current_has_review_bullet = 1
  }
  next
}
END {
  validate_previous_step()

  if (has_unfilled) {
    fail_quality("artifact still contains [UNFILLED] placeholders")
  }
  if (!saw_any_step) {
    fail_quality("implementation plan must contain at least one step")
  }
  for (i = 1; i <= required_repo_order_count; i++) {
    repo_name = required_repo_order[i]
    if (!(repo_name in repo_steps) || repo_steps[repo_name] < 1) {
      fail_quality("repo " repo_name " has impacted components in technical requirements but no plan step is allocated to it")
    }
  }
  for (i = 1; i <= valid_ref_order_count; i++) {
    req_ref = valid_ref_order[i]
    if (!(req_ref in covered_refs)) {
      fail_quality("requirement id " req_ref " is not covered by any implementation step heading")
    }
  }
  for (i = 1; i <= unresolved_req_order_count; i++) {
    req_token = unresolved_req_order[i]
    if (!(req_token in covered_evidence_tokens)) {
      fail_quality("unresolved requirement evidence token " req_token " is not covered by any implementation step")
    }
  }
  for (i = 1; i <= unresolved_comp_order_count; i++) {
    comp_token = unresolved_comp_order[i]
    if (!(comp_token in covered_evidence_tokens)) {
      fail_quality("unresolved component evidence token " comp_token " is not covered by any implementation step")
    }
  }
  for (i = 1; i <= scheduled_slice_refs_order_count; i++) {
    slice_token = "slice/" scheduled_slice_refs_order[i]
    if (!(slice_token in covered_evidence_tokens)) {
      fail_quality("scheduled prerequisite slice_ref " scheduled_slice_refs_order[i] " from prerequisite_gaps.md is not covered by any plan step evidence token (expected: " slice_token ")")
    }
  }
  for (i = 1; i <= required_surface_order_count; i++) {
    required_surface = trim(required_surface_order[i])
    if (required_surface == "") continue
    matched_any = 0
    matched_non_coord = 0
    for (j = 1; j <= preserved_surface_count; j++) {
      if (surface_matches(required_surface, preserved_surfaces[j])) {
        matched_any = 1
        if (!preserved_surface_is_coordination[j]) {
          matched_non_coord = 1
          break
        }
      }
    }
    if (!matched_any) {
      fail_quality("required missing operator-facing surface is not preserved by any implementation plan step: " required_surface)
    } else if (!matched_non_coord) {
      fail_quality("required missing operator-facing surface has no non-coordination plan step coverage: " required_surface)
    }
  }
  if (has_errors) {
    exit 1
  }
  print "quality gate passed: repository implementation plan structure is complete"
}
' "$target_path"
  local status=$?
  set -e

  return "$status"
}

main() {
  require_command awk
  require_command sed

  if [[ -z "$TARGET_RELATIVE_PATH" ]]; then
    helper_fail "Usage: $(basename "$0") <implementation-plan-path>"
  fi

  local target_path=""
  local target_dir=""
  local project_dir=""
  local requirements_path=""
  local technical_requirements_path=""
  local prerequisite_gaps_path=""
  local definition_path=""
  local active_classes_csv=""
  local requirement_refs_csv=""
  local required_repo_csv=""
  local valid_req_evidence_csv=""
  local valid_comp_evidence_csv=""
  local unresolved_req_evidence_csv=""
  local unresolved_comp_evidence_csv=""
  local scheduled_slice_refs_csv=""
  local required_surfaces_csv=""
  local parsed_classes=""
  local parsed_refs=""
  local parsed_evidence_catalog=""
  local parsed_required_surfaces=""
  local class_name=""
  local normalized_class=""
  local status=0
  local catalog_kind=""
  local catalog_value=""

  target_path="$(resolve_target_path "$TARGET_RELATIVE_PATH")"

  if [[ ! -f "$target_path" ]]; then
    helper_fail "Target repository implementation plan artifact not found: $TARGET_RELATIVE_PATH"
  fi
  if [[ ! -s "$target_path" ]]; then
    echo "target repository implementation plan artifact is empty: $TARGET_RELATIVE_PATH"
    exit "$EXIT_CONTENT_FAILURE"
  fi

  target_dir="$(cd "$(dirname "$target_path")" && pwd -P)"
  project_dir="$(cd "$target_dir/.." && pwd -P)"
  requirements_path="$target_dir/requirements_ears.md"
  technical_requirements_path="$target_dir/technical_requirements.md"
  prerequisite_gaps_path="$target_dir/prerequisite_gaps.md"
  definition_path="$project_dir/init_progress_definition.yaml"

  if [[ ! -f "$requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: $requirements_path"
  fi
  if [[ ! -f "$technical_requirements_path" ]]; then
    helper_fail "Required sibling artifact not found for quality check: $technical_requirements_path"
  fi
  if [[ ! -f "$prerequisite_gaps_path" ]]; then
    exit "$EXIT_HELPER_FAILURE"
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

  if ! parsed_refs="$(extract_requirement_refs "$requirements_path" 2>/dev/null)"; then
    helper_fail "Failed to read requirement ids from $requirements_path"
  fi
  while IFS= read -r class_name; do
    class_name="$(trim_value "$class_name")"
    [[ -n "$class_name" ]] || continue
    append_csv_value requirement_refs_csv "$class_name"
  done <<<"$parsed_refs"

  if [[ -z "$requirement_refs_csv" ]]; then
    helper_fail "No requirement ids found in $requirements_path"
  fi

  if ! parsed_evidence_catalog="$(extract_technical_evidence_catalog "$technical_requirements_path" 2>/dev/null)"; then
    helper_fail "Failed to read technical evidence catalog from $technical_requirements_path"
  fi

  while IFS='|' read -r catalog_kind catalog_value; do
    catalog_kind="$(trim_value "$catalog_kind")"
    catalog_value="$(trim_value "$catalog_value")"
    [[ -n "$catalog_kind" && -n "$catalog_value" ]] || continue

    case "$catalog_kind" in
      req_all)
        append_csv_value valid_req_evidence_csv "$catalog_value"
        ;;
      req_unresolved)
        append_csv_value unresolved_req_evidence_csv "$catalog_value"
        ;;
      comp_all)
        append_csv_value valid_comp_evidence_csv "$catalog_value"
        ;;
      comp_unresolved)
        append_csv_value unresolved_comp_evidence_csv "$catalog_value"
        ;;
      repo_unresolved)
        case "$catalog_value" in
          backend | frontend | mobile)
            append_csv_value required_repo_csv "$catalog_value"
            ;;
        esac
        ;;
    esac
  done <<<"$parsed_evidence_catalog"

  if [[ -z "$valid_req_evidence_csv" && -z "$valid_comp_evidence_csv" ]]; then
    helper_fail "No technical requirement or component evidence tokens found in $technical_requirements_path"
  fi

  local slice_ref=""
  while IFS= read -r slice_ref; do
    slice_ref="$(trim_value "$slice_ref")"
    [[ -n "$slice_ref" ]] || continue
    append_csv_value scheduled_slice_refs_csv "$slice_ref"
  done < <(
    awk '
function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
function is_unfilled(v) { v = trim(v); if (v == "" || v == "[UNFILLED]" || v == "none") return 1; return 0 }
BEGIN { current_status = ""; in_prereq = 0 }
/^#### Prerequisite:/ { in_prereq = 1; current_status = ""; current_slice_ref = ""; next }
/^### Requirement:/ { in_prereq = 0; next }
/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0; sub(/^[[:space:]]*-[[:space:]]*status:[[:space:]]*/, "", line); current_status = trim(line); next
}
/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/ {
  if (!in_prereq) next
  line = $0; sub(/^[[:space:]]*-[[:space:]]*slice_ref:[[:space:]]*/, "", line)
  val = trim(line)
  if (current_status == "scheduled_in_slices" && !is_unfilled(val)) { print val }
  next
}
' "$prerequisite_gaps_path"
  )

  if ! parsed_required_surfaces="$(extract_required_missing_surfaces "$prerequisite_gaps_path" 2>/dev/null)"; then
    helper_fail "Failed to read required missing operator-facing surfaces from $prerequisite_gaps_path"
  fi
  while IFS= read -r class_name; do
    class_name="$(trim_value "$class_name")"
    [[ -n "$class_name" ]] || continue
    append_csv_value required_surfaces_csv "$class_name"
  done <<<"$parsed_required_surfaces"

  validate_content \
    "$target_path" \
    "$active_classes_csv" \
    "$requirement_refs_csv" \
    "$required_repo_csv" \
    "$valid_req_evidence_csv" \
    "$valid_comp_evidence_csv" \
    "$unresolved_req_evidence_csv" \
    "$unresolved_comp_evidence_csv" \
    "$scheduled_slice_refs_csv" \
    "$required_surfaces_csv"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    exit "$EXIT_CONTENT_FAILURE"
  fi
}

main "$@"
