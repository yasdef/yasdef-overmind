#!/usr/bin/env bash
set -euo pipefail

DEFAULT_FEATURE_PATH="overmind/product"
DEFAULT_FEATURE_PATH_LEGACY="product"
FEATURE_TITLE_FALLBACK="<feature not initialized>"
FEATURE_PATH=""
FEATURE_INPUT_PATH=""
PROJECT_DEFINITION_FILE="init_progress_definition.yaml"
PROJECT_OUTPUT_FILE="step_state.md"
PROJECT_TYPE_CODE=""
PROJECT_CLASSES=()
SCANNER_ASDLC_ROOT=""

TMP_OUTPUT_FILE=""


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

cleanup_tmp_output() {
  if [[ -n "${TMP_OUTPUT_FILE:-}" && -f "${TMP_OUTPUT_FILE:-}" ]]; then
    rm -f "$TMP_OUTPUT_FILE"
  fi
}

print_usage() {
  echo "Usage: $0 --path <path/to/feature>"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --path)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --path. Expected --path <path/to/feature>."
      FEATURE_INPUT_PATH="$1"
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    --*)
      die "Unknown argument: $1"
      ;;
    *)
      die "Unknown argument: $1 (expected --path <path/to/feature>)."
      ;;
    esac
    shift
  done

  [[ -n "${FEATURE_INPUT_PATH//[[:space:]]/}" ]] || die "Missing required argument: --path <path/to/feature>"
}

resolve_script_dir() {
  local script_dir=""
  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; then
    die "Failed to resolve script directory."
  fi
  printf '%s' "$script_dir"
}

resolve_projects_root() {
  local script_dir=""
  local projects_root=""

  if [[ -n "${ASDLC_PROJECTS_DIR:-}" ]]; then
    if ! projects_root="$(cd "$ASDLC_PROJECTS_DIR" && pwd)"; then
      die "Failed to resolve ASDLC projects directory from ASDLC_PROJECTS_DIR: $ASDLC_PROJECTS_DIR"
    fi
    printf '%s' "$projects_root"
    return 0
  fi

  script_dir="$(resolve_script_dir)"
  if [[ "$(basename "$script_dir")" != ".commands" ]]; then
    die "ASDLC projects directory is not configured. Run from staged /asdlc/.commands or set ASDLC_PROJECTS_DIR."
  fi

  if ! projects_root="$(cd "$script_dir/../projects" && pwd)"; then
    die "Failed to resolve ASDLC projects directory from staged scanner path: $script_dir"
  fi

  printf '%s' "$projects_root"
}

resolve_feature_root() {
  local input_path="$1"
  local projects_root="$2"
  local feature_root=""

  if [[ -z "${input_path//[[:space:]]/}" ]]; then
    die "Feature path cannot be empty."
  fi

  if [[ ! -e "$input_path" ]]; then
    die "Selected feature path does not exist: $input_path"
  fi

  if [[ ! -d "$input_path" ]]; then
    die "Selected feature path is not a directory: $input_path"
  fi

  if ! feature_root="$(cd "$input_path" && pwd)"; then
    die "Failed to resolve selected feature path: $input_path"
  fi

  if [[ "$feature_root" == "$projects_root" ]]; then
    die "Selected feature path must point to a feature-level folder under: $projects_root"
  fi

  case "$feature_root" in
  "$projects_root"/*)
    ;;
  *)
    die "Selected feature path must be inside ASDLC projects directory: $projects_root"
    ;;
  esac

  printf '%s' "$feature_root"
}

infer_project_root_from_feature_root() {
  local feature_root="$1"
  local projects_root="$2"
  local current="$feature_root"
  local parent=""

  while true; do
    if [[ -f "$current/$PROJECT_DEFINITION_FILE" ]]; then
      printf '%s' "$current"
      return 0
    fi

    if [[ "$current" == "$projects_root" ]]; then
      break
    fi

    parent="$(dirname "$current")"
    if [[ "$parent" == "$current" ]]; then
      break
    fi
    current="$parent"
  done

  die "Selected feature path must belong to one ASDLC project with $PROJECT_DEFINITION_FILE under: $projects_root"
}

replace_file_if_changed() {
  local source_path="$1"
  local target_path="$2"

  if [[ -f "$target_path" ]] && cmp -s "$source_path" "$target_path"; then
    rm -f "$source_path"
    return 1
  fi

  if ! mv "$source_path" "$target_path"; then
    die "Failed to write project step state: $target_path"
  fi

  return 0
}

resolve_scan_folder() {
  local project_root="$1"
  local special_folder="${2:-}"
  local feature_path="$3"
  local step_phase="${4:-init}"

  # Init-phase steps are project-level by contract, so they always resolve
  # artifact checks from the project root regardless of special_folder.
  if [[ "$step_phase" == "init" ]]; then
    printf '%s' "$project_root"
    return 0
  fi

  if [[ -z "$special_folder" ]]; then
    printf '%s' "$project_root"
    return 0
  fi

  local normalized="$special_folder"
  normalized="${normalized#/}"
  while [[ "$normalized" == */ ]]; do
    normalized="${normalized%/}"
  done
  if [[ -z "$normalized" ]]; then
    printf '%s' "$project_root"
    return 0
  fi

  if [[ "$normalized" == "$DEFAULT_FEATURE_PATH" || "$normalized" == "$DEFAULT_FEATURE_PATH_LEGACY" ]]; then
    normalized="$feature_path"
  fi

  printf '%s/%s' "$project_root" "$normalized"
}

matches_scoped_key_value() {
  local file_path="$1"
  local section_marker="$2"
  local key_name="$3"
  local expected_value="$4"
  local actual_value=""

  if ! actual_value="$(extract_scoped_key_value "$file_path" "$section_marker" "$key_name")"; then
    return 1
  fi

  [[ "$actual_value" == "$expected_value" ]]
}

extract_scoped_key_value() {
  local file_path="$1"
  local section_marker="$2"
  local key_name="$3"

  awk -v section_marker="$section_marker" -v key_name="$key_name" '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function heading_level(v) {
  v = trim(v)
  if (match(v, /^#+/)) {
    return RLENGTH
  }
  return 0
}
BEGIN {
  in_section = 0
  section_level = 0
  found = 0
}
{
  line = $0
  trimmed = trim(line)

  if (in_section == 0) {
    if (trimmed == trim(section_marker)) {
      in_section = 1
      section_level = heading_level(trimmed)
    }
    next
  }

  current_level = heading_level(trimmed)
  if (section_level > 0 && current_level > 0 && current_level <= section_level) {
    exit(found ? 0 : 1)
  }

  candidate_line = trimmed
  sub(/^-[[:space:]]*/, "", candidate_line)
  colon_index = index(candidate_line, ":")
  if (colon_index <= 0) {
    next
  }

  candidate_key = trim(substr(candidate_line, 1, colon_index - 1))
  if (candidate_key !~ /^[A-Za-z0-9_.-]+$/ || candidate_key != key_name) {
    next
  }

  candidate_value = trim(substr(candidate_line, colon_index + 1))
  sub(/[[:space:]]+#.*$/, "", candidate_value)
  candidate_value = trim(candidate_value)
  if ((candidate_value ~ /^".*"$/) || (candidate_value ~ /^'\''.*'\''$/)) {
    candidate_value = substr(candidate_value, 2, length(candidate_value) - 2)
  }

  print candidate_value
  found = 1
  exit 0
}
END {
  exit(found ? 0 : 1)
}
' "$file_path"
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value
  value="$(trim_value "$1")"
  if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

normalize_phase_name() {
  local phase="$1"
  phase="$(trim_value "$phase")"
  phase="$(printf '%s' "$phase" | tr '[:upper:]' '[:lower:]')"

  if [[ "$phase" == "feature" ]]; then
    printf '%s' "feature"
  else
    printf '%s' "init"
  fi
}

resolve_feature_heading_name() {
  local project_root="$1"
  local feature_path="$2"
  local feature_summary_path="$project_root/$feature_path/feature_br_summary.md"
  local feature_title=""

  if [[ ! -f "$feature_summary_path" ]]; then
    printf '%s' "$FEATURE_TITLE_FALLBACK"
    return 0
  fi

  if feature_title="$(extract_scoped_key_value "$feature_summary_path" "## 1. Document Meta" "feature_title")"; then
    feature_title="$(trim_value "$feature_title")"
  else
    feature_title=""
  fi

  if [[ -z "$feature_title" ]]; then
    printf '%s' "$FEATURE_TITLE_FALLBACK"
    return 0
  fi

  printf '%s' "$feature_title"
}

load_project_classes() {
  local definition_path="$1"
  local parsed=""

  PROJECT_CLASSES=()
  [[ -f "$definition_path" ]] || return 1

  if ! parsed="$(
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
  in_classes = 0
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
  )"; then
    return 1
  fi

  while IFS= read -r class_name; do
    class_name="$(strip_quotes "$class_name")"
    [[ -n "$class_name" ]] || continue
    PROJECT_CLASSES+=("$class_name")
  done <<<"$parsed"
}

load_project_type_code() {
  local definition_path="$1"
  local parsed=""

  PROJECT_TYPE_CODE=""
  [[ -f "$definition_path" ]] || return 1

  if ! parsed="$(
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
  found = 0
}
/^meta_info:[[:space:]]*$/ {
  in_meta = 1
  next
}
/^steps:[[:space:]]*$/ {
  if (in_meta == 1) {
    exit 1
  }
}
{
  if (in_meta == 0) {
    next
  }

  line = $0
  if (line !~ /^[[:space:]]{2}project_type_code:[[:space:]]*/) {
    next
  }
  sub(/^[[:space:]]{2}project_type_code:[[:space:]]*/, "", line)
  print strip_quotes(line)
  found = 1
  exit 0
}
END {
  exit(found ? 0 : 1)
}
' "$definition_path"
  )"; then
    return 1
  fi

  PROJECT_TYPE_CODE="$(strip_quotes "$parsed")"
}

matches_any_of() {
  local any_of_serialized="$1"
  local required_class=""
  local active_class=""
  local token=""
  local joined=""
  local -a required_classes=()

  any_of_serialized="$(trim_value "$any_of_serialized")"
  [[ -n "$any_of_serialized" ]] || return 2

  joined="${any_of_serialized//|/$'\n'}"
  while IFS= read -r token; do
    token="$(strip_quotes "$token")"
    [[ -n "$token" ]] || continue
    required_classes+=("$token")
  done <<<"$joined"

  [[ "${#required_classes[@]}" -gt 0 ]] || return 2

  for required_class in "${required_classes[@]}"; do
    for active_class in "${PROJECT_CLASSES[@]-}"; do
      if [[ "$required_class" == "$active_class" ]]; then
        return 0
      fi
    done
  done

  return 1
}

matches_project_type_code() {
  local expected_code="$1"

  expected_code="$(strip_quotes "$expected_code")"
  [[ -n "$expected_code" ]] || return 2
  [[ -n "$PROJECT_TYPE_CODE" ]] || return 2

  if [[ "$PROJECT_TYPE_CODE" == "$expected_code" ]]; then
    return 0
  fi

  return 1
}

parse_definition_records() {
  local definition_path="$1"

  awk '
function trim(v) {
  sub(/^[[:space:]]+/, "", v)
  sub(/[[:space:]]+$/, "", v)
  return v
}
function unquote(v) {
  v = trim(v)
  if ((v ~ /^".*"$/) || (v ~ /^'\''.*'\''$/)) {
    v = substr(v, 2, length(v) - 2)
  }
  return v
}
function flush_artifact() {
  if (pending_file != "") {
    if (pending_check_declared == 1 && (pending_key == "" || pending_equals == "" || pending_section == "")) {
      print "ERROR: Artifact entry for step " current_step " has incomplete check_key_value fields." > "/dev/stderr"
      exit 2
    }
    if (pending_required_if_declared == 1 && pending_required_any_of == "" && pending_required_project_type_equals == "") {
      print "ERROR: Artifact entry for step " current_step " has incomplete required_if fields." > "/dev/stderr"
      exit 2
    }
    print "ART" DELIM current_step_index DELIM current_step DELIM pending_file DELIM pending_special DELIM pending_key DELIM pending_equals DELIM pending_section DELIM pending_required_any_of DELIM pending_required_project_type_equals
    pending_file = ""
    pending_special = ""
    pending_key = ""
    pending_equals = ""
    pending_section = ""
    pending_required_any_of = ""
    pending_required_project_type_equals = ""
    pending_check_declared = 0
    pending_required_if_declared = 0
    in_check_key_value = 0
    in_required_if = 0
  }
}
function append_required_any_of(raw_value,   cleaned, count, idx, parts, token) {
  cleaned = trim(raw_value)
  if (cleaned !~ /^\[.*\]$/) {
    print "ERROR: required_if.any_of must be inline YAML list for step " current_step "." > "/dev/stderr"
    exit 2
  }
  cleaned = substr(cleaned, 2, length(cleaned) - 2)
  cleaned = trim(cleaned)
  if (cleaned == "") {
    print "ERROR: required_if.any_of list must not be empty for step " current_step "." > "/dev/stderr"
    exit 2
  }
  count = split(cleaned, parts, ",")
  for (idx = 1; idx <= count; idx++) {
    token = unquote(parts[idx])
    if (token == "") {
      print "ERROR: required_if.any_of contains empty class for step " current_step "." > "/dev/stderr"
      exit 2
    }
    if (pending_required_any_of == "") {
      pending_required_any_of = token
    } else {
      pending_required_any_of = pending_required_any_of "|" token
    }
  }
}
function validate_current_step() {
  if (current_step != "" && current_step_has_name == 0) {
    print "ERROR: Step " current_step " is missing step_name in " FILENAME "." > "/dev/stderr"
    exit 2
  }
}
BEGIN {
  DELIM = sprintf("%c", 31)
  saw_steps = 0
  saw_step_entry = 0
  in_artifacts = 0
  in_check_key_value = 0
  in_required_if = 0
  current_step = ""
  current_step_index = -1
  current_step_has_name = 0
  pending_file = ""
  pending_special = ""
  pending_key = ""
  pending_equals = ""
  pending_section = ""
  pending_required_any_of = ""
  pending_required_project_type_equals = ""
  pending_quality_gate = ""
  pending_check_declared = 0
  pending_required_if_declared = 0
}
/^[[:space:]]*steps:[[:space:]]*$/ {
  saw_steps = 1
  next
}
/^[[:space:]]*-[[:space:]]*step_number:[[:space:]]*/ {
  flush_artifact()
  validate_current_step()

  line = $0
  sub(/^[[:space:]]*-[[:space:]]*step_number:[[:space:]]*/, "", line)
  line = trim(line)
  if (line == "") {
    print "ERROR: Step entry is missing step_number in " FILENAME "." > "/dev/stderr"
    exit 2
  }

  current_step = line
  current_step_index++
  current_step_has_name = 0
  in_artifacts = 0
  in_check_key_value = 0
  saw_step_entry = 1
  next
}
/^[[:space:]]*phase_name:[[:space:]]*/ {
  if (current_step == "") {
    next
  }

  line = $0
  sub(/^[[:space:]]*phase_name:[[:space:]]*/, "", line)
  line = tolower(unquote(line))
  print "PHASE" DELIM current_step_index DELIM current_step DELIM line
  next
}
/^[[:space:]]*step_name:[[:space:]]*/ {
  if (current_step == "") {
    next
  }

  line = $0
  sub(/^[[:space:]]*step_name:[[:space:]]*/, "", line)
  line = unquote(line)
  if (line == "") {
    print "ERROR: Step " current_step " is missing step_name in " FILENAME "." > "/dev/stderr"
    exit 2
  }
  print "STEP" DELIM current_step_index DELIM current_step DELIM line
  current_step_has_name = 1
  next
}
/^[[:space:]]*optional:[[:space:]]*/ {
  if (current_step == "") {
    next
  }

  line = $0
  sub(/^[[:space:]]*optional:[[:space:]]*/, "", line)
  line = tolower(unquote(line))
  print "OPT" DELIM current_step_index DELIM current_step DELIM line
  next
}
/^[[:space:]]*finished_only_if_artefacts_present:[[:space:]]*$/ {
  if (current_step != "") {
    flush_artifact()
    in_artifacts = 1
    in_check_key_value = 0
  }
  next
}
/^[[:space:]]*finished_only_if_conditions_meet:[[:space:]]*$/ {
  flush_artifact()
  in_artifacts = 0
  in_check_key_value = 0
  in_required_if = 0
  next
}
{
  if (in_artifacts == 0 || current_step == "") {
    next
  }

  if ($0 ~ /^[[:space:]]*-[[:space:]]*file:[[:space:]]*/) {
    flush_artifact()
    line = $0
    sub(/^[[:space:]]*-[[:space:]]*file:[[:space:]]*/, "", line)
    line = unquote(line)
    if (line == "") {
      print "ERROR: Artifact entry for step " current_step " is missing file." > "/dev/stderr"
      exit 2
    }
    pending_file = line
    pending_special = ""
    pending_key = ""
    pending_equals = ""
    pending_section = ""
    pending_required_any_of = ""
    pending_required_project_type_equals = ""
    pending_check_declared = 0
    pending_required_if_declared = 0
    in_check_key_value = 0
    in_required_if = 0
    next
  }

  if ($0 ~ /^[[:space:]]*special_folder:[[:space:]]*/) {
    if (pending_file == "") {
      next
    }
    line = $0
    sub(/^[[:space:]]*special_folder:[[:space:]]*/, "", line)
    pending_special = unquote(line)
    in_check_key_value = 0
    next
  }

  if ($0 ~ /^[[:space:]]*check_key_value:[[:space:]]*$/) {
    if (pending_file == "") {
      next
    }
    pending_check_declared = 1
    in_check_key_value = 1
    next
  }

  if ($0 ~ /^[[:space:]]*required_if:[[:space:]]*$/) {
    if (pending_file == "") {
      next
    }
    pending_required_if_declared = 1
    in_required_if = 1
    next
  }

  if (in_check_key_value == 1 && $0 ~ /^[[:space:]]*key:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]*key:[[:space:]]*/, "", line)
    pending_key = unquote(line)
    next
  }

  if (in_check_key_value == 1 && $0 ~ /^[[:space:]]*equals:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]*equals:[[:space:]]*/, "", line)
    pending_equals = unquote(line)
    next
  }

  if (in_check_key_value == 1 && $0 ~ /^[[:space:]]*section:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]*section:[[:space:]]*/, "", line)
    pending_section = unquote(line)
    next
  }

  if (in_required_if == 1 && $0 ~ /^[[:space:]]*any_of:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]*any_of:[[:space:]]*/, "", line)
    append_required_any_of(line)
    next
  }

  if (in_required_if == 1 && $0 ~ /^[[:space:]]*equals:[[:space:]]*/) {
    line = $0
    sub(/^[[:space:]]*equals:[[:space:]]*/, "", line)
    pending_required_project_type_equals = unquote(line)
    next
  }
}
END {
  flush_artifact()
  validate_current_step()

  if (saw_steps == 0 || saw_step_entry == 0) {
    print "ERROR: Missing or invalid steps list in " FILENAME "." > "/dev/stderr"
    exit 2
  }
}
' "$definition_path"
}

render_checklist() {
  local project_root="$1"
  local definition_path="$2"

  local -a step_ids=()
  local -a step_names=()
  local -a step_phases=()
  local -a step_optional_flags=()
  local -a step_artifact_indexes=()
  local -a lines=()
  local -a artifact_files=()
  local -a artifact_specials=()
  local -a artifact_check_keys=()
  local -a artifact_check_equals=()
  local -a artifact_check_sections=()
  local -a artifact_required_any_of=()
  local -a artifact_required_project_type_equals=()
  local record_type=""
  local record_step_index=""
  local record_step_id=""
  local record_value_a=""
  local record_value_b=""
  local record_value_c=""
  local record_value_d=""
  local record_value_e=""
  local record_value_f=""
  local record_value_g=""
  local record_value_h=""
  local record_value_i=""
  local artifact_index=""
  local parsed_records=""

  if ! parsed_records="$(parse_definition_records "$definition_path")"; then
    die "Failed to parse project definition: $definition_path"
  fi

  while IFS=$'\037' read -r record_type record_step_index record_step_id record_value_a record_value_b record_value_c record_value_d record_value_e record_value_f record_value_g record_value_h record_value_i; do
    if [[ "$record_type" == "STEP" ]]; then
      step_ids[$record_step_index]="$record_step_id"
      step_names[$record_step_index]="$record_value_a"
    elif [[ "$record_type" == "PHASE" ]]; then
      step_phases[$record_step_index]="$record_value_a"
    elif [[ "$record_type" == "OPT" ]]; then
      step_optional_flags[$record_step_index]="$record_value_a"
    elif [[ "$record_type" == "ART" ]]; then
      artifact_index="${#artifact_files[@]}"
      artifact_files+=("$record_value_a")
      artifact_specials+=("$record_value_b")
      artifact_check_keys+=("$record_value_c")
      artifact_check_equals+=("$record_value_d")
      artifact_check_sections+=("$record_value_e")
      artifact_required_any_of+=("$record_value_f")
      artifact_required_project_type_equals+=("$record_value_g")
      if [[ -n "${step_artifact_indexes[$record_step_index]:-}" ]]; then
        step_artifact_indexes[$record_step_index]+=" $artifact_index"
      else
        step_artifact_indexes[$record_step_index]="$artifact_index"
      fi
    fi
  done <<<"$parsed_records"

  if [[ "${#step_ids[@]}" -eq 0 ]]; then
    die "Missing or invalid 'steps' list in $definition_path"
  fi

  local all_required_complete=1
  local gating_prefix_complete=1
  local next_step_id=""
  local next_step_name=""
  local project_heading_printed=0
  local feature_heading_printed=0
  local feature_heading_name=""

  local i j step_id step_name step_phase complete_marker step_complete step_optional
  local artifact_indexes artifact_file artifact_special artifact_folder artifact_path
  local artifact_check_key artifact_check_equals artifact_check_section artifact_required_csv artifact_required_project_type
  local artifact_required=1
  local any_matching_artifact_mode=0
  local any_matching_artifact_found=0
  local any_matching_artifact_required_count=0
  local artifact_matches_check=0

  for ((i = 0; i < ${#step_ids[@]}; i++)); do
    step_id="${step_ids[$i]}"
    step_name="${step_names[$i]}"
    step_phase="$(normalize_phase_name "${step_phases[$i]:-}")"
    step_optional="$(trim_value "${step_optional_flags[$i]:-false}")"
    step_optional="$(printf '%s' "$step_optional" | tr '[:upper:]' '[:lower:]')"
    if [[ "$step_optional" != "true" ]]; then
      step_optional="false"
    fi

    if [[ "$gating_prefix_complete" -eq 1 || "$step_optional" == "true" ]]; then
      step_complete=1
      any_matching_artifact_mode=0
      any_matching_artifact_found=0
      any_matching_artifact_required_count=0
      if [[ "$step_id" == "7.1" ]]; then
        any_matching_artifact_mode=1
      fi
      artifact_indexes="${step_artifact_indexes[$i]:-}"
      for j in $artifact_indexes; do
        artifact_file="${artifact_files[$j]}"
        artifact_special="${artifact_specials[$j]}"
        artifact_required_csv="${artifact_required_any_of[$j]}"
        artifact_required_project_type="${artifact_required_project_type_equals[$j]}"
        artifact_required=1
        if [[ -n "$artifact_required_project_type" ]]; then
          if matches_project_type_code "$artifact_required_project_type"; then
            artifact_required=1
          else
            case "$?" in
            1)
              artifact_required=0
              ;;
            *)
              die "Invalid project_type_code required_if condition for step $step_id artifact '$artifact_file'."
              ;;
            esac
          fi
        fi
        if [[ -n "$artifact_required_csv" ]]; then
          if matches_any_of "$artifact_required_csv"; then
            :
          else
            case "$?" in
            1)
              artifact_required=0
              ;;
            *)
              die "Invalid required_if condition for step $step_id artifact '$artifact_file'."
              ;;
            esac
          fi
        fi
        if [[ "$artifact_required" -eq 0 ]]; then
          continue
        fi

        artifact_folder="$(resolve_scan_folder "$project_root" "$artifact_special" "$FEATURE_PATH" "$step_phase")"
        artifact_path="$artifact_folder/$artifact_file"
        if [[ "$any_matching_artifact_mode" -eq 1 ]]; then
          any_matching_artifact_required_count=$((any_matching_artifact_required_count + 1))
        fi
        if [[ ! -f "$artifact_path" ]]; then
          if [[ "$any_matching_artifact_mode" -eq 1 ]]; then
            continue
          fi
          step_complete=0
          break
        fi

        artifact_check_key="${artifact_check_keys[$j]}"
        artifact_check_equals="${artifact_check_equals[$j]}"
        artifact_check_section="${artifact_check_sections[$j]}"
        if [[ -n "$artifact_check_key" ]]; then
          artifact_matches_check=0
          if matches_scoped_key_value "$artifact_path" "$artifact_check_section" "$artifact_check_key" "$artifact_check_equals"; then
            artifact_matches_check=1
          fi
          if [[ "$any_matching_artifact_mode" -eq 1 ]]; then
            if [[ "$artifact_matches_check" -eq 1 ]]; then
              any_matching_artifact_found=1
            fi
            continue
          fi
          if [[ "$artifact_matches_check" -ne 1 ]]; then
            step_complete=0
            break
          fi
        fi
      done
      if [[ "$any_matching_artifact_mode" -eq 1 ]]; then
        if [[ "$any_matching_artifact_required_count" -eq 0 || "$any_matching_artifact_found" -ne 1 ]]; then
          step_complete=0
        fi
      fi
    else
      step_complete=0
    fi

    if [[ "$step_complete" -eq 1 ]]; then
      complete_marker="x"
    else
      complete_marker=" "
      if [[ "$step_optional" != "true" ]]; then
        all_required_complete=0
      fi
      if [[ "$step_optional" != "true" && "$gating_prefix_complete" -eq 1 && -z "$next_step_id" ]]; then
        next_step_id="$step_id"
        next_step_name="$step_name"
        gating_prefix_complete=0
      fi
    fi

    if [[ "$step_phase" == "feature" ]]; then
      if [[ "$feature_heading_printed" -eq 0 ]]; then
        feature_heading_name="$(resolve_feature_heading_name "$project_root" "$FEATURE_PATH")"
        lines+=("--- FEATURE LEVEL TASKS $feature_heading_name ---")
        feature_heading_printed=1
      fi
    else
      if [[ "$project_heading_printed" -eq 0 ]]; then
        lines+=("---- PROJECT LEVEL TASKS ----")
        project_heading_printed=1
      fi
    fi

    lines+=("- [$complete_marker] $step_id $step_name")
  done

  echo "# Overmind Bootstrap Checklist"
  echo
  printf '%s\n' "${lines[@]}"
  echo
  if [[ "$all_required_complete" -eq 1 ]]; then
    echo "next step: none"
  else
    printf 'next step: %s (%s)\n' "$next_step_id" "$next_step_name"
  fi
}

main() {
  require_command awk
  require_command cmp
  require_command mktemp

  parse_args "$@"

  local projects_root=""
  local project_root=""
  local feature_root=""
  local definition_path=""
  local output_path=""

  projects_root="$(resolve_projects_root)"
  SCANNER_ASDLC_ROOT="$(dirname "$projects_root")"
  feature_root="$(resolve_feature_root "$FEATURE_INPUT_PATH" "$projects_root")"
  project_root="$(infer_project_root_from_feature_root "$feature_root" "$projects_root")"

  if [[ "$feature_root" == "$project_root" ]]; then
    die "--path must point to a feature-level folder inside project: $project_root"
  fi

  case "$feature_root" in
  "$project_root"/*)
    FEATURE_PATH="${feature_root#"$project_root"/}"
    ;;
  *)
    die "Selected feature path must be nested under inferred project root: $project_root"
    ;;
  esac

  definition_path="$project_root/$PROJECT_DEFINITION_FILE"
  output_path="$project_root/$PROJECT_OUTPUT_FILE"

  [[ -f "$definition_path" ]] || die "Definition file not found: $definition_path"

  load_project_type_code "$definition_path" || PROJECT_TYPE_CODE=""
  load_project_classes "$definition_path" || die "Failed to read meta_info.project_classes from $definition_path."

  mkdir -p "$(dirname "$output_path")"

  TMP_OUTPUT_FILE="$(mktemp "${output_path}.tmp.XXXXXX")"
  trap cleanup_tmp_output EXIT

  if ! render_checklist "$project_root" "$definition_path" >"$TMP_OUTPUT_FILE"; then
    die "Failed to render checklist from $definition_path"
  fi

  replace_file_if_changed "$TMP_OUTPUT_FILE" "$output_path" || true
  TMP_OUTPUT_FILE=""
  trap - EXIT

  cat "$output_path"
}

main "$@"
