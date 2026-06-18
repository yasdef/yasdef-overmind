#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
FEATURE_PATH_INPUT=""
FEATURE_PATH=""
PROJECT_ROOT=""
IMPLEMENTATION_PLAN_FILE=""
WORKERS_FILE=""
PROJECT_DEFINITION_FILE=""

ASSIGNMENT_BACKEND=""
ASSIGNMENT_FRONTEND=""
ASSIGNMENT_MOBILE=""
HAS_ASSIGNMENT_ERRORS="no"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "Required command not found: $command_name"
  fi
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value=""
  value="$(trim_value "$1")"
  if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

normalize_feature_path() {
  local raw_path="${1:-}"
  local normalized="$raw_path"

  normalized="${normalized#./}"
  while [[ "$normalized" == */ ]]; do
    normalized="${normalized%/}"
  done

  if [[ -z "$normalized" ]]; then
    die "feature_path must not be empty."
  fi

  printf '%s' "$normalized"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --feature_path)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --feature_path."
        FEATURE_PATH_INPUT="$(normalize_feature_path "$1")"
        ;;
      --help|-h)
        echo "Usage: feature_assing_workers.sh --feature_path <asdlc/projects/<project-id>/<feature-folder>>"
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done

  [[ -n "$FEATURE_PATH_INPUT" ]] || die "Missing required argument: --feature_path <asdlc/projects/<project-id>/<feature-folder>>."
}

ensure_staged_command_runtime() {
  local script_dir=""
  local parent_dir=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; then
    die "Failed to resolve script directory."
  fi
  parent_dir="$(dirname "$script_dir")"

  if [[ "$(basename "$script_dir")" != ".commands" || ! -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    die "Run this command from ASDLC staged path: <asdlc>/.commands/$SCRIPT_BASENAME"
  fi

  printf '%s' "$parent_dir"
}

resolve_feature_path() {
  local runtime_root="$1"
  local input_path="$2"
  local candidate_path=""
  local resolved_path=""

  if [[ "$input_path" = /* ]]; then
    candidate_path="$input_path"
  else
    candidate_path="$runtime_root/$input_path"
  fi

  if [[ ! -d "$candidate_path" ]]; then
    die "Feature path directory not found: $input_path"
  fi

  if ! resolved_path="$(cd "$candidate_path" && pwd -P)"; then
    die "Failed to resolve feature path: $input_path"
  fi

  case "$resolved_path" in
    "$runtime_root"/*)
      ;;
    *)
      die "Feature path must resolve inside ASDLC workspace: $resolved_path"
      ;;
  esac

  FEATURE_PATH="${resolved_path#"$runtime_root/"}"
}

resolve_project_root() {
  local relative_after_projects=""
  local project_id=""

  if [[ "$FEATURE_PATH" != projects/* ]]; then
    die "Feature path must resolve under projects/<project-id>/<feature-folder>: $FEATURE_PATH"
  fi

  relative_after_projects="${FEATURE_PATH#projects/}"
  project_id="${relative_after_projects%%/*}"

  if [[ -z "$project_id" || "$project_id" == "$relative_after_projects" ]]; then
    die "Feature path must resolve to projects/<project-id>/<feature-folder>: $FEATURE_PATH"
  fi

  PROJECT_ROOT="projects/$project_id"
  PROJECT_DEFINITION_FILE="$PROJECT_ROOT/init_progress_definition.yaml"
}

set_artifact_paths() {
  IMPLEMENTATION_PLAN_FILE="$FEATURE_PATH/implementation_plan.md"
  WORKERS_FILE="$PROJECT_ROOT/workers.yaml"
}

ensure_required_files() {
  local runtime_root="$1"

  [[ -f "$runtime_root/$PROJECT_DEFINITION_FILE" ]] || die "Project definition metadata is required: $PROJECT_DEFINITION_FILE"
  [[ -f "$runtime_root/$IMPLEMENTATION_PLAN_FILE" ]] || die "Implementation plan is not ready: required file not found: $IMPLEMENTATION_PLAN_FILE"
  [[ -f "$runtime_root/$WORKERS_FILE" ]] || die "Worker registry is required for assignment: $WORKERS_FILE"
}

extract_top_level_scalar() {
  local file_path="$1"
  local target_key="$2"

  awk -v target_key="$target_key" '
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
BEGIN {
  found = 0
}
{
  if ($0 ~ /^[[:space:]]*$/) {
    next
  }

  if ($0 !~ /^[A-Za-z0-9_.-]+:[[:space:]]*/) {
    next
  }

  line = $0
  colon_index = index(line, ":")
  if (colon_index <= 0) {
    next
  }

  key = trim(substr(line, 1, colon_index - 1))
  value = strip_quotes(trim(substr(line, colon_index + 1)))
  if (key == target_key) {
    print value
    found = 1
    exit 0
  }
}
END {
  exit(found ? 0 : 1)
}
' "$file_path"
}

ensure_worker_registry_contract() {
  local workers_path="$1"
  local workers_project_id=""

  if ! grep -Eq '^workers:[[:space:]]*($|\[[[:space:]]*\][[:space:]]*$)' "$workers_path"; then
    die "Worker registry is malformed: expected top-level 'workers:' collection in $WORKERS_FILE"
  fi

  workers_project_id="$(extract_top_level_scalar "$workers_path" "project_id" 2>/dev/null || true)"
  workers_project_id="$(strip_quotes "$workers_project_id")"
  [[ -n "$workers_project_id" ]] || die "Worker registry is malformed: expected top-level project_id in $WORKERS_FILE"
}

parse_plan_repo_classes() {
  local plan_path="$1"

  awk '
BEGIN {
  in_step = 0
}
/^### Step[[:space:]]+/ {
  in_step = 1
  next
}
{
  if (!in_step) {
    next
  }
  if ($0 ~ /^#### Repo:[[:space:]]*/) {
    repo_value = tolower($0)
    sub(/^#### repo:[[:space:]]*/, "", repo_value)
    gsub(/[[:space:]]+$/, "", repo_value)
    seen[repo_value] = 1
  }
}
END {
  if (seen["backend"] == 1) {
    print "backend"
  }
  if (seen["frontend"] == 1) {
    print "frontend"
  }
  if (seen["mobile"] == 1) {
    print "mobile"
  }
}
' "$plan_path"
}

collect_active_worker_uuids_for_class() {
  local workers_path="$1"
  local target_class="$2"

  awk -v target_class="$target_class" '
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
function fail_registry(message) {
  print "ERROR: Worker registry is malformed: " message > "/dev/stderr"
  exit 1
}
function finalize_entry() {
  if (entry_started == 0) {
    return
  }
  if (entry_uuid == "" || entry_class == "" || entry_status == "") {
    fail_registry("each worker entry must include uuid, class, and status")
  }
  if (!(entry_class == "backend" || entry_class == "frontend" || entry_class == "mobile" || entry_class == "infrastructure")) {
    fail_registry("unsupported worker class '" entry_class "'")
  }
  if (entry_status == "active" && entry_class == target_class) {
    print entry_uuid
  }
  entry_started = 0
  entry_uuid = ""
  entry_class = ""
  entry_status = ""
}
BEGIN {
  in_workers_section = 0
  workers_key_seen = 0
  entry_started = 0
  entry_uuid = ""
  entry_class = ""
  entry_status = ""
}
{
  raw = $0

  if (raw ~ /^workers:[[:space:]]*\[[[:space:]]*\][[:space:]]*$/) {
    workers_key_seen = 1
    finalize_entry()
    in_workers_section = 0
    next
  }
  if (raw ~ /^workers:[[:space:]]*$/) {
    workers_key_seen = 1
    in_workers_section = 1
    next
  }

  if (raw ~ /^[A-Za-z0-9_.-]+:[[:space:]]*/ && raw !~ /^workers:[[:space:]]*/) {
    finalize_entry()
    in_workers_section = 0
    next
  }

  if (in_workers_section == 0) {
    next
  }

  if (raw ~ /^[[:space:]]*-[[:space:]]*uuid:[[:space:]]*/) {
    finalize_entry()
    line = raw
    sub(/^[[:space:]]*-[[:space:]]*uuid:[[:space:]]*/, "", line)
    entry_uuid = strip_quotes(trim(line))
    entry_started = 1
    next
  }

  if (entry_started == 0) {
    next
  }

  if (raw ~ /^[[:space:]]*class:[[:space:]]*/) {
    line = raw
    sub(/^[[:space:]]*class:[[:space:]]*/, "", line)
    entry_class = tolower(strip_quotes(trim(line)))
    next
  }

  if (raw ~ /^[[:space:]]*status:[[:space:]]*/) {
    line = raw
    sub(/^[[:space:]]*status:[[:space:]]*/, "", line)
    entry_status = tolower(strip_quotes(trim(line)))
    next
  }
}
END {
  if (workers_key_seen == 0) {
    fail_registry("missing top-level workers collection")
  }
  finalize_entry()
}
' "$workers_path"
}

select_worker_uuid_for_class() {
  local class_name="$1"
  shift || true
  local candidates=("$@")
  local candidate_count="${#candidates[@]}"
  local selected=""
  local choice=""
  local idx=0

  if [[ "$candidate_count" -eq 0 ]]; then
    echo "ERROR: no active worker available for class $class_name" >&2
    printf 'ERROR: no active worker available for class %s' "$class_name"
    return 3
  fi

  if [[ "$candidate_count" -eq 1 ]]; then
    printf '%s' "${candidates[0]}"
    return 0
  fi

  while true; do
    echo "Multiple active workers found for class '$class_name'. Select exactly one worker:" >&2
    idx=1
    for selected in "${candidates[@]}"; do
      echo "$idx. $selected" >&2
      idx=$((idx + 1))
    done
    if ! read -r choice; then
      die "Failed to read worker selection for class $class_name."
    fi

    choice="$(trim_value "$choice")"
    if [[ -z "$choice" ]]; then
      echo "Invalid selection. Enter one list number or one worker UUID from the list." >&2
      continue
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      if [[ "$choice" -ge 1 && "$choice" -le "$candidate_count" ]]; then
        printf '%s' "${candidates[$((choice - 1))]}"
        return 0
      fi
      echo "Invalid selection. Enter one list number or one worker UUID from the list." >&2
      continue
    fi

    for selected in "${candidates[@]}"; do
      if [[ "$choice" == "$selected" ]]; then
        printf '%s' "$selected"
        return 0
      fi
    done

    echo "Invalid selection. Enter one list number or one worker UUID from the list." >&2
  done
}

resolve_class_assignments() {
  local workers_path="$1"
  shift || true
  local plan_classes=("$@")
  local class_name=""
  local chosen_value=""
  local select_status=0
  local -a candidates=()
  local candidate=""

  for class_name in "${plan_classes[@]}"; do
    candidates=()
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] && candidates+=("$candidate")
    done < <(collect_active_worker_uuids_for_class "$workers_path" "$class_name")
    set +e
    if [[ "${#candidates[@]}" -gt 0 ]]; then
      chosen_value="$(select_worker_uuid_for_class "$class_name" "${candidates[@]}")"
    else
      chosen_value="$(select_worker_uuid_for_class "$class_name")"
    fi
    select_status=$?
    set -e

    if [[ "$select_status" -eq 3 ]]; then
      HAS_ASSIGNMENT_ERRORS="yes"
    elif [[ "$select_status" -ne 0 ]]; then
      return "$select_status"
    fi

    case "$class_name" in
      backend)
        ASSIGNMENT_BACKEND="$chosen_value"
        ;;
      frontend)
        ASSIGNMENT_FRONTEND="$chosen_value"
        ;;
      mobile)
        ASSIGNMENT_MOBILE="$chosen_value"
        ;;
      *)
        die "Internal error: unsupported class resolution target: $class_name"
        ;;
    esac
  done
}

rewrite_plan_with_assignments() {
  local plan_path="$1"
  local feature_abs_path="$2"
  local output_path="$3"

  awk \
    -v assign_backend="$ASSIGNMENT_BACKEND" \
    -v assign_frontend="$ASSIGNMENT_FRONTEND" \
    -v assign_mobile="$ASSIGNMENT_MOBILE" \
    -v feature_abs_path="$feature_abs_path" \
    -v plan_path="$plan_path" '
function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}
function fail_readiness(message) {
  print "ERROR: Implementation plan is not ready: " message > "/dev/stderr"
  exit 1
}
function step_id_from_heading(line,    rest, parts) {
  rest = line
  sub(/^###[[:space:]]+Step[[:space:]]+/, "", rest)
  split(rest, parts, /[[:space:]]+/)
  return parts[1]
}
function reset_step_buffer() {
  line_count = 0
  insert_after = 0
  current_repo = ""
  current_depends = ""
  current_step_id = ""
}
function step_assignment_for_repo(repo_name) {
  if (repo_name == "backend") {
    return assign_backend
  }
  if (repo_name == "frontend") {
    return assign_frontend
  }
  if (repo_name == "mobile") {
    return assign_mobile
  }
  return ""
}
function dependency_step_complete(sibling_plan_path, dependency_step_id,    line, found_step, checklist_count, incomplete_checklist, candidate_step_id, getline_status) {
  found_step = 0
  checklist_count = 0
  incomplete_checklist = 0

  while ((getline_status = (getline line < sibling_plan_path)) > 0) {
    if (line ~ /^###[[:space:]]+Step[[:space:]]+/) {
      if (found_step == 1) {
        break
      }
      candidate_step_id = step_id_from_heading(line)
      if (candidate_step_id == dependency_step_id) {
        found_step = 1
      }
      continue
    }

    if (found_step != 1) {
      continue
    }

    if (line ~ /^[[:space:]]*-[[:space:]]*\[[^]]+\]/) {
      checklist_count++
      if (line !~ /^[[:space:]]*-[[:space:]]*\[[xX]\]([[:space:]]|$)/) {
        incomplete_checklist = 1
      }
    }
  }
  close(sibling_plan_path)

  return (found_step == 1 && checklist_count > 0 && incomplete_checklist == 0)
}
function cross_dependency_hold(dep,    slash_index, feature_folder, dependency_step_id, sibling_plan_path) {
  slash_index = index(dep, "/")
  feature_folder = substr(dep, 1, slash_index - 1)
  dependency_step_id = substr(dep, slash_index + 1)

  if (feature_folder == "" || dependency_step_id == "" || dep !~ /^[A-Za-z0-9._-]+\/[0-9]+(\.[0-9]+)*$/) {
    fail_readiness("step " current_step_id " has malformed cross-feature dependency " dep)
  }
  if (feature_folder == "." || feature_folder == "..") {
    fail_readiness("step " current_step_id " has malformed cross-feature dependency " dep)
  }

  sibling_plan_path = feature_abs_path "/../" feature_folder "/implementation_plan.md"
  if (!dependency_step_complete(sibling_plan_path, dependency_step_id)) {
    return "hold: depends on " dep
  }

  return ""
}
function hold_assignment_for_depends(depends_value,    dep_parts, dep_count, i, dep, hold_value) {
  depends_value = trim(depends_value)
  if (depends_value == "" || tolower(depends_value) == "none") {
    return ""
  }

  dep_count = split(depends_value, dep_parts, /,/)
  for (i = 1; i <= dep_count; i++) {
    dep = trim(dep_parts[i])
    if (dep == "") {
      continue
    }
    if (index(dep, "/") > 0) {
      hold_value = cross_dependency_hold(dep)
      if (hold_value != "") {
        return hold_value
      }
    }
  }

  return ""
}
function flush_step(    i, insertion_index, assigned_value) {
  if (in_step == 0) {
    return
  }
  if (current_repo == "") {
    fail_readiness("step " step_index " is missing #### Repo: metadata in " plan_path)
  }

  assigned_value = hold_assignment_for_depends(current_depends)
  if (assigned_value == "") {
    assigned_value = step_assignment_for_repo(current_repo)
  }
  if (assigned_value == "") {
    fail_readiness("step " step_index " has no resolved assignment mapping for repo class " current_repo)
  }

  insertion_index = insert_after
  if (insertion_index == 0) {
    insertion_index = 1
    for (i = 1; i <= line_count; i++) {
      if (lines[i] ~ /^#### Repo:[[:space:]]*/ || lines[i] ~ /^#### Depends on:[[:space:]]*/ || lines[i] ~ /^#### Evidence:[[:space:]]*/) {
        insertion_index = i
      }
    }
  }

  for (i = 1; i <= line_count; i++) {
    print lines[i]
    if (i == insertion_index) {
      print "#### Assigned: " assigned_value
    }
  }

  delete lines
  in_step = 0
  reset_step_buffer()
}
BEGIN {
  in_step = 0
  saw_step = 0
  step_index = 0
  reset_step_buffer()
}
/^### Step[[:space:]]+/ {
  flush_step()
  in_step = 1
  saw_step = 1
  step_index++
  current_step_id = step_id_from_heading($0)
  line_count++
  lines[line_count] = $0
  next
}
{
  if (in_step == 0) {
    print $0
    next
  }

  if ($0 ~ /^#### Repo:[[:space:]]*/) {
    if (current_repo != "") {
      fail_readiness("step " step_index " declares #### Repo: more than once in " plan_path)
    }
    repo_value = tolower($0)
    sub(/^#### repo:[[:space:]]*/, "", repo_value)
    gsub(/[[:space:]]+$/, "", repo_value)
    if (!(repo_value == "backend" || repo_value == "frontend" || repo_value == "mobile")) {
      fail_readiness("step " step_index " has unsupported repo class in " plan_path ": " repo_value)
    }
    current_repo = repo_value
    line_count++
    lines[line_count] = $0
    next
  }

  if ($0 ~ /^#### Depends on:[[:space:]]*/) {
    if (current_depends != "") {
      fail_readiness("step " step_index " declares #### Depends on: more than once in " plan_path)
    }
    depends_value = $0
    sub(/^#### Depends on:[[:space:]]*/, "", depends_value)
    current_depends = trim(depends_value)
    line_count++
    lines[line_count] = $0
    next
  }

  if ($0 ~ /^#### Assigned:[[:space:]]*/) {
    next
  }

  line_count++
  lines[line_count] = $0
  if ($0 ~ /^#### Evidence:[[:space:]]*/) {
    insert_after = line_count
  }
}
END {
  flush_step()
  if (!saw_step) {
    fail_readiness("expected at least one ### Step block in " plan_path)
  }
}
' "$plan_path" >"$output_path"
}

main() {
  require_command awk
  require_command grep
  require_command mktemp
  require_command tr

  parse_args "$@"

  local runtime_root=""
  local absolute_plan_path=""
  local absolute_workers_path=""
  local tmp_output_path=""
  local class_name=""
  local -a plan_classes=()
  local plan_class=""

  runtime_root="$(ensure_staged_command_runtime)"
  resolve_feature_path "$runtime_root" "$FEATURE_PATH_INPUT"
  resolve_project_root
  set_artifact_paths
  ensure_required_files "$runtime_root"

  absolute_plan_path="$runtime_root/$IMPLEMENTATION_PLAN_FILE"
  absolute_workers_path="$runtime_root/$WORKERS_FILE"
  ensure_worker_registry_contract "$absolute_workers_path"

  local readiness_helper=""
  readiness_helper="$runtime_root/common_libs/check_implementation_plan_readiness.sh"
  [[ -x "$readiness_helper" ]] || die "Required helper not found: check_implementation_plan_readiness.sh"
  "$readiness_helper" --feature_path "$runtime_root/$FEATURE_PATH"

  while IFS= read -r plan_class; do
    [[ -n "$plan_class" ]] && plan_classes+=("$plan_class")
  done < <(parse_plan_repo_classes "$absolute_plan_path")
  if [[ "${#plan_classes[@]}" -eq 0 ]]; then
    die "Implementation plan is not ready: no supported repo classes were found in step metadata."
  fi

  resolve_class_assignments "$absolute_workers_path" "${plan_classes[@]}"

  if ! tmp_output_path="$(mktemp)"; then
    die "Failed to create temporary file for implementation plan rewrite."
  fi

  if ! rewrite_plan_with_assignments "$absolute_plan_path" "$runtime_root/$FEATURE_PATH" "$tmp_output_path"; then
    rm -f "$tmp_output_path"
    exit 1
  fi

  if grep -Eq '^#### Assigned:[[:space:]]*hold: depends on [^[:space:]]+/[^[:space:]]+' "$tmp_output_path"; then
    HAS_ASSIGNMENT_ERRORS="yes"
  fi

  if ! mv "$tmp_output_path" "$absolute_plan_path"; then
    rm -f "$tmp_output_path"
    die "Failed to write updated implementation plan: $IMPLEMENTATION_PLAN_FILE"
  fi

  echo "Updated $IMPLEMENTATION_PLAN_FILE with worker assignments."
  for class_name in "${plan_classes[@]}"; do
    case "$class_name" in
      backend)
        echo "Class backend -> $ASSIGNMENT_BACKEND"
        ;;
      frontend)
        echo "Class frontend -> $ASSIGNMENT_FRONTEND"
        ;;
      mobile)
        echo "Class mobile -> $ASSIGNMENT_MOBILE"
        ;;
    esac
  done

  if [[ "$HAS_ASSIGNMENT_ERRORS" == "yes" ]]; then
    echo "ERROR: assignment completed with class availability issues or dependency holds. Review #### Assigned lines in $IMPLEMENTATION_PLAN_FILE." >&2
    exit 1
  fi
}

main "$@"
