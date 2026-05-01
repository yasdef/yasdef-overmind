#!/usr/bin/env bash
set -euo pipefail

SCRIPT_BASENAME="$(basename "${BASH_SOURCE[0]}")"
STATE_FILE_NAME=".project_add_feature_e2e_state.env"
FIRST_SUPPORTED_STEP="3"
TARGET_PATH_INPUT=""
RESUME_STEP_INPUT=""
RUNTIME_ROOT=""
PROJECT_PATH=""
PROJECT_ROOT=""
STATE_FILE=""
FEATURE_PATH=""
CACHED_FEATURE_PATH=""
CACHED_FEATURE_PATH_RAW=""
CACHED_FEATURE_PATH_STATE="missing"
DISCOVERED_FEATURE_PATHS=()
UNFINISHED_FEATURE_PATHS=()
UNFINISHED_FEATURE_NEXT_LINES=()
PHASE7_ACTIVE_REPO_CLASSES=()
PHASE7_COMPLETED_REPO_CLASSES=()
PHASE7_PENDING_REPO_CLASSES=()
PHASE_EXECUTION_FAILED_RC=40

PHASE_IDS=("3" "4.1" "4.2" "5" "5.1" "6" "7" "7.1" "8.1" "8.2" "8.3" "8.4")
PHASE_OPTIONAL=("false" "false" "false" "false" "true" "false" "false" "true" "false" "false" "false" "true")


die() {
  echo "ERROR: $*" >&2
  exit 1
}

print_usage() {
  cat <<'USAGE'
Usage: project_add_feature_e2e.sh --path <project-folder-path> [--resume <step>]

Options:
  --path <project-folder-path>  ASDLC project folder (for example: projects/<project-id>)
  --resume <step>               Optional step override (for example: 3, 4.1, 4.2, 5, 5.1, 6, 7, 7.1 (optional MCP placeholder enrichment), 8.1, 8.2 (prerequisite gap trace), 8.3 (implementation plan), 8.4 (optional semantic review))
USAGE
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

array_contains() {
  local needle="$1"
  shift || true
  local item=""
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

is_dotted_numeric_step() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]]
}

compare_dotted_steps() {
  local left="$1"
  local right="$2"
  local old_ifs="$IFS"
  local -a left_parts=()
  local -a right_parts=()
  local max_parts=0
  local idx=0
  local left_value=0
  local right_value=0

  is_dotted_numeric_step "$left" || return 2
  is_dotted_numeric_step "$right" || return 2

  IFS='.'
  read -r -a left_parts <<<"$left"
  read -r -a right_parts <<<"$right"
  IFS="$old_ifs"

  max_parts="${#left_parts[@]}"
  if (( ${#right_parts[@]} > max_parts )); then
    max_parts="${#right_parts[@]}"
  fi

  for ((idx = 0; idx < max_parts; idx++)); do
    left_value=$((10#${left_parts[$idx]:-0}))
    right_value=$((10#${right_parts[$idx]:-0}))
    if (( left_value < right_value )); then
      printf '%s' "-1"
      return 0
    fi
    if (( left_value > right_value )); then
      printf '%s' "1"
      return 0
    fi
  done

  printf '%s' "0"
}

step_is_before_first_supported_step() {
  local step_id="$1"
  local comparison=""

  comparison="$(compare_dotted_steps "$step_id" "$FIRST_SUPPORTED_STEP")" || return 1
  [[ "$comparison" == "-1" ]]
}

fail_project_prerequisite_step() {
  local scanner_step_number="$1"
  local scanner_step_name="$2"

  echo "Project init is incomplete: scanner returned step $scanner_step_number ($scanner_step_name)." >&2
  echo "$SCRIPT_BASENAME starts at feature step $FIRST_SUPPORTED_STEP and cannot continue until earlier project steps are complete." >&2
  case "$scanner_step_number" in
    1.1)
      echo "Run:" >&2
      echo "  .commands/init_project_stack_blueprints.sh --path $PROJECT_PATH" >&2
      ;;
    2)
      echo "Run:" >&2
      echo "  .commands/init_common_contract_definition.sh --path $PROJECT_PATH" >&2
      ;;
    *)
      echo "Complete scanner-reported project step $scanner_step_number before rerunning $SCRIPT_BASENAME." >&2
      ;;
  esac
  exit 1
}

normalize_input_path() {
  local raw_path="${1:-}"
  local normalized="$raw_path"

  normalized="${normalized#./}"
  while [[ "$normalized" == */ ]]; do
    normalized="${normalized%/}"
  done

  if [[ -z "$normalized" ]]; then
    die "path must not be empty."
  fi

  printf '%s' "$normalized"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --path."
        TARGET_PATH_INPUT="$(normalize_input_path "$1")"
        ;;
      --resume)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --resume."
        RESUME_STEP_INPUT="$(trim_value "$1")"
        [[ -n "$RESUME_STEP_INPUT" ]] || die "resume step must not be empty."
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done

  [[ -n "$TARGET_PATH_INPUT" ]] || die "Missing required argument: --path <project-folder-path>."
}

resolve_runtime_root() {
  local script_dir=""
  local parent_dir=""

  if ! script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; then
    die "Failed to resolve script directory."
  fi
  parent_dir="$(dirname "$script_dir")"

  if [[ "$(basename "$script_dir")" != ".commands" || ! -f "$parent_dir/asdlc_metadata.yaml" ]]; then
    die "Run this command from ASDLC staged path: <asdlc>/.commands/$SCRIPT_BASENAME"
  fi

  if ! git -C "$parent_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "ASDLC workspace is not a git repository: $parent_dir"
  fi

  printf '%s' "$parent_dir"
}

resolve_project_path() {
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
    die "Project path directory not found: $input_path"
  fi

  if ! resolved_path="$(cd "$candidate_path" && pwd -P)"; then
    die "Failed to resolve project path: $input_path"
  fi

  case "$resolved_path" in
    "$runtime_root"/*)
      ;;
    *)
      die "Path must resolve inside ASDLC workspace: $resolved_path"
      ;;
  esac

  if [[ ! -f "$resolved_path/init_progress_definition.yaml" ]]; then
    die "Project path must point to a project-level folder containing init_progress_definition.yaml: $input_path"
  fi

  PROJECT_ROOT="${resolved_path#"$runtime_root/"}"
  PROJECT_PATH="$PROJECT_ROOT"
  STATE_FILE="$PROJECT_ROOT/$STATE_FILE_NAME"
}

normalize_feature_path_value() {
  local raw_path="$1"
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

canonicalize_feature_path() {
  local raw_path="$1"
  local runtime_root="$2"
  local candidate_path=""
  local resolved_path=""
  local normalized_value=""

  normalized_value="$(normalize_feature_path_value "$raw_path")"

  if [[ "$normalized_value" = /* ]]; then
    candidate_path="$normalized_value"
  else
    candidate_path="$runtime_root/$normalized_value"
  fi

  if [[ ! -d "$candidate_path" ]]; then
    die "Resolved feature path directory not found: $normalized_value"
  fi

  if ! resolved_path="$(cd "$candidate_path" && pwd -P)"; then
    die "Failed to resolve feature path: $normalized_value"
  fi

  case "$resolved_path" in
    "$runtime_root"/*)
      ;;
    *)
      die "feature_path must resolve inside ASDLC workspace: $resolved_path"
      ;;
  esac

  printf '%s' "${resolved_path#"$runtime_root/"}"
}

maybe_canonicalize_feature_path() {
  local raw_path="$1"
  local runtime_root="$2"
  local candidate_path=""
  local resolved_path=""
  local normalized_value=""

  normalized_value="$(normalize_feature_path_value "$raw_path")" || return 1

  if [[ "$normalized_value" = /* ]]; then
    candidate_path="$normalized_value"
  else
    candidate_path="$runtime_root/$normalized_value"
  fi

  [[ -d "$candidate_path" ]] || return 1

  if ! resolved_path="$(cd "$candidate_path" && pwd -P)"; then
    return 1
  fi

  case "$resolved_path" in
    "$runtime_root"/*)
      ;;
    *)
      return 1
      ;;
  esac

  printf '%s' "${resolved_path#"$runtime_root/"}"
}

load_saved_feature_path_cache() {
  local runtime_root="$1"
  local state_path="$runtime_root/$STATE_FILE"
  local saved_value=""

  [[ -f "$state_path" ]] || return 1

  saved_value="$(awk -F'=' '/^feature_path=/{print substr($0, index($0, "=") + 1)}' "$state_path" | tail -n1)"
  saved_value="$(trim_value "$saved_value")"
  [[ -n "$saved_value" ]] || return 1

  CACHED_FEATURE_PATH_RAW="$saved_value"
  if CACHED_FEATURE_PATH="$(maybe_canonicalize_feature_path "$saved_value" "$runtime_root")"; then
    CACHED_FEATURE_PATH_STATE="valid"
    return 0
  fi

  CACHED_FEATURE_PATH=""
  CACHED_FEATURE_PATH_STATE="stale"
  return 1
}

persist_feature_path() {
  local runtime_root="$1"
  local state_path="$runtime_root/$STATE_FILE"

  mkdir -p "$(dirname "$state_path")"
  printf 'feature_path=%s\n' "$FEATURE_PATH" >"$state_path"
}

parse_scanner_next_step_line() {
  local scanner_output="$1"
  local next_step_line=""

  next_step_line="$(printf '%s\n' "$scanner_output" | awk '/^next step:/ {line=$0} END {print line}')"
  [[ -n "$next_step_line" ]] || return 1

  if [[ "$next_step_line" == "next step: none" ]]; then
    printf '%s' "none"
    return 0
  fi

  if [[ "$next_step_line" =~ ^next\ step:\ ([^[:space:]]+)\ \((.*)\)$ ]]; then
    printf '%s|%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

scanner_status_line_for_feature() {
  local runtime_root="$1"
  local feature_path="$2"
  local scanner_path="$runtime_root/.commands/init_progress_scanner.sh"
  local scanner_output=""
  local parsed_value=""

  [[ -x "$scanner_path" ]] || die "Required script not found or not executable: .commands/init_progress_scanner.sh"

  if ! scanner_output="$("$scanner_path" --path "$feature_path" 2>&1)"; then
    return 1
  fi

  parsed_value="$(parse_scanner_next_step_line "$scanner_output")" || return 1
  if [[ "$parsed_value" == "none" ]]; then
    printf '%s' "next step: none"
    return 0
  fi

  printf 'next step: %s (%s)' "${parsed_value%%|*}" "${parsed_value#*|}"
}

discover_project_features() {
  local runtime_root="$1"
  local project_abs_path="$runtime_root/$PROJECT_PATH"
  local child_path=""
  local rel_path=""
  local scanner_status=""

  DISCOVERED_FEATURE_PATHS=()
  UNFINISHED_FEATURE_PATHS=()
  UNFINISHED_FEATURE_NEXT_LINES=()

  while IFS= read -r child_path; do
    [[ -n "$child_path" ]] || continue
    rel_path="${child_path#"$runtime_root/"}"
    DISCOVERED_FEATURE_PATHS+=("$rel_path")

    if scanner_status="$(scanner_status_line_for_feature "$runtime_root" "$rel_path")"; then
      if [[ "$scanner_status" != "next step: none" ]]; then
        UNFINISHED_FEATURE_PATHS+=("$rel_path")
        UNFINISHED_FEATURE_NEXT_LINES+=("$scanner_status")
      fi
    fi
  done < <(find "$project_abs_path" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | LC_ALL=C sort)
}

prompt_feature_mode() {
  local answer=""

  echo "Project feature selection for: $PROJECT_PATH"
  echo "Found unfinished features: ${#UNFINISHED_FEATURE_PATHS[@]}"
  echo "Project feature options:"
  echo "  1) Start a new feature"
  echo "  2) Continue an existing unfinished feature"

  while true; do
    printf 'Choose [1/2]: ' >&2
    if ! IFS= read -r answer; then
      return 2
    fi

    answer="$(trim_value "$answer")"
    answer="$(to_lower "$answer")"
    case "$answer" in
      1|new|start)
        return 10
        ;;
      2|continue|resume)
        return 20
        ;;
      *)
        echo "Please answer 1 or 2." >&2
        ;;
    esac
  done
}

select_unfinished_feature() {
  local answer=""
  local idx=0
  local total="${#UNFINISHED_FEATURE_PATHS[@]}"

  [[ "$total" -gt 0 ]] || return 1

  echo "Unfinished features:"
  for ((idx = 0; idx < total; idx++)); do
    printf '  %s) %s [%s]\n' "$((idx + 1))" "${UNFINISHED_FEATURE_PATHS[$idx]}" "${UNFINISHED_FEATURE_NEXT_LINES[$idx]}"
  done

  while true; do
    printf 'Choose unfinished feature [1-%s]: ' "$total" >&2
    if ! IFS= read -r answer; then
      return 2
    fi

    answer="$(trim_value "$answer")"
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= total )); then
      FEATURE_PATH="${UNFINISHED_FEATURE_PATHS[$((answer - 1))]}"
      echo "Selected unfinished feature: $FEATURE_PATH"
      return 0
    fi
    echo "Please answer with a number between 1 and $total." >&2
  done
}

print_no_unfinished_features_message() {
  local discovered_count="${#DISCOVERED_FEATURE_PATHS[@]}"

  echo "Examined project features for: $PROJECT_PATH"

  if [[ -n "$CACHED_FEATURE_PATH" ]] && ! array_contains "$CACHED_FEATURE_PATH" "${UNFINISHED_FEATURE_PATHS[@]-}"; then
    echo "Last selected feature is already complete: $CACHED_FEATURE_PATH"
  elif [[ "$discovered_count" -gt 0 ]]; then
    echo "Examined $discovered_count existing feature folder(s); all are already complete."
  else
    echo "No existing feature folders were found for this project."
  fi

  echo "No unfinished features are available to continue."
  echo "Would you like to start a new feature? Confirm the scaffold step below."
}

phase_label() {
  case "$1" in
    3) printf '%s' "Initialize and Enrich BR Structuring (scaffold)" ;;
    4.1) printf '%s' "BR Enrichment Part 1" ;;
    4.2) printf '%s' "BR Enrichment Part 2" ;;
    5) printf '%s' "Convert BR to EARS" ;;
    5.1) printf '%s' "Optional EARS Review" ;;
    6) printf '%s' "Feature Contract Delta" ;;
    7) printf '%s' "Repo Surface and Technical Requirements" ;;
    7.1) printf '%s' "Optional MCP Placeholder Enrichment" ;;
    8.1) printf '%s' "Implementation Slices" ;;
    8.2) printf '%s' "Prerequisite Gap Trace" ;;
    8.3) printf '%s' "Implementation Plan" ;;
    8.4) printf '%s' "Optional Implementation Plan Semantic Review" ;;
    *) printf '%s' "$1" ;;
  esac
}

print_restart_guidance() {
  local phase_id="$1"
  local script_name="$2"
  local exit_code="$3"

  echo "Execution stopped: phase $phase_id failed while running .commands/$script_name (exit $exit_code)." >&2
  echo "Fix the error above and restart the orchestrator. It will continue from the correct step:" >&2
  echo "  .commands/$SCRIPT_BASENAME --path $PROJECT_PATH --resume $phase_id" >&2
}

phase_scripts() {
  case "$1" in
    3)
      printf '%s\n' "feature_br_scaffold.sh"
      ;;
    4.1)
      printf '%s\n' "feature_scan_repo_for_br.sh" "feature_task_to_br.sh"
      ;;
    4.2)
      printf '%s\n' "feature_user_br_clarification.sh" "feature_br_check_ears_readiness.sh"
      ;;
    5)
      printf '%s\n' "feature_br_to_ears.sh"
      ;;
    5.1)
      printf '%s\n' "feature_requirements_ears_review.sh"
      ;;
    6)
      printf '%s\n' "feature_contract_delta.sh"
      ;;
    7)
      printf '%s\n' "feature_repo_surface_and_exec_context.sh" "feature_technical_requirements.sh"
      ;;
    7.1)
      printf '%s\n' "feature_surface_map_mcp_placeholder_enrichment.sh"
      ;;
    8.1)
      printf '%s\n' "feature_implementation_slices.sh"
      ;;
    8.2)
      printf '%s\n' "feature_prerequisite_gaps.sh"
      ;;
    8.3)
      printf '%s\n' "feature_implementation_plan.sh"
      ;;
    8.4)
      printf '%s\n' "feature_implementation_plan_semantic_review.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

extract_project_classes() {
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
        print tolower(value)
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
        print tolower(line)
      }
      next
    }
    in_classes = 0
  }
}
' "$definition_path"
}

phase7_map_file_for_class() {
  case "$1" in
    backend) printf '%s' "$FEATURE_PATH/project_surface_struct_resp_map_backend.md" ;;
    frontend) printf '%s' "$FEATURE_PATH/project_surface_struct_resp_map_frontend.md" ;;
    mobile) printf '%s' "$FEATURE_PATH/project_surface_struct_resp_map_mobile.md" ;;
    *) return 1 ;;
  esac
}

refresh_phase7_status() {
  local runtime_root="$1"
  local definition_path="$runtime_root/$PROJECT_PATH/init_progress_definition.yaml"
  local parsed_classes=""
  local class_name=""
  local map_file=""

  PHASE7_ACTIVE_REPO_CLASSES=()
  PHASE7_COMPLETED_REPO_CLASSES=()
  PHASE7_PENDING_REPO_CLASSES=()

  if [[ -f "$definition_path" ]]; then
    parsed_classes="$(extract_project_classes "$definition_path" 2>/dev/null || true)"
    while IFS= read -r class_name; do
      case "$class_name" in
        backend|frontend|mobile)
          if ! array_contains "$class_name" "${PHASE7_ACTIVE_REPO_CLASSES[@]-}"; then
            PHASE7_ACTIVE_REPO_CLASSES+=("$class_name")
          fi
          ;;
      esac
    done <<<"$parsed_classes"
  fi

  if [[ ${#PHASE7_ACTIVE_REPO_CLASSES[@]} -eq 0 ]]; then
    PHASE7_ACTIVE_REPO_CLASSES=("backend" "frontend" "mobile")
  fi

  for class_name in "${PHASE7_ACTIVE_REPO_CLASSES[@]}"; do
    map_file="$(phase7_map_file_for_class "$class_name" || true)"
    if [[ -z "$map_file" ]]; then
      continue
    fi
    if [[ -f "$runtime_root/$map_file" ]]; then
      PHASE7_COMPLETED_REPO_CLASSES+=("$class_name")
    else
      PHASE7_PENDING_REPO_CLASSES+=("$class_name")
    fi
  done
}

format_class_list() {
  local values=("$@")
  local item=""
  local output=""
  local count=0

  for item in "${values[@]}"; do
    [[ -n "$item" ]] || continue
    count=$((count + 1))
    if [[ -n "$output" ]]; then
      output+=", "
    fi
    output+="$item"
  done

  if [[ "$count" -eq 0 ]]; then
    printf '%s' "none"
    return 0
  fi

  printf '%s' "$output"
}

run_phase7_loop() {
  local runtime_root="$1"
  local selection=""
  local normalized=""
  local command_text=""
  local completed_list=""
  local pending_list=""
  local script_rc=0

  while true; do
    refresh_phase7_status "$runtime_root"
    completed_list="$(format_class_list "${PHASE7_COMPLETED_REPO_CLASSES[@]-}")"
    pending_list="$(format_class_list "${PHASE7_PENDING_REPO_CLASSES[@]-}")"

    echo "Phase 7 repo loop status for feature: $FEATURE_PATH"
    echo "Already picked/completed repo classes: $completed_list"
    echo "Pending repo classes: $pending_list"
    echo "Phase 7 options:"
    echo "  1) Analyze one repo now"
    echo "  2) Refresh repo status"
    echo "  3) contract delta finished lets move forward"
    printf 'Choose [1/2/3]: ' >&2

    if ! IFS= read -r selection; then
      echo "Execution stopped: user input stream closed during phase 7 loop."
      return 20
    fi

    normalized="$(to_lower "$(trim_value "$selection")")"
    case "$normalized" in
      1)
        set +e
        run_feature_script "$runtime_root" "feature_repo_surface_and_exec_context.sh"
        script_rc=$?
        set -e
        if [[ "$script_rc" -ne 0 ]]; then
          print_restart_guidance "7" "feature_repo_surface_and_exec_context.sh" "$script_rc"
          return "$PHASE_EXECUTION_FAILED_RC"
        fi
        ;;
      2)
        ;;
      3)
        break
        ;;
      *)
        echo "Invalid selection: $selection"
        ;;
    esac
  done

  refresh_phase7_status "$runtime_root"
  if [[ ${#PHASE7_PENDING_REPO_CLASSES[@]} -gt 0 ]]; then
    echo "Proceeding with pending repo classes: $(format_class_list "${PHASE7_PENDING_REPO_CLASSES[@]-}")"
  fi

  command_text=".commands/feature_technical_requirements.sh --feature_path $FEATURE_PATH"
  if ! confirm_start "7" "2" "2" "$command_text"; then
    local decision_status=$?
    if [[ "$decision_status" -eq 2 ]]; then
      echo "Execution stopped: user input stream closed during confirmation at 7."
      return 20
    fi
    echo "Execution stopped: user denied phase progression at 7."
    return 20
  fi

  set +e
  run_feature_script "$runtime_root" "feature_technical_requirements.sh"
  script_rc=$?
  set -e
  if [[ "$script_rc" -ne 0 ]]; then
    print_restart_guidance "7" "feature_technical_requirements.sh" "$script_rc"
    return "$PHASE_EXECUTION_FAILED_RC"
  fi
  return 0
}

phase_index() {
  local target="$1"
  local idx
  for ((idx = 0; idx < ${#PHASE_IDS[@]}; idx++)); do
    if [[ "${PHASE_IDS[$idx]}" == "$target" ]]; then
      printf '%s' "$idx"
      return 0
    fi
  done
  return 1
}

has_later_required_phase() {
  local start_index="$1"
  local idx
  for ((idx = start_index + 1; idx < ${#PHASE_IDS[@]}; idx++)); do
    if [[ "${PHASE_OPTIONAL[$idx]}" != "true" ]]; then
      return 0
    fi
  done
  return 1
}

confirm_start() {
  local phase_id="$1"
  local script_index="$2"
  local total_scripts="$3"
  local command_text="$4"
  local answer=""

  echo "Phase $phase_id ($(phase_label "$phase_id")) script $script_index/$total_scripts"
  echo "Command: $command_text"

  while true; do
    printf 'Start this script? [y/n]: ' >&2
    if ! IFS= read -r answer; then
      return 2
    fi

    answer="$(trim_value "$answer")"
    answer="$(to_lower "$answer")"

    case "$answer" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        echo "Please answer yes or no." >&2
        ;;
    esac
  done
}

run_scaffold_and_capture_feature_path() {
  local runtime_root="$1"
  local command_path="$runtime_root/.commands/feature_br_scaffold.sh"
  local capture_file=""
  local status=0
  local raw_feature_path=""
  local updated_line=""

  [[ -x "$command_path" ]] || die "Required script not found or not executable: .commands/feature_br_scaffold.sh"

  capture_file="$(mktemp)"
  set +e
  "$command_path" --path "$PROJECT_PATH" 2>&1 | tee "$capture_file"
  status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    rm -f "$capture_file"
    print_restart_guidance "3" "feature_br_scaffold.sh" "$status"
    return "$PHASE_EXECUTION_FAILED_RC"
  fi

  raw_feature_path="$(
    awk '
      BEGIN {
        created_marker = "Created feature folder:"
      }
      {
        line = $0
        sub(/\r$/, "", line)
        idx = index(line, created_marker)
        if (idx > 0) {
          created_value = substr(line, idx + length(created_marker))
        }
      }
      END {
        gsub(/^[[:space:]]+/, "", created_value)
        gsub(/[[:space:]]+$/, "", created_value)
        if (created_value != "") {
          print created_value
        }
      }
    ' "$capture_file"
  )"

  if [[ -z "$raw_feature_path" ]]; then
    updated_line="$(
      awk '
        BEGIN {
          updated_marker = "Updated "
        }
        {
          line = $0
          sub(/\r$/, "", line)
          idx = index(line, updated_marker)
          if (idx > 0) {
            updated_value = substr(line, idx + length(updated_marker))
          }
        }
        END {
          gsub(/^[[:space:]]+/, "", updated_value)
          gsub(/[[:space:]]+$/, "", updated_value)
          if (updated_value != "") {
            print updated_value
          }
        }
      ' "$capture_file"
    )"
    if [[ "$updated_line" == */feature_br_summary.md ]]; then
      raw_feature_path="${updated_line%/feature_br_summary.md}"
    fi
  fi

  rm -f "$capture_file"

  [[ -n "$raw_feature_path" ]] || die "Unable to determine feature_path from scaffold output."

  raw_feature_path="$(trim_value "$raw_feature_path")"
  FEATURE_PATH="$(canonicalize_feature_path "$raw_feature_path" "$runtime_root")"
  persist_feature_path "$runtime_root"
  echo "Saved feature_path: $FEATURE_PATH"
  return 0
}

run_feature_script() {
  local runtime_root="$1"
  local script_name="$2"
  local command_path="$runtime_root/.commands/$script_name"

  [[ -x "$command_path" ]] || die "Required script not found or not executable: .commands/$script_name"
  "$command_path" --feature_path "$FEATURE_PATH"
}

run_scanner_and_get_next_step() {
  local runtime_root="$1"
  local scanner_path="$runtime_root/.commands/init_progress_scanner.sh"
  local scanner_output=""
  local parsed_value=""

  [[ -x "$scanner_path" ]] || die "Required script not found or not executable: .commands/init_progress_scanner.sh"

  scanner_output="$("$scanner_path" --path "$FEATURE_PATH")"
  printf '%s\n' "$scanner_output" >&2

  parsed_value="$(parse_scanner_next_step_line "$scanner_output")" || die "Unable to parse scanner output: missing canonical 'next step:' line."
  printf '%s' "$parsed_value"
}

map_scanner_step_to_phase() {
  local scanner_step_number="$1"
  local scanner_step_name="$2"
  local normalized_name
  normalized_name="$(to_lower "$scanner_step_name")"

  case "$normalized_name" in
    *"initialize and enrich business requirements structuring"*) printf '%s' "4.1"; return 0 ;;
    *"scan repo"* ) printf '%s' "4.1"; return 0 ;;
    *"task to br"* ) printf '%s' "4.1"; return 0 ;;
    *"business requirements clarification"* ) printf '%s' "4.2"; return 0 ;;
    *"readiness"* ) printf '%s' "4.2"; return 0 ;;
    *"convert business requirements structuring to ears"*) printf '%s' "5"; return 0 ;;
    *"convert br to ears"*) printf '%s' "5"; return 0 ;;
    *"requirement_ears extra review"*) printf '%s' "5.1"; return 0 ;;
    *"define feature contract delta"*) printf '%s' "6"; return 0 ;;
    *"analyze repos and prepare repo execution context"*) printf '%s' "7"; return 0 ;;
    *"create feature-scoped technical requirements"*) printf '%s' "7"; return 0 ;;
    *"mcp placeholder enrichment"*) printf '%s' "7.1"; return 0 ;;
    *"create implementation slice planning artifact"*) printf '%s' "8.1"; return 0 ;;
    *"run prerequisite gap trace"*) printf '%s' "8.2"; return 0 ;;
    *"create shared repository implementation plan"*) printf '%s' "8.3"; return 0 ;;
    *"implementation plan semantic review"*) printf '%s' "8.4"; return 0 ;;
  esac

  case "$scanner_step_number" in
    3) printf '%s' "4.1" ;;
    4) printf '%s' "5" ;;
    4.1) printf '%s' "4.1" ;;
    4.2) printf '%s' "4.2" ;;
    5) printf '%s' "5" ;;
    5.1) printf '%s' "5.1" ;;
    6) printf '%s' "6" ;;
    7) printf '%s' "7" ;;
    7.1) printf '%s' "7.1" ;;
    8) printf '%s' "7" ;;
    8.1) printf '%s' "8.1" ;;
    8.2) printf '%s' "8.2" ;;
    8.3) printf '%s' "8.3" ;;
    8.4) printf '%s' "8.4" ;;
    *) return 1 ;;
  esac
}

map_resume_to_phase() {
  local resume_value="$1"
  local normalized="$resume_value"

  normalized="$(to_lower "$normalized")"

  case "$normalized" in
    3|scaffold) printf '%s' "3" ;;
    4.1|scan-task|scan-task-to-br) printf '%s' "4.1" ;;
    4.2|clarification|readiness) printf '%s' "4.2" ;;
    5|4|ears|br-to-ears) printf '%s' "5" ;;
    5.1|ears-review|4.1-optional) printf '%s' "5.1" ;;
    6|5|contract-delta) printf '%s' "6" ;;
    7|8|6|repo-surface|technical-requirements) printf '%s' "7" ;;
    7.1|mcp-placeholder-enrichment) printf '%s' "7.1" ;;
    8.1|implementation-slices) printf '%s' "8.1" ;;
    8.2|prerequisite-gap-trace|prerequisite-gaps) printf '%s' "8.2" ;;
    8.3|implementation-plan) printf '%s' "8.3" ;;
    8.4|semantic-review|implementation-plan-semantic-review) printf '%s' "8.4" ;;
    *) return 1 ;;
  esac
}

run_phase_by_index() {
  local runtime_root="$1"
  local phase_idx="$2"
  local phase_id="${PHASE_IDS[$phase_idx]}"
  local optional="${PHASE_OPTIONAL[$phase_idx]}"
  local scripts=()
  local script_name=""
  local idx=0
  local total=0
  local command_text=""
  local script_rc=0

  if [[ "$phase_id" == "7" ]]; then
    run_phase7_loop "$runtime_root"
    return $?
  fi

  while IFS= read -r script_name; do
    scripts+=("$script_name")
  done < <(phase_scripts "$phase_id")
  total="${#scripts[@]}"
  [[ "$total" -gt 0 ]] || die "No scripts configured for phase $phase_id"

  for script_name in "${scripts[@]}"; do
    idx=$((idx + 1))

    if [[ "$phase_id" == "3" ]]; then
      command_text=".commands/$script_name --path $PROJECT_PATH"
    else
      command_text=".commands/$script_name --feature_path $FEATURE_PATH"
    fi

    if ! confirm_start "$phase_id" "$idx" "$total" "$command_text"; then
      local decision_status=$?
      if [[ "$decision_status" -eq 2 ]]; then
        echo "Execution stopped: user input stream closed during confirmation at $phase_id."
        return 20
      fi

      if [[ "$optional" == "true" ]]; then
        echo "Optional phase declined at $phase_id; skipping."
        if has_later_required_phase "$phase_idx"; then
          return 10
        fi
        echo "Execution finished: no remaining required phases after declined optional phase $phase_id."
        return 30
      fi

      echo "Execution stopped: user denied phase progression at $phase_id."
      return 20
    fi

    if [[ "$phase_id" == "3" ]]; then
      set +e
      run_scaffold_and_capture_feature_path "$runtime_root"
      script_rc=$?
      set -e
      if [[ "$script_rc" -ne 0 ]]; then
        return "$script_rc"
      fi
    else
      set +e
      run_feature_script "$runtime_root" "$script_name"
      script_rc=$?
      set -e
      if [[ "$script_rc" -ne 0 ]]; then
        print_restart_guidance "$phase_id" "$script_name" "$script_rc"
        return "$PHASE_EXECUTION_FAILED_RC"
      fi
    fi
  done

  return 0
}

main() {
  parse_args "$@"

  RUNTIME_ROOT="$(resolve_runtime_root)"
  resolve_project_path "$RUNTIME_ROOT" "$TARGET_PATH_INPUT"

  local requested_phase=""
  if [[ -n "$RESUME_STEP_INPUT" ]]; then
    if ! requested_phase="$(map_resume_to_phase "$RESUME_STEP_INPUT")"; then
      die "Unsupported resume step: $RESUME_STEP_INPUT"
    fi
  fi

  load_saved_feature_path_cache "$RUNTIME_ROOT" || true
  case "$CACHED_FEATURE_PATH_STATE" in
    valid)
      echo "Loaded saved feature_path cache: $CACHED_FEATURE_PATH"
      ;;
    stale)
      if [[ -n "$CACHED_FEATURE_PATH_RAW" ]]; then
        echo "Ignoring stale saved feature_path cache: $CACHED_FEATURE_PATH_RAW"
      fi
      ;;
  esac

  discover_project_features "$RUNTIME_ROOT"

  if [[ -z "$FEATURE_PATH" ]]; then
    local unfinished_count="${#UNFINISHED_FEATURE_PATHS[@]}"
    if [[ "$unfinished_count" -gt 0 ]]; then
      while true; do
        set +e
        prompt_feature_mode
        local feature_mode_rc=$?
        set -e

        case "$feature_mode_rc" in
          10)
            if [[ -n "$requested_phase" && "$requested_phase" != "3" ]]; then
              echo "Cannot start a new feature with --resume $RESUME_STEP_INPUT. Choose continue or rerun without --resume." >&2
              continue
            fi
            echo "Starting a new feature under project: $PROJECT_PATH"
            break
            ;;
          20)
            if [[ "$requested_phase" == "3" ]]; then
              echo "Cannot continue an existing feature with --resume 3. Choose start new or rerun without --resume." >&2
              continue
            fi
            set +e
            select_unfinished_feature
            local selection_rc=$?
            set -e
            case "$selection_rc" in
              0)
                persist_feature_path "$RUNTIME_ROOT"
                echo "Saved feature_path: $FEATURE_PATH"
                break
                ;;
              2)
                echo "Execution stopped: user input stream closed during unfinished feature selection."
                exit 0
                ;;
              *)
                die "Unexpected unfinished feature selection status: $selection_rc"
                ;;
            esac
            ;;
          2)
            echo "Execution stopped: user input stream closed during project feature selection."
            exit 0
            ;;
          *)
            die "Unexpected project feature selection status: $feature_mode_rc"
            ;;
        esac
      done
    elif [[ -n "$requested_phase" && "$requested_phase" != "3" ]]; then
      die "No unfinished feature context for this project. Run without --resume or use --resume 3 first."
    else
      print_no_unfinished_features_message
    fi
  fi

  if [[ -z "$FEATURE_PATH" ]]; then
    local phase3_index=""
    phase3_index="$(phase_index "3")"

    set +e
    run_phase_by_index "$RUNTIME_ROOT" "$phase3_index"
    local phase3_rc=$?
    set -e

    case "$phase3_rc" in
      0)
        ;;
      10)
        ;;
      20|30)
        exit 0
        ;;
      "$PHASE_EXECUTION_FAILED_RC")
        exit 1
        ;;
      *)
        die "Unexpected phase execution status for step 3: $phase3_rc"
        ;;
    esac

    if [[ "$requested_phase" == "3" ]]; then
      requested_phase=""
    fi
  fi

  local scanner_step_info=""
  local start_phase=""
  local scanner_number=""
  local scanner_name=""

  scanner_step_info="$(run_scanner_and_get_next_step "$RUNTIME_ROOT")"
  if [[ "$scanner_step_info" != "none" ]]; then
    scanner_number="${scanner_step_info%%|*}"
    scanner_name="${scanner_step_info#*|}"
    if step_is_before_first_supported_step "$scanner_number"; then
      fail_project_prerequisite_step "$scanner_number" "$scanner_name"
    fi
  fi

  if [[ -n "$requested_phase" ]]; then
    start_phase="$requested_phase"
  else
    if [[ "$scanner_step_info" == "none" ]]; then
      echo "Execution finished: scanner reports no remaining required steps."
      exit 0
    fi

    if ! start_phase="$(map_scanner_step_to_phase "$scanner_number" "$scanner_name")"; then
      die "Unable to map scanner next step '$scanner_number ($scanner_name)' to orchestrator phase."
    fi
  fi

  local start_index=""
  if ! start_index="$(phase_index "$start_phase")"; then
    die "Configured start phase is unknown: $start_phase"
  fi

  local idx
  for ((idx = start_index; idx < ${#PHASE_IDS[@]}; idx++)); do
    set +e
    run_phase_by_index "$RUNTIME_ROOT" "$idx"
    local phase_rc=$?
    set -e

    case "$phase_rc" in
      0)
        ;;
      10)
        ;;
      20|30)
        exit 0
        ;;
      "$PHASE_EXECUTION_FAILED_RC")
        exit 1
        ;;
      *)
        die "Unexpected phase execution status at ${PHASE_IDS[$idx]}: $phase_rc"
        ;;
    esac
  done

  echo "Execution finished: reached end of configured phase map."
}

main "$@"
